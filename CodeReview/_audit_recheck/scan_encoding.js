const fs = require('fs');
const path = require('path');
const ROOT = 'D:/_Progs/02Business/DeepBase';
const SKIP = new Set(['.git', '.claude', '__history', 'BuildOutput', 'DCUOutput', 'bin', 'dcu', 'node_modules']);

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
const noBomWithCJK = [];
const bomWithCJK = [];
const fffd = [];
for (const f of files) {
  const buf = fs.readFileSync(f);
  const hasBom = buf.length >= 3 && buf[0] === 0xEF && buf[1] === 0xBB && buf[2] === 0xBF;
  let txt;
  try { txt = buf.toString('utf8'); } catch (e) { continue; }
  const cjk = /[\u4e00-\u9fff]/.test(txt);
  const rep = txt.includes('\uFFFD');
  if (cjk) (hasBom ? bomWithCJK : noBomWithCJK).push(path.relative(ROOT, f));
  if (rep) fffd.push(path.relative(ROOT, f));
}
console.log('扫描 .pas 总数:', files.length);
console.log('\n[A] 含中文且有 BOM:', bomWithCJK.length);
console.log('[B] 含中文且无 BOM:', noBomWithCJK.length);
noBomWithCJK.forEach(f => console.log('    ' + f));
console.log('\n[C] 含 U+FFFD 替换字符:', fffd.length);
fffd.forEach(f => console.log('    ' + f));
