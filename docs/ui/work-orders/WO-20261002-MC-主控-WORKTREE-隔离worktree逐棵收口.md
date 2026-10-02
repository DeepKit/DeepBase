# WO-20261002-MC-主控-WORKTREE 隔离 worktree 逐棵收口（主控自办 · P3）

**单号**：`WO-20261002-MC-主控-WORKTREE`
**派单**：主控（2026-10-02，`WO-20261002-MC-MC3` 项 4 ACCEPTED 派生）
**优先级**：P3（占磁盘与认知面，不阻塞功能）
**前置**：`CodeReview/20261002-AUDIT-主控-四单验收结论.md` §六-4
**授权面**：`git worktree` 管理操作；`CodeReview/**` 留档
**禁动区**：任何已跟踪文件；主工作树本体

---

## 〇、纪律与口径

1. **逐棵确认锚点后收口**，禁止 `git worktree prune` 一把梭。
2. 每棵删除前先在台账登记其锚点 commit 与用途，删后 `git worktree list` 复核。
3. A13 验收结论 §十 已记「`D:/ProgData/DeepBase-*` 全部隔离树**曾在验收过程中被外部清理**」
   —— 该批树零 tracked 证据损失，收口属低风险。
4. 不可逆：删除属不可逆操作，主控自核后执行，不交开发线。

---

## 一、现状与主控亲数（2026-10-02）

`git worktree list | wc -l` = **23**（1 主树 + 22 分离树）。

其中甲在本批取证新建 3 棵（`wt-post-a68264a` / `wt-preA8-3c8a6a7` / `wt-41b580a`），
报告记 21 棵；主控本批复跑又自建 2 棵（`wt-mc-post` / `wt-mc-pre`）⇒ 23。

| 组 | 数量 | 根 | 处置建议 |
|---|---|---|---|
| 主树 | 1 | `D:/_Progs/02Business/DeepBase` | **不动** |
| 本批复跑树 | 2 | `D:/_ProgData/DeepBase-REVIEW-MC/wt-mc-{post,pre}` | 保留至本批复核完结 |
| 本批取证树 | 3 | `D:/_ProgData/DeepBase-MC3-A5A8/wt-*`、`D:/_ProgData/DeepBase-TDR01/wt-41b580a` | 见 §二 |
| 早于本批 | 17 | `D:/_ProgData/DeepBase-*` 15 棵 + `E:/temp/db-a7-*` 2 棵 | 见 §二 |

---

## 二、判据（主控验收用）

| # | 判据 | 达成标准 |
|---|---|---|
| 1 | 逐棵建表 | 22 棵分离树各一行：路径 / 锚点 commit / 创建来源（哪个工单）/ 是否仍需保留 |
| 2 | 锚点亲核 | 每棵 `git -C <path> rev-parse HEAD` 与表内锚点一致，零「查无此树」 |
| 3 | 保留清单明确化 | 明确哪些保留（当前在验 / 反事实基线），其余逐棵删 |
| 4 | 收口记录 | 删前各记一行 worktree 状态，删后 `git worktree list` 全量一次 |
| 5 | 主树零影响 | 收口后 `git status --porcelain` 条数不劣于收口前 |
| 6 | 留档 | 全表 + 删前/删后 worktree list 落 `CodeReview/` 留档 |

**验收前置**：判据 1 的表格必须先于任何删除动作；表未建完不得删。

---

## 三、不在本单

1. 各树内的 `.dcu` 产物 —— 随树一并消失，不单独处理；主树的归 `WO-20261002-MC-主控-DCU`。
2. worktree 内若有未提交 tracked 改动 —— 逐棵 `git status` 确认，有改动的**先报主控**再议，不擅自丢。
