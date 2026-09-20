---
title: "第六层：机器语义与介入基础设施 v1.0"
subtitle: "Efficient Human-AI Interaction · Machine Semantics & Intervention Infrastructure"
Status: Frozen v1.0
Layer: Machine Semantics & Intervention Infrastructure (第六层：机器语义与介入基础设施)
System: 高效 AI 人机交互体系 (Efficient Human-AI Interaction)
Specification: 高效 AI 人机交互规范 (Efficient Human-AI Interaction Specification)
Framework Implementation: DeepBase (用于工程化实现和承载规范的 Delphi 软件框架 · 工程实现代号 DB-MSI)
Nature: Engineering Architectural Master Specification (工程架构母规范)
Upstream:
  - 第一层《AI 人机认知哲学 v1.0》 (DeepBase-AI-Human-Cognition-Philosophy-v1.md · Frozen v1.0)
  - 第二层《AI 交付原则 v1.0》 (DeepBase-AI-Delivery-Principles-v1.md · Frozen v1.0)
  - 第三层《AI 人类介入原则 v1.0》 (DeepBase-AI-Human-Intervention-Principles-v1.md · Freeze Candidate v1.0)
  - 第四层《通用 AI 交互协议 v1.0》 (DeepBase-General-AI-Interaction-Protocol-v1.md · Freeze Candidate v1.0)
  - 第五层《HB 人机行为适配基础设施 v1.0》 (DeepBase-HB-Human-Behavior-Adaptation-Infrastructure-v1.md · Freeze Candidate v1.0)
Theory References:
  - ASTO-min 结构桥接语法 (State, Transition, Actor, Boundary Condition, Exception)
  - 动态存在与结构化认识论 (Dynamic Existence vs. Structural Representation)
  - 效力升格防线与语义保真原则 (Effect Escalation Defense & Semantic Fidelity)
Author: 架构组 / 资料员
Freezer: 主控 / 老板 (Human Authority)
Date: 2026-09-09
Frozen Date: 2026-09-09
Ruling: "DeepBase 第六层正式冻结裁定 (Frozen v1.0)"
---

# 第六层：机器语义与介入基础设施 v1.0
## Machine Semantics & Intervention Infrastructure v1.0 (Frozen v1.0)

> **【体系与规范定位声明】**  
> **Efficient Human-AI Interaction（高效 AI 人机交互体系）**定义 AI 与 Human 高效共同工作所需要的核心原则、交互规则、机器语义和产品实现边界。**Efficient Human-AI Interaction Specification（高效 AI 人机交互规范）**是其正式规范表达。**DeepBase** 是用于工程化实现和承载高效 AI 人机交互规范的 Delphi 软件框架。**HB** 是 DeepBase 中面向 Human 的统一人机交互承载与呈现基础设施，负责把高效 AI 人机交互体系中的语义、逻辑、状态、功能与交互行为，转化为 Human 可感知、可理解、可判断、可操作的交互。行为适配是 HB 的重要能力之一，但不是 HB 的全部。

> **【状态与法源声明】**  
> * **正式状态**：`Frozen v1.0`（经 Human Review 最终正式裁定冻结，2026-09-09）。自本裁定生效之日起，本规范作为高效 AI 人机交互体系第六层机器语义与现实介入基础设施的正式架构母规范。DB-MSI 是 DeepBase 工程实现里的名称（由 DeepBase Delphi 框架提供工程承载），不能作为体系 L6 的正式总名。后续任何实质修改必须显式进入规范修订流程，严禁通过工程实现或局部代码静默篡改母规范语义。  
> * **正式命名**：体系规范正式名称为《第六层：机器语义与介入基础设施 v1.0》（英文：`Machine Semantics & Intervention Infrastructure v1.0`）。`DB-MSI` 是 DeepBase 工程实现里的名称与代号，不可作为体系 L6 的正式总名。正式淘汰旧称 `DeepBase AI Infrastructure`，因 Model、Memory、Agent、Tool、Scheduler 等技术构件仅为公共语义基础设施的参与者，而非本层的定义来源。  
> * **法典定位句**：  
>   **同一现实，一套语义；不同能力，共用协议。变化必须显影，介入必须回观。**  
>   **L6 统一机器语义，不统一机器技术栈；统一现实介入协议，不把机器能力升级为 Human 权力。**

---

## 〇、文档状态与规范性用语 (Status and Normative Language)

### 0.1 规范性词汇遵从
本规范中出现的关键字遵循 RFC 2119 / 8174 规范性原则解释：
* **必须（MUST / SHALL）**：表达绝对的工程架构刚性约束或不可逾越的认识论底线；
* **严禁（MUST NOT / SHALL NOT）**：表达会导致语义漂移、效力越权或系统灾难的绝对禁止行为；
* **应当（SHOULD）**：表达推荐的最佳工程实践，偏离需有明确架构裁定依据；
* **允许（MAY）**：表达实现自由度内的可选特性。

### 0.2 认识论状态分级
全篇涉及的概念与机制分为三级认识论状态：
1. **已冻结（Frozen）**：理论闭环完成，核心定义、不变量与规范协议经 Human Authority 裁定正式冻结生效；
2. **强暂定（Strong Tentative）**：已具备明确架构方向与契约骨架，细节允许在工程原型中微调；
3. **待验证（To Be Verified）**：具体编码布局、跨系统适配开销与多代理交互性能，待真实工程闭环检验。

---

## 一、范围、职责与边界 (Scope, Responsibility and Boundaries)

### 1.1 L6 根问题与正式定位
第六层回答高效 AI 人机交互体系机器端的唯一根问题：

> **异构机器能力如何对同一现实说同一种语义，并以同一种受约束协议介入现实？**

**正式定位**：  
L6 为异构机器能力建立共同的结构化语义、参考表示、语义参与者契约与现实介入协议，使不同 Model、Memory、Agent、Tool、Scheduler、HB 及其它机器能力能够围绕同一动态现实形成、交换、保存、比较和延续同一语义，并在 Human Meaning、Authority 与 Responsibility 边界内，以可追踪、可重验证、可重新观察的方式介入现实。

### 1.2 必须继承的上层边界
L6 必须严格引用、消费和保持上层（L1～L5）已经冻结的准则与分类，**严禁在 L6 创建平行的认知或权责体系**：

