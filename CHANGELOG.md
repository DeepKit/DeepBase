# Changelog

All notable changes to DeepBase are documented in this file.

## [Unreleased]

> 本节覆盖 `v1.0.0` (2025-12-08) 至当前 HEAD 的累积变更，供消费者在下一个发布版本（计划 `v1.1.0`）到来前对齐。
> 以消费者视角组织：先看 **BREAKING CHANGES**，再看分类明细。内部工具链/审计门禁类改动不影响被引用的公开单元，归入 Changed 且不标 BREAKING。

### ⚠ BREAKING CHANGES（消费者必读）

- **命名空间与包名 `UniBase` → `DeepBase`（`ca3364ee`, 2026-05-09）**：全部单元前缀、`uses` 引用、BPL/包标识统一改为 `DeepBase.*`。锁定 `UniBase.*` 单元名的下游需改引用；抓引用的正则须支持点号单元名 `A.B.C`（见 `contract/consumer-contract.json` 的 `dot_name_note`）。
- **安全密钥体系重构（UBS2 v2）**：`DeepBase.Security.UBS2`、`DeepBase.Security.MachineIdentity`、`DeepBase.SecureMemory` 引入主口令（master.key）+ AAD 绑定；建钥路径收紧为 owner-only DACL，迁移取钥默认拒绝建钥（fail-closed）。旧版本用默认口令加密的 `Config`/`License` 密文不能直接在新版本解出，需走迁移。
- **DoQry 执行语义收紧**：移除 `ValidateSQL` 的静默改写；无 `WHERE` 的 DELETE 直接拦截；整数列统一走 `AsInt64` 防精度丢失。依赖旧“静默补全/改写”行为的调用方会由成功变为报错。`uDoQryLegacy`/`uDoQryExecutor` 源码由 GBK 转为 UTF-8。
- **配置与限流的默认失败方向**：未知限额的限流器默认 fail-closed（需显式 `FailOpenOnUnknownLimit` 放行）；JSON 根对象零序列化属性由静默跳过改为抛 `ESerializationException`；`WithLevel`/`WithLevels` 由覆盖改为追加去重。
- **构建工具链迁移到 Delphi 13.1 Florence / BDS 37.0**：命令行构建与测试门禁切换至 37.0，`Win64` 为默认目标平台。沿用旧 BDS 路径的脚本需更新 `BDS` 环境变量（见根目录 `build.bat` / `run_tests.bat`）。

### Added
- **消费者契约 SSOT** `contract/consumer-contract.json`：登记可被外部项目稳定引用的单元清单（`unit`/`subdir`/`stability`/`consumers`/`breaking_change_policy`），并配 `contract-gate` 门禁检测 stable 单元公开签名漂移（WO-20260924-AUDIT-甲-D9 段2）。
- **位置无关构建入口** 根目录 `build.bat` / `run_tests.bat`：先校验 `BDS`/`dcc64` 再委派仓内 PowerShell 脚本，打印真实产物路径（`TestResults\bpl64`/`dcp64`/`dcu64`），全新克隆仅凭仓内脚本即可构建并跑核心单测（WO-20260924-AUDIT-甲-D9 段3）。
- **纯 C ABI 插件契约（r2）**：`dbp_*` 固定符号契约 + `CAbiLoader`；插件双轨终裁——生产唯一真相源为旧 BPL 轨，新 C ABI 轨冻结隔离（`53ff5c97`）。
- **DeepBase.Speech.ASR.SenseVoice** — SenseVoice offline ASR backend (default local ASR). Loads SenseVoice ONNX model via DeepBase.Inference, performs FBank 80-dim feature extraction, LFR stacking, CMVN normalization, and CTC greedy decoding. Supports batch recognition and simulated streaming (partial decode every 500ms). Self-registers in TSpeechRegistry at Priority 5.
- **DeepBase.Speech.FBank** — 80-dim FBank feature extraction with Radix-2 FFT (padded to 512), 80 Mel filters, Hamming window. No external DLL dependencies.
- **DeepBase.Inference.Types** — `TInferenceElementType` (float32/int32) and `TInferenceInput` record for mixed-type tensor inputs.
- **DeepBase.Inference.Session** — `RunTyped` method supporting mixed float32/int32 tensor creation per input.
- `abkSenseVoice` added to `TASRBackendKind` enum. SenseVoice config keys: `speech.sensevoice.model_dir`, `speech.sensevoice.language`, `speech.sensevoice.use_itn`, `speech.sensevoice.partial_interval_ms`. Default ASR backend changed from `auto` to `sensevoice`.
- **DeepBase.Browser.PageDriver** — Natural language browser automation via Alibaba page-agent. Adds `dbasPageDriver` strategy and `baatDriveInstruction` action type to the existing BrowserAutomation framework, enabling NL→DOM→Action without screenshots or multi-modal LLMs.
- `TDriveCallback` — Delegate type for Runner→PageDriver bridge, allowing deterministic actions and NL instructions to be mixed in a single action sequence.
- IoC overload: `TBrowserIoCRegistration.RegisterAll(Container, Config)` accepts custom `TPageDriverConfig`.
- 24 DUnitX tests for PageDriver (config, JS generation, result parsing, executor state, runner integration).
- HB runtime contract、触点遥测引擎与 7 步生命周期管线；Schema 幂等迁移与 PostgreSQL 兼容 DDL。

