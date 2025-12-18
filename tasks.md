# UniBase 开发任务

> **最后更新**: 2025-12-18
> **项目状态**: 核心完成，代码优化阶段

---

## 文档导航

| 文档 | 说明 |
|------|------|
| **[history.md](history.md)** | 已完成任务记录 (80+ 任务) |
| **[bugfix.md](bugfix.md)** | Bug 修复记录 (60+ Bug) |
| **[tasks_next.md](tasks_next.md)** | 后续扩展任务规划 |
| **[README.md](README.md)** | 项目说明 |

---

## 项目进度概览

| 阶段 | 状态 | 完成日期 |
|------|------|----------|
| Phase 0: 最小核心 | ✅ 完成 | 2025-11-27 |
| Phase 1: 推荐功能 | ✅ 完成 | 2025-11-27 |
| Phase 2: 扩展功能 | ✅ 完成 | 2025-11-27 |
| Phase 3: 高级功能 | ✅ 完成 | 2025-11-27 |
| Phase 4: 完善与文档 | ✅ 完成 | 2025-11-27 |
| Phase 5: 代码审查优化 | ✅ 完成 | 2025-11-28 |
| Phase P0: 商业化基础 | ✅ 完成 | 2025-12-09 |
| Phase P1: 商业化扩展 | ✅ 完成 | 2025-12-10 |
| Phase P2: 工具与CLI | ✅ 完成 | 2025-11-29 |
| Phase MAINT: 维护优化 | 🟡 进行中 | - |
| Phase OPT: 代码优化 | 🟡 进行中 | - |

---

## 代码审查优化任务 (2025-12-18)

> 基于深度代码审查的优化建议，整体评分 **8.4/10**

### 🔴 P1 - 立即处理

#### OPT-001: 替换泛型异常为特定异常类
- **状态**: ✅ 完成 (2025-12-18)
- **优先级**: P1
- **问题**: 代码中有 **186 处** 使用 `raise Exception.Create(...)`
- **影响**: 难以精确捕获和处理特定错误
- **任务**:
  - [x] 创建异常类层次结构 (`Core/UniBase.Exceptions.pas`)
  - [x] 定义模块特定异常 (ESecurityException, EDatabaseException, EBackupException 等)
  - [x] 替换 Core 模块的泛型异常
  - [x] 替换 ThirdParty 模块的泛型异常
  - [x] 替换 Tools/VCL 模块的泛型异常
  - [x] 替换 doQry 模块的泛型异常
  - [x] 替换 Examples 模块的泛型异常
  - [x] 替换 uniFlow 模块的泛型异常
  - [x] 替换 UniBaseRun 模块的泛型异常
- **备注**: Tests 目录中保留 7 处泛型异常用于测试场景
- **已创建的异常类**:
  - EUniBaseException (基类)
  - ESecurityException, EEncryptionException, EDecryptionException, EHashException
  - EAntiTamperException, EProtectionException, ERandomException
  - EDatabaseException, EPoolException, EConnectionTimeoutException
  - EBackupException, EBackupCancelledException, EBackupInProgressException
  - ENetworkException, EHttpServerException, EServerAlreadyRunningException
  - EResilienceException, ECircuitBreakerException
  - EOperationException, EInvalidOperationException, EOperationCancelledException
  - EConfigException, EConfigNotFoundException, EMissingConfigurationException

#### OPT-002: 重构静态方法为依赖注入服务
- **状态**: ✅ 完成 (2025-12-18)
- **优先级**: P1
- **问题**: **351 个静态方法** 难以单元测试和模拟
- **影响**: 降低代码可测试性
- **任务**:
  - [x] 创建服务接口 (`Core/UniBase.Services.Interfaces.pas`)
    - IHashService, IEncodingService, IPasswordService
    - IRandomService, ICryptoService, ICRCService
    - IStatisticsService, IMathUtilsService, IInterpolationService
    - IEasingService, IRandomDistributionService
    - IAntiTamperService, IBasicProtectionService
    - ISerializationService
  - [x] 实现加密服务 (`Core/UniBase.Services.Crypto.pas`)
    - THashServiceImpl, TEncodingServiceImpl, TPasswordServiceImpl
    - TRandomServiceImpl, TCryptoServiceImpl, TCRCServiceImpl
  - [x] 实现数学服务 (`Core/UniBase.Services.Math.pas`)
    - TStatisticsServiceImpl, TMathUtilsServiceImpl
    - TInterpolationServiceImpl, TEasingServiceImpl
    - TRandomDistributionServiceImpl
  - [x] 实现序列化服务 (`Core/UniBase.Services.Serialization.pas`)
    - TSerializationServiceImpl
  - [x] 实现保护服务 (`Core/UniBase.Services.Protection.pas`)
    - TBasicProtectionServiceImpl, TAntiTamperServiceImpl
  - [x] 创建服务注册模块 (`Core/UniBase.Services.Registration.pas`)
    - RegisterDefaultServices, RegisterCryptoServices
    - RegisterMathServices, RegisterSerializationServices
    - RegisterProtectionServices
