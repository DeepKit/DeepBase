// DeepBase 全库工程编译门禁（WO-20260923-AUDIT-甲-D3 建 .dpr 面；WO-20260923-AUDIT-甲-D4 补 .dpk 包工程面）
//
// 为什么必须有这道门、判定口径（隔离 --detach 工作树 @ 目标 commit）、两种模式的适用场景、
// 环境真相源与 .res/DCU 两个环境坑：见 README-编译门禁.md（本目录），此处不复述。
//
// 参数解析复用 09_工程脚本/gate-args.js，本文件不写第二套 arg()：
// 打回过的根因正是「校验侧接受、取值侧不认」⇒ 静默回落默认根，扫错目录还报绿。
//
// 契约分层（T0 生产面 / T1 观测面 / T2 待定面）由 contracts/ 下的外部声明文件决定，本文件里
// 不写任何路径白名单，也不存在「范围内跳过某个工程」的形态：门禁只认它将要编译的清单，
// 清单内每一个都判，红就红。范围划在哪是治理决定，范围内跳过谁是门禁 bypass —— 后者禁止。
'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { parseGateArgs } = require('../gate-args.js');
const { gateSkipSet } = require('../gate-skip.js');

const HERE = __dirname;
const REPO_ROOT = path.resolve(HERE, '..', '..');

// 两个工程面：.dpr = 可执行程序，.dpk = 包（本仓的生产交付形态，BPL）。两面的枚举与判定完全同构。
const FACES = [
  { key: 'dpr', pattern: '*.dpr', ext: '.dpr', label: '.dpr' },
  { key: 'dpk', pattern: '*.dpk', ext: '.dpk', label: '.dpk' },
];
// 清单文件里的整面选择子：写 all-dpk 而不是抄 25 条路径，新增包自动进面，杜绝「清单漏更新」这种静默缩面。
const FACE_SELECTOR = new Map(FACES.map(f => [`all-${f.key}`, f]));

// 与其余四道门共用 gate-skip 的目录名集（`Logs` 是本门专属：dcc64 的编译日志落处）。
// 这是「枚举面」的定义，不是「范围内放行谁」——判定面内每一个工程都编、都判，红就红。
const BUILD_ARTIFACT_DIRS = gateSkipSet('Logs');
// 源目录（BUG-285：dcc64 即使指定 -N0，也可能把早期依赖的 DCU 落进源目录，跑完须清掉【本次新产生】的那些）。
const SOURCE_DIRS = ['Core', 'Features', 'Persistence', 'VCL', 'FMX', 'Governance', 'Tests', 'Tools', 'Examples', 'DeepFlow', 'DeepBaseRun', 'doQry', 'ThirdParty'];
// 无 .dproj 工程的缺省单元面：与 Scripts/run_tests.ps1 的 $UnitPaths 同构（相对 root 解析，故隔离工作树同样可用）。
const UNIT_DIRS = ['Core', 'Features', 'Persistence', 'VCL', 'FMX', 'Governance', 'ThirdParty/Payment', 'ThirdParty/Social', 'Tools/CLI', 'Tools/WebService', 'Tests', 'Tests/Regression', 'Tests/Integration'];
// 无 .dproj 工程的缺省命名空间：与 Scripts/compile_packages_win64.ps1 的 $NS 同构。
const DEFAULT_NS = 'System;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Shell;Data;FireDAC;FireDAC.Comp;FireDAC.DApt;FireDAC.Stan;Xml;Web;Soap;Winapi;System.Win';
const DUNITX_SOURCE = process.env.DEEPBASE_DUNITX_SOURCE || 'D:\\ProgramData\\delphi\\DUnitX\\Source';
const FALLBACK_BDS = 'D:\\Program Files (x86)\\Embarcadero\\Studio\\37.0';

// 退出码：0=通过 / 1=有工程编译失败 / 2=枚举或输入面不可信（readdir 失败、计数为 0、清单与索引不一致、
//         包依赖成环、找不到编译器、清单文件读不到或为空）/ 3=参数不合法
const EXIT_OK = 0, EXIT_BUILD_FAILED = 1, EXIT_SCAN_FAILED = 2, EXIT_BAD_ARGS = 3;

