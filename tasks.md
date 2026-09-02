# DeepBase 任务清单与审查跟踪

> 本文件只保留**未完成**与**进行中**工作。已完成任务见 `history.md`，
> 逐条 Bug 详情见 `bugfix.md`（BUG-334 ~ BUG-471 / BUG-CR-xxx 编号），完整审查报告见 `CodeReview/20260902-Framework-Audit.md`。
> 状态图例：☐ 未开始 · 🔧 进行中 · ✅ 已完成/已修复（回归通过）· ⏸ 暂缓 · ❌ 不做（注理由）
> 提交规则：Delphi 13.1 (Compiler 37) on Win64，优先采用现代语法，每个 ✅ 必须附 DUnitX 回归并通过编译门禁。

## 当前基线

- 编译器环境: Embarcadero Delphi 13.1 (Florence / Compiler 37.0) on Win64 (`dcc64.exe`)
- 单测基线: 4393 found / 4386 passed / 3 failed（Perception×2 + Timeout PBT；证据 `TestResults/WO-20260902-001-full/`）
- 当前主线: **WO-20260902-001 框架审计 Top10 修复（开发完成 / 待数据解锁；禁止 CLOSE）**
- 审计报告: `CodeReview/20260902-Framework-Audit.md`（~35 P0 / ~95 P1 actionable，Features F3–F9 未审）

---

## 一、🔧 WO-20260902-001 框架审计 Top10 修复

> 工单: `docs/WO-20260902-001-开发甲-框架审计P0修复工单.md` · brief: `docs/brief-WO-20260902-001-开发甲.md`

| FIX | 模块 | 状态 | 回归 |
|-----|------|------|------|
| FIX-1 Pool Shutdown 跳过 csInUse | `Persistence/DeepBase.DB.Pool.pas` | ✅ | BUG-334 |
| FIX-2 Guardian 瞬态 Open 不误 quarantine | `Persistence/DeepBase.DB.Guardian.pas` | ✅ | BUG-335 |
| FIX-3 Scheduler FRunningITask 回调后置 nil | `Core/DeepBase.Scheduler.pas` | ✅ | BUG-326 扩展 |
| FIX-4 FileWatcher Debounce IInterface 捕获 | `Core/DeepBase.FileWatcher.pas` | ✅ | BUG-320 扩展 |
| FIX-5 WorkerQueue Stop 先 WaitFor 再释放 | `Core/DeepBase.WorkerQueue.pas` | ✅ | BUG-336 |
| FIX-6 KeyManager GCM 空明文边界 `>=` | `Core/DeepBase.KeyManager.pas` | ✅ | BUG-327 扩展 |
| FIX-7 WeChat4x 指纹 hex 校验 + 真实前缀 | `Core/DeepBase.SchemaAdapter.WeChat4x.pas` | ⏸ **BLOCKED-DATA-P0-001**（hex 校验已交付，真实 SHA256 待 schema dump） | BUG-332 扩展 |
| FIX-8 Authorization UpdateUser/Role 内存同步 | `Core/DeepBase.Authorization.pas` | ✅ | BUG-337 |
| FIX-9 DoQry Bind 保留原始空格 | `Persistence/DeepBase.DB.DoQry.pas` | ✅ | BUG-338 |
| FIX-10 DoQry Sweep 跳过 InUseCount>0 | `Persistence/DeepBase.DB.DoQry.pas` | ✅ | BUG-339 |
| FIX-11 PluginManager UnloadBPL 顺序 | `Core/DeepBase.PluginManager.pas` | ✅ | BUG-340 |

**交付产物：** `docs/WO-20260902-001-开发甲-框架审计P0修复交付报告.md`

**待闭环（禁止宣告 CLOSE）：**

- [x] 全量单测 + junit XML 证据落 `TestResults/WO-20260902-001-full/`（4386/4393；3 失败=环境债，非本 WO）
- [x] `RegressionTestRegistry.pas` 登记 BUG-334~340，`REGRESSION_TEST_COUNT=31`
- [x] 交付报告已落盘
- [ ] FIX-7 真实 4.x 指纹（依赖 DATA-P0-001 目标机 schema dump）---

## 二、🔧 P0 待环境验证转正（7 条）

| ID | 验证动作 | 涉及 |
|---|---|---|
| CR-002 | POSIX 冒烟：OpenSSL_RandomBytes(16)+PBKDF2 加解密往返 | Core\DeepBase.Crypto.OpenSSL.pas |
| CR-003 | PG 实测出队（语法已修正，需真库） | Persistence\DeepBase.DB.JobQueue.pas |
| CR-005 | 补 >2^53 整数绑定专项用例（编译已过 dcc64） | doQry\src\uDoQryExecutor.pas |
| CR-006/007/012 | 运行时用例（**dcc64 编译验证已过**，Scripts\verify_doqry.ps1） | doQry\uDoQryLegacy.pas |
| CR-014 | PG 实测删除用户/角色事务路径 | Authorization.FireDAC |

## 三、⏸ 环境受限排查

| ID | 内容 |
|---|---|
| CR-606 | Perception 两测试（StaticPair/InjectedBitmap_FlowsThroughFrameDifferGate）在本 VM 确定性失败；代码链路走读无异常，需图形完整会话复跑；同步开启 DPI 感知对照 |
| CR-608 | Test_PreparedPool_ConcurrentSameSql 偶发（AV 一次 / 竞态 Expected0 got1 一次）；排查 DeepBase.DB.DoQry prepared-pool 并发领取路径 |

