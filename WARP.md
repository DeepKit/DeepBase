# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## 1. Key docs and entry points

When you start working in this repo, orient yourself using these files first:

- `README.md` (root): high-level project positioning, core features, and an overview of the directory structure (Core, VCL, FMX, Tools, Examples, Tests, sql, docs). Also shows a minimal example of initializing UniBase and a basic DUnitX test command.
- `QUICK_START.md` (root): documentation index for project status and history:
  - `tasks.md`, `history.md`, `bugfix.md`, `tasks_next.md`, `DOCS_UPDATE.md` – progress tracking, completed work, planned tasks, and documentation rules.
- `ARCH-QUICKSTART.md` (root): **primary entry for AI tools and new developers**. Defines:
  - The architectural layering model (View → Controller → Domain → Data Access/uDM/DoQry).
  - Mandatory reuse of existing UniBase subsystems (Config, i18n, Logging, MRU, Hotkeys, DoQry, TestHelper, etc.).
  - Hard constraints for AI (what is forbidden, how to integrate with tests & automation, and how to search the codebase before generating new code).
- `docs/00_README.md`: documentation hub. Points to architecture, API reference, FAQ/Troubleshooting, the formal spec, and (future) AI-specific rule documents.
- `docs/01_Architecture.md`: **canonical architecture design**. Describes the layered structure (Application → Tools → VCL/FMX → Core → Foundation), technical choices (SQLite config DB, logging, i18n, security), and key modules like `UniBase.Manager`, `UniBase.Config`, `UniBase.i18n`, Logging, Plugin, DataBinding, MVVM, ORM, IoC, and Security.
- `docs/Best_Practices.md`: concrete examples of how to use UniBase for configuration, i18n, logging, exceptions, performance, database access, plugins, MVVM, security, and testing. Use this when you need non-trivial code patterns (e.g., MVVM bindings, plugin lifecycle, secure configuration).
- `CloudServices/README.md`: explains the JSON formats and deployment patterns for cloud-hosted version metadata (`version.json`) and remote configuration (`remote-config.json`) that UniBase clients consume.
- `sql/README.md`: explains the schema of the local SQLite `config.db` (Tier 0 core tables like `SchemaInfo`, `Settings`, `FormStates`, `Languages`, `I18nTexts`), initialization and upgrade scripts, and schema-versioning conventions.
- `UniBaseRun/QUICK_START.md`: describes `UniBaseRun/` – a separate FMX sample application that demonstrates UniBase usage (logging viewer, config editor, login/CRUD skeleton). It outlines its own docs and planned scripts; treat it as a client app built on this framework.

## 2. Common commands (Windows / Delphi)

All commands below assume you are in the repository root (`UniBase/`) on Windows with Delphi installed.

### 2.1 Running automated tests via `Scripts/run_tests.ps1`

The primary test entrypoint is `Scripts/run_tests.ps1` (PowerShell).

**Usage (from repo root):**

- Run all tests (unit + integration) and generate an HTML report:
  - `pwsh -File Scripts/run_tests.ps1 -Type All -Report`
- Run only unit tests:
  - `pwsh -File Scripts/run_tests.ps1 -Type Unit`
- Run only integration tests:
  - `pwsh -File Scripts/run_tests.ps1 -Type Integration`
- CI-style run (defines `CI`, suitable for pipelines):
  - `pwsh -File Scripts/run_tests.ps1 -Type All -CI -Report`

Key behavior (summarized from the script):

- Compiles tests using `dcc32.exe` from your Delphi installation with search paths for `Core`, `VCL`, `Tests`, and `Tests/Integration`.
- Creates an output directory under the repo (default: `TestResults`).
- Unit tests:
  - Builds `Tests/UniBaseTests.dpr`.
  - Runs `Tests/UniBaseTests.exe` with DUnitX options like `--xmloutput:TestResults\UnitTestResults.xml` and `--exitbehavior:Continue`.
- Integration tests:
  - Builds `Tests/Integration/UniBaseIntegrationTests.dpr`.
  - Runs `Tests/Integration/UniBaseIntegrationTests.exe` with `--xmloutput:TestResults\IntegrationTestResults.xml`.
- `-CI` adds the `CI` define so tests do not block waiting for console input.
- `-Report` post-processes XML outputs into an HTML summary (named `TestReport_yyyyMMdd_HHmmss.html` in the output directory).

