unit Tray.DevLogFrame;

{*******************************************************************************
  DeepBaseTray - 开发日志录入 Frame
  
  功能:
  - 快速录入开发日志
  - 项目名下拉框（记住历史）
  - 标签选择
  - 今日日志列表
*******************************************************************************}

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.CheckLst,
  Tray.Database;

type
  TDevLogFrame = class(TFrame)
  private
    { 界面组件 }
    FPnlInput: TPanel;
    FCboProject: TComboBox;
    FLblProject: TLabel;
    FMemRequirement: TMemo;
    FLblRequirement: TLabel;
    FMemImplementation: TMemo;
    FLblImplementation: TLabel;
    FPnlTags: TPanel;
    FLblTags: TLabel;
    FChkBugFix: TCheckBox;
    FChkNewFeature: TCheckBox;
    FChkRefactor: TCheckBox;
    FChkDoc: TCheckBox;
    FChkTest: TCheckBox;
    FBtnSave: TButton;
    FBtnClear: TButton;
    
    { 今日日志列表 }
    FPnlList: TPanel;
    FLblToday: TLabel;
    FLvLogs: TListView;
    FSplitter: TSplitter;
    
    { 状态 }
    FEditingId: Integer;
    
    { 方法 }
    procedure CreateUI;
    procedure CreateInputPanel;
    procedure CreateListPanel;
    procedure LoadProjectHistory;
    procedure LoadTodayLogs;
    function GetSelectedTags: string;
    procedure SetSelectedTags(const ATags: string);
    procedure ClearInput;
    
    { 事件 }
    procedure OnBtnSaveClick(Sender: TObject);
    procedure OnBtnClearClick(Sender: TObject);
    procedure OnLogDblClick(Sender: TObject);
    procedure OnLogKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure RefreshData;
  end;

implementation

uses
  System.DateUtils;

const
  TAG_BUGFIX = 'Bug修复';
  TAG_NEWFEATURE = '新功能';
  TAG_REFACTOR = '重构';
  TAG_DOC = '文档';
  TAG_TEST = '测试';

{ TDevLogFrame }

constructor TDevLogFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEditingId := -1;
  CreateUI;
  RefreshData;
end;

destructor TDevLogFrame.Destroy;
begin
  inherited;
end;

procedure TDevLogFrame.CreateUI;
begin
  // 设置 Frame 属性
  Width := 300;
  Height := 400;
  
  // 分隔条
  FSplitter := TSplitter.Create(Self);
  FSplitter.Parent := Self;
  FSplitter.Align := alBottom;
  FSplitter.Height := 5;
  FSplitter.Cursor := crVSplit;
  
  // 创建列表面板（放在下方）
  CreateListPanel;
  
  // 创建输入面板（放在上方）
  CreateInputPanel;
end;

procedure TDevLogFrame.CreateInputPanel;
var
  Y: Integer;
