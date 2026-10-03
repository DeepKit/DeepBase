# WO-20261003-MC-甲-TPLBOOT Template.AutoUpdateBootstrap 不可编译收口（主控派单 · P2）

**单号**：`WO-20261003-MC-甲-TPLBOOT`
**派单**：主控（2026-10-03，`WO-20261003-MC-甲-UPDENDPOINT` 取证时顺带登记、本次正式派单）
**优先级**：P2（无生产消费方，但 `HEAD` 不可编译 + 乱码还原声称已做而未落盘）
**前置**：`docs/ui/work-orders/00-主控派单总表.md:100` UPDENDPOINT 行「禁顺手修」条款

**对象文件**（下文称「本文件」）：

```text
Examples/Templates/Common/Template.AutoUpdateBootstrap.pas
```

---

## 〇、纪律与口径

1. **零信任**：主控已核实的事实只是线索，处置结论必须由本单自行取证后给出，**不得照抄主控倾向**（见 §二 处置段）。
2. 一笔 H15 原子提交，message 带单号，显式 pathspec，选项在 `--` 前，**禁 push**。
3. 台账状态槽改写权归主控，本单只写回执。
4. **通道/对象限定**：本文件是 `Examples/` 下的样例，不是生产代码路径。任何断言必须写明是哪个类的哪个成员，禁裸写「组件不支持」。
5. 乱码还原的归属：`Examples/` 属 `WO-20260922-AUDIT-甲-A3`（S2 域）授权面。本单**不抢 A3 的活**，只做「还原清单声称已还原、HEAD 实际未还原」这一处的**核定与登记**（判据 2）。

---

## 一、主控已核实的事实（待本单复算）

| # | 事实 | 主控取证方式 |
|---|---|---|
| F1 | `GAutoUpdater: TAutoUpdater`（`:29`），取 `VCL/DeepBase.VCL.AutoUpdater.pas:22` 的 `TAutoUpdater = class(TComponent)` | 亲读两侧 |
| F2 | `TAutoUpdater` 的 `published` 段**只有 3 个属性**：`UpdateUrl`(`:43`)、`CurrentVersion`(`:45`)、`AutoCheck`(`:47`) | `VCL/DeepBase.VCL.AutoUpdater.pas:41-48` |
| F3 | 本文件引用了 **6 个 `TAutoUpdater` 上不存在的属性**：`Channel`(`:45`)、`ShowDialogOnUpdate`(`:46`)、`EnablePolicyDrivenSilentUpdate`(`:47`)、`SilentInstallPollIntervalMs`(`:48`)、`AutoTriggerExitInstall`(`:49`)、`SilentInstallMainExePath`(`:50`) | 亲读本文件 + F2 |
| F4 | 这 6 个名字在**全仓没有任何属性定义**。其中 `Channel` 的唯一 grep 命中 `Features/DeepBase.AutoUpdate.pas:30` 是文档注释里的 JSON 样例 `"channel": "stable"`，**不是属性**——小心这条假阳性 | `git grep -c <name> -- Features/DeepBase.AutoUpdate.pas` 逐名列式核对 |
| F5 | ⇒ 任何 `uses` 本单元的工程必然 `E2003`/`E2029` 编译失败。**当前它靠「无人 uses」而掩盖** | 由 F3+F4 推得，须由本单亲测坐实 |
| F6 | **零消费方**：`git grep -rn "Template.AutoUpdateBootstrap"` 只命中 2 处 gate 基线（`09_工程脚本/encoding-gate/pas_encoding_baseline.json:75`、`09_工程脚本/eol-gate/eol_baseline.json:108`）、1 处审计基线、`还原清单` 2 件、若干 `CodeReview/**` 证据文件名 | 全仓 grep |
| F7 | 干净祖先存在：`ca3364e` 在库，`git show ca3364e:Examples/Templates/Common/Template.AutoUpdateBootstrap.pas` 内容是**可读中文**（含「为模板工程提供统一的自动更新初始化入口」「默认启用 DeepBase 2026-05 的策略化静默更新编排」「- 退出触发安装窗口」） | 主控亲验 |
| F8 | HEAD 本文件**仍是 mojibake**：主控 Read HEAD 见第 5、8、52、58 行为乱码字节 | Read HEAD |
| F9 | `pas_encoding_baseline.json:75` 记本文件 `2` 行；`CodeReview/20260924-AUDIT-主控-乱码还原/还原清单.md:27-29` 只记 2 行：L6 [G1]「已还原」为 `- 后台轮询安装窗口`、L58 [G2a]「已还原」缺 2 字符 | 亲读两件 |
| F10 | **还原清单与 HEAD 已漂移**：HEAD 第 6 行是 `- onExit/whenIdle staged 下载`、第 7 行才是 `- 后台轮询安装窗口`；L58 声称的「已还原」文本在 HEAD 第 58 行**仍是 mojibake 原文** | 亲读 HEAD 对照清单 |