function usage() {
  console.log([
    '编译门禁 用法: node check_build.js (--all | --dpr <path>... | --dpk <path>... | --manifest <file>...) [--root <dir>] [--help]',
    '',
    '  两种模式的适用场景、实测耗时与判定口径见 README-编译门禁.md（本目录）。',
    '',
    '  --all       判定面 = git 已跟踪的全部 .dpr + 全部 .dpk（无例外）。',
    '  --dpr/--dpk 显式点名工程（可重复）；--manifest 读外部契约清单（可重复，取并集）。',
    '              清单每行一个仓内相对路径，或整面选择子 all-dpr / all-dpk；# 起注释。',
    '  三种范围声明互斥且必须给一种；本门禁 fail-closed，不提供「跳过并继续报绿」的任何形态。',
    '',
    'EXIT: 0=通过 1=有工程编译失败 2=枚举/输入面不可信 3=参数不合法',
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
    valued: ['dpr', 'dpk', 'manifest'],
  });
  if (opts.flags.has('help')) { usage(); process.exit(EXIT_OK); }

  const root = opts.root;
  if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) {
    failScan(`--root 不是存在的目录：${root}`);
  }

  // 判定面前置：--all 与 --dpr/--dpk/--manifest 互斥（同时给无法确定判定覆盖的是哪个面）。
  const declared = collectTargets(root, opts);

  const tools = resolveToolchain();
  if (!tools.dcc64) failScan(`找不到 dcc64.exe（设 PATH 或环境变量 DCC64；缺省回退 ${FALLBACK_BDS}\\bin\\dcc64.exe）`);

  const outRoot = path.join(root, '.tmp', 'build-gate');
  // 每次跑先清空包输出面：残留 .dcp 会让「本轮没重建的依赖」被当成已解析，掩盖真实断裂。
  for (const sub of ['dcp', 'bpl']) fs.rmSync(path.join(outRoot, sub), { recursive: true, force: true });
  const env = buildDefaultEnv(root, tools.bds, outRoot);

  const stats = new Map(FACES.map(f => [f.key, faceStat(f)]));
  let resGenerated = 0;
  const failures = [];

  for (const face of FACES) {
    const targets = declared[face.key];
    const st = stats.get(face.key);
    st.total = targets.length;
    targets.forEach((rel, i) => {
      const ctx = projectEnv(root, rel, env, face);
      const res = compileOne(tools, root, rel, ctx, face, outRoot);
      console.log(`[${face.key} ${i + 1}/${targets.length}] ${rel} CONFIG=${ctx.configTag} BUILD_EXIT=${res.exit}`);
      if (res.resGenerated) resGenerated++;
      if (res.exit === 0) { st.ok++; return; }
      st.failed++;
      st.items.push({ rel, exit: res.exit, firstError: res.firstError, killed: res.killed });
      console.error(`  ${rel} 编译失败：${res.firstError || '(无错误行，EXIT=' + res.exit + ')'}`);
      for (const w of ctx.warnings) console.error('  ' + w);
    });
  }

  const staleRemoved = cleanSourceDcus(root, env.snapshotBefore);
  const trackedTotal = declared.trackedTotal;
  const judgedTotal = FACES.reduce((n, f) => n + stats.get(f.key).total, 0);

  for (const face of FACES) {
    const st = stats.get(face.key);
    // 被跳过 = 总数 - 成功 - 失败：恒为 0，本门禁不允许任何「跳过并继续」的形态，保留数字让「=0」成为可核事实。
    console.log(`编译门禁统计：${face.key.toUpperCase()}总数=${st.total} 成功=${st.ok} 失败=${st.failed} 被跳过=${st.total - st.ok - st.failed} 失败子路径=${env.scanFailures}`);
  }
  console.log(`编译门禁统计：判定面=${judgedTotal} 已跟踪=${trackedTotal} 清单来源=${declared.source} .res生成=${resGenerated} 编译器=${path.basename(tools.dcc64)} 陈旧DCU清理=${staleRemoved}`);

  const failed = FACES.reduce((n, f) => n + stats.get(f.key).failed, 0);
  if (failed > 0) {
    console.error('编译门禁失败：' + failed + ' 个工程编译不过');
    for (const face of FACES) for (const x of stats.get(face.key).items) {
      console.error(`  ${x.rel} EXIT=${x.exit}${x.killed ? ' (超时被终止)' : ''}  ${x.firstError}`);
    }
    process.exit(EXIT_BUILD_FAILED);
  }
  console.log(`编译门禁通过：${judgedTotal} 个工程全部 BUILD_EXIT=0（判定应来自隔离 --detach 工作树 @ 目标 commit）`);
  process.exit(EXIT_OK);
}

