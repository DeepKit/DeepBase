# DeepBase 任务清单与审查跟踪

> 本文件只保留**未完成**与**进行中**工作。已完成任务见 `history.md`，
> 逐条 Bug 详情见 `bugfix.md`（BUG-CR-xxx 编号），完整审查报告见 `docs/code-review-2026-08-24.md`。
> 状态图例：☐ 未开始 · 🔧 进行中 · ✅ 已完成/已修复（回归通过）· ⏸ 暂缓 · ❌ 不做（注理由）
> 提交规则：Delphi 13.1 (Compiler 37) on Win64，优先采用现代语法，每个 ✅ 必须附 DUnitX 回归并通过编译门禁。

## 当前基线

- 编译器环境: Embarcadero Delphi 13.1 (Florence / Compiler 37.0) on Win64 (`dcc64.exe`)
- 单测基线: 4300 found / ~4290 passed
- 当前主线: **HB 视觉基础设施 (HB Visual Infrastructure · DeepBase.VCL.HB.*)**

---

## 🚀 一、HB 视觉基础设施建设 (DeepBase.VCL.HB.*) [全栈已交付 ✅]

> 依据 `docs/26.ui.HB视觉基础设施-主题令牌与组件画廊.html` 规范进行开发与双轨验收。
> 编译环境: Delphi 13.1 (Florence / Compiler 37.0) on Win64 (`dcc64.exe`)

### 阶段 1: 主题令牌引擎与数据资产 (Theme Token Engine & Assets)
- [x] **1.1 主题 JSON 资产**: 在 `assets/themes/` 建立 10 套内置主题 JSON（暖金、墨金、靛青学术、石墨专业、翡翠、陶玫、霜白高对比、沧海蓝·暗、紫暮·暗、茶青），支持 `inherits` 差分继承机制
- [x] **1.2 资源编译与嵌入**: 编写 `DeepBase.VCL.HB.Palettes.rc` 将 10 套 JSON 编译为 `RC_DATA` 嵌入资源，并编写 `DeepBase.VCL.HB.Palettes.pas`
- [x] **1.3 核心令牌与引擎单元**: 编写 `DeepBase.VCL.HB.Theme.pas`，实现 `THbTokens` 结构体（字阶、间距、圆角、阴影、动效、三轴计算：色相×明暗×密度）、WCAG AA 运行时对比度断言、DB1 设置联动与主题切换广播
- [x] **1.4 令牌单元单测**: 编写 `Tests/Test.DeepBase.VCL.HB.Theme.pas`，覆盖 10 套主题解析、`inherits` 继承覆盖、WCAG 断言、三轴缩放计算

### 阶段 2: 基础原子自绘控件族 (HB Core Vector Controls)
- [x] **2.1 控件基础基类**: 建立 `THbControl`（基于 GDI+ / `TCustomControl`），原生支持 Normal/Hover/Pressed/Disabled/Focus 五态与 `FocusRing` 绘制、高 DPI 与 Density 复合缩放
- [x] **2.2 基础按钮与双轨钮**: 实现 `THbButton`（四型×三尺寸×五态）与 `THbDualButton`（免费轨/AI点数轨双钮 + 悬浮换算提示 + 确认流程）
- [x] **2.3 标签与徽章**: 实现 `THbChip`（切片标签/选中反色/可关闭）与 `THbBadge`（语义背景徽章）
- [x] **2.4 辅助交互原子**: 实现 `THbAvatar`（名字哈希背景色 + 呼吸孔）、`THbProgressRing`（进度环/扫光动效）、`THbToast`（轻提示/自动滑入/倒计时）、`THbSkeleton`（骨架屏/扫光动效）、`THbSectionHeader`（区头与折叠指示）
- [x] **2.5 原子控件单元归属**: 汇总并暴露于 `DeepBase.VCL.HB.Controls.pas`

### 阶段 3: 业务复合卡片与容器 (Business Cards & Containers)
- [x] **3.1 容器与卡片**: 实现 `THbCard`（ckSurface / ckSunken / ckHero / ckOutline 四型、圆角映射、阴影海拔、密度内边距）
- [x] **3.2 KPI 与度量展示**: 实现 `THbStatBig`（英雄数字、大字阶、涨跌趋势指示）
- [x] **3.3 业务名单行**: 实现 `THbListRow`（内嵌头像哈希、沉睡标签截断、上下文线索提示、内嵌双轨按钮、处理后置灰）
- [x] **3.4 引导与空态**: 实现 `THbEmptyState`（图标/插画占位、引导标题、操作行动按钮）
- [x] **3.5 复合控件单元归属**: 汇总并暴露于 `DeepBase.VCL.HB.Cards.pas`

