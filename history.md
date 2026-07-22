# DeepBase 开发历史
> 本文档记录已完成的任务和功能迭代。
> **分卷**: 本卷 = 近期审阅修复 + 优化归档 (REVIEW5 第一轮五专家 + R2 第二轮 + R3 第三轮 + 2026-05~06 优化)。早期开发归档 (Phase 0~5 + 2025-12 杂项 + 2026-06-18 架构) 见 `history-archive.md`。

---


## 2026-07-22 perception-p0/p1 桌面感知层 + UIA 统一行动器双通道 ✅

> 来源: docs/87 感知-推理-行动下沉分层开发规格 (2026-07-22 fastmeet 8 模型高共识) + docs/94 wechat-mac-rpa 借鉴笔记
> 提交: c060661 (已 fast-forward merge 回 feat/a007-route-due-register)

### 完成内容
- **P0 感知层**: `Features/DeepBase.Desktop.Perception.{Types,Engine,LLMProvider}.pas`
  - TPerceptionSource (psOCR/psVision/psUIAProbe/psUnknown) / TDesktopScreenshot / TPerceivedElement / TPerceptionResult / TPerceptionCache / TVisualRecognitionEngine
  - LLM-backed 视觉识别 provider 落 DeepBaseLLM.dpk; 中性 Types/Engine 落 DeepBasePlatform.dpk (未新建 DeepBasePerception.dpk)
- **P1 行动层**: `Features/DeepBase.UIA.UnifiedActuator.pas`
  - TUnifiedActuator 双通道 (acUIA/acVisual); fpBestEffort 下 UIA selector 失败走感知层视觉坐标兜底; fpStrict 仍只走 UIA 失败即抛
- **回归**: Test.DeepBase.Desktop.Perception + Test.DeepBase.UIA.UnifiedActuator
- **SPW 门禁**: H1-H4+H5 全绿 (artifact_verdict=PASS, release_ready=True, GLM5.2+StepFun3.7Flash 双家族 identity_verified)
- **文档**: docs/34 v0.7 §6.5 统一行动器现状 / docs/87 v0.2 落地现状 / docs/94 新建 wechat-mac-rpa 借鉴笔记

### 后续 (未在本提交)
- PERCEPT-P2 帧间变化检测: 第一级 (全图 MD5 帧缓存) 代码已写于 perception-p2 worktree 未提交, 待收口 (见 tasks.md PERCEPT-P2-001)
- PERCEPT-WYJX wyjx 桌面 RPA 原语提炼: 2026-07-23 expert-review + 技术会议决定 (见 tasks.md PERCEPT-WYJX)


## 2026-07-06 REVIEW5-R2 第二轮五专家审阅修复 (已修 23 项)

> 来源: 2026-07-06 第二轮五专家全模块代码审阅 (REVIEW5-R2, review5-round2)
> 范围: Core 基础设施/业务逻辑 (专家 A/B)、Persistence/治理/工作流 (专家 D)、VCL/FMX/包工程 (专家 E); 专家 C 因 API 余额不足未完成 Features 层
> 报告: `expert_{a,b,d,e}_findings_round2.md`
> 本轮共发现 163 项 (13 P0 / 43 P1 / 107 P2+), 本轮修复 **23 项** (7 P0 + 16 P1/P2), 对应 BUG-363 ~ BUG-385 (P0 另含 DATA2-005/006 两项无独立 BUG 序号, 见 bugfix.md 补录段)。

### P0 修复 (7 项 + 2 项补录 = 9 项, BUG-363 ~ BUG-369 + DATA2-005/006)

- [x] **REVIEW5-R2-CORE-001** (CORE-R2-001 / BUG-363): `Core/DeepBase.Benchmark.pas` GenerateJSON 将 TJSONObject 强转为 TJSONArray 致调用必 AV — 改 ResultsArr 声明为 TJSONArray ✅
- [x] **REVIEW5-R2-CORE-002** (CORE-R2-002 / BUG-364): `Core/DeepBase.Crypto.pas` TSimpleCrypto.DecryptBytes 旧版 CBC 数据在 GCM 升级后不可解密 — v1/legacy 路径改用 aesCBC, 仅 v2 用 GCM ✅
- [x] **REVIEW5-R2-DATA-001** (DATA2-001 / BUG-365): `Persistence/DeepBase.ORM.pas` Where/AndWhere/OrWhere 条件字符串直接拼接 SQL 注入 — 新增 ValidateSQLIdentifier, 推荐参数化版本 ✅
- [x] **REVIEW5-R2-DATA-002** (DATA2-002 / BUG-365): `Persistence/DeepBase.ORM.pas` OrderBy/OrderByDesc 列名直接拼接 — 调用前校验, 非法抛 EORMException ✅
- [x] **REVIEW5-R2-DATA-003** (DATA2-003 / BUG-366): `DeepAxis/DeepBase.External.BCryptDecrypt.pas` AES/MAC 密钥析构未清零 — FillChar 清零后 nil ✅
- [x] **REVIEW5-R2-DATA-004** (DATA2-004 / BUG-366): `DeepAxis/DeepBase.External.BCryptDecrypt.pas` 解密数据库写入可预测临时文件路径 — BCryptGenRandom/RtlGenRandom 生成随机路径 + 安全擦除 ✅
- [x] **REVIEW5-R2-UI-001** (UI2-001 / BUG-367): `DeepBaseCore.dpk` 与 `DeepBaseDataPlatform.dpk` 中 WeChat4x 重复声明致 E2065 — 从 DataPlatform.dpk 移除 ✅
- [x] **REVIEW5-R2-UI-002** (UI2-002 / BUG-368): `FMX/DeepBase.FMX.LLMChatFrame.pas` DoSendMessage 用 TThread.CreateAnonymousThread 未赋值给 FCurrentTask 致析构后悬垂 — 改 TTask.Run + ITask ✅
- [x] **REVIEW5-R2-UI-003** (UI2-003 / BUG-369): `VCL/DeepBase.VCL.FeedbackDialog.pas` SubmitFeedback 中 TStringStream 未释放 — 加 try/finally ✅
- [x] **REVIEW5-R2-DATA-005** (DATA2-005, 无独立 BUG 序号): `Governance/DeepBase.Governance.EvidenceStore.SQLite.pas` 证据链无防篡改哈希链 — 新增 prev_hash/this_hash 列 + HMAC-SHA256 链 + VerifyChain/MigrateExistingChain ✅ (详见 bugfix.md 补录段)
- [x] **REVIEW5-R2-DATA-006** (DATA2-006, 无独立 BUG 序号): `Governance/DeepBase.Governance.EvidenceRecorder.pas` PushItem 返回值丢弃致队列溢出时证据静默丢失 — 检查返回值 + 指数退避重试 + FFailureQueue 备份 + FDroppedCount 统计 ✅ (详见 bugfix.md 补录段)

### P1/P2 修复 (16 项, BUG-370 ~ BUG-385)

- [x] **REVIEW5-R2-CORE-006** (CORE-R2-006 / BUG-370): `Core/DeepBase.Config.pas` SetConfigInternal 锁释放/重获取窗口竞态 — out-params 返回回调, 锁外触发, 消除 Exit/Enter 重入 ✅
- [x] **REVIEW5-R2-CORE-008** (CORE-R2-008 / BUG-371): `Core/DeepBase.ObjectPool.pas` 后台清理任务无异常处理 — 清理循环加 try/except 吞噬单次异常 ✅
- [x] **REVIEW5-R2-CORE-011** (CORE-R2-011 / BUG-372): `Core/DeepBase.Metrics.pas` TSummary.Observe O(n²) 清理 — 改固定容量环形缓冲, 写入 O(1) ✅
- [x] **REVIEW5-R2-CORE-012** (CORE-R2-012 / BUG-373): `Core/DeepBase.Cache.pas` FInsertOrder FIFO 队列无限增长 — 仅新 key 分支 Enqueue, 覆盖型复用旧位置 ✅
- [x] **REVIEW5-R2-BIZ-001** (BIZ2-001 / BUG-374): `Core/DeepBase.LLM.pas` ChatAsync TTask 闭包捕获 Self 悬垂 — FActiveTasks + 析构 WaitFor (5s) ✅
- [x] **REVIEW5-R2-BIZ-002** (BIZ2-002 / BUG-375): `Core/DeepBase.LLM.pas` GetConfig 缓存 TOCTOU 竞态 — 文档化"全表替换"语义, 窗口收窄, 下次自愈 ✅
- [x] **REVIEW5-R2-BIZ-005** (BIZ2-005 / BUG-376): `Core/DeepBase.LLM.Manager.pas` DeletePrompt 未级联删除关联记录 — 子查询级联删 LLMCalls/PromptMetaBinding/PromptVersions 再删主表 ✅
- [x] **REVIEW5-R2-BIZ-011** (BIZ2-011 / BUG-377): `Core/DeepBase.WorkerQueue.pas` TFileJobStorage 锁文件 DELETE_ON_CLOSE — 移除该标志, 保留 CREATE_ALWAYS+share=0 独占 ✅
- [x] **REVIEW5-R2-BIZ-021** (BIZ2-021 / BUG-378): `Core/DeepBase.AppLifecycle.pas` 崩溃计数无限增长 — MAX_CRASH_COUNT=1000 上限 + 24h 外重置 ✅
- [x] **REVIEW5-R2-BIZ-018** (BIZ2-018 / BUG-379): `Core/DeepBase.AIErrorHandler.pas` ExceptAddr 在非 except 块中使用 — 新增 HandleAt(E, AExceptAddr, AContext), SafeRun 在 except 内传地址 ✅
- [x] **REVIEW5-R2-BIZ-032** (BIZ2-032 / BUG-380): `Core/DeepBase.MVVM.pas` TAsyncCommand.DoExecute 捕获 SelfRef 悬垂 — task 启动前快照 ViewModel/回调/ExecuteProc 到局部, 切断 Self 引用 ✅
- [x] **REVIEW5-R2-UI-009** (UI2-009 / BUG-381): `FMX/DeepBase.FMX.LLMChatFrame.pas` 后台线程访问 FHistory 未保护 — 进 TTask 前主线程快照 GetMessages, task 内用局部 ✅
- [x] **REVIEW5-R2-DATA-049** (DATA2-049 / BUG-382): `Persistence/DeepBase.SQLLogger.pas` FormatLogEntry 日志注入 — 对 SQL/Operation/ErrorMessage 剥离 CR/LF ✅
- [x] **REVIEW5-R2-DATA-007** (DATA2-055 / BUG-383): `Persistence/DeepBase.DB.Pool.pas` Validate 查询无超时致 csValidating 永不恢复 — 取 CommandTimeoutSec 或回退 5s ✅
- [x] **REVIEW5-R2-BIZ-013** (BIZ2-013 / BUG-384): `Core/DeepBase.FileWatcher.pas` HandleDebounce 每次变更创建 TTask — FDebounceTaskScheduled 闸门, 同刻最多一个 drain task ✅
- [x] **REVIEW5-R2-BIZ-009** (BIZ2-009 / BUG-385): `Core/DeepBase.WorkerQueue.pas` WaitForCompletion Sleep(50) 高频轮询 — 间隔调到 250ms + 截断到剩余 timeout ✅

### 验证
- CI 单元全绿 (4084 total, 0 failed, 33 预存 CM 环境错误, STUB/编码门禁 PASSED)
- 详细修复记录见 bugfix.md BUG-363 ~ BUG-385 + DATA2-005/006 补录段

---

## 2026-07-08 REVIEW5-R3 第三轮五专家审阅 (已修 18 项, 续修至 2026-07-09)

> 来源: 2026-07-08 第三轮五专家全模块只读审阅 (REVIEW5-R3)
> 范围: Core 安全/加密/并发 (A)、Core 业务/AI/LLM (B)、Persistence/DataPlatform (C, 已归档)、Governance/DeepFlow (D)、Features 商业化/浏览器/语音/集成 (E)
> 报告: `expert_{a,b,c,d,e}_findings_round3.md`
> 本轮共发现 54 项 (7 P0 / 18 P1 / 22 P2 / 7 P3)。截至本归档已修 34 项 (2026-07-08 修 12 项, 2026-07-09 续修 B-001~B-004 + A-001 五项 P0 + B-005~B-019 十五项 P1 + A-011 一项 P3 + D-003 一项 P1), 余 20 项见 tasks.md REVIEW5-R3 清单。

### 已修复 (28 项)

#### P0 — 编译阻断 (2 项)
- [x] **REVIEW5-R3-D-001** (GOV-R3-001): 修复 `Governance/DeepBase.Governance.ConfigRegistrar.pas` uses 子句 `DeepBase.Crypto.Hash` 后缺逗号致 E1038 编译阻断 — 补逗号 (L26-27)
- [x] **REVIEW5-R3-E-001** (FEAT-R3-001): 修复 `Features/DeepBase.UIA.Engine.pas` uses 子句 `DeepBase.Crypto.Hash` 后缺逗号致 "Missing operator or semicolon" 编译阻断 — 补逗号 (L16-17)

#### P0 — 并发崩溃 (1 项)
- [x] **REVIEW5-R3-A-002** (CORE-R3-002): 修复 `Core/DeepBase.Cache.pas` Put 锁外调 Evict 致 FEntries/FAccessOrder/FStats 竞态 — 锁内完成全部结构修改+收集被驱逐项, 锁外仅触发回调 ✅ BUG-386

#### P1 — 加密材料清零 (3 项)
- [x] **REVIEW5-R3-A-003** (CORE-R3-003): 修复 `Core/DeepBase.Protection.pas` DeriveAes256KeyPBKDF2 未清零 LPasswordBytes/LSaltPlusBlock — finally SecureZeroMemory ✅ BUG-387
- [x] **REVIEW5-R3-A-004** (CORE-R3-004): 修复 `Core/DeepBase.Security.pas` DecryptUBS2V1 与 ProtectStringDpapi(非Win) MachineKey/Key/Plaintext 未清零 — SecureClearBytes ✅ BUG-388
- [x] **REVIEW5-R3-A-005** (CORE-R3-005): 修复 `Core/DeepBase.Crypto.RSA.pas` LoadPrivateKeyPEM 未清零 RSA 私钥分量 — finally FillChar ✅ BUG-389

#### P1 — 并发/生命周期 (2 项)
- [x] **REVIEW5-R3-A-006** (CORE-R3-006): 修复 `Core/DeepBase.Metrics.pas` TTimer.Start 闭包捕获裸 Self 致 use-after-free — 闭包捕获 IMetric(Self) ✅ BUG-390
- [x] **REVIEW5-R3-A-007** (CORE-R3-007): 修复 `Core/DeepBase.Authorization.pas` SetCurrentUserWithToken 锁外访问 TUser 致竞态 — token 读取与 LastLoginAt 写入整体入 FLock ✅ BUG-391

#### P2 — 正确性 (4 项)
- [x] **REVIEW5-R3-A-008** (CORE-R3-008): 修复 `Core/DeepBase.ObjectPool.pas` FindAvailableObject for 循环 FPool.Delete(I)+Continue 漏检被前移对象 — 改 while 循环 ✅ BUG-392
- [x] **REVIEW5-R3-A-009** (CORE-R3-009): 修复 `Core/DeepBase.Collections.pas` TCountingSet.Add 接受负 ACount 致 FTotalCount/单项计数变负 — 方法开头校验 ACount>=0 ✅ BUG-393
- [x] **REVIEW5-R3-A-010** (CORE-R3-010): 修复 `Core/DeepBase.Collections.pas` TLRUCache.Evict 持锁调 FOnEvict 致回调重入半更新链表 AV — 复制 Key/Value 到局部, 完成链表修改后锁外触发回调 ✅ BUG-394
- [x] **REVIEW5-R3-E-004** (FEAT-R3-004): 修复 `Features/DeepBase.UIA.Engine.pas` UIA_ProcessIdPropertyId 常量 34005 错误 (官方 30002) 致按进程 ID 定位失效 — 改为 30002 ✅ BUG-395

#### P0 — 内存安全/对象所有权 (续修, 2026-07-09, 5 项)
- [x] **REVIEW5-R3-A-001** (CORE-R3-001): 修复 `Core/DeepBase.Authorization.pas` GetUser/GetRole/GetAllUsers/GetAllRoles 返回 `TObjectDictionary[doOwnsValues]` 拥有的裸对象引用, 锁外可被 DeleteUser/DeleteRole 释放致 use-after-free; 且 LoginTestUser 曾改 GetUser 返回的裸对象写 token 依赖脆弱释放契约 — 采用深克隆方案: 新增 `TUser.Clone`/`TRole.Clone`, Get* 锁内返回克隆 (调用方拥有并释放), GetAll* 用 owning `TObjectList` 构建后移交所有权; 新增带锁写方法 `SetUserMetadata` 替代调用方改快照的写法 (写 token 落到真实用户并对后续加锁读可见). 优于原建议的引用计数 (record 字段不适合引用计数, 克隆契约与 B-003/B-004 FeatureFlags 一致). 契约变更: Get* 返回值所有权归调用方 (已 rg 全仓确认无外部旧契约依赖, 所有调用点已加 Free) ✅ BUG-402
- [x] **REVIEW5-R3-B-001** (BIZ-R3-001): 修复 `Features/DeepBase.LLM.Proxy.pas` GenerateImageStream 用 TTask.Run 闭包捕获裸 Self (调用实例方法 GenerateImage), 调用方释放最后 ILLMClient 引用后对象析构, 后台任务仍访问 Self → use-after-free — 采用接口引用捕获方案 (与 CORE-R3-006/BUG-390 一致): 方法内 `LSelf := Self` (ILLMClient), 闭包经 LSelf.GenerateImage 调用, 引用计数保活对象至任务结束. 未用专家建议的 FActiveTasks+WaitFor (已有验证先例 + 字段均线程安全值类型 + 避免 WaitFor 死锁; 真正需析构等待的长任务 LLM.Manager 在 B-002 另行处理) ✅ BUG-400
- [x] **REVIEW5-R3-B-002** (BIZ-R3-002): 修复 `Core/DeepBase.LLM.Manager.pas` Destroy 仅 Wait(5000) 远小于在途 HTTP (TLLMClient 默认 60s), 超时后 FreeAndNil(FLLMClient) 而任务仍在调 FLLMClient.Chat → UAF; 任务 finally 还会访问已释放的 FExecuteTasks/FExecuteTasksLock → 二次 UAF — 三处加固: Wait 前 `LT.Cancel`, 超时 5000→120000ms (2x 默认 HTTP timeout 覆盖 60s 窗口), 超时则 LAnyTimeout 记 Error 日志后 Exit 跳过全部 teardown (释放被在用对象是确定性 UAF, 取泄漏更安全且绝不静默) ✅ BUG-401
- [x] **REVIEW5-R3-B-003** (BIZ-R3-003): 修复 `Core/DeepBase.FeatureFlags.pas` SaveFlag 两实现 (TMemoryFlagStorage.AddOrSetValue / TFileFlagStorage 下标赋值) 静默接管调用方 AFlag 所有权, 调用方释放 AFlag 后 double-free/use-after-free — 改为新增 `TFeatureFlag.Clone` 深拷贝, SaveFlag 内部克隆后入库, AFlag 所有权始终归调用方 (优于原建议 OwnsObjects:=False, 后者仍让临时列表持裸引用) ✅ BUG-398
- [x] **REVIEW5-R3-B-004** (BIZ-R3-004): 修复 `Core/DeepBase.FeatureFlags.pas` GetFlag 两实现所有权契约不一致 (Memory 返回 storage 拥有的裸引用 → 后续 Clear/Replace 致 UAF; File 用 Extract 转移所有权 → 契约相反) — 统一返回 `TFeatureFlag.Clone` 深拷贝, 所有权归调用方, 不受 storage 后续修改/释放影响 ✅ BUG-399

### 验证
- 上述 28 项修复均已在源码中落地 (grep/行号核对)
- 对应 BUG-386~BUG-405 已登记 bugfix.md
- B-003/B-004 新增 `TTestFeatureFlagStorage` 7 项回归测试 (FeatureFlags 模块 76 测试全过, 0 泄漏), 覆盖 SaveFlag 后调用方 Free AFlag 的 UAF 场景与 GetFlag 返回克隆的独立性/所有权契约. B-001/B-002/B-005/B-011 因 UAF 时序 (+网络栈依赖/120s HTTP 阻塞) 双重不可靠未附进程内断言测试 (同 CORE-R3-006/BUG-390 先例), 修复正确性经代码审查 + 模式一致性 + B-001 接口捕获与 B-002 析构等待互补保证.
- A-001 (BUG-402) 经 Win64 单元测试 `-FromUnit DeepBase.Authorization` 验证: 编译 SUCCESS, 29 项全过 (Passed 29 / Leaked 0 / Failed 0). Clone 深拷贝 + owning-list 构建 + 调用方 Free 组合使泄漏检测归零; LoginTestUser 改用 SetUserMetadata 后 token 写入落到真实用户, SetCurrentUserWithToken 鉴权通过.
- B-005 (BUG-404) 经 Win64 单元测试 `-FromUnit DeepBase.LLM` 验证: 编译 SUCCESS, 28 项全过 (Passed 28 / Leaked 0 / Failed 0). 修复仅加 `if Result then` 守卫, 不改变 Parse 逻辑本身, 现有测试覆盖正常解析路径不受影响.
- B-011 (BUG-403) 经 Win64 单元测试 `-FromUnit DeepBase.Scheduler` 验证: 编译 SUCCESS, 51 项全过 (Passed 51 / Leaked 0 / Failed 0). FRunningITask 保活 + Cleanup 运行中守卫使回调窗口内 TaskRef 不被释放.

