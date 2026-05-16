# DeepBase Governance (OCGS) 集成 — 待办任务清单

> 更新：2026-05-11
> 已完成任务 → `history.md`
> Bug 修复记录 → `bugfix.md`
> 活跃目标：把 Governance 板块从"框架就位"推进到"可交付"

---

## ⚠️ 配置铁律（最高优先级，所有人必须遵守）

DeepBase 唯一的外部配置文件是 `root.txt`。

**Governance 配置通过代码注册**（`TGovernanceSetupProc` / `TGovernanceConfigSetupProc` 回调），不在下游项目创建任何 JSON / INI / YAML / config 目录。

正确方式：
```delphi
RegisterGovernance(gmObserve, ConfigDB,
  procedure(ARegistrar: TConfigRegistrar;
            AGateRes: TGateResolver;
            ARuntime: TOCGSRuntime)
  begin
    ARegistrar.RegisterAction('app.delete', 'Delete', rlL3, 'app.delete_gate');
    ARegistrar.RegisterGate('app.delete_gate', 'Delete Gate', gtAction);
    ARegistrar.RegisterPurpose('app.manage', 'Management', '');
  end);
```

错误方式（会被打回）：创建任何 `config/governance/*.json`。

---

## 交付阻塞项（优先级最高）

必须全部 clear 才能宣称 Governance 板块可交付。

### Phase 1.6：DeepClip LegacyWrap 真实包装（盘古）

- [x] 1.6.1 在 `DeepClip.Repository.pas` 的 `DeleteClipItem` 入口调用 `GovernanceLifecycle.Runtime.EnterGate('clip.delete_gate', Ctx, rmCommit)`
  - Ctx 包含 `record_id` 字段（满足 delete_gate 的 state 条件）
  - observe 模式下：阻挡不生效，但 Evidence 会写
  - enforce 模式下：若条件不满足，直接返回 False 不删
- [ ] 1.6.2 `CleanupExpired` 接入（暂缓：系统后台操作，非用户 L3 行为）
- [x] 1.6.3 `compile.bat` 编译通过（26328 行，2.23s，SUCCESS）

### Phase 1.12：DeepClip Bootstrap 切 ConfigDB-backed + DueRule 收紧（盘古）

- [x] 1.12.1 Bootstrap 从 legacy 路径切到 `RegisterGovernance(gmObserve, ConfigDB, TGovernanceConfigSetupProc)`
- [x] 1.12.2 DueRule 按 GovernanceLifecycle.Mode 分级注册（observe=relaxed, enforce=L2 Evidence+Accountability / L3 +Confirm）
- [x] 1.12.3 JsonLogic evaluator + ActionGrid 双注册 + gate→actionKeys 手动关联保留
- [x] 1.12.4 Bootstrap 精简（InitializeOrRaise → InitializeDB2Connection → RegisterDeepClipGovernance）
- [x] 1.12.5 主编译通过（26499 行，1.77s，COMPILATION SUCCESS）

### Phase 1.8 / 1.9 / 1.10：DeepClip 运行时验证（盘古）

- [x] 1.8a 通过 `DeepClipGovernanceSmoke.exe` 验证 Governance 核心流程（steering 导出 + observe 覆盖 + EnterGate 路由）
- [x] 1.8b ConfigDB-backed 路径验证：governance_evidence 表自动创建 + EnterGate 在 ConfigDB 模式下正常工作
- [x] 1.8c Evidence 实际写入验证通过（rows after=1, action=clip.delete_gate, result=blocked, reason="Please select a record to delete"）— 根因是 EvidenceRecorder 异步线程，需 Flush 后再查
- [x] 1.9 **enforce 模式拦截验证通过**：record_id="" 时返回 `arsBlocked` + "Please select a record to delete"；record_id 非空时正常放行
- [x] 1.10 `.kiro/steering/governance-model.md` 自动导出验证通过（smoke harness）

### Phase 1.11：DeepClip Bootstrap 生产配置补齐（盘古新增）

Smoke test 暴露 Bootstrap 缺的 3 件事：

- [x] 1.11.1 在 `RegisterDeepClipGovernance` 回调里注册 JsonLogic condition evaluator（`gckState` / `gckPermission`），用 `DeepBase.Governance.JsonLogic.TJsonLogicEngine.ApplyStr`
- [x] 1.11.2 把 Actions 同时注册到 `ActionGrid`（`RegisterAction(key, name, level)`）— 修掉 "Action not found"
- [x] 1.11.3 为 L2/L3 actions 注册 observe-mode relaxed DueRule（`RequireEvidence/Accountability/Confirm/Seal` 全 False），修掉 "due.missing_policy" fail-closed
- [x] 1.11.4 主编译通过（COMPILATION SUCCESS）+ smoke 全通过（L3 action 走完完整链路）

