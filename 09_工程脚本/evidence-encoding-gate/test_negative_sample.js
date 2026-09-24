// 证据编码门禁负向样本测试：在临时 CodeReview 目录构造 UTF-16LE（PowerShell `>` 重定向的真实
// 产物形态）与 GBK 原始字节样本，断言 E1/E2 逐项拦截；再验证存量基线只豁免登记文件与登记计数
// （新增违规文件、存量件计数上升均仍被拦）；最后删掉违规件断言干净集通过。
// WO-20260923-AUDIT-乙-D5 §一-1 追加：扫描面已从「.txt/.log/.csv/.xml 白名单」改为
// 「CodeReview/** 全集 − 二进制扩展名排除集」，故本文件必须同时证明
// ①清单外扩展名（.cmd/.json/无扩展名）的违规件现在会被拦；②二进制扩展名件不被误拦。
// WO-20260924-AUDIT-乙-D8 §1.4 追加 E3（双重编码乱码）：命中必红且定位到行、正常中文与纯
// ASCII 必绿、存量登记件不报红、只减不增、命中清单能从门禁自身复算、扫到 0 件必 FAIL-CLOSED。
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
fs.writeFileSync(EMPTY_BASELINE, JSON.stringify({ _comment: '负向样本用空基线', nulStock: {}, mojibakeStock: {} }));
fs.writeFileSync(STOCK_BASELINE, JSON.stringify({
  _comment: '负向样本用存量基线',
  nulStock: { 'CodeReview/ps-redirect.log': 20 },
  mojibakeStock: { 'CodeReview/mojibake-stock.txt': 2 },
}));

// 正样本：合法 UTF-8 证据（无 NUL）
fs.writeFileSync(path.join(CR, 'ok-output.txt'), Buffer.from('证据标题：正常中文与 ASCII 混排\r\nNUL free\r\n', 'utf8'));
// E1 样本 A：UTF-16LE + BOM（PowerShell `cmd > file.log` 的默认落盘形态）
fs.writeFileSync(path.join(CR, 'ps-redirect.log'), Buffer.concat([Buffer.from([0xFF, 0xFE]), Buffer.from('Tests Passed : 100\r\n', 'utf16le')]));
// E1 样本 B：UTF-8 正文中夹带裸 NUL（纯 ASCII UTF-16LE 去掉 BOM 后的等价形态，只有 NUL 规则拦得住）
fs.writeFileSync(path.join(CR, 'nul-in-body.xml'), Buffer.concat([Buffer.from('<test-results total="1"/>\n', 'utf8'), Buffer.from([0x00]), Buffer.from('<more/>\n', 'utf8')]));
// E2 样本：无 NUL 但为 GBK 原始字节
fs.writeFileSync(path.join(CR, 'gbk.csv'), Buffer.concat([Buffer.from('file,result\r\nok,', 'utf8'), Buffer.from([0xC1, 0xE6, 0xC9, 0xE4]), Buffer.from('\r\n', 'utf8')]));

// ── D8 §1.4 E3 样本：合法 UTF-8、无 NUL、无表外字符，但内容是双重编码乱码 ──────────────────
// 构造方式与真实成因同构：中文原文的 UTF-8 字节被按 GBK 误读，再以 UTF-8 落盘。
// 把解码器产生的 U+FFFD 归一成 '?'，是因为实锤样本（R7-gates-run.txt 第 1 行）里那个不可逆
// 字节在真实链路上落成了 '?'；含 U+FFFD 的行属丙-A 面，E3 判据本就不收（收了两套判据打架）。
const mojibake = s => new TextDecoder('gbk').decode(Buffer.from(s, 'utf8')).replace(/\uFFFD/g, '?');
const MOJI_LINES = [
  '编码门禁通过：972 个.pas 文件全部合法',
  '证据编码门禁通过：扫描 134 个 CodeReview 证据文件',
  '行尾门禁通过：检查了 1425 个文件（.pas CRLF / .md LF）',
];
// ①必红：清单外新文件（空基线 / 存量基线都未登记）
fs.writeFileSync(path.join(CR, 'double-encoded.txt'), Buffer.from(MOJI_LINES.map(mojibake).join('\r\n') + '\r\n', 'utf8'));
// ④不报红：存量登记件（封顶 2 行），但命中明细必须照样打印——存量是「看得见」不是「抹掉」
fs.writeFileSync(path.join(CR, 'mojibake-stock.txt'), Buffer.from(MOJI_LINES.slice(0, 2).map(mojibake).join('\r\n') + '\r\n', 'utf8'));
// ②必绿：正常中文行（旧 E1/E2 与新 E3 都不许报，否则门禁一开就误伤全库证据）
fs.writeFileSync(path.join(CR, 'normal-chinese.txt'), Buffer.from(
  '证据标题：正常中文与 ASCII 混排\r\n本次扫描覆盖 12 个目录，未发现异常，结论为通过。\r\n行尾门禁失败，违规 3 项：L2 .md 文档非预期包含 CRLF（要求 LF）\r\n', 'utf8'));
