{ ============================================================================
  DeepBase.FMX.LLMChatFrame - FMX LLM Chat Component
  
  Version: 1.0
  Description: A reusable FMX chat frame for LLM conversations.
               Cross-platform support (Windows, macOS, iOS, Android).
  
  Features:
    - Streaming text display
    - Message hiDeepStory display
    - Cancel button during generation
    - Loading indicator (AniIndicator)
    - Copy message to clipboard
    - Touch-friendly UI
    
  Usage:
    LLMChatFrame1.Client := TBillingClient.Create(URL, APIKey, TenantId);
    LLMChatFrame1.SystemPrompt := 'You are a helpful assistant.';
    LLMChatFrame1.SendMessage('Hello!');
  ============================================================================ }

unit DeepBase.FMX.LLMChatFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Threading, System.Generics.Collections,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Edit, FMX.Memo, FMX.Memo.Types, FMX.ScrollBox,
  FMX.Layouts, FMX.Objects, FMX.Effects, FMX.Ani,
  {$IFDEF MSWINDOWS}
  FMX.Platform.Win,
  {$ENDIF}
  DeepBase.LLM.BillingClient;

type
  /// <summary>Chat message display item</summary>
  TFMXChatDisplayItem = record
    Role: TMessageRole;
    Content: string;
    Timestamp: TDateTime;
    TokenCount: Integer;
  end;
  
  /// <summary>Event when message sent</summary>
  TFMXOnMessageSent = procedure(Sender: TObject; const AMessage: string) of object;
  
  /// <summary>Event when response received</summary>
  TFMXOnResponseReceived = procedure(Sender: TObject; const AResponse: TChatResponse) of object;
  
  /// <summary>Event for streaming chunks</summary>
  TFMXOnStreamChunk = procedure(Sender: TObject; const AChunk: string; ADone: Boolean) of object;
  
  /// <summary>
  /// FMX LLM Chat Frame
  /// </summary>
  TFMXLLMChatFrame = class(TFrame)
  private
    // UI Components
    FLayoutTop: TLayout;
    FLayoutBottom: TLayout;
    FLayoutButtons: TLayout;
    FMemoChat: TMemo;
    FMemoInput: TMemo;
    FBtnSend: TButton;
    FBtnCancel: TButton;
    FBtnClear: TButton;
    FLabelStatus: TLabel;
    FAniIndicator: TAniIndicator;
    
    // Internal state
    FClient: TBillingClient;
    FOwnsClient: Boolean;
    FHistory: TChatHistory;
    FChatItems: TList<TFMXChatDisplayItem>;
    FIsGenerating: Boolean;
    FCurrentTask: ITask;
    FStreamBuffer: string;
    
    // Settings
    FSystemPrompt: string;
    FMaxHistoryMessages: Integer;
    FEnableStreaming: Boolean;
    FShowTimestamps: Boolean;
    FUserColor: TAlphaColor;
    FAssistantColor: TAlphaColor;
    FSystemColor: TAlphaColor;
    
    // Events
    FOnMessageSent: TFMXOnMessageSent;
    FOnResponseReceived: TFMXOnResponseReceived;
    FOnStreamChunk: TFMXOnStreamChunk;
    
    procedure CreateComponents;
    procedure SetupLayout;
    procedure SetClient(AValue: TBillingClient);
    procedure SetSystemPrompt(const AValue: string);
    procedure UpdateUI;
    procedure AppendToChat(ARole: TMessageRole; const AContent: string);
    procedure UpdateStreamContent(const AContent: string);
    procedure DoSendMessage;
    procedure DoCancel;
    procedure DoClear;
    procedure OnBtnSendClick(Sender: TObject);
    procedure OnBtnCancelClick(Sender: TObject);
    procedure OnBtnClearClick(Sender: TObject);
    procedure OnMemoInputKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    function FormatTimestamp(ATime: TDateTime): string;
    procedure SetStatus(const AText: string; AShowIndicator: Boolean = False);
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>Send a message programmatically</summary>
    procedure SendMessage(const AMessage: string);
    
    /// <summary>Cancel current generation</summary>
    procedure Cancel;
    
    /// <summary>Clear chat hiDeepStory</summary>
    procedure ClearHistory;
    
    /// <summary>Get chat hiDeepStory as text</summary>
    function GetChatAsText: string;
    
    /// <summary>Copy chat to clipboard</summary>
    procedure CopyToClipboard;
    
    /// <summary>Export chat to file</summary>
    procedure ExportToFile(const AFileName: string);
    
    // Properties
    property Client: TBillingClient read FClient write SetClient;
    property OwnsClient: Boolean read FOwnsClient write FOwnsClient;
    property SystemPrompt: string read FSystemPrompt write SetSystemPrompt;
    property MaxHistoryMessages: Integer read FMaxHistoryMessages write FMaxHistoryMessages;
    property EnableStreaming: Boolean read FEnableStreaming write FEnableStreaming;
    property ShowTimestamps: Boolean read FShowTimestamps write FShowTimestamps;
    property IsGenerating: Boolean read FIsGenerating;
    property UserColor: TAlphaColor read FUserColor write FUserColor;
    property AssistantColor: TAlphaColor read FAssistantColor write FAssistantColor;
    property SystemColor: TAlphaColor read FSystemColor write FSystemColor;
    
    // Events
    property OnMessageSent: TFMXOnMessageSent read FOnMessageSent write FOnMessageSent;
    property OnResponseReceived: TFMXOnResponseReceived read FOnResponseReceived write FOnResponseReceived;
    property OnStreamChunk: TFMXOnStreamChunk read FOnStreamChunk write FOnStreamChunk;
  end;

