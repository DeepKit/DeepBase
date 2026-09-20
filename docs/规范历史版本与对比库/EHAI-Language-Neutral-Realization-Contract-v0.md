<!-- ===================================================================== -->
<!-- MIRROR / NON-AUTHORITATIVE COPY                                       -->
<!-- Canonical SSOT: EHAI/common-contract/EHAI-Language-Neutral-Realization-Contract-v0.md -->
<!-- Downstream Delphi / DeepBase consumer mirror. Do NOT edit directly.   -->
<!-- ===================================================================== -->
# EHAI 语言无关实现契约 (v0)
## Language-Neutral Realization Contract (v0 Baseline)

> **文档性质**：`APPROVED ENGINEERING BASELINE v0 / NON-NORMATIVE / LANGUAGE-NEUTRAL / DERIVED FROM EHAI`  
> **中文工作名称**：EHAI 语言无关实现契约  
> **英文工作描述**：EHAI Language-Neutral Realization Contract *(OPEN / NOT FROZEN)*  
> **权威地位**：下游 Delphi / DeepBase 消费镜像（MIRROR / NON-AUTHORITATIVE COPY）  
> **版本**：`APPROVED ENGINEERING BASELINE v0`  
> **制定日期**：2026-09-14  
> **法源地位**：非规范性工程契约母稿（Non-Normative Engineering Contract）。本契约派生自 EHAI 冻结规范，作为所有下游具体编程语言实现（Delphi / Python / TypeScript / C# 等）共同遵循的可移植机器语义、状态机抽象与行为验证基准。  
> **基线说明**：`APPROVED ENGINEERING BASELINE v0` 表示可作为后续语言实现与产品绑定工单的工程输入基线；它仍允许依据跨语言实现证据进行受控工程修订，不构成 EHAI 理论 Reopen。

---

## §0 文档身份、最高纪律与负向清单

### 0.1 理论冻结与派生单向性
1. **母规范效力**：`EHAI.00` 为 `APPROVED INDEX v1.0 (Non-Normative)`。**EHAI L1～L8 在当前 v1.0 版本中具有正式且受保护的理论效力**。本契约是下游工程承接文件，**严禁修改任何 EHAI 冻结理论正文**。
2. **严禁理论扩张**：本契约不是 L9，不创造新理论 Root，不发明新法源。
3. **语义强度不越界（Contract Meaning Strength $\le$ Upstream EHAI Meaning Strength）**：
   - 语言共用层只做**可移植工程语义**；
   - 严禁加强、缩窄、扩张或重定义上游理论；
   - 严禁将某一具体产品的工程习惯或某一 UI 平台的控件行为写成普遍规范。
4. **单向派生纪律**：实现便利性绝不反噬理论法源（`Engineering Convenience ≠ Theory Revision Authority`）。

### 0.2 负向清单（严禁写入内容）
为了彻底清除实现泄漏，保持跨语言与跨领域纯粹性，**以下内容严禁进入本契约公共定义**：
- **禁止特定编程语言概念**：严禁出现 `class`、`interface`、`record`、`struct`、`Delphi unit`、`Python module`、`TypeScript type`。
- **禁止特定 UI 框架与控件实现**：严禁出现 `VCL`、`FMX`、`TEdgeBrowser`、`THbChoiceDeck`、`DOM`、`WPF`、`Qt`。
- **禁止特定 UI 交互呈现细节**：严禁出现“`旧候选半透明/淡化`”、“`快捷键挂起`”、“`文本输入焦点保护`”、“`勾选视觉/Checkmark`”、“`独立提交按钮`”、“`原生输入框`”、“`鼠标/键盘具体扫描码`”。
- **禁止特定产品专有模型与术语**：严禁出现 `TCandidateIntent`、`TChangeSet`、`SpecNode`、`规范树`、`WriteTree`、`Accepted Baseline`、`TSpecDecision`（AsWish 专有）；严禁出现 `Contact`、`Customer`、`Relationship`、`Touchpoint`、`微信`、`标签`、`话术`、`商业 Authority Gate`（AXIS 专有）。
- **禁止物理存储格式与外部依赖绑定**：严禁强制指定具体的 SQL 表名、YAML 相对路径、文件物理拆分方式、特定数据库引擎或特定 LLM Provider。