- **使用方法**:
  ```delphi
  uses UniBase.IoC, UniBase.Services.Registration, UniBase.Services.Interfaces;

  // 初始化
  RegisterDefaultServices(GlobalContainer);

  // 使用
  var HashSvc := GlobalContainer.Resolve<IHashService>;
  var Hash := HashSvc.SHA256('data');
  ```

#### OPT-003: 添加长期压力测试
- **状态**: ✅ 完成 (2025-12-18)
- **优先级**: P1
- **问题**: 缺乏长时间运行的稳定性测试
- **任务**:
  - [x] 创建 48 小时内存泄漏测试 (`Tests/Stress/Stress.Memory48h.pas`)
  - [x] 创建高并发竞态条件测试 (`Tests/Stress/Stress.Concurrency.pas`)
  - [x] 创建 EventBus 高负载测试 (`Tests/Stress/Stress.EventBus.pas`)
  - [x] 创建连接池长期稳定性测试 (`Tests/Stress/Stress.ConnectionPool.pas`)
  - [x] 添加自动化测试脚本 (`Tests/Stress/run_stress_tests.ps1`, `run_stress_tests.bat`)
  - [x] 更新主测试程序 (`Tests/Stress/UniBaseStressTests.dpr`)
- **新增测试模块**:
  - `Stress.Memory48h.pas` - 48 小时内存泄漏检测 (8 个测试类)
  - `Stress.Concurrency.pas` - 高并发竞态条件测试 (8 个测试类)
  - `Stress.EventBus.pas` - EventBus 高负载测试 (6 个测试类)
  - `Stress.ConnectionPool.pas` - 连接池稳定性测试 (7 个测试类)
- **使用方法**:
  ```powershell
  # 快速测试 (60秒)
  .\run_stress_tests.ps1 -TestType quick

  # 48小时内存测试
  .\run_stress_tests.ps1 -TestType memory48h

  # 所有测试
  .\run_stress_tests.ps1 -TestType all -DurationSec 300 -ThreadCount 10
  ```

---

### 🟡 P2 - 本版本改进

#### OPT-004: 优化锁竞争
- **状态**: ✅ 完成 (2025-12-18)
- **优先级**: P2
- **问题**: 多处使用 `TCriticalSection`，读写操作都加锁
- **影响**: 高并发场景下性能下降
- **任务**:
  - [x] 分析 Config、Logger、Cache、Security 模块的锁使用
  - [x] 对读多写少的场景引入 `TMultiReadExclusiveWriteSynchronizer`
  - [x] 优化 Config 模块 (`UniBase.Config.pas` v0.4)
  - [x] 优化 Cache 模块 (`UniBase.Cache.pas` v0.2)
  - [ ] 添加锁竞争性能基准测试 (可选后续任务)
- **已优化的模块**:
  - `Core/UniBase.Config.pas` - 读操作使用 `FRWLock.BeginRead/EndRead`，写操作使用 `FRWLock.BeginWrite/EndWrite`
  - `Core/UniBase.Cache.pas` - 全部方法改用 `TMultiReadExclusiveWriteSynchronizer`
- **未修改的模块** (已分析，无需优化):
  - `UniBase.Logging.pas` - 使用异步队列模式，已是最优
  - `UniBase.Security.pas` - 写操作为主，保持 `TMonitor` 即可

