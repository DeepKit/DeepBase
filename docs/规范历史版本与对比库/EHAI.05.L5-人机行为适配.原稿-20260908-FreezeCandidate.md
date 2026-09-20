---
title: "第五层：HB 人机行为适配基础设施 v1.0"
subtitle: "HB — Human Behavior Adaptation Infrastructure"
Status: Freeze Candidate v1.0
Layer: Human Behavior Adaptation Infrastructure (第五层：HB 人机行为适配基础设施)
System: 差异一元论 · 高效 AI 人机交互体系 (EHAI · Efficient Human-AI Interaction)
Specification: 高效 AI 人机交互规范 (EHAI Specification)
Framework Implementation: DeepBase (用于工程化实现和承载规范的 Delphi 软件框架)
Nature: Engineering Architectural Master Specification (工程架构母稿规范)
Upstream:
  - 第一层《AI 人机认知哲学 v1.0》 (EHAI.01.L1-人机认知哲学.md)
  - 第二层《AI 交付原则 v1.0》 (EHAI.02.L2-AI交付原则.md)
  - 第三层《AI 人类介入原则 v1.0》 (EHAI.03.L3-人类介入原则.md)
  - 第四层《通用 AI 交互协议 v1.0》 (EHAI.04.L4-通用交互协议.md)
Theory References:
  - ASTO-min 结构桥接语法 (State, Transition, Actor, Boundary Condition, Exception)
  - 认知保真度与证据链原则 (Epistemological Fidelity & Traceability)
  - 效力升格防线原则 (Effect Escalation Defense)
Author: 架构组 / 资料员
Freezer: 主控 / 老板
Date: 2026-09-08
Revision Note: |
  2026-09-08 Freeze Candidate Final Editorial Calibration:
    - 修复所有公式损坏，统一采用 Unicode ≠ 符号与普通排版，保证原始 Markdown 纯正
    - 明确定位为受原则约束的通用行为适配基础设施
    - AI Profile 中明确不呈现私有 Chain of Thought，采用 Key Reasoning Summary / Evidence Path / Difference / Unknown
    - Human Reality 去绝对化，转为工程适配前提
    - A0～A3 软化为时机语义，解除对特定 UI 控件或风险类型的死板绑定
    - 明确 Attention Arbitration 机制不提前冻结具体实现架构
    - 明确 Recoverable Attention 不由 HB 承担长期上下文存储与持久化
    - 明确 HB Core 不封装自然语言理解与推理引擎，解析能力可插拔
    - 循环模型主体修正为 Human Actor，特定权责场景升级为 Authority Holder
    - Pattern 分类标注为 Illustrative Working Model，避免提前固化
    - Cognitive Projection 从绝对视觉规定调整为语义不变量约束
    - Observable Event 明确防篡改、签名与持久化由下游数据基础设施负责
    - 降低法律化措辞与宣言式修辞，强化工程可执行性与架构严密性
---

# 第五层：HB 人机行为适配基础设施 v1.0
## HB — Human Behavior Adaptation Infrastructure v1.0 (Freeze Candidate v1.0)

> **【体系与规范定位声明】**  
> **Efficient Human-AI Interaction（高效 AI 人机交互体系）**定义 AI 与 Human 高效共同工作所需要的核心原则、交互规则、机器语义和产品实现边界。**Efficient Human-AI Interaction Specification（高效 AI 人机交互规范）**是其正式规范表达。**DeepBase** 是用于工程化实现和承载高效 AI 人机交互规范的 Delphi 软件框架。**HB** 是 DeepBase 中面向 Human 的统一人机交互承载与呈现基础设施，负责把高效 AI 人机交互体系中的语义、逻辑、状态、功能与交互行为，转化为 Human 可感知、可理解、可判断、可操作的交互。行为适配是 HB 的重要能力之一，但不是 HB 的全部。

> **“Freeze Candidate” 状态说明**：  
> 本文件为高效 AI 人机交互规范**第五层架构规范母稿候选**。在工程实现上，HB 是 DeepBase 中面向 Human 的统一人机交互承载与呈现基础设施。它负责把高效 AI 人机交互体系中的语义、逻辑、状态、功能与交互行为，转化为 Human 可感知、可理解、可判断、可操作的交互。行为适配是 HB 的重要能力之一，但不是 HB 的全部。  
> 本文件承接已经正式封版或通过审核的前四层规范（L1 哲学、L2 交付、L3 介入、L4 交互协议），确立通用人机交互基础设施的根本定位、五大适配域、核心原则与工程边界。  
> 本文件处于 Freeze Candidate 状态，待主控与老板完成最终独立审定后，方可升级为 Frozen 状态。资料员不得自行宣布本规范冻结。

---

## 〇、文档身份与法源层级

### 0.1 文档身份与正式名称
本基础设施的正式全称正式冻结为：
* **英文正式全称**：`HB — Human Behavior Adaptation Infrastructure`
* **中文正式全称**：`HB 人机行为适配基础设施`
* **工程简称**：`HB`

淘汰原有的正式全称 `Human Behavior Infrastructure`（原称在历史说明中仅作为旧称注记）。保留代码中既有的 `HB`、`DeepBase.HB.*` 命名空间与 `THb*` 前缀，以保持源码平滑演进与接口连续性。

### 0.2 法源裁定优先级
在整个高效 AI 人机交互规范工程演进与文档体系中，必须严格遵守以下法源裁定优先级：

```text
当前第五层最新讨论与老板裁定
    >
前四层 Frozen / Freeze Candidate 规范 (L1~L4)
    >
ASTO 当前有效理论体系
    >
现有 HB 历史文档体系
    >
现有 HB 代码与历史实现
```

当历史文档或现有代码实现与本母稿结论冲突时，一律以本母稿确立的理论与架构为最高依据，旧文档与历史代码后续按序校准重构，严禁为了迁就历史包袱而削弱本层理论。

---

## 一、为什么需要 HB

### 1.1 机器与人类认知现实的结构性错配
传统软件工程长期假定“人是理想的操作者与信息处理器”：
* 假定人能够无损理解机器吐出的密集数据结构与异常代码；
* 假定人拥有无限的注意力，随时准备响应系统的弹窗与轮询；
* 假定人的意图能够直接编码为机器所期望的严格参数与操作序列；
* 假定人的每一次点击都是理性的、确定不变的终局裁决；
* 假定界面的按钮点击自然等同于现实权责的转移。

当以大语言模型（LLM）为代表的现代 AI 系统进入工程实践后，这种错配被急剧放大：
* AI 生成的大量非结构化文本充斥着幻觉、概率推论与模糊边界，机器却倾向于将其包装为“权威输出”；
* AI 高频、并发的认知与推理活动，不断争夺人类稀缺的注意力；
* 系统为了“闭环”与“自动化”，频繁诱导人类进行无实效的“一键确认”，导致权责边界难以有效保障。

### 1.2 HB 的工程定位与使命
HB 的诞生不是为了做一个更花哨的控件库，也不是为了给业务系统增加一套埋点度量框架。HB 的工程定位与使命是：
> **系统性解决机器复杂度向人类粗暴转嫁的工程问题，构建一套通用基础设施，将机器的能力、状态、推论与诉求，适配为人类真实的生理、认知、心智与权责所能承载的交互形式；同时将人类情境化、模糊、可变但具有主体性的意图，解析为机器可消费的结构。**

---

## 二、HB 是什么

### 2.1 HB 的根定义
母稿确立 HB 的根定义如下：

