# deepBase 开发任务
> **最后更新**: 2026-05-14
> **项目状态**: 框架主体已完成；DeepKit DB4 统一认证/支付后端已独立部署到服务器，当前进入备案/DNS/HTTPS、微信支付接入、IntentClarification Phase 2 接入修复、全局生命周期协议和发布门禁可信化阶段。
> **维护规则**: `tasks.md` 只保留当前待办和下一步任务；已完成任务归档到历史文档；Bug 修复记录写入 `bugfix.md`。

---

## 文档导航

| 文档 | 说明 |
|------|------|
| [README.md](README.md) | 项目说明 |
| [docs/DeepBase-Integration-OneFile.md](docs/DeepBase-Integration-OneFile.md) | 对外唯一集成入口 |
| [docs/DeepBase-Downstream-Integration.md](docs/DeepBase-Downstream-Integration.md) | 下游项目接入说明 |
| [docs/DeepBase-DB4-后端开发交接-王维.md](docs/DeepBase-DB4-后端开发交接-王维.md) | DB4、收费、授权、升级后端交接文档 |
| [bugfix.md](bugfix.md) | Bug 修复记录 |

---

## 当前判断

- deepBase 已具备桌面公共库雏形，但不能再标记为“P0/P1/P2 清空”。
- 当前上线风险和交付缺口集中在 6 个方面：DB4 收费后端实部署、许可证/支付回调安全边界、包分层失真、迁移/schema 漂移、并发生命周期、发布门禁可信化。
- DB4 生产链路必须放在服务器侧实现，桌面端只能调用安全 HTTP API，不能直接写订单、支付、权益表。
- 免费版升级收费版的生命周期应由服务器完成：登录、创建订单、支付回调、发放权益、签发许可证快照、开放付费更新通道。
- LLM 已具备五模型槽配置契约和基础调用能力；下游可以先按 facade/API 集成，UI 配置面板和更完整 fallback 仍需继续强化。
- ICS 不作为当前 P0 主线重写目标；应做成可选网络传输适配层，不能让 Core 强依赖 ICS。
- 桌面工具型产品的上线公共能力要形成标准套件：自动升级、付费升级、权限控制、托盘、热键、语音录入。
- 2026-05-09 五专家审阅后，Unit/Integration/rename gate/Web/API 安全默认值/客户端许可证快照已收敛并通过门禁；`LLMPromptTemplates` schema 漂移、PromptTemplate `DefaultValues` 生命周期泄漏和 `TSimpleCrypto` 错密码/未认证密文问题已修复。仍不能按最终发布处理，DB4 服务端签发、全局生命周期协议和包 DAG 拆分还在 P0/P1 待办中。
- 2026-05-13 DB4 命名和部署边界已调整：服务器统一使用 `deepkit` / `deepkit.top`，`goodmem.cn` 不再作为统一认证/支付中台。新服务为 `/srv/deepkit.top/app/current/backend` + `deepkit-api.service` + `deepkit` 数据库；服务器本机 `/dk` 主链路已通过。当前商用外网阻塞为备案未完成、`deepkit.top` DNS/HTTPS 未完成、微信支付真实商户配置未接入。
- 2026-05-13 DB3 下游矩阵已落地：`devdb/bizdb/noveldb` 已创建各产品 schema 和最小业务表/registry，DeepShine 已补跑 001-006 PG 迁移；明细见 `docs/64.backend.DB3-DB4下游产品数据库矩阵.md`。下一步是补最小权限运行账号和各产品正式业务 API。
- 2026-05-14 IntentClarification 五专家审阅完成：Phase 2 新单元已纳入包/主测试并恢复编译，IC targeted 20 tests 已通过；公开工厂仍返回空 facade，DomainAdapter slots、Provider 状态隔离、Engine 并发、Router 边界和 LLM/L4 降级语义仍是后续 P0/P1 风险。
- 2026-05-14 直接运行完整 `Tests\DeepBaseTests.exe` 当前不再是全绿：3372 found，3351 passed，3 ignored，6 failed，12 errored。失败集中在 Browser Registry/WindowPool/Automation、FeatureFlags rollout range check、License legacy signing 测试环境、DB.DoQry DDL gate 和 Performance benchmark，需纳入 QA 后续收敛。
- 2026-05-14 DeepShell VCL 桌面壳第一版骨架已落地：15 个核心单元 + Demo 项目独立编译通过，runtime 包已纳入 `DeepBaseVCL.dpk`；五专家审阅 P0 缺陷（EventBus UAF、OnShow/OnClose 钩子可被覆盖、RefreshBottomLog O(N²)、svkHtml/svkMarkdown 渲染源码、wsMinimized 坐标）已修复，剩余 P1 项（i18n caption、StatusManager redaction、ProjectPath PII、设置页 GroupName、DPI 缩放）汇入 `DESKTOP-P1-2026-05-14`。下游 VCL 桌面工具应从 `TDeepMainForm` 起步。

---

## 需求追踪矩阵

| 用户要求 | 落地任务 | 当前状态 |
|----------|----------|----------|
| 整个体系已改名为 deep，框架名为 deepBase | `ARCH-P0-001` | 已完成，改名残留检查已并入包门禁（CI 串联仍在 `QA-P0-001`） |
| 桌面软件上线后需要收费、认证和授权系统 | `COM-P0-001`、`SEC-P0-001`、`APP-P0-001` | 进行中，桌面端安全 SDK/权限 facade/付费升级 facade 已完成，服务器实部署仍待王维完成 |
| 收费后端应在服务器开发，不能让桌面端直连收费数据库 | `COM-P0-001`、`COM-P1-001` | 进行中，桌面端只走 `/dk` 安全 API，server-admin adapter 默认受保护 |
| DB4 使用腾讯云数据库，服务器侧还要创建 PostgreSQL 数据库 `deepKit` | `COM-P0-001`、`OPS-P2-001` | 已调整为数据库 `deepkit`；服务器已部署 `deepkit-api.service`，备案/DNS/HTTPS 仍待完成 |
| 免费版升级到收费版，需要支付、权益、许可证和付费更新通道 | `COM-P0-001`、`SEC-P0-001`、`UPD-P0-001` | 进行中，客户端流程 facade 已完成；DeepKit 服务器认证/订单/权益/license snapshot 已部署，真实微信支付和公网 HTTPS 待接入 |
| 网站上支持免费更新和付费升级 | `UPD-P0-001`、`PRODUCT-P2-001` | 待开发 |
| LLM 能交给下游使用，并提供 5 模型配置面板：聪明、平衡、快速、生图、图片兜底 | `LLM-P0-001` | 进行中，五槽位契约/生图基础调用/配置读取测试已完成，UI 面板仍待强化 |
| ICS 是否全力接入 | `NET-P1-001` | 已按可选 adapter 处理，不进入 P0 主线、不污染 Core；仓库不内置 Overbyte ICS 源码 |
| 桌面工具型产品需要自动升级、付费升级、权限控制、托盘、热键等常用功能 | `APP-P0-001`、`UPD-P0-001`、`SEC-P0-001`、`TRAY-P1-001`、`HOTKEY-P1-001` | 进行中，托盘/热键/权限 facade/付费升级 facade/桌面生命周期 facade/VCL-FMX helper/E2E 已完成，完整模板仍待补齐 |
| 支持语音录入，用于 LLM 输入、表单输入和命令触发 | `SPEECH-P1-001` | 进行中，录音/VAD/Baidu ASR/权限配额接入已完成，VCL/FMX 输入控件仍待补齐 |
| deepBase 库需要持续维护和架构优化 | `ARCH-P1-001`、`QA-P1-001`、`DB-P0-001` | 待开发 |
| 5 位架构专家建议要转化为可执行治理项 | `AUDIT-P0-2026-05-09`、`ARCH-P1-001`、`QA-P1-001`、`COM-P1-001`、`NET-P1-001` | 当前可复现 P0 已收敛并通过门禁，剩余为服务端实部署和较大架构治理项 |
| 下游项目需要明确哪些用 DB3/DB4，并把 PG 数据库建好 | `DB3-P0-2026-05-13`、`COM-P0-001` | 已完成首轮矩阵和 DB3 schema/table 初始化；DB4 待补 GuidedUse/DeepGuide/DeepAssist/DeepInsight/DeepRenew/DeepDevLite/DeepUITest SKU |
| IntentClarification 需要形成可编译、可测试、可接入的下游澄清模块 | `IC-P0-2026-05-14` | 进行中：编译/包/主测试接入和最小 Integration 已恢复；公开 facade 与运行时语义继续修复 |
| 下游 VCL 桌面工具需要一个统一的母窗体（菜单、托盘、MRU、布局、主题、设置宿主、命令治理） | `DESKTOP-P1-2026-05-14`, `DESKTOP-P1-2026-05-14-AUX` | 第一版骨架已落地（15 单元 + Demo），P0 缺陷已修复；剩余 i18n/redaction/PII/DPI/governance audit 项汇入 P1 |

