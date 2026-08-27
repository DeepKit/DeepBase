# WO-20260826-DEEPRW-HB-V2

> **类型**：HB 通用组件新增与既有组件扩展工单
> **提出方**：DeepRW
> **承接方**：DeepBase HB 视觉组件线
> **日期**：2026-08-26
> **优先级**：A1/A2＝P0，B1/B2＝P0，A3＝P1，B3＝P1，页面原型＝P1
> **状态**：🟢 VERIFIED（已全量交付并通过 100% CI 单元测试与高保真原型验收）
> **完成日期**：2026-08-26
> **取代**：WO-20260825-DEEPRW-HB-RESEARCH-DISCOVERY（该单基于过时的"双工作台"假设与 v1.1 前组件清单，作废留档）
> **依据指南**：`D:\_Progs\02Business\DeepBase\docs\28.ui.HB视觉基础设施-下游软件集成统一指南.md`（v1.2）
> **下游基准**：
> - `D:\_Progs\02Business\DeepRW\docs\05.架构基线-认知论证核心模型.md`（v0.8）
> - `D:\_Progs\02Business\DeepRW\docs\07.语义契约-v1.0.md`
> - `D:\_Progs\02Business\DeepRW\docs\01.产品功能及未来蓝图.md`

## 交付清单与状态汇总

| 编号 | 交付物 | 级别 | 状态 | 对应代码 / 资产 |
|:---|:---|:---|:---|:---|
| **A1** | `THbCommandPalette` 命令面板 | P0 | 🟢 VERIFIED | `Core/DeepBase.HB.CommandPalette.Types.pas`<br>`VCL/DeepBase.VCL.HB.CommandPalette.pas`<br>`FMX/DeepBase.FMX.HB.CommandPalette.pas` |
| **A2** | `THbGatePanel` 门禁体检面板 | P0 | 🟢 VERIFIED | `Core/DeepBase.HB.Gate.Types.pas`<br>`VCL/DeepBase.VCL.HB.Gate.pas`<br>`FMX/DeepBase.FMX.HB.Gate.pas` |
| **A3** | `THbShareCardRenderer` 扩展 | P1 | 🟢 VERIFIED | `Core/DeepBase.HB.ShareCard.Types.pas`<br>`VCL/DeepBase.VCL.HB.ShareCard.pas`<br>`FMX/DeepBase.FMX.HB.ShareCard.pas` (含 `scfPortrait4x5` 1080×1350) |
| **B1** | `THbNavTree` 多树导航组件 | P0 | 🟢 VERIFIED | `VCL/DeepBase.VCL.HB.NavTree.pas`<br>`FMX/DeepBase.FMX.HB.NavTree.pas` |
| **B2** | `THbDataGrid` 高性能数据网格 | P0 | 🟢 VERIFIED | `VCL/DeepBase.VCL.HB.Grid.pas`<br>`FMX/DeepBase.FMX.HB.Grid.pas` |
| **B3** | `THbVirtualList` 虚拟审阅列表 | P1 | 🟢 VERIFIED | `Core/DeepBase.HB.VirtualList.Types.pas`<br>`VCL/DeepBase.VCL.HB.VirtualList.pas`<br>`FMX/DeepBase.FMX.HB.VirtualList.pas` |
| **P1** | 5 张高保真 SVG 页面原型 | P1 | 🟢 VERIFIED | `docs/ui/prototypes/deeprw/01-governance-dashboard.svg`<br>`docs/ui/prototypes/deeprw/02-material-reader.svg`<br>`docs/ui/prototypes/deeprw/03-candidate-review-queue.svg`<br>`docs/ui/prototypes/deeprw/04-gate-panel-report.svg`<br>`docs/ui/prototypes/deeprw/05-claim-evidence-matrix.svg` |
| **P1** | 交互式 HTML 原型展示中心 | P1 | 🟢 VERIFIED | `docs/ui/prototypes/deeprw-showcase.html` |
| **TEST** | DUnitX 自动化测试套件 | P0 | 🟢 VERIFIED | `Tests/Test.DeepBase.HB.DeepRW.pas` (20/20 全部通过，0 泄漏 0 失败) |

## 0. 已裁决前提（不再讨论）

