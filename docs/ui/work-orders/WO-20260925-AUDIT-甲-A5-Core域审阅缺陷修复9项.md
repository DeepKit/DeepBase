# WO-20260925-AUDIT-甲-A5 Core 域审阅缺陷修复（9 项）

> 签发：主控 · 2026-09-25 · **2026-09-28 正式派出（重锚 HEAD `2dcd1ae`）**
> 基线锚点：HEAD `2dcd1ae`（原锚 `b603cc9` = A4 验收结论提交；其后经甲 A6、乙 B8、主控 dproj 修复笔 `d80671e` 与台账回填叠加；`git diff b603cc9 2dcd1ae -- Core/ Features/` = **空** ⇒ 本单 9 项目标文件零漂移）
> 派工对象：**开发 AI 甲**（9 项全部落 Core 域及 Core 侧测试，与乙 B3 零文件重叠）
> 派发时主控核查（2026-09-28）：九项目标符号逐项 `rg` 抽核全部在册；**文本更正两处**（R04 缺陷文件路径、R03 符号形态）见 §〇-10，按更正执行。
> 串行纪律：甲线 **A5 第一优先**；A7（CI 门禁收口）排本单验收通过之后，A5 交付验收前不得并开 A7。
> 缺陷来源：**甲 A4 只读补验单的 8 项判定**（已由主控亲读代码路径复算坐实，结论 `CodeReview/20260925-AUDIT-主控-甲-A4-验收结论.md`）+ 主控三项裁定。本单不是新审阅，是**已验证缺陷的修复执行面**。

## 〇、开工纪律（对全单生效，违者整单打回）

1. **H15 原子提交**：每条缺陷独立提交，message 带本单编号（A5-R01…R09）；commit 必带 `--only`/显式 pathspec，前后各跑 `git diff --cached --name-only` == 申报清单；**禁 push**。
2. **同文件两条缺陷必须可分离提交**：A5-R01/R02 同在 `Core/DeepBase.DataBinding.pas`（前者改 `Unbind` 退订语义、后者改 `Bind` 与析构登记），两个 commit 必须能各自编译通过，不许裹挟成一个「DataBinding 大修」提交。
3. **禁动区维持**：`v1.1.0` 标签 / EHAI 冻结面 / `TestResults/**` / 旧轨 `Core/DeepBase.PluginManager.pas` / 新轨 `DeepBase.Plugins.*`。
4. **行号漂移警示**：A2 动过 Core 多个文件，本单只给**符号与定位方法**，不承诺行号；找不到符号 ⇒ 报「已不成立（代码已变）」并附 `git log -1 -- <file>`，**禁止照抄行号改错位置**。
5. **测试**：每条缺陷配 DUnitX 回归（**自建新 test 单元文件**，不要改 `Tests/DeepBaseTests.dpr`/.dproj 注册——归主控收口）；全量 run 崩 216 是既存问题，**禁止用全量当判据**，用全限定 `<单元>.<Fixture>` fixture 子集。A4 探针（`CodeReview/20260925-AUDIT-甲-A4-证据/附件/*.dpr.template` + §三复现步骤）可改制为单测判据来源。
6. **编译判据**：隔离 `--detach` 工作树 @ 目标 commit EXIT=0；主树红项逐件点名归属（基线红项名单见 A2 验收结论 §一，本单不得新增红）。
7. **回归前置**：A5-R04（Serialization）动的是高频公共路径，**修复前必须先跑既有 Serialization 相关 fixture 子集并留档基线**——甲 A4 回执明确警示「既有用例可能依赖错类型静默默认」；先有基线再动手，不许修完才发现回归说不清。
8. **fail-closed 总原则**：异常/失败路径一律显式报错（具体异常类），禁止吞异常、禁止无条件 `Result := True`、禁止兜底默认值掩盖错类型。老板口径「质量优先于兼容，允许 breaking change」。
9. **编码/行尾**：`.pas` 四门（encoding/eol/mojibake）交付树复跑全 EXIT=0；中文字面量 UTF-8 BOM；探针不入扫描面（`.dpr.template` 别名）。
10. **派发时文本更正（2026-09-28 主控实测，本单其余内容维持 09-25 原文）**：① R04 缺陷文件是 `Core/DeepBase.Serialization.pas`——`Core/DeepBase.Services.Serialization.pas` 是 80 行门面单元（`rg "IsAllowedType"` 对其命中 0），`TSerializationContext.IsAllowedType` 实测在 `Core\DeepBase.Serialization.pas:630`、白名单 `ALLOWED_TYPES` 在 `:633`、`SameText(...) or ClassName.StartsWith(...)` 绕过臂在 `:647-648`（缺陷仍在）；② R03 符号形态是 `function InitializeEx(out ErrorMsg: string): Boolean`（`:177`/`:655`，非 `procedure`）。本单相关处已同步更正。
11. **范围修订（2026-09-28 主控裁定，源自乙 B7 停等期发现，结论 `CodeReview/20260928-AUDIT-主控-乙-B7-准备期裁定.md`）**：R09 的 Core 单一时钟源必须同时消除**两处**裸 `Now` 过期判定——`Core/DeepBase.License.pas:192`（原列）与 `Core/DeepBase.KeyManager.pas:320`（`TKeyInfo.IsExpired`，主控实测同形）。只修前者 ⇒ Core 内仍留第二轨时钟，违背 R09 单一时钟源目标；且甲时间源符号须为**可注入形态**（修法-1 已含，现因乙 B7 判据①端到端依赖，回执必须点名符号名 + 签名 + 注入用法）。

