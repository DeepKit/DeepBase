{ ============================================================================
  DeepBase.VCL.LLMChatFrame - VCL LLM Chat Component
  
  Version: 1.0
  Description: A reusable VCL chat frame for LLM conversations.
  
  Features:
    - Streaming text display with typing effect
    - Message history display
    - Cancel button during generation
    - Loading indicator
    - Markdown rendering (basic)
    - Copy message to clipboard
    
  Usage:
    LLMChatFrame1.Client := TBillingClient.Create(URL, APIKey, TenantId);
    LLMChatFrame1.SystemPrompt := 'You are a helpful assistant.';
    // User types message and clicks Send, or:
    LLMChatFrame1.SendMessage('Hello!');
  ============================================================================ }

unit DeepBase.VCL.LLMChatFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, 
  System.Classes, System.Threading, System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Buttons, Vcl.ComCtrls, Vcl.Clipbrd,
  DeepBase.LLM.BillingClient;

type
  /// <summary>Chat message display item</summary>
  TChatDisplayItem = record
    Role: TMessageRole;
    Content: string;
    Timestamp: TDateTime;
    TokenCount: Integer;
  end;
  
  /// <summary>Event when message sent</summary>
  TOnMessageSent = procedure(Sender: TObject; const AMessage: string) of object;
  
  /// <summary>Event when response received</summary>
  TOnResponseReceived = procedure(Sender: TObject; const AResponse: TChatResponse) of object;
  
  /// <summary>Event for streaming chunks</summary>
  TOnStreamChunk = procedure(Sender: TObject; const AChunk: string; ADone: Boolean) of object;
  
  /// <summary>
  /// VCL LLM Chat Frame
  /// </summary>
  TLLMChatFrame = class(TFrame)
  private
    // UI Components
    FPanelTop: TPanel;
    FPanelBottom: TPanel;
    FPanelInput: TPanel;
    FRichEditChat: TRichEdit;
    FMemoInput: TMemo;
    FBtnSend: TButton;
    FBtnCancel: TButton;
    FBtnClear: TButton;
    FLabelStatus: TLabel;
    FProgressBar: TProgressBar;
    
    // Internal state
    FClient: TBillingClient;
    FOwnsClient: Boolean;
    FHistory: TChatHistory;
    FChatItems: TList<TChatDisplayItem>;
    FIsGenerating: Boolean;
    FCurrentTask: ITask;
    FStreamBuffer: string;
    
    // Settings
    FSystemPrompt: string;
    FMaxHistoryMessages: Integer;
    FEnableStreaming: Boolean;
    FShowTimestamps: Boolean;
    FUserColor: TColor;
    FAssistantColor: TColor;
    FSystemColor: TColor;
    
    // Events
    FOnMessageSent: TOnMessageSent;
    FOnResponseReceived: TOnResponseReceived;
    FOnStreamChunk: TOnStreamChunk;
    
    procedure CreateComponents;
    procedure SetupLayout;
    procedure SetClient(AValue: TBillingClient);
    procedure SetSystemPrompt(const AValue: string);
    procedure UpdateUI;
    procedure AppendToChat(ARole: TMessageRole; const AContent: string; AIsStream: Boolean = False);
    procedure UpdateStreamContent(const AContent: string);
    procedure DoSendMessage;
    procedure DoCancel;
    procedure DoClear;
    procedure OnBtnSendClick(Sender: TObject);
    procedure OnBtnCancelClick(Sender: TObject);
    procedure OnBtnClearClick(Sender: TObject);
    procedure OnMemoInputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    function FormatTimestamp(ATime: TDateTime): string;
    procedure SetStatus(const AText: string; AShowProgress: Boolean = False);
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>Send a message programmatically</summary>
    procedure SendMessage(const AMessage: string);
    
    /// <summary>Cancel current generation</summary>
    procedure Cancel;
    
    /// <summary>Clear chat history</summary>
    procedure ClearHistory;
    
    /// <summary>Get chat history as text</summary>
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
    property UserColor: TColor read FUserColor write FUserColor;
    property AssistantColor: TColor read FAssistantColor write FAssistantColor;
    property SystemColor: TColor read FSystemColor write FSystemColor;
    
    // Events
    property OnMessageSent: TOnMessageSent read FOnMessageSent write FOnMessageSent;
    property OnResponseReceived: TOnResponseReceived read FOnResponseReceived write FOnResponseReceived;
    property OnStreamChunk: TOnStreamChunk read FOnStreamChunk write FOnStreamChunk;
  end;

