// DeepBase 构建归属门禁（WO-20260919-AUDIT-乙 B3）
// 规则：
//  O1 生产单元（8 个生产目录全集）必须被至少一个构建文件（.dpk/.dproj/.dpr）按单元名引用；
//     否则为孤儿。孤儿必须出现在冻结基线 build_ownership_baseline.json 中并带处置标注，新增孤儿 ⇒ FAIL。
//  O2 C2 硬门禁：任何生产构建包（.dpk/.dproj）的文本引用 DeepBase.Plugins.{CAbi,CAbiLoader,Contracts,Manager,SafeGuard,Verifier}
//     ⇒ BLOCK（新轨冻结隔离，H10）。
//  O3 C1 同名类消解校验：Core\DeepBase.Plugins.Manager.pas 不得再声明 TDeepBasePluginManager ⇒ 出现即 FAIL。
//  O4 生产单元（新轨 6 单元自身除外）的源码引用 DeepBase.Plugins.{6单元} ⇒ BLOCK（uses 级封锁）。
// 用法: node check_build_ownership.js [--root <dir>] [--baseline <file>] [--emit-baseline] [--allow-narrow-root]
// 退出码：0 通过；1 违规；2 基线不可信（gate-baseline.js）；3 参数不合法或扫描本身失败
//   （3 的三种触发都是 fail-closed：读目录/读文件失败、构建文件面 0、生产单元面 0。
//    「扫不到」绝不能报绿，见 WO-20260921-AUDIT-乙-P1 §〇 与 WO-20260924-AUDIT-乙-D7 §一-2）
const fs = require('fs');
const path = require('path');
const { parseGateArgs } = require('../gate-args');
const { gateSkipSet } = require('../gate-skip');
const { loadGateBaseline } = require('../gate-baseline');
const { guardedEmitBaseline } = require('../gate-emit-guard');

// 参数解析收敛到 09_工程脚本/gate-args.js 单一实现（WO-20260924-AUDIT-乙-D7 §一-3）。
// 此前的私有 arg() 用大小写敏感的 indexOf 取值且无未知参数校验：--ROOT / --rot 会被静默忽略，
// 回落默认根后照常报绿——正是编码/行尾门禁在 P2 §3.3 修掉的那道裂缝，本门禁当时漏在外面。
// 默认根同样收敛为脚本自身相对（§1.1）：写死的本机绝对路径在别的检出目录/CI 里等于扫空气报绿。
{
  const opts = parseGateArgs(process.argv.slice(2), {
    label: '构建归属',
    root: path.join(__dirname, '../..'),
    baseline: path.join(__dirname, 'build_ownership_baseline.json'),
    extra: ['emit-baseline', 'allow-narrow-root'],
  });
  if (opts.flags.has('help')) {
    console.log('用法: node check_build_ownership.js [--root <dir>] [--baseline <file>] [--emit-baseline] [--allow-narrow-root]');
    process.exit(0);
  }
  var ROOT = opts.root;
  var BASELINE_P = opts.baseline;
  var EMIT = opts.flags.has('emit-baseline');
  var ALLOW_NARROW = opts.flags.has('allow-narrow-root');
}
const REPO_ROOT = path.resolve(path.join(__dirname, '../..'));
const PROD_DIRS = ['Core', 'Features', 'Persistence', 'VCL', 'FMX', 'Governance', 'Tools', 'DeepFlow'];
const SKIP = gateSkipSet();
const NEWTRACK = ['DeepBase.Plugins.CAbi', 'DeepBase.Plugins.CAbiLoader', 'DeepBase.Plugins.Contracts', 'DeepBase.Plugins.Manager', 'DeepBase.Plugins.SafeGuard', 'DeepBase.Plugins.Verifier'];

function die(why) {
  console.error(`构建归属门禁失败：${why}。已按 fail-closed 拒绝放行。`);
  process.exit(3);
}

function walk(dir, exts, out) {
  let ents;
  // fail-closed：readdir 失败（root 不存在/无权限/路径被同名文件遮蔽）不得静默返回空数组，
  // 否则「没扫到」会被写成「扫过且干净」。
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) {
    die(`无法读取目录 ${dir} (${e.code || e.message})`);
  }
  for (const e of ents) {
    if (SKIP.has(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, exts, out);
    else if (e.isFile() && exts.some(x => e.name.toLowerCase().endsWith(x))) out.push(p);
  }
  return out;
}
// 扫描面内的读取失败同样归「扫描失败」而非「违规」：EXIT=1 的语义是「有归属问题」，
// 让 node 的未捕获异常冒领 EXIT=1 会把环境问题报成分诊问题。
function readText(p, what) {
  try { return fs.readFileSync(p, 'utf8'); } catch (e) {
    die(`${what}读取失败 ${p} (${e.code || e.message})`);
  }
}
function unitNameOf(pasFile) {
  const m = readText(pasFile, '生产单元').match(/^\s*unit\s+([A-Za-z_][\w.]*)/m);
  return m ? m[1] : path.basename(pasFile, '.pas');
}

