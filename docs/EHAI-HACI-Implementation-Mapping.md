# EHAI 到 HACI 最小工程非规范性映射说明 (EHAI-HACI-Implementation-Mapping)

> **文档编号**：`EHAI-NOTE-MAPPING-001`  
> **任务关联**：`WO-HACI-MVP-EHAI-001` (修订版)  
> **文档性质**：**NON-NORMATIVE ENGINEERING MAPPING (非规范性工程映射说明)**  
> 
> **最高红线与法源地位声明**：  
> 1. **EHAI L1～L8 CANONICAL SPECIFICATIONS FROZEN v1.0 处于绝对冻结状态，ZERO CHANGE。**  
> 2. **HACI 当前定位严格为：`THEORY CANDIDATE / RESEARCH EXPLORATION`（理论候选/研究性探索，非 FROZEN THEORY）。**  
> 3. **严禁宣称“HACI 已成为 EHAI 上游正式理论”或“EHAI 已升级为 HACI”。**  
> 4. 本文件仅作为技术对齐指南，表达：**HACI Research Exploration 中的最小工程探索概念，完全可由 EHAI 既有冻结规范提供法源解释与技术承接。**

---

## 一、映射架构与概念关系

EHAI 体系（L1～L8）是经过工程实证、严格冻结的跨语言人机交互架构基准。HACI 在最小工程落地中提炼的若干工程直觉，在 EHAI 体系中均已有完备且定义清晰的对应原语。

```text
┌────────────────────────────────────────────────────────┐
│     EHAI 冻结规约体系 (L1～L8 FROZEN v1.0)              │
│   (上游正式规范：哲学公理、交互契约、门禁、证据闭环)    │
└───────────────────────────┬────────────────────────────┘
                            │ 提供正式法源与接口承接
                            ▼
┌────────────────────────────────────────────────────────┐
│     HACI 最小工程探索 (THEORY CANDIDATE / RESEARCH)     │
│   (Shared Object, Candidate First, Human Authority)    │
└───────────────────────────┬────────────────────────────┘
                            │ 适配器与运行时映射
                            ▼
┌────────────────────────────────────────────────────────┐
│     下游工程生产落地载体                               │
│   (AsWish / THbChoiceDeck / DeepAxis / DeepBase)       │
└────────────────────────────────────────────────────────┘
```

---

## 二、核心法源对齐表 (Canonical Alignment Matrix)

依据主控终审裁决（R1～R6）与工单修订要求，HACI 核心工程概念与 EHAI L1～L8 条款精确映射如下：

| 序号 | HACI 工程概念 | EHAI 冻结规范法源条款 | 跨语言与 Delphi 载体承接 | 工程实施约束与红线 |
| :---: | :--- | :--- | :--- | :--- |
| **1** | **Shared Object**<br>(共同认识对象) | **L1 §1.2 共同认知场**<br>**L4 §6.1 上下文锚定** | `TEhaiContextBinding`<br>• `ContextId`<br>• `ContextTitle`<br>• `ObservableObjectRef` | 严禁全空 Default 泄露；<br>实体语义由 Binding 层动态构造；<br>AsWish Models 保持语言无关。 |
| **2** | **Candidate-first**<br>(候选优先协商) | **L4 §4.1 候选完备性**<br>**L4 §4.3 认知收敛** | `TEhaiCandidateSpace`<br>• 有界空间 $\le 7$<br>• `THbChoiceDeck.Items`<br>• Key 1 推荐标记 | 严禁凑数伪造选项；<br>推荐标记绝不自动执行；<br>允许“无可靠候选”空状态。 |
| **3** | **Decision Mechanism**<br>(协同判断模型) | **L2 §2.1 AI作为增强而非裁决**<br>**L6 §2.2 机器语义边界** | 语言中立 `IDecisionModel` 草案<br>• `Binary` / `Choice` / `Ordinal`<br>• `selected_signal` | **Probability $\ne$ Authority**；<br>模型输出判断信号，人类与策略决定外部授权；本轮严禁代码。 |
| **4** | **Human Authority**<br>(终局主权与逃逸) | **L3 §3.2 终局责任不移交**<br>**L3 §3.4 覆写逃逸权** | `9 Human Override`<br>• `emaReframe`<br>• `TSpecDecision` 人工裁决<br>• AXIS F0 门禁校验 | 终局责任永远不移交；<br>严禁超时自动代选；<br>9 号键具备逃逸最高优先级。 |
| **5** | **Frame Rejection**<br>(框架级否定原语) | **L4 §5.3 框架否定原语** | `eokFrameRejection`<br>• `SubmitFrameRejection`<br>• 架构重设独立分发 | 打破问题预设；<br>**绝不折叠为普通 Option 4**；<br>原样保留人类原声与更高层意图。 |
| **6** | **Difference Context**<br>(差异显影与自觉) | **L6 §6.2 认知漂移识别**<br>**L6 §6.4 差异分析** | `Difference Engine`<br>• `.AsWish/difference.yaml`<br>• 影响分析 (Impact Analysis) | **Difference $\ne$ Error**；<br>严禁未经比对直接覆写基线；<br>Impact 当前属展示层，暂不入库。 |
| **7** | **Evidence Loop**<br>(客观证据驱动闭环) | **L8 §8.1 客观证据不可替代**<br>**L8 §8.3 经验反馈回流** | `Outcome Feedback & Receipts`<br>• `evidence/` 版本受控库<br>• `flight-receipt.json` | **Agent Claim $\ne$ Evidence**；<br>严禁模型自我证明；<br>证据带 SHA256 哈希与签名。 |

