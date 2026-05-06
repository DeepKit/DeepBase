param(
  [Parameter(Mandatory = $true)]
  [string]$DatabasePath,

  [string]$SqliteExe = "sqlite3",

  [switch]$MigrateLLMApiKeys,

  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($env:OS -ne "Windows_NT") {
  throw "This migration uses Windows Credential Manager and must run on Windows."
}

if (-not (Test-Path -LiteralPath $DatabasePath)) {
  throw "Database not found: $DatabasePath"
}

Add-Type -TypeDefinition @"
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class UniBaseCredMan {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct CREDENTIAL {
    public UInt32 Flags;
    public UInt32 Type;
    public string TargetName;
    public string Comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
    public UInt32 CredentialBlobSize;
    public IntPtr CredentialBlob;
    public UInt32 Persist;
    public UInt32 AttributeCount;
    public IntPtr Attributes;
    public string TargetAlias;
    public string UserName;
  }

  [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
  public static extern bool CredWrite(ref CREDENTIAL credential, UInt32 flags);

  public static void WriteGeneric(string targetName, string userName, string secret) {
    byte[] bytes = System.Text.Encoding.Unicode.GetBytes(secret);
    IntPtr blob = Marshal.AllocHGlobal(bytes.Length);
    try {
      Marshal.Copy(bytes, 0, blob, bytes.Length);
      CREDENTIAL credential = new CREDENTIAL();
      credential.Type = 1; // CRED_TYPE_GENERIC
      credential.TargetName = targetName;
      credential.UserName = userName ?? "";
      credential.CredentialBlobSize = (UInt32)bytes.Length;
      credential.CredentialBlob = blob;
      credential.Persist = 2; // CRED_PERSIST_LOCAL_MACHINE
      if (!CredWrite(ref credential, 0)) {
        throw new Win32Exception(Marshal.GetLastWin32Error());
      }
    }
    finally {
      byte[] zero = new byte[bytes.Length];
      Marshal.Copy(zero, 0, blob, zero.Length);
      Marshal.FreeHGlobal(blob);
    }
  }
}
"@

function Invoke-Sqlite {
  param([Parameter(Mandatory = $true)][string]$Sql)

  $output = & $SqliteExe $DatabasePath -batch -noheader -separator "`t" $Sql 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "sqlite3 failed: $output"
  }
  return $output
}

function Quote-SqliteLiteral {
  param([AllowNull()][string]$Value)

  if ($null -eq $Value) {
    return "NULL"
  }
  return "'" + ($Value -replace "'", "''") + "'"
}

function Test-SqliteTable {
  param([Parameter(Mandatory = $true)][string]$Name)

  $sql = "SELECT name FROM sqlite_master WHERE type='table' AND name=$(Quote-SqliteLiteral $Name);"
  return [bool](Invoke-Sqlite $sql)
}

function New-UniBaseLLMCredentialTarget {
  param([Parameter(Mandatory = $true)][string]$ConfigName)

  $safe = $ConfigName.Trim() -replace '[\\/:*?"<>|]', '_'
  if ($safe -eq "") {
    $safe = "Default"
  }
  return "UniBase_LLM_${safe}_ApiKey"
}

function New-UniBaseLLMApiKeyTarget {
  param([Parameter(Mandatory = $true)][string]$ApiKeyName)

  $safe = $ApiKeyName.Trim() -replace '[\\/:*?"<>|]', '_'
  if ($safe -eq "") {
    $safe = "Default"
  }
  return "UniBase_LLMApiKey_${safe}_ApiKey"
}

function Save-UniBaseCredential {
  param(
    [Parameter(Mandatory = $true)][string]$TargetName,
    [Parameter(Mandatory = $true)][string]$Secret
  )

  if (-not $DryRun) {
    [UniBaseCredMan]::WriteGeneric($TargetName, "", $Secret)
  }
}

function Convert-ConfigTableColumn {
  param(
    [Parameter(Mandatory = $true)][string]$TableName,
    [Parameter(Mandatory = $true)][string]$SecretColumn
  )

  if (-not (Test-SqliteTable $TableName)) {
    return 0
  }

  $excludeApiKeyNames = ""
  if ((Test-SqliteTable "LLMApiKeys") -and ($TableName -eq "LLMConfig") -and ($SecretColumn -eq "ApiKeyRef")) {
    $excludeApiKeyNames = "AND NOT EXISTS (SELECT 1 FROM LLMApiKeys k WHERE k.Name = t.ApiKeyRef)"
  }

  $rows = Invoke-Sqlite @"
SELECT t.Name, t.$SecretColumn
FROM $TableName t
WHERE t.$SecretColumn IS NOT NULL
  AND trim(t.$SecretColumn) <> ''
  AND t.$SecretColumn NOT LIKE 'credman:%'
  $excludeApiKeyNames;
"@

  $count = 0
  foreach ($row in $rows) {
    if ($row -eq "") { continue }
    $parts = $row -split "`t", 2
    if ($parts.Count -lt 2) { continue }

    $name = $parts[0]
    $secret = $parts[1]
    $target = New-UniBaseLLMCredentialTarget $name
    $ref = "credman:$target"

    Write-Host "Migrating $TableName.$SecretColumn for '$name' -> $ref"
    Save-UniBaseCredential -TargetName $target -Secret $secret

    if (-not $DryRun) {
      $sql = "UPDATE $TableName SET $SecretColumn=$(Quote-SqliteLiteral $ref), UpdatedAt=datetime('now') WHERE Name=$(Quote-SqliteLiteral $name);"
      Invoke-Sqlite $sql | Out-Null
    }
    $count++
  }

  return $count
}

function Convert-LLMApiKeys {
  if (-not $MigrateLLMApiKeys) {
    return 0
  }
  if (-not (Test-SqliteTable "LLMApiKeys")) {
    return 0
  }

  $rows = Invoke-Sqlite @"
SELECT Name, ApiKey
FROM LLMApiKeys
WHERE ApiKey IS NOT NULL
  AND trim(ApiKey) <> ''
  AND ApiKey NOT LIKE 'credman:%';
"@

  $count = 0
  foreach ($row in $rows) {
    if ($row -eq "") { continue }
    $parts = $row -split "`t", 2
    if ($parts.Count -lt 2) { continue }

    $name = $parts[0]
    $secret = $parts[1]
    $target = New-UniBaseLLMApiKeyTarget $name
    $ref = "credman:$target"

    Write-Host "Migrating LLMApiKeys.ApiKey for '$name' -> $ref"
    Save-UniBaseCredential -TargetName $target -Secret $secret

    if (-not $DryRun) {
      $sql = "UPDATE LLMApiKeys SET ApiKey=$(Quote-SqliteLiteral $ref), EncryptionMethod='CREDMAN', IsEncrypted=1, UpdatedAt=datetime('now') WHERE Name=$(Quote-SqliteLiteral $name);"
      Invoke-Sqlite $sql | Out-Null
    }
    $count++
  }

  return $count
}

& $SqliteExe -version | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "sqlite3 executable not found or not runnable: $SqliteExe"
}

$migrated = 0
$migrated += Convert-ConfigTableColumn -TableName "LLMConfig" -SecretColumn "ApiKeyRef"
$migrated += Convert-ConfigTableColumn -TableName "LLMConfiguration" -SecretColumn "ApiKey"
$migrated += Convert-LLMApiKeys

if ($DryRun) {
  Write-Host "Dry run complete. $migrated credential(s) would be migrated."
}
else {
  Write-Host "Migration complete. $migrated credential(s) migrated."
}
