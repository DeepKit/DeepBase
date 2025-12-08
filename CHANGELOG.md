# Changelog

All notable changes to UniBase are documented in this file.

## [1.0.0] - 2025-12-08

### Added - Core Modules
- **UniBase.Manager** - Central management singleton with Initialize/Finalize lifecycle
- **UniBase.Config** - Type-safe configuration with encryption support
- **UniBase.i18n** - Internationalization with T()/TFmt()/TPlural() functions
- **UniBase.Logging** - Async logging with file rotation and DB storage
- **UniBase.FormState** - Window state persistence (position, size, splitters)
- **UniBase.MRU** - Most Recently Used items with pinning
- **UniBase.Hotkeys** - Global keyboard shortcuts management
- **UniBase.Theme** - UI theme switching (Material/Fluent/macOS styles)
- **UniBase.LLM** - Multi-provider LLM integration (OpenAI/Claude/Azure/Ollama)
- **UniBase.DB.DoQry** - JSON-parameterized database access layer
- **UniBase.ORM** - Simple ORM with TEntity/TRepository pattern
- **UniBase.Scheduler** - Cron-based task scheduling
- **UniBase.EventBus** - Publish/Subscribe event system
- **UniBase.Validation** - Data validation with fluent API
- **UniBase.Authorization** - Role-based access control
- **UniBase.RateLimiter** - Token bucket rate limiting
- **UniBase.CircuitBreaker** - Fault tolerance pattern
- **UniBase.WorkerQueue** - Background job processing
- **UniBase.Metrics** - Counter/Gauge/Histogram metrics
- **UniBase.Math** - Vector/Matrix/Statistics/Interpolation utilities
- **UniBase.Net** - HTTP client and network utilities

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
- **UniBase Studio** - GUI management tool for database/config/logs
- **UniBase Tray** - System tray utility for quick access
- **UniBase CLI** - Command-line interface for automation

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
- API: `Initialize(':memory:')` → `InitializeWithDB(':memory:')`
- API: `Initialized` → `IsInitialized`
- API: `Connection` → `ConfigDB`

### Fixed
- Hotkeys table column name mismatch (IsCustom → IsCustomized)
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
