{ ============================================================================
  Studio.LLMConfigForm - LLM Configuration Management Window
  
  Version: 1.1
  Description: Provides interface for managing LLM provider configurations
  Features:
    - Configuration editing (Provider/Model/APIKey/Temperature)
    - Connection testing with response display
    - Configuration list with status indicators
    - Usage statistics
  UI Design: docs/ui/svg/components/LLM_ConfigDebugWindow.svg
  ============================================================================ }

unit Studio.LLMConfigForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Generics.Collections,
  System.Math,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Grids,
  FireDAC.Comp.Client,
  DeepBase.LLM.Types,
  DeepBase.LLM;

type
  TConfigStatus = (csUnknown, csOnline, csOffline, csError);
  
  TLLMConfigForm = class(TForm)
  private
    // === Top Container & Splitters ===
    FTopContainer: TPanel;
    FVSplitter: TSplitter;
    FHSplitter: TSplitter;

    // === Top Left: Config Editor ===
    FEditorPanel: TPanel;
    
    FLblConfigName: TLabel;
    FCboConfigName: TComboBox;
    FBtnNewConfig: TButton;
    FBtnDeleteConfig: TButton;
    
    FLblProvider: TLabel;
    FCboProvider: TComboBox;
    
    FLblModel: TLabel;
    FEdtModel: TEdit;
    
    FLblApiUrl: TLabel;
    FEdtApiUrl: TEdit;
    
    FLblApiKey: TLabel;
    FEdtApiKey: TEdit;
    FChkShowKey: TCheckBox;
    
    FLblTemperature: TLabel;
    FEdtTemperature: TEdit;
    FTrkTemperature: TTrackBar;
    
    FLblMaxTokens: TLabel;
    FEdtMaxTokens: TEdit;
    
    FLblTimeout: TLabel;
    FEdtTimeout: TEdit;
    
    FLblInputPrice: TLabel;
    FEdtInputPrice: TEdit;
    
    FLblOutputPrice: TLabel;
    FEdtOutputPrice: TEdit;
    
    FChkIsDefault: TCheckBox;
    FChkIsEnabled: TCheckBox;
    
    FBtnSaveConfig: TButton;
    
    // === Top Right: Test Area ===
    FTestPanel: TPanel;
    FLblTestPrompt: TLabel;
    FMmoTestPrompt: TMemo;
    FBtnTestConnection: TButton;
    FBtnSendTest: TButton;
    FLblTestResponse: TLabel;
    FMmoTestResponse: TMemo;
    FLblTestStats: TLabel;
    
    // === Bottom: Config List Grid ===
    FListPanel: TPanel;
    FConfigGrid: TStringGrid;
    FLblUsageStats: TLabel;
    
    // === Status Bar ===
    FStatusBar: TStatusBar;
    
    // Internal
    FConnection: TFDConnection;
    FLLM: TDeepBaseLLM;
    FOwnsLLM: Boolean;
    FCurrentConfig: TLLMConfig;
    FModified: Boolean;
    
    procedure CreateControls;
    procedure CreateEditorPanel;
    procedure CreateTestPanel;
    procedure CreateListPanel;
    
    procedure LoadProviders;
    procedure LoadConfigList;
    procedure LoadConfig(const ConfigName: string);
    procedure SaveConfig;
    procedure RefreshGrid;
    procedure UpdateUsageStats;
    procedure AdjustGridColumns;
    
    // Events
    procedure CboConfigNameChange(Sender: TObject);
    procedure CboProviderChange(Sender: TObject);
    procedure BtnNewConfigClick(Sender: TObject);
    procedure BtnDeleteConfigClick(Sender: TObject);
    procedure BtnSaveConfigClick(Sender: TObject);
    procedure BtnTestConnectionClick(Sender: TObject);
    procedure BtnSendTestClick(Sender: TObject);
    procedure TrkTemperatureChange(Sender: TObject);
    procedure EdtTemperatureChange(Sender: TObject);
    procedure ChkShowKeyClick(Sender: TObject);
    procedure ConfigGridSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure ConfigGridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure ContentChanged(Sender: TObject);
    
    procedure SetStatus(const Text: string; IsError: Boolean = False);
    procedure UpdateProviderDefaults;
    
  protected
    procedure Resize; override;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure Initialize(AConnection: TFDConnection; ALLM: TDeepBaseLLM = nil);
    procedure RefreshData;
    
    property LLM: TDeepBaseLLM read FLLM;
    property Modified: Boolean read FModified;
  end;

var
  LLMConfigForm: TLLMConfigForm;

implementation

uses
  System.DateUtils;

