# 门禁覆盖面总表

本表只回答一个问题：**每道门禁实际扫到了哪里、扫不到哪里**。规则本体在代码里，本表不复述；
交叉验证请用下方「计数口径」的复算命令，不要引用本表的数字作为判据。

建立工单：`docs/ui/work-orders/WO-20260923-AUDIT-乙-D4-门禁覆盖面与消噪收口.md`；
三项收口：`WO-20260923-AUDIT-乙-D5-门禁覆盖面残留三项收口.md`（§一-1 SKIP 单一真相源、§一-3 证据门禁扫描面、§一-3 基线状态自检）。

## 一、五道静态门禁的扫描面

| 门禁 | 入口 | 扫描根（默认） | 纳入扩展名 | 排除目录 | 计数（2026-09-23 12:01 快照，随在途文件漂移，复算方法见 §二） | 已知不覆盖 |
|---|---|---|---|---|---|---|
| 编码门禁 | `encoding-gate/check_pas_encoding.js` | 仓库根（`gate-args.js` 的 `--root`，默认为脚本上两级） | 源码面 `.pas`（全量 G1–G6）；扩展面 `.dpr/.dpk/.dfm/.fmx/.md/.sql`（仅 G2/G4，`check_pas_encoding.js:50`） | 共享 `gateSkipSet()` 12 项（`:47`，见 §一-1；门禁输出的「跳过目录 N」是**实际命中**的目录名数，不是集合大小） | 977 个 `.pas` + 653 个扩展面文件 | `.inc/.rss/.res/.json/.ps1/.py/.yml/.pas` 之外的任意扩展、无扩展文件；`TestResults/`、`bin/`、`dcu/` 等被 SKIP 的目录内的任何文件；被 SKIP 目录名之外的同名嵌套目录不受影响 |
| 行尾门禁 | `eol-gate/check_eol.js` | 仓库根（`--root`，`check_eol.js:28`） | `.pas`、`.md`（`:52`） | 共享 12 项（`:34`） | 1477 个文件 | 除 `.pas/.md` 外的一切文件（含 `.dpr/.dpk/.dfm/.sql/.json`）；`TestResults/` 内的 `.pas/.md` 不查 |
| 证据编码门禁 | `evidence-encoding-gate/check_evidence_encoding.js` | 仓库根的 `CodeReview/` 单层子树（`:29`） | **反向排除**：`CodeReview/**` 里除 `BINARY_EXT`（47 个二进制容器扩展名，`:34`）之外**一律纳入**——清单外的扩展名（`.cmd/.ps1/.bat/.csv/.md/.js/.py/.patch/…`）默认进门禁，新增证据类型不必改门禁（WO-20260923-AUDIT-乙-D5 §一-1） | 同一共享 12 项（`:30`，两种口径都生效：tracked 走 `inSkipDir`（`:43`），工作树走目录名判断（`:76`））；此外不在 `CodeReview/` 下的一律不扫 | 408 个文件（git 已跟踪口径；改前扩展名白名单口径为 211） | `CodeReview/` 之外的证据目录（`docs/`、`08_元管理/` 等）；`BINARY_EXT` 清单内的二进制容器（图片/压缩包/编译产物本身就是合法非 UTF-8 字节流）；未入库的本地产物（默认只看 tracked，`--all-worktree` 才切工作树） |
| 托管拷贝门禁 | `managed-copy-gate/check_managed_copy.js` | 仓库根（`check_managed_copy.js:23`） | `.pas`（`:41`） | 共享 12 项（`:26`） | 977 个 `.pas` | 非 `.pas` 文件里的内存操作（`.dpr/.dpk` 程序体、`.inc`）；行尾/编码/构建归属完全不查 |
| 构建归属门禁 | `build-ownership/check_build_ownership.js` | **硬编码 `D:/_Progs/02Business/DeepBase`**（`:20`，非 `__dirname` 相对） | 生产单元面：`PROD_DIRS` 8 目录内的 `.pas`（`:23`）；引用面：全库 `.dpk/.dproj/.dpr` | 共享 12 项（`:24`，**含 `TestResults`**，改前缺该目录名，见 §一-1） | 574 个生产单元 + 128 个构建文件 | 8 个 `PROD_DIRS` 之外目录里的单元（`Tests/`、`Examples/`、`ThirdParty/`、`Scripts/` 的孤儿单元不判）；`.dpr` 文件自身的编译可行性（属甲 D3 编译门）；`Core/` 之外新轨单元的位置 |

