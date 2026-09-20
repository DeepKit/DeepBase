# WO-20260920-AUDIT-甲-R5 — Top20 安全链派发与 Gate#5 收口

- **工单号**：WO-20260920-AUDIT-甲-R5
- **发出时间**：2026-09-20 10:48:29 +0800
- **发出人**：主控 AI
- **承接方**：开发 AI 甲
- **取证基线**：DeepBase HEAD = `dc28605`
- **工单性质**：**Top20 子单正式派发**（此前 4 份子单由甲 A5 建立但「执行方：待定」，A10 验收要求「无无人认领的 Top20 条目」——本单完成该闭环）+ 两项遗留收口
- **⚠️ 前置依赖**：**本单 M 系列一律在 `WO-20260919-AUDIT-甲-R4`（53 项收口）落定后开工**。R4 未落定即开工 = 制造共享 index 竞争（`ed50cfd` 事故模式），违反 H16。

> **⚠️ 2026-09-20 20:42 主控重新调度（老板「立即优化」裁定）**：本单**以 M1/M2 收口**（M1 `1a6807b`、M2 `9387222`，主控验收中）。**M3（Net SSRF）/ M4（裸跑卡死诊断）/ M5（BPL 卸载测试）已移交 `WO-20260920-AUDIT-甲-R7-安全质量立即优化`（P2/P3/P4）承接**，本单不再单列 M3–M5。原因 = 保证甲**单一活跃工单**，杜绝共享 index 竞争（H16），并按老板裁定以**质量影响**排序。

---

## 一、派发依据（主控按文件所有权切分，实测）

| 子单 | 主文件 | 实测所有权 | 派给 |
| :--- | :--- | :--- | :---: |
| Top20 #01 更新验签链 | `Features/DeepBase.Updater.pas`、`Features/DeepBase.AutoUpdate.pas` | 甲 R4 清单内（甲独占） | **甲** |
| Top20 #05 Security 主口令 | `Core/DeepBase.Security.pas`、`Core/DeepBase.License.pas` | Core 安全系（与甲 A17 `Crypto.AES` 同族） | **甲** |
| Top20 #17 Net SSRF | `Features/DeepBase.Net.pas` | 不在任何一方脏集；安全线主导权在甲（甲 R1/R2 承接 #9/#10/#12/#16 等安全项） | **甲**（主控裁定） |
| Top20 #06 CloudBackup 路径遍历 | `Features/DeepBase.CloudBackup.pas` | 乙组清单内（乙 E7/E9 已动该文件） | 乙（见 R5-乙单） |

---

## 二、任务清单

### M1【Top20 #01 — 更新验签链：恶意更新包可当合法包安装（RCE 级，最高优先级）】

**执行清单以原子单为准，本单不复制其内容**（单一信息源）：`docs\ui\work-orders\WO-20260919-AUDIT-Top20-01-更新验签链.md`

**要点（不可缩减）**：
- 五处缺陷锚点（`Updater.pas:1464-1471` 算法由远端自述 / `:2281-2342` 缺字段零校验 / `:1831-1846` vs `:1374-1390` 双路径输入不一致 / `:1003`+`:1417` URL 无 https 强制与白名单 / `AutoUpdate.pas:867-895` 双重 SHA256）
- **`Updater.pas` 与 `AutoUpdate.pas` 是两条更新通道，禁止混写**；但 AU-06（同名 `TUpdateInfo` record 双定义 = SSOT 分裂）须一并消解
- **前置**：甲 A6 的 `TGateVerdict` 立法须已生效（子单写明为本单门禁改造的前置依赖）

### M2【Top20 #05 — Security 主口令无用户 secret】

**执行清单以原子单为准**：`docs\ui\work-orders\WO-20260919-AUDIT-Top20-05-Security主口令.md`

**要点**：引入用户 secret 熵源（`~/.deepbase/master.key` 0600 随机 32B 或系统 keyring）；`DEEPBASE_MASTER_KEY` 改传**文件路径**并在读入后 `SecureZeroMemory`；machine-id 降级为 AAD；硬件绑定缺失 fail-closed **不回落 `ComputerName`**；UBS2 头引入格式版本与 KDF 上下界。

### M3【Top20 #17 — Net SSRF 与环境变量全局关闸】

**执行清单以原子单为准**：`docs\ui\work-orders\WO-20260919-AUDIT-Top20-17-NetSSRF与环境关闸.md`

**要点**：**废弃字符串正则判 IP**，改数值解析 + 网段判定（简写/八进制/十进制由解析器天然覆盖）；重定向须逐跳复验并剥离自定义头；`DeepBase_ALLOW_PRIVATE_NET_HTTP` 全局关闸须消除或改为需显式二次确认；安全判定与连接解析器须同源（消 rebinding 两解不同果）+ IP pin。

### M4【UNRESOLVED-RUN-001 — 全量套件裸跑卡 HB Gate #5】

