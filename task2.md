# DeepBase 下游集成扫描与优化需求

扫描日期: 2026-05-15  
范围: `D:\_Progs\02Business` 下疑似集成 DeepBase 的项目，排除 DeepBase 框架自身实现后做静态扫描。  
背景: DeepBase 重构后，`DeepBase.Manager` 不再直接携带 FireDAC DB1 连接适配器。任何最终 EXE 只要调用 `DeepBase.Initialize*` / `InitializeWithDB*`，都必须链接 `DeepBase.Persistence.Manager.FireDAC`，否则会报:

```text
DeepBase initialization failed: No DB connection adapter registered.
Include DeepBase.Persistence.Manager.FireDAC.
```

## 结论

这次下游报错的核心原因不是数据库文件路径，也不是 SQLite 本身，而是最终程序没有把 Manager 的 FireDAC 适配器单元链接进来。

确定需要优先更新的项目:

- `DeepDev`: `DeepDev.dpr` 两处调用 `DeepBase.Manager.DeepBase.Initialize`，但 `.dpr` 没有 `DeepBase.Persistence.Manager.FireDAC`。
- `DeepDevLite`: `DeepDevLite.dpr` 调用 `Initialize`，没有 adapter；还显式引用了旧位置 `..\DeepBase\Core\DeepBase.DB.DoQry.pas`，该文件现在在 `Persistence`。
- `DeepRenew`: `DeepRenew.dpr`、`DeepRenewAdmin.dpr`、`DeepRenewFMX.dpr` 都调用 `Initialize`，没有 adapter；`.dproj` 里也缺 `DeepBase\Persistence` 搜索路径。
- `DeepSync`: `DeepSync.Agent.dpr`、`DeepSync.ScreenAgent.dpr` 调用 `UB.Initialize`，没有 adapter。
- `DeepStory`: `DeepStoryRef.dpr`、`TestApi.dpr`、`TestImport.dpr`、`TestWriting.dpr` 通过 `SvcDeepBaseInit.TDeepBaseInit.Initialize` 间接调用 `InitializeEx`，但这些最终程序没有 adapter。
- `DeepInsight`: 主程序已有 adapter，但 `tools\DeepBasePathValidator.dpr` 和部分测试工程缺 adapter。

## 接入铁律

源码直编模式:

```pascal
uses
  DeepBase.Manager,
  DeepBase.Persistence.Manager.FireDAC;
```

运行时包模式:

- 最终程序必须依赖并部署 `DeepBasePersistence.bpl`。
- 不能只带 `DeepBaseCore.bpl`。
- 不要把源码版 `DeepBase.Manager` 和 package 版 `DeepBasePersistence` 混用，否则 adapter 可能注册到另一个 Manager 副本。
- `DeepBase.Persistence.RuntimeRegistration` 不能替代 `DeepBase.Persistence.Manager.FireDAC`；它不是 Manager DB1 连接适配器注册入口。

如果加入 adapter 后错误变成 FireDAC driver 或 SQLite driver 相关，再检查 `FireDAC.Phys.SQLite` / deployment；那已经是下一层问题，不是 `No DB connection adapter registered`。

## 项目清单

