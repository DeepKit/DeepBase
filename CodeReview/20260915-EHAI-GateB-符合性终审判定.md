# Gate B｜EHAI Language Common Contract → Delphi / DeepBase / HB 符合性终审判定

- **判定人**：Amy（沈予安）· 独立审计（不采信任何开发自述，全部回到 SSOT / 源码 / 测试 / 原始证据 / Git object 取证）
- **判定日期**：2026-09-15
- **审计基线**：`fc213b4696d92bc8a836ef644abaeb74f0daa79e`（R5，HEAD）
- **工单性质**：只判定，不开发、不整改、不重开 R2～R5

---

## 最终判定

```
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   Gate B = PASS WITH NON-BLOCKING FINDINGS                   ║
║                                                              ║
║   Language Common Contract                                   ║
║   → Delphi / DeepBase / HB                                   ║
║   Conformance Established                                    ║
║                                                              ║
║   AsWish Gate C               = UNBLOCKED                    ║
║   AXIS L7 Conformance / Gate C = UNBLOCKED                   ║
║   （本判定不替下游 Gate C 判 PASS）                            ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

非阻断发现 6 项（§五），无一触及契约语义，无一需要重开 R2～R5。

---

## 一、权威基准核对（SSOT ↔ Mirror）

| 文件 | SSOT SHA256 | Mirror SHA256 | 差异 |
| :--- | :--- | :--- | :--- |
| `EHAI-Language-Common-Layer-Overview.md` | `409c5f2488e3f366…` | `07b165aed14636f7…` | 仅 7 行头部标识 |
| `EHAI-Language-Neutral-Realization-Contract-v0.md` | `661bbb0c136dfddf…` | `e7b2101d59cc8e45…` | 仅 7 行头部标识 |

差异全部为 `CANONICAL SSOT` ↔ `MIRROR / NON-AUTHORITATIVE COPY` 头部横幅与权威地位声明行，**正文逐行一致**。

```
SSOT ↔ Mirror 漂移 = 无
→ 不触发 HOLD 条款
```

---

## 二、十项语义逐项符合性矩阵

每项按 `Common Semantic → Contract Requirement → Delphi Representation → HB Realization → Test Evidence → Conformance` 建链。**判定依据是语义等价（Semantic Equivalence），不是类名相同**（§五）——HB 使用自有 `cak*`/`cs*` 形式，桥接经 `THbChoiceAction` 直接复用 EHAI 公共枚举（`TEhaiOverrideKind` / `TEhaiSource` / `TEhaiInvolvementProfile`），单一类型定义源。

| # | 语义 | 契约条款 | Delphi 表示 | HB 实现 | 测试证据 | 判定 |
| :--- | :--- | :--- | :--- | :--- | :--- | :---: |
| 1 | **CandidateSpace** | §2.1 | `TEhaiCandidateSpace`：`AddOption` 对 `Key>7` 直接拒绝；`CreateBounded` 只收 1..7 | VCL/FMX Deck + `csNoReliableCandidates` 态 + `SetNoReliableCandidates` | TierA CSV-001（10 项输入收敛至 7）＋ TTestHbSuite `Truthful_State_Transitions` | ✅ |
| 2 | **RecommendedMark** | §2.1 | `IsRecommended` / `RecommendedKey`（最多 1 项） | `AddOption(AIsRecommended)` | CSV-001 断言 2–3（1 号槽位有标记；标记不附带自动承诺） | ✅ |
| 3 | **CandidateSelection** | §2.2 | `emaChoose` + `SelectedKeys[]` + `TEhaiCardinality`(ecSingle/ecMultiple)；action 构造时 `AuthorityBasis` 清零 | `cakCandidate` + `SubmitMultiChoice` | CSV-002/003 ＋ HBV003（多选 toggle、提交分界） | ✅ |
| 4 | **Regenerate** | §2.3 | `emaRegenerate`（Key=8），无授权域、无承诺字段 | `cakRegenerate` + `csRegenerating` + **参照保持**（重生成中 Items 保持装载，HBV002 明断言） | CSV-004 ＋ HBV002 | ✅ |
| 5 | **HumanOverride (9)** | §2.4 | `emaReframe`（Key=9）+ `TEhaiOverrideKind` 三态 | `cakFreeInput` + `EnterFreeInput` / `SubmitFreeInputWithKind` + **通道主权**（自由输入态快捷键挂起，HBV001 明断言 `FLastChoiceKey = -1`） | CSV-005 ＋ HBV001 | ✅ |
| 6 | **FrameRejection** | §2.5 | `eokFrameRejection` 独立枚举成员（≠ eokCandidateReject ≠ eokAlternativeExpression）；Source 强制保持 | 显式通道 `SubmitFreeInputWithKind(…, eokFrameRejection)`；遗留 `SubmitFreeInput` 一律 `eokNone` 不代分类 | CSV-007（MetaAction≠emaChoose、Source 必须 esHuman、防静默重映射）＋ HBV001 显式路径断言 | ✅ |
| 7 | **BackNavigation (0)** | §2.6 | `emaExit`（Key=0）独立成员 | `cakBack` 独立 action kind（≠ 任何 reject/commit kind） | CSV-003 断言 3（0/8/9 不参与业务多选勾选）＋ HBV005 | ✅ |
| 8 | **SourceDistinction** | §4.1–4.2 | `TEhaiSource` 6 值（Human/AI/Inferred/Rule/Tool/System）——契约明文允许等价分类编码 | **物理输入层与认知来源层分离**：`THbChoiceInputSource`(cisKeyboard/cisNumPad/cisMouse) ≠ `TEhaiSource`(esHuman/esAI) | CSV-006（双 trace、Actor 可区分）＋ HBV004（三输入设备语义等价且 InputSource 各自保真） | ✅ |
| 9 | **CommitmentBoundary** | §3.1–3.3 | `TEhaiAuthorityBasis` 四种合法授权形态（Explicit/Prior/Standing/Rule）+ `Covers()` **空 Scope fail-closed** + `ValidateCommitment` 原语 | —（门禁效力判定属产品绑定层，公共层只提供判定原语——正确的职责下沉） | CSV-008（空 scope 三连 fail-closed、过期失效、跨 scope 拒绝、效果分类互异） | ✅ |
| 10 | **RecoverableLineage** | §4.3 | `TEhaiTraceRecord`（TraceId/Source/Actor/Action/Effect/IsCommitted/RecordedAt）+ `TEhaiContextBinding` + `EhaiCheckContextDrift` + `IEhaiSourceTraceable` | — | CSV-006（Source/Actor/Context 可按范围恢复） | ✅ |

---

## 三、语义边界审计矩阵（§三）

| 边界不变量 | 在实现中的体现 | 测试证据 | 判定 |
| :--- | :--- | :--- | :---: |
| **Capability ≠ Authority** | action 记录构造（能力）不携带任何授权；授权是独立信封 `TEhaiAuthorityBasis`，须经 `Covers()` 判定 | CSV-008（空 scope/过期/跨 scope 全部拒绝） | ✅ |
| **Human-stated ≠ Human-authorized** | `esHuman` 来源 ≠ 授权基础；`CreateCandidate` 明确将 AuthorityBasis 清零——人类来源的动作默认无授权 | CSV-002 ＋ CSV-008 | ✅ |
| **Preference ≠ Judgment** | `eipProvide` ≠ `eipJudge`；`eseDataProvided` ≠ `eseJudgmentMade` | 类型分离 ＋ CSV-008 效果分类互异断言 | ✅ |
| **Judgment ≠ Authorization** | `eipJudge` ≠ `eipAuthorize`；`eseJudgmentMade` ≠ `eseAuthorized` | CSV-002 明断言 `AreNotEqual(eipAuthorize)` ＋ CSV-008 | ✅ |
| **CandidateSelection ≠ Inherent Commitment** | choose 动作不带承诺字段；效力由 Profile+Context 下游决定 | CSV-002/003 | ✅ |
| **8 Regenerate ≠ Human Judgment** | `emaRegenerate` 独立成员，无判定/授权字段 | CSV-004 | ✅ |
| **9 HumanOverride/Reframe ≠ Reject** | `emaReframe` 独立于任何 reject 语义；框架否定走高保真保留通道 | CSV-005/007 | ✅ |
| **0 Back/Exit ≠ Reject ≠ Consent ≠ Judgment** | `emaExit` / `cakBack` 均为独立成员 | CSV-003 ＋ HBV005 | ✅ |
| **0 ≠ Consent / 0 ≠ Judgment** | 同上；exit 动作不携带任何效力字段 | HBV005 | ✅ |
| **Human Source ≠ AI Interpretation** | `esHuman` ≠ `esAI`；trace 双轨可区分（ActorIdentity 分立） | CSV-006 | ✅ |
| **Candidate Rejection ≠ Alternative Expression ≠ Frame Rejection** | `eokCandidateReject` / `eokAlternativeExpression` / `eokFrameRejection` 三个独立成员，各有独立断言 | CSV-005（三态分别构造并断言）＋ CSV-007 | ✅ |

---

## 四、公共层污染检查（§四）

| 检查范围 | 命中 | 判定 |
| :--- | :--- | :--- |
| `Core/DeepBase.EHAI.Types.pas`（公共语义层） | **零命中**（SpecNode/ChangeSet/Requirement/Contact/Relationship/Customer/Touchpoint/Tag/Remark/微信/AsWish/AXIS/唤金 全部 0） | ✅ 无污染 |
| `Core/DeepBase.HB.Choice.Types.pas` + VCL/FMX Choice（公共 API 契约面） | **零命中** | ✅ 无污染 |
| `VCL/DeepBase.VCL.HB.Choice.Demo.pas` | 示例文案出现 `Contact List Compact`（Demo 展示场景） | 依工单 §四「示例文本不自动构成污染」**不判问题**；建议换中性文案避免与 AXIS 业务词撞名（见 N-5） |
| `THbChoiceItem.Tag: NativeInt` | Delphi UI 惯例的 payload 句柄字段，非 AXIS 业务 Tag/Remark | ✅ 不构成污染 |
| HB `Touchpoint.*` 单元 | 属 HB 自有表层基础设施（UI 触点），不在 EHAI Choice 语义契约面内 | ✅ 不构成污染 |

---

## 五、非阻断发现（6 项，均不触及契约语义）

| # | 发现 | 位置 | 建议 |
| :--- | :--- | :--- | :--- |
| N-1 | `TEhaiAuthorityBasis.Covers()` 允许显式通配 `ScopeBoundary='*'`（空 Scope 已 fail-closed，但 `'*'` 即全授权） | `Core/DeepBase.EHAI.Types.pas:357` | 下游 Gate C 必须证明产品绑定**不从不可信输入接受 `'*'`**；公共层可考虑对 `'*'` 授权增加审计日志 |
| N-2 | `CreateBounded` / `AddOption` 对 Key>7 **静默丢弃**——收敛被强制但截断无声 | `:427-431, :439-440` | 契约只要求呈现时 ≤7，语义不违；建议下游在收敛发生时留痕，避免上游未收敛被掩盖 |
| N-3 | `AddOption` 不查 Key 重复，重复时 `FindByKey` 返回首个 | `:434-448` | 健壮性注记；下游构造空间时应自行保证 Key 唯一 |
| N-4 | `Covers()` 内部取 `Now`，时钟不可注入 | `:350` | 可测试性注记；如需 Deterministic 测试可加重载 |
| N-5 | Demo 单元示例文案 `Contact List` 与 AXIS 业务词撞名 | `VCL/…Choice.Demo.pas:7,202` | 换中性示例文案（非必须） |
| N-6 | `IsValidAt` 以 `ExpiresAt=0` 表示无期限——对 Standing Authorization 合法，但下游须显式区分「未设置」与「永不过期」 | `:341-346` | 下游 Gate C 自查项 |

---

## 六、证据基础与独立性声明

| 证据 | 取证方式 | 状态 |
| :--- | :--- | :--- |
| SSOT ↔ Mirror | 逐字节 diff + SHA256 双算 | 正文零漂移 |
| 公共语义层源码 | 通读 692 行全文（`Core/DeepBase.EHAI.Types.pas`） | 本判定直接引用行号 |
| Tier A/B 一致性测试 | 提取全部断言清单（8+5 用例逐断言核对） | 断言与 CSV-001~008 一一对应 |
| HB 表层实现 | VCL/FMX Choice + HB Choice Types 通读关键桥接 | 语义等价而非标识符等价 |
| 全量回归 50/50 | `TestResults/WO-20260914-EHAI-001R2/tests-full-r2.xml`（10,317 B）——本审计方此前已用 ElementTree **独立解析**：TierA 8 / TierB 5 / TTestHbSuite 37，非 Success = 0 | 与 Manifest 指纹 `677e9582…` / `3998fda3…` 一致 |
| 构建 | R3 日志 43,595 B（SHA256 `3055cafa…`）：14/14 包、0 Error、144 Warning、声明在第 425–431 行 | 已独立复算 |
| 代码冻结链 | EHAI 相关源与测试自 `2208973`/`3c48daf`/`cca652c`（09-14 19:16）后**未再变动**；R3~R5 三个提交仅触文档/证据/清单 | Git log 逐文件核实 |
| 符号基准连续性 | `docs/EHAI-Delphi-Symbol-Baseline.md` 登记 `de9a3208…` / `963fedd0…` ＝ 当前源码实测值**逐字符一致** | 审计对象与两产品登记的基准为同一字节态 |
| 证据覆盖性 | `66ba6f6` 是 `fc213b4` 的祖先 → R2 回归证据覆盖当前测试代码 | `git merge-base --is-ancestor` |

R2～R5 历史工单未重审；其基础证据（测试 XML、构建日志、Git object）经本次独立复核**全部有效**，无失效情形。

---

## 七、判定依据小结

公共契约的十项语义、十一组边界不变量，在 Delphi 公共层有**真实类型承载**、在 HB 有**表层实现**、在测试中有**可复算断言**，且证据链（原始 XML / 原始日志 / Git object / SHA256 指纹）经本审计方独立复算全部吻合。公共语义层对产品领域词**零吸收**。未发现任何需要重开工单的语义失真。

```
Language Common Contract → Delphi / DeepBase / HB
Conformance Established

Gate B = PASS WITH NON-BLOCKING FINDINGS
（N-1～N-6 转入下游 Gate C 自查清单，不阻断）
```

---

*本判定每一项均来自 SSOT / 源码 / 测试断言 / 原始证据 / Git object 的独立取证，未采信任何开发报告自述。*
