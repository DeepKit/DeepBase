// 丙类编码损坏门禁的负向样本测试（WO-20260924-AUDIT-甲-D8 §三 判据1/2/7 + §二 fail-closed）
//
// 证明的事（不是「新判据会拦」，而是「每类都有检测器、每类都真红、且看不见=会假绿」）：
//  ① 四类损坏各有检测器，且负向样本每类 ≥1 例全部红：
//     · 丙-A（有损 U+FFFD）    —— core.countFFFD 单元命中 + 门禁在丙-B 根行上打出「丙-A(U+FFFD×n)」定性；
//     · 丙-B（结构性吞 ASCII）  —— core.scanUnterminatedStrings 命中 + 门禁 EXIT=1 执法（本门唯一执法项）；
//     · 丙-C（双重编码乱码）    —— core.detectDoubleEncoding 可逆还原 + 门禁打出「丙-C(→…)」定性；
//     · 吞 ASCII 致编译错        —— --build-red-list 交叉标记：命中文件同时落在编译门红清单 ⇒「编译红=是」。
//     （丙-A/丙-C 的 tree-wide 违规归 encoding-gate G1/G6 唯一立法，本门只定性——见 check_mojibake.js 头注释；
//      故此处「红」= 检测器确实点亮（单元级 + 门禁定性级），执法级红= 丙-B 让门 EXIT=1。）
//  ② 对已知损坏样本准确定位到 文件:行。
//  ③ 三档留痕（FULL/LCS/DIFF）在 --list-hits 输出里可辨：构造三件分别落在 HEAD 干净 / 行可逆 / 不可逆。
//  ④ 存量「只减不增」：登记件在封顶内不红但明细仍可见；多出一处即回违规集；--emit-baseline 拒新增未登记件。
//  ⑤ fail-closed：扫到 0 个 .pas 必 EXIT≠0（root 指错 / .pas 缺失）。
//  ⑥ 修前假绿对照：摘掉丙-B 执法（=本门接入之前），含跨行未闭合串的 .pas 仍 EXIT=0「通过」⇒ 能力缺口实锤。
// 用法: node test_negative_sample.js   （退出码 0=门禁按预期拦截）
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');
const HERE = __dirname;
const CHECK = path.join(HERE, 'check_mojibake.js');
const CORE = path.join(HERE, '../mojibake-core.js');
const core = require(CORE);

let failed = false;
function bad(msg) { console.error('负向样本测试失败：' + msg); failed = true; }

// 双重编码乱码构造：中文原文的 UTF-8 字节按 GBK 误读成另一串汉字，再以 UTF-8 落盘。
// 与 detectDoubleEncoding 的判据同构（编回 GB18030 再按 UTF-8 解 → 还原可读中文）。
const mojibake = s => new TextDecoder('gbk').decode(Buffer.from(s, 'utf8')).replace(/\uFFFD/g, '?');

// ── 临时 git 仓（门禁按 git ls-files 枚举 tracked .pas，故样本必须 commit 才进面）──
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'moji-'));
// 样本仓是 mkdtemp 出来的一次性夹具：本机全局 core.hooksPath 会把仓外的 encoding-gate pre-commit 钩子
// 挂进来（它拦的是真仓提交，与本夹具无关，且夹具里的 U+FFFD 样本本就是要测的损坏），
// 用一个空的 hooksPath 隔离掉，保证「夹具能落盘」与「真仓门禁」互不串。
const NOHOOKS = path.join(tmp, '.nohooks');
fs.mkdirSync(NOHOOKS);
function git(...a) {
  return execFileSync('git', ['-C', tmp, '-c', 'core.quotepath=false', '-c', 'core.hooksPath=' + NOHOOKS, '-c', 'user.email=t@t', '-c', 'user.name=t', ...a],
    { encoding: 'utf8' });
}
git('init', '-q');
fs.writeFileSync(path.join(tmp, '.gitattributes'), '*.pas text eol=lf\n');

const MOJI_OPEN = mojibake('日志导出文件清单');      // 合法 UTF-8、无 U+FFFD、可逆 → 丙-C
const FFFD = String.fromCharCode(0xFFFD);            // 有损替换 → 丙-A

