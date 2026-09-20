// B5 三轮：审计取证基线 5f4f9ee 对照 + 剩余字面锚点补齐
const { execSync } = require('child_process');
const REPO = 'D:/_Progs/02Business/DeepBase';
function gitShow(rev, rel) {
  try { return execSync(`git -C ${REPO} show ${rev}:${rel}`, { maxBuffer: 64e6 }).toString('utf8'); }
  catch (e) { return null; }
}
function grepShow(tag, rev, rel, re) {
  console.log(`\n=== ${tag} [${rev}] ${rel} /${re}/`);
  const txt = gitShow(rev, rel);
  if (txt === null) { console.log('NOT-IN-REV'); return; }
  const lines = txt.split(/\r?\n/); const rx = new RegExp(re);
  let n = 0;
  for (let i = 0; i < lines.length && n < 10; i++) if (rx.test(lines[i])) { console.log(`L${i + 1}: ${lines[i].trim()}`); n++; }
  if (!n) console.log('NO-HIT');
}

// 审计时点 5f4f9ee 的原始断言
grepShow('AUDIT-BASE CryptoAES-enum', '5f4f9ee', 'Core/DeepBase.Crypto.AES.pas', 'amECB|amCFB|amOFB|amCTR|TCryptoMode|静默|degrade|降级');
grepShow('AUDIT-BASE CryptoAES-zeroIV', '5f4f9ee', 'Core/DeepBase.Crypto.AES.pas', 'Zero|全零|all-zero|Length\\(FIV\\)|FixedIV');
grepShow('AUDIT-BASE UIA-alwaysTrue', '5f4f9ee', 'Features/DeepBase.UIA.Engine.pas', 'IsMappingIntegrityVerified|Result := True');
grepShow('AUDIT-BASE Updater-remoteAlg', '5f4f9ee', 'Features/DeepBase.Updater.pas', 'SignatureAlgorithm|Algorithm :=|默认|default.*rsa|VerifySignature');
grepShow('AUDIT-BASE KeyManager-save', '5f4f9ee', 'Core/DeepBase.KeyManager.pas', 'WriteAllText|Truncate|Create\\(FStorePath');
grepShow('AUDIT-BASE CDP-903', '5f4f9ee', 'Features/DeepBase.Browser.CDP.pas', 'FreeOnTerminate|REVIEW5-FEAT-009|CreateAnonymousThread');
grepShow('AUDIT-BASE Auth-1618', '5f4f9ee', 'Core/DeepBase.Authorization.pas', 'ThreadCurrentUsers.AddOrSetValue|FThreadCurrentUsers');
grepShow('AUDIT-BASE SenseVoice-143', '5f4f9ee', 'Features/DeepBase.Speech.ASR.SenseVoice.pas', 'Move\\(LList');
grepShow('AUDIT-BASE LogAlert-1131', '5f4f9ee', 'Core/DeepBase.LogAlert.pas', 'FLogBuffer.Add|FMaxBufferSize');
grepShow('AUDIT-BASE LLM-474', '5f4f9ee', 'Core/DeepBase.LLM.pas', "LLMParam\\('Description'");
grepShow('AUDIT-BASE SAReg-61', '5f4f9ee', 'Core/DeepBase.SchemaAdapter.Registry.pas', 'Exit;|for Prefix');
grepShow('AUDIT-BASE AntiTamper-281', '5f4f9ee', 'Features/DeepBase.AntiTamper.pas', '\uFFFD');

// 三轮补漏（当前工作树）
const fs = require('fs');
function g(rep, re) {
  console.log(`\n=== GREP ${rep} /${re}/`);
  try { console.log(execSync(`git -C ${REPO} grep -n -E "${re}" -- ${rep}`, { maxBuffer: 32e6 }).toString('utf8')); }
  catch (e) { console.log('NO-HIT'); }
}
g('Features', 'ParseEntitlement|ParseOrder');
g('Tools/WebService', "'access'|X-CSRF|CSRF");
g('Tools/SeedTool', 'if.*EnableHMAC|EnableHMAC then');
g('Tools/UpdaterHelper', 'VerifyPackage|ExpectedSha256');
g('Core', 'FMaxBufferSize :=|FMaxBufferSize:|MaxBuffer');
g('.', 'function TCloudBackupClient.GetBackupArchivePath');
