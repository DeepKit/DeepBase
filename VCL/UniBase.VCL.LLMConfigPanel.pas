{ ============================================================================
  UniBase.VCL.LLMConfigPanel - LLM 配置面板组件
  
  版本: 1.0
  说明: 提供 LLM 配置的可视化编辑界面
  功能:
    - Provider 选择 (OpenAI/Anthropic/Azure/LiteLLM/Ollama/Custom)
    - API Key / Base URL 配置
    - Model / MaxTokens / Temperature 配置
    - 测试连接
    - 调用历史显示
  ============================================================================ }

unit UniBase.VCL.LLMConfigPanel;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.Grids,
  FireDAC.Comp.Client,
  UniBase.Types,
  UniBase.LLM;

type
  /// <summary>
  /// LLM 配置面板组件 - 独立 TPanel，无需 .dfm
  /// </summary>
  TLLMConfigPanel = class(TPanel)
  private
    // 配置区控件
    FConfigGroupBox: TGroupBox;
    FProviderLabel: TLabel;
    FProviderCombo: TComboBox;
    FBaseUrlLabel: TLabel;
    FBaseUrlEdit: TEdit;
    FApiKeyLabel: TLabel;
    FApiKeyEdit: TEdit;
    FModelLabel: TLabel;
    FModelEdit: TEdit;
    FMaxTokensLabel: TLabel;
    FMaxTokensEdit: TEdit;
    FTemperatureLabel: TLabel;
    FTemperatureEdit: TEdit;
    
    // 按钮
    FTestButton: TButton;
    FSaveButton: TButton;
    FResetButton: TButton;
    
    // 状态
    FStatusLabel: TLabel;
    
    // 历史区控件
    FHistoryGroupBox: TGroupBox;
    FHistoryGrid: TStringGrid;
    FClearHistoryButton: TButton;
    
    // 内部状态
    FConfigName: string;
    FConnection: TFDConnection;
    FLLM: TUniBaseLLM;
    FOwnsLLM: Boolean;
    FOnConfigChanged: TNotifyEvent;
    
    procedure CreateControls;
    procedure LayoutControls;
    procedure ProviderChanged(Sender: TObject);
    procedure TestButtonClick(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
    procedure ResetButtonClick(Sender: TObject);
    procedure ClearHistoryClick(Sender: TObject);
    
    procedure LoadConfig;
    procedure SaveConfig;
    procedure RefreshHistory;
    procedure SetStatus(const AText: string; IsError: Boolean = False);
    
    procedure SetConfigName(const Value: string);
    procedure SetConnection(Value: TFDConnection);
    
  protected
    procedure Resize; override;
    procedure Loaded; override;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>
    /// 刷新配置（从数据库重新加载）
    /// </summary>
    procedure RefreshConfig;
    
    /// <summary>
    /// 刷新数据（配置+历史）
    /// </summary>
    procedure RefreshData;
    
    /// <summary>
    /// 设置 LLM 管理器（可选，否则内部创建）
    /// </summary>
    procedure SetLLM(ALLM: TUniBaseLLM);
    
  published
    /// <summary>
    /// 配置名称
    /// </summary>
    property ConfigName: string read FConfigName write SetConfigName;
    
    /// <summary>
    /// 数据库连接
    /// </summary>
    property Connection: TFDConnection read FConnection write SetConnection;
    
    /// <summary>
    /// 配置变更事件
    /// </summary>
    property OnConfigChanged: TNotifyEvent read FOnConfigChanged write FOnConfigChanged;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('UniBase', [TLLMConfigPanel]);
end;

{ TLLMConfigPanel }

constructor TLLMConfigPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Width := 500;
  Height := 450;
  BevelOuter := bvNone;
  
  FConfigName := 'Default';
  FOwnsLLM := False;
  
  CreateControls;
end;

destructor TLLMConfigPanel.Destroy;
begin
  if FOwnsLLM and Assigned(FLLM) then
    FLLM.Free;
  inherited;
end;

procedure TLLMConfigPanel.CreateControls;
var
  Y: Integer;
begin
  // 配置 GroupBox
  FConfigGroupBox := TGroupBox.Create(Self);
  FConfigGroupBox.Parent := Self;
  FConfigGroupBox.Caption := 'LLM Configuration';
  FConfigGroupBox.Align := alTop;
  FConfigGroupBox.Height := 280;
  
  Y := 25;
  
  // Provider
  FProviderLabel := TLabel.Create(Self);
  FProviderLabel.Parent := FConfigGroupBox;
  FProviderLabel.SetBounds(15, Y, 80, 16);
  FProviderLabel.Caption := 'Provider:';
  
  FProviderCombo := TComboBox.Create(Self);
  FProviderCombo.Parent := FConfigGroupBox;
  FProviderCombo.SetBounds(100, Y - 3, 150, 24);
  FProviderCombo.Style := csDropDownList;
  FProviderCombo.Items.Add('OpenAI');
  FProviderCombo.Items.Add('Anthropic');
  FProviderCombo.Items.Add('Azure');
  FProviderCombo.Items.Add('LiteLLM');
  FProviderCombo.Items.Add('Ollama');
  FProviderCombo.Items.Add('Custom');
  FProviderCombo.ItemIndex := 0;
  FProviderCombo.OnChange := ProviderChanged;
  
  Inc(Y, 30);
  
  // Base URL
  FBaseUrlLabel := TLabel.Create(Self);
  FBaseUrlLabel.Parent := FConfigGroupBox;
  FBaseUrlLabel.SetBounds(15, Y, 80, 16);
  FBaseUrlLabel.Caption := 'Base URL:';
  
  FBaseUrlEdit := TEdit.Create(Self);
  FBaseUrlEdit.Parent := FConfigGroupBox;
  FBaseUrlEdit.SetBounds(100, Y - 3, 380, 24);
  FBaseUrlEdit.Text := '';
  
  Inc(Y, 30);
  
  // API Key
  FApiKeyLabel := TLabel.Create(Self);
  FApiKeyLabel.Parent := FConfigGroupBox;
  FApiKeyLabel.SetBounds(15, Y, 80, 16);
  FApiKeyLabel.Caption := 'API Key:';
  
  FApiKeyEdit := TEdit.Create(Self);
  FApiKeyEdit.Parent := FConfigGroupBox;
  FApiKeyEdit.SetBounds(100, Y - 3, 380, 24);
  FApiKeyEdit.PasswordChar := '•';
  
  Inc(Y, 30);
  
  // Model
  FModelLabel := TLabel.Create(Self);
  FModelLabel.Parent := FConfigGroupBox;
  FModelLabel.SetBounds(15, Y, 80, 16);
  FModelLabel.Caption := 'Model:';
  
  FModelEdit := TEdit.Create(Self);
  FModelEdit.Parent := FConfigGroupBox;
  FModelEdit.SetBounds(100, Y - 3, 200, 24);
  FModelEdit.Text := 'gpt-4o-mini';
  
  Inc(Y, 30);
  
  // Max Tokens
  FMaxTokensLabel := TLabel.Create(Self);
  FMaxTokensLabel.Parent := FConfigGroupBox;
  FMaxTokensLabel.SetBounds(15, Y, 80, 16);
  FMaxTokensLabel.Caption := 'Max Tokens:';
  
  FMaxTokensEdit := TEdit.Create(Self);
  FMaxTokensEdit.Parent := FConfigGroupBox;
  FMaxTokensEdit.SetBounds(100, Y - 3, 80, 24);
  FMaxTokensEdit.Text := '4096';
  
  // Temperature
  FTemperatureLabel := TLabel.Create(Self);
  FTemperatureLabel.Parent := FConfigGroupBox;
  FTemperatureLabel.SetBounds(200, Y, 80, 16);
  FTemperatureLabel.Caption := 'Temperature:';
  
  FTemperatureEdit := TEdit.Create(Self);
  FTemperatureEdit.Parent := FConfigGroupBox;
  FTemperatureEdit.SetBounds(285, Y - 3, 60, 24);
  FTemperatureEdit.Text := '0.7';
  
  Inc(Y, 35);
  
  // Buttons
  FTestButton := TButton.Create(Self);
  FTestButton.Parent := FConfigGroupBox;
  FTestButton.SetBounds(15, Y, 90, 28);
  FTestButton.Caption := 'Test';
  FTestButton.OnClick := TestButtonClick;
  
  FSaveButton := TButton.Create(Self);
  FSaveButton.Parent := FConfigGroupBox;
  FSaveButton.SetBounds(115, Y, 90, 28);
  FSaveButton.Caption := 'Save';
  FSaveButton.OnClick := SaveButtonClick;
  
  FResetButton := TButton.Create(Self);
  FResetButton.Parent := FConfigGroupBox;
  FResetButton.SetBounds(215, Y, 90, 28);
  FResetButton.Caption := 'Reset';
  FResetButton.OnClick := ResetButtonClick;
  
  Inc(Y, 35);
  
  // Status
  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := FConfigGroupBox;
  FStatusLabel.SetBounds(15, Y, 460, 16);
  FStatusLabel.Caption := '';
  FStatusLabel.Font.Color := clGray;
  
  // History GroupBox
  FHistoryGroupBox := TGroupBox.Create(Self);
  FHistoryGroupBox.Parent := Self;
  FHistoryGroupBox.Caption := 'Call History';
  FHistoryGroupBox.Align := alClient;
  
  // History Grid
  FHistoryGrid := TStringGrid.Create(Self);
  FHistoryGrid.Parent := FHistoryGroupBox;
  FHistoryGrid.Align := alClient;
  FHistoryGrid.AlignWithMargins := True;
  FHistoryGrid.Margins.SetBounds(10, 20, 10, 40);
  FHistoryGrid.RowCount := 2;
  FHistoryGrid.ColCount := 5;
  FHistoryGrid.FixedRows := 1;
  FHistoryGrid.FixedCols := 0;
  FHistoryGrid.Options := FHistoryGrid.Options + [goRowSelect];
  FHistoryGrid.DefaultRowHeight := 22;
  
  // Set column headers
  FHistoryGrid.Cells[0, 0] := 'Time';
  FHistoryGrid.Cells[1, 0] := 'Model';
  FHistoryGrid.Cells[2, 0] := 'Tokens';
  FHistoryGrid.Cells[3, 0] := 'Cost';
  FHistoryGrid.Cells[4, 0] := 'Status';
  
  // Clear History Button
  FClearHistoryButton := TButton.Create(Self);
  FClearHistoryButton.Parent := FHistoryGroupBox;
  FClearHistoryButton.Caption := 'Clear History';
  FClearHistoryButton.Width := 100;
  FClearHistoryButton.Height := 25;
  FClearHistoryButton.Anchors := [akRight, akBottom];
  FClearHistoryButton.OnClick := ClearHistoryClick;
end;

procedure TLLMConfigPanel.Loaded;
begin
  inherited;
  LayoutControls;
  if not (csDesigning in ComponentState) then
    LoadConfig;
end;

procedure TLLMConfigPanel.Resize;
begin
  inherited;
  LayoutControls;
end;

procedure TLLMConfigPanel.LayoutControls;
begin
  // Adjust grid column widths
  if Assigned(FHistoryGrid) and (FHistoryGrid.Width > 100) then
  begin
    FHistoryGrid.ColWidths[0] := 120; // Time
    FHistoryGrid.ColWidths[1] := 100; // Model
    FHistoryGrid.ColWidths[2] := 60;  // Tokens
    FHistoryGrid.ColWidths[3] := 60;  // Cost
    FHistoryGrid.ColWidths[4] := Max(80, FHistoryGrid.Width - 360); // Status
  end;
  
  // Position clear button
  if Assigned(FClearHistoryButton) and Assigned(FHistoryGroupBox) then
  begin
    FClearHistoryButton.Left := FHistoryGroupBox.Width - FClearHistoryButton.Width - 15;
    FClearHistoryButton.Top := FHistoryGroupBox.Height - FClearHistoryButton.Height - 10;
  end;
end;

procedure TLLMConfigPanel.SetConfigName(const Value: string);
begin
  if FConfigName <> Value then
  begin
    FConfigName := Value;
    if not (csDesigning in ComponentState) then
      LoadConfig;
  end;
end;

procedure TLLMConfigPanel.SetConnection(Value: TFDConnection);
begin
  if FConnection <> Value then
  begin
    FConnection := Value;
    
    // 如果有内部 LLM，释放它
    if FOwnsLLM and Assigned(FLLM) then
    begin
      FLLM.Free;
      FLLM := nil;
      FOwnsLLM := False;
    end;
    
    // 创建新的 LLM 管理器
    if Assigned(FConnection) and FConnection.Connected then
    begin
      FLLM := TUniBaseLLM.Create(FConnection);
      FOwnsLLM := True;
      LoadConfig;
    end;
  end;
end;

procedure TLLMConfigPanel.SetLLM(ALLM: TUniBaseLLM);
begin
  if FOwnsLLM and Assigned(FLLM) then
  begin
    FLLM.Free;
    FOwnsLLM := False;
  end;
  
  FLLM := ALLM;
  FOwnsLLM := False;
  
  if Assigned(FLLM) then
    LoadConfig;
end;

procedure TLLMConfigPanel.ProviderChanged(Sender: TObject);
var
  ProviderIdx: Integer;
begin
  ProviderIdx := FProviderCombo.ItemIndex;
  
  // 设置默认 Base URL
  case ProviderIdx of
    0: FBaseUrlEdit.Text := ''; // OpenAI - 使用默认
    1: FBaseUrlEdit.Text := ''; // Anthropic - 使用默认
    2: FBaseUrlEdit.Text := ''; // Azure - 需要用户填写
    3: FBaseUrlEdit.Text := 'http://localhost:4000'; // LiteLLM
    4: FBaseUrlEdit.Text := 'http://localhost:11434'; // Ollama
    5: FBaseUrlEdit.Text := ''; // Custom
  end;
  
  // 设置默认 Model
  case ProviderIdx of
    0: FModelEdit.Text := 'gpt-4o-mini';
    1: FModelEdit.Text := 'claude-3-haiku-20240307';
    2: FModelEdit.Text := 'gpt-4';
    3: FModelEdit.Text := 'gpt-4o-mini';
    4: FModelEdit.Text := 'llama2';
    5: FModelEdit.Text := '';
  end;
end;

procedure TLLMConfigPanel.LoadConfig;
var
  Config: TLLMConfig;
begin
  if not Assigned(FLLM) then Exit;
  
  Config := FLLM.GetConfig(FConfigName);
  
  // Provider
  case Config.Provider of
    lpOpenAI:    FProviderCombo.ItemIndex := 0;
    lpAnthropic: FProviderCombo.ItemIndex := 1;
    lpAzure:     FProviderCombo.ItemIndex := 2;
    lpLiteLLM:   FProviderCombo.ItemIndex := 3;
    lpOllama:    FProviderCombo.ItemIndex := 4;
    lpCustom:    FProviderCombo.ItemIndex := 5;
  end;
  
  FBaseUrlEdit.Text := Config.BaseUrl;
  FApiKeyEdit.Text := Config.ApiKey;
  FModelEdit.Text := Config.Model;
  FMaxTokensEdit.Text := IntToStr(Config.MaxTokens);
  FTemperatureEdit.Text := FormatFloat('0.0', Config.Temperature);
  
  RefreshHistory;
  SetStatus('Configuration loaded');
end;

procedure TLLMConfigPanel.SaveConfig;
var
  Config: TLLMConfig;
begin
  if not Assigned(FLLM) then Exit;
  
  Config.Init;
  Config.Name := FConfigName;
  
  // Provider
  case FProviderCombo.ItemIndex of
    0: Config.Provider := lpOpenAI;
    1: Config.Provider := lpAnthropic;
    2: Config.Provider := lpAzure;
    3: Config.Provider := lpLiteLLM;
    4: Config.Provider := lpOllama;
    5: Config.Provider := lpCustom;
  end;
  
  Config.BaseUrl := FBaseUrlEdit.Text;
  Config.ApiKey := FApiKeyEdit.Text;
  Config.Model := FModelEdit.Text;
  Config.MaxTokens := StrToIntDef(FMaxTokensEdit.Text, 4096);
  Config.Temperature := StrToFloatDef(FTemperatureEdit.Text, 0.7);
  Config.IsEnabled := True;
  
  FLLM.SaveConfig(Config);
  
  SetStatus('Configuration saved');
  
  if Assigned(FOnConfigChanged) then
    FOnConfigChanged(Self);
end;

procedure TLLMConfigPanel.RefreshConfig;
begin
  LoadConfig;
end;

procedure TLLMConfigPanel.RefreshData;
begin
  LoadConfig;
  RefreshHistory;
end;

procedure TLLMConfigPanel.RefreshHistory;
var
  History: TLLMCallRecordArray;
  I: Integer;
begin
  if not Assigned(FLLM) then Exit;
  
  History := FLLM.GetCallHistory(50);
  
  FHistoryGrid.RowCount := Max(2, Length(History) + 1);
  
  for I := 0 to High(History) do
  begin
    FHistoryGrid.Cells[0, I + 1] := FormatDateTime('hh:nn:ss', History[I].CallTime);
    FHistoryGrid.Cells[1, I + 1] := History[I].Model;
    FHistoryGrid.Cells[2, I + 1] := IntToStr(History[I].InputTokens + History[I].OutputTokens);
    FHistoryGrid.Cells[3, I + 1] := FormatFloat('$0.0000', History[I].EstimatedCost);
    if History[I].Success then
      FHistoryGrid.Cells[4, I + 1] := 'Success'
    else
      FHistoryGrid.Cells[4, I + 1] := 'Error: ' + Copy(History[I].ErrorMessage, 1, 50);
  end;
  
  if Length(History) = 0 then
  begin
    FHistoryGrid.Cells[0, 1] := '';
    FHistoryGrid.Cells[1, 1] := '';
    FHistoryGrid.Cells[2, 1] := '';
    FHistoryGrid.Cells[3, 1] := '';
    FHistoryGrid.Cells[4, 1] := '(No history)';
  end;
end;

procedure TLLMConfigPanel.SetStatus(const AText: string; IsError: Boolean);
begin
  FStatusLabel.Caption := AText;
  if IsError then
    FStatusLabel.Font.Color := clRed
  else
    FStatusLabel.Font.Color := clGreen;
end;

procedure TLLMConfigPanel.TestButtonClick(Sender: TObject);
var
  DurationMs: Int64;
  ErrorMsg: string;
begin
  if not Assigned(FLLM) then
  begin
    SetStatus('No LLM connection', True);
    Exit;
  end;
  
  SetStatus('Testing connection...');
  FTestButton.Enabled := False;
  Application.ProcessMessages;
  
  try
    // 先保存当前配置
    SaveConfig;
    FLLM.RefreshConfigCache;
    
    if FLLM.TestConnection(FConfigName, DurationMs, ErrorMsg) then
    begin
      SetStatus(Format('Connection successful (%d ms)', [DurationMs]));
      RefreshHistory;
    end
    else
      SetStatus('Connection failed: ' + ErrorMsg, True);
  finally
    FTestButton.Enabled := True;
  end;
end;

procedure TLLMConfigPanel.SaveButtonClick(Sender: TObject);
begin
  SaveConfig;
end;

procedure TLLMConfigPanel.ResetButtonClick(Sender: TObject);
begin
  LoadConfig;
  SetStatus('Configuration reset');
end;

procedure TLLMConfigPanel.ClearHistoryClick(Sender: TObject);
begin
  if not Assigned(FLLM) then Exit;
  
  FLLM.ClearOldCalls(0); // Clear all
  RefreshHistory;
  SetStatus('History cleared');
end;

end.
