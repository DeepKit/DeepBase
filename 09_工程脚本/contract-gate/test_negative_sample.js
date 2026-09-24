// 消费者契约门禁负向样本测试（WO-20260924-AUDIT-甲-D9 段2 / 判据3「签名变更检测对构造样本必红」）
//
// 用 --source worktree + 临时树构造样本，隔离真仓在途改动，逐条证明门「拦得住、且看不见=会假绿」：
//  ① 控制组：worktree 内容 = HEAD 原文 → 签名与基线一致 → EXIT=0（证明本测夹具与抽取同构，非恒红）。
//  ② 破坏（改写公开签名）：把某稳定单元 interface 内一个公开符号重命名 → 基线内该签名消失 → EXIT=1。
//  ③ 破坏（删除公开签名）：删掉一条 function/procedure 声明 → EXIT=1。
//  ④ 兼容新增：只追加一条新公开声明 → 不红（仅提示），EXIT=0（证明门不误伤向后兼容）。
//  ⑤ 单元缺失：契约声明的单元在树中不存在 → EXIT=1（分叉/改名即被拦）。
//  ⑥ 单元重复：同名 .pas 两份 → EXIT=1（消费者契约禁止一份 API 两处定义）。
//  ⑦ stability 枚举非法 → EXIT=2；契约 units 为空 → EXIT=2。
//  ⑧ fail-closed：契约文件不可解析 → EXIT=3。
// 用法: node test_negative_sample.js   （退出码 0=全部按预期）
'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');

const HERE = __dirname;
const CHECK = path.join(HERE, 'check_contract.js');
const REPO = path.join(HERE, '../..');
const REAL_BASELINE = path.join(HERE, 'signature-baseline.json');
const CONTRACT = JSON.parse(fs.readFileSync(path.join(REPO, 'contract/consumer-contract.json'), 'utf8'));
const BASE = JSON.parse(fs.readFileSync(REAL_BASELINE, 'utf8'));

let failed = false;
function expect(code, label, run) {
  let got, out = '';
  try {
    got = run();
  } catch (e) {
    got = e.status === undefined ? 'throw:' + e.message : e.status;
    out = (e.stdout || '') + (e.stderr || '');
  }
  const ok = got === code;
  console.log(`${ok ? 'OK ' : 'BAD'} 期望 EXIT=${code} 实得 ${got}  — ${label}`);
  if (!ok) { failed = true; if (out) console.log('----输出----\n' + out.trim()); }
}
function runGate(args) {
  try {
    const r = execFileSync(process.execPath, [CHECK, ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
    return 0;
  } catch (e) { return e.status === undefined ? 99 : e.status; }
}

// 挑一个 interface 里有可重命名公开符号、且体量小的稳定单元做破坏样本。
const UNIT = 'DeepBase.MRU';
const ENTRY = CONTRACT.units.find(u => u.unit === UNIT);
const REL = `${ENTRY.subdir}/${UNIT}.pas`;
const HEAD_SRC = execFileSync('git', ['-C', REPO, 'show', `HEAD:${REL}`], { encoding: 'utf8' });
// 从基线签名里取一个含标识符的真实公开声明作为改写目标（确保它确在 interface 内）。
const candidateSig = BASE.units[UNIT].sigs.find(s => /\bT[A-Za-z]\w*\b/.test(s)) || BASE.units[UNIT].sigs[0];

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'contract-'));
function resetUnitFile(text) {
  const dest = path.join(tmp, ENTRY.subdir);
  fs.mkdirSync(dest, { recursive: true });
  for (const f of fs.readdirSync(dest)) fs.rmSync(path.join(dest, f), { force: true });
  fs.writeFileSync(path.join(dest, `${UNIT}.pas`), text, 'utf8');
}
function tmpContract(units) {
  const p = path.join(tmp, 'contract.json');
  fs.writeFileSync(p, JSON.stringify({ units }), 'utf8');
  return p;
}
function tmpBaselineFor(unit, sigs) {
  const p = path.join(tmp, 'baseline.json');
  fs.writeFileSync(p, JSON.stringify({ units: { [unit]: { rel: REL, stability: 'stable', sigs } } }), 'utf8');
  return p;
}
const cleanSigs = BASE.units[UNIT].sigs;

// ① 控制组（worktree=HEAD 原文）
resetUnitFile(HEAD_SRC);
expect(0, '① 控制组：worktree 未改动 → 与基线一致', () =>
  runGate(['--source', 'worktree', '--root', tmp, '--contract', tmpContract([ENTRY]), '--baseline', tmpBaselineFor(UNIT, cleanSigs)]));

