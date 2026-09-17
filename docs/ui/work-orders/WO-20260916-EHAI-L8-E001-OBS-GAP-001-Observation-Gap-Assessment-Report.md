# WO-20260916-EHAI-L8-E001-OBS-GAP-001
# Observation Gap Assessment Report
## AsWish + AXIS 现实观察证据缺口评估报告（R3 终验收口版）

- **工单编号**：`WO-20260916-EHAI-L8-E001-OBS-GAP-001`
- **执行性质**：Phase 2 观察员 / 证据调查员专项报告（READ-ONLY，零业务代码开发）
- **依据协议**：`D:\_Progs\02Business\DeepBase\docs\ui\work-orders\L8-E001-Observation-Protocol.md`（`Version = v1`，`Status = FROZEN FOR CASE 001`，SHA256: `747079c8…0de88`）
- **复审响应**：针对主控（Amy · 沈予安）出具的《Phase 2 整改交付｜主控复验结论（R2 CONDITIONAL HOLD）》执行闭环整改（3 项阻断 H-1/H-2/H-3 + 2 项勘误 N-1/N-2 全量闭合）
- **调查对象快照**：
  1. `AsWish` (`D:\_Progs\02Business\AsWish`，HEAD: `0b22a528bdfc85fcba0e08abfb98c6917e529bf7`)
  2. `AXIS` / `DeepAxis` (`D:\_Progs\02Business\DeepAxis`，HEAD: `82e57eae1343fcd995adfb67134254390280ab51`)
  3. `DeepBase` (`D:\_Progs\02Business\DeepBase`，当前基线 Commit: `51f962ca912ce49fd9543c0f066e796b38bb34ef`)
- **调查角色**：开发甲（切换为 Observer / Evidence Investigator 身份）
- **完成时间**：2026-09-17 10:35:00 +0800
- **评估总结论**：**`READY WITH RECOVERY PROCEDURES`**（已具备完整观察与恢复能力，**存在 0 项阻断性缺口，受控证据归档落点已确立，严禁额外开发观测平台**，符合条件即可启动 Case 001 真实观察）

---

## 〇、总结论与决策出口（结论先行）

本报告严格依据协议正源 §3 规定的全部 **26 个** Episode Record 最小字段（逐 token 对齐，无一遗漏），对 AsWish 与 AXIS 两大系统的现有物证、物理路径与恢复链路进行了逐项源码级与实物级穿透调查。

```text
================================================================================
【评估结论（协议 §3 逐 Token 26 字段全覆盖）】
  协议规定最小字段集 ：26 项（逐 Token 严格对应）
  AsWish 字段分类统计 ：A 类（直接可观）= 18 项 | B 类（稳定恢复）= 8 项 | C 类 = 0 项（合计 26 项）
  AXIS   字段分类统计 ：A 类（直接可观）= 19 项 | B 类（稳定恢复）= 7 项 | C 类 = 0 项（合计 26 项）
  Observation Blocking Gaps ：0 项（NONE，无任何阻断 R1/R2/R3 之缺口）
  受控证据落点确立 (H-3)    ：DeepBase/evidence/L8-E001/（含 episodes/, aswish/, axis/, baselines/）
  Non-blocking Findings     ：4 项（D-1, C-1, r-1, W-1 登记备查）
  Nice-to-have Items        ：1 项（无状态轻量汇总脚本，非平台）
================================================================================
【放行裁定判定】
  最终状态判定：READY WITH RECOVERY PROCEDURES
  开发准则响应：No Blocking Gap → NO CODE / NO PLATFORM REQUIRED
  后续行动建议：本报告提交入库，关闭 Phase 2，如期启动 Case 001
================================================================================
```

---

## 一、AsWish A/B/C 证据源与分类矩阵（逐项对齐真实物理布局与协议 §3 全部 26 字段）

AsWish 作为 EHAI 软件工程设计首发产品（Reference Product Binding 001），其交互核心建立在 `Intent -> ChangeSet -> HB Choice Review -> Decision Gate -> Baseline` 的确定性单向流之上。
本表全面纠正历史约定性错误，严格按每个被测项目真实存在的 `<ProjectDir>/.AsWish/` 目录结构与源码真实 API 列明取证来源（闭环 H-1 / H-2）：