```text
Human Judgment ≠ Authorization ≠ Responsibility
Recommendation ≠ Human Judgment
No Response ≠ Consent
Back / Escape ≠ Reject
Capability ≠ Authority
Memory ≠ Judgment
Preference ≠ Standing Authorization
Schedule ≠ Authorization
Execution ≠ Effect
```

* **人类六大裁决类型（L4 Judgment Types）原样继承**：
  * `J-F Fact`（客观事实确认）
  * `J-P Preference`（主观偏好抉择）
  * `J-T Tradeoff`（代价权衡裁定）
  * `J-G Goal / Frame`（目标与框架界定）
  * `J-A Authorization`（行动授权）
  * `J-R Responsibility`（责任归属确认）  
  L6 仅作为下游消费者接收和绑定上述裁决引用，严禁私自派生新的 Human Judgment 类型。

### 1.3 两个根本边界
L6 架构立足于两道不可突破的认识论底线：

1. **机器表示不等于存在本体（Machine Representation ≠ Existence）**  
   机器在任何时刻拥有的，仅仅是对动态客观现实所形成的**有限、离散、具备认识资格约束的结构化表示**，绝非客观现实本身。现实永远超出机器当前表示。
2. **机器能力不等于人类权威（Machine Capability ≠ Human Authority）**  
   机器无论具备多么高阶的推理、生成、规划或执行能力（Capability），绝不因能力本身而自动衍生出人类的意义赋予（Meaning）、价值决断（Judgment）、行动授权（Authorization）或现实责任（Responsibility）。机器能力永远受制于人类权责边界。

### 1.4 L6 的三个一级组织层
为确保全系统统一语义治理，L6 严格按以下三个高层结构组织，**严禁将 Model、Memory、Agent 等技术构件并列为同级基础设施**：

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        A. Unified Semantics                            │
│                 (不同机器能力共同说什么语言？最小核心语义语法)                 │
├────────────────────────────────────────────────────────────────────────┤
│                       B. Unified Representation                        │
│                (不同技术系统怎样表达与交换同一种语义？参考 IR)                 │
├────────────────────────────────────────────────────────────────────────┤
│                          C. Unified Runtime                            │
│            (不同机器能力在运行中如何协同介入现实而不漂移？协议与生命周期)          │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.5 四大核心系统不变量
L6 系统的所有模块、协议与实现必须无条件满足以下四大母不变量：

1. **禁止静默语义升格（No Silent Semantic Upgrade）**  
   没有新的、合法的语义来源或人类显式授权，任何机器组件严禁单方面提升语义的真实性、权威性或现实效力。包括但不限于：
   * `Inference → Reality`（推理假设升格为客观现实）：严禁；
   * `Recommendation → Human Judgment`（机器建议升格为人类裁决）：严禁；
   * `Judgment → Authorization`（人类价值判断升格为执行授权）：严禁；
   * `Memory → Preference`（历史记录升格为当前固定偏好）：严禁；
   * `Repeated Authorization → Standing Authorization`（单次或多次授权升格为长效无限授权）：严禁；
   * `Tool Success → Reality Effect`（工具执行返回成功升格为真实世界效果达成）：严禁；
   * `Schedule → Future Consent`（定时调度计划升格为未来执行同意）：严禁。
2. **内部原生自由，边界公义对齐（Native Internally, Semantic at Boundaries）**  
   单个 Model、Agent 内部推理、数据库持久化或算法模块内部可以使用任意原生的对象结构、临时状态、张量或私有格式；但**一旦跨越组件边界、跨越参与者通信或进入现实介入链路，必须完整解析（Resolve）并投影（Project）到 MSI 公共语义语法**。  
   *架构原则：统一语义，不统一机器技术栈。*
3. **引用先于复制（Reference Before Duplication）**  
   具有全局同一性与法源依据的语义对象（特别是来自上层的 Human Goal、Judgment、Preference、Authorization、Responsibility），必须通过唯一标识进行显式引用与血统追踪。禁止为了局部处理而肆意深拷贝并自行重新解释。
4. **介入必须闭环回观（Intervention Must Close the Reality Loop）**  
   任何现实介入绝不能在“工具调用成功（Tool Return 200/Success）”处草草终结。必须经历执行取证、重新观察现实、生成新切片并进行差异调和的比对闭环。  
   *因果铁律：Observed Difference ≠ Causal Effect（观察到的差异不自动等于介入引发的效果）。*

---

## 二、核心语义语法 (Core Semantic Grammar)

本章是 **Unified Semantics** 的基石。所有异构机器能力交换的语义，统一收敛为四种基础语义结构（Minimal Semantic Grammar）。

```text
                    L6 核心语义四元骨架
┌─────────────────────────────────────────────────────────────┐
│ 1. Assertion                (原子结构化断言)                │
├─────────────────────────────────────────────────────────────┤
│ 2. Slice                    (围绕探究意图的最小充分语义切片)  │
├─────────────────────────────────────────────────────────────┤
│ 3. Intervention             (试图引发预期差异的受约束介入)  │
├─────────────────────────────────────────────────────────────┤
│ 4. Typed Semantic Relations (一等结构：差异/证据/血统/效力关系)│
└─────────────────────────────────────────────────────────────┘
```

### 2.1 语义单元同一性 (Semantic Unit Identity)
任何基础语义结构（Assertion、Slice、Intervention 以及独立的 Relation 实例）必须具备其系统内不可混淆的语义单元唯一标识（Semantic Unit Identity）。  
*区分声明*：`Semantic Unit Identity ≠ Referent Identity`。描述同一现实对象的五条断言具有相同的 Referent Identity，但拥有五个不同的 Semantic Unit Identity。

### 2.2 断言 (Assertion)
**定义**：Assertion 是关于某个客观或主观指称对象（Referent）的一项结构化语义表达。  
* **来源广泛性**：人类显式陈述（Human-stated）、工具客观测量（Tool-observed）、规则逻辑推导（Rule-derived）、大模型概率推断（Model-inferred）均可形成 Assertion。
* **认识资格约束**：每条 Assertion 必须具备可恢复的认识资格（Epistemic Qualification），明确标明其认识来源与角色区分。规范不要求物理上单值枚举，但要求认识资格必须在全链路可恢复且严禁被静默改写。
* **严禁退化**：**严禁把孤立的 `key=value` 视为完整的机器语义**。孤立的 `key=value` 若无法恢复其 Referent、Epistemic Qualification，以及在时间对其意义或适用性具有影响时所需的 Temporal Semantics，则不足以构成完整 Assertion。

