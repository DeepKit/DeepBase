---
title: "第五层：极简人类交互适配 v1.0"
subtitle: "Efficient Human-AI Interaction · L5 极简人类交互适配 (English working candidate / OPEN)"
Status: FROZEN v1.0
Layer: 极简人类交互适配 (L5 Minimal Human Interaction Adaptation · English working candidate / OPEN)
System: 高效 AI 人机交互体系 (EHAI · Efficient Human-AI Interaction)
Specification: 高效 AI 人机交互规范 (EHAI Specification)
Framework Implementation: DeepBase (用于工程化实现和承载 EHAI Specification 的 Delphi 软件框架)
Nature: 体系规范母稿 (Normative Master Specification)
Upstream:
  - 第一层《AI 人机认知哲学 v1.0》 (EHAI.01.L1-人机认知哲学.md · Frozen v1.0)
  - 第二层《AI 交付原则 v1.0》 (EHAI.02.L2-AI交付原则.md · Frozen v1.0)
  - 第三层《AI 人类介入原则 v1.0》 (EHAI.03.L3-人类介入原则.md · Freeze Candidate v1.0)
  - 第四层《通用 AI 交互协议 v1.0》 (EHAI.04.L4-通用交互协议.md · Frozen v1.0)
Downstream:
  - 第六层《机器语义与介入基础设施》（下游工作候选）
  - 第七层《产品实现边界》（下游工作候选）
Theory References:
  - 差异一元论 (Difference Monism) 为重要理论来源之一（完整谱系理论定位另议）
  - ASTO.P03 《认识论：认知错误的必然性与证据化认知》
Author: 架构组 / 资料员
Reviewer: 老板 / 主控 (Human Authority)
Human Authority Final Review: PASS
Freeze Date: 2026-09-11
Date: 2026-09-11
Chinese Canonical Name: 极简人类交互适配
English Canonical Name: OPEN / Not Frozen
Theory Structure: FROZEN
HB Engineering Realization: Separate downstream engineering concern
Reopen Condition: only system-level contradiction or genuinely irreducible new residual
Revision Note: |
  2026-09-11 Human Authority Final Freeze Review (PASS → FROZEN v1.0):
    - Review: PASS
    - Status Transition: FREEZE CANDIDATE v1.0 → FROZEN v1.0
    - Chinese Canonical Name: 极简人类交互适配 (正式冻结)
    - English Canonical Name: OPEN / Not Frozen (暂未冻结，保持开放)
    - Theory Structure: FROZEN (唯一核心约束、极简规范定义、三项最低有效条件可达/可辨/可响应等正式冻结)
    - HB Engineering Realization: Separate downstream engineering concern (明确为下游工程实现考量，不属于 L5 理论母稿范围)
    - Reopen Condition: only system-level contradiction or genuinely irreducible new residual (严格限制仅在出现体系级矛盾或真正不可约新残余时方可重新审议)
  2026-09-11 Pre-Freeze Final Targeted Micro-Calibration (FREEZE CANDIDATE v1.0):
    - L1 继承段收窄责任表述：明确 Human 的价值、目标、判断与合法权力不得被 AI 静默替代，不在 L5 引入完整业务/法律责任理论
    - 清理第三节残余交互界面措辞：改用 Human-facing interaction 的低负担体验与 Human 侧交互的极简适配
    - 清理 L6 边界处视觉/UI 限定：改为转化为 Human 可感知、可辨的现实交互形式，删除界面层限定称呼直接表述为 L5
    - 校准 0–9 语法定位：明确用于降低认知、操作与纠偏负担的高复用 Standard Choice Grammar，去量级主张
    - 校准第四项 Check 表述：当前审议概念已由现有结构覆盖故不立第四项平行 Check，仅在出现不可约残余时允许重新审议
  2026-09-11 L5 Freeze Candidate Targeted Calibration (FREEZE CANDIDATE v1.0):
    - 英文名称明确保持 OPEN，元数据与正文标注为 English working candidate / OPEN，不提前冻结英文 Canonical 层名
    - 删除 Theory References 中未经正式裁定的 WSH 继承条目
    - 严格遵循下游边界：不对 L6/L7 提前封版，标为下游工作候选，不提前冻结其不变量与状态机
    - 校正上游状态口径：明确继承上游已冻结或已收敛成果，严格尊重各层当前真实状态
    - 消除 UI 具体实现污染：将桌面弹窗/手机推送/系统托盘等抽象为不同 Human-facing interaction forms / channels
    - 修正三项 Validity Checks 表述：明确为当前收敛的三项合格性检查门禁，不另立第四项平行 Check
    - 修正“可辨”定义：删除“一眼看出”，改为以合理负担识别重要区别与重要后果，去法律/业务窄化
    - 修正 Human Semantic Responsibility 中文解释：明确为“Human 必须承担的语义责任”，不作笼统最终责任推导
    - 收回 L6 状态生命周期的提前裁定：明确机器真值归 L6，Proposed 等仅为工作候选示例
    - 降低 0–9 效果主张：去除未经实证的绝对化量级修辞，定位为高复用选择语法
    - 抽象 [让AI学习]：去具体 UI 假设，明确“必须由 Human 显式触发，不得默认触发”
    - 去除 HB 英文全称展开，统一表述为 HB（DeepBase 中面向 Human 的统一人机交互承载与呈现基础设施）
    - 拓扑中明确说明：DeepBase / HB 为当前已知工程实现路径之一，不代表 EHAI 只能由 DeepBase 实现
    - 降低过度法律化措辞（将法定/铁律等措辞适度校准为规范定义/必须保持/边界/不得）
    - Anti-Patterns 全面去具体控件化，抽象为“合法响应被弱化/不可逆后果不可辨/实际不可达/偏好被错误升级为授权”
