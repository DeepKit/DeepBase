# LLM UI 详细设计文档

## 概述

本文档详细说明 UniBase 框架中新增的 LLM 相关 UI 界面的设计规范、布局、交互流程和实现要点。

---

## 1. LLM 等待窗体 (LLMWaitForm)

### 1.1 用途

用户发出 LLM 命令后弹出，向用户展示处理进度，防止用户感到操作被冻结。支持取消操作或转为后台运行。

### 1.2 规格

| 属性 | 值 |
|------|-----|
| **窗体类型** | Modal Dialog (模态对话框) |
| **默认大小** | 400px × 200px |
| **位置** | 屏幕中心或主窗体中心 |
| **是否可调整** | 否（固定尺寸） |
| **是否可最小化** | 否 |
| **边框样式** | 圆角 (border-radius: 8px) |
| **背景** | 半透明深灰色背景（modal backdrop） |
| **关闭按钮** | 仅显示标题栏右上角 X 按钮 |

### 1.3 UI 布局

```
┌─────────────────────────────────────────┐
│ LLM 处理中...                        [×] │
├─────────────────────────────────────────┤
│                                         │
│            [🔄 SVG 动画]               │ ← 上部：SVG 动画区 (80px 高)
│                                         │
├─────────────────────────────────────────┤
│  正在处理您的请求...                    │
│  当前：访问 LiteLLM...                  │ ← 中部：动态文本 (60px 高)
│  Token 使用: 45/2000                    │
├─────────────────────────────────────────┤
│                                         │
│     [取消]              [后台运行]      │ ← 下部：按钮区 (50px 高)
│                                         │
└─────────────────────────────────────────┘
```

### 1.4 详细说明

#### 1.4.1 标题栏 (Title Bar)
- **背景色**: #ff9999 (浅红色)
- **高度**: 35px
- **标题文本**: "LLM 处理中..." (14pt, 加粗)
- **关闭按钮**: 右上角 X 按钮，点击触发 "取消" 操作

#### 1.4.2 上部：SVG 动画区 (Animation Area)
- **高度**: 80px
- **内容**: 
  - 从 AnimationAssets 库中随机选择一个 SVG 动画
  - 动画自动播放、循环、无限重复
  - 尺寸不超过 60px × 60px，居中显示
  - 动画库示例：加载圈、脉冲圆、旋转立方体等

**代码参考**:
```delphi
procedure TLLMWaitForm.InitializeAnimation;
begin
  FAnimationList := AnimationAssets.GetAnimationList;
  FSelectedAnimation := FAnimationList.Random;
  FAnimationView.LoadSVG(FSelectedAnimation);
  FAnimationView.AutoPlay := True;
  FAnimationView.Loop := True;
end;
```

#### 1.4.3 中部：动态文本区 (Message Area)
- **高度**: 60px
- **内容** (动态更新):
  1. 第一行：固定提示文本 "正在处理您的请求..."
  2. 第二行：当前操作 "当前：访问 LiteLLM..." (实时更新)
  3. 第三行：进度信息 "Token 使用: 45/2000" (实时更新)

- **文本更新机制**:
  - 通过 BackgroundTask 事件回调更新文本
  - 支持 I18n 国际化
  - 文本对齐：居中

**代码参考**:
```delphi
procedure TLLMWaitForm.UpdateProgress(ACurrentOperation: string; ATokenCount, AMaxTokens: Integer);
begin
  Label_CurrentOp.Caption := Format('当前：%s', [ACurrentOperation]);
  Label_TokenUsage.Caption := Format('Token 使用: %d/%d', [ATokenCount, AMaxTokens]);
end;

procedure TLLMWaitForm.OnTaskProgress(Sender: TObject; AMessage: string);
begin
  UpdateProgress(AMessage, Sender.TokenCount, Sender.MaxTokens);
end;
```

#### 1.4.4 下部：按钮区 (Button Area)
- **高度**: 50px
- **按钮 1**: "取消" (Cancel)
  - 宽度: 100px
  - 功能: 停止 LLM 请求，关闭窗体，返回 mrCancel
  - 背景色: #cccccc
  
- **按钮 2**: "后台运行" (Background)
  - 宽度: 100px
  - 功能: 隐藏窗体，任务转为后台运行，显示后台通知栏
  - 背景色: #cccccc