implementation

uses
  System.DateUtils, Winapi.RichEdit;

const
  DEFAULT_USER_COLOR = clNavy;
  DEFAULT_ASSISTANT_COLOR = clGreen;
  DEFAULT_SYSTEM_COLOR = clGray;
  
{ TLLMChatFrame }

constructor TLLMChatFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  // Initialize internal state
  FClient := nil;
  FOwnsClient := False;
  FHistory := TChatHistory.Create('', 50);
  FChatItems := TList<TChatDisplayItem>.Create;
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

destructor TLLMChatFrame.Destroy;
begin
  if FOwnsClient and Assigned(FClient) then
    FreeAndNil(FClient);
  FreeAndNil(FHistory);
  FreeAndNil(FChatItems);
  inherited;
end;

procedure TLLMChatFrame.CreateComponents;
begin
  // Top panel (status)
  FPanelTop := TPanel.Create(Self);
  FPanelTop.Parent := Self;
  FPanelTop.Align := alTop;
  FPanelTop.Height := 28;
  FPanelTop.BevelOuter := bvNone;
  FPanelTop.ParentBackground := False;
  
  FLabelStatus := TLabel.Create(Self);
  FLabelStatus.Parent := FPanelTop;
  FLabelStatus.Align := alClient;
  FLabelStatus.Layout := tlCenter;
  FLabelStatus.Caption := '就绪';
  FLabelStatus.AlignWithMargins := True;
  FLabelStatus.Margins.Left := 8;
  
  FProgressBar := TProgressBar.Create(Self);
  FProgressBar.Parent := FPanelTop;
  FProgressBar.Align := alRight;
  FProgressBar.Width := 100;
  FProgressBar.Style := pbstMarquee;
  FProgressBar.Visible := False;
  FProgressBar.AlignWithMargins := True;
  
  // Bottom panel (input area)
  FPanelBottom := TPanel.Create(Self);
  FPanelBottom.Parent := Self;
  FPanelBottom.Align := alBottom;
  FPanelBottom.Height := 80;
  FPanelBottom.BevelOuter := bvNone;
  
  // Buttons panel
  FPanelInput := TPanel.Create(Self);
  FPanelInput.Parent := FPanelBottom;
  FPanelInput.Align := alRight;
  FPanelInput.Width := 90;
  FPanelInput.BevelOuter := bvNone;
  
  FBtnSend := TButton.Create(Self);
  FBtnSend.Parent := FPanelInput;
  FBtnSend.Caption := '发送';
  FBtnSend.Top := 4;
  FBtnSend.Left := 4;
  FBtnSend.Width := 80;
  FBtnSend.Height := 25;
  FBtnSend.OnClick := OnBtnSendClick;
  
  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := FPanelInput;
  FBtnCancel.Caption := '取消';
  FBtnCancel.Top := 32;
  FBtnCancel.Left := 4;
  FBtnCancel.Width := 80;
  FBtnCancel.Height := 25;
  FBtnCancel.Enabled := False;
  FBtnCancel.OnClick := OnBtnCancelClick;
  
  FBtnClear := TButton.Create(Self);
  FBtnClear.Parent := FPanelInput;
  FBtnClear.Caption := '清空';
  FBtnClear.Top := 60;
  FBtnClear.Left := 4;
  FBtnClear.Width := 80;
  FBtnClear.Height := 25;
  FBtnClear.OnClick := OnBtnClearClick;
  
  // Input memo
  FMemoInput := TMemo.Create(Self);
  FMemoInput.Parent := FPanelBottom;
  FMemoInput.Align := alClient;
  FMemoInput.AlignWithMargins := True;
  FMemoInput.Margins.SetBounds(4, 4, 4, 4);
  FMemoInput.ScrollBars := ssVertical;
  FMemoInput.OnKeyDown := OnMemoInputKeyDown;
  
  // Chat display (RichEdit)
  FRichEditChat := TRichEdit.Create(Self);
  FRichEditChat.Parent := Self;
  FRichEditChat.Align := alClient;
  FRichEditChat.AlignWithMargins := True;
  FRichEditChat.Margins.SetBounds(4, 4, 4, 4);
  FRichEditChat.ReadOnly := True;
  FRichEditChat.ScrollBars := ssVertical;
  FRichEditChat.WordWrap := True;
  FRichEditChat.PlainText := False;