// ③必绿：纯 ASCII 证据
fs.writeFileSync(path.join(CR, 'pure-ascii.txt'), Buffer.from('Tests Passed : 100\r\nFAILURES 0\r\n', 'utf8'));

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
  return execFileSync(process.execPath, [CHECK, '--root', tmp, '--baseline', baseline, '--all-worktree'], { stdio: 'pipe' });
}
function capture(fn) {
  try { return { code: 0, out: fn().toString('utf8') }; }
  // e.status 而非固定 1：D8 §1.3 要求区分「违规 EXIT=1」与「门禁自身失败 EXIT=2/3」。
  catch (e) { return { code: typeof e.status === 'number' ? e.status : 1, out: (e.stderr || Buffer.alloc(0)).toString('utf8') + (e.stdout || Buffer.alloc(0)).toString('utf8') }; }
}
// 「修前」副本落在 tmp 内时 require('../gate-*') 会 MODULE_NOT_FOUND（同编码门禁 G6 对照），
// 且 MODULE_NOT_FOUND 会让所有「未拦住」的断言变成假通过 ⇒ 共享依赖一律改写为绝对路径。
function portal(src) {
  for (const m of ['gate-skip', 'gate-baseline', 'gate-args']) {
    src = src.replace("require('../" + m + "')", 'require(' + JSON.stringify(path.resolve(HERE, '../' + m + '.js')) + ')');
  }
  return src;
}
// 修前副本必须证明自己真的跑起来了：E1 存量清单内样本仍被拦住，否则「它放行了 X」不成立。
function assertCopyAlive(out, label) {
  if (!/E1 .*ps-redirect\.log/.test(out)) { console.error('修前对照异常（' + label + '）：副本连旧清单内样本都没拦住，副本不可信'); return false; }
  return true;
}

const first = capture(() => runChecker(EMPTY_BASELINE));
if (first.code === 0) {
  console.error('负向样本测试失败：门禁未拦截任何违规'); failed = true;
} else {
  console.log('门禁输出（预期包含 E1 两类 + E2 一类 + E3 一类违规）:\n' + first.out);
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
  // D8 §1.4-①：双重编码命中必红，且明细要能定位到行（路径:行号 + 原文 → 还原后）
  if (!/E3 [^\n]*double-encoded\.txt/.test(first.out)) { console.error('E3 未拦截清单外双重编码新文件'); failed = true; }
  const located = MOJI_LINES.map((_, i) => 'double-encoded\\.txt:' + (i + 1) + ':');
  for (const re of located) {
    if (!new RegExp(re).test(first.out)) { console.error('E3 命中未定位到行号（' + re + '）'); failed = true; }
  }
  if (!/→ 编码门禁通过/.test(first.out)) { console.error('E3 明细未给出还原后的可读文本，无法人工核对判据'); failed = true; }
  // D8 §1.4-②③：正常中文与纯 ASCII 必绿（负向控制，缺了它就是「宁可误伤」的门禁）
  for (const clean of ['normal-chinese\\.txt', 'pure-ascii\\.txt']) {
    if (new RegExp('[^\n]*' + clean).test(first.out)) { console.error('E3 误报负向控制样本 ' + clean); failed = true; }
  }
}

// D8 §一-1.3 fail-closed：扫到 0 个证据文件不得报通过（repo 指错 / CodeReview 缺失同理）。
{
  const empty = path.join(tmp, 'empty-root');
  fs.mkdirSync(path.join(empty, 'CodeReview'), { recursive: true });
  const r = capture(() => execFileSync(process.execPath, [CHECK, '--root', empty, '--baseline', EMPTY_BASELINE, '--all-worktree'], { stdio: 'pipe' }));
  console.log('空集扫描输出: EXIT=' + r.code + ' ' + r.out.trim());
  if (r.code === 0) { console.error('扫到 0 个证据文件仍放行 ⇒ fail-closed 失效'); failed = true; }
  else if (!/拒绝放行/.test(r.out)) { console.error('扫到 0 个证据文件被拒但未声明 fail-closed 原因'); failed = true; }
}

