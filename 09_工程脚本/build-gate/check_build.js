// DeepBase 全库 .dpr 编译门禁（WO-20260923-AUDIT-甲-D3）
//
// 为什么必须有这道门、判定口径（隔离 --detach 工作树 @ 目标 commit）、两种模式的适用场景、
// 环境真相源与 .res/DCU 两个环境坑：见 README-编译门禁.md（本目录），此处不复述。
//
// 参数解析复用 09_工程脚本/gate-args.js，本文件不写第二套 arg()：
// 打回过的根因正是「校验侧接受、取值侧不认」⇒ 静默回落默认根，扫错目录还报绿。
'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { parseGateArgs } = require('../gate-args.js');

const HERE = __dirname;
const REPO_ROOT = path.resolve(HERE, '..', '..');

// 与编码/行尾门禁同一套跳过名单：这些目录里的 .dpr 是构建产物、工具缓存或第三方镜像，不是本仓工程真相源。
const SKIP = new Set(['.git', '.claude', '__history', 'BuildOutput', 'DCUOutput', 'bin', 'dcu', 'node_modules', '.tmp', '.superpowers', '.workbuddy', 'TestResults', 'Logs']);
// 源目录（BUG-285：dcc64 即使指定 -N0，也可能把早期依赖的 DCU 落进源目录，跑完须清掉【本次新产生】的那些）。
const SOURCE_DIRS = ['Core', 'Features', 'Persistence', 'VCL', 'FMX', 'Governance', 'Tests', 'Tools', 'Examples', 'DeepFlow', 'DeepBaseRun', 'doQry', 'ThirdParty'];
// 无 .dproj 工程的缺省单元面：与 Scripts/run_tests.ps1 的 $UnitPaths 同构（相对 root 解析，故隔离工作树同样可用）。
const UNIT_DIRS = ['Core', 'Features', 'Persistence', 'VCL', 'FMX', 'Governance', 'ThirdParty/Payment', 'ThirdParty/Social', 'Tools/CLI', 'Tools/WebService', 'Tests', 'Tests/Regression', 'Tests/Integration'];
// 无 .dproj 工程的缺省命名空间：与 Scripts/compile_packages_win64.ps1 的 $NS 同构。
const DEFAULT_NS = 'System;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Shell;Data;FireDAC;FireDAC.Comp;FireDAC.DApt;FireDAC.Stan;Xml;Web;Soap;Winapi;System.Win';
const DUNITX_SOURCE = process.env.DEEPBASE_DUNITX_SOURCE || 'D:\\ProgramData\\delphi\\DUnitX\\Source';
const FALLBACK_BDS = 'D:\\Program Files (x86)\\Embarcadero\\Studio\\37.0';

// 退出码：0=通过 / 1=有 .dpr 编译失败 / 2=枚举或输入面不可信（readdir 失败、计数为 0、清单与索引不一致、找不到编译器）/ 3=参数不合法
const EXIT_OK = 0, EXIT_BUILD_FAILED = 1, EXIT_SCAN_FAILED = 2, EXIT_BAD_ARGS = 3;

function usage() {
  console.log([
    '编译门禁 用法: node check_build.js (--all | --dpr <path> [--dpr <path> ...]) [--root <dir>] [--help]',
    '',
    '  两种模式的适用场景、实测耗时与判定口径见 README-编译门禁.md（本目录）。',
    '',
    '  必须显式给出 --all 或 --dpr，否则 EXIT=3；本门禁 fail-closed，不提供「跳过并继续报绿」的任何形态。',
    '',
    'EXIT: 0=通过 1=有 .dpr 编译失败 2=枚举/输入面不可信 3=参数不合法',
  ].join('\n'));
}

function failScan(msg) {
  console.error('编译门禁失败(fail-closed)：' + msg);
  process.exit(EXIT_SCAN_FAILED);
}

