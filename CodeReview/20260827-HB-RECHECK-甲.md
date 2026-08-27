# P0 修复复审报告（甲号工单 · 第三方独立复审）

- **工单**：`D:\_Progs\02Business\DeepBase\docs\ui\work-orders\WO-20260827-HB-AUDIT-FIX-VCL-甲.md`
- **被复审交付报告**：`D:\_Progs\02Business\DeepBase\CodeReview\20260827-HB-FIX-甲-交付报告.md`（声称"全项通过 100% GREEN，0 编译错误，0 内存泄漏"）
- **原始审计证据**：`D:\_Progs\02Business\DeepBase\CodeReview\20260827-HB-VCL-A.md`、`D:\_Progs\02Business\DeepBase\CodeReview\20260827-HB-VCL-B.md`
- **复审时间**：2026-08-27 09:00–09:20（Asia/Shanghai）
- **复审方法**：不信任交付报告，逐文件读源码实测 + dcc64 双通道编译实测 + junit XML 实跑取证
- **复审判定口径**：✅已修复 / ⚠️部分修复 / ❌未修复，以工单"修复要求"原文为验收基线

---

## 一、编译与回归实测（先说硬结论）

### 1.1 dcc64 编译 DeepBaseVCL.dpk（双通道）

| 通道 | 参数 | 实测结果 |
|---|---|---|
| **A. 项目标准包门禁参数**（与 `Scripts\build_packages_win64.ps1` L168 一致，无 codepage） | `dcc64 -B -Q -U… -N0… -LE… -LN… DeepBaseVCL.dpk` | **EXITCODE=1，1 Error**：`VCL\DeepBase.VCL.HB.LLMWizard.pas(192) Error: E2010 Incompatible types: 'Char' and 'AnsiString'` + `DeepBaseVCL.dpk(90) Fatal: F2063`。完整日志：`D:\_Progs\02Business\DeepBase\TestResults\vcl_compile_log.txt` |
| **B. 测试构建参数**（与 `Scripts\run_tests.ps1` L592 一致，`--codepage:65001`） | `dcc64 -B -Q --codepage:65001 …` | **EXITCODE=0，0 Error，8 Warning**（7 条存量 + **1 条新增**：`DeepBaseVCL.dpk(94) Warning: W1033 Unit 'DeepBase.Persistence.LLM.FireDAC' implicitly imported into package 'DeepBaseVCL'`）。完整日志：`D:\_Progs\02Business\DeepBase\TestResults\vcl_compile_log_cp65001.txt` |
| C. 依赖包 DeepBaseCore.dpk（通道 A 参数） | 同 A | EXITCODE=0（0 Error，存量 Hint/W1057 若干） |

**E2010 根因**：`DeepBase.VCL.HB.LLMWizard.pas` 为**无 BOM 的 UTF-8 文件**（首 3 字节 `123,32,61` = `{ s`）。L192 `FEdtApiKey.PasswordChar := '•';` 中 `•`（U+2022）以 UTF-8 三字节存放，dcc64 在无 BOM 且未指定 codepage 时按系统 ANSI 代码页解读，解码成多字节字符串 → 与 `PasswordChar: Char` 不兼容。**按工单字面要求"用 dcc64 对 DeepBaseVCL.dpk 做编译"，标准包门禁参数下编译失败。** 交付报告"0 编译错误"只在 `--codepage:65001` 通道成立，与项目自身包构建脚本参数不一致。

### 1.2 回归测试实跑（工单验收准则 2 命令）

```
powershell -ExecutionPolicy Bypass -File D:\_Progs\02Business\DeepBase\Scripts\run_tests.ps1 -Type Unit -Run "Test.DeepBase.HB"
```
- 实测 EXITCODE=0，**23 Found / 23 Passed / 0 Failed**（junit：`D:\_Progs\02Business\DeepBase\TestResults\UnitTestResults.xml`，2026-08-27 09:06:52）
- 但其中 `Test_LLMWizard_CascadingSteps_And_AutoClassification` 为**假覆盖测试**（见第四章），绿≠真绿。

