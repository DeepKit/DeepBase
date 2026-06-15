{ ============================================================================
  DeepBase.FMX.LLMConfigPanel - FMX LLM ����������
  
  �汾: 1.0
  ˵��: �ṩ LLM ���õĿ��ӻ��༭���� (FMX ��ƽ̨�汾)
  ����:
    - Provider ѡ�� (OpenAI/Anthropic/Azure/LiteLLM/Ollama/Custom)
    - API Key / Base URL ����
    - Model / MaxTokens / Temperature ����
    - ��������
    - ������ʷ��ʾ
  ============================================================================ }

unit DeepBase.FMX.LLMConfigPanel;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Math,
  FMX.Types,
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.StdCtrls,
  FMX.Edit,
  FMX.SpinBox,
  FMX.ListBox,
  FMX.Layouts,
  FMX.Grid,
  FMX.Grid.Style,
  FMX.ScrollBox,
  FMX.Graphics,
  FMX.Forms,
  DeepBase.Types,
  DeepBase.LLM;

type
  /// <summary>
  /// FMX LLM ���������� - �����봴�������� .fmx
  /// </summary>
  TFMXLLMConfigPanel = class(TLayout)
  private
    // ����������
    FConfigLayout: TLayout;
    
    // Provider ��
    FProviderLabel: TLabel;
    FProviderCombo: TComboBox;
    
    // Base URL ��
    FBaseUrlLabel: TLabel;
    FBaseUrlEdit: TEdit;
    
    // API Key ��
    FApiKeyLabel: TLabel;
    FApiKeyEdit: TEdit;
    
    // Model ��
    FModelLabel: TLabel;
    FModelEdit: TEdit;
    
    // Max Tokens ��
    FMaxTokensLabel: TLabel;
    FMaxTokensEdit: TSpinBox;
    
    // Temperature ��
    FTemperatureLabel: TLabel;
    FTemperatureEdit: TSpinBox;
    
    // ��ť��
    FButtonLayout: TLayout;
    FTestButton: TButton;
    FSaveButton: TButton;
    FResetButton: TButton;
    
    // ״̬��ǩ
    FStatusLabel: TLabel;
    
    // ��ʷ��
    FHistoryLayout: TLayout;
    FHistoryLabel: TLabel;
    FHistoryGrid: TStringGrid;
    FClearHistoryButton: TButton;
    
    // �ڲ�״̬
    FConfigName: string;
    FConnection: TComponent;
    FLLM: TDeepBaseLLM;
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
    procedure SetConnection(Value: TComponent);
    
    function GetColumnValue(const ACol: Integer; const ARow: Integer): string;
    procedure SetColumnValue(const ACol, ARow: Integer; const Value: string);
    
  protected
    procedure Resize; override;
    procedure Loaded; override;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>
    /// ˢ�����ã������ݿ����¼��أ�
    /// </summary>
    procedure RefreshConfig;
    
    /// <summary>
    /// ˢ�����ݣ�����+��ʷ��
    /// </summary>
    procedure RefreshData;
    
    /// <summary>
    /// ���� LLM ����������ѡ�������ڲ�������
    /// </summary>
    procedure SetLLM(ALLM: TDeepBaseLLM);
    
  published
    /// <summary>
    /// ��������
    /// </summary>
    property ConfigName: string read FConfigName write SetConfigName;
    
    /// <summary>
    /// ���ݿ�����
    /// </summary>
    property Connection: TComponent read FConnection write SetConnection;
    
    /// <summary>
    /// ���ñ���¼�
    /// </summary>
    property OnConfigChanged: TNotifyEvent read FOnConfigChanged write FOnConfigChanged;
  end;

procedure Register;

implementation

uses
  FMX.DialogService;

procedure Register;
begin
  RegisterComponents('DeepBase FMX', [TFMXLLMConfigPanel]);
end;

{ TFMXLLMConfigPanel }

constructor TFMXLLMConfigPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Width := 500;
  Height := 500;
  
  FConfigName := 'Default';
  FOwnsLLM := False;
  
  CreateControls;
end;

destructor TFMXLLMConfigPanel.Destroy;
begin
  if FOwnsLLM and Assigned(FLLM) then
    FreeAndNil(FLLM);
  inherited;
end;

procedure TFMXLLMConfigPanel.CreateControls;
const
  ROW_HEIGHT = 32;
  LABEL_WIDTH = 100;
  MARGIN = 10;
var
  Y: Single;
  Item: TListBoxItem;
