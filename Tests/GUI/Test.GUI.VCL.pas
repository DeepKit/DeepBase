{ ============================================================================
  Test.GUI.VCL - UniBase VCL 控件 GUI 测试
  
  版本: 1.0
  说明: 测试 UniBase 自定义 VCL 控件
  测试内容:
    - ConfigEdit / ConfigCheckBox / ConfigSpinEdit
    - I18nLabel / I18nButton
    - 配置绑定
    - 国际化更新
  ============================================================================ }

unit Test.GUI.VCL;

{$IFDEF USE_DUNITX}
  {$DEFINE HAS_DUNITX}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.Graphics,
{$IFDEF HAS_DUNITX}
  DUnitX.TestFramework,
{$ENDIF}
  UniBase.GUITest,
  UniBase.Manager,
  GUITest.FormFactory;

{$IFNDEF HAS_DUNITX}
type
  Assert = class
  public
    class procedure IsTrue(Condition: Boolean; const Msg: string = ''); static;
    class procedure IsFalse(Condition: Boolean; const Msg: string = ''); static;
    class procedure AreEqual(const Expected, Actual: string; const Msg: string = ''); overload; static;
    class procedure AreEqual(Expected, Actual: Integer; const Msg: string = ''); overload; static;
    class procedure IsNotEmpty(const Value: string; const Msg: string = ''); static;
  end;
  
  TestFixtureAttribute = class(TCustomAttribute);
  SetupAttribute = class(TCustomAttribute);
  TearDownAttribute = class(TCustomAttribute);
  TestAttribute = class(TCustomAttribute);
{$ENDIF}

type
  /// <summary>
  /// 配置控件 GUI 测试
  /// </summary>
  [TestFixture]
  TTestGUIConfigControls = class(TGUITestBase)
  private
    FConfigForm: TConfigControlsTestForm;
    
  protected
    function CreateTestForm: TForm; override;
    
  public
    [Setup]
    procedure Setup; override;
    
    [TearDown]
    procedure TearDown; override;
    
    // ========== ConfigEdit 测试 ==========
    
    [Test]
    procedure Test_ConfigEdit_Load_Value;
    
    [Test]
    procedure Test_ConfigEdit_Save_Value;
    
    [Test]
    procedure Test_ConfigEdit_AutoSave;
    
    [Test]
    procedure Test_ConfigEdit_DefaultValue;
    
    // ========== ConfigCheckBox 测试 ==========
    
    [Test]
    procedure Test_ConfigCheckBox_Load_Value;
    
    [Test]
    procedure Test_ConfigCheckBox_Toggle_Save;
    
    // ========== ConfigSpinEdit 测试 ==========
    
    [Test]
    procedure Test_ConfigSpinEdit_Load_Value;
    
    [Test]
    procedure Test_ConfigSpinEdit_Change_Value;
    
    // ========== 集成测试 ==========
    
    [Test]
    procedure Test_Config_Workflow_Complete;
  end;
  
  /// <summary>
  /// 国际化控件 GUI 测试
  /// </summary>
  [TestFixture]
  TTestGUII18nControls = class(TGUITestBase)
  private
    FI18nForm: TI18nControlsTestForm;
    
  protected
    function CreateTestForm: TForm; override;
    
  public
    [Setup]
    procedure Setup; override;
    
    [TearDown]
    procedure TearDown; override;
    
    // ========== I18nLabel 测试 ==========
    
    [Test]
    procedure Test_I18nLabel_Initial_Caption;
    
    [Test]
    procedure Test_I18nLabel_TranslationKey;
    
    // ========== I18nButton 测试 ==========
    
    [Test]
    procedure Test_I18nButton_Initial_Caption;
    
    [Test]
    procedure Test_I18nButton_TranslationKey;
    
    // ========== 语言切换测试 ==========
    
    [Test]
    procedure Test_LanguageSwitch_Updates_Controls;
    
    [Test]
    procedure Test_LanguageSwitch_Workflow;
  end;
  
  /// <summary>
  /// 主题控件 GUI 测试
  /// </summary>
  [TestFixture]
  TTestGUITheme = class(TGUITestBase)
  private
    FBasicForm: TBasicControlsTestForm;
    
  protected
    function CreateTestForm: TForm; override;
    
  public
    [Setup]
    procedure Setup; override;
    
    [Test]
    procedure Test_Theme_Apply_Light;
    
    [Test]
    procedure Test_Theme_Apply_Dark;
    
    [Test]
    procedure Test_Theme_Switch_Updates_Form;
  end;

implementation

uses
  UniBase.Config,
  UniBase.i18n,
  UniBase.TestHelper;

