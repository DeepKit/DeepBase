{ ============================================================================
  Studio.TranslationForm - i18n Translation Management Interface
  
  Version: 1.0
  Description: Provides visual editor for translation entries
  Features:
    - Translation grid editor
    - Source code scanning for translations
    - LLM batch translation
    - Translation progress statistics
    - Import/Export (JSON/PO)
  ============================================================================ }

unit Studio.TranslationForm;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Grids,
  Vcl.Dialogs,
  Vcl.Menus,
  FireDAC.Comp.Client,
  Studio.I18nScanner,
  UniBase.LLM;

type
  TTranslationForm = class(TForm)
  private
    // Toolbar
    FToolPanel: TPanel;
    FSourceLangCombo: TComboBox;
    FTargetLangCombo: TComboBox;
    FSourceLangLabel: TLabel;
    FTargetLangLabel: TLabel;
    FScanButton: TButton;
    FTranslateButton: TButton;
    FExportButton: TButton;
    FImportButton: TButton;
    
    // Translation grid
    FTransGrid: TStringGrid;
    
    // Status bar
    FStatusBar: TStatusBar;
    
    // Filter panel
    FFilterPanel: TPanel;
    FFilterEdit: TEdit;
    FShowUntranslatedCheck: TCheckBox;
    FShowNeedsReviewCheck: TCheckBox;
    
    // Context menu
    FGridPopupMenu: TPopupMenu;
    
    // Internal state
    FConnection: TFDConnection;
    FLLM: TUniBaseLLM;
    FScanner: TI18nScanner;
    FTranslationData: TList<TStringList>;
    FModified: Boolean;
    
    procedure CreateControls;
    procedure LoadLanguages;
    procedure LoadTranslations;
    procedure SaveTranslation(Row: Integer);
    procedure FilterTranslations;
    
    procedure ScanButtonClick(Sender: TObject);
    procedure TranslateButtonClick(Sender: TObject);
    procedure ExportButtonClick(Sender: TObject);
    procedure ImportButtonClick(Sender: TObject);
    procedure GridSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure GridSetEditText(Sender: TObject; ACol, ARow: Integer; const Value: string);
    procedure FilterChanged(Sender: TObject);
    
    procedure MenuCopyClick(Sender: TObject);
    procedure MenuPasteClick(Sender: TObject);
    procedure MenuMarkReviewedClick(Sender: TObject);
    procedure MenuDeleteClick(Sender: TObject);
    
    procedure UpdateStatusBar;
    function TranslateWithLLM(const SourceText, SourceLang, TargetLang: string): string;
    function TranslateBatchWithLLM(const SourceTexts: TArray<string>;
      const SourceLang, TargetLang: string): TArray<string>;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure Initialize(AConnection: TFDConnection; ALLM: TUniBaseLLM = nil);
    procedure RefreshData;
    
    property Modified: Boolean read FModified;
  end;

implementation

uses
  Vcl.Clipbrd;

{ TTranslationForm }

constructor TTranslationForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Caption := 'Translation Manager';
  Width := 1000;
  Height := 700;
  Position := poScreenCenter;
  
  FTranslationData := TList<TStringList>.Create;
  FModified := False;
  
  CreateControls;
end;

destructor TTranslationForm.Destroy;
var
  SL: TStringList;
begin
  for SL in FTranslationData do
    SL.Free;
  FTranslationData.Free;
  
  if Assigned(FScanner) then
    FScanner.Free;
    
  inherited;
end;

procedure TTranslationForm.CreateControls;
var
  MenuItem: TMenuItem;
