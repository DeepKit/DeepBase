// DeepBase 托管类型非托管拷贝门禁（WO-20260919-AUDIT-乙-R2 E7 / 审计 T4 家族）
// 背景：对含 string/动态数组等托管字段的 record 或数组使用 Move/FillChar 裸内存
// 拷贝会绕过引用计数，释放阶段 double-free/悬垂（T4.1 CloudBackup headers、
// T4.2 SenseVoice tokens 均为此类真实缺陷）。本门禁立法禁止新增此类用法。
// 规则：
//  M1 硬规则（不可 baseline 豁免）：内存 Move( 调用的大小参数按行启发式命中
//     托管元素类型（string / TArray< / TStringDynArray / TNetHeaders 等）。
//  M2 基线规则：逐文件统计裸内存原语（非限定 Move( 与 System.Move( 与 FillChar(）
//     调用次数；新文件出现调用或既有文件计数上升即违规，需评审后显式更新基线。
// 扫描根与排除集（H10 口径）：仓库根，SKIP 目录集与行尾门禁一致
//     （.git/.tmp/.claude/BuildOutput/DCUOutput/bin/dcu/TestResults 等）。
// 用法: node check_managed_copy.js [--root <dir>] [--baseline <file>] [--emit-baseline] [--allow-narrow-root]
// 退出码：0 通过；1 违规；2 基线不可信（WO-20260923-AUDIT-乙-D5 §一-3，见 gate-baseline.js）；
//        3 参数不合法 / 扫描自身失败（root 不可读）——fail-closed，绝不放行。
const fs = require('fs');
const path = require('path');
const { parseGateArgs } = require('../gate-args');
const { gateSkipSet } = require('../gate-skip');
const { loadGateBaseline } = require('../gate-baseline');
const { guardedEmitBaseline } = require('../gate-emit-guard');

// 参数解析收敛到 09_工程脚本/gate-args.js 单一实现（同 eol/build-ownership；此前的私有 arg()
// 对未知参数静默忽略、也不支持 = 取值，是 P2/D7 已收口过的同型裂缝，本门当时漏在外面）。
{
  const opts = parseGateArgs(process.argv.slice(2), {
    label: '托管拷贝',
    root: path.join(__dirname, '../..'),
    baseline: path.join(__dirname, 'managed_copy_baseline.json'),
    extra: ['emit-baseline', 'allow-narrow-root'],
  });
  if (opts.flags.has('help')) {
    console.log('用法: node check_managed_copy.js [--root <dir>] [--baseline <file>] [--emit-baseline] [--allow-narrow-root]');
    process.exit(0);
  }
  var ROOT = opts.root;
  var BASELINE_P = opts.baseline;
  var EMIT = opts.flags.has('emit-baseline');
  var ALLOW_NARROW = opts.flags.has('allow-narrow-root');
}
const REPO_ROOT = path.resolve(path.join(__dirname, '../..'));
const SKIP = gateSkipSet();