1. DeepRW 主题锁定 **`canghai-blue` + `hdComfortable`**（采用现货调色板，不注册自定义品牌色）；
2. 语音链路（THbVoiceDialog / Waveform / FieldCard）对 DeepRW **排期至 P2**，本单不含语音需求；
3. 研究语义组件（ClaimCard、EvidenceExcerpt、主张—证据矩阵网格、局部关系卡、状态胶囊）
   由 DeepRW 业务层自建，**不进入本单、不下沉 DeepBase**。

## A1（P0）命令面板 `THbCommandPalette`

全产品通用的 Ctrl+K 动词入口。复用方：DeepRW / DeepDsh / Assayer / DeepSync。

要求：

- Ctrl+K 唤起 / Esc 关闭；置顶搜索框，支持关键词与拼音首字母模糊匹配；
- 条目模型：`Caption / VerbGroup / ShortcutText / Enabled / DisabledReason / CommandID`；
  禁用态灰显并悬浮显示原因（对接统一 Command ID 军规，指南 §6.2.5）;
- 最近使用排序（宿主可注入历史源）；分组标题粘性头；
- 全键盘导航（↑↓ Enter）、五态齐备、令牌取色、DPI 四档、WCAG AA；
- 宿主注入条目提供者接口（`RegisterProvider`），面板本身零业务语义。

## A2（P0）门禁结果面板 `THbGatePanel`

编译器式检查结果清单。复用方：DeepRW 体检报告页 / Assayer 自检报告 / DeepDsh 校验输出。

行模型：

```text
RuleID        规则编号（如 R01）
Severity      sePass / seNotice / seWarning / seError
Title         一句话结论
TargetText    触发对象摘要（可空）
ReasonText    为什么触发（必填，展开区显示）
FixHint       修复建议（可空）
JumpRef       string —— 跳转引用（由下游解析定位，面板只回调 OnJump）
```

要求：

- 汇总头：`X Error · Y Warning · Z Pass · N Notice` 计数胶囊（点击按严重度过滤）；
- 行内 severity 徽章（红/琥珀/蓝灰/绿）＋图标＋文本三重冗余（不只靠颜色）；
- 行点击平滑展开解释区（Reason/FixHint/原始上下文槽）；
- 底部可选动作条插槽：宿主注入"处置"按钮（如 DeepRW 的书面豁免，走 THbDialog.PromptReason）；
- 万级行虚拟化渲染；规则编号等宽字体列对齐；
- 五态/令牌/DPI/WCAG 同 A1。

## A3（P1）ShareCardRenderer 扩展

在保持离屏矢量渲染与 `EnableAutoMasking` 语义不变的前提下：

1. 新增输出规格 `scfPortrait4x5`（1080×1350），与现有 16:9、1:1 并存；
2. `THbShareCardData` 扩展字段：
   - `FooterNote: string` —— 底部强制声明行（如"通过本地检查 ≠ 事实正确"）；
   - `BadgeText: string` + `WatermarkLocked: Boolean` —— 角标水印文案；
     锁定后任何调用方不可关闭渲染（演示数据场景硬性要求）；
   - `MetricRows: TArray<string>` —— 多行指标（替代单行 Metrics 的超集，旧字段保留兼容）；
   - `LogoRef / QRSlot` —— 可选品牌位（空则不渲染）；
3. 三种卡片模板（门禁收据 / 证据护照 / 矩阵快照）由下游用扩展字段自行拼装，
   渲染器只保证版式与脱敏，不内置业务模板。

## 页面原型（P1，5 张）

基于 canghai-blue + hdComfortable 输出 SVG 与 Delphi API 草案（1366×768 / 1920×1080 / 150% DPI 截图）：

1. 治理仪表盘：四问卡（交付就绪/阻断项/证据缺口/待我拍板）+ 第二排今日变化与健康趋势；
2. 材料阅读器：左原文右锚点列表，选区浮出"提取为 Statement / 记为候选 Claim"动作；
3. 候选审阅队列：表格+右侧 Inspector，五态处置按钮组，批量操作条；
4. 体检报告页：A2 GatePanel 全幅应用，含"为什么触发"展开与书面豁免入口；
5. 主张—证据矩阵：单元格状态灯（Direct/Partial/Contradicted/Unclear），行=Claim 列=证据簇。

## 验收

