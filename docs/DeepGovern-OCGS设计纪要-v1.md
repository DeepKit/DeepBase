# DeepGovern OCGS 设计纪要 v1

> 版本：v1.0
> 创建：2026-05-11
> 主题：DeepGovern 治理控制台按 OCGS-se 面向门开发流程的设计讨论
> 参与角色：仙儿（主持人 + 安全专家）、盘古（架构师）、李冰（Delphi 工程师）、织女（UX 设计师）、墨子（AI 工程师）
> 关联文档：`docs/OCGS-delphi/OCGS-se-面向门的OutputDriven开发流程.md`

---

## 定位

DeepGovern 是 DeepBase 生态的治理控制台，作为 **DeepBase 基础能力**之一提供两种形态：

| 形态 | 身份 | 用途 |
|------|------|------|
| **exe**（管理态） | `DeepGovern.exe` 独立程序 | 治理管理员集中管理所有下游项目的 ConfigDB |
| **package**（嵌入态） | VCL package 导出 2 个 Frame | 嵌入下游业务程序，作为业务程序的内建配置中心 |

核心价值主张：**让非技术用户在人类 + AI 协同下安全地调整治理规则**，每一次调整都可追溯、可回滚、可审计。

---

## OCGS 8 步讨论结果（前四步）

### 第一步：Output（宝物）锁定

用户拍板：主宝物 = 门禁记录（"用户凭什么拿到宝物"），副产出 = 用户流程 + 证据链。

经 UX 视角拆分，门禁记录分两层生命周期：

| # | OutputKey | 谁产生 | DeepGovern 角色 |
|---|-----------|--------|-------------------|
| 1 | `governance.gate_resolution_record` | 下游 app 的 Runtime 自动产生 | 查看器 + 分析器 |
| 2 | `governance.policy_change_record` | 人类 + AI 在 DeepGovern 里协同产生 | 生产者 |

**Output 1 表（门禁记录）：**

```
OutputKey:         governance.gate_resolution_record
OutputName:        门禁判定记录
OutputType:        evidence_record
InitialState:      pending_resolution
FinalState:        resolved_and_persisted
RiskLevel:         L2
MutationRiskLevel: L3（任何试图修改/删除已有记录的操作）
ReadRiskLevel:     L1
EvidenceRequired:  true（自身就是 evidence）
SealRequired:      conditional（当对应 action.risk_level >= L3 时自动 seal）
AcceptanceCriteria:
  - 包含 actor_key + timestamp + gate_key + conditions_evaluated + result(pass/block)
  - 不可被后续修改（append-only）
  - 可被外部审计工具读取
```

**Output 2 表（策略变更记录）：**

```
OutputKey:         governance.policy_change_record
OutputName:        治理策略变更记录
OutputType:        sealed_governance_diff
InitialState:      draft
FinalState:        committed_and_sealed
RiskLevel:         L3
EvidenceRequired:  true
SealRequired:      true
AcceptanceCriteria:
  - AI 草案或手编稿通过 JSONLogic 语法校验
  - 在合成 context 上跑 dry-run，所有预期用例结果符合
  - 人类显式签字确认
  - 变更前后 ConfigDB 有完整 diff
  - Evidence 链记录 actor + timestamp + ai_verbatim（如果 AI 参与）+ before/after hash
```

### 第二步：Output 状态机

**Output 1 状态机**（DeepGovern 只读）：

```
[triggered] → [evaluating] → [resolved] → [persisted]
                                              ↓
                                  (risk>=L3 时自动)
                                              ↓
                                          [sealed]
```

触发 Gate 映射：
- triggered → evaluating：`RuntimeGate`
- evaluating → resolved：`ConditionEvalGate`
- resolved → persisted：`EvidenceWriteGate`
- persisted → sealed：`AutoSealGate`

**约束**：persisted 之后不可回退。Evidence 是 append-only，retention 变更必须走 Output 2。

**Output 2 状态机**（DeepGovern 生产）：

```
[intent] → [drafting] → [draft_ready] → [dry_running]
                                              ↓
                              [dry_run_passed] / [dry_run_failed]
                                              ↓
                                        [reviewing]
                                              ↓
                                        [confirmed]
                                              ↓
                                        [committing]
                                              ↓
                                        [committed]
                                              ↓
                                        [sealed]
```

状态迁移 Gate 守卫：

| 从 | 到 | 触发 Gate | 禁条件 |
|----|----|-----------|----|
| intent | drafting | IntentGate | actor_key 非空 |
| drafting | draft_ready | DraftCompleteGate | JSON 语法校验通过 |
| draft_ready | dry_running | DryRunStartGate | 无额外禁 |
| dry_running | dry_run_passed | DryRunPassGate | 所有合成用例符合预期 |
| dry_running | dry_run_failed | DryRunFailGate | 至少一个用例不符合 |
| dry_run_passed | reviewing | ReviewGate | 无额外禁 |
| reviewing | confirmed | ConfirmGate | 权限 + 非空 actor + 双角色（L3 时） |
| confirmed | committing | CommitGate | DB 连接可用 |
| committing | committed | PersistGate | 事务写入成功 |
| committed | sealed | SealGate | sha256(diff + actor + timestamp) 生成 |

