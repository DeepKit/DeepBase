---
title: "第五层派生规范：表述适配 v1.0"
subtitle: "Efficient Human-AI Interaction · L5 Derivative Specification: Expression Adaptation (English working candidate / OPEN)"
Status: FROZEN v1.0
Layer: EHAI L5 派生规范 (L5.D1 Expression Adaptation · English working candidate / OPEN)
System: 高效 AI 人机交互体系 (EHAI · Efficient Human-AI Interaction)
Specification: 高效 AI 人机交互规范 (EHAI Specification)
Framework Implementation: DeepBase (用于工程化实现和承载 EHAI Specification 的 Delphi 软件框架)
Nature: 体系派生规范母稿 (Derivative Normative Specification)
Parent Layer:
  - 第五层《极简人类交互适配 v1.0》 (EHAI.05.L5-极简人类交互适配.md · Frozen v1.0)
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
Chinese Canonical Name: 表述适配
English Canonical Name: OPEN / Not Frozen (Expression Adaptation · English working candidate / OPEN)
Theory Structure: FROZEN (L5 派生规范正式冻结)
Reopen Condition: only system-level contradiction or genuinely irreducible new residual
Revision Note: |
  2026-09-11 Human Authority Final Freeze Review (PASS → FROZEN v1.0):
    - Review: PASS
    - Status Transition: FREEZE CANDIDATE v1.0 → FROZEN v1.0
    - Chinese Canonical Name: 表述适配 (正式冻结)
    - English Canonical Name: OPEN / Not Frozen (保持开放，候选 Expression Adaptation)
    - Theory Structure: FROZEN (双维正交模型、即时动作、生效三准则、重述与重裁定分离正式冻结)
    - Reopen Condition: only system-level contradiction or genuinely irreducible new residual
  2026-09-11 Pre-Freeze Final Targeted Micro-Calibration:
    - 校准 Immediate：明确为显式触发后直接进入转换流程，无需人类重新提问建立上下文，非工程零延迟保证
    - 校准 Re-expression ≠ Task-level Re-reasoning / Re-adjudication：重新表述非重新裁定原任务，严格区分 Re-expression、Task-level Re-reasoning 与 Content Correction，坚守 Content Correction ≠ Silent Re-expression
  2026-09-11 L5.D1 Freeze Candidate Draft (FREEZE CANDIDATE v1.0):
    - 建立 EHAI L5 首份独立派生规范《表述适配》（EHAI.05.D1-表述适配.md）
    - 严格遵循已冻结 L5 唯一核心约束与三大最低有效条件（可达/可辨/可响应），确立 Expression Adaptation ≠ Semantic Change 核心底线
    - 确立语言门槛（Language Level: 专业/有术语/大白话）与内容深度（Detail Depth: 简要/标准/深入）正交分离模型
    - 确立举例/类比/讲故事为即时理解动作（Instant Explanation Actions），非语言门槛且非长期偏好
    - 确立即时生效三准则：Immediate、Context-preserving、Reversible，确立 Re-expression ≠ Re-reasoning
    - 确立同一语义对象的多个 Human-facing Representation 映射机制与 Local Re-expression vs Session State 分离
    - 确立显式优先级：Human 当前显式选择 > 当前会话表述状态 > 合法长期偏好 > AI 当前推断 > 系统默认
    - 确立叙事真实性底线：Narrative Adaptation ≠ Fact Transformation
    - 剥离具体 UI 控件，明确能力要求，HB 作为下游工程承载基础设施
---

# 第五层派生规范：表述适配 v1.0
## L5.D1 — 表述适配 (Expression Adaptation · English working candidate / OPEN · FROZEN v1.0)

---

## 〇、派生规范定位与理论归属

本规范属于 **EHAI L5｜极简人类交互适配** 体系下的**第一项独立派生规范（L5.D1）**。

```text
差异一元论理论母源 (重要理论来源之一)
        ↓
第一层：AI 人机认知哲学 (FROZEN v1.0 · 体系哲学母源与主体性保留)
        ↓
第二层：AI 交付原则 (FROZEN v1.0 · 交付不变量与最小充分交付)
        ↓
第三层：AI 人类介入原则 (Freeze Candidate v1.0 · Involvement / Attention Bound / Execution Gate)
        ↓
第四层：通用 AI 交互协议 (FROZEN v1.0 · 协议不变量、五类平权 Profile、两场分离)
        ↓
第五层：极简人类交互适配 (FROZEN v1.0 · 唯一核心约束、极简定义、三项最低有效条件)
   └──►【本派生规范 L5.D1：表述适配 (Expression Adaptation · FROZEN v1.0)】
        ↓
第六层：机器语义与介入基础设施 (下游工作候选 · 统一机器语义表示、现实重新观察、真实回闭与对账)
        ↓
第七层：产品实现边界 (下游工作候选 · 领域产品绑定与符合性判定)
        ↓
[工程承载实现（如 DeepBase / HB 等）] ──► 业务产品消费层 (AsWish / 唤金 / 各类系统)
```

