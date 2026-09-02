# DeepBase 框架分模块代码审阅报告

| 项 | 内容 |
|---|---|
| 审阅日期 | 2026-09-02 |
| 审阅角色 | Delphi 高级架构师 / 代码审核师 |
| 审阅方式 | 只读静态审阅 + 源码逐点复核 + 回归测试映射 |
| 审阅范围 | Core / Persistence / Features(部分) / HB / 并发与安全子系统 |
| 基线 | Delphi 13.1 (dcc64)，遵守 `CLAUDE.md` / `.editorconfig` |
| 关联历史报告 | `20260824-Core.md`、`20260824-Persistence.md`、`20260825-Features.md`、`20260827-HB-Core.md` |

---

## 一、执行摘要

DeepBase 是一个分层清晰的 Delphi 框架（Core → Persistence → Features → VCL/FMX），安全与并发意识较强，大量历史缺陷已有回归测试（BUG001–BUG333）和 CR/BIZ 修复注释。本次审阅在既有报告基础上**复核当前 HEAD 工作区**，区分「已修复 / 仍开放 / 新发现」。

### 统计概览（本次复核仍开放项）

| 层级 | P0 | P1 | P2 | P3 |
|------|----|----|----|-----|
| Core — 并发/调度 | 4 | 4 | 6 | 3 |
| Core — 安全/加密 | 2 | 7 | 9 | 4 |
| Core — 插件/授权/反馈 | 1 | 3 | 2 | 2 |
| Persistence / DB | 8 | 12 | 14 | 5 |
| HB 视觉系统 | 0 | 1 | 3 | 2 |
| Features（F1–F2 已审） | 20 | 68+ | 50+ | — |
| **合计（去重后 actionable）** | **~35** | **~95** | **~84** | **~16** |

### 全局 Top 10 优先修复项

| # | 模块 | 问题 | 影响 |
|---|------|------|------|
| 1 | `DeepBase.DB.Pool` Shutdown | 超时后仍 `FPool.Clear`，可销毁 `csInUse` 连接 | 进程崩溃 / 堆损坏 |
| 2 | `DeepBase.DB.Guardian` | 任意 Open 失败即 quarantine + 从备份恢复 | 静默数据回滚 |
| 3 | `DeepBase.Scheduler` | `FRunningITask := nil` 在回调**之前**，与注释矛盾 | Cleanup 并发 UAF |
| 4 | `DeepBase.FileWatcher` | Debounce 任务捕获 raw `TFileWatcherGuard` 非 `IInterface` | 析构后 UAF |
| 5 | `DeepBase.WorkerQueue` | `Stop(False)` / 缩容时 Terminate 后不 WaitFor 即 Clear | 工作线程 UAF |
| 6 | `DeepBase.KeyManager` | GCM 路径 `Length > 29` 严格大于，空明文无法解密 | 密钥管理功能错误 |
| 7 | `DeepBase.SchemaAdapter.WeChat4x` | 指纹前缀 `'4x7f2a9b1c'` 非 hex，无法匹配 SHA256 | 4.x 适配器永不命中 |
| 8 | `DeepBase.Authorization` | `UpdateUser`/`UpdateRole` 只写库不更新 `FUsers`/`FRoles` | RBAC 内存态 stale |
| 9 | `DeepBase.DB.DoQry` | Bind 前 `Trim` + Sweep/Clear 不检查 `InUseCount` | 数据静默变异 / UAF |
| 10 | `DeepBase.PluginManager` | `UnloadBPL` 后本地 `PluginIntf` 仍引用已卸载 BPL | 插件卸载 UAF |

---

## 二、已修复项确认（2026-08 报告 → 当前源码）

以下在 20260824-Core 等报告中为 🔴，**当前源码已修复**，审阅时不再重复列为开放缺陷：