---

# 第五层：极简人类交互适配 v1.0
## L5 — 极简人类交互适配 (English working candidate / OPEN · FROZEN v1.0)

> **体系与工程定位说明**：  
> **EHAI（Efficient Human-AI Interaction · 高效 AI 人机交互体系）** 致力于定义 AI 与 Human 高效协同的核心原则、交互规则、机器语义与产品实现边界。差异一元论（Difference Monism）是 EHAI 的重要理论来源之一；EHAI 在差异一元论完整理论谱系中的最终定位另行决议。  
> **DeepBase** 是用于工程化实现和承载 EHAI 规范的 Delphi 软件框架。  
> **HB** 是 DeepBase 中面向 Human 的统一人机交互承载与呈现基础设施。HB 是 DeepBase 中实现 EHAI L5 极简人类交互适配要求的主要工程基础设施之一，但 HB 并不等同于 L5 本身。

---

## 〇、第五层在全体系中的定位与职责交接

整个高效 AI 人机交互体系（EHAI）自上而下遵循以下规范分层拓扑：

```text
差异一元论理论母源 (重要理论来源之一，独立演进)
        ↓
第一层：AI 人机认知哲学 (FROZEN v1.0 · 体系哲学母源与主体性保留)
        ↓
第二层：AI 交付原则 (FROZEN v1.0 · 交付不变量与最小充分交付)
        ↓
第三层：AI 人类介入原则 (Freeze Candidate v1.0 · 产生 Human Involvement、Attention Bound 与 Execution Gate)
        ↓
第四层：通用 AI 交互协议 (FROZEN v1.0 · 交互语义、承诺完整性、0–9 选择语法)
        ↓
第五层：极简人类交互适配 ──【本文档 FROZEN v1.0】
(在不削弱正式语义与判断条件前提下，将人类现实交互负担压至最小充分)
        ↓
第六层：机器语义与介入基础设施 (下游工作候选 · 统一机器语义表示、现实重新观察、真实回闭与对账)
        ↓
第七层：产品实现边界 (下游工作候选 · 领域产品绑定与符合性判定)
        ↓
[工程承载实现（如 DeepBase / HB 等）] ──► 业务产品消费层 (AsWish / 唤金 / 各类系统)
```

> **实现路径说明**：  
> DeepBase / HB 是当前已知工程实现路径之一，不代表 EHAI 只能由 DeepBase 实现。

---

## 一、继承的上游边界（绝对不得重新打开）

本规范继承上游已经冻结或已经收敛的当前有效成果，并严格尊重各层当前状态，不重复推导、不重新解释、不擅自变更：

### 1.1 第一层（L1 认知哲学）继承底线
* AI 在合法、授权且足够可靠的范围内，应最大化承担机器适合承担的认知劳动；
* Human 的价值、目标、判断与合法权力不得被 AI 静默替代；
* 必须保持核心边界：
  ```text
  AI Recommendation       ≠  Human Judgment
  AI Inference            ≠  Human Goal
  Repeated Choice         ≠  Permanent Preference
  Repeated Authorization  ≠  Standing Authorization
  AI Capability Expansion ≠  Authority Expansion
  No Response             ≠  Consent
  AI Cognition Fallible   /  Human Judgment Revisable
  Human Authority         ≠  Human Infallibility
  ```

### 1.2 第二层（L2 交付原则）继承底线
* 坚持核心公理：`AI Output ≠ AI Delivery`；
* 坚持交付组织总原则：`Minimal Sufficient Delivery｜最小充分交付`；
* 区分：`Delivery Completeness ≠ Simultaneous Exposure`（交付完整不等于同时全展示）；
* L5 不得把 Delivery 重新定义成 UI Presentation（界面呈现）。

