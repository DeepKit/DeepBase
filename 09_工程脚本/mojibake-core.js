// DeepBase 丙类编码损坏检测内核（WO-20260924-AUDIT-甲-D8 §1.1）
//
// 为什么单独成模块（SSOT 边界，段 0 判定）：
//   .pas 面的丙-A（U+FFFD）/ 丙-C（双重编码）已由 encoding-gate G1/G6 唯一立法，
//   CodeReview 证据面的丙-C 由 evidence-encoding-gate E3 唯一立法（乙 D8）。
//   本内核不重造那两套判据，只承载【此前没有任何门禁覆盖】的能力：
//     · 丙-B（结构性吞 ASCII：Delphi 单引号串跨行未闭合 = 终结符被吞）——新面，唯一立法在本内核的使用方 mojibake-gate；
//     · 三档留痕强度分档（整件等值性 > LCS 逐行 > 只有 diff）——补回件相对 git 祖先的证据强度定级；
//   并复用同一份表意文字面/GB18030 反表，供 mojibake-gate 对损坏点做【定性分类】（丙-A/丙-C 只标注、不判违规，
//   违规仍归 encoding-gate），避免把 G6/E3 的判据抄成第三份会漂移的副本。
//
// 本模块是纯函数库：不读参数、不 exit、不碰 process.exitCode。退出码语义由调用方（mojibake-gate）产出。
'use strict';

// ── 表意文字面（与 evidence-encoding-gate 同口径：基本区 + 扩展 A + 兼容表意，比 .pas 门 G6 更宽）──
const IDEOGRAPH_RANGES = [[0x3400, 0x4DBF], [0x4E00, 0x9FFF], [0xF900, 0xFAFF]];
function isIdeographic(cp) { return IDEOGRAPH_RANGES.some(([lo, hi]) => cp >= lo && cp <= hi); }
const CJK_RE = new RegExp('[' + IDEOGRAPH_RANGES.map(([lo, hi]) =>
  '\\u' + lo.toString(16).padStart(4, '0') + '-\\u' + hi.toString(16).padStart(4, '0')).join('') + ']');

// ── GB18030 反表（Unicode 字符 → GB18030 双字节），供丙-C 可逆性试探 ──
// 用 gb18030 而非 gbk：主控实测 encode('gbk') 在本仓头号样本（含 U+E6E6 GB18030 PUA 区）直接抛异常 ⇒ 漏检。
// 反表按双字节面全枚举 GB18030 解码结果构建；解码为 U+FFFD 的非法双字节不入表（否则表外字符会被"编"回去造出假可逆）。
let GB_REV = null;
function gbkReverseTable() {
  if (GB_REV) return GB_REV;
  let dec;
  try { dec = new TextDecoder('gb18030'); } catch (e) { return null; } // 调用方按 fail-closed 处理
  GB_REV = new Map();
  for (let b0 = 0x81; b0 <= 0xFE; b0++) {
    for (let b1 = 0x40; b1 <= 0xFE; b1++) {
      if (b1 === 0x7F) continue;
      const s = dec.decode(Uint8Array.of(b0, b1));
      if (s === '\uFFFD') continue;
      if (s.length === 1 && !GB_REV.has(s)) GB_REV.set(s, [b0, b1]);
    }
  }
  return GB_REV;
}

// 丙-C 阈值（沿用乙 D8 在证据面标定出的同一组常量，语义一致，非本门另拍）：
const MIN_RESTORED_UNITS = 4;
const MAX_BROKEN_RATIO = 0.20;
const MIN_RESTORED_CJK_RATIO = 0.5;
function scanRestored(restored) {
  let clean = 0, cleanCjk = 0, broken = 0;
  for (const ch of restored) {
    const cp = ch.codePointAt(0);
    if (cp < 0x80) continue;
    if (cp === 0xFFFD) { broken++; continue; }
    clean++;
    if (isIdeographic(cp)) cleanCjk++;
  }
  return { clean, cleanCjk, broken };
}
/**
 * 丙-C 双重编码试探：命中返回 {restored, clean, broken}，否则 null。
 * rev 由调用方一次性取得（gbkReverseTable()）；rev=null 表示本机无 GB18030，调用方须 fail-closed。
 */
function detectDoubleEncoding(line, rev) {
  if (!rev || !CJK_RE.test(line)) return null;
  const bytes = [];
  for (const ch of line) {
    const cp = ch.codePointAt(0);
    if (cp < 0x80) { bytes.push(cp); continue; }
    const pair = rev.get(ch);
    if (!pair) return null; // 表外字符 ⇒ 不可能是 GBK 误读产物
    bytes.push(pair[0], pair[1]);
  }
  const restored = Buffer.from(bytes).toString('utf8');
  if (restored === line) return null;
  const { clean, cleanCjk, broken } = scanRestored(restored);
  const total = clean + broken;
  if (total === 0 || clean < MIN_RESTORED_UNITS) return null;
  if (broken / total > MAX_BROKEN_RATIO) return null;   // 不可逆损坏 → 丙-A/丙-B 面，本判据放行不判
  if (cleanCjk / clean < MIN_RESTORED_CJK_RATIO) return null; // 还原出拉丁/音标 ⇒ 2 字节链巧合，非双编码
  return { restored, clean, broken };
}

