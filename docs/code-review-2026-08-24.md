# DeepBase 全库代码审查报告

- 日期：2026-08-24
- 范围：doQry（11 文件）、Persistence（32 文件）、Core（130 文件），共约 109,000 行 Object Pascal
- 方法：分 13 批逐行审查 + 关键发现人工复核（ABBA 死锁、ORM 参数错位、SKIP LOCKED 顺序等已亲验源码行）
- 定级：🔴 崩溃/数据损坏 · 🟡 功能缺陷 · 🔵 优化建议
- 性质：只读审查，未修改任何文件。行号以当日工作区为准。

## 总体统计

| 模块 | 🔴 | 🟡 | 🔵 |
|---|---|---|---|
| doQry | 8 | 12 | ~10 |
| Persistence | 9 | 30 | ~20 |
| Core | ~40 | ~150 | ~80 |
| **合计** | **~57** | **~190** | **~110** |

跨模块系统性主题（修复优先级最高的模式）：
1. **单例/SetXxx 热替换直接 Free 旧实例** → 在途线程 UAF（EventBus、Logger、AuthManager、TConfig.Default、KeyManager.SetInstance、DeepBase() 等至少 8 处同型）。
2. **持锁做 I/O 或执行用户回调**（HTTP、DB、磁盘、工厂、OnEvent 回调在临界区内）→ 全局停顿/死锁，遍布 Pool、WorkerQueue、IoC、LogAggregator、LogAlert、Authorization、PluginManager、Feedback。
3. **超时/关停后仍 Free 正在运行的线程或共享对象**（Pool.Shutdown、LLM.Destroy 5s vs 60s、Feedback 轮询线程、FileWatcher IRP、Resilience.Timeout ResultLock、MVVM TAsyncCommand）。
4. **区域设置相关解析/格式化**（Serialization 日期往返、Reflection FromString、i18n Plural 小数符、Config Float 读写、Diff 强制 UTF-8、JobQueue StrToDateTime）→ 跨机器数据损坏。
5. **递归无深度限制**（Template include/block、Expression、Diff 回溯、FeatureFlags 依赖环、StateMachine 父状态环、LLM Manager 分类环）→ 栈溢出或持锁死循环。

---

## A. doQry 模块

### 🔴
1. `doQry\src\uDoQryExecutor.pas:114-115,139-140` BindParams 对所有 JSON 数字一律 `AsFloat` 绑定 → 超过 2^53 的整数 ID（雪花 ID 等）精度丢失，可**更新/删除错误行**。修复：整数走 `AsInt64`。
2. `doQry\src\uDoQryDialect.pas:20-23` + Executor.CompileSQL：`HasLimitClause` 用 `PosText(' LIMIT ')` 探测全串，子查询含 LIMIT 时外层不再加 DefaultLimit → 安全行数上限失效，返回全表。
3. `doQry\uDoQryLegacy.pas:243-251` HandleParamValue ptInteger/ptFloat 分支把参数值原样拼进 SQL，无任何数值校验 → **SQL 注入通道**（legacy 路径）。
4. `doQry\uDoQryLegacy.pas:328-338` BuildDeleteSQL whereClause 为空时不拦截 → `DELETE FROM t` 全表删除（新版执行器有 GuardNonQuery，legacy 没有）。
5. `doQry\uDoQryLegacy.pas:631-682` ValidateSQL 的"自动修复"（补引号、`,,`→`,NULL,`、盲补括号）会静默篡改含此类字符的合法字符串数据 → 数据损坏。
6. `doQry\uDoQryLegacy.pas:601-626` StringToParams 中文冒号分支 `Copy(pair, colonPos+2)` 多吞值首字符（'：' 是单 WideChar，应 +1）；与 ParseParamString(+1) 行为互相矛盾。
7. `doQry\uDoQryLegacy.pas:1192-1221` IsWhereField 结束时 Close 共享的 aQry；随后 BuildWhereClauseFromDict(:1119) 对已关闭数据集 `FieldByName('proc_name')` → 动态字段已销毁，UPDATE 路径凡同时有 SET/WHERE 参数必抛"Field not found"，功能瘫痪。
8. `doQry\uDoQryLegacy.pas:686-704` GetLastInsertedRecord 用 `SELECT MAX(pk)` 取新插入 ID，并发插入下返回他人记录 ID；且硬编码 dtPostgreSQL 元数据查询(:744)。

