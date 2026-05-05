# UniBase 开发任务

> **最后更新**: 2026-05-04
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
| Phase ARCH: 架构审阅优化 | 🟡 进行中 | - |

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
  - [x] 添加自动化测试脚本 (`Tests/Stress/run_stress_tests.ps1`, `Tests/Stress/run_stress_tests.bat`)
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
  - [x] 添加锁竞争性能基准测试 (`Tests/Test.UniBase.LockContention.pas`)
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
- **状态**: ✅ 完成 (2026-05-02)
- **优先级**: P3
- **任务**:
  - [x] 添加 `docs/legacy/performance-tuning.md`
  - [x] 添加缓存配置最佳实践
  - [x] 添加连接池调优指南
  - [x] 添加日志性能优化指南

#### OPT-009: 补充故障排除指南
- **状态**: ✅ 完成 (2026-05-02)
- **优先级**: P3
- **任务**:
  - [x] 添加 `docs/legacy/troubleshooting.md`
  - [x] 常见错误及解决方案
  - [x] 调试技巧和工具
  - [x] 日志分析指南

#### OPT-010: 完善性能基准
- **状态**: ✅ 完成 (2026-05-02)
- **优先级**: P3
- **任务**:
  - [x] 补充内存占用基准 (`Test.UniBase.PerformanceSuite.pas` - 8个内存测试)
  - [x] 补充磁盘 I/O 基准 (`Test.UniBase.PerformanceSuite.pas` - 8个磁盘测试)
  - [x] 补充网络延迟基准 (网络基准依赖外部服务，留为手动测试)
  - [x] 补充并发度基准 (`Test.UniBase.PerformanceSuite.pas` - 8个并发测试 + `Test.UniBase.LockContention.pas` - 7个锁竞争测试)
- **新增文件**:
  - `Tests/Test.UniBase.PerformanceSuite.pas` - 综合性能基准套件 (30+ 测试)
  - `Tests/Test.UniBase.LockContention.pas` - 锁竞争对比基准 (7 测试，对比 TCriticalSection vs MREW)

---

### 代码审查统计 (2025-12-18)

| 维度 | 评分 | 说明 |
|-----|------|------|
| 架构设计 | 8.5/10 | 清晰分层，Manager 职责过多 |
| 代码质量 | 8.8/10 | 风格一致，命名规范100%遵守 |
| 安全性 | 8.9/10 | 71个安全问题已修复 |
| 测试覆盖 | 8.7/10 | Win64 门禁稳定：单测 876（872 通过）+ 集成 9（全通过） |
| 性能优化 | 7.8/10 | 锁竞争有改进空间 |
| **综合评分** | **8.4/10** | 优秀的企业级框架 |

---

## 架构专家审阅优化任务 — 第一轮 (2026-05-02)

> 基于架构/Delphi/安全/文档/集成 5 位专家审阅，识别出 8 项 P0 + 6 项 P1 + 4 项 P2 问题

### 🔴 P0 - 必须修复

#### ARCH-001: DoQry Queries 表列名不匹配
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P0 (安全/数据)
- **问题**: `UniBase.DB.DoQry.pas` 中 `LoadQuerySQL` 使用 `SELECT SQL FROM Queries WHERE ProcName = :ProcName`，但 Schema 文档 `04.01` 定义的列名可能是 `SqlText`/`Name`
- **影响**: 运行时 SQL 查询失败，导致所有 DoQry 功能不可用
- **任务**:
  - [x] 确认实际数据库表 `Queries` 的列名定义
  - [x] 对齐 DoQry 代码中的 SQL 与实际 Schema
  - [x] 补充 DoQry 列名匹配的单元测试
  - [x] 更新 `04.01` Schema 文档确保一致性

#### ARCH-002: UniDbInsertReturningId 缺少 BindJsonParams
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P0 (数据完整性)
- **问题**: Persistence 层的 `UniDbInsertReturningId` 未调用 `BindJsonParams`，导致 JSON 参数无法正确绑定
- **影响**: INSERT 语句中引用 JSON 参数时可能插入空值或失败
- **任务**:
  - [x] 检查 `UniDbInsertReturningId` 实现
  - [x] 补充 `BindJsonParams` 调用（与 UniDbInsert/UniDbUpdate 对齐）
  - [x] 补充 JSON 参数绑定的集成测试

#### ARCH-003: DoQry ProcName 回退 SQL 注入风险
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P0 (安全)
- **问题**: 当 `LoadQuerySQL` 在 Queries 表中找不到 ProcName 时，如果直接将 ProcName 当作 SQL 执行，存在 SQL 注入风险
- **影响**: 恶意构造的查询名可能执行任意 SQL
- **任务**:
  - [x] 审查 DoQry 中 ProcName 回退逻辑
  - [x] 移除或将回退逻辑限制为仅允许白名单格式的 SQL
  - [x] 添加 SQL 注入防护的单元测试
  - [x] 在文档中明确 ProcName 与直接 SQL 的安全边界

#### ARCH-004: TBasicProtection 加解密密钥派生不对称
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P0 (安全)
- **问题**: `TBasicProtection.Encrypt` 和 `Decrypt` 的密钥派生逻辑可能不对称（如 salt 处理不一致），导致加密后无法正确解密
- **影响**: 已加密数据可能无法恢复
- **任务**:
  - [x] 审查 Encrypt/Decrypt 完整密钥派生路径
  - [x] 确认 salt/IV/迭代次数完全对称
  - [x] 补充加密-解密往返测试（含边界场景）
  - [x] 如有不对称，修复并记录到 bugfix.md

#### ARCH-005: Payment 模块使用非 CSPRNG 随机数
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P0 (安全)
- **问题**: Payment 模块（支付宝/微信/PayPal）中可能使用 `Random()` 生成订单号、nonce 等安全敏感值，而非密码学安全随机数 (`CryptGenRandom` / `BCryptGenRandom`)
- **影响**: 订单号可预测，nonce 可被猜测，影响支付安全
- **任务**:
  - [x] 扫描所有 Payment 模块的随机数使用
  - [x] 将安全敏感场景替换为 `CryptGenRandom` 或 `BCryptGenRandom`
  - [x] 提供 `SecureRandom` 统一封装函数
  - [x] 补充随机数安全性的测试

#### ARCH-006: LLM 文档表名冲突
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P0 (文档一致性)
- **问题**: 多份文档中 LLM 相关表名不一致，部分使用 `LLMConfig`，部分使用 `LLMConfiguration`
- **影响**: 下游开发者/AI 集成时产生歧义
- **任务**:
  - [x] 确认实际数据库中的表名
  - [x] 统一所有文档中的表名引用
  - [x] 更新 `04.01 Schema 说明`、`05.01 API 参考`、`05.05 LLM 集成指南`

#### ARCH-007: ARCH-QUICKSTART 断链修复
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P0 (文档)
- **问题**: `ARCH-QUICKSTART.md` 中有 12 个链接指向不存在的文件或路径
- **影响**: 开发者无法通过快速入口找到正确文档
- **任务**:
  - [x] 逐一检查并修复所有断链
  - [x] 确保链接路径与实际文件一致
  - [x] 添加 CI 文档链接检查脚本

#### ARCH-008: 残留泛型异常替换
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P0 (代码质量)
- **问题**: 代码审查 OPT-001 完成了 Core/ThirdParty 模块的泛型异常替换，但仍有 30+ 处 `raise Exception.Create(...)` 未迁移到 `EUniBaseException` 层次
- **影响**: 异常无法按模块精确捕获
- **任务**:
  - [x] 扫描所有 `raise Exception.Create` 残留
  - [x] 替换为对应的 `EUniBaseException` 子类
  - [x] 更新测试中的异常断言

---

### 🟡 P1 - 高优先级

#### ARCH-009: 全局锁对象竞态条件
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P1 (并发安全)
- **问题**: 部分全局锁对象（如 Config、Cache 中的 TCriticalSection）在 `var` 段声明但在 `initialization` 中创建，多线程启动时可能发生竞态
- **影响**: 高并发初始化场景下可能访问未创建的锁对象
- **任务**:
  - [x] 审查所有全局锁对象的声明和创建位置
  - [x] 将锁对象创建移至 `initialization` 段（确保线程安全）
  - [x] 确认 `finalization` 段的释放顺序正确
- **修复摘要**:
  - `Persistence/UniBase.DB.DoQry.pas`: 查询缓存锁和预编译语句池锁改为单元初始化创建，并补齐 finalization 释放。
  - `Core/UniBase.KeyManager.pas`: `FInstanceLock` 改为初始化阶段创建，finalization 先释放实例再释放锁。
  - `Core/UniBase.FeatureFlags.pas`: 全局 manager 创建统一走锁；`TFeatureFlags.Manager` 收敛到同一个全局实例。
  - `Core/UniBase.Configuration.pas` / `Core/UniBase.Authorization.pas`: 默认配置与全局授权 manager 读取路径补齐锁保护。
  - `Tests/Test.UniBase.FeatureFlags.pas`: 新增多线程首次访问单例的回归测试。

#### ARCH-010: 合并 Core/Persistence DoQry 重复代码
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P1 (代码质量)
- **问题**: `Core/UniBase.DB.DoQry.pas` 和 `Persistence/` 下存在功能重复的 DoQry 实现
- **影响**: 维护成本翻倍，修复需同步两处
- **任务**:
  - [x] 对比 Core 和 Persistence 的 DoQry 实现
  - [x] 提取共享逻辑到公共模块
  - [x] 让两处实现统一调用公共模块
  - [x] 确保不破坏现有调用方
- **修复摘要**:
  - 删除 `Core/UniBase.DB.DoQry.pas` 的重复实现，保留 `Persistence/UniBase.DB.DoQry.pas` 作为唯一 canonical 实现。
  - 将 `Tests/UniBaseTests.dpr` / `.dproj` 的 DoQry 源文件引用切换到 `Persistence/`。
  - 将 ARCH-009 的全局锁初始化修复迁入 Persistence DoQry，避免合并后回退到懒创建锁。
  - 保留 Persistence 版本中的 `IDoQryService` / `TDoQryService`，供 IoC 和运行时注册继续使用。

#### ARCH-011: OAuth2 PKCE + State 验证
- **状态**: ✅ 已完成
- **优先级**: P1 (安全)
- **问题**: 社交登录（微信/QQ/Weibo/GitHub/Google）的 OAuth2 流程缺少 PKCE 和 state 参数验证
- **影响**: 容易受到 CSRF 和授权码截获攻击
- **任务**:
  - [x] 在 OAuth 基类中添加 PKCE 支持（code_verifier / code_challenge）
  - [x] 添加 state 参数生成和验证
  - [x] 使用 CSPRNG 生成 state 和 verifier
  - [x] 更新所有 OAuth 子类实现
  - [x] 补充 PKCE 流程的测试
