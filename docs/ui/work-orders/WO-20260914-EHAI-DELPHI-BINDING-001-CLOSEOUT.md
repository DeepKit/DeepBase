# 工单 WO-20260914-EHAI-001 · EHAI 语言共用层 Delphi Binding 001 交付收口

> **工单编号**：WO-20260914-EHAI-001（含整改 WO-20260914-EHAI-001R1）
> **性质**：跨语言通用契约 Delphi 绑定实现、HB 视觉承接与规约化收口
> **指派对象**：开发甲 (`software-tools`)
> **唯一上游契约**：`EHAI/common-contract/EHAI-Language-Neutral-Realization-Contract-v0.md` & `EHAI-Language-Common-Layer-Overview.md` (APPROVED ENGINEERING BASELINE v0)
> **状态**：PASS / 待主控审查入库

---

## 1. 交付概览

本工单完成 EHAI 语言共用层（Language Common Layer）在 Delphi / DeepBase / HB 分支的首次正式工程实现。通过构建语言无关语义绑定（Core）、HB 人机交互承接（VCL & FMX）以及完备的共用契约符合性套件（Conformance Suite），实现跨语言人机协同语义的统一。

```text
Language-Neutral Contract (EHAI SSOT)
        ↓
Delphi Semantic Binding (Core/DeepBase.EHAI.Types.pas)
        ↓
DeepBase Core (DeepBaseCore.dpk)
        ↓
HB Human-facing Realization (THbChoiceDeck in VCL & FMX)
```

---

## 2. 核心架构与实现

### 2.1 语义绑定层 (`Core/DeepBase.EHAI.Types.pas`)
- **介入度与角色模型**：`TEhaiInvolvementProfile`（五种人类介入形态：`eipInform`, `eipProvide`, `eipJudge`, `eipAuthorize`, `eipAct`，EHAI.04.L4 §3）, `TEhaiSource` (`esHuman`, `esAI`, `esInferred`, `esRule`, `esTool`, `esSystem`), `TEhaiMetaAction` (`emaChoose`, `emaRegenerate`, `emaReframe`, `emaExit`)。
- **四态覆写模型 (Strict Frame Rejection Quad-State)**：
  - `eokNone`：未分类（遗留入口下发默认值，上层按上下文判定）
  - `eokCandidateReject`：局部候选拒绝
  - `eokAlternativeExpression`：同框架下替代意图表达
  - `eokFrameRejection`：框架级彻底拒绝（不映射为业务属性，保护人类真实否定意图）
- **现实效应与授权基石**：
  - `TEhaiInformState` (`eisAvailable`, `eisPresented`, `eisAcknowledged`, `eisAgreed`)
  - `TEhaiSemanticEffectKind` (`eseInformOnly`, `eseDataProvided`, `eseJudgmentMade`, `eseAuthorized`, `eseActionReported`)
  - `TEhaiAuthorityBasisKind` (`eabExplicitConfirmation`, `eabPriorAuthorization`, `eabStandingAuthorization`, `eabRuleDerivedAuthority`)
  - `TEhaiAuthorityBasis`：凭据验证，空 Scope 严格 fail-closed。
- **候选空间与行动语法**：
  - `TEhaiCandidateSpace`：有界候选（$\le 7$）、无默认执行推荐
  - 语法约束：`1–7` 确定性选择，`8` 探索性重算（零写入），`9` 框架重塑/自由输入，`0` 无承诺退出（0 ≠ 拒绝, 0 ≠ 同意）
  - 单选/多选基数支持 (`TEhaiCardinality`: `ecSingle`, `ecMultiple`)
- **上下文与可追溯接口**：`IEhaiContextBound`, `IEhaiSourceTraceable`, `IEhaiInteractionContract`。

### 2.2 HB 交互承接层 (`Core/DeepBase.HB.Choice.Types.pas`, VCL/FMX `THbChoiceDeck`)
- **多选支持**：`ecMultiple` 下 `1–7` 键/点击切换勾选，`Enter` 显式确认边界；`0/8/9` 永远作为独立动作触发，不参与勾选状态。
- **三态覆写视觉分流**：`TriggerOverrideAction` 与 `SubmitFreeInputWithKind` 支持携带三态覆写类型，保持语义纯净；`SubmitFreeInput` 默认下发 `eokNone`。
- **重算探索与视觉参考保持**：Regenerate 时卡片半透明变暗叠加 Spinner，保持原有候选视觉参考可见，消除闪烁与空间迷航。
- **自由输入键盘独占**：自由输入激活时完全挂起数字快捷键（`1–9`, `0`），所有击键路由给文本框。
- **100% 向后兼容**：现有单一选择模式（`ecSingle`）与 API 行为完全不变。

---

## 3. 轻量门禁（G1–G5）验证结果