> **HB 是使机器行为适配 Human 的认知、注意、表达与操作、判断与修订、权责与效力现实的通用基础设施。**  
> **HB adapts machine behavior to humans; it does not adapt humans to machines.**

中文核心准则：
> **HB 让机器行为适配 Human，而不是让 Human 迁就机器，更不是操纵、塑造或诱导 Human Behavior。**

架构大白话：
> **机器迁就人，不让人迁就机器。**

### 2.2 核心职责范畴
HB 是受 Human Authority、Meaning Preservation、Minimum Sufficient Adaptation 与 No Manipulation 等原则约束的通用行为适配基础设施，承担以下三大核心职责：
1. **认知与呈现翻译（Machine-to-Human）**：将机器底层的高维状态、计算图、置信度、候选空间与异常，降维投影为人类可理解、可比较、可追溯的最小充分认知结构。
2. **意图与操作解析（Human-to-Machine）**：规范输入适配契约与语义路由，将人类低成本、跨媒介、情境化的自然表达与操作，解析映射为符合系统契约与效力边界的语义动作（Semantic Action）。具体的自然语言解析能力由规则解析器、领域解析器或上层 AI 模块承载，HB Core 不垄断自然语言理解引擎。
3. **权责与效力防线（Authority & Effect Defense）**：严格拦截任何隐式效力升格，确保未获有效人类授权的操作绝不跨越现实承诺边界（Commitment Boundary）。

---

## 三、HB 不是什么（边界划定）

为防止概念泛化与职责污染，HB 明确界定以下边界：

1. **HB 不是漂亮控件库（HB ≠ Pretty Control Suite）**：VCL / FMX / Web 组件只是 HB 在视觉与交互表层的呈现资产，控件库不等于 HB 本身。
2. **HB 不是视觉设计系统（HB ≠ Visual Design System）**：设计系统规范色彩、排版与间距，HB 规范机器行为如何适配人的认知与权责。
3. **HB 不是行为操纵体系（HB ≠ Behavior Manipulation System）**：HB 严禁成为增长黑客、用户转化诱导、留存绑架或 Dark Pattern 的工具。
4. **HB 不是 AI 运行环境（HB ≠ AI Runtime）**：HB 不管理 LLM 调用、Prompt 组装、上下文窗口与 Token 成本。
5. **HB 不是业务运行环境（HB ≠ Business Runtime）**：HB 不承担业务事务、数据库持久化、业务流程流转与领域计算。
6. **HB 不是通用工作流引擎（HB ≠ Universal Workflow Engine）**：HB 关注人机交互的适配质量，不代替业务引擎驱动端到端业务流。
7. **HB 不是通用人类判断本体（HB ≠ Universal Judgment Ontology）**：人类的价值判断权属于人类本身，HB 绝不提供一套先验裁决人类价值高低的本体论。

---

## 四、与 L1～L8 的层级关系

高效 AI 人机交互规范的分层结构具有清晰的单向依赖拓扑：

```text
L1 AI 人机认知哲学 (EHAI.01.L1-人机认知哲学.md · Frozen v1.0)
    ↓
L2 AI 交付原则 (EHAI.02.L2-AI交付原则.md · Frozen v1.0)
    ↓
L3 Human Intervention 介入原则 (EHAI.03.L3-人类介入原则.md · Freeze Candidate v1.0)
    ↓
L4 通用 AI 交互协议 (EHAI.04.L4-通用交互协议.md · Freeze Candidate v1.0)
    ↓
L5 HB 基础设施 (本文档 · Freeze Candidate v1.0 · 人机行为适配)
    ↓
L6 机器语义与介入基础设施 (EHAI.06.L6-机器语义与介入.md · Frozen v1.0 · DeepBase 工程实现：DB-MSI)
    ↓
L7 产品实现边界 (EHAI.07.L7-产品实现边界.md · Freeze Candidate v1.0)
    ↓
[DeepBase Delphi 软件框架承载] ──► 具体产品消费层 (AsWish / 唤金 / ERP ...)
```

### 4.1 第五层对第四层的继承与非重叠
* **L4 的职责**：定义合法交互的形式语义与人类六大判断语义（`J-F Fact`, `J-P Preference`, `J-T Tradeoff`, `J-G Goal/Frame`, `J-A Authorization`, `J-R Responsibility`），以及 0–9 交互语义空间。
* **L5 HB 的职责**：**消费** L4 已经冻结的语义，绝不重新定义、合并或篡改 L4 的判断类型；HB 负责将 L4 的抽象判断语义以及普通软件的交互需求，落地适配为人类可承受的物理与认知交互。

### 4.2 第五层与第六层（L6）的严格解耦
L5 与 L6 互为独立层级。HB 不拥有、不封装、不干预：
* LLM Invocation（大模型调用与多模型路由）；
* Prompt Construction（提示词工程与上下文模板拼接）；
* AI Reasoning & Planning（内部规划器、推理决策、ReAct 循环）；
* Context Window & Token Budgeting（上下文窗口裁剪与 Token 预算）；
* AI Long-term Memory & Persona Store（长期记忆检索、向量数据库、画像推断）；
* Business Database Transaction & Business State Machine（业务事务与状态机）。

---

## 五、Human Reality（人类现实：工程适配前提）

机器行为必须迁就人类，根源在于人类具有客观的生理、心智与权责现实（Human Reality）。HB 将这些现实作为工程系统不可动摇的适配前提与物理约束，而非宣告普遍哲学或法律定律：

### 5.1 认知现实（Cognitive Reality）
* **认知容量有限**：人类工作记忆容量有限，无法在单次交互中无损承载高维、密集的复杂参数；
* **差异识别存在成本**：人类对海量相似信息中的细微 Difference 识别存在显著的认知劳动成本；
* **理解依赖情境与上下文**：人类的理解高度依赖叙事背景、因果联系与上下文（Context）。

### 5.2 注意现实（Attention Reality）
* **注意力资源稀缺**：人类的注意力资源有限且打断恢复成本高；
* **打断产生心智损耗**：无节制的即时打扰会破坏连续深度思考与决策质量；
* **过载引发防御性忽略**：面对高频或泛滥的提示与警告，人类会自动产生疲劳忽略与跳过倾向。

### 5.3 表达与操作现实（Expression & Operation Reality）
* **意图先于格式**：人类意图形成时往往是口语化、情境化且非严格格式化的，不天然符合关系表或机器底层 Schema；
* **媒介随境迁移**：在不同工作情境下，人类倾向于使用键盘、鼠标、触摸、语音、CLI 等不同物理媒介表达相同意图；
* **表达具有试探性**：在最终下定决断前，人类需要试探、对比、改口与草稿空间。

### 5.4 判断现实（Judgment Reality）
* **情境性与可修订性**：人类判断通常在特定情境与条件下做出，并拥有推翻前议、重新审视与修改决定的主权；
* **价值取舍不可简单算法化**：偏好权衡、伦理取舍与边界妥协属于人类主体性范畴，无法由算法代劳；
* **反思与改判是合法权利**：系统必须支持人类对过往决断的检视、反思与再议。

### 5.5 权责现实（Authority & Responsibility Reality）
* **权责与执行语义分离**：权限、Judgment、Authorization、Responsibility 与 Execution 必须保持明确的语义分离；
* **高影响效力遵守适用制度**：高影响 Reality Effect 必须遵守其适用的权责与治理制度，机器执行绝不自动转移或豁免人类背书；
* **知情是有效授权的前提**：未被真实理解并显化的确认，不具备合法授权效力；
* **权力与后果必须对等**：越是不可逆、后果严重的动作，越需要显式、严密的意图表达与权责确认。

---

