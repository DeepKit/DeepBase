# DeepBase 项目长期记忆

> **第8次压缩 2026-09-21 17:59（主控）。历史明细/硬锚点全文 → `MEMORY-ARCHIVE-20260920.md`（禁删；查历史读它）**。日更 → `2026-09-XX.md`。

## 一、边界
主管 EHAI 链：DeepBase/HB + AsWish（参考）+ DeepAxis/AXIS（独立）；兼 MEDIA 链独立审核（只审不开发）；兼全库审计（20260918）复核线。跨线（唤金商业/定价/传播/文学）移交 Amy。

## 二、治理铁律（永久，最高优先）
- 禁自报 PASS：门禁数字须来自日志/产物。
- 不等式四则：`Commit Claim ≤ Git Evidence`；`Regression Claim ≤ Executed Scope`；**`未提交的交付 = 未交付`**；`机读声明 ≤ 实测证据`。
- 取证：路径取 `git ls-files`/实测；file:line 锚**字面符号名**；受控状态必实测。
- **H15 原子提交**：裸 commit 会带走他人 staged（前科 `ed50cfd`/`c0592ff`）⇒ 必带 `--only`/显式 pathspec，前后各跑 `git diff --cached --name-only`。**H16**：staged 非空即停写报主控。
- **行尾三教训**：① 整文件重写级 diff 先 `--ignore-cr-at-eol` 复验（只剥**单个**尾部 CR；多重 `\r\r\r\n` 无效 → 用剥 CR 字节指纹）② **`.gitattributes` 归一化让 CRLF↔LF 在 git 层彻底隐身** ⇒ 判行尾污染必用**字节级 eol-gate** ③ **层次错配**：HEAD blob 不可直接比工作树文件（LF 层 vs CRLF 层）。
- **F3**：自述 SHA 须 `git branch -a --contains` 非空。
- 整改五件套：文件:行／改法／验收标准／证据要求／是否阻塞他仓；禁 `checkout --`/`restore`/`clean`/`reset --hard` 处置非本工单改动。
- **状态门 ≠ 争用门**：前置是**资源** ⇒ 空闲可开工；前置是**状态**（前单交付+验收）⇒ 资源空闲也**不**解锁。
- **★ 保护老板注意力**（09-20 20:42）：「得你保护我的注意力，这些小事要么你定，要么开会定，少来麻烦我」⇒ 调度/取舍/优先级**一律主控自决或召会议，不上推**；只战略/产品/跨仓/花钱才报老板。
- **★ 质量优先于记账**（09-20 20:36）：「记过有什么用，问题是开发出高质量的程序」⇒ 验收**物/序二分**：物合格即过，序有瑕记一笔即止，**不得升格为阻塞/待决**。排序按质量影响：**真安全洞 > 真缺陷 > 告警消噪**。
- **★ 质量优先，不是兼容优先**（09-19）：允许 breaking change；禁为兼容保留缺陷/加兼容层/开关/fallback。
- **★ 全库修复线 = 产品干预**（09-19）：须登记为产品干预，不得记作「纯内部优化」。
- **元规律**：引用（符号名/路径/hash/受控状态/覆盖率）持续不实 ⇒「逐条落地核验」为固定动作；**先核锚点再采信结论**。

