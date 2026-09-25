// 共享守卫负向样本测试（WO-20260923-AUDIT-乙-D5 §一-2 与 §一-3；C 段见 WO-20260925-AUDIT-总控 包二 B1 §1）
// 覆盖三件事，都是「门禁自己的防线」，不属于任何单道门禁的样本：
//  A. SKIP 目录名集单一实现（gate-skip.js）：
//     A1 静态——五道门必须引用共享模块，且源码内不得再残留内联 SKIP 字面量（漂移的物理来源）；
//     A2 行为——`TestResults/` 下的构建文件必须被构建归属门跳过：旧口径（该门 SKIP 集缺这一项）
//        会让它把孤儿单元判成「已被引用」而放行，新口径必须报 O1。这是 §四-5 口径分裂的实测后果。
//  B. 基线文件状态自检（gate-baseline.js）：五道门各喂一份 `{}`（被清空/被顶替的最小形态）⇒
//     必须 EXIT=2 且报「基线不可信」；另测非法 JSON、顶层数组、基线缺失与跨门顶替四种损坏形态。
//     本项只读校验文件状态，不触碰 --emit-baseline 写路径（守写入动作是 C 段，两者互补不重复）。
//  C. 基线写入守卫（gate-emit-guard.js）：窄根拒绝 / 新增键拒绝 / 计数抬升拒绝 / 合规缩短放行，
//     各 ≥2 例，且拒绝时基线文件必须原样（EXIT≠0 且未落盘），放行时必须留下写前 .bak。
// 用法: node test_negative_sample.js   （退出码 0=守卫按预期拦截）
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');
const { GATE_SKIP_DIRS } = require('./gate-skip');

const HERE = __dirname;
const GATES = {
  encoding: path.join(HERE, 'encoding-gate/check_pas_encoding.js'),
  eol: path.join(HERE, 'eol-gate/check_eol.js'),
  evidence: path.join(HERE, 'evidence-encoding-gate/check_evidence_encoding.js'),
  managedCopy: path.join(HERE, 'managed-copy-gate/check_managed_copy.js'),
  buildOwnership: path.join(HERE, 'build-ownership/check_build_ownership.js'),
  mojibake: path.join(HERE, 'mojibake-gate/check_mojibake.js'),
};

let failed = false;
const note = (msg) => console.log(msg);
const fail = (msg) => { console.error(msg); failed = true; };

function run(args) {
  try {
    const out = execFileSync(process.execPath, args, { stdio: 'pipe' });
    return { code: 0, out: out.toString('utf8'), err: '' };
  } catch (e) {
    return { code: e.status === undefined ? -1 : e.status, out: (e.stdout || Buffer.alloc(0)).toString('utf8'), err: (e.stderr || Buffer.alloc(0)).toString('utf8') };
  }
}
// 注：run() 的参数是「门禁脚本 + 门禁自己的 argv」，node 可执行文件由 run() 统一前置。

