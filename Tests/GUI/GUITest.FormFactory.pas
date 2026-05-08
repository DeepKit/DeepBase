{ ============================================================================
  GUITest.FormFactory - 测试窗体工厂
  
  版本: 1.0
  说明: 提供测试窗体的创建和管理
  功能:
    - 创建标准测试窗体
    - 创建带控件的测试窗体
    - 管理窗体生命周期
    - 提供预配置的测试场景窗体
  ============================================================================ }

unit GUITest.FormFactory;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Menus,
  DeepBase.Manager,
  DeepBase.VCL.ConfigControls,
  DeepBase.VCL.I18nControls;

type
  /// <summary>
  /// 测试窗体类型
  /// </summary>
  TTestFormType = (
    tftEmpty,           // 空窗�?
    tftBasicControls,   // 基础控件窗体
    tftConfigControls,  // 配置控件窗体
    tftI18nControls,    // 国际化控件窗�?
    tftDataEntry,       // 数据录入窗体
    tftMasterDetail,    // 主从窗体
    tftDialog           // 对话框窗�?
  );
  
  /// <summary>
  /// 测试窗体配置
  /// </summary>
  TTestFormConfig = record
    Width: Integer;
    Height: Integer;
    Caption: string;
    Position: TPosition;
    FormLeft: Integer;
    FormTop: Integer;
    InitializeDeepBase: Boolean;
    DBPath: string;
    
    class function Default: TTestFormConfig; static;
  end;
  
  /// <summary>
  /// 测试窗体工厂
  /// </summary>
  TTestFormFactory = class
  private
    class var FCreatedForms: TList;
    
    class procedure AddBasicControls(AForm: TForm);
    class procedure AddConfigControls(AForm: TForm);
    class procedure AddI18nControls(AForm: TForm);
    class procedure AddDataEntryControls(AForm: TForm);
    class procedure AddMasterDetailControls(AForm: TForm);
    class procedure AddDialogControls(AForm: TForm);
    
  public
    class constructor Create;
    class destructor Destroy;
    
    /// <summary>
    /// 创建测试窗体
    /// </summary>
    class function CreateForm(FormType: TTestFormType; 
      Config: TTestFormConfig): TForm; overload;
    class function CreateForm(FormType: TTestFormType): TForm; overload;
    
    /// <summary>
    /// 创建空窗�?
    /// </summary>
    class function CreateEmptyForm(const Caption: string = 'Test Form';
      Width: Integer = 400; Height: Integer = 300): TForm;
    
    /// <summary>
    /// 创建带基础控件的窗�?
    /// </summary>
    class function CreateBasicControlsForm: TForm;
    
    /// <summary>
    /// 创建配置测试窗体
    /// </summary>
    class function CreateConfigTestForm: TForm;
    
    /// <summary>
    /// 创建国际化测试窗�?
    /// </summary>
    class function CreateI18nTestForm: TForm;
    
    /// <summary>
    /// 创建数据录入测试窗体
    /// </summary>
    class function CreateDataEntryForm: TForm;
    
    /// <summary>
    /// 销毁所有创建的窗体
    /// </summary>
    class procedure DestroyAllForms;
    
    /// <summary>
    /// 确保 DeepBase 已初始化
    /// </summary>
    class procedure EnsureDeepBaseInitialized(const DBPath: string = '');
  end;
  
  /// <summary>
  /// 基础控件测试窗体
  /// </summary>
  TBasicControlsTestForm = class(TForm)
  public
    btnOK: TButton;
    btnCancel: TButton;
    edtInput: TEdit;
    lblLabel: TLabel;
    chkOption: TCheckBox;
    rbOption1: TRadioButton;
    rbOption2: TRadioButton;
    cboSelect: TComboBox;
    lbxList: TListBox;
    mmoText: TMemo;
    trkSlider: TTrackBar;
    prgProgress: TProgressBar;
    pnlContainer: TPanel;
    grpOptions: TGroupBox;
    
    constructor Create(AOwner: TComponent); override;
  end;
  
  /// <summary>
  /// 配置控件测试窗体
  /// </summary>
  TConfigControlsTestForm = class(TForm)
  public
    edtConfig: TConfigEdit;
    chkConfig: TConfigCheckBox;
    spnConfig: TConfigSpinEdit;
    lblStatus: TLabel;
    btnSave: TButton;
    btnReset: TButton;
    
    constructor Create(AOwner: TComponent); override;
  end;
  
  /// <summary>
  /// 国际化控件测试窗�?- 带辅助属性的包装�?
  /// </summary>
  TI18nLabelHelper = class helper for TI18nLabel
    function GetTranslationKey: string;
    procedure SetTranslationKey(const Value: string);
    property TranslationKey: string read GetTranslationKey write SetTranslationKey;
  end;
  
  TI18nButtonHelper = class helper for TI18nButton
    function GetTranslationKey: string;
    procedure SetTranslationKey(const Value: string);
    property TranslationKey: string read GetTranslationKey write SetTranslationKey;
  end;
  
  /// <summary>
  /// 国际化控件测试窗�?
  /// </summary>
  TI18nControlsTestForm = class(TForm)
  public
    lblI18n: TI18nLabel;
    btnI18n: TI18nButton;
    cboLanguage: TComboBox;
    lblCurrentLang: TLabel;
    
    constructor Create(AOwner: TComponent); override;
  end;
  
  /// <summary>
  /// 数据录入测试窗体
  /// </summary>
  TDataEntryTestForm = class(TForm)
  public
    lblName: TLabel;
    edtName: TEdit;
    lblEmail: TLabel;
    edtEmail: TEdit;
    lblPhone: TLabel;
    edtPhone: TEdit;
    lblNotes: TLabel;
    mmoNotes: TMemo;
    chkActive: TCheckBox;
    cboCategory: TComboBox;
    btnSubmit: TButton;
    btnClear: TButton;
    pnlButtons: TPanel;
    
    constructor Create(AOwner: TComponent); override;
    procedure ClearForm;
    function ValidateForm: Boolean;
  end;