### Changed
- Migrated command-line build and test gates to Delphi 13.1 Florence / BDS 37.0.
- Added Delphi 13.1 steering rules for global toolchain constraints, syntax samples, Skia 7.1 conventions, and SSE streaming patterns.
- Added Delphi 13.1 syntax samples across Core, Persistence, Features, VCL, and FMX.
- Schema DDL PostgreSQL 兼容性：移除 `AUTOINCREMENT` 与 `INSERT OR IGNORE`，改用方言化建表与 upsert（Config/License/I18n 保留兄弟列）。
- 编译器告警清理批（H2077/H2164/H2219）删除死赋值与死代码；`Schema.pas` 多重 CR 前置修复；全库 `.gitattributes` renormalize（行尾统一）。
- 审计工程门禁面扩展：全库 `.dpr`/`.dpk` 编译门禁、evidence 编码门禁、mojibake（丙类编码损坏）门禁、build-ownership 门禁，均 fail-closed 并接入 CI（`self-hosted, delphi-windows`）。

### Fixed
- Removed legacy `VCL/UniBase.VCL.*` source and form files after confirming `DeepBase.VCL.*` replacements and no active references.
- Fixed Delphi 13.1 compatibility issues in ThirdParty DB and Payment helper units.
- Verified LLM proxy client scenarios against the mock proxy under Delphi 13.1.
- 审查修复批量落地（CR-001…CR-315 等）：KeyManager 盐持久化 + KEK 校验、OpenSSL PBKDF2 签名对齐、接口 GUID 唯一化、record 序列化加固、EventBus 回调防护、JobQueue PG 出队 SKIP LOCKED、Pool ABBA 锁序、ORM Insert/Update 参数语义拆分等。
- A18 BPL 端到端卸载真机验证通过（正向 + 负向 + 文件级释放）。

### Removed
- `Persistence/DeepBase.External.BCryptDecrypt.pas`、`Persistence/DeepBase.External.SQLiteReader.pas`、`VCL/DeepBase.AutoFix.ErrorRecorder.VCL.pas`（无引用的孤立旧实现）。
- `DeepBaseStudio.dpr` / `.dproj` 死入口工程（双入口分叉消解，统一入口，WO-20260923-AUDIT-甲-D7 段1）。
- 窄口 runner `Tests/TestSecurityM2.dpr`（M2 迁移演练重定向到统一测试入口）。

## [1.0.0] - 2025-12-08

