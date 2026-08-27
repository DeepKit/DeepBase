{ ============================================================================
  Studio.LLMFrame - LLM Management and Testing Frame
  
  Version: 1.0
  Description: Provides LLM configuration, testing and chat interface
  Features:
    - Provider configuration (LiteLLM/OpenAI/Anthropic/etc.)
    - Connection testing
    - Interactive chat interface
    - Call hiDeepStory viewer
    - Usage statistics
  ============================================================================ }

unit Studio.LLMFrame;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.DateUtils,
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
  DeepBase.LLM.Types,
  DeepBase.LLM;

type
  TfraLLM = class(TFrame)
    pgcMain: TPageControl;
    tabConfig: TTabSheet;
    tabChat: TTabSheet;
    tabHistory: TTabSheet;
    
    { Config Tab }
    pnlConfigTop: TPanel;
    lblProvider: TLabel;
    cboProvider: TComboBox;
    lblBaseUrl: TLabel;
    edtBaseUrl: TEdit;
    lblApiKey: TLabel;
    edtApiKey: TEdit;
    lblModel: TLabel;
    edtModel: TEdit;
    lblMaxTokens: TLabel;
    edtMaxTokens: TEdit;
    lblTemperature: TLabel;
    edtTemperature: TEdit;
    lblConfigName: TLabel;
    cboConfigName: TComboBox;
    btnTestConnection: TButton;
    btnSaveConfig: TButton;
    btnNewConfig: TButton;
    { Advanced tools buttons }
    btnOpenConfigManager: TButton;
    btnOpenPromptDebug: TButton;
    pnlConfigStatus: TPanel;
    lblStatus: TLabel;
    
    { Chat Tab }
    pnlChatTop: TPanel;
    lblChatConfig: TLabel;
    cboChatConfig: TComboBox;
    mmoChat: TMemo;
    pnlChatInput: TPanel;
    mmoInput: TMemo;
    btnSend: TButton;
    btnClear: TButton;
    
    { History Tab }
    pnlHistoryTop: TPanel;
    lblHistoryFilter: TLabel;
    cboHistoryConfig: TComboBox;
    btnRefreshHistory: TButton;
    btnClearHistory: TButton;
    lblStats: TLabel;
    grdHistory: TStringGrid;
    
    procedure cboProviderChange(Sender: TObject);
    procedure btnTestConnectionClick(Sender: TObject);
    procedure btnSaveConfigClick(Sender: TObject);
    procedure btnNewConfigClick(Sender: TObject);
    procedure cboConfigNameChange(Sender: TObject);
    procedure btnSendClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnRefreshHistoryClick(Sender: TObject);
    procedure btnClearHistoryClick(Sender: TObject);
    procedure mmoInputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnOpenConfigManagerClick(Sender: TObject);
    procedure btnOpenPromptDebugClick(Sender: TObject);
    
  private
    FConnection: TFDConnection;
    FLLM: TDeepBaseLLM;
    FOwnsLLM: Boolean;
    
    procedure CreateControls;
    procedure LoadProviders;
    procedure LoadConfigList;
    procedure LoadConfig(const ConfigName: string);
    procedure SaveConfig;
    procedure UpdateProviderDefaults;
    procedure SetStatus(const Text: string; IsError: Boolean = False);
    procedure LoadHistory;
    procedure UpdateStats;
    procedure DoChat;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure SetConnection(AConnection: TFDConnection);
    procedure RefreshData;
    
    property LLM: TDeepBaseLLM read FLLM;
  end;

implementation

uses
  Studio.LLMConfigForm,
  Studio.PromptDebugForm;

{$R *.dfm}

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

{ TfraLLM }

constructor TfraLLM.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FOwnsLLM := False;
  CreateControls;
end;

