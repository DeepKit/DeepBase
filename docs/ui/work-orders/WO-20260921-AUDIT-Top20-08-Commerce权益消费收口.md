# WO-20260921-AUDIT-Top20-08 — Commerce 权益消费收口（资金类）

- **工单号**：WO-20260921-AUDIT-Top20-08
- **承接**：开发 AI **乙**（**排队单**）
- **派发**：主控 AI（沈予安）｜ 2026-09-21 11:2x +0800
- **依据**：`CodeReview/20260918-全库审计-总报告.md` §三 **Top20 #8**；分模块明细 `CodeReview/20260918-Features-B-Commerce语音.md`（清单 #2 / #3 / #5 / #6 / #7，对应 C-02 / C-03 / C-07 与并发消费两项）
- **类别**：**资金**（权益计费 / 配额扣减 / 分级鉴权 / 支付守卫）
- **前置依赖**：**乙 R7 交付并经验收后开工**（单活跃单纪律，避 H16）。**主控未发开工令前不得动工**

> **为何是本单唯一无主的高危条目**：Top20 其余 18 项均落在已有工单链（或已闭环）；唯 **#8 从未派生工单、从未有修复标记** —— 主控 2026-09-21 复扫 `docs/ui/work-orders/` 确认零命中，并回源码确认缺陷仍在（`Supabase.pas:722 ConsumeEntitlement` 仅新增乐观并发过滤条件，**无 PATCH 影响行数校验**、`:772 Result := True` 仍无条件）。**资金类缺陷优先级高于告警消噪**（老板 2026-09-20 质量影响排序）。

---

## 一、缺陷清单（逐条带锚点，主控已复验路径为真）

### 🔴 P1 `ParseOrder` 漏读 `Status` ⇒ 支付/发放守卫被绕过

| 文件 | 锚点 | 实测 |
| :--- | :--- | :--- |
| `Features/DeepBase.Commerce.Adapter.Supabase.pas` | `:311-323` | `ParseOrder` 无 `Result.Status` 赋值 ⇒ 读回恒为 `cosCreated` |
| `Features/DeepBase.Commerce.Adapter.Firebase.pas` | `:367-379` | 同上 |

**后果**（审计明细 #6 / #9）：`Service.pas:210,229` 与 `UpgradeFlow.pas:110` 依赖被抹平的 `Order.Status` ⇒ 「非成功终态」分支永不进入 ⇒ 失败/退款订单被当作进行中继续发放权益、重复支付。

### 🔴 P2 `ParseEntitlement` 漏读四个治理字段 ⇒ 分级/设备/离线鉴权错乱

| 文件 | 锚点 | 漏读字段 |
| :--- | :--- | :--- |
| `Features/DeepBase.Commerce.Adapter.Supabase.pas` | `:356-368` | `Tier` / `MaxDevices` / `OfflineGraceDays` / `LastValidatedISO` |
| `Features/DeepBase.Commerce.Adapter.Firebase.pas` | `:412-424` | 同上（止于 `SourceOrderId`） |

**后果**（#7 / #10）：读回 `Tier=''`、`MaxDevices=0`、`OfflineGraceDays=0` ⇒ **设备数限制失效、离线宽限期归零（联网抖动即误判过期）、按 Tier 的分级鉴权错乱**；组合放大后**付费 Pro 用户可被降级为 free 或反之越权**。
> 对照：同文件 `ParseProduct`（`Supabase.pas:339-354`）**已读** `Tier/MaxDevices/OfflineGraceDays` ⇒ 证明是 `ParseEntitlement` 遗漏，非接口缺失。

### 🔴 P3 权益消费无原子性 / 不校验影响行数 ⇒ 并发双花

| 文件 | 锚点 | 现状 |
| :--- | :--- | :--- |
| `Features/DeepBase.Commerce.Adapter.Supabase.pas` | `:722-772` | 条件 PATCH（`remaining_quota=eq.<old>`，`:752`）冲突时影响 **0 行**，但 `SupabasePatch` 返回与**实际更新行数均未校验**；`:772 Result := True` **无条件执行**；`:764` 确认 GET 若失败（`Obj=nil`）仍返回 True |
| `Features/DeepBase.Commerce.Adapter.Firebase.pas` | `:875-933` | 权益消费为**非原子读-改-写、无版本守卫** ⇒ 多实例 TOCTOU 双花 |

**后果**（#2 / #3）：两个并发消费者条件更新「一成功一匹配 0 行」，失败方仍被告知「消费成功」而实际未扣减 ⇒ **少扣 / 双花 / 配额账实不符**。

### 🔴 P4 订单状态解析未知值默认「已退款」⇒ 误撤权益

| 文件 | 锚点 | 问题 |
| :--- | :--- | :--- |
| `Features/DeepBase.Commerce.JsonUtil.pas` | `:258` | `OrderStatusFromString` 对**未知/空值默认 `cosRefunded`** |

**后果**（#5）：一条 status 字段临时缺失的订单被误判已退款并终结 ⇒ **用户已付款却被撤权**，或对未付款订单发起退款。

---

## 二、改法（质量优先，禁兼容层）

