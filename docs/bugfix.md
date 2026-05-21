# DeepBase Governance 接入轮 — Bug 修复记录

> 本文件记录 2026-05-11 起 Governance 接入期间发现并修复的问题。
> 活跃任务请看 `tasks.md`，已完成任务请看 `history.md`。

---

## BUG-001 盘古误判 Governance 类型不存在（误删代码）

- **严重度**：中（影响框架能力评估准确性）
- **现象**：盘古最初版本的 `Lifecycle.pas` / `Registration.pas` 引用了
  - `TObserveGateResolver`
  - `TConfigRegistrar`
  - `TEvidenceRecorder`
  - `IEvidenceStore` / `TEvidenceStoreSQLite`
  - `TGovernanceConfigSetupProc`
  编译报"找不到"，盘古误判为"自动化机制扩展出的幻觉类型"，主动降级为最小可编译版本
- **根因**：盘古没有先在 `02Business/DeepBase/Governance/` 目录里核实，直接以编译报错为准。这些类型**全部真实存在**：
  - `DeepBase.Governance.ObserveGateResolver.pas`
  - `DeepBase.Governance.ConfigRegistrar.pas`
  - `DeepBase.Governance.EvidenceRecorder.pas`
  - `DeepBase.Governance.EvidenceStore.SQLite.pas`
  - `TGovernanceConfigSetupProc` 定义在 `Lifecycle.pas` 中
  当时编译失败大概率是**搜索路径没覆盖到这些新增文件**，不是类型不存在
- **修复**：
  - Lifecycle.pas 还原为完整版本（ConfigDB 持久化 + ObserveGateResolver 装饰 + Evidence 写 SQLite）
  - Registration.pas 还原两个重载（legacy in-memory / ConfigDB-backed）+ `GovernanceRegistrar` 访问器
- **预防**：在主张"类型不存在"前先用 `fileSearch` / `listDirectory` 核实目录，不要以编译报错为唯一依据
- **状态**：已修复，两文件均在 Phase 0.1 / 0.2 验证通过

---

## BUG-002 违反 DeepBase 配置铁律（创建外部 JSON 配置）

- **严重度**：高（违反 DeepBase 基础约定）
- **现象**：盘古最初给每个接入项目都创建了 `config/governance/gates.json` / `actions.json` / `purposes.json`
- **根因**：盘古没有首先确认 DeepBase 配置铁律（**唯一外部配置文件 = `root.txt`**，其余入 DB1 ConfigDB）
- **修复**：
  - 删除所有已创建的 `config/governance/*.json`
  - `tasks.md` Phase 1.2 / 2.2 / 3.2 等"创建 config 目录"条目全部划掉并标注"已废弃"
  - 改为代码回调注册（`TGovernanceSetupProc` / `TGovernanceConfigSetupProc`）
  - 新增文档 `52.extend.Governance代码注册示例-governance-setup-via-code.md`
  - `00.quickstart.AI集成总览-ai-one-file.md` 首页加配置铁律警告
- **预防**：任何下游项目接入前先过 `00.quickstart.AI集成总览-ai-one-file.md` 配置铁律章节
- **状态**：已修复，全团队对齐

---

## BUG-003 DeepFlow 被误放进 DeepBase/docs 子目录

- **严重度**：低（文档组织问题）
- **现象**：`DeepBase/docs/DeepFlow/` 把独立 AI 开发方法论混入基础框架文档
- **根因**：早期目录整理阶段未区分"DeepBase 文档"与"独立方法论"
- **修复**：`DeepFlow/` 移出到 `02Business/DeepFlow/` 独立目录
- **状态**：已修复

---

## 待确认（待运行时验证）

以下情况在运行时验证之前不能确认是否存在问题：

- `.kiro/steering/governance-model.md` 是否真的被 SteeringExporter 写入（`Lifecycle.Start` 最后一步，try/except 吞错误）
- observe 模式下 Evidence 是否真的写进 DB1 `governance_evidence_*` 表
- enforce 模式切换后 `TObserveGateResolver` 是否真的从"只记录"切到"真拦截"
- `DeepBaseGovernance.dpk` 在完整包链中独立编译是否通过（目前只通过 DeepClip 间接编译）


## BUG-004 ObserveGateResolver 覆盖 State 时不还原 AvailableActions（框架 bug）

