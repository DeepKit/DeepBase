# WO-20260930-AUDIT-甲-A14 TimeGuard 自研解析器改 RTL（P3 · 1 项）

> 签发：主控 · 2026-09-30 · 排队态：**甲线后位**（A10 待验收、A13 交付中；不与他线争文件）
> 派生来源：《20260930-AUDIT-主控-甲-A13-裁定结论》§八
> 派工对象：**开发 AI 甲**
> 基线锚点：开工时 HEAD（主控在派工消息中重锚）

## 〇、开工纪律

1. **H15 原子提交**：1 项 1 笔，message 带 `A14`；显式 pathspec；前后 `git diff --cached --name-only` == 申报清单；**禁 push**；台账状态槽不碰（归主控）。
2. **禁动区维持**：`v1.1.0` 标签 / EHAI 冻结面 / `TestResults/**` / 新旧 PluginManager 轨 / `contracts/**` / `noise-baseline.json` / `Core/**`（`TTimeZone`/`TryRFC822ToDate` 都是 RTL，无需动底座；若修法迫使碰 `Core/**` ⇒ 停机上报） / `Features/DeepBase.Licensing.pas`（B7 域，**只读**） / `Tests/DeepBaseTests.dpr` 与 `.dproj`（归主控） / `Scripts/**`。
3. **范围收敛**为 `Features/DeepBase.TimeGuard.pas` 的 `ParseRfc822Date`（`:186-271`）及其唯一调用点 `:307`；A13 未验收前**不得开工**（避免同文件两因交织， assertion 面互不明）。
4. **fail-closed 语义不变**：五态语义、`FMaxDriftMinutes` 阈值行为、`IsTimeTrusted` 三可信态集合均不得改。
5. **测试纪律**：全限定子集跑（`bash CodeReview/20260925-AUDIT-乙-B2-证据/b2_run_fixture.sh <单元>`）+ 主套件 exe 同进程（`--run` 限定名）；**禁全量 run**（必崩 216 既存）；**反事实必做**（换回自研解析器 ⇒ 等价探针须仍绿，证 RTL 语义同范）。
6. 编码/行尾：`.pas` UTF-8 BOM + CRLF。

## 一、修单与判据

### 代码事实（主控已核实）

- Studio 37 RTL `System.DateUtils` 自带 `TryRFC822ToDate`（`AReturnUTC: Boolean = True` 默认返 UTC）与 `HttpToDate`，另有过载 `TRFC822ToDateOptions = set of (roReturnUTC)`。
- 仓内 `Features/DeepBase.TimeGuard.pas:186-271` 是手写的 `ParseRfc822Date`，解析 HTTP `Date` 响应头后 `:266` 以 `EncodeDateTime(GMT 数值)` 原样编码 ⇒ 返 UTC 框架裸值。A13 已坐实该函数是「Date 头字符串 → 数值」变换在全仓的唯一发生点。
- `ParseRfc822Date` 为 implementation 私有，唯一调用点 `:307`（默认传输 `TNetTimeGuardHttp` 内部）。

### 修法（唯一定型，不设第二案）

把手写 `ParseRfc822Date` 替换为 RTL `TryRFC822ToDate(S, Result, True)` 的薄封装（或直接内联至 `:307`），删除 `:186-271` 手写实现。命名与可见性维持现状（implementation 私有），不必提为 interface（A13 裁定 §八 已否掉「提为可测面」原形）。

### 判据

1. **等价性（核心）**：新增/增补探针用例，对**同一批** Date 头样本逐条断言「替换前实现」与「RTL 实现」产出逐字节相同。样本必须覆盖：正常 RFC 822（`Wed, 30 Sep 2026 07:52:05 GMT`）、单位数月日（`Wed, 9 Sep 2026 07:52:05 GMT`）、两位数年份、RFC 850 形态（`Wednesday, 30-Sep-26 07:52:05 GMT`）、asctime 形态（`Wed Sep 30 07:52:05 2026`）、畸形串、空串、非 GMT 时区别名（`+0000`/`-0500`）、毫秒噪声。样本集须以字面量表固化在测试单元里，**不接受运行时生成**。
2. **框架不回退**：替换后 `ParseRfc822Date` 对同一 GMT 串仍产 UTC 裸值（`AReturnUTC=True`）——即 A13 判据1/2 的探针面不得因本单回归（A13 探针夹具须复跑全绿）。
3. **不回归**：`Test.DeepBase.TimeGuardSecretStore`（6/6）、`Test.DeepBase.LicensingTimeSource`（7/7）、`Test.DeepBase.License`（16/16）、`Test.DeepBase.Commerce`（68/68）全限定复跑零新增红；既有断言一字不改。
4. **反事实**：换回手写实现 ⇒ 等价探针仍全绿（证 RTL 与手写同范，不是「碰巧一致」）；同时换 `AReturnUTC` 为 `False` ⇒ 等价探针或框架探针须红（证探针有鉴别力）。
5. **编译/门禁**：隔离 `--detach` 树 T0 manifest `BUILD_EXIT=0` 全绿、`Hint=793 Warning=155` 按码串逐字符同一（**不许 emit 基线**）；四门 EXIT=0。

## 二、破坏面与输出物

`Features/DeepBase.TimeGuard.pas`（自研解析器 86 行删除 + 调用点改形，净减）+ 测试单元（等价样本探针）。`Core/**`、`Features/DeepBase.Licensing.pas`、`contracts/**`、`Tests/DeepBaseTests.dpr` 与 `.dproj`、`noise-baseline.json` 零改动。

回执 CodeReview/20260930-AUDIT-甲-A14-交付回执.md + 证据 `CodeReview/20260930-AUDIT-甲-A14-证据/`。验收：主控亲跑 + 样本集逐条复跑 + 反事实复跑 + T0 隔离树 + 四门；**甲自报不作为依据**。

## 三、不在本单（已登记）

- `ParseRfc822Date` 提为 interface 可测面（A13 裁定 §八 已否掉原形，无独立价值时不做）。
- `FServerTimeOffset` 注释订正、`ITimeGuardHttpTransport` 框架声明：归 **A13**（A13 交付中包含）。
- RTL `TryRFC822ToDate` 自身在畸形输入上的行为差异（若等价探针发现某类样本不一致）⇒ 按「窄化样本集并登记」或「保留手写」二择一，**写进回执并停机交主控裁定，不得静默扩大差异面**。

*主控 · 2026-09-30 签发 · 亲跑取证后才派单*
