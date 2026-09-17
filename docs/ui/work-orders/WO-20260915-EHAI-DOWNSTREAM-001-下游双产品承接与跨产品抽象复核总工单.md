# WO-20260915-EHAI-DOWNSTREAM-001

## EHAI 下游双产品承接、Gate C 与跨产品抽象复核总工单

> **类型**：跨仓主控总工单 / Serial Multi-Repo Execution
> **执行模式**：一个开发 AI 串行执行多个仓
> **执行顺序**：AsWish → AXIS → Cross-Product Review
> **Human Authority**：最终裁定权属于 Human
> **理论状态**：EHAI L1～L8 `FROZEN v1.0`
> **禁止新增 L9**

---

# 一、上游正式基线

本工单以下列已经完成独立终审的事实为不可回退基线：

```text
WO-20260914-EHAI-001
→ R1
→ R2
→ R3
→ R4
→ R5
→ Gate B
```

全部闭合。

Gate B 正式判定：

```text
Gate B
=
PASS WITH NON-BLOCKING FINDINGS
```

正式建立：

```text
EHAI Language Common Contract
→ Delphi / DeepBase / HB
Conformance Established
```

因此：

```text
AsWish Gate C
= UNBLOCKED

AXIS L7 Conformance / Gate C
= UNBLOCKED
```

当前 DeepBase / HB 基线：

```text
fc213b4696d92bc8a836ef644abaeb74f0daa79e
```

本工单不得重新审理 Gate B，不得重新打开：

```text
001
R1
R2
R3
R4
R5
```

除非发现新的、能够推翻现有 Git Object / 原始证据的事实。

---

# 二、本工单真正目标

本工单不是继续开发 EHAI 公共层。

目标是验证并完成：

```text
Language Common Contract
        ↓
DeepBase / HB
        ↓
AsWish
```

以及：

```text
Language Common Contract
        ↓
DeepBase / HB
        ↓
AXIS
```

最终回答：

> 两个领域差异很大的产品，能否在不污染公共层、不偷换语义、不降低 Human Authority 的条件下，自然消费同一套 EHAI 公共实现？

---

# 三、总执行纪律

虽然由同一个 AI 串行执行多个仓，但必须保持：

```text
一个阶段
=
一个 Owner Repo
```

严禁：

```text
一边改 AsWish
一边顺手改 DeepBase

或

一边改 AXIS
一边顺手改 AsWish / DeepBase
```

跨仓发现问题时：

```text
发现上游缺口
→ Shared Capability Gap
≠
直接跨仓修复
```

每次切仓前必须记录：

```text
Owner Repo
Current HEAD
Upstream Baseline
Working Tree Status
本阶段允许修改范围
```

每阶段必须独立：

```text
调查
→ 修改
→ 测试
→ Raw Evidence
→ isolated commit
→ delivery report
```

不得做跨仓“大一统提交”。

---

# 四、证据纪律

本工单继续执行已经形成的工程铁律：

```text
Commit Claim
≤
Git Evidence

Regression Claim Strength
≤
Executed Test Scope

Build Claim Strength
≤
Declared Build Scope
```

并新增正式交付纪律：

```text
先 Commit
再交付报告
```

提供给主控 / 审计的报告必须对应一个明确：

```text
Commit SHA
```

审计第一法定对象：

```text
Git Commit
Git Blob
Source Code
Raw Test Evidence
```

聊天贴文和 Walkthrough 只能作为索引。

如果：

```text
聊天报告
≠
Git Blob 中正式报告
```

必须显式声明差异，不得静默替换。

---

# 五、Gate B 六项发现下传

Gate B 的 N-1～N-6 不阻断公共层，但必须完整下传至两个产品 Gate C。

## N-1｜显式通配 Authority Scope `'*'`

公共层允许：

```text
'*'
=
explicit wildcard authority scope
```

它不是 Empty Scope。

但两个产品必须分别证明：