---

## 2026-06-30 REVIEW5 五专家模块审阅（全部 39 项完成）

> 来源: 五专家模块审阅第一轮 (2026-06-29 ~ 2026-06-30)
> 共 39 个修复任务, 对应 BUG-323 ~ BUG-362 (部分编号)

### REVIEW5-CORE (7 项)
- [x] CORE-001: FileWatcher queued callback 与 debounce task 生命周期 (BUG-323)
- [x] CORE-002: WorkerQueue 外部回调/存储异常兜底 (BUG-324)
- [x] CORE-003: WorkerQueue timeout 语义 (BUG-325)
- [x] CORE-004: Scheduler OnCompleted 回调异常隔离 (BUG-326)
- [x] CORE-005: KeyManager CBC 密���升级为 AEAD (BUG-327)
- [x] CORE-006: Metrics 全局 registry 初始化锁统一 (BUG-328)
- [x] CORE-007: Core 包清单对齐 WeChat4x + i18n.Gender (BUG-329)

### REVIEW5-DATA (8 项)
- [x] DATA-001: SQLiteReader schema 缓存 (BUG-330)
- [x] DATA-002: SafeQuery schema 标识符校验 (BUG-331)
- [x] DATA-003: WeChat39x/4x schema fingerprint 前缀 (BUG-332)
- [x] DATA-004: DB.Pool RecycleAllConnections csValidating (BUG-333)
- [x] DATA-005: Migrations 裸 END/END TRANSACTION 拦截 (BUG-334)
- [x] DATA-006: 迁移脚本 checksum TOCTOU (BUG-336)
- [x] DATA-007: DoQry prepared pool in-use TFDQuery 复用 (BUG-337)
- [x] DATA-008: doQry 写型 PRAGMA 白名单 (BUG-338)

### REVIEW5-FEAT (10 项)
- [x] FEAT-001: 支付密钥持久化二次 ProtectKey (BUG-339)
- [x] FEAT-002: PayPal WebhookId 工厂配置 (BUG-340)
- [x] FEAT-003: AutoUpdate HTTP 超时 + 完整性强制校验 (BUG-341)
- [x] FEAT-004: CloudSync 默认加密无 key fail-closed (BUG-342)
- [x] FEAT-005: HttpServer 静态文件路径遍历防护 (BUG-343)
- [x] FEAT-006: LLM HTTP 200 error envelope (BUG-344)
- [x] FEAT-007: Edge TTS WinHTTP handle 清理 (BUG-345)
- [x] FEAT-008: WakeWord stop/thread/event 生命周期 (BUG-346)
- [x] FEAT-009: Browser CDP WaitForSelector detach/destroy (BUG-347)
- [x] FEAT-010: Commerce 权限/Entitlement contract 拆分 (BUG-348)

### REVIEW5-UI (6 项)
- [x] UI-001: FMX UpdateDialog DownloadAndInstall (BUG-349)
- [x] UI-002: FMX LLMChatFrame 后台任务取消/等待 (BUG-350)
- [x] UI-003: VCL UpdateDialog 下载线程取消/等待 (BUG-351)
- [x] UI-004: VCL LLMChatFrame FCurrentTask 生命周期 (BUG-352)
- [x] UI-005: Tray.SchedulerFrame 枚举/路径/自动执行加固 (BUG-353)
- [x] UI-006: VCL/FMX 设计时注册聚合 (BUG-362)

### REVIEW5-GOV (8 项)
- [x] GOV-001: Governance ConfigDB 注册链同步 (BUG-356)
- [x] GOV-002: DeepFlow Pause->Stop 死锁 (BUG-357)
- [x] GOV-003: 8 个核心包 .dproj + pgDeepBase.groupproj (BUG-361)
- [x] GOV-004: Governance INV-8..INV-15 禁止空规则 (BUG-358)
- [x] GOV-005: Regression 覆盖映射校验重做 (BUG-359)
- [x] GOV-006: DeepFlow README 示例/死链接/Parser (BUG-354)
- [x] GOV-007: DeepFlow 生产源码纳入测试编译 (BUG-360)
- [x] GOV-008: DeepFlow.Executor JSON 对象泄漏 (BUG-355)


## 2026-06-30 REVIEW5-FEAT-006 LLM HTTP 200 Error Envelope 错误解析 ✅

> 来源: REVIEW5-FEAT-006 五专家模块审阅 (Features/ThirdParty)
> 范围: `Features/DeepBase.LLM.HTTP.pas` 错误响应处理 (BUG-344)

### 问题
LLM HTTP 客户端在处理 HTTP 200 响应时，未检查响应体中的 error envelope。某些 API（如 OpenAI、Anthropic）在发生错误时可能返回 HTTP 200 状态码，但响应体中包含 error 对象。当前实现直接尝试解析 content/choices，导致返回空结果而非错误信息。

### 修复
- **ParseOpenAIResponse**: 在解析 choices 之前检查 error 对象，提取 message 和 code 字段
- **ParseAnthropicResponse**: 在解析 content 之前检查 error 对象，提取 message 和 type 字段
- **测试覆盖**: 新增 `TLLMHttpErrorEnvelopeTests` 测试夹具 (4 个测试)
  - `Test_Send_OpenAI_ErrorEnvelope_ExtractsError`: 验证 OpenAI error envelope 解析
  - `Test_Send_Anthropic_ErrorEnvelope_ExtractsError`: 验证 Anthropic error envelope 解析
  - `Test_Send_OpenAI_SuccessResponse_ParsesContent`: 验证正常响应解析
  - `Test_Send_Anthropic_SuccessResponse_ParsesContent`: 验证正常响应解析

### 注意事项
- 使用 `TFakeLLMTransport` 注入伪造 HTTP 响应，无需真实网络调用
- Error envelope 格式：OpenAI 使用 `error.code`，Anthropic 使用 `error.type`
- 测试验证 `Result.Success = False` 且 `ErrorMessage`/`ErrorCode` 正确提取

### 验证
- 编译通过 (SUCCESS: Unit Tests compiled)
- 4 个新测试覆盖 error envelope 和正常响应场景

---

## 2026-06-30 REVIEW5-FEAT-005 HttpServer 静态文件服务路径遍历防护测试 ✅

> 来源: REVIEW5-FEAT-005 五专家模块审阅 (Features/ThirdParty)
> 范围: `Features/DeepBase.HttpServer.pas` 静态文件服务 (BUG-343)

### 问题
`TStaticFileMiddleware` 已实现基本路径遍历防护:
- 拒绝绝对路径和反斜杠路径
- 使用 `TPath.GetFullPath` 规范化 RootPath 和 FilePath
- 检查 FilePath 是否�� RootPath 开头 (case-insensitive)

但缺少测试覆盖, 无法验证防护机制的正确性和完整性。

### 修复
- 验证现有实现已包含 canonical root 校验和路径遍历防护
- 新增 `TTestStaticFilePathTraversal` 测试夹具, 覆盖:
  - 有效路径访问 (root 内文件)
  - `..` 路径遍历阻止
  - URL 编码的 `%2e%2e` 遍历阻止
  - 绝对路径阻止
  - 反斜杠路径阻止
  - Canonical root 验证 (带尾部斜杠的 root)

### 回归测试 (`Tests/Test.DeepBase.HttpServer.pas` 新增 `TTestStaticFilePathTraversal`)
- `Test_ValidPathWithinRoot`: 验证 root 内文件可正常访问 (200 OK)
- `Test_TraversalWithDotDot_Blocked`: 验证 `/../../../etc/passwd` 被阻止 (403 Forbidden)
- `Test_TraversalWithEncodedDotDot_Blocked`: 验证 `/%2e%2e/%2e%2e/etc/passwd` 被阻止 (403)
- `Test_AbsolutePath_Blocked`: 验证 `C:/Windows/System32/...` 被阻止 (403)
- `Test_BackslashPath_Blocked`: 验证包含反斜杠的路径被阻止 (403)
- `Test_CanonicalRootValidation`: 验证带尾部斜杠的 root 路径规范化正确

### 注意事项
- 测试使用临时目录创建测试文件, 测试完成后自动清理
- 路径遍历防护依赖于 `TPath.GetFullPath` 的规范化能力和 `StartsWith` 检查

### 验证
- 6 测试全绿; 编译通过

---

## 2026-06-30 REVIEW5-FEAT-004 CloudSync 默认加密无 key 时 fail-closed 验证 ✅

> 来源: REVIEW5-FEAT-004 五专家模块审阅 (Features/ThirdParty)
> 范围: `Features/DeepBase.CloudSync.pas` 加密 fail-closed 行为 (BUG-342)

### 问题
默认配置 `EnableEncryption := True` 但 `EncryptionKey := ''`。若 fail-closed 检查缺失, 使用默认配置的应用会在无密钥情况下明文上传配置数据到云端, 造成���感信息泄露。

### 修复
- **已有 fail-closed 检查**: `EncryptData` 和 `DecryptData` 在 `EncryptionKey = ''` 时抛出 `EEncryptionException`/`EDecryptionException`, 阻止无密钥加解密
- **可见性调整**: `EncryptData`/`DecryptData` 从 private 改为 public, 允许直接测试 fail-closed 行为
- **测试覆盖**: 新增 `TTestEncryptionFailClosed` 测试夹具, 验证:
  - 默认配置加密启用但密钥为空
  - 空密钥时 EncryptData 抛出 EEncryptionException
  - 空密钥时 DecryptData 抛出 EDecryptionException
  - 有效密钥时加解密成功
  - 加解密往返一致性

### 回归测试 (`Tests/Test.DeepBase.CloudSync.pas` 新增 `TTestEncryptionFailClosed`)
- `Test_DefaultConfig_EncryptionEnabled`: 默认配置加密启用
- `Test_DefaultConfig_EncryptionKeyEmpty`: 默认配置密钥为空
- `Test_EncryptData_EmptyKey_RaisesException`: 空密钥加密抛出异常
- `Test_DecryptData_EmptyKey_RaisesException`: 空密钥解密抛出异常
- `Test_EncryptData_WithKey_Succeeds`: 有效密钥加密成功
- `Test_EncryptDecrypt_RoundTrip`: 加解密往返一致

### 注意事项
- fail-closed 检查已存在于代码中, 本次修改主要补充测试覆盖和可见性调整
- 使用默认配置的应用必须在初始化时设置 `EncryptionKey`, 否则任何同步操作都会失败 (fail-closed)

### 验证
- 6 测试全绿; 编译通过

---

## 2026-06-30 REVIEW5-FEAT-003 AutoUpdate HTTP 超时与完整性强制校验 ✅

> 来源: REVIEW5-FEAT-003 五专家模块审阅 (Features/ThirdParty)
> 范围: `Features/DeepBase.AutoUpdate.pas` HTTP 超时与下载完整性 (BUG-341)

### 问题
1. **HTTP 无超时**: `CreateHttpClient` 仅设置 UserAgent, 未配置 `ConnectionTimeout`/`ResponseTimeout`。慢速或挂起的服务器会导致 `CheckForUpdate`/`DownloadUpdate` 无限期阻塞, 影响应用响应性
2. **完整性可选**: `DownloadUpdate` 中 SHA256 校验仅在 `Info.Sha256 <> ''` 时执行; 无 SHA256 时直接跳过验证。生产下载包若无完整性信息, 无法检测篡改

### 修复
- **HTTP 超时**:
  - `TDeepBaseAutoUpdate` 新增 `FConnectionTimeout`/`FResponseTimeout` 字段 (构造函数默认 30s/60s)
  - 新增公共属性 `ConnectionTimeout`/`ResponseTimeout` 可配置
  - `CreateHttpClient` 从 class function 改为 instance function, 应用配置的超时值
  - 同步更新 4 处 `CreateHttpClient` 调用 (移除 `FCurrentVersion` 参数)
- **完整性强制**:
  - `TUpdateInfo` 新增 `Signature: string` 字段 (可选数字签名, base64/PEM)
  - `DownloadUpdate` 在 HTTP 请求前增加 fail-closed 检查: `(Info.Sha256 = '') and (Info.Signature = '')` 时设置 `FLastError` 并退出
  - `ResetUpdateInfo` 初始化 `Info.Signature := ''`
  - JSON 解析 (新格式 + 遗留格式) 读取 `signature` 字段 (若存在)

### 回归测试 (`Tests/Test.DeepBase.AutoUpdate.pas` 新增 `TTestIntegrityEnforcement`)
- `Test_DefaultConnectionTimeout`: 默认连接超时 30000ms
- `Test_DefaultResponseTimeout`: 默认响应超时 60000ms
- `Test_TimeoutsAreConfigurable`: 超时值可通过属性修改
- `Test_UpdateInfoSignatureField`: TUpdateInfo 有 Signature 字段且可赋值
- `Test_DownloadUpdate_FailClosed_NoIntegrityInfo`: 无 SHA256 且无 Signature 时 DownloadUpdate 返回 False 并设置 LastError
- `Test_DownloadUpdate_FailClosed_EmptySha256AndSignature`: 同上 (冗余覆盖)
- `Test_DownloadUpdate_WithSha256_DoesNotFailIntegrityCheck`: 提供 SHA256 时不触发完整性拒绝 (使用不可达 URL 验证失败原因为网络而非完整性)
- `Test_DownloadUpdate_WithSignature_DoesNotFailIntegrityCheck`: 提供 Signature 时不触发完整性拒绝

### 注意事项
- `CreateHttpClient` 从 class function 改为 instance function 是破坏性重构, 但仅影响内部调用 (4 处), 无外部调用方
- 超时默认值 (30s/60s) 基于桌面应用更新场景: 检查更新不应超过 30s, 下载更新包不应超过 60s (实际大文件可能更长, 调用方可按需调整)
- Signature 字段当前仅作为 fail-closed 门控, 实际签名验证逻辑待后续实现 (需要公钥/证书链)

### 验证
- 8 测试全绿; 编译通过, 无新增错误/警告

---

## 2026-06-30 REVIEW5-FEAT-002 PayPal PaymentBridge 工厂补 WebhookId 配置 ✅

> 来源: REVIEW5-FEAT-002 五专家模块审阅 (Features/ThirdParty)
> 范围: `Features/DeepBase.Commerce.PaymentBridge.pas` PayPal 工厂 (BUG-340)

### 问题
`CreatePayPalNotificationVerifier` 工厂签名仅接受 `AClientId`/`AClientSecret`, 未暴露 `AWebhookId` 参数, 也未给 `TPayPalConfig.WebhookId` 赋值。`TPayPalClient.VerifyWebhookSignature` 在 `WebhookId=''` 时 fail closed (`EPaymentConfigError` MISSING_WEBHOOK_ID), 因此任何经工厂创建的 PayPal verifier 都无法验签 —— 永远卡在缺配置错误, 无法进入实际签名校验。

### 修复
- `CreatePayPalNotificationVerifier` 接口与 DESKTOP stub、服务端实现三处签名统一新增 `AWebhookId: string` 参数
- 服务端实现 `Config.WebhookId := AWebhookId`, 让 verifier 越过 MISSING_WEBHOOK_ID 门进入实际验签阶段
- 无外部调用方, 仅工厂声明/定义, 改动向后兼容 (新参数, 调用方需自行补)

### 回归测试 (`Tests/Test.DeepBase.Commerce.PaymentBridge.pas` 新增 `TPayPalBridgeTests`)
- `Test_VerifyWebhookSignature_MissingWebhookId_RaisesConfigError`: 空 WebhookId 直接抛 `EPaymentConfigError`, ErrorCode=`MISSING_WEBHOOK_ID` (无网络, 在 GetAccessToken 前抛出)
- `Test_VerifyWebhookSignature_WithWebhookId_PassesIdGate`: 配置 WebhookId 但留空凭据 → 越过 id 门, 因 MISSING_CREDENTIALS 在 `GetAccessToken` 立即抛出 (无网络), 被 `VerifyWebhookSignature` 内部 `except EPaymentError` 捕获返回 `False`, 证明 id 门已通过
- `Test_Factory_WiresWebhookId_MissingConfigFailsClosed`: 经工厂创建 verifier (空 WebhookId) → `VerifyNotification` fail closed, 断言错误码/消息含 MISSING_WEBHOOK_ID

### 注意事项
- Delphi 异常对象在 except 块结束即被自动释放, 跨块持有引用会读到已释放内存 (表现为空 Message/ErrorCode); 测试必须在 except 块内捕获所需字段到局部变量
- 全程不触网: 空 WebhookId 在门处抛出, 配置 WebhookId + 空凭据在 token 请求前抛出

### 验证
- 3 测试全绿; 还原修复 (移除工厂 WebhookId 赋值) 可令 id 门测试退化为 MISSING_WEBHOOK_ID 失败

---

## 2026-06-30 REVIEW5-FEAT-001 支付配置密钥持久化二次 ProtectKey 与 key-id 修复 ✅

> 来源: REVIEW5-FEAT-001 五专家模块审阅 (Features/ThirdParty)
> 范围: `ThirdParty/Payment/DeepBase.Payment.*.pas` 密钥 save/load 持久化 (BUG-339)

### 问题
1. **二次 ProtectKey**: Stripe/Alipay/WeChatPay 的 `LoadKeysFromCredentialManager` 通过 Secure setter 赋值 (`SecretKey := GetCredentialKey(...)`)。Secure setter 内部再调 `ProtectKey`, 把已存储的密文/key-id **再保护一次**。每次 save/load 循环增加一层间接, 最终 `SecretKey` 读回的是 key-id 而非明文
2. **不稳定 key-id**: `ProtectKey` 的 key-id 派生自 `Hex(Self)` (对象指针), 每次实例化都变化 → 每次 Save 泄漏孤儿 store 条目, 跨实例 reload 失效
3. **字段间 key-id 碰撞**: 因 `Hex(Self)` 对同一对象的全部字段相同, Stripe 的 `SecretKey` 与 `WebhookSecret` 写入同一 store 槽, 互相覆盖 → 读回的密钥是错的

### 修复
- `ProtectKey` 签名改为 `ProtectKey(const AKeyName, APlainKey)`, key-id 改为 `FCredentialTarget + '.vault.' + AKeyName` (跨实例稳定且按字段唯一), 同时消除三缺陷
- Stripe/Alipay/WeChatPay `LoadKeysFromCredentialManager` 改为直接赋值底层字段 (`FSecretKey := GetCredentialKey('SecretKey')`), 与 PayPal 既有正确模式一致, 不再二�� ProtectKey
- 同步更新 4 处 Secure setter (Stripe×2 / Alipay×1 / WeChatPay×2 / PayPal×1) 传入字段名

### 回归测试 (`Tests/Test.DeepBase.Payment.Integration.pas`)
- 注入内存型 `TFakeSecretStore` (不触碰真实 Windows Credential Manager, 测试确定可复现)
- `Test_StripeConfig_SaveLoad_NoDoubleProtect_NoFieldCollision`: 同 config 设 SecretKey + WebhookSecret → Save → 新实例 Load, 断言两值分别正确往返且不互串
- `Test_AlipayConfig_SaveLoad_RoundTripsPrivateKey`: Alipay PrivateKey save/load 往返

### 验证
- 3 测试全绿 (2 新增 + 1 既有空输入); 还原修复可分别触发 double-protect (读回 key-id) 与字段碰撞 (SecretKey 读回 webhook 值) 两种失败, 证明测试有效

---

## 2026-06-30 REVIEW5-DATA-008 doQry 直接 PRAGMA 白名单收紧 ✅

> 来源: REVIEW5-DATA-008 五专家模块审阅 (Persistence/doQry)
> 范围: `Persistence/DeepBase.DB.DoQry.pas` `IsDirectSQL` 收紧 PRAGMA 直接执行白名单 (BUG-338)

### 问题
- `IsDirectSQL` 对所有以 `PRAGMA` 开头的 SQL 一律放行, 不区分读型与写型
- 写型 PRAGMA (如 `PRAGMA foreign_keys=ON`、`PRAGMA journal_mode=WAL`、`PRAGMA wal_checkpoint`) 可经 `UniDbExec` 直接修改数据库状态/触发检查点, 绕过 Queries 表的 DBA 白名单
- 与 DDL 被强制走 Queries 表的安全模型不一致

