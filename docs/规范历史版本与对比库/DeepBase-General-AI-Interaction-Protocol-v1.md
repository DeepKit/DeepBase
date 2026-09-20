---
title: "第四层：通用 AI 交互协议 v1.0"
subtitle: "Efficient Human-AI Interaction · General AI Interaction Protocol"
Status: SUPERSEDED / Historical Source
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
  - L5｜HB Human-facing realization / 承载与呈现相关规范（正式名称待 L5 审议）
  - 第六层《机器语义与介入基础设施 v1.0》
  - 第七层《产品实现边界 v1.0》
Theory References:
  - 差异一元论 (Difference Monism) 为重要理论来源之一（完整谱系法定定位另议）
  - ASTO.P03 《认识论：认知错误的必然性与证据化认知》
  - 和悦论（WSH）中的主体价值判断与擢助边界
Author: 架构组 / 资料员
Reviewer: 老板 / 主控 (Human Authority)
Date: 2026-09-10
Revision Note: |
  2026-09-10 Pre-Freeze Final Calibration (FREEZE CANDIDATE v1.0):
    - 状态调整为 FREEZE CANDIDATE v1.0，等待 Human Authority 最终封版裁定
    - 理论定位校准：差异一元论（Difference Monism）为 EHAI 重要理论来源之一，最终谱系法定定位另议
    - L3 输入术语统一校准为：Human Involvement、Attention Bound、Execution Gate，清理旧术语
    - L5 名称去提前冻结：统一表达为“L5｜HB Human-facing realization / 承载与呈现相关规范（正式名称待 L5 审议）”
    - Common Interaction Kernel 由固定流程重构为“按 Profile 与 Context 适用的共同协议职责与能力”，明确 Inform/Act 不强制生成候选集
    - 修正 Inform 语义：四阶状态为必须严格区分的语义状态（非必经阶段），明确 Agreed 非必然终态且已超出单纯 Inform
    - 修正 Standard Choice Grammar：1–7 Choose 本身只是一种候选指针与选择语法，其正式语义由 Profile + Context 决定；Choose 8 校准为“本次不重构 Frame 而要求重新生成候选”，不构成对 Frame 的正式 Judgment
    - 修正 Decision Context：L4 聚焦 recoverable + traceable + context-bound，防篡改下沉 L6，各要素按适用性表达（无候选不造候选集，无响应不造假响应）
    - 修正 [让AI学习]：仅定义为显式可选 Meta Action，删除微调/提示词/记忆等具体学习机制，长期学习下沉
    - 彻底清除实现层偷渡：删除具体数据结构名与伪法律措辞（改为规范效力、正式语义效力、协议保障、严格语义边界），Judge 聚焦价值排序、目标取舍、方案选择与接受性判断
---