```text
1. '*' 从哪里产生？
2. 谁可以创建？
3. 是否可能来自用户自由输入？
4. 是否可能来自 AI 输出？
5. 是否可能来自外部导入 / 配置 / 持久化恢复？
6. 是否有可信边界？
7. 是否能够追溯是谁授予？
8. 是否会被默认生成？
```

原则：

```text
显式全授权
≠
隐式全授权
```

以及：

```text
AI 不能因为“方便”
自动生成全授权 Scope
```

如果产品允许 `'*'`：

必须能够恢复：

```text
Grantor
Source
Reason
Applicability
Lineage
```

若从不可信输入可直接进入，则视为 Gate C 高优先级问题。

---

## N-2｜超过 7 个候选静默丢弃

公共层强制：

```text
CandidateSpace ≤ 7
```

这是正确约束。

但当前超过 7 项会静默丢弃。

产品层必须检查：

```text
原始候选数量
→ 收敛动作
→ 最终候选集合
```

是否存在可恢复痕迹。

不得让 Human 误以为：

```text
“本来就只有这 7 个”
```

如果实际上 AI / 系统从更大集合中进行了收敛。

不要求一定展示全部候选。

要求的是：

> 收敛发生过这件事，在需要时能够恢复。

---

## N-3｜Candidate Key 不查重

检查两个产品是否可能产生：

```text
Key duplicate
```

必须判断：

```text
产品层天然保证唯一
```

还是：

```text
存在冲突路径
```

如存在冲突：

优先在产品 binding 层做最小防护。

不得未经 Shared Capability Gap 裁定直接修改 DeepBase。

---

## N-4｜`Covers()` 内部使用 `Now`

属于可测试性债务。

两个产品分别检查：

```text
Expiry / Authority 测试
```

是否仍然：

```text
Deterministic Enough
```

若产品现实场景需要：

```text
可控时钟
模拟时间
回放历史权限
```

则登记：

```text
Shared Capability Gap Candidate
```

不得本工单直接改公共层。

---

## N-5｜Demo 中性语义

DeepBase Demo 中：

```text
Contact List
```

与 AXIS 领域词撞名。

这是非阻断项。

不得为了它回 DeepBase 开返工。

只在 Cross-Product Review 中判断：

```text
纯 Demo 文案
```

还是：

```text
已经造成公共语义误导
```

没有真实影响则记录后关闭。

---

## N-6｜`ExpiresAt = 0` 双义

产品必须显式回答：

```text
0
=
Not Set

还是

Never Expires
```

不得在产品领域里继续保持无法解释的双义。

AsWish 与 AXIS 可以采用不同业务策略，但必须能够映射回明确公共语义。

---

# 六、PHASE A｜AsWish Reference Product Binding 001

## A-0 Owner Repo

本阶段唯一允许修改：

```text
AsWish
```

禁止修改：

```text
DeepBase
EHAI SSOT
AXIS
```

开始时登记：

```text
AsWish HEAD
DeepBase upstream baseline = fc213b4
working tree status
```

---

# 七、A-1｜建立 Gate C Semantic Binding Matrix

至少逐项检查以下公共语义：

```text
CandidateSpace
RecommendedMark
CandidateSelection
Regenerate
HumanOverride
FrameRejection
BackNavigation
SourceDistinction
CommitmentBoundary
RecoverableLineage
```

建立正式矩阵：

| Common Semantic | DeepBase/HB Realization | AsWish Domain Meaning | AsWish Implementation | Human Observable | Test Evidence | Verdict |
| --------------- | ----------------------- | --------------------- | --------------------- | ---------------- | ------------- | ------- |

Verdict：

```text
PASS
PARTIAL
FAIL
NOT ESTABLISHED
NOT APPLICABLE
```

---

# 八、A-2｜不得把 AsWish 私有语义上收

AsWish 私有领域包括但不限于：

```text
Intent
Spec
SpecNode
Tree
Bundle
ChangeSet
Baseline
Requirement Decision
Snapshot
Evidence
Issue
```

必须保持：

```text
Common Semantic
↓
AsWish Domain Binding
```

禁止反转：

```text
AsWish Domain Model
↓
定义 Common Contract
```

