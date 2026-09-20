# DeepBase HB AI Choice Interaction Standard
## HB AI 选择式交互标准规范 (v1.0)

> **承接定位**：本标准是 **EHAI 语言无关实现契约（Language-Neutral Realization Contract）在 Delphi / DeepBase / HB 分支中的原生桌面交互承载实现**。  
> **血统溯源**：0–9 交互语法源自 EHAI 冻结规范派生的语言共用层公共语义；AsWish 原型与 HB 控件为该语义在 Delphi / Win64 平台上的先锋工程探索与具体承接。  
> **核心受众**：DeepBase 核心控件开发、AsWish、唤金（HuanJin / AXIS）及未来所有基于 DeepBase HB 的 AI 桌面应用。

---

## 1. 核心定位与交互哲学

在现代 AI 桌面工作台中，传统 GUI（固定表单、固定单选框）与纯 Chat 界面（大量 Prompt 输入、高认知负荷）存在显著鸿沟。HB AI Choice Interaction Standard 旨在建立一种结构化、低摩擦的通用人机协作通道：

> **AI 多想一步，Human 少输一点。**  
> **AI 提供候选空间，Human 永远保留打破候选空间的权利。**

```text
AI Context
    ↓
AI 动态产生候选空间 (1–7)
    ↓
HB Choice Surface
    ↓
Human
 ├─ 1–7: 快速裁决 (Keyboard / Mouse / Voice)
 ├─ 8:   换一批 (Regenerate Context)
 ├─ 9:   人类覆写 / 自由输入 / 框架否定 (Human Override & Frame Rejection)
 └─ 0:   导航返回 (Back Navigation)
    ↓
Next Context → 连续流转 (1 → 2 → 1 → 3)
```

---

## 2. 交互协议与键位语义 (0–9 Interaction Protocol)

0–9 交互语义由 **EHAI 语言无关实现契约** 统一规定，HB 作为 Delphi 面向 Human 的交互基础设施，在原生桌面严格承载并呈现该语义，禁止任何下游产品私自重载或扭曲键位含义：

```text
1–7 : Dynamic Candidate Space (动态候选空间)
8   : Regenerate (重新生成当前上下文候选)
9   : Human Override / Free Input (人类覆写 / 自由表达 / 框架否定)
0   : Back / Navigation (导航返回上一步)
```

### 2.1. 1–7 候选区规范
* **动态数量**：候选数量由 AI 在当前 Context 下动态生成（0～7 项）。禁止为了凑满 7 项而生成伪候选；
* **推荐 ≠ 正确答案**：`1` 可作为系统推荐候选（`IsRecommended = True`），但仅表示“AI 当前优先级建议”。**禁止**默认自动选中、**禁止** Enter 键无条件自动提交、**禁止**使用高危/主操作强色强调、**禁止**倒计时自动采纳；
* **无可靠候选（No Reliable Candidates）是合法 AI 状态**：当信息不足无法生成候选时，候选区为空，呈现诚实说明，保留 `9 自己说明` 与 `0 返回`（视情况提供 `8 再试一次`）。

### 2.2. 8 重新生成（Regenerate）规范
* `8` 仅表示“在当前 Context 下向 AI 请求重构候选集合”；
* **8 不是 Decision**：触发 `8` 绝对不能自动改变业务状态、自动提交表单或写入业务 Canonical；
* **视觉呈现**：进入轻量级 `Regenerating` 状态（旧候选半透明/骨架微动），禁止整页闪白、禁止弹出阻塞模态框。

### 2.3. 9 人类覆写（Human Override & Frame Rejection）规范
* `9` 是一等公民，严禁缩减为不起眼的“其他...”或隐藏至二级菜单；
* **支持 Frame Rejection（框架否定）**：`9` 不仅用于补充未列出的选项，还允许用户打破问题本身的假设（例如“AI 问打什么客户标签，用户回答‘他不是客户，是老朋友介绍的熟人’”）；
* **输入模式**：
  * **Built-in（内置）**：ChoiceDeck 原地平滑展开输入框，提交后交由上层 AI 理解；
  * **External（外部接管）**：触发 `OnFreeInputRequested`，由应用呼出独立复杂编辑器、语音听写面板等。

### 2.4. 0 导航返回（Back）规范
* `0` **永远只是 Navigation**，绝不代表 `Reject`、`Cancel Business Action`、`Decline` 或 `Stop`；
* HB 仅发出返回意图，业务步骤与历史栈回退完全由 Application 控制。

### 2.5. 1–7 候选多选能力扩展规范（Multi-Select Extension · Human 裁定 2026-09-07）

> **当前基线核对事实**：经 2026-09-07 资料员代码审查，`THbChoiceDeck` v2.0 正式版仅支持**单选（Single-Select）**模式（`FSelectedIndex: Integer`），不存在 `MultiSelect` / `SelectedKeys` 等多选代码。本次更新为经 Human 裁定的全新能力扩展规范。

