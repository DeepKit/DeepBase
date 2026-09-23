# 门禁覆盖面总表

本表只回答一个问题：**每道门禁实际扫到了哪里、扫不到哪里**。规则本体在代码里，本表不复述；
交叉验证请用下方「计数口径」的复算命令，不要引用本表的数字作为判据。

建立工单：`docs/ui/work-orders/WO-20260923-AUDIT-乙-D4-门禁覆盖面与消噪收口.md`。

## 一、五道静态门禁的扫描面

| 门禁 | 入口 | 扫描根（默认） | 纳入扩展名 | 排除目录 | 计数（2026-09-23 12:01 快照，随在途文件漂移，复算方法见 §二） | 已知不覆盖 |
|---|---|---|---|---|---|---|
| 编码门禁 | `encoding-gate/check_pas_encoding.js` | 仓库根（`gate-args.js` 的 `--root`，默认为脚本上两级） | 源码面 `.pas`（全量 G1–G6）；扩展面 `.dpr/.dpk/.dfm/.fmx/.md/.sql`（仅 G2/G4，`check_pas_encoding.js:47`） | `SKIP` 12 项：`.git .claude __history BuildOutput DCUOutput bin dcu node_modules .tmp .superpowers .workbuddy TestResults`（`:44`；门禁输出的「跳过目录 N」是**实际命中**的目录名数，不是集合大小） | 977 个 `.pas` + 653 个扩展面文件 | `.inc/.rss/.res/.json/.ps1/.py/.yml/.pas` 之外的任意扩展、无扩展文件；`TestResults/`、`bin/`、`dcu/` 等被 SKIP 的目录内的任何文件；被 SKIP 目录名之外的同名嵌套目录不受影响 |
| 行尾门禁 | `eol-gate/check_eol.js` | 仓库根（`--root`，`check_eol.js:19`） | `.pas`、`.md`（`:49`） | 同上 12 项（`:31`） | 1477 个文件 | 除 `.pas/.md` 外的一切文件（含 `.dpr/.dpk/.dfm/.sql/.json`）；`TestResults/` 内的 `.pas/.md` 不查 |
| 证据编码门禁 | `evidence-encoding-gate/check_evidence_encoding.js` | 仓库根的 `CodeReview/` 单层子树（`:24`） | `CodeReview/**` 的 `.txt/.log/.csv/.xml`（`:42–43`） | 不在 `CodeReview/` 下的东西一律不扫；不走 SKIP 集，改走 `git ls-files` | 199 个文件（git 已跟踪口径 = 174 存量 + 本单 17 + 甲 D2 落笔 `3c64b72` 的 8；其 2 件 `.cmd` 不在门禁扩展清单内 ⇒ 扫不到，见 §四-3） | `CodeReview/` 之外的证据目录（`docs/`、`08_元管理/` 等）；`.md` 证据（`CodeReview/**/*.md` 不在扩展清单内）；未入库的本地产物（默认只看 tracked，`--all-worktree` 才切工作树） |
| 托管拷贝门禁 | `managed-copy-gate/check_managed_copy.js` | 仓库根（`check_managed_copy.js:21`） | `.pas`（`:39`） | 同上 12 项（`:24`） | 977 个 `.pas` | 非 `.pas` 文件里的内存操作（`.dpr/.dpk` 程序体、`.inc`）；行尾/编码/构建归属完全不查 |
| 构建归属门禁 | `build-ownership/check_build_ownership.js` | **硬编码 `D:/_Progs/02Business/DeepBase`**（`:18`，非 `__dirname` 相对） | 生产单元面：`PROD_DIRS` 8 目录内的 `.pas`（`:21`）；引用面：全库 `.dpk/.dproj/.dpr` | 同上 12 项**但缺 `TestResults`**（`:22`） | 574 个生产单元 + 128 个构建文件 | 8 个 `PROD_DIRS` 之外目录里的单元（`Tests/`、`Examples/`、`ThirdParty/`、`Scripts/` 的孤儿单元不判）；`.dpr` 文件自身的编译可行性（属甲 D3 编译门）；`Core/` 之外新轨单元的位置 |

## 二、计数口径（复算方法）

四道文件系统遍历型门禁（编码/行尾/托管拷贝/构建归属）**忽略 `.gitignore`，只看目录名 SKIP 集**，
所以计数是**工作树口径**：未跟踪且未被忽略的文件同样计入，已跟踪但在工作树里被删除的文件不再计入。
这是「1433→1426→1474→1475→1476→1477」这类漂移的唯一来源，与基线无关（`eol_baseline.json` 自 `c0772f4`（2026-09-20）起未被改写过）。

计数恒等式（三条命令即可复算，SKIP 集为表中所列 12 项；下式为 2026-09-23 12:01 快照）：

```
门禁计数 = git ls-files          − git ls-files -d        + git ls-files -o --exclude-standard
           − 位于 SKIP 目录内的（已跟踪 + 未跟踪）
.pas:  977 = 975 − 0 + 2 − 0     （两条未跟踪 .pas 是 .ai/subset/{Core/b,Features/a}.pas，非门禁域但被扫）
.md:   500 = 488 − 3 + 28 − 13   （13 = .workbuddy/memory 下 5 tracked + 8 untracked）
合计: 1477 = 977 + 500 ✓ 与 `node 09_工程脚本/eol-gate/check_eol.js --root .` 输出一致
```

