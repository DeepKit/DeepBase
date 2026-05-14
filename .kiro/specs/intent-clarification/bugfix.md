# Intent Clarification Module - Bug/问题记录

## BUG-IC-001: Engine 未真正调用注册的 Provider（已修复）

**发现时间**: 2026-05-13 专家评审
**严重度**: 🔴 高
**描述**: Engine.SubmitInput 的 ProcessLevel 是 placeholder，永远返回固定文本，不调用注册的 ILevelProvider
**根因**: 初版实现只搭了骨架，内部连线未完成
**修复**: 重写 Engine.pas，SubmitInput 现在执行完整 turn cycle（Signal→Route→FindProvider→Process→OptionFrame→Presenter）

## BUG-IC-002: Registration 是空壳（已修复）

**发现时间**: 2026-05-13 专家评审
**严重度**: 🔴 高
**描述**: TClarificationRegistration 的所有方法只做 nil 检查，没有把组件注入到 Engine
**根因**: IClarificationEngine 接口缺少配置方法
**修复**: 接口新增 SetDomainAdapter/SetPresenter/RegisterProvider/SetLLM/SetPersonaRegistry/SetAnticipationEngine，Registration 调用这些方法

## BUG-IC-003: LLM 调用模式不成熟（已修复）

**发现时间**: 2026-05-13 专家评审
**严重度**: 🟡 中
**描述**: L2/L3/L4 全部硬编码 TierFast，没有根据场景选择模型层级
**修复**: L2 默认 TierFast，L3 默认 TierBalanced，L4 专家用 TierBalanced、综合用 TierSmart，均可通过构造函数覆盖

## BUG-IC-004: Storage 使用 JSON 文件而非 SQLite（已修复）

**发现时间**: 2026-05-13 专家评审
**严重度**: 🟡 中
**描述**: 设计文档要求 SQLite 持久化，实际用了 JSON 文件
**修复**: 重写 Storage.pas，使用 FireDAC TFDConnection + TFDQuery，参数化查询

## BUG-IC-005: 未复用 DeepBase 现有基础设施（待修复）

**发现时间**: 2026-05-13 自检
**严重度**: 🔴 高
**描述**: 模块重复实现了 IoC、状态机、日志、配置、插件注册、弹性、指标等能力，未复用 DeepBase.IoC / StateMachine / Logging / Config / Plugin / Resilience / Metrics / DB.Factory / DB.Migrations / DB.Guardian / Validation / FeatureFlags / Services.Registration
**根因**: 开发时把模块当独立系统写，而非 DeepBase 框架的一部分
**修复**: Phase 2 重构（见 tasks.md）
