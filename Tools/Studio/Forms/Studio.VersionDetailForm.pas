{ ============================================================================
  Studio.VersionDetailForm - Version Detail Popup Window
  
  Version: 1.0
  Description: Large popup window for editing single prompt version
  Features:
    - Full-screen content editor
    - Preview with variables filled
    - Token count estimation
    - Statistics display
    - Set as Production toggle
  ============================================================================ }

unit Studio.VersionDetailForm;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.JSON,
  System.Generics.Collections,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Buttons,
  UniBase.LLM.Manager;

type
  /// <summary>
  /// Version detail popup form
  /// </summary>
  TVersionDetailForm = class(TForm)
  private
    // Header
    FHeaderPanel: TPanel;
    FLblPromptCode: TLabel;
    FLblVersionNum: TLabel;
    FChkProduction: TCheckBox;
    FBtnClose: TSpeedButton;
    
    // Main editor area
    FEditorPanel: TPanel;
    FMemoContent: TMemo;
    FLblContentHint: TLabel;
    
    // Right panel - preview and stats
    FRightPanel: TPanel;
    FSplitter: TSplitter;
    
    // Preview section
    FPreviewPanel: TPanel;
    FLblPreviewTitle: TLabel;
    FMemoPreview: TMemo;
    FBtnRefreshPreview: TSpeedButton;
    
    // Stats section
    FStatsPanel: TPanel;
    FLblStatsTitle: TLabel;
    FStatsGrid: TStringGrid;
    
    // Variable input section
    FVarPanel: TPanel;
    FLblVarTitle: TLabel;
    FVarGrid: TStringGrid;
    
    // Footer
    FFooterPanel: TPanel;
    FLblTokens: TLabel;
    FBtnSave: TButton;
    FBtnCancel: TButton;
    FBtnSend: TButton;
    
    // Data
    FLLMManager: TLLMManager;
    FPrompt: TPrompt;
    FVersion: TPromptVersion;
    FVersionNumber: Integer;
    FVariables: TArray<TPromptVariable>;
    FModified: Boolean;
    FOnSave: TNotifyEvent;
    
    procedure CreateControls;
    procedure SetupLayout;
    procedure LoadVersion;
    procedure UpdatePreview;
    procedure UpdateTokenCount;
    procedure UpdateStats;
    
    procedure BtnSaveClick(Sender: TObject);
    procedure BtnCancelClick(Sender: TObject);
    procedure BtnCloseClick(Sender: TObject);
    procedure BtnSendClick(Sender: TObject);
    procedure BtnRefreshPreviewClick(Sender: TObject);
    procedure ChkProductionClick(Sender: TObject);
    procedure MemoContentChange(Sender: TObject);
    procedure VarGridSetEditText(Sender: TObject; ACol, ARow: Integer; const Value: string);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    
    function GetVariableValues: TDictionary<string, Variant>;
    function EstimateTokens(const Text: string): Integer;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>Initialize with prompt and version number</summary>
    procedure Initialize(ALLMManager: TLLMManager; const APrompt: TPrompt; 
      AVersionNumber: Integer);
    
    /// <summary>Get the edited version</summary>
    function GetVersion: TPromptVersion;
    
    property Modified: Boolean read FModified;
    property OnSave: TNotifyEvent read FOnSave write FOnSave;
  end;

/// <summary>
/// Show version detail popup
/// </summary>
function ShowVersionDetail(AOwner: TComponent; ALLMManager: TLLMManager;
  const APrompt: TPrompt; AVersionNumber: Integer): TModalResult;

implementation

uses
  Winapi.Windows,
  System.StrUtils,
  System.Math;

function ShowVersionDetail(AOwner: TComponent; ALLMManager: TLLMManager;
  const APrompt: TPrompt; AVersionNumber: Integer): TModalResult;
var
  Form: TVersionDetailForm;
begin
  Form := TVersionDetailForm.Create(AOwner);
  try
    Form.Initialize(ALLMManager, APrompt, AVersionNumber);
    Result := Form.ShowModal;
  finally
    Form.Free;
  end;
