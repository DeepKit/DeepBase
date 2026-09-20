# EHAI × HB/AsWish 承接链 001

## Candidate-first + 0–9 + Human Override

### 现状工程实现事实调查记录（As-Is Engineering Realization Record）

---

## §0 文档身份与事实边界 (Document Status)

本报告是对 **HB 视觉系统（DeepBase）** 与 **AsWish 规格反向工程系统** 当前在：
- Candidate-first（AI 候选优先）
- 0–9 交互语法矩阵（0–9 Interaction Grammar）
- Human Override（自由表达 / 人类重载）
- Frame Rejection（框架否定）
- 8 Regenerate（重生成）
- 0 Back（返回）
- Exploration / Commitment separation（探索与裁定分界）

等维度的**真实工程实现现状**的专题事实调查记录。

### 0.1 法律与效力声明
- **文档性质**：`AS-IS ENGINEERING RECORD / NON-NORMATIVE / NON-CONFORMANCE-JUDGMENT`（现状工程事实记录 · 非规范性文件 · 非符合性裁定）。
- **非理论法源**：本记录不是 EHAI 理论规范，不属于 L1～L8 任一层母规范，不创立任何新规则。
- **无裁定效力**：本报告不作任何符合性定级，严禁标定 `PASS`、`FAIL`、`EHAI COMPLIANT` 或 `EHAI NON-COMPLIANT`。
- **职责定位**：本报告仅负责建立真实、可验证的代码级事实台账，为后续 Human Authority 依据 EHAI L7（Applicability → Binding → Conformance）开展正式审阅提供客观依据。
- **执行纪律**：本轮调查严格遵循只调查不修改原则（NO CODE CHANGE, NO PROTOCOL CHANGE, NO ARCHITECTURE REDESIGN）。

---

## §1 调查范围与证据来源 (Investigation Scope)

本调查针对以下代码仓、核心单元、协议基线、测试套件及交付工单进行了完整源码审查与行为追踪：

### 1.1 调查工程仓位
1. **DeepBase（HB 视觉基础设施库）**：`d:\_Progs\02Business\DeepBase`
2. **AsWish（规格反向工程系统）**：`d:\_Progs\02Business\AsWish`

### 1.2 核心审查文件与单元
| 体系 | 文件 / 单元相对路径 | 审查核心内容 |
| :--- | :--- | :--- |
| **HB (DeepBase)** | `Core\DeepBase.HB.Choice.Types.pas` | 0-9 语义类型 (`THbChoiceKind`, `THbChoiceActionKind`, `THbChoiceState`, `THbChoiceItem`, `THbChoiceAction`) |
| **HB (DeepBase)** | `VCL\DeepBase.VCL.HB.Choice.pas` | `THbChoiceDeck` 实现（键盘消息拦截、状态机流转、内置文本编辑、事件下发） |
| **HB (DeepBase)** | `VCL\DeepBase.VCL.HB.Choice.Demo.pas` | 0-9 控件展示窗体（4 种布局模式、多步骤交互流、瀑布流集成） |
| **HB (DeepBase)** | `Tests\Test.DeepBase.HB.Suite.pas` | 0-9 控件自动化单元测试（矩阵断言、输入源解耦、真实状态机、键盘所有权悬挂） |
| **HB (DeepBase)** | `docs\ui\DeepBase-HB-AI-Choice-Interaction-Standard.md` | HB AI 选择交互标准规范文本 |
| **AsWish** | `docs\归档\参考\05-INTERACTION-SPEC.md` | AsWish 双表面交互协议（Conversation vs Decision，0-9 协议原型，Frame Rejection） |
| **AsWish** | `docs\05.协议-AsWish协议基线.md` | §8.1 意图-变更集-裁定追溯链，§8.2 接受基线，§9 不变量约束 |
| **AsWish** | `src\models\AsWish.Models.pas` | 核心数据模型 (`TCandidateIntent`, `TChangeSet`, `TChangeItem`, `TSpecDecision`, `TSpecNode`) |
| **AsWish** | `src\services\AsWish.Services.CandidateIngest.pas` | 候选意图摄入、变更集生成、持久化 YAML 读写、规范合并应用 |
| **AsWish** | `src\services\AsWish.Services.Prompts.pas` | `WriteChangeInterpretPrompt`（大模型意图解构 Prompt 模板） |
| **AsWish** | `src\controllers\AsWish.Controller.pas` | 控制器业务流 (`SubmitUserIntent`, `ReviewChangeSet`, `AcceptChangeSet`, `RejectChangeSet`, `ClarifyChangeSet`) |
| **AsWish** | `cli\AsWish.CLI.dpr` | CLI 意图摄入命令 (`ingest-intent`, `list-intents`, `submit-intent`) |
| **工单履历** | `WO-20260830-0027A~E`, `WO-20260830-0028`, `WO-20260907` | 意图摄入、变更集审计、裁定落盘、Accepted Baseline 实施记录 |

---

## §2 Candidate-first 现状实现 (Candidate-first Current Realization)

### 2.1 架构分层现状：HB 控件层 vs AsWish 业务系统
经代码审查，当前存在重要的**架构分层事实**：
1. **`THbChoiceDeck`（DeepBase）**：定位于**通用 VCL 原生交互控件与状态机**。它负责 0–9 布局渲染（Deck / Row / NumberedList / Inline）、鼠标点击与键盘（含小键盘）快捷键调度、真实状态展现（Ready / Regenerating / FreeInput / NoReliableCandidates / Error）、以及内置文本编辑器排版。**它本身不包含大模型调用代码，不包含业务持久化存储逻辑，不直连任何规范树数据库**。
2. **`AsWish` 系统**：定位于**规格反向工程业务产品**。AsWish 在其早期规范文档（`05-INTERACTION-SPEC.md`）中确立了双表面与 0-9 交互原则。在当前生产代码中，AsWish 的候选生成与审核主要通过 `TAsWishCandidateIngest`、`TAsWishPromptService`、`TAsWishController` 以及基于 EdgeBrowser WebView2 的 HTML 审查页面（`changeset-review.html`）实现。**AsWish 桌面端目前尚未在主窗体上直接实例化并挂载 `THbChoiceDeck` 控件**，二者处于“HB 提供了标准控件与契约，AsWish 实现了后台无头流水线与 Web 审查表面”的工程状态。

