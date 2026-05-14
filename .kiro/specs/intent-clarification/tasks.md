# Implementation Plan: Intent Clarification Module - Phase 2 重构

## Overview

Phase 1 完成了模块骨架和基本功能。Phase 2 的目标是**复用 DeepBase 现有基础设施**，消除重复造轮子，使模块成为 DeepBase 框架的标准公民。

## Tasks

- [x] 20. IoC 容器集成
  - [x] 20.1 重构 Engine 依赖注入 → `DeepBase.IntentClarification.IoC.pas`
  - [x] 20.2 重构 Registration 为 IoC 注册

- [x] 21. 状态机集成
  - [x] 21.1 重构 Session 生命周期为 StateMachine → `DeepBase.IntentClarification.SessionFSM.pas`

- [x] 22. 日志集成
  - [x] 22.1 Engine 关键路径加日志（Engine.pas 已有 Logging）
  - [x] 22.2 SignalDetector 加日志 → 已更新 SignalDetector.pas

- [x] 23. 数据库标准化
  - [x] 23.1 Storage 走 DB.Factory 获取连接 → Storage.pas 已重写
  - [x] 23.2 Schema 注册为 Migration → RegisterMigration 方法
  - [x] 23.3 Storage 初始化时调用 Guardian → EnsureInitialized 中调用

- [x] 24. 弹性保护
  - [x] 24.1 LLM 调用包装 Resilience → `DeepBase.IntentClarification.LLMResilience.pas`

- [x] 25. 指标收集
  - [x] 25.1 Engine 上报运行指标 → `DeepBase.IntentClarification.Metrics.pas`

- [x] 26. 配置系统集成
  - [x] 26.1 Templates 从 Config 系统加载 → `DeepBase.IntentClarification.FeatureConfig.pas`
  - [x] 26.2 FeatureFlags 控制高级功能

- [x] 27. 验证框架集成
  - [x] 27.1 Templates 验证用 Validation 框架 → `DeepBase.IntentClarification.Validation.pas`

- [x] 28. Checkpoint - 确保重构后所有功能正常

- [x] 29. 集成测试
  - [x] 29.1 编写 Engine + IoC + DB 端到端测试 → `Test.DeepBase.IntentClarification.Integration.pas`
  - [x] 29.2 编写 LLM Resilience 测试

## Status: ✅ Phase 2 Complete