例如：

```text
FrameRejection
```

在 AsWish 可以解释成：

```text
当前 Spec / Requirement / Tree framing
整体不成立
```

但公共层不得因此出现：

```text
SpecFrameRejection
RequirementRejection
TreeRejection
```

---

# 九、A-3｜Human Authority 与 Commitment Boundary

重点验证：

```text
CandidateSelection
≠
自动修改 Canonical Spec
```

必须能够说明：

```text
什么时候只是选择候选
什么时候形成 Human Decision
什么时候形成 Commitment
什么时候允许改变 Canonical State
```

保持：

```text
Exploration
≠
Commitment
```

以及：

```text
AI Proposal
≠
Human Authority Decision
```

检查所有可能改变 Canonical Spec 的路径。

不得因为：

```text
用户点了候选
```

就未经合法 completion semantics 自动提升为：

```text
正式 Requirement Decision
```

除非当前 Decision Context 明确赋予这种效力。

---

# 十、A-4｜0–9 在 AsWish 中的真实语义

检查：

```text
1–7 Choose
8 Regenerate
9 HumanOverride / Reframe
0 Back / Exit
```

不得退化成：

```text
1–7 = 永远正式决定
8 = Human Reject
9 = Reject
0 = Reject
```

尤其验证：

```text
9
```

能够拒绝整个 AI framing，而不是只能填写“第八个候选”。

---

# 十一、A-5｜Human Source / AI Interpretation

必须验证：

```text
Human Source
≠
AI Interpretation
```

在：

```text
Intent
Requirement
Decision
ChangeSet
```

相关路径中能够恢复。

不得把：

```text
AI 推断的人类需求
```

在保存 / reload / snapshot / apply 后变成：

```text
Human 明确说过
```

Qualification / Provenance / Lineage 必须保持。

---

# 十二、A-6｜Gate B N-1～N-6 AsWish 专项

形成：

```text
AsWish-N1
...
AsWish-N6
```

六项明确结论。

特别是 N-1：

如果 AsWish 中存在：

```text
'*'
```

或等价全授权机制，必须追踪：

```text
Source
Grantor
Generation Path
Persistence Path
Restore Path
AI Reachability
User Input Reachability
```

如完全不用，也必须用源码 / 测试证明：

```text
NOT USED
```

不得只写“应该没有”。

---

# 十三、A-7｜测试

必须执行：

```text
现有 AsWish regression
+
Gate C targeted tests
```

不得为了历史测试数硬凑数字。

必须列：

| Suite | Count | Pass | Fail | Skip | Exit Code |
| ----- | ----: | ---: | ---: | ---: | --------: |

如果发现缺少 Gate C 关键断言：

允许在 AsWish 仓新增最小测试。

若发现产品实现问题：

允许在 AsWish 仓最小修复。

不得因此改 DeepBase。

---

# 十四、A-8｜Shared Capability Gap 规则

如果 AsWish 发现：

```text
现有公共能力不足
```

先问：

```text
能否合理留在 AsWish Domain Binding？
```

如果能：

```text
留 AsWish
```

只有同时满足：

```text
不是 AsWish 私有语义
+
不是 Delphi 特有问题
+
具有跨产品公共意义
```

才登记：

```text
Shared Capability Gap
```

必须包含：

```text
1. 当前产品需求
2. 缺失能力
3. 为什么不能产品层解决
4. 为什么具有跨产品意义
5. 是否涉及 Common Contract
6. 是否阻断当前 Gate C
```

登记后停止跨仓动作。

不得自己切回 DeepBase 修改。

---

# 十五、A-9｜AsWish 提交

所有合法修改完成并测试 PASS 后：

形成独立 commit。

提供：

```text
Commit SHA
Parent SHA
Changed Files
Insertions
Deletions
git status --porcelain
```

必须说明：

```text
DeepBase baseline consumed
```

以及：

```text
是否存在 Shared Capability Gap
```

---

# 十六、A-10｜AsWish 交付报告

生成：

```text
WO-20260915-EHAI-DOWNSTREAM-001-A
AsWish Gate C Execution & Evidence Report
```

