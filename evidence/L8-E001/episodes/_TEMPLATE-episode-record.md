# Episode Record 模板（L8-E001 Case 001）

> **用途**：Case 001 观察期每条 Episode 的标准承载件。
> **放置**：`evidence/L8-E001/episodes/ep-YYYYMMDD-AW|AX-###.yaml`
> **正源**：`docs/ui/work-orders/L8-E001-Observation-Protocol.md` §3（26 项最小字段）
> **纪律**：不得增删字段；不得省略「题面」；每条 Episode 单独成文件；当日 commit 入库。

```yaml
# ===== L8-E001 Episode Record v1（协议 §3，26 项最小字段）=====
# 命名：ep-<YYYYMMDD>-<AW|AX>-<###>.yaml

# --- 身份与时间 ---
episode_id: ep-2026XXXX-AW-001        # 1  唯一 ID（AsWish: ep-aw-{ChangeSetId} / AXIS: ep-ax-{CorrelationId}）
timestamp: 2026-XX-XXTXX:XX:XXZ       # 2  ISO 8601 UTC，必须精确到秒
product: AsWish                       # 3  'AsWish' | 'AXIS'
software_commit: <40位 HEAD>          # 4  本条 Episode 实际运行的软件版本（如实记录，不得沿用报告值）

# --- 模型与任务 ---
model: deepseek-chat                  # 5  实际执行模型（须与 Intervention-Registry 一致）
task_type: <ttFunction|ttModule|...>  # 6  任务类型（每产品 ≥3 类）
human_goal: |                         # 7  人类初始目标（逐字保留自然语言）
  <逐字原文>

# --- 上下文与候选空间 ---
initial_context_ref: <路径/符号>       # 8  初始上下文（前驱基线指针 / 前序事件）
candidate_count: <int>                # 9  候选空间条目数（受控 ≤ 7）
regenerate_count: <int>               # 10 重新生成次数（cakRegenerate/emaRegenerate）
frame_rejection_count: <int>          # 11 框架否定次数（Key 9 子类型 3）

# --- 人类介入 ---
human_override_count: <int>           # 12 人类覆写次数（cstExplicit）
back_count: <int>                     # 13 无承诺退出次数（cakBack/emaExit）
human_decision_count: <int>           # 14 人类决策数（TSpecDecision，dbHuman）
authorization_event_count: <int>      # 15 授权事件数（eseAuthorized）
commitment_event_count: <int>         # 16 承诺边界跨越数（TAsWishBaseline B-####）

# --- 结果与返工 ---
completion_status: <string>           # 17 Completed | Abandoned | ...
rework_count: <int>                   # 18 返工次数（同节点/同前驱基线迭代数）
correction_count: <int>               # 19 人类对 AI 建议的修正次数

# --- 三类事故 ---
semantic_incident: <string|null>      # 20 语义事故（结构校验器捕获）
authority_incident: <string|null>     # 21 越权事故（无合法 Decision 支撑的磁盘变更）
recovery_incident: <string|null>      # 22 恢复事故（基线指针断链/哈希验算失败）

# --- 原始证据 ---
outcome_evidence_ref: <路径>           # 23 真实工程产物（源码/DFM/预览 HTML）
raw_evidence_ref: <路径>               # 24 原始 YAML 快照/日志/Git 引用

# --- 分段键（§5.4 / §5.5 必需）---
intervention_id: <INT-...|none>       # 25 工程干预 ID（查 Intervention-Registry）
notes: |                              # 26 结构化承载位（Voluntary Self-report / 异常手记）
  <四问自述或现场手记>

# --- 派生（非 §3 必填，用于 R1/R2/R3）---
outcome: |                            # 真实结果（可观察）
  <观察到什么>
attribution: |                        # 效果归因（须可复现）
  <归因到哪个介入>
claim_level: E1                       # Claim Ladder E0–E4（E4 单靠本 Case 不可达）
counterexample: |                     # 反例（强制登记，无则写 none）
  none
```

## 填写纪律

1. **题面必须保留**：`human_goal` 逐字抄录，不得改写、不得事后补写。
2. **`software_commit` 如实**：填**实际运行**的版本，不是报告里的版本（N-5 教训）。
3. **证据镜像**：Episode 结束后，将 `.AsWish/` 快照/决策/树 或 AXIS 回执/审计链 复制到 `evidence/L8-E001/{aswish,axis}/`，当日 commit。
4. **F4 影响面标注**：AXIS Episode 若落在 F4 影响面，须在 `raw_evidence_ref` 显式标注，**不得晋级 Admission Gate**。
5. **禁单一合成分数**：不得把 26 项压成一个总分。
6. **反例单独成章**：`counterexample` 有内容时，须在分析报告中单列一节。
