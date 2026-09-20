<!-- ===================================================================== -->
<!-- MIRROR / NON-AUTHORITATIVE COPY                                       -->
<!-- Canonical SSOT: EHAI/common-contract/EHAI-Language-Common-Layer-Overview.md -->
<!-- Downstream Delphi / DeepBase consumer mirror. Do NOT edit directly.   -->
<!-- ===================================================================== -->
# EHAI 语言共用层总览与工程承接架构

> **文档性质**：`APPROVED ENGINEERING BASELINE v0 / NON-NORMATIVE / LANGUAGE-NEUTRAL / DERIVED FROM EHAI`  
> **中文工作名称**：EHAI 语言共用层总览与工程承接架构  
> **英文工作描述**：EHAI Language-Neutral Common Realization Architecture Overview *(OPEN / NOT FROZEN)*  
> **权威地位**：下游 Delphi / DeepBase 消费镜像（MIRROR / NON-AUTHORITATIVE COPY）  
> **版本**：`APPROVED ENGINEERING BASELINE v0`  
> **制定日期**：2026-09-14  
> **法源地位**：非规范性工程架构母稿（Non-Normative Engineering Architecture）。本母稿派生自 EHAI 冻结规范，不属于理论规范，不具备理论法源效力。  
> **基线说明**：`APPROVED ENGINEERING BASELINE v0` 表示可作为后续语言实现与产品绑定工单的工程输入基线；它仍允许依据跨语言实现证据进行受控工程修订，不构成 EHAI 理论 Reopen。

---

## §0 最高纪律与权威边界

### 0.1 理论冻结与派生单向性
1. **母规范冻结效力**：`EHAI.00` 为 `APPROVED INDEX v1.0 (Non-Normative)`。**EHAI L1～L8 在当前 v1.0 版本中具有正式且受保护的理论效力**。本架构母稿属于下游工程承接文档，**严禁修改任何 L1～L8 冻结理论正文**。
2. **严禁理论扩张**：本工程层**不是 L9**，不增加新理论 Root，不定义新理论 Primitive，不构成新的 EHAI 规范法源。
3. **语义强度不越界**：语言共用层的语义强度必须满足：
   $$\text{Contract Meaning Strength} \le \text{Upstream EHAI Meaning Strength}$$
   严禁加强、缩窄、扩张、重定义上游理论，严禁将具体工程习惯写成普遍理论规范。
4. **派生权威约束**：工程实现的诉求与便利性**绝不具备反向修改理论的权威**（`Engineering Convenience ≠ Theory Revision Authority`）。

### 0.2 语言共用层的法定身份
- **是什么**：EHAI 语言共用层是**连接 EHAI 理论母规范与各编程语言具体实现之间的公共工程契约层**。它回答：
  > “不同编程语言必须共同理解和实现成什么机器语义、事件、状态转换与行为契约，才能在工程上忠实承接 EHAI 适用规范？”
- **不是什么**：
  ```text
  语言共用层 ≠ EHAI 新理论层
  语言共用层 ≠ L9
  语言共用层 ≠ EHAI Canonical Specification
  语言共用层 ≠ DeepBase
  语言共用层 ≠ HB
  语言共用层 ≠ AsWish
  语言共用层 ≠ AXIS
  ```

### 0.3 唯一跨语言工程真相源（Canonical Cross-Language SSOT）
为了消除“多 Master”架构分叉风险，确立以下 SSOT 治理规则：
1. **中立归属**：语言共用层契约母稿**不由 DeepBase / Delphi 单方面拥有**，物理归档于跨语言工程专用目录（`EHAI/common-contract/`）；
2. **理论隔离**：契约母稿**不混入 L1～L8 冻结母规范文件群**，保持理论与工程承接物理分离；
3. **平权消费**：DeepBase 仅作为 Delphi 语言运行时**消费 / 引用**该契约；Python、TypeScript 等未来实现与 DeepBase 享有**完全平权的消费地位**；
4. **镜像标注**：`DeepBase/docs/` 下的对应文件均为下游镜像，必须显式标注 `MIRROR / NON-AUTHORITATIVE COPY`。

---

## §1 架构背景与五层工程承接血统链

### 1.1 历史简化结构的局限
在早期工程探索中，下游承接曾简写为 `EHAI → DeepBase/HB → AsWish/AXIS`。该简写存在多重缺陷：
- 误使开发者将 EHAI 误解为 Delphi 专有技术体系；
- 混淆了“跨语言公共语义契约”与“Delphi 原生桌面呈现实现”；
- 阻碍了 Python、Web 前端等多语言运行时的正交接入。

### 1.2 最新正式五层工程承接架构
Human Authority 经战略推演，正式确立五层工程承接血统链：