function main() {
  const opts = parseGateArgs(process.argv.slice(2), {
    label: '编译',
    root: REPO_ROOT,
    extra: ['all'],
    valued: ['dpr'],
  });
  if (opts.flags.has('help')) { usage(); process.exit(EXIT_OK); }

  const root = opts.root;
  if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) {
    failScan(`--root 不是存在的目录：${root}`);
  }

  const targets = collectTargets(root, opts);
  if (targets.length === 0) failScan(`待编译 .dpr 计数为 0（空扫描不是通过）：root=${root}`);

  const tools = resolveToolchain();
  if (!tools.dcc64) failScan(`找不到 dcc64.exe（设 PATH 或环境变量 DCC64；缺省回退 ${FALLBACK_BDS}\\bin\\dcc64.exe）`);

  const outRoot = path.join(root, '.tmp', 'build-gate');
  const env = buildDefaultEnv(root, tools.bds);
  let resGenerated = 0;

  let ok = 0, failed = 0;
  const failures = [];
  targets.forEach((rel, i) => {
    const ctx = projectEnv(root, rel, env);
    const res = compileOne(tools, root, rel, ctx, outRoot);
    console.log(`[${i + 1}/${targets.length}] ${rel} CONFIG=${ctx.configTag} BUILD_EXIT=${res.exit}`);
    if (res.resGenerated) resGenerated++;
    if (res.exit === 0) { ok++; return; }
    failed++;
    failures.push({ rel, exit: res.exit, firstError: res.firstError, killed: res.killed });
    console.error(`  ${rel} 编译失败：${res.firstError || '(无错误行，EXIT=' + res.exit + ')'}`);
    for (const w of ctx.warnings) console.error('  ' + w);
  });

  const staleRemoved = cleanSourceDcus(root, env.snapshotBefore);
  const skipped = targets.length - ok - failed; // 恒为 0：本门禁不允许任何「跳过并继续」的形态，保留数字让「=0」成为可核事实

  console.log(`编译门禁统计：DPR总数=${targets.length} 成功=${ok} 失败=${failed} 被跳过=${skipped} 失败子路径=${env.scanFailures} .res生成=${resGenerated} 编译器=${path.basename(tools.dcc64)} 陈旧DCU清理=${staleRemoved}`);
  if (failed > 0) {
    console.error('编译门禁失败：' + failed + ' 个 .dpr 编译不过');
    for (const f of failures) console.error(`  ${f.rel} EXIT=${f.exit}${f.killed ? ' (超时被终止)' : ''}  ${f.firstError}`);
    process.exit(EXIT_BUILD_FAILED);
  }
  console.log('编译门禁通过：' + targets.length + ' 个 .dpr 全部 BUILD_EXIT=0（判定应来自隔离 --detach 工作树 @ 目标 commit）');
  process.exit(EXIT_OK);
}

// ---- 目标清单：git 索引 ∩ 磁盘实扫，两侧必须一致，多一个少一个都是红 ----
function collectTargets(root, opts) {
  const gitRel = gitTrackedDprs(root);
  const { diskRel, readdirFailures } = walkDprs(root);

  for (const d of readdirFailures) console.error('  readdir 失败：' + d);
  if (readdirFailures.length > 0) {
    failScan(`readdir 失败子路径 ${readdirFailures.length} 个（部分扫描不得报绿）`);
  }

  const gitSet = new Set(gitRel), diskSet = new Set(diskRel);
  const onlyGit = gitRel.filter(p => !diskSet.has(p));
  const onlyDisk = diskRel.filter(p => !gitSet.has(p));
  if (onlyGit.length > 0) {
    failScan(`git 索引里有、工作树里却没有的 .dpr 共 ${onlyGit.length} 个：\n  ${onlyGit.join('\n  ')}`);
  }
  if (onlyDisk.length > 0) {
    failScan(`未跟踪但存在的 .dpr 共 ${onlyDisk.length} 个（绕开了编译判定，先 git add 或删除）：\n  ${onlyDisk.join('\n  ')}`);
  }

  if (!opts.flags.has('all') && opts.values.size === 0) {
    console.error('编译门禁失败：未指定编译范围。请给 --all（全量）或 --dpr <path>（单个/多个）。已按 fail-closed 拒绝放行。');
    process.exit(EXIT_BAD_ARGS);
  }
  if (opts.flags.has('all') && opts.values.size > 0) {
    console.error('编译门禁失败：--all 与 --dpr 互斥（前者声明全量，后者声明子集，同时给无法确定判定覆盖的是哪个面）。');
    process.exit(EXIT_BAD_ARGS);
  }

  if (opts.flags.has('all')) return gitRel;

  const wanted = (opts.values.get('dpr') || []).map(v => {
    const abs = path.resolve(root, v);
    const rel = path.relative(root, abs).split(path.sep).join('/');
    if (rel === '' || rel.startsWith('..') || path.isAbsolute(rel)) {
      failScan(`--dpr 落在 --root 之外：${v}（root=${root}）`);
    }
    if (!gitSet.has(rel)) {
      failScan(`--dpr 不是本仓已跟踪的 .dpr：${rel}（拼错的根/路径不会静默缩小扫描面，直接红）`);
    }
    return rel;
  });
  return [...new Set(wanted)];
}