begin
  // ========== ������ ==========
  FConfigLayout := TLayout.Create(Self);
  FConfigLayout.Parent := Self;
  FConfigLayout.Align := TAlignLayout.Top;
  FConfigLayout.Height := 280;
  FConfigLayout.Margins.Rect := RectF(MARGIN, MARGIN, MARGIN, MARGIN);
  
  Y := 0;
  
  // Provider ��
  FProviderLabel := TLabel.Create(Self);
  FProviderLabel.Parent := FConfigLayout;
  FProviderLabel.Position.X := 0;
  FProviderLabel.Position.Y := Y + 6;
  FProviderLabel.Width := LABEL_WIDTH;
  FProviderLabel.Text := 'Provider:';
  
  FProviderCombo := TComboBox.Create(Self);
  FProviderCombo.Parent := FConfigLayout;
  FProviderCombo.Position.X := LABEL_WIDTH;
  FProviderCombo.Position.Y := Y;
  FProviderCombo.Width := 150;
  FProviderCombo.Height := ROW_HEIGHT;
  
  Item := TListBoxItem.Create(FProviderCombo);
  Item.Text := 'OpenAI';
  FProviderCombo.AddObject(Item);
  
  Item := TListBoxItem.Create(FProviderCombo);
  Item.Text := 'Anthropic';
  FProviderCombo.AddObject(Item);
  
  Item := TListBoxItem.Create(FProviderCombo);
  Item.Text := 'Azure';
  FProviderCombo.AddObject(Item);
  
  Item := TListBoxItem.Create(FProviderCombo);
  Item.Text := 'LiteLLM';
  FProviderCombo.AddObject(Item);
  
  Item := TListBoxItem.Create(FProviderCombo);
  Item.Text := 'Ollama';
  FProviderCombo.AddObject(Item);
  
  Item := TListBoxItem.Create(FProviderCombo);
  Item.Text := 'Custom';
  FProviderCombo.AddObject(Item);
  
  FProviderCombo.ItemIndex := 0;
  FProviderCombo.OnChange := ProviderChanged;
  
  Y := Y + ROW_HEIGHT + 8;
  
  // Base URL ��
  FBaseUrlLabel := TLabel.Create(Self);
  FBaseUrlLabel.Parent := FConfigLayout;
  FBaseUrlLabel.Position.X := 0;
  FBaseUrlLabel.Position.Y := Y + 6;
  FBaseUrlLabel.Width := LABEL_WIDTH;
  FBaseUrlLabel.Text := 'Base URL:';
  
  FBaseUrlEdit := TEdit.Create(Self);
  FBaseUrlEdit.Parent := FConfigLayout;
  FBaseUrlEdit.Position.X := LABEL_WIDTH;
  FBaseUrlEdit.Position.Y := Y;
  FBaseUrlEdit.Width := 350;
  FBaseUrlEdit.Height := ROW_HEIGHT;
  
  Y := Y + ROW_HEIGHT + 8;
  
  // API Key ��
  FApiKeyLabel := TLabel.Create(Self);
  FApiKeyLabel.Parent := FConfigLayout;
  FApiKeyLabel.Position.X := 0;
  FApiKeyLabel.Position.Y := Y + 6;
  FApiKeyLabel.Width := LABEL_WIDTH;
  FApiKeyLabel.Text := 'API Key:';
  
  FApiKeyEdit := TEdit.Create(Self);
  FApiKeyEdit.Parent := FConfigLayout;
  FApiKeyEdit.Position.X := LABEL_WIDTH;
  FApiKeyEdit.Position.Y := Y;
  FApiKeyEdit.Width := 350;
  FApiKeyEdit.Height := ROW_HEIGHT;
  FApiKeyEdit.Password := True;
  
  Y := Y + ROW_HEIGHT + 8;
  
  // Model ��
  FModelLabel := TLabel.Create(Self);
  FModelLabel.Parent := FConfigLayout;
  FModelLabel.Position.X := 0;
  FModelLabel.Position.Y := Y + 6;
  FModelLabel.Width := LABEL_WIDTH;
  FModelLabel.Text := 'Model:';
  
  FModelEdit := TEdit.Create(Self);
  FModelEdit.Parent := FConfigLayout;
  FModelEdit.Position.X := LABEL_WIDTH;
  FModelEdit.Position.Y := Y;
  FModelEdit.Width := 200;
  FModelEdit.Height := ROW_HEIGHT;
  FModelEdit.Text := 'gpt-4o-mini';
  
  Y := Y + ROW_HEIGHT + 8;
  
  // Max Tokens ��
  FMaxTokensLabel := TLabel.Create(Self);
  FMaxTokensLabel.Parent := FConfigLayout;
  FMaxTokensLabel.Position.X := 0;
  FMaxTokensLabel.Position.Y := Y + 6;
  FMaxTokensLabel.Width := LABEL_WIDTH;
  FMaxTokensLabel.Text := 'Max Tokens:';
  
  FMaxTokensEdit := TSpinBox.Create(Self);
  FMaxTokensEdit.Parent := FConfigLayout;
  FMaxTokensEdit.Position.X := LABEL_WIDTH;
  FMaxTokensEdit.Position.Y := Y;
  FMaxTokensEdit.Width := 100;
  FMaxTokensEdit.Height := ROW_HEIGHT;
  FMaxTokensEdit.Min := 1;
  FMaxTokensEdit.Max := 128000;
  FMaxTokensEdit.Value := 4096;
  FMaxTokensEdit.DecimalDigits := 0;
  
  // Temperature (ͬһ��)
  FTemperatureLabel := TLabel.Create(Self);
  FTemperatureLabel.Parent := FConfigLayout;
  FTemperatureLabel.Position.X := 220;
  FTemperatureLabel.Position.Y := Y + 6;
  FTemperatureLabel.Width := 90;
  FTemperatureLabel.Text := 'Temperature:';
  
  FTemperatureEdit := TSpinBox.Create(Self);
  FTemperatureEdit.Parent := FConfigLayout;
  FTemperatureEdit.Position.X := 320;
  FTemperatureEdit.Position.Y := Y;
  FTemperatureEdit.Width := 80;
  FTemperatureEdit.Height := ROW_HEIGHT;
  FTemperatureEdit.Min := 0;
  FTemperatureEdit.Max := 2;
  FTemperatureEdit.Value := 0.7;
  FTemperatureEdit.DecimalDigits := 1;
  
  Y := Y + ROW_HEIGHT + 12;
  
  // ========== ��ť�� ==========
  FButtonLayout := TLayout.Create(Self);
  FButtonLayout.Parent := FConfigLayout;
  FButtonLayout.Position.X := 0;
  FButtonLayout.Position.Y := Y;
  FButtonLayout.Width := 400;
  FButtonLayout.Height := 36;
  
  FTestButton := TButton.Create(Self);
  FTestButton.Parent := FButtonLayout;
  FTestButton.Position.X := 0;
  FTestButton.Position.Y := 0;
  FTestButton.Width := 90;
  FTestButton.Height := 32;
  FTestButton.Text := 'Test';
  FTestButton.OnClick := TestButtonClick;
  
  FSaveButton := TButton.Create(Self);
  FSaveButton.Parent := FButtonLayout;
  FSaveButton.Position.X := 100;
  FSaveButton.Position.Y := 0;
  FSaveButton.Width := 90;
  FSaveButton.Height := 32;
  FSaveButton.Text := 'Save';
  FSaveButton.OnClick := SaveButtonClick;
  
  FResetButton := TButton.Create(Self);
  FResetButton.Parent := FButtonLayout;
  FResetButton.Position.X := 200;
  FResetButton.Position.Y := 0;
  FResetButton.Width := 90;
  FResetButton.Height := 32;
  FResetButton.Text := 'Reset';
  FResetButton.OnClick := ResetButtonClick;
  
  Y := Y + 40;
  
  // ״̬��ǩ
  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := FConfigLayout;
  FStatusLabel.Position.X := 0;
  FStatusLabel.Position.Y := Y;
  FStatusLabel.Width := 450;
  FStatusLabel.Height := 20;
  FStatusLabel.Text := '';
  FStatusLabel.FontColor := TAlphaColorRec.Gray;
  
  // ========== ��ʷ�� ==========
  FHistoryLayout := TLayout.Create(Self);
  FHistoryLayout.Parent := Self;
  FHistoryLayout.Align := TAlignLayout.Client;
  FHistoryLayout.Margins.Rect := RectF(MARGIN, 0, MARGIN, MARGIN);
  
  FHistoryLabel := TLabel.Create(Self);
  FHistoryLabel.Parent := FHistoryLayout;
  FHistoryLabel.Align := TAlignLayout.Top;
  FHistoryLabel.Height := 24;
  FHistoryLabel.Text := 'Call History';
  FHistoryLabel.StyledSettings := FHistoryLabel.StyledSettings - [TStyledSetting.Size];
  FHistoryLabel.TextSettings.Font.Size := 14;
  FHistoryLabel.TextSettings.Font.Style := [TFontStyle.fsBold];
  
  // History Grid
  FHistoryGrid := TStringGrid.Create(Self);
  FHistoryGrid.Parent := FHistoryLayout;
  FHistoryGrid.Align := TAlignLayout.Client;
  FHistoryGrid.Margins.Top := 5;
  FHistoryGrid.Margins.Bottom := 40;
  FHistoryGrid.RowCount := 1;
  FHistoryGrid.Options := FHistoryGrid.Options + [TGridOption.RowSelect];
  FHistoryGrid.ReadOnly := True;
  
  // �����
  with TStringColumn.Create(FHistoryGrid) do
  begin
    Parent := FHistoryGrid;
    Header := 'Time';
    Width := 80;
  end;
  
  with TStringColumn.Create(FHistoryGrid) do
  begin
    Parent := FHistoryGrid;
    Header := 'Model';
    Width := 100;
  end;
  
  with TStringColumn.Create(FHistoryGrid) do
  begin
    Parent := FHistoryGrid;
    Header := 'Tokens';
    Width := 60;
  end;
  
  with TStringColumn.Create(FHistoryGrid) do
  begin
    Parent := FHistoryGrid;
    Header := 'Cost';
    Width := 70;
  end;
  
  with TStringColumn.Create(FHistoryGrid) do
  begin
    Parent := FHistoryGrid;
    Header := 'Status';
    Width := 100;
  end;
  
  // Clear History Button
  FClearHistoryButton := TButton.Create(Self);
  FClearHistoryButton.Parent := FHistoryLayout;
  FClearHistoryButton.Align := TAlignLayout.Bottom;
  FClearHistoryButton.Height := 32;
  FClearHistoryButton.Width := 120;
  FClearHistoryButton.Position.X := 0;
  FClearHistoryButton.Text := 'Clear History';
  FClearHistoryButton.OnClick := ClearHistoryClick;
