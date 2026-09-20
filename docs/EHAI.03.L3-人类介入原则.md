---
title: "第三层：AI 人类介入原则 v1.0"
subtitle: "Efficient Human-AI Interaction · AI Human Intervention Principles"
Status: FROZEN v1.0
Layer: Human Intervention Principles (第三层：AI 人类介入原则)
System: 高效 AI 人机交互体系 (EHAI · Efficient Human-AI Interaction)
Specification: 高效 AI 人机交互规范 (EHAI Specification)
Framework Implementation: DeepBase (用于工程化实现和承载 EHAI Specification 的 Delphi 软件框架)
Nature: 体系规范母稿 (Normative Master Specification)
Upstream:
  - 第一层《AI 人机认知哲学 v1.0》 (EHAI.01.L1-人机认知哲学.md · FROZEN v1.0)
  - 第二层《AI 交付原则 v1.0》 (EHAI.02.L2-AI交付原则.md · FROZEN v1.0)
Downstream:
  - 第四层《通用 AI 交互协议 v1.0》 (EHAI.04.L4-通用交互协议.md · FROZEN v1.0)
  - 第五层《极简人类交互适配 v1.0》 (EHAI.05.L5-极简人类交互适配.md · FROZEN v1.0)
  - 第五层派生规范《表述适配 v1.0》 (EHAI.05.D1-表述适配.md · FROZEN v1.0)
  - 第六层《机器语义与介入基础设施 v1.0》 (EHAI.06.L6-机器语义与介入.md · FROZEN v1.0)
  - 第七层《产品实现边界》（下游工作候选 · OPEN）
Theory References:
  - 差异一元论 (Difference Monism) 为重要理论来源之一（完整谱系理论定位另议）
  - ASTO.P03 《认识论：认知错误的必然性与证据化认知》
  - 可见判断原则 (Observable Judgment Principle · OJP)
Author: 架构组 / 资料员
Reviewer: 老板 / 主控 (Human Authority)
Human Authority Final Review: PASS
Freeze Date: 2026-09-12
Date: 2026-09-12
Chinese Canonical Name: AI 人类介入原则
English Canonical Name: AI Human Intervention Principles (English working candidate / OPEN)
Theory Structure: FROZEN v1.0
Revision Note: |
  2026-09-12 Human Authority Final Review (PASS → FROZEN v1.0):
    - Human Authority 正式裁定终审通过，L3 自此进入正式冻结状态（FROZEN v1.0）
    - 确立 EHAI.03.L3-人类介入原则.md 为唯一规范母稿（Canonical Master Specification）
    - 冻结核心：Minimal Necessary Human Intervention、H / A / E 三轴正交判定模型、五类类型化 Human Involvement Profiles（Inform / Provide / Judge / Authorize / Act）产生条件、Attention Bound、Execution Gate、动态重评与介入压缩机制
  2026-09-12 Human Freeze Review Hold Calibrations (FREEZE CANDIDATE v1.0):
    - 清除 H 轴残留的“要不要人”表述，精确为“当前路径是否依赖新的 Human semantic contribution 或 Human takeover”
    - 修正 L2/L3 认知收支对称表述：从“索取注意力与判断劳动”扩展为“占用多少 Human 注意力，并索取多少不可替代的 Human 参与 / 语义贡献”
    - 扩展 E 轴核心质问：扩展为“当当前所需 Human Involvement / Human dependency 尚未解除时，机器最多可以合法、安全地推进到哪里？”，完备覆盖 H1/H2 及 Inform
    - 删除 L3 对 Inform Completion 的越权裁定：明确无响应不得使 L3 自动提高 Execution Gate，Inform 正式完成仍全权归 L4
    - 纠偏 Anti-pattern 1 对 H0 的过度 Inform 要求：确立 H0 ≠ Mandatory Silence 且 H0 ≠ Mandatory Inform，依 L2/领域/监管要求决定是否 Inform，无要求时 H0+A0+E0+none 同样合法
    - 收窄 H2 的“全面接管”表述为“接管当前相关受限路径的控制或主体处置，机器仍可承担不越界辅助工作”，补齐 H2 产生 Profile 集（涵盖 Provide 在内的五类 Profile 任意组合）
    - 清理 Human Judgment Window 旧术语，更名为工作名 Human Attention Window / 人类注意窗口，避免暗示介入仅为 Judge
    - 删除责任绝对化“负全责”措辞，改为“AI/系统必须完整履行属于自身的认知与交付责任，不得利用形式确认转嫁机器缺陷与责任”，严格对齐 L1 责任哲学
  2026-09-12 L3 Freeze Candidate Calibration:
    - 更新全体系法源与层级拓扑状态：严格对齐 L1/L2/L4/L5/L5.D1 已正式 FROZEN，L6 为重构校准候选；废除所有旧 L5=HB、旧 L4 候选、旧 L6 四元结构及旧 J-* 描述
    - 重新精确表述 L3 唯一根问题，确立第一总纲与第二辅助总纲（“该告诉人的要告诉，该由人补的才让人补；该机器继续干的，不因找人而停”）
    - 坚决维持 H / A / E 三轴正交模型，正式明确 H/A/E 为判定维度，Human Involvement Profile 为类型化输出，严禁设立第四轴
    - 纠偏 H 轴核心认知：明确 Human Dependency ≠ Human Visibility 与 Machine Sufficient ≠ Nothing Needs To Be Told To Human，H0 绝不排除 Inform
    - H 轴档位校准：H0 明确为无需新人类语义贡献亦无需接管；H1 扩充为 Human Contribution Required（不再局限于判断请求）；H2 纠偏为 Human Takeover Required（废除 Responsibility Handoff 说法，明确 H2 ≠ Authorize/Act/新 Profile，仅为机器控制状态改变）
    - 正式补齐 L3 → L4 的五类类型化 Human Involvement Profiles（Inform / Provide / Judge / Authorize / Act）及正交组合输出契约
    - 严格限定 L3 只定义 Profile 产生条件，绝不定义 Profile 完成语义（L4 全权负责完成规约与两场分离）
    - 旧五类贡献降级为非穷举的 Common Human Necessity / Involvement Basis，删除 Responsibility Contribution 作为正式贡献类型（内核融入 H2 接管根基）
    - 破除 Authority Holder 统称，确立 Profile-specific Human Qualification，明确 Qualified Information Source ≠ Authority Holder 与 Epistemic Qualification ≠ Authorization Authority
    - 校准 H1 四项准入资格与未知处理流水线
    - A 轴与 E 轴保持完全正交独立，A 轴同步服务 Inform；E 轴承诺边界与持续授权联动，解除“一变就重新要授权”的机械误区
    - Material Difference 明确为重新评估触发器，绝非自动重新问人
    - High-Leverage Judgment First 扩充并更名为 High-Leverage Human Contribution First（高杠杆 Human 贡献优先）
    - 介入压缩与动态重评升级为针对 Human Involvement / Human Requirement，动态清除失效与已解事项
    - 明确 No Response ≠ Consent，结合 Profile / Attention Bound / Execution Gate 差异化应对
    - 权知果时扰明确为派生检查问题，拆清“权”的三重含义
    - 全面重写 L3 → L4 交接契约，重推七大典型场景（场景 A～G）