---

## P0 当前开发（Blocking）

### IC-P0-2026-05-14: IntentClarification Phase 2 接入和缺陷收敛
- **状态**: 进行中，编译接入已恢复
- **目标**: 让 `DeepBase.IntentClarification.*` 从草案代码变成可编译、可测试、文档可照抄的下游接入模块。
- **来源**: 2026-05-14 五专家审阅；缺陷登记见 `bugfix.md` 的 BUG-134 ~ BUG-143。
- **任务**:
- [x] 将 `DeepBase.IntentClarification.Types/Interfaces/Engine/IoC/Provider.L0-L4/Session/SessionFSM/Router/SignalDetector/Budget/Exit/OptionFrame/Storage/Metrics/FeatureConfig/Templates/Validation/LLMResilience` 纳入 `DeepBaseFeatures.dpk/.dproj` 和主测试编译链。
- [x] 统一核心类型契约：`TOptionItem`、`THypothesis`、`TBudgetConfig/TBudgetStatus`、`TRapportProfile`、`TSessionCheckpoint`、`TPresetTemplate`，先消除编译阻塞。
- [ ] 合并或删除空的 `IClarificationEngine` facade，确保 `CreateEngine/CreateEngineWithPreset` 返回真正的 `TClarificationEngine` 或明确引导到 IoC 创建路径。
- [x] 补完整 `DeepBase.IntentClarification.Registration.pas`：`RegisterAll`、`RegisterDomainAdapter`、`RegisterPresenter`、`RegisterPersonaRegistry`、`RegisterLLM`、`ApplyPreset`。
- [x] 修复 IoC 默认 provider 注册：L1 optional constructor 不再被 RTTI 错解析，L2-L4 注册进入 IoC；未配置 LLM 时 Engine 跳过 LLM provider，避免最小集成路径误报 `PROVIDER_ERROR`。
- [ ] 将 `IDomainAdapter.GetPresetSlots` 接入 Engine/L1 Provider，请求中必须带 slots，避免 L1 空槽位误判 `icsReady`。
- [ ] 修复 Engine session 并发：同一 session 的 `SubmitInput/Suspend/Resume/Cancel` 串行化，`FHistory/FTokenUsage/FSessions` 统一锁策略，预算耗尽路径也记录最后一轮历史。
- [ ] 将 L2 denied hypotheses、L3 current expert 改为 session-scoped；session 完成/取消时清理 provider 状态。
- [ ] 修复 Router `MaxLevel` 边界钳制和无信号自动升级策略，避免 L1/L2 被边界误升。
- [ ] 修复 LLM resilience：超时必须可中断或由 HTTP 层 enforce；失败结果写入 `ErrorMessage`；`GenerateImage/Stream` 明确是否参与熔断。
- [ ] 修复 L4 全链路失败仍 `Success=True` 的语义，要求所有专家/综合失败时返回 degraded failure。
- [ ] 接入 `TICFeatureConfig`、`TICMetrics`、`TClarificationStorage` 到真实 Engine 生命周期，删除死接线或补齐注入。
- [x] 将 `Test.DeepBase.IntentClarification.Integration` 接入活跃测试入口，并通过 IC targeted 20 tests。
- [ ] 补 IntentClarification 包边界、slot 注入、并发和降级语义回归用例。

### DB3-P0-2026-05-13: 下游产品 DB3/DB4 矩阵与服务器初始化
- **状态**: 已完成首轮，进入产品 API/SKU 细化
- **产物**:
- [x] 阅读下游文档并形成 DB3/DB4 判断矩阵：`docs/64.backend.DB3-DB4下游产品数据库矩阵.md`。
- [x] 服务器只读审计：确认现有数据库为 `deepkit/devdb/bizdb/noveldb/configdb/goodmem/postgres`，DB4 `deepkit.products` 已有首批 SKU。
- [x] `devdb` 已建：`progee_core/progee_app_common/progee_app_self/deepdevlite/deeprenew/deepllm/deepcompare/deepuitest`。
- [x] `bizdb` 已建：`deepshine/guideduse/deepclip/deepinsight/common/senate_app/litellm/deepguide/deepassist`。
- [x] `noveldb.deepstory` 已做预留 registry；DeepStory 当前仍按 SQLite 2+X，不迁公网 PG。
- [x] DeepShine 已跑 `Migrations/pg/001-006`，当前 `bizdb.deepshine` 37 张表。
- [x] `.env` 已补 DB3 schema 映射；明文密码仍只维护在既有 `PG_*_PASSWORD` 项中。
- [ ] 为 DB3 各 schema 创建最小权限 runtime role，避免后端长期使用 admin 账号。
- [ ] 冻结并写入待补 DB4 SKU：`guideduse/deepguide/deepassist/deepinsight/deeprenew/deepdevlite/deepuitest`。
- [ ] 为 GuidedUse、DeepGuide、DeepAssist、DeepInsight、DeepRenew 补业务 API 文档和迁移脚本。

