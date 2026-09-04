# 工单 WO-20260904-001 · HB 运行时契约与触点引擎代码实施（罗辑）

> **指派对象**：罗辑（software-tools 人格 / 主编码代理）
> **工单性质**：规范落地开发（文档已定稿为最优设计，代码从零实施行为层）
> **基线**：Delphi 13.1 (Athens) · Win64 · dcc64 = `D:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe`
> **规范依据**（接口签名以规范为冻结标准，代码不得偏离）：
> - `D:\_Progs\02Business\DeepBase\docs\29.ui-runtime.md`（v2.0 · 7 步生命周期 / 两轴状态 + 状态槽 / Paint 前置断言）
> - `D:\_Progs\02Business\DeepBase\docs\30.touchpoint.md`（v2.0 · IHbTouchpoint 契约 / 三级分级采样 / Grid 聚合）
> - `D:\_Progs\02Business\DeepBase\docs\31.hb-test.md`（v1.1 · 第 7 项门禁：证据写入延迟 P95 ≤ 2ms）

---

## 任务 A · Core 契约单元（G0 契约存在）

### A1 新建 `D:\_Progs\02Business\DeepBase\Core\DeepBase.HB.Touchpoint.Types.pas`
以 30.touchpoint v2.0 第 1.3 节为冻结标准，一字不改地实现：
- `THbTouchpointLevel = (tlCritical, tlStandard)`
- `TTouchEvidence` record（11 字段：TouchpointId/SurfaceId/TimestampUtc/DwellTimeMs/Success/BeforeState/AfterState/ActionType/ExitPosition/ErrorCode/SupportDeflected）
- `TMetricDefinition` record（MetricKey/BaseValue/TargetValue/AchievedValue）
- `IHbTouchpoint` interface（GUID `{8F9B6E12-4C3D-4E5F-8A9B-1C2D3E4F5A6B}`，9 方法含 GetLevel）

### A2 新建 `D:\_Progs\02Business\DeepBase\Core\DeepBase.HB.StateSlot.Types.pas`
以 29.ui-runtime v2.0 第 3.1 节为冻结标准：
- `IHbStateSlotProvider` interface（GUID `{A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D}`，GetSlotId/GetStateLabel/GetStateRank）
- **红线**：本单元及一切 Core 单元严禁出现任何业务枚举（bsNeedFollowUp/bsHighValue 等只允许出现在测试的 mock 实现里）

### A3 状态槽注册机制（挂入 `D:\_Progs\02Business\DeepBase\Core\DeepBase.HB.Core.pas` 或新建 `Core\DeepBase.HB.Runtime.pas`，按现有架构最佳位置定）
- `THbRuntime.RegisterStateSlot(const AWorkOrder: string; ASlot: IHbStateSlotProvider)`：显式注册 + 工单号审计（风格对齐 `THbTheme.RegisterOverride`）
- 注册记录可枚举（供测试断言审计链）；重复 SlotId 注册：后注册覆盖并记审计，不抛异常

### A4 触点登记与分级采样引擎（新建 `D:\_Progs\02Business\DeepBase\Core\DeepBase.HB.Touchpoint.Engine.pas`）
- `THbTouchpointRegistry`：控件运行时登记触点（ID/Level/SurfaceId），线程安全（主线程约定 + 锁保护登记表）
- **分级采集策略**（30.touchpoint v2.0 第 2 节）：
  - tlCritical → 全量证据（完整 TTouchEvidence 11 字段）
  - tlStandard → 轻量证据（仅 TouchpointId + ActionType + TimestampUtc 三字段有效，其余零值）
  - 未登记元素 → 零开销（引擎不得为非触点保留任何对象）
- **Grid 聚合采样**：提供聚合上报 API（每 N 次同类行交互合并为一条聚合证据，N 可配置默认 50）；`THbDataGrid` 场景下引擎整体作为一个容器级触点 `tp_datagrid`，单元格/行不得独立登记
- **证据环形缓冲**：复用 `D:\_Progs\02Business\DeepBase\Core\DeepBase.Memory.pas` 现有 `TRingBuffer<T>`，容量 10000；**本工单不做 SQLite 持久化**（后续工单），缓冲满时按环形语义覆盖最旧

---

## 任务 B · VCL 基类生命周期管线（G1 事件可运行）

### B1 `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Controls.pas` · `THbCustomControl` 改造
- 引入生命周期阶段状态机：`lpCreated → lpTokenBound → lpStateBound → lpTouchpointAttached → lpRendered`（+ lpDisposed）
- 模板方法管线：`BindToken`（构造尾部自动完成，因现有 GetTokens 为拉模式）→ `BindState`（两轴基础态初始化）→ `AttachTouchpoint`（可选，默认无触点）→ Render（现有 Paint 路径）→ `EmitTelemetry`（有触点时经引擎记录）
- **Paint 前置断言**：`Paint` 入口检查 `F LifecyclePhase >= lpTokenBound`，未达即 `raise EHbLifecycleViolation`（异常类新建于 Core，含控件类名与当前阶段信息）
  - **兼容性硬约束**：现有 75 个控件全部直接 override Paint 且构造即取 Token——默认路径必须自动满足断言，全量存量测试保持绿，零误伤
