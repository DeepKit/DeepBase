# UniFlow Bug 修复记录

> 记录开发过程中发现和修复的 Bug
>
> 最后更新: 2025-12-05

---

## 已修复 Bug

### BUG-001: Source 目录未持久化
- **发现/修复日期**: 2024-12-05
- **严重程度**: Medium
- **影响范围**: 项目结构
- **问题描述**: 会话中断导致文件系统操作未完成
- **修复方案**: 重新创建目录结构和所有源文件

---

## Delphi 12 兼容性修复

> 共 78 个文件修复，详见 `../bugfix.md` 主文件

### 已修复模块

| 模块 | 修复内容 | 日期 |
|------|----------|------|
| UniBase.IoC.pas | PTypeInfo 本地变量, TValue.AsType<T> | 2025-12-05 |
| UniBase.StateMachine.pas | 本地过程重构为私有方法 | 2025-12-05 |
| UniBase.Diff.pas | TObjectList 改 TList (记录类型) | 2025-12-05 |
| UniBase.FileWatcher.pas | TEvent 替代 TTimer, TTask.Create | 2025-12-05 |
| UniBase.Template.pas | 内联变量声明, 属性访问器 | 2025-12-05 |
| UniBase.CloudSync.pas | HTTP 空请求体, TThread.Queue | 2025-12-05 |

### 常见修复模式

```pascal
// 1. TStringDynArray 缺少单元
uses System.Types;

// 2. 线程同步
TThread.Synchronize(nil, proc) → TThread.Queue(nil, proc)

// 3. 异步任务
TTask.Run(proc) → TTask.Create(proc).Start

// 4. 泛型类中本地过程 (E2570)
procedure TMyClass<T>.Method;
  function LocalFunc: string; // 禁止!
end;
→ 重构为私有类方法

// 5. 记录类型容器
TObjectList<TMyRecord> → TList<TMyRecord>

// 6. 记录属性 Inc
Inc(LRecord.Count) → 
  LCount := LRecord.Count; Inc(LCount); LRecord.Count := LCount;

// 7. 注释格式
{*...*} → (*...*)
```

---

## 已修复 Bug (Delphi 12 兼容性)

### BUG-038: Graph.pas 泛型类中的本地过程 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: High
- **影响范围**: UniBase.Graph.pas
- **问题描述**: TTree.Traverse 等方法中包含本地过程，触发 NI19024 错误
- **修复方案**: 将所有递归遍历重构为迭代式实现 (Stack/Queue)
- **修复内容**:
  - `TTree.Traverse` 使用 TStack/TQueue 迭代
  - `TTree.ToArray` 使用 TStack/TQueue 迭代
  - `TTree.Find` 使用 TStack 迭代
  - `TTree.NodeCount` 使用 TStack 迭代
  - `TGraph.FindCycle` 使用 TStack 迭代 DFS
  - `TGraph.StronglyConnectedComponents` 使用 TStack 迭代 Kosaraju

### BUG-039: Net.pas Indy DNS API 变更 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: High
- **影响范围**: UniBase.Net.pas
- **问题描述**: QueryTimeout/qtCNAME/TCNAMERecord 在新版 Indy 中不存在
- **修复方案**: 使用新版 Indy API
- **修复内容**:
  - `QueryTimeout` → `WaitingTime`
  - `qtCNAME` → `qtName`
  - `TCNAMERecord` → `TCNRecord`

### BUG-040: Serialization.pas 接口泛型方法限制 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: High
- **影响范围**: UniBase.Serialization.pas
- **问题描述**: E2535 Interface methods must not have parameterized methods
- **修复方案**: 接口移除泛型方法，保留在类中实现
- **修复内容**:
  - `ISerializer` 接口只包含非泛型方法
  - `TBaseSerializer` 类保留泛型方法 (Delphi 12 允许类有泛型方法)
  - 添加 `TSerializer` 静态帮助类提供泛型入口

---

## 代码审查 Bug (2025-12-05)

### BUG-041: JSON Unicode 转义处理不完整 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: Medium
- **影响范围**: UniFlow.Performance.JSON.pas
- **问题描述**: `TJSONStreamReader.ReadString` 中 `\uXXXX` 未转换为字符
- **修复方案**: 解析 4 位十六进制并转换为 Char

### BUG-042: TJSONObjectPool 重置器内存泄漏 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: Medium
- **影响范围**: UniFlow.Performance.Pool.pas
- **问题描述**: `RemovePair().Free` 正序删除可能导致索引错误
- **修复方案**: 使用倒序删除并正确释放 Pair

### BUG-043: TWorkStealingQueue Pop 竞态条件 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: High
- **影响范围**: UniFlow.Performance.Concurrent.pas
- **问题描述**: Pop 方法在只有一个元素时逻辑错误
- **修复方案**: 简化 Pop 逻辑，先检查空再弹出

### BUG-044: TPoolStats.HitRate 除零风险 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: Low
- **影响范围**: UniFlow.Performance.Pool.pas
- **问题描述**: `TotalAcquired = 0` 时除零
- **修复方案**: 添加除零保护

