# 上下文交接文档 — Governance 接入轮 Round 2

> 生成时间：2026-05-11
> 上一轮完成到：Phase 1.11 + 1.8c + 1.9 全部验证通过
> 本文档供新对话的盘古（Kiro）继续工作

---

## 身份与团队

盘古（Kiro）— 系统架构师，负责 Governance 框架层 + DeepClip 试点。
李冰 — 测试工程师，负责 Assayer + DeepShine。
仙儿 — 安全专家，负责 DeepInsight + DeepStory（已标记完成）。

---

## 本轮已完成

| 项 | 状态 |
|----|------|
| tasks.md / history.md / bugfix.md 三文件对齐 | ✅ |
| Phase 1.6 Repository.DeleteClipItem 接入 EnterGate | ✅ 编译通过 |
| Phase 1.11 Bootstrap 生产级（JsonLogic evaluator + ActionGrid 双注册 + DueRule） | ✅ |
| Phase 1.8a/1.8b/1.8c Evidence 持久化验证 | ✅ governance_evidence 表写入成功 |
| Phase 1.9 enforce 模式拦截 | ✅ arsBlocked + 正确 reason |
| Phase 1.10 steering 文件导出 | ✅ .kiro/steering/governance-model.md |
| BUG-004 GateResolver AvailableActions 修复 | ✅ |
| DeepClip 主编译 | ✅ 26328 行 SUCCESS |

---

## 下一轮要做的 3 件事

### 1. DeepClip.Bootstrap 切到 ConfigDB-backed 路径（用户决策：数据库是唯一真相源）

当前 Bootstrap 用 `RegisterGovernance(gmObserve, TGovernanceSetupProc)` — legacy in-memory 路径。
需要改为 `RegisterGovernance(gmObserve, ConfigDB, TGovernanceConfigSetupProc)`。

阻塞点：DeepClip 主程序的 `DeepClipInitialize` 调用 `Mgr.InitializeOrRaise` 时，Manager 需要 ConfigDB（SQLite）。
之前 smoke 测试发现 Guardian 在新建空 DB 时报 "DB protection failed"。
解决方案：确保 DeepClip 的 root.txt 指向的目录下有一个可用的 ConfigDB（或修 Guardian 让它对新建 DB 不报错）。

已有参考：`DeepClip.Governance.Registration.pas`（src/App/ 下，hook 生成的 ConfigDB-backed 版本）可直接复用。

### 2. DueRule 收紧（盘古决策）

当前 L2/L3 actions 的 DueRule 全是 relaxed（RequireEvidence/Accountability/Confirm/Seal = False）。
我的决策：**observe 模式保持 relaxed，enforce 模式收紧为：**
- L2: RequireEvidence=True, RequireAccountability=True（需要 context 里有 user_id）
- L3: 在 L2 基础上 + RequireConfirm=True（需要 context 里有 confirmed=true）
- RequireSeal 暂不启用（封存是 P08+ 的功能）

实现方式：在 Bootstrap 的 setup proc 里根据 `GovernanceLifecycle.Mode` 判断注册哪套 DueRule。

### 3. 李冰代码 Review（Assayer + DeepShine）

已知文件：
- `02Business/Assayer/src/Assayer.Governance.Bridges.pas`（有 `DoEnterGate` 函数）
- `02Business/DeepShine/Common/Core/DeepShine.Governance.Registration.pas`（有 RegisterEvaluator 调用）
- `02Business/Assayer/tests/Win64/.kiro/steering/governance-model.md`（steering 已导出）
- `02Business/DeepShine/Tests/GovernanceSmoke/Win64/.kiro/steering/governance-model.md`（steering 已导出）

Review 要点：
- 是否注册了 JsonLogic evaluator（gckState / gckPermission）
- 是否 ActionGrid 双注册
- 是否有 DueRule（L2/L3 不能缺）
- ConfigRegistrar 是否手动补了 gate→actionKeys 关联

---

## 关键约束（必须记住）

- Delphi 13.1（Compiler 37），编译器 `d:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe`
- 配置铁律：唯一外部配置文件 = root.txt，其余走 DB1 ConfigDB
- 修改代码后必须编译通过再汇报
- 源目录（OCGS demo）不要动
- 不要动态创建控件，不要用 TEdgeBrowser

---

## 关键文件位置

| 用途 | 路径 |
|------|------|
| Governance 源码 | `02Business/DeepBase/Governance/` |
| 任务清单 | `02Business/DeepBase/docs/tasks.md` |
| Bug 记录 | `02Business/DeepBase/docs/bugfix.md` |
| 完成历史 | `02Business/DeepBase/docs/history.md` |
| DeepClip Bootstrap | `02Business/DeepClip/src/App/DeepClip.Bootstrap.pas` |
| DeepClip ConfigDB-backed 注册（hook 生成） | `02Business/DeepClip/src/App/DeepClip.Governance.Registration.pas` |
| DeepClip Repository（已接入 EnterGate） | `02Business/DeepClip/src/Storage/DeepClip.Repository.pas` |
| DeepClip 编译脚本 | `02Business/DeepClip/compile.bat` |
| Smoke 测试（legacy） | `02Business/DeepClip/tests/GovernanceSmoke/DeepClipGovernanceSmoke.dpr` |
| Smoke 测试（ConfigDB） | `02Business/DeepClip/tests/GovernanceSmoke/DeepClipGovernanceSmokeCfg.dpr` |
| 李冰 Assayer Governance | `02Business/Assayer/src/Assayer.Governance.Bridges.pas` |
| 李冰 DeepShine Governance | `02Business/DeepShine/Common/Core/DeepShine.Governance.Registration.pas` |
| 代码注册示例文档 | `02Business/DeepBase/docs/52.extend.Governance代码注册示例-governance-setup-via-code.md` |

---

## 发现的框架设计 Gap（已记录但未修复）

1. **ConfigRegistrar 不自动关联 gate→actionKeys** — 下游必须手动 `LGate.AddActionKey(...)` 否则 EnterGate 报 "No action resolved"
2. **EvidenceRecorder 异步写入** — 查询前必须调 `.Flush` 否则 rows=0
3. **enforce 模式切换需要重启** — `SetMode('enforce')` 只写 DB，不翻内存 FMode；需 Shutdown + 重新 RegisterGovernance 才生效
4. **DeepClip.exe 启动依赖 BPL 运行时** — 必须先 `call delphi-13.1.bat` 设 PATH，否则 STATUS_DLL_NOT_FOUND
5. **DeepClip Manager 初始化需要 ConfigDB** — Guardian 对新建空 DB 报 "DB protection failed"，需要先有一个可用的 ConfigDB 文件