// 丙-A：行内含 U+FFFD（有损替换）。返回替换符个数（0 = 干净）。违规判定归 encoding-gate，本内核只做定位/分类。
// 用 \uFFFD 转义而非字面替换符：门禁自身源码若被误转码，判据也不会静默漂移（同 evidence 门 IDEOGRAPH_RANGES 的理由）。
function countFFFD(line) {
  let n = 0;
  for (const ch of line) if (ch.codePointAt(0) === 0xFFFD) n++;
  return n;
}

/**
 * 丙-B（结构性吞 ASCII）：扫整份 .pas 文本，返回【跨行的单引号串】事件列表。
 * Delphi 字符串字面量不得含裸换行——一行结束仍是未闭合串，即终结符被吞（doQry 61 行同型）。
 * 先按文件级状态机剥 // 行注释、{ } 块注释（含 {$IFDEF} 指令）、(* *)，再按 '' 转义配对单引号。
 * 事件按【串起始行】归属（一次吞符只算一处，不因后续乱码级联多计），close>open 才成立。
 * @returns {Array<{open:number, close:number}>} 0-based 行号
 */
function scanUnterminatedStrings(text) {
  const events = [];
  let line = 0, i = 0;
  let inLine = false, inBrace = false, inParen = false, inStr = false;
  let strStart = -1;
  const n = text.length;
  while (i < n) {
    const c = text[i];
    const d = text[i + 1];
    if (c === '\n') {
      if (inStr) { /* 串跨到下一行：不在此结事件，等闭合时统一按 open/close 行判定 */ }
      inLine = false; line++; i++; continue;
    }
    if (inLine) { i++; continue; }
    if (inStr) {
      if (c === "'") {
        if (d === "'") { i += 2; continue; }        // '' 转义，仍在串内
        if (line > strStart) events.push({ open: strStart, close: line });
        inStr = false; i++; continue;
      }
      i++; continue;
    }
    if (inBrace) { if (c === '}') inBrace = false; i++; continue; }
    if (inParen) { if (c === '*' && d === ')') { inParen = false; i += 2; continue; } i++; continue; }
    if (c === '/' && d === '/') { inLine = true; i += 2; continue; }
    if (c === '{') { inBrace = true; i++; continue; }
    if (c === '(' && d === '*') { inParen = true; i += 2; continue; }
    if (c === "'") { inStr = true; strStart = line; i++; continue; }
    i++;
  }
  if (inStr && line > strStart) events.push({ open: strStart, close: line }); // EOF 仍未闭合
  return events;
}

// ── 三档留痕强度（1.2）：给定损坏行的"当前文本"与其 git 祖先候选文本，定级补回证据强度 ──
// 整件等值性 (FULL)：当前件去掉损坏区后与祖先逐字节相等 ⇒ 补回有祖先原件背书，最强。
// LCS 逐行 (LCS) ：损坏行能在祖先里找到唯一对应行（祖先那行是可读中文且非损坏），次之。
// 只有 diff (DIFF)：祖先不可得/无对应 ⇒ 仅凭本次改动 diff，最弱。
function lcsLen(a, b) {
  const m = a.length, n2 = b.length;
  if (!m || !n2) return 0;
  let prev = new Uint32Array(n2 + 1), cur = new Uint32Array(n2 + 1);
  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n2; j++) {
      cur[j] = a[i - 1] === b[j - 1] ? prev[j - 1] + 1 : Math.max(prev[j], cur[j - 1]);
    }
    [prev, cur] = [cur, prev]; cur.fill(0);
  }
  return prev[n2];
}
/**
 * @param {string} current 当前（疑损坏）整件文本
 * @param {string|null} ancestor git 祖先整件文本；null=无祖先
 * @param {Array<{open:number}>} damage 损坏事件
 */
function gradeEvidenceStrength(current, ancestor, damage) {
  if (ancestor === null || ancestor === undefined) return 'DIFF';
  if (current === ancestor) return 'FULL'; // 整件与祖先一致（本次未改坏）
  const cl = current.split('\n'), al = ancestor.split('\n');
  let allMatch = true;
  for (const ev of damage) {
    const line = cl[ev.open] || '';
    // 该损坏行能在祖先里找到唯一、且自身不含损坏（无 U+FFFD、非跨行串起点重复）的对应行 ⇒ LCS 逐行可核
    const cand = al.filter(a => a.trim() === line.trim());
    if (cand.length !== 1) { allMatch = false; break; }
  }
  // LCS 覆盖率高（≥0.98 公共行）⇒ 至少是逐行可对齐
  const common = lcsLen(cl, al);
  const cov = Math.max(cl.length, al.length) || 1;
  if (allMatch && damage.length) return 'LCS';
  if (common / cov >= 0.98) return 'LCS';
  return 'DIFF';
}

module.exports = {
  IDEOGRAPH_RANGES, CJK_RE, isIdeographic,
  gbkReverseTable, detectDoubleEncoding, countFFFD,
  scanUnterminatedStrings, gradeEvidenceStrength, lcsLen,
  MIN_RESTORED_UNITS, MAX_BROKEN_RATIO, MIN_RESTORED_CJK_RATIO,
};