### 2.3 语义切片 (Slice)
**定义**：Slice 是围绕一个特定的探究意图（Inquiry），由一组相关 Assertions 聚合而成、并达到当前用途**最小充分语义闭包（Minimum Sufficient Semantic Closure）**的属集认识。  
* **非瞬时快照**：Slice 不是数据库的整库瞬时 Snapshot，更不是对整个物理世界的穷尽镜像；它是带着特定问题、由关联证据组成的闭合视域。
* **观察不等于切片（Observation ≠ Slice）**：未完成闭包校验、正在收集中的散乱观察数据属于切片形成过程（Slice Formation），**禁止为其增设 Draft Slice / Working Slice 等平行核心类型**。
* **锚定基石**：重大的人类裁决（Human Judgment）、现实介入动作（Intervention）、历史回放（Replay）必须严格绑定到确定版本的 Slice 上。

### 2.4 介入动作 (Intervention)
**定义**：Intervention 是机器基于当前合法语义基础，试图使 Reality 出现某个 Intended Difference 的受约束介入。  
* **介入不等于工具调用（Intervention ≠ Tool Call）**：Tool Call 是具体的底层 API 触发（如发送 HTTP POST、执行 SQL UPDATE）；而一个 Intervention 代表具有明确业务与权责意图的宏观操作，底层可由一次、多次或条件式 Tool Calls 协同组合完成。
* **语义必备恢复要素**：一个合法的 Intervention 在语义上必须能够完整恢复以下要素（具体字段名在工程层不锁死）：
  1. `Actor`（承担该 Intervention 行为语义的介入主体；Proposal Producer 与底层 Executor 分别通过独立语义关系引用，不与 Actor 默认合并）；
  2. `Target`（介入所作用的目标指称对象）；
  3. `Semantic Basis`（决策所依据的 Slice 引用及差异证据）；
  4. `Intended Difference`（期望在现实中建立的目标状态差异）；
  5. `Boundary & Ceiling`（允许执行的最大作用范围与额度限额）；
  6. `Expected Consequence`（对系统的预期后续影响评估）；
  7. `Human Authority Reference`（所依托的人类授权凭证引用；当 Intervention 跨越 Human Authority、Commitment、Responsibility-sensitive Effect 或其它上层规定的授权边界时必须可恢复）。内部技术写入、缓存更新、已有 Standing Authorization 覆盖范围内的动作等，不因“write”物理性质自动要求新增 Human Authorization。

> **角色解耦声明**：Proposal Producer（提议生成者）、Intervention Actor（介入行为主体）与底层 Executor（具体工具执行者）在概念上保持分离，通过语义关系进行明确区分，严禁混为一谈。

### 2.5 类型化语义关系 (Typed Semantic Relations)
**定义**：Typed Semantic Relation 是连接语义单元之间的第四种一等（First-Class）语义结构。  
母规范确立：**全面废除独立的 Difference System、Evidence System、Dependency System 或 External Reference System**。所有复杂的网状关系收敛为类型化的语义连接：

1. **差异关系（Difference · Qualified Comparison Relation）**：  
   **架构核心裁定：Difference 不再作为与 Assertion/Slice 平级的独立核心对象，而是作为一等的类型化比较关系（Qualified Comparison Relation）存在**。它可以用于比较 Assertion 之间或 Slice 之间，不预设天然必须是 Baseline vs Target，也不预设天然必须是 Material Difference。Difference 本身保持中性，其 Material / Non-material / Unresolved 状态属于后续的评价资格判定（Qualification），并严格坚守 **Difference ≠ Error**（差异不自动等于错误）。
2. **证据关系（Evidence Linkage）**：Evidence 本身可以是客观工件（Artifact）、环境观测（Observation）、结构化断言（Assertion）、人类陈述（Human Expression）或外部源（External Source）等；而 Evidence Linkage 是一等的类型化语义关系（Typed Semantic Relation），用于连接被支撑语义与证据来源。MSI 不建立与公共语义平行的独立 Evidence 语义系统；
3. **推导关系（Derivation）**：复合结论与前置输入断言之间的认识推导关系（derived-from），严禁将其表述为物理世界的现实因果关系；
4. **依赖关系（Dependency）**：任务或断言有效性对其他前提条件的依赖；
5. **从属关系（Membership）**：Assertion 属于特定 Slice 闭包的属集关联；
6. **血统关系（Lineage）**：语义在时间演进与模型流转中的源流追溯；
7. **废止替代关系（Supersession）**：新语义对旧语义的显式置换；
8. **外部参照关系（External Semantic Reference）**：连接外部系统对象（如 GitHub Issue、ERP 单号、知识库 URI）；
9. **授权溯源关系（Authority Linkage）**：介入动作与上层 `J-A Authorization` 裁决的凭证绑定；
10. **效力影响关系（Effect Linkage）**：介入动作与再观察切片之间的关联映射。严禁直接假定为确定性现实因果，必须在语义上至少区分 observed-after（后验观察）、associated-with（相关联）与 causal attribution / causal hypothesis（因果归因假设，必须携带明确的认识资格）。

---

## 三、语义坐标与认识资格 (Semantic Context and Qualification)

语义单元本身不能孤立存在，必须依托其时空坐标、场域意图与认识资格。  
*重要工程原则*：**强制可恢复，非物理冗余（Mandatory means semantically recoverable, not physically duplicated）**。语义单元可以通过直接持有（Direct）、层级继承（Inherited）或引用关联（Referenced）三种路径恢复其完整坐标，不要求每条底层记录无脑冗余全部字段。

### 3.1 指称对象 (Referent)
**职责**：回答“这项语义在说现实世界中的什么对象”。  
* 明确区分：`Referent Identity ≠ Semantic Unit Identity`。同一个物理文件、数据库表或业务客户（Referent）在不同时间演进中会对应多个断言与切片版本。

