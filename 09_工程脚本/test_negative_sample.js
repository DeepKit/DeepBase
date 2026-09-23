// 共享守卫负向样本测试（WO-20260923-AUDIT-乙-D5 §一-2 与 §一-3）
// 覆盖两件事，都是「门禁自己的防线」，不属于任何单道门禁的样本：
//  A. SKIP 目录名集单一实现（gate-skip.js）：
//     A1 静态——五道门必须引用共享模块，且源码内不得再残留内联 SKIP 字面量（漂移的物理来源）；
//     A2 行为——`TestResults/` 下的构建文件必须被构建归属门跳过：旧口径（该门 SKIP 集缺这一项）
//        会让它把孤儿单元判成「已被引用」而放行，新口径必须报 O1。这是 §四-5 口径分裂的实测后果。
//  B. 基线文件状态自检（gate-baseline.js）：五道门各喂一份 `{}`（被清空/被顶替的最小形态）⇒
//     必须 EXIT=2 且报「基线不可信」；另测非法 JSON、顶层数组、基线缺失与跨门顶替四种损坏形态。
//     本项只读校验文件状态，不触碰 --emit-baseline 写路径（守写入动作是 B1，两者互补不重复）。
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
  fs.mkdirSync(path.join(tmp, 'Core'), { recursive: true });
  fs.mkdirSync(path.join(tmp, 'TestResults'), { recursive: true });
  // 生产单元 FooOrphan：没有任何生产构建文件引用它 ⇒ 应为孤儿
  fs.writeFileSync(path.join(tmp, 'Core', 'FooOrphan.pas'), Buffer.from('unit FooOrphan;\ninterface\nimplementation\nend.\n', 'utf8'));
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
fs.mkdirSync(path.join(clean, 'Core'), { recursive: true });
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

// 每道门的调用方式（证据门用 --repo + --all-worktree，其余用 --root）
const INVOCATIONS = {
  encoding: (b) => [GATES.encoding, '--root', path.join(clean, 'src'), '--baseline', b],
  eol: (b) => [GATES.eol, '--root', path.join(clean, 'src'), '--baseline', b],
  managedCopy: (b) => [GATES.managedCopy, '--root', path.join(clean, 'src'), '--baseline', b],
  buildOwnership: (b) => [GATES.buildOwnership, '--root', clean, '--baseline', b],
  evidence: (b) => [GATES.evidence, '--repo', clean, '--all-worktree', '--baseline', b],
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

fs.rmSync(clean, { recursive: true, force: true });
console.log(failed ? 'SHARED-GUARD-TEST: FAIL' : 'SHARED-GUARD-TEST: PASS');
process.exit(failed ? 1 : 0);