1. **P1**：两适配器 `ParseOrder` 补读 `Status`；字段缺失/未知**不得**静默落 `cosCreated`，须**显式失败**（返回 `False`/`nil` 或抛类型化异常，由调用方按既有异常分支处理）。
2. **P2**：两适配器 `ParseEntitlement` 补读四字段；**字段缺失即 fail-closed**（不得默认 `Tier=''`/`MaxDevices=0`/`OfflineGraceDays=0`）。设备上限与离线宽限为**安全相关默认**，缺省必须拒绝而非放宽。
3. **P3**：消费路径改为**可验证的原子扣减**：
   - Supabase：要求服务端返回受影响行（`Prefer: return=representation` 或校验 `Content-Range`）；**影响行数 = 0 视为 CAS 失败** ⇒ 重读重试或返回 `False`；**严禁无条件 `Result := True`**；确认 GET 失败必须返回 `False`。
   - Firebase：引入**版本守卫**（事务 / `updateTime` 前置条件）实现原子读-改-写。
4. **P4**：`OrderStatusFromString` 未知/空值**不得**默认 `cosRefunded` ⇒ 改为显式不可判定态并让调用方 fail-closed。
5. **P5（主控已裁定，无需再请示）部署形态**：审计明细 Q-2 提出「若产品承诺单实例则严重度可降 🟡」——**主控裁定按「多实例并发」修**，不假设单实例。理由：不假设单实例本身即 fail-closed 思维，且修复手段（CAS / 版本守卫）与单实例场景不冲突，无额外代价。
6. **H8**：**禁**为兼容旧宽松解析保留 fallback / 开关 / 兼容分支；允许 breaking change（改后不合规数据一律拒绝）。

---

## 三、明确不在本单

| 项 | 处置 |
| :--- | :--- |
| `Service.pas:210` `cosRefunded` 编排语义（C-01） | 根因在 P1/P4 修复后复评；如仍有残余，另行建单 |
| `Commerce.Adapter.*` 1250 行架构拆分建议（`Features-B` 🔵 项） | 属可维护性，非资金缺陷，不在本单 |
| 甲域文件（`Core/` 安全链、`Features/DeepBase.Update*`、`Updater*`） | **乙不碰**（对称于甲 R7/R8 的 H2） |

---

## 四、验收标准

| 项 | 标准 | 主控判定方式 |
| :--- | :--- | :--- |
| P1 | 两适配器 `ParseOrder` 返回 `Status`；缺失/未知**不落** `cosCreated` 且可被调用方观测 | 主控读源码 + 负向用例 |
| P2 | 两适配器 `ParseEntitlement` 四字段齐；**缺失即拒绝** | 主控读源码 + 负向用例 |
| P3 | 影响行数 0 ⇒ 返回失败；确认 GET 失败 ⇒ 返回失败；**无无条件 `Result := True`**；Firebase 有版本守卫 | 主控读源码 + **并发双花负向用例**（两路并发消费一权益：合计只扣一次） |
| P4 | 未知/空 status **不**默认 `cosRefunded` | 主控读源码 + 负向用例 |
| 通用 | 双证据（控制台 log + NUnit XML，数量自洽，**XML 时间戳早于 commit**）；H14 双数字（raw + `--ignore-cr-at-eol`）；H18 证据 `NUL=0` | 主控逐项复算 |

---

## 五、硬约束（H 系列，违反即 REJECT）

- **H1**：禁 `checkout --`/`restore`/`clean`/`reset --hard` 处置非本工单改动。
- **H3**：禁 `git add -A` / `git add .` / 目录级宽泛添加；逐件精确 pathspec。
- **H7**：禁自报 PASS；数字必须来自日志/产物。
- **H8 · 质量优先，不是兼容优先（老板 2026-09-19）**：本单 P1/P2/P4 尤为核心 —— **缺字段必须拒绝，不得默认放宽**。
- **H14**：提交前 `git ls-files --eol <path>`；`i/crlf`/`i/mixed` 须 `--renormalize`；双数字申报。
- **H15 · 原子提交**：`git commit` 必带 `--only` 或显式 pathspec；**提交前后各跑 `git diff --cached --name-only`**（前空后空）。
- **H16**：发现他方暂存即停写、报主控。
- **H18**：证据 UTF-8，自证 `NUL = 0`。
- **H9**：回执写明**精确结束时间**（本地）+ 交付 commit hash。
- **门禁申报**：每段提交前跑 `encoding-gate` + `evidence-encoding-gate` 并申报 EXIT。

---

## 六、产品干预登记

P1–P5 **全部为行为变更**（原宽松解析 ⇒ fail-closed；并发消费结果语义变化）⇒ 按老板 2026-09-19 裁定**一律登记为产品干预**（`docs/ui/work-orders/L8-E001-Intervention-Registry.md`），**禁用「纯内部优化」表述**，须写清「哪些行为变了 + 迁移窗口」。

---

## 七、交付物

1. 精确 pathspec 的 commit（**建议 P1+P4 一笔 / P2 一笔 / P3 一笔**，或按适配器两笔）
2. 回执：`CodeReview/20260921-AUDIT-乙-Top20-08-交付回执.md`
3. 证据：`CodeReview/_audit_recheck/`（含**并发双花负向用例**原始输出）

---

## 八、是否阻塞他仓

**是（需申报）**：`ParseEntitlement` 补字段后，**任何下游（AsWish / DeepAxis）若依赖当前的宽松读回语义，行为将改变**（缺字段由「静默 0 值」变为「拒绝」）；`ConsumeEntitlement` 由「恒 True」变为「CAS 失败即 False」，**调用方必须处理失败分支**。须在回执申报影响面，由主控决定是否下发下游工单。

---

*主控 沈予安 ｜ 2026-09-21 11:2x +0800*
