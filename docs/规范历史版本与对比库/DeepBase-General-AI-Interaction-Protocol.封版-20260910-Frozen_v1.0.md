---
title: "第四层：通用 AI 交互协议 v1.0"
subtitle: "Efficient Human-AI Interaction · General AI Interaction Protocol"
Status: FROZEN v1.0
Layer: General AI Interaction Protocol (第四层：通用 AI 交互协议)
System: 高效 AI 人机交互体系 (EHAI · Efficient Human-AI Interaction)
Specification: 高效 AI 人机交互规范 (EHAI Specification)
Framework Implementation: DeepBase (用于工程化实现和承载 EHAI Specification 的 Delphi 软件框架)
Nature: 体系规范母稿 (Normative Master Specification)
Upstream:
  - 第一层《AI 人机认知哲学 v1.0》 (EHAI.01.L1-人机认知哲学.md · Frozen v1.0)
  - 第二层《AI 交付原则 v1.0》 (EHAI.02.L2-AI交付原则.md · Frozen v1.0)
  - 第三层《AI 人类介入原则 v1.0》 (EHAI.03.L3-人类介入原则.md)
Downstream:
  - 第五层《HB 人机交互承载与呈现基础设施 v1.0》
  - 第六层《机器语义与介入基础设施 v1.0》
  - 第七层《产品实现边界 v1.0》
Theory References:
  - 差异一元论 (Difference Monism)
  - ASTO.P03 《认识论：认知错误的必然性与证据化认知》
  - 和悦论（WSH）中的主体价值判断与擢助边界
Author: 架构组 / 资料员
Reviewer: 老板 / 主控 (Human Authority)
Date: 2026-09-10
Revision Note: |
  2026-09-10 Formal Convergence Calibration & Freeze (FROZEN v1.0):
    - 体系身份对齐 EHAI 规范体系；明确 DeepBase 为 Delphi 实现框架，HB 为统一人机交互承载与呈现基础设施
    - 明确唯一根问题：当 L3 产生 Human Involvement 后，怎样以最小充分、语义明确、上下文绑定的交互完成介入，而不把交互完成误当成 Reality 完成
    - 正式确立三大协议不变量：PI-1 语义承诺完整性、PI-2 最小充分交互、PI-3 上下文绑定的类型化完成
    - 统一采用五类非等级化 Human Involvement Profile：Inform, Provide, Judge, Authorize, Act
    - 明确会话场与决策场边界（Conversation Surface ≠ Decision Surface，保护 Exploration ≠ Commitment）
    - 0–9 正式降位为 Standard Choice Grammar（标准选择语法），保留 1-7/8/9/0 底层 Meta Actions
    - 确立 Decision Context 为正式响应不可脱离的绑定条件
    - 确立 [让AI学习] 为显式可选 Meta Action，严禁作为决策默认副作用
    - 划定严密层级边界：交互呈现下沉 L5 HB，现实回闭与验证下沉 L6 机器语义基础设施（Human Interaction Complete ≠ Reality Complete）
---

# 第四层：通用 AI 交互协议 v1.0
## General AI Interaction Protocol v1.0 (FROZEN v1.0)

> **体系定位说明**：  
> **EHAI（Efficient Human-AI Interaction · 高效 AI 人机交互体系）** 直属于差异一元论的高阶实践体系，其核心规范为 **EHAI Specification（高效 AI 人机交互规范）**。  
> **DeepBase** 是用于工程化实现和承载 EHAI 规范的 Delphi 软件框架。  
> **HB** 是 DeepBase 中面向 Human 的统一人机交互承载与呈现基础设施。它负责把体系中的语义、逻辑、状态、功能与交互行为，转化为人类可感知、可理解、可判断、可操作的交互。

---

## 〇、第四层在全体系中的定位与职责定界

整个高效 AI 人机交互体系（EHAI）自上而下严格遵循以下规范分层拓扑：

