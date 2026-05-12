# DeepBase Governance 接入轮 — 完成任务历史

> 本文件记录 2026-05-11 起 DeepBase Governance (OCGS) 下游接入任务中**已完成**的条目。
> 活跃任务请看 `tasks.md`，修复过的 bug 请看 `bugfix.md`。

---

## Phase 0：框架层准备（盘古）

- [x] 0.1 创建 `DeepBase.Governance.Lifecycle.pas`
  - 完整装配 9 引擎（KeyResolver → DueChecker → ActionGrid → GateResolver → RouteResolver → ProjectionResolver → FeedbackResolver → ActionExecutor → OCGSRuntime）
  - 双路径 Configure：legacy（TGovernanceSetupProc，内存态）与 ConfigureEx（TGovernanceConfigSetupProc + ConfigDB 持久化）
  - 内建 PurposeSet + SteeringExporter
  - 通过 TObserveGateResolver 装饰原始 GateResolver，支持 observe / enforce 运行期切换
  - 通过 EvidenceRecorder + TEvidenceStoreSQLite 把证据写进 ConfigDB `governance_evidence_*` 表
- [x] 0.2 创建 `DeepBase.Governance.Registration.pas`
  - 对外 API `RegisterGovernance(AMode, ASetupProc)` / `RegisterGovernance(AMode, AConfigDB, ASetupProc)` 两个重载
  - `ShutdownGovernance` 幂等
  - `GovernanceRegistrar` 全局访问器（ConfigDB 模式下返回 TConfigRegistrar）
- [x] 0.4 ~~config/governance/ 模板文件集~~ **已废弃**（违反配置铁律）
  - 改为文档 `52.extend.Governance代码注册示例-governance-setup-via-code.md`
- [x] 0.5 更新 `00.quickstart.AI集成总览-ai-one-file.md`
  - 加入配置铁律（唯一外部配置文件 = `root.txt`）
  - 加入 Governance 接入章节（代码注册示例）

---

## Phase 1：DeepClip Governance 试点（盘古）

- [x] 1.1 `compile.bat` 搜索路径加入 `%BASE%\Governance`
- [x] 1.2 ~~创建 DeepClip/config/governance/ 目录~~ **已废弃**（违反铁律）
  - 所有 Gate / Action / Purpose 配置写入 `DeepClip.Bootstrap.pas`
- [x] 1.3 `RegisterDeepClipGovernance` 回调中定义 5 个 Gate
  - `clip.llm_gate`（L1，Purpose=clip_ai）
  - `clip.speech_gate`（L1，Purpose=clip_ai）
  - `clip.export_gate`（L2，Purpose=clip_manage）
  - `clip.commerce_gate`（L3，Purpose=clip_commerce，带 Permission 条件）
  - `clip.delete_gate`（L3，Purpose=clip_manage，带 State 条件）
- [x] 1.4 定义 5 个 Action + 3 个 Purpose
  - Actions: `clip.llm_chat` / `clip.speech_recognize` / `clip.export_data` / `clip.create_order` / `clip.delete_data`
  - Purposes: `clip_ai` / `clip_commerce` / `clip_manage`
- [x] 1.5 `DeepClip.Bootstrap.pas` 接入 `RegisterGovernance(gmObserve, ...)` 与 `ShutdownGovernance`
- [x] 1.7 默认 observe 模式（不阻断，只记录）
- [x] DeepClip 整体编译通过
  - `compile.bat` → `=== COMPILATION SUCCESS ===`
  - 产物 `d:\_Progs\02Business\DeepClip\bin\DeepClip.exe`（≈ 2.1 MB）

---

## Phase 4：DeepInsight Governance 接入（仙儿）

- [x] 4.1 补齐 `uses DeepBase.Persistence.Manager.FireDAC`（DPR 已加）
- [x] 4.2 补齐 Security 接入
  - API Key 走 `SaveSecret` / `LoadSecret`（DPAPI）
  - `CtrlData.ApiKeysRoleMap.inc` 存储器接入 DPAPI，保留 XOR legacy 迁移路径
  - `CtrlData.pas` 硬编码 XOR 密钥降级为 legacy migration helper
- [x] 4.3 补齐 i18n 接入（DPR 中 `InitI18n` / `SetLanguage`）
- [x] 4.4 添加 DeepBaseGovernance 搜索路径（`.dproj` 含 `..\DeepBase\Governance`）
- [x] 4.5 通过 `TConfigRegistrar` 代码注册 gates / actions / purposes
  - 持久化到 DB1 `governance_*` 表
  - **零 JSON 文件**
- [x] 4.6 定义门禁：`insight.export_data` (L3) + `insight.delete_data` (L3)
- [x] 4.7 observe 模式注册（`RegisterGovernance(gmObserve, ConfigDB, SeedInsightGovernance)`）
- [x] 4.8 dcc64 Win64 编译通过，产出 `DeepInsightApp.exe`

