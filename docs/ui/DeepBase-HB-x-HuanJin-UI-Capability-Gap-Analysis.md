# DeepBase HB × 唤金（HuanJin）第一阶段 UI 通用能力差距评审与基础设施设计书

> **文档编号**：`docs/ui/DeepBase-HB-x-HuanJin-UI-Capability-Gap-Analysis.md`  
> **评审角色**：DeepBase 通用 UI 视觉基础设施架构组（通用 UI 基础设施设计人员，非唤金产品经理）  
> **基线版本**：DeepBase v1.2 (`commit 380ff13`) · Delphi 13.1 on Win64 (Pure 0 Error / 0 Warning / 0 Hint)  
> **参考输入**：`docs/27-唤金UI呈现原则与语义规范.md`、`docs/28.ui`、`docs/29.ui`、`docs/30.touchpoint`、HB 核心源码与测试集  
> **设计纪律**：做长期正确的事 · 能组合解决不增控件 · 能留产品层不入基座 · 严格区分 AI 推荐与人类决断 · 严格区分事实差异与警告错误

---

## 一、架构分层与边界定界

在展开能力评审前，必须重申并冻结 DeepBase HB 与唤金（HuanJin）之间的**单向消费架构契约**：

```text
+-----------------------------------------------------------------------------------------------+
|  【唤金领域与业务层】(HuanJin Domain / Application)                                            |
|  • 负责股权关系图谱计算、司法/工商变更事实提取、商机 Lighthouse 评分算法、商业闭环回款状态流转        |
+-----------------------------------------------------------------------------------------------+
                                           │
                                           ▼
+-----------------------------------------------------------------------------------------------+
|  【唤金 UI 语义与呈现层】(HuanJin.UI.Semantics / ViewModels)                                    |
|  • 负责将领域实体映射为 UI 视觉属性（如：股东变更 -> 事实差异展示；AI线索推荐 -> 4个平权动作编排）    |
+-----------------------------------------------------------------------------------------------+
                                           │
                                           ▼
+-----------------------------------------------------------------------------------------------+
|  【唤金平台适配层】(HuanJin.UI.VCL.* / HuanJin.UI.FMX.*)                                      |
|  • 负责组合 HB 基础原语，构建业务卡片（THjRelationshipCard, THjEvidenceDrawer, THjDiffInspector）   |
+-----------------------------------------------------------------------------------------------+
                                           │ 纯消费 / 组装 (只读依赖)
                                           ▼
+-----------------------------------------------------------------------------------------------+
|  【DeepBase HB 视觉基座层】(DeepBase.HB.Core / DeepBase.VCL.HB.* / DeepBase.FMX.HB.*)          |
|  • 纯设计令牌系统 (10 主题 x 2 密度 x DPI 矢量缩放 x 7 类语义 Tone)                               |
|  • 通用原子与复合原语 (Button, Badge, Chip, Card, DisclosureBox, Timeline, EmptyState, Grid 等)  |
|  • 触点状态槽引擎 (Touchpoint & State Slot) / 生命周期管线 (BindToken -> Render -> Telemetry)   |
+-----------------------------------------------------------------------------------------------+
                                           │
                                           ▼
+-----------------------------------------------------------------------------------------------+
|  【原生渲染底层】(Windows GDI+ / VCL GDI / FireMonkey Canvas / Image32)                         |
+-----------------------------------------------------------------------------------------------+
```

### 铁律红线
1. **零业务侵入**：DeepBase 任何单元内严禁出现 `DifferenceCard`、`EvidenceCard`、`RelationshipCard`、`Lighthouse`、`WorthSeeing` 等唤金业务专有名词与类定义。
2. **三不原则**：
   - 能通过现有组件**组合**解决的，绝对不新增控件；
   - 属于单一产品专用的，绝对留在 `HuanJin.UI.*`；
   - 只有**多款商业软件（DeepDsh / DeepRW / Assayer / HuanJin / DeepSync）均有明确复用价值**的视觉原语，才允许进入 DeepBase HB。

---

## 二、当前工程现实（Current Engineering Reality）

基于当前真实 Delphi 源码（`commit 380ff13`）的盘点，HB 实际已交付并验证的通用视觉资产如下：

