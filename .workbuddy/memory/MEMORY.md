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
- **⚠️ `--ignore-cr-at-eol` 语义边界铁律（2026-09-20 K6 受控实验）**：该标志**只剥单个尾部 CR**，对 `\r\r\r\r\n` 等多重 CR **无效**（受控测试：`a\r\r\r\r\n` ↔ `a\r\n` 仍报 2/2）。⇒ 多重 CR 是**真实内容变更**，不能被该标志消解；判「纯行尾」前必须先排除多重 CR。又：blob 为 `-text`（git 判二进制）时该标志与 clean/smudge 一并失效，内容零变化须改用**剥 CR 字节指纹**证明（K6 对 Schema.pas 用此法，47,773 B 逐字节一致）。
- **⚠️ 全库扫描口径铁律**：必排除 `.tmp`/`.claude`/`.git`/构建产物，报告须声明扫描根与排除集（`.tmp\b1-backup-preapply\` 含 1073 个修复前副本，实测 19 vs 251）。全库 `.pas` 现状 = **CRLF**（约 958 生产单元）。
- **⚠️⚠️ 原子提交铁律 H15（2026-09-20，主控第二次同型失误后立）**：**裸 `git commit`（无 `--only`、无显式 pathspec）会提交 index 中他人已 stage 的全部内容**。主控 `ed50cfd` 名义 `chore(memory)`，实际带走乙的 28 个文件（29 文件 +3204/−1100）。前科 `c0592ff`（宽泛 `git add` 误带甲 Registry）。**纪律：`git commit` 必带 `--only` 或 pathspec；提交前后各跑 `git diff --cached --name-only`（前空后空）。**
- **H16 · 共享 index 并发禁令**：多 AI 共操作同一工作树时，发现 `git diff --cached` 非空（他方暂存）即**停写**，报主控排序。
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
- **2026-09-20 收口态**：K2/E8 已入库（`ed50cfd` 误带 + `832ad65` 回执）；**K6 全库 renormalize 裁定由主控串行发**（甲 R4 落定后，440 脏件全属甲）；乙 R3 = ACCEPTED WITH CORRECTIONS（`bfac426`）。
- **★ 2026-09-20 主控取证新发现（原审计 1445 项定级外）**：`Tests/Test.DeepBase.Browser.Selectors.pas` 的 HEAD blob = **UTF-16LE + U+FFFD 双重损坏**（blob 10470 = 工作树 5234×2），git 判 `i/-text`；`Core/DeepBase.Schema.pas` 报 `i/-text` 但无 NUL、size 一致、attr `text: set` ⇒ 成因待查。新开 `WO-20260920-AUDIT-乙-R4-UTF16编码损坏.md`。
- **全库行尾现状（2026-09-20 实测）**：`i/lf` 1510 / `i/crlf` 362 / `i/mixed` 49 / `i/-text` 39（其中 .pas 仅 2 件，余为 png/ico/db/log）。凡 `i/crlf`/`i/mixed` 一 `git add` 即被 clean 成 LF 产生一次性整文件重写 ⇒ **H14 行尾前置核验**（提交前 `git ls-files --eol`，必须 `--renormalize`，双数字申报）。
- **乙 R4 状态（2026-09-20 11:40 主控验证）**：L1/L2/L4/L5/L9 **ACCEPTED**（L2 无损性主控独立证明：`worktree.replace(CRLF→LF) == HEAD blob` = True，5,231 字符对齐原损坏体 5,231 NUL）；L3 诊断 ACCEPTED（修复入 K6 前置）；**L6/L7/L8 在途**（L8 未提交）。乙 6 笔 commit 零外来文件，H15 无违。
- **★ 行尾归因裁定（2026-09-20）**：「362 项纯行尾污染系冻结后触碰工作树」**证据不支持** —— 样本 blob 自 `c4b96a9` 至 HEAD 逐字节未变，且 `.gitattributes`(`4f9a747`) 为 `c4b96a9` 祖先（冻结前已生效）。真实口径 = E9 行尾立法改变脏度判定口径，内容零变化、零灭失风险。**冻结 91 M → 现 433 M 差额机制 = NOT ESTABLISHED**（不作断言）。**冻结快照只覆盖实质维度（180 项），不可作「零多余零缺失」基准；脏度申报一律实时口径 + `--ignore-cr-at-eol` 双数字。** 现场 = 433 M + 95 ??（362 纯行尾 + 71 实质）。
- **★ 乙 R4 全项验收（2026-09-20 12:20 主控）**：L1/L2/L4/L5/L8/L9 ACCEPTED；L3 诊断 ACCEPTED（修复入 K6 前置）；L6(`d33273d`)/L7(`dc01026`) ACCEPTED WITH NOTE。**L2 无损性主控独立证明**：`worktree.replace(CRLF→LF)==HEAD blob` = True，5,231 字符对齐原损坏体。乙 9 笔交付 commit **零外来文件**（H15 无违）。乙 L6 **自行证伪** R3「CLI.SSH 迁移」归因（根因 = `DeepBaseTests.dproj` `DCC_UnitSearchPath` 落后，非迁移）⇒ **乙 R5 解锁**。
- **★ 行尾归因裁定（2026-09-20，永久）**：「362 项纯行尾污染系冻结后触碰工作树」**证据不支持** —— 样本 blob 自 `c4b96a9` 至 HEAD 逐字节未变，且 `.gitattributes`(`4f9a747`) 为 `c4b96a9` 祖先。真实口径 = E9 行尾立法改变脏度判定口径（index blob CRLF vs attr LF），内容零变化、零灭失风险。**冻结 91 M → 现 435 M 差额机制 = NOT ESTABLISHED**，不得反推「某方删改」。**冻结快照只覆盖实质维度（180 项），不可作「零多余零缺失」基准；脏度申报一律实时口径 + `--ignore-cr-at-eol` 双数字。** 现场 435 = 361 纯行尾 + 74 实质；未跟踪 94。
- **★ K6 已执行完毕（2026-09-20 12:30，主控自单自执行）**：`46ee3f0`（254 件 = 251 干净集 renormalize + Schema.pas 前置修复 + 双门禁豁免归零）→ `5a14aae`（执行结论 + 干预登记 + 复现脚本）→ `f5e2d82`（WO 状态指针）。结论 = **ACCEPTED WITH CORRECTIONS**（§四 判据经证据修正，以结论 §五 为准）。**内容零变化双证**：① `git diff 71d9596 46ee3f0 --numstat --ignore-cr-at-eol` = **3 行**（251 干净集 = 0）；② Schema.pas **剥 CR 指纹**逐字节一致（47,773 B）。**Schema.pas** = 961 处 `\r\r\r\r\n`→`\r\n` **并归正 12 处裸 LF**（否则 `lf>0 ∧ crlf>0` 触发 eol-gate **L3 mixed**）；`i/-text`→`i/lf`，`4cr+LF 961→0`、`loneCR 2883→0`；**双豁免归零移除**（兑现 `PI-R4-GATE-G4G5` 约定）；登记 `PI-K6-SCHEMA-MULTICR` + `PI-K6-E9-CONVERGENCE`。
- **★ K6 后全库行尾态（2026-09-20 实测）**：`i/lf` **1807** / `i/crlf` **143**（= 142 `TestResults/**` 受控证据 + 1 `Tests/Test.DeepBase.HB.Benchmark.pas` 实质件）/ `i/mixed` **9** / `i/-text` **22**（余二进制 + 2 日志）。**非 TestResults 纯行尾 = 0（零漏网）**。脏 435 → **183**（73 实质 + 110 TestResults；非受控部分 73 ≤ 75）。eol-gate **零豁免 PASS 1397**。
- **⚠️ encoding-gate 存量红（非 K6 引入，2026-09-20 归因）**：FAIL **7 项 G3 缺 BOM**，**Schema.pas 不在违规列**。根因 = 乙-B1 `bomExceptions`(47) 口径「含中文且无 BOM」vs G3 规则「任何 `.pas` 须带 BOM」之**裂缝**；7 项实测 **HEAD 即无 BOM**（非工作树改动）。真需 BOM 3 件（`Core/DeepBase.Gate.Verdict.pas` 293 汉字 / `Core/DeepBase.HB.Choice.Types.pas` 36 / **未跟踪** `Tests/Regression/Test.Regression.A8_InFlightUnloadGate.pas` 229 = 甲 R4 待交付物）+ 非 ASCII 1 件（`EHAI.Types.pas`）+ 纯 ASCII 3 件。**K6 不得代改**（越线 + 触碰甲未跟踪交付风险）⇒ **移交乙**。
- **施工序列**：甲 R4（56 项）→ ~~主控 K6~~（**✅ 已完成**）→ 甲 R5 M ／ 乙 R5 N（含 `TestResults/**` 去跟踪 N2、encoding-gate G3 裂缝处置）。
- **★ 甲 R4 已落定（2026-09-20 12:33:43）**：`c1052a2`「甲R4 工作区收口（56 项精确提交）」，**56 文件 / 零外来**（未卷入 K6 产物、记忆、双门禁基线、`Schema.pas`），H15 无违。**主控待办 = 独立验收**（56 ↔ J2 逐条、双证据复跑、受控证据未入库、干预登记齐备）。
- **★ H16 首次活体窗口（2026-09-20 12:31:32–12:33:43）**：主控末笔 `f5e2d82`(12:29:58) 后，甲于 **12:31:32** 向共享 index 暂存 54 项（`.git/index` mtime 取证），12:33:43 提交。主控于窗口内**仅只读取证、零 index 写** ⇒ **未污染**。反证：若该窗口用裸 `git commit` 即 `ed50cfd` 同型事故。**「H15 `--only`/pathspec + H16 非空即停写」双规经实测验证有效。**
- **脏度轨迹**：435 →(K6) 183 →(甲R4) **129**（= 19 未暂存实质 + 110 `TestResults` 纯行尾）；未跟踪 94。
- **J2 计数勘误**：甲 R4 清单 52 → 实枚举 **56**（9+27+10+8+1+1）；主控自身产物同标准纠错。
- 遗留：A18 端到端 BPL 卸载测试 DEFERRED；`docs/` 下 60+ 历史未跟踪文档归档卫生债；`UNRESOLVED-RUN-001`（全量裸跑卡 HB Gate #5，甲独占区）；pg-tag 未授权。
