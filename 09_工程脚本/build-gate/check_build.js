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
const { loadGateBaseline } = require('../gate-baseline.js');
const { guardedEmitBaseline } = require('../gate-emit-guard.js');

const HERE = __dirname;
const REPO_ROOT = path.resolve(HERE, '..', '..');

// 两个工程面：.dpr = 可执行程序，.dpk = 包（本仓的生产交付形态，BPL）。两面的枚举与判定完全同构。
const FACES = [
  { key: 'dpr', pattern: '*.dpr', ext: '.dpr', label: '.dpr' },
  { key: 'dpk', pattern: '*.dpk', ext: '.dpk', label: '.dpk' },
];
// 清单文件里的整面选择子：写 all-dpk 而不是抄 25 条路径，新增包自动进面，杜绝「清单漏更新」这种静默缩面。
const FACE_SELECTOR = new Map(FACES.map(f => [`all-${f.key}`, f]));

// 证据附件面（WO-20260926-AUDIT-甲-A6-01）。口径唯一一处在本文件，README §二 与契约注释只指向这里：
//   CodeReview/** 下的证据件（探针、夹具）不是工程真相源，不得被显式点名/清单条目拉进任何编译判定面。
// 这是机械强制，不是第二套路径白名单：白名单放行谁=门禁 bypass（禁止），本口径回答的是「证据目录根本
// 不是工程真相源」——与 BUILD_ARTIFACT_DIRS 屏蔽 CI 产物目录同类，判定路径上依然没有按工程放行形态。
const EVIDENCE_FACE_DIR = 'CodeReview';
const EVIDENCE_FACE_REJECT = '证据附件不得进生产编译面（口径唯一源：check_build.js 的 EVIDENCE_FACE_DIR，README §二 / T0 契约注释指向此处）';

// 与其余四道门共用 gate-skip 的目录名集（`Logs` 是本门专属：dcc64 的编译日志落处）。
// 这是「枚举面」的定义，不是「范围内放行谁」——判定面内每一个工程都编、都判，红就红。
const BUILD_ARTIFACT_DIRS = gateSkipSet('Logs');
// 源目录（BUG-285：dcc64 即使指定 -N0，也可能把早期依赖的 DCU 落进源目录，跑完须清掉【本次新产生】的那些）。
const SOURCE_DIRS = ['Core', 'Features', 'Persistence', 'VCL', 'FMX', 'Governance', 'Tests', 'Tools', 'Examples', 'DeepFlow', 'DeepBaseRun', 'doQry', 'ThirdParty'];
// 无 .dproj 工程的缺省单元面：与 Scripts/run_tests.ps1 的 $UnitPaths 同构（相对 root 解析，故隔离工作树同样可用）。
const UNIT_DIRS = ['Core', 'Features', 'Persistence', 'VCL', 'FMX', 'Governance', 'ThirdParty/Payment', 'ThirdParty/Social', 'Tools/CLI', 'Tools/WebService', 'Tests', 'Tests/Regression', 'Tests/Integration'];
// 无 .dproj 工程的缺省命名空间：外置到 contracts/ 声明文件（WO-20260924-AUDIT-甲-D7 段4），
// 与契约清单同族同位置。留在代码里时「门禁缺一个命名空间」会伪装成源码的 F2613 假红。
const NS_CONTRACT = path.join(HERE, 'contracts', '命名空间声明.txt');
const DUNITX_SOURCE = process.env.DEEPBASE_DUNITX_SOURCE || 'D:\\ProgramData\\delphi\\DUnitX\\Source';
const FALLBACK_BDS = 'D:\\Program Files (x86)\\Embarcadero\\Studio\\37.0';
// 编译噪声基线（WO-20260924-AUDIT-甲-D9 段4 / 外单 DB-006）：dcc64 报出的 Hint/Warning 按码计数。
// 目标是【不增长】而非清零——存量噪声是正当技术债，清零会伪装成「全绿」；只拦新增/增长，让
// 「噪声下降是修复的结果，不是视线的转移」可核。基线绑定【判定面身份】：只有同一面 emit 与 compare
// 的按码计数才可比，跨面（子集 vs 超集）只观测不判定。生产噪声基线取自全绿的 T0 生产契约面
// （--all 是超集、含 T1 观测面的在册红件，恒非全绿，不能作基线面）。
const NOISE_BASELINE = path.join(HERE, 'noise-baseline.json');

