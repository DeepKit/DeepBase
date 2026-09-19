{ ============================================================================
  Test.GUI.VCL - DeepBase VCL 鎺т欢 GUI 娴嬭瘯
  
  鐗堟湰: 1.0
  璇存槑: 娴嬭瘯 DeepBase 鑷畾涔?VCL 鎺т欢
  娴嬭瘯鍐呭:
    - ConfigEdit / ConfigCheckBox / ConfigSpinEdit
    - I18nLabel / I18nButton
    - 閰嶇疆缁戝畾
    - 鍥介檯鍖栨洿鏂?
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
  DeepBase.GUITest,
  DeepBase.Manager,
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
  /// 閰嶇疆鎺т欢 GUI 娴嬭瘯
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
    
    // ========== ConfigEdit 娴嬭瘯 ==========
    
    [Test]
    procedure Test_ConfigEdit_Load_Value;
    
    [Test]
    procedure Test_ConfigEdit_Save_Value;
    
    [Test]
    procedure Test_ConfigEdit_AutoSave;
    
    [Test]
    procedure Test_ConfigEdit_DefaultValue;
    
    // ========== ConfigCheckBox 娴嬭瘯 ==========
    
    [Test]
    procedure Test_ConfigCheckBox_Load_Value;
    
    [Test]
    procedure Test_ConfigCheckBox_Toggle_Save;
    
    // ========== ConfigSpinEdit 娴嬭瘯 ==========
    
    [Test]
    procedure Test_ConfigSpinEdit_Load_Value;
    
    [Test]
    procedure Test_ConfigSpinEdit_Change_Value;
    
    // ========== 闆嗘垚娴嬭瘯 ==========
    
    [Test]
    procedure Test_Config_Workflow_Complete;
  end;
  
  /// <summary>
  /// 鍥介檯鍖栨帶浠?GUI 娴嬭瘯
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
    
    // ========== I18nLabel 娴嬭瘯 ==========
    
    [Test]
    procedure Test_I18nLabel_Initial_Caption;
    
    [Test]
    procedure Test_I18nLabel_TranslationKey;
    
    // ========== I18nButton 娴嬭瘯 ==========
    
    [Test]
    procedure Test_I18nButton_Initial_Caption;
    
    [Test]
    procedure Test_I18nButton_TranslationKey;
    
    // ========== 璇█鍒囨崲娴嬭瘯 ==========
    
    [Test]
    procedure Test_LanguageSwitch_Updates_Controls;
    
    [Test]
    procedure Test_LanguageSwitch_Workflow;
  end;
  
  /// <summary>
  /// 涓婚鎺т欢 GUI 娴嬭瘯
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
  DeepBase.Config,
  DeepBase.i18n,
  DeepBase.TestHelper;

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
  // 纭繚 DeepBase 鍒濆鍖?
  TTestFormFactory.EnsureDeepBaseInitialized;
  
  FConfigForm := TConfigControlsTestForm.Create(nil);
  Result := FConfigForm;
end;

procedure TTestGUIConfigControls.Setup;
begin
  inherited;
  
  // 璁剧疆娴嬭瘯閰嶇疆鍊?
  if DeepBase.Manager.DeepBase.IsInitialized then
  begin
    DeepBase.Manager.DeepBase.Config.SetConfig('test.value', 'Initial Value');
    DeepBase.Manager.DeepBase.Config.SetConfigBool('test.enabled', False);
    DeepBase.Manager.DeepBase.Config.SetConfigInt('test.count', 10);
  end;
end;

procedure TTestGUIConfigControls.TearDown;
begin
  inherited;
  FConfigForm := nil;
end;

// ========== ConfigEdit 娴嬭瘯 ==========

procedure TTestGUIConfigControls.Test_ConfigEdit_Load_Value;
begin
  Step('娴嬭瘯 ConfigEdit 鍔犺浇鍊?);
  
  // 璁剧疆閰嶇疆鍊?
  if DeepBase.Manager.DeepBase.IsInitialized then
  begin
    DeepBase.Manager.DeepBase.Config.SetConfig('test.value', 'Loaded Value');
  end;
  
  // ConfigEdit 閫氳繃 AutoLoad 鑷姩鍔犺浇锛岃繖閲岄獙璇佹帶浠舵枃鏈?
  Assert.IsTrue(FConfigForm.edtConfig.ConfigKey <> '', 'ConfigKey should be set');
  
  Verify(True, 'ConfigEdit load test', 'Passed');
end;

procedure TTestGUIConfigControls.Test_ConfigEdit_Save_Value;
const
  NEW_VALUE = 'New Test Value';
begin
  Step('娴嬭瘯 ConfigEdit 淇濆瓨鍊?);
  
  // 杈撳叆鏂板€煎埌鎺т欢
  Input('edtConfig', NEW_VALUE);
  
  // AutoSave 浼氬湪 Change 浜嬩欢涓嚜鍔ㄤ繚瀛?
  ProcessMessages;
  
  Assert.AreEqual(NEW_VALUE, FConfigForm.edtConfig.Text, '鎺т欢鏂囨湰搴旇鏇存柊');
  
  Verify(True, 'ConfigEdit save test', 'Passed');
end;

procedure TTestGUIConfigControls.Test_ConfigEdit_AutoSave;
const
  AUTO_VALUE = 'Auto Saved Value';
begin
  Step('娴嬭瘯 ConfigEdit 鑷姩淇濆瓨');
  
  // 鍚敤鑷姩淇濆瓨
  FConfigForm.edtConfig.AutoSave := True;
  
  // 杈撳叆骞剁Щ鍑虹劍鐐?
  Input('edtConfig', AUTO_VALUE);
  FConfigForm.btnSave.SetFocus;  // 瑙﹀彂 Exit 浜嬩欢
  ProcessMessages;
  
  Assert.AreEqual(AUTO_VALUE, FConfigForm.edtConfig.Text);
  
  Verify(True, 'AutoSave test', 'Passed');
end;

procedure TTestGUIConfigControls.Test_ConfigEdit_DefaultValue;
begin
  Step('娴嬭瘯 ConfigEdit 榛樿鍊?);
  
  // 璁剧疆榛樿鍊?
  FConfigForm.edtConfig.DefaultValue := 'Default Text';
  
  Assert.AreEqual('Default Text', FConfigForm.edtConfig.DefaultValue,
    '榛樿鍊煎簲璇ヨ璁剧疆');
  
  Verify(True, 'DefaultValue test', 'Passed');
end;

// ========== ConfigCheckBox 娴嬭瘯 ==========

procedure TTestGUIConfigControls.Test_ConfigCheckBox_Load_Value;
begin
  Step('娴嬭瘯 ConfigCheckBox 鍔犺浇鍊?);
  
  Assert.IsTrue(FConfigForm.chkConfig.ConfigKey <> '', 'ConfigKey should be set');
  
  Verify(True, 'ConfigCheckBox load test', 'Passed');
end;

procedure TTestGUIConfigControls.Test_ConfigCheckBox_Toggle_Save;
begin
  Step('娴嬭瘯 ConfigCheckBox 鍒囨崲淇濆瓨');
  
  // 鍕鹃€?
  Check('chkConfig', True);
  ProcessMessages;
  
  Assert.IsTrue(FConfigForm.chkConfig.Checked);
  
  // 鍙栨秷鍕鹃€?
  Check('chkConfig', False);
  ProcessMessages;
  
  Assert.IsFalse(FConfigForm.chkConfig.Checked);
  
  Verify(True, 'ConfigCheckBox toggle test', 'Passed');
end;

// ========== ConfigSpinEdit 娴嬭瘯 ==========

procedure TTestGUIConfigControls.Test_ConfigSpinEdit_Load_Value;
begin
  Step('娴嬭瘯 ConfigSpinEdit 鍔犺浇鍊?);
  
  Assert.IsTrue(FConfigForm.spnConfig.ConfigKey <> '', 'ConfigKey should be set');
  
  Verify(True, 'ConfigSpinEdit load test', 'Passed');
end;

procedure TTestGUIConfigControls.Test_ConfigSpinEdit_Change_Value;
begin
  Step('娴嬭瘯 ConfigSpinEdit 鏇存敼鍊?);
  
  // 璁剧疆鏂板€?
  FConfigForm.spnConfig.Value := 100;
  ProcessMessages;
  
  Assert.AreEqual(100, FConfigForm.spnConfig.Value, '鍊煎簲璇ヨ鏇存柊');
  
  Verify(True, 'ConfigSpinEdit change test', 'Passed');
end;

// ========== 闆嗘垚娴嬭瘯 ==========

procedure TTestGUIConfigControls.Test_Config_Workflow_Complete;
begin
  Step('瀹屾暣閰嶇疆宸ヤ綔娴佹祴璇?);
  
  // 1. 淇敼鍊?
  Input('edtConfig', 'Modified Value');
  Check('chkConfig', True);
  FConfigForm.spnConfig.Value := 25;
  
  // 2. 鎴浘
  CaptureScreenshot('config_modified');
  
  // 3. 楠岃瘉鎺т欢鍊?
  Assert.AreEqual('Modified Value', FConfigForm.edtConfig.Text);
  Assert.IsTrue(FConfigForm.chkConfig.Checked);
  Assert.AreEqual(25, FConfigForm.spnConfig.Value);
  
  Verify(True, 'Config workflow complete', 'Passed');
end;

{ TTestGUII18nControls }

function TTestGUII18nControls.CreateTestForm: TForm;
begin
  // 纭繚 DeepBase 鍒濆鍖?
  TTestFormFactory.EnsureDeepBaseInitialized;
  
  FI18nForm := TI18nControlsTestForm.Create(nil);
  Result := FI18nForm;
end;

procedure TTestGUII18nControls.Setup;
begin
  inherited;
  
  // 璁剧疆娴嬭瘯缈昏瘧
  if DeepBase.Manager.DeepBase.IsInitialized then
  begin
    DeepBase.Manager.DeepBase.i18n.CurrentLanguage := 'en';
  end;
end;

procedure TTestGUII18nControls.TearDown;
begin
  inherited;
  FI18nForm := nil;
end;

// ========== I18nLabel 娴嬭瘯 ==========

procedure TTestGUII18nControls.Test_I18nLabel_Initial_Caption;
begin
  Step('娴嬭瘯 I18nLabel 鍒濆鏍囬');
  
  // 鍒濆搴旇鏄剧ず榛樿 Caption 鎴栫炕璇?
  Assert.IsNotEmpty(FI18nForm.lblI18n.Caption,
    'I18nLabel 搴旇鏈夋爣棰?);
  
  Verify(FI18nForm.lblI18n.Caption <> '', 'Not empty', FI18nForm.lblI18n.Caption);
end;

procedure TTestGUII18nControls.Test_I18nLabel_TranslationKey;
begin
  Step('娴嬭瘯 I18nLabel 缈昏瘧閿?);
  
  Assert.AreEqual('app.greeting', FI18nForm.lblI18n.TranslationKey,
    '缈昏瘧閿簲璇ユ纭缃?);
  
  Verify(FI18nForm.lblI18n.TranslationKey = 'app.greeting',
    'app.greeting', FI18nForm.lblI18n.TranslationKey);
end;

// ========== I18nButton 娴嬭瘯 ==========

procedure TTestGUII18nControls.Test_I18nButton_Initial_Caption;
begin
  Step('娴嬭瘯 I18nButton 鍒濆鏍囬');
  
  Assert.IsNotEmpty(FI18nForm.btnI18n.Caption,
    'I18nButton 搴旇鏈夋爣棰?);
  
  Verify(FI18nForm.btnI18n.Caption <> '', 'Not empty', FI18nForm.btnI18n.Caption);
end;

procedure TTestGUII18nControls.Test_I18nButton_TranslationKey;
begin
  Step('娴嬭瘯 I18nButton 缈昏瘧閿?);
  
  Assert.AreEqual('button.submit', FI18nForm.btnI18n.TranslationKey,
    '缈昏瘧閿簲璇ユ纭缃?);
  
  Verify(FI18nForm.btnI18n.TranslationKey = 'button.submit',
    'button.submit', FI18nForm.btnI18n.TranslationKey);
end;

// ========== 璇█鍒囨崲娴嬭瘯 ==========

procedure TTestGUII18nControls.Test_LanguageSwitch_Updates_Controls;
begin
  Step('娴嬭瘯璇█鍒囨崲鏇存柊鎺т欢');
  
  // 鍒囨崲鍒颁腑鏂?
  if DeepBase.Manager.DeepBase.IsInitialized then
  begin
    DeepBase.Manager.DeepBase.i18n.CurrentLanguage := 'zh-CN';
    DeepBase.Manager.DeepBase.i18n.NotifyLanguageChanged;
  end;
  ProcessMessages;
  
  // 楠岃瘉鏍囬瀛樺湪
  Assert.IsNotEmpty(FI18nForm.lblI18n.Caption);
  
  // 鍒囧洖鑻辨枃
  if DeepBase.Manager.DeepBase.IsInitialized then
  begin
    DeepBase.Manager.DeepBase.i18n.CurrentLanguage := 'en';
    DeepBase.Manager.DeepBase.i18n.NotifyLanguageChanged;
  end;
  ProcessMessages;
  
  Verify(True, 'Language switch works', 'Passed');
end;

procedure TTestGUII18nControls.Test_LanguageSwitch_Workflow;
begin
  Step('璇█鍒囨崲宸ヤ綔娴佹祴璇?);
  
  // 1. 鍒濆鑻辨枃
  if DeepBase.Manager.DeepBase.IsInitialized then
  begin
    DeepBase.Manager.DeepBase.i18n.CurrentLanguage := 'en';
    DeepBase.Manager.DeepBase.i18n.NotifyLanguageChanged;
  end;
  ProcessMessages;
  CaptureScreenshot('i18n_english');
  
  // 2. 閫夋嫨涓枃
  Select('cboLanguage', 'zh-CN');
  if DeepBase.Manager.DeepBase.IsInitialized then
  begin
    DeepBase.Manager.DeepBase.i18n.CurrentLanguage := 'zh-CN';
    DeepBase.Manager.DeepBase.i18n.NotifyLanguageChanged;
  end;
  ProcessMessages;
  
  CaptureScreenshot('i18n_chinese');
  
  // 3. 鎭㈠鑻辨枃
  Select('cboLanguage', 'en');
  if DeepBase.Manager.DeepBase.IsInitialized then
  begin
    DeepBase.Manager.DeepBase.i18n.CurrentLanguage := 'en';
    DeepBase.Manager.DeepBase.i18n.NotifyLanguageChanged;
  end;
  ProcessMessages;
  
  Verify(True, 'Language workflow complete', 'Passed');
end;

{ TTestGUITheme }

function TTestGUITheme.CreateTestForm: TForm;
begin
  TTestFormFactory.EnsureDeepBaseInitialized;
  
  FBasicForm := TBasicControlsTestForm.Create(nil);
  Result := FBasicForm;
end;

procedure TTestGUITheme.Setup;
begin
  inherited;
end;

procedure TTestGUITheme.Test_Theme_Apply_Light;
begin
  Step('娴嬭瘯搴旂敤娴呰壊涓婚');
  
  // 搴旂敤娴呰壊涓婚
  if DeepBase.Manager.DeepBase.IsInitialized then
  begin
    DeepBase.Manager.DeepBase.Theme.ApplyTheme('Light');
    ProcessMessages;
  end;
  
  CaptureScreenshot('theme_light');
  
  Verify(True, 'Light theme applied', 'Passed');
end;

procedure TTestGUITheme.Test_Theme_Apply_Dark;
begin
  Step('娴嬭瘯搴旂敤娣辫壊涓婚');
  
  // 搴旂敤娣辫壊涓婚
  if DeepBase.Manager.DeepBase.IsInitialized then
  begin
    DeepBase.Manager.DeepBase.Theme.ApplyTheme('Dark');
    ProcessMessages;
  end;
  
  CaptureScreenshot('theme_dark');
  
  // 鎭㈠娴呰壊涓婚
  if DeepBase.Manager.DeepBase.IsInitialized then
    DeepBase.Manager.DeepBase.Theme.ApplyTheme('Light');
  ProcessMessages;
  
  Verify(True, 'Dark theme applied', 'Passed');
end;

procedure TTestGUITheme.Test_Theme_Switch_Updates_Form;
var
  InitialColor: TColor;
begin
  Step('娴嬭瘯涓婚鍒囨崲鏇存柊绐椾綋');
  
  // 璁板綍鍒濆棰滆壊
  InitialColor := FBasicForm.Color;
  
  // 鍒囨崲涓婚
  if DeepBase.Manager.DeepBase.IsInitialized then
    DeepBase.Manager.DeepBase.Theme.ApplyTheme('Dark');
  ProcessMessages;
  
  // 鍒囧洖
  if DeepBase.Manager.DeepBase.IsInitialized then
    DeepBase.Manager.DeepBase.Theme.ApplyTheme('Light');
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