---

## 二、10 条 P0 逐条复审

### P0-1 A-S1 圆角黑角（Controls.pas / Cards.pas）→ **⚠️ 部分修复**

**工单要求**：重写 Paint 背景：**擦除整个 ClientRect（或 Parent 背景色）后再绘制圆角路径**。

实测证据：
- 已做：`D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Controls.pas:348` `ControlStyle := ControlStyle - [csOpaque] + [csCaptureMouse];`；`D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Cards.pas:205` `ControlStyle := ControlStyle + [csAcceptsControls] - [csOpaque];`
- 未做①：`DeepBase.VCL.HB.Controls.pas:366-368` 与 `DeepBase.VCL.HB.Cards.pas:224-226` 的 `WMEraseBkgnd` 仍返回 `Message.Result := 1`（继续拒绝系统背景擦除）；
- 未做②：`DeepBase.VCL.HB.Cards.pas:298-374` `THbCard.Paint` 四个分支（ckHero L326-340 / ckSunken L341-350 / ckOutline L351-356 / ckSurface L357-366）**全部只 FillPath/DrawPath 圆角路径，无任何 FillRectangle(整个 ClientRect) 或 Graphics.Clear**。
- 反证（正确做法在同仓库存在）：`DeepBase.VCL.HB.Grid.pas:409-414` Grid 的 Paint 先 `Graphics.FillRectangle(BrushBg, 0, 0, Width, Height)` 全区擦除再画内容。

技术后果：移除 csOpaque 后 VCL 视该控件为需背景绘制，但系统擦除被 `Result:=1` 短路、Paint 又不补画 → 圆角外四角区域仍呈未定义内容（首帧黑角/残影风险仍在，双缓冲下为垃圾位图内容）。
**交付报告声称"黑角瑕疵完全消除"——与实测不符。**

### P0-2 A-S2 Tray Hint 污染 + 释放路径守卫 → **⚠️ 部分修复**

**工单要求**：按报告建议修复 **Hint 生命周期**与**释放路径守卫**。

实测证据：
- Hint 生命周期已修 ✅：`D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Tray.pas:127` 新增 `FBaseToolTip: string;`；L649-656 `SetToolTip` 先存基准串再按 `FBadgeCount` 重拼；L658-667 `SetBadgeCount` 基于 `FBaseToolTip` 重拼，不再累积污染。
- 释放路径守卫（原审计 M1，工单列入 A-S2 修复范围）**三处全部未修**，代码与原审计引用逐字一致：
  - `DeepBase.VCL.HB.Controls.pas:826-838` `THbDualButton.MouseUp`：无 (X,Y) 命中校验，`FPressPart` 触发事件后才清零，拖出控件释放仍触发 `FOnPointsClick`（付费扣点按钮，资损级交互缺陷）；
  - `DeepBase.VCL.HB.Cards.pas:674-686` `THbListRow.MouseUp`：同病（`FActionPressPart`）；
  - `DeepBase.VCL.HB.Cards.pas:935-945` `THbEmptyState.MouseUp`：同病（`FActionPressed`）；
  - 三者均无 `CMMouseLeave` 复位 press 状态（基类 `DeepBase.VCL.HB.Controls.pas:382-388` 只复位基类自身的 `FIsPressed`）。

### P0-3 A-S3 Waterfall 空壳 → **⚠️ 部分修复**

**工单要求**：补齐核心渲染实现。

