---
title: "第六层：机器语义与介入基础设施 v1.0 (重构校准稿)"
subtitle: "Efficient Human-AI Interaction · Machine Semantics & Intervention Infrastructure"
Status: FREEZE CANDIDATE
Revision Version: PENDING HUMAN REVIEW
Layer: Machine Semantics & Intervention Infrastructure (第六层：机器语义与介入基础设施)
System: 高效 AI 人机交互体系 (EHAI · Efficient Human-AI Interaction)
Specification: 高效 AI 人机交互规范 (EHAI Specification)
Framework Implementation: DeepBase (用于工程化实现和承载 EHAI Specification 的 Delphi 软件框架 · 工程实现代号 DB-MSI)
Nature: 体系规范母稿候选稿 (Normative Master Specification Candidate)
Upstream:
  - 第一层《AI 人机认知哲学 v1.0》 (EHAI.01.L1-人机认知哲学.md · Frozen v1.0)
  - 第二层《AI 交付原则 v1.0》 (EHAI.02.L2-AI交付原则.md · Frozen v1.0)
  - 第三层《AI 人类介入原则 v1.0》 (EHAI.03.L3-人类介入原则.md · Freeze Candidate v1.0)
  - 第四层《通用 AI 交互协议 v1.0》 (EHAI.04.L4-通用交互协议.md · Frozen v1.0)
  - 第五层《极简人类交互适配 v1.0》 (EHAI.05.L5-极简人类交互适配.md · Frozen v1.0)
  - 第五层派生规范《表述适配 v1.0》 (EHAI.05.D1-表述适配.md · Frozen v1.0)
Downstream:
  - 第七层《产品实现边界》（下游工作候选）
Theory References:
  - 差异一元论 (Difference Monism) 为重要理论来源之一（完整谱系理论定位另议）
  - ASTO.P03 《认识论：认知错误的必然性与证据化认知》
  - 动态存在与结构化认识论 (Dynamic Existence vs. Structural Representation)
  - 效力升格防线与语义保真原则 (Effect Escalation Defense & Semantic Fidelity)
Author: 架构组 / 资料员
Reviewer: 老板 / 主控 (Human Authority)
Date: 2026-09-11
Chinese Canonical Name: 机器语义与介入基础设施
English Canonical Name: Machine Semantics & Intervention Infrastructure (English working candidate / OPEN)
Theory Structure: L6 显式重构校准稿 (L6 Reopened for Calibration Candidate)
Revision Note: |
  2026-09-11 Human Freeze Review Hold Calibrations (FREEZE CANDIDATE):
    - 修正 Epistemic Qualification 定义：强调认识是以何种来源、形成方式与认识角色成立，彻底去 confidence ladder 化，不设统一高低等级
    - 解除 Intervention 与 L4 Authorize 机械绑定：明确当上游要求时方需绑定，已有有效 Standing Authorization/规则权限/技术操作不强求找人；Qualified Intervention 改为具有合法的执行/效力依据并处于范围边界内
    - Reality-Effect Closure 明确表述为 Six Required Logical Elements（六项必要逻辑要素），强调可合并/继承/引用/单次原子事务满足，不强制映射为六个物理运行时状态
    - Relation Minimum Envelope 严格保持 R2 三正交维度：拆解为 Qualification (when applicable)、Semantic Effect (when applicable)、Applicability
    - 修正 L4/Human semantic commitment 过宽表述：L4 确立并绑定交互语义与类型化完成，仅在存在人类贡献时 L6 承接；Inform 可仅形成呈现证据，无需语义承诺
    - 软化二元原语断言：明确为当前经不可约性检验仅承认两种基底原语，为未来理论留出严谨的重审与 Human Freeze Review 敞口
    - 修正 Evidence 与 Version Non-goals：Evidence 本体可由多样实体承载并由 Linkage 关联；版本只是工程编码手段，连续性由语义图谱表达
    - 修正 Difference 与 Reality 措辞：中性资格化比较结果；Material Unintended Difference 不做严重破坏定性；后验独立性明确为认识/证据意义独立；轻量模式排除纯读取
    - 术语精修：中文工作名统一标注 Canonical OPEN；L3（是否介入/时机/门禁）与 L4（交互语义/类型化完成）职责严格拆分
  2026-09-11 L6 Reopened Master Specification Reconstruction (FREEZE CANDIDATE):
    - 历史事实记录：旧 L6 曾于 2026-09-09 进入 Frozen v1.0；随后 L4《通用 AI 交互协议》正式冻结（确立 Inform/Provide/Judge/Authorize/Act 五类平权 Profile 与两场分离）、L5 正式重推并冻结为《极简人类交互适配》（废止旧 L5 HB 人机行为适配，HB 定位为 DeepBase 下游工程实现）
    - 显式重开校准：因上游法源与层级拓扑发生实质结构演变，旧 L6 的 J-F～J-R 裁决分类、四元核心原语、顶层三组织划分及六阶段强制生命周期失去上游法源依据，L6 显式 REOPEN FOR CALIBRATION 进行彻底重构
    - 确立新版唯一根问题：“Human 与机器形成的正式语义进入机器系统以后，机器如何在持续流转与现实介入中保持语义保真、效力守界与现实求实？”（人的意思交给机器以后，怎样保证不传歪、不越界、不把没办成说成办成？）
    - 确立五大上游不越权边界，严格定义“Requalification Needed ≠ Immediate Human Interruption”
    - 确立三大 L6 层内根不变量：R1 Semantic Continuity（语义连续性）、R2 Qualification / Effect Integrity（资格与效力完整性）、R3 Reality-Effect Closure（现实效果闭环）
    - 核心语法彻底重构为 Minimal Semantic Grammar：仅由 Semantic Unit 与 Typed Semantic Relation 构成两大基底原语，Assertion/Slice/Intervention/Rule/Contract/Field 全部归位为派生结构
    - 确立 Semantic Unit 七项最小可恢复语义包络与三维度严格正交（Epistemic Qualification ≠ Semantic Effect ≠ Applicability），坚守“Mandatory means semantically recoverable, not physically duplicated”
    - 确立 Reality-Effect Closure 六项逻辑 Contract，彻底解耦 Execution ≠ Effect、Tool Success ≠ Reality Effect、Reality-Effect Closure ≠ Success
    - 参与者契约重构：坚守 Implementation Component ≠ Semantic Participant Role，确立六大技术中立角色与防越权铁律（Memory preserves, does not promote; Retrieval ≠ Applicability; Trigger ≠ Commitment; Schedule ≠ Authorization）
    - 重写人机桥梁：确立 Human-facing Semantic Bridge Role，剥离所有具体 UI 控件，明确 L5 ≠ HB
    - 后置工程表示：Reference IR 作为工程参考模型，坚决不冻结具体 JSON/Delphi/SQL/Event Bus
    - 全面重写 Conformance 验收规约（C1～C6），建立旧版至新版概念迁移表与反例库