```text
差异一元论理论母源 (认识论依据，独立演进)
        ↓
第一层：AI 人机认知哲学 (FROZEN v1.0 · 体系哲学母源与主体性保留)
        ↓
第二层：AI 交付原则 (FROZEN v1.0 · 交付不变量与最小充分交付)
        ↓
第三层：AI 人类介入原则 (介入时机、打断门禁、静默预算、介入语义产生)
        ↓
第四层：通用 AI 交互协议 ──【本文档 FROZEN v1.0】
(最小充分、语义明确、上下文绑定的交互协议与选择语法)
        ↓
第五层：HB 统一人机交互承载与呈现基础设施
(原生桌面呈现、视觉交互组件、动态行为适配)
        ↓
第六层：机器语义与介入基础设施
(统一机器语义模型、现实重新观察、真实回闭与对账)
        ↓
第七层：产品实现边界 (PR-1～3 根不变量、领域产品绑定与符合性判定)
        ↓
[DeepBase Delphi 框架实现] ──► 业务产品消费层 (AsWish / 唤金 / 各类智能系统)
```

### 0.1 第四层回答的唯一根问题
第四层在 EHAI 体系中只回答一个唯一的根问题：

> **当 L3 已经产生 Human Involvement 后，怎样以最小充分、语义明确、上下文绑定的交互，使该 Human Involvement 被正确完成，而不把交互完成误当成 Reality 完成？**

**通俗大白话辅助理解**：
> **既然已经必须让人进来，怎样让人最省事、又不搞错意思地完成这次介入？**

### 0.2 与上游第三层（L3 人类介入原则）的职责交接
* **第三层（L3）已经全权负责决定**：
  1. 是否需要 Human 介入；
  2. Human 以什么语义介入（Involvement Type）；
  3. Human 最晚何时进入（Attention Bound / Timeout）；
  4. Human 尚未完成介入时，AI 哪些行动仍可继续、哪些边界不得跨越（Degradation / Boundary）。
* **第四层（L4）的职责定界**：
  - **L4 不再讨论“什么时候该找人”**；
  - L4 专注于 Human 被引入后，人机交互的**语义纯正性、认知低负荷、选择语法与上下文绑定**；
  - 严禁在 L4 重新推导打断门禁或介入准入条件。

---

## 一、三大协议不变量 (Three Protocol Invariants)

第四层的全部协议规则由且仅由以下三大协议不变量推导，严禁私自扩充不可约原则列表：

```text
               三大协议不变量 (Three Protocol Invariants)
┌──────────────────────────────────────────────────────────────────────────┐
│ PI-1｜Semantic Commitment Integrity —— 语义承诺完整性 (不混淆、不静默升级)│
├──────────────────────────────────────────────────────────────────────────┤
│ PI-2｜Minimal Sufficient Interaction —— 最小充分交互 (机器多想，人可改题) │
├──────────────────────────────────────────────────────────────────────────┤
│ PI-3｜Context-Bound Typed Completion —— 上下文绑定的类型化完成 (算哪件就哪件)│
└──────────────────────────────────────────────────────────────────────────┘
```

---

### PI-1｜Semantic Commitment Integrity（语义承诺完整性）
* **正式定义**：**探索、告知、补充、判断、授权和行动不得因为界面相似、语言模糊、历史行为或机器推断而被相互静默升级；凡产生正式 Human Judgment、Authorization 等 Human commitment 的语义，必须由明确的 Human commitment act 产生。**
* **核心法理**：**“聊天归聊天，拍板归拍板。”**
* **禁止语义混淆**：
  - 严禁用一个模糊的 `Confirmed = true` 吞掉 Human 响应的真实语义；
  - 自然语言对话中的附和、闲聊或探索性提问，绝不构成业务授权或不可逆判断；
* **复合语义可区分性**：一个 Human 操作可以同时产生多个正式语义（例如：`Judge(B) + Authorize(Implement B)`），但在机器语义记录中必须保持两种语义严格可拆解、可区分，不得合流为无法核验的单一事件。

---