### Added - Core Modules
- **DeepBase.Manager** - Central management singleton with Initialize/Finalize lifecycle
- **DeepBase.Config** - Type-safe configuration with encryption support
- **DeepBase.i18n** - Internationalization with T()/TFmt()/TPlural() functions
- **DeepBase.Logging** - Async logging with file rotation and DB storage
- **DeepBase.FormState** - Window state persistence (position, size, splitters)
- **DeepBase.MRU** - Most Recently Used items with pinning
- **DeepBase.Hotkeys** - Global keyboard shortcuts management
- **DeepBase.Theme** - UI theme switching (Material/Fluent/macOS styles)
- **DeepBase.LLM** - Multi-provider LLM integration (OpenAI/Claude/Azure/Ollama)
- **DeepBase.DB.DoQry** - JSON-parameterized database access layer
- **DeepBase.ORM** - Simple ORM with TEntity/TRepository pattern
- **DeepBase.Scheduler** - Cron-based task scheduling
- **DeepBase.EventBus** - Publish/Subscribe event system
- **DeepBase.Validation** - Data validation with fluent API
- **DeepBase.Authorization** - Role-based access control
- **DeepBase.RateLimiter** - Token bucket rate limiting
- **DeepBase.CircuitBreaker** - Fault tolerance pattern
- **DeepBase.WorkerQueue** - Background job processing
- **DeepBase.Metrics** - Counter/Gauge/Histogram metrics
- **DeepBase.Math** - Vector/Matrix/Statistics/Interpolation utilities
- **DeepBase.Net** - HTTP client and network utilities

### Added - VCL Controls (14 components)
- TI18nLabel, TI18nButton, TI18nCheckBox, TI18nRadioButton
- TConfigEdit, TConfigComboBox, TConfigCheckBox, TConfigSpinEdit
- TThemeSwitcher, TLanguageSwitcher
- TLogListView, TMRUMenu, TNotificationBar, TLicenseStatusPanel

### Added - FMX Controls (15 components)
- TFMXConfigEdit, TFMXConfigSwitch, TFMXConfigComboBox
- TFMXThemeSwitcher, TFMXLanguageSwitcher
- TFMXLogListView, TFMXMRUList
- TFMXWaitForm, TFMXMessageDialog, TFMXInputDialog
- TFMXAutoUpdater, TFMXUpdateDialog
- TFMXNotificationBar, TFMXToast

### Added - Tools
- **DeepBase Studio** - GUI management tool for database/config/logs
- **DeepBase Tray** - System tray utility for quick access
- **DeepBase CLI** - Command-line interface for automation

### Added - Templates & Extensions
- **ECommerceApp** - E-commerce application template
- **RealtimeChatApp** - Real-time chat application template
- **PostgreSQL Driver** - PostgreSQL database adapter
- **MySQL Driver** - MySQL database adapter
- **UI Themes** - Material/Fluent/macOS theme packs
- **Cloud Storage** - AWS S3/Azure Blob/Aliyun OSS integration

### Added - Documentation
- Integration Guide (AI-focused)
- API Reference
- Database Schema Guide
- FAQ & Error Reference
- User Manuals (CLI/Studio/Tray)

### Fixed - Bug Fixes (49+)
- BUG-001: Config deadlock in concurrent writes
- BUG-007: Theme switch refresh issue
- BUG-009: TI18nLabel empty after language switch
- BUG-018: AutoUpdate SHA256 validation
- BUG-021: DoQry memory leak
- BUG-039: Manager missing MRU/Hotkeys properties
- BUG-040: License test wrong property
- BUG-041: Scheduler concurrent count race condition
- BUG-042: MRU UNC path cleanup
- BUG-043: EventBus generic filter ignored
- BUG-044: UniDbSetCacheTTL null lock
- BUG-045: TokenBucket divide by zero
- BUG-046: WorkerQueue wait semantics
- BUG-047: WorkerQueue stats non-atomic
- BUG-048: Authorization audit action mapping
- BUG-049: HttpServer binary file corruption
- ... and 33 more fixes

### Performance
- Config cache hit rate: 95%+
- i18n query time: < 0.1ms
- Logging throughput: 10k logs in 3s
- TLogListView: Virtual scrolling for 100k+ logs

---

## [0.3.0] - 2025-11-28

### Added
- Schema version migration mechanism
- Database connection pool
- Log file rotation (10MB default)
- Encrypted configuration support

### Changed
- API: `Initialize(':memory:')` �?`InitializeWithDB(':memory:')`
- API: `Initialized` �?`IsInitialized`
- API: `Connection` �?`ConfigDB`

### Fixed
- Hotkeys table column name mismatch (IsCustom �?IsCustomized)
- FormState RTTI context caching
- Logger thread safety (ResetEvent timing)

---

## [0.2.0] - 2025-11-15

### Added
- Phase 0-3 core modules
- VCL control library
- Basic documentation

---

## [0.1.0] - 2025-11-01

### Added
- Initial project structure
- Core architecture design
- Database schema (23 tables)