### 1.3 第三层（L3 人类介入原则）继承底线
* L3 全权负责决定：Human 什么时候必须介入、以何种类型（Involvement Type）介入、介入时限与注意力量级边界（Attention Bound）以及受 Execution Gate 阻断的动作边界；
* 必须保持核心边界：
  ```text
  AI Uncertainty       ≠  Human Intervention
  Human Involvement    ≠  Immediate Interruption
  Blocked Action       ≠  Blocked Task
  Blocked Path         ≠  Whole Task Frozen
  少打扰               ≠  多授权
  尽量不请示           ≠  沉默即授权
  ```
* L5 绝不越权决定“该不该找 Human”。

### 1.4 第四层（L4 通用 AI 交互协议）继承底线
* L4 全权负责定义：Human 介入后的正式交互语义、正式承诺（Formal Commitment）、完成语义与决策上下文（Decision Context）；
* 必须保持核心边界：
  ```text
  Exploration ≠ Commitment
  Acknowledgement ≠ Agreement
  Provide ≠ Judge
  Judge ≠ Authorize
  Human Reported Done ≠ Reality Verified
  Human Interaction Complete ≠ Reality Complete
  ```
* 0–9 已经正式降位为：`Standard Choice Grammar｜标准选择语法`，不得重新提升为 L5 根原则；
* `[让AI学习]` 已经正式定位为：显式、可选 Meta Action，坚持 `Decision ≠ Learning`。L5 不得重新定义长期学习机制。

---

## 二、第五层的唯一根问题

第五层在体系中只回答一个唯一的根问题：

> **当 Human Involvement 已被确定为必要、且其正式语义已经明确后，怎样在不削弱 Human 权力、正式语义和完成所需判断条件的前提下，把 Human 为完成该介入所承担的现实交互负担压到最小充分？**

**通俗配套大白话**：
> **这件事确实必须找人以后，怎样让人只做必要的那一点，而且做得最省事。**  
> **人的责任不能偷，人的麻烦尽量省。**

* **定界说明**：
  - L5 不回答：Human 是否应该介入（由 L3 决定）；
  - L5 不回答：Human 交互的正式语义是什么（由 L4 决定）；
  - L5 专注于：**当上游两件事都定下来之后，如何让这一过程在人类一侧以最低负担、最高保真度现实发生。**

---

## 三、为什么第五层必须独立存在

第五层既不能被上游 L3、L4 吞并，也不能被下游 L6 替代，其独立的规范与工程价值在于：

1. **“语义要求”不等于“现实落地方式”**：  
   L4 可以严格规定“此处需要一个类型为 Authorize 的承诺”，但该承诺在现实中通过不同 Human-facing interaction forms / channels 呈现与完成，L4 不作规定。若无 L5，系统要么陷入形式僵化（无法根据设备、环境与注意条件进行合理适配），要么导致正式语义在不同交互形态中随意漂移失真。
2. **“必要介入”不等于“必须让人承担繁重劳动”**：  
   L3 决定找人，并不代表人类必须自己翻阅原始材料才能做出判断。必须有一层专门负责把复杂的机器背景信息压缩为人类易于消化、比对和决断的交互形态。
3. **“交互完成”与“现实对账”的物理分离**：  
   Human-facing interaction 的低负担体验（L5）绝不代表底层现实系统已经执行完毕（L6）。L5 独立存在，才能确保Human 侧交互的极简适配不会掩盖底层工程执行的严肃性。

---

## 四、第五层唯一核心约束

第五层不搞冗长的原则堆砌，全文贯彻**唯一核心约束**：

```text
┌──────────────────────────────────────────────────────────────────────────┐
│                             L5 唯一核心约束                              │
├──────────────────────────────────────────────────────────────────────────┤
│ 必要 Human semantic contribution 不得因极简适配而被削减、替代或静默改变；  │
│ 同时，Human 为完成该必要介入所承担的非必要交互负担，应在合法、授权、     │
│ 足够可靠以及完成条件充分的前提下，尽可能由 AI 消解。                     │
└──────────────────────────────────────────────────────────────────────────┘
```

**通俗大白话表述**：
> **该由人做的不能替人做；除此之外，机器能替人省的都应该省。**  
> **人的责任不能偷，人的麻烦尽量省。**

---

## 五、“极简”的严格正式含义

在 EHAI 体系中，“极简”具有极为严肃的定义，严防庸俗化与偷换概念：

* **绝对不是**：
  - ❌ 点击次数越少越好；
  - ❌ 界面字数越少越好；
  - ❌ 找人的次数越少越好；
  - ❌ 默认帮人类替选、默认替人类决定；
  - ❌ 盲目追求最高程度的自动化；
  - ❌ 把“人类介入越少”吹嘘为“系统越先进”。