- **现象**：全量 `Tests\DeepBaseTests.dpr` 编译通过（`FULL_EXIT=0`，357,160 行），但**裸跑卡在 `HB Gate #5`**（UI 性能基准需真实窗口消息泵）。乙 R2/R4 均据此改用「定向 runner」，导致**全库回归声明长期无法成立**（不等式②受限）。
- HB 区为甲独占，乙无权修。
- **要求**：查明 Gate #5 的真实依赖（消息泵？DPI？桌面会话？CI 无头环境？），给出**在无头/CI 环境可跑**或**明确标注为 manual-only 且登记原因**的结论。**不得**用「跳过该 Gate」掩盖（若确需跳过，须列出跳过项清单 + 每项原因 + 替代验证）。
- 交付：`CodeReview\_audit_recheck\甲-R5-gate5-诊断.txt` + 结论。

### M5【A18 — 端到端 BPL 卸载测试（R1 遗留 DEFERRED）】

- 甲 R1 判 DEFERRED（BPL 夹具需 IDE 链）。**永久限定表述**：A8 与插件卸载**只可**声明「计数机制已验证；真实 BPL 卸载未验证」。
- **要求**：给出可执行路径（能否用 `loadpackage`/`UnloadPackage` 在测试进程内建夹具？能否脚本化 IDE 构建？）或**正式申请永久关闭**并说明残差风险。

---

## 三、验收标准

| 项 | 标准 | 主控判定方式 |
| :--- | :--- | :--- |
| M1–M3 | 各自原子单的「验收标准」章节全部满足；**改法与原子单一致，不得自行缩减**（缩项须书面申请） | 主控逐条比对原子单 |
| M1 | 「质量优先」：**禁**为兼容旧 manifest 格式/旧签名路径保留 fallback 或开关；缺字段一律 fail-closed | 主控回源码复核 |
| M4 | Gate #5 依赖查明；无头可跑 或 manual-only 已登记（含跳过项清单 + 原因 + 替代验证） | 主控读结论 + 复跑 |
| M5 | 可执行路径已给出 或 永久关闭已申请（含残差风险） | 主控读结论 |
| — | 双证据：控制台 log + NUnit XML，数量自洽、XML 时间戳早于 commit | 主控读文件 |
| — | H14 双数字申报（raw + ignore-EOL） | 主控复验 |

---

## 四、硬约束（H 系列，违反即 REJECT）

- **H1**：禁 `checkout --`/`restore`/`clean`/`reset --hard` 处置非本工单改动。
- **H2**：禁触碰乙组文件（`Resilience*`/`CloudSync`/`CloudBackup`/`Browser.*`/`Speech.*`/`IntentClarification.*`/`Governance.*`/`LLMChatFrame`/`managed-copy-gate`/`eol-gate`）。
- **H3**：禁 `git add -A` / `git add .` / 目录级宽泛添加。
- **H8 · 质量优先，不是兼容优先（老板 2026-09-19 裁定）**：允许 breaking change；**禁**为兼容旧行为/旧密文格式/旧时序而保留缺陷，或加兼容层/开关/fallback。**本条对本单 M1/M2/M3 尤为核心** —— 安全链改造不得留后门式兼容。
- **H14**：提交前 `git ls-files --eol <path>`；`i/crlf`/`i/mixed` 必须 `--renormalize`；双数字申报。
- **H15 · 原子提交**：`git commit` 必带 `--only` 或 pathspec；提交前后各跑 `git diff --cached --name-only`（前空后空）。
- **H16 · 共享 index 并发禁令**：发现他方暂存即停写、报主控。
- **H17 · 迁移类声明须附双证**：`git log --all -- <路径>` + 目标仓可达性。
- **H18 · 证据文件编码纪律**：证据必须 UTF-8 落盘，自证 `NUL = 0`。
- **H7**：禁自报 PASS；数字必须来自日志/产物。
- **H12**：`PluginManager`（旧轨）改动须遵 C1–C5 约束。
- **H11**：本单不授权 pg-tag。
- **H9**：回执须写明结束时间（本地，精确）与交付 commit hash。

---

## 五、产品干预登记

按老板 2026-09-19 裁定，M1–M3 均为**行为变更**，一律登记为**产品干预**（`docs/ui/work-orders/L8-E001-Intervention-Registry.md`），禁用「纯内部优化」表述。安全链改造属高影响面，须逐项写清「哪些行为变了」。

---

## 六、交付物

1. 精确 pathspec 的 commit（可按 M 逐项分次提交）
2. 回执：`CodeReview\20260920-AUDIT-甲-R5-交付回执.md`
3. 证据：`CodeReview\_audit_recheck\`（`甲-R5-run-tests.log` + `甲-R5-NUnit.xml` + `甲-R5-gate5-诊断.txt`）

---

## 七、是否阻塞他仓

**否**。但 **M1 涉及更新签名链**，若 AsWish / DeepAxis 复用同一更新组件，须在回执中申报影响面（由主控决定是否下发下游工单）。