destructor TfraLLM.Destroy;
begin
  // Clear all event handlers to prevent access violations during destruction
  if Assigned(cboConfigName) then cboConfigName.OnChange := nil;
  if Assigned(cboProvider) then cboProvider.OnChange := nil;
  if Assigned(btnNewConfig) then btnNewConfig.OnClick := nil;
  if Assigned(btnTestConnection) then btnTestConnection.OnClick := nil;
  if Assigned(btnSaveConfig) then btnSaveConfig.OnClick := nil;
  if Assigned(btnSend) then btnSend.OnClick := nil;
  if Assigned(btnClear) then btnClear.OnClick := nil;
  if Assigned(btnRefreshHistory) then btnRefreshHistory.OnClick := nil;
  if Assigned(btnClearHistory) then btnClearHistory.OnClick := nil;
  if Assigned(btnOpenConfigManager) then btnOpenConfigManager.OnClick := nil;
  if Assigned(btnOpenPromptDebug) then btnOpenPromptDebug.OnClick := nil;
  if Assigned(mmoInput) then mmoInput.OnKeyDown := nil;
  
  // Safely release LLM manager
  if FOwnsLLM and Assigned(FLLM) then
  begin
    FLLM.Free;
    FLLM := nil;
    FOwnsLLM := False;
  end;
  inherited;
end;

