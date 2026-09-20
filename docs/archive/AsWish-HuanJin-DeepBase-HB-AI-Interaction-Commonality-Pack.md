# 《AsWish × 唤金 · DeepBase/HB AI交互共性现状资料包》

> **交付性质**：工程现状调查与跨产品资料整理资料包（供上层产品与架构讨论使用）  
> **调查基线**：
> - `DeepBase`: `master` 分支（基线 `commit 2b5b028` · WO-20260905-004/005）
> - `AsWish`: `main` 分支（基线 `commit a21c54c` · WO-0034 / WO-0030 Spike）
> - `DeepAxis`（唤金主仓）: `main` 分支（基线 `commit 698543f` · DA-120~DA-132 / F1-F3b）
> 
> **调查纪律**：只调查、只归纳、只比较、只提供证据；不设计新架构、不修改源码、不发开发工单、不发明新协议、不代替决策层冻结结论。

---

## 0. Executive Summary

### 0.1 核心综述

1. **两个软件最重要的 AI Interaction 共性**：
   无论业务领域是“软件规格逆向推演（AsWish）”还是“微信社交关系经营（唤金）”，两者在人机协作模式上**100% 事实上收敛到了相同的交互内核**：
   $$\text{Human Intent} \longrightarrow \text{AI Context Assembly} \longrightarrow \text{Candidate/Proposal} \longrightarrow \text{Human Judgment} \longrightarrow \text{State Transition}$$
   两端均摒弃了“参数密集型传统表单”与“无序发散型纯聊天流”，确立了**“AI 多想一步给出候选，人类保持终局裁决”**（Candidate-first + Human-in-the-loop）的确定性循环，并在数据层高度一致地将 AI 推理结果解构为“事实（Explicit/Fact）”、“推断（Inferred）”与“未知/待定（Unknown/Insufficient Evidence）”。

2. **当前 DeepBase 已承担多少**：
   - **承担较深的基础支撑**：底层数据访问（FireDAC/SQLite）、加密存储（`DeepBase.Security` 密钥引用）、部分文本处理、全局异常挂钩（`DeepBase.AIErrorHandler`）、进程组合根生命周期（`RuntimeContext`）。
   - **未完全统一步伐**：DeepBase 虽具备完整的 `DeepBaseLLM` 模块（客户端、计费桥、代理），但产品层未完全统一消费，存在各自实现 HTTP 调用的现象。

3. **当前 HB 已承担多少**：
   - **已承担且直接消费**：`THbTheme` 10 套设计令牌体系（唤金 `gold-luxury` 主题由 `THbTheme` 注入驱动）、原子卡片 `THbCard`、状态指示按钮 `THbButton`、`THbTokens` 语义色彩。
   - **已抽象但未被产品生产流消费**：HB 虽已在高阶层冻结了跨平台通用 0–9 交互标准组件 `THbChoiceDeck`（Delphi VCL/FMX 原生控件 `commit ed7b1bc`，37 项单测全绿），且其规范源于 AsWish 早期探索，但**当前 AsWish 与唤金的主生产 GUI 均尚未将该组件实装上线**。

4. **产品层还存在多少重复**：
   存在**大量高价值但各自实现的平行资产**（Semantic Commonality / Separate Implementations）：
   - **LLM HTTP 调用栈**：AsWish 自建 `AsWish.Services.LLM.pas`，唤金自建 `DeepAxis.F3B.Adapters.pas`，DeepBase 基座存在 `DeepBase.LLM.Client.pas`；
   - **上下文预算与组装器**：AsWish 自建 `AsWish.Services.Context.pas`（分层 Token 裁剪），唤金自建 `DeepAxis.Pipeline.Evidence.pas` + 提示词拼装；
   - **审阅与决策界面**：AsWish 采用 WebView2 JS Bridge 渲染四层模型 HTML 页面，唤金采用 VCL 原生 Panel/Grid 分散呈现，两者均未接入 HB 标准 `THbChoiceDeck`；
   - **事实/推断/未知三态模型**：AsWish 建立 `TChangeSourceType`，唤金建立 `TF1EvidenceKind`，语义完全等价但类型隔离。

5. **最值得上层继续研究的共性能力**：
   - **统一决策审阅原语（Decision Surface Primitive）**：将 AsWish 验证成熟的“四层审阅模型（I said → AI understood → Changes → Decision）”与 HB 现成的 `THbChoiceDeck` 原生控件打通，为唤金等后续产品提供开箱即用的“候选裁决卡组”；
   - **统一结构化解释契约（Explicit / Inferred / Unknown Contract）**：将两端高度吻合的三态推断标签提升为基座交互契约；
   - **AI Client & Context Budget Infrastructure**：收口重复的 HTTP 调用、重试退避、BYOK 密钥路由与上下文裁剪逻辑至 DeepBase。

---

### 0.2 十个核心问题深度回答

#### Q1: AsWish 与唤金是否已经事实上形成了一套共同的交互循环？
* **回答**：**是，已经事实上绝对成立。**
* **证据**：
  - AsWish 闭环：`SubmitUserIntent`（意图） $\rightarrow$ `BuildCandidateIntentPrompt` $\rightarrow$ `TChangeSet`（候选） $\rightarrow$ `RecordChangeSetDecision`（Accept/Reject/Clarify 裁决） $\rightarrow$ `MergeInto`（写回）。
  - 唤金闭环：`TF1Judge.Assess`（客观事实与证据输入） $\rightarrow$ `TF1ActionContract`（推荐候选 `fsRecommended`） $\rightarrow$ `TF1Feedback`（人类 Accepted/Modified/Rejected） $\rightarrow$ `Advance`（推进管线）。
  - 尽管两端载体一个是“软件规约”，一个是“联系人触点”，但其“AI 给出提议，人类离散裁决，驳回保持静默，批准方可推进”的控制流拓扑完全一致。

#### Q2: 两个产品目前最明显的 5–10 个 AI Interaction 共性是什么？
* **回答**：
  1. **Candidate-first（候选先行）**：均禁止人类填大量复杂参数，AI 先基于 Context 输出 1~7 项候选；
  2. **Explicit / Inferred / Unknown 三态显影**：均在界面中清晰标注哪些是用户明确要求的、哪些是 AI 推断的、哪些是机器无法确认的未知；
  3. **Non-destructive Reject（非破坏性驳回）**：人类驳回（Reject）或返回（Back）绝不会破坏基线数据或触发异常流；
  4. **Clarify / Override Escape Hatch（人类覆写与澄清安全阀）**：提供逃逸通道允许人类打破 AI 候选框架（AsWish 9键自由说明，唤金 `fkModified` 修改备忘）；
  5. **Regenerate is not Decision（重试非决策）**：重新生成仅请求重构候选空间，不产生业务裁决、不污染审计台账；
  6. **Evidence Lineage Traceability（证据溯源链）**：AI 给出的每个结论都附带证据链（AsWish `SourceRefs`，唤金 `TF1Evidence`）；
  7. **Decision Surface 分离于 Conversation**：均将终审操作隔离在明确的卡片/面板/审阅面上，避免混杂在无限滚动的聊天气泡中；
  8. **Deterministic State Transition（状态机驱动确定性流转）**：所有交互最终沉淀为强类型状态枚举，拒绝弱类型文本驱动。

#### Q3: 这些共性中已经由 DeepBase 提供了哪些？
* **回答**：
  - 加密存储与密钥隔离（`DeepBase.Security` / `key.db`）；
  - 基础运行环境与进程级服务容器（`RuntimeContext` / `Manager`）；
  - 状态槽抽象接口（`Core/DeepBase.HB.StateSlot.Types.pas` 中的 `IHbStateSlotProvider`）；
  - 基础数据连接池与 SQLite 运行时（`DeepBasePersistence`）。

#### Q4: 已经由 HB 提供了哪些？
* **回答**：
  - **设计令牌与语义色**：`DeepBase.HB.Core.pas`、`DeepBase.HB.Palettes.pas`（已在唤金主窗体中应用 `gold-luxury` 主题，提取 `Tokens.Surface`、`Tokens.Ink` 等绘制矢量卡片）；
  - **通用控件原语**：`THbButton`、`THbCard`（唤金用于顶部工具栏 `FTopToolbarCard` 及各类操作入口）；
  - **交互规范与独立组件**：`DeepBase.HB.Choice.Types.pas` 与 `DeepBase.VCL.HB.Choice.pas` / `DeepBase.FMX.HB.Choice.pas`（`THbChoiceDeck` 实现了完整的 0–9 协议、4 种布局、8 种状态、内外联动输入），但目前处于“已交付待接入”状态。

#### Q5: 哪些目前由两个产品分别重复实现？
* **回答**：
  - **LLM HTTP 请求与鉴权**：AsWish 的 `TAsWishLLMService` 与唤金的 `TRealLLMAdapter`；
  - **Prompt 组装与 Token 预算裁剪**：AsWish 的 `TContextAssembler` 与唤金的 `TF1Judge` / `TSloganPipelineB`；
  - **结构化提议比对**：AsWish 的 `AsWish.Services.Difference.pas` 与唤金的 `AssetReportPanel` / 审计比对逻辑；
  - **AI 交互审阅表面**：AsWish 基于 WebView2 自行编写 HTML/CSS 渲染 0–9 审阅卡组；唤金使用标准 VCL `TPanel` + `TStringGrid` + `TButton` 拼装建议面板。

#### Q6: HB Choice 是否已经成为真正的跨产品 AI Interaction Primitive？
* **回答**：
  - **规范语义层面**：**是**。两端产品规范文档均明确引用 HB 0–9 协议（AsWish `docs/03.规范-可见判断与交互规范.md`；唤金 `docs/23-唤金顾问体系与四自接触点规范.md`）；
  - **工程运行层面**：**尚不是**。两端产品在实际运行代码中均未直接 `uses DeepBase.VCL.HB.Choice` 并将其实例化挂载到生产窗体上。HB Choice 当前是一个**设计成熟、测试完备（37/37 Green）、但尚未被两端实装的就绪原语**。