## 一、修单一览

| 编号 | 缺陷 | 文件域 | 严重度 | 主控裁定/收敛 |
|---|---|---|---|---|
| A5-R01 | Unbind 退订共享 handler ⇒ 同源兄弟绑定静默失效 | `Core/DeepBase.DataBinding.pas` | 高 | 甲 A4 已复现（唯一失败断言） |
| A5-R02 | BindingEntry 持裸指针，无析构登记 ⇒ 未解绑即释放 = 真 UAF | 同上 | 高 | **主控裁定：取强路线 (a)** 析构登记自动解绑（见 §二.2） |
| A5-R03 | 初始化失败时 `FIsInitialized` 未置位 ⇒ Finalize 早退 ⇒ 模块批量泄漏 | `Core/DeepBase.Manager.pas` | 中高 | 按 `FModulesCreated` 标志清理；**不采纳**把 7 处 Create*Storage 改 fail-fast（那是另一种产品语义，超范围） |
| A5-R04 | 反序列化无值类型校验（AV/堆字节进消息/静默默认）+ 白名单 StartsWith 前缀绕过 | `Core/DeepBase.Serialization.pas` | 高 | 精确匹配 `SameText`；标量赋值前类型校验 |
| A5-R05 | IoC 单例双路径各判单例 ⇒ 双实例+泄漏；RegisterSingleton 后对象路径 AV | `Core/DeepBase.IoC.pas` | 高 | 抽 `EnsureSingletonInstance` 单一真相源；interface-only 注册后对象路径解析改抛 `EIoCException`（见 §二.5 三条硬约束） |
| A5-R06 | `TopExceptions` 换入换出不可逆 ⇒ owned 源被提前释放/borrowed 源引用永久丢失 | `Core/DeepBase.LogQuery.pas` | 高 | **首选**过滤列表参数下传 `TopErrors`，取消状态往返 |
| A5-R07 | 字体伴生 CIDFont 用 `ObjNum+1` 从未预留 ⇒ 对象号撞号/孤儿体/DescendantFonts 错指 | `Core/DeepBase.Export.PDF.pas` | 高 | 登记时一次分配两个对象号 + 删死预分配循环；**不采纳**重写字体嵌入的大修提案（超范围） |
| A5-R08 | DOCX 属性值未过 `EscapeXML` ⇒ XML 解析失败 / 注入 `<w:ins>` | `Core/DeepBase.Export.DOCX.pas` | 高 | 属性三处 + color + shd fill 统一转义 |
| A5-R09 | License 过期判定裸 `Now`，无回拨防护 ⇒ 时钟回拨续命 | `Core/DeepBase.License.pas`（**甲段**） | 高（合规面） | **跨层拆两段**：甲段 Core 时间源注入 + LastSeen 单调水位；乙段接 `GetCorrectedNow` 归乙 B3（甲先乙后，本单只做甲段） |

