# DeepBase 人类判断记忆与偏好沉淀模型规范
## DeepBase Core AI Human Judgment Memory & Preference Model Standard (v1.0)

> **法源地位**：DeepBase Core / AI 运行时人类判断沉淀与偏好检索单一法定母稿（SSOT）  
> **裁定时间**：2026-09-07（Human 架构裁定收口）  
> **适用层级**：`DeepBase Core / AI` 通用基础设施层  
> **核心受众**：DeepBase AI 运行时组、数据存储层、AsWish、唤金及所有下游智能体应用  
> **纯净性铁律**：本文档定义通用偏好数据结构与检索机制，**严禁包含“微信”、“销售”、“话术”、“SpecNode”等任何具体产品专有业务名词**。

---

## 1. 核心定位与设计哲学

在基于 HB 的选择式人机交互中，当用户通过 `[让我学习]` 原语显式确认了其选择原因后，系统必须将这一“人类判断过程”持久化为机器可理解、可检索、可溯源的偏好记忆资产。

### 1.1 核心定义
> **人类判断记忆（Human Judgment Memory）**：  
> 不是保存无意义的点击流日志，而是保存**“在何种上下文场景下（Context），面对哪些候选方案（Candidates），人类做出了何种取舍（Chosen vs Rejected），其显式认可的技术/语义原因是什么（Confirmed Rationale），以及该决策在何种范围内有效（Scope）”**的结构化认知数据。

### 1.2 阶段红线
* **存储并检索，不做黑盒微调**：第一阶段绝对不在本地或云端执行权重微调，一律采用**结构化记忆存储 + 场景指纹检索 + 提示词上下文注入 / 候选重排**。

---

## 2. 通用偏好数据结构契约（Schema Specification）

每个被用户确认的判断记忆记录定义如下（以强类型 JSON-Schema 表达）：

```json
{
  "$schema": "https://deepbase.org/schemas/ai-judgment-memory.v1.json",
  "title": "THbJudgmentMemoryRecord",
  "type": "object",
  "required": [
    "memory_id",
    "source_product_id",
    "scene_fingerprint",
    "chosen_candidate_id",
    "rejected_candidate_ids",
    "confirmed_rationale_tags",
    "scope",
    "confidence_weight",
    "created_at_utc",
    "is_active"
  ],
  "properties": {
    "memory_id": {
      "type": "string",
      "format": "uuid",
      "description": "判断记忆全局唯一标识"
    },
    "source_product_id": {
      "type": "string",
      "description": "来源应用标识 (如 'aswish', 'huanjin', 'deepaxis', 'cli')"
    },
    "scene_fingerprint": {
      "type": "object",
      "required": ["task_domain", "context_hash"],
      "properties": {
        "task_domain": {
          "type": "string",
          "description": "通用任务领域类别 (如 'text_generation', 'structure_refactor', 'diff_arbitration')"
        },
        "context_hash": {
          "type": "string",
          "description": "输入上下文环境特征摘要哈希"
        },
        "feature_tags": {
          "type": "array",
          "items": { "type": "string" },
          "description": "用于模糊匹配的场景特征标签 (如 ['cold_interaction', 'high_density', 'informal'])"
        }
      }
    },
    "decision": {
      "type": "object",
      "required": ["chosen_candidate_id", "rejected_candidate_ids"],
      "properties": {
        "chosen_candidate_id": {
          "type": "string",
          "description": "用户最终选中的方案标识"
        },
        "rejected_candidate_ids": {
          "type": "array",
          "items": { "type": "string" },
          "description": "同批被用户放弃的备选方案标识列表"
        },
        "chosen_features": {
          "type": "object",
          "description": "选中方案的结构化属性切片 (键值对)"
        }
      }
    },
    "confirmed_rationale_tags": {
      "type": "array",
      "items": { "type": "string" },
      "description": "用户在 [让我学习] 交互中确认的原因标签 (如 ['concise', 'no_pressure', 'type_strict'])"
    },
    "human_custom_note": {
      "type": "string",
      "description": "用户通过按键 [9] 补充的自定义说明文本 (若无则为 null)"
    },
    "scope": {
      "type": "object",
      "required": ["scope_type"],
      "properties": {
        "scope_type": {
          "type": "string",
          "enum": ["target_entity", "scenario_cluster", "global_weak"],
          "description": "适用范围：特定目标实体 | 同类场景聚类 | 全局弱偏好"
        },
        "target_entity_key": {
          "type": "string",
          "description": "当 scope_type 为 target_entity 时的实体唯一标识 (由下游产品传入)"
        },
        "cluster_key": {
          "type": "string",
          "description": "当 scope_type 为 scenario_cluster 时的聚类标识"
        }
      }
    },
    "confidence_weight": {
      "type": "number",
      "minimum": 0.0,
      "maximum": 1.0,
      "default": 1.0,
      "description": "偏好权重 (多次强化递增，被撤销或冲突时衰减)"
    },
    "hit_count": {
      "type": "integer",
      "default": 0,
      "description": "在后续推理生成中被命中的次数"
    },
    "created_at_utc": {
      "type": "integer",
      "description": "创建时间戳 (毫秒)"
    },
    "last_applied_at_utc": {
      "type": "integer",
      "description": "最后一次被下游调用的时间戳 (毫秒)"
    },
    "is_active": {
      "type": "boolean",
      "default": true,
      "description": "是否激活 (允许用户在偏好管理面板一键软删除或禁用)"
    }
  }
}
```