end;

procedure TFMXLLMConfigPanel.Loaded;
begin
  inherited;
  LayoutControls;
  if not (csDesigning in ComponentState) then
    LoadConfig;
end;

procedure TFMXLLMConfigPanel.Resize;
begin
  inherited;
  LayoutControls;
end;

procedure TFMXLLMConfigPanel.LayoutControls;
begin
  // FMX ʹ�� Align �Զ����֣����������һЩ΢��
  if Assigned(FBaseUrlEdit) then
    FBaseUrlEdit.Width := Max(100, Width - 160);
    
  if Assigned(FApiKeyEdit) then
    FApiKeyEdit.Width := Max(100, Width - 160);
end;

procedure TFMXLLMConfigPanel.SetConfigName(const Value: string);
begin
  if FConfigName <> Value then
  begin
    FConfigName := Value;
    if not (csDesigning in ComponentState) then
      LoadConfig;
  end;
end;

procedure TFMXLLMConfigPanel.SetConnection(Value: TComponent);
begin
  if FConnection <> Value then
  begin
    FConnection := Value;
    
    // ������ڲ� LLM���ͷ���
    if FOwnsLLM and Assigned(FLLM) then
    begin
      FreeAndNil(FLLM);
      FLLM := nil;
      FOwnsLLM := False;
    end;
    
    // �����µ� LLM ������
    if Assigned(FConnection) then
    begin
      FLLM := TDeepBaseLLM.Create(FConnection);
      FOwnsLLM := True;
      LoadConfig;
    end;
  end;
