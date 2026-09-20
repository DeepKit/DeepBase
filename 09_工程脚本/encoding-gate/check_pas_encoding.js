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
// 用法: node check_pas_encoding.js [--root <dir>] [--baseline <file>]
// 退出码：0 通过；1 违规。
const fs = require('fs');
const path = require('path');

function arg(name, dflt) {
  const i = process.argv.indexOf('--' + name);
  return i > 0 && process.argv[i + 1] ? process.argv[i + 1] : dflt;
}
const ROOT = path.resolve(arg('root', process.cwd()));
const BASELINE_P = arg('baseline', path.join(__dirname, 'pas_encoding_baseline.json'));
const SKIP = new Set(['.git', '.claude', '__history', 'BuildOutput', 'DCUOutput', 'bin', 'dcu', 'node_modules', '.tmp', '.superpowers', '.workbuddy']);

function walk(dir, out) {
  let ents;
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { return out; }
  for (const e of ents) {
    if (SKIP.has(e.name)) continue;
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
for (const f of files) {
  const rel = path.relative(ROOT, f).replace(/\\/g, '/');
  const buf = fs.readFileSync(f);
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
console.log(`编码门禁通过：${files.length} 个 .pas（基线残留U+FFFD文件 ${Object.keys(allowed).length}，BOM例外 ${bomExcepts.size}，孤立CR基线文件 ${Object.keys(loneCrAllowed).length}）`);
