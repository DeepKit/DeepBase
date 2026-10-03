// F10 核心：用 encoding-gate 的同源判据（buildReverseTable('gbk') + CJK_RE + GBK可逆）
// 对 HEAD 文件逐行跑 G6 detectMojibake，实测「行计数规则」下的命中行号。
// 与 check_pas_encoding.js 的 split(/\r\n|\r|\n/) 完全一致。
const fs = require('fs');
const path = require('path');
const { buildReverseTable } = require(path.join(__dirname, '../../09_工程脚本/gb18030-reverse-table'));

function buildGbkReverseTable() { return buildReverseTable('gbk'); }
function toGbkBytes(s, rev) {
  const out = [];
  for (const ch of s) {
    const cp = ch.codePointAt(0);
    if (cp < 0x80) { out.push(cp); continue; }
    const r = rev.get(ch);
    if (!r) return null;
    out.push(r[0], r[1]);
  }
  return out;
}
const CJK_RE = /[一-鿿]/;
function detectMojibake(line, rev) {
  if (!CJK_RE.test(line)) return null;
  const b = toGbkBytes(line, rev);
  if (!b) return null;
  try { new TextDecoder('utf-8', { fatal: true }).decode(Uint8Array.from(b)); } catch (e) { return null; }
  const back = Buffer.from(b).toString('utf8');
  if (!CJK_RE.test(back)) return null;
  return back;
}

const rev = buildGbkReverseTable();
if (!rev) { console.error('无 GBK 反表，fail-closed'); process.exit(3); }
console.log('GBK 反表键数 =', rev.size);

const TARGET = process.argv[2] || '../../Examples/Templates/Common/Template.AutoUpdateBootstrap.pas';
const buf = fs.readFileSync(path.join(__dirname, TARGET));
const lines = buf.toString('utf8').split(/\r\n|\r|\n/);
console.log('split 行数 =', lines.length, '(末行空串:', JSON.stringify(lines[lines.length - 1]), ')');
const hits = [];
lines.forEach((line, i) => {
  const back = detectMojibake(line, rev);
  if (back) hits.push({ no: i + 1, line, back });
});
console.log('G6 命中行数 =', hits.length);
for (const h of hits) {
  console.log('---');
  console.log('L%d 乱码行: %s', h.no, JSON.stringify(h.line.trim().slice(0, 80)));
  console.log('L%d 还原为: %s', h.no, JSON.stringify(h.back.trim().slice(0, 80)));
}
console.log('命中行号列表 =', JSON.stringify(hits.map(h => h.no)));