end;

{ TVersionDetailForm }

constructor TVersionDetailForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Caption := 'Version Detail';
  Width := 1200;
  Height := 800;
  Position := poMainFormCenter;
  BorderStyle := bsSizeable;
  BorderIcons := [biSystemMenu, biMaximize];
  KeyPreview := True;
  OnKeyDown := FormKeyDown;
  
  FModified := False;
  
  CreateControls;
  SetupLayout;
end;

destructor TVersionDetailForm.Destroy;
begin
  inherited;
end;

procedure TVersionDetailForm.CreateControls;
begin
  // === Header Panel ===
  FHeaderPanel := TPanel.Create(Self);
  FHeaderPanel.Parent := Self;
  FHeaderPanel.Align := alTop;
  FHeaderPanel.Height := 50;
  FHeaderPanel.BevelOuter := bvNone;
  FHeaderPanel.Color := $00F5F5F5;
  FHeaderPanel.ParentBackground := False;
  
  FLblPromptCode := TLabel.Create(Self);
  FLblPromptCode.Parent := FHeaderPanel;
  FLblPromptCode.Left := 16;
  FLblPromptCode.Top := 8;
  FLblPromptCode.Font.Size := 12;
  FLblPromptCode.Font.Style := [fsBold];
  FLblPromptCode.Caption := 'Prompt Code';
  
  FLblVersionNum := TLabel.Create(Self);
  FLblVersionNum.Parent := FHeaderPanel;
  FLblVersionNum.Left := 16;
  FLblVersionNum.Top := 28;
  FLblVersionNum.Font.Color := $00757575;
  FLblVersionNum.Caption := 'Version 1';
  
  FChkProduction := TCheckBox.Create(Self);
  FChkProduction.Parent := FHeaderPanel;
  FChkProduction.Left := 300;
  FChkProduction.Top := 16;
  FChkProduction.Caption := 'Production Version';
  FChkProduction.Font.Style := [fsBold];
  FChkProduction.OnClick := ChkProductionClick;
  
  FBtnClose := TSpeedButton.Create(Self);
  FBtnClose.Parent := FHeaderPanel;
  FBtnClose.Width := 30;
  FBtnClose.Height := 30;
  FBtnClose.Flat := True;
  FBtnClose.Caption := '×';
  FBtnClose.Font.Size := 16;
  FBtnClose.OnClick := BtnCloseClick;
  
  // === Footer Panel ===
  FFooterPanel := TPanel.Create(Self);
  FFooterPanel.Parent := Self;
  FFooterPanel.Align := alBottom;
  FFooterPanel.Height := 50;
  FFooterPanel.BevelOuter := bvNone;
  FFooterPanel.Color := $00FAFAFA;
  FFooterPanel.ParentBackground := False;
  
  FLblTokens := TLabel.Create(Self);
  FLblTokens.Parent := FFooterPanel;
  FLblTokens.Left := 16;
  FLblTokens.Top := 16;
  FLblTokens.Caption := 'Estimated: 0 tokens';
  FLblTokens.Font.Color := $00757575;
  
  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := FFooterPanel;
  FBtnCancel.Width := 80;
  FBtnCancel.Height := 30;
  FBtnCancel.Caption := 'Cancel';
  FBtnCancel.ModalResult := mrCancel;
  FBtnCancel.OnClick := BtnCancelClick;
  
  FBtnSave := TButton.Create(Self);
  FBtnSave.Parent := FFooterPanel;
  FBtnSave.Width := 100;
  FBtnSave.Height := 30;
  FBtnSave.Caption := 'Save';
  FBtnSave.OnClick := BtnSaveClick;
  
  FBtnSend := TButton.Create(Self);
  FBtnSend.Parent := FFooterPanel;
  FBtnSend.Width := 100;
  FBtnSend.Height := 30;
  FBtnSend.Caption := 'Send to LLM';
  FBtnSend.OnClick := BtnSendClick;
  
  // === Right Panel ===
  FRightPanel := TPanel.Create(Self);
  FRightPanel.Parent := Self;
  FRightPanel.Align := alRight;
  FRightPanel.Width := 400;
  FRightPanel.BevelOuter := bvNone;
  
  FSplitter := TSplitter.Create(Self);
  FSplitter.Parent := Self;
  FSplitter.Align := alRight;
  FSplitter.Width := 5;
  FSplitter.Color := $00E0E0E0;
  
  // Variable input section
  FVarPanel := TPanel.Create(Self);
  FVarPanel.Parent := FRightPanel;
  FVarPanel.Align := alTop;
  FVarPanel.Height := 180;
  FVarPanel.BevelOuter := bvNone;
  
  FLblVarTitle := TLabel.Create(Self);
  FLblVarTitle.Parent := FVarPanel;
  FLblVarTitle.Left := 8;
  FLblVarTitle.Top := 8;
  FLblVarTitle.Caption := 'Variables';
  FLblVarTitle.Font.Style := [fsBold];
  
  FVarGrid := TStringGrid.Create(Self);
  FVarGrid.Parent := FVarPanel;
  FVarGrid.Left := 8;
  FVarGrid.Top := 30;
  FVarGrid.Height := 140;
  FVarGrid.ColCount := 2;
  FVarGrid.RowCount := 2;
  FVarGrid.FixedCols := 1;
  FVarGrid.FixedRows := 1;
  FVarGrid.Options := FVarGrid.Options + [goEditing, goColSizing];
  FVarGrid.ColWidths[0] := 100;
  FVarGrid.ColWidths[1] := 250;
  FVarGrid.Cells[0, 0] := 'Variable';
  FVarGrid.Cells[1, 0] := 'Value';
  FVarGrid.OnSetEditText := VarGridSetEditText;
  
  // Stats section
  FStatsPanel := TPanel.Create(Self);
  FStatsPanel.Parent := FRightPanel;
  FStatsPanel.Align := alTop;
  FStatsPanel.Height := 150;
  FStatsPanel.BevelOuter := bvNone;
  
  FLblStatsTitle := TLabel.Create(Self);
  FLblStatsTitle.Parent := FStatsPanel;
  FLblStatsTitle.Left := 8;
  FLblStatsTitle.Top := 8;
  FLblStatsTitle.Caption := 'Statistics';
  FLblStatsTitle.Font.Style := [fsBold];
  
  FStatsGrid := TStringGrid.Create(Self);
  FStatsGrid.Parent := FStatsPanel;
  FStatsGrid.Left := 8;
  FStatsGrid.Top := 30;
  FStatsGrid.Height := 110;
  FStatsGrid.ColCount := 2;
  FStatsGrid.RowCount := 6;
  FStatsGrid.FixedCols := 0;
  FStatsGrid.FixedRows := 0;
  FStatsGrid.Options := FStatsGrid.Options - [goEditing];
  FStatsGrid.ColWidths[0] := 120;
  FStatsGrid.ColWidths[1] := 150;
  FStatsGrid.DefaultRowHeight := 20;
  
  // Preview section
  FPreviewPanel := TPanel.Create(Self);
  FPreviewPanel.Parent := FRightPanel;
  FPreviewPanel.Align := alClient;
  FPreviewPanel.BevelOuter := bvNone;
  
  FLblPreviewTitle := TLabel.Create(Self);
  FLblPreviewTitle.Parent := FPreviewPanel;
  FLblPreviewTitle.Left := 8;
  FLblPreviewTitle.Top := 8;
  FLblPreviewTitle.Caption := 'Preview (with variables)';
  FLblPreviewTitle.Font.Style := [fsBold];
  
  FBtnRefreshPreview := TSpeedButton.Create(Self);
  FBtnRefreshPreview.Parent := FPreviewPanel;
  FBtnRefreshPreview.Width := 24;
  FBtnRefreshPreview.Height := 24;
  FBtnRefreshPreview.Top := 4;
  FBtnRefreshPreview.Flat := True;
  FBtnRefreshPreview.Caption := '↻';
  FBtnRefreshPreview.Font.Size := 12;
  FBtnRefreshPreview.OnClick := BtnRefreshPreviewClick;
  FBtnRefreshPreview.Hint := 'Refresh preview';
  FBtnRefreshPreview.ShowHint := True;
  
  FMemoPreview := TMemo.Create(Self);
  FMemoPreview.Parent := FPreviewPanel;
  FMemoPreview.Left := 8;
  FMemoPreview.Top := 32;
  FMemoPreview.ReadOnly := True;
  FMemoPreview.ScrollBars := ssBoth;
  FMemoPreview.Font.Name := 'Consolas';
  FMemoPreview.Font.Size := 10;
  FMemoPreview.Color := $00F5F5F5;
  
  // === Editor Panel ===
  FEditorPanel := TPanel.Create(Self);
  FEditorPanel.Parent := Self;
  FEditorPanel.Align := alClient;
  FEditorPanel.BevelOuter := bvNone;
  
  FLblContentHint := TLabel.Create(Self);
  FLblContentHint.Parent := FEditorPanel;
  FLblContentHint.Left := 8;
  FLblContentHint.Top := 4;
  FLblContentHint.Caption := 'Prompt Content (use {{variable_name}} for variables)';
  FLblContentHint.Font.Color := $00757575;
  
  FMemoContent := TMemo.Create(Self);
  FMemoContent.Parent := FEditorPanel;
  FMemoContent.Left := 8;
  FMemoContent.Top := 24;
  FMemoContent.ScrollBars := ssBoth;
  FMemoContent.Font.Name := 'Consolas';
  FMemoContent.Font.Size := 11;
  FMemoContent.WantTabs := True;
  FMemoContent.OnChange := MemoContentChange;
