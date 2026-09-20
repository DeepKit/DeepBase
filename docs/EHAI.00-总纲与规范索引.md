---
title: "EHAI.00：总纲与规范索引"
subtitle: "Efficient Human-AI Interaction · System Overview, Source Map & Normative Index"
Status: APPROVED INDEX v1.0
Nature: Non-Normative System Overview / Source Map / Normative Index / Governance Entry (非规范性体系总纲 · 规范索引 · 治理入口)
Authority: Derived from FROZEN L1–L8 specifications (派生自已冻结 L1～L8 规范母稿，非独立规范法源；若出现语义冲突，一律以对应层已冻结规范母稿为准)
System: 高效 AI 人机交互体系 (EHAI · Efficient Human-AI Interaction)
Specification: 高效 AI 人机交互规范 (EHAI Specification)
Scope: L1～L8 全层规范索引与治理入口
Date: 2026-09-13
Human Authority: APPROVED
Revision Note: |
  2026-09-13 EHAI.00 终审封版 (APPROVED INDEX v1.0 · Non-Normative):
    - Human Authority 终审原则裁定：EHAI.00 作为非规范性体系总纲与索引正式封版为 APPROVED INDEX v1.0
    - 明确区分 Index Maintenance ≠ Theory Reopen，本文件不作独立规范法源，亦不采用 FROZEN 理论成熟度状态
    - 修正 §10：明确冻结状态指“在当前 v1.0 版本中具有正式且受保护的理论效力”
    - 收紧 §12：明确 Boundary / Scope Refinement 指“对经验发现或经验主张的适用范围、边界条件作更精确限定”，恪守 Scope Refinement ≠ Automatic Theory Revision
    - 修正 §4：问题路由增加 L8 评估与 Qualified Empirical Challenge 中间资格判断，消除 Finding 直达 Revision Candidate 路径
---

# §0 文档身份与权威边界

## 0.1 法定身份

`EHAI.00` 是高效 AI 人机交互体系（EHAI v1.0）的**体系级总纲、规范索引与治理入口**。

其法定定位为纯粹的派生性入口文件与索引目录，而非新的理论层或规范层。

## 0.2 排他性消极界定（EHAI.00 不是什么）

为杜绝体系越权与层级膨胀，明确声明 EHAI.00：

* **不是 L0**：EHAI 体系不存在第零层，体系的认知与哲学起点始于 L1；
* **不是第九层（L9）**：EHAI v1.0 当前主体系由 L1～L8 构成；当前没有发现需要建立 L9 的独立不可约问题，因此当前不存在 L9。不得主动设计 L9；
* **不是新的理论层**：不提出任何新的公理、原语、Root 或理论公式；
* **不是独立规范法源**：其本身不产生独立的约束力与规范效力；
* **不是 L1～L8 的替代文本**：阅读本文件绝不能替代阅读各层正式母规范；
* **不是 Implementation Specification**：不包含具体软件的架构实现方案与代码细节；
* **不是 Empirical Methodology**：不包含统计学实验设计、A/B 测试教程与指标测量方案。

## 0.3 权威优先关系与核心解释准则

EHAI.00 与各层已冻结母规范（L1～L8 Canonical Specifications）之间的权威优先关系如下：

> **如果 EHAI.00 与任一 L1～L8 Canonical Specification 出现语义冲突，一律以相应 L1～L8 冻结母规范为准。**

核心解释准则：

```text
EHAI.00 may point to the specification.
EHAI.00 must not replace the specification.
```

（`EHAI.00 可以指向规范，但 EHAI.00 绝不能取代规范。`）

英文仅作为工作辅助表达与学术对照使用，不得擅自以此建立新的正式英文术语。

## 0.4 三大排他职能

EHAI.00 严格限定于以下三大功能，严禁扩展出第四种功能：

1. **导航（Navigation）**：指引读者在遇到具体业务、工程或理论问题时，迅速判断该问题归属于哪一层规范管辖；
2. **登记（Registry）**：权威登记八层正式层名、正式文件名、版本、冻结状态以及已冻结/OPEN 事项；
3. **治理入口（Governance Entry）**：明确冻结规范的效力、修订候选（Revision Candidate）的提出门槛、人类终审重开权限以及实证结果回流治理的通道。

## 0.5 文件反目标（Navigation ≠ Substitution）

EHAI.00 不追求让读者“只读本文件便知悉 EHAI 全貌而无需阅读各层母稿”。

相反，本文件的唯一目标是：**帮助读者以最短路径找到并进入对应的 Canonical Specification**。

```text
Navigation ≠ Substitution
（导航不等于替代）
```

---

# §1 EHAI v1.0 体系入口

## 1.1 体系全景与阶段转换

EHAI（高效 AI 人机交互规范 / Efficient Human-AI Interaction）当前主体系由 L1～L8 构成。

各层具体规范含义以对应 FROZEN v1.0 Canonical Specification 为准。

体系当前状态处于明确的阶段转换节点：

