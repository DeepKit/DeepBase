# WO-20260917-EHAI-L8-E001-START-001｜Case 001 Observation Start Declaration

- **工单性质**：**Observation Lifecycle Event（观察生命周期事件）** —— 非开发工单，不产出代码，不修改任何被测产品
- **状态**：`DECLARED`
- **Observation Case ID**：`L8-E001`
- **宣告时间（Observation Start）**：`2026-09-17`（当地时间 GMT+8）
- **依据**：
  - `docs/ui/work-orders/L8-E001-Observation-Protocol.md`（v1，`FROZEN FOR CASE 001`）
  - `CodeReview/20260917-EHAI-L8-E001-OBS-GAP-001-R3-终验复审结论.md`（Phase 2 终验 = CLOSED，含 N-3 终验附记与 START 放行）
- **宣告方**：主控（Amy · 沈予安）
- **授权方**：Human Authority（老板）
- **观测窗口**：Start `2026-09-17` → End `2026-10-14`（28 天）；Midpoint `2026-09-30`

---

## 一、Start 宣告

```
Case 001 — OBSERVATION STARTED
Time: 2026-09-17（GMT+8）
Status: ACTIVE
```

**本宣告只做一件事：定位并冻结观察起点。** 在此刻之前的一切工作（理论构建、规范建立、工程能力、可复核性证明）为**建设期**；自此进入**现实世界观察阶段**。

**评价标准自此切换**：

| 建设期问句 | 观察期问句 |
| :--- | :--- |
| 系统有没有设计出来？ | 在真实使用中，是否产生了**可观察、可归因、可复现**的现实结果？ |

对应 L8 三个 Root：

- **R1 Outcome Integrity**（现实结果完整性）
- **R2 Attribution Integrity**（效果归因完整性）
- **R3 Empirical Claim Integrity**（经验主张完整性）

---

## 二、观察起点锚点（Observation Start Anchor）

> 取证方式：`git rev-parse HEAD` 三仓实测 + 协议 `sha256` 实测；取证时间 2026-09-17 16:25 +0800。

| 标的 | 锚定值 | 说明 |
| :--- | :--- | :--- |
| **Protocol 正源** | `747079c8706a6f4166b3b426b99d78f25be9f0c78d2302646644072dc5f0de88` | `L8-E001-Observation-Protocol.md` v1，FROZEN，观察期内不得改动 |
| **DeepBase HEAD** | `fcb856db7efd9164015f2a603f989f1194a4cf25` | 证据基座、双 Manifest、干预登记表、R3 结论已入库（含本工单前序提交） |
| **AsWish HEAD** | `7624a1d09da164b60d3a6deffb2d4c1127383548` | WO-0030 尖兵样本已入库受控（N-3 闭环） |
| **DeepAxis HEAD** | `f47c57320f0a8343de16bd188e507aab8ef0139d` | **（N-5 校准结果）** 以此为 AXIS 观察基线；替代原报告所述 `82e57ea` |
| **Observation Evidence Base** | `DeepBase/evidence/L8-E001/` | 受 Git 跟踪的唯一官方证据归档落点 |
| **Comparison Baseline** | `evidence/L8-E001/baselines/aswish-historical-manifest.json`（51 文件 SHA256）<br>`evidence/L8-E001/baselines/axis-historical-manifest.json`（56 文件 TRACKED_IN_GIT） | Comparison B 历史对照，已受控 |
| **F4 Status** | `EXCLUDED until Delta Closure` | F4 受影响 AXIS 证据**不得通过 Admission Gate**（详见 §四） |

**N-5 处置（本工单即为其闭环载体）**：DeepAxis 观察基线由 `82e57ea` **校准登记为 `f47c573`**（实测当前 HEAD，DA-133 密钥重构，与 L8 证据面零交集；`docs/_archive/` 受跟踪数在新 HEAD 下仍 = 56，Manifest 断言继续成立）。据锚点纪律，此前绑定 `82e57ea` 的裁定依然有效，不因本次校准失效。

---

## 三、Observation Rules（观察规则，引用协议 v1）