---

# 第三层：AI 人类介入原则 v1.0
## AI Human Intervention Principles (English working candidate / OPEN · FROZEN v1.0)

---

## 〇、状态、法源与当前体系定位

### 0.1 规范母稿与当前体系状态
本文件为高效 AI 人机交互体系（EHAI）中关于“人类介入判定、注意力时机控制与执行边界界定”的**第三层规范母稿（FROZEN v1.0 · 唯一规范母稿）**。

当前全体系各层级的最新收敛法定状态如下：

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        EHAI 体系当前法源与状态拓扑                     │
├────────────────────────────────────────────────────────────────────────┤
│ L1 ｜ AI 人机认知哲学          │ FROZEN v1.0 (体系哲学母源)            │
├────────────────────────────────┼───────────────────────────────────────┤
│ L2 ｜ AI 交付原则              │ FROZEN v1.0 (交付结构与完成态标准)    │
├────────────────────────────────┼───────────────────────────────────────┤
│ L3 ｜ AI 人类介入原则          │ FROZEN v1.0 (唯一规范母稿)           │
├────────────────────────────────┼───────────────────────────────────────┤
│ L4 ｜ 通用 AI 交互协议          │ FROZEN v1.0 (通用交互契约与两场分离)  │
├────────────────────────────────┼───────────────────────────────────────┤
│ L5 ｜ 极简人类交互适配          │ FROZEN v1.0 (降低人类现实交互负担)    │
├────────────────────────────────┼───────────────────────────────────────┤
│ L5.D1 ｜ 表述适配              │ FROZEN v1.0 (L5 派生表述重述规范)     │
├────────────────────────────────┼───────────────────────────────────────┤
│ L6 ｜ 机器语义与介入基础设施    │ FROZEN v1.0 (唯一规范母稿)           │
├────────────────────────────────┼───────────────────────────────────────┤
│ L7 ｜ 产品实现边界              │ 下游工作候选 (OPEN)                   │
└────────────────────────────────┴───────────────────────────────────────┘
```

* **工程承载与呈现关系**：  
  * **DeepBase** 是用于工程化实现和承载 EHAI Specification 的 Delphi 软件框架；
  * **HB** 是 DeepBase 中承载面向 Human 交互的工程基础设施之一，负责将体系中的语义、逻辑、状态与交互行为转化为 Human 可感知、可操作的交互。$\text{L5 极简适配} \neq \text{HB 工程实现}$。

### 0.2 本轮重构的核心工作纪律
1. **定点结构校准，绝不重新开题**：本轮任务不是推倒重写 L3，而是清除因下游 L4 / L5 / L6 理论演进所暴露出的跨层接口错位与旧概念残留，使 L3 成为 L4 五类 Human Involvement Profile 的合法上游法源；
2. **严守 H / A / E 三轴正交模型**：不得新增第四判定轴（严禁把 Profile 升格为第四轴），不得推翻 H / A / E，不得新增体系哲学 Root；
3. **严格恪守层级职责分工**：
   * L3 只决定**什么时候依赖人、什么时候进入注意力、等人的时候机器能做到哪里，以及向 L4 提出何种类型的 Human Involvement 需求**；
   * L3 绝不定义 Profile 如何在界面上“完成”，绝不提前规定 L6 机器语义的物理实现，绝不涉足具体 UI、控件、弹窗尺寸、按键绑定、数据库表或 JSON 结构。

---

## 一、唯一根问题与 Minimal Necessary Human Intervention

### 1.1 新版唯一根问题精确表述
第三层在体系中只回答一个唯一的根问题：

> **当机器推进任务时，什么时候必须依赖 Human，什么时候应让 Human 的注意力进入，以及在 Human 尚未完成必要参与时机器最多可以推进到哪里？**

**通俗配套大白话**：
> **什么时候真得找人、什么时候找最合适、等人的时候机器还能干到哪？**

### 1.2 核心总纲与辅助总纲
第三层的行为准则由两大核心总纲统领：

* **第一核心总纲（底线法则）**：
  > **只问必须问的，只在必须问的时候问，只停必须停的部分。**
* **第二辅助总纲（协作法则）**：
  > **该告诉人的要告诉，该由人补的才让人补；该机器继续干的，不因找人而停。**

### 1.3 与第二层的工程认知收支对称
第二层交付原则与第三层介入原则在全体系中构成严格的**认知收支对称**：

```text
第二层：最小充分交付 (Minimal Sufficient Delivery)
= 机器至少应该交给人多少认知物 (D1～D7)
= 机器对 Human 知情权、审阅权与控制权的尊重底线