### AUDIT-P0-2026-05-09: 五专家审阅缺陷修复
- **状态**: 进行中
- **目标**: 将 2026-05-09 架构、并发、持久化、安全、测试发布审阅中发现的问题收敛为可验证修复。
- **任务**:
- [x] 当前 Unit 门禁必须恢复通过：`Test.DeepBase.TrayIcon` 5 个失败和 `Test.DeepBase.PluginManager.Test_GetPluginDataPath` 权限错误已修复；2026-05-09 完整 Unit 为 3243 tests，3240 passed，3 ignored，0 failed，0 errored，0 leaked。
- [x] 修复 CI rename gate 误杀：`Scripts/check_rename_residue.ps1` 不再把合法 `DeepBase` 当残留，只检查真实旧名 `UniBase/UniFlow`，并已清理 guarded scripts 中的旧名残留。
- [x] 修复 Integration 漏跑：`Test.Integration.WebAPI` fixture 已注册，`run_tests.ps1` 已支持最低测试数检查；Integration 当前 10 tests passed。
- [x] 修复 SQLLogger schema 漂移：写入 `Logs` 时使用 `LogLevel/LogTime`，数据库写入失败会输出 debug 降级错误。
- [x] 修复压缩/备份/云下载 Zip Slip 和对象 key 路径穿越：解压/下载写文件已 canonicalize 并确认位于目标根目录下。
- [x] 修复插件配置命名空间：插件启停配置使用 `Plugin.` 约定，加载阶段会拦截 disabled 插件。
- [x] 修复 RBAC wildcard 越权：`orders.*` 只匹配 `orders.` 前缀的请求权限，inactive user/role 默认拒绝。
- [x] 支付回调必须 fail-closed：Commerce PaymentBridge 对 Stripe/PayPal 使用 raw body + headers 验签；微信 V3 在未完成头验签/AES-GCM 解密前不会返回成功。
- [x] 客户端许可证快照必须 fail-closed：`TDeepKitSafeClient` 已要求 `snapshot_id/issued_at/expires_at/payload/signature/key_id/schema_version`，过期、app/device mismatch、缺 verifier/public key、验签失败均拒绝；Windows 下支持 RSA-SHA256 PEM 公钥验签。
- [ ] 服务端许可证机制必须替换：DB4 服务端私钥签发、撤销版本同步、公钥轮换和离线宽限策略仍需实部署。
- [x] 许可证 legacy 本地签发默认关闭：客户端不再内置生产共享签名密钥，旧 HMAC 许可证只允许通过 `DEEPBASE_LEGACY_LICENSE_SIGNING_KEY` 显式迁移或 CI 测试通道使用；服务端私钥签发和撤销策略仍在 `SEC-P0-001`。
- [x] 迁移引擎脚本解析、诊断和并发锁收敛：SQLite trigger body 不再被 `;` 错拆；迁移脚本内 `BEGIN/COMMIT/ROLLBACK/SAVEPOINT` 等事务控制 fail-fast；checksum mismatch 会记录 `FailedScript`；SQLite 执行迁移前使用 `BEGIN IMMEDIATE` 写锁并在锁内二次检查版本。
- [x] 修复 LLM prompt template schema 漂移：`Core/DeepBase.LLM.pas` 使用的 `LLMPromptTemplates` 已加入 `Core/DeepBase.Schema.pas` 和 `data/create_sample_db.sql`，`Test.DeepBase.LLM.PromptTemplate` 已重新接入 Unit runner 并通过 14 个测试。
- [x] 收敛 LLM PromptTemplate `DefaultValues` 生命周期泄漏：新增 `TLLMPromptTemplate.Clear` 显式释放协议，框架内部、Studio 模板界面和 PromptTemplate 单测已对 `GetTemplate/GetAllTemplates/GetTemplatesByCategory/Clone/Import` 返回或创建的字典补齐释放；`DeepBase.LLM.PromptTemplate` 14 tests passed，0 leaked，退出无 FastMM unexpected memory leak。
- [x] 恢复 Studio Win64 工程编译：修复 DoQry 数据集类型漂移、LLM 配置/Prompt Debug 表单损坏字符串与缺失 uses、LLMFrame 事件声明缺失、QueriesFrame 缺失最小 DFM；`Tools\Studio\Studio.dproj` Debug Win64 编译通过。
- [ ] 迁移/schema 剩余治理：继续审计现有脚本与 `Core/DeepBase.Schema.pas` 的剩余表结构漂移。
- [x] CloudBackup 生命周期收敛：scheduler/backup/restore 线程不再 `FreeOnTerminate=True` 后丢引用；`Stop/Cancel/Destroy` 会 signal 并 `WaitFor` 后释放。
- [ ] 全局生命周期协议仍需统一：连接池/WorkerQueue/Scheduler/FileWatcher/Updater/EventBus 必须阻止新任务、取消/等待后台任务、归还或转移借出资源后再释放内部结构。
- [ ] 包 DAG 必须重切：`Core -> Services -> {Persistence, Features} -> {VCL, FMX}`，Services 禁止 `vcl/FireDAC/dbrtl`，运行时包不得包含测试辅助单元。
- [x] 清理重复 unit：已删除 34 个 `VCL/UniBase.VCL.*` 旧文件；源码/包/工程中不再引用 `UniBase.VCL`。
- [x] Regression runner 和过滤门禁必须可信：`Test.WebService` 已接入 `DeepBaseTests.dpr`，`NET` module alias 只运行已注册 fixture；`-CI -SkipCompile` 禁止，CI 过滤运行必须显式 `-AllowFilteredCI`。
- [x] Web/API 安全默认值 fail-fast：WebSocket 默认不再放行 `*` origin；query `api_key` 默认关闭；弱 JWT secret 拒绝；JWT verify 使用常量时间比较；默认 500 不回显 `E.Message`；HTTP CORS middleware 默认不写 CORS 头。
- [x] `TSimpleCrypto` 错密码和密文篡改 fail-closed：新密文使用版本头 + HMAC-SHA256 认证封包，解密前常量时间验签；旧 `IV||Ciphertext` 格式保留兼容读取，PKCS#7 padding 完整校验，UTF-8 解码错误统一转换为 `ECryptoException`。

