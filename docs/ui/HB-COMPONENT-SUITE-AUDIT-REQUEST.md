# DeepBase HB 视觉基础设施全量组件审核与测试请求书
# (HB Component Suite Audit & Verification Request Dossier)

> **文档版本**：v1.0 (2026-08-26)  
> **提出方**：DeepBase 视觉组件研发组  
> **受检方**：DeepBase HB 视觉基础设施全系组件（VCL / FMX 双架构）  
> **目标读者**：第三方独立审核 AI / 架构评审组 / QA 自动化测试工程师  
> **编译与运行环境**：Delphi 13.1 (Athens) · 64 位 Win64 / Windows 10/11 · 支持 100%/125%/150%/200% High-DPI

---

## 一、审核目标与范围

本工程已完成 **HB（Haobo / 浩博）现代桌面级视觉基础设施** 的全量底层契约、原子控件、高阶复合控件、离屏渲染引擎、FMX 双胞胎实现、DUnitX 自动化回归套件及 5 张高保真页面原型。

请评审 AI / 审计方依据以下技术规范对全系代码资产进行全维度静态与动态审计：
1. **架构合规性**：Core（纯类型与计算） / VCL（Windows GDI+ 硬件加速） / FMX（跨平台双胞胎）分层是否清晰无循环依赖；
2. **内存与句柄安全性**：是否存在 FastMM 内存泄漏、未挂载 Parent 时的非法 HandleNeeded/RecreateWnd 触发；
3. **设计令牌一致性**：所有控件是否严格取色于 `THbTheme.Tokens`，有无硬编码魔法数值或颜色；
4. **无障碍与视觉门禁**：对比度是否达到 WCAG AA（正文 ≥ 4.5:1，大字/边框 ≥ 3.0:1），四档 DPI 缩放是否正常；
5. **性能基准**：虚拟网格与虚拟列表在 10 万~100 万数据行下是否满足 O(1) 内存与流畅渲染。

---

## 二、交付物与源码绝对路径清单

### 1. 核心层类型契约与设计系统 (`Core/`)

| 模块名称 | 绝对路径 | 说明 |
|:---|:---|:---|
| **HB 设计令牌与主题内核** | `D:\_Progs\02Business\DeepBase\Core\DeepBase.HB.Core.pas` | 包含 24+ 设计令牌、WCAG 对比度算法、色板生成器 |
| **命令面板类型契约** | `D:\_Progs\02Business\DeepBase\Core\DeepBase.HB.CommandPalette.Types.pas` | `THbCommandItem`, `IHbCommandProvider` 契约 |
| **门禁面板类型契约** | `D:\_Progs\02Business\DeepBase\Core\DeepBase.HB.Gate.Types.pas` | `THbGateSeverity`, `THbGateRowItem` 契约 |
| **虚拟列表类型契约** | `D:\_Progs\02Business\DeepBase\Core\DeepBase.HB.VirtualList.Types.pas` | `THbVirtualListItem`, `THbVirtualListAction` 契约 |
| **分享卡片类型契约** | `D:\_Progs\02Business\DeepBase\Core\DeepBase.HB.ShareCard.Types.pas` | `scfPortrait4x5`, `THbShareCardData` 契约 |
| **研究语义发现契约** | `D:\_Progs\02Business\DeepBase\Core\DeepBase.HB.Research.Types.pas` | 领域主张与证据接口契约 |
| **Core 运行时包定义** | `D:\_Progs\02Business\DeepBase\DeepBaseCore.dpk` | 核心包注册表 |

---

### 2. VCL 控件库源码 (`VCL/`)

