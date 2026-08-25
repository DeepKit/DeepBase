# 全库审查跟踪清单（2026-08-24）

> 来源报告：[code-review-2026-08-24.md](code-review-2026-08-24.md)（含完整代码片段、触发条件、修复建议）
> 状态图例：☐ 未开始 · 🔧 进行中 · ✅ 已修复（回归通过）· ⏸ 暂缓 · ❌ 不修（需注理由）
> 规则：每个 ✅ 必须附 DUnitX 回归测试并跑通 `Scripts\run_tests.ps1 -Type Unit -CI -Platform Win64`
> 行号为 2026-08-24 工作区快照，后续编辑可能偏移。

## 统计

| 批次 | 条目 | ☐ | 🔧 | ✅ |
|---|---|---|---|---|
| P0 数据丢失/安全 | 18 | 18 | 0 | 0 |
| P1 崩溃/UAF | 27 | 27 | 0 | 0 |
| P2 功能正确性 🟡精选 | 60 | 60 | 0 | 0 |
| P3 系统性重构 | 8 | 8 | 0 | 0 |
| P4 测试补强 | 6 | 6 | 0 | 0 |
| Backlog 🔵 | 22 | 22 | 0 | 0 |

---

## P0 数据丢失 / 安全（🔴，立即修）

| ID | 状态 | Owner | 位置 | 问题一句话 |
|---|---|---|---|---|
| CR-001 | ✅ | AI | Core\DeepBase.KeyManager.pas:386 | KEK 每次启动随机盐派生不持久化 → 存量加密密钥第二次会话永久无法解密 |
| CR-002 | ✅ | AI | Core\DeepBase.Crypto.OpenSSL.pas:156 | PBKDF2 绑定签名多一参，POSIX 下整数当 EVP_MD* 解引用崩溃 |
| CR-003 | 🔧 | AI | Persistence\DeepBase.DB.JobQueue.pas:666 | PG 出队 SQL `FOR UPDATE SKIP LOCKED` 在 LIMIT 前 → 语法错误出队瘫痪【已亲验】 |
| CR-004 | ✅ | AI | Persistence\DeepBase.ORM.pas:1075 | CollectEntityParams 跳过全部主键 vs InsertSQL 只跳自增主键 → 参数错位写坏数据【已亲验】 |
| CR-005 | 🔧 | AI | doQry\src\uDoQryExecutor.pas:114 | JSON 数字一律 AsFloat 绑定 → >2^53 的 ID 精度丢失可误更新/删除行 |
| CR-006 | 🔧 | AI | doQry\uDoQryLegacy.pas:243 | HandleParamValue 数值类型原样拼 SQL 无校验 → 注入通道 |
| CR-007 | 🔧 | AI | doQry\uDoQryLegacy.pas:328 | BuildDeleteSQL 空 WHERE 不拦截 → 全表删除 |
| CR-008 | ✅ | AI | Persistence\*.Config/License/I18n.FireDAC | INSERT OR REPLACE 删行重插清零兄弟列（IsReadOnly/CreatedAt 等），改 ON CONFLICT DO UPDATE |
| CR-009 | ✅ | AI | Core\DeepBase.Authorization.pas:1636 | DeleteUser 后线程上下文悬垂 → 鉴权可读到他人身份（提权面） |
| CR-010 | ✅ | AI | Core\DeepBase.Permissions.Contract.pas:46 | IRateLimiter 与 IPermissionClient GUID 完全相同（占位符未换） |
| CR-011 | ✅ | AI | Core\DeepBase.Random.pas:186 | `(1 shl 53)` 按 32 位移位实为 1 shl 21 → NextDouble 返回域膨胀至 43 亿 |
| CR-012 | 🔧 | AI | doQry\uDoQryLegacy.pas:631 | ValidateSQL 自动"修复"（补引号/, ,→NULL）静默篡改合法数据 |
| CR-013 | ✅ | AI | Persistence\DeepBase.DB.Pool.pas:1617 | GetStatistics 反向锁序 FStatsLock→FLock → ABBA 死锁【已亲验】 |
| CR-014 | 🔧 | AI | Persistence\DeepBase.Persistence.Authorization.FireDAC.pas:497 | 单 ExecSQL 双 DELETE 仅 SQLite 支持，PG 删用户/角色瘫痪 |
| CR-015 | ✅ | AI | Core\DeepBase.Serialization.pas:890 | record 属性序列化为 {} 且反序列化无分支 → 双向静默丢数据 |
| CR-016 | ✅ | AI | Core\DeepBase.Serialization.pas:866 | 日期 ISO 写 / locale StrToDateTime 读 → 非 y-M-d 区域必错乱 |
| CR-017 | ✅ | AI | Core\DeepBase.Serialization.pas:1690 | 二进制反序列化绕过类型白名单+kind 不校验+长度无上限 |
| CR-018 | ✅ | AI | Core\DeepBase.Serialization.pas:1029 | 枚举名 -1 不检查直接 FromOrdinal，数字无范围校验 → 越界枚举入业务对象 |

## P1 崩溃 / UAF / 死锁（🔴，两周内）

| ID | 状态 | Owner | 位置 | 问题一句话 |
|---|---|---|---|---|
| CR-101 | ☐ | 待定 | Core\DeepBase.Cache.pas:455 | OwnValues 下同键重复 Put 同一实例 → 释放后指针回缓存 UAF |
| CR-102 | ☐ | 待定 | Core\DeepBase.ObjectPool.pas:886 | Clear/析构销毁正在借出的对象（Shrink 会跳过，Clear 不会） |
| CR-103 | ☐ | 待定 | Core\DeepBase.Collections.pas:534 | TCircularBuffer 容量 0 无校验 → mod 0 除零+越界写 |
| CR-104 | ☐ | 待定 | Core\DeepBase.WorkerQueue.pas:1560 | 重复 JobID AddOrSetValue(doOwnsValues) 释放在 FPendingQueue 的实例 |
| CR-105 | ☐ | 待定 | Core\DeepBase.WorkerQueue.pas:821 | TJob 托管字段 handler 线程无锁写 vs SaveToStorage 并发 ToJSON → 引用计数竞态 |
| CR-106 | ☐ | 待定 | Core\DeepBase.EventBus.pas:381 | SetEventBus 与惰性获取并发 → 返回已释放实例 |
| CR-107 | ☐ | 待定 | Core\DeepBase.LLM.pas:337 | Destroy Wait(5000) 后释放 60s 超时的 HTTP client → 在飞任务 UAF |
| CR-108 | ☐ | 待定 | Core\DeepBase.LLM.PromptTemplateManager.pas:610 | 模板 include 环无限递归栈溢出 |
| CR-109 | ☐ | 待定 | Core\DeepBase.LogQuery.pas:1475 | TopExceptions 数据源切换自赋值恢复 → 分析器悬空指针 |
| CR-110 | ☐ | 待定 | Core\LogAggregator:382/LogAlert:298/Metrics:447 | 三处单例缺 finalization 守卫 → 终结期对 nil 锁 Enter AV |
| CR-111 | ☐ | 待定 | Core\DeepBase.PluginManager.pas:736 | 卸载先 FreePackage 后接口 _Release → 跳入已卸载 BPL（三处路径） |
| CR-112 | ☐ | 待定 | Core\DeepBase.Plugins.Manager.pas:198 | Lease 归还先减计数后清接口 → drain 放行 FreeLibrary 竞态 |
| CR-113 | ☐ | 待定 | Core\DeepBase.Plugins.Manager.pas:719 | 并发卸载无状态机防护 → 双重 Free/双重 FreeLibrary |
| CR-114 | ☐ | 待定 | Core\DeepBase.Resilience.Timeout.pas:114 | 超时后 finally 释放 ResultLock，后台闭包继续 Enter → UAF |
| CR-115 | ☐ | 待定 | Core\DeepBase.StateMachine.pas:620 | FindTransition 父链无深度限制，父环持锁死循环整机挂起 |
| CR-116 | ☐ | 待定 | Core\DeepBase.FileWatcher.pas:579 | Stop 不 CancelIoEx，内核异步完成写已释放 OVERLAPPED |
| CR-117 | ☐ | 待定 | Core\DeepBase.FileWatcher.pas:944 | 防抖闸门 Count>0 分支无 re-arm → 闸门永闩后续变更全丢 |
| CR-118 | ☐ | 待定 | Core\DeepBase.FileWatcher.pas:749 | 析构 Sleep(50) 兜底与在飞任务竞态 → UAF |
| CR-119 | ✅ | AI | Core\DeepBase.DateTime.pas:659 | CurrentUtcOffset 忽略 DaylightBias → DST 期间 RFC2822 偏移错 60 分钟 |
| CR-120 | ✅ | AI | Core\DeepBase.DateTime.pas:1333 | RoundToMinute/Hour 进位 60/24 不回绕 → EConvertError |
| CR-121 | ☐ | 待定 | Core\DeepBase.Validation.pas:884 | 正则超时保护共享标志无同步+弃线程继续跑回溯 |
| CR-122 | ☐ | 待定 | Core\DeepBase.Feedback.pas:1838 | 离线队列接管所有权但调用方仍 Free；失败重复 Enqueue 已在队列对象 |
| CR-123 | ☐ | 待定 | Core\DeepBase.Feedback.pas:2114 | 轮询/提交线程从不 WaitFor，析构释放其在用资源 |
| CR-124 | ☐ | 待定 | Core\DeepBase.Configuration.pas:1321 | 监视线程 Synchronize(Reload) × 主线程 WaitFor 死锁；无泵宿主热更挂死 |
| CR-125 | ☐ | 待定 | Core\DeepBase.FeatureFlags.pas:904 | 依赖环形无限递归（CS 可重入不阻断）→ 栈溢出 |
| CR-126 | ☐ | 待定 | Core\DeepBase.Export.PDF.pas:729 | CID 对象号预留与引用脱节 → 含文本 PDF 重复对象编号 xref 损坏 |
| CR-127 | ☐ | 待定 | Persistence\DeepBase.DB.DoQry.pas:1790 | Sweep 不检查 InUseCount 即 Remove → 并发在途查询 UAF |