### 3.2 探究意图 (Inquiry)
**职责**：回答“为什么在此时此地聚集这一组属集，为什么某项属性具有相关性，为什么某项差异具有实质性”。  
* **无意图不差异准则**：**脱离明确的 Inquiry，任何机器组件严禁随意宣告存在“实质性差异（Material Difference）”**。  
* **差异实质性分层权责（Materiality Contract）**：
  1. L6 Core 定义 Materiality 契约原则与评估语义，要求必须支持判定为 Material、Non-material 或 Unresolved；
  2. Domain Profile 定义领域相关属性与比较规则；
  3. Product Profile 定义产品级敏感度与容差阈值；
  4. 涉及 Human Meaning / Value / Goal / Authority / Responsibility 时，最终仍回归上层 Human Judgment 判定。

### 3.3 时间语义 (Temporal Semantics)
**职责**：精确表达现实演化与认识形成的时间流，**严禁将所有时间暴力降维为单一的 `created_at` 时间戳**。必须支持细分的时间语义维度：
* `Observation Time`（机器对现实发生观察动作的时间点）；
* `Effective Time`（现实世界中该事实真正生效的时间点）；
* `Temporal Anchor`（推演分析所依托的时空锚定参考点）；
* `Observation Window`（连续采样或日志聚合的时间窗口区间）；
* `Valid From / Until`（语义声称合法有效的时间区间）。

### 3.4 交互场域绑定 (Interaction Field Binding)
**职责**：界定在一个连续区间内，默认 Human–Machine Interaction Regime 保持质的同一性与有效性的场域（Interaction Field）。  
* **反泛化与一等结构声明**：**Interaction Field 只定义为 Human–Machine Interaction Regime 的有效性场域，严禁将其泛化为所有机器计算的万能 Context**。Field 本身属于一等有效性结构（First-Class Validity Structure），而 Field Binding 则是语义单元的坐标属性。超出该 Field 的行为必须触发场域跃迁审查。

### 3.5 认知主体 (Epistemic Subject)
**职责**：记录是谁形成了该项语义认识（如指定 ID 的人类操作者、特定版本的 LLM、指定的静态扫描工具或自动化规则引擎）。

### 3.6 认识资格 (Epistemic Qualification)
**职责**：标定该项认识的认识来源与角色区分，不建立从高到低的单一可信度阶梯。任何机器组件交换语义时，必须由契约保证以下认识资格的清晰分离，严禁混淆：

```text
Human-stated   (Human 是该陈述的语义来源。对 Human 自身 Meaning、Value、Goal、Judgment、Authorization、Responsibility 等，上层 Human Semantic Source 具有合法法源地位；对外部 Reality 的事实判断，Human 同样可能可谬)
     ≠
Tool-observed  (工具在其测量/观察边界内取得的观察，不等于绝对客观真理)
     ≠
Rule-derived   (形式化规则或确定性逻辑推导)
     ≠
Model-inferred (概率化大模型推理分析，存在幻觉与随机性风险)
     ≠
Predicted      (对未来尚未发生事件的趋势预测)
     ≠
Unknown / Conflict (系统显式承认的未知项或证据自相矛盾项)
```

> **架构裁定**：Epistemic Qualification 是认识来源与角色的本质区分，绝不建立单一线性置信度高低。规范不冻结“每个 Assertion 物理上只能有一个 Qualification Enum”，核心底线是认识资格必须在全链路可恢复且严禁被静默篡改。

### 3.7 来源标识 (Source Identity)
**职责**：记录生成该语义项的最原始载体信息（如文件路径、网络响应报文 ID、日志行号或特定 Prompt Session ID），提供可追溯、可验证的溯源原点。

---

## 四、语义连续性与历史真实性 (Semantic Continuity and Historical Integrity)

### 4.1 语义连续性核心公理
Semantic Continuity 是 L6 首要的系统不变量，而非某个局部的业务功能。其核心哲学定义为：

> **同一语义跨组件、跨表示、跨时间、跨版本和跨介入过程传播时，其身份、含义、认识资格、Human 法源和效力边界不得静默变形；发生 Material Difference 时，变化必须显式建立。**

核心表达：
```text
Continuity ≠ No Change
```
> **Change without silent semantic distortion（允许变化，但绝不允许静默的语义扭曲）。**

### 4.2 跨变迁适用性 (Applicability Across Change)
历史形成的断言或切片，不能假定在现实变迁后依然自动适用。系统每次消费历史语义时，必须校验其前置条件是否依然满足；一旦失效，必须重新资格化（Requalification）。

### 4.3 语义与指称连续性 (Semantic / Referent Continuity)
在跨步骤流转中，指称对象（Referent）的真实世界映射必须保持恒定，语义单元的演进必须挂载在同一 Referent 线上，防止发生偷换概念或张冠李戴。

### 4.4 血统与废止 (Lineage & Supersession)
**历史语义保护底线**：一旦 Semantic Unit 已成为 Human Judgment、Authorization、Material Intervention、Canonical Evidence、Replay 或其它重要历史语义的依据，其历史语义身份和当时内容不得被静默重写，后续修正必须通过 successor / supersession 等关系显式表达，历史语义单元完整保留于血统（Lineage）中。对于临时、未绑定重要效力的工作态语义表示，实现层可自主决定就地更新策略，规范不作一律禁止原位覆写的教条限制。

### 4.5 差异与依赖驱动的失效 (Dependency-Driven Invalidation)
当再观察切片与基准切片计算出 Material Difference 时，系统实施基于依赖图谱的精准失效（Dependency-Driven Invalidation）：**只有实际依赖该 Material Difference 的语义、判断基础、Intervention 或 Projection 才被失效（Invalidated）、挂起（Suspended）或重新资格化（Requalified）**。与该差异无关的独立部分允许继续执行，严格与 L3 原则保持一致（E1 Continue Independent Parts）。在此过程中，Difference 始终保持中性描述，严禁带入主观贬义或错误定性标签。

### 4.6 场域连续性与场域跃迁 (Field Continuity & Transition)
* **场域内演进（Field Continuity）**：在同一 Interaction Field 内，随着对话深入或任务推进而产生的后续 Slice，属于**次要语义演进（Minor Semantic Evolution）**；
* **场域跃迁（Field Transition）**：Field Transition 的根判据是：**Relevant Attributes 的变化是否导致 Human–Machine Interaction Regime 发生质变**（业务目标变化、主体变化、承诺系统变化仅为常见示例，非穷举或绝对判据；Field Transition 亦不等于简单超过某个数值阈值）。发生 Field Transition 后，旧授权与假设必须重新检查其适用性（Applicability），但不得笼统规定全部失效；合法覆盖跨 Field 范围的 Standing Authorization 仍可能继续适用。场域跃迁属于**重大语义演进（Major Semantic Evolution）**。

