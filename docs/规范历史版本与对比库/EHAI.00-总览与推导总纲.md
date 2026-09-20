---
title: "高效 AI 人机交互体系（EHAI）体系总览与推导总纲"
subtitle: "Efficient Human-AI Interaction · System Overview, Source Map & Normative Index"
Status: Canonical Overview / Index v1.0
Nature: System Overview / Source Map / Normative Index (体系总览 · 法源地图 · 规范索引)
Authority: Derived from FROZEN L1–L6 specifications (派生自已冻结 L1～L6 规范母稿，非独立规范法源)
System: 高效 AI 人机交互体系 (EHAI · Efficient Human-AI Interaction)
Specification: 高效 AI 人机交互规范 (EHAI Specification)
Core Frozen Segment: L1～L6 (L1, L2, L3, L4, L5, L5.D1, L6 · FROZEN v1.0)
Future Review Segment: L7 (OPEN / Future Review Material)
Theory References:
  - 差异一元论 (Difference Monism) 及其认识论成果为重要理论来源之一（完整理论谱系法定定位另议）
  - ASTO.P03 《认识论：认知错误的必然性与证据化认知》
Engineering Realization: DeepBase (Delphi 软件框架) + HB (人机工程交互承载设施)
Author: 架构组 / 资料员
Reviewer: 老板 / 主控 (Human Authority)
Date: 2026-09-12
Revision Note: |
  2026-09-12 L1～L6 全部冻结后的体系总览与法源总索引重构校准:
    - 重新定义 EHAI.00 为体系总览、法源地图与规范索引，非独立规范法源；确立冲突时以对应层已冻结规范母稿为准
    - 撤销提前冻结的理论谱系定位：统一采用“差异一元论为重要理论来源之一，最终法定定位另议”安全口径，不提前法定归位
    - 确立当前已冻结核心段为 L1～L6（含 L5.D1），全部进入 FROZEN v1.0；L7 标记为 OPEN / Future Review Material（不建立法源）
    - 围绕六层已冻结唯一根问题重塑架构地图，彻底清除旧 L5/L6（L5 极简适配 ≠ HB 工程实现，L6 为双基底原语与三根，将 Assertion/Slice/Intervention 归位为派生结构，废除强制六阶段流程）
    - 清除旧 L3/L4 机械状态机语言，确立 Minimal Necessary Intervention、H/A/E 判定维度与 Profile 类型化输出、Context-bound 完成契约
    - 清除责任与 AI 权力的过强旧句，区分 Capability ≠ Authority 与 AI Recommendation ≠ Human Judgment，统一责任法理口径
    - 写入体系级运行时纪律：Normative Layering ≠ Runtime Sequence，严禁将分层机械实现为执行流水线
    - 明确 DeepBase / HB 为当前重要工程实现与实证路径，非 EHAI 理论本体成立的必要条件
  2026-09-09 EHAI.00 初稿建立 (Canonical v1.0 历史归档):
    - 建立 EHAI 体系四层血统链条与初步推导逻辑框架
---

# 高效 AI 人机交互体系（EHAI）体系总览与推导总纲
## Efficient Human-AI Interaction · System Overview, Source Map & Normative Index

> **【总览定位与法源边界声明】**  
> 本文件为 **EHAI 体系总览、法源地图与规范索引（System Overview, Source Map & Normative Index）**。  
> 本文件旨在对高效 AI 人机交互体系（EHAI）的核心哲学、各层唯一根问题、法源层级拓扑与规范母稿索引进行自下而上的全局性呈现与导引。  
> 
> **核心防线等式**：
> $$\text{EHAI.00 Overview / Index} \neq \text{Independent Normative Source}$$
> 
> **冲突裁决规则**：  
> **EHAI.00 本身不是与 L1～L6 并列或高于它们的独立规范法源。若本文件的任何描述与对应层已冻结的规范母稿发生冲突，一律以对应层的 FROZEN Canonical Master Specification 为准。严禁以 EHAI.00 反向自创新 Root、原则、Profile、状态机、产品合规要求或理论谱系结论。**