// 退出码：0=通过 / 1=门禁报红（有工程编译失败 或 全量面编译噪声相对基线增长）/ 2=枚举或输入面不可信
//         （readdir 失败、计数为 0、清单与索引不一致、包依赖成环、找不到编译器、清单/噪声基线读不到或不可信）/ 3=参数不合法
// 注意：单个工程是否「编译通过」只看 BUILD_EXIT=0；Hint/Warning 从不把一次成功的编译改判为编译失败（段4 口径=先报不修）。
//       噪声「增长」只影响门禁整体放行（EXIT 1），不改变任何工程的编译判定语义。
const EXIT_OK = 0, EXIT_BUILD_FAILED = 1, EXIT_SCAN_FAILED = 2, EXIT_BAD_ARGS = 3;

function usage() {
  console.log([
    '编译门禁 用法: node check_build.js (--all | --dpr <path>... | --dpk <path>... | --manifest <file>...) [--root <dir>] [--baseline <file>] [--emit-baseline] [--allow-narrow-root] [--help]',
    '',
    '  两种模式的适用场景、实测耗时与判定口径见 README-编译门禁.md（本目录）。',
    '',
    '  --all       判定面 = git 已跟踪的全部 .dpr + 全部 .dpk（无例外）。',
    '  --dpr/--dpk 显式点名工程（可重复）；--manifest 读外部契约清单（可重复，取并集）。',
    '              清单每行一个仓内相对路径，或整面选择子 all-dpr / all-dpk；# 起注释。',
    '  --baseline / --emit-baseline 编译噪声基线（段4）：--emit-baseline 从【当前判定面】写按码聚合的 Hint/Warning',
    '              基线（要求该面全绿，失败单元不计噪声、否则基线少计）。判定时仅当本轮判定面与基线记录面一致才比对，',
    '              只拦增长与新增码，不拦存量下降；跨面（如子集 vs 全量）计数不可比，仅观测不判定。',
    '              写入侧同五道门走 gate-emit-guard.js：只减不增（新增码/抬升拒绝）、非仓库根扫描拒绝、写前 .bak；',
    '              换判定面重生成基线属人工动作（先移除旧基线文件再 --emit-baseline），自动路径不得跨面改写。',
    '  三种范围声明互斥且必须给一种；本门禁 fail-closed，不提供「跳过并继续报绿」的任何形态。',
    '',
    'EXIT: 0=通过 1=编译失败或噪声增长 2=枚举/输入面不可信 3=参数不合法',
  ].join('\n'));
}

function failScan(msg) {
  console.error('编译门禁失败(fail-closed)：' + msg);
  process.exit(EXIT_SCAN_FAILED);
}