begin
  // Toolbar panel
  FToolPanel := TPanel.Create(Self);
  FToolPanel.Parent := Self;
  FToolPanel.Align := alTop;
  FToolPanel.Height := 45;
  FToolPanel.BevelOuter := bvNone;
  
  // Source language
  FSourceLangLabel := TLabel.Create(Self);
  FSourceLangLabel.Parent := FToolPanel;
  FSourceLangLabel.SetBounds(10, 14, 60, 16);
  FSourceLangLabel.Caption := 'Source:';
  
  FSourceLangCombo := TComboBox.Create(Self);
  FSourceLangCombo.Parent := FToolPanel;
  FSourceLangCombo.SetBounds(70, 10, 100, 24);
  FSourceLangCombo.Style := csDropDownList;
  FSourceLangCombo.OnChange := FilterChanged;
  
  // Target language
  FTargetLangLabel := TLabel.Create(Self);
  FTargetLangLabel.Parent := FToolPanel;
  FTargetLangLabel.SetBounds(180, 14, 50, 16);
  FTargetLangLabel.Caption := 'Target:';
  
  FTargetLangCombo := TComboBox.Create(Self);
  FTargetLangCombo.Parent := FToolPanel;
  FTargetLangCombo.SetBounds(230, 10, 100, 24);
  FTargetLangCombo.Style := csDropDownList;
  FTargetLangCombo.OnChange := FilterChanged;
  
  // Buttons
  FScanButton := TButton.Create(Self);
  FScanButton.Parent := FToolPanel;
  FScanButton.SetBounds(360, 10, 80, 26);
  FScanButton.Caption := 'Scan';
  FScanButton.OnClick := ScanButtonClick;
  
  FTranslateButton := TButton.Create(Self);
  FTranslateButton.Parent := FToolPanel;
  FTranslateButton.SetBounds(450, 10, 100, 26);
  FTranslateButton.Caption := 'LLM Translate';
  FTranslateButton.OnClick := TranslateButtonClick;
  
  FExportButton := TButton.Create(Self);
  FExportButton.Parent := FToolPanel;
  FExportButton.SetBounds(560, 10, 70, 26);
  FExportButton.Caption := 'Export';
  FExportButton.OnClick := ExportButtonClick;
  
  FImportButton := TButton.Create(Self);
  FImportButton.Parent := FToolPanel;
  FImportButton.SetBounds(640, 10, 70, 26);
  FImportButton.Caption := 'Import';
  FImportButton.OnClick := ImportButtonClick;
  
  // Filter panel
  FFilterPanel := TPanel.Create(Self);
  FFilterPanel.Parent := Self;
  FFilterPanel.Align := alTop;
  FFilterPanel.Height := 35;
  FFilterPanel.BevelOuter := bvNone;
  
  FFilterEdit := TEdit.Create(Self);
  FFilterEdit.Parent := FFilterPanel;
  FFilterEdit.SetBounds(10, 6, 200, 24);
  FFilterEdit.TextHint := 'Filter by text...';
  FFilterEdit.OnChange := FilterChanged;
  
  FShowUntranslatedCheck := TCheckBox.Create(Self);
  FShowUntranslatedCheck.Parent := FFilterPanel;
  FShowUntranslatedCheck.SetBounds(230, 8, 120, 20);
  FShowUntranslatedCheck.Caption := 'Untranslated only';
  FShowUntranslatedCheck.OnClick := FilterChanged;
  
  FShowNeedsReviewCheck := TCheckBox.Create(Self);
  FShowNeedsReviewCheck.Parent := FFilterPanel;
  FShowNeedsReviewCheck.SetBounds(360, 8, 120, 20);
  FShowNeedsReviewCheck.Caption := 'Needs review';
  FShowNeedsReviewCheck.OnClick := FilterChanged;
  
  // Translation grid
  FTransGrid := TStringGrid.Create(Self);
  FTransGrid.Parent := Self;
  FTransGrid.Align := alClient;
  FTransGrid.ColCount := 4;
  FTransGrid.RowCount := 2;
  FTransGrid.FixedRows := 1;
  FTransGrid.FixedCols := 0;
  FTransGrid.DefaultRowHeight := 24;
  FTransGrid.Options := FTransGrid.Options + [goEditing, goRowSelect, goColSizing];
  FTransGrid.OnSelectCell := GridSelectCell;
  FTransGrid.OnSetEditText := GridSetEditText;
  
  // Column headers
  FTransGrid.Cells[0, 0] := 'Key (Source Text)';
  FTransGrid.Cells[1, 0] := 'Translation';
  FTransGrid.Cells[2, 0] := 'Status';
  FTransGrid.Cells[3, 0] := 'Context';
  
  FTransGrid.ColWidths[0] := 300;
  FTransGrid.ColWidths[1] := 300;
  FTransGrid.ColWidths[2] := 80;
  FTransGrid.ColWidths[3] := 150;
  
  // Context menu
  FGridPopupMenu := TPopupMenu.Create(Self);
  FTransGrid.PopupMenu := FGridPopupMenu;
  
  MenuItem := TMenuItem.Create(FGridPopupMenu);
  MenuItem.Caption := 'Copy';
  MenuItem.ShortCut := TextToShortCut('Ctrl+C');
  MenuItem.OnClick := MenuCopyClick;
  FGridPopupMenu.Items.Add(MenuItem);
  
  MenuItem := TMenuItem.Create(FGridPopupMenu);
  MenuItem.Caption := 'Paste';
  MenuItem.ShortCut := TextToShortCut('Ctrl+V');
  MenuItem.OnClick := MenuPasteClick;
  FGridPopupMenu.Items.Add(MenuItem);
  
  MenuItem := TMenuItem.Create(FGridPopupMenu);
  MenuItem.Caption := '-';
  FGridPopupMenu.Items.Add(MenuItem);
  
  MenuItem := TMenuItem.Create(FGridPopupMenu);
  MenuItem.Caption := 'Mark as Reviewed';
  MenuItem.OnClick := MenuMarkReviewedClick;
  FGridPopupMenu.Items.Add(MenuItem);
  
  MenuItem := TMenuItem.Create(FGridPopupMenu);
  MenuItem.Caption := '-';
  FGridPopupMenu.Items.Add(MenuItem);
  
  MenuItem := TMenuItem.Create(FGridPopupMenu);
  MenuItem.Caption := 'Delete';
  MenuItem.ShortCut := TextToShortCut('Del');
  MenuItem.OnClick := MenuDeleteClick;
  FGridPopupMenu.Items.Add(MenuItem);
  
  // Status bar
  FStatusBar := TStatusBar.Create(Self);
  FStatusBar.Parent := Self;
  FStatusBar.SimplePanel := False;
  FStatusBar.Panels.Add.Width := 150;
  FStatusBar.Panels.Add.Width := 150;
  FStatusBar.Panels.Add.Width := 150;
  FStatusBar.Panels.Add.Width := 200;
