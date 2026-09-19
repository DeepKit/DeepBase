# DeepBase 项目长期记忆

> 第五次压缩：2026-09-19 21:56。硬锚点（SHA/裁定/时间戳）不可删。

## 一、会话边界

- 本会话只管 **EHAI 链**：DeepBase/HB（公共层）+ AsWish（参考产品）+ DeepAxis/AXIS（独立产品）。兼职 **MEDIA 链主控独立审核**（只审不开发）。2026-09-19 起新增 **全库审计（20260918）复核线**（§八）。
- 跨线议题（唤金商业定位/定价/传播/文学）一律婉拒移交 Amy 会话。既定工单链内的跨线工程依赖按接口契约正常做。

## 二、治理铁律（最高复用价值）

- **禁自报 PASS**：门禁数字必须来自日志/产物（G3）。
- **不等式四则**：① `Commit Claim ≤ Git Evidence` ② `Regression Claim ≤ Executed Test Scope` ③ **`未提交的交付 = 未交付`** ④ `Machine-readable Reality Claim ≤ Real-world Evidence`。
- **取证纪律**：路径取自 `git ls-files`/实测；file:line **锚定字面符号名**；受控状态须实测；免责声明 ≠ 消解误导机读字段。
- **⚠️ diff 行尾污染铁律**：工作副本 CRLF 而 blob LF 时，`git diff --numstat` 造整文件重写级假阳性（实测 UIA.Engine 虚高 +545/−514，真实 +44/−13）。**凡 diff 呈整文件重写，先 `--ignore-cr-at-eol`/`--ignore-all-space` 复验再定性**。主控与开发方同标准。
- **⚠️ 全库扫描口径铁律**：必排除 `.tmp`/`.claude`/`.git`/构建产物，报告须声明扫描根与排除集（`.tmp\b1-backup-preapply\` 含 1073 个修复前副本，实测 19 vs 251）。全库 `.pas` 现状 = **CRLF**（约 958 生产单元）。
- **自指锚点不可能性（F3）**：提交无法命名自身 ⇒ 报告自述 HEAD 永远写不准。自述 SHA 须 `git branch -a --contains` 非空。
- **整改工单五件套**：文件:行／改法／验收标准／证据要求／是否阻塞他仓。硬约束：禁 `git checkout --`/`restore`/`clean`/`reset --hard` 处置非本工单改动；脏区分三类（纯噪声／未提交的历史已过审交付不可销毁／本工单改动）。
- **冻结纪律**：开工单要求提交方声明停等；主控取证打时间戳；会写脏工作树的流水线不跑。
- **元规律（六次复现）**：凡涉**引用**（符号名/路径/hash/受控状态/覆盖率）持续不实；数字账目经点名后迅速做平 ⇒ 「引用逐条落地核验」为固定动作。**审计类报告先核锚点再采信结论。**

## 三、EHAI 公共层硬事实

- SSOT = `D:\_Progs\一元论\90-跨层组合\高效AI人机交互体系-EHAI\common-contract\`；符号真相源 = `docs\EHAI-Delphi-Symbol-Baseline.md`（脚本机械生成，禁手工维护）。
- L4 法源 `TEhaiInvolvementProfile` 5 形态 = Inform/Provide/Judge/Authorize/Act；**L1–L8 = 层号非 Profile；EHAI L1–L8 = FROZEN v1.0**。
- 覆写四态 `eokNone/CandidateReject/AlternativeExpression/FrameRejection`；框架否定须显式 `SubmitFreeInputWithKind(..., eokFrameRejection)`。
- fail-closed：`Covers()` 空 Scope = 无授权；Boundary/PackageId 空不得跳过核验。

## 四、三仓不可变锚点（DOWNSTREAM-001 = CLOSED，2026-09-16 终裁）

裁定：`Gate B / AXIS L7·Gate C`、`AsWish Gate C / Cross-Product` = PASS WITH NON-BLOCKING FINDINGS；`Common Contract = No Common Revision Needed`。能力上限 = `Cross-product engineering reuse evidence`，严禁越线 L8。

**⭐ 锚点纪律（老板，永久）**：`Audit Verdict is bound to Audited Git Objects` —— 旧 Commit = 已审计；新 Commit = 未被旧裁定覆盖。已废止「有效期至下一次 HEAD 变更」。

| 仓库 | 锚定 Commit | Tag Object SHA（tag `audit/ehai-downstream-001-closed`） |
| :--- | :--- | :--- |
| DeepBase | `328be36` | `a73f088` |
| AsWish | `0b22a52` | `4a21a0b` |
| DeepAxis | `67034a5` | `70553c3` |

主控亲跑全绿 388 项。产物目录 `CodeReview\`，命名 `${日期}-${WO号}-{scope}复审结论.md`。

## 五、L8 Empirical Case 001

- 协议 `docs/ui/work-orders/L8-E001-Observation-Protocol.md`（525 行，sha256 `747079c8…0de88`）= FROZEN。Freeze `8f3dbf2`，治理件 `b518c3f`。
- 7 参数：Start 2026-09-17 / 28 天 → End 2026-10-14 / Midpoint 2026-09-30 / 样本 AsWish ≥20 + AXIS ≥20 / 每产品 ≥3 task types / Self-report VOLUNTARY / F4 Rule。
- **Case 001 = `OBSERVATION ACTIVE`**（老板 2026-09-18 确认）。**唯一主任务 = `Collect Real Episodes.`**
  - START Anchor：Protocol `747079c8`｜DeepBase `339fe4a`｜AsWish `7624a1d`｜DeepAxis `f47c573`｜Evidence `evidence/L8-E001/`｜F4 = `EXCLUDED until Delta Closure`。
  - 十项口径要点：Episode 必须真实（禁造/禁挑漂亮案例）；`software_commit` 无法确立 ⇒ `NOT ESTABLISHED`；ID `L8-E001-ASWISH-0001`/`AXIS-0001` 递增；结束六步顺序（禁先写结论）；**不做阶段结论**；下检查点 `2026-09-30 Midpoint Integrity Review`。
  - 干预登记 `INT-20260917-01 c3215d3 / 02 3b9f135 / 03 e389cd5`，表 `L8-E001-Intervention-Registry.md`。**跨干预严禁混池**。
  - 禁令：措辞只允许 `Observation Started`；禁进入 L8 平台/数据平台/统一埋点/AI 评估系统设计。
- Phase 2 = CLOSED（`e1b2e93`）；Phase 3 = SKIPPED（No Gap → No Code）。N-5 DeepAxis HEAD 漂移纳入元观察。

## 六、PG（受控进度台账）

- PG 不是 PostgreSQL。入口 `D:\_Progs\00Common\skills\ai-workbench-router\workbench.py`（`pg-query`/`pg-tag`，禁直接 SQL）。须系统 python `D:\ProgramData\Python313\python.exe`。
- 四条纪律：单 Skill / BCW 任务 PG-first / 完成必须留痕 / 会议优先。
- 实测 `bcw_runtime` 53 表、`universal_tag` 2599 行，**EHAI/L8/E001 全库 0 命中**。「每日进 PG」现状 = `HALF-OPERATIONAL`（结论 `5f4f9ee`）。
- **待老板裁定**：是否授权写 PG（未授权 ⇒ 审计线跳过 pg-tag）。

## 七、旁线与事故

- **F4（2026-09-16 PASS）**：代码 `12dd4da`，强类型 `dmMock/dmDryRun/dmReal/dmEngineVerification` + 终态 `dsEngineVerified` + `dmReal` 下 mock 时钟 fail-closed。历史缺陷样本登记 `INVALID AS REAL-FLIGHT EVIDENCE`。
- **DA-131B 损失事件（2026-09-16）**：`HJValidateAndExecuteUiaPaste`（+82 行）被 `git checkout HEAD` 销毁，从未提交不可恢复。终局 `CONDITIONALLY ACCEPTED / BASELINED` + `PERMANENT EVIDENCE GAP`；永久禁止声称 `Source-level faithful restoration proven`。**元教训：审计结论须带取证时间戳；未提交代码先固化 sha256 再动。**
- **双轨终裁（2026-09-19，`2f011fd`）**：生产唯一真相源 = **旧轨 `Core\DeepBase.PluginManager.pas`（BPL，在 dpk 内，验签 `WinVerifyTrust` fail-closed）**；新轨 `DeepBase.Plugins.*`（6 单元 2446 行）**冻结隔离**，受 C1–C5（C1 同名类改名活雷 / C2 禁入生产+CI BLOCK / C3 FROZEN / C4 灰盒 / C5 复活四门槛）。**旧轨不豁免**，卸载加固 = 甲 A8。
- **老板 2026-09-19 两项裁定（永久）**：① 全库修复线一律作**产品干预**登记，禁包装成"纯内部优化" ② **质量优先，不是兼容优先**，允许 breaking change，禁为兼容保留缺陷/加兼容层/开关/fallback。

## 八、20260918 全库审计复核线（2026-09-19）

- 审计本体 12 分包 + 总报告（声称 ~540 单元/1445 定级）。主控复核：数字账不平（1500 vs 1445）、39 单元未覆盖、**编码损坏被低估两个数量级（实测 116 个 .pas 含 U+FFFD vs 报告 1 文件 3 处）**、3 处误判（Manifest.Verifier:205-232 实为 fail-closed；CDP:905-1011 已有 REVIEW5-FEAT-009 缓解；EHAI `CreateExplicit` 属契约约定）、加密栈三缺陷（CBC IV 复用 / `DeriveSalt` 盐由密码确定性派生 / MacKey 单轮 HMAC）。
- 归档 `8eb1aa3`（38 文件，未改源码）。甲单 A1–A8、乙单 B1–B5。
- **甲线 R1+R2+R3 全 ACCEPTED**（`32b0642` 交付，`c4b96a9` 结论）；**乙线 R1+R2 闭环**（`4f9a747` 交付，`7366865` 结论 PASS）。
- **★ 2026-09-19 21:56 主控发现：HEAD `c4b96a9` 后工作区仍有 180 项脏（91 修改 + 89 未跟踪），实质 85 文件 / +4041 −2466 ⇒ 未交付。** 已冻结快照 `CodeReview\_audit_recheck\20260919-工作区冻结快照\`，登记 `20260919-AUDIT-甲乙-工作区冻结与收口登记.md`（commit `eac257e`）。
  - 甲组 52 项 → `WO-20260919-AUDIT-甲-R4-工作区收口提交.md`；乙组 26 项 → `WO-20260919-AUDIT-乙-R3-工作区收口提交.md`（均为收口单：申报→精确提交→双证据复跑→干预登记）。
  - 归属待申报：`Examples/MicroserviceClientDemo/DeepBase.Microservice.Client.pas`、`Tests/Regression/Test.Regression.A8_InFlightUnloadGate.pas`。
- 遗留：A18 端到端 BPL 卸载测试 DEFERRED；`docs/` 下 60+ 历史未跟踪文档归档卫生债。