### 4.7 版本的正确定位
**架构裁定：彻底废除独立的 Version Service**。  
版本号仅仅是对连续性结构的某种工程编码呈现，**版本绝不是连续性的来源**。连续性的真实来源是语义关系图谱中的 Lineage 与 Supersession。

### 4.8 历史真实性与回放 (Historical Integrity & Replay)
系统在执行历史复盘（Replay）、反思比对（Reflect）或审计调查时，必须精确呈现当时当刻的历史 Slice、认识资格与所处 Field，**绝对严禁依据事后获得的新知识篡改历史当时的认知记录**。

---

## 五、参考语义表示 (Reference Semantic Representation)

本章确立 **Unified Representation**。异构系统之间如何交换语义，遵循严格的单向依赖阶梯：

```text
Semantic Contract ──► Reference Semantic IR ──► Encoding Profiles
```

### 5.1 契约、IR 与编码的关系
* **Semantic Contract（语义契约 · 最高法源）**：第二章至第四章确立的不可动摇的认识论与系统边界；
* **Reference Semantic IR（参考中介表示 · 逻辑标准）**：规范各种语义单元与其属性的逻辑中介对象模型（Intermediate Representation），作为多语言、多组件对齐的共同中枢；
* **Encoding Profiles（具体编码实现 · 物理载体）**：在不同传输与存储媒介下的具体表现形式（如 JSON-LD、Protocol Buffers、Delphi Records、PostgreSQL Tables 等）。  
*严正纪律*：**严禁由现有数据库 Schema、JSON 字段习惯反向倒逼或决定上层语义理论**。

### 5.2 Reference IR 设计原则
Reference IR 承担跨语言实现的公共参照基准、一致性测试基准（Conformance Baseline）与结构转换支点。  
*工程后置与首发选型建议*：
1. **本母规范绝对不冻结具体的物理字段键名、UUID 编码规则或类名排布**，仅规范 IR 必须承载的语义槽位与逻辑投影关系；
2. 后续工程原型建议优先采用普通 JSON + JSON Schema 作为 interchange / conformance reference representation，并以 Delphi / Python 强类型结构作为语言绑定；
3. JSON-LD 仅作为未来可选的高阶 Encoding Profile，不作为核心语义公理绑定。

### 5.3 编码剖面与投影保真度 (Projection & Semantic Fidelity)
当组件将本地原生数据结构序列化至某特定 Encoding Profile，或反向反序列化回本地技术栈时，必须满足**语义保真度（Semantic Fidelity）**门禁：
1. 核心四大语义结构不可降维变形；
2. 认识资格（Epistemic Qualification）在跨编码转换中严禁降级丢失；
3. 关键时空坐标与血统引用链路保持完整闭环。

---

## 六、领域与产品剖面 (Domain and Product Profiles)

L6 MSI 是通用基础设施。不同行业领域与上层产品通过 Profile 机制进行特化扩充。

### 6.1 Profile 机制与继承底线
Profile 承担领域词汇、专有关系、专用差异比对规则与特定介入类型的扩展规范。  
**母规范最高铁律：Profile 只能扩展（Extend）、特化（Specialize）或映射（Map），绝对不得覆盖（Override）或削弱 L6 核心语义语法！**  
特别地，任何 Profile 严禁推翻或重新解释：
* Assertion、Slice、Intervention 的根定义；
* 人类六大裁决类型与人类授权边界；
* 认识资格来源的严格分离；
* Field Transition 的重大演进规则；
* Difference ≠ Error 准则；
* Tool Result ≠ Reality Effect 准则；
* Materiality Contract 分层定义权（Profile 仅定义领域/产品级属性、比较规则与阈值，不推翻核心语义）。

### 6.2 产品剖面映射范例：AsWish Profile
以代码规约与行为推演产品 AsWish 为例，其专业概念平滑映射至 L6 通用语义体系：
* AsWish **代码基线（Baseline）** ──► 映射为标准 `Slice`（带着特定审计 Inquiry 形成的闭合代码与元数据切片）；
* AsWish **实现结果（Implementation Result）** ──► 映射为工程执行后生成的对应 `Slice`；
* AsWish **规约差异（Specification Gap）** ──► 映射为基准切片与实现切片间的 `Typed Semantic Relation (Difference)`；
* AsWish **变更应用动作（ApplyChangeSet）** ──► 映射为挂载了授权引用的标准 `Intervention`。

---

## 七、语义参与者契约 (Semantic Participant Contracts)

本章规范异构技术组件在接入 L6 运行环境时的身份与行为边界。  
**架构声明**：**实现组件不等于参与者角色（Implementation Component ≠ Semantic Participant Role）**。一个实际的 Python 服务或 Delphi 模块可以同时兼具多种角色，但每个角色必须独立遵守对应的契约约束。

```text
                           L6 语义参与者角色拓扑
┌────────────────────────────────────────────────────────────────────────┐
│                        Semantic Orchestrator                           │
│                       (流程编排与语义协调，不僭越授权)                     │
└───────┬──────────────────────────┬──────────────────────────┬──────────┘
        │                          │                          │
        ▼                          ▼                          ▼
┌───────────────┐          ┌───────────────┐          ┌───────────────┐
│   Cognition   │          │   Semantic    │          │ Observation / │
│   Producer    │          │     Store     │          │ Execution Adp │
│ (推论建议生成) │          │ (历史保持防升格)│          │ (环境测量与取证)│
└───────┬───────┘          └───────┬───────┘          └───────┬───────┘
        │                          │                          │
        └──────────────────────────┼──────────────────────────┘
                                   ▼
┌──────────────────────────────────┴─────────────────────────────────────┐
│                       Human Projection Adapter                         │
│                    (L5/HB 对接桥梁，显像与意图解析)                      │
└────────────────────────────────────────────────────────────────────────┘
```

