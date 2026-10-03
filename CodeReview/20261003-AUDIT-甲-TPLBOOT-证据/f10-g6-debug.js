// G6 判据逐行诊断（同源判据：09_工程脚本/gb18030-reverse-table('gbk') + [一-鿿] + GBK可逆）。
// 注意：本脚本不写任何原始乱码字面量——阳性对照的纯乱码样本由「日志导出」UTF-8 字节
// 经 TextDecoder('gbk') 误读程序化构造，保证可 round-trip，同时避免本证据件自身被
// evidence-encoding-gate E3 判为双重编码（证据文件必须干净 UTF-8 且不含可逆乱码行）。
const fs = require('fs');
const path = require('path');
const { buildReverseTable } = require(path.join(__dirname, '../../09_工程脚本/gb18030-reverse-table'));

const rev = buildReverseTable('gbk');
const CJK_RE = /[一-鿿]/;
function toGbkBytes(s) {
  const out = [];
  for (const ch of s) {
    const cp = ch.codePointAt(0);
    if (cp < 0x80) { out.push(cp); continue; }
    const r = rev.get(ch);
    if (!r) return { fail: 'GBK反表无此字符', ch: ch, cp: cp.toString(16) };
    out.push(r[0], r[1]);
  }
  return { bytes: out };
}
function diag(label, line) {
  console.log(`==== ${label} ====`);
  console.log(`  行: ${JSON.stringify(line.trim().slice(0, 90))}`);
  console.log(`  ①含CJK([一-鿿]): ${CJK_RE.test(line)}`);
  const g = toGbkBytes(line);
  if (g.fail) { console.log(`  ②GBK可编码: 失败 -> ${g.fail} U+${g.cp}`); return; }
  console.log(`  ②GBK可编码: 通过 (${g.bytes.length} 字节)`);
  let ok = true;
  try { new TextDecoder('utf-8', { fatal: true }).decode(Uint8Array.from(g.bytes)); }
  catch (e) { ok = false; }
  console.log(`  ③重组字节整体为合法UTF-8: ${ok}`);
  if (!ok) return;
  const back = Buffer.from(g.bytes).toString('utf8');
  console.log(`  ④还原文本含CJK: ${CJK_RE.test(back)}`);
  console.log(`  还原: ${JSON.stringify(back.trim().slice(0, 90))}`);
}

// 阳性对照样本：把「日志导出」的 UTF-8 字节按 GBK 误读，得到纯双重编码行（与 gate 文档样本同源构造）
const pureMojibake = new TextDecoder('gbk').decode(Buffer.from('日志导出', 'utf8'));
console.log(`[构造] 日志导出 --UTF-8字节按GBK误读--> ${JSON.stringify(pureMojibake)}`);

const TARGET = process.argv[2] || '../../Examples/Templates/Common/Template.AutoUpdateBootstrap.pas';
const buf = fs.readFileSync(path.join(__dirname, TARGET));
const lines = buf.toString('utf8').split(/\r\n|\r|\n/);
for (const n of [5, 7, 52, 58]) diag(`HEAD L${n}`, lines[n - 1] || '');
diag('阳性对照(纯乱码行, 程序构造)', `  // ${pureMojibake}`);
diag('阴性对照(正常中文)', '  // 日志导出');
diag('阴性对照(HEAD L6 已还原行)', '      - 后台轮询安装窗口');