## 四、🟠 20260902 审计剩余高优（Top10 之外 · 未纳入 WO-001）

### P0 — 仍开放

| ID | 模块 | 描述 |
|----|------|------|
| C-CON-03 | `Resilience.Timeout.pas` | 超时路径 `ResultLock.Free` 时 worker 仍可能 Enter → UAF |
| P-DB-05 | `DB.ConnectionPool.Destroy` | 无 drain 即 Free pool |
| P-DB-06 | `DB.StatusMachine` | `GetTableDef` 返回 owned Def，无锁并发 Register |
| P-DB-07 | `IntentClarification.Storage` | `StrToFloatDef` 受 locale 影响 |
| C-CON-02 | `FileWatcher` NotifyChange | `edmMainThread` 的 EventBus 异步计数/drain 缺口（Debounce 已修，NotifyChange 路径待核） |

### P1 — 节选（完整清单见审计报告 §三）

| ID | 模块 | 描述 |
|----|------|------|
| C-SEC-05 | Authorization | Session token 应用常量时间比较 |
| C-CON-05 | ObjectPool | 回调在持 FLock 时执行 → 死锁风险 |
| C-CON-06 | EventBus | `edmMainThread` Queue 未计入 FAsyncCount |
| C-MVVM-01 | MVVM | Wait 超时后 FTask:=nil，匿名任务仍可能访问 Self |
| P-DB Pool/DoQry | 多项 | Release 复活 Invalidate、INFO→Debug SQL 泄露、JobQueue 事务隔离不一致 |
| HB-01 | HB Types | uses 冗余，编译耦合偏高 |

### Features 待审（F3→F9，20260825 交接文档优先级）

- F3 Commerce（支付/签名，交叉 BUG013/014）
- F4 Desktop + Inference
- F6–F7 IntentClarification
- F8–F9 Speech
- Governance / DeepFlow 独立审阅

## 五、🟡 剩余 CR 子项（按模块）

### Core
- [ ] CR-268 余项：edmAsync handler 异常接入 OnError 统计通道
- [ ] CR-283 余项：序列化默认可见性决策3仅覆盖 JSON 根对象——XML/Binary 嵌套空对象行为待 Owner 追加决策
- [ ] CR-284 余项：Reflection FromString 可诊断化 / DeepClone 真递归 / 列表识别结构化判定
- [ ] CR-286 余项：Template 未闭合标签报错 / 自定义分隔符 / 引号感知切分
- [ ] CR-287 余项：CompareChars 代理对 / Apply 换行保真 / IgnoreBlankLines 实现 / IsBinary 规则统一
- [ ] CR-288 余项：插件加载 psLoading 拒绝 / 门禁回滚 / GetMetadata 泄漏 / 拓扑排序 / 大小写统一
- [ ] CR-289 余项：Finalize 锁内复查 / WhenReady 入锁 / InitializeModules 失败回滚
- [ ] CR-291 余项：Bulkhead 快速路径空等 / 析构排空
- [ ] CR-292 余项：IgnoreIf 守卫生效 / 动作锁外化+重入检测 / FromJSON 白名单
- [ ] CR-293 余项：UpdateUser 合并活体 / token 单临界区+哈希存储 / 审计异步投递
- [ ] CR-295 余项：CheckAll 原子性 / TryExecute 异常保类型
- [ ] CR-299 余项：ISO 偏移量与小数秒支持
- [ ] CR-310 余项：Plural 小数操作数 Invariant 化
- [ ] CR-311 余项：MVVM 错误回调保类型 / 关停悬空 SelfRef
- [ ] CR-313 余项：CSV 公式前缀 / DOCX 属性转义复核
- [ ] CR-317 余项：GBK 乱码注释文件 UTF-8 重写（TestHelper/Constants 等）

### Persistence
- [ ] CR-231 Migrations 数值排序
- [ ] CR-233 EnsureSchemaIfNeeded 原子化
- [ ] CR-235 StatusMachine 乐观守卫+裸指针收敛
- [ ] CR-236 ORM Count 方言 / CreateTable PG 分支
- [ ] CR-240 Logging legacy 回退一次性切换 / 枚举范围钳制

### Tools/Infra
- [ ] 将 doQry 纳入主测试图（引入真 DBClient 或沿用 Tools\DBClientStub 于 CI）
- [ ] Scripts\verify_doqry.ps1 接入 CI 门禁

## 六、🔵 Backlog（低优）

- CR-601 性能族：LRU O(n)、日志每条开关文件、O(n²) 字符串累加、TFDQuery 逐调用创建
- CR-602 安全加固族：取模偏差、迭代上限、HTML/CSV 转义、WM_COPYDATA 校验
- CR-603 API 语义族：cepNone 抛异常、Exists LIMIT 1、ReDeepMoveCallback 更名
- CR-604 卫生族：Schema 空行整理、VER350 订正、CompilerVersion 注释订正
- CR-605 备注：Config 写门禁 4000 已校准；若实现连接级语句缓存可回调 5000
- CR-607 二进制流式 API 原生 raw-stream 重载（去 Base64 中转）
- CR-608 见上（与三合并排查）
- 新增: doQry Logger JsonEscape 修复后补运行时断言用例
- 新增: 存量库 App.LogLevel 迁移 UPDATE 已随种子执行，观察一个版本后可移除该语句
- 架构 SSOT：PBKDF2 三处实现合并、Protection/Crypto 双栈 deprecation、Shutdown 协议统一文档化