implementation

uses
  System.DateUtils,
  FMX.Platform;

const
  DEFAULT_USER_COLOR: TAlphaColor = $FF000080;      // Navy
  DEFAULT_ASSISTANT_COLOR: TAlphaColor = $FF008000; // Green
  DEFAULT_SYSTEM_COLOR: TAlphaColor = $FF808080;    // Gray
  
{ TFMXLLMChatFrame }

constructor TFMXLLMChatFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  // Initialize internal state
  FClient := nil;
  FOwnsClient := False;
  FHistory := TChatHistory.Create('', 50);
  FChatItems := TList<TFMXChatDisplayItem>.Create;
  FIsGenerating := False;
  FStreamBuffer := '';
  
  // Default settings
  FSystemPrompt := '';
  FMaxHistoryMessages := 50;
  FEnableStreaming := True;
  FShowTimestamps := True;
  FUserColor := DEFAULT_USER_COLOR;
  FAssistantColor := DEFAULT_ASSISTANT_COLOR;
  FSystemColor := DEFAULT_SYSTEM_COLOR;
  
  // Create UI
  CreateComponents;
  SetupLayout;
  UpdateUI;
end;

destructor TFMXLLMChatFrame.Destroy;
begin
  // REVIEW5-UI-002: Cancel and wait for background task to prevent
  // use-after-free when frame is destroyed during generation
  if FIsGenerating then
  begin
    if Assigned(FClient) then
      FClient.Cancel;
    // Wait for task to complete (with timeout to prevent deadlock)
    if Assigned(FCurrentTask) then
      FCurrentTask.WaitFor(2000);  // 2 second timeout
  end;

  if FOwnsClient and Assigned(FClient) then
    FreeAndNil(FClient);
  FreeAndNil(FHistory);
  FreeAndNil(FChatItems);
  inherited;
end;