// 非限定 Move( 与 System.Move(；排除 TFile.Move 等文件方法（前随 '.'）
const MEM_MOVE = /(?<![\w.$])(?:System\.)?Move\s*\(/g;
const FILL_CHAR = /(?<![\w.$])FillChar\s*\(/g;
// M1：Move 尺寸参数命中托管元素类型（单行启发式；跨行由 M2 基线兜底）
const MANAGED_SIZEOF = /SizeOf\s*\(\s*(string|String|TArray\s*<|TStringDynArray|TNetHeaders|TBytes_dyn|WideString|AnsiString|UnicodeString|RawByteString)\b/;

function walk(dir, out) {
  let ents;
  // fail-closed：readdir 失败不得静默返回空数组（「没扫到」不能伪装成「扫过且干净」），
  // 否则写基线的扫描面会静默缩水——正是写入守卫要在源头兜住的形态。
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) {
    console.error(`托管拷贝门禁无法读取目录: ${dir} (${e.message})`);
    process.exit(3);
  }
  for (const e of ents) {
    if (SKIP.has(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.isFile() && path.extname(e.name).toLowerCase() === '.pas') out.push(p);
  }
  return out;
}

function countCalls(text, re) {
  re.lastIndex = 0;
  let n = 0;
  while (re.exec(text) !== null) n++;
  return n;
}

const files = walk(ROOT, []).sort();
// 空扫描即失败：仓库内必有 .pas；扫到 0 个说明 root 指错或 SKIP 规则吃掉了源码树
// （与其余四道门同口径；对 --emit-baseline 而言这同时是写入守卫一的扫描面自证）。
if (files.length === 0) {
  console.error(`托管拷贝门禁失败：扫描 0 个 .pas（root=${ROOT}）。根因通常是 --root 指错目录；已按 fail-closed 拒绝放行。`);
  process.exit(3);
}
const findings = []; // { rel, line, rule, detail }
const counts = {};   // rel -> { move, fillchar }

for (const f of files) {
  const rel = path.relative(ROOT, f).replace(/\\/g, '/');
  let text;
  // 读取失败归「扫描自身失败」（EXIT=3）而非「违规」（EXIT=1）：环境问题不得冒领分诊问题。
  try { text = fs.readFileSync(f, 'latin1'); } catch (e) { // 只匹配 ASCII 序列，编码无关
    console.error(`托管拷贝门禁无法读取文件: ${rel} (${e.message})`);
    process.exit(3);
  }
  const moveN = countCalls(text, MEM_MOVE);
  const fillN = countCalls(text, FILL_CHAR);
  if (moveN || fillN) counts[rel] = { move: moveN, fillchar: fillN };
  if (moveN) {
    const lines = text.split(/\r?\n/);
    for (let i = 0; i < lines.length; i++) {
      MEM_MOVE.lastIndex = 0;
      if (MEM_MOVE.test(lines[i]) && MANAGED_SIZEOF.test(lines[i])) {
        findings.push({ rel, line: i + 1, rule: 'M1', detail: 'Move 尺寸参数含托管元素类型（禁止裸内存拷贝，改逐字段/逐元素赋值）' });
      }
    }
  }
}

if (EMIT) {
  const out = {
    _comment: 'DeepBase 裸内存拷贝存量基线 (WO-20260919-AUDIT-乙-R2 E7)，禁止新增文件或将计数上升；变更须评审后显式更新',
    files: counts
  };
  const cmp = guardedEmitBaseline({
    label: '托管拷贝', baselinePath: BASELINE_P, root: ROOT, repoRoot: REPO_ROOT,
    allowNarrowRoot: ALLOW_NARROW, scanCount: files.length,
    entryKeys: ['files'], newBaseline: out,
  });
  console.log('托管拷贝基线生成完成：' + Object.keys(counts).length + ' 个文件含 Move/FillChar -> ' + BASELINE_P + (cmp.skipped ? '（首建）' : `（只减不增：条目 -${cmp.removed} / 计数下调 ${cmp.decreased}）`));
  process.exit(0);
}

// 基线只在检查路径被读取，故放在 EMIT 之后：`--emit-baseline` 是修复存量的动作；
// 守写入动作是 gate-emit-guard.js（窄根自证 / 只减不增 / 写前 .bak），守读取侧是 gate-baseline.js。
const baseline = loadGateBaseline({
  file: BASELINE_P, label: '托管拷贝',
  keys: { files: 'object' },
});
const baseFiles = baseline.files;
const violations = findings.map(v => 'M1 Move/托管类型裸拷贝: ' + v.rel + ':' + v.line);

for (const rel of Object.keys(counts).sort()) {
  const c = counts[rel];
  const b = baseFiles[rel] || { move: 0, fillchar: 0 };
  if (c.move > (b.move || 0)) {
    violations.push('M2 未评审的裸内存 Move 调用 (当前 ' + c.move + ' > 基线 ' + (b.move || 0) + '): ' + rel);
  }
  if (c.fillchar > (b.fillchar || 0)) {
    violations.push('M2 未评审的 FillChar 内存操作 (当前 ' + c.fillchar + ' > 基线 ' + (b.fillchar || 0) + '): ' + rel);
  }
}

if (violations.length) {
  console.error('托管拷贝门禁失败，违规 ' + violations.length + ' 项:');
  violations.slice(0, 50).forEach(v => console.error('  ' + v));
  process.exit(1);
}
console.log('托管拷贝门禁通过：检查了 ' + files.length + ' 个 .pas 文件（M1 硬规则 + M2 基线 ' + Object.keys(baseFiles).length + ' 项豁免存量）');