### 0.1 严格遵循 L5 母法底线
本规范绝非 EHAI 的新根层级，也绝不修改 L5 已正式冻结的理论基石：
1. **坚守 L5 唯一核心约束**：
   > **必要 Human semantic contribution 不得因极简适配而被削减、替代或静默改变；同时，Human 为完成该必要介入所承担的非必要交互负担，应在合法、授权、足够可靠以及完成条件充分的前提下，尽可能由 AI 消解。**  
   > （人的责任不能偷，人的麻烦尽量省。）
2. **坚守 L5 三项最低有效条件**：
   任何表述适配的落地形态，必须无条件满足 **可达（Reachability）、可辨（Distinguishability）、可响应（Response Availability）**。
3. **贯彻核心等式与禁令**：
   $$\text{Expression Adaptation} \neq \text{Semantic Change}$$
   任何表述形式的切换、重述、故事化或大白话化，**绝不得导致底层的正式业务语义、判定条件、责任边界或事实结论发生静默漂移**。

---

## 一、派生规范的唯一根问题与范围定界

### 1.1 唯一根问题
本派生规范在 L5 极简人类交互适配的框架下，只聚焦回答一个唯一的根问题：

> **当 AI 已经拥有要向 Human 表达的同一个语义对象、事实、判断对象或交付内容时，怎样允许 Human 以最低交互负担选择自己更容易理解的表达形式？**

**通俗配套大白话**：
> **人不必重新问，点一下，AI 就换一种更容易懂的说法。**

### 1.2 严格定界（明确不决议事项）
本规范严守层级分工，绝不越权决议以下事项：
* ❌ **不决定内容是真是假**：事实与知识真伪由底层推理、事实对账与客观证据源决定；
* ❌ **不决定 AI 应交付什么**：交付要素完备性由 L2《AI 交付原则》（D1～D7）全权负责；
* ❌ **不决定是否需要 Human 介入**：找人时机与类型由 L3《AI 人类介入原则》（Involvement / Attention Bound / Execution Gate）全权负责；
* ❌ **不决定正式交互语义与承诺**：正式承诺与协议完成由 L4《通用 AI 交互协议》（PI-1～PI-3）全权负责；
* ❌ **不决定底层机器状态与现实执行**：状态真值与现实对账由 L6 全权负责；
* ❌ **不改变任务现状与执行流**：表述适配只改变面向人一侧的表达形态，不触发任务重启或底层执行中断。

---

## 二、第一维：语言门槛（Language Level）

系统确立**语言门槛（Language Level）**的三档正式分类。语言门槛衡量的是：**理解当前表述对 Human 先验领域专业知识的依赖程度**。

```text
┌──────────────────────────────────────────────────────────────────────────┐
│                   第一维：语言门槛 (Language Level)                      │
├──────────────────┬───────────────────────────────────────────────────────┤
│ 1. 专业          │ 高信息密度，充分使用领域术语，预设较高专业背景知识    │
├──────────────────┼───────────────────────────────────────────────────────┤
│ 2. 有术语 (默认) │ 正常使用必要术语并对关键门槛适度释义，平衡准确与易读  │
├──────────────────┼───────────────────────────────────────────────────────┤
│ 3. 大白话        │ 普通语言直观表达，优先建立形象理解，免除术语先验门槛  │
└──────────────────┴───────────────────────────────────────────────────────┘
```

### 2.1 专业（Professional）
* **特征定义**：
  - 允许使用高精度的领域行业术语、标准缩略语与技术概念；
  - 默认 Human 具备相应领域的专业工作背景与完备知识谱系；
  - 具备最高的信息编码密度与符号严谨度；
  - 规范不要求对行业常见专业术语逐一进行下位通俗解释。
* **边界底线**：
  - 不得为了追求所谓“专业腔调”而故意使用晦涩黑话或省略决策所需的实质上下文；
  - 不得增加原语义对象中不存在的推测性专业结论。

### 2.2 有术语（Term-guided / Balanced · 系统默认）
* **特征定义**：
  - **此档为全系统通用默认语言门槛**；
  - 正常且准确地使用领域核心术语，保障概念严谨性；
  - 对可能构成跨专业认知门槛的重要术语，在上下文或紧随其后附带简短的通俗释义或引导；
  - 在表达的科学严谨性与大众可读性之间取得最优平衡；
  - 不预设 Human 必然是该领域的专精学者。

### 2.3 大白话（Plain Language）
* **特征定义**：
  - 遵循“能不用术语时尽量不用”的语言原则；
  - 遇到无法回避的核心概念时，优先先用生活化、通俗直观的日常语言建立概念锚点，再引出必要概念；
  - 优先调动人类的直觉经验与常识认知，使 Human 无需预先研修领域术语体系即可迅速理解核心实质。
* **核心底线**：
  $$\text{Plain Language} \neq \text{Shallow Content}$$
  > **大白话，不等于讲浅。**
* **严格禁令**：
  严禁为了迎合“大白话”而做出以下违规操作：
  - ❌ 删除使当前判断成立所必需的关键边界条件；
  - ❌ 扭曲技术因果关系与时序逻辑；
  - ❌ 模糊或淡化不可逆操作的破坏性风险；
  - ❌ 偷换正式业务语义或交付结论。

