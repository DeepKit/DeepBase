// DeepBase 丙类编码损坏检测门禁（WO-20260924-AUDIT-甲-D8）
//
// 本门把甲 D6 段 1 的一次性脚本（d6_mojibake / skel_proof / LCS 逐行核对）升格为在册门禁。
// 内核在 ../mojibake-core.js（纯函数库）。本文件只负责：枚举 .pas、按四类定性、
// 对【此前无门禁覆盖】的丙-B 结构损坏执法、产出三档留痕标签、与编译门红清单交叉标记。
//
// ── SSOT 边界（段 0 判定，为何本门不对丙-A/丙-C 造第二套违规判据）──────────────
//   .pas 面的丙-A（U+FFFD）= encoding-gate G1 唯一立法；丙-C（双重编码）= encoding-gate G6 唯一立法。
//   CodeReview 证据面的丙-C = evidence-encoding-gate E3 唯一立法（乙 D8）。
//   ⇒ 本门【只】对丙-B（结构性吞 ASCII：Delphi 单引号串跨行未闭合＝终结符被吞）执法——
//     这是 encoding-gate 六条规则（G1/G2/G3/G4/G5/G6）里没有任何一条覆盖的形态。
//   本门的丙-A/丙-C 检测器（countFFFD/detectDoubleEncoding）仅用于：① 对丙-B 命中行做内容定性；
//   ② 驱动「三档留痕」分档；③ 与 encoding-gate 基线交叉核对。它们【不】产生本门的 tree-wide 违规，
//   否则就与 G1/G6 形成会漂移的第二套计数（乙 D8 判据 6 同禁忌）。
//
// ── 四类检测器（工单 §1.1；负向样本四类各 ≥1 红，见 test_negative_sample.js）──────
//   丙-A 有损 U+FFFD        core.countFFFD            —— 定性/交叉核对，违规归 encoding-gate G1
//   丙-B 结构性吞 ASCII      core.scanUnterminatedStrings —— 【本门唯一执法项】，只拦新增
//   丙-C 双重编码乱码        core.detectDoubleEncoding  —— 定性/驱动留痕分档，违规归 encoding-gate G6
//   吞 ASCII 致编译错        --build-red-list 交叉标记  —— 命中文件是否同时落在编译门红清单内（§1.3）
//
// ── 三档留痕强度（工单 §1.2；输出逐条可辨）────────────────────────────────────
//   FULL 整件等值性 : git HEAD 版本本件 丙-B 计数为 0 ⇒ 损坏由工作树引入，补回＝还原到 HEAD 原件，最强。
//   LCS  逐行       : HEAD 仍带损坏，但命中行可 GB18030 逐行逆否还原出可读中文 ⇒ 逐行有权威候选，次之。
//   DIFF 只有 diff  : 既无干净整件祖先、行也不可逆 ⇒ 只能凭本次改动，最弱（还原须外部权威源，归双域分片单）。
//
// ── 存量清单：只减不增（工单 §二「不得用基线把洞盖上」；沿用甲 D6 已证正确立场）────
//   baseline.pbStock = { "<rel>": { count, reason } }。门只拦 count 超过登记值的新增；
//   --emit-baseline 只能【缩短】已登记件，绝不自动新增文件条目（新增必须人工带 reason 写进清单并说明）——
//   该判据的实现收口在 ../gate-emit-guard.js（五道门共用一份，含窄根自证与写前 .bak）。
//
// 用法: node check_mojibake.js [--root <dir>] [--baseline <file>] [--build-red-list <log>]
//                              [--list-hits] [--emit-baseline] [--allow-narrow-root]
// 退出码：0 通过；1 丙-B 新增违规；2 基线不可信/枚举失败；3 扫描自身失败（root 不可读 / 扫到 0 个 .pas /
//        单文件读取失败 / 参数解析失败）——fail-closed，绝不放行。
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { parseGateArgs } = require('../gate-args');
const { gateSkipSet } = require('../gate-skip');
const { loadGateBaseline } = require('../gate-baseline');
const { guardedEmitBaseline } = require('../gate-emit-guard');
const core = require('../mojibake-core');

const OPTS = parseGateArgs(process.argv.slice(2), {
  label: '丙类损坏',
  root: path.join(__dirname, '../..'),
  baseline: path.join(__dirname, 'pb_baseline.json'),
  extra: ['list-hits', 'emit-baseline', 'allow-narrow-root'],
  valued: ['build-red-list'],
});
if (OPTS.flags.has('help')) {
  console.log('用法: node check_mojibake.js [--root <dir>] [--baseline <file>] [--build-red-list <log>] [--list-hits] [--emit-baseline] [--allow-narrow-root]');
  process.exit(0);
}
const REPO = OPTS.root;
const BASELINE_P = OPTS.baseline;
const SKIP = gateSkipSet();

