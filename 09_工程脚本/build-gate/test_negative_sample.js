// 编译门禁负向样本（WO-20260923-AUDIT-甲-D3 §2.4；WO-20260923-AUDIT-甲-D4 §3.2/§3.3 补包面与清单面；
// WO-20260924-AUDIT-甲-D7 段4 补命名空间声明面）
//
// 这道门的价值全在「红得可信」上：S-3 的根因不是没人编译，而是没有任何机械判定，
// 所以负向样本必须证明三件事——
//   1) 输入面不可信时不放行（不存在根 / 空扫描 / 索引与磁盘不一致 / 部分扫描）；
//   2) 代码真在编译（语法错误的 .dpr 必须被 dcc64 拦下，而不是只做文件枚举就报绿）；
//   3) 判定不恒真（合法 .dpr 必须能过，否则「红」没有信息量）。
// D4 把这三件事逐条搬到 .dpk 包面与外部契约清单面上：三面各自的「计数为 0 / 部分扫描 / BUILD_EXIT≠0」都要红，
// 且每面都留正对照——缺正对照的红无法区分「拦住了断裂」与「恒红」。
// 每个用例都在 %TEMP% 里建独立 git 仓库跑真实进程，不碰本仓工作树。
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawnSync } = require('child_process');

const HERE = __dirname;
const GATE = path.join(HERE, 'check_build.js');

const OK_DPR = 'program OkProj;\n{$APPTYPE CONSOLE}\nbegin\nend.\n';
// 语法错误样本：F 前缀是 dcc64 的 Fatal，E 前缀是 Error，两者都必须被 firstErrorLine 抓到。
const BAD_DPR = 'program BadProj;\nbegin\n  this is not valid pascal\nend.\n';
// 包面样本（WO-20260923-AUDIT-甲-D4 §3.3）：合法最小包同时走 {$R *.res} 补生成路径；
// 改坏的包用的是单元里的类型错误（E2010），不是缺文件——判据 3 要的是「真在编译包」，F 类不算。
const OK_DPK = 'package OkPkg;\n{$R *.res}\nrequires\n  rtl;\nend.\n';
const BAD_DPK = 'package BadPkg;\n{$R *.res}\nrequires\n  rtl;\ncontains\n  BadUnit in \'BadUnit.pas\';\nend.\n';
const BAD_UNIT = 'unit BadUnit;\ninterface\nvar X: Integer;\nimplementation\ninitialization\n  X := \'not-a-number\';\nend.\n';
// 命名空间样本（WO-20260924-AUDIT-甲-D7 段4）：DBClient 只有加进 -NS 才解析得了，StrUtils 靠缺省集里的 System。
// 两件放一起，一次编译同时验「工程级声明真进了 -NS」与「声明没把缺省集顶掉」（并集而非替换）。
const NS_DEMO_DPR = 'program NsDemo;\n{$APPTYPE CONSOLE}\nuses DBClient, StrUtils;\nbegin\nend.\n';

let failed = false;
const trash = [];
const trashFiles = [];

function say(msg) { console.log(msg); }
function bug(msg) { console.error('✗ ' + msg); failed = true; }

function makeRepo(name, files) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'buildgate-' + name + '-'));
  trash.push(root);
  git(root, ['init', '-q']);
  for (const [rel, content] of Object.entries(files)) {
    const abs = path.join(root, rel);
    fs.mkdirSync(path.dirname(abs), { recursive: true });
    fs.writeFileSync(abs, content, 'utf8');
    git(root, ['add', '-f', '--', rel]);
  }
  return root;
}

function git(cwd, args) {
  const r = spawnSync('git', args, { cwd, encoding: 'utf8' });
  if (r.status !== 0) bug(`临时仓库 git ${args.join(' ')} 失败：${(r.stderr || r.stdout).trim()}`);
  return r;
}

function runGate(args, env) {
  const r = spawnSync(process.execPath, [GATE, ...args], { encoding: 'utf8', env: env && Object.assign({}, process.env, env) });
  return { code: r.status, out: (r.stdout || '') + (r.stderr || '') };
}

function expectExit(label, res, code, mustContain) {
  if (res.code !== code) {
    bug(`${label}：期望 EXIT=${code}，实际 EXIT=${res.code}\n${res.out}`);
    return;
  }
  for (const tag of mustContain || []) {
    if (!res.out.includes(tag)) {
      bug(`${label}：EXIT=${code} 对上了，但输出缺少判定依据「${tag}」——只有退出码没有归因不算取证\n${res.out}`);
      return;
    }
  }
  say(`✓ ${label} => EXIT=${code}${mustContain ? '（含 ' + mustContain.join(' / ') + '）' : ''}`);
}