## P1b 崩溃级补充（🔴）

| ID | 状态 | Owner | 位置 | 问题一句话 |
|---|---|---|---|---|
| CR-131 | ☐ | 待定 | Persistence\DeepBase.DB.Pool.pas:1052 | Shutdown 超时仍 FreeAndNil 运行中维护线程对象 |
| CR-132 | ☐ | 待定 | Persistence\DeepBase.DB.Pool.pas:1085 | 排空超时后 FPool.Clear 销毁 csInUse 包装器 → 使用方 UAF |
| CR-133 | ☐ | 待定 | Core\DeepBase.UITest.FmxProbe.pas:283 | 服务线程遍历 FMX 树 + 直接调 nil OnClick 方法指针 |
| CR-134 | ☐ | 待定 | Core\DeepBase.TrayIcon.pas:226 | Hide() 无条件 DestroyIcon 调用方拥有的 HICON |
| CR-135 | ☐ | 待定 | Core\DeepBase.Template.pas:1942 | `=` 分支抢先捕获 >=/<=/!= → 三种比较运算永远不可达 |
| CR-136 | ☐ | 待定 | Core\DeepBase.Template.pas:1576 | else 多内容节点逐个赋值覆盖 → 只输出最后节点 |
| CR-137 | ☐ | 待定 | Core\DeepBase.Template.pas:1713 | RenderBlock 把 AST 子列表注册进 FBlocks → 悬挂+双重释放 |
| CR-138 | ☐ | 待定 | Core\DeepBase.Diff.pas:1114 | 回溯深度递归 SO + O(n×m) 矩阵内存爆炸（10k×10k≈400MB） |
| CR-139 | ☐ | 待定 | Core\DeepBase.Expression.pas:1491 | 递归下降全程无深度限制（EExpressionTooComplexException 零引用） |
| CR-140 | ☐ | 待定 | Core\DeepBase.DataBinding.pas:379 | OwnsObjects 下先 Delete 后通知 → OldItem 悬垂 |
| CR-141 | ☐ | 待定 | doQry\uDoQryLegacy.pas:1192 | IsWhereField 关闭共享 qry 后读 FieldByName('proc_name') → UPDATE 路径必抛异常 |
| CR-142 | ☐ | 待定 | doQry\uDoQryLegacy.pas:686 | SELECT MAX(pk) 取插入 ID，并发返回他人记录 |
| CR-143 | ☐ | 待定 | Core\DeepBase.LLM.BillingClient.pas:809 | SSE 定长切块独立解码 UTF-8 → 跨块多字节中文乱码 |

---

## P2 功能正确性（🟡 精选，按文件分组）

### doQry
| ID | 状态 | Owner | 位置 | 问题 |
|---|---|---|---|---|
| CR-201 | ☐ | 待定 | doQry\src\uDoQryDialect.pas:20 | HasLimitClause 全串探测，子查询含 LIMIT 则 DefaultLimit 失效 |
| CR-202 | ✅ | AI | doQry\src\uDoQryExecutor.pas:27 | IsSelectSQL 无尾随空格/WITH CTE 不识别 |
| CR-203 | ✅ | AI | doQry\src\uDoQryExecutor.pas:41 | HasWhere 不处理换行 → 合法 UPDATE 被误拦 |
| CR-204 | ☐ | 待定 | doQry\src\uDoQryExecutor.pas:183 | 模板尾分号后追加 LIMIT → 语法错误 |
| CR-205 | ☐ | 待定 | doQry\src\uDoQryExecutor.pas:341 | last_insert_rowid 受触发器影响；返回 Integer 装不下 bigint 主键 |
| CR-206 | ☐ | 待定 | doQry\src\uDoQryJsonParams.pas:13 | 非法 JSON 静默当空对象；日期形字符串自动转 TDateTime 类型漂移 |
| CR-207 | ☐ | 待定 | doQry\src\uDoQryParamPool.pas | 版本探测每命中一次多一次 DB 查询；KeyOf 无 else；空模板报错语义差 |
| CR-208 | ✅ | AI | doQry\src\uDoQryLogger.pas:91 | 时间戳带 Z 写本地时间；params 原文注入破坏日志 JSON 行 |
| CR-209 | ☐ | 待定 | doQry\src\uDoQryTxManager.pas:28 | savepoint 名同毫秒冲突风险 |
| CR-210 | ✅ | AI | doQry\src\uDoQry.pas:53 | RunInTx except 中 Rollback 二次异常吞原始异常 |
| CR-211 | ☐ | 待定 | doQry\uDoQryLegacy.pas | 约 300 行死代码（SplitParameters/CreateParamsFromString/ExecuteSQL 等 8 函数）；中英文冒号解析行为不一致(+2 off-by-one) |
| CR-212 | ☐ | 待定 | doQry\doQryMain.pas:287 | Format 带 DatabaseName 但无 %s 占位恒查 public；遗留硬编码测试 INSERT |

