# 专家 D 审阅报告: Governance/DeepFlow（第三轮）

> 审查日期: 2026-07-08
> 审查范围: Governance/ 下 41 个 .pas 文件（重点全读 EvidenceStore.SQLite/EvidenceRecorder/Accountability/AbilityRegistry/ActionBinding/ActionExecutor/ActionGrid/Actor/AI.ProposalQueue/AI.SteeringExporter/AI.ViewScopeEnforcer/DueChecker/EventBridge/Explain/FeedbackResolver/GateResolver/ConfigLoader/ConfigRegistrar），DeepFlow/ 下 12 个 .pas 文件（重点全读 Engine、Commander、Message）
> 文件总数: 53

## 概要

8 new issues: 1 P0 / 5 P1 / 2 P2. 关键问题：
- ConfigRegistrar 的 uses 子句缺逗号导致编译失败（P0，阻断性）；
- EvidenceStore 的链迁移方法 `MigrateExistingChain` 从未被调用，旧库行 `this_hash` 永远为空 → VerifyChain 误报篡改；
- ActionGrid 的 CanRun/Run/GetDisabledReason 读取 FActions/FBridges 未加 FLock，与注册路径形成数据竞争；
- EvidenceRecorder.SaveWithRetry 重试无退避（固定 100/200/400）且重试间无抖动，高并发失败时形成重试风暴；
- Engine.SendSync 用单槽 FResponseSink，并发调用互相覆盖，注释声称"safe against concurrent SendSync"但实际不安全；
- Commander.ProcessRequest 在锁外修改会话状态字段，同 session-id 并发请求存在数据竞争。

## 发现列表

| 编号 | 严重度 | 模块 | 分类 | 简述 |
|------|--------|------|------|------|
| GOV-R3-001 | P0 | ConfigRegistrar | 编译阻断 | uses 子句缺逗号导致语法错误 |
| GOV-R3-002 | P1 | EvidenceStore.SQLite | 证据链 | MigrateExistingChain 死代码，旧行未迁移致 VerifyChain 误报篡改 |
| GOV-R3-003 | P1 | ActionGrid | 数据竞争 | CanRun/Run/GetDisabledReason 读字典未加 FLock |
| GOV-R3-004 | P1 | EvidenceStore.SQLite | 事务缺失 | MigrateExistingChain 多行 UPDATE 未包事务，中断致链损坏 |
| GOV-R3-005 | P1 | EvidenceRecorder | 重试风暴 | SaveWithRetry 固定退避无抖动，并发失败时重试风暴 + 阻塞析构 |
| GOV-R3-006 | P1 | DeepFlow.Engine | 并发正确性 | SendSync 单槽 FResponseSink 并发调用互相覆盖 |
| GOV-R3-007 | P2 | DeepFlow.Commander | 数据竞争 | ProcessRequest 锁外修改 Session.State/FTurnCount |
| GOV-R3-008 | P2 | AI.ProposalQueue | 无界增长 | Submit 无容量上限，AI 可无限堆积建议 |

## 各发现详细说明

### GOV-R3-001 [P0] — ConfigRegistrar uses 子句缺逗号，编译阻断
**文件**: D:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.ConfigRegistrar.pas
**位置**: 第 26-27 行
```pascal
  DeepBase.Governance.ActionGrid,
  DeepBase.Governance.DueChecker,
  DeepBase.Crypto, DeepBase.Crypto.Hash
  DeepBase.KeyManager;
```
`DeepBase.Crypto.Hash` 后缺少逗号，编译器将 `DeepBase.Crypto.Hash DeepBase.KeyManager` 视为非法的单元名序列，产生 E1038 / "Identifier expected" 语法错误，整个单元无法编译。任何引用 ConfigRegistrar 的目标（dpk/dproj）都会编译失败。
**修复**: 第 26 行末补逗号 → `DeepBase.Crypto, DeepBase.Crypto.Hash,`。

---

### GOV-R3-002 [P1] — MigrateExistingChain 从未被调用，旧库 VerifyChain 误报篡改
**文件**: D:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.EvidenceStore.SQLite.pas
**位置**: 第 43 行（声明）、第 490-551 行（实现）、第 183-186 行（构造函数）