### 2.2 候选生成模块与触发
- **AsWish 侧**：
  - 触发点：`TAsWishController.SubmitUserIntent` 或 CLI `submit-intent`。
  - 生成器：调用 `TAsWishPromptService.WriteChangeInterpretPrompt` 生成结构化提示词，委托外部大模型将用户输入或上下文差异解构为候选变更。
  - 产物：输出符合 AsWish YAML 规范的 `TChangeSet` 候选变更集。
- **HB 侧**：
  - 加载入口：`THbChoiceDeck.SetOptions(const AOptions: array of string; ARecommendedKey: Integer = 1)` 或 `THbChoiceDeck.SetCandidates(const ACandidates: array of THbChoiceItem; AAddStandardControls: Boolean = True)`。

### 2.3 候选数据结构
在源码中，存在两个层级的候选数据表示：

```pascal
// 1. HB UI 交互层表示 (DeepBase.HB.Choice.Types.pas: Lines 96-108)
THbChoiceItem = record
  Key: Integer;             // 0..9 键位绑定
  Text: string;             // 候选标题 / 摘要
  Description: string;      // 次级细节说明
  Kind: THbChoiceKind;      // ckOption, ckRegenerate, ckInput, ckBack
  IsRecommended: Boolean;   // 1 号键是否为推荐项 (AI 建议方案)
  Enabled: Boolean;         // 是否可用
  Tag: NativeInt;           // 宿主整型标记
  Payload: NativeInt;       // 宿主领域上下文对象句柄 / 指针
end;

// 2. AsWish 业务语义层候选表示 (AsWish.Models.pas: Lines 184-195)
TChangeSet = record
  Id: string;                     // 变更集唯一 ID (如 cs-func-001-01)
  IntentNodeId: string;           // 关联源规范节点 ID
  IntentTree: TTreeType;          // 目标树类型 (Function / Module / View / Data)
  RawUserIntent: string;          // 原始人类意图 verbatim 拷贝
  Author: string;                 // 作者 (llm / human)
  CreatedAt: TDateTime;           // 生成时间戳
  AffectedProjections: TArray<TTreeType>; // 语义束联动影响的投影树
  Items: TArray<TChangeItem>;     // 具体字段级变更项数组
end;

TChangeItem = record
  TargetNodeId: string;           // 目标节点
  TargetTree: TTreeType;          // 目标树
  Field: string;                  // 变更字段 (如 summary)
  BeforeValue: string;            // 变更前值
  AfterValue: string;             // 变更后建议值
  SourceType: TChangeSourceType;  // cstExplicit, cstInferred, cstUnknown
  Reason: string;                 // AI 解释原因
end;
```

### 2.4 候选数量与 1～7 约束
- **硬编码约束**：在 `THbChoiceDeck.SetOptions`（`DeepBase.VCL.HB.Choice.pas: Lines 378-390`）中：
  ```pascal
  for I := 0 to High(AOptions) do
  begin
    Key := I + 1;
    if Key <= 7 then
      AddOption(Key, AOptions[I], '', Key = ARecommendedKey);
  end;
  AddStandardControls(True, True, True);
  ```
  **事实确认**：候选空间被代码显式限制为 **最多 1～7 项**。超出 7 项的输入在 `SetOptions` 中被直接截断丢弃；8、9、0 键位被保留给系统标准控制项。

### 2.5 候选元数据字段存在性核查
| 元数据字段 | HB `THbChoiceItem` 实现 | AsWish `TChangeSet` / `TChangeItem` 实现 | 事实判定 |
| :--- | :--- | :--- | :--- |
| **id** | 无显式 GUID，以 `Key: Integer (1..7)` 及 `Tag/Payload` 标识 | 具有显式 `Id: string`（如 `cs-func-001-01`）与 `TargetNodeId` | 存在，但 UI 层以数字键槽位寻址 |
| **label / text** | `Text: string` 存储候选摘要文本 | `TChangeItem.Field` + `AfterValue` | 完整存在 |
| **semantic value** | 无直接字符串语义值，依赖 `Payload: NativeInt` 由宿主映射 | 包含 `BeforeValue` 与 `AfterValue` 完整前后语义字串 | 完整存在 |
| **source** | 无 | `SourceType: TChangeSourceType` (`cstExplicit`, `cstInferred`, `cstUnknown`) | 业务层完整存在，UI 层未暴露 |
| **confidence** | 无置信度浮点数；仅支持 `IsRecommended: Boolean`（Key 1） | 无百分比置信度，以 `SourceType` 及 `ReviewStatus` 区分 | 无数值评分，以离散分类存在 |
| **context** | 具有控件级 `ContextTitle: string` 与 `StepInfo: string` | 包含 `AffectedProjections`、`IntentNodeId`、`IntentTree` | 完整存在 |

### 2.6 候选性质：纯 UI 文本 vs 正式语义对象
- 在 **HB 控件层**：候选在呈现上表现为带有样式、徽标、快捷键提示的交互卡片，属于 UI Presentation Object；但其内部持有 `Payload: NativeInt`，允许调用方绑定领域语义句柄。
- 在 **AsWish 业务层**：候选变更集（`TChangeSet`）是**正式的一等语义对象（First-Class Semantic Object）**，具有独立的 YAML Schema、解析序列化服务（`TAsWishCandidateIngest`）以及全生命周期状态追踪。

### 2.7 候选持久化现状
- **HB 控件层**：`THbChoiceDeck.FItems` 纯驻留内存，控件销毁或执行 `Clear` 即清除，不作本地持久化。
- **AsWish 业务层**：`TChangeSet` 显式持久化至磁盘：
  - 默认工作文件：`.AsWish/llm/change-set.yaml`
  - 历史归档路径：`.AsWish/llm/change-sets/<change_set_id>.yaml`
  - 持久化由 `TAsWishCandidateIngest.SaveChangeSet` 实施（`AsWish.Services.CandidateIngest.pas: Lines 678-710`）。

### 2.8 候选选择事件与派生产物
当用户通过键盘或鼠标选中 1～7 号候选时，系统派发：
- **统一交互事件**：`OnAction(Sender, Action: THbChoiceAction)`，载荷包含 `Kind = cakCandidate`, `Key = 1..7`, `Text`, `Payload`, `InputSource`。
- **向下兼容事件**：`OnChoice(Sender, Key: Integer)`。
- **语义下发**：宿主收到事件后，由 `Payload` 或 `Key` 取出对应的语义候选，进入 Human Review 或直接应用。

---