### PI-2｜Minimal Sufficient Interaction（最小充分交互）
* **正式定义**：**AI 应承担可以由机器承担的候选生成、信息整理、比较、结构化和解释劳动，使 Human 只承担当前介入语义中真正不可替代的最小充分部分；同时不得强迫 Human 接受机器当前给出的候选集合或问题框架。**
* **核心法理**：**“机器多想，人少填；机器想歪了，人可以改题。”**
* **分工底线**：
  - 坚持 `Machine prepares, Human resolves`（机器筹备，人类定夺）；
  - AI 必须把问题收敛到真正属于人类主权决策的最小核心，禁止倾倒原始中间半成品强迫人类当苦力；
* **拒绝框架绑架（Frame Escape / Reframe）**：
  - 绝不得将最小交互扭曲为“人类只能在 AI 预设候选中做选择题”；
  - 协议必须为人类保留完整的逃逸与改题通道（Frame Escape），人类享有质疑前提、重定义框架与自定义输入的法定权利。

---

### PI-3｜Context-Bound Typed Completion（上下文绑定的类型化完成）
* **正式定义**：**每一种 Human Involvement 必须按其自身语义、对象和上下文定义明确完成条件；其 Human response 必须绑定于明确、可观察的对象、上下文和响应类型。一种交互类型的完成不得被静默升级为另一种 Human commitment，也不得自动升级为未经证据支持的 Reality completion。**
* **核心法理**：**“人完成的是哪件事，就只算哪件事。”**
* **抗漂移铁律（Anti-Drift）**：
  $$\text{Authorization}(\text{Object}_{v1}) \neq \text{Authorization}(\text{Object}_{v2})$$
  只要交互对象、生效范围、关键参数、预期效果或决策上下文（Decision Context）的演变足以改变原响应的业务语义，旧的 Human 响应不得静默漂移到新对象上，必须触发显式重新确认。

---

## 二、通用交互内核 (Common Interaction Kernel)

L4 不为各类交互创造割裂的协议栈，而是统一运行在通用的内核之上：

```text
┌──────────────────────────────────────────────────────────────────────────┐
│ Step 1：Involvement Request 接收与语义解析 (绑定 L3 传入的 Profile 与 Context)│
├──────────────────────────────────────────────────────────────────────────┤
│ Step 2：场域准备与候选生成 (依据 Minimal Sufficient Interaction 预制选择/表单)│
├──────────────────────────────────────────────────────────────────────────┤
│ Step 3：响应捕获与语义类型校验 (区分 Choose / Regenerate / Reframe / Exit)│
├──────────────────────────────────────────────────────────────────────────┤
│ Step 4：决策上下文密封存证 (Decision Context Binding，生成不可变记录)    │
├──────────────────────────────────────────────────────────────────────────┤
│ Step 5：下游语义移交 (向 L6 移交类型化语义事件，绝不自行断言现实完成)    │
└──────────────────────────────────────────────────────────────────────────┘
```

### 核心铁律：Human Interaction Complete ≠ Reality Complete
* **法理确立**：**人类在界面上完成了交互响应，绝不等于物理世界或业务系统的真实事务已经完成。**
* **通俗本质**：**“人回答完了，不等于事情真的办成了。”**
* **边界划分**：
  - **L4 管**：Human 到底被告知了什么、提供了什么、判断了什么、授权了什么、报告或实施了什么；
  - **L6 管**：机器状态与现实世界因此实际发生了什么、是否被重新观察、是否与预期一致（Re-observation & Reconciliation）。

---

## 三、五种人类介入形态规范 (Human Involvement Profiles)

统一使用 L3 冻结的五类 Human Involvement Type。**它们绝非强弱等级，而是平等的语义角色（Semantic Roles），可正交组合。**