### 7.1 认知生产角色 (Cognition Producer · LLM / Rules / Predictors)
* **允许产出**：`Inference`（推论）、`Prediction`（预测）、`Recommendation`（方案推荐）、`Candidate`（选项集合）、`Intervention Proposal`（介入建议）；
* **绝对严禁产出**：`Observed Reality`（未经工具测量的客观现实）、`Human Judgment`（人类价值裁决）、`Human Authorization`（合法的执行授权）。

### 7.2 语义存储角色 (Semantic Store · Memory / Vector DB / Caches)
* **职责**：保存、索引与检索历史的 Semantic Units、Relations 与 Episodes；
* **核心戒律**：**检索不等于适用（Retrieval ≠ Applicability）**。  
  > **Memory preserves; it does not promote（记忆负责保真留存，绝不自行升格效力）。**  
  从向量数据库中召回历史人类偏好，仅代表历史上存在该记录，绝不自动赋予其支配当前决策的合法性。

### 7.3 语义编排角色 (Semantic Orchestrator · Agent Workflows)
* **职责**：负责协调 Inquiry、驱动 Cognition Producer、调度 Tool 并串联 Intervention 生命周期；
* **核心戒律**：严禁通过在复杂工作流内部拼装多条弱推论，凭空制造出不存在的人类授权。

### 7.4 观察与执行适配角色 (Observation / Execution Adapter · Tools / APIs)
* **职责**：与物理世界、操作系统、网络服务或数据库直接交互，产生客观环境测量断言（`Tool-observed Assertion`）与执行原始证据（`Execution Evidence`）；
* **核心戒律**：严禁自行宣告“用户目标达成（Human Goal Achieved）”或“整体现实效果已生效（Reality Effect Occurred）”，它只负责返回局部物理证据。

### 7.5 时态触发角色 (Temporal Trigger · Schedulers / Cron)
* **职责**：依据既定时间规则发出调度到达脉冲（Trigger）；
* **核心戒律**：**触发不等于承诺，调度不等于授权（Trigger ≠ Commitment, Schedule ≠ Authorization）**。定时器到期仅代表“应当检查当前是否具备介入条件”，绝不等于获得自动推进的免死金牌。

### 7.6 人机投影适配角色 (Human Projection Adapter · L5/HB Bridge)
* **职责**：充当 L5（HB 行为适配基础设施）与 L6 之间的标准结构化桥梁。
* **协作契约**：
  * **L6 ──► HB**：L6 向 HB 提交待人类理解与裁决的结构化语义对象（Material Semantics）；HB 负责将其投影为人类可承受的视觉、注意与操作界面；
  * **HB ──► L6**：HB 将人类的自然物理操作解析为符合 L4 协议的**结构化语义凭证（Human Semantic Reference）**交还 L6，**L6 绝不直接接收未解析的裸鼠标点击或原生按键事件**。

---

## 八、运行时语义协议 (Runtime Semantic Protocols)

本章确立 **Unified Runtime**。异构机器能力如何在运行态安全协同并受控介入现实。

### 8.1 语义事件协议 (Semantic Event Protocol)
用于规范跨语义参与者（Participants）的事件传播。Semantic Event Contract 只规定语义层面的传播契约与数据约束，不依赖特定的物理系统总线（Event Bus）、消息队列或拓扑结构。
* **报告内容**：报告“哪项语义单元在哪个场域中发生了什么性质的变化”；
* **引用优先（Event by Reference）**：采用 Event by Reference 机制，但不等于 Event 只能拥有一个孤立的 ID。一次合法的 Semantic Event 至少必须能够恢复：
  1. Event Identity（事件唯一标识）；
  2. Event Type（事件类型与状态跃迁性质）；
  3. Affected Semantic Refs（受影响的语义单元引用集合）；
  4. Temporal Semantics（发生与记录的时间语义）；
  5. Producer / Source（产生事件的参与者与来源标识）；
  6. Causal / Trigger Refs（适用时的因果触发引用）；
  7. 必要的 Field / Slice coordinate 坐标信息。
* **严格区分**：  
```text
Semantic Event ≠ Telemetry ≠ Human Notification
```
  语义事件属于系统内核状态广播，不等于商业遥测指标，更不等于打扰人类的前台通知。

### 8.2 现实介入生命周期协议 (Intervention Lifecycle Protocol)
统一一切 Agent、Scheduler、自动化流水线与规则引擎对现实的介入过程。六阶段主干构成了标准成功执行的逻辑生命周期，但不意味着所有 Intervention 必须强制走完全部阶段。协议允许显式的分支与提前终止语义（如 Rejected、Withdrawn、Expired、Failed、Unresolved 等，具体枚举不在本母规范冻结）：

```text
               现实介入六阶段生命周期主干
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ 1. Proposed  │ ──► │ 2. Qualified │ ──► │ 3. Committed │
└──────────────┘     └──────────────┘     └──────────────┘
                                                 │
                                                 ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│6. Reconciled │ ◄── │5.Re-observed │ ◄── │ 4. Executed  │
└──────────────┘     └──────────────┘     └──────────────┘
```

1. **提议阶段（Proposed）**：机器基于当前 Slice 推导产出介入提议（Intervention Proposal），说明意图与预期差异；
2. **资格化审查阶段（Qualified）**：系统对提议进行前置合规审查。**Qualification 绝不是一个简单的布尔标记 `status=true`**，它必须能够完整溯源其依据的基准切片（Slice）、适用的权责限额（Ceiling）以及所需的人类授权凭证（跨越权责边界时关联 `J-A Authorization Reference`）；
3. **承诺锁定阶段（Committed）**：当且仅当资格审查通过且满足承诺条件，在不可逆操作发生前，介入动作被正式标记为系统承诺（Commitment），锁定当前操作边界；
4. **底层执行阶段（Executed）**：调度底层工具或物理适配器执行操作，完整收集底层调用返回的原始证据（`Execution Evidence`）；
5. **现实回观阶段（Re-observed）**：**介入绝不在此刻宣告完成！** 观察适配器必须对真实世界进行重新采样，形成介入后的新语义切片（Post-Intervention Slice）；
6. **差异调和阶段（Reconciled）**：系统自动比对执行前后切片，计算其实际差异。  
   * **调和不等于成功（Reconciled ≠ Success）**：**Reconciled 仅表示 Intended Difference 与 Observed Difference 已经完成了客观的语义比对与调和，绝不直接等同于“执行成功”**。调和的结论可以为：
     * `achieved`（完全达成预期差异）；
     * `partially achieved`（部分达成）；
     * `not achieved`（未达成预期差异）；
     * `unresolved`（差异因条件限制无法判明）；
     * `accompanied by material unintended difference`（伴随出现实质性非预期副作用）。  
   系统严禁将调和状态本身直接宣告为业务成功。

