# WO-20260926-AUDIT-甲-A6 编译门结构轨与 CI 覆盖登记（B2 裁定执行甲段 · 4 项）

> 签发：主控 · 2026-09-26
> 基线锚点：HEAD `c5d6658`（= 乙 B2 验收结论 + 13 件并网注册 + 乙 B8 工单签发）
> 派工对象：**开发 AI 甲**
> 来源：B2 验收结论（`CodeReview/20260925-AUDIT-主控-乙-B2-验收结论.md`）§二.1 **结构轨** + §二.4 **CI 矩阵登记**；残留判据核对源自 `WO-20260923-AUDIT-甲-D3-全库DPR编译门.md` §三（本单**吸收**台账中该 D3 待开工行，不另立 D 号）。
> 与甲 A5（全 Core 域）、乙 B8（CodeReview 证据目录改名）**文件零重叠**；唯一耦合点 = A6-02 反向闸门的「绿」依赖乙 B8-01 先落地，见该项前置。

## 〇、开工纪律（违者整单打回）

1. **H15 原子提交**：四个子项（A6-01…A6-04）各自独立提交，message 带编号；显式 pathspec，前后 `git diff --cached --name-only` == 申报清单；**禁 push**。
2. **单线串行**：甲线当前在途 = **A5 优先**（其 R09 甲段是乙 B7 的最后前置），A6 次之；A5 未交付不得并开 A6。A6-02 的前置见 §一.2。
3. **禁动区维持**：`v1.1.0` 标签 / EHAI 冻结面 / `TestResults/**` / 旧轨 `Core/DeepBase.PluginManager.pas` / 新轨 `DeepBase.Plugins.*` / `Tests/DeepBaseTests.dpr`（已由主控收口注册，本单不得改）/ `09_工程脚本/eol-gate/eol_baseline.json`（禁 `--emit-baseline` 改写）。**本单不得改任何 `CodeReview/**` 内容**（改名归乙 B8-01，甲发现残留 `.dpr` 只许报，不许动手）。
4. **行号/符号定位**：不照抄本单行号；找不到符号 ⇒ 报「已不成立」并附 `git log -1 -- <file>`，不许绕。
5. **编译判据**：隔离 `--detach` 工作树 @ 目标 commit 亲跑；`--all` 全量面约 20 分钟量级，按需跑，主树红项逐件点名归属（基线红项名单以甲 D7 结论为参照，不得新增红）。
6. **编码/行尾**：`.js`/`.md`/`.json` 按 `.editorconfig`；证据 UTF-8 NUL=0；交付前四门复跑全 EXIT=0。
7. **fail-closed 总原则**：本单四子项全是门禁语义收口——任何「跳过并继续报绿」形态一律禁止；扫描/读取/排除规则失效 ⇒ EXIT≠0。

## 一、修单一览

| 编号 | 事项 | 来源裁定 | 性质 |
|---|---|---|---|
| A6-01 | 生产契约面 `CodeReview/**` 引用 fail-closed 校验 + 口径统一 | 验收结论 §二.1 结构轨 | 执行 |
| A6-02 | 反向闸门：`CodeReview/**` 下非 `.template` 的 `.dpr` ⇒ 红 | 验收结论 §二.1 结构轨 | 执行（有前置） |
| A6-03 | `Screen.Click` 三件 CI 编译覆盖坐实与登记 | 验收结论 §二.4 | 登记核对 + 执行 |
| A6-04 | 旧 D3 §三 7 判据逐条实测核对（只补不重写） | 旧 D3 工单残留 | 核对 + 补缺 |

## 二、逐项修单

### A6-01 [待执行] 生产契约面 `CodeReview/**` 引用 fail-closed 校验

- **代码事实（主控已核，甲复核）**：`09_工程脚本/build-gate/contracts/T0-生产契约面.txt` = `all-dpk` 选择子 + `Tests/DeepBaseTests.dpr` 显式条目；`check_build.js` 支持 `--all`（git 已跟踪全部 `.dpr`+`.dpk`）/ `--dpr` / `--dpk` / `--manifest` 四种面，`--all` 与点名/清单互斥；`git ls-files '*.dpr'` = **68**，其中 3 件在 `CodeReview/**`（`附件/B2FixtureRunner.dpr`、`附件/B2Seg0Probe.dpr`、`附件/B2-01-premise-probe.dpr`）。
- **执行**：manifest 解析处加 fail-closed 校验——显式清单条目若 resolve 到 `CodeReview/**` 下 ⇒ EXIT≠0 并打印该条目（防止回归手写证据路径进契约面）；选择子与 `--all` 语义**不改**（全量面无例外是既有设计，观测面恒非全绿有注释在案）；在 `README-编译门禁.md` 与契约注释同一处写清口径：**证据附件不进生产编译面，由 A6-02 反向闸门强制，不是第二套白名单**。
- **判据**：① 隔离树 T0 面复跑 EXIT=0（不因本项回归）；② 负向样本：构造一个含 `CodeReview/**` 条目的 manifest ⇒ 必红（写进 `test_negative_sample.js`）；③ `rg` 自证校验逻辑与 README 口径同源存在；④ 四门 EXIT=0。
- **边界**：只动 `09_工程脚本/build-gate/**`；不改任何 `.pas`/`.dpr` 被测对象。