构造函数调用链为 `EnsureTable → MigrateHashColumns → InitializeChainState`，**从未调用 MigrateExistingChain**（已用 rg 全仓确认仅声明+实现两处出现）。`InitializeChainState` 仅 `GetLastHash` 读取链尾 `this_hash`：对升级前的旧库，所有行 `this_hash` 为空，`GetLastHash` 返回 GENESIS_HASH。

**后果**：
1. 新 `Save` 以 `prev_hash=GENESIS` 接入新行，与旧行无链关系；
2. `VerifyChain` 遇到旧行（`this_hash=''`）时，计算 `LExpectedHash` 并与空 `LStoredHash` 比较 → `SameText('', <hash>)` 为 False → `Inc(ABrokenCount)`，**所有旧行均被误报为篡改**；
3. 第 606-609 行虽用 `LExpectedHash` 推进 `LPrevHash`，但已计数 broken，审计报告失真，无法区分真实篡改与未迁移。

**修复**: 在构造函数 `MigrateHashColumns` 之后调用 `MigrateExistingChain`（需在 FLock 内），或让 `VerifyChain` 对 `this_hash=''` 的行先迁移再验证。注意需配合 GOV-R3-004 的事务包裹。

---

### GOV-R3-003 [P1] — ActionGrid CanRun/Run/GetDisabledReason 读字典未加 FLock
**文件**: D:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.ActionGrid.pas
**位置**: 第 129-149 行（CanRun）、第 151-170 行（GetDisabledReason）、第 196-237 行（Run）、第 172-178 行（SetEnabled）、第 239-259 行（GetActionInfo）

`RegisterAction`/`RegisterActionObj`/`RegisterBridge`/`FindAction` 都在 `FLock` 下操作 `FActions`/`FBridges`，但读取类方法（CanRun、Run、GetDisabledReason、SetEnabled、GetActionInfo）直接调用 `FActions.TryGetValue` / `FBridges.TryGetValue` **未持有 FLock**。若运行时热注册 Action/Bridge（ConfigRegistrar.RegisterAction → FActionGrid.RegisterActionObj 在第 112 行加锁写），与 UI 线程的 CanRun/Run 并发，`TDictionary` 内部桶数组在 rehash 期间被并发读 → 可能读到半更新状态或 AV。

**修复**: 这些读路径统一 `FLock.Enter/try/finally Leave`，或改用只读快照。注意 FindAction 已正确加锁，可复用其模式。

---

### GOV-R3-004 [P1] — MigrateExistingChain 多行 UPDATE 未包事务，中断致链损坏
**文件**: D:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.EvidenceStore.SQLite.pas
**位置**: 第 490-551 行

`MigrateExistingChain` 在 `while not LReadQuery.Eof` 循环中对每行调用 `LUpdateQuery.ExecSQL`（第 533 行），**整段无事务包裹**。若进程在迁移中途崩溃/断电：
- 前 N 行已写入 `prev_hash`/`this_hash`，后续行仍为空；
- 重启后 `InitializeChainState` 的 `GetLastHash` 可能取到已迁移行的 hash，新 Save 接入正确链段；
- 但 `VerifyChain` 对未迁移的尾段仍会误报（同 GOV-R3-002），且无法定位断裂点。

**修复**: 迁移全程包在 `FConnection.StartTransaction / Commit` 中，异常时 `Rollback`；迁移完原子可见。

---

### GOV-R3-005 [P1] — EvidenceRecorder.SaveWithRetry 固定退避无抖动，析构阻塞
**文件**: D:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.EvidenceRecorder.pas
**位置**: 第 287-327 行（SaveWithRetry）、第 163-183 行（析构函数）

`SaveWithRetry` 用 `PUSH_RETRY_DELAYS = (100,200,400)` 固定退避，**无随机抖动**。当 SQLite 锁争用（多写者）导致批量失败时，所有失败线程同步在相同 100/200/400ms 点重试，形成重试风暴（thundering herd），放大锁争用。