```text
Portable Semantic Contract (可移植语义契约)
        ≠
Language Implementation (语言框架实现：DeepBase / Python Runtime)
        ≠
Human-facing Realization (人机呈现基础设施：HB / Python Adapter)
        ≠
Product Domain Model (产品领域模型：AsWish / AXIS)
```

---

## §1 母规范渊源映射 (Source Mapping)

本契约声明范围内的每一个条目，均严格溯源至已冻结的真实 EHAI 规范文本。条目必须明确区分**真实母规范法源（Canonical Source）**与**下游工程解释（Derived Engineering Interpretation）**：

| 契约条目代号 | 语言无关抽象语义 | 真实母规范法源 (Canonical Source) | 下游工程解释 (Derived Engineering Interpretation) |
| :---: | :--- | :--- | :--- |
| **SRC-01** | `CandidateSpace`<br>(候选提议空间) | • `EHAI.04.L4` §5.1 (`1–7：Choose（选择指定候选）`)<br>• `EHAI.02.L2` §4 (`Minimal Sufficient Delivery`) & §5.6 (`D6：Branches & Consequences`)<br>• `EHAI.05.L5` §15 (`标准选择语法（0–9）在 L5 中的定位`) | 机器针对当前上下文生成的提议在呈现空间上收敛为有界离散集合（有效业务候选上限为 7 项），避免无边界认知发散。 |
| **SRC-02** | `RecommendedMark`<br>(建议标记) | • `EHAI.02.L2` §7.2 反模式 1 (`Delivery Completion ≠ Advice Acceptance`) & 反模式 2 (`Delivery Success ≠ Persuasion Success`)<br>• `EHAI.04.L4` §5.1 (`1–7：Choose`) & §8.1 (`Choose ≠ Affirmation`) | 提议空间允许标注一项作为机器推理优先级建议（逻辑 1 号槽位），但仅为视觉与认知辅助，严禁隐式自动选中、自动提交或剥夺人类裁决权。 |
| **SRC-03** | `CandidateSelection`<br>(候选倾向选择) | • `EHAI.04.L4` §5.1 (`1–7：Choose`) & §8.1 (`Choose ≠ Affirmation`)<br>• `EHAI.03.L3` §10.3 (`承诺边界 Commitment Boundary`) | 人类在候选集合中选定某项意图；选择动作本身不天然具有承诺效力（`CandidateSelection ≠ Inherent Commitment`）；作为 Standard Choice Grammar 的 Choose meta-action，本身不天然具有 Judge、Authorize、Execution 或其它 commitment 效力；其是否形成正式 Human semantic commitment，必须由当前 Human Involvement Profile、Decision Context 与适用 Completion Semantics 决定；未跨越适用承诺边界前不改写权威真实状态。 |
| **SRC-04** | `Regenerate`<br>(候选集合重构) | • `EHAI.04.L4` §5.2 (`8：Regenerate（候选重构）`) & §8.4 (`Regenerate ≠ New Context`)<br>• `EHAI.03.L3` §10.3 (`承诺边界 Commitment Boundary`) | 请求机器在同一上下文重构提议集合；属于纯探索动作，自身绝不获取承诺效力，绝不改写权威真实状态。 |
| **SRC-05** | `HumanOverride`<br>(人类自主覆写) | • `EHAI.04.L4` §5.3 (`9：Reframe / Human Input（自定义输入）`)<br>• `EHAI.03.L3` §3.2 (`H1 / H2`) & §9.4 (`High-Leverage Human Contribution First`) | 人类超越既有提议集合进行自主自由表达的通用安全阀通道；当 Standard Choice Grammar / Candidate Space 在当前交互中适用并被呈现时，Human 必须保有 Reframe / Human Input 所提供的候选空间逃逸能力（`9 = Reframe / Human Input`，`9 ≠ Reject`），不受预设选项绑架；不要求无候选空间的交互机械呈现“9”。 |
| **SRC-06** | `FrameRejection`<br>(框架否定) | • `EHAI.01.L1` §2.1 (`R1: 人类主权与责任在人`) & §2.2 (`R2: 认知不对称性 Cognitive Asymmetry`)<br>• `EHAI.04.L4` §5.3 (`9：Reframe / Human Input`) & §8.2 (`Input ≠ Rejection`) | 人类对问题假设、分类体系或框架本身的根本性否定；系统严禁通过算法静默将框架否定归并或重映射为既有候选。 |
| **SRC-07** | `BackNavigation`<br>(导航回退) | • `EHAI.04.L4` §5.4 (`0：Exit without Commitment（无承诺退出）`) & §8.3 (`Exit ≠ Revocation`)<br>• `EHAI.05.L5` §15 (`标准选择语法（0–9）在 L5 中的定位`) | 步骤与视图的导航撤退（Navigation）；`0 / Exit without Commitment ≠ Reject ≠ Consent ≠ Judgment`；Exit / Back 本身不得被解释成对既有已生效正式决定的撤销。退出或回退时草稿的保存、丢弃、自动恢复或询问策略，均属于下游 Language Runtime 与 Product Policy 自由度。 |
| **SRC-08** | `SourceDistinction`<br>(来源可区分性) | • `EHAI.06.L6` §3.1 (`Semantic Unit`)、§4.1 (`Unit Minimum Envelope`)、§4.3 (`Recoverable, Not Duplicated`)<br>• `EHAI.02.L2` §5.3 (`D3：Evidence & Source`) | 人类来源表达（Human-originated source）与机器派生解释（AI-derived interpretation）必须在语义上逻辑可区分并维持必要溯源恢复能力；物理存储与字段形式自由。 |
| **SRC-09** | `CommitmentBoundary`<br>(承诺边界与效力分界) | • `EHAI.03.L3` §10.1 (`E 轴执行前置要求`)、§10.3 (`承诺边界`)、§10.4 (`授权与 Standing Authorization 中的不重复原则`)<br>• `EHAI.06.L6` §6 (`Reality-Effect Closure Contract`)<br>• `EHAI.07.L7` §6 (`R3: Realization Conformance`) | 区分探索效应与承诺效应；产生权威状态改变必须具备适用的有效授权基础（含现场确认、事前授权或常态规则；Need Auth ≠ Need Repeated Auth）。 |
| **SRC-10** | `RecoverableLineage`<br>(可恢复的因果血统) | • `EHAI.06.L6` §2.1 (`R1: 语义连续性 Semantic Continuity`) & §4.3 (`Recoverable, Not Duplicated`)<br>• `EHAI.04.L4` §6.1 (`Recoverable + Traceable + Context-Bound`) | 已生效的 semantic / authoritative effect 必须能够恢复与其成立有关的 applicable Authority Basis、Context、Qualification、Source / Provenance 与 Lineage；具体哪些要素存在，由该 effect 的实际来源、效力类型与适用性决定；兼容 Standing Authorization、Rule-derived Authority、Prior Authorization、Human-stated source、Tool-observed source 与 Model-derived interpretation，不假定所有 effect 都有新的 Human intent。 |