### 🟡
- `uDoQryExecutor.pas` ExecNonQuery/ExecInsertReturningId：Commit 成功后若 DoQryLogEvent 抛异常进入 except 再 Rollback（当前 Tx.Rollback 有 FActive 守卫故安全，但依赖隐式约定，建议显式置 nil）。SQL 局部变量在异常处理器中可能未赋值（日志空 SQL）。
- `uDoQryExecutor.pas:27-39` IsSelectSQL 无尾随空格（'selectxxx' 误判）；WITH CTE 不识别 → 默认 LIMIT 不生效。
- `uDoQryExecutor.pas:41-44` HasWhere 归一化不处理换行 → `DELETE FROM t\nWHERE ...` 被误拦截。
- `uDoQryExecutor.pas:183-199` CompileSQL 向以 `;` 结尾的模板追加 LIMIT → 语法错误。
- `uDoQryExecutor.pas:341` SQLite last_insert_rowid() 受触发器插入影响可返回错误 id；ExecInsertReturningId 返回 Integer 装不下 bigint 主键。
- `uDoQryJsonParams.pas:13-27` 非法 JSON 静默当空对象（错误延迟到 ParamByName 才暴露）；TryAsISODateTime 把形如日期的普通字符串自动转 TDateTime 绑定，类型漂移风险。
- `uDoQryParamPool.pas` 版本探测使每次缓存命中都多一次 DB 查询，缓存收益减半（🔵/🟡 之间）；KeyOf 无 else 分支（新增枚举值时 Result 未初始化）；LoadQueryDef 未命中时返回空模板定义，报错语义差。
- `uDoQryLogger.pas:91` 时间戳格式带 'Z' 却写本地时间（Now）；`:100` params 原文拼入日志行可破坏 JSON 结构；GLogLock 双检初始化竞态。
- `uDoQryTxManager.pas:28` savepoint 名取 GetTickCount64 mod，同毫秒嵌套事务名冲突风险。
- `uDoQry.pas:53-65` DoQryRunInTx 的 except 中 Rollback 自身抛异常会吞掉原始业务异常。
- `uDoQryLegacy.pas:255-296` BuildWhereClause(TDataSet) 为死代码；SplitParameters/CreateParamsFromString/ExecuteSQL/GetQueryDef/GetDatabaseType/GetPrimaryKeyField/RightStr 均未被调用（约 300 行死代码）。
- `doQryMain.pas:287` GetTableList 的 Format 带 [DatabaseName] 但 SQL 无 %s 占位——参数被忽略，恒查 public schema；`:179-180` 遗留硬编码测试 INSERT（Button1Click）。
- 编码问题：doQryLegacy/doQryMain 大量 GBK/ANSI 中文注释乱码，与其他 UTF-8 文件混杂，违反 .editorconfig utf-8 约定。

---

## B. Persistence 模块

### 🔴
1. `DeepBase.DB.Pool.pas:1617-1621` GetStatistics 先 FStatsLock 后 FLock，与其余全部路径（FLock→FStatsLock）相反 → **ABBA 死锁**【已亲验】。修复：统一锁序。
2. `DeepBase.DB.Pool.pas:1052-1064` Shutdown 等维护线程 5s 超时后仍 FreeAndNil(FMaintenanceThread) → 释放运行中的 TThread，UAF。超时分支必须泄漏或延迟释放。
3. `DeepBase.DB.Pool.pas:1085-1095` 排空超时后 FPool.Clear 销毁 csInUse 包装器及底层连接 → 持有连接的工作线程 use-after-free。需墓碑化延迟释放。
4. `DeepBase.DB.DoQry.pas:1790-1802` UniDbSweepConnectionFromPool 不检查 InUseCount 即 Remove（doOwnsValues 立即析构）→ 并发在途查询 UAF。
5. `DeepBase.DB.JobQueue.pas:666-668` PG 出队 SQL `ORDER BY ... FOR UPDATE SKIP LOCKED LIMIT 1` —— 锁定子句必须在 LIMIT 之后 → **PG 上必然语法错误，出队瘫痪**【已亲验】。改为 `... LIMIT 1 FOR UPDATE SKIP LOCKED`。
6. `DeepBase.ORM.pas:1075-1078` CollectEntityParams 跳过所有主键而 BuildInsertSQL 只跳过自增主键 → 非自增主键实体 INSERT 参数整体错位一位，SQLite TEXT 主键下静默写入坏数据【已亲验，第二行条件还是死代码】。
7. Persistence 下 Config、License、I18n 三个 FireDAC 存储的 INSERT OR REPLACE 是"删行重插"：Settings.IsReadOnly/IsSystem/CreatedAt、License snapshot、I18n Context/IsVerified 等兄弟列每次写入被清零。改 ON CONFLICT DO UPDATE。
8. `DeepBase.Persistence.Authorization.FireDAC.pas:497-501,644-648` 单条 ExecSQL 内两条 DELETE 仅 SQLite 支持，PG prepared protocol 必失败（删除用户/角色在 PG 瘫痪）。
9. `Core\DeepBase.Random.pas:186`（Persistence 引用链相关，归 Core）：`(Value shr 11) * (1.0/(1 shl 53))` —— 32 位序数移位实际是 `1 shl 21`，NextDouble 返回域膨胀至 [0, 4.3e9]。

