# L8-E001 Intervention Registry
## Case 001 观察期工程干预与代码变更登记表

- **所属协议**：`L8-E001 Observation Protocol v1` (§5.5, §23)
- **管理方式**：轻量级结构化文档（不建任何平台软件，手工维护）
- **维护人**：观察员 / 调查员
- **核心纪律**：任何影响人机交互或系统行为的代码更新、配置更新或模型切换必须即时登记。数据按生效时间（Effective Time）严格切分为 `Before Intervention` / `After Intervention` 两个独立统计池，**严禁混池计算**。

---

## 一、干预事件登记表（Intervention Events）

| Intervention ID | Target Repo | Commit SHA | Effective Time (UTC+8) | Reason | Affected Behavior | Expected Effect | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :---: |
| **INT-20260916-01** | `DeepAxis` | `12dd4da9eb8ef8b1c165e8e35e6d3d26079f0a21` | 2026-09-16 16:56:12 | F4 机器语义失真定点整改 | 修正回执机器模式为 `engine-verification`，拦截仿真时钟跨入真实路径 | 彻底杜绝仿真冒充真实交付，消除语义失真 | **ACTIVE** |
| **INT-20260917-01** | `DeepAxis` | `c3215d3` (DataStore 搬迁收尾) | 2026-09-17 18:29:55 | DA-136 收尾：DataStore 搬迁 + 测试动态锚定恢复 159/159 | 数据存储位置变更，测试由硬编码 ID 改为动态锚定 | 消除硬编码 ID 失效，稳定数据存储基座 | **ACTIVE**（START 后）|
| **INT-20260917-02** | `DeepAxis` | `3b9f135` (明文库消费通路) | 2026-09-17 18:52:33 | DA-137-T1：`DecryptedDataPath` 直接消费外部明文 SQLite | **数据通路变更**：由原路径改为直接消费外部明文库 | 打通明文库消费通路 | **ACTIVE**（START 后）|
| **INT-20260917-03** | `DeepAxis` | `e389cd5` (hook 取钥移植) | 2026-09-17 18:52:51 | DA-137-T2：hook 取钥移植 + Profile 门禁 + 版本自检 | **执行行为/门禁变更**：取钥方式改为 hook，新增 Profile 门禁与版本自检 | 提升取钥合规性与版本一致性 | **ACTIVE**（START 后）|

> **登记来源**：`L8-E001-Observation-Active-Execution-Policy.md` §二（START Anchor `f47c573` 之后 commit 分类登记）。
> **时间界**：INT-20260917-01/02/03 均发生在 Case 001 START 宣告（2026-09-17 16:31）**之后** ⇒ 凡 `timestamp` 早于其 `Effective Time` 的 Episode 归入 `Before`，晚者归入 `After`，**严禁混池**。
> **F4 相关性**：三项均未触及 `F2B`/`Engine`/`flight-receipt`，**与 F4 影响面无交集**。

---

## 二、模型切换事件登记表（Model Change Events, §5.4）

| Model Event ID | Product | Model Version / Provider | Effective Time (UTC+8) | Reason / Context | Expected Impact |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **MOD-20260917-01** | `AsWish` | `deepseek-chat` (DeepSeek-V3) | 2026-09-17 00:00:00 | Case 001 观察启动初始基线模型 | 候选生成、意图解释基准能力 |
| **MOD-20260917-02** | `AXIS` | `deepseek-chat` (DeepSeek-V3) | 2026-09-17 00:00:00 | Case 001 观察启动初始基线模型 | F3 话术生成基准能力 |

---

## 三、使用说明

1. **Episode 关联**：每个 Episode 记录的 `intervention_id` 字段按其 `timestamp` 与 `software_commit` 匹配上述表格。
2. **基线切分**：在任何 Intervention 生效之前的数据归入前序统计子集，生效后归入后续子集。
3. **归因边界**：若模型或代码发生重大变更，观察结论必须单独评估该干预事件的影响，禁止将变更带来的变化全部归因于 EHAI。
