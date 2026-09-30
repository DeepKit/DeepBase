# WO-20260930-AUDIT-乙-B14 Core AutoFix 时间框架收口 + 调用点可测性（P2 · 2 项）

> 签发：主控 · 2026-09-30 · 冲期：乙线当前零在途（B13 已于 2026-09-30 ACCEPTED，B12 排队态解除但顺次于本单之后，乙线不并发两单）
> 基线锚点：HEAD `89ba4a8`（B13 四笔落定后的主树 HEAD，428 笔未 push）
> 派工对象：**开发 AI 乙**
> 缺陷来源：《20260929-AUDIT-主控-乙-B13-验收结论》§三派生表第 1 行（B13 回执 §八-1 + 主控亲读复核）
> 上游口径：`Features/DeepBase.Commerce.Types.pas` interface 的 wire convention 注释（B10 立的 SSOT）+ `ThirdParty/Payment/DeepBase.Payment.Alipay.pas:181`（仓内唯一「显式 UTC+8 偏移」先例）

## 〇、开工纪律（违者整单打回）

1. **H15 原子提交**：2 项 = 最多 2 笔独立提交（message 分别带 `B14-01`/`B14-02`）；显式 pathspec（写成 `git commit -m "…" -- <pathspec>`，**选项在 `--` 之前**；并行线他线暂存件常驻索引，禁 bare `git commit -m`）；前后 `git diff --cached --name-only` == 申报清单；每笔后 `git show --name-only` 核验件数；**禁 push**；台账状态槽**不碰**（改写权归主控，B10 验收结论 §8 立规）。
2. **禁动区维持 + 本单唯一开口**：`contracts/**` / `Tests/DeepBaseTests.dpr` 与 `.dproj` / `Tests/Integration/**` / `TestResults/**` / `v1.1.0` 标签 / EHAI 冻结面 / 新旧 PluginManager 轨 / `noise-baseline.json` / `Features/DeepBase.Licensing.pas`（B7 域）/ `Features/DeepBase.TimeGuard.pas`（只读）/ `Scripts/**`。**`Core/**` 对本单开口，且仅限 B14-01 的 4 个文件**（`Core/DeepBase.AutoFix.HealthSignal.pas`、`DeepBase.AutoFix.ErrorRecorder.pas`、`DeepBase.AutoFix.SelfTerminator.pas`、`DeepBase.AutoFix.ScenarioRunner.pas`）＋按枚举结果落在同 4 件内的连带修改。**Core 其余任何文件零改动**，**不得新增 Core 单元**（会撞 `Tests/DeepBaseTests.dpr` 禁动区）。
3. **fail-closed**：既有断言红即停机上报，先留基线再修，**不许改既有断言「修绿」**；修法若迫使公开签名变更 ⇒ 停机上报主控裁定。
4. **测试纪律**：一律 fixture 全限定子集（`bash CodeReview/20260925-AUDIT-乙-B2-证据/b2_run_fixture.sh <单元>`），**禁全量 run**（必崩 216 既存）；本单判据①要求「在本机 UTC+8 上咬住」，故**不得**把断言写成「只在本机偏移 == 注入偏移时才红」的自证循环；反事实必做（换回旧形态 ⇒ 新断言真变红）。
5. 编码/行尾：`.pas` UTF-8 BOM + CRLF。证据件**禁含**丙类乱码明细行／U+FFFD（甲 A11、B13 同坑两次，复跑前先扫）。

## 一、修单与判据

### B14-01：`Core/DeepBase.AutoFix.*.pas` 4 点「本机本地数值 + 硬编码固定 `+08:00`」

**代码事实（主控亲读 @`89ba4a8`，行号已核实；4 点形态完全同族）**：