#### 1. 单选与多选双模式定义
`THbChoiceDeck` 统一支持两种工作方式：
* **单选模式（Single-Select · 默认）**：
  - 用户选中一个项目 $\rightarrow$ 立即触发该项选择并完成本次裁决（保持既有行为 100% 兼容）。
* **多选模式（Multi-Select · 新增）**：
  - **范围严格限定**：**只能是 1–7 多选，绝对不是 0–7 多选！**（因为 `0` 返回、`8` 换一批、`9` 自己输入三个全局固定语义永不改变）。

#### 2. 多选大白话交互规则
* **数字按键切换（Toggle）**：
  - 用户按数字 `2` $\rightarrow$ 选中第 2 项；
  - 用户再按数字 `4` $\rightarrow$ 同时选中第 4 项；
  - 用户再次按数字 `2` $\rightarrow$ 取消第 2 项的选中状态。
* **界面显影反馈**：
  - 界面必须实时、直观地告诉用户：“当前已选：2、4、6”；每个已选项在视觉上拥有清晰的勾选标记（Checkmark）与高亮边缘。
* **显式提交防线（Explicit Confirmation）**：
  - **多选绝不能因为用户刚按下一个数字就立即完成！**
  - 必须存在独立的、明确的“确认已选内容（Confirm Selection）”动作（如独立的确认按钮或特定的提交操作），确认之后才真正提交并流转状态。

#### 3. 为什么需要多选？
在“偏好学习”或“多维度原因判定”等典型 AI 场景中：
> 例如 AI 询问：“为什么你选择刚才那个方案？”  
> 候选包括：`1 更自然`、`2 更短`、`3 没有推销感`、`4 更像我的说话方式`、`5 对方更容易接受`。  
> 用户的真实意图往往同时包含 `1 + 3 + 4`。如果强迫只能单选其一，会严重失商人机交互的真实判断。

#### 4. 保护已有协议的铁律红线
下面四项绝对不得因为加入多选而被侵蚀或重载：
* `1–7` = 用户可选内容空间；
* `8` = 换一批（Regenerate），**不是决定**；
* `9` = 用户自由表达（Free Input），逃逸安全阀；
* `0` = 返回（Back），**不是拒绝**。

> [!CAUTION]
> **绝对禁止出现的暗黑映射**：
> - 绝对不能把 `0` 当成“取消已选”；
> - 绝对不能把 `8` 当成“确认”；
> - 绝对不能把 `9` 当成“提交已选”！  
> 新增“确认已选”必须使用**独立的明确操作（独立按钮或专用确认键）**，严禁抢占 `0–9` 已冻结语义！

#### 5. 所在层级与后续开发验收清单
* **层级归属**：`DeepBase └─ HB ├─ Choice Types ├─ VCL Choice └─ FMX Choice`。这是基座通用交互原语，不属于 AsWish 或唤金私有。
* **后续开发验收清单（Engineering AC）**：
  - [ ] **AC-MS-01**：单选模式无回退，既有单选逻辑与单测 100% 保持绿色；
  - [ ] **AC-MS-02**：多选模式下按 1–7 键能够成功多选与取消多选（Toggle 正确）；
  - [ ] **AC-MS-03**：1–7 候选可以任意组合多选（如选中 1, 3, 5）；
  - [ ] **AC-MS-04**：多选状态下 `0`（返回）、`8`（换一批）、`9`（自由输入）行为与语义完全不变；
  - [ ] **AC-MS-05**：鼠标勾选与主键盘/小键盘数字键结果严格一致；
  - [ ] **AC-MS-06**：VCL 端与 FMX 端 API、属性及行为语义 100% 对齐；
  - [ ] **AC-MS-07**：已选集合（如 `SelectedKeys: TArray<Integer>`）可被程序清晰读取；
  - [ ] **AC-MS-08**：在用户触发显式确认之前，绝对不发生误提交或提前流转状态。

---

## 3. 架构分层与职责边界

```text
HuanJin / AsWish / Downstream AI Applications (业务领域、LLM调用、决策权威、持久化)
                         ↓ (业务 Context / 动态候选)
        DeepBase HB AI Choice Interaction Standard
                         ↓ (统一交互契约 THbChoiceAction)
        DeepBase.VCL.HB.Choice / DeepBase.FMX.HB.Choice (原生控件与矢量渲染)
```

| 维度 | DeepBase HB 视觉基础设施负责 | Application (AsWish / 唤金等) 负责 |
| :--- | :--- | :--- |
| **候选管理** | 当前 Candidate Set 渲染、微动效、自适应高度 | 业务 Context、LLM Prompt 与候选生成 |
| **交互控制** | 键盘/鼠标/NumPad/多模态事件分发、Active Surface 焦点仲裁 | 业务 Flow 状态流转、历史栈真正业务含义 |
| **9 自由输入** | 原生内联 Editor / External Slot 触发、文本状态维护 | 文本语义理解、Prompt 重新构造与换 Frame |
| **状态呈现** | Ready / Regenerating / Loading / Error / NoCandidates 视觉 | 区分网络/服务 Error 与 AI 逻辑 NoCandidates |
| **决策执行** | **严格分离**（Choice ≠ Authority ≠ Execution） | 业务确认、高危操作二次防线、数据持久化 |