// argv 显式入参：注入式负样本（test_negative_sample.js ⑦/⓯/⓳-㉖）在【门禁自身进程】内替换 fs 后
// 调用本函数——main 挂在 require.main 守卫后，require 不触发判定，静默 EXIT=0 就是假绿。
function main(argv) {
  const opts = parseGateArgs(argv || process.argv.slice(2), {
    label: '编译',
    root: REPO_ROOT,
    baseline: NOISE_BASELINE,
    extra: ['all', 'emit-baseline', 'allow-narrow-root'],
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
  const noise = new Map(); // 编译噪声：dcc64 报出的 Hint/Warning 按码聚合（段4 可观测性，全量面下比对基线）

  for (const face of FACES) {
    const targets = declared[face.key];
    const st = stats.get(face.key);
    st.total = targets.length;
    targets.forEach((rel, i) => {
      const ctx = projectEnv(root, rel, env, face);
      const res = compileOne(tools, root, rel, ctx, face, outRoot);
      const nh = sumCodes(res.codes);
      console.log(`[${face.key} ${i + 1}/${targets.length}] ${rel} CONFIG=${ctx.configTag} BUILD_EXIT=${res.exit} HINT=${nh.hints} WARN=${nh.warnings}`);
      for (const [code, n] of Object.entries(res.codes)) noise.set(code, (noise.get(code) || 0) + n);
      if (res.resGenerated) resGenerated++;
      if (res.exit === 0) { st.ok++; return; }
      st.failed++;
      st.items.push({ rel, exit: res.exit, firstError: res.firstError, killed: res.killed });
      console.error(`  ${rel} 编译失败：${res.firstError || '(无错误行，EXIT=' + res.exit + ')'}`);
      for (const w of ctx.warnings) console.error('  ' + w);
    });
  }

  // 声明未被判定面命中 = 路径拼错或工程已删。静默失效的声明比没有声明更糟（它给人「已经处理过」的错觉）。
  for (const proj of env.nsExtra.keys()) {
    if (!env.nsExtraUsed.has(proj)) {
      failScan(`命名空间声明未被本轮判定面命中（路径拼错、工程已删或不在范围内）：${proj}`);
    }
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
  const noiseTotals = sumCodes(Object.fromEntries(noise));
  console.log(`编译门禁统计：编译噪声 Hint=${noiseTotals.hints} Warning=${noiseTotals.warnings} 按码=${formatNoise(noise)}`);

  const failed = FACES.reduce((n, f) => n + stats.get(f.key).failed, 0);
  const reportFailures = () => {
    for (const face of FACES) for (const x of stats.get(face.key).items) {
      console.error(`  ${x.rel} EXIT=${x.exit}${x.killed ? ' (超时被终止)' : ''}  ${x.firstError}`);
    }
  };

  // 编译失败与噪声增长是两条正交的红（都记 EXIT 1）；噪声基线绑定【判定面身份】declared.source：
  // 只有同一面 emit 与 compare 的按码计数才可比。--all 是超集且在本仓含 T1 观测面的在册红件（恒非全绿），
  // 不能作基线面；生产噪声基线取自全绿的 T0 生产契约面（all-dpk + DeepBaseTests.dpr）。
  if (opts.flags.has('emit-baseline')) {
    if (failed > 0) {
      console.error(`编译噪声基线未写入：判定面「${declared.source}」有 ${failed} 个工程编译失败。` +
        `失败单元不产出 Hint/Warning，据此写基线会系统性少计、把噪声藏进"缺失"——基线必须来自全绿编译面。` +
        `请用全绿判定面（如 --manifest contracts/T0-生产契约面.txt）重跑 --emit-baseline。`);
      reportFailures();
      process.exit(EXIT_BUILD_FAILED);
    }
    emitNoiseBaseline(opts.baseline, root, declared, noise, noiseTotals, { allowNarrowRoot: opts.flags.has('allow-narrow-root'), scanCount: judgedTotal });
    console.log(`编译噪声基线已写入：${opts.baseline}（判定面=${judgedTotal} 来源=${declared.source} 按码=${formatNoise(noise)}）`);
    process.exit(EXIT_OK);
  }
  if (failed > 0) {
    console.error('编译门禁失败：' + failed + ' 个工程编译不过');
    reportFailures();
    process.exit(EXIT_BUILD_FAILED);
  }
  const cmp = compareNoise(opts.baseline, noise, declared.source);
  if (!cmp.compared) {
    // 面不一致：跨面计数不可比，如实跳过（不报红也不冒充判过），与子集「仅观测」同调。
    console.log(`编译噪声基线未比对：本轮判定面「${declared.source}」≠ 基线记录面「${cmp.baselineSurface}」（跨面计数不可比）；噪声计数仅观测`);
  } else if (cmp.violations.length) {
    console.error('编译门禁失败：编译噪声相对基线增长（段4 口径=不增长，非清零；下降须来自真实修复）:');
    cmp.violations.forEach(v => console.error('  ' + v));
    process.exit(EXIT_BUILD_FAILED);
  } else {
    console.log(`编译噪声基线比对通过：判定面「${declared.source}」按码计数未超过 ${path.basename(opts.baseline)}`);
  }
  console.log(`编译门禁通过：${judgedTotal} 个工程全部 BUILD_EXIT=0（判定应来自隔离 --detach 工作树 @ 目标 commit）`);
  process.exit(EXIT_OK);
}

// dcc64 噪声行的真实形态是 `<file>(<line>) Hint: H2443 ...` / `<file>(<line>) Warning: W1035 ...`：
// 严重级前面是【右括号 + 空格】，不是冒号。曾按 `: Hint:` 写正则→整条扫不中→恒报 Hint=0，
// 把「解析器漏读所有噪声」伪装成「全库零噪声」——正是本门禁链要堵的「校验放行、取值静默丢」型 fail-open。
// 故只锚定「严重级词 + 码」本身（Hint/Warning 后紧跟 H/W 数字码），不约束其左侧标点；
// Error/Fatal 的 E/F 码不匹配 [HW]，天然排除。
function parseNoise(out) {
  const codes = {};
  for (const line of out.split(/\r?\n/)) {
    const m = /\b(?:Hint|Warning):\s+([HW]\d{3,5})\b/.exec(line);
    if (m) codes[m[1]] = (codes[m[1]] || 0) + 1;
  }
  return codes;
}

function sumCodes(codes) {
  let hints = 0, warnings = 0;
  for (const [code, n] of Object.entries(codes)) {
    if (code[0] === 'H') hints += n; else if (code[0] === 'W') warnings += n;
  }
  return { hints, warnings };
}

function formatNoise(noiseMap) {
  const entries = [...noiseMap.entries()].filter(([, n]) => n > 0).sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1));
  return entries.length ? entries.map(([c, n]) => `${c}=${n}`).join(',') : '(无)';
}

function gitHead(root) {
  const r = spawnSync('git', ['-C', root, 'rev-parse', 'HEAD'], { encoding: 'utf8' });
  return r.status === 0 ? r.stdout.trim() : 'unknown';
}

function emitNoiseBaseline(file, root, declared, noise, totals, emitOpts) {
  const doc = {
    generated: new Date().toISOString(),
    generatedFrom: `git HEAD ${gitHead(root)} 清单来源=${declared.source} 已跟踪=${declared.trackedTotal}`,
    surface: declared.source,
    _comment: 'DeepBase 编译噪声基线（WO-20260924-AUDIT-甲-D9 段4 / DB-006）。noise=各 Hint/Warning 码在【surface 记录的判定面】上的出现次数，门禁只拦增长不拦存量；比对要求当前判定面与 surface 一致（跨面计数不可比）。',
    noise: Object.fromEntries([...noise.entries()].filter(([, n]) => n > 0).sort()),
    totals,
  };
  // 跨面 = 与旧基线的条目根本不可比，而且一旦写入会让后续同面判定静默变成「跨面跳过」
  // （compareNoise 见面不一致即不比对 ⇒ 门禁无声失效）。换面重生成是人工动作，不由 emit 自动完成。
  let incomparable = null;
  if (fs.existsSync(file)) {
    try {
      const old = JSON.parse(fs.readFileSync(file, 'utf8'));
      if (old && old.surface && old.surface !== doc.surface) {
        incomparable = `判定面不一致：旧基线记录面「${old.surface}」≠ 本轮判定面「${doc.surface}」，跨面计数不可比；自动路径不得跨面改写基线（确要换面重生成：先人工移除旧基线文件，再 --emit-baseline）`;
      }
    } catch (e) { /* 旧基线不可解析交由守卫按 T2 语义拒绝（EXIT=2），此处不吞不判 */ }
  }
  guardedEmitBaseline({
    label: '编译噪声', baselinePath: file, root, repoRoot: REPO_ROOT,
    allowNarrowRoot: emitOpts.allowNarrowRoot, scanCount: emitOpts.scanCount,
    entryKeys: ['noise'], newBaseline: doc, incomparableReason: incomparable,
  });
}

// 只拦「增长」与「新增码」：current[code] > baseline.noise[code]（缺省 0）即红。存量下降/归零是正当目标，一律放行。
function compareAgainstBaseline(base, noise) {
  const violations = [];
  for (const [code, n] of noise) {
    if (n === 0) continue;
    const b = base[code] || 0;
    if (n > b) violations.push(`${code}: 当前 ${n} > 基线 ${b}${b === 0 ? '（基线中不存在此码 = 新增噪声）' : ''}`);
  }
  return violations;
}

// 读基线（不可信 → loadGateBaseline 内 process.exit(2)）；仅当基线记录面与本轮判定面一致才比对。
// 面不一致按「跨面计数不可比」如实跳过（不红），返回 compared=false 交由调用方打印观测说明。
function compareNoise(file, noise, currentSurface) {
  const baseline = loadGateBaseline({ file, label: '编译噪声', keys: { noise: 'object' } });
  if (baseline.surface && currentSurface && baseline.surface !== currentSurface) {
    return { compared: false, baselineSurface: baseline.surface, violations: [] };
  }
  return { compared: true, baselineSurface: baseline.surface || null, violations: compareAgainstBaseline(baseline.noise, noise) };
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
  if (isEvidenceFacePath(rel)) {
    failScan(`${origin} 条目指向 ${EVIDENCE_FACE_DIR}/** 证据附件面：${rel}——${EVIDENCE_FACE_REJECT}`);
  }
  if (!tracked[got.key].includes(rel)) {
    failScan(`${origin} 不是本仓已跟踪的 ${got.label}：${rel}（拼错的根/路径不会静默缩小扫描面，直接红）`);
  }
  return rel;
}

// 路径是否落在证据附件面下（大小写不敏感，与扩展名判定同一口径）。
function isEvidenceFacePath(rel) {
  return rel.toLowerCase().startsWith(EVIDENCE_FACE_DIR.toLowerCase() + '/');
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

// 命名空间声明文件：default 行给无 .dproj 工程的缺省 -NS，其余每行给单个工程补命名空间。
// fail-closed 与 readManifest 同调：读不到、无 default 行、空值、多行 default 一律 EXIT=2，
// 「声明文件写坏了」绝不能退化成「安静地少给几个命名空间然后报红/报绿都不对」。
function readNamespaceContract(abs) {
  let txt;
  try {
    txt = fs.readFileSync(abs, 'utf8');
  } catch (e) {
    failScan(`命名空间声明读不到：${abs}（${e.code || e.message}）`);
  }
  let base = null;
  const byProject = new Map();
  for (const raw of txt.split(/\r?\n/)) {
    const line = raw.replace(/#.*$/, '').trim();
    if (!line) continue;
    const sep = line.indexOf('=');
    if (sep < 0) failScan(`命名空间声明行缺 '='：${abs} → ${line}`);
    const key = line.slice(0, sep).trim().toLowerCase();
    const value = line.slice(sep + 1).split(';').map(s => s.trim()).filter(Boolean).join(';');
    if (!value) failScan(`命名空间声明等号后为空：${abs} → ${line}`);
    if (key === 'default') {
      if (base !== null) failScan(`命名空间声明有多行 default：${abs}`);
      base = value;
      continue;
    }
    byProject.set(line.slice(0, sep).trim().split(path.sep).join('/').toLowerCase(), value);
  }
  if (base === null) failScan(`命名空间声明没有 default 行：${abs}`);
  return { base, byProject };
}

function buildDefaultEnv(root, bds, outRoot) {
  const ns = readNamespaceContract(NS_CONTRACT);
  const dirs = UNIT_DIRS.map(d => path.resolve(root, d));
  // 与 compile_packages_win64.ps1 的 $LibPaths 同构：RTL/VCL 的 .dcu 在这里，缺了它们会把好工程误判成 F2613。
  dirs.push(path.join(bds, 'lib', 'Win64', 'release'), path.join(bds, 'lib', 'Win64', 'debug'), DUNITX_SOURCE);
  // 本轮包输出面：后面的包 requires 前面的包，dcc64 在单元/对象搜索路径上找 .dcp，缺了就会 F2613 假红。
  dirs.push(path.join(outRoot, 'dcp'));
  return {
    root,
    bds,
    searchPaths: dirs.join(';'),
    ns: ns.base,
    nsExtra: ns.byProject,
    nsExtraUsed: new Set(),
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
  const extra = env.nsExtra.get(rel.toLowerCase());
  if (extra) env.nsExtraUsed.add(rel.toLowerCase());
  // 声明只补不减：允许工程补命名空间，不允许它反过来裁减缺省集——否则「声明」就成了缩面手段。
  // 无声明时原样返回，保证 -NS 串与外置前逐位相同。
  const mergeNs = (own) => {
    if (!extra) return own;
    return [...new Set(own.split(';').concat(extra.split(';')))].join(';');
  };
  if (!fs.existsSync(dproj)) {
    return { ...base, name: pkgName(root, rel), configTag: 'default', searchPaths: env.searchPaths, ns: mergeNs(env.ns) };
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
    ns: mergeNs(namespaces.size ? [...namespaces].join(';') : env.ns),
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
  return { exit: r.status === null ? (r.signal ? 124 : 1) : r.status, firstError, killed: !!r.signal, resGenerated, codes: parseNoise(out) };
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

if (require.main === module) main();

module.exports = { main, parseNoise, sumCodes, compareAgainstBaseline, compareNoise };