---

## 〇、理论母源与发展定位

### 0.1 理论来源安全口径
* **重要理论来源**：  
  > **差异一元论（Difference Monism）及其相关认识论成果是 EHAI 的重要理论来源。EHAI 在差异一元论完整理论谱系中的最终法定定位另议。**
* **保持理论审慎**：  
  体系保留历史上差异一元论对 EHAI 的哲学启发、概念溯源与认知映射，但**坚决不提前宣布最终法定谱系定位**；不得将 EHAI 提前升格为已定论的理论分支编号。

### 0.2 四重核心哲学启发
EHAI 从差异一元论及其认识论推演中汲取了四重根本性的思考基底：

1. **本体论启发：属集断裂 $\to$ 坚决反对 AI 拟人化**  
   - 人类具有生物实在性、有限生命时间、不可逆经验、痛苦与意义感知，处于真实的现实因果与责任关系中；  
   - AI 是符号计算、统计概率关联与参数推理的机器系统，无肉身痛苦，无存在焦虑，不天然拥有主体权利；  
   - **反拟人化防线**：机器必须显式呈现为计算、推理与认知辅助工具。人机协作的本质是**异质协作**，严禁在界面与交互中诱导虚假的情感依附或“人格平等”。

2. **认识论启发（回接 ASTO.P03）：局部性与可谬性 $	o$ 证据化认知与非破坏性驳回**  
   - 任何认识主体的认知都受限于其信息通道与时空局部性，认知错误是必然的，真理仅体现为基于证据的暂定有效性与持续修订过程；  
   - 机器输出本质上是基于模式与数据的推断，**永远不拥有全知全局真理**；  
   - **证据化与可修订**：AI 的重要结论必须带有可恢复的证据依据与不确定性标注；人类享有对 AI 输出进行质疑、驳回、修改与重置的通道保障。

3. **主体主权启发：$\text{Capability} \neq \text{Authority}$ $	o$ 算力不可兑换为主权**  
   - 无论 AI 在特定任务上的准确率达到何种高度，无论其推理速度超越人类多少倍，**能力绝不等于权力（Capability is not Authority）**；  
   - 机器算力不能自动兑换为主体权力；AI 可以在授权范围内自主推演与执行，但不得越界代行属于人类的终极价值裁决。

4. **实践论启发（回接和悦论 WSH）：差异是生长的契机 $	o$ 交互的目的是“认知擢助”**  
   - 差异（Difference）不是必须抹平的缺陷，而是认识深化与系统演进的动力；  
   - 拒绝用粗暴的黑箱全面替代人类，坚守**“认知擢助（Sponsorship）”**：人机交互应当保护人类的理解力、专注力与反思力，帮助人类在与机器协作中提升认知与实践能力，而非退化为被动的盖章机器。

---

## 一、EHAI 规范分层全景索引 (Normative Master Index)

EHAI 体系严格区分**已冻结核心规范段（L1～L6）**与**下游待推导候选（L7）**：