function trackedPas() {
  let out;
  try {
    out = execFileSync('git', ['-C', REPO, '-c', 'core.quotepath=false', 'ls-files', '-z', '--', '*.pas'],
      { encoding: 'buffer', maxBuffer: 64 * 1024 * 1024 });
  } catch (e) {
    // fail-closed：git 枚举失败不得静默当作「无文件=通过」
    console.error(`丙类损坏门禁无法枚举 .pas（git ls-files 失败）: ${e.message}`);
    process.exit(2);
  }
  return out.toString('utf8').split('\0').filter(Boolean)
    .filter(rel => !rel.split('/').slice(0, -1).some(seg => SKIP.has(seg)));
}

const baseline = loadGateBaseline({
  file: BASELINE_P, label: '丙类损坏',
  keys: { pbStock: 'object' },
});
// pbStock 每一项必须是 {count:number>=0, reason:非空串}——reason 缺失即视为「静默加入」，拒绝。
// 这是判据 3「阻止新增条目被静默加入」的第一道：即使有人手改基线，缺 reason 的条目读进来即 EXIT=2。
for (const [rel, v] of Object.entries(baseline.pbStock || {})) {
  if (!v || typeof v !== 'object' || typeof v.count !== 'number' || v.count < 0 ||
      typeof v.reason !== 'string' || v.reason.trim() === '') {
    console.error(`丙类损坏门禁失败：存量条目非法（须为 {count, reason}，reason 非空说明为何豁免）: ${rel}`);
    process.exit(2);
  }
}

const files = trackedPas();
// 空扫描即失败：仓库内必有 .pas；扫到 0 个说明 root 指错或 SKIP 吃掉了源码树。
if (files.length === 0) {
  console.error(`丙类损坏门禁失败：扫描 0 个 .pas（root=${REPO}）。已按 fail-closed 拒绝放行。`);
  process.exit(3);
}

// 编译门红清单交叉标记（§1.3 / 判据 6）：读 check_build.js 原始输出，抽出被点名为编译失败的单元/工程 basename。
// 缺省未提供时输出「未提供」，不影响执法（交叉标记是最低要求的可见性，非违规源）。
let redSet = null;
const redListArg = (OPTS.values.get('build-red-list') || [])[0];
if (redListArg) {
  redSet = new Set();
  let txt;
  try { txt = fs.readFileSync(path.resolve(REPO, redListArg), 'utf8'); }
  catch (e) { console.error(`丙类损坏门禁失败：--build-red-list 读取失败 ${redListArg} (${e.message})`); process.exit(3); }
  // check_build 红行形如 `  <rel> 编译失败：<firstError>` / `  <rel> EXIT=.. <firstError>`；
  // firstError 常引用具体单元 `DeepBase.X.pas(123) Error E2065 ...`。两种都收 basename。
  for (const ln of txt.split('\n')) {
    const m = ln.match(/(\S+\.(?:pas|dpr|dpk))(?:\(\d+\))?/i);
    if (m && /编译失败|EXIT=[^0]|Error|Fatal/i.test(ln)) redSet.add(path.basename(m[1]).toLowerCase());
  }
}
function buildRedMark(rel) {
  if (redSet === null) return '编译红=未提供';
  return redSet.has(path.basename(rel).toLowerCase()) ? '编译红=是' : '编译红=否';
}

// git HEAD 版本（缓存），供 FULL/LCS/DIFF 分档取整件祖先
const headCache = new Map();
function headText(rel) {
  if (headCache.has(rel)) return headCache.get(rel);
  let t = null;
  try { t = execFileSync('git', ['-C', REPO, 'show', `HEAD:${rel}`], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }); }
  catch (e) { t = null; } // HEAD 无此件（新文件）⇒ 无整件祖先，分档降级
  headCache.set(rel, t);
  return t;
}