## §3 1～7 Candidate Selection 现状实现 (Candidate Selection Trace)

### 3.1 完整执行链追踪
当用户在真实运行环境中触发 1～7 候选时，完整的内部调用链路如下：

```text
[人类操作] 物理按键 (键盘 1~7 / 小键盘 1~7) 或 鼠标左键点击候选卡片
  │
  ├── 键盘分支: THbChoiceDeck.WMKeyDown(var Message: TWMKeyDown)
  │     ├── 检查 FState <> csFreeInput (确保非文本输入态)
  │     ├── 检查 FIsActiveChoiceSurface = True (确保交互表面激活)
  │     ├── 解析 CharCode / VK_NUMPAD -> DigitKey (1..7), InputSrc (cisKeyboard / cisNumPad)
  │     └── 调用 SelectKey(DigitKey, InputSrc)
  │
  └── 鼠标分支: THbChoiceDeck.MouseUp(Button = mbLeft, X, Y)
        ├── ItemIndexAt(X, Y) 定位卡片索引 Idx
        └── 调用 TriggerAction(cakCandidate, Item.Key, Item.Text, Item.Payload, cisMouse)
              │
              ▼
THbChoiceDeck.TriggerAction(...)
  ├── 实例化统一动作记录 THbChoiceAction.Create(...)
  ├── 触发 FOnAction(Self, Action)
  └── 触发 FOnChoice(Self, AKey)
        │
        ▼
[宿主控制器] (在 AsWish 架构流水线中)
  │
  ├── 1. 获取对应候选 TChangeSet (或已加载的待审变更集)
  ├── 2. 调用 Controller.ReviewChangeSet(ChangeSetId)
  │     └── 渲染 4 层审查表面 (changeset-review.html):
  │           - Layer 1: 变更集摘要与影响范围
  │           - Layer 2: 目标节点当前规格上下文
  │           - Layer 3: 字段级前后对比 (Before vs After) 与来源分类 (explicit/inferred)
  │           - Layer 4: 审查决策操作表面 (Accept / Reject / Clarify)
  │
  └── 3. 人类审查确认后，调用 Controller.AcceptChangeSet(ChangeSetId, Rationale)
        ├── 步骤 A: 记录正式决策
        │     FDecisions.RecordChangeSetDecision(LCS, rsAccepted, ARationale)
        │     -> 生成 TSpecDecision 记录 (写入 .AsWish/decisions/requirement-decisions.yaml)
        ├── 步骤 B: 应用变更至内存树
        │     LIngest.ApplyChangeSet(LCS, LDec, FunctionNodes, ModuleNodes, ViewNodes, DataNodes)
        ├── 步骤 C: 覆盖落盘 Canonical Spec
        │     FSpecStore.WriteTreeFile('trees/function-tree.yaml', ttFunction, FunctionNodes)
        │     FSpecStore.WriteTreeFile('trees/module-tree.yaml', ttModule, ModuleNodes)
        │     FSpecStore.WriteTreeFile('trees/view-tree.yaml', ttView, ViewNodes)
        │     FSpecStore.WriteTreeFile('trees/data-tree.yaml', ttData, DataNodes)
        ├── 步骤 D: 冻结历史基线
        │     FSnapshot.CreateBaseline(LDec, LCS, ...) -> 固化 Accepted Baseline (B-xxxx)
        └── 步骤 E: 刷新视图
              RenderAll
```

### 3.2 关键核查：“选择了 3”到底保存了什么？
- **事实结论**：在当前工程实现中，**最终落盘的绝对不是纯数字 `3`**。
- **证据记录**：
  1. 数字 `3` 仅作为前端路由索引与快捷键触发代号；
  2. 在 `TSpecDecision` 中，落盘持久化的是：
     - `decision_id`（如 `dec-0001`）
     - `change_set_id`（如 `cs-func-001-01`）
     - `decision_type`（`dtAccept`）
     - `title`、`description`、`rationale`（审查意见）
     - `affected_nodes`（受影响的业务节点 ID 列表）
  3. 在规范树文件（`trees/*.yaml`）中，落盘的是由该候选解构出来的**真实业务字段内容**（如修改后的 `summary`、`purpose`、`relations`）。

---

## §4 8 Regenerate 现状实现 (8 Regenerate Realization)

### 4.1 8 键位的正式存在性
- **类型定义**：`DeepBase.HB.Choice.Types.pas` 显式定义 `ckRegenerate` 与 `cakRegenerate`。
- **标准控件**：`THbChoiceDeck.AddStandardControls` 默认注入：
  - Key: `8`
  - Text: `8 换一组候选`（由 `GetDefaultKeyLabel(8)` 派生）
  - Description: `在当前上下文换一组候选`

### 4.2 触发后的状态机流转与视觉表现
- **状态转换**：
  - 调用 `THbChoiceDeck.BeginRegenerate`，控件进入 `FState := csRegenerating`。
  - 触发统一动作：`TriggerAction(cakRegenerate, 8, Text, Payload, InputSource)`。
  - 触发 `FOnChoice(Self, 8)`。
- **视觉真实状态保护**：
  - 源码文件 `DeepBase.VCL.HB.Choice.pas: Lines 1115-1126`：
    ```pascal
    if FState = csRegenerating then
    begin
      // 真实状态：旧候选淡化半透明 (Alpha 110/255)，而非直接空白刷掉
      OptColor := ApplyAlpha(Tokens.ChoiceOption, 110);
      TitleColor := ApplyAlpha(Tokens.TextPrimary, 110);
    end;
    ```
  - **事实确认**：重生成期间旧候选保持可见但淡化（dimmed, not blanked），防止用户视觉跳闪或丢失上一轮参照物。

### 4.3 Regenerate 对 Canonical State 与 Decision 的影响
- **事实核查**：
  - 在 `THbChoiceDeck` 层面：`TriggerAction(cakRegenerate)` 仅通知宿主事件，不触碰任何数据库或文件。
  - 在 `AsWish` 层面：重新请求大模型生成候选，仅输出新的 `TChangeSet` 草稿或更新当前提示词；**绝对不调用 `RecordChangeSetDecision`，绝对不调用 `WriteTreeFile`，绝对不生成 `Accepted Baseline`**。
- **核心结论**：**Regenerate 是纯粹的探索行为（Pure Exploration），在当前工程中完全无法污染正式 Decision 与 Canonical Spec**。