// D5 §一-1「修前假绿」对照：把排除判据改回旧的扩展名白名单语义，得到「扩面之前」的门禁副本，
// 它必须放行上面 4 件清单外样本 —— 否则无法证明扩面真的闭合了一个旧缺口。
{
  const beforeGate = path.join(tmp, 'check_evidence_encoding_before.js');
  const src = fs.readFileSync(CHECK, 'utf8');
  const OLD_SEMANTICS = '  return BINARY_EXT.has(path.extname(name).toLowerCase());';
  const patched = portal(src).replace(OLD_SEMANTICS, '  return !/\\.(txt|log|csv|xml)$/i.test(name); // 「修前」对照：旧白名单之外的件一律不扫');
  if (!src.includes(OLD_SEMANTICS) || patched === portal(src)) {
    console.error('修前对照异常：未能在门禁源码上定位旧白名单判据，无法构造「扩面之前」的副本');
    failed = true;
  } else {
    fs.writeFileSync(beforeGate, patched);
    let out = '';
    try { out = execFileSync(process.execPath, [beforeGate, '--root', tmp, '--baseline', EMPTY_BASELINE, '--all-worktree'], { stdio: 'pipe' }).toString('utf8'); }
    catch (e) { out = (e.stderr || Buffer.alloc(0)).toString('utf8') + (e.stdout || Buffer.alloc(0)).toString('utf8'); }
    const missed = ['build-commands.cmd', 'scan-list.md', 'summary.json', 'raw-console-output'].filter(n => !out.includes(n));
    if (missed.length !== 4) { console.error('修前对照失败：旧口径副本仍拦下了 ' + (4 - missed.length) + ' 件清单外样本 ⇒ 无法证明扩面必要'); failed = true; }
    else console.log('修前对照通过：旧白名单口径对 ' + missed.join(' / ') + ' 全部视而不见（假绿实锤）');
    if (assertCopyAlive(out, 'D5 扩面')) { /* 副本可信 */ } else failed = true;
    fs.rmSync(beforeGate, { force: true });
  }
}

// D8 §〇「修前假绿」对照：把 E3 判据摘掉（=乙 D8 之前的门禁），双重编码件必须整份放行。
// 这一步证明的不是「新判据会拦」，而是「旧判据真的看不见」：E1/E2 对合法 UTF-8 的乱码恒绿。
{
  const noE3Gate = path.join(tmp, 'check_evidence_encoding_before_e3.js');
  const src = portal(fs.readFileSync(CHECK, 'utf8'));
  const ENTRY = 'function detectDoubleEncoding(line) {';
  const patched = src.replace(ENTRY, ENTRY + "\n  return null; // 「修前」对照：E3 判据未接入（乙 D8 之前）");
  if (patched === src) {
    console.error('修前对照异常：未能定位 detectDoubleEncoding，无法构造「E3 接入之前」的副本');
    failed = true;
  } else {
    fs.writeFileSync(noE3Gate, patched);
    let out = '';
    let code = 0;
    try { out = execFileSync(process.execPath, [noE3Gate, '--root', tmp, '--baseline', EMPTY_BASELINE, '--all-worktree'], { stdio: 'pipe' }).toString('utf8'); }
    catch (e) { code = typeof e.status === 'number' ? e.status : 1; out = (e.stderr || Buffer.alloc(0)).toString('utf8') + (e.stdout || Buffer.alloc(0)).toString('utf8'); }
    if (!assertCopyAlive(out, 'D8 E3')) failed = true;
    else if (out.includes('double-encoded.txt') || /E3 双重编码命中 [1-9]/.test(out)) { console.error('修前对照异常：E3 摘掉后仍报双重编码件 ⇒ 副本不可信'); failed = true; }
    else if (code === 0) { console.error('修前对照异常：E3 摘掉后 EXIT=0，说明 E1/E2 样本也不在旧面上，本对照不成立'); failed = true; }
    else console.log('修前对照通过：E3 接入之前（EXIT=' + code + '），3 行双重编码乱码在 E1/E2 下全部隐身 ⇒ D8 §〇 恒绿实锤');
    fs.rmSync(noE3Gate, { force: true });
  }
}

