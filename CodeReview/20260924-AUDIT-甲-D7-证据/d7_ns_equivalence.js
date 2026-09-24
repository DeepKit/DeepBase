// 段4 等值性复算（WO-20260924-AUDIT-甲-D7 判据④）：证明「外置」只换了清单的来源，没换内容。
// 用法：node d7_ns_equivalence.js <外置前的 commit>
// 三个取值各取自其唯一真相源（改前的门禁代码 / 改后的声明文件 / 仓内既有构建脚本），脚本内不抄清单。
'use strict';

const path = require('path');
const { execFileSync } = require('child_process');

const ref = process.argv[2];
if (!/^[0-9a-f]{7,40}$/i.test(ref || '')) {
  console.error('用法：node d7_ns_equivalence.js <外置前的 commit SHA>');
  process.exit(2);
}
const repo = path.resolve(__dirname, '..', '..');
const GATE = '09_工程脚本/build-gate/check_build.js';
const CONTRACT = '09_工程脚本/build-gate/contracts/命名空间声明.txt';
const PS1 = 'Scripts/compile_packages_win64.ps1';

const show = (p) => execFileSync('git', ['-C', repo, 'show', `${ref}:${p}`], { encoding: 'utf8' });
const work = (p) => execFileSync('git', ['-C', repo, 'show', `HEAD:${p}`], { encoding: 'utf8' });

const before = show(GATE).match(/^const DEFAULT_NS = '([^']+)';$/m);
if (!before) { console.error(`改前代码里找不到 DEFAULT_NS 常量：${ref}:${GATE}`); process.exit(2); }

const after = work(CONTRACT).split(/\r?\n/).filter((l) => l.startsWith('default='));
if (after.length !== 1) { console.error(`声明文件的 default 行应恰好 1 行，实际 ${after.length} 行`); process.exit(2); }

const ps = work(PS1).match(/^\$NS = "([^"]+)"$/m);
if (!ps) { console.error(`找不到 ${PS1} 的 $NS`); process.exit(2); }

const split = (s) => s.split(';').map((x) => x.trim()).filter(Boolean);
const [b, a, p] = [before[1], after[0].slice('default='.length), ps[1]];
const setDiff = (x, y) => split(x).filter((n) => !split(y).includes(n));
const eq = (x, y) => x === y;

const checks = [
  ['改前(DEFAULT_NS@' + ref.slice(0, 7) + ') 逐位 == 改后(default 行)', eq(b, a)],
  ['改后(default 行) 逐位 == Scripts/compile_packages_win64.ps1 $NS', eq(a, p)],
  ['项数不变', split(b).length === split(a).length],
  ['顺序逐项不变', split(b).join('|') === split(a).join('|')],
  ['相对改前新增项为空', setDiff(a, b).length === 0],
  ['相对改前删除项为空', setDiff(b, a).length === 0],
];

console.log(`基准 ref（外置前）= ${ref}`);
console.log(`改前 DEFAULT_NS 长度=${b.length} 项数=${split(b).length}`);
console.log(`改后 default  行长度=${a.length} 项数=${split(a).length}`);
console.log(`ps1  $NS      长度=${p.length} 项数=${split(p).length}`);
for (const [label, ok] of checks) console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}`);
const failed = checks.filter(([, ok]) => !ok).length;
console.log(failed ? `NS-EQUIVALENCE: FAIL（${failed} 项不成立）` : 'NS-EQUIVALENCE: PASS');
process.exit(failed ? 1 : 0);
