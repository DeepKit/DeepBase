# deepBase 开发任务
> **最后更新**: 2026-05-08
> **项目状态**: 框架主体已完成，当前进入上线前架构治理、收费后端接入和发布门禁修复阶段。
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
- 当前上线风险和交付缺口集中在 4 个方面：DB4 收费后端实部署、许可证/升级安全边界、桌面工具生命周期 UI 示例、ICS/E2E 后置适配。
- DB4 生产链路必须放在服务器侧实现，桌面端只能调用安全 HTTP API，不能直接写订单、支付、权益表。
- 免费版升级收费版的生命周期应由服务器完成：登录、创建订单、支付回调、发放权益、签发许可证快照、开放付费更新通道。
- LLM 已具备五模型槽配置契约和基础调用能力；下游可以先按 facade/API 集成，UI 配置面板和更完整 fallback 仍需继续强化。
- ICS 不作为当前 P0 主线重写目标；应做成可选网络传输适配层，不能让 Core 强依赖 ICS。
- 桌面工具型产品的上线公共能力要形成标准套件：自动升级、付费升级、权限控制、托盘、热键、语音录入。

---

## 需求追踪矩阵

| 用户要求 | 落地任务 | 当前状态 |
|----------|----------|----------|
| 整个体系已改名为 deep，框架名为 deepBase | `ARCH-P0-001` | 已完成，改名残留检查已并入包门禁（CI 串联仍在 `QA-P0-001`） |
| 桌面软件上线后需要收费、认证和授权系统 | `COM-P0-001`、`SEC-P0-001`、`APP-P0-001` | 进行中，桌面端安全 SDK/权限 facade/付费升级 facade 已完成，服务器实部署仍待王维完成 |
| 收费后端应在服务器开发，不能让桌面端直连收费数据库 | `COM-P0-001`、`COM-P1-001` | 进行中，桌面端只走 `/dk` 安全 API，server-admin adapter 默认受保护 |
| DB4 使用腾讯云数据库，服务器侧还要创建 PostgreSQL 数据库 `deepKit` | `COM-P0-001`、`OPS-P2-001` | 待开发，王维服务器交接文档已列入导航 |
| 免费版升级到收费版，需要支付、权益、许可证和付费更新通道 | `COM-P0-001`、`SEC-P0-001`、`UPD-P0-001` | 进行中，客户端流程 facade 已完成，服务器支付回调/权益发放/签名快照需实部署 |
| 网站上支持免费更新和付费升级 | `UPD-P0-001`、`PRODUCT-P2-001` | 待开发 |
| LLM 能交给下游使用，并提供 5 模型配置面板：聪明、平衡、快速、生图、图片兜底 | `LLM-P0-001` | 进行中，五槽位契约/生图基础调用/配置读取测试已完成，UI 面板仍待强化 |
| ICS 是否全力接入 | `NET-P1-001` | 决策为可选 adapter，不进入 P0 主线、不污染 Core |
| 桌面工具型产品需要自动升级、付费升级、权限控制、托盘、热键等常用功能 | `APP-P0-001`、`UPD-P0-001`、`SEC-P0-001`、`TRAY-P1-001`、`HOTKEY-P1-001` | 进行中，托盘/热键/权限 facade/付费升级 facade/桌面生命周期 facade/VCL-FMX helper 已完成，完整模板和 E2E 仍待补齐 |
| 支持语音录入，用于 LLM 输入、表单输入和命令触发 | `SPEECH-P1-001` | 进行中，录音/VAD/Baidu ASR/权限配额接入已完成，VCL/FMX 输入控件仍待补齐 |
| deepBase 库需要持续维护和架构优化 | `ARCH-P1-001`、`QA-P1-001`、`DB-P0-001` | 待开发 |
| 5 位架构专家建议要转化为可执行治理项 | `ARCH-P1-001`、`QA-P1-001`、`COM-P1-001`、`NET-P1-001` | 已转化为分层、边界、安全、测试、可选包任务 |

---

## P0 当前开发（Blocking）

