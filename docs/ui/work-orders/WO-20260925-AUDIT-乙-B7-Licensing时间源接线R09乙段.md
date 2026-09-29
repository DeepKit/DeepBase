# WO-20260925-AUDIT-乙-B7 Licensing 时间源接线（A4-R09 乙段 · 1 项）

> 签发：主控 · 2026-09-25 · **2026-09-28 正式派出（重锚 HEAD `2dcd1ae`）**
> 基线锚点：HEAD `2dcd1ae`（原锚 `b603cc9` = A4 验收结论提交；其后经甲 A6、乙 B8、主控 dproj 修复笔 `d80671e` 与台账回填叠加；`git diff b603cc9 2dcd1ae -- Features/` = **空** ⇒ 本单目标文件 `Features\DeepBase.Licensing.pas` 零漂移）
> 派工对象：**开发 AI 乙**
> 缺陷来源：甲 A4 补验单 A4-08 判定（**主控已亲读复算坐实**，结论 `CodeReview/20260925-AUDIT-主控-甲-A4-验收结论.md` §四.2 跨层拆分裁定）。本单是 A4-R09 的 **Features 侧段**；Core 侧段（时间源注入 + LastSeen 单调水位）已派 **甲 A5-R09**，甲先乙后。
> 本单与甲 A5（全 Core 域）、乙 B2（Features/DeepFlow/doQry/VCL 在途）**文件零重叠**。

## 〇、开工纪律（违者整单打回）

1. **H15 原子提交**：本单仅 1 条缺陷，提交 message 带 `B7-R09`；显式 pathspec，前后 `git diff --cached --name-only` == 申报清单；**禁 push**。
2. **两重开工前置（未满足不得动手）**：① 乙线不并发两单——B2（✅ ACCEPTED `c5d6658`）与 B8（✅ ACCEPTED，结论 `CodeReview/20260926-AUDIT-主控-乙-B8-验收结论.md`）均已收口，**乙线当前零在途单，本前置已达成**；② 甲 **A5-R09 甲段已交付且符号在 HEAD 可见**——**截至派发（2026-09-28）仍未达成**：派单即启程，允许只读准备（`rg` 清单核对、`VerifyTime`/`GetCorrectedNow` 调用链 trace、既有 License fixture 子集基线预留），**禁止任何代码改动与提交**；待甲 A5-R09 符号在 HEAD 可见后，开工第一步 `rg` 核对甲交付回执点名的符号名与签名，核对通过才可动手；核对不上 ⇒ 停机上报，**禁止按猜的符号硬接**。
3. **禁动区维持**：`v1.1.0` 标签 / EHAI 冻结面 / `TestResults/**` / 旧轨 `Core/DeepBase.PluginManager.pas` / 新轨 `DeepBase.Plugins.*`；**本单不得改任何 Core 文件**（Core 侧归甲 A5；发现 Core 侧 API 不足 ⇒ 停机上报主控，不许越域代改）。
4. **行号漂移警示**：只按符号定位，不照抄本单线索行号（Licensing.pas 在乙 B2 期间是否被动过以 `git log -1 -- Features\DeepBase.Licensing.pas` 为准）；找不到符号 ⇒ 报「已不成立」取证，不许绕。
5. **测试**：配 DUnitX 回归（**自建新 test 单元文件**，不改 `Tests/DeepBaseTests.dpr`/.dproj 注册——归主控收口）；全量 run 崩 216 是既存问题，**禁止用全量当判据**，用全限定 `<单元>.<Fixture>` fixture 子集。
6. **编译判据**：隔离 `--detach` 工作树 @ 目标 commit EXIT=0；主树红项逐件点名归属（基线红项名单见 A2 验收结论 §一，不得新增红）。
7. **fail-closed 总原则**：时间不可信 ⇒ 拒绝/显式失败，**禁止兜底 `Result := Now` 放行**；资金/安装/证据同规。老板口径「质量优先于兼容，允许 breaking change」。
8. **编码/行尾**：`.pas` 四门交付树复跑全 EXIT=0；中文字面量 UTF-8 BOM；探针不入扫描面（`.dpr.template` 别名）。

## 一、修单：B7-R09 [待修] Licensing 裸 Now 分叉 + GetCorrectedNow fail-open 兜底

### 代码事实（甲 A4-08 trace T1..T7，主控复算）