procedure TfraLLM.CreateControls;
begin
  // PageControl setup
  pgcMain := TPageControl.Create(Self);
  pgcMain.Parent := Self;
  pgcMain.Align := alClient;
  
  // === Config Tab ===
  tabConfig := TTabSheet.Create(pgcMain);
  tabConfig.PageControl := pgcMain;
  tabConfig.Caption := 'Configuration';
  
  pnlConfigTop := TPanel.Create(Self);
  pnlConfigTop.Parent := tabConfig;
  pnlConfigTop.Align := alClient;
  pnlConfigTop.BevelOuter := bvNone;
  
  // Config Name
  lblConfigName := TLabel.Create(Self);
  lblConfigName.Parent := pnlConfigTop;
  lblConfigName.SetBounds(16, 18, 85, 16);
  lblConfigName.Caption := 'Config Name:';
  
  cboConfigName := TComboBox.Create(Self);
  cboConfigName.Parent := pnlConfigTop;
  cboConfigName.SetBounds(110, 14, 180, 24);
  cboConfigName.Style := csDropDownList;
  cboConfigName.OnChange := cboConfigNameChange;
  
  btnNewConfig := TButton.Create(Self);
  btnNewConfig.Parent := pnlConfigTop;
  btnNewConfig.SetBounds(300, 13, 75, 26);
  btnNewConfig.Caption := 'New...';
  btnNewConfig.OnClick := btnNewConfigClick;
  
  // Provider
  lblProvider := TLabel.Create(Self);
  lblProvider.Parent := pnlConfigTop;
  lblProvider.SetBounds(16, 52, 85, 16);
  lblProvider.Caption := 'Provider:';
  
  cboProvider := TComboBox.Create(Self);
  cboProvider.Parent := pnlConfigTop;
  cboProvider.SetBounds(110, 48, 180, 24);
  cboProvider.Style := csDropDownList;
  cboProvider.OnChange := cboProviderChange;
  
  // Base URL
  lblBaseUrl := TLabel.Create(Self);
  lblBaseUrl.Parent := pnlConfigTop;
  lblBaseUrl.SetBounds(16, 86, 85, 16);
  lblBaseUrl.Caption := 'Base URL:';
  
  edtBaseUrl := TEdit.Create(Self);
  edtBaseUrl.Parent := pnlConfigTop;
  edtBaseUrl.SetBounds(110, 82, 420, 24);
  edtBaseUrl.Anchors := [akLeft, akTop, akRight];
  edtBaseUrl.Text := 'http://localhost:4000';
  
  // API Key
  lblApiKey := TLabel.Create(Self);
  lblApiKey.Parent := pnlConfigTop;
  lblApiKey.SetBounds(16, 120, 85, 16);
  lblApiKey.Caption := 'API Key:';
  
  edtApiKey := TEdit.Create(Self);
  edtApiKey.Parent := pnlConfigTop;
  edtApiKey.SetBounds(110, 116, 420, 24);
  edtApiKey.Anchors := [akLeft, akTop, akRight];
  edtApiKey.Text := '';
  // Use simple ASCII mask char for compatibility with all code pages
  edtApiKey.PasswordChar := '*';

  // Model
  lblModel := TLabel.Create(Self);
  lblModel.Parent := pnlConfigTop;
  lblModel.SetBounds(16, 154, 85, 16);
  lblModel.Caption := 'Model:';
  
  edtModel := TEdit.Create(Self);
  edtModel.Parent := pnlConfigTop;
  edtModel.SetBounds(110, 150, 240, 24);
  edtModel.Text := 'gpt-4o-mini';
  
  // Max Tokens
  lblMaxTokens := TLabel.Create(Self);
  lblMaxTokens.Parent := pnlConfigTop;
  lblMaxTokens.SetBounds(16, 188, 85, 16);
  lblMaxTokens.Caption := 'Max Tokens:';
  
  edtMaxTokens := TEdit.Create(Self);
  edtMaxTokens.Parent := pnlConfigTop;
  edtMaxTokens.SetBounds(110, 184, 80, 24);
  edtMaxTokens.Text := '4096';
  
  // Temperature
  lblTemperature := TLabel.Create(Self);
  lblTemperature.Parent := pnlConfigTop;
  lblTemperature.SetBounds(210, 188, 80, 16);
  lblTemperature.Caption := 'Temperature:';
  
  edtTemperature := TEdit.Create(Self);
  edtTemperature.Parent := pnlConfigTop;
  edtTemperature.SetBounds(295, 184, 60, 24);
  edtTemperature.Text := '0.7';
  
  // Row 1: Action Buttons (Test & Save)
  btnTestConnection := TButton.Create(Self);
  btnTestConnection.Parent := pnlConfigTop;
  btnTestConnection.SetBounds(16, 230, 130, 30);
  btnTestConnection.Caption := 'Test Connection';
  btnTestConnection.OnClick := btnTestConnectionClick;
  
  btnSaveConfig := TButton.Create(Self);
  btnSaveConfig.Parent := pnlConfigTop;
  btnSaveConfig.SetBounds(155, 230, 110, 30);
  btnSaveConfig.Caption := 'Save Config';
  btnSaveConfig.OnClick := btnSaveConfigClick;
  
  // Row 2: Advanced tools (Open Config Manager & Prompt Debugger)
  btnOpenConfigManager := TButton.Create(Self);
  btnOpenConfigManager.Parent := pnlConfigTop;
  btnOpenConfigManager.SetBounds(16, 270, 160, 30);
  btnOpenConfigManager.Caption := 'Open Config Manager...';
  btnOpenConfigManager.OnClick := btnOpenConfigManagerClick;
  
  btnOpenPromptDebug := TButton.Create(Self);
  btnOpenPromptDebug.Parent := pnlConfigTop;
  btnOpenPromptDebug.SetBounds(185, 270, 160, 30);
  btnOpenPromptDebug.Caption := 'Prompt Debugger...';
  btnOpenPromptDebug.OnClick := btnOpenPromptDebugClick;
  
  // Status Panel
  pnlConfigStatus := TPanel.Create(Self);
  pnlConfigStatus.Parent := pnlConfigTop;
  pnlConfigStatus.SetBounds(16, 315, 420, 30);
  pnlConfigStatus.Anchors := [akLeft, akTop, akRight];
  pnlConfigStatus.BevelOuter := bvLowered;
  pnlConfigStatus.Caption := '';
  
  lblStatus := TLabel.Create(Self);
  lblStatus.Parent := pnlConfigStatus;
  lblStatus.Align := alClient;
  lblStatus.Alignment := taCenter;
  lblStatus.Layout := tlCenter;
  lblStatus.Caption := 'Ready';
  
  // === Chat Tab ===
  tabChat := TTabSheet.Create(pgcMain);
  tabChat.PageControl := pgcMain;
  tabChat.Caption := 'Chat Test';
  
  pnlChatTop := TPanel.Create(Self);
  pnlChatTop.Parent := tabChat;
  pnlChatTop.Align := alTop;
  pnlChatTop.Height := 40;
  pnlChatTop.BevelOuter := bvNone;
  
  lblChatConfig := TLabel.Create(Self);
  lblChatConfig.Parent := pnlChatTop;
  lblChatConfig.SetBounds(10, 12, 50, 16);
  lblChatConfig.Caption := 'Config:';
  
  cboChatConfig := TComboBox.Create(Self);
  cboChatConfig.Parent := pnlChatTop;
  cboChatConfig.SetBounds(70, 8, 150, 24);
  cboChatConfig.Style := csDropDownList;
  
  btnClear := TButton.Create(Self);
  btnClear.Parent := pnlChatTop;
  btnClear.SetBounds(240, 7, 80, 26);
  btnClear.Caption := 'Clear Chat';
  btnClear.OnClick := btnClearClick;
  
  pnlChatInput := TPanel.Create(Self);
  pnlChatInput.Parent := tabChat;
  pnlChatInput.Align := alBottom;
  pnlChatInput.Height := 100;
  pnlChatInput.BevelOuter := bvNone;
  
  mmoInput := TMemo.Create(Self);
  mmoInput.Parent := pnlChatInput;
  mmoInput.Align := alClient;
  mmoInput.ScrollBars := ssVertical;
  mmoInput.OnKeyDown := mmoInputKeyDown;
  
  btnSend := TButton.Create(Self);
  btnSend.Parent := pnlChatInput;
  btnSend.Align := alRight;
  btnSend.Width := 80;
  btnSend.Caption := 'Send';
  btnSend.OnClick := btnSendClick;
  
  mmoChat := TMemo.Create(Self);
  mmoChat.Parent := tabChat;
  mmoChat.Align := alClient;
  mmoChat.ReadOnly := True;
  mmoChat.ScrollBars := ssBoth;
  mmoChat.Font.Name := 'Consolas';
  mmoChat.Font.Size := 10;
  
  // === History Tab ===
  tabHistory := TTabSheet.Create(pgcMain);
  tabHistory.PageControl := pgcMain;
  tabHistory.Caption := 'Call History';
  
  pnlHistoryTop := TPanel.Create(Self);
  pnlHistoryTop.Parent := tabHistory;
  pnlHistoryTop.Align := alTop;
  pnlHistoryTop.Height := 70;
  pnlHistoryTop.BevelOuter := bvNone;
  
  lblHistoryFilter := TLabel.Create(Self);
  lblHistoryFilter.Parent := pnlHistoryTop;
  lblHistoryFilter.SetBounds(10, 12, 40, 16);
  lblHistoryFilter.Caption := 'Filter:';
  
  cboHistoryConfig := TComboBox.Create(Self);
  cboHistoryConfig.Parent := pnlHistoryTop;
  cboHistoryConfig.SetBounds(60, 8, 150, 24);
  cboHistoryConfig.Style := csDropDownList;
  
  btnRefreshHistory := TButton.Create(Self);
  btnRefreshHistory.Parent := pnlHistoryTop;
  btnRefreshHistory.SetBounds(230, 7, 80, 26);
  btnRefreshHistory.Caption := 'Refresh';
  btnRefreshHistory.OnClick := btnRefreshHistoryClick;
  
  btnClearHistory := TButton.Create(Self);
  btnClearHistory.Parent := pnlHistoryTop;
  btnClearHistory.SetBounds(320, 7, 100, 26);
  btnClearHistory.Caption := 'Clear History';
  btnClearHistory.OnClick := btnClearHistoryClick;
  
  lblStats := TLabel.Create(Self);
  lblStats.Parent := pnlHistoryTop;
  lblStats.SetBounds(10, 45, 500, 16);
  lblStats.Caption := 'Statistics: -';
  
  grdHistory := TStringGrid.Create(Self);
  grdHistory.Parent := tabHistory;
  grdHistory.Align := alClient;
  grdHistory.RowCount := 2;
  grdHistory.ColCount := 6;
  grdHistory.FixedRows := 1;
  grdHistory.FixedCols := 0;
  grdHistory.Options := grdHistory.Options + [goRowSelect];
  grdHistory.DefaultRowHeight := 22;
  grdHistory.Cells[0, 0] := 'Time';
  grdHistory.Cells[1, 0] := 'Config';
  grdHistory.Cells[2, 0] := 'Model';
  grdHistory.Cells[3, 0] := 'Tokens';
  grdHistory.Cells[4, 0] := 'Cost';
  grdHistory.Cells[5, 0] := 'Status';
  grdHistory.ColWidths[0] := 130;
  grdHistory.ColWidths[1] := 80;
  grdHistory.ColWidths[2] := 120;
  grdHistory.ColWidths[3] := 60;
  grdHistory.ColWidths[4] := 70;
  grdHistory.ColWidths[5] := 150;
  
  // Load provider list
  LoadProviders;