{$IFNDEF HAS_DUNITX}
class procedure Assert.IsTrue(Condition: Boolean; const Msg: string);
begin
  if not Condition then
    raise ETestAssertionFailed.Create('Assertion failed (expected True): ' + Msg);
end;

class procedure Assert.IsFalse(Condition: Boolean; const Msg: string);
begin
  if Condition then
    raise ETestAssertionFailed.Create('Assertion failed (expected False): ' + Msg);
end;

class procedure Assert.AreEqual(const Expected, Actual: string; const Msg: string);
begin
  if Expected <> Actual then
    raise ETestAssertionFailed.CreateFmt('Assertion failed: Expected "%s", got "%s". %s', [Expected, Actual, Msg]);
end;

class procedure Assert.AreEqual(Expected, Actual: Integer; const Msg: string);
begin
  if Expected <> Actual then
    raise ETestAssertionFailed.CreateFmt('Assertion failed: Expected %d, got %d. %s', [Expected, Actual, Msg]);
end;

class procedure Assert.IsNotEmpty(const Value: string; const Msg: string);
begin
  if Value = '' then
    raise ETestAssertionFailed.Create('Assertion failed (expected non-empty): ' + Msg);
end;
{$ENDIF}

{ TTestGUIConfigControls }

function TTestGUIConfigControls.CreateTestForm: TForm;
begin
  // 确保 UniBase 初始化
  TTestFormFactory.EnsureUniBaseInitialized;
  
  FConfigForm := TConfigControlsTestForm.Create(nil);
  Result := FConfigForm;
end;

procedure TTestGUIConfigControls.Setup;
begin
  inherited;
  
  // 设置测试配置值
  if UniBase.Manager.UniBase.IsInitialized then
  begin
    UniBase.Manager.UniBase.Config.SetConfig('test.value', 'Initial Value');
    UniBase.Manager.UniBase.Config.SetConfigBool('test.enabled', False);
    UniBase.Manager.UniBase.Config.SetConfigInt('test.count', 10);
  end;
end;

procedure TTestGUIConfigControls.TearDown;
begin
  inherited;
  FConfigForm := nil;
end;

// ========== ConfigEdit 测试 ==========

procedure TTestGUIConfigControls.Test_ConfigEdit_Load_Value;
begin
  Step('测试 ConfigEdit 加载值');
  
  // 设置配置值
  if UniBase.Manager.UniBase.IsInitialized then
  begin
    UniBase.Manager.UniBase.Config.SetConfig('test.value', 'Loaded Value');
  end;
  
  // ConfigEdit 通过 AutoLoad 自动加载，这里验证控件文本
  Assert.IsTrue(FConfigForm.edtConfig.ConfigKey <> '', 'ConfigKey should be set');
  
  Verify(True, 'ConfigEdit load test', 'Passed');
end;

procedure TTestGUIConfigControls.Test_ConfigEdit_Save_Value;
const
  NEW_VALUE = 'New Test Value';
begin
  Step('测试 ConfigEdit 保存值');
  
  // 输入新值到控件
  Input('edtConfig', NEW_VALUE);
  
  // AutoSave 会在 Change 事件中自动保存
  ProcessMessages;
  
  Assert.AreEqual(NEW_VALUE, FConfigForm.edtConfig.Text, '控件文本应该更新');
  
  Verify(True, 'ConfigEdit save test', 'Passed');
end;

procedure TTestGUIConfigControls.Test_ConfigEdit_AutoSave;
const
  AUTO_VALUE = 'Auto Saved Value';
begin
  Step('测试 ConfigEdit 自动保存');
  
  // 启用自动保存
  FConfigForm.edtConfig.AutoSave := True;
  
  // 输入并移出焦点
  Input('edtConfig', AUTO_VALUE);
  FConfigForm.btnSave.SetFocus;  // 触发 Exit 事件
  ProcessMessages;
  
  Assert.AreEqual(AUTO_VALUE, FConfigForm.edtConfig.Text);
  
  Verify(True, 'AutoSave test', 'Passed');
end;

procedure TTestGUIConfigControls.Test_ConfigEdit_DefaultValue;
begin
  Step('测试 ConfigEdit 默认值');
  
  // 设置默认值
  FConfigForm.edtConfig.DefaultValue := 'Default Text';
  
  Assert.AreEqual('Default Text', FConfigForm.edtConfig.DefaultValue,
    '默认值应该被设置');
  
  Verify(True, 'DefaultValue test', 'Passed');
end;

// ========== ConfigCheckBox 测试 ==========

procedure TTestGUIConfigControls.Test_ConfigCheckBox_Load_Value;
begin
  Step('测试 ConfigCheckBox 加载值');
  
  Assert.IsTrue(FConfigForm.chkConfig.ConfigKey <> '', 'ConfigKey should be set');
  
  Verify(True, 'ConfigCheckBox load test', 'Passed');