- **按钮间距**: 60px (按钮中心之间的距离)

### 1.5 交互流程

```
User Action                    LLMWaitForm                Backend Task
    │                              │                          │
    ├─ 发出LLM命令 ───────────────>│                          │
    │                              ├─ 弹出等待窗体              │
    │                              ├─ 启动动画                │
    │                              ├──────────────────────────>│
    │                              │  Task Started             │
    │                              │<─ Progress Updates ────┐  │
    │                              │  "当前: ...token: 45" │  │
    │                              │                      <──┤
    │                              │                          │
    │  ◇ 用户选择:                 │                          │
    │  ├─ 点击"取消" ─────────────>│                          │
    │  │                           ├─ 停止任务 ──────────────>│
    │  │                           │ (任务被中断)             │
    │  │                           ├─ 关闭窗体               │
    │  │                           └─ 返回 mrCancel          │
    │  │                                                      │
    │  └─ 点击"后台运行" ─────────>│                          │
    │                              ├─ 隐藏窗体                │
    │                              ├─ 显示后台通知栏          │
    │                              ├──────────────────────────>│
    │                              │  Continue Running...      │
    │                              │                      (继续)
    │                              │                          │
    │                              │  (后台任务继续运行)       │
    │                              │<───────────────────────┐ │
    │                              │ Completion/Error Event │ │
    │                              ├─ 更新通知栏             │
    │                              ├─ 可选：播放声音/振动    │
    │                              └─ 自动关闭后台通知       │
```

### 1.6 样式规范

- **字体**: Arial, 10pt (正文), 12pt (标题)
- **文本颜色**: #333333 (深灰)
- **背景色**: #ffffff (白色)
- **边框**: 1px solid #999999
- **圆角**: 8px
- **阴影**: drop-shadow(0 2px 8px rgba(0,0,0,0.15))

### 1.7 国际化 (i18n) 支持

所有固定文本必须支持翻译：

```
Resource_ID              | 中文                | English
───────────────────────────────────────────────────────────
IDS_LLMWAIT_TITLE       | LLM 处理中...       | Processing with LLM...
IDS_LLMWAIT_MESSAGE     | 正在处理您的请求... | Processing your request...
IDS_LLMWAIT_CURRENT     | 当前：%s            | Current: %s
IDS_LLMWAIT_TOKEN_USAGE | Token 使用: %d/%d  | Token Usage: %d/%d
IDS_LLMWAIT_CANCEL      | 取消                | Cancel
IDS_LLMWAIT_BACKGROUND  | 后台运行            | Background Run
```

---

## 2. LLM 参数配置面板 (LLMConfigPanel)

### 2.1 用途

让用户配置 LLM 连接参数（如 API Key、Model、Temperature、成本等），查看历史调用记录。

### 2.2 规格

| 属性 | 值 |
|------|-----|
| **控件类型** | Panel (嵌入到主设置窗体或独立 Dialog) |
| **默认大小** | 800px × 500px (或父窗体尺寸) |
| **分为两部分** | 上部配置面板 (60%) + 下部 Grid (40%) |

### 2.3 UI 布局

#### 2.3.1 上部：配置面板 (Configuration Panel)

```
┌────────────────────────────────────────────────────────────────────────┐
│ 参数配置                                                               │
├────────────────────────────────────────────────────────────────────────┤
│ ☑ 启用            Provider: [LiteLLM ▼]                  [测试连接]    │
│                                                                        │
│ API地址: [_______________________________]                             │
│ API Key: [****] [👁️]    (显示/隐藏密钥)                              │
│                                                                        │
│ Model: [gpt-4o ▼]    Temperature: [0.7 ── ]    Timeout: [60000] ms   │
│                                                                        │
│ Max Tokens: [4096]    Top-P: [1.0]                                    │
│                                                                        │
│ Input Price/1K: $[0.15]    Output Price/1K: $[0.60]                  │
│ Concurrent Requests: [5]   Retry Count: [3]   Retry Delay: [1000] ms │
│                                                                        │
│ [✓ 保存] [⟲ 重置] [? 帮助] [📋 复制]                                  │
└────────────────────────────────────────────────────────────────────────┘
```

#### 2.3.2 下部：LLM 调用记录 Grid