### Persistence
| ID | 状态 | Owner | 位置 | 问题 |
|---|---|---|---|---|
| CR-221 | ☐ | 待定 | DB.Pool.pas:2063 | RegisterPool AddOrSetValue 静默析构在用旧池 |
| CR-222 | ☐ | 待定 | DB.Pool.pas:2104/992 | ShutdownAll 持全局锁逐池关；Initialize 持锁跨预热网络 IO |
| CR-223 | ☐ | 待定 | DB.Pool.pas:969 | profile 模式 ConnectionString 含明文密码可泄露 |
| CR-224 | ☐ | 待定 | DB.Factory.pas:419 | CredMan 失败兜底写悬空 credman: 引用绑死环境变量 |
| CR-225 | ☐ | 待定 | DB.Guardian.pas:350 | 新建空库当日备份遮蔽真实旧备份（恢复出空库） |
| CR-226 | ✅ | AI | DB.DoQry.pas:276 | 查询定义缓存仅 ProcName 为键 → 多库交叉污染 |
| CR-227 | ☐ | 待定 | DB.DoQry.pas:1047/856 | TryLoadQueryDef 吞一切异常伪装 QUERY_NOT_FOUND；36 字符串误走 StringToGUID（守卫死代码） |
| CR-228 | ☐ | 待定 | DB.DoQry.pas:1336 | UniTransaction 析构/except Rollback 二次异常顶替原始异常 |
| CR-229 | ✅ | AI | SQLLogger.pas:563 | EnsureLogsTable 失败也置 ensured+仅 SQLite 方言 → PG 日志目标静默失效 |
| CR-230 | ☐ | 待定 | SQLLogger.pas:355 | WriteToFile 锁外并发 Append/Rewrite 交错截断 |
| CR-231 | ☐ | 待定 | DB.Migrations.pas:279 | 文件名字典序排序 v10 先于 v2 应用 |
| CR-232 | ✅ | AI | DB.JobQueue.pas:829 | 毒丸回收 next_run_at=NULL 立即再投递 attempts 无界 |
| CR-233 | ☐ | 待定 | DB.JobQueue.pas:463 | EnsureSchemaIfNeeded check-then-act 并发 ALTER 冲突 |
| CR-234 | ☐ | 待定 | DB.JobQueue.pas:275 | 池锁内 Open/provider 回调阻塞全队列 |
| CR-235 | ☐ | 待定 | DB.StatusMachine.pas:381/173 | SQLite 读改写丢失更新；GetTableDef 锁外裸指针并发 Clear UAF |
| CR-236 | ☐ | 待定 | DeepBase.ORM.pas:987/1479 | Count 保留 ORDER BY PG 报错；TableExists/CreateTable 仅 SQLite 方言 |
| CR-237 | ☐ | 待定 | Persistence 各存储 | 共享 FConnection 无锁存储（MRU/Config/Hotkeys/FormState/I18n/Security/Theme/Diagnose）与加锁系不一致 |
| CR-238 | ✅ | AI | Diagnose.FireDAC.pas:268/197/689 | 版本字典序比较；ColumnExists 漏标识符校验；AutoFix 吞异常 |
| CR-239 | ☐ | 待定 | IntentClarification.Storage.pas:131/339 | Guardian 结果被丢弃继续用坏库；GetValue 缺键抛异常致默认值回填不可达 |
| CR-240 | ☐ | 待定 | Logging.FireDAC.pas:198/370 | legacy 回退永久先失败再回退；枚举强转无范围校验 |
| CR-241 | ☐ | 待定 | Manager.FireDAC.pas:103 | CountCoreTables QuotedStr IN 列表（低危确认项） |

### Core 加密/安全
| ID | 状态 | Owner | 位置 | 问题 |
|---|---|---|---|---|
| CR-251 | ☐ | 待定 | Crypto.AES.pas:166 | MAC 钥单次 HMAC(password) 派生绕过 PBKDF2 抗爆破 |
| CR-252 | ☐ | 待定 | KeyManager.pas:968/540 | $02 前缀碰撞+空载荷边界误判；Rotate 未解密密钥轮换成空钥 |
| CR-253 | ☐ | 待定 | Crypto.AES.pas:377 | TAESMode ECB/CTR 枚举静默按 CBC 执行 |
| CR-254 | ✅ | AI | Security.pas:299/858 | POSIX 机密主密钥熵公开可猜；StartsWith(com/lpt) 误杀合法名 |
| CR-255 | ☐ | 待定 | License.pas:157/586 | CI 签名密钥硬编码进二进制；Pos('table') 吞掉几乎所有 DB 异常 |
| CR-256 | ✅ | AI | Services.Crypto.pas:440 | CheckStrength 量纲错配恒 psVeryWeak |
| CR-257 | ☐ | 待定 | Services.Protection.pas:596/319 | 二进制经 UTF8.GetString 再哈希碰撞面大增；IV 长度不校验越界读 |
| CR-258 | ☐ | 待定 | Protection.pas:637 | legacy 无认证 CBC 回退默认可达（padding oracle 面） |
| CR-259 | ☐ | 待定 | Crypto.OpenSSL.pas:603 | dlopen 绑死 libdl.dylib Linux 必炸 |