### 4.4 重生成前后的候选可追溯性与 Lineage
- **HB 控件层**：`THbChoiceDeck` 内部**没有实现撤销重做栈（No built-in history stack）**。当宿主加载新的一组候选调用 `SetOptions` 时，旧的 `FItems` 被清空覆盖。
- **AsWish 业务层**：
  - 若调用方为每次生成赋予了不同的 `change_set_id`，则旧变更集保存在 `.AsWish/llm/change-sets/<id>.yaml` 中；
  - 但对于在 UI 交互中高频触发但未保存为文件的瞬态提示交互，系统当前**不存在第一类的 Generation Lineage DAG 追溯图**。未确认的重生成结果在覆盖后无法在 UI 内存中回滚。

---

## §5 9 Human Override 现状实现 (9 Human Override Realization)

### 5.1 触发入口与输入界面流转
当用户按下 `9` 键（或点击“9 我自己说”卡片）时，链路如下：

```text
按键 9 / 鼠标点击 Key 9
  │
  ▼
THbChoiceDeck.SelectKey(9, InputSrc)
  │
  ▼
THbChoiceDeck.TriggerAction(cakFreeInput, 9, Text, Payload, InputSrc)
  │
  ├── 触发 FOnAction(Self, Action)
  ├── 触发 FOnChoice(Self, 9)
  ├── 触发 FOnCustomInput(Self, AText)
  └── 触发 FOnFreeInputRequested(Self, Handled)
        │
        ├── 分支 A: 外部截获 (fimExternal)
        │     Handled := True, 宿主弹出外部对话框
        │
        └── 分支 B: 内置编辑模式 (fimBuiltIn, 默认)
              Handled = False -> 调用 EnterFreeInput('')
                    │
                    ├── FInlineEdit.Text := ''
                    ├── SetState(csFreeInput)
                    ├── FInlineEdit.Visible := True
                    ├── FBtnSubmit.Visible := True
                    ├── FBtnCancel.Visible := True
                    └── FInlineEdit.SetFocus
```

### 5.2 键盘所有权规则：Text Entry Owns Keyboard
在 `DeepBase.VCL.HB.Choice.pas: Lines 745-750` 中存在硬编码保护：
```pascal
procedure THbChoiceDeck.WMKeyDown(var Message: TWMKeyDown);
begin
  // Rule: Text Entry Owns Keyboard (suspend choice shortcuts if free text entry active)
  if FState = csFreeInput then
  begin
    inherited;
    Exit;
  end;
  ...
```
- **事实确认**：一旦进入 `csFreeInput` 状态，**0–9 快捷键被全面挂起（Suspended）**。用户在文本框内输入数字（如输入“修改第 2 项为 100 元”）时，键盘事件完全由 `TEdit` 消费，绝不触发选择操作。
- **提交与取消**：
  - 回车键（`VK_RETURN`）或点击“提交”按钮 -> `SubmitFreeInput`：退出 `csFreeInput` 回到 `csReady`，触发 `TriggerAction(cakFreeInput, 9, TrimmedText, 0, cisKeyboard)`。
  - ESC 键（`VK_ESCAPE`）或点击“取消”按钮 -> `CancelFreeInput`：退出 `csFreeInput`，清空未提交文本，恢复 0-9 快捷键。

### 5.3 自由文本格式与长度限制
- 文本框为原生 VCL `TEdit` 单行输入控件（Demo 中演示可扩展多行）；
- 系统未设置正则表达式拦截，未设置语义字典白名单，**允许输入任意 UTF-8 自由字符串**；
- 唯一校验为 `Trim(AText) <> ''`（空文本不触发提交）。

### 5.4 人类意图捕获对象：`TCandidateIntent`
在 AsWish 控制器中，自由文本被封装为独立的候选意图对象：
```pascal
// AsWish.Controller.pas: Lines 1171-1172
LIntent := TCandidateIntent.CreateNew(ANodeId, ATree, AIntentText, 'human');
LIngest.SaveCandidateIntent(FProjectService.ProjectPath, LIntent);
```
- **作者标记**：明确登记 `Author := 'human'`；
- **文件落盘**：写入 `.AsWish/llm/candidate-intent.yaml` 及 `.AsWish/llm/candidate-intents/<id>.yaml`。

### 5.5 人类原始表达的完整保留
经核查，**人类原始表达在整个链路中被 100% 完整保留，从未被抛弃**：
1. 在 `TCandidateIntent` 中以 `UserIntent` 存储并持久化为 YAML；
2. 在 `TAsWishPromptService.WriteChangeInterpretPrompt` 中：
   ```text
   ## 1. Raw Human User Intent
   - Target Node ID: `<ANodeId>`
   - Target Projection: `<ATree>`
   - Author: `human`
   - User Intent Text:
     > <AIntent.UserIntent 原文内容>
   ```
   作为大模型提示词的首要约束；
3. 在大模型生成的 `TChangeSet` 中以 `RawUserIntent` 字段显式保留；
4. 在 Accepted Baseline（`TAsWishBaseline.Lineage.IntentId`）中与原始意图标号建立强关联。

### 5.6 原始表达与 AI 解释的物理隔离
| 维度 | 人类原始意图 (Human Raw Intent) | AI 解释产物 (AI Interpretation) |
| :--- | :--- | :--- |
| **内存对象** | `TCandidateIntent` (record) | `TChangeSet` (record) |
| **数据内容** | 纯自由文本字串 (`UserIntent`) | 结构化变更数组 (`Items: TArray<TChangeItem>`) |
| **分类属性** | `Author = 'human'` | `SourceType` (`explicit` / `inferred` / `unknown`) |
| **持久化文件** | `.AsWish/llm/candidate-intent.yaml` | `.AsWish/llm/change-set.yaml` |
| **决策效力** | 探索与意图输入，无裁定效力 | 候选提议，无裁定效力 |

**事实确认**：系统在数据结构、持久化文件、业务语义上对“人类说了什么”与“AI 怎么解释的”进行了**完全物理隔离与分别保存**。

### 5.7 AI 是否会静默重映射回 1～7？
- **事实结论**：**不会**。
- **证据记录**：`WriteChangeInterpretPrompt`（`AsWish.Services.Prompts.pas: Lines 552-604`）要求大模型将自由文本解构为对当前节点或关联投影的字段变更（`field`, `before`, `after`, `reason`, `source_type`），**完全不存在任何将自由输入静默归并为原有 1～7 选项之一的逻辑分支或分类器**。