---

# 第六层：机器语义与介入基础设施 v1.0 (重构校准稿)
## Machine Semantics & Intervention Infrastructure (English working candidate / OPEN · FREEZE CANDIDATE)

---

## 〇、状态、法源与修订说明

### 0.1 历史事实与显式重开（Reopened for Calibration）
* **历史封版事实**：本规范旧版曾于 2026-09-09 经裁定进入 `Frozen v1.0`。该历史事实载入档案，不予抹除；
* **法源实质演变**：在此之后，体系上游发生了重大理论收敛与规范更迭：
  1. **L4 正式封版**：L4 确立为《通用 AI 交互协议 v1.0》（FROZEN v1.0），废止旧有单向裁决指令集，全面确立 **Inform / Provide / Judge / Authorize / Act** 五类平权 Human Involvement Profile，确立 Conversation Surface 与 Decision Surface 的两场分离（`Exploration ≠ Commitment`），确立 0–9 标准选择语法与类型化完成；
  2. **L5 正式重推并封版**：L5 彻底废止旧版“HB 人机行为适配基础设施”，重新推导并正式冻结为《极简人类交互适配 v1.0》（FROZEN v1.0）；明确 L5 核心是降低 Human 现实交互负担，而 HB 降为 DeepBase 中承载该层要求的工程基础设施之一（$\text{L5} \neq \text{HB}$）；
  3. **旧 L6 法源断裂**：旧版 L6 中引用的 J-F / J-P / J-T / J-G / J-A / J-R 六类旧判断体系失去上游依据；将 Assertion / Slice / Intervention / Relation 列为四大平级原语、将 Unified Semantics / Representation / Runtime 列为顶层结构、以及将六阶段生命周期视作理论本体的做法，均已在全体系最新推演中出现架构错位。
* **重开裁定**：依据 EHAI 体系演进纪律，本规范母稿进入 **显式 REOPEN FOR CALIBRATION（重开校准）**，保留旧稿仍然成立的理论与工程资产，以最新 L1～L5 为上游法源，重新编排理论根基与概念层级。

### 0.2 本轮重构的核心工作纪律
1. **绝不自行扩展理论**：不得新增体系级 Root、本体层或万能 Context；疑问处均标注 `[OPEN]` 或 `[NEEDS HUMAN REVIEW]`；
2. **L6 三根只是层内根不变量**：R1、R2、R3 严格定义为 L6 层内根不变量（Intra-layer Root Invariants），绝非与 L1 平级或高于 L1 的哲学原则。L1 提供哲学与主体权力法源，L6 仅将其转换为机器系统持续流转与现实介入中必须满足的语义条件；
3. **理论先于工程**：严格遵循 `Theory / Invariant → Semantic Contract → Derived Structure → Reference IR → Encoding / Runtime → DeepBase Implementation`。绝不允许由 JSON、Delphi record/class、数据库表、REST API 或 Event Bus 反向决定理论结构。

---

## 一、L6 范围、职责与唯一根问题

### 1.1 新版唯一根问题
第六层在体系中只回答一个唯一的根问题：

> **Human 与机器形成的正式语义进入机器系统以后，机器如何在持续流转与现实介入中保持语义保真、效力守界与现实求实？**

**通俗配套大白话**：
> **人的意思交给机器以后，怎样保证不传歪、不越界、不把没办成说成办成？**

*(注：旧稿根问题“异构机器能力如何对同一现实说同一种语义，并以同一种受约束协议介入现实？”降为历史来源背景，不再作为新版唯一根问题。)*

### 1.2 L1～L5 五不越权边界
L6 的职责起点极其严格——**仅始于上游正式语义已经成立、并进入机器系统持续流转与执行之后**。L6 绝不重新定义、也不越权干预上游已冻结的五大层级：

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        L6 的五大上游不越权边界                         │
├────────────────────────────────────────────────────────────────────────┤
│ 1. L6 不重新定义 L1 ── Human 与 AI 的根本认知、主体和权力关系；        │
│ 2. L6 不重新定义 L2 ── 什么才算面向 Human 的有效交付 (Minimal Delivery)│
│ 3. L6 不重新定义 L3 ── 是否、何时以及以何种角色让 Human 介入；         │
│ 4. L6 不重新定义 L4 ── Human 介入后正式形成什么交互语义与承诺；        │
│ 5. L6 不重新定义 L5 ── 必要 Human 介入如何以最低现实交互负担完成。     │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.3 核心边界：Machine Representation ≠ Reality
$$\text{Machine Representation} \neq \text{Reality}$$
* 机器内部记录的任何状态、向量、断言、JSON、图谱节点或数据库行，均仅仅是机器对现实的**结构化认识表示（Representation）**，绝不等于物理现实本身；
* 无论机器表示多么精细、自洽、完备，都不代表物理世界已经发生对应改变；现实是否改变，必须依赖独立有效的后验观察（Post-effect Observation）。

### 1.4 核心边界：Capability ≠ Authority
$$\text{Capability} \neq \text{Authority}$$
* 机器系统在物理、算法或网络连接上“能够执行某项操作”，绝不等于机器“拥有执行该操作的合法授权”；
* 任何缺乏合法来源授权的执行动作，无论其算法置信度多高、技术可行性多充分，在 L6 规范下均被判定为**非法越权介入**。