#### Q7: 当前有没有真正的 Semantic Action Layer 雏形？
* **回答**：**有，但处于局部高阶抽象，未上升为通用总线。**
* **证据**：
  - AsWish 控制器提供明确语义方法：`SubmitUserIntent`, `ReviewChangeSet`, `AcceptChangeSet`, `RejectChangeSet`, `ClarifyChangeSet`，JS Bridge 通信采用 `changeset-accept` 等语义动作名；
  - 唤金核心领域层提供：`Enqueue`, `Transition`, `RecordFeedback(fkAccepted/fkModified/fkRejected)`, `Approve`, `ProcessMessage`。两端内部均不是通过模拟点击坐标或模拟敲键盘来改变业务状态，而是调用强类型语义动作。然而，这些动作目前深植于各自领域控制器中，没有统一的 `ISemanticActionInvoker`。

#### Q8: 当前 UI 是否能够知道“这个控件在语义上是什么”，还是主要只知道“这是 Button / Panel / Label”？
* **回答**：**处于过渡阶段，开始具备语义色感知，但布局容器依然偏向物理控件。**
* **现状分析**：
  - **已知语义的部分**：通过 HB Tokens，控件知道自己当前处于 `ToneBrand`、`ToneSuccess`、`ToneWarning`、`ToneDanger` 还是 `ToneNeutral`，HB 按钮知道自己是 `bkPrimary`、`bkSecondary` 还是 `bkGhost`，HB ChoiceDeck 知道自己是 `cakCandidate`、`cakRegenerate` 还是 `cakFreeInput`；
  - **未知语义的部分**：在唤金的 `TagSuggestPanel` 和 AsWish 的 `MainForm` 中，界面主体依然由普通的 `TPanel`、`TStringGrid`、`TListBox` 拼装，宿主窗体只把它们当成原生 Win32 控件句柄操作，缺乏“这是证据槽（EvidenceSlot）”、“这是候选槽（CandidateSlot）”的元数据自省能力。

#### Q9: 目前两个产品中，人类输入最可以被 AI 压缩的共同场景是什么？
* **回答**：
  1. **复杂对象的结构化增删改（Parameter-free Entity Mutation）**：用户仅用自然语言表达一个模糊意向，AI 自动将其展开为几十个关联字段的前后差异（Before/After）与外键关系，人类只需一键 Accept；
  2. **海量异构事实中的关键异常筛选（Signal-over-Noise Screening）**：用户无需翻阅上千行代码变更或几千条微信会话流水，AI 自动提炼出“客观事实差异（Facts）”与“待确认风险（Unknowns）”，人类只需对生成的少量 Action Contract 进行拍板；
  3. **沟通与表达初稿拟定（Drafting & Slogan Generation）**：人类无需从零构思沟通切入点，AI 结合历史情境输出高匹配候选，人类输入压缩为“选择合适候选”或“微调局部词句”。

#### Q10: 从现状证据看，下一轮最值得讨论的 DeepBase/HB 共性问题是什么？
* **回答（仅提议讨论议题，不越界做决策）**：
  - **议题 1**：HB 已经交付的 `THbChoiceDeck`（VCL/FMX）如何以最低成本实装进 AsWish（替换/接管 WebView2 中的 0–9 HTML 渲染）与唤金（替换 `TagSuggestPanel` 等离散按钮）？
  - **议题 2**：是否应当在 DeepBase 中建立统一的 `IDeepBaseLLMClient` 接入层，强制归拢 AsWish 与唤金两套孤立且重复的 `System.Net.HttpClient` 代码？
  - **议题 3**：AsWish 的 `cstExplicit / cstInferred / cstUnknown` 与唤金的 `Facts / Inferences / Unknowns`，是否具备抽象为 `DeepBase.HB.AI.Types` 通用推断三态资产的价值？
  - **议题 4**：唤金强烈诉求的 `THbDisclosureBox`（渐进展开容器）与 `THbTimeline`（时间线追踪），是否作为第二批 HB 原生原语立项？

---

## 1. 调查范围与证据来源

### 1.1 调查物理路径与工程基线

| 目标代码库 | 本地根路径 | 当前工作分支 | 关键提交 / 标签基线 | 核心职责与业务形态 |
| :--- | :--- | :--- | :--- | :--- |
| **DeepBase** | `d:\_Progs\02Business\DeepBase` | `master` | `commit 2b5b028`<br>`ed7b1bc` (WO-004 Choice) | 底层系统运行时、持久化、HB 视觉系统、LLM 基础设施 |
| **AsWish** | `d:\_Progs\02Business\AsWish` | `main` | `commit a21c54c` (WO-0034)<br>`v0.1.0` (Tag) | AI 原生需求规约与反向工程系统，0–9 协议探索发源地 |
| **唤金 (DeepAxis)** | `d:\_Progs\02Business\DeepAxis` | `main` | `commit 698543f` (DA-131)<br>DA-120~DA-132 演进 | 微信商业关系经营系统、客户意向判定、触点履约与话术 |

### 1.2 证据核查方式
1. **源码走查**：逐行查验 Pascal 单元（`Core`, `VCL`, `FMX`, `src`, `pipeline`, `services`）的接口声明、数据结构、生命周期与调用链；
2. **测试报告核验**：审查 `TestResults/` 下的 XML/TXT 测试日志（AsWish 151/151 Green，DeepBase HB 37/37 & 90/90 Green）；
3. **工单与规范核对**：比对三方仓库中关于 UI 规范、交付报告与评审结论的真实记录（包括 `WO-20260905-004`、`WO-20260830-0027D-R1`、`DA-121`、`DA-125`、`DA-128` 等）。

---

## 2. 当前 DeepBase / HB / Product 实际分层

### 2.1 真实工程依赖拓扑

```text
                                  +---------------------------------------+
                                  |         DeepBase Core & RTL           |
                                  |  (Security, Persistence, Base Utils)  |
                                  +---------------------------------------+
                                          ▲                       ▲
                                          │                       │
                                          │ 源码/包引用           │ 独立实现/无源码引用
                                          │                       │ (Zero External Dep)
                     +--------------------+----+                  │
                     |    DeepBase HB 基座     |                  │
                     | (Core, Palettes, VCL,  |                  │
                     |  FMX, Controls, Choice)|                  │
                     +-------------------------+                  │
                             ▲         ▲                          │
             uses/linkage    │         │ 仅规范对齐               │
             (强依赖)        │         │ (无物理引用)             │
                             │         │                          │
        +--------------------+---+   +-+--------------------------+----+
        |   唤金 (DeepAxis)      |   |            AsWish               |
        |                        |   |                                 |
        | • 启动初始化 THbTheme  |   | • 独立实现 TAsWishLLMService    |
        | • 窗体引用 THbCard/Btn |   | • 独立实现 TContextAssembler    |
        | • 独立实现 F3b LLM     |   | • 独立实现 4-Layer Review HTML  |
        | • 自建 F1 Action 队列  |   | • 独立维护 Canonical Spec       |
        +------------------------+   +---------------------------------+
```

### 2.2 跨层引用与边界反向检查
1. **产品 $\rightarrow$ DeepBase 正常消费**：
   - 唤金（`DeepAxis.dpr`）在启动入口明确调用 `THbTheme.Initialize` 并应用 `'gold-luxury'` 主题；在 `DeepAxis.UI.MainForm.pas` 中引用 `DeepBase.HB.Core`, `DeepBase.VCL.HB.Theme`, `DeepBase.VCL.HB.Controls`, `DeepBase.VCL.HB.Cards`。
2. **产品自行重复实现（隔离孤岛）**：
   - AsWish 坚持“Zero external database or proprietary framework dependencies”设计哲学，其项目工程文件 `AsWish.dpr` 未包含任何 DeepBase 或 HB 单元，导致 AsWish 在工程上完全独立自研了一套等价的 Token 映射、LLM 客户端与 Review 呈现引擎。
3. **HB 反向感知检查（无违规）**：
   - 审查 `DeepBase/Core/DeepBase.HB.*.pas` 及 `DeepBase/VCL/DeepBase.VCL.HB.*.pas`，确认**未出现**任何 AsWish（如 `TSpecNode`, `ChangeSet`, `DfmParser`）或唤金（如 `WeChat`, `ContactDB`, `Lighthouse`, `WorthSeeing`）的业务专有名词。HB 基座严格遵守零业务侵入纪律。
4. **DeepBase 出现产品概念检查（无违规）**：
   - 早期个别历史实验字段（如 `THbListRow` 中的 `FreeButtonText`、`PointsCost`）已在工单 `docs/ui/DeepBase-HB-x-HuanJin-UI-Capability-Gap-Analysis.md` 中被标记为需解耦债务，未发生结构性反向渗透。

---

## 3. AsWish × 唤金 AI Interaction 总体共性图

两端系统在剔除具体业务外壳后，其真实人机行为视觉流转拓扑如下：

```text
                [ Human Actor ] (人类操作者)
                      │
        ┌─────────────┴─────────────┐
        │ 1. 表达意图 (Intent)       │
        ▼                           ▼
[ 自然语言意图输入 ]         [ 结构化上下文选择 ]
 (AsWish: 修改说明)          (唤金: 筛选联系人/雷达)
        │                           │
        └─────────────┬─────────────┘
                      ▼
           [ 2. AI Context Assembly ]
     (组装当前实体、历史事实、策略规则、Token预算)
                      │
                      ▼
          [ 3. AI Interpretation & Generation ]
    (解构事实 vs 推断 vs 未知；生成候选空间或话术)
                      │
        ┌─────────────┴─────────────┐
        ▼                           ▼
[ AsWish: TChangeSet ]      [ 唤金: TF1ActionContract / Slogan ]
(Explicit / Inferred / Unknown) (Facts / Inferences / Unknowns)
        │                           │
        └─────────────┬─────────────┘
                      ▼
        [ 4. Observable Presentation Surface ]
      (非发散聊天窗口；结构化卡组/差异表/四层审阅模型)
                      │
                      ▼
             [ 5. Human Judgment ]
   ┌──────────────────┼──────────────────┐
   ▼                  ▼                  ▼
[ Accept / 批准 ]   [ Reject / 驳回 ]  [ Clarify / 覆写 ]
 (AsWish: 1 键)      (AsWish: 4 键)     (AsWish: 3/9 键)
 (唤金: fkAccepted)  (唤金: fkRejected) (唤金: fkModified)
   │                  │                  │
   ▼                  ▼                  ▼
[ 状态机正式推进 ]  [ 保持基线静默 ]   [ 修正参数重新生成 ]
(Merge Into Spec)  (不污染正式规范)   (输入逃逸 / 框架否定)
(Enqueue to Send)  (记录审计台账)     (重构 Candidate 空间)
```