// ①--root 指向不存在/写错的路径：输入面不可信，不得放行
expectExit('负样本①不存在根', runGate(['--all', '--root', path.join(os.tmpdir(), 'buildgate-no-such-root-' + Date.now())]), 2,
  ['--root 不是存在的目录']);

// ②空扫描：仓库存在但一个 .dpr 都没有，「全过」必须是红而不是真空绿
{
  const root = makeRepo('empty', { 'README.md': '# no projects here\n' });
  expectExit('负样本②空扫描', runGate(['--all', '--root', root]), 2, ['待编译 .dpr 计数为 0']);
}

// ③故意语法错误的 .dpr 已被 git 跟踪：证明真在调用 dcc64 编译，而非只做文件枚举
{
  const root = makeRepo('bad', { 'BadProj.dpr': BAD_DPR });
  expectExit('负样本③语法断裂', runGate(['--all', '--root', root]), 1, ['BadProj.dpr', 'BUILD_EXIT=1', '失败=1', '被跳过=0']);
}

// ④正向对照：合法最小 .dpr 必须过。缺了这条，③ 的「红」无法区分「拦住了断裂」与「恒红」。
{
  const root = makeRepo('ok', { 'OkProj.dpr': OK_DPR });
  expectExit('正对照④合法工程', runGate(['--all', '--root', root]), 0, ['成功=1', 'DPR总数=1']);
}

// ⑤未跟踪但存在的 .dpr：绕开编译判定的典型形态，红
{
  const root = makeRepo('untracked', { 'OkProj.dpr': OK_DPR });
  fs.writeFileSync(path.join(root, 'Ghost.dpr'), OK_DPR, 'utf8');
  expectExit('负样本⑤未跟踪 .dpr', runGate(['--all', '--root', root]), 2, ['未跟踪但存在的 .dpr']);
}

// ⑥索引里有、磁盘上被删：清单与工作树不一致，扫描面不可信，红
{
  const root = makeRepo('deleted', { 'OkProj.dpr': OK_DPR });
  fs.unlinkSync(path.join(root, 'OkProj.dpr'));
  expectExit('负样本⑥索引与工作树不一致', runGate(['--all', '--root', root]), 2, ['git 索引里有、工作树里却没有']);
}

// ⑦readdir 失败 = 部分扫描。Windows 下没有任何可移植、可复现的权限/链接构造能稳定让
// fs.readdirSync 抛错（icacls deny 在本机被令牌权限绕过，broken junction 会被 Node 归为
// symlink 而根本不进遍历队列），所以这里用注入式故障：子进程替换 fs.readdirSync，让门禁
// 遍历到 sealed 目录时抛 EPERM，其余路径走真实实现——判定仍由门禁进程自己产出（EXIT 与
// 归因文案都是真实代码路径的结果），而非测试进程自证。
{
  const root = makeRepo('seal', { 'OkProj.dpr': OK_DPR });
  fs.mkdirSync(path.join(root, 'sealed'), { recursive: true });
  fs.writeFileSync(path.join(root, 'sealed', 'Ghost.dpr'), OK_DPR, 'utf8');
  const injector = path.join(os.tmpdir(), 'buildgate-inject-readdir-' + Date.now() + '.js');
  trashFiles.push(injector);
  fs.writeFileSync(injector, [
    'const fs = require("fs");',
    'const real = fs.readdirSync;',
    'fs.readdirSync = function (p, ...a) {',
    '  if (String(p) === process.env.BG_SEAL) throw Object.assign(new Error("injected"), { code: "EPERM" });',
    '  return real.call(fs, p, ...a);',
    '};',
    'process.argv = [process.execPath, process.env.BG_GATE, "--all", "--root", process.env.BG_ROOT];',
    'require(process.env.BG_GATE).main(process.argv.slice(2));',
  ].join('\n'), 'utf8');
  const r = spawnSync(process.execPath, [injector], {
    encoding: 'utf8',
    env: Object.assign({}, process.env, { BG_GATE: GATE, BG_ROOT: root, BG_SEAL: path.join(root, 'sealed') }),
  });
  expectExit('负样本⑦部分扫描（readdir 注入失败）', { code: r.status, out: (r.stdout || '') + (r.stderr || '') }, 2,
    ['readdir 失败', '部分扫描不得报绿']);
}