```text
+---------------------------------------------------------------------------------------------------------+
|                                    HB 视觉基座现有工程资产矩阵                                            |
+-------------------+---------------------------------------+---------------------------------------------+
| 资产分类          | 已交付单元 / 契约                      | 真实工程能力与状态                           |
+-------------------+---------------------------------------+---------------------------------------------+
| 1. 设计令牌核心   | `DeepBase.HB.Core.pas`                | 10 套内置调色板，2 套密度 (Comfortable/Compact)，  |
|                   | `DeepBase.HB.Palettes.pas`            | L0-L5 语义层级，WCAG 2.1 AA 自动对比度校验，  |
|                   |                                       | 3轴 DPI 动态缩放 (ScaleForDPI)              |
+-------------------+---------------------------------------+---------------------------------------------+
| 2. 原子视觉控件   | `DeepBase.VCL.HB.Controls.pas`        | • THbButton (4 Kinds x 3 Sizes x 5 States)  |
|    (VCL & FMX)    | `DeepBase.FMX.HB.Controls.pas`        | • THbDualButton (免费 vs 点数双轨按钮)       |
|                   |                                       | • THbChip & THbBadge (5 种基础 Tone)        |
|                   |                                       | • THbAvatar (哈希散列种子色 + 呼吸状态点)     |
|                   |                                       | • THbProgressRing (环形进度与脉冲动画)       |
|                   |                                       | • THbToast & THbSkeleton (加载骨架屏)        |
|                   |                                       | • THbSectionHeader (分组标题栏 + 数量徽标)   |
+-------------------+---------------------------------------+---------------------------------------------+
| 3. 业务卡片容器   | `DeepBase.VCL.HB.Cards.pas`           | • THbCard (Surface/Sunken/Hero/Outline)     |
|    (VCL & FMX)    | `DeepBase.FMX.HB.Cards.pas`           | • THbStatBig (Hero KPI 指标大字 + 趋势)      |
|                   |                                       | • THbListRow (高密度任务/联系人行)           |
|                   |                                       | • THbEmptyState (引导式空白占位)            |
+-------------------+---------------------------------------+---------------------------------------------+
| 4. 高阶交互套件   | `DeepBase.*.HB.Choice`                | • THbChoiceDeck (0-9 键鼠对等决策卡组)       |
|    (VCL & FMX)    | `DeepBase.*.HB.Dialogs`               | • THbDialog / THbSummaryBar (令牌对话框)    |
|                   | `DeepBase.*.HB.Voice`                 | • THbVoiceDialog (六态语音提取容器)          |
|                   | `DeepBase.*.HB.Tray`                  | • THbTrayIcon / THbTrayMenu (分块托盘菜单)  |
|                   | `DeepBase.*.HB.Waterfall`             | • THbFacetWaterfall (分面瀑布流向导)        |
|                   | `DeepBase.*.HB.Gate`                  | • THbGatePanel (严重度手风琴门禁)           |
|                   | `DeepBase.*.HB.VirtualList`           | • THbVirtualList (10万级 O(1) 虚拟列表)     |
|                   | `DeepBase.*.HB.Grid`                  | • THbDataGrid (类 Excel 高性能数据网格)      |
|                   | `DeepBase.*.HB.AI`                    | • THbAIConsole (思考流 + 差异提案卡)        |
|                   | `DeepBase.*.HB.NavTree`               | • THbNavTree (240px ⇄ 48px 侧栏导轨)       |
|                   | `DeepBase.*.HB.PageControl`           | • THbPageControl (4种现代 Tab 样式)         |
|                   | `DeepBase.*.HB.Dock`                  | • THbDockSite / THbDockPanel (九宫格停靠)   |
|                   | `DeepBase.*.HB.ShareCard`             | • THbShareCardRenderer (离屏成果卡导出)      |
+-------------------+---------------------------------------+---------------------------------------------+
```

---

## 三、现有控件四分类矩阵（KEEP / ENHANCE / NEW PRIMITIVE / HUANJIN ONLY）

针对唤金第一阶段 UI 语义诉求，对所有现有与潜在控件进行严格定界分类：