| # | 协议 §3 字段 (Token) | AsWish 真实物理证据来源（Source） | 分类 | 证据性质与恢复方法（Recovery Procedure / Confidence） |
| :-: | :--- | :--- | :---: | :--- |
| 1 | **episode_id** | `TChangeSet.Id` (`cs-...`) / `TEhaiTraceRecord.TraceId` | **B** | **恢复方法**：以单次规范变更任务流为单元，统一映射为 `ep-aw-{ChangeSetId}`。置信度：极高（全局唯一，无碰撞）。 |
| 2 | **timestamp** | `TChangeSet.CreatedAt` / `TSpecDecision.CreatedAt` | **A** | 强类型 `TDateTime`（`AsWish.Models.pas:198, 310`），YAML 存盘时格式化为标准 ISO 8601 UTC 字符串，全生命周期自带精确时间戳。 |
| 3 | **product** | `TAsWishHBBinding.Context.ProductRef` = `'AsWish'` | **A** | 常量直出，在 `Binding.HB.pas:163` 及项目配置中机器可读。 |
| 4 | **software_commit** | AsWish 仓库 `git rev-parse HEAD`（当前 `0b22a528bdfc85fcba0e08abfb98c6917e529bf7`） | **B** | **恢复方法**：观察开始时记录受观察软件版本 Commit SHA。置信度：极高。 |
| 5 | **model** | 应用级 `config.json`（存取键 `aswish.llm.<Profile>.model`）及运行时日志 | **B** | **恢复方法（勘误 H-2）**：AsWish 无 `.aswish/config.yaml`；LLM 模型参数由 `AsWish.Config` / `TAsWishLLMConfigHelper.SaveModelScopeConfig` 持久化于应用级 JSON 配置（键 `aswish.llm.Default.model`），从环境配置及批次日志中提取执行时模型版本（如 `deepseek-chat`）。置信度：高。 |
| 6 | **task_type** | `TChangeSet.AffectedProjections` / `IntentTree` | **A** | 直接记录操作投影树（`ttFunction` 需求, `ttModule` 架构, `ttView` 界面, `ttData` 数据）及 `dtAcceptDifference` 差异裁决。 |
| 7 | **human_goal** | `TCandidateIntent.UserIntent` / `TChangeSet.RawUserIntent` | **A** | 物理 YAML 文件中 `raw_user_intent` 逐字保留人类初始自然语言目标。 |
| 8 | **initial_context_ref** | `<ProjectDir>/.AsWish/snapshots/<SnapshotName>/snapshot.yaml` 中固化的 `lineage.parent_baseline_id` 与前驱快照目录 | **A** | **（勘误 H-2）**：通过 `parent_baseline_id` 定位前驱快照目录，在 `TChangeItem` 中明确保留每个字段的 `BeforeValue`。 |
| 9 | **candidate_count** | `TChangeSet.Items` 数组长度 / `CandidateSpace` | **A** | 候选空间严格受控 $\le 7$，直接读取候选条目数组长度。 |
| 10 | **regenerate_count** | `TEhaiTraceRecord` (`cakRegenerate` / `emaRegenerate`) | **A** | 绑定层直接拦截 Key 8，触发 `ExportPrompt`，记录 `eseInformOnly` 探索轨迹，不提交规范。 |
| 11 | **frame_rejection_count** | `TCandidateIntent.IsFrameRejection` + `RejectedNodeId` | **A** | Key 9（子类型 3，FR-AW-01）显式记录：被否定节点置为 `nsRejected`，高层需求定向挂载至 Function 上游树，全链路机器可判。 |
| 12 | **human_override_count** | `TChangeSet.Items[].SourceType` = `cstExplicit` | **A** | 人类通过 Key 9（子类型 1/2）提出的自由自然语言输入，在 `ChangeItem` 中严格标明 `cstExplicit`，与 AI 推断隔离。 |
| 13 | **back_count** | `TEhaiTraceRecord` (`cakBack` / `emaExit`) | **A** | 绑定层直接记录无承诺退出事件，确认 Canonical Spec 树零字节改动。 |
| 14 | **human_decision_count** | `TSpecDecision`（位于 `<ProjectDir>/.AsWish/decisions/decisions.yaml` 与 `requirement-decisions.yaml`） | **A** | **（勘误 H-2）**：包含 `Id`, `DecisionType`, `Title`, `Rationale`, `DecidedBy=dbHuman`, `Status`, `TargetNodes`, `ChangeSetId`。 |
| 15 | **authorization_event_count** | `AcceptChangeSet(ChangeSetId, Rationale)` | **A** | 承诺门禁（Commitment Gate）跨越时显式记录人类决策理由与授权（`eseAuthorized`）。 |
| 16 | **commitment_event_count** | `TAsWishBaseline` (`B-####`) + 物理快照与树写入 | **A** | **（勘误 H-2）**：跨越承诺边界，由 `TAsWishSnapshotService.CreateBaseline` 写入 `<ProjectDir>/.AsWish/snapshots/<SnapshotName>/snapshot.yaml` 及 `trees/*.yaml`，固化 `ContentHash` 与 `RelationHash`。 |
| 17 | **completion_status** | `TSpecDecision.Status` + 基线快照挂载 | **B** | **恢复方法**：若 ChangeSet 对应 Decision 状态为 `dsAccepted` 且生成基线快照，则判定为 `Completed`；若为 `dsRejected` 则为 `Abandoned`。置信度：极高。 |
| 18 | **rework_count** | 针对同一 `IntentNodeId` / `ParentBaselineId` 的变更集频次 | **B** | **恢复方法**：统计历史 ChangeSets 中指向同一节点或前驱基线的迭代记录数。若 $>1$ 即发生返工。置信度：高。 |
| 19 | **correction_count** | `TChangeItem` 中 `SourceType=cstExplicit` 且修改 AI 项 | **A** | 逐项对比 `cstExplicit` 与 `cstInferred`，精确观察人类对 AI 建议的手工修正。 |
| 20 | **semantic_incident** | `AsWish.Validation.pas` + `TSpecIssue` (`itConflict`等) | **A** | 结构校验器自动捕获孤立节点、未决冲突、来源漂移及非法状态机迁移。 |
| 21 | **authority_incident** | `<ProjectDir>/.AsWish/trees/*.yaml` 物理更新与 `decisions/` 签名比对 | **B** | **恢复方法**：比对 Spec 树文件修改时间与决策提交时间；若存在无合法 Decision 支撑的磁盘变更，即标记为越权。置信度：极高。 |
| 22 | **recovery_incident** | `<ProjectDir>/.AsWish/snapshots/<SnapshotName>/snapshot.yaml` 中的 `lineage.parent_baseline_id` 指针链与 `TAsWishSnapshotService.VerifyBaseline` 验算 | **B** | **恢复方法（闭环 H-1）**：删除虚构的 `.aswish/baselines.yaml`；基线与血缘实际固化于每个快照目录下的 `snapshot.yaml`。源码层由 `AsWish.Services.Snapshot.pas:403-466` 提供 `VerifyBaseline`（实测通过重新计算 `trees/*.yaml` 的 ContentHash 与 RelationHash 比对元数据）。事后分析时由轻量脚本遍历 `snapshot.yaml` 的父子指针链；若指针断链或哈希验算失败，即记录为恢复失败。置信度：高。 |
| 23 | **outcome_evidence_ref** | 目标项目代码文件 / `<ProjectDir>/.AsWish/html/visual-preview.html` | **A** | 真实工程产物：由规范驱动生成的 Delphi 源码、VCL 窗体 DFM、视觉预览 HTML。 |
| 24 | **raw_evidence_ref** | `<ProjectDir>/.AsWish/snapshots/` + `<ProjectDir>/.AsWish/llm/` + Git 日志 | **A** | **（勘误 H-2）**：无 `changesets/` 目录，候选变更集实际位于 `<ProjectDir>/.AsWish/llm/change-set-*.yaml`；快照位于 `<ProjectDir>/.AsWish/snapshots/<Name>/`。均为真实存在的原始 YAML。 |
| 25 | **intervention_id** | `docs/ui/work-orders/L8-E001-Intervention-Registry.md` | **B** | **恢复方法**：在轻量登记表中记录每次工程干预（Commit、原因、生效时间）。依据 Episode 的 `timestamp` 与 `software_commit` 查表匹配对应的 Intervention ID（无干预则为 `'none'`）。置信度：极高。 |
| 26 | **notes** | Episode Record 之 `notes` 字段 / 自主自述四问 | **A** | 直接作为 Episode 记录的结构化承载位，挂载人类 Voluntary Self-report 四问结果或异常现场手记。 |