### 一-1 SKIP 目录名集：单一真相源与改前/改后对照

目录名集合只有一个定义处 `09_工程脚本/gate-skip.js`（与 `gate-args.js` 同族同位置），五道门一律
`const SKIP = gateSkipSet()`；「某个目录被哪道门跳过」从此不再有第二套答案。

| 门禁 | 改前（`72fa744` 源码字面量） | 改后 | 本次口径变化 |
|---|---|---|---|
| 编码门禁 | 私有 `new Set([...])` 12 项（`:44`） | `gateSkipSet()`（`:47`） | 无（内容相同，来源统一） |
| 行尾门禁 | 私有 12 项（`:31`） | `gateSkipSet()`（`:34`） | 无 |
| 证据编码门禁 | 私有 7 项，仅工作树遍历生效（`:26`） | `gateSkipSet()`（`:30`），**已跟踪 / 工作树两种口径同时生效**（`:43` `inSkipDir` + `:76`） | 纳入 `.claude BuildOutput DCUOutput bin dcu`，且补齐 tracked 口径的排除 |
| 托管拷贝门禁 | 私有 12 项（`:24`） | `gateSkipSet()`（`:26`） | 无 |
| 构建归属门禁 | 私有 11 项，**缺 `TestResults`**（`:22`） | `gateSkipSet()`（`:24`） | **`TestResults/` 从此被跳过**（CI 产物里的 `.dpr` 不再冒充生产引用面） |
| 甲 `build-gate/check_build.js` | 私有 13 项（含门禁专属 `Logs`） | 未改 | 不属乙 scope：该门还需 `Logs`，且 SKIP 由甲线自有工单负责（登记见 §四-5） |

复算命令（逐门 grep 即得改前/改后，原始输出见 `CodeReview/20260923-AUDIT-乙-D5-证据/SKIP集对照-改前改后.txt`）：

```
for f in encoding-gate/check_pas_encoding.js eol-gate/check_eol.js \
         evidence-encoding-gate/check_evidence_encoding.js managed-copy-gate/check_managed_copy.js \
         build-ownership/check_build_ownership.js build-gate/check_build.js; do
  echo "== $f"; git show HEAD:09_工程脚本/$f | grep -n 'const SKIP'; done      # 改前
node -e "console.log(require('./09_工程脚本/gate-skip').GATE_SKIP_DIRS.join(' '))"  # 唯一集合
```

「改后是否还有第二份副本」由 `09_工程脚本/test_negative_sample.js` A1 静态断言守住
（任一门引用缺失或重新出现内联目录字面量 ⇒ 测试红）；口径分裂的**实测后果**由 A2 守住
（`TestResults/StrayRunner.dpr` 引用孤儿单元：旧 11 项口径假绿 EXIT=0，新口径如实报 O1）。

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
| 16:3x（乙 D5） | 977 | 662 | 1486 | 408 | 两件事叠加：① **口径变更（证据列）**——同一批已跟踪件由白名单 211 → 反向排除 408 纳入，`.pas/.md` 面不受影响，逐扩展名对账见 `CodeReview/20260923-AUDIT-乙-D5-证据/证据门禁扫描面-改前未覆盖清单.txt`；② **在途件（扩展面/行尾列）**——`.md` 面 500→509 = 他方 `fce392d`/`58f3106`/`72fa744` 等入库净 +8 件已跟踪 `.md`、+1 件本单新建回执（未跟踪），恒等式 `509 = 496 − 3 + 29 − 13` 闭合，扩展面 653→662 同因 |