### QA-P0-001: 测试和 CI 门禁可信化
- **状态**: 进行中
- **目标**: 不能再出现“测试项目不存在但脚本仍返回成功”的情况。
- **任务**:
- [x] 修复 `Scripts/run_tests.ps1`，改为编译运行 `DeepBaseTests.dpr` 和 `DeepBaseIntegrationTests.dpr`。
- [x] 缺少必需测试项目、测试 exe 或 0 测试结果时必须失败。
- [x] 修复 `-Module` / `-FromUnit` 过滤：从 `TDUnitX.RegisterTestFixture(...)` 解析精确 fixture，避免单元名前缀误匹配和 0 测试假通过。
- [x] 修复 Unit 测试工程编译阻塞；`DeepBaseTests.dpr` 当前可完整编译。
- [x] `Test.DeepBase.Commerce` 过滤运行通过：49 tests passed，0 failed（包含 DeepKit SafeClient、license snapshot fail-closed、权限 facade、付费升级 facade、桌面生命周期 facade）。
- [x] 定位完整 Unit 运行超时用例：`Test.DeepBase.MVVM.TTestAsyncCommand` 因 `TThread.Synchronize` + 主线程 `Wait` 死锁。
- [x] 修复 `TAsyncCommand.Wait` 主线程等待泵 `CheckSynchronize`；`Test.DeepBase.MVVM` 当前 42 tests passed，0 failed。
- [x] 完整 Unit 已不再超时：`Scripts/run_tests.ps1 -Type Unit -CI` 当前完整编译运行约 166 秒结束。
- [x] 收敛 `DeepBase.DB.DoQry` 失败簇：SQLite `InsertReturningId`、预编译池跨连接污染、直接 SQL 语法错误码、LRU 统计均已修复；`Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.DB.DoQry -CI` 通过，32 tests passed。
- [x] 收敛 `DeepBase.StateMachine` 失败簇：泛型状态/触发器比较、未配置目标状态跳转语义、Builder 内部状态机泄漏、异常断言均已修复；`Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.StateMachine -CI` 通过，79 tests passed，0 leaked。
- [x] 收敛 `DeepBase.Template` 失败簇：条件分支解析、注释吞吐、严格模式缺失变量、冒号过滤器参数、点号键解析、父子 Context 生命周期均已修复；`Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Template -CI` 通过，81 tests passed，0 leaked。
- [x] 收敛 `DeepBase.Expression` 失败簇：`Compile` 缓存所有权、`XOR` 解析、Int64 半数舍入、AST 解析异常释放、专用异常断言均已修复；`Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.Expression -CI` 通过，140 tests passed，0 leaked。
- [x] 收敛 `DeepBase.DataBinding` 失败簇：ObservableList 所有权同步和 OneTime 绑定订阅语义已修复；`Scripts/run_tests.ps1 -Type Unit -FromUnit DeepBase.DataBinding -CI` 通过，22 tests passed，0 leaked。
- [x] 收敛 `DeepBase.Security/KeyManager` 失败簇：KeyManager AES-CBC IV 持久化、KeyStore active key 自动创建、Security secret 长度校验坏行均已修复；`DeepBase.KeyManager` 36 tests、`DeepBase.Security` 19 tests、`DeepBase.Security.DPAPI` 23 tests 均通过，0 leaked。
- [x] 收敛 `DeepBase.CloudBackup/Feedback` JSON 日期失败簇：兼容 ISO 与 Delphi 浮点日期、修复可选 JSON 对象/数组读取、枚举数字反序列化和异常路径泄漏；`DeepBase.CloudBackup` 35 tests、`DeepBase.Feedback` 31 tests 均通过，0 leaked。
- [x] 收敛 `DeepBase.Plugin/PluginManager` 配置键失败簇：插件本地配置键统一归一化到 `Plugin.*` 命名空间，安全敏感键检测避免误杀普通键，插件数据路径短 GUID 断言已对齐；`DeepBase.Plugin` 25 tests、`DeepBase.PluginManager` 23 tests 均通过，0 leaked。
- [x] 收敛 `DeepBase.Unlock` 解锁等级失败簇：校验字符算法改为同一产品月份内按等级固定错位，避免 `Free/Follow/Share` 碰撞导致高等级被识别为低等级，同时保留旧算法兜底；`DeepBase.Unlock` 5 tests passed，0 leaked。
- [x] 收敛 `DeepBase.Validation` Email 空值失败簇：Fluent `Email` 规则和快捷 `TValidate.Email` 统一将空白字符串视为无效邮箱，避免 Email 规则绕过必填语义；`DeepBase.Validation` 72 tests passed，0 leaked。
- [x] 收敛 `DeepBase.VirtualScroll` 可见索引失败簇：保留 overscan 预渲染列表，但 `FirstVisibleIndex/LastVisibleIndex` 改为返回真实 `Visible=True` 项，避免公开索引被预渲染项污染；`DeepBase.VirtualScroll` 60 tests passed，0 leaked。
- [x] 收敛 `DeepBase.AntiTamper` 安全默认值测试口径：默认配置继续不提供硬编码密钥，加解密测试改为显式注入测试密钥，保持 BUG-034 安全边界；`DeepBase.AntiTamper` 8 tests passed，0 leaked。
- [x] 收敛 `DeepBase.DBException` 用户提示口径失败簇：`GetErrorMessage` 默认恢复中文用户提示，与 FAQ 和现有测试一致；`DeepBase.DBException` 7 tests passed，0 leaked。
- [x] 收敛 `DeepBase.Diff` 相似度和 patch 泄漏失败簇：`Similarity` 改为字符级 LCS，`TPatchOperation` 释放持有的 `TDiffHunk`；`DeepBase.Diff` 57 tests passed，0 leaked。
- [x] 收敛 `DeepBase.Exception` VCL 全局异常适配和存储注入失败簇：恢复 VCL `Application.OnException` adapter，Core 仍保持 UI-neutral；存储工厂支持无 DB 连接的测试/内存注入；`DeepBase.Exception` 10 tests passed，0 leaked。
- [x] 收敛 `DeepBase.Export.Gen` PDF 头部失败簇：修复 `TBytes` 写流时写入数组变量而非数组内容的问题，`startxref` 记录 xref 起点；测试改为按字节读取 PDF header；`DeepBase.Export.Gen` 18 tests passed，0 leaked。
- [x] 收敛 `DeepBase.LLM.BillingClient` 聊天历史和 token 统计失败簇：Clear 后保留 `SystemPrompt` 配置但不把 system message 计入当前消息列表，`TTokenUsage.TotalTokens` 支持按 prompt+completion 自动计算；`DeepBase.LLM.BillingClient` 23 tests passed，0 leaked。
- [x] 收敛 `DeepBase.LLM` credential storage 失败簇：布尔字段读取增加 SQLite/FireDAC 兼容 helper，配置/模板/调用记录不再直接依赖 `AsBoolean`；`DeepBase.LLM` 当前 22 tests passed，0 leaked（包含五模型槽配置契约、生图调用、旧 `vision` 迁移）。
- [x] 收敛 `DeepBase.Scheduler` fluent Delay 失败簇：`Delay/Every/Cron` 配置阶段立即刷新 `NextRunAt`，并清理互斥调度策略残留；`DeepBase.Scheduler` 50 tests passed，0 leaked。
- [x] 收敛 `DeepBase.MVVM` 退出阶段泄漏：`TAsyncCommand.DoExecute` 的取消检查匿名方法在任务结束时释放，避免 actrec 自引用；`DeepBase.MVVM` 42 tests passed，0 leaked。
- [x] 收敛 `DeepBase.Performance` 并发 benchmark 退出泄漏：`TTask` 数组在 `WaitForAll` 后逐项释放，避免 `TTask`/线程池对象和 benchmark 闭包残留；`DeepBase.Performance` 16 tests passed，0 leaked。
- [x] 收敛 `DeepBase.CloudSync` JSON 数组替换泄漏：`JSONMergeArrays` 释放 `TJSONArray.Remove` 返回的旧值，清除完整 Unit 中 `TJSONNumber x5` 泄漏；`DeepBase.CloudSync` 56 tests passed，0 leaked。
- [x] 完整 Unit 发布门禁恢复通过：2026-05-09 当前 `Scripts/run_tests.ps1 -Type Unit -CI` 为 3243 tests，3240 passed，3 ignored，0 failed，0 errored，0 leaked。
- [x] GUI 测试窗体位置统一固定为 `Left=100, Top=300`（`DeepBase.GUITest`、`GUITest.FormFactory`、`AcceptanceMain`、`Test.DeepBase.TestHelper`），减少测试对其他桌面程序的遮挡干扰。
- [ ] 清理 0-fixture/未引用测试单元：`Test.DeepBase.Net`、`HttpServer`、`FileWatcher`、`Reflection`、`Math`、`Crypto.OpenSSL`、`i18n.Gender` 当前在默认 CI runner 下无注册 fixture；`Test.WebService` 已接入主 Unit runner。
- [x] CI 串联 package build、unit tests、integration tests、examples build（`.github/workflows/delphi-ci.yml` 已接入）。
- [x] CI package gate 恢复可信：`check_rename_residue.ps1` 已改成真实旧名残留检查，且当前 guarded files 检查通过。
- [x] Integration gate 防假通过：`Test.Integration.WebAPI` fixture 已注册，runner 已支持最低测试数检查；Commerce E2E 已显式配置 license snapshot verifier；当前 Integration 10 tests passed。
- [x] CI 补 architecture checks 阶段（模块边界/分层约束单独 gate）：新增 `Tests/Architecture/DeepBaseArchitectureTests.dpr`、`Scripts/run_architecture_checks.ps1`，并接入 `.github/workflows/delphi-ci.yml` 的 `architecture-checks` job（当前本地 18/18 通过）。
- [x] 覆盖率脚本启用失败阈值，不能只生成报告：`run_tests.ps1` 在 `-Coverage` 模式会自动调用 `coverage_check.ps1`，且在 `-CI` 或 `DEEPBASE_COVERAGE_FAIL_ON_LOW=1` 时低覆盖率直接失败。
- [x] 将 IntentClarification Phase 2 集成测试接入活跃 Unit/Integration runner，防止 `compile_test.bat` 只编旧 facade 后误报成功。
- [ ] 包边界测试补 `DeepBase.IntentClarification.*` 必需单元检查，防止 `DeepBaseFeatures.dpk/.dproj` 漏单元。
- [ ] 收敛完整 `DeepBaseTests.exe` 当前剩余失败：Browser Registry/WindowPool/Automation、FeatureFlags rollout、License legacy signing 环境、DB.DoQry DDL gate、Performance benchmark。