第三层：最小必要介入 (Minimal Necessary Human Intervention)
= 机器最多应占用多少 Human 注意力，并索取多少不可替代的 Human 参与 / 语义贡献
= 机器对 Human 专注力与认知负荷的保护底线
```

**核心总结**：
> **AI 交得足够，人只补最少。**

---

## 二、H / A / E 三轴正交模型

第三层坚决摒弃单一、粗糙的“严重度等级”或一维打分，采用三轴独立正交判定模型：

```text
┌─────────────────────────────────────────────────────────────┐
│                   L3 三轴正交判定维度 (Axes)                 │
├─────────────────────────────────────────────────────────────┤
│ H 轴 ｜ Human Necessity    (人类必要性) → 决定当前路径是否依赖新的 Human semantic contribution 或 Human takeover │
│ A 轴 ｜ Attention Timing   (注意力时机) → 决定“何时找人”    │
│ E 轴 ｜ Execution Boundary (执行边界)   → 决定“AI能做到哪”  │
└─────────────────────────────────────────────────────────────┘
```

### 2.1 判定维度与类型化输出的严格解耦
必须在体系中彻底厘清维度与输出的关系：
$$\text{H / A / E} = \text{L3 的判定维度 (Adjudication Dimensions)}$$
$$\text{Human Involvement Profile} = \text{L3 的类型化输出 (Typed Output)}$$
* **绝对禁令**：Profile 是 L3 依据 H 轴等判定后向 L4 发出的介入类型指令，**绝不是所谓的“第四判定轴”**。

### 2.2 三轴正交性原理
* **重要不等于现在打断**：一件事即使极度重要（H1），也完全可以处于 A1（汇总）或 A2（等待自然窗口），绝不必然触发即时打断；
* **紧急不等于必须找人**：一件事即使时间紧迫，只要机器已有完备规则与授权（H0），就应在 E0 正常执行，并在 A0（静默）推进；
* **等待不等于全局挂起**：某分支即使必须等待人类介入（H1/A2），系统也只应局部阻塞该特定受阻路径（E1），绝不因单点等待而挂起整个工作流。
* **三轴彼此独立，禁止在工程实现中被强行合成为单一的加权分值或简单线性枚举。**

---

## 三、H 轴：人类必要性（Human Necessity）

### 3.1 核心质问与关键认知校准
> **当前路径对 Human contribution 或 Human takeover 的依赖程度到底是什么？**

#### 关键防线等式（破除“H0 = 机器必须彻底黑盒”的错误理解）：
$$\text{Human Dependency} \neq \text{Human Visibility}$$
$$\text{Machine Sufficient} \neq \text{Nothing Needs To Be Told To Human}$$
* **通俗大白话**：**机器不需要人帮忙，不等于机器什么都不用告诉人。**
* 机器自主闭环与人类知情监督是两个不同维度的诉求。不能把“无需人输入”偷换为“剥夺人的可观察性”。

### 3.2 H 轴三级分档定义

```text
┌────────────────────────────────────────────────────────────────────────┐
│ H0 ｜ Machine Sufficient (机器已经足够)                                │
│      当前路径无需新的人类语义贡献，也无需接管；机器具备推进所需一切条件 │
├────────────────────────────────────────────────────────────────────────┤
│ H1 ｜ Human Contribution Required (需要 Human 语义贡献)                │
│      存在机器不能合法替代的必要人类语义贡献，缺失将实质影响目标与效力   │
├────────────────────────────────────────────────────────────────────────┤
│ H2 ｜ Human Takeover Required (需要 Human 接管 · Canonical OPEN)       │
│      超出机器自主控制职责边界，机器不应继续独立主导该责任性/控制性路径   │
└────────────────────────────────────────────────────────────────────────┘
```

#### H0｜Machine Sufficient（机器已经足够）
* **定义**：当前路径无需新的 Human semantic contribution，也无需 Human takeover；机器具备继续合法推进所需的事实、规则、授权和能力。
* **重大规则说明**：
  > **H0 绝不排除 Inform！**  
  > 例如，`H0 + A1 + E0 + Inform` 是完全合法的组合：机器完全有能力自主办妥任务并全速执行（H0/E0），但执行结果、审计摘要或状态变更需要在阶段结束时向人做汇总呈报（A1/Inform）。
* **严禁表述**：严禁在规范与工程中写出“H0 = 完全无需任何 Human 介入 / Human 不应被看见”。

#### H1｜Human Contribution Required（需要 Human 语义贡献）
* **定义**：当前存在一个机器不能合法替代、必须由合格 Human 完成的正式语义贡献；该贡献如果缺失，将实质影响目标、路径、效力、授权、事实基础或必要现实行动。
* **命名纠偏**：不得再狭隘地称为“有效的人类判断请求”。因为该贡献既可能是 Provide（提供事实），也可能是 Judge（做出裁决），或是 Authorize（授予权限）、Act（实施物理动作）。统一采用 **Human Contribution Required**。
* **排除条款（H1 边界澄清）**：
  * **AI 不确定 $\neq$ H1**（可继续通过本地文件检索、知识库查询解决的，AI 必须先自主求证）；
  * **AI 没见过 $\neq$ H1**（陌生领域只要规则与逻辑可推导，继续自主推导）；
  * **出现 Difference $\neq$ H1**（差异是客观现象，只有足以撼动判断根基的重大差异才触发重新评估）；
  * **事情很重要 $\neq$ H1**（重大事项若在已获有效授权与明确规约内，AI 照常自主推进）。

#### H2｜Human Takeover Required（需要 Human 接管 · Canonical OPEN）
* **废除旧名说明**：废止旧称 `Responsibility Handoff Required`。根据 L1 认知哲学，责任不能凭空消失，也不能虚假转嫁。具体法律与组织责任由真实控制权、授权与法律环境确定，L3 绝不预设“机器原先承担最终责任、现在转交给人类”。
* **工作定位**：当前路径已不是“Human 补一个输入后机器继续自主主导”，而是由于控制权边界、专业法定资格、重大伦理冲突、不可逆外部危机或组织规约限制，**机器不应继续独立控制该责任性/控制性路径，需要合格 Human 接管当前相关受限路径的控制或主体处置；机器仍可继续承担不越过该控制边界的辅助工作**。
* **核心防线等式**：
  $$\text{H2} \neq \text{Authorize}, \quad \text{H2} \neq \text{Act}, \quad \text{H2} \neq \text{一个单一的 Human Profile}$$
  * H2 是机器自身自主控制状态的根本转变，而不是一个新的交互形态；
  * 进入 H2 后，系统根据实际需要，可产生五类 Profile（Inform / Provide / Judge / Authorize / Act）中任意一个或组合（包括在接管过程中由人类向系统 Provide 现场关键处置参数等）。

---

## 四、Typed Human Involvement Profiles

L3 判定完成后，向下游 L4 交互协议输出类型化的 Human Involvement。体系正式确立五类平权 Profile：

```text
┌─────────────────────────────────────────────────────────────┐
│           L3 → L4 五类 Human Involvement Profiles           │
├─────────────────────────────────────────────────────────────┤
│ 1. Inform    │ 告知与可见性 ── 结果、状态与风险进入人侧感知 │
│ 2. Provide   │ 提供必要输入 ── 事实、参数、约束与明确意图   │
│ 3. Judge     │ 主体价值裁决 ── 价值排序、方案取舍与意义赋予 │
│ 4. Authorize │ 正式效力授权 ── 行动权限覆盖与越界许可       │
│ 5. Act       │ 现实动作实施 ── 机器无法物理/法定替代的操作  │
└─────────────────────────────────────────────────────────────┘
```

### 4.1 五类 Profile 的触发条件（L3 职责范围）
L3 仅严格定义各类 Profile 的**产生条件**，严禁规定其完成语义：

1. **Inform（告知）**：
   * **触发条件**：某项结果、状态、风险、Material Difference、执行结果或必要监督信息应进入 Human 可观察范围，但当前不要求 Human 提供新的正式语义贡献；
   * **重要来源**：**Inform 可以来自 H0，也可以来自 H1 或 H2**。
2. **Provide（提供）**：
   * **触发条件**：存在一个当前任务推进所需、机器无法合法获得或自行确定，而某个合格 Human 可以提供的必要事实、环境参数、外部约束、目标细节或意图输入。
3. **Judge（裁决）**：
   * **触发条件**：当前路径依赖 Human 保留的主体性价值排序、多目标冲突取舍、方案接受性评估、意义赋予、最终偏好定夺或其他主体裁断。
4. **Authorize（授权）**：
   * **触发条件**：当前拟议动作需要有效 Authorization Coverage（即将跨越承诺边界或进入受限域），但当前不存在足够且仍适用的有效授权；
   * **防机械重复铁律**：
     $$\text{Need Authorization} \neq \text{Need Repeated Authorization}$$
     已有仍然有效的当前授权、任务授权或持续授权（Standing Authorization）覆盖时，严禁机械产生新的 Authorize 请求。
5. **Act（实施）**：
   * **触发条件**：某项必要现实动作必须由 Human 本人完成，机器在合法性、物理环境或主体资格上无法替代（例如物理插拔硬件、面对面签字确认、法人实名认证等）。

### 4.2 Profile Composition（正交组合）
Profile 彼此之间允许按需正交组合，单次介入场景中可同时包含多个 Profile，例如：
* `Provide + Judge`：既需要人类补充现场缺失事实，又需要对两套衍生方案做出价值取舍；
* `Judge + Authorize`：人类选定最终方案的同时，正式签发针对该方案高危动作的执行授权；
* `Authorize + Act`：在授权高危部署的同时，要求管理员在物理安全密钥上完成触碰认证；
* `Inform + Judge`：向人类通报已执行部分的阶段性结果，并请求对后续分支策略做出裁决。

### 4.3 L3 与 L4 的绝对职责划分
> **L3 decides which Human Involvement is required; L4 defines how that typed involvement is formally completed.**  
> （L3 决定需要何种类型的人类介入；L4 决定该类型化介入如何在协议与语义上正式完成。）

* **L3 严禁越权涉足的内容（全权归 L4 规约）**：
  * Inform 何时算 Presented、是否需要显式 Acknowledgment；
  * Provide 与 Judge 的类型化完成与 Context 绑定；
  * Authorize 的正式语义绑定与效力签发；
  * Act completion 与执行凭据检验；
  * Conversation Surface 与 Decision Surface 的两场分离（`Exploration ≠ Commitment`）；
  * 0–9 标准选择语法、Candidate Set、Clarify、Reframe 及具体交互协议。

---

## 五、Human Necessity / Involvement Basis

旧规范中的“五类不可替代人类贡献”正式降级并重构为**常见、非穷举的介入根基（Common Human Necessity / Involvement Basis）**。它们解释了“为什么机器不能自主闭环、为什么人类介入有必要”：

```text
┌─────────────────────────────────────────────────────────────┐
│         常见 Human 介入根基与 Profile 映射关系              │
├─────────────────────────────────┬───────────────────────────┤
│ 1. Human-only Fact Basis        │ ──常触发──► Provide       │
│ 2. Value Basis                  │ ──常触发──► Judge         │
│ 3. Goal Basis                   │ ──常触发──► Judge         │
│ 4. Authority Gap                │ ──常触发──► Authorize     │
│ 5. Human-only Action Requirement│ ──常触发──► Act           │
│ 6. Takeover / Control Boundary  │ ──常触发──► H2            │
│ 7. Mandatory Visibility / Oversight │ ──常触发──► Inform    │
└─────────────────────────────────┴───────────────────────────┘
```

1. **Human-only Fact / Information Basis（人类独有事实根基）**：
   人类是某个未数字化、线下发生或隐蔽关键事实的正当知情者（“我知道”）。*铁律：人是最后事实来源，不应该是第一事实来源。*
2. **Value Basis（主体价值根基）**：
   回答“什么更重要、为了目标愿意付出何种代价”（“我在乎”）。涉及速度 vs 质量、收益 vs 风险等多目标权衡。
3. **Goal Basis（根本目标根基）**：
   回答“我们最终要解决什么问题、终局成功的定义是什么”（“我要什么”）。*铁律：AI 可以澄清与挑战问题框架，但绝对不能偷偷重写人类的最终目标。*
4. **Authority Gap（行动权限缺口）**：
   回答“AI 是否拥有跨越现实边界的正式行动许可”。*铁律：认知正确 $\neq$ 行动有权。*
5. **Human-only Action Requirement（人类专属动作要求）**：
   现实世界中机器在物理上无法触达、或法规要求必须自然人亲历的操作。
6. **Human Takeover / Control Boundary（人类接管与控制边界）**：
   由于风险失控、资质不足或法定代理越界，机器必须退居辅助、让渡控制权（进入 H2）。
7. **Mandatory Human Visibility / Oversight（法定/合规可见性与监督根基）**：
   即便机器自主能力充分，依照合规或业务契约必须让人知悉关键运行状态（触发 Inform）。

* **说明**：正式废除“Responsibility Contribution”作为平级贡献类型，其关于法律、伦理与控制权主体的核心价值全面归入 H2 接管根基。

---

## 六、Qualified Human / Role

系统严禁将所有合格人类主体笼统冠以“Authority Holder”，必须实施精确的 **Profile-specific Human Qualification（分型人类资格匹配）**：

```text
┌─────────────────────────────────────────────────────────────┐
│                Profile-specific Human Qualification         │
├─────────────┬───────────────────────────────────────────────┤
│ Provide     │ Qualified Information Source (合格信息来源)   │
├─────────────┼───────────────────────────────────────────────┤
│ Judge       │ Proper Value / Goal Subject (正当价值/目标主体)│
├─────────────┼───────────────────────────────────────────────┤
│ Authorize   │ Authority Holder (正式法定/组织授权主体)     │
├─────────────┼───────────────────────────────────────────────┤
│ Act         │ Qualified Actor (合格现实操作主体)           │
├─────────────┼───────────────────────────────────────────────┤
│ Inform      │ Appropriate Recipient / Role (正当被告知角色) │
└─────────────┴───────────────────────────────────────────────┘
```

### 6.1 核心正交等式
$$\text{Qualified Information Source} \neq \text{Authority Holder}$$
$$\text{Epistemic Qualification} \neq \text{Authorization Authority}$$
* 知道关键事实的人（合格信息源），绝不必然拥有签发高危变更的授权权力；
* 拥有认识资格（知道怎么做）不等于拥有法理权力（有权决定做）。

### 6.2 H1 四项准入资格
一个潜在事项必须**同时满足**以下四项条件，才具备进入 H1 的正当资格：
1. **Important Relevance（重要相关性）**：该贡献将实质影响目标、路径、效力、授权、事实或必要现实行动；
2. **Currently Unresolved（当前未解决）**：在现有上下文、知识库、既有规约与持续授权中不存在现成有效答案；
3. **Machine Cannot Legitimately Substitute（机器不可替代）**：AI 穷尽检索、推导与低成本可逆验证后，仍无法合法闭环；
4. **Proper Qualification（具备匹配资格）**：目标对象是针对当前 Profile 具备合法正当资格的 Human / role。

* **黄金准则**：  
  > **不是 AI 不知道就找人，而是当前仍存在重要且未解决的 Human dependency，而且只有具有相应资格的 Human 才能合法完成。**

### 6.3 未知处理认知链路
> **未知首先触发机器继续认知，不首先触发人类介入。**

```text
遭遇 Unknown (未知变量)
       ↓