实测证据：
- 渲染已补 ✅：`D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Waterfall.pas:352-386` `RebuildLeftRail` 真实创建分面按钮（L376-381 有 bkPrimary/bkGhost/bkSoft 视觉区分）；L388-439 `RebuildWaterfall` 真实创建卡片（THbCard + 标题 + 摘要，L415-434）。
- 缺陷①：**分面按钮无 OnClick**（L369-381 创建 `Btn` 全程无事件绑定）→ 用户点击分面无任何反应，`FFocusedCategoryId` 只能靠代码 API 改变；
- 缺陷②：**双模式无差异**——`RebuildWaterfall` L409-435 渲染循环完全不依赖 `FMode`，`wmTimeline`/`wmSectioned` 输出相同平铺列表；`SetMode`（L181-198）只切换两个模式按钮的 Kind。
**交付报告声称"瀑布流交互与渲染完整"——分面筛选交互（published 接口的核心承诺）未兑现。**

### P0-4 B-S1 NavTree 托管记录 UB → **✅ 已修复**

实测证据：`D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.NavTree.pas:156`（AddSection）、`:170`（AddItem）、`:188`（AddDivider）三处 `N := Default(THbNavItemData);`。`Default()` 使编译器初始化全部托管字段（IconSvg 等 string 字段为合法空串），未初始化托管字段 UB 消除，满足工单"补全全部托管字段"意图。

### P0-5 B-S2 Grid 滚动死代码 → **⚠️ 部分修复**

**工单要求**：打通滚动→可视区映射→按需绘制链路。

实测证据：
- 链路已通 ✅：`D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Grid.pas:222-236` `WMVScroll` 全 case 处理；`:238-246` `CMMouseWheel`；`:198-208` `ScrollToRow`（范围裁剪+UpdateScrollBars+Invalidate）；`:180-196` `UpdateScrollBars` 走 `SetScrollInfo`；`:466` Paint 行循环 `for R := FScrollTopRow to FScrollTopRow + VisibleRows`（按需绘制虚拟行）。
- 关键缺口：**全文件无 `CreateParams` 覆写、无 `WS_VSCROLL` 样式声明**（Grep 实测零命中）→ Windows 不为该窗口创建滚动条，`SetScrollInfo` 对不可见滚动条无效，用户无法拖动滚动条定位。滚轮/键盘路径可用，但"滚动条 UI"这条主路径仍是死路。
**交付报告声称"缺少标准滚动条与消息绑定"已修——滚动条本体缺失未提。**

### P0-6 B-S3 VirtualList O(N²)/全量常驻 → **⚠️ 部分修复**

**工单要求**：改为仅持有可视区渲染状态，数据经回调按需取；批量加载降为 O(N)。

实测证据：
- O(N²)→O(N) 已修 ✅：`D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.VirtualList.pas:336-363` `AddItem` 改为**增量追加**过滤索引（L357-359 仅对新增项做一次匹配后 `FFilteredIndices.Add`），不再全量重建（全量重建仅在 `SetSearchFilter` L188-196 时触发，属合理）。
- 全量常驻未修 ❌：L42 `FItems: TList<THbVirtualListItem>` 仍全量持有每条完整记录（13 个字符串/布尔字段，见 `D:\_Progs\02Business\DeepBase\Core\DeepBase.HB.VirtualList.Types.pas:33-47`）；**无回调式数据源**（对比 Grid 的 `OnGetCellText`/`OnGetCellFloat` 回调设计）。单元头 L6 注释"O(1) memory virtual viewport rendering for 100,000+ items"承诺继续落空——10 万行时内存仍随 N 线性增长。
- 渲染层虚拟化 ✅：Paint L491-496 从 `StartIdx` 起仅画可视高度内行。
**工单验收准则 3（10 万行内存恒定实测）交付报告亦未提供任何数字。**

### P0-7 B-S4 CommandPalette 命中错位 → **⚠️ 部分修复**

**工单要求**：修命中计算（含滚动偏移与 DPI 缩放）；**改为选中项高亮+回车/双击执行**。

