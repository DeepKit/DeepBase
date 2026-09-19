const fs = require('fs');
const path = require('path');
const ROOT = 'D:/_Progs/02Business/DeepBase';
const SKIP = new Set(['.git', '.claude', '__history', 'BuildOutput', 'DCUOutput', 'bin', 'dcu', 'node_modules', '.tmp']);

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

const files = walk(ROOT, []);
const rows = [];
for (const f of files) {
  const buf = fs.readFileSync(f);
  const hasBom = buf.length >= 3 && buf[0] === 0xEF && buf[1] === 0xBB && buf[2] === 0xBF;
  const txt = buf.toString('utf8');
  const cjk = (txt.match(/[\u4e00-\u9fff]/g) || []).length;
  const ff = (txt.match(/\uFFFD/g) || []).length;
  if (ff === 0) continue;
  // FF 数与中文数的比例：GBK 误读 => FF 远大于 CJK；真损坏 => FF 远小于 CJK
  rows.push({ f: path.relative(ROOT, f), bom: hasBom, cjk, ff, ratio: cjk ? (ff / cjk) : 999 });
}
rows.sort((a, b) => b.ff - a.ff);
console.log('含 U+FFFD 的文件数:', rows.length);
console.log('');
console.log('--- 疑似 GBK 整体误读 (FF/CJK >= 1.5 且无 BOM) ---');
const gbkish = rows.filter(r => !r.bom && r.ratio >= 1.5);
gbkish.forEach(r => console.log(`  FF=${String(r.ff).padStart(5)} CJK=${String(r.cjk).padStart(5)}  ${r.f}`));
console.log('  小计:', gbkish.length);
console.log('');
console.log('--- 疑似真损坏 (有 BOM 或 FF/CJK < 1.5) ---');
const broken = rows.filter(r => r.bom || r.ratio < 1.5);
broken.slice(0, 60).forEach(r => console.log(`  FF=${String(r.ff).padStart(5)} CJK=${String(r.cjk).padStart(5)} BOM=${r.bom ? 'Y' : 'N'}  ${r.f}`));
console.log('  小计:', broken.length);
