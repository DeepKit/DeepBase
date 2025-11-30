{ ============================================================================
  MultiLanguageDemo - Main Form
  
  Demonstrates UniBase i18n features:
  - T() translation function
  - TFmt() formatted translation
  - TN() plural forms
  - Language switching
  - I18n-aware controls (TI18nLabel, TI18nButton)
  - Auto-subscribe to language changes
  ============================================================================ }

unit MainForm;

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Dialogs,
  UniBase.Manager, UniBase.Types, UniBase.i18n, UniBase.VCL.I18nControls;

type
  TfrmMain = class(TForm)
    PanelTop: TPanel;
    LabelTitle: TLabel;
    ComboLanguage: TComboBox;
    LabelLanguage: TLabel;
    PageControl1: TPageControl;
    TabBasic: TTabSheet;
    TabFormatted: TTabSheet;
    TabPlural: TTabSheet;
    TabControls: TTabSheet;
    
    // Basic tab
    LabelWelcome: TLabel;
    LabelTranslateDemo: TLabel;
    EditInput: TEdit;
    ButtonTranslate: TButton;
    LabelResult: TLabel;
    MemoLog: TMemo;
    
    // Formatted tab
    LabelFmtDemo: TLabel;
    EditName: TEdit;
    LabelName: TLabel;
    EditAge: TEdit;
    LabelAge: TLabel;
    ButtonFormat: TButton;
    LabelFmtResult: TLabel;
    
    // Plural tab
    LabelPluralDemo: TLabel;
    EditCount: TEdit;
    LabelCount: TLabel;
    ButtonPlural: TButton;
    LabelPluralResult: TLabel;
    
    // I18n Controls tab
    GroupI18nControls: TGroupBox;
    I18nLabel1: TI18nLabel;
    I18nLabel2: TI18nLabel;
    I18nButton1: TI18nButton;
    I18nButton2: TI18nButton;
    LabelControlsNote: TLabel;
    
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ComboLanguageChange(Sender: TObject);
    procedure ButtonTranslateClick(Sender: TObject);
    procedure ButtonFormatClick(Sender: TObject);
    procedure ButtonPluralClick(Sender: TObject);
    procedure I18nButton1Click(Sender: TObject);
    procedure I18nButton2Click(Sender: TObject);
    
  private
    procedure LoadLanguages;
    procedure UpdateUI;
    procedure Log(const Msg: string);
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.FormCreate(Sender: TObject);
var
  UB: TUniBaseManager;
begin
  UB := UniBase.Manager.UniBase;
  
  // Initialize UniBase with memory database for demo
  if not UB.IsInitialized then
    UB.InitializeWithDB(':memory:');
  
  // Setup demo translations
  if Assigned(UB.I18n) then
  begin
    // English translations (source text is English, so these are mostly identity)
    UB.I18n.AddTranslation('Welcome', 'en-US', 'Welcome');
    UB.I18n.AddTranslation('Hello', 'en-US', 'Hello');
    UB.I18n.AddTranslation('Save', 'en-US', 'Save');
    UB.I18n.AddTranslation('Cancel', 'en-US', 'Cancel');
    UB.I18n.AddTranslation('Open File', 'en-US', 'Open File');
    UB.I18n.AddTranslation('Settings', 'en-US', 'Settings');
    UB.I18n.AddTranslation('Hello, %s! You are %d years old.', 'en-US', 'Hello, %s! You are %d years old.');
    UB.I18n.AddTranslation('%d item', 'en-US', '%d item');
    UB.I18n.AddTranslation('%d items', 'en-US', '%d items');
    
    // Chinese translations
    UB.I18n.AddTranslation('Welcome', 'zh-CN', '欢迎');
    UB.I18n.AddTranslation('Hello', 'zh-CN', '你好');
    UB.I18n.AddTranslation('Save', 'zh-CN', '保存');
    UB.I18n.AddTranslation('Cancel', 'zh-CN', '取消');
    UB.I18n.AddTranslation('Open File', 'zh-CN', '打开文件');
    UB.I18n.AddTranslation('Settings', 'zh-CN', '设置');
    UB.I18n.AddTranslation('Hello, %s! You are %d years old.', 'zh-CN', '你好，%s！你今年 %d 岁。');
    UB.I18n.AddTranslation('%d item', 'zh-CN', '%d 个项目');
    UB.I18n.AddTranslation('%d items', 'zh-CN', '%d 个项目');
    
    // Japanese translations
    UB.I18n.AddTranslation('Welcome', 'ja-JP', 'ようこそ');
    UB.I18n.AddTranslation('Hello', 'ja-JP', 'こんにちは');
    UB.I18n.AddTranslation('Save', 'ja-JP', '保存');
    UB.I18n.AddTranslation('Cancel', 'ja-JP', 'キャンセル');
    UB.I18n.AddTranslation('Open File', 'ja-JP', 'ファイルを開く');
    UB.I18n.AddTranslation('Settings', 'ja-JP', '設定');
    UB.I18n.AddTranslation('Hello, %s! You are %d years old.', 'ja-JP', 'こんにちは、%sさん！あなたは%d歳です。');
    UB.I18n.AddTranslation('%d item', 'ja-JP', '%d アイテム');
    UB.I18n.AddTranslation('%d items', 'ja-JP', '%d アイテム');
  end;
  
  LoadLanguages;
  UpdateUI;
  
  Log('UniBase MultiLanguage Demo started');
  Log('Current language: ' + UB.I18n.CurrentLanguage);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  // Cleanup handled by UniBase