---

## 三、第二维：内容深度（Detail Depth）

语言门槛与内容深度是两个完全正交的独立维度，严禁混淆：

$$\text{Language Level} \neq \text{Detail Depth}$$

内容深度衡量的是：**面向 Human 展开的信息颗粒度、背景广度与推导演进程度**。正式确立三档分类：

```text
┌──────────────────────────────────────────────────────────────────────────┐
│                   第二维：内容深度 (Detail Depth)                        │
├──────────────────┬───────────────────────────────────────────────────────┤
│ 1. 简要          │ 结论优先，极致提炼，仅保留当前行动最核心信息          │
├──────────────────┼───────────────────────────────────────────────────────┤
│ 2. 标准 (默认)   │ 充分充分，提供正常判断与行动所需的完备信息，不泛滥展开│
├──────────────────┼───────────────────────────────────────────────────────┤
│ 3. 深入          │ 展开全景背景、推导逻辑、关键差异、证据链及潜在后果    │
└──────────────────┴───────────────────────────────────────────────────────┘
```

### 3.1 简要（Concise）
* **特征定义**：
  - 结论导向，剔除次要过程描述与冗长修辞；
  - 仅保留达成当前介入目标或推动后续决策所绝对必需的核心要点；
  - 适用于快节奏决策、即时指令响应或高注意力受限环境。

### 3.2 标准（Standard · 系统默认）
* **特征定义**：
  - **此档为全系统通用默认内容深度**；
  - 严格落实 L2《AI 交付原则》的“最小充分交付（Minimal Sufficient Delivery）”；
  - 完整呈现做出当前理解、判断与授权所需的充分要素（D1～D7 的核心摘要），不刻意隐瞒关键点，也不无端铺陈海量冷背景。

### 3.3 深入（In-depth）
* **特征定义**：
  - 充分展开问题的形成背景、演化脉络与深层机理；
  - 详尽剖析推理链条中的因果推演（Reasoning Path）；
  - 展开候选方案之间的实质差异对比（Difference Matrix）；
  - 充分补充客观证据（Evidence）、边界极值、已知反例、不确定性区间与次生影响。

### 3.4 严格正交组合律
Human 可以根据自身认知状态与任务需求，在两维空间中自由组合：

| 深度 \ 语言门槛 | 专业 (Professional) | 有术语 (Term-guided · 默认) | 大白话 (Plain Language) |
| :--- | :--- | :--- | :--- |
| **简要 (Concise)** | 术语密集、极高压缩比的专家速记 | 提炼核心结论与关键概念的紧凑摘要 | 用日常大白话直奔要点的一句话结论 |
| **标准 (Standard · 默认)** | 规范的专业论述与标准技术报告 | **系统基准：平衡严谨性与普适可读性** | 清晰通俗、论据完备的常人可读说明 |
| **深入 (In-depth)** | 包含全量技术细节与数学/代码推导 | 结构化详尽展开的深度技术分析报告 | **极其透彻、机理展开、举重若轻的科普级精讲** |

**正交性底线禁令**：
* 严禁在规范与工程实现中形成“专业即深入”的错误等同（专业完全可以极度简要）；
* 严禁形成“大白话即简单/浅薄”的轻慢偏见（大白话完全可以进行极具穿透力的高深度推演）。

---

## 四、第三类：AI 自适应组织方式（Autonomous Organization）

除了语言门槛与内容深度这两个主控维度外，信息在微观上的组织结构呈现多样化：
* **直接说明**（Direct Exposition）
* **分步骤演进**（Step-by-step Flow）
* **横向比对**（Contrast & Comparison）
* **结构化表格**（Tabular Matrix）
* **时间时序流**（Chronological Sequence）
* **因果逻辑链**（Cause-and-Effect Chain）
* **问答解析结构**（FAQ / Diagnostic Breakdown）

### 4.1 核心原则：默认由 AI 自行决策组织方式
> **信息组织方式主要由 AI 根据当前语义对象的内在结构、信息类型与上下文目标自适应选择，不强制要求 Human 进行琐碎配置。**

**设计哲学根据**：
Human 的注意力是稀缺资源。人类不应为了看懂一个结论，还要在界面上先选择“该用对比还是该用表格”。
$$\text{Internal Adaptation Complexity} \neq \text{Human Configuration Complexity}$$
> **系统内部可以很复杂，不要把复杂配置重新甩给 Human。**

### 4.2 人类覆盖权
AI 自适应选择为默认行为。若 Human 主动显式提出特定组织要求（如“以表格对比”、“列出步骤”），系统必须响应人类指令，但不得强制要求用户每轮必选。

---

## 五、即时理解动作（Instant Explanation Actions）

为辅助 Human 快速击穿认知障碍，规范正式确立三项高频**即时理解动作**：

```text
┌─────────────────────────────────────────────────────────────┐
│             三项高频即时理解动作 (Instant Actions)          │
├─────────────────────────────────────────────────────────────┤
│ 1. 举例 (Example)  ── 通过具象案例将抽象逻辑实例化         │
│ 2. 类比 (Analogy)  ── 借助已知常识经验同构映射陌生概念     │
│ 3. 讲故事 (Story)  ── 通过情境化角色演进展现因果与影响     │
└─────────────────────────────────────────────────────────────┘
```