* **正式规范定义**：
  > **在 Human 必须承担的正式语义、Human Authority 和完成该介入所需的最小充分判断条件不下降的前提下，使整体 Human Interaction Burden 尽可能低。**
* **核心边界**：
  ```text
  Minimal Human Interaction    ≠  Minimal Human Authority
  (极简人类交互 不等于 削减人类主权)

  Interaction Minimization     ≠  Semantic Minimization
  (交互精简 不等于 语义缩水)

  Minimal Information          ≠  Minimal Sufficient Information
  (极少信息 不等于 最小充分信息)

  Few Actions                  ≠  Low Human Burden
  (操作少步数 不等于 低人类负担)
  ```
* **通俗大白话**：
  > **操作可以极简，意义不能缩水。**

---

## 六、人类交互负担（Human Interaction Burden）的观测维度

L5 优化的唯一对象是 **Human Interaction Burden（人类交互负担）**。  
为了工程观测与评估，系统确立以下四个**非穷举的常见观测维度**（注意：它们只是观测视角，绝不是四条根原则）：

1. **注意负担（Attention Burden）**：  
   人类被当前任务打断、转移焦点、在不同上下文之间来回切换所耗费的心智精力；
2. **认知负担（Cognitive Burden）**：  
   人类为了弄清楚“AI 说了什么、当前处于什么状态、不同选项到底有何区别、选了会怎样”所必须进行的理解、检索、推理与心算劳动；
3. **操作负担（Operational Burden）**：  
   人类为了输入信息、表达意图、完成操作所必须进行的打字、翻页、查找控件、点击和手部动作量；
4. **纠偏负担（Recovery / Correction Burden）**：  
   当 AI 理解产生偏差、候选不合意、或人类希望推翻重来时，进行框架逃逸（Reframe）、改题、撤销、回滚与重新输入的阻力和成本。

---

## 七、三项最低有效条件（Validity Checks）

为了防止“极简”退化为偷工减料或非法越权，当前 L5 的最低有效性检查收敛为三项：**可达、可辨、可响应**；其它已讨论要求当前均作为派生要求，不另立第四项平行 Check。三项通过，即视为满足 L5 极简人类交互适配的最低有效性（注意：它们是合格性检验门禁，不是三大理论原则）：

```text
               合格极简适配的三项最低有效条件 (Validity Checks)
┌──────────────────────────────────────────────────────────────────────────┐
│ 1. 可达 (Reachability)       —— 人类在现实中有没有机会接触到当前交互？   │
├──────────────────────────────────────────────────────────────────────────┤
│ 2. 可辨 (Distinguishability) —— 人类能否分清关键事实、语义、差异与后果？ │
├──────────────────────────────────────────────────────────────────────────┤
│ 3. 可响应 (Response Availability) —— 人类是否有现实可用、语义纯正的完成路径？│
└──────────────────────────────────────────────────────────────────────────┘
```

---

### 7.1 可达（Reachability）
* **正式含义**：在当前 Context 与 Attention Bound 下，相应合格 Human 必须在物理现实与软件交互通道中有切实机会接触到当前的必要交互。
* **边界区分**：
  $$\text{Available} \neq \text{Reachable} \neq \text{Attended}$$
  - `Available`（可用）：机器内部已经生成了该交互请求；
  - `Reachable`（可达）：该请求已经按符合人类工作流与物理设备条件的方式，投射到了人类可以触及的视界或通道中；
  - `Attended`（已关注）：人类心智真正投入了注意。
* **底线保证**：L5 必须保证 Reachable，但绝不妄称“已经能监测或证明人类内心是否真正投入了注意力”。

### 7.2 可辨（Distinguishability）
* **正式含义**：在合理的认知负担内，清晰可辨其动作语义与可能后果（包括完成当前介入所必需的关键对象、正式意义、重要状态与实质差异）。
* **特别保护的语义边界**：
  ```text
  Exploration   ≠  Commitment
  Provide       ≠  Judge
  Judge         ≠  Authorize
  Authorized    ≠  Executed
  Executed      ≠  Reality Verified
  ```
* **边界区分**：
  $$\text{Visible} \neq \text{Distinguishable} \neq \text{Understood}$$
  - `Visible`（可见）：文字或元素仅仅显示在交互界面中；
  - `Distinguishable`（可辨）：Human 能够以合理负担识别完成当前介入所必需的重要区别与重要后果；
  - `Understood`（已理解）：人类内心完全参透。
* **底线保证**：系统必须提供合格、充分的理解与辨别条件，但绝不越权宣称“系统保证人类已经完全理解”。

### 7.3 可响应（Response Availability / Actionability）
* **正式含义**：当当前 Human Involvement 要求人类产生正式 Response 时，必须存在现实可用、语义合法、没有被静默替代的完成路径，使人类能够有意完成相应的正式语义动作（Formal Semantic Act）。
* **边界区分**：
  $$\text{Response Exists} \neq \text{Response Effectively Available} \neq \text{Actionable} \neq \text{Acted}$$