| 控件 / 原语 | 分类归属 | 决策理由与通用性论证 | 影响范围 |
|---|---|---|---|
| **THbAvatar** | **KEEP** | 头像哈希种子着色、在线/离线呼吸灯状态完整，通用且自洽。 | 无需修改 |
| **THbProgressRing** | **KEEP** | 环形进度与不确定脉冲已完整支持矢量绘制与 DPI 缩放。 | 无需修改 |
| **THbToast / ToastHost** | **KEEP** | 顶层悬浮气泡通知机制完备，动效与超时销毁正常。 | 无需修改 |
| **THbSkeleton** | **KEEP** | Line、Card、Circle 三种骨架扫光占位已覆盖全场景加载。 | 无需修改 |
| **THbSectionHeader** | **KEEP** | 标题 + 徽标计数 + 尾部操作链已能满足各类分组头需求。 | 无需修改 |
| **THbChoiceDeck** | **KEEP** | 0–9 预置选择卡组完美满足键盘快速闭环，可直接被唤金使用。 | 无需修改 |
| **THbVirtualList** | **KEEP** | 10万级虚拟滚动与批量操作栏是工业级通用资产。 | 无需修改 |
| **THbDataGrid** | **KEEP** | 数据网格与选中区域即时统计具备极高复用度。 | 无需修改 |
| **THbNavTree / PageControl / Dock** | **KEEP** | 导航树、多风格选项卡与磁吸停靠均为标准通用基座容器。 | 无需修改 |
| **THbBadge & THbChip** | **ENHANCE** | **现状痛点**：仅支持 5 种传统 Tone（Neutral, Brand, Success, Warning, Danger），无法表达“中性客观变化（Change）”、“提醒复核（Notice）”及“未决/挂起（Unresolved）”。<br>**通用理由**：所有严肃商业系统（审计、版本差异、合规监控）都需要中性 Diff 表达，绝非唤金特有。 | `Core`, `VCL.Controls`, `FMX.Controls` |
| **THbButton** | **ENHANCE** | **现状痛点**：缺少对“AI 推荐”与“人类终局决断”的显式层级区分，容易导致系统建议被错误赋予高对比度 Primary 强视觉权重。<br>**通用理由**：AI 辅助决策系统的核心原则是“推荐 ≠ 人类决断”，需要 `bkRecommended` 与 `bkSubtle` 动作层级。 | `VCL.Controls`, `FMX.Controls` |
| **THbCard** | **ENHANCE** | **现状痛点**：当前仅有 4 种背景样式，缺少 `ckGhost`（透明透底容器）与 `ckQuiet`（柔和静默底色），且缺少标准化的子区域排版布局契约。<br>**通用理由**：卡片复合嵌套是现代桌面 UI 基础规范。 | `VCL.Cards`, `FMX.Cards` |
| **THbEmptyState** | **ENHANCE** | **现状痛点**：仅能表达“无数据 / 空白”，无法表达“系统运转正常，天下太平，今日无需打扰用户”的静默确认语义。<br>**通用理由**：Zero-Inbox / All-Clear 是监控、安全与治理类软件的标准通用模式。 | `VCL.Cards`, `FMX.Cards` |
| **THbListRow** | **ENHANCE** | **现状痛点**：内建了早期商业化实验硬编码字段（`FreeButtonText`、`PointsCost`）。<br>**通用理由**：需解耦为通用双动作/状态徽标插槽，消除历史残留。 | `VCL.Cards`, `FMX.Cards` |
| **THbDisclosureBox** | **NEW PRIMITIVE** | **通用理由**：提供独立的“标题栏 + 展开折叠指示器 + 摘要徽标 + 自适应内容容器”。多产品（DeepRW 引用折叠、DeepDsh 执行详情、唤金证据链）高度通用。无法通过简单 Button 优雅组合。 | `Core.Types`, `VCL.Controls`, `FMX.Controls` |
| **THbTimeline / Item** | **NEW PRIMITIVE** | **通用理由**：通用的“时间节点 + 连接导轨 + 时间戳 + 内容槽”视觉原语。适用于事件溯源、审计日志、多阶段流水线。 | `Core.Types`, `VCL.Controls`, `FMX.Controls` |
| **THjRelationshipCard** | **HUANJIN ONLY** | 股权穿透关系图谱、受益所有人比例计算、控制路径渲染。 | 留在 `HuanJin.UI.*` |
| **THjEvidenceDrawer** | **HUANJIN ONLY** | 裁判文书网判决书关联链、工商登记底档原件核对、司法公示核验。 | 留在 `HuanJin.UI.*` |
| **THjDifferenceInspector** | **HUANJIN ONLY** | 财报三表科目差异比对表、营业执照经营范围文本 Diff 业务规则。 | 留在 `HuanJin.UI.*` |
| **THjLighthousePanel** | **HUANJIN ONLY** | 商业意向打分算法、潜客价值转化漏斗、商机评级看板。 | 留在 `HuanJin.UI.*` |
| **THjOutcomeFeedbackCard**| **HUANJIN ONLY** | 商务闭环佣金回款追踪、销售签约状态回执、交易网关状态流。 | 留在 `HuanJin.UI.*` |