### LLM-P0-001: 下游可用的 5 模型 LLM 配置和调用面板
- **状态**: 进行中
- **目标**: 让下游桌面软件可以直接接入 LLM，不需要自己重新设计模型配置、API Key、调用、兜底和调试界面。
- **要求**:
- [ ] 统一 `Core/DeepBase.LLM.*` 与 `Features/DeepBase.LLM.*` 的配置模型，避免同一框架内出现两套 LLM 配置语义。
- [x] 固化 5 个模型槽：聪明 `smart`、平衡 `balanced`、快速 `fast`、生图 `image_gen`、图片兜底 `vision_fallback`（`Features/DeepBase.LLM.Types.pas` 已新增 `TierImageGen`，旧 `TierVision` 保留兼容别名）。
- [x] `TLLMConfigStore.BuiltInTiers` 暴露五槽位顺序；`NormalizeTier`/`LoadTierModelsJson` 已把旧 `vision` 配置迁移为 `image_gen`，避免老配置失效。
- [ ] 每个模型槽支持主模型和多个 fallback 模型，按顺序失败切换，并记录最终使用的 provider/model。
- [ ] Provider 支持 OpenAI-compatible、Anthropic、Azure、LiteLLM、Ollama、Custom；API Key 必须走安全存储，不允许明文长期落库。
- [ ] 增加生图能力接口：`GenerateImage` / `GenerateImageStream` / `ImageGenerationResult`，与图片理解 `ChatVision` 分开。
- [x] 增加生图基础接口：`ILLMClient.GenerateImage`、`TImageGenerationResult`、OpenAI-compatible `/images/generations` transport 调用和 fake transport 单测；`GenerateImageStream` 待后续补流式/异步版本。
- [ ] 增加图片兜底策略：视觉模型失败后可切换到低成本视觉模型或服务端 OCR/ASR/图像摘要兜底。
- [ ] 做 VCL/Studio 和 FMX 可复用配置面板：5 槽卡片、Provider 测试、模型拉取、API Key 显示/隐藏、费用预估、调用历史。
- [ ] 暴露下游 facade：`LLM.Chat(TierSmart, ...)`、`LLM.GenerateImage(...)`、`LLM.ChatVision(...)`，避免下游直接操作内部表。
- [ ] 增加 mock provider 单元测试，覆盖配置保存、fallback、失败记录、费用统计、无 key 错误提示。
- [x] 增加五槽读取和旧配置迁移单测：`Test.DeepBase.LLM` 当前 22 tests passed。
- [x] LLM 特性层 HTTP 客户端支持统一 transport 注入，默认 `System.Net`，可由下游替换为 ICS/fake transport；已补 fake transport 单测。
- [x] 更新 `docs/DeepBase-Downstream-Integration.md`，明确五槽位配置、`GenerateImage` 和下游接入边界。

### COM-P0-001: DB4 收费后端与 deepKit 数据库
- **状态**: 进行中
- **负责人**: DeepKit 服务器端负责统一认证/支付；deepBase 负责框架契约和桌面端 SDK 边界。
- **目标**: 在服务器侧完成 DB4 认证、订单、支付、权益、许可证、升级通道；所有下游工具统一走 DeepKit。
- **任务**:
- [x] PostgreSQL 使用数据库 `deepkit`，已执行兼容 migration，建立/补齐用户、身份、产品、订单、支付、权益、设备、许可证快照、更新通道、审计表。
- [x] 服务器端已从 `goodmem.cn` 中台命名切换为 `deepkit`：部署目录 `/srv/deepkit.top/app/current/backend`，环境文件 `/srv/deepkit.top/env/deepkit.env`，服务 `deepkit-api.service`，绑定 `127.0.0.1:8001`。
- [x] 本地维护用 `.env` 已创建在 DeepBase 根目录，记录服务器、数据库、服务路径和维护账号；`.gitignore` 已加入 `.env`，禁止误提交真实口令。
- [x] `TCommerceHttpStorage` 默认禁止订单、支付、商品、用户、权益写操作，服务器侧必须显式使用 `CreateServerAdmin`。
- [x] Commerce HTTP 配置支持路由前缀：新增 `RoutePrefix` 与 `CreateDeepKitClient/CreateDeepKitServerAdmin`，桌面端可直接对接 `/dk/*` 而不改业务调用代码。
- [x] 桌面端只允许调用安全 API：登录、创建订单、查询订单、查询权益、获取许可证快照、检查更新（已新增 `Features/DeepBase.Commerce.SafeClient.pas`，默认 `/dk`，并补齐 `Test.DeepBase.Commerce` 中的 DeepKit SafeClient 单测）。
- [x] 桌面端付费升级流程 facade 已落地：新增 `DeepBase.Commerce.UpgradeFlow`，封装列商品、创建订单、创建支付意图、检查权益、刷新许可证快照、获取更新 manifest。
- [x] 桌面端上线生命周期 facade 已落地：新增 `DeepBase.Desktop.Lifecycle`，集中封装匿名设备登录、token 注入 updater、权限判断/配额扣减、刷新许可证快照、付费升级、权益检查和 DeepKit 更新 manifest。
- [x] DB4 腾讯云数据库只作为服务器侧可信数据源，桌面端禁止直连。
- [x] 服务器已提供 `/auth/login`、`/commerce/orders`、`/commerce/payments/intents`、`/commerce/entitlements`、`/license/snapshot`、`/updates/manifest`。
- [x] 服务器本机主链路验收通过：登录、商品列表、创建订单、支付意图、license snapshot、更新 manifest。
- [ ] 支付回调必须由服务器验签，服务器按产品价格发放 entitlement，禁止信任客户端提交的金额、状态或权益；微信支付真实商户配置后验收。
- [ ] 桌面端 SDK 只保存短期 token 和许可证快照，不保存支付密钥、服务器管理 token、DB4 连接串。
- [ ] 增加支付状态机：pending、paid、failed、closed、refunded，并要求所有状态变更写审计日志。
- [ ] 增加幂等键和重放保护：订单创建、支付回调、权益发放、许可证签发必须可重复调用但不重复发放。

### OPS-P0-2026-05-13: DeepKit 备案、DNS、HTTPS 和服务交接
- **状态**: 进行中
- **目标**: 让 `deepkit.top` 能作为正式公网 DB4 入口使用，并确保后续同事没有上下文也能维护。
- **任务**:
- [x] 新建服务器目录 `/srv/deepkit.top`，不再把统一认证/支付能力放在 `/srv/goodmem.cn`。
- [x] 创建 `deepkit-api.service`，监听 `127.0.0.1:8001`，健康检查通过。
- [x] Nginx 已配置 `deepkit.top` 虚拟主机，`/dk/`、`/openapi.json`、`/docs`、`/health` 代理到 `127.0.0.1:8001`。
- [x] DeepKit.top 静态站已部署到 `/srv/deepkit.top/site`。
- [x] 服务器本机 `curl -H 'Host: deepkit.top' http://127.0.0.1/health` 返回 `deepkit-db4 production`。
- [ ] 完成 `deepkit.top` 备案。
- [ ] 完成 `deepkit.top` DNS 解析到 `124.221.136.137`；当前本机无法解析 `deepkit.top`，公网 IP + Host 访问被腾讯侧 DNSPod webblock 拦截。
- [ ] 配置 HTTPS 证书，优先使用 Let's Encrypt/certbot；完成后把 `DEEPKIT_PUBLIC_BASE_URL` 固化为 `https://deepkit.top`。
- [ ] 备案/DNS/HTTPS 完成后，从外网跑 `backend/scripts/acceptance-curl.md` 全链路验收。
- [ ] 微信支付接入后，补真实预下单、支付回调验签、重复回调幂等、退款撤权和对账验收。

