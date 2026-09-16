# WO-20260916-DEEPAXIS-F4 机器语义失真独立整改工单

> **发单回执**
> - **发单时间**：`2026-09-16 15:42:52 +0800`
> - **工单文件（绝对路径）**：`D:\_Progs\02Business\DeepBase\docs\ui\work-orders\WO-20260916-DEEPAXIS-F4-机器语义失真独立整改工单.md`
> - **发单人**：主控（Amy · 沈予安）
> - **承接方**：开发甲（DeepAxis 侧）
> - **发单依据**：Human Authority 最终裁定 §三 / §四 / §十一.3
> - **关联裁定**：`WO-20260915-EHAI-DOWNSTREAM-001` 已 **CLOSED**，本工单为**切出的独立整改单**，**不阻断主链**

---

## 一、背景与定性（依裁定 §三）

**F4 事实**：
```
D:\_Progs\02Business\DeepAxis\docs\DA-131-Delivery\flight-receipt.json
  "mode": "real"                        ← 机器语义失真
  "terminal_state": "DELIVERY_CONFIRMED" ← 机器语义失真
实际生成路径：mock-injection / engine-verification
```

**主控实测（2026-09-16 15:24，锚定于 `67034a5`）**：

| 字段 | 现状 | 判定 |
| :--- | :--- | :---: |
| `mode` | 仍为 `"real"` | ❌ |
| `terminal_state` | 仍为 `"DELIVERY_CONFIRMED"` | ❌ |
| `environment_note` | 已加免责文本 | ⚠️ 仅文本 |
| 生成器根因 `tools/FirstFlightPhaseB.dpr:50`（`LMockTimestamp`）/ `:118-121`（注入式 `TimestampGetter`，每次 `+100`） | 未改 | ❌ |

**性质界定（裁定 §三）**：属 `DeepAxis delivery evidence defect`，**不是** Common Contract / EHAI semantic / Gate B / Cross-product abstraction defect → **不作为 DOWNSTREAM-001 阻断项**。

**处置口径（裁定 §四）**：采用 **「② + ③」** —— 既修机器字段与生成器根因，**同时**把现有非真机回执移出正式 Delivery Evidence。**不得只加免责说明。**

---

## 二、硬前置（主控已完成，承接方不得重复）

