{ ============================================================================
  DeepBase.VCL.FeedbackDialog - 用户反馈对话框
  
  版本: 1.0
  功能: 
    - 反馈表单（类型、内容、联系方式）
    - 附带日志选项
    - 异步提交到服务器
  ============================================================================ }

unit DeepBase.VCL.FeedbackDialog;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  Vcl.ComCtrls;

type
  TFeedbackType = (
    ftBugReport,      // Bug 报告
    ftFeatureRequest, // 功能请求
    ftQuestion,       // 问题咨询
    ftOther           // 其他
  );

  TFeedbackSubmitCallback = reference to procedure(Success: Boolean; const Message: string);

  TFeedbackDialog = class(TForm)
  private
    FPnlHeader: TPanel;
    FLblTitle: TLabel;
    FLblSubtitle: TLabel;
    FPnlContent: TPanel;
    FLblType: TLabel;
    FCmbType: TComboBox;
    FLblSubject: TLabel;
    FEdtSubject: TEdit;
    FLblContent: TLabel;
    FMmoContent: TMemo;
    FLblEmail: TLabel;
    FEdtEmail: TEdit;
    FChkIncludeLogs: TCheckBox;
    FChkIncludeSystemInfo: TCheckBox;
    FPnlButtons: TPanel;
    FBtnSubmit: TButton;
    FBtnCancel: TButton;
    FProgressBar: TProgressBar;
    FLblStatus: TLabel;
    
    FFeedbackUrl: string;
    FAppName: string;
    FAppVersion: string;
    FLogCollector: TFunc<string>;
    
    procedure CreateControls;
    procedure LayoutControls;
    procedure HandleSubmitClick(Sender: TObject);
    procedure HandleCancelClick(Sender: TObject);
    procedure HandleTypeChange(Sender: TObject);
    procedure UpdateSubmitButton;
    function CollectSystemInfo: string;
    function GetFeedbackTypeName(FT: TFeedbackType): string;
  protected
    procedure DoShow; override;
  public
    constructor Create(AOwner: TComponent); override;
    
    /// <summary>提交反馈（异步）</summary>
    procedure SubmitFeedback(Callback: TFeedbackSubmitCallback);
    
    /// <summary>显示反馈对话框</summary>
    class function Execute(const FeedbackUrl: string; 
      const AppName: string = ''; const AppVersion: string = ''): Boolean;
    
    /// <summary>反馈提交 URL</summary>
    property FeedbackUrl: string read FFeedbackUrl write FFeedbackUrl;
    
    /// <summary>应用名称</summary>
    property AppName: string read FAppName write FAppName;
    
    /// <summary>应用版本</summary>
    property AppVersion: string read FAppVersion write FAppVersion;
    
    /// <summary>日志收集函数</summary>
    property LogCollector: TFunc<string> read FLogCollector write FLogCollector;
  end;

implementation

uses
  System.IOUtils,
  System.TypInfo;

{ TFeedbackDialog }

constructor TFeedbackDialog.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  
  Caption := 'Send Feedback';
  Width := 500;
  Height := 480;
  Position := poMainFormCenter;
  BorderStyle := bsDialog;
  
  FAppName := 'Application';
  FAppVersion := '1.0';
  
  CreateControls;
  LayoutControls;
end;

