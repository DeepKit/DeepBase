# L8-E001 Intervention Registry
## Case 001 观察期工程干预与代码变更登记表

- **所属协议**：`L8-E001 Observation Protocol v1` (§5.5, §23)
- **管理方式**：轻量级结构化文档（不建任何平台软件，手工维护）
- **维护人**：观察员 / 调查员
- **核心纪律**：任何影响人机交互或系统行为的代码更新、配置更新或模型切换必须即时登记。数据按生效时间（Effective Time）严格切分为 `Before Intervention` / `After Intervention` 两个独立统计池，**严禁混池计算**。

---

## 一、干预事件登记表（Intervention Events）

| Intervention ID | Target Repo | Commit SHA | Effective Time (UTC+8) | Reason | Affected Behavior | Expected Effect | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :---: |
| **INT-20260916-01** | `DeepAxis` | `12dd4da9eb8ef8b1c165e8e35e6d3d26079f0a21` | 2026-09-16 16:56:12 | F4 机器语义失真定点整改 | 修正回执机器模式为 `engine-verification`，拦截仿真时钟跨入真实路径 | 彻底杜绝仿真冒充真实交付，消除语义失真 | **ACTIVE** |
| **INT-20260917-01** | `DeepAxis` | `c3215d3` (DataStore 搬迁收尾) | 2026-09-17 18:29:55 | DA-136 收尾：DataStore 搬迁 + 测试动态锚定恢复 159/159 | 数据存储位置变更，测试由硬编码 ID 改为动态锚定 | 消除硬编码 ID 失效，稳定数据存储基座 | **ACTIVE**（START 后）|
| **INT-20260917-02** | `DeepAxis` | `3b9f135` (明文库消费通路) | 2026-09-17 18:52:33 | DA-137-T1：`DecryptedDataPath` 直接消费外部明文 SQLite | **数据通路变更**：由原路径改为直接消费外部明文库 | 打通明文库消费通路 | **ACTIVE**（START 后）|
| **INT-20260917-03** | `DeepAxis` | `e389cd5` (hook 取钥移植) | 2026-09-17 18:52:51 | DA-137-T2：hook 取钥移植 + Profile 门禁 + 版本自检 | **执行行为/门禁变更**：取钥方式改为 hook，新增 Profile 门禁与版本自检 | 提升取钥合规性与版本一致性 | **ACTIVE**（START 后）|
| **PI-UPD-FAILCLOSED** | `DeepBase` | `bff202b` | 2026-09-19 03:42 | A6 TGateVerdict 立法 | 验签失败/缺签名/未知算法→拒绝（原 fail-open） | AsWish/DeepAxis: 未配置公钥时更新将失败而非静默放行 | **ACTIVE** |
| **PI-GOV-FAILCLOSED** | `DeepBase` | `bff202b` | 2026-09-19 03:42 | A6 TGateVerdict Governance | 权限裁决缺失→拒绝（原默认放行） | Governance 行为变更，L8可观察 | **ACTIVE** |
| **PI-CRYPTO-IV** | `DeepBase` | `bff202b` | 2026-09-19 03:42 | A4 CBC 随机 IV | EncryptPackage 输出格式变（IV 前缀） | AsWish/DeepAxis: 旧 CBC 密文不可用新代码解密（生产仅用 GCM，无实际落盘数据） | **ACTIVE** |
| **PI-UIA-GATE** | `DeepBase` | `bff202b` | 2026-09-19 03:42 | A6 UIA fail-closed | 屏幕映射未注册签名→拒绝 | DeepBase 内部，影响 HB 视觉系统 | **ACTIVE** |
| **PI-PLUGIN-DRAIN** | `DeepBase` | `bff202b` | 2026-09-19 03:42 | A8 在途计数 | 卸载等待在途调用完成（≤5s）超时拒绝 | AsWish/DeepAxis: 插件卸载可能延迟最多 5s | **ACTIVE** |
| **PI-E4-LLMBACKOFF** | `DeepBase` | `ed50cfd` | 2026-09-19 23:32 | E4 LLMResilience 指数退避+抖动 | 重试间隔由固定→随机指数退避 | LLM 调用重试时序行为变，可观察 | **ACTIVE** |
| **PI-E6-TIMEOUT-API** | `DeepBase` | `ed50cfd` | 2026-09-19 23:32 | E6 Resilience.Timeout 死代码清除 | TTimeoutLock 类删除，调用方编译报错（原无实现） | API 缩减，无运行时行为变（死代码） | **ACTIVE** |
| **PI-E7-CLOUDSYNC-TIMEOUT** | `DeepBase` | `ed50cfd` | 2026-09-19 23:32 | E7 CloudSync 显式超时+重试 | 网络同步请求新增 30s 超时+2次重试 | 同步等待行为变：原来无限等→30s超时 | **ACTIVE** |
| **PI-E8-LLMCHAT-GUARD** | `DeepBase` | `ed50cfd` | 2026-09-19 23:32 | E8 FMX/VCL LLMChatFrame 回调守卫 | 防回调重入：快速连发请求时仅首次响应 | UI 响应行为变（丢弃后续回调） | **ACTIVE** |
| **PI-B1-B5-GOVERNANCE** | `DeepBase` | `ed50cfd` | 2026-09-19 23:32 | B1-B5 Governance/Browser | 配置注册/动作审核/审查队列/缓存接线 | Governance 执行路径变更，可观察 | **ACTIVE** |
| **PI-R4-SELECTORS-UTF16FIX** | `DeepBase` | `3e72786` | 2026-09-20 10:40 | 乙R4-L2 UTF-16 损坏 blob 替换 | `Tests/Test.DeepBase.Browser.Selectors.pas` HEAD blob 由 UTF-16LE+U+FFFD 双重损坏体替换为 UTF-8 修复版（逐字符无损重建验证，`-text`→`i/lf`，EOL 立法恢复） | 该文件恢复 diff/renormalize 能力；K6 排除集 .pas 由 2 件收敛为 1 件 | **ACTIVE** |
| **PI-R4-GATE-G4G5** | `DeepBase` | `b307896` | 2026-09-20 10:55 | 乙R4-L4 编码门禁扩展 | `check_pas_encoding.js` 新增 G4（.pas 禁 NUL/UTF-16/32 BOM，零基线）与 G5（.pas 禁孤立 CR，存量豁免 `Core/DeepBase.Schema.pas`=2,883 待归属裁定后移除）；负向样本 5 类全覆盖 | 阻断 UTF-16/-text 类缺陷再次入库；Schema.pas 暂由基线豁免，不改变其现有行为 | **ACTIVE** |
| **PI-K6-SCHEMA-MULTICR** | `DeepBase` | `46ee3f0` | 2026-09-20 12:26:54 | 主控 K6-全库行尾收敛前置修复：`Core/DeepBase.Schema.pas` 961 行 `\r\r\r\r\n`→`\r\n`，并归正 12 处裸 LF（该件 blob 原 `-text`，EOL 立法与 clean/smudge 对其失效） | **行尾归一**：该件由「多重 CR」态归正为纯 CRLF；blob 由 `-text` 转 `i/lf`。Delphi 逐 CR 计行号，修复前 961 行行号错位，修复后行号与物理行一致 | 消除 Delphi 行号错位；**实现 PI-R4-GATE-G4G5 所述「待归属裁定后移除」之约定**——`eol_baseline.json` `pas_multicr_exceptions` 与 `pas_encoding_baseline.json` `loneCr` 双豁免已归零移除（eol-gate 零豁免通过） | **ACTIVE** |
| **PI-K6-E9-CONVERGENCE** | `DeepBase` | `46ee3f0` | 2026-09-20 12:26:54 | 激活 `.gitattributes`(E9，commit `4f9a747`)：251 件纯行尾 blob 一次 renormalize | **内容零变化**（非行为变更）：`git diff 71d9596 46ee3f0 --numstat --ignore-cr-at-eol` = **3 / 254 件**，251 件归零；**独立证明**：对 Schema.pas 剥 CR 指纹与修复前逐字节一致（47,773 B），全库除受控证据 `TestResults/**` 外纯行尾噪声 = **0** | blob 行尾与 E9 立法一致，检出物与原工作树逐字节同（`text eol=crlf` 往返）；使「零多余零缺失」类判定不再受行尾噪声干扰 | **ACTIVE**（无语义行为变更，登记以满足「全库修复线一律登记」） |
| **PI-R4-UPDATE-CHAIN-TGV** | `DeepBase` | `c1052a2` | 2026-09-20 12:33:43 | 甲R4：更新验签链强类型 fail-closed 收口（`DeepBase.Manifest.Verifier` / `DeepBase.Updater` / `DeepBase.AutoUpdate`） | **行为变更**：`VerifySignature`/`VerifyFileHash`/`DownloadUpdate` 返回值由 `Boolean` 改为 `TGateVerdict`；manifest 缺字段/未知算法/验签失败一律 `gdRejected`；下载包完整性校验失败时**删除已落盘包并拒绝安装**（原保留文件）。下游 AsWish/DeepAxis：按 Boolean 分支的调用方语义改变——拒绝面扩大且拒绝即清理磁盘 | **ACTIVE** |
| **PI-R4-HB-BADGE-TONES** | `DeepBase` | `c1052a2` | 2026-09-20 12:33:43 | 甲R4：`DeepBase.HB.Core` 徽章语义扩展 | **视觉行为变更**：`THbBadgeTone` 新增 `btChange/btNotice/btUnresolved` 三档，主题新增 SurfaceQuiet/Change/Notice/Unresolved 四组取色；HB 组件（Status/Cards 等）可渲染新色调徽章，下游集成方可见 | **ACTIVE** |
| **PI-R4-PAS-BOM-ENCODING** | `DeepBase` | `c1052a2` | 2026-09-20 12:33:43 | 甲R4：27 个生产单元 + 8 个测试单元补 UTF-8 BOM | **编译解析行为变更**：这些含中文注释/字面量的 .pas 此前无 BOM，dcc64 按 ANSI 代码页解析（中文字符串常量存在误编译面）；加 BOM 后编译器按 UTF-8 读取，产出物中的中文字面量字节序列与加 BOM 前构建**不同**。凡引用这些单元中文常量的运行时显示/序列化输出均属变更面 | **ACTIVE** |
| **PI-R4-L6-DPROJ-SEARCHPATH** | `DeepBase` | `d33273d` | 2026-09-20 11:58:35 | 乙R4-L6：`Tests/DeepBaseTests.dproj` 的 `DCC_UnitSearchPath`（Base/Win32）补 `..\FMX`、`..\Tools\WebService` | **构建配置变更**：dproj 此前落后于 CI 权威口径 `Scripts/run_tests.ps1:530-541` 的 `-U` 集，缺 `..\FMX` 导致 `Test.DeepBase.FMX.HB.Dialogs.pas(22)` 报 `F2613 Unit 'DeepBase.FMX.HB.Theme' not found`、`msbuild EXIT=1` 阻断全量编译；补路径后同参数重跑 `EXIT=0`（361,486 lines）。影响面 = 本地/CI 以 dproj 为入口的编译可达性，不改任何单元源码、未删 dpr 引用、未加条件编译 | IDE 与 msbuild 的 dproj 编译口径与 `run_tests.ps1` 对齐，消除「命令行可编、dproj 不可编」分叉 | **ACTIVE** |
| **PI-R4-L7-EXAMPLES-RENAME** | `DeepBase` | `dc01026` | 2026-09-20 11:46:54 | 乙R4-L7：`Examples/MicroserviceClientDemo` 落地（归属已裁定=乙） | **工程结构与产物变更**：① `MainForm.pas/.dfm` 经 `git mv` 更名为 `Main.Form.pas/.dfm`，**单元名随之改变**（dpr `uses` 已同步；改名动因是 E2004「单元名与全局 var 同名」的既有编译缺陷）；② dpr 删除 `{$R *.res}`（该 .res 不在仓内，删除后 dcc32 不再要求预置资源文件，动因 E1026）；③ demo 内本地 `TCircuitState`/`TCircuitBreaker` 重复实现删除，改消费 `Core/DeepBase.Resilience.CircuitBreaker`（SSOT 收敛，净减 122 行）。影响面限 `Examples/**`，不参与主库编译与发布产物 | 示例工程可独立编译（dcc64 Win64 37.0 实测 `EXIT=0`，3196 lines）；熔断语义与主库单一实现一致，消除双轨分叉 | **ACTIVE** |
| **PI-R5-N1-BACKUPID-FAILCLOSED** | `DeepBase` | `1a85e92` | 2026-09-20 13:43:13 | 乙R5-N1：云备份 `ABackupId` 统一走 `SafeBackupId`（`IsValidBackupId` + `BACKUP_ID_PATTERN`，`Features/DeepBase.CloudBackup.pas`） | **行为变更（fail-closed）**：非法备份 id（空值、含 `/ \ .. ` 路径分隔或穿越、超出字符集/长度）此前被**静默拼进文件路径**，此后在入口一律抛 `EBackupInvalidIdException`。消费点覆盖创建/列举/下载/恢复/删除全链（`SafeBackupId` 调用点 1810/1812/1817/2047/2126），`BackupFileUnderRoot` 保留根前缀二次防御；**不为旧宽松语义保留任何兼容分支**，所有现有与未来消费点统一走同一入口 | 调用方（含 AsWish/DeepAxis 下游）传入非法 id 时由「可能读写根外路径」变为「立即失败」，须按异常分支处理；合法 id 行为不变 | **ACTIVE** |
| **PI-R5-N3-EVIDENCE-ENCODING-GATE** | `DeepBase` | `efc40cf` | 2026-09-20 13:45:23 | 乙R5-N3：新增 `09_工程脚本/evidence-encoding-gate/` 并接入 `.github/workflows/delphi-ci.yml` | **CI 门禁变更（无产品运行时行为变更）**：`CodeReview/**` 的 `*.txt/*.log/*.csv/*.xml` 证据若含 NUL 字节或非 UTF-8 编码即使 CI 失败；基线 `evidence_encoding_baseline.json` 只降不升，当前豁免 1 件甲域存量（`20260919-AUDIT-甲-证据/R3-run-tests.log`，NUL=987）。影响面 = 所有提交审计证据的编码口径（H18），存量 3 件 UTF-16 日志须由其归属人按 UTF-8 重落后删除条目 | 杜绝 PowerShell `>` 产出 UTF-16LE 证据再次入库；证据可读性可机器执法 | **ACTIVE**（登记以满足「修复线一律登记」） |
| **PI-R6-N1-GATE-G3-NONASCII** | `DeepBase` | `033a11d` | 2026-09-20 15:24:17 | 乙R6-N1：`09_工程脚本/encoding-gate/check_pas_encoding.js` 的 G3 判据收窄 | **门禁判据变更（无产品运行时行为变更）**：`.pas` 的 UTF-8 BOM 要求由「**任何 .pas**」收窄为「**含非 ASCII 字节的 .pas**」——纯 ASCII 源码不再要求 BOM（dcc64 对纯 ASCII 按 ANSI 代码页解析的结果与 UTF-8 逐字节相同，加 BOM 无收益）；同时使 G3 与 `bomExceptions` 的生成口径（含中文且无 BOM）对齐，消除两口径之间的误报裂缝。实测 encoding-gate 违规 **7 → 4**，出列 3 件纯 ASCII（`Core/DeepBase.Template.pas`、`Features/DeepBase.UIA.UnifiedActuator.pas`、`Features/UIAutomationClient_TLB.pas`）；`bomExceptions` 同步移除 2 项 HEAD blob 已含 BOM 的死条目（47 → 45，基线只降不升） | 门禁剩余 4 件均为真实缺陷且属甲域/公共层（H2 乙不代改，移交甲 R6）；下游写 `.pas` 的 AI/工具链约束面收窄，含中文文件的要求不变，无语义行为变更 | **ACTIVE**（登记以满足「修复线一律登记」） |
| **PI-R6-N2-GITIGNORE-TESTRESULTS** | `DeepBase` | `c966abc` | 2026-09-20 15:28:50 | 乙R6-N2：`.gitignore` 的 `TestResults/` 忽略口径收口 + 已跟踪产物去跟踪 | **工程治理（无产品运行时行为变更）**：原 5 条按扩展名/子目录的部分覆盖规则（`*.xml`/`*.txt`/`*.json`/`_*/`/`autofix-*/`）漏过 csv/png/md/bmp 共 29 件，使 182 件测试运行产物长期被仓库跟踪并贡献 142 件 `i/crlf` 行尾噪声；收口为整目录 `TestResults/` 一条（原 5 条为其真子集，全仓 3 条 negation 与之无冲突），并 `git rm --cached -r TestResults/` 仅去跟踪。**工作树零删除**：前后 `files=37578 dirs=402 bytes=7082344701` 逐位一致 | 追踪面 182 → 0；`TestResults/**` 不再进入 diff/行尾统计，eol-gate 复跑 1403 文件 EXIT=0；受控证据改由 `CodeReview/_audit_recheck/` 承载（H6） | **ACTIVE**（工程治理登记） |