### 5.1 概念定位与瞬态性质
* **非语言门槛**：举例、类比、讲故事绝不是第四个“语言门槛”，它们是针对当前特定语义对象的**解释展开技法**；
* **非持久偏好**：它们是**瞬时、即开即用、按需触发**的即时动作，绝不属于会话长期默认状态；
* **核心等式**：
  $$\text{Expression Depth} \neq \text{Explanation Technique}$$
  $$\text{Instant Explanation Action} \neq \text{Expression State Change}$$

### 5.2 行为示例与状态保持
* **场景示例**：
  当前会话状态为 `[大白话 + 深入]`。Human 读到一段因果逻辑时感到吃力，点击了 `[讲故事]`。
* **规范响应行为**：
  系统围绕当前正在讨论的这一个语义对象，生成或切换为一段生动的情境化故事展开；
* **状态保护禁令**：
  系统生成故事后，**绝不得自动把当前会话的语言门槛篡改为“讲故事模式”**。后续其他段落与后续交互依然严格保持原本的 `[大白话 + 深入]`。

---

## 六、Human 显式即时切换能力

### 6.1 能力要求规范
在面向 Human 的交互呈现中，系统必须向 Human 提供**显式可见、极低认知门槛、即按即得的操作通路**，使人类能随时切换 Language Level、Detail Depth 或触发 Instant Explanation Actions。

### 6.2 严禁绑定具体前端 UI 控件
本规范规定的是人机交互体系的能力母法，**严禁在 L5.D1 规范中写死具体的 UI 控件形式**：
* ❌ 严禁冻结为必须是 Dropdown（下拉框）；
* ❌ 严禁冻结为必须是 Segmented Button（分段按钮）或 Tab 标签页；
* ❌ 严禁冻结为必须是右键菜单、悬浮气泡、图标或快捷键；
* ❌ 严禁限定界面的绝对排版坐标、像素边距或 CSS 样式类。

具体表现形式完全属于下游 **HB 基础设施 / Design System / 终端产品实现层** 的工程自由度。L5.D1 的底线要求仅一条：**Human 必须能够在当前交互视界内以合理负担显式触发表述切换。**

---

## 七、即时生效三准则（Immediate, Context-preserving, Reversible）

Human 显式触发任何表述适配动作后，系统必须严格符合以下三项黄金准则：

### 7.1 Immediate（即时进入流程）
* **规范正式含义**：Human 显式触发后，应直接进入当前对象的表述转换流程，无需 Human 重新提问、重新定位或重新建立上下文（不将其解释为工程零延迟保证）；
* **通俗配套大白话**：
  > **点一下就换讲法，不要让人再问一遍。**
* **绝对禁止倒退交互**：严禁强迫 Human 重新在输入框打字输入（如：“请你用大白话把刚才的话重新说一遍”）。

### 7.2 Context-preserving（保持上下文）
* **核心等式**：
  $$\text{Expression Switch} \neq \text{Context Loss}$$
  > **换讲法，不换题，也别让人重新找位置。**
* 切换表述形态时，系统必须严格保持：
  - 当前正在讨论的议题与任务目标不变；
  - 核心语义对象（Semantic Object）与事实绑定关系不变；
  - 当前交互所绑定的 Decision Context 与授权边界不变；
  - Human 当前的阅读视窗、焦点段落或定位标记不变。

### 7.3 Reversible（无损可逆）
* Human 的任何表述切换都是无损的探索性行为；
* Human 可以随时以同等低廉的成本，从“大白话”秒切回“专业”，或在“简要”与“深入”之间往复比对；
* 切换动作不产生任何单向破坏性、不可逆副作用。

---

## 八、表述切换不是重新裁定原任务 (Re-expression ≠ Task-level Re-reasoning)

系统必须在理论、协议与工程实现上坚决贯彻核心公理：

$$\text{Re-expression} \neq \text{Task-level Re-reasoning / Re-adjudication}$$
> **重新表述 ≠ 重新裁定原任务。**

### 8.1 概念严格界定（防止工程侧误读）
为防止被工程侧误读为“重述过程中模型不得进行任何语言组织或局部推理”，规范明确界定以下三者的根本边界：

1. **`Re-expression`（重新表述）**：
   对既有语义对象和既有结果换一种 Human-facing 表达（允许模型进行语言重组、修辞置换与通俗化自适应组织）；
2. **`Task-level Re-reasoning`（原任务级重新推理 / 重新裁定）**：
   重新打开原任务的事实形成、逻辑推演、价值判断或最终结论形成过程；
3. **`Content Correction`（内容修正）**：
   重述过程中若发现原内容本身存在客观问题，显式进行内容修正。

* **核心防线等式**：
  $$\text{Content Correction} \neq \text{Silent Re-expression}$$
  > **内容修正 绝不等于 静默重述。**

