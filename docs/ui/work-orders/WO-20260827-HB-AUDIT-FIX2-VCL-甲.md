# 工单 WO-20260827-HB-AUDIT-FIX2-VCL（甲号工单第二轮 / 开发AI：甲）

> **指派对象**：开发AI 甲（VCL 控件线）
> **性质**：第一轮复审不通过（FAIL），退回修正
> **复审证据（每条含路径:行号，修复前必读）**：`D:\_Progs\02Business\DeepBase\CodeReview\20260827-HB-RECHECK-甲.md`
> **基线**：Delphi 13.1 · dcc64 = `D:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe`
> **第一轮实绩**：10 条 P0 中 ✅4（NavTree/AI/PageControl/ShareCard-PNG）/ ⚠️6（部分修复）；新增 🔴3 / 🟡7 / 🔵6

---

## P0 · 第二轮必修（全部完成才可交付）

### R1 编译门禁修复（🔴）
- `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.LLMWizard.pas` 为无 BOM UTF-8 → 标准包门禁参数（同 `Scripts\build_packages_win64.ps1`）编译失败 E2010（L192 `PasswordChar := '•'`）。
- 修复：文件加 UTF-8 BOM 或改 ASCII 字符；
- `D:\_Progs\02Business\DeepBase\DeepBaseVCL.dpk` requires 补 `DeepBasePersistence`（消除 W1033 `DeepBase.Persistence.LLM.FireDAC` 隐式导入）；同时移除 LLMWizard 中五个装饰性 uses（L24/L37-40，全部未使用）。
- 验收：`Scripts\build_packages_win64.ps1` 同参数编译 DeepBaseVCL.dpk EXITCODE=0 且无新增 Warning（附编译日志路径）。

### R2 LLMWizard 假实现处置（🔴 证据红线，二选一，交付报告必须写明选择）
现状：假 Ping（L356-384 硬编码 128ms、Key 任意值即 🟢）、假模型探测（L386-405 写死 4 模型）、假持久化（L459-470 恒 True 却显示"已固化写入主库 DB1"）。
- 方案 A（推荐）：**整体摘除**——删除 `VCL\DeepBase.VCL.HB.LLMWizard.pas`、`Core\DeepBase.HB.LLMWizard.Types.pas`、两个 dpk 的 contains 条目、`Tests\Test.DeepBase.HB.DeepRW.pas` 中假测试用例；
- 方案 B：**真实实现**——真网络 Ping、真调 `/v1/models`、真 DB1 事务持久化（走 DeepBase.Persistence 正式链路）。
- 禁止保留现状或任何形式的假数据。

### R3 假测试处置（🔴）
`D:\_Progs\02Business\DeepBase\Tests\Test.DeepBase.HB.DeepRW.pas:299-331` `Test_LLMWizard_CascadingSteps_And_AutoClassification`（未测级联、断言静态默认值、验证恒真空壳）：随 R2 方案 A 删除，或随方案 B 重写为真实断言（Mock 传输层测分类逻辑、断言持久化调用次数）。

### R4 六条部分修复缺口补齐
| # | 文件 | 缺口 |
|---|---|---|
| R4-1 | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Controls.pas` / `DeepBase.VCL.HB.Cards.pas` | A-S1：Paint 先 FillRectangle 擦整个 ClientRect（对照 Grid.pas:409-414 正确做法）；`WMEraseBkgnd`（Controls:366-368 / Cards:224-226）相应调整 |
| R4-2 | 同上 | A-S2：三处 MouseUp（Controls:826-838 / Cards:674-686 / Cards:935-945）加 (X,Y) 命中校验 + CMMouseLeave 复位 press 状态（付费按钮拖出释放属资损级） |
| R4-3 | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Waterfall.pas` | A-S3：分面按钮绑 OnClick（更新 FFocusedCategoryId 并重建）；wmTimeline/wmSectioned 渲染差异化 |
| R4-4 | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Grid.pas` | B-S2：CreateParams 声明 WS_VSCROLL，使滚动条可见可拖（现仅滚轮/键盘可用） |
| R4-5 | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.VirtualList.pas` | B-S3：增回调数据源模式（对照 Grid 的 OnGetCellText 设计），10 万行 FItems 不再全量常驻；交付报告附 10 万行内存前后实测数字（可写 DUnitX 内存断言用例） |
| R4-6 | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.CommandPalette.pas` | B-S4：左键改选中高亮，回车/双击执行（现 L379-381 左键单击即执行） |

---

## 验收准则
1. `Scripts\build_packages_win64.ps1` 标准参数编译 DeepBaseVCL.dpk：EXITCODE=0、0 新增 Warning，附日志绝对路径；
2. 回归全绿（junit XML 为准，禁止口头报数）：
   `powershell -ExecutionPolicy Bypass -File D:\_Progs\02Business\DeepBase\Scripts\run_tests.ps1 -Type Unit -Run "Test.DeepBase.HB"`
3. 10 万行 VirtualList 内存实测数字 + 测试代码（R4-5）；
4. 交付报告**必须含「生产部署状态」章节**（编译/测试进程时间戳）——缺失直接 FAIL；
5. 交付报告不得出现与实测不符的声称；R2 选择及理由必须写明；每条 P0 标注 已修复/部分修复/不适用+理由。

**交付报告写入**：`D:\_Progs\02Business\DeepBase\CodeReview\20260827-HB-FIX2-甲-交付报告.md`