procedure TFeedbackDialog.CreateControls;
begin
  // 头部面板
  FPnlHeader := TPanel.Create(Self);
  FPnlHeader.Parent := Self;
  FPnlHeader.Align := alTop;
  FPnlHeader.Height := 60;
  FPnlHeader.BevelOuter := bvNone;
  FPnlHeader.Color := clWhite;
  FPnlHeader.ParentBackground := False;
  
  FLblTitle := TLabel.Create(Self);
  FLblTitle.Parent := FPnlHeader;
  FLblTitle.Caption := 'Send Feedback';
  FLblTitle.Font.Size := 14;
  FLblTitle.Font.Style := [fsBold];
  
  FLblSubtitle := TLabel.Create(Self);
  FLblSubtitle.Parent := FPnlHeader;
  FLblSubtitle.Caption := 'We appreciate your feedback to help us improve';
  FLblSubtitle.Font.Color := clGray;
  
  // 内容面板
  FPnlContent := TPanel.Create(Self);
  FPnlContent.Parent := Self;
  FPnlContent.Align := alClient;
  FPnlContent.BevelOuter := bvNone;
  
  // 类型
  FLblType := TLabel.Create(Self);
  FLblType.Parent := FPnlContent;
  FLblType.Caption := 'Feedback Type:';
  
  FCmbType := TComboBox.Create(Self);
  FCmbType.Parent := FPnlContent;
  FCmbType.Style := csDropDownList;
  FCmbType.Items.Add('Bug Report');
  FCmbType.Items.Add('Feature Request');
  FCmbType.Items.Add('Question');
  FCmbType.Items.Add('Other');
  FCmbType.ItemIndex := 0;
  FCmbType.OnChange := HandleTypeChange;
  
  // 主题
  FLblSubject := TLabel.Create(Self);
  FLblSubject.Parent := FPnlContent;
  FLblSubject.Caption := 'Subject:';
  
  FEdtSubject := TEdit.Create(Self);
  FEdtSubject.Parent := FPnlContent;
  FEdtSubject.OnChange := HandleTypeChange;
  
  // 内容
  FLblContent := TLabel.Create(Self);
  FLblContent.Parent := FPnlContent;
  FLblContent.Caption := 'Description:';
  
  FMmoContent := TMemo.Create(Self);
  FMmoContent.Parent := FPnlContent;
  FMmoContent.ScrollBars := ssVertical;
  FMmoContent.OnChange := HandleTypeChange;
  
  // 邮箱
  FLblEmail := TLabel.Create(Self);
  FLblEmail.Parent := FPnlContent;
  FLblEmail.Caption := 'Email (optional):';
  
  FEdtEmail := TEdit.Create(Self);
  FEdtEmail.Parent := FPnlContent;
  
  // 选项
  FChkIncludeLogs := TCheckBox.Create(Self);
  FChkIncludeLogs.Parent := FPnlContent;
  FChkIncludeLogs.Caption := 'Include recent logs';
  FChkIncludeLogs.Checked := True;
  
  FChkIncludeSystemInfo := TCheckBox.Create(Self);
  FChkIncludeSystemInfo.Parent := FPnlContent;
  FChkIncludeSystemInfo.Caption := 'Include system information';
  FChkIncludeSystemInfo.Checked := True;
  
  // 状态
  FLblStatus := TLabel.Create(Self);
  FLblStatus.Parent := FPnlContent;
  FLblStatus.Caption := '';
  FLblStatus.Font.Color := clGray;
  
  FProgressBar := TProgressBar.Create(Self);
  FProgressBar.Parent := FPnlContent;
  FProgressBar.Style := pbstMarquee;
  FProgressBar.Visible := False;
  
  // 按钮面板
  FPnlButtons := TPanel.Create(Self);
  FPnlButtons.Parent := Self;
  FPnlButtons.Align := alBottom;
  FPnlButtons.Height := 50;
  FPnlButtons.BevelOuter := bvNone;
  
  FBtnSubmit := TButton.Create(Self);
  FBtnSubmit.Parent := FPnlButtons;
  FBtnSubmit.Caption := 'Submit';
  FBtnSubmit.Default := True;
  FBtnSubmit.Enabled := False;
  FBtnSubmit.OnClick := HandleSubmitClick;
  
  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := FPnlButtons;
  FBtnCancel.Caption := 'Cancel';
  FBtnCancel.Cancel := True;
  FBtnCancel.OnClick := HandleCancelClick;
end;

procedure TFeedbackDialog.LayoutControls;
var
  Y: Integer;
begin
  // 头部
  FLblTitle.SetBounds(16, 12, 300, 24);
  FLblSubtitle.SetBounds(16, 36, 400, 16);
  
  // 内容
  Y := 16;
  
  FLblType.SetBounds(16, Y, 100, 16);
  Inc(Y, 18);
  FCmbType.SetBounds(16, Y, 200, 24);
  Inc(Y, 32);
  
  FLblSubject.SetBounds(16, Y, 100, 16);
  Inc(Y, 18);
  FEdtSubject.SetBounds(16, Y, ClientWidth - 32, 24);
  Inc(Y, 32);
  
  FLblContent.SetBounds(16, Y, 100, 16);
  Inc(Y, 18);
  FMmoContent.SetBounds(16, Y, ClientWidth - 32, 100);
  Inc(Y, 108);
  
  FLblEmail.SetBounds(16, Y, 150, 16);
  Inc(Y, 18);
  FEdtEmail.SetBounds(16, Y, 250, 24);
  Inc(Y, 32);
  
  FChkIncludeLogs.SetBounds(16, Y, 200, 20);
  Inc(Y, 24);
  FChkIncludeSystemInfo.SetBounds(16, Y, 200, 20);
  Inc(Y, 28);
  
  FLblStatus.SetBounds(16, Y, ClientWidth - 32, 16);
  Inc(Y, 20);
  FProgressBar.SetBounds(16, Y, ClientWidth - 32, 16);
  
  // 按钮
  FBtnCancel.SetBounds(ClientWidth - 92, 12, 80, 28);
  FBtnSubmit.SetBounds(ClientWidth - 180, 12, 80, 28);
end;

procedure TFeedbackDialog.DoShow;
begin
  inherited;
  FEdtSubject.SetFocus;
end;

procedure TFeedbackDialog.HandleTypeChange(Sender: TObject);
begin
  UpdateSubmitButton;
end;

procedure TFeedbackDialog.UpdateSubmitButton;
begin
  FBtnSubmit.Enabled := (Trim(FEdtSubject.Text) <> '') and 
                        (Trim(FMmoContent.Text) <> '');
end;

function TFeedbackDialog.GetFeedbackTypeName(FT: TFeedbackType): string;
begin
  case FT of
    ftBugReport: Result := 'bug_report';
    ftFeatureRequest: Result := 'feature_request';
    ftQuestion: Result := 'question';
    ftOther: Result := 'other';
  else
    Result := 'unknown';
  end;
end;