| 层级 | 中文正式名 | 状态 | 唯一职责摘要 | 对应规范母稿 / 索引 |
|:---|:---|:---|:---|:---|
| **L1** | **AI 人机认知哲学** | `FROZEN v1.0` | Human 与 AI 的根本认知、价值、权力与可谬根边界 | [`EHAI.01.L1-人机认知哲学.md`](./EHAI.01.L1-人机认知哲学.md) |
| **L2** | **AI 交付原则** | `FROZEN v1.0` | 面向 Human 的有效交付完成态规范 ($\text{AI Output} \neq \text{AI Delivery}$) | [`EHAI.02.L2-AI交付原则.md`](./EHAI.02.L2-AI交付原则.md) |
| **L3** | **AI 人类介入原则** | `FROZEN v1.0` | $H / A / E$ 三轴判定模型与五类 Human Involvement Profile 介入需求产生 | [`EHAI.03.L3-人类介入原则.md`](./EHAI.03.L3-人类介入原则.md) |
| **L4** | **通用 AI 交互协议** | `FROZEN v1.0` | 类型化交互完成规约 (Typed Context-bound Completion) 与双场分离 | [`EHAI.04.L4-通用交互协议.md`](./EHAI.04.L4-通用交互协议.md) |
| **L5** | **极简人类交互适配** | `FROZEN v1.0` | 最小化 Human 现实交互负担 (人的责任不能偷，人的麻烦尽量省) | [`EHAI.05.L5-极简人类交互适配.md`](./EHAI.05.L5-极简人类交互适配.md) |
| **L5.D1** | **表述适配** | `FROZEN v1.0` | L5 派生表述重述规范 ($\text{Re-expression} \neq \text{Task-level Re-adjudication}$) | [`EHAI.05.D1-表述适配.md`](./EHAI.05.D1-表述适配.md) |
| **L6** | **机器语义与介入基础设施** | `FROZEN v1.0` | 机器侧语义保真 (R1)、效力守界 (R2) 与现实效果闭环 (R3) | [`EHAI.06.L6-机器语义与介入.md`](./EHAI.06.L6-机器语义与介入.md) |
| **L7** | **产品实现边界** | `OPEN / Future Review` | 尚未正式推导，不建立法源（既有材料作为历史候选资产，待后续重新审议） | [`EHAI.07.L7-产品实现边界.md`](./EHAI.07.L7-产品实现边界.md) |

> **关于英文 Canonical Name 的说明**：各层英文 Canonical Name 尚未全部冻结的，保持 OPEN 状态，总览不越权提前冻结。  
> **关于 L7 的明确界定**：L7 当前处于 `OPEN / Future Review`。目录中若存在既有 L7 草稿，仅作为历史候选参考材料，绝不构成当前 EHAI 体系已生效的规范法源；不得引用其 PR 规则或未冻结符合性判定来约束当前体系。

---

## 二、六层核心根问题与职责地图

整个 EHAI 核心规范段自上而下严格由且仅由以下六大根问题驱动，各层职责严格定界、互不越权：

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              EHAI 六层核心职责地图                                     │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ L1｜AI 人机认知哲学                                                                    │
│     回答：Human 与 AI 最根本的认知、价值、权力和可谬边界是什么？                       │
│     核心：P1～P12 哲学原则、异质定界、反拟人化防线、责任哲学                           │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ L2｜AI 交付原则                                                                        │
│     回答：AI 已经形成认知、产物或执行结果后，怎样才算真正形成 Human-facing Delivery？   │
│     核心：AI Output ≠ AI Delivery；交付完成态结构；认知诚实与可检验性                  │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ L3｜AI 人类介入原则                                                                    │
│     回答：什么时候需要 Human？什么时候占用 Human 注意力？机器最多合法推进到哪里？      │
│     核心：Minimal Necessary Human Intervention；                                       │
│           H (必要性) / A (注意力时机) / E (执行门禁) 三轴正交判定；                    │
│           类型化输出：Inform / Provide / Judge / Authorize / Act；                     │
│           H0 ≠ Mandatory Silence；Need Authorization ≠ Need Repeated Authorization     │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ L4｜通用 AI 交互协议                                                                    │
│     回答：Human 介入以后，怎样形成正式、类型化、Context-bound 的交互完成？             │
│     核心：PI-1 Semantic Commitment Integrity (两场分离：Exploration ≠ Commitment)；   │
│           PI-2 Minimal Sufficient Interaction (机器多想人少填，保留 Frame Escape)；    │
│           PI-3 Context-Bound Typed Completion (算哪件就哪件，抗漂移，取消自动充分推定)│
├────────────────────────────────────────────────────────────────────────────────────────┤
│ L5｜极简人类交互适配                                                                    │
│     回答：当 Human involvement 确实必要且正式语义已明确，怎样让人只做必要的那一点，   │
│           而且现实负担最小？                                                           │
│     核心：人的责任不能偷，人的麻烦尽量省；降低认知与交互负担；保护不可替代的语义贡献； │
│           L5.D1 派生表述适配：Re-expression ≠ Task-level Re-adjudication               │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ L6｜机器语义与介入基础设施                                                              │
│     回答：当正式语义进入机器持续处理与现实介入后，机器如何在跨能力、跨时间和跨系统     │
│           流转中保持语义保真、效力守界与现实求实？                                     │
│     大白话：事情交给机器继续办以后，怎样保证不传歪、不越界、不把没办成说成办成？       │
│     核心：R1 Semantic Continuity (不传歪)；                                            │
│           R2 Qualification / Effect Integrity (不越权)；                               │
│           R3 Reality-Effect Closure (不吹嘘，Claim Strength ≤ Closure Strength)；      │
│           Minimal Semantic Grammar：Semantic Unit + Typed Semantic Relation            │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 跨层分工的绝对铁律
1. **L3 与 L4 的职责铁律**：
   $$\text{L3 decides which Human Involvement is required.}$$
   $$\text{L4 defines how that typed involvement is formally completed.}$$
   L3 全权负责判定是否需要人、何时介入、门禁卡在哪里，并输出所需 Profile；L4 全权负责定义该 Profile 在交互层如何以 Context-bound 的方式正式完成。L3 绝不规定按键弹窗，L4 绝不反向决定介入时机。