// ⑧⑨ 范围声明缺失/冲突：宁可不放行，也不静默选定一个扫描面
expectExit('负样本⑧未声明范围', runGate(['--root', makeRepo('norangeso', { 'OkProj.dpr': OK_DPR })]), 3, ['未指定编译范围']);
{
  const root = makeRepo('both', { 'OkProj.dpr': OK_DPR });
  expectExit('负样本⑨--all 与 --dpr 互斥', runGate(['--all', '--dpr', 'OkProj.dpr', '--root', root]), 3, ['--all 与 --dpr 互斥']);
}

// ⑩ --dpr 取值不可信时不得静默缩小扫描面：路径不存在/未跟踪/落在 root 外，一律红
{
  const root = makeRepo('dprscope', { 'OkProj.dpr': OK_DPR });
  expectExit('负样本⑩--dpr 指向未跟踪文件', runGate(['--dpr', 'Nope.dpr', '--root', root]), 2, ['不是本仓已跟踪的 .dpr']);
  const outside = path.join(os.tmpdir(), 'buildgate-outside-' + Date.now() + '.dpr');
  trashFiles.push(outside);
  fs.writeFileSync(outside, OK_DPR, 'utf8');
  expectExit('负样本⑪--dpr 落在 root 之外', runGate(['--dpr', outside, '--root', root]), 2, ['落在 --root 之外']);
}

// ⑫ 参数 fail-open 五类（与 gate-args.js 同一套契约，缺值/大小写/裸参数都不得被静默吞掉）
{
  const root = makeRepo('args', { 'OkProj.dpr': OK_DPR });
  const ARG_CASES = [
    ['未知参数', ['--rot', root]],
    ['已知参数缺值', ['--root']],
    ['裸位置参数', ['stray']],
    ['大小写不符', ['--ROOT', root]],
    ['值形似参数', ['--root', '--root']],
  ];
  for (const [label, argv] of ARG_CASES) {
    expectExit(`参数负样本(${label})`, runGate(argv), 3, ['fail-closed']);
  }
}

// ---- 以下为 WO-20260923-AUDIT-甲-D4 §3.2/§3.3 新增：三条 fail-closed 逐条在包面成立 + 包面正对照 + 清单面完整性 ----
// 既有 16 例（①-⑫）逐条保留、断言未改；这里只往上加。

function writeManifest(root, name, text) {
  const abs = path.join(root, name);
  fs.writeFileSync(abs, text, 'utf8');
  return abs;
}

// ⓬包面正对照：合法最小 .dpk 必须编过（顺带走 {$R *.res} 补生成路径）。缺了它，包面的「红」无法区分
// 「拦住了断裂」与「包面根本编不了所以恒红」。
{
  const root = makeRepo('dpk-ok', { 'OkPkg.dpk': OK_DPK });
  expectExit('包面正对照⓬合法包', runGate(['--all', '--root', root]), 0, ['DPK总数=1', '成功=1', '被跳过=0']);
}

// ⓭包面 fail-closed·BUILD_EXIT：故意改坏一个 .dpk（单元里放类型错误），必须在包面真红，且红的是 E 类编译错误
// 而不是 F 类文件缺失——后者只能证明「文件没找到」，证不了包被真编译。
{
  const root = makeRepo('dpk-bad', { 'BadPkg.dpk': BAD_DPK, 'BadUnit.pas': BAD_UNIT });
  const res = runGate(['--all', '--root', root]);
  expectExit('包面负样本⓭故意改坏 .dpk', res, 1, ['BadPkg.dpk', 'BUILD_EXIT=1', 'DPK总数=1', '失败=1', '被跳过=0', 'Error: E2010']);
  if (/Fatal:/.test(res.out)) bug('包面负样本⓭：输出含 Fatal: ——「改坏」退化成了 F 类断裂（文件缺失/依赖不可解析），不能证明包体被编译');
}

// ⓮包面 fail-closed·计数为 0：清单声明整面 all-dpk，而仓库里一个包都没有 ⇒ 声明落空必须是红，
// 不能因为「这一面没东西可编」就报成全过。
{
  const root = makeRepo('dpk-nopkg', { 'OkProj.dpr': OK_DPR });
  const mf = writeManifest(root, 'only-dpk.txt', 'all-dpk\n');
  expectExit('包面负样本⓮整面声明落空', runGate(['--manifest', mf, '--root', root]), 2, ['整面 all-dpk 计数为 0']);
}

