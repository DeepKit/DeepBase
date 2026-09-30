# WO-20260929-AUDIT-甲-A13 TimeGuard 服务器读数链跨框架裸值混用收口（P1 · 1 项）

> 签发：主控 · 2026-09-30 · 排队态：**甲线后位**（A10 待验收、A12 排队；不与他线争文件；不把 A11 刚接通的 fail-closed 落点留在坏框架里）
> 基线锚点：开工时 HEAD（主控在派工消息中重锚）
> 派工对象：**开发 AI 甲**
> 缺陷来源：《20260929-AUDIT-主控-甲-A11-验收结论》§三——主控验收甲 A11 时用框架探针**实测坐实**（原件 `CodeReview/20260929-AUDIT-主控-甲-A11-证据/A11-MC-框架探针-服务器读数链坐实.txt`），与乙 B10 修掉的 Commerce 旧缺陷**同族同因**（裸值跨框架混用），非 A11 引入（修前即存，A11 工单范围收敛在接线，甲正确地未越界）

## 〇、开工纪律

1. **H15 原子提交**：1 项 1 笔（若按两案拆分落地可拆「解析换算」与「水位串框架」两笔，逐笔可编译），message 带 `A13`；显式 pathspec；前后 `git diff --cached --name-only` == 申报清单；**禁 push**；台账状态槽不碰（归主控）。
2. **禁动区维持**：`v1.1.0` 标签 / EHAI 冻结面 / `TestResults/**` / 新旧 PluginManager 轨 / `contracts/**` / `noise-baseline.json` / `Core/**`（`TTimeZone` 是 RTL，无需动底座；若修法迫使碰 `Core/**` ⇒ 停机上报）/ `Features/DeepBase.Licensing.pas`（B7 域，**只读**——本单不碰其消费链）/ `Tests/DeepBaseTests.dpr|.dproj`（归主控）/ `Scripts/**`。
3. **范围收敛**为 `Features/DeepBase.TimeGuard.pas` 的「服务器读数 → 水位读写 → 两条回拨比较 + drift 分类」链；既有断言（含 A11 新单元 6 例）**一字不改**，新用例可增补于 `Tests/Test.DeepBase.TimeGuardSecretStore.pas` 或新单元。
4. **fail-closed 语义不变**：`tgOk/tgSkewMinor/tgSkewMajor/tgClockRewound/tgOffline` 五态语义、`FMaxDriftMinutes` 阈值行为、`IsTimeTrusted` 三可信态集合均不得改；阈值参数语义不是本单对象。
5. **测试纪律**：全限定子集跑（`bash CodeReview/20260925-AUDIT-乙-B2-证据/b2_run_fixture.sh <单元>`）+ 主套件 exe 同进程（`--run` 限定名）；**禁全量 run**（必崩 216 既存）；**反事实必做**（换回旧解析/旧框架 ⇒ 新用例真变红）。
6. 编码/行尾：`.pas` UTF-8 BOM + CRLF。

## 一、修单与判据

### 代码事实（主控亲读 + 探针实测，逐点可复验）

1. `Features/DeepBase.TimeGuard.pas:186-271` 的**自研** `ParseRfc822Date`（非 RTL）：解析 HTTP `Date` 响应头（RFC 822，**GMT = UTC 框架**）后 `:266 Result := EncodeDateTime(LYear, LMonth, LDay, LHour, LMin, LSec, 0)` —— **GMT 数值原样编码、不换算** ⇒ 返回 UTC 框架裸值，却被全链当本地裸值用。
2. `Verify`：`:413 LLocalNow := Now`（本地裸值）→ `:424 LServerTime := GetHttpTransport.FetchServerTime(...)`（UTC 框架值）→ `:447 FServerTimeOffset := LServerTime - LLocalNow`（**跨框架相减**）→ `:433`/`:451` 两条回拨比较 `LLocalNow < LLastGood`。
3. 水位链：`SaveLastKnownGoodTime:381 DateToISO8601(ATime, False)` 写、`LoadLastKnownGoodTime:400 TryISO8601ToDate(LISO, Result, False)` 读——主控探针实测 `False/False` 往返**数值守恒**（读回 == 写入的 UTC 裸值）⇒ 水位以 UTC 框架存放、与本地裸值比较。

### 缺陷（主控探针实测，本机 UTC+8；UTC 机器 offset=0 无症状 ⇒ 探针 k=0 无鉴别力，CI 亦不暴露）

- **drift 恒 ≥ 本机偏移**：同一真实瞬时的两个读数相减恒得 `−offset` ⇒ `LDriftMinutes` 恒 480（UTC+8）⇒ `:465` 的 `tgOk` **不可达** ⇒ Verify 恒 `tgSkewMajor`。探针原始输出：`utc-framed server (prod) drift_min=480.0 -> MajorSkew` vs `local-framed server drift_min=0.0 -> OK`。
- **消费链后果**（`Features/DeepBase.Licensing.pas`，只读不碰）：`TTimeGuard.IsTimeTrusted` 三可信态不含 `tgSkewMajor` ⇒ 非 UTC 生产的 `TDeepLicensing.IsTimeTrusted` **恒 False** ⇒ `:707` 试用发放 `Exit(0)`、`GetCorrectedNow` 抛 `EDeepBaseLicensingTimeUntrusted`、`:873` `SeedWatermark` **永不播种**（Core 单调水位收不到服务器读数）。**fail-closed 方向的过紧假阳性**，用户主力时区 UTC+8 全量命中。
- **回拨检测钝化**：水位 UTC 框架 vs 本地裸值 now ⇒ 本地时钟回拨不足一个偏移量时两条 rewind 分支均不触发（探针实测 `offline rewind fires: False`：本地 11:32 vs 水位 03:32）——**A11 刚接通的 fail-closed 落点被偏移量吃掉**。