Always prefer this script for local and CI test runs unless you have a specific reason to drive `dcc32`/`msbuild` directly.

### 2.2 Running tests directly with DUnitX executables

If the PowerShell runner is unavailable or you want to debug directly against the test executables:

1. **Build unit tests (example using Delphi 11 Alexandria / 12.x path – adjust to your install):**
   - `& "C:\\Program Files (x86)\\Embarcadero\\Studio\\23.0\\bin\\dcc32.exe" Tests\\UniBaseTests.dpr`
2. **Run unit tests with XML output (from repo root):**
   - `& .\\Tests\\UniBaseTests.exe --xmloutput:TestResults\\UnitTestResults.xml --exitbehavior:Continue`
3. **Build and run integration tests similarly:**
   - `& "C:\\Program Files (x86)\\Embarcadero\\Studio\\23.0\\bin\\dcc32.exe" Tests\\Integration\\UniBaseIntegrationTests.dpr`
   - `& .\\Tests\\Integration\\UniBaseIntegrationTests.exe --xmloutput:TestResults\\IntegrationTestResults.xml --exitbehavior:Continue`

These options align with how the DUnitX bootstrap code in `UniBaseTests.dpr` and `UniBaseIntegrationTests.dpr` is written (it calls `TDUnitX.CheckCommandLine` and uses `XMLOutputFile` / `ExitBehavior`).

### 2.3 Running a single DUnitX test or fixture

DUnitX supports filtering which tests run via standard command-line options parsed by `TDUnitX.CheckCommandLine`.

To run a single fixture (or a specific test method) from the unit test binary:

- `& .\Tests\UniBaseTests.exe --run:<FixtureOrTestName>`

Guidance:

- `<FixtureOrTestName>` must match the `[TestFixture]` class name or a fully-qualified test method name defined in the relevant `Tests/Test.UniBase.*.pas` file (e.g., a fixture in `Test.UniBase.Manager.pas`).
- When you need to run only a portion of the suite, open the target test unit, locate the `[TestFixture]` declaration, and use that name in the `--run:` argument.

(If you need more advanced filters such as categories or name patterns, follow the standard DUnitX command-line conventions.)

### 2.4 CI-style build + test (from `ARCH-QUICKSTART.md`)

For non-interactive builds/tests (e.g., CI agents), the recommended flow is:

1. Initialize the Delphi command-line environment:
   - `call "C:\\Program Files (x86)\\Embarcadero\\Studio\\23.0\\bin\\rsvars.bat"`
2. Build unit tests:
   - `msbuild Tests\\UniBaseTests.dproj /t:Build /p:Config=Debug /p:Platform=Win32`
3. Run unit tests with XML output (CI mode):
   - `Tests\\Win32\\Debug\\UniBaseTests.exe --xmloutput=TestResults.xml --exitbehavior=Continue`

You can extend this pattern to integration, GUI, and stress tests by pointing `msbuild` and the executable invocation at the corresponding `.dproj` / `.exe` in `Tests/`.

### 2.5 Installing UniBase core packages in Delphi

For developers working in the Delphi IDE:

- Open `UniBaseCore.dpk` and `dclUniBaseCore.dpk` from the repo root.
- Compile and install the design-time package so UniBase components and design-time editors are available in the IDE.
- Ensure your IDE library/search paths include `Core/`, `VCL/`, `FMX/`, and (for consumers) any additional units you use.

### 2.6 Running examples and UniBaseRun

- **Examples**: each subdirectory under `Examples/` (e.g., `FMXDemo/`, `FullDemo/`, `Phase0Demo/`, templates under `Examples/Templates/`) is a standalone demo project with its own `README.md` and Delphi project files. Open the `.dproj` in Delphi and run from the IDE; use these as references for how to consume UniBase in real applications.
- **UniBaseRun**: `UniBaseRun/` is an FMX sample application that is still early in development. Its `QUICK_START.md` documents planned scripts under `UniBaseRun/scripts/` (`build.bat`, `test.bat`, etc.), but these may not yet exist. Before using any of those commands, check whether the scripts and `tests/` projects have actually been created.

## 3. High-level architecture and structure

This section summarizes the “big picture” architecture so you can quickly locate the right layer or subsystem when editing code.

### 3.1 Layering overview

From `docs/01_Architecture.md` and `ARCH-QUICKSTART.md`, UniBase uses two complementary views of the architecture:

1. **Framework layering (inside UniBase itself):**
   - **Foundation layer** (`Core/UniBase.Types`, `UniBase.Manager`, base DB and utils): low-level types, lifecycle management, DB access primitives, and common utilities.
   - **Core layer** (`Core/`): cross-cutting subsystems such as configuration, i18n, logging, plugin system, data binding, MVVM, ORM, IoC, security, scheduling, caching, rate limiting, resilience, worker queues, metrics, feature flags, etc.
   - **UI layer** (`VCL/`, `FMX/`): reusable controls and helpers for VCL and FMX that bind to core services (config, i18n, logging, MRU, themes, etc.).
   - **Tools layer** (`Tools/`): standalone utilities (Studio, Tray, CLI, LogAnalyzer, WebService) built on top of Core+UI.
   - **Applications** (`Examples/`, `UniBaseRun/`, external consumers): actual end-user apps that consume UniBase.

2. **Application layering (for UniBase-based apps):**
   - **View layer**: forms/frames (VCL or FMX). Responsible only for UI rendering and user input, using UniBase-bound controls (config-binding controls, i18n controls, etc.).
   - **Controller layer**: application services that orchestrate workflows, calling domain services and data-access modules. Controllers use UniBase services (`Config`, `Logger`, `DoQry`, etc.) and domain objects but should not directly own UI forms.
   - **Domain layer**: entities and business services independent of VCL/FMX/FireDAC/UniBase UI. Highly testable and should have strong unit test coverage.
   - **Data Access layer**: data modules (`uDM`), repositories, and DoQry-based data access, responsible for DB connections, queries, and transactions but not for business rules or UI.

When adding or modifying code, always decide which of these layers you are working in and keep dependencies one-directional (View → Controller → Domain → Data Access → Core/Foundation).

### 3.2 Core subsystems (`Core/`)

The `Core/` directory contains the non-UI building blocks that everything else depends on. Important families of modules include:

- **Lifecycle and routing:** `UniBase.Manager` is the entry point that initializes/shuts down UniBase and provides access to submodules (Config, i18n, Logger, etc.). Client apps typically call `UniBase.Initialize` near `Application.Initialize` and `UniBase.Finalize` at shutdown.
- **Configuration:** `UniBase.Config` implements a typed configuration system backed by SQLite (`config.db`) with caching, change notifications, and encrypted storage for sensitive values. Most configuration-related code should go through this module rather than using INI/registry/JSON files.
- **Internationalization:** `UniBase.i18n` provides translation functions (`T`, `TFmt`, pluralization) and utilities for translating entire forms. It is backed by tables like `Languages` and `I18nTexts` defined in `sql/`.
- **Logging and diagnostics:** `UniBase.Logging` offers leveled logging (Debug/Info/Warn/Error/Fatal), file + DB sinks, timing helpers, and structured logging patterns. `UniBase.Benchmark`, metrics, and related modules support performance measurement and monitoring.
- **Data access and ORM:** modules under `Core/UniBase.DB.*` encapsulate connection pooling, parameterized queries (`DoQry`), and higher-level ORM abstractions (`UniBase.ORM.*`) for mapping entities to tables and issuing queries.
- **IoC and composition:** `UniBase.IoC` and related modules provide dependency injection capabilities (type registration, singletons, factories, attribute-based injection) used heavily by higher-level subsystems and plugins.
- **Plugins and extensibility:** `UniBase.Plugin`, `UniBase.PluginManager` and related types implement a plugin architecture where external BPLs can register capabilities, access host services, and participate in the app lifecycle.
- **Patterns and infrastructure:** there are dedicated modules for MVVM (`UniBase.MVVM.*`), validation, state machines, event bus, worker queues, rate limiting, scheduling, collections, caching, serialization, security/authorization, template engines, etc. When you need one of these concerns, search `Core/` first – there is usually an existing implementation.

### 3.3 UI layers (`VCL/` and `FMX/`)

The UI libraries adapt Core concepts into reusable, bindable components:

- **VCL:** `VCL/` includes controls and helpers such as configuration-aware edits/check boxes/spin edits, i18n-aware labels/buttons/menu items, MVVM binding controls, MRU controls, log viewers, notification bars, auto-updater dialogs, license dialogs, DB initialization wizards, and wait forms. These controls are designed to:
  - Bind directly to `UniBase.Config` keys.
  - Surface logging, MRU, and theme state in the UI.
  - Integrate with MVVM patterns from `Core/`.