* **底线保证**：
  - 界面上存在一个死入口或难寻路径，不等于响应“现实有效可用”；
  - 拥有完成路径，不等于人类“已经做出了响应”；
  - 严禁因为交互通道上存在未操作元素，就强行推导认定人类已经默认确认。

---

## 八、不得新增第四个 Validity Check

体系明确确立：当前已经审议的相关概念均可由核心约束、三项最低有效条件或派生要求覆盖，因此当前不另立第四个平行 Validity Check；只有未来出现不能由现有结构推出的真正不可约残余时，才允许重新审议。常见概念收敛关系如下：

* ❌ Feedback（反馈机制）—— 属可辨与可达的实现手段；
* ❌ Context Continuity（上下文连续性）—— 属可辨与认知负担优化的工程策略；
* ❌ Consistency（交互一致性）—— 属降低操作负担的工程准则；
* ❌ Accessibility（无障碍可访问性）—— 属可达在特定人群与通道中的具体落地；
* ❌ Progressive Disclosure（渐进式暴露）—— 属处理交付完整与避免信息淹没的设计策略；
* ❌ Reversibility / Error Prevention（可逆性与防错）—— 属纠偏负担（Recovery Burden）的工程实现；
* ❌ Difference Visualization（差异可视化）—— 属可辨的下位要求。

---

## 九、AI 与 Human 在 L5 中的职责分工

在极简交互适配过程中，AI 与人类的边界清晰明了，严禁混淆：

### 9.1 Human 做什么
* 严格遵循上游 L3/L4 的判定，亲自完成 `Inform / Provide / Judge / Authorize / Act` 中不可替代的核心角色；
* L5 绝不得为了降低所谓的交互步骤，擅自取消或合并必要的 Judge、Authorize、Provide、Act 或必要的 Inform；
* **Human 必须承担的语义责任**：进入决策闭环的动作语义，必须归属于 Human 主体意志；AI 不得擅自替 Human 代行其主观语义赋值。此处强调的是语义责任与确认责任，而非在此规定整个社会的侵权与连带责任法理。不得把“Human 语义责任”直接泛化或等同于“Human 承担最终业务责任 / 最终法律后果”。

### 9.2 AI 在 L5 中做什么
在绝不越权替代人类正式语义的前提下，AI 应主动、充分承担人类完成当前介入所不必亲自承担的全部机器化劳动：

```text
┌─────────────────────────────────────────────────────────────┐
│                 AI 在 L5 中应当全力承担的劳动               │
├─────────────────────────────────────────────────────────────┤
│ 搜索与信息查证 │ 数据提取与格式清洗 │ 跨源信息汇总与排重         │
│ 复杂关联计算   │ 方案横向对比       │ 提炼实质差异 (Difference)  │
│ 组织客观证据链 │ 预制合格候选集     │ 提炼精炼摘要 (Summary)     │
│ 预测潜在影响   │ 恢复历史决策上下文 │ 字段智能预填               │
│ 输入形式简化   │ 机器状态直白解释   │ 提供低成本纠偏与改题通道   │
│ 在未被 Execution Gate 阻断的分支上，机器自主继续推进后续工作│
└─────────────────────────────────────────────────────────────┘
```

* **核心边界**：
  ```text
  Human Involvement Required      ≠  Human Work Transfer
  (需要人类介入 不等于 把工作交给人)

  Human Judgment Required         ≠  Human Analysis Required
  (需要人类判断 不等于 必须人类自己做全部分析)

  Human Authorization Required    ≠  Human Execution Required
  (需要人类授权 不等于 必须人类自己动手执行)

  Human Semantic Responsibility   ≠  Human Interaction Workload
  (Human 必须承担的语义责任 不等于 人类必须承担繁琐交互工作量)

  AI Assistance                   ≠  Human Substitution
  (机器全力辅佐 不等于 机器静默替代)
  ```
* **通俗大白话**：
  > **必须由 Human 拍板，不代表资料也必须 Human 自己查、差异自己找、后果自己算。**

---

## 十、适配（Adaptation）的正式含义与边界

L5 中的“适配”绝不仅仅是前端换肤或样式调整，它的正式规范定义是：

> **在正式 Human Semantic Requirement 不变的前提下，根据当前 Human、Context、Attention 条件、设备、输入方式、能力与合法偏好，选择 Human Interaction Burden 更低而仍然合格的现实交互形式。**

### 10.1 形式适配与语义守恒原则
```text
Same Semantics                 ≠  Same Interaction Form
(相同的业务语义 可以采用完全不同的交互形式)

Different Interaction Form     ≠  Different Formal Meaning
(不同的交互表现形式 绝不改变底层的正式业务含义)

Adaptation                     ≠  Semantic Change
(交互适配 绝不等于 篡改或变更语义)
```