### SEC-P0-001: 许可证签名机制替换
- **状态**: 进行中
- **目标**: 从本地共享密钥许可证切换为服务器私钥签名、客户端公钥验签的许可证快照。
- **任务**:
- [x] 定义并校验 license snapshot 必需字段：`snapshot_id`、`issued_at`、`expires_at`、`payload`、`signature`、`key_id`、`schema_version`、`revocation_version`。
- [x] deepBase 客户端只保存公钥/验签回调，不保存服务器私钥；旧共享签名密钥默认关闭，仅保留显式迁移/CI 通道。
- [ ] 权益判断以 DB4 entitlement 为真源，本地许可证只作为离线缓存。
- [ ] 增加撤权、退款、封号、设备解绑后的许可证失效策略。
- [x] 权益读取和消耗默认 fail-closed：缺失 `status` 不再默认 active；`valid_until` 过期会拒绝；`ConsumeEntitlement` 缺 `ok/success` 不再默认成功。
- [ ] 建立完整权限模型：feature code、license tier、quota、expires_at、device limit、offline grace days。
- [x] 提供客户端统一权限 API 初版：新增 `DeepBase.Commerce.Permissions`，封装 `HasFeature`、`RequireFeature`、`ConsumeQuota`、`RefreshLicenseSnapshot`，并接入 `TDeepKitSafeClient`。
- [ ] 本地许可证缓存必须包含签名、公钥版本、撤销版本、签发时间和过期时间，超过宽限期必须回连服务器。
- [ ] 所有付费功能入口必须通过权限 API 检查，不能只判断本地 UI 状态或配置开关。

### UPD-P0-001: 免费版升级收费版和付费更新
- **状态**: 进行中
- **目标**: 软件上线后支持免费版到收费版的安全升级，并支持网站上的免费/付费版本更新。
- **任务**:
- [x] 更新检查 API 必须携带 app_id、version、platform、channel、device_id 和用户 token（`DeepBase.Updater` 已增加 `UpdateAppId/UpdateDeviceId/UpdateAccessToken/UpdateApiKey` 与 `UpdateCheckRouteMode`，并在检查请求中同时发送 `version/current_version` + `platform/channel`）。
- [ ] 服务器根据 entitlement 返回可见版本、下载地址、强制更新策略和签名 manifest。
- [ ] 更新包必须校验 hash 和签名，防止篡改、路径穿越和降级攻击。
- [ ] 未付费用户只能看到免费通道，付费用户才能看到 Pro/商业通道。
- [ ] 更新检查必须接入权限系统：免费版、试用版、Pro 版、企业版看到不同 release channel。
- [ ] 更新 manifest 必须包含 app_id、version、channel、min_version、package_hash、signature、download_url、release_notes。
- [x] 客户端必须区分“免费更新”和“付费升级”：免费更新直接走 updater，付费升级通过 `TDeepKitUpgradeFlowClient` 先走订单/支付/权益，再刷新 license snapshot。
- [ ] 增加更新失败回滚、断点/失败重试、强制更新、稍后安装、退出安装、静默下载策略。
- [ ] 增加 Updater 安全测试：签名错误、hash 错误、Zip Slip、降级攻击、断网、服务器返回越权通道。

### APP-P0-001: 桌面工具型产品上线公共能力套件
- **状态**: 进行中
- **目标**: 将 deepBase 打包成桌面工具型产品上线时可直接复用的公共能力组合。
- **任务**:
- [ ] 提供标准启动流程：初始化 DB1、本地配置、日志、异常、许可证、更新检查、托盘、热键。
- [ ] 提供标准用户入口：登录、查看当前版本、查看授权状态、升级到收费版、检查更新、反馈问题。
- [x] 提供标准付费入口 facade：选择商品、创建订单、拉起支付、查询权益、刷新授权快照（`DeepBase.Commerce.UpgradeFlow`）。
- [x] 提供标准权限入口 facade：`DeepBase.Commerce.Permissions` 支持 `HasFeature/RequireFeature/ConsumeQuota/RefreshLicenseSnapshot`；UI 灰显和升级提示仍由 VCL/FMX 示例补齐。
- [x] 提供标准桌面生命周期 facade：`DeepBase.Desktop.Lifecycle` 支持登录、授权、付费升级、更新检查和 manifest 获取。
- [x] 提供 VCL/FMX 生命周期 UI helper：`DeepBase.VCL.DesktopLifecycle`、`DeepBase.FMX.DesktopLifecycle` 支持授权标签刷新、功能灰显、付费升级打开浏览器、检查更新和 GUI 测试窗体 `Left=100, Top=300` 定位。
- [ ] 提供完整标准 UI 模板：VCL 和 FMX 至少各一个桌面工具模板，覆盖升级、授权、托盘、热键、LLM 配置。
- [x] 增加 E2E 示例或测试：新增 `Test.Integration.CommerceE2E`，覆盖免费用户登录、升级 Pro、付费功能可见、刷新许可证快照、付费更新通道可见。

### DB-P0-001: 数据库边界和 DoQry 安全
- **状态**: 待开发
- **目标**: DB1/DB2/DB3/DB4 边界明确，桌面端查询工具不能绕过安全边界。
- **任务**:
- [ ] 明确 DB1 本地配置、DB2 本地业务、DB3 团队/共享业务、DB4 服务器收费授权的职责边界。
- [x] DoQry 默认禁止桌面端执行 DDL/PRAGMA/DROP/ALTER 等高风险 SQL。
- [x] DoQry 默认关闭全局预编译池并清理 stale query；显式启用时验证连接仍有效，避免跨测试/跨连接复用已释放连接。
- [x] DoQry SQLite `UniDbInsertReturningId` 改为 `ExecSQL + last_insert_rowid()`，兼容当前 FireDAC SQLite；直接 SQL 判定改为 token 级别， malformed `SELECT FROM` 能正确落到数据库语法错误码。
- [ ] DoQry 增加 timeout 落地、参数校验、敏感日志脱敏。
- [ ] 迁移统一走 `DeepBase.DB.Migrations`，生产环境禁止靠运行时补字段代替正式 migration。

---

## P1 架构治理（Important）

### DESKTOP-P1-2026-05-14: DeepShell VCL 桌面壳 P1 收敛与扩展
- **状态**: 进行中
- **来源**: 2026-05-14 五专家审阅；P0 阻塞已收敛（BUG-150 ~ BUG-154 已修复），剩余为体验、安全、性能与契约完善项。
- **目标**: 让 `TDeepMainForm` 在多产品上线时不再因为缺 i18n、缺 redaction、缺 DPI、缺 governance evidence 而重复打补丁。
- **任务**:
- [x] Shell 内置 caption / StatusBar / About 文本走 `IShellLocalizationService.Text(key, default)`：`TDeepMainForm.ShellText` helper + 内置命令 caption 全部走 i18n。locale 在运行期切换需重启刷新内置 caption（下游已注册的命令可在 `OnLocaleChanged` 内自行 `RegisterCommand` 覆盖）。
- [x] `IShellStatusManager` 新增可注入 sanitizer 钩子（默认 noop），下游可挂正则把 `Authorization: Bearer ...`、API Key、设备 token 等敏感片段替换为 `***`。Demo 加示例 sanitizer 仍待补。
- [x] `TShellCommandManager.BuildContextJson` 默认不发 `project_path`；只有命令显式 `RequiresEvidence=True` 时才把 path 写入 governance evidence，避免泄漏用户本地路径 PII。
- [ ] `ISettingsPageProvider.GroupName` 真接入：`TDeepShellSettingsForm` 按 GroupName 在 ListBox 里加分组分隔，或者从契约删除并文档说明。
- [x] `IShellLayoutService` 接入 `SaveProjectLayout`：新增 `TDeepMainForm.OpenProject/CloseProject` orchestration，`SaveShellState` 同时写全局和（如有）项目级 layout，`OpenProject` 切换前会先持久化旧项目的 layout 再加载新项目的 layout。
- [x] `TDeepShellToolWindow` 默认尺寸做 DPI 缩放（`MulDiv(320, Screen.PixelsPerInch, 96)`），在 4K/200% DPI 下不再变成 160×240。
- [x] `TShellAreaController.SetCollapsed` 中区不再走 BOTTOM 默认值的死代码路径；middle 走 alClient，仅切换 host vs summary 可见性。
- [x] `Dictionary.Keys.ToArray` 顺序不保证：`TShellCommandManager.CommandIds` 与 `TShellServiceRegistry.ServiceIds` 改为返回内部并行 `TList<string>` 的 `ToArray`，按注册顺序输出。
- [ ] 把 `IShellMainViewProvider.CreateViewControl` 的 `(AOwner, ARef, AInfo)` 参数语义写入文档；明确 `AInfo.ViewId` 与 `ARef.Id` 的关系，去掉冗余。
- [x] 把 `IShellStatusManager.ShellError` 改名为 `LogError`，`ShellError` 保留为兼容别名。
- [x] `Examples/VCLDeepShellDemo/.dproj` 已直接产出（dproj 是 MSBuild XML 文本文件，不必依赖 IDE 生成）。本地用 `msbuild VCLDeepShellDemo.dproj /p:Config=Debug /p:Platform=Win64` 可独立编译，输出 6.0 MB Win64 exe，0 错。