## 三、硬锚点速查（全文 → ARCHIVE）
- **EHAI**：SSOT = `D:\_Progs\一元论\90-跨层组合\高效AI人机交互体系-EHAI\common-contract\`；符号真相源 = `docs\EHAI-Delphi-Symbol-Baseline.md`（机械生成禁手工）。`TEhaiInvolvementProfile` 5 形态 = Inform/Provide/Judge/Authorize/Act（**L1–L8 是层号不是 Profile**，L1–L8 = **FROZEN v1.0**）。覆写四态 `eokNone/CandidateReject/AlternativeExpression/FrameRejection`；fail-closed：`Covers()` 空 Scope = 无授权。
- **三仓锚点（DOWNSTREAM-001 = CLOSED，09-16）**：`Gate B / AXIS L7·Gate C`、`AsWish Gate C / Cross-Product` = PASS WITH NON-BLOCKING FINDINGS；`Common Contract = No Common Revision Needed`；上限 = `Cross-product engineering reuse evidence`，禁越线 L8；主控亲跑全绿 388 项。**⭐ `Audit Verdict is bound to Audited Git Objects`**。tag `audit/ehai-downstream-001-closed`：DeepBase `328be36`｜AsWish `0b22a52`｜DeepAxis `67034a5`。
- **L8 Case 001 = `OBSERVATION ACTIVE`**（老板 09-18）。**唯一主任务 = `Collect Real Episodes.`** Protocol `docs/ui/work-orders/L8-E001-Observation-Protocol.md`（525 行，sha256 `747079c8…0de88`，FROZEN `8f3dbf2`）。START Anchor：Protocol `747079c8`｜DeepBase `339fe4a`｜AsWish `7624a1d`｜DeepAxis `f47c573`｜F4 = `EXCLUDED until Delta Closure`。干预 `INT-20260917-01/02/03`；**跨干预禁混池**。口径：Episode 必真实；`software_commit` 不确立 ⇒ `NOT ESTABLISHED`；ID 递增；结束六步顺序；**不做阶段结论**；下一检查点 `09-30 Midpoint Integrity Review`。措辞只允许 `Observation Started`；禁进入 L8 平台/统一埋点/AI 评估系统设计。Phase 2 CLOSED；Phase 3 SKIPPED。
- **PG（受控进度台账，非 PostgreSQL）**：入口 `D:\_Progs\00Common\skills\ai-workbench-router\workbench.py`（`pg-query`/`pg-tag`，禁直接 SQL；须 `D:\ProgramData\Python313\python.exe`）。EHAI/L8/E001 全库 **0 命中**；「每日进 PG」= `HALF-OPERATIONAL`。**待老板裁定是否授权写 PG**。
- **旁线/事故**：**F4 PASS**（`12dd4da`，强类型 mock/dryrun/real + `dsEngineVerified` + `dmReal` 下 mock 时钟 fail-closed）；**DA-131B 损失**（`HJValidateAndExecuteUiaPaste` +82 行被 `checkout HEAD` 销毁且未提交 ⇒ `BASELINED` + `PERMANENT EVIDENCE GAP`，**永久禁称 `Source-level faithful restoration proven`**；未提交代码先固化 sha256）；**双轨终裁**（生产真相源 = 旧轨 `Core\DeepBase.PluginManager.pas` BPL `WinVerifyTrust` fail-closed；新轨 `DeepBase.Plugins.*` **冻结隔离**）。

## 四、20260918 全库审计复核线
- 审计本体 12 分包；主控复核：账不平、39 单元未覆盖、**编码损坏低估两个数量级**（实测 116 .pas 含 U+FFFD）、3 误判、加密栈三缺陷（CBC IV 复用 / `DeriveSalt` 确定性派生 / MacKey 单轮 HMAC）。归档 `8eb1aa3`。
- **已闭环**：甲 R1–R6 + 乙 R1–R6（乙 R6 ACCEPTED WITH CORRECTIONS `f4cc7c5`）；K6（`Schema.pas` 961 处多重 CR 归一 + 剥 CR 指纹 47,773 B 逐字节一致）。
- **行尾末态**：`i/lf` 1807 / `i/crlf` 143（142 `TestResults/**`+1 `HB.Benchmark.pas`）/ `i/mixed` 9 / `i/-text` 22；非 TestResults 纯行尾 = **0**。
- **元教训**：「同型缺陷」登记不可照信 —— 须全库机械扫描调用点 + 逐点核守卫（须作用于**目标路径**且**同执行分支**）；层次错配须自查。

## 五、Top20 闭环台账（权威进度源）
- 台账 `CodeReview/20260921-AUDIT-主控-Top20闭环台账.md`；基准 = `20260918-全库审计-总报告.md` §三；有效 **19** 条（#13 撤回）。
- **进度：✅ 17／🟠 排队 1（#08 Commerce 权益消费 → 乙）／⚠️ 保留 1（#04 Governance 端到端绕过）⇒ 17/19 = 89%**。
- 甲 R5 欠账已清（`4c7ec5a`，M1/M2 ACCEPTED WITH CORRECTIONS；缺口 A 残差 = **A-1**）。#17 已闭环（`e86d3ff`+`28ff778`，`Net.pas:2182 GetSsrfAllowFlags` 单点 SSOT + `{$IFNDEF RELEASE}`，RELEASE DCU 0/0）。
- **总教训**：`9387222` 实为 **26** 件（主控曾误记 25，甲反质疑成立 ⇒ 已自纠）。

## 六、当前态与待办（主控自决范围）
- **甲 R7 = ✅ CLOSED**：ACCEPTED（P3 = ACCEPTED WITH CORRECTIONS）。序侧：S-1 `R7-gates-run.txt` **内容级乱码**（合法 UTF-8 双重编码，门禁抓不到）；S-2 `.gitattributes` 加 `*.bpl binary`。
- **★ S-3 编译阻塞 = ✅ CLOSED**（`CodeReview/20260921-AUDIT-主控-乙-P0-验收结论.md`，**ACCEPTED**）：三 commit `a6ca329`/`1c1c862`/`2e97d11` 解 E2003/E2034/E2250/E2035；pristine HEAD 编译 **EXIT=0**、全量回归 **4617/4625**。**根因双源**：E2034/E2250/E2035 ← `9387222`（Top20#05，甲）；**E2003 ← `1a85e92`（乙 R5-N1，乙自身）**（自该 commit 起 HEAD 即不可编译，**R5 验收未含 DPR 编译门** = 过程缺口）。**⇒ 全量套件恢复可跑 + 甲 R8-P2 顺延解除**。
  - 序侧：乙 P0 报告**承接工单引用不实**（乙-R6 无 §P0，#28/#29 本仓审计线不存在）；证据 `TestResults/*.log` **未入版本控制**（gitignore）⇒ 须固化哈希/转存。
  - **存量失败**：BitmapSource 2 红**已有修复 `de8d989`**（BUG-449，`Engine.CaptureScreen` 闸门解耦），**仅 `feat/wyjx-colormatch-canary`，master 未并入**；PBT `Property6` 空指针 AV 无线索。
- **甲 R8 = 活跃**（P1 POSIX `d95b522` 已入；P3 证据链 `2fc1696`/`a82d09d`/`20493c6`/`2930fa1`/`69e9792`；**追加段 = ACCEPTED**）。**★ P2 窗口已授予甲**（2026-09-21 18:5x 裁定）：scope = `DeepBaseTests.dpr` **仅加 3 个 `uses`**（`Test.DeepBase.Security.UBS2`/`Security.MachineIdentity`/`SecureMemory`；原写「4 单元」已更正）；**验证须走隔离工作树**（共享树含乙在制品）；随后 `git rm Tests/TestSecurityM2.dpr`（**裁定 = 删**，第二次原子提交）。队列 → A-1（R8 交付前不开工）。
- **★★ 乙 P1 单新增 P0（最高优先）= 门禁 fail-open 修复**：`check_pas_encoding.js:26` / `check_eol.js:23` 的 `walk()` **吞 readdir 异常**且不校验扫描计数 ⇒ **扫 0 文件仍报「通过」EXIT=0**（主控实证：`--root` 传 POSIX 路径得 0/0 假绿；换 Windows 路径得 972/1422）。修法：任一 readdir 失败 ⇒ EXIT≠0；计数 0 ⇒ EXIT≠0；负向样本增 2 例。**主控自律**：读门禁结论必核「扫描计数 > 0 且与仓规模同量级」。
- **乙队列**：R7 剩余（C3/C4 澄清 + 归档删除口径：3 件现为**未暂存** ` D`，README ` M`）→ **P1 单**（`WO-20260921-AUDIT-乙-P1-cwd裂缝与存量失败收口.md`：cwd 裂缝 **15** 处 + **P0 门禁 fail-open** + BitmapSource 复用 `de8d989` + PBT AV）→ **P3-HB**（§九 P0 已 CLOSED）→ Top20-08 ⇒ 解锁 **#08**。
- **★ 域口径（主控 2026-09-21 18:5x 细化）**：`Tests/**` 测试件归**该单单一 owner**；`VCL/**`/`FMX/**` 生产件 + 测试件的**基准逻辑**（Gate 阈值/渲染路径/类别标记）仍甲域。⇒ 乙改 `Tests/Test.DeepBase.HB.Benchmark.pas` 的**路径解析行**已授权，无需转甲（P3-HB §三 已加交叉引用）。
- **★ 零级口径（即日生效）**：**提交段门禁判定 = 隔离 `--detach` 工作树 @ 目标 commit 的 EXIT；主树红项须逐件点名归属**（已登记为产品干预）。
- **时标纪律（新）**：**会话时钟 ≠ 受控状态**；产物时刻**只认 `git log` 实测**（我上轮「23:0x」不实，实测 `b94d98e` = 17:59:04，已全篇更正）。
- **余下 Top20**：#08 + #04。
- **现场快照（`20493c6`）**：staged = **空**；工作树脏 = `docs/规范历史版本与对比库/` 3 删除（` D`）+ README（` M`）+ 甲 R8 域 `.pas` + 甲乙未跟踪交付件（**H2，勿动**）。
