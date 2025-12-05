# UniBase 任务清单

本文件仅跟踪“待办/进行中”事项。
- 已完成任务请见 `history.md`
- Bug 修复请见 `bugfix.md`

---

## 待办（P3）

### INSIGHT-001: 实现洞见决策思维显影金路径 Workflow
- **状态**: ⏳ 未开始
- **说明**: 按 `07.02.Case-UniFlow-Insight-决策思维显影金路径-v1.0.md` 定义，在 UniFlow 中实现 `wf_insight_decision_gold` Workflow 及节点编排。

### INSIGHT-002: 实现洞见多角色决策相关 Python Skills 与聚合 Agent
- **状态**: ⏳ 未开始
- **说明**: 实现 `decision_coach/decision_critic/decision_mirror/decision_observer/film_generator` Python Skills 及 `advisor_synthesizer` Agent，输出形式符合洞见宪法中“陪伴与觉察优先”的要求。

### INSIGHT-003: 为洞见金路径增加 Guard 的“产品哲学校验”规则
- **状态**: ⏳ 未开始
- **说明**: 在 `guard_review` 节点增加对输出语气和内容的校验，避免直接替用户做决定或制造焦虑，将不符合洞见宪法的输出打回或重写。

### INSIGHT-004: 洞见 UI 支持“只想被陪伴 / 需要行动灵感”模式切换
- **状态**: ⏳ 未开始
- **说明**: 在洞见前端增加模式选择与开关，将用户是否需要“小步行动建议”的偏好传入 Workflow 上下文，并影响 synthesizer/film_generator 的输出形态。

### INSIGHT-005: 洞见金路径指标与审计埋点
- **状态**: ⏳ 未开始
- **说明**: 按 `07.02` 文档中第 5 节的指标设计，补充 `insight_decision_*` 系列指标与相关审计日志字段，确保可观察性与回溯能力。

## 已完成（P1）

### DELPHI12-001: Core 模块 Delphi 12 编译兼容性 ✅
- **状态**: ✅ 已完成 (78/78, 100%)
- **完成日期**: 2025-12-05
- **说明**: 修复 UniBase Core 模块在 Delphi 12.2 (RAD Studio 23.0) 下的编译错误
- **详细修复记录**: 见 `bugfix.md` BUG-028 ~ BUG-053

---

## 待办（P3）

### INSIGHT-001: 实现洞见决策思维显影金路径 Workflow
- **状态**: ⏳ 未开始
- **说明**: 按 `07.02.Case-UniFlow-Insight-决策思维显影金路径-v1.0.md` 定义，在 UniFlow 中实现 `wf_insight_decision_gold` Workflow 及节点编排。

### INSIGHT-002: 实现洞见多角色决策相关 Python Skills 与聚合 Agent
- **状态**: ⏳ 未开始
- **说明**: 实现 `decision_coach/decision_critic/decision_mirror/decision_observer/film_generator` Python Skills 及 `advisor_synthesizer` Agent，输出形式符合洞见宪法中“陪伴与觉察优先”的要求。

### INSIGHT-003: 为洞见金路径增加 Guard 的“产品哲学校验”规则
- **状态**: ⏳ 未开始
- **说明**: 在 `guard_review` 节点增加对输出语气和内容的校验，避免直接替用户做决定或制造焦虑，将不符合洞见宪法的输出打回或重写。

### INSIGHT-004: 洞见 UI 支持“只想被陪伴 / 需要行动灵感”模式切换
- **状态**: ⏳ 未开始
- **说明**: 在洞见前端增加模式选择与开关，将用户是否需要“小步行动建议”的偏好传入 Workflow 上下文，并影响 synthesizer/film_generator 的输出形态。

### INSIGHT-005: 洞见金路径指标与审计埋点
- **状态**: ⏳ 未开始
- **说明**: 按 `07.02` 文档中第 5 节的指标设计，补充 `insight_decision_*` 系列指标与相关审计日志字段，确保可观察性与回溯能力。

---

## 已完成（P3）

### DOC-002: 补充 QuickStart.md ✅
- **状态**: ✅ 已完成
- **完成日期**: 2025-12-02
- **输出物**: `docs/QuickStart.md` (433 行)

---

## 已完成（P4）

### PERF-002: SSH 连接复用优化 ✅
- **状态**: ✅ 已完成
- **完成日期**: 2025-12-02
- **文件**: `Core/UniBase.CLI.SSH.pas` (v0.2 → v0.3)

---

最后更新：2025-12-05 (Delphi 12 迁移完成)