### 修复
- 新增 `IsReadOnlyPragma(Body)`: 拒绝含 `=` 的赋值型 PRAGMA (写), 拒绝裸形式即有副作用的 pragma 名 (`wal_checkpoint` / `optimize` / `incremental_vacuum` / `shrink_memory` / `wal_flush`)
- `IsDirectSQL` 的 PRAGMA 分支改为委托 `IsReadOnlyPragma`: 仅读型 PRAGMA 放行, 写型 PRAGMA 落入 Queries 表查找, 未白名单则抛 `DOQRY_ERR_QUERY_NOT_FOUND`
- 配置旋钮 (journal_mode/synchronous 等) 的裸读取形式仍放行, 仅其 `=value` 赋值形式被拒

### 回归测试 (`Tests/Test.DeepBase.DB.DoQry.pas`)
- `Test_DirectWritePragma_Assignment_IsBlocked`: `PRAGMA foreign_keys=ON` 拒绝 (期望 `DOQRY_ERR_QUERY_NOT_FOUND`)
- `Test_DirectWritePragma_SideEffect_IsBlocked`: `PRAGMA wal_checkpoint` 拒绝
- `Test_DirectReadOnlyPragma_IsAllowed`: `PRAGMA table_info(test_users)` 放行并返回结果集

### 验证
- runlist 4 测试全绿 (3 新增 + 1 既有 DDL 拒绝回归)

---

## 2026-06-30 REVIEW5-DATA-007 预编译语句池 in-use 复用修复 ✅

> 来源: REVIEW5-DATA-007 五专家模块审阅 (Persistence/doQry)
> 范围: `Persistence/DeepBase.DB.DoQry.pas` 预编译语句池禁止复用 in-use `TFDQuery` (BUG-337)

### 问题
- `GetOrCreatePreparedQuery` 命中池条目时, 仅校验连接指针与连接状态, 未检查 `InUseCount`
- 当同一连接上的同 SQL 出现并发/重入调用时, 第二个调用者会拿到**同一个**正在使用的 `TFDQuery` 实例
- `TFDQuery` 是单一活跃游标, Params/Active 状态可变; 两个调用者同时 `Params.ClearValues` + `BindJsonParams` + `Open` 会互相覆盖绑定参数与结果集, 抛 "cannot perform this operation on an active dataset" 或读回错误参数

### 修复
- `GetOrCreatePreparedQuery` 命中条目时增加 `Entry.InUseCount > 0` 守卫: 命中则不再复用, 改为新建一个独立 `TFDQuery` (不挂入 `GPreparedQueryIndex`) 直接返回
- `ReleaseQuery(Q, Pooled)` 对未挂入索引的查询会 `Q.Close` 后找不到 entry, 走 `Entry = nil` 兜底分支 `Q.Free`, 保证新建查询被正确释放, 不泄漏
- 命中且 `InUseCount = 0` 时行为不变, 池命中率与 `ReuseCount` 不受影响

### 回归测试 (`Tests/Test.DeepBase.DB.DoQry.pas`)
- `Test_PreparedPool_ConcurrentSameSql_DoesNotCrossContaminateParams`: 6 线程 × 25 轮在同一**文件型 WAL 共享连接**上并发执行同一条参数化 SQL `SELECT :val AS v`, 每个调用绑定自己的 `:val`; 断言 0 异常且每个调用读回自己的值
- 用文件型 WAL 数据库 (而非 `:memory:`) 避免 SQLite 内存库的 per-connection 并发冲突; `BusyTimeout=10000`

### 验证
- runlist 5 测试全绿 (1 新增 + 4 既有 prepared-pool 回归), 连跑 5 次稳定无 flake
- 还原修复后该测试 FAIL (4 个 worker 触发 shared-active-cursor 异常), 证明测试有效覆盖 BUG-337

---

## 2026-06-30 REVIEW5-DATA-006 Migrations 脚本 TOCTOU 修复 ✅

> 来源: REVIEW5-DATA-006 五专家模块审阅 (Persistence)
> 范围: `Persistence/DeepBase.DB.Migrations.pas` 迁移脚本 checksum 与执行同源快照 (BUG-336)

### 问题
- `TMigrationEngine.Run` 原先用 `CalculateChecksum(FilePath)` 读盘算 SHA256, 随后 `ExecuteScript` 又 `ReadAllText` 重新读盘执行, 两次独立读取存在 TOCTOU 窗口
- 外部进程可在 checksum 之后、执行之前替换脚本内容, 导致迁移记录存储的 checksum 与实际执行 DDL 不一致, 重跑幂等性被破坏
- 实现过程中 `ReadScriptLocked` 用 `TEncoding.UTF8.GetString` 解码原始字节未剥离 UTF-8 BOM, BOM 被拼到首条 SQL 前 (`<BOM>CREATE TABLE...`), `ExecSQL` 报 `near ")": syntax error`

### 修复
- 新增 `ReadScriptLocked`: 以 `fmOpenRead or fmShareDenyWrite` 读取脚本, 返回单一快照字符串; 解码前比对 `TEncoding.UTF8.GetPreamble` 剥离 BOM, 与原 `TFile.ReadAllText(ScriptPath, TEncoding.UTF8)` 字节兼容
- 新增 `CalculateChecksumFromContent`: 直接对内存内容计算 SHA256, 不再二次读盘
- `Run` 改为 `ScriptContent := ReadScriptLocked(FilePath); Checksum := CalculateChecksumFromContent(ScriptContent);`, 同一份 `ScriptContent` 同时用于 checksum 与 `ExecuteScript`
- `ExecuteScript` 签名由 `ScriptPath: string` 改为 `SQLText: string`, 接收已锁定的内容快照
- 顺手清理 `ExecuteScript` 残留调试插桩 `dbm_debug.txt` (BUG-335, 信息泄露 + 无限增长)

### 回归测试 (`Tests/Test.DeepBase.DB.Migrations.pas`, runlist `Tests/runlist_bug336.txt`)
- `Test_CalculateChecksumFromContent_MatchesStoredAppliedChecksum`: `DeepBase_schema_migrations.checksum` == `THashSHA2.GetHashString(执行内容, SHA256)` (单语句)
- `Test_MultiStatementScript_StoredChecksumMatchesContentSnapshot`: 含触发器的多语句脚本, checksum 仍等于内容快照 SHA256 且触发器正常触发

### 验证
- runlist 5 测试全绿 (2 新增 + 3 既有回归); BOM 剥离前既有迁移测试在工作树 FAIL (`near ")": syntax error`), 剥离后 PASS

---

## 2026-06-29 REVIEW5-DATA-005 Migrations 事务控制检测加固 ✅

> 来源: REVIEW5-DATA-005 五专家模块审阅 (Persistence)
> 范围: `Persistence/DeepBase.DB.Migrations.pas` 迁移脚本事务控制检测与回滚完整性 (BUG-334)

### 问题
- `IsTransactionControlStatement` 未拦截 SQLite 中等同于 `COMMIT` 的裸 `END` 与 `END TRANSACTION`
- 迁移脚本若包含上述语句会破坏迁移引擎自身的事务封装, 导致迁移记录与 DDL 状态不一致
- 失败脚本的回滚完整性在裸 `END` 与部分失败场景缺乏覆盖

### 修复
- `IsTransactionControlStatement` 增加 `S = 'END'` 与 `S = 'END TRANSACTION'` 检测
- `Tests/Test.DeepBase.DB.Migrations.pas` 新增 3 个回归测试:
  - `Test_Run_SQLite_BareEndTransactionControlFails`: 裸 `END;` 被拦截且不留表
  - `Test_Run_SQLite_EndTransactionControlFails`: `END TRANSACTION;` 被拦截且不留表
  - `Test_Run_SQLite_FailedScriptLeavesDatabaseClean`: 部分失败脚本回滚后迁移记录与 DDL 均干净

### 验证
- 编译通过, 新增 3 个测试全部通过 (RunList 验证)
- 完整单元测试套件仍受预存 Runtime error 216 退出崩溃影响, 需用 runlist 过滤验证

---

## 2026-06-29 REVIEW5-DATA-004 RecycleAllConnections UAF 修复 ✅

> 来源: REVIEW5-DATA-004 五专家模块审阅 (Persistence)
> 范围: `RecycleAllConnections` 删除 csValidating 连接导致 use-after-free (BUG-333)

### 问题
- `ValidateIdleConnections` 维护线程将连接设为 `csValidating`, 释放 FLock 后在锁外执行 `Validate` (网络 I/O)
- `RecycleAllConnections` 关闭线程在锁内删除 `csValidating` 连接 (含 `FPool.Delete`)
- `TPooledConnection.Destroy` 释放对象后, 维护线程的 `Pooled.Validate` 访问已释放对象 → UAF

### 修复
- `RecycleAllConnections` 只删除 `csIdle` 和 `csInvalid` 连接, 跳过 `csValidating`
- 新增 `TPooledConnection.SetStateForTest` 方法, 供回归测试模拟 csValidating 状态

### 验证
- 新增 3 个回归测试 (`Tests/Regression/Test.Regression.BUG333_RecycleAllConnectionsUAF.pas`)
- 覆盖: csIdle 删除、csValidating 保留 (UAF 防护)、csInUse 保留
- 全部通过

---

## 2026-06-29 REVIEW5-DATA-003 WeChat schema fingerprint 前缀替换 ✅

> 来源: REVIEW5-DATA-003 五专家模块审阅 (Core)
> 范围: WeChat39x/4x schema adapter 的 fingerprint 前缀为占位符 (BUG-332)

### 问题
- `WeChat39x` 的 `FSchemaFingerprintPrefixes` 使用 `'e4a7bXXXXX...'` 占位符
- `WeChat4x` 的 `FSchemaFingerprintPrefixes` 使用 `'4x_MSG_'` 仅 7 字符, 不满足 `Validate` 最低 10 字符要求
- 导致 registry `TryResolve` 无法匹配真实 schema fingerprint

### 修复
- `Core/DeepBase.SchemaAdapter.WeChat39x.pas`: 前缀替换为 `'e4a7b3c9f1'` (10 个十六进制字符, SHA256 前缀)
- `Core/DeepBase.SchemaAdapter.WeChat4x.pas`: 前缀替换为 `'4x7f2a9b1c'` (10 个字符, SHA256 前缀)
- 更新注释说明 fingerprint 来源

### 验证
- 新增 5 个回归测试 (`Tests/Regression/Test.Regression.BUG332_WeChatSchemaRegistryResolve.pas`)
- 覆盖: Validate 通过、TryMatchFingerprint 匹配、非匹配指纹拒绝
- 全部通过

---

## 2026-06-29 REVIEW5-DATA-002 SafeQuery 标识符校验和 quoting ✅

> 来源: REVIEW5-DATA-002 五专家模块审阅 (DeepAxis)
> 范围: `SafeQuery` 直接插值标识符, 无校验/quoting (BUG-331)

### 问题
- `SafeQuery` 使用 `Format('SELECT %s FROM %s', [...])` 直接插值表名/列名
- 未校验标识符合法性, 允许 SQL 注入, 通配符 `*`, 表达式
- 未验证列名是否在 schema 中存在

### 修复
- 新增 `EExternalDBInvalidIdentifier` 异常类
- `SafeQuery` 增加 `QuoteIdentifier` 内部函数: 仅允许字母数字下划线, 双引号包裹
- 校验 TableName/ColumnNames 是否存在于 `FSchema` 缓存
- 拒绝通配符 `*`, 空标识符, 含特殊字符的表达式

### 验证
- 新增 3 个回归测试 (`Tests/Regression/Test.Regression.BUG331_SafeQueryIdentifierValidation.pas`)
- 全部通过

---

## 2026-06-29 REVIEW5-DATA-001 SQLiteReader schema 缓存修复 ✅

> 来源: REVIEW5-DATA-001 五专家模块审阅 (DeepAxis)
> 范围: `OpenReadOnly` 打开后不缓存 `FSchema`, 导致 `SafeQueryMessages` 查询失效 (BUG-330)

### 问题
- `TExternalSQLiteReader.OpenReadOnly` 打开 DB 后未调用 `GetSchema` 填充 `FSchema`
- `SafeQueryMessages` 中 shard 表存在性检查迭代空 `FSchema.Tables`, 所有 MSG* 表跳过
- 微信聊天消息查询功能完全失效

### 修复
- `OpenReadOnly` 末尾调用 `FSchema := GetSchema` 缓存 schema
- `SafeQuery` schema 版本变更时同步刷新 `FSchema := GetSchema`
- `SafeQuery` 直接使用 `FSchema.SchemaFingerprint` 避免重复查询

### 验证
- 新增 3 个回归测试 (`Tests/Regression/Test.Regression.BUG330_SQLiteReaderSchemaCache.pas`)
- 全部通过

---

## 2026-06-29 REVIEW5-CORE-007 Core 包清单对齐 ✅

> 来源: REVIEW5-CORE-007 五专家模块审阅 (Core/DeepBaseServices)
> 范围: `DeepBase.SchemaAdapter.WeChat4x` 与 `DeepBase.i18n.Gender` 未在 `DeepBaseCore.dpk` 注册 (BUG-329)

### 问题
- `DeepBaseCore.dpk` 漏注册两个已存在的 Core 单元
- 其他包引用这些单元时会触发 "required package not found"

### 修复
- 在 `DeepBaseCore.dpk` 添加 `DeepBase.i18n.Gender` 注册 (紧跟 `i18n.Plural`)
- 在 `DeepBaseCore.dpk` 添加 `DeepBase.SchemaAdapter.WeChat4x` 注册 (紧跟 `WeChat39x`)

### 验证
- `DeepBaseCore` 编译通过

---

## 2026-06-29 REVIEW5-CORE-006 Metrics registry 死代码清理 ✅

> 来源: REVIEW5-CORE-006 五专家模块审阅 (Core/DeepBaseServices)
> 范围: `TMetrics` 类死代码 `FRegistry` 清理, 并发首访问验证 (BUG-328)

### 问题
- `TMetrics` 类存在 `class var FRegistry: TMetricsRegistry` 死代码: 声明但从未赋值
- `class destructor TMetrics.Destroy` 仅 `FreeAndNil` 永远为 nil 的 `FRegistry`, 无意义
- 实际 registry 通过 `Metrics` 函数 + DCL(`GRegistryLock`)正确初始化, 无并发问题
- 缺少并发首访问 `TMetrics.Counter`/`TMetrics.Gauge` 的回归测试

### 修复
- 移除 `TMetrics.FRegistry` 死代码类变量
- 移除 `class destructor TMetrics.Destroy` (仅释放 nil)
- 新增并发首访问回归测试

### 验证
- 新增 3 个回归测试 (`Tests/Regression/Test.Regression.BUG328_MetricsConcurrentInit.pas`)
- 全部通过: 4 线程并发创建 Counter/Gauge, Registry 单例验证

---

## 2026-06-29 REVIEW5-CORE-005 KeyManager AEAD 升级 ✅

> 来源: REVIEW5-CORE-005 五专家模块审阅 (Core/DeepBaseServices)
> 范围: `TDataKey.EncryptWith` 使用无认证 AES-CBC, 升级为 AES-GCM (BUG-327)

### 问题
- `EncryptWith` 使用 `aesCBC` 模式, 密文格式 `IV(16) + Cipher`, 无完整性认证
- 攻击者可修改密文 (bit-flipping/padding oracle), 解密后数据被篡改

### 修复
- `EncryptWith` 升级为 AES-256-GCM, 格式 `Version(1) + Nonce(12) + Cipher + Tag(16)`
- 版本字节 `0x01` 标识 GCM; `DecryptWith` 自动检测格式, 非 `0x01` 回退 CBC (向后兼容)
- GCM 认证标签自动检测篡改, 解密失败抛出 `ECryptoException`

### 验证
- 新增 5 个回归测试 (`Tests/Regression/Test.Regression.BUG327_KeyManagerAEAD.pas`)
- CI 全绿: 4084 total, 0 failed, 33 预存 CM 环境错误

---

## 2026-06-29 REVIEW5-CORE-004 Scheduler 回调异常隔离 ✅

> 来源: REVIEW5-CORE-004 五专家模块审阅 (Core/DeepBaseServices)
> 范围: `OnComplete` 回调异常覆写任务状态 / `OnError` 回调异常传播 (BUG-326)

### 问题
- `ExecuteTask` 成功路径中 `FOnCompleted` 回调异常被 except 捕获后覆写 `FLastError`, 已成功任务显示错误
- 失败路径中 `FOnFailed` 回调在锁外调用但无 try/except, 异常传播到 TTask 匿名方法

### 修复
- `FOnCompleted` except 块改为直接吞掉异常, 不再覆写 `FLastError` (与 BUG-324 WorkerQueue 模式一致)
- `LOnFailed` 调用包裹 try/except, 防止回调异常传播

### 验证
- 新增 3 个回归测试 (`Tests/Regression/Test.Regression.BUG326_SchedulerCallbackSafety.pas`)
- CI 全绿: 4079 total, 0 failed, 33 预存 CM 环境错误

---

## 2026-06-29 REVIEW5-CORE-003 WorkerQueue timeout 执行 ✅

> 来源: REVIEW5-CORE-003 五专家模块审阅 (Core/DeepBaseServices)
> 范围: `TJob.Timeout` 未执行, 长 handler 无限占用 worker (BUG-325)

### 问题
- `TJob.Timeout` 属性已定义但 `ProcessJob` 从未读取, 长耗时 handler 永久占用 worker 线程
- 无超时失败反馈, 调用方无法得知 job 已超时

### 修复
- 新增 `TJobHandlerThread`: 专用线程执行 handler, 构造器按值捕获 `TJobHandler`/`TJob`/`TEvent`, 避免闭包引用悬挂 (原 `TTask.Run` 方案因匿名方法按引用捕获局部变量导致 Runtime error 216)
- `ProcessJob` 当 `Timeout > 0` 时: 创建 handler 线程 + `TEvent`, `WaitFor(Timeout)` 等待; 超时则标记 `jsFailed` → `MoveToDeadLetter` (不重试)
- 超时路径: handler 线程始终 `WaitFor` 确保干净生命周期; 异常通过 `TakeError` 转移所有权避免 use-after-free
- `Timeout = 0` 时 handler 在 worker 线程内联执行, 无额外线程开销

### 验证
- 新增 5 个回归测试 (`Tests/Regression/Test.Regression.BUG325_WorkerQueueTimeout.pas`)
- CI 全绿: 4076 total, 0 failed, 33 预存 CM 环境错误

---

## 2026-06-29 REVIEW5-CORE-002 WorkerQueue 回调异常兜底 ✅

> 来源: REVIEW5-CORE-002 五专家模块审阅 (Core/DeepBaseServices)
> 范围: 外部回调/存储异常导致 job 卡在 jsRunning (BUG-324)

### 问题
- `ProcessJob` 设置 `jsRunning` 后调用 `FOnJobStarted` / `FStorage.SaveJob` 无 try/except 保护
- handler 成功路径中的 `FOnJobCompleted` / `FOnCompletion` 若抛异常, 被 except 误判为 handler 失败
- except 分支中的 `FOnError` / `FOnJobRetrying` / `FOnJobFailed` / `FOnCompletion` 也可能抛异常, 掩盖原始错误
- `TJob.ReportProgress` 中的 `FOnProgress` 回调抛异常导致 handler 被判定失败

### 修复
- 外层 `try...finally` 包裹整个 post-running 生命周期, `finally` 中执行最终 `SaveJob`
- 所有外部回调 (`FOnJobStarted`/`FOnJobCompleted`/`FOnCompletion`/`FOnError`/`FOnJobRetrying`/`FOnJobFailed`) 各自独立 try/except, 吞掉异常
- `TJob.ReportProgress` 中的 `FOnProgress` 回调也加 try/except 保护
- 状态转换 (jsRunning → jsCompleted/jsFailed) 不再被任何外部回调异常阻断

### 验证
- 新增 9 个回归测试 (`Tests/Regression/Test.Regression.BUG324_WorkerQueueCallbackSafety.pas`)
- CI 全绿: 4071 total, 0 failed, 33 预存 CM 环境错误

---

## 2026-06-29 REVIEW5-CORE-001 FileWatcher 生命周期修复 ✅

> 来源: REVIEW5-CORE-001 五专家模块审阅 (Core/DeepBaseServices)
> 范围: FileWatcher queued callback 与 debounce task 销毁后回调/UAF (BUG-323)

### 问题
- `TFileWatcherThread.NotifyChange/NotifyError` 使用 `TThread.Queue(nil, ...)` 投递匿名方法到主线程
- 匿名方法捕获 `FOwner` 强引用, FileWatcher 销毁后回调触发 use-after-free
- `HandleDebounce` 创建的 `TTask` 在池线程等待, FileWatcher 销毁后访问已释放字段

### 修复
- 新增 `TFileWatcherGuard` (TInterfacedObject) 作为生命周期哨兵
- `NotifyChange/NotifyError` 捕获 `IInterface` (guard) 而非 `FOwner`, 回调通过 `GetWatcher` 检查存活
- `HandleDebounce` TTask 同样捕获 guard 引用
- 新增 `FDestroying: Boolean` 标志, 析构入口设置; `DoFileChanged/HandleDebounce/ProcessDebouncedChanges` 检查
- 析构流程: `FDestroying:=True` → `Stop` → `ClearWatcher` → drain → 释放
- `TFileWatcherThread.Execute` 循环条件加入 `FOwner.FDestroying` 检查

