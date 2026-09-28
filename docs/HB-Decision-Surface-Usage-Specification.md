# HB Decision Surface 调用规范 (Usage Specification)

> **文档编号**：`HB-SPEC-SURFACE-001`  
> **归属工程**：`DeepBase/docs/HB-Decision-Surface-Usage-Specification.md`  
> **任务关联**：`WO-HACI-MVP-HB-001`  
> **性质声明**：视觉语义与调用范式规范 (纯规范说明，零控件代码修改)  
> **适用范围**：AsWish、DeepAxis、DeepBase 及所有集成 `THbChoiceDeck` / `TEhaiInteractionContract` 的前端界面  

---

## 一、规范背景与核心原则

HB (Human-in-the-loop Bridge) 决策面板以 `THbChoiceDeck` 控件为视觉承载，旨在为人类（Human Authority）提供标准化、低认知负荷的判断操作表面。

### 核心硬约束 (Strict Invariants)
1. **NO CONTROL CODE CHANGE**：严禁修改 `DeepBase.VCL.HB.Choice.pas` 控件源码或 GDI+ 绘制引擎。
2. **0–9 统一交互语法保持不变**：
   - `1..7`：有界候选空间（Bounded Candidate Space，人类展示层严格 $\le 7$）。
   - `8`：换一批 / 重新生成（Regenerate，局域探索，零写入，无承诺）。
   - `9`：人类自由输入 / 框架否定（Human Override / Frame Rejection，主权逃逸安全阀）。
   - `0`：从容返回（Back Navigation，无承诺离开，不产生负罪感）。
3. **人类呈现空间 $\ne$ 模型计算空间**：
   - $\le 7$ 仅属于 **Human Interaction Surface** 认知收敛约束，绝非后端判断模型（Decision Model）的内在能力上限。

---

## 二、视觉字段语义映射规范 (Standard Surface Mapping)

业务端在装配 `THbChoiceDeck` 实例与 `TEhaiContextBinding` 时，**必须严格遵守**以下五大要素映射：

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ [ContextTitle] 共同认识对象 (Shared Object Context)                           │
│ [StepInfo]     当前问题 / AI 发现与理解                                       │
├──────────────────────────────────────────────────────────────────────────────┤
│ 1. [推荐] 候选方案 A                                                          │
│    Description: 候选说明与依据 (Rationale)                                   │
│ 2. 候选方案 B                                                                │
│    Description: 候选说明与依据                                               │
│ ... (最多 7 个候选)                                                          │
├──────────────────────────────────────────────────────────────────────────────┤
│ [StatusMessage] 差异显影、风险提示与前置门禁说明                                │
├──────────────────────────────────────────────────────────────────────────────┤
│ [8 重新生成]    [9 自由输入/框架否定]    [0 返回退出]                          │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 1. `ContextTitle` $\to$ 共同认识对象 (Shared Object Context)
- **语义定义**：明确人机当前协同审视的物理/逻辑实体，回答“**当前 Human 与 AI 正在共同处理什么对象？**”。
- **禁止内容**：禁止填入泛化口号或系统无意义默认串（如 `"HB Choice Context"`）。
- **标准范例**：
  - AsWish 规约场景：`"【对象】需求节点: func-inventory-sku · 库存唯一编码"`
  - AXIS 关系治理场景：`"【对象】联系人: 王总 (CRM-8021) · 商务跟进"`

### 2. `StepInfo` $\to$ 当前问题 / AI 发现与理解
- **语义定义**：AI 向人类汇报当前所处的判断阶段、已识别出的上下文特征或需要裁决的问题焦点。
- **标准范例**：
  - AsWish：`"【状态】已解析 3 个候选字段变更，待人类架构师审查"`
  - AXIS：`"【发现】休眠 45 天，近 3 日有动态互动，建议激活跟进"`

### 3. `Items 1..7` $\to$ 有界候选空间 (Candidate Space, $\le 7$)
- **语义定义**：AI 生成的离散建议选项，供人类比较、权衡与选择。
- **推荐标记**：仅允许在 1 号候选标注 `[推荐]`（`IsRecommended = True`）。**推荐不等于最佳，更绝不等于自动执行**。
- **`Description` 展开**：每一个 Candidate 必须透出其背后的依据（Evidence / Rationale Summary），不可仅有孤立标题。

### 4. `StatusMessage` $\to$ 差异显影、风险提示与门禁说明
- **语义定义**：显影本动作可能带来的现实影响、与历史 Baseline 的差异（Difference）以及安全合规提示。
- **标准范例**：
  - AsWish：`"【差异】将修改主键规则，影响 2 个下游视图；需人类显式签发 Baseline"`
  - AXIS：`"【注意】该动作将移出观察期进入意向名单；受控模拟外发，禁止直接触碰生产微信"`

### 5. 控制快捷键 `8 / 9 / 0`
- **`8` (Regenerate - 重新生成)**：
  - 纯探索动作（`8 != Judgment`），请求模型在当前对象框架内换一批候选。
  - 界面保持原参考视觉状态（半透明或提示），零 Canonical 变更。
- **`9` (Human Override / Frame Rejection - 自由输入与框架否定)**：
  - 人类主权逃逸安全阀。人类跳出预设 1..7 候选空间，补充未列出的方案或彻底推翻问题前提。
  - **三态分流**：
    - 局部候选拒绝 (`eokCandidateReject`)；
    - 替代表达 (`eokAlternativeExpression`)；
    - 框架级否定 (`eokFrameRejection`，如“都不是，目标对象本身已失效”，绝不强制折叠为 Option 4)。
- **`0` (Back Navigation - 返回退出)**：
  - 从容离开，`0 != Reject != Consent != Judgment`，绝不留下负罪感，不触发任何状态持久化或惩罚。

---

## 三、四工程接入映射速查表

| 要素 | AsWish (规约系统) | DeepAxis (关系治理) | DeepBase (共用层) |
| :--- | :--- | :--- | :--- |
| **Object** | `TSpecNode` (`func-*`, `mod-*`) | 目标联系人 / 账户 (`ct-*`, `acct-*`) | `ObservableObjectRef` |
| **ContextTitle** | 规约节点标题 (`Node.Title`) | 联系人姓名 + 组织 / 阶段 | `ContextTitle` |
| **StepInfo** | `Candidate Review: <CSID>` | 触点互动意图分析 / 阶段跃迁 | `StepInfo` |
| **Items 1..7** | 规约变更集候选方案 | 联系人经营策略建议 | `TEhaiCandidateSpace` |
| **StatusMessage** | 差异报告影响、Baseline 冻结提示 | A1 授权凭据状态、微信安全边界 | `StatusMessage` |
| **8 (Regen)** | `ExportPrompt` / 换一批变更方案 | 重新推理经营建议 | `emaRegenerate` |
| **9 (Reframe)** | 框架否定重构领域模型 | 否定联系人经营前提/换人 | `emaReframe` (`eokFrameRejection`) |
| **0 (Back)** | 退出变更预览，Spec 保持不变 | 退出决策面板，无任何外发 | `emaExit` |

---

## 四、合规验收检查清单 (Checklist)

- [ ] 调用端装配 `THbChoiceDeck` 时，`ContextTitle` 非空且具有明确领域实体指代。
- [ ] 候选项目数严格控制在 $1 \le N \le 7$。
- [ ] 1 号候选若标注推荐，未附带自动执行副作用。
- [ ] 9 号键输入能区分局部调整与框架否定，框架否定独立流转。
- [ ] 0 号键退出时没有任何后台静默决策落库。