### Phase 0.3：DeepBaseGovernance.dpk 独立编译验证（盘古）

- [x] 验证 `DeepBaseGovernance.dpk` 在完整包链（Core → Services → Persistence → Features → VCL / FMX → Governance）中独立构建通过（105940 行，7.34s，exit code 0）

---

## 同事进度待 Review（盘古）

### Phase 4 / 5 Review — 仙儿交付物

- [x] R4.1 Code review `DeepInsight` 的 `SeedInsightGovernance` 回调实现
  - 2 purpose + 2 L3 gate（含 gckPermission/gckEvidence/gckAccountability 条件）+ 2 action
  - 缺 evaluator 注册 + ActionGrid + DueRule + gate→actionKeys（observe 可用，enforce 需补齐）
- [ ] R4.2 运行 `DeepInsightApp.exe`，确认 observe 模式下 Evidence 写入 DB1
- [x] R5.1 Code review `DeepStory` 的 `SeedStoryGovernance` 回调与 LegacyWrap 桥接
  - 4 purpose + 3 gate（L2/L3，多条件）+ 3 action + 2 LegacyWrapBridge
  - LegacyWrap 设计正确（通过 GovernanceLifecycle.ActionGrid.RegisterBridge）
  - 同样缺 evaluator + ActionGrid 双注册 + DueRule + gate→actionKeys
- [ ] R5.2 运行 DeepStory 主程序，确认 observe 模式下 publish / delete 的 Evidence

### Phase 2 / 3 跟进 — 李冰进度

- [x] Q2 Assayer 接入 **已完成** — 编译通过 + CLI smoke 全绿 + DUnitX 回归 184/186 pass
- [x] Q3 DeepShine 接入 **已完成** — 编译通过 + CLI smoke 全绿（含 CB 联动 Property 7）
- [x] Q2/Q3 盘古 Review 完成（2026-05-11）
  - Assayer: 4 gate 无条件，observe 模式正常；缺 ActionGrid 双注册 + DueRule + gate→actionKeys（enforce 模式下会 "No action resolved"，后续补齐）
  - DeepShine: gckState evaluator 已注册（CB 联动）；同样缺 ActionGrid + DueRule + gate→actionKeys
  - 结论：observe 模式可用，enforce 切换需后续补齐（不阻塞本轮交付，DeepClip 已验证 enforce 全流程）

---

## Phase 2：Assayer Governance 试点（李冰）✅ 已完成

- [x] 2.1 在 Assayer 项目搜索路径中添加 `DeepBase\Governance`
- [x] 2.2 ~~`Assayer/config/governance/` 目录~~ **已废弃**（违反铁律），改走代码注册
- [x] 2.3 Gate 设计（代码注册）— `deepllm.switch_model` L2, `deepllm.update_apikey` L3, `deepllm.delete_history` L3, `deepllm.generate_image` L2
- [x] 2.4 Action 设计（代码注册）— `deepllm.action.*` 一对一绑定
- [x] 2.5 DPR 入口调用 `RegisterGovernance(gmObserve, ConfigDB, callback)`
- [x] 2.6 `GovernanceEnterApiKeyUpdate` / `GovernanceEnterDeleteHistory` 桥接（EnterGate-first 模式）
- [x] 2.7 observe 模式运行 + 验证 Evidence 写 DB1 — CLI smoke Stage 5 验证
- [x] 2.8 CLI smoke harness 替代 DUnitX（`Assayer/tests/build_gov_smoke.bat`）
- [x] 2.9 enforce 回归 — 通过 DeepShine smoke 验证共享 ObserveGateResolver 逻辑
- [x] 2.10 `.kiro/steering/governance-model.md` 自动导出 — CLI smoke Stage 4 验证

---

## Phase 3：DeepShine Governance 接入（李冰）✅ 已完成

- [x] 3.1 DeepShine 添加 `DeepBase\Governance` 搜索路径
- [x] 3.2 代码注册 Gate / Action / Purpose（零 JSON）— `DeepShine.Governance.Registration.pas`
- [x] 3.3 LLM 调用门禁 + 与 Resilience CircuitBreaker 联动 — `gckState` evaluator 注册
- [x] 3.4 验证熔断 + 门禁双重保护 — CLI smoke Stage 4 三次 CB 状态迁移
- [x] 3.5 observe → enforce 切换回归 — CLI smoke Stage 4d (Property 3 + 5)

---

## 全局封版验收

所有项目 observe 通过 + 至少一个项目 enforce 验证通过后，由盘古统一：

- [x] V1 `00.quickstart.AI集成总览-ai-one-file.md` 补 enforce 切换 SOP
- [x] V2 `51.extend.Governance治理扩展-governance-integration.md` 加"验收清单"章节
- [x] V3 `90.history.BugFix记录-bugfix-log.md` 汇入 `bugfix.md` 本轮记录
- [ ] V4 打 Governance 板块交付 tag