*全链路防御公式*：
```text
Proposal ≠ Authorization ≠ Commitment ≠ Execution ≠ Effect
```

---

## 九、一致性认证 (Conformance)

为使公共语义基础设施具备真实效力，任何接入组件与子系统必须通过五大 Conformance 规范性审查：

### 9.1 核心语义一致性 (Core Semantic Conformance)
* 组件是否严格使用 Assertion、Slice、Intervention 与 Typed Relations？
* 是否杜绝将无源 `key=value` 当作合法语义？
* 是否将 Difference 正确实现为比较关系而非独立对象？

### 9.2 表示一致性 (Representation Conformance)
* 本地私有数据结构与 Reference IR 之间的双向映射是否保持语义保真（Semantic Fidelity）？
* 认识资格（Epistemic Qualification）与指称标识（Referent Identity）是否在跨格式序列化中无损保留？

### 9.3 剖面一致性 (Profile Conformance)
* 领域或产品 Profile 是否仅开展合法的词汇与关系扩展？
* 是否存在越权覆盖、推翻 L6 核心语法的恶性违规行为？

### 9.4 参与者契约一致性 (Participant Conformance)
* 模型类角色（Cognition Producer）是否发生越权宣告客观事实或伪造人类授权的违规？
* 存储类角色（Semantic Store）是否坚守“检索不等于适用”，不发生静默偏好升级？
* 调度类角色（Temporal Trigger）是否发生将定时器等同于执行承诺的违规？

### 9.5 运行时与介入一致性 (Runtime & Intervention Conformance)
* 介入动作是否严格遵循六阶段生命周期，严禁以工具调用成功冒充现实效果？
* 运行链路中是否坚决贯彻“禁止静默语义升格（No Silent Semantic Upgrade）”？

---

## 十、非目标与实现自由度 (Non-goals and Implementation Freedom)

### 10.1 明确不采纳的历史候选方向 (Rejected Historical Directions)
为防止历史包袱重新污染当前理论，母规范明确排除以下 12 项已被推翻的方向：
1. **恢复 `DeepBase AI Infrastructure` 旧名称**：AI 只是参与者，不是基础设施的定义来源；
2. **将 Field / Slice / Difference / Intervention 列为四个平级核心对象**：不再将 Field 与 Assertion / Slice / Intervention 等 Minimal Core Semantic Structures 并列；Interaction Field 仍保持 First-Class Validity Structure，而 Field Binding 作为 Semantic Coordinate 表达语义单元与当前 Field 的适用性关联；
3. **万能 Context 与 Context Service**：杜绝无边界、无结构的“大杂烩上下文服务”；
4. **建立独立的 Difference System**：Difference 是 Semantic Units 之间的 First-Class Qualified Comparison Relation，例如 Assertion–Assertion 或 Slice–Slice；Difference 本身保持中性，不自动等于 Material Difference，更不等于 Error；
5. **建立独立的 Evidence System**：MSI 不建立与公共语义平行的独立 Evidence Semantic System；Evidence 本体可以来自多种语义或外部来源，而其对 Assertion、Slice、Intervention 等语义结构的支撑关系统一通过 Evidence Linkage 表达；
6. **建立独立的 Dependency System**：依赖关系天然内置于语义图谱，无需额外系统；
7. **建立 Universal User Profile（全能用户画像）**：防范利用无边界历史画像推测人类即时偏好；
8. **建立 Universal JSON / 单一全局大统一格式**：不追求单一固定 JSON 统管一切，以 Reference IR 和契约约束跨媒介转换；
9. **建立 Central Semantic Server（单体中心语义服务器）**：MSI 是一套契约与协议规范，不强制要求物理上的集中单点服务器；
10. **将 Model / Memory / Agent / Scheduler 划为一级理论模块**：已全面重构为技术中立的参与者角色；
11. **建立独立的 Version Service**：版本从属于连续性图谱的衍生编码，不设独立实体；
12. **建立一套平行的 Observability 语义体系**：可观察事件直接复用核心语义引用，不另起炉灶。

### 10.2 工程后置与实现自由度 (Implementation Freedom)
母规范冻结的是 Meaning、Boundary、Role、Invariant、Protocol 与 Conformance。**本母规范严禁提前冻结以下具体工程实现细节**：
* 最终物理 JSON/YAML Schema 结构定义；
* Delphi 单元名、Record/Class 具体命名；
* RESTful / gRPC / COM API 的接口方法签名；
* 微服务划分与进程边界部署方案；
* UUID / URI 的物理生成算法；
* 关系型数据库表结构、SQL DDL 与索引方案；
* Event Bus 或消息队列的物理选型（Kafka, RabbitMQ, ZeroMQ 等）；
* 具体的 Model Provider 接入驱动实现；
* 特定的 Agent Framework 框架依赖；
* 底层 Tool Protocol 的二进制传输编码；
* 调度器 Scheduler 的时间轮具体数据结构实现；
* Typed Relation 与 Epistemic Qualification 的最终物理枚举常量代码。

---

## 附录 (Appendices)

### 附录 A：端到端语义演进与现实介入全流程示例 (End-to-End Walkthrough)

以下示例展示一个典型的自动化运维与优化场景，说明各层语义结构的协同流转：