**会话持久化表**：

```sql
CREATE TABLE governance_change_sessions (
  id TEXT PRIMARY KEY,
  state TEXT NOT NULL DEFAULT 'intent',
  actor_key TEXT NOT NULL,
  intent_text TEXT,
  draft_json TEXT,
  dry_run_result TEXT,
  diff_json TEXT,
  created_at TEXT,
  updated_at TEXT,
  committed_at TEXT,
  seal_hash TEXT
);
```

### 第三步：AccessGateTree（倒推）

**双形态根 Gate 分叉，子树共享**：

**exe 管理态**：

```
[AppGate] DeepGovern.exe 启动
  └─ [PermissionGate] 启动权限检查
     └─ [MainWindowGate] 主窗口打开
        ├─ [RegionGate] ProjectSelector 区（仅 exe 形态）
        │   └─ [ControlGate] 选择下游项目的 ConfigDB
        │       ├─ [ContextGate] DB 文件存在 + 可连接
        │       └─ [StateGate] governance_* 表已存在
        │
        ├─ [RegionGate] PolicyBrowser 区
        │   ├─ [TabGate] Purposes
        │   ├─ [TabGate] Gates
        │   ├─ [TabGate] Actions
        │   ├─ [TabGate] Evidence（Output 1 只读视图）
        │   └─ [TabGate] Sessions
        │
        └─ [RegionGate] ChangeWorkbench 区（Output 2 生产地）
            ├─ [CommandGate] 新建 ChangeSession
            │   └─ [DialogGate] 输入 intent → state: intent → drafting
            ├─ [AIGate] 调 Assayer 生成草案（仅黄色协议能力）
            │   └─ state: drafting → draft_ready
            ├─ [ControlGate] 手编辑器
            ├─ [CommandGate] 触发 DryRun
            ├─ [RegionGate] DiffPreview
            ├─ [DialogGate] 签字确认（双角色守卫）
            └─ [CommandGate] 最终提交（事务包裹三表）
```

**package 嵌入态**：根 Gate 从 `[AppGate]` 替换为 `[EmbeddedFrameGate]`，不含 `ProjectSelector`（宿主提供 ConfigDB 实例）。

**包导出两个 Frame**：
- `TFrameGovernBrowser`：浏览器（Output 1 查看 + 配置浏览）
- `TFrameChangeWorkbench`：工作台（Output 2 生产）

宿主自选使用其中一个或两个。

**关键门禁强化**：

`[DialogGate] 签字确认` 条件：
```
- permission: govern.commit.low_risk 或 govern.commit.high_risk
- accountability: actor_key 非空且符合格式 /^[A-Z0-9_.@-]+$/
- risk_gate:
    if affected_actions.max_risk >= L3:
      require: actor 同时持有 role.committer AND role.guardian
- state_gate: session.state == 'reviewing'
- context_gate: DRY_RUN_PASSED == true
```

`[CommandGate] 最终提交` 事务约束：**三表原子性**
1. 写 governance_* 表的新规则
2. 更新 governance_change_sessions.state = committed
3. 写 governance_evidence 的变更审计条目
任何一步失败全部回滚。

`[AIGate]` 强制约束：**AI 不得输出 raw JSONLogic**，只能输出"结构化模板实例"。raw JSON 只能由人类在手编辑器敲。

### 第四步：PurposeSet + RoleSet

**5 个角色**（第 5 为预留槽）：

| RoleKey | 含义 | 默认权限 |
|---------|------|---------|
| `role.viewer` | 只读 | 浏览所有配置 + 审计 evidence |
| `role.drafter` | 起草者 | viewer + 起草草案 + dry-run |
| `role.committer` | 提交者 | drafter + 提交 L0/L1/L2 变更 |
| `role.guardian` | 守护者 | L3 提交 + seal + role grant + mode switch |
| `role.custom` | 预留 | 首次向导时由用户定义，默认空 |

**L3 提交要求**：actor 必须同时持有 `role.committer` 且 `role.guardian`。
**一个 actor 可持有多个角色**。

**Purpose 主表（18 项）**：

```
PurposeKey              | MinRole              | Scope
------------------------|----------------------|------
govern.core             | viewer               | 根
govern.browse           | viewer               | govern.core
govern.browse.purposes  | viewer               | govern.browse
govern.browse.gates     | viewer               | govern.browse
govern.browse.actions   | viewer               | govern.browse
govern.audit.evidence   | viewer               | govern.browse
govern.audit.sessions   | viewer               | govern.browse
govern.draft            | drafter              | govern.core
govern.draft.ai         | drafter              | govern.draft
govern.draft.manual     | drafter              | govern.draft
govern.dry_run          | drafter              | govern.core
govern.commit.low_risk  | committer            | govern.core
govern.commit.high_risk | committer + guardian | govern.core
govern.seal             | guardian             | govern.core
govern.role.grant       | guardian             | govern.core
govern.role.revoke      | guardian             | govern.core
govern.mode.switch      | guardian             | govern.core
```