implementation

{ TTestFormConfig }

class function TTestFormConfig.Default: TTestFormConfig;
begin
  Result.Width := 400;
  Result.Height := 300;
  Result.Caption := 'Test Form';
  Result.Position := poDesigned;
  Result.FormLeft := 100;
  Result.FormTop := 300;
  Result.InitializeDeepBase := True;
  Result.DBPath := '';
end;

{ TTestFormFactory }

class constructor TTestFormFactory.Create;
begin
  FCreatedForms := TList.Create;
end;

class destructor TTestFormFactory.Destroy;
begin
  DestroyAllForms;
  FCreatedForms.Free;
end;

class function TTestFormFactory.CreateForm(FormType: TTestFormType;
  Config: TTestFormConfig): TForm;
begin
  // 确保 DeepBase 初始�?
  if Config.InitializeDeepBase then
    EnsureDeepBaseInitialized(Config.DBPath);
  
  case FormType of
    tftEmpty:
      Result := CreateEmptyForm(Config.Caption, Config.Width, Config.Height);
    tftBasicControls:
      Result := CreateBasicControlsForm;
    tftConfigControls:
      Result := CreateConfigTestForm;
    tftI18nControls:
      Result := CreateI18nTestForm;
    tftDataEntry:
      Result := CreateDataEntryForm;
    tftMasterDetail:
      begin
        Result := CreateEmptyForm('Master-Detail Test', 600, 400);
        AddMasterDetailControls(Result);
      end;
    tftDialog:
      begin
        Result := CreateEmptyForm('Dialog Test', 350, 200);
        AddDialogControls(Result);
      end;
  else
    Result := CreateEmptyForm;
  end;
  
  if Assigned(Result) then
  begin
    Result.Position := Config.Position;
    if Result.Position = poDesigned then
    begin
      Result.Left := Config.FormLeft;
      Result.Top := Config.FormTop;
    end;
    FCreatedForms.Add(Result);
  end;
end;

class function TTestFormFactory.CreateForm(FormType: TTestFormType): TForm;
begin
  Result := CreateForm(FormType, TTestFormConfig.Default);
end;

class function TTestFormFactory.CreateEmptyForm(const Caption: string;
  Width, Height: Integer): TForm;