证据门禁的「本次到底扫了哪些件」不再由本表复述（复述必然漂），改由门禁自身打印：

```
node 09_工程脚本/evidence-encoding-gate/check_evidence_encoding.js --list-files | wc -l   # 408
```

结论：**跨机器/跨时点比对数字前必须先对齐工作树，并对齐门禁口径版本**，否则「门禁数字变了」会被误读成「基线被改了」或「在途件多了」。
证据：`CodeReview/20260923-AUDIT-乙-D4-证据/eol计数复现-恒等式闭合.txt`。

## 三、门禁族的 fail-closed 现状

| 门禁 | 空扫描/坏参数是否拒绝放行 | 基线文件状态是否拒绝放行 | 说明 |
|---|---|---|---|
| 编码门禁 | 是 | 是（`EXIT=2`） | `--root` 缺失/空目录 ⇒ `EXIT=3`（`:168`、`:58–60`）；负向样本覆盖 5 组坏参数；基线经 `loadGateBaseline`（`:75`）校验 T1–T4 |
| 行尾门禁 | 是 | 是（`EXIT=2`） | 同上（`check_eol.js:43–44`、`:60–62`）；基线校验在 `:111` |
| 证据编码门禁 | 是 | 是（`EXIT=2`） | 扫描 0 项即 `EXIT=3`（`:97–100`），基线不可信 ⇒ `EXIT=2`（`:84` → `gate-baseline.js`） |
| 托管拷贝门禁 | **否** | 是（`EXIT=2`） | `walk()` 对不存在的根 `catch` 后返回空集（`check_managed_copy.js:36`），`--root <不存在>` ⇒ 扫 0 文件仍 `EXIT=0`；大写 `--ROOT` 被静默忽略并回落到默认根；基线校验在 `:86` |
| 构建归属门禁 | **否** | 是（`EXIT=2`） | 同上（`check_build_ownership.js:29`）；且默认根为本机绝对路径，在 CI 检出目录下永远扫不到东西，而 fail-open 让它报绿；基线校验在 `:96`，**排在 `--emit-baseline` 之前**（emit 要读旧基线以保留 47 条人工处置，坏基线必须先拦住） |

「基线状态」一列由 `09_工程脚本/gate-baseline.js` 一处实现（T1 可读 / T2 合法 JSON 对象 / T3 溯源字段非空 /
T4 本门所需键齐全且类型正确），五道门只声明自己的键；负向样本在 `09_工程脚本/test_negative_sample.js` B 段
（5 门 × 空对象/顶层数组/截断 JSON/跨门顶替/文件缺失 ⇒ 全部 `EXIT=2`）。

> 与 B1（`WO-20260922-AUDIT-乙-基线写入守卫`）的分工：**B1 守写入动作**（`--emit-baseline` 防清空/防缩水/备份），
> **本列守文件状态**（不管怎么被改的，改坏了就该红）。本校验故意**不看条目数量**（无「条数地板」），
> 否则「债务归零后合法重录」会被误伤——那类判断只属于 B1 的写入侧。

修法（未覆盖面，非 D4/D5 scope）：给托管拷贝/构建归属两道门禁补 `gate-args.js` 解析 + 空扫描守卫，与其余三道对齐。

## 四、当前明确不被任何门禁覆盖的清单

