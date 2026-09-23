// 交付前门禁族复跑原始输出（WO-20260923-AUDIT-乙-D5 交付物③的绿跑部分）
// 用 node 而非 PowerShell 落盘：`>` 重定向在 PowerShell 下默认写 UTF-16LE，会把证据本身
// 变成门禁要拦的形态（H18）。本脚本用 fs.writeFileSync(..., 'utf8') 保证 UTF-8。
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const REPO = path.resolve(__dirname, '../..');
const S = p => path.join(REPO, '09_工程脚本', p);

const RUNS = [
  ['共享守卫负向样本（gate-skip / gate-baseline）', [S('test_negative_sample.js'), []]],
  ['编码门禁', [S('encoding-gate/check_pas_encoding.js'), ['--root', '.']]],
  ['行尾门禁', [S('eol-gate/check_eol.js'), ['--root', '.']]],
  ['证据编码门禁（已跟踪口径）', [S('evidence-encoding-gate/check_evidence_encoding.js'), []]],
  ['证据编码门禁（工作树口径，含本单新建证据件）', [S('evidence-encoding-gate/check_evidence_encoding.js'), ['--all-worktree']]],
  ['托管拷贝门禁', [S('managed-copy-gate/check_managed_copy.js'), ['--root', '.']]],
  ['构建归属门禁', [S('build-ownership/check_build_ownership.js'), ['--root', '.']]],
];

let out = `WO-20260923-AUDIT-乙-D5 交付前门禁族复跑（原始输出）\n取证时刻: ${new Date().toISOString()}   HEAD: ${execFileSync('git', ['-C', REPO, 'rev-parse', '--short', 'HEAD'], { encoding: 'utf8' }).trim()}\n复算命令: node CodeReview/20260923-AUDIT-乙-D5-证据/d5_final_rerun.js\n说明: 托管拷贝/构建归属两道门在开工前即为红（存量基线外违规），判据 6 要求的是「违规行逐行与开工前一致」，非本次转绿；详见 双树diff-五道门.txt。\n${'='.repeat(78)}\n`;
for (const [name, [script, args]] of RUNS) {
  let code = 0, text = '';
  try {
    text = execFileSync(process.execPath, [script, ...args], { cwd: REPO, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, stdio: 'pipe' });
  } catch (e) {
    code = e.status === undefined ? -1 : e.status;
    text = (e.stdout || '') + (e.stderr || '');
  }
  out += `\n########## ${name}\n$ node ${path.relative(REPO, script).replace(/\\/g, '/')} ${args.join(' ')}\nEXIT=${code}\n${text.replace(/\r\n/g, '\n')}`;
}
fs.writeFileSync(__dirname + '/交付前五门复跑.txt', out, 'utf8');
console.log('written 交付前五门复跑.txt');