### 10.2 跨媒介与多端表现
* 原生桌面、Web 界面、移动触控、语音交互、纯键盘快速操作、无障碍辅助模式等，完全可以具备截然不同的界面呈现与交互节奏；
* 只要其正式语义、上下文绑定以及三项最低有效条件（可达/可辨/可响应）保持成立，即判定为合格适配；
* **严禁把“跨平台像素级一致”写为 EHAI L5 的规范要求。**

---

## 十一、人类偏好（Human Preference）的使用边界

L5 允许且应当消费上游合法提供的人类偏好参数（例如 L3 的五档干预偏好：`及时请示｜必要请示｜平衡｜少打扰｜尽量不请示`，以及详细/精简、图表/文字、键鼠/语音等偏好），但必须坚守以下严格规范边界：

```text
┌─────────────────────────────────────────────────────────────────────┐
│    Preference tunes adaptation; it does not override obligation.    │
│   (偏好可以调节“怎么做”，但绝不能覆盖必须履行的责任与权力边界)      │
└─────────────────────────────────────────────────────────────────────┘
```

* **偏好越权禁令**：
  - 无论人类设置了多么极端的“少打扰”或“尽量不请示”，当遇到触及系统安全底线或未授权的高危操作时，**机器必须叫人的规范程序绝不能被偏好静默免除**；
  - 必须保持：`少打扰 ≠ 多授权`；`尽量不请示 ≠ 沉默即授权`；
* **偏好与承诺的严格分离**：
  ```text
  Adaptation Preference   ≠  Current Human Commitment
  Repeated Choice         ≠  Permanent Preference
  Repeated Authorization  ≠  Standing Authorization
  No Response             ≠  Consent
  ```

---

## 十二、长期学习与 Memory 的非归属边界

关于个性化、记忆与长期自适应，L5 确立清晰的治理边界：

```text
┌─────────────────────────────────────────────────────────────────────┐
│         L5 owns adaptation application, not preference truth.       │
│   (L5 只负责应用已知偏好来优化交互，不负责宣布偏好真相)              │
└─────────────────────────────────────────────────────────────────────┘
```

* **L5 允许做的事情**：
  - 消费和使用当前上下文中已经合法存在的、被授权的适配参数（Adaptation Context）；
* **L5 绝不负责的事情（严禁越权）**：
  - ❌ 学习信号如何提取与持久化存储；
  - ❌ 长期 User Model（用户模型）的构建与维护；
  - ❌ 偏好在跨场景下的泛化与冲突消解机制；
  - ❌ 偏好权重的衰减、遗忘、过期与数据同步；
  - ❌ 预测性代投代答与预先默认同意（Standing Authorization）；
* **通俗大白话**：
  > **L5 可以用“对这个人的合法了解”来优化当前交互，但不能自己宣布“我已经真正了解他，所以以后替他决定”。**
* **归属说明**：长期 Learning、Memory 与价值偏好的生命周期治理，属于 L6、L7 或未来专门规范的范畴，L5 保持中立与纯粹。

---

## 十三、状态反馈与第六层（L6）的边界

在机器状态与现实反馈方面，L5 与 L6 的职责划分清晰明了：

