// DeepBase 消费者契约门禁（WO-20260924-AUDIT-甲-D9 段2 / 外单 DB-004）
//
// 目的：DeepBase 被 30+ 兄弟项目共享，但「哪些单元是稳定 API」此前无人登记，
//   消费者只能各自反向工程。本门把契约显式化并让它可机器执法：
//   ① 校验 contract/consumer-contract.json 结构（字段齐全、stability 合法）；
//   ② 交叉核对契约声明的每个单元在仓内【存在且仅一份】（重复即分叉前兆）；
//   ③ 对 stability=stable 单元做【公开签名变更检测】：与上次发布快照（signature-baseline.json）比对，
//      消失或被改写的公开声明 = 破坏性变更 → 门禁红，须记 CHANGELOG 并重新生成基线（发版动作）。
//
// ── 为何执法读 git 对象而非工作树（共享树结论无效）──────────────────────────────
//   判定统一走 `git show HEAD:<path>`（或 --source <ref>），不读工作树文件。
//   他人未提交的在途改动不得污染本门结论；基线也是某 ref 的快照，两侧同为 git 对象才可比。
//   （负向样本用 --source worktree + --root <tmp> 定向构造，见 test_negative_sample.js。）
//
// ── 签名抽取的保守立场 ────────────────────────────────────────────────────────
//   把 interface→implementation 段去掉注释后按 `;` 切分为声明块，逐块归一空白即为一条「签名」。
//   Delphi 单元只导出 interface 段的声明 ⇒ 这是消费者可见面的保守超集：
//   重命名/改类型/删除公开成员 ⇒ 某块消失或改写 = 破坏；新增公开成员 ⇒ 只报不拦。
//   宁可偏保守（多触发一次 CHANGELOG 复核），不做会漏的细粒度语法解析。
//
// 用法: node check_contract.js [--root <dir>] [--contract <file>] [--baseline <file>]
//                              [--source <HEAD|ref|worktree>] [--only <unit>] [--emit-baseline]
// 退出码：0 通过；1 破坏性签名变更 / 契约单元缺失或重复；2 基线缺失或非法 / stability 枚举非法；
//        3 扫描或 git 读取自身失败（fail-closed，绝不放行）。
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { parseGateArgs } = require('../gate-args');

const OPTS = parseGateArgs(process.argv.slice(2), {
  label: '契约',
  root: path.join(__dirname, '../..'),
  baseline: path.join(__dirname, 'signature-baseline.json'),
  extra: ['emit-baseline'],
  valued: ['source', 'only', 'contract'],
});
if (OPTS.flags.has('help')) {
  console.log('用法: node check_contract.js [--root <dir>] [--contract <file>] [--baseline <file>] [--source <HEAD|ref|worktree>] [--only <unit>] [--emit-baseline]');
  process.exit(0);
}

const REPO = OPTS.root;
const SOURCE = (OPTS.values.get('source') || [])[0] || 'HEAD';
const ONLY = (OPTS.values.get('only') || [])[0] || null;
const CONTRACT_P = path.resolve(REPO, (OPTS.values.get('contract') || [])[0] || 'contract/consumer-contract.json');
const BASELINE_P = OPTS.baseline;
const STABILITIES = new Set(['stable', 'internal', 'deprecated']);

