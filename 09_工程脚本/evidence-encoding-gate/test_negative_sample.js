// 证据编码门禁负向样本测试：在临时 CodeReview 目录构造 UTF-16LE（PowerShell `>` 重定向的真实
// 产物形态）与 GBK 原始字节样本，断言 E1/E2 逐项拦截；再验证存量基线只豁免登记文件与登记计数
// （新增违规文件、存量件计数上升均仍被拦）；最后删掉违规件断言干净集通过。
// WO-20260923-AUDIT-乙-D5 §一-1 追加：扫描面已从「.txt/.log/.csv/.xml 白名单」改为
// 「CodeReview/** 全集 − 二进制扩展名排除集」，故本文件必须同时证明
// ①清单外扩展名（.cmd/.json/无扩展名）的违规件现在会被拦；②二进制扩展名件不被误拦。
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
fs.writeFileSync(EMPTY_BASELINE, JSON.stringify({ _comment: '负向样本用空基线', nulStock: {} }));
fs.writeFileSync(STOCK_BASELINE, JSON.stringify({ _comment: '负向样本用存量基线', nulStock: { 'CodeReview/ps-redirect.log': 20 } }));

// 正样本：合法 UTF-8 证据（无 NUL）
fs.writeFileSync(path.join(CR, 'ok-output.txt'), Buffer.from('证据标题：正常中文与 ASCII 混排\r\nNUL free\r\n', 'utf8'));
// E1 样本 A：UTF-16LE + BOM（PowerShell `cmd > file.log` 的默认落盘形态）
fs.writeFileSync(path.join(CR, 'ps-redirect.log'), Buffer.concat([Buffer.from([0xFF, 0xFE]), Buffer.from('Tests Passed : 100\r\n', 'utf16le')]));
// E1 样本 B：UTF-8 正文中夹带裸 NUL（纯 ASCII UTF-16LE 去掉 BOM 后的等价形态，只有 NUL 规则拦得住）
fs.writeFileSync(path.join(CR, 'nul-in-body.xml'), Buffer.concat([Buffer.from('<test-results total="1"/>\n', 'utf8'), Buffer.from([0x00]), Buffer.from('<more/>\n', 'utf8')]));
// E2 样本：无 NUL 但为 GBK 原始字节
fs.writeFileSync(path.join(CR, 'gbk.csv'), Buffer.concat([Buffer.from('file,result\r\nok,', 'utf8'), Buffer.from([0xC1, 0xE6, 0xC9, 0xE4]), Buffer.from('\r\n', 'utf8')]));

// ── D5 §一-1 扩面样本：扫描面不再按扩展名白名单放行，下列三件在旧门禁下「完全扫不到」──────
// 甲 D2 落笔 3c64b72 实证：11 件证据里 2 件 .cmd 不在旧扩展清单内 ⇒ 违规可静默入库。
const WIDENED = [
  // 旧清单外的扩展名 + UTF-16LE 落盘 ⇒ E1 必拦
  ['build-commands.cmd', Buffer.concat([Buffer.from([0xFF, 0xFE]), Buffer.from('@echo off\r\necho 完成\r\n', 'utf16le')])],
  ['scan-list.md', Buffer.concat([Buffer.from([0xFF, 0xFE]), Buffer.from('# 扫描清单\r\n', 'utf16le')])],
  // 旧清单外的扩展名 + GBK 原始字节 ⇒ E2 必拦
  ['summary.json', Buffer.concat([Buffer.from('{"note":"', 'utf8'), Buffer.from([0xC1, 0xE6, 0xC9, 0xE4]), Buffer.from('"}\n', 'utf8')])],
  // 无扩展名件（旧口径同样扫不到）⇒ E1 必拦
  ['raw-console-output', Buffer.concat([Buffer.from([0xFF, 0xFE]), Buffer.from('Tests Passed : 1\r\n', 'utf16le')])],
];
for (const [name, buf] of WIDENED) fs.writeFileSync(path.join(CR, name), buf);
// 反向对照：二进制容器本身就是合法的非 UTF-8 字节流，含 NUL 也不该报（否则扩面即误报）。
fs.writeFileSync(path.join(CR, 'chart.png'), Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.from([0x00, 0x00, 0x00, 0x0d]), Buffer.from('IHDR', 'latin1'), Buffer.from([0x00])]));

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
  // D5 §一-1：旧扩展名白名单之外的文本证据（.cmd/.md/.json/无扩展名）必须进门禁
  for (const [rule, name] of [['E1', 'build-commands.cmd'], ['E1', 'scan-list.md'], ['E2', 'summary.json'], ['E1', 'raw-console-output']]) {
    const re = new RegExp(rule + ' [^\n]*' + name.replace(/[.\-]/g, '\\$&'));
    if (!re.test(first.out)) { console.error('扩面失效：' + rule + ' 未拦截旧清单外样本 ' + name); failed = true; }
  }
  // 反向对照：二进制容器含 NUL 也属正常，误拦就等于「扩面即误报」，不能落地
  if (/chart\.png/.test(first.out)) { console.error('二进制排除集失效：含 NUL 的 .png 被误报'); failed = true; }
}

