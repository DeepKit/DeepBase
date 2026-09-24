// 段5 等值性复算（WO-20260924-AUDIT-甲-D7 段5）：证明 build-gate 的枚举面目录名集已走共享真相源，
// 且接入前后是同一个集合、'Logs' 这项目前仍是承重的（删了就缩面）。脚本内不抄目录名清单。
// 用法：node d7_skip_equivalence.js <接入前的 commit>（在隔离工作树里跑，HEAD 即当前口径）
'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ref = process.argv[2];
if (!/^[0-9a-f]{7,40}$/i.test(ref || '')) {
  console.error('用法：node d7_skip_equivalence.js <接入前的 commit SHA>');
  process.exit(2);
}
const repo = path.resolve(__dirname, '..', '..');
const GATE = '09_工程脚本/build-gate/check_build.js';
const show = (p, at) => execFileSync('git', ['-C', repo, 'show', `${at}:${p}`], { encoding: 'utf8' });

// 改前口径：该门自己的内联字面量
const before = show(GATE, ref).match(/^const SKIP = new Set\(\[([\s\S]*?)\]\);/m);
if (!before) { console.error(`${ref}:${GATE} 里找不到内联 const SKIP 字面量，本脚本的复算前提不成立`); process.exit(2); }
const oldNames = [...before[1].matchAll(/'([^']+)'/g)].map((m) => m[1]);

// 改后口径：工作树里的真实代码路径（HEAD），不是脚本里重算的第二套清单
const gateSrc = fs.readFileSync(path.join(repo, GATE), 'utf8');
const inline = gateSrc.match(/^const SKIP = new Set\(/m);
const wired = gateSrc.match(/^const BUILD_ARTIFACT_DIRS = gateSkipSet\((.*)\);$/m);
const { gateSkipSet, GATE_SKIP_DIRS } = require(path.join(repo, '09_工程脚本/gate-skip.js'));
if (!wired) { console.error('当前 check_build.js 没有 const BUILD_ARTIFACT_DIRS = gateSkipSet(...) 这一行'); process.exit(2); }
// 从代码里读实参，避免在脚本里再写一遍 'Logs'
const extras = [...wired[1].matchAll(/'([^']+)'/g)].map((m) => m[1]);
const now = gateSkipSet(...extras);

const usedAt = [...gateSrc.matchAll(/BUILD_ARTIFACT_DIRS\.has\(/g)].length;
const setEq = (x, y) => x.size === y.size && [...x].every((n) => y.has(n));
const onlyOld = oldNames.filter((n) => !GATE_SKIP_DIRS.includes(n));

const checks = [
  [`当前代码不再持有内联 SKIP 副本（'const SKIP = new Set(' 命中数=0）`, !inline],
  ['改前 13 项集合 == 当前 gateSkipSet 集合（逐位等值，非仅计数相等）', setEq(new Set(oldNames), now)],
  ['集合大小不变', oldNames.length === now.size],
  ['共享 12 项不含本门专属目录（专属项只能来自调用点实参）', GATE_SKIP_DIRS.filter((n) => oldNames.includes(n)).length === GATE_SKIP_DIRS.length],
  [`本门专属项 = 改前清单减去共享口径 = [${onlyOld}]，与代码实参 [${extras}] 一致`, String(onlyOld) === String(extras)],
  ['枚举面接线点数=2（目录遍历 + 未跟踪检测同一集合）', usedAt === 2],
];

console.log(`基准 ref（接入前）= ${ref}`);
console.log(`改前内联清单 ${oldNames.length} 项：${oldNames.join(', ')}`);
console.log(`当前 gateSkipSet(${wired[1].trim()}) 展开 ${now.size} 项：${[...now].sort().join(', ')}`);
for (const [label, ok] of checks) console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}`);
const failed = checks.filter(([, ok]) => !ok).length;
console.log(failed ? `SKIP-EQUIVALENCE: FAIL（${failed} 项不成立）` : 'SKIP-EQUIVALENCE: PASS');
process.exit(failed ? 1 : 0);