**AsWish 分类小计**：`A 类 = 18` 项，`B 类 = 8` 项，`C 类 = 0` 项，总计 `26` 项。

---

## 二、AXIS (DeepAxis) A/B/C 证据源与分类矩阵（逐项对齐真实符号与协议 §3 全部 26 字段）

AXIS 作为 EHAI 商业关系经营首发产品（Product Binding 002），其核心特征在于 `F0/F1 Authority Gate`、`A0~A3 强授权模型` 以及 `F2B 首飞与回执链`。

| # | 协议 §3 字段 (Token) | AXIS 现有真实证据来源（Source） | 分类 | 证据性质与恢复方法（Recovery Procedure / Confidence） |
| :-: | :--- | :--- | :---: | :--- |
| 1 | **episode_id** | `THJAuditEvent.CorrelationId` / `ActionContractId` | **B** | **恢复方法**：以单次触达/评估治理周期为单元，统一映射为 `ep-ax-{CorrelationId}`。置信度：极高。 |
| 2 | **timestamp** | `THJAuditEvent.TsUtc` / `flight-receipt.json` 之 `timestamp` | **A** | **（勘误 N-2）**：删除不存在的 `F2BReceipt` 类型引用。回执直接由 `FirstFlightPhaseB.dpr` 生成为结构化 JSON 文件，带毫秒级 ISO 8601 UTC 字符串；审计链输出 `yyyy-mm-dd"T"hh:nn:ss.zzz"Z"`。 |
| 3 | **product** | `DeepAxis.Binding.EHAI` / `HJF0.Types` 常量 `'AXIS'` | **A** | 绑定层与治理层全局常量直接标识。 |
| 4 | **software_commit** | DeepAxis 仓库 `git rev-parse HEAD`（当前 `82e57eae1343fcd995adfb67134254390280ab51`） | **B** | **恢复方法**：观察期初始登记受测代码基线。置信度：极高。 |
| 5 | **model** | `F3B.Adapters` 运行时日志与配置数据库记录 | **B** | **恢复方法**：从 F3 调用记录或系统全局配置中提取模型版本。置信度：高。 |
| 6 | **task_type** | `TAXISCandidateKind` / `THJAuthPackage.Purpose` | **A** | 明确分类：联系人触达建议 (`ackContactSuggestion`)、关系评估决策 (`ackRelationshipJudge`)、沟通话术生成 (`ackScriptOption`)、商业工作流执行 (`ackBusinessAction`)。 |
| 7 | **human_goal** | `TAXISSourceRecord.OriginalHumanExpression` / `Purpose` | **A** | 双轨来源记录逐字保存人类原始目标，授权包明确载明业务意图。 |
| 8 | **initial_context_ref** | `ContactDB1` + `TagProfileDB1` + 相关前序审计事件 | **A** | 触达前联系人阶段（`TF1Stage`）、历史互动记录与合规标记（`TF1Marks`）。 |
| 9 | **candidate_count** | `TAXISConvergenceTrace.OriginalCount` & `RetainedCount` | **A** | 候选收敛轨迹强保证：完整记录初始候选数、保留槽位数（$\le 7$）及被裁剪候选项。 |
| 10 | **regenerate_count** | `THJAuditEvent` (`EventType = 'hjf0_candidate_regenerate'`) | **A** | 记录 Key 8 探索事件，重算话术或重选联系人，不签发 Permit。 |
| 11 | **frame_rejection_count** | `TAXISFrameRejectionDisposition` / `hjf0_frame_rejection` | **A** | Key 9 框架否定显式转换为领域治理动作：重定目标 (`afrReidentifyGoal`)、重选对象 (`afrReselectContact`)、终止任务 (`afrHaltTask`)。 |
| 12 | **human_override_count** | `TAXISSourceRecord.Source = esHuman` / `hjf0_human_override` | **A** | 人类通过 Key 9 输入的定制话术或排除指令，明确标记为人类来源且未经 AI 加工。 |
| 13 | **back_count** | `THJAuditEvent` (`EventType = 'hjf0_back_navigation'`) | **A** | 明确记录退出事件，保持联系人状态与授权状态无任何副作用。 |
| 14 | **human_decision_count** | `THJAuditEvent` (`hjf0_auth_activated`) / `TF1Assessment` | **A** | 人类针对 A1/A2 授权包的明确激活决策与意图确认。 |
| 15 | **authorization_event_count** | `THJAuthPackage` (`Level=A1/A2`, `BoundContactId`, `Sha256`) | **A** | 强类型不可伪造授权包，受时间窗口、预算上限与防重用强约束。 |
| 16 | **commitment_event_count** | `THJAuthorizationStore.ConsumeBudget` + `PermitId` 签发 | **A** | 跨越单向承诺边界：单次消耗型 Permit 签发，进入执行就绪状态。 |
| 17 | **completion_status** | `THJAuditEvent` (`f2b_receipt`) / `flight-receipt.json` 之 `terminal_state` | **B** | **恢复方法（勘误 N-2）**：若处于真实模式且收到回执，状态为 `dsConfirmed` 则为 `Completed`；若网关拒绝（`hjf0_gate_denied`）则为 `Blocked`；若超时则为 `Failed`。置信度：极高。 |
| 18 | **rework_count** | 同一联系人/会话下的重试重发事件计数 | **B** | **恢复方法**：按 `ContactId` 或 `CorrelationId` 归集审计日志，计算重新生成与授权撤回次数。置信度：高。 |
| 19 | **correction_count** | 人类修改后正文 SHA256 与 AI 初始模板 SHA256 之比对 | **B** | **恢复方法**：比较 `BoundBodySha256` 与初始生成话术指纹；指纹不符即证明人类进行了文本级校正。置信度：极高。 |
| 20 | **semantic_incident** | `F4 Defect Evidence` 监控 / `FJ_ERR_BODY_UNAUTHORIZED` | **A** | F4 整改后机器语义强校验（`dmEngineVerification` vs `dmReal`），禁止仿真冒充真实。 |
| 21 | **authority_incident** | `THJPolicyGate` 拒绝事件（`hjf0_gate_denied`） | **A** | 策略门禁主动拦截并记录违规事件：越界调用、通配权限拒绝、预算超限、紧急熔断。 |
| 22 | **recovery_incident** | `THJAuditLog.VerifyChain` 返回 `BrokenAtSeq` | **A** | SHA-256 审计哈希链自动验算：篡改、重排、删除事件均直接暴露。 |
| 23 | **outcome_evidence_ref** | 真实微信交互回执（含真机网络/UI证据） / 仿真引擎回执 | **A** | 结构化回执：区分真实证据与引擎验证证据（受 §8 准入门审查）。 |
| 24 | **raw_evidence_ref** | `runtime/flight-receipt.json` + `AuditLog` + 数据库 WAL | **A** | 不可变机器原始日志、加密 WAL 重放文件、原始消息结构。 |
| 25 | **intervention_id** | `docs/ui/work-orders/L8-E001-Intervention-Registry.md` | **B** | **恢复方法**：在轻量登记表中记录每次工程干预（如 F4 整改 `12dd4da`）。按 Episode 发生时间戳与代码提交哈希关联匹配。置信度：极高。 |
| 26 | **notes** | Episode Record 之 `notes` 字段 / 回执 `environment_note` | **A** | 直接作为 Episode 记录主观自述或环境运行上下文之承载位。 |