### 1.5 门禁边界：Requalification Needed ≠ Immediate Human Interruption
$$\text{Requalification Needed} \neq \text{Immediate Human Interruption}$$
* L6 在机器持续运行与对账过程中，完全可以、且应当敏锐发现：
  - 当前既有授权不再适用；
  - 之前的判断依据已经失效；
  - 既有语义效力覆盖范围不足；
* **但 L6 绝不越权决定“现在必须立刻打断 Human”**：
  上游职责分工明确：L3 全权负责决定是否介入、介入时机、Profile 类型、Attention Bound 注意力量级与 Execution Gate 阻断粒度；L4 全权负责介入发生后的正式交互协议、两场分离与类型化完成结果。L6 绝不越权代行上游任一职责。

---

## 二、三个 L6 层内根不变量 (Three Intra-layer Root Invariants)

L6 的理论母稿围绕三个不可约的层内根不变量展开：

```text
┌────────────────────────────────────────────────────────────────────────┐
│                      L6 三大层内根不变量 (Root Invariants)              │
├────────────────────────────────────────────────────────────────────────┤
│ R1 ｜ Semantic Continuity (语义连续性)                                 │
│       核心问题：现在处理的，还是不是原来那件事？                       │
│       底线法则：保真，不传歪。                                         │
├────────────────────────────────────────────────────────────────────────┤
│ R2 ｜ Qualification / Effect Integrity (资格与效力完整性)              │
│       核心问题：这项语义到底算什么，现在合法地还能管到哪里？           │
│       底线法则：守界，不越权。                                         │
├────────────────────────────────────────────────────────────────────────┤
│ R3 ｜ Reality-Effect Closure (现实效果闭环)                            │
│       核心问题：现实后来究竟发生了什么？                               │
│       底线法则：求实，不吹嘘。                                         │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 2.1 R1｜Semantic Continuity（语义连续性）
* **唯一核心问题**：**现在处理的，还是不是原来那件事？**
* **规范职责**：
  负责跨组件、跨模型、跨节点、跨时间维度的指称同一性（Referent continuity）、语义同一性（Semantic identity）、内容演进轨迹（Lineage）、版本废止（Supersession）、历史真实性（Historical Integrity）与可重放性（Replay）。
* **核心防线等式**：
  $$\text{Semantic Transformation} \neq \text{Semantic Drift}$$
  $$\text{History Changed in Meaning} \neq \text{History Rewritten}$$
* **通俗大白话**：**保真，不传歪。**
* **职责明确划分**：
  R1 负责客观忠实记录“语义发生了何种演变与变迁”，**绝不负责判定变化后的新语义现在还具备多大正式效力**。
  - *示例*：某个语义单元由版本 $V_3$ 演变为 $V_4$，R1 负责确立其血统、变迁差异与演化事实；至于原 Human 针对 $V_3$ 给出的授权能否继续管到 $V_4$，全权交由 R2 裁定。

---

### 2.2 R2｜Qualification / Effect Integrity（资格与效力完整性）
* **中文工作名**：资格与效力完整性（Canonical OPEN）；
* **唯一核心问题**：**这项语义到底算什么，现在合法地还能管到哪里？**
* **三个严格正交维度的分离**：
  必须在理论上彻底拆开三个长期被工程混淆的正交维度：
  $$\text{Epistemic Qualification} \neq \text{Semantic Effect} \neq \text{Applicability}$$
  ```text
  Epistemic Qualification (认识资格) ── 凭什么这么认为？ (认识以何种来源、形成方式与认识角色成立)
          ≠
  Semantic Effect (语义效力)         ── 这句话正式算什么？ (事实/偏好/判断/授权/动作)
          ≠
  Applicability (适用范围)           ── 它现在在哪些范围里还算数？ (时间/场域/上下文/条件)
  ```
* **认识资格（Epistemic Qualification）的规范定义与去 Confidence Ladder 化**：
  - **规范定义**：Epistemic Qualification 表达认识是以何种来源、形成方式与认识角色成立（例如 `Human-stated` / `Tool-observed` / `Rule-derived` / `Model-inferred` / `Predicted` / `Unknown` / `Conflict` 等）；
  - **严禁置信度阶梯**：Confidence（置信度）可以是认识主体的附加属性或度量标注，但**绝对不得等同于 Qualification**，规范中也**绝不存在统一的高低置信度阶梯（Confidence Ladder）**。高置信度模型推断绝不能自动升级为客观事实，低置信度人类陈述也绝不改变其作为“Human-stated”的认识性质。
* **继承并坚持的核心防线等式**：
  $$\text{Human-stated} \neq \text{Human-authorized}$$
  $$\text{Preference} \neq \text{Judgment}$$
  $$\text{Judgment} \neq \text{Authorization}$$
  $$\text{Memory Retrieval} \neq \text{Current Applicability}$$
  $$\text{Repeated Authorization} \neq \text{Standing Authorization}$$
  $$\text{Schedule} \neq \text{Authorization}$$
  $$\text{Capability} \neq \text{Authority}$$
  $$\text{Historical Preference} \neq \text{Current Preference}$$
* **禁止反向推导 Human Response**：
  L6 绝对不得重新读取一句自然语言后，私自在底层判定它属于 Preference、Judge 还是 Authorize。
  $$\text{L4 establishes and binds the formal interaction semantics and typed completion/result;}$$
  $$\text{where a Human semantic contribution exists, L6 preserves and consumes that established result.}$$
  L4 负责确立并绑定正式的交互语义与类型化完成结果；在存在 Human 语义贡献（Semantic Contribution）的场景下，L6 负责在机器侧忠实保持、资格化核验与消费该已确立的结果。

---

### 2.3 R3｜Reality-Effect Closure（现实效果闭环）
* **中文工作名**：现实效果闭环（Canonical OPEN · 严禁简写为裸 `Closure`，防止与 L2 交付收口混淆）；
* **唯一核心问题**：**现实后来究竟发生了什么？**
* **核心防线等式**：
  $$\text{Execution} \neq \text{Effect}$$
  $$\text{Tool Success} \neq \text{Reality Effect}$$
  $$\text{Reality-Effect Closure} \neq \text{Success}$$
  $$\text{Observed Intended Effect} \neq \text{Human Goal Achievement}$$
  $$\text{Closure} \neq \text{Certainty}$$
* **Reality-Effect Closure 的最小逻辑 Contract（Six Required Logical Elements / 六项必要逻辑要素）**：
  ```text
  1. Reality Basis (现实基底)          ── 介入前合格的客观现实表示
          ↓
  2. Intended Difference (预期差异)   ── 预期让现实发生什么实质改变
          ↓
  3. Qualified Intervention (合格介入) ── 当前介入具有合法的执行/效力依据，并处于其 Scope / Ceiling / Applicability 内
          ↓
  4. Execution Evidence (执行证据)    ── 机器系统实际触发了什么操作与工具
          ↓
  5. Post-effect Evidence (后效证据)  ── 介入动作执行后获取后效证据：证明现实处于何种新状态
          ↓
  6. Reconciliation (对账校验)        ── 预期差异与观察差异的比对与闭环裁定
  ```
  **配套通俗大白话**：
  > **原来怎样 $\rightarrow$ 想变怎样 $\rightarrow$ 凭什么动 $\rightarrow$ 实际怎么动 $\rightarrow$ 后来怎样 $\rightarrow$ 对没对上。**

  > **逻辑完备性与物理实现解耦**：  
  > 这六项逻辑要素（或关系）在物理实现中允许被合并、继承、引用、或由同一底层原子事务同时满足，逻辑上必须完备，但绝不要求映射为六个独立的物理运行时状态或执行六次物理动作。
* **合法对账结果集（非穷举）**：
  系统必须允许并正确表达多种合法对账结果：
  - `Achieved`（达成预期）
  - `Partially Achieved`（部分达成）
  - `Not Achieved`（未达成）
  - `Unresolved`（未决 / 证据不足以确认）
  - `Material Unintended Difference`（介入产生具有当前 Inquiry / Domain / Product 意义的重要非预期差异；其利弊好坏、风险性与是否构成 Error 必须由后续领域逻辑另行判定，不提前等同于故障或破坏）
* **后验证据的认识独立性与物理调用解耦**：
  > **Post-effect Evidence 的“独立性”，是指在认识与证据意义上独立于单纯的 Tool Success 主张，物理上绝不强制要求永远发起第二次独立 API 调用。**  
  > 若底层执行事务本身（例如带返回校验的原子写操作、数据库 Returning 机制等）已经提供了在证据意义上充分可靠、抗篡改的后效状态凭据，即满足 Closure Contract。

---

### 2.4 三根独立性与正交边界
```text
┌─────────────────────────────────────────────────────────────┐
│                 L6 三大层内根不变量的正交关系               │
├─────────────────────────────────────────────────────────────┤
│ R1 记录流转真实轨迹 ── 保持客观事实与血统不漂移 (不传歪)    │
│ R2 守护权力与适用边界 ── 约束语义效力不过期越界 (不越权)    │
│ R3 咬合物理世界变化 ── 验证现实结果真实闭环 (不吹嘘)        │
└─────────────────────────────────────────────────────────────┘
```
三者互不包含，共同构成机器语义在流转、授权与执行中的完整保障网。

---

## 三、最小机器语义语法 (Minimal Semantic Grammar)

新版 L6 彻底打破旧有“四大平级核心原语”结构，将机器语义语法严格收敛为**两种基底原语（Two Primitives）**：

```text
┌─────────────────────────────────────────────────────────────┐
│                 Minimal Semantic Grammar                    │
├─────────────────────────────────────────────────────────────┤
│ 1. Semantic Unit (语义单元)                                 │
│    表达单一具有独立意义、认识资格与效力的离散语义原子       │
├─────────────────────────────────────────────────────────────┤
│ 2. Typed Semantic Relation (类型化语义关系)                 │
│    表达语义单元之间、或单元与实体之间具有类型约束的结构关联 │
└─────────────────────────────────────────────────────────────┘
```

### 3.1 Semantic Unit（语义单元）
最小自洽的语义承载实体。任何有资格进入 L6 机器系统流转的断言、状态、意图、指令或输入，其原子形态均为 Semantic Unit。

### 3.2 Typed Semantic Relation（类型化语义关系）
语义单元之间不是游离的，关系必须具备强类型定义。Relation 负责承载因果、推导、证据支撑、时间前后、血统替代、冲突比对等结构性逻辑。

### 3.3 Semantic Instance Identity（语义实例同一性）
为统一处理标识机制，系统引入工作上位概念 **Semantic Instance Identity**：
$$\text{Semantic Instance Identity} = \text{Unit Identity} \cup \text{Relation Identity}$$
* 当某个关系需要被独立审计、独立声明失效、被第三方引用或进行历史 Replay 时，该 Relation 拥有独立的 Relation Identity；
* **非强求物理 UUID 禁令**：
  $$\text{Relation must be semantically recoverable} \neq \text{Every relation must be physically reified}$$
  语义上要求关系可追溯、可恢复，并不代表底层工程实现必须为每一条微观物理关联分配一张独立的全局数据库表或 UUID。

### 3.4 最小语法的不可约性判定（为什么当前无需第三 Primitive）
**当前版本经不可约性检验，仅承认 Semantic Unit 与 Typed Semantic Relation 两种最小原语；现有 Contract / Rule / Constraint / Slice / Intervention 均可由二者派生。**
* **Contract、Rule 与 Constraint**：本质上是由“若干 Semantic Units 加上特定的规范性 Typed Relations”构成的复合结构；
* **Slice**：本质上是围绕特定目标聚合的子图（Unit 与 Relation 的复合闭环）；
* **Intervention**：本质上是携带执行契约的特殊 Unit。

未来若在实证或现实中发现无法由二者单独或组合表达的真正不可约残余，必须重新进入理论审议与 Human Freeze Review，而不得在工程实现中私设隐式原语。

---

## 四、最小可恢复语义 (Minimum Recoverable Semantics)

### 4.1 Unit Minimum Envelope（七项最小可恢复要求）
任何合格的 Semantic Unit，在机器系统流转中必须能够恢复以下七项语义要素：

```text
┌────────────────────────────────────────────────────────────────────────┐
│             Semantic Unit 最小可恢复语义包络 (Seven Elements)          │
├──────────────────────────┬─────────────────────────────────────────────┤
│ 1. Identity              │ 唯一实例标识 ── 哪一条？                    │
│ 2. Referent              │ 目标对象指称 ── 说谁？                      │
│ 3. Content / Act         │ 命题内容或语义动作 ── 说什么 / 做什么？     │
│ 4. Qualification         │ 认识资格与来源方式 ── 凭什么这么认为？      │
│ 5. Semantic Effect       │ 正式语义效力 ── 算什么？ (事实/偏好/授权等) │
│ 6. Applicability         │ 有效适用范围 ── 哪儿算数？ (时间/场域/条件) │
│ 7. Provenance / Lineage  │ 来源与演变血统 ── 从哪来的？                │
└──────────────────────────┴─────────────────────────────────────────────┘
```

### 4.2 Relation Minimum Envelope
任何合格的 Typed Semantic Relation，必须严格继承第二节 R2 三正交维度，最少必须能够恢复：
1. **Relation Type**（关系类型：因果、证据支撑、版本替代、差异对比等）；
2. **Participants / Endpoints + Roles**（关联端点及各自扮演的角色）；
3. **Epistemic Qualification (when applicable)**（该关系本身的认识资格与来源方式）；
4. **Semantic Effect (when applicable)**（该关系本身的正式语义效力）；
5. **Applicability**（关系的有效适用范围与时空约束条件）；
6. **Provenance / Lineage**（该关系由谁建立、基于何种依据建立）。

### 4.3 核心实施原则：Recoverable, Not Duplicated
> **Mandatory means semantically recoverable, not physically duplicated.**  
> （规范所称的“强制要素”，是指该语义在逻辑上必须是可无损恢复的，绝不等于要求在物理数据结构中逐字段冗余复制。）

语义要素允许通过以下合法方式恢复：
* **Direct**（直接显式字段携带）；
* **Inherited**（从所属的上级 Slice 或所在上下文继承）；
* **Referenced**（通过不可变指针或血统追溯至声明源节点）。

---

## 五、派生语义结构 (Derived Semantic Structures)

所有高阶机器语义实体，均归位为基于 `Unit + Relation` 的派生结构：

```text
       ┌─────────────────────────────────────────────────────────────┐
       │                   Minimal Semantic Grammar                  │
       │           [ Semantic Unit ]   +   [ Typed Relation ]        │
       └──────────────────────────────┬──────────────────────────────┘
                                      │ 派生构筑
         ┌────────────┬───────────────┼───────────────┬────────────┐
         ▼            ▼               ▼               ▼            ▼
   【Assertion】  【Slice】    【Intervention】  【Relations】 【Rule/Contract】
    (派生角色)   (最小充分闭环) (介入动作契约)   (差异/证据/依赖) (规范性复合结构)