// D8 §1.2 存量清单必须能从门禁自身复算：--list-mojibake 逐行 命中数<TAB>路径 + 汇总计数
{
  const r = capture(() => execFileSync(process.execPath, [CHECK, '--root', tmp, '--baseline', EMPTY_BASELINE, '--all-worktree', '--list-mojibake'], { stdio: 'pipe' }));
  console.log('--list-mojibake 输出:\n' + r.out.trim());
  if (r.code !== 0) { console.error('--list-mojibake 应 EXIT=0（它是取证口径，不是判定口径）'); failed = true; }
  if (!/^2\tCodeReview\/mojibake-stock\.txt$/m.test(r.out)) { console.error('--list-mojibake 未登记存量件的命中数（递减无依据）'); failed = true; }
  if (!/3\tCodeReview\/double-encoded\.txt/.test(r.out)) { console.error('--list-mojibake 未登记清单外新件的命中数'); failed = true; }
  if (!/# 扫描 \d+ 件 \/ 命中 \d+ 行 \/ \d+ 件/.test(r.out)) { console.error('--list-mojibake 缺「扫描 N 件 / 命中 M 行」汇总'); failed = true; }
}

// 存量基线：只豁免登记文件，其余违规照拦
const scoped = capture(() => runChecker(STOCK_BASELINE));
console.log('存量基线（ps-redirect.log=20 / mojibake-stock.txt=2）命中输出:\n' + (scoped.out || '(全绿)'));
if (/E1 .*ps-redirect\.log/.test(scoped.out)) { console.error('存量基线未豁免登记文件'); failed = true; }
if (!/E1 .*nul-in-body\.xml/.test(scoped.out)) { console.error('存量基线外新增 NUL 文件未被拦截'); failed = true; }
if (!/E2 .*gbk\.csv/.test(scoped.out)) { console.error('存量基线外 GBK 文件未被拦截'); failed = true; }
// D8 §1.4-④：存量登记件不报红，但命中明细必须仍看得见（否则「只减不增」无从核对）
if (/E3 [^\n]*mojibake-stock\.txt/.test(scoped.out)) { console.error('E3 存量登记件被误判为违规'); failed = true; }
if (!/mojibake-stock\.txt:1:/.test(scoped.out)) { console.error('E3 存量登记件的命中明细被隐藏 ⇒ 无法核对递减'); failed = true; }
if (/normal-chinese\.txt|pure-ascii\.txt/.test(scoped.out)) { console.error('负向控制样本在存量基线口径下被误报'); failed = true; }

// 存量件计数上升必须回到违规集
fs.appendFileSync(path.join(CR, 'ps-redirect.log'), Buffer.from([0x00]));
const risen = capture(() => runChecker(STOCK_BASELINE));
console.log('存量件 NUL 上升后输出:\n' + (risen.out || '(全绿)'));
if (!/E1 [^\n]*存量基线=20[^\n]*ps-redirect\.log/.test(risen.out)) { console.error('存量件 NUL 计数上升未被拦截'); failed = true; }
fs.writeFileSync(path.join(CR, 'ps-redirect.log'), Buffer.concat([Buffer.from([0xFF, 0xFE]), Buffer.from('Tests Passed : 100\r\n', 'utf16le')]));

// D8 §1.2 只减不增：存量登记件多出一行乱码即红（还原归 B2/B3/A3，门只拦新增）
fs.appendFileSync(path.join(CR, 'mojibake-stock.txt'), mojibake(MOJI_LINES[2]) + '\r\n');
const mojibakeRisen = capture(() => runChecker(STOCK_BASELINE));
console.log('存量件 E3 命中上升后输出:\n' + (mojibakeRisen.out || '(全绿)'));
if (!/E3 [^\n]*3 行 > 存量基线 2[^\n]*mojibake-stock\.txt/.test(mojibakeRisen.out)) { console.error('E3 存量件命中数上升未被拦截'); failed = true; }
fs.writeFileSync(path.join(CR, 'mojibake-stock.txt'), Buffer.from(MOJI_LINES.slice(0, 2).map(mojibake).join('\r\n') + '\r\n', 'utf8'));

// 剔除违规件后应全绿（chart.png 故意留着：它被排除集挡住，留着仍应全绿）
for (const f of ['ps-redirect.log', 'nul-in-body.xml', 'gbk.csv', 'build-commands.cmd', 'scan-list.md', 'summary.json', 'raw-console-output', 'double-encoded.txt', 'mojibake-stock.txt']) fs.rmSync(path.join(CR, f));
try {
  const out = runChecker(STOCK_BASELINE).toString('utf8');
  console.log('清理后复跑: ' + out.trim());
  if (!/E3 命中 0 行/.test(out)) { console.error('清理后 E3 仍报命中 ⇒ 判据不稳定（同一份干净集应恒绿）'); failed = true; }
} catch (e) {
  console.error('负向样本测试失败：干净样本集仍被拒绝\n' + (e.stderr || Buffer.alloc(0)).toString('utf8'));
  failed = true;
}

fs.rmSync(tmp, { recursive: true, force: true });
console.log(failed ? 'NEGATIVE-TEST: FAIL' : 'NEGATIVE-TEST: PASS');
process.exit(failed ? 1 : 0);
