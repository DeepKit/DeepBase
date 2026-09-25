# A4-08 companion: symbol-accurate read trace for the license clock-rollback claim.
# Produces a plain-text trace (ripgrep, line numbers, no rewritten prose).
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
  L('A4-08 trace, repo=' + $Repo)
  L('generated=' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

  Section 'T1 Core/DeepBase.License.pas: time source / expiry decision / guard symbols' `
    @('rg', '-n', 'IsExpired|ExpiresAt|LastSeen|LastCheck|Rewind|Monotonic|TimeGuard|GetCorrectedNow', 'Core\DeepBase.License.pas')

  Section 'T1b TLicenseInfo.IsExpired body' `
    @('rg', '-n', '-A', '14', 'function TLicenseInfo.IsExpired', 'Core\DeepBase.License.pas')

  Section 'T1c raw Now/Date usage inside Core/DeepBase.License.pas' `
    @('rg', '-n', '\bNow\b|\bDate\b|DateTime', 'Core\DeepBase.License.pas')

  Section 'T2 Features/DeepBase.TimeGuard.pas: guard API that exists in the repo' `
    @('rg', '-n', 'tg[A-Z][A-Za-z]*|function |procedure |class function|class procedure', 'Features\DeepBase.TimeGuard.pas')

  Section 'T3 every unit that references DeepBase.TimeGuard' `
    @('rg', '-ln', 'DeepBase\.TimeGuard', '-g', '*.pas')

  Section 'T4 Features/DeepBase.Licensing.pas: TimeGuard wiring' `
    @('rg', '-n', 'TimeGuard|VerifyTime|GetCorrectedNow|tgClock', 'Features\DeepBase.Licensing.pas')

  Section 'T4b Features/DeepBase.Licensing.pas: raw Now / expiry decision' `
    @('rg', '-n', '\bNow\b|IsExpired|ExpiresAt', 'Features\DeepBase.Licensing.pas')

  Section 'T5 units consuming Core/DeepBase.License (potential unprotected consumers)' `
    @('rg', '-ln', 'DeepBase\.License', '-g', '*.pas')

  Section 'T6 VCL/FMX license UI references' `
    @('rg', '-n', 'DeepBase\.(TimeGuard|Licensing|License)', 'VCL\DeepBase.VCL.LicenseAuthDialog.pas', 'VCL\DeepBase.VCL.LicenseStatusPanel.pas', 'FMX\DeepBase.FMX.LicenseStatusPanel.pas')

  Section 'T7 files touching the rollback guard (incl. tests)' `
    @('rg', '-ln', 'TimeGuard|ClockRewind|Rewind|tgClock', '-g', '*.pas')
}
finally { Pop-Location }

L('')
[System.IO.File]::WriteAllLines($OutPath, $lines, $enc)
Write-Host ("A408 trace: lines={0} out={1}" -f $lines.Count, $OutPath)