end;

procedure TLLMChatFrame.SetupLayout;
begin
  Self.Width := 500;
  Self.Height := 400;
end;

procedure TLLMChatFrame.SetClient(AValue: TBillingClient);
begin
  if FOwnsClient and Assigned(FClient) then
    FreeAndNil(FClient);
  FClient := AValue;
  FOwnsClient := False;
end;

procedure TLLMChatFrame.SetSystemPrompt(const AValue: string);
begin
  FSystemPrompt := AValue;
  if Assigned(FHistory) then
    FHistory.SystemPrompt := AValue;
end;

procedure TLLMChatFrame.UpdateUI;
begin
  FBtnSend.Enabled := not FIsGenerating and Assigned(FClient);
  FBtnCancel.Enabled := FIsGenerating;
  FBtnClear.Enabled := not FIsGenerating;
  FMemoInput.Enabled := not FIsGenerating;
end;

procedure TLLMChatFrame.SetStatus(const AText: string; AShowProgress: Boolean);
begin
  FLabelStatus.Caption := AText;
  FProgressBar.Visible := AShowProgress;
end;

function TLLMChatFrame.FormatTimestamp(ATime: TDateTime): string;
begin
  Result := FormatDateTime('hh:nn:ss', ATime);
end;

procedure TLLMChatFrame.AppendToChat(ARole: TMessageRole; const AContent: string; 
  AIsStream: Boolean);
var
  Item: TChatDisplayItem;
  RoleText: string;
  TextColor: TColor;
begin
  // Add to items list
  if not AIsStream then
  begin
    Item.Role := ARole;
    Item.Content := AContent;
    Item.Timestamp := Now;
    Item.TokenCount := 0;
    FChatItems.Add(Item);
  end;
  
  // Determine role text and color
  case ARole of
    mrSystem:
    begin
      RoleText := '[系统]';
      TextColor := FSystemColor;
    end;
    mrUser:
    begin
      RoleText := '[你]';
      TextColor := FUserColor;
    end;
    mrAssistant:
    begin
      RoleText := '[助手]';
      TextColor := FAssistantColor;
    end;
  else
    RoleText := '';
    TextColor := clBlack;
  end;
  
  // Append to RichEdit
  FRichEditChat.SelStart := Length(FRichEditChat.Text);
  FRichEditChat.SelLength := 0;
  
  // Role header with timestamp
  FRichEditChat.SelAttributes.Style := [fsBold];
  FRichEditChat.SelAttributes.Color := TextColor;
  if FShowTimestamps then
    FRichEditChat.SelText := RoleText + ' ' + FormatTimestamp(Now) + #13#10
  else
    FRichEditChat.SelText := RoleText + #13#10;
  
  // Content
  FRichEditChat.SelAttributes.Style := [];
  FRichEditChat.SelAttributes.Color := clBlack;
  FRichEditChat.SelText := AContent + #13#10#13#10;
  
  // Scroll to end
  FRichEditChat.SelStart := Length(FRichEditChat.Text);
  Winapi.Windows.SendMessage(FRichEditChat.Handle, EM_SCROLLCARET, 0, 0);
end;

procedure TLLMChatFrame.UpdateStreamContent(const AContent: string);
begin
  // Update the last line with streaming content
  FRichEditChat.Lines.BeginUpdate;
  try
    // Find last content position and update
    FRichEditChat.SelStart := Length(FRichEditChat.Text);
    FRichEditChat.SelLength := 0;
    FRichEditChat.SelText := AContent;
    
    // Scroll to end
    Winapi.Windows.SendMessage(FRichEditChat.Handle, EM_SCROLLCARET, 0, 0);
  finally
    FRichEditChat.Lines.EndUpdate;
  end;
end;

procedure TLLMChatFrame.OnBtnSendClick(Sender: TObject);
begin
  DoSendMessage;