---

## 4. Human Intent 共性

### 4.1 表达通道比较

| 表达通道 | AsWish 表现形式 | 唤金 表现形式 | 共通模式 |
| :--- | :--- | :--- | :--- |
| **自然语言输入** | 节点详情页底部“人类自然语言修订”输入框，支持多行模糊意图表达 | 话术场景描述、自动回复规则输入、或外部微信消息自然语言输入 | 将人类难以形式化表达的诉求，以原始非结构化文本形式输入系统 |
| **结构化点选** | 4 树规范节点选择、0–9 数字键/小键盘快速点选、分项检查框 | 联系人列表选中、雷达象限选择、建议列表行选择 | 提供高密度点选锚定上下文实体，避免用户重复输入“我在操作谁” |
| **人类覆写 (Override)** | `[9] 我自己说明`：支持人类打破 AI 当前提问框架（Frame Rejection） | `fkModified`：允许人类在接受前手动修改 AI 话术或附加 `ModifiedNote` | 人类永远拥有逃逸通道与打破候选封闭空间的最高权力 |
| **非决策性刷新** | `[8] 重新生成理解`：请求 AI 换一种思路重新表达 | `刷新建议` / `重新生成话术`：仅重构候选集合 | 允许人类在不触发任何业务副作用的前提下探索更多可能性 |
| **返回与退出** | `[0] 返回上一步`：仅做界面与步骤回退，严禁等同于 Reject | 对话框取消 / 抽屉关闭 / 退出当前上下文 | 纯粹的 UI 导航语义，不改变底层业务状态 |

### 4.2 核心共性归纳
两端均严格禁止“必须填写全量表单方可开始”的传统 GUI 路径，但也排斥“让用户在空无一物的对话框中自己想 Prompt”的纯 Chat 模式。两端均采用**“上下文锚定（Context Pinning）+ 少量自然语言意向 + 离散动作修饰”**的复合意图输入机制。

---

## 5. AI Interpretation 共性

### 5.1 数据结构与调用链取证