> F10 是本单的核心疑点：**乱码还原要么没落盘，要么落盘后行号整体漂移导致清单指错行**。不得假定是哪一种，由本单核定。

---

## 二、处置（二选一，回执必须写明选哪个 + 为什么）

- **（A）修复**：给 `TAutoUpdater` 补上 6 个属性（或改为访问 `TDeepBaseAutoUpdate`）。注意代价：这会为一个**零消费方的死样例**扩张 `VCL/**` 的公开 API 面，且属客户端发版面。
- **（B）删除**本文件（路径见单头「对象文件」）。理由候选：零消费方（F6）+ HEAD 不可编译（F5）+ 意图已被 mojibake 破坏一半（F8/F10），按「过时的直接删」最简实现。

**主控倾向 (B)，但本单必须自行取证后独立给结论。** 若选 (A)，须在回执里回答「为什么要为一个没人用的样例扩生产组件 API」。若选 (B)，须说明对 A3 单 `Examples/` 域文件数的影响，以及 gate 基线里那两条本文件条目（`09_工程脚本/**`，主控禁动，本单不得改）后续如何处理——**登记并上报主控，不自行处理**。

---

## 三、判据（主控验收用）

| # | 判据 | 达成标准 |
|---|---|---|
| 1 | F1–F10 复算 | 每条用命令或亲读复现；对不上就报差异，不改主控记录 |
| 2 | F10 核定 | 给出「HEAD 实际 mojibake 行数」「encoding-gate 的**行计数规则**」「与 baseline `2` 的关系」三者的实证结论，零「待定」 |
| 3 | F5 坐实 | 用一个最小工程 `uses` 本单元，贴出真实编译错误行（不是推断）。跑录须在隔离树/独立工程，**不得用主树读数**（主树 T0 必红，见 DCU 单） |
| 4 | 处置落地 | 选 (A) 或 (B)，按 §二 写完理由；(A) 须单件 `BUILD_EXIT=0` 且有新消费方或明确标注为文档样例 |
| 5 | 基线零擅动 | `09_工程脚本/**` 下**零改动**（`git diff --stat -- 09_工程脚本/` 为空）。若处置后 gate 报「好于基线」，如实登记并上报，**不得为转绿改基线，也不得为转绿删条目** |
| 6 | 阴性对照 | 写错一个属性名 / 漏一行 `uses` / mojibake 补错一个字符，各造一例证明会红 |
| 7 | 四门 + 交付纪律 | eol / encoding / mojibake / evidence-encoding 全 EXIT=0；一笔 H15；禁 push |

---

## 四、授权面与禁动区

**授权**：本文件（路径见单头「对象文件」）、`CodeReview/**`（取证留档）、按 §二 选 (A) 时的 `VCL/DeepBase.VCL.AutoUpdater.pas`。

**禁动**：`Core/**`、`contracts/**`、`Features/**`、`09_工程脚本/**`、`Scripts/**`、`noise-baseline.json`、`Tests/**`、`VCL/**`（选 A 时才解禁，且仅限上列一个文件）。

**明令禁止**：
- 顺手「修好」本文件后就地把它设为 UPDENDPOINT 的 Z2 改动载体（UPDENDPOINT 纪律原文「禁顺手修」）
- 改任何 gate 基线
- 声称「已还原乱码」而不给逐行 diff

---

## 五、不在本单

1. `Examples/` 域其余乱码还原 —— 归 `WO-20260922-AUDIT-甲-A3`。
2. `WO-20261003-MC-甲-UPDENDPOINT`（独立下载域门禁收口）。
3. `WO-20261003-MC-甲-ORPHANREG`（22 个回归单未进主测试工程）。
