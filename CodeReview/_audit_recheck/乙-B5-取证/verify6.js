// B5 六轮：残余缺口探针
const { execSync } = require('child_process');
const REPO = 'D:/_Progs/02Business/DeepBase';
function g(tag, cmd) {
  console.log('\n=== ' + tag);
  try { console.log(execSync(cmd, { maxBuffer: 32e6, cwd: REPO }).toString('utf8')); }
  catch (e) { console.log('NO-HIT'); }
}
// 1) IBrowserSession 第二定义（GUID CDEF3456）
g('IBrowserSession-defs', 'git grep -n "IBrowserSession = interface" -- "*.pas"');
g('GUID-CDEF3456', 'git grep -n "CDEF3456" -- "*.pas"');
// 2) EnsureSchema 落点文件清单
g('EnsureSchema-files', 'git grep -l "EnsureSchema" -- "*.pas"');
// 3) LLMChatFrame VCL+FMX 线程锚点
g('VCL-LLMChatFrame-thread', 'git grep -n -E "TThread|FreeOnTerminate|TTask" -- "VCL/DeepBase.VCL.LLMChatFrame.pas"');
g('FMX-LLMChatFrame-thread', 'git grep -n -E "TThread|FreeOnTerminate|TTask" -- "FMX/DeepBase.FMX.LLMChatFrame.pas"');
// 4) AutoUpdater 线程锚点（T3 点名）
g('VCL-AutoUpdater-thread', 'git grep -n -E "TThread|FreeOnTerminate|TTask" -- "VCL/DeepBase.VCL.AutoUpdater.pas"');
// 5) 旧轨同名类定义位置
g('TDeepBasePluginManager-def', 'git grep -n "TDeepBasePluginManager = class" -- "*.pas"');
// 6) sql 文件实名与 DEPRECATED
g('sql-files', 'git ls-files -- sql');
g('sql-L2', 'git grep -n "DEPRECATED" -- sql');
// 7) 审计时点 AntiTamper L281 行内 U+FFFD 计数
const fs = require('fs');
const raw = execSync(`git -C ${REPO} show 5f4f9ee:Features/DeepBase.AntiTamper.pas`, { maxBuffer: 32e6, encoding: 'buffer' });
const txt = raw.toString('utf8');
const line = txt.split(/\r?\n/)[280];
const cnt = (line.match(/\uFFFD/g) || []).length;
console.log('\n=== 5f4f9ee AntiTamper L281 U+FFFD count: ' + cnt);