### 5.8 自由输入后的承诺约束
- **事实结论**：**自由输入绝不自动形成 Commitment**。
- 提交自由文本后，系统仅完成 `TCandidateIntent` 落盘并生成 `TChangeSet` 候选提议。它必须进入 `ReviewChangeSet`，由人类在审查表面上明确点击 `Accept` 才能生效；若人类点击 `Reject` 或 `Clarify`，规范树保持一字不变。

---

## §6 Frame Rejection 现状调查 (Frame Rejection Realization)

### 6.1 调查判定状态
针对 Frame Rejection（框架否定 / 打破预设框架），当前工程实现的事实状态为：
> **`PARTIALLY OBSERVED / SPEC-DEFINED / NO DEDICATED AST`**
> （事实部分观察到 · 规范中已明确定义 · 代码中缺少一等 AST 节点）

### 6.2 规范与 UI 现状
1. **UI 引导与文案**：`THbChoiceDeck.AddStandardControls` 将 9 号键描述为：“`手动输入或打破预设框架`”。在 UI 交互层，用户完全可以通过 9 键摆脱 1～7 的选项约束。
2. **AsWish 规范定义**：`docs/归档/参考/05-INTERACTION-SPEC.md` §8 明确定义了 Frame Rejection 概念，强调：
   > “人类不是在现有选项里挑一个，而是指出当前整个问题的问法是错的，或者现有模型边界不适用。”

### 6.3 真实代码实现与断层调查
对 `TAsWishController.SubmitUserIntent`（`AsWish.Controller.pas: Lines 1150-1219`）进行审查，发现了以下关键工程事实：
1. **必须锚定已有节点**：
   ```pascal
   function TAsWishController.SubmitUserIntent(const ANodeId: string;
     ATree: TTreeType; const AIntentText: string): string;
   ```
   当前 API 签名要求必须传入 `ANodeId` 与 `ATree`。人类意图必须挂载在某一个既有树节点上。
2. **场景推演与提示词行为**：
   假设人类输入框架否定言论：
   > *“这些都不是，我决定取消这个项目，重新做架构设计。”*
   - 该文本作为 `AIntentText` 传入 `SubmitUserIntent`；
   - 系统将其与当前节点上下文（`ANode.Title`, `ANode.Summary`）一同打包发给大模型；
   - 大模型被要求输出针对该 `ANodeId` 的 `TChangeItem`（通常会建议修改该节点的 `summary`，或者由于无法理解而将 `SourceType` 标为 `cstUnknown`）；
   - 人类在审查界面中看到该变更，可以通过 `RejectChangeSet` 拒绝该变更集。
3. **关键缺失事实**：
   - 当前系统中**不存在专门表示“框架否定”的一等 AST 节点或协议枚举**（例如不存在 `dtFrameReject` 决策类型，不存在 `FrameRejectionEvent`）；
   - 系统**不支持未锚定节点的顶级意图（Top-level / Unanchored Intent）直接触发树拓扑重构**；
   - 框架否定在底层仍然被当作针对现有节点的“文本输入意图”进行处理。

---

## §7 0 Back 现状实现 (0 Back Realization)

### 7.1 0 键位的真实语义
- **类型定义**：`ckBack` / `cakBack`。
- **默认文案**：`0 返回上一步`（`GetDefaultKeyLabel(0)`）。
- **定位**：纯粹的 **UI Navigation（界面导航回退）**。

### 7.2 概念严格区分核查
在当前代码中，`0 Back` 与其他操作有着严格的边界划分：
```text
Back (0)
  ≠ Reject (审查界面的拒绝决策)
  ≠ Cancel (FInlineEdit 的取消输入)
  ≠ Undo (业务状态或历史版本回滚)
```
- **Back**：仅通知宿主切换回上一屏、上一个向导步骤（Step）或父级导航节点；
- **Reject**：属于决策范畴，调用 `RejectChangeSet` 显式生成 `rsRejected` 决策记录；
- **Cancel**：调用 `CancelFreeInput`，仅关闭文本框并恢复 Ready 状态；
- **Undo**：当前由快照回滚机制（`TAsWishSnapshotService.RollbackSnapshot`）提供，不绑定在 0 键上。

### 7.3 上下文与决策破坏性核查
- **事实结论**：**0 Back 绝不破坏当前上下文，绝不撤销已生效决策**。
- **证据记录**：
  1. `THbChoiceDeck.WMKeyDown` 收到 `0` 键后，调用 `TriggerAction(cakBack, 0, ...)`, 内部 `FItems` 列表保持完整；
  2. 控制器收到 Back 事件后仅执行页面/视图后退，不删除 `.AsWish/trees/*.yaml`，不修改 `.AsWish/decisions/*.yaml` 中的任何历史记录；
  3. 0 Back 不产生任何持久化数据落盘。

---

## §8 探索与裁定分界图 (Exploration / Commitment Boundary)

基于源码实际追踪，HB 与 AsWish 运行时的真实状态流转与承诺边界如下：

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                      1. 纯探索阶段 (Exploration Phase)                  │
│                                                                         │
│  用户交互: 鼠标浏览 / 1~7 临时预览 / 8 换一组候选 (Regenerate) / 0 返回   │
│  UI 状态: csReady / csRegenerating                                      │
│  数据状态: 仅在 THbChoiceDeck 内存中变动 (FItems / FSelectedIndex)      │
│  承诺效力: ZERO (Canonical Spec 树文件与 Decisions 数据库完全零写入)      │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ 用户决定表达意图
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                 2. 意图摄入与候选生成 (Expression / Ingest Phase)        │
│                                                                         │
│  用户交互: 触发 9 我自己说 -> EnterFreeInput -> 输入自由文本 -> 提交     │
│  系统动作:                                                              │
│    1. 实例化 TCandidateIntent ('human')                                 │
│    2. 落盘 .AsWish/llm/candidate-intent.yaml                            │
│    3. 组装 WriteChangeInterpretPrompt 提示词                            │
│    4. 大模型生成 TChangeSet 候选变更集                                  │
│    5. 落盘 .AsWish/llm/change-set.yaml                                  │
│  承诺效力: ZERO (Canonical Spec 树文件保持原样，无正式裁定生成)           │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ 控制器触发 ReviewChangeSet
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       3. 人类审查阶段 (Human Review Phase)              │
│                                                                         │
│  界面呈现: 4-Layer Review 审查表面 (changeset-review.html)              │
│  人类活动: 审查变更目标、前后对比 (Before/After)、AI 推理原因与来源分类 │
│  承诺效力: PENDING (等待法定人类主权裁定)                               │
└──────────────┬─────────────────────┬────────────────────┬───────────────┘
               │                     │                    │
    人类裁定:  │ AcceptChangeSet     │ RejectChangeSet    │ ClarifyChangeSet