end;

procedure TFMXLLMConfigPanel.SetLLM(ALLM: TDeepBaseLLM);
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

procedure TFMXLLMConfigPanel.ProviderChanged(Sender: TObject);
var
  ProviderIdx: Integer;
begin
  ProviderIdx := FProviderCombo.ItemIndex;
  
  // ����Ĭ�� Base URL
  case ProviderIdx of
    0: FBaseUrlEdit.Text := ''; // OpenAI - ʹ��Ĭ��
    1: FBaseUrlEdit.Text := ''; // Anthropic - ʹ��Ĭ��
    2: FBaseUrlEdit.Text := ''; // Azure - ��Ҫ�û���д
    3: FBaseUrlEdit.Text := 'http://localhost:4000'; // LiteLLM
    4: FBaseUrlEdit.Text := 'http://localhost:11434'; // Ollama
    5: FBaseUrlEdit.Text := ''; // Custom
  end;
  
  // ����Ĭ�� Model
  case ProviderIdx of
    0: FModelEdit.Text := 'gpt-4o-mini';
    1: FModelEdit.Text := 'claude-3-haiku-20240307';
    2: FModelEdit.Text := 'gpt-4';
    3: FModelEdit.Text := 'gpt-4o-mini';
    4: FModelEdit.Text := 'llama2';
    5: FModelEdit.Text := '';
  end;