```text
┌────────────────────────────────────────────────────────┐
│ 1. EHAI Canonical Normative Specification (L1～L8)     │
│                                                        │
│    回答：Human 与 AI 在交互中应满足什么哲学规范与法则？   │
└──────────────────────────┬─────────────────────────────┘
                           │ derives / constrains (约束与派生)
                           ▼
┌────────────────────────────────────────────────────────┐
│ 2. Language-Neutral Common Realization Contract        │
│    (EHAI 语言共用层 · 语言无关实现契约)                 │
│                                                        │
│    回答：不同编程语言必须共同理解和实现成什么可移植机器   │
│          语义、状态机模型与行为验证契约？                │
└──────────┬──────────────────────────────┬──────────────┘
           │ implements (跨语言共同实现)   │ implements
           ▼                              ▼
┌─────────────────────────┐    ┌─────────────────────────┐
│ 3a. Delphi Runtime      │    │ 3b. Python Runtime      │
│     (DeepBase 框架)     │    │     (Python 运行时)     │
└──────────┬──────────────┘    └──────────┬──────────────┘
           │ realizes / presents          │ realizes / presents
           ▼                              ▼
┌─────────────────────────┐    ┌─────────────────────────┐
│ 4a. Delphi Human-facing │    │ 4b. Python Human-facing │
│     Realization (HB)    │    │     Realization         │
└──────────┬──────────────┘    └──────────┬──────────────┘
           │ binds (领域语义绑定)          │ binds
           ▼                              ▼
┌─────────────────────────┐    ┌─────────────────────────┐
│ 5a. Delphi Products     │    │ 5b. Python Products     │
│     AsWish (Binding 001)│    │     (Agent / 自动化管道) │
│     AXIS   (Binding 002)│    │                         │
└─────────────────────────┘    └─────────────────────────┘
```

**横向扩展性**：未来接入 `TypeScript`、`C#` 等语言实现时，直接在第 3 层设立平行分支，无缝继承第 2 层契约，无需修改上游架构。

---

## §2 参与实体之定位校准与职责解耦

### 2.1 DeepBase 定位
- **正式定位**：**EHAI 语言共用契约的一种 Delphi 工程实现框架**。
- **职责边界**：
  - 在 Delphi 13.1 / Win64 平台上，提供支撑语言无关契约运转的底层运行时、数据通信、并发调度与基础设施服务；
  - **DeepBase 不拥有 EHAI 规范定义权**，严禁出现“`EHAI = DeepBase Specification`”的错误等同；
  - DeepBase 仅为当前已落地的一种具体语言实现路径，不构成 EHAI 对 Delphi 的单向依赖。

### 2.2 HB 定位
- **正式定位**：**DeepBase 中面向 Human 的交互承载、呈现与行为适配基础设施**。
- **职责边界**：
  - 负责在 Windows 原生桌面端，通过 VCL / FMX 控件群（如 `THbChoiceDeck`）、设计令牌系统与焦点调度机制，将语言共用层的抽象机器语义具体呈现给人类感知与操作；
  - **HB 不拥有跨语言语义定义权**。例如 `FrameRejection`、`HumanOverride` 属于跨语言公共语义，HB 只是其在 Delphi 原生桌面端的呈现载体；不能因为 Delphi 控件如何绘制，反向限制或独占该语义的跨语言定义。

### 2.3 AsWish 定位
- **正式定位**：**Reference Product Binding 001（参考产品领域绑定 001）**。
- **职责边界**：负责将抽象公共语义绑定至“**规格反向工程与需求推演**”业务领域。
- **专有领域封存**：`TCandidateIntent`、`TChangeSet`、`TSpecNode`、`Tree`、`Accepted Baseline`、`TSpecDecision` 等均属 AsWish 私有资产，**严禁上收到语言共用层**。

### 2.4 AXIS（唤金 / DeepAxis / 序枢）定位
- **正式定位**：**Independent Product Binding 002（独立产品领域绑定 002）**。
- **职责边界**：负责将抽象公共语义绑定至“**商业关系经营、客户资产与行为推进**”业务领域。
- **专有领域封存**：`Contact`、`Customer`、`Relationship`、`Touchpoint`、`Tag`、`话术`、`商业 Authority Gate` 等均属 AXIS 私有资产，**严禁上收到语言共用层**。

### 2.5 Python 分支架构说明
- **正式定位**：**Parallel Language Realization（平行的语言共用契约工程实现）**。
- **架构级血统**：
  ```text
  Language-Neutral Contract → Python Implementation → Python-facing Realization → Python Products
  ```
- **核心原则**：
  1. **零 Delphi 依赖**：Python 分支不依赖 DeepBase，不引用任何 Pascal 编译单元；
  2. **非转译性**：Python 分支直接依据语言无关契约进行符合 Python 习惯（Idiomatic）的原生实现，严禁“机械翻译 Delphi 源码”；
  3. **非绑定技术栈说明**：具体开发技术栈（如 Python 解释器版本、异步框架、数据模型库、存储方案、测试工具）由未来 Python 独立工程工单确定，本架构母稿不作硬性预设。

---

## §3 与 EHAI 规范层的边界澄清