## 六、核心五个 Adaptation Domains（五大适配域）

> **架构最高声明**：  
> 五大适配域是**机器行为适配人类时必须系统性审查的五个基本验证维度**。  
> **五大适配域绝对不是五个 UI 区域、不是五个代码 Class、不是五个页面、也不是五个独立的控件模块！**  
> 任何一次具体的人机交互，都可以并且通常会横切多个适配域进行综合适配。

```text
                       HB 行为适配审查矩阵
┌─────────────────────────────────────────────────────────────┐
│ 1. Cognitive Adaptation      (机器内部表示 → 最小充分认知结构)     │
│ 2. Attention Adaptation      (机器时机事件 → 稀缺注意体验)       │
│ 3. Expression & Operation    (人类自然表达 → 结构化语义动作)     │
│ 4. Judgment & Revision       (人类主体决断 → 上下文裁决保持)     │
│ 5. Authority & Effect        (人类意图授权 → 现实效力边界防御)   │
└─────────────────────────────────────────────────────────────┘
```

---

### 6.1 Domain 1 — Cognitive Adaptation（认知适配）
**定义**：将机器内部表示转换成 Human 可识别、可理解、可比较、可追溯的最小充分认知结构，同时不改变源语义、不替 Human 作领域判断、不隐藏 Material Meaning。

1. **复杂度吸收（Complexity Absorption）**  
   机器内部的指针、句柄、嵌套 JSON、调用栈、底层状态码等机器复杂度，必须由机器本身充分消化吸收，严禁原样转嫁给人类认知。
2. **认知保真度（Cognitive Fidelity）**  
   呈现形式可以为人类理解进行视觉重构或语法简化，但绝对不得篡改以下核心要素：
   * `Object Identity`（对象的本体同一性）；
   * `Fact State`（客观事实状态）；
   * `Material Meaning`（对决策具有实质性影响的含义）；
   * `Unknown`（机器自身的“未知”状态必须如实呈现，严禁伪装确定性）；
   * `Semantic Role`（主客体语义角色）。
3. **最小充分认知（Minimum Sufficient Cognition）**  
   坚持“最小充分”原则：既不是信息倾倒（Dump），也不是过度删减（Omission）。提供足以支撑当前判断的必要事实，次要背景实施渐进显露（Progressive Disclosure）。
4. **可追溯压缩（Traceable Compression）**  
   摘要与概括必须是可溯源的。人类有权随时从紧凑视图展开追溯至原始证据、计算依据、差异对比或底层来源（Difference, Reason, Evidence, Source）。
5. **差异显影卸载（Difference Offloading）**  
   在有基准比对的场景下，机器必须主动承担计算和标定差异的机械劳动，直接将“实质性差异（Material Difference）”显影给人类，人类只负责判断差异的业务意义，严禁让双眼逐行肉眼找茬。
6. **认知连续性（Cognitive Continuity）**  
   在跨步骤、多轮次的交互流中，保持对象命名、术语体系、视觉映射与上下文锚点的基本连续，避免让用户在上下步切换中产生认知断层。

---

### 6.2 Domain 2 — Attention Adaptation（注意适配）
**定义**：将机器的提示、请求、变化和异常，按照上游确定的时机、重要性和效力要求，适配成人可以承受、不会被无必要打断、并能够在需要时重新进入的 Attention Experience。

1. **注意力稀缺公理（Attention Is Scarce）**  
   机器发生事件（Machine Event），绝不天然拥有打扰人类的权利。
2. **通知时机不等于响应义务（Timing ≠ Response Obligation）**  
   机器在何时呈现信息（时机），与人类是否必须立刻处理（响应义务），是正交的两个概念。系统不得将自身的信息输出强行绑定为人类的即时阻塞任务。
3. **继承第三层 A0～A3 时机律令（L3 Attention Realization）**  
   HB 继承第三层冻结的时机分级。**何时属于 A0～A3 由上游（L3/业务契约）裁定，HB 负责 Attention Realization 呈现适配**：
   * `A0 (Silent)`：静默处理，保持状态可查询，不触发即时打扰；
   * `A1 (Digest / Batch)`：适合汇聚为摘要或批处理队列，默认在人类自然空闲或工作间歇时提供；
   * `A2 (Timely / Natural Window)`：适合在人类工作流的自然停顿间隙显露；
   * `A3 (Immediate)`：**A3 是 Timing 语义（即时到达），不是 Risk Type（风险类别）**。具体模态（Modal、Inline、Voice、Queue 等）由上游契约、Profile 与工程验证决定，同时注意保护当前上下文。
4. **语义持久性（Semantic Persistence）**  
   凡是具有实质性业务或权责意义的内容，绝对不得因为前端 UI 临时倒计时（如 Toast 自动关闭）而无声湮灭。Material Signal 必须保持可恢复、可重新显影，不得因呈现超时而无声丢失。
5. **可恢复的注意力（Recoverable Attention）**  
   HB 必须支持可恢复的 Attention Projection 与 Re-entry Contract，使得人类在被打断、挂起或离开后能够无缝重新进入（Re-enter）；具体 Context 的持久化、恢复与存储归相应基础设施负责。
6. **注意仲裁机制（Attention Arbitration）**  
   **HB 必须支持多个机器请求在进入 Human Attention 前的统一语义仲裁能力，避免各模块无约束争夺 Human Attention。** 具体是否采用单一 Router、Queue、Scheduler、Notification Center 或 Runtime Service，均不在第五层冻结，留待工程 Profile 与实现验证。
7. **严禁注意操纵（No Attention Manipulation）**  
   严禁利用生理本能制造虚假紧迫感，严禁滥用警示动效、刺耳音效、强制倒计时或无法关闭的阻断蒙层来强行收割注意力。

---

### 6.3 Domain 3 — Expression & Operation Adaptation（表达与操作适配）
**定义**：将 Human 自然、上下文化、可修正、跨媒介的表达和操作，适配为机器可消费的语义输入，同时避免要求 Human 预先理解机器 Schema、内部状态或实现媒介。

1. **人类意图先于机器格式（Human Meaning Before Machine Format）**  
   人类负责表达真实业务含义，机器负责结构化。严禁强迫人类用户直接手填机器内部 Schema、底层外键或格式代码。
2. **输入与语义动作三层解耦（Input ≠ Meaning）**  
   HB 在架构上严格解耦以下三个层次：
   ```text
   [Physical Input]        键盘按键、鼠标点击、触屏手势、语音声波输入
          ↓ (映射与初步接收)
   [Raw Human Expression] “选第二个”、“用昨天的方案”、“不要改价格”、“3”
          ↓ (结合上下文与契约解析)
   [Resolved: Semantic Action] 或 [Unresolved: Semantic Resolution Required]
   ```
   HB 负责 Input Adaptation Contract、Semantic Routing 以及 Meaning / Effect Boundary 的守护；但具体的自然语言解析与推断可以由 Rule Resolver、Product Resolver、L6 AI 或其它可插拔语义解析能力承担。HB Core 不封装或替代 NLP / LLM 推理引擎。
3. **最小成本表达（Least-Cost Expression）**  
   不盲目追求“点击越少越好”，也不教条式地要求“必须全面采用自然语言对话”。在语义充分和效力清晰的前提下，采用人类心智与操作成本总和最低的形式。
4. **上下文承载稀疏输入（Context Carries Meaning）**  
   人类能够进行极简表达（如说“好的”、“撤销”、“第二个”），是因为机器上下文（Context）完整保留了当前的指称对象。机器利用上下文补全语义，而不是靠盲猜。