| 控件名称 | 绝对路径 | 核心能力说明 |
|:---|:---|:---|
| **VCL 主题适配器** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Theme.pas` | Windows 主题消息广播、`AlphaColorToColor` 转换 |
| **现货色板集合** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Palettes.pas` | 沧海蓝 `canghai-blue`、极光绿等 6 套现货色板 |
| **原子控件套件** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Controls.pas` | `THbButton`, `THbBadge`, `THbAvatar`, `THbProgressBar` |
| **卡片与容器** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Cards.pas` | `THbCard`、渐变 Hero 头、阴影与圆角容器 |
| **终端与代码视口** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Terminal.pas` | 等宽字体 ANSI 语法高亮终端视口 |
| **标准对话框** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Dialogs.pas` | 模态二次确认、`PromptReason` 处置理由输入框 |
| **语音链路控件** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Voice.pas` | 麦克风波形、语音交互弹窗 |
| **托盘图标与气泡** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Tray.pas` | 现代 Windows 托盘图标与通知通知卡 |
| **分面瀑布流** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Waterfall.pas` | `THbFacetWaterfall` 分段与平铺瀑布流切换 |
| **虚拟数据网格** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Grid.pas` | `THbDataGrid` 百万行 O(1) 内存虚拟网格、状态灯单元格 |
| **AI 交互控制台** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.AI.pas` | `THbAIConsole` 左右双栏、模型选择下拉、上下文折叠 |
| **多树导航组件** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.NavTree.pas` | `THbNavTree` 240px ⇄ 48px Mini Rail 折叠导航树 |
| **现代标签页** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.PageControl.pas` | `THbPageControl` 纯矢量平滑标签页 |
| **停靠悬浮系统** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Dock.pas` | `THbDockSite`, `THbDockPanel` 现代桌面停靠框架 |
| **命令面板** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.CommandPalette.pas` | `THbCommandPalette` 全局 Ctrl+K 动词指令面板 |
| **门禁体检面板** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Gate.pas` | `THbGatePanel` 编译器式规则检查、折叠抽屉、豁免插槽 |
| **虚拟审阅列表** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.VirtualList.pas` | `THbVirtualList` 十万行虚拟审阅队列、多选与批量操作条 |
| **离屏分享卡渲染器** | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.ShareCard.pas` | `THbShareCardRenderer` 4:5 (1080×1350) 矢量长图导出 |
| **VCL 运行时包定义** | `D:\_Progs\02Business\DeepBase\DeepBaseVCL.dpk` | VCL 包注册表 |

---

### 3. FMX 跨平台双胞胎源码 (`FMX/`)