---

## 暂缓项目（不在本轮）

| 项目 | 原因 | 下轮条件 |
|------|------|----------|
| DeepMoveC | 已发版稳定，外部 SeedTool 接入够用 | 下次大版本改造时 |
| DeepSVG | 同上 | 同上 |
| DeepCharset | 简单工具，无高风险操作 | 需要收费时再接 |
| DeepConfig | 配置工具，不面向终端用户 | 不接入 |
| DeepInput | 遗留项目，语音已迁移到 DeepBase.Speech | 废弃，不接入 |
| DeepSync | 当前集成够用，无紧迫高风险操作 | Commerce 上线后再加门禁 |
| DeepDev / DevLite | 开发工具，不面向终端用户收费 | 后期 |
| DeepCompare | 简单对比工具 | 后期 |
| DeepLaunch | 启动器，功能单一 | 不接入 |
| DeepRenew | 更新辅助工具 | 不接入 |

---

## 交付定义

Governance 板块"可交付"的充分条件：

1. ✅ 框架层 `Lifecycle.pas` + `Registration.pas` 编译通过并运行时稳定
2. ✅ 至少一个下游项目（DeepClip）完成 observe → enforce 全流程验证（Phase 1.9 + 1.12 DueRule 收紧）
3. ✅ Evidence 持久化到 DB1 `governance_evidence_*` 表可见（Phase 1.8c 验证通过）
4. ✅ `.kiro/steering/governance-model.md` 可由框架自动导出（Phase 1.10 验证通过）
5. ⬜ DeepBaseGovernance.dpk 独立编译通过（包链验证）
6. ⬜ Phase 4 / 5 仙儿交付物通过 review


---

## Phase 6：行为 Mock 测试全覆盖（李冰，2026-05-11 新增）

> 目的：下游项目的 governance 集成不仅要能编译，还要在 observe / enforce 两种模式下对每个已注册的门禁行为给出正确结果。
> 背景：`TGateResolver.EvaluateCondition` 的默认策略是 **fail-closed**——没注册 evaluator 的条件会返回 False。这意味着 enforce 模式下，任何带 `gckPermission` / `gckState` / `gckEvidence` / `gckAccountability` 条件但未注册对应 evaluator 的门禁都会拦截所有请求。Behavior mock 必须在 observe 和 enforce 两种模式下把这条约束验证到。
> 范围：**每个下游项目独立一个 BehaviorMock.dpr + build 脚本**，console 级 harness，不依赖 GUI，出 exit code 用于 CI。

### 共享前提（所有 BehaviorMock 复用）

- 使用 `:memory:` SQLite 隔离，每个 test case 初始化独立 lifecycle。
- `MockEvaluator`：每个项目注册一套可控的条件 evaluator，对 context 字段做简单等值检查，使条件可预测。
- 断言协议：`[OK]` / `[FAIL]`，main 段根据失败计数决定 exit code。

### Phase 6.1：DeepClip BehaviorMock（李冰）

`DeepClip/Tests/BehaviorMock/DeepClipBehavior.dpr`

- [x] 6.1.1 注册 `gckPermission` evaluator：读 context `user.has_pay_permission` 字段
- [x] 6.1.2 注册 `gckState` evaluator：读 context `record_id` 字段（非空视为满足）
- [x] 6.1.3 **Observe mode** 断言：
  - L1 `clip.llm_gate` 无条件 → `gsOpen`
  - L1 `clip.speech_gate` 无条件 → `gsOpen`
  - L2 `clip.export_gate` 无条件 → `gsOpen`
  - L3 `clip.commerce_gate` + pay_permission=false → `EnterGate` 不阻挡（observe）
  - L3 `clip.delete_gate` + record_id='' → `EnterGate` 不阻挡（observe）
- [x] 6.1.4 **Enforce mode** 断言：
  - L3 `clip.commerce_gate` + pay_permission=false → `Resolve.State = gsDisabled`（permission fail）
  - L3 `clip.commerce_gate` + pay_permission=true → `Resolve.State = gsOpen`
  - L3 `clip.delete_gate` + record_id='' → `Resolve.State = gsBlocked`
  - L3 `clip.delete_gate` + record_id='rec123' → `Resolve.State = gsOpen`
- [x] 6.1.5 Evidence 写盘断言：enforce + permission fail → `governance_evidence.result='blocked'` 且 `blocked_reason` 非空

### Phase 6.2：Assayer BehaviorMock（李冰）

`Assayer/tests/BehaviorMock/AssayerBehavior.dpr`

