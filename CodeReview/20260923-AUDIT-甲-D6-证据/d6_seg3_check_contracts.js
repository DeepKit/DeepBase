// T0/T1/T2 契约面机械重派生校验（WO-20260923-AUDIT-甲-D6 段3）
//
// 为什么要有这个件：T1 的语义是「全部已跟踪 .dpr − T0 − T2」的机械差集。差集一旦靠手抄，
// 「把某个红项从 T1 拿掉」就会伪装成「重派生的结果」——数字下降变成视线转移。故按门禁自己的
// 解析口径（check_build.js readManifest：# 起注释、整面选择子、路径须已跟踪）复算一遍并逐条比对。
'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const SELECTORS = new Map([['all-dpr', 'dpr'], ['all-dpk', 'dpk']]);

function repoRoot() {
  let dir = __dirname;
  for (;;) {
    if (fs.existsSync(path.join(dir, '.git'))) return dir;
    const up = path.dirname(dir);
    if (up === dir) throw new Error('找不到仓根（.git）');
    dir = up;
  }
}

const ROOT = repoRoot();
const CONTRACTS = path.join(ROOT, '09_工程脚本', 'build-gate', 'contracts');

function tracked(key) {
  const r = spawnSync('git', ['-c', 'core.quotePath=false', 'ls-files', '-z', '--', `*.${key}`],
    { cwd: ROOT, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  if (r.status !== 0) throw new Error(`git ls-files *.${key} EXIT=${r.status}`);
  return r.stdout.split('\0').filter(Boolean).sort();
}

// 与 check_build.js readManifest 同构：行内 # 之后一并剥掉，选择子展开为整面已跟踪清单。
function faceLines(rel, all) {
  const abs = path.join(CONTRACTS, rel);
  if (!fs.existsSync(abs)) throw new Error(`清单文件不存在：${rel}`);
  const out = [];
  for (const raw of fs.readFileSync(abs, 'utf8').split(/\r?\n/)) {
    const line = raw.replace(/#.*$/, '').trim();
    if (!line) continue;
    const sel = SELECTORS.get(line.toLowerCase());
    if (sel) out.push(...all[sel]);
    else out.push(line.split(path.sep).join('/'));
  }
  return out;
}

const all = { dpr: tracked('dpr'), dpk: tracked('dpk') };
const t0 = faceLines('T0-生产契约面.txt', all);
const t1 = faceLines('T1-观测面.txt', all);
const t2 = faceLines('T2-待定面.txt', all);

const t0set = new Set(t0);
const t2set = new Set(t2);
const expectedT1 = all.dpr.filter(p => !t0set.has(p) && !t2set.has(p));

const missing = expectedT1.filter(p => !t1.includes(p));
const extra = t1.filter(p => !expectedT1.includes(p));
const unknown = [...t1, ...t2].filter(p => !all.dpr.includes(p) && !all.dpk.includes(p));

console.log(`tracked .dpr=${all.dpr.length}  tracked .dpk=${all.dpk.length}`);
console.log(`T0 展开=${t0.length}  T1 在册=${t1.length}  T2 在册=${t2.length}`);
console.log(`期望 T1（= 全部 .dpr − T0 − T2）=${expectedT1.length}`);
console.log(`set_equal=${missing.length === 0 && extra.length === 0}  order_equal=${JSON.stringify(expectedT1) === JSON.stringify(t1)}`);
console.log(`T1 缺（应进未进）=${JSON.stringify(missing)}`);
console.log(`T1 多（不该在却在）=${JSON.stringify(extra)}`);
console.log(`清单里指向未跟踪文件=${JSON.stringify(unknown)}`);
console.log(`DoQryDemo 仍在 T1=${t1.some(p => p.includes('DoQryDemo'))}  PageDriverSmoke 在面=${t1.some(p => p.includes('PageDriverSmoke'))}`);
process.exit(missing.length || extra.length || unknown.length ? 1 : 0);