function gitTrackedDprs(root) {
  const r = spawnSync('git', ['-c', 'core.quotePath=false', 'ls-files', '-z', '--', '*.dpr'], { cwd: root, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  if (r.status !== 0) {
    failScan(`git ls-files 失败（EXIT=${r.status}）：${(r.stderr || r.error?.message || '').trim()}`);
  }
  return r.stdout.split('\0').filter(Boolean).sort();
}

function walkDprs(root) {
  const diskRel = [], readdirFailures = [];
  const stack = [root];
  while (stack.length) {
    const dir = stack.pop();
    let entries;
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch (e) {
      readdirFailures.push(`${dir} (${e.code || e.message})`);
      continue;
    }
    for (const e of entries) {
      const abs = path.join(dir, e.name);
      if (e.isDirectory()) {
        if (SKIP.has(e.name)) continue;
        stack.push(abs);
      } else if (e.isFile() && e.name.toLowerCase().endsWith('.dpr')) {
        diskRel.push(path.relative(root, abs).split(path.sep).join('/'));
      }
    }
  }
  return { diskRel: diskRel.sort(), readdirFailures };
}

// ---- 编译环境：缺省面（仓内构建脚本同构）+ 每个工程 .dproj 自己的面 ----
function resolveToolchain() {
  let dcc64 = null;
  if (process.env.DCC64 && fs.existsSync(process.env.DCC64)) dcc64 = process.env.DCC64;
  if (!dcc64) {
    const where = spawnSync('where.exe', ['dcc64'], { encoding: 'utf8' });
    if (where.status === 0) dcc64 = where.stdout.split(/\r?\n/).find(Boolean) || null;
  }
  if (!dcc64) {
    const fb = path.join(FALLBACK_BDS, 'bin', 'dcc64.exe');
    if (fs.existsSync(fb)) dcc64 = fb;
  }
  const bds = dcc64 ? path.resolve(path.dirname(dcc64), '..') : FALLBACK_BDS;
  let brcc32 = path.join(bds, 'bin', 'brcc32.exe');
  if (!fs.existsSync(brcc32)) {
    const where = spawnSync('where.exe', ['brcc32'], { encoding: 'utf8' });
    brcc32 = where.status === 0 ? (where.stdout.split(/\r?\n/).find(Boolean) || '') : '';
  }
  return { dcc64, bds, brcc32 };
}

function buildDefaultEnv(root, bds) {
  const dirs = UNIT_DIRS.map(d => path.resolve(root, d));
  // 与 compile_packages_win64.ps1 的 $LibPaths 同构：RTL/VCL 的 .dcu 在这里，缺了它们会把好工程误判成 F2613。
  dirs.push(path.join(bds, 'lib', 'Win64', 'release'), path.join(bds, 'lib', 'Win64', 'debug'), DUNITX_SOURCE);
  return {
    root,
    bds,
    searchPaths: dirs.join(';'),
    ns: DEFAULT_NS,
    scanFailures: 0,
    snapshotBefore: snapshotSourceDcus(root),
  };
}

// 从工程自己的 .dproj 取 DCC_UnitSearchPath / DCC_Namespace（全部配置取并集）：
// 取并集是为了让红只可能来自代码，而不是「门禁恰好挑了一个没配路径的配置」这种假红。
function projectEnv(root, rel, env) {
  const projDir = path.dirname(path.join(root, rel));
  const name = path.basename(rel, path.extname(rel));
  const dproj = path.join(projDir, name + '.dproj');
  const warnings = [];
  if (!fs.existsSync(dproj)) {
    return { configTag: 'default', cwd: projDir, searchPaths: env.searchPaths, ns: env.ns, warnings, name, projDir };
  }
  const xml = fs.readFileSync(dproj, 'utf8');
  const dirs = new Set();
  const namespaces = new Set();
  for (const m of xml.matchAll(/<DCC_UnitSearchPath>([\s\S]*?)<\/DCC_UnitSearchPath>/g)) {
    for (const raw of decodeXml(m[1]).split(';')) {
      const e = raw.trim();
      if (!e || /^\$\(DCC_UnitSearchPath\)$/i.test(e)) continue;
      if (e.includes('$(') && !/\$\((BDS|CDIR|SourceDir|OutputDir)\)/i.test(e)) {
        warnings.push(`  未展开的搜索路径变量（该工程的第三方依赖未随仓提供，按原样跳过）：${e}`);
        continue;
      }
      const expanded = e.replace(/\$\(BDS\)/gi, env.bds).replace(/\$\(CDIR\)|\$\(SourceDir\)/gi, projDir);
      dirs.add(path.resolve(projDir, expanded.replace(/\\/g, path.sep)));
    }
  }
  for (const m of xml.matchAll(/<DCC_Namespace>([\s\S]*?)<\/DCC_Namespace>/g)) {
    for (const raw of decodeXml(m[1]).split(';')) {
      const e = raw.trim();
      if (e && !/^\$\(DCC_Namespace\)$/i.test(e)) namespaces.add(e);
    }
  }
  return {
    configTag: name + '.dproj',
    cwd: projDir,
    searchPaths: [...dirs, env.searchPaths].join(';'),
    ns: namespaces.size ? [...namespaces].join(';') : env.ns,
    warnings,
    name,
    projDir,
  };
}

function decodeXml(s) {
  return s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&#(\d+);/g, (_, c) => String.fromCharCode(Number(c))).replace(/&amp;/g, '&');
}

// ---- 单文件编译 ----
function compileOne(tools, root, rel, ctx, outRoot) {
  // dcc64 不会自己建嵌套输出目录（F2039 Could not create output file），每个 .dpr 的子目录先建出来。
  const sub = rel.split('/').slice(0, -1).join('_') || '_';
  const dcuOut = path.join(outRoot, 'dcu', sub);
  const exeOut = path.join(outRoot, 'exe', sub);
  fs.mkdirSync(dcuOut, { recursive: true });
  fs.mkdirSync(exeOut, { recursive: true });

  const dprSrc = fs.readFileSync(path.join(root, rel), 'utf8');
  const resGenerated = ensureProjectRes(tools, dprSrc, ctx, outRoot);

  const args = [
    '-Q', '-B', '-DDEBUG',
    '-U' + ctx.searchPaths,
    '-NS' + ctx.ns,
    '-N0' + dcuOut,
    '-E' + exeOut,
    path.join(root, rel),
  ];
  const r = spawnSync(tools.dcc64, args, {
    cwd: ctx.cwd,
    encoding: 'utf8',
    maxBuffer: 32 * 1024 * 1024,
    timeout: 10 * 60 * 1000,
  });
  const out = (r.stdout || '') + (r.stderr || '');
  const firstError = firstErrorLine(out) || (r.error ? 'spawn 失败: ' + r.error.message : '');
  return { exit: r.status === null ? (r.signal ? 124 : 1) : r.status, firstError, killed: !!r.signal, resGenerated };
}

// `{$R *.res}` 引用的 .res 是 IDE 生成物且被 .gitignore 排除，干净检出里必然不存在。
// 不补它就会把「代码没问题」的工程报成 E1026 假红，所以按 IDE 的行为补一个空资源件（落在 .gitignore 内，不脏工作树）。
function ensureProjectRes(tools, dprSrc, ctx, outRoot) {
  const m = dprSrc.match(/\{\$R\s+([^}\s]+)\}/i);
  if (!m || !/\.res$/i.test(m[1])) return false;
  const fileName = m[1] === '*' ? ctx.name + '.res' : m[1].replace(/^\*\./, ctx.name + '.');
  const target = path.join(ctx.projDir, fileName);
  if (fs.existsSync(target)) return false;
  if (!tools.brcc32) {
    ctx.warnings.push('  缺 brcc32.exe：无法补生成 ' + fileName + '（E1026 属环境缺失，非代码断裂）');
    return false;
  }
  const scratch = path.join(outRoot, 'res');
  fs.mkdirSync(scratch, { recursive: true });
  const rc = path.join(scratch, ctx.name + '.rc');
  fs.writeFileSync(rc, '// 门禁补生成的空资源件（等价于 IDE 新建工程时的 <project>.res 占位）\r\n', 'utf8');
  const r = spawnSync(tools.brcc32, ['-fo' + target, rc], { cwd: scratch, encoding: 'utf8' });
  if (r.status !== 0 || !fs.existsSync(target)) {
    ctx.warnings.push('  brcc32 生成 ' + fileName + ' 失败 EXIT=' + r.status + '：' + ((r.stdout || '') + (r.stderr || '')).trim().split(/\r?\n/).filter(Boolean).pop());
    return false;
  }
  return true;
}

function firstErrorLine(out) {
  for (const line of out.split(/\r?\n/)) {
    if (/(?:^|\s)(?:Fatal|Error):/.test(line)) return line.trim();
  }
  return '';
}

// ---- BUG-285：只清【本次编译新落进源目录】的 .dcu，已存在的（含被跟踪的）一律不动 ----
function snapshotSourceDcus(root) {
  const seen = new Set();
  for (const d of SOURCE_DIRS) collect(path.join(root, d), '.dcu', seen);
  return seen;
}

function collect(dir, ext, acc) {
  let entries;
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
  for (const e of entries) {
    const abs = path.join(dir, e.name);
    if (e.isDirectory()) { if (!SKIP.has(e.name)) collect(abs, ext, acc); }
    else if (e.name.toLowerCase().endsWith(ext)) acc.add(abs);
  }
}

function cleanSourceDcus(root, before) {
  const now = new Set();
  for (const d of SOURCE_DIRS) collect(path.join(root, d), '.dcu', now);
  let n = 0;
  for (const f of now) {
    if (before.has(f)) continue;
    try { fs.unlinkSync(f); n++; } catch { /* 删不掉不影响判定，已在计数中体现 */ }
  }
  return n;
}

main();