### 8.2 严格防线禁令
严禁将用户的表述切换点击偷梁换柱解释为：
```text
Expression Change  ≠  Task Restart                 (表述切换 绝不等于 重启任务流)
Expression Change  ≠  Re-search                    (表述切换 绝不等于 重新发起全网/本地检索)
Expression Change  ≠  Task-level Re-reasoning      (表述切换 绝不等于 重新裁定原任务事实与推理)
Expression Change  ≠  Judgment Change              (表述切换 绝不等于 变更价值裁定)
Expression Change  ≠  Semantic Change              (表述切换 绝不等于 修改正式业务语义)
```

### 8.3 真实性发现的显式处理规则
如果在重述或换讲法过程中，底层模型发现原事实数据、推理因果或结论本身存在客观问题：
* **必须显式进行 Content Correction**：“检测到底层数据/结论存在更正：……”；
* **严禁暗度陈仓**：必须坚守 `Content Correction ≠ Silent Re-expression`，绝对禁止借着“换一种通俗说法”的掩护，静默修改原始事实或结论。

---

## 九、同一语义对象，多种 Human-facing Representation

体系确立“单一语义对象，多态呈现适配”的解耦模型：

```text
               ┌─────────────────────────────────────────┐
               │    Semantic Object (唯一核心语义对象)   │
               │  (拥有事实真值、推导逻辑与 Decision 属性)│
               └────────────────────┬────────────────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         ▼                          ▼                          ▼
┌─────────────────┐        ┌─────────────────┐        ┌─────────────────┐
│ 专业 Representation │     │有术语 Representation│    │大白话 Representation│
└─────────────────┘        └─────────────────┘        └─────────────────┘
         │                          │                          │
         ├──────────────────────────┼──────────────────────────┤
         ▼                          ▼                          ▼
┌─────────────────┐        ┌─────────────────┐        ┌─────────────────┐
│ 举例解释镜像    │        │ 类比映射镜像    │        │ 情境故事镜像    │
└─────────────────┘        └─────────────────┘        └─────────────────┘
```

### 9.1 核心边界
$$\text{Different Expression} \neq \text{Different Semantic Object}$$
* 无论同一语义对象派生出多少套专业报告、大白话总结或故事案例，它们在语义本体论上**全属于同一个客观实体**；
* 绝不得因为生成了一份“大白话版本”，就在系统状态机中将其判定为另一个独立的派生事实。

### 9.2 工程解耦
关于多表述镜像的预先生成、流式惰性计算、LRU 缓存管理、版本向量对齐等具体技术实现，**全部留归下游 L6 与 HB 工程框架自主设计**，L5.D1 母稿保持理论纯洁。

---

## 十、局部转换与会话状态分离（Local vs Session）