## 二、逐项修单

行号不给，只给符号与 `rg` 定位法；A4 回执 §二/§三有完整复现素材，直接改制。

### A5-R01 [待修] Unbind 误杀同源兄弟绑定
- **代码事实**（甲 A4 探针 S2 复现，主控已复算）：`TBindingManager.Unbind`（`rg -n "function Unbind|procedure Unbind" Core\DeepBase.DataBinding.pas`）逐对 `FBindings.Delete(i)` 并调 `RemovePropertyChangedHandler`，**无「该 Source 是否仍有剩余绑定」判断** ⇒ 同源两条绑定解绑其一，退订的是共享 handler，存活绑定静默失效（`BindingCount` 仍在但通知不传播）。
- **修法**：删除条目前统计该 `Source` 的剩余绑定数，**仅当无剩余时才退订** handler（语义从「按对退订」改为「按源引用计数退订」）。改动限 `Unbind` 一个函数。
- **判据**（单测，新单元或并入既有 `Tests\Test.DeepBase.DataBinding.pas` 的新 fixture）：同源 `(S,T1)`、`(S,T2)` 两条绑定 ⇒ `Unbind(S,T1)` ⇒ 断言 `BindingCount=1` **且** 源属性变更后 T2 收到通知（A4 S2 的 `phase-B` 断言转正）。
- **破坏面**：`Core\DeepBase.MVVM.pas`、`VCL\DeepBase.VCL.BindableControls.pas`、`VCL\DeepBase.VCL.MVVMControls.pas`、`Examples\DataBindingDemo`、`Examples\MVVMDemo`；既有 `Tests\Test.DeepBase.{DataBinding,MVVM}.pas` 不得回归。

### A5-R02 [待修] BindingEntry 裸指针 UAF（强路线 a）
- **代码事实**：`FBindings: TList<TBindingEntry>`，entry 持裸 Source/Target 指针，无 FreeNotification/弱引用登记 ⇒ 未 Unbind 即释放对象时，源通知向已释放内存写值 / `UpdateAllTargets` 读到 decoy 值（甲 A4 S3/S4 decoy 实证）。
- **主控裁定：取强路线 (a)**——Bind 时对 Source/Target 建立析构登记（FreeNotification 风格，或仓内既有等价的弱通知机制，先 `rg -n "FreeNotification|FreeNotify" Core\*.pas` 翻现有能力再决定具体形态），对象销毁自动 Unbind。**不采纳**「保留裸指针契约 + `FreeBindingOf` + 文档化」弱路线：与乙 B2-14（`GCommandBindings` 野指针）已确立的 Ownership/FreeNotification 范式同源，弱路线把 UAF 留给调用方自觉，违背 fail-closed。
- **修法要点**：① Bind 入口对 Source/Target 各登记一次析构回调（同一对象被多条绑定共享时只登记一份，登记表按对象引用计数管理）；② 析构回调里摘除该对象全部绑定条目并同步清理 R01 的引用计数；③ `TBindingManager` 析构时注销全部登记，不许泄漏通知槽。
- **判据**：复刻 A4-01 S3/S4 为单测——释放 target/source 后以 decoy 对象复用同地址，再触发源通知/`UpdateAllTargets`，断言无 AV、无 sentinel 写入、无 decoy 读取；另加「同对象多绑定只登记一份 + manager 析构后无残留登记」断言。
- **破坏面**：同 R01 全部调用方；本项改公共 API 语义，提交说明必须写清「绑定不再要求调用方保证对象存活顺序」。