```pascal
// Core/DeepBase.AutoFix.HealthSignal.pas:150（.Append 链，写入 health-signal.json 的 "timestamp"）
.Append(FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"+08:00"', Now)).Append('"')
// Core/DeepBase.AutoFix.SelfTerminator.pas:200（.Append 链，写入 exit-reason.json 的 "timestamp"）
.Append(FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"+08:00"', Now)).Append('"')
// Core/DeepBase.AutoFix.ErrorRecorder.pas:343（var LTs :=，写入 runtime-errors.jsonl 的 "ts"）
var LTs := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"+08:00"', Now);
// Core/DeepBase.AutoFix.ScenarioRunner.pas:214（var LTs :=，写入场景记录的 "ts"）
var LTs := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"+08:00"', Now);
```

**缺陷**：后缀 `+08:00` 是**字面量**，与本机实际偏移无关。UTC+8 部署下恰好正确；非 UTC+8 部署下（含负偏移）这 4 个时间串各自偏差本机偏移量，且**方向不定**（UTC+8 机器差 0、UTC−5 机器差 13 小时、UTC 机器差 8 小时）。形态与 B13-03 修前 WeChat 的实现完全同族，属同一缺陷族的第 5～8 例。

**修法（枚举先行，禁只改点名 4 点）**：

1. **枚举**：`rg` 全仓同形态（`FormatDateTime` 内出现固定偏移字面量、或 `zzz` 被写成固定 `+/-hh:mm` 常量）。主控已核实的同族面之外**仍有其他命中**的可能性未排除，枚举表须逐点分类并给出「本单改 / 已登记不改」及理由，不许留「未定」格。
2. **分类**：4 点（＋枚举新增命中）逐点分**判定用点 / 仅展示用点**。主控已核实：这 4 点的 `ts`/`timestamp` 字段**只写不读**——`Scripts/autofix/runner.ps1` 的 `Read-HealthIfReady` 只比对 `run_id`，全 `Scripts/autofix/**` 与 `Examples/AutoFixDemo/**` 均无任何回读解析该字段的代码；`Tests/AutoFix/schemas/*.json` 只规定**字段名必需**（`ts` / `timestamp`），**不规定格式**。故 4 点均倾向「仅展示用点」，但**分类权在乙的枚举表**，主控按表验收。
3. **修形**：不得保留「本机本地数值 + 硬编码固定后缀」。候选（**按仓内先例选，回执须说明选型理由**，与 B13-03 同范）：
   - (a) **跟随本机实际偏移**：`DateToISO8601(Now, False)`（RTL 语义 = 原值 + 本机实际偏移后缀，见 B10-1 探针）。这与 **PowerShell 侧同族写法一致**——`Scripts/autofix/_common.ps1:43` 的 `Get-AutoFixTimestamp` 就是 `Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'`（本机本地 + 本机实际偏移，自洽）。⇒ 两侧 runner 与 Delphi 写方口径统一。
   - (b) **显式收 UTC**：`DateToISO8601(TTimeZone.Local.ToUniversalTime(Now), True)`（Zulu 串）。
   - (c) **显式 UTC+8**：与 `Alipay.pas:181` 同形 `FormatDateTime(..., IncHour(TTimeZone.Local.ToUniversalTime(Now), 8))`。
   - **主控倾向 (a)**：这 4 点是本机进程写给同机 runner 的遥测字段，`zzz`（本机偏移）是同族 PS 写方既有口径；(b) 会改字段语义（虽无消费者，但属无收益的契约漂移）；(c) 只在确需北京时时用。**最终由乙据枚举表与 PS 侧先例定，理由写进回执。**
4. **可测试性（本项硬约束）**：4 点的缺陷在**本机 UTC+8 上不可见**（差 0）。故断言**必须与偏移无关地咬住**：把「取现在 → 格式化」收敛成**可注入偏移/瞬时的可测试形态**（纯函数、类方法＋seam、或把 `Now` 与偏移格式串分离），新用例以**假偏移/假瞬时**驱动，断言输出串的偏移部分与瞬时部分**分别**正确。**禁止**写成「读本机 `TTimeZone.Local.UtcOffset` 再比对」（那是自证循环，本机 UTC+8 上修前修后同值）。Core 内不得新增单元（见 §〇-2），seam 放哪件、画依赖图，由乙定并在回执说明（主控已核实的层级线索：`ScenarioRunner`/`StackWalker` 是叶，`ErrorRecorder` 被 `HealthSignal`、`SelfTerminator` uses，`DeepBase.AutoFix.pas` uses 后三者——注意别造 interface 循环）。

