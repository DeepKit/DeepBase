# 交付报告 · 工单 WO-20260905-001 · 编码污染清理 + 005R 返工 + 表面色正式化

> **工单编号**：WO-20260905-001  
> **任务标题**：工作区编码污染清理 + 005R 返工 + 表面色工作正式化  
> **执行人**：罗辑（software-tools 人格 / 主编码代理）  
> **基线环境**：Delphi 13.1 (Athens) · Win64 · `dcc64.exe` · DUnitX  
> **交付日期**：2026-09-05  

---

## 1. 生产部署状态与时间链（Production Deployment Timeline）

| 节点时间 (UTC+8) | 执行阶段 | 操作与产物 | 状态 |
| :--- | :--- | :--- | :--- |
| **2026-09-05 09:50** | 工单下达 | 接收综合返工工单 `WO-20260905-001`，确立 P0-A → P0-B → P1 严格执行序 | OK |
| **2026-09-05 09:51** | P0-A 审查 | 审查工作区状态，确认非白名单噪声已完全清理，仅保留真实工作单元 | OK |
| **2026-09-05 09:52** | P0-A 门禁 | 跑通 21 个 Win64 运行时包构建（0 Error / 0 Warning），存档 `build-p0a-packages.log` | PASS |
| **2026-09-05 09:53** | P0-A 回归 | HB 全量单元测试 91/91 全绿，存档 `p0a-regression.xml`，证明零破坏还原 | PASS |
| **2026-09-05 09:53** | P0-B 提交 | 完成 005R 返工提交（Commit 1: `95edea6`，含 Demo 崩溃修复与真机证据、GUID 唯一化、Demo 源码入库） | PASS |
| **2026-09-05 09:55** | P1 契约落地 | 编写 Brief `docs/ui/work-orders/WO-20260905-001-brief.md`，更新规范索引 `docs/29.ui-runtime.md` | OK |
| **2026-09-05 09:57** | P1 视觉验证 | 编写并跑通表面色渲染自动化测试，生成 4 张不同 Card Kind 底色按钮融入截图 | PASS |
| **2026-09-05 09:58** | P1 全量门禁 | 全包构建通过，92/92 测试全绿，输出 `UnitTestResults.xml` 与 `test_hb_ci.log` | PASS |

---

## 2. 编码污染根因诊断与防复发建议（Root Cause Analysis）

### 2.1 根因诊断
1. **发生机理**：在 Delphi 13.1 (Athens) / Windows 简体中文（CP936）环境下，历史会话曾执行针对 `*.pas` 文件的批量 UTF-8 BOM 修复脚本，由于未设置精准的文件修改白名单或路径边界，导致扫描并重写了仓库中约 300 个存量源码文件，引入了 UTF-8 BOM 字节头（`EF BB BF`）及中文注释行的字节级重编码；
2. **扩散影响**：导致未修改的存量单元大面积出现在 `git status` 的 Modified 列表中，造成后续代码审查时的“噪音频发”与“混提交”风险；
3. **修复验证**：本次 P0-A 严格按白名单将除真实工作单元（`Core.pas`, `Controls.pas`, `Cards.pas`, `PageControl.pas`, `Suite.pas` 及 P0-B 单元）外的全部文件还原至 HEAD，并通过 21 包全量编译与 91/91 单元测试（`p0a-regression.xml`），实证还原操作未对代码库造成任何破坏。

### 2.2 防复发措施建议（Proposal）
- **工具层面建议**：后续任何字符编码转换工具必须强制携带 `--dry-run` 预览与基于 `git diff --name-only` 的精准暂存范围限制，严禁在无边界全仓递归重写；
- **配置建议**：建议团队在 `.gitattributes` 中对 Pascal 源文件声明标准检出行为（`*.pas text eol=crlf`），并在 IDE/编辑器中锁定“仅在文件实质修改时按原编码或统一 UTF-8 保存”策略。

---

## 3. 逐任务执行状态与验收核对

### 3.1 P0-A · 工作区编码污染清理（已完成）
- **白名单外文件还原**：已清理所有噪声修改，恢复 `TestResults/WO-20260904-001/UnitTestResults.xml` 与 `TestResults/WO-20260904-003/screenshots/sharecard_yahei.png` 等不可变证据；
- **构建门禁**：21 个 Win64 运行时包构建 0 Error / 0 Warning，日志：`TestResults/WO-20260905-001/build-p0a-packages.log`；
- **回归测试**：91/91 单元测试全部 PASS，JUnit XML 存档：`TestResults/WO-20260905-001/p0a-regression.xml`。