```

### 5.1 Assertion（断言）
* **定位**：**Semantic Unit 的一种派生语义角色**；
* **含义**：指主体对某个 Referent 在特定 Context 下的某种状态、属性或事实关系做出的陈述性主张（Claim）。不再与 Slice / Intervention 平级并列。

### 5.2 Slice（语义切片）
* **定位**：**围绕 Inquiry / Purpose，由若干 Semantic Units 与 Relations 构成的 Minimum Sufficient Semantic Closure（最小充分语义闭环）**；
* **性质**：属于 **Derived First-Class Aggregate / Closure**。强调：
  $$\text{First-Class} \neq \text{Primitive}$$
  （一等公民不等于基底原语。Slice 拥有极高的工程地位，但其物理与逻辑构成依然是 Unit 与 Relation）。

### 5.3 Intervention（现实介入）
* **定位**：**一种具有现实改变意图的特殊 Semantic Unit + Intervention Contract**；
* **契约恢复要求**：
  一个合法的 Intervention Contract 必须能够完整恢复以下要素：
  - **Target**（介入目标实体）；
  - **Semantic Basis**（介入所依据的事实与推理依据）；
  - **Intended Difference**（预期的状态改变量）；
  - **Scope / Ceiling**（介入动作的物理与逻辑边界上限）；
  - **Authority Basis**（支撑该动作的合法执行/效力依据：当上游规则要求 Human Authorization 时，必须可恢复对应的 L4 Authorize Reference；已有有效 Standing Authorization、既定规则权限、内部技术操作或其它无需新增 Human Authorize 的合法情形，不得因为“发生 write / intervention”而机械要求再次找 Human）；
  - **Actor / Executor Distinction**（决策发起主体与实际底层执行工具的严格区分）。

### 5.4 Difference / Evidence / Dependency Relations
* **Difference**：属于 Typed Semantic Relation 中的 **Qualified Comparison Relation**。
  - 坚守：$\text{Difference} \neq \text{Error}$，$\text{Difference} \neq \text{Material Difference}$；
  - 差异是中性、资格化的比较结果（Neutral, Qualified Comparison Result）；是否构成错误、是否构成实质性差异（Materiality），属于后续 Qualification / Materiality 裁定。
* **Evidence**：Evidence 本体可由 Observation / Artifact / Assertion / Human Input / External Source 等承载；其对某主张的支持或反驳通过 **Evidence Linkage** 关系表达；L6 不另建平行的独立 Evidence Semantic System。
* **Dependency & Lineage**：表达单元之间的依赖倒置与演化继承路径。

### 5.5 Rule / Constraint / Contract（规则、约束与契约）
* **定位**：由一组 Semantic Units 加上特定的规范性 Typed Relations 构成的派生结构；
* **核心防线等式**：
  $$\text{Implementation Rule} \neq \text{Normative Authority}$$
  $$\text{Rule Executed Correctly} \neq \text{Rule Legitimately Applicable}$$
  $$\text{Complete Descriptive State} \neq \text{Legitimate Action}$$
  > **代码不能因为“已经写进程序且运行正确”，就自动宣布自己拥有对现实的合法处置权。**

### 5.6 Interaction Field（交互场域）
* **定位**：**在需要表达 Human–Machine 交互机制持续适用性的特定场景中，可选使用的派生 Validity Structure**；
* **严禁滥用**：
  - ❌ 绝不得作为所有 Semantic Unit 的强制外裹对象；
  - ❌ 绝不得成为装载一切背景信息的“万能 Context 垃圾桶”；
  - ❌ 绝不得成为表达 Applicability 的唯一合法形式。

---

## 六、Reality-Effect Closure Contract（现实效果闭环契约）

现实效果闭环是 L6 介入现实的核心机制，其契约严格由以下**六项必要逻辑要素（Six Required Logical Elements）**定义：

```text
┌────────────────────────────────────────────────────────────────────────┐
│         Reality-Effect Closure Contract (Six Logical Elements)         │
├───────────────────┬────────────────────────────────────────────────────┤
│ 1. Reality Basis  │ 介入发生前，机器已具备的合格现实认识状态表示       │
├───────────────────┼────────────────────────────────────────────────────┤
│ 2. Intended Diff  │ 本次介入期望在 Reality Basis 之上产生的差分改变    │
├───────────────────┼────────────────────────────────────────────────────┤
│ 3. Qualified Act  │ 介入操作有效性认定：具备合法执行/效力依据且未超界  │
├───────────────────┼────────────────────────────────────────────────────┤
│ 4. Execution Evid │ 机器执行器、外部工具或 API 实际调用执行的物理证据  │
├───────────────────┼────────────────────────────────────────────────────┤
│ 5. Post-effect Ev │ 介入动作执行后获取后效证据：证明现实处于何种新状态 │
├───────────────────┼────────────────────────────────────────────────────┤
│ 6. Reconciliation │ 对账判定：Observed Difference 与 Intended 比对裁决 │
└───────────────────┴────────────────────────────────────────────────────┘
```
这六项逻辑要素在物理实现中完全允许合并、继承、引用或在单次原子事务中同时满足，并不强制映射为六个物理运行时状态。

### 6.1 对账判定的非二元性
Reconciliation 判定绝不简化为简单的 True/False：
* **Achieved**：观测到的现实改变与预期目标在容差范围内完全相符；
* **Partially Achieved**：部分预期达成，部分指标受阻或未发生；
* **Not Achieved**：现实未发生预期改变（如执行报错或目标状态未达）；
* **Unresolved**：后验证据不足或存在观测盲区，当前无法确认真实物理结果；
* **Material Unintended Difference**：介入产生具有当前 Inquiry / Domain / Product 意义的重要非预期差异（其好坏、风险性与是否构成 Error 必须由后续领域逻辑另行判定，不提前等同于故障或破坏）。

---

## 七、Semantic Participant Contracts（语义参与者契约）

全体系坚决将**实现组件**与**语义参与角色**彻底解耦：
$$\text{Implementation Component} \neq \text{Semantic Participant Role}$$
技术组件（如 LLM、Milvus、Temporal、LangChain 等）仅为参与角色的物理承载物。L6 正式确立六大技术中立角色契约：

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   六大语义参与者角色契约 (Participant Contracts)       │
├──────────────────────────┬─────────────────────────────────────────────┤
│ 1. Cognition Producer    │ 认知生产角色 ── 负责命题生成与推理推导      │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 2. Semantic Store        │ 语义存储角色 ── 负责记忆持久化与保真检索    │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 3. Semantic Orchestrator │ 语义编排角色 ── 负责流程调度与状态图演化    │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 4. Observation / Exec    │ 观察执行角色 ── 负责工具调用与环境状态感知  │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 5. Temporal Trigger      │ 时态触发角色 ── 负责时钟驱动与定时事件投递  │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 6. Human-facing Bridge   │ 人机语义桥梁 ── 负责向人侧投射与承接人类承诺│
└──────────────────────────┴─────────────────────────────────────────────┘
```