**判据**：① 枚举表逐点分类闭环，无「未定」格；② 4 点全部改为自洽形态，`rg` 同族硬编码字面量在开口 4 件内清零（或逐条给不改理由）；③ 新用例在**本机 UTC+8** 上对修前形态**变红**（证明不是自证循环）；④ 反事实：把任一改点换回 `FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"+08:00"', Now)` ⇒ 对应用例**必须变红**；⑤ 4 个已注册 fixture（`Test.DeepBase.AutoFix.ErrorRecorder` / `.HealthSignal` / `.ScenarioRunner` / `Test.DeepBase.AutoFixSelfTermination`）全绿，`Tests/DeepBaseTests.dpr` 零改动（主控已核实 5 个 Core AutoFix 单元 + 4 个 fixture 均已在 `:230-241` 在册，**勿动 dpr**）；⑥ 不改 JSON 字段名与必需字段集（`Tests/AutoFix/schemas/*.json` 零改动）。

### B14-02：`ThirdParty/Payment` 调用点时间框架约定不可测试

**代码事实（主控亲读 @`89ba4a8`）+ B13 验收 CF-5 实测**：

```pascal
// ThirdParty/Payment/DeepBase.Payment.WeChatPay.pas:767（唯一生产调用点）
ReqBody.AddPair('time_expire',
  WeChatTimeExpire(TTimeZone.Local.ToUniversalTime(Now), AOrder.ExpireMinutes));
// ThirdParty/Payment/DeepBase.Payment.Stripe.pas:328（唯一生产调用点）
Params.Add('expires_at', IntToStr(
  StripeExpiresAtUnix(TTimeZone.Local.ToUniversalTime(Now), AOrder.ExpireMinutes)));
```

**缺陷**：两个接缝的形参名 `ANowUtcBare` 声明了「调用点必须传 UTC 裸值」这一框架约定，但它是 **`TDateTime` 类型系统不检查、只活在注释里的约定**。B13 验收 CF-5 实测：把两处调用点换回裸 `Now`（接缝一字不动）⇒ `Test.DeepBase.Payment` **27/27 全绿**。即 B13 的单测锁住了**接缝内**的换算，锁不住**调用点**是否真的传 UTC 读数——同族缺陷若再犯，测试不会响。

**附带的第二重事实（主控已核实，写入判据边界）**：`Core/DeepBase.TimeSource.pas:119` 的 `TDeepBaseTimeSource.Now` **不做任何时区换算**，它只是对 `FNowFunc()`（或 `System.SysUtils.Now`）读数加单调水位夹压。因此把调用点从 RTL `Now` 换成 `TDeepBaseTimeSource.Shared.Now` **不改变读数的基准（仍是本地裸值）**，外层 `TTimeZone.Local.ToUniversalTime(...)` **必须保留、不可删**（删了就是双重遗漏 / 加了就是双重换算，两个方向都错）。另：仓内唯一可注入时钟是 `TDeepBaseTimeSource.Shared.SetNowFunc`（**类方法**，Fixture 无法直接改）；且该单元在 `DeepBaseServices.dpk:34`，`ThirdParty/Payment` 各单元当前 uses 面**不含**它——夹具能否解析到该单元由乙实测定（探针面需 `DEEPBASE_EXTRA_U`，见 §〇-4 引用脚本头部注释）。

**修法（候选，由乙据实测选型并写理由；禁只改注释/只改参数名）**：

