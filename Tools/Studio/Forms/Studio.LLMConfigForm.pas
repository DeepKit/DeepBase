{ ============================================================================
  Studio.LLMConfigForm - LLM Configuration Management Window
  
  Version: 1.0
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
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Grids,
  FireDAC.Comp.Client,
  UniBase.LLM;

type
  TConfigStatus = (csUnknown, csOnline, csOffline, csError);
  
  TLLMConfigForm = class(TForm)
  private
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
    FLLM: TUniBaseLLM;
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
    function GetConfigStatus(const ConfigName: string): TConfigStatus;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure Initialize(AConnection: TFDConnection; ALLM: TUniBaseLLM = nil);
    procedure RefreshData;
    
    property LLM: TUniBaseLLM read FLLM;
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
  Width := 1100;
  Height := 750;
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

procedure TLLMConfigForm.CreateControls;
begin
  // Status Bar
  FStatusBar := TStatusBar.Create(Self);
  FStatusBar.Parent := Self;
  FStatusBar.SimplePanel := True;
  FStatusBar.SimpleText := 'Ready';
  
  // List Panel (Bottom)
  CreateListPanel;
  
  // Editor Panel (Top Left)
  CreateEditorPanel;
  
  // Test Panel (Top Right)
  CreateTestPanel;
end;

procedure TLLMConfigForm.CreateEditorPanel;
var
  Y: Integer;
begin
  FEditorPanel := TPanel.Create(Self);
  FEditorPanel.Parent := Self;
  FEditorPanel.Align := alLeft;
  FEditorPanel.Width := 380;
  FEditorPanel.BevelOuter := bvNone;
  FEditorPanel.Caption := '';
  
  Y := 10;
  
  // Config Name
  FLblConfigName := TLabel.Create(Self);
  FLblConfigName.Parent := FEditorPanel;
  FLblConfigName.SetBounds(10, Y, 80, 16);
  FLblConfigName.Caption := 'Config Name:';
  
  FCboConfigName := TComboBox.Create(Self);
  FCboConfigName.Parent := FEditorPanel;
  FCboConfigName.SetBounds(100, Y - 4, 160, 24);
  FCboConfigName.Style := csDropDownList;
  FCboConfigName.OnChange := CboConfigNameChange;
  
  FBtnNewConfig := TButton.Create(Self);
  FBtnNewConfig.Parent := FEditorPanel;
  FBtnNewConfig.SetBounds(270, Y - 5, 50, 24);
  FBtnNewConfig.Caption := 'New';
  FBtnNewConfig.OnClick := BtnNewConfigClick;
  
  FBtnDeleteConfig := TButton.Create(Self);
  FBtnDeleteConfig.Parent := FEditorPanel;
  FBtnDeleteConfig.SetBounds(325, Y - 5, 45, 24);
  FBtnDeleteConfig.Caption := 'Del';
  FBtnDeleteConfig.OnClick := BtnDeleteConfigClick;
  
  Inc(Y, 35);
  
  // Provider
  FLblProvider := TLabel.Create(Self);
  FLblProvider.Parent := FEditorPanel;
  FLblProvider.SetBounds(10, Y, 80, 16);
  FLblProvider.Caption := 'Provider:';
  
  FCboProvider := TComboBox.Create(Self);
  FCboProvider.Parent := FEditorPanel;
  FCboProvider.SetBounds(100, Y - 4, 160, 24);
  FCboProvider.Style := csDropDownList;
  FCboProvider.OnChange := CboProviderChange;
  
  Inc(Y, 35);
  
  // Model
  FLblModel := TLabel.Create(Self);
  FLblModel.Parent := FEditorPanel;
  FLblModel.SetBounds(10, Y, 80, 16);
  FLblModel.Caption := 'Model:';
  
  FEdtModel := TEdit.Create(Self);
  FEdtModel.Parent := FEditorPanel;
  FEdtModel.SetBounds(100, Y - 4, 260, 24);
  FEdtModel.OnChange := ContentChanged;
  
  Inc(Y, 35);
  
  // API URL
  FLblApiUrl := TLabel.Create(Self);
  FLblApiUrl.Parent := FEditorPanel;
  FLblApiUrl.SetBounds(10, Y, 80, 16);
  FLblApiUrl.Caption := 'API URL:';
  
  FEdtApiUrl := TEdit.Create(Self);
  FEdtApiUrl.Parent := FEditorPanel;
  FEdtApiUrl.SetBounds(100, Y - 4, 260, 24);
  FEdtApiUrl.OnChange := ContentChanged;
  
  Inc(Y, 35);
  
  // API Key
  FLblApiKey := TLabel.Create(Self);
  FLblApiKey.Parent := FEditorPanel;
  FLblApiKey.SetBounds(10, Y, 80, 16);
  FLblApiKey.Caption := 'API Key:';
  
  FEdtApiKey := TEdit.Create(Self);
  FEdtApiKey.Parent := FEditorPanel;
  FEdtApiKey.SetBounds(100, Y - 4, 200, 24);
  FEdtApiKey.PasswordChar := '*';
  FEdtApiKey.OnChange := ContentChanged;
  
  FChkShowKey := TCheckBox.Create(Self);
  FChkShowKey.Parent := FEditorPanel;
  FChkShowKey.SetBounds(310, Y - 2, 60, 20);
  FChkShowKey.Caption := 'Show';
  FChkShowKey.OnClick := ChkShowKeyClick;
  
  Inc(Y, 35);
  
  // Temperature
  FLblTemperature := TLabel.Create(Self);
  FLblTemperature.Parent := FEditorPanel;
  FLblTemperature.SetBounds(10, Y, 80, 16);
  FLblTemperature.Caption := 'Temperature:';
  
  FEdtTemperature := TEdit.Create(Self);
  FEdtTemperature.Parent := FEditorPanel;
  FEdtTemperature.SetBounds(100, Y - 4, 50, 24);
  FEdtTemperature.Text := '0.7';
  FEdtTemperature.OnChange := EdtTemperatureChange;
  
  FTrkTemperature := TTrackBar.Create(Self);
  FTrkTemperature.Parent := FEditorPanel;
  FTrkTemperature.SetBounds(155, Y - 6, 200, 30);
  FTrkTemperature.Min := 0;
  FTrkTemperature.Max := 20;
  FTrkTemperature.Position := 7;
  FTrkTemperature.TickStyle := tsNone;
  FTrkTemperature.OnChange := TrkTemperatureChange;
  
  Inc(Y, 35);
  
  // Max Tokens
  FLblMaxTokens := TLabel.Create(Self);
  FLblMaxTokens.Parent := FEditorPanel;
  FLblMaxTokens.SetBounds(10, Y, 80, 16);
  FLblMaxTokens.Caption := 'Max Tokens:';
  
  FEdtMaxTokens := TEdit.Create(Self);
  FEdtMaxTokens.Parent := FEditorPanel;
  FEdtMaxTokens.SetBounds(100, Y - 4, 80, 24);
  FEdtMaxTokens.Text := '4096';
  FEdtMaxTokens.OnChange := ContentChanged;
  
  // Timeout
  FLblTimeout := TLabel.Create(Self);
  FLblTimeout.Parent := FEditorPanel;
  FLblTimeout.SetBounds(200, Y, 60, 16);
  FLblTimeout.Caption := 'Timeout:';
  
  FEdtTimeout := TEdit.Create(Self);
  FEdtTimeout.Parent := FEditorPanel;
  FEdtTimeout.SetBounds(265, Y - 4, 60, 24);
  FEdtTimeout.Text := '60000';
  FEdtTimeout.OnChange := ContentChanged;
  
  Inc(Y, 35);
  
  // Input Price
  FLblInputPrice := TLabel.Create(Self);
  FLblInputPrice.Parent := FEditorPanel;
  FLblInputPrice.SetBounds(10, Y, 80, 16);
  FLblInputPrice.Caption := 'In Price/1K:';
  
  FEdtInputPrice := TEdit.Create(Self);
  FEdtInputPrice.Parent := FEditorPanel;
  FEdtInputPrice.SetBounds(100, Y - 4, 70, 24);
  FEdtInputPrice.Text := '0.00015';
  FEdtInputPrice.OnChange := ContentChanged;
  
  // Output Price
  FLblOutputPrice := TLabel.Create(Self);
  FLblOutputPrice.Parent := FEditorPanel;
  FLblOutputPrice.SetBounds(185, Y, 80, 16);
  FLblOutputPrice.Caption := 'Out Price/1K:';
  
  FEdtOutputPrice := TEdit.Create(Self);
  FEdtOutputPrice.Parent := FEditorPanel;
  FEdtOutputPrice.SetBounds(270, Y - 4, 70, 24);
  FEdtOutputPrice.Text := '0.0006';
  FEdtOutputPrice.OnChange := ContentChanged;
  
  Inc(Y, 40);
  
  // Checkboxes
  FChkIsDefault := TCheckBox.Create(Self);
  FChkIsDefault.Parent := FEditorPanel;
  FChkIsDefault.SetBounds(10, Y, 100, 20);
  FChkIsDefault.Caption := 'Is Default';
  FChkIsDefault.OnClick := ContentChanged;
  
  FChkIsEnabled := TCheckBox.Create(Self);
  FChkIsEnabled.Parent := FEditorPanel;
  FChkIsEnabled.SetBounds(120, Y, 100, 20);
  FChkIsEnabled.Caption := 'Enabled';
  FChkIsEnabled.Checked := True;
  FChkIsEnabled.OnClick := ContentChanged;
  
  Inc(Y, 35);
  
  // Save Button
  FBtnSaveConfig := TButton.Create(Self);
  FBtnSaveConfig.Parent := FEditorPanel;
  FBtnSaveConfig.SetBounds(10, Y, 100, 30);
  FBtnSaveConfig.Caption := 'Save Config';
  FBtnSaveConfig.Font.Style := [fsBold];
  FBtnSaveConfig.OnClick := BtnSaveConfigClick;
  
  LoadProviders;
end;

procedure TLLMConfigForm.CreateTestPanel;
begin
  FTestPanel := TPanel.Create(Self);
  FTestPanel.Parent := Self;
  FTestPanel.Align := alClient;
  FTestPanel.BevelOuter := bvNone;
  FTestPanel.Caption := '';
  
  // Test Prompt Label
  FLblTestPrompt := TLabel.Create(Self);
  FLblTestPrompt.Parent := FTestPanel;
  FLblTestPrompt.SetBounds(10, 10, 80, 16);
  FLblTestPrompt.Caption := 'Test Prompt:';
  
  // Test Prompt Memo
  FMmoTestPrompt := TMemo.Create(Self);
  FMmoTestPrompt.Parent := FTestPanel;
  FMmoTestPrompt.SetBounds(10, 28, 680, 80);
  FMmoTestPrompt.Anchors := [akLeft, akTop, akRight];
  FMmoTestPrompt.ScrollBars := ssVertical;
  FMmoTestPrompt.Text := 'Reply with exactly: OK';
  
  // Test Buttons
  FBtnTestConnection := TButton.Create(Self);
  FBtnTestConnection.Parent := FTestPanel;
  FBtnTestConnection.SetBounds(10, 115, 120, 28);
  FBtnTestConnection.Caption := 'Test Connection';
  FBtnTestConnection.OnClick := BtnTestConnectionClick;
  
  FBtnSendTest := TButton.Create(Self);
  FBtnSendTest.Parent := FTestPanel;
  FBtnSendTest.SetBounds(140, 115, 100, 28);
  FBtnSendTest.Caption := 'Send Test';
  FBtnSendTest.OnClick := BtnSendTestClick;
  
  // Test Stats
  FLblTestStats := TLabel.Create(Self);
  FLblTestStats.Parent := FTestPanel;
  FLblTestStats.SetBounds(260, 120, 400, 16);
  FLblTestStats.Caption := '';
  FLblTestStats.Font.Color := clGray;
  
  // Response Label
  FLblTestResponse := TLabel.Create(Self);
  FLblTestResponse.Parent := FTestPanel;
  FLblTestResponse.SetBounds(10, 150, 100, 16);
  FLblTestResponse.Caption := 'Response:';
  
  // Response Memo
  FMmoTestResponse := TMemo.Create(Self);
  FMmoTestResponse.Parent := FTestPanel;
  FMmoTestResponse.SetBounds(10, 168, 680, 190);
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
  FListPanel.Height := 350;
  FListPanel.BevelOuter := bvNone;
  FListPanel.Caption := '';
  
  // Usage Stats Label
  FLblUsageStats := TLabel.Create(Self);
  FLblUsageStats.Parent := FListPanel;
  FLblUsageStats.SetBounds(10, 5, 600, 16);
  FLblUsageStats.Caption := 'Last 30 days: 0 calls, 0 tokens, $0.0000 total cost';
  FLblUsageStats.Font.Style := [fsBold];
  
  // Config Grid
  FConfigGrid := TStringGrid.Create(Self);
  FConfigGrid.Parent := FListPanel;
  FConfigGrid.SetBounds(10, 26, 1070, 310);
  FConfigGrid.Anchors := [akLeft, akTop, akRight, akBottom];
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
  
  // Column widths
  FConfigGrid.ColWidths[GRID_COL_NAME] := 120;
  FConfigGrid.ColWidths[GRID_COL_PROVIDER] := 100;
  FConfigGrid.ColWidths[GRID_COL_MODEL] := 180;
  FConfigGrid.ColWidths[GRID_COL_STATUS] := 80;
  FConfigGrid.ColWidths[GRID_COL_CALLS] := 70;
  FConfigGrid.ColWidths[GRID_COL_TOKENS] := 90;
  FConfigGrid.ColWidths[GRID_COL_COST] := 90;
  FConfigGrid.ColWidths[GRID_COL_DEFAULT] := 60;
end;

procedure TLLMConfigForm.Initialize(AConnection: TFDConnection; ALLM: TUniBaseLLM);
begin
  FConnection := AConnection;
  
  if Assigned(ALLM) then
  begin
    FLLM := ALLM;
    FOwnsLLM := False;
  end
  else if Assigned(FConnection) and FConnection.Connected then
  begin
    FLLM := TUniBaseLLM.Create(FConnection);
    FOwnsLLM := True;
  end;
  
  RefreshData;
end;

procedure TLLMConfigForm.RefreshData;
begin
  if not Assigned(FLLM) then
  begin
    SetStatus('No LLM - open database first', True);
    Exit;
  end;
  
  FLLM.RefreshConfigCache;
  LoadConfigList;
  RefreshGrid;
  UpdateUsageStats;
  
  if FCboConfigName.Items.Count > 0 then
    LoadConfig(FCboConfigName.Text);
    
  SetStatus('Data loaded');
end;

procedure TLLMConfigForm.LoadProviders;
var
  I: Integer;
begin
  FCboProvider.Items.Clear;
  for I := Low(PROVIDERS) to High(PROVIDERS) do
    FCboProvider.Items.Add(PROVIDERS[I]);
  FCboProvider.ItemIndex := 3; // Default to LiteLLM
end;

procedure TLLMConfigForm.LoadConfigList;
var
  Configs: TLLMConfigArray;
  I: Integer;
begin
  FCboConfigName.Items.Clear;
  
  if not Assigned(FLLM) then Exit;
  
  Configs := FLLM.GetAllConfigs;
  for I := 0 to High(Configs) do
    FCboConfigName.Items.Add(Configs[I].Name);
    
  if FCboConfigName.Items.Count = 0 then
    FCboConfigName.Items.Add('Default');
    
  FCboConfigName.ItemIndex := 0;
end;

procedure TLLMConfigForm.LoadConfig(const ConfigName: string);
begin
  if not Assigned(FLLM) then Exit;
  
  FCurrentConfig := FLLM.GetConfig(ConfigName);
  
  // Provider
  case FCurrentConfig.Provider of
    lpOpenAI:    FCboProvider.ItemIndex := 0;
    lpAnthropic: FCboProvider.ItemIndex := 1;
    lpAzure:     FCboProvider.ItemIndex := 2;
    lpLiteLLM:   FCboProvider.ItemIndex := 3;
    lpOllama:    FCboProvider.ItemIndex := 4;
    lpCustom:    FCboProvider.ItemIndex := 5;
  end;
  
  FEdtModel.Text := FCurrentConfig.Model;
  FEdtApiUrl.Text := FCurrentConfig.BaseUrl;
  FEdtApiKey.Text := FCurrentConfig.ApiKey;
  FEdtTemperature.Text := FormatFloat('0.0', FCurrentConfig.Temperature);
  FTrkTemperature.Position := Round(FCurrentConfig.Temperature * 10);
  FEdtMaxTokens.Text := IntToStr(FCurrentConfig.MaxTokens);
  FEdtInputPrice.Text := FormatFloat('0.00000', FCurrentConfig.InputTokenPrice);
  FEdtOutputPrice.Text := FormatFloat('0.00000', FCurrentConfig.OutputTokenPrice);
  FChkIsDefault.Checked := FCurrentConfig.IsDefault;
  FChkIsEnabled.Checked := FCurrentConfig.IsEnabled;
  
  FModified := False;
  SetStatus('Loaded: ' + ConfigName);
end;

procedure TLLMConfigForm.SaveConfig;
var
  Config: TLLMConfig;
begin
  if not Assigned(FLLM) then
  begin
    SetStatus('No LLM manager', True);
    Exit;
  end;
  
  Config.Init;
  Config.Name := FCboConfigName.Text;
  
  case FCboProvider.ItemIndex of
    0: Config.Provider := lpOpenAI;
    1: Config.Provider := lpAnthropic;
    2: Config.Provider := lpAzure;
    3: Config.Provider := lpLiteLLM;
    4: Config.Provider := lpOllama;
    5: Config.Provider := lpCustom;
  end;
  
  Config.Model := FEdtModel.Text;
  Config.BaseUrl := FEdtApiUrl.Text;
  Config.ApiKey := FEdtApiKey.Text;
  Config.Temperature := StrToFloatDef(FEdtTemperature.Text, 0.7);
  Config.MaxTokens := StrToIntDef(FEdtMaxTokens.Text, 4096);
  Config.InputTokenPrice := StrToFloatDef(FEdtInputPrice.Text, 0);
  Config.OutputTokenPrice := StrToFloatDef(FEdtOutputPrice.Text, 0);
  Config.IsDefault := FChkIsDefault.Checked;
  Config.IsEnabled := FChkIsEnabled.Checked;
  
  FLLM.SaveConfig(Config);
  FCurrentConfig := Config;
  FModified := False;
  
  RefreshGrid;
  LoadConfigList;
  
  // Reselect
  FCboConfigName.ItemIndex := FCboConfigName.Items.IndexOf(Config.Name);
  
  SetStatus('Config saved: ' + Config.Name);
end;

procedure TLLMConfigForm.RefreshGrid;
var
  Configs: TLLMConfigArray;
  I: Integer;
  TotalCalls, TotalTokens: Integer;
  TotalCost: Double;
begin
  if not Assigned(FLLM) then Exit;
  
  Configs := FLLM.GetAllConfigs;
  FConfigGrid.RowCount := Max(2, Length(Configs) + 1);
  
  // Clear grid
  for I := 1 to FConfigGrid.RowCount - 1 do
  begin
    FConfigGrid.Rows[I].Clear;
  end;
  
  for I := 0 to High(Configs) do
  begin
    FConfigGrid.Cells[GRID_COL_NAME, I + 1] := Configs[I].Name;
    FConfigGrid.Cells[GRID_COL_PROVIDER, I + 1] := Configs[I].ProviderToStr;
    FConfigGrid.Cells[GRID_COL_MODEL, I + 1] := Configs[I].Model;
    
    // Status - simplified
    if Configs[I].IsEnabled then
      FConfigGrid.Cells[GRID_COL_STATUS, I + 1] := 'Enabled'
    else
      FConfigGrid.Cells[GRID_COL_STATUS, I + 1] := 'Disabled';
    
    // Get usage stats
    FLLM.GetUsageStats(Configs[I].Name, 30, TotalCalls, TotalTokens, TotalCost);
    FConfigGrid.Cells[GRID_COL_CALLS, I + 1] := IntToStr(TotalCalls);
    FConfigGrid.Cells[GRID_COL_TOKENS, I + 1] := IntToStr(TotalTokens);
    FConfigGrid.Cells[GRID_COL_COST, I + 1] := FormatFloat('$0.0000', TotalCost);
    
    if Configs[I].IsDefault then
      FConfigGrid.Cells[GRID_COL_DEFAULT, I + 1] := '★'
    else
      FConfigGrid.Cells[GRID_COL_DEFAULT, I + 1] := '';
  end;
  
  if Length(Configs) = 0 then
    FConfigGrid.Cells[GRID_COL_NAME, 1] := '(No configurations)';
end;

procedure TLLMConfigForm.UpdateUsageStats;
var
  TotalCalls, TotalTokens: Integer;
  TotalCost: Double;
begin
  if not Assigned(FLLM) then Exit;
  
  FLLM.GetUsageStats('', 30, TotalCalls, TotalTokens, TotalCost);
  FLblUsageStats.Caption := Format('Last 30 days: %d calls, %d tokens, $%.4f total cost',
    [TotalCalls, TotalTokens, TotalCost]);
end;

// === Event Handlers ===

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
  
  FCboConfigName.Items.Add(NewName);
  FCboConfigName.ItemIndex := FCboConfigName.Items.IndexOf(NewName);
  
  // Reset to defaults
  FCboProvider.ItemIndex := 3; // LiteLLM
  UpdateProviderDefaults;
  FEdtApiKey.Clear;
  FEdtMaxTokens.Text := '4096';
  FEdtTemperature.Text := '0.7';
  FTrkTemperature.Position := 7;
  FChkIsDefault.Checked := False;
  FChkIsEnabled.Checked := True;
  
  FModified := True;
  SetStatus('New config: ' + NewName + ' (not saved)');
end;

procedure TLLMConfigForm.BtnDeleteConfigClick(Sender: TObject);
var
  ConfigName: string;
begin
  if not Assigned(FLLM) then Exit;
  
  ConfigName := FCboConfigName.Text;
  if ConfigName = '' then Exit;
  
  if MessageDlg(Format('Delete configuration "%s"?', [ConfigName]), 
     mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  
  FLLM.DeleteConfig(ConfigName);
  LoadConfigList;
  RefreshGrid;
  
  if FCboConfigName.Items.Count > 0 then
    LoadConfig(FCboConfigName.Text);
    
  SetStatus('Config deleted: ' + ConfigName);
end;

procedure TLLMConfigForm.BtnSaveConfigClick(Sender: TObject);
begin
  SaveConfig;
end;

procedure TLLMConfigForm.BtnTestConnectionClick(Sender: TObject);
var
  DurationMs: Int64;
  ErrorMsg: string;
begin
  if not Assigned(FLLM) then
  begin
    SetStatus('No LLM manager', True);
    Exit;
  end;
  
  // Save first
  if FModified then
    SaveConfig;
  
  SetStatus('Testing connection...');
  FMmoTestResponse.Clear;
  FBtnTestConnection.Enabled := False;
  Application.ProcessMessages;
  
  try
    if FLLM.TestConnection(FCboConfigName.Text, DurationMs, ErrorMsg) then
    begin
      FMmoTestResponse.Lines.Add('✓ Connection successful!');
      FLblTestStats.Caption := Format('Response time: %d ms', [DurationMs]);
      SetStatus('Connection OK');
    end
    else
    begin
      FMmoTestResponse.Lines.Add('✗ Connection failed:');
      FMmoTestResponse.Lines.Add(ErrorMsg);
      FLblTestStats.Caption := Format('Failed after %d ms', [DurationMs]);
      SetStatus('Connection failed', True);
    end;
  finally
    FBtnTestConnection.Enabled := True;
  end;
  
  RefreshGrid;
end;

procedure TLLMConfigForm.BtnSendTestClick(Sender: TObject);
var
  Response: TLLMChatResponse;
  Prompt: string;
begin
  if not Assigned(FLLM) then
  begin
    SetStatus('No LLM manager', True);
    Exit;
  end;
  
  Prompt := FMmoTestPrompt.Text;
  if Prompt = '' then
  begin
    SetStatus('Enter a test prompt', True);
    Exit;
  end;
  
  // Save first
  if FModified then
    SaveConfig;
  
  SetStatus('Sending...');
  FMmoTestResponse.Clear;
  FBtnSendTest.Enabled := False;
  Application.ProcessMessages;
  
  try
    if FLLM.Chat(Prompt, Response, FCboConfigName.Text) then
    begin
      FMmoTestResponse.Text := Response.Content;
      FLblTestStats.Caption := Format('Tokens: %d in / %d out | Time: %d ms | Finish: %s',
        [Response.InputTokens, Response.OutputTokens, Response.DurationMs, Response.FinishReason]);
      SetStatus('Response received');
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
    // Draw star for default
    S := Grid.Cells[ACol, ARow];
    Grid.Canvas.FillRect(Rect);
    if S = '★' then
    begin
      Grid.Canvas.Font.Color := clYellow;
      Grid.Canvas.Font.Size := 14;
      Grid.Canvas.TextRect(Rect, Rect.Left + 20, Rect.Top + 2, '★');
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

function TLLMConfigForm.GetConfigStatus(const ConfigName: string): TConfigStatus;
begin
  // Simplified - real implementation would check last test result
  Result := csUnknown;
end;

end.