begin
  Result := TForm.CreateNew(nil);
  Result.Caption := Caption;
  Result.Width := Width;
  Result.Height := Height;
  Result.Position := poDesigned;
  Result.Left := 100;
  Result.Top := 300;
  FCreatedForms.Add(Result);
end;

class function TTestFormFactory.CreateBasicControlsForm: TForm;
begin
  Result := TBasicControlsTestForm.Create(nil);
  FCreatedForms.Add(Result);
end;

class function TTestFormFactory.CreateConfigTestForm: TForm;
begin
  EnsureDeepBaseInitialized;
  Result := TConfigControlsTestForm.Create(nil);
  FCreatedForms.Add(Result);
end;

class function TTestFormFactory.CreateI18nTestForm: TForm;
begin
  EnsureDeepBaseInitialized;
  Result := TI18nControlsTestForm.Create(nil);
  FCreatedForms.Add(Result);
end;

class function TTestFormFactory.CreateDataEntryForm: TForm;
begin
  Result := TDataEntryTestForm.Create(nil);
  FCreatedForms.Add(Result);
end;

class procedure TTestFormFactory.AddBasicControls(AForm: TForm);
var
  btn: TButton;
  edt: TEdit;
  lbl: TLabel;
  chk: TCheckBox;
begin
  lbl := TLabel.Create(AForm);
  lbl.Parent := AForm;
  lbl.Name := 'lblLabel';
  lbl.Caption := 'Test Label:';
  lbl.Left := 20;
  lbl.Top := 20;
  
  edt := TEdit.Create(AForm);
  edt.Parent := AForm;
  edt.Name := 'edtInput';
  edt.Left := 20;
  edt.Top := 40;
  edt.Width := 200;
  
  chk := TCheckBox.Create(AForm);
  chk.Parent := AForm;
  chk.Name := 'chkOption';
  chk.Caption := 'Enable Option';
  chk.Left := 20;
  chk.Top := 70;
  
  btn := TButton.Create(AForm);
  btn.Parent := AForm;
  btn.Name := 'btnOK';
  btn.Caption := 'OK';
  btn.Left := 20;
  btn.Top := 100;
  btn.Width := 80;
  
  btn := TButton.Create(AForm);
  btn.Parent := AForm;
  btn.Name := 'btnCancel';
  btn.Caption := 'Cancel';
  btn.Left := 110;
  btn.Top := 100;
  btn.Width := 80;
end;

class procedure TTestFormFactory.AddConfigControls(AForm: TForm);
var
  edt: TConfigEdit;
  chk: TConfigCheckBox;
  spn: TConfigSpinEdit;
  lbl: TLabel;
begin
  lbl := TLabel.Create(AForm);
  lbl.Parent := AForm;
  lbl.Caption := 'Config Edit (app.setting):';
  lbl.Left := 20;
  lbl.Top := 20;
  
  edt := TConfigEdit.Create(AForm);
  edt.Parent := AForm;
  edt.Name := 'edtConfig';
  edt.ConfigKey := 'app.setting';
  edt.Left := 20;
  edt.Top := 40;
  edt.Width := 200;
  
  lbl := TLabel.Create(AForm);
  lbl.Parent := AForm;
  lbl.Caption := 'Config CheckBox:';
  lbl.Left := 20;
  lbl.Top := 70;
  
  chk := TConfigCheckBox.Create(AForm);
  chk.Parent := AForm;
  chk.Name := 'chkConfig';
  chk.ConfigKey := 'app.enabled';
  chk.Caption := 'Enabled';
  chk.Left := 20;
  chk.Top := 90;
  
  lbl := TLabel.Create(AForm);
  lbl.Parent := AForm;
  lbl.Caption := 'Config SpinEdit:';
  lbl.Left := 20;
  lbl.Top := 120;
  
  spn := TConfigSpinEdit.Create(AForm);
  spn.Parent := AForm;
  spn.Name := 'spnConfig';
  spn.ConfigKey := 'app.count';
  spn.Left := 20;
  spn.Top := 140;
  spn.Width := 100;
end;

class procedure TTestFormFactory.AddI18nControls(AForm: TForm);
var
  lbl: TI18nLabel;
  btn: TI18nButton;
  cbo: TComboBox;
  lblInfo: TLabel;
