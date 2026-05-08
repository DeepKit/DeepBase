{ ============================================================================
  DeepBase.VCL.ComboBoxes - 专用下拉框控件
  
  版本: 0.3
  说明: 自动填充内容的 ComboBox，如语言选择、主题选择
  ============================================================================ }

unit DeepBase.VCL.ComboBoxes;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.StdCtrls,
  Vcl.Controls,
  DeepBase.Manager,
  DeepBase.i18n,
  DeepBase.Theme,
  DeepBase.Types;

type
  /// <summary>
  /// 语言选择下拉框
  /// </summary>
  TLanguageComboBox = class(TComboBox)
  private
    FAutoUpdate: Boolean;
    procedure OnLanguageChanged(Sender: TObject);
  protected
    procedure Loaded; override;
    procedure Select; override;
    procedure Populate; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property AutoUpdate: Boolean read FAutoUpdate write FAutoUpdate default True;
  end;

  /// <summary>
  /// 主题选择下拉框
  /// </summary>
  TThemeComboBox = class(TComboBox)
  private
    FAutoUpdate: Boolean;
    procedure OnThemeChanged(Sender: TObject);
  protected
    procedure Loaded; override;
    procedure Select; override;
    procedure Populate; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property AutoUpdate: Boolean read FAutoUpdate write FAutoUpdate default True;
  end;

implementation

{ TLanguageComboBox }

constructor TLanguageComboBox.Create(AOwner: TComponent);
begin
  inherited;
  FAutoUpdate := True;
  Style := csDropDownList;
end;

destructor TLanguageComboBox.Destroy;
begin
  inherited;
end;

procedure TLanguageComboBox.Loaded;
begin
  inherited;
  if not (csDesigning in ComponentState) then
    Populate;
end;

procedure TLanguageComboBox.Populate;
var
  Langs: TLanguageInfoArray;
  Lang: TLanguageInfo;
begin
  Items.Clear;
  if not DeepBase.Manager.DeepBase.IsInitialized then Exit;
  
  Langs := DeepBase.Manager.DeepBase.I18n.GetAvailableLanguages;
  for Lang in Langs do
  begin
    // Store LangCode in Object? Or just use Name=Code format
    Items.Add(Lang.LangName + '=' + Lang.LangCode);
    
    // Auto Select current
    if Lang.LangCode = DeepBase.Manager.DeepBase.CurrentLanguage then
      ItemIndex := Items.Count - 1;
  end;
end;

procedure TLanguageComboBox.Select;
var
  Val: string;
begin
  inherited;
  if not FAutoUpdate then Exit;
  if ItemIndex < 0 then Exit;
  
  Val := Items.ValueFromIndex[ItemIndex];
  if Val = '' then Val := Items[ItemIndex];
  
  DeepBase.Manager.DeepBase.CurrentLanguage := Val;
end;

procedure TLanguageComboBox.OnLanguageChanged(Sender: TObject);
begin
  // Sync selection with current language
end;

{ TThemeComboBox }

constructor TThemeComboBox.Create(AOwner: TComponent);
begin
  inherited;
  FAutoUpdate := True;
  Style := csDropDownList;
end;

destructor TThemeComboBox.Destroy;
begin
  inherited;
end;

procedure TThemeComboBox.Loaded;
begin
  inherited;
  if not (csDesigning in ComponentState) then
    Populate;
end;

procedure TThemeComboBox.Populate;
var
  Themes: TThemeInfoArray;
  Theme: TThemeInfo;
begin
  Items.Clear;
  if not DeepBase.Manager.DeepBase.IsInitialized then Exit;
  
  Themes := DeepBase.Manager.DeepBase.Theme.GetAvailableThemes;
  for Theme in Themes do
  begin
    Items.Add(Theme.Name);
    if Theme.Name = DeepBase.Manager.DeepBase.CurrentTheme then
      ItemIndex := Items.Count - 1;
  end;
end;

procedure TThemeComboBox.Select;
begin
  inherited;
  if not FAutoUpdate then Exit;
  if ItemIndex < 0 then Exit;
  
  DeepBase.Manager.DeepBase.CurrentTheme := Items[ItemIndex];
end;

procedure TThemeComboBox.OnThemeChanged(Sender: TObject);
begin
  // Sync selection
end;

end.