═══════════════╪═════════════════════╪════════════════════╪══════════════════
               │ 【唯一合法承诺门禁】  │                    │
               ▼ (Commitment Gate)   │                    │
┌─────────────────────────────────┐  │                    │
│ 4. 裁定生效 (Canonical Spec)     │  │                    │
│                                 │  │                    │
│ 1. RecordChangeSetDecision      │  │                    │
│    -> TSpecDecision (rsAccepted)│  │                    │
│    写入 requirement-decisions   │  │                    │
│ 2. ApplyChangeSet               │  │                    │
│    -> 内存合并更新各 SpecNode   │  │                    │
│ 3. WriteTreeFile                │  │                    │
│    -> 物理覆盖 trees/*.yaml     │  │                    │
│ 4. CreateBaseline               │  │                    │
│    -> 冻结 Accepted Baseline    │  │                    │
│       (B-xxxx 不可变快照)       │  │                    │
└─────────────────────────────────┘  ▼                    ▼
               ┌──────────────────────────────────────────────────────────┐
               │ 5. 拒绝与澄清路径 (Non-Mutating Decisions)                │
               │                                                          │
               │ Reject: 记录 TSpecDecision(rsRejected)                   │
               │ Clarify: 记录 TSpecDecision(rsDeferred)                  │
               │ 物理结果: Canonical Spec 树文件一字不变 (零修改)          │
               └──────────────────────────────────────────────────────────┘
```

---

## §9 语义持久化现状 (Semantic Persistence)

| 语义对象 | 内存类型 (Delphi Record) | 持久化物理路径 | 数据格式 | 变更触发操作 | 是否变动 Canonical Spec |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **人类原始表达** | `TCandidateIntent` | `.AsWish/llm/candidate-intent.yaml`<br>`.AsWish/llm/candidate-intents/<id>.yaml` | YAML | `SubmitUserIntent` / CLI `submit-intent` | **否** |
| **AI 解释变更集** | `TChangeSet` | `.AsWish/llm/change-set.yaml`<br>`.AsWish/llm/change-sets/<id>.yaml` | YAML | 大模型完成解构分析 | **否** |
| **人类裁定记录** | `TSpecDecision` | `.AsWish/decisions/requirement-decisions.yaml` | YAML | `AcceptChangeSet`<br>`RejectChangeSet`<br>`ClarifyChangeSet` | 仅 Accept 时关联树修改 |
| **权威规范树** | `TSpecNode` (树结构) | `.AsWish/trees/function-tree.yaml`<br>`module-tree.yaml`<br>`view-tree.yaml`<br>`data-tree.yaml` | YAML | 仅 `AcceptChangeSet` 调用 `WriteTreeFile` | **是（唯一写入口）** |
| **已接受基线** | `TAsWishBaseline` | `.AsWish/snapshots/<name>/snapshot.yaml` | YAML | `AcceptChangeSet` 触发 `CreateBaseline` | **是（不可变固化）** |
| **UI 交互状态** | `THbChoiceDeck` 字段 | *无持久化（纯内存）* | 内存对象 | 键盘按键、鼠标点击、状态切换 | **否** |

---

## §10 工程事实证据台账 (Evidence Table)

| 事实编号 (Fact ID) | 观察到的工程事实 (Observed Fact) | 确凿代码证据 (Code Evidence) | 确认把握度 (Confidence) |
| :--- | :--- | :--- | :--- |
| **F-01** | `THbChoiceDeck` 显式支持 0-9 完整矩阵，并保留 8、9、0 作为标准控制项 | `DeepBase.HB.Choice.Types.pas: Lines 32-48`<br>`DeepBase.VCL.HB.Choice.pas: Lines 368-376` | **HIGH** |
| **F-02** | 候选选项数量在控件层被显式硬编码约束为最多 1～7 项 | `DeepBase.VCL.HB.Choice.pas: Lines 380-388` (`if Key <= 7`) | **HIGH** |
| **F-03** | 候选 1 号键原生支持 `IsRecommended` 属性，渲染 AI 建议方案专用标记 | `DeepBase.HB.Choice.Types.pas: Line 101`<br>`DeepBase.VCL.HB.Choice.pas: Line 361` | **HIGH** |
| **F-04** | 文本输入态下严格挂起所有 0-9 快捷键（Text Entry Owns Keyboard） | `DeepBase.VCL.HB.Choice.pas: Lines 746-750`<br>`Test.DeepBase.HB.Suite.pas: Lines 1669-1680` | **HIGH** |
| **F-05** | 键盘小键盘（NumPad 0~9）与主键盘数字键具有等价的动作派发能力 | `DeepBase.VCL.HB.Choice.pas: Lines 775-786`<br>`Test.DeepBase.HB.Suite.pas: Lines 1523-1532` | **HIGH** |
| **F-06** | 8 Regenerate 将控件置为 `csRegenerating` 状态，旧选项淡化显示而非置空 | `DeepBase.VCL.HB.Choice.pas: Lines 498-500, 1115-1126` | **HIGH** |
| **F-07** | Regenerate 绝不修改 Canonical Spec 树，绝不写入 Decision 决策文件 | 全局搜索 `WriteTreeFile` 与 `RecordChangeSetDecision` 调用链，无重生成触发路径 | **HIGH** |
| **F-08** | 9 Human Override 支持内置文本输入框（`FInlineEdit`）与外部截获两种模式 | `DeepBase.HB.Choice.Types.pas: Lines 88-91`<br>`DeepBase.VCL.HB.Choice.pas: Lines 473-479` | **HIGH** |
| **F-09** | 人类原始自由文本以 `TCandidateIntent` 完整落盘至 `.AsWish/llm/candidate-intent.yaml` | `AsWish.Controller.pas: Lines 1171-1172`<br>`AsWish.Services.CandidateIngest.pas: Lines 587-601` | **HIGH** |
| **F-10** | 大模型意图解构提示词显式包含人类原文且包含严禁直接修改规范树的系统指令 | `AsWish.Services.Prompts.pas: Lines 554-564` | **HIGH** |
| **F-11** | 大模型解释产物 `TChangeSet` 与人类原始意图 `TCandidateIntent` 分立存储于不同 YAML | `AsWish.Models.pas: Lines 152, 184`<br>`AsWish.Services.CandidateIngest.pas: Lines 587, 678` | **HIGH** |
| **F-12** | 系统的唯一合法承诺门禁为 `AcceptChangeSet`，只有它会触发写规范树与固化基线 | `AsWish.Controller.pas: Lines 1248-1300` | **HIGH** |
| **F-13** | 拒绝变更（`RejectChangeSet`）与要求澄清（`ClarifyChangeSet`）不修改规范树 | `AsWish.Controller.pas: Lines 1304-1368` | **HIGH** |
| **F-14** | 0 Back 仅触发导航与界面后退，不删除上下文，不回滚已存在决策 | `DeepBase.VCL.HB.Choice.pas: Lines 451-465`<br>`AsWish.Controller.pas` 导航流程 | **HIGH** |
| **F-15** | AsWish 生产桌面端当前通过 EdgeBrowser WebView2 呈现变更审查，未直接嵌入 `THbChoiceDeck` | 检查 `AsWish.View.*.pas` 与 `AsWish.dpr`，确认主 UI 采用 `TEdgeBrowser` 渲染 HTML | **HIGH** |
| **F-16** | 系统中缺少 Frame Rejection 的专属 AST 节点或协议枚举，必须依附既有 `ANodeId` | 检查 `TCandidateIntent` 构造函数与 `SubmitUserIntent` 签名 | **HIGH** |
| **F-17** | `THbChoiceDeck` 内部未维护未提交重生成的历史回滚栈 | 检查 `THbChoiceDeck.FItems` 的清空与重置逻辑 | **HIGH** |

*(注：Confidence 仅表示对代码实现与运行事实的查证把握度，不构成 EHAI 符合性评级)*

---

## §11 未确认事项与工程断层 (Unknowns / Missing Evidence)

经地毯式代码调查，以下 3 个工程断层已得到确证并如实登记：

### 11.1 断层一：桌面端 UI 尚未装配 `THbChoiceDeck`（GUI Integration Gap）
- **现象记录**：`DeepBase` 仓中拥有高度完备的 `THbChoiceDeck` 控件实现、单测与 Demo；但 `AsWish` 桌面端现阶段采用的是 VCL 树控件 + `TEdgeBrowser`（加载 `changeset-review.html`）的混合表面。
- **事实状态**：`UNKNOWN / NOT OBSERVED in Production GUI`。在 AsWish 最终发布的桌面安装程序界面上，尚未观察到 `THbChoiceDeck` 原生 VCL 控件与后台流水线的端到端联动，目前主要通过 CLI、单元测试和 WebView2 页面交互。

### 11.2 断层二：重生成过程的瞬态 Lineage 缺失（Transient Generation Lineage Missing）
- **现象记录**：当用户多次点击 8 换一组候选时，若宿主未显式持久化中间结果，这些瞬态候选在大模型重新返回后即被覆盖。
- **事实状态**：`NOT OBSERVED`。系统中缺乏细粒度的“候选代际谱系图（Candidate Generation Lineage DAG）”。

### 11.3 断层三：Frame Rejection 缺少一等 AST 节点支持（No First-Class Frame Rejection AST）
- **现象记录**：框架否定在规范（`05-INTERACTION-SPEC.md`）与 UI 引导文案（`9 我自己说 / 手动输入或打破预设框架`）中均有明确意图，但在控制器 API（`SubmitUserIntent(const ANodeId: string; ...)`）中，强制要求绑定一个已有的规范节点 ID。
- **事实状态**：`PARTIALLY OBSERVED / NO DEDICATED AST`。如果人类要表达“当前整个功能树架构完全错误，废除该分类”，系统无法以一等拓扑操作直接记录，只能作为该节点的一条普通文本意图传递，存在被局部化解释的工程局限。

---

## §12 12 项特别核查问题直接回答 (Answers to Mandatory Questions)

针对任务书中要求重点回答的 12 项问题，事实调查结论如下：

#### 1. 1～7 选择最终保存的是数字还是语义对象？
> **答：保存的是正式语义对象，绝对不是纯数字。**
> 数字（1～7）仅在 UI 层面用作按键捕捉和界面卡片索引。在 AsWish 业务持久化链中，只有经过人类审查并点击 Accept 的变更集才会落盘，落盘实体为具有审计线索的 `TSpecDecision`（写入 `requirement-decisions.yaml`）以及受影响规范树节点中具体字段的修改值（写入 `trees/*.yaml`）。

#### 2. 8 Regenerate 是否污染正式 Decision？
> **答：绝对不会。**
> Regenerate 仅促使系统进入 `csRegenerating` 状态并重新请求大模型生成候选变更集草稿，全程不调用 `RecordChangeSetDecision`，不调用 `WriteTreeFile`。它是一项纯粹的前端探索行为。

#### 3. Regenerate 前后候选是否可追溯？
> **答：文件级可追溯，瞬态交互级不可追溯。**
> 若生成的候选已落盘为带有唯一 `change_set_id` 的 YAML 文件，则历史变更集可在 `.AsWish/llm/change-sets/` 目录查阅；但在 UI 控件内存中，一旦刷新加载新候选，旧候选即被覆盖，无内存撤销栈。

#### 4. 9 是否真正允许自由表达？
> **答：是，完全允许原生自由文本输入。**
> 触发 9 键后激活的原生 VCL 文本输入框不设正则表达式校验，不设受限选项白名单，允许人类键入任意 UTF-8 文本内容。

#### 5. Human 原文是否完整保存？
> **答：是，100% 完整保留。**
> 人类原始自由文本存储于 `TCandidateIntent.UserIntent` 字段，并在 `.AsWish/llm/candidate-intent.yaml` 中原样持久化；在后续的提示词文件及 `TChangeSet.RawUserIntent` 中亦逐字随行，绝不丢弃。

#### 6. AI 是否会重解释 Human 原文？
> **答：是，这是系统设计的明确步骤。**
> 系统通过 `WriteChangeInterpretPrompt` 明确指派大模型将人类原生非结构化意图解构、翻译为结构化的字段级变更建议（`TChangeItem`，包含 `before`、`after`、`field`、`source_type`）。

#### 7. 原文与 AI interpretation 是否可区分？
> **答：完全可区分，物理与数据结构严格隔离。**
> 原文记录于 `TCandidateIntent`（作者标记 `human`，独立 YAML），AI 解释记录于 `TChangeSet`（包含来源分类与推理说明，独立 YAML），二者在代码类型和物理文件上均分立。

#### 8. 9 是否允许拒绝整个 framing？
> **答：UI 与规范允许，但底层缺乏一等 AST 支持。**
> 用户完全可以在 9 号输入框中输入否定当前框架的语句；但由于控制器 `SubmitUserIntent` 强制要求传入现有 `ANodeId`，系统会将此表达附着在当前节点上下文发给大模型，缺乏专门处理框架否定的拓扑级协议实体。

#### 9. Human Override 是否可能被 AI 后续静默覆盖？
> **答：在持久化与决策层面不可能；但存在 AI 理解偏差风险。**
> 依据 AsWish 不变量第 5 条（`generated content cannot silently overwrite locked human decisions`）与代码逻辑，AI 生成的变更集必须经由人类在审查表面显式 Accept 才能写入规范树；未经人类点击同意，AI 解释绝无权限直接覆盖既有规范。但如果人类未经审查误点了 Accept，则 AI 的重解释会成为正式基线。

#### 10. Human 自由输入是否自动形成 Commitment？
> **答：绝对不会。**
> 提交自由文本仅生成候选意图与建议变更集，属于探索与提议范畴；只有在后续的独立审查步骤中显式执行 `AcceptChangeSet`，才会形成 Commitment。

#### 11. 真正改变 Canonical State 的动作是什么？
> **答：唯一动作为 `TAsWishController.AcceptChangeSet`。**
> 无论是 1～7 选择、8 重生成、9 自由输入、要求澄清或拒绝变更，均不会修改 `trees/*.yaml`。只有人类发起 `AcceptChangeSet` 时，系统才会执行 `ApplyChangeSet`、调用 `WriteTreeFile` 覆盖四棵规范树，并生成不可变的 `Accepted Baseline`（`B-xxxx`）。

#### 12. 0 Back 是否破坏当前上下文或已存在 Decision？
> **答：绝不破坏。**
> 0 键的本质是 UI 导航回退，不清除控件内存中的既有候选，不修改任何后端数据库，不撤销任何历史已固化的 Decision 或 Baseline。

---

## §13 潜在承接候选分析 (Potential Binding Candidates)

> [!IMPORTANT]
> **本节声明：以下承接映射仅为技术事实与 EHAI 理论条款之间的初步对应分析，带有 `Binding Candidate Only / Not Yet Human-Approved` 属性，不构成任何正式的 L7 Binding 裁定。正式裁定由 Human Authority 后续执行。**

| HB / AsWish 工程实现实体 | 潜在承接的 EHAI 规范条款 | 承接性质与分析要点 | 候选状态 |
| :--- | :--- | :--- | :--- |
| **`THbChoiceDeck` 1～7 候选空间** | **EHAI L2（AI 交付原则）**<br>· Candidate Delivery<br>· Cognitive Economy | 限制一次最多 7 个选项，且 1 号键承接 Recommended 标记，与 L2 降低人类认知负荷、提供可行动交付物的要求高度契合。 | `Binding Candidate Only`<br>`Not Yet Human-Approved` |
| **`THbChoiceDeck` 8 Regenerate** | **EHAI L3 / L4（交互协议与探索自由）**<br>· Safe Exploration<br>· Non-Commitment Redo | 8 号键允许重生成且证明对 Canonical Spec 零污染，承接了探索行为不得过早引发承诺的协议原则。 | `Binding Candidate Only`<br>`Not Yet Human-Approved` |
| **`THbChoiceDeck` 9 Human Override**<br>(`EnterFreeInput` / `csFreeInput`) | **EHAI L3（人类介入原则）**<br>· Human Self-Expression<br>· Authority Preservation | 允许人类在任意选择关口跳脱 AI 预设候选，自主表达原始意图，承接了人类终局主权原则。 | `Binding Candidate Only`<br>`Not Yet Human-Approved` |
| **Text Entry Owns Keyboard 机制**<br>(`WMKeyDown` 状态挂起) | **EHAI L5（极简人类交互适配）**<br>· Input Modality Protection<br>· Non-Interference | 在人类输入自由文本时，完全悬挂 0-9 选项快捷键，防止打字过程中的数字误触选择，体现了对人类物理输入的严格保护。 | `Binding Candidate Only`<br>`Not Yet Human-Approved` |
| **`TCandidateIntent` 原文持久化**<br>(`.AsWish/llm/candidate-intent.yaml`) | **EHAI L6（机器语义基础设施）**<br>· Truthful Intent Capture<br>· Unaltered Evidence | 人类原始意图与大模型解释产物物理隔离、分别保存，提供了客观真实的意图真相源。 | `Binding Candidate Only`<br>`Not Yet Human-Approved` |
| **`AcceptChangeSet` 唯一承诺门禁**<br>(`WriteTreeFile` + `CreateBaseline`) | **EHAI L3 / L7（裁定边界与实现）**<br>· Explicit Human Commitment<br>· Irreversible State Gate | 确立了只有人类显式确认才能改变真实世界/规范基线的唯一合法写入口，杜绝了 AI 静默自决。 | `Binding Candidate Only`<br>`Not Yet Human-Approved` |

---

## §14 调查结论与后续指针 (Conclusion and Pointers)

1. **事实总结**：
   - HB 控件层（`THbChoiceDeck`）已在 UI 层面完整实现了 0–9 交互语法、1～7 候选收敛、8 重生成探索、9 自由重载以及打字时快捷键防误触机制；
   - AsWish 业务层已在后台管道层面完整实现了“人类原始意图 → 大模型结构化解构 → 人类独立审查 → 唯一决策门禁生效 → 固化 Accepted Baseline”的单向承诺链；
   - 两者的核心理念完全契合，但在“桌面端 GUI 控件直接嵌入”与“Frame Rejection 一等 AST 表达”上存在明确的工程演进空间。
2. **后续工作指针**：
   - 提交本工程事实报告至 Human Authority；
   - 等待 Human Authority 启动基于本报告的 **EHAI L7 Applicability & Conformance 审查**；
   - 不得擅自基于本报告直接开展代码改造或接口重构。

---
*记录完成时间：2026-09-13*
*记录执行人：Antigravity Engine (Pair Programming Agent)*
