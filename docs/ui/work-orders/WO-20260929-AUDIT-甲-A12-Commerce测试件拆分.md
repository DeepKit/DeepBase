# WO-20260929-AUDIT-甲-A12 `Test.DeepBase.Commerce.pas` 拆分（P3 · 1 项）

> 签发：主控 · 2026-09-29 · 排队态：甲线后位（A10/A11 在途；不与他线争文件）
> 基线锚点：开工时 HEAD（主控在派工消息中重锚）
> 派工对象：**开发 AI 甲**
> 缺陷来源：《20260929-AUDIT-主控-乙-B10-验收结论》§三派生表第 3 行（B10 回执 §五.6 末条）

## 〇、开工纪律

1. **H15 原子提交**：1 项 1 笔，message 带 `A12`；显式 pathspec；前后 `git diff --cached --name-only` == 申报清单；**禁 push**；台账状态槽不碰（归主控）。
2. **禁动区维持**：`v1.1.0` 标签 / EHAI 冻结面 / `TestResults/**` / 新旧 PluginManager 轨 / `contracts/**` / `noise-baseline.json` / `Core/**` / `Features/**`（本单只动 `Tests/**`）/ `Tests/DeepBaseTests.dpr|.dproj`（**拆分后的 dpr 登记归主控**，本单不碰）/ `ThirdParty/**` / `Scripts/**`。
3. **fixture 总数与用例集合逐字不变**：拆分前后 found/pass 计数、用例限定名清单、失败集合三者必须完全一致（拆分是纯搬迁，不是重写）。既有断言**一字不改**。
4. **测试纪律**：全限定子集跑（`bash CodeReview/20260925-AUDIT-乙-B2-证据/b2_run_fixture.sh <单元>`）+ 主套件 exe 同进程跑（`--run` 限定名）；**禁全量 run**（必崩 216 既存）。
5. 编码/行尾：`.pas` UTF-8 BOM + CRLF；DUnitX 注册惯例照仓内同形（`Tests/Test.DeepBase.License.pas` 附近样本）。

## 一、修单与判据

### 代码事实

`Tests/Test.DeepBase.Commerce.pas` 现 **2471 行**（`3a5e8ae` 后），超 AGENTS.md 的 2000 行结构审查线；单一 fixture `TCommerceServiceTests` 承担 68 例。B10 工单明文要求「新增断言落在已注册 fixture 内」故未拆，现由本单收口。

### 修法（主控已定型：按四职责垂直拆）

| 新单元 | 搬迁内容 | 目标行数 |
|---|---|---|
| `Tests/Test.DeepBase.Commerce.pas` | Service 流程面（下单/支付/授权链）+ 时间框架 6 例 | ≤ 800 |
| `Tests/Test.DeepBase.Commerce.SafeClient.pas` | SafeClient 线协议面（快照/签名/重试/退避） | ≤ 700 |
| `Tests/Test.DeepBase.Commerce.Permissions.pas` | Permissions 判定面（宽限/配额/权限） | ≤ 500 |
| `Tests/Test.DeepBase.Commerce.Types.pas` | 纯函数面（枚举/ID/线格式/时间框架单测） | ≤ 500 |

- 助函数（`FixedAnchorLocal`/`InjectFixedClock`/`UtcIso`/`SnapshotJsonExpiringAt`/`ActiveEntitlementExpiringAt`/`RegisterProduct`/`EnsureUser` 等）按归属搬到目标单元，**被跨面共用的助函数放 `Types` 件并 use 引入**，不许复制两份。
- `[TearDown]` 的假时钟还原逻辑搬到每个含时间框架用例的新单元，**逐单元都要有**（B10 验收证明单例泄漏会让同进程别人读到 2031 年）。
- 新单元在各自 `initialization` 段注册本单元 fixture。
- **不得**改变任何断言语义、不得合并/删除用例、不得顺手改生产代码。

### 判据

1. **计数守恒**：四个新单元全限定逐单元跑 + 合并同进程跑，found/pass/fail/error 与拆分前主控留档值（`68/68/0/0` @`3a5e8ae`）**逐字相等**；用例限定名清单 `diff` 为空。
2. **同进程无泄漏**：拆分后四单元同进程混跑 `Tests Leaked: 0`（时间框架用例散在多个单元，泄漏风险比拆分前更高，必须实测）。
3. **dpr 归主控**：本单**不碰** `Tests/DeepBaseTests.dpr|.dproj`；验收后由主控登记四单元并复跑 T0（登记前后 Hint/Warning 逐码不变是主控判据）。
4. **编译**：四单元逐单元 `BUILD_EXIT=0`；主套件 exe（旧清单态）编译不受影响。
5. **四门**：encoding / eol / mojibake / evidence-encoding 全 EXIT=0。

## 二、不在本单（已登记）

- `Test.DeepBase.Commerce.PaymentBridge` 的零断言用例 ⇒ 乙 B13-04。
- 新单元命名若非 `Test.DeepBase.Commerce.*` 会与既有 `Test.DeepBase.Commerce.Adapter.Firebase` 等混淆 ⇒ 若你认为需要不同前缀，**先停机上报**，不许自行定名。

*主控 · 2026-09-29 签发 · 纯搬迁单，判据核心是「守恒」；任何用例集合漂移即整单打回*