- (a) **调用点改读 `TDeepBaseTimeSource.Shared.Now`**（保留外层 `ToUniversalTime`）⇒ 现有夹具的 `SetNowFunc` 随即能驱动调用点，最小改动即得可观测性；前置条件是夹具搜索面可达该单元，须实测。
- (b) **把接缝的约定提升为类型/命名强制**：如接缝改吃一个具名参数类型或 `TDeepBaseTimeSource` 实例，使「传错基准」在编译期或调用形态上显式化。
- (c) **把换算整体移入接缝**：调用点只喂本地读数，`IncHour`/`ToUniversalTime` 全在接缝内完成一次，seam 输入输出同基准 ⇒ 单测直接锁死整个链条（注意这会改动接缝签名 ⇒ 触发 §〇-3 停机上报条件，须先报裁）。

**判据**：① 修后**主控必做 CF-5 同款反事实**：把两处调用点换回 `WeChatTimeExpire(Now, ...)` / `StripeExpiresAtUnix(Now, ...)` ⇒ 新用例**必须变红**（B13 时全绿 ⇒ 修后必须红，这是本项唯一硬验收）；② 反事实之外另验正向：夹具以假时钟/假瞬时驱动，断言两 wire 字段与注入瞬时一致（不随本机时区变）；③ `Test.DeepBase.Payment` 夹具全绿且计数变化如实留档；④ 不改两 wire 字段语义、不改两接缝对外的值语义（换基准不算改语义，删/加一次换算算）；⑤ 回执须说明 (a)/(b)/(c) 选型理由 + `TDeepBaseTimeSource` 在夹具面的可达性实测结论；⑥ 若选 (a) 而导致夹具 needs 新增路径 ⇒ **只改夹具侧**，`Tests/DeepBaseTests.dpr`/`.dproj` 仍零改动。

## 二、破坏面与输出物

`Core/DeepBase.AutoFix.{HealthSignal,ErrorRecorder,SelfTerminator,ScenarioRunner}.pas`（仅此 4 件，按枚举结果可含同 4 件内连带）＋既有已注册 fixture `Tests/AutoFix/Test.DeepBase.AutoFix.{ErrorRecorder,HealthSignal,ScenarioRunner}.pas`、`Tests/Test.DeepBase.AutoFixSelfTermination.pas`＋`ThirdParty/Payment/DeepBase.Payment.{Stripe,WeChatPay}.pas`＋`Tests/Test.DeepBase.Payment.pas`。下游 Studio/VCL/FMX/Unlock 只读不碰。

回执 `CodeReview/20260930-AUDIT-乙-B14-交付回执.md` + 证据 `CodeReview/20260930-AUDIT-乙-B14-证据/`；验收：主控亲跑 + 亲读 diff + 反事实复跑（含 CF-5 同款）+ 禁动区 grep（Core 开口 4 件**以外**必须空）+ 四门；**乙自报不作为依据**。

## 三、不在本单（已登记）

- **provider 回调时间戳取用**：三家 provider 回调载荷带了交易时间而适配层未取，落回 `Now` ⇒ `PaidAtISO` 恒走墙钟兜底。已由主控登记进台账 §三「待立项态」，**不并入本单**（本单面要窄：Core 4 点 + 调用点可测性）。
- **CI 固定非 UTC 时区**：主控自办（台账 §三），乙不碰 `.github/**`。
- `ThirdParty/Payment` 其余既有缺陷（并发 CustomHeaders、CreateJSAPIOrder 重复调用、`QueryOrder` 用错 ID 等，见 `docs/evaluation/08-commerce-payment-integration.md`）不属本单，维持评估文档登记态。
- `Core/DeepBase.AutoFix.*` 的时间字段若枚举发现**确有回读消费者**（主控已核为无，若乙发现新的）⇒ 停机上报，勿自行改字段语义。

*主控 · 2026-09-30 签发 · 枚举先行（B10/B13 同范），禁止只改工单点名处；本机 UTC+8 无鉴别力处必须靠注入偏移而非自证循环*