| 项目 | 风险 | 证据 | 优化需求 |
| --- | --- | --- | --- |
| `Assayer` | 低 | `src\DeepLLMProxy.dpr` 有 `DeepBase.Persistence.Manager.FireDAC`，并调用 `DeepBase.Manager.DeepBase.Initialize`；治理/行为测试也显式包含 adapter | 保持当前模式。后续新增 EXE 时，adapter 必须放进最终 `.dpr`，不能只靠共享单元。 |
| `DeepClip` | 低 | `DeepClip.dpr` / `DeepClipLite.dpr` 链接 adapter；`src\App\DeepClip.Bootstrap.pas` 调用 `Mgr.InitializeOrRaise` | 当前是正确的“最终 DPR 链接 adapter，bootstrap 只负责初始化”模式。后续不要把 adapter 从 `.dpr` 挪到普通业务单元里当作隐式依赖。 |
| `DeepCompare` | 低 | `delphi\DeepCompare.dpr`、`DeepCompareDebug.dpr`、`DeepCompareU.dpr` 都有 adapter；主程序调用 `DeepBase.Manager.DeepBase().Initialize` | 主程序基本安全。`delphi\__history\DeepCompare.TestGUI.dpr` 是历史工程，缺 adapter；若还会编译运行，需要同步更新或归档排除。 |
| `DeepDev` | P0 | `DeepDev.dpr` line 90 / 126 调用 `DeepBase.Manager.DeepBase.Initialize`；uses 只有 `DeepBase.Manager`，没有 adapter | 在 `DeepDev.dpr` 加 `DeepBase.Persistence.Manager.FireDAC`。`.dproj` 已有 `DeepBase\Persistence` 搜索路径，优先做 `.dpr` 修复。测试辅助 `tests\HelperTestDB.pas` 也会初始化，测试 EXE 同样要链接 adapter。 |
| `DeepDevLite` | P0 | `DeepDevLite.dpr` line 38 调用 `Initialize`；没有 adapter；还写死 `DeepBase.DB.DoQry in '..\DeepBase\Core\DeepBase.DB.DoQry.pas'`，但实际文件在 `DeepBase\Persistence` | 加 `DeepBase.Persistence.Manager.FireDAC in '..\DeepBase\Persistence\DeepBase.Persistence.Manager.FireDAC.pas'`。同时把 `DeepBase.DB.DoQry` 的显式路径改到 `Persistence`，避免旧 Core 边界导致编译或混用问题。 |
| `DeepInput` | 低 | `src\DeepInput.dpr` 已有 `DeepBase.Persistence.Manager.FireDAC`，并调用 `Initialize` | adapter 正确。优化点是初始化失败时现在只设置 `GConfigDBAvailable=False` 后继续运行；如果 ConfigDB 是必需能力，应记录 `LastError` 或改为明确失败。 |
| `DeepInsight` | 中 | `DeepInsightApp.dpr` 已有 adapter；`tools\DeepBasePathValidator.dpr` 调用 `DeepBase.Initialize` 但只 uses `DeepBase.Manager`；部分测试 `.dpr` 也只显式引用 Manager | 主程序安全。给 `tools\DeepBasePathValidator.dpr` 和仍在使用的测试 EXE 加 adapter。测试代码里直接调用 `DeepBase.Manager.DeepBase.Initialize` 时要检查返回值和 `LastError`。 |
| `DeepLaunch` | 低 | `DeepLaunch.dpr` 有 adapter；`src\Core\PathHelper.pas` 的 `EnsureDeepBaseReady` 内部调用 `InitializeEx` | 当前 adapter 在最终 `.dpr`，可运行。优化点是初始化入口隐藏在 `PathHelper`，新维护者容易只看 `.dpr` 误删 adapter；建议在 `.dpr` adapter 行旁保留注释，说明它服务于 `TPathHelper.EnsureDeepBaseReady`。 |
| `DeepRenew` | P0 | 三个最终程序 `DeepRenew.dpr`、`DeepRenewAdmin.dpr`、`DeepRenewFMX.dpr` 都调用 `Initialize`，但没有 adapter；对应 `.dproj` 搜索路径只有 `Core/FMX/VCL`，缺 `Persistence`；`DeepRenewAdmin.dproj` 还有 `D:_Progs...` 路径拼写错误 | 三个 `.dpr` 都加 `DeepBase.Persistence.Manager.FireDAC`。三个 `.dproj` 的所有配置加 `D:\_Progs\02Business\DeepBase\Persistence`。修正 `D:_Progs` 为 `D:\_Progs`。 |
| `DeepShine` | 中 | `Apps\DeepShineStudio`、`DeepShineFlow`、`DeepShineConfig`、`DeepShine.TestGUI` 都显式 source-mode 引用 Manager 和 adapter | adapter 齐全。风险是大量绝对路径 source-mode 直引 `D:\_Progs\02Business\DeepBase\...`，以后切 package 或换机器时容易混用。建议统一为相对路径或切到包依赖，不要同一 EXE 同时混源码和包。 |
| `DeepSpec` | 中 | `DeepSpec.dpr` 有 adapter，但 line 60 调用 `DeepBase.Manager.DeepBase.InitializeEx(GErrorMsg);` 后忽略返回值 | 不会触发 adapter 缺失，但会吞掉真实初始化错误。若 DeepBase 是必需能力，改成 `if not InitializeEx then ... Halt(1)`；若确实允许 fallback，至少把 `GErrorMsg` 写入日志/状态栏。 |
| `DeepStory` | P0 | `DeepStory.dpr` 有 adapter；但 `DeepStoryRef.dpr`、`TestApi.dpr`、`TestImport.dpr`、`TestWriting.dpr` 调用 `TDeepBaseInit.Initialize`，最终 `.dpr` 未链接 adapter；`SvcDeepBaseInit.pas` 内部调用 `InitializeEx` | 所有会调用 `TDeepBaseInit.Initialize` 的最终 EXE 都加 adapter。不要只在 `SvcDeepBaseInit.pas` 加 adapter 来“碰巧链接”，最终程序入口更清楚，也更符合接入规范。 |
| `DeepSync` | P0 | `DeepSync.dpr` 有 adapter；`DeepSync.Agent.dpr` line 96 调用 `UB.Initialize`，`DeepSync.ScreenAgent.dpr` line 82 调用 `UB.Initialize`，两者都没有 adapter | 给 Agent 和 ScreenAgent 的 `.dpr` 加 `DeepBase.Persistence.Manager.FireDAC`。两个 agent 的 `.dproj` 已有 `DeepBase\Persistence` 搜索路径。顺手补 `UB.Finalize`，否则 agent 进程退出时 DeepBase 生命周期不完整。 |
| `DeepCharset` | 低 | `better2.md` 的示例已写 `uses DeepBase.Manager, DeepBase.Persistence.Manager.FireDAC`；当前实际 `.dpr` 未发现 DeepBase 初始化调用 | 未来按 `better2.md` 落地真实 DeepBase 集成时，直接使用示例中的 adapter 组合。不要只复制 `DeepBase.InitializeOrRaise` 那一行。 |
| `DeepConfig` | 低 | 目前只在 docs 里提到 `DeepBase.Manager`，未发现实际 `.dpr` DeepBase 初始化入口 | 暂无代码修复。后续迁移到 DeepBase 时按本文件接入铁律处理。 |