end;

procedure TTranslationForm.Initialize(AConnection: TFDConnection; ALLM: TUniBaseLLM);
begin
  FConnection := AConnection;
  FLLM := ALLM;
  
  if Assigned(FScanner) then
    FScanner.Free;
  FScanner := TI18nScanner.Create(FConnection);
  
  LoadLanguages;
  LoadTranslations;
end;

procedure TTranslationForm.LoadLanguages;
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  FSourceLangCombo.Items.Clear;
  FTargetLangCombo.Items.Clear;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT LangCode, LangName FROM Languages WHERE IsEnabled = 1 ORDER BY SortOrder';
    Query.Open;
    
    while not Query.Eof do
    begin
      FSourceLangCombo.Items.AddObject(
        Query.FieldByName('LangName').AsString,
        TObject(PChar(Query.FieldByName('LangCode').AsString)));
      FTargetLangCombo.Items.AddObject(
        Query.FieldByName('LangName').AsString,
        TObject(PChar(Query.FieldByName('LangCode').AsString)));
      Query.Next;
    end;
    
    if FSourceLangCombo.Items.Count > 0 then
      FSourceLangCombo.ItemIndex := 0;
    if FTargetLangCombo.Items.Count > 1 then
      FTargetLangCombo.ItemIndex := 1
    else if FTargetLangCombo.Items.Count > 0 then
      FTargetLangCombo.ItemIndex := 0;
  finally
    Query.Free;
  end;
end;

