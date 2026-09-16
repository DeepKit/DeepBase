# WO-20260916-EHAI-L8-EMPIRICAL-001 + F4 补充裁定｜落地执行回执

> **执行对象**：①《EHAI L8 Empirical Case 001 总工单》②《F4 机器语义修正与 L8 现实证据准入补充裁定》
> **执行人**：主控 / 资料员（Amy · 沈予安）
> **执行时间**：**2026-09-16 15:53 ~ 15:58 +0800**
> **执行性质**：不重开 DOWNSTREAM-001 / Gate B / AsWish·AXIS Gate C / EHAI L1-L8

---

## 〇、结论

```
========================================================================
① ADDENDUM §一 事实核验       → 逐条成立（事件链完整存在）
② F4 工单                      → 已扩充为 F4-1~F4-6 + F4-A~F4-G（v1.1）
③ L8 总工单 STEP 1（资料员建 Protocol） → ✅ 已建立 L8-E001 Observation Protocol v1
④ 旧 L8 前置工单               → 已标 SUPERSEDED（防平行文件漂移）
⑤ L8 前置工单 §五 F4 隔离清单  → 已升格为「准入门执行细则」沿用
========================================================================
```

**DOWNSTREAM-001 仍为 CLOSED**；工程结论上限仍为 `Cross-product engineering reuse evidence`。

---

## 一、ADDENDUM §一 事实核验（主控亲验）

**证据源**：冻结快照 `D:\_Progs\02Business\DeepBase\CodeReview\evidence\DA-131-Delivery-snapshot-20260916\flight-receipt.DELIVERY-original.json`
**SHA256**：`c5a13f527bc261da8ee9e9b330a99938db61e786da76ee1c2f511eebdd903095`（与 15:41 固化值一致，未被改动）

| ADDENDUM §一 所列举项 | 实测 | 判定 |
| :--- | :--- | :---: |
| `mode = "real"` | 存在 | ✅ |
| `terminal_state = "DELIVERY_CONFIRMED"` | 存在 | ✅ |
| `audit_trail`: `f2b_mode_real_declared` / detail `"[F2B][MODE=REAL] real dispatch armed"` | 存在 | ✅ |
| `audit_trail`: `f2b_first_flight_confirmed` / detail `"first_flight_gate_armed"` | 存在 | ✅ |
| `audit_trail`: `f2b_uia_paste_executed` / detail `status=executed;capability=send.execute_uia_paste` | 存在 | ✅ |
| `audit_trail`: `f2b_receipt` / detail `"delivery_confirmed"` | 存在 | ✅ |
| `dispatch_success`（§二 F4-D 新增检查项） | `true`，存在 | ✅ |

**结论**：老板「**F4 并非两个字段的孤立错误，而是整条机器可读事件链将 mock / engine verification 表达为 real delivery**」之定性，**与实物完全吻合**。F4 正式定义为 `Machine-readable Reality Classification Defect`。
**完整字段集**：`stage / environment_note / timestamp / mode / dispatch_success / terminal_state / contact_id / grant_id / error / audit_trail`。

---

## 二、F4 工单已扩充（v1.1）

**文件**：`D:\_Progs\02Business\DeepBase\docs\ui\work-orders\WO-20260916-DEEPAXIS-F4-机器语义失真独立整改工单.md`

**新增 §三bis（ADDENDUM 扩充验收，强制）**：

| 条目 | 内容 |
| :--- | :--- |
| **F4-A** | mock / injected execution **MUST NOT** produce `mode = real` |
| **F4-B** | mock / engine verification **MUST NOT** produce real-world `DELIVERY_CONFIRMED`；须用与 mock 语义一致的**独立终态** |
| **F4-C** | audit_trail 不得再表达 `real dispatch armed` / `first flight confirmed` / `real delivery confirmed`（除非真有真机证据） |
| **F4-D** | `dispatch_success` 语义独立检查；`Engine Dispatch Success ≠ Real-device Dispatch Success ≠ Delivery Confirmation` |
| **F4-E** | 注入时钟不得进入可生成 `mode=real` / real first-flight / real delivery confirmation 的状态路径 |
| **F4-F** | 历史原件**不得覆盖/静默销毁**，只能「标记失效 / 移入审计样本区 / manifest 引用」 |
| **F4-G** | 四条断言 + **`Machine consumer test`**（**只消费结构化字段、不读 `environment_note`/README/人工说明**） |

**CLOSED 充要条件已更新**：**F4-A ~ F4-G 全部满足**；不得再以「改了 `environment_note`」或「只改了 `mode`」作为 CLOSED 条件。

---

## 三、L8 总工单 STEP 1 已执行（资料员建 Protocol）

**文件**：`D:\_Progs\02Business\DeepBase\docs\ui\work-orders\L8-E001-Observation-Protocol.md`
**Protocol Version**：`v1`　**Status**：`PRE-REGISTRATION`（**未冻结前不得采集任何正式观察数据**）

已按总工单 §四 冻结项 + §六~§三十七 逐条落为可执行协议（23 节），要点：

