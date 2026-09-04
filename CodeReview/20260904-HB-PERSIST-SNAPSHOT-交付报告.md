# WO-20260904-004 · HB 遥测持久化与会话快照恢复交付报告

**工单编号**: WO-20260904-004 (HB-PERSIST-SNAPSHOT)  
**执行周期**: 2026-09-04  
**指派对象**: 罗辑 (software-tools / 主编码代理)  
**规范依据**:
- `docs/30.touchpoint.md` v2.0 第 6 节 (本地优先遥测 · best-effort 持久化)
- `docs/30.touchpoint.md` v2.0 第 7 节 (会话快照恢复 · 覆盖误关/切出/崩溃)
- `docs/31.hb-test.md` v1.1 第 7 项门禁 (证据写入延迟 P95 ≤ 2.0ms)

---

## 1. 任务完成矩阵

| 任务项 | 状态 | 目标文件 / 产物 | 交付说明 |
| :--- | :--- | :--- | :--- |
| **契约 Brief 先行** | **DONE** | `docs/ui/work-orders/WO-20260904-004-brief.md` | 锁定目标、范围、架构红线、性能指标与验收门禁 |
| **Task A1: Core 持久化槽抽象** | **DONE** | `Core/DeepBase.HB.Touchpoint.Types.pas`<br>`Core/DeepBase.HB.Touchpoint.Engine.pas` | 定义 `IHbTelemetrySink` 槽接口；引擎实现 `SetSink`、`GetSink`、`FlushSink`、`CheckAutoFlush`；50% 容量水位与 30s 自动落盘；未注入时零破坏维持纯内存模式；**Core 保持纯 RTL 零重依赖** |
| **Task A2: SQLite WAL 遥测持久化驱动** | **DONE** | `Persistence/DeepBase.Persistence.HBTelemetry.FireDAC.pas` | 在 Persistence 层实现 `THbFireDACTelemetrySink`，复用 FireDAC + SQLite WAL 模式，创建 `hb_evidence` 单表与索引；存储位置走 AppData 机制（`GetDefaultHbDatabasePath`）；满足零 PII 纪律 |
| **Task B1: 会话快照框架** | **DONE** | `Core/DeepBase.HB.Touchpoint.Types.pas`<br>`Persistence/DeepBase.Persistence.HBTelemetry.FireDAC.pas` | Core 定义 `IHbSnapshotProvider` 接口；Persistence 层实现 `THbFireDACSnapshotStorage`（`hb_snapshots` 表），支持 `SaveSnapshot`、`LoadSnapshot`、`DeleteSnapshot` 及 7 天 TTL `PurgeExpiredSnapshots` |
| **Task B2: 试点容器快照适配** | **DONE** | `VCL/DeepBase.VCL.HB.Dialogs.pas`<br>`VCL/DeepBase.VCL.HB.Waterfall.pas` | 1) `THbDialogWizardSession` 接入 `IHbSnapshotProvider`，支持向导步骤与字段序列化/反序列化与恢复提示文案；<br>2) `THbFacetWaterfall` 接入 `IHbSnapshotProvider`，支持分面排除、卡片折叠/详情展开、呈现模式恢复与提示文案 `"已为您恢复上次推演进度"` |
| **Task C1-C3: 测试与性能守护** | **DONE** | `Tests/Test.DeepBase.HB.Persistence.pas`<br>`Tests/DeepBaseTests.dpr` | 覆盖 Sink 3 路径 flush、WAL 模式、AppData 路径、未注入回归、崩溃模拟读取、零 PII 结构化审计、快照保存/恢复/任务完成清理/7 天 TTL 清理、跨进程重启模拟恢复、P95 延迟门禁、Core 防污染扫描 |

---

## 2. 架构决策与设计取舍 (Architecture Decisions & Trade-offs)

