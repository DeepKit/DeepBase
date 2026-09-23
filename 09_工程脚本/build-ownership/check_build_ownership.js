// DeepBase 构建归属门禁（WO-20260919-AUDIT-乙 B3）
// 规则：
//  O1 生产单元（8 个生产目录全集）必须被至少一个构建文件（.dpk/.dproj/.dpr）按单元名引用；
//     否则为孤儿。孤儿必须出现在冻结基线 build_ownership_baseline.json 中并带处置标注，新增孤儿 ⇒ FAIL。
//  O2 C2 硬门禁：任何生产构建包（.dpk/.dproj）的文本引用 DeepBase.Plugins.{CAbi,CAbiLoader,Contracts,Manager,SafeGuard,Verifier}
//     ⇒ BLOCK（新轨冻结隔离，H10）。
//  O3 C1 同名类消解校验：Core\DeepBase.Plugins.Manager.pas 不得再声明 TDeepBasePluginManager ⇒ 出现即 FAIL。
//  O4 生产单元（新轨 6 单元自身除外）的源码引用 DeepBase.Plugins.{6单元} ⇒ BLOCK（uses 级封锁）。
// 用法: node check_build_ownership.js [--root <dir>] [--baseline <file>] [--emit-baseline]
// 退出码：0 通过；1 违规；2 基线不可信（WO-20260923-AUDIT-乙-D5 §一-3，见 gate-baseline.js）。
const fs = require('fs');
const path = require('path');
const { gateSkipSet } = require('../gate-skip');
const { loadGateBaseline } = require('../gate-baseline');

function arg(name, dflt) {
  const i = process.argv.indexOf('--' + name);
  return i > 0 && process.argv[i + 1] ? process.argv[i + 1] : dflt;
}
const ROOT = path.resolve(arg('root', 'D:/_Progs/02Business/DeepBase'));
const BASELINE_P = arg('baseline', path.join(__dirname, 'build_ownership_baseline.json'));
const EMIT = process.argv.includes('--emit-baseline');
const PROD_DIRS = ['Core', 'Features', 'Persistence', 'VCL', 'FMX', 'Governance', 'Tools', 'DeepFlow'];
const SKIP = gateSkipSet();
const NEWTRACK = ['DeepBase.Plugins.CAbi', 'DeepBase.Plugins.CAbiLoader', 'DeepBase.Plugins.Contracts', 'DeepBase.Plugins.Manager', 'DeepBase.Plugins.SafeGuard', 'DeepBase.Plugins.Verifier'];

function walk(dir, exts, out) {
  let ents;
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { return out; }
  for (const e of ents) {
    if (SKIP.has(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, exts, out);
    else if (e.isFile() && exts.some(x => e.name.toLowerCase().endsWith(x))) out.push(p);
  }
  return out;
}
function unitNameOf(pasFile) {
  const txt = fs.readFileSync(pasFile).toString('utf8');
  const m = txt.match(/^\s*unit\s+([A-Za-z_][\w.]*)/m);
  return m ? m[1] : path.basename(pasFile, '.pas');
}

// 构建文件全集（repo 内所有 .dpk/.dproj/.dpr），一次性读入拼成检索文本
const buildFiles = walk(ROOT, ['.dpk', '.dproj', '.dpr'], []);
const buildText = {};
for (const bf of buildFiles) buildText[bf] = fs.readFileSync(bf, 'utf8');
function referencedBy(unit) {
  const hits = [];
  const re = new RegExp('\\b' + unit.replace(/\./g, '\\.') + '\\b');
  for (const bf of buildFiles) if (re.test(buildText[bf])) hits.push(path.relative(ROOT, bf).replace(/\\/g, '/'));
  return hits;
}

const prodUnits = [];
for (const d of PROD_DIRS) {
  for (const f of walk(path.join(ROOT, d), ['.pas'], [])) {
    prodUnits.push({ path: path.relative(ROOT, f).replace(/\\/g, '/'), unit: unitNameOf(f) });
  }
}
prodUnits.sort((a, b) => a.path.localeCompare(b.path));

const orphans = prodUnits.filter(u => referencedBy(u.unit).length === 0);
const violations = [];

// O2：新轨禁入生产构建
for (const nu of NEWTRACK) {
  for (const bf of buildFiles) {
    if (!/\.(dpk|dproj)$/i.test(bf)) continue;
    if (new RegExp('\\b' + nu.replace(/\./g, '\\.') + '\\b').test(buildText[bf])) {
      violations.push(`O2/C2 BLOCK 新轨单元进入生产构建: ${nu} ∈ ${path.relative(ROOT, bf).replace(/\\/g, '/')}`);
    }
  }
}
// O3：同名类不得复活
const mgrP = path.join(ROOT, 'Core', 'DeepBase.Plugins.Manager.pas');
if (fs.existsSync(mgrP) && /TDeepBasePluginManager\b/.test(fs.readFileSync(mgrP, 'utf8'))) {
  violations.push('O3/C1 FAIL 新轨再次出现同名类 TDeepBasePluginManager（遮蔽活雷回归）');
}
// O4：生产单元 uses 级封锁（新轨 6 单元自身互引豁免）
const newTrackFiles = new Set(NEWTRACK.map(n => path.join(ROOT, 'Core', n + '.pas').toLowerCase()));
for (const u of prodUnits) {
  const abs = path.join(ROOT, u.path);
  if (newTrackFiles.has(abs.toLowerCase())) continue;
  const txt = fs.readFileSync(abs, 'utf8');
  for (const nu of NEWTRACK) {
    if (new RegExp('\\b' + nu.replace(/\./g, '\\.') + '\\b').test(txt)) {
      violations.push(`O4/C2 BLOCK 生产单元引用新轨: ${u.path} -> ${nu}`);
    }
  }
}

// O1：孤儿须入基线
// 本门的 --emit-baseline 要读旧基线以保留人工 disposition，故基线校验放在 EMIT 之前：
// 不允许在坏基线上重刷（否则 47 条人工标注会退回『待标注』）。守写入动作仍是 B1。
const baseline = loadGateBaseline({
  file: BASELINE_P, label: '构建归属',
  keys: { orphans: 'object' },
});
if (EMIT) {
  const emit = { generatedFrom: 'check_build_ownership.js', orphans: {} };
  for (const o of orphans) emit.orphans[o.path] = baseline.orphans[o.path] && baseline.orphans[o.path].disposition
    ? baseline.orphans[o.path] : { disposition: '待标注', reason: 'TODO' };
  fs.writeFileSync(BASELINE_P, JSON.stringify(emit, null, 1));
  console.log('baseline emitted: ' + orphans.length + ' orphans');
} else {
  for (const o of orphans) {
    if (!baseline.orphans[o.path]) violations.push(`O1 FAIL 新增孤儿单元（不在基线）: ${o.path} (unit ${o.unit})`);
  }
}

if (violations.length) {
  console.error(`构建归属门禁失败，违规 ${violations.length} 项:`);
  violations.slice(0, 60).forEach(v => console.error('  ' + v));
  process.exit(1);
}
console.log(`构建归属门禁通过：生产单元 ${prodUnits.length}，构建文件 ${buildFiles.length}，孤儿（已登记基线）${orphans.length}`);