### 3.1 与 L6《机器语义与介入基础设施》的边界
```text
EHAI L6 机器语义与介入基础设施
= Normative Machine Semantics (规范性机器语义理论法则)
        ≠
EHAI 语言共用层
= Portable Engineering Semantics (可移植的工程语义契约)
```
- **职责划分**：`L6` 规定机器状态、意图、证据与溯源应满足的规范哲学；`语言共用层` 将其转化为跨编程语言、无头可测的结构体规范、状态机抽象与测试向量；
- **单向保护**：严禁因为某门语言不好实现而要求修改 L6 理论。语言共用层只能忠实承接 L6。

### 3.2 与 L7《具体实现边界》的关系与三级验证门禁
在工程质量治理中，设立三级工作门禁（Verification Gates）：

```text
┌────────────────────────────────────────────────────────┐
│ Gate A: Scope-bound Fidelity Gate                      │
│                                                        │
│ 审查对象: EHAI 适用规范 → Language-Neutral Contract    │
│ 核心检验: 声明进入共用层范围的每个条目，其 EHAI 来源、  │
│           意义和效力是否被忠实保留？                    │
│ 范围规则: Contract Coverage ≠ Entire EHAI Coverage     │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│ Gate B: Language Implementation Fidelity Gate          │
│                                                        │
│ 审查对象: Language-Neutral Contract → Delphi / Python   │
│ 核心检验: 具体语言实现是否完整实现公共语义契约？        │
│           是否通过 Common Semantic Vectors 测试？      │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│ Gate C: Product Domain Binding Fidelity Gate           │
│                                                        │
│ 审查对象: Language Framework → AsWish / AXIS Product   │
│ 核心检验: 产品是否正确绑定领域语义？承诺边界是否守住？   │
│           有无 AI 静默越权修改权威业务状态？           │
└────────────────────────────────────────────────────────┘
```

#### Gate A 范围受约束保真原则（Scope-bound Fidelity）
语言共用层 v0 当前只承接声明范围内的可移植工程语义。**不得要求语言共用层覆盖 100% EHAI 理论**。未进入本契约范围的 EHAI 规范不因此失效或视为已实现（`Contract Coverage ≠ Entire EHAI Coverage`）。

---

## §4 公共能力上收治理机制 (Uplift Governance)

为保持语言共用层的长期整洁与跨语言纯粹性，新能力上收必须遵循严格的三级决策树：

```text
               下游提出新能力 / 交互需求
                         │
                         ▼
             【检查 1】是否为领域特有？
             (例如：软件规格树、商业客户画像、交易账单)
               ├── YES ───────────► 归入【产品层】(Product Layer)
               │                     (严禁上收)
               └── NO
                   │
                   ▼
             【检查 2】是否为编程语言 / UI 平台特有？
             (例如：VCL 消息循环、GIL、DOM 事件、输入框焦点)
               ├── YES ───────────► 归入【语言实现 / Surface 层】
               │                     (严禁上收)
               └── NO
                   │
                   ▼
             【检查 3】是否真正跨语言、跨产品共享人机交互语义？
             (例如：候选收敛、人类覆写、框架否定、不可逆承诺门禁)
               ├── NO ────────────► 不予处理 / 保持就地封装
               │
               └── YES
                   │
                   ▼
       晋升为【Common Contract Candidate】
                   │
                   ├── 必须完成 EHAI Frozen Source 真实法源核验
                   ├── 语义强度不得超过上游理论母稿
                   └── 必须编写语言无关 Common Semantic Vectors
```

**铁律**：即使某项能力成功晋升为 `Common Contract Candidate`，也仅代表工程公共契约的演进，**绝对不代表 EHAI 理论规范发生修改**。

---

## §5 语言共用层文档矩阵与 SSOT 指针

1. **总览与架构母稿（本文件）**：
   - 权威路径：`EHAI/common-contract/EHAI-Language-Common-Layer-Overview.md`
   - 消费镜像：`DeepBase/docs/EHAI-Language-Common-Layer-Overview.md`
   - 职责：多语言承接架构全景、实体定位、理论边界、三级门禁与上收治理。
2. **语言无关实现契约母稿**：
   - 权威路径：`EHAI/common-contract/EHAI-Language-Neutral-Realization-Contract-v0.md`
   - 消费镜像：`DeepBase/docs/EHAI-Language-Neutral-Realization-Contract-v0.md`
   - 职责：真实母规范渊源映射、跨语言抽象交互语义、状态效力契约、溯源模型与第一批公共语义验证向量（Common Semantic Vectors）。
3. **工程现状调查事实台账（非规范参考）**：
   - 归档路径：`DeepBase/docs/EHAI-Realization-001-HB-AsWish-CandidateFirst-0-9-HumanOverride-AsIs.md`
   - 职责：记录 Delphi / AsWish 历史现状代码证据。

---
*基线批准：2026-09-14*  
*执行主体：Antigravity Engine*  
*批准主体：Human Authority*