```text
EHAI v1.0 主体系：
理论构建阶段：CLOSED
实证与应用阶段：OPEN
```

体系演进由此进入后续治理循环：

```text
体系整理 → 工程承接 → 实证验证 → 经验回流
```

## 1.2 体系三段论演进脉络

EHAI 八层体系在理论结构上分为三个逻辑阶段：

```text
L1～L6: Normative Architecture
（规范体系如何成立：从认知哲学到机器语义的规范闭环）
        ↓
L7: Theory → Reality
（理论如何进入现实：规范如何映射、绑定并符合于具体实现系统）
        ↓
L8: Reality → Theory
（现实如何反约理论：现实经验效应与归因如何反馈并约束理论本身）
```

---

# §2 八层正式规范登记表

## 2.1 主体系规范登记表（L1～L8）

| Layer | 中文正式名称 | 英文正式名称 / 状态 | Version | Status | Canonical File |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **L1** | 人机认知哲学 | Human-AI Cognition Philosophy | v1.0 | **FROZEN v1.0** | `EHAI.01.L1-人机认知哲学.md` |
| **L2** | AI 交付原则 | AI Delivery Principles | v1.0 | **FROZEN v1.0** | `EHAI.02.L2-AI交付原则.md` |
| **L3** | 人类介入原则 | Human Intervention Principles | v1.0 | **FROZEN v1.0** | `EHAI.03.L3-人类介入原则.md` |
| **L4** | 通用交互协议 | General AI Interaction Protocol | v1.0 | **FROZEN v1.0** | `EHAI.04.L4-通用交互协议.md` |
| **L5** | 极简人类交互适配 | Minimal Human Interaction Adaptation *(English working candidate / OPEN)* | v1.0 | **FROZEN v1.0** | `EHAI.05.L5-极简人类交互适配.md` |
| **L6** | 机器语义与介入基础设施 | Machine Semantics & Intervention Infrastructure | v1.0 | **FROZEN v1.0** | `EHAI.06.L6-机器语义与介入.md` |
| **L7** | 具体实现边界 | Concrete Realization Boundary *(English working candidate / OPEN)* | v1.0 | **FROZEN v1.0** | `EHAI.07.L7-具体实现边界.md` |
| **L8** | 现实效应与经验闭环 | **OPEN** *(待 Human Authority 最终裁定 · 不预设正式英文名称)* | v1.0 | **FROZEN v1.0** | `EHAI.08.L8-现实效应与经验闭环.md` |

## 2.2 官方正式派生规范登记表 (Official Derived Specifications)

| Derivative Layer | 中文正式名称 | 英文正式名称 / 状态 | Version | Status | Canonical File | 父层与从属关系说明 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **L5.D1** | 表述适配 | Expression Adaptation *(English working candidate / OPEN)* | v1.0 | **FROZEN v1.0** | `EHAI.05.D1-表述适配.md` | 派生自 L5，受 L5 约束，不构成独立主体系层级 |

> [!IMPORTANT]
> **关于英文层名状态的特别说明：**
> 1. **L8 英文正式层名严格保持 `OPEN`**：L8 中文正式层名《现实效应与经验闭环》已正式冻结，但正式英文层名保持 OPEN，未随本次冻结一同裁定。严禁为了中英文对称而自行发明正式英文层名。
> 2. **L5 / L5.D1 / L7 英文层名**：当前处于工作候选态（English working candidate / OPEN），供国际交流辅助使用。
> 3. **全层冻结效力**：八层中文规范母稿均已获得 Human Authority 终审裁定冻结，任何文字与条款修改均受第 §10 条重开门禁严格限制。

---

# §3 八层职责导航

本节精简界定各层“负责什么”与“不负责什么”，保持极简索引，详细推导与条款必须阅读对应母规范。

### L1 人机认知哲学
* **负责什么**：人与 AI 的基本本体论定位、角色划分、能力与权力边界；确立全体系基石不变量 `Capability ≠ Authority`。
* **不负责什么**：不负责具体的交付验证规则、介入触发条件、交互通信协议及工程软件实现。

### L2 AI 交付原则
* **负责什么**：定义什么才算真正完成 AI 交付；确立核心不变量 `AI Output ≠ AI Delivery` 及真实任务完成性评价标准。
* **不负责什么**：不负责人类何时介入、介入判定算法、用户界面形态与工程数据持久化。

### L3 人类介入原则
* **负责什么**：定义什么时候需要人类介入（介入触发条件），以及人类介入时提供什么类型的具体作用（Inform / Provide / Judge / Authorize / Act 五大职责类型，以及 H / A / E 三轴正交判定维度：Human Necessity / Attention Timing / Execution Boundary）；确立 `Need Authorization ≠ Need Repeated Authorization`。
* **不负责什么**：不负责人类接入之后的交互通信协议序列、交互状态转换机以及界面的信息折叠呈现。