| 项 | 状态 | 证据 |
| :--- | :--- | :--- |
| **F4-1 证据先行固化** | ✅ **已由主控于 15:41 完成**（在任何整改动作之前） | 快照目录 `D:\_Progs\02Business\DeepBase\CodeReview\evidence\DA-131-Delivery-snapshot-20260916\`；原件 SHA256：DELIVERY 版 `c5a13f52…3095`、runtime 版 `d4a0e5a8…f26d`、README `4f835f22…cde`、00-说明 `7b590244…b177` |

> **承接方不得重做此步，亦不得以「已保护」为由跳过对保护范围的核对。**

---

## 三、整改条目（F4-1 ~ F4-6）

### F4-1｜证据保护（**主控已完成**，承接方仅需核对）

- **要求**：确认主控快照的 4 个 SHA256 与 `67034a5` 所载内容一致；如不一致**立即上报，不得自行修改**。
- **验收**：`sha256sum` 复核输出留档。
- **证据要求**：UTF-8 日志，含 4 组 `sha256 → 文件名`。

### F4-2｜当前回执不得继续作为 Real Delivery Evidence

- **对象**：`D:\_Progs\02Business\DeepAxis\docs\DA-131-Delivery\flight-receipt.json`
- **要求**：将其明确登记为
  ```
  INVALID AS REAL-FLIGHT EVIDENCE
  ```
  或**等价机器可恢复状态**，并从「正式真机 Delivery Evidence」中移出。
- **允许保留形态**：`audit sample` / `engine verification sample` / `mock-injection evidence` / `historical defect sample`。
- **严禁**：删除历史事实。

### F4-3｜修改机器字段（**核心**）

- **要求**：mock / injected execution 产生的 receipt **不得再输出** `"mode": "real"`；**不得无条件输出** `"terminal_state": "DELIVERY_CONFIRMED"`。
- **目标机器语义**（具体 enum 值由 DeepAxis 现有 schema 决定）：
  ```
  mode           → mock-injection / simulated / engine-verification
  terminal_state → 与 mock 验证相符的、非 Real Delivery 的状态
  ```
- **红线**：**禁止仅靠** `environment_note` / `README` / Markdown 说明修正机器语义。
  ```
  Human-readable Disclaimer  ≠  Machine-readable Truth
  ```

### F4-4｜修生成器根因

- **对象**：`D:\_Progs\02Business\DeepAxis\tools\FirstFlightPhaseB.dpr`（`:50`、`:116-121`）
- **要求**：生产态真实 Delivery Receipt **不得**由「人工递增 Timestamp」或「mock TimestampGetter」制造出「像真实执行」的时间序列。
- **允许**：注入时钟可保留于 `test harness` / `mock runner` / `simulation mode`，但**必须同时满足**：
  ```
  Injected Clock → Cannot Produce mode = real
  Injected Clock → Cannot Produce real DELIVERY_CONFIRMED
  ```
- **一句话**：**可以 Mock 时间，但不能 Mock 完以后仍声称自己是真机交付。**

### F4-5｜增加回归断言（机器级）

**至少**增加以下断言（**不得只测字符串说明**）：
```
Mock execution        → mode != real
Mock execution        → terminal_state != real delivery confirmed
Injected Timestamp    → cannot cross real-delivery boundary
Real delivery receipt → requires real delivery evidence path
```
- **验收**：四条断言各自可见「构造违反条件的输入 → 必 FAIL」的反向证明。
- **证据要求**：测试输出日志（UTF-8）+ 用例名；**断言须打在缺陷所在分支**（不得只覆盖最易分支）。

### F4-6｜复核范围 = 仅 F4 Delta Review

- **只做**：
  ```
  F4 Delta Review：字段 / 生成器 / 测试 / 旧回执处置 / 证据保护 / Git Object
  ```
- **不得**重跑整个 `Gate B`、`AsWish Gate C`、`Cross-Product Review`——**除非 F4 实际修改越过其声明边界**（若越界，须先申报并获得主控书面同意）。

---

## 三bis、ADDENDUM 扩充验收标准（F4-A ~ F4-E，**强制**）

> 依据 Human Authority《F4 机器语义修正与 L8 现实证据准入补充裁定》。**F4 性质正式定义为 `Machine-readable Reality Classification Defect`，而非「两个字段写错」。**

**范围扩大确认（主控已逐条核实，证据 = 本工单 §二 冻结快照 `c5a13f52…3095`）**：以下整条机器可读事件链均将 mock/engine verification 表达为 real delivery：

| 位置 | 现值 | 核实 |
| :--- | :--- | :---: |
| `mode` | `"real"` | ✅ 存在 |
| `terminal_state` | `"DELIVERY_CONFIRMED"` | ✅ 存在 |
| `audit_trail[].kind` = `f2b_mode_real_declared` | detail `"[F2B][MODE=REAL] real dispatch armed"` | ✅ 存在 |
| `audit_trail[].kind` = `f2b_first_flight_confirmed` | detail `"first_flight_gate_armed"` | ✅ 存在 |
| `audit_trail[].kind` = `f2b_uia_paste_executed` | detail `status=executed;…` | ✅ 存在 |
| `audit_trail[].kind` = `f2b_receipt` | detail `"delivery_confirmed"` | ✅ 存在 |
| `dispatch_success` | `true` | ✅ 存在 |

### F4-A｜执行模式语义
mock / injected execution **MUST NOT** produce `mode = real`。

### F4-B｜终态语义
mock / engine verification **MUST NOT** produce real-world `DELIVERY_CONFIRMED`。如需「验证成功」状态，须使用与 `engine verification` / `simulation` / `mock execution` 语义一致的**独立终态**。

### F4-C｜Audit Trail
Audit Trail 中任何机器事件**不得**继续表达 `real dispatch armed` / `first flight confirmed` / `real delivery confirmed`，**除非确实存在真实设备 / 真实执行证据**。必须保证：
```
Mock Execution → Mock / Engine Verification Events
（而不是 → Real Delivery Events）
```

### F4-D｜`dispatch_success` 语义（**新增独立检查项**）
须独立检查 `dispatch_success` 的协议含义：
- 若真实含义仅为 `engine / dispatcher path succeeded` → **可保留**，但须通过 schema / 字段定义使其**不会被解释成 real-device dispatch succeeded**；
- 若字段天然包含现实发送含义 → 必须**拆分 / 重命名 / 增加明确机器级分类**。
必须保持：
```
Engine Dispatch Success  ≠  Real-device Dispatch Success  ≠  Delivery Confirmation
```

### F4-E｜生成器
`tools/FirstFlightPhaseB.dpr` 的注入式时间路径可保留于 `test` / `mock` / `engine verification`，但：
```
Injected Timestamp / Mock Clock
→ 不得进入能够生成 mode=real / real first-flight / real delivery confirmation 的状态路径
```

### F4-F｜历史问题回执**不得被覆盖**（强化 F4-2）
现存问题 JSON 须先 `copy + hash + preserve provenance`（**主控已于 15:41 完成**），作为 `Historical F4 Defect Evidence` 保留。**不得**「直接覆盖旧文件 → 再声称旧问题已不存在」。历史原件**只能**：
```
标记失效 / 移动至审计样本区 / 建立 manifest 引用
```
**不得静默销毁。**

### F4-G｜新增自动化验收断言（机器级）
至少建立：
```
Mock execution        → mode != real
Mock execution        → no real-flight confirmation event
Mock execution        → no real-delivery terminal state
Injected clock        → cannot cross real-delivery boundary
```
**并增加 `Machine consumer test`**：该测试**不得**读取 `environment_note` / `README` / 任何人工说明，**只消费结构化字段**。
**测试目标**：任何**仅依赖机器字段**的正常消费者，都不能把 mock verification 合理解释为真实首飞成功。
**只有满足这一条件，`F4 = CLOSED`。**

---

## 四、执行纪律（本链血案教训，强制）

| # | 纪律 | 说明 |
| :-: | :--- | :--- |
| 1 | **禁止销毁性 git 操作** | 严禁 `git checkout --` / `git restore` / `git clean` / `git reset --hard` 处置**非本工单产出**的工作区改动。让渡基线须用 `git stash` 或临时 worktree（**保全改动**）。 |
| 2 | **脏区定性须分三类** | 纯噪声（工具产物）／**未提交的历史已过审交付（不可销毁）**／本工单改动。**不得**笼统写「既有脏区、与本次无关」。 |
| 3 | **先提交、后验证才算账** | `交付的生命周期保障 ≤ 交付是否进入版本控制`。**未提交的交付 = 未交付。** |
| 4 | **禁止自报 PASS 文本** | 门禁数字必须来自日志/产物，不得来自对脚本的想象。 |
| 5 | **停等纪律** | 声明「已停等」之后**不得再有提交**；若确有后续提交，须**先提交再声明**，不得倒序。 |
| 6 | **基线件固化** | 今后任何逆向/还原类取证，**必须先行 `copy + sha256`** 固化基准镜像（F1 教训）。 |

---

## 五、须提交的证据（缺一不可）

1. **旧回执处置证明**：`docs/DA-131-Delivery/flight-receipt.json` 的最终机器可读内容 + `INVALID AS REAL-FLIGHT EVIDENCE`（或等价）登记位置。
2. **新字段 schema 说明**：`mode` / `terminal_state` 的 enum 定义位置（file:line）。
3. **生成器 diff**：`tools/FirstFlightPhaseB.dpr` 的改动 diff（含行号）。
4. **回归断言日志**：F4-5 四条断言的正反两向输出（UTF-8，含用例名）。
5. **F4 Delta Review 结论**：逐项对照表 + 明确声明「未越界」。
6. **Commit SHA**（40 位，须 `git rev-parse` 取值，**禁止补全**）+ `git branch -a --contains` 非空证明。

---

## 五bis、执行顺序与判定权（Human Authority 2026-09-16 §七 指定）

**承接方**：当前串行多仓开发 AI（开发甲）｜**Owner Repo** = `DeepAxis`
**立即进入本单**；在 **F4 CLOSED 前禁止其它非必要 DeepAxis 功能开发**。

### 执行顺序（严格按序）

```
Step 1   保护现有 F4 原件 / SHA256 / provenance   ← ✓ 主控已完成，不得破坏
Step 2   修 mode machine semantics
Step 3   修 terminal_state
Step 4   修 audit_trail reality semantics
Step 5   检查 / 修正 dispatch_success 定义
Step 6   隔离 mock clock / TimestampGetter，不得跨入 real delivery path
Step 7   增加 Machine Consumer Test
Step 8   全量相关 regression
Step 9   isolated commit
Step 10  独立 F4 Delta Review
```

### 判定权（**关键**）

```
开发甲 不得自己宣布：F4 = CLOSED
开发甲 只能提交：    READY FOR F4 DELTA REVIEW
判定方：            主控 / 独立审计
```

> **自宣 CLOSED 一律不予采信**，且构成「措辞替代动作」。

---

## 六、验收标准

```
[ ] F4-1  快照 4 组 SHA256 复核一致，无重做、无篡改
[ ] F4-2  旧回执已登记 INVALID AS REAL-FLIGHT EVIDENCE（或等价），历史事实未删除
[ ] F4-3  机读字段不再输出 mode="real" / 无条件 DELIVERY_CONFIRMED
[ ] F4-4  注入时钟无法产出 mode=real 与 real DELIVERY_CONFIRMED
[ ] F4-5  四条机器级断言到位，且各有反向证明
[ ] F4-6  F4 Delta Review 完成，明确声明未越界重跑
─── ADDENDUM 扩充（F4-A ~ F4-G）───
[ ] F4-A  mock/injected execution 不产出 mode=real
[ ] F4-B  mock/engine verification 不产出 real-world DELIVERY_CONFIRMED（改用独立终态）
[ ] F4-C  audit_trail 不再出现 real dispatch armed / first flight confirmed / real delivery confirmed
[ ] F4-D  dispatch_success 语义独立检查；Engine ≠ Real-device ≠ Delivery Confirmation 三者可机器区分
[ ] F4-E  注入时钟不得进入可生成 real 语义的状态路径
[ ] F4-F  历史原件仅「标记失效/移入审计样本区/manifest 引用」，不得覆盖、不得静默销毁
[ ] F4-G  四条断言 + Machine consumer test（仅消费结构化字段、不读免责文本）通过
[ ] 纪律   六条执行纪律全部遵守（尤其 §4.1 无销毁性 git 操作）
```

**F4 = CLOSED 的充要条件**：**F4-A ~ F4-G 全部满足**（不得再以「改了 `environment_note`」或「只改了 `mode`」作为 CLOSED 条件）。

---

## 七、措辞与边界红线

- 本工单**不改变** DOWNSTREAM-001 的 CLOSED 状态；F4 为**旁路独立整改**。
- 本工单**不得**外推任何 EHAI L8 表述；仍受 `Cross-product engineering reuse evidence` 上限约束。
- **严禁**将本工单产出物送入 L8 Empirical Case 001 证据集（裁定 §十）。

**止于 F4 Delta Review，不得扩张范围。**
