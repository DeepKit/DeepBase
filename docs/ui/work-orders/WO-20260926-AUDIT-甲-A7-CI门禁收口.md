# WO-20260926-AUDIT-甲-A7 CI 门禁收口（负向样本纳入 + 噪声基线归因重发 + IntegrationTests 面收口 · 3 项）

> 签发：主控 · 2026-09-26（**2026-09-28 修订**：增补 A7-03，见文末 §四 修订记录）
> 基线锚点：HEAD `d80671e`（= 主控 dproj 搜索面修复 + 乙 B8 / 甲 A6 验收结论落笔）
> 派工对象：**开发 AI 甲**
> 来源：乙 B8 回执 §三与甲 A6 回执 §三.2 独立指出的同一 CI 缺口 + 本日 T0 复跑的噪声门挂账（乙 B8 / 甲 A6 两份验收结论共同裁定派出）+ 乙 B9 回执 §四.2 收口建议（`DeepBaseIntegrationTests.dpr` 门禁承接，主控裁定并入本单为 A7-03）。
> 与甲 A5（全 Core 域）文件零重叠；仅动 `.github/workflows/delphi-ci.yml`、`09_工程脚本/build-gate/**` 与 `contracts/**` 两个清单 txt。

## 〇、开工纪律（违者整单打回）

1. **H15 原子提交**：三子项（A7-01/A7-02/A7-03）各自独立提交，message 带编号；显式 pathspec，前后 `git diff --cached --name-only` == 申报清单；**禁 push**。
2. **单线串行**：A5（甲线第一优先，乙 B7 最后前置）未交付前，本单不得抢跑；若老板直派则按直派执行并登记口径（同 A6 先例）。**执行序（2026-09-28 主控核定）**：A7-03 先于 A7-02 重发——面孔迁移改变噪声归属面，A7-02 的归因表与 `--emit-baseline` 必须以**迁移后**的面为准，否则归因表留「不明增量」。A7-01 与二者无耦合，任意序。
3. **禁动区维持**：`v1.1.0` 标签 / EHAI 冻结面 / `TestResults/**` / 旧轨 `Core/DeepBase.PluginManager.pas` / 新轨 `DeepBase.Plugins.*` / `Tests/DeepBaseTests.dpr|.dproj` / `09_工程脚本/eol-gate/eol_baseline.json`（禁 `--emit-baseline` 改写）。**本单零生产代码、零 `.pas`/`.dpr` 改动**；不得为压噪声删 Hint 源或改编译门判定语义；`contracts/**` 只许按 A7-03 迁行，不得改判定语义文本。
4. **符号/路径定位**：CI 文件、门禁代码与契约清单以当前 HEAD 实测为准，不照抄本单描述；找不到 ⇒ 报「已不成立」附 `git log -1`。
5. **编译判据**：隔离 `--detach` 工作树 @ 目标 commit；T0 全量约 20 分钟量级，按需跑；主树红项逐件点名归属。
6. **fail-closed**：emit 基线只许「同面、带归因、经 `gate-emit-guard` 校验」三条件齐备才做；归因表对不上 ⇒ 停机上报，不许硬发；A7-03 同 runner 任一 fixture 在环境前提齐备下不能稳定绿 ⇒ 停机上报，先解决再迁移。

## 一、修单一览

| 编号 | 事项 | 来源 | 性质 |
|---|---|---|---|
| A7-01 | `.github/workflows/delphi-ci.yml` 纳入 `build-gate/test_negative_sample.js` | 乙 B8 §三 + 甲 A6 §三.2 | 执行 |
| A7-02 | T0 噪声基线逐码归因 + 同面重发（H2077/H2443/H2269 超基线治理） | B8/A6 两份验收结论 §四 挂账 | 执行 |
| A7-03 | `DeepBaseIntegrationTests.dpr` 从 T1-观测面升入 T0 判定面（迁行收口） | 乙 B9 回执 §四.2 收口建议 | 执行 |

## 二、逐项修单

### A7-01 [待执行] CI 纳入 build-gate 负向样本

- **代码事实（主控已核）**：`delphi-ci.yml` 现有 8 个负样本步骤（encoding / build-ownership / eol / managed-copy / evidence-encoding / mojibake / contract X `test_negative_sample.js` + `build-gate/test_noise.js`），**唯独没跑 `09_工程脚本\build-gate\test_negative_sample.js`**（当前 41 例，含甲 A6 新增 6 例反向闸门样本）⇒ 编译门禁语义回归在 CI 无人值守。
- **执行**：在既有负样本步骤序列的语义位置（编译门相关处）补一步 `node .\09_工程脚本\build-gate\test_negative_sample.js`，命名/顺序与既有步骤风格一致；不改其他步骤。
- **判据**：① `git diff` 自证只新增该步骤；② 主树亲跑该命令 EXIT=0（41 例 PASS 跑录留档）；③ 复跑 CI 文件语法校验（若 workflow 有 lint 工具则跑，无则人工核 YAML 结构）；④ 四门 EXIT=0。

### A7-02 [待执行] T0 噪声基线归因重发