### A5-R03 [待修] 初始化失败路径模块泄漏
- **代码事实**：`InitializeEx`（`rg -n "function InitializeEx" Core\DeepBase.Manager.pas`，实测 `:177`/`:655`）中 `FIsInitialized := True` 位于 `InitializeModules` **之后**；两者之间还有无保护消费点（配置读取等）。该窗口抛异常 ⇒ `FIsInitialized` 保持 False ⇒ `Finalize` 首行 `if not FIsInitialized then Exit`（`rg -n "not FIsInitialized" Core\DeepBase.Manager.pas`）⇒ `FinalizeModules`（唯一释放点）被跳过 ⇒ FLogger/FConfig/FI18n/FTheme/FSecurity 整批泄漏，且全局 logger 悬挂。（甲 A4 S2 实证：释放后 `loggerInstalled=1 samePtr=1`。`InitializeWithDB` 的 except 分支同型，须一并核对。）
- **修法**：引入 `FModulesCreated` 标志（`InitializeModules` 内成功创建的模块置位，逐模块就逐模块置位，失败也保留已创建部分的位图）；`Finalize`/两条 except 分支按该标志（而非 `FIsInitialized`）决定是否执行 `FinalizeModules`。**不采纳**把 7 处 `Create*Storage` 改 fail-fast——产品语义变更，超范围。
- **判据**：复刻 A4-02 S2 为单测——注入配置读取异常 ⇒ 走完失败路径 ⇒ 析构后断言各模块实例已释放、全局 logger 已摘除；另加「初始化成功后 Finalize 正常释放」对照（防修出双释放）。
- **破坏面**：全仓初始化链路（VCL/FMX/Examples/Tools Studio/DeepBaseRun）；既有 `Tests\Test.DeepBase.Manager.pas`、`Tests\Regression\Test.Regression.BUG007_WhenReadyDeadlock.pas`、`Tests\Stress\*` 不得回归。

### A5-R04 [待修] Serialization 值类型校验 + 白名单精确匹配
- **代码事实**（甲 A4 14 类错型输入实测，主控复算）：错类型 → AV（`Age=bool`）；异常消息含原始堆字节（`Age=object/array`）；静默默认值 4 例（`Age=null→0`、`Name=int→123` 等）。附加：`TSerializationContext.IsAllowedType`（`rg -n "IsAllowedType" Core\DeepBase.Serialization.pas`，实测 `:630`，白名单 `ALLOWED_TYPES` 在 `:633`）判定链为 `SameText(ClassName, ALLOWED_TYPES[I]) or ClassName.StartsWith(ALLOWED_TYPES[I])`（`:647-648`）⇒ `StartsWith` 臂令 `TObject*` 命名全过白名单。
- **修法**：① 标量赋值前按目标属性类型校验 JSON 值类型（number/string/bool/null 四分），不符抛**带属性路径 + 期望/实际类型**的类型化异常（`Core/DeepBase.Exceptions.pas` 具体异常类优先）；② 白名单前缀匹配改 `SameText` 精确匹配（`SerializableAttribute` 路径已精确，保留）。
- **判据**：A4-03 的 14 类错型输入全部转正为「类型化异常 + 明确消息」，无 AV、无堆字节进消息、无静默；`TObject` 前缀命名类不过白名单。既有序列化 fixture 子集（`Tests\Test.DeepBase.Serialization.pas`、`Tests\Regression\BUG059_*`/`BUG060_*`）**按纪律 7 先留基线再修**，修后逐一比对。
- **破坏面**：`Core\DeepBase.Serialization.pas`（2370 行，`TSerializer`/`TSerializationContext` 实现本体，`FromJson/FromXml/FromBinary` 均在此）及全部 `FromJson/FromXml/FromBinary` 调用方（数量大，提交前 `rg -ln "FromJson|FromXml|FromBinary" --glob "*.pas"` 自报影响面）。