```
┌────────────────────────────────────────────────────────────────────────┐
│ LLM 调用记录                                        [📊导出] [🔄刷新]  │
├────────────────────────────────────────────────────────────────────────┤
│ Time │ Provider │ Model │ Status │ Duration │ Tokens │ Est. Cost │    │
├──────┼──────────┼───────┼────────┼──────────┼────────┼───────────┤    │
│14:30 │LiteLLM   │gpt-4o │   ✓    │ 1250ms   │  245   │  $0.08    │    │
│14:28 │LiteLLM   │gpt-4o │   ✓    │  980ms   │  180   │  $0.06    │    │
│14:27 │OpenAI    │gpt-4o │   ✓    │ 5400ms   │  512   │  $0.15    │    │
│14:25 │LiteLLM   │gpt-3.5│   ✗    │  2100ms  │  100   │  $0.01    │    │
│14:20 │OpenAI    │gpt-4o │   ✓    │ 3800ms   │  340   │  $0.10    │    │
├──────┴──────────┴───────┴────────┴──────────┴────────┴───────────┤    │
│ Total: 156 | Success: 154 | Failed: 2 | Today Cost: $2.34      │    │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.4 配置面板字段详解

#### 2.4.1 启用复选框 (Enabled Checkbox)
- **标签**: "☑ 启用"
- **功能**: 开启/关闭该 LLM 配置
- **默认值**: True (勾选)

#### 2.4.2 Provider 下拉列表
- **标签**: "Provider:"
- **选项示例**:
  - LiteLLM (通用代理)
  - OpenAI (官方 OpenAI)
  - Anthropic (Claude)
  - Google (Gemini)
  - Custom (自定义)
- **默认值**: "LiteLLM"
- **关联**: 更改 Provider 会自动更新可用 Model 列表

#### 2.4.3 测试连接按钮
- **标签**: "测试连接"
- **功能**: 
  - 验证 API Key 有效性
  - 测试网络连接
  - 显示响应时间
  - 显示成功/失败提示
- **成功提示**: "✓ 连接成功 (响应时间: 250ms)"
- **失败提示**: "✗ 连接失败: API Key 无效"

#### 2.4.4 API 地址字段
- **标签**: "API地址:"
- **类型**: TEdit (单行文本)
- **示例**: "https://api.litellm.ai/v1"
- **功能**: 支持自定义 API 端点

#### 2.4.5 API Key 字段
- **标签**: "API Key:"
- **类型**: TEdit (密码模式)
- **掩码**: 默认显示 [****]
- **显示/隐藏按钮**: 👁️ 图标，点击可切换显示/隐藏
- **安全性**: 
  - 从不在日志中记录明文
  - 存储在加密配置中
  - 内存中使用 SecureString

#### 2.4.6 Model 下拉列表
- **标签**: "Model:"
- **选项示例**:
  - gpt-4o
  - gpt-4-turbo
  - gpt-3.5-turbo
  - claude-3-opus
  - gemini-1.5-pro
- **默认值**: "gpt-4o"
- **关联**: 由 Provider 决定可用列表

#### 2.4.7 Temperature 滑块
- **标签**: "Temperature:"
- **范围**: 0.0 - 2.0
- **默认值**: 0.7
- **步长**: 0.1
- **显示**: 数值标签 (如 "0.7")

#### 2.4.8 Timeout 字段
- **标签**: "Timeout:"
- **类型**: TSpinEdit
- **单位**: ms (毫秒)
- **范围**: 1000 - 60000
- **默认值**: 60000
- **说明**: 单个请求最长等待时间

#### 2.4.9 Max Tokens 字段
- **标签**: "Max Tokens:"
- **类型**: TSpinEdit
- **范围**: 1 - 10000
- **默认值**: 4096

#### 2.4.10 Top-P 字段
- **标签**: "Top-P:"
- **范围**: 0.0 - 1.0
- **默认值**: 1.0

#### 2.4.11 价格配置
- **输入价格**: "Input Price/1K:" (美元)
- **输出价格**: "Output Price/1K:" (美元)
- **用途**: 计算每次 LLM 调用的成本估算

#### 2.4.12 并发和重试配置
- **并发请求数**: "Concurrent Requests:" (默认 5)
- **重试次数**: "Retry Count:" (默认 3)
- **重试延迟**: "Retry Delay:" (ms, 默认 1000)

#### 2.4.13 按钮组
- **保存**: ✓ 按钮，保存所有配置
- **重置**: ⟲ 按钮，回滚到上次保存的配置
- **帮助**: ? 按钮，打开帮助文档
- **复制**: 📋 按钮，复制配置为 JSON 格式

### 2.5 Grid 字段说明

| 列名 | 宽度 | 说明 |
|------|------|------|
| **Time** | 100px | 调用时间戳 (HH:MM:SS) |
| **Provider** | 90px | LLM 提供商名称 |
| **Model** | 80px | 使用的模型 |
| **Status** | 60px | ✓ 成功 / ✗ 失败 / ⏳ 进行中 |
| **Duration** | 100px | 响应时间 (ms) |
| **Tokens** | 80px | 使用的 Token 数 |
| **Est. Cost** | 90px | 估算费用 ($) |

#### Grid 功能
- **排序**: 点击列标题排序
- **筛选**: Provider/Status 的快速筛选
- **搜索**: 支持全文搜索
- **导出**: 导出为 CSV/Excel
- **刷新**: 重新加载最新记录
- **上下文菜单**: 右键菜单 (复制、删除、查看详情)

### 2.6 交互流程

```
用户操作                          配置面板                          后端
  │                               │                              │
  ├─ 更改 Provider ──────────────>│                              │
  │                               ├─ 更新 Model 列表 ────────────>│
  │                               │ (查询可用模型)               │
  │                               │<─ Model List ──────────┐    │
  │                               ├─ 刷新 Model 下拉列表    │    │
  │                               │                            │
  ├─ 点击"测试连接" ─────────────>│                            │
  │                               ├─ 验证参数 ───────────────────>│
  │                               │                  Request    │
  │                               │<─ Connection Status ──┐     │
  │                               ├─ 显示成功/失败提示      │    │
  │                               │                            │
  ├─ 修改配置字段 ─────────────────────────────────────────────>│
  │  (API Key, Model, Temperature等)                           │
  │                               │                            │
  ├─ 点击"保存" ──────────────────>│                            │
  │                               ├─ 验证所有字段 ────────────────>│
  │                               │  (Validation)              │
  │                               │<─ Validation Result ──┐    │
  │                               ├─ 加密并保存配置        │    │
  │                               ├─ 显示保存成功提示      │    │
  │                               │                            │
  ├─ Grid 中的操作:               │                            │
  │  ├─ 点击列排序                │                            │
  │  ├─ 筛选记录                  ├─ 数据查询              ──────>│
  │  ├─ 导出 CSV                  │                  Query   │
  │  └─ 右键查看详情              │<─ Record Details ──┐        │
  │                               ├─ 更新 Grid          │       │
  │                               │                            │
