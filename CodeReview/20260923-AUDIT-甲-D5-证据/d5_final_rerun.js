// 甲 D5 交付前复算脚本：在隔离工作树 @ 目标 commit 上跑门禁族，原始输出落 D5-10。
// 为什么要在工作树里跑而不是共享树：共享树同时有他角色在途改动（SecureMemory/UBS2 等），
// 门禁红项归因会混进别人的账；工单口径要求判定来自 --detach 工作树 @ 目标 commit。
'use strict';
const { spawnSync } = require('child_process');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const G = '09_工程脚本';
const CMDS = [
  ['共享守卫负向样本（gate-skip / gate-baseline）', [`${G}/test_negative_sample.js`, '--root', ROOT]],
  ['编码门禁', [`${G}/encoding-gate/check_pas_encoding.js`, '--root', ROOT]],
  ['行尾门禁', [`${G}/eol-gate/check_eol.js`, '--root', ROOT]],
  ['证据编码门禁（工作树口径，含本单新建证据件）', [`${G}/evidence-encoding-gate/check_evidence_encoding.js`, '--root', ROOT, '--all-worktree']],
  ['托管拷贝门禁', [`${G}/managed-copy-gate/check_managed_copy.js`, '--root', ROOT]],
  ['构建归属门禁', [`${G}/build-ownership/check_build_ownership.js`, '--root', ROOT]],
  ['编译门禁（判据 6，全量）', [`${G}/build-gate/check_build.js`, '--root', ROOT, '--all']],
];

for (const [title, argv] of CMDS) {
  console.log(`\n########## ${title}\n$ node ${argv.join(' ')}`);
  const r = spawnSync(process.execPath, argv, { cwd: ROOT, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  console.log('EXIT=' + r.status);
  process.stdout.write((r.stdout || '') + (r.stderr || ''));
}