### 🟡（摘要）
- Pool：RegisterPool AddOrSetValue 静默析构旧池(:2063)；ShutdownAll 持全局锁逐池关闭(2104)；Initialize 持锁跨 DoWarmup 网络 I/O(992)；DoWarmup 回锁不复查 MaxSize(1697)；ConnectionString 含明文密码可被日志泄露(969)；ConnectionPool 本地异常类违反仓库体系(:46)。
- Factory：CredMan 失败+env 兜底路径写入悬空 credman: 引用(419-430)，系统被永久绑死在环境变量上。
- Guardian：新建空库后 TryDailyBackup 会用空库备份遮蔽真实旧备份（恢复出空库）(350-358)；隔离恢复依赖独占句柄前提未文档化。
- DoQry 封装：查询定义缓存仅按 ProcName 为键，多库交叉污染(276)；TryLoadQueryDef 吞掉一切异常伪装成 QUERY_NOT_FOUND(1047)；36 字符短横线串误走 StringToGUID 抛 EConvertError(856)（守卫函数写好却未接线=回归）；EnsureReturningId 子串探测过宽可静默返回 id=0(1539)；BuildSqlPreview 明文拼入参数 JSON(1710)；UniTransaction 析构/except 路径 Rollback 二次异常顶替原始异常(1336)。
- SQLLogger：EnsureLogsTable 失败也置 ensured 且 DDL 仅 SQLite 方言 → PG 数据库日志目标永久静默失效(563-586)；WriteToFile 锁外并发 Append/Rewrite 交错截断(355,514)；GetRecentLogs(-N) 负长度范围异常(657)。
- Migrations：文件名字典序排序，v10 先于 v2 应用(279)；裸 BEGIN IMMEDIATE/COMMIT 绕过 FireDAC 事务跟踪（存疑）；VACUUM INTO 失败后兜底 Copy 可能复制 WAL 活库。
- JobQueue：毒丸任务回收后 next_run_at=NULL 立即再投递，attempts 无界增长绕过重试预算(829)；EnsureSchemaIfNeeded check-then-act 竞态并发 ALTER 冲突(463)；池锁内 Open/provider 回调(275)；StrToDateTime 本地格式解析 ISO(1114)；PG/SQLite 两分支 SQL 完全相同的复制粘贴(1238)。
- StatusMachine：SQLite DEFERRED 读改写丢失更新，UPDATE 应加乐观守卫(381)；GetTableDef 锁外解引用裸指针，Clear/RegisterTable 并发 UAF(173)；心跳字典无界增长(459)。
- ORM：Count 保留 ORDER BY 在 PG 报 42803(987)；TableExists/CreateTable 硬编码 SQLite 方言，PG 不可用(1479,1380)；接口+对象所有权混用双重释放路径(1017)；Exists 走全表 COUNT(*)。
- 存储层共性：部分存储共享 FConnection 无锁（MRU/Config/Hotkeys/FormState/I18n/Security/Theme/Diagnose），与 Logging/License/Protection 加锁风格不一致，后台写日志并发即错乱参数；Diagnose 版本号字典序比较 '0.10'<'0.3'(268)、ColumnExists 唯一漏网标识符校验点(197)、AutoFix 吞异常(689)；IntentClarification 丢弃 Guardian 校验结果继续用坏库(131)、GetValue 缺键抛异常致默认值回填全不可达(339)；Logging legacy 回退永久"先失败再回退"(198)、枚举强转无范围校验(370)；Voiceprint 每次操作跑 4 条 DDL(96)、HMAC 常量 'veoice_' 拼写冻结注意勿单独修正(107)；Hotkeys RegisterDefaults 循环无事务(203)；License 析构不按范式取锁(60)。
- Authorization.FireDAC / 循环内 SetLength O(n²) 扩容（Authorization/FormState/TestHelper 共 7 处）。

---

## C. Core 模块（按域）

### C1. 加密与安全栈
🔴
1. `Crypto.OpenSSL.pas:156-158` PBKDF2 绑定签名多一个 digest_len 参数，POSIX 下整数 32 被当作 EVP_MD* 解引用 → Linux/macOS 构建全线崩溃或派生失效。
2. `KeyManager.pas:386-438` KEK 每次进程启动用全新随机盐派生且盐从不持久化 → 第二次会话所有存量加密密钥永久无法解密（用户数据丢失级）。修复：盐入库 + 启动试解密校验。
🟡（要点）
- SimpleCrypto MAC 钥 = HMAC(password) 单次哈希派生，离线爆破绕过 100k PBKDF2(AES.pas:166)。
- KeyManager Decrypt $02 前缀碰撞 + 空 v2 载荷 29 字节边界误判(968)；Rotate 未解密密钥会把密钥轮换成 0 字节(540)。
- TAESMode 暴露 ECB/CTR 等枚举但全部静默按 CBC 执行(377)。
- POSIX 机密存储主密钥熵全部来自公开信息(machine-id/USER/HOME)(Security.pas:299)。
- IsValidSecretName 前缀匹配误杀 com*/lpt* 合法名(858)；License CI 密钥硬编码进二进制(157)；LoadLicenseFromDB 用 Pos('table') 吞掉几乎所有 DB 异常(586)；CheckStrength 量纲错配恒 psVeryWeak(Services.Crypto:440)；完整性哈希先 UTF8.GetString 再哈希，二进制图片碰撞面大增(Services.Protection:596)；DecryptSensitiveData 不校验 IV 长度越界读(319)；legacy 无认证 CBC 回退默认可达（padding oracle 面）(Protection:637)；dlopen 绑死 libdl.dylib，Linux 必炸(OpenSSL:603)。
🔵：RSA CRT 字段缺 nil 检查、EVP padding 返回值忽略、DPAPI 口令缓冲不清零、RandomString 取模偏置、VerifyPassword 接受攻击者可控迭代次数、HexDecode 三副本行为不一、PBKDF2 四套实现并存（#1 即其漂移产物）、TAESCrypto 每次开关 provider。