```

---

## 3. 后台任务通知栏 (Background Task Notification Bar)

### 3.1 用途

当用户选择"后台运行"时，在主窗体的状态栏或专用通知栏显示 LLM 任务进度。

### 3.2 规格

| 属性 | 值 |
|------|-----|
| **位置** | 主窗体状态栏下方或系统通知栏 |
| **高度** | 40px (如为内部通知栏) |
| **显示条件** | 存在运行中的后台 LLM 任务时 |
| **自动隐藏** | 任务完成后 5 秒自动隐藏或点击关闭 |

### 3.3 UI 布局

```
┌──────────────────────────────────────────────────────────────────────┐
│ 🔄 后台 LLM 任务 [进度条: ████████░░░░░░░] 75%  [取消]  [×]           │
└──────────────────────────────────────────────────────────────────────┘
```

### 3.4 字段说明

- **图标**: 🔄 旋转动画
- **文本**: "后台 LLM 任务"
- **进度条**: 显示任务完成百分比
- **百分比数字**: 如 "75%"
- **取消按钮**: 停止后台任务
- **关闭按钮**: 隐藏通知栏 (但任务继续运行)

### 3.5 交互

```
Task Completion
       │
       ├─ 任务完成 ──────────────────────────────────>│ 显示"✓ 完成！"
       │                                              │ 自动隐藏 (5s 后)
       │
       ├─ 任务出错 ──────────────────────────────────>│ 显示"✗ 出错"
       │                                              │ 显示错误信息
       │                                              │ 不自动隐藏
       │
       └─ 用户点击"取消" ───────────────────────────>│ 中止任务
                                                     │ 显示"已取消"
