// 证据编码门禁负向样本测试：在临时 CodeReview 目录构造 UTF-16LE（PowerShell `>` 重定向的真实
// 产物形态）与 GBK 原始字节样本，断言 E1/E2 逐项拦截；再验证存量基线只豁免登记文件与登记计数
// （新增违规文件、存量件计数上升均仍被拦）；最后删掉违规件断言干净集通过。
// 用法: node test_negative_sample.js   （退出码 0=门禁按预期拦截）
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');
const HERE = __dirname;
const CHECK = path.join(HERE, 'check_evidence_encoding.js');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'evenc-'));
const CR = path.join(tmp, 'CodeReview');
fs.mkdirSync(CR, { recursive: true });
const EMPTY_BASELINE = path.join(tmp, 'empty-baseline.json');
const STOCK_BASELINE = path.join(tmp, 'stock-baseline.json');
fs.writeFileSync(EMPTY_BASELINE, JSON.stringify({ nulStock: {} }));
fs.writeFileSync(STOCK_BASELINE, JSON.stringify({ nulStock: { 'CodeReview/ps-redirect.log': 20 } }));

// 正样本：合法 UTF-8 证据（无 NUL）
fs.writeFileSync(path.join(CR, 'ok-output.txt'), Buffer.from('证据标题：正常中文与 ASCII 混排\r\nNUL free\r\n', 'utf8'));
// E1 样本 A：UTF-16LE + BOM（PowerShell `cmd > file.log` 的默认落盘形态）
fs.writeFileSync(path.join(CR, 'ps-redirect.log'), Buffer.concat([Buffer.from([0xFF, 0xFE]), Buffer.from('Tests Passed : 100\r\n', 'utf16le')]));
// E1 样本 B：UTF-8 正文中夹带裸 NUL（纯 ASCII UTF-16LE 去掉 BOM 后的等价形态，只有 NUL 规则拦得住）
fs.writeFileSync(path.join(CR, 'nul-in-body.xml'), Buffer.concat([Buffer.from('<test-results total="1"/>\n', 'utf8'), Buffer.from([0x00]), Buffer.from('<more/>\n', 'utf8')]));
// E2 样本：无 NUL 但为 GBK 原始字节
fs.writeFileSync(path.join(CR, 'gbk.csv'), Buffer.concat([Buffer.from('file,result\r\nok,', 'utf8'), Buffer.from([0xC1, 0xE6, 0xC9, 0xE4]), Buffer.from('\r\n', 'utf8')]));

let failed = false;
function runChecker(baseline) {
  return execFileSync(process.execPath, [CHECK, '--repo', tmp, '--baseline', baseline, '--all-worktree'], { stdio: 'pipe' });
}
function capture(fn) {
  try { return { code: 0, out: fn().toString('utf8') }; }
  catch (e) { return { code: 1, out: (e.stderr || Buffer.alloc(0)).toString('utf8') + (e.stdout || Buffer.alloc(0)).toString('utf8') }; }
}

const first = capture(() => runChecker(EMPTY_BASELINE));
if (first.code === 0) {
  console.error('负向样本测试失败：门禁未拦截任何违规'); failed = true;
} else {
  console.log('门禁输出（预期包含 E1 两类 + E2 一类违规）:\n' + first.out);
  if (!/E1 .*ps-redirect\.log/.test(first.out)) { console.error('E1 未拦截 UTF-16LE 重定向日志'); failed = true; }
  if (!/E1 .*nul-in-body\.xml/.test(first.out)) { console.error('E1 未拦截正文夹带 NUL 的 XML'); failed = true; }
  if (!/E2 .*gbk\.csv/.test(first.out)) { console.error('E2 未拦截 GBK 原始字节'); failed = true; }
  if (/ok-output\.txt/.test(first.out)) { console.error('门禁误报正样本 ok-output.txt'); failed = true; }
  if (!/NUL=\d+, 首偏移=\d+/.test(first.out)) { console.error('E1 报错未给出 NUL 计数与首偏移'); failed = true; }
}

// 存量基线：只豁免登记文件，其余违规照拦
const scoped = capture(() => runChecker(STOCK_BASELINE));
console.log('存量基线（ps-redirect.log=20）命中输出:\n' + (scoped.out || '(全绿)'));
if (/E1 .*ps-redirect\.log/.test(scoped.out)) { console.error('存量基线未豁免登记文件'); failed = true; }
if (!/E1 .*nul-in-body\.xml/.test(scoped.out)) { console.error('存量基线外新增 NUL 文件未被拦截'); failed = true; }
if (!/E2 .*gbk\.csv/.test(scoped.out)) { console.error('存量基线外 GBK 文件未被拦截'); failed = true; }

// 存量件计数上升必须回到违规集
fs.appendFileSync(path.join(CR, 'ps-redirect.log'), Buffer.from([0x00]));
const risen = capture(() => runChecker(STOCK_BASELINE));
console.log('存量件 NUL 上升后输出:\n' + (risen.out || '(全绿)'));
if (!/E1 [^\n]*存量基线=20[^\n]*ps-redirect\.log/.test(risen.out)) { console.error('存量件 NUL 计数上升未被拦截'); failed = true; }
fs.writeFileSync(path.join(CR, 'ps-redirect.log'), Buffer.concat([Buffer.from([0xFF, 0xFE]), Buffer.from('Tests Passed : 100\r\n', 'utf16le')]));

// 剔除违规件后应全绿
for (const f of ['ps-redirect.log', 'nul-in-body.xml', 'gbk.csv']) fs.rmSync(path.join(CR, f));
try {
  const out = runChecker(EMPTY_BASELINE).toString('utf8');
  console.log('清理后复跑: ' + out.trim());
} catch (e) {
  console.error('负向样本测试失败：干净样本集仍被拒绝\n' + (e.stderr || Buffer.alloc(0)).toString('utf8'));
  failed = true;
}

fs.rmSync(tmp, { recursive: true, force: true });
console.log(failed ? 'NEGATIVE-TEST: FAIL' : 'NEGATIVE-TEST: PASS');
process.exit(failed ? 1 : 0);