end;

procedure TVersionDetailForm.SetupLayout;
begin
  // Position close button
  FBtnClose.Left := FHeaderPanel.Width - FBtnClose.Width - 8;
  FBtnClose.Top := 10;
  FBtnClose.Anchors := [akTop, akRight];
  
  // Position footer buttons
  FBtnSend.Left := FFooterPanel.Width - FBtnSend.Width - 16;
  FBtnSend.Top := 10;
  FBtnSend.Anchors := [akTop, akRight];
  
  FBtnSave.Left := FBtnSend.Left - FBtnSave.Width - 8;
  FBtnSave.Top := 10;
  FBtnSave.Anchors := [akTop, akRight];
  
  FBtnCancel.Left := FBtnSave.Left - FBtnCancel.Width - 8;
  FBtnCancel.Top := 10;
  FBtnCancel.Anchors := [akTop, akRight];
  
  // Size grids
  FVarGrid.Width := FVarPanel.Width - 16;
  FVarGrid.Anchors := [akLeft, akTop, akRight];
  
  FStatsGrid.Width := FStatsPanel.Width - 16;
  FStatsGrid.Anchors := [akLeft, akTop, akRight];
  
  FBtnRefreshPreview.Left := FPreviewPanel.Width - FBtnRefreshPreview.Width - 8;
  FBtnRefreshPreview.Anchors := [akTop, akRight];
  
  FMemoPreview.Width := FPreviewPanel.Width - 16;
  FMemoPreview.Anchors := [akLeft, akTop, akRight, akBottom];
  
  // Size content editor
  FMemoContent.Width := FEditorPanel.Width - 16;
  FMemoContent.Anchors := [akLeft, akTop, akRight, akBottom];