#### OPT-005: 修复 EventBus MainThread 死锁风险
- **状态**: ✅ 完成 (2025-12-18)
- **优先级**: P2
- **问题**: `Publish(..., edmMainThread)` 可能导致死锁
- **任务**:
  - [x] 添加 MainThread 分发超时机制 (默认 5 秒)
  - [x] 检测主线程阻塞情况 (超时后 fallback 到 TThread.Queue)
  - [x] 添加死锁检测日志 (TotalMainThreadTimeouts 统计)
  - [x] 更新文档说明使用注意事项 (EventBus.pas 头部 WARNING 注释)
- **已修改文件**:
  - `Core/UniBase.EventBus.pas` (v0.2)
    - 新增 `DEFAULT_MAINTHREAD_TIMEOUT_MS = 5000` 常量
    - 新增 `TotalMainThreadTimeouts` 统计字段
    - 新增 `MainThreadTimeoutMs` 可配置属性
    - 新增 `TrySynchronizeWithTimeout` 方法 (使用 TEvent.WaitFor)
    - 修改 `InvokeHandler` 支持超时和 fallback

#### OPT-006: 统一资源清理模式
- **状态**: ✅ 完成 (2025-12-18)
- **优先级**: P2
- **问题**: 部分代码使用 `Free` 而非 `FreeAndNil`
- **任务**:
  - [x] 扫描所有 `destructor Destroy` 实现
  - [x] 将 `X.Free` 替换为 `FreeAndNil(X)` - 486 处
  - [x] 检查并修复悬空指针风险
- **修改统计**:
  - Core 模块: 451 处 (70 文件)
  - VCL 模块: 26 处 (10 文件)
  - ThirdParty 模块: 9 处 (7 文件)
  - **总计: 486 处替换，87 个文件**

#### OPT-007: 完善异常恢复机制
- **状态**: ✅ 完成 (2025-12-18)
- **优先级**: P2
- **问题**: 缺乏自动恢复机制
- **任务**:
  - [x] 数据库连接失败自动重连 (`TDatabaseHealthCheck` 支持重试)
  - [x] 网络超时重试策略 (`TNetworkHealthCheck` + `UniBase.Resilience` 已有)
  - [x] 磁盘满时日志轮转 (`TDiskSpaceHealthCheck` 触发警告)
  - [x] 添加健康检查和自愈逻辑
- **已修改文件**:
  - `Core/UniBase.Services.HealthCheck.pas` (v1.1)
    - `THealthCheckResult` 记录类型 (含状态、描述、连续失败计数)
    - `IHealthCheck` 接口 + `TBaseHealthCheck` 基类
    - `TDatabaseHealthCheck` - 数据库健康检查 (支持自动重连、重试)
    - `TDiskSpaceHealthCheck` - 磁盘空间检查 (可配置警告/临界阈值)
    - `TMemoryHealthCheck` - 内存使用检查 (Windows API)
    - `TNetworkHealthCheck` - 网络连接检查 (TCP Socket)
    - `THealthCheckService` - 健康检查服务
      - `AutoRecover` 属性 (默认 True)
      - `MaxConsecutiveFailures` 属性 (默认 3 次触发恢复)
      - `StartMonitoring(IntervalMs)` 后台监控
      - `TryRecover` 自愈逻辑
      - `OnHealthCheck` / `OnRecovery` / `OnStatusChanged` 事件
    - `HealthCheckService()` 全局单例函数
- **使用示例**:
  ```delphi
  uses UniBase.Services.HealthCheck;

  // 注册数据库健康检查 (含自动重连)
  HealthCheckService.RegisterCheck(TDatabaseHealthCheck.Create(Connection,
    procedure begin
      Connection.Connected := False;
      Connection.Connected := True;
    end));

  // 注册磁盘空间检查
  HealthCheckService.RegisterCheck(TDiskSpaceHealthCheck.Create('C:\', 100 * 1024 * 1024));

  // 启动后台监控 (每30秒)
  HealthCheckService.StartMonitoring(30000);
  ```

---

### 🟢 P3 - 下版本改进

#### OPT-008: 补充性能调优文档
- **状态**: 🔲 待开始
- **优先级**: P3
- **任务**:
  - [ ] 添加 `docs/performance-tuning.md`
  - [ ] 添加缓存配置最佳实践
  - [ ] 添加连接池调优指南
  - [ ] 添加日志性能优化指南

