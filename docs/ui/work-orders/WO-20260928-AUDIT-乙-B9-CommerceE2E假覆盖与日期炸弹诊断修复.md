# WO-20260928-AUDIT-乙-B9 CommerceE2E 假覆盖与日期炸弹诊断修复（1 项）

> 签发：主控 · 2026-09-28
> 基线锚点：HEAD `ca4c9a1`
> 派工对象：**开发 AI 乙**
> 来源：乙 B7 停等期只读准备发现（`CodeReview/20260925-AUDIT-乙-B7-证据/B7-停等期只读准备与停机上报.md` §四.3）+ 主控实测复核坐实（结论 `CodeReview/20260928-AUDIT-主控-乙-B7-准备期裁定.md` §二.3）；与平行线 `WO-20260928-TESTDEBT-甲-001`（HB Gate6 / Timeout PBT）**零重叠**。
> 状态：🟡 待排——乙线串行，**B7 交付验收通过后**开工。

## 〇、开工纪律（违者整单打回）

1. **H15 原子提交**：单笔提交，message 带 `B9`；显式 pathspec，前后 `git diff --cached --name-only` == 申报清单；**禁 push**。
2. **禁动区维持**：本单**只动 `Tests/Integration/Test.Integration.CommerceE2E.pas` 一个夹具文件**（+ 必要新断言），**零生产代码**；`Tests/DeepBaseTests.dpr`/.dproj **不改**——注册收口归主控，且**绿了才注册**（见 §一判据）。
3. **诊断优先**：先查清「为何全量套件不跑它」再修日期炸弹；禁止把「没注册」当「已通过」，禁止删/跳过用例粉饰。
4. **测试纪律**：全量 run 崩 216 是既存问题，禁止全量当判据；用全限定 fixture 子集；过期态断言必须**不随真实日期漂移**（固定相对基准）。

## 一、修单：B9-01 [待修] CommerceE2E 双重假覆盖（未注册 + 日期炸弹）

- **代码事实（主控实测，乙 B7 独立同判）**：`Tests/Integration/Test.Integration.CommerceE2E.pas` 有 `[TestFixture]`（`:17`）与唯一用例，但：
  ① **不在 `Tests/DeepBaseTests.dpr` uses 面**（`rg -c` = 0；dpr 无任何 `Test.Integration` 条目）⇒ 2026-09-28 21:22 审计全量跑录（4679 found；F1=Gate6、F2=Timeout PBT AV）里它**根本没跑**——「全量不现红」与「乙单跑现红」的矛盾由此解释：不是全量绿，是全量没跑；
  ② 夹具硬编码 `"expires_at":"2026-06-08T10:00:00Z"`（`:120`）早于今日 ⇒ 乙单跑实测 `1 error / License snapshot has expired`——日期炸弹型既存红。
- **修法**：
  1. **诊断留档**：`git log -- Tests/DeepBaseTests.dpr` 等溯源 Integration 面去向（历史排除原因：环境依赖？编译问题？）；若曾因环境依赖被排除，在回执写明环境前提；
  2. **修日期炸弹**：夹具寿命改**相对基准**（以运行时刻推算 issued/expires，覆盖「在用」态），主路径恢复可执行；
  3. **负向断言转正**：保留/新增一条**固定过去日期**的过期许可用例，显式断言系统按过期拒绝——把「炸弹」转成永不过期的回归；
  4. **注册建议**：回执给出本单元是否建议收口进 `DeepBaseTests.dpr` 的意见（由主控裁定执行，乙不改 dpr）。
- **判据**：修后全限定 `Test.Integration.CommerceE2E.TCommerceDesktopE2ETests` runner 实测 **pass**（含新负向断言）；过期态断言稳定（不随真实日期漂移）；`git diff` 自证只改该夹具、`DeepBaseTests.dpr`/.dproj 零改动。
- **边界**：只动本夹具；诊断中若发现**生产侧**对过期许可的处理也有缺陷 ⇒ 停机上报主控，不顺手改生产代码。
- **输出物**：回执 `CodeReview/20260928-AUDIT-乙-B9-交付回执.md`（诊断结论、跑录、diff 自证、注册建议）；验收由主控全限定复跑 + 亲读 diff + 裁定是否收口注册。

*主控 · 2026-09-28 · 签发即生效，待排（B7 后）；本单是全量套件假覆盖债务第 4 条，第 3 条（LicenseSecret）派甲 A8*