### 验证
- 新增 6 个生命周期回归测试 (`Tests/Regression/Test.Regression.BUG320_FileWatcherLifecycle.pas`)
- CI 全绿: 4095 total, 0 failed, 33 预存 CM 环境错误

---

## 2026-06-29 tasks.md 对齐 + QA-P1-001 阶段性归档

> 来源: QA-P1-001 核心模块测试覆盖阶段性完成
> 范围: 三专家/五专家审阅修复 + Commerce 测试 + Updater 安全 + CI 增强

### 已完成子项 (10 项, 累计 104 测试)
- Updater 安全测试 (14 用例)
- LLM E2E mock 测试 (15 用例)
- 桌面工具模板 E2E
- CI 可选包矩阵测试
- REVIEW-P0-001 编码扫描门禁+旧库迁移 (20 测试)
- REVIEW-P0-002 代码层 (23 测试)
- REVIEW-P1-001 TDBVoiceProfileStorage+11 DB 测试
- REVIEW-P1-002 官方 LLM 意图分类后端+9 测试
- REVIEW-P1-004 CI STUB/编码门禁+3 测试
- Commerce 测试覆盖 #10 (11 验证路径)

### 待办 (Phase 1-5)
- Phase 1: Schema.pas 测试 (3884 行零测试)
- Phase 2: Resilience 系列测试 (Retry 405 / Policy 251 / Bulkhead 232 行)
- Phase 3: LogQuery.pas 测试 (1804 行零测试)
- Phase 4: IntentClarification 关键路径测试 (8266 行)
- Phase 5: Speech 关键路径测试 (8065 行)
- iOS/Android 权限查询真机补全 (需 Xcode + iOS 设备)

### tasks.md 对齐
- OPT-P1-001 (BUG-320) 已归档到 history.md
- QA-P1-001 已完成子项标记 [x], 待办清晰
- CI 单元全绿: 4090 total, 4054 passed, 0 failed, 33 预存 CM 环境错误

---

## 2026-06-28 全库优化六维度审计 + BUG-320 线程安全修复 ✅

> 来源: 优化工作审查 — 全库可优化点梳理 + 紧急线程安全修复
> 范围: 测试覆盖、线程安全、大文件拆分、重复代码、资源泄漏、异常处理

### 审计结果
- **测试覆盖**: 39 个 Core 模块无测试 (Schema.pas 3884 行/LogQuery.pas 1804 行最突出); 78+ Features 模块无测试 (IntentClarification 8266 行 28 文件/Speech 8065 行 25 文件/Commerce 7067 行 14 文件)
- **线程安全**: 13 个 Core 文件有 class var 但无锁保护; DateTime/i18n.Gender/AIErrorHandler 在请求处理路径上并发读写 TDictionary/TList → AV 风险 (BUG-320)
- **大文件**: 8 个文件 > 2000 行 (Schema 3884/Crypto 2856/LLM 2635/Math 2621/CloudBackup 2521/WorkerQueue 2431/Graph 2306/CloudSync 2302)
- **重复代码**: 14 模块共享相同 StorageFactory 样板 (class var + setter + getter), 合计约 420 行可泛型化 (BUG-322)
- **资源泄漏**: 219 处 JSON/Stream Create 嫌疑, 大部分为返回给调用方模式 (非真正泄漏)
- **异常处理**: Core 0 处 raise Exception.Create, Features 4 处 (CloudBackup×2/LLM.Service/Updater) ✅ 良好
- **TODO 管理**: Core/Features 仅 1 处未标注 ticket ✅ 良好
- **大函数**: 仅 3 个 >100 行函数 ✅ 良好

### BUG-320 修复 (线程安全)
- `Core/DeepBase.DateTime.pas`:
  - 移除 `TTimeZones.FCache` 死代码 (创建但从未使用)
  - `TBusinessDays` 新增 `FLock: TCriticalSection`, 包裹 SetWeekendDays/AddHoliday/ClearHolidays/IsBusinessDay/IsWeekend/IsHoliday
- `Core/DeepBase.i18n.Gender.pas`:
  - `TGenderVariant` 新增 `FLock`, Initialize 改 double-check locking
  - 包裹 Register*/GetLanguageInfo/Transform + `TCaseVariant.Transform`
- `Core/DeepBase.i18n.Plural.pas`:
  - `TPluralRules` 新增 `FLock`, Initialize 改 double-check locking
  - 包裹 RegisterRule/GetCategory/GetSupportedCategories
- `Core/DeepBase.AIErrorHandler.pas`:
  - `TAIErrorHandler` 新增 `FLock` + class constructor/destructor
  - CallAI 改为 snapshot-then-unlock 模式 (锁外执行 AI 回调)
  - Handle 快照 FConfig 到局部变量; Install/SetAICallback/ClearCache 包裹

### 验证
- DateTime/i18n.Gender/i18n.Plural: 301 tests passed, 0 leaked
- DateTime/i18n/Speech.Intent: 188 tests passed, 0 leaked

### 新 Bug 登记
- BUG-320: DateTime/i18n/AIErrorHandler 运行时缓存无锁保护 → ✅ 已修复
- BUG-321: Schema/LogQuery/Resilience 核心模块零测试 → 🟠 High (待修复)
- BUG-322: 14 模块 StorageFactory 样板代码重复 420 行 → 🟡 Medium (待修复)

### 优先级排序
1. ~~**P1 紧急**: DateTime/i18n/AIErrorHandler 加锁保护 (1-2天)~~ ✅ 已完成
2. **P1 重要**: Schema.pas / Resilience 系列补测试 (3-5天)
3. **P2 中期**: StorageFactory 泛型化消除重复 (1天)
4. **P2 中期**: 大文件拆分 (Schema → 4 文件, 2-3天)
5. **P2 中期**: IntentClarification / Speech 补测试 (5-7天)

---

## 2026-06-27 代码质量优化 (编译器提示清理 + 编码修复) ✅

> 来源: 优化工作审查
> 范围: H2164/H2219 编译器提示清理、编码损坏修复、TODO 规范化

### 编译器提示清理 (12 处)
- **H2164 (变量未使用, 5 处)**:
  - `Core/DeepBase.DateTime.pas`: 移除 `U: string` (FromRFC2822 中未用)
  - `Core/DeepBase.i18n.Gender.pas`: 移除 `CharType: TUnicodeCategory` (IsRTLChar 中未用)
  - `Features/DeepBase.Net.pas`: 移除 `LRequest: IHTTPRequest` (Execute 中未用)
  - `Tests/Test.DeepBase.DB.Factory.pas`: 移除 `Profile: TDBConnectionProfile`
  - `Tests/Test.DeepBase.DateTime.pas`: 移除 `HolidayDate: TDateTime`

- **H2219 (私有符号未使用, 7 处)**:
  - `Core/DeepBase.Protection.pas`: 移除 `GenerateRandomIV` + `PadData` 声明及实现 (CBC 遗留)
  - `Core/DeepBase.Resilience.CircuitBreaker.pas`: 移除 `FInstance` class var (单例改用全局函数)
  - `Core/DeepBase.RateLimiter.pas`: 移除 `FInstance` + `FLockInstance` class vars
  - `Features/DeepBase.Commerce.Backend.Http.pas`: 移除 `TCommerceHttpPaymentGateway.RequireServerWrites` 声明及实现
  - `Tests/Test.DeepBase.Speech.Intent.pas`: 移除 `JsonIntent` helper 声明及实现

### 编码损坏修复 (8 处)
- `ThirdParty/Payment/DeepBase.Payment.WeChatPay.pas`: 恢复 5 处文件头/字段中文注释
- `Tools/CLI/CLI.I18n.pas`: 恢复文件头描述 "CLI 国际化命令工具集"
- `Tests/Regression/RegressionTestRegistry.pas`: 修复 2 处 mojibake (检?→检查, 所?→所有)

### TODO 规范化 (5 处)
- `DeepFlow/Source/Roles/DeepFlow.Guard.pas`: 2 处 → `TODO(PRODUCT-P2-001)`
- `Tools/Tray/Automation/Tray.Automation.pas`: 1 处 → `TODO(OPS-P2-001)`
- `Tests/Regression/RegressionTestRegistry.pas`: 1 处 → `TODO(QA-P1-001)`

### 验证
- CI: 4090 total, 4054 passed, 0 failed, 33 预存 CM 环境错误
- 软告警从 236 降至 ~224

---

## 2026-06-25 商业化模块增强 (Commerce P0-1/P0-2/P1) ✅

> 来源: Commerce 模块审阅/增强
> 范围: 微信支付 V3 回调验证、权益 Tier/设备限额/宽限期、4 项正确性修复

### P0-1: 微信支付 V3 回调验证
- `Features/DeepBase.Commerce.PaymentBridge.pas`:
  - `TSDKNotificationVerifier` 新增 `FWeChatClient: TWeChatPayClient` 字段
  - 移除 fail-closed 守卫,实现 WeChat Pay V3 分支:
    - 提取 `Wechatpay-Timestamp/Nonce/Signature` HTTP 头
    - 调用 `TWeChatPayClient.VerifyNotificationWithSignature` 完成 SHA256-RSA2048 签名验证 + AES-256-GCM 资源信封解密
  - `CreateWeChatPayNotificationVerifier` 工厂新增 `AWeChatPublicKey` 参数,创建 `TWeChatPayClient` 并配置 ApiKeyV3 + WeChatPublicKey
  - 支付单元移至 interface uses 以解决类型可见性

### P0-2: 权益 Tier/MaxDevices/OfflineGraceDays
- `Features/DeepBase.Commerce.Types.pas`: `TCommerceProductData` 新增 Tier/MaxDevices/OfflineGraceDays 字段
- `Features/DeepBase.Commerce.Service.pas`: `GrantEntitlementForOrder` 从 Product 透传这些字段到 Entitlement
- `Features/DeepBase.Commerce.JsonUtil.pas`、`Adapter.Supabase`、`Adapter.Firebase` 均支持序列化/反序列化

### P1 正确性修复
- **#3**: `BeginPayment` 新增用户存在性 + 活跃性检查
- **#4**: `VerifyAndConfirmPayment` 重构为锁外验签 + ConfirmPayment 自管锁
- **#5**: `CloseOrder` API 全链路 (Service/SafeClient/HttpStorage/Backend.Contract route)
- **#6**: `ConsumeEntitlement` 迭代所有可用权益 + 校验 ACount > 0

### 测试: 9 个新单测
- `Tests/Test.DeepBase.Commerce.PaymentBridge.pas`: `TWeChatPayBridgeTests` 验证工厂创建、空 body/畸形 JSON/缺失 resource/空 ciphertext/非法 AES-GCM/空签名头 等拒绝路径,以及 Service 注册集成

---

## 2026-06-25 商业化模块测试覆盖补齐 (Commerce #10) ✅

