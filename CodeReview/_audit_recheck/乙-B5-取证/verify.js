// B5 锚点核验取证：对每个锚点输出 HEAD 基线的字面行内容与符号实测行号
const { execSync } = require('child_process');
const fs = require('fs');
const REPO = 'D:/_Progs/02Business/DeepBase';

// B4 已改文件必须用 git HEAD 基线核验（工作树已含乙改造）
const HEAD_FILES = new Set([
  'Core/DeepBase.Feedback.pas', 'Core/DeepBase.MVVM.pas', 'Features/DeepBase.Browser.CDP.pas',
  'Core/DeepBase.AIErrorHandler.pas', 'Core/DeepBase.WorkerQueue.pas', 'Core/DeepBase.Scheduler.pas',
]);

function getText(rel) {
  if (HEAD_FILES.has(rel)) {
    return execSync(`git -C ${REPO} show HEAD:${rel}`, { maxBuffer: 64e6 }).toString('utf8');
  }
  return fs.readFileSync(`${REPO}/${rel}`, 'utf8');
}

function report(id, rel, range, symRe) {
  console.log(`\n=== ${id} | ${rel}${HEAD_FILES.has(rel) ? ' [HEAD基线]' : ''}`);
  let txt;
  try { txt = getText(rel); } catch (e) { console.log('FILE-MISSING: ' + e.message.split('\n')[0]); return; }
  const lines = txt.split(/\r?\n/);
  if (range) {
    const [a, b] = range.split('-').map(Number);
    for (let i = a; i <= (b || a) && i <= lines.length; i++) console.log(`L${i}: ${lines[i - 1]}`);
  }
  if (symRe) {
    const re = new RegExp(symRe);
    let hits = 0;
    for (let i = 0; i < lines.length && hits < 12; i++) {
      if (re.test(lines[i])) { console.log(`  SYM@L${i + 1}: ${lines[i].trim()}`); hits++; }
    }
    if (hits === 0) console.log('  SYM-NOT-FOUND: ' + symRe);
  }
}

// ---- T1 ----
report('T1-1a', 'Features/DeepBase.Updater.pas', null, 'Verify|Signature|算法|Algorithm|key_id|trusted');
report('T1-1b', 'VCL/DeepBase.VCL.AutoUpdater.pas', null, 'Verify|Signature');
report('T1-2', 'Features/DeepBase.UIA.Engine.pas', '449-452', 'IsMappingIntegrityVerified');
report('T1-3a', 'Governance/DeepBase.Governance.ConfigRegistrar.pas', null, 'Verify|Signature|sign');
report('T1-3b', 'Governance/DeepBase.Governance.ReviewQueue.pas', null, 'Verify|Signature|sign');
report('T1-3c', 'Governance/DeepBase.Governance.ActionExecutor.pas', null, 'Verify|Approv|guard|Gate');
report('T1-4', 'Core/DeepBase.External.Types.pas', null, 'IsWriteStatement');
report('T1-5', 'Features/DeepBase.Net.pas', null, 'DEEPBASE.*DISABLE|SSRF|IsPrivate|environ|GetEnv');
report('T1-6a', 'Tools/UpdaterHelper/UpdaterHelper.Core.pas', null, 'sha256|SHA256|--sha');
report('T1-6b', 'Tools/SeedTool/uSeedMain.pas', null, 'EnableHMAC|HMAC');

// ---- T2 ----
report('T2-1a', 'Core/DeepBase.Crypto.AES.pas', null, 'ecb|cfb|ofb|ctr|cbc|TCryptoMode|mode');
report('T2-1b', 'Core/DeepBase.Crypto.AES.pas', null, 'IV');
report('T2-2', 'Core/DeepBase.Crypto.Hash.pas', '474-532', 'VerifyPassword|Iterations|algorithm');
report('T2-3', 'Core/DeepBase.Crypto.PBKDF2.pas', '70-88', null);
report('T2-4', 'Core/DeepBase.Security.pas', '299-340', 'machine|USER|Derive');
report('T2-5', 'Core/DeepBase.Services.Protection.pas', null, 'CBC|HMAC|SHA256|PBKDF2|Derive');

// ---- T3 ----
report('T3-1', 'Features/DeepBase.Browser.CDP.pas', '903-912', 'FreeOnTerminate|WaitFor|WaitForSelector|FDetached');
report('T3-1b', 'Features/DeepBase.Browser.CDP.pas', '995-1011', 'FreeOnTerminate|destructor|Destroy');
report('T3-2', 'Core/DeepBase.Pool.pas', '1066-1083', null);
report('T3-2b', 'Core/DeepBase.ObjectPool.pas', '1066-1083', 'TThread|FreeOnTerminate|StartThread');
report('T3-3', 'Core/DeepBase.Feedback.pas', null, 'TThread\\.|FreeOnTerminate|CreateThread');
report('T3-4', 'Core/DeepBase.MVVM.pas', null, 'TTask|Run\\(|FTask');
report('T3-5', 'DeepFlow/Source/Roles/DeepFlow.Commander.pas', '349-363', 'TThread|Queue|Sleep');
report('T3-6', 'Features/DeepBase.IntentClarification.LLMResilience.pas', null, 'LCtx\\s*:=\\s*nil|LCtx');
report('T3-6b', 'Features/DeepBase.IntentClarification.LLMResilience.pas', '326-330', null);
report('T3-6c', 'Features/DeepBase.IntentClarification.LLMResilience.pas', '449-453', null);
report('T3-7', 'Core/DeepBase.Resilience.Timeout.pas', null, 'Free|Lock|TCriticalSection|finally');
report('T3-8', 'Core/DeepBase.AIErrorHandler.pas', '348-377', 'TThread|MessageDlg|Terminate|SafeRun');
report('T3-8b', 'Core/DeepBase.AIErrorHandler.pas', '455-460', 'SafeRun');
report('T3-9', 'Core/DeepBase.Reflection.pas', null, 'finalization|Destroy|Finalize');
report('T3-10', 'Core/DeepBase.External.Types.pas', null, 'finalization');
report('T3-11', 'Features/DeepBase.Browser.Engine.WebView2.pas', null, 'finalization|TThread');