[步骤 1] 现有上下文与交互历史能推导？  ──(能)──→ 自主消化 (H0)
       ↓ (否)
[步骤 2] 本地文件、知识库与日志能检索？  ──(能)──→ 检索补齐 (H0)
       ↓ (否)
[步骤 3] 既往决策与历史基线能比对得出？  ──(能)──→ 逻辑收敛 (H0)
       ↓ (否)
[步骤 4] 能否通过完全可逆的沙箱模拟验证？  ──(能)──→ 模拟获取 (H0)
       ↓ (否)
[步骤 5] 该未知是否属于关键未知 (Critical Unknown)？  ──(否)──→ 记录备忘 / 渐进显露 (H0)
       ↓ (是)
[步骤 6] 是否只有特定资质的 Human 有正当资格提供？  ──(是)──→ 正式核准为 H1 介入需求
```

* **关键未知（Critical Unknown）**：只有其不同答案会实质改变目标、路径、权限、责任或现实后果的未知，才构成关键未知。平庸实现细节严禁打扰人类。

---

## 七、A 轴：注意力时机（Attention Timing）

### 7.1 核心质问与三大误区破除
> **这件事最晚什么时候进入人的注意力，依然来得及且代价最小？**

#### 破除三大注意力误区：
1. **事情重要 $\neq$ 现在值得打断**（重大的系统架构决策，完全可以等到例行审阅时段集中处理）；
2. **事件紧急 $\neq$ 人必须立即介入**（紧急的系统熔断若在已授权策略内，AI 应自主秒级切断，事后汇总呈报）；
3. **需要人 $\neq$ 现在就需要人**（需要最终审批，但当前距离交付尚有窗口，AI 应先完成推演与准备）。

### 7.2 最晚介入点（Latest Intervention Point）
* **定义**：如果人类的知情、判断或授权继续晚于某个特定时点，将开始造成不可逆的现实机会丧失、严重的判断价值贬损，或将迫使 AI 越过合法执行边界，该时点即为最晚介入点；
* 最晚介入点是倒逼 A 轴升级的唯一刚性时间基准。

### 7.3 A 轴四档时机定义
```text
┌────────────────────────────────────────────────────────┐
│ A0 ｜ 静默 (Silent)                                    │
│      完全不占用人类注意力，后台自主流转                 │
├────────────────────────────────────────────────────────┤
│ A1 ｜ 汇总 (Digest / Batch)                            │
│      值得人类知情，但延迟无损失，阶段结束时批量呈报     │
├────────────────────────────────────────────────────────┤
│ A2 ｜ 适时介入 (Timely / Natural Window)                │
│      时限前必须完成，但不破坏当前心流，等待自然注意力窗口│
├────────────────────────────────────────────────────────┤
│ A3 ｜ 即时介入 (Immediate Interruption)                 │
│      继续延迟将导致实质损失或迫使系统越界，强制即时打断 │
└────────────────────────────────────────────────────────┘
```
* **A 轴的普适性**：A 轴不仅服务于 H1/H2，同样服务于 H0。例如，`H0 + Inform + A1`（自主办结、汇总呈报）是全体系推荐的黄金模式。
* **自然注意力窗口（Natural Attention Window）**：人类切换进入该任务、处于工作切换间歇、或主动调出待办面板时的认知窗口。*铁律：能在自然注意力窗口解决的事项，严禁提前制造强制打断。*

---

## 八、人类介入偏好（Human Intervention Preference）

系统确立五档标准介入偏好，以调节系统的打扰敏感度：

```text
及时请示  |  必要请示  |  平衡 (系统默认)  |  少打扰  |  尽量不请示
```

### 8.1 介入偏好的铁律红线
* **第一铁律**：
  $$\text{Preference} \neq \text{Authorization}$$
  介入偏好只调节注意力的节奏与通知策略，**绝不改变 Human Authority，绝不自动扩大行动授权，绝不能突破现实承诺边界**。
* **第二铁律**：
  $$\text{少打扰} \neq \text{多授权} \quad (\text{及时请示} \neq \text{少授权})$$
* **第三铁律**：
  $$\text{尽量不请示} \neq \text{沉默即授权}$$
* **通俗大白话**：**可以少问我，但不能替我越权。**

### 8.2 介入偏好来源原则（严禁 AI 自行改档）
* 生效来源唯一性：当前生效的偏好档位，**只能来自用户当前显式指示，或用户在配置中的显式保存**；
* 历史行为与偏好证据仅可用于向用户提出“是否调整偏好”的建议，AI 绝对不得自动改档或自行升级权限；
* **持续授权（Standing Authorization）绝不得作为介入偏好的来源**。

---

## 九、介入优化机制 (Intervention Optimization)

### 9.1 介入事项动态重评（Dynamic Re-evaluation）
待介入事项不是静态消息，而是随环境变化的动态对象。当事实、授权、时间或上下文变化时，必须动态重评：
* 该事项现在还需要人吗？后续发生的事实是否已顺带解决该问题？
* 最晚介入点是否发生推移？
* 是否可与刚刚生成的同类事项合并？
* 基础环境是否已改变导致该问题彻底失效？
* **铁律**：**已失效或已被机器后续自愈的 Human Requirement，必须静默移出待介入集合。**

### 9.2 介入压缩机制（Intervention Compression）
存在多个待介入事项时，严禁原样平铺抛出，必须经过强力压缩流水线：
```text
[1. 剔除失效] 自动清除已过时、无意义的介入诉求
      ↓