end;

procedure TfraLLM.LoadProviders;
var
  I: Integer;
begin
  cboProvider.Items.Clear;
  for I := Low(PROVIDERS) to High(PROVIDERS) do
    cboProvider.Items.Add(PROVIDERS[I]);
  cboProvider.ItemIndex := 3; // Default to LiteLLM
  UpdateProviderDefaults;
end;

procedure TfraLLM.LoadConfigList;
var
  Configs: TLLMConfigArray;
  I: Integer;
begin
  cboConfigName.Items.Clear;
  cboChatConfig.Items.Clear;
  cboHistoryConfig.Items.Clear;
  
  cboHistoryConfig.Items.Add('(All)');
  
  if Assigned(FLLM) then
  begin
    Configs := FLLM.GetAllConfigs;
    for I := 0 to High(Configs) do
    begin
      cboConfigName.Items.Add(Configs[I].Name);
      cboChatConfig.Items.Add(Configs[I].Name);
      cboHistoryConfig.Items.Add(Configs[I].Name);
    end;
  end;
  
  // Add default if not present
  if cboConfigName.Items.IndexOf('Default') < 0 then
    cboConfigName.Items.Add('Default');
  if cboChatConfig.Items.IndexOf('Default') < 0 then
    cboChatConfig.Items.Add('Default');
  
  if cboConfigName.Items.Count > 0 then
    cboConfigName.ItemIndex := 0;
  if cboChatConfig.Items.Count > 0 then
    cboChatConfig.ItemIndex := 0;
  cboHistoryConfig.ItemIndex := 0;