---

## Phase 5：DeepStory Governance 接入（仙儿）

- [x] 5.1 DeepBaseGovernance 搜索路径已加（`.dproj`）
- [x] 5.2 `TConfigRegistrar` 代码注册 → DB1 `governance_*` 表（**零 JSON 文件**）
- [x] 5.3 定义门禁
  - `story.publish_content` (L3)
  - `story.llm_generate` (L1)
  - `story.delete_project` (L3)
- [x] 5.4 `TLegacyWrap` 包装发布 / 删除操作（bridges 通过 `GovernanceLifecycle.ActionGrid` 注册）
- [x] 5.5 observe 模式注册（`RegisterGovernance(gmObserve, ConfigDB, SeedStoryGovernance)`）
- [x] 5.6 i18n 接入（DPR 使用 `L('...')` / `SvcI18N`）

---

## 文档与工作流

- [x] DeepBase docs 平铺结构整理（`xx.分类.中文-english.md`）
- [x] 删除噪声（`.deepseek/` / 知乎缓存 / `convert_to_html.py`）
- [x] `DeepFlow/` 移出到独立项目目录（不属于 DeepBase）
- [x] 16 个 Deep* 项目扫描打分（Governance 接入必要性评估）
- [x] 任务分配方案 + 给李冰 / 仙儿的详细提示词已下发
- [x] 配置铁律（唯一外部配置 = `root.txt`）贯穿所有文档

---

## Phase 1.12：DeepClip Bootstrap 切 ConfigDB-backed + DueRule 收紧（盘古）

- [x] 1.12.1 `DeepClip.Bootstrap.pas` 从 legacy `RegisterGovernance(gmObserve, TGovernanceSetupProc)` 切换到 ConfigDB-backed `RegisterGovernance(gmObserve, LConfigDB, TGovernanceConfigSetupProc)`
  - 通过 `DeepBase.Manager.DeepBase.ConfigDB as TFDConnection` 获取 DB1 连接
  - 所有 gates/actions/purposes 持久化到 `governance_*` 表
- [x] 1.12.2 DueRule 按模式分级注册
  - observe 模式：全 relaxed（RequireEvidence/Accountability/Confirm/Seal = False）
  - enforce 模式：L2 RequireEvidence+RequireAccountability=True；L3 额外 RequireConfirm=True
  - RequireSeal 始终 False（P08+ 功能）
- [x] 1.12.3 保留 JsonLogic evaluator（gckState + gckPermission）+ ActionGrid 双注册 + gate→actionKeys 手动关联
- [x] 1.12.4 Bootstrap 精简为 3 行调用（InitializeOrRaise → InitializeDB2Connection → RegisterDeepClipGovernance）
- [x] 1.12.5 主编译通过（26499 行，1.77s，COMPILATION SUCCESS）


---

## Phase 0.3：DeepBaseGovernance.dpk 独立编译验证（盘古）

- [x] `DeepBaseGovernance.dpk` 独立编译通过（105940 行，7.34s，exit code 0）
  - requires: rtl, vcl, DeepBaseCore, DeepBasePersistence
  - contains: 34 个 Governance 单元（Types → Interfaces → Model → ... → Lifecycle → Registration）
  - 验证方式：直接 dcc64 编译 dpk，搜索路径指向 Core + Persistence + Governance 源码

---

## 李冰代码 Review（盘古，2026-05-11）

- [x] DeepLLM.Governance.Registration.pas — 4 gate + 4 action + 3 purpose，observe 模式正常
- [x] DeepLLM.Governance.Bridges.pas — DoEnterGate 逻辑正确，observe 模式 always returns True
- [x] DeepShine.Governance.Registration.pas — gckState evaluator 注册（CB 联动），3 gate + 3 action + 1 purpose
- [x] 共同 gap：缺 ActionGrid 双注册 + DueRule + gate→actionKeys（observe 可用，enforce 需后续补齐）

---

## 仙儿代码 Review（盘古，2026-05-11）

- [x] DeepInsight GovernanceSeed.pas — 2 L3 gate（gckPermission + gckEvidence/gckAccountability）+ 2 action + 2 purpose
- [x] DeepStory GovernanceSeed.pas — 3 gate（L2/L3，多条件）+ 3 action + 4 purpose + 2 LegacyWrapBridge
- [x] 共同 gap：缺 evaluator 注册 + ActionGrid + DueRule + gate→actionKeys（observe 可用）

---

## 全局封版验收文档（盘古，2026-05-11）

- [x] V1 `00.quickstart.AI集成总览-ai-one-file.md` 补 enforce 切换 SOP（Section 2.6）
- [x] V2 `51.extend.Governance治理扩展-governance-integration.md` 加"验收清单"章节（Section 13）
- [x] V3 `90.history.BugFix记录-bugfix-log.md` 汇入 Governance 接入轮 4 个 bug（BUG-G001~G004）