5. **语义跨媒介等价（Semantic Modality Equivalence）**  
   无论人类通过键盘快捷键、鼠标点击、触屏手势、CLI 命令还是语音指令发起输入，只要意图相同，在 HB 解析后必须映射为等价的 Semantic Action 与 Effect Boundary。
6. **框架逃逸权（Frame Escape · 9 号语义）**  
   当机器给出一组候选集让用户选择时，人类必须拥有合法的表达路径表明“我不认可这组选项”、“跳出当前框架”或“另有补充”。L4 中定义的 `9 = 退出当前候选空间` 在此得到操作支持。
7. **渐进精度输入（Progressive Precision）**  
   人类在决策初期仅提供粗粒度意向，机器根据需要逐步引导细化精度。严禁在一开始要求人类输入超出当前决策阶段的过高精度参数。
8. **修正友好（Correction Friendly）**  
   在未跨越现实承诺边界前，人类的表达具有草稿属性。重置、撤回、改口、局部微调必须保持极低成本，严禁“一处改动、全盘重来”。

---

### 6.4 Domain 4 — Judgment & Revision Adaptation（判断与修订适配）
**定义**：将 Human 情境化、分类型、可暂缓、可挑战、可修订且具有时间连续性的 Judgment Behavior，适配为机器可消费的结构化交互，同时保持 Judgment Type、Context、Completion、Effect 与历史真实性。

1. **判断类型不可降维（Judgment Type Preservation）**  
   系统严禁为了交互或界面绘制便利，将 L4 规定的六大异质判断类型降维混淆：
   * 确认客观事实（`J-F Fact`）绝不能被包装成价值偏好；
   * 权衡取舍（`J-T Tradeoff`）绝不能隐去代价值直接骗取同意；
   * 行动授权（`J-A Authorization`）绝不能伪装为普通确认。
2. **判断的情境性有效（Contextual Validity）**  
   人类在特定上下文作出的判断，其合法效力严格受限于当前的 Context、Condition 与 Scope。严禁机器自动将一次情境判断泛化为全局规则。
3. **交互响应不等于判断完成（Response ≠ Completion）**  
   人类在界面上有动作（如焦点移动、勾选复选框、输入文字），仅代表“产生了响应（Response）”。只有当 L4 规定的裁决完成条件（Judgment Completion Conditions）被完全满足时，方可判定裁决终结。
4. **拒绝强迫确定性（No Forced Certainty）**  
   在真实世界中，“悬而未决（Unresolved）”、“暂缓考虑（Defer）”、“需要更多信息（Need More Info）”、“对前提存疑（Challenge Frame）”都是完全合法的决策状态。HB 严禁通过交互死锁强迫人类必须做出非黑即白的抉择。
5. **反思与重开机制（Revision / Reopen）**  
   即使裁决已经做出，只要重大客观条件发生漂移（Material Context Change），或者人类主动发起异议，HB 必须提供规范的重新审议（Reopen）入口。
6. **严禁静默偷换框架（No Silent Reframing）**  
   在人类进行判断的思考期间，如果机器底层的前提约束、候选集合、边界条件发生改变，系统必须显式警示并重置判断流，严禁静默采用旧判断套用新环境。
7. **历史时间真实性（Temporal Integrity）**  
   历史判断记录必须忠实反映当时的条件与裁决事实。历史可以被回放（Replay）、比对（Compare）、反思（Reflect）或被新决断废止（Supersede），但绝对严禁篡改历史审计记录。
8. **严禁强制定局（No Forced Finality）**  
   单次业务动作的判断完成，不得被系统自动沉淀为永久偏好（Permanent Preference）或长效授权（Standing Authorization）。

---

### 6.5 Domain 5 — Authority & Effect Adaptation（权责与效力适配）
**定义**：将 Human 的 Judgment、Authorization、Responsibility 与其它操作，适配为具有明确 Actor、Scope、Condition 与 Effect Boundary 的机器可消费语义，并防止低效力行为被无依据升级成高效力现实后果。

1. **动作不等于效力（Action ≠ Effect）**  
   人类在界面上的物理动作，必须经由当前上下文检验、效力边界审查及状态转移规则验证，方能转化为真实的系统效力。**HB 必须消费或要求可靠的 Actor / Authority Validity，并禁止在 Authority 不成立时产生越界 Effect；权限系统本体由产品或独立权限基础设施承担。**
2. **效力扩大必须显式（Explicit Effect Expansion）**  
   继承第四层核心准则：**缩小效力可以默认，扩大效力必须显式**。任何可能扩大授权范围、增加现实债务、提高执行额度的变更，必须让人类清晰可见并显式确认。
3. **范围与条件不可丢弃（Scope & Condition Integrity）**  
   在底层契约转交中，严禁把包含精细前置条件的授权退化为一个简单的布尔值 `approved = true`，从而丢失其背后的 Scope、Ceiling、Condition 与 Reopen 约束。
4. **效力清晰可辨（Effect Legibility）**  
   在即将跨越不可逆承诺边界（Commitment Boundary）前，交互界面必须以足够清晰度向人类标明：
   * 动作的作用对象是谁？
   * 将产生哪些主要现实效力？
   * 效力的影响范围有多大？
5. **授权、责任与执行语义分离（Authorization ≠ Responsibility ≠ Execution）**  
   * 获得授权（Authorized）不等于机器自动免除执行审查；
   * 给予授权的人（Authorizer）不必然是操作的具体执行者；
   * 机器作为执行载体，绝不替代人类主体承担责任，责任确认依适用的权责与治理制度界定。
6. **可逆性敏感适配（Reversibility-Sensitive Adaptation）**  
   机器行为适配的严格程度必须与后果的可逆性强相关：
   * 完全可逆、低效力的试探性操作：保持低摩擦，不应使用弹窗阻塞；
   * 不可逆、高现实风险的操作：前置审查与显式确权必须达到相应严密等级。
7. **持续性授权透明化（Standing Power Transparency）**  
   若存在预先批准的长效授权（Standing Authorization），该授权的有效范围、截止条件、限额以及当前执行状态必须对人类公开可查，人类可随时收回或暂停。
8. **异常阻断自动延续（No Silent Continuation Across Exception）**  
   当执行过程中遭遇前提条件失效或发生未预料异常时，系统严禁凭借“此前用户已经同意过”而盲目继续强行推进，必须立即熔断并回退至安全保护状态。

---

## 七、HB 八大核心原则（Master Principles）

HB 体系的所有架构设计、协议制定与控件实现，必须收敛于以下八大母原则（HB-P1 ～ HB-P8）：

| 编号 | 原则名称 | 英文核心定义 | 架构要求与底线 |
| :--- | :--- | :--- | :--- |
| **HB-P1** | **机器适配人类** | **Machine Adapts to Human** | 机器行为迁就人类生理、认知与权责现实，严禁强迫人类迁就机器数据结构与内部状态。 |
| **HB-P2** | **人类现实第一** | **Human Reality First** | 人类认知有限、注意稀缺、判断情境化与权责主体性是工程现实约束，机器交互必须以此为前提。 |
| **HB-P3** | **语义意义保真** | **Meaning Preservation** | 在信息降维、跨平台呈现、媒介翻译与格式解析的全链路中，绝对不得篡改交互的实质性含义。 |
| **HB-P4** | **最小充分适配** | **Minimum Sufficient Adaptation** | 既不转嫁机器原始复杂度，也不提供不可追溯的黑箱结论；以最小必要心智成本交付足以做出正确决断的结构。 |
| **HB-P5** | **低阻试探，显式效力** | **Low-Friction Exploration, Explicit Effect** | 探索与草稿阶段保持低摩擦与可逆性；跨越现实效力与承诺边界时必须具备无歧义的显式语义表达。 |
| **HB-P6** | **情境化与可修裁决** | **Contextual & Revisable Judgment** | 人类判断默认在特定情境成立，不可自动全局泛化；系统必须保留反思、变更、撤回与重新审议机制。 |
| **HB-P7** | **严禁隐式效力升格** | **No Implicit Semantic / Effect Escalation** | 严禁将低级交互动作（浏览、聚焦、选择、未响应）升格为高级权责裁决（判断、授权、免责、同意）。 |
| **HB-P8** | **核心独立于平台与 AI** | **Core Independent of AI & Platform** | HB 核心架构是一套通用的行为适配理论，不依附于 LLM、AI 记忆，也不绑定于特定操作系统或 GUI 框架。 |