end;

procedure TfraLLM.LoadConfig(const ConfigName: string);
var
  Config: TLLMConfig;
begin
  if not Assigned(FLLM) then Exit;
  
  Config := FLLM.GetConfig(ConfigName);
  
  // Provider
  case Config.Provider of
    lpOpenAI:    cboProvider.ItemIndex := 0;
    lpAnthropic: cboProvider.ItemIndex := 1;
    lpAzure:     cboProvider.ItemIndex := 2;
    lpLiteLLM:   cboProvider.ItemIndex := 3;
    lpOllama:    cboProvider.ItemIndex := 4;
    lpCustom:    cboProvider.ItemIndex := 5;
  end;
  
  edtBaseUrl.Text := Config.BaseUrl;
  edtApiKey.Text := Config.ApiKey;
  edtModel.Text := Config.Model;
  edtMaxTokens.Text := IntToStr(Config.MaxTokens);
  edtTemperature.Text := FormatFloat('0.0', Config.Temperature);
end;

procedure TfraLLM.SaveConfig;
var
  Config: TLLMConfig;
begin
  if not Assigned(FLLM) then
  begin
    SetStatus('No LLM manager available', True);
    Exit;
  end;
  
  Config.Init;
  Config.Name := cboConfigName.Text;
  
  case cboProvider.ItemIndex of
    0: Config.Provider := lpOpenAI;
    1: Config.Provider := lpAnthropic;
    2: Config.Provider := lpAzure;
    3: Config.Provider := lpLiteLLM;
    4: Config.Provider := lpOllama;
    5: Config.Provider := lpCustom;
  end;
  
  Config.BaseUrl := edtBaseUrl.Text;
  Config.ApiKey := edtApiKey.Text;
  Config.Model := edtModel.Text;
  Config.MaxTokens := StrToIntDef(edtMaxTokens.Text, 4096);
  Config.Temperature := StrToFloatDef(edtTemperature.Text, 0.7);
  Config.IsEnabled := True;
  
  FLLM.SaveConfig(Config);
  FLLM.RefreshConfigCache;
  
  SetStatus('Configuration saved: ' + Config.Name);
  LoadConfigList;