```text
[场景：系统发现某核心业务数据库索引缺失，导致查询退化]

Step 1: 工具观察与断言生成
  - Observation Adapter 调用性能监控 API，测得 P99 延迟突破 5000ms。
  - 生成 Assertion#001: {
      Referent: "DB.Cluster.Primary",
      Content: "QueryLatency.P99 = 5200ms",
      Qualification: Tool-observed,
      Time: ObservationTime(2026-09-09T10:00:00Z)
    }

Step 2: 探究聚合与基准切片形成
  - 编排器以 Inquiry("Database Performance Diagnostics") 为导向。
  - 聚合性能监控、表结构、慢日志等断言，完成闭包审查。
  - 固化形成 Baseline Slice#101。

Step 3: 认知生产与推论建议
  - Cognition Producer (LLM) 分析 Slice#101。
  - 生成 Assertion#002: {
      Referent: "DB.Table.Orders",
      Content: "Missing Index on column [created_at]",
      Qualification: Model-inferred
    }
  - 产出介入提议: Intervention Proposal: "Create Index idx_orders_created_at"。

Step 4: 资格化与人类授权绑定
  - 该介入被判定将引发重大 DDL 锁表风险，超出自动化限额（Ceiling）。
  - 通过 L5/HB Human Projection Adapter 显化呈报给人类 DBA。
  - 人类确认收益与代价（J-T Tradeoff），并正式签发 J-A Authorization (ID: Auth#889)。
  - 介入进入 Qualified 状态，并与 Auth#889 建立权威溯源关系（Authority Linkage）。

Step 5: 承诺锁定与底层执行
  - 介入状态推进为 Committed。
  - Execution Adapter 执行 SQL，捕获底层执行返回结果，留存 Execution Evidence。

Step 6: 重新观察现实闭环
  - 介入绝不宣布完成！
  - Observation Adapter 再次发起采样，抓取执行后的性能数据，形成 Post-Intervention Slice#102。

Step 7: 差异调和终结
  - 系统建立 Typed Semantic Relation (Difference):
      Baseline: Slice#101 ──► Target: Slice#102
      Inquiry: "Verify Latency Recovery"
      Result: P99 降低至 45ms，未引入锁死异常。
  - 实际观察到的 Difference 与 Intended Difference 完成调和，Reconciliation Result 被判定为 `achieved`；因此本次 Intervention 以成功结果完成 Reconciliation。
```

### 附录 B：语义参与者多角色协同示意 (Participant Interaction Trace)

同一个 Agent 软件组件在不同处理阶段，严格按对应角色契约行使权力：
1. 作为 **Cognition Producer** 时，只负责分析数据输出建议，不擅自产生客观事实；
2. 作为 **Semantic Orchestrator** 时，只负责调度各方，不私自伪造授权；
3. 作为 **Execution Adapter** 时，只负责抓取工具原始执行凭据，不擅自宣布业务目标达成。

### 附录 C：产品剖面映射规范速查 (Profile Mapping Cheat Sheet)

| 产品专有概念 | L6 通用语义归宿 | 适用约束与底线 |
| :--- | :--- | :--- |
| **代码/业务基准** | `Slice` | 必须具备明确 Inquiry 与最小充分闭包，不可为全局瞬时全量数据。 |
| **执行产出/当前状态** | `Slice` | 记录执行后重新观察的事实属集。 |
| **规约偏离/差异审计** | `Typed Semantic Relation (Difference)` | 比较关系，必须关联前后两个 Slice，严格保持 Difference ≠ Error。 |
| **修复动作/状态发布** | `Intervention` | 统一经历六阶段生命周期，跨越权责与承诺边界时必须关联上层 `J-A` 授权凭证。 |
| **历史行为记忆** | `Semantic Store (Episode / Units)` | 坚守 Retrieval ≠ Applicability，历史记忆严禁静默升级为当前有效偏好。 |

### 附录 D：参考中介表示 (Reference IR) 概念骨架伪代码示意

> **【免责声明】以下仅为展示语义槽位与逻辑关联的非规范性示意伪代码，不构成工程实现的物理 Schema 约束。**

```text
// 1. Assertion IR 概念示意
ReferenceIR.Assertion {
  UnitID:         "sem-ast-20260909-00124",
  ReferentRef:    "ref://db/cluster/primary",
  InquiryRef:     "inq://diagnostics/db-perf",       // 可从所属 Slice 继承
  FieldRef:       "field://prod/ops/dba-session-09", // 可从所属 Slice 继承
  SubjectRef:     "sub://agent/diagnostics-runner",
  Qualification:  EpistemicQualification.ToolObserved,
  Temporal: {
    ObservationTime: "2026-09-09T10:00:00Z",
    EffectiveTime:   "2026-09-09T09:59:58Z"
  },
  ContentPayload: {
    Metric: "QueryLatency.P99",
    Value:  5200,
    Unit:   "ms"
  },
  SourceRef:      "source://telegraf/agent/metric-stream#offset=98432"
}

// 2. Slice IR 概念示意
ReferenceIR.Slice {
  UnitID:         "sem-slc-20260909-00088",
  InquiryRef:     "inq://diagnostics/db-perf",
  FieldRef:       "field://prod/ops/dba-session-09",
  ClosureStatus:  SemanticClosure.MinimumSufficientSatisfied,
  Assertions: [
    "sem-ast-20260909-00124",
    "sem-ast-20260909-00125",
    "sem-ast-20260909-00126"
  ]
}

// 3. Typed Relation (Difference) IR 概念示意
ReferenceIR.SemanticRelation {
  RelationID:     "sem-rel-20260909-00431",
  RelationType:   RelationKind.Difference,
  SourceUnitRef:  "sem-slc-20260909-00088", // Baseline Slice
  TargetUnitRef:  "sem-slc-20260909-00092", // Post-Action Slice
  InquiryRef:     "inq://diagnostics/db-perf",
  Materiality:    MaterialityStatus.MaterialDifferenceIdentified,
  Details: {
    DeltaP99: "-5155ms",
    SemanticImpact: "Performance Restored within SLA"
  }
}

// 4. Intervention IR 概念示意
ReferenceIR.Intervention {
  UnitID:         "sem-itv-20260909-00015",
  LifecycleStage: InterventionStage.Reconciled,
  ActorRef:       "sub://agent/dba-assistant",
  TargetRef:      "ref://db/cluster/primary",
  BasisSliceRef:  "sem-slc-20260909-00088",
  AuthorityRef:   "auth://human-approval/J-A-889",
  Boundaries: {
    MaxExecutionTimeMs: 30000,
    RiskCeiling: "DDL-Safe-Online-Only"
  },
  ExecutionEvidenceRefs: [
    "source://db-driver/ddl-log/tx-99432"
  ],
  PostSliceRef:   "sem-slc-20260909-00092",
  ComparisonRef:  "sem-rel-20260909-00431"
}
```

---