### L4 通用交互协议
* **负责什么**：负责人类真正介入后，人机之间如何形成合法、清晰、最小充分的交互完成态契约；确立 `Exploration ≠ Commitment` 不变量及三类协议不变量（PI-1~3）。
* **不负责什么**：不负责降低人类认知负荷的具体表述技巧与交互样式，不负责底层断言持久化。

### L5 极简人类交互适配
* **负责什么**：在绝不削弱人类权力、语义和判断条件的前提下，最大限度降低不可避免的人类认知与交互负担；确立核心不变量 `Burden Reduction ≠ Semantic Reduction`（含派生规范 L5.D1 表述适配）。
* **不负责什么**：不负责底层机器不可变数据结构实现，不负责宿主软件的具体 UI 业务框架编码。

### L6 机器语义与介入基础设施
* **负责什么**：AI 运行全生命周期中，机器如何持续保持语义、资格、适用性、效力、来源与现实效果的机器可恢复真实性；由三大根构成：R1 语义连续性完整性、R2 资格与效力完整性、R3 现实效果闭环完整性；确立 `L6 Reality Effect ≠ L8 Empirical Effect`。
* **不负责什么**：不负责上层具体软件系统的业务架构开发，不负责外部现实世界的宏观实证归因。

### L7 具体实现边界
* **负责什么**：评估与判定 EHAI 规范是否正确、完整地进入具体实现系统（Concrete Realization）；由三大根构成：R1 规范适用性完整性、R2 规范绑定完整性、R3 实现符合性；确立 `Applicability → Binding → Conformance`、`EHAI Specification ≠ DeepBase Implementation`、`L5 ≠ HB` 及符合性断言与证据相称性。
* **不负责什么**：不负责现实世界最终产生的效果、业务成败与外部因果归因（此为 L8 职责）。

### L8 现实效应与经验闭环
* **负责什么**：评估 EHAI 具体实现进入真实人机环境后产生了什么现实结果、这些结果在多大程度上可归因于 EHAI，以及现有证据支持形成多强的经验主张；由三大根构成：R1 现实结果完整性、R2 效果归因完整性、R3 经验主张完整性；确立 `Evaluation Scope → Outcome → Attribution → Empirical Claim`、`Conformance ≠ Empirical Effect` 及经验反馈闭环。
* **不负责什么**：不负责具体软件代码的符合性审计，不负责工程 Bug 排查，不制定业务 KPI。

---

# §4 Question → Layer Routing

实用问题路由导航表如下。遇到具体问题时，请查表进入对应规范，不得通过本表创造新的层级职责：

| 典型问题 / 关切场景 | 建议进入层级 | 核心关切与判定准则 | 对应 Canonical 文件 |
| :--- | :--- | :--- | :--- |
| AI 有没有权力替人类做出最终业务裁决？ | **L1** *(辅助 L3)* | `Capability ≠ Authority`；能力不等于授权 | `EHAI.01.L1-人机认知哲学.md` |
| AI 已经给出了文字/代码答案，是否就算交付完成？ | **L2** | `AI Output ≠ AI Delivery`；交付必须闭环完成 | `EHAI.02.L2-AI交付原则.md` |
| AI 遇到何种风险或歧义时必须停下来寻求人类介入？ | **L3** | H/A/E 三轴判定、Profile 类型化输出 | `EHAI.03.L3-人类介入原则.md` |
| 人类给出的长期授权，是否必须每次重复确认？ | **L3** | `Need Auth ≠ Need Repeated Auth`；授权范围与门限 | `EHAI.03.L3-人类介入原则.md` |
| 人类介入后，人机之间如何形成不可推诿的完成态契约？ | **L4** | `Exploration ≠ Commitment`；交互完成态协议 | `EHAI.04.L4-通用交互协议.md` |
| 如何在不削弱语义准确性的前提下精简人类输入与界面干扰？ | **L5** *(及 L5.D1)* | `Burden Reduction ≠ Semantic Reduction`；认知减负 | `EHAI.05.L5-极简人类交互适配.md` |
| 系统如何防止上下文衰减导致越权，如何保证机器语义持久可追溯？ | **L6** | R1 连续性、R2 资格效力、R3 现实闭环 | `EHAI.06.L6-机器语义与介入.md` |
| 某个软件（如 HB/DeepBase）到底有没有合规实现 EHAI 规范？ | **L7** | R1 适用性、R2 绑定、R3 符合性 (`Applicability → Binding → Conformance`) | `EHAI.07.L7-具体实现边界.md` |
| 按照 EHAI 规范上线了系统，真实用户在现实中到底发生了什么变化？ | **L8** *(R1)* | Evaluation Scope 界定、现实结果完整性收集 | `EHAI.08.L8-现实效应与经验闭环.md` |
| 观察到用户任务耗时缩短/错误率下降，这是否能归因于 EHAI 的引入？ | **L8** *(R2)* | 效果归因完整性、混淆因素排除、反事实比较 | `EHAI.08.L8-现实效应与经验闭环.md` |
| 我们手头的测试数据与实验证据，允许我们对外宣称多强的 EHAI 效果？ | **L8** *(R3)* | 经验主张完整性、主张强度与证据相称性 | `EHAI.08.L8-现实效应与经验闭环.md` |
| 现场实证发现理论假设在某种极端场景下失效，该如何启动规范治理？ | **EHAI.00** *(§10, §12)*<br>+ **L8** *(§8)* | L8 评估 → 是否构成 Qualified Empirical Challenge？ → 若构成 → Revision Candidate → Human Authority Review → Possible Reopen | `EHAI.00-总纲与规范索引.md`<br>`EHAI.08.L8-现实效应与经验闭环.md` |