const
  PROVIDERS: array[0..5] of string = (
    'OpenAI', 'Anthropic', 'Azure', 'LiteLLM', 'Ollama', 'Custom'
  );
  
  DEFAULT_URLS: array[0..5] of string = (
    'https://api.openai.com/v1',
    'https://api.anthropic.com/v1',
    '',
    'http://localhost:4000',
    'http://localhost:11434',
    ''
  );
  
  DEFAULT_MODELS: array[0..5] of string = (
    'gpt-4o-mini',
    'claude-3-haiku-20240307',
    'gpt-4',
    'gpt-4o-mini',
    'llama2',
    ''
  );
  
  // Grid columns
  GRID_COL_NAME = 0;
  GRID_COL_PROVIDER = 1;
  GRID_COL_MODEL = 2;
  GRID_COL_STATUS = 3;
  GRID_COL_CALLS = 4;
  GRID_COL_TOKENS = 5;
  GRID_COL_COST = 6;
  GRID_COL_DEFAULT = 7;

{ TLLMConfigForm }

constructor TLLMConfigForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Caption := 'LLM Configuration Manager';
  Width := 1180;
  Height := 820;
  Constraints.MinWidth := 920;
  Constraints.MinHeight := 640;
  Position := poScreenCenter;
  
  FOwnsLLM := False;
  FModified := False;
  FCurrentConfig.Init;
  
  CreateControls;
end;

destructor TLLMConfigForm.Destroy;
begin
  // Clear event handlers
  if Assigned(FCboConfigName) then FCboConfigName.OnChange := nil;
  if Assigned(FCboProvider) then FCboProvider.OnChange := nil;
  if Assigned(FTrkTemperature) then FTrkTemperature.OnChange := nil;
  if Assigned(FConfigGrid) then
  begin
    FConfigGrid.OnSelectCell := nil;
    FConfigGrid.OnDrawCell := nil;
  end;
  
  if FOwnsLLM and Assigned(FLLM) then
  begin
    FLLM.Free;
    FLLM := nil;
  end;
  
  inherited;
end;

procedure TLLMConfigForm.Resize;
begin
  inherited;
  AdjustGridColumns;
end;

procedure TLLMConfigForm.AdjustGridColumns;
var
  AvailW: Integer;
begin
  if Assigned(FConfigGrid) and (FConfigGrid.ClientWidth > 200) then
  begin
    AvailW := FConfigGrid.ClientWidth - 25;
    FConfigGrid.ColWidths[GRID_COL_NAME] := Max(100, AvailW * 14 div 100);
    FConfigGrid.ColWidths[GRID_COL_PROVIDER] := Max(80, AvailW * 10 div 100);
    FConfigGrid.ColWidths[GRID_COL_MODEL] := Max(140, AvailW * 22 div 100);
    FConfigGrid.ColWidths[GRID_COL_STATUS] := Max(70, AvailW * 8 div 100);
    FConfigGrid.ColWidths[GRID_COL_CALLS] := Max(70, AvailW * 8 div 100);
    FConfigGrid.ColWidths[GRID_COL_TOKENS] := Max(80, AvailW * 10 div 100);
    FConfigGrid.ColWidths[GRID_COL_COST] := Max(80, AvailW * 10 div 100);
    FConfigGrid.ColWidths[GRID_COL_DEFAULT] := Max(60, AvailW - (
      FConfigGrid.ColWidths[GRID_COL_NAME] +
      FConfigGrid.ColWidths[GRID_COL_PROVIDER] +
      FConfigGrid.ColWidths[GRID_COL_MODEL] +
      FConfigGrid.ColWidths[GRID_COL_STATUS] +
      FConfigGrid.ColWidths[GRID_COL_CALLS] +
      FConfigGrid.ColWidths[GRID_COL_TOKENS] +
      FConfigGrid.ColWidths[GRID_COL_COST]));
  end;
end;

procedure TLLMConfigForm.CreateControls;
begin
  // Status Bar
  FStatusBar := TStatusBar.Create(Self);
  FStatusBar.Parent := Self;
  FStatusBar.SimplePanel := True;
  FStatusBar.SimpleText := 'Ready';
  
  // List Panel (Bottom)
  CreateListPanel;
  
  // Horizontal Splitter between Top Container and List Panel
  FHSplitter := TSplitter.Create(Self);
  FHSplitter.Parent := Self;
  FHSplitter.Align := alBottom;
  FHSplitter.Height := 5;
  FHSplitter.Cursor := crVSplit;
  FHSplitter.MinSize := 120;
  
  // Top Container for Editor & Test panels
  FTopContainer := TPanel.Create(Self);
  FTopContainer.Parent := Self;
  FTopContainer.Align := alClient;
  FTopContainer.BevelOuter := bvNone;
  FTopContainer.Caption := '';
  
  // Editor Panel (Top Left)
  CreateEditorPanel;
  
  // Vertical Splitter between Editor and Test
  FVSplitter := TSplitter.Create(Self);
  FVSplitter.Parent := FTopContainer;
  FVSplitter.Align := alLeft;
  FVSplitter.Width := 5;
  FVSplitter.Cursor := crHSplit;
  FVSplitter.MinSize := 380;
  
  // Test Panel (Top Right)
  CreateTestPanel;
end;

procedure TLLMConfigForm.CreateEditorPanel;
var
  Y: Integer;