const rev = core.gbkReverseTable(); // null ⇒ 本机无 GB18030，丙-C 定性与 LCS 分档不可评估（明示，不静默）
const hits = [];          // 全部丙-B 命中明细（含存量登记件：看得见才谈得上递减）
const perFile = new Map(); // rel → 命中数
const violations = [];
for (const rel of files) {
  let text;
  try { text = fs.readFileSync(path.join(REPO, rel), 'utf8'); }
  catch (e) { console.error(`丙类损坏门禁失败：读取失败 ${rel} (${e.message})`); process.exit(3); }
  const events = core.scanUnterminatedStrings(text);
  if (!events.length) continue;
  perFile.set(rel, events.length);
  const lines = text.split('\n');
  const head = headText(rel);
  const headEvents = head === null ? null : core.scanUnterminatedStrings(head).length;
  const tag = buildRedMark(rel);
  // 一个被吞的闭合引号会翻转整件后续引号奇偶 ⇒ 级联出多行"未闭合"假象。
  // 真正的损坏【根】= 起始行自身含非 ASCII（mojibake 串把终结符吃掉了）；纯 ASCII 起始行的事件是级联后果。
  // 计数指标用事件总数（任何新增奇偶错位都会抬动它，兜住罕见的纯 ASCII 吞引号）；
  // 明细只展开【根】并标注其级联跨度，保证判据 2「准确定位到文件:行」不被级联噪声淹没。
  let cascadeRun = 0;
  for (let k = 0; k < events.length; k++) {
    const ev = events[k];
    const line = lines[ev.open] || '';
    const isRoot = /[^\x00-\x7F]/.test(line);
    if (!isRoot) { cascadeRun++; continue; }
    // 向前收集本根之后、下一个根之前的级联跨度
    let j = k + 1;
    while (j < events.length && !/[^\x00-\x7F]/.test(lines[events[j].open] || '')) j++;
    const fffd = core.countFFFD(line);
    const dbl = rev ? core.detectDoubleEncoding(line, rev) : null;
    let tier;
    if (headEvents === 0) tier = 'FULL';               // 整件祖先干净 ⇒ 还原=回到 HEAD
    else if (dbl) tier = 'LCS';                         // 行可逐行逆否还原 ⇒ 逐行有权威候选
    else tier = 'DIFF';                                 // 无干净整件祖先且不可逆 ⇒ 只有 diff
    const cls = [`丙-B@L${ev.open + 1}->L${ev.close + 1}`];
    if (fffd) cls.push(`丙-A(U+FFFD×${fffd};违规归encoding-gate G1)`);
    if (dbl) cls.push(`丙-C(→「${dbl.restored.trim().slice(0, 40)}」;违规归encoding-gate G6)`);
    if (!rev && core.CJK_RE.test(line)) cls.push('丙-C未评(本机无GB18030)');
    const span = events.slice(k + 1, j).length + cascadeRun;
    hits.push(`${rel}:${ev.open + 1}: [${tier}] ${cls.join(' ')} ${tag}${span ? `（下承级联 ${span} 处至 L${(events[j - 1] || ev).close + 1}）` : ''}\n      现场: ${line.trim().slice(0, 100)}`);
    cascadeRun = 0;
    k = j - 1;
  }
  const cap = rel in baseline.pbStock ? baseline.pbStock[rel].count : 0;
  if (events.length > cap) {
    violations.push(`丙-B 结构性吞ASCII ${events.length} 处 > 存量 ${cap}（清单外新文件即新增）。门只拦新增，存量只减不增；逐件还原归双域分片单，本单只做看得见: ${rel}`);
  }
}

if (OPTS.flags.has('list-hits')) {
  hits.forEach(h => console.log(h));
  console.log(`# 扫描 ${files.length} 个 .pas / 丙-B 命中 ${hits.length} 处 / ${perFile.size} 件`);
  process.exit(0);
}

if (OPTS.flags.has('emit-baseline')) {
  // 只减不增统一走 ../gate-emit-guard.js：新增键（未登记文件）与 count 抬升一律拒绝 EXIT≠0，
  // 已登记件按当前实测下调；窄根自证与写前 .bak 同在守卫里（五道门一份判据）。
  const before = Object.keys(baseline.pbStock || {}).length;
  const stock = { ...(baseline.pbStock || {}) };
  for (const [rel, n] of perFile) stock[rel] = { ...stock[rel], count: n };
  const out = {
    generated: new Date().toISOString(),
    generatedFrom: `全量扫描 ${files.length} 个 tracked .pas（丙-B 结构性吞 ASCII 存量，只减不增）`,
    _comment: 'DeepBase 丙-B 存量清单（WO-20260924-AUDIT-甲-D8）。每条目 count 为该文件跨行未闭合串的事件数，门只拦超过 count 的新增。reason 说明该存量为何存在、归属哪张还原单。新增条目须人工带 reason，不得由 emit 自动生成。',
    pbStock: stock,
  };
  const cmp = guardedEmitBaseline({
    label: '丙类损坏', baselinePath: BASELINE_P, root: REPO,
    repoRoot: path.resolve(path.join(__dirname, '../..')),
    allowNarrowRoot: OPTS.flags.has('allow-narrow-root'), scanCount: files.length,
    entryKeys: ['pbStock'], newBaseline: out,
  });
  console.log(`已写出存量清单：${BASELINE_P}（条目 ${before}→${Object.keys(stock).length}，只减不增：新增 0 / 抬升 0，计数下调 ${cmp.decreased}）`);
  process.exit(0);
}

if (violations.length) {
  console.error(`丙类损坏门禁失败：扫描 ${files.length} 个 .pas，丙-B 命中 ${hits.length} 处（${perFile.size} 件），违规 ${violations.length} 项:`);
  violations.forEach(v => console.error('  ' + v));
  process.exit(1);
}
const stockN = Object.keys(baseline.pbStock || {}).length;
const totalStock = Object.values(baseline.pbStock || {}).reduce((s, v) => s + v.count, 0);
console.log(`丙类损坏门禁通过：扫描 ${files.length} 个 .pas，丙-B 命中 ${hits.length} 处（${perFile.size} 件），全部在存量清单 ${stockN} 件 / ${totalStock} 处封顶内（只减不增）；编译红交叉标记=${redSet ? `已载入 ${redSet.size} 个红项` : '未提供'}`);
if (hits.length) {
  console.log('丙-B 命中明细（[档位]=三档留痕强度 FULL>LCS>DIFF；丙-A/丙-C 仅定性，违规归 encoding-gate）:');
  hits.forEach(h => console.log('  ' + h));
}
