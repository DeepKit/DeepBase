# 工单 WO-20260905-001 · 工作区编码污染清理 + 005R 返工 + 表面色工作正式化（罗辑）

> **指派对象**：罗辑（software-tools 人格 / 主编码代理）
> **性质**：综合返工单（P0-A 污染清理 → P0-B 005R 返工 → P1 表面色正式化，严格按序执行）
> **基线**：Delphi 13.1 (Athens) · Win64 · dcc64 = `D:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe`

***

## 主控复核实录（2026-09-05，全部独立验证）

1. **表面色工作（IHbSurfaceProvider）代码真实、架构合格**：Core 接口（DeepBase.HB.Core.pas:43）、基类父链解析（GetContainerBgColor）、THbCard 按 Kind 同步、THbPageControl 接入、新测试（Suite +67 行）均实证存在。**但为"三无"交付：无工单、无证据存档（90/90 仅有控制台输出，TestResults 无 XML）、未提交。**
2. **工作区被约 300 个文件的编码转换污染**：GBK/ANSI → UTF-8 BOM 批量转换（BOM 加入 + 中文注释行字节重写）。抽样实证：Core/DeepBase.Crypto.Hash.pas 唯一实质改动是行首加 BOM；Tests/Acceptance/AcceptanceRunner.pas 同模式。表面色工作未提交且泡在污染中——此时直接 commit 即 99ec1e7 混提交事故放大重演。
3. **WO-20260904-005R 三项返工（GUID 唯一化 / demo 崩溃修复 / demo 源码入库）一项未动**：GUID 四重复用仍在（DataBinding:99 / Services.Interfaces:47 / Touchpoint.Types:82 / StateSlot.Types:24）；TestResults\WO-20260904-004 无 r2 证据；Examples\HbSnapshotDemo\ 仍未跟踪。
4. 证据不可变纪律被触碰：`TestResults/WO-20260904-001/UnitTestResults.xml`、`TestResults/WO-20260904-003/screenshots/sharecard_yahei.png` 被改动（编码噪声或再生成），须还原。
5. 主控已自查补账（不属本工单）：v2.0 规范与 004/005R 工单此前从未提交，已补（commit 5d10638）；历史报告与证据归档（commit c04e727）；.gitignore 增补工具目录。

## P0-A · 编码污染清理（第一优先，先做）

**白名单（真实工作，保留不还原）**：

```
Core/DeepBase.HB.Core.pas
VCL/DeepBase.VCL.HB.Controls.pas
VCL/DeepBase.VCL.HB.Cards.pas
VCL/DeepBase.VCL.HB.PageControl.pas
Tests/Test.DeepBase.HB.Suite.pas
Examples/HbSnapshotDemo/          （未跟踪，留给 P0-B R3 入库）
```

**操作**：白名单之外的**全部已修改文件**一律还原（含证据文件与交付报告的噪声改动）：

```powershell
$whitelist = @('Core/DeepBase.HB.Core.pas','VCL/DeepBase.VCL.HB.Controls.pas','VCL/DeepBase.VCL.HB.Cards.pas','VCL/DeepBase.VCL.HB.PageControl.pas','Tests/Test.DeepBase.HB.Suite.pas')
git diff --name-only | Where-Object { $_ -notin $whitelist } | ForEach-Object { git checkout -- $_ }
```

**根因诊断（交付报告必含一段）**：查明编码批量转换何时/由何工具引入（文件 mtime 聚类分析 + 昨日 17:11 demo 构建后夜间会话时间线比对），给出防复发措施（如编辑器保存编码设置、.gitattributes 壳 proposal——只建议不实施）。

**P0-A 验收**：

- `git status --short` 修改文件仅剩白名单 5 个（+未跟踪 Examples/、Tools/gen\_ev.js）

- 三包 dcc64 编译 0 Error、HB 全量套件重跑全绿，junit XML 存档 `TestResults\WO-20260905-001\p0a-regression.xml`（证明还原零破坏）

## P0-B · WO-20260904-005R 三项返工（原样重申，一字未减）

**R1（P0）Demo 崩溃修复 + 真实环境证据重做**

- 主控复跑 `TestResults\WO-20260904-004\HbSnapshotDemo.exe` 启动即崩（Runtime error 217 / exit 0xC0000005）

- 定位根因（疑方向：console 程序 uses VCL 单元的 initialization 依赖；或 FireDAC SQLite 驱动链接时机），禁止 try-except 吞异常式"修复"

- 完整跑通 Phase 1（填半程+落盘+模拟崩溃）→ Phase 2（新进程恢复+断言+提示文案），stdout 存 `TestResults\WO-20260904-004\demo_snapshot_recovery-r2.log`

- 交付报告 3.4 节重写：只写证据文件实际支撑的结论

**R2（P0）HB 接口 GUID 唯一化**

- `IHbSnapshotProvider`（Touchpoint.Types.pas:82）与 `IHbStateSlotProvider`（StateSlot.Types.pas:24）各生成全新唯一 GUID，全库 grep 证唯一

- 新增回归测试：同一对象实现两接口时 `Supports` 各得其所、互不误报

- 存量 DataBinding/Services.Interfaces 两处历史复用登记债务，不强制改

**R3（P1）Demo 源码入库**

- `Examples\HbSnapshotDemo\`（dpr + dproj）入返工 commit

## P1 · 表面色工作正式化（代码已验收合格，补流程闭环）

1. 补契约节入本工单交付报告（目标/范围/验收标准/digest，参照 brief 格式，可并入 `docs\ui\work-orders\WO-20260905-001-brief.md`）
2. 90/90 全量重跑（噪声还原后），junit XML 存档 `TestResults\WO-20260905-001\UnitTestResults.xml`
3. 新增表面色验证截图存 `TestResults\WO-20260905-001\screenshots\`（卡片四 Kind × 按钮融入对比，至少 ckSurface/ckSunken/ckHero 三张）——**禁止改动 003 已提交的旧截图**
4. 文档索引：29.ui-runtime.md v2.0 增补一行 IHbSurfaceProvider 契约索引（接口已在 Core 落地，规范补登记）

## 精确提交纪律（两个 commit，顺序固定）

1. **commit 1（P0-B 返工）**：demo 修复 + GUID + demo 源码 + 004 报告 r2 更新 + r2 证据文件
2. **commit 2（P1 表面色）**：白名单 5 文件 + brief + 新证据目录 + 规范索引行
3. 每次 commit 前 `git status` 核对暂存清单并在交付报告附上；禁止 `git add -A`

## 总验收准则

1. P0-A/P0-B/P1 按序全部完成，验收项逐条满足
2. 三包编译 0 Error / 0 Warning（HB 单元），原始日志存档 `TestResults\WO-20260905-001\build-*.log`
3. 全量 HB 套件全绿（junit XML 实数，预期 90+ 新增 GUID 测试数）
4. 主控将亲自复跑 demo exe、grep GUID 唯一性、核对 `git status` 干净度
5. 异族模型独立终审（必做：涉及证据纪律与范围纪律双复发风险）
6. 交付报告 `CodeReview\20260905-HB-CLEANUP-005R-SURFACE-交付报告.md`：生产部署状态章节（时间链）、编码污染根因、逐任务状态、债务节（含 Tools/gen\_ev.js 待归属、DataBinding/Services 存量 GUID 债务）、两个 commit 哈希与暂存清单