[2. 剔除已解] 自动移出机器后续已自行求证闭环的事项
      ↓
[3. 语义合并] 将属于同一上下文与底层逻辑的事项合并为单次呈现
      ↓
[4. 依赖分析] 分析各介入事项之间的上下游因果与拓扑关系
      ↓
[5. 提炼交付] 仅将真正独立的顶层 Human Requirement 交给人
```
* **核心金句**：**减少打扰的第一手段不是静音，而是减少真正需要人的问题本身。**

### 9.3 人类注意窗口（Human Attention Window · 工作名）
* **定位说明**：工作名定为 Human Attention Window / 人类注意窗口（或 Human Involvement Window / 人类介入窗口），不作为新的 Canonical 理论术语；废除将人类注意窗口狭隘绑定为 Judge 的旧表述；
* **定义**：一段由相同决策或任务背景构成的集中认知窗口；
* **防杂烩约束**：只有属于同一项目、同一工作对象、同一任务背景的事项才允许打包呈报；严禁将无关琐碎事务拼凑为认知杂烩。

### 9.4 高杠杆 Human 贡献优先（High-Leverage Human Contribution First · Canonical OPEN）
* 当多个介入事项交织依赖时，AI 严禁并发平铺提问，必须精准定位**上游最高杠杆的介入节点**（该节点既可能是 Judge，也可能是 Provide、Authorize 或 Act）；
* **核心金句**：
  > **先问那个一答，后面很多问题就不用问的问题。**

---

## 十、E 轴：执行边界（Execution Boundary）

### 10.1 核心质问与执行前沿
> **当当前所需 Human Involvement / Human dependency 尚未解除时，机器最多可以合法、安全地推进到哪里？**

* **执行前沿（Execution Frontier）**：AI 在不越过人类主权、既定授权与不可接受现实后果的前提下，当前能够安全推进到的最远工作极限。

### 10.2 E 轴四档划分定义
```text
┌────────────────────────────────────────────────────────┐
│ E0 ｜ 正常推进 (Normal Execution)                      │
│      完全不依赖新外部输入，在授权范围内全速闭环        │
├────────────────────────────────────────────────────────┤
│ E1 ｜ 继续无依赖部分 (Partial Forwarding)               │
│      局部受阻等待人，但无依赖的其余分支继续并行推进    │
├────────────────────────────────────────────────────────┤
│ E2 ｜ 停在承诺边界前 (Halt at Commitment Boundary)      │
│      完成所有准备、推演与模拟，绝对不跨越现实承诺线    │
├────────────────────────────────────────────────────────┤
│ E3 ｜ 停止当前路径 (Halt Current Path)                 │
│      当前路径不适宜继续推进，保存现场，挂起等待重定义  │
└────────────────────────────────────────────────────────┘
```
* **局部阻塞铁律**：
  > **只停必须停的部分。局部受阻，不默认全局挂起。**

### 10.3 承诺边界（Commitment Boundary）
* **定义**：一项操作从“纯内部准备、推演、模拟或完全可安全撤回状态”，跨入产生现实外部影响、正式契约约束、主体责任承诺或高恢复代价状态的临界点。
* **核心铁律**：
  > **准备可以提前，承诺不能提前。**
* **承诺边界严密对照表**：
  ```text
  【承诺边界左侧 (准备态/模拟态/推演态)】      【承诺边界右侧 (必须有效授权覆盖)】
  生成邮件草稿 (Drafting)               ≠    正式发送外部邮件 (Sending)
  本地沙箱仿真 (Simulation)             ≠    生产真实环境执行 (Execution)
  推演候选方案 (Candidate Set)          ≠    锁定正式决定 (Decision Commitment)
  本地变更对比预览 (Diff Preview)       ≠    写回真实物理存储 (Apply / Commit)
  工程构建与测试 (Build & Test)         ≠    产线正式发布部署 (Deploy / Release)
  制定行动方案计划 (Plan)               ≠    触发外联动作用款 (Disbursement / Write)
  ```

### 10.4 持续授权（Standing Authorization）与防机械重复原则
* **持续授权四要素**：
  1. **Scope（范围）**：生效的业务领域、目录或功能边界；
  2. **Condition（条件）**：授权成立的前提假设、环境约束与安全基线；
  3. **Ceiling（上限）**：资源额度上限、修改深度上限或最大影响范围；
  4. **Reopen（重开）**：发生何种偏离时触发授权适用性与 H/A/E 重新评估。
* **防机械重复铁律**：
  $$\text{Human Authority} \neq \text{Human Repetition}$$
  跨越承诺边界必须有合法授权覆盖。但授权可能来自当前明确授权、任务授权或仍适用的持续授权。只要在有效授权范围内，系统在 E0 推进，严禁机械重复要人确认。
* **环境变化的规范处理流（严禁写“一变就必须重新授权”）**：
  ```text
  Difference / Context Change (环境发生变化)
              ↓
  Qualification / Applicability Re-evaluation (适用性重核)
              ↓
  H / A / E Re-evaluation (重新判定三轴)
              ↓
  Only if current authorization remains insufficient (仅当现有授权不足时)
              ↓
  Produce Authorize Profile (才产生新的 Authorize 需求)
  ```

### 10.5 现实恢复性原则（Real-World Recoverability）
* **技术可恢复 $\neq$ 现实可恢复**。发错外部敏感信函无法靠更正信挽回商业信誉；破坏性删除生产库无法靠冷备恢复抵消商誉损失。
* 后果评估三要素：**对外性**（是否辐射组织外部）、**承诺性**（是否产生契约约束）、**现实恢复性**（物理与商业关系的真实挽回代价）。

---

## 十一、Material Difference 与 Reopen 机制

### 11.1 差异在第三层的位置定界
$$\text{Difference} \neq \text{Human Interruption}$$
* 在第二层交付中，Difference 是认知交付的重要客体（$\text{Difference} \neq \text{Error}$）；
* **在第三层介入中，Difference 绝不是一个打分参数，而是“重新评估 H / A / E 判定的刚性触发器”**。

### 11.2 Material Difference 定义与重开评估
* **定义**：如果一个 Difference 足以改变“权、知、果、时、扰”中的关键判断，从而可能推翻原授权成立前提或改变 H/A/E 策略，则属于第三层的 **Material Difference（实质差异）**；
* **评估机制**：
  $$\text{Material Difference} \rightarrow \text{Re-evaluate H / A / E / Profile / Applicability}$$
  * Material Difference 触发的是**系统内部重新评估**，绝非自动机械叫人；
  * 重新评估后，若机器发现既有规则或新事实仍可自主消化，则保持 H0；仅当重评确认存在不可替代缺口时，才派生对应 Profile。
  * **金句**：**环境没变，不重复问；条件变了，重新判断。**

---

## 十二、等待人时的认知与执行规范

### 12.1 等待人时继续向前
因 H1 等待人类时，AI 严禁停工躺平，必须在安全前沿推进辅助工作：
* 严格冻结直接依赖该介入的下游路径；
* 全速推进不依赖该介入的平行分支；
* 继续在后台搜集线索尝试消化未知；
* 提前准备多种分支的决策材料（D1～D7）；
* 提前生成可观察物（Observable），备人类切入时秒级呈现。
* **金句**：**在不能替人决定的地方停下来，在不需要人的地方继续向前。**

### 12.2 推测性准备（Speculative Preparation）
在不越权、不造成现实承诺、资源开销可控的前提下，AI 可以针对人类可能做出的不同分支展开推测性推导与准备（如同时生成方案 A 与方案 B 的完整 Diff 预览）。推测性准备必须严格锁死在承诺边界（E2）左侧。

### 12.3 划清 Human in the Loop 边界
$$\text{Human in the Loop} \neq \text{Human in Every Step}$$
人类的参与必须聚焦在不可替代的高价值关键节点，严禁让每一次中间状态流转都变成人类必须点击的绊马索。

### 12.4 严禁责任转嫁与确认疲劳
* **确认疲劳（Confirmation Fatigue）**：频繁、低价值的机械式弹窗确认，会导致人类产生条件反射式的闭眼盲点，彻底摧毁真正的人类审阅质量；
* **严惩责任转嫁**：
  > **人的确认不能成为 AI 转嫁自身认知责任的免责按钮。**  
  AI 未尽充分推导直接把半成品抛给用户并索取确认，事后以“用户已确认”为由推卸幻觉责任，在体系中被判定为严重违规。

### 12.5 沉默原则：No Response ≠ Consent
$$\text{No Response} \neq \text{Consent}$$
* 即使在“少打扰”或“尽量不请示”模式下，人类的沉默也决不能被解释为授权许可；
* **长期无响应的差异化应对**：
  * 系统根据具体的 **Profile、Attention Bound、Execution Gate 与 Authorization Coverage** 进行差异化处理，**并非所有无响应都必须死锁在 E2**；
  * *示例*：在纯 Inform 场景中，若 L4 / 领域规约已确定当前 Inform 不要求 Human Response，则无响应本身不得使 L3 自动提高 Execution Gate 或生成新的授权要求（Inform 是否正式完成仍归 L4 规约）；而在 Authorize 场景中，无响应则必须坚决阻绝于承诺边界左侧。

### 12.6 指令与授权冲突消解准则
遵循“更新、更具体优先”原则：
$$\text{最新明确意图} > \text{任务单次授权} > \text{通用持续授权} > \text{历史偏好证据} > \text{AI 自主推测}$$

---

## 十三、“权知果时扰”派生检查框架

第三层在工程实践中坚决不做虚假的数学公式打分，系统通过五个质朴的派生问题完成 H/A/E 的核验：

```text
【权】执行权与授权权各在哪？谁是事实源？──┐
【知】AI 当前掌握的信息够不够？          ──┴──→  H 轴｜当前路径是否依赖新的 Human 语义贡献或接管