### 7.1 核心语义等价与升格阻断链（HB-P7 核心准则）
在 HB 治理范围内，必须由交互契约严格锁死以下等价阻断关系：

```text
Inspect ≠ Select
Select ≠ Judgment
Judgment ≠ Authorization
Authorization ≠ Responsibility
Authorization ≠ Execution
No Response ≠ Consent
Back / Escape ≠ Reject
```

---

## 八、Human Behavior Adaptation Loop（人机行为适配核心循环）

HB 将人机交互抽象为双向循环适配模型。该模型展示了机器意图如何向人类投影，以及人类意图如何向机器翻译：

```text
       [ Machine Side ]                              [ Human Side ]
┌────────────────────────────┐                ┌────────────────────────────┐
│ Machine Capability / State │                │        Human Actor         │
└─────────────┬──────────────┘                └─────────────▲──────────────┘
              │                                             │
      (1) Cognitive Adaptation                      (3) Expression &
              │ (Complexity Absorption)                 Operation Adaptation
              ▼                                             │ (Least-Cost Input)
      (2) Attention Adaptation                              │
              │ (Timing & Arbitration)                      │
              ▼                                             │
      [ Cognitive Projection ] ───────────────► [ Human Cognitive Field ]
              (Sensory Surface)               (Comprehension & Reflection)
                                                            │
                                                    (4) Judgment &
                                                        Revision Adaptation
                                                            │ (Preserve J-Type)
                                                            ▼
                                                    (5) Authority &
                                                        Effect Adaptation
                                                            │ (Ceiling Defense)
                                                            ▼
                                              [ Machine-Consumable Action ]
                                                            │
┌────────────────────────────┐                              │
│ Machine / Reality Changes  │◄─────────────────────────────┘
└────────────────────────────┘
```

> **重要说明**：  
> 1. 上述闭环展示的是**全要素认知与权责适配拓扑**，绝不意味着任何一次简单的微交互都必须机械化地经历全部五个步骤。简单只读查看仅经过 (1) 与 (2)；低风险界面的连续操作可直接流转于 (3)；仅当面临实质性裁决与效力跃迁时，全流程防御方全面介入。  
> 2. **主体定义说明**：闭环中的主体为 `Human Actor`。HB Core 服务所有人类交互，并非所有交互都涉及权责。只有在涉及 Judgment / Authorization / Responsibility 等权责场景下，Human Actor 才进一步承担 `Authority Holder` 角色。

---

## 九、Semantic Routing 与 Interaction Contract（语义路由与交互契约原则）

### 9.1 Semantic Router 的正确定位
在系统架构中，**Semantic Router（语义路由器）是 HB 实现人机行为适配的核心调度机制之一，但它绝不等于 HB 本体的全部**。  
HB 是包含适配哲学、投影规范、模式剖面、观察体系与平台适配器的完整体系，Semantic Router 承担其中交互意图的契约仲裁与分发职责。

HB 的宏观架构全景如下：

```text
HB Human Behavior Adaptation Infrastructure
├── 1. Adaptation Principles (八大母原则与五域审查标准)
├── 2. Semantic Routing & Interaction Contract (意图仲裁与交互契约)
├── 3. Cognitive Projection System (认知投影与感官呈现不变量)
├── 4. Interaction Patterns & Effect Profiles (通用交互模式与效力剖面)
├── 5. Observable Interaction Subsystem (语义事实事件流)
├── 6. Presentation & Visual System (令牌、主题、排版、动效、组件资产)
└── 7. Platform & Modality Adapters (VCL, FMX, Web, CLI, Voice 适配器)
```

### 9.2 Interaction Contract 核心原则（不提前冻结具体 Schema）
一次合法的 Interaction Contract，必须具备回答以下核心问题的能力，但在母稿阶段**严禁提前冻结最终字段数量、JSON Schema 定义、Pascal 类结构或 Enum 列表**：

* **Current State**：当前交互所处的明确事实状态与上下文锚点；
* **Actor**：当前交互的主体是谁（哪个系统服务发起，要求哪个人类角色响应）；
* **Allowed Transitions**：在此状态下，人类拥有哪些合法的操作路径（包括正向、反向、挂起、跳过与逃逸）；
* **Boundary / Effect Boundary**：当前交互如果达成，其最大的现实承诺影响边界是什么；
* **Exception / Reopen Condition**：在何种前提破坏或外部事件下，本次交互必须中止或重新开启；
* **Semantic Object**：交互所操作的核心领域客体同一性；
* **Observable Result**：交互终结时产出的确定性事实。

---

## 十、Cognitive Projection（认知投影与呈现不变量）

### 10.1 呈现媒介非中性公理
任何用户界面（UI）、语音（Voice）或命令行（CLI）都绝不是单纯的中性数据管道。呈现媒介的排版、字号、色彩、排序、留白与动效，必然会对人类认知产生引导或扰动。

### 10.2 八大认知呈现不变量（Semantic Invariants）
HB 要求任何具体的展示层实现，必须严格受控于以下八大呈现维度，其目的在于守护语义保真，而非规定具体视觉风格：

1. **Role Clarity（角色可辨）**：AI 建议、系统客观事实、人类历史记录、第三方外部数据的身份必须具有明确的区分度。
2. **Visibility & Manifestation（显著可见）**：信息“写在屏幕某个角落”不等于“在认知上显化（Cognitively Manifest）”。对决策关键的信息必须具备足够的感知显著度。
3. **Ordering（排序防偏与中性呈现）**：候选方案的物理排列不得无依据地赋予其权威感。AI 的推荐方案可以放置于某一位（如 1 号位），但**位置本身不得被解释为正确答案，亦不得产生自动同意**。
4. **Grouping & Boundary（分组与边界）**：语义相关的对象应当在认知结构上合理聚类，**不同语义角色与 Effect Boundary 必须可辨认**。
5. **Emphasis Control（强调控制）**：**Presentation Emphasis 不得违背上游 Semantic Priority，也不得创建上游不存在的 Importance Ranking。** 视觉权重的分布应当忠实反映语义优先级，严禁通过弱化关键操作入口来诱导倾向性决策。
6. **Progressive Disclosure（渐进显露）**：主视图只呈现最小充分认知事实，背景数据、推导过程与技术细节以次级入口（折叠面板、抽屉、详情页）提供，保证人类随时可溯源展开。
7. **Effect Visibility（效力可视化）**：**Material Effect 必须在动作发生前达到足够的可辨认度**，使人类清晰预知动作是只读试探、可撤销改动还是现实承诺。
8. **Temporal Identity（时态同一性）**：**Current 与 Historical Context 必须保持明确 Temporal Identity，避免误认为历史操作正在作用于现实。**