`govern.mode.switch`（observe↔enforce）单独成一条，等同或超越 L3 严格度，要求强制 dry-run + evidence + seal。

**Bootstrap 机制**：

- `root.txt` 只存一条信息（RootPath）
- 首次启动检测 `governance_actor_roles` 表缺失 guardian → 进入 FirstRunWizard：

```
Step 1: 欢迎 + 原理说明（不可跳过）
Step 2: 填写 bootstrap guardian 的 actor_key
Step 3: 确认 AI 红黄绿协议的各能力分类
Step 4: 可选：自定义 role.custom 的权限集
Step 5: 配置预览 + 确认
Step 6: 写入 ConfigDB + 生成首条 evidence("bootstrap by X at T")
         + 在 governance_mode_history 追加 mode=bootstrapped 的初始条目
```

首次之后即使 DB 被清空，不会自动重走向导；需手动删 `.bootstrapped` 标记文件或 `--bootstrap-force` 命令行强制。

**AI 红黄绿协议（取代硬隔离）**：

| 协议色 | 含义 | 范围（示例） |
|--------|------|-------------|
| 🟢 绿 | AI 自由执行，evidence 标记 `ai_initiated=true` | 读取配置、生成报告、分析趋势、回答查询、观察异常主动提示 |
| 🟡 黄 | AI 生成建议，进入 `governance_ai_suggestions` 队列，需人类确认 | 起草 gate/action/purpose、生成 dry-run 用例、建议 role 授予、诊断 dry_run_failed |
| 🔴 红 | AI 无论如何不可触发 | commit 任何规则（即使 L0）、seal、grant/revoke role、switch mode、改 actor_roles / mode_history 表 |

**技术落地**：每个 AbilityKey 标签 `ai_protocol: green | yellow | red`。`ActionExecutor` 在调用 ability 前检查 actor 前缀（`ai:` 开头即 AI），对照协议色做分流。

**协议色调整权限**：协议色本身属于 L3 配置。guardian 可以调整（比如把一个黄级能力升到红），但调整本身需要 evidence + seal。

---

## 新增 DB 表（累计）

```sql
-- 角色定义
CREATE TABLE governance_roles (
  role_key TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  description TEXT
);

-- actor 角色绑定
CREATE TABLE governance_actor_roles (
  actor_key TEXT NOT NULL,
  role_key TEXT NOT NULL,
  granted_at TEXT NOT NULL,
  granted_by TEXT NOT NULL,
  revoked_at TEXT,
  PRIMARY KEY (actor_key, role_key)
);

-- 变更 session
CREATE TABLE governance_change_sessions (
  id TEXT PRIMARY KEY,
  state TEXT NOT NULL DEFAULT 'intent',
  actor_key TEXT NOT NULL,
  intent_text TEXT,
  draft_json TEXT,
  dry_run_result TEXT,
  diff_json TEXT,
  created_at TEXT,
  updated_at TEXT,
  committed_at TEXT,
  seal_hash TEXT
);

-- mode 切换历史（evidence 链的根）
CREATE TABLE governance_mode_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  from_mode TEXT NOT NULL,
  to_mode TEXT NOT NULL,
  actor_key TEXT NOT NULL,
  changed_at TEXT NOT NULL,
  reason TEXT,
  evidence_ref TEXT NOT NULL
);

-- AI 建议队列（黄色协议使用）
CREATE TABLE governance_ai_suggestions (
  id TEXT PRIMARY KEY,
  ai_actor_key TEXT NOT NULL,
  ability_key TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',  -- pending / accepted / rejected / expired
  created_at TEXT NOT NULL,
  reviewed_by TEXT,
  reviewed_at TEXT
);
```

---

## 剩余待讨论（第 5-8 步）

- 第 5 步：Projection（UI 参数表，双形态 Frame 布局）
- 第 6 步：AbilitySet（稳定命名的能力表 + 红黄绿标签）
- 第 7 步：DueSet（L2/L3 Output 的合当性条件）
- 第 8 步：FeedbackSet（每道门被挡时的提示文案）

---

## 当前冻结句

> DeepGovern 是 DeepBase 治理控制台，双形态交付（exe 管理态 + VCL package 嵌入态）。主 Output 分两条：Output 1（门禁记录）由下游 Runtime 自动产生，DeepGovern 只做查看器；Output 2（策略变更记录）由人类 + AI 协同产生，DeepGovern 是生产者。角色体系 5 档（viewer/drafter/committer/guardian/custom）；L3 变更要求 committer + guardian 双角色，同一 actor 可同时持有。Bootstrap 通过首次启动向导建立，root.txt 只存 RootPath。AI 采用红黄绿三色协议替代硬隔离：绿可自主、黄需人类确认、红永不触碰。所有变更走 dry-run → review → sign → commit → seal 的状态机，事务包裹 rules + session + evidence 三表原子落盘。