### C2. 集合 / 内存 / 对象池 / 缓存
🔴
1. `Cache.pas:455-462` OwnValues 下对同一键重复 Put 同一实例 → 释放后指针重新入缓存（UAF）。
2. `ObjectPool.pas:886-888` Clear/析构销毁正在借出的对象（Shrink 都知道跳过 in-use，Clear 不知道）。
3. `Collections.pas:534-564` TCircularBuffer 容量 0 无校验 → mod 0 除零 + 越界写。
🟡（要点）：cepNone 实际执行 LRU 违背契约(Cache:739)；TSmartCache cepNone 满员判定 TOCTOU(Memory:917)；TMemoryTracker.FreeInstance 释放使用中的锁(1050)；双检锁外层裸读 ×2(Cache:1088,ObjectPool:1132)；TryAcquire 吞一切异常(580)；Acquire 异常压扁丢根因(568)；Release 静默泄漏外来对象(616)；GetTTL 过期条目返回正数剩余秒(1020)；TCountingSet.Remove 负数计数反向膨胀(Collections:1714)；TMemoryBlockPool 外来指针读头/Clear 连在用块一起释放(762,783)；TWeakRef<T> IsAlive 对已释放对象返回 True(1226)；对象池持锁执行用户回调/工厂/校验(ObjectPool:613)；TSortedList 与同单元其他集合口径不一完全无锁(29)；超时依赖墙钟 Now、BUG-120 单调时钟注释从未落地。
🔵：LRU 热路径 IndexOf O(n)；池 Acquire/Release 线性扫描；TDeque 队首 O(n)；负数长度直达 SetLength；GrowthFactor/FGrowBy 死配置。

### C3. EventBus / IoC / Scheduler / WorkerQueue
🔴
1. `WorkerQueue.pas:1560` 重复 Job ID 触发 doOwnsValues 替换释放仍在 FPendingQueue 中的实例 → UAF（LoadFromStorage 重复加载同样触发）。
2. `WorkerQueue.pas:821` TJob 托管字段（FProgressMessage/FStatus/FNextRetryAt）handler 线程无锁写、SaveToStorage 并发 ToJSON 读 → string 引用计数竞态堆腐败。
3. `EventBus.pas:381-397` SetEventBus 与惰性 EventBus() 并发 → 返回已释放实例。
🟡（要点）：订阅令牌 Unsubscribe 撞析构中的 FLock(455)；edmAsync handler 异常绕过 OnError 与统计(943)；ReplayHistory 持锁执行 handler(1144)；OnError/OnDeadLetter 回调自身抛异常中断派发(1071)；Scheduler 取消失效+循环任务复活(963)；依赖 RTL 线程池致 Stop/析构无限挂起(876)；上游失败下游照跑(928)；非法 cron 静默立即执行一次(693)；WorkerQueue 伪超时（超时后无限 WaitFor，副作用生效却记失败）(1937)；StopAll/SetWorkerCount 持注册表锁 join 工作线程死锁/冻结(2643,2348)；Enqueue 持锁做磁盘 IO+文件锁最长 5s 重试+用户回调(1564)；文件锁 fail-open 静默失效(1262)；裸 Exception.Create 克隆异常丢类型(1046)；ProcessJob except 内二次异常使任务永卡 jsRunning(2048)；IoC 单例构造/拦截器持全局容器锁(647)；ResolveAll StartsWith 前缀错配+重复解析默认注册(1165)；TryResolve 吞一切异常(1095)。
🔵：每次 Enqueue 全量重排 O(n²log n)+事件机制被 100ms 轮询架空；Stats 口径漂移可为负；事件类型白名单前缀过宽；GDefaultQueue 死变量；cron 日/星期 AND 语义偏离标准 OR（未注明）。

### C4. LLM 栈
🔴
1. `LLM.BillingClient.pas:809-815` SSE 按 4096 字节切块独立 UTF-8 解码 → 跨块多字节序列（中文/emoji 必现概率高）解码成 U+FFFD，长中文回复必然乱码。
2. `PromptTemplateManager.pas:610` include 递归无环检测/深度限制 → 互相 include 的模板栈溢出。
3. `LLM.pas:337-347` Destroy 仅 Wait(5000) 即释放 FHttpClient（HTTP 超时 60s）→ 在飞任务 UAF；同仓库 Manager 已有 BIZ-R3-002 正确方案未套用到门面类。
🟡（要点）：异常消息手拼 JSON 只转义引号(666)；ExecuteTemplate 的 SystemPrompt/Temperature 覆盖被 Chat(Name) 重取配置静默丢弃(964)；DefaultTimeout setter 不同步内置 client(293)；ChatAsync TThread.Queue 回调传悬空 Self(870)；LTask 先启动后赋值的捕获竞态(LLM:861,Manager:2015)；RecordCall 记账异常吞掉成功的响应(849)；BillingClient 两条路径错误契约不一致(697)；`as TJSONObject` 硬转义逃逸(559)；"流式"实为 Post 全量下载后内存重放(786)；SSE 要求 'data: ' 带空格不符规范行静默丢弃(612)；重试耗尽降级基础异常丢状态码+Sleep 阻塞 UI 最长 17 分钟(1070)；imOverwrite 先清库后无事务导入中途失败留空库(ImportExport:655)；模板导入可选键缺失静默跳过全部(759)；ExportPrompts 吞异常(424)；LLMBridge 未接超时感知回调，AITimeoutMs 形同虚设(57)；AI 分析把原始 E.Message（可能含凭据/连接串）发往外部 LLM(AIErrorHandler:202)；Config 类属性无锁写撕裂读(126)；分类 ParentId 环死循环(1044)。
🔵：AI 缓存满即整表清空；双份头数组易漂移；SSE 字符串拼接 O(n²)；RecordLLMCall 硬编码 LLMConfig 表名子查询；两套模板引擎大小写敏感不一致；Execute 二次 GetConfig 计价错位。