## 优先修复批次

### Batch 1: 直接导致当前错误的 EXE

- `DeepDev\DeepDev.dpr`
- `DeepDevLite\DeepDevLite.dpr`
- `DeepRenew\DeepRenew.dpr`
- `DeepRenew\DeepRenewAdmin.dpr`
- `DeepRenew\DeepRenewFMX.dpr`
- `DeepSync\DeepSync.Agent.dpr`
- `DeepSync\DeepSync.ScreenAgent.dpr`
- `DeepStory\DeepStoryRef.dpr`
- `DeepStory\TestApi.dpr`
- `DeepStory\TestImport.dpr`
- `DeepStory\TestWriting.dpr`
- `DeepInsight\tools\DeepBasePathValidator.dpr`

### Batch 2: 接入卫生

- `DeepDevLite`: 修正 `DeepBase.DB.DoQry` 旧 Core 路径到 `Persistence`。
- `DeepRenew`: 补 `.dproj` 的 `DeepBase\Persistence` 搜索路径，修正 `D:_Progs` 路径。
- `DeepSpec`: 明确 `InitializeEx` 失败策略，不要静默吞掉。
- `DeepSync` agent: 补 `DeepBase.Finalize`。
- `DeepShine`: 减少绝对路径 source-mode 绑定，防止和 package 模式混用。

## 建议增加的静态门禁

在 DeepBase 或 02Business 级别增加一个轻量扫描脚本，规则如下:

- 如果 `.dpr` 或启动 bootstrap 调用了 `Initialize` / `InitializeEx` / `InitializeOrRaise` / `InitializeWithDB`，最终 `.dpr` 必须包含 `DeepBase.Persistence.Manager.FireDAC`。
- 如果 `.dpr` 只包含 `DeepBase.Manager` 且包含 `Initialize`，判为失败。
- 如果 `.dpr` 显式 `in '..\DeepBase\Core\DeepBase.DB.DoQry.pas'`，判为失败；该单元属于 `Persistence`。
- 如果 `.dproj` 搜索路径只有 `DeepBase\Core` 而没有 `DeepBase\Persistence`，但 `.dpr` 调用了 DeepBase 初始化，判为失败。
- 如果同时发现 `DeepBase.Manager in '...\Core\DeepBase.Manager.pas'` 和 package 依赖 `DeepBasePersistence`，判为需人工确认，避免双 Manager 副本。

建议人工复核命令:

```powershell
rg -n "DeepBase\.Manager|DeepBase\.Persistence\.Manager\.FireDAC|InitializeOrRaise|InitializeWithDB|InitializeEx|\.Initialize\b" D:\_Progs\02Business -g "*.dpr" -g "*.pas" -g "!DeepBase/**"
```

注意: `Application.Initialize` 也会命中，人工筛掉即可；真正要查的是 `DeepBase.Manager.DeepBase.Initialize`、`UB.Initialize`、`TDeepBaseInit.Initialize` 这类 DeepBase 生命周期入口。

## 标准补丁模板

源码直编:

```pascal
uses
  DeepBase.Manager,
  DeepBase.Persistence.Manager.FireDAC,
```

如果当前 `.dpr` 使用显式路径:

```pascal
uses
  DeepBase.Manager in '..\DeepBase\Core\DeepBase.Manager.pas',
  DeepBase.Persistence.Manager.FireDAC in '..\DeepBase\Persistence\DeepBase.Persistence.Manager.FireDAC.pas',
```

运行时包:

```text
Required packages:
  DeepBaseCore
  DeepBasePersistence
```

部署检查:

```text
DeepBaseCore.bpl
DeepBasePersistence.bpl
```

看到 `No DB connection adapter registered` 时，先查 adapter 链接；看到 SQLite driver / vendor library 错误时，再查 FireDAC SQLite driver 和部署。

---

## better / better2 / history / bugfix 复核追加 - 2026-05-16

### 复核结论

不能确认所有 bug 都已经修完。`bugfix.md` 中 BUG-181~219 大多已有修复记录，且 `TestResults/UnitTestResults.xml` 显示 2026-05-15 的 Unit 门禁为 `3486 total / 0 failures / 0 errors / 3 ignored`；但 `better.md`、`better2.md` 和当前源码抽查仍显示若干 P0/P1/P2 只是“部分修复”或“缺少闭环测试”。

本次未重新运行完整测试，只做文档对账 + 源码静态复核；以下条目需要进入后续修复/验证队列。

