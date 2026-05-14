<#
.SYNOPSIS
    DeepBase 分层架构边界检查脚本
.DESCRIPTION
    检测核心层与外壳层之间的违规依赖：
    - 循环依赖
    - 反向依赖（核心层依赖外壳层）
    - 跨层直接调用
.NOTES
    参考文档: docs/AI编程低熵约束指南.md
    版本: 1.0
    日期: 2025-12-07
#>

param(
    [string]$SourcePath = "$PSScriptRoot\..\docs\deepBase\Source",
    [switch]$Verbose,
    [switch]$FailOnViolation
)

# ============================================================================
# 分层定义
# ============================================================================

# 核心层模块 - 只能被外壳层依赖，不能反向依赖
$CoreModules = @(
    "EventSourcing",
    "Workflow",
    "Core"
)

# 外壳层模块 - 可以依赖核心层
$ShellModules = @(
    "Skills",
    "Plugins",
    "AI",
    "Analytics",
    "Tenant",
    "MCP",
    "Queue",
    "Realtime",
    "Session"
)

# 核心层文件模式
$CoreFilePatterns = @(
    "DeepBase.EventSourcing.*",
    "DeepBase.Workflow.*",
    "DeepBase.Core.*",
    "DeepBase.Types.*",
    "DeepBase.DI.*"
)

# 外壳层文件模式
$ShellFilePatterns = @(
    "DeepBase.AI.*",
    "DeepBase.Skill.*",
    "DeepBase.Plugin.*",
    "DeepBase.Analytics.*",
    "DeepBase.Tenant.*",
    "DeepBase.MCP.*",
    "DeepBase.Queue.*",
    "DeepBase.Realtime.*",
    "DeepBase.Session.*"
)

# ============================================================================
# 工具函数
# ============================================================================

function Get-UsesClause {
    param([string]$FilePath)
    
    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return @() }
    
    # 提取 uses 子句中的单元名
    $usesPattern = '(?s)uses\s+(.*?);'
    $matches = [regex]::Matches($content, $usesPattern)
    
    $units = @()
    foreach ($match in $matches) {
        $usesBlock = $match.Groups[1].Value
        # 移除注释
        $usesBlock = $usesBlock -replace '\{[^}]*\}', ''
        $usesBlock = $usesBlock -replace '\(\*.*?\*\)', ''
        $usesBlock = $usesBlock -replace '//.*', ''
        
        # 分割单元名
        $unitNames = $usesBlock -split ',' | ForEach-Object {
            $_.Trim() -replace '\s+', ''
        } | Where-Object { $_ -ne '' }
        
        $units += $unitNames
    }
    
    return $units | Select-Object -Unique
}

function Is-CoreFile {
    param([string]$FileName)
    
    foreach ($pattern in $CoreFilePatterns) {
        if ($FileName -like $pattern) {
            return $true
        }
    }
    return $false
}

function Is-ShellFile {
    param([string]$FileName)
    
    foreach ($pattern in $ShellFilePatterns) {
        if ($FileName -like $pattern) {
            return $true
        }
    }
    return $false
}

function Is-CoreUnit {
    param([string]$UnitName)
    
    foreach ($pattern in $CoreFilePatterns) {
        $patternWithoutExt = $pattern -replace '\.pas$', ''
        if ($UnitName -like $patternWithoutExt) {
            return $true
        }
    }
    return $false
}

function Is-ShellUnit {
    param([string]$UnitName)
    
    foreach ($pattern in $ShellFilePatterns) {
        $patternWithoutExt = $pattern -replace '\.pas$', ''
        if ($UnitName -like $patternWithoutExt) {
            return $true
        }
    }
    return $false
}

# ============================================================================
# 检查逻辑
# ============================================================================