### 3.2 P0-B · WO-20260904-005R 返工（已提交并闭环）
- **R1（P0）Demo 启动崩溃根因修复 + 真机实测存证**：
  - **根因**：`THbFireDACSnapshotStorage` 构造期直接触碰 DB/IO，且 `THbDialogWizardSession` 包含在 VCL 单元中引发控制台宿主与 VCL initialization 顺序异常；
  - **修复**：重构为 `GetInstance` 延迟单例，将 `THbDialogWizardSession` 纯 RTL 下沉至 `Core/DeepBase.HB.Dialogs.Types.pas`，Demo DPR 显式链接 FireDAC 驱动；
  - **真机证据**：跑通 Phase 1（填至第 3 步，持久化 snapshot）→ 进程退出 → Phase 2（重开进程，100% 恢复第 3 步与表单字段，文案“已为您恢复上次推演进度”验证），原始输出见 `TestResults/WO-20260904-004/demo_snapshot_recovery-r2.log`；
  - **报告更新**：004 交付报告 3.4 节已严格依据 `r2` 日志重写。
- **R2（P0）HB 接口 GUID 唯一化**：
  - `IHbSnapshotProvider`: `['{7D4B6E20-8F31-4A5C-9E12-6B8F0A2C4D6E}']`
  - `IHbStateSlotProvider`: `['{E3A1C590-7D82-4F6B-B415-9C0E2A4F8D17}']`
  - 全库 grep 验证无重复；新增交叉查询防误报回归测试 `Test_InterfaceGUID_UniquenessAndCrossCast_NoCollision`。
- **R3（P1）Demo 源码入库**：
  - `Examples/HbSnapshotDemo/HbSnapshotDemo.dpr` 与 `.dproj` 完整入库。
- **Commit 1 执行**：已提交至 master（Commit Hash: `95edea6`）。

### 3.3 P1 · 表面色工作正式化（已完成）
- **契约与 Brief**：
  - Brief 交付文件：`docs/ui/work-orders/WO-20260905-001-brief.md`；
  - 规范索引更新：`docs/29.ui-runtime.md` 增补第 4.1 节《容器表面色契约 (IHbSurfaceProvider)》；
- **核心实现机制**：
  - `Core/DeepBase.HB.Core.pas`: 定义 `IHbSurfaceProvider` 契约（GUID: `['{69611684-5658-4FE2-895C-6EF54C532001}']`）；
  - `VCL/DeepBase.VCL.HB.Controls.pas`: `THbCustomControl.GetContainerBgColor` 沿 Parent 链自底向上动态解析父容器的 `IHbSurfaceProvider.GetSurfaceColor`，并在 `EraseBackground` 中统一擦除，彻底杜绝 Pill 按钮及圆角控件在不同底色容器中产生的矩形尖角露边；焦点环内缩 1px 防止窗口边界硬裁切；
  - `VCL/DeepBase.VCL.HB.Cards.pas`: `THbCard` 实现 `IHbSurfaceProvider`，按 `Kind` 分别暴露 `SurfaceAlt` (ckSurface)、`Sunken` (ckSunken)、`Brand` (ckHero)、`Surface` (ckOutline)；
  - `VCL/DeepBase.VCL.HB.PageControl.pas`: `THbPageControl` 实现 `IHbSurfaceProvider` 暴露 `Surface`；
- **视觉验证截图存档**：
  - 截图存储目录：`TestResults/WO-20260905-001/screenshots/`
    - `card_ckSurface_button_blend.png` (ckSurface 浅灰表面 × Pill 按钮无缝融合)
    - `card_ckSunken_button_blend.png` (ckSunken 凹陷底色 × 按钮边缘完美融合)
    - `card_ckHero_button_blend.png` (ckHero 品牌主色背景 × 按钮融合)
    - `card_ckOutline_button_blend.png` (ckOutline 边框卡片底色融合)
  - 注：003 历史截图未做任何修改。
- **测试与门禁**：
  - HB 单元测试全量 92/92 PASS（含表面色解析测试 `Test_SurfaceProvider_Resolution_AndCardContainerBg` 与截图生成测试 `Test_SurfaceProvider_VisualVerification_ExportCardScreenshots`）；
  - 存档：`TestResults/WO-20260905-001/UnitTestResults.xml`、`TestResults/WO-20260905-001/test_hb_ci.log`。