| 节 | 内容 |
| :--- | :--- |
| §2 | 12 项预登记冻结清单（含 v1 提案值） |
| §3 | Observation Unit = `一次完整 Human-AI Task Episode` + 最小 Episode Record 字段集 + **必须保留「题面」**（防 hindsight） |
| §4 | R1 六类指标 O1–O6 + 「工程指标不得冒充现实指标」 |
| §5 | R2：强制反事实 + Comparison A/B/C + 11 项干扰变量 + Model Change Event + Intervention Event |
| §6 | R3：Claim Ladder E0–E4（**E4 单靠 Case 001 不可达**） |
| §7 | Evidence Set 四层 E0–E3 + 强制追溯链 |
| **§8** | ⭐ **Reality Evidence Admission Gate**（5 项最低条件，来自补充裁定 §五） |
| §9 | F4 污染数据**永久**隔离 + 修复后有效起点规则 |
| §10 | 严重事故优先记录 |
| §11 | 28 天窗口 / 20+20 样本 / Early Stop |
| §13 | 冻结程序（Observation Freeze Point） |
| §14 | 主观数据边界（`Observed Behavior ≠ Human Subjective Judgment`） |
| §16 | 分析顺序 Step1–7 + **Counterexample 强制单独成章**（缺章不得 CLOSED） |
| §18 | 三个出口 A/B/C |
| §19 | DA-131B gap 不得反向声称源码已恢复 |
| §21 | Protocol Amendment 规则（禁止静默修改） |
| §22 | 待 Human Authority 确认 7 项 |

**核心不等式已写入协议**：
```
Claim Strength ≤ Available Empirical Evidence
Machine-readable Reality Claim ≤ Real-world Evidence
Disclaimer cannot downgrade a false machine claim into a true claim
Engineering Conformance Evidence ≠ Empirical Effect Evidence
```

---

## 四、旧前置工单已标 SUPERSEDED（防平行文件漂移）

`WO-20260916-EHAI-L8-CASE001-观察协议前置工单.md` 已在页首登记：
- 取代者 = 老板《L8 总工单》+《F4 补充裁定》；取代登记时间 `2026-09-16 15:53 +0800`
- **保留为历史前置件**（不得静默销毁），其 **§五 F4 隔离清单** 升格为**准入门执行细则**沿用
- 现行执行件 = `L8-E001-Observation-Protocol.md`

---

## 五、待 Human Authority 裁定/指定（7 项）

| # | 事项 | 备注 |
| :-: | :--- | :--- |
| 1 | 观察起始日 `Start Date` | 决定后写入冻结登记 |
| 2 | 样本下限是否维持 `20+20` | v1 提案值 |
| 3 | `28 natural days` 窗口是否调整 | v1 提案值 |
| 4 | Comparison B 的具体非 EHAI 对照流程 | 需指定真实可比流程 |
| 5 | 主观自report 是否启用及频度 | v1 提案：自愿、Episode 结束时 |
| 6 | **协议冻结执行人**（§13 须提交 Git Object） | 主控 or 开发方 |
| 7 | **F4 工单承接方与承接时间** | 总工单 STEP 0 亦待指定 |

---

## 六、后续（依总工单 §三十五，尚未开始）

```
STEP 0  F4 修复 或 严格排除            → 排除已永久生效；修复待承接方
STEP 1  Protocol v1                    → ✅ 本次完成（待冻结）
STEP 2  Observation Gap Assessment     → 开发 AI，未开始
STEP 3  确认现有日志/Evidence 是否已足够 → 未开始
STEP 4  仅当有 Observation Blocking Gap 才开最小工程单 → 未开始
STEP 5  Protocol 固定形成 Git Object    → 待 §五.6 裁定
STEP 6  Human Authority 宣布 START      → 待裁定
```

---

## 七、产物索引（绝对路径）

| 类别 | 路径 |
| :--- | :--- |
| F4 工单（v1.1，含 ADDENDUM 扩充） | `D:\_Progs\02Business\DeepBase\docs\ui\work-orders\WO-20260916-DEEPAXIS-F4-机器语义失真独立整改工单.md` |
| **L8-E001 Observation Protocol v1** | `D:\_Progs\02Business\DeepBase\docs\ui\work-orders\L8-E001-Observation-Protocol.md` |
| L8 前置工单（已标 SUPERSEDED） | `D:\_Progs\02Business\DeepBase\docs\ui\work-orders\WO-20260916-EHAI-L8-CASE001-观察协议前置工单.md` |
| F4 冻结快照（4 件 sha256） | `D:\_Progs\02Business\DeepBase\CodeReview\evidence\DA-131-Delivery-snapshot-20260916\` |

---

## 八、执行声明

- 本次**未修改任何源码、未产生任何新提交**；三仓锁定的 Audited Git Object 未变。
- F4 冻结快照 sha256 经复核**未被改动**（`c5a13f52…3095`）。
- 本回执与 Protocol 均遵守裁定 §九 最终原则：**机器字段如果说「真的发生了」，那就必须真的发生了。**