### DESKTOP-P1-2026-05-14-AUX: DeepShell governance/audit 默认值
- **状态**: 进行中
- **目标**: `NullGovernanceService` 不能既不拦也不记录，否则上线前的 `gmObserve` 阶段没有任何审计痕迹。
- **任务**:
- [x] 默认 governance 改为 audit-only：新增 `VCL/DeepBase.VCL.DeepShell.Governance.pas`，提供 `TShellAuditOnlyGovernanceService`（L2/L3 命令通过 `IShellStatusManager.Diagnostic` 写一行 evidence）和 `TShellAllowAllGovernanceService`（旧 null 行为）。`TDeepMainForm` 默认接 `TShellAuditOnlyGovernanceService`；下游 `SetGovernance(nil)` 或 `SetGovernance(allowAll)` 可显式退出。
- [ ] 真实 `DeepShell.GovernanceAdapter`（OCGS 包装）在第二阶段提供，默认 `gmObserve`，稳定后 L2/L3 切 `gmEnforce`。
- [ ] Shell 主窗体加一条命令 `shell.governance.toggleObserve`（仅 Pro/Admin 可见），方便在演示和验收期切换观察 / 阻断模式。

### DESKTOP-P1-2026-05-14-UI: DeepShell UI 完整性补全
- **状态**: 待开发
- **来源**: 2026-05-14 第二轮门禁审阅"重要问题"列表中关于 UI 呈现的项目。Shell 当前能编译但还不是"完整可体验"。
- **任务**:
- [ ] `FCommandBar` 不再是空面板：把内置命令（File / View / Tools / Help 几个 category）按注册顺序生成菜单项 + 工具栏按钮，绑定 `IShellCommandManager.Execute`。下游可清空再覆盖。
- [ ] Structure tool window 真正消费 `IShellStructureProvider`：内置一个 `TTreeView`-based 结构窗，按 `GetTreeNames` 显示多个根树，按 `HasChildren / GetChildren` 懒加载，节点点击 → `FContext.SetObject(ARef)`。
- [ ] Inspector tool window 真正消费 `IShellInspectorProvider`：内置一个 `TValueListEditor`/`TStringGrid` 的属性视图，订阅 `sekObjectSelected` 事件刷新；下区列出 issues / relations。
- [ ] Demo `Demo.MainForm` 改为先 `OpenProject('demo-project', ...)` 再 `OpenView`，让结构窗、inspector、context 都能联动展示。
- [ ] Demo 加一个示例 sanitizer：注册一个把 `Authorization: Bearer \S+` 替换为 `Authorization: Bearer ***` 的正则函数，演示 BUG-155 的用法。

### DESKTOP-P1-2026-05-14-I18N: Settings 窗体 + Localization 默认值
- **状态**: 待开发
- **来源**: 2026-05-14 第二轮审阅"重要问题"5（Settings 硬编英文 + en-US 默认）
- **任务**:
- [ ] `TDeepShellSettingsForm` 内的 `Caption='Settings'` / `'Restore Defaults'` / `'Cancel'` / `'Apply'` / `'OK'` / 错误对话框文本走 i18n key。窗体接收 `IShellLocalizationService` 引用，在 CreateNew 时 resolve key。
- [ ] `TShellDefaultLocalizationService.Create` 默认 locale 改为按系统区域决定：调用 `GetUserDefaultLocaleName` 或读 `SysLocale.PriLangID`，回退到 `en-US`。
- [ ] facade 提供一个 `RegisterDefaultShellTexts(loc, 'zh-CN')` helper，注入 `shell.cmd.fileExit='退出'` 等中文 key 集合，下游一行就能切到中文。

### DESKTOP-P1-2026-05-14-TEST: DeepShell 合同测试
- **状态**: 待开发
- **来源**: 2026-05-14 第二轮审阅"验证结果"4（无 DUnitX 测试）
- **任务**:
- [ ] 新建 `Tests/Test.DeepBase.VCL.DeepShell.pas`，至少覆盖：
  - `TShellEventBus` 多线程订阅/发布、销毁后 queue 项 no-op（用 bridge mock）。
  - `TShellCommandManager` Governance 双轨：返回 `True+sgoDeniedHard` 必须 reject（BUG-168 防回归）。
  - `TShellInMemoryRecentService` 顺序与 capacity trim。
  - `TShellSettingsBackedLayoutService` JSON 序列化往返。
  - `TShellAreaController` 折叠/展开/状态恢复。
  - `TDeepMainForm.AfterConstruction` 正确顺序调用虚方法 + ResolveServicesFromRegistry 后 FRecent/FLayout 真的指向 registry 里的实现（BUG-166 防回归）。
- [ ] 接入 `Tests/DeepBaseTests.dproj` 主 runner。

### ARCH-P1-001: Core 瘦身和包分层
- **状态**: 待开发
- **任务**:
- [ ] `Core` 禁止依赖 VCL/FMX/FireDAC/支付/LLM 具体实现。
- [ ] `Services` 不直接依赖 UI 和数据库驱动。
- [ ] `Persistence` 独占 FireDAC 适配。
- [ ] `Features` 拆分 Commerce、LLM、Speech、Updater 等可选包，避免下游被迫引入全部重依赖。
- [ ] 将 LLM、Speech、Updater、Commerce、ICS adapter 作为可选包，不让最小桌面工具强制引入重依赖。

### COM-P1-001: Commerce SDK 客户端/服务器拆分
- **状态**: 进行中
- **任务**:
- [x] 桌面端 SDK 只暴露用户安全操作（`TDeepKitSafeClient` 已落地）。
- [x] 服务器 SDK 才允许订单、支付、权益、退款、撤权等管理写操作（`TCommerceHttpStorage` 已补 `RefundOrder`/`RevokeEntitlement`/`RevokeLicenseSnapshot`，且继续受 `CreateServerAdmin`/`CreateDeepKitServerAdmin` 保护）。
- [x] Supabase/Firebase/PaymentBridge 标记为 server-only 或 prototype，不能作为桌面生产直连入口（`TSupabaseConfig/TFirebaseConfig` 新增 `CreateServerOnly` 和显式 `AllowServerOnlyPrototype`；默认需显式开启或设置 `DEEPBASE_ALLOW_PROTOTYPE_COMMERCE_ADAPTERS=1`，PaymentBridge 工厂同样加了 server-side 保护）。