function TFeedbackDialog.CollectSystemInfo: string;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Add('OS: ' + TOSVersion.ToString);
    SL.Add('App: ' + FAppName);
    SL.Add('Version: ' + FAppVersion);
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

procedure TFeedbackDialog.HandleSubmitClick(Sender: TObject);
begin
  SubmitFeedback(
    procedure(Success: Boolean; const Message: string)
    begin
      if Success then
      begin
        FLblStatus.Caption := 'Feedback submitted successfully!';
        FLblStatus.Font.Color := clGreen;
        FProgressBar.Visible := False;
        
        // 延迟关闭
        TThread.CreateAnonymousThread(
          procedure
          begin
            Sleep(1500);
            TThread.Queue(nil,
              procedure
              begin
                Self.ModalResult := mrOk;
              end);
          end).Start;
      end
      else
      begin
        FLblStatus.Caption := 'Submit failed: ' + Message;
        FLblStatus.Font.Color := clRed;
        FProgressBar.Visible := False;
        FBtnSubmit.Enabled := True;
      end;
    end);
end;

procedure TFeedbackDialog.HandleCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TFeedbackDialog.SubmitFeedback(Callback: TFeedbackSubmitCallback);
var
  FeedbackType: TFeedbackType;
  Subject, Content, Email, Logs, SystemInfo: string;
  // UI2-016 fix: main-thread snapshots of fields that the background task
  // needs. Accessing FFeedbackUrl / FAppName / FAppVersion from a worker
  // thread while the UI thread could still mutate them is a data race.
  LFeedbackUrl: string;
  LAppName: string;
  LAppVersion: string;
  Client: THTTPClient;
  Response: IHTTPResponse;
  JsonObj: TJSONObject;
  Body: TStringStream;
  Success: Boolean;
  Msg: string;
begin
  FeedbackType := TFeedbackType(FCmbType.ItemIndex);
  Subject := Trim(FEdtSubject.Text);
  Content := Trim(FMmoContent.Text);
  Email := Trim(FEdtEmail.Text);

  if FChkIncludeLogs.Checked and Assigned(FLogCollector) then
    Logs := FLogCollector()
  else
    Logs := '';

  if FChkIncludeSystemInfo.Checked then
    SystemInfo := CollectSystemInfo
  else
    SystemInfo := '';

  // UI2-016 fix: snapshot the remaining fields on the main thread before
  // the background task starts.
  LFeedbackUrl := FFeedbackUrl;
  LAppName := FAppName;
  LAppVersion := FAppVersion;

  // 显示进度
  FBtnSubmit.Enabled := False;
  FProgressBar.Visible := True;
  FLblStatus.Caption := 'Submitting feedback...';
  FLblStatus.Font.Color := clGray;

  // 异步提交
  TThread.CreateAnonymousThread(
    procedure
    begin
      Success := False;
      Msg := '';

      if LFeedbackUrl = '' then
      begin
        // 无提交 URL，模拟成功
        Sleep(1000);
        Success := True;
        Msg := 'Feedback saved locally';
      end
      else
      begin
        Client := THTTPClient.Create;
        try
          try
            Client.ContentType := 'application/json';

            JsonObj := TJSONObject.Create;
            try
              JsonObj.AddPair('type', GetFeedbackTypeName(FeedbackType));
              JsonObj.AddPair('subject', Subject);
              JsonObj.AddPair('content', Content);
              JsonObj.AddPair('email', Email);
              JsonObj.AddPair('app', LAppName);
              JsonObj.AddPair('version', LAppVersion);

              if Logs <> '' then
                JsonObj.AddPair('logs', Logs);
              if SystemInfo <> '' then
                JsonObj.AddPair('system_info', SystemInfo);

              // UI2-003 fix: keep a handle to the body stream so we can free it
              // in the enclosing finally. THTTPClient.Post does NOT take
              // ownership of the ASource stream — the caller must free it.
              Body := TStringStream.Create(JsonObj.ToString, TEncoding.UTF8);
              try
                Response := Client.Post(LFeedbackUrl, Body);
              finally
                Body.Free;
              end;
            finally
              JsonObj.Free;
            end;

            if (Response.StatusCode >= 200) and (Response.StatusCode < 300) then
            begin
              Success := True;
              Msg := 'OK';
            end
            else
            begin
              Msg := 'Server returned: ' + Response.StatusCode.ToString;
            end;
          except
            on E: Exception do
              Msg := E.Message;
          end;
        finally
          Client.Free;
        end;
      end;

      TThread.Queue(nil,
        procedure
        begin
          if Assigned(Callback) then
            Callback(Success, Msg);
        end);
    end).Start;
end;

class function TFeedbackDialog.Execute(const FeedbackUrl: string;
  const AppName: string; const AppVersion: string): Boolean;
var
  Dlg: TFeedbackDialog;
begin
  Dlg := TFeedbackDialog.Create(Application);
  try
    Dlg.FeedbackUrl := FeedbackUrl;
    if AppName <> '' then
      Dlg.AppName := AppName;
    if AppVersion <> '' then
      Dlg.AppVersion := AppVersion;
    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

end.