// ⓯包面 fail-closed·readdir 失败：被封锁目录里放的是 .dpk（而非 .dpr），证明包面在同一次枚举里，
// 部分扫描同样不放行。注入方式与 ⑦ 一致（子进程替换 fs.readdirSync），判定仍由门禁进程自己产出。
{
  const root = makeRepo('dpk-seal', { 'OkPkg.dpk': OK_DPK });
  fs.mkdirSync(path.join(root, 'sealedPkg'), { recursive: true });
  fs.writeFileSync(path.join(root, 'sealedPkg', 'Ghost.dpk'), OK_DPK, 'utf8');
  const injector = path.join(os.tmpdir(), 'buildgate-inject-readdir-dpk-' + Date.now() + '.js');
  trashFiles.push(injector);
  fs.writeFileSync(injector, [
    'const fs = require("fs");',
    'const real = fs.readdirSync;',
    'fs.readdirSync = function (p, ...a) {',
    '  if (String(p) === process.env.BG_SEAL) throw Object.assign(new Error("injected"), { code: "EPERM" });',
    '  return real.call(fs, p, ...a);',
    '};',
    'process.argv = [process.execPath, process.env.BG_GATE, "--all", "--root", process.env.BG_ROOT];',
    'require(process.env.BG_GATE).main(process.argv.slice(2));',
  ].join('\n'), 'utf8');
  const r = spawnSync(process.execPath, [injector], {
    encoding: 'utf8',
    env: Object.assign({}, process.env, { BG_GATE: GATE, BG_ROOT: root, BG_SEAL: path.join(root, 'sealedPkg') }),
  });
  expectExit('包面负样本⓯部分扫描（.dpk 目录 readdir 注入失败）', { code: r.status, out: (r.stdout || '') + (r.stderr || '') }, 2,
    ['readdir 失败', '部分扫描不得报绿']);
}

// ⓰包面输入完整性：未跟踪但存在的 .dpk —— 绕开编译判定最典型的形态，红
{
  const root = makeRepo('dpk-untracked', { 'OkPkg.dpk': OK_DPK });
  fs.writeFileSync(path.join(root, 'Ghost.dpk'), OK_DPK, 'utf8');
  expectExit('包面负样本⓰未跟踪 .dpk', runGate(['--all', '--root', root]), 2, ['未跟踪但存在的 .dpk']);
}

// ⓱⓲清单面不可信：--manifest 指向不存在的文件 / 清单解析后零条目，两者都不许变成「无工程可编 ⇒ 通过」
expectExit('负样本⓱--manifest 文件不存在', runGate(['--manifest', path.join(os.tmpdir(), 'buildgate-no-such-manifest-' + Date.now() + '.txt'), '--root', makeRepo('mfmissing', { 'OkPkg.dpk': OK_DPK })]), 2,
  ['--manifest 读不到']);
{
  const root = makeRepo('mfempty', { 'OkPkg.dpk': OK_DPK });
  const mf = writeManifest(root, 'blank.txt', '# 只有注释和空行\n\n');
  expectExit('负样本⓲--manifest 清单为空', runGate(['--manifest', mf, '--root', root]), 2, ['--manifest 清单为空']);
}

// ---- 以下为 WO-20260924-AUDIT-甲-D7 段4 新增：命名空间声明面（外置清单的 fail-closed 五条 + 默认不放宽 + 只补不减）----
// 声明文件钉在门禁自己的 contracts/ 下：既不吃 --root，也不留参数/环境变量覆盖的口子——可传参就等于允许把
// 「放宽后的清单」临时传进门禁，那是门禁 bypass。代价是本面只能用注入式故障替换子进程读到的那份内容
// （与 ⑦/⓯ 同一惯例），判定与退出码仍由门禁进程自己的代码路径产出。
const NS_CONTRACT = path.join(HERE, 'contracts', '命名空间声明.txt');
// 缺省集从真实声明文件里取，测试不抄第二份清单：抄了就等于造出第二个真相源，「默认未放宽」的断言当场失效。
const NS_DEFAULT_LINE = fs.readFileSync(NS_CONTRACT, 'utf8').split(/\r?\n/).find((l) => l.startsWith('default='));
if (!NS_DEFAULT_LINE) bug(`命名空间声明没有 default 行，本面全部用例失去基准：${NS_CONTRACT}`);

