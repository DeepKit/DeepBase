# WO-20261001-MC-甲-A15 SkeletonRules 并网与「假覆盖谱系」终局清点（P2 · 2 项）

> 签发：主控 · 2026-10-01
> 派生来源：A10 验收结论 §五（停机上报①裁定）与 §七 派单第 1 项（该件原记 `WO-20261001-MC-甲-A15`，本工单即该派生单）
> 派工对象：**开发 AI 甲**（§三 终局枚举面）；**主控**（§二 并网面，主控落笔，不派甲）
> 基线锚点：开工时 HEAD（当前 `d35ec6a`；甲开工前以主控派工消息重锚——并网落笔后枚举才从终态起算）

## 〇、开工纪律

1. **H15 原子提交**：枚举面 1 笔（回执 + 证据），message 带 `A15`；显式 pathspec；前后 `git diff --cached --name-only` == 申报清单；**禁 push**；台账状态槽不碰（归主控）。
2. **禁动区维持**：`v1.1.0` 标签 / EHAI 冻结面 / `TestResults/**` / 新旧 PluginManager 轨 / `contracts/**` / `noise-baseline.json` / `Tests/DeepBaseTests.dpr` 与 `.dproj`（**主控并网除外，甲连读都不必**）/ `Tests/Integration/**` / `Core/**` / `Features/DeepBase.Licensing.pas` / `Scripts/**`。本单**零生产代码、零 `.pas` 改动**——枚举是只读面，产出仅回执与证据件。
3. **范围收敛**：只读全仓 `*.pas`（rg/grep 枚举）、只读三个 dpr（uses 面核对）。禁改任何源码；禁跑全量单测（必崩 RT216，见 memory 与 A9 回执）。
4. **fail-closed 三档**：①枚举工具须**自证有效**——正对照（工具必须命中 A10-02 修前形态的已知件、A8 的 `Test.DeepBase.LicenseSecret`）与负对照（对已知「已注册」件必须判「已注册」，误报即工具无效、本单打回）；②枚举不到尽头（有件判不了「在册/孤儿/可编译」三态之一）⇒ **停机上报**，禁止写「假覆盖已清零」；③与主控 §一 基线不一致 ⇒ 逐件列差异，禁静默改结论。
5. **基线差异即停机**：任何与 §一 主控基线不符的读数，附命令原文与 `文件:行` 上报，禁自行扩大或缩小枚举面。
6. **串行**：A15 与甲线其他单文件零重叠，可并行；但枚举必须锚在主控并网落笔之后的 HEAD（§二.4 的重锚消息为准）。

## 一、主控基线（2026-10-01 亲跑亲读 @ `d35ec6a`，甲须逐条复核「一致 / 不一致+原文」）

### 1.1 谱系定义与已闭环账

「假覆盖」= 单元含 `[TestFixture]` 类但**运行时无 `TDUnitX.RegisterTestFixture` 注册** ⇒ runner 报 `ENoTestsRegistered` / `RUN_EXIT=2`，dpr uses 在册而用例永不执行。

| 轮次 | 范围 | 处置 | 状态 |
|---|---|---|---|
| A8 | `Test.DeepBase.LicenseSecret`（+2 例） | 补 initialization | ✅ ACCEPTED |
| A9-01 | 主 dpr 在册不跑 9 件（唤醒 46 例，工单原记 10 件，`Test.DeepBase.DiagnosticLogger` 经主控核定系误列——它是 logger 非 fixture） | 逐件补注册，9 笔 H15 | ✅ ACCEPTED |
| A9-02 | 集成面 `TIntegrationTestBase`（`[Test]`=0 ⇒ 计数中性） | 摘误导性 `[TestFixture]` | 已被 A10-03 落地 |
| A10-02 | `DeepFlow/Tests/Test.DeepFlow.Engine.pas`（4 例） | 补注册 +3 行，主控亲跑 4/4 `RUN_EXIT=0` | ✅ ACCEPTED |
| A10-01 | `Tests/Test.DeepBase.Governance.Validation.SkeletonRules.pas` 红因修正（INV-5 孤儿门） | 择案 a 补 `AddActionKey`；主控隔离树重建 M0/M1/M3 三副本复现读数逐字符一致 | ✅ ACCEPTED |
| **A15（本单）** | SkeletonRules 并网（§二）+ **全仓终局枚举**（§三） | — | 🔵 本单 |

### 1.2 SkeletonRules 当前态（主控亲跑）

- 交付态单元在册无注册 ⇒ 主树 fixture 探针复现 `ENoTestsRegistered: No Test Fixtures found` / `RUN_EXIT=2`（A10 结论 §三亲跑留档）；
- 甲 M1 副本（修后 + 注册注入）= found=3 pass=3 fail=0 error=0 `RUN_EXIT=0` ⇒ 红因已消，并网后新增 3 例、失败集合不变；
- 该单元**不在任何 dpr**（`git log -S SkeletonRules -- <三个 dpr>` 空 ⇒ 从未登记，非有意排除）；单元尾部无 `initialization` 段。

### 1.3 「同形先例」三条（并网形态依据）

`Tests/Test.DeepBase.License.pas` 尾部即此惯例；A10-02 为 `TDeepFlowEngineTests` 落 +3 行同形；A9-01 一次性为 9 件补同一形态。SkeletonRules 是该谱系**最后一处已定性件**——但是否「最后一处」本身正是 §三 终局枚举要证伪/坐实的对象，**枚举结果出来前任何人不得声称「谱系已清零」**。

## 二、并网面（主控办，甲不必动手）