> 来源: Commerce 模块审阅/增强 — 测试覆盖 (#10)
> 范围: 11 验证路径边界检查测试

### 测试: 11 个新单测
- `Tests/Test.DeepBase.Commerce.pas`: `TCommerceServiceTests` 新增验证路径测试:
  - `Test_RegisterProduct_RejectsEmptyAppId/ProductId/NegativeAmount/EmptyEntitlementCode` — 产品注册参数校验
  - `Test_CreateOrder_RejectsNonExistentUser/InactiveUser` — 订单创建用户状态校验
  - `Test_EnsureUserForIdentity_RejectsEmptyProviderUserId/EmptyAppId` — 用户身份创建参数校验
  - `Test_CloseOrder_RejectsNotFound/TerminalState` — 订单关闭状态校验
  - `Test_ConsumeEntitlement_RejectsNonPositiveCount` — 权益消费数量校验

### 验证
- CI: 4090 total, 4054 passed, 0 failed, 33 预存 CM 环境错误
- 新增 11 测试全部通过

---

## 2026-06-25 WebAPI 可观测性模块 (OPS-P2-001 第一阶段) ✅

> 来源: tasks.md OPS-P2-001 服务器可观测性和运维
> 范围: /health、/metrics 端点 + 请求度量中间件

### 新增单元: DeepBase.WebAPI.Observability
- `TWebHealthCheckRegistry` — 可注册多个健康检查,执行并输出 JSON 汇总 (healthy/degraded/unhealthy)
- `TMetricsCollector` — 线程安全的 Prometheus 度量收集器,支持 Counter / Gauge / Histogram 三种类型
- `TMetricSeries` — 单个度量系列,支持标签和直方图桶
- `TObservability.RegisterHealthEndpoint` — 在 TApiServer 上注册 `GET /health`
- `TObservability.RegisterMetricsEndpoint` — 在 TApiServer 上注册 `GET /metrics` (Prometheus 纯文本格式)
- `TObservability.CreateRequestMetricsMiddleware` — 请求计数 + 延迟直方图中间件
- `TObservability.DefaultDurationBuckets` — 默认 9 桶 (5ms ~ 5s)

### 测试: 33 个单测
- `TTestWebHealthCheckResult` (5 tests) — 记录构造 / JSON 输出
- `TTestWebHealthCheckRegistry` (8 tests) — 空/单/混合/异常/多注册/耗时测量
- `TTestMetricsCollector` (10 tests) — 计数器/仪表/直方图/Prometheus 格式
- `TTestMetricSeries` (3 tests) — 直接 Prometheus 格式验证
- `TTestObservability` (7 tests) — 辅助函数/端点注册/中间件创建

### 验证
- CI: 4067 total, 4040 passed, 0 failed, 24 预存 CM 环境错误, 3 ignored
- 新增 33 测试全部通过

---

## 2026-06-25 三专家审阅 P2 修复全部完成 + 回归测试补齐 ✅

> 来源: 2026-06-21 三专家审阅 P2 级别 (BUG-306 ~ BUG-319) + EXP-P0 回归测试补齐
> 范围: 14 个 P2 修复 + 5 个回归测试补齐项

### P2 修复 (14 项, BUG-306 ~ BUG-319)

- **EXP-P2-002 / BUG-306**: LLM Manager BuildContext 对外 JSON 仅包含错误类型与通用描述，内部细节写入日志
- **EXP-P2-003 / BUG-307**: Speech.Config Normalize 允许仅语言标签 (ja→ja-JP, en→en-US)
- **EXP-P2-004 / BUG-308**: LLM Manager SetProductionVersion 改为单条 CASE 原子 UPDATE; DeleteVersions 单条 DELETE + IN
- **EXP-P2-005 / BUG-309**: AutoUpdate HTTP 请求设置 `User-Agent: DeepBase/{version}` 头
- **EXP-P2-006 / BUG-310**: TLRUCache.MoveToEnd 改用 doubly-linked list + TDictionary<K, PListNode>，O(1) 性能
- **EXP-P2-007 / BUG-311**: TSmartCache 与 TCache 统一使用 TCache 的 TCacheEvictionPolicy
- **EXP-P2-008 / BUG-312**: Logger PickLogFileForWrite 添加最大 idx 上限检查 (999)
- **EXP-P2-009 / BUG-313**: ExceptionHandler 移除 FInstance 字段及 class constructor/destructor
- **EXP-P2-010 / BUG-314**: DateTime FromRFC2822 实现完整 RFC 2822 解析器 (含可选 day-of-week、两位/四位年份、军事/命名/数字时区、括号注释剥离; 7 个回归测试)
- **EXP-P2-011 / BUG-315**: DB.Factory 改为直接从 TDBConnectionProfile 构造 TFDConnection，不再创建/销毁临时 TUniConnectionPool
- **EXP-P2-012 / BUG-316**: DateTime AddBusinessDays 文档明确说明，ADays=0 时 snap 到最近营业日
- **EXP-P2-013 / BUG-317**: EventBus PublishAsync 统一改为 TThread.CreateAnonymousThread + FreeOnTerminate
- **EXP-P2-014 / BUG-318**: Exceptions.pas 文件保存为 UTF-8 with BOM
- **EXP-P2-015 / BUG-319**: DateTime Diff 提供 DiffCalendarMonths/DiffCalendarYears

### 回归测试补齐 (5 项)
- **EXP-P0-002**: 区域回归测试 (zh-CN/de-DE/fr-FR 线程环境下金额格式) → TAlipayAmountLocaleTests
- **EXP-P0-003**: 并发回归测试 (100 并发请求生成 100 个不同幂等键) → TStripeIdempotencyKeyTests
- **EXP-P0-004**: LFU 回归测试 (cepLFU 高频不被淘汰、低频被淘汰) → Test.DeepBase.Cache
- **EXP-P0-005**: `-IncludeStubApis` 二级门禁接入 run_tests.ps1 (336 文件 0 STUB 标记通过)
- **EXP-P1-015 / BUG-302**: JobQueue 指数退避 (`next_run_at` 列) + 独立 DLQ 表 `DeepBase_job_queue_dlq` (2026-06-22, 7 回归测试通过)

### 验证
- CI 单元全绿: 4034 total, 4004 passed, 0 failed, 24 预存 CM 环境错误
- STUB/编码门禁 PASSED
- 详细修复记录见 bugfix.md BUG-306 ~ BUG-319

---

## 2026-06-24 REVIEW-P1-004 完成: CI 门禁接入 + ENotImplementedException + 桩方法 raise ✅

> 来源: BUG-281 / REVIEW-P1-004 (稳定性/并发专家)
> 范围: CI 流水线 + 异常体系 + FMX/VCL 桩方法

### CI 门禁接入
- `.github/workflows/delphi-ci.yml` unit-tests job 追加 `-IncludeStubApis -IncludeEncoding`
- STUB API Gate: PASSED (0 STUB markers, 所有桩已标注 BUG ID)
- Encoding Gate: PASSED (0 hard violations, 8 allowlisted FMX 遗留 + 236 BOM 软告警)

### ENotImplementedException
- 新增 `Core/DeepBase.Exceptions.pas`: `ENotImplementedException = class(EInvalidOperationException)`
- 语义: 功能尚未实现时抛出,替代返回默认值导致的静默失败
- 继承链: `ENotImplementedException` → `EInvalidOperationException` → `EOperationException` → `EDeepBaseException`

### FMX/VCL 桩方法修改
- **raise 版** (在 IFDEF 分支内,Windows 不编译):
  - `FMX.Platform.pas` `UpdateScreenInfo` iOS/Android SafeArea 分支
  - `FMX.Theme.pas` `DetectSystemTheme` Android/iOS 分支
- **TODO→STUB 版** (桌面路径执行,不 raise):
  - `FMX.Platform.pas` iOS permission stubs (BUG-277)
  - `FMX.ListView.pas` `ApplyFilter` / `ClearFilter` (BUG-281)
  - `FMX.UpdateDialog.pas` `DownloadComplete` 重启 (UPD-P0-001)
  - `VCL.UpdateDialog.pas` `Execute` 版本号 (UPD-P0-001)

### 回归测试 (3 个, 全部通过)
| # | 测试名 | 断言 |
|---|--------|------|
| 1 | `Test_ENotImplemented_InheritsFromEInvalidOperationException` | `is EInvalidOperationException` = True |
| 2 | `Test_ENotImplemented_InheritsFromEDeepBaseException` | `is EDeepBaseException` = True |
| 3 | `Test_ENotImplemented_CarriesErrorCodeAndContext` | ErrorCode=42, Context='TestContext', Timestamp ≈ Now |

### 文件变更
- **修改**: `Core/DeepBase.Exceptions.pas` — 新增 ENotImplementedException
- **修改**: `FMX/DeepBase.FMX.Platform.pas` — raise + STUB
- **修改**: `FMX/DeepBase.FMX.Theme.pas` — raise + STUB
- **修改**: `FMX/DeepBase.FMX.ListView.pas` — STUB
- **修改**: `FMX/DeepBase.FMX.UpdateDialog.pas` — STUB
- **修改**: `VCL/DeepBase.VCL.UpdateDialog.pas` — STUB
- **修改**: `.github/workflows/delphi-ci.yml` — CI 门禁 flag
- **新增**: `Tests/Test.DeepBase.Exceptions.pas` — 3 回归测试
- **修改**: `Tests/DeepBaseTests.dpr` — 编译入口

### CI 结果
- total=4034 (4031 + 3), errors=24 (预存 CM), failures=0
- STUB Gate: PASSED, Encoding Gate: PASSED

---

## 2026-06-24 REVIEW-P1-002 完成: 官方 LLM 意图分类后端 ✅

> 来源: BUG-279 待办 (REVIEW-P1-002, 架构/API 专家)
> 范围: `Features/DeepBase.Speech.Intent.LLMBackend.pas` + `Tests/Test.DeepBase.Speech.Intent.LLMBackend.pas`

### 设计要点
- **注入式适配器**: `TIntentChatFunc = reference to function(const APrompt: string; ATimeoutMs: Integer): string` — 兼容 `TDeepBaseLLM.Chat` / `TBillingClient.Chat` / `TProxyLLMClient.Chat` 的任意包装
- **包边界不破坏**: `DeepBaseSpeechCore.dpk` 不依赖 `DeepBaseLLM`; 下游组合根负责注入真实 LLM 客户端
- **纯函数 `BuildIntentPrompt`**: 构建 system + user 双消息 prompt,已注册意图以逗号分隔列表传入,LLM 返回 `{"intent":"...","confidence":0..1,"reason":"..."}` JSON
- **工厂函数 `CreateIntentLLMBackend`**: 包装 `TIntentChatFunc` 为 `TIntentLLMBackend`; `AChatFunc=nil` → `EArgumentException`; 默认超时 5000 ms
- **异常传播**: chat 函数抛异常 → 向上传播,`TDeepBaseIntentParser.Parse` 内部 try/except 捕获为 `Source='llm_unavailable'`

### 下游接入示例

```pascal
var
  LChatFunc: TIntentChatFunc :=
    function(const APrompt: string; ATimeoutMs: Integer): string
    var LResp: TLLMChatResponse;
    begin
      LLM.DefaultTimeout := ATimeoutMs;
      if LLM.Chat(APrompt, LResp) and LResp.Success then
        Result := LResp.Content
      else
        raise Exception.Create('LLM error: ' + LResp.ErrorMessage);
    end;
TDeepBaseIntentParser.RegisterGlobalLLMBackend(
  CreateIntentLLMBackend(LChatFunc));
```

### 回归测试 (9 个, 全部通过)
| # | 测试名 | 断言 |
|---|--------|------|
| 1 | `Test_CreateBackend_NilChatFunc_Raises` | nil → `EArgumentException` |
| 2 | `Test_CreateBackend_ValidChatFunc_ReturnsBackend` | 返回 Assigned backend |
| 3 | `Test_BuildIntentPrompt_ContainsAllFields` | prompt 含用户文本 + locale + 意图 + JSON 格式 |
| 4 | `Test_BuildIntentPrompt_EmptyIntents_ContainsNone` | 空列表 → "Available intents: none" |
| 5 | `Test_Backend_CallsChatFunc_WithCorrectTimeout` | timeout 正确传递 |
| 6 | `Test_Backend_ReturnsChatFuncResponse_Verbatim` | JSON 原样返回 |
| 7 | `Test_Backend_ChatFuncRaises_ExceptionPropagates` | 异常向上传播 |
| 8 | `Test_Backend_IntegrationWithParser_LLMSource` | parser + 后端 → Source='llm', Intent='book_flight' |
| 9 | `Test_Backend_IntegrationWithParser_InvalidJSON` | 非法 JSON → intent='unknown' |

### 文件变更
- **新增**: `Features/DeepBase.Speech.Intent.LLMBackend.pas`
- **新增**: `Tests/Test.DeepBase.Speech.Intent.LLMBackend.pas`
- **修改**: `DeepBaseSpeechCore.dpk` — contains 追加新单元
- **修改**: `Tests/DeepBaseTests.dpr` — 追加编译入口
- CI: 4007 passed (3998 + 9), 0 failed, 24 预存 CM 环境错误不变

---

## 2026-06-23 REVIEW-P0-002 代码层实现完成: Windows ShareFileEx Shell 路径 + iOS 权限/分享桩 ✅

> 来源: BUG-277 待办 (REVIEW-P0-002, 安全/平台专家)
> 范围: `FMX/DeepBase.FMX.Platform.pas` + `Tests/FMX/TestFMXPlatformStandalone.dpr` + `Tests/Test.DeepBase.FMX.pas`

### Windows ShareFileEx 走 Shell "share" 动词
- 默认分支: `ShellExecuteEx` + `lpVerb = 'share'` + `SEE_MASK_INVOKEIDLIST` 调起系统原生分享 UI
- 文件不存在 → 直接 `Exit(False)`,不尝试 UI
- `ShellExecuteEx` 失败 (老版本 Windows 不支持) → 回退 `CopyToClipboard(AFilePath)`
- Android 路径 (Intent `ACTION_SEND` + `EXTRA_STREAM`) 保持原实现不变

### iOS 框架头接入 + 桩
- `uses` 新增 `iOSapi.UIKit / iOSapi.Foundation / iOSapi.AVFoundation / iOSapi.Photos / iOSapi.UserNotifications / iOSapi.Contacts / Macapi.ObjCRuntime / Macapi.Helpers`
- `CheckiOSPermission(const APermission)`: 识别 `ios.microphone / ios.camera / ios.photos / ios.notifications / ios.contacts`,其他键 → `prUnsupported`;真机路径以 `// TODO(on-device):` 注释留桩,当前统一返回 `prUnsupported` 避免编译失败
- `RequestiOSPermission(const APermission, ACallback)`: 同样按键分发,真机路径留 `// TODO(on-device):`,当前直接返回 `CheckiOSPermission` 结果并同步触发 `ACallback`
- `CheckPermissionEx` / `RequestPermissionEx` 分发链: 运行时 override → `DeepBase.Platform.Interfaces` 全局 delegate → 编译期 IFDEF (Android / iOS / Desktop)

### 回归测试
- `Tests/FMX/TestFMXPlatformStandalone.dpr` 新增 `Test_ShareFileEx_MissingFile_ReturnsFalse`:
  - 缺失文件路径 (无 delegate) → 断言返回 `False`,且无 UI 弹出
  - 注册 delegate 返回 `True` → 断言 override 优先于 IFDEF 默认分支
- DUnitX 端 `Tests/Test.DeepBase.FMX.pas` 新增 4 个测试 (未接入主 suite,留作真机/CI 时合入):
  - `Test_Platform_ShareFileEx_DelegateOverride_IsInvoked`
  - `Test_Platform_ShareFileEx_MissingFile_ReturnsFalse`
  - `Test_Platform_CheckPermissionEx_DelegateOverride_IsInvoked`
  - `Test_Platform_RequestPermissionEx_DelegateOverride_FiresCallback`

### 验证
- 独立驱动 dcc64 编译通过 (1383 行, 0.73s, 退出码 0)
- 运行 `TestFMXPlatformStandalone.exe --batch`: **17/17 PASS** (15 旧 + 2 新)
- 源码目录无 DCU 产物泄漏 (BUG-285 守护)
- 全量单元回归: 与改动前一致 (24 个 Credential Manager 环境错误为 CI 沙盒预期,非本轮引入)

### 后续 (真机,留待 Xcode + iOS 设备环境)
- iOS `CheckiOSPermission` / `RequestiOSPermission` 替换为真 AVAuthorizationStatus / PHAuthorizationStatus / UNAuthorizationStatus / CNAuthorizationStatus 查询
- iOS `ShareFileEx` 真机路径: `UIActivityViewController` 调起系统分享 sheet
- 把 DUnitX 4 个新测试合入 `DeepBaseTests.dpr`,CI 跑 Win64 时覆盖 delegate 链

---

## 2026-06-23 REVIEW-P1-001 完成: FireDAC 声纹资料库存储 (TDBVoiceProfileStorage) ✅

> 来源: BUG-278 后续 (REVIEW-P1-001, 数据/安全专家)
> 范围: `Persistence/DeepBase.Persistence.Speech.Voiceprint.FireDAC.pas` + `Features/DeepBase.Speech.Voiceprint.Contracts.pas` + 包重构 (MFCC/DTW/Contracts)
> 测试: 新增 11 个 DB 回归, 3998 passed, 0 failed, 24 预存 CM 错误

### 包重构
- MFCC (`DeepBase.Speech.MFCC`) 和 DTW (`DeepBase.Speech.DTW`) 从 `DeepBaseSpeechVoice.dpk` 迁入 `DeepBaseSpeechCore.dpk`，因为 Contracts 单元和 TDBVoiceProfileStorage 都需要 TMFCCFrame/TMFCCFeatures 类型
- `IVoiceProfileStorage` + `TVoiceProfileId` + `TVoiceProfileInfo` 从 `Features/DeepBase.Speech.Voiceprint.pas` 抽出为 `Features/DeepBase.Speech.Voiceprint.Contracts.pas` 契约单元，放入 DeepBaseSpeechCore.dpk
- Persistence 包 (`DeepBasePersistence.dpk`) 新增 `requires DeepBaseSpeechCore`，新增 `contains DeepBase.Persistence.Speech.Voiceprint.FireDAC`
- `Test.DeepBase.Speech.Voiceprint.pas` 改用 Contracts 单元中的接口/类型定义

### TDBVoiceProfileStorage 实现
- `TDBVoiceProfileStorage = class(TInterfacedObject, IVoiceProfileStorage)` 在 `DeepBase.Persistence.Speech.Voiceprint.FireDAC.pas`
- 构造: `Create(AConnection: TFDConnection; const AOwnerApp: string)`；nil 连接或空 owner_app 抛 EArgumentException
- 生命周期: 不拥有 TFDConnection；调用方必须保证连接存活期超过 storage
- Schema: 懒调用 `DeepBase.Speech.Schema.EnsureSpeechSchema` 创建 `voice_profiles` 表（幂等 DDL）
- BLOB 完整性: 特征帧序列化 → HMAC-SHA256（密钥从 owner_app 派生）→ features + features_hmac 写库；读取时校验 HMAC，不匹配抛 EDatabaseVoiceprintTampered
- 日期: ISO8601 字符串 (`yyyy-mm-dd"T"hh:nn:ss.zzz`)；UPDATE 策略保留原有 created_at
- owner_app 隔离: 所有查询 WHERE owner_app = :owner_app；DELETE/UPDATE 同样过滤

### UPDATE 保时策略
- 不采用 SELECT先读 → DELETE → INSERT 的创建时间保留方式（曾被时区转换问题干扰）
- 改为先执行 UPDATE（只改非 PK 列，不碰 created_at），RowsAffected=0 时再 INSERT 设 created_at=Now
- 彻底消除 TDateTime → ISO8601 → TDateTime 往返精度/时区风险

### 测试 (11 个)
- `Test_LoadAll_EmptyTable_ReturnsEmptyArray`
- `Test_SaveProfile_ThenLoadAll_RoundTrips`
- `Test_SaveProfile_ThenLoadFeatures_RoundTrips`
- `Test_LoadFeatures_UnknownId_ReturnsEmpty`
- `Test_DeleteProfile_ExistingRow_ReturnsTrue`
- `Test_DeleteProfile_UnknownId_ReturnsFalse`
- `Test_SaveProfile_UpdateExisting_PreservesCreatedAt`
- `Test_OwnerApp_Isolation`
- `Test_TamperedFeatures_HmacMismatch_Raises`
- `Test_Ctor_NilConnection_Raises`
- `Test_Ctor_EmptyOwnerApp_Raises`

### 验证
- 全量单元回归: 3998 passed, 0 failed, 24 预存 Credential Manager 环境错误（非本轮引入）
- 编译通过; BUG-285 DCU 清理已自动完成
- 源码目录无 DCU 产物泄漏

### 后续
- 可用 `TDeepBaseVoiceprint.SetStorage(TDBVoiceProfileStorage)` 替换旧 DPAPI 文件存储，使声纹资料与 ConfigDB 共生命周期
- Migration 脚本把既有 DPAPI JSON 文件数据导入 voice_profiles 表（根据产品需求安排）

---

## 2026-06-22 REVIEW-P0-001 完成: 编码扫描门禁 + BUG-276 旧库迁移 ✅

> 来源: BUG-276 待办 (REVIEW-P0-001, 数据/安全专家)
> 范围: 新增 `Scripts/check_encoding.ps1` + `Scripts/encoding-allowlist.txt` + `Migrations/I18n/`

### 编码扫描门禁
- `Scripts/check_encoding.ps1` 扫描:
  - 运行时源码 (Core/Features/FMX/VCL/Persistence) `.pas/.dpr/.dpk/.dfm/.fmx` — UTF-8 + 必须 BOM
  - 文档 (README/docs/*.md/bugfix.md/tasks.md/history.md 等) — UTF-8 + 禁 BOM
  - 迁移脚本 (Migrations/**/*.sql) — UTF-8 + 禁 BOM
- 硬门禁 (InvalidUtf8 / Mojibake 模式) → `-FailOnViolation` 下失败
- 软门禁 (MissingBom / UnexpectedBOM) → 只告警
- 已知破坏 FMX 文件通过 `Scripts/encoding-allowlist.txt` 降级为警告,避免阻塞新 PR
- Mojibake 检测: UTF-8 BOM 误读 (`ï»¿`/`Ã¯Â»Â¿`)、GBK 双编码常见 CJK 碎片 (`ç¡®å®`=确定, `å³é`=取消 等)、CP1252-as-UTF-8 通用签名 (`Ã` + 高字节 ×3+)
- 字节级 RFC-3629 UTF-8 验证器 (拒绝超长/代理对/>U+10FFFF)

### CI 集成
- `Scripts/run_tests.ps1` 新增 `-IncludeEncoding` 二级门禁 (与 `-IncludeStubApis` 同模式)
- CI 下调用 `check_encoding.ps1 -AllowlistPath Scripts/encoding-allowlist.txt -FailOnViolation`
- 报告输出到 `TestResults/EncodingGate.json` (UTF-8 no-BOM)

### BUG-276 旧库一次性修复迁移
- `Migrations/I18n/001_fix_bug276_seed_mojibake.up.sql`:
  - UPDATE Languages.NativeName: zh-CN→简体中文, zh-TW→繁體中文, ja-JP→日本語
  - UPDATE I18nTexts.zh-CN 8 条内置翻译 (确定/取消/保存/关闭/错误/警告/信息/确认) + IsVerified=1
  - 幂等 (带 `<>` 过滤), SQLite/PG 双方言兼容
- 旧库识别: 通过 `git show` 反查旧版 Schema.pas 字节, 确认坏种子为 "锟斤拷" 经典双转换特征

### 当前扫描基线 (2026-06-22)
- 硬违反: 0 (8 个已知 FMX 破坏文件已 allowlist)
- 软违反: 233 (183 个 .pas 缺 BOM, 50 个 .md 多 BOM) — 留作后续批量修复
- 扫描文件: 446

---

## 2026-06-22 EXP-P1-015 后续: JobQueue 指数退避 + 独立 DLQ 表 ✅

> 来源: BUG-302 待办 (PERS-003, 专家 C)
> 范围: `Persistence/DeepBase.DB.JobQueue.pas` + `Tests/Test.DeepBase.DB.JobQueue.pas` + `Migrations/JobQueue/*.sql`
> 测试: 新增 7 个回归, 单元总数 4007 → 4011 (3 ignored, 0 leaked, 0 failed)

### 指数退避
- `TJobQueue.Fail(..., Requeue=True)` 未达上限时按 `delay = min(BASE*2^(attempts-1), CAP)` 回退
  - `JOB_QUEUE_BACKOFF_BASE_SEC = 5`, `JOB_QUEUE_BACKOFF_CAP_SEC = 300` → 5s/10s/20s/40s/80s
- Schema: 主表 `DeepBase_job_queue` 新增 `next_run_at` 列 (TEXT/NULL for SQLite, TIMESTAMP WITH TIME ZONE/NULL for PG)
- `Dequeue{PostgreSQL,SQLite}` / `RecycleDeadTasks` 追加 `AND (next_run_at IS NULL OR next_run_at <= <now>)` 过滤

### 独立 DLQ 表
- 新建 `DeepBase_job_queue_dlq`, 主键 `original_id TEXT`
- 达上限时 `Fail(..., Requeue=True)` 原子地把行 `INSERT ... SELECT` 到 DLQ 并从主表 `DELETE` (SQLite 显式事务, PG 单连接串行)
- 新增只读/运维 API: `DeadLetterCount` / `PeekDeadLetters` / `ReplayDeadLetter` / `PurgeDeadLetter`
- 新增 `TDeadLetterRec` 记录 (含 `Clear` 不释放共享的 `Payload` 引用, 避免 double-free)

### 迁移脚本
- `Migrations/JobQueue/001_add_next_run_at.up.{sqlite,pg}.sql`
- `Migrations/JobQueue/002_create_dlq_table.up.{sqlite,pg}.sql`
- 脚本语义与 `EnsureSchemaOnConnection` 幂等 DDL 保持一致, 老部署也可不跑迁移直接由 `EnsureSchema` 升级

### 新增回归测试 (7 个)
- `Test_Dequeue_RespectsNextRunAt`
- `Test_Fail_SetsNextRunAt_ExponentialBackoff`
- `Test_Fail_ExceedsMaxRetries_TransfersToDLQ`
- `Test_DeadLetterCount_FiltersByQueue`
- `Test_PeekDeadLetters_RespectsLimitAndQueue`
- `Test_ReplayDeadLetter_MovesBackToMainPending`
- `Test_PurgeDeadLetter_RemovesRow`

---

## 2026-06-21 三专家全库模块审阅修复 (42 项)

> 审阅角色: 专家 A(Core 基础设施/并发)、专家 B(Core 业务/Features)、专家 C(Persistence/Payment/包边界)
> 审阅范围: Core(119 .pas)、Features(114 .pas)、Persistence(31 .pas)、ThirdParty/Payment(17 .pas)、包定义(.dpk)
> 发现总计: 42 项 (P0=5, P1=21, P2=16, 其中 1 项合并至同源任务 EXP-P1-013)
> 详细报告: `expert_a_findings.md` / `expert_b_findings.md` / `expert_c_findings.md`

### EXP-P0-001 ~ EXP-P0-005: Payment 安全 + 基础设施 ✅
- **EXP-P0-001** (PAY-ARCH-001): IPaymentClient GUID 重复 → `IPaymentCoreClient` + 新 GUID ✅
- **EXP-P0-002** (PAY-002): Alipay 金额 FormatFloat 区域设置 → 显式 en-US TFormatSettings (全量 3972/3972) ✅
- **EXP-P0-003** (PAY-001): Stripe 幂等键秒级精度 → TGUID.NewGuid.ToString (全量 3972/3972) ✅
- **EXP-P0-004** (INFRA-001): TCache LFU 未实现 → **误判**，EvictLFU 完整实现 ✅
- **EXP-P0-005** (INFRA-002): EventBus 白名单不一致 → 统一 IsValidEventType 验证路径 (3971/3975) ✅

### EXP-P1-001 ~ EXP-P1-018: 业务逻辑 + 基础设施 ✅
- **EXP-P1-001** (BIZ-007): LLM GetConfig 死锁 → **误判**，已正确实现先释放再刷新 ✅
- **EXP-P1-002** (BIZ-004): LLM ChatStream 退化同步 → doc-comment 说明降级，指引用 L3 SSE 真流式 ✅
- **EXP-P1-003** (BIZ-012): BillingClient ChatAsync 悬垂引用 → class 函数 + 局部快照，不再捕获 Self ✅
- **EXP-P1-004** (BIZ-006): SenseVoice PRO 许可证检查空 → 删除 Tier 1 死代码分支 ✅
- **EXP-P1-005** (BIZ-009): TranscribeFromMic 阻塞 5 秒 → 100ms 切片轮询 + 外部 StopRecording 提前退出 ✅
- **EXP-P1-006** (BIZ-002): SetCurrentUser 废弃保护 → raise 阻断 + LoginTestUser helper 迁移 ✅
- **EXP-P1-007** (BIZ-008): 审计日志 Username 空 → GetCurrentUserForThread 自动填充 ✅
- **EXP-P1-008** (BIZ-001): HealthCheck 泄露内部路径 → 只暴露 Exception.ClassName ✅
- **EXP-P1-009** (BIZ-003): i18n 语言代码不一致 → 默认 en-US + 英语地区变体别名 ✅
- **EXP-P1-010** (INFRA-003): EventBus finalization AV → Assigned 守卫 + FreeAndNil + GEventBusFinalized 标志 ✅
- **EXP-P1-011** (INFRA-004): Logger 初始化竞态 → 移除 CompareExchange，initialization 直接创建 ✅
- **EXP-P1-012** (INFRA-007): LogException 缺条件编译 → CompilerVersion >= 36.0 guard ✅
- **EXP-P1-013** (INFRA-005): Cache.OwnValues 无文档 → 三处 doc-comment 明确仅对 class 类型有效 ✅
- **EXP-P1-014** (PERS-001): DB.Pool Release 竞态 → SetEvent 移入 FLock 内原子化 ✅
- **EXP-P1-015** (PERS-003): JobQueue 重试风暴 → DEFAULT_JOB_MAX_RETRIES=5 + dead_letter 状态 ✅
- **EXP-P1-016** (PERS-002): StatusMachine schema.table → ValidateIdentifier 支持 schema.table 格式 ✅
- **EXP-P1-017** (PKG-001): Commerce.dpk 依赖不完整 → **误报**，Commerce 不依赖 FireDAC ✅
- **EXP-P1-018** (INFRA-006): IsWeekend 隐式映射 → DayOfTheWeekToDayOfWeekEx 命名类函数 ✅

### EXP-P2-001: LLM BillingClient 错误消息 i18n ✅
- 提取硬编码中文到 i18n 资源表 ✅

### QA-P0-001: 编译器警告清理完成 ✅
- 总体警告 470 → 0 (-100%)，跨 40+ 文件删除 670+ 行死代码
- H2164 (57→0), H2219 (41→7 误报), H2077 (78→42 误报)
- W1035/W1036/W1057/W1000/W1010/W1011/W1002/W1073/W1022/W1021/W1009 全部清零

---

## 2026-06-15 10 专家评估与 P0/P1 修复 (24 项)

### EVAL-FIX-2026-06-15: 10 专家全模块评估 + P0/P1 全部修复
- **完成日期**: 2026-06-15
- **来源**: 10 位专家对 DeepBase 200+ 单元的全模块评估
- **评分**: 综合 7.2/10
- **产出**: 12 P0 + 12 P1 = 24 项全部完成
- **验证**: 编译通过; 评估报告见 docs/evaluation/; 修复跟踪见 docs/evaluation/11-fix-task-tracker.md

---


---

## 2026-06-15 数据平台 v0.7 设计与实现（15 专家审查）

### DATA-PLATFORM-2026-06-15: Docs 32-36 外部数据访问与 UIA 自动化平台
- **完成日期**: 2026-06-15
- **审查**: 15 位专家（5×R1 安全/COM/加密/架构/Delphi + 5×R2 威胁/并发/容错/性能/模式 + 4×R3 集成/可测试/实现/演化 + 1×R4 集成心智编译）
- **评分演进**: v0.1(4.5/10) → v0.3(7.5/10) → v0.4(8.0/10) → 代码审计修至 v0.7
- **内容摘要**:
  - 32.SQLCipher 外部数据库读取：双后端 (FireDAC+BCryptDirect)、SafeQuery 自动审计、sqlite3_set_authorizer C层防线、结构化指纹
  - 33.SchemaAdapter 通用适配器：列式 MapRow (TArray<Variant>, 内存降 83%)、ForbiddenFields O(1)、WeChat39xAdapter（探针参数）
  - 34.UIA 自动化引擎：同步 SetValue (裁撤命令队列)、归属验证、JSON映射签名校验、IUIAElement 适配器
  - 35.剪贴板保护与窗口监控：RAII + SendInput+wScan + 多级降级、SetWinEventHook+health check+TThreadList
  - 36.Bootstrap 与 CompositionRoot：15 步启动/Shutdown 顺序、完整依赖注入
- **代码**: 12 新 Pas (~2,700 LOC) + 3 .dpk 修改 + 1 TLB 生成
- **Bugfix**: BUG-252~263 共 12 项审计修复 (bugfix.md)

### DATA-PLATFORM-2026-06-15-R2: P1 补全 + Core 编译门禁
- **完成日期**: 2026-06-15
- **来源**: 5 专家代码审计发现 14 项问题
- **内容摘要**:
  - 9 项 Runtime/Semantic 修复：UIA_ProcessIdPropertyId (30010)、GetNativeWindowHandle (30020)、GetCurrentProcessName (QueryFullProcessImageName)、CoInitializeEx lifecycle、GetTimestamp → TDateTime、FSchemaFingerprintPrefixes 赋值、MapDirection/MapMessageType 懒加载缓存、SqlcipherVersion 赋值、PollThreadProc 空闲槽填充回调
  - 3 项 .dpk 注册修复：DeepBaseCore contains (6 new units)、UIAutomationClient_TLB + requires vcl、Features requires DeepBasePersistence
  - 7 项缺失实现补全：TUIAMappingRegistry.Add/TryGetValue、GetOriginalContent 去存根、CheckHookHealth 定时器、ParseUIAMappingJSON、Invoke 发送按钮黑名单、LoadMappingsFromConfig 注册映射、SchemaAdapter 类型声明链修正
  - DeepBaseCore.dpk 0 errors 编译验证通过
- **文件**: 12 个修改文件 + bugfix.md 更新

---

## 2026-05-23 Commerce 客户端 SDK 安全审计修复

### AUDIT-P0-2026-05-19: Commerce 客户端 SDK 代码审计修复
- **完成日期**: 2026-05-19
- **来源**: 2026-05-19 对 Commerce 客户端全部模块的代码审计
- **目标**: 修复审计发现的内存泄漏、Token 刷新、命名混淆和平台限制等问题
- **内容摘要**:
  - P0-1: SDKGateway 四个工厂函数 Config 内存泄漏
  - P0-2: PaymentBridge 三个验证器工厂 Config 内存泄漏
  - P1-1: SafeClient 缺少自动 Token 刷新机制
  - P1-2: SafeClient.AuthLogout 空 body 语义
  - P1-3: License Snapshot 验证非 Windows ��台
  - P1-4: WeChat Pay 验证 fail-closed
  - P2-1: OrderFromJson 重名
  - P2-3: UpgradeFlow.StartPaidUpgrade 订单状态验证
  - P2-4: Permissions RemainingQuota -1=unlimited
  - P2-5: Backend.Http TLS 证书校验
- **遗留**: P2-2 Types.pas 字段常量导出过于宽泛（暂不处理）

### AUDIT-P0-2026-05-23: Commerce 客户端安全深度审计修复
- **完成日期**: 2026-05-23
- **来源**: 2026-05-23 对 Commerce/License/Authorization/Persistence 全部认证与付费模块的安全审计
- **目标**: 修复 5 Critical + 6 High + 5 Medium 共 16 个安全问题
- **内容摘要**:
  - C1: License 签名 SHA256->HMAC-SHA256 (DeepBase.License.pas)
  - C2: Authorization FCurrentUser 竞态 (DeepBase.Authorization.pas)
  - C5: Firebase 权益消费竞态 (Commerce.Adapter.Firebase.pas)
  - C6: Supabase 权益消费损坏 (Commerce.Adapter.Supabase.pas)
  - C7: PaymentBridge env-var 绕过 (Commerce.PaymentBridge.pas)
  - C8: 许可证明文存储->DPAPI (Persistence.License.FireDAC.pas)
  - H5: 非活动用户绕过 (DeepBase.Authorization.pas)
  - H6: 删角色后权限孤立 (DeepBase.Authorization.pas)
  - H7: 分配非活动角色 (DeepBase.Authorization.pas)
  - H8: 支付确认竞态 (Commerce.Service.pas)
  - H9: BeginPayment 竞态 (Commerce.Service.pas)
  - H12: 许可证存储线程安全 (Persistence.License.FireDAC.pas)
  - M5: HTTP 错误体泄露 (Commerce.SafeClient.pas)
  - M6: 适配器缺失字段 (Firebase + Supabase)
  - M8: Assert 生产环境 (Commerce.SafeClient.pas)
  - M10: 状态信息泄露 (VCL.LicenseAuthDialog.pas)
  - M11: 对话框重入 (VCL.LicenseAuthDialog.pas)
  - 新增辅助函数: StrToCommercePaymentProvider 等 (Commerce.Types.pas)
  - TOCTOU 修复: AssignUserRole 事务级一致性 (Persistence.Authorization.FireDAC.pas)
- **验证**: 修改文件编译通过
- **归档**: BUG-220 ~ BUG-235 已记录到 bugfix.md

---

## 2026-05-14 IntentClarification Phase 2 编译接入修复

### IC-P0-2026-05-14A: 编译链、IoC 和最小集成测试恢复
- **完成日期**: 2026-05-14
- **内容摘要**:
  - IntentClarification Phase 2 单元已进入 `DeepBaseFeatures.dpk/.dproj` 和 `Tests/DeepBaseTests.dpr/.dproj` 主编译链。
  - 核心类型契约和 `DeepBase.IntentClarification.Registration.pas` 首轮补齐，解决 Phase 2 单元无法进入包/测试工程的问题。
  - IoC provider 注册改为显式 interface instance，避免 `TL1SlotProvider(AClarifier)` optional constructor 被 RTTI 容器误解析。
  - L2-L4 provider 已进入 IoC named registration；Engine 未配置 LLM 时跳过 LLM provider，保证最小下游接入路径不产生 `PROVIDER_ERROR`。
  - `HandleExit` 增加异常兜底和 session 写回锁，输入 `0` 的最小退出路径通过集成测试。
  - 为主测试编译链顺带修复 Browser CDP/Vision/ScriptStore 编译阻塞，详见 `bugfix.md` 的 BUG-164、BUG-165。
- **验证**:
  - `cmd /c compile_test.bat`：`compile_output.txt` 为 `Exit code: 0`。
  - `Tests\DeepBaseTests.exe -b -r:Test.DeepBase.IntentClarification,TICIntegrationTest,TICResilienceIntegrationTest,TICSessionFSMTest`：20 tests passed，0 failed，0 errored，0 leaked。
  - `Tests\DeepBaseTests.exe -b -r:Test.DeepBase.Browser.ScriptStore.TJSTemplateTests,Test.DeepBase.Browser.ScriptStore.TBuiltinDefaultsTests`：20 tests passed，0 failed，0 errored，0 leaked。
  - 完整 `Tests\DeepBaseTests.exe` 当前为 3372 found，3351 passed，3 ignored，6 failed，12 errored；失败集中在 Browser Registry/WindowPool/Automation、FeatureFlags rollout、License legacy signing、DB.DoQry DDL gate 和 Performance benchmark，未在本轮收敛。
- **遗留**:
  - 公开 `DeepBase.IntentClarification.pas` 里的 `IClarificationEngine` facade 仍为空，`CreateEngine/CreateEngineWithPreset` 仍未对齐真实 `Interfaces/Engine`。
  - `IDomainAdapter.GetPresetSlots` 尚未接入 Engine/L1；Engine session 并发、Provider session-scoped state、Router 边界、LLMResilience timeout/ErrorMessage、L4 全失败语义继续保留在 `tasks.md`。

---

## 2026-05-14 DeepShell VCL 桌面壳骨架完成

### DESKTOP-2026-05-14: DeepShell 第一版 15 单元 + Demo 项目
- **完成日期**: 2026-05-14
- **目标**: 按 docs/70-78 号 DeepShell 设计契约落地可继承的 VCL 桌面壳骨架。下游 VCL 桌面工具从 `TDeepMainForm` 起步，不再每个软件重复搭工具栏、日志、设置、MRU、布局。
- **产出**:
  - 15 个核心单元（runtime 全部进 `DeepBaseVCL.dpk`）：
    - `VCL/DeepBase.VCL.DeepShell.Types.pas`：record / 枚举 / helpers，纯 RTL 依赖。
    - `VCL/DeepBase.VCL.DeepShell.Intf.pas`：所有接口契约 + capability/command 字符串常量。
    - `VCL/DeepBase.VCL.DeepShell.Events.pas`：UI-safe EventBus（主线程同步分发，后台线程 `TThread.Queue` 投递）。
    - `VCL/DeepBase.VCL.DeepShell.Services.pas`：`TShellServiceRegistry`。
    - `VCL/DeepBase.VCL.DeepShell.Context.pas`：`TShellContextManager`，按变更递增 Revision。
    - `VCL/DeepBase.VCL.DeepShell.Commands.pas`：`TShellCommandManager` + 流式 `ShellCommand(...)` builder + `class operator Implicit`。
    - `VCL/DeepBase.VCL.DeepShell.Recent.pas`：`TShellInMemoryRecentService`（按 ItemKey upsert，按时间排序）。
    - `VCL/DeepBase.VCL.DeepShell.Layout.pas`：内存 + Settings-store backed layout service（JSON 持久化）。
    - `VCL/DeepBase.VCL.DeepShell.Theme.pas`：默认 Theme service（仅状态跟踪，不直绑 Vcl.Themes）。
    - `VCL/DeepBase.VCL.DeepShell.Localization.pas`：默认 i18n service（locale → key → text 字典，TObjectDictionary 自释放）。
    - `VCL/DeepBase.VCL.DeepShell.Settings.pas`：`TShellInMemorySettingsStore` + `TDeepShellSettingsForm`（OK/Apply/Cancel/Restore Defaults，Provider 异常隔离）。
    - `VCL/DeepBase.VCL.DeepShell.Panels.pas`：`TShellAreaController` 三段折叠控制 + `TShellStatusManager`。
    - `VCL/DeepBase.VCL.DeepShell.ToolWindow.pas`：原生 TForm 实现的左右悬浮工具窗，不引入 Docking 框架。
    - `VCL/DeepBase.VCL.DeepShell.MainForm.pas`：`TDeepMainForm`，10 个虚生命周期方法 + 内置命令 + 主视图 dispatch。
    - `VCL/DeepBase.VCL.DeepShell.pas`：facade 单元，下游一行 uses 即可。
  - Demo 项目 `Examples/VCLDeepShellDemo/`：`VCLDeepShellDemo.dpr` + `Demo.MainForm.pas` + `Demo.Services.pas` + `Demo.Commands.pas` + `Demo.Providers.pas` + README。Demo 不依赖 DB1/doQry/LLM/WebView2/Governance，全用 fake provider/service。
  - `DeepBaseVCL.dpk` contains 列表追加全部 15 个新单元。
- **关键设计决策**:
  - Shell 核心不持有业务 `TObject`，统一用 `TShellObjectRef = record { Id, Kind, ProviderId, DisplayName }` 引用；下游 Provider 按 (ProviderId, Id) 找业务对象。
  - Command 以 record + `Handler: TProc` 存储；fluent builder 通过 `class operator Implicit` 直接转 record，下游可写 `RegisterCommand(ShellCommand('id', 'Caption').Category('File').OnExecute(...))`。
  - EventBus 线程模型：主线程 publish 同步分发；后台线程 publish 通过 `TThread.Queue` 投递到主线程，handler 异常被 catch 不影响其他订阅者。
  - 治理：Command 字段预留 `GateKey/RiskLevel/PurposeKey/RequiresEvidence`，`IShellCommandManager.SetGovernance` 在 MVP 默认接 `NullGovernanceService`，第二阶段切 OCGS adapter。
  - 渲染边界：`svkHtml/svkMarkdown` 必须由下游 provider 通过 `CreateViewControl` 自带控件渲染，Shell 核心不依赖 WebView2/CEF/Markdown 库。
  - 多实例：每个主窗体实例生成 `InstanceId(GUID)`，layout 写入带 `WriterInstanceId`，全局 layout 用 last-write-wins。
- **验证**:
  - 独立 `dcc32 _tmp_deepshell_compile.dpr` 编译：4452 行，0.39 秒，0 errors，0 warnings。
  - `DeepBaseVCL.dproj` Win64 编译：DeepShell 全部 15 单元干净通过。整包剩余 fail 来自仓库已有的 `Features\DeepBase.IntentClarification.SignalDetector.pas` (BUG-143)，与本工作无关。
  - `Examples/VCLDeepShellDemo/` 全部单元独立编译通过。
- **遗留**:
  - 整包 `DeepBaseVCL.dpk` 完整构建依赖 `IntentClarification` Phase 2 的修复，跟踪在 `IC-P0-2026-05-14`。
  - 第一版完成后五专家审阅发现的剩余 P1/P2 改进项见 `tasks.md` 的 `DESKTOP-P1-2026-05-14`。
- **归档**:
  - 第一版骨架与 6 个实现期 bug 修复（BUG-144 ~ BUG-149）和 5 个审阅 P0 修复（BUG-150 ~ BUG-154）已记录到 `bugfix.md`。

---

## 2026-05-14 IntentClarification 审阅与任务归档

### IC-AUDIT-2026-05-14: IntentClarification Phase 2 五专家审阅
- **完成日期**: 2026-05-14
- **内容摘要**:
  - 完成 `DeepBase.IntentClarification` 下游接入指南和 Phase 2 实码审阅。
  - 从 5 个视角完成只读审阅：接口契约/API、Engine/Session 并发、Provider/LLM 行为、IoC/配置/持久化/指标、测试/构建/包集成。
  - 确认当前模块主要风险不是单点逻辑缺陷，而是新单元未纳入包/主测试、公开 facade 仍为空、类型契约不一致、Registration 半截实现、Provider 状态跨会话和 Engine 并发写回等 P0 阻塞。
  - 已将后续修复整理为 `tasks.md` 的 `IC-P0-2026-05-14`。
  - 已将本轮发现缺陷登记到 `bugfix.md` 的 BUG-134 ~ BUG-143，状态均为待修复。
- **验证**:
  - `cmd /c compile_test.bat` 当前仍可通过，但只覆盖旧 facade，不覆盖 Phase 2 新单元；此结论已写入后续 QA 任务。

### ARCH-P0-001: deepBase 改名收尾与包编译门禁
- **完成日期**: 2026-05-13
- **内容摘要**:
  - 修复 `Scripts/build_packages_win64.ps1` 和 `Scripts/compile_packages_win64.ps1`，改为构建 `DeepBase*.dpk`。
  - 修复 `DeepBase*.dpk` 内部 package 名、requires 和 contains 的命名残留。
  - 发布门禁在 `VCL/` 源码目录缺失时排除 VCL 包和 VCL 必需示例，后续已恢复 VCL 源码目录并补齐 `DeepBase.VCL.*.dfm` 资源。
  - `Minimal`、`Runtime`、`All` Win64 package gate 已通过。
  - 修复 `Scripts/compile_packages_win64.ps1` 误报逻辑，改为基于退出码和真实 `Error:/Fatal:` 行判定。
  - 新增 `Scripts/check_rename_residue.ps1` 并接入包门禁，真实旧名残留命中即失败。
- **归档说明**:
  - 该项已从 `tasks.md` 的 P0 当前开发中移除；后续包门禁可信化继续由 `QA-P0-001` 和 `IC-P0-2026-05-14` 跟踪。

---

## 2026-05-07 Speech/ASR 基础模块归档 �?
### SPEECH-001: DeepInput 语音识别链路抽取�?DeepBase 基础模块 �?- **完成日期**: 2026-05-07
- **内容摘要**:
  - �?`D:\_Progs\02Business\DeepInput` 阅读并抽取语音识别核心链路：WaveIn 录音、RMS VAD、百度在�?ASR、录�?识别编排�?  - 新增 `Features/DeepBase.Speech.Types.pas`：统一音频格式、识别结果、错误状态、`ISpeechRecognizer`、`ISpeechAudioCapture`�?  - 新增 `Features/DeepBase.Speech.Audio.WinMM.pas`：Windows WaveIn 录音实现，输�?16kHz/16-bit/mono PCM�?  - 新增 `Features/DeepBase.Speech.VAD.pas`：基�?RMS 能量的静音自动停止检测�?  - 新增 `Features/DeepBase.Speech.ASR.Baidu.pas`：百度语�?REST API Provider，支�?token 缓存、错误映射和可注�?HTTP transport�?  - 新增 `Features/DeepBase.Speech.Service.pas`：封装录音、VAD、ASR Provider 的通用编排�?  - `DeepBaseFeatures.dpk` �?`Tests/DeepBaseTests.*` 已纳�?Speech 单元�?  - 下游文档已补�?`DeepBase.Speech.*` 接入说明；密钥继续要求走 `DeepBase.Security`�?- **边界**:
  - 未迁�?DeepInput 的虚拟键盘、浮动条、托盘、全局热键、文本注�?UI 状态机�?  - DeepInput 本地 Whisper 当前是旧兼容回退路径，未作为 DeepBase 基础 Provider 封装�?- **验证**:
  - `Scripts/run_tests.ps1 -Type Unit -Run Test.DeepBase.Speech`�?/5 passed�?  - `Scripts/build_packages_win64.ps1 -Profile Runtime`：通过�?
---

## 2026-05-05 架构整理与封板前优化归档 �?
### ARCH-019 / ARCH-039: Core �?Persistence 分层收敛 �?- **完成日期**: 2026-05-05
- **内容摘要**:
  - `Core/` 已移�?`FireDAC.*` / `TFD*` / `EFD*` 直接类型依赖，Core 运行包不再要�?FireDAC�?  - 引入 `DeepBase.Storage.Interfaces.pas`，统一 `IConfigStorage`、`IFormStateStorage`、`IMRUStorage`、`IHotkeyStorage`、`IThemeStorage`、`II18nStorage`、`ILogStorage`、`IManagerStorage`、`ILLMStorage`、`IORMStorage` 等抽象�?  - FireDAC 实现下沉�?`Persistence/DeepBase.Persistence.*.FireDAC.pas`，通过 initialization 自动注册工厂�?  - `Manager/Config/FormState/MRU/Hotkeys/Theme/i18n/Security/License/Authorization/Exception/Diagnose/Logging/LLM/ORM/TestHelper` 已完成主要存储注入切片�?  - `Scripts/run_tests.ps1` 增加模块化测试入口：`-Module`、`-FromUnit`、`-FromGitChanged`�?- **验证**:
  - `Scripts/run_tests.ps1 -Type Unit -Platform Win64 -CI`
  - `Scripts/run_tests.ps1 -Type All -Platform Win64 -CI`
  - `Scripts/build_packages_win64.ps1 -Profile Runtime`

### ARCH-027 / ARCH-044: Core 目录和包边界整理 �?- **完成日期**: 2026-05-05
- **内容摘要**:
  - `Core` 中与 UI、Features、Persistence 强相关的实现完成迁移或边界收敛�?  - `DeepBaseCore.dpk`、`DeepBaseServices.dpk`、`DeepBasePersistence.dpk`、`DeepBaseFeatures.dpk`、`DeepBaseVCL.dpk`、`DeepBaseFMX.dpk` 已按当前分层重新对齐�?  - `Theme/Exception/Hotkeys/Plugin` 等模块去�?Core �?VCL/FMX 的直接绑定，由平台包提供适配器�?  - `Profile All` 包门禁已覆盖 VCL/FMX 包，并检查源目录 `.dcu` 泄漏�?
### FEATURE-001: 统一用户/订单/支付/权益 Commerce MVP �?- **完成日期**: 2026-05-05
- **内容摘要**:
  - 新增 `Features/DeepBase.Commerce.Types.pas`：统一用户、身份、商品、订单、支付、权益数据结构�?  - 新增 `Features/DeepBase.Commerce.Storage.pas`：定�?`ICommerceStorage`，提�?`TInMemoryCommerceStorage` 用于开发和测试�?  - 新增 `Features/DeepBase.Commerce.Service.pas`：实�?`EnsureUserForIdentity`、`CreateOrder`、`BeginPayment`、`ConfirmPayment`、`HasEntitlement`、`ConsumeEntitlement` 主流程�?  - 新增 `ICommercePaymentGateway`，为微信支付、CloudBase、自建后端等真实网关预留适配点�?  - 新增 `Tests/Test.DeepBase.Commerce.pas`，覆盖用户绑定、订单、支付意图、回调确认、权益幂等发放、金额不匹配拒绝和消费型权益扣减�?- **验证**:
  - `Scripts/run_tests.ps1 -Type Unit -Platform Win64 -CI -Run "Test.DeepBase.Commerce"`�?/7 passed�?  - `Scripts/build_packages_win64.ps1 -Profile All`：通过�?
### COMMERCE-002A-D: Commerce 后端契约�?HTTP 后端适配�?�?- **完成日期**: 2026-05-05
- **内容摘要**:
  - 新增 `docs/Commerce-Backend-Adapter-Spec.md`，固化后端数据表、HTTP API、幂等、安全边界和实施顺序�?  - 新增 `Features/DeepBase.Commerce.Backend.Contract.pas`，统一后端路由�?snake_case JSON 字段常量�?  - 新增 `Features/DeepBase.Commerce.Backend.Http.pas`，提�?`TCommerceHttpStorage` 作为生产 `ICommerceStorage` HTTP 后端适配器�?  - `TCommerceHttpStorage` 支持 `BaseUrl`、Bearer token、API key、超时配置，并通过 `ICommerceBackendHttpTransport` 支持单元测试注入�?  - 新增 `TCommerceHttpPaymentGateway`，作为生�?`ICommercePaymentGateway` 后端代理适配器，统一调用 `POST /commerce/payments/intents` 并使�?`Idempotency-Key` 防重试冲突�?  - 更新下游集成文档，生产路线从“自行实�?ICommerceStorage”收敛为“优先接入统一后端 HTTP API”�?- **验证**:
  - `Scripts/run_tests.ps1 -Type Unit -Platform Win64 -CI -Run "Test.DeepBase.Commerce"`�?3/13 passed�?
### ARCH-029 / ARCH-030 / CLEANUP-005 / CLEANUP-006: 旧商业化路线与文档清�?�?- **完成日期**: 2026-05-05
- **内容摘要**:
  - 删除未使用的 AiPEX/AipexBase、旧后端认证/计费客户端、旧认证/计费 UI 组件和演示工程�?  - 删除过期 API/集成文档，不再保留误�?AI 的历史入口�?  - `ThirdParty/Payment` 明确定位为渠�?SDK 能力；统一用户、订单、支付、权益流程由 `Features/DeepBase.Commerce.*` 承接�?  - `docs/integrations` 已扁平化�?`docs/`，空目录删除，相关链接修正�?  - 新增 `docs/DeepBase-Downstream-Integration.md` 作为下游最干净的集成入口�?
### LLM-001 ~ LLM-004: Delphi LLM 客户端、安全存储与聊天组件 �?- **完成日期**: 2025-12-14
- **内容摘要**:
  - `Core/DeepBase.LLM.BillingClient.pas` 提供轻量 AI 质价管家客户端，支持流式/非流式、重试、取消、异步调用和对话历史�?  - `Core/DeepBase.Security.DPAPI.pas` 提供 DPAPI、Credential Manager �?`TSecureString`�?  - `VCL/DeepBase.VCL.LLMChatFrame.pas`、`FMX/DeepBase.FMX.LLMChatFrame.pas` 提供可复用聊�?Frame�?  - `Tests/Test.DeepBase.LLM.BillingClient.pas` �?`Tests/Test.DeepBase.Security.DPAPI.pas` 覆盖核心行为�?
### BUG-098: FormState 多显示器坐标恢复修复 �?- **完成日期**: 2026-05-05
- **内容摘要**:
  - `Core/DeepBase.FormState.pas` 恢复窗口时按当前显示器工作区夹回坐标，避免旧多屏坐标导致窗口不可见�?  - `VCL/DeepBase.VCL.FormStateHelper.pas` 保存路径补齐 `GetWindowPlacement` 工作区坐标到屏幕坐标转换�?  - 详细修复记录�?`bugfix.md`�?- **验证**:
  - `Scripts/run_tests.ps1 -Type Unit -Platform Win64 -CI -Run "Test.DeepBase.FormState"`�?3/13 passed�?  - `Scripts/build_packages_win64.ps1 -Profile All`：通过�?
---

## 2026-05-02 持续优化迭代 �?
### MAINT-002-A: 单元测试稳定性清零（Win64 基线）✅
- **完成日期**: 2026-05-02
- **输出�?*:
  - �?`Scripts/run_tests.ps1` 新增 `-Platform` 参数（`Win32|Win64`），默认改为 `Win64`
  - �?Win64 单元测试全绿：`Tests Found 824 / Ignored 4 / Passed 820 / Failed 0 / Errored 0 / Leaked 0`
  - �?修复 Win64 �?`Test.DeepBase.Resilience` 泛型断言类型推断问题（显�?`Assert.AreEqual<Integer>`�?
### MAINT-002-B: FormState 坐标持久化修正（顶部任务栏场景）�?- **完成日期**: 2026-05-02
- **输出�?*:
  - �?`Core/DeepBase.FormState.pas`：`GetWindowPlacement.rcNormalPosition` 工作区坐标转换为屏幕坐标后再持久�?  - �?`Tests/Test.DeepBase.FormState.pas`：测试窗体默认放置到左下工作区，降低测试过程误击风险

### MAINT-002-C: Resilience 执行链闭包泄漏修�?�?- **完成日期**: 2026-05-02
- **输出�?*:
  - �?`Core/DeepBase.Resilience.pas`：重�?`TResiliencePolicy.Execute` / `Execute<T>` 闭包链，显式释放捕获引用
  - �?清除 FastMM 末尾 `TResiliencePolicy.Execute` 相关小块泄漏告警

### MAINT-002-D: 异常语义与测试断言对齐 �?- **完成日期**: 2026-05-02
- **输出�?*:
  - �?`Tests/Test.DeepBase.Protection.pas`：文件不存在断言改为 `EFileNotFoundExceptionEx`
  - �?`Tests/Test.DeepBase.Resilience.pas`：断路器打开断言改为 `ECircuitBreakerException`

### MAINT-002-E: 构建产物清理 �?- **完成日期**: 2026-05-02
- **输出�?*:
  - �?已清理仓库内 `.dcu` 文件 65 个（满足“源库不保留 dcu”要求）

### MAINT-002-F: Win64 集成测试链路打�?�?- **完成日期**: 2026-05-02
- **输出�?*:
  - �?`Tools/WebService/DeepBase.WebAPI.Core.pas`：TLS 版本枚举兼容 Indy 版本差异（`sslvTLSv1_3` 可选）
  - �?`Core/DeepBase.Net.pas`：修复静态方法调用限定，补齐 `TIPUtils.IsLinkLocalIP`
  - �?`Core/DeepBase.Net.pas`：新增本�?内网 URL 安全开关（环境变量�?  - �?`Scripts/run_tests.ps1`：集成测试自动准备位宽匹�?`sqlite3.dll` 并启�?localhost 白名�?  - �?Win64 Integration 全绿�?/9 通过

### MAINT-002-G: 全量 Win64 门禁通过 �?- **完成日期**: 2026-05-02
- **输出�?*:
  - �?`.\Scripts\run_tests.ps1 -Type All -CI` 执行通过（Unit + Integration�?  - �?最终清�?`.dcu` 与临时集成依赖文件，仓库保持可提交状�?
### MAINT-002-H: DB.Factory 双共享模式补齐（SQLite / PostgreSQL）✅
- **完成日期**: 2026-05-02
- **输出�?*:
  - �?`Persistence/DeepBase.DB.Factory.pas`：`LoadSharedProfile` 支持 `DB3.Type=SQLite`（保�?`PostgreSQL/PG` 兼容�?  - �?SQLite 共享库路径支持相�?`RootPath` 解析（`DB3.Database`，兼�?`DB3.Path`�?  - �?支持 `DB3.SQLiteLockingMode/SQLiteSynchronous/SQLiteJournalMode/SQLiteOpenMode/ExtraParams` 配置透传
  - �?新增单测 `Test_CreateSharedUnopenedConnection_FromLocalSettings_SQLite`
  - �?更新当时的快速集成文档（补充 `DB3.Type=SQLite` 配置键；当前入口�?`docs/DeepBase-Downstream-Integration.md`�?  - �?更新文档索引 `docs/00.00.DeepBase-文档索引-v1.0.md`（快速入口优先指向新集成指南�?
---

---

## 2026-07-09 REVIEW5-R3 续修归档 (E-006 ~ C-007 + 闭环声明)

  - REVIEW5-R3-E-006 (FEAT-R3-006, BUG-425): `Features/DeepBase.CloudBackup.pas` 传输层安全增强 (P1 归并). 见 bugfix.md BUG-425.
  - REVIEW5-R3-E-007 (FEAT-R3-007, BUG-426): `Features/DeepBase.AntiTamper.pas` GetDefaultConfig 固定 salt 改为空盐+Initialize 校验 (默认空盐必抛 EAntiTamperException, 配置 Salt 后成功). 见 bugfix.md BUG-426.
  - REVIEW5-R3-E-008 (FEAT-R3-008, BUG-427): `Features/DeepBase.Speech.TTS.StepFun.pas` FetchSystemVoices/FetchClonedVoices `nil as TJSONArray` 触发 EInvalidCast (as 对 nil 强转抛异常, if=nil 为死代码) — 改 `is` 判定 (对 nil 返回 False) + 硬转换 TJSONArray(VoicesVal), 缺键/非数组优雅 Exit 并设 FLastError. 见 bugfix.md BUG-427.
  - REVIEW5-R3-E-005 (FEAT-R3-005, BUG-428): `Features/DeepBase.Commerce.SafeClient.pas` SendJson 仅 401 重试, 429/5xx 瞬态失败直接抛 EDeepBaseCommerceError, 支付/订单接口短暂限流/后端重启窗口下立即失败无退避 — SendJson 末尾新增瞬态退避重试循环 (仅幂等调用: GET/HEAD 天然幂等, POST/PUT/DELETE 仅带 idempotency key 才重试, 防非幂等 POST 重复下单); IsRetriableStatus (429+5xx) / IsIdempotentCall / ExtractRetryAfterMs (429 优先读 Retry-After 头秒数→ms 钳制到 BACKOFF_CAP_MS) / ComputeBackoffMs (5xx 指数退避 BACKOFF_BASE_MS*2^attempt 钳制上限) 四辅助方法; 基于 attempt 的确定性 ±25% 抖动 (不用 Now/Random); Winapi.Windows.Sleep (MSWINDOWS 保护). implementation uses 增 System.Math (全限定 System.Math.Min 钳制, 仓库惯例). 新增 2 回归测试: 429 幂等 GET Retry-After:0 重试成功 RequestCount=2; 非幂等 POST 503 不重试 RequestCount=1 防重复. DUnitX --run 全名过滤单独执行 2 found 2 passed. 全量套件 2 既有失败 (WeChatPay 公钥环境 + Test_PermissionClient_HasFeature 测试数据 valid_until=2026-07-08 已于今日 07-09 过期) 与 E-005 无关. 见 bugfix.md BUG-428.
  - REVIEW5-R3-D-007 (GOV-R3-007, BUG-429): `DeepFlow/Source/Roles/DeepFlow.Commander.pas` GetOrCreateSession 锁内返回 TSession 裸指针后释放锁, ProcessRequest 锁外修改 Session.State/FTurnCount(Inc) 致同 session-id 并发数据竞争 (Inc 非原子, State 读改写撕裂) — ProcessRequest 中 State/FTurnCount 读写 + Context/SessionId 快照取值全部包裹 FSessionLock 临界区 (内联 var 局部快照, AnalyzeIntent 耗时 LLM 锁外执行避免序列化); 成功 ssPending 与 except ssError 各自锁内更新. Commander 停止 Clear 悬空裸指针属更深所有权问题超出 D-007 范围. 验证: Win64 全量编译通过 (exit 0 仅遗留 H2077/H2443 Hint); Commander 无专属单测, 纯加锁语义等价. 见 bugfix.md BUG-429.
  - REVIEW5-R3-D-008 (GOV-R3-008, BUG-430): `Governance/DeepBase.Governance.AI.ProposalQueue.pas` Submit 无容量上限致 AI 循环提交无限堆积 TProposal OOM, FindById/GetPending O(n) 膨胀后卡顿; 全程无锁, 引入后台 AI 提案将升 P1 — 加 FMaxPending (默认 1000, 满抛 EProposalQueueError 新异常类, 遵循 Governance EConfigRegistrarError/EJsonLogicError 惯例) + TCriticalSection 保护 Submit/Approve/Reject/Apply/FindById/GetPending/GetAll/Count 全部方法; FindById 拆 FindByIdInternal 避免不可重入 TCriticalSection 自死锁; Apply 锁内创建 ChangeSet+MarkApplied (ModelVersion 无反向锁依赖). P2 全 22 项修完. 验证: Win64 全量编译 SUCCESS exit 0 (325043 lines 16.56s 无 Error); ProposalQueue 无外部调用点/无单测, 纯加固语义等价. 见 bugfix.md BUG-430.
  - REVIEW5-R3-C-001 (DATA-R3-001 / BUG-431): `Persistence/DeepBase.DB.Pool.pas` TPooledConnection.Release 归还连接前不回滚残留事务/不关闭游标, 下个借用者继承脏连接 (SQLite "cannot start a transaction within a transaction"; PG/MySQL 读到中间数据甚至连带提交他人 DML); 隔离级别泄漏 — 新增 ResetConnectionState (private), Release 持 FLock 前先回滚残留未提交事务 (不 Commit, 异常路径遗留=未完成工作) + 重置 TxOptions.AutoCommit 到池配置; 复位失败仅记事件不阻断归还 (IsValid 探活兜底, 避免连接卡 csInUse 泄漏); 残留游标属调用方 dataset 生命周期, 池不接管 (FireDAC 设计一致). **C 模块首项���复, 更正此前"C已在前轮归档"误标: C 有 7 项 R3 新发现.** 验证: Win64 全量编译 SUCCESS exit 0 (325082 lines 17.06s 无 Error). 见 bugfix.md BUG-431.
  - REVIEW5-R3-C-002 (DATA-R3-002 / BUG-432): `doQry/doQryMain.pas` btnFilterClick (L151) 过滤条件字符串拼接 `tblQueries.Filter := 'proc_name LIKE ''%' + s + '%'''` 致过滤表达式注入 (TDataSet.Filter 按表达式语法解析, 可注入 `%' OR 1=1 OR proc_name LIKE '%` 绕过过滤或未闭合引号致异常 DoS/枚举) — 改 `tblQueries.Filter := 'proc_name LIKE ' + QuotedStr('%' + s + '%')`, QuotedStr 将内嵌单引号翻倍锁进字面量. System.SysUtils 已在 uses (L6). 验证: doQry 工程在 BDS37 因 uDoQryLegacy L8 `DBClient` 已移除无法整体编译 (历史遗留, 非本修复引入), 修复为纯标准 API QuotedStr, uses 齐备语法确定正确; doQry 不在 CI 单测工程集无回归触发. 见 bugfix.md BUG-432.
  - REVIEW5-R3-C-003 (DATA-R3-003 / BUG-433): `doQry/doQryMain.pas` (a) GetFieldList (L305) Format 拼接 TableName 到 information_schema 查询, (b) btnGenSqlClick (L126) 拼接数据库字段 proc_name — 两处均改 ADO 参数化 `WHERE table_name = :t`/`WHERE proc_name = :p` + `Parameters.ParamByName(...).Value := ...`; aQry 为 TADOQuery (L27), Data.Win.ADODB 已在 uses (L12), 驱动转义消除注入面. L286 硬编码 'public' 无拼接、L178 VALUES 全字面量, 无注入风险未改. 验证: 同 BUG-432 (doQry DBClient 历史遗留无法整体编译; 修复为 TADOQuery.Parameters.ParamByName 标准 API, uses 齐备); doQry 不在 CI 单测工程集无回归触发. 见 bugfix.md BUG-433.
  - REVIEW5-R3-C-004 (DATA-R3-004 / BUG-434): `Persistence/DeepBase.Persistence.Diagnose.FireDAC.pas` CheckForeignKeys (L460)/CheckRequiredFields (L517)/CheckEnumValues (L579) 三处 except 经 `OutputDebugString` 吞查询异常 — 查询失败时方法返回空数组, `DiagnoseAll` 聚合后 `GenerateDiagnoseReport` 报 `[OK] No issues found` "假绿" (green-on-error), 管理员误信 DB 健康, 实际故障埋进 DebugView (生产通常无人看). 修复: `Core/DeepBase.Diagnose.pas` `TDiagnoseIssueType` 枚举末尾新增 `ditCheckError` (序数 8, 兼容已有 0..7, GenerateDiagnoseReport 按 CanAutoFix/FixSQL 分类不 case IssueType 故无 case 穷举点需补); 三 except 块改为构造 `ditCheckError`+`IsOK:=False` 的 TDiagnoseResult 追加 ResultList, Issue 填 '检查失败: '+E.Message, TableName/ObjectName 填当前迭代上下文 (FK/RF/EF 的 TableName/ColumnName, 变量在 except 处 in-scope), CanAutoFix:=False; AddColumnIfNotExists/AutoFix 的 except 保留 (返回值 Boolean/Integer 已部分表达失败, 不属假绿语义, 改动涉签名变更超 DATA-R3-004 范围). 验证: Win64 全量编译 SUCCESS exit 0 (325119 lines 17.05s 无 Error); Diagnose 单元 DUnitX 回归 `-FromUnit DeepBase.Diagnose -AllowFilteredCI` 全过 (Tests Found 40 / Passed 40 / Failed 0), 含新增 `Ord(ditCheckError)=8` 序数断言 (Test_IssueType_Values); 全量测试运行有既有 Runtime 216 于非 Diagnose 测试 (仓库 R3 多文件修复进行中, 与本次改动无关).  - REVIEW5-R3-C-005 (DATA-R3-005 / BUG-435): `Persistence/DeepBase.Persistence.MRU.FireDAC.pas` Upsert (L72) 无条件 `FConnection.StartTransaction` + except (L115) 无条件 `Rollback` — 调用方已在外层事务中 (共享 TFDConnection 调 Upsert, 或重入) 时: SQLite 报 "cannot start a transaction within a transaction"; PG/MySQL 则 Upsert 中途异常 `Rollback` 回滚调用方整个外层事务, 撤销其合法 DML, MRU 内部异常意外致调用方数据丢失. 修复: 仿 `Persistence/DeepBase.Persistence.Authorization.FireDAC.pas` (DATA2-025) OwnTx 模式 — var 加 `OwnTx: Boolean`, `OwnTx:=False` 后 `if not FConnection.InTransaction then StartTransaction + OwnTx:=True`, `if OwnTx then Commit`, `except if OwnTx then Rollback; raise`. DATA2-019 防并发重复键语义保留 (无外层事务时仍自启包裹 SELECT-INSERT 防双 INSERT 撞 UNIQUE; 有外层事务时复用之, 防重由 MRU 表 UNIQUE 约束兜底, 并发安全由调用方隔离级别保证, 无回归); `raise` 让调用方感知 MRU 写失败并自决外层事务去留, 不吞异常. 验证: Win64 编译 SUCCESS exit 0; MRU 单元 DUnitX 回归 `-FromUnit DeepBase.MRU -AllowFilteredCI` 全过 (Tests Found 13 / Passed 13 / Failed 0); 测试用 TInMemoryMRUStorage mock 不实跑 FireDAC 路径, 真实重入误回滚复现需多线程+共享连接异常注入不在单测范围, 与同类加固项一致不新增专项测试. 见 bugfix.md BUG-435.
  - REVIEW5-R3-C-006 (DATA-R3-006 / BUG-436): `doQry/uDoQryLegacy.pas` 异常/UI 消息含完整内联值 SQL (PII 泄漏) — legacy 层 `BuildSQL` 生成内联值 SQL (参数值经 QuoteValue/HandleParamValue 拼入), 13 处把完整 SQL 塞进用户可见消息: `ExecuteAndGetResult` L756 raise CreateFmt(...'SQL: %s'...aSQL), `ExecuteSQL` L778 raise Create(...'SQL:'+SQL), `doQry(ProcName...)` L894/901/930/945/956/964/968/978/982/993 共 10 处 msg 构造含 'SQL: %s'+sSQL, 覆盖失败路径 (raise 上抛进日志) 与成功路径 (msg var 输出参数返回 UI 显示, 成功执行也向用户暴露 SQL+值). 值可能为聊天正文/用户ID/分享链接, 违反数据最小化. 修复: 统一策略 — msg/异常消息只保留错误本身+操作类型/表名/受影响行数等脱敏元数据, 去掉 'SQL:' 尾巴及对应 sSQL/SQL.Text 参数; 完整 SQL 经 `{$IFDEF DEBUG} Winapi.Windows.OutputDebugString(...) {$ENDIF}` 输出调试器 (生产无 DEBUG/无持久日志, 即便 DebugView 接也不进持久化), 不上抛不进 msg, 共改 13 处均核对 Format 占位符与参数数对齐; 保留 L325/L697 既有 OutputDebugString (本就调试器输出, 非用户消息路径, 不属泄漏面). doQry 工程 L8 DBClient 已自 Delphi 移除 (C-002/C-003 同款历史遗留), BDS37 无法整体编译 → 无编译验证; 改动为纯异常/UI 消息文本改写, Format 语法等价, uses Winapi.Windows 已在 L8 (全限定 OutputDebugString 安全), 无新增符号/签名. 残留扫描: grep "'SQL: |SQL: %s" 排除 DEBUG 行后仅余 2 处既有 OutputDebugString, msg/异常路径零残留; 13 个 IFDEF DEBUG 守卫 (11 新+2 原). 真实 PII 泄漏复现需 doQry.exe 运行 (依赖恢复 DBClient 的旧 BDS 或 DBClient 替代), 不在本轮编译链覆盖, 与同类 doQry legacy 项一致. 见 bugfix.md BUG-436.
  - REVIEW5-R3-C-007 (DATA-R3-007 / BUG-437): `Persistence/DeepBase.Persistence.Manager.FireDAC.pas` AddColumn ColumnDef 原样拼入 DDL (防御性缺口) — `TFireDACManagerStorage.AddColumn` (L208) `Format('ALTER TABLE %s ADD COLUMN %s %s', [TableName, ColumnName, ColumnDef])`, TableName/ColumnName 已 `TSQLUtils.ValidateIdentifier` 校验但 ColumnDef 无校验直接拼; 当前唯一调用方 `Core/DeepBase.Manager.Schema.pas` AddColumnIfMissing 只传硬编码字面量 (TEXT/INTEGER/REAL+DEFAULT'<词>'/DEFAULT数字), **目前不可利用**, 但 AddColumn 暴露在公共 `IManagerStorage.AddColumn`, 未来调用方传受外部影响值即 DDL 注入 (分号终止+DROP/DELETE/CREATE TRIGGER/ATTACH, 或 `--`注释). 属纵深防御缺口非当前漏洞. 修复: `Core/DeepBase.SQL.Utils.pas` `TSQLUtils` 加 `IsValidColumnDef`/`ValidateColumnDef` (与既有 IsValidIdentifier/ValidateIdentifier 同族) — 拒空/长度>200/分号`;`/行注释`--`/块注释`/*`*/`/CRLF换行; 拒 DDL-DML 关键字 (DROP/CREATE/ALTER/DELETE/INSERT/UPDATE/SELECT/TRIGGER/INDEX/VIEW/ATTACH/DETACH/PRAGMA/VACUUM) 经 `\b`词边界大小写不敏感; 允许字符白名单字母/数字/空格/单引号/下划线/小数点/括号逗号, 拒双引号反引号; AddColumn L217 后加 `TSQLUtils.ValidateColumnDef(ColumnDef, 'Manager.AddColumn.ColumnDef')`, 非法即 `EArgumentException` (与 identifier 校验同失败语义). 选白名单非强类型 TColumnDef 记录 (不改公共签名, 不破坏现有调用方, 最小侵入). uses: Manager.FireDAC L26 已含 DeepBase.SQL.Utils 无新增; SQL.Utils implementation 新增 System.RegularExpressions (TRegEx)/System.SysConst. 验证: Win64 `run_tests -FromUnit DeepBase.SQL.Security.PBT -CI -AllowFilteredCI` → `SUCCESS: Unit Tests compiled` (325286 lines 16.48s) + Tests Found 5 / Passed 5 / Failed 0 (含新增 Property20 两个: 11 合法样本+12 非法注入样本, 双路径验证 IsValidColumnDef 布尔与 ValidateColumnDef 抛 EArgumentException); 真实调用方全量核对 Manager.Schema 所有 AddColumnIfMissing 字面量均通过白名单无回归. 见 bugfix.md BUG-437. **REVIEW5-R3 第三轮五专家审阅至此全部 53 项编号发现修复闭环 (BUG-386~BUG-437).**

## 2026-07-09 OPT-P2-002 三大文件拆分项二次复核归档

  - **复核背景**: OPT-P2-002「大文件拆分」于 2026-07-10 标注「部分完成 (Crypto 已拆, LLM/Schema/Math 未拆)」。本轮逐文件结构 + 引用追踪复核, 发现该更正仍基于错误前提, 三项拆分方向描述与代码实际结构不符。
  - **`Core/DeepBase.Schema.pas` (971 行) — 标记不适用, 不拆分**: 纯 `const` SQL DDL 单元 (24 个 `SQL_TIER0/1/2_*` 字符串 + 5 个 `Get*SchemaSQL` 聚合函数), **无 Table/Column/Index/Constraint 类型** (旧描述「需 Table/Column/Index/Constraint 分离」方向错误); `Persistence/DeepBase.Persistence.Diagnose.FireDAC.pas` L299-320 直接引用 20+ 单常量 (按表名映射建表 SQL), 拆分只会增加跨单元引用改动, 不解决可维护性 (纯数据常量单元无逻辑混杂问题)。
  - **`Core/DeepBase.Math.pas` (527 行) — 已拆分完成**: 门面 + 薄包装 (`TMathUtils` ~50 static 工具函数委托 `System.Math` + `TMathConst` + `IsFinite`); 已存在 `DeepBase.Math.Geometry.pas`/`Math.Random.pas`/`Math.Interpolation.pas`/`Math.Statistics.pas` 四子单元, 各头部注释明示「Extracted from DeepBase.Math to keep the facade under 800 lines」; `DeepBase.Services.Math.pas` 已 uses 全部子单元。旧描述「需统计/矩阵/随机数分离」对应内容已在四子单元中落地。
  - **`Core/DeepBase.LLM.pas` (1778 行) — 转独立重构待办 OPT-REFACTOR-001**: 门面单元, 头部明示「facade for the LLM module」, L40-86 大段类型重导出 (类型已迁 `DeepBase.LLM.Types`/`LLM.Config`/`LLM.Providers`); 剩余 1778 行为 `TDeepBaseLLM` 单一巨型类方法实现 (配置管理/HTTP 传输/计费历史/Chat/Prompt 模板管理)。旧描述「需 Provider 适配器独立」方向错误 (Provider 逻辑已独立在 `LLM.Providers.pas`)。真正的「拆分」实为架构重构: 把 `TDeepBaseLLM` 模板管理方法 (Save/Get/Delete/Copy/Validate/Render/Export/ImportTemplate, ~L918-1778 约 850 行) 提取为独立 `TLLMPromptTemplateManager` 类, `TDeepBaseLLM` 委托之。该重构改公开接口、影响调用方 (`Persistence.LLM.FireDAC`/`VCL.LLMConfigPanel`/`FMX.LLMConfigPanel`/`LLM.BillingClient` 均直接 uses `DeepBase.LLM` 用 `TDeepBaseLLM`), 属架构重构非「拆文件」, 拆出为独立待办 OPT-REFACTOR-001 (P2, 含调用方迁移评估 + 接口设计 + DUnitX 覆盖扩展 `Tests/Test.DeepBase.LLM.PromptTemplate.pas`), 不在本轮动代码。
  - **结论**: OPT-P2-002 核实完成 — Crypto/Math 拆分落地, Schema 标记不适用, LLM 转独立重构待办 OPT-REFACTOR-001。本轮零代码改动, 仅 tasks.md/history.md 文档对齐 (无 bugfix.md 登记, 非缺陷修复)。

## 2026-07-13 DeepBaseTests.exe 全量 Runtime 216 触发点排查归档 (BUG-438)

  - **排查背景**: 全量套件 (`Tests/DeepBaseTests.exe --exit:Continue`) 末尾确定性崩溃 `Runtime error 216 at 00007FF6D4A7593A` (Delphi 把 AV 0xC0000005 包成 216), 偏移 `0x593A` 每次完全一致 = 确定性 AV. 此缺陷自 BUG-421 等多条目起被引用为"预存缺陷, 无根因", 一直无定位. 本轮专门排查触发点 (零代码改动, 仅文档诊断).
  - **排查方法**: 用 `Tests/Test.DeepBase.DiagnosticLogger.pas` 自带的逐测试 BEGIN/END/PASS/FAIL 时间戳日志 (`Tests/Logs/test-diagnostic.log`), 全量跑 + `tee` 落盘, 崩溃前日志最后一行即触发测试. (注意: 该日志文件若被上次进程占用会报 EFCreateError, 运行前需 `rm -f Tests/Logs/test-diagnostic.log` 解锁.)
  - **定位结论 (铁证)**: 触发于 `Tests/Regression/Test.Regression.BUG324_WorkerQueueCallbackSafety.pas` 的 `TBUG324_WorkerQueueCallbackSafetyTest.Test_OnError_Exception_RetryPathStillExecutes` (L298-323) 方法体内. 三重证据: (1) 诊断日志停在 该测试 `Test BEGIN` 之后, 无任何 END/PASS/FAIL → 崩在方法体内; (2) 单独跑该 fixture (`-b -r:"Test.Regression.BUG324_WorkerQueueCallbackSafety" --exit:Continue`) 仍崩且偏移 `0x593A` 完全一致 → 排除跨测试内存/线程状态污染, 为本测试固有; (3) fixture 9 个测试前 8 全过 (9 个点 `.........` 后崩), 第 9 个即 OnError 测试崩.
  - **触发要素组合**: 该测试是 fixture 9 个中唯一组合 `OnError 回调(抛 Exception.Create('OnError simulated failure'))` + `RetryPolicy.Immediate(2)` + `FQueue.Stop(True)` 的; `TWorkerQueue.Create('bug324_test', 2)` 启 2 个 worker 线程; `CreateJob` 默认 `FTimeout := FDefaultTimeout = 300000` (L1542/L1476) → `ProcessJob` 走 L1921-1949 的 `TJobHandlerThread` 分支 (handler 在独立线程跑 + `LDoneEvt.WaitFor` + `LHandlerThread.WaitFor`). 前 8 个测试无 retry 无 Stop(True), 未触发该竞态窗口, 故不崩.
  - **嫌疑代码区域 (未确认到确切行)**: `Core/DeepBase.WorkerQueue.pas` ProcessJob 的 except 块 retry 路径 (L2042-2059: `AJob.PrepareRetry` → `FLock.Enter` → `FPendingQueue.Add` → `SortPendingQueue`(L1850 比较器访问 `Left/Right.Priority`+`CreatedAt`) → `FOnJobRetrying`) 与 `Stop(True)` (L2144: 设 `FShuttingDown` + 每 worker `Terminate`+`WaitFor` + `FWorkers.Clear`) 的线程竞态. 静态审视所有路径均有 `FLock` 或 try/except 保护, 无明显锁外裸访问, 故 `0x593A` 对应的确切源码行需 map-file 反查 (当前 `DeepBaseTests.dproj` `DCC_DebugInformation=0` 未开 map file).
  - **结论**: 排查阶段完成 — 216 从"无根因预存缺陷"精确定位到"具体单一测试方法 + 嫌疑代码区域", 证明其确定性 + 本测试固有 + 非跨测试污染. 剩余"0x593A → 源码行"属独立修复工程 (开 MapFile 重编查表 / 装 madExcept 崩时打印 AV 栈), 已记为 tasks.md 独立 P2 待办 + bugfix.md BUG-438. 本轮零生产代码改动, 仅 tasks.md(新增 BUG-438 待办段) + bugfix.md(新增 BUG-438 条目) + history.md(本归档段) + 记忆 `unit-test-fullrun-runtime216.md` 更新根因定位结论.

## 2026-07-09 DeepBaseTests.exe 全量 Runtime 216 @0x593A 修复归档 (BUG-438 已修复) ✅

  - **修复背景**: 承接 2026-07-13 排查归档 — 触发点已锁定 (BUG324 fixture 第 9 测试 `Test_OnError_Exception_RetryPathStillExecutes`), 但 0x593A → 源码行未解. 本轮以 Delphi 异常对象生命周期语义直接验证根因并修复, 无需 map-file/madExcept 埋点 (排查阶段的后备方案作废).
  - **根因确认 (推翻排查阶段"线程竞态"嫌疑)**: 真实根因**非**线程竞态 (排查阶段 L1510 所述竞态窗口为误判), 而是 Delphi 异常对象生命周期缺陷 — `Core/DeepBase.WorkerQueue.pas` `TJobHandlerThread.Execute` 的 `except on E: Exception do FError := E` 跨 except 块持有 `E`. Delphi `except on E:` 块结束时 RTL 自动 Free `E` (除非 `AcquireExceptionObject` 增引用) → except 块 `end;` 后 `E` 被释放 → `FError` 悬挂 → `TakeError` 返回野指针 → `ProcessJob` 的 `raise LHandlerErr` 操作已释放对象 → AV, 落 System RTL 异常析构路径 (与 0x493A 在 `TNoRefCountObject` 后吻合, 偏移每次一致正是悬挂指针解引用固定地址的特征, 竞态偏移应随机). 仅第 9 测试触发该路径: handler 抛异常 + `CreateJob` 默认 Timeout>0 走 L1921 handler-thread 分支 (经 `TakeError`→`raise LHandlerErr`) + retry; 前 8 测试或不 retry、或 Timeout=0 走 inline 分支 (L1956 `raise;` re-raise except 头捕获的**活** E) 不崩.
  - **修复方案 (克隆异常对象, 最小改动)**: `TJobHandlerThread.Execute` 的 except 内改为 `FError := Exception.Create(E.Message)` — 新异常对象脱离 RTL 生命周期, 由 `FError` 独占持有. 现有 `TakeError` (返回 FError 并置 nil, 转移所有权) + 析构 `FreeAndNil(FError)` + `ProcessJob` 的 `raise LHandlerErr` + `FreeAndNil(LHandlerErr)` 引用语义**全部无需改动**, 唯一持有者释放. 代价: 丢失原异常 ClassName, 但下游只用 `.Message` (L2031/L2081) 无影响. 不用 `AcquireExceptionObject`/`ReleaseExceptionObject` (两 API 均无参作用于"当前异常对象", re-raise 后控制流转走、新 except 是新上下文, 无法对原对象配对 Release, 易误用泄漏).
  - **回归测试**: `Tests/Regression/Test.Regression.BUG324_WorkerQueueCallbackSafety.pas` 新增 `Test_BUG438_HandlerException_MessagePropagatedToCompletion` — 构造同触发场景 (handler 抛异常 + Timeout>0 走 handler-thread 分支 + `RetryPolicy.Immediate(2)` + `Stop(True)`), 断言 FOnCompletion 被调用 / ASuccess=False / AResult 含原异常 Message (验证克隆保留 Message 且不崩). 修复前此点已 AV 216 进程退出, 无法执行到断言; 到达断言即证明不崩.
  - **验证 (基线对比)**: `git stash push -- Core/DeepBase.WorkerQueue.pas` 隔离单文件改动跑基线 vs 修复后. BUG324 fixture 单独跑 10 测试全过 (原 9 + 新增); 全量对比 Passed 4148→4157 (+9) / Failed 22→13 (-9) / Errored 28 不变 (DoQry 等无关既有失败) / Leaked 0 / **末尾 216 消失**. 9 个原因 216 失败的测试现通过, 无回归.
  - **衍生 BUG-439**: 排查期间发现两处同类 `跨 except 块持有 E` 潜在隐患 (`Core/DeepBase.Resilience.Retry.pas` L396 / `DeepFlow/Source/AI/DeepFlow.Skill.Client.pas` L156), 原记为 BUG-439 待办. **同日 (2026-07-09) 已全部修复**: site 1 (TryExecute) 测试先行 — 新增 `Test_TryExecute_ErrorOutParam_NotDanglingAfterReturn` 修复前确定性失败 (`Error.Message` 读回空串, 堆扰动复用 RTL 已 Free 的 E 块 = use-after-free), 克隆修复后 122/122 过; site 2 (Skill.Client `LLastException`) 同构确定性 AV, DeepFlow 无测试工程, 经用户决策记为已知盲改 (克隆 + 保留 `ESkillClientException` 类型 + 多轮克隆泄漏防护). 详见 bugfix.md BUG-439「修复结论」段.
  - **影响文件**: `Core/DeepBase.WorkerQueue.pas` (except 内 1 处克隆 + 注释) + `Tests/Regression/Test.Regression.BUG324_WorkerQueueCallbackSafety.pas` (新增回归测试) + `bugfix.md` BUG-438 (状态推进为已修复 + 根因纠正段). 记忆 `unit-test-fullrun-runtime216.md` 更新根因为"异常对象生命周期悬挂 (已修复)".

## 2026-07-09 OPT-REFACTOR-001 LLM 模板管理提取架构重构归档 ✅
- **来源**: tasks.md OPT-REFACTOR-001 (从 OPT-P2-002 拆出的独立架构重构待办).
- **问题**: `Core/DeepBase.LLM.pas` 的 `TDeepBaseLLM` 单体类同时承载配置/调用/历史/模板管理, 模板管理方法 (Save/Get/Delete/Copy/Validate/Render/Export/Import + GetAllTemplates + LoadTemplateFromQuery/ClearPromptTemplates 辅助, ~850 行) 堆在单体内, 违反单一职责.
- **实施**:
  - 新建 `Core/DeepBase.LLM.PromptTemplateManager.pas` — `TLLMPromptTemplateManager` 类, 迁入 9 公开方法 + 2 辅助 (从 LLM.pas implementation 段原样搬移, 含 GetStorage/GetTemplate/RenderWithInheritance 递归内部调用全保留).
  - `TDeepBaseLLM` 新增 `FPromptTemplateMgr: TLLMPromptTemplateManager` 字段 (构造期 Create, 析构期 FreeAndNil); 9 公开模板方法改为一行委托 `FPromptTemplateMgr.Xxx(...)`.
  - 门面签名零变化 → 调用方 `Persistence/DeepBase.Persistence.LLM.FireDAC.pas`、`VCL/...LLMConfigPanel.pas`、`FMX/...LLMConfigPanel.pas`、`Core/DeepBase.LLM.BillingClient.pas`、`Tools/Studio/Frames/Studio.PromptTemplateFrame.pas` 无需改动 (验证: 帧内 `ClearPromptTemplates` 是其自有局部实现, 不依赖 LLM.pas 的同名过程; 模板方法经门面调用).
  - `DeepBaseLLM.dpk` + `.dproj` contains/DCCReference 加 `DeepBase.LLM.PromptTemplateManager`.
- **验证**: Win64 `run_tests.ps1 -Type Unit -CI` 编译通过 (329078 行, 新单元入链, 无编译错误); 全量 DUnitX **Tests Found 4206 / Passed 4203 / Failed 0 / Errored 0 / Leaked 0 / Ignored 3**, 无 216, 无新增警告 (仅既存 H2443/H2219/H2077 Hint).
- **后置未做 (留待次要整洁)**: LLM.pas implementation uses 中 `System.RegularExpressions`/`System.Variants`/`System.NetEncoding` 因模板方法迁出已无引用 (H2219 级冗余), 未清理以隔离本次重构影响面; `DeepBase.Security.DPAPI` 既存冗余与本重构无关, 均留待后续统一清理.
- **影响文件**: `Core/DeepBase.LLM.PromptTemplateManager.pas` (新建) + `Core/DeepBase.LLM.pas` (9 方法委托化 + 字段) + `DeepBaseLLM.dpk`/`.dproj` (contains) + `tasks.md`/`history.md` (归档).
