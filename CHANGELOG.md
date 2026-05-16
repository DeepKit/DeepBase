# Changelog

All notable changes to DeepBase are documented in this file.

## [Unreleased] - 2026-05-15

### Added
- **DeepBase.Speech.ASR.SenseVoice** — SenseVoice offline ASR backend (default local ASR). Loads SenseVoice ONNX model via DeepBase.Inference, performs FBank 80-dim feature extraction, LFR stacking, CMVN normalization, and CTC greedy decoding. Supports batch recognition and simulated streaming (partial decode every 500ms). Self-registers in TSpeechRegistry at Priority 5.
- **DeepBase.Speech.FBank** — 80-dim FBank feature extraction with Radix-2 FFT (padded to 512), 80 Mel filters, Hamming window. No external DLL dependencies.
- **DeepBase.Inference.Types** — `TInferenceElementType` (float32/int32) and `TInferenceInput` record for mixed-type tensor inputs.
- **DeepBase.Inference.Session** — `RunTyped` method supporting mixed float32/int32 tensor creation per input.
- `abkSenseVoice` added to `TASRBackendKind` enum. SenseVoice config keys: `speech.sensevoice.model_dir`, `speech.sensevoice.language`, `speech.sensevoice.use_itn`, `speech.sensevoice.partial_interval_ms`. Default ASR backend changed from `auto` to `sensevoice`.
- **DeepBase.Browser.PageDriver** — Natural language browser automation via Alibaba page-agent. Adds `dbasPageDriver` strategy and `baatDriveInstruction` action type to the existing BrowserAutomation framework, enabling NL→DOM→Action without screenshots or multi-modal LLMs.
- `TDriveCallback` — Delegate type for Runner→PageDriver bridge, allowing deterministic actions and NL instructions to be mixed in a single action sequence.
- IoC overload: `TBrowserIoCRegistration.RegisterAll(Container, Config)` accepts custom `TPageDriverConfig`.
- 24 DUnitX tests for PageDriver (config, JS generation, result parsing, executor state, runner integration).

### Changed
- Migrated command-line build and test gates to Delphi 13.1 Florence / BDS 37.0.
- Added Delphi 13.1 steering rules for global toolchain constraints, syntax samples, Skia 7.1 conventions, and SSE streaming patterns.
- Added Delphi 13.1 syntax samples across Core, Persistence, Features, VCL, and FMX.

### Fixed
- Removed legacy `VCL/UniBase.VCL.*` source and form files after confirming `DeepBase.VCL.*` replacements and no active references.
- Fixed Delphi 13.1 compatibility issues in ThirdParty DB and Payment helper units.
- Verified LLM proxy client scenarios against the mock proxy under Delphi 13.1.

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
