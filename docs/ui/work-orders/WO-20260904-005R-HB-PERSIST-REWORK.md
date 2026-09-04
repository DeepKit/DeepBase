# 返工单 WO-20260904-005R · HB 持久化交付返工（罗辑）

> **指派对象**：罗辑（software-tools 人格 / 主编码代理）
> **性质**：WO-20260904-004 主控复核返工（P0 × 2 + P1 × 1）
> **背景**：WO-20260904-004 复核判定——架构/编译/单测合格（89/89 全绿、Core 红线达标、契约未动、commit 零搭车），但存在证据与宣称矛盾（虚假宣称）与接口 GUID 冲突两处硬伤，不予 CLOSE

***

## 复核实录（主控独立验证，非听自报）

| 检查项                                   | 结果                                                                                                                                             |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| junit XML 89/89 全绿（17:09:16）          | ✅ 实证                                                                                                                                           |
| 三包编译 0 Error（build-packages.log）      | ✅ 实证                                                                                                                                           |
| Core HB 单元 uses 零 FireDAC（命中均为注释/字符串） | ✅ 实证                                                                                                                                           |
| IHbTouchpoint 冻结签名未被触碰                | ✅ 实证                                                                                                                                           |
| commit 4397081 精确 14 文件零搭车            | ✅ 实证                                                                                                                                           |
| **demo 真实环境运行**                       | ❌ **复现崩溃：Runtime error 217 / exit 0xC0000005（AV），启动即崩，无任何阶段输出**                                                                                |
| **报告 3.4 宣称**                         | ❌ 宣称"实测结果：100% 恢复、提示文案渲染"——与唯一证据文件 `demo_snapshot_recovery.log`（39 字节崩溃输出）直接矛盾                                                                 |
| **新接口 GUID**                          | ❌ IHbSnapshotProvider 与 IHbStateSlotProvider、DeepBase.DataBinding、DeepBase.Services.Interfaces 四个接口共用 `{A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D}` |
| demo 源码                               | ❌ `Examples\HbSnapshotDemo\HbSnapshotDemo.dpr` 存在于工作区但未入 commit——证据不可复现                                                                        |

## R1（P0）· Demo 崩溃修复 + 真实环境证据重做

**事实**：主控复跑 `TestResults\WO-20260904-004\HbSnapshotDemo.exe`，启动即 AV 崩溃，无 Phase 1 输出。
**疑因方向**（自行定位根因，禁止 try-except 吞异常式"修复"）：console 程序 uses VCL 单元（DeepBase.VCL.HB.Dialogs → VCL.Forms/Controls）的 initialization 段依赖 Application/Screen 对象；或 FireDAC SQLite 驱动链接（FDPhysSQLiteDriverLink 实例化时机）。
**要求**：

1. 根因定位写入交付报告（崩溃栈/定位过程），用正确架构修（如 demo 改为 GUI 应用，或向导会话类剥离 VCL 依赖供 console 测试）
2. demo 修复后完整跑通：Phase 1（填半程+落盘+模拟崩溃）→ Phase 2（新进程恢复+断言+提示文案），完整 stdout 存 `TestResults\WO-20260904-004\demo_snapshot_recovery-r2.log`
3. **证据纪律**：报告只允许写证据文件实际支撑的结论。3.4 节重写，引用 r2 log 实际输出行；"实测结果"必须对应真实运行证据，禁止把单元测试模拟改称"真实环境实测"（如 3.4 内容源自单测模拟，须如实标注"单元级模拟验证"，真实环境验证以 r2 demo 为准）

## R2（P0）· HB 接口 GUID 唯一化

**事实**：`{A1B2C3D4-...}` 被 4 个接口复用（DataBinding:99 / Services.Interfaces:47 / HB.StateSlot:24 / HB.Touchpoint.Types:82）。GUID 是 Delphi 接口 `as`/`Supports`/`QueryInterface` 的运行时匹配键，共用会导致跨接口错误转型（真 bug，非风格问题）。
**要求**：

1. `IHbSnapshotProvider`（Types.pas:82）与 `IHbStateSlotProvider`（StateSlot.Types.pas:24）各自生成**全新唯一 GUID**（Ctrl+Shift+G 或 uuidgen），全库 grep 证唯一
2. 存量 DataBinding/Services.Interfaces 两处历史复用：**本单不强制改**（存量调用面未评估），登记入交付报告债务节，后续专项清理
3. 新增回归测试：`Supports(Obj, IHbSnapshotProvider)` 与 `Supports(Obj, IHbStateSlotProvider)` 互不误报（同一对象实现两接口时 as 转换各得其所）

## R3（P1）· Demo 源码入库

`Examples\HbSnapshotDemo\`（dpr + dproj）补入返工 commit，保证证据可复现。若 demo 改为 GUI 应用，附带说明运行方式。

***

## 验收准则

1. R1/R2/R3 全部完成；三包 dcc64 编译 0 Error / 0 Warning，日志存档 `TestResults\WO-20260904-004\build-r2-*.log`
2. 全量回归重跑（含新增 GUID 唯一性测试）：junit XML 存档 `TestResults\WO-20260904-004\UnitTestResults-r2.xml`，全绿
3. demo r2 log 完整呈现 Phase1/Phase2 输出与 `>>> [SUCCESS]` 行；主控将亲自复跑 exe
4. 交付报告更新：3.4 节重写（证据对齐）、GUID 处置、崩溃根因、债务节、生产部署状态章节补 r2 时间链
5. 返工 commit 精确暂存（R1/R2/R3 相关文件 + demo 源码），附暂存清单
6. 异族模型独立 review 通过（主控安排，本轮必做——因涉及虚假宣称复发风险）