---

## 4. 多模态输入抽象与统一交互意图 (Action Abstraction)

HB 将触发设备与交互语义彻底解耦：

```pascal
type
  /// <summary>
  /// 统一交互意图分类
  /// </summary>
  THbChoiceActionKind = (
    cakCandidate,    // 1..7 候选选择
    cakRegenerate,   // 8 重新生成
    cakFreeInput,    // 9 自由输入 / 人类覆写
    cakBack          // 0 导航返回
  );

  /// <summary>
  /// 输入源设备类型
  /// </summary>
  THbChoiceInputSource = (
    cisMouse,          // 鼠标左键点击
    cisKeyboard,       // 主键盘数字键 (0..9)
    cisNumPad,         // 数字小键盘 (NumLock 开启时)
    cisVoice,          // 语音指令映射 (未来扩展)
    cisAccessibility,  // 屏幕阅读器 / 无障碍操作
    cisProgrammatic    // 代码直接触发
  );

  /// <summary>
  /// 统一交互动作载荷
  /// </summary>
  THbChoiceAction = record
    Kind: THbChoiceActionKind;
    Key: Integer;                // 0..9
    Text: string;               // 选项文本或自由输入文本
    Payload: NativeInt;         // 透传业务上下文句柄/指针
    InputSource: THbChoiceInputSource;
  end;
```

---

## 5. 键盘第一公民与焦点仲裁机制

### 5.1. Text Entry Owns Keyboard（文本输入优先原则）
只要用户处于任何文本输入上下文（ChoiceDeck 内置输入框、外部 TEdit/TMemo、输入法 IME 组合态、应用声明的 Text Surface），ChoiceDeck **必须无条件暂停 `0–9` 快捷键拦截**，确保输入 `13800138000` 或拼音选字时不发生误触。

### 5.2. Active Choice Surface（活动选择表面）
同一界面存在多个 ChoiceDeck 时，全局最多只有一个 `Active Choice Surface` 拥有数字快捷键。当 Deck 失去活动状态时，以静默半高亮展示，仅响应鼠标点击。

### 5.3. NumPad 行为规范
* **NumLock 开启**：`NumPad0..NumPad9` 与主键盘 `0..9` 严格等价；
* **NumLock 关闭**：保留操作系统原生光标与导航语义（Home/End/Arrows），不得强行劫持。

---

## 6. 四大布局模式 (Layout Modes)

`THbChoiceDeck` 统一支持四种布局模式：

```pascal
type
  THbChoiceLayoutMode = (
    clmDeck,          // Mode A: 标准卡片叠层 (3~7个候选，适合深度对比与决策)
    clmRow,           // Mode B: 紧凑横排 (2~4个短候选，适合快速分类与归档)
    clmNumberedList,  // Mode C: 编号列表 (长文本/话术候选，适合侧边栏)
    clmInline         // Mode D: 轻量行内选择 (工作流嵌入轻决策)
  );
```

---

## 7. 视觉状态模型 (Truthful State Machine)

```text
         ┌─────────────── Ready ────────────────┐
         │                  │                   │
         ▼                  ▼                   ▼
    Regenerating        FreeInput        NoReliableCandidates
         │                  │                   │
         ▼                  ▼                   ▼
   (New Options)       (Submit / Cancel)    (8 Retry / 9 / 0)
         │                  │                   │
         └─────────────── Ready ◄───────────────┘
                            │
                            ▼
                          Error (网络/接口技术异常，与 NoCandidates 严格分离)
```

---

## 8. 跨平台孪生准则

* **原则**：`Semantic Contract Aligned, Platform Implementation Native`。
* **VCL**：基于 Windows GDI+ 双缓冲与 High-DPI 缩放矩阵绘制，完美支持 Windows 消息循环与 IME 交互。
* **FMX**：基于跨平台 `TCanvas` 矢量路径绘制，API 语义 100% 对齐。

---

## 9. 索引与源文件指针

* 核心数据契约类型：[`Core/DeepBase.HB.Choice.Types.pas`](file:///d:/_Progs/02Business/DeepBase/Core/DeepBase.HB.Choice.Types.pas)
* 主题 Token 单一真相源：[`Core/DeepBase.HB.Core.pas`](file:///d:/_Progs/02Business/DeepBase/Core/DeepBase.HB.Core.pas)
* VCL 原生标准控件：[`VCL/DeepBase.VCL.HB.Choice.pas`](file:///d:/_Progs/02Business/DeepBase/VCL/DeepBase.VCL.HB.Choice.pas)
* VCL Showcase 演示窗体：[`VCL/DeepBase.VCL.HB.Choice.Demo.pas`](file:///d:/_Progs/02Business/DeepBase/VCL/DeepBase.VCL.HB.Choice.Demo.pas)
* 单元测试套件：[`Tests/Test.DeepBase.HB.Suite.pas`](file:///d:/_Progs/02Business/DeepBase/Tests/Test.DeepBase.HB.Suite.pas)