#### OPT-009: 补充故障排除指南
- **状态**: 🔲 待开始
- **优先级**: P3
- **任务**:
  - [ ] 添加 `docs/troubleshooting.md`
  - [ ] 常见错误及解决方案
  - [ ] 调试技巧和工具
  - [ ] 日志分析指南

#### OPT-010: 完善性能基准
- **状态**: 🔲 待开始
- **优先级**: P3
- **任务**:
  - [ ] 补充内存占用基准
  - [ ] 补充磁盘 I/O 基准
  - [ ] 补充网络延迟基准
  - [ ] 补充并发度基准

---

### 代码审查统计 (2025-12-18)

| 维度 | 评分 | 说明 |
|-----|------|------|
| 架构设计 | 8.5/10 | 清晰分层，Manager 职责过多 |
| 代码质量 | 8.8/10 | 风格一致，命名规范100%遵守 |
| 安全性 | 8.9/10 | 71个安全问题已修复 |
| 测试覆盖 | 8.2/10 | 407+ 测试用例 |
| 性能优化 | 7.8/10 | 锁竞争有改进空间 |
| **综合评分** | **8.4/10** | 优秀的企业级框架 |

---

## 待开发任务

### 进行中 (MAINT)

#### MAINT-002: 单元测试覆盖率提升至 95%+
- **状态**: 🟡 进行中
- **优先级**: P0
- **目标**:
  - 单元测试整体覆盖率提升到 95%+，并确保关键安全/网络模块有稳定回归测试。
- **下一步任务**:
  - （可选）在后续 CI 环境中补充针对数据库 Integration Tests 的专用配置说明文档（如何启用 `UNIBASE_RUN_DB_INTEGRATION=1` 与 FireDAC/SQLite 驱动）。
  - 将新增/修复的测试单元逐步纳入统一测试入口（`Tests/UniBaseTests.dpr` / `Scripts/run_tests.ps1`），并在 README/Docs 中明确一键测试命令。
  - 检查 `Test.UniBase.Config.pas` 等被注释的测试单元与当前 API 的兼容性问题（能恢复则恢复，不能则删除/重写，避免长期"注释债务"）。
  - 修复剩余 11 个失败测试（Manager/Protection/Resilience/Unlock 模块）
  - 修复 58 个 Access Violation 错误（需 UniBaseManager 初始化）
- **当前测试状态** (2025-12-18):
  - 单元测试: 751/824 通过 (91.1%)
  - 失败测试: 11 个 (Manager/Protection/Resilience/Unlock)
  - 错误测试: 58 个 (Access Violation - Config/FormState/Hotkeys/MRU/Theme/i18n)
  - 新增测试文件:
    - `Test.UniBase.Payment.pas` - 支付模块测试
    - `Test.UniBase.Social.pas` - 社交模块测试
    - `Test.UniBase.Types.pas` - 类型模块测试
    - `Test.UniBase.Serialization.pas` - 序列化模块测试 (58 测试)
    - `Test.UniBase.DateTime.pas` - DateTime 模块测试 (已修复)
- **备注**:
  - Unit 测试入口 `Tests/UniBaseTests.dpr` 已恢复包含 `Test.UniBase.FormState` / `Test.UniBase.Logging` / `Test.UniBase.License`。
  - Bug 修复记录统一写入 `bugFixed.md`。
  - 已完成的测试模块清单见 `history.md` 中 "MAINT-002: 单元测试覆盖率提升 🟡" 小节。

### 商业化与工具集成 (P1)

#### PUBL-105: 工具项目接入 AboutFrame + aboutMeImages（TwoKeyRun / OmniSync / 其它）
- **状态**: 🟡 进行中（UniBase 侧开发已完成，待人工集成）
- **优先级**: P1
- **实施指南**: `docs/integrations/IMPLEMENTATION_GUIDE.md`
- **已完成**:
  - ✅ 5 个工具项目集成规划文档（见 `docs/integrations/`）
  - ✅ VCL 版 AboutFrame：`VCL/UniBase.VCL.AboutFrame.pas`（6 个 Tab，含公众号）
  - ✅ FMX 版 AboutFrame：`FMX/UniBase.FMX.AboutFrame.pas`（6 个 Tab，已对齐 AntiTamper）
  - ✅ SeedTool（GUI）已包含 Enabled 字段、可播种 `aboutMeImages`
  - ✅ IMPLEMENTATION_GUIDE.md 文档已更新（2025-12-12）
