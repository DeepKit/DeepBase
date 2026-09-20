const { execSync } = require('child_process');
const REPO = 'D:/_Progs/02Business/DeepBase';
function g(pat, path) {
  console.log('=== /' + pat + '/ ' + path);
  try {
    console.log(execSync(`git -C ${REPO} grep -n -E "${pat}" -- ${path}`, { maxBuffer: 32e6 }).toString('utf8').split(/\r?\n/).slice(0, 10).join('\n'));
  } catch (e) { console.log('NO-HIT'); }
}
g('function.*SendCommand', 'Features/DeepBase.Browser.CDP.pas');
g('MinorUnitsToAmount|MinorUnits', 'Features/DeepBase.Commerce');
g('aesECB|aesCFB|aesOFB|aesCTR|TAESMode|aesGCM|aesCBC', 'Core/DeepBase.Crypto.AES.pas');
g('GetIV|IV :=|LIV', 'Core/DeepBase.Crypto.AES.pas');