### 阶段 4: 包集成与画廊双轨验收 (Package Integration & Gallery)
- [x] **4.1 包配置更新**: 将 `DeepBase.VCL.HB.Theme.pas`、`Palettes.pas`、`Controls.pas`、`Cards.pas` 编入 `DeepBaseVCL.dpk`，通过 Win64 严格包编译门禁
- [x] **4.2 画廊对照工程**: 构建 `Tools/Gallery/hbtheme_gallery.dpr`，渲染 12 个组件与 10 套主题矩阵，并与 `26.ui.HB视觉基础设施...html` 进行双轨人工/截图验收
- [x] **4.3 CI 门禁检查**: 单元测试 `Test.DeepBase.VCL.HB.Theme` 纳入 `DeepBaseTests.dpr` 自动化门禁

### 阶段 5: 集成文档与 Schema 规范同步
- [x] **5.1 快速入门指南**: 更新 `docs/00.quickstart.AI集成总览-ai-one-file.md` 与 `docs/02.quickstart.下游接入流程-downstream-integration.md`
- [x] **5.2 控件与设计规范**: 更新 `docs/25.ui.VCL-FMX控件规范.md` 与 `docs/26.ui.HB视觉基础设施-主题令牌与组件画廊.html`
- [x] **5.3 数据库 Schema 说明**: 更新 `docs/30.data.数据库Schema说明-database-schema.md` 关于 `Themes` 与 `Settings` 的键值说明

---

## 二、🔧 P0 待环境验证转正（7 条）

| ID | 验证动作 | 涉及 |
|---|---|---|
| CR-002 | POSIX 冒烟：OpenSSL_RandomBytes(16)+PBKDF2 加解密往返 | Core\DeepBase.Crypto.OpenSSL.pas |
| CR-003 | PG 实测出队（语法已修正，需真库） | Persistence\DeepBase.DB.JobQueue.pas |
| CR-005 | 补 >2^53 整数绑定专项用例（编译已过 dcc64） | doQry\src\uDoQryExecutor.pas |
| CR-006/007/012 | 运行时用例（**dcc64 编译验证已过**，Scripts\verify_doqry.ps1） | doQry\uDoQryLegacy.pas |
| CR-014 | PG 实测删除用户/角色事务路径 | Authorization.FireDAC |

## 三、⏸ 环境受限排查

| ID | 内容 |
|---|---|
| CR-606 | Perception 两测试（StaticPair/InjectedBitmap_FlowsThroughFrameDifferGate）在本 VM 确定性失败；代码链路走读无异常，需图形完整会话复跑；同步开启 DPI 感知对照 |
| CR-608 | Test_PreparedPool_ConcurrentSameSql 偶发（AV 一次 / 竞态 Expected0 got1 一次）；排查 DeepBase.DB.DoQry prepared-pool 并发领取路径 |

## 四、🟡 剩余子项（按模块）

### Core
- [ ] CR-268 余项：edmAsync handler 异常接入 OnError 统计通道
- [ ] CR-283 余项：序列化默认可见性决策3仅覆盖 JSON 根对象——XML/Binary 嵌套空对象行为待 Owner 追加决策
- [ ] CR-284 余项：Reflection FromString 可诊断化 / DeepClone 真递归 / 列表识别结构化判定
- [ ] CR-286 余项：Template 未闭合标签报错 / 自定义分隔符 / 引号感知切分
- [ ] CR-287 余项：CompareChars 代理对 / Apply 换行保真 / IgnoreBlankLines 实现 / IsBinary 规则统一
- [ ] CR-288 余项：插件加载 psLoading 拒绝 / 门禁回滚 / GetMetadata 泄漏 / 拓扑排序 / 大小写统一
- [ ] CR-289 余项：Finalize 锁内复查 / WhenReady 入锁 / InitializeModules 失败回滚
- [ ] CR-291 余项：Bulkhead 快速路径空等 / 析构排空
- [ ] CR-292 余项：IgnoreIf 守卫生效 / 动作锁外化+重入检测 / FromJSON 白名单
- [ ] CR-293 余项：UpdateUser 合并活体 / token 单临界区+哈希存储 / 审计异步投递
- [ ] CR-295 余项：CheckAll 原子性 / TryExecute 异常保类型
- [ ] CR-299 余项：ISO 偏移量与小数秒支持
- [ ] CR-310 余项：Plural 小数操作数 Invariant 化
- [ ] CR-311 余项：MVVM 错误回调保类型 / 关停悬空 SelfRef
- [ ] CR-313 余项：CSV 公式前缀 / DOCX 属性转义复核
- [ ] CR-317 余项：GBK 乱码注释文件 UTF-8 重写（TestHelper/Constants 等）

### Persistence
- [ ] CR-231 Migrations 数值排序
- [ ] CR-233 EnsureSchemaIfNeeded 原子化
- [ ] CR-235 StatusMachine 乐观守卫+裸指针收敛
- [ ] CR-236 ORM Count 方言 / CreateTable PG 分支
- [ ] CR-240 Logging legacy 回退一次性切换 / 枚举范围钳制

### Tools/Infra
- [ ] 将 doQry 纳入主测试图（引入真 DBClient 或沿用 Tools\DBClientStub 于 CI）
- [ ] Scripts\verify_doqry.ps1 接入 CI 门禁