- **待人工完成（集成）**:
  - [ ] 准备 6 张标准图片资源
  - [ ] 运行 SeedTool 为各项目创建 `*Config.db` 并播种 6 个标准 key
  - [ ] 在 IDE 中按指南修改各项目代码并编译测试

---

### LLM 集成 (P2)

#### LLM-001: Delphi LLM 客户端封装库
- **状态**: ✅ 完成 (2025-12-14)
- **优先级**: P2
- **相关文档**: `../远程Delphi客户端连接和LLM调用指南.md`
- **实现文件**: `Core/UniBase.LLM.BillingClient.pas`
- **已完成**:
  - [x] `TBillingClient` 轻量级客户端（不依赖数据库）
  - [x] 流式/非流式响应支持 (SSE 解析)
  - [x] `TChatHistory` 对话历史管理
  - [x] 自定义异常层次 (`EBillingError`, `EBillingAuthError`, `EBillingBalanceError`, `EBillingRateLimitError`)
  - [x] 重试机制 (`ChatWithRetry` 指数退避)
  - [x] 请求取消 (`Cancel`)
  - [x] 异步调用 (`ChatAsync`)

#### LLM-002: API Key 安全存储模块
- **状态**: ✅ 完成 (2025-12-14)
- **优先级**: P2
- **实现文件**: `Core/UniBase.Security.DPAPI.pas`
- **已完成**:
  - [x] `TDPAPIHelper` - Windows DPAPI 加密/解密
  - [x] `ProtectString` / `UnprotectString` 字符串加解密
  - [x] `ProtectToFile` / `UnprotectFromFile` 文件加解密
  - [x] `TCredentialManager` - Windows Credential Manager 集成
  - [x] `TSecureString` - 安全字符串（自动清除内存）

#### LLM-003: VCL/FMX LLM 聊天组件
- **状态**: ✅ 完成 (2025-12-14)
- **优先级**: P3
- **实现文件**:
  - `VCL/UniBase.VCL.LLMChatFrame.pas`
  - `FMX/UniBase.FMX.LLMChatFrame.pas`
- **已完成**:
  - [x] VCL 聊天 Frame（RichEdit 支持富文本）
  - [x] FMX 聊天 Frame（跨平台）
  - [x] 流式文本逐字显示
  - [x] 取消按钮/加载状态
  - [x] 历史记录导出

#### LLM-004: LLM 模块单元测试
- **状态**: ✅ 完成 (2025-12-14)
- **优先级**: P2
- **测试文件**:
  - `Tests/Test.UniBase.LLM.BillingClient.pas` (22 测试用例)
  - `Tests/Test.UniBase.Security.DPAPI.pas` (23 测试用例)
- **测试覆盖**:
  - [x] `TChatMessage` 消息记录测试
  - [x] `TChatHistory` 历史管理测试
  - [x] `TBillingClient` 属性/URL 处理测试
  - [x] `TDPAPIHelper` 加解密测试
  - [x] `TCredentialManager` 凭据管理测试
  - [x] `TSecureString` 安全字符串测试

---

### AipexBase 集成 (P0)

#### AIPEX-001: 用户认证与计费 UI 组件
- **状态**: ✅ 前端完成，等待后端 (2025-12-15)
- **优先级**: P0
- **API 文档**: `docs/api/前端对接后端用户认证、计费指南.md`
- **已完成 (前端)**:
  - [x] `Core/UniBase.AipexBase.Client.pas` - API 客户端
  - [x] VCL 组件 (7个): LoginDialog, RegisterDialog, ForgotPasswordDialog, UserProfileFrame, BalanceFrame, UsageStatsFrame, BillingFrame
  - [x] FMX 组件 (7个): 同上 FMX 版本
  - [x] `Examples/UserAuthDemo/` - VCL 演示程序
  - [x] `docs/ui/svg/` - 7 个 UI 线框图
  - [x] `docs/integrations/AipexBase-Integration.md` - 集成指南