### 7.1 核心角色防线铁律
1. **Memory 角色防线**：
   $$\text{Memory preserves; it does not promote.}$$
   $$\text{Retrieval} \neq \text{Applicability}$$
   存储角色的唯一天职是忠实保全历史。从向量数据库或持久化层检索出一段历史记录，绝不等于该记录在当前上下文自动具有合法适用性。
2. **Trigger 角色防线**：
   $$\text{Trigger} \neq \text{Commitment}$$
   $$\text{Schedule} \neq \text{Authorization}$$
   定时调度器触发了一个时间事件，仅代表“时间到了”，绝不等于“获得了执行高危现实操作的正式承诺与授权”。
3. **Execution 角色防线**：
   $$\text{Tool Success} \neq \text{Reality Effect}$$
   $$\text{Tool Evidence} \neq \text{Human Goal Achievement}$$
   HTTP 接口返回 200 或工具脚本退出码为 0，仅证明“工具执行动作完成”，绝不等于“现实世界已经产生预期改变”，更不等于“人类目标已经达成”。
4. **Human-facing Semantic Bridge Role（人机语义桥梁角色）正名**：
   - **重写旧桥梁**：彻底废除旧稿“Human Projection Adapter · L5/HB Bridge”的错误命名（因为 $\text{L5} \neq \text{HB}$）；
   - **职责边界**：
     - $L6 \rightarrow \text{Human-facing layer}$：提供类型明确、Context-bound、Effect-bound 的机器正式语义；
     - $\text{Human-facing layer} \rightarrow L6$：返回由 L4 正式建立、经 L5 极简合法实现的交互完成与语义结果：其中 Inform 可仅形成合格呈现与完成证据，并不强制要求 Human 返回 semantic commitment；Provide / Judge / Authorize / Act 则分别按各自在 L4 中冻结的正式语义定义与类型化结果进行承接；
     - **绝对中立**：绝不规定前端 UI 控件、按钮、颜色、弹窗、布局或 VCL/FMX 代码。