// ── A1 静态：单一实现，无内联副本 ──────────────────────────────────────────────
for (const [name, file] of Object.entries(GATES)) {
  const src = fs.readFileSync(file, 'utf8');
  if (!/require\('\.\.\/gate-skip'\)/.test(src)) fail(`A1 ${name} 门未引用共享 SKIP 集（require('../gate-skip') 缺失）`);
  if (/['"]BuildOutput['"]/.test(src)) fail(`A1 ${name} 门仍残留内联 SKIP 目录字面量（口径又抄了一份，必然再漂）`);
}
if (GATE_SKIP_DIRS.filter(x => x === 'TestResults').length !== 1) fail('A1 gate-skip.js 的 TestResults 项异常');

// ── A2 行为：TestResults/ 下的 .dpr 不得被构建归属门当作有效引用面 ──────────────
{
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'skiptest-'));
  // 八个生产目录必须齐备：构建归属门自 D7 起 fail-closed（PROD_DIRS 缺子树 / 构建文件面为 0 ⇒ EXIT=3），
  // 本用例要测的是「引用面口径」，不能让夹具本身先撞上覆盖面守卫——那等于用一个洞盖另一个洞。
  for (const d of ['Core', 'Features', 'Persistence', 'VCL', 'FMX', 'Governance', 'Tools', 'DeepFlow']) {
    fs.mkdirSync(path.join(tmp, d), { recursive: true });
  }
  fs.mkdirSync(path.join(tmp, 'TestResults'), { recursive: true });
  // 生产单元 FooOrphan：没有任何【生产】构建文件引用它 ⇒ 应为孤儿
  fs.writeFileSync(path.join(tmp, 'Core', 'FooOrphan.pas'), Buffer.from('unit FooOrphan;\ninterface\nimplementation\nend.\n', 'utf8'));
  // 合法引用面：BarOk 入 prod.dpk ⇒ 非孤儿（同时保证构建文件面非 0，覆盖面守卫不误伤本用例）
  fs.writeFileSync(path.join(tmp, 'Core', 'BarOk.pas'), Buffer.from('unit BarOk;\ninterface\nimplementation\nend.\n', 'utf8'));
  fs.writeFileSync(path.join(tmp, 'prod.dpk'), Buffer.from('package prod;\ncontains\n  BarOk;\n.\n', 'utf8'));
  // CI 产物目录里混进一份 .dpr（真实场景：测试跑完把临时工程文件留在 TestResults/），它引用了该单元
  fs.writeFileSync(path.join(tmp, 'TestResults', 'StrayRunner.dpr'), Buffer.from('program StrayRunner;\nuses FooOrphan;\nbegin\nend.\n', 'utf8'));
  const emptyOrphanBaseline = path.join(tmp, 'baseline_empty.json');
  fs.writeFileSync(emptyOrphanBaseline, JSON.stringify({ generatedFrom: 'test_negative_sample.js', orphans: {} }));

  const after = run([GATES.buildOwnership, '--root', tmp, '--baseline', emptyOrphanBaseline]);
  if (!/O1 FAIL 新增孤儿单元[^\n]*FooOrphan\.pas/.test(after.out + after.err)) {
    fail('A2 构建归属门未把 TestResults/ 下的 .dpr 排除出引用面（孤儿被 CI 产物判成「已引用」= §四-5 口径分裂的实测后果）');
  } else note('A2 通过：TestResults/StrayRunner.dpr 被跳过 ⇒ Core/FooOrphan.pas 如实报孤儿');

  // 修前对照：把该门 SKIP 集退回「缺 TestResults」的旧口径（同源副本），它必须放行同一孤儿
  const src = fs.readFileSync(GATES.buildOwnership, 'utf8');
  const anchor = 'const SKIP = gateSkipSet();';
  const patched = src
    .replace(/require\('\.\.\/([\w-]+)'\)/g, (m, mod) => 'require(' + JSON.stringify(path.resolve(HERE, mod + '.js')) + ')')
    .replace(anchor, "const SKIP = new Set(['.git', '.claude', '__history', 'BuildOutput', 'DCUOutput', 'bin', 'dcu', 'node_modules', '.tmp', '.superpowers', '.workbuddy']); // 「修前」对照：旧 11 项口径缺 TestResults");
  if (!src.includes(anchor) || patched === src) {
    fail('A2 修前对照异常：未能在构建归属门源码上定位 SKIP 集调用点');
  } else {
    const beforeGate = path.join(tmp, 'check_build_ownership_before.js');
    fs.writeFileSync(beforeGate, patched);
    const before = run([beforeGate, '--root', tmp, '--baseline', emptyOrphanBaseline]);
    if (/O1 FAIL 新增孤儿单元[^\n]*FooOrphan\.pas/.test(before.out + before.err)) {
      fail('A2 修前对照失败：旧 11 项口径也报了孤儿 ⇒ 对照不成立（副本可能被其他规则拦下）');
    } else if (before.code !== 0) {
      fail('A2 修前对照异常：旧口径副本以 EXIT=' + before.code + ' 结束，非预期的「假绿」\n' + (before.out + before.err));
    } else note('A2 修前对照通过：旧 11 项 SKIP 口径下 CI 产物把孤儿判成已引用（假绿实锤）');
    fs.rmSync(beforeGate, { force: true });
  }
  fs.rmSync(tmp, { recursive: true, force: true });
}

