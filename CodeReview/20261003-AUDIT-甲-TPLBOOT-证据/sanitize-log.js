// 证据日志净化：把文件中所有非 ASCII 字符替换为 \uXXXX 转义后另存。
// 目的：保留乱码样本的可读证据，同时保证入库证据件自身是纯 ASCII——
// 否则 evidence-encoding-gate E3 会把含可逆乱码行的证据件判为新增违规（新文件零豁免）。
const fs = require('fs');
const path = require('path');
const [, , src] = process.argv;
if (!src) { console.error('用法: node sanitize-log.js <file>'); process.exit(2); }
const text = fs.readFileSync(src, 'utf8');
let out = '';
for (const ch of text) {
  const cp = ch.codePointAt(0);
  if (cp < 0x80) { out += ch; continue; }
  if (cp === 0xFEFF) { out += '<BOM>'; continue; } // BOM 单独标记
  out += '\\u' + cp.toString(16).padStart(4, '0');
}
const dst = src.replace(/\.txt$/, '') + '.sanitized.txt';
fs.writeFileSync(dst, out);
console.log('sanitized ->', path.basename(dst), '非ASCII残留:', /[^\x00-\x7F]/.test(out) ? '有' : '0');