| 控件名称 | 绝对路径 |
|:---|:---|
| **FMX 主题适配器** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Theme.pas` |
| **FMX 色板集合** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Palettes.pas` |
| **FMX 原子控件** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Controls.pas` |
| **FMX 卡片容器** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Cards.pas` |
| **FMX 终端视口** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Terminal.pas` |
| **FMX 标准对话框** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Dialogs.pas` |
| **FMX 语音交互** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Voice.pas` |
| **FMX 托盘图标** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Tray.pas` |
| **FMX 瀑布流** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Waterfall.pas` |
| **FMX 数据网格** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Grid.pas` |
| **FMX AI 控制台** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.AI.pas` |
| **FMX 导航树** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.NavTree.pas` |
| **FMX 标签页** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.PageControl.pas` |
| **FMX 停靠框架** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Dock.pas` |
| **FMX 命令面板** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.CommandPalette.pas` |
| **FMX 门禁面板** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.Gate.pas` |
| **FMX 虚拟列表** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.VirtualList.pas` |
| **FMX 分享卡渲染器** | `D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.HB.ShareCard.pas` |
| **FMX 运行时包定义** | `D:\_Progs\02Business\DeepBase\DeepBaseFMX.dpk` |

---

### 4. 自动化测试套件与执行脚本 (`Tests/` & `Scripts/`)

| 测试文件 | 绝对路径 | 测试范围 |
|:---|:---|:---|
| **DeepRW 专项测试** | `D:\_Progs\02Business\DeepBase\Tests\Test.DeepBase.HB.DeepRW.pas` | 覆盖 CommandPalette, GatePanel, VirtualList, ShareCard 4:5 |
| **HB 全套件综合测试** | `D:\_Progs\02Business\DeepBase\Tests\Test.DeepBase.HB.Suite.pas` | 覆盖 NavTree, DataGrid, Waterfall, AI, Dock, PageControl |
| **主题与设计系统测试** | `D:\_Progs\02Business\DeepBase\Tests\Test.DeepBase.VCL.HB.Theme.pas` | 覆盖 WCAG 对比度、令牌计算、色板注册 |
| **托盘图标与语音测试** | `D:\_Progs\02Business\DeepBase\Tests\Test.DeepBase.HB.Tray.pas`<br>`D:\_Progs\02Business\DeepBase\Tests\Test.DeepBase.HB.Voice.CF.pas` | 覆盖通知事件与音频波形生命周期 |
| **DUnitX 测试工程** | `D:\_Progs\02Business\DeepBase\Tests\DeepBaseTests.dpr` | 全量自动化测试入口 |
| **一键回归执行脚本** | `D:\_Progs\02Business\DeepBase\Scripts\run_tests.ps1` | 自动化编译与 CI 执行脚本 |

**测试执行命令**：
```powershell
powershell -ExecutionPolicy Bypass -File D:\_Progs\02Business\DeepBase\Scripts\run_tests.ps1 -Type Unit -Run "Test.DeepBase.HB"
```

---

### 5. 页面原型与交互展示资产 (`docs/ui/prototypes/`)

| 原型资产 | 绝对路径 | 说明 |
|:---|:---|:---|
| **01. 治理仪表盘** | `D:\_Progs\02Business\DeepBase\docs\ui\prototypes\deeprw\01-governance-dashboard.svg` | 四问看板 + 今日流转变化 + 健康度雷达 |
| **02. 材料阅读器** | `D:\_Progs\02Business\DeepBase\docs\ui\prototypes\deeprw\02-material-reader.svg` | 原文阅读 + 选区浮动动作胶囊 + 锚点列表 |
| **03. 候选审阅队列** | `D:\_Progs\02Business\DeepBase\docs\ui\prototypes\deeprw\03-candidate-review-queue.svg` | VirtualList + 批量操作条 + 7 字段 Inspector + 五态处置 |
| **04. 门禁体检报告** | `D:\_Progs\02Business\DeepBase\docs\ui\prototypes\deeprw\04-gate-panel-report.svg` | GatePanel 全幅 + 展开抽屉 + 申请书面豁免插槽 |
| **05. 主张—证据矩阵** | `D:\_Progs\02Business\DeepBase\docs\ui\prototypes\deeprw\05-claim-evidence-matrix.svg` | DataGrid 冻结列 + 单元格四态状态灯 |
| **交互式 HTML 原型展示** | `D:\_Progs\02Business\DeepBase\docs\ui\prototypes\deeprw-showcase.html` | 浏览器端可交互验证 Ctrl+K、门禁折叠与批量选择 |

---

### 6. 规范与工单基线文档 (`docs/`)

| 文档名称 | 绝对路径 | 说明 |
|:---|:---|:---|
| **DeepRW 需求工单 v2.0** | `D:\_Progs\02Business\DeepBase\docs\ui\work-orders\WO-20260826-DEEPRW-HB-V2.md` | 本次需求的直接源头与验收准则 (🟢 VERIFIED) |
| **视觉基础设施集成指南** | `D:\_Progs\02Business\DeepBase\docs\28.ui.HB视觉基础设施-下游软件集成统一指南.md` | 下游系统接入指南与规范基线 (v1.2) |
| **视觉基础设施技术规范** | `D:\_Progs\02Business\DeepBase\docs\29.ui.HB视觉基础设施总技术规范-实施基线.md` | 架构图、成熟度矩阵与性能标准 (v2.1) |

---

## 三、推荐给审核 AI 的核心检查清单 (Audit Checklist)

请审核 AI 重点关注以下关键指标并给出审查意见：

1. **[代码完整性]**
   - 检查 `DeepBaseCore.dpk`、`DeepBaseVCL.dpk`、`DeepBaseFMX.dpk` 是否无遗漏地包含所有新增单元；
   - 检查各单元 `interface` 与 `implementation` 中的 `uses` 引用是否精简，有无循环依赖。

2. **[Windows GDI+ 与 DPI 缩放安全]**
   - 检查 `DeepBase.VCL.HB.*.pas` 中是否存在没有 Parent 即创建底层 Win32 控件 handle 的逻辑；
   - 检查所有绘图逻辑中字体大小、内边距、圆角是否通过 `ScaleDIP` / `CurrentPPI` 进行动态缩放。

3. **[门禁与状态冗余]**
   - 检查 `THbGatePanel` 中状态指示是否严格遵循「颜色 + 图标 + 文本」三重冗余，避免纯色觉依赖；
   - 检查 `THbVirtualList` 在无选区与有选区时顶部批量操作条的显隐与内存同步逻辑。

4. **[单元测试全绿验证]**
   - 检查 `Test.DeepBase.HB.DeepRW.pas` 与 `Test.DeepBase.HB.Suite.pas` 中的测试用例是否覆盖边界情况（空队列、特殊字符模糊搜索、4:5 尺寸溢出与脱敏掩码等）。

---

*（审核 AI 可直接读取上述任一绝对路径文件进行独立审查）*