---

## 3. 偏好检索与注入机制（Retrieval & Injection Pipeline）

当系统再次面临类似 AI 任务时，DeepBase AI 运行时调度器执行四步闭环：

```text
       [ 应用层发起 AI 生成任务 (携带当前 ContextTags 与 TargetId) ]
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Step 1: 偏好匹配引擎 (Preference Matcher)                              │
│ • 精确匹配：target_entity_key == 当前 TargetId (权重 1.0)              │
│ • 场景聚类匹配：cluster_key 命中 且 feature_tags 重合度高 (权重 0.7)    │
│ • 全局弱偏好：global_weak 命中 (权重 0.3)                              │
│ • 排除 is_active == false 或被撤销的历史记录                          │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ 检出 Top-K 有效偏好规则
┌────────────────────────────────────────────────────────────────────────┐
│ Step 2: 注入与重排 (Injection & Reranking)                             │
│ 途径 A (Prompt 上下文注入)：                                           │
│   在 System / Developer Prompt 中挂载 [User Preference Constraint]     │
│   例如: "User explicitly prefers: concise, no_pressure in this scene"  │
│ 途径 B (候选重排 Reranker)：                                           │
│   对生成出的 1–7 候选进行打分，命中 confirmed_rationale_tags 者排位前置   │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ 生成候选
┌────────────────────────────────────────────────────────────────────────┐
│ Step 3: 偏好透明显影 (Transparency Trace)                              │
│ 生成结果附加 trace 元数据，供前端卡片展示：                           │
│ "根据你之前偏好【concise, no_pressure】的记录，已为你优先推荐本方案"  │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Step 4: 遥测与计数 (Telemetry)                                         │
│ 更新 hit_count 与 last_applied_at_utc；若用户再次采纳，提升置信度      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 4. 偏好生命周期与治理（Governance & Safety）

1. **防学错（Anti-Overfitting）**：
   单次判断**默认不得赋予全局生效（`global_weak`）**，必须要求下游应用在 `[让我学习]` 确认环节指定或默认限制为 `target_entity` 或 `scenario_cluster`。
2. **可撤销（Revocability）**：
   所有记忆记录必须支持前端界面的“撤销偏好（Undo/Revoke）”操作。一旦用户撤销，`is_active` 置为 `false`，并在本地持久化层写入撤销审计。
3. **隐私与隔离（Tenant/Product Isolation）**：
   各下游产品的数据通过 `source_product_id` 严格隔离。AsWish 的架构偏好绝不会被唤金检出，唤金的关系偏好亦不会干扰 AsWish 的规约推演。

---

## 5. 跨层指针

* **HB 偏好学习交互规范（UI 表现层母稿）**：  
  [`DeepBase/docs/ui/DeepBase-HB-AI-Preference-Learning-Interaction-Standard.md`](file:///d:/_Progs/02Business/DeepBase/docs/ui/DeepBase-HB-AI-Preference-Learning-Interaction-Standard.md)
* **唤金偏好业务语义（唤金消费母稿）**：  
  [`DeepAxis/docs/23-唤金顾问体系与四自接触点规范.md`](file:///d:/_Progs/02Business/DeepAxis/docs/23-%E5%94%A4%E9%87%91%E9%A1%BE%E9%97%AE%E4%BD%93%E7%B3%BB%E4%B8%8E%E5%9B%9B%E8%87%AA%E6%8E%A5%E8%A7%A6%E7%82%B9%E8%A7%84%E8%8C%83.md)
* **AsWish 偏好业务语义（AsWish 消费母稿）**：  
  [`AsWish/docs/03.规范-可见判断与交互规范.md`](file:///d:/_Progs/02Business/AsWish/docs/03.%E8%A7%84%E8%8C%83-%E5%8F%AF%E8%A7%81%E5%88%A4%E6%96%AD%E4%B8%8E%E4%BA%A4%E4%BA%92%E8%A7%84%E8%8C%83.md)