// D5 §一-1「修前假绿」对照：把排除判据改回旧的扩展名白名单语义，得到「扩面之前」的门禁副本，
// 它必须放行上面 4 件清单外样本 —— 否则无法证明扩面真的闭合了一个旧缺口。
// 副本落在 tmp 内时 require('../gate-*') 会 MODULE_NOT_FOUND，故改写为绝对路径（同编码门禁 G6 对照）。
{
  const beforeGate = path.join(tmp, 'check_evidence_encoding_before.js');
  const src = fs.readFileSync(CHECK, 'utf8');
  const OLD_SEMANTICS = '  return BINARY_EXT.has(path.extname(name).toLowerCase());';
  const patched = src
    .replace("require('../gate-skip')", 'require(' + JSON.stringify(path.resolve(HERE, '../gate-skip.js')) + ')')
    .replace("require('../gate-baseline')", 'require(' + JSON.stringify(path.resolve(HERE, '../gate-baseline.js')) + ')')
    .replace(OLD_SEMANTICS, '  return !/\\.(txt|log|csv|xml)$/i.test(name); // 「修前」对照：旧白名单之外的件一律不扫');
  if (patched === src || !src.includes(OLD_SEMANTICS)) {
    console.error('修前对照异常：未能在门禁源码上定位旧白名单判据，无法构造「扩面之前」的副本');
    failed = true;
  } else {
    fs.writeFileSync(beforeGate, patched);
    let out = '';
    try { out = execFileSync(process.execPath, [beforeGate, '--repo', tmp, '--baseline', EMPTY_BASELINE, '--all-worktree'], { stdio: 'pipe' }).toString('utf8'); }
    catch (e) { out = (e.stderr || Buffer.alloc(0)).toString('utf8') + (e.stdout || Buffer.alloc(0)).toString('utf8'); }
    const missed = ['build-commands.cmd', 'scan-list.md', 'summary.json', 'raw-console-output'].filter(n => !out.includes(n));
    if (missed.length !== 4) { console.error('修前对照失败：旧口径副本仍拦下了 ' + (4 - missed.length) + ' 件清单外样本 ⇒ 无法证明扩面必要'); failed = true; }
    else console.log('修前对照通过：旧白名单口径对 ' + missed.join(' / ') + ' 全部视而不见（假绿实锤）');
    if (!/E1 .*ps-redirect\.log/.test(out) || !/E2 .*gbk\.csv/.test(out)) { console.error('修前对照异常：旧口径副本连旧清单内样本都没拦住，副本不可信'); failed = true; }
    fs.rmSync(beforeGate, { force: true });
  }
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

// 剔除违规件后应全绿（chart.png 故意留着：它被排除集挡住，留着仍应全绿）
for (const f of ['ps-redirect.log', 'nul-in-body.xml', 'gbk.csv', 'build-commands.cmd', 'scan-list.md', 'summary.json', 'raw-console-output']) fs.rmSync(path.join(CR, f));
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
