// B5 二轮补证：对首轮未命中/需literal确认的锚点定向取证
const { execSync } = require('child_process');
const fs = require('fs');
const REPO = 'D:/_Progs/02Business/DeepBase';
const HEAD_FILES = new Set(['Core/DeepBase.Feedback.pas','Core/DeepBase.MVVM.pas','Features/DeepBase.Browser.CDP.pas','Core/DeepBase.AIErrorHandler.pas','Core/DeepBase.WorkerQueue.pas','Core/DeepBase.Scheduler.pas']);
function getText(rel) {
  if (HEAD_FILES.has(rel)) return execSync(`git -C ${REPO} show HEAD:${rel}`, { maxBuffer: 64e6 }).toString('utf8');
  return fs.readFileSync(`${REPO}/${rel}`, 'utf8');
}
function show(id, rel, range) {
  console.log(`\n=== ${id} | ${rel} L${range}`);
  let txt; try { txt = getText(rel); } catch (e) { console.log('FILE-MISSING'); return; }
  const lines = txt.split(/\r?\n/);
  const [a, b] = range.split('-').map(Number);
  for (let i = a; i <= (b || a) && i <= lines.length; i++) console.log(`L${i}: ${lines[i - 1]}`);
}
function grep(id, rel, re) {
  console.log(`\n=== ${id} | ${rel} /${re}/`);
  let txt; try { txt = getText(rel); } catch (e) { console.log('FILE-MISSING'); return; }
  const lines = txt.split(/\r?\n/); const rx = new RegExp(re);
  let n = 0;
  for (let i = 0; i < lines.length && n < 15; i++) if (rx.test(lines[i])) { console.log(`L${i + 1}: ${lines[i].trim()}`); n++; }
  if (!n) console.log('NO-HIT');
}

show('UIA-IsMappingIntegrity-body', 'Features/DeepBase.UIA.Engine.pas', '454-475');
show('CryptoAES-mode-body', 'Core/DeepBase.Crypto.AES.pas', '395-430');
grep('CryptoAES-mode-enum', 'Core/DeepBase.Crypto.AES.pas', 'amECB|amCFB|amOFB|amCTR|amCBC|amGCM|TCryptoMode');
grep('CryptoAES-IV-head', 'Core/DeepBase.Crypto.AES.pas', 'Prepend|Concat|Header|LZero|Zero IV|all-zero');
grep('External-IsWrite-body', 'Core/DeepBase.External.Types.pas', 'WITH|INSERT|UPDATE|DELETE|DROP|StartsWith|Contains');
grep('LogAlert-BufferClear', 'Core/DeepBase.LogAlert.pas', 'FLogBuffer');
grep('CircuitBreaker-Registry2', 'Core/DeepBase.Resilience.CircuitBreaker.pas', 'Registry');
grep('IBrowserSession-2def', 'FEATURES-GLOB', 'IBrowserSession = interface');
grep('CSRF-middleware-wire', 'Tools/WebService/DeepBase.WebAPI.Core.pas', 'CSRF');
grep('CloudSync-verify', 'Features/DeepBase.CloudSync.pas', 'Verify|Report.*[Ss]uccess|MarkAllSynced|SyncAll|UploadFile');
grep('ParseOrder-global', 'Features/DeepBase.Commerce.SDKGateway.pas', 'Parse|Order|Status');
grep('Entitlement-consume', 'Features/DeepBase.Commerce.pas', 'Consume');
grep('SmartExec-iface-body', 'Features/DeepBase.Desktop.Screen.Click.SmartExecutor.pas', 'begin|0\\.5|for I := 0 to');
grep('ABackupId-literal', 'Features/DeepBase.CloudBackup.pas', 'ABackupId');
grep('NameValuePair-def', 'Features/DeepBase.CloudBackup.pas', 'TNameValuePair');
grep('CLI-SSH-overwrite', 'Tools/CLI/DeepBase.CLI.SSH.pas', 'TFile|WriteAllText|SaveToFile|TStringList|SaveToStream');
grep('SeedTool-HMAC-usage', 'Tools/SeedTool/uBasicProtection.pas', 'EnableHMAC|HMAC');
grep('CliSSH-factory-default', 'Tools/CLI/DeepBase.CLI.SSH.pas', 'returns mock|by default');
show('UpdaterHelper-nosha', 'Tools/UpdaterHelper/UpdaterHelper.Core.pas', '195-215');
grep('AutoUpdate-FMX-verify', 'FMX/DeepBase.FMX.AutoUpdater.pas', 'Verify|Signature|Updater');
show('WPAuth-refresh-check', 'Tools/WebService/DeepBase.WebAPI.Auth.pas', '985-1000');
grep('HBCore-warmgold', 'Core/DeepBase.HB.Core.pas', 'WarmGold|\u6696\u91d1');
grep('HBPalettes-hex', 'Core/DeepBase.HB.Palettes.pas', '\\$[Ff]{2}[0-9A-Fa-f]{4}|Gold');
grep('Schema-init-DEPRECATED', 'sql/tier0-2_init.sql', 'DEPRECATED');
grep('EnsureSchema-code', 'PERSISTENCE-GLOB', 'EnsureSchema');
grep('Commander-threads-any', 'DeepFlow/Source/Roles/DeepFlow.Commander.pas', 'Thread|TTask|Sleep|Queue');
show('ResilTimeout-89-135', 'Core/DeepBase.Resilience.Timeout.pas', '86-135');

// AntiTamper:281 U+FFFD 计数（HEAD 与工作树）
for (const [tag, txt] of [['HEAD', execSync(`git -C ${REPO} show HEAD:Features/DeepBase.AntiTamper.pas`, {maxBuffer:64e6}).toString('utf8')], ['WORKTREE', fs.readFileSync(REPO + '/Features/DeepBase.AntiTamper.pas', 'utf8')]]) {
  const l281 = txt.split(/\r?\n/)[280] || '';
  console.log(`\n=== AntiTamper L281 [${tag}] U+FFFD count: ${(l281.match(/\uFFFD/g) || []).length}`);
}
