# WO-20260926-AUDIT-甲-A7 CI 门禁收口（负向样本纳入 + 噪声基线归因重发 · 2 项）

> 签发：主控 · 2026-09-26
> 基线锚点：HEAD `d80671e`（= 主控 dproj 搜索面修复 + 乙 B8 / 甲 A6 验收结论落笔）
> 派工对象：**开发 AI 甲**
> 来源：乙 B8 回执 §三与甲 A6 回执 §三.2 独立指出的同一 CI 缺口 + 本日 T0 复跑的噪声门挂账（乙 B8 / 甲 A6 两份验收结论共同裁定派出）。
> 与甲 A5（全 Core 域）文件零重叠；仅动 `.github/workflows/delphi-ci.yml` 与 `09_工程脚本/build-gate/**`。

## 〇、开工纪律（违者整单打回）

1. **H15 原子提交**：两子项（A7-01/A7-02）各自独立提交，message 带编号；显式 pathspec，前后 `git diff --cached --name-only` == 申报清单；**禁 push**。
2. **单线串行**：A5（甲线第一优先，乙 B7 最后前置）未交付前，本单不得抢跑；若老板直派则按直派执行并登记口径（同 A6 先例）。
3. **禁动区维持**：`v1.1.0` 标签 / EHAI 冻结面 / `TestResults/**` / 旧轨 `Core/DeepBase.PluginManager.pas` / 新轨 `DeepBase.Plugins.*` / `Tests/DeepBaseTests.dpr|.dproj` / `09_工程脚本/eol-gate/eol_baseline.json`（禁 `--emit-baseline` 改写）。**本单零生产代码、零 `.pas`/`.dpr` 改动**；不得为压噪声删 Hint 源或改编译门判定语义。
4. **符号/路径定位**：CI 文件与门禁代码以当前 HEAD 实测为准，不照抄本单描述；找不到 ⇒ 报「已不成立」附 `git log -1`。
5. **编译判据**：隔离 `--detach` 工作树 @ 目标 commit；T0 全量约 20 分钟量级，按需跑；主树红项逐件点名归属。
6. **fail-closed**：emit 基线只许「同面、带归因、经 `gate-emit-guard` 校验」三条件齐备才做；归因表对不上 ⇒ 停机上报，不许硬发。

## 一、修单一览

| 编号 | 事项 | 来源 | 性质 |
|---|---|---|---|
| A7-01 | `.github/workflows/delphi-ci.yml` 纳入 `build-gate/test_negative_sample.js` | 乙 B8 §三 + 甲 A6 §三.2 | 执行 |
| A7-02 | T0 噪声基线逐码归因 + 同面重发（H2077/H2443/H2269 超基线治理） | B8/A6 两份验收结论 §四 挂账 | 执行 |

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

## 三、输出物与验收

- 回执：`CodeReview/20260926-AUDIT-甲-A7-交付回执.md`（提交哈希、判据跑录原件、归因表、重发前后对照）。
- 证据：`CodeReview/20260926-AUDIT-甲-A7-证据/`。
- 验收：主控亲跑（CI 步骤存在性 + 主树负样本 41 例 + 隔离树 T0 门禁 EXIT=0）+ 亲读 diff + 四门复跑；**甲自报不作为验收依据**。

*主控 · 2026-09-26 · 签发即生效；本单是 B8/A6 验收结论共同裁定的 CI 收口面，零生产代码*