---

## 四、6 类核心通用能力差距深度评审

### 1. 语义色与状态令牌差距（Semantic Tone Gap: Difference ≠ Warning / Danger）

#### 根因剖析
传统 Web/桌面组件库习惯将状态粗暴简化为四色灯（Success=绿, Warning=黄, Danger=红, Info=蓝）。
但在商业与法律事实治理中：
- **事实差异（Difference）不是错误**：企业法人变更、注册资本增加是客观事实，既不是 Warning 警告，更不是 Danger 危险。强行使用黄色会引发用户不必要的焦虑，使用红色会导致警报疲劳（Alert Fatigue）。
- **未决/挂起（Unresolved）不是中性空闲**：等待第三方数据源同步或等待人工核验，具有明确的“待决”语义，不能等同于普通的 `btNeutral` 灰度文字。
- **上下文提示（Notice）不是系统消息**：AI 或规则引擎给出的复核提示属于温和建议，不应采用高饱和度的 Info 蓝。

#### HB 解决方案
在 `THbTokens` 与 `THbBadgeTone` 中扩充通用语义 Tone，建立 7 维状态色阶矩阵：

```text
+-----------------------------------------------------------------------------------------------+
|                                    HB 语义色阶矩阵 (Semantic Tones)                             |
+---------------+-------------------+-----------------------+-----------------------------------+
| 语义 Tone     | 推荐色相 (HSL)    | 典型 ARGB (Light)     | 适用通用场景 (Framework Standard)  |
+---------------+-------------------+-----------------------+-----------------------------------+
| `stBrand`     | 品牌主色 (暖金)   | `#D97706` (Amber-600) | 品牌锚点、核心主流程高亮          |
| `stNeutral`   | 稳重石灰 (Stone)  | `#78716C` (Stone-500) | 静态事实、次要元数据、非活动标签  |
| `stChange`    | 中性质感青 (Teal) | `#0F766E` (Teal-700)  | 客观事实变更、版本差异对比 (Diff) |
| `stNotice`    | 智慧鸢尾紫(Indigo)| `#4F46E5` (Indigo-600)| 建议复核、上下文提示、线索高亮    |
| `stUnresolved`| 待决琥珀橙 (Amber)| `#D97706` (Amber-600) | 挂起、暂缓处理、等待第三方确认    |
| `stSuccess`   | 确认翡翠绿(Emerald)|`#059669` (Emerald-600)| 校验通过、积极结果、闭环达成      |
| `stDanger`    | 警示玫瑰红 (Rose) | `#E11D48` (Rose-600)  | 不可逆破坏性操作、阻断性门禁失败  |
+---------------+-------------------+-----------------------+-----------------------------------+
```

---

### 2. 渐进式展开差距（Progressive Disclosure Gap）

#### 根因剖析
- 现有 HB 的展开折叠能力内嵌在 `THbFacetWaterfall`（瀑布流）与 `THbGatePanel`（门禁手风琴）中，属于特定复合组件的私有逻辑。
- 唤金及其他业务系统需要将“事实证据”或“详细日志”默认收敛为一行安静的摘要（如：`3 条工商变更事实 [展开详情 ▾]`），仅当用户需要核对证据链时才平滑展开。

#### HB 解决方案：新增 `THbDisclosureBox` 通用原语
- **职责**：纯容器与展开交互控制器。
- **结构契约**：
  - `Header`: 左侧标题/Icon + 状态徽标 (`Badge`) + 摘要文本 (`Summary`) + 右侧折叠指示符 (`Chevron`)；
  - `Body Container`: 容纳任意子控件的面板，支持自动测量高度与动画过渡；
  - `Interaction`: 鼠标整行 Hover 高亮，点击切换展开；键盘 `Space` / `Enter` 触发折叠；`FocusRing` 规范支持。
- **纯粹性保证**：不包含任何“证据”、“判决书”字段，仅对外暴露 `Title`、`Summary`、`Expanded: Boolean`、`Tone: THbBadgeTone`。

```text
+-----------------------------------------------------------------------------------------------+
|  THbDisclosureBox 结构图                                                                       |
|                                                                                               |
|  [▾]  工商登记变更记录 (2026-08)   [已核验·btSuccess]   共 3 项变更记录           [折叠 ▴]     |
|  +-----------------------------------------------------------------------------------------+  |
|  |  (展开区域：可嵌入 THbTimeline、THbDataGrid 或业务自定义 View)                          |  |
|  |  • 2026-08-12: 注册资本由 1000 万变更为 5000 万                                          |  |
|  |  • 2026-08-15: 法定代表人变更                                                            |  |
|  +-----------------------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------------------+
```

---

### 3. 卡片复合结构差距（Card Composition Gap）

#### 根因剖析
当前 `THbCard` 是一个纯背景/边框容器控件（`TCustomControl`），内部没有固化的排版槽位。如果针对每个业务卡片都在 HB 中衍生一个完整类（如 `THbDifferenceCard`、`THbEvidenceCard`），会导致基座类爆炸、职责混乱且严重违背 SSOT 原则。

#### HB 解决方案：采用轻量级复合槽位模式（Composition Slots）
在 `THbCard` 体系中提供标准化的结构规范与子区域辅助类，供业务层在卡片内自顶向下装配：

1. **Card Header Area**：利用 `THbSectionHeader` 或标准顶部排版（标题 + 副标题 + 状态 Badge + 快捷操作）；
2. **Card Meta Grid Area**：利用 `THbKeyValRow` 或 2/3 列网格，高密度展示结构化元数据；
3. **Card Disclosure Area**：嵌入 `THbDisclosureBox` 展示次级证明细节；
4. **Card Action Row Area**：底部平权动作按钮栏（右对齐或双端分布）；
5. **Card Footer / Return Area**：柔和底色区，展示处理回执或归档状态。

---

### 4. 动作层级差距（Action Hierarchy: Recommendation ≠ Human Decision）

#### 根因剖析
传统 UI 的 Button 只有 `Primary`（主色高亮）和 `Secondary` / `Ghost`（描边/透明）。
当 AI 给出推荐建议时，如果直接套用 `bkPrimary`：
- 界面上充斥着大面积高饱和度实体按钮，产生强烈的“系统代用户拍板”的压迫感；
- 用户容易误以为该动作已经被执行，或者这是唯一的合法操作；
- “观察”、“暂缓”、“不处理”、“退出”等理性决断被贬低为不可见的弱按钮，破坏了人机协同的平权原则。

#### HB 解决方案：规范四级动作层级
在 `THbBtnKind` / `THbButtonKind` 中确立显式层级：

```text
+-----------------------------------------------------------------------------------------------+
|                                    HB 按钮动作层级规范                                        |
+---------------+-------------------+-----------------------+-----------------------------------+
| 按钮种类      | 视觉形态          | 心理暗示              | 语义定界                          |
+---------------+-------------------+-----------------------+-----------------------------------+
| `bkPrimary`   | 实体品牌金底 + 白字| "我已确认，执行终局"  | **人类最终决断**（签名、提交、执行）|
| `bkRecommended`| 浅金底 + 品牌金字  | "系统建议，供您参考"  | **AI 推荐方案**（非强制，温和指引）|
|               | + 柔和虚线/实线边框|                       |                                   |
| `bkSoft`      | 浅灰底 + 深灰字   | "合法选项，平权考量"  | **观察 / 暂缓 / 补充材料**         |
| `bkGhost`     | 透明底 + 灰字/细边框| "退后一步，保持现状"  | **忽略 / 不处理 / 退出 / 取消**    |
| `bkDanger`    | 实体玫瑰红底 + 白字| "高危操作，谨慎破坏"  | **彻底删除 / 撤销资格 / 阻断**    |
+---------------+-------------------+-----------------------+-----------------------------------+
```

---

### 5. 时间线原语差距（Timeline Primitive Gap）

#### 根因剖析
多产品均存在时间维度的事实流水需求：
- `DeepRW`：资料检索与学术证据时间流；
- `DeepDsh`：自动化脚本阶段执行流；
- `HuanJin`：企业工商变更历史、历史触达与跟进时间线。
当前 HB 缺少一个轻量级、纯矢量绘制的 `THbTimeline` 容器。

#### HB 解决方案：新增 `THbTimeline` 原语
- **契约定义** (`DeepBase.HB.Timeline.Types.pas`)：
  - `THbTimelineNodeKind = (tnkDot, tnkRing, tnkIcon);`
  - `THbTimelineItem = record`：`Timestamp: string`、`Title: string`、`Subtitle: string`、`Tone: THbBadgeTone`、`NodeKind: THbTimelineNodeKind`、`CustomData: Pointer`；
- **渲染特征**：
  - 自动绘制垂直连续导轨（`Tokens.Border`）；
  - 节点根据 `Tone` 绘制外发光环或实心点；
  - 完美支持 High-DPI 与 Dark/Light 主题切换。

---

### 6. 静默与完全正常状态差距（Quiet / All-Clear State Gap）

#### 根因剖析
现有 `THbEmptyState` 主要针对“数据列表为空”场景，其视觉呈现通常带有一定的“引导去创建内容”的呼吁（CTA 按钮）。
但在商业风险治理、合规扫描、线索监控等场景中：
- “今日暂无待办事项”代表**系统运行极其良好、没有风险需要打扰用户**；
- 这种状态不是“缺失（Empty）”，而是“平安（All Clear）”；
- 强行显示一个空盒子图画与“新建任务”按钮，完全破坏了安静严肃的商业感。

#### 决策裁定：采用【方案 A - 增强 THbEmptyState】
- **为什么不选方案 B（新建独立类）**：视觉骨架完全一致（Icon/Glyph + Title + Hint + Optional Action），新建类会导致冗余代码和认知分叉。
- **为什么不选方案 C（留在产品层）**：All-Clear / Zero-Inbox 是现代桌面商业系统的通用模式，基座应原生支持。
- **增强实现**：
  - 增加属性 `Mode: THbEmptyStateMode = (esmNoData, esmAllClear, esmFilteredEmpty, esmOffline);`
  - 当 `Mode = esmAllClear` 时，默认使用 `Tokens.SurfaceQuiet` 与翡翠绿轻柔勾选图标，提示语呈现从容、安静的文案风格，隐藏激进的操作按钮。

---

## 五、VCL 与 FMX 跨平台现实对照矩阵

任何 HB 的能力扩展都必须在 VCL 和 FMX 双框架上对等落地：

```text
+----------------------------------------------------------------------------------------------------+
|                                    VCL vs FMX 跨平台实现现实矩阵                                    |
+----------------------+------------------------------------+----------------------------------------+
| 评估维度             | VCL 实现路径 (Win64)               | FMX 实现路径 (Cross-Platform)          |
+----------------------+------------------------------------+----------------------------------------+
| **矢量绘制引擎**     | Windows GDI+ (`TGPGraphicsPath`,   | FMX Canvas (`TPathData`,               |
|                      | `TGPSolidBrush`, `TGPPen`)         | `TStrokeBrush`, `TFillBrush`)          |
| **DPI 适配机制**     | Per-Monitor v2 (`WM_DPICHANGED` +  | 自动场景缩放 (`Scene.GetSceneScale`) +  |
|                      | `ScaleForDPI` 手动 DIP 换算)       | 逻辑像素坐标系统                       |
| **主题感知与广播**   | `WM_HB_THEME_CHANGED` 窗口消息 +   | `TMessageManager` 跨平台解耦广播 +     |
|                      | `THbTheme.AddListener` 回调        | `OnThemeChangedMessage` 接收           |
| **焦点与键盘导航**   | `WM_SETFOCUS` / `WM_KILLFOCUS` +   | `DoEnter` / `DoExit` +                 |
|                      | GDI+ 绘制外发光 FocusRing          | `Canvas.DrawRect` 焦点外框             |
| **容器嵌套与重绘**   | 必须显式处理 `WS_CLIPCHILDREN` 与  | 自动树状层级渲染，透明度与裁切原生支持 |
|                      | 双缓冲擦除 (`WMEraseBkgnd`)        |                                        |
| **字体渲染一致性**   | `GDI+ StringFormat` 垂直居中校准   | `TCanvas.FillText` 跨平台文本度量      |
+----------------------+------------------------------------+----------------------------------------+
```

---

## 六、HB 建议修改文件清单

为达成上述通用基础设施增强，HB 需要修改与新增的实际文件如下：

```text
+----------------------------------------------------------------------------------------------------+
|                                      HB 代码修改与新增清单                                         |
+-----------------------------------+-----------+----------------------------------------------------+
| 文件路径                          | 变动类型  | 变更内容说明                                       |
+-----------------------------------+-----------+----------------------------------------------------+
| `Core/DeepBase.HB.Core.pas`       | [MODIFY]  | • 扩展 `THbBadgeTone` (btChange, btNotice, etc.)   |
|                                   |           | • 扩展 `THbTokens` (Change, Notice, SurfaceQuiet) |
|                                   |           | • 扩展 JSON 主题解析器与默认 WarmGold 令牌值        |
| `Core/DeepBase.HB.Palettes.pas`   | [MODIFY]  | • 为 10 套内置主题补充 Change/Notice/Quiet 颜色定义 |
| `Core/DeepBase.HB.Timeline.Types` | [NEW]     | • 定义时间线共享数据契约 (NodeKind, Item, List)    |
| `VCL/DeepBase.VCL.HB.Controls.pas`| [MODIFY]  | • `THbButton` 增加 `bkRecommended` / `bkSubtle`    |
|                                   |           | • `THbBadge` & `THbChip` 支持扩展 7 类 Tone 绘制   |
|                                   |           | • 实现 `THbDisclosureBox` VCL 控件                 |
|                                   |           | • 实现 `THbTimeline` VCL 控件                      |
| `VCL/DeepBase.VCL.HB.Cards.pas`   | [MODIFY]  | • `THbCard` 增加 `ckGhost` / `ckQuiet` 样式        |
|                                   |           | • `THbEmptyState` 增加 `esmAllClear` 静默模式      |
|                                   |           | • `THbListRow` 解耦历史点数硬编码字段              |
| `FMX/DeepBase.FMX.HB.Controls.pas`| [MODIFY]  | • 同步实现 FMX 端的 Button/Badge/Chip 增强与       |
|                                   |           |   `THbDisclosureBox` / `THbTimeline` 孪生对等控件  |
| `FMX/DeepBase.FMX.HB.Cards.pas`   | [MODIFY]  | • 同步实现 FMX 端的 Card / EmptyState 增强         |
| `Tests/Test.DeepBase.HB.Suite.pas`| [MODIFY]  | • 补充新增 Tone、Disclosure、Timeline 的全量单测   |
+-----------------------------------+-----------+----------------------------------------------------+
```

---

## 七、Gallery 增补演示计划（Examples / HbGallery）

在控件画廊中增加专项对照演示看板，证明其通用性与稳定性：

1. **Semantic Tone 7色矩阵横向对比**：
   - 展示 `Neutral`、`Brand`、`Success`、`Warning`、`Danger`、`Change`、`Notice`、`Unresolved` 在同一基准卡片上的视觉对比；
   - 证明 `Change`（客观事实差异）与 `Warning`（警告错误）具有清晰可辨的视觉心理区分。
2. **Action Hierarchy 动作层级沙盘**：
   - 模拟一组真实的商业决断场景：`[AI建议采纳 (bkRecommended)]` + `[观察 (bkSoft)]` + `[暂缓 (bkSoft)]` + `[终局签约 (bkPrimary)]`；
   - 证明各操作具有合法视觉地位，不会产生界面强迫感。
3. **Disclosure & Timeline 动态联动**：
   - 演示带有 3 个节点的时间线，在折叠状态下仅占 36px 高度，点击展开后平滑展示 180px 证据链。
4. **全维度环境验证**：
   - 覆盖 Light / Dark、Comfortable / Compact、DPI 100% / 150% / 200%、Hover / Focus / Disabled 各种组合。

---

## 八、拒斥清单（严格禁止进入 HB 的唤金专用需求）

以下需求经审查属于唤金业务产品层专有逻辑，**坚决拒绝进入 DeepBase HB**：

```text
+----------------------------------------------------------------------------------------------------+
|                                      HB 架构拒斥清单                                               |
+-----------------------------------+----------------------------------------------------------------+
| 被拒斥的产品级需求                | 拒斥的技术与架构理由                                           |
+-----------------------------------+----------------------------------------------------------------+
| 1. `THbDifferenceCard`            | 包含工商财报对比特定业务逻辑，应由 `HuanJin.UI` 组合           |
|                                   | `THbCard` + `THbBadge(btChange)` + `THbDisclosureBox` 实现。   |
+-----------------------------------+----------------------------------------------------------------+
| 2. `THbEvidenceCard` / Drawer     | 包含裁判文书、公示档案等专有数据模型，应由 `HuanJin.UI`        |
|                                   | 组合 `THbCard` + `THbTimeline` + `THbVirtualList` 实现。       |
+-----------------------------------+----------------------------------------------------------------+
| 3. `THbRelationshipCard` / Graph  | 股权穿透拓扑图是垂直行业图分析算法，不属于通用桌面排版原语。   |
+-----------------------------------+----------------------------------------------------------------+
| 4. `THbLighthousePanel`           | 商机评分模型与加权漏斗算法是唤金核心商业机密，严禁污染基座。   |
+-----------------------------------+----------------------------------------------------------------+
| 5. `THbOutcomeFeedbackCard`       | 业务交易回执与佣金流转属于应用业务流程，非通用 UI 控件。       |
+-----------------------------------+----------------------------------------------------------------+
```

---

## 九、给唤金（HuanJin）UI 设计人员的能力交付说明

### 1. HB 能够直接为您提供的通用能力
- **完美的物理排版与令牌驱动**：10 套主题、暗黑模式、Compact 紧凑模式与高分屏 DPI 无缝自适应；
- **客观事实差异表达**：使用 `THbBadge` / `THbChip` 的 `btChange` 色标，优雅表达中性工商/数据变更；
- **从容的证据展开交互**：使用 `THbDisclosureBox` 构建“默认安静、按需展开”的证据核验区；
- **平衡的人机动作层级**：使用 `bkRecommended` 呈现 AI 建议，使用 `bkPrimary` 呈现用户拍板，使用 `bkSoft`/`bkGhost` 呈现观察与退出；
- **天下太平的静默确认**：使用 `THbEmptyState(esmAllClear)` 传达“系统一切正常，今日无打扰”的高级平静感。

### 2. 需要唤金 UI 层自行编排与封装的部分
- 唤金页面请在 `HuanJin.UI.VCL.*` / `HuanJin.UI.FMX.*` 中建立业务级复合组件（如 `THjContactFactCard`）；
- 业务卡片内部通过纯组合（Composition）方式引用 HB 的 `THbCard`、`THbDisclosureBox`、`THbButton`；
- 领域模型（DTO / Entity）与视觉状态的绑定由唤金 ViewModel 负责。

---

## 十、一并提问：需要唤金 UI 与产品设计师确认的技术细节

为确保基础设施对下游支撑的严丝合缝，请唤金 UI 设计师明确以下 4 个工程细节：

1. **事实差异色标（btChange）的情感倾向**：
   - 目前基座拟采用 **中性质感青（Slate Teal `#0F766E`）** 作为客观事实差异的代表色。请确认在唤金的商业语境中，该色调是否能在与绿色（Success 确认）和蓝色（Info 提示）并存时，保持清晰的辨识度且不引发误判？
2. **渐进式展开（THbDisclosureBox）的高度自适应模式**：
   - 证据展开区在默认装配时，唤金更倾向于**根据内部子控件内容自适应撑开高度（Auto-Height）**，还是**设定最大高度并支持内部虚拟滚动（Max-Height with Scroll）**？
3. **四级平权动作栏的排布惯例**：
   - 在事实卡片底部的 4 个动作（如：`[采纳建议]`、`[继续观察]`、`[暂缓]`、`[忽略]`）中，唤金 UI 是否要求**主次操作严格固定左右顺序**（例如：AI 推荐固定居左，观察/暂缓居中，终局决断固定居右）？
4. **时间线节点密度与嵌套诉求**：
   - 在企业工商变更或跟进时间线中，单个 Timeline Item 内部是否需要支持嵌套二级子时间线，还是单层线性流水即满足第一阶段全部场景？

---
*DeepBase HB 视觉基础设施架构组 · 2026-09-06*