end;

procedure TfrmMain.LoadLanguages;
var
  Langs: TLanguageInfoArray;
  i: Integer;
  UB: TUniBaseManager;
begin
  UB := UniBase.Manager.UniBase;
  ComboLanguage.Items.Clear;
  
  if Assigned(UB.I18n) then
  begin
    Langs := UB.I18n.GetAvailableLanguages;
    for i := 0 to Length(Langs) - 1 do
    begin
      ComboLanguage.Items.AddObject(
        Format('%s - %s', [Langs[i].LangCode, Langs[i].NativeName]),
        TObject(i)
      );
      
      if Langs[i].LangCode = UB.I18n.CurrentLanguage then
        ComboLanguage.ItemIndex := ComboLanguage.Items.Count - 1;
    end;
  end;
  
  if ComboLanguage.ItemIndex < 0 then
    ComboLanguage.ItemIndex := 0;
end;

procedure TfrmMain.UpdateUI;
begin
  // Update static labels using T()
  Caption := T('Welcome') + ' - MultiLanguage Demo';
  LabelWelcome.Caption := T('Welcome') + '!';
  
  // Note: I18n controls (TI18nLabel, TI18nButton) auto-update on language change
end;

procedure TfrmMain.ComboLanguageChange(Sender: TObject);
var
  SelText, LangCode: string;
  P: Integer;
  UB: TUniBaseManager;
begin
  if ComboLanguage.ItemIndex < 0 then Exit;
  
  UB := UniBase.Manager.UniBase;
  SelText := ComboLanguage.Items[ComboLanguage.ItemIndex];
  P := Pos(' - ', SelText);
  if P > 0 then
    LangCode := Copy(SelText, 1, P - 1)
  else
    LangCode := SelText;
  
  if Assigned(UB.I18n) then
  begin
    UB.I18n.CurrentLanguage := LangCode;
    UpdateUI;
    Log('Language changed to: ' + LangCode);
  end;
end;

procedure TfrmMain.ButtonTranslateClick(Sender: TObject);
var
  Source, Translated: string;
begin
  Source := EditInput.Text;
  if Source = '' then
    Source := 'Hello';
  
  Translated := T(Source);
  LabelResult.Caption := 'Result: ' + Translated;
  
  Log(Format('T("%s") = "%s"', [Source, Translated]));
end;

procedure TfrmMain.ButtonFormatClick(Sender: TObject);
var
  Name: string;
  Age: Integer;
  Result: string;
begin
  Name := EditName.Text;
  if Name = '' then Name := 'World';
  
  if not TryStrToInt(EditAge.Text, Age) then
    Age := 25;
  
  // TFmt: Translate with format arguments
  Result := TFmt('Hello, %s! You are %d years old.', [Name, Age]);
  LabelFmtResult.Caption := Result;
  
  Log(Format('TFmt() = "%s"', [Result]));
end;

procedure TfrmMain.ButtonPluralClick(Sender: TObject);
var
  Count: Integer;
  Result: string;
begin
  if not TryStrToInt(EditCount.Text, Count) then
    Count := 1;
  
  // TN: Plural form translation
  Result := TN('%d item', '%d items', Count);
  LabelPluralResult.Caption := Format(Result, [Count]);
  
  Log(Format('TN(count=%d) = "%s"', [Count, Format(Result, [Count])]));
end;

procedure TfrmMain.I18nButton1Click(Sender: TObject);
begin
  Log('Save button clicked - I18n controls auto-translate!');
  ShowMessage(T('Save') + ' - ' + T('Settings'));
end;

procedure TfrmMain.I18nButton2Click(Sender: TObject);
begin
  Log('Cancel button clicked');
  ShowMessage(T('Cancel'));
end;

procedure TfrmMain.Log(const Msg: string);
begin
  MemoLog.Lines.Add(Format('[%s] %s', [FormatDateTime('hh:nn:ss', Now), Msg]));
end;

end.