```

---

## 4. 集成指南

### 4.1 Delphi 实现示例

#### LLMWaitForm

```delphi
unit LLMWaitForm;

interface

uses
  System.Classes, Vcl.Forms, Vcl.StdCtrls, Vcl.Controls, Vcl.ExtCtrls,
  AnimationAssets, LLMManager;

type
  TLLMWaitForm = class(TForm)
    PanelAnimation: TPanel;
    ImageViewAnimation: TImage;  // 或自定义 SVG 控件
    LabelMessage: TLabel;
    LabelCurrent: TLabel;
    LabelTokenUsage: TLabel;
    ButtonCancel: TButton;
    ButtonBackground: TButton;
    TimerAnimation: TTimer;
  private
    FLLMTask: ILLMTask;
    FAnimationFrame: Integer;
  public
    procedure ShowWaitForm(ALLMTask: ILLMTask);
    procedure UpdateProgress(const AMessage: string; ATokenCount, AMaxTokens: Integer);
    procedure OnTaskComplete(Sender: TObject);
    procedure OnTaskError(Sender: TObject; const AErrorMsg: string);
  end;

implementation

procedure TLLMWaitForm.ShowWaitForm(ALLMTask: ILLMTask);
begin
  FLLMTask := ALLMTask;
  
  // 随机选择 SVG 动画
  var LAnimation := AnimationAssets.GetRandomAnimation;
  ImageViewAnimation.Picture.LoadFromStream(LAnimation.SVGStream);
  
  // 绑定事件
  FLLMTask.OnProgress := UpdateProgress;
  FLLMTask.OnComplete := OnTaskComplete;
  FLLMTask.OnError := OnTaskError;
  
  // 显示窗体
  ShowModal;
end;

procedure TLLMWaitForm.UpdateProgress(const AMessage: string; ATokenCount, AMaxTokens: Integer);
begin
  LabelCurrent.Caption := Format(i18n.Get('IDS_LLMWAIT_CURRENT'), [AMessage]);
  LabelTokenUsage.Caption := Format(i18n.Get('IDS_LLMWAIT_TOKEN_USAGE'), [ATokenCount, AMaxTokens]);
end;

procedure TLLMWaitForm.ButtonCancelClick(Sender: TObject);
begin
  FLLMTask.Cancel;
  ModalResult := mrCancel;
  Close;
end;

procedure TLLMWaitForm.ButtonBackgroundClick(Sender: TObject);
begin
  // 转为后台任务
  NotificationBar.AddBackgroundTask(FLLMTask);
  ModalResult := mrOk;
  Close;
end;

end.
```

#### LLMConfigPanel

```delphi
unit LLMConfigPanel;

interface

uses
  System.Classes, Vcl.Forms, Vcl.StdCtrls, Vcl.Controls, Vcl.ExtCtrls,
  Vcl.ComCtrls, Vcl.Grids, LLMManager, Data.DB;

type
  TLLMConfigPanel = class(TPanel)
    GroupBoxConfig: TGroupBox;
    CheckBoxEnabled: TCheckBox;
    ComboBoxProvider: TComboBox;
    ButtonTestConnection: TButton;
    EditAPIAddress: TEdit;
    EditAPIKey: TEdit;
    ButtonShowKey: TButton;
    ComboBoxModel: TComboBox;
    TrackBarTemperature: TTrackBar;
    SpinEditTimeout: TSpinEdit;
    EditInputPrice: TEdit;
    EditOutputPrice: TEdit;
    SpinEditConcurrent: TSpinEdit;
    SpinEditRetry: TSpinEdit;
    ButtonSave: TButton;
    ButtonReset: TButton;
    ButtonHelp: TButton;
    ButtonCopy: TButton;
    StringGridCalls: TStringGrid;
    ButtonExport: TButton;
    ButtonRefresh: TButton;
  private
    FLLMConfig: TLLMConfiguration;
    procedure LoadConfiguration;
    procedure SaveConfiguration;
    procedure PopulateModelList;
    procedure UpdateGridData;
  public
    procedure Initialize;
    procedure Finalize;
  end;

implementation

