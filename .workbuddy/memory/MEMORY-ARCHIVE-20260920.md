# DeepBase 项目长期记忆

> 第六次压缩：2026-09-20 15:05。硬锚点（SHA/裁定/时间戳）不可删。

## 一、会话边界

- 主管 **EHAI 链**：DeepBase/HB + AsWish（参考产品）+ DeepAxis/AXIS（独立）；兼职 **MEDIA 链独立审核**（只审不开发）+ **全库审计（20260918）复核线**（§八）。跨线议题（唤金商业/定价/传播/文学）移交 Amy。

## 二、治理铁律

- **禁自报 PASS**：门禁数字须来自日志/产物。
- **不等式四则**：`Commit Claim ≤ Git Evidence`／`Regression Claim ≤ Executed Scope`／**`未提交的交付 = 未交付`**／`机读声明 ≤ 实测证据`。
- **取证**：路径取自 `git ls-files`/实测；file:line 锚定字面符号名；受控状态须实测；免责 ≠ 消解机读字段。
- **⚠️ diff 行尾污染**：整文件重写级 diff 先 `--ignore-cr-at-eol` 复验。**边界**：该标志只剥**单个尾部 CR**，多重 CR（`\r\r\r\r\n`）**无效**；blob `-text` 时改用**剥 CR 字节指纹**证明。
- **⚠️⚠️ H15 原子提交**：裸 `git commit` 会带走 index 中他人已 stage 内容（前科 `ed50cfd` 名义 chore(memory) 实带乙 28 件；`c0592ff` 误带甲 Registry）。**必带 `--only`/显式 pathspec；前后各跑 `git diff --cached --name-only`（双空）。**
- **H16 共享 index 并发禁令**：发现 `git diff --cached` 非空即**停写**报主控。
- **F3 自指锚点不可能性**：提交无法命名自身 ⟹ 自述 SHA 须 `git branch -a --contains` 非空。
- **整改工单五件套**：文件:行／改法／验收标准／证据要求／是否阻塞他仓。禁 `checkout --`/`restore`/`clean`/`reset --hard` 处置非本工单改动。
- **冻结纪律**：提交方声明停等；主控取证打时间戳；会写脏工作树的流水线不跑。
- **元规律**：引用（符号名/路径/hash/受控状态/覆盖率）持续不实 ⇒ 「逐条落地核验」为固定动作；先核锚点再采信结论。
- **★★ 主控自决 + 保护老板注意力（老板 2026-09-20 20:42）**：原话「得你保护我的注意力，这些小事要么你定，要么开会定，少来麻烦我」。⇒ **调度/取舍/优先级一律主控自决或召会议，不上推**；只有战略/产品/跨仓/花钱才报老板。
- **★★ 质量优先于记账（老板 2026-09-20 20:36）**：原话「记过有什么用，问题是开发出高质量的程序」。⇒ 验收**物/序二分**：物合格即过，序有瑕记一笔即止，**不得升格为阻塞/待决**。注意力按质量影响排序：**真安全洞 > 真缺陷 > 告警消噪（BOM/去重）**。

## 三、EHAI 公共层硬事实