> **架构声明**：第五层冻结语义要求与认知不变量，不冻结具体视觉实现手段。

### 10.3 焦点、默认与裁决阻断律
Presentation 层必须时刻保持以下界限：

```text
Recommendation ≠ Default
Default ≠ Focus
Focus ≠ Selection
Selection ≠ Judgment
```

---

## 十一、Interaction Pattern 与 Profile 架构方向

> **【重要说明】本节展示的是 Illustrative Working Model（架构示意），仅供工程理解交互模式与效力剖面的关系，不构成已冻结的 Pattern Taxonomy（分类法）。**

第五层不追求在一份规范中穷尽所有交互控件形态，而是确立清晰的分层抽象示意模型：

```text
┌─────────────────────────────────────────────────────────────┐
│ 1. Cognitive Patterns (示意: Compare, Explain, Inspect, Diff)│
├─────────────────────────────────────────────────────────────┤
│ 2. Response Patterns  (示意: Choice, Open Input, Modify)    │
├─────────────────────────────────────────────────────────────┤
│ 3. Effect Profiles    (示意: Judgment, Auth, Reopen Profiles)│
├─────────────────────────────────────────────────────────────┤
│ 4. Surface Composition(示意: Inline, Dialog, Drawer, Card)   │
├─────────────────────────────────────────────────────────────┤
│ 5. Platform Adapters  (示意: VCL, FMX, Web, CLI, Voice)      │
└─────────────────────────────────────────────────────────────┘
```

* **通用交互模式（Interaction Patterns）**：如 `Compare`（差异对比）、`Explain`（因果展开）、`Inspect`（对象探查）、`Choice`（选项呈现）、`Open Input`（自由输入）。这些模式具有广泛的跨领域通用性。注意：`Choice` 更可能属于 Response Pattern 而非纯 Cognitive Pattern。
* **效力与语义剖面（Effect / Semantic Profiles）**：如对应 L4 的 `Judgment Profile`、`Authorization Profile`、`Learning Profile`。它们定义了特定模式在与权责边界挂钩时的严格效力约束。
* **具体 Pattern Library 清单与分类法保持开放验证（To Be Verified）**，不在本母稿中做死板的穷尽冻结。

---

## 十二、Observable Interaction（可观察交互）

### 12.1 语义事实原则
任何一次具有实质业务或认知效力的人机交互，在 HB 内部都应当产生确定的、结构化的**可观察语义事件（Observable Semantic Event）**。例如：
* `HumanInputReceived`：接收到底层输入并初步解析；
* `SemanticActionResolved`：结合上下文成功将输入解析为语义动作；
* `SelectionChanged`：用户在候选空间中改变了关注焦点；
* `FrameEscaped`：用户选择跳出预设的候选集合；
* `JudgmentCompleted`：人类依据明确事实做出了特定类型的合法裁决；
* `AuthorizationResponded`：人类对特定授权诉求做出了明确回应；
* `ExplanationOpened`：人类主动展开溯源证据链。

### 12.2 可观察性与商业度量的严格解耦
HB 必须清晰界定事件与遥测的边界：

```text
Observable Event ≠ Telemetry ≠ Analytics ≠ KPI
```

* **HB 负责在人机交互发生时，按照明确语义契约产生具有明确语义、对象、时间与 Effect Identity 的 Observable Event；其持久化、防篡改、签名和审计完整性由下游证据与数据基础设施负责。**
* 至于这些事件是否上传、如何持久化、如何进行大数据分析，或者如何计算产品转化率，属于下游数据基础设施与业务分析模块的职责，**绝非 HB 核心的职责**。HB 绝不为追求数据指标而扭曲交互。

---

## 十三、Platform & Modality Independence（跨平台与多媒介无关性）

### 13.1 核心逻辑的媒介无关性
HB Core 是一套通用的**行为与认知适配语义规范**。它独立于以下具体平台与媒介技术：
* 独立于 Windows VCL / Windows FMX；
* 独立于 Web (HTML / DOM / CSS / Canvas)；
* 独立于 Mobile (iOS / Android 原生或跨平台框架)；
* 独立于 CLI 终端字符界面；
* 独立于 Voice 智能语音交互管道。

### 13.2 平台适配机制与职责
具体物理平台应通过平台适配机制保持与 HB Core 的语义等价；Platform Adapter 是当前推荐的工程实现模型之一，其具体接口与组织形式不在第五层冻结：
* 适配器负责将 HB 的抽象语义动作（如 `EscapeFrame`）映射为本地平台的原生事件（如按键盘 `Esc` 键、语音说“退出”、点击界面退出图标）；
* 适配器负责将 HB 的认知投影要求落地为本地平台的物理渲染（如调用 Windows DirectWrite 渲染清晰文本、或在 Web 端渲染自适应 CSS Grid）；
* 无论平台如何变换，HB 所守护的五大适配域约束与权责边界始终保持一致。

---

## 十四、HB 与 Visual Design System 的关系

### 14.1 现有视觉资产的架构从属地位
母稿明确指出：**推进第五层理论规范，绝不是否定或推翻现有的 HB 视觉设计资产！**  
包括但不限于以下既有工程交付物：
* Design Tokens（颜色、圆角、阴影、层级令牌）；
* Themes（亮色、暗色、高对比度主题引擎）；
* Typography & Motion（字体排印阶梯与物理缓动曲线）；
* DPI 缩放与多显示器适配规范；
* VCL / FMX 双孪生控件库（ChoiceDeck、CardDeck、HBEdit、HBButton、ProgressDialog）；
* 性能门禁体系（09_工程脚本/bgor/ 下的视觉测试与自动化审计套件）。

### 14.2 统一架构从属拓扑
既有视觉系统是 HB 在图形交互维度上的具象化呈现通道。二者层级拓扑如下：

```text
HB 人机行为适配原则 (Adaptation Principles · 本规范)
        ↓
语义路由与交互契约 (Semantic Routing & Interaction Contract)
        ↓
认知投影机制 (Cognitive Projection System)
        ↓
模式与效力剖面 (Interaction Patterns & Effect Profiles)
        ↓
HB 视觉设计系统 (Visual Design System · Tokens, Themes, Layout, Motion)
        ↓
HB 组件套件 (Component Suites · ChoiceDeck, Dialog, Cards)
        ↓
原生平台控件实现 (VCL / FMX / Web Controls)
```

**结论**：视觉系统完全属于 HB，但视觉系统仅仅是 HB 的一部分（呈现子系统），而不是 HB 的全部。

---

## 十五、HB 与 ASTO 的关系

### 15.1 吸收结构桥接思想
ASTO（以 ASTO-min 为代表）确立了一套强大的结构描述方法：
* `state`（当前状态）
* `transition`（流转动作）
* `actor`（主体）
* `boundary_condition`（边界条件）
* `exception`（异常处理）

这种“统一语法、结构转交、边界清晰、不替上下游做终裁”的思想，是 HB 架构的重要方法论滋养。

### 15.2 严禁机械复制 ASTO 五字段
母稿明确宣布：**严禁将 ASTO 的五字段机械照抄为 HB 的交互数据模型（Schema）！**  
原因在于二者面对的问题域本质不同：
* ASTO 属于宏观认识论与系统演进理论；
* HB 面对的是极其具体的人机行为适配工程现实。  
HB 必须具备处理输入去噪、多媒介等价、注意力仲裁、人类改口、可逆性防线、时间回放等特定领域问题的独立数据结构与能力。

---

## 十六、HB 与 AI Profile / L6 的关系