procedure TLLMConfigPanel.Initialize;
begin
  // 初始化下拉列表
  ComboBoxProvider.Items.Add('LiteLLM');
  ComboBoxProvider.Items.Add('OpenAI');
  ComboBoxProvider.Items.Add('Anthropic');
  ComboBoxProvider.Items.Add('Google');
  
  // 加载已保存的配置
  LoadConfiguration;
  
  // 初始化 Grid
  StringGridCalls.ColCount := 7;
  StringGridCalls.RowCount := 1;
  StringGridCalls.Cells[0, 0] := 'Time';
  StringGridCalls.Cells[1, 0] := 'Provider';
  StringGridCalls.Cells[2, 0] := 'Model';
  StringGridCalls.Cells[3, 0] := 'Status';
  StringGridCalls.Cells[4, 0] := 'Duration';
  StringGridCalls.Cells[5, 0] := 'Tokens';
  StringGridCalls.Cells[6, 0] := 'Cost';
  
  UpdateGridData;
end;

procedure TLLMConfigPanel.ButtonTestConnectionClick(Sender: TObject);
begin
  var LManager := TLLMManager.Create;
  try
    var LResult := LManager.TestConnection(
      ComboBoxProvider.Text,
      EditAPIKey.Text,
      EditAPIAddress.Text
    );
    
    if LResult.Success then
      ShowMessage(Format('✓ 连接成功 (响应时间: %dms)', [LResult.ResponseTime]))
    else
      ShowMessage(Format('✗ 连接失败: %s', [LResult.ErrorMessage]));
  finally
    LManager.Free;
  end;
end;

procedure TLLMConfigPanel.ButtonSaveClick(Sender: TObject);
begin
  SaveConfiguration;
  ShowMessage('✓ 配置已保存');
end;

end.
```

### 4.2 数据库表结构

#### LLMConfiguration 表

```sql
CREATE TABLE LLMConfiguration (
  ConfigID INTEGER PRIMARY KEY AUTOINCREMENT,
  ProviderName TEXT NOT NULL,
  APIAddress TEXT,
  APIKey TEXT,  -- 加密存储
  Model TEXT,
  Temperature REAL DEFAULT 0.7,
  TimeoutMS INTEGER DEFAULT 60000,
  MaxTokens INTEGER DEFAULT 4096,
  TopP REAL DEFAULT 1.0,
  InputPrice REAL,
  OutputPrice REAL,
  ConcurrentRequests INTEGER DEFAULT 5,
  RetryCount INTEGER DEFAULT 3,
  RetryDelayMS INTEGER DEFAULT 1000,
  Enabled INTEGER DEFAULT 1,
  CreatedAt TEXT,
  ModifiedAt TEXT,
  UNIQUE(ProviderName)
);
```

#### LLMCallHistory 表

```sql
CREATE TABLE LLMCallHistory (
  CallID INTEGER PRIMARY KEY AUTOINCREMENT,
  CallTime TEXT NOT NULL,
  ProviderName TEXT,
  Model TEXT,
  Status TEXT,  -- 'Success' / 'Failed' / 'Cancelled'
  DurationMS INTEGER,
  InputTokens INTEGER,
  OutputTokens INTEGER,
  EstimatedCost REAL,
  ErrorMessage TEXT,
  RequestHash TEXT,  -- 用于去重
  CreatedAt TEXT,
  INDEX(CallTime),
  INDEX(ProviderName)
);
```

---

## 5. 安全考虑

### 5.1 API Key 安全

1. **加密存储**: 所有 API Key 使用 AES-256 加密
2. **内存安全**: 使用 SecureString 避免明文在内存中泄露
3. **日志安全**: 从不在日志中记录完整的 API Key (最多显示前 4 位)
4. **传输安全**: 所有 API 请求使用 HTTPS

### 5.2 错误处理

- 连接失败时，显示友好的错误提示
- 避免暴露内部系统信息
- 记录所有错误用于调试

### 5.3 访问控制

- 配置只能由管理员修改
- 调用记录对所有用户可见但受限于权限

---

## 6. 测试计划

### 单元测试
- 验证参数验证逻辑
- 验证配置加密/解密
- 验证 Grid 数据加载

### 集成测试
- 端到端 LLM 请求流程
- 等待窗体取消/后台运行切换
- 错误恢复机制

### UI 测试
- 布局响应式测试
- 国际化文本正确性
- 动画流畅性

---

## 7. 版本历史

| 版本 | 日期 | 更改 |
|------|------|------|
| 1.0 | 2024-12-XX | 初稿 |