### C5. 日志与指标族
🔴
1. `LogQuery.pas:1475-1487` TopExceptions 切换数据源覆盖原 FDataSource 后自赋值"恢复"→ 分析器留下指向已 Free 的 TList 的悬空指针，之后任何调用 AV。
2. LogAggregator/LogAlert/Metrics 三处单例访问器缺终结期守卫（Logging 已有 GLoggerFinalized 模式未推广）→ finalization 后调用对 nil 锁 Enter AV。
🟡（要点）：Logger 析构不排干队列尾部日志丢失+并发 Log 踩已释放队列(329)；WriteToAggregator 是空操作假功能(547)；SetGlobalLogger 等 setter 就地 Free 使用中的回退实例(254)；Loki 批内时间戳截断秒级整批被拒(1086)；FLabels 无锁遍历 vs 加锁写(1078)；Webhook 自定义 Header 只写不发(1223)；推送/健康检查持锁做网络 IO+Sleep 退避最长 97s(1372)；告警评估全程持锁执行 webhook/回调(680)；ImportRules 丢弃 Condition/Actions 导入即哑规则(554)；告警缓冲满拒新留旧致 NoLogs 误报(1131)；TAlertRule 用户线程与 eval 线程零同步(459)；告警消息统计口径与窗口不符(1000)；GetStats(AFilter) 完全忽略过滤器(950)；WhereApp/Host/Environment/MessageMatches 全部降级为消息子串匹配(736)；Metrics Unregister 后外部持有的类指针悬垂(1426)；TMetricFamily.WithLabels 未知类型野指针入库(1313)。
🔵：每条日志开/关文件三重系统调用；FillChar 覆盖托管字段泄漏字符串；聚合缓冲满静默丢无计数；TPushResult 早退分支栈垃圾；日志队列无界无背压；ExecuteFirst 永久污染 Limit=1；WithLevel 覆盖式链式陷阱；FindPatterns 循环内编译正则+重复 key 异常；Benchmark PrivateUsage=PagefileUsage；HTML 导出 script 上下文注入面；多处 OutputDebugString/uses Winapi.Windows 缺 IFDEF；ISO 时间戳本地时间不带偏移。

### C6. 反射 / 序列化 / 数据绑定
🔴
1. `Serialization.pas:890-892` record 类型属性序列化为 `{}`、反序列化无 tkRecord 分支 → 静默双向丢数据；二进制 tkDynArray 同样丢。
2. `Serialization.pas:866` 日期固定 ISO 格式序列化、locale 相关 StrToDateTime 反序列化 → 非 y-M-d 词序区域必错乱（zh-CN/en-US 部署即触发）。
3. `Serialization.pas:1690` 二进制反序列化绕过 IsAllowedType 白名单 + kind 字节不校验 + ReadString 长度无上限 → 反序列化不可信载荷可任意实例化/OOM/AV。
4. `Serialization.pas:1029` GetEnumValue=-1 不检查直接 FromOrdinal；数字路径无范围校验 → 越界枚举静默写入业务对象。
🟡（要点）：默认仅 mvPublished 序列化，普通 public DTO 输出 {}(814)；MaxDepth 硬钳 8 使 API 参数无效(546)；JSON 类型不符硬 cast 无路径信息(1004)；TSerializationContext 空注册表使 JSON 多态判别器为死功能(502)；单例 Options 热路径直读撕裂(775)；反序列化中途异常泄漏半初始化实例(1056)；XML 手写扫描 Trim 丢空白、自闭合标签不识别(1357)；白名单 StartsWith 放行 TTimeoutPolicy 之类(606)；空输入 LBytes[0] R+ 越界(748)；ShouldSerialize 每属性重建属性数组无缓存。Reflection：FromString 数值静默归零/float 区域相关(1682)；InvokeClass 不校验 IsClassMethod 可把 metaclass 当 Self 踩内存(995)；伪深克隆只一层且无环检测(1292)；Equals 用 TValue.ToString 类名比较对象内容(1340)；列表识别仅按限定名前缀漏掉自定义容器子类(1934)；Try* 裸 except 吞业务异常(603)；锁剧场——仅 GetType* 持锁其余 95% 路径裸奔(414)。DataBinding：TObservableList OwnsObjects 下 Delete 先析构后通知，OldItem 悬垂(379)；同一 Source 多绑定共享一个 handler，Unbind 任一条即全体失聪(544)；TObservableObject 基于 TInterfacedPersistent，无 Owner 时 Supports(INotifyPropertyChanged) 恒 False，变更绑定核心链路对独立模型不工作（待实测确认）(107)；遍历 handler 中退订自身未快照(276)。ORM.Mapping：DefaultValueAttribute 把引号烘焙进值+FloatToStr 区域小数符产出坏 DDL(535)。