- **修复摘要**:
  - `TSocialHelper.GenerateState` 改用 `SecureRandom`，新增 PKCE verifier 生成、S256 challenge 和常量时间 state 比较。
  - `TSocialClient` 统一保存/验证 OAuth state，并提供带 state 的 `ExchangeCode` 重载。
  - GitHub/Google 通用 OAuth、WeChat、Weibo、QQ 授权 URL 和授权码换 token 请求复用基类 state/PKCE 逻辑。
  - `Tests/Test.UniBase.Social.pas` 新增 RFC 7636 challenge 向量、PKCE 参数、state 校验回归测试。

#### ARCH-012: 合并两套 TObjectPool<T> 实现
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P1 (代码质量)
- **问题**: `Core/UniBase.Memory.pas` 和 `Core/UniBase.ObjectPool.pas` 存在两套泛型 `TObjectPool<T>` 实现，功能重复
- **影响**: 维护成本高，行为不一致风险
- **任务**:
  - [x] 对比两套 TObjectPool<T> 的接口和行为
  - [x] 合并为统一的泛型实现
  - [x] 确保所有调用方迁移到统一版本
  - [x] 补充池化行为的回归测试
- **修复摘要**:
  - `Core/UniBase.Memory.pas` 的兼容 `TObjectPool<T>` 改为委托 `UniBase.ObjectPool.TObjectPool<T>`，保留旧 API 和 reset 语义。
  - `Core/UniBase.ObjectPool.pas` 作为 canonical 实现，放宽事件类型以支持匿名方法，将默认 `MinSize` 调整为惰性创建语义，并新增 `Discard` 处理坏对象。
  - 对象池后台清理任务改为 shutdown event 唤醒，析构时等待任务退出，避免测试进程在默认 60 秒清理间隔上挂起。
  - `Tests/UniBaseTests.dpr` / `.dproj` 纳入 `Test.UniBase.ObjectPool`，并修正测试搜索路径。
  - `Tests/Test.UniBase.ObjectPool.pas` 补齐并修复 canonical 对象池回归测试，清理 wrapper 测试中直接创建的对象，消除 FastMM 泄漏。

#### ARCH-013: 统一 LLM API 示例文档
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P1 (文档)
- **问题**: `05.05 LLM 集成指南` 和 `05.01 API 参考` 中的 LLM API 示例代码风格不一致
- **影响**: 开发者集成时困惑
- **任务**:
  - [x] 统一所有 LLM 示例代码风格
  - [x] 确保示例代码可编译
  - [x] 添加完整的请求/响应示例
- **修复摘要**:
  - `docs/05.05.uniBase-4AI-LLM集成指南-v1.0.md`: LLM 示例统一为 `delphi` 代码块，移除旧占位调用和未定义 UI 控件，补齐导入导出与错误处理示例的真实单元引用。
  - `docs/05.01.uniBase-4AI-API参考-v1.0.md`: 新增 LLM 模块 API 参考，覆盖 `TUniBaseLLM`、`TLLMManager`、`TLLMImportExport`，并补充配置、请求、响应和异步执行示例。
  - 静态扫描确认两份文档不再包含 `LLMConfiguration`、旧 `UniBaseLLM` 全局写法、`TLLMMessage.Create`、`LLM.AddProvider`、`LLM.SetTierModels` 或 `pascal` 代码块。

#### ARCH-014: 旧格式文档迁移
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P1 (文档)
- **问题**: 项目根目录和 `docs/` 外有 25+ 个旧格式文档文件未迁移到 `docs/` 标准命名
- **影响**: 文档结构混乱，难以维护
- **任务**:
  - [x] 列出所有不符合命名规范的文档
  - [x] 迁移到 `docs/legacy/` 并更新索引
  - [x] 修复所有文档间交叉引用
  - [x] 更新 `00.00 文档索引`
- **修复摘要**:
  - 将 `docs/` 根目录下 51 个旧格式、重复或过期文档迁移到 `docs/legacy/`，并新增 `docs/legacy/README.md` 记录替代入口和归档清单。
  - `docs/00.00.uniBase-文档索引-v1.0.md` 更新日期、修正表格格式、补充 `legacy/` 说明，并将 ThirdParty 指南入口统一到 v1.1。
  - 修复 `ARCH-QUICKSTART.md`、`README.md`、标准文档和回归测试文档中的旧路径引用，旧 API/FAQ/DoQry/Glossary/用户手册引用改到当前标准文档或 legacy 归档。
  - `Scripts/check_doc_links.ps1` 改为按 Markdown 文件所在目录解析相对链接，避免文档子目录链接误报。
  - 静态扫描确认 `docs/` 根目录仅保留标准命名文档和 `00.00` 文档索引，关键导航文档链接检查通过。

---

### 🟢 P2 - 改进优化

#### ARCH-015: AES-256-CBC 迁移到 AES-256-GCM
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P2 (安全加固)
- **问题**: `TBasicProtection` 使用 AES-256-CBC 模式，应迁移到 AEAD 模式（AES-256-GCM）以获得认证加密
- **影响**: CBC 模式不提供密文完整性验证
- **任务**:
  - [x] 实现 AES-256-GCM 加密/解密
  - [x] 提供向后兼容的解密路径（CBC→GCM 迁移）
  - [x] 更新文档说明加密模式变更
- **修复摘要**:
  - `Core/UniBase.Protection.pas`: `EncryptSensitiveData` / `EncryptBinaryData` 新密文改用 Windows CNG AES-256-GCM，字符串格式为 `UBG1|<hex payload>`，二进制格式为 `UBG1 + nonce + tag + ciphertext`。
  - 保留旧 AES-256-CBC 字符串格式 `IVHex|CipherHex` 和二进制格式 `IV + Cipher` 的解密兼容路径。
  - `Tests/Test.UniBase.Protection.pas`: 补充 GCM 格式、篡改认证失败、旧 CBC 样本兼容解密回归测试。
  - `docs/07.03.uniBase-4H-安全与测试-v1.0.md`: 更新运行时校验说明，明确新数据使用 AES-256-GCM，旧 CBC 只读兼容。

#### ARCH-016: 凭据存储迁移到 Windows Credential Manager
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P2 (安全)
- **问题**: 部分 API Key / Secret 仍存储在配置文件中，应迁移到 Windows Credential Manager 或 DPAPI
- **影响**: 凭据泄露风险
- **任务**:
  - [x] 审查所有硬编码/文件存储的凭据
  - [x] 迁移到 `TCredentialManager`（已在 `UniBase.Security.DPAPI.pas` 中实现）
  - [x] 提供凭据迁移工具/脚本
- **完成说明**:
  - `Core/UniBase.LLM.pas`: `SaveConfig` 将 LLM API Key 写入 Windows Credential Manager，`LLMConfig.ApiKeyRef` / 旧 `LLMConfiguration.ApiKey` 仅保存 `credman:` 引用；读取时兼容 `credman:`、`LLMApiKeys.Name` 和旧明文值。
  - `Scripts/migrate_llm_credentials.ps1`: 新增旧库迁移脚本，将旧明文 LLM 凭据迁入 Credential Manager 并回写引用。
  - `Tests/Test.UniBase.LLM.pas`: 补充 Credential Manager 存储、旧明文迁移和 `LLMApiKeys` 引用解析回归测试。
  - LLM Schema/诊断/文档更新为 `CREDMAN` 存储语义。

#### ARCH-017: 补充 .editorconfig 到 CLAUDE.md
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P2 (开发体验)
- **问题**: 项目有 `.editorconfig` 但未在 `CLAUDE.md` 中说明代码风格约定
- **影响**: AI 辅助开发时可能不遵守项目代码风格
- **任务**:
  - [x] 在 CLAUDE.md 中引用 .editorconfig 关键规则
  - [x] 说明 Delphi 特定的代码风格约定
- **完成说明**:
  - 新增 `CLAUDE.md`，明确 `.editorconfig` 的 CRLF/UTF-8/缩进/尾随空白规则。
  - 补充 Delphi/Object Pascal 命名、异常、资源释放、FireDAC 参数化 SQL、Windows 条件编译和回归测试约定。

#### ARCH-018: 补充集成测试的 CI 配置
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P2 (DevOps)
- **问题**: 集成测试需要数据库环境，当前 CI 配置未说明如何启用
- **影响**: CI 中集成测试被跳过
- **任务**:
  - [x] 编写 CI 集成测试配置文档
  - [x] 说明 `UNIBASE_RUN_DB_INTEGRATION=1` 环境变量
  - [x] 说明 FireDAC 驱动安装要求
- **完成说明**:
  - `.github/workflows/delphi-ci.yml`: 改为统一调用 `Scripts/run_tests.ps1`，默认运行 Unit 和排除 `DBEnv` 的 Integration；workflow_dispatch 可开启 DBEnv 集成测试。
  - `docs/07.03.uniBase-4H-安全与测试-v1.0.md` / `README.md`: 补充 `UNIBASE_RUN_DB_INTEGRATION=1`、FireDAC SQLite 单元、`sqlite3.dll` 位宽匹配和本地回环测试开关说明。

---

## 架构专家审阅优化任务 — 第二轮 (2026-05-03)

> 基于架构/Delphi/安全/文档/数据库 5 位专家深度审阅（第二轮），识别出 8 项 P0 + 12 项 P1 + 6 项 P2 问题
>
> 综合评分：架构 5.5 | Delphi代码 7.0 | 安全 4.5 | 文档 5.5 | 数据库 7.0 | **均值 5.9/10**

### 🔴 P0 - 必须修复

#### ARCH-019: Core 层直接依赖 FireDAC，破坏分层隔离
- **状态**: 🟡 进行中（2026-05-04）
- **优先级**: P0 (架构)
- **问题**: Core/ 下 23 个 .pas 文件直接 `uses FireDAC.Comp.Client` 等单元，破坏了技术规范"Core 无 UI 依赖"的承诺。轻量项目被迫引入完整 FireDAC。
- **影响**: 编译体积膨胀、部署复杂、技术锁定
- **任务**:
  - [x] 引入 `UniBase.Storage.Interfaces.pas`（IConfigStorage, IFormStateStorage, II18nStorage, ISecuritySecretStorage, ILicenseStorage, IMRUStorage, IHotkeyStorage, IThemeStorage, ILogStorage 等）并补齐 Authorization 专用存储抽象
  - [ ] Core 只依赖接口，FireDAC 实现移到 Persistence/
  - [ ] 确保 UniBaseCore.dpk 不再包含 FireDAC 引用