### 16.1 AI 是高压场景，而非存在前提
HB Core 面向一切人机交互系统（传统 GUI 软件、自动化工具、规则引擎、CLI 等）。  
AI（特别是 LLM Agent）是 HB 体系面对的**复杂度最高、认知压力最大、权责最易失控的应用场景之一**。但：  
> **AI 不是 HB Core 的存在前提。即使在一个完全没有 AI 参与的传统数据录入软件中，HB 的五大适配原则同样完全有效。**

### 16.2 AI 专有能力的接入路径
未来针对大模型、Agent 交互所特有的机制（如 Key Reasoning Summary、Reason Summary、Evidence Path、Difference、Unknown、Source / Supporting Evidence、Prompt 调优反馈、`[让AI学习]` 偏好学习等）：
* 通过标准化的 **HB AI Interaction Profile** 或扩展插件形式平滑接入；
* **HB 不要求、不保存、不呈现私有 Chain of Thought（思维链）；需要让 Human 理解的是可审查的理由、证据、Difference、Unknown 与判断场结构；**
* 绝对不得将 LLM 的专有概念反向污染渗透进 HB Core 的核心基础对象中。

---

## 十七、Touchpoint 与 Telemetry 的重新定位

### 17.1 触点角色的降级与纠偏
在旧有 HB 文档体系中，曾出现将“触点（Touchpoint）”无限泛化、宣称“每一个界面元素都是潜在触点”的严重偏向。本母稿正式对此进行纠偏：

```text
UI Element ≠ Interaction Unit ≠ Judgment Unit
```

* 界面上的一个标签、一个图标、一个空白面板仅仅是渲染树上的一个节点，绝不天然构成一个触点；
* **Touchpoint 的新定位**：它是人机交互适配过程中，**为了观察、验证、度量人机行为适配质量而设立的可选观察投影点**；
* 触点绝不是界面元素存在的合法性前提。

### 17.2 遥测（Telemetry）的合理边界
* **HB Core 不以商业转化最大化、行为塑造或 Attention Manipulation 为设计目标；HB 不应为了这类目标歪曲 Semantic Interaction。**
* **HB Core 为适配质量验证提供的 Observable Semantics，应优先支持识别高频改口、注意过载、误操作回滚等行为适配问题；这些事件进入 Telemetry 后的其它分析用途，由独立 Data / Privacy / Product Governance 规范管理。**

---

## 十八、典型正例（Canonical Positive Scenarios）

以下五个典型场景展示了五大适配域在工程实践中的良好协同：

### 18.1 认知适配正例：智能差异显影与可溯源压缩
* **场景**：系统比对一份包含 5000 行配置的生产环境变更。
* **实践**：HB 不把 5000 行全量 diff 扔给用户，也不仅出一句“配置已优化”。HB 主动计算出 3 处可能导致端口冲突的实质性差异（Material Differences），在主视图以对比卡片显影，并在侧边保留“展开查看 5000 行原始代码与比对证据”的溯源入口。人类在短时间内完成高价值决策，同时拥有完全的追溯权。

### 18.2 注意适配正例：A1 Batch 汇聚与自然停顿提醒
* **场景**：后台运行的数据同步作业发现 12 个非致命警告。
* **实践**：系统不弹出 12 次弹窗，也不打出 12 条系统通知。HB 将其归入 A1 批处理摘要。当用户完成当前的核心编辑动作、进入工作流的自然间歇时，界面右上角以平和的指示徽标提示“有 12 项次要记录待查看”。用户可随时展开批量检视，当前注意力未被破坏。

### 18.3 表达适配正例：稀疏自然指令的精确情境映射
* **场景**：用户在多文件处理界面，通过语音输入“把刚才失败的那几个重试一下”。
* **实践**：HB 依托当前工作区的上下文（Context），将自然语言交由解析器解析，确认“刚才失败的那几个”对应的是任务列表中状态为 `Error` 的 3 个文件对象，转化为结构化操作 `RetryAction(TargetIDs=[4, 7, 9])`，并在界面上高亮这 3 个对象供用户复核，无需用户重新手动寻找和多选。

### 18.4 判断适配正例：保护暂缓与情境性裁决
* **场景**：系统检测到某项客户协议即将到期，提示是否续签。
* **实践**：界面清晰提供“立即续签”、“拒绝续签”，同时同等呈现“暂缓考虑（2天后提醒）”与“补充商务条款后再议”。当用户选择暂缓时，系统平稳归档现场，绝不通过红字警告恐吓用户，也绝不因用户没有选择而自动默认续订。

### 18.5 权责适配正例：跨越现实效力边界的前置显化
* **场景**：财务自动化流程准备向供应商银行账户打款 100 万元。
* **实践**：系统严禁仅用一个写着“确定”的常规按钮完成操作。在终局确认视图中，HB 强制显化三大现实效力要素：【出资账户与收款方全称】、【不可撤销的扣款金额：¥1,000,000】、【操作者责任确认】。操作需要一次具备明确交互摩擦力的显式动作完成。一旦发生异常，系统立刻熔断，不再静默重试。

---

## 十九、典型反例（Canonical Anti-Patterns）

为防范工程实践中的变相走样，正文收录并防范以下典型反例：

### 19.1 认知反例（Cognitive Anti-Patterns）
* **内部错误码直接甩锅**：界面弹窗显示 `Error 0x80004005: E_FAIL`，将机器底层的内部故障代码未经翻译直接倾倒给最终用户。
* **万行表格冒充透明**：将长达 10,000 行的数据未加任何聚类、筛选与关键指标摘要，直接铺在一个巨大表格里，宣称“系统极其透明”。
* **不可溯源的黑箱总结**：AI 用自然语言信誓旦旦给出一句“经过分析，该项目不存在法律风险”，但界面上完全找不到任何事实支撑点、推导链条或引用的条款出处。
* **肉眼找茬式比对**：给出两个长篇文本或两套复杂配置方案，让用户自己在几万字中一行行肉眼寻找差异，机器未做任何差异显影。

### 19.2 注意反例（Attention Anti-Patterns）
* **有事件就弹窗（Alert Fatigue）**：系统底层任何微小变化、保存成功或网络重连，都要通过屏幕中央的模态弹窗强行中断用户当前思考。
* **AI 兴奋式碎碎念**：大语言模型每产生一行中间推论、每调用一个内部工具，都高频发送一次桌面通知或气泡打扰。
* **A1 批处理却滥用阻断模态**：本属于可以合并稍后查看的次要信息，强行使用阻断全屏操作的 Modal Dialog，强迫用户必须立刻点击关闭才能继续工作。
* **Toast 倒计时假定已知**：重要业务提示以悬浮 Toast 形式出现，倒计时 3 秒后自动消失，系统后台直接标记为“用户已完全知悉并同意”。

### 19.3 表达与操作反例（Expression Anti-Patterns）
* **强迫人类手填机器 Schema**：在用户仅想表达“把张三设为管理员”时，弹出一个包含 20 个必填字段的底层权限关系表让用户逐项勾选。
* **万物皆聊天框（Chatbot Fallacy）**：盲目跟风，取消所有成熟高效的图形控件，哪怕只修改一个布尔开关，也强迫用户打字跟 AI 进行自然语言对话。
* **万物皆死板按钮**：完全不提供自由表达与微调空间，强行把复杂的业务诉求压制在几个写死的固定按钮内。
* **把 `9` 解释为拒绝（Escape Treated as Reject）**：用户选择 `9`（退出当前候选空间），系统却粗暴将其记为“用户拒绝了业务方案”，违背框架逃逸的本意。
* **自然语言瞬间绑定不可逆操作**：用户刚在输入框打出“我想把旧数据清空”，机器未做二次效力确认，瞬间执行物理删除。