let nsSeq = 0;
function runWithNamespace(contractText, args, throwOnRead) {
  const stamp = Date.now() + '-' + (++nsSeq);
  const repl = path.join(os.tmpdir(), 'buildgate-ns-contract-' + stamp + '.txt');
  const injector = path.join(os.tmpdir(), 'buildgate-inject-ns-' + stamp + '.js');
  trashFiles.push(repl, injector);
  fs.writeFileSync(repl, contractText, 'utf8');
  fs.writeFileSync(injector, [
    'const fs = require("fs");',
    'const real = fs.readFileSync;',
    'fs.readFileSync = function (p, ...a) {',
    '  if (String(p) !== process.env.BG_NS_TARGET) return real.call(fs, p, ...a);',
    '  if (process.env.BG_NS_THROW === "1") throw Object.assign(new Error("injected"), { code: "ENOENT" });',
    '  return real.call(fs, process.env.BG_NS_REPL, ...a);',
    '};',
    'process.argv = [process.execPath, process.env.BG_GATE, ...JSON.parse(process.env.BG_ARGV)];',
    'require(process.env.BG_GATE).main(process.argv.slice(2));',
  ].join('\n'), 'utf8');
  const r = spawnSync(process.execPath, [injector], {
    encoding: 'utf8',
    env: Object.assign({}, process.env, {
      BG_GATE: GATE,
      BG_NS_TARGET: NS_CONTRACT,
      BG_NS_REPL: repl,
      BG_NS_THROW: throwOnRead ? '1' : '0',
      BG_ARGV: JSON.stringify(args),
    }),
  });
  return { code: r.status, out: (r.stdout || '') + (r.stderr || '') };
}

// ⓳声明读不到：门禁自己的契约文件缺失时不许回退成「少给几个命名空间」，也不许静默按空清单跑
expectExit('命名空间负样本⓳声明读不到（注入 ENOENT）', runWithNamespace(NS_DEFAULT_LINE + '\n', ['--all', '--root', makeRepo('ns-missing', { 'OkProj.dpr': OK_DPR })], true), 2,
  ['命名空间声明读不到']);

// ⓴没有 default 行 / ㉑多行 default / ㉒行缺 '=' / ㉓等号后为空：四种写坏的声明一律红，且各自给归因
expectExit('命名空间负样本⓴没有 default 行', runWithNamespace('# 只有注释，没有 default 行\n', ['--all', '--root', makeRepo('ns-nodefault', { 'OkProj.dpr': OK_DPR })]), 2,
  ['命名空间声明没有 default 行']);
expectExit('命名空间负样本㉑多行 default', runWithNamespace(`${NS_DEFAULT_LINE}\n${NS_DEFAULT_LINE}\n`, ['--all', '--root', makeRepo('ns-two-default', { 'OkProj.dpr': OK_DPR })]), 2,
  ['命名空间声明有多行 default']);
expectExit('命名空间负样本㉒行缺 =', runWithNamespace(`${NS_DEFAULT_LINE}\nVcl.Samples\n`, ['--all', '--root', makeRepo('ns-noeq', { 'OkProj.dpr': OK_DPR })]), 2,
  ["命名空间声明行缺 '='"]);
expectExit('命名空间负样本㉓等号后为空', runWithNamespace(`${NS_DEFAULT_LINE}\nNsDemo.dpr=\n`, ['--all', '--root', makeRepo('ns-emptyval', { 'OkProj.dpr': OK_DPR })]), 2,
  ['命名空间声明等号后为空']);

// ㉔声明未被判定面命中：路径拼错或工程已删。静默失效的声明比没有声明更糟（它给人「已经处理过」的错觉），红。
expectExit('命名空间负样本㉔声明未被判定面命中', runWithNamespace(`${NS_DEFAULT_LINE}\nGhost.dpr=Datasnap\n`, ['--all', '--root', makeRepo('ns-unused', { 'OkProj.dpr': OK_DPR })]), 2,
  ['命名空间声明未被本轮判定面命中', 'ghost.dpr']);

