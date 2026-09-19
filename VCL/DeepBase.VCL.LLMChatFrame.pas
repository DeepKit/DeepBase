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
  System.Classes, System.Generics.Collections, System.SyncObjs,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Buttons, Vcl.ComCtrls, Vcl.Clipbrd,
  DeepBase.LLM.BillingClient,
  DeepBase.ManagedWorker;

type
  TLLMChatFrame = class; // E8 前向声明：供 ILLMChatContext 回指宿主

  /// <summary>E8/WO-20260919-AUDIT-乙-R2（B4 同构）：异步回信上下文的引用计数接口。
  /// 工作体只捕获本接口（独立于宿主生命周期）；UI 回调经 TryBeginOwner 在守护锁内
  /// 检查宿主注册态，宿主 Destroy 先 UnregisterOwner 再释放 → 迟到回调丢弃，
  /// 消除超时 Evacuate 后 Synchronize 体解引用已释放宿主（Self）的 UAF（审计 T3 同族）。</summary>
  ILLMChatContext = interface
    ['{6B2F4A18-3C07-4E5D-9A1B-7D0E2F5C8B34}']
    function TryBeginOwner(out AFrame: TLLMChatFrame): Boolean;
    procedure UnregisterOwner;
  end;

  /// <summary>ILLMChatContext 实现：持宿主裸指针 + 注册位，二者由 FLock 串行化守护。</summary>
  TLLMChatContext = class(TInterfacedObject, ILLMChatContext)
  private
    FLock: TCriticalSection;
    FOwner: TLLMChatFrame;   // 仅 FRegistered=True 时有效
    FRegistered: Boolean;
  public
    constructor Create(AOwner: TLLMChatFrame);
    destructor Destroy; override;
    function TryBeginOwner(out AFrame: TLLMChatFrame): Boolean;
    procedure UnregisterOwner;
  end;

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
    FCurrentWorker: TManagedWorker;
    FCurrentCtx: ILLMChatContext;
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

// UI2-018: resourcestrings allow per-language overrides via satellite .res
// files without pulling in the full i18n manager dependency here.
resourcestring
  SBtnSend = 'Send';      // zh-CN: '发送'
  SBtnCancel = 'Cancel';  // zh-CN: '取消'
  SBtnClear = 'Clear';    // zh-CN: '清空'
  SStatusCancelled = 'Cancelled';  // zh-CN: '已取消'
  SStatusCleared = 'Cleared';      // zh-CN: '已清空'

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
  // REVIEW5-UI-004 / Top20 T3.5 改写（WO-20260919-AUDIT-乙-R2 E8）：
  // 后台任务改走 TManagedWorker + 引用计数回信上下文（B4 同构）。Destroy 保留 2 秒预算语义：
  // Cancel→Wait(2000)，超时则 Evacuate 移交托管隔离区（看护线程不等待挂起中的
  // Synchronize 体，主线程自毁不会死锁）。先 UnregisterOwner：被 Evacuate 的后台体
  // 之后晚到的 Synchronize 经 TryBeginOwner 见未注册即丢弃，不再触碰本已释放宿主。
  if FIsGenerating and Assigned(FClient) then
    FClient.Cancel;
  if Assigned(FCurrentWorker) then
  begin
    FCurrentWorker.Cancel;
    if not FCurrentWorker.Wait(2000) then
      FCurrentWorker.Evacuate
    else
      FCurrentWorker.Free;
    FCurrentWorker := nil;
  end;
  if Assigned(FCurrentCtx) then
    FCurrentCtx.UnregisterOwner;
  FCurrentCtx := nil;

  if FOwnsClient and Assigned(FClient) then
    FreeAndNil(FClient);
  FreeAndNil(FHistory);
  FreeAndNil(FChatItems);
  inherited;
end;

{ TLLMChatContext }

constructor TLLMChatContext.Create(AOwner: TLLMChatFrame);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FOwner := AOwner;
  FRegistered := True;
end;

destructor TLLMChatContext.Destroy;
begin
  FreeAndNil(FLock);
  inherited;
end;