规范严格区分**局部即时重述**与**整场会话表述状态**：

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                  表述适配作用域分离 (Scope Separation)                  │
├──────────────────────────┬──────────────────────────────────────────────┤
│ Local Re-expression      │ 作用于局部粒子 (单句、术语、单卡片、特定证据) │
├──────────────────────────┼──────────────────────────────────────────────┤
│ Current Session State    │ 作用于当前会话流 (整场对话、连续输出基调)    │
└──────────────────────────┴──────────────────────────────────────────────┘
```

### 10.1 Local Re-expression（局部重述）
* **适用对象**：特定的某一个词、某一行状态描述、某一张差异卡片（Difference）、某一条风险声明或某一段论据摘要；
* **行为特征**：Human 仅对该局部元素点击“大白话”或“举例”；系统仅就地刷新该局部元素；
* **边界保护**：
  $$\text{Local Re-expression} \neq \text{Session Expression State Change}$$
  局部元素的即时解释**绝对不改变整场会话的基础语言门槛与深度设定**。

### 10.2 Current Session Expression State（当前会话表述状态）
* **适用对象**：当前正在进行的整场交互会话（Session）；
* **行为特征**：Human 在全局或流式控制入口显式选择了全局档位（如将默认的“有术语”切换为“大白话”）；
* **生效联动**：
  1. 当前正在展示或生成的内容立即切换为新状态重述；
  2. 当前 Session 内后续输出默认沿用该状态；
  3. 持续生效直至 Human 再次显式切换。

---

## 十一、会话状态不自动升级为永久偏好

在时间尺度与主体意图上，规范确立坚决的防越权边界：

$$\text{Current Expression State} \neq \text{Persistent Preference}$$

### 11.1 防泛化禁令
* Human 在当前特定会话中选择“大白话”，**绝不等于**该 Human 是个“在所有业务场景下都只看大白话的人”；
* Human 在本次复杂排障中临时点击了“深入”，**绝不等于**以后该用户的全部任务默认都必须输出海量长篇背景；
* 严禁任何算法或系统私自进行如下越权推导：
  - ❌ 单次或少数会话的选择 $\rightarrow$ 自动写入用户长期画像；
  - ❌ 局部的习惯流露 $\rightarrow$ 自动变成跨业务、跨终端的无条件静默预设。

### 11.2 长期偏好的合法生成途径
长期偏好（Persistent Preference）的沉淀，**必须且只能通过已审议合法的 Preference Governance 体系**，并在得到 Human 显式确认（如“记住我的选择作为全局默认”）后方可生效。L5.D1 绝不承担长期偏好算法与数据库读写的职责。

---

## 十二、表述适配优先级（Precedence）

当存在多种表达指令或推断可能冲突时，全体系必须无条件服从以下优先级铁律：

```text
┌─────────────────────────────────────────────────────────────┐
│             表述适配决定优先级 (Expression Precedence)       │
├─────────────────────────────────────────────────────────────┤
│ 1. Human 当前显式选择 (Explicit Choice)                     │
│    └─► 最高权威，拥有绝对即时否决权与覆盖权                 │
│ 2. 当前会话表述状态 (Current Session Expression State)       │
│    └─► 会话级显式意图，覆盖长期默认                         │
│ 3. 合法长期偏好 (Persistent Preference)                     │
│    └─► 经过合法治理沉淀的 Human 长期习惯                    │
│ 4. AI 当前自适应推断 (AI Inferred Adaptation)               │
│    └─► 机器基于场景与内容特性的局部辅助优化                 │
│ 5. 系统默认 (System Default)                                │
│    └─► 终极保底基准：【有术语 + 标准】                      │
└─────────────────────────────────────────────────────────────┘
```

**核心法则**：
$$\text{Explicit Human Expression Choice} > \text{AI Inferred Preference}$$
> **Human 已经明确选了怎么跟他说，AI 就不要自作聪明改回去。**

---

## 十三、AI 局部自适应的弹性与边界

### 13.1 允许且鼓励的 AI 局部微调
Human 处于默认的“有术语”状态，并不意味系统生成的每一个句子都必须机械呆板地维持同一频率：
$$\text{Session Default} \neq \text{Every Sentence Must Use Same Form}$$
AI 完全被允许、且应当在以下情形进行适度的微观自适应：
* 遇到陡峭生僻概念时，主动附带一句精妙通俗的大白话比喻；
* 遇到多分支并列时，主动组织为清晰的分步骤条目；
* 遇到方案二选一时，主动并置生成横向差异表格。

### 13.2 绝对不可逾越的边界
AI 的局部自适应调整，**其强度与方向绝不得与 Human 当前的显式选择相抵触**。例如：当 Human 已经明确切换到“大白话”后，AI 绝不得主观臆测“这段话太专业无法通俗化”而强行擅自切回高门槛学术文风。

---

## 十四、讲故事、类比与举例的真实性边界

针对举例、类比与讲故事这三类即时动作，规范确立最高等级的真实性防线：

$$\text{Narrative Adaptation} \neq \text{Fact Transformation}$$
> **可以换讲法，不能为了好听把事实讲变了。**

```text
┌─────────────────────────────────────────────────────────────┐
│                 即时理解动作的真实性“五不准”                │
├─────────────────────────────────────────────────────────────┤
│ 1. 不准凭空伪造事实 (No Fact Fabrication)                   │
│ 2. 不准混淆真实案例与虚构寓言 (No Reality-Fiction Blurring) │
│ 3. 不准把类比逻辑当成物理运作机制 (No Analogy as Mechanism)│
│ 4. 不准颠倒或篡改原有的因果依赖 (No Causality Distortion)   │
│ 5. 不准隐去实质决策所依赖的重要约束 (No Constraint Omission)│
└─────────────────────────────────────────────────────────────┘
```

### 14.1 显式虚构标注义务
当 AI 采用情境故事或假设案例来辅助解释严肃业务、代码缺陷或财务法律概念时，**必须在醒目位置附带显式提示**（例如：*“以上为辅助理解的虚构情境类比，非真实历史交易”*），严防 Human 产生事实误判。

---

## 十五、适用 Human-facing 语义对象全景

表述适配绝非仅局限于聊天界面的对话气泡，它普适于 EHAI 体系中**所有需要被 Human 心智消费的语义对象**：

```text
┌─────────────────────────────────────────────────────────────┐
│                 表述适配适用的语义对象池                    │
├─────────────────────────────────────────────────────────────┤
│ 1. AI 结论与交付成果 (D1 Result / Conclusion)               │
│ 2. 候选方案与实质差异 (D5 Difference / D6 Branches)         │
│ 3. 证据链条摘要与溯源解释 (D3 Evidence / D4 Reasoning)     │
│ 4. 系统运行状态与等待说明 (D2 Fact & Status)                │
│ 5. 不可逆操作的潜在风险提示与影响预测                      │
│ 6. 需要 Human 进行 Authorize 的标的范围说明                 │
│ 7. 决策上下文环境 (Decision Context) 阐释                   │
│ 8. 系统帮助文档、引导教程与交互向导                         │
│ 9. 面向人的故障诊断与差异分析报告 (Error Explanation)       │
└─────────────────────────────────────────────────────────────┘
```

---

## 十六、与 L5 三项最低有效条件（Validity Checks）的承接

表述适配作为 L5 极简人类交互适配的派生规范，必须完全通过 L5 母法的三项最低有效检验门禁：

```text
┌──────────────────────────────────────────────────────────────────────────┐
│                   表述适配的三项最低有效条件核验                         │
├──────────────────┬───────────────────────────────────────────────────────┤
│ 1. 可达          │ 表述切换入口与适配产物，在当前 Attention Bound 与工作 │
│   (Reachability) │ 流通道中真实可触及，不隐藏在幽灵层级中                │
├──────────────────┼───────────────────────────────────────────────────────┤
│ 2. 可辨          │ Human 清晰可知当前处于何种表达状态，明确当前是同一语义│
│ (Distinguish-    │ 的重新表达而非新任务结论，且各档位差异清晰可辨        │
│    ability)      │                                                       │
├──────────────────┼───────────────────────────────────────────────────────┤
│ 3. 可响应        │ Human 拥有现实可用、极低负担的触发与回切路径，且机器  │
│ (Actionability)  │ 立即响应，无虚假挂起                                  │
└──────────────────┴───────────────────────────────────────────────────────┘
```

---

## 十七、与 HB 基础设施及工程落地的关系

### 17.1 职责交接矩阵
```text
┌─────────────────────────────────────────────────────────────┐
│ 1. EHAI L5.D1 派生规范                                      │
│    规定表述适配的理论母法、维度模型、瞬态动作与核心不等式   │
├─────────────────────────────────────────────────────────────┤
│ 2. HB (DeepBase 统一人机交互承载与呈现基础设施)             │
│    作为下游工程实现，承载并具象化 L5.D1 的能力需求          │
├─────────────────────────────────────────────────────────────┤
│ 3. Design System / UI Controls                              │
│    组件规约、状态指示器、切换交互模式、卡片排版规范         │
└─────────────────────────────────────────────────────────────┘
```

### 17.2 HB 的工程候选职责（非规范强制冻结代码）
HB 在后续 Delphi / 跨平台工程落地时，可根据本规范抽象并实现以下基础设施能力：
* `ExpressionStateContext`：管理当前 Session 与 Local 的表达参数；
* `RepresentationRegistry`：维护同一 Semantic Object 与多套表述镜像的映射；
* `OnExpressionChange`：分发表述切换事件并触发界面就地局部重绘；
* `InstantActionInvoker`：解耦分发举例、类比、讲故事等瞬时生成管道。

**母法底线声明**：上述类名、事件名与存储模型仅为下游工程候选，L5.D1 严禁提前冻结具体编程语言代码细节。

---

## 十八、核心边界不等式清单

本规范所立全部规则与约束，均严密收敛于以下 **14 项核心边界不等式**：

```text
1.  Language Level                  ≠  Detail Depth
    (语言门槛 不等于 内容深度)