- **代码事实（主控已核）**：隔离树 @`d80671e` 跑 T0：26/26 `BUILD_EXIT=0`，噪声门 H2077 **412>401**、H2443 **123>118**、H2269 **5>4**（B2 验收 @`4e3d0d4` 时点为 409/122，即本批并网测试单元增量 +3/+1/+1；更早基线 401/118/4 不含 13 件新用例 Hint）。
- **执行**：① 逐码归因——对 H2077/H2443/H2269 三个码各定位「新增 Hint 的工程/单元/提交」（可用隔离树 @`d80671e` vs @`4e3d0d4` vs 基线对应树逐面编译比对跑录）；② 归因表全部落到具体提交后，走**同面**（`--manifest contracts/T0-生产契约面.txt`）`--emit-baseline` 重发 `noise-baseline.json`，经 `gate-emit-guard` 校验；③ 重发后复跑 T0：26/26 BUILD_EXIT=0 且门禁整体 **EXIT=0**。
- **判据**：① 归因表（码 × 工程 × 提交 × 条数）进回执，无「不明增量」残留；② 重发跑录 + `gate-emit-guard` 校验结果留档；③ 重发后 T0 门禁 EXIT=0（隔离树）；④ `git diff` 自证除 `noise-baseline.json` 外零其他门禁语义改动；⑤ 四门 EXIT=0。
- **边界**：只重发基线数字，不改 `check_build.js` 判定逻辑、不动 Hint 产生源；若归因发现某增量来自**主控并网注册笔以外**的意外源 ⇒ 停机上报，先归因后发。

### A7-03 [待执行] IntegrationTests.dpr 升入 T0 判定面

- **代码事实（主控已核 + 乙 B9 诊断回执 §二/§四.2）**：`Tests/Integration/DeepBaseIntegrationTests.dpr` 现只挂 **T1-观测面**（`contracts/T1-观测面.txt:41`；观测面口径 = 编且记录、**红不阻断**）。B9 诊断坐实：该 runner 能编（`check_build.js --dpr Tests/Integration/DeepBaseIntegrationTests.dpr` BUILD_EXIT=0），本地 2026-09-22 跑录早已 `errors="1"`（正是 CommerceE2E 日期炸弹），但 T1 红不阻断 + `TestResults/**` 未跟踪 + CI `integration-tests` job 两次 run（`32099652781`/`33701496844`）**均 cancelled**（self-hosted `delphi-windows` runner 未接）⇒ 该面跑出的红不落任何门禁，等于没信号。**仓库侧唯一可落地杠杆是面孔迁移**；CI self-hosted runner 落实属仓外基础设施轨，由主控登记上交，**本单不负责**。
- **环境前提（迁入 T0 即升为阻断面，须在判据坐实可复现）**：集成 runner 依赖 `sqlite3.dll`（`run_tests.ps1` 的 `Ensure-SqliteDll` 自动保障）、`DEEPBASE_ALLOW_LOCALHOST_HTTP=1`、默认 `--exclude:DBEnv`（B9 回执 §二 环境前提）。CommerceE2E 单 fixture 不依赖以上任何一项，但同 runner 的 WebAPI/WebSocket fixture 依赖——**迁移按 runner 收口，两类混面是既有事实**，本单不改构成。
- **执行**：把 `Tests/Integration/DeepBaseIntegrationTests.dpr` 从 `contracts/T1-观测面.txt` 清单移入 `contracts/T0-生产契约面.txt` 清单（逐行迁移，行文格式随目标清单现状）；不改任何门禁代码、runner 语义、`run_tests.ps1`、dpr/.dproj。
- **判据**：① `git diff` 自证只动两个契约 txt 各一行（一删一增）；② 隔离 `--detach` 工作树 @ 目标 commit：`check_build.js --dpr Tests/Integration/DeepBaseIntegrationTests.dpr` **BUILD_EXIT=0**（迁移后该 dpr 按 T0 口径判定）；③ 主树环境前提齐备下 `run_tests.ps1 -Type Integration -CI` 全绿跑录留档（B9 修后 baseline total=11 起算，件数只增不减）；④ 迁移后 T0 同面门禁复跑 **EXIT=0**（噪声计数因面孔迁移变化，由 A7-02 归因覆盖——故执行序上本子项必须先于 A7-02 重发）；⑤ 四门 EXIT=0。
- **边界**：只迁行；若同 runner 任一 fixture 在环境前提齐备下不能稳定绿 ⇒ 停机上报（先解决该 fixture 再迁移，fail-closed，纪律 6）；「CommerceE2E 并入主套件 dpr」路线 B9 已论证不取（会把环境依赖类与单元级混入同一判定面），本单沿用面收口。

## 三、输出物与验收

- 回执：`CodeReview/20260926-AUDIT-甲-A7-交付回执.md`（提交哈希、判据跑录原件、归因表、重发前后对照）。
- 证据：`CodeReview/20260926-AUDIT-甲-A7-证据/`。
- 验收：主控亲跑（CI 步骤存在性 + 主树负样本 41 例 + 隔离树 T0 门禁 EXIT=0）+ 亲读 diff + 四门复跑；**甲自报不作为验收依据**。

## 四、修订记录

- **2026-09-28 主控修订**：增补 A7-03（`DeepBaseIntegrationTests.dpr` T1→T0 面收口），源自乙 B9 回执 §四.2 注册/收口建议——B9 明确「此项属契约面/CI 轨，归主控或甲 A6/A7 线，乙不动 `contracts/**`」，主控裁定并入本单。同时补执行序条款（A7-03 先于 A7-02 重发）与「契约清单以当前 HEAD 实测为准」定位纪律。原 A7-01/A7-02 内容不变。

*主控 · 2026-09-26 · 签发即生效（2026-09-28 增补 A7-03）；本单是 B8/A6 验收结论 + B9 收口建议共同裁定的 CI/契约收口面，零生产代码*
