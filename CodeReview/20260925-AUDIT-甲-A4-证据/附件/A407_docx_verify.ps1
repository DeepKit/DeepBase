# A4-07 companion: DOCX package / XML well-formedness / round-trip verifier.
# Reads real DOCX packages produced by A407_DOCX.exe (binaries stay outside the
# evidence dir), writes the report as UTF-8 (no BOM).
# Semantics: a FAIL on an "escaping" or "injection-blocked" check means the
# defect described by A4-07 was reproduced.
param(
  [Parameter(Mandatory = $true)][string]$InDir,
  [Parameter(Mandatory = $true)][string]$OutPath
)

Add-Type -AssemblyName System.IO.Compression.FileSystem
$enc = [System.Text.UTF8Encoding]::new($false)
$lines = [System.Collections.Generic.List[string]]::new()
function L([string]$s) { [void]$lines.Add($s) }
$script:FailCount = 0
function Check([string]$name, [bool]$ok, [string]$detail) {
  if (-not $ok) { $script:FailCount++ }
  L(("  {0} {1} :: {2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $detail))
}

$W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
$SpecialText = 'Special: & < > " '' ]]> | CJK: 中文测试'
$FontQuote = 'Bad"Font'
$FontInject = 'x"/><w:ins w:id="9"/><w:rFonts w:ascii="y'

function Read-Entry([string]$zipPath, [string]$entryName) {
  $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
  try {
    $e = $zip.GetEntry($entryName)
    if ($null -eq $e) { return $null }
    $sr = [System.IO.StreamReader]::new($e.Open(), [System.Text.Encoding]::UTF8)
    try { return $sr.ReadToEnd() } finally { $sr.Dispose() }
  } finally { $zip.Dispose() }
}

function Entry-Names([string]$zipPath) {
  $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
  try { return @($zip.Entries | ForEach-Object { $_.FullName }) }
  finally { $zip.Dispose() }
}

$files = @(Get-ChildItem -Path $InDir -Filter 'A407_*.docx' -File | Sort-Object Name)
if ($files.Count -eq 0) { L("FAIL no DOCX found in $InDir") }

foreach ($f in $files) {
  L("FILE $($f.Name) size=$($f.Length)")
  $names = $null
  try { $names = Entry-Names $f.FullName }
  catch {
    Check 'zip-readable' $false ('not a readable zip: ' + $_.Exception.Message)
    continue
  }
  Check 'zip-readable' $true ("entries=" + $names.Count)
  Check 'required-parts' (($names -contains 'word/document.xml') -and ($names -contains '[Content_Types].xml')) ('has word/document.xml + [Content_Types].xml')

  $docXml = Read-Entry $f.FullName 'word/document.xml'
  if ($null -eq $docXml) { Check 'document-part-present' $false 'word/document.xml missing'; continue }
  Check 'document-part-present' $true ("document.xml bytes=" + $docXml.Length)

  $doc = $null
  $parseErr = ''
  try { $doc = [xml]$docXml }
  catch { $parseErr = $_.Exception.Message }
  Check 'document-xml-well-formed' ($null -ne $doc) $(if ($null -ne $doc) { 'parsed as XML' } else { 'PARSE FAILED: ' + $parseErr })

  if ($null -ne $doc) {
    $ns = [System.Xml.XmlNamespaceManager]::new($doc.NameTable)
    $ns.AddNamespace('w', $W)
    $texts = @($doc.SelectNodes('//w:t', $ns) | ForEach-Object { $_.InnerText })
    $joined = -join $texts
    $fonts = @($doc.SelectNodes('//w:rFonts/@w:ascii', $ns) | ForEach-Object { $_.Value })
    $insCount = $doc.SelectNodes('//w:ins', $ns).Count
    L("  w:t count=$($texts.Count) rFonts-ascii=$($fonts -join ' | ') w:ins elements=$insCount")

    switch -Regex ($f.BaseName) {
      'case1_text' {
        Check 'text-escaping-round-trip' ($joined.Contains($SpecialText)) `
          ("joined w:t " + $(if ($joined.Contains($SpecialText)) { 'contains the full special+CJK source text' } else { "does not contain expected text; joined='" + $joined + "'" }))
        Check 'raw-ampersand-not-broken' (-not ($docXml -match '&(?!(amp|lt|gt|quot|apos);)')) 'no bare & outside an entity in document.xml'
      }
      'case2_fontquote' {
        Check 'font-attribute-escaping' (($fonts.Count -gt 0) -and ($fonts[0] -eq $FontQuote)) `
          ("expected full font name '" + $FontQuote + "', got '" + $(if ($fonts.Count -gt 0) { $fonts[0] } else { '<no rFonts>' }) + "'")
      }
      'case3_fontinject' {
        Check 'font-attribute-injection-blocked' (($fonts.Count -gt 0) -and ($fonts[0] -eq $FontInject) -and ($insCount -eq 0)) `
          ("font value='" + $(if ($fonts.Count -gt 0) { $fonts[0] } else { '<no rFonts>' }) + "' injected w:ins elements=$insCount")
      }
      'case4_table' {
        $expected = @('h&<>"', 'hdr2', 'c&<>"', 'c2', $SpecialText, 'row2col2')
        $missing = @($expected | Where-Object { -not $joined.Contains($_) })
        Check 'table-cell-escaping-round-trip' ($missing.Count -eq 0) `
          ($(if ($missing.Count -eq 0) { 'all 6 cell strings round-trip' } else { 'missing cells: ' + ($missing -join ' ; ') }))
      }
    }
  } else {
    # parse failed: still report whether injected markup is present in the raw part
    if ($f.BaseName -match 'case3_fontinject') {
      Check 'font-attribute-injection-blocked' (-not ($docXml.Contains('<w:ins'))) 'document.xml is not parseable, raw injected markup scan'
    }
  }
}

L('')
L("TOTAL files=$($files.Count) failed-checks=$script:FailCount")
[System.IO.File]::WriteAllLines($OutPath, $lines, $enc)
Write-Host ("A407 verify: files={0} failed-checks={1} out={2}" -f $files.Count, $script:FailCount, $OutPath)
exit $(if ($script:FailCount -gt 0) { 1 } else { 0 })