begin
  lbl := TI18nLabel.Create(AForm);
  lbl.Parent := AForm;
  lbl.Name := 'lblI18n';
  lbl.TextKey := 'app.welcome';
  lbl.Caption := 'Welcome';
  lbl.Left := 20;
  lbl.Top := 20;
  
  btn := TI18nButton.Create(AForm);
  btn.Parent := AForm;
  btn.Name := 'btnI18n';
  btn.TextKey := 'button.ok';
  btn.Caption := 'OK';
  btn.Left := 20;
  btn.Top := 50;
  btn.Width := 100;
  
  lblInfo := TLabel.Create(AForm);
  lblInfo.Parent := AForm;
  lblInfo.Caption := 'Language:';
  lblInfo.Left := 20;
  lblInfo.Top := 90;
  
  cbo := TComboBox.Create(AForm);
  cbo.Parent := AForm;
  cbo.Name := 'cboLanguage';
  cbo.Style := csDropDownList;
  cbo.Left := 80;
  cbo.Top := 87;
  cbo.Width := 120;
  cbo.Items.Add('en');
  cbo.Items.Add('zh-CN');
  cbo.Items.Add('ja');
  cbo.ItemIndex := 0;
end;

class procedure TTestFormFactory.AddDataEntryControls(AForm: TForm);
var
  lbl: TLabel;
  edt: TEdit;
  mmo: TMemo;
  btn: TButton;
  Y: Integer;
begin
  Y := 20;
  
  // Name
  lbl := TLabel.Create(AForm);
  lbl.Parent := AForm;
  lbl.Caption := 'Name:';
  lbl.Left := 20;
  lbl.Top := Y;
  
  edt := TEdit.Create(AForm);
  edt.Parent := AForm;
  edt.Name := 'edtName';
  edt.Left := 100;
  edt.Top := Y - 3;
  edt.Width := 200;
  Inc(Y, 30);
  
  // Email
  lbl := TLabel.Create(AForm);
  lbl.Parent := AForm;
  lbl.Caption := 'Email:';
  lbl.Left := 20;
  lbl.Top := Y;
  
  edt := TEdit.Create(AForm);
  edt.Parent := AForm;
  edt.Name := 'edtEmail';
  edt.Left := 100;
  edt.Top := Y - 3;
  edt.Width := 200;
  Inc(Y, 30);
  
  // Notes
  lbl := TLabel.Create(AForm);
  lbl.Parent := AForm;
  lbl.Caption := 'Notes:';
  lbl.Left := 20;
  lbl.Top := Y;
  
  mmo := TMemo.Create(AForm);
  mmo.Parent := AForm;
  mmo.Name := 'mmoNotes';
  mmo.Left := 100;
  mmo.Top := Y - 3;
  mmo.Width := 200;
  mmo.Height := 80;
  Inc(Y, 90);
  
  // Buttons
  btn := TButton.Create(AForm);
  btn.Parent := AForm;
  btn.Name := 'btnSubmit';
  btn.Caption := 'Submit';
  btn.Left := 100;
  btn.Top := Y;
  btn.Width := 80;
  
  btn := TButton.Create(AForm);
  btn.Parent := AForm;
  btn.Name := 'btnClear';
  btn.Caption := 'Clear';
  btn.Left := 190;
  btn.Top := Y;
  btn.Width := 80;
end;

class procedure TTestFormFactory.AddMasterDetailControls(AForm: TForm);
var
  pnl: TPanel;
  lv: TListView;
  col: TListColumn;
  lbl: TLabel;
  edt: TEdit;
begin
  // Master panel
  pnl := TPanel.Create(AForm);
  pnl.Parent := AForm;
  pnl.Name := 'pnlMaster';
  pnl.Align := alLeft;
  pnl.Width := 200;
  pnl.Caption := '';
  
  lv := TListView.Create(AForm);
  lv.Parent := pnl;
  lv.Name := 'lvMaster';
  lv.Align := alClient;
  lv.ViewStyle := vsReport;
  
  col := lv.Columns.Add;
  col.Caption := 'ID';
  col.Width := 50;
  
  col := lv.Columns.Add;
  col.Caption := 'Name';
  col.Width := 120;
  
  // Detail panel
  pnl := TPanel.Create(AForm);
  pnl.Parent := AForm;
  pnl.Name := 'pnlDetail';
  pnl.Align := alClient;
  pnl.Caption := '';
  
  lbl := TLabel.Create(AForm);
  lbl.Parent := pnl;
  lbl.Caption := 'Detail View';
  lbl.Left := 20;
  lbl.Top := 20;
  
  edt := TEdit.Create(AForm);
  edt.Parent := pnl;
  edt.Name := 'edtDetail';
  edt.Left := 20;
  edt.Top := 45;
  edt.Width := 200;
