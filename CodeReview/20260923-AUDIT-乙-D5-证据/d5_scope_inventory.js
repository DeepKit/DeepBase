// WO-20260923-AUDIT-乙-D5 §一-1 取证脚本：枚举 CodeReview/** 里「改前不被证据门禁扫描」的证据件。
//
// 改后清单直接问门禁自身（--list-files），不在本脚本里二次实现排除规则——那正是本单要消灭的
// 「口径抄成几份、各自漂移」；改前口径（扩展名白名单 .txt/.log/.csv/.xml）是本单要闭合的历史事实，
// 只能照 git show HEAD:09_工程脚本/evidence-encoding-gate/check_evidence_encoding.js 的旧源码复述。
//
// 本脚本自身的落点也是判据：它是 CodeReview/** 下的 .js，改前不在任何门禁的扫描面内，改后被证据门禁扫。
// 用法: node "CodeReview/20260923-AUDIT-乙-D5-证据/d5_scope_inventory.js"   （在仓库根执行）
const { execFileSync } = require('child_process');
const path = require('path');

const GATE = path.join('09_工程脚本', 'evidence-encoding-gate', 'check_evidence_encoding.js');
// 其余门禁的纳入扩展名（面/规则映射见 09_工程脚本/README-门禁覆盖面.md §一，此处只取扩展名集合）
const OTHER_GATE_EXT = new Set(['.pas', '.dpr', '.dpk', '.dfm', '.fmx', '.md', '.sql', '.dproj']);
const OLD_WHITELIST = /\.(txt|log|csv|xml)$/i; // 改前：证据门禁 EXT 白名单

const git = (args) => execFileSync('git', ['-c', 'core.quotepath=false', ...args],
  { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
const tracked = git(['ls-files', '-z', '--', 'CodeReview']).split('\0').filter(Boolean);
const after = execFileSync(process.execPath, [GATE, '--list-files'],
  { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }).split('\n').filter(Boolean);

const afterSet = new Set(after);
const before = tracked.filter(f => OLD_WHITELIST.test(f));
const gained = tracked.filter(f => !before.includes(f) && afterSet.has(f));
const lost = before.filter(f => !afterSet.has(f));
const ext = f => (path.posix.extname(f) || '(无扩展)').toLowerCase();

console.log(`已跟踪 CodeReview 文件            : ${tracked.length}`);
console.log(`改前（白名单口径）进门禁          : ${before.length}`);
console.log(`改后（门禁 --list-files 实测）    : ${after.length}`);
console.log(`净增                              : ${gained.length}（改前该扫却扫不到）`);
console.log(`改前在扫描面、改后反而掉出        : ${lost.length}${lost.length ? '\n  ' + lost.join('\n  ') : '（0，扩面只增不减）'}`);

const byExt = {};
for (const f of gained) (byExt[ext(f)] = byExt[ext(f)] || []).push(f);
console.log('\n净增清单按扩展名（并标注改前是否被其他门禁覆盖）:');
for (const [e, list] of Object.entries(byExt).sort((a, b) => b[1].length - a[1].length)) {
  console.log(`  ${e} × ${list.length} —— 改前${OTHER_GATE_EXT.has(e) ? '有编码/行尾面兜底（但 NUL/E2 无人查）' : '完全不被任何门禁扫描'}`);
  list.forEach(f => console.log('    ' + f));
}
