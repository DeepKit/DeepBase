# WO-20260928-AUDIT-甲-A8 LicenseSecret 测试假覆盖注册修补（1 项）

> 签发：主控 · 2026-09-28
> 基线锚点：HEAD `ca4c9a1`
> 派工对象：**开发 AI 甲**
> 来源：乙 B7 停等期只读准备发现（`CodeReview/20260925-AUDIT-乙-B7-证据/B7-停等期只读准备与停机上报.md` §四.3）+ 主控实测复核坐实（结论 `CodeReview/20260928-AUDIT-主控-乙-B7-准备期裁定.md` §二.3）；与平行线 `WO-20260928-TESTDEBT-甲-001`（HB Gate6 / Timeout PBT）**零重叠**。
> 状态：🟡 待排——甲线串行，**A5 交付验收通过后**开工。

## 〇、开工纪律（违者整单打回）

1. **H15 原子提交**：单笔提交，message 带 `A8`；显式 pathspec，前后 `git diff --cached --name-only` == 申报清单；**禁 push**。
2. **禁动区维持**：`v1.1.0` 标签 / EHAI 冻结面 / `TestResults/**` / 旧轨 `Core/DeepBase.PluginManager.pas` / 新轨 `DeepBase.Plugins.*`；本单**只动 `Tests/Test.DeepBase.LicenseSecret.pas` 一个测试单元文件，零生产代码**；`Tests/DeepBaseTests.dpr`/.dproj **不改**（注册收口归主控，且 dpr uses 已在册，本条不涉及）。
3. **测试纪律**：全量 run 崩 216 是既存问题，**禁止全量当判据**；用全限定 `<单元>.<Fixture>` fixture 子集。
4. **fail-closed**：只补注册，不改测试断言逻辑；若补注册后用例本身红 ⇒ 与修前基线不符，停机上报，不许顺手改断言「修绿」。

## 一、修单：A8-01 [待修] Test.DeepBase.LicenseSecret 假覆盖

- **代码事实（主控实测，乙 B7 独立同判）**：`Tests/Test.DeepBase.LicenseSecret.pas` 有 `[TestFixture]`（`:20`）与 2 个 `[Test]`，但单元内**无 `initialization ... RegisterTestFixture(...)` 调用**——全仓 **303** 个测试单元均有此调用（惯例样本 `Tests/Test.DeepBase.License.pas:414 TDUnitX.RegisterTestFixture(TTestDeepBaseLicense);`），唯此单元漏登记 ⇒ 一次性 runner 实测 `RUN_EXIT=2 / No Test Fixtures found`；而该单元在 `Tests/DeepBaseTests.dpr` uses 面内（`rg -c` = 1）⇒ **挂着名、永不执行，假覆盖**（乙报告「全仓无此惯例」一语不准确：惯例存在，是本单元漏，已由主控在裁定件更正）。
- **修法**：按仓内惯例补 `initialization` 段注册调用 `TDUnitX.RegisterTestFixture(TTestLicenseSecretFailClosed);`（类名/单元名以文件内实测为准，开工先 `rg -n "TestFixture\|= class" Tests/Test.DeepBase.LicenseSecret.pas` 核对）。
- **判据**：全限定 `Test.DeepBase.LicenseSecret.TTestLicenseSecretFailClosed` runner 实测 **2 found / 2 pass / RUN_EXIT=0**（修前基线：0 注册，见 `B7-1-License-fixture基线.txt`）；`git diff` 自证只改该单元、`DeepBaseTests.dpr`/.dproj 零改动。
- **输出物**：回执 `CodeReview/20260928-AUDIT-甲-A8-交付回执.md`（跑录、diff 自证）；验收由主控全限定复跑 + 亲读 diff。

*主控 · 2026-09-28 · 签发即生效，待排（A5 后）；本单是全量套件假覆盖债务第 3 条，第 4 条（CommerceE2E）派乙 B9*
