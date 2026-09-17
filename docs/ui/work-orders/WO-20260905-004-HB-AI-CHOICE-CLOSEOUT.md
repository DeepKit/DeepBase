# 工单 WO-20260905-004 · HB AI Choice 选择式交互标准收口入库（罗辑）

> **指派对象**：开发甲（software-tools / 主编码代理）
> **性质**：规约化收口 + 单次精确 commit
> **基线**：WO-20260905-003 已 CLOSE；工作区 AI Choice 代码与规范文档已完成待入库
> **规范法源**：`docs/ui/DeepBase-HB-AI-Choice-Interaction-Standard.md` v1.0 · `docs/31.hb-test.md` v1.1

---

## 背景（现状，主控已核实）

1. WO-20260905-003（Gate #5 Resize + Dispose 债务）已提交为 `380ff13`，主控审核结论为 PASS_WITH_FINDINGS（G1 构建日志补交、G5 全量套件空档说明待补）。
2. 工作区现存 AI Choice 全套实现与规范文档，`TestResults/UnitTestResults.xml` 显示 37/37 全绿，但未纳入工单管理，未提交版本控制。
3. 关联文件清单（不全提交）：
   - `Core/DeepBase.HB.Choice.Types.pas`
   - `VCL/DeepBase.VCL.HB.Choice.pas`
   - `VCL/DeepBase.VCL.HB.Choice.Demo.pas`
   - `FMX/DeepBase.FMX.HB.Choice.pas`（未跟踪）
   - `Tools/FMXGallery/hbtheme_fmx_gallery.dpr`
   - `Tests/Test.DeepBase.HB.Suite.pas`
   - `docs/ui/DeepBase-HB-AI-Choice-Interaction-Standard.md`（未跟踪）
   - `docs/ui/DeepBase-HB-x-HuanJin-UI-Capability-Gap-Analysis.md`（未跟踪）

## 任务

1. **提交收口**：将上述所有 AI Choice 相关源码、测试、文档纳入一次精确 commit，禁止搭车修改。
2. **证据归档**：将 `TestResults/UnitTestResults.xml`（37 测试）及 21 包构建日志复制到 `TestResults/WO-20260905-004/` 下存档命名。
3. **回归验证**：HB 模块套件（当前 90/90）与 AI Choice 37 测试合并后全绿；若 Choice 测试已并入 HBModule，以 HBModule XML 为准并明确说明。
4. **交付报告**：`CodeReview/20260905-HB-AI-CHOICE-交付报告.md`：提交哈希、证据路径、37 测试清单、双端实现说明、规范文档索引、债务/风险节。

## 验收准则

1. `TestResults/WO-20260905-004/UnitTestResults.xml` 或等效归档文件 total=37 / failures=0 / errors=0。
2. `TestResults/WO-20260905-004/build_packages.log` 显示 21 包 0 Error / 0 Warning。
3. `git show --stat <commit>` 仅含 AI Choice 相关文件。
4. 异族模型终审通过。
5. 台账登记 CLOSE。

## 禁止事项

- 禁止修改阈值常量、规范文档 v1.0 协议编号。
- 禁止搭车提交 FMX 表面色、DEBT-20260905-001 GUID 治理、Tools/gen_ev.js 归属等本单外事项。
- 禁止 `git add -A`。

## 提交纪律

- **单次 commit**：`feat(hb): add AI Choice Deck cross-platform and freeze interaction standard (WO-20260905-004)`
- 每次 commit 前 `git status` 核对暂存清单并附交付报告。