实测证据：
- 命中错位已修 ✅：`D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.CommandPalette.pas:338-366` `HitTestRow` 与 Paint L385-483 游标严格同源——同起点（`ListTop := FPnlSearchBox.Height` + 4，L345-346 vs L397+413）、组头同推进（`Inc(CurY, FHeaderHeight)`，L355-358 vs L426-433）、行高同推进（`Inc(CurY, FRowHeight)`，L364 vs L481）、命中区间 `[CurY, CurY+FRowHeight)`（L361）与绘制矩形（L436）对齐。分组标题高度错位问题消除。
- 执行交互未按工单改 ❌：MouseDown L368-383 仍为**左键单击即执行**（L379-381 `FSelectedIndex := ClickedRow; Invalidate; ExecuteSelected;`）。工单明确要求"选中项高亮+回车/双击执行"，未实现。回车路径存在（OnSearchKeyDown L227-231）但单击即执行行为未收敛。
- 附带：L47/L90 `FMaxVisibleItems` 声明+published 但 Paint/HitTest 均未使用（死属性）；`LastUsedAt`（L294 赋值）从未参与 MRU 排序。

### P0-8 B-S5 AI 空壳 → **✅ 已修复**

实测证据：`D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.AI.pas` 主体非空壳——双面板布局（FPnlLeftMain L172-175 / FPnlRightAux L161-165）、模型切换（L284-292）、抽屉开合（L259-274）、思考卡片 `AddThoughtStep`（L327-365）、Diff 提案卡片+采纳按钮 `AddDiffProposal`（L367-416）、`OnPromptSubmit`/`OnDiffDecision` 事件闭环、Ctrl+Enter 采纳（L312-325）。published 属性均有实现，无空壳接口。
小瑕疵（🔵）：Ctrl+Enter 固定采纳 `FProposals[0]`（L318）而非当前焦点提案。

### P0-9 B-S6 PageControl 4 样式 → **✅ 已修复**

实测证据：`D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.PageControl.pas` Paint 中四样式均有真实绘制分支：tsSegmented（L300-311 活动 pill 填充）、tsCard（L313-337 活动卡边框/非活动 SurfaceAlt）、tsChrome（L340-351 活动 SurfaceAlt 填充）、tsUnderline（L367-371 活动下划线 PenActive）。Badge 绘制 L379-392。原审计"只实现 2 种"已补齐。
遗留（🔵）：单元头 L7 承诺的 Chrome 风格关闭按钮 'x'（`IsClosable`）未渲染未命中；`FHoverIndex` 在 MouseMove（L220-231）更新但 Paint 从未使用，hover 无视觉反馈。

### P0-10 B-S7 ShareCard PNG → **✅ 已修复**

实测证据：`D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.ShareCard.pas:28` 引入 `Vcl.Imaging.pngimage`；L216-243 `SaveToFile` 用 `TPngImage.Assign(Bmp)` + `Png.SaveToFile` 真实 PNG 编码（L226-233）；`.png`/无扩展名走 PNG（L224），其他扩展名退回 BMP 并明示；L245-256 `CopyToClipboard`。RenderToBitmap 异常安全（L210-213 except Free+raise）。真实测试 `Test_ShareCard_TruePngExport`（junit 实跑通过）。

---

## 三、判定速览