*(注：本表所列条款均经逐字核对最终 sealed canonical L1～L7 文本。如后续扩展条目无法在冻结规范中确立直接法源，必须显式标注 `SOURCE NOT YET ESTABLISHED`)*。

---

## §2 交互语义契约 (Interaction Semantic Contract)

本节定义语言无关的可移植交互语义。具体编程语言语法和 UI 呈现行为属于下游实现自由：

### 2.1 候选提议空间 (`Candidate` & `CandidateSpace`)
- **定义**：机器针对当前上下文所生成的离散提议集合。
- **抽象属性**：
  - 提议标识与摘要；
  - 领域上下文引用；
  - 建议标记（`IsRecommended`）：最多允许 1 项标记为优先级建议，仅供认知辅助，禁止默认自动提交；
  - 容量收敛：单次呈现的有效业务提议数量上限为 7 项。
- **信息不足状态（NoReliableCandidates）**：当机器缺乏依据无法形成可靠提议时，必须进入诚实无候选状态，说明未确定性，并保留自由覆写与返回通道。

### 2.2 候选倾向选择 (`CandidateSelection`)
- **定义**：人类在候选提议集合中表达选择倾向的操作事件。
- **语义约束**：
  - 单选基线：表达对特定单项提议的倾向；
  - 基数扩展（Decision Cardinality）：支持对 1～7 提议进行多项倾向标记；
  - **非天然承诺（`CandidateSelection ≠ Inherent Commitment`）**：CandidateSelection 作为 Standard Choice Grammar 的 Choose meta-action，本身不天然具有 Judge、Authorize、Execution 或其它 commitment 效力；其是否形成正式 Human semantic commitment，必须由当前 Human Involvement Profile、Decision Context 与适用 Completion Semantics 决定。
    - 恪守 L4 理论不变量：
      $$\text{Choose} \ne \text{inherently Judge}$$
      $$\text{Choose} \ne \text{inherently Authorize}$$
      $$\text{Choose} \ne \text{Execution}$$
    - 允许定型承接：
      $$\text{Choose} + \text{applicable Profile} + \text{Decision Context} \to \text{formal typed Human act}$$
    - 严禁将选择绝对化表述为“永远只是探索”；在未满足适用承诺边界与完成语义前，不改写权威真实状态。

