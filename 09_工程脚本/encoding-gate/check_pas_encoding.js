// DeepBase .pas 源码编码门禁（WO-20260919-AUDIT-乙 B1-④）
// 规则：
//  G1 任何 .pas 禁止引入基线之外的 U+FFFD（按文件计数，超过基线即失败；新文件出现 U+FFFD 即失败）
//  G2 任何 .pas 必须是合法 UTF-8（禁止 GBK/ANSI 原始字节入库）
//  G3 任何 .pas 必须带 UTF-8 BOM（例外清单：基线 bomExceptions，待相应独占人整改后移除）
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
const bomExcepts = new Set(baseline.bomExceptions || []);
const violations = [];
const files = walk(ROOT, []);
for (const f of files) {
  const rel = path.relative(ROOT, f).replace(/\\/g, '/');
  const buf = fs.readFileSync(f);
  const bom = buf.length >= 3 && buf[0] === 0xEF && buf[1] === 0xBB && buf[2] === 0xBF;
  if (!bom && !bomExcepts.has(rel)) violations.push(`G3 缺UTF-8 BOM: ${rel}`);
  if (!validUtf8(buf)) { violations.push(`G2 非法UTF-8(GBK/ANSI原始字节): ${rel}`); continue; }
  const n = (buf.toString('utf8').match(/\uFFFD/g) || []).length;
  const cap = rel in allowed ? allowed[rel] : 0;
  if (n > cap) violations.push(`G1 U+FFFD ${n} > 基线 ${cap}: ${rel}`);
}
if (violations.length) {
  console.error('编码门禁失败，违规 ' + violations.length + ' 项:');
  violations.slice(0, 50).forEach(v => console.error('  ' + v));
  process.exit(1);
}
console.log(`编码门禁通过：${files.length} 个 .pas（基线残留U+FFFD文件 ${Object.keys(allowed).length}，BOM例外 ${bomExcepts.size}）`);
