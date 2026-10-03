# WO-20261003-MC-甲-ORPHANREG 22 个回归测试单未进主测试工程（主控派单 · P1）

**单号**：`WO-20261003-MC-甲-ORPHANREG`
**派单**：主控（2026-10-03，回答「bug 修复是否全部完成」取证时发现）
**优先级**：**P1** —— 直接决定「全量套件绿了」这句话的效力
**触发**：主控清点 `Tests/Regression/` 时发现 53 个 `Test.Regression.*.pas` 中只有 31 个进了 `Tests/DeepBaseTests.dpr`

---

## 〇、纪律与口径

1. **零信任**：主控给的所有读数都只是线索，本单必须**独立复算**后才可作为结论引用。
2. 一笔 H15 原子提交，message 带单号，显式 pathspec，选项在 `--` 前，**禁 push**。
3. 台账状态槽改写权归主控，本单只写回执。
4. **先清点、先证明可编译，后并入**。禁止「为让读数变好看」而批量挂载。
5. 主树陈旧编译产物 46679 `.dcu` ⇒ 主树跑 T0 必红（`WO-20261002-MC-主控-DCU`）。**本单所有跑录必须在隔离树或独立探针工程里做**，不得用主树读数下结论。
6. 写任何「某处会拦住/某规则 fail-closed」类断言前，先把同族实现数清、把用户可见行为读到代码那一行。

---

## 一、主控已核实的事实（待本单复算）

| # | 事实 | 主控取证方式 |
|---|---|---|
| F1 | `Tests/Regression/` 下 `Test.Regression.*.pas` 共 **53** 个 | `ls Tests/Regression/Test.Regression.*.pas \| wc -l` |
| F2 | `Tests/DeepBaseTests.dpr` 注册 `Test.Regression.*` 共 **31** 个 | `rg -o "Test\.Regression\.[A-Za-z0-9_]+" Tests/DeepBaseTests.dpr \| sort -u \| wc -l` |
| F3 | 差集 **22** 个未进主测试工程 | `comm -23` |
| F4 | dpr **无 `{$I ...}` include**，`uses` 段是唯一注册机制 | `rg -n '\{\$[Ii]\b' Tests/DeepBaseTests.dpr` 空 |
| F5 | 22 个中 **18 个在全仓任何 `.dpr`/`.dproj`/`.dpk`/`.template` 里零引用** | `git grep -ln <unit> -- '*.dpr' '*.dproj' '*.dpk' '*.template'` 逐个为空 |
| F6 | `Tests/Regression/RegressionTestRegistry.pas:75` 登记了 `TestUnit: 'Test.Regression.BUG007_WhenReadyDeadlock';`，但该 registry 单元在主 dpr **零引用** ⇒ 死注册表 | `git grep -ln RegressionTestRegistry -- '*.dpr'` 空 |
| F7 | `A5R03Wide` 探针的 4 例红**全部**在 `Test.Regression.BUG007_WhenReadyDeadlock` | `CodeReview/20261002-请求审核报告-开发甲-MC-TESTDEBT-MOE-GOVCONTRACT-MC3.md:132` |

### 18 个全仓零工程引用的单（F5 名单，逐字）

```
Test.Regression.BUG001_AnimationMemoryLeak
Test.Regression.BUG009_LoggingRace
Test.Regression.BUG010_WorkerQueueRace
Test.Regression.BUG013_RSASignature
Test.Regression.BUG014_WeChatPaySignature
Test.Regression.BUG020_KeyNameValidation
Test.Regression.BUG033_WeakEncryption
Test.Regression.BUG034_HardcodedKeys
Test.Regression.BUG035_InsecureRandom
Test.Regression.BUG037_KeyDerivation
Test.Regression.BUG054_SemaphoreLeak
Test.Regression.BUG058_XOREncryption
Test.Regression.BUG062_PluginSandbox
Test.Regression.BUG063_PluginConfigBypass
Test.Regression.BUG066_PathTraversal
Test.Regression.BUG070_LogInjection
Test.Regression.BUG073_EventTypeInjection
Test.Regression.CR606_FrameDifferAlpha
```

> 其中 10 个是**安全回归**（WeakEncryption / HardcodedKeys / InsecureRandom / XOREncryption / PluginSandbox / PluginConfigBypass / PathTraversal / LogInjection / EventTypeInjection / KeyDerivation），2 个是**签名回归**（RSASignature / WeChatPaySignature）。

### 另外 4 个（有工程引用但未进主套件）

| 单 | 唯一引用处 |
|---|---|
| `Test.Regression.BUG007_WhenReadyDeadlock` | `CodeReview/20260925-AUDIT-甲-A5-证据/附件/A5R03Baseline.dpr.template`、同目录 `A5R03Wide.dpr.template:22` |
| `Test.Regression.BUG059_JsonDeserializationType` | `附件/A5R04Broad.dpr.template` |
| `Test.Regression.BUG060_SerializationDepth` | `附件/A5R04Broad.dpr.template` |
| `Test.Regression.A8_InFlightUnloadGate` | `Tests/TestGateVerdictAndA8.dpr` |