### C7. 模板 / 表达式 / Diff
🔴
1. `Template.pas:1942-1985` 条件比较 `=` 分支抢先捕获含 `=` 的 `>=/<=/!=` → 三种比较运算永远不可达，`{{#if count >= 5}}` 恒真/恒假随机。
2. `Template.pas:1576-1581` else 分支多内容节点逐个赋值覆盖 → 只输出最后一个节点。
3. `Template.pas:1713` RenderBlock 把 AST 拥有的 Children 注册进 FBlocks → 悬挂指针+双重释放。
4. `Template.pas:1657` include 无环检测/深度限制；Expression.pas 递归下降全程无深度限制（约定的 EExpressionTooComplexException 全单元零引用）→ 栈溢出。
5. `Diff.pas:1114` BacktrackLCS 深度递归（M+N 帧）大 diff 栈溢出；`:1083` ComputeLCS 全量 O(n×m) 矩阵（10k×10k≈400MB，字符级 100KB 文本需 40GB）。
🟡（要点）：Template 所有标签未闭合静默接受(659)；else 前缀误判吃掉 elsewhere 变量(764)；自定义分隔符下 {{{ 硬编码错乱+include 不继承分隔符(615)；函数参数/过滤器管道按裸字符切分粉碎引号内容(1517,811)；数组索引无边界检查(1767)；代理对按码元切割(truncate/first/last/foreach)；ParseNodes 异常泄漏半成品 AST(912)；缓存以 GetHashCode 为键冲突渲染错模板+无淘汰+非线程安全(2106)；父上下文裸指针(495)；AddObject 裸 except 吞 OOM(445)；数组值直接渲染必抛(2030)；random/range 溢出与资源放大(1337)；块嵌套深度无限制。Diff：NormalizeLine 在 O(n×m) 内层循环反复跑正则(1098)；中间 hunk 丢尾随上下文(1209)；ToSideBySide 跨 hunk 行号漂移(537)；CompareChars 代理对拆散(1314)；Apply 用 sLineBreak 重建静默改换行符(876)；IgnoreBlankLines 从未实现(37)；hunk 体 --- 行劫持为文件头(722)；hunk 头正则不容忍函数名注解(680)；IsBinary 三套语义混战(1605)；合并标记输出多余空行(1008)；CompareFiles 强制 UTF-8(1293)。
🔵：O(n²) 字符串累加遍布热路径；行列号记录偏移；json 过滤器控制字符不转义；Merge3Way 重复计算 4 次 LCS+异常路径泄漏；TDiffResult.Items 公开但恒空；Similarity 无护栏。

### C8. 插件 / Manager / Services
🔴
1. `PluginManager.pas:736,791,874` 卸载顺序倒置：接口引用（局部 Plugin、LoadedRec.Plugin、快照数组）存活到过程结束才 _Release，BPL 已 FreePackage → 跳入已卸载代码 AV（同仓库 Plugins.Manager:828 已记载正确顺序教训）。
2. `Plugins.Manager.pas:198-204` Lease 归还先 DecLease 后才清 FPlugin，drain 放行 FreeLibrary 与 _Release 竞态 → UAF。
3. `Plugins.Manager.pas:719` 并发/重复卸载无状态机防护 → 双重 TCAbiPlugin.Free / 双重 FreeLibrary。
🟡（要点）：加载不拒绝 psLoading/psUnloading 并发双加载泄漏实例与模块(511)；能力门禁失败实例已驻留注册表(584)；CAbi GetMetadata 抛异常泄漏对象与 DLL(560)；签名校验与 LoadLibrary 之间 TOCTOU(Verifier:159)；裸 LoadLibrary 相对路径 DLL 劫持面(CAbiLoader:157)；JsonBytesToMetadata 变量复用泄根树+将来补写即双重释放(Contracts:256)；HealthCheck 每次检查泄漏一个字典+全程 Monitor(106)；旧 PluginManager QueryInterface 写类类型变量永久引用泄漏(697)；锁内 LoadPackage/Initialize/FirePluginError(585,799)；IsValidPluginPath 大小写敏感误拒+junction 越界(1040)；LoadAllPlugins 无拓扑排序(836)；依赖大小写 SameText vs 敏感字典不一致(265)；卸载先 Shutdown 后 drain 倒置(799)；Operational 归档 INSERT/DELETE 非事务+时间列假设 ISO 文本(129)；Finalize 锁外读 FIsInitialized(793)；DeepBase() 单例无锁首查+SetDeepBaseInstance 释放在用实例(370)；WhenReady FReadyFired 竞态丢回调(823)；InitializeModules 半途失败残留半成品重试覆盖泄漏(887)；CAbiLoader/Plugins.Manager 大量裸 Exception.CreateFmt 违规(22 处)。
🔵：TwoPhaseFetch 零长度 R+ 越界+正数冒充错误码；SafeCall<T> 吞 OOM；Lease Sleep 轮询+墙钟；快照泄露裸 CAbiPlugin 指针；默认空密码注册保护服务；dbp_invoke_alloc 声明未接线。

### C9. 弹性 / 限流 / 状态机 / 授权
🔴
1. `Resilience.Timeout.pas:114-133` 超时后 Task.Cancel 不能中止已运行任务，finally 释放 ResultLock 后后台闭包继续 TMonitor.Enter → use-after-free；超时路径异常静默丢弃。
2. `Authorization.pas:1636,1104` FThreadCurrentUsers 持有 doOwnsValues 活体指针，DeleteUser 后悬挂 → 后续鉴权读到复用内存中**另一个用户的身份**（提权面）。
3. `StateMachine.pas:620-654` FindTransition 父链上溯无深度限制（IsInState 有 64 层防护这里没有），父状态环 → 持 FLock 死循环整机挂起。
🟡（要点）：断路器 pending 事件槽位覆盖丢失+ARM 可见性(227)；限流/熔断计时全部用墙钟 Now，NTP 回拨/DST 即失效(RateLimiter 多处+CircuitBreaker)；Bulkhead 快速路径空等满额 30s(177)；Bulkhead/Registry 析构不排空(86,551)；IgnoreIf 守卫永不生效等价无条件 Ignore(474)；动作用户回调持锁+同线程重入 Fire 被外层覆盖+动作异常无回滚(715)；IsValidState 恒真+FromJSON 字符串状态机任意注入(1198)；UpdateUser 只落库不同步活体权限变更不生效(1092)；令牌校验与会话建立两临界区 TOCTOU+明文 token+SameText(1611)；审计回调与 DB 写持锁(933)；SetAuthManager 直接 Free 使用中的管理器(519)；CheckAll 多限额非原子已扣不回滚(1289)；未知限额默认放行 fail-open(1275)；FixedWindow 等三种算法构造参数 0 不校验限流失效(546)；Retry.TryExecute 异常压扁成裸 Exception(396)；IRateLimiter 与 IPermissionClient **GUID 完全相同**(占位符没换)(Permissions.Contract:46)；facade 与 impl 各建一套断路器注册表分裂(F-20)；组合策略 bulkhead 最外层重试霸占舱位+对熔断异常照撞(Policy:159)。
🔵：deprecated AllowRequest 半开名额泄漏+OnRejected 锁内触发；rmwWarn 无 handler 等于 Allow；rsJitter 未实现落 else；initialization Randomize 全局 RNG；策略每次调用重建；多数模块异常未挂 EDeepBaseException；GetAllPermissions/CurrentUser 违反克隆纪律残留；HasAnyPermission 逐项加锁全量重算；Start 先置标志后 entry。

### C10. 日期 / 数学 / 校验 / 文件监控 / 压缩
🔴
1. `FileWatcher.pas:579-591` Stop 分支不 CancelIoEx，CloseHandle 异步取消期间内核仍写已释放的 OVERLAPPED/置信已关闭事件 → UAF。
2. `FileWatcher.pas:944-954` 防抖闸门 Count>0 分支注释撒谎无 re-arm 代码 → 闸门永久闩死，后续全部变更静默丢失。
3. `FileWatcher.pas:749-755` 析构用 Sleep(50) 兜底与在飞防抖任务的竞态 → UAF。
4. `DateTime.pas:659-665` CurrentUtcOffset 忽略 DaylightBias → DST 期间 RFC2822 偏移错 60 分钟。
5. `DateTime.pas:1333-1351` RoundToMinute/RoundToHour 进位 60/24 不回绕 → EncodeDateTime 抛 EConvertError（每小时 xx:59:30 后必触）。
6. `Validation.pas:884-915` ReDoS"超时保护"共享标志无同步 + 弃线程继续跑灾难性回溯（CPU 灼烧+线程堆积）。
🟡（要点）：Math.Random/FileWatcher/DateTime 平台 API 无 {$IFDEF MSWINDOWS}（仓库硬约定）；FileWatcher 回调线程模型不一致（默认防抖即混发主线程/池线程）+无泵进程收不到 Queue 事件；ReDeepMoveCallback 清空全部回调+命名损坏；IncludeHidden/System/MinSize/MaxSize 四过滤字段死配置；Manager 白名单过窄（Documents/Temp/exe 之外全拒）与 Builder 入口不一致+'..' 误伤+硬编码 C:\WINDOWS；Compression 取消语义缺失（压缩留截断流正常返回、解压忽略取消）；ZipWriter.CompressionLevel 从未生效；TryFromISO8601 会 raise+忽略时区偏移+小数秒(707)；军用时区 J 映射 +10h(873)；四个模块异常基类绕过 EDeepBaseException 体系(V2)；TInRule ToString 类型混淆匹配(1043)；Product([])=0 违反空积单位元(Statistics:253)；P/C 被 Factorial N≤20 人为卡死(Math:414)。
🔵：TRandomDist 全局 Random 非线程安全仅一个方法有锁；NextInt 取模偏差；LCM/NextPrime 无 Int64 溢出防护；Mode 平票不确定；R² 退化伪值 1；Matrix3 零填充非法长度；向量绝对 epsilon；Interpolation T>1 NaN；fctAttributes 死枚举；每事件 DirectoryExists；Start 失败 Running 仍 True；AddStream 全量载入内存；Builder 文件操作无视 Format。

### C11. 配置 / 特性旗标 / 反馈 / 生命周期
🔴
1. `Feedback.pas:1838-1847` 提交失败 Enqueue 接管 OwnsObjects 所有权但调用方仍持有并 Free → 悬垂；ProcessOfflineQueue 失败再次 Enqueue 已在队列的对象（重复指针）+成功路径 Dequeue 结果不 Free 泄漏。
2. `Feedback.pas:2114` 轮询/提交线程 FreeOnTerminate 从不 WaitFor，析构释放 FClient/FOfflineQueue → 间歇 AV。
3. `Configuration.pas:1321` 监视线程 Synchronize(Reload) + 主线程 StopWatching WaitFor → 经典互等死锁；无消息泵宿主热更新永久失效。
4. `FeatureFlags.pas:904` 依赖求值环形无限递归（TCriticalSection 同线程可重入不阻断）→ 栈溢出；ImportFromJSON 接受任意外部依赖图。
🟡（要点）：Configuration Reload 三段持锁间 SetValue 被静默清除(1238)；Reload 持锁 NotifyChange(1252)；TConfig.Default 裸指针+SetDefault FreeAndNil 在用实例(1454)；解密失败静默回退密文本体当凭据(806)；JSON 解析失败静默空字典(650)；Config Float 读写未固定 Invariant 区域跨机器损坏(379)；AppLifecycle AcquireSingleton 检查创建非原子句柄泄漏(244)；WaitForShutdownSignal 与 Reset 销毁事件竞态(462)；SingleInstance 空串 @DataBytes[0] R+ 越界(197)；WM_COPYDATA 无发送方校验本机任意进程可注入命令行(280)；RegisterClass 失败静默 IPC 失联(242)；FF WithGroups 不写 groupId 属性按组定向永不命中(490)；EnableFlag 持锁触发 OnFlagChanged(1822)；GetVariant/GetAllFlags 返回 doOwnsValues 裸指针悬垂(1687)；FlagStorage Save 非原子覆写+损坏文件静默空集导致全部旗标复位(1414-1451)；Clone 经变体字符串化类型漂移+Payload 不参与序列化(1231)；semver 非法版本判相等(590)；schedule Timezone 字段从未参与计算(842)；Manifest Verifier ISO8601ToDate(S,False) 把 UTC 当本地 → 有效清单提前 N 小时过期/过期清单多活数小时(188)；schema_version 定义了但从不校验(34)；RuntimeContext Shutdown 单组件异常中断后续组件收尾+析构期异常逃逸(327)；SplashScreen OnFadeTimer 内 Sleep(3000) 冻结消息泵(344)；反馈默认采集全量系统信息+崩溃打包 50MB 日志+上传本地路径+匿名请求带 X-User-Id（隐私面）(984)；DoRequest 持锁 HTTP 最长 90s(1315)；zip 条目同名覆盖(1199)。

### C12. Schema / SQL 工具 / i18n / Hotkeys / MVVM / 杂项尾部
🔴
1. `Export.PDF.pas:729-771` CID 字体对象号预留逻辑与写死引用 ObjNum+1 脱节 → 含文本的 PDF 必然产生重复对象编号，xref 损坏。
2. `UITest.FmxProbe.pas:283-366` 服务线程直接遍历 FMX 控件树 + 直接调用可能为 nil 的 OnClick 方法指针。
3. `TrayIcon.pas:226-234` Hide() 无条件 DestroyIcon 调用方拥有的 HICON（UI2-014 修泄漏引入所有权缺陷）。
🟡（要点）：i18n 缓存 miss→回填 TOCTOU 重复 Add(552)；CLDR 复数小数操作数依赖本地化分隔符(Plural:195)；FormState 仅识别类名含 Form 的窗体(288)；MVVM 异步错误回调裸 Exception.Create 丢原始类型(632)；TAsyncCommand 关闭超时放弃等待后闭包悬空 SelfRef(503)；TestHelper 模拟点击移动真实光标投全局点击(630)；MRU 持锁做 UNC FileExists 最长 30s+(270)；VirtualScroll 每像素滚动 O(n) 全量和+锁内渲染回调(521,797)；导出 CSV 公式注入/DOCX XML 属性注入/PDF BaseFont 名称对象未转义(Export:242,DOCX:352,PDF:760)；SchemaAdapter.Registry Validate 异常击穿 TryResolve Boolean 契约(111)；Gender 懒初始化无锁与 PluralRules 不一致(297)；Theme ApplyTheme Synchronize 关停期挂起(261)；Consts 'Log.Level' 与 Schema 种子 'App.LogLevel' 漂移——常量读取永不命中种子行(Consts:49)；多个文件中文注释 UTF-8→CP1252 双重编码乱码（TestHelper/Constants/i18n 等，违反 .editorconfig）；SQL.Splitter END 后缀误判 DESCEND+未闭合注释静默丢弃；存储模块普遍持锁做 DB I/O（i18n/Hotkeys/FormState/Theme/MRU）。
🔵：WeChat 适配器指纹占位值待复核；TFmxProbe GServer 从不释放；热键 Scope 不持久化疑似缺口；TN() 不替换数量占位符与 TranslatePlural 行为不一。

---

## D. 修复路线建议

1. **第一批（数据丢失/安全，本周）**：KeyManager 盐持久化(#C1.2)、JobQueue PG 出队 SQL(B.5)、INSERT OR REPLACE 三处(B.7)、ORM 参数错位(B.6)、doQry 数字 AsFloat 精度(A.1)、legacy 注入与全表删除(A.3/A.4)、授权线程上下文悬垂提权(C9.2)、GUID 占位符重复(C9)、NextDouble 移位错误(B.9)。
2. **第二批（崩溃/UAF，两周内）**：全部"Free 运行中线程/共享实例"家族（主题 3 清单）、插件卸载顺序(C8.1-3)、FileWatcher 三连(C10.1-3)、Timeout/Feedback/Configuration 死锁族、Serialization record/locale/白名单四连。
3. **第三批（功能正确性）**：模板比较运算/else、Diff 算法、LLM SSE 解码、限流墙钟换单调钟、ValidateSQL 自动修复移除、Migrations 排序。
4. **第四批（系统性重构）**：统一"锁内快照、锁外 I/O/回调"纪律；统一单例 SetXxx 延迟释放协议；收敛 HexDecode/PBKDF2/异常基类到 DeepBase.Exceptions；清理各单元死代码与假配置项；全库编码统一 UTF-8 重写乱码注释。
5. **测试补强**：每个 🔴 修复配一条 DUnitX 回归（尤其 PG 方言路径、并发压力、非 zh-CN 区域设置矩阵）；现有测试明显未覆盖 POSIX/OpenSSL、PG JobQueue、多库缓存隔离场景。

> 备注：报告由多批并行审查汇总，个别行号可能因后续编辑偏移；存疑项已在各节标注"待确认"，不应未经复测直接当缺陷修复（如 DataBinding Supports 行为、Merge3Way 对齐假设、JCS 游离语句原意）。