procedure TTranslationForm.LoadTranslations;
var
  Query: TFDQuery;
  TargetLang: string;
  SL: TStringList;
  Row: Integer;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  if FTargetLangCombo.ItemIndex < 0 then
    Exit;
    
  TargetLang := string(FTargetLangCombo.Items.Objects[FTargetLangCombo.ItemIndex]);
  
  // Clear existing data
  for SL in FTranslationData do
    SL.Free;
  FTranslationData.Clear;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'SELECT TextKey, TextValue, NeedsReview ' +
      'FROM I18nTexts WHERE LangCode = :Lang ORDER BY TextKey';
    Query.ParamByName('Lang').AsString := TargetLang;
    Query.Open;
    
    FTransGrid.RowCount := Max(2, Query.RecordCount + 1);
    Row := 1;
    
    while not Query.Eof do
    begin
      SL := TStringList.Create;
      SL.Values['Key'] := Query.FieldByName('TextKey').AsString;
      SL.Values['Value'] := Query.FieldByName('TextValue').AsString;
      SL.Values['NeedsReview'] := Query.FieldByName('NeedsReview').AsString;
      SL.Values['Lang'] := TargetLang;
      FTranslationData.Add(SL);
      
      FTransGrid.Cells[0, Row] := SL.Values['Key'];
      FTransGrid.Cells[1, Row] := SL.Values['Value'];
      
      if Query.FieldByName('NeedsReview').AsInteger = 1 then
        FTransGrid.Cells[2, Row] := 'Review'
      else if SL.Values['Key'] = SL.Values['Value'] then
        FTransGrid.Cells[2, Row] := 'Untranslated'
      else
        FTransGrid.Cells[2, Row] := 'OK';
        
      FTransGrid.Cells[3, Row] := '';
      
      Inc(Row);
      Query.Next;
    end;
    
    if Query.RecordCount = 0 then
    begin
      FTransGrid.Cells[0, 1] := '';
      FTransGrid.Cells[1, 1] := '';
      FTransGrid.Cells[2, 1] := '';
      FTransGrid.Cells[3, 1] := '';
    end;
  finally
    Query.Free;
  end;
  
  UpdateStatusBar;
end;

procedure TTranslationForm.SaveTranslation(Row: Integer);
var
  Query: TFDQuery;
  Key, Value, Lang: string;
  DataIndex: Integer;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  DataIndex := Row - 1;
  if (DataIndex < 0) or (DataIndex >= FTranslationData.Count) then
    Exit;
    
  Key := FTranslationData[DataIndex].Values['Key'];
  Value := FTransGrid.Cells[1, Row];
  Lang := FTranslationData[DataIndex].Values['Lang'];
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'UPDATE I18nTexts SET TextValue = :Value, NeedsReview = 0, UpdatedAt = CURRENT_TIMESTAMP ' +
      'WHERE LangCode = :Lang AND TextKey = :Key';
    Query.ParamByName('Value').AsString := Value;
    Query.ParamByName('Lang').AsString := Lang;
    Query.ParamByName('Key').AsString := Key;
    Query.ExecSQL;
    
    // Update local data
    FTranslationData[DataIndex].Values['Value'] := Value;
    FTranslationData[DataIndex].Values['NeedsReview'] := '0';
    
    // Update status column
    if Key = Value then
      FTransGrid.Cells[2, Row] := 'Untranslated'
    else
      FTransGrid.Cells[2, Row] := 'OK';
      
    FModified := True;
  finally
    Query.Free;
  end;
  
  UpdateStatusBar;
end;

procedure TTranslationForm.FilterTranslations;
begin
  LoadTranslations;
end;

procedure TTranslationForm.RefreshData;
begin
  LoadLanguages;
  LoadTranslations;
end;

procedure TTranslationForm.UpdateStatusBar;
var
  Total, Translated, NeedsReview: Integer;
  SL: TStringList;
begin
  Total := FTranslationData.Count;
  Translated := 0;
  NeedsReview := 0;
  
  for SL in FTranslationData do
  begin
    if SL.Values['Key'] <> SL.Values['Value'] then
      Inc(Translated);
    if SL.Values['NeedsReview'] = '1' then
      Inc(NeedsReview);
  end;
  
  FStatusBar.Panels[0].Text := Format('Total: %d', [Total]);
  FStatusBar.Panels[1].Text := Format('Translated: %d', [Translated]);
  FStatusBar.Panels[2].Text := Format('Needs Review: %d', [NeedsReview]);
  
  if Total > 0 then
    FStatusBar.Panels[3].Text := Format('Progress: %.1f%%', [Translated / Total * 100])
  else
    FStatusBar.Panels[3].Text := 'Progress: 0%';
