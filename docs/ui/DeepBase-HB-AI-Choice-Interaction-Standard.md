# DeepBase HB AI Choice Interaction Standard
## HB AI 选择式交互标准规范 (v1.0)

> **法源状态**：DeepBase 视觉与交互基础设施通用法定标准  
> **历史溯源**：本标准最初在 AsWish 的 0–9 Universal Choice 实践中完成探索与验证，本轮提炼其中通用 AI 人机交互语义，正式上移为 DeepBase HB 通用人机交互基础设施。  
> **核心受众**：DeepBase 核心控件开发、AsWish、唤金（HuanJin）及未来所有基于 DeepBase HB 的 AI 桌面应用。

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

HB 严格冻结 `0–9` 的交互语义，禁止任何下游产品私自重载或扭曲键位含义：

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