begin
  FPnlInput := TPanel.Create(Self);
  FPnlInput.Parent := Self;
  FPnlInput.Align := alClient;
  FPnlInput.BevelOuter := bvNone;
  FPnlInput.Caption := '';
  
  Y := 5;
  
  // 项目名标签
  FLblProject := TLabel.Create(Self);
  FLblProject.Parent := FPnlInput;
  FLblProject.Caption := '项目名:';
  FLblProject.Left := 5;
  FLblProject.Top := Y;
  Inc(Y, 18);
  
  // 项目名下拉框
  FCboProject := TComboBox.Create(Self);
  FCboProject.Parent := FPnlInput;
  FCboProject.Left := 5;
  FCboProject.Top := Y;
  FCboProject.Width := FPnlInput.Width - 10;
  FCboProject.Anchors := [akLeft, akTop, akRight];
  FCboProject.Style := csDropDown;  // 允许输入新项目
  Inc(Y, 28);
  
  // 需求标签
  FLblRequirement := TLabel.Create(Self);
  FLblRequirement.Parent := FPnlInput;
  FLblRequirement.Caption := '需求描述:';
  FLblRequirement.Left := 5;
  FLblRequirement.Top := Y;
  Inc(Y, 18);
  
  // 需求输入框
  FMemRequirement := TMemo.Create(Self);
  FMemRequirement.Parent := FPnlInput;
  FMemRequirement.Left := 5;
  FMemRequirement.Top := Y;
  FMemRequirement.Width := FPnlInput.Width - 10;
  FMemRequirement.Height := 50;
  FMemRequirement.Anchors := [akLeft, akTop, akRight];
  FMemRequirement.ScrollBars := ssVertical;
  Inc(Y, 55);
  
  // 实现标签
  FLblImplementation := TLabel.Create(Self);
  FLblImplementation.Parent := FPnlInput;
  FLblImplementation.Caption := '实现功能:';
  FLblImplementation.Left := 5;
  FLblImplementation.Top := Y;
  Inc(Y, 18);
  
  // 实现输入框
  FMemImplementation := TMemo.Create(Self);
  FMemImplementation.Parent := FPnlInput;
  FMemImplementation.Left := 5;
  FMemImplementation.Top := Y;
  FMemImplementation.Width := FPnlInput.Width - 10;
  FMemImplementation.Height := 50;
  FMemImplementation.Anchors := [akLeft, akTop, akRight];
  FMemImplementation.ScrollBars := ssVertical;
  Inc(Y, 55);
  
  // 标签选择面板
  FLblTags := TLabel.Create(Self);
  FLblTags.Parent := FPnlInput;
  FLblTags.Caption := '标签:';
  FLblTags.Left := 5;
  FLblTags.Top := Y;
  Inc(Y, 18);
  
  FPnlTags := TPanel.Create(Self);
  FPnlTags.Parent := FPnlInput;
  FPnlTags.Left := 5;
  FPnlTags.Top := Y;
  FPnlTags.Width := FPnlInput.Width - 10;
  FPnlTags.Height := 24;
  FPnlTags.Anchors := [akLeft, akTop, akRight];
  FPnlTags.BevelOuter := bvNone;
  FPnlTags.Caption := '';
  
  // 标签复选框
  FChkBugFix := TCheckBox.Create(Self);
  FChkBugFix.Parent := FPnlTags;
  FChkBugFix.Caption := 'Bug';
  FChkBugFix.Left := 0;
  FChkBugFix.Top := 0;
  FChkBugFix.Width := 50;
  
  FChkNewFeature := TCheckBox.Create(Self);
  FChkNewFeature.Parent := FPnlTags;
  FChkNewFeature.Caption := '新功能';
  FChkNewFeature.Left := 50;
  FChkNewFeature.Top := 0;
  FChkNewFeature.Width := 60;
  
  FChkRefactor := TCheckBox.Create(Self);
  FChkRefactor.Parent := FPnlTags;
  FChkRefactor.Caption := '重构';
  FChkRefactor.Left := 110;
  FChkRefactor.Top := 0;
  FChkRefactor.Width := 50;
  
  FChkDoc := TCheckBox.Create(Self);
  FChkDoc.Parent := FPnlTags;
  FChkDoc.Caption := '文档';
  FChkDoc.Left := 160;
  FChkDoc.Top := 0;
  FChkDoc.Width := 50;
  
  FChkTest := TCheckBox.Create(Self);
  FChkTest.Parent := FPnlTags;
  FChkTest.Caption := '测试';
  FChkTest.Left := 210;
  FChkTest.Top := 0;
  FChkTest.Width := 50;
  
  Inc(Y, 28);
  
  // 按钮面板
  FBtnSave := TButton.Create(Self);
  FBtnSave.Parent := FPnlInput;
  FBtnSave.Caption := '保存';
  FBtnSave.Left := 5;
  FBtnSave.Top := Y;
  FBtnSave.Width := 80;
  FBtnSave.OnClick := OnBtnSaveClick;
  
  FBtnClear := TButton.Create(Self);
  FBtnClear.Parent := FPnlInput;
  FBtnClear.Caption := '清空';
  FBtnClear.Left := 90;
  FBtnClear.Top := Y;
  FBtnClear.Width := 80;
  FBtnClear.OnClick := OnBtnClearClick;
end;

procedure TDevLogFrame.CreateListPanel;
begin
  FPnlList := TPanel.Create(Self);
  FPnlList.Parent := Self;
  FPnlList.Align := alBottom;
  FPnlList.Height := 150;
  FPnlList.BevelOuter := bvNone;
  FPnlList.Caption := '';
  
  // 标题
  FLblToday := TLabel.Create(Self);
  FLblToday.Parent := FPnlList;
  FLblToday.Caption := '今日日志:';
  FLblToday.Left := 5;
  FLblToday.Top := 5;
  FLblToday.Font.Style := [fsBold];
  
  // 日志列表
  FLvLogs := TListView.Create(Self);
  FLvLogs.Parent := FPnlList;
  FLvLogs.Left := 5;
  FLvLogs.Top := 25;
  FLvLogs.Width := FPnlList.Width - 10;
  FLvLogs.Height := FPnlList.Height - 30;
  FLvLogs.Anchors := [akLeft, akTop, akRight, akBottom];
  FLvLogs.ViewStyle := vsReport;
  FLvLogs.ReadOnly := True;
  FLvLogs.RowSelect := True;
  FLvLogs.GridLines := True;
  FLvLogs.OnDblClick := OnLogDblClick;
  FLvLogs.OnKeyDown := OnLogKeyDown;
  
  // 列
  with FLvLogs.Columns.Add do
  begin
    Caption := '项目';
    Width := 80;
  end;
  with FLvLogs.Columns.Add do
  begin
    Caption := '需求';
    Width := 100;
  end;
  with FLvLogs.Columns.Add do
  begin
    Caption := '标签';
    Width := 60;
  end;
end;

procedure TDevLogFrame.LoadProjectHistory;
var
  Projects: TArray<string>;
  S: string;
begin
  FCboProject.Items.Clear;
  Projects := TrayDB.GetProjectHistory;
  for S in Projects do
    FCboProject.Items.Add(S);
    
  // 如果有项目历史，默认选中第一个
  if FCboProject.Items.Count > 0 then
    FCboProject.ItemIndex := 0;
end;