// ---- T4 ----
report('T4-1', 'Features/DeepBase.CloudBackup.pas', null, 'Move\\(|FillChar|System\\.Move');
report('T4-2', 'Features/DeepBase.CloudSync.pas', null, 'Move\\(|System\\.Move');
report('T4-3', 'Features/DeepBase.Speech.ASR.SenseVoice.pas', '140-146', 'Move|FillChar|TByte');
report('T4-4', 'Core/DeepBase.Compression.pas', null, 'Move\\(|System\\.Move');
report('T4-5', 'Core/DeepBase.ObjectPool.pas', null, 'Move\\(|System\\.Move');

// ---- T5 ----
report('T5-1', 'Core/DeepBase.Plugins.Manager.pas', null, 'PChar|GetProcAddress');
report('T5-2', 'Features/DeepBase.Desktop.Screen.Click.SmartExecutor.pas', null, 'function.*begin|interface|0\\.5');
report('T5-3', 'Features/DeepBase.Browser.Engine.WebView2.pas', null, 'USE_WEBVIEW2');

// ---- T6 ----
report('T6-1', 'Features/DeepBase.Browser.Types.pas', null, 'IBrowserSession\\s*=\\s*interface|\\{[0-9A-F-]+\\}');
report('T6-1b', 'Features/DeepBase.Browser.CDP.Adapter.pas', null, 'IBrowserSession|SendCommand');
report('T6-2', 'Core/DeepBase.Resilience.pas', null, 'TCircuitBreaker|Registry');
report('T6-3', 'Core/DeepBase.HB.Palettes.pas', null, 'WarmGold|暖金|\\$[0-9A-Fa-f]{6}');
report('T6-4', 'Core/DeepBase.SchemaAdapter.Registry.pas', null, 'RegisterAdapter|Schema');

// ---- T7 ----
report('T7-1', 'Core/DeepBase.LogAlert.pas', '1131-1140', 'Add|Clear|Count');
report('T7-2', 'Features/DeepBase.CloudSync.pas', null, 'VerifyBackup|同步成功|UploadAll|MarkSynced');
report('T7-3', 'Features/DeepBase.Speech.ASR.SAPI.pas', null, 'Success|Text');
report('T7-4', 'Features/DeepBase.Commerce.JsonUtil.pas', null, 'cosRefunded|unknown|default');
report('T7-5', 'Features/DeepBase.Commerce.PaymentBridge.pas', null, 'ParseOrder|ParseEntitlement');
report('T7-6', 'Core/DeepBase.LLM.pas', '470-500', 'SaveConfig|Description');
report('T7-7', 'Tools/CLI/DeepBase.CLI.SSH.pas', '445-460', 'mock|Mock|WriteFile|SaveFile|本地');
report('T7-8', 'Core/DeepBase.SchemaAdapter.Registry.pas', '61-74', 'Exit|Continue|for ');

// ---- T8 ----
report('T8-1', 'Features/DeepBase.AntiTamper.pas', '278-284', null);

// ---- Top20 独有 ----
report('TOP3', 'Core/DeepBase.KeyManager.pas', '742-784', 'Truncate|Save|Write|Atom');
report('TOP6', 'Features/DeepBase.CloudBackup.pas', null, 'ABackupId|Restore|Delete|Path');
report('TOP8', 'Features/DeepBase.Commerce.SDKGateway.pas', null, 'Consume|Entitlement|WHERE|rows');
report('TOP9', 'Core/DeepBase.Authorization.pas', '1614-1622', 'ThreadID|TUser|Dictionary');
report('TOP12', 'Core/DeepBase.UITest.FmxProbe.pas', null, 'Authenticate|Token|Password|Bind|Port');
report('TOP16a', 'Core/DeepBase.Template.pas', '2080-2090', 'Include|File|Read');
report('TOP16b', 'Core/DeepBase.Reflection.pas', '397-405', 'context|RttiContext|TRttiContext');
report('TOP18', 'Tools/WebService/DeepBase.WebAPI.Auth.pas', null, 'CSRF|refresh|access|state');
report('TOP20', 'Core/DeepBase.Plugins.Contracts.pas', null, 'interface');
