# Bug-测试映射文档

本文档列出所有已修复 Bug 与对应回归测试的映射关系。

## P0 - Critical (10 个)

| Bug 编号 | 描述 | 测试文件 | 源文件 | 修复日期 |
|---------|------|---------|--------|---------|
| BUG-058 | 配置XOR加密安全缺陷 | Test.Regression.BUG058_XOREncryption.pas | Core/UniBase.Config.pas | 2025-01-27 |
| BUG-062 | 插件沙箱逃逸风险 | Test.Regression.BUG062_PluginSandbox.pas | Core/UniBase.PluginManager.pas | 2025-01-27 |
| BUG-063 | 插件配置权限绕过 | Test.Regression.BUG063_PluginConfigBypass.pas | Core/UniBase.PluginManager.pas | 2025-01-27 |
| BUG-013 | 支付模块RSA签名未实现 | Test.Regression.BUG013_RSASignature.pas | ThirdParty/Payment/UniBase.Payment.Alipay.pas | 2025-01-27 |
| BUG-035 | 不安全随机数生成 | Test.Regression.BUG035_InsecureRandom.pas | Core/UniBase.Crypto.pas | 2025-12-16 |
| BUG-007 | 死锁风险-WhenReady方法 | Test.Regression.BUG007_WhenReadyDeadlock.pas | Core/UniBase.Manager.pas | 2025-12-16 |
| BUG-014 | 微信支付签名验证缺失 | Test.Regression.BUG014_WeChatPaySignature.pas | ThirdParty/Payment/UniBase.Payment.WeChatPay.pas | 2025-12-16 |
| BUG-033 | 弱加密算法使用 | Test.Regression.BUG033_WeakEncryption.pas | Core/UniBase.AntiTamper.pas | 2025-12-16 |
| BUG-034 | 硬编码密钥漏洞 | Test.Regression.BUG034_HardcodedKeys.pas | Core/UniBase.Protection.pas | 2025-12-16 |
| BUG-008 | UI线程竞态条件 | Test.Regression.BUG008_UIThreadRace.pas | VCL/UniBase.VCL.LLMChatFrame.pas | 2025-12-16 |

## P1 - High (11 个)

| Bug 编号 | 描述 | 测试文件 | 源文件 | 修复日期 |
|---------|------|---------|--------|---------|
| BUG-001 | 动画对象内存泄漏 | Test.Regression.BUG001_AnimationMemoryLeak.pas | VCL/UniBase.VCL.WaitForm.pas | 2025-01-27 |
| BUG-059 | JSON反序列化类型验证缺失 | Test.Regression.BUG059_JsonDeserializationType.pas | Core/UniBase.Serialization.pas | 2025-01-27 |
| BUG-060 | 序列化深度限制过高 | Test.Regression.BUG060_SerializationDepth.pas | Core/UniBase.Serialization.pas | 2025-01-27 |
| BUG-066 | 路径遍历攻击漏洞 | Test.Regression.BUG066_PathTraversal.pas | Core/UniBase.FileWatcher.pas | 2025-01-27 |
| BUG-070 | 日志注入攻击风险 | Test.Regression.BUG070_LogInjection.pas | Core/UniBase.Logging.pas | 2025-01-27 |
| BUG-073 | 事件类型注入风险 | Test.Regression.BUG073_EventTypeInjection.pas | Core/UniBase.EventBus.pas | 2025-01-27 |
| BUG-037 | 密钥派生不当 | Test.Regression.BUG037_KeyDerivation.pas | Core/UniBase.AntiTamper.pas | 2025-01-27 |
| BUG-020 | 密钥名称验证缺失 | Test.Regression.BUG020_KeyNameValidation.pas | Core/UniBase.Security.pas | 2025-01-27 |
| BUG-010 | 工作队列状态竞争 | Test.Regression.BUG010_WorkerQueueRace.pas | Core/UniBase.WorkerQueue.pas | 2025-12-16 |
| BUG-054 | 弹性模式信号量泄漏 | Test.Regression.BUG054_SemaphoreLeak.pas | Core/UniBase.Resilience.pas | 2025-12-16 |
| BUG-009 | 日志系统竞态条件 | Test.Regression.BUG009_LoggingRace.pas | Core/UniBase.Logging.pas | 2025-12-16 |

## 待实现测试

以下 Bug 已修复但尚未创建回归测试：

### P1 级别
- BUG-018: 反序列化安全漏洞
- BUG-019: 日志注入攻击
- BUG-027: 文件监控路径遍历
- BUG-039: HTTP请求头注入风险
- BUG-040: SSRF攻击风险

### P2 级别
- BUG-003: 锁持有时间过长
- BUG-004: 调试输出泄露敏感信息
- BUG-005: 边界检查不足
- BUG-006: 状态机验证不足
- ... (更多见 bugfix.md)

## 测试覆盖率统计

| 优先级 | 已修复 Bug 数 | 已创建测试数 | 覆盖率 |
|-------|-------------|-------------|-------|
| P0 | 10 | 10 | 100% |
| P1 | 31 | 11 | 35.5% |
| P2 | 25 | 0 | 0% |
| P3 | 7 | 0 | 0% |
| **总计** | **73** | **21** | **28.8%** |

## 更新日志

- 2025-01-05: 创建文档，添加 P0 和部分 P1 测试映射