2. **L5 与 HB 的解耦铁律**：
   $$\text{L5} \neq \text{HB}$$
   L5 是关于“极简人类交互适配与负担压降”的理论规范；HB 是 DeepBase 中用于实现该规范的面向 Human 的工程承载设施。严禁把 L5 简写为 UI 控件层。
3. **L6 机器语义基石铁律**：
   L6 确立 **基底双原语（Semantic Unit + Typed Semantic Relation）**，高阶结构（Assertion、Slice、Intervention 等）全部归位为派生结构。现实效果闭环严格按 **Claim-strength-sensitive** 治理：
   $$\text{Reality Claim Strength} \le \text{Evidence-Supported Closure Strength}$$
   （现实主张有多强，证据就要有多强；你说多重的话，就得有多重证据。）

---

## 三、体系运行时纪律：Normative Layering ≠ Runtime Sequence

全体系在理解与工程实现 EHAI 时，必须坚守以下根本性的运行时解释纪律：

$$\text{Normative Layering} \neq \text{Runtime Sequence}$$

* **规范分层不等于软件物理执行流水线**：  
  EHAI L1～L6 表达的是规范职责归属、原则推演关系与法源约束拓扑，绝不代表实际软件运行时必须机械按照 `L1 → L2 → L3 → L4 → L5 → L6` 顺序单向线性流动。
* **合法非线性调度示例（非强制运行时）**：  
  在实际软件工程中，完全允许出现根据现实事件触发的跨层闭环调度。例如以下典型流转：
  ```text
  L6 (机器底层在持续运行中侦测到 Epistemic Qualification 变化或 Applicability Gap)
         ↓
  L3 (触发重新评估：重新判定 H / A / E 门禁与所需 Human Involvement Profile)
         ↓
  L4 / L5 (按需发起面向人类的极简类型化交互，并由 L5/L5.D1 进行低负担表述适配)
         ↓
  Human (人类完成必要且不可替代的语义贡献或价值定夺)
         ↓
  L6 (承接 L4 类型化完成证据，绑定 Context，执行受约束的现实介入操作)
         ↓
  Reality Closure (依据主张强度获取相称证据，完成现实效果对账闭环)
         ↓
  L2 Human-facing Delivery (向人类呈现真正符合交付完成态的最终产物)
  ```
  该示例清晰展示了规范分层的立体协同，证明规范分层是治理框架，而非拘泥代码流动的物理枷锁。