---

# §5 EHAI 总体结构图

## 5.1 理论依赖三段论

EHAI 体系是自洽且严密的理论结构，其宏观关系为：

```text
       ┌────────────────────────────────────────────────────────┐
       │                 L1～L6 规范架构成立                    │
       │               (Normative Architecture)                 │
       │   L1 哲学 → L2 交付 → L3 介入 → L4 协议 → L5 减负 → L6 机器语义 │
       └───────────────────────────┬────────────────────────────┘
                                   │
                                   ▼
       ┌────────────────────────────────────────────────────────┐
       │                   L7 规范进入现实                      │
       │                 (Theory → Reality)                     │
       │       具体实现边界：Applicability → Binding → Conformance│
       └───────────────────────────┬────────────────────────────┘
                                   │
                                   ▼
       ┌────────────────────────────────────────────────────────┐
       │                   L8 现实反约理论                      │
       │                 (Reality → Theory)                     │
       │   现实效应与经验闭环：Scope → Outcome → Attribution → Claim │
       └────────────────────────────────────────────────────────┘
```

## 5.2 辅助记忆口诀与警示声明

为便于工程与研究人员快速记忆各层主旨，体系提供八字口诀对照：

```text
L1 定位  │  人与机器谁说了算，能力不等于权力
L2 交付  │  AI 生成不等于交付，任务必须真完成
L3 找人  │  何时必须喊人来，给准授权不复读
L4 算数  │  探索不等于承诺，落笔交互才算数
L5 省人  │  减负不等于减语义，极简界面省心力
L6 守真  │  机器语义不断链，断言效力可还原
L7 落地  │  规范如何进工程，合规绑定不漏接
L8 验真  │  现实到底灵不灵，相称归因求闭环
```

> [!CAUTION]
> **两大严正警示：**
> 1. **八字口诀仅为辅助记忆工具，绝非正式层名**。任何正式文书、工单和规范引用必须使用 §2 登记的正式中文层名。
> 2. **体系依赖图是理论规范与认识论依赖关系，绝非运行时执行序列（Runtime Sequence）**。实际软件执行时，绝不是机械地先跑 L1 代码、再调 L2 代码、再调 L3 代码。各层规范约束同时且立体地贯穿于人机交互的各环节中。

---

# §6 核心不变量索引

以下索引收录八层母规范中已冻结的、对于理解体系边界与跨层关系至关重要的核心不变量。本节只作索引，严禁借此展开二次推导或重新理论化：

| 核心不变量表达式 | 来源层级 | 极简导航说明 |
| :--- | :--- | :--- |
| `Capability ≠ Authority` | **L1** | 能力不等于权力。AI 具备的能力不等于其获得的法定授权。 |
| `AI Output ≠ AI Delivery` | **L2** | AI 生成内容不等于交付。任务完成需满足交付闭环与校验标准。 |
| `Need Authorization ≠ Need Repeated Authorization` | **L3** | 需要授权不等于需要机械重复授权。常设授权受 Scope / Condition / Ceiling / Reopen 约束。 |
| `Exploration ≠ Commitment` | **L4** | 探索不等于承诺。交互完成态确立前不产生不可撤回承诺。 |
| `Burden Reduction ≠ Semantic Reduction` | **L5** | 减负不等于削减语义。降低认知负荷不得削弱必要语义与人类判断条件。 |
| `L6 Reality Effect ≠ L8 Empirical Effect` | **L6 / L8** | L6 机器语义的系统调用现实效果不等于 L8 外部现实世界的人类经验效果。 |
| `Applicability → Binding → Conformance` | **L7** | 规范进入具体实现的最小判断依赖。 |
| `Conformance Claim Strength ≤ Evidence-Supported Conformance Strength` | **L7** | 符合性断言强度不得超出证据充分支撑的强度上限。 |
| `EHAI Specification ≠ DeepBase Implementation` | **L7** | EHAI 规范与 DeepBase 工程实现严格解耦。 |
| `L5 ≠ HB` | **L5 / L7** | L5 极简人机交互适配规范与 HB 工程实现资产严格解耦。 |
| `Conformance ≠ Empirical Effect` | **L7 / L8** | 实现符合性与真实经验效果正交解耦。 |
| `Evaluation Scope → Outcome → Attribution → Empirical Claim` | **L8** | 形成经验主张的最小判断依赖。 |
| `EHAI-related ≠ EHAI-attributed` | **L8** | EHAI 系统中观察到的现象不等于归因于 EHAI。 |
| `Observed Outcome ≠ Attributed Effect ≠ Empirical Claim` | **L8** | 观察结果、归因效果与经验主张处于不同认识论层级。 |
| `Association ≠ Causation` | **L8** | 经验相关关系不等于因果关系。 |
| `Metric ≠ Outcome` | **L8** | 数值指标不等于真实经验结果。 |
| `Proxy Improvement ≠ Target Improvement` | **L8** | 代理指标改善不等于真实目标改善。 |
| `Unresolved Material Alternative Explanation → Attribution Strength Ceiling` | **L8** | 未解决的实质性替代解释对归因强度构成封顶约束。 |
| `L7 Nonconformance ≠ Automatic Cause of Bad Outcome` | **L8** | L7 实现不符合不自动作为现实不良结果的归因原因。 |
| `No Comparator ≠ No Evaluation; No Comparison Basis → No Supported Comparative Claim` | **L8** | 缺乏合法比较基准不得支持比较性经验主张。 |