2.  Expression Depth                ≠  Explanation Technique
    (表述展开深度 不等于 即时解释技法)

3.  Plain Language                  ≠  Shallow Content
    (大白话 不等于 讲浅)

4.  Expression Adaptation           ≠  Semantic Change
    (表述适配 绝不等于 篡改语义)

5.  Re-expression                   ≠  Task-level Re-reasoning
    (重新表述 绝不等于 重新裁定原任务)

    Content Correction              ≠  Silent Re-expression
    (内容修正 绝不等于 静默重述)

6.  Expression Change               ≠  Judgment Change
    (表述切换 绝不等于 变更裁定)

7.  Expression Change               ≠  Task Restart
    (表述切换 绝不等于 任务重启)

8.  Expression Switch               ≠  Context Loss
    (表述切换 绝不等于 上下文丢失)

9.  Different Expression            ≠  Different Semantic Object
    (不同的表现形式 绝不等于 不同的语义对象)

10. Local Re-expression             ≠  Session Expression State Change
    (局部微观重述 绝不等于 会话全局状态变更)

11. Current Expression State        ≠  Persistent Preference
    (当前会话表述状态 绝不等于 永久固化偏好)

12. Explicit Human Expression Choice > AI Inferred Preference
    (Human 显式表述指令 绝对优先于 AI 推断偏好)

13. Narrative Adaptation            ≠  Fact Transformation
    (叙事化展开 绝不等于 扭曲事实)

14. Internal Adaptation Complexity  ≠  Human Configuration Complexity
    (内部自适应的高复杂度 绝不等于 甩给人类高配置负担)