end;

class procedure TTestFormFactory.AddDialogControls(AForm: TForm);
var
  lbl: TLabel;
  pnl: TPanel;
  btn: TButton;
begin
  AForm.BorderStyle := bsDialog;
  
  lbl := TLabel.Create(AForm);
  lbl.Parent := AForm;
  lbl.Name := 'lblMessage';
  lbl.Caption := 'Dialog Message';
  lbl.Left := 20;
  lbl.Top := 30;
  lbl.AutoSize := False;
  lbl.Width := AForm.ClientWidth - 40;
  lbl.WordWrap := True;
  
  pnl := TPanel.Create(AForm);
  pnl.Parent := AForm;
  pnl.Name := 'pnlButtons';
  pnl.Align := alBottom;
  pnl.Height := 45;
  pnl.BevelOuter := bvNone;
  
  btn := TButton.Create(AForm);
  btn.Parent := pnl;
  btn.Name := 'btnOK';
  btn.Caption := 'OK';
  btn.ModalResult := mrOK;
  btn.Default := True;
  btn.Left := pnl.Width - 180;
  btn.Top := 10;
  btn.Width := 80;
  
  btn := TButton.Create(AForm);
  btn.Parent := pnl;
  btn.Name := 'btnCancel';
  btn.Caption := 'Cancel';
  btn.ModalResult := mrCancel;
  btn.Cancel := True;
  btn.Left := pnl.Width - 90;
  btn.Top := 10;
  btn.Width := 80;
end;

class procedure TTestFormFactory.DestroyAllForms;
var
  I: Integer;
  Frm: TForm;
begin
  for I := FCreatedForms.Count - 1 downto 0 do
  begin
    Frm := TForm(FCreatedForms[I]);
    if Assigned(Frm) then
    begin
      Frm.Close;
      Frm.Free;
    end;
  end;
  FCreatedForms.Clear;
end;

class procedure TTestFormFactory.EnsureDeepBaseInitialized(const DBPath: string);
var
  ActualPath: string;
begin
  if DeepBase.Manager.DeepBase.IsInitialized then
    Exit;
    
  if DBPath <> '' then
    ActualPath := DBPath
  else
    ActualPath := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'test_gui.db');
    
  DeepBase.Manager.DeepBase.InitializeWithDB(ActualPath);
end;

{ TBasicControlsTestForm }

