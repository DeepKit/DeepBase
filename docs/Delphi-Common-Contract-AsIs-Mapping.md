# EHAI Language Common Layer · Delphi As-Is Mapping

## 现状工程实现与语言无关契约映射台账 (Delphi-Common-Contract-AsIs-Mapping)

> **文档性质**：`ENGINEERING AS-IS MAPPING & GAP AUDIT / NON-NORMATIVE`  
> **基线版本**：`EHAI-Language-Neutral-Realization-Contract-v0 (APPROVED ENGINEERING BASELINE v0)`  
> **工程主仓**：`D:\_Progs\02Business\DeepBase`  
> **日期**：2026-09-14  

---

## 一、概述与定界原则

本映射台账对当前 DeepBase / HB 现有 Delphi 实现进行逐条、逐单元、逐类型的严格技术对照，确立：
1. **契约条目（Common Contract Item）**；
2. **现有 Delphi 实现（Existing Delphi Realization）**；
3. **确凿代码证据（Code Evidence）**；
4. **差距与断层（Gap & Missing Semantics）**；
5. **升级改造方案（Remediation & Binding Strategy）**。

恪守纪律：**禁止因为已有类似类型名就默认认为已经满足契约；语义等价优于名称一致。**

---

## 二、十项核心语义契约 As-Is 对照矩阵

| 条目代号 | 契约抽象语义 | 现有 Delphi 实现及代码证据 | 证据把握度 | 识别出的差距 (Gap) | 升级改造方案 |
| :---: | :--- | :--- | :---: | :--- | :--- |
| **SRC-01** | `CandidateSpace`<br>(候选提议空间) | `Core\DeepBase.HB.Choice.Types.pas: Lines 96-108`<br>`VCL\DeepBase.VCL.HB.Choice.pas: Lines 380-388`<br>• `THbChoiceItem` 承载单项候选<br>• `SetOptions` 显式硬编码上限 7 项 (`if Key <= 7`) | **HIGH** | • 提议空间目前与 UI 控件紧耦合，缺少 DeepBase Core 级别的纯语义无头数据结构 `TEhaiCandidateSpace`。<br>• 缺少无头状态下的 `NoReliableCandidates` 语义表示。 | 在 `DeepBase.EHAI.Types` 中定义无头 `TEhaiCandidate` 与 `TEhaiCandidateSpace`，支持最多 7 项约束与 `NoReliableCandidates` 状态；HB 控件作为其 Presenter。 |
| **SRC-02** | `RecommendedMark`<br>(建议标记) | `Core\DeepBase.HB.Choice.Types.pas: Line 101`<br>`VCL\DeepBase.VCL.HB.Choice.pas: Line 361`<br>• `THbChoiceItem.IsRecommended: Boolean`<br>• 1 号键呈现 Accent 建议徽标 | **HIGH** | • 仅作为 UI 视觉标记存在，缺少契约层“建议非执行性（`Delivery Completion ≠ Advice Acceptance`）”的语义守界约束。 | 在 `TEhaiCandidate` 中保留 `IsRecommended`，并配合 `TEhaiInteractionAction` 确保标记不附带默认自动承诺。 |
| **SRC-03** | `CandidateSelection`<br>(候选倾向选择) | `Core\DeepBase.HB.Choice.Types.pas: Lines 43, 114`<br>`VCL\DeepBase.VCL.HB.Choice.pas: Lines 775-786`<br>• `cakCandidate`, `THbChoiceAction`<br>• `TriggerAction(cakCandidate, ...)` | **HIGH** | • `THbChoiceAction` 未绑定 `InvolvementProfile`、`DecisionContext` 与 `CompletionSemantics`。<br>• 容易被误解为“纯探索”或“自动承诺”，缺少上下文决定正式效力的连接机制。 | 在 `DeepBase.EHAI.Types` 中定义 `TEhaiInteractionAction`，将 Choose 动作与 `TEhaiInvolvementProfile` 及 `TEhaiContextBinding` 显式锚定，实现 `Choose + Profile + Context → Formal Act`。 |
| **SRC-04** | `Regenerate`<br>(候选集合重构) | `Core\DeepBase.HB.Choice.Types.pas: Lines 34, 44, 77`<br>`VCL\DeepBase.VCL.HB.Choice.pas: Lines 1115-1126`<br>• `ckRegenerate`, `cakRegenerate`, `csRegenerating`<br>• 8 键重生成，旧选项淡化（Alpha 110） | **HIGH** | • 控件具备探索性与视觉参照保护，但 Core 缺少无头环境下的非承诺探索守界断言机制。 | 在 Core 中规范 `TEhaiMetaAction.emaRegenerate` 状态机，保证重生成对 Canonical State 零污染。 |
| **SRC-05** | `HumanOverride`<br>(人类自主覆写) | `Core\DeepBase.HB.Choice.Types.pas: Lines 35, 45, 78, 88`<br>`VCL\DeepBase.VCL.HB.Choice.pas: Lines 745-750`<br>• `ckInput`, `cakFreeInput`, `csFreeInput`<br>• Text Entry Owns Keyboard 挂起快捷键 | **HIGH** | • 将所有自由输入粗暴归为单一 `cakFreeInput`，未区分人类覆写的具体意图类型（候选拒绝 vs 替代参数 vs 框架否定）。 | 引入 `TEhaiOverrideKind` 三态枚举（`eokCandidateReject`, `eokAlternativeExpression`, `eokFrameRejection`），并在 `THbChoiceAction` 与 `THbChoiceDeck` 中支持显式传递。 |
| **SRC-06** | `FrameRejection`<br>(框架否定) | `DeepBase-HB-AI-Choice-Interaction-Standard.md: §4.3`<br>`DeepBase.VCL.HB.Choice.pas: Line 303`<br>• 仅在注释和文案中提及“打破预设框架” | **MEDIUM** | • 源码中**无独立一等枚举或 AST 支持**。<br>• 缺乏防静默重映射（Non-Remapping Invariant）与未锚定意图保真机制。 | 在 `DeepBase.EHAI.Types` 中建立一等 `TEhaiOverrideKind.eokFrameRejection`，严格禁止静默归并为既有候选。 |
| **SRC-07** | `BackNavigation`<br>(导航回退) | `Core\DeepBase.HB.Choice.Types.pas: Lines 36, 46`<br>`VCL\DeepBase.VCL.HB.Choice.pas: Lines 451-465`<br>• `ckBack`, `cakBack`<br>• 0 返回上一步，非破坏性保留 `FItems` | **HIGH** | • 缺少形式化断言 `0 ≠ Reject ≠ Consent ≠ Judgment` 及不撤销已生效决定的规范说明。 | 在 Core 中确立 `TEhaiMetaAction.emaExit`，严格定义导航回退与业务拒绝的边界。 |
| **SRC-08** | `SourceDistinction`<br>(来源可区分性) | `Core\DeepBase.HB.Choice.Types.pas: Lines 52-59`<br>• `THbChoiceInputSource` (`cisMouse`, `cisKeyboard`, `cisNumPad`...) | **HIGH** | • `THbChoiceInputSource` 仅区分**物理硬件输入设备**，完全未表达**认知语义来源（Epistemic Source）**。<br>• 无法在 Core 中区分 `Human Source` 与 `AI Interpretation`。 | 在 `DeepBase.EHAI.Types` 中定义 `TEhaiSource` (`esHuman`, `esAI`, `esInferred`, `esRule`, `esTool`, `esSystem`)，实现认识来源与硬件设备彻底解耦。 |
| **SRC-09** | `CommitmentBoundary`<br>(承诺边界与效力分界) | `Core\DeepBase.Authorization.pas`<br>• 拥有基础权限检查 | **MEDIUM** | • 缺少 EHAI 承诺门禁模型，未区分探索效应与权威承诺效应。<br>• 未形式化表达 `Standing Authorization` 与 `Rule-derived Authority`（`Need Auth ≠ Need Repeated Auth`）。 | 在 Core 中定义 `TEhaiAuthorityBasisKind` 与 `IEhaiInteractionContract`，支持显式现场确认、事前授权、常设授权与规则授权。 |
| **SRC-10** | `RecoverableLineage`<br>(可恢复的因果血统) | *现有 Core 各模块分散存储* | **LOW** | • 缺少统一的决策上下文绑定与因果血统可恢复结构体。 | 在 Core 中定义 `TEhaiContextBinding` 与 `TEhaiTraceRecord`，支持恢复 Authority Basis, Context, Qualification, Source, Lineage。 |

