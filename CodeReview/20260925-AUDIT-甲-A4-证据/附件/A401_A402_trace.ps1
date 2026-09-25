# A4-01 / A4-02 companion: symbol-accurate read trace (ripgrep, line numbers).
param(
  [Parameter(Mandatory = $true)][string]$Repo,
  [Parameter(Mandatory = $true)][string]$OutPath
)

$enc = [System.Text.UTF8Encoding]::new($false)
$lines = [System.Collections.Generic.List[string]]::new()
function L([string]$s) { [void]$lines.Add($s) }
function Section([string]$title, [string[]]$argv) {
  L('')
  L('=== ' + $title + ' ===')
  L('$ ' + ($argv -join ' '))
  $out = & $argv[0] $argv[1..($argv.Length - 1)] 2>&1
  foreach ($o in $out) { L([string]$o) }
  if ($LASTEXITCODE -ne 0) { L("[rg exit=$LASTEXITCODE]  (1 = no match)") }
}
Push-Location $Repo
try {
  L('A4-01 / A4-02 trace, repo=' + $Repo)
  L('generated=' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

  L('')
  L('########## A4-01 Core/DeepBase.DataBinding.pas ##########')

  Section 'A401-1 does the unit have any DataSource concept? (empty result = no)' `
    @('rg', '-n', 'DataSource', 'Core\DeepBase.DataBinding.pas')

  Section 'A401-2 Unbind removes the entry (what the storage actually does)' `
    @('rg', '-n', '-A', '20', 'TBindingManager\.Unbind\(Source', 'Core\DeepBase.DataBinding.pas')

  Section 'A401-3 handler add de-dupes, handler remove deletes' `
    @('rg', '-n', '-A', '7', 'TObservableObject\.(Add|Remove)PropertyChangedHandler', 'Core\DeepBase.DataBinding.pas')

  Section 'A401-4 binding entry holds raw Source/Target pointers' `
    @('rg', '-n', '-A', '16', 'FBindings: TList', 'Core\DeepBase.DataBinding.pas')

  Section 'A401-5 notification path dereferences those raw pointers' `
    @('rg', '-n', '-A', '12', 'procedure TBindingManager\.UpdateAllTargets', 'Core\DeepBase.DataBinding.pas')

  L('')
  L('########## A4-02 Core/DeepBase.Manager.pas ##########')

  Section 'A402-1 Create*Storage call sites are wrapped in try/except' `
    @('rg', '-n', '-B', '3', '-A', '3', 'Create(Config|I18n|Theme|SecuritySecret|FormState|MRU|Hotkey)Storage failed', 'Core\DeepBase.Manager.pas')

  Section 'A402-2 InitializeEx: exception handler leaves FIsInitialized untouched' `
    @('rg', '-n', '-A', '18', 'function TDeepBaseManager\.InitializeEx', 'Core\DeepBase.Manager.pas')

  Section 'A402-3 Finalize: early exit when FIsInitialized = False' `
    @('rg', '-n', '-A', '16', 'procedure TDeepBaseManager\.Finalize;', 'Core\DeepBase.Manager.pas')

  Section 'A402-4 FinalizeModules: the only place modules are freed' `
    @('rg', '-n', '-A', '26', 'procedure TDeepBaseManager\.FinalizeModules;', 'Core\DeepBase.Manager.pas')

  Section 'A402-5 unguarded module/storage consumption inside InitializeModules' `
    @('rg', '-n', 'FConfig\.GetConfig|FTheme\.ApplyTheme|FI18n\.CurrentLanguage|RunOperationalRetention|LoadAllPlugins', 'Core\DeepBase.Manager.pas')
}
finally { Pop-Location }

L('')
[System.IO.File]::WriteAllLines($OutPath, $lines, $enc)
Write-Host ("A401/A402 trace: lines={0} out={1}" -f $lines.Count, $OutPath)