constructor TBasicControlsTestForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  
  Caption := 'Basic Controls Test';
  Width := 450;
  Height := 400;
  Position := poDesigned;
  Left := 100;
  Top := 300;
  
  // Container panel
  pnlContainer := TPanel.Create(Self);
  pnlContainer.Parent := Self;
  pnlContainer.Name := 'pnlContainer';
  pnlContainer.Align := alClient;
  pnlContainer.BevelOuter := bvNone;
  pnlContainer.Caption := '';
  
  // Label
  lblLabel := TLabel.Create(Self);
  lblLabel.Parent := pnlContainer;
  lblLabel.Name := 'lblLabel';
  lblLabel.Caption := 'Enter Text:';
  lblLabel.Left := 20;
  lblLabel.Top := 20;
  
  // Edit
  edtInput := TEdit.Create(Self);
  edtInput.Parent := pnlContainer;
  edtInput.Name := 'edtInput';
  edtInput.Left := 20;
  edtInput.Top := 40;
  edtInput.Width := 200;
  
  // CheckBox
  chkOption := TCheckBox.Create(Self);
  chkOption.Parent := pnlContainer;
  chkOption.Name := 'chkOption';
  chkOption.Caption := 'Enable Option';
  chkOption.Left := 20;
  chkOption.Top := 70;
  
  // GroupBox with RadioButtons
  grpOptions := TGroupBox.Create(Self);
  grpOptions.Parent := pnlContainer;
  grpOptions.Name := 'grpOptions';
  grpOptions.Caption := 'Options';
  grpOptions.Left := 20;
  grpOptions.Top := 100;
  grpOptions.Width := 200;
  grpOptions.Height := 70;
  
  rbOption1 := TRadioButton.Create(Self);
  rbOption1.Parent := grpOptions;
  rbOption1.Name := 'rbOption1';
  rbOption1.Caption := 'Option 1';
  rbOption1.Left := 15;
  rbOption1.Top := 20;
  rbOption1.Checked := True;
  
  rbOption2 := TRadioButton.Create(Self);
  rbOption2.Parent := grpOptions;
  rbOption2.Name := 'rbOption2';
  rbOption2.Caption := 'Option 2';
  rbOption2.Left := 15;
  rbOption2.Top := 42;
  
  // ComboBox
  cboSelect := TComboBox.Create(Self);
  cboSelect.Parent := pnlContainer;
  cboSelect.Name := 'cboSelect';
  cboSelect.Style := csDropDownList;
  cboSelect.Left := 240;
  cboSelect.Top := 40;
  cboSelect.Width := 150;
  cboSelect.Items.Add('Item 1');
  cboSelect.Items.Add('Item 2');
  cboSelect.Items.Add('Item 3');
  cboSelect.ItemIndex := 0;
  
  // ListBox
  lbxList := TListBox.Create(Self);
  lbxList.Parent := pnlContainer;
  lbxList.Name := 'lbxList';
  lbxList.Left := 240;
  lbxList.Top := 70;
  lbxList.Width := 150;
  lbxList.Height := 100;
  lbxList.Items.Add('List Item 1');
  lbxList.Items.Add('List Item 2');
  lbxList.Items.Add('List Item 3');
  
  // Memo
  mmoText := TMemo.Create(Self);
  mmoText.Parent := pnlContainer;
  mmoText.Name := 'mmoText';
  mmoText.Left := 20;
  mmoText.Top := 180;
  mmoText.Width := 200;
  mmoText.Height := 80;
  mmoText.Lines.Add('Sample text');
  
  // TrackBar
  trkSlider := TTrackBar.Create(Self);
  trkSlider.Parent := pnlContainer;
  trkSlider.Name := 'trkSlider';
  trkSlider.Left := 240;
  trkSlider.Top := 180;
  trkSlider.Width := 150;
  trkSlider.Min := 0;
  trkSlider.Max := 100;
  trkSlider.Position := 50;
  
  // ProgressBar
  prgProgress := TProgressBar.Create(Self);
  prgProgress.Parent := pnlContainer;
  prgProgress.Name := 'prgProgress';
  prgProgress.Left := 240;
  prgProgress.Top := 220;
  prgProgress.Width := 150;
  prgProgress.Min := 0;
  prgProgress.Max := 100;
  prgProgress.Position := 75;
  
  // Buttons
  btnOK := TButton.Create(Self);
  btnOK.Parent := pnlContainer;
  btnOK.Name := 'btnOK';
  btnOK.Caption := 'OK';
  btnOK.Left := 20;
  btnOK.Top := 280;
  btnOK.Width := 80;
  btnOK.Default := True;
  
  btnCancel := TButton.Create(Self);
  btnCancel.Parent := pnlContainer;
  btnCancel.Name := 'btnCancel';
  btnCancel.Caption := 'Cancel';
  btnCancel.Left := 110;
  btnCancel.Top := 280;
  btnCancel.Width := 80;
  btnCancel.Cancel := True;
end;

{ TConfigControlsTestForm }