end;

procedure TVersionDetailForm.Initialize(ALLMManager: TLLMManager; 
  const APrompt: TPrompt; AVersionNumber: Integer);
begin
  FLLMManager := ALLMManager;
  FPrompt := APrompt;
  FVersionNumber := AVersionNumber;
  FVariables := APrompt.Variables;
  
  // Get or create version
  FVersion := APrompt.GetVersion(AVersionNumber);
  if FVersion.VersionNumber = 0 then
  begin
    FVersion.VersionNumber := AVersionNumber;
    FVersion.PromptId := APrompt.Id;
    FVersion.IsProduction := False;
    FVersion.Content := '';
  end;
  
  LoadVersion;
end;

procedure TVersionDetailForm.LoadVersion;
var
  I: Integer;
begin
  // Header
  FLblPromptCode.Caption := FPrompt.InternalCode + ' - ' + FPrompt.Name;
  FLblVersionNum.Caption := Format('Version %d', [FVersionNumber]);
  FChkProduction.Checked := FVersion.IsProduction;
  
  Caption := Format('Version %d - %s', [FVersionNumber, FPrompt.InternalCode]);
  
  // Content
  FMemoContent.Text := FVersion.Content;
  
  // Variables grid
  if Length(FVariables) > 0 then
  begin
    FVarGrid.RowCount := Length(FVariables) + 1;
    for I := 0 to High(FVariables) do
    begin
      FVarGrid.Cells[0, I + 1] := FVariables[I].Name;
      FVarGrid.Cells[1, I + 1] := VarToStr(FVariables[I].DefaultValue);
    end;
  end
  else
  begin
    FVarGrid.RowCount := 2;
    FVarGrid.Cells[0, 1] := '(no variables)';
    FVarGrid.Cells[1, 1] := '';
  end;
  
  UpdateStats;
  UpdatePreview;
  UpdateTokenCount;
  
  FModified := False;