procedure TDevLogFrame.LoadTodayLogs;
var
  Logs: TArray<TDevLogRecord>;
  Log: TDevLogRecord;
  Item: TListItem;
begin
  FLvLogs.Items.Clear;
  Logs := TrayDB.GetTodayLogs;
  
  for Log in Logs do
  begin
    Item := FLvLogs.Items.Add;
    Item.Caption := Log.ProjectName;
    Item.SubItems.Add(Log.Requirement);
    Item.SubItems.Add(Log.Tags);
    Item.Data := Pointer(Log.Id);  // 保存 ID
  end;
  
  // 更新标题
  FLblToday.Caption := Format('今日日志 (%d):', [Length(Logs)]);
end;

function TDevLogFrame.GetSelectedTags: string;
var
  Tags: TStringList;
begin
  Tags := TStringList.Create;
  try
    Tags.Delimiter := ',';
    Tags.StrictDelimiter := True;
    
    if FChkBugFix.Checked then
      Tags.Add(TAG_BUGFIX);
    if FChkNewFeature.Checked then
      Tags.Add(TAG_NEWFEATURE);
    if FChkRefactor.Checked then
      Tags.Add(TAG_REFACTOR);
    if FChkDoc.Checked then
      Tags.Add(TAG_DOC);
    if FChkTest.Checked then
      Tags.Add(TAG_TEST);
      
    Result := Tags.DelimitedText;
  finally
    Tags.Free;
  end;
end;

procedure TDevLogFrame.SetSelectedTags(const ATags: string);
begin
  FChkBugFix.Checked := Pos(TAG_BUGFIX, ATags) > 0;
  FChkNewFeature.Checked := Pos(TAG_NEWFEATURE, ATags) > 0;
  FChkRefactor.Checked := Pos(TAG_REFACTOR, ATags) > 0;
  FChkDoc.Checked := Pos(TAG_DOC, ATags) > 0;
  FChkTest.Checked := Pos(TAG_TEST, ATags) > 0;
end;

procedure TDevLogFrame.ClearInput;
begin
  FEditingId := -1;
  FCboProject.Text := '';
  if FCboProject.Items.Count > 0 then
    FCboProject.ItemIndex := 0;
  FMemRequirement.Clear;
  FMemImplementation.Clear;
  FChkBugFix.Checked := False;
  FChkNewFeature.Checked := False;
  FChkRefactor.Checked := False;
  FChkDoc.Checked := False;
  FChkTest.Checked := False;
  FBtnSave.Caption := '保存';
end;

procedure TDevLogFrame.OnBtnSaveClick(Sender: TObject);
var
  ProjectName: string;
  Requirement: string;
  Implementation_: string;
  Tags: string;
begin
  ProjectName := Trim(FCboProject.Text);
  if ProjectName = '' then
  begin
    ShowMessage('请输入项目名');
    FCboProject.SetFocus;
    Exit;
  end;
  
  Requirement := Trim(FMemRequirement.Text);
  Implementation_ := Trim(FMemImplementation.Text);
  
  if (Requirement = '') and (Implementation_ = '') then
  begin
    ShowMessage('请输入需求描述或实现功能');
    FMemRequirement.SetFocus;
    Exit;
  end;
  
  Tags := GetSelectedTags;
  
  if FEditingId > 0 then
  begin
    // 更新
    TrayDB.UpdateDevLog(FEditingId, Requirement, Implementation_, Tags, '');
  end
  else
  begin
    // 新增
    TrayDB.AddDevLog(ProjectName, Requirement, Implementation_, Tags);
  end;
  
  ClearInput;
  RefreshData;
end;

procedure TDevLogFrame.OnBtnClearClick(Sender: TObject);
begin
  ClearInput;
end;

procedure TDevLogFrame.OnLogDblClick(Sender: TObject);
var
  Item: TListItem;
  LogId: Integer;
  Logs: TArray<TDevLogRecord>;
  Log: TDevLogRecord;
begin
  Item := FLvLogs.Selected;
  if Item = nil then Exit;
  
  LogId := Integer(Item.Data);
  
  // 查找日志详情
  Logs := TrayDB.GetTodayLogs;
  for Log in Logs do
  begin
    if Log.Id = LogId then
    begin
      // 填充到输入区域进行编辑
      FEditingId := LogId;
      FCboProject.Text := Log.ProjectName;
      FMemRequirement.Text := Log.Requirement;
      FMemImplementation.Text := Log.Implementation_;
      SetSelectedTags(Log.Tags);
      FBtnSave.Caption := '更新';
      Break;
    end;
  end;
end;

procedure TDevLogFrame.OnLogKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Item: TListItem;
  LogId: Integer;
begin
  if Key = VK_DELETE then
  begin
    Item := FLvLogs.Selected;
    if Item = nil then Exit;
    
    if MessageDlg('确定要删除这条日志吗？', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      LogId := Integer(Item.Data);
      TrayDB.DeleteDevLog(LogId);
      RefreshData;
    end;
  end;
end;

procedure TDevLogFrame.RefreshData;
begin
  LoadProjectHistory;
  LoadTodayLogs;
end;

end.