```text
┌───────────────┬───────────────────────────────────┬────────────────────────────────────────┐
│ Profile       │ 核心语义与定位                    │ 正式完成标准 (Completion Invariant)    │
├───────────────┼───────────────────────────────────┼────────────────────────────────────────┤
│ 1. Inform     │ 告知：单向信息披露与风险通报      │ 充分呈现且人可观察；知悉不等于赞同     │
├───────────────┼───────────────────────────────────┼────────────────────────────────────────┤
│ 2. Provide    │ 补充：提供事实、偏好、约束或参数  │ 关键数据已填报绑定；提供不等于事实真确 │
├───────────────┼───────────────────────────────────┼────────────────────────────────────────┤
│ 3. Judge      │ 判断：价值排序、方案择优、真伪裁决│ 针对明确对象完成显式定夺；判断非真理   │
├───────────────┼───────────────────────────────────┼────────────────────────────────────────┤
│ 4. Authorize  │ 授权：跨越控制权与责任边界的许可  │ 具备主体资格者针对明确动作与范围显式授权│
├───────────────┼───────────────────────────────────┼────────────────────────────────────────┤
│ 5. Act        │ 行动：必须由人本人实施的现实动作  │ 现实操作事件已捕获/上报；操作非达成    │
└───────────────┴───────────────────────────────────┴────────────────────────────────────────┘
```

### 3.1 Inform Profile（告知）
* **完成语义界定**：Inform 完成绝不能定义为“Human 已理解”（机器无法证明人类内部心智状态）。
* **正式完成标准**：**系统已经按照上游 Attention Bound，以合格、充分且 Human 可观察的方式履行了告知义务。**
* **严格区分告知四阶**：
  $$\text{Available} \to \text{Presented} \to \text{Acknowledged} \to \text{Agreed}$$
  - `Available`（可用）：信息已就绪放入通知中心，等待人类查阅；
  - `Presented`（已呈现）：信息已按注意力量级在人类主界面完整显影；
  - `Acknowledged`（已知悉）：人类产生了显式已读/回执动作（如点击“已知悉”）；
  - `Agreed`（已赞同）：人类对告知内容表示认可。
* **铁律**：`Acknowledgement ≠ Judgment` 且 `Acknowledgement ≠ Authorization`。已读回执绝不构成同意或授权，不得将 Acknowledge 滥立为根类型。

### 3.2 Provide Profile（补充）
* **完成条件**：Human 已经提供当前任务明确要求的事实、现场上下文、意图、约束、参数或特定输入，并正确绑定到当前 Context。
* **边界铁律**：
  $$\text{Human Provided } X \neq X \text{ Objectively Verified}$$
  L4 仅负责记录“人类提供了什么数据”，绝不自动将人类提供的信息等同于已经过客观验证的现实真理。验证真实性属于下游证据链闭环。

### 3.3 Judge Profile（判断）
* **完成条件**：Human 已针对当前明确可观察的对象，在特定决策上下文中产生了一个显式的 Human Judgment。
* **边界铁律**：
  $$\text{AI Recommendation} \neq \text{Human Judgment}$$
  $$\text{Human Judgment} \neq \text{Objective Truth}$$
* **可修订性**：人类享有对既定判断的推翻与修订权。当现实世界涌现新的 Evidence、Difference 或执行异常时，既有 Judgment 可以被合法重新打开。

### 3.4 Authorize Profile（授权）
* **完成条件（比 Judge 更严苛）**：**合格的 Authority Holder 已经针对明确的对象、动作、范围和当前上下文，显式产生了 Authorization。**
* **四大可辨认要素**：Human 在授权界面必须能清晰辨认：
  1. **What**：目标对象与系统范围是什么；
  2. **Action**：即将由系统执行的具体动作是什么；
  3. **Scope**：影响边界与权限额度；
  4. **Relevant Effect**：预期结果与潜在破坏性后果。
* **绑定要求**：Authorization 必须固化绑定 `[Object, Action, Scope, Context, Authority Holder]`。
* **边界铁律**：
  $$\text{Recommendation} \neq \text{Authorization} \neq \text{Execution}$$
  AI 可以给出建议，但 AI 建议绝不能自封为授权，授权动作也绝不能被等同于执行完成。