function faceStat(face) { return { key: face.key, total: 0, ok: 0, failed: 0, items: [] }; }

// ---- 目标清单：git 索引 ∩ 磁盘实扫，两面各自成立；多一个少一个都是红 ----
function collectTargets(root, opts) {
  const tracked = { dpr: [], dpk: [] };
  const scanned = { dpr: [], dpk: [] };
  const readdirFailures = [];
  for (const face of FACES) tracked[face.key] = gitTracked(root, face);
  walkProjects(root, scanned, readdirFailures);
  const totalTracked = tracked.dpr.length + tracked.dpk.length;

  for (const d of readdirFailures) console.error('  readdir 失败：' + d);
  if (readdirFailures.length > 0) {
    failScan(`readdir 失败子路径 ${readdirFailures.length} 个（部分扫描不得报绿）`);
  }

  for (const face of FACES) {
    const gitSet = new Set(tracked[face.key]), diskSet = new Set(scanned[face.key]);
    const onlyGit = tracked[face.key].filter(p => !diskSet.has(p));
    const onlyDisk = scanned[face.key].filter(p => !gitSet.has(p));
    if (onlyGit.length > 0) {
      failScan(`git 索引里有、工作树里却没有的 ${face.label} 共 ${onlyGit.length} 个：\n  ${onlyGit.join('\n  ')}`);
    }
    if (onlyDisk.length > 0) {
      failScan(`未跟踪但存在的 ${face.label} 共 ${onlyDisk.length} 个（绕开了编译判定，先 git add 或删除）：\n  ${onlyDisk.join('\n  ')}`);
    }
  }

  // --all 的 fail-closed：整个扫描面为空＝枚举坏了，不是「全都通过」。单面为 0 由统计行如实打印（DPK总数=0）。
  if (opts.flags.has('all') && totalTracked === 0) {
    failScan(`待编译 .dpr 计数为 0（.dpk 同为 0；空扫描不是通过）：root=${root}`);
  }
  const picked = pickScope(root, opts, tracked);
  const judged = picked.dpr.length + picked.dpk.length;
  if (judged === 0) failScan(`判定面为空（清单/点名解析后一个工程都没有）：source=${picked.source}`);
  if (picked.dpk.length) picked.dpk = orderByRequires(root, picked.dpk, tracked.dpk);
  return { ...picked, trackedTotal: totalTracked };
}

// 范围声明：--all（全量）/ --dpr+--dpk（点名）/ --manifest（外部契约清单）。三者互斥，必须给一种。
function pickScope(root, opts, tracked) {
  const named = [...(opts.values.get('dpr') || []), ...(opts.values.get('dpk') || []), ...(opts.values.get('manifest') || [])];
  if (opts.flags.has('all') && named.length > 0) {
    scopeError('--all 与 --dpr 互斥（--all 声明全量面，--dpr/--dpk/--manifest 声明子集，同时给无法确定判定覆盖的是哪个面）');
  }
  if (opts.flags.has('all')) {
    return { source: 'all', dpr: tracked.dpr, dpk: tracked.dpk };
  }
  if (!named.length) {
    scopeError('未指定编译范围。请给 --all（全量）、--dpr/--dpk <path>（点名）或 --manifest <file>（外部契约清单）。已按 fail-closed 拒绝放行。');
  }
  const set = new Set();
  const sources = [];
  for (const face of FACES) {
    for (const v of opts.values.get(face.key) || []) set.add(resolveProject(root, v, tracked, `--${face.key}`, face));
  }
  for (const v of opts.values.get('manifest') || []) {
    const abs = path.resolve(root, v);
    sources.push(path.basename(abs));
    for (const rel of readManifest(root, abs, tracked)) set.add(rel);
  }
  const list = [...set];
  return {
    source: sources.length ? 'manifest:' + [...new Set(sources)].join('+') : 'named',
    dpr: list.filter(p => p.toLowerCase().endsWith('.dpr')),
    dpk: list.filter(p => p.toLowerCase().endsWith('.dpk')),
  };
}

