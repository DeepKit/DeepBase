# WO-20260930-AUDIT-乙-B15 provider 回调交易时间取用澄清（P3 · 1 项）

> 签发：主控 · 2026-09-30 · 排队态：**乙线后位**（B14 未 ACCEPTED 前不得开工；乙线不并发两单）
> 派生来源：B13 验收结论 §三 ③ + 乙 B13 回执 §八-2 + 派单总表 §三 登记行「provider 回调时间戳取用（待立项）」
> 派工对象：**开发 AI 乙**
> 基线锚点：开工时 HEAD（主控在派工消息中重锚；当前 HEAD `e78175e`）

## 〇、开工纪律

1. **H15 原子提交**：1 项 1 笔，message 带 `B15`；显式 pathspec；前后 `git diff --cached --name-only` == 申报清单；**禁 push**；台账状态槽不碰（归主控）。
2. **禁动区维持**：`v1.1.0` 标签 / EHAI 冻结面 / `TestResults/**` / 新旧 PluginManager 轨 / `contracts/**` / `noise-baseline.json` / `Core/**`（本单连读都不必读——Core 开口面归 B14）/ `Tests/DeepBaseTests.dpr` 与 `.dproj` / `Tests/Integration/**` / `Scripts/**` / `Features/DeepBase.Licensing.pas`。本单**零 `.pas` 改动**，禁动区实为只读纪律。
3. **范围收敛**：只读 `ThirdParty/Payment/**`、`Features/DeepBase.Commerce.PaymentBridge.pas`、`Features/DeepBase.Commerce.Service.pas`、`Features/DeepBase.Commerce.Types.pas`、`Features/DeepBase.Commerce.JsonUtil.pas`、`Features/DeepBase.Commerce.Adapter.Firebase.pas`、`Features/DeepBase.Commerce.Adapter.Supabase.pas`、`Tests/Test.DeepBase.Commerce.PaymentBridge.pas`、`docs/evaluation/08-commerce-payment-integration.md`。产出仅回执 + 证据件。
4. **fail-closed 三档取证**：载荷时间字段的可用性按证据分档——A 仓内代码或夹具佐证 / B 仓内文档佐证 / C 仅外部 API 口径（无仓内佐证）。**档 C 字段不得作为修法定论依据**，只能进「待沙盒验证」清单。禁止凭官方 API 记忆直接断言字段存在或其格式。
5. **基线差异即停机**：任何一格与 §一 主控基线不符 ⇒ **停机上报**，禁静默扩大或缩小枚举面。所有结论带 `文件:行` 或命令原文。
6. **串行**：B14 未 ACCEPTED 前不得开工；B15 验收前不开乙线下一单。

## 一、主控已核实的代码基线（2026-09-30 亲读 @ `e78175e`）

### 1.1 仓内 `PaidAt` 赋值点仅两处，均在 PayPal

| # | 位置 | 路径 | 取值 | 框架 |
|---|---|---|---|---|
| P1 | `ThirdParty/Payment/DeepBase.Payment.PayPal.pas:574` | `QueryOrder` 的 status='COMPLETED' 分支 | `Now` | 本地裸值 |
| P2 | `ThirdParty/Payment/DeepBase.Payment.PayPal.pas:810` | webhook `CHECKOUT.ORDER.COMPLETED` 分支 | `Now` | 本地裸值 |

### 1.2 其余事件源从不赋值 ⇒ `Clear` 置 0

`ThirdParty/Payment/DeepBase.Payment.pas:374`（`TPaymentQueryResult.Clear`）与 `:429`（`TPaymentNotification.Clear`）均 `PaidAt := 0`。以下解析路径从不写 `PaidAt`：

- `ThirdParty/Payment/DeepBase.Payment.PayPal.pas:814-831`（`PAYMENT.CAPTURE.COMPLETED` / `PENDING`）
- `ThirdParty/Payment/DeepBase.Payment.Stripe.pas:408-434`（`RetrievePaymentIntent`：读 id / metadata.order_no / amount / amount_received / status）
- `ThirdParty/Payment/DeepBase.Payment.Stripe.pas:558-640`（`VerifyNotificationWithSignature`：四类事件）
- `ThirdParty/Payment/DeepBase.Payment.WeChatPay.pas:1016-1051`（`QueryOrder`）
- `ThirdParty/Payment/DeepBase.Payment.WeChatPay.pas:1191-1308`（`VerifyNotificationWithSignature`）
- `ThirdParty/Payment/DeepBase.Payment.Alipay.pas:685-728`（`VerifyNotification`，表单形态）

### 1.3 下游链（`PaidAt` → wire）

`Features/DeepBase.Commerce.PaymentBridge.pas:262-265`（`SDKNotif.PaidAt > 0` ⇒ `DateToISO8601(TTimeZone.Local.ToUniversalTime(SDKNotif.PaidAt), True)`；否则 `''`）→ `Features/DeepBase.Commerce.Service.pas:322-324`（空 ⇒ `CommerceNowISO` 墙钟兜底）→ `Payment.PaidAtISO` 与 `Result.PaidAtISO` → wire 字段 `paid_at`（`Features/DeepBase.Commerce.JsonUtil.pas:392` 读 / `:409` 写）与两个 adapter 落库（`Features/DeepBase.Commerce.Adapter.Firebase.pas:394/:408`、`Features/DeepBase.Commerce.Adapter.Supabase.pas:322/:336`）。

### 1.4 桥面是 4 家，不是台账原记的「三家」

