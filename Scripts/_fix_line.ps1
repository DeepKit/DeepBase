$ErrorActionPreference = 'Stop'
$f = 'D:\_Progs\02Business\DeepBase\tasks.md'
$lines = Get-Content $f -Encoding UTF8
$lines[150] = '> **进度**: 已修 **30 项** (D-001, E-001, E-004, A-001~A-010, B-001~B-017), 待修 **24 项**。已修 30 项归档 history.md (2026-07-08 REVIEW5-R3 段, 含 2026-07-09 续修 B-001~B-017 + A-001), 对应 BUG-386~BUG-415。'
[System.IO.File]::WriteAllLines($f, $lines, (New-Object System.Text.UTF8Encoding $true))
Write-Host "Line 151 rewritten"
