# WO-20260924-AUDIT-甲-D10：BUG-449 修复并入 master + 两处收尾

> **接收方：开发 AI 甲**　**优先级：🟠 高（挂着的是真缺陷）**
> 开单：主控（沈予安）　前置：甲 D7/D8/D9 已验收（`CodeReview\20260924-AUDIT-主控-甲-D7-验收结论.md`、
> `…甲-D8-乙-D8-验收结论.md`、`…甲-D9-乙-D9-验收结论与分支裁定.md`）

---

## 段 1 · cherry-pick `de8d989` 进 master（BUG-449，BitmapSource 2 红）

- `de8d989`（`FrameDiffer` 的 `FLast`/`LLastShot` 双状态解耦，`Engine.CaptureScreen` 闸门解耦）已在 canary 分支验证过，master 上对应的 **2 条存量红至今未修**；
- 执行：`git cherry-pick de8d989` → 隔离工作树全量回归，确认 **BitmapSource 2 红转绿且无新红**；
- **分支处置（主控已裁定，照办即可）**：并入验证通过后删 `feat/wyjx-colormatch-canary`；其另 3 件独有提交（perception P2 docs/feat）逐件 `git diff` vs master 取证——无独有价值留痕后随删，**有独有价值先报再动**。

## 段 2 · eol 门新红修正（1 条）

`Examples/Templates/DocManager/Entity.Base.pas` 纯 LF ⇒ 转 CRLF（甲 D6 段3 补齐模板件时带入）。修后 eol 门 EXIT=0。

## 段 3 · 甲 D8 证据件 E3 自染更正（3 件）

只回显「原文」的证据件会被 E3 判成新命中。改「原文 → 还原后」双列格式（含 U+FFFD 天然不成罪）：
`CodeReview/20260919-AUDIT-甲-证据/A2-1-excerpt-ManifestVerifier-245-327.txt`、`…/R7/R7-gates-run.txt`、`…/A1/06-bypass-grep.txt`（以 E3 实际点名的 3 件为准）。修后 E3 存量回到 20 件封顶内、EXIT=0。

## 判据

1. master 上 BitmapSource 2 红 **BUILD_EXIT=0**，全量回归无新红；
2. `feat/wyjx-colormatch-canary` 处置完成且 de8d989 可从 master 到达（`git branch -a --contains` 非空）；
3. eol 门 EXIT=0；E3 EXIT=0（存量回到封顶内）；
4. 落笔**前** `git diff --cached --name-only` == 申报清单（硬规则）。

## 禁区

不动验签/Commerce 语义；canary 分支上 perception P2 的 3 件**未取证前不得删**。

---

*主控（沈予安）· 2026-09-24 · 本单完成后，master 携带 BUG-449 修复，canary 分支方可安全退场*