### NET-P1-001: ICS 可选网络传输适配层
- **状态**: 进行中
- **目标**: 支持需要 ICS 的传统 Delphi 项目，但不把 ICS 变成 deepBase Core 的硬依赖。
- **任务**:
- [x] 定义统一网络传输接口：GET、POST、PUT、PATCH、DELETE、HEAD、OPTIONS、headers、timeout、redirect（`DeepBase.Net.Transport`）。
- [x] 保留 `System.Net.HttpClient` 默认实现（`TDeepBaseSystemNetTransport`）。
- [x] 新增 `DeepBase.Net.Transport.ICS` 可选 adapter 入口；未编译 ICS 时 fail-fast，避免下游误判为可用。
- [x] ICS adapter 固化可选适配契约：支持超时、代理、重定向、TLS 最低版本、证书校验策略、证书错误回调、取消回调配置；仓库未内置 Overbyte ICS 源码，未定义 `DEEPBASE_HAS_ICS` 时继续 fail-fast。
- [x] Commerce 通过统一 transport 注入（`TCommerceBackendUnifiedTransport`）。
- [x] Speech/Baidu ASR 通过统一 transport 注入（`TSpeechUnifiedHttpTransport`）。
- [x] Updater 通过统一 transport 注入，更新检查、release notes、history、下载均可替换 transport，fake transport 单测覆盖 `/updates/manifest` 参数和 token header。
- [x] LLM 特性层 HTTP 客户端通过统一 transport 注入，默认 `System.Net`，fake transport 单测覆盖请求 URL、body、Authorization header 和响应解析。
- [ ] Core 旧 LLM/BillingClient HTTP 面仍直接使用 `THTTPClient/TNetHTTPClient`，需要后续迁移或标记 legacy，避免形成第二套网络实现。
- [x] 增加 fake transport 单元测试，网络模块测试默认不依赖外网、不依赖 ICS 安装。
- [x] 统一 transport 响应增加真实 `BodyBytes` 读取，Updater 下载不再依赖 `IHTTPResponse.ContentStream`。
- [x] 文档明确：ICS 是兼容传统桌面项目的可选方案，不是当前 P0 主线。

### HOTKEY-P1-001: 热键模块强化为桌面工具标准能力
- **状态**: 进行中
- **目标**: 从“快捷键配置表”强化为可直接用于桌面工具的应用内热键和全局热键体系。
- **任务**:
- [ ] 保留现有 `DeepBase.Hotkeys` 配置、默认值、冲突检测能力。
- [x] 增加 Windows 全局热键注册：`RegisterHotKey`、`UnregisterHotKey`、`WM_HOTKEY` 消息分发。
- [x] 增加热键作用域：global、application、form、editor，并在冲突检测中区分作用域（Core 基础能力已实现）。
- [x] 增加应用内快捷键绑定基础：`BindAction/TriggerShortcut`（Core 抽象已实现，便于注入）。
- [x] 补齐 VCL 适配层：`DeepBase.VCL.Hotkeys` 支持 action/menu/button 绑定与按作用域触发。
- [x] 补齐 FMX 适配层：`DeepBase.FMX.Hotkeys` 已支持 action name 到 FMX action、menu item、button 的统一映射。
- [x] 增加 Core 级热键导入导出能力：`DeepBase.Hotkeys.Exchange`（JSON 导出/导入、冲突策略 strict/overwrite/keep）。
- [x] 增加 VCL 热键编辑器组件 UI：`Studio.HotkeyFrame` 已支持录入快捷键、检测冲突、恢复默认、JSON 导入导出。
- [x] 补齐 FMX 热键编辑器组件 UI（与 VCL 功能对齐）：`DeepBase.FMX.HotkeyEditor` 已支持搜索、分类、冲突处理、恢复默认、JSON 导入导出。
- [x] 增加测试：文本转换、冲突检测、全局热键注册失败处理、注销清理、重复注册保护。
- [x] 增加测试：作用域冲突检测、按作用域触发绑定动作。

### TRAY-P1-001: 托盘模块强化为桌面工具生命周期组件
- **状态**: 进行中
- **目标**: 让下游桌面工具可以直接获得托盘驻留、菜单、通知、最小化到托盘等标准能力。
- **任务**:
- [x] 保留 `DeepBase.TrayIcon` 底层 Shell_NotifyIcon 能力。
- [x] 增加 VCL 托盘组件和示例：`DeepBase.VCL.TrayIcon` + `Tools/Tray` 已支持显示、隐藏、双击恢复、右键菜单、气泡通知。
- [ ] 增加 FMX Windows 托盘适配；非 Windows 平台明确降级策略。
- [x] 增加标准菜单项：打开主窗口、检查更新、授权状态、设置、退出（`Tools/Tray` 示例已接入）。
- [x] 支持最小化到托盘、关闭到托盘、托盘启动恢复主窗口（`TDeepBaseTrayIcon` + `Tools/Tray` 已接入）。
- [ ] 与 SingleInstance、Updater、License、Hotkeys 联动，避免后台驻留时状态不同步（`Tools/Tray` 已接入 Hotkeys，剩余 SingleInstance/Updater/License 待完成）。
- [x] 增加测试和示例，覆盖重复 Show/Hide、窗口消息释放、退出时托盘图标清理（`Test.DeepBase.TrayIcon` 已补重复 Show/Hide 与回调清理用例，`Tools/Tray` 已作为示例）。

### SPEECH-P1-001: 语音录入和 ASR 组件化
- **状态**: 进行中
- **目标**: 为桌面工具提供可复用的语音录入能力，支持 LLM 输入、表单输入和命令触发。
- **任务**:
- [x] 统一 Speech facade：`TDeepBaseSpeechService` 已编排录音、VAD、ASR、错误和识别结果。
- [x] 封装当前 WinMM 录音、VAD、Baidu ASR，实现 provider 可替换。
- [ ] 支持按住说话、热键开始/停止录音、自动断句、录音状态 UI。
- [x] ASR 调用可接入权限/配额系统：`TDeepBaseSpeechService.PermissionClient` 识别前 `RequireFeature`，识别成功后 `ConsumeQuota`，默认 feature code 为 `speech.asr`。
- [ ] 支持在线 ASR 和本地/离线兜底接口，具体实现可后续扩展。
- [ ] 增加 VCL/FMX 语音录入控件，支持把识别文本写入 Edit/Memo 或发送给 LLM。
- [ ] 增加测试：空音频、超时、取消、配额不足。
- [x] 增加测试：音频格式、VAD、Baidu ASR 成功/失败、统一 transport、Service 编排、ASR 权限检查和配额扣减；`Test.DeepBase.Speech` 当前 7 tests passed。

### QA-P1-001: 长期质量体系
- **状态**: 待开发
- **任务**:
- [ ] 增加架构规则检查：Core 禁 UI/DB、包引用方向、危险 SQL、密钥泄漏。
- [ ] 增加 Updater 安全测试：签名、hash、Zip Slip、回滚、断网、灰度。
- [x] 增加 Commerce E2E：登录、下单、支付意图、权益生效、许可证快照、付费更新可见（`Test.Integration.CommerceE2E`）。
- [ ] 增加 LLM E2E mock：5 模型槽、fallback、生图失败、图片兜底、费用统计。
- [ ] 增加桌面工具模板 E2E：托盘、热键、自动升级、付费升级、权限控制、语音录入。
- [ ] CI 增加可选包矩阵：Minimal、Runtime、All、LLM、Speech、Commerce、Updater、ICS adapter。

---

## P2 中期整理

### OPS-P2-001: 服务器可观测性和运维
- **状态**: 待开发
- **任务**:
- [ ] 后端提供 `/health`、`/metrics`、审计日志和告警。
- [ ] 监控支付回调成功率、权益发放失败率、许可证签发失败率、升级成功率。
- [ ] 建立 migration 执行时长、失败、回滚统计。

### PRODUCT-P2-001: 商业生命周期增强
- **状态**: 待开发
- **任务**:
- [ ] 支持多产品、多租户、组织席位、设备限制。
- [ ] 支持续费、升级、优惠码、发票、退款撤权。
- [ ] 支持离线宽限期和上线后的许可证重新对账。

---

## P3 低优先级

### DOC-P3-001: 视频教程
- **状态**: 待开发
- **任务**:
- [ ] 在 P0/P1 发布治理完成后再制作视频教程。

---

**维护**: 罗辑