---

# §7 Theory / Realization / Evidence 边界

## 7.1 理论规范与工程实现的非等同性

EHAI 体系自创立起便恪守“理论与实现严格解耦”的第一性原则：

```text
EHAI Specification ≠ DeepBase Implementation
DeepBase ≠ EHAI
HB ≠ EHAI
AsWish ≠ EHAI
唤金 ≠ EHAI
```

这些具体的现实系统与工程资产处于如下法定角色：
* 它们可以**实现** EHAI 规范（Realize EHAI）；
* 它们可以**测试** EHAI 规范（Test EHAI）；
* 它们可以**提供实证证据**以供 EHAI 评估（Provide Evidence Relevant to EHAI）；
* 但它们**绝对不能反过来成为 EHAI 理论法源**。

任何工程实现中的架构妥协、编程语言限制（如 Delphi 语言特质）、产品业务偏好或商业诉求，均不得直接倒灌为 EHAI 理论规范。

## 7.2 体系角色关系图（非 Runtime Pipeline）

```text
    ┌────────────────────────────────────────────────────────┐
    │              EHAI Canonical Specification              │
    │             （开放、中立的跨平台理论母规范）                 │
    └───────────────────────────┬────────────────────────────┘
                                │
                                │ 规范映射与实现绑定 (L7)
                                ▼
    ┌────────────────────────────────────────────────────────┐
    │                  Concrete Realization                  │
    │         （DeepBase / HB / AsWish / 唤金 / 未来系统）     │
    └───────────────────────────┬────────────────────────────┘
                                │
                                │ 运行生成与客观记录
                                ▼
    ┌────────────────────────────────────────────────────────┐
    │                 Observation / Evidence                 │
    │               （现实观测、运行日志与测量证据）                │
    └───────────────────────────┬────────────────────────────┘
                                │
                                │ 范围评估与归因分析 (L8)
                                ▼
    ┌────────────────────────────────────────────────────────┐
    │                  L8 Empirical Finding                  │
    │              （合资格的实证发现与理论经验闭环）              │
    └────────────────────────────────────────────────────────┘
```

---

# §8 L7 / L8 边界

L7 与 L8 分处“理论进入现实”与“现实反馈理论”的关键铰链，极易发生概念混淆。本节确立核心防混层边界。

## 8.1 根本问题对照

* **L7 根本问题**：
  > `Did we correctly realize the applicable EHAI requirements?`
  > （我们是否在具体实现系统中，正确、完整、不走样地实现了适用的 EHAI 规范要求？）
  > ——关注对象是**工程系统与规范契约之间的符合性（Conformance）**。

* **L8 根本问题**：
  > `What happened in reality, what may reasonably be attributed, and what empirical claim is supported?`
  > （在真实人机环境中现实到底发生了什么？多大程度可归因于 EHAI？现有证据允许形成多强的经验主张？）
  > ——关注对象是**真实世界中发生的客观结果、效果归因与经验主张（Empirical Effects & Claims）**。

## 8.2 典型实例映射对比

| 现实研发场景 | 归属层级 | 性质界定 | 判定焦点 |
| :--- | :--- | :--- | :--- |
| HB 框架严格实现了“候选先行”协议与“取消不破坏上下文”接口 | **L7** | 实现符合性 (Conformance) | 系统代码与配置是否满足 L4/L5 规范要求 |
| 引入系统后，现场操作人员的任务平均耗时减少了 35 秒 | **L8 (R1)** | 现实结果 (Outcome) | 测量数据是否客观真实，评价范围是否清晰 |
| 耗时减少究竟是因为“候选先行”还是因为用户熟练度提升或任务简化？ | **L8 (R2)** | 效果归因 (Attribution) | 排除其他混淆因素，判定因果贡献度 |
| 能否在产品发布会上正式宣称“采用 EHAI 架构可提升任务效率 30%”？ | **L8 (R3)** | 经验主张 (Empirical Claim) | 证据强度是否相称，主张边界与适用范围是否严密 |