- **阶段进展**:
  - `Core/UniBase.Logging.pas` 已移除 `FireDAC/Data.DB/TFDConnection/TFDQuery` 直接依赖，改为 `ILogStorage` 工厂注入。
  - `Persistence/UniBase.Persistence.Logging.FireDAC.pas` 已重写为 FireDAC 适配器，并在 initialization 自动注册到 Logger 存储工厂。
  - `Scripts/build_packages_win64.ps1 -Profile Runtime` 已通过（Core/Services/Persistence/Features 全链路编译通过），为后续继续拆分 Core 依赖提供稳定基线。
  - `UniBaseCore.dpk` 中历史重复/无效单元已清理，当前剩余阻塞点是 Core 多模块仍直接 `uses FireDAC.*`，需继续下沉到 Persistence。
  - `Core/UniBase.Manager.pas` 已接入 `IManagerStorage` 工厂扩展点（`SetStorageFactory/CreateStorageFromConnection`），并在 Schema 校验/ProjectInfo/SchemaVersion 等路径优先走抽象接口，保留 SQL 回退。
  - `2026-05-04`：`Core/UniBase.Manager.pas` 已将 `FireDAC.Stan.Def/Async/DApt/Stan.ExprFuncs/Phys.SQLite/Phys.SQLiteDef` 从 interface uses 下沉到 implementation uses，仅保留 `TFDConnection` 所需最小公开类型依赖。
  - `2026-05-04`：`Core/UniBase.Manager.pas` 的 `CreateSchema`、`RunMigrationScript`、`EnsureSchemaColumns`（MRU 补丁 DDL）已改为优先走 `IManagerStorage.ExecuteStatement`，仅在无存储适配器时回退 `TFDQuery`。
  - `2026-05-04`：`Core/UniBase.Manager.pas` 的 `ArchiveAndTrimTable`（运维保留策略归档/清理）已改为优先走 `IManagerStorage.ExecuteStatement`，仅在无存储适配器时回退 `TFDQuery`。
  - `2026-05-04`：`Core/UniBase.SQLLogger.pas` 的公开签名已从 `TFDConnection/TFDQuery` 收敛为 `TObject`，`FireDAC.Comp.Client` 下沉到 implementation uses，调用侧不再被迫在接口层引用 FireDAC 类型。
  - `2026-05-04`：`Core/UniBase.TestHelper.pas` 的公开连接参数已从 `TFDConnection` 收敛为 `TObject`，并通过内部安全转换访问 FireDAC，实现接口层去耦。
  - `2026-05-04`：`Core/UniBase.LLM.pas` 的公开连接字段/构造参数/属性已从 `TFDConnection` 收敛为 `TObject`，并通过 `GetFDConnection` 内部转换使用 FireDAC，`FireDAC.Comp.Client` 已下沉到 implementation uses。
  - `2026-05-04`：`Core/UniBase.LLM.Manager.pas` 的公开连接字段/构造参数/属性已从 `TFDConnection` 收敛为 `TObject`，并通过 `GetFDConnection` 内部安全转换使用 FireDAC，`FireDAC.Comp.Client` 已下沉到 implementation uses。
  - `2026-05-05`：`Core/UniBase.ORM.pas` 的公开连接字段/构造参数/属性已从 `TFDConnection` 收敛为 `TObject`，`FireDAC.Comp.Client` 下沉到 implementation uses；查询映射签名改为 `TDataSet`，内部通过类型检查与转换访问 FireDAC。
  - `2026-05-05`：`Core/UniBase.Manager.pas` 的公开 `ConfigDB` 属性与内部连接字段已收敛为 `TObject`，`FireDAC.Comp.Client` 下沉到 implementation uses；核心 DB 访问点改为内部显式转换使用 FireDAC，调用侧不再需要接口层 FireDAC 类型。
  - `Persistence/UniBase.Persistence.Manager.FireDAC.pas` 已补齐 `IManagerStorage` 适配并纳入 `UniBasePersistence.dpk`，运行时可自动注册 Manager 存储实现。
  - `IManagerStorage` 已扩展 `CreateConfigStorage/CreateI18nStorage/CreateThemeStorage/CreateSecuritySecretStorage/CreateFormStateStorage/CreateMRUStorage/CreateHotkeyStorage`；`Core/UniBase.Manager.pas` 初始化 `Config/I18n/Theme/Security/FormState/MRU/Hotkeys` 时优先使用接口存储（失败自动回退旧路径），进一步减少模块级 FireDAC 耦合。
  - `Core/UniBase.Config.pas`、`Core/UniBase.FormState.pas`、`Core/UniBase.MRU.pas` 已移除内嵌 `TFireDAC*Storage` 与 `FireDAC.*` 直接依赖；连接构造统一为 `Create(AConnection: TObject)`，仅通过已注册存储工厂解析。
  - `Core/UniBase.Theme.pas`、`Core/UniBase.Hotkeys.pas`、`Core/UniBase.i18n.pas` 已移除内嵌 `TFireDAC*Storage` 与 `FireDAC.*` 直接依赖；连接构造统一为 `Create(AConnection: TObject)`，仅通过已注册存储工厂解析。
  - `2026-05-04`：`Config/FormState/MRU/Theme/Hotkeys/i18n/License/Security` 的 `CreateStorageFromConnection` 已统一为“仅在 `AConnection<>nil` 时调用工厂”，修复空连接场景触发 `Expected TFDConnection` 的误报。
  - `2026-05-04`：`Core/UniBase.Exception.pas` 已移除 `TFireDACExceptionReportStorage` 与 `FireDAC.*` 依赖，异常上报仅通过 `IExceptionReportStorage` 工厂解析，FireDAC 适配器完全下沉到 `Persistence/UniBase.Persistence.Exception.FireDAC.pas`。
  - `2026-05-04`：`Core/UniBase.Diagnose.pas` 已移除内置 `TFireDACDiagnoseStorage` 回退，`CreateDiagnoseStorage` 改为仅通过注册工厂解析，FireDAC 适配器统一由 `Persistence/UniBase.Persistence.Diagnose.FireDAC.pas` 提供。
  - `Tests/UniBaseTests.dpr`、`Tests/Integration/UniBaseIntegrationTests.dpr` 已显式引入 `UniBase.Persistence.Manager.FireDAC`，确保测试入口稳定完成 Manager/模块存储工厂注册。
  - `VCL/UniBase.VCL.FormStateHelper.pas`、`FMX/UniBase.FMX.FormStateHelper.pas`、`VCL/UniBase.VCL.MRUControls.pas`、`UniBaseRun/ViewMain.pas`、`Examples/Phase0Demo/MainForm.pas` 已改为优先复用 `UniBase.Manager` 持有的 `FormState/MRU/Config/I18n` 模块实例，减少直接按 `ConfigDB` 构造子模块的路径。
  - 回归验证通过：`Scripts/build_packages_win64.ps1 -Profile Runtime`、`Scripts/run_tests.ps1 -Type Unit -Platform Win64 -CI`、`Scripts/run_tests.ps1 -Type All -Platform Win64 -CI`。

#### ARCH-020: 异常类继承断裂（EUniBaseDbError / EMathException）
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P0 (代码质量)
- **问题**: `EUniBaseDbError`(DoQry) 和 `EMathException`(Math) 继承自 `Exception` 而非 `EUniBaseException`，全局 `if E is EUniBaseException` 无法捕获
- **影响**: 全局异常处理失效，错误上下文丢失
- **任务**:
  - [x] `EUniBaseDbError` 改为 `EDatabaseException` 或继承 `EUniBaseException`
  - [x] `EMathException` 改为继承 `EUniBaseException`
  - [x] 扫描所有异常类确认继承链完整
- **修复摘要**:
  - `Persistence/UniBase.DB.DoQry.pas`、`Core/UniBase.DB.DoQry.pas` 中 `EUniBaseDbError` 已改为继承 `EUniBaseException`。
  - `Core/UniBase.Math.pas` 中 `EMathException` 已改为继承 `EUniBaseException`。
  - `Tests/Test.UniBase.Exception.pas` 新增继承链回归测试，验证 `EMathException` 与 `EUniBaseDbError` 均可被 `EUniBaseException` 捕获。

#### ARCH-021: 支付签名验证严重缺陷（CVSS 9.8）
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P0 (安全)
- **问题**:
  - 支付宝 `RSA2Verify` 未实际执行 RSA-SHA256 验证，沙箱模式直接返回 True
  - 支付宝 `ImportRSAPrivateKey` 始终返回 False（空实现）
  - 微信支付 `ImportRSAPrivateKey` DER 格式非 CryptoAPI BLOB，无法工作
  - PayPal `VerifySignature` 直接返回 True
- **影响**: 攻击者可伪造支付回调，导致虚假支付确认
- **任务**:
  - [x] 支付宝：实现真正的 RSA-SHA256 签名验证（Windows 下使用 CNG 验签）
  - [x] 微信支付：实现 PEM→CryptoAPI BLOB 正确转换
  - [x] PayPal：`VerifySignature` 收敛为必需 transmission 参数并调用 `VerifyWebhookSignature`
  - [x] 补充签名验证的单元测试（含伪造回调拦截测试）
- **修复摘要 (2026-05-03)**:
  - `ThirdParty/Payment/UniBase.Payment.Alipay.pas`：移除沙箱直接放行，改为真实 RSA-SHA256 验签；无公钥/空签名直接拒绝。
  - `ThirdParty/Payment/UniBase.Payment.WeChatPay.pas`：签名验签改为 `TRSAVerifier` 实际校验，缺少公钥不再降级放行。
  - `ThirdParty/Payment/UniBase.Payment.WeChatPay.pas`：新增 PEM 私钥 DER 解析（PKCS#8/PKCS#1）、RSA 私钥 BLOB 构造与 CNG `BCryptSignHash` RSA-SHA256 签名路径，修复私钥导入不可用问题。
  - `ThirdParty/Payment/UniBase.Payment.PayPal.pas`：`VerifySignature` 不再恒为 `True`，缺少 transmission 上下文时直接拒绝；生产环境 `VerifyNotification` 默认 fail-closed。
  - `Tests/Test.UniBase.Payment.pas`：新增支付签名安全回归测试，覆盖支付宝/微信“无公钥拒绝”与 PayPal 上下文缺失拒绝。

#### ARCH-022: TBasicProtection 硬编码密钥 + HMAC 实现错误
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P0 (安全)
- **问题**:
  - 默认密码 `@2241114` 硬编码在源码中，所有默认实例共享同一密钥 (CVSS 9.1)
  - `CalculateHMAC` 实现为 `SHA256(Key || Data)` 而非 HMAC-SHA256，存在长度扩展攻击 (CVSS 7.4)