begin
  FEditorPanel := TPanel.Create(Self);
  FEditorPanel.Parent := FTopContainer;
  FEditorPanel.Align := alLeft;
  FEditorPanel.Width := 450;
  FEditorPanel.Constraints.MinWidth := 390;
  FEditorPanel.BevelOuter := bvNone;
  FEditorPanel.Caption := '';
  
  Y := 12;
  
  // Row 1: Config Name
  FLblConfigName := TLabel.Create(Self);
  FLblConfigName.Parent := FEditorPanel;
  FLblConfigName.SetBounds(12, Y, 85, 16);
  FLblConfigName.Caption := 'Config Name:';
  
  FCboConfigName := TComboBox.Create(Self);
  FCboConfigName.Parent := FEditorPanel;
  FCboConfigName.SetBounds(105, Y - 4, 180, 24);
  FCboConfigName.Style := csDropDownList;
  FCboConfigName.OnChange := CboConfigNameChange;
  
  FBtnNewConfig := TButton.Create(Self);
  FBtnNewConfig.Parent := FEditorPanel;
  FBtnNewConfig.SetBounds(295, Y - 5, 65, 26);
  FBtnNewConfig.Caption := 'New';
  FBtnNewConfig.OnClick := BtnNewConfigClick;
  
  FBtnDeleteConfig := TButton.Create(Self);
  FBtnDeleteConfig.Parent := FEditorPanel;
  FBtnDeleteConfig.SetBounds(368, Y - 5, 65, 26);
  FBtnDeleteConfig.Caption := 'Del';
  FBtnDeleteConfig.OnClick := BtnDeleteConfigClick;
  
  Inc(Y, 36);
  
  // Row 2: Provider
  FLblProvider := TLabel.Create(Self);
  FLblProvider.Parent := FEditorPanel;
  FLblProvider.SetBounds(12, Y, 85, 16);
  FLblProvider.Caption := 'Provider:';
  
  FCboProvider := TComboBox.Create(Self);
  FCboProvider.Parent := FEditorPanel;
  FCboProvider.SetBounds(105, Y - 4, 180, 24);
  FCboProvider.Style := csDropDownList;
  FCboProvider.OnChange := CboProviderChange;
  
  Inc(Y, 36);
  
  // Row 3: Model
  FLblModel := TLabel.Create(Self);
  FLblModel.Parent := FEditorPanel;
  FLblModel.SetBounds(12, Y, 85, 16);
  FLblModel.Caption := 'Model:';
  
  FEdtModel := TEdit.Create(Self);
  FEdtModel.Parent := FEditorPanel;
  FEdtModel.SetBounds(105, Y - 4, 328, 24);
  FEdtModel.Anchors := [akLeft, akTop, akRight];
  FEdtModel.OnChange := ContentChanged;
  
  Inc(Y, 36);
  
  // Row 4: API URL
  FLblApiUrl := TLabel.Create(Self);
  FLblApiUrl.Parent := FEditorPanel;
  FLblApiUrl.SetBounds(12, Y, 85, 16);
  FLblApiUrl.Caption := 'API URL:';
  
  FEdtApiUrl := TEdit.Create(Self);
  FEdtApiUrl.Parent := FEditorPanel;
  FEdtApiUrl.SetBounds(105, Y - 4, 328, 24);
  FEdtApiUrl.Anchors := [akLeft, akTop, akRight];
  FEdtApiUrl.OnChange := ContentChanged;
  
  Inc(Y, 36);
  
  // Row 5: API Key
  FLblApiKey := TLabel.Create(Self);
  FLblApiKey.Parent := FEditorPanel;
  FLblApiKey.SetBounds(12, Y, 85, 16);
  FLblApiKey.Caption := 'API Key:';
  
  FEdtApiKey := TEdit.Create(Self);
  FEdtApiKey.Parent := FEditorPanel;
  FEdtApiKey.SetBounds(105, Y - 4, 255, 24);
  FEdtApiKey.Anchors := [akLeft, akTop, akRight];
  FEdtApiKey.PasswordChar := '*';
  FEdtApiKey.OnChange := ContentChanged;
  
  FChkShowKey := TCheckBox.Create(Self);
  FChkShowKey.Parent := FEditorPanel;
  FChkShowKey.SetBounds(368, Y - 2, 65, 20);
  FChkShowKey.Anchors := [akTop, akRight];
  FChkShowKey.Caption := 'Show';
  FChkShowKey.OnClick := ChkShowKeyClick;
  
  Inc(Y, 36);
  
  // Row 6: Temperature
  FLblTemperature := TLabel.Create(Self);
  FLblTemperature.Parent := FEditorPanel;
  FLblTemperature.SetBounds(12, Y, 85, 16);
  FLblTemperature.Caption := 'Temperature:';
  
  FEdtTemperature := TEdit.Create(Self);
  FEdtTemperature.Parent := FEditorPanel;
  FEdtTemperature.SetBounds(105, Y - 4, 50, 24);
  FEdtTemperature.Text := '0.7';
  FEdtTemperature.OnChange := EdtTemperatureChange;
  
  FTrkTemperature := TTrackBar.Create(Self);
  FTrkTemperature.Parent := FEditorPanel;
  FTrkTemperature.SetBounds(165, Y - 6, 268, 30);
  FTrkTemperature.Anchors := [akLeft, akTop, akRight];
  FTrkTemperature.Min := 0;
  FTrkTemperature.Max := 20;
  FTrkTemperature.Position := 7;
  FTrkTemperature.TickStyle := tsNone;
  FTrkTemperature.OnChange := TrkTemperatureChange;
  
  Inc(Y, 36);
  
  // Row 7: Max Tokens & Timeout (Spacious, No Overlap)
  FLblMaxTokens := TLabel.Create(Self);
  FLblMaxTokens.Parent := FEditorPanel;
  FLblMaxTokens.SetBounds(12, Y, 85, 16);
  FLblMaxTokens.Caption := 'Max Tokens:';
  
  FEdtMaxTokens := TEdit.Create(Self);
  FEdtMaxTokens.Parent := FEditorPanel;
  FEdtMaxTokens.SetBounds(105, Y - 4, 85, 24);
  FEdtMaxTokens.Text := '4096';
  FEdtMaxTokens.OnChange := ContentChanged;
  
  FLblTimeout := TLabel.Create(Self);
  FLblTimeout.Parent := FEditorPanel;
  FLblTimeout.SetBounds(210, Y, 60, 16);
  FLblTimeout.Caption := 'Timeout:';
  
  FEdtTimeout := TEdit.Create(Self);
  FEdtTimeout.Parent := FEditorPanel;
  FEdtTimeout.SetBounds(275, Y - 4, 85, 24);
  FEdtTimeout.Text := '60000';
  FEdtTimeout.OnChange := ContentChanged;
  
  Inc(Y, 36);
  
  // Row 8: Input Price & Output Price (Spacious, No Overlap)
  FLblInputPrice := TLabel.Create(Self);
  FLblInputPrice.Parent := FEditorPanel;
  FLblInputPrice.SetBounds(12, Y, 85, 16);
  FLblInputPrice.Caption := 'In Price/1K:';
  
  FEdtInputPrice := TEdit.Create(Self);
  FEdtInputPrice.Parent := FEditorPanel;
  FEdtInputPrice.SetBounds(105, Y - 4, 85, 24);
  FEdtInputPrice.Text := '0.00015';
  FEdtInputPrice.OnChange := ContentChanged;
  
  FLblOutputPrice := TLabel.Create(Self);
  FLblOutputPrice.Parent := FEditorPanel;
  FLblOutputPrice.SetBounds(210, Y, 80, 16);
  FLblOutputPrice.Caption := 'Out Price/1K:';
  
  FEdtOutputPrice := TEdit.Create(Self);
  FEdtOutputPrice.Parent := FEditorPanel;
  FEdtOutputPrice.SetBounds(295, Y - 4, 85, 24);
  FEdtOutputPrice.Text := '0.0006';
  FEdtOutputPrice.OnChange := ContentChanged;
  
  Inc(Y, 40);
  
  // Row 9: Checkboxes
  FChkIsDefault := TCheckBox.Create(Self);
  FChkIsDefault.Parent := FEditorPanel;
  FChkIsDefault.SetBounds(12, Y, 105, 20);
  FChkIsDefault.Caption := 'Is Default';
  FChkIsDefault.OnClick := ContentChanged;
  
  FChkIsEnabled := TCheckBox.Create(Self);
  FChkIsEnabled.Parent := FEditorPanel;
  FChkIsEnabled.SetBounds(130, Y, 105, 20);
  FChkIsEnabled.Caption := 'Enabled';
  FChkIsEnabled.Checked := True;
  FChkIsEnabled.OnClick := ContentChanged;
  
  Inc(Y, 36);
  
  // Row 10: Save Button
  FBtnSaveConfig := TButton.Create(Self);
  FBtnSaveConfig.Parent := FEditorPanel;
  FBtnSaveConfig.SetBounds(12, Y, 130, 32);
  FBtnSaveConfig.Caption := 'Save Config';
  FBtnSaveConfig.Font.Style := [fsBold];
  FBtnSaveConfig.OnClick := BtnSaveConfigClick;
  
  LoadProviders;
