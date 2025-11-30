{ ============================================================================
  Studio.ThemeFrame - Theme Editor Frame
  
  Version: 1.0
  Description: Visual editor for previewing and switching application themes.
               Displays available VCL styles with type indicators and preview.
  ============================================================================ }

unit Studio.ThemeFrame;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.UITypes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Buttons,
  Vcl.CheckLst,
  Vcl.Themes,
  Vcl.Styles,
  FireDAC.Comp.Client,
  UniBase.Types,
  UniBase.Theme;

type
  TfraTheme = class(TFrame)
    pnlToolbar: TPanel;
    lblTitle: TLabel;
    btnApply: TButton;
    splSplitter: TSplitter;
    pnlLeft: TPanel;
    lblThemes: TLabel;
    lvThemes: TListView;
    pnlRight: TPanel;
    pnlPreviewHeader: TPanel;
    lblPreview: TLabel;
    pnlPreviewContent: TPanel;
    grpSampleControls: TGroupBox;
    lblSampleLabel: TLabel;
    edtSampleEdit: TEdit;
    btnSampleButton: TButton;
    chkSampleCheck: TCheckBox;
    cboSampleCombo: TComboBox;
    prgSampleProgress: TProgressBar;
    trkSampleTrack: TTrackBar;
    rdoSample1: TRadioButton;
    rdoSample2: TRadioButton;
    pnlStatus: TPanel;
    lblStatus: TLabel;
    procedure lvThemesSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure lvThemesDblClick(Sender: TObject);
    procedure btnApplyClick(Sender: TObject);
  private
    FConnection: TFDConnection;
    FThemeManager: TUniBaseTheme;
    FAllThemes: TThemeInfoArray;
    FSelectedThemeName: string;
    
    procedure LoadThemes;
    procedure RefreshThemeList;
    procedure UpdatePreview;
    procedure ApplySelectedTheme;
    procedure SetStatus(const AText: string; AIsWarning: Boolean = False);
    function GetSelectedThemeName: string;
    function GetThemeTypeText(const ATheme: TThemeInfo): string;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure SetConnection(AConnection: TFDConnection);
    procedure RefreshData;
  end;

implementation

{$R *.dfm}

{ TfraTheme }

constructor TfraTheme.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSelectedThemeName := '';
  
  // Initialize ListView columns
  lvThemes.ViewStyle := vsReport;
  lvThemes.RowSelect := True;
  lvThemes.ReadOnly := True;
  lvThemes.HideSelection := False;
  
  with lvThemes.Columns.Add do
  begin
    Caption := 'Theme Name';
    Width := 180;
  end;
  with lvThemes.Columns.Add do
  begin
    Caption := 'Type';
    Width := 100;
  end;
  
  // Initialize sample controls
  cboSampleCombo.Items.Add('Option 1');
  cboSampleCombo.Items.Add('Option 2');
  cboSampleCombo.Items.Add('Option 3');
  cboSampleCombo.ItemIndex := 0;
  
  prgSampleProgress.Position := 65;
  trkSampleTrack.Position := 5;
  chkSampleCheck.Checked := True;
  rdoSample1.Checked := True;
end;

destructor TfraTheme.Destroy;
begin
  FThemeManager.Free;
  inherited;
end;

procedure TfraTheme.SetConnection(AConnection: TFDConnection);
begin
  FConnection := AConnection;
  
  // Recreate theme manager with new connection
  FreeAndNil(FThemeManager);
  if Assigned(FConnection) and FConnection.Connected then
    FThemeManager := TUniBaseTheme.Create(FConnection);
end;

procedure TfraTheme.RefreshData;
begin
  LoadThemes;
  RefreshThemeList;
  SetStatus('');
end;

procedure TfraTheme.LoadThemes;
begin
  if Assigned(FThemeManager) then
    FAllThemes := FThemeManager.GetAvailableThemes
  else
  begin
    // Fallback: load directly from TStyleManager if no database connection
    var StyleNames := TStyleManager.StyleNames;
    SetLength(FAllThemes, Length(StyleNames));
    for var I := 0 to High(StyleNames) do
    begin
      FAllThemes[I].Name := StyleNames[I];
      FAllThemes[I].IsBuiltIn := True;
      FAllThemes[I].IsDark := 
        (Pos('Dark', StyleNames[I]) > 0) or 
        (Pos('Black', StyleNames[I]) > 0) or 
        (Pos('Carbon', StyleNames[I]) > 0) or
        (Pos('Slate', StyleNames[I]) > 0);
    end;
  end;
