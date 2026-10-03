# WO-20261003-MC-甲-HBGATE6 句柄泄漏断言稳定性（主控派单 · P2）

**单号**：`WO-20261003-MC-甲-HBGATE6`
**派单**：主控（2026-10-03，ORPHANREG 验收观察项 + 主控全量跑实测）
**优先级**：P2 —— 它是**当前全量套件唯一一道 `Failed`**，但两次跑出两种不同的失败形态
**前置**：主控全量跑 `/tmp/dbrun/fullrun-20261003.log`（master @ `cf5da64`）

---

## 〇、两次实测读数（异构，这是本单的出发点）

| 跑者 | 基线 | 用例 | 失败消息 |
|---|---|---|---|
| 开发甲（ORPHANREG） | `d5c93a2` | `Test.DeepBase.HB.Benchmark.TTestHbBenchmark.Gate6_TenThousandInstances_ZeroGdiAndHeapLeak` | `[HB Gate #6 VIOLATION: USER handle leak round 2 (before=34 after=35 delta=1)]` |
| 主控（全量跑） | master @ `cf5da64` | 同一条用例 | `[HB Gate #6 VIOLATION: GDI leak round 1 (before=42 after=64 delta=22)]` |

**同一条用例、两次跑、两种失败形态（USER 句柄差 1 / GDI 句柄差 22）。**

⇒ 要么它真的 flaky（进程环境里残留句柄），要么它测到的是一个**偶发泄漏**，只是泄漏对象在两次运行间不同。这两种解释的处置完全不同，本单必须分清。

---

## 一、判据（主控验收用）

| # | 判据 | 达成标准 |
|---|---|---|
| 1 | 判定 flaky 还是真漏 | **同一基线连续跑 ≥5 次**，给出每次的失败形态/通过情况表。5 次全过 ⇒ 记录为环境敏感并给出使能条件；有失败 ⇒ 进入判据 2 |
| 2 | 泄漏点指名 | 若存在真实泄漏，指名是哪个对象的哪个构造/析构不平衡，给代码行号（不许写「可能是 HB 层」） |
| 3 | 测量口径核实 | 该用例的句柄采样点在哪、`before/after` 之间隔了什么、是否可能把**测试框架自身**或其他 fixture 的句柄算进来。亲读用例全文 |
| 4 | 与 `Memory` 记录的老红无关性 | 主控 memory 记 2026-10-01 全量唯一红是 `Resilience.Timeout.PBT`（`Errored`），当时 `Failed 0`。本单要解释：**HB Gate #6 是何时开始红的**（用 `git log -L` 或隔离树切点，而不是猜） |
| 5 | 处置 | ① 真漏 ⇒ 修产品 ② 测量口径错 ⇒ 改用例 ③ 纯环境敏感 ⇒ 给出**确定性**的隔离方案（如独立进程/固定 fixture 顺序），**不许加 `Retry` 或提高阈值糊过去** |
| 6 | 阴性对照 | 故意注入一个句柄泄漏（造一个不释放的对象），证明该用例真的能抓到 |
| 7 | 四门 + 纪律 | eol/encoding/mojibake/evidence-encoding 全 EXIT=0；一笔 H15；禁 push；台账状态槽不改 |

---

## 二、授权面与禁动区

**授权**：`Tests/**`（HB 测试件）、`CodeReview/20261003-AUDIT-甲-HBGATE6-证据/**`。

**禁动**：`Core/**`、`contracts/**`、`Features/**`、`09_工程脚本/**`、`Scripts/**`、`noise-baseline.json`、`Governance/**`、`VCL/**`、`FMX/**`。

**若判据 5 判为「修产品」**，需先指名要改哪个产品文件，由主控**另行解禁**；本单授权面内不得动产品代码。

**明令禁止**：
- 加 `Assert.Ignore` / `SKIP` / `Retry` / 放宽阈值
- 删用例
- 把两次异构读数说成「同一次运行」或当成噪声一笔带过

---

## 三、不在本单

1. `Resilience.Timeout.PBT Property6_TimeoutCancelsBackgroundTask` 的 AV —— 归 `WO-20261002-MC-甲-F2`。
2. 7 处断言与产品分歧 —— 归 `WO-20261003-MC-甲-ORPHANRED`。
3. 11 处 `Assert.Pass` 假绿 —— 归 `WO-20261003-MC-甲-FAILCLOSED`。
4. 全量套件的「存量红清单」重整 —— 主控自办（见派单总表当日第八批）。