- **失败路径**：管线任一步骤异常 → 触发 `OnLifecycleError(Sender, AStep, AException)` → 无条件进入清理
- **Dispose 幂等**：`DoDispose` 可重入（Freed 标志守卫），重复调用无副作用无二次异常
- 现有子类控件（THbButton 等）**不改一行**即可通过基类获得生命周期；只有需要触点能力的控件后续显式调用 `AttachTouchpoint`

### B2 触点挂载试点（垂直切片，证明引擎闭环）
- 在 `THbButton` 上实现首个触点试点：Click 事件经引擎产生一条 tlStandard 轻量证据
- 在 `THbDialog` 的确认按钮上实现 tlCritical 全量证据试点（Before/After 状态文本由 Dialog 传入）
- 试点仅为验证管线，不做业务语义

---

## 任务 C · 测试与基准（G1 证据）

### C1 新建 `D:\_Progs\02Business\DeepBase\Tests\Test.DeepBase.HB.Touchpoint.pas`
- 契约测试：IHbTouchpoint 9 方法、TTouchEvidence 11 字段、GetLevel 分级
- 引擎测试：登记/查询/分级采集策略（Critical 全量 vs Standard 轻量字段断言）
- 聚合测试：模拟 10 万次行交互走聚合 API，断言产生 ≤ ⌈100000/N⌉ 条聚合证据
- 状态槽测试：RegisterStateSlot 注册/覆盖/审计链断言（mock 实现放测试内）
- **反污染测试**：断言 `Core\DeepBase.HB.*.pas` 源文件中不出现 `bsNeedFollowUp`/`bsHighValue`/`tsMedium` 等业务标识（读源文件文本扫描，守护层级纪律）

### C2 新建 `D:\_Progs\02Business\DeepBase\Tests\Test.DeepBase.HB.Lifecycle.pas`
- 7 步顺序测试：阶段状态机按序推进
- **断言测试**：构造绕过 BindToken 的场景（如测试专用子类拦截）→ 断言 `EHbLifecycleViolation` 真实抛出
- Dispose 幂等测试：连续调用 3 次无异常
- 失败路径测试：BindState 阶段注入异常 → OnLifecycleError 触发 + 清理完成
- 试点触点测试：THbButton 点击产生轻量证据、THbDialog 确认产生全量证据（mock 引擎 sink 断言字段）

### C3 新建 `D:\_Progs\02Business\DeepBase\Tests\Test.DeepBase.HB.Benchmark.pas`（31.hb-test v1.1 第 7 项门禁落地）
- 10 万行场景：向引擎以聚合模式写入 10 万次行交互证据，测量单次聚合写入延迟 P95 ≤ 2ms
- 基准数字写入 junit XML / 测试输出，禁止口头报数

---

## 明确不在本工单范围（防止范围蔓延）
- SQLite/WAL 持久化与会话快照恢复（30.touchpoint v2.0 第 6/7 节 → 后续工单）
- FMX 端生命周期迁移（`D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Controls.pas` → 后续工单）
- 31.hb-test 第 1–6 项视觉性能门禁基准测试（后续工单）
- 下游产品（唤金等）状态槽实际注册（由各产品线自行实施）

---

## 验收准则（全部满足才可交付，非睿智轻量门禁）
1. **契约 brief 先行**：开发启动时先落 `D:\_Progs\02Business\DeepBase\docs\ui\work-orders\WO-20260904-001-brief.md`（目标/范围/验收标准/digest，不超过 60 行）
2. **编译门禁**：DeepBaseCore.dpk / DeepBaseVCL.dpk / DeepBaseFMX.dpk 三包 dcc64 编译 **0 Error / 0 Warning / 0 Leaked DCU**，原始编译输出存档至 `D:\_Progs\02Business\DeepBase\TestResults\WO-20260904-001\build-*.log`
3. **存量回归全绿**（零误伤证明）：
   ```powershell
   powershell -ExecutionPolicy Bypass -File D:\_Progs\02Business\DeepBase\Scripts\run_tests.ps1 -Type Unit -Run "Test.DeepBase.HB"
   ```
   junit XML 存档至 `D:\_Progs\02Business\DeepBase\TestResults\WO-20260904-001\`，以 XML 实际数字为准
4. **新增测试全绿**：C1/C2/C3 三个测试单元全部通过（含 Paint 断言真实抛出、Dispose 幂等、聚合证据条数、P95 ≤ 2ms 实测数字）
5. **反污染扫描通过**：C1 源文本扫描断言通过（Core 契约单元零业务枚举）
6. **主控复核**：交付后由主控（Amy）+ 异族模型独立 review 代码与证据文件；复核不通过不 CLOSE
7. **交付报告**写入 `D:\_Progs\02Business\DeepBase\CodeReview\20260904-HB-RUNTIME-TOUCHPOINT-交付报告.md`，必含：逐任务完成状态、编译/测试进程时间戳（生产部署状态章节）、基准实测数字、遗留债务清单（有未清债务禁止宣告 CLOSE）
8. **Git**：允许本地精确 commit（引用 WO-20260904-001），不允许 push/发布；每次 commit 保证三包可编译