- **等待后端 (Phase 6)**:
  - [ ] POST /api/auth/login
  - [ ] POST /api/auth/register
  - [ ] POST /api/auth/forgot-password
  - [ ] POST /api/auth/refresh
  - [ ] GET /api/user/profile
  - [ ] GET /api/billing/balance
  - [ ] POST /api/billing/recharge
  - [ ] GET /api/billing/transactions
  - [ ] GET /api/billing/invoices

#### AIPEX-002: LLM 调用与用量统计 UI
- **状态**: ✅ 前端完成，等待后端 (2025-12-15)
- **优先级**: P0
- **API 文档**: `docs/api/前端对接后端LLM能力与计费指南.md`
- **已完成 (前端)**:
  - [x] `VCL/UniBase.VCL.UsageStatsFrame.pas` - VCL 用量统计
  - [x] `FMX/UniBase.FMX.UsageStatsFrame.pas` - FMX 用量统计
  - [x] `VCL/UniBase.VCL.LLMChatFrame.pas` - VCL 聊天界面
  - [x] `FMX/UniBase.FMX.LLMChatFrame.pas` - FMX 聊天界面
- **等待后端 (Phase 5-6)**:
  - [ ] POST /api/llm/chat/completions (流式)
  - [ ] GET /api/llm/models
  - [ ] GET /api/usage/summary
  - [ ] GET /api/usage/trend
  - [ ] GET /api/usage/models
  - [ ] GET /api/usage/calls

#### AIPEX-003: 前后端联调测试
- **状态**: 🔲 待后端就绪
- **优先级**: P0
- **任务**:
  - [ ] 后端部署开发环境 (http://localhost:8090)
  - [ ] 运行 UserAuthDemo 测试登录/注册
  - [ ] 测试余额充值流程 (沙箱支付)
  - [ ] 测试 LLM 调用和计费
  - [ ] 测试用量统计数据展示
  - [ ] 修复前后端字段对接问题

---

### 低优先级 (P3)

#### ECO-002: 社区扩展包 (持续)
- **状态**: 🟡 进行中
- **性质**: ThirdParty 可选扩展（非 Core 核心功能）
- **已完成阶段**:
  - 第一批扩展（PostgreSQL/MySQL 驱动、UI 主题包、云存储集成）已记录在 `history.md` 的 "ECO-002: 社区扩展包（第一阶段）" 小节
  - 支付接口集成 (2025-12-15):
    - [x] `ThirdParty/Payment/UniBase.Payment.pas` - 统一支付接口
    - [x] `ThirdParty/Payment/UniBase.Payment.Alipay.pas` - 支付宝实现
    - [x] `ThirdParty/Payment/UniBase.Payment.WeChatPay.pas` - 微信支付实现 (APIv3)
    - [x] `ThirdParty/Payment/UniBase.Payment.Stripe.pas` - Stripe 实现
  - 社交媒体集成 (2025-12-15):
    - [x] `ThirdParty/Social/UniBase.Social.pas` - 统一社交接口
    - [x] `ThirdParty/Social/UniBase.Social.OAuth.pas` - OAuth 2.0 通用实现 (GitHub/Google)
    - [x] `ThirdParty/Social/UniBase.Social.WeChat.pas` - 微信登录实现
- **下一步任务**:
  - [ ] 支付接口扩展: PayPal
  - [ ] 社交媒体扩展: Weibo/QQ
- **开发指南**:
  - 参考 [06.01.uniBase-4H-ThirdParty扩展开发指南-v1.0.md](docs/06.01.uniBase-4H-ThirdParty扩展开发指南-v1.0.md)
  - 参考已实现的 `ThirdParty/Cloud/UniBase.Cloud.Storage.pas` 模式
  - 支付接口文档: `ThirdParty/Payment/README.md`

#### DOC-004: 视频教程
- **状态**: 🔲 待开始
- **优先级**: P3
- **内容**:
  - [ ] 快速入门视频
  - [ ] 模块深度讲解
  - [ ] 实战案例演示

---

## 性能基准

| 操作 | 目标 | 实际 |
|------|------|------|
| Config 读取 (缓存) | < 1ms | ✅ |
| Config 写入 | < 10ms | ✅ |
| 日志写入 10000条 | < 5s | ✅ 3s |
| i18n 查询 | < 0.5ms | ✅ |

---

## Schema 迁移

升级脚本位置: `sql/upgrade_v{old}_to_v{new}.sql`

---

**维护者**: 李冰、鲁班、Claude
