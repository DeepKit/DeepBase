# L8-E001 Observation Active 执行口径（Execution Policy）

- **文件性质**：**Observation Governance Record（观察期治理登记件）** —— 非开发工单，零代码，不改变任何产品行为
- **效力来源**：Human Authority（老板）2026-09-18 确认口径
- **状态**：`OBSERVATION ACTIVE`
- **Effective Start**：`2026-09-17`
- **依据**：`docs/ui/work-orders/L8-E001-Observation-Protocol.md`（v1 FROZEN）｜`WO-20260917-EHAI-L8-E001-START-001-Case-001-Observation-Start-Declaration.md`

> Human Authority 确认：
> ```
> L8 Empirical Case 001 = OBSERVATION ACTIVE
> Effective Start = 2026-09-17
> ```
> 既有 START 生命周期事件、Protocol v1、Evidence Base、Episode Template 均接受。
> **自此停止继续建设 Case 001 启动基础设施，进入真实 Episode 观察。**

---

## 一、START Anchor 永久固定

**Case 001 START 时刻锚点（此后不再更新）**：

| 标的 | 永久锚定值 |
| :--- | :--- |
| Protocol | `747079c8706a6f4166b3b426b99d78f25be9f0c78d2302646644072dc5f0de88` |
| DeepBase START Anchor | `339fe4a7456303c1dc49eb11e2deec4960efbcca` |
| AsWish | `7624a1d09da164b60d3a6deffb2d4c1127383548` |
| DeepAxis | `f47c57320f0a8343de16bd188e507aab8ef0139d` |

**规则**：

```
后续新 commit  ≠  START Anchor 更新
```

任何后续 commit 只能归入下列四类之一，分别登记（见 §二 登记表）：

| # | 类别 | 判据 |
| :-: | :--- | :--- |
| 1 | `Observation Infrastructure Change` | 只动观察工具/模板/清单/记录格式/README，**不改变用户实际体验或产品行为** |
| 2 | `Product Intervention` | 改变**候选 / Decision / Authority / Commitment / UI / AI Prompt / 模型 / 执行行为** 中任一项 |
| 3 | `Evidence Maintenance` | 只做证据归档、索引、勘误、受控状态校准 |
| 4 | 普通后续开发 | 与 Case 001 无关的既有工单链开发 |

---

## 二、START Anchor 之后的 commit 分类登记

> 登记时间 2026-09-18 08:2x +0800；取证方式 `git log --format='%h | %ci | %s' <anchor>..HEAD`。

### DeepBase（Anchor `339fe4a` 之后）

| commit | 时间 | 类别 | 说明 |
| :--- | :--- | :--- | :--- |
| `ea6fb86` | 2026-09-17 16:32:18 | `Observation Infrastructure Change` | Episode Record 模板入库（26/26 字段） |
| `c7d3813` | 2026-09-17 16:32:36 | `Observation Infrastructure Change`／Evidence Maintenance | R3 结论追加 START 宣告附记二 |
| 本件（含模板修订与干预登记） | 2026-09-18 | `Observation Infrastructure Change` | 执行口径落盘 + 模板命名对齐 + 干预登记 |

### DeepAxis（Anchor `f47c573` 之后）—— ⚠️ 含 Product Intervention

| commit | 时间 | 类别 | 说明 |
| :--- | :--- | :--- | :--- |
| `c3215d3` | 2026-09-17 18:29:55 | **`Product Intervention`** | `fix(da-136)` DataStore 搬迁收尾（影响数据存储位置与测试锚定） |
| `3b9f135` | 2026-09-17 18:52:33 | **`Product Intervention`** | `feat(da-137-t1)` **明文库消费通路**（`DecryptedDataPath` 直接消费外部明文 SQLite ⇒ 改变数据通路） |
| `e389cd5` | 2026-09-17 18:52:51 | **`Product Intervention`** | `feat(da-137-t2)` **hook 取钥移植**（Profile 门禁 + 版本自检 ⇒ 改变执行行为与门禁） |
| `77fad21` | 2026-09-17 18:52:54 | Evidence Maintenance | `docs/21 §三` 双轨数据路径修订（文档） |
| `d775e34` | 2026-09-17 18:54:33 | Evidence Maintenance | 开发请求审核报告 + tasks.md 登记 |
| `21e5ee2` | 2026-09-17 23:09:05 | Evidence Maintenance | 主控复审报告 + 工单归档 |
| `5efc812` | 2026-09-17 23:31:57 | Evidence Maintenance | DA-137-T2 主控复审 |
| `10d16ba` | 2026-09-17 23:47:58 | Evidence Maintenance | DA-140 派单 |
| `8998aba` | 2026-09-17 23:57:45 | Evidence Maintenance | DA-140 T2 证据补交 |
| `d98f2fd` | 2026-09-18 08:23:11 | Evidence Maintenance | DA-139 主控复审 + DA-141 派单 |

**F4 相关性核查**：上述 DeepAxis 变更经 `git log --name-only` 检索，**未触及** `F2B` / `Engine` / `flight-receipt` / `receipt` 相关文件 ⇒ 与 F4 影响面**无交集**，不触发 §七 的排除条款。