function scopeError(msg) {
  console.error('编译门禁失败：' + msg);
  process.exit(EXIT_BAD_ARGS);
}

// 点名的工程必须是本仓已跟踪的、且扩展名与所给参数一致：拼错的路径不会静默缩小扫描面，直接红。
// face 参数为显式点名时限定扩展名（--dpk 不接受 .dpr），清单里靠扩展名自己归面，故传 null。
function resolveProject(root, v, tracked, origin, face) {
  const abs = path.resolve(root, v);
  const rel = path.relative(root, abs).split(path.sep).join('/');
  if (rel === '' || rel.startsWith('..') || path.isAbsolute(rel)) {
    failScan(`${origin} 落在 --root 之外：${v}（root=${root}）`);
  }
  const got = FACES.find(f => rel.toLowerCase().endsWith(f.ext));
  if (!got) failScan(`${origin} 只接受 .dpr 或 .dpk 工程文件：${rel}`);
  if (face && got !== face) failScan(`${origin} 要的是 ${face.label}，给的是 ${got.label}：${rel}`);
  if (!tracked[got.key].includes(rel)) {
    failScan(`${origin} 不是本仓已跟踪的 ${got.label}：${rel}（拼错的根/路径不会静默缩小扫描面，直接红）`);
  }
  return rel;
}