function TLLMChatContext.TryBeginOwner(out AFrame: TLLMChatFrame): Boolean;
begin
  // UI 线程串行执行本方法所在的 Synchronize 体；与宿主 Destroy 的 UnregisterOwner
  // 同锁串行，返回 True 即表示宿主仍存活且本次回调期间不会被同线程的 Destroy 插入。
  FLock.Enter;
  try
    if FRegistered then
    begin
      AFrame := FOwner;
      Result := True;
    end
    else
    begin
      AFrame := nil;
      Result := False;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TLLMChatContext.UnregisterOwner;
begin
  FLock.Enter;
  try
    FRegistered := False;
    FOwner := nil;
  finally
    FLock.Leave;
  end;
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
  FBtnSend.Caption := SBtnSend;
  FBtnSend.Top := 4;
  FBtnSend.Left := 4;
  FBtnSend.Width := 80;
  FBtnSend.Height := 25;
  FBtnSend.OnClick := OnBtnSendClick;
  
  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := FPanelInput;
  FBtnCancel.Caption := SBtnCancel;
  FBtnCancel.Top := 32;
  FBtnCancel.Left := 4;
  FBtnCancel.Width := 80;
  FBtnCancel.Height := 25;
  FBtnCancel.Enabled := False;
  FBtnCancel.OnClick := OnBtnCancelClick;
  
  FBtnClear := TButton.Create(Self);
  FBtnClear.Parent := FPanelInput;
  FBtnClear.Caption := SBtnClear;
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
  LCtx: ILLMChatContext;
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
  // VCL-001/002 + E8/B4 同构：先把无关注状态捕获为局部，后台体不直接解引用宿主；
  // UI 回写经引用计数上下文 LCtx 的注册守护（TryBeginOwner）在 UI 线程串行执行，
  // 宿主 Destroy 先 UnregisterOwner → 超时 Evacuate 后晚到的回写被安全丢弃。
  var LClient := FClient;
  var LEnableStreaming := FEnableStreaming;
  var LMessages := FHistory.GetMessages;
  var LLastUserMessage := FHistory.GetLastUserMessage;
  // 上一轮 worker 无论正常结束还是已被 Evacuate（字段仅残留失效引用，
  // 此处只覆写不解引用）均在此回收/清位；上一轮回信随之作废。Destroy 是另一释放点。
  FreeAndNil(FCurrentWorker);
  FCurrentCtx := nil;
  LCtx := TLLMChatContext.Create(Self);
  FCurrentCtx := LCtx;
  FCurrentWorker := TManagedWorker.Create(
    procedure
    var
      Response: TChatResponse;
      LocalStreamBuffer: string;
      LocalContent: string;
      LocalErrorMsg: string;
      LocalTokenCount: Integer;
    begin
      LocalStreamBuffer := '';

      try
        if LEnableStreaming then
        begin
          // Streaming mode - use simple Chat for now since stream callback is complex
          if LClient.Chat(LLastUserMessage, Response) then
          begin
            LocalContent := Response.Content;
            LocalTokenCount := Response.Usage.TotalTokens;
            
            TThread.Synchronize(TThread(nil),
              procedure
              var
                LFrame: TLLMChatFrame;
                Item: TChatDisplayItem;
              begin
                if not LCtx.TryBeginOwner(LFrame) then Exit; // 宿主已释放→丢弃晚到回调
                if Assigned(LFrame.FRichEditChat) and LFrame.FRichEditChat.HandleAllocated and
                   Assigned(LFrame.FHistory) and Assigned(LFrame.FChatItems) then
                begin
                  LFrame.FRichEditChat.SelStart := Length(LFrame.FRichEditChat.Text);
                  LFrame.FRichEditChat.SelText := LocalContent + #13#10#13#10;

                  LFrame.FHistory.AddAssistantMessage(LocalContent);

                  Item.Role := mrAssistant;
                  Item.Content := LocalContent;
                  Item.Timestamp := Now;
                  Item.TokenCount := LocalTokenCount;
                  LFrame.FChatItems.Add(Item);

                  LFrame.FIsGenerating := False;
                  LFrame.UpdateUI;
                  LFrame.SetStatus('完成 (' + IntToStr(LocalTokenCount) + ' tokens)');

                  if Assigned(LFrame.FOnResponseReceived) then
                    LFrame.FOnResponseReceived(LFrame, Response);
                end;
              end);
          end
          else
          begin
            LocalErrorMsg := Response.ErrorMessage;
            TThread.Synchronize(TThread(nil),
              procedure
              var
                LFrame: TLLMChatFrame;
              begin
                if not LCtx.TryBeginOwner(LFrame) then Exit;
                if Assigned(LFrame.FRichEditChat) and LFrame.FRichEditChat.HandleAllocated then
                begin
                  LFrame.FRichEditChat.SelStart := Length(LFrame.FRichEditChat.Text);
                  LFrame.FRichEditChat.SelAttributes.Color := clRed;
                  LFrame.FRichEditChat.SelText := '错误: ' + LocalErrorMsg + #13#10#13#10;
                  LFrame.FRichEditChat.SelAttributes.Color := clBlack;

                  LFrame.FIsGenerating := False;
                  LFrame.UpdateUI;
                  LFrame.SetStatus('错误: ' + LocalErrorMsg);
                end;
              end);
          end;
        end
        else
        begin
          // Non-streaming mode
          Response := LClient.ChatWithHistory(LMessages);
          LocalContent := Response.Content;
          LocalTokenCount := Response.Usage.TotalTokens;
          LocalErrorMsg := Response.ErrorMessage;
          
          TThread.Synchronize(TThread(nil),
            procedure
            var
              LFrame: TLLMChatFrame;
              Item: TChatDisplayItem;
            begin
              if not LCtx.TryBeginOwner(LFrame) then Exit;
              if Assigned(LFrame.FRichEditChat) and LFrame.FRichEditChat.HandleAllocated and
                 Assigned(LFrame.FHistory) and Assigned(LFrame.FChatItems) then
              begin
                if Response.Success then
                begin
                  LFrame.FRichEditChat.SelStart := Length(LFrame.FRichEditChat.Text);
                  LFrame.FRichEditChat.SelText := LocalContent + #13#10#13#10;

                  LFrame.FHistory.AddAssistantMessage(LocalContent);

                  Item.Role := mrAssistant;
                  Item.Content := LocalContent;
                  Item.Timestamp := Now;
                  Item.TokenCount := LocalTokenCount;
                  LFrame.FChatItems.Add(Item);

                  LFrame.SetStatus('完成 (' + IntToStr(LocalTokenCount) + ' tokens)');
                end
                else
                begin
                  LFrame.FRichEditChat.SelStart := Length(LFrame.FRichEditChat.Text);
                  LFrame.FRichEditChat.SelAttributes.Color := clRed;
                  LFrame.FRichEditChat.SelText := '错误: ' + LocalErrorMsg + #13#10#13#10;
                  LFrame.FRichEditChat.SelAttributes.Color := clBlack;

                  LFrame.SetStatus('错误: ' + LocalErrorMsg);
                end;

                LFrame.FIsGenerating := False;
                LFrame.UpdateUI;

                if Assigned(LFrame.FOnResponseReceived) then
                  LFrame.FOnResponseReceived(LFrame, Response);
              end;
            end);
        end;
      except
        on E: Exception do
        begin
          LocalErrorMsg := E.Message;
          TThread.Synchronize(TThread(nil),
            procedure
            var
              LFrame: TLLMChatFrame;
            begin
              if not LCtx.TryBeginOwner(LFrame) then Exit;
              if Assigned(LFrame.FRichEditChat) and LFrame.FRichEditChat.HandleAllocated then
              begin
                LFrame.FRichEditChat.SelStart := Length(LFrame.FRichEditChat.Text);
                LFrame.FRichEditChat.SelAttributes.Color := clRed;
                LFrame.FRichEditChat.SelText := '错误: ' + LocalErrorMsg + #13#10#13#10;
                LFrame.FRichEditChat.SelAttributes.Color := clBlack;

                LFrame.FIsGenerating := False;
                LFrame.UpdateUI;
                LFrame.SetStatus('错误: ' + LocalErrorMsg);
              end;
            end);
        end;
      end;
    end, 'VCL.LLMChatFrame.Send');
  FCurrentWorker.Start;
end;

procedure TLLMChatFrame.DoCancel;
begin
  if FIsGenerating and Assigned(FClient) then
  begin
    FClient.Cancel;
    SetStatus(SStatusCancelled);
  end;
end;

procedure TLLMChatFrame.DoClear;
begin
  if not FIsGenerating then
  begin
    FRichEditChat.Clear;
    FChatItems.Clear;
    FHistory.Clear;
    SetStatus(SStatusCleared);
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