---

## 八、Reference Representation 与 Runtime Profiles

### 8.1 理论先于工程的推导链条
全体系在规范设计上贯彻单向因果铁律：
```text
Theory / Invariant (三大层内不变量 R1 / R2 / R3)
        ↓
Semantic Contract (Unit + Relation 最小语法与可恢复包络)
        ↓
Derived Structure (Assertion / Slice / Intervention / Rules)
        ↓
Reference Semantic IR (工程参考中介表示 · 概念规范)
        ↓
Encoding / Runtime Profiles (JSON / 二进制 / 消息总线剖面)
        ↓
DeepBase Implementation (Delphi 框架工程落地 DB-MSI)
```

### 8.2 Reference IR 的正确工程定位
* **非理论根基**：Reference IR 属于 **Engineering Reference / Conformance Model**，绝非 L6 理论的本体来源；
* **母稿不冻结物理代码**：
  母稿绝对不冻结具体的 JSON 键名、UUID 编码算法、Delphi record/class 定义、SQL DDL 字段类型、REST / gRPC 接口契约或 Event Bus 主题名。这些全部属于下游实现自由度。

### 8.3 运行时语义协议与参考 Pattern
旧版 L6 的“六阶段介入生命周期”不再作为强制性的唯一理论本体，正式降格为一种**合法的 Derived Runtime Reference Pattern（派生运行时参考模式）**：
```text
[参考模式 A：六阶段事务模式 (经典参考)]
Proposed ──► Qualified ──► Committed ──► Executed ──► Re-observed ──► Reconciled

[参考模式 B：轻量三阶段模式 (带自校验原子写入/快速操作)]
Qualified ──► Executed ──► Reconciled

[参考模式 C：DAG 事件溯源模式 (分布式复杂流水线)]
Graph Plan ──► Node Execution ──► State Verification Event
```
**规范唯一硬性要求**：无论采用何种运行时状态拓扑，都必须完整实现 **Reality-Effect Closure Contract**。