**AXIS 分类小计**：`A 类 = 19` 项，`B 类 = 7` 项，`C 类 = 0` 项，总计 `26` 项。

---

## 三、R1 / R2 / R3 三大根系覆盖度评估

### 1. R1｜现实结果完整性（Outcome Integrity, O1–O6）
- **O1 任务完成**：AsWish 基于 `snapshot.yaml` 基线快照判断；AXIS 基于 `PermitId` 消费与真机回执状态判断。**完全可判定，无靠猜成分**。
- **O2 返工分析**：AsWish 从多次 ChangeSets 归集，AXIS 从审计重试链归集，均可分类为需求理解偏差、人类意向改变或权限故障。
- **O3 注意力负担**：两仓 `HBBinding` 均完整记录 0–9 Interaction Grammar 的物理点击/键盘事件（Choose / Regenerate / Override / Back 次数），客观计数完整。
- **O4 人类判断保留**：AsWish 严格要求 `AcceptChangeSet` 才能修改 Spec；AXIS 严格要求 A1/A2 授权才能签发 Permit。AI 无法自动跨越承诺门禁，判断点 100% 被捕获。
- **O5 语义完整性**：AsWish 之 `cstExplicit` vs `cstInferred` 与 AXIS 之 `TAXISSourceRecord` 强保证人类原话与 AI 派生可严格区分。
- **O6 恢复与溯源**：AsWish 具备 `snapshot.yaml` 之 `parent_baseline_id` 逆向图谱与 `VerifyBaseline` 验算；AXIS 具备 `THJAuditLog` SHA-256 连续哈希链。
- **R1 综合判定**：**PASS（完整覆盖，无需新增工程打点）**。