### 2.3 重生成 (`Regenerate`)
- **定义**：人类要求机器在当前上下文背景下重新构造一组候选提议。
- **语义约束**：
  - **纯探索性**：重生成属于探索动作，自身绝不获取承诺效力，绝不污染权威状态与已存决策；
  - **认知参照保持**：重生成过程中，上一轮提议应在人机表面维持认知参考，避免界面跳闪与参照物丢失。

### 2.4 人类自主覆写 (`HumanOverride` / `9: Reframe / Human Input`)
- **定义**：当 Standard Choice Grammar / Candidate Space 在当前交互中适用并被呈现时，人类脱离预设候选集合，直接以自然意图进行自主表达的交互通道。
- **语义约束**：
  - **逃逸主权**：`9 = Reframe / Human Input`，`9 ≠ Reject`。人类必须保有脱离预设提议集合进行自主自由表达的候选空间逃逸能力，不受预设选项绑架；
  - **适用范围约束**：当 Standard Choice Grammar / Candidate Space 在当前交互中适用并被呈现时，必须提供该逃逸通道；不要求没有 Candidate Space 的所有人机交互界面都机械呈现“9”；
  - **自由表达性**：支持接收任意未经预设枚举约束的自然语言表达；
  - **通道主权保护**：当人类进入自主表达态时，物理输入通道应受到保护，防止常规交互快捷键产生意图干扰。

### 2.5 框架否定 (`FrameRejection`)
- **定义**：人类明确否定当前任务的前提假设、问题结构或分类体系本身。
- **语义约束**：
  - **防静默重映射不变量（Non-Remapping Invariant）**：系统**绝对严禁**通过相似度计算强行将框架否定言论归并或重映射为既有候选之一；
  - **机器解释不确定性处理**：当机器无法充分解释人类意图时，必须恪守：
    $$\text{Preserve Human Source}$$
    $$\text{Do Not Fabricate Understood Meaning}$$
    严禁捏造虚假理解。是否标记为特定存疑状态、是否或何时触发澄清交互（Clarify），由适用 Qualification、L3、L4 与 Product Binding 决定，公共契约不作机械流程绑定；
  - **框架解构**：框架否定属于更高层级意图，不应被降级为对既有提议对象的局部属性修改。

### 2.6 导航退出与回退 (`BackNavigation` / `0: Exit without Commitment`)
- **定义**：人类请求将工作流或界面步骤回退至上一阶段或退出当前提议空间。
- **语义约束**：
  - **规范语义**：`0 / Exit without Commitment ≠ Reject ≠ Consent ≠ Judgment`；
  - **效力不回溯**：Exit / Back 本身不得被解释成对既有已生效正式决定的撤销；
  - **去产品政策化**：退出或回退时草稿的保存、丢弃、自动恢复或询问策略，均属于下游 Language Runtime 与 Product Policy 自由度，公共契约不作统一定义。

