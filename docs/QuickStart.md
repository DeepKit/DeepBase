# UniBase 快速入门指南

本文档帮助您在 10 分钟内完成 UniBase 框架的安装和基本使用。

## 目录

1. [系统要求](#系统要求)
2. [安装步骤](#安装步骤)
3. [第一个项目](#第一个项目)
4. [核心功能速览](#核心功能速览)
5. [常见问题](#常见问题)
6. [下一步](#下一步)

---

## 系统要求

| 项目 | 要求 |
|------|------|
| **Delphi 版本** | Delphi 10.3 Rio 或更高 |
| **数据库** | FireDAC + SQLite（Delphi 自带） |
| **操作系统** | Windows 10/11（VCL）；支持 FMX 跨平台 |
| **单元测试** | DUnitX（可选） |

---

## 安装步骤

### 步骤 1：获取源码

```bash
git clone https://github.com/YourRepo/UniBase.git
cd UniBase
```

### 步骤 2：安装包

1. 打开 Delphi IDE
2. 打开 `UniBaseCore.dpk`，点击 **Compile**
3. 打开 `dclUniBaseCore.dpk`，点击 **Install**
4. 确认组件面板出现 **UniBase** 和 **UniBase FMX** 分组

### 步骤 3：配置搜索路径

将以下路径添加到项目的 **Search Path**：

```
$(UniBase)\Core
$(UniBase)\VCL
$(UniBase)\FMX
```

> 💡 建议：在 IDE 的 Library Path 中添加，避免每个项目重复配置。

---

## 第一个项目

### 最小示例（控制台）

```delphi
program HelloUniBase;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  UniBase.Manager;

begin
  // 初始化（自动检测或创建 config.db）
  if not UniBase.Initialize then
  begin
    WriteLn('初始化失败: ', InitErrorCodeToStr(UniBase.InitErrorCode));
    Exit;
  end;
  
  try
    // 读写配置
    UniBase.Config.SetConfig('App.Version', '1.0.0');
    WriteLn('版本: ', UniBase.Config.GetConfig('App.Version', ''));
    
    // 国际化
    WriteLn('翻译: ', UniBase.I18n.T('Hello'));
    
    // 日志
    UniBase.Logger.Info('Hello from UniBase!');
    
    WriteLn('运行成功！按回车退出...');
    ReadLn;
  finally
    UniBase.Finalize;
  end;
end.
```

### VCL 应用示例

**项目文件 (MyApp.dpr):**

```delphi
program MyApp;

uses
  Vcl.Forms,
  UniBase.Manager,
  UniBase.SingleInstance,
  MainForm in 'MainForm.pas' {frmMain};

{$R *.res}

begin
  // 单实例检测（可选）
  if not TAppInstance.CheckSingleInstance('MyCompany.MyApp') then
  begin
    TAppInstance.ActivateExistingInstance;
    Exit;
  end;

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  
  // 初始化 UniBase
  if not UniBase.Initialize then
  begin
    Application.MessageBox(
      PChar('初始化失败: ' + InitErrorCodeToStr(UniBase.InitErrorCode)),
      '错误', MB_ICONERROR);
    Exit;
  end;
  
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
  
  // 清理
  UniBase.Finalize;
end.
```

**主窗体 (MainForm.pas):**

```delphi
unit MainForm;

interface

uses
  Vcl.Forms, Vcl.StdCtrls, Vcl.Controls, System.Classes,
  UniBase.Manager, UniBase.VCL.ConfigControls, UniBase.VCL.I18nControls,
  UniBase.VCL.FormStateHelper;

type
  TfrmMain = class(TForm)
    FormStateHelper1: TFormStateHelper;  // 自动保存窗体状态
    lblWelcome: TI18nLabel;              // 自动翻译标签
    edtUsername: TConfigEdit;            // 自动绑定配置
    btnSave: TI18nButton;                // 自动翻译按钮
    procedure FormCreate(Sender: TObject);
  end;

implementation

{$R *.dfm}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  // 设置控件属性
  lblWelcome.TextKey := 'Welcome';           // 翻译键
  edtUsername.ConfigKey := 'App.Username';   // 配置键
  edtUsername.DefaultValue := 'Guest';
  btnSave.TextKey := 'Save';
end;

end.
```

---

## 核心功能速览

### 1. 配置管理

UniBase 提供多种访问方式，根据个人喜好选择：

```delphi
// ==== 方式 A: 单元级便捷函数（推荐，最简洁） ====
uses UniBase.Config;

var title := GetConfig('App.Title', 'Default');         // 直接调用
SetConfig('App.Title', 'My Application');
SetConfigInt('App.MaxRetries', 3);
var debug := GetConfigBool('App.DebugMode', False);

// ==== 方式 B: 模块快捷函数 ====
uses UniBase.Manager;

var title := UBConfig.GetConfig('App.Title', 'Default');  // UBConfig 返回 Config 模块
UBConfig.SetConfig('App.Title', 'My Application');
UBI18n.CurrentLanguage := 'zh-CN';                        // UBI18n 返回 I18n 模块
UBLogger.Info('Hello');                                   // UBLogger 返回 Logger 模块

// ==== 方式 C: 完整路径（传统方式） ====
uses UniBase.Manager;

UniBase.Config.SetConfig('App.Title', 'My Application');
var title := UniBase.Config.GetConfig('App.Title', 'Default');

// 类型化配置
UniBase.Config.SetConfigInt('App.MaxRetries', 3);
UniBase.Config.SetConfigBool('App.DebugMode', True);
UniBase.Config.SetConfigFloat('App.Timeout', 30.5);

var retries := UniBase.Config.GetConfigInt('App.MaxRetries', 1);
var debug := UniBase.Config.GetConfigBool('App.DebugMode', False);
```

> 💡 **说明**: `UniBase.Config` 中的 `UniBase` 是函数调用（返回单例管理器），不是单元名。
> 新增的单元级函数和快捷函数可避免这种混淆。

### 2. 国际化 (i18n)

```delphi
uses UniBase.Manager, UniBase.i18n;

// 简单翻译
Caption := T('Welcome');

// 带参数的翻译
ShowMessage(TFmt('Hello, %s!', [username]));

// 切换语言
UniBase.I18n.CurrentLanguage := 'zh-CN';

// 获取可用语言
var langs := UniBase.I18n.GetAvailableLanguages;
for var lang in langs do
  ComboBox1.Items.Add(lang.LangName);
```

### 3. 日志系统

```delphi
uses UniBase.Manager, UniBase.Logging;

// 基本日志
UniBase.Logger.Debug('调试信息');
UniBase.Logger.Info('一般信息');
UniBase.Logger.Warn('警告信息');
UniBase.Logger.Error('错误信息');

// 带格式的日志
UniBase.Logger.InfoFmt('用户 %s 登录成功', ['admin']);

// 配置日志存储
UniBase.Logger.StorageMode := lsmBoth;  // 同时写入数据库和文件

// 清理旧日志
UniBase.Logger.ClearOldLogs(30);  // 保留 30 天
```

### 4. 窗体状态管理

**方式一：使用组件**

```delphi
// 在窗体上放置 TFormStateHelper 组件
// 设置 AutoSave := True 和 AutoRestore := True
// 完成！窗体位置和大小会自动保存/恢复
```

**方式二：手动调用**

```delphi
procedure TfrmMain.FormShow(Sender: TObject);
begin
  UniBase.RestoreFormState(Self);
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  UniBase.SaveFormState(Self);
end;
```

### 5. 单实例检测

```delphi
uses UniBase.SingleInstance;

// 在 DPR 文件中
if not TAppInstance.CheckSingleInstance('MyApp') then
begin
  TAppInstance.ActivateExistingInstance;  // 激活已运行的实例
  Exit;
end;
```

### 6. 数据导出

```delphi
uses UniBase.Export;

// 导出 DataSet 到 CSV
TDataExport.ToCSV(MyDataSet, 'data.csv');

// 导出到 HTML（带样式）
TDataExport.ToHTML(MyDataSet, 'report.html', '销售报表');

// 导出 StringGrid
TDataExport.ToCSV(StringGrid1, 'grid.csv');

// 自定义选项
TDataExport.ToCSV(MyDataSet, 'data.csv', [
  eoIncludeHeaders,     // 包含列标题
  eoQuoteStrings        // 字符串加引号
], ';');                // 使用分号分隔
```

### 7. 启动画面

```delphi
uses UniBase.SplashScreen;

// 显示启动画面
TSplashScreen.Show('splash.png');
TSplashScreen.SetStatus('正在加载配置...');
TSplashScreen.SetProgress(20);

// 执行初始化...
TSplashScreen.SetStatus('正在连接数据库...');
TSplashScreen.SetProgress(50);

// 初始化完成
TSplashScreen.SetProgress(100);
TSplashScreen.Hide;  // 淡出关闭
```

### 8. LLM 集成

```delphi
uses UniBase.LLM;

// 同步调用
var response: string;
if UniBase.LLM.Chat('你好，请介绍一下 Delphi', response, 'Default') then
  ShowMessage(response);

// 异步调用
UniBase.LLM.ChatAsync('翻译成英文: ' + text, 
  procedure(const Response: string; Success: Boolean; const Error: string)
  begin
    if Success then
      Memo1.Text := Response
    else
      ShowMessage('错误: ' + Error);
  end);
```

---

## VCL 控件一览

| 控件 | 说明 | 关键属性 |
|------|------|----------|
| `TConfigEdit` | 配置绑定编辑框 | `ConfigKey`, `DefaultValue`, `AutoSave` |
| `TConfigCheckBox` | 配置绑定复选框 | `ConfigKey`, `DefaultValue` |
| `TConfigSpinEdit` | 配置绑定数字框 | `ConfigKey`, `MinValue`, `MaxValue` |
| `TI18nLabel` | 自动翻译标签 | `TextKey` |
| `TI18nButton` | 自动翻译按钮 | `TextKey` |
| `TLanguageComboBox` | 语言选择下拉框 | `AutoSwitch` |
| `TThemeComboBox` | 主题选择下拉框 | `AutoApply` |
| `TFormStateHelper` | 窗体状态辅助 | `AutoSave`, `AutoRestore` |
| `TLogListView` | 日志查看列表 | `MaxItems`, `AutoScroll` |
| `TLLMConfigPanel` | LLM 配置面板 | `ConfigName`, `Connection` |

---

## 常见问题

### Q: 初始化失败怎么办？

检查 `UniBase.InitErrorCode`：

| 错误码 | 说明 | 解决方案 |
|--------|------|----------|
| `iecNone` | 成功 | - |
| `iecRootPathNotFound` | 找不到根路径 | 确保 EXE 目录可写，或创建 `root.txt` |
| `iecDatabaseNotFound` | 数据库不存在 | 首次运行会自动创建；检查路径权限 |
| `iecDatabaseOpenFailed` | 无法打开数据库 | 检查 SQLite 驱动是否安装 |
| `iecSchemaValidationFailed` | Schema 校验失败 | 数据库版本不兼容，需要迁移 |

### Q: 如何自定义数据库位置？

```delphi
// 方式一：使用 root.txt
// 在 EXE 目录创建 root.txt，内容为数据库路径

// 方式二：代码指定
UniBase.InitializeEx('C:\MyApp\Data', 'config.db');

// 方式三：直接传入连接
UniBase.InitializeWithDB(MyFDConnection);
```

### Q: 如何添加新的翻译？

1. 使用 **UniBase Studio** 的翻译管理界面
2. 或直接操作数据库 `I18nTexts` 表
3. 或使用 CLI 工具：`unibase i18n add "Hello" "你好" zh-CN`

### Q: 配置修改后如何实时生效？

```delphi
// 注册配置变更回调
UniBase.Config.OnConfigChanged := procedure(const Key, OldValue, NewValue: string)
begin
  if Key = 'App.Theme' then
    ApplyTheme(NewValue);
end;
```

---

## 下一步

- 📖 [完整 API 参考](02_API_Reference.md)
- 🏗️ [架构文档](01_Architecture.md)
- 🔧 [UniBase Studio 使用手册](User_Manual_Studio.md)
- 💻 [CLI 工具手册](User_Manual_CLI.md)
- 📋 [最佳实践](Best_Practices.md)
- ❓ [FAQ 和故障排除](03_FAQ_Troubleshooting.md)

---

## 示例工程

框架自带两个示例工程：

| 示例 | 位置 | 说明 |
|------|------|------|
| **Phase0Demo** | `Examples/Phase0Demo/` | 核心功能演示（配置、i18n、窗体状态） |
| **Phase1Demo** | `Examples/Phase1Demo/` | VCL 控件演示（完整功能展示） |

运行示例：

1. 打开 `Examples/Phase0Demo/Phase0Demo.dproj`
2. 编译并运行
3. 观察日志输出和功能演示

---

**文档版本**: 1.0  
**最后更新**: 2025-12-02  
**适用版本**: UniBase v0.3+