// 外部契约清单：每行一个仓内相对路径或整面选择子（all-dpr / all-dpk），# 起注释，空行忽略。
// 读不到 / 零条目 / 条目不在索引里，一律 EXIT=2 —— 「清单写错」绝不能变成「少编译几个还报绿」。
function readManifest(root, abs, tracked) {
  let txt;
  try {
    txt = fs.readFileSync(abs, 'utf8');
  } catch (e) {
    failScan(`--manifest 读不到：${abs}（${e.code || e.message}）`);
  }
  const out = [];
  for (const raw of txt.split(/\r?\n/)) {
    const line = raw.replace(/#.*$/, '').trim();
    if (!line) continue;
    const face = FACE_SELECTOR.get(line.toLowerCase());
    if (face) {
      // 整面声明落空同样红：清单说「判定全部 ${face.label}」，而索引里一个都没有，说明枚举/仓库面不可信。
      if (tracked[face.key].length === 0) {
        failScan(`清单声明的整面 ${line} 计数为 0（${face.key.toUpperCase()}总数=0，整面声明落空不是「那一面全过」）：${abs}`);
      }
      out.push(...tracked[face.key]);
      continue;
    }
    out.push(resolveProject(root, line, tracked, `--manifest ${path.basename(abs)}`, null));
  }
  if (out.length === 0) failScan(`--manifest 清单为空（0 个工程）：${abs}——空清单不是「全都通过」，直接红`);
  return out;
}

// 包工程的编译顺序：requires 决定谁先编。按全部已跟踪 .dpk 建图取拓扑序，再过滤到判定面，
// 这样子集跑与全量跑得到同一条相对次序；缺依赖不会因「本轮没编」而变成 F2613 假红。
function orderByRequires(root, selected, allDpks) {
  const byName = new Map(allDpks.map(p => [pkgName(root, p).toLowerCase(), p]));
  const deps = new Map();
  for (const rel of allDpks) {
    const names = new Set(requiresOf(root, rel).map(d => byName.get(d)).filter(d => d && d !== rel));
    names.delete(rel);
    deps.set(rel, [...names]);
  }
  const order = [], done = new Set(), temp = new Set();
  const visit = (node, chain) => {
    if (done.has(node)) return;
    if (temp.has(node)) failScan(`包依赖成环（requires 无法定序）：${[...chain, node].join(' -> ')}`);
    temp.add(node);
    for (const d of deps.get(node) || []) visit(d, [...chain, node]);
    temp.delete(node);
    done.add(node);
    order.push(node);
  };
  for (const rel of allDpks) visit(rel, []);
  const wanted = new Set(selected);
  return order.filter(p => wanted.has(p));
}

function requiresOf(root, rel) {
  let txt;
  try { txt = fs.readFileSync(path.join(root, rel), 'utf8'); } catch { return []; }
  const stripped = txt.replace(/\{[\s\S]*?\}/g, ' ').replace(/\(\*[\s\S]*?\*\)/g, ' ');
  const m = /\brequires\b([\s\S]*?);/i.exec(stripped);
  if (!m) return [];
  return m[1].split(',').map(s => s.replace(/^['"]|['"]$/g, '').replace(/@[\d.]+$/, '').trim().toLowerCase()).filter(Boolean);
}

function gitTracked(root, face) {
  const r = spawnSync('git', ['-c', 'core.quotePath=false', 'ls-files', '-z', '--', face.pattern], { cwd: root, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  if (r.status !== 0) {
    failScan(`git ls-files 失败（EXIT=${r.status}）：${(r.stderr || r.error?.message || '').trim()}`);
  }
  return r.stdout.split('\0').filter(Boolean).sort();
}

function walkProjects(root, acc, readdirFailures) {
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
        if (BUILD_ARTIFACT_DIRS.has(e.name)) continue;
        stack.push(abs);
        continue;
      }
      if (!e.isFile()) continue;
      const lower = e.name.toLowerCase();
      for (const face of FACES) {
        if (lower.endsWith(face.ext)) acc[face.key].push(path.relative(root, abs).split(path.sep).join('/'));
      }
    }
  }
  for (const face of FACES) acc[face.key].sort();
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

function buildDefaultEnv(root, bds, outRoot) {
  const dirs = UNIT_DIRS.map(d => path.resolve(root, d));
  // 与 compile_packages_win64.ps1 的 $LibPaths 同构：RTL/VCL 的 .dcu 在这里，缺了它们会把好工程误判成 F2613。
  dirs.push(path.join(bds, 'lib', 'Win64', 'release'), path.join(bds, 'lib', 'Win64', 'debug'), DUNITX_SOURCE);
  // 本轮包输出面：后面的包 requires 前面的包，dcc64 在单元/对象搜索路径上找 .dcp，缺了就会 F2613 假红。
  dirs.push(path.join(outRoot, 'dcp'));
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
function projectEnv(root, rel, env, face) {
  const projDir = path.dirname(path.join(root, rel));
  const fileBase = path.basename(rel, face.ext);
  const dproj = path.join(projDir, fileBase + '.dproj');
  const warnings = [];
  const base = { cwd: projDir, warnings, projDir, fileBase };
  if (!fs.existsSync(dproj)) {
    return { ...base, name: pkgName(root, rel), configTag: 'default', searchPaths: env.searchPaths, ns: env.ns };
  }
  const xml = fs.readFileSync(dproj, 'utf8');
  const dirs = new Set();
  const namespaces = new Set();
  for (const m of xml.matchAll(/<DCC_UnitSearchPath>([\s\S]*?)<\/DCC_UnitSearchPath>/g)) {
    for (const raw of decodeXml(m[1]).split(';')) {
      const e = raw.trim();
      if (!e || /^\$\(DCC_UnitSearchPath\)$/i.test(e)) continue;
      if (e.includes('$(') && !/\$\((BDS|CDIR|SourceDir|OutputDir)\)/i.test(e)) {
        warnings.push(`  未展开的搜索路径变量（该工程的第三方依赖未随仓提供，变量原样保留）：${e}`);
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
    ...base,
    name: pkgName(root, rel),
    configTag: fileBase + '.dproj',
    searchPaths: [...dirs, env.searchPaths].join(';'),
    ns: namespaces.size ? [...namespaces].join(';') : env.ns,
  };
}

// dcc64 展开 {$R *.res} 时的 `*` 取的是【声明的包名】（.dpk）或工程名（.dpr），两者通常同名不同源：
// dclDeepBaseFMX 之类设计包的 requires 会把资源要成 DeepBaseFMX.res。按声明取，别按文件名猜。
function pkgName(root, rel) {
  const fallback = path.basename(rel, path.extname(rel));
  if (path.extname(rel).toLowerCase() !== '.dpk') return fallback;
  try {
    const m = /\bpackage\s+([A-Za-z_][\w.]*)\s*;/i.exec(fs.readFileSync(path.join(root, rel), 'utf8'));
    if (m) return m[1];
  } catch { /* 读不到就退回文件名，真实红会由编译本身暴露 */ }
  return fallback;
}

function decodeXml(s) {
  return s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&#(\d+);/g, (_, c) => String.fromCharCode(Number(c))).replace(/&amp;/g, '&');
}

// ---- 单文件编译 ----
function compileOne(tools, root, rel, ctx, face, outRoot) {
  // dcc64 不会自己建嵌套输出目录（F2039 Could not create output file），每个工程的子目录先建出来。
  const sub = rel.split('/').slice(0, -1).join('_') || '_';
  const dcuOut = path.join(outRoot, 'dcu', face.key, sub);
  const exeOut = path.join(outRoot, 'exe', sub);
  fs.mkdirSync(dcuOut, { recursive: true });
  fs.mkdirSync(exeOut, { recursive: true });

  const src = fs.readFileSync(path.join(root, rel), 'utf8');
  const resGenerated = ensureProjectRes(tools, src, ctx, outRoot);

  const args = [
    '-Q', '-B', '-DDEBUG',
    '-U' + ctx.searchPaths,
    '-NS' + ctx.ns,
    '-N0' + dcuOut,
  ];
  if (face.key === 'dpk') {
    // 包输出必须重定向：不指定 -LN/-LE 时 dcc64 把 .dcp/.bpl 落在 .dpk 自己的目录里，脏工作树，
    // 而且下一轮会被当成「已解析的依赖」，把真断裂掩成假绿。
    const dcpOut = path.join(outRoot, 'dcp'), bplOut = path.join(outRoot, 'bpl');
    fs.mkdirSync(dcpOut, { recursive: true });
    fs.mkdirSync(bplOut, { recursive: true });
    args.push('-O' + ctx.searchPaths, '-LN' + dcpOut, '-LE' + bplOut);
  } else {
    args.push('-E' + exeOut);
  }
  args.push(path.join(root, rel));

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

// `{$R *.res}`（以及设计包的 `{$R *.otares}`）引用的是 IDE 生成物且被 .gitignore 排除，干净检出里必然不存在。
// 不补它就会把「代码没问题」的工程报成 E1026 假红，所以按 IDE 的行为补一个空资源件（落在 .gitignore 内，不脏工作树）。
function ensureProjectRes(tools, src, ctx, outRoot) {
  const refs = [...src.matchAll(/\{\$R\s+([^}\s]+)\}/gi)]
    .map(m => m[1])
    .filter(t => /\.(res|otares)$/i.test(t));
  if (refs.length === 0) return false;
  if (!tools.brcc32) {
    for (const t of refs) ctx.warnings.push('  缺 brcc32.exe：无法补生成 ' + t + '（E1026 属环境缺失，非代码断裂）');
    return false;
  }
  let made = 0;
  for (const ref of refs) {
    const ext = ref.replace(/^.*?(\.\w+)$/, '$1').toLowerCase();
    const fileName = ref.startsWith('*') ? ctx.name + ext : ref.replace(/^\*\./, ctx.name + '.');
    const target = path.join(ctx.projDir, fileName);
    if (fs.existsSync(target)) continue;
    const scratch = path.join(outRoot, 'res');
    fs.mkdirSync(scratch, { recursive: true });
    const rc = path.join(scratch, ctx.fileBase + ext + '.rc');
    fs.writeFileSync(rc, '// 门禁补生成的空资源件（等价于 IDE 新建工程时的 <project>.res 占位）\r\n', 'utf8');
    const r = spawnSync(tools.brcc32, ['-fo' + target, rc], { cwd: scratch, encoding: 'utf8' });
    if (r.status !== 0 || !fs.existsSync(target)) {
      ctx.warnings.push('  brcc32 生成 ' + fileName + ' 失败 EXIT=' + r.status + '：' + ((r.stdout || '') + (r.stderr || '')).trim().split(/\r?\n/).filter(Boolean).pop());
      continue;
    }
    made++;
  }
  return made > 0;
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
    if (e.isDirectory()) { if (!BUILD_ARTIFACT_DIRS.has(e.name)) collect(abs, ext, acc); }
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