开发 AI只能建议：

```text
READY FOR GATE C REVIEW
```

不得自己宣布：

```text
Gate C = PASS
```

AsWish 完成后：

```text
Commit
→ Report
→ 离开 AsWish 仓
```

然后进入 AXIS。

不允许回头顺手修 AsWish。

---

# 十七、PHASE B｜AXIS Independent Product Binding 002

## B-0 Owner Repo

本阶段唯一允许修改：

```text
AXIS / DeepAxis / 唤金 / 序枢所属工程仓
```

禁止修改：

```text
DeepBase
EHAI SSOT
AsWish
```

开始时登记：

```text
AXIS HEAD
DeepBase upstream baseline = fc213b4
working tree status
```

---

# 十八、B-1｜建立 AXIS Gate C / L7 Conformance Matrix

同样逐项检查：

```text
CandidateSpace
RecommendedMark
CandidateSelection
Regenerate
HumanOverride
FrameRejection
BackNavigation
SourceDistinction
CommitmentBoundary
RecoverableLineage
```

建立：

| Common Semantic | DeepBase/HB Realization | AXIS Domain Meaning | AXIS Implementation | Human Observable | Test Evidence | Verdict |
| --------------- | ----------------------- | ------------------- | ------------------- | ---------------- | ------------- | ------- |

---

# 十九、B-2｜AXIS 私有领域不得污染公共层

AXIS 私有领域包括：

```text
Contact
Relationship
Customer
Touchpoint
Tag
Remark
话术
关系经营动作
微信相关业务
Authority Gate
```

必须保持：

```text
Common Semantic
↓
AXIS Domain Binding
```

例如：

```text
FrameRejection
```

可以在 AXIS 表达为：

```text
当前关系经营 framing 不成立
```

但不得上收成公共层：

```text
ContactFrame
RelationshipReject
CustomerIntent
```

---

# 二十、B-3｜Authority 是 AXIS 第一高优先级

AXIS 涉及现实关系经营动作，因此对：

```text
Authority
Scope
Expiry
Execution
```

进行专项检查。

必须保持：

```text
Capability
≠
Authority
```

以及：

```text
Need Authorization
≠
Need Repeated Authorization
```

检查：

```text
Prior Authorization
Standing Authorization
Rule-derived Authority
```

是否在合法 Scope 内正常工作。

同时验证：

```text
Empty Scope
Missing Authority
Expired Authority
```

继续 fail-closed。

---

# 二十一、B-4｜N-1 必须作为 AXIS P0 自查

重点追踪：

```text
Covers('*')
```

完整调用链。

必须回答：

```text
谁能创建 '*'
谁能保存 '*'
谁能恢复 '*'
AI 能不能构造 '*'
用户自由输入能不能构造 '*'
外部数据能不能带入 '*'
默认值会不会变成 '*'
迁移代码会不会产生 '*'
```

若：

```text
'*'
```

可以从不可信路径直接进入 Authority Scope：

```text
AXIS Gate C
= HOLD CANDIDATE
```

优先在 AXIS binding / validation 边界解决。

不得未经主控批准直接修改 DeepBase。

---

# 二十二、B-5｜Execution Boundary

检查关系经营动作是否保持：

```text
Choose
≠
Authorize
≠
Execute
```

不得因为 Human：

```text
选了某个建议
```

就自动变成：

```text
授予外部执行权限
```

除非 Decision Context + Completion Semantics 明确建立这种效力。

Human-facing UI 必须能够让 Human 理解当前所处状态。

---

# 二十三、B-6｜Source / Lineage

AXIS 中必须区分：

```text
Human 提供的联系人事实
AI 推断
系统历史记录
外部导入
规则派生
```

不得在：

```text
保存
恢复
标签整理
关系建议
话术生成
```

之后丢失源区别。

---

# 二十四、B-7｜N-2～N-6 AXIS 自查

分别形成：

```text
AXIS-N2
AXIS-N3
AXIS-N4
AXIS-N5
AXIS-N6
```