end;

procedure TfraTheme.RefreshThemeList;
var
  I: Integer;
  Item: TListItem;
  CurrentTheme: string;
begin
  lvThemes.Items.BeginUpdate;
  try
    lvThemes.Items.Clear;
    
    CurrentTheme := TStyleManager.ActiveStyle.Name;
    
    for I := 0 to High(FAllThemes) do
    begin
      Item := lvThemes.Items.Add;
      Item.Caption := FAllThemes[I].Name;
      Item.SubItems.Add(GetThemeTypeText(FAllThemes[I]));
      Item.Data := Pointer(I);
      
      // Highlight current theme
      if SameText(FAllThemes[I].Name, CurrentTheme) then
      begin
        Item.Caption := FAllThemes[I].Name + ' (Current)';
        Item.Selected := True;
        FSelectedThemeName := FAllThemes[I].Name;
      end;
    end;
  finally
    lvThemes.Items.EndUpdate;
  end;
  
  UpdatePreview;
end;

function TfraTheme.GetThemeTypeText(const ATheme: TThemeInfo): string;
begin
  Result := '';
  
  if ATheme.IsDark then
    Result := 'Dark'
  else
    Result := 'Light';
    
  if ATheme.IsBuiltIn then
    Result := Result + ', Built-in'
  else
    Result := Result + ', Custom';
end;

function TfraTheme.GetSelectedThemeName: string;
begin
  Result := '';
  if lvThemes.Selected <> nil then
  begin
    var Idx := Integer(lvThemes.Selected.Data);
    if (Idx >= 0) and (Idx < Length(FAllThemes)) then
      Result := FAllThemes[Idx].Name;
  end;
end;

procedure TfraTheme.UpdatePreview;
var
  ThemeName: string;
  I: Integer;
begin
  ThemeName := GetSelectedThemeName;
  if ThemeName = '' then
    ThemeName := TStyleManager.ActiveStyle.Name;
    
  // Find theme info
  for I := 0 to High(FAllThemes) do
  begin
    if SameText(FAllThemes[I].Name, ThemeName) then
    begin
      lblPreview.Caption := Format('Preview: %s', [ThemeName]);
      
      // Update status with theme info
      if FAllThemes[I].IsDark then
        SetStatus(Format('%s - Dark theme', [ThemeName]), False)
      else
        SetStatus(Format('%s - Light theme', [ThemeName]), False);
        
      Break;
    end;
  end;
end;

procedure TfraTheme.ApplySelectedTheme;
var
  ThemeName: string;
begin
  ThemeName := GetSelectedThemeName;
  if ThemeName = '' then
  begin
    SetStatus('No theme selected', True);
    Exit;
  end;
  
  // Don't apply if it's the current theme
  if SameText(ThemeName, TStyleManager.ActiveStyle.Name) then
  begin
    SetStatus(Format('%s is already the active theme', [ThemeName]), False);
    Exit;
  end;
  
  // Apply the theme
  if Assigned(FThemeManager) then
    FThemeManager.ApplyTheme(ThemeName)
  else
    TStyleManager.TrySetStyle(ThemeName);
  
  // Refresh the list to show new current theme
  RefreshThemeList;
  SetStatus(Format('Applied theme: %s', [ThemeName]), False);
end;

procedure TfraTheme.SetStatus(const AText: string; AIsWarning: Boolean);
begin
  lblStatus.Caption := AText;
  if AIsWarning then
    lblStatus.Font.Color := clRed
  else
    lblStatus.Font.Color := clWindowText;
end;

procedure TfraTheme.lvThemesSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
begin
  if Selected then
  begin
    FSelectedThemeName := GetSelectedThemeName;
    UpdatePreview;
  end;
end;

procedure TfraTheme.lvThemesDblClick(Sender: TObject);
begin
  ApplySelectedTheme;
end;

procedure TfraTheme.btnApplyClick(Sender: TObject);
begin
  ApplySelectedTheme;
end;

end.