end;

procedure TfraLLM.UpdateProviderDefaults;
var
  Idx: Integer;
begin
  Idx := cboProvider.ItemIndex;
  if (Idx >= 0) and (Idx <= High(DEFAULT_URLS)) then
  begin
    if edtBaseUrl.Text = '' then
      edtBaseUrl.Text := DEFAULT_URLS[Idx];
    if edtModel.Text = '' then
      edtModel.Text := DEFAULT_MODELS[Idx];
  end;
end;

procedure TfraLLM.SetStatus(const Text: string; IsError: Boolean);
begin
  lblStatus.Caption := Text;
  if IsError then
    lblStatus.Font.Color := clRed
  else
    lblStatus.Font.Color := clGreen;
end;

procedure TfraLLM.SetConnection(AConnection: TFDConnection);
begin
  // Release old LLM first
  if FOwnsLLM and Assigned(FLLM) then
  begin
    FLLM.Free;
    FLLM := nil;
    FOwnsLLM := False;
  end;
  
  FConnection := AConnection;
  
  // Create new LLM if connection is valid
  if Assigned(FConnection) and FConnection.Connected then
  begin
    try
      FLLM := TDeepBaseLLM.Create(FConnection);
      FOwnsLLM := True;
      LoadConfigList;
      if cboConfigName.Items.Count > 0 then
        LoadConfig(cboConfigName.Text);
    except
      FLLM := nil;
      FOwnsLLM := False;
    end;
  end;
end;

procedure TfraLLM.RefreshData;
begin
  if Assigned(FLLM) then
  begin
    FLLM.RefreshConfigCache;
    LoadConfigList;
    if cboConfigName.Items.Count > 0 then
      LoadConfig(cboConfigName.Text);
    LoadHistory;
    UpdateStats;
  end
  else
  begin
    // When no LLM is available (no DB), reset status
    SetStatus('No LLM manager - open config.db first', True);
  end;
end;