### A5-R05 [待修] IoC 单例双路径（三条硬约束）
- **代码事实**：对象路径单例分支只读写 `Reg.SingletonInstance`，接口路径只读写 `Reg.SingletonInterface`（并迟后回填），两路径各自判断 ⇒ 双实例（`created=2`）+ 泄漏（`leaked=1`）；`RegisterSingleton(instance)` 只置接口侧，对象路径解析 `CreateInstance` 解引用空实现类型 ⇒ AV。
- **主控三条硬约束**（修法必须满足）：
  1. 抽 `EnsureSingletonInstance` 单一真相源：两路径统一「先查已有实例/已有接口视图，再创建」，消灭顺序依赖（对象先解析/接口先解析/仅接口注册三种序都必须 created=1、同 id、leaked=0）。
  2. 接口视图复用既有实例时，**禁止对 refcount-0 单例做 `Supports`/`QueryInterface` 的 AddRef**（自毁 + 污染计数）——用非持有视图或显式生命周期标注，提交说明须写清选取方式。
  3. `HasSingletonInterface=True` 且无对象视图时，对象路径解析 **raise `EIoCException`（明确信息）**，禁止再 AV。
- **判据**：A4-04 S1/S2/S3 三个探针断言全部转正（failed-assertions 3→0）；另加「容器释放后 leaked=0」。
- **破坏面**：`Core\DeepBase.IoC.pas`、`Core\DeepBase.Services.Registration.pas`、`Features\DeepBase.Browser.IoC.pas`、`Features\DeepBase.Inference.IoC.pas`、`Features\DeepBase.IntentClarification.{IoC,Registration}.pas`；测试 `Tests\Test.DeepBase.{IoC,Inference.IoC,Services.Registration,RuntimeContext}.pas`、`Tests\Test.DeepBase.IntentClarification.Integration.pas`。（Features 侧 IoC 文件**只读不改**——若修法迫使 Features 侧联动，停机上报主控，不许顺手改。）

### A5-R06 [待修] TopExceptions 换入换出不可逆
- **代码事实**：`TopExceptions`（`rg -n "function TopExceptions" Core\DeepBase.LogQuery.pas`）内 `SetDataSource(过滤列表, False)` 触发自有源释放逻辑（owned 源查询中途被销毁），恢复时 `SetDataSource(FDataSource, FOwnsDataSource)` 传的是**换入后的当前值** ⇒ 恢复语义失效，`finally` 中 `ExceptionLogs.Free` 让 `FDataSource` 悬垂（甲 A4 case A/B 共 4 断言失败实证）。
- **修法（首选）**：把过滤后列表**作为参数下传** `TopErrors`，取消临时换入换出（单一真相源、消除 `SetDataSource` 所有权副作用）。若实测发现 `TopErrors` 内部深度依赖 `FDataSource` 状态不可参数化 ⇒ 才允许退而求其次：局部保存 `SavedSrc/SavedOwns`，`finally` 用**不触发 Free 的赋值**恢复；选取哪种须在提交说明写理由。
- **判据**：A4-05 case A（owned）/ case B（borrowed）全部断言转正（源不提前释放、恢复后可继续查询、解耦后值正确、无 AV）。
- **破坏面**：`Core\DeepBase.LogQuery.pas` `TopExceptions`；调用方 `Core\DeepBase.LogAlert.pas`、`Core\DeepBase.LogDashboard.pas`；既有 `Tests\Test.DeepBase.LogAggregator.pas` 不得回归。