- **严重度**：高（observe 模式的条件失败 action 会被报"No action resolved"而非成功放行）
- **发现路径**：DeepClip Governance Smoke Test Phase 3 — Test 2（`record_id=""` 的 delete_gate）
- **现象**：
  - 内部 GateResolver 评估条件失败，返回 `State=gsBlocked`, `AvailableActions=nil`（因为 GateResolver 只在 `gsOpen` 时才填充 ActionKeys）
  - ObserveGateResolver 装饰器把 State 覆盖为 gsOpen 并清空 BlockedReason，但**没有恢复 AvailableActions**
  - Runtime.EnterGate 拿到 State=gsOpen 但 `Length(AvailableActions)=0`，报错 `No action resolved for gate: xxx`
  - 结果：observe 模式下条件失败的 action 会被错误地标记为 Fail 而非 Success
- **根因**：`TGateResolver.Resolve` 只在 `gsOpen` 时填充 AvailableActions，违反了"数据产出应与状态解释分离"的设计原则
- **修复**：`DeepBase.Governance.GateResolver.pas` 第 124 行 — 无论 State 如何都填充 AvailableActions
  ```delphi
  // 旧代码（错误）：
  if Result.State = gsOpen then
    Result.AvailableActions := LGate.ActionKeys.ToArray
  else
    Result.AvailableActions := nil;

  // 新代码（正确）：
  Result.AvailableActions := LGate.ActionKeys.ToArray;
  ```
  调用方（Runtime.EnterGate）已经在路由前判断 State，不依赖 AvailableActions=nil 作为阻断信号
- **测试覆盖**：DeepClipGovernanceSmoke 的 Phase 3 Test 2，`record_id=""` 触发 state 条件失败，验证 observe 覆盖后 Runtime 能正确路由到 action
- **状态**：已修复并验证

---

## BUG-005 两套支付类型系统同名不同构（P1 — 设计债）

- **严重度**：中（未来集成支付网关时易引发序列化/反序列化不一致）
- **发现路径**：DeepBase 认证+支付模块审查
- **现象**：
  - `DeepBase.Payment.pas` 定义了 `TPaymentProvider`、`TPaymentStatus`、`TPaymentResult`、`EPaymentError` 等类型
  - `DeepBase.Payment.Types.pas` 定义了**同名但结构不同**的 `TPaymentProvider`、`TPaymentStatus`、`TPaymentResult`、`EPaymentError`
  - 两套枚举值**值域不完全一致**（Payment.pas 有 `ppNone`、`psIdle` 等，Types.pas 没有）
  - 如果某单元同时 `uses` 两个文件，最后一个 `uses` 的会遮盖前一个（Delphi 名称解析规则）
- **根因**：Types.pas + Core.pas 是早期设计草图，未被任何 `.dpr` 或 `.pas` 引用（死代码），未与 Payment.pas 统一
- **影响范围**：当前无实际影响（死代码），但未来激活 Payment 网关时如果引用了错误的类型，会导致 subtle bug
- **修复策略**（P1 — 不阻塞交付）：
  - 在 `DeepBase.Payment.Types.pas` 头部加了 WARNING 注释，标注所有重复类型及与 `DeepBase.Payment.pas` 的差异
  - 在 `DeepBase.Payment.Core.pas` 头部加了 WARNING 注释，说明使用前需先统一类型系统
  - 不做破坏性重构（避免引入新的编译错误）
- **后续建议**：
  - 激活 Payment 网关前，决定保留哪套类型作为唯一源，删除另一套
  - 或将 Types.pas 的类型改为 `TXxx`（加前缀）避免命名冲突
- **状态**：WARNING 注释已加，设计债已记录，待后续 Payment 激活时处理

---

## Phase 1.8/1.10 运行时验证（DeepClip 纯 Governance 层）

通过 `tests/GovernanceSmoke/DeepClipGovernanceSmoke.dpr`（控制台最小 harness）验证：

| 项 | 结果 |
|----|------|
| Lifecycle.Initialize + Start | ✅ |
| `.kiro/steering/governance-model.md` 导出 | ✅ 819 bytes |
| Runtime.EnterGate（条件满足） | ✅ arsSuccess |
| Runtime.EnterGate（条件失败，observe 覆盖） | ✅ arsSuccess + Evidence 记录 |
| ShutdownGovernance 幂等 | ✅ |

注意：该 harness 走 **legacy in-memory 路径**（`RegisterGovernance(gmObserve, TGovernanceSetupProc)`），不依赖 ConfigDB。完整 ConfigDB 持久化路径（Phase 1.8 的 Evidence 写 DB1）尚未验证，需 DeepClip 主程序在一个可建 ConfigDB 的环境下跑起来才能测。