### ARCH-P0-001: deepBase 改名收尾与包编译门禁
- **状态**: 已完成
- **目标**: 所有发布脚本、`.dpk`、测试入口从 `DeepBase` 切换为 `DeepBase/deepBase` 命名，包编译必须能暴露真实问题。
- **任务**:
- [x] 修复 `Scripts/build_packages_win64.ps1`，改为构建 `DeepBase*.dpk`。
- [x] 修复 `Scripts/compile_packages_win64.ps1`，改为构建 `DeepBase*.dpk`。
- [x] 修复 `DeepBase*.dpk` 内部 package 名、requires 和 contains 的 `DeepBase` 残留。
- [x] 当前发布门禁在 `VCL/` 源码目录缺失时排除 VCL 包和 VCL 必需示例。
- [x] 修复包编译暴露的源文件损坏，`Minimal`、`Runtime`、`All` Win64 package gate 已通过。
- [x] 处理 VCL 发布口径：恢复 `VCL/` 源码目录并补齐 `DeepBase.VCL.*.dfm` 资源，`DeepBaseVCL.dpk` 已可独立编译通过。
- [x] 核心脚本和 `.dpk` 文件已完成 `DeepBase` 残留检查，当前无命中。
- [x] 修复 `Scripts/compile_packages_win64.ps1` 误报逻辑（`ErrorMessage` 误判为失败），改为基于退出码 + 真正 `Error:/Fatal:` 行判定。
- [x] 将改名残留检查固化进发布门禁：新增 `Scripts/check_rename_residue.ps1` 并在 `Scripts/build_packages_win64.ps1` 入口强制执行，命中即失败。