end;

procedure TLLMConfigForm.CreateTestPanel;
begin
  FTestPanel := TPanel.Create(Self);
  FTestPanel.Parent := FTopContainer;
  FTestPanel.Align := alClient;
  FTestPanel.BevelOuter := bvNone;
  FTestPanel.Caption := '';
  
  // Test Prompt Label
  FLblTestPrompt := TLabel.Create(Self);
  FLblTestPrompt.Parent := FTestPanel;
  FLblTestPrompt.SetBounds(12, 12, 100, 16);
  FLblTestPrompt.Caption := 'Test Prompt:';
  
  // Test Prompt Memo
  FMmoTestPrompt := TMemo.Create(Self);
  FMmoTestPrompt.Parent := FTestPanel;
  FMmoTestPrompt.SetBounds(12, 32, FTestPanel.ClientWidth - 24, 85);
  FMmoTestPrompt.Anchors := [akLeft, akTop, akRight];
  FMmoTestPrompt.ScrollBars := ssVertical;
  FMmoTestPrompt.Text := 'Reply with exactly: OK';
  
  // Test Buttons
  FBtnTestConnection := TButton.Create(Self);
  FBtnTestConnection.Parent := FTestPanel;
  FBtnTestConnection.SetBounds(12, 126, 130, 28);
  FBtnTestConnection.Caption := 'Test Connection';
  FBtnTestConnection.OnClick := BtnTestConnectionClick;
  
  FBtnSendTest := TButton.Create(Self);
  FBtnSendTest.Parent := FTestPanel;
  FBtnSendTest.SetBounds(150, 126, 100, 28);
  FBtnSendTest.Caption := 'Send Test';
  FBtnSendTest.OnClick := BtnSendTestClick;
  
  // Test Stats
  FLblTestStats := TLabel.Create(Self);
  FLblTestStats.Parent := FTestPanel;
  FLblTestStats.SetBounds(260, 131, 380, 16);
  FLblTestStats.Anchors := [akLeft, akTop, akRight];
  FLblTestStats.Caption := '';
  FLblTestStats.Font.Color := clGray;
  
  // Response Label
  FLblTestResponse := TLabel.Create(Self);
  FLblTestResponse.Parent := FTestPanel;
  FLblTestResponse.SetBounds(12, 164, 100, 16);
  FLblTestResponse.Caption := 'Response:';
  
  // Response Memo
  FMmoTestResponse := TMemo.Create(Self);
  FMmoTestResponse.Parent := FTestPanel;
  FMmoTestResponse.SetBounds(12, 184, FTestPanel.ClientWidth - 24, Max(80, FTestPanel.ClientHeight - 196));
  FMmoTestResponse.Anchors := [akLeft, akTop, akRight, akBottom];
  FMmoTestResponse.ScrollBars := ssBoth;
  FMmoTestResponse.ReadOnly := True;
  FMmoTestResponse.Font.Name := 'Consolas';
  FMmoTestResponse.Font.Size := 10;