procedure TFMXLLMChatFrame.CreateComponents;
begin
  // Top layout (status)
  FLayoutTop := TLayout.Create(Self);
  FLayoutTop.Parent := Self;
  FLayoutTop.Align := TAlignLayout.Top;
  FLayoutTop.Height := 32;
  
  FLabelStatus := TLabel.Create(Self);
  FLabelStatus.Parent := FLayoutTop;
  FLabelStatus.Align := TAlignLayout.Client;
  FLabelStatus.Text := '����';
  FLabelStatus.TextSettings.HorzAlign := TTextAlign.Leading;
  FLabelStatus.Margins.Left := 8;
  
  FAniIndicator := TAniIndicator.Create(Self);
  FAniIndicator.Parent := FLayoutTop;
  FAniIndicator.Align := TAlignLayout.Right;
  FAniIndicator.Width := 24;
  FAniIndicator.Enabled := False;
  FAniIndicator.Visible := False;
  
  // Bottom layout (input area)
  FLayoutBottom := TLayout.Create(Self);
  FLayoutBottom.Parent := Self;
  FLayoutBottom.Align := TAlignLayout.Bottom;
  FLayoutBottom.Height := 100;
  
  // Buttons layout
  FLayoutButtons := TLayout.Create(Self);
  FLayoutButtons.Parent := FLayoutBottom;
  FLayoutButtons.Align := TAlignLayout.Right;
  FLayoutButtons.Width := 90;
  
  FBtnSend := TButton.Create(Self);
  FBtnSend.Parent := FLayoutButtons;
  FBtnSend.Text := '����';
  FBtnSend.Position.X := 5;
  FBtnSend.Position.Y := 5;
  FBtnSend.Width := 80;
  FBtnSend.Height := 28;
  FBtnSend.OnClick := OnBtnSendClick;
  
  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := FLayoutButtons;
  FBtnCancel.Text := 'ȡ��';
  FBtnCancel.Position.X := 5;
  FBtnCancel.Position.Y := 36;
  FBtnCancel.Width := 80;
  FBtnCancel.Height := 28;
  FBtnCancel.Enabled := False;
  FBtnCancel.OnClick := OnBtnCancelClick;
  
  FBtnClear := TButton.Create(Self);
  FBtnClear.Parent := FLayoutButtons;
  FBtnClear.Text := '���';
  FBtnClear.Position.X := 5;
  FBtnClear.Position.Y := 67;
  FBtnClear.Width := 80;
  FBtnClear.Height := 28;
  FBtnClear.OnClick := OnBtnClearClick;
  
  // Input memo
  FMemoInput := TMemo.Create(Self);
  FMemoInput.Parent := FLayoutBottom;
  FMemoInput.Align := TAlignLayout.Client;
  FMemoInput.Margins.Left := 4;
  FMemoInput.Margins.Top := 4;
  FMemoInput.Margins.Right := 4;
  FMemoInput.Margins.Bottom := 4;
  FMemoInput.TextSettings.WordWrap := True;
  FMemoInput.OnKeyDown := OnMemoInputKeyDown;
  
  // Chat display memo
  FMemoChat := TMemo.Create(Self);
  FMemoChat.Parent := Self;
  FMemoChat.Align := TAlignLayout.Client;
  FMemoChat.Margins.Left := 4;
  FMemoChat.Margins.Top := 4;
  FMemoChat.Margins.Right := 4;
  FMemoChat.Margins.Bottom := 4;
  FMemoChat.ReadOnly := True;
  FMemoChat.TextSettings.WordWrap := True;
end;

procedure TFMXLLMChatFrame.SetupLayout;
begin
  Self.Width := 500;
  Self.Height := 400;
end;

procedure TFMXLLMChatFrame.SetClient(AValue: TBillingClient);
begin
  if FOwnsClient and Assigned(FClient) then
    FreeAndNil(FClient);
  FClient := AValue;
  FOwnsClient := False;
end;

procedure TFMXLLMChatFrame.SetSystemPrompt(const AValue: string);
begin
  FSystemPrompt := AValue;
  if Assigned(FHistory) then
    FHistory.SystemPrompt := AValue;
end;

procedure TFMXLLMChatFrame.UpdateUI;
begin
  FBtnSend.Enabled := not FIsGenerating and Assigned(FClient);
  FBtnCancel.Enabled := FIsGenerating;
  FBtnClear.Enabled := not FIsGenerating;
  FMemoInput.Enabled := not FIsGenerating;
end;

procedure TFMXLLMChatFrame.SetStatus(const AText: string; AShowIndicator: Boolean);
begin
  FLabelStatus.Text := AText;
  FAniIndicator.Visible := AShowIndicator;
  FAniIndicator.Enabled := AShowIndicator;
end;

function TFMXLLMChatFrame.FormatTimestamp(ATime: TDateTime): string;
begin
  Result := FormatDateTime('hh:nn:ss', ATime);
end;