1. **`.dpr` 的编译可行性**：全库 67 个 `.dpr` 中，被入口脚本/CI/BAT 引用的 29 个、未被引用的 38 个（判定脚本与清单见 `CodeReview/20260923-AUDIT-乙-D4-证据/`）。**没有任何门禁编译 `.dpr`**；静态门禁只能保证编码与引用，不保证可编译。该缺口由甲 `WO-20260923-AUDIT-甲-D3` 的全库编译门负责闭合，本表不重复造门。
2. **非 `.pas/.md` 文件的行尾**：`.sql`、`.json`、`.ps1`、`.dpr/.dpk/.dfm` 的行尾一致性无门禁（eol 只看 `.pas/.md`）。
3. **`CodeReview/` 之外的证据/文档正文编码**：~~扩展名清单不全~~ **已由乙 D5 §一-1 收口**——证据门禁改为「反向排除二进制清单」，`CodeReview/**` 里 `.cmd/.ps1/.bat/.csv/.md/.js/.py/.patch/…` 一律纳入（改前 211 → 改后 408 件，含甲 D2 那 2 件 `D2-*.cmd`），实际纳入清单由 `--list-files` 从门禁自身复算，本表不再复述。**仍不覆盖**：`CodeReview/` 之外的证据目录（`docs/**`、`08_元管理/**` 的 `.txt/.log/.csv/.xml`）——归属不变，这些是文档正文不是审计证据件，其编码由编码门禁扩展面（`.md/.sql` G2/G4）与行尾门禁兜住，NUL/证据专用规则按门禁职责边界（「审计证据不得 UTF-16/GBK 落盘」）刻意不限定 `docs/`；扩面到 `docs/` 需先定义 docs 的证据职责，不在门禁族现状内。二进制容器（`BINARY_EXT` 47 项）同样排除：图片/压缩包/编译产物本身就是合法非 UTF-8 字节流，纳入即必然误报。
4. **`PROD_DIRS` 之外目录的孤儿单元**：`Tests/`、`Examples/`、`ThirdParty/` 里的 `.pas` 是否被构建引用，构建归属门禁不判。
5. **`TestResults/` 目录**：~~四道门口径分裂~~ **已由乙 D5 §一-2 收口**——五道门共用 `gate-skip.js` 12 项，构建归属门补上 `TestResults`，CI 产物不再冒充生产引用面（实测：旧 11 项口径把孤儿判成「已引用」假绿 EXIT=0，新口径如实报 O1；见 §一-1 与 `CodeReview/20260923-AUDIT-乙-D5-证据/负向样本-六份真实输出.txt`）。**残留一项**：甲 `build-gate/check_build.js` 仍用私有 13 项（多一个该门专属的 `Logs`），未合并进共享集——不属乙 scope，登记给甲线（该门若改用 `gateSkipSet('Logs')` 即零成本合并，需甲自行验收其对 `Logs/` 的构建产物语义）。
6. **`Scripts/*.ps1`、`09_工程脚本/*.js` 自身**：~~基线被改无自动告警~~ **基线面已由乙 D5 §一-3 收口**——五道门的基线一律经 `gate-baseline.js` 做 T1–T4 状态校验（不可读/非 JSON 对象/缺溯源/缺本门键 ⇒ `EXIT=2`），SKIP 集则由 `test_negative_sample.js` A1 断言「不得再出现内联副本」。两条**明确不做**：① **不做门禁脚本自身的语法/编码检查**——`node` 加载即报错，门禁红在运行时而非静默放行，收益低而维护成本实在（要新增一道扫描 `.js` 的门或引入 lint 依赖），本单按「登记」处理；② **不拦「形状正确但覆盖面被窄根重录」的基线**——文件状态校验只看形状与溯源，条目是否缩水属 `--emit-baseline` 写入动作，归 B1（防清空/防缩水/备份），在此重复实现会造成两套判据打架。
7. **DUnitX 短名过滤的裸 exe 用法**：`run_tests.ps1 -Run` 有「命中 0 ⇒ 红」守卫；直接调用 `.exe --run:` 仍会 EXIT=0（框架行为），WARP.md 已改为只推荐受守卫入口，但没有机器门禁能阻止裸调用。