### 19.4 判断反例（Judgment Anti-Patterns）
* **下拉框选中即裁决终结**：用户仅仅在下拉列表中鼠标悬停或选中某一行（`SelectedIndex >= 0`），系统立刻认为人类完成了业务判断并持久化。
* **“全都要”被无脑处理为 SelectAll**：用户在面对两个互斥冲突的复杂选项时随口说“全都要”，机器未加任何冲突解释，直接把二者强行合并执行导致系统崩溃。
* **历史选择直接当当前偏好**：用户上周由于赶时间选了一次最便宜的物流，系统本周在用户完全不知情的情况下自动将其设为唯一默认物流。
* **人类暂缓被曲解为人类拒绝**：用户表示“先放一放，我下午再看”，系统后台直接将工单状态打上 `Rejected` 并触发关闭通知。

### 19.5 权责与效力反例（Authority & Effect Anti-Patterns）
* **Confirm 等同于合法授权**：将一个普通的弹窗确认“你确定吗？”直接等同于用户授予了跨越权责边界的正式委托。
* **授权等同于责任转移**：认为“只要用户点击了允许，出了任何事故就完全是用户的责任，与系统架构无关”。
* **未响应被默认为同意（Silence as Consent）**：发送一条涉及重大资产变动的通知，声明“若您在 24 小时内未提出异议，将视为您已完全同意”。
* **“以后你看着办”被理解为无限权力**：用户在某个简单任务中随口说了一句“以后类似的事情你直接定”，系统将其解释为可以永久、无限额度代理所有现实业务。
* **点击直通现实不可逆执行**：毫无效力缓冲机制，鼠标单击瞬间触发真实资金划拨或硬件动作。
* **三次确认框冒充系统安全**：连续弹出三次“您真的确定吗？您真的真的确定吗？”，只制造操作疲倦与心理厌烦，未向用户解释任何实质风险与效力边界。

---

## 二十、理论状态分类（Epistemological Status）

母稿严格规范当前体系内各项内容的认识论状态：

### 20.1 已冻结（Frozen Concepts）
以下核心概念与原则已达成完全共识，严禁在后续工程讨论中反复动摇或推翻：
1. **HB 正式名称**：`HB — Human Behavior Adaptation Infrastructure`（HB 人机行为适配基础设施）；
2. **HB 根定义**：机器适配人类，不让人类迁就机器（Machine adapts to human; it does not adapt humans to machines）；
3. **HB 不限于 AI**：HB 是通用基础设施，AI 是高压场景而非存在前提；
4. **五大 Adaptation Domains**：认知、注意、表达与操作、判断与修订、权责与效力（作为行为审查维度，而非五个模块）；
5. **八大母原则**：HB-P1 至 HB-P8；
6. **语义保真与最小充分**：Meaning Preservation & Minimum Sufficient Adaptation；
7. **情境化与可修裁决**：Contextual & Revisable Human Judgment；
8. **效力升格防线**：No Implicit Effect Escalation，以及焦点/选择/判断/授权/责任的严格分离；
9. **HB Core 与平台解耦**：核心逻辑独立于 Delphi/Web/AI/特定硬件；
10. **视觉系统架构从属**：既有视觉与控件资产有效并归入 HB 呈现系统。

### 20.2 强暂定 / 暂定（Strong Tentative / Tentative）
以下内容已具备清晰架构方向，但具体实现细节允许在工程验证中调整：
* Attention Arbitration 具体架构机制；
* Semantic Router 具体内部架构与分发调度算法；
* Interaction Contract 的核心抽象基类字段构成；
* Cognitive Projection 的具体量化编码与设计参数；
* Pattern 与 Profile 的具体继承接口分类法；
* Observable Event 的具体 Schema 与事件类型枚举列表；
* Platform Adapter 的具体 API 签名与通信协议。

### 20.3 待验证（To Be Verified）
以下内容必须经过真实工程代码实现、端到端真实用户模拟与性能测试门禁检验后方可冻结：
* 具体 Pattern Library 的实现数量与组件封装；
* 跨平台 Adapter（特别是 Web 与 CLI 适配器）的性能损耗指标；
* 复杂多轮历史回放（Replay UI）的交互体验与状态恢复开销；
* 批处理（Batch UI）在高并发报警下的吞吐表现；
* 自动化测试框架在 HB Test 门禁中的断言规则。

### 20.4 不采用清单（Rejected Concepts · 18 项禁止事项）
全体系严格禁止将以下 18 项错误概念引入 HB：
1. **HB ≠ 漂亮控件库**
2. **HB ≠ Visual Design System**
3. **HB ≠ Human Behavior Manipulation System（严禁行为操纵）**
4. **HB ≠ AI Runtime**
5. **HB ≠ Business Runtime**
6. **HB ≠ Universal Workflow Engine**
7. **HB ≠ Universal Human Judgment Ontology**
8. **Click ≠ Human Meaning（点击不等于意图）**
9. **Information Visible Somewhere ≠ Cognitively Manifest（显露不等于感知）**
10. **More Confirmation ≠ More Safety（多次弹窗不等于安全）**
11. **More Notification ≠ Better Attention（通知越多不等于体验越好）**
12. **More Natural Language ≠ Better Adaptation（无脑自然语言不等于好适配）**
13. **Fewer Clicks ≠ Lower Human Cognitive Cost（少点击不等于低认知成本）**
14. **AI Recommendation ≠ Correct Answer（AI 推荐不等于正确答案）**
15. **Choice ≠ Judgment（候选勾选不等于业务裁决）**
16. **Authorization ≠ Responsibility ≠ Execution（授权、责任与执行语义分离）**
17. **Historical Judgment ≠ Current Command（历史判断不等于当前指令）**
18. **No Response ≠ Consent（沉默绝不代表同意）**

---

## 二十一、给工程层的下游接口说明

为指导后续 Delphi 代码重构、VCL/FMX 孪生演进以及 Web 适配层开发，确立以下下游对接不变量与边界准则：

### 21.1 命名空间与代码继承准则
1. **保留代码命名空间**：Delphi 既有源码工程中的 `HB.*`、`DeepBase.HB.*` 命名空间与 `THb*` 类前缀全部保留，禁止进行全局重命名或盲目重构类名。
2. **术语注释校准**：在代码核心单元文件头注释中，将原有 `Human Behavior Infrastructure` 统一修订为 `HB — Human Behavior Adaptation Infrastructure`。
3. **消除历史误导性注释**：全面清理代码与单元测试中残留的“转化率”、“营销触点”、“每一个元素都是触点”、“引导用户接受 AI 建议”等陈旧或变质的文档注释。

### 21.2 严禁提前冻结工程 Schema
* 在本规范正式通过老板与主控审核前，**严禁在代码中定义过于死板的全局单例 Schema 记录体**；
* 交互契约与语义路由应面向接口（`interface`）设计，保持足够的扩展弹性；
* 优先保证数据流动满足“认知可溯源、效力不跃迁、操作可撤回”三大底线。

### 21.3 核心总结与最终定位句
HB 体系的核心追求，最终凝练为以下定位：

> **HB — Human Behavior Adaptation Infrastructure，是使机器行为适配 Human 的认知、注意、表达与操作、判断与修订、权责与效力现实的通用基础设施。**  
> **HB 让机器承担机器擅长的复杂度，让 Human 保持人的理解、表达、判断、修订与权责主体性。**  
> **机器迁就人，不让人迁就机器。**

---