| # | 缺陷 | 判定 | 一句话依据 |
|---|---|---|---|
| P0-1 | A-S1 圆角黑角 | ⚠️ 部分修复 | csOpaque 已移除（Controls:348 / Cards:205），但 WMEraseBkgnd 仍返回 1、Paint 未擦全 ClientRect（Cards:298-374 仅画圆角路径），工单"擦除整个 ClientRect"未达标 |
| P0-2 | A-S2 Tray Hint 污染 | ⚠️ 部分修复 | Hint 污染已修（Tray:127/649-667 FBaseToolTip）；工单"释放路径守卫"M1 三处未修（Controls:826-838、Cards:674-686、Cards:935-945 拖出释放仍触发付费按钮） |
| P0-3 | A-S3 Waterfall 空壳 | ⚠️ 部分修复 | 渲染已补（Waterfall:352-386/388-439），但分面按钮无 OnClick、wmTimeline/wmSectioned 双模式渲染无差异 |
| P0-4 | B-S1 NavTree 托管 UB | ✅ 已修复 | NavTree:156/170/188 三处 Default(THbNavItemData) 初始化 |
| P0-5 | B-S2 Grid 滚动死代码 | ⚠️ 部分修复 | 消息链路+虚拟行绘制已通（Grid:180-246/466），但无 CreateParams/WS_VSCROLL → 滚动条不可见不可拖 |
| P0-6 | B-S3 VirtualList O(N²)/全量常驻 | ⚠️ 部分修复 | AddItem 已改增量索引 O(N)（VirtualList:336-363），但 FItems 仍全量常驻、无回调数据源，O(1) 内存承诺落空 |
| P0-7 | B-S4 CommandPalette 命中错位 | ⚠️ 部分修复 | HitTest 与 Paint 游标同源已修（:338-366 vs :385-483），但左键仍单击即执行（:379-381），工单"高亮+回车/双击执行"未实现 |
| P0-8 | B-S5 AI 空壳 | ✅ 已修复 | 双面板/思考卡/Diff 卡/事件闭环齐备（AI.pas:110-440） |
| P0-9 | B-S6 PageControl 4 样式 | ✅ 已修复 | 四样式真实现（PageControl:299-352）；Chrome 关闭按钮未兑现记 🔵 |
| P0-10 | B-S7 ShareCard PNG | ✅ 已修复 | TPngImage 真编码（ShareCard:216-243） |

**汇总：✅ 4 / ⚠️ 6 / ❌ 0**（交付报告 10 条全部标 ✅，其中 5-6 条与实测不符）

---

## 四、额外复审：超工单范围新增资产（LLMWizard）

### 4.1 编译失败（🔴）

`VCL\DeepBase.VCL.HB.LLMWizard.pas(192) Error: E2010`（`PasswordChar := '•'`，无 BOM UTF-8 根因，详见 1.1）。按项目标准包门禁参数 `DeepBaseVCL.dpk` 编不过；`--codepage:65001` 通道可过但产生新增 W1033（`DeepBase.Persistence.LLM.FireDAC` 隐式导入 DeepBaseVCL 包，dpk 的 requires 未声明该依赖）。

### 4.2 三大核心步骤为假实现，交付报告虚假声称（🔴）

对照交付报告第二章声称与 `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.LLMWizard.pas` 实况：

| 交付报告声称 | 代码实况 | 证据 |
|---|---|---|
| "Step 1: 实时测速连通性 Ping、握手延迟指示" | **硬编码假延迟**：`Latency := 128; // Default good latency probe result`，无任何网络请求；端点为空才报错，Key 填什么都 `IsVerified := True` 并显示"🟢 连通性正常" | L356-384（L374 硬编码，L376 无条件置真） |
| "Step 2: 调用 /v1/models 获取可用清单" | **写死 4 个模型名**（deepseek-reasoner/deepseek-chat/gpt-4o-mini/qwen-2.5-7b），无任何 HTTP 调用 | L386-405（L391-395 硬编码数组） |
| "Step 4: 一键事务存盘并向全局广播就绪信标" | **无任何持久化代码**：`FConfig.IsPersisted := True; Result := True;`，无 DB 写入、无事务、无广播；UI 却显示"🟢 已成功固化并事务写入主库 DB1 · 配置立即生效" | L459-470（ValidateAndSaveToDB1）、L472-481（虚假成功文案） |
| （集成痕迹） | uses 引入 `System.Threading`、`DeepBase.LLM.Client`、`DeepBase.LLM.Types`、`DeepBase.LLM.Service`、`DeepBase.Persistence.LLM.FireDAC` **五个单元全部从未使用**——伪装集成的装饰性 uses | L24、L37-40 |

### 4.3 测试真实性（🔴 假覆盖）

