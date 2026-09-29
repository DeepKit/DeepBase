# IDecisionModel 语言中立契约草案 (工程镜像与引用说明)

> **SSOT 唯一权威源声明**：  
> 本文件为**工程参考镜像 (Implementation Reference / Mirror Notice)**。  
> **唯一规范性权威源 (Authoritative Source of Truth)** 位于理论仓：  
> [`D:\_Progs\一元论\IDecisionModel-Language-Neutral-Contract-DRAFT.md`](file:///D:/_Progs/%E4%B8%80%E5%85%83%E8%AE%BA/IDecisionModel-Language-Neutral-Contract-DRAFT.md)  
> 任何对语言中立契约与 Schema 的修订，必须以一元论仓母稿为准，严禁在工程仓独立分叉编辑。

> **文档状态声明**：  
> **DRAFT / FUTURE CAPABILITY / NON-PRODUCTION / NO IMPLEMENTATION COMMITMENT**  
> 本文件为前瞻性标准化研究草案，严格定位于 HACI `THEORY CANDIDATE / RESEARCH EXPLORATION`。  
> 当前生产系统（AsWish / DeepBase / AXIS）**未实现、未引用、无 Provider、且本轮严禁编写任何代码与运行时集成**。

---

## 1. 核心设计公理 (Core Axioms)

1. **Probability $\ne$ Authority (概率不等于授权)**：
   - 决策模型（Decision Model）仅负责在有界特征空间中输出内部概率倾向、评分向量与判断信号；
   - 现实物理/业务行动的决定权与授权门禁（Authority Gate）永远归属于人类主体（Human Authority）与业务策略规则（Policy）；
   - 无论模型置信度（Confidence / Probability）多高，绝不自动赋予外部现实系统的任何执行权限。

2. **Model Probability $\ne$ Real-world Accuracy (模型概率不等于现实正确率)**：
   - 模型输出的概率分布仅代表该模型在给定特征与自回归/统计分布下的内部似然估计；
   - 内部数学概率不等于物理世界的客观准确率，在未经外部校准与证据核验前，严禁将其作为事实依据。

3. **Model Space $\ne$ Human Presentation Space (模型空间不等于展示空间)**：
   - Decision Model 可以在领域允许的任意有界离散集合或等级空间中进行评分与推理（候选数量 $K$ 可任意设定，不受展示层限制）；
   - 只有当候选进入人机交互层（如 EHAI / HB ChoiceDeck）呈现给人类专家时，才由展示适配层（Presentation Layer）依据注意力认知约束筛选收敛为 $\le 7$ 项有界候选。

4. **Model Rationale $\ne$ Objective Evidence (模型解释不等于客观证据)**：
   - 模型自生成的推导解释（Rationale）属于模型内部注意力或生成式自我阐述，具有幻觉与自洽伪装风险；
   - 客观证据必须通过独立哈希引用的外部不可篡改凭证（`evidence_refs[]`）进行锚定，两者必须在 Schema 中严格解耦。

5. **Honest Abstained / Out-of-Scope (诚实弃权与越界声明)**：
   - 模型必须具备对不确定、分布外或无足够证据支撑的查询进行显式弃权（Abstained）或声明超出认知域（OutOfScope）的能力，严禁在无知状态下强制输出高置信假象。

---

## 2. 三种核心 Primitive

```text
1. Binary (二元判断)
   - 判定空间：{True, False} 或 {Pass, Fail}
   - 输出：内部概率倾向向量、置信定级与判断信号

2. Choice (有限离散选择)
   - 判定空间：有限离散候选集合 {Candidate_1, Candidate_2, ..., Candidate_K} (K 不受 UI <= 7 限制)
   - 输出：各候选的内部评分与概率分布向量

3. Ordinal (有序等级评估)
   - 判定空间：有序评级序列 (例如：{Low, Medium, High, Critical})
   - 输出：各等级分布向量与期望分类
```

---

## 3. 语言中立 Schema 规范 (YAML/JSON 语义)

### 3.1 DecisionRequest

```yaml
DecisionRequest:
  request_id: string                # 唯一请求标识符 (UUID / TraceId)
  timestamp: timestamp              # 请求生成时间戳 (ISO-8601 UTC)
  object_context:
    object_id: string               # 共同认识对象唯一 ID (NodeId, ContactId 等)
    object_type: string             # 业务对象类型 (如 "SpecNode", "Contact", "ChangeSet")
    scope_boundary: string          # 认知与授权作用域边界 (如 "AsWish", "CRM.BizFollow")
    features: map<string, any>      # 提取出的结构化特征或观测上下文
  question:
    question_id: string             # 判断问题标识
    task_description: string        # 语言中立的任务/意图表述 (绝非特定 LLM Prompt 咒语)
    primitive: "binary" | "choice" | "ordinal" # 三种基础 Primitive 之一
  candidates:                       # 候选集 (Choice / Binary / Ordinal 选项定义)
    - candidate_id: string          # 候选唯一标识
      label: string                 # 候选摘要名称
      constraints: list<string>     # 候选约束或前置条件
  timeout_ms: integer               # 超时毫秒限制
```

### 3.2 DecisionOutcome

```yaml
DecisionOutcome:
  request_id: string                # 关联的 DecisionRequest ID
  status: "success" | "abstained" | "out_of_scope" | "error" # 显式执行状态
  model_id: string                  # 模型标识 (模型族名/版本/权重大纲)
  generated_at: timestamp           # 决策生成时间戳 (ISO-8601 UTC)
  distribution:                     # 概率分布向量 (非现实正确率)
    - candidate_id: string          # 对应候选 ID
      probability: float            # 内部判断概率 (0.0 .. 1.0)
      score: float                  # 模型内部评分 (原始 logit 或标度分)
  selected_signal: string           # 模型最高倾向或推荐候选 ID (仅作为信号输入)
  confidence: "low" | "medium" | "high" # 内部置信定级
  rationale: string                 # 模型自我推演解释 (非客观物理证据)
  evidence_refs: list<string>       # 外部客观不可篡改证据引用锚点 (SHA-256 / URI / Git Commit)
```

---

## 4. 与生产系统的边界隔离声明

1. **零代码实现**：本轮不编写任何 Delphi、Go、TypeScript 或 Python 运行代码。
2. **零 Provider 接入**：不接入任何真实本地或云端 Decision Model Provider。
3. **零生产系统侵入**：
   - AsWish 继续使用原有轻量语义服务与 Human 审查门禁；
   - AXIS 继续使用原有 F0/F1 授权门禁与微信自动化封禁策略；
   - DeepBase 继续使用原有 EHAI L1-L8 冻结规约与 THbChoiceDeck 控件。
4. **定位未来探索**：此草案仅供 HACI 理论在完成多系统实证、证据积累与人类裁决成熟后的标准化储备。