- **FMX:** `FMX/` offers the FMX equivalents of configuration and i18n controls, theme integration, list views, waiting dialogs, and other shared UI primitives designed to work cross-platform.

When building end-user applications, prefer using these components instead of hand-rolling bindings or translation logic in forms.

### 3.4 Tools (`Tools/`)

The `Tools/` directory contains standalone applications that exercise and support UniBase:

- **CLI**: command-line tool(s) for interacting with UniBase services (e.g., config/DB operations, maintenance tasks).
- **Studio**: a GUI “control center” built on UniBase for inspecting logs, editing configuration, managing themes/plugins, etc.
- **Tray**: a tray-resident helper that exposes common UniBase capabilities (status, quick actions) in the system tray.
- **LogAnalyzer**: specialized tooling for log inspection and analysis.
- **WebService**: HTTP-based services built on UniBase’s core modules (e.g., remote config/version endpoints) using the same conventions as desktop apps.

All of these tools are consumers of the same core modules and patterns that application code should use; they are good references for how to structure higher-level features.

### 3.5 Data and cloud integration (`sql/`, `CloudServices/`)

- **Local config DB (`config.db`):**
  - Schema is documented in `sql/README.md` and implemented by scripts like `tier0_init.sql`.
  - Core tables (`SchemaInfo`, `ProjectInfo`, `Settings`, `FormStates`, `Languages`, `I18nTexts`) support configuration storage, form state persistence, and i18n.
  - Upgrade scripts `sql/upgrade_v*.sql` follow a strict versioned naming scheme and use transactional DDL+DML with `SchemaInfo` updates.
- **Cloud services:**
  - `CloudServices/version.json` and `CloudServices/remote-config.json` define the contract for auto-update and remote configuration.
  - Server-side deployment can be pure static hosting (e.g., Nginx/OSS/S3) or dynamic APIs (examples are given in Go and Delphi WebBroker).
  - Client-side integration uses UniBase modules like `TUniBaseAutoUpdate` and `TUniBaseRemoteConfig` to check versions, download updates, fetch remote config, and evaluate feature flags.

Application code should treat these as infrastructure concerns delegated to UniBase modules, not as ad-hoc HTTP/JSON logic embedded in forms or controllers.

### 3.6 Tests (`Tests/`)

The `Tests/` tree provides several complementary test suites:

- **Unit tests** (`Tests/UniBaseTests.dpr` + `Tests/Test.UniBase.*.pas`): DUnitX-based tests focused on individual core modules (Manager, Config, i18n, FormState, Logging, MRU, Hotkeys, Theme, License, DB/DoQry, collections, graph, ORM, scheduler, security, etc.).
- **Integration tests** (`Tests/Integration/UniBaseIntegrationTests.dpr`): higher-level scenarios that exercise multiple modules together via `UniBase.IntegrationTest` and dedicated integration fixtures.
- **GUI tests** (`Tests/GUI/`): DUnitX-based or custom harnesses that drive UniBase UI components and example forms.
- **Stress/performance tests** (`Tests/Stress/`): workloads for validating stability and performance boundaries of subsystems like resilience, worker queues, or DB access.

When modifying or adding features in Core/UI/Tools, you should expect to create or update the corresponding tests in these locations and wire them into the existing DUnitX projects.

### 3.7 Example and host applications