| 原编号 | 位置 | 修复证据 |
|--------|------|----------|
| Core #1 | `FeatureFlags.pas` `FDefaultContext` | 构造函数 `:1547-1549`  eagerly create |
| Core #2 | `Feedback.pas` `StopNotificationPolling` | `:2128-2130` `WaitFor` + `FreeAndNil` |
| Core #3 | `Feedback.pas` `InternalSubmit` double-free | `:1849` 失败不再入队 |
| Core #4 | `Feedback.pas` `ProcessOfflineQueue` 泄漏 | `:1863-1865` Dequeue + Free |
| Core #6 | `i18n.pas` 并发 Add 冲突 | `:562-579` CR-310 TryGetValue 再 Add/Update |
| HB F-01 | `HB.Core` space 令牌键名 | `:707-715` 同时支持 `spaceXS` 与 `xs` |
| BUG-333 | `DB.Pool` RecycleAll | `:1587-1603` 跳过 `csValidating` |
| BUG-330/331 | `SQLiteReader` | schema cache + QuoteIdentifier（回归测试偏浅，见下文） |

---

## 三、分模块审阅详情

### 3.1 Core — 加密与安全 (`DeepBase.Crypto.*`, `KeyManager`, `Security`, `Authorization`, `Protection`, `RateLimiter`)

#### P0

| ID | 文件:行 | 类型 | 描述 |
|----|---------|------|------|
| C-SEC-01 | `KeyManager.pas:1076` | Bug | `(Length(AData) > 1+12+16)` 应为 `>=`；空明文 GCM 包恰 29 字节会走 legacy CBC |
| C-SEC-02 | `KeyManager.pas` 头注释 vs `SaveToFile` | Security | 文档称 DPAPI/Keychain，实际 `~/.DeepBase_keys.json` 明文 JSON（DEK 加密，主结构未保护） |

#### P1

| ID | 文件 | 类型 | 描述 |
|----|------|------|------|
| C-SEC-03 | `Authorization.pas:1092-1101` | Bug | `UpdateUser` 仅 `SaveUserToDatabase`，不更新 `FUsers` 字典 |
| C-SEC-04 | `Authorization.pas:1217-1226` | Bug | `UpdateRole` 同上，`FRoles` stale |
| C-SEC-05 | `Authorization.pas:~1639` | Security | Session token 用 `SameText` 比较，应常量时间 + 大小写敏感 |
| C-SEC-06 | `Authorization.pas:1349-1367` | Concurrency | `GetAllPermissions` 返回 live 指针，与 GetUser 克隆策略不一致 |
| C-SEC-07 | `Crypto.AES.pas:375-412` | Bug/Security | `TAESMode` 暴露 ECB/CFB/OFB/CTR，实现全走 CBC |
| C-SEC-08 | `Protection.pas:657-660` | Bug | IV-only 密文时 `Move` 到空数组可 AV |
| C-SEC-09 | `Security.DPAPI.pas:412-419` | Bug | 空密码 `@PasswordBytes[0]` 不安全 |
| C-SEC-10 | `KeyManager.pas:858-868` | Security | 空 key 列表时错误密码不被检测 |

#### P2（优化/架构）

- **三处 PBKDF2 实现**（`Crypto.PBKDF2` / `Hash.PBKDF2` / `Protection.DeriveAes256KeyPBKDF2`）— 应 SSOT 合并
- **Modulo bias**：`Crypto.Random.RandomString` / `Hash.GeneratePassword` 用 `byte mod N`
- **RateLimiter.CheckAll**：顺序 TryAcquire，前置 limit 失败时已消耗 token
- **Protection vs Crypto**：重复 BCrypt/AES-GCM 栈，长期应收敛到 Crypto facade
- **HardwareFingerprint**：实为 env/用户名亲和，非硬件绑定，API 命名误导

#### P3

- `Crypto.pas` initialization 中冗余 `Randomize`
- `KeyManager.GetActiveKeyForPurpose` 存在不可达分支
- BUG327 回归测试 tamper case 未 assert 解密失败

---

### 3.2 Core — 并发与弹性 (`WorkerQueue`, `Scheduler`, `EventBus`, `ObjectPool`, `FileWatcher`, `Resilience.*`)

#### P0