---

## 三、HB 交互表现层 As-Is 对照矩阵

| 交互特性 | 现有 Delphi 实现 | 差距 (Gap) | 升级改造方案 |
| :--- | :--- | :--- | :--- |
| **0–9 快捷键矩阵** | `THbChoiceDeck.WMKeyDown` 支持 1~7, 8, 9, 0 及 NumPad 对应键 | 已满足基本矩阵 | 保持 100% 向后兼容，补充 `TEhaiMetaAction` 映射。 |
| **Text Entry Owns Keyboard** | `if FState = csFreeInput then Exit;` 挂起 0-9 快捷键 | 已满足 VCL/FMX 键盘独占 | 保持并纳入 `HB-V-001` 回归测试。 |
| **Regenerate 淡化显示** | `FState = csRegenerating` 时 `ApplyAlpha(Tokens.ChoiceOption, 110)` | 已满足视觉参照保留 | 保持并纳入 `HB-V-002` 回归测试。 |
| **Decision Cardinality** | 仅支持单选 (`FSelectedIndex: Integer`) | **缺失多选支持（Multi-choice）**。<br>无法承载 L4 §5.5 的 Multi-choice 倾向标记。 | 在 `THbChoiceDeck` (VCL/FMX) 中增加 `Cardinality: THbChoiceCardinality` (`ccSingle`, `ccMultiple`)、`SelectedKeys: TArray<Integer>`、多选勾选渲染及显式提交机制。 |
| **Frame Rejection 三态下发** | `SubmitFreeInput` 仅传入字符串，统一触发 `cakFreeInput` | **无法传递三态意图** | 增加 `SubmitFreeInputWithKind(const AText: string; AKind: TEhaiOverrideKind)` 与 `TriggerOverrideAction`。 |

---

## 四、领域隔离扫描基线

经扫描，当前 `Core/`、`VCL/`、`FMX/` 代码中：
- 严格不存在 `TCandidateIntent`、`TChangeSet`、`TSpecNode` 等 AsWish 业务模型；
- 严格不存在 `Contact`、`Customer`、`Relationship`、`Touchpoint` 等 AXIS 业务模型；
- 本次升级改造将继续严格维持 **0 领域模型泄漏**。