---

## 分角色代码审查 Bug (2025-12-05)

### BUG-045: SEC-001 表达式注入风险 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: High (Security)
- **影响范围**: UniFlow.Workflow.Context.pas
- **问题描述**: `TExpressionEvaluator` 未限制可执行表达式，存在注入风险
- **修复方案**: 添加 `TExpressionWhitelist` 白名单类，启用 `SafeMode` 默认验证

### BUG-046: SEC-002 审计日志敏感信息泄露 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: High (Security)
- **影响范围**: UniFlow.Audit.Manager.pas
- **问题描述**: 审计日志可能记录用户输入中的敏感信息
- **修复方案**: 添加 `SanitizeMessage` 方法，默认启用脱敏

### BUG-047: SEC-003 租户隔离可被绕过 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: High (Security)
- **影响范围**: UniFlow.Tenant.pas
- **问题描述**: `IsTenantFlow` 仅检查前缀，可伪造 FlowId
- **修复方案**: 添加 `SignFlowId`/`VerifyFlowId` HMAC 签名验证

### BUG-048: SEC-005 配额检查竞态条件 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: Medium (Security)
- **影响范围**: UniFlow.Tenant.pas
- **问题描述**: `CheckQuota` 和 `IncrementUsage` 非原子操作
- **修复方案**: 添加 `TCriticalSection` 互斥锁，新增 `CheckAndIncrementQuota` 原子方法

### BUG-049: ARCH-002 TTenantEventStore 接口不一致 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: High (Architecture)
- **影响范围**: UniFlow.Tenant.pas
- **问题描述**: `SaveSnapshot` 返回 `procedure` 与 `IEventStore.SaveSnapshot: Boolean` 不匹配
- **修复方案**: 修改返回类型为 `Boolean`

### BUG-050: CODE-001 TStepResult.Output 所有权不明 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: High (Memory)
- **影响范围**: UniFlow.Workflow.Executor.pas
- **问题描述**: 谁负责释放 `Output` 的 `TJSONValue` 不明确
- **修复方案**: 添加 `OwnsOutput` 属性和 `ReleaseOutput` 方法，明确文档化

### BUG-051: CODE-003 缺少 try-finally 资源释放保护 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: High (Memory)
- **影响范围**: UniFlow.Workflow.Executor.pas
- **问题描述**: `ExecuteAction`/`ExecuteCondition` 等缺少异常保护
- **修复方案**: 添加 `try-except` 保护，异常时释放已创建的结果

### BUG-052: CODE-005 子工作流变量污染父上下文 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: Medium
- **影响范围**: UniFlow.Workflow.Executor.pas
- **问题描述**: 子工作流变量可能泄漏到父上下文
- **修复方案**: 子工作流创建独立的 `TWorkflowContext`，仅显式传递输入/输出

### BUG-053: SEC-004 Skill 服务缺少身份认证 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: Medium (Security)
- **影响范围**: UniFlow.Skill.Client.pas
- **问题描述**: `TSkillClient` 与 Skill 服务通信无身份认证，任何人可调用
- **修复方案**: 
  - 新增 `TSkillAuthType` 枚举 (None/ApiKey/Bearer/Basic)
  - `TSkillClientConfig` 添加认证配置 (ApiKey/BearerToken/BasicAuth)
  - `ApplyAuthentication` 方法在请求中添加认证头
  - 401/403 错误不重试直接抛出

### BUG-054: CODE-004 HTTP/重试超时硬编码 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: Low
- **影响范围**: UniFlow.Skill.Client.pas
- **问题描述**: 超时、重试次数、延迟等参数硬编码，无法根据环境调整
- **修复方案**: 
  - `TSkillClientConfig` 新增高级配置 (RetryBackoffMultiplier/MaxRetryDelayMs/EnableRetryOnTimeout/EnableRetryOn5xx)
  - 添加 `LoadFromJSON`/`ToJSON`/`LoadFromFile`/`SaveToFile` 方法
  - `CalculateRetryDelay` 实现指数退避算法
  - `ShouldRetry` 根据配置判断是否重试

### BUG-055: ARCH-004 并行执行为串行实现 ✅
- **发现/修复日期**: 2025-12-06
- **严重程度**: Medium (Architecture)
- **影响范围**: UniFlow.Workflow.Executor.pas
- **问题描述**: `ExecuteParallel` 使用串行实现，无法利用多核性能
- **修复方案**: 使用 `TTask` 为每个分支创建独立上下文并行执行，支持 `FailFast/WaitAll`

### BUG-056: QA-001 缺少核心单元测试 ✅
- **发现/修复日期**: 2025-12-06
- **严重程度**: Critical (QA)
- **影响范围**: Tests
- **问题描述**: 缺少 `Executor/Context/Definition` 核心单元测试
- **修复方案**: 新增 `UniFlow.Tests.Executor.pas`，覆盖基础执行/条件/循环/并行/上下文等场景