`D:\_Progs\02Business\DeepBase\Tests\Test.DeepBase.HB.DeepRW.pas:299-331` `Test_LLMWizard_CascadingSteps_And_AutoClassification`：
- 名为"级联步骤+自动分类"，实际**未触发任何级联**——`OnTestPingClick`/`OnFetchModelsClick`/`OnCommitDB1Click`/`AutoClassifyModels`（经 UI 路径）一个都没调用；
- L324 `Wizard.Config := THbLLMSetupConfig.CreateDefault;` 后 L326-327 断言的 `deepseek-reasoner`/`deepseek-chat` 是 **CreateDefault 的静态默认值**（Types.pas L75-76），不是"自动分类"的输出；
- L325 `Assert.IsTrue(Wizard.ValidateAndSaveToDB1)` 验证的是恒返回 True 的**假持久化空壳方法**。
- 交付报告声称"增加完整向导级联与自动分类测试用例"——名不副实。

### 4.4 工程注册（✅）

- `D:\_Progs\02Business\DeepBase\DeepBaseCore.dpk:70` 收录 `DeepBase.HB.LLMWizard.Types`；
- `D:\_Progs\02Business\DeepBase\DeepBaseVCL.dpk:90` 收录 `DeepBase.VCL.HB.LLMWizard`。
- 唯一瑕疵：VCL 包 requires 未声明 FireDAC 持久化依赖，导致 4.1 的 W1033 隐式导入。

---

## 五、工单验收准则逐条对照

| # | 工单验收准则 | 实测 | 结论 |
|---|---|---|---|
| 1 | dcc64 编译 0 Error；新增 0 Warning | 标准包参数 1 Error（E2010）；UTF-8 通道 0 Error 但新增 1 条 W1033 | **❌ 不满足** |
| 2 | 回归全绿，以 junit XML 为准 | 23/23 通过（UnitTestResults.xml 09:06:52），但含 1 条假覆盖测试 | △ 形式满足 |
| 3 | 10 万行 VirtualList/DataGrid 内存恒定，给出实测前后对比数字与测试代码 | 交付报告无任何内存数据、无测试代码 | **❌ 不满足** |
| 4 | 交付报告含「生产部署状态」章节（编译/测试进程时间戳） | 交付报告全文无该章节 | **❌ 不满足** |
| 5 | 每条 P0 引用编号并标注 已修复/部分修复/不适用+理由 | 编号齐全，但 10 条全标 ✅，实测 6 条为部分修复 | △ 标注失实 |

---

## 六、新增问题统计（本次复审发现，原审计之外）

**🔴 3 项（阻断级）**
1. `DeepBaseVCL.dpk` 标准包门禁参数编译失败：E2010 at `VCL\DeepBase.VCL.HB.LLMWizard.pas:192`（无 BOM UTF-8 + `PasswordChar := '•'`），包门禁 `Scripts\build_packages_win64.ps1` 参数下必炸；
2. LLMWizard 三大核心步骤假实现（硬编码 Ping 128ms / 写死 4 模型 / 无 DB 持久化却显示"已固化写入主库"），且交付报告据此作出"实时测速 / 调用 /v1/models / 一键事务存盘"三处虚假功能声称——触碰零容忍捏造红线；
3. `Test_LLMWizard_CascadingSteps_And_AutoClassification` 假覆盖测试（未测级联、断言静态默认值、验证恒真空壳方法）。

**🟡 7 项**
1. A-S1 残留：`WMEraseBkgnd` 返回 1 + Paint 不擦全 ClientRect（Controls:366-368 / Cards:224-226 / Cards:298-374），黑角风险仍存，工单验收未达标；
2. A-S2 残留：M1 拖出释放误触发三处未修（Controls:826-838 / Cards:674-686 / Cards:935-945，付费按钮资损风险）；
3. A-S3 残留：Waterfall 分面按钮无 OnClick（Waterfall:369-381）、双模式渲染无差异（RebuildWaterfall 不依赖 FMode）；
4. B-S2 残留：Grid 无 WS_VSCROLL 样式声明，滚动条不可见不可拖（Grid.pas 全文件无 CreateParams）；
5. B-S3 残留：VirtualList `FItems` 全量常驻（VirtualList:42），无回调数据源，O(1) 内存承诺落空；
6. B-S4 残留：CommandPalette 左键单击即执行（CommandPalette:379-381），违反工单"高亮+回车/双击执行"交互要求；
7. 新增 W1033：`DeepBase.Persistence.LLM.FireDAC` 隐式导入 DeepBaseVCL 包（DeepBaseVCL.dpk:94 警告，requires 未声明）。