#### AsWish 链路
- **源码文件**：[`AsWish.Services.CandidateIngest.pas`](file:///d:/_Progs/02Business/AsWish/src/services/AsWish.Services.CandidateIngest.pas)、[`AsWish.Models.pas`](file:///d:/_Progs/02Business/AsWish/src/models/AsWish.Models.pas)
- **关键数据结构**：
  ```pascal
  TChangeSourceType = (cstExplicit, cstInferred, cstUnknown);

  TChangeItem = record
    TargetNodeId: string;
    TargetTree: TTreeType;
    Field: string;
    BeforeValue: string;
    AfterValue: string;
    SourceType: TChangeSourceType;
    Reason: string;
  end;
  ```
- **核心过程**：用户输入自然语言 $\rightarrow$ `TAsWishPromptService` 注入系统 Prompt $\rightarrow$ LLM 返回带解释的结构化 YAML $\rightarrow$ `TCandidateIngest` 强类型沙箱校验字段合法性 $\rightarrow$ 生成 `TChangeSet`。

#### 唤金 (DeepAxis) 链路
- **源码文件**：[`DeepAxis.F1.Judge.pas`](file:///d:/_Progs/02Business/DeepAxis/src/f1/DeepAxis.F1.Judge.pas)、[`DeepAxis.F1.Types.pas`](file:///d:/_Progs/02Business/DeepAxis/src/f1/DeepAxis.F1.Types.pas)
- **关键数据结构**：
  ```pascal
  TF1EvidenceKind = (ekFact, ekInference, ekCounter);

  TF1AssessmentOutput = record
    ContactId: string;
    Kind: TF1JudgmentKind;
    Confidence: Integer;
    Facts: TArray<string>;
    Inferences: TArray<string>;
    Unknowns: TArray<string>;
    Reasons: TArray<string>;
    CounterEvidence: TArray<string>;
    RuleVersion: string;
    AssessedAtUtc: TDateTime;
  end;
  ```
- **核心过程**：输入联系人客观交互历史 $\rightarrow$ `TF1Judge.Assess` 执行确定性规则分析 $\rightarrow$ 严格拆解为客观事实（`Facts`）、推断结论（`Inferences`）与缺失信息（`Unknowns`） $\rightarrow$ 组装为行动意向契约 `TF1ActionContract`。

### 5.2 语义等价性分析
两个产品在不同的业务场景中，**不约而同地设计了完全同构的解释输出模型**：
1. 区分“什么是铁的事实 / 用户明确说的”；
2. 区分“什么是 AI 自己猜的 / 推导的”；
3. 区分“什么是目前尚不知道、需要人工介入确定的”。

---

## 6. Candidate-first Interaction 共性

### 6.1 交互流程对比

```text
[ 传统表单交互 ]   Human 录入 10 个参数  ───► 提交 ───► 系统执行
[ 唤金/AsWish ]   Human 给出意向/实体   ───► AI 给出候选空间 ───► Human 审阅并判断
```

* **AsWish 实践**：
  - 在意图提出后，系统自动呈现 1–7 候选区；
  - 键位 `1` 作为推荐候选（`IsRecommended = True`），但仅表示建议，严禁自动采纳、严禁回车静默提交；
  - 提供 `8 重新生成` 与 `9 自由覆写`。
* **唤金 实践**：
  - F1 行动队列中，AI 输出 `jkRecommended` 推荐动作卡片；
  - F3 话术生成中，AI 输出若干条不同风格的开场白候选；
  - 标签建议面板中，AI 列出带置信度百分比的标签操作建议（合并、提取、补充）；
  - 人类无需手写整段回复或手动整理全量标签，仅需对候选列表执行行选或确认。

### 6.2 四分类判定
- **完全相同**：Candidate-first 交互哲学、推荐不等于终审决策、必须提供人类覆写通道；
- **语义相同但表现不同**：候选呈现控件（AsWish 采用内联卡组，唤金采用 StringGrid 与 ListBox）；
- **部分相同**：快捷键体系（AsWish 严格落地 0–9；唤金仅在文档规范定义，代码中仍以鼠标点击为主）；
- **产品特有**：AsWish 的多投影级联变更（4 Trees），唤金的商业点数扣减（Credits Settle）。

---

## 7. Choice / Judge / Accept / Reject / Clarify 共性

### 7.1 裁决动作矩阵

| 裁决意图 | AsWish 映射 | 唤金 映射 | HB 规范映射 (`THbChoiceActionKind`) |
| :--- | :--- | :--- | :--- |
| **接受采纳** | `Accept` (`[1]`, `rsAccepted`) | `fkAccepted` / `Approve` | `cakCandidate` (选定 Key) |
| **完全驳回** | `Reject` (`[4]`, `rsRejected`) | `fkRejected` | 业务层处理（非 0 键） |
| **补充澄清/修改**| `Clarify` (`[3]`, 弹出澄清表单) | `fkModified` (带 `ModifiedNote`) | `cakFreeInput` (Key 9) |
| **重新推演** | `Regenerate` (`[8]`, 非决策) | `Regenerate` (非决策) | `cakRegenerate` (Key 8) |
| **人类自填** | `Escape / Input` (`[9]`, 自由输入) | 手动编辑文本框 | `cakFreeInput` (Key 9) |
| **退出导航** | `Back` (`[0]`, 仅导航) | 窗口返回 / 关闭 | `cakBack` (Key 0) |

### 7.2 核心铁律在两端的贯彻
1. **驳回不产生污染（Non-destructive Rejection）**：
   - AsWish 中点击 Reject，仅将 ChangeSet 标记为已驳回，并向 `decisions.yaml` 写入一条拒绝记录，正式规约文件零修改；
   - 唤金中拒绝 F1 推荐或不批准 F3 话术，数据绝对不会流向 `TF2SendQueue`，微信真实发送队列零入队。
2. **重试不是裁决（Regenerate is not Decision）**：
   - 两端均严格禁止“点击换一批自动保存当前数据”的流氓行为。

---

## 8. Conversation 与 Decision 类交互

### 8.1 探索面与决策面的工程分化事实

在 AsWish 和唤金的代码实现中，均可清晰观察到两类界面的物理分离：

1. **探索类交互（Conversation / Exploration Surface）**：
   - 特征：多轮、非结构化、发散、允许容错；
   - AsWish 表现：节点详情页中的自然语言留言板、Clarify 时的补充说明输入框；
   - 唤金 表现：微信原始会话历史的被动监听分析、自动回复规则的模糊配置。
2. **判断类交互（Decision Surface）**：
   - 特征：离散、强类型、结构化、不可逆持久化、强审计；
   - AsWish 表现：Review Surface 页面（I said $\rightarrow$ AI understood $\rightarrow$ Changes $\rightarrow$ Decision），在此页面用户无法漫无边际聊天，只能进行确认、驳回或跳转；
   - 唤金 表现：F1 Action Queue、话术审批面板、L2a 逐条写回确认弹窗。

> **工程共性结论**：两个产品均自发抵制了“将全功能塞进一个 Chat 对话框”的简陋做法。**AI 生成的内容必须落地到具备结构化边界的“决策面”上供人类审阅。**

---

## 9. AI Result Presentation 共性

两端在展示 AI 生成结果时，呈现组件均包含以下 6 维信息契约：

```text
+-----------------------------------------------------------------------+
|  [ 1. 方案摘要 / 候选标题 ] (Proposal / Candidate Title)               |
+-----------------------------------------------------------------------+
|  [ 2. 理由阐述 (Rationale / Why) ]                                    |
|      "为什么推荐该操作 / 依据何种规则版本"                            |
+-----------------------------------------------------------------------+
|  [ 3. 证据溯源与推断分级 (Facts vs Inferences vs Unknowns) ]         |
|      • 事实依据 (Explicit/Facts): 已被验证的上下文/用户原话           |
|      • 算法推断 (Inferred): 关联猜测与推荐理由                        |
|      • 待定未知 (Unknowns): 尚未搜集到的关键阻断项                    |
+-----------------------------------------------------------------------+
|  [ 4. 影响范围 (Impact / Affected Areas) ]                            |
|      • 涉及投影/字段 (AsWish: Function/View; 唤金: 客户阶段/联系人)   |
+-----------------------------------------------------------------------+
|  [ 5. 前后对比 (Before vs After / Diff) ]                             |
|      • 原始状态 (Before) ────► 拟变更为 (After)                       |
+-----------------------------------------------------------------------+
|  [ 6. 确定性裁决动作条 (Action Deck / 0–9 / Buttons) ]                |
+-----------------------------------------------------------------------+
```

---

## 10. Human Input Compression 真实案例

### 10.1 AsWish 真实案例

#### 案例 A-01: 自然语言修改规范节点
* **Human originally needs to provide**:
  在数百个 YAML 节点中手动检索对应 ID；手工比对 Function、Module、View、Data 四个投影的外键关联；手动书写严格符合 schema 约束的 YAML 语法块；手动计算版本 hash。
* **AI currently handles**:
  `TAsWishPromptService` 组装当前节点及关联投影上下文；LLM 识别修改意图并推导出跨投影影响；`TCandidateIngest` 校验并生成带 Before/After 及推理理由的 `TChangeSet`。
* **Human finally only needs to**:
  在 Review Surface 浏览对比表，敲击数字键 `1`（Accept）或 `4`（Reject）。
* **HB involved**:
  HB 0–9 交互标准定义（当前在 WebView2 中以 HB 语义色渲染）。
* **DeepBase involved**:
  底层字符串处理与 Hash 校验。

#### 案例 A-02: 代码逆向解析推演规范树
* **Human originally needs to provide**:
  通读 Pascal 单元及 DFM 表单定义；提取所有 UI 控件层次与事件响应；手动建立窗体与业务模块的映射关系。
* **AI currently handles**:
  `TAsWishScanService`（DfmParser / PasParser）自动扫描源码 AST；`TreeBuilder` 自动构建 4 树草稿；AI 自动推断功能摘要并标注迷雾状态（`TFogState`）。
* **Human finally only needs to**:
  在 VCL 树形控件中查看带有黄色/绿色状态标记的节点，点击确认或微调。
* **HB involved**:
  设计令牌色阶（用于不同深度与状态的背景色）。
* **DeepBase involved**:
  基础文件与路径扫描。

#### 案例 A-03: 视觉基线差异自动化审查 (WO-0030 Spike)
* **Human originally needs to provide**:
  人工肉眼比对实际运行窗体与设计规范的像素级偏差；逐一测量控件位置（Left/Top/Width/Height）与色彩数值；编写测试缺陷单。
* **AI currently handles**:
  运行时自动反射提取 VCL 控件真实属性（Bounds, Color, Font）；对比引擎生成包含 L2（布局偏差）与 L3（样式偏差）的 `TSpecDifferenceReport`。
* **Human finally only needs to**:
  在差异裁决列表中选择 `djAcceptable`（接受容差）或 `djUnacceptable`（要求返工）。
* **HB involved**:
  VCL 控件绘制规范。
* **DeepBase involved**:
  无（AsWish 侧 Spike 验证）。

---

### 10.2 唤金 (DeepAxis) 真实案例

#### 案例 H-01: 微信海量联系人沉睡唤醒评估 (F1 Assessment)
* **Human originally needs to provide**:
  逐一翻阅数千个微信好友的聊天记录；记忆上次互动时间；判断对方是否具有商业潜在意向；排查是否存在利益冲突或免打扰约束。
* **AI currently handles**:
  `TF1Judge.Assess` 自动拉取交互流水，基于确定性规则版本计算张力；自动过滤敏感与黑名单；输出包含 Facts、Inferences、Unknowns 的结构化推荐结果与理由。
* **Human finally only needs to**:
  在联系人雷达或唤醒卡片上，针对生成的动作契约执行确认（`fkAccepted`）或驳回（`fkRejected`）。
* **HB involved**:
  `THbTheme` 当前主题（`gold-luxury`）的 `Tokens.SurfaceAlt`、`Tokens.Border` 等颜色注入。
* **DeepBase involved**:
  `DeepBase.HB.Core` 令牌接口。

#### 案例 H-02: 破冰跟进话术智能生成 (F3/F3b Pipeline)
* **Human originally needs to provide**:
  构思符合对方身份与当前关系阶段的跟进话术；注意字数与微信防骚扰规则；避免生硬销售推销。
* **AI currently handles**:
  `TSloganPipelineB` 结合联系人画像与历史情境调用 LLM；自动执行文本长度与合规校验；自动计费并预留点数；生成待审批草稿（`DRAFT_READY_FOR_USER_EDIT`）。
* **Human finally only needs to**:
  在预览面板中查看话术与风险评分，一键点击 `Approve` 批准入队，或直接原位复制修改。
* **HB involved**:
  `THbButton` 操作按钮与卡片容器。
* **DeepBase involved**:
  `DeepBase.Security` 密钥引用，点数扣减抽象模型。

#### 案例 H-03: 微信好友标签与备注整理 (Tag Suggestion L0-L1-L2a)
* **Human originally needs to provide**:
  人工打开微信资料卡；根据聊天内容提炼对方职务、公司、需求；手动打字保存备注。
* **AI currently handles**:
  `TTagEngine` 扫描会话流水，自动识别 `merge` / `extract` / `add` / `product_match` 操作；计算置信度并在后台生成 `TTagSuggestion` 列表。
* **Human finally only needs to**:
  在 `TTagSuggestPanel` 列表中选中有价值的建议，点击 `逐条执行(L2a)` 确认写回微信。
* **HB involved**:
  面板底层继承与视觉着色。
* **DeepBase involved**:
  SQLite 缓存与数据轮询。

---

### 10.3 现状中依然要求人类大量输入的断点记录
1. **AsWish**: 当 AI 推理跨投影冲突过大时，系统无法自动收敛，必须要求人类在 `Clarify` 文本框中手工键入详细的设计原则说明；
2. **唤金**: 微信 4.x 本地环境的扫码绑定、密钥提取失败时，仍需大量手工配置；会话策略（如跨夜免打扰的具体分钟数、黑白名单名单字符串）仍依赖用户手动配置。

---

## 11. AI Output → Human Judgment 真实闭环案例

### 案例 1: AsWish 自然语言修改规范闭环
```text
Human Intent: 用户在 node-detail.html 底部输入："为本窗体增加深色模式适配" 并提交
    ↓
AI Operation: TAsWishController.SubmitUserIntent 调用 LLM 分析影响投影
    ↓
AI Output Artifact: TChangeSet (含 2 项变更: View 增加 DarkMode 属性, Module 增加 ThemeService 依赖)
    ↓
HB/UI Representation: Review Surface 四层页面，展现变更对比与 0-9 键选卡组
    ↓
Human Judgment: 用户审查影响范围，确认无误，按下键盘 '1' (Accept)
    ↓
State Change: RecordChangeSetDecision 生成 dec-0001; MergeInto 将变更合并入正式规范树; FogState 收敛
```

### 案例 2: AsWish 代码逆向解析与确认闭环
```text
Human Intent: 用户触发工程扫描命令 (aswish.scan)
    ↓
AI Operation: TAsWishScanService 遍历工程解析 AST，TreeBuilder 聚合并推断未知节点
    ↓
AI Output Artifact: TCandidateIngestResult (一批 nsCandidate 状态的候选节点)
    ↓
HB/UI Representation: MainForm 左侧 TTreeView 以待审阅样式挂载节点
    ↓
Human Judgment: 用户选中节点并在右侧详情卡审阅，点击确认按钮
    ↓
State Change: 节点状态由 nsCandidate 流转为 nsConfirmed; 对应迷雾状态消解为 fsClear
```

### 案例 3: 唤金 微信联系人关系评估与行动契约闭环
```text
Human Intent: 用户进入唤金雷达面板 (FRadarPanel)
    ↓
AI Operation: TF1Judge.Assess 遍历联系人数据，按规则版本生成评估结果 (TF1AssessmentOutput)
    ↓
AI Output Artifact: TF1ActionContract (Stage=fsRecommended, 包含 Why、ConfirmWhat、ProvideWhat)
    ↓
HB/UI Representation: FWakeList / 卡片以 THbTheme 色彩渲染推荐跟进项
    ↓
Human Judgment: 用户审查理由，判定可以跟进，点击接受 (提交 TF1Feedback: fkAccepted)
    ↓
State Change: TF1QueueManager 推进状态至 fsAccepted，随后封顶流转至 fsPlannedOnly
```

### 案例 4: 唤金 破冰话术生成与终审审批闭环
```text
Human Intent: 用户针对某目标联系人点击“生成唤醒话术”
    ↓
AI Operation: TSloganPipelineB.Generate 调度真实/Mock LLM 接口，经敏感词校验并扣减点数
    ↓
AI Output Artifact: TF3BProduct (文本内容已生成，但 Approved=False，Cap 为 DRAFT_READY_FOR_USER_EDIT)
    ↓
HB/UI Representation: ScriptGeneratorPanel 预览区显示生成文本与风险指示色
    ↓
Human Judgment: 用户进行人工审校，确认话术得体，点击“审批通过”按钮
    ↓
State Change: Pipeline 调用 Approve 标记 Approved=True; 触发 CreateQueueEntry 真正进入发送队列
```

### 案例 5: 唤金 自动回复影子模式决策与名单校准闭环
```text
Human Intent: 微信收到一条新的私聊消息
    ↓
AI Operation: TAutoReplyDecisionEngine.ProcessMessage 判定策略，LLM 输出回复内容或结构化 [SKIP]
    ↓
AI Output Artifact: TDecisionResult (Outcome=doSkip, Reason="处于免打扰时段窗", IsShadow=True)
    ↓
HB/UI Representation: 主窗体审计日志与 [SKIP] 采样统计看板实时刷新
    ↓
Human Judgment: 用户检查影子决策记录，发现该联系人不应被跳过，手动将其加入 SessionPolicy 白名单
    ↓
State Change: SetPolicy 写入自定义策略; 该联系人后续消息解除静默，允许进入正常决策流
```

---

## 12. Semantic Action 现状

### 12.1 动作触发机制调查

经深度排查，**两端在内部系统状态流转中，均未采用“模拟鼠标移动与虚拟点击”的脆弱方式，而是全面建立了语义动作方法**：

* **AsWish 控制器语义动作**：
  - `TAsWishController.SubmitUserIntent(NodeId, Tree, Intent)`
  - `TAsWishController.ReviewChangeSet(ChangeSetId)`
  - `TAsWishController.AcceptChangeSet(ChangeSetId)`
  - `TAsWishController.RejectChangeSet(ChangeSetId)`
  - `TAsWishController.ClarifyChangeSet(ChangeSetId, Notes)`
  - `TAsWishDecisionsService.RecordDifferenceDecision(Report, Action, Rationale)`
* **唤金 核心状态语义动作**：
  - `TF1QueueManager.Enqueue(Contract)`
  - `TF1QueueManager.Transition(ContractId, Stage)`
  - `TF1QueueManager.RecordFeedback(Feedback)`
  - `TSloganPipelineB.Generate(...)`
  - `TSloganPipelineB.Approve(GenerationId)`
  - `TAutoReplyDecisionEngine.ProcessMessage(...)`
  - `TSendQueue.Enqueue(...)`

### 12.2 物理自动化边界
唤金仅在与**外部闭源宿主软件（微信桌面客户端）进行最终落地交互**时，通过 `TUiaEngine` 与 `TContactOps` 调用 Windows UI Automation API 寻找窗口句柄、查找 Edit 元素并填入文本。**内部业务与 AI 控制流 100% 为纯语义调用。**

---

## 13. AI / UI / Business State 现状

### 13.1 状态分层与结构化资产验证

| 状态维度 | AsWish 现状 | 唤金 现状 | DeepBase HB 基础设施对应 |
| :--- | :--- | :--- | :--- |
| **AI 内部状态** | 隐藏在 Prompt 生成与 Ingest 过程中；通过 `TGenStatus`（`gsDraft`, `gsGenerated`, `gsConfirmed`, `gsSkipped`）体现 | 严格的机器状态：`TF3BPipelineMode`、`TMessageProcessState`（`msPending`, `msProcessed`, `msIntentionallySkipped`） | `THbChoiceState` (`csReady`, `csRegenerating`, `csLoading`, `csNoReliableCandidates`, `csError`) |
| **UI 呈现状态** | WebView2 页面路由状态、折叠展开状态、树节点高亮 | 面板显隐、StringGrid 选中行、Tab 切换、Toolbar 按钮启用/禁用 | `THbLifecycleState` (`lsConstructed` .. `lsRendered`) |
| **业务事实状态** | 规范节点状态：`TNodeStatus` (`nsCandidate`, `nsConfirmed`, `nsRejected`)；迷雾状态：`TFogState` (`fsClear`, `fsFoggy` 等) | 契约阶段：`TF1Stage` (`fsRaw` .. `fsPlannedOnly`)；管线阶段：`TF1PipelineStage` (`plLead` .. `plPaid`) | 产品业务专属，不得直接入基座 |
| **人类裁决状态** | `TReviewStatus` (`rsUnreviewed`, `rsAccepted`, `rsRejected`, `rsDeferred`) | `TF1FeedbackKind` (`fkAccepted`, `fkModified`, `fkRejected`)；`Approved: Boolean` | `THbProposeStatus` (`psPending`, `psAccepted`, `psRejected`, `psModified`) |

> **关键证据结论**：两端产品的 AI 输出与人类交互结果，**均已沉淀为强类型的枚举、Record 或 Class 实体，绝对不是临时丢弃的无状态文本字符串**。

---

## 14. Context 现状

### 14.1 上下文组装能力比较

* **AsWish 上下文组装器**：
  - 源码：[`AsWish.Services.Context.pas`](file:///d:/_Progs/02Business/AsWish/src/services/AsWish.Services.Context.pas)
  - 核心类：`TContextAssembler`、`IContextSource`
  - 来源分类：`cskProjectMeta`, `cskAiRules`, `cskDocs`, `cskCodeStructure`, `cskExistingTrees`, `cskDecisions`, `cskVisualBaseline`, `cskIssues`
  - 特色机制：**Token 预算动态裁剪（Token Budget Trimming）**，按优先级从低到高截断超出预算的内容。
* **唤金 上下文组装器**：
  - 源码：[`DeepAxis.F1.Judge.pas`](file:///d:/_Progs/02Business/DeepAxis/src/f1/DeepAxis.F1.Judge.pas)、[`DeepAxis.Pipeline.Evidence.pas`](file:///d:/_Progs/02Business/DeepAxis/src/pipeline/DeepAxis.Pipeline.Evidence.pas)
  - 核心数据：`TF1AssessmentInput`
  - 来源分类：联系人画像（`ContactDB1`）、交互证据摘要（`EvidenceDB1`）、合规标签（`Marks`）、免打扰时段（`QuietHours`）
  - 特色机制：**敏感词与隐私门禁（BodyZero）**，严格禁止完整消息体进入推理上下文，仅允许摘要与哈希进入。

### 14.2 五大类通用上下文映射

```text
1. UI Context          ───► 当前选中的树节点 / 列表行 / 激活的 Tab
2. Interaction Context ───► 当前处于哪一步 / 用户刚才按下了什么键 / 鼠标悬停项
3. Conversation Context───► 最近 3~5 轮相关修改意见 / 微信最近会话证据摘要
4. Domain Context      ───► 4 树规范当前版本 / 联系人关系等级与跟进周期
5. Decision Context    ───► 历史已采纳的 decisions.yaml / F1 历史反馈与拒绝原因
```

---

## 15. HB Component 共用情况

经全面检索两端工程源码，HB 组件库的实际消费状态盘点如下：

| HB 组件 / 原语 | DeepBase 现状 | AsWish 消费情况 | 唤金 消费情况 | 归属与复用判定 |
| :--- | :--- | :--- | :--- | :--- |
| **`THbTheme`** | 已交付（10 套主题） | 未直接引用（以 CSS 变量等价对齐） | **已实装**（启动调用，应用 `gold-luxury`） | **SHARED SEMANTIC / PARTIAL CODE** |
| **`THbTokens`** | 已交付（各级语义色） | 未直接引用（HTML 渲染层硬编码等价值）| **已实装**（`WakeHero`, `WakeList` 广泛引用）| **SHARED SEMANTIC / PARTIAL CODE** |
| **`THbCard`** | 已交付（VCL & FMX） | 未使用（HTML div 或原生 Panel） | **已实装**（用于 `FTopToolbarCard`） | **HUANJIN ACTIVE CONSUMER** |
| **`THbButton`** | 已交付（VCL & FMX） | 未使用 | **已实装**（用于顶部工具条各类启动按钮） | **HUANJIN ACTIVE CONSUMER** |
| **`THbChoiceDeck`**| 已交付（commit ed7b1bc） | **未接入**（在 WebView2 中用 HTML 渲染） | **未接入**（以分散 Button/Grid 替代） | **HB READY / NO CONSUMER YET** |
| **`THbAIConsole`** | 已交付（VCL & FMX） | 未接入（自建 Review Surface） | 未接入（自建 ScriptPanel） | **HB READY / NO CONSUMER YET** |
| **`THbFacetWaterfall`**| 已交付（分面瀑布） | 未接入 | 未接入（规划于文档） | **HB READY / NO CONSUMER YET** |
| **`THbBadge / Chip`**| 已交付（VCL & FMX） | 未接入 | 部分使用原生绘制替代 | **HB READY / HUANJIN PARTIAL** |
| **`THbVirtualList`**| 已交付（10万级） | 未接入 | 未接入（使用自绘 ScrollBox/Panel） | **HB READY / NO CONSUMER YET** |
| **`THbSkeleton`** | 已交付（骨架屏） | 未接入 | 未接入（文档有规划） | **HB READY / NO CONSUMER YET** |

---

## 16. HB Choice System 专项

### 16.1 HB 已经抽象了什么？
1. **键位与语义协议（0–9 Protocol）**：
   - `1–7`：动态候选空间（Candidate Space），Key 1 可标记为推荐（`IsRecommended`）；
   - `8`：重新生成（`cakRegenerate`），重申“8 不是 Decision”，不改变业务 Canonical；
   - `9`：人类覆写与自由输入（`cakFreeInput`），内置展开式输入框或外部委托，支持框架否定（Frame Rejection）；
   - `0`：导航返回（`cakBack`），纯 Navigation 语义，绝对严禁等同于 Reject。
2. **多模态意图与设备解耦**：
   - 抽象出 `THbChoiceAction`，输入设备可以是鼠标（`cisMouse`）、主键盘（`cisKeyboard`）、数字小键盘（`cisNumPad`）、代码触发（`cisProgrammatic`）乃至预留的语音指令（`cisVoice`）。
3. **真实诚实状态机（Truthful State Machine）**：
   - 定义 `THbChoiceState`，将“无可靠候选（`csNoReliableCandidates`）”作为合法 AI 状态独立呈现，并与技术网络故障（`csError`）严格区分开。

### 16.2 AsWish 怎样消费？
* **现状**：AsWish 在理论和规约上是 0–9 协议的原作者与最大倡导者，但其当前生产版本是通过 `TAsWishRenderService` 生成带有 JS 键盘监听器（`window.addEventListener('keydown', ...)`）的 HTML 页面承载，并在 WebView2 中运行，尚未直接替换为 Delphi 原生 `THbChoiceDeck`。

### 16.3 唤金 怎样消费？
* **现状**：唤金在设计总纲与触点规范（`23-唤金顾问体系与四自接触点规范.md`）中明确将 `THbChoiceDeck` 列为“意图澄清与推荐拍板”的标准控件，但目前在 Delphi 生产窗体中，仍以分散的 `TButton`、`TListBox` 和 `TStringGrid` 分步呈现。

### 16.4 相同点与不同点
* **相同点**：对 1–7 候选、8 重新生成、9 自由表达、0 导航返回的交互哲学与快捷键映射共识 100% 一致。
* **不同点**：AsWish 已经拥有完整的四层审阅模型呈现（但在浏览器内核里）；唤金在原生 VCL 界面里（但仍是分散的传统控件）；HB 在原生控件库里（但尚待产品挂载）。

### 16.5 是否已摆脱业务产品概念？
* **结论**：**是，已经彻底摆脱。**
* **证据**：查看 [`Core/DeepBase.HB.Choice.Types.pas`](file:///d:/_Progs/02Business/DeepBase/Core/DeepBase.HB.Choice.Types.pas)，其暴露的属性和事件仅包含 `Key`, `Text`, `Description`, `Kind`, `IsRecommended`, `Payload`, `InputSource`，零任何业务字段。

---

## 17. Token / Theme / Semantic Style 现状

1. **色彩令牌（Color Tokens）**：
   - DeepBase 定义了 10 套调色板，唤金直接调用 `THbTheme.ApplyTheme('gold-luxury', hdComfortable)`；
   - AsWish 虽未直接链接该单元，但其 CSS 样式表中的色彩数值与 DeepBase HB 设计规范完全同构。
2. **核心语义色差距（Difference ≠ Warning / Danger）**：
   - 两个产品在实践中均强烈要求：**“客观事实差异不是错误”**；
   - 在 AsWish 的差异审阅（Difference Review）与唤金的工商/关系变更展示中，黄色会引发虚假警报，红色会导致警报疲劳。HB 已在设计文档中规划扩充中性板岩蓝（`hsiChange`）与未决挂起（`Unresolved`）色阶。

---

## 18. AI 基础设施共性

| 能力项 | DeepBase 现状 | AsWish 现状 | 唤金 现状 | 重复实现判定 |
| :--- | :--- | :--- | :--- | :--- |
| **LLM HTTP 客户端** | `DeepBase.LLM.Client.pas` | `AsWish.Services.LLM.pas` | `DeepAxis.F3B.Adapters.pas` | **三方独立实现（高冗余）** |
| **密钥隔离/BYOK** | `DeepBase.Security` | `AsWish.Security.pas` (自建) | `DeepAxis.LLM.Router.pas` (调基座)| **各自维护一套加密配置** |
| **计费与点数扣减** | `DeepBase.LLM.BillingClient` | 无商业计费诉求 | `DeepAxis.F3.Credits.pas` | **产品特有 vs 基座通用** |
| **重试与指数退避** | `IntentClarification.LLMResilience`| 基础重试 | `DeepAxis.F3B.Resilience.pas` | **两端各自实现退避算法** |
| **Prompt 模板管理** | `LLM.PromptTemplateManager`| `AsWish.Services.Prompts.pas` | `ScriptEngine` / 散落代码 | **各自拼装字符串** |
| **上下文预算截断** | 无统一裁剪器 | `TContextAssembler` (自建) | 简易长度截断 | **AsWish 已有优质实现待下沉** |

---

## 19. Interaction Capability Matrix

| Interaction Capability | AsWish | 唤金 | DeepBase | HB | Separate implementation? | Evidence | Commonality |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Intent input** | 自然语言/树点击 | 场景选择/好友行选 | Not found | Not found | Yes (各自实现输入框/列表) | AsWish `CandidateIngest` / 唤金 `WakeList` | HIGH (语义共性) |
| **AI interpretation**| `TChangeSet` 提议 | `TF1Assessment` 判定 | Not found | `THbThoughtStep` | Yes (两套解析管线) | AsWish `cstExplicit` / 唤金 `TF1EvidenceKind` | HIGH (三态结构等价) |
| **Candidate generation**| 1–7 项候选变更 | 动作契约/话术候选 | Not found | `THbChoiceItem` | Yes (各自生成候选) | AsWish `ChangeItem` / 唤金 `TF1ActionContract`| HIGH (候选先行) |
| **Candidate presentation**| 4层模型 Review 面 | 面板/Grid/列表 | Not found | `THbChoiceDeck` (就绪) | Yes (HTML vs 原生Grid vs HB Deck) | AsWish `Render.pas` / 唤金 `TagSuggestPanel` | HIGH (急需统一控件) |
| **Choice** | 0–9 键盘/鼠标选择 | 鼠标选择/行选 | Not found | `THbChoiceDeck` (双端支持)| Yes (AsWish HTML / 唤金 VCL) | AsWish `ReviewSurface` / 唤金 `FGrid` | HIGH (标准相同) |
| **Regenerate** | Key 8 (非决策) | 重新生成按钮 (非决策)| Not found | `cakRegenerate` (Key 8) | Yes (各自绑定回调) | AsWish `changeset-regenerate` / 唤金 `F3b` | HIGH (非决策重试) |
| **Manual input** | Key 9 (自由说明) | 手动备注/修改话术 | Not found | `cakFreeInput` (Key 9) | Yes (HTML input vs VCL Memo) | AsWish `changeset-clarify` / 唤金 `fkModified` | HIGH (人类逃逸阀) |
| **Back** | Key 0 (纯导航) | 窗口关闭/返回 | Not found | `cakBack` (Key 0) | Yes (各自实现路由) | AsWish `changeset-back` / 唤金 Form.Close | HIGH (导航非驳回) |
| **Accept** | 接受提议写回 | 批准动作/批准发送 | Not found | `psAccepted` | Yes (各写各的控制器) | AsWish `AcceptChangeSet` / 唤金 `Approve` | HIGH (终审批准) |
| **Reject** | 驳回提议并留痕 | 拒绝动作/不回消息 | Not found | `psRejected` | Yes (各写各的状态机) | AsWish `RejectChangeSet` / 唤金 `fkRejected` | HIGH (非破坏驳回) |
| **Clarify** | 澄清表单修正意向 | 修改建议文本 | Not found | Not found | Yes (AsWish 有独立闭环) | AsWish `ClarifyChangeSet` / 唤金 `ModifiedNote`| MEDIUM (AsWish 更完备) |
| **Explain** | 输出推导原因 | 输出决策理由与事实 | Not found | Not found | Yes (各自输出字符串数组) | AsWish `Item.Reason` / 唤金 `Reasons` | HIGH (必须有解释) |
| **Preview** | Before/After 对比 | 话术预览/风险着色 | Not found | `THbAIConsole` (差异卡) | Yes (HTML 表格 vs Memo 预览) | AsWish `RenderDiff` / 唤金 `MBoxPreview` | HIGH (前后对比) |
| **Compare** | L2/L3 差异报告 | 事实差异比对表 | Not found | Not found | Yes (各自编写比对引擎) | AsWish `Difference.pas` / 唤金 变更比对 | MEDIUM (事实差异) |
| **AI status** | Draft/Generated | Pending/Processed | Not found | `THbChoiceState` (8态) | Yes (各自维护枚举) | AsWish `TGenStatus` / 唤金 `TMessageProcessState`| HIGH (状态机驱动) |
| **Human decision** | 落盘 `decisions.yaml` | 落盘 Feedback / 审计 | Not found | Not found | Yes (各自持久化) | AsWish `TAsWishDecisionsService` / 唤金 `FAudit` | HIGH (决策必须可审计) |
| **Context** | 8类上下文+预算裁剪 | 客户画像+会话摘要 | Not found | Not found | Yes (AsWish 裁剪机制更完善) | AsWish `Context.pas` / 唤金 `Evidence.pas` | HIGH (组装与裁剪) |
| **Semantic action**| Controller 5 大方法 | 队列推进 4 大方法 | Not found | `THbChoiceAction` | Yes (各自在业务层实现) | AsWish `AsWish.Controller` / 唤金 `TF1Action` | HIGH (内部拒绝模拟点击)|
| **AI result rendering**| WebView2 HTML/CSS | VCL 原生控件自绘 | Not found | GDI+ 矢量渲染器 | Yes (实现完全割裂) | AsWish `Render.pas` / 唤金 `WakeList.pas` | HIGH (表现层割裂) |

---

## 20. Capability Ownership Matrix

| Capability | DeepBase currently provides | HB currently provides | AsWish provides | 唤金 provides | Duplicate? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Design Tokens & Themes** | `DeepBase.HB.Palettes` | `DeepBase.VCL.HB.Theme` | 等价 CSS 变量 | 消费 `THbTheme` | 部分重复（AsWish 未直接引用包） |
| **0–9 Choice Interaction** | Not found | `THbChoiceDeck` (VCL/FMX) | WebView2 HTML 实现 | 离散按钮/未接 Deck | **严重脱节（基座有，两端自造/未接）** |
| **LLM HTTP Client** | `DeepBase.LLM.Client` | Not found | `AsWish.Services.LLM`| `DeepAxis.F3B.Adapters` | **三方各自重复实现** |
| **Context Token Budgeting** | Not found | Not found | `TContextAssembler` | 简易长度截断 | **存在单边优质实现，未沉淀基座** |
| **Explicit/Inferred Tri-state**| Not found | Not found | `TChangeSourceType` | `TF1EvidenceKind` | **语义完全重复，数据类型割裂** |
| **Before/After Diff Model** | Not found | `THbProposeDiffItem` | `TChangeItem` | 独立比对逻辑 | **基座有契约，两端自建模型** |
| **Touchpoint Telemetry Sink** | `IHbTelemetrySink` | `THbTouchpointEngine` | 自建 Dogfood 日志 | 自建 `TF2AuditLog` | 各自实现留痕，未接统一持久化槽 |
| **Audit Log & Replay** | Not found | Not found | decisions.yaml 追踪 | `TF2AuditLog` 链表回放 | 各自实现审计存储 |
| **UI Automation (External)** | `DeepBaseBrowser` | Not found | Not found (无外部软件)| `TUiaEngine` (对接微信) | 唤金特有需求 |
| **AI Model Billing & Credits** | `LLM.BillingClient` | Not found | 不需要 (开源离线) | `DeepAxis.F3.Credits` | 唤金自建与基座存在概念重复 |

---

## 21. Shared Implementation

真正实现了**物理代码级共用**的能力清单：

1. **`DeepBase.HB.Core` & `DeepBase.VCL.HB.Theme`**：
   - **真实消费者**：唤金（`DeepAxis.dpr`, `DeepAxis.UI.MainForm.pas`, `DeepAxis.UI.WakeList.pas`, `DeepAxis.UI.WakeHero.pas`）
   - **证据**：`DeepAxis.dpr` 行 217 `THbTheme.Initialize; THbTheme.ApplyTheme('gold-luxury', hdComfortable);`；`WakeList.pas` 行 161 `TColor(THbTheme.Current.Tokens.Surface and $00FFFFFF);`。
2. **`DeepBase.VCL.HB.Cards` (`THbCard`) & `DeepBase.VCL.HB.Controls` (`THbButton`)**：
   - **真实消费者**：唤金（`DeepAxis.UI.MainForm.pas`）
   - **证据**：`FTopToolbarCard: THbCard;`、`FBtnLaunchWeChat: THbButton;`。
3. **`DeepBase.AIErrorHandler` & `DeepBase.AutoFix`**：
   - **真实消费者**：唤金（`DeepAxis.UI.MainForm.pas`）
   - **证据**：`uses DeepBase.AIErrorHandler, DeepBase.AutoFix;`。
4. **`DeepBase.Security` 密钥引用机制**：
   - **真实消费者**：唤金（`DeepAxis.LLM.Router.pas`）
   - **证据**：`BYOK key 只存 DeepBase.Security 引用 — 本单元永远不接触明文`。

---

## 22. Semantic Commonality / Separate Implementations

### SC-01: 候选裁决与审阅交互界面 (Review Surface & Choice Deck)
* **共同语义**：呈现当前 AI 针对人类意图给出的结构化候选提议，展示 Before/After 及推理理由，提供 0–9 快速键选、人类覆写与返回机制。
* **AsWish 当前实现**：基于 WebView2 JS Bridge，使用 HTML/CSS 渲染“四层信息模型”（`src/services/AsWish.Services.Render.pas`）。
* **唤金 当前实现**：使用原生 VCL `TPanel` + `TStringGrid` + `TButton` 拼装建议列表，或在 `ScriptPanel` 中使用 `TListBox` + `TMemo` 预览。
* **共有部分**：候选先行、推荐高亮但不自动执行、支持驳回、支持自由输入。
* **差异部分**：AsWish 具备高度集成的单页四层信息流；唤金分散在不同的业务功能面板中。
* **是否值得进入下一轮架构讨论**：**Yes**（讨论是否两端统一接入 HB 原生 `THbChoiceDeck`）。

### SC-02: 事实 / 推断 / 未知三态数据结构 (Explicit / Inferred / Unknown)
* **共同语义**：将机器产出的所有信息严格打标为“确凿事实/用户提出”、“系统猜测推断”、“未知或需澄清项”。
* **AsWish 当前实现**：`AsWish.Models.pas` 中的 `TChangeSourceType = (cstExplicit, cstInferred, cstUnknown);`。
* **唤金 当前实现**：`DeepAxis.F1.Types.pas` 与 `DeepAxis.F1.Judge.pas` 中的 `Facts: TArray<string>; Inferences: TArray<string>; Unknowns: TArray<string>;`。
* **共有部分**：认知模型 100% 同构，均用于指导 UI 呈现不同的信任权重。
* **差异部分**：AsWish 绑定在字段级变更上（`TChangeItem`）；唤金绑定在联系人评估契约上（`TF1AssessmentOutput`）。
* **是否值得进入下一轮架构讨论**：**Yes**（可考虑在 `DeepBase.HB.AI.Types` 中抽象通用的推断置信度契约）。

### SC-03: LLM 运行时 HTTP 适配器 (LLM Client Adapter)
* **共同语义**：基于 Delphi 自带的 `System.Net.HttpClient`，向 OpenAI 兼容接口发送 JSON POST 请求，解析响应文本与 Token 消耗。
* **AsWish 当前实现**：`src/services/AsWish.Services.LLM.pas`（`TAsWishLLMService`）。
* **唤金 当前实现**：`src/f3b/DeepAxis.F3B.Adapters.pas`（`TRealLLMAdapter`）。
* **DeepBase 现有基座**：`Features/DeepBase.LLM.Client.pas`（`TDeepBaseLLMClient`）。
* **共有部分**：均使用 `System.Net.HttpClient`，均走异步或后台线程，均提取 `usage.total_tokens`。
* **差异部分**：唤金增加了 `TF3BEndpointGuard` 与环境密钥擦除审计；AsWish 增加了本地加密配置读取。
* **是否值得进入下一轮架构讨论**：**Yes**（明显的代码冗余，应当讨论统一收拢至 DeepBase）。

### SC-04: 上下文组装与 Token 预算裁剪 (Context Assembly & Budget Trimming)
* **共同语义**：将当前界面实体、历史记录、规则和文档组合成 Prompt 文本，并在超出模型上下文窗口时按优先级策略丢弃低优先级信息。
* **AsWish 当前实现**：`src/services/AsWish.Services.Context.pas`（`TContextAssembler`，支持 8 类来源与优先级裁剪）。
* **唤金 当前实现**：分散在 `Evidence.pas` 与 `F3b.Pipeline.pas` 中的硬编码截断。
* **共有部分**：避免超长 Prompt 引发模型报错。
* **差异部分**：AsWish 已经形成了优雅的 `IContextSource` 插件式管道与估算器；唤金偏向过程式拼装。
* **是否值得进入下一轮架构讨论**：**Yes**（AsWish 的 `TContextAssembler` 极具下沉价值）。

### SC-05: 结构化差异比对与裁决 (Difference Inspection & Judgment)
* **共同语义**：比对基准数据与目标数据之间的结构化差异，将差异归类（新增/缺失/修改），并交由人类执行 `Acceptable / Unacceptable / Unresolved` 判定。
* **AsWish 当前实现**：`AsWish.Services.Difference.pas`（`TSpecDifferenceReport`, `TDifferenceJudgment`）。
* **唤金 当前实现**：`DeepAxis.UI.AssetReportPanel.pas` 及工商/关系资产比对逻辑。
* **DeepBase 现有契约**：`Core/DeepBase.HB.AI.Types.pas`（`THbProposeDiffItem`, `THbProposeStatus`）。
* **共有部分**：差异不等于错误（Difference ≠ Error），由人类进行中性审阅。
* **差异部分**：AsWish 比对的是规格 AST 与 VCL 控件几何属性；唤金比对的是商业关系属性与资产标签。
* **是否值得进入下一轮架构讨论**：**Yes**（讨论 UI 表现层能否共用通用差异比对卡）。

---

## 23. Product-specific Semantics

以下内容经确认**属于具体产品的独有业务语义**，在后续架构演进中**严禁错误下沉到 DeepBase 或 HB**：

### 23.1 明确只属于 AsWish 的业务语义
1. **四投影规约模型（Four Projections Spec）**：
   - `ttFunction`（功能树）、`ttModule`（模块树）、`ttView`（界面树）、`ttData`（数据树）；
   - 包含的属性如 `SourceLayer`、`valid_states`、`field_constraints`、`cascade` 等编译器与架构设计专用词汇。
2. **Delphi 语法反向工程与 AST 解析**：
   - `AsWish.Delphi.PasParser.pas`、`AsWish.Delphi.DfmParser.pas`。
3. **需求迷雾状态机（Fog State Machine）**：
   - `fsClear` $\leftarrow$ `fsMisty` $\leftarrow$ `fsFoggy` $\leftarrow$ `fsUnknownUnknowns` 单向收敛度量。
4. **YAML 格式的规范持久化契约**：
   - 严格遵循 AsWish Protocol v1.2 的文件序列化规范。

### 23.2 明确只属于 唤金 (DeepAxis) 的业务语义
1. **微信生态与社交协议**：
   - 微信本地数据库解密（`WeChat.Decrypt`）、账号扫描（`WeChatScanner`）、4.x 协议适配、联系人昵称与备注。
2. **Windows UIA 外部注入操作**：
   - `TUiaEngine`、`TContactOps` 通过系统无障碍树查找微信控件并模拟写回。
3. **销售转化漏斗与商业管线**：
   - `plLead` $\rightarrow$ `plInterview` $\rightarrow$ `plTrial` $\rightarrow$ `plCoCreate` $\rightarrow$ `plQuote` $\rightarrow$ `plPaid` $\rightarrow$ `plDelivered` $\rightarrow$ `plRebuyReferral`。
4. **企业股权与司法工商风控**：
   - 股权穿透关系图谱、裁判文书关联链、工商登记底档原件核对。
5. **AI 点数商业化计量（Credits Ledger）**：
   - 1元 = 1000点、月票、商业佣金三分法。

---

## 24. Gaps / Unknowns

本节严格记录当前调查中客观存在的工程断点与未确认事实（严禁猜测）：

1. **GAP-01: AsWish 生产主程序尚未内嵌原生 VCL `THbChoiceDeck`**
   - *事实*：AsWish 主窗体 `AsWish.MainForm.pas` 仍通过 EdgeBrowser（WebView2）加载自绘 HTML 页面呈现 0–9 审阅。虽然进行了 VCL 高保真 Spike（WO-0030），但尚未在正式生产编译链中引入 `DeepBase.VCL.HB.Choice`。
2. **GAP-02: 唤金生产主界面尚未采用 `THbChoiceDeck` 替换离散按钮**
   - *事实*：唤金虽在文档中定义了该交互规范，但目前 `TagSuggestPanel.pas` 等界面仍然采用普通的 `TStringGrid` 与 `TButton`，未将 F1 动作契约绑定至 `THbChoiceDeck`。
3. **GAP-03: DeepBase HB 高阶组件存在“有实现、无产品实装”的闲置断点**
   - *事实*：HB 库中已完成并经过严密单测验证的 `THbChoiceDeck`（37/37通过）、`THbAIConsole`、`THbFacetWaterfall`，在 AsWish 和唤金两个真实消费者的最新 HEAD 代码中，均未找到正式窗体实装实例（No confirmed consumer in production forms）。
4. **GAP-04: 渐进式折叠与时间线原语缺失导致唤金自建临时实现**
   - *事实*：HB 尚未提供正式的 `THbDisclosureBox`（自适应折叠盒）与 `THbTimeline`（物理时间线原语），导致唤金在展示证据链时只能使用静态 ListBox 或 Panel 变通处理。
5. **GAP-05: 微信 4.x 实机逆向受限性**
   - *事实*：唤金代码库中存在部分针对微信特定补丁版本（如 4.1.10.53）的适配单元，外部软件一旦强更，底层读取链路存在脆弱性，但该物理断点与上层 AI 交互抽象无关。

---

## 25. 给上层讨论的事实清单

以下提炼 25 条客观事实，供后续产品与架构讨论决策使用（只摆事实与证据，不越界做方案）：

### F-01
* **事实**：AsWish 与唤金在 AI 交互循环上，100% 收敛于“用户输入/实体锚定 $\rightarrow$ AI 组装上下文 $\rightarrow$ 输出结构化候选 $\rightarrow$ 人类审阅并终局裁决 $\rightarrow$ 状态机确定性流转”。
* **证据**：AsWish `TAsWishController` 五方法；唤金 `DeepAxis.F1.Action.pas` 与 `DeepAxis.F1.Judge.pas`。
* **涉及产品**：AsWish、唤金。
* **当前归属**：各自业务层独立运转。

### F-02
* **事实**：两端系统在处理 AI 推理结果时，均自发抽象出“客观事实（Explicit/Facts）”、“系统推断（Inferred）”与“待定未知（Unknowns）”三态模型。
* **证据**：AsWish `AsWish.Models.TChangeSourceType`；唤金 `DeepAxis.F1.Judge.TF1AssessmentOutput`。
* **涉及产品**：AsWish、唤金。
* **当前归属**：各自独立定义枚举与字段，DeepBase 基座尚无对应统一契约。

### F-03
* **事实**：两端系统均严格遵循“AI 推荐不等于自动采纳，人类驳回绝不破坏正式数据基线”的交互铁律。
* **证据**：AsWish `RecordChangeSetDecision` 中 Reject 不改 Canonical Spec；唤金 `TF1QueueManager` 中未获 Approved 话术无法入队 `TF2SendQueue`。
* **涉及产品**：AsWish、唤金。
* **当前归属**：各自在控制器与队列管理器中自行防守。

### F-04
* **事实**：两端系统均确认“重新生成（Regenerate）不是 Decision”，触发重新生成绝不能产生业务持久化副作用。
* **证据**：AsWish `WO-20260830-0027D-R1` AC-02；唤金 `DeepAxis.F3B.Pipeline.pas`。
* **涉及产品**：AsWish、唤金、DeepBase HB。
* **当前归属**：HB 0–9 标准（`cakRegenerate`）已做语义规范冻结。

### F-05
* **事实**：两端系统均提供了打破 AI 封闭候选框架的“人类覆写（Human Override / Frame Rejection）”安全阀。
* **证据**：AsWish 0–9 中的 `[9] 我自己说明`；唤金 F1 Feedback 中的 `fkModified`。
* **涉及产品**：AsWish、唤金。
* **当前归属**：各自界面中独立实现。

### F-06
* **事实**：两端系统均将 0 键或返回操作严格定界为“界面导航（Navigation）”，禁止将其扭曲为业务驳回或取消。
* **证据**：AsWish `docs/03.规范-可见判断与交互规范.md` §2.4；DeepBase `docs/ui/DeepBase-HB-AI-Choice-Interaction-Standard.md` §2.4。
* **涉及产品**：AsWish、唤金、DeepBase HB。
* **当前归属**：已在 HB 标准冻结。

### F-07
* **事实**：DeepBase HB 已开发并交付跨平台通用的 `THbChoiceDeck`（VCL & FMX，单测 37/37 Green），但在两端主生产窗体中实装率为 0。
* **证据**：`DeepBase.VCL.HB.Choice.pas`；AsWish `MainForm.pas` 使用 EdgeBrowser；唤金 `MainForm.pas` 使用原生标准控件。
* **涉及产品**：DeepBase HB、AsWish、唤金。
* **当前归属**：HB 基础设施已就绪，产品层未集成。

### F-08
* **事实**：AsWish 拥有经过完整真人 Dogfood 验证的“四层审阅信息模型（I said $\rightarrow$ AI understood $\rightarrow$ Changes $\rightarrow$ Decision）”，但目前承载于 WebView2 JS Bridge。
* **证据**：AsWish `WO/DELIVERABLE-REPORT-WO-20260830-0027D-R1.md`。
* **涉及产品**：AsWish。
* **当前归属**：AsWish 自研 HTML 表现层。

### F-09
* **事实**：唤金已经在启动入口与核心界面强依赖 `THbTheme`（`gold-luxury`）与 `THbCard`、`THbButton`。
* **证据**：`DeepAxis.dpr` 行 217；`DeepAxis.UI.MainForm.pas` 行 52。
* **涉及产品**：唤金、DeepBase HB。
* **当前归属**：HB 正常供给唤金消费。

### F-10
* **事实**：AsWish 项目当前保持“Zero External Dependencies”，编译期未连接任何 DeepBase 或 HB 二进制包。
* **证据**：`AsWish.dpr` 源码工程清单。
* **涉及产品**：AsWish。
* **当前归属**：AsWish 独立维护所有支持代码。

### F-11
* **事实**：两端产品均独立自研了基于 `System.Net.HttpClient` 的 LLM HTTP 调用类，且 DeepBase 基座中亦存在等价实现。
* **证据**：AsWish `AsWish.Services.LLM.pas`；唤金 `DeepAxis.F3B.Adapters.pas`；DeepBase `DeepBase.LLM.Client.pas`。
* **涉及产品**：AsWish、唤金、DeepBase。
* **当前归属**：三方重复实现。

### F-12
* **事实**：AsWish 拥有完善的插件式上下文组装与 Token 预算裁剪器（`TContextAssembler`），可按优先级丢弃超限信息；唤金尚未具备同等成熟度的组装器。
* **证据**：AsWish `src/services/AsWish.Services.Context.pas`。
* **涉及产品**：AsWish、唤金。
* **当前归属**：留在 AsWish 内部。

### F-13
* **事实**：两端系统在内部状态机与业务流转中，均未采用“模拟鼠标坐标点击”，而是通过强类型语义动作方法进行通信。
* **证据**：AsWish Controller 5 大方法；唤金 QueueManager / Pipeline 核心方法。
* **涉及产品**：AsWish、唤金。
* **当前归属**：各自业务层。

### F-14
* **事实**：唤金仅在与外部闭源微信桌面端打通时，使用 `TUiaEngine` 执行 Windows UI 自动化操作。
* **证据**：`DeepAxis.UIA.Engine.pas`、`DeepAxis.UIA.ContactOps.pas`。
* **涉及产品**：唤金。
* **当前归属**：唤金独有外部适配层。

### F-15
* **事实**：两端均一致认为“事实差异不等于错误警告（Difference ≠ Warning / Danger）”，使用警告黄或错误红会破坏用户心智并产生警报疲劳。
* **证据**：AsWish `Difference.pas`；DeepBase `docs/ui/DeepBase-HB-x-HuanJin-UI-Capability-Gap-Analysis.md` §四.1。
* **涉及产品**：AsWish、唤金、DeepBase HB。
* **当前归属**：HB 已立项扩展 `hsiChange` 语义令牌。

### F-16
* **事实**：唤金自研了严密的会话免打扰决策层（DA-128），支持结构化 `[SKIP]` 作为合法一等公民输出，并提供不丢消息三态承诺（`PENDING / PROCESSED / INTENTIONALLY_SKIPPED`）。
* **证据**：`DeepAxis.Decision.AutoReply.pas`。
* **涉及产品**：唤金。
* **当前归属**：唤金独立决策层。

### F-17
* **事实**：两端系统在 AI 交互结果的生命周期管理上，均采用了严格的单向流转状态机，不存在弱类型字符串驱动现象。
* **证据**：AsWish `TNodeStatus` / `TFogState`；唤金 `TF1Stage` (`FJIsLegalTransition`)。
* **涉及产品**：AsWish、唤金。
* **当前归属**：各自领域状态机。

### F-18
* **事实**：唤金具备严格的离机隐私防线（BodyZero），任何聊天消息体绝对禁止进入 AI 推断模型，仅允许摘要与单向 Hash 进入。
* **证据**：`DeepAxis.F1.Judge.pas` 契约约束。
* **涉及产品**：唤金。
* **当前归属**：唤金合规层。

### F-19
* **事实**：AsWish 探索了基于 VCL 真实运行时的视觉基线抽取与 L2（布局）/ L3（外观）差异自动化比对技术（WO-0030 Spike）。
* **证据**：AsWish `WO/WO-20260906-0030-甲-High-Fidelity-Visual-Baseline-VCL-Vertical-Spike.md`。
* **涉及产品**：AsWish。
* **当前归属**：AsWish 实验性 Spike。

### F-20
* **事实**：DeepBase 拥有独立的触点与遥测持久化驱动接口（`IHbTouchpoint` / `IHbTelemetrySink`），但两个产品目前均采用自建日志文件进行行为留痕。
* **证据**：DeepBase `Core/DeepBase.HB.Touchpoint.Types.pas`；AsWish `WO/evidence/`；唤金 `TF2AuditLog`。
* **涉及产品**：DeepBase HB、AsWish、唤金。
* **当前归属**：HB 提供标准接口，产品自建留痕。

### F-21
* **事实**：唤金在设计规范中强烈诉求 `THbDisclosureBox`（自适应折叠盒）与 `THbTimeline`（物理时间线原语），目前 HB 基座库中尚未包含这两个正式控件。
* **证据**：`docs/ui/DeepBase-HB-x-HuanJin-UI-Capability-Gap-Analysis.md` CR-01 / CR-03。
* **涉及产品**：唤金、DeepBase HB。
* **当前归属**：HB 待决差距项。

### F-22
* **事实**：DeepBase 拥有带思考折叠（Thought Fold）与差异提案卡（Propose Diff Item）的 `THbAIConsole` 控件，但两端均自建了专门的 Review 面板。
* **证据**：`Core/DeepBase.HB.AI.Types.pas`；`VCL/DeepBase.VCL.HB.AI.pas`。
* **涉及产品**：DeepBase HB、AsWish、唤金。
* **当前归属**：HB 控件就绪但产品未接。

### F-23
* **事实**：两端系统的 AI 输出均伴随明确的置信度评估（AsWish `TConfidenceLevel` / 唤金 `Confidence: Integer 0..100`）。
* **证据**：AsWish `AsWish.Models.pas`；唤金 `DeepAxis.F1.Judge.pas`。
* **涉及产品**：AsWish、唤金。
* **当前归属**：各自数据结构。

### F-24
* **事实**：DeepBase 的 HB Choice 控件源码完全去除了 AsWish 与唤金的任何领域实体概念，具备纯粹的人机交互原语通用性。
* **证据**：`DeepBase.HB.Choice.Types.pas` 零业务依赖。
* **涉及产品**：DeepBase HB。
* **当前归属**：HB 视觉基础设施层。

### F-25
* **事实**：唤金的主管线在商业化层面依赖 AI 点数计量与预留结算机制（`ReserveCredits` / `SettleCredits`），而 AsWish 作为本地离线开发工具，无商业计费诉求。
* **证据**：唤金 `DeepAxis.LLM.Router.pas`；AsWish `AsWish.Services.LLM.pas`。
* **涉及产品**：唤金、AsWish。
* **当前归属**：唤金商业化特有逻辑。

---

*（本资料包由自动化工程取证生成，全量事实已交叉索引至具体代码行与工程工单，供上层产品与架构评审会议作为真相源使用）*
