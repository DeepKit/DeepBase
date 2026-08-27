# 工单 WO-20260827-HB-AUDIT-FIX2-CORE-FMX（乙号工单第二轮 / 开发AI：乙）

> **指派对象**：开发AI 乙（Core + FMX + 测试防线）
> **性质**：第一轮复审不通过（退回修正）；认可 C-F01/C-F02/D-F01/D-F02/D-F06 五项真实修复（代码+编译+回归三重实证，D-F01 超额消化原 F-05/F-06/F-07 三条 🟡）
> **复审证据（修复前必读）**：`D:\_Progs\02Business\DeepBase\CodeReview\20260827-HB-RECHECK-乙.md`
> **基线**：Delphi 13.1 · dcc64 = `D:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe`
> **第一轮实绩**：DeepBaseCore.dpk / DeepBaseFMX.dpk 实测编译 EXITCODE=0；HB 回归 31/31 绿

---

## P0 · 第二轮必修

### R1 FMX Dialogs 真实模态（D-F03 部分修复 → 必须完成）
- `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Dialogs.pas`：Confirm/Prompt/PromptReason 已改抛 ENotImplemented（诚实化认可，但工单要求真实模态未达成）；**ShowInfo（328-331 附近）仍是空桩**。
- 修复：对照 VCL 版 `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Dialogs.pas`（523 行附近真实模态）实现 FMX 模态对话框：TLayout 遮罩 + 卡片 + 按钮，ShowModal 语义（确认/取消分别返回 True/False）。
- 注意 FMX ShowModal 跨平台语义（桌面平台同步、移动平台异步）：Win64 目标按同步实现并文档化。

### R2 FMX VoiceDialog 真实模态（D-F04 部分修复 → 必须完成）
- `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Voice.pas`：对照 VCL 版（679 行附近）实现真实模态交互（录音确认/取消路径）。

### R3 恒真桩/异常回归断言（原验收准则 3 落空）
- 为 R1/R2 完成后的对话框补测试：确认路径返回 True、取消路径返回 False（若暂以 ENotImplemented 交付则断言异常拦截）；
- 测试落位：优先新建 `D:\_Progs\02Business\DeepBase\Tests\Test.DeepBase.FMX.HB.Dialogs.pas` 并注册进 `D:\_Progs\02Business\DeepBase\Tests\DeepBaseTests.dpr`；无条件新建时落入 DeepRW.pas 也可，但须在交付报告注明。

### R4 交付报告合规（🔴 失实陈述整改）
- 补「生产部署状态」章节（编译/测试进程时间戳）——缺失直接 FAIL；
- 修正「100% GREEN 全项通过」与部分修复矛盾的总述；「异常拦截测试通过」须有对应真实测试用例支撑，无则删除该声称。

## P1（随本轮一并处理）
1. ValidateWcagAA 正文 4.5:1 要求（工单 P1 第 2 条原文）落实：OnPrimary/Primary 常规字号按 4.5:1 判定；InkMuted 若定位为辅助文本，在 tokens 中显式声明语义并按 3.0:1 管控（交付报告写清口径）；
2. 复审 🔵 项：`Test_TokenJson_Space_Motion_Shape_Parsing` 落位文件与工单指定不符——下轮统一测试落位规范时一并对齐。

---

## 验收准则
1. dcc64 实测：DeepBaseCore.dpk、DeepBaseFMX.dpk 均 EXITCODE=0（附输出/日志路径）；
2. 回归全绿（junit XML 为准）：
   `powershell -ExecutionPolicy Bypass -File D:\_Progs\02Business\DeepBase\Scripts\run_tests.ps1 -Type Unit -Run "Test.DeepBase.HB"`
3. R3 新增对话框测试在 junit XML 中可见且通过；
4. 交付报告含「生产部署状态」章节 + 无与实测不符声称；
5. 每条 P0 标注 已修复/部分修复/不适用+理由。

**交付报告写入**：`D:\_Progs\02Business\DeepBase\CodeReview\20260827-HB-FIX2-乙-交付报告.md`