### A6-02 [待执行] 反向闸门（有前置，fail-closed）

- **前置（硬性）**：开工第一步 `git ls-files 'CodeReview/**/*.dpr'`。当前 = **3**（改名归**乙 B8-01**，进行中）；仍为 3 ⇒ 反向闸门无法交付绿 ⇒ **停机报主控**协调顺序，不许自行改名、不许给门禁加 SKIP。为 0 ⇒ 直接开工。
- **执行**：在 `check_build.js` 或同族新门实现——`CodeReview/**` 下出现**非 `.template` 结尾**的 `.dpr` ⇒ EXIT≠0 并逐条打印路径；`.dpr.template` 探针别名不触发；闸门自身扫描失败（读不到目录等）⇒ 同样 EXIT≠0，禁 fail-open。
- **判据**：① 前置满足（该通配 = 0）时隔离树门 EXIT=0；② 乙 B8-01 落地后对其 3 件改名结果复跑绿（留原件）；③ 负向样本：人为在 `CodeReview/` 放 1 个非 `.template` `.dpr` ⇒ 必红，样本入库 `test_negative_sample.js`；④ 该闸门对 `--all`/`--manifest` 两种模式都生效（不止挂在一种模式上）；⑤ 四门 EXIT=0。

### A6-03 [待登记核对] `Screen.Click` 三件 CI 编译覆盖坐实

- **代码事实**：乙 B2 回执 §六-2 登记 `Features/DeepBase.Desktop.Screen.Click.{RegionLocator,SmartExecutor,DPIMapper}.pas` 不在任何编译 CI 面；主控已把 3 个对应测试单元（`Test.DeepBase.Desktop.Screen.Click.*`，属 13 件并网注册）挂进 `Tests/DeepBaseTests.dpr`，而该 dpr 是 T0 契约面条目 ⇒ **应已传递编译，但未坐实**。
- **执行**：坐实传递覆盖——隔离树单件编译三 SUT 单元各留 `BUILD_EXIT` 原件（或等价 T0 编译内的引用链取证，二者选一并说清依据）；把「三件的编译覆盖路径 = T0 dpr 传递」写进 `README-编译门禁.md` 或 T0 契约注释，消掉「不在任何 CI 面」的悬空登记。若坐实发现某件实际没被编译 ⇒ 停机上报附证据，**不许为凑绿硬加 uses 或改测试单元**。
- **判据**：① 三件 `BUILD_EXIT` 原件留档；② 覆盖路径登记落库；③ `git show --name-only` 自证本项零 `.pas` 改动；④ 四门 EXIT=0。

### A6-04 [待核对] 旧 D3 §三 7 判据实测核对（只补不重写）

- **代码事实**：`WO-20260923-AUDIT-甲-D3-全库DPR编译门.md` §三 共 7 条判据，09-23 交付记录「判据①⑦未成立（非本单之过——当时全库有在册红项）」；当前 `check_build.js` 已具备面选择/三态 EXIT/`gateSkipSet`/`gate-args` 复用/`test_negative_sample.js`，**具体哪些成立须甲以当前 HEAD 实测复核，不采信台账转述、不照抄本单描述**。
- **执行**：逐条实测 §三 7 判据（含：`.dpr` 总数与 `git ls-files '*.dpr'` 独立复算一致的自核输出；三条 fail-closed 逐型实测；负向样本 ≥3 条全红且含故意语法错误证明真编译；`gate-args.js` 无第二套 `arg()`）。已成立的：标记保留、**禁重写已绿代码**；不成立的：补到成立，补什么写什么。
- **判据**：① 逐条判定表（成立/不成立/补法）进回执；② 改动仅限未成立项，diff 逐段可读；③ 主控 `git show` 抽查确认为增量非重写；④ 四门 EXIT=0。

## 三、输出物与验收

- 回执：`CodeReview/20260926-AUDIT-甲-A6-交付回执.md`（逐项：提交哈希、判据跑录原件引用、A6-03 覆盖登记、A6-04 逐条判定表、A6-02 前置状态核对记录）。
- 证据：`CodeReview/20260926-AUDIT-甲-A6-证据/`（负向样本输出、T0 复跑原件、三件 BUILD_EXIT 原件、口径 diff；探针继续 `.dpr.template` 别名）。
- 验收：主控逐项亲跑判据（反向闸门负向样本 + T0 不回归 + A6-04 判定表复核）+ 亲读 diff + 四门复跑 + 隔离树编译对照基线；**甲自报不作为验收依据**。
- 衔接纪律：A6-02 依赖乙 B8-01，甲只核对不代改；A5 未完不并开；完工后回填台账（吸收的 D3 行改判归属）。

*主控 · 2026-09-26 · 签发即生效；本单为乙 B2 验收结论的甲侧执行面，范围限于编译门禁与登记，任何生产代码改动一律打回*