const FIX = {};
// 正样本：正常中文 + 正确闭合的单行串 ⇒ 丙-B 恒 0 事件（缺了它门禁一开就误伤全库 .pas）
FIX['Clean.pas'] = 'unit Clean;\ninterface\nimplementation\nprocedure P;\nvar s: string;\nbegin\n  s := \'正常中文与 ASCII 混排\';\n  s := \'再一行也闭合\';\nend.\n';
// 正样本：纯 ASCII
FIX['Ascii.pas'] = 'unit Ascii;\nbegin\n  Result := 1;\nend.\n';
// 丙-B + 丙-C：跨行未闭合串，起始行是双重编码乱码（HEAD 也脏 → 行可逆 → LCS）
FIX['DoubleB.pas'] = 'unit DoubleB;\nbegin\n  s := \'' + MOJI_OPEN + '\n        continue\';\nend.\n';
// 丙-B + 丙-A：跨行未闭合串，起始行含裸 U+FFFD（不可逆 → DIFF）
FIX['LossyA.pas'] = 'unit LossyA;\nbegin\n  s := \'前' + FFFD + '后数据\n  续\';\nend.\n';
// 丙-B 存量件：登记在基线封顶内（不红，但明细仍可见）
FIX['StockB.pas'] = 'unit StockB;\nbegin\n  s := \'' + mojibake('描述串被吞掉引号') + '\n  更多\';\nend.\n';
// 回归件：HEAD 干净、工作树引入丙-B → HEAD 计数 0 → FULL 档
FIX['Regression.pas'] = 'unit Regression;\nbegin\n  s := \'未损坏\';\nend.\n';

for (const [n, t] of Object.entries(FIX)) fs.writeFileSync(path.join(tmp, n), Buffer.from(t, 'utf8'));
git('add', '-A');
git('commit', '-q', '-m', 'fixtures');
// Regression 提交干净版后，仅改工作树引入跨行未闭合串（不重提交）⇒ HEAD=0 事件、工作树>0 ⇒ FULL 档
fs.writeFileSync(path.join(tmp, 'Regression.pas'),
  Buffer.from('unit Regression;\nbegin\n  s := \'' + mojibake('新引入的损坏描述') + '\n  续\';\nend.\n', 'utf8'));

const EMPTY_BASELINE = path.join(tmp, 'empty-baseline.json');
const STOCK_BASELINE = path.join(tmp, 'stock-baseline.json');
fs.writeFileSync(EMPTY_BASELINE, JSON.stringify({ _comment: '负向样本空基线', pbStock: {} }));
// 存量基线的 count 由 core 复算（不硬抄数字，抄错就等于把「只减不增」写坏）
const stockCount = core.scanUnterminatedStrings(fs.readFileSync(path.join(tmp, 'StockB.pas'), 'utf8')).length;
fs.writeFileSync(STOCK_BASELINE, JSON.stringify({
  _comment: '负向样本存量基线',
  pbStock: { 'StockB.pas': { count: stockCount, reason: '负向样本：存量丙-B，只减不增用' } },
}));

function run(args, root) {
  return execFileSync(process.execPath, [CHECK, '--root', root || tmp, ...args], { stdio: 'pipe' });
}
function capture(fn) {
  try { return { code: 0, out: fn().toString('utf8') }; }
  // e.status 而非固定 1：区分「违规 EXIT=1」与「门禁自身失败 EXIT=2/3」
  catch (e) { return { code: typeof e.status === 'number' ? e.status : 1, out: (e.stderr || Buffer.alloc(0)).toString('utf8') + (e.stdout || Buffer.alloc(0)).toString('utf8') }; }
}

