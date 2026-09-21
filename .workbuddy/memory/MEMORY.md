# DeepBase 项目长期记忆

> 第7次压缩 2026-09-20（主控）。**历史明细/硬锚点全文 → `MEMORY-ARCHIVE-20260920.md`（禁删；查历史读它）**。

## 一、边界
主管 EHAI 链：DeepBase/HB + AsWish（参考）+ DeepAxis/AXIS（独立）；兼 MEDIA 链独立审核（只审不开发）；兼全库审计（20260918）复核线。跨线（唤金商业/定价/传播/文学）移交 Amy。

## 二、治理铁律（永久）
- 禁自报 PASS：门禁数字须来自日志/产物。
- 不等式四则：`Commit Claim ≤ Git Evidence`；`Regression Claim ≤ Executed Scope`；**`未提交的交付 = 未交付`**；`机读声明 ≤ 实测证据`。
- 取证：路径取 `git ls-files`/实测；file:line 锚**字面符号名**；受控状态必实测；免责 ≠ 消解机读字段。
- **H15 原子提交**：裸 commit 会带走他人 staged（前科 `ed50cfd`/`c0592ff`）⇒ 必带 `--only`/显式 pathspec，前后各跑 `git diff --cached --name-only`。
- **H16**：staged 非空即停写报主控。
- **行尾三教训**：① 整文件重写级 diff 先 `--ignore-cr-at-eol` 复验（只剥**单个**尾部 CR；多重 `\r\r\r\r\n` 无效 → 用剥 CR 字节指纹）② **`.gitattributes` 归一化让 CRLF↔LF 在 git 层彻底隐身**（`git status`/`diff` 看不见）⇒ 判行尾污染必用字节级 eol-gate ③ **层次错配**：HEAD blob 不可直接比工作树文件（LF 层 vs CRLF 层）。
- **F3**：提交无法命名自身 ⇒ 自述 SHA 须 `git branch -a --contains` 非空。
- 整改五件套：文件:行／改法／验收标准／证据要求／是否阻塞他仓；禁 `checkout --`/`restore`/`clean`/`reset --hard` 处置非本工单改动。
- **状态门 ≠ 争用门**：前置是**资源** ⇒ 资源空闲可开工；前置是**状态**（前单交付+验收）⇒ 资源空闲也**不**解锁。
- **★ 保护老板注意力**（2026-09-20 20:42）：「得你保护我的注意力，这些小事要么你定，要么开会定，少来麻烦我」⇒ 调度/取舍/优先级**一律主控自决或召会议，不上推**；只战略/产品/跨仓/花钱才报老板。
- **★ 质量优先于记账**（2026-09-20 20:36）：「记过有什么用，问题是开发出高质量的程序」⇒ 验收**物/序二分**：物合格即过，序有瑕记一笔即止，**不得升格为阻塞/待决**。注意力按质量影响排序：**真安全洞 > 真缺陷 > 告警消噪（BOM/去重）**。
- **★ 质量优先，不是兼容优先**（2026-09-19）：允许 breaking change；禁为兼容保留缺陷/加兼容层/开关/fallback。
- **★ 全库修复线 = 产品干预**（2026-09-19）：一切全库修复不得记作「纯内部优化」，须登记为产品干预。
- **元规律**：引用（符号名/路径/hash/受控状态/覆盖率）持续不实 ⇒「逐条落地核验」为固定动作；先核锚点再采信结论。

