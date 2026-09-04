# 返工单 WO-20260904-002R · HB 触点契约回归冻结签名（罗辑）

> **指派对象**：罗辑（software-tools 人格 / 主编码代理）
> **性质**：WO-20260904-001 主控复核返工（3 项，2 项必改 1 项登记）
> **冻结标准**：`D:\_Progs\02Business\DeepBase\docs\30.touchpoint.md` v2.0 第 1.3 节（一字不改）
> **背景**：WO-20260904-001 复核判定——测试/编译/生命周期管线合格，但 `IHbTouchpoint` 实现偏离冻结契约，形成规范-代码双真相

---

## R1（P0 · 必改）· `IHbTouchpoint` 回归规范冻结签名

`D:\_Progs\02Business\DeepBase\Core\DeepBase.HB.Touchpoint.Types.pas` 当前实现与规范 30.touchpoint v2.0 第 1.3 节对照：

| 项 | 规范冻结签名 | 当前实现（偏离） |
|---|---|---|
| 方法1 | `function GetID: string;` | `GetTouchpointId`（改名+新增 GetSurfaceId） |
| 方法2 | `function GetLevel: THbTouchpointLevel;` | ✅ 一致 |
| 方法3 | `function GetBeforeState: string;` | ❌ 被删 |
| 方法4 | `function GetAction: string;` | ❌ 被删 |
| 方法5 | `function GetAfterState: string;` | ❌ 被 GetTargetState 替代 |
| 方法6 | `function GetMeasure: TMetricDefinition;` | ❌ 被 GetMetricDefinitions: TArray<T> 替代 |
| 方法7 | `function EmitEvidence: TTouchEvidence;` | ❌ 变为 `EmitEvidence(const AEvidence): Boolean`（拉→推，语义反转） |
| 方法8 | `procedure ExecuteNextAction;` | ❌ 被删 |
| 方法9 | `procedure ExecuteFallbackAction;` | ❌ 被 ValidateZeroSupportClosure/EvaluateHealth/TransformState 替代 |
| 字段 | `DwellTimeMs: Cardinal` | ❌ Integer |
| 字段 | `ErrorCode: Integer` | ❌ string |

**修正要求**：
1. `IHbTouchpoint` 恢复规范 9 方法精确签名；`TTouchEvidence` 11 字段名与类型全部对齐规范（DwellTimeMs: Cardinal、ErrorCode: Integer）
2. 同步修正引用方：`Core\DeepBase.HB.Touchpoint.Engine.pas`、`VCL\DeepBase.VCL.HB.Controls.pas`（试点）、`VCL\DeepBase.VCL.HB.Dialogs.pas`（试点）、`Tests\Test.DeepBase.HB.Touchpoint.pas`、`Tests\Test.DeepBase.HB.Lifecycle.pas`
3. 试点语义对齐：THbButton（tlStandard 轻量）/ THbDialog 确认（tlCritical 全量）在交互时**调用触点的 EmitEvidence 产出 TTouchEvidence**，交引擎按分级策略入缓冲
4. 实现版新增方法（TransformState/ValidateZeroSupportClosure/EvaluateHealth/GetMetricDefinitions）若认为有价值：**不得留在 IHbTouchpoint**。可下沉为引擎层独立类型（如 THbTouchpointHealthEvaluator）或另提规范修订，二选一并在交付报告注明去向
5. 规范版 `GetMeasure: TMetricDefinition` 为单记录返回；多指标场景属于下游扩展，不在冻结接口内

## R2（P0 · 必改）· 交付报告补「生产部署状态」章节

`D:\_Progs\02Business\DeepBase\CodeReview\20260904-HB-RUNTIME-TOUCHPOINT-交付报告.md` 缺该章节（硬纪律：缺失即 FAIL）。补记：
- 构建进程：`build_packages_win64.log` 完成时间 2026-09-04 15:19:05
- 测试进程：`UnitTestResults.xml` 生成时间 2026-09-04 15:21:34
- Git commit：99ec1e7 @ 2026-09-04 15:22:04 +0800
- 顺序结论：构建 → 测试 → 提交，链路合规
- 返工轮次的时间链按新证据文件补记

## R3（P1 · 登记不返工）· commit 范围失控教训

99ec1e7（49 文件 +8839 行）混入 8/30–8/31 积压未提交文件约 20 个（Choice/Choice.Demo/Inputs/Text/Glass/Status/Grid/Waterfall/Suite 等，属既往审计修复产物，非本工单改动）。已定性：积压搭车，非私改。不要求拆分已提交历史；处置：
1. 交付报告债务节登记此事（影响：本工单 commit 不可独立回滚）
2. 返工 commit 必须**精确**：只暂存 R1/R2 涉及文件，commit 前 `git status` 核对暂存清单并在交付报告附上
3. 积压文件的质量责任归属既往工单，随存量回归测试覆盖（65 全绿已含），不另行返工

---

## 验收准则
1. `Core\DeepBase.HB.Touchpoint.Types.pas` 与 30.touchpoint v2.0 第 1.3 节逐行一致（主控将做规范文本 vs 源码的机械比对）
2. 三包 dcc64 编译 0 Error / 0 Warning；原始输出存档 `TestResults\WO-20260904-001\build-r2-*.log`
3. 全量回归重跑：`Scripts\run_tests.ps1 -Type Unit -Run "Test.DeepBase.HB"`，junit XML 存档 `TestResults\WO-20260904-001\UnitTestResults-r2.xml`，全绿
4. 异族模型独立 review 通过（主控安排）
5. 交付报告更新：R1/R2/R3 处置结果 + 生产部署状态章节（含 r2 时间链）+ 精确 commit 哈希与暂存清单
6. 交付报告「未清债务」节如实更新（commit 混入影响 + 后续工单计划保留）