- [x] 6.2.1 Assayer 当前 4 个 gate 都没条件 → observe 和 enforce 下都应 `gsOpen`
- [x] 6.2.2 注入一个带 `gckAccountability` 条件的测试 gate，验证 fail-closed 默认行为
- [x] 6.2.3 注册 `gckAccountability` evaluator（要求 context.actor_key 非空），验证 evaluator 接入生效
- [x] 6.2.4 `EvidenceRecorder` 白名单脱敏（已经在 smoke 里测过，这里 re-assert）
- [x] 6.2.5 `GovernanceEnterApiKeyUpdate` / `GovernanceEnterDeleteHistory` 的 observe vs enforce 行为

### Phase 6.3：DeepShine BehaviorMock（李冰）

`DeepShine/Tests/BehaviorMock/DeepShineBehavior.dpr`

- [x] 6.3.1 CB 状态 → `deepshine.llm_call` resolution（已有 smoke 覆盖，re-assert）
- [x] 6.3.2 `deepshine.publish_content` / `deepshine.delete_task` 没条件 → 两种模式都 `gsOpen`
- [x] 6.3.3 注入 permission 条件 evaluator，enforce 下阻挡
- [x] 6.3.4 `SwitchMode` 运行时切换验证（Property 3 + 5 已在 smoke 覆盖，re-assert）

### Phase 6.4：DeepInsight BehaviorMock（李冰，代仙儿交付 review 前缺口补全）

`DeepInsight/tests/BehaviorMock/DeepInsightBehavior.dpr`

- [x] 6.4.1 注册 `gckPermission` evaluator：读 context `permissions` 字符串数组，查表
- [x] 6.4.2 注册 `gckEvidence` evaluator：读 context `confirmed` bool 字段
- [x] 6.4.3 注册 `gckAccountability` evaluator：读 context `actor_key` 非空
- [x] 6.4.4 **Enforce 断言**：
  - `insight.export_data` 没 permission → `gsDisabled`
  - `insight.export_data` 有 permission 但 confirmed=false → `gsBlocked`
  - `insight.export_data` 有 permission 且 confirmed=true → `gsOpen`
  - `insight.delete_data` 没 permission → `gsDisabled`
  - `insight.delete_data` 有 permission 但 actor_key='' → `gsBlocked`
  - `insight.delete_data` 有 permission 且 actor_key='u1' → `gsOpen`

### Phase 6.5：DeepStory BehaviorMock（李冰，代仙儿交付 review 前缺口补全）

`DeepStory/Tests/BehaviorMock/DeepStoryBehavior.dpr`

- [x] 6.5.1 同 6.4 套三个 evaluator 外加针对 `story.publish_content` 的 word_count 检查
- [x] 6.5.2 **Enforce 断言**：
  - `story.publish_content` 缺 permission → `gsDisabled`
  - `story.publish_content` 有 permission 但 word_count=0 → `gsBlocked`
  - `story.publish_content` 三个条件全满足 → `gsOpen`
  - `story.llm_generate` 缺 llm permission → `gsDisabled`
  - `story.llm_generate` 有 llm permission → `gsOpen`
  - `story.delete_project` 缺 permission → `gsDisabled`
  - `story.delete_project` 有 permission 但 actor_key='' → `gsBlocked`
  - `story.delete_project` 条件全满足 → `gsOpen`
- [x] 6.5.3 LegacyWrapBridge 注册验证：`story.bridge.publish` 和 `story.bridge.delete` 存在于 ActionGrid


---

## Phase 6 运行结果（2026-05-11）

全部 5 个 BehaviorMock harness 跑绿，共 **52 个行为断言，0 失败**。

| 项目 | Harness 路径 | Checks | Exit |
|---|---|---|---|
| DeepClip    | `DeepClip/Tests/BehaviorMock/build.bat`    | 12 | 0 |
| Assayer     | `Assayer/tests/BehaviorMock/build.bat`     | 13 | 0 |
| DeepShine   | `DeepShine/Tests/BehaviorMock/build.bat`   | 11 | 0 |
| DeepInsight | `DeepInsight/tests/BehaviorMock/build.bat` | 6  | 0 |
| DeepStory   | `DeepStory/Tests/BehaviorMock/build.bat`   | 10 | 0 |

**覆盖的行为**：
- Observe 模式不拦截 + 持续写 Evidence（Property 3, 4）
- Enforce 模式按条件类型驱动 `gsDisabled` / `gsBlocked`（Property 5）
- 未注册 evaluator 的条件 fail-closed（架构防线验证）
- Evaluator 接入后，gate state 由 context 精确驱动
- `Lifecycle.SwitchMode` 运行时切换 + 持久化
- Evidence 白名单脱敏（Property 8）

**共享基础设施**：`DeepBase/Tests/Governance/DeepBase.Governance.BehaviorMock.pas` — 提供 `TBehaviorMockAsserter`、`CountRows`、`MakeCtx` helper，5 个 harness 共用。