另外析构函数第 167-172 行在 `FRunning=True` 时同步调用 `Flush`，`Flush` 内对每个待写条目调用 `SaveWithRetry`（最坏 100+200+400=700ms/条），队列满 1000 条时析构可阻塞 **数百秒**，期间持有 recorder 不释放。`Flush` 也无超时上限。

**修复**: (1) 退避加 ±30% 抖动；(2) Flush 限制最大处理条数或设超时；(3) 析构时若 Flush 超时则剩余条目转入失败队列而非阻塞。

---

### GOV-R3-006 [P1] — Engine.SendSync 单槽 FResponseSink 并发互相覆盖
**文件**: D:\_Progs\02Business\DeepBase\DeepFlow\Source\Core\DeepFlow.Engine.pas
**位置**: 第 502-548 行（SendSync）、第 744-760 行（ProcessMessage 分发）

`FResponseSink` 是单实例字段。两个线程并发 `SendSync`：线程 A 先在 515-528 行设置 `FResponseSink := procedure(...)`，线程 B 紧随其后用 **自己的 correlationId 覆盖** `FResponseSink`。之后 `ProcessMessage` 第 752 行取到的 `LSink` 是 B 的闭包，A 的响应到来时匹配 B 的 correlationId 失败 → A 的 `ResponseEvent` 永不 SetEvent → A 在 534 行 `WaitFor(ATimeout)` 超时，响应丢失。第 514 行注释声称 "safe against concurrent SendSync calls"，与实现不符。

**修复**: 用 `TDictionary<string, TWaitForResponse>`（key=MsgId）替代单槽，每条 SendSync 注册自己的 (event, response) 槽，ProcessMessage 按 correlationId 查表分发后移除。

---

### GOV-R3-007 [P2] — Commander.ProcessRequest 锁外修改会话状态
**文件**: D:\_Progs\02Business\DeepBase\DeepFlow\Source\Roles\DeepFlow.Commander.pas
**位置**: 第 340-380 行（ProcessRequest）、第 181-190 行（GetOrCreateSession）

`GetOrCreateSession` 在 `TMonitor.Enter(FSessionLock)` 下返回 `TSession` 指针并释放锁。随后 `ProcessRequest` 在锁外修改 `Session.State`（第 350、371、375 行）和 `Session.FTurnCount`（第 351 行 `Inc`）。两个线程用相同 session-id 并发调用时，`Inc(FTurnCount)` 非原子、`State` 赋值非原子，turn 计数丢失 / 状态错乱。

**修复**: 修改会话字段时重新 `TMonitor.Enter(FSessionLock)`，或将这些字段的读写统一封装为带锁的方法。

---

### GOV-R3-008 [P2] — ProposalQueue.Submit 无容量上限，AI 可无限堆积
**文件**: D:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.AI.ProposalQueue.pas
**位置**: 第 136-142 行（Submit）、第 51-53 行（字段）

`Submit` 直接 `FProposals.Add(Result)`，无最大容量检查。`FProposals` 是 `TObjectList<TProposal>` 无上限。AI Agent 若循环提交（或被恶意 steering 诱导）可无限堆积 `TProposal` 对象，内存无界增长直至 OOM。且 `FindById`/`GetPending` 为 O(n) 线性扫描，队列膨胀后审批 UI 卡顿。

另注：`TProposalQueue` 全程无锁，若 AI 后台线程 Submit 与 UI 线程 Approve/Reject 并发，`TObjectList` 并发读写可致 AV。考虑到当前调用方多为单线程 UI，定级 P2；若引入后台 AI 提交则升 P1。

**修复**: Submit 前检查 `FProposals.Count >= FMaxPending`（可配置，默认如 1000），超出则拒绝或淘汰最旧的非 submitted 项；若可能多线程访问，加 `TObject`/TCriticalSection 保护。

---

**附加说明（非 bug，不单独编号）**：ActionGrid.CheckDueIfRequired 第 192 行 `raise Exception.CreateFmt(...)` 使用泛型 `Exception`，违反 CLAUDE.md "不引入泛型 Exception.Create；业务错误优先使用具体异常类"约定，建议改用 `DeepBase.Exceptions` 中的具体类或模块内 `EGovernanceError`。属 P3 风格问题，本轮不计入发现数。
