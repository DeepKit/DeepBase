# 工单 WO-20260827-HB-AUDIT-FIX-CORE-FMX（乙号工单 / 开发AI：乙）

> **指派对象**：开发AI 乙（Core 令牌系统 + FMX 双胞胎 + 测试防线）
> **工单性质**：审计缺陷修复（P0 全部必修，P1 按序修）
> **基线**：Delphi 13.1 (Athens) · Win64 · dcc64 = `D:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe`
> **来源审计报告**（每条缺陷含路径:行号+代码片段+修复建议，修复前必读）：
> - `D:\_Progs\02Business\DeepBase\CodeReview\20260827-HB-Core.md`（🔴2 / 🟡14 / 🔵6）
> - `D:\_Progs\02Business\DeepBase\CodeReview\20260827-HB-FMX-Tests.md`（🔴4 / 🟡10 / 🔵2）

---

## P0 · 必修（全部 🔴，共 6 条）

### C 组（Core 层，来自 HB-Core 报告）
| # | 文件 | 缺陷 | 修复要求 |
|---|---|---|---|
| C-F01 | `D:\_Progs\02Business\DeepBase\Core\DeepBase.HB.Core.pas`（解析器 577-591 / 594-604 附近，对照 `D:\_Progs\02Business\DeepBase\Core\DeepBase.HB.Palettes.pas` JSON 键名） | 解析器读 `xs/s/m/l/xl` 与 `fast/normal/slow`，JSON 写 `spaceXS` 与 `durFast` 系 → space 组 5 键 + motion 组 3 键 100% 静默失效 | 统一键名（以 JSON 侧为准改解析器，或反向），并新增单元测试：每主题逐键断言解析结果 ≠ 默认值 |
| C-F02 | 同上 | durNorm 等令牌 JSON 覆盖全量失效（gold 主题 220 恒为默认 200） | 同 C-F01 修复后，在 `D:\_Progs\02Business\DeepBase\Tests\Test.DeepBase.VCL.HB.Theme.pas` 增加回归用例锁定 |

### D 组（FMX + 测试，来自 HB-FMX-Tests 报告）
| # | 文件 | 缺陷 | 修复要求 |
|---|---|---|---|
| D-F01 | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Gate.pas`、`D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.CommandPalette.pas`、`D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.VirtualList.pas` | 误引 VCL 专属基类 `THbCustomControl`（正确基类为 `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Controls.pas` 的 `THbFmxControl`），dcc64 实测各 8 处 E2003，编译失败 | 替换基类并清除级联错误，直至 dcc64 EXITCODE=0 |
| D-F02 | `D:\_Progs\02Business\DeepBase\FMX\`（全目录） | 14/18 单元无任何工程引用 = 编译盲区，破损长期潜伏 | 在 `D:\_Progs\02Business\DeepBase\DeepBaseFMX.dpk` 确认全量收录（编译该 dpk 验证），或建 FMX 冒烟编译目标纳入 run_tests.ps1 |
| D-F03 | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Dialogs.pas` | 确认对话框恒真桩（接通后静默放行全部确认流） | 改为真实模态实现（对照 VCL 版 `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Dialogs.pas` 523 行附近真实模态） |
| D-F04 | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Voice.pas` | VoiceDialog 恒真桩（同上） | 对照 VCL 版 `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Voice.pas` 679 行附近实现 |

## P1 · 高优（第二批）
1. C-F04：`RowHeightScale` 密度系数 0.85 双处硬编码覆盖 JSON density 令牌（该组未解析）→ 接入解析；
2. C-F06：`ValidateWcagAA` 仅验 2 对颜色：补 OnPrimary/Primary 按 4.5:1（常规字号正文）、InkMuted 3.77:1 未检 → 扩充校验对并让默认主题达标或降级声明；
3. C-F09：`THbTheme` 锁语义与 TMessageManager 跨线程发送不安全 → 文档化仅主线程调用，或改主线程 Synchronize 派发；
4. run_tests.ps1 `ModuleRunMap`（约 75-91 行）补 `Test.DeepBase.HB` 别名映射；
5. FMX 两个对话框修复后，补 FMX 冒烟测试（至少编译级）+ 恒真桩回归断言（确认流取消时必须返回 False）；
6. 测试边界补齐：空队列、特殊字符模糊搜索、4:5 尺寸溢出、脱敏掩码（写入 `D:\_Progs\02Business\DeepBase\Tests\Test.DeepBase.HB.DeepRW.pas`）。

---

## 验收准则（全部满足才可交付）
1. dcc64 编译 0 Error：DeepBaseFMX.dpk 与 DeepBaseCore.dpk 均单独编译通过（EXITCODE=0 附输出）；
2. FMX 三个失败单元修复后必须实测编译（对照法：Voice/Grid/ShareCard 同参数 EXITCODE=0）；
3. 回归全绿：
   ```powershell
   powershell -ExecutionPolicy Bypass -File D:\_Progs\02Business\DeepBase\Scripts\run_tests.ps1 -Type Unit -Run "Test.DeepBase.HB"
   ```
   新增 C-F01/C-F02 令牌回归用例与 D-F03/D-F04 恒真桩断言，结果以 junit XML / 日志为准，禁止口头报数；
4. 交付报告含「生产部署状态」章节（编译/测试进程时间戳）；
5. 每条 P0 修复必须引用审计编号（C-F01~D-F04）逐条标注 已修复/部分修复/不适用+理由。

**交付报告写入**：`D:\_Progs\02Business\DeepBase\CodeReview\20260827-HB-FIX-乙-交付报告.md`