---

## 4. 技术债务登记（Technical Debt Log）

1. **历史存量 GUID 复用**：`DeepBase.DataBinding` 与 `DeepBase.Services.Interfaces` 中仍存在存量占位 GUID `{A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D}`，属于历史遗留代码，未影响 HB 体系（HB 体系已全量唯一化），建议在后续数据绑定与服务治理专项工单中统一重构；
2. **Tools/gen_ev.js 归属待定**：工作区未跟踪文件 `Tools/gen_ev.js` 未属于本工单范围，保持未跟踪状态，待主控后续明确工程归属。

---

## 5. 精确提交清单（Two Commits Record）

### 5.1 Commit 1（P0-B 005R 返工，已提交）
- **Commit Hash**：`95edea6`
- **Commit Message**：`fix(hb): rework persistence telemetry and snapshot recovery (WO-20260904-005R)`
- **暂存文件清单（13 files）**：
  1. `CodeReview/20260904-HB-PERSIST-SNAPSHOT-交付报告.md`
  2. `Core/DeepBase.HB.Dialogs.Types.pas`
  3. `Core/DeepBase.HB.StateSlot.Types.pas`
  4. `Core/DeepBase.HB.Touchpoint.Types.pas`
  5. `Examples/HbSnapshotDemo/HbSnapshotDemo.dpr`
  6. `Examples/HbSnapshotDemo/HbSnapshotDemo.dproj`
  7. `Persistence/DeepBase.Persistence.HBTelemetry.FireDAC.pas`
  8. `TestResults/WO-20260904-004/UnitTestResults-r2.xml`
  9. `TestResults/WO-20260904-004/build-r2-packages.log`
  10. `TestResults/WO-20260904-004/demo_snapshot_recovery-r2.log`
  11. `TestResults/WO-20260904-004/test_hb_ci-r2.log`
  12. `Tests/Test.DeepBase.HB.Persistence.pas`
  13. `VCL/DeepBase.VCL.HB.Dialogs.pas`

### 5.2 Commit 2（P1 表面色正式化与综合闭环）
- **暂存文件清单（18 files）**：
  1. `Core/DeepBase.HB.Core.pas`
  2. `VCL/DeepBase.VCL.HB.Cards.pas`
  3. `VCL/DeepBase.VCL.HB.Controls.pas`
  4. `VCL/DeepBase.VCL.HB.PageControl.pas`
  5. `Tests/Test.DeepBase.HB.Suite.pas`
  6. `docs/29.ui-runtime.md`
  7. `docs/ui/work-orders/WO-20260905-001-brief.md`
  8. `docs/ui/work-orders/WO-20260905-001-HB-CLEANUP-005R-SURFACE.md`
  9. `TestResults/WO-20260905-001/build-p0a-packages.log`
  10. `TestResults/WO-20260905-001/p0a-regression.xml`
  11. `TestResults/WO-20260905-001/build-packages.log`
  12. `TestResults/WO-20260905-001/UnitTestResults.xml`
  13. `TestResults/WO-20260905-001/test_hb_ci.log`
  14. `TestResults/WO-20260905-001/screenshots/card_ckSurface_button_blend.png`
  15. `TestResults/WO-20260905-001/screenshots/card_ckSunken_button_blend.png`
  16. `TestResults/WO-20260905-001/screenshots/card_ckHero_button_blend.png`
  17. `TestResults/WO-20260905-001/screenshots/card_ckOutline_button_blend.png`
  18. `CodeReview/20260905-HB-CLEANUP-005R-SURFACE-交付报告.md`

---

## 6. 门禁与证据总结

- [x] **G1 构建门禁**：21 个 Win64 运行时包构建 0 Error / 0 Warning，日志完备；
- [x] **G2 测试门禁**：HB 套件 92/92 测试全绿，0 Failed, 0 Errored, 0 Leaked；
- [x] **G3 真机环境**：Demo 崩溃彻底根治，恢复进度实测日志与 stdout 原始证据留痕；
- [x] **G4 契约规范**：`IHbSurfaceProvider` 与新 GUID 契约闭环并索引至规范文档；
- [x] **G5 提交纪律**：两阶段独立 Commit 留痕，无混提交，无搭车代码。