### QA-P0-001: 测试和 CI 门禁可信化
- **状态**: 进行中
- **目标**: 不能再出现“测试项目不存在但脚本仍返回成功”的情况。
- **任务**:
- [x] 修复 `Scripts/run_tests.ps1`，改为编译运行 `DeepBaseTests.dpr` 和 `DeepBaseIntegrationTests.dpr`。
- [x] 缺少必需测试项目、测试 exe 或 0 测试结果时必须失败。
- [x] 修复 `-Module` / `-FromUnit` 过滤：从 `TDUnitX.RegisterTestFixture(...)` 解析精确 fixture，避免单元名前缀误匹配和 0 测试假通过。
- [x] 修复 Unit 测试工程编译阻塞；`DeepBaseTests.dpr` 当前可完整编译。
- [x] `Test.DeepBase.Commerce` 过滤运行通过：42 tests passed，0 failed（包含 DeepKit SafeClient、权限 facade、付费升级 facade、桌面生命周期 facade）。
- [x] 定位完整 Unit 运行超时用例：`Test.DeepBase.MVVM.TTestAsyncCommand` 因 `TThread.Synchronize` + 主线程 `Wait` 死锁。
- [x] 修复 `TAsyncCommand.Wait` 主线程等待泵 `CheckSynchronize`；`Test.DeepBase.MVVM` 当前 42 tests passed，0 failed。
- [x] 完整 Unit 已不再超时：`Scripts/run_tests.ps1 -Type Unit -SkipCompile -CI` 当前约 143 秒结束。
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
- [x] 完整 Unit 发布门禁当前通过：`Scripts/run_tests.ps1 -Type Unit -SkipCompile -CI` 为 3115 tests，3112 passed，3 ignored，0 failed，0 errored，DUnitX 0 leaked，退出无 FastMM unexpected memory leak。
- [x] GUI 测试窗体位置统一固定为 `Left=100, Top=300`（`DeepBase.GUITest`、`GUITest.FormFactory`、`AcceptanceMain`、`Test.DeepBase.TestHelper`），减少测试对其他桌面程序的遮挡干扰。
- [ ] 清理 0-fixture/未引用测试单元：`Test.DeepBase.Net`、`HttpServer`、`FileWatcher`、`Reflection`、`Math`、`Crypto.OpenSSL`、`i18n.Gender` 当前在默认 CI runner 下无注册 fixture；`Test.WebService` 未被 `DeepBaseTests.dpr` 引用。
- [x] CI 串联 package build、unit tests、integration tests、examples build（`.github/workflows/delphi-ci.yml` 已接入）。
- [x] CI 补 architecture checks 阶段（模块边界/分层约束单独 gate）：新增 `Tests/Architecture/DeepBaseArchitectureTests.dpr`、`Scripts/run_architecture_checks.ps1`，并接入 `.github/workflows/delphi-ci.yml` 的 `architecture-checks` job（当前本地 18/18 通过）。
- [x] 覆盖率脚本启用失败阈值，不能只生成报告：`run_tests.ps1` 在 `-Coverage` 模式会自动调用 `coverage_check.ps1`，且在 `-CI` 或 `DEEPBASE_COVERAGE_FAIL_ON_LOW=1` 时低覆盖率直接失败。

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
- **负责人**: 王维负责服务器端，罗辑负责 deepBase 框架契约和桌面端 SDK 边界。
- **目标**: 在服务器侧完成 DB4 认证、订单、支付、权益、许可证、升级通道。
- **任务**:
- [ ] PostgreSQL 创建数据库 `deepKit`，按交接文档建立用户、身份、产品、订单、支付、权益、设备、许可证快照、更新通道、审计表。
- [x] `TCommerceHttpStorage` 默认禁止订单、支付、商品、用户、权益写操作，服务器侧必须显式使用 `CreateServerAdmin`。
- [x] Commerce HTTP 配置支持路由前缀：新增 `RoutePrefix` 与 `CreateDeepKitClient/CreateDeepKitServerAdmin`，桌面端可直接对接 `/dk/*` 而不改业务调用代码。
- [x] 桌面端只允许调用安全 API：登录、创建订单、查询订单、查询权益、获取许可证快照、检查更新（已新增 `Features/DeepBase.Commerce.SafeClient.pas`，默认 `/dk`，并补齐 `Test.DeepBase.Commerce` 中的 DeepKit SafeClient 单测）。
- [x] 桌面端付费升级流程 facade 已落地：新增 `DeepBase.Commerce.UpgradeFlow`，封装列商品、创建订单、创建支付意图、检查权益、刷新许可证快照、获取更新 manifest。
- [x] 桌面端上线生命周期 facade 已落地：新增 `DeepBase.Desktop.Lifecycle`，集中封装匿名设备登录、token 注入 updater、权限判断/配额扣减、刷新许可证快照、付费升级、权益检查和 DeepKit 更新 manifest。
- [ ] 支付回调必须由服务器验签，服务器按产品价格发放 entitlement，禁止信任客户端提交的金额、状态或权益。
- [ ] DB4 腾讯云数据库只作为服务器侧可信数据源，桌面端禁止直连。
- [ ] 服务器提供 `/auth/login`、`/commerce/orders`、`/commerce/payments/intents`、`/commerce/entitlements`、`/license/snapshot`、`/updates/manifest`。
- [ ] 桌面端 SDK 只保存短期 token 和许可证快照，不保存支付密钥、服务器管理 token、DB4 连接串。
- [ ] 增加支付状态机：pending、paid、failed、closed、refunded，并要求所有状态变更写审计日志。
- [ ] 增加幂等键和重放保护：订单创建、支付回调、权益发放、许可证签发必须可重复调用但不重复发放。

### SEC-P0-001: 许可证签名机制替换
- **状态**: 待开发
- **目标**: 从本地共享密钥许可证切换为服务器私钥签名、客户端公钥验签的许可证快照。
- **任务**:
- [ ] 定义 license snapshot 字段：用户、产品、设备、权益、签发时间、过期时间、撤销版本、schema_version。
- [ ] deepBase 客户端只保存公钥，不保存服务器私钥或共享签名密钥。
- [ ] 权益判断以 DB4 entitlement 为真源，本地许可证只作为离线缓存。
- [ ] 增加撤权、退款、封号、设备解绑后的许可证失效策略。
- [ ] 建立权限模型：feature code、license tier、quota、expires_at、device limit、offline grace days。
- [x] 提供客户端统一权限 API：`HasFeature`、`RequireFeature`、`ConsumeQuota`、`RefreshLicenseSnapshot`。
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
- [ ] 增加 E2E 示例或测试：免费用户升级为 Pro 后，付费功能可见，付费更新通道可见。

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
- [ ] ICS adapter 支持 HTTP/HTTPS、TLS 配置、代理、超时、取消、重定向、证书错误回调。
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
- [ ] 增加 Commerce E2E：登录、下单、支付回调、发放权益、许可证快照、付费更新可见。
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