// ── B 基线状态自检：五道门 × 四种损坏形态 ─────────────────────────────────────
const clean = fs.mkdtempSync(path.join(os.tmpdir(), 'baselineguard-'));
fs.mkdirSync(path.join(clean, 'src'), { recursive: true });
fs.writeFileSync(path.join(clean, 'src', 'Ok.pas'), Buffer.from('unit Ok;\r\ninterface\r\nimplementation\r\nend.\r\n', 'utf8'));
fs.mkdirSync(path.join(clean, 'CodeReview'), { recursive: true });
fs.writeFileSync(path.join(clean, 'CodeReview', 'ok.txt'), Buffer.from('合法 UTF-8 证据\n', 'utf8'));
// 构建归属门自 D7 起对覆盖面 fail-closed（PROD_DIRS 缺子树 / 构建文件面 0 ⇒ EXIT=3），
// 故 B 的夹具必须是一棵「结构完整」的树，否则测到的是扫描失败而不是基线自检（EXIT=3 顶掉 EXIT=2）。
for (const d of ['Core', 'Features', 'Persistence', 'VCL', 'FMX', 'Governance', 'Tools', 'DeepFlow']) {
  fs.mkdirSync(path.join(clean, d), { recursive: true });
}
fs.writeFileSync(path.join(clean, 'Core', 'Ok.pas'), Buffer.from('unit Ok;\r\ninterface\r\nimplementation\r\nend.\r\n', 'utf8'));
fs.writeFileSync(path.join(clean, 'prod.dpk'), Buffer.from('package prod;\ncontains Ok;\n.\n', 'utf8'));

const BAD = {
  empty: '{}',                                   // 被清空/被顶替成空对象：T3 溯源缺失 + T4 键缺失
  array: '[]',                                   // 顶层不是对象：T2
  broken: '{"generated": "x", "files": ',        // 截断的半截 JSON：T2
  crossFed: JSON.stringify({ nulStock: {} }),    // 拿证据门的基线顶替本门：T4 键缺失
};
const BAD_P = {};
for (const [k, v] of Object.entries(BAD)) {
  BAD_P[k] = path.join(clean, 'bad_' + k + '.json');
  fs.writeFileSync(BAD_P[k], v);
}
const MISSING = path.join(clean, 'no_such_baseline.json');

// 每道门的调用方式（五门统一 --root；证据门额外用 --all-worktree，因干净树无 git 跟踪索引）
const INVOCATIONS = {
  encoding: (b) => [GATES.encoding, '--root', path.join(clean, 'src'), '--baseline', b],
  eol: (b) => [GATES.eol, '--root', path.join(clean, 'src'), '--baseline', b],
  managedCopy: (b) => [GATES.managedCopy, '--root', path.join(clean, 'src'), '--baseline', b],
  buildOwnership: (b) => [GATES.buildOwnership, '--root', clean, '--baseline', b],
  evidence: (b) => [GATES.evidence, '--root', clean, '--all-worktree', '--baseline', b],
};
for (const [name, mk] of Object.entries(INVOCATIONS)) {
  for (const [caseName, file] of [...Object.entries(BAD_P), ['missing', MISSING]]) {
    const r = run([...mk(file)]);
    const text = r.err + r.out;
    if (r.code !== 2) fail(`B ${name} 门对损坏基线(${caseName})未以 EXIT=2 拒绝放行，实际 EXIT=${r.code}\n${text}`);
    else if (!/基线不可信/.test(text)) fail(`B ${name} 门 EXIT=2 但未声明原因（取证链断裂）：${caseName}`);
  }
}
note('B 五道门 × 4 种基线损坏形态（空对象/顶层数组/截断 JSON/跨门顶替/文件缺失）全部 EXIT=2 拒绝放行');

// 反向对照：形状正确但缺溯源的基线必须红，补上溯源即放行 ⇒ 拦的是状态，不是误伤。
{
  const noProvenance = path.join(clean, 'eol_no_provenance.json');
  const withProvenance = path.join(clean, 'eol_with_provenance.json');
  const shape = { pas_lf_exceptions: [], pas_mixed_exceptions: [], md_crlf_exceptions: [], pas_multicr_exceptions: [] };
  fs.writeFileSync(noProvenance, JSON.stringify(shape));
  fs.writeFileSync(withProvenance, JSON.stringify({ _comment: '负向样本对照用', ...shape }));
  const noProv = run([GATES.eol, '--root', path.join(clean, 'src'), '--baseline', noProvenance]);
  const withProv = run([GATES.eol, '--root', path.join(clean, 'src'), '--baseline', withProvenance]);
  if (noProv.code !== 2) fail('B 对照失败：形状正确但无溯源的基线被放行（T3 未生效）');
  else note('B 溯源判据生效：无溯源同形基线 EXIT=2');
  if (withProv.code !== 0) fail('B 对照失败：完整可信基线被误拦（EXIT=' + withProv.code + '）\n' + withProv.err);
  else note('B 正向对照通过：可信基线正常放行（未过度兜底）');
}