---

## 三、条款法源深度阐释

### 1. 共同认识对象 (Shared Object $\longleftrightarrow$ L1 §1.2 / L4 §6.1)
- **理论基石**：EHAI L1 指出人机协同的前提是构建同构的“认知场”；L4 §6.1 要求任何动作必须通过 `TEhaiContextBinding` 显式绑定对象边界。
- **工程承接**：AsWish 在适配器层（`AsWish.Binding.HB.pas`）动态反查变更集与规格节点，注入具体的 `ObservableObjectRef`（如 `func-root`, `mod-orders`）与 `ContextTitle`，使人机始终对齐在具体对象上。

### 2. 候选优先与有界收敛 (Candidate-first $\longleftrightarrow$ L4 §4.1 / §4.3)
- **理论基石**：L4 §4.1 强调 AI 的核心功能是生成离散完备候选，将连续发散空间压缩为有界选项；L4 §4.3 从认知工效学要求展示空间必须满足米勒法则（$\le 7$）。
- **工程承接**：`THbChoiceDeck` 控件固化 1..7 有界卡片，1 号允许标记推荐，但语义严格锁定为“未承诺候选预览”，无回车不产生任何状态突变。

### 3. 判断与授权分离 (Decision Mechanism $\longleftrightarrow$ L2 §2.1 / L6 §2.2)
- **理论基石**：EHAI L2 与 L6 确立公理：机器生成的是置信度与概率信号，而非现实权力。
- **工程承接**：`IDecisionModel` 草案严格界定 `Probability != Authority`。模型内部概率分布即使高达 0.99，进入现实世界执行必须经过独立的 Authority Gate 门禁校验。

### 4. 框架否定不可折叠 (Frame Rejection $\longleftrightarrow$ L4 §5.3)
- **理论基石**：L4 §5.3 严格禁止将人类对预设前提的否定异化为既有候选的变种。
- **工程承接**：`THbChoiceAction` 的 9 号键三态区分 `eokFrameRejection`。当人类指出“这个问题本身就不该做”时，系统直接路由至目标重置或规约废止，严禁作为普通意见处理。

### 5. 证据不可替代 (Evidence Loop $\longleftrightarrow$ L8 §8.1 / §8.3)
- **理论基石**：EHAI L8 将协同真实性锚定于外部物理证据。
- **工程承接**：各系统独立落地真实凭证（AsWish 的 Git 冻结 Baseline、AXIS 的本地审计哈希收据、DeepBase 的 E001 日志），杜绝跨系统虚假胶水串联。

---

## 四、维护与审计纪律

1. **母稿不可篡改**：本文件生效绝不引发 EHAI L1～L8 规范的重新议定。
2. **术语使用口径**：在工程汇报、代码注释与对外技术文档中，必须坚持“EHAI 为冻结规范，HACI 为研究探索”，禁止混淆主次地位。
3. **技术合规门禁**：所有下游产品 Binding 必须能逐项映射到上述法源对齐表，否则判定为架构漂移（Architecture Drift）。