| ID | 文件:行 | 类型 | 描述 |
|----|---------|------|------|
| C-CON-01 | `Scheduler.pas:1032,1087` | UAF | 注释要求回调后清 `FRunningITask`，实际在锁内提前置 nil；`Cleanup:1217` 可并发释放 |
| C-CON-02 | `FileWatcher.pas:851,870-889` | UAF | Debounce 捕获 `LGuard: TFileWatcherGuard`（raw）；`NotifyChange` 已用 `IInterface` |
| C-CON-03 | `Resilience.Timeout.pas:116-194` | UAF | 超时路径 `ResultLock.Free` 时 worker 可能仍 `Enter` |
| C-CON-04 | `WorkerQueue.pas:2165-2173` | UAF | `Stop(False)` Terminate 后不 WaitFor 即 `FWorkers.Clear` |

#### P1

| ID | 文件 | 类型 | 描述 |
|----|------|------|------|
| C-CON-05 | `ObjectPool.pas:689-792` | Deadlock | 回调在持 `FLock` 时执行 |
| C-CON-06 | `EventBus.pas:952-963` | UAF | `edmMainThread` 的 `TThread.Queue` 未计入 `FAsyncCount`，Destroy 未 drain |
| C-CON-07 | `Scheduler.pas:837-870` | Race | `Start`/`Stop` 无锁，可双 Timer 线程 |
| C-CON-08 | `WorkerQueue.pas:1937-1939` | Semantics | Timeout 标记失败后仍 WaitFor handler，无法释放 worker 槽 |

#### P2

- BUG010 残留：`PrepareRetry` 在锁外设 `jsRetrying`
- `CircuitBreaker`：`Execute` 路径 Open→HalfOpen 可能不通知
- `FileWatcher.ReDeepMoveCallback` 清空全部回调
- `Retry` 默认 `rmwWarn` 在主线程 Sleep
- `Bulkhead` BUG054 已修，非队列路径 count/semaphore 仍 fragile

#### 回归测试状态

| Bug | 状态 |
|-----|------|
| BUG010 | 大部分已修；PrepareRetry 缺口 |
| BUG320 | NotifyChange 已修；Debounce **仍开放** |
| BUG324-326 | 回调隔离已修；Scheduler FRunningITask 时序 **仍开放** |
| BUG325 | 有 timeout 路径，非 abort，仅 detect |

---

### 3.3 Core — 插件 / IoC / MVVM / 其他

#### P0–P1

| ID | 文件 | 描述 |
|----|------|------|
| C-PLG-01 | `PluginManager.pas:791-805` | `Finalize` 后 `UnloadBPL`，本地 `PluginIntf: IDeepBasePlugin` 仍持有已卸载 DLL 的 vtable |
| C-MVVM-01 | `MVVM.pas:503-524` | Wait(5000) 超时后 `FTask := nil`，匿名任务仍可能访问 Self |
| C-VS-01 | `VirtualScroll.pas:450-481` | O(N²) + 持锁范围过大（大数据量性能/死锁风险，20260824 仍开放） |
| C-UI-01 | `UITest.FmxProbe.pas` | HTTP 线程直接触 FMX 树（20260824 仍开放） |
| C-HC-01 | `Services.HealthCheck.pas:106-108` | `CheckResult.Data` 字典泄漏（20260824 仍开放） |

#### 架构观察

- `PluginManager` BIZ2-023/024 已改善锁内回调死锁与依赖检查，**BPL 生命周期顺序**仍是缺口
- `IoC` / `Services.Init` 未见 P0，但 Services 层测试覆盖偏薄

---

### 3.4 Persistence / DB 层

> 详细清单见 `20260824-Persistence.md`（~106 项）；以下为**当前仍开放**高优先级摘要。

#### P0 — Critical

| ID | 模块 | 描述 |
|----|------|------|
| P-DB-01 | `DB.Pool.Shutdown:1085-1092` | Drain 超时后仍 Clear 全部连接，含 csInUse |
| P-DB-02 | `DB.Guardian:398-409` | Open 失败一律 quarantine，busy/locked 误当 corrupt |
| P-DB-03 | `DB.DoQry:853-872` | Bind 前 Trim，静默去掉首尾空格 |
| P-DB-04 | `DB.DoQry:1817-1829` | Sweep/Clear 不检查 InUseCount |
| P-DB-05 | `DB.ConnectionPool.Destroy:204-216` | 无 drain 即 Free pool |
| P-DB-06 | `DB.StatusMachine:372+` | `GetTableDef` 返回 owned Def，无锁并发 Register |
| P-DB-07 | `IntentClarification.Storage:346-356` | `StrToFloatDef` 受 locale 影响 |
| P-DB-08 | `SchemaAdapter.WeChat4x:79` | 指纹前缀非 hex，BUG-332 **未完整修复** |