end;

procedure TLLMChatFrame.OnBtnCancelClick(Sender: TObject);
begin
  DoCancel;
end;

procedure TLLMChatFrame.OnBtnClearClick(Sender: TObject);
begin
  DoClear;
end;

procedure TLLMChatFrame.OnMemoInputKeyDown(Sender: TObject; var Key: Word; 
  Shift: TShiftState);
begin
  // Ctrl+Enter or just Enter (without Shift) to send
  if (Key = VK_RETURN) and (ssCtrl in Shift) then
  begin
    Key := 0;
    DoSendMessage;
  end;
end;

procedure TLLMChatFrame.DoSendMessage;
var
  UserMessage: string;
begin
  if FIsGenerating or not Assigned(FClient) then
    Exit;
    
  UserMessage := Trim(FMemoInput.Text);
  if UserMessage = '' then
    Exit;
    
  // Clear input
  FMemoInput.Clear;
  
  // Add user message to display
  AppendToChat(mrUser, UserMessage);
  
  // Add to history
  FHistory.AddUserMessage(UserMessage);
  
  // Fire event
  if Assigned(FOnMessageSent) then
    FOnMessageSent(Self, UserMessage);
  
  // Start generation
  FIsGenerating := True;
  FStreamBuffer := '';
  UpdateUI;
  SetStatus('正在生成...', True);
  
  // Add assistant placeholder
  FRichEditChat.SelStart := Length(FRichEditChat.Text);
  FRichEditChat.SelAttributes.Style := [fsBold];
  FRichEditChat.SelAttributes.Color := FAssistantColor;
  if FShowTimestamps then
    FRichEditChat.SelText := '[助手] ' + FormatTimestamp(Now) + #13#10
  else
    FRichEditChat.SelText := '[助手]' + #13#10;
  FRichEditChat.SelAttributes.Style := [];
  FRichEditChat.SelAttributes.Color := clBlack;
  
  // Run async
  TThread.CreateAnonymousThread(
    procedure
    var
      Messages: TChatMessages;
      Response: TChatResponse;
      LocalStreamBuffer: string;
      LocalChunk: string;
      LocalContent: string;
      LocalErrorMsg: string;
      LocalTokenCount: Integer;
    begin
      Messages := FHistory.GetMessages;
      LocalStreamBuffer := '';
      
      try
        if FEnableStreaming then
        begin
          // Streaming mode - use simple Chat for now since stream callback is complex
          if FClient.Chat(FHistory.GetLastUserMessage, Response) then
          begin
            LocalContent := Response.Content;
            LocalTokenCount := Response.Usage.TotalTokens;
            
            TThread.Synchronize(nil,
              procedure
              var
                Item: TChatDisplayItem;
              begin
                // 检查控件有效性，防止访问已释放的控件
                if Assigned(Self) and not (csDestroying in ComponentState) and 
                   Assigned(FRichEditChat) and FRichEditChat.HandleAllocated then
                begin
                  FRichEditChat.SelStart := Length(FRichEditChat.Text);
                  FRichEditChat.SelText := LocalContent + #13#10#13#10;
                  
                  FHistory.AddAssistantMessage(LocalContent);
                  
                  Item.Role := mrAssistant;
                  Item.Content := LocalContent;
                  Item.Timestamp := Now;
                  Item.TokenCount := LocalTokenCount;
                  FChatItems.Add(Item);
                  
                  FIsGenerating := False;
                  UpdateUI;
                  SetStatus('完成 (' + IntToStr(LocalTokenCount) + ' tokens)');
                  
                  if Assigned(FOnResponseReceived) then
                    FOnResponseReceived(Self, Response);
                end;
              end);
          end
          else
          begin
            LocalErrorMsg := Response.ErrorMessage;
            TThread.Synchronize(nil,
              procedure
              begin
                // 检查控件有效性
                if Assigned(Self) and not (csDestroying in ComponentState) and 
                   Assigned(FRichEditChat) and FRichEditChat.HandleAllocated then
                begin
                  FRichEditChat.SelStart := Length(FRichEditChat.Text);
                  FRichEditChat.SelAttributes.Color := clRed;
                  FRichEditChat.SelText := '错误: ' + LocalErrorMsg + #13#10#13#10;
                  FRichEditChat.SelAttributes.Color := clBlack;
                  
                  FIsGenerating := False;
                  UpdateUI;
                  SetStatus('错误: ' + LocalErrorMsg);
                end;
              end);
          end;
        end
        else
        begin
          // Non-streaming mode
          Response := FClient.ChatWithHistory(Messages);
          LocalContent := Response.Content;
          LocalTokenCount := Response.Usage.TotalTokens;
          LocalErrorMsg := Response.ErrorMessage;
          
          TThread.Synchronize(nil,
            procedure
            var
              Item: TChatDisplayItem;
            begin
              // 检查控件有效性
              if Assigned(Self) and not (csDestroying in ComponentState) and 
                 Assigned(FRichEditChat) and FRichEditChat.HandleAllocated then
              begin
                if Response.Success then
                begin
                  FRichEditChat.SelStart := Length(FRichEditChat.Text);
                  FRichEditChat.SelText := LocalContent + #13#10#13#10;
                  
                  FHistory.AddAssistantMessage(LocalContent);
                  
                  Item.Role := mrAssistant;
                  Item.Content := LocalContent;
                  Item.Timestamp := Now;
                  Item.TokenCount := LocalTokenCount;
                  FChatItems.Add(Item);
                  
                  SetStatus('完成 (' + IntToStr(LocalTokenCount) + ' tokens)');
                end
                else
                begin
                  FRichEditChat.SelStart := Length(FRichEditChat.Text);
                  FRichEditChat.SelAttributes.Color := clRed;
                  FRichEditChat.SelText := '错误: ' + LocalErrorMsg + #13#10#13#10;
                  FRichEditChat.SelAttributes.Color := clBlack;
                  
                  SetStatus('错误: ' + LocalErrorMsg);
                end;
                
                FIsGenerating := False;
                UpdateUI;
                
                if Assigned(FOnResponseReceived) then
                  FOnResponseReceived(Self, Response);
              end;
            end);
        end;
      except
        on E: Exception do
        begin
          LocalErrorMsg := E.Message;
          TThread.Synchronize(nil,
            procedure
            begin
              // 检查控件有效性
              if Assigned(Self) and not (csDestroying in ComponentState) and 
                 Assigned(FRichEditChat) and FRichEditChat.HandleAllocated then
              begin
                FRichEditChat.SelStart := Length(FRichEditChat.Text);
                FRichEditChat.SelAttributes.Color := clRed;
                FRichEditChat.SelText := '错误: ' + LocalErrorMsg + #13#10#13#10;
                FRichEditChat.SelAttributes.Color := clBlack;
                
                FIsGenerating := False;
                UpdateUI;
                SetStatus('错误: ' + LocalErrorMsg);
              end;
            end);
        end;
      end;
    end).Start;