## 8.3 核心不变量与双向警示

```text
Conformance ≠ Empirical Effect
（符合规范不等于产生经验效果）
```

> [!WARNING]
> **双向解耦警示：**
> 1. **L7 符合，不保证 L8 产生优良结果**：系统完全 100% 严格符合 EHAI 规范，依然可能由于外部环境剧烈动荡、任务目标本身不可行、操作者动机不足等非规范因素而导致任务失败。
> 2. **L8 出现负面结果，不自动证明 L7 存在不符合**：现实任务受挫，不能在未做因果归因的前提下，直接武断推断是“由于某个模块没符合 EHAI”导致的。

---

# §9 Evidence Discipline

## 9.1 横切定位：严禁设立 Evidence R4

在 L7 与 L8 中，证据（Evidence）是支撑全部判断的命脉，但**证据是一项贯穿全流程的横切纪律（Cross-Cutting Discipline），严禁将其作为独立的第四根（R4）**：

```text
严禁出现：L7 R4 Evidence
严禁出现：L8 R4 Evidence
```

证据不是与适用性、绑定、符合性或结果、归因、主张平级的独立本体概念；证据是评估这些本体对象时必须出示的信度凭证。

## 9.2 两类核心用途与差异

证据纪律在 L7 和 L8 中分别承担截然不同且不可混淆的任务：

| 评估维度 | 核心目的 | 证据典型形态 | 证据纪律底线 |
| :--- | :--- | :--- | :--- |
| **L7 证据** | 支撑**实现符合性主张**<br>(Supports Conformance Claims) | 源代码审查、架构调用图、配置文件、单元与集成测试用例、静态代码分析报告、契约测试记录 | 断言强度不得超出证据支撑上限；缺少绑定测试不得做出强符合性断言 |
| **L8 证据** | 支撑**结果、归因与经验主张**<br>(Supports Outcome, Attribution & Empirical Claims) | 生产环境遥测日志、用户行为轨迹、时间序列测量数据、反事实与比较基准证据、混淆因素控制记录 | 缺乏合法 Comparison Basis，不得形成 Supported Comparative Claim；存在未排除重大替代假说时归因强度强制封顶 |

---

# §10 Freeze / Reopen Governance

## 10.1 冻结规范的效力

EHAI v1.0 的 L1～L8 规范母稿已全部处于：

```text
FROZEN v1.0
```

**冻结状态意味着该文本在当前 v1.0 版本中具有正式且受保护的理论效力。**严禁在日常开发、代码编写、Bug 修复或产品重构过程中对已冻结规范进行任何就地“顺手修改”或普通编辑。

## 10.2 理论修订的法定流向

任何触及理论核心、不变量、原语或条款的实质性修订，必须严格履行以下法定流向：

```text
New Evidence / New Theory Finding
（新的严肃实证证据 / 理论推导发现）
        ↓
Revision Candidate
（形成规范的修订候选提案，明确变动点、论证证据与影响范围）
        ↓
Human Authority Review
（人类主控 / 老板独立审阅与准入裁决）
        ↓
Explicit Reopen
（经正式指令显式宣布重开理论层，进入修订流程）
```

## 10.3 阻断不变量与非权限等价原则

在重开治理中，必须严格恪守以下阻断不变量：

```text
Finding ≠ Challenge
（发现新现象不等于形成理论挑战）

Challenge ≠ Revision
（理论受到挑战不等于自动修改理论）

Revision Candidate ≠ Automatic Reopen
（提出修订候选提案不等于自动获得重开授权）
```

同时明确确立四项**非权限等价原则**：

```text
Engineering Need ≠ Theory Revision Authority
（工程实现困难，绝不构成修改理论的法源权威）

Product Requirement ≠ Theory Revision Authority
（产品业务诉求，绝不构成修改理论的法源权威）

AI Preference ≠ Theory Revision Authority
（AI 大模型的偏好或生成结果，绝不构成修改理论的法源权威）

Empirical Finding ≠ Automatic Theory Revision
（实证经验发现，绝不能绕过审查自动引发理论修改）
```

> [!IMPORTANT]
> **Human Authority 独占原则：**
> 重新打开已冻结理论（Explicit Reopen）并做出正式理论修订裁定的权力，完全且独占地归属于 **Human Authority（人类主控/老板）**。AI 助手仅具备事实调查、证据整理、提案起草与逻辑分析的辅助职责，严禁自行僭越修改冻结母规范。

---

# §11 L8 实证入口

## 11.1 现实检验的法定入口

当工程团队或研究人员需要对 EHAI 的实际效能进行真实环境检验时，必须以 **L8《现实效应与经验闭环》** 作为法定规范入口。

## 11.2 最小判断依赖链（Judgment Dependency）