### 2.1 遥测持久化分层隔离（红线守护）
- **问题**: Core 层必须保持轻量、跨平台与零重依赖，严禁直接引用 `FireDAC.*` 或 `Data.DB`。
- **方案**: 采用**依赖倒置 (IoC) 注入式持久化槽**。Core 只定义 `IHbTelemetrySink` 接口（纯 RTL），`THbTouchpointEngine` 暴露 `SetSink(ASink)`。
- **效果**:
  - 当未注入 Sink 时，引擎维持纯内存 10,000 条环形缓冲，不产生任何 I/O 与依赖开销；
  - 当注入 Sink 时，在 50% 缓冲水位（5,000 条）、30s 定时检查或进程正常退出时异步/平滑批量写入 SQLite；
  - 静态架构扫描验证：`Core/` 目录全量源码中 `FireDAC` 单元引用数为 **0**。

### 2.2 会话快照存储位置取舍（Persistence SQLite vs 本地 JSON 文件）
- **评估**:
  1. **方案 A（散落 JSON 文件）**: 每个 Surface/Control 在本地生成独立的 `.json` 文件。缺点是并发控制复杂、文件碎片多、超龄清理（7天 TTL）需遍历文件树、易受文件系统锁冲突影响。
  2. **方案 B（集中 SQLite `hb_snapshots` 表）**: 复用已建立的 SQLite WAL 连接，以 `(surface_id, control_id)` 为复合主键存储 JSON Payload 与 `captured_at_utc` 时间戳。
- **裁决**: 采纳 **方案 B（集中 SQLite 表）**。
  - **单事务高吞吐**: 与遥测 evidence 共享同一 WAL 连接，零额外连接开销；
  - **事务一致性**: `INSERT OR REPLACE` 保证原子性覆盖更新；
  - **极简治理**: 单条 `DELETE FROM hb_snapshots WHERE captured_at_utc < :cutoff` 即可在毫秒级完成 7 天超龄快照自动 purge。

### 2.3 零 PII 与 Best-Effort 语义约束
- **零 PII 纪律**: `hb_evidence` 表仅存储结构化系统字段（`touchpoint_id`, `surface_id`, `timestamp_utc`, `dwell_time_ms`, `success`, `before_state`, `after_state`, `action_type`, `exit_position`, `error_code`, `support_deflected`），字段本身从源头阻断自由文本输入与 PII 泄漏面。
- **Best-effort 承诺**: 严格对齐 `docs/30.touchpoint.md` 规范措辞，覆盖正常退出、50% 水位崩溃防护与定时落盘，明示不承诺突发断电未落盘窗口。

---

## 3. 门禁验证证据 (Gate Evidence)

### 3.1 Win64 Package 构建门禁
- **构建命令**: `Scripts/build_packages_win64.ps1 -Profile All`
- **构建输出**: `TestResults/WO-20260904-004/build-packages.log`
- **构建结果**: **0 Error, 0 Fatal** (Exit Code: 0)。
  - `DeepBaseCore.dpk`: 59,690 lines (2.92s)
  - `DeepBasePersistence.dpk`: 63,004 lines (3.33s)
  - `DeepBaseVCL.dpk`: 5,024 lines (1.38s)
  - `DeepBaseFMX.dpk`: 669 lines (1.36s)
  - `DeepBasePlatform.dpk` / `DeepBaseServices.dpk` / `DeepBaseCommerce.dpk` / `DeepBaseSpeechCore.dpk` / `DeepBaseLLM.dpk` / `DeepBaseBrowser.dpk` / `DeepBaseInference.dpk` / `DeepBaseFeatures.dpk` 全量通过。

### 3.2 自动化测试门禁
- **执行命令**: `Scripts/run_tests.ps1 -Type Unit -Run "Test.DeepBase.HB" -OutputDir "TestResults/WO-20260904-004" -CI -AllowFilteredCI`
- **测试结果统计**:
  - Tests Found: **89**
  - Tests Passed: **89 (100%)**
  - Tests Failed: **0**
  - Tests Errored: **0**
  - Memory Leaks: **0**
