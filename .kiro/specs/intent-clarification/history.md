# Intent Clarification Module - 开发历史

## Phase 1: 骨架实现（已完成 2026-05-13）

### 已完成任务

- [x] 1.1 创建 `DeepBase.IntentClarification.Types.pas` — 核心类型定义
- [x] 1.2 创建 `DeepBase.IntentClarification.Interfaces.pas` — 8 个接口 + 支撑类型
- [x] 2.1 创建 `DeepBase.IntentClarification.Engine.pas` — 引擎骨架
- [x] 2.2 创建 `DeepBase.IntentClarification.Session.pas` — 会话管理
- [x] 4.1 创建 `DeepBase.IntentClarification.Router.pas` — 姿态深度路由
- [x] 5.1 创建 `DeepBase.IntentClarification.OptionFrame.pas` — 0-9 选项框架
- [x] 6.1 创建 `DeepBase.IntentClarification.Provider.L0.pas` — L0 背景识别
- [x] 6.2 创建 `DeepBase.IntentClarification.Provider.L1.pas` — L1 指令型
- [x] 7.1 创建 `DeepBase.IntentClarification.Provider.L2.pas` — L2 问题识别
- [x] 8.1 创建 `DeepBase.IntentClarification.Provider.L3.pas` — L3 单专家
- [x] 8.2 创建 `DeepBase.IntentClarification.Provider.L4.pas` — L4 多专家圆桌
- [x] 10.1 创建 `DeepBase.IntentClarification.SignalDetector.pas` — 信号检测
- [x] 11.1 创建 `DeepBase.IntentClarification.Budget.pas` — 预算控制
- [x] 11.2 创建 `DeepBase.IntentClarification.Exit.pas` — 优雅退出
- [x] 12.1 创建 `DeepBase.IntentClarification.Degradation.pas` — 降级处理
- [x] 13.1 创建 `DeepBase.IntentClarification.Rapport.pas` — 融洽度层
- [x] 14.1 创建 `DeepBase.IntentClarification.Anticipation.pas` — 预判引擎
- [x] 16.1 创建 `DeepBase.IntentClarification.Templates.pas` — 预设模板
- [x] 17.1 创建 `DeepBase.IntentClarification.Moments.pas` — 微时刻
- [x] 17.2 创建 `DeepBase.IntentClarification.Storage.pas` — 持久化（初版 JSON 文件）
- [x] 18.1 更新 `DeepBase.IntentClarification.pas` — 便捷创建方法
- [x] 18.2 创建 `DeepBase.IntentClarification.Registration.pas` — 组件注册

### Phase 1 修复（评审后）

- [x] Engine 连线：SubmitInput 真正调用 Provider/Adapter/Presenter
- [x] Registration 实际注入组件到 Engine
- [x] IClarificationEngine 接口扩展配置方法
- [x] Storage 改为 SQLite（FireDAC）
- [x] L2/L3/L4 Provider 可配置 ModelTier
- [x] Budget 增加 token 追踪