### A5-R07 [待修] PDF 字体对象号预留
- **代码事实**（根因与 A4 工单线索不同，**采信甲修正版**，主控已复算）：xref 偏移算式无错；真根因是 `FindOrAddFont`（`rg -n "function FindOrAddFont" Core\DeepBase.Export.PDF.pas`）给字体只分配一个对象号，写伴生 CIDFont 时用 `ObjNum+1` 却从未预留 ⇒ 与后续 Page/Content/Catalog 撞号 ⇒ 重复对象号 + CIDFont 体成孤儿 + `/DescendantFonts` 指向无 `/Subtype` 的对象（甲 xref 校验器 3 文件 9 failed-checks）。
- **修法**：字体登记时**一次分配两个对象号**（entry 增 `CIDObjNum` 字段），`SaveToStream` 用 `CIDObjNum` 写伴生体与 `/DescendantFonts`；删除 `SaveToStream` 开头从未使用的死预分配循环（`rg -n "CIDObj" Core\DeepBase.Export.PDF.pas` 自证死代码后删）。
- **主控收敛**：**只做对象号管理与死代码删除**。禁止顺手重写字体嵌入/TextShow 算子/压缩流——甲 A4 未发现嵌入本身有错，大修无证据支撑且超范围；若修中发现嵌入层另有缺陷，写入回执登记，主控另派。
- **判据**：复用甲校验器 `附件\A406_xref_verify.ps1`（或等效自建）对 3 份真导出 PDF 判定 `TOTAL failed-checks` 9→**0**，`no-duplicate-object-numbers`/`no-orphaned-object-bodies`/`type0-descendant-is-cidfont` 全 PASS；既有 `Tests\Test.DeepBase.Export.Gen.pas` fixture 不回归。
- **破坏面**：`Core\DeepBase.Export.PDF.pas`（`FindOrAddFont`/`SaveToStream`/`TFontEntry`）+ `Tests\Test.DeepBase.Export.Gen.pas`（唯一调用方）。

### A5-R08 [待修] DOCX 属性值转义
- **代码事实**：`EscapeXML` 覆盖 `& < > " '` 且文本/表格路径已用；**属性路径未用**——`w:rFonts`（`rg -n "w:rFonts" Core\DeepBase.Export.DOCX.pas`）、`w:color`、`w:shd` 的 `w:fill` 直接 `%s` 拼属性值 ⇒ `Bad"Font` 令 XML 解析失败（包不可用）、`x" ... <w:ins>` 注入 3 个修订元素（甲 docx 校验器 4 文件 2 failed-checks）。
- **修法**：三处属性 + `w:color` + `w:fill` 的值统一过 `EscapeXML`（属性上下文需引号转义，`EscapeXML` 已含 `"`）。
- **判据**：复用甲校验器 `附件\A407_docx_verify.ps1`（或等效自建），`Bad"Font`/`x" ... <w:ins>`/含 `]]>` 样本全部 round-trip 逐字一致、`w:ins elements=0`、failed-checks 2→0；既有 Export.Gen fixture 不回归。
- **破坏面**：`Core\DeepBase.Export.DOCX.pas` + `Tests\Test.DeepBase.Export.Gen.pas`（唯一调用方）。

### A5-R09 [待修] License 时钟回拨防护（**甲段：Core 侧**）
- **代码事实**（主控复算）：`TLicenseInfo.IsExpired` = `(ExpiresAt > 0) and (Now > ExpiresAt)`，`DaysRemaining` 同用裸 `Now`；Core 全单元无任何时间防护符号；仓内 `Features\DeepBase.TimeGuard.pas`（`GetCorrectedNow`）只被 Features 自己引用且 Licensing 自身也大量用裸 `Now`，`VerifyTime` 结果未接入任何过期判定；`Tests/` 对回拨零覆盖。
- **分层约束**：`DeepBaseCore` 不得反向依赖 Features（架构测试 `Tests\Architecture\Test.Arch.PackageBoundaries.pas` 的 Features→Core 单向关系），故 Core 侧必须**自持**时间源与单调水位。
- **修法（甲段）**：
  1. `Core/DeepBase.License.pas` 增**可注入时间源**（默认 `Now`，供测试注入假时钟；形态参考仓内既有 DI/工厂习惯，先翻 `Core\DeepBase.IoC.pas` 现有能力）；
  2. 增 **last-seen 单调水位**：序列化钩子已具备（写/读路径 `rg -n "LastSeen|ExpiresAt" Core\DeepBase.License.pas`），增一个持久化字段（建议 `l`），读入时水位 = max(既有水位, 文件值)，防删除文件重置；
  3. 生效时间 `EffectiveNow = Max(InjectedNow, LastSeen)`；`Now < LastSeen` ⇒ 判定时钟回拨，按回拨处理（**不得让许可续命**：回拨期间 EffectiveNow 取水位，过期许可保持过期）；
  4. `IsExpired`/`DaysRemaining` 全部改走 `EffectiveNow`，清除裸 `Now`。