| 编号 | 严重性 | 当前证据 | 优化需求 |
| --- | --- | --- | --- |
| `IC-FACADE-001` | P0/P1 | `Features/DeepBase.IntentClarification.pas` 仍保留一个空的本地 `IClarificationEngine`，与 `Features/DeepBase.IntentClarification.Interfaces.pas` 中完整接口同 GUID。`CreateEngine*` 已改为创建真实 engine，但下游通过 facade 单元拿到的接口类型仍没有 `StartSession/SubmitInput` 等方法。 | 删除重复空接口，facade 公开类型统一引用 `DeepBase.IntentClarification.Interfaces.IClarificationEngine`；把文档示例变成 compile/run 测试。 |
| `IC-PRESET-002` | P1 | `TIntentClarifier.CreateEngineWithPreset(APresetName)` 当前只创建 engine，`APresetName` 未实际应用；`TClarificationRegistration.ApplyPreset` 只返回模板并注册 L0/L1 provider，没有把模板写入 session/engine 配置。 | `CreateEngineWithPreset` 要么真正应用 preset，要么改名/改文档要求显式调用 `ApplyPreset`；补 preset 生效测试。 |
| `IC-BUDGET-003` | P1 | `StartSession` 对 `Template` / `BudgetOverride` 主要是日志；`SubmitInput` 每轮仍用 `TBudgetConfig.Default`，预算覆盖不会真正生效。 | 将 per-session budget snapshot 存入 session state；`SubmitInput` 使用该 snapshot；补 `MaxTurns=1` 等覆盖测试。 |
| `IC-ROUTING-004` | P1 | `FindProvider` 只按 level 找 provider，不调用 `ILevelProvider.CanHandle`；L2/L3/L4 需要 LLM 但 `FLLM=nil` 时 engine 直接置空 provider，未走 provider-specific degraded result / `TDegradationHandler`。 | `FindProvider` 接受 `TProcessingContext` 并调用 `CanHandle`；缺 LLM 时调用 provider degraded path 或统一 `TDegradationHandler`。 |
| `IC-SLOTS-005` | P1 | `IDomainAdapter.GetPresetSlots` 仍未接入 engine 主路径；L1 provider 注释说 slots 来自 domain adapter，但 `BuildProcessingContext` 未填 slots。 | 在 session start 或 L1 request 构造时读取 domain adapter slots，并进入 `TIntentClarificationRequest` / context；补 domain slot 追问测试。 |
| `IC-HISTORY-006` | P1 | budget exhausted 分支在记录 turn history 前 `Exit`；普通 turn record 只写 `Question`，未写 `Answer` / `AssistantOutput`。 | 预算退出前也记录当前 turn；`TTurnRecord` 字段要按合同完整填充；补 history/checkpoint round-trip 测试。 |
| `IC-SESSION-007` | P1 | `TSessionManager.SaveCheckpoint` 明确把 `TurnHistory` / `OpenQuestions` 置 nil；`SuspendIdleSessions` 在枚举 `FSessions` 时 `AddOrSetValue` 修改同一字典。 | checkpoint 完整序列化 history/open questions；SuspendIdleSessions 先收集 keys 再批量更新。 |
| `IC-RESILIENCE-008` | P1 | `LLMResilience` 超时后只记录 slow log，不取消调用；retry 用 `Sleep`，不可取消；`GenerateImage` 直接透传，不进 circuit breaker/retry/timeout。 | 引入可取消超时或底层 transport timeout；retry 使用 cancellation-aware wait；明确或实现 image/stream resilience 语义。 |
| `IC-PROVIDER-009` | P1 | L2/L3 已改成 per-session dictionary，但这些 dictionary 仍在 provider 实例上且未加锁；多个 session 并发时仍可能竞态。`RegisterLLM` 创建 L3/L4 provider 时传入 nil persona registry。 | provider 状态加锁或迁到 canonical session state；`SetPersonaRegistry` 后能同步给 L3/L4 provider，或注册 LLM 时使用 engine 当前 registry。 |
| `LLMCHAT-UAF-010` | P0/P1 | `VCL/DeepBase.VCL.LLMChatFrame.pas` 和 `FMX/DeepBase.FMX.LLMChatFrame.pas` 仍用 anonymous thread 捕获 `Self/FClient/FHistory/UI`；`FCurrentTask` 声明但未赋值，析构不 cancel/wait。 | 改成可取消 task/worker，析构 drain；UI 更新只使用生命周期安全的 weak token；补关闭窗口时后台请求未完成的回归测试。 |
| `LLMCHAT-STREAM-011` | P2 | `EnableStreaming=True` 但 VCL 注释为“Streaming mode - use simple Chat”，FMX 注释为“Use non-streaming for simplicity”。 | 要么实现真实 streaming，要么把属性/文档改成当前不支持，避免下游误用。 |
| `SAPI-ASR-012` | P1 | `Features/DeepBase.Speech.ASR.SAPI.pas` 中 worker thread `FreeOnTerminate=True`，`Stop` 只 `Sleep(100)` 后释放 COM 对象。 | `FreeOnTerminate=False`，Stop 发 stop event 后 `WaitFor`，超时策略明确；COM 对象释放必须在 worker 退出后。 |
| `SUPABASE-COMMERCE-013` | P1 | `PaymentToJson` 写 `channel=''`，`EntitlementToJson` 写 `status=''`；`ConsumeEntitlement` PATCH body 把 `remaining_quota - X` 当字符串传给 PostgREST，重读后直接 `Result := True`，不能证明扣减成功。 | 枚举字段使用正式 serializer；额度扣减改 RPC/SQL function 或 PostgREST 支持的原子更新方案；验证 affected rows/返回 quota 变化。 |
| `PERSIST-UPSERT-014` | P1 | `Persistence.Security.FireDAC`、`Persistence.License.FireDAC`、`Persistence.Manager.FireDAC`、`DB.Factory` 仍有 `INSERT OR REPLACE`；SQLite replace 语义可能 delete+insert，带来 created_at/外键/竞态问题。 | 统一迁到 canonical UPSERT/transaction；必要时拆 SQLite/PostgreSQL 方言；补并发 upsert 回归。 |
| `RANDOM-BIAS-015` | P1 | `Core.DeepBase.Random.TSecureRandom.NextInt` 和 `Features.DeepBase.Math.TSecureRandom.NextInt` 仍用 `Value mod AMax`。`Core.DeepBase.Crypto.RandomInt` 已修，但同名安全随机 API 仍有模偏差。 | 用 rejection sampling；所有 `SecureRandom` 命名 API 统一 fail-closed。 |
| `ANTITAMPER-SALT-016` | P2/P1 | `Features.DeepBase.AntiTamper.pas` 仍有默认静态 salt `DeepMoveC_Default_Salt_2025`。 | 如果 AntiTamper 被用于安全边界，salt 必须 per-install/per-package 随机化或由外部密钥管理；若只是弱完整性提示，文档必须降级说明。 |
| `BROWSER-VERIFY-017` | P1 | `bugfix.md` 已修 BROWSER-005 ScriptStore contract，但 `better.md` 仍登记 Browser Registry/ResponseWaiter/CDP/WindowPool/Recovery/Session state 等 P1 风险；旧 `Tests/test_results.xml` 也曾记录 Browser 相关 fail/error，最新 unit 绿灯未证明真实 WebView2/message/lifecycle 场景已覆盖。 | 对 BrowserAutomation 增加真实 WebView2 smoke、ResponseWaiter postMessage object/string、multi-waiter、CDP destroy、WindowPool concurrent acquire/release 测试；以最新测试结果替换旧失败基线。 |
| `TEST-BASELINE-018` | P1 | `history.md` line 21 记录完整 `DeepBaseTests.exe` 曾有 `6 failed / 12 errored`；`Tests/test_results.xml` 曾有 `23 failures / 88 errors`；但 `TestResults/UnitTestResults.xml` 最新为 0 fail/error。文档和测试产物现在互相矛盾。 | 重新跑一次当前工作区 full unit / package / targeted integration，并把 `history.md`、`bugfix.md`、`TestResults` 的基线统一到同一次运行，避免继续按旧失败清单或旧绿灯误判。 |
| `DOWNSTREAM-ADAPTER-019` | P0 | 上一节已经确认多个 02Business 下游最终 EXE 缺 `DeepBase.Persistence.Manager.FireDAC`。这不是 DeepBase 内部 bugfix 能自动修复的，bugfix/docs 变更不会让下游程序自动链接 adapter。 | Batch 1 下游 `.dpr` 必须直接加 adapter；同时增加静态门禁，禁止只 uses `DeepBase.Manager` 就调用 DeepBase 初始化。 |

### 本轮未作为当前阻塞继续追的旧项

- `NEW-008` / `StateMachine.FireIfInState`：当前静态看不出原文所称“必死锁”，Delphi `TMonitor` 同线程重入通常可行，且 StateMachine 单测有通过记录；需要并发压测再定性。
- `PERSIST-004` / `UniPool.Initialize -> Warmup`：当前 `Initialize` 调的是私有 `DoWarmup`，旧的二次锁死锁形态看起来已修。
- `FEAT-001`、`FEAT-002`、`FEAT-012`、`PERSIST-005`、`PERSIST-014/015`、`PERSIST-019`：源码抽查看到已有明显缓解或修复痕迹，本次不把它们作为确认未修项；后续以专项测试结果为准。