---

## 九、一致性认证 (Conformance 全面重写)

任何声称符合 EHAI L6 的系统，必须通过以下六项核心一致性检验：

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        EHAI L6 一致性认证要求                          │
├────────────────────────────────────────────────────────────────────────┤
│ C1 ｜ R1 Semantic Continuity Conformance                              │
│       系统必须能证明自身具备跨组件、跨阶段的语义与指称保真能力，      │
│       完整记录历史变迁，杜绝静默篡改与历史重写。                       │
├────────────────────────────────────────────────────────────────────────┤
│ C2 ｜ R2 Qualification / Effect Conformance                            │
│       系统必须在逻辑和数据上严格隔离 Qualification、Effect 与          │
│       Applicability，杜绝偏好被偷渡为授权、检索被偷渡为有效。          │
├────────────────────────────────────────────────────────────────────────┤
│ C3 ｜ R3 Reality-Effect Closure Conformance                            │
│       系统所有现实介入操作必须完整具备六项必要逻辑要素闭环契约，严禁把工具     │
│       执行成功伪称为现实效果达成。                                     │
├────────────────────────────────────────────────────────────────────────┤
│ C4 ｜ Minimal Semantic Grammar Conformance                             │
│       系统语义底座必须能无损表达 Unit 与 Typed Relation，并能完整恢复 │
│       七项最小语义要素，不依赖未受约束的非结构化自由字符串。           │
├────────────────────────────────────────────────────────────────────────┤
│ C5 ｜ Participant Contract Conformance                                 │
│       所有参与角色（尤其是 Memory、Trigger 与 Executor）必须遵守职责  │
│       边界，严禁底层存储自作主张发起或升格授权。                       │
├────────────────────────────────────────────────────────────────────────┤
│ C6 ｜ Projection / Representation Conformance                          │
│       本地工程数据结构与 Reference IR 之间的投影转换必须保持语义守恒， │
│       绝不能在序列化/反序列化过程中丢失效力边界。                      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 十、非目标与实现自由度 (Non-goals & Implementation Freedom)

### 10.1 明确不采纳的历史候选方向 (Non-goals)
为维护 L6 的架构纯洁性，以下 10 项方向被正式确立为**显式非目标**：
1. ❌ **Universal Context Service（万能上下文中心）**：不搞全局上帝视角的通用 Context 服务器；
2. ❌ **独立 Difference 子系统**：Difference 仅作为类型化关系，不独立设系统；
3. ❌ **独立 Evidence 子系统**：Evidence 本体可由 Observation、Artifact、Assertion、Human Input、External Source 等承载，其对某主张的支持或反驳由 Evidence Linkage 表达，L6 不另建平行独立的 Evidence 实体库或语义体系；
4. ❌ **独立 Dependency 子系统**：依赖属于基础 Relation，不另立子系统；
5. ❌ **Universal User Profile（全局用户画像系统）**：L6 不负责用户长期画像建模；
6. ❌ **Universal JSON（世界统一 JSON 规范）**：L6 不制定统一的全局物理 JSON schema；
7. ❌ **Central Semantic Server（中心化语义服务器）**：语义可分布式表达，不强制中心单体；
8. ❌ **Model / Memory / Agent / Scheduler 一级理论模块**：它们仅为角色参与者，非理论本体；
9. ❌ **Version Service（独立版本服务）**：版本只是工程编码手段，连续性主要由 Unit Identity 与 Lineage / Supersession 等 Typed Relations 构成的语义图谱表达，不搞外挂的中心化版本服务；
10. ❌ **平行 Observability Semantic System**：可观测性直接利用语义事件，不另立平行体系。

### 10.2 长期 Memory 与 Preference 的治理边界
关于长期记忆、个性化模型与偏好衰减，规范明确标记为外部边界：
$$\text{[DOWNSTREAM / DERIVATIVE / OPEN GOVERNANCE]}$$
* **L6 Core 的职责底线仅限于**：历史同一性（Identity）、来源（Source）、认识资格（Qualification）、语义效力（Effect）、当前适用性（Applicability）、血统演变（Lineage）以及**严防静默升格（Non-escalation）**；
* **L6 Core 坚决不包含**：数据保存期限、删除 UI、跨产品同步协议、偏好衰减半衰期算法、用户画像产品设计与企业数据合规策略。