end;

procedure TFMXLLMConfigPanel.LoadConfig;
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
  FMaxTokensEdit.Value := Config.MaxTokens;
  FTemperatureEdit.Value := Config.Temperature;
  
  RefreshHistory;
  SetStatus('Configuration loaded');
end;

procedure TFMXLLMConfigPanel.SaveConfig;
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
  Config.MaxTokens := Trunc(FMaxTokensEdit.Value);
  Config.Temperature := FTemperatureEdit.Value;
  Config.IsEnabled := True;
  
  FLLM.SaveConfig(Config);
  
  SetStatus('Configuration saved');
  
  if Assigned(FOnConfigChanged) then
    FOnConfigChanged(Self);
end;

procedure TFMXLLMConfigPanel.RefreshConfig;
begin
  LoadConfig;
end;

procedure TFMXLLMConfigPanel.RefreshData;
begin
  LoadConfig;
  RefreshHistory;
end;

function TFMXLLMConfigPanel.GetColumnValue(const ACol, ARow: Integer): string;
begin
  Result := '';
  if Assigned(FHistoryGrid) and (ACol < FHistoryGrid.ColumnCount) and (ARow < FHistoryGrid.RowCount) then
    Result := FHistoryGrid.Cells[ACol, ARow];
end;

procedure TFMXLLMConfigPanel.SetColumnValue(const ACol, ARow: Integer; const Value: string);
begin
  if Assigned(FHistoryGrid) and (ACol < FHistoryGrid.ColumnCount) and (ARow < FHistoryGrid.RowCount) then
    FHistoryGrid.Cells[ACol, ARow] := Value;
end;

procedure TFMXLLMConfigPanel.RefreshHistory;
var
  History: TLLMCallRecordArray;
  I: Integer;
begin
  if not Assigned(FLLM) then Exit;
  
  History := FLLM.GetCallHistory(50);
  
  FHistoryGrid.RowCount := Max(1, Length(History));
  
  for I := 0 to High(History) do
  begin
    SetColumnValue(0, I, FormatDateTime('hh:nn:ss', History[I].CallTime));
    SetColumnValue(1, I, History[I].Model);
    SetColumnValue(2, I, IntToStr(History[I].InputTokens + History[I].OutputTokens));
    SetColumnValue(3, I, FormatFloat('$0.0000', History[I].EstimatedCost));
    if History[I].Success then
      SetColumnValue(4, I, 'Success')
    else
      SetColumnValue(4, I, 'Error: ' + Copy(History[I].ErrorMessage, 1, 30));
  end;
  
  if Length(History) = 0 then
  begin
    FHistoryGrid.RowCount := 1;
    SetColumnValue(0, 0, '');
    SetColumnValue(1, 0, '');
    SetColumnValue(2, 0, '');
    SetColumnValue(3, 0, '');
    SetColumnValue(4, 0, '(No hiDeepStory)');
  end;
end;

procedure TFMXLLMConfigPanel.SetStatus(const AText: string; IsError: Boolean);
begin
  FStatusLabel.Text := AText;
  if IsError then
    FStatusLabel.FontColor := TAlphaColorRec.Red
  else
    FStatusLabel.FontColor := TAlphaColorRec.Green;
end;

procedure TFMXLLMConfigPanel.TestButtonClick(Sender: TObject);
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
  
  try
    // �ȱ��浱ǰ����
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

procedure TFMXLLMConfigPanel.SaveButtonClick(Sender: TObject);
begin
  SaveConfig;
end;

procedure TFMXLLMConfigPanel.ResetButtonClick(Sender: TObject);
begin
  LoadConfig;
  SetStatus('Configuration reset');
end;

procedure TFMXLLMConfigPanel.ClearHistoryClick(Sender: TObject);
begin
  if not Assigned(FLLM) then Exit;
  
  TDialogService.MessageDialog('Clear all call hiDeepStory?',
    TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo],
    TMsgDlgBtn.mbNo, 0,
    procedure(const AResult: TModalResult)
    begin
      if AResult = mrYes then
      begin
        FLLM.ClearOldCalls(0); // Clear all
        RefreshHistory;
        SetStatus('History cleared');
      end;
    end);
end;

end.