在进行现实检验与经验评估时，必须严格遵守以下判断依赖链：

```text
Evaluation Scope (评估范围)
        ↓
Outcome (现实结果)
        ↓
Attribution (效果归因)
        ↓
Empirical Claim (经验主张)
```

> [!NOTE]
> **本链条是逻辑判断依赖（Judgment Dependency），而非运行时间序列（Runtime Sequence）**。即：在判断主张前必须先完成归因；在归因前必须先确立结果；在收集结果前必须先界定评估范围。

## 11.3 评估范围（Evaluation Scope）要素构成

合资格的现实评估，必须首先完整显式定义 Evaluation Scope，包含以下要素：

* **七项基础要素**：
  1. **Subject / Mechanism**：所考察的 EHAI 规范机制或子机制；
  2. **Realization / Configuration**：被测的具体宿主系统与运行配置环境；
  3. **Human / Population**：参与的人类群体特征（专业度、熟练度、背景等）；
  4. **Task / Situation**：所执行的任务类型、复杂性与情境约束；
  5. **Environment**：运行的物理、组织与软件生态环境；
  6. **Temporal Horizon**：观察的时间跨度与数据采集窗口；
  7. **Primary Outcome Concern**：主要关切的现实结果类型。
* **条件性要素**：
  8. **Baseline / Comparator**：比较基线或对照条件（若涉及比较性主张）。

比较基准约束原则：

```text
No Comparator ≠ No Evaluation
（没有比较基线，不代表不能进行描述性事实评估）

No Comparison Basis → No Supported Comparative Claim
（缺乏合法 Comparison Basis，不得形成 Supported Comparative Claim）
```

## 11.4 排除域说明

本节及 L8 母规范严格限定于人机交互效能与归因的认识论框架，明确排除以下内容：
* 不包含具体 A/B 测试平台的代码开发与埋点脚本；
* 不包含统计学公式演算与样本量估算教程；
* 不包含商业 Telemetry 遥测架构设计；
* 不包含商业转化率、业务 KPI 与市场营销验证。

---

# §12 经验反馈与理论治理入口

## 12.1 经验回流四分支模型

实证研究所获得的合资格经验发现（Qualified Empirical Finding），通过以下四种法定出口接入理论治理：

```text
Qualified Empirical Finding
        │
        ├─ Empirical Support
        ├─ Boundary / Scope Refinement
        ├─ Qualified Uncertainty
        └─ Qualified Empirical Challenge
                    ↓
             Revision Candidate
                    ↓
             Human Authority Review
                    ↓
             Possible Reopen
```

各出口规范说明：
1. **Empirical Support**：经验观察结果支持既有规范假设；
2. **Boundary / Scope Refinement**：经验证据支持对经验发现或经验主张的适用范围、边界条件作更精确限定；
3. **Qualified Uncertainty**：经验证据表明存在当前不可消除的混淆因素或未定因果链，记录为已知不确定性；
4. **Qualified Empirical Challenge**：合资格的经验挑战表明既有理论在特定条件下存在实质性困难，唯一允许接入后续修订通道。

在治理流向中，必须严格恪守阻断不变量：

```text
Finding ≠ Challenge
Challenge ≠ Revision
Revision Candidate ≠ Automatic Reopen
Scope Refinement ≠ Automatic Theory Revision
```

只有 **Qualified Empirical Challenge** 可以继续进入 `Revision Candidate` 提报流程（若构成）。

## 12.2 理论治理底线

L8 不是 EHAI 的单向自证机制，现实结果允许产生上述四类正式结果。

关于各类实证结果的合资格判定条件、归因约束与证据标准，必须以《第八层：现实效应与经验闭环》（`EHAI.08.L8-现实效应与经验闭环.md`）已冻结条款为准。

---

# §13 Canonical File Registry

本节登记 EHAI v1.0 规范体系各正式文件、派生规范与参考资料。

## 13.1 主体系规范母稿与总纲索引 (Canonical Master Specifications)