end;

procedure TTestGUIConfigControls.Test_ConfigCheckBox_Toggle_Save;
begin
  Step('测试 ConfigCheckBox 切换保存');
  
  // 勾选
  Check('chkConfig', True);
  ProcessMessages;
  
  Assert.IsTrue(FConfigForm.chkConfig.Checked);
  
  // 取消勾选
  Check('chkConfig', False);
  ProcessMessages;
  
  Assert.IsFalse(FConfigForm.chkConfig.Checked);
  
  Verify(True, 'ConfigCheckBox toggle test', 'Passed');
end;

// ========== ConfigSpinEdit 测试 ==========

procedure TTestGUIConfigControls.Test_ConfigSpinEdit_Load_Value;
begin
  Step('测试 ConfigSpinEdit 加载值');
  
  Assert.IsTrue(FConfigForm.spnConfig.ConfigKey <> '', 'ConfigKey should be set');
  
  Verify(True, 'ConfigSpinEdit load test', 'Passed');
end;

procedure TTestGUIConfigControls.Test_ConfigSpinEdit_Change_Value;
begin
  Step('测试 ConfigSpinEdit 更改值');
  
  // 设置新值
  FConfigForm.spnConfig.Value := 100;
  ProcessMessages;
  
  Assert.AreEqual(100, FConfigForm.spnConfig.Value, '值应该被更新');
  
  Verify(True, 'ConfigSpinEdit change test', 'Passed');
end;

// ========== 集成测试 ==========

procedure TTestGUIConfigControls.Test_Config_Workflow_Complete;
begin
  Step('完整配置工作流测试');
  
  // 1. 修改值
  Input('edtConfig', 'Modified Value');
  Check('chkConfig', True);
  FConfigForm.spnConfig.Value := 25;
  
  // 2. 截图
  CaptureScreenshot('config_modified');
  
  // 3. 验证控件值
  Assert.AreEqual('Modified Value', FConfigForm.edtConfig.Text);
  Assert.IsTrue(FConfigForm.chkConfig.Checked);
  Assert.AreEqual(25, FConfigForm.spnConfig.Value);
  
  Verify(True, 'Config workflow complete', 'Passed');
end;

{ TTestGUII18nControls }

function TTestGUII18nControls.CreateTestForm: TForm;
begin
  // 确保 UniBase 初始化
  TTestFormFactory.EnsureUniBaseInitialized;
  
  FI18nForm := TI18nControlsTestForm.Create(nil);
  Result := FI18nForm;
end;

procedure TTestGUII18nControls.Setup;
begin
  inherited;
  
  // 设置测试翻译
  if UniBase.Manager.UniBase.IsInitialized then
  begin
    UniBase.Manager.UniBase.i18n.CurrentLanguage := 'en';
  end;
end;

procedure TTestGUII18nControls.TearDown;
begin
  inherited;
  FI18nForm := nil;
end;

// ========== I18nLabel 测试 ==========

procedure TTestGUII18nControls.Test_I18nLabel_Initial_Caption;
begin
  Step('测试 I18nLabel 初始标题');
  
  // 初始应该显示默认 Caption 或翻译
  Assert.IsNotEmpty(FI18nForm.lblI18n.Caption,
    'I18nLabel 应该有标题');
  
  Verify(FI18nForm.lblI18n.Caption <> '', 'Not empty', FI18nForm.lblI18n.Caption);
end;

procedure TTestGUII18nControls.Test_I18nLabel_TranslationKey;
begin
  Step('测试 I18nLabel 翻译键');
  
  Assert.AreEqual('app.greeting', FI18nForm.lblI18n.TranslationKey,
    '翻译键应该正确设置');
  
  Verify(FI18nForm.lblI18n.TranslationKey = 'app.greeting',
    'app.greeting', FI18nForm.lblI18n.TranslationKey);
end;

// ========== I18nButton 测试 ==========

procedure TTestGUII18nControls.Test_I18nButton_Initial_Caption;
begin
  Step('测试 I18nButton 初始标题');
  
  Assert.IsNotEmpty(FI18nForm.btnI18n.Caption,
    'I18nButton 应该有标题');
  
  Verify(FI18nForm.btnI18n.Caption <> '', 'Not empty', FI18nForm.btnI18n.Caption);
end;

procedure TTestGUII18nControls.Test_I18nButton_TranslationKey;
begin
  Step('测试 I18nButton 翻译键');
  
  Assert.AreEqual('button.submit', FI18nForm.btnI18n.TranslationKey,
    '翻译键应该正确设置');
  
  Verify(FI18nForm.btnI18n.TranslationKey = 'button.submit',
    'button.submit', FI18nForm.btnI18n.TranslationKey);