#### P1 — High（节选）

- Pool：`Release` 总是 csIdle（Invalidate 被复活）、无双 Release 防护、Warmup 已 DATA2-058 但 TryGetConnection 仍锁内 Create
- DoQry：`INFO` → `llDebug` 导致 SQL+参数泄露；`InsertReturningId` 用 AsInteger
- JobQueue：`DequeueSQLite` DEFERRED vs Migrations IMMEDIATE 不一致 → BUSY 死锁
- ORM：`ToList`/`MapRowToEntity` 异常路径泄漏；SQLite `OFFSET` 无 LIMIT
- Authorization FireDAC：`INSERT OR IGNORE` 无 PG 分支

#### 测试覆盖缺口

- BUG330/331 回归**未调用**生产路径 `OpenReadOnly` / `SafeQuery`
- BUG332 测试只验 Validate 长度，不验真实 SHA256 前缀匹配

---

### 3.5 HB 视觉系统（Core Types + VCL/FMX）

> 20260827-HB-Core 静态审计 + 20260830 最终验证（52/52 HB fixture PASS）

#### 仍开放 / 新发现

| ID | 严重度 | 描述 |
|----|--------|------|
| HB-01 | P1 | 部分 Types 单元 uses 冗余（F-14），编译时间与耦合度偏高 |
| HB-02 | P2 | JSON 令牌解析缺少「未消费键」诊断，同类静默失效难发现 |
| HB-03 | P2 | FMX/VCL 双实现需保持 token 解析与 Palettes 同步（Choice.Types 新增后需核对 dpk） |

#### 已验证通过（20260830）

- VCL Cards MouseDown 坐标重算
- Controls ProgressRing/Skeleton 定时器 60ms
- space 令牌键名兼容（Core 已 dual-key）

---

### 3.6 Features 功能层（130 单元，已完成 F1+F2 = 38 单元）

> 完整条目见 `20260825-Features.md`；F3–F9 **未审**。

#### F1 批次 Top 缺陷（仍开放，未在本次逐行复核）

| ID | 模块 | 描述 |
|----|------|------|
| F1-01 | CloudSync | 远程列表所有权分裂 → double-free + 悬垂指针 |
| F1-02 | CloudBackup | `Move` 复制含 string 的 record → double-free |
| F1-03 | Updater | manifest 签名两路径输入不一致；备份清单 `'*.*'` 字面量 |
| F1-04 | ClipboardGuard | GlobalAlloc 失败未检查 |
| F1-05 | TimeGuard | RFC822 忽略 GMT |
| F1-06 | WindowMonitor | QueryFullProcessImageNameA + PChar 类型错 |
| F1-07 | Net | Execute 异常时 Headers 泄漏 |
| F1-08 | Graph | ReDeepMoveChild + OwnsObjects Remove 释放子节点 |

#### F2 批次 Top 缺陷（Browser，仍开放）

| ID | 模块 | 描述 |
|----|------|------|
| F2-01 | CDP.Adapter | NavigateTo URL 未 JSON 转义 |
| F2-02 | CDP.Adapter | SendCommand 空实现 |
| F2-03 | CDP | WaitForSelector 匿名线程不 WaitFor → UAF |
| F2-04 | Session | 同名不同 GUID 的 IBrowserSession 架构冲突 |
| F2-05 | Recorder | Parameters UAF；AddActionInternal 覆盖 FActions |
| F2-06 | WebView2 | 析构顺序 FCDPCallsLock 过早释放 |

#### 待审模块（优先级建议）

1. F3 Commerce（支付/签名，与 BUG013/014 相关）
2. F4 Desktop + Inference
3. F6–F7 IntentClarification（与 P-DB-07 交叉）
4. F8–F9 Speech