| 门禁 | 判定 | 验证指标与证据说明 | 证据文件 |
| :--- | :---: | :--- | :--- |
| **G1 构建门禁** | **PASS** | 14/14 Win64 Packages 全部通过（0 Error, 144 Warning, 0 DCU 泄露）<br>（声明：Declared All profile scope: RuntimePackages = 12 / UiPackages = 2 / Total = 14. This summary covers the declared All profile only. It does not assert that every .dpk file in the repository was built.） | `TestResults/WO-20260914-EHAI-001R3/build_packages.log` |
| **G2 性能门禁** | **PASS** | Gate #1~#7 全部绿灯（Gate #5 Resize 3.795ms $\le 16.6$ms；Gate #6 0 GDI/Heap Leak；Gate #7 0.0034ms） | `TestResults/WO-20260914-EHAI-001R1/UnitTestResults.xml` |
| **G3 契约符合性** | **PASS** | 13 项 EHAI 契约向量测试全部通过（Tier A 8/8 CSV-001~CSV-008, Tier B 5/5 HB-V-001~HB-V-005） | `TestResults/WO-20260914-EHAI-001R1/TierA-vectors.xml`<br>`TestResults/WO-20260914-EHAI-001R1/TierB-surface.xml` |
| **G4 文档与映射** | **PASS** | 机器生成 182 符号基准与上游 10 项共用契约（SRC-01~SRC-10）As-Is 映射台账完整落盘 | `docs/EHAI-Delphi-Symbol-Baseline.md`<br>`docs/Delphi-Common-Contract-AsIs-Mapping.md` |
| **G5 证据归档** | **PASS** | 50/50 全量回归测试全部通过（Tier A 8 + Tier B 5 + HB 既有 37；0 Fail, 0 Error, 0 Leak），证据齐备 | `TestResults/WO-20260914-EHAI-001R2/tests-full-r2.xml`<br>`TestResults/WO-20260914-EHAI-001R2/tests-full-r2.txt` |

---

## 4. 零业务领域渗透审计 (Zero Domain Leakage)

对 `Core/` 及 `Tests/` 全量代码执行业务领域类型审计：
- `TCandidateIntent`：0 处命中
- `TChangeSet`：0 处命中
- `TSpecNode`：0 处命中
- `Contact` / `Customer` / `Relationship` / `Touchpoint`（业务实体）：0 处命中

保证 DeepBase Core 与 HB 仅处理纯粹人机协同交互语义，业务领域类型由上层产品（AsWish / HuanJin）承接。

---

## 5. 文件变更清单

### 新增文件
1. `Core/DeepBase.EHAI.Types.pas`：Delphi EHAI 跨语言共用层语义类型系统
2. `Tests/Test.DeepBase.EHAI.Conformance.pas`：EHAI 契约符合性 13 项验证测试套件（Tier A / Tier B）
3. `Scripts/gen_ehai_symbol_baseline.py`：符号基准自动化提取与校验脚本
4. `docs/EHAI-Delphi-Symbol-Baseline.md`：182 符号基准唯一真相源文档
5. `docs/Delphi-Common-Contract-AsIs-Mapping.md`：Delphi 与 EHAI 上游契约逐项映射表
6. `TestResults/WO-20260914-EHAI-001R1/build_packages.log`：14 Win64 包编译日志与 Warning 台账
7. `TestResults/WO-20260914-EHAI-001R1/TierA-vectors.xml`：Tier A 8/8 独立向量日志
8. `TestResults/WO-20260914-EHAI-001R1/TierB-surface.xml`：Tier B 5/5 独立表面日志
9. `TestResults/WO-20260914-EHAI-001R1/UnitTestResults.xml`：13/13 测试全绿原始证据
10. `docs/ui/work-orders/WO-20260914-EHAI-DELPHI-BINDING-001-CLOSEOUT.md`：本工单收口文档

### 修改文件
1. `Packages/DeepBaseCore.dpk`：注册 `DeepBase.EHAI.Types.pas`
2. `Core/DeepBase.HB.Choice.Types.pas`：基数收敛至 `TEhaiCardinality`、补充三态覆写、语义来源及上下文接口
3. `VCL/DeepBase.VCL.HB.Choice.pas`：多选支持、三态覆写分流、`SubmitFreeInput` 默认 `eokNone`、安全焦点判定
4. `FMX/DeepBase.FMX.HB.Choice.pas`：FMX 侧对称支持多选与三态覆写分流、`SubmitFreeInput` 默认 `eokNone`
5. `VCL/DeepBase.VCL.HB.Choice.Demo.pas`：清理产品特定命名
6. `Tests/DeepBaseTests.dpr`：注册 `Test.DeepBase.EHAI.Conformance.pas`
7. `Scripts/build_packages_win64.ps1`：增强 UTF-8 日志、逐包 `[BUILD] START/OK` 标记与 `[SUMMARY]` 统计
8. `CodeReview/20260914-EHAI-DELPHI-BINDING-001-交付报告.md`：校正符号与真实门禁台账