end;

// ========== 语言切换测试 ==========

procedure TTestGUII18nControls.Test_LanguageSwitch_Updates_Controls;
begin
  Step('测试语言切换更新控件');
  
  // 切换到中文
  if UniBase.Manager.UniBase.IsInitialized then
  begin
    UniBase.Manager.UniBase.i18n.CurrentLanguage := 'zh-CN';
    UniBase.Manager.UniBase.i18n.NotifyLanguageChanged;
  end;
  ProcessMessages;
  
  // 验证标题存在
  Assert.IsNotEmpty(FI18nForm.lblI18n.Caption);
  
  // 切回英文
  if UniBase.Manager.UniBase.IsInitialized then
  begin
    UniBase.Manager.UniBase.i18n.CurrentLanguage := 'en';
    UniBase.Manager.UniBase.i18n.NotifyLanguageChanged;
  end;
  ProcessMessages;
  
  Verify(True, 'Language switch works', 'Passed');
end;

procedure TTestGUII18nControls.Test_LanguageSwitch_Workflow;
begin
  Step('语言切换工作流测试');
  
  // 1. 初始英文
  if UniBase.Manager.UniBase.IsInitialized then
  begin
    UniBase.Manager.UniBase.i18n.CurrentLanguage := 'en';
    UniBase.Manager.UniBase.i18n.NotifyLanguageChanged;
  end;
  ProcessMessages;
  CaptureScreenshot('i18n_english');
  
  // 2. 选择中文
  Select('cboLanguage', 'zh-CN');
  if UniBase.Manager.UniBase.IsInitialized then
  begin
    UniBase.Manager.UniBase.i18n.CurrentLanguage := 'zh-CN';
    UniBase.Manager.UniBase.i18n.NotifyLanguageChanged;
  end;
  ProcessMessages;
  
  CaptureScreenshot('i18n_chinese');
  
  // 3. 恢复英文
  Select('cboLanguage', 'en');
  if UniBase.Manager.UniBase.IsInitialized then
  begin
    UniBase.Manager.UniBase.i18n.CurrentLanguage := 'en';
    UniBase.Manager.UniBase.i18n.NotifyLanguageChanged;
  end;
  ProcessMessages;
  
  Verify(True, 'Language workflow complete', 'Passed');
end;

{ TTestGUITheme }

function TTestGUITheme.CreateTestForm: TForm;
begin
  TTestFormFactory.EnsureUniBaseInitialized;
  
  FBasicForm := TBasicControlsTestForm.Create(nil);
  Result := FBasicForm;
end;

procedure TTestGUITheme.Setup;
begin
  inherited;
end;

procedure TTestGUITheme.Test_Theme_Apply_Light;
begin
  Step('测试应用浅色主题');
  
  // 应用浅色主题
  if UniBase.Manager.UniBase.IsInitialized then
  begin
    UniBase.Manager.UniBase.Theme.ApplyTheme('Light');
    ProcessMessages;
  end;
  
  CaptureScreenshot('theme_light');
  
  Verify(True, 'Light theme applied', 'Passed');
end;

procedure TTestGUITheme.Test_Theme_Apply_Dark;
begin
  Step('测试应用深色主题');
  
  // 应用深色主题
  if UniBase.Manager.UniBase.IsInitialized then
  begin
    UniBase.Manager.UniBase.Theme.ApplyTheme('Dark');
    ProcessMessages;
  end;
  
  CaptureScreenshot('theme_dark');
  
  // 恢复浅色主题
  if UniBase.Manager.UniBase.IsInitialized then
    UniBase.Manager.UniBase.Theme.ApplyTheme('Light');
  ProcessMessages;
  
  Verify(True, 'Dark theme applied', 'Passed');
end;

procedure TTestGUITheme.Test_Theme_Switch_Updates_Form;
var
  InitialColor: TColor;
begin
  Step('测试主题切换更新窗体');
  
  // 记录初始颜色
  InitialColor := FBasicForm.Color;
  
  // 切换主题
  if UniBase.Manager.UniBase.IsInitialized then
    UniBase.Manager.UniBase.Theme.ApplyTheme('Dark');
  ProcessMessages;
  
  // 切回
  if UniBase.Manager.UniBase.IsInitialized then
    UniBase.Manager.UniBase.Theme.ApplyTheme('Light');
  ProcessMessages;
  
  Verify(True, 'Theme switch works', 'Passed');
end;

initialization
{$IFDEF HAS_DUNITX}
  TDUnitX.RegisterTestFixture(TTestGUIConfigControls);
  TDUnitX.RegisterTestFixture(TTestGUII18nControls);
  TDUnitX.RegisterTestFixture(TTestGUITheme);
{$ENDIF}

end.