$Violations = @()
$Stats = @{
    TotalFiles = 0
    CoreFiles = 0
    ShellFiles = 0
    ReverseViolations = 0
    CircularViolations = 0
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " DeepBase 分层架构边界检查" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "源码路径: $SourcePath"
Write-Host ""

# 获取所有 Pascal 文件
$PasFiles = Get-ChildItem -Path $SourcePath -Filter "*.pas" -Recurse -ErrorAction SilentlyContinue

if (-not $PasFiles) {
    Write-Host "未找到 Pascal 源文件" -ForegroundColor Yellow
    exit 0
}

$Stats.TotalFiles = $PasFiles.Count
Write-Host "扫描文件数: $($Stats.TotalFiles)"
Write-Host ""

# 构建依赖图
$DependencyGraph = @{}

foreach ($file in $PasFiles) {
    $fileName = $file.Name
    $unitName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    
    $uses = Get-UsesClause -FilePath $file.FullName
    $DependencyGraph[$unitName] = $uses
    
    if (Is-CoreFile -FileName $fileName) {
        $Stats.CoreFiles++
    }
    elseif (Is-ShellFile -FileName $fileName) {
        $Stats.ShellFiles++
    }
}

Write-Host "核心层文件: $($Stats.CoreFiles)"
Write-Host "外壳层文件: $($Stats.ShellFiles)"
Write-Host ""

# 检查反向依赖（核心层依赖外壳层）
Write-Host "检查反向依赖..." -ForegroundColor Yellow

foreach ($file in $PasFiles) {
    $fileName = $file.Name
    $unitName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    
    if (-not (Is-CoreFile -FileName $fileName)) {
        continue
    }
    
    $uses = $DependencyGraph[$unitName]
    
    foreach ($dep in $uses) {
        if (Is-ShellUnit -UnitName $dep) {
            $Stats.ReverseViolations++
            $violation = @{
                Type = "ReverseDepend"
                Source = $unitName
                Target = $dep
                Message = "核心层 '$unitName' 依赖外壳层 '$dep'"
                Severity = "High"
            }
            $Violations += $violation
            
            if ($Verbose) {
                Write-Host "  [违规] $($violation.Message)" -ForegroundColor Red
            }
        }
    }
}

# 检查循环依赖
Write-Host "检查循环依赖..." -ForegroundColor Yellow

function Find-Cycle {
    param(
        [string]$Start,
        [string]$Current,
        [System.Collections.Generic.HashSet[string]]$Visited,
        [System.Collections.Generic.List[string]]$Path
    )
    
    if ($Path.Contains($Current) -and $Current -eq $Start -and $Path.Count -gt 1) {
        return $Path
    }
    
    if ($Visited.Contains($Current)) {
        return $null
    }
    
    $Visited.Add($Current) | Out-Null
    $Path.Add($Current)
    
    $deps = $DependencyGraph[$Current]
    if ($deps) {
        foreach ($dep in $deps) {
            if ($DependencyGraph.ContainsKey($dep)) {
                $cycle = Find-Cycle -Start $Start -Current $dep -Visited $Visited -Path $Path
                if ($cycle) {
                    return $cycle
                }
            }
        }
    }
    
    $Path.RemoveAt($Path.Count - 1)
    return $null
}

$CheckedCycles = @{}

foreach ($unit in $DependencyGraph.Keys) {
    $visited = [System.Collections.Generic.HashSet[string]]::new()
    $path = [System.Collections.Generic.List[string]]::new()
    
    $cycle = Find-Cycle -Start $unit -Current $unit -Visited $visited -Path $path
    
    if ($cycle -and $cycle.Count -gt 1) {
        $cycleKey = ($cycle | Sort-Object) -join "->"
        
        if (-not $CheckedCycles.ContainsKey($cycleKey)) {
            $CheckedCycles[$cycleKey] = $true
            $Stats.CircularViolations++
            
            $violation = @{
                Type = "CircularDepend"
                Source = $unit
                Target = $cycle -join " -> "
                Message = "循环依赖: $($cycle -join ' -> ') -> $unit"
                Severity = "High"
            }
            $Violations += $violation
            
            if ($Verbose) {
                Write-Host "  [违规] $($violation.Message)" -ForegroundColor Red
            }
        }
    }
}

# ============================================================================
# 输出报告
# ============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " 检查结果" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($Violations.Count -eq 0) {
    Write-Host "✅ 未发现分层违规" -ForegroundColor Green
}
else {
    Write-Host "❌ 发现 $($Violations.Count) 个分层违规" -ForegroundColor Red
    Write-Host ""
    
    # 按类型分组
    $reverseViolations = $Violations | Where-Object { $_.Type -eq "ReverseDepend" }
    $circularViolations = $Violations | Where-Object { $_.Type -eq "CircularDepend" }
    
    if ($reverseViolations.Count -gt 0) {
        Write-Host "反向依赖违规 ($($reverseViolations.Count)):" -ForegroundColor Yellow
        foreach ($v in $reverseViolations) {
            Write-Host "  - $($v.Message)" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    if ($circularViolations.Count -gt 0) {
        Write-Host "循环依赖违规 ($($circularViolations.Count)):" -ForegroundColor Yellow
        foreach ($v in $circularViolations) {
            Write-Host "  - $($v.Message)" -ForegroundColor Red
        }
        Write-Host ""
    }
}

Write-Host "统计:"
Write-Host "  - 扫描文件: $($Stats.TotalFiles)"
Write-Host "  - 核心层文件: $($Stats.CoreFiles)"
Write-Host "  - 外壳层文件: $($Stats.ShellFiles)"
Write-Host "  - 反向依赖违规: $($Stats.ReverseViolations)"
Write-Host "  - 循环依赖违规: $($Stats.CircularViolations)"

# 输出 JSON 报告
$reportPath = "$PSScriptRoot\layer-violations-report.json"
$report = @{
    Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    SourcePath = $SourcePath
    Stats = $Stats
    Violations = $Violations
}
$report | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host ""
Write-Host "报告已保存: $reportPath"

if ($FailOnViolation -and $Violations.Count -gt 0) {
    exit 1
}

exit 0