- **影响**: 加密数据可被任何获得源码的人解密
- **任务**:
  - [x] 移除硬编码默认密钥，要求调用方必须提供
  - [x] 修复 `CalculateHMAC` 使用真正的 HMAC-SHA256（THashSHA2.GetHMAC*）
  - [x] 补充 HMAC 测试向量验证
- **修复摘要 (2026-05-03)**:
  - `Core/UniBase.Protection.pas`：`CalculateHMACBinary` 改为真实 HMAC-SHA256；`DeriveAes256Key/CalculateHMAC` 增加空口令 fail-closed 校验并抛出 `EMissingConfigurationException`。
  - `Core/UniBase.Services.Protection.pas`：去除 `TBasicProtectionServiceImpl` 默认硬编码口令；新增 `EnsurePasswordConfigured`，在加解密与 HMAC 前强制检查；服务层 HMAC 改为 `THashSHA2.GetHMAC(..., SHA256)`；`TAntiTamperServiceImpl.GetDefaultConfig` 的 `KeyString` 置空。
  - `Core/UniBase.Services.Registration.pas`：`RegisterProtectionServices` 默认参数改为空；`RegisterDefaultServices` 不再注入 `@2241114`。
  - `Tests/Test.UniBase.Protection.pas`：新增标准 HMAC-SHA256 向量断言与空口令异常测试。
  - `Tests/Test.UniBase.Services.Protection.pas`：测试初始化时显式配置 `KeyString`，与新安全约束一致。

#### ARCH-023: DoQry 缓存 TOCTOU 竞态 + TFDQuery 泄漏
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P0 (并发)
- **问题**: `LoadQuerySQL` 缓存查找和未命中计数使用两段独立加锁，高并发下可能重复查询。`GetOrCreatePreparedQuery` 中新 TFDQuery 在异常时泄漏。
- **影响**: 缓存统计不准、数据库查询风暴、内存泄漏
- **任务**:
  - [x] 合并缓存查找+未命中计数为单次持锁操作
  - [x] `GetOrCreatePreparedQuery` 使用 try/finally 保护新对象
  - [x] 添加并发压力测试验证
- **修复摘要 (2026-05-03)**:
  - `Core/UniBase.DB.DoQry.pas`：`LoadQuerySQL` 改为“缓存检查 + miss 计数 + 并发加载协调”一体化持锁逻辑；新增 `GQueryCacheLoading` 与 `TMonitor.Wait/PulseAll`，同一 `ProcName` 并发只允许一个线程查库，其他线程等待缓存结果。
  - `Core/UniBase.DB.DoQry.pas`：`GetOrCreatePreparedQuery` 新增 `NewQuery/NewEntry` 异常回收路径，`AddOrSetValue` 异常时不再泄漏 `TFDQuery`。
  - `Core/UniBase.DB.DoQry.pas`：`UniDbInit/UniDbClearQueryCache/UniDbShutdown` 同步管理 `GQueryCacheLoading` 生命周期，避免等待状态残留。
  - `Tests/Test.UniBase.DB.DoQry.pas`：新增 `Test_CacheConcurrentLoad_SingleMissAndStableResult` 并发回归测试，验证并发加载稳定性与缓存命中/未命中统计。

#### ARCH-024: ConnectionPool 锁内 I/O + SQLite InsertReturningId 竞态
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P0 (并发/数据)
- **问题**:
  - `EnsureMinConnections` 在锁内执行 `CreateConnection`（阻塞 I/O），阻塞所有获取连接操作
  - `UniDbInsertReturningId` 在 SQLite 下先 INSERT 再 `last_insert_rowid()`，并发场景可能返回错误 ID
- **影响**: 网络延迟阻塞整个连接池；高并发写入返回错误自增 ID
- **任务**:
  - [x] 将连接创建移到锁外，仅在锁内做指针操作
  - [x] SQLite InsertReturningId 改用 `INSERT ... RETURNING id`（SQLite 3.35+）或单事务保护
  - [x] 补充并发写入测试
- **修复摘要 (2026-05-03)**:
  - `Persistence/UniBase.DB.Pool.pas`：`EnsureMinConnections` 改为先计算缺口，锁外批量 `CreateConnection`，再锁内挂接到池，避免锁内阻塞 I/O。
  - `Core/UniBase.DB.DoQry.pas`：SQLite `UniDbInsertReturningId` 改为 `INSERT ... RETURNING id` 路径，移除 `last_insert_rowid()` 两段式读取。
  - `Tests/Test.UniBase.DB.DoQry.pas`：新增触发器回归测试 `Test_InsertReturningId_WithTrigger_ReturnsTargetTableId`，覆盖 `last_insert_rowid()` 易错场景。
  - `Tests/Test.UniBase.DB.DoQry.pas`：新增并发写入回归 `Test_InsertReturningId_ConcurrentWrites_ReturnUniqueIds`，验证并发 `InsertReturningId` 的稳定性与 ID 唯一性。

#### ARCH-025: 文档 API 签名与实际代码严重不符
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P0 (文档)
- **问题**:
  - 05.01 API参考 Manager 属性名错误（Initialized→IsInitialized, Connection→ConfigDB, Log→Logger）
  - 04.03 数据库指南 API 名完全不同（DoQryInit vs UniDbInit, TDoQryContext vs TUniQueryContext）
  - 07.01 检查清单使用不存在的 `GetSetting/SetSetting`
  - 05.03 DoQry 指南 `Logger.LogInfo` 不存在（应为 `Logger.Info`）
- **影响**: 按文档编码无法编译，开发者信任度下降
- **任务**:
  - [x] 修正 05.01 Manager 属性签名 + 补充 InitializeWithDB/WhenReady + 修正日志类名
  - [x] 修正 04.03 全部 API 名称为 UniDb* 系列 + SAVEPOINT 标注为计划中
  - [x] 修正 07.01 GetSetting/SetSetting → GetConfig/SetConfig
  - [x] 修正 05.03 Logger.Info + TClientDataSet→TFDMemTable + SQL关键字列表

#### ARCH-026: Schema 表名与代码不一致 + Token 价格单位差 1000 倍
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P0 (数据/文档)
- **问题**:
  - 04.01 Schema 定义 `LLMPrompts`，代码使用 `LLMPromptTemplates`
  - 05.01 Token 价格定义"每 1K Token"，04.01 Schema 定义 `InputPricePer1M`（每 1M），差 1000 倍
  - 00.00 索引写"23 张表"，04.01 写"24 张表"
- **影响**: 按文档建表后代码找不到表；价格计算出错
- **任务**:
  - [x] 统一 ARCH-QUICKSTART 中 LLMPromptTemplates→LLMPrompts（与 Schema.pas 一致）
  - [x] 确认 Token 价格字段名 InputPricePer1M 与 Schema DDL 一致
  - [x] 更新 00.00 索引 + 04.01 + 01.01 中表数量为 24 张

---

### 🟡 P1 - 高优先级

#### ARCH-027: Core 目录膨胀至 101 个文件
- **状态**: 🔲 待开始
- **优先级**: P1 (架构)
- **问题**: Core/ 包含 CLI（Interactive/Pipeline/SSH）、CloudSync、CloudBackup、HttpServer、Graph、Math 等不应属于核心基础设施的模块
- **影响**: "最小核心"设计理念名存实亡，编译时间增加
- **任务**:
  - [ ] CLI 相关移至 `Tools/CLI/`
  - [ ] CloudSync/CloudBackup 移至 `Features/`
  - [ ] Graph/Math 等边界功能移至 `Features/`
  - [ ] 更新技术规范文档中的目录结构

#### ARCH-028: Core/Features 同名文件冲突（5 个文件）
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P1 (代码质量)
- **问题**: AntiTamper/AutoUpdate/Protection/Unlock/Updater 在 Core/ 和 Features/ 同时存在
- **影响**: 编译器 unit collision 警告，修改一处漏改另一处
- **任务**:
  - [x] 删除 Core/UniBase.Unlock.pas（与 Features/ 完全相同）
  - [x] 删除 Core/UniBase.AntiTamper.pas（Features/ 是超集，XOR 死代码已移除）
  - [x] 删除 Core/UniBase.AutoUpdate.pas（Features/ 是超集）
  - [x] 删除 Core/UniBase.Updater.pas（Features/ 是超集）
  - [x] 删除 Features/UniBase.Protection.pas（Core/ 有 GCM+CBC 完整实现）
  - [x] 更新 .dpk/.dproj 引用并验证构建（2026-05-03，`cmd /c build_test.bat` `errorlevel 0`）