尤其：

### N-2

如果从大量联系人 / 动作候选中收敛为 ≤7：

必须能恢复：

```text
发生过候选收敛
```

不要求 Human 看全部候选。

### N-3

重复 Candidate Key 不得造成：

```text
选 A 实际执行 B
```

### N-4

如果权限有效期依赖真实业务时间：

必须说明 `Now` 对测试与回放的影响。

### N-5

仅登记 Demo 文案影响。

不得回 DeepBase 为一个 Demo 词开返工。

### N-6

明确：

```text
ExpiresAt = 0
```

在 AXIS 中的单一业务解释。

---

# 二十五、B-8｜测试

运行：

```text
AXIS existing regression
+
Gate C / L7 targeted tests
```

列出真实测试范围。

不得使用历史数字代替当前执行结果。

如果增加测试：

必须是针对真实 Gate C / L7 行为。

---

# 二十六、B-9｜AXIS 提交

合法修改完成后：

形成独立 commit。

提供：

```text
Commit SHA
Parent SHA
Changed Files
Insertions
Deletions
git status --porcelain
```

不得夹带既有 dirty workspace。

---

# 二十七、B-10｜AXIS 交付报告

生成：

```text
WO-20260915-EHAI-DOWNSTREAM-001-B
AXIS L7 Conformance / Gate C Execution & Evidence Report
```

只能建议：

```text
READY FOR INDEPENDENT REVIEW
```

不得自己宣布：

```text
Gate C PASS
```

---

# 二十八、两个产品完成后的强制停点

开发 AI 执行完：

```text
Phase A
+
Phase B
```

必须停止代码开发。

不得自动进入：

```text
Common Contract 修改
DeepBase 修改
EHAI 修改
```

先交付两仓证据。

等待：

```text
AsWish Independent Gate C Review
+
AXIS Independent L7 / Gate C Review
```

只有两者均正式 PASS，才能解锁 Phase C。

---

# 二十九、PHASE C｜Cross-Product Abstraction Review

## 解锁条件

只有：

```text
AsWish Gate C = PASS / PASS WITH NON-BLOCKING FINDINGS

AND

AXIS Gate C = PASS / PASS WITH NON-BLOCKING FINDINGS
```

才允许进入。

本阶段：

```text
READ-ONLY REVIEW
```

默认禁止修改任何仓。

---

# 三十、Cross-Product Review 六个核心问题

必须回答：

```text
1. AsWish 与 AXIS 是否重复实现了本应公共化的语义？

2. DeepBase / HB 是否混入 AsWish 私货？

3. DeepBase / HB 是否混入 AXIS 私货？

4. Language Common Contract 是否存在 Delphi 偏见？

5. 产品私有语义是否被错误上收？

6. 是否出现真正应当上收的新公共能力？
```

---

# 三十一、重点比较两个完全不同领域

AsWish：

```text
软件构建
Intent
Spec
ChangeSet
Tree
Decision
```

AXIS：

```text
关系经营
Contact
Relationship
Touchpoint
Business Action
Authority
```

重点判断：

> 两个领域差异如此大的产品，是否仍然能够自然消费同一套公共语义。

如果成立，只能裁为：

```text
Cross-product engineering reuse evidence
```

不得写：

```text
EHAI empirically proven
```

后者属于 L8。

---

# 三十二、公共能力上收规则

如果两个产品独立出现同一种缺口：

不得自动上收。

形成：

```text
Common Contract Revision Candidate
```

至少写清：

```text
AsWish Evidence
AXIS Evidence
Shared Semantic
Why Product Binding Is Insufficient
Why Language-specific Fix Is Insufficient
Potential Contract Impact
Backward Compatibility
```

然后：

```text
Human Authority Review
```

未经 Human 明确裁定：

```text
不得修改 Common Contract SSOT
```

---

# 三十三、Phase C 最终产物

形成：

```text
WO-20260915-EHAI-DOWNSTREAM-001-C
Cross-Product Abstraction Review Report
```

最终只能给：

```text
PASS
PASS WITH FINDINGS
HOLD
```