---

## 二、为什么这是 P1

1. **「全量套件绿」的效力被高估**。`WO-20261002-MC-MC1` 项 1 全量读数 `Found 4871 / Passed 4866 / Failed 0 / Errored 1`（唯一红 P2-b）被多次引用为「套件健康」的凭据。但该读数**从未覆盖这 22 个单** ⇒ 它是一个**子集**的真话，不是套件的真话。
2. **它与 `A5R03Wide` 的 `133 found / 129 passed / 4 failed` 不矛盾，且已被 F5+F7 解释**：主套件根本不编译 BUG007，所以跑不到那 4 例。此前台账把这两组读数当成「口径未调和」挂起，本单要把它写成可复算的算式（判据 2）。
3. **安全回归整批不在跑**。19 个单覆盖弱加密 / 硬编码密钥 / 不安全随机 / XOR / 插件沙箱 / 插件配置绕过 / 路径遍历 / 日志注入 / 事件类型注入 / 密钥派生。这些是**回归防线**，不是锦上添花。

---

## 三、判据（主控验收用）

| # | 判据 | 达成标准 |
|---|---|---|
| 1 | 复算 F1–F6 | 用与主控不同的命令路径各得同一数字；若得不出，报出差异行 |
| 2 | 读数调和写成算式 | 用一行可复算表达式说明 `A5R03Wide` 133/129/4 与全量 4871/4866/0F/1E 为何可同时成立，并指名 4 例所在单 |
| 3 | **可编译性前置证明** | 22 个单逐个在隔离工程里编译，给出 `BUILD_EXIT` 表。任一非 0 ⇒ **先修再谈并入**，不得带病挂载 |
| 4 | 逐个运行读数 | 22 个单逐个跑 `DUnitX`，给出每单 Found/Passed/Failed/Errored/RUN_EXIT 表 |
| 5 | 三态分级 | ①可现修 ②需前置（写明前置单号）③维持现状（写明为何不动）——22 条全覆盖，**零「待定」** |
| 6 | 溯源 | 每单给出首次入库提交哈希 + `git log --oneline -- <path>` 末次改动；对 18 个零引用单，给出「从未进过 / 曾进过被剥离」的判定及证据 |
| 7 | 并入批次表 | 不得一次性把 22 个全挂进 `Tests/DeepBaseTests.dpr`。给分批表，每批附「并入前/并入后 Found·Passed·Failed 对比」，**并说明每批引入几道新红** |
| 8 | 阴性对照 | 写错一个单元名 / 少一行 `in 'Regression\...'` / 路径分隔符写错，各造一例证明门禁或编译会红 |
| 9 | 四门 + 交付纪律 | eol / encoding / mojibake / evidence-encoding 全 EXIT=0；一笔 H15；禁 push |

**验收前置**：判据 1 → 3 → 4 必须按序；判据 3 未过不算完。判据 7 若最终决定「全部并入」，必须单独一笔提交 + 主控另行验收，不得塞进本单其他改动里。

---

## 四、授权面与禁动区

**授权**：
- `CodeReview/**`（取证留档）
- `Tests/Regression/**`（只读取证 + 必要的夹具修）
- **显式授权** `Tests/DeepBaseTests.dpr` 与 `Tests/DeepBaseTests.dproj`，且**仅限增补** `in 'Regression\...'` 形式的单元行；**禁止删除、改名、重排任何既有注册行**
- `Tests/Regression/*.dpr.template`（若需新建探针，仅限本目录）

**禁动**：`Core/**`、`contracts/**`、`Features/**`、`09_工程脚本/**`、`Scripts/**`、`noise-baseline.json`、`Governance/**`、`VCL/**`、`FMX/**`。

**明令禁止**：
- 为让判据 4 的读数变绿而改断言、加 `SKIP`、删用例
- 把 22 个单里的失败归因为「环境问题」而不给读数
- 声称「全量套件已覆盖全部 53 个回归单」——除非判据 7 真的做完了

---

## 五、不在本单

1. `WO-20261002-MC-甲-F2`（Timeout PBT 空指针，全量套件 `Errored` 那条）；HB Gate #6 句柄泄漏断言（`Failed` 那条）归 `WO-20261003-MC-甲-HBGATE6`——两条都是红，不存在「唯一存量红」。
2. `WO-20261002-MC-甲-A5R03`（A5R03Wide 4 红清点）—— 本单只解释**为何那 4 例不在全量读数里**，不重跑、不改写 A5R03 结论。
3. `WO-20261002-MC-主控-DCU`（主树陈旧 `.dcu` 清理）。
4. `Template.AutoUpdateBootstrap.pas` 不可编译 —— 归 `WO-20261003-MC-甲-TPLBOOT`。
5. `WO-20261003-MC-甲-UPDENDPOINT`（独立下载域门禁收口）。