procedure TFMXLLMChatFrame.AppendToChat(ARole: TMessageRole; const AContent: string);
var
  Item: TFMXChatDisplayItem;
  RoleText: string;
  Line: string;
begin
  // Add to items list
  Item.Role := ARole;
  Item.Content := AContent;
  Item.Timestamp := Now;
  Item.TokenCount := 0;
  FChatItems.Add(Item);
  
  // Determine role text
  case ARole of
    mrSystem: RoleText := '[ϵͳ]';
    mrUser: RoleText := '[��]';
    mrAssistant: RoleText := '[����]';
  else
    RoleText := '';
  end;
  
  // Build line
  if FShowTimestamps then
    Line := RoleText + ' ' + FormatTimestamp(Now)
  else
    Line := RoleText;
  
  // Append to memo (FMX doesn't support rich text formatting in TMemo)
  FMemoChat.Lines.Add(Line);
  FMemoChat.Lines.Add(AContent);
  FMemoChat.Lines.Add('');
  
  // Scroll to end
  FMemoChat.GoToTextEnd;
end;

procedure TFMXLLMChatFrame.UpdateStreamContent(const AContent: string);
var
  LastLineIdx: Integer;
  CurrentLine: string;
begin
  // Append content to last line
  if FMemoChat.Lines.Count > 0 then
  begin
    LastLineIdx := FMemoChat.Lines.Count - 2; // -1 for empty line, -1 for content line
    if LastLineIdx >= 0 then
    begin
      CurrentLine := FMemoChat.Lines[LastLineIdx];
      FMemoChat.Lines[LastLineIdx] := CurrentLine + AContent;
    end
    else
    begin
      FMemoChat.Lines.Add(AContent);
    end;
  end
  else
  begin
    FMemoChat.Lines.Add(AContent);
  end;
  
  FMemoChat.GoToTextEnd;
end;

procedure TFMXLLMChatFrame.OnBtnSendClick(Sender: TObject);
begin
  DoSendMessage;
end;

procedure TFMXLLMChatFrame.OnBtnCancelClick(Sender: TObject);
begin
  DoCancel;
end;

procedure TFMXLLMChatFrame.OnBtnClearClick(Sender: TObject);
begin
  DoClear;
end;

procedure TFMXLLMChatFrame.OnMemoInputKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin
  // Ctrl+Enter to send
  if (Key = vkReturn) and (ssCtrl in Shift) then
  begin
    Key := 0;
    KeyChar := #0;
    DoSendMessage;
  end;
end;

procedure TFMXLLMChatFrame.DoSendMessage;
var
  UserMessage: string;
  Messages: TChatMessages;
