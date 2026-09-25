# 门禁覆盖面总表

本表只回答一个问题：**每道门禁实际扫到了哪里、扫不到哪里**。规则本体在代码里，本表不复述；
交叉验证请用下方「计数口径」的复算命令，不要引用本表的数字作为判据。

建立工单：`docs/ui/work-orders/WO-20260923-AUDIT-乙-D4-门禁覆盖面与消噪收口.md`；
三项收口：`WO-20260923-AUDIT-乙-D5-门禁覆盖面残留三项收口.md`（§一-1 SKIP 单一真相源、§一-3 证据门禁扫描面、§一-3 基线状态自检）。

## 一、六道静态门禁的扫描面

| 门禁 | 入口 | 扫描根（默认） | 纳入扩展名 | 排除目录 | 计数（2026-09-23 12:01 快照，随在途文件漂移，复算方法见 §二） | 已知不覆盖 |
|---|---|---|---|---|---|---|
| 编码门禁 | `encoding-gate/check_pas_encoding.js` | 仓库根（`gate-args.js` 的 `--root`，默认为脚本上两级） | 源码面 `.pas`（全量 G1–G6）；扩展面 `.dpr/.dpk/.dfm/.fmx/.md/.sql`（仅 G2/G4，`check_pas_encoding.js:50`） | 共享 `gateSkipSet()` 12 项（`:47`，见 §一-1；门禁输出的「跳过目录 N」是**实际命中**的目录名数，不是集合大小） | 977 个 `.pas` + 653 个扩展面文件 | `.inc/.rss/.res/.json/.ps1/.py/.yml/.pas` 之外的任意扩展、无扩展文件；`TestResults/`、`bin/`、`dcu/` 等被 SKIP 的目录内的任何文件；被 SKIP 目录名之外的同名嵌套目录不受影响 |
| 行尾门禁 | `eol-gate/check_eol.js` | 仓库根（`--root`，`check_eol.js:28`） | `.pas`、`.md`（`:52`） | 共享 12 项（`:34`） | 1477 个文件 | 除 `.pas/.md` 外的一切文件（含 `.dpr/.dpk/.dfm/.sql/.json`）；`TestResults/` 内的 `.pas/.md` 不查 |
| 证据编码门禁 | `evidence-encoding-gate/check_evidence_encoding.js` | 仓库根的 `CodeReview/` 单层子树（`:29`） | **反向排除**：`CodeReview/**` 里除 `BINARY_EXT`（47 个二进制容器扩展名，`:34`）之外**一律纳入**——清单外的扩展名（`.cmd/.ps1/.bat/.csv/.md/.js/.py/.patch/…`）默认进门禁，新增证据类型不必改门禁（WO-20260923-AUDIT-乙-D5 §一-1） | 同一共享 12 项（`:30`，两种口径都生效：tracked 走 `inSkipDir`（`:43`），工作树走目录名判断（`:76`））；此外不在 `CodeReview/` 下的一律不扫 | **不抄活值**：`--list-files` 现算（tracked 口径），覆盖面 SSOT 在门禁里；改前扩展名白名单口径只有 211 件（D5 收口的净增即此差） | `CodeReview/` 之外的证据目录（`docs/`、`08_元管理/` 等）；`BINARY_EXT` 清单内的二进制容器（图片/压缩包/编译产物本身就是合法非 UTF-8 字节流）；未入库的本地产物（默认只看 tracked，`--all-worktree` 才切工作树） |
| 托管拷贝门禁 | `managed-copy-gate/check_managed_copy.js` | 仓库根（`gate-args.js` 的 `--root`，默认为脚本上两级 `:25`；改前是私有 `arg()`，见 §三） | `.pas`（`:61`） | 共享 12 项（`:41`） | 977 个 `.pas` | 非 `.pas` 文件里的内存操作（`.dpr/.dpk` 程序体、`.inc`）；行尾/编码/构建归属完全不查 |
| 构建归属门禁 | `build-ownership/check_build_ownership.js` | 仓库根（`gate-args.js` 的 `--root`，默认为脚本上两级 `:26`；改前是硬编码的本机绝对路径，见 §三） | 生产单元面：`PROD_DIRS` 8 目录内的 `.pas`（`:38`）；引用面：全库 `.dpk/.dproj/.dpr` | 共享 12 项（`:39`，**含 `TestResults`**，改前缺该目录名，见 §一-1） | 574 个生产单元 + 126 个构建文件（2026-09-24 实测；计数在输出头一行，红时同样可见） | 8 个 `PROD_DIRS` 之外目录里的单元（`Tests/`、`Examples/`、`ThirdParty/`、`Scripts/` 的孤儿单元不判）；`.dpr` 文件自身的编译可行性（属甲 D3 编译门）；`Core/` 之外新轨单元的位置 |
| 丙类损坏门禁 | `mojibake-gate/check_mojibake.js` | 仓库根的**已跟踪** `.pas`（`git ls-files -- '*.pas'`，CI checkout 即全量） | 只对**丙-B（结构性吞 ASCII：Delphi 单引号串跨行未闭合）**执法；丙-A（U+FFFD）/丙-C（双重编码）只作**定性 + 三档留痕分档**，其 tree-wide 违规仍归编码门禁 G1/G6（本门不造第二套计数，SSOT 见脚本头注释） | 共享 12 项（`gateSkipSet()`） | **不抄活值**：`--list-hits` 现算（末行「扫描 N 个 .pas / 丙-B 命中 M 处 / K 件」），覆盖面 SSOT 在门禁里 | 跨行串之外的编码损坏（丙-A/丙-C 违规判定归 encoding-gate）；`CodeReview/` 证据面丙-C（归 evidence-encoding-gate E3）；`.dpr/.dpk/.dfm` 不扫（丙-B 是 `.pas` 串词法问题）；逐件还原（不做）——本门只「看得见」 |