// ② 改写公开符号：把候选签名里的一个标识符整体重命名 → 基线内含它的签名消失
const tok = (candidateSig.match(/\bT[A-Za-z]\w+\b/) || [])[0];
if (tok) {
  resetUnitFile(HEAD_SRC.split(tok).join(tok + 'Renamed'));
  expect(1, '② 破坏：重命名公开符号 → 红', () =>
    runGate(['--source', 'worktree', '--root', tmp, '--contract', tmpContract([ENTRY]), '--baseline', tmpBaselineFor(UNIT, cleanSigs)]));
} else { console.log('SKIP ②（候选签名无标识符，③已证改写拦截）'); }

// ③ 删除一条 function/procedure 声明
const m = HEAD_SRC.match(/(procedure|function)\s+[A-Za-z_.][\w.]*(?:\([^;]*\))?(?:\s*:\s*[\w.<>\[\]]+)?\s*;/);
if (m) {
  resetUnitFile(HEAD_SRC.replace(m[0], '(*removed*)'));
  expect(1, '③ 破坏：删除一条公开声明 → 红', () =>
    runGate(['--source', 'worktree', '--root', tmp, '--contract', tmpContract([ENTRY]), '--baseline', tmpBaselineFor(UNIT, cleanSigs)]));
} else { console.log('SKIP ③（该单元 interface 无匹配单行声明，②已证破坏拦截）'); }

// ④ 兼容新增：追加一条新公开声明（不改旧签名）
resetUnitFile(HEAD_SRC.replace(/^\s*implementation\s*$/m, '  procedure DeepBaseContractGateNewPublicProc;\nimplementation'));
expect(0, '④ 兼容：仅新增公开声明 → 不红', () =>
  runGate(['--source', 'worktree', '--root', tmp, '--contract', tmpContract([ENTRY]), '--baseline', tmpBaselineFor(UNIT, cleanSigs)]));

// ⑤ 单元缺失：树里不放该 .pas
fs.rmSync(path.join(tmp, ENTRY.subdir, `${UNIT}.pas`), { force: true });
expect(1, '⑤ 契约声明单元缺失 → 红', () =>
  runGate(['--source', 'worktree', '--root', tmp, '--contract', tmpContract([ENTRY]), '--baseline', tmpBaselineFor(UNIT, cleanSigs)]));

// ⑥ 单元重复：同名两份
resetUnitFile(HEAD_SRC);
fs.mkdirSync(path.join(tmp, 'DupDir'), { recursive: true });
fs.writeFileSync(path.join(tmp, 'DupDir', `${UNIT}.pas`), HEAD_SRC, 'utf8');
expect(1, '⑥ 同名单元两处定义 → 红', () =>
  runGate(['--source', 'worktree', '--root', tmp, '--contract', tmpContract([ENTRY]), '--baseline', tmpBaselineFor(UNIT, cleanSigs)]));
fs.rmSync(path.join(tmp, 'DupDir'), { recursive: true, force: true });

// ⑦ stability 枚举非法 / units 空
expect(2, '⑦a stability 非法枚举 → EXIT=2', () =>
  runGate(['--source', 'worktree', '--root', tmp, '--contract', tmpContract([{ ...ENTRY, stability: 'public' }]), '--baseline', tmpBaselineFor(UNIT, cleanSigs)]));
const emptyP = path.join(tmp, 'empty.json');
fs.writeFileSync(emptyP, JSON.stringify({ units: [] }), 'utf8');
expect(2, '⑦b units 为空 → EXIT=2', () =>
  runGate(['--source', 'worktree', '--root', tmp, '--contract', emptyP, '--baseline', tmpBaselineFor(UNIT, cleanSigs)]));

// ⑧ 契约不可解析 → fail-closed EXIT=3
const badP = path.join(tmp, 'bad.json');
fs.writeFileSync(badP, '{ not json', 'utf8');
expect(3, '⑧ 契约不可解析 → EXIT=3（fail-closed）', () =>
  runGate(['--source', 'worktree', '--root', tmp, '--contract', badP, '--baseline', tmpBaselineFor(UNIT, cleanSigs)]));

// ⑨ 缺字段（无 breaking_change_policy）→ EXIT=2
const noField = { ...ENTRY }; delete noField.breaking_change_policy;
expect(2, '⑨ 契约条目缺字段 → EXIT=2', () =>
  runGate(['--source', 'worktree', '--root', tmp, '--contract', tmpContract([noField]), '--baseline', tmpBaselineFor(UNIT, cleanSigs)]));

fs.rmSync(tmp, { recursive: true, force: true });
console.log(failed ? '\n契约负向样本测试：失败' : '\n契约负向样本测试：全部通过');
process.exit(failed ? 1 : 0);