- **阶段进展**:
  - `UniBaseCore.dpk`：移除对已删除 `Core\UniBase.AutoUpdate.pas`、`Core\UniBase.AntiTamper.pas` 的无效引用。
  - `UniBaseFeatures.dpk`：移除对已删除 `Features\UniBase.Protection.pas` 的无效引用，保留 `UniBaseCore` 中 `UniBase.Protection` 实现。
  - `Tests/TestNewModules.dpr` 与 `Examples/FullDemo/FullDemo.dpr`：将 `Updater/AutoUpdate` 路径统一到 `Features\` 实现，避免旧路径编译失败。

#### ARCH-029: AipexBase Core/ThirdParty 重复 + ThirdParty 含 UI 代码
- **状态**: ✅ 完成 (2026-05-04)
- **优先级**: P1 (架构)
- **问题**: AipexBase.Client 同时存在于 Core/ 和 ThirdParty/（差异巨大）。ThirdParty/AipexBase/ 直接包含 VCL/FMX Frame 代码，模糊层边界。
- **影响**: 归属混乱，开发者不确定用哪个
- **任务**:
  - [x] 统一 AipexBase.Client 到 ThirdParty/
  - [x] VCL/FMX Frame 移至对应 VCL/FMX 目录
  - [x] ThirdParty 只保留"接口+实现+工厂"
- **阶段进展**:
  - `Examples/UserAuthDemo/UserAuthDemo.dpr` 已改为引用 `ThirdParty\AipexBase\UniBase.AipexBase.Client.pas`，并清除 `Core\UniBase.AipexBase.Client.pas` 路径残留引用。
  - `VCL/` 与 `FMX/` 已承载 `LoginDialog/RegisterDialog/ForgotPasswordDialog/UserProfileFrame/BalanceFrame/UsageStatsFrame/BillingFrame`，项目入口不再引用 `ThirdParty\AipexBase\VCL|FMX` 路径。
  - `ThirdParty/AipexBase/` 新增 `UniBase.AipexBase.Factory.pas`，并将 `UniBase.AipexBase.Client.pas` 纳入版本库，收敛为 API 客户端 + 工厂实现。

#### ARCH-030: Payment 模块策略与文档矛盾
- **状态**: ✅ 完成 (2026-05-04)
- **优先级**: P1 (架构)
- **问题**: 文档 06.01 明确禁止"直接实现各渠道 SDK"，但 Payment/ 完整实现了 Alipay/WeChat/Stripe/PayPal SDK 对接
- **影响**: 架构决策文档失效
- **任务**:
  - [x] 决策：保留直接实现 or 改为后端代理
  - [x] 更新文档 06.01 与实际策略一致
- **决策与完成摘要 (2026-05-04)**:
  - 采用“双模式并行”策略：`ThirdParty/Payment` 继续支持直连 SDK；`ThirdParty/AipexBase` 作为企业化后端代理推荐路径。
  - `docs/06.01.uniBase-4H-ThirdParty扩展开发指南-v1.1.md`：将“仅后端代理”更新为“双模式策略”，并明确适用场景与边界约束。
  - `ThirdParty/Payment/README.md`：新增架构定位，明确与 AipexBase 代理模式的关系与选型建议。

#### ARCH-031: EventBus 订阅者强引用内存泄漏
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P1 (内存)
- **问题**: `FSubscriptions` 持有匿名方法闭包的强引用，订阅者对象销毁后若未 `Unsubscribe`，事件总线持续持有悬空引用
- **影响**: TForm 等组件无法释放，内存持续增长
- **任务**:
  - [x] 提供基于弱引用的订阅机制
  - [x] 或在 Publish 时检测并跳过已销毁的订阅者
  - [x] 文档中强调必须 Unsubscribe
- **修复摘要**:
  - `Core/UniBase.EventBus.pas`：新增 `SubscribeWeak<T>(AOwner, ...)`，将订阅绑定到 `TComponent` 生命周期，owner 销毁时自动退订，避免悬空订阅持续保留。
  - `Core/UniBase.EventBus.pas`：在 `Unsubscribe/UnsubscribeAll/UnsubscribeByTag/Clear` 同步清理弱订阅链接，防止重复回调与链接残留。
  - `Tests/Test.UniBase.EventBus.pas`：新增弱订阅回归测试（owner 销毁自动退订、手工退订后 owner 销毁无副作用）。

#### ARCH-032: CircuitBreaker AllowRequest/RecordFailure 非原子
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P1 (可靠性)
- **问题**: 手动调用 `AllowRequest → 业务 → RecordFailure` 三步非原子，漏调 RecordFailure 导致断路器状态不一致
- **影响**: 断路器可能永远不触发熔断
- **任务**:
  - [x] 标记 `AllowRequest` 为 deprecated，引导使用 `Execute` 封装方法
  - [x] 添加自动超时记录失败的机制
- **修复摘要**:
  - `Core/UniBase.Resilience.pas`：`AllowRequest` 已标记 `deprecated`，提示迁移到 `Execute(...)` 以保证状态更新原子性。
  - 模块头部示例已改为 `Breaker.Execute(...)` 推荐用法，避免新代码继续采用 `AllowRequest → RecordSuccess/RecordFailure` 手工三段式调用。
  - `Core/UniBase.Resilience.pas`：`TCircuitBreaker` 新增 `Execute(Proc, TimeoutMs)` / `Execute<T>(Func, TimeoutMs)` 重载，将超时异常纳入断路器失败统计。
  - `Tests/Test.UniBase.Resilience.pas`：新增超时回归测试，验证超时会触发 `ETimeoutException` 且按阈值打开断路器。

#### ARCH-033: 微信/QQ OAuth AppSecret 通过 GET URL 暴露
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P1 (安全)
- **问题**: `ExchangeCode` 和 `RefreshToken` 将 AppSecret 作为 URL 查询参数，会被记录在浏览器历史、代理日志、Referrer 中
- **影响**: AppSecret 泄露风险
- **任务**:
  - [x] 微信 API 限制：在文档中标注风险，建议使用服务端代理
  - [x] QQ：检查是否可改用 POST body 传输 client_secret
  - [x] 添加安全最佳实践文档
- **阶段进展**:
  - `ThirdParty/Social/README.md`：新增 OAuth 凭据传输安全建议，明确微信 token 交换接口存在 URL 暴露风险，推荐服务端代理中转。
  - `ThirdParty/Social/README.md`：补充 QQ 建议策略为 POST body 传输 `client_secret`，仅在兼容性要求下回退 GET，并要求日志脱敏。
  - 代码核查结论：QQ OAuth token 交换路径可采用 POST body（兼容分支可保留 GET 回退）；微信官方接口限制仍需通过部署策略（后端代理）规避风险。

#### ARCH-034: EncryptWithIV/DecryptWithIV 忽略 IV + OAuth Microsoft 映射错误
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P1 (安全)
- **问题**: `EncryptWithIV`/`DecryptWithIV` 接受 IV 参数但完全忽略。OAuth `SetupForMicrosoft` 将 Provider 设为 `spGoogle`。
- **影响**: 自定义 IV 的安全需求未实现；Microsoft 登录用户信息映射错误
- **任务**:
  - [x] 实现或移除 EncryptWithIV/DecryptWithIV
  - [x] 修复 Microsoft OAuth Provider 枚举映射
- **修复摘要**:
  - `Core/UniBase.Services.Crypto.pas`：`EncryptWithIV/DecryptWithIV` 改为使用 `TAESCrypto`，显式校验 IV 长度并实际参与加解密流程（不再忽略 IV）。
  - `ThirdParty/Social/UniBase.Social.pas`：新增 `spMicrosoft` Provider 枚举及字符串映射。
  - `ThirdParty/Social/UniBase.Social.OAuth.pas`：`SetupForMicrosoft` 的 Provider 从 `spGoogle` 修正为 `spMicrosoft`。
  - 回归测试：
    - `Tests/Test.UniBase.Crypto.pas` 新增 `TCryptoServiceImplTests`（IV 回环、不同 IV 结果差异、非法 IV 抛错）。
    - `Tests/Test.UniBase.Social.pas` 新增 Microsoft Provider 映射与预置配置断言。

#### ARCH-035: UniDbRunInTx 不支持 SAVEPOINT 但文档声称支持
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P1 (数据/文档)
- **问题**: 04.03 文档声称"支持嵌套 SAVEPOINT"，但 `UniDbRunInTx` 完全没有实现嵌套事务，同一连接已有事务时 FireDAC 抛异常
- **影响**: 嵌套事务场景运行时异常
- **任务**:
  - [x] 实现 SAVEPOINT 支持（SQLite: `SAVEPOINT sp1` / `RELEASE sp1`）
  - [x] 已实现 SAVEPOINT，文档声明保留
- **修复摘要 (2026-05-03)**:
  - `Core/UniBase.DB.DoQry.pas`：`TUniTransaction` 新增嵌套事务检测；外层事务仍使用 `StartTransaction/Commit/Rollback`，内层事务自动切换到 `SAVEPOINT/RELEASE/ROLLBACK TO SAVEPOINT`。
  - `Tests/Test.UniBase.DB.DoQry.pas`：新增 `Test_RunInTx_NestedSavepoint_CommitWorks` 与 `Test_RunInTx_NestedSavepoint_InnerRollbackKeepsOuter`，验证嵌套提交与内层回滚行为。

#### ARCH-036: 预编译语句池无上限 + WebAPI CORS 默认全开
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P1 (性能/安全)
- **问题**:
  - `GPreparedPool` 无大小上限、无 LRU 淘汰，动态 SQL 场景下无限增长
  - WebAPI `FCORSOrigins := '*'` 且 `FCORSEnabled := True`，生产环境跨域安全风险
  - WebAPI 缺少内置认证中间件（JWT/API Key）
- **影响**: 内存持续增长；API 任意跨域访问
- **任务**:
  - [x] 预编译池添加容量上限（默认 500）和 LRU 淘汰
  - [x] CORS 默认改为空（生产必须显式配置）
  - [x] 添加 API Key / JWT 认证中间件示例
- **阶段进展 (2026-05-03)**:
  - `Core/UniBase.DB.DoQry.pas`：预编译语句池新增 `GPreparedPoolMaxSize`（默认 500）与 `UniDbSetPreparedPoolMaxSize`；新增 LRU 淘汰与“在用计数（InUseCount）”保护，避免淘汰正在执行的语句对象。
  - `Core/UniBase.DB.DoQry.pas`：补充 `Query -> Entry` 索引，`ReleaseQuery` 改为按索引归还并更新最近使用时间，确保统计与淘汰依据稳定。
  - `Tests/Test.UniBase.DB.DoQry.pas`：新增 `Test_PreparedPool_MaxSizeEnforcesLRUEviction` 回归测试，验证容量上限与 LRU 行为。
  - `Tools/WebService/UniBase.WebAPI.Core.pas`：`TApiServerConfig` 默认改为 `CORSEnabled=False`、`CORSOrigins=''`；`HandleCORS` 在 origins 为空时不再写入 CORS 响应头，默认 fail-closed。
  - `Tests/Test.WebService.pas`：新增 `Test_ApiServerConfig_DefaultCorsIsClosed`，验证 CORS 安全默认值。
  - `Tests/Test.WebService.pas`：新增 JWT/API Key 中间件示例测试（`Test_JWT_Middleware_Example_DeniesMissingToken`、`Test_ApiKey_Middleware_Example_AllowsValidKey`），展示最小可运行接入方式。

#### ARCH-037: LLM 三套 API 并存 + 术语表偏离
- **状态**: ✅ 完成 (2026-05-04)
- **优先级**: P1 (文档)
- **问题**:
  - LLM 存在三套 API：`TUniBaseLLM`(Core)、`LLM()`facade(Features)、`TLLMManager`(Core)，无迁移说明
  - 02.01 术语表 80% 为 uniFlow 工作流术语，UniBase 核心术语（ConfigDB/DoQry/FormState/MRU）缺失
  - 05.05 提示词 5 张表未列入 04.01 Schema
- **影响**: 开发者无法确定使用哪套 API；术语表无用
- **任务**:
  - [x] 在文档中添加 LLM API 迁移对照表
  - [x] 重写术语表为 UniBase 核心 + uniFlow 分离
  - [x] 04.01 Schema 补充提示词相关表
- **完成摘要 (2026-05-04)**:
  - `docs/05.05.uniBase-4AI-LLM集成指南-v1.0.md`：新增 LLM 三套 API 迁移对照矩阵（`TUniBaseLLM` / `TLLMManager` / `LLM()`）。
  - `docs/02.01.uniBase-4AI-术语表-v1.0.md`：重写为“UniBase 核心术语 + uniFlow 术语”双区结构，补齐 ConfigDB/UniDb/FormState/MRU/LLM 术语。
  - `docs/04.01.uniBase-4AI-数据库Schema说明-v1.0.md`：补充 Prompt Studio 5 张扩展表映射说明（`PromptCategories` 等）。

#### ARCH-038: Schema 版本号不一致 + 04.03 API 命名不同
- **状态**: ✅ 完成 (2026-05-04)
- **优先级**: P1 (文档)
- **问题**:
  - Schema 版本有 0.3 / 1.0 / 1.0.0 三种说法
  - 04.03 使用 `DoQryInit/DoQryExecSelect`，05.03 使用 `UniDbInit/UniDbSelect`，代码使用后者
  - 01.01 文档版本号 v1.0 vs 文末 Document Version v1.1
- **影响**: 无法确定当前版本，API 命名混乱
- **任务**:
  - [x] 统一 Schema 版本号为单一值
  - [x] 归档或重写 04.03（API 名与代码完全不同）
  - [x] 统一 01.01 文档版本号
- **完成摘要 (2026-05-04)**:
  - `docs/03.03.uniBase-4H-技术规范-v1.0.md`：`SchemaVersion` 示例统一为 `1.0.0`，DoQry 示例 API 统一收敛为 `UniDb*` 命名（含 `TUniQueryContext`）。
  - `docs/04.03.uniBase-4AI-数据库指南-v1.0.md`：已使用 `UniDbInit/UniDbSelect` 命名并说明 `UniDbRunInTx` 嵌套 `SAVEPOINT` 支持。
  - `docs/01.01.uniBase-4AI-集成指南-v1.0.md`：文末版本元数据已统一为 `Document Version: 1.0`。

---

### 🟢 P2 - 改进优化

#### ARCH-039: 引入数据库访问抽象层
- **状态**: 🟡 进行中（2026-05-04）
- **优先级**: P2 (架构)
- **任务**:
  - [x] 定义 `IConfigStorage`、`IFormStateStorage`、`II18nStorage`、`ISecuritySecretStorage`、`ILicenseStorage`、`IMRUStorage`、`IHotkeyStorage`、`IThemeStorage`、`ILogStorage`、`ISchemaStorage`、`IManagerStorage` 接口，并补齐 `IAuthorizationStorage`
  - [ ] Core 仅依赖接口，FireDAC 实现全部移入 Persistence/
  - [ ] 为未来支持其他数据库技术（dbExpress/ADO）预留扩展点
- **阶段进展**:
  - `Core/UniBase.Storage.Interfaces.pas` 新增 `IManagerStorage` 契约；`Core/UniBase.Manager.pas` 增加存储工厂注入点并将部分元数据访问迁移为接口优先路径（Schema 校验、列检查、版本/项目信息读写）。
  - `Persistence/UniBase.Persistence.Manager.FireDAC.pas` 与 `UniBasePersistence.dpk` 已打通，Manager 抽象层具备 FireDAC 适配落地。
  - `IManagerStorage` 已新增 `CreateConfigStorage/CreateI18nStorage/CreateThemeStorage/CreateSecuritySecretStorage/CreateFormStateStorage/CreateMRUStorage/CreateHotkeyStorage` 扩展点；`TUniBaseManager.InitializeModules` 对 `Config/I18n/Theme/Security/FormState/MRU/Hotkeys` 采用“接口优先 + 兼容回退”创建策略，减少对连接构造路径的绑定。
  - VCL/FMX 辅助组件与 Demo/Runner 入口已优先复用 Manager 管理的子模块实例，减少外层调用对 `TUniBase*.Create(ConfigDB, Lock)` 构造路径的耦合。
  - 新增 `Core/UniBase.Storage.Interfaces.pas`，统一声明 `IConfigStorage`、`IFormStateStorage`、`II18nStorage`、`ISecuritySecretStorage`、`ILicenseStorage`、`IMRUStorage`、`IHotkeyStorage`、`IThemeStorage`、`ILogStorage`、`ISchemaStorage`。
  - `Core/UniBase.Config.pas` 新增存储注入能力：支持 `TUniBaseConfig.Create(const AStorage: IConfigStorage)`，并通过 `SetConnectionStorageFactory` 对接外部实现。
  - 新增 `Persistence/UniBase.Persistence.Config.FireDAC.pas`，提供 FireDAC 版 `IConfigStorage` 适配器与工厂注册。
  - `Core/UniBase.FormState.pas` 新增存储注入能力：支持 `TUniBaseFormState.Create(const AStorage: IFormStateStorage)`，并通过 `SetConnectionStorageFactory` 对接外部实现。
  - `Persistence/UniBase.Persistence.FormState.FireDAC.pas` 调整为 FireDAC 版 `IFormStateStorage` 适配器，与 Core 抽象对齐。
  - `Core/UniBase.MRU.pas` 新增存储注入能力：支持 `TUniBaseMRU.Create(const AStorage: IMRUStorage)`，并通过 `SetConnectionStorageFactory` 对接外部实现。
  - `Persistence/UniBase.Persistence.MRU.FireDAC.pas` 重构为 FireDAC 版 `IMRUStorage` 适配器，与 Core 抽象对齐。
  - `Core/UniBase.Config.pas`、`Core/UniBase.FormState.pas`、`Core/UniBase.MRU.pas` 已删除 FireDAC 内嵌 SQL 实现（`TFireDAC*Storage`），Core 侧仅保留抽象存储注入与工厂回调。
  - `Core/UniBase.Theme.pas`、`Core/UniBase.Hotkeys.pas`、`Core/UniBase.i18n.pas` 已删除 FireDAC 内嵌 SQL 实现（`TFireDAC*Storage`），Core 侧仅保留抽象存储注入与工厂回调。
  - 连接构造路径在未注册工厂时改为显式抛错（提示引入 `UniBase.Persistence.*.FireDAC` 或 `UniBase.Persistence.Manager.FireDAC`），避免静默降级为无持久化行为。
  - 回归验证：`Scripts/run_tests.ps1 -Type All -Platform Win64 -CI`、`Scripts/build_packages_win64.ps1 -Profile Runtime` 均通过。
  - `Core/UniBase.Hotkeys.pas` 新增存储注入能力：支持 `TUniBaseHotkeys.Create(const AStorage: IHotkeyStorage)`，并通过 `SetConnectionStorageFactory` 对接外部实现。
  - `Persistence/UniBase.Persistence.Hotkeys.FireDAC.pas` 调整为 FireDAC 版 `IHotkeyStorage` 适配器，与 Core 抽象对齐。
  - `Core/UniBase.Theme.pas` 新增存储注入能力：支持 `TUniBaseTheme.Create(const AStorage: IThemeStorage)`，并通过 `SetConnectionStorageFactory` 对接外部实现。
  - `Persistence/UniBase.Persistence.Theme.FireDAC.pas` 调整为 FireDAC 版 `IThemeStorage` 适配器，与 Core 抽象对齐。
  - `Core/UniBase.i18n.pas` 新增存储注入能力：支持 `TUniBaseI18n.Create(const AStorage: II18nStorage)`，并通过 `SetConnectionStorageFactory` 对接外部实现。
  - `Persistence/UniBase.Persistence.I18n.FireDAC.pas` 调整为 FireDAC 版 `II18nStorage` 适配器，与 Core 抽象对齐。
  - `Core/UniBase.Security.pas` 新增存储注入能力：支持 `TUniBaseSecurity.Create(const AStorage: ISecuritySecretStorage)`，并通过 `SetStorageFactory` 对接外部实现；同时保留 `Create(AConnection: TFDConnection)` 兼容构造。
  - `Persistence/UniBase.Persistence.Security.FireDAC.pas` 对齐为 FireDAC 版 `ISecuritySecretStorage` 适配器，与 Core 抽象对齐。
  - `Core/UniBase.License.pas` 新增存储注入能力：支持 `TUniBaseLicense.Create(const AStorage: ILicenseStorage)`，并通过 `SetStorageFactory` 对接外部实现；兼容保留 `Create(AConnection: TFDConnection)` 构造。
  - `Persistence/UniBase.Persistence.License.FireDAC.pas` 对齐为 FireDAC 版 `ILicenseStorage` 适配器，与 Core 抽象对齐。
  - `Core/UniBase.Authorization.pas` 新增存储注入能力：支持 `TAuthorizationManager.Create(const AStorage: IAuthorizationStorage)`，并通过 `SetStorageFactory` / `CreateStorageFromConnection` 对接外部实现；连接构造统一为 `Create(AConnection: TObject)` 并仅通过工厂解析存储。
  - `Persistence/UniBase.Persistence.Authorization.FireDAC.pas` 对齐为 FireDAC 版 `IAuthorizationStorage` 适配器，与 Core 抽象对齐。
  - `Core/UniBase.Storage.Interfaces.pas` 新增 `TExceptionReportData` 与 `IExceptionReportStorage` 契约，统一异常报告持久化数据结构。
  - `Core/UniBase.Exception.pas` 新增异常报告存储注入能力：支持 `SetStorageFactory` / `CreateStorageFromConnection`，并移除 Core 内置 FireDAC 回退实现。
  - `Persistence/UniBase.Persistence.Exception.FireDAC.pas` 新增 FireDAC 版 `IExceptionReportStorage` 适配器，与 Core 抽象对齐。
  - `Core/UniBase.Diagnose.pas` 新增 `IDiagnoseStorage` 抽象与 `*WithStorage` 注入入口（如 `DiagnoseAllWithStorage`、`AutoFixWithStorage`），保留原 `TFDConnection` API 兼容调用。
  - `Core/UniBase.Diagnose.pas` 新增 `SetDiagnoseStorageFactory`/`CreateDiagnoseStorage` 工厂扩展点，可由 Persistence 层注册连接适配器。
  - `Persistence/UniBase.Persistence.Diagnose.FireDAC.pas` 新增 FireDAC 版 `IDiagnoseStorage` 适配器并自动注册工厂。
  - `Tests/Test.UniBase.Config.pas` 增加注入存储回归测试，覆盖无 DB 场景下的读写/存在性/删除行为。
  - `Tests/Test.UniBase.FormState.pas` 增加注入存储回归测试，覆盖无 DB 场景下的状态保存/恢复行为。
  - `Tests/Test.UniBase.Hotkeys.pas` 增加注入存储回归测试，覆盖默认注册/修改/重置/删除完整链路。
  - `Tests/Test.UniBase.Theme.pas` 增加注入存储回归测试，覆盖注入主题元数据读取行为。
  - `Tests/Test.UniBase.i18n.pas` 增加注入存储回归测试，覆盖翻译读取、默认语言与语言列表行为。
  - `Tests/Test.UniBase.Security.pas` 增加注入存储回归测试，覆盖秘密读写/存在性/删除/列表行为。
  - `Tests/Test.UniBase.License.pas` 增加注入存储回归测试，覆盖激活持久化、重建实例恢复与停用清理行为。
  - `Tests/Test.UniBase.Authorization.pas` 增加注入存储回归测试，覆盖角色授权写入与重建实例恢复行为。
  - `Tests/Test.UniBase.Exception.pas` 增加注入存储回归测试，覆盖全局异常处理器经注入存储写入异常报告行为。
  - `Tests/UniBaseTests.dpr`、`Tests/Integration/UniBaseIntegrationTests.dpr` 已显式引入 `UniBase.Persistence.Exception.FireDAC`，确保测试入口始终注册异常报告存储工厂。
  - `Tests/Test.UniBase.Diagnose.pas` 增加存储注入回归测试，覆盖 `DiagnoseAllWithStorage` 聚合结果与 `AutoFixWithStorage` 委托行为。
  - `Tests/UniBaseTests.dpr`、`Tests/Integration/UniBaseIntegrationTests.dpr` 已显式引入 `UniBase.Persistence.Diagnose.FireDAC`，确保 Diagnose 存储工厂在测试入口稳定注册。
  - `Core/UniBase.Storage.Interfaces.pas` 的日志契约已扩展为 `TLogStorageData` + `ILogQueryStorage`，支持完整日志字段与计数查询。
  - `Core/UniBase.Logging.pas` 已完成日志存储抽象切片：DB 写入/清理/计数均走 `ILogStorage` 注入，Core 不再包含 FireDAC SQL 细节。
  - `Persistence/UniBase.Persistence.Logging.FireDAC.pas` 已实现 FireDAC 版 `ILogStorage/ILogQueryStorage`，并保留 `Logs.Extra` 列缺失时的兼容写入路径。
  - `Tests/Test.UniBase.Logging.pas` 新增 `Test_StorageInjection_DelegatesDbWriteAndQuery`，覆盖注入写入、计数与清理委托行为。
  - `2026-05-04`：`Core/UniBase.Authorization.pas`、`Core/UniBase.Exception.pas`、`Core/UniBase.Diagnose.pas`、`Core/UniBase.Manager.pas` 的工厂入口已补齐空连接保护（仅连接非空时调用注册工厂），避免适配器类型检查在 `nil` 输入下误抛异常。
  - `2026-05-04`：`Core/UniBase.Diagnose.pas` 的公开连接参数已统一为 `TObject`（内部仍兼容 FireDAC 转换），并将 `FireDAC.Comp.Client` 从 interface uses 下沉到 implementation uses，降低调用侧编译耦合。
  - `2026-05-04`：`Core/UniBase.Authorization.pas` 已移除 Core 内置 FireDAC SQL 回退（`TFDConnection/TFDQuery`），授权读写与审计持久化仅通过 `IAuthorizationStorage`。
  - `2026-05-04`：`Tests/Test.UniBase.Authorization.pas` 的主测试夹具改为显式注入内存 `IAuthorizationStorage`，不再依赖 FireDAC 内存连接隐式回退；`run_tests -Type All` 回归通过。
  - `2026-05-04`：`Core/UniBase.Manager.pas` 的 `ArchiveAndTrimTable`（`Logs/LLMCalls/ExceptionReports` 归档清理）已改为优先走 `IManagerStorage.ExecuteStatement`，仅在无存储适配器时回退 `TFDQuery`。
  - `2026-05-04`：`Core/UniBase.SQLLogger.pas` 的公开签名已从 `TFDConnection/TFDQuery` 收敛为 `TObject`，`FireDAC.Comp.Client` 下沉到 implementation uses，调用侧不再被迫在接口层引用 FireDAC 类型。
  - `2026-05-04`：`Core/UniBase.TestHelper.pas` 的公开连接参数已从 `TFDConnection` 收敛为 `TObject`，并通过内部安全转换访问 FireDAC，实现接口层去耦。
  - `2026-05-04`：`Core/UniBase.LLM.pas` 的公开连接字段/构造参数/属性已从 `TFDConnection` 收敛为 `TObject`，并通过 `GetFDConnection` 内部转换使用 FireDAC，`FireDAC.Comp.Client` 已下沉到 implementation uses。
  - `2026-05-04`：`Core/UniBase.LLM.Manager.pas` 的公开连接字段/构造参数/属性已从 `TFDConnection` 收敛为 `TObject`，并通过 `GetFDConnection` 内部安全转换使用 FireDAC，`FireDAC.Comp.Client` 已下沉到 implementation uses。
  - `2026-05-05`：`Core/UniBase.ORM.pas` 的公开连接字段/构造参数/属性已从 `TFDConnection` 收敛为 `TObject`，`FireDAC.Comp.Client` 下沉到 implementation uses；查询映射签名改为 `TDataSet`，内部通过类型检查与转换访问 FireDAC。
  - `2026-05-05`：`Core/UniBase.Manager.pas` 的公开 `ConfigDB` 属性与内部连接字段已收敛为 `TObject`，`FireDAC.Comp.Client` 下沉到 implementation uses；核心 DB 访问点改为内部显式转换使用 FireDAC，调用侧不再需要接口层 FireDAC 类型。
  - 回归验证（2026-05-05）：`Scripts/run_tests.ps1 -Type All -Platform Win64 -CI`、`Scripts/build_packages_win64.ps1 -Profile Runtime` 均通过。

#### ARCH-040: BindJsonParams 精度 + InferErrorCode 脆弱
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P2 (代码)
- **任务**:
  - [x] `BindJsonParams` 区分整数/浮点：`TJSONNumber.AsInt64` vs `AsDouble`
  - [x] `InferErrorCode` 改用 FireDAC 驱动原生错误码，不依赖字符串匹配
  - [x] 统一 `UniBase.Cache.TCache<K,V>` 和 `UniBase.Memory.TSmartCache<K,V>`
- **阶段进展**:
  - `Persistence/UniBase.DB.DoQry.pas` 已按 `TJSONNumber` 内容区分整数和浮点绑定，避免整型参数被统一当作浮点处理。
  - `InferErrorCode` 已优先使用 `EFDDBEngineException.Kind` 与原生错误码映射，字符串匹配仅保留为兜底。
  - `Core/UniBase.Memory.pas`：`TSmartCache<K,V>` 内部实现收敛为 `UniBase.Cache.TCache<K,V>` 代理，保留原 API（`TEvictionPolicy`、TTL、OnEvict、统计）并移除重复缓存实现。
  - `Tests/Test.UniBase.Memory.pas`：新增 `Test_EvictionPolicy_None_RaisesWhenFull`，锁定 `epNone` 满容量抛异常行为。

#### ARCH-041: SSRF 防护加固 + SecureZeroMemory
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P2 (安全)
- **任务**:
  - [x] SSRF 防护：在 HTTP 连接建立时再次校验解析后的 IP（防 DNS rebinding）
  - [x] `SecureZeroMemory` 改用 `RtlSecureZeroMemory` 或 `FillMemory`（防编译器优化）
  - [x] OAuth Token 使用后调用 SecureZeroMemory 清除内存
- **阶段进展**:
  - `Core/UniBase.Net.pas`：`THttpRequest.Execute` 在 `IsSafeUrl` 之后新增解析结果二次校验（`ValidateResolvedUrlForHttp`），对解析出的 IPv4/IPv6 地址执行内网、回环、链路本地与元数据地址拦截。
  - `Core/UniBase.Security.pas`：`SecureZeroMemory` 在 Windows 改为调用 `RtlSecureZeroMemory`，非 Windows 使用 `FillChar`，并对字符串执行 `UniqueString` 后清除。
  - `ThirdParty/Social/UniBase.Social.pas` 与 `ThirdParty/Social/UniBase.Social.OAuth.pas`：OAuth token 与授权头相关临时字符串在 `finally` 中执行安全擦除，授权码换取用户信息后的临时 token 立即清理。

#### ARCH-042: 文档去重 + Schema.pas 补充
- **状态**: ✅ 完成 (2026-05-04)
- **优先级**: P2 (文档)
- **任务**:
  - [x] 消除 01.01、04.01、07.01 之间的 DB1 表结构重复内容
  - [x] `UniBase.Schema.pas` 补充 aboutMeImages 表 DDL
  - [x] MRU 表字段名统一：04.01 `ItemPath` vs Schema.pas `ItemKey`
  - [x] 05.05 添加版本号和更新日期
- **阶段进展**:
  - `Core/UniBase.Schema.pas`：Tier2 新增 `aboutMeImages` DDL（含 `Enabled`、`Sha256Hash`、`HmacSha256` 等字段），并纳入 `GetTier2SchemaSQL`。
  - `data/create_sample_db.sql`：MRU 字段统一为 `ItemKey`（替代 `ItemPath`），并补充 `aboutMeImages` 表定义与索引。
  - `Core/UniBase.Manager.pas`：`CreateSchema` 成功后增加兼容补丁阶段，`EnsureSchemaColumns` 为旧库补齐 `MRU.ItemKey`，并将 `ItemPath` 历史数据迁移到 `ItemKey`，同时补建 `(Category, ItemKey)` 唯一索引。
  - `Tests/Test.UniBase.Manager.pas`：新增 `Test_MRUItemPath_IsMigratedToItemKey_OnLegacyDatabase`，覆盖旧 MRU 结构自动迁移回归。
  - `docs/01.01.uniBase-4AI-集成指南-v1.0.md` 与 `docs/07.01.uniBase-4AI-集成检查清单-v1.0.md`：删除重复 DDL/删表 SQL，统一引用 `04.01` 作为 DB1 Schema 权威来源。
  - `docs/04.01.uniBase-4AI-数据库Schema说明-v1.0.md`：Tier2 数量与可选扩展说明补齐，作为唯一结构定义入口。

#### ARCH-043: 日志表清理 + WebAPI JSON 安全
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P2 (运维)
- **任务**:
  - [x] Logs/LLMCalls/ExceptionReports 表添加自动归档或分区策略
  - [x] WebAPI `BadRequest/Unauthorized` 等方法改用 `TJSONObject` 构造（防 JSON 注入）
  - [x] WebAPI 路由匹配缓存正则编译结果
  - [x] PostgreSQL 密码改用 DPAPI 加密存储
- **阶段进展**:
  - `Tools/WebService/UniBase.WebAPI.Core.pas`：`BadRequest/Unauthorized/Forbidden/NotFound/Conflict/InternalError/TooManyRequests` 改为统一 `SendErrorResponse(...)`，通过 `TJSONObject` 生成错误 JSON，消除字符串拼接注入风险。
  - `Tools/WebService/UniBase.WebAPI.Core.pas`：`TRouteDefinition` 在 `CompilePattern` 阶段预编译 `TRegEx` 并在 `Match` 阶段复用，避免每次路由匹配重复构造正则对象。
  - `Tests/Test.WebService.pas`：新增 `Test_Response_ErrorEscapesJSONPayload`，验证包含引号和换行的错误消息仍能生成合法 JSON。
  - `Tests/Test.WebService.pas`：新增 `Test_Router_Match_ExtractsRouteParams`，覆盖参数路由匹配与参数提取回归。
  - `Core/UniBase.Manager.pas`：新增按日自动归档策略（`Logs`/`LLMCalls`/`ExceptionReports`），按 `Maintenance.Retention.*Days` 配置将超期数据迁移到 `*_Archive` 再清理主表。
  - `Tests/Test.UniBase.Manager.pas`：新增 `Test_OperationalRetention_ArchivesOldRowsAcrossCoreTables`，覆盖三张核心表的归档+保留行为。
  - `Persistence/UniBase.DB.Factory.pas`：`DB3.Password` 支持 `credman:` 引用解析，并在 Windows 下将明文密码自动迁移到 Credential Manager。
  - `Tests/Test.UniBase.DB.Factory.pas`：新增 PostgreSQL 密码迁移与引用解析回归测试。

---

### 第二轮审阅统计

| 维度 | P0 | P1 | P2 | 评分 |
|------|-----|-----|-----|------|
| 架构 | 1 | 4 | 1 | 5.5/10 |
| Delphi 代码 | 2 | 2 | 1 | 7.0/10 |
| 安全 | 2 | 3 | 1 | 4.5/10 |
| 文档 | 2 | 2 | 1 | 5.5/10 |
| 数据库 | 1 | 1 | 1 | 7.0/10 |
| **合计** | **8** | **12** | **5** | **5.9/10** |

---

## 文件清理任务 (2026-05-03)

> 清理重复文件、编译产物、过时文档，减少仓库噪音

### CLEANUP-001: 删除重复源码文件
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P0 (代码质量)
- **说明**: 已删除以下重复/冲突文件
- **已删除**:
  - [x] `Core/UniBase.DB.DoQry.pas` — 与 Persistence/ 完全相同
  - [x] `Core/UniBase.DB.ConnectionPool.pas` — Persistence/ 版本更新（含 deprecated + FreeAndNil）
  - [x] `Core/UniBase.Unlock.pas` — 与 Features/ 完全相同
  - [x] `Core/UniBase.AntiTamper.pas` — Features/ 是超集（XOR 死代码已移除）
  - [x] `Core/UniBase.AutoUpdate.pas` — Features/ 是超集
  - [x] `Core/UniBase.Updater.pas` — Features/ 是超集
  - [x] `Features/UniBase.Protection.pas` — Core/ 有 GCM+CBC 完整实现
  - [x] `Core/UniBase.AipexBase.Client.pas` — ThirdParty/ 是 canonical 位置

### CLEANUP-002: 清理编译产物
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P1 (仓库卫生)
- **已删除**:
  - [x] Core/ 下 24 个 .dcu 文件
  - [x] Persistence/ 下 3 个 .dcu 文件
  - [x] Features/ 下 5 个 .dcu 文件
  - [x] 根目录 16 个 .bpl/.dcp 文件
  - [x] .gitignore 已包含排除规则

### CLEANUP-003: 清理过时文档
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P2 (文档)
- **已清理**:
  - [x] 删除 `docs/legacy/` 目录（52 个旧文档）
  - [x] 删除 `docs/V1.0版/` 目录（4 个归档文档）
  - [x] `docs/后端对接/` → `docs/integrations/`
  - [x] `docs/tools/UniPublisher-Spec.md` → `docs/10.05.uniBase-4H-UniPublisher发布工具规范-v1.0.md`

### CLEANUP-004: 清理临时状态文件
- **状态**: ✅ 完成 (2026-05-03)
- **优先级**: P2 (仓库卫生)
- **已删除**:
  - [x] `DOCS_UPDATE.md`, `Phase0~3_Status.md`, `Studio_Status.md`, `better.md`（共 7 个）

### 清理统计

| 类别 | 文件数 | 状态 |
|------|--------|------|
| 重复源码 | 8 | ✅ 已删除冗余副本 |
| 编译产物 | 48 | ✅ 已删除 |
| 过时文档 | 56 | ✅ 已删除或归档 |
| 临时文件 | 7 | ✅ 已删除 |
| 文档修正 | 5 文档 | ✅ 已修正 API 签名/版本号 |
| **合计** | **119 个文件** | ✅ 已完成 |

---

### 待开发任务

### 进行中 (MAINT)

#### MAINT-002: 单元测试覆盖率提升至 95%+
- **状态**: 🟡 进行中
- **优先级**: P0
- **目标**:
  - 单元测试整体覆盖率提升到 95%+，并确保关键安全/网络模块有稳定回归测试。
- **下一步任务**:
  - 输出真实覆盖率报告（按模块分解），定位距离 95% 的缺口并形成补测清单。
  - 在 CI 文档补充数据库集成测试启用说明（`UNIBASE_RUN_DB_INTEGRATION=1` + FireDAC 驱动要求）。
  - 将 Win64 单测纳入默认门禁，Win32 作为兼容性回归（按需执行）。
- **当前测试状态** (2026-05-04):
  - 单元测试: 1442/1445 通过（Ignored: 3，Failed: 0，Errored: 0，Leaked: 0）
  - 集成测试: 9/9 通过（Failed: 0，Errored: 0，Leaked: 0）
  - 全量门禁: `.\Scripts\run_tests.ps1 -Type All -CI`（Win64）已通过
  - 默认平台: Win64（`Scripts/run_tests.ps1` 默认 `-Platform Win64`）
  - 覆盖率阻塞: `.\Scripts\run_tests.ps1 -Type Unit -Platform Win64 -CI -Coverage` 已验证测试通过，但本机缺失 `CodeCoverage.exe`，暂无法产出覆盖率报告。
  - 关键修复:
    - `Core/UniBase.Security.pas` 的 `SecureZeroMemory` 改为运行时解析（`RtlSecureZeroMemory`→`RtlZeroMemory`→`FillChar` 回退），修复 Unit 运行期 `0xC0000139` 启动崩溃。
    - `Scripts/run_tests.ps1`：Unit 路径新增 `Ensure-SqliteDll`，并补充 x64 候选 `bin\windows\lldb\sqlite3.dll`，解决 Win64 单测加载 32 位 sqlite3 失败。
    - `Tests/Test.UniBase.Resilience.pas`：`Test_Execute_RejectedWhenOpen` 异常断言对齐为 `ECircuitBreakerException`。
    - `FormState` 保存窗口坐标已修复工作区/屏幕坐标差异（顶部任务栏场景）
    - `Resilience` 策略组合执行链修复匿名方法残留，FastMM 不再报泄漏
    - `WebAPI/Net` 已完成 Win64 编译兼容与本地集成测试链路修复（TLS 枚举兼容、sqlite3 装载、localhost 安全开关）
    - `Protection/Resilience` 异常断言与实现语义对齐（具体异常类型）
    - `DB.Factory` 已支持 `DB3.Type=SQLite/PG` 双模式（相对路径解析 + SQLite 参数透传）
    - `Scripts/run_tests.ps1` 已将 `.dcu` 输出重定向到 `TestResults/build/dcu/<Platform>`，避免源代码目录污染
    - `Tests/Test.UniBase.FormState.pas` 的测试窗体基准坐标统一为 `Left=100, Top=300`（含工作区边界保护），减少不同桌面布局下的位置漂移。
  - **2026-05-02 批量修复 12 个被注释掉的测试单元**:
    - 修复并启用 `Test.UniBase.Authorization` (无 API 不匹配)
    - 修复并启用 `Test.UniBase.Interfaces` (3 个字段名不匹配: Key→ItemKey, Code→LangCode, Name→LangName)
    - 修复并启用 `Test.UniBase.RateLimiter` (Config 双重释放 + 对象/接口混用)
    - 修复并启用 `Test.UniBase.FeatureFlags` (7 个 API 不匹配: RegisterFlag/DeleteFlag/SaveToFile/LoadFromFile 等)
    - 修复并启用 `Test.UniBase.Metrics` (移除 TESTINSIGHT 守卫 + 9 个 API 不匹配)
    - 修复并启用 `Test.UniBase.Compression` (StringOfChar 参数修复)
    - 修复并启用 `Test.UniBase.Benchmark` (Length 返回 NativeInt 导致 AreEqual 重载歧义)
    - 修复并启用 `Test.UniBase.Diagnose` (Core 添加 Winapi.Windows 引用)
    - 修复并启用 `Test.UniBase.Security` (WillRaise 重载歧义)
    - 修复并启用 `Test.UniBase.Memory` (Core BlockSize 属性返回用户请求大小)
    - 重写并启用 `Test.UniBase.Exception` (原测试与 Core 完全不匹配)
    - 重写并启用 `Test.UniBase.Services.HealthCheck` (原测试与 Core 完全不匹配)
    - 修复 `Test.UniBase.Serialization` 的 JSON 数组反序列化 (Core RTTI 元素类型推导)
  - **2026-05-02 新增性能基准测试**:
    - `Test.UniBase.PerformanceSuite.pas` - 综合性能基准 (内存/磁盘/并发/核心模块, 30+ 测试)
    - `Test.UniBase.LockContention.pas` - 锁竞争对比基准 (CriticalSection vs MREW, 7 测试)
- **备注**:
  - Unit 测试入口 `Tests/UniBaseTests.dpr` 已恢复包含 `Test.UniBase.FormState` / `Test.UniBase.Logging` / `Test.UniBase.License`，并纳入 `Test.UniBase.DB.Factory` / `Test.UniBase.DB.Pool` / `Test.UniBase.DB.Migrations`。
  - Bug 修复记录统一写入 `bugfix.md`。
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
  - [x] 支付接口扩展: PayPal (`ThirdParty/Payment/UniBase.Payment.PayPal.pas`, 2026-05-02)
  - [x] 社交媒体扩展: Weibo/QQ (`ThirdParty/Social/UniBase.Social.Weibo.pas`, `UniBase.Social.QQ.pas`, 2026-05-02)
- **开发指南**:
  - 参考 [06.01.uniBase-4H-ThirdParty扩展开发指南-v1.1.md](docs/06.01.uniBase-4H-ThirdParty扩展开发指南-v1.1.md)
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
