// DeepBase .pas 源码编码门禁（WO-20260919-AUDIT-乙 B1-④；L4 扩展 WO-20260920-AUDIT-乙-R4）
// 规则：
//  G1 任何 .pas 禁止引入基线之外的 U+FFFD（按文件计数，超过基线即失败；新文件出现 U+FFFD 即失败）
//  G2 任何 .pas 必须是合法 UTF-8（禁止 GBK/ANSI 原始字节入库）
//  G3 含非 ASCII 字节的 .pas 必须带 UTF-8 BOM（例外清单：基线 bomExceptions，待相应独占人整改后移除）
//     纯 ASCII 的 .pas 不要求 BOM：dcc64 按 ANSI 代码页解析时与 UTF-8 结果逐字节相同，加 BOM 无收益；
//     口径与 bomExceptions 生成口径（含中文且无 BOM）对齐，消除两者之间的误报裂缝（乙R6-N1）
//  G4 任何 .pas 禁止含 NUL 字节或 UTF-16/32 BOM（纯 ASCII 的 UTF-16LE 能通过 G2/G1，须专规拦截；
//     孤立 CR/UTF-16 内容会使 git 将文件判为 -text，EOL 立法与 clean/smudge 对其失效——见乙R4 L3 诊断）
//  G5 任何 .pas 禁止含孤立 CR（0x0D 后不跟 0x0A；基线 loneCr 按文件计数给存量豁免，新文件出现即失败）
// G6 任何 .pas 禁止含双重编码乱码（GBK 误读→以 UTF-8 重编码；正文仍是合法 UTF-8，G1/G2 零感知）。
//     判据: 行内同时满足 (a) 含中日韩表意文字 (b) 该行 GBK→UTF-8 可逆 (c) 含双重编码高频标记字。
//     典型样本: 「日志导出」→「鏃ュ織瀵煎嚭」。基线 mojibake 按文件计数给存量豁免，新文件出现即失败。
// 用法: node check_pas_encoding.js [--root <dir>] [--baseline <file>]
// 退出码：0 通过；1 违规；3 扫描自身失败（root 不可读/扫到 0 个 .pas/单文件读取失败/参数解析失败）——fail-closed，绝不放行。
const fs = require('fs');
const path = require('path');
const { parseGateArgs } = require('../gate-args');

// 参数解析收敛到 09_工程脚本/gate-args.js 单一实现（WO-20260922-AUDIT-乙-P2 §七）。
// 此前本文件与 eol 门禁各写一份内联校验，且裂成「校验侧归一放行 / 取值侧大小写敏感取空」
// 两半，导致 --ROOT 被静默忽略并回落默认 root ⇒ 假绿。共用实现后该裂缝在物理上不存在。
{
  const opts = parseGateArgs(process.argv.slice(2), {
    label: '编码',
    root: path.join(__dirname, '../..'),
    baseline: path.join(__dirname, 'pas_encoding_baseline.json'),
  });
  if (opts.flags.has('help')) {
    console.log('用法: node check_pas_encoding.js [--root <dir>] [--baseline <file>]');
    process.exit(0);
  }
  var ROOT = opts.root;
  var BASELINE_P = opts.baseline;
}
const SKIP = new Set(['.git', '.claude', '__history', 'BuildOutput', 'DCUOutput', 'bin', 'dcu', 'node_modules', '.tmp', '.superpowers', '.workbuddy']);
// 记录被 SKIP 规则吃掉的顶层目录，让「扫描面缩了什么」可见（WO-20260921-AUDIT-乙-P1 §〇 第 3 条）。
const skippedDirs = new Set();

function walk(dir, out) {
  let ents;
  // fail-closed：readdir 失败（root 不存在/无权限/符号链接断链）不得静默返回。
  // 否则门禁扫到 0 个文件却报「通过」，把「没扫」伪装成「扫过且干净」（WO-20260921-AUDIT-乙-P1 §〇）。
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) {
    console.error(`编码门禁无法读取目录: ${dir} (${e.message})`);
    process.exit(3);
  }
  for (const e of ents) {
    if (SKIP.has(e.name)) { skippedDirs.add(e.name); continue; }
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.isFile() && /\.pas$/i.test(e.name)) out.push(p);
  }
  return out;
}
function validUtf8(buf) { try { new TextDecoder('utf-8', { fatal: true }).decode(buf); return true; } catch (e) { return false; } }