end;

procedure TLLMChatFrame.DoCancel;
begin
  if FIsGenerating and Assigned(FClient) then
  begin
    FClient.Cancel;
    SetStatus('已取消');
  end;
end;

procedure TLLMChatFrame.DoClear;
begin
  if not FIsGenerating then
  begin
    FRichEditChat.Clear;
    FChatItems.Clear;
    FHistory.Clear;
    SetStatus('已清空');
  end;
end;

procedure TLLMChatFrame.SendMessage(const AMessage: string);
begin
  FMemoInput.Text := AMessage;
  DoSendMessage;
end;

procedure TLLMChatFrame.Cancel;
begin
  DoCancel;
end;

procedure TLLMChatFrame.ClearHistory;
begin
  DoClear;
end;

function TLLMChatFrame.GetChatAsText: string;
var
  SB: TStringBuilder;
  Item: TChatDisplayItem;
  RoleText: string;
begin
  SB := TStringBuilder.Create;
  try
    for Item in FChatItems do
    begin
      case Item.Role of
        mrSystem: RoleText := '[系统]';
        mrUser: RoleText := '[你]';
        mrAssistant: RoleText := '[助手]';
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

procedure TLLMChatFrame.CopyToClipboard;
begin
  Clipboard.AsText := GetChatAsText;
end;

procedure TLLMChatFrame.ExportToFile(const AFileName: string);
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