## 五、🔵 Backlog（低优）

- CR-601 性能族：LRU O(n)、日志每条开关文件、O(n²) 字符串累加、TFDQuery 逐调用创建
- CR-602 安全加固族：取模偏差、迭代上限、HTML/CSV 转义、WM_COPYDATA 校验
- CR-603 API 语义族：cepNone 抛异常、Exists LIMIT 1、ReDeepMoveCallback 更名
- CR-604 卫生族：Schema 空行整理、VER350 订正、CompilerVersion 注释订正
- CR-605 备注：Config 写门禁 4000 已校准；若实现连接级语句缓存可回调 5000
- CR-607 二进制流式 API 原生 raw-stream 重载（去 Base64 中转）
- CR-608 见上（与三合并排查）
- 新增: doQry Logger JsonEscape 修复后补运行时断言用例
- 新增: 存量库 App.LogLevel 迁移 UPDATE 已随种子执行，观察一个版本后可移除该语句

---

# [HB-20260824] HB Visual Infrastructure 本体开发计划（DeepBase.VCL.HB.* / DeepBase.FMX.HB.*）

> 发起：老板 2026-08-24 裁定。目标：全 Skia4Delphi 矢量自绘 + Token 驱动主题系统，替代 VCL Styles。
> 编译器：dcc64.exe @ "D:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe"（Delphi 13.1 / Win64）
> 语法纪律：尽量用 13.1 新语法——inline var(`var x := expr`)、inline const、{$SCOPEDENUMS ON} 强类型枚举、泛型与匿名方法(reference to)类型推断、record helper；禁旧式 Tr()、禁运行时 Create(nil) 控件。

## HB-0 地基层
- [ ] HB-0.1 令牌系统：theme-tokens JSON 单一事实源（10 主题 × 亮/暗 × 密度三轴），运行时解析器 TThemeTokens；暗色=亮色差分令牌继承，不重复定义全集
- [ ] HB-0.2 渲染基底：Skia 画布管理封装。Delphi 12 起 RTL 官方内置 Skia（System.Skia / Vcl.Skia / FMX.Skia），直接使用内置单元，禁止再引第三方 Skia4Delphi 安装包造成双 Skia 冲突
- [ ] HB-0.3 组件基类 THbVisual = class(TGraphicControl)：强制五态状态机 Normal/Hover/Pressed/Disabled/Focus，缺一态不予合入
- [ ] HB-0.4 DPI：Per-Monitor V2 清单启用 + 缩放管线在 100%/125%/150%/200% 四档截图回归，矢量不发虚
## HB-1 核心原子组件（VCL/FMX 孪生实现，几何与令牌逻辑共享单元）
- [ ] THbDualButton：免费轨/AI 点数消耗轨并排双钮，内建 ≈¥ 金额透明提示；对接 DeepCommerce 点数模型（1 元=1000 点）
- [ ] THbListRow：高密度名单行（沉睡标签/上下文线索/哈希头像/双轨行动钮/已处理置灰）
- [ ] THbStatBig / THbCard：KPI 英雄数字、渐变成果卡、凹陷容器
- [ ] THbAvatar：名字哈希确定性背景色 + 在线状态呼吸孔
- [ ] THbProgressRing / THbToast / THbSkeleton：进度环、轻量通知、扫光骨架屏
- [ ] THbChip / THbBadge：切片筛选器、状态徽章
## HB-2 十套内置主题
暖金、墨金、靛青学术、石墨专业、翡翠生活、陶玫、霜白高对比(无障碍)、沧海蓝·暗、紫暮·暗、茶青
## HB-3 密度轴
紧凑 0.85（笔记本小屏一屏多行）/ 舒适 1.0；触屏宿主（DeepInput 类）锁死舒适档 API
## HB-4 验收门
- [ ] DemoHost 工程：一屏铺满全部组件 × 全部主题 × 两密度 × 五态矩阵
- [ ] 编译：dcc64(37.0) -Q -B 零 Error 零 Warning（Hint 允许）
- [ ] 主干打 tag hb-v1.0 后立即开放 P0 产品换脸（不等全部完成）

## [HB-20260824 补充裁定] 平台收敛
- [ ] Delphi 12 已废弃：HB 仅支持 13.1 (Studio 37.0)，零兼容层；总控计划见 02Business/tasks.md #3，本仓代码落点默认 HB/src（Q1 待确认即动工）

## [2026-08-25 同事开发检测] Amy 让位记录
- [x] 检测：VCL/ 下四个 HB 单元 + 测试均为同事今日上午活跃产出（09:21-09:49），DCU 已编译，worktree ×2 活跃
- [x] 处置：按老板令跳过，Amy 未写任何 HB 实现；本仓 tasks.md 的 [HB-20260824] 计划段保留作为验收对照基准
- [ ] 待办（同事合入后）：DemoHost、DPI 四档截图回归、dcc64 门禁跑批、hb-v1.0 tag