同一工作树连跑两次输出逐字节相同 ⇒ 计数**确定**；跨时刻的差异**全部由在途文件造成**，且可逐件对账。
本单取证期间的三次快照（原始输出见 `CodeReview/20260923-AUDIT-乙-D4-证据/eol计数复现-恒等式闭合.txt`）：

| 快照 | `.pas` | 扩展面 | 行尾 | 证据（已跟踪） | 与上一快照的差值归因 |
|---|---|---|---|---|---|
| 11:36 | 977 | 651 | 1475 | 174 | — |
| 11:51 | 977 | 652 | 1476 | 174 | +1 件 `.md`：本单新建交付回执（未跟踪、不在 SKIP 内，同时命中扩展面与 `.md` 面），恒等式两边 1:1 闭合 |
| 12:01 | 977 | 653 | 1477 | 199 | 他方落笔 `3c64b72`（甲 D2）：+1 件 `.md` 回执、+8 件 `.txt/.log/.xml` 证据、另 2 件 `.cmd` 不在证据门禁扩展清单内 |

结论：**跨机器/跨时点比对数字前必须先对齐工作树**，否则「门禁数字变了」会被误读成「基线被改了」。
证据：`CodeReview/20260923-AUDIT-乙-D4-证据/eol计数复现-恒等式闭合.txt`。

## 三、门禁族的 fail-closed 现状

| 门禁 | 空扫描/坏参数是否拒绝放行 | 说明 |
|---|---|---|
| 编码门禁 | 是 | `--root` 缺失/空目录 ⇒ `EXIT=3`（`:158`、`:41`）；负向样本覆盖 5 组坏参数 |
| 行尾门禁 | 是 | 同上（`check_eol.js:41`、`:57`） |
| 证据编码门禁 | 是 | 扫描 0 项即 `EXIT=3`（`:86–87`），另有 `EXIT=2` 分支 |
| 托管拷贝门禁 | **否** | `walk()` 对不存在的根 `catch` 后返回空集（`check_managed_copy.js:33`），`--root <不存在>` ⇒ 扫 0 文件仍 `EXIT=0`；大写 `--ROOT` 被静默忽略并回落到默认根 |
| 构建归属门禁 | **否** | 同上（`check_build_ownership.js:31`）；且默认根为本机绝对路径，在 CI 检出目录下永远扫不到东西，而 fail-open 让它报绿 |

修法（未覆盖面，非本单 scope，见下）：给这两道门禁补 `gate-args.js` 解析 + 空扫描守卫，与其余三道对齐。

## 四、当前明确不被任何门禁覆盖的清单

1. **`.dpr` 的编译可行性**：全库 67 个 `.dpr` 中，被入口脚本/CI/BAT 引用的 29 个、未被引用的 38 个（判定脚本与清单见 `CodeReview/20260923-AUDIT-乙-D4-证据/`）。**没有任何门禁编译 `.dpr`**；静态门禁只能保证编码与引用，不保证可编译。该缺口由甲 `WO-20260923-AUDIT-甲-D3` 的全库编译门负责闭合，本表不重复造门。
2. **非 `.pas/.md` 文件的行尾**：`.sql`、`.json`、`.ps1`、`.dpr/.dpk/.dfm` 的行尾一致性无门禁（eol 只看 `.pas/.md`）。
3. **`CodeReview/` 之外的证据/文档正文编码**：证据门禁限定 `CodeReview/`；`docs/**` 的 `.txt/.log/.csv/.xml` 与 `CodeReview/**/*.md` 均不在扫描内（`docs/**/*.md` 的编码由编码门禁扩展面 G2/G4 兜住，行尾由 eol 兜住，但 NUL/证据专用规则不覆盖）；`CodeReview/**` 里扩展名不在 `.txt/.log/.csv/.xml` 清单内的证据件同样扫不到（实例：甲 D2 落笔 `3c64b72` 的 2 件 `D2-*.cmd` 与 11 件中仅 8 件进门禁）。
4. **`PROD_DIRS` 之外目录的孤儿单元**：`Tests/`、`Examples/`、`ThirdParty/` 里的 `.pas` 是否被构建引用，构建归属门禁不判。
5. **`TestResults/` 目录**：编码/行尾/托管拷贝三道 SKIP 它（合理：CI 产物），构建归属门禁因 SKIP 集缺该目录名而不一致（本单未改，登记为待收口）。
6. **`Scripts/*.ps1`、`09_工程脚本/*.js` 自身**：任何门禁都不检查门禁脚本自身的语法/编码一致性之外的东西；门禁被绕过（改 `SKIP`、扩基线）无自动告警，靠工单回执与基线 `generated` 溯源字段人工审。
7. **DUnitX 短名过滤的裸 exe 用法**：`run_tests.ps1 -Run` 有「命中 0 ⇒ 红」守卫；直接调用 `.exe --run:` 仍会 EXIT=0（框架行为），WARP.md 已改为只推荐受守卫入口，但没有机器门禁能阻止裸调用。