1. 全部观察行为与证据记录遵循 `L8-E001-Observation-Protocol.md`（v1），**不得自行增删或变通**。
2. **Observation Unit** = 一次完整 Human-AI Task Episode；**必须保留题面**（防 hindsight 污染）。
3. **Episode Record 最小字段 = 协议 §3 的 26 项**（AsWish 18A/8B/0C、AXIS 19A/7B/0C，阻断缺口 = 0）。
4. **Model / Intervention Event 分段统计，禁混池**：`L8-E001-Intervention-Registry.md` 为唯一登记表；初始模型均锁定 `deepseek-chat`（DeepSeek-V3）。
5. **证据四层 E0–E3 强制追溯**；**Claim Ladder E0–E4** 逐级晋级（E4 单靠 Case 001 不可达）。
6. **Counterexample 强制单独成章**；禁止单一合成分数；三出口 A/B/C。
7. **每次 Episode 只记录五项链路**：

```
Episode
  ↓
Evidence
  ↓
Decision
  ↓
Outcome
  ↓
Attribution
```

---

## 四、当前限制（Explicit Constraints）

```
F4 affected AXIS evidence  ──→  EXCLUDED
                                 until F4 Delta Closure
```

- **F4 不阻止 L8 开始**；但 F4 影响部分 **AXIS Outcome Evidence 的准入**（`Reality Evidence Admission Gate`）。
- F4 受影响证据**可记录、可保留 Raw Evidence，但不得晋级（不得通过入场门）**。
- F4 作为**并行整改线**继续推进，不干扰 L8 启动。
- 涉及 AXIS 的 Episode，须在 `raw_evidence_ref` 中显式标注该证据是否落入 F4 影响面。

**禁止事项（本阶段禁令）**：

- ❌ `EHAI proven`
- ❌ `产品有效`
- ❌ `价值提升`
- ✅ 只允许：`Observation Started`

---

## 五、本阶段纪律（老板 §五，防"造体系"）

**明确禁止进入**：L8 平台设计 / 数据平台设计 / 自动分析系统 / 实验管理系统 / 统一埋点 / AI 评估平台。

**理由**：现在缺的不是工具，而是——`真实 Episode + 真实 Outcome + 真实 Attribution + 真实 Claim Boundary`。

> **No Gap → No Code**（协议 §16）。Phase 3 已因 `Observation Blocking Gaps = 0` 合法跳过。

---

## 六、下一动作

1. **本工单宣告 START**（本文件即宣告载体）。
2. **开始收集第 1 个真实 Episode**，按 §三.7 五链记录；证据镜像落 `DeepBase/evidence/L8-E001/`，当日 commit 入库（依据 `evidence/L8-E001/README.md` 归档纪律）。
3. **不再开 EHAI 理论讨论**；F4 并行线独立推进。

---

## 七、元观察登记（Evidence Anchor Drift）

本链已累计的**证据锚点漂移**现象，作为 L8 观察期的元观察项（**不扩大为工程治理项目**）：

| 类型 | 实例 |
| :--- | :--- |
| 哈希层漂移 | R2 声明 commit 前 7 位对/后 33 位错（N-1） |
| 草稿版本漂移 | 报告自述 HEAD 过时（A-1，自指不可能性） |
| README 状态漂移 | WO-0030「已进入版本控制」实为未跟踪（N-3） |
| **Git HEAD 漂移** | 报告称 `82e57ea`，实际 `f47c573`（N-5，本工单校准） |
| 交付消息引用漂移 | 跨样本文件清单张冠李戴（N-4） |

**处置定性**：以上均为 `Evidence Anchor Drift（证据锚点漂移）` 的不同表现，纳入 L8 经验观察，**不作为新的工程治理项目**。

---

- **落盘人**：Amy（沈予安）／主控
- **宣告时间**：2026-09-17 16:31 +0800
- **锚定对象**：DeepBase `fcb856db7efd9164015f2a603f989f1194a4cf25`｜AsWish `7624a1d09da164b60d3a6deffb2d4c1127383548`｜DeepAxis `f47c57320f0a8343de16bd188e507aab8ef0139d`｜协议 v1（`747079c8…0de88`）