- **判据**：新单测覆盖——① 假时钟回拨（Now 前移 30 天）⇒ 到期许可**仍判过期**、剩余天数不增反按水位计；② 删除/篡改许可文件降低水位后重新加载 ⇒ 水位不回退（单调性）；③ 既有 `Tests\Test.DeepBase.{License,LicenseSecret}.pas` fixture 不回归（含 A2-01 密钥外置后的秘密用例）。
- **移交**：甲段落地后，在提交说明与回执点名新时间源符号名与用法（乙 B3 依赖它接线）；**甲不得改** `Features\DeepBase.Licensing.pas` 及任何 Features 文件。
- **破坏面**：`Core/DeepBase.License.pas` + Core 侧测试；下游 `Features\DeepBase.Licensing.pas`、`VCL\DeepBase.VCL.{LicenseStatusPanel,LicenseAuthDialog}.pas`、`FMX\DeepBase.FMX.LicenseStatusPanel.pas`、`Tools\Studio\Forms\Studio.LicenseForm.pas`、`Persistence\DeepBase.Persistence.License.FireDAC.pas`、`Features\DeepBase.Unlock.pas`、`Examples\FullDemo` **本单不碰**，由乙 B3 及后续收口。

## 三、交叉引用与不派单项

- **A5-R09 乙段**（`Features\DeepBase.Licensing.pas` 接 `GetCorrectedNow`、消裸 `Now`、`VerifyTime` 接入过期判定链）**已单派乙 B3**，甲不碰；乙 B3 等本单 R09 甲段符号落地后开工。
- **Supabase 乐观锁超卖**（Top20-08 资金单）仍不重派，不得顺手改。
- **乙 B2 在途件**（B2-12 GUID 重复、B2-13/14 等）文件域与本单零重叠；`Tests\DeepBaseTests.dpr` 注册归主控，甲只建自己的测试单元文件。
- 若任一项修下去发现**前提已变**（符号没了/别处已修）：停机上报，附 `git log -1 -- <file>` 取证，不许绕过去硬修。

## 四、输出物与验收

- 回执：`CodeReview/20260925-AUDIT-甲-A5-交付回执.md`（9 项逐条：提交哈希、判据跑录、回归基线比对、破坏面自报）。
- 证据：`CodeReview/20260925-AUDIT-甲-A5-证据/`（探针/单测运行日志、xref/docx 校验器输出、隔离树编译日志；探针源继续用 `.dpr.template` 别名）。
- 验收：主控对 9 项逐项亲跑判据（探针或单测全限定 fixture）+ 亲读修复 diff + 四门复跑 + 隔离树编译对照基线；**甲自报不作为验收依据**。
- 建议顺序：R04（先留基线，防回归扯皮）→ R05/R06（UAF/泄漏类）→ R01/R02 → R03 → R07/R08（产出物不可用）→ R09（甲段，乙段等符号）。

*主控 · 2026-09-25 签发 · **2026-09-28 正式派出**（重锚 HEAD `2dcd1ae`，派发核查与文本更正见 §〇-10）；本单三项裁定（R02 强路线 / R09 拆两段 / R07 最小修复）随单生效，不属可再议项*