### BUG-057: UX-001 错误信息不够友好 ✅
- **发现/修复日期**: 2025-12-06
- **严重程度**: High (UX)
- **影响范围**: 错误展示
- **问题描述**: 错误代码直出，缺少用户友好描述和建议
- **修复方案**: 新增 `UniFlow.Workflow.Errors.pas` 提供友好错误映射、多语言与建议输出

### BUG-058: ARCH-001 缺少依赖注入容器 ✅
- **发现/修复日期**: 2025-12-06
- **严重程度**: Medium (Architecture)
- **影响范围**: Core
- **问题描述**: 组件创建硬编码，缺少统一依赖管理
- **修复方案**: 新增 `UniFlow.DI.pas` 轻量级容器，支持单例/瞬态/工厂/作用域

### BUG-059: QA-002~004 边界/并发/恢复测试 ✅
- **发现/修复日期**: 2025-12-06
- **严重程度**: High (QA)
- **影响范围**: Tests
- **问题描述**: 缺少边界条件、并发场景、错误恢复测试
- **修复方案**: 新增 `TBoundaryConditionTests`/`TConcurrencyTests`/`TErrorRecoveryTests` 测试套件

### BUG-060: ARCH-003 Skill URL 配置硬编码 ✅
- **发现/修复日期**: 2025-12-06
- **严重程度**: Low
- **影响范围**: UniFlow.Skill.Executor.pas
- **问题描述**: Skill 服务 URL 硬编码在构造函数，无法通过配置调整
- **修复方案**: 
  - 新增 `TSkillServiceConfig` 配置类
  - 支持从 JSON/环境变量/配置文件加载
  - 环境变量前缀: `UNIFLOW_SKILL_URL/TIMEOUT/RETRY_COUNT/RETRY_DELAY`
  - `TSkillActionExecutor.CreateDefault` 使用全局默认配置

### BUG-061: CODE-002 ExecuteLoop 对象频繁创建 ✅
- **发现/修复日期**: 2025-12-06
- **严重程度**: Medium
- **影响范围**: UniFlow.Performance.Pool.pas
- **问题描述**: 循环每次迭代都创建新的 `TVariableValue`，GC 压力大
- **修复方案**: 
  - 新增 `TPooledLoopVar` 轻量级循环变量类
  - 新增 `TVariableValuePool` 对象池
  - 支持整数/字符串/JSON 值的池化复用
  - 预热 16 个整数 + 8 个字符串对象

### BUG-062: UX-002 缺少工作流模板 ✅
- **发现/修复日期**: 2025-12-06
- **严重程度**: Low (UX)
- **影响范围**: Templates
- **问题描述**: 新用户缺少参考模板，上手困难
- **修复方案**: 
  - 新建 `Templates/` 目录
  - 添加 3 个常用模板:
    - `01-sequential-approval.json` - 顺序审批流程
    - `02-data-sync.json` - ETL 数据同步
    - `03-ai-chat.json` - AI 智能对话
  - 添加 `README.md` 模板使用指南

### BUG-063: UX-003 缺少调试器可视化 ✅
- **发现/修复日期**: 2025-12-06
- **严重程度**: Medium (UX)
- **影响范围**: Debug
- **问题描述**: 工作流执行时缺少调试工具，难以排查问题
- **修复方案**: 
  - 新增 `UniFlow.Debug.Debugger.pas` (~1350 行)
  - `TWorkflowDebugger` 工作流调试器
  - `TBreakpoint` 断点管理 (普通/条件/监视)
  - `TStackFrame` 调用栈查看
  - `TDebugConsole` 文本调试控制台
  - 支持 Step Over/Into/Out 单步执行
  - 支持变量监视和修改
  - 支持执行历史回溯

### BUG-064: UX-004 缺少性能分析面板 ✅
- **发现/修复日期**: 2025-12-06
- **严重程度**: Low (UX)
- **影响范围**: Debug
- **问题描述**: 缺少性能分析工具，难以识别瓶颈
- **修复方案**: 
  - 新增 `UniFlow.Debug.Profiler.pas` (~1170 行)
  - `TWorkflowProfiler` 性能分析器
  - `TStepProfile` 步骤性能数据
  - `THotspot` 热点检测 (慢步骤/高频/内存/易错)
  - `TProfileReport` 性能报告 (JSON/Text/HTML/CSV)
  - `TProfilerPanel` 文本监控面板
  - 支持实时统计和历史分析

---

## Bug 统计

| 严重程度 | 已修复 | 待修复 | 合计 |
|----------|--------|--------|------|
| Critical | 1 | 0 | 1 |
| High | 87 | 0 | 87 |
| Medium | 12 | 0 | 12 |
| Low | 5 | 0 | 5 |
| **合计** | **105** | **0** | **105** |

---

## 回归测试清单

- [x] Workflow 定义加载测试
- [x] 变量引用解析测试
- [x] 步骤执行流程测试
- [x] 状态持久化测试
- [x] 错误处理测试
- [x] 编辑器单元测试
- [x] CI/CD 自动化测试