### 一-1 SKIP 目录名集：单一真相源与改前/改后对照

目录名集合只有一个定义处 `09_工程脚本/gate-skip.js`（与 `gate-args.js` 同族同位置），五道门一律
`const SKIP = gateSkipSet()`；「某个目录被哪道门跳过」从此不再有第二套答案。

| 门禁 | 改前（`72fa744` 源码字面量） | 改后 | 本次口径变化 |
|---|---|---|---|
| 编码门禁 | 私有 `new Set([...])` 12 项（`:44`） | `gateSkipSet()`（`:47`） | 无（内容相同，来源统一） |
| 行尾门禁 | 私有 12 项（`:31`） | `gateSkipSet()`（`:34`） | 无 |
| 证据编码门禁 | 私有 7 项，仅工作树遍历生效（`:26`） | `gateSkipSet()`（`:30`），**已跟踪 / 工作树两种口径同时生效**（`:43` `inSkipDir` + `:76`） | 纳入 `.claude BuildOutput DCUOutput bin dcu`，且补齐 tracked 口径的排除 |
| 托管拷贝门禁 | 私有 12 项（`:24`） | `gateSkipSet()`（`:26`） | 无 |
| 构建归属门禁 | 私有 11 项，**缺 `TestResults`**（`:22`） | `gateSkipSet()`（`:39`） | **`TestResults/` 从此被跳过**（CI 产物里的 `.dpr` 不再冒充生产引用面） |
| 甲 `build-gate/check_build.js` | 私有 13 项（含门禁专属 `Logs`） | 改前未改（不属乙 scope）→ **甲 D4 并网 `gateSkipSet('Logs')`** | 集合与共享 12 项 + `Logs` 逐位相同，枚举面零变化；该门不再持有内联副本，§四-5 的甲线残留登记清零 |

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
node 09_工程脚本/evidence-encoding-gate/check_evidence_encoding.js --list-files | wc -l   # 件数即活值，本表不登记
node 09_工程脚本/evidence-encoding-gate/check_evidence_encoding.js --list-mojibake          # E3 存量清单：命中行数<TAB>路径 + 「扫描 N 件 / 命中 M 行 / K 件」汇总
```

`--list-mojibake` 是 E3（双重编码乱码，WO-20260924-AUDIT-乙-D8 §1.2）存量清单
`evidence_encoding_baseline.json` 里 `mojibakeStock` 的唯一来源：登记/递减时逐行对照该输出，
不靠人抄。它是**可核可递减的存量登记**而不是豁免开关——命中明细每次运行都全量打印，
门只拦「清单外新文件」与「超封顶」，所以存量件永远看得见，只能因内容被还原而下降。
`mojibakeStock` 与 E1 的 `nulStock` 在基线里分列两个键（工单要求「单列清单、禁止录进豁免基线当默认」），
递减、删除、加条目各走各的口径，互不遮蔽。
判据本体（阈值取值、为什么替换符按标准解码器的 U+FFFD 个数计、为什么加表意文字占比）在
`check_evidence_encoding.js` 的 E3 段注释里，标定实测在
`CodeReview/20260924-AUDIT-乙-D8-证据/D8-阈值标定-良性语料零误报.txt`，本表不复述。

结论：**跨机器/跨时点比对数字前必须先对齐工作树，并对齐门禁口径版本**，否则「门禁数字变了」会被误读成「基线被改了」或「在途件多了」。
证据：`CodeReview/20260923-AUDIT-乙-D4-证据/eol计数复现-恒等式闭合.txt`。

## 三、门禁族的 fail-closed 现状

| 门禁 | 空扫描/坏参数是否拒绝放行 | 基线文件状态是否拒绝放行 | 说明 |
|---|---|---|---|
| 编码门禁 | 是 | 是（`EXIT=2`） | `--root` 缺失/空目录 ⇒ `EXIT=3`（`:168`、`:58–60`）；负向样本覆盖 5 组坏参数；基线经 `loadGateBaseline`（`:75`）校验 T1–T4 |
| 行尾门禁 | 是 | 是（`EXIT=2`） | 同上（`check_eol.js:43–44`、`:60–62`）；基线校验在 `:111` |
| 证据编码门禁 | 是 | 是（`EXIT=2`） | 扫描 0 项、`readdir` 失败、**本机 Node 无 GB18030 解码（E3 无法评估）** 各自 `EXIT=3` 并打印原因（fail-closed，绝不静默跳过 E3），基线不可信 ⇒ `EXIT=2`（`nulStock` + `mojibakeStock` 两键缺一即拦）；参数走 `gate-args.js`（改前是私有 `arg()` + 异族的 `--repo`，未知参数会被静默丢弃并回落到脚本自身所在树 ⇒ 甲 R8 §5.1 那类「带真实计数的假 PASS」入口，乙 D8 收口） |
| 托管拷贝门禁 | 是（`EXIT=3`） | 是（`EXIT=2`） | 参数走 `gate-args.js`（`:25`，乙 B1 收口，改前是私有 `arg()`——未知参数与大写 `--ROOT` 被静默忽略并回落默认根）；`walk()` 读目录失败即 `EXIT=3`（`:54`，改前 `catch` 后返回空集 ⇒ 扫 0 文件仍 `EXIT=0`）；扫描 0 个 `.pas` ⇒ `EXIT=3`；单文件读取失败 ⇒ `EXIT=3`；基线校验在 `:110` |
| 构建归属门禁 | 是（`EXIT=3`） | 是（`EXIT=2`） | 参数解析走 `gate-args.js`（`check_build_ownership.js:24`，改前是私有 `arg()`，`--ROOT` 会被静默忽略并回落默认根）；默认根为脚本上两级（`:26`，改前是硬编码本机绝对路径 ⇒ 在 CI 检出目录下扫空气却报绿）；`walk()` 读目录失败即 `EXIT=3` 并打印失败路径（`:52`）；构建文件面为 0 / 生产单元面为 0 各自独立判零（`:95`、`:96`）；基线校验在 `:131`，**排在 `--emit-baseline` 之前**（emit 要读旧基线以保留 47 条人工处置，坏基线必须先拦住）。负向样本：`build-ownership/test_negative_sample.js` T2 五型 + T3 修前对照（同一「默认根指错」夹具下旧形态假绿 EXIT=0、新形态 EXIT=3） |
| 丙类损坏门禁 | 是 | 是（`EXIT=2`） | `git ls-files` 枚举失败 ⇒ `EXIT=2`；扫到 0 个 `.pas` / 单文件读取失败 / `--build-red-list` 读取失败 ⇒ `EXIT=3`（fail-closed，绝不因空扫报绿）；基线经 `loadGateBaseline`（`pbStock` 缺键 ⇒ `EXIT=2`），且每条必须为 `{count≥0, reason 非空}`——缺 reason 视为「静默加入」即 `EXIT=2`（判据 3 第一道防线）；参数走 `gate-args.js`，默认根为脚本上两级（无绝对路径）；`--emit-baseline` 只缩短已登记件，拒写未登记文件、拒条目数增长（只减不增）。负向样本：`mojibake-gate/test_negative_sample.js` 四类检测器各 ≥1 红 + 三档留痕可辨 + 修前假绿对照（摘掉丙-B 执法 ⇒ 跨行未闭合串隐身 EXIT=0）+ 存量只减不增 + fail-closed |

「基线状态」一列由 `09_工程脚本/gate-baseline.js` 一处实现（T1 可读 / T2 合法 JSON 对象 / T3 溯源字段非空 /
T4 本门所需键齐全且类型正确），五道门只声明自己的键；负向样本在 `09_工程脚本/test_negative_sample.js` B 段
（5 门 × 空对象/顶层数组/截断 JSON/跨门顶替/文件缺失 ⇒ 全部 `EXIT=2`）。

> 与写入侧的分工：**写入动作由 `09_工程脚本/gate-emit-guard.js` 一处实现**（`--emit-baseline` 的窄根自证 /
> 只减不增 / 写前 `.bak`，乙 B1 交付），**本列守文件状态**（不管怎么被改的，改坏了就该红）。
> 本校验故意**不看条目数量**（无「条数地板」），否则「债务归零后合法重录」会被误伤——那类判断只属于写入侧；
> 写入侧的负样本（窄根/新增键/抬升/缩短 各 ≥2 例）在 `09_工程脚本/test_negative_sample.js` C 段。

修法（未覆盖面）：~~托管拷贝门禁仍走私有参数取值 + `walk` 吞错~~ **已由乙 B1 顺手收口**（`gate-args.js` 解析 + `walk` 读失败 `EXIT=3` + 空扫描 `EXIT=3`，与其余四道对齐）；构建归属门禁的同类缺陷已由 **乙 D7** 收口（同上表倒数第二行）。

## 四、当前明确不被任何门禁覆盖的清单

1. ~~**`.dpr` 的编译可行性**：全库 67 个 `.dpr` 中，被入口脚本/CI/BAT 引用的 29 个、未被引用的 38 个（判定脚本与清单见 `CodeReview/20260923-AUDIT-乙-D4-证据/`）。**没有任何门禁编译 `.dpr`**；静态门禁只能保证编码与引用，不保证可编译。~~ **已由甲 D3（`.dpr` 面）+ 甲 D4（`.dpk` 包工程面）收口**——`build-gate/check_build.js` 编译两面并给出 EXIT 判定，**本表不重复造门**，判定口径/耗时/契约分层见 `build-gate/README-编译门禁.md`；「哪些工程红、进入哪一层契约」属该门自己的台账（`CodeReview/20260923-AUDIT-甲-D3-交付回执.md`、`CodeReview/20260923-AUDIT-甲-D4-交付回执.md`），本表不复述。
2. **非 `.pas/.md` 文件的行尾**：`.sql`、`.json`、`.ps1`、`.dpr/.dpk/.dfm` 的行尾一致性无门禁（eol 只看 `.pas/.md`）。
3. **`CodeReview/` 之外的证据/文档正文编码**：~~扩展名清单不全~~ **已由乙 D5 §一-1 收口**——证据门禁改为「反向排除二进制清单」，`CodeReview/**` 里 `.cmd/.ps1/.bat/.csv/.md/.js/.py/.patch/…` 一律纳入（改前 211 → 改后 408 件，含甲 D2 那 2 件 `D2-*.cmd`），实际纳入清单由 `--list-files` 从门禁自身复算，本表不再复述。**仍不覆盖**：`CodeReview/` 之外的证据目录（`docs/**`、`08_元管理/**` 的 `.txt/.log/.csv/.xml`）——归属不变，这些是文档正文不是审计证据件，其编码由编码门禁扩展面（`.md/.sql` G2/G4）与行尾门禁兜住，NUL/证据专用规则按门禁职责边界（「审计证据不得 UTF-16/GBK 落盘」）刻意不限定 `docs/`；扩面到 `docs/` 需先定义 docs 的证据职责，不在门禁族现状内。二进制容器（`BINARY_EXT` 47 项）同样排除：图片/压缩包/编译产物本身就是合法非 UTF-8 字节流，纳入即必然误报。
4. **`PROD_DIRS` 之外目录的孤儿单元**：`Tests/`、`Examples/`、`ThirdParty/` 里的 `.pas` 是否被构建引用，构建归属门禁不判。
5. **`TestResults/` 目录**：~~四道门口径分裂~~ **已由乙 D5 §一-2 收口**——五道门共用 `gate-skip.js` 12 项，构建归属门补上 `TestResults`，CI 产物不再冒充生产引用面（实测：旧 11 项口径把孤儿判成「已引用」假绿 EXIT=0，新口径如实报 O1；见 §一-1 与 `CodeReview/20260923-AUDIT-乙-D5-证据/负向样本-六份真实输出.txt`）。~~**残留一项**：甲 `build-gate/check_build.js` 仍用私有 13 项（多一个该门专属的 `Logs`），未合并进共享集——不属乙 scope，登记给甲线（该门若改用 `gateSkipSet('Logs')` 即零成本合并，需甲自行验收其对 `Logs/` 的构建产物语义）。~~ **残留项已由甲 D4 收口**：该门枚举面改为 `gateSkipSet('Logs')`，与共享 12 项 + 本门专属 `Logs` 逐位相同（取证见 `CodeReview/20260923-AUDIT-甲-D4-证据/`），五道门至此同一真相源，`Logs/` 的构建产物语义按原口径保留（dcc64 日志目录不进枚举面）。
6. **`Scripts/*.ps1`、`09_工程脚本/*.js` 自身**：~~基线被改无自动告警~~ **基线面已由乙 D5 §一-3 收口**——五道门的基线一律经 `gate-baseline.js` 做 T1–T4 状态校验（不可读/非 JSON 对象/缺溯源/缺本门键 ⇒ `EXIT=2`），SKIP 集则由 `test_negative_sample.js` A1 断言「不得再出现内联副本」。两条**明确不做**：① **不做门禁脚本自身的语法/编码检查**——`node` 加载即报错，门禁红在运行时而非静默放行，收益低而维护成本实在（要新增一道扫描 `.js` 的门或引入 lint 依赖），本单按「登记」处理；② **不拦「形状正确但覆盖面被窄根重录」的基线**——文件状态校验只看形状与溯源，条目是否缩水属 `--emit-baseline` 写入动作，归 B1（防清空/防缩水/备份），在此重复实现会造成两套判据打架。
7. **DUnitX 短名过滤的裸 exe 用法**：`run_tests.ps1 -Run` 有「命中 0 ⇒ 红」守卫；直接调用 `.exe --run:` 仍会 EXIT=0（框架行为），WARP.md 已改为只推荐受守卫入口，但没有机器门禁能阻止裸调用。
8. ~~**Delphi 单引号串跨行未闭合（丙-B 结构性吞 ASCII）**：编码门禁 G1–G6 判字节合法性、U+FFFD 与双重编码，判不出「闭合引号被吞导致整件引号奇偶翻转」这一**结构**形态——此面此前无任何门禁覆盖。~~ **已由甲 D8 收口**：`mojibake-gate/check_mojibake.js` 以 Pascal 词法状态机（剥 `//`、`{}`、`(* *)`、`''` 转义）扫跨行未闭合串，对丙-B 执法（存量以 `pb_baseline.json` 单列、只减不增），输出三档留痕（FULL/LCS/DIFF）并与编译门 `check_build.js` 红清单交叉标记（同一文件双命中）。丙-A/丙-C 的 tree-wide 违规仍归 encoding-gate，本门只定性、不造第二套计数（SSOT）。