constructor TConfigControlsTestForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  
  Caption := 'Config Controls Test';
  Width := 400;
  Height := 250;
  Position := poDesigned;
  Left := 100;
  Top := 300;
  
  // Config Edit
  lblStatus := TLabel.Create(Self);
  lblStatus.Parent := Self;
  lblStatus.Caption := 'Config Edit (test.value):';
  lblStatus.Left := 20;
  lblStatus.Top := 20;
  
  edtConfig := TConfigEdit.Create(Self);
  edtConfig.Parent := Self;
  edtConfig.Name := 'edtConfig';
  edtConfig.ConfigKey := 'test.value';
  edtConfig.Left := 20;
  edtConfig.Top := 40;
  edtConfig.Width := 200;
  
  // Config CheckBox
  chkConfig := TConfigCheckBox.Create(Self);
  chkConfig.Parent := Self;
  chkConfig.Name := 'chkConfig';
  chkConfig.ConfigKey := 'test.enabled';
  chkConfig.Caption := 'Enable Feature';
  chkConfig.Left := 20;
  chkConfig.Top := 75;
  
  // Config SpinEdit
  spnConfig := TConfigSpinEdit.Create(Self);
  spnConfig.Parent := Self;
  spnConfig.Name := 'spnConfig';
  spnConfig.ConfigKey := 'test.count';
  spnConfig.Left := 20;
  spnConfig.Top := 105;
  spnConfig.Width := 100;
  
  // Buttons
  btnSave := TButton.Create(Self);
  btnSave.Parent := Self;
  btnSave.Name := 'btnSave';
  btnSave.Caption := 'Save';
  btnSave.Left := 20;
  btnSave.Top := 150;
  btnSave.Width := 80;
  
  btnReset := TButton.Create(Self);
  btnReset.Parent := Self;
  btnReset.Name := 'btnReset';
  btnReset.Caption := 'Reset';
  btnReset.Left := 110;
  btnReset.Top := 150;
  btnReset.Width := 80;
  
  lblStatus := TLabel.Create(Self);
  lblStatus.Parent := Self;
  lblStatus.Name := 'lblStatus';
  lblStatus.Caption := 'Status: Ready';
  lblStatus.Left := 20;
  lblStatus.Top := 190;
end;

{ TI18nControlsTestForm }

constructor TI18nControlsTestForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  
  Caption := 'I18n Controls Test';
  Width := 350;
  Height := 200;
  Position := poDesigned;
  Left := 100;
  Top := 300;
  
  // I18n Label
  lblI18n := TI18nLabel.Create(Self);
  lblI18n.Parent := Self;
  lblI18n.Name := 'lblI18n';
  lblI18n.TextKey := 'app.greeting';
  lblI18n.Caption := 'Hello, World!';
  lblI18n.Left := 20;
  lblI18n.Top := 20;
  
  // I18n Button
  btnI18n := TI18nButton.Create(Self);
  btnI18n.Parent := Self;
  btnI18n.Name := 'btnI18n';
  btnI18n.TextKey := 'button.submit';
  btnI18n.Caption := 'Submit';
  btnI18n.Left := 20;
  btnI18n.Top := 50;
  btnI18n.Width := 100;
  
  // Language selector
  lblCurrentLang := TLabel.Create(Self);
  lblCurrentLang.Parent := Self;
  lblCurrentLang.Name := 'lblCurrentLang';
  lblCurrentLang.Caption := 'Language:';
  lblCurrentLang.Left := 20;
  lblCurrentLang.Top := 100;
  
  cboLanguage := TComboBox.Create(Self);
  cboLanguage.Parent := Self;
  cboLanguage.Name := 'cboLanguage';
  cboLanguage.Style := csDropDownList;
  cboLanguage.Left := 90;
  cboLanguage.Top := 97;
  cboLanguage.Width := 120;
  cboLanguage.Items.Add('en');
  cboLanguage.Items.Add('zh-CN');
  cboLanguage.Items.Add('ja');
  cboLanguage.Items.Add('de');
  cboLanguage.ItemIndex := 0;
end;

{ TDataEntryTestForm }

