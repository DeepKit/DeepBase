const { execSync } = require('child_process');
const REPO = 'D:/_Progs/02Business/DeepBase';
function g(pat, path) {
  console.log('=== /' + pat + '/ ' + path);
  try {
    console.log(execSync(`git -C ${REPO} grep -n -E "${pat}" -- ${path}`, { maxBuffer: 32e6 }).toString('utf8').split(/\r?\n/).slice(0, 12).join('\n'));
  } catch (e) { console.log('NO-HIT'); }
}
g('VerifyBackup', 'Features');
g('TNameValuePair[ ]*=', 'Features');
g('PluginManager', 'Core');
g('implementation', 'Features/DeepBase.Desktop.Screen.Click.SmartExecutor.pas');
g('0\\.5', 'Features/DeepBase.Desktop.Screen.Click');