---

### 3.7 其他包（未深度审阅，索引级观察）

| 包 | 单元规模 | 状态 |
|----|----------|------|
| `DeepBaseLLM` | Core.LLM + Features.LLM | Core 组 6 报告 🔴2；需与 Features F5 合并审 |
| `DeepBaseBrowser` | Features.Browser.* | 见 F2 |
| `DeepBaseCommerce` | Features.Commerce.* | 待 F3 |
| `DeepBaseGovernance` | 治理层 | 交接文档标记待审 |
| `DeepAxis` | 外部 SQLite 读取 | BUG330/331/332 交叉 |
| `DeepFlow` | 消息/引擎 | 未纳入本次 |

---

## 四、架构级优化建议（非 Bug，长期）

1. **单一真相源（SSOT）**
   - PBKDF2、AES 信封格式、Upsert SQL 方言分支应各收敛一处
   - Protection / Crypto 双栈应规划 deprecation 路径

2. **生命周期契约文档化**
   - 所有 `GetXxx` 返回克隆 vs live 指针应在 interface 注释统一（Authorization 已分裂）
   - 插件/BPL/接口引用顺序写进 `PluginManager` 模块头

3. **Shutdown 协议**
   - Pool / WorkerQueue / Scheduler / EventBus / FileWatcher 应共享「Stop → Drain → Wait → Free」模式
   - `TDBPoolManagerRuntimeComponent.Shutdown` 与 async worker stop 顺序需在 AppLifecycle 文档索引

4. **回归测试深度**
   - BUG330–332 需集成测试走真实 `OpenReadOnly` / registry resolve
   - Scheduler Cleanup vs in-flight callback 需新回归（BUG326 扩展）
   - KeyManager 空 payload GCM round-trip

5. **Features 审阅续作**
   - 按 `20260825-审查交接文档.md` 优先级 F3→F9
   - Commerce 与 Crypto/SchemaAdapter 交叉验证签名链

6. **性能热点**
   - VirtualScroll 大数据索引结构（跳表/分块）
   - Crypto.Hash PBKDF2 内层 HMAC 密钥块缓存
   - Pool TryGetConnection 锁外创建（对齐 Warmup DATA2-058）

---

## 五、SQL 与安全维度结论

- **SQL 注入**：Core + Persistence 审查范围内，数据库访问经 `IxxxStorage` / 参数化 DoQry，**未发现**直接拼接用户输入的 SQL（20260824 结论仍成立）。
- **凭据存储**：KeyManager 明文 JSON、Security.GetMachineEntropy 弱绑定、DPAPI 空密码路径 — **需产品级威胁模型对齐**。
- **日志泄露**：DoQry INFO→Debug、Guardian/Pool 错误吞没 — 运维侧可见性 vs 安全需平衡。

---

## 六、审阅方法说明

1. 读取历史报告 `CodeReview/20260824-*`、`20260825-*`、`20260827-HB-*`
2. 对 Top 10 开放项逐文件 grep/read 复核当前工作区
3. 并行深审：Crypto/Security、Concurrency、Persistence 三子域
4. 对照 `Tests/Regression/Test.Regression.BUG*.pas` 与 `RegressionTestRegistry.pas`
5. **未运行**全量单测（用户要求只审不改）；HB 20260830 报告引用 52/52 fixture PASS

---

## 七、建议后续动作

| 优先级 | 动作 | 负责建议 |
|--------|------|----------|
| P0 | 修复 Top 10 表中 1–5（Pool/Guardian/Scheduler/FileWatcher/WorkerQueue） | Core + Persistence |
| P0 | KeyManager GCM 边界 + WeChat4x 真实指纹 | Security + Data |
| P1 | Authorization UpdateUser/Role 内存同步 | Core |
| P1 | 补 BUG330–332 集成回归 | Tests |
| P2 | 续 Features F3–F9 审阅 | Features 组 |
| P2 | Governance / DeepFlow 独立审阅 | 架构 |

---

*本报告为只读审阅产物，未修改任何源码。与历史报告并存时，以本报告「已修复项确认」+「仍开放」为准做增量跟踪。*