function readTracked(rel) {
  if (SOURCE === 'worktree') {
    try { return fs.readFileSync(path.join(REPO, rel), 'utf8'); }
    catch (e) { console.error(`契约门禁失败：读取工作树失败 ${rel} (${e.message})`); process.exit(3); }
  }
  try {
    return execFileSync('git', ['-C', REPO, 'show', `${SOURCE}:${rel}`],
      { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  } catch (e) {
    console.error(`契约门禁失败：git show ${SOURCE}:${rel} 失败（${SOURCE} 不存在该文件或 ref 无效）: ${e.message}`);
    process.exit(3);
  }
}

// 载入契约（读工作树：契约是本门要执法的配置，非被检代码；缺失即失败）
let contract;
try {
  contract = JSON.parse(fs.readFileSync(CONTRACT_P, 'utf8'));
} catch (e) {
  console.error(`契约门禁失败：无法读取/解析契约 ${CONTRACT_P}: ${e.message}`);
  process.exit(3);
}
if (!Array.isArray(contract.units) || contract.units.length === 0) {
  console.error('契约门禁失败：契约缺 units 数组或为空。');
  process.exit(2);
}

// ── ① 结构校验 ──────────────────────────────────────────────────────────────
const structural = [];
const seen = new Set();
for (const u of contract.units) {
  const id = u && typeof u.unit === 'string' ? u.unit : JSON.stringify(u).slice(0, 40);
  for (const f of ['unit', 'subdir', 'stability', 'consumers', 'breaking_change_policy']) {
    if (u[f] === undefined || u[f] === '') structural.push(`单元 ${id} 缺字段 ${f}`);
  }
  if (typeof u.stability === 'string' && !STABILITIES.has(u.stability)) {
    structural.push(`单元 ${id} stability 非法: ${u.stability}（须为 ${[...STABILITIES].join('|')}）`);
  }
  if (seen.has(u.unit)) structural.push(`契约内单元重复: ${u.unit}`);
  seen.add(u.unit);
}
if (structural.length) {
  console.error(`契约门禁失败：契约结构非法 ${structural.length} 项:`);
  structural.forEach(s => console.error('  ' + s));
  process.exit(2);
}

// ── ② 单元存在且仅一份 ──────────────────────────────────────────────────────
//   默认（--source HEAD|ref）查 git 索引：与工作树在途改动无关。
//   --source worktree 查文件系统：供本地开发与负向样本构造隔离树用（此时整门以 worktree 为准）。
function listPasFiles(root) {
  const found = [];
  (function walk(dir) {
    let ents;
    try { ents = fs.readdirSync(dir, { withFileTypes: true }); }
    catch (e) { console.error(`契约门禁失败：readdir 失败 ${dir} (${e.message})`); process.exit(3); }
    for (const ent of ents) {
      const full = path.join(dir, ent.name);
      if (ent.isDirectory()) { if (ent.name !== '.git') walk(full); }
      else if (ent.name.endsWith('.pas')) found.push(path.relative(root, full).split(path.sep).join('/'));
    }
  })(root);
  return found;
}
let pasFilesCache = null;
function trackedCopies(unit) {
  if (SOURCE === 'worktree') {
    if (pasFilesCache === null) pasFilesCache = listPasFiles(REPO);
    return pasFilesCache.filter(p => path.basename(p) === `${unit}.pas`);
  }
  let out;
  try {
    out = execFileSync('git', ['-C', REPO, '-c', 'core.quotepath=false', 'ls-files', '-z', '--', `**/${unit}.pas`],
      { encoding: 'buffer', maxBuffer: 64 * 1024 * 1024 });
  } catch (e) {
    console.error(`契约门禁失败：git ls-files 枚举 ${unit} 失败: ${e.message}`);
    process.exit(3);
  }
  return out.toString('utf8').split('\0').filter(Boolean);
}

// ── ③ 签名抽取 ────────────────────────────────────────────────────────────────
function stripComments(text) {
  return text
    .replace(/\{[\s\S]*?\}/g, ' ')
    .replace(/\(\*[\s\S]*?\*\)/g, ' ')
    .replace(/\/\/[^\n]*/g, ' ');
}
function extractInterface(text) {
  const t = stripComments(text);
  const i = t.search(/^\s*interface\s*$/mi);
  const j = t.search(/^\s*implementation\s*$/mi);
  if (i < 0) return '';
  const start = t.slice(i).indexOf('\n') + i + 1;
  return j > i ? t.slice(start, j) : t.slice(start);
}
function signatures(text) {
  const iface = extractInterface(text);
  const set = new Set();
  for (let chunk of iface.split(';')) {
    const norm = chunk.replace(/\s+/g, ' ').trim();
    if (norm) set.add(norm);
  }
  return set;
}

const targets = ONLY ? contract.units.filter(u => u.unit === ONLY) : contract.units;
if (ONLY && targets.length === 0) {
  console.error(`契约门禁失败：--only ${ONLY} 不在契约内。`);
  process.exit(2);
}

const current = {}; // unit → { rel, sigs:[...] sorted }
const dupMissing = [];
for (const u of targets) {
  const copies = trackedCopies(u.unit);
  const want = `${u.subdir}/${u.unit}.pas`;
  if (!copies.includes(want)) {
    dupMissing.push(`契约声明 ${u.unit}@${u.subdir} 但 git 索引无 ${want}（实际: ${copies.join(', ') || '无'}）`);
    continue;
  }
  if (copies.length > 1) {
    dupMissing.push(`单元 ${u.unit} 存在多份（分叉前兆）: ${copies.join(', ')}`);
    continue;
  }
  const sigs = [...signatures(readTracked(want))].sort();
  current[u.unit] = { rel: want, sigs };
}
if (dupMissing.length) {
  console.error(`契约门禁失败：单元存在性/唯一性违规 ${dupMissing.length} 项:`);
  dupMissing.forEach(d => console.error('  ' + d));
  process.exit(1);
}

// ── emit-baseline：把当前签名集写为发布快照（发版动作的一部分）──────────────────
if (OPTS.flags.has('emit-baseline')) {
  let old = { units: {} };
  if (fs.existsSync(BASELINE_P)) {
    try { old = JSON.parse(fs.readFileSync(BASELINE_P, 'utf8')); }
    catch (e) { console.error(`契约门禁失败：现有基线不可解析 ${BASELINE_P}: ${e.message}`); process.exit(2); }
  }
  const units = { ...(old.units || {}) };
  for (const [unit, v] of Object.entries(current)) {
    units[unit] = { rel: v.rel, stability: (targets.find(t => t.unit === unit) || u0(unit)).stability, sigs: v.sigs };
  }
  function u0(unit) { return contract.units.find(x => x.unit === unit) || { stability: 'unknown' }; }
  const out = {
    generated: new Date().toISOString(),
    generatedFrom: `git show ${SOURCE}（stability=stable 单元的 interface 公开签名快照，随每次发布重新生成并提交）`,
    _comment: 'DeepBase 消费者契约签名基线（WO-20260924-AUDIT-甲-D9 段2）。发版时对本发布 ref 重新生成本文件并提交，即成为「上一次发布」的对照面。门只拦基线内公开签名被改写/删除者。',
    units,
  };
  fs.writeFileSync(BASELINE_P, JSON.stringify(out, null, 2) + '\n', 'utf8');
  console.log(`已写出签名基线：${BASELINE_P}（本次覆盖 ${Object.keys(current).length} 个单元）`);
  process.exit(0);
}

// ── 比对：stable 单元公开签名不得消失/改写 ─────────────────────────────────────
let baseline;
if (!ONLY) {
  try { baseline = JSON.parse(fs.readFileSync(BASELINE_P, 'utf8')); }
  catch (e) { console.error(`契约门禁失败：签名基线缺失或不可解析 ${BASELINE_P}: ${e.message}（发版时应 --emit-baseline 生成）`); process.exit(2); }
  if (!baseline.units || typeof baseline.units !== 'object') {
    console.error('契约门禁失败：基线缺 units 映射。'); process.exit(2);
  }
} else {
  // --only 模式：无基线则只报当前签名，不做破坏判定（供 emit/构造样本用）
  if (fs.existsSync(BASELINE_P)) { try { baseline = JSON.parse(fs.readFileSync(BASELINE_P, 'utf8')); } catch (e) { baseline = { units: {} }; } }
  else baseline = { units: {} };
}

const breaking = [];
const additive = [];
for (const u of contract.units.filter(x => x.stability === 'stable')) {
  if (!(u.unit in current)) continue; // --only 未覆盖
  const base = (baseline.units || {})[u.unit];
  if (!base) { breaking.push(`stable 单元 ${u.unit} 不在基线内（新纳入稳定的单元须发版时写入基线）`); continue; }
  const bset = new Set(base.sigs || []), cset = new Set(current[u.unit].sigs);
  const removed = [...bset].filter(s => !cset.has(s));
  const added = [...cset].filter(s => !bset.has(s));
  if (removed.length) breaking.push(`${u.unit}: 公开签名消失/改写 ${removed.length} 处（须记 CHANGELOG 并重新生成基线）:\n      ` + removed.slice(0, 8).join('\n      '));
  if (added.length) additive.push(`${u.unit}: 新增公开签名 ${added.length} 处（向后兼容，仅提示）`);
}

if (breaking.length) {
  console.error(`契约门禁失败：扫描 ${contract.units.length} 单元，stable 破坏性变更 ${breaking.length} 项:`);
  breaking.forEach(b => console.error('  ' + b));
  process.exit(1);
}
const stableN = contract.units.filter(x => x.stability === 'stable').length;
console.log(`契约门禁通过：${contract.units.length} 单元（stable ${stableN}），单份核对无误，stable 公开签名与基线一致。`);
if (additive.length) { console.log('向后兼容新增（不拦）:'); additive.forEach(a => console.log('  ' + a)); }
