// B5 七轮：Desktop.Screen.Click 三件套 interface 段体判定 + 121/0.5 字面
const { execSync } = require('child_process');
const REPO = 'D:/_Progs/02Business/DeepBase';
function g(tag, cmd) {
  console.log('\n=== ' + tag);
  try { console.log(execSync(cmd, { maxBuffer: 32e6, cwd: REPO }).toString('utf8')); }
  catch (e) { console.log('NO-HIT'); }
}
const files = [
  'Features/DeepBase.Desktop.Screen.Click.DPIMapper.pas',
  'Features/DeepBase.Desktop.Screen.Click.RegionLocator.pas',
  'Features/DeepBase.Desktop.Screen.Click.SmartExecutor.pas',
];
for (const f of files) {
  g('impl-line ' + f, `git grep -n "^implementation" -- ${f}`);
  g('begin-before-impl? first-begin ' + f, `git grep -n "^begin" -- ${f}`);
}
g('121-fanout', 'git grep -n -E "121" -- "Features/DeepBase.Desktop.Screen.Click"');
g('score-0.5', 'git grep -n -E "0\\.5" -- "Features/DeepBase.Desktop.Screen.Click.*"');
g('placeholder', 'git grep -n -E -i "placeholder|占位|TODO|not implemented|未实现" -- "Features/DeepBase.Desktop.Screen.Click.*"');