### 修法（两案，甲二选一，回执说明选型理由；先 rg 仓内 `TTimeZone` / `ToUniversalTime` / `ToLocalTime` 惯例）

- **案 A（最小改动，一点收口）**：`ParseRfc822Date` 末尾把 GMT 编码值换算本地裸值框架（`Result := TTimeZone.Local.ToLocalTime(...)` 之类）⇒ 全链（offset/drift/水位/回拨比较）自洽，存量键无需迁移。
- **案 B（与乙 B10  Commerce 修后同范，推荐）**：`Verify` 内两侧显式统一 UTC 框架比较（`LLocalNow` 改 `TTimeZone.Local.ToUniversalTime(Now)`、水位写读改 `DateToISO8601(..., True)` / `TryISO8601ToDate(..., True)`）——水位 ISO 串与 Commerce 域 wire convention（`Features/DeepBase.Commerce.Types.pas` interface 注释，B10 立的 SSOT）对齐；**须同步处理存量键**（见下条）。
- **存量水位键必答**（写进回执）：旧框架写入的 `+08:00` 串在案 B 下首次读回差一个偏移量 ⇒ 评估并择一：① 容忍「修后首次 Verify 以一次误判 rewound 换取自愈」并说明 `SaveLastKnownGoodTime` 下一次在线写入即覆盖；② 版本化键名（`AppID + '.timeguard.v2'`）弃旧读新；③ 其他（须论证）。**不允许静默不处理**。案 A 无此问题（若选 A 在回执里明示）。

### 判据

1. **双向对照（核心）**：同一份测试源码在修前/修后两棵树（甲 A11 同范）——fake transport 返回「GMT 数值」（`TTimeZone.Local.ToUniversalTime(Now)`）时：修后 `Verify` 必须 `tgOk`；修前必须非 `tgOk`（红点即 drift 框架用例）。修前/修后两树新单元 sha256 逐字节相同，唯一变量是解析/比较那处。
2. **回拨恢复**：GMT 框架水位 + 本地回拨 > `FMaxDriftMinutes` ⇒ `tgClockRewound`；**回拨量 < 一个偏移量的用例修前必须红**（证明钝化已消）修后绿；反事实：换回 `EncodeDateTime` 原样 ⇒ 判据 1/2 用例回红。
3. **不回归**：`Test.DeepBase.LicensingTimeSource`（7/7）、`Test.DeepBase.License`（16/16）、`Test.DeepBase.Commerce`（68/68）、`Test.DeepBase.TimeGuardSecretStore`（6/6，主控已并网）全限定复跑零新增红。
4. **编译/门禁**：隔离 `--detach` 树 T0 manifest（27 件）`BUILD_EXIT=0` 全绿、`Hint=793 Warning=155` 按码串逐字符同一（**不许 emit 基线**）；`DeepBaseCommerce.dpk` 单件 `HINT=8 WARN=2` 不劣化；四门 EXIT=0。
5. **存量键**：按修法「必答」落定的策略有测试或用例说明；不回退判定语义。

## 二、破坏面与输出物

`Features/DeepBase.TimeGuard.pas`（解析/比较/水位框架链）+ `Tests/Test.DeepBase.TimeGuardSecretStore.pas`（增补用例，既有 6 例一字不改）或新测试单元；`Core/**`、`Features/DeepBase.Licensing.pas`、`contracts/**`、`Tests/DeepBaseTests.dpr|.dproj`、`noise-baseline.json` 零改动。

回执 `CodeReview/20260929-AUDIT-甲-A13-交付回执.md` + 证据 `CodeReview/20260929-AUDIT-甲-A13-证据/`；验收：主控亲跑 + 同款框架探针复测 + 反事实复跑 + T0 隔离树 + 存量键策略审读；**甲自报不作为依据**。

## 三、不在本单（已登记）

- `ConfirmPurchase`/`Idempotency.PurgeExpired` 的墙钟测时长 ⇒ 乙 B12（排队态，同族不同修法：改单调计时源）。
- A11 判据③④ 的非 Windows `raise` 分支未复证项 ⇒ A11 验收结论登记态，CI 接通 Linux 前维持登记。
- `FServerTimeOffset` 属性注释（`ServerTime - LocalTime`）随修法一并更新即可，不另立单。
- `ThirdParty/Payment` 三桥时间框架 ⇒ 乙 B13（在途）。

*主控 · 2026-09-30 签发 · 探针实测坐实才派单；禁止只改工单点名处，两案选型理由须入回执*
