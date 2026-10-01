# WO-20261002-MC-主控-GOVCONTRACT `DeepBase.DataBinding` 显式登记消费者契约（主控 · P3）

**单号**：`WO-20261002-MC-主控-GOVCONTRACT`
**派单**：主控（2026-10-02 全仓缺口清点：甲 A16 Q3 breaking change 落地后遗留的一项**治理决定**，自 2026-10-01 起只登记为「另属治理决定、已登记为待办」，无单承接）
**优先级**：P3
**授权面**：`contract/consumer-contract.json`、`CodeReview/**`（裁定件）、`docs/ui/work-orders/00-主控派单总表.md`
**禁动区**：`Core/**`、`Features/**`、`Tests/**`、`Tests/Integration/**`、`Scripts/**`、`09_工程脚本/**`、`noise-baseline.json`

---

## 〇、纪律与口径

1. 本单只做**治理裁定 + 契约登记**，**不改一行 `.pas`**。`DeepBase.DataBinding` 的源码面（A16 已落地 `a2c4077`/`37cdf3a`/`7c1a98b`）不在本单。
2. **禁止为转绿重建签名基线**：`signature-baseline.json --emit-baseline` 是发版动作（见 `WO-20261001-MC-主控-CONTRACTGATE` 与「四门」口径记忆），本单若触到 contract-gate 读数，先归因再定性。
3. 一笔 H15 原子提交，显式 pathspec，禁 push。台账状态槽归主控。

---

## 一、事实与待裁问题

甲 A16 把 `TBindingManager.Bind` 契约从「任意 `TObject`」收窄为「可追踪对象」（不可登记面抛 `EBindingUnsupportedObject`），Q3 已由主控登记入 `./CHANGELOG.md` 的 `## [Unreleased]`（BREAKING CHANGES 一条 + Added 一条）与 `09_工程脚本/contract-gate/signature-baseline.json` 的比对面。

**遗留待裁**：`DeepBase.DataBinding` **未显式登记进** `contract/consumer-contract.json`。

⇒ 派生两个待裁问题：

1. **是否显式登记**：不登记的后果是——contract-gate 的 `stability=stable` 集合不含该单元 ⇒ 该单元的公开签名变更**不在门禁检测面内**（只报不拦都不报）。一次 breaking change 已经发生而门禁无从覆盖，属**检测盲区**。
2. **若登记，定何级**：`stability` 取何值、`signatures` 基线如何取（当前 HEAD 的快照 vs 取 A16 前的旧签名）——取错会让**已经发生的收窄**被记成「未来才允许的破坏」，或反过来洗掉既存事实。

**须一并核对**：`contract-gate` 当前既存红（`eb93e23` 引入、HEAD EXIT=1，另单 CONTRACTGATE 修抽取器）。本单**不得在 CONTRACTGATE 修好抽取器之前**重建任何基线，否则假阳性会掩盖真发现。

## 二、任务

1. 亲读 `contract/consumer-contract.json`，列出现有 `stable` 单元集合与登记格式（含 `stability` / `signatures` / `notes` 等字段的实际语义）。
2. 判定 `DeepBase.DataBinding` 的**消费者面**：仓内 consumer 调用点亲核（A16 已核实仓内零影响），并确认外部消费者是否存在（DeepSync 外单 DB-002/004/006/007 的承接面）。
3. 出具**裁定件** CodeReview/20261002-AUDIT-主控-GOVCONTRACT-裁定.md（未来路径不加反引号）：是否登记 + 定级 + 基线取法 + 对 contract-gate 读数的影响预测（含 CONTRACTGATE 修好前后的两版预测）。
4. 若裁「登记」：落 `contracts/consumer-contract.json`（**记录 `generated` 时间戳与来源提交**），并复跑 contract-gate 记录**修前/修后**读数，差异逐条归因。
5. 台账 §三 主控线该行回填；涉及 CHANGELOG 的口径变化（若裁「登记」则 A16 的登记说明需补一句「现已显式入约」）另笔处理，不得夹带。

## 三、判据（fail-closed）

| # | 判据 | 期望 |
|---|---|---|
| 1 | 契约格式亲读 | 现有集合逐条列出，字段语义有出处 |
| 2 | 消费者面亲核 | 仓内调用点 + 外部承接面，禁凭回执转述 |
| 3 | 裁定件 | 两问各有结论与理由；定级与基线取法写明 |
| 4 | 若登记 | contract-gate 修前/修后读数均留档，差异归因；**不得**用 `--emit-baseline` 洗 |
| 5 | 若裁「不登记」 | 须写明盲区如何被别的手段覆盖（例：人工审阅清单），禁「不登记且无覆盖」 |
| 6 | 四门 | eol / encoding / mojibake / evidence-encoding **逐道写门名 + EXIT** |
| 7 | 纪律 | 单笔 H15，显式 pathspec，未 push |

## 四、不在本单（已登记）

- contract-gate 抽取器假阳性修复：`WO-20261001-MC-主控-CONTRACTGATE`（**前置**）。
- `DeepBase.DataBinding` 源码改动：已 ACCEPTED 的甲 A16。
- 签名基线重建：留待发版，主控不自行 `--emit-baseline`。

## 五、执行结论（主控回填）

（待回执：契约集合亲读结果、消费者面亲核、两问裁定、contract-gate 修前/修后读数与归因、提交哈希、未 push 声明。）