- SSOT = `D:\_Progs\一元论\90-跨层组合\高效AI人机交互体系-EHAI\common-contract\`；符号真相源 = `docs\EHAI-Delphi-Symbol-Baseline.md`（机械生成，禁手工）。
- L4 法源 `TEhaiInvolvementProfile` 5 形态 = Inform/Provide/Judge/Authorize/Act；**L1–L8 = 层号非 Profile；EHAI L1–L8 = FROZEN v1.0**。覆写四态 `eokNone/CandidateReject/AlternativeExpression/FrameRejection`（框架否定须显式 `SubmitFreeInputWithKind(..., eokFrameRejection)`）。fail-closed：`Covers()` 空 Scope = 无授权。

## 四、三仓不可变锚点（DOWNSTREAM-001 = CLOSED，2026-09-16）

裁定：`Gate B / AXIS L7·Gate C`、`AsWish Gate C / Cross-Product` = PASS WITH NON-BLOCKING FINDINGS；`Common Contract = No Common Revision Needed`；能力上限 = `Cross-product engineering reuse evidence`，严禁越线 L8。主控亲跑全绿 388 项。产物 `CodeReview\`。

**⭐ 锚点纪律（老板，永久）**：`Audit Verdict is bound to Audited Git Objects` —— 旧 Commit = 已审计；新 Commit = 未被旧裁定覆盖。

| 仓库 | 锚定 Commit | Tag Object SHA（tag `audit/ehai-downstream-001-closed`） |
| :--- | :--- | :--- |
| DeepBase | `328be36` | `a73f088` |
| AsWish | `0b22a52` | `4a21a0b` |
| DeepAxis | `67034a5` | `70553c3` |

## 五、L8 Empirical Case 001

- 协议 `docs/ui/work-orders/L8-E001-Observation-Protocol.md`（525 行，sha256 `747079c8…0de88`）= FROZEN（`8f3dbf2`／治理件 `b518c3f`）。7 参数：Start 2026-09-17 / 28 天 → End 2026-10-14 / Midpoint 2026-09-30 / AsWish ≥20 + AXIS ≥20 / 每产品 ≥3 task types / Self-report VOLUNTARY / F4 Rule。
- **Case 001 = `OBSERVATION ACTIVE`**（老板 2026-09-18）。**唯一主任务 = `Collect Real Episodes.`** START Anchor：Protocol `747079c8`｜DeepBase `339fe4a`｜AsWish `7624a1d`｜DeepAxis `f47c573`｜F4 = `EXCLUDED until Delta Closure`。干预 `INT-20260917-01 c3215d3 / 02 3b9f135 / 03 e389cd5`（表 `L8-E001-Intervention-Registry.md`），**跨干预严禁混池**。
- 口径：Episode 必真实（禁造/禁挑漂亮案例）；`software_commit` 不确立 ⇒ `NOT ESTABLISHED`；ID 递增；结束六步顺序（禁先写结论）；**不做阶段结论**；下一检查点 `2026-09-30 Midpoint Integrity Review`。禁令：措辞只允许 `Observation Started`；禁进入 L8 平台/数据平台/统一埋点/AI 评估系统设计。Phase 2 = CLOSED（`e1b2e93`）；Phase 3 = SKIPPED。

## 六、PG（受控进度台账）

- PG 不是 PostgreSQL。入口 `D:\_Progs\00Common\skills\ai-workbench-router\workbench.py`（`pg-query`/`pg-tag`，禁直接 SQL）；须系统 python `D:\ProgramData\Python313\python.exe`。四纪律：单 Skill / BCW 任务 PG-first / 完成必留痕 / 会议优先。实测 `bcw_runtime` 53 表、`universal_tag` 2599 行，EHAI/L8/E001 全库 **0 命中**；「每日进 PG」= `HALF-OPERATIONAL`（`5f4f9ee`）。**待老板裁定是否授权写 PG**。

## 七、旁线与事故

- **F4（2026-09-16 PASS）**：代码 `12dd4da`，强类型 `dmMock/dmDryRun/dmReal/dmEngineVerification` + 终态 `dsEngineVerified` + `dmReal` 下 mock 时钟 fail-closed。
- **DA-131B 损失（2026-09-16）**：`HJValidateAndExecuteUiaPaste`（+82 行）被 `git checkout HEAD` 销毁且未提交 ⇒ `CONDITIONALLY ACCEPTED / BASELINED` + `PERMANENT EVIDENCE GAP`；**永久禁称 `Source-level faithful restoration proven`**。元教训：未提交代码先固化 sha256 再动。
- **双轨终裁（2026-09-19，`2f011fd`）**：生产唯一真相源 = **旧轨 `Core\DeepBase.PluginManager.pas`（BPL，`WinVerifyTrust` fail-closed）**；新轨 `DeepBase.Plugins.*`（6 单元 2446 行）**冻结隔离**（同名类改名活雷／禁入生产+CI BLOCK／FROZEN／灰盒／复活四门槛）。卸载加固 = 甲 A8。
- **★ 老板 2026-09-19 两项裁定（永久）**：① 全库修复线一律作**产品干预**登记，禁「纯内部优化」 ② **质量优先，不是兼容优先**：允许 breaking change，禁为兼容保留缺陷/加兼容层/开关/fallback。

## 八、20260918 全库审计复核线

- 审计本体 12 分包（声称 ~540 单元/1445 定级）。主控复核：账不平、39 单元未覆盖、**编码损坏低估两个数量级（实测 116 .pas 含 U+FFFD vs 报告 1 文件 3 处）**、3 误判、加密栈三缺陷（CBC IV 复用 / `DeriveSalt` 确定性派生 / MacKey 单轮 HMAC）。归档 `8eb1aa3`。
- 甲 R1+R2+R3 ACCEPTED（`32b0642`/`c4b96a9`）；乙 R1+R2 闭环（`4f9a747`/`7366865`）；冻结收口 `eac257e`。
- **K6（主控自单）**：`46ee3f0`（254 件）→ 结论 `5a14aae` → `f5e2d82` = **ACCEPTED WITH CORRECTIONS**。`Schema.pas` 961 处 `\r\r\r\r\n`→`\r\n` + 归正 12 裸 LF，`i/-text`→`i/lf`，**剥 CR 指纹 47,773 B 逐字节一致**；双豁免归零（`PI-K6-SCHEMA-MULTICR` + `PI-K6-E9-CONVERGENCE`）。
- **乙 R4 全项 ACCEPTED**：L1–L9（L2 无损性独立证明 `worktree.replace(CRLF→LF)==HEAD blob`=True；L6 `d33273d`/L7 `dc01026` WITH NOTE）；乙自行证伪 R3「CLI.SSH 迁移」归因（根因 = `DeepBaseTests.dproj` `DCC_UnitSearchPath` 落后）。
- **甲 R4 = ACCEPTED WITH CORRECTIONS**：`c1052a2`（56 件，raw +2034/−1209，icr +1219/−394，**815/815 纯 CR**）+ `6f39015`（5 件 +557/−0）。K6∩R4=0、零夹带、零乙域文件、3 项 PI@c1052a2。J3 223/223（与 TestResults 同源 md5）。C1 = 主控开工令名笔误（`视觉基础设计`→`视觉基础设施`、`四景`→`全景`），**追责不落甲**。
- **乙 R5 = ACCEPTED WITH CORRECTIONS**：`1a85e92`(N1 `ABackupId`→`SafeBackupId` fail-closed) / `efc40cf`(N3 证据编码门禁) / `a0bbe52`(N2 归档卫生) + 回执 `863d82d`/`ef6b68a`/`02ea82b`（六笔 raw==icr；N1 全量 4587/130/33 独立真跑；F2613/EXIT 两 log 分离证实；六遗留诚实申报）。
- **★ 甲 R5 M1–M5 = `UNLOCKED`（2026-09-20，条件 R4 落定 + K6 完成均满足）**。终审 = `CodeReview\20260920-AUDIT-主控-R4-R5-终审结论.md`（`2e1aa78`）。
- **行尾末态**：`i/lf` 1807 / `i/crlf` 143（142 `TestResults/**` + 1 `HB.Benchmark.pas`）/ `i/mixed` 9 / `i/-text` 22；非 TestResults 纯行尾 = **0**。
- **★ 已派单（2026-09-20 `ef439b4`→`e24f68a`）**：**乙 R6**（N1 G3 口径校正 7→4 / N2 `TestResults/**` 去跟踪 182 件含 142 `i/crlf` / N3 跨仓文档 2 件归位 / N4 乙域 R2E8 未跟踪 3 件归档 / N5 `nulStock` 清理 / **N6 D1–D8 去重** / **N7 `TTestBackupProgress` 测试未初始化 record 缺陷**）+ **甲 R6**（甲域 4 件补 BOM：`Gate.Verdict`·`HB.Choice.Types`·A8测试·`EHAI.Types` / 甲域 3 件 UTF-16 证据重落）。⚠️ **修正上一轮误判**：BOM **非**「乙主责整体」——乙主**门禁口径**（B1 线），甲主**文件补 BOM**（7 件中 5 件在甲域，H2 禁乙碰 `HB.*`/`UIA.*`）。甲 R6 前置 = 甲 R5 全落定后（H16）。
- **★ 老板 2026-09-20 15:12 D1–D8 四项裁定（已入乙 R6 N6）**：① EHAI 两套命名**以新名 `EHAI.0x.Lx` 为准**（新名集入库 + 修 tracked `docs/ui/00-Index.md` L1–L8 链接 + 旧名集转归档）② 两份总纲**留最新**（`EHAI.00-总纲与规范索引.md`，09-14 较新）③ 跨仓派生副本**本仓只留指路牌** ④ **授权删 7 件纯重复**（D4 `...(2).md` 1 + D5 快照重复 4 + D7 甲旧报告 2）。**铁律：EHAI 正文零改写**（`FROZEN v1.0` 契约未触）；D8 关闭（无重复）。删除规程：先报主控复核 → 仓库外备份 → 回收站。
- **★ 甲 R6 = ACCEPTED WITH CORRECTIONS（2026-09-20 20:31，`d32cf13`）**：M1 6 件补 BOM（正文逐字节零改动 6/6、`encoding-gate` 亲跑 **EXIT=0** 970 .pas）、M2 3 件日志 NUL=0、`nulStock`={}、`--all-worktree` EXIT=0。**程序偏差**：R6 在 **甲 R5 未完成（M3/M4/M5 未开始）+ 主控未发许可** 下自我开工；甲 H16 主动申报、index 全程 0（零实害）⇒ 记程序偏差，**须老板确认许可来源**；口径 = 物/序分开评，第二次出现即 REJECT。**连带发现**：① 甲 R5-M2(`9387222`) 新建 2 件无 BOM ⇒ 门禁 4→6（流程缺口，后续段须申报门禁 EXIT）② **甲 R5 以 M1/M2 收口**（M3 Net SSRF / M4 裸跑 Gate#5 / M5 BPL 卸载 → 已移交甲 R7）。 **★ 终验确认（2026-09-20 22:56，`87caa5c`）= ACCEPTED**：老板转交完整交付路径后加固复核 —— **blob 字节级 6/6**（`git cat-file` 验 `after==BOM+before`，长度差恒 +3）、**证据 sha256 6/6 逐位相等**（非伪造）、**M2 3 件独立复算吻合**（len=987/NUL=0/sha `c73373c2` 全等）、**门禁自跑 EXIT=0**（encoding 970 / evidence 99 tracked·122 all-worktree）、`PI-甲-R6-BOM-COMPILER-PARSE`（`L8-E001-Intervention-Registry.md` L47）ACTIVE、提交原子 6/1/7、老板所列 9 项交付件 100% 对应。「序」更正 1 项：回执称 `--all-worktree` **111 件** vs 证据文件 **106 件**（声明>证据，log-once，不阻塞）。
- **★ 乙 R6 = ACCEPTED WITH CORRECTIONS（2026-09-20 21:09，`f4cc7c5`）**：`494f272`(回执) / `5bd19bf`(末笔) / `dacbf85`(报告)；N1 G3 口径收窄 `033a11d`、N2 `TestResults` 去跟踪 `c966abc`、N3 跨仓归档 `2629b2c`、N4 R2E8 入库 `5208d40`、N5 `a007e57`、N6 D1–D8 `33d80b8`、N7 测试归零 `e44a81d`、**授权删 7 件 `c0772f4`**。**主控独立取证**：7 件删除路径 `git log --all` 全 0（从未 tracked，零 tracked 删，H4 成立）；7 保留件 sha256 逐位全等；仓库外备份 7 件完整；`md_crlf_exceptions` 216→210（精删 6 键，D7-1 不在基线自洽）；`backup_20260909_l1_l7/` 空 = 4 件转归档（`规范历史版本与对比库/*.快照-20260909.md`）；2 旧名顶层文件从未 tracked（D1 归档 `33d80b8`）；自跑 eol-gate **14 项** / managed-copy-gate **5 项**复现。**「序」纠正（log-once）**：回执「工作树未提交态」措辞不精确（`git diff HEAD` 空，归一化隐藏），实质正确、非乙引入。
- **★★ 老板 2026-09-20 20:42 裁定：旧锁去掉 + 立即优化 + 开新工单** ⇒ **甲 R7**（`89cbaf4`，增补 P5 见 `f4cc7c5`）= 安全质量立即优化：**P1 删三段 legacy 弱解密路径**（`Crypto.AES.pas` 的 v2 无盐单轮 / v1 确定性盐 / 无头；只留 v3，旧格式必须 `raise`，禁 fallback/开关；连带清 `SimpleCryptoMacKey`/`DeriveSalt`；负向测试；`PI-甲-R7-CRYPTO-LEGACY-REMOVAL`）/ **P2 SSRF 加固**（拒环回·私网·链路本地·元数据，协议白名单，重定向复检，默认拒绝）/ P3 M4 卡死诊断 / P4 M5 / **P5 安全链 .pas 工作树行尾归一 CRLF**（14 项 eol 违规逐项命中 `9387222` 改动集=甲域；工作树 `w/lf`/`w/mixed` 偏离 `.gitattributes` `*.pas→CRLF`，13 项无基线豁免；**禁新增豁免**，验 `--ignore-cr-at-eol` diff=0）。**甲 R5 以 M1/M2 收口，M3–M5 移交 R7**（单一活跃工单，避 H16）。新增纪律：每段提交前必跑双门禁申报 EXIT。
- **★ 元教训新增（2026-09-20）**：**`.gitattributes` 归一化会让行尾偏离在 git 层彻底隐身**（`git status`/`git diff` 均看不见 CRLF↔LF 差）⇒ 判行尾污染**必用字节级门禁（eol-gate）**，不能信 git。此与「diff 行尾污染」「H15 原子提交」并列为行尾三教训。
- **★ 已派（2026-09-20 23:02，`c987465`）**：**甲 R8**（排队单，前置 R7 交付+验收）= `WO-20260920-AUDIT-甲-R8-POSIX构建缺口与安全测试网并网`：**P1** `Crypto.OpenSSL.pas:606-607` 硬编码 `libdl.dylib` ⇒ Linux/macOS 下 `dlopen/RTLD_NOW` Undeclared，`Crypto.AES` 及依赖单元全不可编译（甲 R5 缺口 B）；**P2** `Tests/TestSecurityM2.dpr` 4 单元未并入 `Tests/DeepBaseTests.dpr`（grep 0 命中，甲 R5 缺口 D；H2 保护已授权仅加 `uses`）。**乙 R7**（立即开工）= `WO-20260920-AUDIT-乙-R7-备份路径守卫与预算外重复对收口`：**P1** `Features/DeepBase.CloudBackup.pas:1938` `TFile.Move` 无目标守卫（同名重复备份失败；全库 9 处扫描唯一真缺陷）；**P2** 乙 R6 回执 §七.3 三组预算外重复对→**授权删除**。**编排**：甲 = R7(活跃)→R8(排队)；乙 = R7(活跃)。**更正**：甲 R5 回执「同类隐患」登记 4 处，实测仅 1 处真缺陷（`HealthSignal:161`/`Guardian:304` 已带守卫、`MasterKey:142` 有 `Exists→Exit` 前置守卫且语义正确）。
- **★ 元教训新增（2026-09-20）**：**「同型缺陷」登记不可照信** —— 须全库机械扫描调用点 + 逐点核守卫，且**守卫必须作用于目标路径且同执行分支**（自动窗口判定会误判：删源 ≠ 删目标、if 分支 ≠ else 分支）。
- **★ 甲 R8 裁定（2026-09-20 23:38，`ef1b414`）**：甲领单即核验前置并**停等**（正确），主控复核成立（`CodeReview/` 无 R7 文件、`Crypto.AES.pas` 工作树==HEAD、staged 空）⇒ 裁定 **维持阻塞、走正 path**；**不启用老板 override**（主控职权内调度，不上推）。**R8 开工资格 = 三门齐备**：R7 `P1–P5` 全交付 + 主控验收结论 + **主控发开工令**。冲突面确认：R7-P1 改 `Crypto.AES` ⇄ R8-P1 需编译该单元；R7-P5 重写 14 件行尾 ⇄ R8-P1 编译面重叠 ⇒ 严格串行。
- **★ 概念新增（永久）**：**「状态门」≠「争用门」** —— 争用门（仅互斥共享资源）在资源空闲时可开工；**状态门（前置为「前单交付+验收」等状态）在资源空闲时不得解锁**。判据：前置是**资源**还是**状态**？
- **现场定格**：HEAD `ef1b414`；staged=0；脏 raw 3（含甲在途 `Core/DeepBase.Exceptions.pas` M +5）；未跟踪 27。