// ── C 基线写入守卫：gate-emit-guard.js 的四判据（窄根 / 新增键 / 抬升 / 缩短）────────
// 总单判据：新增键、抬高 count 的篡改 ⇒ EXIT≠0 且基线原样；合规缩短 ⇒ EXIT=0 且留写前 .bak。
// 夹具都在临时目录（root ≠ 仓库根），凡要比对本身的一律显式 --allow-narrow-root；
// C1 是唯一不开该开关的用例——它测的就是窄根本身必须被拒。
{
  const { checkOnlyDecrease } = require('./gate-emit-guard');
  const core = require('./mojibake-core.js');
  const cg = fs.mkdtempSync(path.join(os.tmpdir(), 'emitguard-'));
  const mkDir = (name) => { const d = path.join(cg, name); fs.mkdirSync(d, { recursive: true }); return d; };
  const writeJson = (file, obj) => fs.writeFileSync(file, JSON.stringify(obj, null, 2) + '\n', 'utf8');
  const assertRejected = (label, r, bp, raw, whyRe) => {
    if (r.code === 0) fail(`${label} 未被拒绝（EXIT=0）：${whyRe}`);
    else if (fs.readFileSync(bp, 'utf8') !== raw) fail(`${label} 拒绝后基线文件仍被改写（写守卫失效）`);
    else if (!whyRe.test(r.err + r.out)) fail(`${label} 拒绝但未声明原因（取证链断裂）\n${r.err + r.out}`);
    else note(`${label} 通过：EXIT=${r.code}，基线原样，原因已声明`);
  };

  // C0 单元级：扁平计数映射（编译噪声 noise:{码:次数} 形态）共用同一份只减不增判据
  if (!checkOnlyDecrease({ noise: { H1: 5 } }, { noise: { H1: 6 } }, ['noise']).risen.length) fail('C0 计数抬升未被识别（扁平映射）');
  if (!checkOnlyDecrease({ noise: { H1: 5 } }, { noise: { H1: 5, W9: 1 } }, ['noise']).added.length) fail('C0 新增码未被识别（扁平映射）');
  if (checkOnlyDecrease({ noise: { H1: 5, W9: 3 } }, { noise: { H1: 4 } }, ['noise']).added.length) fail('C0 合规缩短被误拦（扁平映射）');
  else note('C0 通过：编译噪声基线（扁平计数映射）与各门共用同一份只减不增判据');

  // C1 窄根拒绝（eol / 托管拷贝 各 1 例）：root ≠ 仓库根且未放行 ⇒ EXIT≠0 且不落盘
  for (const [name, gate] of [['eol', GATES.eol], ['托管拷贝', GATES.managedCopy]]) {
    const src = mkDir('narrow-' + name);
    fs.writeFileSync(path.join(src, 'A.pas'), Buffer.from('unit A;\ninterface\nimplementation\nend.\n', 'utf8'));
    const bp = path.join(cg, 'narrow_' + name + '.json');
    const r = run([gate, '--root', src, '--baseline', bp, '--emit-baseline']);
    if (r.code === 0) fail(`C1 ${name} 窄根 --emit-baseline 未被拒绝（EXIT=0）`);
    else if (fs.existsSync(bp)) fail(`C1 ${name} 窄根拒绝后仍写出了基线文件`);
    else if (!/仓库根|窄根/.test(r.err + r.out)) fail(`C1 ${name} 窄根拒绝未声明原因（取证链断裂）\n${r.err + r.out}`);
    else note(`C1 通过：${name} 窄根 emit 拒绝写入且未落盘`);
  }

  // C2 新增键拒绝（eol / 托管拷贝 / 构建归属 各 1 例）：基线外新条目一律不得由自动路径写入
  {
    const src = mkDir('add-eol');
    for (const f of ['A.pas', 'B.pas']) fs.writeFileSync(path.join(src, f), Buffer.from(`unit ${f[0]};\ninterface\nimplementation\nend.\n`, 'utf8'));
    const bp = path.join(cg, 'add_eol.json');
    writeJson(bp, { _comment: 'C2 夹具', pas_lf_exceptions: ['A.pas'], pas_mixed_exceptions: [], md_crlf_exceptions: [], pas_multicr_exceptions: [] });
    const raw = fs.readFileSync(bp, 'utf8');
    assertRejected('C2 eol 新增键', run([GATES.eol, '--root', src, '--baseline', bp, '--emit-baseline', '--allow-narrow-root']), bp, raw, /拒绝新增/);
  }
  {
    const src = mkDir('add-mc');
    fs.writeFileSync(path.join(src, 'X.pas'), Buffer.from('unit X;\r\ninterface\r\nimplementation\r\nprocedure W(var Buf; N: Integer);\r\nbegin\r\n  FillChar(Buf, N, 0);\r\nend;\r\nend.\r\n', 'utf8'));
    const bp = path.join(cg, 'add_mc.json');
    writeJson(bp, { _comment: 'C2 夹具', files: {} });
    const raw = fs.readFileSync(bp, 'utf8');
    assertRejected('C2 托管拷贝 新增键', run([GATES.managedCopy, '--root', src, '--baseline', bp, '--emit-baseline', '--allow-narrow-root']), bp, raw, /拒绝新增/);
  }
  {
    const root = mkDir('add-own');
    for (const d of ['Core', 'Features', 'Persistence', 'VCL', 'FMX', 'Governance', 'Tools', 'DeepFlow']) fs.mkdirSync(path.join(root, d), { recursive: true });
    fs.writeFileSync(path.join(root, 'Core', 'FooOk.pas'), Buffer.from('unit FooOk;\ninterface\nimplementation\nend.\n', 'utf8'));
    fs.writeFileSync(path.join(root, 'Core', 'FooOrphan.pas'), Buffer.from('unit FooOrphan;\ninterface\nimplementation\nend.\n', 'utf8'));
    fs.writeFileSync(path.join(root, 'prod.dpk'), Buffer.from('package prod;\ncontains\n  FooOk;\n.\n', 'utf8'));
    const bp = path.join(cg, 'add_own.json');
    writeJson(bp, { generatedFrom: 'test_negative_sample.js C2', orphans: {} });
    const raw = fs.readFileSync(bp, 'utf8');
    assertRejected('C2 构建归属 新增键（新孤儿）', run([GATES.buildOwnership, '--root', root, '--baseline', bp, '--emit-baseline', '--allow-narrow-root']), bp, raw, /拒绝新增/);
  }

  // C3 计数抬升拒绝（托管拷贝 / 丙类损坏 各 1 例）
  {
    const src = mkDir('rise-mc');
    fs.writeFileSync(path.join(src, 'Y.pas'), Buffer.from(
      'unit Y;\r\ninterface\r\nimplementation\r\nprocedure P(var A, B);\r\nbegin\r\n  Move(A, B, 1);\r\n  Move(A, B, 2);\r\n  Move(A, B, 3);\r\nend;\r\nend.\r\n', 'utf8'));
    const bp = path.join(cg, 'rise_mc.json');
    writeJson(bp, { _comment: 'C3 夹具', files: { 'Y.pas': { move: 1, fillchar: 0 } } });
    const raw = fs.readFileSync(bp, 'utf8');
    assertRejected('C3 托管拷贝 抬升', run([GATES.managedCopy, '--root', src, '--baseline', bp, '--emit-baseline', '--allow-narrow-root']), bp, raw, /拒绝抬高/);
  }
  {
    const repo = mkDir('rise-pb');
    execFileSync('git', ['-C', repo, 'init', '-q'], { stdio: 'pipe' });
    const text = 'unit RiseB;\ninterface\nimplementation\nprocedure P;\nvar s: string;\nbegin\n  s := \'one\n  s := \'two\n  s := \'three\nend.\n';
    fs.writeFileSync(path.join(repo, 'RiseB.pas'), Buffer.from(text, 'utf8'));
    execFileSync('git', ['-C', repo, 'add', 'RiseB.pas'], { stdio: 'pipe' });
    const n = core.scanUnterminatedStrings(text).length;
    if (n < 2) fail(`C3 丙类夹具未产生 ≥2 个丙-B 事件（实际 ${n}），抬升用例不成立`);
    else {
      const bp = path.join(cg, 'rise_pb.json');
      writeJson(bp, { generatedFrom: 'test_negative_sample.js C3', pbStock: { 'RiseB.pas': { count: n - 1, reason: 'C3 夹具：抬升用' } } });
      const raw = fs.readFileSync(bp, 'utf8');
      assertRejected('C3 丙类损坏 抬升', run([GATES.mojibake, '--root', repo, '--baseline', bp, '--emit-baseline', '--allow-narrow-root']), bp, raw, /拒绝抬高/);
    }
  }

  // C4 合规缩短放行 + 写前 .bak（eol / 托管拷贝 各 1 例）
  {
    const src = mkDir('shrink-eol');
    fs.writeFileSync(path.join(src, 'A.pas'), Buffer.from('unit A;\ninterface\nimplementation\nend.\n', 'utf8'));   // 仍违规（纯 LF）
    fs.writeFileSync(path.join(src, 'B.pas'), Buffer.from('unit B;\r\ninterface\r\nimplementation\r\nend.\r\n', 'utf8')); // 已修复（CRLF）
    const bp = path.join(cg, 'shrink_eol.json');
    writeJson(bp, { _comment: 'C4 夹具', pas_lf_exceptions: ['A.pas', 'B.pas'], pas_mixed_exceptions: [], md_crlf_exceptions: [], pas_multicr_exceptions: [] });
    const raw = fs.readFileSync(bp, 'utf8');
    const r = run([GATES.eol, '--root', src, '--baseline', bp, '--emit-baseline', '--allow-narrow-root']);
    if (r.code !== 0) fail(`C4 eol 合规缩短未放行（EXIT=${r.code}）\n${r.err + r.out}`);
    else {
      const written = JSON.parse(fs.readFileSync(bp, 'utf8'));
      if (written.pas_lf_exceptions.join(',') !== 'A.pas') fail('C4 eol 缩短后条目未正确收敛：' + written.pas_lf_exceptions.join(','));
      if (!fs.existsSync(bp + '.bak')) fail('C4 eol 写前未留 .bak 备份');
      else if (JSON.parse(fs.readFileSync(bp + '.bak', 'utf8')).pas_lf_exceptions.join(',') !== 'A.pas,B.pas') fail('C4 eol .bak 不是写入前的旧基线');
      else if (fs.readFileSync(bp + '.bak', 'utf8') !== raw) fail('C4 eol .bak 内容与写入前原件不一致');
      else note('C4 通过：eol 缩短放行 EXIT=0，条目收敛，.bak 为写入前原件');
    }
  }
  {
    const src = mkDir('shrink-mc');
    fs.writeFileSync(path.join(src, 'Z.pas'), Buffer.from('unit Z;\r\ninterface\r\nimplementation\r\nprocedure W(var Buf; N: Integer);\r\nbegin\r\n  FillChar(Buf, N, 0);\r\nend;\r\nend.\r\n', 'utf8'));
    const bp = path.join(cg, 'shrink_mc.json');
    writeJson(bp, { _comment: 'C4 夹具', files: { 'Z.pas': { move: 5, fillchar: 2 } } });
    const raw = fs.readFileSync(bp, 'utf8');
    const r = run([GATES.managedCopy, '--root', src, '--baseline', bp, '--emit-baseline', '--allow-narrow-root']);
    if (r.code !== 0) fail(`C4 托管拷贝 合规缩短未放行（EXIT=${r.code}）\n${r.err + r.out}`);
    else {
      const written = JSON.parse(fs.readFileSync(bp, 'utf8'));
      if (!written.files['Z.pas'] || written.files['Z.pas'].move !== 0 || written.files['Z.pas'].fillchar !== 1) {
        fail('C4 托管拷贝 缩短后计数未收敛：' + JSON.stringify(written.files));
      }
      const bak = JSON.parse(fs.readFileSync(bp + '.bak', 'utf8'));
      if (!bak.files['Z.pas'] || bak.files['Z.pas'].move !== 5) fail('C4 托管拷贝 .bak 不是写入前的旧基线');
      else note('C4 通过：托管拷贝 计数下调放行 EXIT=0，.bak 为写入前原件');
    }
  }

  fs.rmSync(cg, { recursive: true, force: true });
}

fs.rmSync(clean, { recursive: true, force: true });
console.log(failed ? 'SHARED-GUARD-TEST: FAIL' : 'SHARED-GUARD-TEST: PASS');
process.exit(failed ? 1 : 0);