// 构建文件全集（root 内所有 .dpk/.dproj/.dpr），一次性读入拼成检索文本
const buildFiles = walk(ROOT, ['.dpk', '.dproj', '.dpr'], []);
const buildText = {};
for (const bf of buildFiles) buildText[bf] = readText(bf, '构建文件');
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

// 空扫描即失败：两个面各自判零，缺一不可。构建文件面为 0 ⇒ 引用关系无从判定（孤儿判定会整片失真）；
// 生产单元面为 0 ⇒ PROD_DIRS 一个都没扫到，root 指错或被同名文件遮蔽（WO-20260924-AUDIT-乙-D7 §一-2 第 2/3 条）。
if (buildFiles.length === 0) die(`扫描 0 个构建文件（root=${ROOT}），引用面为空`);
if (prodUnits.length === 0) die(`扫描 0 个生产单元（root=${ROOT}，PROD_DIRS=${PROD_DIRS.join('/')}）`);

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
if (fs.existsSync(mgrP) && /TDeepBasePluginManager\b/.test(readText(mgrP, '新轨 Manager 单元'))) {
  violations.push('O3/C1 FAIL 新轨再次出现同名类 TDeepBasePluginManager（遮蔽活雷回归）');
}
// O4：生产单元 uses 级封锁（新轨 6 单元自身互引豁免）
const newTrackFiles = new Set(NEWTRACK.map(n => path.join(ROOT, 'Core', n + '.pas').toLowerCase()));
for (const u of prodUnits) {
  const abs = path.join(ROOT, u.path);
  if (newTrackFiles.has(abs.toLowerCase())) continue;
  const txt = readText(abs, '生产单元');
  for (const nu of NEWTRACK) {
    if (new RegExp('\\b' + nu.replace(/\./g, '\\.') + '\\b').test(txt)) {
      violations.push(`O4/C2 BLOCK 生产单元引用新轨: ${u.path} -> ${nu}`);
    }
  }
}

// O1：孤儿须入基线
// 本门的 --emit-baseline 要读旧基线以保留人工 disposition，故基线校验放在 EMIT 之前：
// 不允许在坏基线上重刷（否则 47 条人工标注会退回『待标注』）。
// 写入动作收口在 ../gate-emit-guard.js：新孤儿（基线外新键）由守卫拒绝 EXIT≠0——
// 处置标注只能人工带 reason 登记，自动路径不得把「待标注」当默认值写进冻结基线。
const baseline = loadGateBaseline({
  file: BASELINE_P, label: '构建归属',
  keys: { orphans: 'object' },
});
if (EMIT) {
  const emit = { generatedFrom: 'check_build_ownership.js', orphans: {} };
  for (const o of orphans) emit.orphans[o.path] = baseline.orphans[o.path] && baseline.orphans[o.path].disposition
    ? baseline.orphans[o.path] : { disposition: '待标注', reason: 'TODO' };
  guardedEmitBaseline({
    label: '构建归属', baselinePath: BASELINE_P, root: ROOT, repoRoot: REPO_ROOT,
    allowNarrowRoot: ALLOW_NARROW, scanCount: prodUnits.length,
    entryKeys: ['orphans'], newBaseline: emit, space: 1, trailingNewline: false,
  });
  console.log('baseline emitted: ' + orphans.length + ' orphans');
} else {
  for (const o of orphans) {
    if (!baseline.orphans[o.path]) violations.push(`O1 FAIL 新增孤儿单元（不在基线）: ${o.path} (unit ${o.unit})`);
  }
}

// 违规时同样把覆盖面打出来（与其余四道门同口径）：判据要求「红项不变 + 计数同量级」可核，
// 只在绿单里报计数会让「扫了多大一片」在最需要取证的那次运行里反而看不见。
if (violations.length) {
  console.error(`构建归属门禁失败：生产单元 ${prodUnits.length}，构建文件 ${buildFiles.length}，违规 ${violations.length} 项:`);
  violations.slice(0, 60).forEach(v => console.error('  ' + v));
  process.exit(1);
}
console.log(`构建归属门禁通过：生产单元 ${prodUnits.length}，构建文件 ${buildFiles.length}，孤儿（已登记基线）${orphans.length}`);