// ── 单元级：四类检测器各自命中（core 直接调用，隔离验证检测器本身）──────────────
{
  const lA = '含替换符' + FFFD + '的损坏行';
  if (core.countFFFD(lA) < 1) bad('丙-A 检测器：countFFFD 未数出行内 U+FFFD');
  if (core.countFFFD('干净中文行没有任何替换符') !== 0) bad('丙-A 检测器：countFFFD 在干净行误报');
  const rev = core.gbkReverseTable();
  if (!rev) bad('丙-C 检测器：本机无 GB18030，无法评估（应由门禁 fail-closed，但单元侧无法继续）');
  else {
    const d = core.detectDoubleEncoding(MOJI_OPEN, rev);
    if (!d || !/日志导出/.test(d.restored)) bad('丙-C 检测器：detectDoubleEncoding 未把双重编码还原回可读中文（' + (d ? d.restored : 'null') + '）');
    if (core.detectDoubleEncoding('完全正常的中文行不需要还原', rev)) bad('丙-C 检测器：正常中文行被判为双重编码（误报）');
  }
  const evs = core.scanUnterminatedStrings('procedure P;\nbegin\n  s := \'跨行\n  未闭合\';\nend.\n');
  if (evs.length !== 1 || evs[0].open !== 2 || evs[0].close !== 3) bad('丙-B 检测器：scanUnterminatedStrings 未定位跨行串 open/close（' + JSON.stringify(evs) + '）');
  if (core.scanUnterminatedStrings('begin\n  s := \'闭合的\';\nend.\n').length !== 0) bad('丙-B 检测器：正确闭合串被误判为吞 ASCII');
  if (core.scanUnterminatedStrings('begin\n  s := \'内嵌\'\'转义引号\';\nend.\n').length !== 0) bad('丙-B 检测器：\'\' 转义引号被当成串边界（误判跨行）');
}

// ── 门禁级：空基线下 丙-B 必红，且三类定性 + 三档留痕在 --list-hits 里可辨 ──────
const first = capture(() => run(['--baseline', EMPTY_BASELINE]));
console.log('门禁输出（空基线，预期 EXIT=1 + 多类定性）:\n' + first.out);
if (first.code === 0) bad('丙-B 未被拦截：含跨行未闭合串的空基线扫描仍 EXIT=0');
// 违规必须逐件点名（判据 2：定位到文件；行号在 --list-hits 侧核对）
for (const f of ['DoubleB.pas', 'LossyA.pas', 'Regression.pas']) {
  if (!new RegExp(f.replace('.', '\\.')).test(first.out)) bad('违规清单未点名 ' + f);
}
if (/Clean\.pas|Ascii\.pas/.test(first.out)) bad('门禁误报正样本 Clean.pas / Ascii.pas');