constructor TDataEntryTestForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  
  Caption := 'Data Entry Test';
  Width := 400;
  Height := 350;
  Position := poDesigned;
  Left := 100;
  Top := 300;
  
  // Name field
  lblName := TLabel.Create(Self);
  lblName.Parent := Self;
  lblName.Name := 'lblName';
  lblName.Caption := 'Name:';
  lblName.Left := 20;
  lblName.Top := 23;
  
  edtName := TEdit.Create(Self);
  edtName.Parent := Self;
  edtName.Name := 'edtName';
  edtName.Left := 100;
  edtName.Top := 20;
  edtName.Width := 200;
  
  // Email field
  lblEmail := TLabel.Create(Self);
  lblEmail.Parent := Self;
  lblEmail.Name := 'lblEmail';
  lblEmail.Caption := 'Email:';
  lblEmail.Left := 20;
  lblEmail.Top := 53;
  
  edtEmail := TEdit.Create(Self);
  edtEmail.Parent := Self;
  edtEmail.Name := 'edtEmail';
  edtEmail.Left := 100;
  edtEmail.Top := 50;
  edtEmail.Width := 200;
  
  // Phone field
  lblPhone := TLabel.Create(Self);
  lblPhone.Parent := Self;
  lblPhone.Name := 'lblPhone';
  lblPhone.Caption := 'Phone:';
  lblPhone.Left := 20;
  lblPhone.Top := 83;
  
  edtPhone := TEdit.Create(Self);
  edtPhone.Parent := Self;
  edtPhone.Name := 'edtPhone';
  edtPhone.Left := 100;
  edtPhone.Top := 80;
  edtPhone.Width := 200;
  
  // Category
  cboCategory := TComboBox.Create(Self);
  cboCategory.Parent := Self;
  cboCategory.Name := 'cboCategory';
  cboCategory.Style := csDropDownList;
  cboCategory.Left := 100;
  cboCategory.Top := 110;
  cboCategory.Width := 200;
  cboCategory.Items.Add('Personal');
  cboCategory.Items.Add('Business');
  cboCategory.Items.Add('Other');
  cboCategory.ItemIndex := 0;
  
  // Active checkbox
  chkActive := TCheckBox.Create(Self);
  chkActive.Parent := Self;
  chkActive.Name := 'chkActive';
  chkActive.Caption := 'Active';
  chkActive.Left := 100;
  chkActive.Top := 145;
  chkActive.Checked := True;
  
  // Notes
  lblNotes := TLabel.Create(Self);
  lblNotes.Parent := Self;
  lblNotes.Name := 'lblNotes';
  lblNotes.Caption := 'Notes:';
  lblNotes.Left := 20;
  lblNotes.Top := 175;
  
  mmoNotes := TMemo.Create(Self);
  mmoNotes.Parent := Self;
  mmoNotes.Name := 'mmoNotes';
  mmoNotes.Left := 100;
  mmoNotes.Top := 172;
  mmoNotes.Width := 200;
  mmoNotes.Height := 80;
  
  // Button panel
  pnlButtons := TPanel.Create(Self);
  pnlButtons.Parent := Self;
  pnlButtons.Name := 'pnlButtons';
  pnlButtons.Align := alBottom;
  pnlButtons.Height := 45;
  pnlButtons.BevelOuter := bvNone;
  pnlButtons.Caption := '';
  
  btnSubmit := TButton.Create(Self);
  btnSubmit.Parent := pnlButtons;
  btnSubmit.Name := 'btnSubmit';
  btnSubmit.Caption := 'Submit';
  btnSubmit.Left := 100;
  btnSubmit.Top := 10;
  btnSubmit.Width := 80;
  
  btnClear := TButton.Create(Self);
  btnClear.Parent := pnlButtons;
  btnClear.Name := 'btnClear';
  btnClear.Caption := 'Clear';
  btnClear.Left := 190;
  btnClear.Top := 10;
  btnClear.Width := 80;
end;

procedure TDataEntryTestForm.ClearForm;
begin
  edtName.Text := '';
  edtEmail.Text := '';
  edtPhone.Text := '';
  mmoNotes.Clear;
  cboCategory.ItemIndex := 0;
  chkActive.Checked := True;
end;

function TDataEntryTestForm.ValidateForm: Boolean;
begin
  Result := (edtName.Text <> '') and (edtEmail.Text <> '');
end;

{ TI18nLabelHelper }

function TI18nLabelHelper.GetTranslationKey: string;
begin
  Result := TextKey;
end;

procedure TI18nLabelHelper.SetTranslationKey(const Value: string);
begin
  TextKey := Value;
end;

{ TI18nButtonHelper }

function TI18nButtonHelper.GetTranslationKey: string;
begin
  Result := TextKey;
end;

procedure TI18nButtonHelper.SetTranslationKey(const Value: string);
begin
  TextKey := Value;
end;

end.