### 2.7 机器解释与权威效力定义（去产品化重写）
- **`AIInterpretation`（机器派生解释）**：
  > 由机器基于人类来源表达（Human Source）或交互上下文形成的派生结构化解释。它必须在语义上与人类原文逻辑可区分，并维持必要的因果追溯线索（Provenance）。
- **`CanonicalEffect`（权威状态效力）**：
  > 某一具体工程实现依据其合法效力规则，对其权威状态（Canonical State）产生的已生效改变。具体产品领域对 Canonical State 的定义（例如规格树更新或商业交易执行）属于产品绑定层范畴。

---

## §3 状态与效力契约 (State / Effect Contract)

跨语言工程实现必须共同维护以下抽象状态机与效力分界：

```text
┌────────────────────────────────────────────────────────┐
│ 1. 探索状态 (Exploration State)                         │
│                                                        │
│ 语义: 人类浏览、候选选择倾向标记、重生成、导航返回等   │
│ 效力: 产生探索效应 (Exploration Effect)，但不天然具有   │
│       承诺效应 (Commitment Effect)。                   │
└──────────────────────────┬─────────────────────────────┘
                           │ 提交提议或触发审查
                           ▼
┌────────────────────────────────────────────────────────┐
│ 2. 待审 / 待裁决状态 (Review State)                     │
│                                                        │
│ 语义: 呈现机器解释提议、影响范围与证据线索，等待裁决   │
│ 效力: 待定 (Pending)。权威状态保持不变。               │
└──────────────┬─────────────────────┬───────────────────┘
               │                     │
    裁决动作:  │ 拒绝 / 退出 / 存疑   │ 具备合法授权依据
               ▼                     ▼
┌───────────────────────────────┐ ┌──────────────────────┐
│ 3a. 未承诺退出 / 拒绝          │ │ 3b. 承诺门禁 (Gate)  │
│     (Non-Commit / Reject)     │ └──────────┬───────────┘
│                               │            │ 跨越门禁
│ 语义: 产生拒绝/退出语义效应， │            ▼
│       被拒绝事项不予生效执行  │ ┌──────────────────────┐
└───────────────────────────────┘ │ 4. 权威生效状态      │
                                  │    (Canonical Effect)│
                                  │                      │
                                  │ 权威状态发生有效改变，│
                                  │ 固化不可变审计基线。  │
                                  └──────────────────────┘
```

### 3.1 探索效应与承诺效应的分离
- **`CandidateSelection ≠ Inherent Commitment`**：
  - 探索状态并不等于绝对零持久化。具体实现合法地记录草稿、对话历史、探索上下文、调试日志等临时状态，并不违反本契约；
  - 核心约束在于：探索阶段产生的数据变动，绝不天然等同于不可逆的业务承诺（Commitment）。哪些存储介质可写由具体产品绑定决定。

### 3.2 承诺门禁去 AsWish 化与授权基础
- **核心原则**：**产生不可逆承诺与权威状态改变，必须满足适用的 EHAI 授权与执行边界要求**。
- **兼容多样化授权形态**：
  $$\text{Need Authorization} \ne \text{Need Repeated Manual Authorization}$$
  合法授权依据包括但不限于：
  1. **显式现场核准（Explicit Confirmation）**：人类在 Review 界面显式点击核准；
  2. **事前 / 常态授权（Prior / Standing Authorization）**：依据事先明确的规则、权限配额或工作流策略允许自动跨越门禁；
  3. **适用规则权限（Applicable Rule Authority）**：合规框架赋予的确定性授权。
- **严禁 AI 静默自决**：在缺乏上述任何合法授权依据时，AI 绝对无权擅自触发权威状态修改。