### 3.5 Act Profile（行动）
* **范畴**：必须由 Human 本人亲自完成的现实或高敏动作（如物理按键操作、生物特征认证、手写签名、带外安全验证等）。
* **完成条件**：L4 仅确认并记录 **Human interaction / Human attestation / Human action report 已经发生**。
* **边界铁律**：
  $$\text{Human says "Done"} \neq \text{Act Observed} \neq \text{Desired Effect Achieved}$$
  人类汇报“已完成”不等于动作已被物理观测，动作被观测也不等于预期效果已经达成。最终的现实回闭校验严格交由 L6 负责。

### 3.6 Profile 的复合调用
五种 Profile 允许并支持复合调用（例如：`Provide + Judge`、`Judge + Authorize`、`Authorize + Act`），但在数据结构与交互记录中必须保持清晰的多态标识，严禁复合时丢失各自独立的不变量约束。

---

## 四、会话场与决策场边界 (Conversation vs Decision Surface)

L4 正式确立两场分离原则，两场不是界面 UI 样式的互斥，而是**法律与语义效力的严格隔离**：

```text
┌─────────────────────────────────────────────────────────────┐
│                 Exploration ≠ Commitment                    │
│               (探索不等于承诺 · 聊天不等于拍板)             │
└─────────────────────────────────────────────────────────────┘
```

### 4.1 会话场（Conversation Surface）
* **核心定位**：主要承载探索、发散、讨论、追问、重新理解、概念澄清与框架修正等**非承诺性交互（Non-committing Interaction）**；
* **语义保护门禁**：在会话场中人类所说的任何自然语言（例如“我觉得挺好”、“听起来不错”、“可以试试”），**严禁被 AI 算法私自解析并静默升级为正式的 Human Judgment 或 Authorization**。

### 4.2 决策场（Decision Surface）
* **核心定位**：能够产生**正式、类型化 Human semantic commitment** 的受约束交互环境；
* **关键特征**：不在于界面是否有固定按钮，而在于**Human 明确知晓当前操作正在产生具有法律或工程效力的正式 Semantic Object**；
* **进入门禁**：
  - Human 可以主动要求进入决策场（如“请列出方案供我审批”）；
  - AI 在触发 L3 介入时，可以提示“当前步骤需要您的正式判断/授权”并调起决策场；
  - 严禁将自然语言对话偷渡为决策场结果。

---

## 五、标准选择语法 (Standard Choice Grammar)

0–9 数字协议在 L4 中**正式降位为：标准选择语法（Standard Choice Grammar）**。它不是 L4 的根原则，而是基于 PI-2 最小充分交互推导出的高效人机输入语法。

```text
               标准选择语法底层 Meta Actions 映射矩阵
┌───────┬──────────────────────────┬────────────────────────────────────────┐
│ 按键  │ 底层 Meta Action         │ 正式语义与边界约束                     │
├───────┼──────────────────────────┼────────────────────────────────────────┤
│ 1–7   │ Choose (候选选择)        │ 快速指针引用；不自带盲目授权           │
├───────┼──────────────────────────┼────────────────────────────────────────┤
│ 8     │ Regenerate (候选重构)    │ 框架成立但候选欠佳；8 ≠ Human Judgment │
├───────┼──────────────────────────┼────────────────────────────────────────┤
│ 9     │ Reframe (跳出框架/改题)  │ 拒绝候选空间，自定义输入；9 ≠ Reject   │
├───────┼──────────────────────────┼────────────────────────────────────────┤
│ 0     │ Exit (无承诺退出)        │ 放弃交互或后退；0 ≠ Reject / Consent   │
└───────┴──────────────────────────┴────────────────────────────────────────┘
```

### 5.1 `1–7`｜Choose（候选选择）
* **核心功能**：对当前决策场中明确编号的 Candidate 进行直接指针引用；
* **上限控制**：最多展示 7 个具有实质差异的候选（严禁为凑数生造无意义选项）；
* **推荐位置**：1 号候选可放置 AI 建议倾向，但仅代表参考倾向，不是默认选择；
* **铁律**：**选择 1–7 仅表示选中该项方案，不代表自动签署授权或产生现实行动。**