begin
  if FIsGenerating or not Assigned(FClient) then
    Exit;
    
  UserMessage := Trim(FMemoInput.Text);
  if UserMessage = '' then
    Exit;
    
  // Clear input
  FMemoInput.Lines.Clear;
  
  // Add user message to display
  AppendToChat(mrUser, UserMessage);
  
  // Add to hiDeepStory
  FHistory.AddUserMessage(UserMessage);
  
  // Fire event
  if Assigned(FOnMessageSent) then
    FOnMessageSent(Self, UserMessage);
  
  // Start generation
  FIsGenerating := True;
  FStreamBuffer := '';
  UpdateUI;
  SetStatus('��������...', True);
  
  // Add assistant header
  if FShowTimestamps then
    FMemoChat.Lines.Add('[����] ' + FormatTimestamp(Now))
  else
    FMemoChat.Lines.Add('[����]');
  FMemoChat.Lines.Add(''); // Content placeholder
  FMemoChat.Lines.Add(''); // Empty line
  
  // Run async
  // UI2-002 fix: store the task in FCurrentTask so the destructor can
  // WaitFor() it before tearing down FHistory/FClient. The previous
  // TThread.CreateAnonymousThread(...).Start left FCurrentTask nil, so
  // Destroy's safety net never engaged and the anonymous thread continued
  // to access fields on the already-freed frame.
  // UI2-009 fix: snapshot the history on the main thread BEFORE entering
  // the background task. The previous code called FHistory.GetMessages
  // from the worker thread while DoSendMessage (main thread) could be
  // mutating FHistory concurrently via AddUserMessage. Capturing a
  // TChatMessages copy up front eliminates the data race entirely.
  Messages := FHistory.GetMessages;

  FCurrentTask := TTask.Run(
    procedure
    var
      Response: TChatResponse;
      LocalContent: string;
      LocalErrorMsg: string;
      LocalTokenCount: Integer;
      LocalContentLineIdx: Integer;
    begin
      try
        // Use non-streaming for simplicity in FMX
        Response := FClient.ChatWithHistory(Messages);
        LocalContent := Response.Content;
        LocalTokenCount := Response.Usage.TotalTokens;
        LocalErrorMsg := Response.ErrorMessage;
        
        TThread.Synchronize(nil,
          procedure
          var
            Item: TFMXChatDisplayItem;
          begin
            LocalContentLineIdx := FMemoChat.Lines.Count - 2;
            
            if Response.Success then
            begin
              if LocalContentLineIdx >= 0 then
                FMemoChat.Lines[LocalContentLineIdx] := LocalContent;
              
              FHistory.AddAssistantMessage(LocalContent);
              
              Item.Role := mrAssistant;
              Item.Content := LocalContent;
              Item.Timestamp := Now;
              Item.TokenCount := LocalTokenCount;
              FChatItems.Add(Item);
              
              SetStatus('��� (' + IntToStr(LocalTokenCount) + ' tokens)');
            end
            else
            begin
              if LocalContentLineIdx >= 0 then
                FMemoChat.Lines[LocalContentLineIdx] := '����: ' + LocalErrorMsg;
              
              SetStatus('����: ' + LocalErrorMsg);
            end;
            
            FIsGenerating := False;
            UpdateUI;
            
            if Assigned(FOnResponseReceived) then
              FOnResponseReceived(Self, Response);
          end);
      except
        on E: Exception do
        begin
          LocalErrorMsg := E.Message;
          TThread.Synchronize(nil,
            procedure
            begin
              LocalContentLineIdx := FMemoChat.Lines.Count - 2;
              if LocalContentLineIdx >= 0 then
                FMemoChat.Lines[LocalContentLineIdx] := '����: ' + LocalErrorMsg;
              
              FIsGenerating := False;
              UpdateUI;
              SetStatus('����: ' + LocalErrorMsg);
            end);
        end;
      end;
    end);
end;

procedure TFMXLLMChatFrame.DoCancel;
begin
  if FIsGenerating and Assigned(FClient) then
  begin
    FClient.Cancel;
    SetStatus('��ȡ��');
  end;
end;

procedure TFMXLLMChatFrame.DoClear;
begin
  if not FIsGenerating then
  begin
    FMemoChat.Lines.Clear;
    FChatItems.Clear;
    FHistory.Clear;
    SetStatus('�����');
  end;
end;

procedure TFMXLLMChatFrame.SendMessage(const AMessage: string);
begin
  FMemoInput.Text := AMessage;
  DoSendMessage;
end;

procedure TFMXLLMChatFrame.Cancel;
begin
  DoCancel;
end;

procedure TFMXLLMChatFrame.ClearHistory;
begin
  DoClear;
end;

function TFMXLLMChatFrame.GetChatAsText: string;
var
  SB: TStringBuilder;
  Item: TFMXChatDisplayItem;
  RoleText: string;
begin
  SB := TStringBuilder.Create;
  try
    for Item in FChatItems do
    begin
      case Item.Role of
        mrSystem: RoleText := '[ϵͳ]';
        mrUser: RoleText := '[��]';
        mrAssistant: RoleText := '[����]';
      else
        RoleText := '';
      end;
      
      SB.AppendLine(RoleText + ' ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Item.Timestamp));
      SB.AppendLine(Item.Content);
      SB.AppendLine;
    end;
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

procedure TFMXLLMChatFrame.CopyToClipboard;
var
  ClipboardService: IFMXClipboardService;
begin
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, ClipboardService) then
    ClipboardService.SetClipboard(GetChatAsText);
end;

procedure TFMXLLMChatFrame.ExportToFile(const AFileName: string);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Text := GetChatAsText;
    SL.SaveToFile(AFileName, TEncoding.UTF8);
  finally
    SL.Free;
  end;
end;

end.
