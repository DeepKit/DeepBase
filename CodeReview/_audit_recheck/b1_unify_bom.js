// 乙-B1 ④ 全库 .pas 统一 UTF-8 BOM。跳过甲独占路径（WO-20260919-AUDIT-甲 §1）与仍非法 UTF-8 的文件。
// 用法: node b1_unify_bom.js [--apply]
const fs = require('fs');
const path = require('path');
const ROOT = 'D:/_Progs/02Business/DeepBase';
const SKIP = new Set(['.git', '.claude', '__history', 'BuildOutput', 'DCUOutput', 'bin', 'dcu', 'node_modules', '.tmp', '.superpowers', '.workbuddy']);
const JIA_EXCLUDE = [
  /^Core\/DeepBase\.Crypto\.AES\.pas$/,
  /^Features\/DeepBase\.(Updater|AutoUpdate|UIA\.Engine)\.pas$/,
  /^Governance\//,
];
const APPLY = process.argv[2] === '--apply';

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
const BOM = Buffer.from([0xEF, 0xBB, 0xBF]);
const files = walk(ROOT, []);
let added = 0, skippedJia = 0, skippedInvalid = 0, already = 0;
const skippedList = [];
for (const f of files) {
  const rel = path.relative(ROOT, f).replace(/\\/g, '/');
  if (JIA_EXCLUDE.some(re => re.test(rel))) { skippedJia++; if (!fs.readFileSync(f).subarray(0,3).equals(BOM)) skippedList.push('JIA:' + rel); continue; }
  const buf = fs.readFileSync(f);
  if (buf.length >= 3 && buf[0] === 0xEF && buf[1] === 0xBB && buf[2] === 0xBF) { already++; continue; }
  if (!validUtf8(buf)) { skippedInvalid++; skippedList.push('INVALID:' + rel); continue; }
  if (APPLY) fs.writeFileSync(f, Buffer.concat([BOM, buf]));
  added++;
}
console.log({ total: files.length, already, added, skippedJia, skippedInvalid, APPLY });
console.log('跳过清单(甲独占无BOM或非法UTF-8):', skippedList);