主控在并网笔内落两处：

```pascal
// Tests/Test.DeepBase.Governance.Validation.SkeletonRules.pas 尾部（end. 前）
initialization
  TDUnitX.RegisterTestFixture(TSkeletonRuleTests);
```

并在 `Tests/DeepBaseTests.dpr` 增 `uses` 行（插位与 A7/A11 并网同款，置于 dpr uses 区内）。

### 2.1 并网判据（主控自跑，全部留档）

1. 修前复现：交付态探针 `ENoTestsRegistered` / `RUN_EXIT=2` 原文；
2. 修后：全限定 `Test.DeepBase.Governance.Validation.SkeletonRules.TSkeletonRuleTests` ⇒ found=3 pass=3 fail=0 error=0 `RUN_EXIT=0`；
3. 主套件同进程 `--run` 该 fixture：3/3、`Leaked=0`；
4. **纪律 6（Hint 守恒）**：并网前后 `Tests/DeepBaseTests.dpr` 单件编译 `HINT`/`WARN` **按码分布逐字相同**（基线 = A10 验收读数 `HINT=238 WARN=17`）；任何增量 ⇒ 逐条归因后才可落笔；
5. T0 门禁隔离树复跑 27 件 `BUILD_EXIT=0`、`Hint=793 Warning=155` 按码串与基线逐字符同一；
6. 四门 EXIT=0；7. H15 1 笔（显式 pathspec = 单元 + dpr + 证据件），禁 push。

### 2.2 落点回填

并网笔 commit 与上述判据跑录，由主控在落笔后回填本节（甲开工重锚以回填后的 commit 为准）。

## 三、终局枚举面（甲办）

### 3.1 枚举口径（fail-closed）

1. **对象**：全仓 `*.pas` 中声明 `[TestFixture]` 的全部类（按 `类名` 计，不按单元文件名）；
2. **判定**：逐类回答——该单元内（`initialization` 段）或其他任何单元/程序入口是否存在对应该 fixture 的 `TDUnitX.RegisterTestFixture` 调用；
3. **三态定性**（每件必归其一，禁留空）：
   - **A 已注册**：有注册调用 ⇒ 记注册点 `文件:行`；
   - **B 在册不跑**：无注册且单元出现在任一 dpr 的 uses 面（**两种 uses 形态都要匹配**：`Unit.Name in '...'` 与裸名逗号形态）⇒ 记在哪个 dpr；
   - **C 孤儿**：无注册且不在任何 dpr ⇒ 记「不在任何 dpr」+ git 溯源（`git log --diff-filter=A -- <file>` 首笔，判「从未登记」还是「被摘出」）；
4. **可编译性附带列**：B/C 态每件标注能否编译（A9 §九.2 已定性 `Tests/Test.DeepBase.Browser.*` 5 件为**不可编译**——`var Implementation :` 撞保留字 E2029 等，双 dpr uses 零命中——那 5 件**不是**假覆盖，禁重复计入；其余 B/C 件按 A13/A14/A10 交付态实际可编译状态标注）；
5. **计数纪律**：A9 实修 9 件 + A10-02 1 件 + 本单并网 1 件 = 已闭环 11 件；终局枚举若不再有 B/C 态可编译件 ⇒ 「假覆盖谱系清零」方能成立；**只要有一件判不出三态，就不许下该结论**。

### 3.2 工具自证（必交）

枚举脚本/ rg 命令族须附：正对照（命中 §1.1 表中至少 2 个已知 B→A 转化件的修前形态、以及 `Tests/Test.DeepBase.Browser.*` 的三态判定）+ 负对照（对 A9-01 修后 9 件必须判 A 态，误报即无效）。脚本本体不入库（一次性工具，入库会成第二套口径），命令原文入证据件。

### 3.3 输出物

回执 `CodeReview/20261001-AUDIT-甲-A15-交付回执.md` + 证据 `CodeReview/20261001-AUDIT-甲-A15-证据/`（全量枚举表〔类名/单元/注册点或三态/dpr 在册面/可编译性/计数〕、与 §一 基线逐条复核表、工具自证原文、rg 与 git 溯源原文）。生产码、Tests/**、三个 dpr、Scripts/**、contracts/** 零改动（`git status --porcelain` 附原文）。

## 四、判据

1. **枚举完整**：全仓 `[TestFixture]` 类一张表，B/C 态零留空、三态各归其一；
2. **基线一致**：§一 1.2/1.3 逐条复核「一致」；不一致 ⇒ 停机，本单判据不成立；
3. **工具自证**：正/负对照均通过，原文在案；
4. **终局结论有条件**：只有「B/C 态可编译件 = 0（SkeletonRules 并网后）」才可写「假覆盖谱系清零」，且须列清零前的最后一件是什么、在哪轮闭环的；
5. **纪律**：H15 1 笔、显式 pathspec、禁 push、零 `.pas`/dpr/生产码改动、台账状态槽不碰；
6. **门禁**：只动 `.md`/`.txt` ⇒ eol 门与 evidence-encoding 门必跑且 EXIT=0，encoding/mojibake 复跑留档，四门原文入证据。

## 五、不在本单（已登记）

- §二 并网面全部动作（单元 +3 行、dpr uses 登记、并网判据）——主控自办，甲不碰；
- 任何新测试用例的编写或既有断言的修改（枚举只读）；
- A16（A5-R02 强路线落地）与 A14（TimeGuard 解析器改 RTL）的面。

*主控 · 2026-10-01 签发 · 并网落笔后重锚派工*