沿用指南 §7 七项 CI 门禁；新增组件各附 DUnitX 用例与画廊交互样例；
A1/A2 附万级行性能数据（滚动不掉帧）；A3 附三尺寸渲染样张。

## 交付顺序

A1 → A2 并行启动；B1/B2 与 A 组并行（独立组件互不阻塞）；
A3 → 五张原型 → B3。


## B 档：通用组件 Delphi 实现（2026-08-26 由排期请求升格为正式需求）

> 依据 29.ui v2.1 成熟度矩阵，以下组件已有交互原型（hb-suite-showcase.html），
> 属跨产品通用资产：由 DeepBase HB 线实现并交付 🟢 VERIFIED。
> 下游业务语义（如 DeepRW 的证据状态灯着色规则、候选五态处置逻辑）一律经
> 渲染器插槽 / 回调注入，不进入组件本体——保持通用性。

### B1（P0）`THbNavTree` Delphi 实现

从现有原型落地 VCL 实现（FMX 对等后置）。

要求：

- 多树容器＋分组粘性头；240px ⇄ 48px Mini Rail 平滑折叠（记忆状态）；
- 节点要素：矢量图标(16/20/24)＋文本＋计数徽章＋状态灯；支持禁用/隐藏节点；
- 关键字过滤即时高亮＋命中计数；
- 键盘全可达（↑↓←→ Enter Space Esc）；五态/令牌/DPI 四档/WCAG AA；
- 万级节点虚拟化渲染不掉帧；
- 最小 API：`RegisterTree` / `BeginUpdate` / `AddNode` / `SetBadge(node,count,tone)` /
  `Filter(keyword)` / `OnNodeClick` / `OnNodeDoubleClick`。

验收：DUnitX 用例＋画廊交互样例＋万级节点滚动性能数据。

### B2（P0）`THbDataGrid` Delphi 实现

类 Excel 高性能虚拟数据网格，对齐 29.ui §4 基准：
**100 万逻辑行滚动帧耗时 P95 ≤ 16ms**（内存驻留数组＋GDI+ 双缓冲），
超预算自动降级纯色块渲染。

要求：

- OwnerData 模式：行数由宿主声明，单元格值经 `OnGetCellContent` 回调取用；
- 列能力：拖宽／点击排序（回调宿主执行）／冻结首列；
- 单元格渲染器插槽：状态灯、徽章、进度、等宽字体（哈希/编号）、多行截断省略；
- 单元格延迟 Tooltip（宿主回调内容）；行悬停高亮；选区（单行/矩形区/Ctrl 散选）；
- 空态／加载骨架／错误态三态齐备；
- 最小 API：`Columns[]` / `SetRowCount(n)` / `OnGetCellContent` / `OnCellDraw` /
  `OnSortRequest` / `SelectedRows` / `EnsureVisible(row)`。

验收：DUnitX＋性能基准报告（注明测量机器环境）＋画廊样例。
复用方：DeepRW 主张—证据矩阵 / DeepDsh / Assayer / DeepSync 冲突对比。

### B3（P1）`THbVirtualList` 虚拟审阅列表

面向「一行＝一条待办对象」的审阅场景（DeepRW 候选审阅队列、通知中心、任务队列）。

要求：

- 行模板插槽：状态灯＋标题＋摘要两行截断＋标签 Chip 组＋右侧动作按钮区（宿主注入）；
- 多选（Shift/Ctrl）＋顶部批量操作条挂钩（宿主定义批量动作）；
- 分组折叠（按宿主提供的 group key）；关键字增量过滤；
- 十万行级虚拟化；
- 若评估结论是「可由 B2 的列表模式覆盖」，允许合并交付，
  但须在本单书面说明取舍理由与 API 差异。

验收：DUnitX＋画廊样例（含 DeepRW 候选队列传票场景）。

### B 档与 DeepRW P1 的依赖关系

- DeepRW 界面开发位于 P1 第 5–7 周；若 B1/B2 届时交付 🟢 VERIFIED 则直接消费；
- 若排期冲突，DeepRW 按 `docs/09.底座与DeepBase集成设计.md` §14 自建兜底，
  组件转绿后换壳——两条路径都已冻结，无论哪条先到都不返工；
- 请承接时**逐项反馈承诺交付日**（B1 / B2 / B3 分开报）。