- **Examples/**: a curated set of small, focused demos illustrating specific UniBase capabilities (FMX, VCL, multi-language support, phased features, plugin architecture, templates for CRUD/DocManager/DataAnalyzer, etc.). These projects show idiomatic usage of View/Controller/Domain/uDM layering on top of UniBase.
- **UniBaseRun/**: an FMX “standard app” that demonstrates how to build a real-world UniBase-based application with logging viewer, config editor, and CRUD skeletons. Its own docs (`UniBaseRun/docs/*.md`) describe constraints like “FMX only”, flat (zero-directory) file layout, and strict View→Ctrl→Model/uDM layering for that app.

## 4. Guidance and constraints for WARP / AI agents

This section adapts the AI-specific rules from `ARCH-QUICKSTART.md` and related docs to WARP.

### 4.1 Search and reuse before generating code

Before writing new code, always:

- **Search the existing codebase** for relevant functionality (e.g., use `grep`/Warp search for `GetConfig`, `DoQry`, `I18n`, `Logger`, `Hotkeys`, `MRU`, `TestHelper`, etc.).
- **Prefer reusing or extending** existing UniBase modules over introducing parallel implementations.
- When you propose or apply changes, explicitly mention which existing modules you reused (e.g., `UniBase.Config`, `UniBase.DB.DoQry`, `UniBase.Logger`, `UniBase.MVVM`, etc.).

### 4.2 Mandatory module usage

When implementing new features or modifying existing ones, these pairings are mandatory:

- **Configuration:** use `UniBase.Config` (and constants from `UniBase.Consts`) rather than `TIniFile`, Windows Registry, ad-hoc JSON/YAML files, or custom key-value stores.
- **Internationalization:** use `UniBase.i18n` (`T`, `TFmt`, pluralization helpers) and I18n-aware controls; do not hardcode user-facing text in any language.
- **Logging:** use `UniBase.Logging` (and associated helpers) instead of `OutputDebugString`, `WriteLn`, message boxes, or custom log files for diagnostic output.
- **Window state & MRU:** use `UniBase.FormState` / `TFormStateHelper`, `UniBase.MRU`, `UniBase.Hotkeys`, `UniBase.Theme`, etc., for their respective concerns.
- **Database access:** use `UniBase.DB.DoQry` and established uDM/repository patterns; avoid raw string-concatenated SQL in UI or controllers.
- **GUI testing:** use `UniBase.TestHelper` and existing GUI test harnesses instead of inventing new GUI test frameworks.

If you find code that violates these rules, prefer refactoring it toward the UniBase-style approach rather than adding similar violations.

### 4.3 Hard prohibitions

From `ARCH-QUICKSTART.md`, the following are explicitly forbidden for AI-generated changes and should generally be avoided by humans as well:

- Introducing new configuration mechanisms based on INI files, Windows Registry, or arbitrary JSON files instead of `UniBase.Config`/`config.db`.
- Hardcoding user-visible text (Chinese, English, or any language) directly in code without going through the i18n system.
- Using message-pump-driven patterns like `Application.ProcessMessages` loops or unsafe `TThread.Synchronize` usage to manage concurrency.
- Performing database queries directly from forms/frames (`View` layer), especially raw `TFDQuery.ExecSQL` calls tied to UI events.
- Having data modules (`uDM`) reference UI units like `Vcl.Forms` / `Dialogs` or manipulate visual components.
- Storing important business state (current user, current order, etc.) in global variables instead of proper services/context objects.

If a requested change appears to require one of these patterns, stop and instead propose a design that stays within UniBase’s architectural constraints (e.g., add/extend a service in `Core/` or a controller in the app layer).

### 4.4 Testing expectations for changes

When you change behavior in Core, UI components, or Tools:

- **Unit tests:** locate the closest `Tests/Test.UniBase.*.pas` file(s) for the module you are touching (e.g., `Config`, `i18n`, `FormState`, `Logging`, `DB.DoQry`, `Security`, `StateMachine`, etc.). If tests exist, update them; if none exist for that module but the pattern is established, add new DUnitX fixtures aligned with existing style.
- **Integration/GUI tests:** for high-level flows or UI-visible behavior, check whether there is an appropriate integration or GUI test and extend it where reasonable.
- After modifications, run `Scripts/run_tests.ps1` with the appropriate `-Type` or run the specific DUnitX executables you affected (using the `--run:` filter when targeting individual fixtures).

### 4.5 How to approach new feature requests

When using WARP to implement or change features in this repo:

1. **Determine scope and layer:** decide whether the request belongs to Core (`Core/`), Framework UI (`VCL/`/`FMX/`), Tools (`Tools/`), Example apps (`Examples/`), or UniBaseRun (`UniBaseRun/`).
2. **Read relevant docs:** at minimum, consult `README.md`, `ARCH-QUICKSTART.md`, `docs/01_Architecture.md`, and (when patterns are involved) the relevant parts of `docs/Best_Practices.md`.
3. **Reuse patterns:** look for similar modules or features and follow their patterns (naming, folder placement, public API style, test structure) instead of designing new ones from scratch.
4. **Keep changes minimal and localized:** prefer small, well-scoped changes with clear tests over wide-reaching refactors unless the user explicitly asks for architectural work.
5. **Explain build/test impact:** when you propose or apply code, always mention how to build and test the affected parts using the commands in section 2.