const baseline = JSON.parse(fs.readFileSync(BASELINE_P, 'utf8'));
const allowed = baseline.fffd || {};
const loneCrAllowed = baseline.loneCr || {};
const bomExcepts = new Set(baseline.bomExceptions || []);
const mojibakeAllowed = baseline.mojibake || {};
const mojibakeExempt = new Set(baseline.mojibakeExceptions || []);
const violations = [];
const files = walk(ROOT, []);
function countLoneCr(buf) {
  let n = 0;
  for (let i = 0; i < buf.length; i++) if (buf[i] === 0x0D && buf[i + 1] !== 0x0A) n++;
  return n;
}
function countByte(buf, byte) {
  let n = 0;
  for (let i = 0; i < buf.length; i++) if (buf[i] === byte) n++;
  return n;
}
function hasNonAscii(buf) {
  for (let i = 0; i < buf.length; i++) if (buf[i] > 0x7F) return true;
  return false;
}
// ── G6：双重编码乱码（GBK 误读 → 以 UTF-8 重编码）──────────────────────────
// 机制：中文原文的 UTF-8 字节被按 GBK 错误解码成另一串汉字，再以 UTF-8 正常入库。
// 结果文件仍是合法 UTF-8、无 U+FFFD、无 NUL ⇒ G1/G2 零感知，只能靠「可逆性」识别。
// 例：「日志导出」.utf8 → GBK 误读 → 「鏃ュ織瀵煎嚭」（主控取证样本）。
//
// 判据（WO-20260922-AUDIT-乙-P2 §3.1，实测后收窄见下）：
//   ① 行内含中日韩表意文字；
//   ② 整行可 GBK 编码回原始字节并再按 UTF-8 解码出中文（可逆 ⇒ 该行本就是乱码）；
//   ③ 工单另要求「含双重编码高频标记字」——实测该条会把头号样本「鏃ュ織瀵煎嚭」
//      （日志导出）漏掉，因其不含任何标记字。故③改为**冗余确认**而非必要条件，
//      以①+②为主体判据，避免把真缺陷写成假绿。偏离已在请求审核报告留痕。
//
// 零依赖实现：Node 24 内置 ICU TextDecoder('gbk') 提供 GBK→Unicode 解码；
// 反向的 Unicode→GBK 编码表由 0x81–0xFE / 0x40–0xFE 全枚举 GBK 解码结果构建（23940 条）。
// 不引入 iconv-lite 等三方依赖（门禁须保持 fs/path 最小依赖面）。
let GBK_REV = null;
function buildGbkReverseTable() {
  if (GBK_REV) return GBK_REV;
  let dec;
  try { dec = new TextDecoder('gbk'); } catch (e) {
    // 环境无 ICU GBK 支持 ⇒ 无法判定。fail-closed：退出码 3，不静默跳过 G6。
    console.error('编码门禁失败：本机 Node 无 GBK 解码支持（缺 ICU），G6 无法评估。已按 fail-closed 拒绝放行。');
    process.exit(3);
  }
  GBK_REV = new Map();
  for (let b0 = 0x81; b0 <= 0xFE; b0++) {
    for (let b1 = 0x40; b1 <= 0xFE; b1++) {
      if (b1 === 0x7F) continue;
      try {
        const s = dec.decode(Uint8Array.of(b0, b1));
        if (s.length === 1 && !GBK_REV.has(s)) GBK_REV.set(s, [b0, b1]);
      } catch (e) { /* 非 GBK 合法双字节 */ }
    }
  }
  return GBK_REV;
}
function toGbkBytes(s) {
  const rev = buildGbkReverseTable();
  const out = [];
  for (const ch of s) {
    const cp = ch.codePointAt(0);
    if (cp < 0x80) { out.push(cp); continue; }
    const r = rev.get(ch);
    if (!r) return null; // 该字符无法 GBK 编码 ⇒ 不可能是 GBK 误读产物
    out.push(r[0], r[1]);
  }
  return out;
}
const CJK_RE = /[一-鿿]/;
function detectMojibake(line) {
  if (!CJK_RE.test(line)) return null;
  const b = toGbkBytes(line);
  if (!b) return null;
  try { new TextDecoder('utf-8', { fatal: true }).decode(Uint8Array.from(b)); } catch (e) { return null; }
  const back = Buffer.from(b).toString('utf8');
  if (!CJK_RE.test(back)) return null;
  return back;
}
// 空扫描即失败：仓库内必有 .pas；扫到 0 个说明 root 指错或 SKIP 规则吃掉了源码树。
if (files.length === 0) {
  console.error(`编码门禁失败：扫描 0 个 .pas（root=${ROOT}）。根因通常是 --root 指错目录；已按 fail-closed 拒绝放行。`);
  process.exit(3);
}
for (const f of files) {
  const rel = path.relative(ROOT, f).replace(/\\/g, '/');
  let buf;
  try { buf = fs.readFileSync(f); } catch (e) {
    // 标签不用 G6：G6 专指「双重编码乱码」内容级判据；读取失败属扫描自身失败，走 G0
    // （WO-20260922-AUDIT-乙-P2 §3.1b——此前本行误标 G6，与 G6 语义互斥）
    console.error(`G0 读取失败: ${path.relative(ROOT, f).replace(/\\/g, '/')} (${e.message})`);
    process.exit(3);
  }
  const bom = buf.length >= 3 && buf[0] === 0xEF && buf[1] === 0xBB && buf[2] === 0xBF;
  if (!bom && hasNonAscii(buf) && !bomExcepts.has(rel)) violations.push(`G3 缺UTF-8 BOM: ${rel}`);
  // G4: UTF-16/32 BOM 或任何 NUL 字节一律拒绝（存量 .pas 基线为 0，不设豁免）
  const u16bom = buf.length >= 2 && ((buf[0] === 0xFF && buf[1] === 0xFE) || (buf[0] === 0xFE && buf[1] === 0xFF));
  const u32bom = buf.length >= 4 && buf[0] === 0x00 && (buf[1] === 0xFE || buf[1] === 0xFF) && buf[2] === 0x00;
  const nulCount = countByte(buf, 0x00);
  if (u16bom || u32bom || nulCount > 0) {
    violations.push(`G4 含NUL/UTF-16/32 BOM(NUL=${nulCount}): ${rel}`);
    continue; // NUL 污染文件的其余字节统计不可信，不再评估 G2/G1/G5
  }
  if (!validUtf8(buf)) { violations.push(`G2 非法UTF-8(GBK/ANSI原始字节): ${rel}`); continue; }
  // G6: 双重编码乱码（仅在文件已通过 G2 合法 UTF-8 且未被 mojibakeExceptions 豁免时评估）
  if (!mojibakeExempt.has(rel)) {
    const lines = buf.toString('utf8').split(/\r\n|\r|\n/);
    const hitLines = [];
    for (const line of lines) if (detectMojibake(line)) hitLines.push(line);
    const mcap = rel in mojibakeAllowed ? mojibakeAllowed[rel] : 0;
    if (hitLines.length > mcap) {
      violations.push(`G6 双重编码乱码 ${hitLines.length} 行 > 基线 ${mcap}: ${rel}`);
      const idx = lines.findIndex(l => detectMojibake(l));
      const rev = detectMojibake(lines[idx]);
      violations.push(`  └─ G6 样例 L${idx + 1}: ${lines[idx].trim().slice(0, 70).replace(/\s+/g, ' ')}`);
      if (rev) violations.push(`  └─ G6 还原: ${rev.trim().slice(0, 70)}`);
    }
  }
  const n = (buf.toString('utf8').match(/\uFFFD/g) || []).length;
  const cap = rel in allowed ? allowed[rel] : 0;
  if (n > cap) violations.push(`G1 U+FFFD ${n} > 基线 ${cap}: ${rel}`);
  const lc = countLoneCr(buf);
  const lcap = rel in loneCrAllowed ? loneCrAllowed[rel] : 0;
  if (lc > lcap) violations.push(`G5 孤立CR ${lc} > 基线 ${lcap}: ${rel}`);
}
if (violations.length) {
  console.error('编码门禁失败，违规 ' + violations.length + ' 项:');
  violations.slice(0, 50).forEach(v => console.error('  ' + v));
  process.exit(1);
}
console.log(`编码门禁通过：${files.length} 个 .pas（基线残留U+FFFD文件 ${Object.keys(allowed).length}，BOM例外 ${bomExcepts.size}，孤立CR基线文件 ${Object.keys(loneCrAllowed).length}，双重编码基线文件 ${Object.keys(mojibakeAllowed).length}，跳过目录 ${skippedDirs.size}）`);