- **证据文件**:
  - `TestResults/WO-20260904-004/UnitTestResults.xml` (JUnit 格式)
  - `TestResults/WO-20260904-004/test_hb_unit.log`
  - `TestResults/WO-20260904-004/test_hb_ci.log`

### 3.3 Gate #7 触点证据写入延迟压测 (Latency Benchmark)
- **压测规模**: 100,000 次触点交互，100 次批量落盘。
- **性能实测数据**:
  - 平均单次耗时: **0.0017 ms (1.70 μs)**
  - Latency P50: **0.0020 ms**
  - Latency P90: **0.0035 ms**
  - Latency P95: **0.0040 ms** (远优于门禁红线 `<= 2.0 ms`，裕量 > 500x)
  - Latency P99: **0.0086 ms**
  - Latency Max: **0.1054 ms**

### 3.4 真实环境崩溃与恢复链路验证 (Real-world Crash & Recovery)
- **测试场景**: 用户向导填写半程（Step 3/5, cluster=prod-asia-east-01, replica_count=8）→ 模拟非正常进程终止 → 全新进程重启 → 检测快照并自动恢复。
- **实测结果**:
  - 步骤索引与已填字段 100% 恢复；
  - 界面温和提示文案渲染: `"已为您恢复上次推演进度"`；
  - 任务确认完成后快照正常删除，再次重开不再触发恢复。

---

## 4. 生产部署状态 (Production Deployment Status)

依据持续交付纪律与非睿智轻量门禁 G1–G5，对流水线时间链与执行顺序进行严格审计：

1. **契约冻结阶段**:
   - `docs/ui/work-orders/WO-20260904-004-brief.md` 创建并锁定。
2. **构建阶段**:
   - `build-packages.log` 归档时间: `2026-09-04 17:04:48` (Exit Code 0)。
3. **测试阶段**:
   - `test_hb_unit.log` / `UnitTestResults.xml` 归档时间: `2026-09-04 17:09:19` (89/89 Tests Passed, P95=0.0040ms)。
4. **提交阶段**:
   - 精确暂存与 Git commit。
5. **顺序审计**: 契约 (先) → 构建 (17:04:48) → 测试 (17:09:19) → 提交 (后)，时间链严格单调递增，**流水线完整合规**。

---

## 5. 精确暂存文件清单 (Exact Staging Manifest)

1. `docs/ui/work-orders/WO-20260904-004-brief.md` (本地契约 Brief)
2. `Core/DeepBase.HB.Touchpoint.Types.pas` (`IHbTelemetrySink` 与 `IHbSnapshotProvider` 接口定义)
3. `Core/DeepBase.HB.Touchpoint.Engine.pas` (持久化槽注入、容量水位/定时落盘与析构 flush)
4. `Persistence/DeepBase.Persistence.HBTelemetry.FireDAC.pas` (SQLite WAL 遥测持久化驱动与快照存储引擎)
5. `DeepBasePersistence.dpk` (Persistence 包单元注册)
6. `VCL/DeepBase.VCL.HB.Dialogs.pas` (`THbDialogWizardSession` 快照适配与恢复文案)
7. `VCL/DeepBase.VCL.HB.Waterfall.pas` (`THbFacetWaterfall` 快照适配与恢复文案)
8. `Tests/Test.DeepBase.HB.Persistence.pas` (持久化与快照完整测试套件)
9. `Tests/DeepBaseTests.dpr` (测试工程单元注册)
10. `TestResults/WO-20260904-004/` (包含 `build-packages.log`、`UnitTestResults.xml`、`test_hb_unit.log`、`test_hb_ci.log`)
11. `CodeReview/20260904-HB-PERSIST-SNAPSHOT-交付报告.md` (本交付报告)

---

## 6. 技术债务与遗留项声明

- **本工单新增债务**: **0 项**（全部代码符合单一真相源，Core 层零重依赖，测试全绿，P95 达标）。
- **后续工单计划**:
  - `THbVoiceDialog` 快照适配与恢复（纳入后续语音基础设施专项工单）；
  - FMX 端会话快照适配（纳入 FMX 移动端适配工单）。
