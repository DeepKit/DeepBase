# 专家 B 审阅报告: Core 业务 + Features

## 概要
- 审阅模块数: 28 (Core 15 + Features 13，部分深读、部分扫视)
- 发现总数: 14 (bug 8 个, 优化/设计 6 个)
- 严重度分布: P1 9 个、P2 5 个

---

## 发现列表

| ID | 模块 | 严重度 | 类型 | 简述 | 位置 |
|----|------|--------|------|------|------|
| BIZ-001 | DeepBase.Services.HealthCheck | P1 | security | 异常处理泄露内部异常消息，可暴露栈路径 | L109-115 |
| BIZ-002 | DeepBase.Authorization | P1 | bug | SetCurrentUser 已废弃但仍可正常调用，失去弃用保护 | L414-415 |
| BIZ-003 | DeepBase.i18n | P1 | bug | GetDefaultLanguage 返回 en-US，回退代码使用 en，格式不一致导致空回退命中失败 | L607/L224-226 |
| BIZ-004 | DeepBase.LLM | P1 | bug | ChatStream 声明为流式 API 但实际退化为同步 Chat，违反契约 | L1745-1759 |
| BIZ-005 | DeepBase.LLM.BillingClient | P2 | i18n | 错误信息硬编码中文字符串，国际化缺失 | L509-517 |
| BIZ-006 | DeepBase.Speech.Resolver | P1 | bug | ResolveASR 中 SenseVoice 许可证检查逻辑为空操作，始终走 Tier 2 | L47-77 |
| BIZ-007 | DeepBase.LLM | P1 | bug | GetConfig 缓存未命中时持有 FCacheLock 调用 RefreshConfigCache，TCriticalSection 不可重入导致潜在死锁 | L1084-1093 |
| BIZ-008 | DeepBase.Authorization | P2 | bug | CreateRole/GrantPermission 等操作审计日志 Username 为空字符串，无法追溯操作者 | L1045,L1163 |
| BIZ-009 | DeepBase.Speech.Service | P1 | bug | TranscribeFromMic 使用 Sleep(Min(AMaxSeconds*1000,5000)) 阻塞，上限仅 5 秒 | L414 |
| BIZ-010 | DeepBase.LLM.Manager | P2 | security | BuildContext 将原始 Exception.Message 拼入 JSON 字符串，可暴露内部路径 | L1078-1079 |
| BIZ-011 | DeepBase.Speech.Config | P2 | bug | TSpeechLangHelper.Normalize 要求必须包含区域子标签，但 ja/en 等常用短码被拒绝 | L108-130 |
| BIZ-012 | DeepBase.LLM.BillingClient | P1 | bug | ChatAsync 传递 Self 引用给 TTask.Run，若 Self 被释放则悬垂引用 | L812 |
| BIZ-013 | DeepBase.LLM.Manager | P2 | logic | SetProductionVersion/DeleteVersion 连续操作 RefreshCache，非原子且性能低下 | L1543,L1577 |
| BIZ-014 | DeepBase.AutoUpdate | P2 | bug | CheckForUpdateFromJson 发起 HTTP 请求但未设置 User-Agent | L499-521 |