end;

procedure TLLMConfigForm.CreateListPanel;
begin
  FListPanel := TPanel.Create(Self);
  FListPanel.Parent := Self;
  FListPanel.Align := alBottom;
  FListPanel.Height := 250;
  FListPanel.Constraints.MinHeight := 120;
  FListPanel.BevelOuter := bvNone;
  FListPanel.Caption := '';
  
  // Usage Stats Label
  FLblUsageStats := TLabel.Create(Self);
  FLblUsageStats.Parent := FListPanel;
  FLblUsageStats.SetBounds(12, 6, 600, 16);
  FLblUsageStats.Caption := 'Configured Models';
  FLblUsageStats.Font.Style := [fsBold];
  
  // Config Grid
  FConfigGrid := TStringGrid.Create(Self);
  FConfigGrid.Parent := FListPanel;
  FConfigGrid.Align := alClient;
  FConfigGrid.AlignWithMargins := True;
  FConfigGrid.Margins.SetBounds(12, 26, 12, 8);
  FConfigGrid.ColCount := 8;
  FConfigGrid.RowCount := 2;
  FConfigGrid.FixedRows := 1;
  FConfigGrid.FixedCols := 0;
  FConfigGrid.DefaultRowHeight := 24;
  FConfigGrid.Options := FConfigGrid.Options + [goRowSelect, goThumbTracking];
  FConfigGrid.OnSelectCell := ConfigGridSelectCell;
  FConfigGrid.OnDrawCell := ConfigGridDrawCell;
  
  // Column headers
  FConfigGrid.Cells[GRID_COL_NAME, 0] := 'Name';
  FConfigGrid.Cells[GRID_COL_PROVIDER, 0] := 'Provider';
  FConfigGrid.Cells[GRID_COL_MODEL, 0] := 'Model';
  FConfigGrid.Cells[GRID_COL_STATUS, 0] := 'Status';
  FConfigGrid.Cells[GRID_COL_CALLS, 0] := 'Calls';
  FConfigGrid.Cells[GRID_COL_TOKENS, 0] := 'Tokens';
  FConfigGrid.Cells[GRID_COL_COST, 0] := 'Cost';
  FConfigGrid.Cells[GRID_COL_DEFAULT, 0] := 'Default';
  
  AdjustGridColumns;
end;

procedure TLLMConfigForm.Initialize(AConnection: TFDConnection; ALLM: TDeepBaseLLM);
begin
  FConnection := AConnection;
  
  if Assigned(ALLM) then
  begin
    FLLM := ALLM;
    FOwnsLLM := False;
  end
  else if Assigned(FConnection) then
  begin
    FLLM := TDeepBaseLLM.Create(FConnection);
    FOwnsLLM := True;
  end;
  
  RefreshData;
end;

procedure TLLMConfigForm.RefreshData;
begin
  LoadConfigList;
  RefreshGrid;
  UpdateUsageStats;
  
  if FCboConfigName.Items.Count > 0 then
  begin
    if FCboConfigName.ItemIndex < 0 then
      FCboConfigName.ItemIndex := 0;
    LoadConfig(FCboConfigName.Text);
  end
  else
    BtnNewConfigClick(nil);
end;

procedure TLLMConfigForm.LoadProviders;
var
  I: Integer;