| 层级编号 | 规范中文层名 | 官方标准文件名 (Canonical Filename) | 版本 | 法定状态 | 历史替代 (Supersedes) | 备注与法源说明 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Index** | 总纲与规范索引 | `EHAI.00-总纲与规范索引.md` | v1.0 | **APPROVED INDEX v1.0** *(Non-Normative)* | `EHAI.00-总览与推导总纲.md` *(前序总览)* | 非规范性体系总纲、规范索引与治理入口；非独立规范法源 |
| **L1** | 人机认知哲学 | `EHAI.01.L1-人机认知哲学.md` | v1.0 | **FROZEN v1.0** | 无 | 体系哲学基石；`Capability ≠ Authority` |
| **L2** | AI 交付原则 | `EHAI.02.L2-AI交付原则.md` | v1.0 | **FROZEN v1.0** | 无 | 体系交付基石；`AI Output ≠ AI Delivery` |
| **L3** | 人类介入原则 | `EHAI.03.L3-人类介入原则.md` | v1.0 | **FROZEN v1.0** | 无 | 体系介入基石；H/A/E 三轴判定维度 |
| **L4** | 通用交互协议 | `EHAI.04.L4-通用交互协议.md` | v1.0 | **FROZEN v1.0** | 无 | 体系协议基石；`Exploration ≠ Commitment` |
| **L5** | 极简人类交互适配 | `EHAI.05.L5-极简人类交互适配.md` | v1.0 | **FROZEN v1.0** | `EHAI.05.L5-人机行为适配.md` | 体系人机工程基石；`Burden Reduction ≠ Semantic Reduction` |
| **L6** | 机器语义与介入基础设施 | `EHAI.06.L6-机器语义与介入.md` | v1.0 | **FROZEN v1.0** | 无 | 体系机器语义基石；R1/R2/R3 三根结构 |
| **L7** | 具体实现边界 | `EHAI.07.L7-具体实现边界.md` | v1.0 | **FROZEN v1.0** | `EHAI.07.L7-产品实现边界.md` | 体系实现边界基石；`Applicability → Binding → Conformance` |
| **L8** | 现实效应与经验闭环 | `EHAI.08.L8-现实效应与经验闭环.md` | v1.0 | **FROZEN v1.0** | 无 | 体系实证闭环基石；英文层名 OPEN；R1/R2/R3 三根结构 |

## 13.2 官方正式派生规范 (Official Derived Specifications)

| 层级编号 | 规范中文层名 | 官方标准文件名 (Canonical Filename) | 版本 | 法定状态 | 历史替代 (Supersedes) | 备注与法源说明 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **L5.D1** | 表述适配 | `EHAI.05.D1-表述适配.md` | v1.0 | **FROZEN v1.0** | 无 | L5 官方派生规范；表述剪裁与展示规范；非独立主层 |

## 13.3 非规范性参考资料 (Non-Normative Reference Materials)

| 资料编号 | 资料名称 | 文件名 | 性质状态 | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| **REF-01** | AsWish × 唤金现状资料包 | `EHAI.实证.01-AsWish与唤金AI交互共性现状资料包.md` | **INFORMATIONAL** | 工程现状调查与跨产品资料整理资料包；非理论规范文件 |

## 13.4 非规范性工程承接基线登记 (Non-Normative Engineering Registry)

本节登记派生自 EHAI 规范的跨语言通用工程承接基线。本类文档属于非规范性工程架构与契约基线（Non-Normative Engineering Baseline），不属于理论规范，不具备理论法源效力。本登记属于维护操作（`Registry Maintenance ≠ Theory Reopen`）：

| 登记代号 | 文档名称 | 物理路径 | 状态 | 备注与法源说明 |
| :--- | :--- | :--- | :--- | :--- |
| **ENG-01** | EHAI 语言共用层总览与工程承接架构 | `common-contract/EHAI-Language-Common-Layer-Overview.md` | **APPROVED ENGINEERING BASELINE v0**<br>*(Non-Normative)* | 跨语言工程承接架构母稿，确立五层血统与 SSOT 治理 |
| **ENG-02** | EHAI 语言无关实现契约 (v0) | `common-contract/EHAI-Language-Neutral-Realization-Contract-v0.md` | **APPROVED ENGINEERING BASELINE v0**<br>*(Non-Normative)* | 跨语言可移植语义契约母稿，定义 SRC-01～10 与 CSV-001～008 |

## 13.5 登记簿审查与核对状态记录 (Verification Status Record)

经全面核对主库与镜像库现有文件，记录如下核对项状态：

1. **[TO VERIFY 1] 镜像库缺失 L1、L2 正式规范文件**：
   * **现状**：主库包含完整 L1～L8 文件；镜像库当前仅同步存有 L3～L8，未同步 `EHAI.01.L1-人机认知哲学.md` 与 `EHAI.02.L2-AI交付原则.md`。
   * **处理状态**：`PENDING DEPLOYMENT SYNC`（保留为部署同步待办事项；本工单禁止顺手修改或复制 L1/L2，待后续统一批处理）。
2. **[TO VERIFY 2] L6 文件名与正文标题全称的字面差异**：
   * **现状**：文件名实际为 `EHAI.06.L6-机器语义与介入.md`，正文标题与元数据中中文层名全称为 `第六层：机器语义与介入基础设施`。
   * **处理状态**：`KNOWN / NO THEORY CHANGE REQUIRED`（已确认 Canonical 文件，历史文件名简写不改变理论语义，不为名称对称修改冻结文件）。
3. **[TO VERIFY 3] L1 元数据 Status 的大小写格式**：
   * **现状**：L1 元数据中记载为 `Status: Frozen v1.0`，L2～L8 统一为 `Status: FROZEN v1.0`。
   * **处理状态**：`KNOWN / NO THEORY CHANGE REQUIRED`（已确认为排版格式差异，法定冻结效力一致，禁止因此修改冻结 L1）。

