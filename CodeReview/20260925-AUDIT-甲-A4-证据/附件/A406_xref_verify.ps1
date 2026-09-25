# A4-06 companion: PDF cross-reference / object-graph verifier.
# Reads real PDFs produced by A406_PDF.exe (binaries stay outside the evidence
# dir), writes an ASCII-only verification report.
param(
  [Parameter(Mandatory = $true)][string]$InDir,
  [Parameter(Mandatory = $true)][string]$OutPath
)

$enc = [System.Text.UTF8Encoding]::new($false)
$lines = [System.Collections.Generic.List[string]]::new()
function L([string]$s) { [void]$lines.Add($s) }
$script:FailCount = 0
function Check([string]$name, [bool]$ok, [string]$detail) {
  if (-not $ok) { $script:FailCount++ }
  L(("  {0} {1} :: {2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $detail))
}
function Repl([string]$s) { return ($s -replace "[^\x20-\x7e]", '.') }

# Blank stream payloads so that binary data cannot be mistaken for "N 0 obj".
function Mask-Streams([string]$text) {
  $sb = [System.Text.StringBuilder]::new($text)
  $rx = [regex]'(?<!end)stream\r?\n'
  foreach ($m in ($rx.Matches($text) | Sort-Object Index -Descending)) {
    $end = $text.IndexOf('endstream', $m.Index + $m.Length)
    if ($end -lt 0) { continue }
    for ($i = $m.Index; $i -lt $end; $i++) {
      if ($sb[$i] -ne "`n" -and $sb[$i] -ne "`r") { $sb[$i] = ' ' }
    }
  }
  return $sb.ToString()
}

$files = @(Get-ChildItem -Path $InDir -Filter 'A406_*.pdf' -File | Sort-Object Name)
if ($files.Count -eq 0) { L("FAIL no PDF found in $InDir") }

foreach ($f in $files) {
  $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
  $latin = [System.Text.Encoding]::GetEncoding(28591).GetString($bytes)
  $masked = Mask-Streams $latin
  L("FILE $($f.Name) size=$($bytes.Length)")

  Check 'header' $latin.StartsWith('%PDF-') ("starts with " + (Repl $latin.Substring(0, 8)))
  Check 'eof-marker' ($latin.TrimEnd().EndsWith('%%EOF')) 'file ends with %%EOF'

  # ---- startxref ----
  $sx = [regex]::Match($latin, 'startxref\s+(\d+)\s+%%EOF')
  if (-not $sx.Success) { $sx = [regex]::Match($latin, 'startxref\s+(\d+)') }
  Check 'startxref-present' $sx.Success ('startxref token found, value=' + $(if ($sx.Success) { $sx.Groups[1].Value } else { 'none' }))
  if (-not $sx.Success) { continue }
  $sxOff = [int]$sx.Groups[1].Value
  $sxOk = ($sxOff -ge 0 -and $sxOff -lt $masked.Length -and $masked.Substring($sxOff, 4) -eq 'xref')
  Check 'startxref-target' $sxOk ("offset $sxOff -> '" + $(if ($sxOff -lt $masked.Length) { Repl $masked.Substring($sxOff, 12) } else { 'OUT-OF-RANGE' }) + "'")
  if (-not $sxOk) { continue }

  # ---- parse xref table ----
  $xr = $masked.Substring($sxOff)
  $objFree = @{}   # object number -> 'f'
  $objUsed = @{}   # object number -> byte offset
  $sub = [regex]::Match($xr, '(?m)^xref\s*\r?\n(\d+)\s+(\d+)\s*\r?\n')
  if ($sub.Success) {
    $startNo = [int]$sub.Groups[1].Value
    $count = [int]$sub.Groups[2].Value
    $region = $xr.Substring($sub.Index + $sub.Length)
    $entries = @([regex]::Matches($region, '(?m)^(\d{10})\s+(\d{5})\s+([nf])[ ]?\r?$'))
    if ($entries.Count -lt $count) {
      L("    xref header declares $count entries but only $($entries.Count) parsed")
    }
    for ($i = 0; $i -lt [Math]::Min($count, $entries.Count); $i++) {
      $num = $startNo + $i
      $off = [int]$entries[$i].Groups[1].Value
      if ($entries[$i].Groups[3].Value -eq 'n') { $objUsed[$num] = $off } else { $objFree[$num] = $true }
    }
  } else {
    L('    xref subsection header not found')
  }
  L("  xref entries: used=$($objUsed.Count) free=$($objFree.Count)")

  # ---- every in-use xref entry must point at its own object ----
  $badEntry = 0
  foreach ($k in $objUsed.Keys) {
    $o = $objUsed[$k]
    if ($o -ge $masked.Length -or -not $masked.Substring($o, [Math]::Min(32, $masked.Length - $o)).StartsWith("$k 0 obj")) {
      $badEntry++
      L("    xref entry $k offset $o does NOT start its own object: '" +
        $(if ($o -lt $masked.Length) { Repl $masked.Substring($o, 24) } else { 'OUT-OF-RANGE' }) + "'")
    }
  }
  Check 'xref-entry-points-to-own-object' ($badEntry -eq 0) ("$($objUsed.Count) in-use entries checked, $badEntry mismatched")

  # ---- object inventory outside streams ----
  $found = @{}
  foreach ($m in [regex]::Matches($masked, '(?<![0-9])(\d+)\s+0\s+obj\b')) {
    $n = [int]$m.Groups[1].Value
    if ($found.ContainsKey($n)) { $found[$n] += @($m.Index) } else { $found[$n] = @($m.Index) }
  }
  $dups = @($found.Keys | Where-Object { $found[$_].Count -gt 1 })
  foreach ($d in $dups) {
    $snips = @()
    foreach ($idx in $found[$d]) {
      $snips += ("@" + $idx + "='" + (Repl $masked.Substring($idx, [Math]::Min(48, $masked.Length - $idx))) + "'")
    }
    L("    object $d bodies: " + ($snips -join '  ||  ') + " ; xref maps object $d to " +
      $(if ($objUsed.ContainsKey($d)) { "offset $($objUsed[$d])" } else { '<not in xref>' }))
  }
  Check 'no-duplicate-object-numbers' ($dups.Count -eq 0) ($(if ($dups.Count -eq 0) { "$($found.Count) object numbers, all unique" } else { 'duplicated object numbers: ' + ($dups -join ',') }))

  # object bodies resolved THROUGH THE XREF (this is what a conforming reader
  # uses; bodies found in the file that the xref does not select are orphans)
  $body = @{}
  foreach ($k in $objUsed.Keys) {
    $idx = $objUsed[$k]
    $end = $masked.IndexOf('endobj', $idx)
    if ($end -lt 0) { $end = [Math]::Min($idx + 2000, $masked.Length) }
    $body[$k] = $masked.Substring($idx, $end - $idx)
  }
  $orphanBodies = 0
  foreach ($n in $found.Keys) {
    foreach ($idx in $found[$n]) {
      if (-not $objUsed.ContainsKey($n) -or $objUsed[$n] -ne $idx) {
        $orphanBodies++
        L("    orphaned body: object $n at offset $idx is not the body the xref selects" +
          $(if ($objUsed.ContainsKey($n)) { " (xref selects $($objUsed[$n]))" } else { ' (object number not in xref)' }))
      }
    }
  }
  Check 'no-orphaned-object-bodies' ($orphanBodies -eq 0) ("$orphanBodies object bodies unreachable through the xref")

  # ---- every "N 0 R" reference must resolve to an existing object ----
  $missing = @()
  $freeRefs = @()
  $refs = [System.Collections.Generic.HashSet[int]]::new()
  $refScan = ($body.Values -join "`n")
  foreach ($m in [regex]::Matches($refScan, '(\d+)\s+\d+\s+R\b')) {
    $n = [int]$m.Groups[1].Value
    [void]$refs.Add($n)
    if (-not $found.ContainsKey($n)) { $missing += $n }
    elseif ($objFree.ContainsKey($n)) { $freeRefs += $n }
  }
  Check 'all-references-resolve' ($missing.Count -eq 0) ("$($refs.Count) distinct indirect refs, unresolved: " + $(if ($missing.Count) { ($missing -join ',') } else { 'none' }))
  Check 'no-ref-to-free-xref-entry' ($freeRefs.Count -eq 0) ("references landing on free/offset-0 xref entries: " + $(if ($freeRefs.Count) { ($freeRefs -join ',') } else { 'none' }))

  # ---- page tree integrity ----
  $catPages = @()
  $badCatalog = 0
  foreach ($n in $body.Keys) {
    $b = $body[$n]
    if ($b -match '/Type\s*/Catalog') {
      $pm = [regex]::Match($b, '/Pages\s+(\d+)\s+\d+\s+R')
      if (-not $pm.Success) { $badCatalog++; L("    catalog object $n has no /Pages ref"); continue }
      $p = [int]$pm.Groups[1].Value
      if (-not $body.ContainsKey($p) -or $body[$p] -notmatch '/Type\s*/Pages') {
        $badCatalog++
        L("    catalog object $n -> /Pages $p does NOT resolve to a /Type /Pages object (" +
          $(if ($body.ContainsKey($p)) { Repl $body[$p].Substring(0, [Math]::Min(60, $body[$p].Length)) } else { 'missing' }) + ")")
      } else { $catPages += $p }
    }
  }
  Check 'catalog-pages-type' ($badCatalog -eq 0) ("catalog->/Pages target subtype checked, $badCatalog bad")

  $badKids = 0; $kidCount = 0
  foreach ($p in $catPages) {
    $km = [regex]::Match($body[$p], '/Kids\s*\[([^\]]*)\]')
    if (-not $km.Success) { $badKids++; L("    pages object $p has no /Kids array"); continue }
    foreach ($rm in [regex]::Matches($km.Groups[1].Value, '(\d+)\s+\d+\s+R')) {
      $k = [int]$rm.Groups[1].Value; $kidCount++
      if (-not $body.ContainsKey($k) -or $body[$k] -notmatch '/Type\s*/Page\b') {
        $badKids++
        L("    pages object $p -> kid $k is NOT a /Type /Page object (" +
          $(if ($body.ContainsKey($k)) { Repl $body[$k].Substring(0, [Math]::Min(60, $body[$k].Length)) } else { 'missing' }) + ")")
      }
    }
  }
  Check 'pages-kids-type' ($badKids -eq 0) ("$kidCount kid refs checked, $badKids bad")

  # ---- font object graph: /Type0 font must point at a CID descendant ----
  $badFont = 0; $fontCount = 0
  foreach ($n in $body.Keys) {
    $b = $body[$n]
    if ($b -notmatch '/Subtype\s*/Type0') { continue }
    $dm = [regex]::Match($b, '/DescendantFonts\s*\[([^\]]*)\]')
    if (-not $dm.Success) { $badFont++; L("    Type0 font object $n has no /DescendantFonts array"); continue }
    foreach ($rm in [regex]::Matches($dm.Groups[1].Value, '(\d+)\s+\d+\s+R')) {
      $d = [int]$rm.Groups[1].Value; $fontCount++
      if (-not $body.ContainsKey($d)) {
        $badFont++; L("    Type0 font $n -> descendant $d MISSING"); continue
      }
      $t = [regex]::Match($body[$d], '/Subtype\s*/(\w+)')
      $tname = $(if ($t.Success) { $t.Groups[1].Value } else { 'no-subtype' })
      if ($tname -notmatch '^CIDFontType[012]$') {
        $badFont++
        L("    Type0 font $n -> descendant $d has /Subtype /$tname (expected CIDFontType0/1/2)")
      }
    }
  }
  Check 'type0-descendant-is-cidfont' ($badFont -eq 0) ("$fontCount descendant refs checked, $badFont bad")

  # ---- font resource refs used by pages must point at a font object ----
  $badRes = 0; $resCount = 0
  foreach ($n in $body.Keys) {
    $b = $body[$n]
    if ($b -notmatch '/Type\s*/Page\b') { continue }
    foreach ($rm in [regex]::Matches($b, '/Font\s*<<([^>]*)>>')) {
      foreach ($fm in [regex]::Matches($rm.Groups[1].Value, '/(F\d+)\s+(\d+)\s+\d+\s+R')) {
        $resCount++
        $t = [int]$fm.Groups[2].Value
        if (-not $body.ContainsKey($t) -or $body[$t] -notmatch '/Type\s*/Font') {
          $badRes++
          L("    page $n resource $($fm.Groups[1].Value) -> object $t is not a /Type /Font object (" +
            $(if ($body.ContainsKey($t)) { Repl $body[$t].Substring(0, [Math]::Min(60, $body[$t].Length)) } else { 'missing' }) + ")")
        }
      }
    }
  }
  Check 'page-font-resource-type' ($badRes -eq 0) ("$resCount page font refs checked, $badRes bad")
}

L("")
L("TOTAL files=$($files.Count) failed-checks=$script:FailCount")
[System.IO.File]::WriteAllLines($OutPath, $lines, $enc)
Write-Host ("A406 verify: files={0} failed-checks={1} out={2}" -f $files.Count, $script:FailCount, $OutPath)
exit $(if ($script:FailCount -gt 0) { 1 } else { 0 })