**⚠️ 对 R2 Attribution 的直接影响（须登记，不提前裁决）**：
- AXIS 观察期间，产品已发生 **3 项 Product Intervention**（DataStore 迁移 / 明文库消费通路 / hook 取钥）。
- 依协议 §5.5 与 R2「Model / Intervention Event 分段，禁混池」，**跨这些干预的 Episode 不得混池统计**；归因须按 Intervention Event 分段。
- START Anchor 登记的 AXIS 基线 `f47c573` 与该批干预的关系：**基线保留不动**（§一 规则），干预按 §二 登记；运行版以 Episode 的 `software_commit` 如实承载（§三）。

---

## 三、执行口径（Human Authority 十项，逐条固化）

### 1. START Anchor 永久固定
见 §一。后续 commit ≠ anchor 更新，须分别登记。

### 2. Episode 必须来自真实任务
**不得**为 Case 001：设计容易成功的任务 / 刻意制造 EHAI 使用场景 / 重复做已知答案的任务 / 挑选漂亮案例进入数据集。
Episode 应来自 **Human 原本就需要完成的真实 AsWish / AXIS 工作**。
**失败、放弃、返工、Frame Rejection 同样必须进入观察。**

### 3. `software_commit` 记录实际运行版本
必须保持：
```
Recorded software_commit  ==  Actually Executed Software Version
```
**不得**机械写 `git rev-parse HEAD` 代替真实运行版本。
若运行二进制与 Git Commit 的对应关系不能确立：
```
software_commit = NOT ESTABLISHED
```
并**同时登记原因**。**不得推测。**

### 4. Observation Infrastructure 与 Product Intervention 分开
属于 Observation Infrastructure：Episode Template / Manifest / Evidence README / observation extraction script / 记录格式机械修正。
只要**没有改变用户实际体验或产品行为** ⇒ **不得登记为 Product Intervention**。
若改变了以下任一项 ⇒ **必须登记 Product Intervention**：
```
候选 / Decision / Authority / Commitment / UI / AI Prompt / 模型 / 执行行为
```

### 5. 首个 Episode 不设"特殊待遇"
Episode 001 与后续 Episode 使用**完全相同**的 Protocol / Evidence Admission / 字段要求 / Claim Boundary。
不得因"第一个案例"而额外包装。
**Episode ID 规范**：
```
L8-E001-ASWISH-0001
L8-E001-AXIS-0001
```
之后**单调递增**。

### 6. Episode 结束后的顺序（禁止倒置）
```
1. Preserve Raw Evidence
2. 填 Episode Record
3. 建 Evidence References
4. 判断 Reality Evidence Admission
5. 当日进入受控 evidence base
6. Git commit
```
**禁止**：先写效果结论 → 再整理 Episode。

### 7. F4 边界继续有效
```
AXIS Episode                        = 可以记录
F4 affected raw evidence            = 可以保存
F4 affected Real-world Outcome Evidence = EXCLUDED
```
不得因 Observation 已 START 而放宽准入条件。

### 8. 现在不做阶段结论
当前只允许形成：`Episode Facts` / `Evidence` / `Outcome Record` / `Self-report` / `Incident` / `Intervention`。
**暂不形成**：`EHAI 有效` / `EHAI 无效` / `AsWish 改善了多少` / `AXIS 提升了多少`。
这些属观察结束后的 **R1 → R2 → R3** 分析阶段。

### 9. 下一正式检查点
无 Early Stop 事件情况下：
```
2026-09-30  Midpoint Integrity Review
```
届时**只检查**：采集是否正常 / 证据是否可恢复 / 字段缺失情况 / Reality Evidence Admission / Intervention 状况 / Counterexample 是否被保留 / 严重 Incident。
**不得提前做效果裁决。**

### 10. 现在唯一的主任务
```
Collect Real Episodes.
```
> 系统已经搭好了，现在不要再搭架子，开始看真实的人、真实的任务、真实的软件到底发生什么。

---

## 四、登记与修订纪律

- 本口径件为**受控治理件**，与 START 工单同属观察期顶层治理登记；任何口径变更须经 Human Authority 确认后修订本件。
- **不再新增启动基础设施**；Episode 收集所需的唯一模板 = `evidence/L8-E001/episodes/_TEMPLATE-episode-record.md`。
- 干预登记唯一落点 = `docs/ui/work-orders/L8-E001-Intervention-Registry.md`。

---

- **落盘人**：Amy（沈予安）／主控
- **落盘时间**：2026-09-18 08:2x +0800
- **锚定对象**：Protocol `747079c8…0de88`｜DeepBase START Anchor `339fe4a7456303c1dc49eb11e2deec4960efbcca`｜AsWish `7624a1d09da164b60d3a6deffb2d4c1127383548`｜DeepAxis START Anchor `f47c57320f0a8343de16bd188e507aab8ef0139d`（当前 HEAD `d98f2fd` 已作 §二 分类登记）