begin
  FCboProvider.Items.Clear;
  for I := Low(PROVIDERS) to High(PROVIDERS) do
    FCboProvider.Items.Add(PROVIDERS[I]);
  FCboProvider.ItemIndex := 0;
end;

procedure TLLMConfigForm.LoadConfigList;
var
  Configs: TLLMConfigArray;
  I: Integer;
begin
  FCboConfigName.Items.Clear;
  
  if Assigned(FLLM) then
  begin
    Configs := FLLM.GetAllConfigs;
    for I := 0 to High(Configs) do
      FCboConfigName.Items.Add(Configs[I].Name);
  end;
  
  if FCboConfigName.Items.Count = 0 then
    FCboConfigName.Items.Add('default');
    
  FCboConfigName.ItemIndex := 0;
end;

procedure TLLMConfigForm.LoadConfig(const ConfigName: string);
begin
  if not Assigned(FLLM) then Exit;
  
  FCurrentConfig := FLLM.GetConfig(ConfigName);
  
  case FCurrentConfig.Provider of
    lpOpenAI:    FCboProvider.ItemIndex := 0;
    lpAnthropic: FCboProvider.ItemIndex := 1;
    lpAzure:     FCboProvider.ItemIndex := 2;
    lpLiteLLM:   FCboProvider.ItemIndex := 3;
    lpOllama:    FCboProvider.ItemIndex := 4;
    lpCustom:    FCboProvider.ItemIndex := 5;
  else
    FCboProvider.ItemIndex := 0;
  end;
    
  FEdtModel.Text := FCurrentConfig.Model;
  FEdtApiUrl.Text := FCurrentConfig.BaseUrl;
  FEdtApiKey.Text := FCurrentConfig.ApiKey;
  FEdtTemperature.Text := FormatFloat('0.0', FCurrentConfig.Temperature);
  FTrkTemperature.Position := Round(FCurrentConfig.Temperature * 10);
  FEdtMaxTokens.Text := IntToStr(FCurrentConfig.MaxTokens);
  FEdtTimeout.Text := '60000';
  FEdtInputPrice.Text := FormatFloat('0.00000', FCurrentConfig.InputTokenPrice);
  FEdtOutputPrice.Text := FormatFloat('0.00000', FCurrentConfig.OutputTokenPrice);
  FChkIsDefault.Checked := FCurrentConfig.IsDefault;
  FChkIsEnabled.Checked := FCurrentConfig.IsEnabled;
  
  FModified := False;
  SetStatus(Format('Loaded configuration "%s"', [ConfigName]));
end;

