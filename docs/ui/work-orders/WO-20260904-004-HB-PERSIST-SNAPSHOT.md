# 工单 WO-20260904-004 · HB 遥测持久化与会话快照恢复（罗辑）

> **指派对象**：罗辑（software-tools 人格 / 主编码代理）
> **工单性质**：行为层能力补全（30.touchpoint v2.0 §6/§7 从规范到代码）
> **基线**：Delphi 13.1 (Athens) · Win64 · dcc64 = `D:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe`
> **规范依据**（措辞为准，禁止过度承诺）：
> - `D:\_Progs\02Business\DeepBase\docs\30.touchpoint.md` v2.0 第 6 节（本地优先遥测：**best-effort 持久化，非零丢失**）
> - `D:\_Progs\02Business\DeepBase\docs\30.touchpoint.md` v2.0 第 7 节（会话快照恢复：覆盖误关窗/切出查阅/应用崩溃，**不含断电未落盘窗口**）
> **现状**：引擎内存环形缓冲（10000 容量）已落地（WO-20260904-001），退出即丢；快照恢复零代码

---

## 任务 A · 遥测持久化驱动（best-effort）

### A1 架构分层（红线：Core 不引重依赖）
- `Core\DeepBase.HB.Touchpoint.Engine.pas` 所在 Core 包**禁止**直接引用 FireDAC/SQLite 单元
- Core 定义持久化槽接口（风格对齐 IHbStateSlotProvider 显式注入）：
  ```pascal
  IHbTelemetrySink = interface
    procedure PersistEvidence(const AEvidence: TArray<TTouchEvidence>);  // 批量落盘
  end;
  ```
- 引擎暴露 `SetSink(ASink)`；未注入时行为与现状完全一致（内存缓冲）——**注入式，不破坏现有测试**

### A2 SQLite 驱动（FireDAC 复用，落在 Persistence 层）
- 新建 `Persistence\DeepBase.Persistence.HBTelemetry.FireDAC.pas`：实现 IHbTelemetrySink
- 复用项目现有 FireDAC 基础设施（`DeepBase.DB.Factory` / ConnectionPool），SQLite + **WAL 模式**
- 库文件位置：用户本地应用数据目录（`%LOCALAPPDATA%\<产品>\hbtelemetry.sqlite`，路径经现有配置机制，禁止写死仓库路径）
- 表结构：evidence 单表（字段对齐 TTouchEvidence 11 列 + 自增主键），附 PRAGMA 与索引最小集
- 触发时机（对齐规范 best-effort 措辞）：
  - 正常退出：全量 flush
  - 崩溃防护：缓冲水位达 50% 或距上次 flush 超 30s（低频后台，不占 UI 帧预算）
  - 断电窗口：明示不承诺（规范原文）
- 零 PII 纪律：只落结构化字段，无明文文本采集面（字段本身即合规）

## 任务 B · 会话快照恢复（Session Snapshot Recovery）

### B1 快照框架（Core，接口驱动）
- Core 定义快照契约：`IHbSnapshotProvider`（控件实现 Capture/Restore，快照体为 JSON 字符串，字段由控件自定义）
- 快照存储复用 A2 的 SQLite 连接（独立 snapshot 表：SurfaceId/ControlId/Payload/CapturedAt）或轻量 JSON 文件——按现有 Persistence 架构最佳位置定，交付报告注明取舍
- 恢复时机：容器再次实例化时查询快照 → 命中则恢复 + 温和提示（规范原文文案："已为您恢复上次推演进度"）
- 快照失效策略：任务确认完成后删除该 Surface 快照；保留期上限 7 天（防无限膨胀，规范 §4.3 数据治理红线）

### B2 试点容器（2 个，防范围蔓延）
- `VCL\DeepBase.VCL.HB.Dialogs.pas`（THbDialog）：步骤位置 + 已填字段值
- `VCL\DeepBase.VCL.HB.Waterfall.pas`（THbFacetWaterfall）：展开/折叠状态 + 已选分面
- THbVoiceDialog 不在本轮（后续工单）

## 任务 C · 测试

### C1 持久化测试（新建 `Tests\Test.DeepBase.HB.Persistence.pas`）
- Sink 注入后 flush 触发（退出/水位/定时三路径）
- WAL 模式断言；库文件创建位置断言
- Sink 未注入时引擎行为与现状一致（回归保护）
- 崩溃模拟：进程内模拟未 flush 场景，断言 best-effort 语义（已 flush 部分可读）

### C2 快照测试（并入 C1 或独立）
- THbDialog：填半程 → 销毁 → 重开 → 状态恢复 + 提示触发
- THbFacetWaterfall：折叠态 + 选择恢复
- 快照失效：完成后重开不恢复；超龄清理
- 崩溃恢复路径（模拟进程重启读库）

### C3 性能守护
- flush 与快照写不得阻塞 UI 帧：单次 PersistEvidence P95 ≤ 2ms（对齐 31.hb-test 第 7 项门禁精神，批量场景）

## 明确不在范围
- 遥测数据上报/回流服务端（Local-First，无外发）
- THbVoiceDialog 快照、FMX 端（后续工单）
- 四自指标计算/看板（度量口径在规范，计算属下游产品）

## 验收准则
1. 契约 brief 先行：`docs\ui\work-orders\WO-20260904-004-brief.md`
2. 三包 dcc64 编译 0 Error / 0 Warning（Core 引用链红线：Core 包 uses 中不得出现 FireDAC 单元，主控将机械核查），原始日志存档 `TestResults\WO-20260904-004\build-*.log`
3. 全量回归 + 新增测试全绿，junit XML 存档 `TestResults\WO-20260904-004\`（含 P95 数字）
4. 真实环境测试：跑 Demo 演示「填半程向导 → 杀进程 → 重开恢复」全链路，截图/日志存证
5. 异族模型独立 review（主控安排）通过
6. 交付报告 `CodeReview\20260904-HB-PERSIST-SNAPSHOT-交付报告.md`：生产部署状态章节（时间链）、架构取舍说明（快照存储位置）、遗留债务、精确 commit