```

---

## 十九、显式非目标（Explicit Non-Goals）

为彻底杜绝规范边界无序蔓延，明确以下范畴**绝不属于 L5.D1 的规范职责**：
* ❌ 不制定大模型预训练、监督微调（SFT）或强化学习（RLHF）的具体训练标准；
* ❌ 不定义用户画像、认知档案（User Persona）的数据库持久化格式；
* ❌ 不定义长短期记忆（Memory）的存储、索引与过期淘汰算法；
* ❌ 不制定具体 Prompt 模板的编写规范与分词参数；
* ❌ 不制定前端具体的 UI 控件名称、CSS 样式类、Design Token 或颜色值；
* ❌ 不制定原生桌面（VCL/FMX）的具体窗口句柄、消息循环或组件 API；
* ❌ 不定义搜索引擎协议、联网检索算法或底层图谱查询语法；
* ❌ 不干预真实物理世界或底层执行器的对账逻辑（由 L6 负责）。

---

## 二十、建议的最小 Human-facing 控制模型

为保障极简人机交互的工程优雅性，推荐下游 HB 与交互设计系统收敛暴露**极简控制模型**：

```text
┌─────────────────────────────────────────────────────────────┐
│                 表述适配最小控制模型 (推荐)                 │
├─────────────────────────────────────────────────────────────┤
│ 1. 表述门槛 (Language Level):                               │
│    [ 专业 ]  |  [ 有术语 (默认) ]  |  [ 大白话 ]            │
│                                                             │
│ 2. 内容深度 (Detail Depth):                                 │
│    [ 简要 ]  |  [ 标准 (默认) ]    |  [ 深入 ]              │
│                                                             │
│ 3. 即时理解 (Instant Explanation Actions):                  │
│    [ 举例 ]  |  [ 类比 ]          |  [ 讲故事 ]            │
└─────────────────────────────────────────────────────────────┘
```

* **运行规则小结**：
  - 系统默认配置为：`【有术语】 + 【标准】`；
  - 组织方式（对比/步骤/表格等）由 AI 默认自主按需决定；
  - Human 可在任何时刻显式点击切换；
  - 切换立即在当前视界就地生效，保持上下文不丢失；
  - 会话级状态持续至下一次切换，绝不自动升级为永久全局 Preference。

---

## 二十一、待决议事项（Open Items）

以下事项保持规范开放，待后续跨层级或主控统筹审议：

1. **英文正式名称（English Canonical Name）**：  
   * **当前状态**：`OPEN / Not Frozen`  
   * **说明**：中文正式规范名称确定为《表述适配》。英文名称当前采用工作描述候选：`Expression Adaptation`，保持开放状态，暂不作正式 Canonical 冻结。
2. **跨会话长期偏好治理（Persistent Preference Governance）的正式承接机制**：  
   * **当前状态**：`OPEN`  
   * **说明**：明确其不属于 L5.D1 内部职责。其如何在 L6/L7、账号体系或全体系通用偏好服务中进行主权认证与合法生命周期存储，留待后续下游规范审议。

---


3. **L5.D1 理论母稿重开条件（Reopen Condition）**：  
   * **正式裁定约束**：L5.D1 理论结构自此正式冻结（Theory structure: FROZEN）。严格限制仅在出现体系级矛盾（system-level contradiction）或证明存在真正不可约新残余（genuinely irreducible new residual）时方可重新审议。

## 二十二、封版候选自检清单（Freeze Candidate Checklist）

在提交 Human Authority 终审裁定前，资料员已严格对照以下 17 项标准执行完整自检：

- [x] 1. **是否误改了 L5 Root？**（未修改；严格继承 L5 唯一核心约束与三项最低有效条件）
- [x] 2. **是否把本规范写成新的 EHAI 层？**（未设立新层；严格定界为 L5.D1 派生规范）
- [x] 3. **是否把“讲故事”错误放进专业→通俗的深度等级？**（已纠正；讲故事被正确定位为即时动作而非 Language Level）
- [x] 4. **是否正确区分 Language Level 与 Detail Depth？**（已确立正交分离律 `Language Level ≠ Detail Depth`）
- [x] 5. **是否保留“有术语”为默认？**（已正式指定“有术语”为系统默认基准）
- [x] 6. **是否允许“大白话 + 深入”？**（已在正交矩阵中明确支持高穿透力的通俗深入表述）
- [x] 7. **是否支持 Human 显式点击后直接进入流程？**（已确立 Immediate：显式触发后直接进入转换流程，无需人类重新提问建立上下文，非零延迟保证）
- [x] 8. **是否避免要求 Human 重新提问？**（已严令禁止倒退式交互，严禁要求重新打字提问）
- [x] 9. **是否保证切换不重启任务？**（已确立 `Expression Change ≠ Task Restart`）
- [x] 10. **是否保证切换不改变 Judgment？**（已确立 `Expression Change ≠ Judgment Change`）
- [x] 11. **是否保证 Re-expression 不等于 Task-level Re-reasoning？**（已明确重新表述非重新裁定原任务，严格区分 Re-expression、Task-level Re-reasoning 与 Content Correction，坚守 Content Correction ≠ Silent Re-expression）
- [x] 12. **是否正确区分 Local Re-expression 与 Session State？**（已确立粒子级局部重述与全局会话状态的严格隔离）
- [x] 13. **是否防止 Session State 自动升级为永久 Preference？**（已确立 `Current Expression State ≠ Persistent Preference` 禁令）
- [x] 14. **是否确立 Human Explicit Choice 高于 AI Inference？**（已确立五级优先级链，Human 显式指令绝对优先）
- [x] 15. **是否防止讲故事 / 类比造成事实失真？**（已确立 `Narrative Adaptation ≠ Fact Transformation` 与真实性五不准）
- [x] 16. **是否避免把具体 UI / 控件 API 写进规范？**（已彻底剥离控件、Token、CSS、组件类名，严守纯理论母稿界限）
- [x] 17. **是否保持英文正式名称 OPEN？**（已在元数据与 Open Items 中明确标注 `OPEN / Not Frozen`）

---