end;

procedure TVersionDetailForm.UpdateStats;
begin
  FStatsGrid.Cells[0, 0] := 'Test Count';
  FStatsGrid.Cells[1, 0] := IntToStr(FVersion.TestCount);
  
  FStatsGrid.Cells[0, 1] := 'Success Count';
  FStatsGrid.Cells[1, 1] := IntToStr(FVersion.SuccessCount);
  
  FStatsGrid.Cells[0, 2] := 'Success Rate';
  if FVersion.TestCount > 0 then
    FStatsGrid.Cells[1, 2] := Format('%.1f%%', [FVersion.SuccessCount / FVersion.TestCount * 100])
  else
    FStatsGrid.Cells[1, 2] := 'N/A';
  
  FStatsGrid.Cells[0, 3] := 'Total Tokens';
  FStatsGrid.Cells[1, 3] := IntToStr(FVersion.TotalTokens);
  
  FStatsGrid.Cells[0, 4] := 'Total Cost';
  FStatsGrid.Cells[1, 4] := Format('$%.4f', [FVersion.TotalCost]);
  
  FStatsGrid.Cells[0, 5] := 'Avg Duration';
  FStatsGrid.Cells[1, 5] := Format('%.0f ms', [FVersion.AvgDuration]);
end;

procedure TVersionDetailForm.UpdatePreview;
var
  Content: string;
  VarValues: TDictionary<string, Variant>;
  Key: string;
begin
  Content := FMemoContent.Text;
  
  if Content = '' then
  begin
    FMemoPreview.Text := '(empty)';
    Exit;
  end;
  
  VarValues := GetVariableValues;
  try
    // Replace variables
    for Key in VarValues.Keys do
      Content := StringReplace(Content, '{{' + Key + '}}', 
        VarToStr(VarValues[Key]), [rfReplaceAll]);
  finally
    VarValues.Free;
  end;
  
  FMemoPreview.Text := Content;
end;

procedure TVersionDetailForm.UpdateTokenCount;
var
  Tokens: Integer;
begin
  Tokens := EstimateTokens(FMemoContent.Text);
  FLblTokens.Caption := Format('Estimated: %d tokens', [Tokens]);
end;

function TVersionDetailForm.GetVariableValues: TDictionary<string, Variant>;
var
  I: Integer;
begin
  Result := TDictionary<string, Variant>.Create;
  
  for I := 1 to FVarGrid.RowCount - 1 do
  begin
    if FVarGrid.Cells[0, I] <> '' then
      Result.AddOrSetValue(FVarGrid.Cells[0, I], FVarGrid.Cells[1, I]);
  end;
end;

function TVersionDetailForm.EstimateTokens(const Text: string): Integer;
begin
  // Rough estimate: ~4 characters per token for English
  // Adjust for Chinese: ~2 characters per token
  Result := Ceil(Length(Text) / 3.5);
end;