### 5.2 `8`｜Regenerate（候选重构）
* **核心功能**：Human 认可当前问题定义（Frame 成立），但判定当前给出的候选集质量低下、切角偏差或缺乏可行性；
* **系统行为**：AI 在既有框架下重新检索、推理，生成全新候选集交付；
* **铁律**：$$8 \neq \text{Human Judgment}$$（8 是对生成物质量的反馈，不属于业务判断）。

### 5.3 `9`｜Reframe / Human Input（跳出框架与自定义输入）
* **核心功能**：**人类享有拒绝 AI 预设候选空间、提出新候选或重定义问题框架（Frame Escape）的终极主权**；
* **实质含义**：按下 9 表示人类退出当前选择题，后续可输入全新参数、反驳前置假设或重构目标；
* **铁律**：$$9 \neq \text{Reject}$$（9 是重构题目的开端，并不等于业务上的完全否定）。

### 5.4 `0`｜Exit without Commitment（无承诺退出）
* **核心功能**：人类选择中止本次交互、后退或搁置任务；
* **铁律**：
  $$0 \neq \text{Reject} \quad\text{且}\quad 0 \neq \text{Consent} \quad\text{且}\quad 0 \neq \text{Judgment}$$
  0 是交互动作的中止，绝不代表投赞成票，也绝不代表投反对票，系统不得借由 0 制造出虚假的业务结论。

### 5.5 Decision Cardinality 参数（单选 vs 多选）
单选与多选不是新原则，而是当前决策场的 **Cardinality 参数**：
* **Single-choice**：`Choose` 操作仅允许选中一个有效 Candidate；
* **Multi-choice**：`Choose` 操作允许同时选中多个相互兼容的 Candidate（如 `[1, 3]`）；
* AI 必须在题面显式声明当前是单选还是多选，不得模棱两可。

---

## 六、决策上下文绑定 (Decision Context Binding)

任何正式的 Human commitment（Judge, Authorize, Act 等）**绝不得以孤立数据孤悬存储**，必须与不可篡改的 Decision Context 强行绑定，以防止事后语义漂移与责任篡改。

### 6.1 绑定的最小必要语义要素
一个合格的决策上下文快照至少能够完整恢复以下事实：
1. **Request**：当时向人类发起的提问、陈述与意图请求；
2. **Observable Object**：当时呈现给人类审查的具体对象与材料；
3. **Key Context & Difference**：做决定时所依赖的关键背景与差异比对；
4. **Candidate Set**：当时呈现的候选选项（含各自影响描述）；
5. **Human Response & Type**：人类具体的响应操作及其绑定的语义类型；
6. **Temporal & Identity Stamp**：操作发生的时间戳与操作者身份标识。

### 6.2 职责定界
L4 仅在法理上确立“响应必须绑定上下文且不得脱离上下文漂移”；其具体的数据持久化结构、防篡改签名与数据库实现由 **L6 机器语义基础设施** 承担。

---

## 七、可选元动作规范：`[让AI学习]` (Optional Meta Action)

为了平衡交互效率与人类偏好适应，系统提供 `[让AI学习]` 机制，但必须对其设立极高的宪法级防火墙：

```text
┌─────────────────────────────────────────────────────────────┐
│                 Decision ≠ Learn from Decision              │
│                (单次决策 不等于 永久价值偏好)               │
└─────────────────────────────────────────────────────────────┘
```

### 7.1 显式与可选原则
* **绝非默认副作用**：**`[让AI学习]` 绝不得作为人类确认或决策的默认勾选项或静默副作用**；
* **明确授权**：只有当 Human 显式触发该 Meta Action 时，本次交互数据才被允许作为模型参数微调、提示词优化或场景记忆的训练样本；
* **上游铁律**：$$\text{Repeated Choice} \neq \text{Permanent Preference}$$
  人类在特定场景下的连续重复选择，只代表当前环境下的权衡，绝不自动等于永久放弃未来选择权。