---

## 四、主体权力、能力与责任纪律

### 4.1 机器能力与人类主体权力的严格解耦
全体系坚决反对因技术能力提升而产生的越权幻觉，确立四大核心防线等式：

$$\text{AI Recommendation} \neq \text{Human Judgment}$$
$$\text{AI Inference} \neq \text{Human Goal}$$
$$\text{AI Capability Expansion} \neq \text{Authority Expansion}$$
$$\text{Capability} \neq \text{Authority}$$

* **合法机器运作**：AI 可以在合法授权、规则和明确适用的边界内，承担复杂的机器决策、深度推理、任务调度与自动化执行；
* **主权防线**：机器能力的扩展绝不自动带来权力的扩张。AI 绝不得因为算法置信度高、推演速度快而静默取得或替代属于 Human 的终极价值排序、目标设定与授权权力。

### 4.2 责任法理口径（去绝对化表述）
体系彻底废除“AI 永远不承担责任、一切后果由人类单方承担”的简单化旧表述，统一遵循 L1 冻结的责任法理口径：

> **责任不得凭空消失，也不得虚假转嫁。**  
> AI 系统及其开发者、部署者必须对系统本身的认知质量、推演诚实性、程序正确性与交付完整性承担属于自身的工程与法定责任，严禁利用形式确认界面将机器缺陷与失职甩锅给用户。  
> 具体的法律、组织、产品与行为责任，依据真实的控制权归属、有效授权、行为因果来源、合同约定与法律环境综合判定。

---

## 五、跨层工程承载与实证关系

### 5.1 EHAI Specification 与 DeepBase / HB 的关系
$$\text{EHAI Specification} \neq \text{DeepBase Implementation}$$
* **EHAI Specification**：是技术中立、架构完备的高效 AI 人机交互规范母稿，定义理论本体与核心交互约束；
* **DeepBase**：是当前用于工程化实现和承载 EHAI Specification 的 Delphi 软件框架，包含机器语义运行时、事件流与调度组件；
* **HB**：是 DeepBase 中面向 Human 的工程交互承载设施，负责将规范中的交互语义与完成标准转化为具体可感知的界面与操作流；
* **实现定位**：DeepBase 与 HB 是当前验证 EHAI 规范的重要工程实现与实证路径，但**绝非 EHAI 理论成立的唯一必要本体条件**。未来无论采用何种语言或框架（Rust、Go、Web），只要满足 L1～L6 规范约束，均属合格实现。

### 5.2 业务产品消费关系
* 业务产品（如 AsWish、唤金、各类自动化工具等）通过消费 EHAI 规范，保证其人机交互过程符合认知正义、语义保真与责任守界；
* 业务场景的丰富性为 EHAI 提供了不可替代的实证检验场；总览保留对跨业务场景实证共性的关注，但不将具体产品细节、硬编码契约或历史探索性假说上升为全体系通用规范。

---

## 六、结语：人机异质协作的长期正道

高效 AI 人机交互体系（EHAI）的建立，旨在为 AI 时代的严肃工作确立一条长期主义的健康轨道：

1. **破除盲目技术崇拜**：不把统计概率与生成算力神化为主体权力；
2. **破除虚无拟人玩具主义**：不把严肃的人机协作降格为无事实依据、无证据闭环的黑箱对话；
3. **坚守异质协作与认知擢助**：让机器做机器最擅长的事（海量搜索、结构提取、候选推演、自动化执行与现实对账），让人类行使真正不可替代的职责（价值定夺、目标选择、意图表达与伦理裁决）。

**各守其位，各负其责；保真守界，求实闭环。** 这正是 EHAI 规范体系所守护的人机协作正道。