```text
┌───────────────────────────────────────────────────────────────────────────────────────┐
│  L6 owns machine state truth; L5 owns human-facing realization of Human-material state.  │
│  (L6 拥有机器状态的真值；L5 拥有面向人的一侧实质状态的呈现与适配)                     │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

* **L6 负责真值与现实对账**：
  - 对于 Proposed / Selected / Committed / Discarded 等，仅作为下游 L6 机器语义生命周期管理的工作候选示例，L5 不预先冻结 L6 的内部状态机；真正由机器承担的语义真值管理与 Reality Closure，明确留给下游 L6。
* **L5 负责呈现与适配**：
  - L5 仅负责将这些状态中**对人类当前理解、判断、等待或后续动作有实质意义的差异（Human-material difference）**，以最低负担的方式转化为 Human 可感知、可辨的现实交互形式；
* **必须保持**：
  ```text
  Machine State Difference   ≠  Human-Material Difference
  State Ownership            ≠  State Presentation
  ```
  严禁让 L5 自行推导或断言现实世界的执行真值。

---

## 十四、与第二层（L2 交付原则）的边界

* **L2 规定**：AI 应当交付什么要素（D1 结论、D2 事实、D3 证据、D4 推导摘要、D5 差异、D6 分叉、D7 后续/收口）；
* **L5 规定**：应交付给人类的要素，怎样在特定环境和时间窗口中，以低负担、不淹没人类的方式现实转化为交互通道；
* **核心边界**：
  ```text
  More Information      ≠  Better Human Realization
  (堆砌更多信息 不等于 更好的交互实现)

  Everything Exposed    ≠  Human Informed
  (把所有东西一股脑展示 不等于 人类已经被充分告知)
  ```

---

## 十五、标准选择语法（0–9）在 L5 中的位置

* **绝非理论根原则**：0–9 在 L4 中已降位为 `Standard Choice Grammar（标准选择语法）`，在 L5 中同样不得反向升格为根原则；
* **L5 中的角色**：可用于降低 Human 认知、操作与纠偏负担，并作为跨场景高复用的 Standard Choice Grammar。
* **严格保持语义边界**：
  - `1–7 Choose`：是指向候选的指针语法，其正式语义由 `Profile + Decision Context` 决定；
  - `8 Regenerate`：本次不改题，要求机器重做候选，$$8 \neq \text{Human Judgment}$$；
  - `9 Reframe`：跳出候选框架，人类自主输入，$$9 \neq \text{Reject}$$；
  - `0 Exit`：无承诺退出，$$0 \neq \text{Reject} \land 0 \neq \text{Consent} \land 0 \neq \text{Judgment}$$。

---

## 十六、可选元动作 `[让AI学习]` 在 L5 中的位置

* **显式触发原则**：`[让AI学习]` 必须由 Human 显式触发，不得默认触发，绝不能作为默认或隐式副作用，也不能被包装为自动偏好学习引擎；
* **边界坚守**：
  $$\text{Decision} \neq \text{Learning}$$
  $$\text{Repeated Choice} \neq \text{Permanent Preference}$$

---

## 十七、与 HB 基础设施及 UI 工程实现的关系

为彻底消除理论与工程实现的混淆，确立以下四层工程落地关系：

```text
┌─────────────────────────────────────────────────────────────┐
│ 1. EHAI L5 规范                                             │
│    规定合格极简人类交互适配的理论母法、核心约束与最低有效条件│
├─────────────────────────────────────────────────────────────┤
│ 2. HB                                                       │
│    DeepBase 中面向 Human 的统一人机交互承载与呈现基础设施   │
├─────────────────────────────────────────────────────────────┤
│ 3. Design System / Interaction Patterns                     │
│    将交互承载要求进行设计制度化 (组件规约、交互模板、布局规范)│
├─────────────────────────────────────────────────────────────┤
│ 4. Platform UI Toolkits / Controls                          │
│    不同平台的原生控件、Web 组件、跨媒介交互入口等            │
└─────────────────────────────────────────────────────────────┘
```

* **严格定界辨析**：
  ```text
  DeepBase  ≠  EHAI
  HB        ≠  L5
  L5        ≠  HB
  L5        ≠  Design System
  L5        ≠  UI Framework
  L5        ≠  Control Library
  ```
* **实现路径说明**：DeepBase / HB 是当前已知工程实现路径之一，不代表 EHAI 只能由 DeepBase 实现。
* **禁止实现污染**：Delphi 语法、窗口句柄、系统消息循环、RGB 颜色值、圆角阴影、CSS 样式类、弹窗具体控件名等，一律属于底层工程代码，严禁写进 L5 规范母稿。

---

## 十八、核心不等式与反例库

### 18.1 核心边界不等式
```text
1.  Human Involvement Required      ≠  Human Work Transfer
2.  Human Semantic Responsibility   ≠  Human Interaction Workload
3.  Interaction Minimization        ≠  Semantic Minimization
4.  Minimal Human Interaction       ≠  Reduced Human Authority
5.  AI Assistance                   ≠  Human Substitution
6.  Same Semantics                  ≠  Same Interaction Form
7.  Preference                      ≠  Current Commitment
8.  Available                       ≠  Reachable
9.  Visible                         ≠  Distinguishable
10. Response Available              ≠  Human Responded
```

### 18.2 典型违规反例（Anti-Patterns）
* **反例 1：伪极简偷渡（合法响应被弱化）**  
  为了追求表面极简，系统将授权与执行合并，削弱或跳过人类独立 Authorize 的现实路径；
* **反例 2：甩锅式介入（违反分工界限）**  
  在需要人类做价值判断时，系统直接倾倒大量未经结构化加工的原始背景数据，强迫人类承担机械整理劳动；
* **反例 3：不可辨的紧凑（不可逆后果不可辨）**  
  在呈现交互时，未对可逆操作与具有破坏性后果的操作进行清晰区隔，导致人类在决策时无法辨识重要后果；
* **反例 4：僵尸可达（Attention Bound 内实际不可达）**  
  在需要必要介入的任务中，交互入口被放置在人类在当前 Attention Bound 内根本无法有效注意或接触的隐蔽路径中，虚假声称“已向人类提供”；
* **反例 5：偏好被错误升级为授权（偏好被错误升级为授权）**  
  因为人类曾设置“少打扰”，系统在遭遇未授权的高危风险时，将一般交互偏好错误升级为免除介入的授权，造成静默越权。

---

## 十九、显式非目标与淘汰概念清单

### 19.1 淘汰的旧概念
* ❌ **“行为适配层”**：已正式淘汰作为层级正式名称，行为适配仅作为 L5 内部的派生实现机制；
* ❌ 严禁恢复以下概念作为 L5 Root 原则：`Semantic Fidelity`、`Human Realizability`、`Attention Realization`、`Information Hierarchy`、`Context Continuity`、`Feedback`、`Consistency`、`Accessibility`、`Human Leverage`。

### 19.2 显式非目标（Explicit Non-Goals）
* L5 不制定前端 UI 控件库的技术 API（属于 HB 源码与底层实现职责）；
* L5 不制定具体操作系统的图形驱动适配标准；
* L5 不决定模型训练、偏好微调或长期记忆存储格式；
* L5 不处理具体商业产品的业务页面排版。

---

## 二十、封版候选自检清单（Freeze Candidate Checklist）

在提交主控审核前，资料员已对照以下 15 项标准进行严格自检：

- [x] 1. 文档是否明确说明 L5 为什么不能被 L3、L4 或 L6 吞掉？（已在第三节专门阐明）
- [x] 2. 是否明确区分“Human 必须承担什么”与“Human 完成它需要付出多少负担”？（已在第七节、第九节确立）
- [x] 3. 是否错误地把点击最少等同于极简？（已在第五节明确批判与纠正）
- [x] 4. 是否保护了 Human Judgment / Authority / Formal Semantics？（已确立为核心约束）
- [x] 5. 是否明确“可达 / 可辨 / 可响应”只是最低有效条件，不是三大 Root？（已在第七节正名）
- [x] 6. 是否把 Human Interaction Burden 的四类表现误写成封闭分类？（已在第六节明确为开放常见维度）
- [x] 7. 是否允许交互形式适配而保护正式语义？（已在第十节确立形式与语义守恒律）
- [x] 8. 是否错误把历史行为当成永久 Preference？（已在第十一节明确禁止）
- [x] 9. 是否错误把 `[让AI学习]` 变成自动长期学习？（已在第十六节明确为显式触发）
- [x] 10. 是否错误让 L5 拥有 Machine State / Reality truth？（已在第十三节将真值坚决划归 L6）
- [x] 11. 是否错误把 HB 等同于 EHAI L5？（已在第十七节确立工程落地关系，HB ≠ L5）
- [x] 12. 是否引入了 VCL / FMX / Popup / Color / Token 等过早实现细节？（已彻底过滤清理）
- [x] 13. 是否已完成 Human Authority 终审裁定并正式冻结？（已通过主控裁定正式封版为 `FROZEN v1.0`）
- [x] 14. 英文名是否保持 OPEN？（已在元数据与 Open Items 中明确标注 OPEN）
- [x] 15. 是否存在任何可以由现有结构推出、却被擅自升级成新 Root 的概念？（已严格收敛，无新增 Root）

---

## 二十一、待决议事项（Open Items）

以下三项为当前规范真正尚未冻结的事项，依规如实标明并提交后续审议，资料员不得擅自代断：

1. **英文正式名称（English Canonical Name）**：  
   * **当前状态**：`OPEN / Not Frozen`  
   * **说明**：中文正式层名已正式冻结为《极简人类交互适配》（Chinese Canonical Name: 极简人类交互适配 · FROZEN）。英文正式名称保持开放未冻结（English Canonical Name: OPEN / Not Frozen），仅作为工作描述（English working candidate / OPEN），等待后续主控统一定夺，不得提前宣布任何正式英文 Canonical 层名。
2. **L5 在差异一元论完整理论谱系中的最终法定位置**：  
   * **当前状态**：`OPEN`  
   * **说明**：差异一元论是本体系的重要理论来源之一，但 EHAI 在其全局本体谱系中的终极理论归属另行决议。
3. **长期 Learning / Memory / Preference Governance 的最终归属**：  
   * **当前状态**：`OPEN`  
   * **说明**：已确定其不属于 L5 的核心职责，最终归属于 L6 机器语义、L7 产品实现还是未来专门规范，尚待后续层级联审确定。

4. **L5 理论母稿重开条件（Reopen Condition）**：  
   * **正式裁定约束**：L5 理论结构自此正式冻结（Theory structure: FROZEN）。除非后续出现体系级重大矛盾（system-level contradiction）或证明存在真正不可约的新残余（genuinely irreducible new residual），否则任何人不得以具体产品实现习惯、HB 编码实现方式或单一业务特殊需求为由重新打开 L5 理论审议。