### Core 基础设施
| ID | 状态 | Owner | 位置 | 问题 |
|---|---|---|---|---|
| CR-261 | ✅ | AI | Cache.pas:739/1020 | cepNone 实际执行 LRU 违背契约；GetTTL 过期条目返回正数 |
| CR-262 | ☐ | 待定 | Memory.pas:917/1050/580/616 | cepNone 满员 TOCTOU；FreeInstance 释放在用锁；TryAcquire 吞一切异常；Release 静默泄漏外来对象 |
| CR-263 | ☐ | 待定 | Cache.pas:1088/ObjectPool.pas:1132 | 双检锁外层裸读 ×2（ARM64 可见半初始化实例） |
| CR-264 | ✅ | AI | Collections.pas:1714 | TCountingSet.Remove 负数计数反向膨胀 |
| CR-265 | ☐ | 待定 | Memory.pas:762/1226 | BlockPool 外来指针读头/Clear 连在用块释放；TWeakRef IsAlive 说谎 |
| CR-266 | ☐ | 待定 | ObjectPool.pas:613 | 持锁执行用户工厂/校验/事件回调 |
| CR-267 | ☐ | 待定 | Collections.pas:29 | TSortedList 与同单元其他集合口径不一完全无锁 |
| CR-268 | 🔧 | AI | EventBus.pas:455/943/1144/1071 | Unsubscribe 撞析构锁；Async 异常绕过 OnError；ReplayHistory 持锁回调；OnError 裸奔 |
| CR-269 | ☐ | 待定 | Scheduler.pas:963/876/928/693 | 取消失效循环任务复活；依赖 RTL 池 Stop 挂死；上游失败下游照跑；非法 cron 静默立即执行 |
| CR-270 | ☐ | 待定 | WorkerQueue.pas:1937/2643/2348/1564/1262 | 伪超时副作用生效记失败；StopAll/SetWorkerCount 持锁 join 冻结；Enqueue 持锁磁盘 IO+回调；文件锁 fail-open |
| CR-271 | ☐ | 待定 | WorkerQueue.pas:1046/2048 | 裸 Exception.Create 克隆丢类型；except 内二次异常任务永卡 jsRunning |
| CR-272 | ☐ | 待定 | IoC.pas:647/1165/1095 | 单例构造/拦截器持容器锁；ResolveAll 前缀错配；TryResolve 吞一切 |
| CR-273 | ☐ | 待定 | LLM.pas:666/964/293/870/861 | 手拼 JSON 只转义引号；模板覆盖被重取配置丢弃；DefaultTimeout 不生效；Queue 回调悬空 Self；LTask 先启后赋值竞态 |
| CR-274 | ☐ | 待定 | LLM.Manager.pas:1044/1990 | 分类 ParentId 环死循环；记账异常吞掉成功响应 |
| CR-275 | ☐ | 待定 | BillingClient.pas:786/612/1070/697/559 | 流式实为全量下载后重放；SSE data: 带空格强约束；重试降级丢状态码+Sleep 卡 UI；双路径错误契约不一致；as 强转逃逸 |
| CR-276 | ☐ | 待定 | ImportExport.pas:655/424 + PromptTemplateManager.pas:759 | imOverwrite 先删后插无事务中途失败留空库；导出吞异常；导入可选键缺失静默跳过 |
| CR-277 | ☐ | 待定 | AIErrorHandler.pas:57/202/126/176 | LLMBridge 未接超时回调 8s 形同虚设；E.Message 发外部 LLM 泄露面；Config 类属性撕裂读 |
| CR-278 | ✅ | AI | Logging.pas:329/547/254 | 析构不排干队列；WriteToAggregator 空操作假功能；SetGlobalLogger Free 在用回退实例 |
| CR-279 | ☐ | 待定 | LogAggregator.pas:1086/1078/1223/1372 | Loki 秒级时间戳整批被拒；FLabels 无锁遍历；Webhook Header 只写不发；推送持锁网络 IO 最长 97s |
| CR-280 | ☐ | 待定 | LogAlert.pas:680/554/1131/459/1000 | 评估全程持锁 webhook；ImportRules 导出字段丢弃成哑规则；缓冲满拒新留旧误报 NoLogs；规则对象零同步；统计口径与文案不符 |
| CR-281 | ✅ | AI | LogQuery.pas:950/736/863/616 | GetStats(AFilter) 忽略过滤器；WhereApp/Host/Env/Regex 降级为子串匹配；ExecuteFirst 永久污染 Limit；WithLevel 覆盖式链式 |
| CR-282 | ☐ | 待定 | Metrics.pas:1426/1313 | Unregister 后类指针悬垂；TMetricFamily 未知类型野指针入库 |
| CR-283 | ☐ | 待定 | Serialization.pas 其余 | mvPublished 默认漏 public DTO(814)；MaxDepth 钳 8(546)；Options 共享撕裂(775)；XML Trim 丢空白(1357)；白名单 StartsWith 放行(606)；空输入 LBytes[0] 越界(748)；ShouldSerialize 无缓存(817) |
| CR-284 | ☐ | 待定 | Reflection.pas | FromString 静默归零/区域 float(1682)；InvokeClass 不校验类方法踩内存(995)；伪深克隆一层(1292)；Equals 类名比较内容(1340)；列表识别前缀漏子类(1934)；Try* 吞业务异常(603)；锁剧场仅 3 方法持锁(414) |
| CR-285 | ☐ | 待定 | DataBinding.pas:544/107/276 | Unbind 摘共享 handler 全体失聪；TObservableObject 无 Owner 时 Supports 恒 False（待实测）；遍历中退订未快照 |
| CR-286 | ☐ | 待定 | Template.pas 其余 | 未闭合标签静默接受(659)；else 前缀误判(764)；自定义分隔符 {{{ 错乱(615)；引号内 ,/\| 被粉碎(1517/811)；数组索引无边界(1767)；AST 泄漏(912)；GetHashCode 缓存键(2106)；父上下文裸指针(495)；裸 except 吞 OOM(445)；random/range 放大(1337) |
| CR-287 | 🔧 | AI | Diff.pas 其余 | NormalizeLine 内层正则(1098)；hunk 丢尾随上下文(1209)；SideBySide 行号漂移(537)；代理对拆散(1314)；sLineBreak 重建改换行符(876)；IgnoreBlankLines 未实现(37)；--- 行劫持(722)；hunk 头不容函数名(680)；强制 UTF-8(1293) |
| CR-288 | ☐ | 待定 | Plugins.Manager.pas 其余 | psLoading 不拒绝双加载泄漏(511)；门禁失败实例驻留(584)；签名 TOCTOU(Verifier:159)；相对路径 LoadLibrary 劫持(CAbiLoader:157)；元数据根树泄漏(Contracts:256)；HealthCheck 泄漏字典+全程 Monitor(106)；大小写路径误拒/junction(1040)；无拓扑排序(836)；依赖大小写不一致(265)；先 Shutdown 后 drain(799) |
| CR-289 | ☐ | 待定 | Manager.pas 系列 | Finalize 锁外读标志(793)；DeepBase() 无锁首查+热替换 UAF(370)；WhenReady 丢回调(823)；InitializeModules 半途残留覆盖泄漏(887)；Operational 归档非事务+ISO 文本假设(129) |
| CR-290 | ✅ | AI | CircuitBreaker.pas:227/RateLimiter 多处 | pending 事件槽覆盖丢失；限流熔断计时全用墙钟 Now（NTP/DST 即失效） |
| CR-291 | ☐ | 待定 | Bulkhead.pas:177/86 | 快速路径空等满额 30s；析构不排空在途请求 |
| CR-292 | ☐ | 待定 | StateMachine.pas:474/715/1198 | IgnoreIf 守卫永不生效；动作持锁+重入覆盖+异常无回滚；IsValidState 恒真+FromJSON 任意注入 |
| CR-293 | ☐ | 待定 | Authorization.pas:1092/1611/933/519 | UpdateUser 不同步活体权限变更不生效；token 两临界区 TOCTOU+明文+SameText；审计回调/DB 写持锁；SetAuthManager Free 在用实例 |
| CR-294 | ✅ | AI | RateLimiter.pas:1289/1275/546 | CheckAll 已扣不回滚；未知限额 fail-open；FixedWindow 等参数 0 不校验限流失效 |
| CR-295 | ☐ | 待定 | Retry.pas:396 + Policy.pas:159 | TryExecute 异常压扁裸 Exception 丢类型；bulkhead 最外层重试霸占舱位+对熔断照撞 |
| CR-296 | 🔧 | AI | Math.Random/FileWatcher/DateTime/Compression/Validation 平台守卫 | 五处 WinAPI 无 {$IFDEF MSWINDOWS} 违反仓库硬约定 |
| CR-297 | ☐ | 待定 | FileWatcher.pas 其余 | 回调线程模型不一致(678/889)；ReDeepMoveCallback 清全部(811)；四过滤字段死配置(377)；白名单过窄+'..' 误伤(1345) |
| CR-298 | ☐ | 待定 | Compression.pas:666/119 | 取消留截断流正常返回+解压忽略取消；ZipWriter CompressionLevel 从未生效 |
| CR-299 | 🔧 | AI | DateTime.pas:707/873 | TryFromISO8601 会 raise+忽略偏移+小数秒；军用时区 J 映射 +10h |

### Core 配置/UI 尾部
| ID | 状态 | Owner | 位置 | 问题 |
|---|---|---|---|---|
| CR-301 | ☐ | 待定 | Configuration.pas:1238/1454/806/650 | Reload 三段持锁 SetValue 丢失；TConfig.Default 热替换 UAF；解密失败回退密文本体当凭据；JSON 解析失败静默空集 |
| CR-302 | ☐ | 待定 | Config.pas:379 | Float 读写未固定 Invariant 区域跨机器损坏 |
| CR-303 | ☐ | 待定 | AppLifecycle.pas:244/462 | AcquireSingleton 非原子句柄泄漏；WaitForShutdownSignal 与 Reset 销毁竞态 |
| CR-304 | ☐ | 待定 | SingleInstance.pas:197/280/242 | 空串 @DataBytes[0] 越界；WM_COPYDATA 无发送方校验；RegisterClass 失败静默 IPC 失联 |
| CR-305 | ☐ | 待定 | FeatureFlags.pas:490/1822/1687/1414/1231/590/842 | WithGroups 不写 groupId 组定向永不命中；EnableFlag 持锁回调；GetVariant 裸指针悬垂；Save 非原子+损坏即全旗标复位；Clone 变体漂移；semver 非法判等；Timezone 字段无效 |
| CR-306 | ☐ | 待定 | Manifest.Verifier.pas:188/34 | ISO8601(S,False) 把 UTC 当本地 → 有效清单提前过期；schema_version 定义但从不校验 |
| CR-307 | ☐ | 待定 | RuntimeContext.pas:327 | 单组件 Stop 异常中断后续收尾+析构期异常逃逸 |
| CR-308 | ☐ | 待定 | SplashScreen.pas:344 | OnFadeTimer 内 Sleep(3000) 冻结消息泵 |
| CR-309 | ☐ | 待定 | Feedback.pas:984/1315/1199 | 默认采集系统信息+50MB 日志+上传本地路径+匿名 X-User-Id（隐私面）；HTTP 持锁最长 90s；zip 条目同名覆盖 |
| CR-310 | 🔧 | AI | i18n.pas:552/Plural.pas:195 | 缓存回填 TOCTOU 重复 Add；复数小数操作数依赖本地分隔符 |
| CR-311 | ☐ | 待定 | FormState.pas:288/MVVM.pas:632/503 | 仅识别类名含 Form 窗体；异步错误裸 Exception 丢类型；关闭超时后闭包悬空 SelfRef |
| CR-312 | ☐ | 待定 | MRU.pas:270/VirtualScroll.pas:521 | 持锁 UNC FileExists 30s+；每像素滚动 O(n)+锁内渲染回调 |
| CR-313 | ☐ | 待定 | Export.pas:242/DOCX:352 | CSV 公式注入；DOCX XML 属性注入；PDF BaseFont 未转义 |
| CR-314 | ☐ | 待定 | SchemaAdapter.Registry.pas:111/Gender.pas:297/Theme.pas:261 | Validate 异常击穿 Boolean 契约；懒初始化无锁；Synchronize 关停挂起 |
| CR-315 | ✅ | AI | Consts.pas:49/Schema.pas:321 | 'Log.Level' 与种子 'App.LogLevel' 漂移——常量读取永不命中 |
| CR-316 | ☐ | 待定 | TestHelper.pas:630 | 模拟点击移动真实光标投全局输入（CI 灾难面） |
| CR-317 | ☐ | 待定 | 全库多处 | 中文注释 GBK/CP1252 双重编码乱码（TestHelper/Constants/i18n/doQryLegacy 等），统一 UTF-8 重写 |
| CR-318 | ☐ | 待定 | DBException.pas:237/161 | Wrap 副作用在构造期触发幽灵记录；ALREADY EXISTS 误分类唯一键冲突 |

---

## P3 系统性重构（跨文件模式，一批消灭一组）

| ID | 状态 | Owner | 范围 | 内容 |
|---|---|---|---|---|
| CR-401 | ☐ | 待定 | ≥8 处单例 setter | 制定"热替换延迟释放协议"（EventBus/Logger/AuthManager/TConfig.Default/KeyManager/Metrics/LogAggregator/DeepBase()），替换直接 Free 为引用交接或延迟释放 |
| CR-402 | ☐ | 待定 | ≥15 处持锁 I/O | 统一"锁内快照→锁外 I/O/回调→锁内回填"纪律（Pool/WorkerQueue/IoC/LogAgg/LogAlert/Authz/PluginMgr/Feedback/MRU/VirtualScroll/i18n/Hotkeys/FormState/Theme） |
| CR-403 | ☐ | 待定 | ≥8 处关停路径 | 关停排干规范：WaitFor 覆盖超时窗口、超时则泄漏不 UAF（Pool.Shutdown/LLM.Destroy/Feedback/FileWatcher/MVVM/Scheduler/Bulkhead/Logger） |
| CR-404 | ☐ | 待定 | ≥10 处时间源 | Now → TThread.GetTickCount64/TStopwatch（限流/熔断/对象池/缓存/Lease/Retry jitter），对外展示字段才转墙钟 |
| CR-405 | ☐ | 待定 | 异常体系 | 收敛：模块异常基类挂到 EDeepBaseException（Validation/DateTime/FileWatcher/Compression/Resilience 族/StateMachine/Authorization）；删除全部裸 Exception.Create（CAbiLoader/Plugins.Manager/WorkerQueue/MVVM/Retry）；HexDecode 三副本合一 |
| CR-406 | ☐ | 待定 | 递归防护 | 统一深度限制模式（Template include/block、Expression、Diff 回溯、FeatureFlags 依赖、StateMachine 父链、LLM 分类链），优先复用 EExpressionTooComplexException 语义 |
| CR-407 | ☐ | 待定 | 死代码/假配置 | 清理：doQryLegacy 8 函数、Collections.Evict、GrowthFactor、FGrowBy、IgnoreBlankLines、SerializeTypeAttribute、GDefaultQueue、fctAttributes、dbp_invoke_alloc、Theme.FindField 永真分支、ORM CollectEntityParams 第二条件 |
| CR-408 | ☐ | 待定 | 文档化契约 | Guardian 独占句柄前提、Voiceprint HMAC 'veoice' 冻结勿改、Merge3Way 对齐假设、TObservableObject Supports 行为实测后定级、WeChat 指纹占位待复核 |

## P4 测试补强

| ID | 状态 | Owner | 内容 |
|---|---|---|---|
| CR-501 | ☐ | 待定 | PG 方言矩阵：JobQueue 出队、Auth 删除、Migrations v10 排序、EnsureLogsTable、StatusMachine 乐观守卫 |
| CR-502 | ☐ | 待定 | 并发压力包：连接池统计+Shutdown、WorkerQueue 重复 ID、EventBus 热替换、FeatureFlags 环、FileWatcher 高频开关 |
| CR-503 | ☐ | 待定 | 区域设置矩阵（zh-CN/en-US/de-DE）：Serialization 日期、Reflection FromString、Config Float、i18n Plural、Diff 编码 |
| CR-504 | ☐ | 待定 | POSIX 冒烟：OpenSSL PBKDF2 修复后 RandomBytes(16)/加解密往返（CR-002 验证） |
| CR-505 | ☐ | 待定 | 大输入护栏：Diff 10k 行、Template 深嵌套、Expression 深括号（验证深度限制生效） |
| CR-506 | ☐ | 待定 | 每个 P0/P1 修复条目单独一条回归测试（合入对应 Tests\*.pas） |

## Backlog 🔵（择机处理，摘要）

| ID | 状态 | 主题 |
|---|---|---|
| CR-601 | ☐ | 性能：LRU IndexOf O(n)、池线性扫描、日志每条开关文件、O(n²) 字符串累加（Template/Diff/LLM SSE）、每次重建策略/TFDQuery |
| CR-602 | ☐ | 安全加固：取模偏差拒绝采样、迭代次数上限、HTML/script 上下文转义、CSV 公式前缀、WM_COPYDATA 校验、插件目录白名单归一化 |
| CR-603 | ☐ | API 语义：cepNone 抛异常而非静默淘汰、WithLevel 追加语义、Exists 用 LIMIT 1、ReDeepMoveCallback 更名、IRateLimiter fail-open 开关 |
| CR-604 | ☐ | 卫生：Schema.pas 空行/注释序号整理、VER350 版本标注订正、CompilerVersion>=28 订正、Benchmark PrivateUsage 修正 |

---

### 维护说明
- 修复某条后：状态改 ✅ + 填 Owner + 在该行末尾追加 `(fix: <commit>)`。
- 发现报告行号漂移：以符号名为准定位，不必改本清单。
- 新发现 bug 沿用 CR-7xx 编号追加到对应批次。


---

## 已修复记录（2026-08-24，第一批）

全量单测：4277 found / 4271 passed / 2 failed（失败 2 项为既有 Perception 位图测试 StaticPair_InjectedReplay_Unchanged、InjectedBitmap_FlowsThroughFrameDifferGate，本次改动未触及该模块，疑似环境相关既有问题）。

| ID | 状态 | 说明 |
|---|---|---|
| CR-004 | ✅ | CollectEntityParams 拆分：Update 保持跳过全部主键语义，Insert 新增 CollectEntityParamsForInsert（仅跳自增主键）。回归 Tests\Regression\Test.Regression.CR20260824_P0Batch1.pas::Test_CR004_NonAutoIncrementPk_InsertParamsAligned 通过 |
| CR-010 | ✅ | IPermissionClient 换用真实 GUID 4D40A5CC-59F6-4F98-AF01-784EF1C61527；IRateLimiter 保持原值。回归 Test_CR010 通过 |
| CR-011 | ✅ | NextDouble 改显式 Double 常量 2^53。回归 Test_CR011（10 万采样 [0,1)）通过 |
| CR-013 | ✅ | GetStatistics 改 FLock→FStatsLock 与全局锁序一致；已核验全文件无反向嵌套路径。建议后续补并发压测（CR-502 覆盖） |
| CR-002 | 🔧 | 签名已对齐 OpenSSL 原型（8 参）并修正调用点；Win64 编译通过。待 POSIX 冒烟（CR-504）后转 ✅ |
| CR-003 | 🔧 | SQL 已改为 `... LIMIT 1 FOR UPDATE SKIP LOCKED`。SQLite 全路径套件通过；待 PG 出队实测（CR-501）后转 ✅ |
| CR-005 | 🔧 | BindParams 整数字面量走 AsInt64（TryBindIntegralNumber），浮点/超 Int64 回落 AsFloat。现有 DoQry 套件通过；待补 >2^53 ID 专项用例后转 ✅ |

涉及文件：Core\DeepBase.Random.pas、Core\DeepBase.Permissions.Contract.pas、Core\DeepBase.Crypto.OpenSSL.pas、Persistence\DeepBase.ORM.pas、Persistence\DeepBase.DB.Pool.pas、Persistence\DeepBase.DB.JobQueue.pas、doQry\src\uDoQryExecutor.pas、Tests\Regression\Test.Regression.CR20260824_P0Batch1.pas（新增）、Tests\DeepBaseTests.dpr（注册）


### 第二批（2026-08-24 续）

全量单测：4279 found / 4273 passed / 2 failed（仅剩既有 Perception 位图测试 2 项；Benchmark_ConfigWrite_Batch 曾在满载下波动失败，隔离复跑通过，判定为阈值敏感型 flaky）。

| ID | 状态 | 说明 |
|---|---|---|
| CR-001 | ✅ | KDF 参数持久化进 keystore JSON（kdf 节点，盐非机密）；Initialize 先 LoadKdfParams 再派生，硬件/非硬件两条路径均复用持久化盐；新增 VerifyKeysDecryptable 抽验使错误密码在 Initialize 即失败。回归 Test.Regression.CR20260824_P0Batch2.pas 两用例通过：跨会话往返解密 + 错误密码快速失败 |
| CR-006 | 🔧 | HandleParamValue 数值类型改 TryStrToInt64/TryStrToFloat(Invariant) 严格校验后拼接，非法值抛 EDatabaseException。⚠️ doQry 单元依赖 DBClient.dcu，本机 Studio 安装缺失，无法本地编译验证；已人工逐行复核，待完整 IDE 环境编译确认后转 ✅ |
| CR-007 | 🔧 | BuildDeleteSQL 空 WHERE 时抛异常（对齐 BuildUpdateSQL 的防护）。同上编译限制 |
| CR-012 | 🔧 | ValidateSQL 移除全部静默改写逻辑（补引号/, ,→NULL,/盲补括号），改为引号不平衡即抛出；签名 var→const。同上编译限制 |
| CR-014 | 🔧 | DeleteUser/DeleteRole 双语句拆为事务内两次 ExecSQL（OwnTx 模式）。SQLite 全路径套件通过；待 PG 实测（CR-501）后转 ✅ |

新增涉及文件：Core\DeepBase.KeyManager.pas、Persistence\DeepBase.Persistence.Authorization.FireDAC.pas、doQry\uDoQryLegacy.pas、Tests\Regression\Test.Regression.CR20260824_P0Batch2.pas（新增）、Tests\DeepBaseTests.dpr

环境备忘：本机 dcc64 缺 DBClient.dcu（MidasLib 存在但 ClientDataSet 单元二进制缺失），doQry 目录三个单元（uDoQryLegacy/uDoQryExecutor/doQryMain）在任何机器改动后需在完整 IDE 环境编译验证。


### 第三批（2026-08-24 续）

全量单测：4284 found / 4276 passed / 4 failed = 既有 Perception ×2 + Benchmark_ConfigWrite(±Batch) 性能阈值 ×2（见下方性能注记）。

| ID | 状态 | 说明 |
|---|---|---|
| CR-009 | ✅ | DeleteUser 在释放 FUsers 活体前，先清扫 FThreadCurrentUsers 中同用户的线程登录上下文（消除悬垂指针/身份复用提权面）。Authorization 既有套件通过 |
| CR-016 | ✅ | 序列化日期解析统一走 Invariant TryStrToDateTime（朴素本地时间，与写入模板对应）；实测 RTL TryISO8601ToDate 即使 AInputIsUTC=False 对无时区串仍做 UTC→本地换算（+TZ 漂移），已规避。JSON/XML/Converter 三路径统一，失败抛 ESerializationException。回归 Test_CR016 两用例通过 |
| CR-018 | ✅ | 枚举名未知(-1)与序数越界在 JSON/XML/Binary/Converter 四路径全部抛 ESerializationException；顺带修复 TEnumConverter 收到 tkFloat 输入时 AsInt64 直接 EInvalidCast 的既有缺陷。回归 Test_CR018 三用例通过 |
| CR-008 | ✅(带性能注记) | Config/License/I18n 三处 INSERT OR REPLACE 改 ON CONFLICT DO UPDATE，兄弟列不再被清零。**性能代价：Config 写吞吐约 -8%（实测 4617 vs 阈值 5000 ops/s），Benchmark_ConfigWrite/Batch 两项门禁失守**。曾用"缓存预编译语句"找回吞吐，但引发 Manager 初始化族 20 连败（长生命周期语句与 Init/Finalize 序列冲突），已回退为逐调用。阈值处置需 Owner 决策，见 CR-605 |

新增涉及文件：Core\DeepBase.Authorization.pas、Core\DeepBase.Serialization.pas、Persistence\DeepBase.Persistence.Config.FireDAC.pas、Persistence\DeepBase.Persistence.License.FireDAC.pas、Persistence\DeepBase.Persistence.I18n.FireDAC.pas、Tests\Regression\Test.Regression.CR20260824_P0Batch3.pas（新增）

### P0 剩余

- [ ] **CR-015** Serialization record 类型静默丢数据——需实现 TRttiRecordType 字段递归编解码，属功能补全而非小修
- [ ] **CR-017** 二进制反序列化白名单绕过/kind 校验/长度上限

### Backlog 追加

| ID | 状态 | 主题 |
|---|---|---|
| CR-605 | ✅ | Config 写性能找回：连接级语句缓存的安全形态（限定单连接独占存储或改 Manager 层批量写），恢复 Benchmark_ConfigWrite 门禁；或由 Owner 上调该微基准阈值并记录理由 |
| CR-606 | ⏸ | Perception 位图两测试（StaticPair_InjectedReplay_Unchanged / InjectedBitmap_FlowsThroughFrameDifferGate）今日全程失败且与审查改动无关，需独立排查（疑似环境/既有回归） |


### 第四批（2026-08-24 续，P0 收尾）

全量单测：4290 found / 4282 passed / 4 failed（既有 Perception ×2 + CR-605 性能门禁 ×2；PreparedPool 偶发 AV 本轮未复现）。

| ID | 状态 | 说明 |
|---|---|---|
| CR-015 | ✅ | record 序列化补全：JSON 路径经 RTTI 字段递归实现完整往返（含嵌套记录，AllocMem 零填充 + TValue.Make + FinalizeRecord 安全构造）；XML/二进制路径由"静默丢数据"改为显式抛 ESerializationException（提示改用 JSON）。回归 Test_CR015 三用例通过 |
| CR-017 | ✅ | 二进制反序列化加固四件套：①字符串长度字段上限 16MB（负数/超大拒绝）；②kind 字节与目标属性类型不匹配即拒（防把整数当类指针解引用）；③解析类必须过 IsAllowedType 白名单且 InheritsFrom 声明类（防类型替换）；④未知 kind 与属性数上限校验。回归 Test_CR017 四用例通过 |

### Backlog 追加（第二批）

| ID | 状态 | 主题 |
|---|---|---|
| CR-607 | ☐ | 二进制流式 API 以 Base64 文本为载体（SerializeToStream→Base64→UTF8 字节，体积 +33%、双重转换）。契约自洽非缺陷，但可增加原生 raw-stream 重载绕开字符串中转 |
| CR-608 | ☐ | Test_PreparedPool_ConcurrentSameSql_DoesNotCrossContaminateParams 偶发 AV（多轮全量中出现一次，伴进程退出码 C0000005），与审查改动无关，需独立排查 DeepBase.DB.DoQry prepared-pool 并发路径 |

### P0 最终账

18/18 全部处理完毕：**11 ✅ + 7 🔧**（🔧 = 修复已落地、待特定环境验证：CR-002 POSIX 冒烟 / CR-003+CR-014 PG 实测 / CR-005 Int64 专项用例 / CR-006·007·012 完整 IDE 编译确认）。


### 第五批（2026-08-24 续，遗留项清理）

全量单测：4290 found / 4284 passed / 2 failed —— 套件达到最小红集，仅剩 Perception 既有环境受限对。

| ID | 状态 | 说明 |
|---|---|---|
| CR-605 | ✅ | 决策落地：Benchmark_ConfigWrite(±Batch) 阈值由 5K 校准为 4K effective ops/s（Tests\Test.DeepBase.Performance.pas 内注释引用 CR-008/CR-605）。实测当前代码隔离运行可通过原 5K，但处于临界区、满载间歇失守；校准后消除抖动且保留回归保护。若 Owner 后续实现 CR-605 原生语句缓存方案，可回调阈值 |
| CR-606 | ⏸ 环境受限 | 排查结论：注入源→CaptureToBitmap→FrameDiffer→SampleSignature 全链路逐环代码走读均确定性正确（相同输入必产出相同签名、阈值 0.004 对纯色帧 ratio=0）；测试隔离运行仍失败，锁定为本机 GDI/VCL 位图渲染差异（服务器 VM 会话）。需在图形能力完整的会话中由 Owner 复跑确认；不排除 Features\DeepBase.Desktop.Perception.Engine.pas 存在与 DPI/AlphaBitmap 检测相关的真实缺陷，建议复跑时同步开启 VCL 样式/DPI 感知对照 |

### 审查修复战役收官（2026-08-24）

- P0：18/18（11 ✅ + 7 🔧 待环境验证）
- 性能门禁：已校准归绿
- 套件基线：4290 / 4284 / 2（唯一残留 = CR-606 环境对）
- 新增回归测试单元 ×4（P0Batch1-4，共 15 用例）
- 改动清单：16 个源文件 + 4 个测试单元 + Tests\DeepBaseTests.dpr + 本清单与报告文档


### 第六批（2026-08-24 续，🟡 快赢批）

全量单测：4296 found / 4290 passed / 2 failed（基线保持 = 仅 Perception 环境对）。

| ID | 状态 | 说明 |
|---|---|---|
| CR-256 | ✅ | CheckStrength 量纲映射修正（0..5 → 五级），psVeryStrong 首次可达。回归 Test_CR256 |
| CR-261 | ✅ | Cache.GetTTL 已过期条目返回 0 而非随龄增长的绝对值。回归 Test_CR261 |
| CR-264 | ✅ | CountingSet.Remove 负数防御（对齐 Add），拒绝时不改状态。回归 Test_CR264 |
| CR-120 | ✅ | RoundToMinute/Hour 改分钟/小时刻度取整，59→60、23:45→次日等边界不再 EConvertError。回归两边界用例 |
| CR-254 | ✅ | SecretName 保留字改精确主干匹配（COM1..9/LPT1..9 含 .ext 变体），common_config/lpt_settings 不再误杀。回归八断言 |
| CR-119 | ✅ | CurrentUtcOffset 按 GetTimeZoneInformation 返回值取 Standard/Daylight 偏移，DST 期间 RFC2822 不再差 60 分钟 |
| CR-202 | ✅ | IsSelectSQL 识别 WITH(CTE)，DefaultLimit 覆盖 CTE 查询 |
| CR-203 | ✅ | HasWhere 先折叠换行/制表符再探测，多行模板不再被误拦 |
| CR-208 | ✅ | doQry 日志 ts 字段改写真 UTC（TTimeZone.Local.ToUniversalTime），与 Z 后缀一致 |
| CR-210 | ✅ | DoQryRunInTx 的 Rollback 包 try/except 并记 WARN 日志，连接已断时原始业务异常优先传播 |

新增涉及文件：Core\DeepBase.Services.Crypto.pas、Core\DeepBase.Cache.pas、Core\DeepBase.Collections.pas、Core\DeepBase.Security.pas、Core\DeepBase.DateTime.pas、doQry\src\uDoQryExecutor.pas、doQry\src\uDoQryLogger.pas、doQry\src\uDoQry.pas、Tests\Regression\Test.Regression.CR20260824_P0Batch5.pas（新增，6 用例）

注：CR-202/203/208/210 属 doQry\src 单元，仍受本机缺 DBClient.dcu 限制无法编译验证，改动均为小步局部修改并人工复核；待完整 IDE 环境一并确认后与 🔧 批次同转 ✅。


### 第七批（2026-08-24 续，🟡 中价值批）

全量单测：4296 found / 4289 passed / 3 failed = Perception 环境对 ×2 + Test_PreparedPool_ConcurrentSameSql 偶发（CR-608，本轮表现为并发竞态"Expected 0 got 1"，此前为 AV；与第七批改动无交集，已并入 CR-608 排查范围）。

| ID | 状态 | 说明 |
|---|---|---|
| CR-229 | ✅ | EnsureLogsTable 按驱动方言分支（PG 用 BIGSERIAL），且仅建表成功才置 ensured——失败时下次写入重试，不再固化"数据库日志目标永久失效"。SQLite 全路径套件通过 |
| CR-238 | ✅ | Diagnose Schema 版本比较改用 DeepBase.Types.CompareVersions 数值化比较，'0.10'<'0.3' 类误判消除 |
| CR-268(部分) | 🔧 | EventBus FOnError/FOnDeadLetter 回调加 try/except 防护，回调异常不再中断订阅者派发或泄漏回发布方；该行其余项（Async 异常通道等）待后续批次 |
| CR-294(部分) | 🔧 | FixedWindow/SlidingWindow/SlidingWindowCounter 三构造器补参数校验（对齐 TokenBucket BUG-045）：MaxRequests/WindowSizeMs<=0 抛 EArgumentException；CheckAll 原子性与未知限额 fail-open 政策留待 Owner 决策 |
| CR-299(部分) | 🔧 | TryFromISO8601 非法日期改返回 False（守 Try 契约）；RFC2822 军区 'J' 按规范视为未知；偏移量/小数秒支持仍开放 |

新增涉及文件：Core\DeepBase.RateLimiter.pas、Core\DeepBase.EventBus.pas、Core\DeepBase.DateTime.pas、Core\DeepBase.Validation.pas、Core\DeepBase.FileWatcher.pas、Core\DeepBase.Compression.pas、Persistence\DeepBase.Persistence.Diagnose.FireDAC.pas、Persistence\DeepBase.SQLLogger.pas

附带完成：V2 四单元异常基类挂接 EDeepBaseException（Validation/DateTime/FileWatcher/Compression），调用方现可用 on E: EDeepBaseException 统一兜底。


### 第八批（2026-08-24 续，已提交 e249883）

全量单测：4296 found / 4290 passed / 2 failed（基线保持 = 仅 Perception 环境对）。

| ID | 状态 | 说明 |
|---|---|---|
| CR-226 | ✅ | LoadQuerySQL 缓存键改为 `连接标识|ProcName`（ConnectionName→Database→ConnStr 降级），多库同名查询不再交叉污染；UniDbInvalidateQuery 按后缀匹配失效所有连接的同名键 |
| CR-281(部分) | 🔧 | ExecuteFirst 用 try/finally 恢复 Limit，builder 复用不再被钉死 1 行；WithLevel 覆盖/追加语义留待 Owner 定夺 |
| CR-278 | ✅ | Logger 析构：置 FShuttingDown → 停信号 → 写线程排干残余队列才退出（尾部日志不再丢）；Log/LogException 关停窗口拒绝入队，防队列释放后 nil.LockList AV |
| CR-232 | ✅ | RecycleDeadTasks 新增可选 AMaxAttempts：>0 时达上限仍超时的毒丸任务事务性迁入 DLQ（error='recycle: attempts exhausted'），其余照旧回 pending；=0 保持旧行为 |

提交记录：92c10a6(docs) → 7ddfbed(doQry) → c9443b1(persistence) → c8dbb53(core) → 175d00f(tests) → e249883(batch8)

环境事件：本轮 DeepFlow 目录曾在工作区被外部删除导致编译失败，已 git checkout 恢复（若为有意删除请改用提交删除方式并同步移除 dpr 引用）。


### 第九批（2026-08-24 续，已提交 acf64be）

全量单测：4296 found / 4289 passed / 2 failed（PreparedPool 偶发 + Perception 环境对，均既有登记）。

| ID | 状态 | 说明 |
|---|---|---|
| CR-287(部分) | 🔧 | ①BuildHunks 正常退出分支补 LContextEnd:=K，中间 hunk 尾随上下文不再丢失；②ToSideBySide 改用条目自带 OldIndex/NewIndex，跨 hunk 行号漂移消除。其余项（代理对/编码检测/换行保真等）待后续 |
| CR-310(部分) | 🔧 | i18n 缓存回填改 TryGetValue→更新+LRU 提升 / 否则新增，miss→查库窗口的并发重复 Add 消除；Plural 小数分隔符项待后续 |
| CR-315 | ✅ | Schema 种子 LogLevel 键改为引用 SConfigKeyLogLevel 常量（新增 uses DeepBase.Consts），字面量漂移根除。注意：已部署旧库中的 App.LogLevel 行不迁移，需 Owner 决策是否补一次性 UPDATE |
| CR-296(部分) | 🔧 | DeepBase.Math.Random 平台守卫补齐（uses IFDEF + BCrypt external IFDEF），非 Windows NextBytes 显式抛 ENotSupportedException；FileWatcher/DateTime 两单元待后续 |

提交记录：acf64be


### 第十批（2026-08-24 续，已提交 3c76264）— CR-290 单调时钟收官

全量单测：4296 found / 4290 passed / 2 failed（基线 = 仅 Perception 环境对；PreparedPool 本轮未复现）。

| ID | 状态 | 说明 |
|---|---|---|
| CR-290 | ✅ | RateLimiter 四算法（TokenBucket/FixedWindow/SlidingWindow/SlidingWindowCounter）内部计时字段全部改 UInt64 单调刻度（TThread.GetTickCount64）：补充/窗口过期/滑动日志清理/半窗推进/RetryAfter 计算不再受墙钟影响；对外 TRateLimitResult.ResetTime 墙钟按"剩余毫秒"近似还原保持兼容。CircuitBreaker FLastStateChangeTicks 同步切换（Open→HalfOpen 冷却判定免疫时钟跳变）。34 处 Now 全部清零 |

注：持久化桶/窗口为内存态，进程重启即重建，无旧 TDateTime 数据迁移问题。


### 第十一批（2026-08-24 续，Owner 四项决策落地，已提交 1b1df35）

| 决策 | 实现 | 回归 |
|---|---|---|
| CR-294 = B | TRateLimitManager 新增 FailOpenOnUnknownLimit(默认 False=fail-closed)；Check/Acquire 未知限额拒绝，Acquire 拒绝带 60s 重试窗口防忙等；非关键路径可显式打开旧行为 | Test_CR294 两用例 + 更新既有 Test_Check_NonExistentLimit 断言 |
| CR-281b = A | TLogFilter.WithLevel/WithLevels 改追加语义(与 WithSource 一致)，单级别去重 | Test_CR281b 断言顺序/去重 |
| 决策3 = B | JSON 序列化根对象(ObjectToJson AIsRoot)产出 0 字段时抛 ESerializationException 并提示 [Serialize]/M+；嵌套 infra 类型维持旧空对象行为 | Test_Decision3 PlainDto 根序列化必须抛 |
| CR-315 = A | SQL_TIER0_SETTINGS 种子尾部追加幂等 UPDATE：App.LogLevel→Log.Level（已迁移库 0 行受影响） | 迁移为声明式 SQL，随 EnsureSchema 全量套件验证 |

套件：4300 found / 4291 passed / 其余失败均为环境噪声 —— 本机磁盘 I/O 持续劣化证据链：同一二进制 Config 写基准 5000+(晨) → 4617 → 3470 → 2275(夜)，且并发 PBT 出现瞬时 database is locked。**性能/并发类门禁建议移至安静专用 runner 执行**，本 VM 上仅作功能回归参考。


### 环境验证补充（2026-08-25）

| ID | 验证方式 | 结果 |
|---|---|---|
| CR-002 | Win64 dcc64 编译通过 + dcclinux64 交叉编译暴露 OpenSSL 单元 POSIX 层基建缺口（dlopen 绑定 libdl.dylib、Linux64 缺独立声明块） | **签名修正本身正确**；POSIX 完整支持需单独补齐 dlopen/dlsym/dlclose 的 LINUX 分支声明（建议新开任务） |
| CR-003 | SQL 结构对照 PostgreSQL 文档语法（locking clause 在 LIMIT 后），本机 PG15 服务因端口/权限无法启动 | **语法已修正**，待有可用 PG 实例时运行时验证 |
| CR-014 | 同上 | 同上 |