并给出：

```text
No Common Revision Needed
```

或：

```text
Common Contract Revision Candidate(s)
```

不得自动修改公共层。

---

# 三十四、L8 禁止提前进入

即使 Phase A / B 成功，也不得立刻宣称：

```text
EHAI 有效
EHAI 已实证
EHAI empirically proven
```

必须先完成：

```text
Gate B
✓

AsWish Gate C
↓

AXIS Gate C
↓

Cross-Product Abstraction Review
↓
```

确认：

```text
Stable
Testable
Conformant
Cross-product reusable
```

之后由 Human Authority 决定：

```text
是否正式进入
L8 Empirical Case 001
```

---

# 三十五、开发 AI 最终总报告格式

执行完当前已解锁的 Phase A + Phase B 后，提交一份总导航报告：

```text
WO-20260915-EHAI-DOWNSTREAM-001
Execution Index
```

必须包含：

## Upstream

```text
Gate B Verdict:
DeepBase Baseline:
Common Contract Baseline:
```

## AsWish

```text
Starting HEAD:
Ending HEAD:
Commit:
Regression:
Gate C Targeted Tests:
N-1～N-6:
Shared Capability Gap:
Recommended Status:
```

## AXIS

```text
Starting HEAD:
Ending HEAD:
Commit:
Regression:
Gate C / L7 Targeted Tests:
N-1～N-6:
Shared Capability Gap:
Recommended Status:
```

## Cross-Repo Integrity

明确：

```text
AsWish phase modified DeepBase?
YES / NO

AXIS phase modified DeepBase?
YES / NO

AXIS phase modified AsWish?
YES / NO
```

正常答案应全部：

```text
NO
```

## Pending Independent Gates

```text
AsWish Gate C:
PENDING INDEPENDENT REVIEW

AXIS L7 / Gate C:
PENDING INDEPENDENT REVIEW

Cross-Product Review:
LOCKED UNTIL BOTH PASS
```

---

# 三十六、失败处理

任何阶段出现问题，不得为了“大工单完成率”强行往后推进。

如果 AsWish 出现 Blocking Shared Capability Gap：

```text
AsWish
→ HOLD

登记 Gap
→ 主控裁定
```

AXIS 是否继续调查，由问题是否真正共享决定。

如果 AXIS 出现 Blocker：

```text
AXIS
→ HOLD
```

不得因此回头修改已经完成的 AsWish。

---

# 三十七、本大工单成功标准

当前第一阶段成功标准是：

```text
AsWish
完成 Product Binding 实测
完成 Gate C Evidence
完成 N-1～N-6 自查
完成 isolated commit
READY FOR INDEPENDENT GATE C

+

AXIS
完成 Product Binding 实测
完成 L7 / Gate C Evidence
完成 N-1～N-6 自查
完成 isolated commit
READY FOR INDEPENDENT REVIEW

+

全过程
0 unauthorized cross-repo edit
0 Common Contract unauthorized change
0 EHAI frozen theory change
```

两个独立 Gate 均 PASS 后：

```text
→ Cross-Product Abstraction Review
```

Cross-Product Review 也完成后，整个本工单才可：

```text
CLOSED
```

然后把是否进入：

```text
L8 Empirical Case 001
```

重新交回 Human Authority 裁定。

---

# 三十八、当前立即执行

现在不要继续修改 DeepBase。

立即执行：

```text
STEP 1
锁定 Gate B baseline
fc213b4

STEP 2
进入 AsWish
执行 Phase A

STEP 3
提交 AsWish
形成正式 Evidence Report

STEP 4
彻底退出 AsWish 修改状态

STEP 5
进入 AXIS
执行 Phase B

STEP 6
提交 AXIS
形成正式 Evidence Report

STEP 7
STOP

等待两个独立 Gate C 判定
```

核心纪律只有一句：

> **同一个 AI 可以跨仓串行工作，但每个语义归属、每次修改、每份证据、每个 Git object，都必须知道自己属于哪一层、哪一个仓、哪一道 Gate。**