### 3.3 拒绝与退出语义的准确界定
- **区分被拒事项非执行性与拒绝本身之语义效力**：
  $$\text{Rejected Action Not Applied} \ne \text{Reject Has No Semantic Effect}$$
  Reject 不得产生“被拒绝事项”的接受、授权或执行效力（被拒绝提议不生效）；但 Reject 动作本身可依据当前 Human Involvement Profile、Decision Context 与适用 Completion Semantics 形成正式 Human semantic effect（如正式记录人类拒绝裁定），并可被权威系统登记审计。
- **去产品化解耦**：特定产品中“拒绝变更集导致规格树内容未变”（如 AsWish 的 `RejectChangeSet → Spec Tree unchanged`）属于该产品的 Tier C 绑定逻辑，不得作为公共契约的通用规则。

---

## §4 意图来源与溯源契约 (Source & Provenance Contract)

### 4.1 逻辑分立与溯源可恢复性
- **核心语义不变量**：
  $$\text{Human Source} \ne \text{AI Interpretation}$$
  人类原始表达（Human-originated source）与机器派生解释（AI-derived interpretation）必须在语义上逻辑可区分；与其成立相关的 Qualification、Source、Provenance / Lineage 必须能够按适用范围恢复。
- **实现与存储自由度**：本契约不强制特定的物理字段设计（如不强制要求作者与时间戳必须为独立物理字段），不强制特定的存储物理拆分（单文件、双文件、单表、多表或事件流数据库等均属下游实现自由），只要满足逻辑可区分性与溯源恢复要求。

### 4.2 来源分类与溯源表达 (Source Typing & Provenance)
公共契约不强制将特定枚举（如 `explicit / inferred / unknown`）作为唯一的跨语言来源规范。各语言实现允许根据 L6 规范语义，采用等价的来源分类与标记，例如：
- `Human-stated`（人类直接陈述）
- `Model-inferred`（模型推理派生）
- `Rule-derived`（规则确定性派生）
- `Tool-observed`（工具/环境直接观测）
或其它与 L6 机器语义等价的实现编码。关键在于系统能够按适用范围恢复其 Qualification 与因果血统。

### 4.3 因果血统可恢复性契约 (Recoverable Lineage)
- **核心约束**：已生效的 semantic / authoritative effect 必须能够恢复与其成立有关的 applicable Authority Basis、Context、Qualification、Source / Provenance 与 Lineage；具体哪些要素存在，由该 effect 的实际来源、效力类型与适用性决定。
- **兼容多元授权与来源形态**：系统必须兼容以下合法形态，严禁假定所有 effect 都必须包含即时的人类来源意图或即时的机器推理快照：
  1. `Standing Authorization`（常设授权）；
  2. `Rule-derived Authority`（规则派生权限）；
  3. `Prior Authorization`（事前批量授权）；
  4. `Human-stated source`（人类直接表达来源）；
  5. `Tool-observed source`（工具/环境直接观测来源）；
  6. `Model-derived interpretation`（模型派生解释）。

---

## §5 第一批公共语义验证向量 (Common Semantic Vectors v0)

本节仅包含**语言无关、UI 无关、产品无关的纯语义验证向量**。UI 交互细节已下沉至 HB 测试，产品业务逻辑已下沉至 AsWish/AXIS 测试：

### CSV-001: 提议空间有界性与建议非执行性
- **场景**：机器生成离散提议集合。
- **输入**：包含 10 项推理结果的原始上下文。
- **断言**：
  1. 提议集合被收敛至 $\le 7$ 项；
  2. 逻辑 1 号槽位可具备建议标记（`Recommended`）；
  3. 建议标记不附带默认自动承诺效力。

### CSV-002: 提议单选与非天然承诺
- **场景**：人类在提议集合中选择某项倾向。
- **输入**：选择 3 号提议。
- **断言**：
  1. 系统派发包含 3 号提议标识的选择事件；
  2. CandidateSelection 本身不天然具有 Judge / Authorize / Execution 效力（`CandidateSelection ≠ Inherent Commitment`）；
  3. 其是否形成正式承诺由适用 Profile、Decision Context 与 Completion Semantics 决定；在当前探索/待审设定下，权威状态（Canonical State）保持未变，未发生静默承诺生效。