---

## 八、派生铁律与语义区隔集合 (Derived Invariants & Semantic Separations)

在系统实现与行为审计中，必须严格恪守以下十大派生铁律，任何违反均判定为协议级严重 Bug：

```text
1.  Exploration           ≠  Commitment
    (探索讨论 不等于 形成承诺)

2.  Available             ≠  Presented
    (放入通知 不等于 已经呈现)

3.  Presented             ≠  Acknowledged
    (已经呈现 不等于 人类知悉)

4.  Acknowledged          ≠  Agreed
    (人类知悉 不等于 人类赞同)

5.  Provided              ≠  Verified
    (人类提供 不等于 事实真确)

6.  Judged                ≠  Authorized
    (主权判断 不等于 授权执行)

7.  Authorized            ≠  Executed
    (业务授权 不等于 现实执行)

8.  Human Reported Done   ≠  Reality Verified
    (人类报完 不等于 现实回闭)

9.  Decision              ≠  Learning
    (完成决断 不等于 建立偏好)

10. 8 ≠ Judgment   /   9 ≠ Reject   /   0 ≠ Reject, Consent, Judgment
    (重构非判断 / 改题非拒绝 / 退出非赞同也非反对)
```

---

## 九、层级边界与显式非目标 (Downstream Handoff & Non-Goals)

第四层严格坚守“人机交互语义与选择语法”的职责边界，绝不越权吸收上下游实现细节：

```text
[L3 人类介入原则]
决定何时介入、介入类型与注意力量级
    │
    │ 移交：判定需要找人后，交互语义如何规范、选择如何完成？
    ↓
[L4 通用 AI 交互协议] ── 本规范
定义 PI-1～3 不变量、五种 Profile、两场分离、0–9 标准选择语法、Decision Context 绑定
    │
    │ 移交：交互语义如何在原生桌面、控件、卡片与输入设备中完美呈现？
    ↓
[L5 HB 基础设施]
定义卡片布局、按钮尺寸、颜色动效、键盘鼠标等价映射、Toast/Popup 动态行为适配
    │
    │ 移交：人回答完成后，机器底层如何解析状态、执行动作并对账现实？
    ↓
[L6 机器语义基础设施]
定义 Assertion/Slice 数据结构、语义存储、现实重新观察、真实回闭与对账校验
```

### 显式非目标清单（禁止重新升格为 L4 根规范的细项）：
* **严禁包含 HB 界面细节**：像素、内边距、外边距、主题调色、弹窗形式、控件类层次；
* **严禁包含物理输入绑定**：鼠标点击、键盘扫描码、手势识别算法（统一下沉 L5 抽象）；
* **严禁包含数据库与存储结构**：JSON Schema、SQL 表定义、数据迁移脚本（统一下沉 L6 抽象）；
* **严禁发明新的根原则**：诸如“Acknowledge Principle”、“Mouse Principle”、“Reality Principle”等细项均属派生，绝不得升格为第四条协议不变量。

---

## 十、文档封版与修订纪律

1. **正式审定状态**：本规范经 Human Authority 于 2026-09-10 正式终审通过，正式标记并冻结为 **`FROZEN v1.0`**；
2. **冻结边界保护**：冻结后，不得因为具体产品交互习惯、前端样式排版或底层数据库设计困难而反向修改 L4；
3. **允许重新开启 Review 的严苛条件**：
   - 只有当出现以下五类重大事实之一时，方允许重新开启 L4 规范审议：
     1. L4 内部出现不可消解的逻辑冲突或规范矛盾；
     2. L3 上游介入理论发生重大重写或类型颠覆；
     3. 实践证据证明三大协议不变量（PI-1 / PI-2 / PI-3）存在无法覆盖的重大死角；
     4. 五种 Human Involvement Profile 无法容纳关键的人机交互形态；
     5. 现实世界人机交互基本前提发生颠覆性质变。