end;

procedure TTranslationForm.ScanButtonClick(Sender: TObject);
var
  Dir: string;
  TotalFiles, TotalEntries, NewEntries, Imported: Integer;
begin
  if not Assigned(FScanner) then
    Exit;
    
  Dir := '';
  if not SelectDirectory('Select project directory to scan', '', Dir) then
    Exit;
    
  FScanButton.Enabled := False;
  FStatusBar.Panels[3].Text := 'Scanning...';
  Application.ProcessMessages;
  
  try
    FScanner.Clear;
    FScanner.OnProgress := procedure(const FileName: string; Current, Total: Integer)
    begin
      FStatusBar.Panels[3].Text := Format('Scanning %d/%d...', [Current, Total]);
      Application.ProcessMessages;
    end;
    
    FScanner.ScanDirectory(Dir, True);
    FScanner.GetStats(TotalFiles, TotalEntries, NewEntries);
    
    if NewEntries > 0 then
    begin
      if MessageDlg(Format('Found %d new entries in %d files. Import to database?',
        [NewEntries, TotalFiles]), mtConfirmation, [mbYes, mbNo], 0) = mrYes then
      begin
        Imported := FScanner.ImportNewEntries;
        ShowMessage(Format('Imported %d new entries.', [Imported]));
        LoadTranslations;
      end;
    end
    else
    begin
      ShowMessage(Format('Scanned %d files. No new entries found.', [TotalFiles]));
    end;
  finally
    FScanButton.Enabled := True;
    UpdateStatusBar;
  end;
end;

procedure TTranslationForm.TranslateButtonClick(Sender: TObject);
const
  BATCH_SIZE = 10;  // Number of concurrent translations
  MAX_BATCH_TEXTS = 20;  // Max texts per batch API call
var
  SourceLang, TargetLang: string;
  I, J, Translated, BatchStart: Integer;
  Key, Value: string;
  UntranslatedIndices: TList<Integer>;
  BatchTexts: TArray<string>;
  BatchResults: TArray<string>;
  UseBatchMode: Boolean;