// ㉕功能负对照：只给 default（= 外置前的那份缺省集）时，DBClient 仍编不过。
// 这条证的是「外置没有顺手放宽默认集合」——缺了它，判定面变绿就无法区分「换了来源」与「偷偷扩了面」。
{
  const root = makeRepo('ns-tight', { 'NsDemo.dpr': NS_DEMO_DPR });
  const res = runWithNamespace(NS_DEFAULT_LINE + '\n', ['--dpr', 'NsDemo.dpr', '--root', root]);
  expectExit('命名空间负样本㉕默认集合未放宽', res, 1, ["F2613 Unit 'DBClient' not found"]);
  if (/StrUtils/.test(res.out)) bug('命名空间负样本㉕：StrUtils 也报找不到 —— 缺省集被裁减了，声明成了缩面手段');
}

// ㉖功能正对照：给 NsDemo.dpr 补一行 Datasnap 声明后编过，且 StrUtils（靠缺省集里的 System 解析）依旧解析得到。
// 一条用例同时证两件事：声明真进了 -NS；合并是并集而非替换。
{
  const root = makeRepo('ns-wide', { 'NsDemo.dpr': NS_DEMO_DPR });
  expectExit('命名空间正对照㉖工程级声明生效且缺省集未被顶掉', runWithNamespace(`${NS_DEFAULT_LINE}\nNsDemo.dpr=Datasnap\n`, ['--dpr', 'NsDemo.dpr', '--root', root]), 0,
    ['NsDemo.dpr', 'BUILD_EXIT=0']);
}

// ㉗没有「传命名空间」的入口：清单只能改文件、走 review，不能在一次运行里临时塞进去
{
  const root = makeRepo('ns-noknob', { 'OkProj.dpr': OK_DPR });
  expectExit('命名空间负样本㉗命令行不接受命名空间参数', runGate(['--all', '--ns', 'Datasnap', '--root', root]), 3, ['为未知参数']);
}

// ㉘枚举面目录名集走共享真相源（WO-20260924-AUDIT-甲-D7 段5 口径）：`Logs` 是本门专属的 CI 产物目录，
// 从调用点实参里删掉它 = 把 CI 产物当源码扫（静默缩面反向变成静默扩面+假红）。
// 配对证据：Logs/ 下的未跟踪 .dpr 不进判定面（下面 0 件），同样形态放在其它目录名下一律红（上面 2 件）——
// 后者证未跟踪检测是活的，前者的「不报」才只可能归因于 SKIP 集里的 Logs，而不是整条检查死了。
{
  const root = makeRepo('skipset', { 'OkProj.dpr': OK_DPR });
  fs.mkdirSync(path.join(root, 'Logs'), { recursive: true });
  fs.mkdirSync(path.join(root, 'BuildOutput'), { recursive: true });
  fs.writeFileSync(path.join(root, 'Logs', 'Ghost.dpr'), OK_DPR, 'utf8');
  fs.writeFileSync(path.join(root, 'BuildOutput', 'Ghost.dpr'), OK_DPR, 'utf8');
  const skip = runGate(['--all', '--root', root]);
  if (skip.code !== 0) bug(`目录名集负样本㉘：Logs/BuildOutput 下的未跟踪 .dpr 被判进判定面（CI 产物冒充源码）=> EXIT=${skip.code}\n${skip.out}`);
  if (/Ghost\.dpr/.test(skip.out)) bug(`目录名集负样本㉘：输出提到 Ghost.dpr，共享口径未生效\n${skip.out}`);
  const ctlRoot = makeRepo('skipset-ctl', { 'OkProj.dpr': OK_DPR });
  fs.mkdirSync(path.join(ctlRoot, 'SomeSourceDir'), { recursive: true });
  fs.writeFileSync(path.join(ctlRoot, 'SomeSourceDir', 'Ghost.dpr'), OK_DPR, 'utf8');
  expectExit('目录名集正对照㉘-ctl：非跳过目录下的未跟踪 .dpr 必红', runGate(['--all', '--root', ctlRoot]), 2,
    ['未跟踪但存在的 .dpr', 'Ghost.dpr']);
  say(`✓ 目录名集负样本㉘共享口径下的 CI 产物不进判定面 => EXIT=${skip.code}（输出不含 Ghost.dpr）`);
}

for (const p of trashFiles) {
  try { fs.rmSync(p, { force: true }); } catch (e) { bug(`临时注入件清理失败 ${p}: ${e.code || e.message}`); }
}
for (const p of trash) {
  try { fs.rmSync(p, { recursive: true, force: true }); } catch (e) { bug(`临时样本清理失败 ${p}: ${e.code || e.message}`); }
}

say(failed ? 'NEGATIVE-TEST: FAIL' : 'NEGATIVE-TEST: PASS');
process.exit(failed ? 1 : 0);