- 仓内确有回拨防护 `Features\DeepBase.TimeGuard.pas`（`tgClockRewound` / `GetCorrectedNow` / `SaveLastKnownGoodTime`），但 `rg` 全仓仅 2 文件引用它：TimeGuard 自身与 `Features\DeepBase.Licensing.pas`——**挂了没用上**。
- `Features\DeepBase.Licensing.pas` 试用判定用裸 `Now`（按符号 `rg -n "TTimeZone.Local.ToUniversalTime\(Now\)" Features\DeepBase.Licensing.pas` 定位，甲 trace 记 :689/:690，2026-09-28 实测为 `:689` 一点），与 Core 的 `TLicenseInfo.IsExpired`（甲 A5-R09 已修）**各用各的时间源** ⇒ 双轨时钟。另实测 `Licensing.pas` 全文 `\bNow\b` 共 4 处：`:689`（判时）、`:837`（兜底）、`:968`/`:974`（超时测量的 `StartTime`/`SecondsBetween`，非判时用途，静态自证时按纪律逐条说明理由）。
- fail-open 兜底点实测三处（2026-09-28 派发时定位）：`Features\DeepBase.Licensing.pas:837`（`TDeepLicensing.GetCorrectedNow` 未验证兜底裸 `Now`）、`Features\DeepBase.Licensing.pas:845`（`TDeepLicensing.IsTimeTrusted` 未验证默认 `Result := True`）、`Features\DeepBase.TimeGuard.pas:467`（`TTimeGuard.GetCorrectedNow` 未验证兜底裸 `Now`）⇒ 回拨后时间不可信反而放行。前两处在本单 Licensing 单文件范围内必修；第三处**只读登记**——Licensing 侧 fail-closed 后该分支应随之不可达，若实测仍可达 ⇒ 接线不完整，回头补 Licensing 侧守卫（**仍不改 TimeGuard**）。
- `VerifyTime` 的结果**未接入任何过期判定链**；`Tests/` 对回拨零覆盖。

### 修法（乙段）

1. **接线**：Licensing 内全部判时点（先用 `rg -n "\bNow\b" Features\DeepBase.Licensing.pas` 列全清单再逐点改）统一走甲 A5-R09 交付的 Core 侧时间源符号（以甲回执点名 + 开工 `rg` 核对为准），消灭「Licensing 裸 Now vs Core IsExpired」双轨。
2. **去 fail-open**：`GetCorrectedNow` 时间未验证时**不得兜底裸 Now**；按 fail-closed 明确失败（抛具体异常或返回不可信标记，由调用链拒绝许可），选取形态写进提交说明。
3. **VerifyTime 入链**：`VerifyTime`/`IsTimeTrusted` 结果接入试用/许可过期判定；检测到回拨（`tgClockRewound`）⇒ 许可判不可用，不放行。
4. **下游只读**：`VCL\DeepBase.VCL.{LicenseStatusPanel,LicenseAuthDialog}.pas`、`FMX\DeepBase.FMX.LicenseStatusPanel.pas`、`Tools\Studio\Forms\Studio.LicenseForm.pas`、`Features\DeepBase.Unlock.pas`、`Examples\FullDemo` **本单不碰**；若修法迫使它们的调用签名变更 ⇒ 停机上报主控再议，不许顺手改。

### 判据（可执行）

- **单测（新单元，假时钟注入）**：① 到期许可 + 假时钟回拨 30 天 ⇒ 端到端仍判不可用（续命失败）；② 回拨且 `VerifyTime` 失败 ⇒ `GetCorrectedNow` **不返回裸 Now**（断言 fail-closed 行为）；③ 时间可信路径下试用/许可判定与修前一致（无过紧回归）。
- **静态自证**：改后 `rg -n "\bNow\b" Features\DeepBase.Licensing.pas` 判时点清零（仅剩非判时用途须逐条在回执说明理由）。
- **不回归**：既有 License 相关 fixture 子集（`rg -ln "License" Tests\*.pas` 自列）逐个全限定名跑，基线比对留档。

### 破坏面

`Features\DeepBase.Licensing.pas` + 本单新测试单元；下游 UI/Unlock 面只读依赖。Core 侧符号由甲 A5-R09 提供，**本单零 Core 改动**。

## 二、输出物与验收

- 回执：`CodeReview/20260925-AUDIT-乙-B7-交付回执.md`（判据跑录、`Now` 清零自证、签名核对记录、回归基线比对）。
- 证据：`CodeReview/20260925-AUDIT-乙-B7-证据/`（单测日志、隔离树编译日志；探针继续 `.dpr.template` 别名）。
- 验收：主控亲跑判据（假时钟回拨用例 + fail-closed 断言）+ 亲读 diff + 四门复跑 + 隔离树编译对照基线；**乙自报不作为验收依据**。
- 衔接纪律：甲 A5-R09 未落地不得开工；开工先核符号；B2 收尾验收前不得开工。

*主控 · 2026-09-25 签发 · **2026-09-28 正式派出**（重锚 HEAD `2dcd1ae`，前置①已达成、前置②维持硬门槛：只读准备可、动手待 A5-R09 符号）；本单为 A4-R09 跨层拆分的乙段，范围收敛为 Licensing 单文件，越界改动一律打回*

> **2026-09-28 主控复核解门（前置②已达成）**：甲 A5-R09 已交付（`1f3f9dd`），`TDeepBaseTimeSource` HEAD 在册（`Core/DeepBase.TimeSource.pas`：`Shared` / `Now` / `SetNowFunc` / `SeedWatermark` / `Reset` / `LastSeen` / `RollbackCount` / `MaxRollbackSeconds`），且 `Core/DeepBase.License.pas:194/201/367/488`、`Core/DeepBase.KeyManager.pas:324/332/359/380/402/564` 已接线（`TDeepBaseTimeSource.Shared.Now` / `SeedWatermark`）——Core 侧判时点裸 `Now` 已消。乙按 §〇-2 开工第一步 `rg` 核对甲回执点名的符号名与签名，核对通过才可动手；核对不上 ⇒ 停机上报，禁止按猜的符号硬接。B10（Commerce 时区修复）排本单之后。