`Features/DeepBase.Commerce.PaymentBridge.pas:271`（Alipay）/ `:286`（WeChatPay）/ `:302`（Stripe）/ `:315`（PayPal）共四个 verifier 工厂。台账 §三 该登记行「三家」口径由主控在派单时订正为 4 家，本单枚举按 4 家执行。

### 1.5 查询路径当前是死面（主控基线，乙须自核）

`TPaymentQueryResult.PaidAt` 在 `Features/**` 无任何消费（`QueryOrder` 在 Features 面 0 命中）⇒ 查询路径今天不影响 `PaidAtISO`。枚举仍须覆盖该路径——未来轮询或对账流会继承这两个赋值点。

### 1.6 待取证的载荷时间字段（主控未在仓内找到佐证，默认档 C）

| 提供方 | 候选字段 | 编码形态（外部口径，待取证） |
|---|---|---|
| PayPal | order `create_time` / `update_time`、capture `create_time` | RFC 3339 GMT |
| Stripe | `created` | Unix 秒 |
| WeChatPay | `success_time` | RFC 3339 带 `+08:00` |
| Alipay | `notify_time` / `gmt_payment` / `gmt_create` | `+08:00` 裸串（无偏移后缀） |

## 二、修法（本单 = 澄清：枚举 + 候选，零生产代码）

### 2.1 枚举矩阵（必交）

4 家 × 2 路径（notify / 查询）+ 1 死面 = 9 格，每格 5 列：路径函数（`文件:行`）/ 载荷时间字段名 / 编码形态 / 当前是否已被解析 / 证据档位（A/B/C，定义见 §〇.4）。无字段的格必须显式写「无字段」并给判据，不得留空。

### 2.2 基线复核（必交）

对 §一 1.1–1.5 逐条给出「一致」或「不一致 + 原文」。不一致 ⇒ 按 §〇.5 停机上报，不得自行改动结论。

### 2.3 修法候选（必交，不落地）

至少 2 案，每案须答五问：

1. 改动文件清单（含 `Features/DeepBase.Commerce.PaymentBridge.pas` 与四家 provider 的逐点）；
2. 对 `Tests/Test.DeepBase.Commerce.PaymentBridge.pas` 既有两例（`TPaidAtWireConventionTests`，`:182-220`，含本地裸值假提供者 `TLocalClockPaymentClient`）的影响逐例评估；
3. 四种编码（GMT `Z` / Unix 秒 / `+08:00` 串 / 裸串）各由谁在哪个函数解析、以什么框架进入接缝；
4. `Features/DeepBase.Commerce.Service.pas:323-324` 墙钟兜底保留、改显式标记（空串上抛）或删除，各自的 fail-closed 后果；
5. 与 B14 的接缝面关系——B14 治「调用点读 RTL `Now` 而非 `TDeepBaseTimeSource.Shared.Now`」的 `ANowUtcBare` 注释约定；本单若改 `TPaymentNotification.PaidAt` 的框架语义，两单的「注释约定不可测」问题会叠加，须在主控裁修法时一并考虑。

候选方向（不限定，可提更优案）：案一 接缝语义改 UTC 裸值（provider 解析时换算、桥面去掉 `ToUniversalTime`）；案二 保持本地裸值接缝（四家解析时就地换算为本地裸值）；案三 分层（notify 取 payload 真值、查询路径维持现状并登记）。

## 三、判据

1. **矩阵完整**：9 格 × 5 列齐、无空格、档位标注正确。
2. **基线一致**：§一 1.1–1.5 逐条复核为「一致」；不一致 ⇒ 本单判据不成立，按停机流程交主控裁定。
3. **档 C 自律**：修法候选显式声明依赖哪些字段、其中哪些是档 C；凡依赖档 C 的候选须附「沙盒验证通过后才可开工」的前提。
4. **死面自核**：乙自行 rg 复核 `QueryOrder` 在 `Features/**` 0 命中，命令原文入证据。
5. **破坏面**：零 `.pas` 改动；`git status --porcelain` 除回执与证据件外为空（附原文）。
6. **纪律**：H15 1 笔、显式 pathspec、禁 push、台账状态槽不碰。
7. **门禁**：本单只动 `.md` / `.txt` ⇒ eol 门与 evidence-encoding 门必跑且 EXIT=0（encoding / mojibake 不涉及也复跑留档）；四门原文入证据。

## 四、破坏面与输出物

回执 CodeReview/20260930-AUDIT-乙-B15-交付回执.md + 证据 CodeReview/20260930-AUDIT-乙-B15-证据/（枚举矩阵、基线复核表、修法候选、rg 与门禁原文）。生产码、Tests/**、contracts/**、Scripts/**、Core/** 零改动。

验收：主控亲读 + 矩阵逐格复跑 rg + 候选修法审读；**乙自报不作为依据**。

## 五、不在本单（已登记）

- 任何生产代码改动与 `TPaymentNotification.PaidAt` 框架语义变更本身（修法由主控裁后另单落地）。
- B14 并入项（Core 4 点 + `ANowUtcBare` 调用点可测性）；B13-02/03 已 ACCEPTED 面（Stripe `expires_at`、WeChat `time_expire`）。
- wire 字段 `paid_at` 的版本化或语义变更（属契约面，未立项前不动）。
- CI 固定非 UTC 时区（主控自办，见派单总表 §三）。

*主控 · 2026-09-30 签发 · B14 ACCEPTED 后派工*