procedure TfraLLM.cboProviderChange(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := cboProvider.ItemIndex;
  if (Idx >= 0) and (Idx <= High(DEFAULT_URLS)) then
  begin
    edtBaseUrl.Text := DEFAULT_URLS[Idx];
    edtModel.Text := DEFAULT_MODELS[Idx];
  end;
end;

procedure TfraLLM.cboConfigNameChange(Sender: TObject);
begin
  if cboConfigName.ItemIndex >= 0 then
    LoadConfig(cboConfigName.Text);
end;

procedure TfraLLM.btnTestConnectionClick(Sender: TObject);
var
  DurationMs: Int64;
  ErrorMsg: string;
begin
  if not Assigned(FLLM) then
  begin
    SetStatus('No LLM manager - open database first', True);
    Exit;
  end;
  
  // Save current config first
  SaveConfig;
  
  SetStatus('Testing connection...');
  btnTestConnection.Enabled := False;
  Application.ProcessMessages;
  
  try
    if FLLM.TestConnection(cboConfigName.Text, DurationMs, ErrorMsg) then
      SetStatus(Format('Connection successful! (%d ms)', [DurationMs]))
    else
      SetStatus('Connection failed: ' + ErrorMsg, True);
  finally
    btnTestConnection.Enabled := True;
  end;
  
  LoadHistory;
end;

procedure TfraLLM.btnSaveConfigClick(Sender: TObject);
begin
  SaveConfig;
end;

procedure TfraLLM.btnNewConfigClick(Sender: TObject);
var
  NewName: string;
begin
  NewName := InputBox('New Configuration', 'Enter configuration name:', '');
  if NewName <> '' then
  begin
    cboConfigName.Items.Add(NewName);
    cboConfigName.ItemIndex := cboConfigName.Items.IndexOf(NewName);
    
    // Reset to defaults
    cboProvider.ItemIndex := 3; // LiteLLM
    cboProviderChange(nil);
    edtApiKey.Text := '';
    edtMaxTokens.Text := '4096';
    edtTemperature.Text := '0.7';
    
    SetStatus('New config created: ' + NewName + ' (not saved yet)');
  end;
end;

procedure TfraLLM.DoChat;
var
  Prompt, Response: string;
  ChatResponse: TLLMChatResponse;
  ConfigName: string;
begin
  if not Assigned(FLLM) then
  begin
    mmoChat.Lines.Add('[ERROR] No LLM manager - open database first');
    Exit;
  end;
  
  Prompt := Trim(mmoInput.Text);
  if Prompt = '' then Exit;
  
  ConfigName := cboChatConfig.Text;
  if ConfigName = '' then
    ConfigName := 'Default';
  
  // Show user message
  mmoChat.Lines.Add('');
  mmoChat.Lines.Add('>>> USER:');
  mmoChat.Lines.Add(Prompt);
  mmoChat.Lines.Add('');
  
  mmoInput.Clear;
  btnSend.Enabled := False;
  Application.ProcessMessages;
  
  try
    if FLLM.Chat(Prompt, ChatResponse, ConfigName) then
    begin
      mmoChat.Lines.Add('<<< ASSISTANT:');
      mmoChat.Lines.Add(ChatResponse.Content);
      mmoChat.Lines.Add('');
      mmoChat.Lines.Add(Format('[Tokens: %d in / %d out, Time: %d ms]',
        [ChatResponse.InputTokens, ChatResponse.OutputTokens, ChatResponse.DurationMs]));
    end
    else
    begin
      mmoChat.Lines.Add('[ERROR] ' + ChatResponse.ErrorMessage);
    end;
  finally
    btnSend.Enabled := True;
    mmoChat.Lines.Add('');
    mmoChat.Lines.Add('----------------------------------------');
    
    // Scroll to bottom
    SendMessage(mmoChat.Handle, EM_LINESCROLL, 0, mmoChat.Lines.Count);
    
    LoadHistory;
  end;
end;

procedure TfraLLM.btnSendClick(Sender: TObject);
begin
  DoChat;
end;

procedure TfraLLM.btnClearClick(Sender: TObject);
begin
  mmoChat.Clear;
  mmoChat.Lines.Add('=== LLM Chat Test ===');
  mmoChat.Lines.Add('Enter a message below and press Send or Ctrl+Enter');
  mmoChat.Lines.Add('');
end;

procedure TfraLLM.mmoInputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (ssCtrl in Shift) then
  begin
    Key := 0;
    DoChat;
  end;
end;

procedure TfraLLM.btnOpenConfigManagerClick(Sender: TObject);
var
  Form: TLLMConfigForm;
begin
  if (FConnection = nil) or not FConnection.Connected then
  begin
    SetStatus('No database connection - open config.db first', True);
    Exit;
  end;

  Form := TLLMConfigForm.Create(Self);
  try
    // Reuse existing LLM instance so configuration is shared
    Form.Initialize(FConnection, FLLM);
    Form.ShowModal;
  finally
    Form.Free;
  end;

  // Reload configs in case user modified them
  RefreshData;
end;

procedure TfraLLM.btnOpenPromptDebugClick(Sender: TObject);
var
  Form: TPromptDebugForm;
begin
  if (FConnection = nil) or not FConnection.Connected then
  begin
    SetStatus('No database connection - open config.db first', True);
    Exit;
  end;

  Form := TPromptDebugForm.Create(Self);
  try
    // Let PromptDebugForm create its own LLMManager on the same config.db
    Form.Initialize(FConnection, nil);
    Form.ShowModal;
  finally
    Form.Free;
  end;

  // After prompt edits, usage hiDeepStory may change
  RefreshData;
end;

procedure TfraLLM.LoadHistory;
var
  History: TLLMCallRecordArray;
  I: Integer;
  FilterConfig: string;
begin
  if not Assigned(FLLM) then Exit;
  
  FilterConfig := '';
  if (cboHistoryConfig.ItemIndex > 0) then
    FilterConfig := cboHistoryConfig.Text;
  
  History := FLLM.GetCallHistory(100, FilterConfig);
  
  grdHistory.RowCount := Length(History) + 1;
  if Length(History) = 0 then
    grdHistory.RowCount := 2;
  
  for I := 0 to High(History) do
  begin
    grdHistory.Cells[0, I + 1] := FormatDateTime('yyyy-mm-dd hh:nn:ss', History[I].CallTime);
    grdHistory.Cells[1, I + 1] := History[I].ConfigName;
    grdHistory.Cells[2, I + 1] := History[I].Model;
    grdHistory.Cells[3, I + 1] := IntToStr(History[I].TotalTokens);
    grdHistory.Cells[4, I + 1] := FormatFloat('$0.0000', History[I].EstimatedCost);
    if History[I].Success then
      grdHistory.Cells[5, I + 1] := 'Success'
    else
      grdHistory.Cells[5, I + 1] := 'Error: ' + Copy(History[I].ErrorMessage, 1, 50);
  end;
  
  if Length(History) = 0 then
  begin
    grdHistory.Cells[0, 1] := '';
    grdHistory.Cells[1, 1] := '';
    grdHistory.Cells[2, 1] := '';
    grdHistory.Cells[3, 1] := '';
    grdHistory.Cells[4, 1] := '';
    grdHistory.Cells[5, 1] := '(No hiDeepStory)';
  end;
  
  UpdateStats;
end;

procedure TfraLLM.UpdateStats;
var
  TotalCalls, TotalTokens: Integer;
  TotalCost: Double;
  FilterConfig: string;
begin
  if not Assigned(FLLM) then Exit;
  
  FilterConfig := '';
  if (cboHistoryConfig.ItemIndex > 0) then
    FilterConfig := cboHistoryConfig.Text;
  
  FLLM.GetUsageStats(FilterConfig, 30, TotalCalls, TotalTokens, TotalCost);
  
  lblStats.Caption := Format('Last 30 days: %d calls, %d tokens, $%.4f total cost',
    [TotalCalls, TotalTokens, TotalCost]);
end;

procedure TfraLLM.btnRefreshHistoryClick(Sender: TObject);
begin
  LoadHistory;
end;

procedure TfraLLM.btnClearHistoryClick(Sender: TObject);
begin
  if not Assigned(FLLM) then Exit;
  
  if MessageDlg('Clear all call hiDeepStory?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FLLM.ClearOldCalls(0);
    LoadHistory;
    SetStatus('History cleared');
  end;
end;

end.