> **登记来源**：`L8-E001-Observation-Active-Execution-Policy.md` §二（START Anchor `f47c573` 之后 commit 分类登记）+ `WO-20260919-AUDIT-乙-R3` K4。
> **时间界**：INT-20260917-01/02/03 均发生在 Case 001 START 宣告（2026-09-17 16:31）**之后** ⇒ 凡 `timestamp` 早于其 `Effective Time` 的 Episode 归入 `Before`，晚者归入 `After`，**严禁混池**。
> **F4 相关性**：三项均未触及 `F2B`/`Engine`/`flight-receipt`，**与 F4 影响面无交集**。

---

## 二、模型切换事件登记表（Model Change Events, §5.4）

| Model Event ID | Product | Model Version / Provider | Effective Time (UTC+8) | Reason / Context | Expected Impact |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **MOD-20260917-01** | `AsWish` | `deepseek-chat` (DeepSeek-V3) | 2026-09-17 00:00:00 | Case 001 观察启动初始基线模型 | 候选生成、意图解释基准能力 |
| **MOD-20260917-02** | `AXIS` | `deepseek-chat` (DeepSeek-V3) | 2026-09-17 00:00:00 | Case 001 观察启动初始基线模型 | F3 话术生成基准能力 |

---

## 三、使用说明

1. **Episode 关联**：每个 Episode 记录的 `intervention_id` 字段按其 `timestamp` 与 `software_commit` 匹配上述表格。
2. **基线切分**：在任何 Intervention 生效之前的数据归入前序统计子集，生效后归入后续子集。
3. **归因边界**：若模型或代码发生重大变更，观察结论必须单独评估该干预事件的影响，禁止将变更带来的变化全部归因于 EHAI。