procedure TLLMConfigForm.SaveConfig;
begin
  if not Assigned(FLLM) then Exit;
  
  FCurrentConfig.Name := FCboConfigName.Text;
  case FCboProvider.ItemIndex of
    0: FCurrentConfig.Provider := lpOpenAI;
    1: FCurrentConfig.Provider := lpAnthropic;
    2: FCurrentConfig.Provider := lpAzure;
    3: FCurrentConfig.Provider := lpLiteLLM;
    4: FCurrentConfig.Provider := lpOllama;
    5: FCurrentConfig.Provider := lpCustom;
  else
    FCurrentConfig.Provider := lpOpenAI;
  end;
  FCurrentConfig.Model := FEdtModel.Text;
  FCurrentConfig.BaseUrl := FEdtApiUrl.Text;
  FCurrentConfig.ApiKey := FEdtApiKey.Text;
  FCurrentConfig.Temperature := StrToFloatDef(FEdtTemperature.Text, 0.7);
  FCurrentConfig.MaxTokens := StrToIntDef(FEdtMaxTokens.Text, 4096);
  FCurrentConfig.InputTokenPrice := StrToFloatDef(FEdtInputPrice.Text, 0.0);
  FCurrentConfig.OutputTokenPrice := StrToFloatDef(FEdtOutputPrice.Text, 0.0);
  FCurrentConfig.IsDefault := FChkIsDefault.Checked;
  FCurrentConfig.IsEnabled := FChkIsEnabled.Checked;
  
  // Validation
  if FCurrentConfig.Name = '' then
  begin
    MessageDlg('Config Name cannot be empty.', mtError, [mbOK], 0);
    Exit;
  end;
  
  if (FCurrentConfig.Provider <> lpOllama) and (FCurrentConfig.ApiKey = '') then
  begin
    if MessageDlg('API Key is empty. Continue saving?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      Exit;
  end;
  
  FLLM.SaveConfig(FCurrentConfig);
  FLLM.RefreshConfigCache;
  FModified := False;
  
  SetStatus(Format('Configuration "%s" saved successfully', [FCurrentConfig.Name]));
  RefreshGrid;
  
  // Update combo if new name
  if FCboConfigName.Items.IndexOf(FCurrentConfig.Name) < 0 then
  begin
    FCboConfigName.Items.Add(FCurrentConfig.Name);
    FCboConfigName.ItemIndex := FCboConfigName.Items.IndexOf(FCurrentConfig.Name);
  end;
end;

procedure TLLMConfigForm.RefreshGrid;
var
  Configs: TLLMConfigArray;
  I, Row: Integer;
begin
  FConfigGrid.RowCount := 2;
  FConfigGrid.Rows[1].Clear;
  
  if not Assigned(FLLM) then Exit;
  
  Configs := FLLM.GetAllConfigs;
  if Length(Configs) = 0 then
  begin
    FConfigGrid.Cells[GRID_COL_NAME, 1] := '(No configurations)';
    Exit;
  end;
  
  FConfigGrid.RowCount := Length(Configs) + 1;
  
  for I := 0 to High(Configs) do
  begin
    Row := I + 1;
    FConfigGrid.Cells[GRID_COL_NAME, Row] := Configs[I].Name;
    FConfigGrid.Cells[GRID_COL_PROVIDER, Row] := Configs[I].ProviderToStr;
    FConfigGrid.Cells[GRID_COL_MODEL, Row] := Configs[I].Model;
    
    if Configs[I].IsEnabled then
      FConfigGrid.Cells[GRID_COL_STATUS, Row] := 'Enabled'
    else
      FConfigGrid.Cells[GRID_COL_STATUS, Row] := 'Disabled';
      
    FConfigGrid.Cells[GRID_COL_CALLS, Row] := '-';
    FConfigGrid.Cells[GRID_COL_TOKENS, Row] := IntToStr(Configs[I].MaxTokens);
    FConfigGrid.Cells[GRID_COL_COST, Row] := Format('$%.4f', [Configs[I].InputTokenPrice]);
    
    if Configs[I].IsDefault then
      FConfigGrid.Cells[GRID_COL_DEFAULT, Row] := '*'
    else
      FConfigGrid.Cells[GRID_COL_DEFAULT, Row] := '';
  end;
  
  AdjustGridColumns;
end;

procedure TLLMConfigForm.UpdateUsageStats;
begin
  if not Assigned(FLLM) then Exit;
  FLblUsageStats.Caption := 'Configured Models: ' + IntToStr(Length(FLLM.GetAllConfigs));
end;

procedure TLLMConfigForm.CboConfigNameChange(Sender: TObject);
begin
  if FCboConfigName.ItemIndex >= 0 then
    LoadConfig(FCboConfigName.Text);
end;

procedure TLLMConfigForm.CboProviderChange(Sender: TObject);
begin
  UpdateProviderDefaults;
  FModified := True;
end;

procedure TLLMConfigForm.BtnNewConfigClick(Sender: TObject);
var
  NewName: string;
begin
  NewName := InputBox('New Configuration', 'Enter configuration name:', '');
  if NewName = '' then Exit;
  
  if FCboConfigName.Items.IndexOf(NewName) >= 0 then
  begin
    MessageDlg('A configuration with this name already exists.', mtError, [mbOK], 0);
    Exit;
  end;
  
  FCboConfigName.Items.Add(NewName);
  FCboConfigName.ItemIndex := FCboConfigName.Items.IndexOf(NewName);
  
  // Reset to defaults
  FCurrentConfig.Init;
  FCurrentConfig.Name := NewName;
  FCurrentConfig.Provider := lpOpenAI;
  FCurrentConfig.Model := 'gpt-4o-mini';
  FCurrentConfig.BaseUrl := 'https://api.openai.com/v1';
  FCurrentConfig.Temperature := 0.7;
  FCurrentConfig.MaxTokens := 4096;
  
  LoadConfig(NewName);
  FModified := True;
end;

procedure TLLMConfigForm.BtnDeleteConfigClick(Sender: TObject);
var
  ConfigName: string;
begin
  ConfigName := FCboConfigName.Text;
  if ConfigName = '' then Exit;
  
  if MessageDlg(Format('Delete configuration "%s"?', [ConfigName]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
    
  if Assigned(FLLM) then
    FLLM.DeleteConfig(ConfigName);
    
  FCboConfigName.Items.Delete(FCboConfigName.ItemIndex);
  if FCboConfigName.Items.Count > 0 then
  begin
    FCboConfigName.ItemIndex := 0;
    LoadConfig(FCboConfigName.Text);
  end;
  
  RefreshGrid;
  SetStatus(Format('Configuration "%s" deleted', [ConfigName]));
end;

procedure TLLMConfigForm.BtnSaveConfigClick(Sender: TObject);
begin
  SaveConfig;
end;

procedure TLLMConfigForm.BtnTestConnectionClick(Sender: TObject);
var
  Success: Boolean;
  ErrorMsg: string;
  DurationMs: Int64;
begin
  if not Assigned(FLLM) then Exit;
  
  SaveConfig;
  FBtnTestConnection.Enabled := False;
  SetStatus('Testing connection...');
  Screen.Cursor := crHourGlass;
  try
    Success := FLLM.TestConnection(FCboConfigName.Text, DurationMs, ErrorMsg);
    
    if Success then
    begin
      FLblTestStats.Caption := Format('Connection OK (%d ms)', [DurationMs]);
      FLblTestStats.Font.Color := clGreen;
      SetStatus('Connection test succeeded');
    end
    else
    begin
      FLblTestStats.Caption := Format('Failed: %s (%d ms)', [ErrorMsg, DurationMs]);
      FLblTestStats.Font.Color := clRed;
      SetStatus('Connection test failed: ' + ErrorMsg, True);
    end;
  finally
    FBtnTestConnection.Enabled := True;
    Screen.Cursor := crDefault;
  end;
end;

procedure TLLMConfigForm.BtnSendTestClick(Sender: TObject);
var
  Prompt: string;
  Response: TLLMChatResponse;
begin
  if not Assigned(FLLM) then Exit;
  
  Prompt := Trim(FMmoTestPrompt.Text);
  if Prompt = '' then
  begin
    MessageDlg('Please enter a test prompt.', mtWarning, [mbOK], 0);
    Exit;
  end;
  
  FBtnSendTest.Enabled := False;
  SetStatus('Sending request...');
  FMmoTestResponse.Clear;
  
  try
    if FLLM.Chat(Prompt, Response, FCboConfigName.Text) then
    begin
      FMmoTestResponse.Text := Response.Content;
      FLblTestStats.Caption := Format(
        'Tokens: %d in, %d out | Time: %d ms',
        [Response.InputTokens, Response.OutputTokens, Response.DurationMs]
      );
      SetStatus('Request completed successfully');
    end
    else
    begin
      FMmoTestResponse.Lines.Add('ERROR: ' + Response.ErrorMessage);
      FLblTestStats.Caption := Format('Failed after %d ms', [Response.DurationMs]);
      SetStatus('Request failed', True);
    end;
  finally
    FBtnSendTest.Enabled := True;
  end;
  
  RefreshGrid;
  UpdateUsageStats;
end;

procedure TLLMConfigForm.TrkTemperatureChange(Sender: TObject);
begin
  FEdtTemperature.Text := FormatFloat('0.0', FTrkTemperature.Position / 10);
  FModified := True;
end;

procedure TLLMConfigForm.EdtTemperatureChange(Sender: TObject);
var
  V: Double;
begin
  V := StrToFloatDef(FEdtTemperature.Text, 0.7);
  if (V >= 0) and (V <= 2) then
    FTrkTemperature.Position := Round(V * 10);
  FModified := True;
end;

procedure TLLMConfigForm.ChkShowKeyClick(Sender: TObject);
begin
  if FChkShowKey.Checked then
    FEdtApiKey.PasswordChar := #0
  else
    FEdtApiKey.PasswordChar := '*';
end;

procedure TLLMConfigForm.ConfigGridSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
var
  ConfigName: string;
begin
  CanSelect := True;
  
  if (ARow > 0) and (ARow < FConfigGrid.RowCount) then
  begin
    ConfigName := FConfigGrid.Cells[GRID_COL_NAME, ARow];
    if (ConfigName <> '') and (ConfigName <> '(No configurations)') then
    begin
      FCboConfigName.ItemIndex := FCboConfigName.Items.IndexOf(ConfigName);
      if FCboConfigName.ItemIndex >= 0 then
        LoadConfig(ConfigName);
    end;
  end;
end;

procedure TLLMConfigForm.ConfigGridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
var
  Grid: TStringGrid;
  S: string;
begin
  Grid := TStringGrid(Sender);
  
  // Custom draw for Status column
  if (ARow > 0) and (ACol = GRID_COL_STATUS) then
  begin
    S := Grid.Cells[ACol, ARow];
    Grid.Canvas.FillRect(Rect);
    
    if S = 'Enabled' then
      Grid.Canvas.Font.Color := clGreen
    else if S = 'Disabled' then
      Grid.Canvas.Font.Color := clGray
    else
      Grid.Canvas.Font.Color := clBlack;
    
    Grid.Canvas.TextRect(Rect, Rect.Left + 4, Rect.Top + 4, S);
  end
  else if (ARow > 0) and (ACol = GRID_COL_DEFAULT) then
  begin
    S := Grid.Cells[ACol, ARow];
    Grid.Canvas.FillRect(Rect);
    if S = '*' then
    begin
      Grid.Canvas.Font.Color := clOlive;
      Grid.Canvas.Font.Size := 14;
      Grid.Canvas.TextRect(Rect, Rect.Left + 20, Rect.Top + 2, '*');
      Grid.Canvas.Font.Size := 8;
    end;
  end;
end;

procedure TLLMConfigForm.ContentChanged(Sender: TObject);
begin
  FModified := True;
end;

procedure TLLMConfigForm.SetStatus(const Text: string; IsError: Boolean);
begin
  FStatusBar.SimpleText := Text;
  if IsError then
    FStatusBar.Font.Color := clRed
  else
    FStatusBar.Font.Color := clWindowText;
end;

procedure TLLMConfigForm.UpdateProviderDefaults;
var
  Idx: Integer;
begin
  Idx := FCboProvider.ItemIndex;
  if (Idx >= 0) and (Idx <= High(DEFAULT_URLS)) then
  begin
    FEdtApiUrl.Text := DEFAULT_URLS[Idx];
    FEdtModel.Text := DEFAULT_MODELS[Idx];
  end;
end;

end.