begin
  if not Assigned(FLLM) then
  begin
    ShowMessage('LLM module not configured.');
    Exit;
  end;
  
  if FSourceLangCombo.ItemIndex < 0 then Exit;
  if FTargetLangCombo.ItemIndex < 0 then Exit;
  
  SourceLang := FSourceLangCombo.Text;
  TargetLang := FTargetLangCombo.Text;
  
  if SourceLang = TargetLang then
  begin
    ShowMessage('Source and target language must be different.');
    Exit;
  end;
  
  // Collect untranslated entries
  UntranslatedIndices := TList<Integer>.Create;
  try
    for I := 0 to FTranslationData.Count - 1 do
    begin
      Key := FTranslationData[I].Values['Key'];
      Value := FTranslationData[I].Values['Value'];
      if Key = Value then
        UntranslatedIndices.Add(I);
    end;
    
    if UntranslatedIndices.Count = 0 then
    begin
      ShowMessage('All entries are already translated.');
      Exit;
    end;
    
    UseBatchMode := UntranslatedIndices.Count > 5;
    
    if MessageDlg(Format('Translate %d entries using LLM?%s', 
      [UntranslatedIndices.Count, 
       IfThen(UseBatchMode, #13#10'(Using batch mode for faster processing)', '')]),
      mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      Exit;
      
    FTranslateButton.Enabled := False;
    Translated := 0;
    
    try
      if UseBatchMode then
      begin
        // Batch translation mode - process multiple texts per API call
        BatchStart := 0;
        while BatchStart < UntranslatedIndices.Count do
        begin
          // Prepare batch
          SetLength(BatchTexts, Min(MAX_BATCH_TEXTS, UntranslatedIndices.Count - BatchStart));
          for J := 0 to High(BatchTexts) do
            BatchTexts[J] := FTranslationData[UntranslatedIndices[BatchStart + J]].Values['Key'];
          
          FStatusBar.Panels[3].Text := Format('Translating batch %d-%d of %d...', 
            [BatchStart + 1, BatchStart + Length(BatchTexts), UntranslatedIndices.Count]);
          Application.ProcessMessages;
          
          // Translate batch
          BatchResults := TranslateBatchWithLLM(BatchTexts, SourceLang, TargetLang);
          
          // Apply results
          for J := 0 to High(BatchResults) do
          begin
            I := UntranslatedIndices[BatchStart + J];
            if (BatchResults[J] <> '') and (BatchResults[J] <> BatchTexts[J]) then
            begin
              FTransGrid.Cells[1, I + 1] := BatchResults[J];
              SaveTranslation(I + 1);
              Inc(Translated);
            end;
          end;
          
          Inc(BatchStart, Length(BatchTexts));
        end;
      end
      else
      begin
        // Sequential mode for small batches
        for I := 0 to UntranslatedIndices.Count - 1 do
        begin
          J := UntranslatedIndices[I];
          Key := FTranslationData[J].Values['Key'];
          
          FStatusBar.Panels[3].Text := Format('Translating %d/%d...', 
            [I + 1, UntranslatedIndices.Count]);
          Application.ProcessMessages;
          
          Value := TranslateWithLLM(Key, SourceLang, TargetLang);
          if (Value <> '') and (Value <> Key) then
          begin
            FTransGrid.Cells[1, J + 1] := Value;
            SaveTranslation(J + 1);
            Inc(Translated);
          end;
        end;
      end;
      
      ShowMessage(Format('Translated %d entries.', [Translated]));
    finally
      FTranslateButton.Enabled := True;
      UpdateStatusBar;
    end;
  finally
    UntranslatedIndices.Free;
  end;
end;

function TTranslationForm.TranslateWithLLM(const SourceText, SourceLang, TargetLang: string): string;
var
  Prompt: string;
  LLMResult: TLLMResult;
begin
  Result := '';
  
  Prompt := Format(
    'Translate the following text from %s to %s. ' +
    'Return ONLY the translated text, nothing else. ' +
    'Keep any placeholders like %%s, %%d, %%0:s intact. ' +
    'Text to translate: "%s"',
    [SourceLang, TargetLang, SourceText]);
  
  LLMResult := FLLM.Chat('Default', Prompt);
  
  if LLMResult.Success then
    Result := Trim(LLMResult.Response);
end;

function TTranslationForm.TranslateBatchWithLLM(const SourceTexts: TArray<string>;
  const SourceLang, TargetLang: string): TArray<string>;
var
  Prompt: string;
  LLMResult: TLLMResult;
  I: Integer;
  Lines: TArray<string>;
  SB: TStringBuilder;
begin
  SetLength(Result, Length(SourceTexts));
  if Length(SourceTexts) = 0 then
    Exit;
  
  // Build batch prompt with numbered lines
  SB := TStringBuilder.Create;
  try
    SB.AppendFormat('Translate the following %d texts from %s to %s.', 
      [Length(SourceTexts), SourceLang, TargetLang]);
    SB.AppendLine;
    SB.AppendLine('IMPORTANT RULES:');
    SB.AppendLine('1. Return ONLY the translations, one per line');
    SB.AppendLine('2. Keep the same order as input');
    SB.AppendLine('3. Preserve placeholders like %s, %d, %0:s exactly');
    SB.AppendLine('4. Do NOT include line numbers or prefixes');
    SB.AppendLine;
    SB.AppendLine('Texts to translate:');
    
    for I := 0 to High(SourceTexts) do
      SB.AppendFormat('%d. %s', [I + 1, SourceTexts[I]]).AppendLine;
    
    Prompt := SB.ToString;
  finally
    SB.Free;
  end;
  
  LLMResult := FLLM.Chat('Default', Prompt);
  
  if LLMResult.Success then
  begin
    // Parse response - one translation per line
    Lines := LLMResult.Response.Split([#13#10, #10], TStringSplitOptions.None);
    
    for I := 0 to Min(High(SourceTexts), High(Lines)) do
    begin
      Result[I] := Trim(Lines[I]);
      // Remove any leading numbers like "1. " if LLM included them
      if (Length(Result[I]) > 3) and CharInSet(Result[I][1], ['0'..'9']) then
      begin
        if (Result[I][2] = '.') and (Result[I][3] = ' ') then
          Result[I] := Copy(Result[I], 4, MaxInt)
        else if (Length(Result[I]) > 4) and (Result[I][3] = '.') and (Result[I][4] = ' ') then
          Result[I] := Copy(Result[I], 5, MaxInt);
      end;
    end;
  end
  else
  begin
    // Fallback to single translations if batch fails
    for I := 0 to High(SourceTexts) do
      Result[I] := TranslateWithLLM(SourceTexts[I], SourceLang, TargetLang);
  end;
end;

procedure TTranslationForm.ExportButtonClick(Sender: TObject);
var
  SaveDlg: TSaveDialog;
  TargetLang: string;
  JSONArray: TJSONArray;
  JSONObj: TJSONObject;
  SL: TStringList;
  Content: string;
begin
  if FTargetLangCombo.ItemIndex < 0 then
    Exit;
    
  TargetLang := string(FTargetLangCombo.Items.Objects[FTargetLangCombo.ItemIndex]);
  
  SaveDlg := TSaveDialog.Create(nil);
  try
    SaveDlg.Filter := 'JSON files (*.json)|*.json|PO files (*.po)|*.po';
    SaveDlg.DefaultExt := 'json';
    SaveDlg.FileName := 'translations_' + TargetLang;
    
    if SaveDlg.Execute then
    begin
      if LowerCase(ExtractFileExt(SaveDlg.FileName)) = '.json' then
      begin
        // Export JSON
        JSONArray := TJSONArray.Create;
        try
          for SL in FTranslationData do
          begin
            JSONObj := TJSONObject.Create;
            JSONObj.AddPair('key', SL.Values['Key']);
            JSONObj.AddPair('value', SL.Values['Value']);
            JSONObj.AddPair('needs_review', TJSONBool.Create(SL.Values['NeedsReview'] = '1'));
            JSONArray.AddElement(JSONObj);
          end;
          
          Content := JSONArray.Format(2);
          TFile.WriteAllText(SaveDlg.FileName, Content, TEncoding.UTF8);
        finally
          JSONArray.Free;
        end;
      end
      else
      begin
        // Export PO
        Content := '# Translation file for ' + TargetLang + #13#10;
        Content := Content + 'msgid ""' + #13#10;
        Content := Content + 'msgstr ""' + #13#10;
        Content := Content + '"Language: ' + TargetLang + '\n"' + #13#10;
        Content := Content + #13#10;
        
        for SL in FTranslationData do
        begin
          Content := Content + 'msgid "' + SL.Values['Key'].Replace('"', '\"') + '"' + #13#10;
          Content := Content + 'msgstr "' + SL.Values['Value'].Replace('"', '\"') + '"' + #13#10;
          Content := Content + #13#10;
        end;
        
        TFile.WriteAllText(SaveDlg.FileName, Content, TEncoding.UTF8);
      end;
      
      ShowMessage('Exported successfully.');
    end;
  finally
    SaveDlg.Free;
  end;
end;

procedure TTranslationForm.ImportButtonClick(Sender: TObject);
var
  OpenDlg: TOpenDialog;
  TargetLang, Content: string;
  JSONArray: TJSONArray;
  JSONObj: TJSONObject;
  Query: TFDQuery;
  I, Imported: Integer;
  Key, Value: string;
begin
  if FTargetLangCombo.ItemIndex < 0 then
    Exit;
    
  TargetLang := string(FTargetLangCombo.Items.Objects[FTargetLangCombo.ItemIndex]);
  
  OpenDlg := TOpenDialog.Create(nil);
  try
    OpenDlg.Filter := 'JSON files (*.json)|*.json';
    
    if OpenDlg.Execute then
    begin
      Content := TFile.ReadAllText(OpenDlg.FileName, TEncoding.UTF8);
      JSONArray := TJSONObject.ParseJSONValue(Content) as TJSONArray;
      
      if not Assigned(JSONArray) then
      begin
        ShowMessage('Invalid JSON file.');
        Exit;
      end;
      
      try
        Query := TFDQuery.Create(nil);
        try
          Query.Connection := FConnection;
          Query.SQL.Text := 
            'UPDATE I18nTexts SET TextValue = :Value, NeedsReview = 0, UpdatedAt = CURRENT_TIMESTAMP ' +
            'WHERE LangCode = :Lang AND TextKey = :Key';
          
          Imported := 0;
          FConnection.StartTransaction;
          try
            for I := 0 to JSONArray.Count - 1 do
            begin
              JSONObj := JSONArray.Items[I] as TJSONObject;
              Key := JSONObj.GetValue<string>('key', '');
              Value := JSONObj.GetValue<string>('value', '');
              
              if (Key <> '') and (Value <> '') then
              begin
                Query.ParamByName('Value').AsString := Value;
                Query.ParamByName('Lang').AsString := TargetLang;
                Query.ParamByName('Key').AsString := Key;
                Query.ExecSQL;
                
                if Query.RowsAffected > 0 then
                  Inc(Imported);
              end;
            end;
            FConnection.Commit;
          except
            FConnection.Rollback;
            raise;
          end;
          
          ShowMessage(Format('Imported %d translations.', [Imported]));
          LoadTranslations;
        finally
          Query.Free;
        end;
      finally
        JSONArray.Free;
      end;
    end;
  finally
    OpenDlg.Free;
  end;
end;

procedure TTranslationForm.GridSelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
begin
  // Allow editing translation column only
  CanSelect := True;
end;

procedure TTranslationForm.GridSetEditText(Sender: TObject; ACol, ARow: Integer;
  const Value: string);
begin
  // Save translation (translation column only)
  if (ACol = 1) and (ARow > 0) then
    SaveTranslation(ARow);
end;

procedure TTranslationForm.FilterChanged(Sender: TObject);
begin
  LoadTranslations;
end;

procedure TTranslationForm.MenuCopyClick(Sender: TObject);
begin
  if FTransGrid.Row > 0 then
    Clipboard.AsText := FTransGrid.Cells[FTransGrid.Col, FTransGrid.Row];
end;

procedure TTranslationForm.MenuPasteClick(Sender: TObject);
begin
  if (FTransGrid.Row > 0) and (FTransGrid.Col = 1) then
  begin
    FTransGrid.Cells[1, FTransGrid.Row] := Clipboard.AsText;
    SaveTranslation(FTransGrid.Row);
  end;
end;

procedure TTranslationForm.MenuMarkReviewedClick(Sender: TObject);
var
  Query: TFDQuery;
  DataIndex: Integer;
  Key, Lang: string;
begin
  if FTransGrid.Row <= 0 then
    Exit;
    
  DataIndex := FTransGrid.Row - 1;
  if (DataIndex < 0) or (DataIndex >= FTranslationData.Count) then
    Exit;
    
  Key := FTranslationData[DataIndex].Values['Key'];
  Lang := FTranslationData[DataIndex].Values['Lang'];
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'UPDATE I18nTexts SET NeedsReview = 0, UpdatedAt = CURRENT_TIMESTAMP ' +
      'WHERE LangCode = :Lang AND TextKey = :Key';
    Query.ParamByName('Lang').AsString := Lang;
    Query.ParamByName('Key').AsString := Key;
    Query.ExecSQL;
    
    FTranslationData[DataIndex].Values['NeedsReview'] := '0';
    FTransGrid.Cells[2, FTransGrid.Row] := 'OK';
    
    UpdateStatusBar;
  finally
    Query.Free;
  end;
end;

procedure TTranslationForm.MenuDeleteClick(Sender: TObject);
var
  Query: TFDQuery;
  DataIndex: Integer;
  Key, Lang: string;
begin
  if FTransGrid.Row <= 0 then
    Exit;
    
  if MessageDlg('Delete this translation entry?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
    
  DataIndex := FTransGrid.Row - 1;
  if (DataIndex < 0) or (DataIndex >= FTranslationData.Count) then
    Exit;
    
  Key := FTranslationData[DataIndex].Values['Key'];
  Lang := FTranslationData[DataIndex].Values['Lang'];
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM I18nTexts WHERE LangCode = :Lang AND TextKey = :Key';
    Query.ParamByName('Lang').AsString := Lang;
    Query.ParamByName('Key').AsString := Key;
    Query.ExecSQL;
    
    LoadTranslations;
  finally
    Query.Free;
  end;
end;

end.
