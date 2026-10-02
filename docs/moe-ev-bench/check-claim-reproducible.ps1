# MoE 取证单 · 性能数字「可复算性」机器判定（WO-20261002-MC-甲-MOE-EV 判据 3）
#
# 用途：讨论包与工单里出现的任何 tok/s / GB/s / 延迟数字，提交前先过这道判定。
# 缺任何一项基线维度 ⇒ 判「不可复算」并列出缺哪几项，不允许「大致可信」这种第三态
# （这正是上游 docs/BENCHMARKING.md 的纪律：没有硬件基线的秒数不是数据）。
#
# 四维基线（缺一即不可复算）：
#   1. 硬件基线   —— CPU 型号 / 核数 / 内存 / 是否有加速卡
#   2. 量化与打包格式 —— MXFP4 / int4 / int8 / bf16 / fp32，以及标度分组粒度
#   3. 模型形状   —— 参数量或矩阵维度（同一 tok/s 在 2B 与 2.78T 上不可比）
#   4. 重复次数与离散度 —— 上游实测同配置 run-to-run 离散 33.1%，单次读数不可作判据
#
# 用法:
#   pwsh -NoProfile -File docs/moe-ev-bench/check-claim-reproducible.ps1 `
#        -Claim 'A 卡 30 tok/s' -Repetitions 1
#   pwsh -NoProfile -File docs/moe-ev-bench/check-claim-reproducible.ps1 `
#        -Claim 'AMD Ryzen 7 3700X 8C/16T, 63.95 GB, 无独显; MXFP4 每 32 元素 1 个 E8M0 标度; 4608x7168 单专家 33,030,144 参数; 3 组重复离散度 7.3%' `
#        -Hardware $true -Quant $true -Shape $true -Repetitions 3 -SpreadPct 7.3
#
# 退出码: 0 = 可复算; 1 = 不可复算（缺项已打印）; 3 = 参数自相矛盾

param(
  [Parameter(Mandatory = $true)][string]$Claim,
  [switch]$Hardware,          # 已给硬件基线
  [switch]$Quant,             # 已给量化/打包格式
  [switch]$Shape,             # 已给模型形状
  [int]$Repetitions = 0,      # 重复次数（0 = 未声明）
  [double]$SpreadPct = -1     # 组间离散度（-1 = 未声明）
)

$ErrorActionPreference = 'Stop'
$missing = @()

if (-not $Hardware) { $missing += '硬件基线（CPU 型号 / 核数 / 内存 / 加速卡）' }
if (-not $Quant)    { $missing += '量化与打包格式（位宽 + 标度分组粒度）' }
if (-not $Shape)    { $missing += '模型形状（参数量或矩阵维度）' }
if ($Repetitions -lt 3) {
  $missing += "重复次数（$Repetitions 次；上游纪律要求 >= 3 次，单次读数不是判据）"
}
if ($SpreadPct -lt 0) {
  $missing += '组间离散度（未声明，无法判断该差异是否超过噪声底）'
}

Write-Host "claim        : $Claim"
Write-Host ("hardware     : {0}" -f $(if ($Hardware) { 'declared' } else { 'MISSING' }))
Write-Host ("quant/format : {0}" -f $(if ($Quant)    { 'declared' } else { 'MISSING' }))
Write-Host ("model shape  : {0}" -f $(if ($Shape)    { 'declared' } else { 'MISSING' }))
Write-Host ("repetitions  : $Repetitions")
Write-Host ("spread       : $(if ($SpreadPct -lt 0) { 'MISSING' } else { "$SpreadPct%" })")
Write-Host ""

if ($missing.Count -eq 0) {
  Write-Host "VERDICT: REPRODUCIBLE"
  Write-Host "  判据：三态取「可复算」。引用时必须把上面 6 个字段一起带上，否则接收方无法复跑。"
  exit 0
}

Write-Host "VERDICT: NOT-REPRODUCIBLE"
Write-Host ("  缺 {0} 项：" -f $missing.Count)
$missing | ForEach-Object { Write-Host "    - $_" }
Write-Host ""
Write-Host "  这不是「大致可信」的问题，是这个数字在当前形态下不可被第三方复跑或反驳，"
Write-Host "  因此不得作为工单判据、WP 验收标准或对老板汇报里的性能依据。"
exit 1