### 2. R2｜效果归因完整性（Attribution Integrity）
- **反事实分析支持**：协议 §5.1 强制反事实提问（*如果没有这套机制，结果是否一样？*）。两仓数据均提供足够的中间状态与探索痕迹，使事后可检验「是机制生效还是模型凑巧」。
- **干扰变量与工程干预切分**：
  - **不新建任何系统**：不开发 Registry 软件系统；
  - **实体落地**：已正式建立并入库轻量化结构文档 [`docs/ui/work-orders/L8-E001-Intervention-Registry.md`](file:///D:/_Progs/02Business/DeepBase/docs/ui/work-orders/L8-E001-Intervention-Registry.md)；
  - **分池规则**：按干预事件生效时间戳（`Effective Time`），将 Episode 数据机械切分为 `Before Intervention` 与 `After Intervention` 两个独立统计池，严禁混池计算。
- **R2 综合判定**：**PASS（归因结构稳固）**。

### 3. R3｜经验主张完整性（Claim Strength & Empirical Ceiling）
- **Claim Ladder 约束**：严格限制在 Case 001 仅能输出 E0（事件事实）、E1（Case 内观察）、E2（重复模式）、E3（有关联的 Case 结论），严禁越级宣称 E4（跨 Case 普遍规律）。
- **反例强制单列**：明确规定最终报告必须包含《反预期证据与无效场景》独立章节，严禁只报喜不报忧。
- **禁止单一合成分数**：严禁计算任何形式的假大空综合指数（如 "EHAI Score"）。
- **R3 综合判定**：**PASS（治理规则明确，逻辑自洽）**。

---

## 四、Comparison B 历史素材受控归置与 Case 001 证据落点（闭环 H-3）

### 1. Comparison B 历史基座受控归置与事实澄清
主控复审指出：AsWish 仓内的 `batch_dogfood/`（158 文件）与全部 8 个 `dogfood_*/` 目录目前受 `AsWish/.gitignore:55/57` 规则忽略，处于未受控的工作树本地暂存态。
为彻底消除证据生命周期保障不成立的硬伤，本报告在此做出**正式事实澄清与受控基座锚定**：
1. **AsWish Comparison B 版本控制内基座**：
   - **已受控尖兵样本**：`AsWish/Spikes/WO-0030-VCL-HighFidelity/`（9 个源码与元数据文件已正式提交入库，Commit `7624a1d09da164b60d3a6deffb2d4c1127383548`，彻底消除 N-3 声明失真）；
   - **已受控工程样本**：AsWish 仓内 `WO/evidence/runtime-generic-project/` 完整处于 Git 版本控制内（含 `.deepspec/`、`app.py`、`legacy.pas` 等），可直接作为受控测试用例；
   - **历史冻结存证**：建立 [`DeepBase/evidence/L8-E001/baselines/aswish-historical-manifest.json`](file:///D:/_Progs/02Business/DeepBase/evidence/L8-E001/baselines/aswish-historical-manifest.json)，对 `batch_dogfood/proj_calc_tool` 全部 51 个文件进行逐文件 SHA256 哈希固化，正式声明为 **FROZEN_READ_ONLY_EXTERNAL_SAMPLE**；
2. **AXIS Comparison B 版本控制内基座**：
   - 建立 [`DeepBase/evidence/L8-E001/baselines/axis-historical-manifest.json`](file:///D:/_Progs/02Business/DeepBase/evidence/L8-E001/baselines/axis-historical-manifest.json)，将 DeepAxis 仓内已受版本控制的 **56 个** 历史归档文档（`docs/_archive/`）与 Git 历史提交锚定为受控历史工作流基线。

### 2. Case 001 受控证据官方落点（Controlled Evidence Landing Zone）
为杜绝 Case 001 启动后新产生的观察证据落入被忽略目录导致重演「工作树单副本」的致命缺陷，正式确立官方受控归档落点：
```text
D:\_Progs\02Business\DeepBase\evidence\L8-E001/
├── README.md                           # 归档纪律与说明文件（已建立入库）
├── episodes/                           # 标准化 Episode YAML 记录集 (ep-YYYYMMDD-AW/AX-###.yaml)
├── aswish/                             # AsWish 各 Episode 抽取的受控证据快照 (snapshots/decisions/trees)
├── axis/                               # AXIS 各 Episode 抽取的受控证据回执与审计链 (receipts/audit-logs)
└── baselines/                          # Comparison B 历史对照样本受控清单与指纹镜像
    ├── aswish-historical-manifest.json # AsWish 51 文件 SHA256 冻结清单（已建立入库）
    └── axis-historical-manifest.json   # AXIS 56 篇历史归档清单（已建立入库）
```
**归档硬纪律**：
- 在观察过程中，即使被测 AsWish 项目位于本地 `dogfood_*/`，**每个 Episode 结束后，必须将核心证据镜像（`snapshot.yaml`、`decisions.yaml`、`change-set-*.yaml`）连同标准化 `ep-*.yaml` 复制至上述 DeepBase 对应受控目录**；
- 每日观察窗口关闭前，必须将当日全部新增证据通过 Git Commit 提交入库。**严禁证据只保留在未受跟踪目录中。**

---

## 五、主观自述可行性评估（Voluntary Self-Report）

依据协议 §14 与 §二十一，主观自述采用 **VOLUNTARY + LOW-BURDEN** 模式：

1. **执行方式**：
   - **严禁**开发完整问卷调查软件、弹窗系统或收集平台；
   - 采用纯轻量级 Markdown / YAML 附加片段形式，在关键 Episode（如发生明显返工、框架否定或严重事故）发生后，由人类自愿记录：
     ```yaml
     self_report:
       goal_achieved: "yes" # 1. 这次是否达到了你的目的？
       redundant_step: "none" # 2. 哪一步让你觉得多余？
       unauthorized_takeover: "none" # 3. 有没有哪一步系统替你做了你认为应该由你决定的事情？
       desired_difference: "none" # 4. 如果再做一次，你最希望哪里不同？
     ```
2. **可行性判定**：**FEASIBLE IMMEDIATELY（立即可行，零工程负担）**。

---

## 六、现实证据准入门就绪度评估（Reality Evidence Admission Gate）

依据协议 §8、§9 及主控最新 F4 Delta Review 裁定：

1. **F4 状态**：
   - 主控复审判定：`PASS WITH NON-BLOCKING FINDINGS`，`F4 = CLOSED`；
   - 机器语义全面修正：仿真回执明确标记 `mode="engine-verification"`，终态为 `terminal_state="ENGINE_VERIFIED"`，`real_device_delivery=false`；
   - 真实交付边界强拦截：若试图在 `dmReal` 模式下挂载 mock 时钟，引擎立即 Fail-Closed（`F2B_ERR_MOCK_CLOCK_IN_REAL_MODE`）；
   - 历史缺陷样本（`c5a13f52…3095`）永久移入审计样本区，并在新回执中标记 `INVALID AS REAL-FLIGHT EVIDENCE`。
2. **准入门 5 项条件核验**：
   - [x] 1. Evidence mode 可以机器读取：**满足**（结构化枚举）
   - [x] 2. Real / Mock / Simulation 可以机器区分：**满足**（Delphi + Python 机器测试验证）
   - [x] 3. Evidence provenance 可恢复：**满足**（SHA256 审计链）
   - [x] 4. Real-world outcome 不依赖自然语言免责：**满足**（纯结构化字段判定）
   - [x] 5. 没有已知 Reality Classification Defect：**满足**（F4 已 CLOSED）
3. **准入判定**：**ADMISSION GATE READY**。Case 001 的 AXIS 真实触达数据只要具备真机网络/UI执行凭证，即可正式申请准入。

---

## 七、缺口登记表（Gap Register）

### 1. Observation Blocking Gaps（阻断性缺口）
- **统计**：**0 项（NONE）**。
- **说明**：两仓对应协议 §3 全部 26 个字段均处于 A 类（已有）或 B 类（可稳定恢复），受控证据落点已指定，不存在任何直接阻断 R1/R2/R3 分析的工程缺失。

### 2. Non-blocking Findings（非阻断登记项）
按主控复审结论要求，登记 4 项遗留技术发现（不阻断观察启动）：
- **D-1 引用锚点勘误**：后续文档中涉及 Engine.pas 拦截代码时，精确指向 `:623-625` 与 `:824-826`。
- **C-1 参考消费者演进**：后续将 Python 参考消费者的 detail 匹配改由结构化事件枚举承载。
- **r-1 遗留字段归宿**：`dispatch_success` 字段定位为历史遗留别名，后续逐步淡出。
- **W-1 脏工作树归置**：在 Case 001 正式运行前，对 DeepAxis 历史未受控文档进行合理归置（提交或 stash），严禁销毁性处置。

### 3. Nice-to-have Items（锦上添花项）
- **NTH-1 轻量归一化脚本**：可在观察员本地编写一个单文件 Python 脚本（如 `scratch/extract_episode.py`），用于一键将两仓的 ChangeSet / Audit 日志提取并格式化为 Protocol §3 的标准 Episode YAML 片段。**此项非平台开发，非阻断项，按需自用即可。**

---

## 八、严格禁止借 L8 建平台之声明（§十八 审查）

本评估严格贯彻「**No Gap → No Code**」纪律：

- [x] 严禁设计 EHAI Analytics Platform
- [x] 严禁设计 Telemetry Platform / 遥测收集中心
- [x] 严禁设计 Unified Experiment Engine / 实验管理引擎
- [x] 严禁设计 Data Warehouse / 大数据中心
- [x] 严禁设计 Universal Event Bus / 统一事件总线

**调查员郑重声明**：Case 001 观察完全依赖现有的 `Git Commit`、`YAML 文件`、`SHA-256 审计链`、`结构化回执` 与 `轻量本地归档` 即可完整闭环，无需且禁止为此编写任何重型平台代码。

---

## 九、最终状态判定与下一步动作

依据《L8-E001 冻结后连续执行令》第二十四与二十五条：

```text
================================================================================
  当前阶段状态：PHASE 2 COMPLETED (R3 收口)
  最终判定结论：READY WITH RECOVERY PROCEDURES
  阻断缺口计数：0 项（NONE）
  受控证据落点：已确立并入库（DeepBase/evidence/L8-E001/）
  工程开发建议：NO OBSERVATION INSTRUMENTATION REQUIRED（跳过 Phase 3）
================================================================================
```

### 下一步动作建议：
1. **跳过 Phase 3**：因未发现任何 Observation Blocking Gap，无需提出亦无需开发任何最小打点工单；
2. **提请主控放行**：提请主控（Amy · 沈予安）审阅本终验收口版报告并裁定 Phase 2 正式关闭；
3. **准时启动观察**：按 Protocol §0.1 既定时间表，于 **`2026-09-17`** 正式开启 **Case 001 Observation START**。
