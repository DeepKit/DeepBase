# WO-20260920-AUDIT-甲-R6 — 编码收口：甲域 BOM 补与 UTF-16 证据重落

- **工单号**：WO-20260920-AUDIT-甲-R6
- **发出时间**：2026-09-20 15:10 +0800
- **发出人**：主控 AI
- **承接方**：开发 AI 甲
- **取证基线**：DeepBase HEAD = `2e1aa78`
- **工单性质**：K6 / 乙 R5 归因遗留的**甲域编码收口单**（非新开发）
- **⚠️ 前置依赖**：**本单一律在 `WO-20260920-AUDIT-甲-R5`（M1–M5）全部落定后开工**。R5 未落定即开工 = 制造共享 index 竞争（`ed50cfd` 事故模式），违反 H16。**主控另发开工许可后再启动。**
- **上游依据**：`20260920-AUDIT-主控-K6-执行结论.md` §六｜`20260920-AUDIT-乙-R5-交付回执.md` §五/§六｜`20260920-AUDIT-主控-R4-R5-终审结论.md` §五

---

## 一、背景（一句话）

`encoding-gate` 存量红 7 项缺 BOM，经乙 R6 N1 校正 G3 口径（「任何 .pas 须 BOM」→「**含非 ASCII** 的 .pas 须 BOM」）后，纯 ASCII 3 件出列，**余 4 件全在甲域 / 公共层**，须由甲按权属补 BOM；另甲域 3 件 UTF-16 证据须按 H18 重落。两项均因 H2（乙不代改甲域）而积压至今。

---

## 二、任务清单

### M1【甲域 / 公共层 4 件 `.pas` 补 UTF-8 BOM】

> ⚠️ 本项**须在乙 R6 N1 落定后**执行（否则 7 件口径未收敛）。若届时乙 R6 未开工，按 7 件全量执行亦可，但回执须声明所用 G3 口径。

| # | 文件 | 非 ASCII | 汉字 | 首入库（首版无 BOM 点） | 域 |
| :--- | :--- | ---: | ---: | :--- | :--- |
| 1 | `Core/DeepBase.Gate.Verdict.pas` | 1037 | 293 | `32b0642`（甲 R2） | 甲 |
| 2 | `Core/DeepBase.HB.Choice.Types.pas` | 122 | 36 | `99ec1e7`（feat(hb)） | 甲（`HB.*`） |
| 3 | `Tests/Regression/Test.Regression.A8_InFlightUnloadGate.pas` | 777 | 229 | **`c1052a2`（甲 R4，无 BOM 态入库）** | 甲 |
| 4 | `Core/DeepBase.EHAI.Types.pas` | 56 | 0 | `2208973`（feat(ehai)） | 公共层（本单代收） |

**改法**：逐件在文件头写入 UTF-8 BOM（`EF BB BF`），**不改动任何正文字节**。

**产品干预登记**：**编译解析行为变更** —— 这些含中文注释/字面量的 `.pas` 此前无 BOM，dcc64 按 ANSI 代码页解析；加 BOM 后按 UTF-8 读取，产出物中中文字面量字节序列与加 BOM 前**不同**。凡引用这些单元中文常量的运行时显示/序列化输出均属变更面。登记入 `docs/ui/work-orders/L8-E001-Intervention-Registry.md`。

**验收**：`encoding-gate` 由 4 → **0**（若乙 R6 N1 已落下）；`git diff --numstat` 每件仅 +1/−1 行级（BOM 使首行变化），正文零改动（可用逐字节比对证明除首 3 字节外相同）。

### M2【甲域 3 件 UTF-16 证据重落为 UTF-8（H18）】

**现状（主控实测）**：以下 3 件含 NUL=987/件，属 `PowerShell >` 产出的 UTF-16LE：

| 文件 | NUL 计数 |
| :--- | ---: |
| `CodeReview/20260919-AUDIT-甲-证据/R2-run-tests.log` | 987 |
| `CodeReview/20260919-AUDIT-甲-证据/R3-run-tests.log` | 987 |
| `CodeReview/20260919-AUDIT-甲-证据/run-tests-a6a8.log` | 987 |

**改法**：逐字节转码为 **UTF-8 无 BOM、NUL=0**，**内容零增删**（同乙 R5 对 R2 证据所用方法）。

**联动**：完成后**通知乙**，由乙 R6 N5 删除 `09_工程脚本/evidence-encoding-gate/evidence_encoding_baseline.json` 的 `nulStock` 条目，`--all-worktree` 口径 NUL=0 方可成立。

**验收**：3 件 NUL=0 且为合法 UTF-8；`--all-worktree` 口径 `evidence-encoding-gate` **exit=0**。

---

## 三、明确不在本单

| 项 | 处置 |
| :--- | :--- |
| G3 规则/基线口径修改 | 乙 R6 N1（门禁侧），甲不碰门禁脚本 |
| `TestResults/**` 去跟踪 | 乙 R6 N2 |
| 纯 ASCII 3 件（`Template.pas` 等） | G3 口径收窄后出列，无需补 BOM |

---

## 四、硬约束（H 系列，违反即 REJECT）

- **H1**：禁 `checkout --`/`restore`/`clean`/`reset --hard` 处置非本单改动。
- **H2 反向**：本单仅动甲域 / 公共层文件；**禁触碰乙组文件**（`CloudBackup.pas`/`Selectors.pas`/`encoding-gate/`/`evidence-encoding-gate/`/`Examples/MicroserviceClientDemo/` 等）。
- **H3**：禁宽泛 `add`；逐件精确 pathspec。
- **H4**：零删除。
- **H8**：不得为兼容旧解析而保留无 BOM 态。
- **H9**：回执写明结束时间 + commit hash。
- **H14/H15/H16/H18**：行尾前置核验 / 原子提交 / 共享 index 并发 / 证据编码。
- **H7**：禁自报 PASS。**H11**：不授权 pg-tag。

---

## 五、交付物

1. 精确 pathspec 的 commit（M1 / M2 建议分次）
2. 回执：`CodeReview\20260920-AUDIT-甲-R6-交付回执.md`
3. 证据：`CodeReview\_audit_recheck\`（`甲-R6-encoding-gate-run.txt` + `甲-R6-bom-byte-diff.txt` + 重落后的 3 件日志）

---

## 六、是否阻塞他仓

**否**。但 M2 落定是乙 R6 N5 的**前置**（单向依赖）。
