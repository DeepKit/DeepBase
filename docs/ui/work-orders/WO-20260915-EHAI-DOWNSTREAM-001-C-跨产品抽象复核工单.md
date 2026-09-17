# WO-20260915-EHAI-DOWNSTREAM-001-C ｜ Phase C 跨产品抽象复核工单

> **发单时间**：`2026-09-16 14:34:19 +0800`
> **工单文件绝对路径**：`D:\_Progs\02Business\DeepBase\docs\ui\work-orders\WO-20260915-EHAI-DOWNSTREAM-001-C-跨产品抽象复核工单.md`
> **派单人**：主控（Amy · 沈予安）｜**承接方**：开发甲（跨仓串行）
> **法源**：`docs/ui/work-orders/WO-20260915-EHAI-DOWNSTREAM-001-下游双产品承接与跨产品抽象复核总工单.md` §二十九 ~ §三十三
> **放行依据**：`CodeReview/20260916-EHAI-DOWNSTREAM-001-双仓收口复审与PhaseC放行结论.md`（AsWish IR = YES ／ DeepAxis IR = YES）

---

## 一、任务性质（**硬约束**）

```text
READ-ONLY REVIEW
默认禁止修改任何仓：DeepBase / AsWish / DeepAxis
```

| 禁止 | 说明 |
| :--- | :--- |
| 修改任何源码 | 三仓源码一律只读 |
| 修改 `Common Contract` SSOT | 未经 Human Authority 明确裁定前，**绝对不得**改动 |
| 「以复核为名顺手修一下」 | 发现缺陷 → 写进报告，不得即改 |
| 销毁性 git 操作 | `git checkout --` / `git restore` / `git clean` / `git reset --hard` **全面禁用** |
| 开启 L8 | 见 §六 |

**唯一允许的写操作**：新增本工单的报告产物文件（见 §七）。

---

## 二、冻结基线（开工前须逐项复核并登记）

| 仓 | 基线 HEAD | 备注 |
| :--- | :--- | :--- |
| DeepBase | `fc213b4696d92bc8a836ef644abaeb74f0daa79e` | Gate B 冻结基线，本轮**不得触碰** |
| AsWish | `0b22a528bdfc85fcba0e08abfb98c6917e529bf7` | Phase A 收口 |
| DeepAxis | `08a16af42a545a0227f70ca442a1bfd833bab410` | Phase B R2 收口 |

> **硬前置**：开工时须重新 `git rev-parse HEAD` 三仓，若与上表不符 → **停止并上报主控**，不得自行追随新 HEAD。

---

## 三、必须回答的六个核心问题（总工单 §三十）

```text
1. AsWish 与 AXIS 是否重复实现了本应公共化的语义？
2. DeepBase / HB 是否混入 AsWish 私货？
3. DeepBase / HB 是否混入 AXIS 私货？
4. Language Common Contract 是否存在 Delphi 偏见？
5. 产品私有语义是否被错误上收？
6. 是否出现真正应当上收的新公共能力？
```

**每一问须给出**：判定 + 可 grep 的源码位置（文件:行）+ 对照证据（两仓同一语义的落地形态）+ 结论强度（已校准原则／强候选／工作模型／待议）。

---

## 四、重点比较：两个领域差异极大的产品

| AsWish（软件构建） | AXIS（关系经营） |
| :--- | :--- |
| Intent / Spec / ChangeSet / Tree / Decision | Contact / Relationship / Touchpoint / Business Action / Authority |

**核心判断**：

> 两个领域差异如此大的产品，是否仍然能够自然消费**同一套**公共语义。

---

## 五、判定上限（**措辞红线**，总工单 §三十一）

若上述判断成立，**只能**裁为：

```text
Cross-product engineering reuse evidence
```

**严禁**写成：

```text
EHAI empirically proven
EHAI 有效
EHAI 已实证
```

> 后者属 **L8**，须由 Human Authority 单独决定是否进入 `L8 Empirical Case 001`。
> **参照前例**：2026-09-04 主控曾对 AC2 措辞越线作出改判；本轮同类越线一律判 `HOLD`。

---

## 六、公共能力上收规则（总工单 §三十二）

若两产品**独立**出现同一种缺口：

```text
不得自动上收！
```

须形成 `Common Contract Revision Candidate`，且**至少写清 7 项**：

```text
1. AsWish Evidence
2. AXIS Evidence
3. Shared Semantic
4. Why Product Binding Is Insufficient
5. Why Language-specific Fix Is Insufficient
6. Potential Contract Impact
7. Backward Compatibility
```

然后移交 `Human Authority Review`。**未经 Human 明确裁定，不得修改 Common Contract SSOT。**

---

## 七、最终产物与判定

**产物**（唯一允许新增的文件）：

```text
WO-20260915-EHAI-DOWNSTREAM-001-C
Cross-Product Abstraction Review Report
```

落盘路径：`D:\_Progs\02Business\DeepBase\docs\ui\work-orders\WO-20260915-EHAI-DOWNSTREAM-001-C-Cross-Product-Abstraction-Review-Report.md`

**最终判定只能给三者之一**：

```text
PASS
PASS WITH FINDINGS
HOLD
```

并附结论：

```text
No Common Revision Needed
```
或
```text
Common Contract Revision Candidate(s)
```

---

## 八、交付纪律（五件套 + 台账）

**交付必须含**：

```text
1. 三仓开工/收工 HEAD（40 位 SHA）
2. 本报告的文件绝对路径
3. 逐项结论强度标注
4. 报告自身已提交（commit SHA + 提交信息）
5. 工作树状态：git status --porcelain 原始输出（计数须与事实一致）
```

**纪律提醒（本轮血案教训，务必内化）**：

| 不等式 | 含义 |
| :--- | :--- |
| `Canonical Claim ≤ Git Evidence ≤ Runtime Evidence` | 报告声明不得超出 git 与运行时证据 |
| `交付的生命周期保障 ≤ 交付是否进入版本控制` | **未提交即未交付**——工作树单副本随时可灭 |
| `Commit Claim ≤ Git Evidence` | 报告内自述的 Commit SHA 必须 `git branch -a --contains` 非空 |

**禁止**：
- 将未提交的工作区改动定性为「既有脏区、与本次无关」；
- 用「工作树干净」等措辞替代 `git status` 实际输出；
- 自报 PASS 文本（门禁数字必须来自日志/产物）。

---

## 九、停等点

```text
完成本报告 → 提交 → 停止
提交状态建议：READY FOR INDEPENDENT REVIEW
不得自行开启 L8，不得自行修改任何仓
等待主控（Amy）与 Human Authority（老板）裁定
```

---

## 十、发单回执

```text
发单时间   ：2026-09-16 14:34:19 +0800
工单编号   ：WO-20260915-EHAI-DOWNSTREAM-001-C
工单绝对路径：D:\_Progs\02Business\DeepBase\docs\ui\work-orders\WO-20260915-EHAI-DOWNSTREAM-001-C-跨产品抽象复核工单.md
派单人     ：主控（Amy · 沈予安）
承接方     ：开发甲
性质       ：READ-ONLY REVIEW（默认禁止修改任何仓）
```