> [!WARNING]
> ### 本文件已被正式废止并归档为历史源码 (SUPERSEDED / Historical Source)
> 
> **正式唯一规范母稿（Canonical Master Specification）已经确立并正式冻结为 FROZEN v1.0：**  
> 指针路径：[`EHAI.04.L4-通用交互协议.md`](file:///D:/_Progs/一元论/90-跨层组合/高效AI人机交互体系-EHAI/EHAI.04.L4-通用交互协议.md)
> 
> 根据 EHAI 文档治理与单一真相源（SSOT）纪律：
> 1. 本文件不再作为并列 SSOT 或独立规范母稿维护；
> 2. 本文件保留仅供历史追溯与审计比对，禁止向本文件提交新的规范修改；
> 3. 以后所有规范引用、工程实现、技术审阅与下游文档（L5/L6/L7），均一律严格引用正式母稿 `EHAI.04.L4-通用交互协议.md`。

---

# 第四层：通用 AI 交互协议 v1.0
## General AI Interaction Protocol v1.0 (FREEZE CANDIDATE v1.0)

> **体系定位说明**：  
> **EHAI（Efficient Human-AI Interaction · 高效 AI 人机交互体系）** 致力于定义 AI 与 Human 高效协同的核心原则、交互规则、机器语义和产品实现边界。其正式规范表达为 **EHAI Specification（高效 AI 人机交互规范）**。差异一元论（Difference Monism）是 EHAI 的重要理论来源之一；EHAI 在差异一元论完整理论谱系中的最终法定定位另议。  
> **DeepBase** 是用于工程化实现和承载 EHAI Specification 的 Delphi 软件框架。  
> **HB** 是 DeepBase 中面向 Human 的交互承载组件群与实现设施，具体规范由下游 L5 专项承接。

---

## 〇、第四层在全体系中的定位与职责定界

整个高效 AI 人机交互体系（EHAI）自上而下严格遵循以下规范分层拓扑：

```text
差异一元论理论母源 (重要理论来源之一，独立演进)
        ↓
第一层：AI 人机认知哲学 (Frozen v1.0 · 体系哲学母源与主体性保留)
        ↓
第二层：AI 交付原则 (Frozen v1.0 · 交付不变量与最小充分交付)
        ↓
第三层：AI 人类介入原则 (产生 Human Involvement、Attention Bound 与 Execution Gate)
        ↓
第四层：通用 AI 交互协议 ──【本文档 FREEZE CANDIDATE v1.0】
(最小充分、语义明确、上下文绑定的交互协议与选择语法)
        ↓
L5｜HB Human-facing realization / 承载与呈现相关规范（正式名称待 L5 审议）
(原生桌面呈现、视觉交互组件、动态行为适配)
        ↓
第六层：机器语义与介入基础设施
(统一机器语义表示、状态/介入生命周期、现实重新观察、真实回闭与对账)
        ↓
第七层：产品实现边界 (PR-1～3 根不变量、领域产品绑定与符合性判定)
        ↓
[DeepBase Delphi 框架实现] ──► 业务产品消费层 (AsWish / 唤金 / 各类系统)
```

### 0.1 第四层回答的唯一根问题
第四层在 EHAI 体系中只回答一个唯一的根问题：

> **当 L3 已经产生 Human Involvement 后，怎样以最小充分、语义明确、上下文绑定的交互，使该 Human Involvement 被正确完成，而不把交互完成误当成 Reality 完成？**

**通俗大白话辅助理解**：
> **既然已经必须让人进来，怎样让人最省事、又不搞错意思地完成这次介入？**

### 0.2 与上游第三层（L3 人类介入原则）的职责交接
* **第三层（L3）已经全权负责决定**：
  1. 是否需要 Human 介入并产生 **`Human Involvement`**；
  2. Human 以什么语义角色介入（Involvement Type：Inform / Provide / Judge / Authorize / Act）；
  3. 介入的时限与注意力量级边界（**`Attention Bound`**）；
  4. 尚未完成介入时的执行门禁与动作边界（**`Execution Gate`**）。
* **第四层（L4）的职责定界**：
  - **L4 不再讨论“什么时候该找人”**；
  - L4 专注于 Human 被引入后，人机交互的**语义承诺完整性、认知低负荷、选择语法与上下文绑定**；
  - 严禁在 L4 重新推导介入准入条件。

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
* **核心意涵**：**“聊天归聊天，拍板归拍板。”**
* **禁止语义混淆**：
  - 严禁用一个模糊的 `Confirmed = true` 吞掉 Human 响应的真实语义；
  - 自然语言对话中的附和、闲聊或探索性提问，绝不构成业务授权或正式承诺；
* **复合语义可区分性**：一个 Human 操作可以同时产生多个正式语义（例如：`Judge(B) + Authorize(Implement B)`），但在语义记录中必须保持各 Profile 严格可拆解、可区分，不得合流为无法核验的单一事件。

---

### PI-2｜Minimal Sufficient Interaction（最小充分交互）
* **正式定义**：**AI 应承担可以由机器承担的候选生成、信息整理、比较、结构化和解释劳动，使 Human 只承担当前介入语义中真正不可替代的最小充分部分；同时不得强迫 Human 接受机器当前给出的候选集合或问题框架。**
* **核心意涵**：**“机器多想，人少填；机器想歪了，人可以改题。”**
* **分工底线**：
  - 坚持 `Machine prepares, Human resolves`（机器筹备，人类定夺）；
  - AI 必须把问题收敛到真正属于人类决策的最小核心，禁止倾倒原始中间半成品强迫人类承担机械整理工作；
* **协议保障框架逃逸（Frame Escape / Reframe）**：
  - 绝不得将最小交互扭曲为“人类只能在 AI 预设候选中做选择题”；
  - 协议必须为人类保留完整的逃逸与改题通道（Frame Escape），人类享有质疑前提、重定义框架与自定义输入的协议保障通道。

---

### PI-3｜Context-Bound Typed Completion（上下文绑定的类型化完成）
* **正式定义**：**每一种 Human Involvement 必须按其自身语义、对象和上下文定义明确完成条件；其 Human response 必须绑定于明确、可观察的对象、上下文和响应类型。一种交互类型的完成不得被静默升级为另一种 Human commitment，也不得自动升级为未经证据支持的 Reality completion。**
* **核心意涵**：**“人完成的是哪件事，就只算哪件事。”**
* **抗漂移原则（Anti-Drift）**：
  $$\text{Authorization}(\text{Object}_{v1}) \neq \text{Authorization}(\text{Object}_{v2})$$
  只要交互对象、生效范围、关键参数、预期效果或决策上下文（Decision Context）的演变足以改变原响应的业务语义，旧的 Human 响应不得静默漂移到新对象上，必须触发显式重新确认。

---

## 二、通用交互内核 (Common Interaction Kernel)

Common Interaction Kernel 是一组面向各类 Human Involvement 的**共同协议职责与能力集合**，而非机械的一刀切固定流水线。各项职责根据当前介入 Profile 与 Context 按需适用，不要求固定顺序全部执行：

```text
               Common Interaction Kernel 共同协议职责集合
┌──────────────────────────────────────────────────────────────────────────┐
│ 职责 1：Involvement Request 接收与语义解析 (绑定 L3 的 Profile 与 Context)│
├──────────────────────────────────────────────────────────────────────────┤
│ 职责 2：场域与交互素材准备 (按需提供材料；非选择型介入绝不强造候选集)     │
├──────────────────────────────────────────────────────────────────────────┤
│ 职责 3：响应捕获与语义类型校验 (校验输入有效性，捕获 Choose/Reframe 等动作)│
├──────────────────────────────────────────────────────────────────────────┤
│ 职责 4：决策上下文绑定 (可恢复、可追溯地固化当时交互依据，防止语义漂移) │
├──────────────────────────────────────────────────────────────────────────┤
│ 职责 5：下游语义移交 (向 L6 移交类型化语义事件，绝不自行断言现实完成)    │
└──────────────────────────────────────────────────────────────────────────┘
```

* **按需调用规则**：
  - 各职责按当前介入类型动态适用；
  - **Inform（告知）、Act（行动）等 Profile 绝不得被强制经过“候选生成”**；
  - 简单告知仅需履行呈现与可选回执记录，无需强行走完完整裁决流程。

### 核心铁律：Human Interaction Complete ≠ Reality Complete
* **核心原则**：**人类在界面上完成了交互响应，绝不等于物理世界或业务系统的真实事务已经完成。**
* **通俗本质**：**“人回答完了，不等于事情真的办成了。”**
* **严格边界**：
  - **L4 管**：Human 到底被告知了什么、提供了什么、判断了什么、授权了什么、报告或实施了什么；
  - **L6 管**：机器状态与现实世界因此实际发生了什么、是否被重新观察、是否与预期一致（Reality re-observation & reconciliation）。

---

## 三、五种人类介入形态规范 (Human Involvement Profiles)

统一使用 L3 冻结的五类 Human Involvement Type。**它们绝非强弱等级，而是平等的语义角色（Semantic Roles），可正交组合。**

```text
┌───────────────┬───────────────────────────────────┬────────────────────────────────────────┐
│ Profile       │ 核心语义与定位                    │ 正式完成标准 (Completion Invariant)    │
├───────────────┼───────────────────────────────────┼────────────────────────────────────────┤
│ 1. Inform     │ 告知：单向信息披露与状态通报      │ 充分呈现且人可观察；知悉不等于赞同     │
├───────────────┼───────────────────────────────────┼────────────────────────────────────────┤
│ 2. Provide    │ 补充：提供事实、偏好、约束或参数  │ 关键数据已填报绑定；提供不等于事实真确 │
├───────────────┼───────────────────────────────────┼────────────────────────────────────────┤
│ 3. Judge      │ 判断：价值排序、目标取舍、方案选择│ 针对明确对象完成显式定夺；判断非客观真理│
├───────────────┼───────────────────────────────────┼────────────────────────────────────────┤
│ 4. Authorize  │ 授权：跨越控制权与责任边界的许可  │ 具备资格者针对明确动作与范围显式授权   │
├───────────────┼───────────────────────────────────┼────────────────────────────────────────┤
│ 5. Act        │ 行动：必须由人本人实施的现实动作  │ 现实操作事件已记录/上报；操作非达成    │
└───────────────┴───────────────────────────────────┴────────────────────────────────────────┘
```

### 3.1 Inform Profile（告知）
* **完成语义界定**：Inform 完成绝不能定义为“Human 已理解”（机器无法证明人类内部心智状态）。
* **正式完成标准**：**系统已经按照上游 Attention Bound，以合格、充分且 Human 可观察的方式履行了告知义务。**
* **严格区分四种独立的语义状态（非必经阶段）**：
  ```text
  Available ≠ Presented
  Presented ≠ Acknowledged
  Acknowledged ≠ Agreed
  ```
  - `Available`（可用）：信息已就绪放置于待办/通知区，等待人类在需要时查阅；
  - `Presented`（已呈现）：信息已按注意力量级在人类主界面/工作流中有效显影展示；
  - `Acknowledged`（已知悉）：人类产生了显式已读/知悉回执动作（如点击“已知悉”）；
  - `Agreed`（已赞同）：人类对告知内容表示实质认可。
* **语义边界**：
  - `Agreed` 绝不是 Inform 的必然终态（Inform 仅要求履行告知）；
  - 若业务进一步要求人类表示赞同，其实质已超出单纯告知范畴，可能引入了 Judge（判断认可）或 Authorize（许可确认）等新的正式语义；
  - `Acknowledgement ≠ Judgment` 且 `Acknowledgement ≠ Authorization`。已读回执绝不构成同意或授权，不得将 Acknowledge 滥立为根类型。

### 3.2 Provide Profile（补充）
* **完成条件**：Human 已经提供当前任务明确要求的事实、现场上下文、意图、约束、参数或特定输入，并正确绑定到当前 Context。
* **边界铁律**：
  $$\text{Human Provided } X \neq X \text{ Objectively Verified}$$
  L4 仅负责记录“人类提供了什么数据”，绝不自动将人类提供的信息等同于已经过客观验证的现实真理。验证真实性属于下游证据链闭环。

### 3.3 Judge Profile（判断）
* **完成条件**：Human 已针对当前明确可观察的对象，在特定决策上下文中产生了一个显式的 Human Judgment（如价值排序、目标取舍、方案选择、接受性判断等）。
* **边界铁律**：
  $$\text{AI Recommendation} \neq \text{Human Judgment}$$
  $$\text{Human Judgment} \neq \text{Objective Truth}$$
* **可修订性**：人类享有对既定判断的修订通道。当现实世界涌现新的证据、差异或执行异常时，既有 Judgment 可以被合理重新打开。

### 3.4 Authorize Profile（授权）
* **完成条件（比 Judge 更严苛）**：**合格的主体资格承担者（Authority Holder）已经针对明确的对象、动作、范围和当前上下文，显式产生了 Authorization。**
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
* **范畴**：必须由 Human 本人亲自完成的现实动作（如物理按键操作、生物特征核验、外部设备物理动作等）。
* **完成条件**：L4 仅确认并记录 **Human interaction / Human attestation / Human action report 已经发生**。
* **边界铁律**：
  $$\text{Human says "Done"} \neq \text{Act Observed} \neq \text{Desired Effect Achieved}$$
  人类汇报“已完成”不等于动作已被物理观测，动作被观测也不等于预期效果已经达成。最终的现实回闭校验严格交由 L6 负责。

### 3.6 Profile 的复合调用
五种 Profile 允许并支持复合调用（例如：`Provide + Judge`、`Judge + Authorize`、`Authorize + Act`），但在语义记录中必须保持各 Profile 严格可区分，严禁复合时丢失各自独立的不变量约束。

---

## 四、会话场与决策场边界 (Conversation vs Decision Surface)

L4 正式确立两场分离原则，两场不是界面 UI 样式的互斥，而是**正式语义效力与交互约束的严格隔离**：

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
* **关键特征**：不在于界面是否有固定按钮，而在于**Human 明确知晓当前操作正在产生具有规范效力的正式 Semantic Object**；
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
│ 1–7   │ Choose (候选选择语法)    │ 指针引用语法；其业务语义由 Profile 决定 │
├───────┼──────────────────────────┼────────────────────────────────────────┤
│ 8     │ Regenerate (候选重构)    │ 本次不改 Frame 但重造候选；8 ≠ Judgment│
├───────┼──────────────────────────┼────────────────────────────────────────┤
│ 9     │ Reframe (跳出框架/改题)  │ 拒绝候选空间，自定义输入；9 ≠ Reject   │
├───────┼──────────────────────────┼────────────────────────────────────────┤
│ 0     │ Exit (无承诺退出)        │ 放弃交互或后退；0 ≠ Reject / Consent   │
└───────┴──────────────────────────┴────────────────────────────────────────┘
```

### 5.1 `1–7`｜Choose（候选指针与选择语法）
* **核心功能**：对当前场域中明确编号的 Candidate 进行直接指针引用；
* **语义派生机制**：
  - `1–7 Choose` 本身只是一种候选指针与选择语法；
  - 它最终形成 Provide（提供参数）、Judge（方案裁决）、Authorize（行动授权）或其它何种正式语义，**必须由当前 `Human Involvement Profile + Decision Context` 严格决定**；
* **铁律约束**：
  $$\text{Choose} \neq \text{inherently Judge}$$
  $$\text{Choose} \neq \text{inherently Authorize}$$
  $$\text{Choose} \neq \text{Execution}$$
  在明确绑定 Judge 或 Authorize Profile 的 Decision Surface 中，Choose 可以成为产生相应正式 Human act 的承载语法；但在未声明绑定的上下文中，Choose 不自带任何越权承诺；
* **上限控制**：最多展示 7 个具有实质差异的候选（严禁为凑数生造无意义选项）；1 号候选可放置 AI 建议倾向，但仅代表参考倾向，不是默认选择。

### 5.2 `8`｜Regenerate（候选重构请求）
* **核心功能**：**Human 本次不重构当前 Frame，而要求 AI 在当前 Frame 下重新生成候选**；
* **系统行为**：AI 在既有框架下重新检索、推理，生成全新候选集交付；
* **铁律约束**：
  $$8 \neq \text{Human Judgment}$$
  按下 8 仅代表人类对现有生成物质量不满意并要求重新计算，**绝不得把按 8 静默升级为对 Frame 正确性的正式 Judgment**。

### 5.3 `9`｜Reframe / Human Input（跳出框架与自定义输入）
* **核心功能**：**人类享有拒绝 AI 预设候选空间、提出新候选或重定义问题框架（Frame Escape）的协议保障**；
* **实质含义**：按下 9 表示人类退出当前预设选择空间，后续可输入全新参数、反驳前置假设或重构目标；
* **铁律约束**：$$9 \neq \text{Reject}$$（9 是重构题目的开端，并不等于业务上的完全否定）。

### 5.4 `0`｜Exit without Commitment（无承诺退出）
* **核心功能**：人类选择中止本次交互、后退或搁置任务；
* **铁律约束**：
  $$0 \neq \text{Reject} \quad\text{且}\quad 0 \neq \text{Consent} \quad\text{且}\quad 0 \neq \text{Judgment}$$
  0 是交互动作的中止，绝不代表投赞成票，也绝不代表投反对票，系统不得借由 0 制造出虚假的业务结论。

### 5.5 Decision Cardinality 参数（单选 vs 多选）
单选与多选不是新原则，而是当前决策场的 **Cardinality 参数**：
* **Single-choice**：`Choose` 操作仅允许选中一个有效 Candidate；
* **Multi-choice**：`Choose` 操作允许同时选中多个相互兼容的 Candidate（如 `[1, 3]`）；
* AI 必须在题面显式声明当前是单选还是多选，不得模棱两可。

---

## 六、决策上下文绑定 (Decision Context Binding)

任何正式的 Human commitment（Judge, Authorize, Act 等）**绝不得脱离上下文孤悬存储或漂移使用**，必须与决策上下文（Decision Context）保持强绑定。

### 6.1 绑定的核心要求：Recoverable + Traceable + Context-Bound
L4 只对上下文提出三项规范要求：
* **Recoverable（可恢复）**：在需要复核或审计时，能够重构当时的交互情境；
* **Traceable（可追溯）**：能够沿脉络查证是谁、在何时、基于什么材料做出的响应；
* **Context-Bound（上下文绑定）**：响应与当时的对象、意图严格锚定，严禁跨上下文脱离使用。

### 6.2 语义要素按适用性表达
决策上下文要素必须根据介入类型按需适用，严禁机械套用：
1. **Request**：向人类发起的提问、陈述、通报或意图请求（**必需**）；
2. **Observable Object**：当时呈现给人类审查的具体对象与材料（**必需**）；
3. **Key Context & Difference**：介入时所依赖的关键背景与差异比对（**按需适用**）；
4. **Candidate Set**：当时呈现的候选集（**仅在存在候选时需要**；Act、Provide、Inform 等非选择型介入不得被强制生成虚假候选集）；
5. **Human Response & Semantic Type**：人类具体的响应内容及其正式语义类型（**仅在需要人类响应时需要**；Inform 履行通报时不得强行捏造虚假的 Human Response）；
6. **Temporal & Identity Trace**：操作发生的时间与操作者身份追踪信息（**必需**）。

### 6.3 职责定界
L4 仅确立决策上下文的语义绑定要求；底层的防篡改校验、数据签名、存储架构与持久化机制统一下沉至 **L6 机器语义基础设施**。

---

## 七、可选元动作规范：`[让AI学习]` (Optional Meta Action)

系统提供 `[让AI学习]` 机制以沉淀人类个性化偏好，但必须设立严格的语义边界：

```text
┌─────────────────────────────────────────────────────────────┐
│                 Decision ≠ Learn from Decision              │
│                (单次决策 不等于 建立永久偏好)               │
└─────────────────────────────────────────────────────────────┘
```

### 7.1 显式与可选原则
* **绝非默认副作用**：**`[让AI学习]` 绝不得作为人类确认或决策的默认勾选项或静默副作用**；
* **定义定界**：仅定义为**显式、可选 Meta Action**，表达 Human 允许本次 Human Interaction 被作为未来适配与学习的参考信号；
* **实现去耦**：L4 不决定长期学习模型、Memory 架构、Preference 生命周期与具体算法（统一下沉下游规范）；
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
决定何时产生 Human Involvement、Attention Bound 与 Execution Gate
    │
    │ 移交：判定需要找人后，交互语义如何规范、选择如何完成？
    ↓
[L4 通用 AI 交互协议] ── 本规范 (FREEZE CANDIDATE v1.0)
定义 PI-1～3 不变量、五种 Profile、两场分离、0–9 标准选择语法、Decision Context 绑定
    │
    │ 移交：交互语义如何在界面、控件、卡片与输入设备中承载与呈现？
    ↓
[L5｜HB Human-facing realization / 承载与呈现相关规范（正式名称待 L5 审议）]
定义卡片布局、按钮尺寸、颜色动效、键盘鼠标等价映射、Toast/Popup 动态行为适配
    │
    │ 移交：人回答完成后，机器底层如何解析状态、执行动作并对账现实？
    ↓
[L6 机器语义基础设施]
定义统一机器语义表示、状态/介入生命周期、Reality re-observation、reconciliation / reality closure
```

### 显式非目标清单（禁止重新升格为 L4 根规范的细项）：
* **严禁包含 HB 界面细节**：像素、内边距、外边距、主题调色、弹窗形式、控件类层次（统一下沉 L5）；
* **严禁包含物理输入绑定**：鼠标点击、键盘扫描码、手势识别算法（统一下沉 L5 抽象）；
* **严禁包含数据库与存储结构**：数据存储结构、防篡改签名、数据迁移脚本（统一下沉 L6 抽象）；
* **严禁发明新的根原则**：诸如“Acknowledge Principle”、“Mouse Principle”、“Reality Principle”等细项均属派生，绝不得升格为第四条协议不变量。

---

## 十、文档状态与后续封版纪律

1. **当前审定状态**：本规范经校准后处于 **`FREEZE CANDIDATE v1.0`** 状态，等待 Human Authority 最终封版裁定；
2. **冻结边界保护**：冻结后，不得因为具体产品交互习惯、前端样式排版或底层数据库设计困难而反向修改 L4；
3. **允许重新开启 Review 的严苛条件**：
   - 只有当出现以下五类重大事实之一时，方允许重新开启 L4 规范审议：
     1. L4 内部出现不可消解的逻辑冲突或规范矛盾；
     2. L3 上游介入理论发生重大重写或类型颠覆；
     3. 实践证据证明三大协议不变量（PI-1 / PI-2 / PI-3）存在无法覆盖的重大死角；
     4. 五种 Human Involvement Profile 无法容纳关键的人机交互形态；
     5. 现实世界人机交互基本前提发生颠覆性质变。