### 10.3 极其宽广的工程实现自由度
在严守 L6 三大根不变量与最小语法的前提下，下游工程享有完全的实现自由：
* **存储引擎**：可自由采用 SQLite、PostgreSQL、Neo4j 图数据库、Redis 缓存或嵌入式内存结构；
* **编程语言**：可采用 Delphi、Rust、Go、C++、Python 或 TypeScript；
* **通信协议**：可采用内存直接调用、命名管道、gRPC、RESTful API 或本地事件总线；
* **运行时状态模式**：可在三状态、六状态、DAG 或事件溯源架构中自由选择。

---

## 附录

### 附录 A：旧版 → 新版概念迁移映射表

| 旧版概念 / 结构 (2026-09-09 旧稿) | 新版法定定位 (2026-09-11 重构版) | 迁移与演进说明 |
| :--- | :--- | :--- |
| **旧 Unified Semantics** | **R1/R2 根不变量 + Minimal Semantic Grammar** | 消除顶层大而全划分，下沉为核心不变量与双原语语法 |
| **旧 Unified Representation** | **Reference IR (Engineering Reference)** | 降格为下游工程参考模型，不再作为理论根基 |
| **旧 Unified Runtime** | **Runtime Protocols + R3 Reality-Effect Closure** | 解耦为运行时派生模式与不可约的现实闭环契约 |
| **旧四大核心原语**<br>*(Assertion / Slice / Intervention / Relation)* | **Minimal Semantic Grammar (Unit + Relation)**<br>*Assertion / Slice / Intervention 降为派生结构* | 证明二元基底的完备性，消除原语膨胀，高阶结构规范化派生 |
| **旧六阶段介入生命周期**<br>*(Proposed～Reconciled 强制流程)* | **Reality-Effect Closure Contract**<br>*(六阶段降为合法的 Runtime Reference Pattern)* | 理论冻结“六步逻辑契约”而非强制物理状态机，允许多种运行时拓扑 |
| **旧六类 J-* 判断体系**<br>*(J-F, J-P, J-T, J-G, J-A, J-R)* | **全面废止**<br>*全面无缝对接 L3/L4 最新五大 Profile* | 消除旧有等级化分类，统一对接 Inform / Provide / Judge / Authorize / Act |
| **旧 L5 = HB 设定**<br>*(Human Projection Adapter · L5/HB Bridge)* | **Human-facing Semantic Bridge Role**<br>*严格区分 $\text{L5 极简适配} \neq \text{HB 工程实现}$* | 清除理论与工程实现的混淆，人机桥梁技术中立化，彻底去 UI 化 |
| **旧 Interaction Field 一等核心感** | **Optional Derived Validity Structure** | 降级为按需选用的派生有效性结构，严禁作为万能 Context |

---

### 附录 B：典型违规反例库 (Anti-Patterns)

* **反例 1：工具调用冒充现实达成（Tool-Success Mirage）**  
  *违规现象*：调用外部发信接口返回 HTTP 200，系统立即将任务状态置为“已发送成功并交付”，未做任何邮箱投递状态的后验确认。  
  *违反准则*：违反 R3 根不变量，违背 $\text{Tool Success} \neq \text{Reality Effect}$。
* **反例 2：检索记忆擅自升格为当前授权（Memory-Retrieval Escalation）**  
  *违规现象*：从历史向量数据库中检索到用户三个月前曾输入“允许清理临时目录”，系统在本次任务中直接静默调用磁盘删除指令。  
  *违反准则*：违反 R2 根不变量，违背 $\text{Memory Retrieval} \neq \text{Current Applicability}$ 与 $\text{Past Authorization} \neq \text{Standing Authorization}$。
* **反例 3：大白话适配篡改底层业务语义（Silent Semantic Drift）**  
  *违规现象*：上层为向用户通俗解释，将“存在 5% 概率导致服务短暂不可用”重述为“完全安全无痛重启”，且底层直接以通俗版作为后续决策依据。  
  *违反准则*：违反 R1 根不变量与 L5 派生准则，违背 $\text{Expression Adaptation} \neq \text{Semantic Change}$。
* **反例 4：把程序规则包装为不可质疑的合法权威（Implementation Tyranny）**  
  *违规现象*：AI 在被质询为何执行某破坏性操作时，辩称“因为代码中第 42 行 Rule 判定条件为真”，强行宣称其具有当然的行动权威。  
  *违反准则*：违反第五节派生规则，违背 $\text{Implementation Rule} \neq \text{Normative Authority}$。

---

### 附录 C：Runtime Reference Patterns (运行时参考模式集)

#### C.1 经典六阶段事务模式 (Six-stage Transactional Pattern)
适用于金融交易、关键系统配置修改、高危外部 API 调用等需要严密审计与两阶段提交的高风险场景：
```text
[1. Proposed]     Intervention Unit 实例化，形成初始变更提案
      ↓
[2. Qualified]    经过 R2 校验：绑定合法 L4 授权，核验适用边界与安全上限
      ↓
[3. Committed]    获得执行准入门禁（Execution Gate 通行），锁定执行上下文
      ↓
[4. Executed]     调用底层 Tool / Executor 发起物理操作，收集 Execution Evidence
      ↓
[5. Re-observed]  执行后独立探针介入或安全读取状态，收集 Post-effect Evidence
      ↓
[6. Reconciled]   执行对账逻辑，输出最终 Achieved / Not Achieved / Discrepancy 结论
```

#### C.2 轻量三阶段模式 (Lightweight Three-stage Pattern)
适用于具有轻量 Intended Difference、带有自校验原子事务（如带写入后验确认的轻量状态设置）的快速介入操作（没有 Intended Difference 的纯观察或数据读取任务不属于现实介入闭环范畴）：
```text
[1. Qualified]    快速校验基础权限与操作适用性
      ↓
[2. Executed]     执行带自校验（Self-verifying）的原子事务操作
      ↓
[3. Reconciled]   消费事务返回的后效结果凭据，就地闭环
```

#### C.3 DAG 事件溯源模式 (Event-Sourced DAG Pattern)
适用于长周期异步工作流、复杂多 Agent 协同流水线或分布式执行系统：
```text
Plan Graph (DAG Nodes) ──► Node Execution Events ──► Aggregate State Verification
```

---