### CSV-003: 提议多选基数与显式提交分界
- **场景**：系统处于多选支持模式。
- **输入**：对提议 2、4 进行倾向标记。
- **断言**：
  1. 提议集合支持记录多个并列倾向；
  2. 倾向标记过程本身不天然具有承诺效力（`CandidateSelection ≠ Inherent Commitment`），未满足适用承诺边界与授权动作前不产生权威生效；
  3. 0（返回）、8（重生成）、9（自由覆写）等元控制项不参与业务多选勾选。

### CSV-004: 重生成探索性与权威状态只读性
- **场景**：人类请求重生成提议。
- **输入**：触发重生成操作。
- **断言**：
  1. 状态机迁移至重生成探索态；
  2. 重新向机器索取新提议；
  3. 整个过程对权威状态零修改，不产生不可逆承诺。

### CSV-005: 人类自主覆写可用性
- **场景**：人类跳出预设提议进行自主表达。
- **输入**：人类提供不在提议集合内的自由自然语言输入。
- **断言**：
  1. 自由输入被完整接收并标记作者为 `human`；
  2. 提议集合的选择状态被重置或退出；
  3. 该自由表达作为全新意图进入后续解释流，不自动形成承诺。

### CSV-006: 意图来源与机器解释的逻辑区分及可恢复性
- **场景**：人类提交自由文本后机器进行解释。
- **输入**：包含自然语言描述的人类意图表达。
- **断言**：
  1. 人类原始表达（Human Source）与机器派生解释（AI Interpretation）在语义上逻辑可区分；
  2. 与其成立相关的 Qualification、Source、Provenance / Lineage 能够按适用范围恢复；
  3. 允许具体实现采用与 L6 语义等价的来源分类编码（如 Human-stated / Model-inferred / Rule-derived / Tool-observed 等），不强制统一 cross-language enum 或固定物理字段拆分。

### CSV-007: 框架否定防静默重映射与真实意图保真
- **场景**：人类表达对当前框架的根本性否定。
- **输入**：语义为“否定既有分类体系，要求解构任务”的表达。
- **断言**：
  1. 系统完整保留该框架否定的人类来源表达（Preserve Human Source）；
  2. 机器解释管道绝对严禁静默将其强行归并或重映射为既有候选之一；
  3. 若机器无法充分解释，严禁捏造机器理解（Do Not Fabricate Understood Meaning）；后续是否标为存疑或何时触发澄清交互由适用上下文与产品策略决定，不作公共契约硬性流程绑定。

### CSV-008: 承诺门禁、拒绝效力与合法授权基础
- **场景**：从 Review State 迈向效力裁决或权威生效。
- **输入**：
  - 分支 A：人类执行拒绝（Reject）；
  - 分支 B：具备合法授权依据（显式确认、有效事前授权或规则授权）。
- **断言**：
  - 分支 A：Reject 不得产生“被拒绝事项”的接受、授权或执行效力（`Rejected Action Not Applied`）；但 Reject 本身可依据适用 Profile、Decision Context 与 Completion Semantics 形成正式 Human semantic effect 并被系统记录审计（`Rejected Action Not Applied ≠ Reject Has No Semantic Effect`）；
  - 分支 B：权威状态发生有效改变（Canonical Effect），并可按适用范围恢复与其成立相关的因果血统链。

---

## §6 版本演进与扩展治理

1. **版本基线**：本契约正式确立为 `APPROVED ENGINEERING BASELINE v0`，作为后续各语言实现与产品绑定工单的工程基线；它仍允许依据跨语言实现证据进行受控工程修订，不构成 EHAI 理论 Reopen；
2. **多语言同权验证**：任何具体编程语言（Delphi、Python 等）声称支持本契约，必须独立提供通过 CSV-001～CSV-008 的自动化证据日志；
3. **下沉测试职责分工**：
   - 界面按键、焦点、视觉动画等测试向量下沉至 HB 测试套件；
   - 业务树更新、快照落盘、商业交易等测试向量下沉至各产品测试套件。

---
*基线批准：2026-09-14*  
*执行主体：Antigravity Engine*  
*批准主体：Human Authority*
