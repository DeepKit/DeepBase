# WO-20261001-MC-主控-PS1ENC `.ps1` 编码约定求证与仓级收口（主控派单 · P3）

**单号**：`WO-20261001-MC-主控-PS1ENC`
**派单**：主控（2026-10-01，甲 `WO-20261001-MC-甲-A16` 验收收口时派生；含 MC1 项 2 一处**过宣称的订正**）
**优先级**：P3
**授权面**：`Scripts/**`、`.gitattributes`、`09_工程脚本/encoding-gate/**`（若判据需要）
**禁动区**：`Core/**`、`contracts/**`、`Features/DeepBase.Licensing.pas`、`Tests/**`、`Tests/Integration/**`

---

## 〇、纪律与口径

1. 零信任：判据全部主控亲跑留档。
2. 本单第一件事是**订正一处过宣称**（见 §一），不是去修一个不存在的缺陷。执行方不得把
   「MC1 项 2 登记的 ANSI 吞行」当成已证事实直接开修。
3. 一笔 H15 原子提交，显式 pathspec，禁 push。台账状态槽归主控。

---

## 一、先订正：MC1 项 2 的一处过宣称

MC1 项 2 台账行曾登记：

> `.ps1` 无 BOM + PS 5.1 ANSI（CP936）解码：中文注释若恰在换行处被吞行……仓级待立项收口面。

**主控 2026-10-01 复测证伪该机制**（`.tmp/mc-bomtest/`，本机 `5.1.26100.2161`，
`[Text.Encoding]::Default.WebName = gb2312`）：

| 用例 | 文件形态（UTF-8 无 BOM，CRLF） | 实跑读数 |
|---|---|---|
| c1 | 中文注释独占一行 + 下一行 `Write-Output` | 输出 `AFTER-COMMENT`，EXIT=0，**注释未被吞行** |
| c2 | 行尾中文注释 + 下一行代码 | 输出 `AFTER-TAIL`，EXIT=0 |
| c3 | 中文串相等判断分支 | 输出 `MATCH`，EXIT=0 |
| t | 中文串直接输出 | 输出 `中文测试-EN`，**非乱码** |

⇒ 本机 PS 5.1 对无 BOM 的 UTF-8 `.ps1` **按 UTF-8 解码**，注释吞行与串乱码**均不复现**。
该登记是从「MS 文档称无 BOM 回落 ANSI」推演的，**未实测即入账**，本单负责订正。

**但风险不是零**：回落行为是 **PS 版本/OS 语言包相关**的（本机 gb2312 恰好能容纳部分情形，
且新版 PS 读文件已有 UTF-8 嗅探）。换 runner、换语言包、或文件被 msys/git 以非 UTF-8 重写一次，
就可能真的回落。⇒ 值得做的是**声明约定 + 门禁固化**，不是紧急修复。

---

## 二、仓内事实（主控 2026-10-01 亲点）

- 仓内 `.ps1` 共 **72 个**，**带 BOM 0 个 / 无 BOM 72 个**；
- 其中含 CJK 的 **16 个**（`Scripts/run_tests.ps1`、`Scripts/check-entropy.ps1`、
  `Scripts/autofix/_common.ps1`、`Scripts/verify_doqry.ps1`、`Tests/AutoFix/*.Tests.ps1` 9 件等）；
- 全部为合法 UTF-8（无一为真实 ANSI/CP936 字节）；
- `.gitattributes` 已有 `*.ps1 text eol=crlf`，**但无任何编码声明**；`encoding-gate` 的面是
  `.pas` + 扩展面，需核实 `.ps1` 是否在册。

⇒ 现状**自洽**（一律无 BOM 的 UTF-8），缺的是「写下来的约定」与「防止漂移的检查」。

---

## 三、修法方向（执行方裁后落）

1. **立约定**：在 `.gitattributes` 或 AGENTS.md/CLAUDE.md 明确「`.ps1` 一律 UTF-8 **无 BOM**、
   CRLF」，并说明为什么不加 BOM（PS 5.1 认 BOM 为 UTF-8，但 msys 工具链与部分编辑器会重复加）。
2. **加固化检查**：若 `encoding-gate` 未覆盖 `.ps1`，则纳入——判据为「全部合法 UTF-8 + 无一带 BOM」，
   基线只减不增，**不得用 `--emit-baseline` 一次性洗白**（见 `gate-set-enumeration-trap`）。
3. **不批量加 BOM**：那会一次改动 72 个文件、且与本机实测结论矛盾。

---

## 四、判据（fail-closed，全部主控亲跑留档）

| # | 判据 | 期望 |
|---|---|---|
| 1 | 反向样本：构造一个**真实 CP936 字节**的 `.ps1` | 若纳入 encoding-gate ⇒ 必须检出；未纳入则须如实登记覆盖面结论 |
| 2 | 负样本：把 run_tests.ps1 复制一份转成 CP936 字节 | 同上；证明检查有牙 |
| 3 | 本机复跑 §一 四用例 | 全绿（订正结论可复算） |
| 4 | 若动 `.gitattributes` | eol 门 EXIT=0，且 `.ps1` 检出面不缩小 |
| 5 | 若动 encoding-gate | baseline 只减不增；跑录留档 |
| 6 | 四门 | eol / encoding / mojibake / evidence-encoding EXIT=0（**不含 contract-gate**，既存红另单） |
| 7 | 台账订正 | MC1 项 2 行内「仓级待立项收口面」按 §一 订正，注明本单号 |
| 8 | 提交纪律 | 单笔 H15，显式 pathspec，未 push |

---

## 五、不在本单（已登记）

- check_doc_links.ps1 裸名误报（另单 `WO-20261001-MC-主控-DOCLINKS`）。
- `contract-gate` 既存红（另单 `WO-20261001-MC-主控-CONTRACTGATE`）。
- 其他脚本语言（`.py`/`.sh`）的编码面。
- 72 个 `.ps1` 的批量重写。

---

## 六、执行结论（执行方回填）

（待执行方回执填写：判据 1–8 逐条读数、覆盖面结论、订正文案、提交哈希、未 push 声明。）