**🔵 6 项**
1. CommandPalette `FMaxVisibleItems` 声明未用（CommandPalette:47/90 死属性）；
2. CommandPalette `LastUsedAt` 从未参与 MRU 排序（CommandPalette:294 赋值后无消费）；
3. PageControl Chrome 关闭按钮 'x' 未渲染未命中（单元头 L7 承诺、IsClosable 字段无消费）；
4. PageControl `FHoverIndex` 更新但 Paint 不使用（PageControl:220-231 vs Paint），hover 无视觉反馈；
5. AI 控件 Ctrl+Enter 固定采纳 `FProposals[0]`（AI:318）而非当前焦点提案；
6. LLMWizard 装饰性 uses 五单元引入未用（LLMWizard:24/37-40，含引发 W1033 的 FireDAC）。

---

## 七、复审总结论：**不通过（FAIL）**

**理由链**：

1. **工单 5 条验收准则中 3 条硬性不满足**（编译失败/无内存实测/无生产部署状态章节——第 4 条缺失按老板规则直接 FAIL）；
2. **交付报告总体结论"全项通过（100% GREEN，0 编译错误）"与实测矛盾**：标准包门禁参数下 DeepBaseVCL.dpk 编译失败；LLMWizard 章节含三处虚假功能声称；10 条 P0 中 6 条实测为部分修复却全部标注 ✅；
3. **新增资产触碰证据纪律红线**：LLMWizard 假 Ping/假探测/假持久化 + 假覆盖测试，属"以假实现冒充功能交付"；
4. **修复本身并非一无是处**：B-S1（NavTree Default 初始化）、B-S5（AI 控件）、B-S6（PageControl 四样式）、B-S7（ShareCard 真 PNG）四条为真实合格修复；A-S2 的 Hint 生命周期、B-S2 的滚动消息链路、B-S3 的 O(N) 增量、B-S4 的命中同源也各有实质进展——但均未达到工单验收原文要求。

**放行条件（修复后需重审）**：
1. LLMWizard：要么补真实实现（真 Ping/真 /v1/models/真 DB1 持久化），要么从交付中摘除（含 dpk contains/requires、测试用例同步摘除）；修复无 BOM 编码问题（文件加 UTF-8 BOM 或改 ASCII PasswordChar）；requires 补 FireDAC 依赖消除 W1033；
2. 补齐 6 条 ⚠️ 的各自工单缺口（A-S1 全 ClientRect 擦除、A-S2 释放守卫三处、A-S3 分面交互+模式差异、B-S2 WS_VSCROLL、B-S3 回调数据源+内存实测、B-S4 高亮+回车/双击执行）；
3. 重写 LLMWizard 测试为真实级联/自动分类断言；
4. 交付报告补「生产部署状态」章节与 10 万行内存实测数据，修正全部不实声称。

---

## 附：复审实测产物索引（可复制粘贴）

- 本报告：`D:\_Progs\02Business\DeepBase\CodeReview\20260827-HB-RECHECK-甲.md`
- 编译日志（标准参数，失败）：`D:\_Progs\02Business\DeepBase\TestResults\vcl_compile_log.txt`
- 编译日志（codepage 65001，通过）：`D:\_Progs\02Business\DeepBase\TestResults\vcl_compile_log_cp65001.txt`
- 测试运行日志：`D:\_Progs\02Business\DeepBase\TestResults\recheck_test_run.txt`
- junit XML（23/23）：`D:\_Progs\02Business\DeepBase\TestResults\UnitTestResults.xml`
