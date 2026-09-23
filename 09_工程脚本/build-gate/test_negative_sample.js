// 编译门禁负向样本（WO-20260923-AUDIT-甲-D3 §2.4）
//
// 这道门的价值全在「红得可信」上：S-3 的根因不是没人编译，而是没有任何机械判定，
// 所以负向样本必须证明三件事——
//   1) 输入面不可信时不放行（不存在根 / 空扫描 / 索引与磁盘不一致 / 部分扫描）；
//   2) 代码真在编译（语法错误的 .dpr 必须被 dcc64 拦下，而不是只做文件枚举就报绿）；
//   3) 判定不恒真（合法 .dpr 必须能过，否则「红」没有信息量）。
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
    'require(process.env.BG_GATE);',
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

for (const p of trashFiles) {
  try { fs.rmSync(p, { force: true }); } catch (e) { bug(`临时注入件清理失败 ${p}: ${e.code || e.message}`); }
}
for (const p of trash) {
  try { fs.rmSync(p, { recursive: true, force: true }); } catch (e) { bug(`临时样本清理失败 ${p}: ${e.code || e.message}`); }
}

say(failed ? 'NEGATIVE-TEST: FAIL' : 'NEGATIVE-TEST: PASS');
process.exit(failed ? 1 : 0);