## 三、EHAI 硬事实
- SSOT = `D:\_Progs\一元论\90-跨层组合\高效AI人机交互体系-EHAI\common-contract\`；符号真相源 = `docs\EHAI-Delphi-Symbol-Baseline.md`（机械生成，禁手工）。
- `TEhaiInvolvementProfile` 5 形态 = Inform/Provide/Judge/Authorize/Act；**L1–L8 是层号不是 Profile**；EHAI L1–L8 = **FROZEN v1.0**（正文零改写）。
- 覆写四态 `eokNone/CandidateReject/AlternativeExpression/FrameRejection`（框架否定须显式 `SubmitFreeInputWithKind(..., eokFrameRejection)`）；fail-closed：`Covers()` 空 Scope = 无授权。

## 四、三仓不可变锚点（DOWNSTREAM-001 = CLOSED，2026-09-16）
裁定：`Gate B / AXIS L7·Gate C`、`AsWish Gate C / Cross-Product` = PASS WITH NON-BLOCKING FINDINGS；`Common Contract = No Common Revision Needed`；能力上限 = `Cross-product engineering reuse evidence`，严禁越线 L8。主控亲跑全绿 388 项。产物 `CodeReview\`。
**⭐ `Audit Verdict is bound to Audited Git Objects`**（旧 Commit=已审计；新 Commit=未被旧裁定覆盖）。
tag `audit/ehai-downstream-001-closed`：DeepBase `328be36`（tag `a73f088`）｜AsWish `0b22a52`（`4a21a0b`）｜DeepAxis `67034a5`（`70553c3`）。

## 五、L8 Empirical Case 001
- 协议 `docs/ui/work-orders/L8-E001-Observation-Protocol.md`（525 行，sha256 `747079c8…0de88`）= FROZEN（`8f3dbf2`／治理件 `b518c3f`）。7 参数：Start 2026-09-17 / 28 天 → End 2026-10-14 / Midpoint 2026-09-30 / AsWish ≥20 + AXIS ≥20 / 每产品 ≥3 task types / Self-report VOLUNTARY / F4 Rule。
- **Case 001 = `OBSERVATION ACTIVE`**（老板 2026-09-18）。**唯一主任务 = `Collect Real Episodes.`** START Anchor：Protocol `747079c8`｜DeepBase `339fe4a`｜AsWish `7624a1d`｜DeepAxis `f47c573`｜F4 = `EXCLUDED until Delta Closure`。干预 `INT-20260917-01 c3215d3 / 02 3b9f135 / 03 e389cd5`（`L8-E001-Intervention-Registry.md`）；**跨干预严禁混池**。
- 口径：Episode 必真实（禁造/禁挑漂亮案例）；`software_commit` 不确立 ⇒ `NOT ESTABLISHED`；ID 递增；结束六步顺序（禁先写结论）；**不做阶段结论**；下一检查点 `2026-09-30 Midpoint Integrity Review`。措辞只允许 `Observation Started`；禁进入 L8 平台/数据平台/统一埋点/AI 评估系统设计。Phase 2 = CLOSED（`e1b2e93`）；Phase 3 = SKIPPED。

## 六、PG（受控进度台账，非 PostgreSQL）
- 入口 `D:\_Progs\00Common\skills\ai-workbench-router\workbench.py`（`pg-query`/`pg-tag`，禁直接 SQL）；须系统 python `D:\ProgramData\Python313\python.exe`。四纪律：单 Skill / BCW 任务 PG-first / 完成必留痕 / 会议优先。实测 `bcw_runtime` 53 表、`universal_tag` 2599 行，EHAI/L8/E001 全库 **0 命中**；「每日进 PG」= `HALF-OPERATIONAL`（`5f4f9ee`）。**待老板裁定是否授权写 PG**。

## 七、旁线与事故
- **F4（2026-09-16 PASS）**：代码 `12dd4da`；强类型 `dmMock/dmDryRun/dmReal/dmEngineVerification` + 终态 `dsEngineVerified` + `dmReal` 下 mock 时钟 fail-closed。
- **DA-131B 损失（2026-09-16）**：`HJValidateAndExecuteUiaPaste`（+82 行）被 `git checkout HEAD` 销毁且未提交 ⇒ `CONDITIONALLY ACCEPTED / BASELINED` + `PERMANENT EVIDENCE GAP`；**永久禁称 `Source-level faithful restoration proven`**。元教训：未提交代码先固化 sha256 再动。
- **双轨终裁（2026-09-19 `2f011fd`）**：生产唯一真相源 = **旧轨 `Core\DeepBase.PluginManager.pas`（BPL，`WinVerifyTrust` fail-closed）**；新轨 `DeepBase.Plugins.*`（6 单元 2446 行）**冻结隔离**（同名类改名活雷／禁入生产+CI BLOCK／FROZEN／灰盒／复活四门槛）。卸载加固 = 甲 A8。

## 八、20260918 全库审计复核线（明细 → ARCHIVE）
- 审计本体 12 分包（声称 ~540 单元/1445 定级）。主控复核：账不平、39 单元未覆盖、**编码损坏低估两个数量级**（实测 116 .pas 含 U+FFFD vs 报告 1 文件 3 处）、3 误判、加密栈三缺陷（CBC IV 复用 / `DeriveSalt` 确定性派生 / MacKey 单轮 HMAC）。归档 `8eb1aa3`。
- **已闭环**：甲 R1–R6（`32b0642`/`c4b96a9`；`c1052a2`+`6f39015`；R6 ACCEPTED `d32cf13`/`87caa5c`）；乙 R1–R6（`4f9a747`/`7366865`；`1a85e92`/`efc40cf`/`a0bbe52`；R6 ACCEPTED WITH CORRECTIONS `f4cc7c5`，授权删 7 件纯重复 `c0772f4`）；K6（`46ee3f0`/`5a14aae`/`f5e2d82`，`Schema.pas` 961 处多重 CR 归一 + 剥 CR 指纹 47,773 B 逐字节一致）。
- **行尾末态**：`i/lf` 1807 / `i/crlf` 143（142 `TestResults/**` + 1 `HB.Benchmark.pas`）/ `i/mixed` 9 / `i/-text` 22；非 TestResults 纯行尾 = **0**。
- **★ 现场定格（取数时 HEAD `4060630`，2026-09-20/21）**：staged = 乙 R7 的 3 件删除（`D `，主控未取，H15 安全）；脏 raw 3。
  - **甲 R7**（`89cbaf4` + P5 `f4cc7c5`）= 安全质量立即优化：**P1** 删三段 legacy 弱解密（`Crypto.AES.pas`：v2 无盐单轮 / v1 确定性盐 / 无头；只留 v3，旧格式 `raise`，禁 fallback/开关；连带清 `SimpleCryptoMacKey`/`DeriveSalt`；负向测试；`PI-甲-R7-CRYPTO-LEGACY-REMOVAL`）/ **P2** SSRF 加固 / **P3** M4 卡死诊断 / **P4** M5 / **P5** 安全链 .pas 工作树行尾归一 CRLF（14 项 eol 违规=甲域 `9387222` 改动集，13 项无 baseline 豁免；**禁新增豁免**，验 `--ignore-cr-at-eol` diff=0）。**状态：在途未交付**。
    - **★ P5 现况（2026-09-21 10:0x，`a77c436`）**：主控复跑 eol-gate = **EXIT=0 / 1419 件**；14 件全 `i/lf w/crlf eol=crlf`、diff 均 0、基线四键 `667/25/210/0` 未变 ⇒ **「物」已达标**；但 14 件 mtime **全为 `09:56:22`**（一次批量动作，落在主控乙 R7 结论文档落盘后 20 秒）、**无 commit 内容** ⇒ **无交付证据、归因不明** ⇒ P5 交付改判为「申报是否本方执行 + 三件套证据」。**永久纪律**：工作树字节态类工单**天生无 commit 内容**（`.gitattributes` 归一化 ⇒ diff 恒空）⇒ 验收基准 = **工作树字节 + 门禁 EXIT + 豁免基线计数**，非 commit diff；**非本方动作不得记为本方交付**（技能 `main-control-independent-audit` §33）。
  - **甲 R8**（`c987465`/`ef1b414`，排队）= **P1** `Crypto.OpenSSL.pas:606-607` 硬编码 `libdl.dylib` ⇒ Linux/macOS `dlopen/RTLD_NOW` Undeclared（甲 R5 缺口 B）；**P2** `Tests/TestSecurityM2.dpr` 4 单元未并入 `DeepBaseTests.dpr`（H2 保护，仅授权加 `uses`）。**裁定：维持阻塞（状态门），走正 path，不开老板 override**；开工资格 = R7 P1–P5 全交付 + 主控验收 + 主控发开工令。
  - **乙 R7**（`c987465`）= **P1** `CloudBackup.pas:1938` `TFile.Move` 目标守卫（同名重复备份失败；全库 9 处扫描唯一真缺陷）；**P2** 三组预算外重复对授权删除。**主控验收 = ACCEPTED WITH CORRECTIONS（`4060630`）**：P1 物合格（`GetBackupArchivePath`+删后移+`GenerateBackupId` protected/virtual+`EBackupInvalidIdException`）、P2 三组真重复零损失（HEAD blob 逐位相等）；未提交，改动留工作区。**C1–C4 待乙补**：C1 P1 测试证据落盘（硬）/ C2 index 口径（3 删除件是 **staged** 非工作区）/ C3 时间 00:20 vs 04:05 / C4 基线 `0c1b00b` vs `ef1b414`。
  - **元教训**：①「同型缺陷」登记不可照信 —— 须全库机械扫描调用点 + 逐点核守卫（守卫须作用于**目标路径**且**同执行分支**）② 层次错配自查（主控曾拿 HEAD blob 比工作树文件误判乙，已自纠）。

## 九、Top20 闭环台账（权威进度源）
- **台账**：`CodeReview/20260921-AUDIT-主控-Top20闭环台账.md`（`a4034e8`）。基准 = `20260918-全库审计-总报告.md` §三 Top20；有效 **19** 条（#13 已撤回）。
- **进度（2026-09-21 11:3x 实测）**：✅ 已闭环 **16**（#01 #02 #03 #05 #06 #07 #09 #10 #11 #12 #14 #15 #16 #18 #19 #20）／🟡 在途 **1**（#17 甲 R7-P2 已提交 `e86d3ff`，R7 整体未交付）／🟠 已派单排队 **1**（#08 Commerce 权益消费，资金类 → **乙**）／⚠️ 部分保留 **1**（#04 Governance 端到端绕过）。
- ⇒ **16/19 = 84% 闭环**。
- **★ 甲 R5 欠账已清（`4c7ec5a`）**：出《甲 R5 验收结论》= **M1/M2 均 ACCEPTED WITH CORRECTIONS**（M1 `1a6807b` / M2 `9387222`，raw==icr、域边界 0、153/153 + 86/86 + 迁移 4/4 真跑、NUL=0、RELEASE 无豁免）；缺口 A（`master.key` 丢失）= **APPROVED** + 残差 **A-1**（须补显式导出/备份入口）；序侧 **C1–C6** 随甲 R7 回执闭环，其中 **C1（回执称证据 6 件、实测 4 件，`05/06` 全库不存在）为硬项**。
- **★ #17 未消解项**：`Net.pas:2183/2184`、`:2208/2209` 仍运行期读进程级 env `DeepBase_ALLOW_PRIVATE_NET_HTTP`/`DeepBase_ALLOW_LOCALHOST_HTTP`（默认拒绝，非漏洞，但属全局 fail-open 开关，悖 H8）⇒ 已预置甲 R7 工单 §八 验收要点：**按 M1 同款包进 `{$IFNDEF RELEASE}`**（推荐）/ 收窄 per-call / 书面申请保留。

## 十、待办（主控自决范围）
- **甲 R7**（P1 `8d2154f` / P2 `e86d3ff` 已提交；**P3 已交付并裁定**；P4/P5 待交）交付 → 主控验收 → 解阻甲 R8；验收须含 **P2 env 关闸要点**，并把 **甲 R5 C1–C6 + 残差 A-1** 一并闭环。
- **甲 R7-P3 已裁定 = ACCEPTED WITH CORRECTIONS**（`20260921-AUDIT-主控-甲-R7-P3-验收结论.md`）：排除性结论「非死锁/非句柄/非污染」经主控**独立复跑证实**；**根因更正** —— 真长尾是 **Gate6（2×1万实例 >5min 未完）**，非甲所锁的 Gate5；Gate5 为**阈值噪声翻转**（14.248 PASS vs 19.808 FAIL）；Gate1 原 FAIL 系**并发争用**（隔离 PASS 476ms）。**路径裁定 D（分离+串行独占），否决 A/B/C**。**不返工**。**★ P3 修复已改派乙**（老板 14:2x 指定）：工单 `WO-20260921-AUDIT-P3-HB性能门禁分离与Gate5修复-乙.md`（单一 owner；甲 §十 P6 改指针）。**域要点**：`Test.DeepBase.HB.Benchmark.pas` = **VCL ⇒ 甲域**（乙主责门禁分离；改该测试源码须经主控转甲）；`Tests/DeepBaseTests.dpr` 受 H2 保护；既有 `WO-20260905-003-HB-GATE5-RESIZE-FIX`（甲）明文**禁调阈值**。
- **乙队列**：R7（活跃，C1–C4 待补）→ **P3-HB门禁（插队）** → Top20-08。乙 R7 提交（建议 P1/P2 两笔原子提交）→ 主控复验转常 ⇒ **解锁 #08（Top20-08 Commerce 权益消费，资金类）开工**。
- **#17** 待甲 R7 整体交付后判闭环（届时进度 17/19）。
- **#04**（Governance 端到端绕过）按报告原文「逐路径举证后保留」，维持观察。
