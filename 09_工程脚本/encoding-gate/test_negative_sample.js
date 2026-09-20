// 编码门禁负向样本测试：向临时副本注入 U+FFFD / 移除 BOM / 写入 GBK 字节 / UTF-16+NUL / 孤立 CR，断言门禁逐项报错。
// 用法: node test_negative_sample.js   （退出码 0=门禁按预期拦截）
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');
const HERE = __dirname;

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'pasenc-'));
fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
// 样本 1：合法带 BOM UTF-8（应通过）
fs.writeFileSync(path.join(tmp, 'src', 'Ok.pas'), Buffer.concat([Buffer.from([0xEF, 0xBB, 0xBF]), Buffer.from("unit Ok;\n// 正常中文注释\ninterface\nimplementation\nend.\n", 'utf8')]));
// 样本 2：注入 U+FFFD（G1 应报错）；BOM 之后正文中出现 EF BF BD 序列，解码即为 U+FFFD
fs.writeFileSync(path.join(tmp, 'src', 'Injected.pas'), Buffer.concat([Buffer.from([0xEF, 0xBB, 0xBF]), Buffer.from("unit Injected;\n// 注入\uFFFD损坏\ninterface\nimplementation\nend.\n", 'utf8')]));
// 样本 3：缺 BOM（G3 应报错）
fs.writeFileSync(path.join(tmp, 'src', 'NoBom.pas'), Buffer.from("unit NoBom;\ninterface\nimplementation\nend.\n", 'utf8'));
// 样本 4：GBK 原始字节（G2 应报错）
const gbkText = new TextEncoder().encode('unit Gbk;');
const gbkBytes = Buffer.from([0xB5, 0xA5, 0xCE, 0xBB]); // "单位" GBK
fs.writeFileSync(path.join(tmp, 'src', 'Gbk.pas'), Buffer.concat([Buffer.from([0xEF, 0xBB, 0xBF]), gbkText, gbkBytes, Buffer.from('\ninterface\nimplementation\nend.\n', 'utf8')]));
// 样本 5：UTF-8 BOM + 正文含 NUL 字节（G2 合法、G1 无、仅 G4 能拦——纯 ASCII UTF-16 场景的等价形态）
fs.writeFileSync(path.join(tmp, 'src', 'NulIn.pas'), Buffer.concat([Buffer.from([0xEF, 0xBB, 0xBF]), Buffer.from('unit NulIn;\n', 'utf8'), Buffer.from([0x00]), Buffer.from('interface\nimplementation\nend.\n', 'utf8')]));
// 样本 6：UTF-16LE BOM 文件（FF FE；G4 应报错）
fs.writeFileSync(path.join(tmp, 'src', 'Utf16.pas'), Buffer.concat([Buffer.from([0xFF, 0xFE]), Buffer.from('unit Utf16;\r\ninterface\r\nimplementation\r\nend.\r\n', 'utf16le')]));
// 样本 7：行尾多一个孤立 CR（\r\r\n；G5 应报错）
fs.writeFileSync(path.join(tmp, 'src', 'LoneCr.pas'), Buffer.concat([Buffer.from([0xEF, 0xBB, 0xBF]), Buffer.from('unit LoneCr;\r\r\ninterface\r\nimplementation\r\nend.\r\n', 'utf8')]));

const emptyBaseline = path.join(tmp, 'baseline.json');
fs.writeFileSync(emptyBaseline, JSON.stringify({ fffd: {}, loneCr: {}, bomExceptions: [] }));
let failed = false;
try {
  execFileSync(process.execPath, [path.join(HERE, 'check_pas_encoding.js'), '--root', tmp, '--baseline', emptyBaseline], { stdio: 'pipe' });
  console.error('负向样本测试失败：门禁未拦截任何违规'); failed = true;
} catch (e) {
  const out = (e.stderr || Buffer.alloc(0)).toString('utf8') + (e.stdout || Buffer.alloc(0)).toString('utf8');
  console.log('门禁输出（预期包含 5 类违规）:\n' + out);
  for (const tag of ['G1', 'G2', 'G3', 'G4', 'G5']) {
    if (!out.includes(tag)) { console.error('缺少 ' + tag + ' 报错'); failed = true; }
  }
  // G4 必须由 NulIn.pas 证明（纯 ASCII+NUL 能通过 G2，只有 G4 拦得住）
  if (!/G4 .*NulIn\.pas/.test(out)) { console.error('G4 未拦截 NulIn.pas（NUL 规则失效）'); failed = true; }
}
fs.rmSync(tmp, { recursive: true, force: true });
console.log(failed ? 'NEGATIVE-TEST: FAIL' : 'NEGATIVE-TEST: PASS');
process.exit(failed ? 1 : 0);