// --list-hits：取证口径，逐条 文件:行 + 三档留痕 + 丙-A/丙-C 定性（判据 2 + 判据 1 定性 + 判据 7）
const lh = capture(() => run(['--baseline', EMPTY_BASELINE, '--list-hits']));
console.log('--list-hits 输出:\n' + lh.out);
if (lh.code !== 0) bad('--list-hits 应 EXIT=0（它是取证口径，不是判定口径）');
if (!/丙-B@L\d+->L\d+/.test(lh.out)) bad('--list-hits 未给出 丙-B 起止行定位（判据 2 文件:行）');
if (!/# 扫描 \d+ 个 \.pas \/ 丙-B 命中 \d+ 处 \/ \d+ 件/.test(lh.out)) bad('--list-hits 缺「扫描 N / 命中 M / K 件」汇总');
// 定性：同一根行上点亮丙-A（LossyA 起始行含 U+FFFD）与丙-C（DoubleB 起始行为双重编码）
if (!/丙-A\(U\+FFFD/.test(lh.out)) bad('丙-A 检测器未在门禁输出中对损坏根行做定性标注');
if (!/丙-C\(→/.test(lh.out)) bad('丙-C 检测器未在门禁输出中给出可逆还原定性');
// 三档留痕（判据 7）：Regression=FULL / DoubleB=LCS / LossyA=DIFF（行格式 rel:行号: [档] ...）
for (const [f, tier] of [['Regression\\.pas', 'FULL'], ['DoubleB\\.pas', 'LCS'], ['LossyA\\.pas', 'DIFF']]) {
  if (!new RegExp(f + ':\\d+: \\[' + tier + '\\]').test(lh.out)) bad('三档留痕不可辨：' + f + ' 未标为 ' + tier);
}

// ── 编译门交叉标记（§1.3 / 判据 6）：--build-red-list 内文件=是，其余=否，未提供=未提供 ──
const REDLOG = path.join(tmp, 'build-red.log');
fs.writeFileSync(REDLOG, 'Build started\n  DoubleB.pas(6) Fatal: F2063 Could not compile\n  StockB.pas(3) Error E2029 \'END\' expected\nDone.\n', 'utf8');
const cross = capture(() => run(['--baseline', EMPTY_BASELINE, '--list-hits', '--build-red-list', REDLOG]));
console.log('编译红交叉标记输出（节选）:\n' + cross.out.split('\n').filter(l => /编译红/.test(l)).join('\n'));
if (!/DoubleB\.pas[^\n]*编译红=是/.test(cross.out)) bad('编译门交叉标记：红清单内 DoubleB.pas 未标为「编译红=是」');
if (!/StockB\.pas[^\n]*编译红=是/.test(cross.out)) bad('编译门交叉标记：StockB.pas 在红清单内却未标为是');
if (!/Regression\.pas[^\n]*编译红=否/.test(cross.out)) bad('编译门交叉标记：清单外 Regression.pas 未标为「编译红=否」');
if (!/编译红=未提供/.test(lh.out)) bad('未提供 --build-red-list 时应显式标注「编译红=未提供」而非静默');

// ── 存量基线：登记件在封顶内不红，但明细仍可见（看得见才谈得上递减）──────────────
const stockRun = capture(() => run(['--baseline', STOCK_BASELINE]));
const stock = capture(() => run(['--baseline', STOCK_BASELINE, '--list-hits']));
// StockB 已登记（count=实测），不应出现在违规清单里；违规行以 `: <rel>` 结尾
if (new RegExp('\\n\\s+丙-B[^\\n]*: StockB\\.pas').test(stockRun.out)) bad('存量登记件 StockB.pas 被误判为违规');
if (!/违规 3 项/.test(stockRun.out)) bad('存量基线下违规数应为 3（DoubleB/LossyA/Regression），StockB 已豁免');
if (!/StockB\.pas:\d+:/.test(stock.out)) bad('存量登记件 StockB.pas 的丙-B 明细被隐藏 ⇒ 无法核对递减');
// 其余未登记件仍须红
if (stockRun.code === 0) bad('存量基线未拦截清单外新增丙-B 件');
if (!/DoubleB\.pas|LossyA\.pas/.test(stockRun.out)) bad('存量基线外新增件未被拦截');

// ── 只减不增：登记件多出一处丙-B 即回违规集 ──────────────────────────────────
const stockBefore = fs.readFileSync(path.join(tmp, 'StockB.pas'), 'utf8');
fs.writeFileSync(path.join(tmp, 'StockB.pas'), Buffer.from(stockBefore.replace("end.\n", "  t := '又吞一次\n  续';\nend.\n"), 'utf8'));
const risen = capture(() => run(['--baseline', STOCK_BASELINE]));
console.log('存量件丙-B 上升后输出:\n' + (risen.out || '(全绿)'));
if (risen.code === 0) bad('存量件丙-B 计数上升仍放行（只减不增失效）');
if (!new RegExp('>\\s*存量\\s*' + stockCount + '[^\\n]*StockB\\.pas').test(risen.out)) bad('存量件上升未点名「> 存量 ' + stockCount + '」');
fs.writeFileSync(path.join(tmp, 'StockB.pas'), Buffer.from(stockBefore, 'utf8'));

// ── --emit-baseline 拒新增未登记件（判据 3「阻止新增条目被静默加入」）────────────
// 夹具仓 ≠ 仓库根，须显式 --allow-narrow-root 才会走到「新增键」比对（窄根自证是另一条判据，见共享测试 C1）。
const emit = capture(() => run(['--baseline', EMPTY_BASELINE, '--emit-baseline', '--allow-narrow-root']));
console.log('--emit-baseline（空基线）输出:\n' + (emit.out || '(全绿)'));
if (emit.code === 0) bad('--emit-baseline 在存在未登记丙-B 件时不应 EXIT=0（那等于静默扩面）');
if (!/拒绝新增|未登记/.test(emit.out)) bad('--emit-baseline 未声明拒绝新增未登记件');

// ── fail-closed：扫到 0 个 .pas 必 EXIT≠0 ──────────────────────────────────
{
  const empty = path.join(tmp, 'empty-repo');
  fs.mkdirSync(empty, { recursive: true });
  execFileSync('git', ['-C', empty, '-c', 'core.hooksPath=' + NOHOOKS, 'init', '-q']);
  fs.writeFileSync(path.join(empty, 'readme.txt'), 'no pas here\n', 'utf8');
  execFileSync('git', ['-C', empty, '-c', 'core.hooksPath=' + NOHOOKS, '-c', 'user.email=t@t', '-c', 'user.name=t', 'add', '-A']);
  execFileSync('git', ['-C', empty, '-c', 'core.hooksPath=' + NOHOOKS, '-c', 'user.email=t@t', '-c', 'user.name=t', 'commit', '-q', '-m', 'e']);
  const r = capture(() => run(['--baseline', EMPTY_BASELINE], empty));
  console.log('空 .pas 仓输出: EXIT=' + r.code + ' ' + r.out.trim());
  if (r.code === 0) bad('扫到 0 个 .pas 仍放行 ⇒ fail-closed 失效');
  else if (!/拒绝放行|fail-closed|扫描 0/.test(r.out)) bad('扫到 0 个 .pas 被拒但未声明 fail-closed 原因');
}

// ── 修前假绿对照：摘掉丙-B 执法（=本门接入之前），含跨行未闭合串仍「通过」──────
// 证明的不是「新判据会拦」，而是「旧门禁真看不见」：本面此前无任何门禁执法。
{
  const before = path.join(tmp, 'check_before.js');
  const src = fs.readFileSync(CHECK, 'utf8');
  const ENTRY = 'if (events.length > cap) {';
  const patched = src.replace(ENTRY, 'if (false) { // 「修前」对照：丙-B 执法未接入');
  if (patched === src) bad('修前对照异常：未能定位丙-B 执法判据，无法构造「接入之前」的副本');
  else {
    // 修前副本落在 tmp 内时 require('../mojibake-core') 等会 MODULE_NOT_FOUND，
    // 而 MODULE_NOT_FOUND 会让「未拦住」变成假通过 ⇒ 共享依赖一律改写为绝对路径。
    let portal = patched;
    for (const m of ['gate-args', 'gate-skip', 'gate-baseline', 'gate-emit-guard', 'mojibake-core']) {
      portal = portal.replace("require('../" + m + "')", 'require(' + JSON.stringify(path.resolve(HERE, '../' + m + '.js')) + ')');
    }
    fs.writeFileSync(before, portal);
    const r = capture(() => execFileSync(process.execPath, [before, '--root', tmp, '--baseline', EMPTY_BASELINE], { stdio: 'pipe' }));
    console.log('修前对照（丙-B 执法摘掉）: EXIT=' + r.code + '\n' + r.out.trim());
    // 副本必须证明自己真的跑起来并扫到了 .pas，否则「它放行了」不成立
    if (!/扫描 \d+ 个 \.pas/.test(r.out)) bad('修前对照异常：副本连 .pas 都没扫到（可能 MODULE_NOT_FOUND），副本不可信');
    else if (r.code !== 0) bad('修前对照异常：丙-B 执法摘掉后副本仍 EXIT≠0 ⇒ 本面另有执法源，对照不成立');
    else console.log('修前对照通过：丙-B 接入之前（EXIT=0「通过」），跨行未闭合串在旧门禁下隐身 ⇒ 甲-D8 §〇 能力缺口实锤');
    fs.rmSync(before, { force: true });
  }
}

fs.rmSync(tmp, { recursive: true, force: true });
console.log(failed ? 'NEGATIVE-TEST: FAIL' : 'NEGATIVE-TEST: PASS');
process.exit(failed ? 1 : 0);