【权】当前执行授权边界到哪里？           ──┐
【果】最坏后果是什么？现实能否恢复？     ──┴──→  E 轴｜AI 能做到哪 (执行边界)

【时】最晚推迟到何时仍来得及？           ──┐
【扰】打断成本多大？是否值得？           ──┼──→  A 轴｜何时找人 (注意力时机)
【果】后果紧迫度是否影响介入窗口？       ──┘

                 Material Difference (实质差异)
                               ↓
                   触发 H / A / E 重新评估
```

* **“权”的三重含义彻底拆清**：
  1. **谁拥有正式授权权（Authority Holder）？**
  2. **AI 当前拥有多大合法执行权（Execution Scope）？**
  3. **谁仅仅是事实的知情来源（Qualified Information Source）？**
  绝不再将三者混淆在一个笼统的“Authority”概念中。
* **知（Knowledge）**：AI 当前掌握的事实与证据是否充分？是否存有关键未知？
* **果（Consequence）**：贸然推进的最坏现实后果是什么？物理与人际层面能否低成本恢复？
* **时（Timing）**：这个判断最晚推迟到什么时候，依然来得及且不造成实质损失？
* **扰（Disruption）**：强行打断人类的心流切换代价是否值得？

---

## 十四、第三层核心句集合（Golden Rules）

1. **只问必须问的，只在必须问的时候问，只停必须停的部分。**
2. **该告诉人的要告诉，该由人补的才让人补；该机器继续干的，不因找人而停。**
3. **AI 交得足够，人只补最少。**
4. **机器不需要人帮忙，不等于机器什么都不用告诉人（$\text{Human Dependency} \neq \text{Human Visibility}$）。**
5. **未知首先触发机器继续认知，不首先触发人类介入。**
6. **人是最后事实来源，不应该是第一事实来源。**
7. **需要人，不等于现在需要人。**
8. **事情重要，不等于现在值得打断。**
9. **事件紧急，不等于人必须立即介入。**
10. **Human Authority $\neq$ Human Repetition（人类的主权不等于机械重复）。**
11. **Human in the Loop $\neq$ Human in Every Step（闭环不等于步步卡死）。**
12. **No Response $\neq$ Consent（无回应绝不等于默认同意）。**
13. **准备可以提前，承诺不能提前。**
14. **只停必须停的部分（局部受阻不引发全局瘫痪）。**
15. **在不能替人决定的地方停下来，在不需要人的地方继续向前。**
16. **减少打扰的第一手段不是静音，而是减少真正需要人的问题本身。**
17. **AI 可以越来越懂人，但不能因为越来越懂，就偷偷给自己增加权限。**
18. **人的确认不能成为 AI 转嫁自身认知责任的免责按钮（AI/系统必须完整履行属于自身的认知与交付责任，不得利用形式确认转嫁机器缺陷与责任）。**
19. **高杠杆 Human 贡献优先——先问那个一答，后面很多问题就不用问的问题。**
20. **可以少问我，但不能替我越权（少打扰 $\neq$ 多授权；尽量不请示 $\neq$ 沉默即授权）。**

---

## 十五、典型反例库（Anti-Patterns）

* **反例 1：把 H0 误解为对人完全黑盒或机械全汇报（H0 Misconception）**  
  *违规现象*：其一，在合规监管或重要状态变更要求人类可见时，AI 借口 H0 将执行过程完全黑盒隐瞒；其二，机械误解 H0，认为所有后台日常推进都必须强制弹窗或推送 Inform。  
  *违反准则*：违背 H0 的中性可见性边界：
  $$\text{H0} \neq \text{Mandatory Silence}$$
  $$\text{H0} \neq \text{Mandatory Inform}$$
  H0 仅代表当前无需新的 Human 语义贡献与接管；当 L2 交付要求、领域契约、监督义务或特定 Context 要求人类可见时才派生 Inform；无此要求时，`H0 + A0 + E0 + none`（静默推进无需打扰）同样完全合法。
* **反例 2：一遇到未知就地问人（Lazy Questioning）**  
  *违规现象*：遇到某个系统函数的配置参数，代码库配置中均有说明，AI 偷懒不检索直接弹窗询问用户。  
  *违反准则*：违反“未知首先触发机器认知”原则，剥夺其 H1 资格，强制退回自主检索。
* **反例 3：所有平庸差异一律弹窗请示（Trivial Difference Interruption）**  
  *违规现象*：生成的文档比原模板多了一处格式缩进，AI 立即停工弹窗请求确认。  
  *违反准则*：违反实质差异原则。只有足以改变原判断基础的 Material Difference 才允许触发重评。
* **反例 4：把人类未回应解读为默认同意（Silence-as-Consent Usurpation）**  
  *违规现象*：发送“10秒内不按取消将自动删除生产备份”，倒计时结束后直接执行。  
  *违反准则*：严重违反 $\text{No Response} \neq \text{Consent}$。未获明确授权前，执行前沿必须严密死锁在承诺边界（E2）左侧。
* **反例 5：把用户设置“少打扰”当作扩大操作权限（Preference Exploitation）**  
  *违规现象*：用户开启了“少打扰”，AI 擅自决定跳过授权直接修改线上数据库表。  
  *违反准则*：少打扰绝不等于多授权。偏好只调节通知节奏（A 轴），绝不能放宽执行边界（E 轴）。
* **反例 6：环境变化时机械重新要全部授权（Mechanical Re-authorization）**  
  *违规现象*：持续授权明确覆盖“500元内日常采购”，某次采购因供应商缺货换了一家同款同价供应商，AI 废弃整套持续授权，重新弹窗要完整授权。  
  *违反准则*：环境发生变化时应触发适用性与 H/A/E 重新评估，若仍处于原授权 Scope/Condition/Ceiling 容差内，严禁机械重复打扰。
* **反例 7：单点受阻引发全局系统瘫痪（Cascading Freeze）**  
  *违规现象*：在生成整套后台系统的任务中，仅因一个末端报表的标题文案未获答复，AI 停止了所有数据库架构与后端逻辑代码的推进。  
  *违反准则*：违反局部阻塞原则。必须坚守“只停必须停的部分”，其余 E1 部分全速推进。
* **反例 8：以末端“确认按钮”实施免责式责任转嫁（Disclaim-by-Confirmation）**  
  *违规现象*：AI 产出一份充满技术缺陷的代码，末尾附加“请点击确认”，用户点击后系统宣称“用户已确认，一切后果由用户自行承担”。  
  *违反准则*：AI / 系统必须完整履行属于自身的认知与交付责任，不得利用 Human 的形式确认转嫁机器认知缺陷、产品缺陷或其它本应由相应主体承担的责任。

---

## 十六、七大典型工程场景推演

通过以下七大典型场景，严格证明 **H / A / E 判定维度与 Profile 类型化输出是正交而非重复的结构**：

### 场景 A：后台静默自动化维护
* **场景**：系统夜间根据明确规约对本地临时缓存进行清理，既有规则完备，测试通过，授权充分。
* **三轴判定与输出**：
  * **H 轴**：**H0（Machine Sufficient）**，无需人类语义贡献；
  * **A 轴**：**A0（Silent）**，无需占用人类注意力；
  * **E 轴**：**E0（Normal Execution）**，全速自主推进；
  * **Profile**：`none`（无需产生任何 Human Involvement）。
* **结果**：AI 自主完成闭环，全过程不惊扰人类。

### 场景 B：机器自主完成但需阶段汇报
* **场景**：AI 自主完成了 50 个单元测试的本地重构与验证，全部通过，但项目规范要求每日下班前向负责人呈报变更摘要。
* **三轴判定与输出**：
  * **H 轴**：**H0（Machine Sufficient）**，完成该任务本身无需人帮忙；
  * **A 轴**：**A1（Digest / Batch）**，延迟无损失，汇总呈报；
  * **E 轴**：**E0（Normal Execution）**，自主执行推进；
  * **Profile**：**Inform**（呈报测试与重构结果证据）。
* **实证意义**：证明 **H0 完全可以产生 Inform**，彻底破除“H0 就是什么都不能让人看”的误区。

### 场景 C：关键客观事实缺失
* **场景**：AI 根据合同草拟发票，合同中缺少客户最新线下指定的纳税人识别号，机器检索知识库无果。
* **三轴判定与输出**：
  * **H 轴**：**H1（Human Contribution Required）**，缺少关键事实；
  * **A 轴**：**A2（Timely / Natural Window）**，尚未到开票最后截止期，挂于用户自然窗口；
  * **E 轴**：**E1 / E2**，发票其余部分已排版完毕，但开票接口坚决刹车；
  * **Profile**：**Provide**（向财务知情人员索取税号事实）。
* **结果**：只等税号这一个事实，其余部分准备就绪，开票动作用合法边界锁住。

### 场景 D：多方价值与策略冲突
* **场景**：系统面临架构升级路径选择：方案 1 交付极快但留有架构债务，方案 2 极其完备但延期三天。
* **三轴判定与输出**：
  * **H 轴**：**H1（Human Contribution Required）**，涉及核心价值与目标取舍；
  * **A 轴**：**A2（Timely / Natural Window）**，在项目评审时段呈报；
  * **E 轴**：**E2（Halt at Commitment Boundary）**，推演好两套方案的比对（D1～D7），锁定在决策线前；
  * **Profile**：**Judge**（请求产品负责人进行价值裁决）。
* **结果**：AI 准备充分的决策材料，人类优雅完成价值定夺。

### 场景 E：高危现实越界动作缺乏授权
* **场景**：AI 生成了修复生产严重性能问题的 SQL 脚本，但在安全体系中，AI 没有直接在生产库执行 `DROP/ALTER TABLE` 的有效授权。
* **三轴判定与输出**：
  * **H 轴**：**H1（Human Contribution Required）**，存在行动权限缺口；
  * **A 轴**：**A2 / A3**（依据故障恶化速度评估是否即时打断）；
  * **E 轴**：**E2（Halt at Commitment Boundary）**，脚本生成与测试完毕，执行接口严密锁死；
  * **Profile**：**Authorize**（向具备 DBA 权限的 Authority Holder 请求执行授权）。
* **结果**：认知充分，行动守界，绝不越权。

### 场景 F：必须人类亲自签署/认证的现实动作
* **场景**：AI 协助准备好全部报关申请文件，但海关申报系统强制要求法定代表人插入物理加密狗并刷脸认证。
* **三轴判定与输出**：
  * **H 轴**：**H1（Human Contribution Required）**，必须自然人实施物理动作；
  * **A 轴**：**A2（Timely / Natural Window）**；
  * **E 轴**：**E2（Halt at Commitment Boundary）**，报关包密封准备完毕；
  * **Profile**：**Act**（请求法定代表人插入物理硬件并完成生物认证）。
* **结果**：AI 办妥一切前置材料，人类执行物理世界的唯一主体动作。

### 场景 G：机器遭遇法定或安全控制红线必须接管
* **场景**：AI 辅助医疗诊断系统检测到患者出现复杂的罕见并发症，且多项生理指标急剧恶化，超出了 AI 辅助软件的法定许可范围。
* **三轴判定与输出**：
  * **H 轴**：**H2（Human Takeover Required）**，系统不应继续自主主导救治路径；
  * **A 轴**：**A3（Immediate Interruption）**，生命体征危急，立即强制报警打断；
  * **E 轴**：**E3（Halt Current Path）**，停止 AI 自主策略推荐，全面封存诊断现场；
  * **Profile Set**：**Inform + Judge + Act**（即刻告警呈现病情 + 医生现场诊断定性 + 医生接管受限路径救治操作；后续如有需要医生亦可向系统 Provide 现场体征修正参数）。
* **实证意义**：证明 **H2 并非一个单一 Profile，而是控制权状态的改变，随后按需派生多个具体 Profile**。

---

## 十七、L3 → L4 Handoff Contract（交接契约）

第三层与第四层的交接遵循严格的类型化契约：

```text
┌─────────────────────────────────────────────────────────────┐
│               L3 Human Intervention Principles              │
├─────────────────────────────────────────────────────────────┤
│ 产生并向下传递类型化介入指令：                              │
│ 1. Human Necessity State (H0 / H1 / H2)                     │
│ 2. Required Profile Set (Inform / Provide / Judge / Authorize / Act)│
│ 3. Profile-specific Qualified Human / Role                  │
│ 4. Attention Bound (A0 / A1 / A2 / A3)                      │
│ 5. Execution Gate (E0 / E1 / E2 / E3)                       │
│ 6. Relevant Basis & Context (事实/价值/授权缺口/差异依据)   │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼ (类型化交接)
┌─────────────────────────────────────────────────────────────┐
│             L4 General AI Interaction Protocol              │
├─────────────────────────────────────────────────────────────┤
│ 接收指令并负责交互的正式完成与语义绑定：                    │
│ 1. Formal Interaction Semantics (正式交互语义表达)          │
│ 2. Typed Completion (类型化完成结果裁定)                    │
│ 3. Decision Context Binding (决策上下文严格绑定)            │
│ 4. Two Surfaces Separation (Conversation vs Decision 场分离)│
│ 5. Standard Choice Grammar (0–9 候选语法与澄清机制)         │
└─────────────────────────────────────────────────────────────┘
```

### 17.1 绝对分工边界
1. **L3 决定需要什么 Human role $\neq$ L4 决定什么时候需要 Human**：
   L3 全权负责判定是否需要人、何时需要人、执行前沿停在哪里；L4 绝不反向决定何时介入；
2. **L4 定义 Profile completion $\neq$ L3 定义具体交互形态**：
   L4 全权负责定义 Inform 何时算 Presented、Provide/Judge/Authorize/Act 何时算类型化完成；L3 严禁在母稿中规定任何 0–9 编号、按键、弹窗或界面实现。

---

## 十八、第三层正式封版纪律 (Freeze Discipline)

> **第三层以后原则上只接受“H/A/E 三轴正交性、最小必要介入哲学、Profile 产生条件、持续授权模型”级体系根本矛盾的修订，严禁追加任何具体按键、控件、样式与模型调度层实现。**

* 凡涉及：
  * 0–9 候选如何编号与键盘绑定；
  * 单选 / 多选协议与交互状态机；
  * 具体弹窗尺寸、界面颜色、视觉布局、UI Token；
  * Delphi / VCL / FMX 控件实现；
* **一律严格阻绝于第三层之外**，由第四层（通用 AI 交互协议）、HB 控件基础设施或 DeepBase 框架层处理。
* 只有当未来实证或工程中出现 H/A/E 三轴存在不可覆盖的关键残余、或与上游 L1/L2 发生不可调和的法源冲突时，方可经 Human Authority 批准重新打开本层母稿。

---