procedure TVersionDetailForm.BtnSaveClick(Sender: TObject);
begin
  // Update version content
  FVersion.Content := FMemoContent.Text;
  FVersion.IsProduction := FChkProduction.Checked;
  
  // Save to database
  if Assigned(FLLMManager) then
  begin
    FLLMManager.SaveVersion(FPrompt.InternalCode, FVersion);
    
    // If set as production, update prompt
    if FVersion.IsProduction then
      FLLMManager.SetProductionVersion(FPrompt.InternalCode, FVersionNumber);
  end;
  
  FModified := False;
  
  if Assigned(FOnSave) then
    FOnSave(Self);
    
  ModalResult := mrOk;
end;

procedure TVersionDetailForm.BtnCancelClick(Sender: TObject);
begin
  if FModified then
  begin
    case MessageDlg('You have unsaved changes. Discard?', 
                    mtConfirmation, [mbYes, mbNo], 0) of
      mrNo: Exit;
    end;
  end;
  
  ModalResult := mrCancel;
end;

procedure TVersionDetailForm.BtnCloseClick(Sender: TObject);
begin
  BtnCancelClick(Sender);
end;

procedure TVersionDetailForm.BtnSendClick(Sender: TObject);
var
  Content: string;
  VarValues: TDictionary<string, Variant>;
  Key: string;
  Response: TLLMResponse;
begin
  if not Assigned(FLLMManager) then
  begin
    ShowMessage('LLM Manager not available');
    Exit;
  end;
  
  Content := FMemoContent.Text;
  if Content = '' then
  begin
    ShowMessage('Please enter prompt content');
    Exit;
  end;
  
  VarValues := GetVariableValues;
  try
    // Replace variables
    for Key in VarValues.Keys do
      Content := StringReplace(Content, '{{' + Key + '}}', 
        VarToStr(VarValues[Key]), [rfReplaceAll]);
  finally
    VarValues.Free;
  end;
  
  // Send to LLM
  Screen.Cursor := crHourGlass;
  try
    Response := FLLMManager.Execute(Content, FVersionNumber);
    
    // Show response
    if Response.Success then
    begin
      ShowMessage(Format('Response (%d tokens, %d ms):'#13#10#13#10'%s', 
        [Response.TotalTokens, Response.DurationMs, Response.Content]));
        
      // Update stats
      FVersion := FLLMManager.GetVersion(FPrompt.InternalCode, FVersionNumber);
      UpdateStats;
    end
    else
      ShowMessage('Error: ' + Response.ErrorMessage);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TVersionDetailForm.BtnRefreshPreviewClick(Sender: TObject);
begin
  UpdatePreview;
end;

procedure TVersionDetailForm.ChkProductionClick(Sender: TObject);
begin
  FModified := True;
end;

procedure TVersionDetailForm.MemoContentChange(Sender: TObject);
begin
  FModified := True;
  UpdateTokenCount;
  UpdatePreview;
end;

procedure TVersionDetailForm.VarGridSetEditText(Sender: TObject; 
  ACol, ARow: Integer; const Value: string);
begin
  UpdatePreview;
end;

procedure TVersionDetailForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_ESCAPE:
      BtnCancelClick(Sender);
    VK_RETURN:
      if ssCtrl in Shift then
        BtnSaveClick(Sender);
    VK_F5:
      BtnRefreshPreviewClick(Sender);
  end;
end;

function TVersionDetailForm.GetVersion: TPromptVersion;
begin
  Result := FVersion;
  Result.Content := FMemoContent.Text;
  Result.IsProduction := FChkProduction.Checked;
end;

// Fix layout on resize
procedure TVersionDetailForm.Resize;
begin
  inherited;
  
  if Assigned(FMemoContent) then
  begin
    FMemoContent.Width := FEditorPanel.Width - 16;
    FMemoContent.Height := FEditorPanel.Height - 32;
  end;
  
  if Assigned(FMemoPreview) then
  begin
    FMemoPreview.Width := FPreviewPanel.Width - 16;
    FMemoPreview.Height := FPreviewPanel.Height - 40;
  end;
end;

end.
