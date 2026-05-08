unit Tray.SchedulerFrame;

{*******************************************************************************
  DeepBaseTray - 定时任务管理 Frame
  
  功能:
  - 创建/编辑/删除定时任务
  - 任务类型：运行命令/打开程序/执行脚本
  - 定时方式：一次性/每日/每周/间隔
  - 任务启用/禁用
  - 任务执行日志
*******************************************************************************}

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI,
  System.SysUtils, System.Classes, System.Generics.Collections, System.DateUtils,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls,
  FireDAC.Comp.Client,
  Tray.Database;

type
  TTaskType = (ttCommand, ttProgram, ttScript);
  TScheduleType = (stOnce, stDaily, stWeekly, stInterval);
  
  TScheduledTask = record
    Id: Integer;
    TaskName: string;
    TaskType: TTaskType;
    Command: string;
    ScheduleType: TScheduleType;
    ScheduleTime: TTime;
    ScheduleDate: TDate;
    IntervalMinutes: Integer;
    WeekDays: string;  // 如 "1,3,5" 表示周一三五
    IsEnabled: Boolean;
    LastRunAt: TDateTime;
    NextRunAt: TDateTime;
    CreatedAt: TDateTime;
  end;

  TSchedulerFrame = class(TFrame)
  private
    { 界面组件 - 任务列表 }
    FLvTasks: TListView;
    FPnlButtons: TPanel;
    FBtnAdd: TButton;
    FBtnEdit: TButton;
    FBtnDelete: TButton;
    FBtnRun: TButton;
    
    { 界面组件 - 编辑区 }
    FPnlEdit: TPanel;
    FEdtName: TEdit;
    FLblName: TLabel;
    FCboTaskType: TComboBox;
    FLblTaskType: TLabel;
    FEdtCommand: TEdit;
    FLblCommand: TLabel;
    FBtnBrowse: TButton;
    FCboScheduleType: TComboBox;
    FLblScheduleType: TLabel;
    FDtpTime: TDateTimePicker;
    FDtpDate: TDateTimePicker;
    FEdtInterval: TEdit;
    FLblInterval: TLabel;
    FChkEnabled: TCheckBox;
    FBtnSave: TButton;
    FBtnCancel: TButton;
    
    { 定时器 }
    FCheckTimer: TTimer;
    
    { 数据 }
    FTasks: TList<TScheduledTask>;
    FEditingId: Integer;
    
    { 方法 }
    procedure CreateUI;
    procedure CreateTaskList;
    procedure CreateEditPanel;
    procedure LoadTasks;
    procedure SaveTask;
    procedure RefreshTaskList;
    procedure ShowEditPanel(AShow: Boolean);
    procedure ClearEditPanel;
    procedure RunTask(const ATask: TScheduledTask);
    procedure CheckAndRunTasks;
    function GetTaskTypeText(AType: TTaskType): string;
    function GetScheduleTypeText(AType: TScheduleType): string;
    function CalculateNextRun(const ATask: TScheduledTask): TDateTime;
    
    { 事件 }
    procedure OnBtnAddClick(Sender: TObject);
    procedure OnBtnEditClick(Sender: TObject);
    procedure OnBtnDeleteClick(Sender: TObject);
    procedure OnBtnRunClick(Sender: TObject);
    procedure OnBtnBrowseClick(Sender: TObject);
    procedure OnBtnSaveClick(Sender: TObject);
    procedure OnBtnCancelClick(Sender: TObject);
    procedure OnScheduleTypeChange(Sender: TObject);
    procedure OnCheckTimer(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure RefreshData;
    procedure StartScheduler;
    procedure StopScheduler;
  end;

implementation

const
  TASK_TYPE_TEXTS: array[TTaskType] of string = ('命令', '程序', '脚本');
  SCHEDULE_TYPE_TEXTS: array[TScheduleType] of string = ('一次性', '每日', '每周', '间隔');

{ TSchedulerFrame }

constructor TSchedulerFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTasks := TList<TScheduledTask>.Create;
  FEditingId := -1;
  
  CreateUI;
  
  // 设置检查定时器（每分钟检查）
  FCheckTimer := TTimer.Create(Self);
  FCheckTimer.Interval := 60000;
  FCheckTimer.OnTimer := OnCheckTimer;
  FCheckTimer.Enabled := False;
  
  RefreshData;
end;

destructor TSchedulerFrame.Destroy;
begin
  FCheckTimer.Enabled := False;
  FTasks.Free;
  inherited;
end;

procedure TSchedulerFrame.CreateUI;
begin
  Width := 300;
  Height := 450;
  Color := $002D2D2D;
  
  CreateTaskList;
  CreateEditPanel;
  ShowEditPanel(False);
end;

procedure TSchedulerFrame.CreateTaskList;
begin
  // 按钮面板
  FPnlButtons := TPanel.Create(Self);
  FPnlButtons.Parent := Self;
  FPnlButtons.Align := alTop;
  FPnlButtons.Height := 35;
  FPnlButtons.BevelOuter := bvNone;
  FPnlButtons.Color := $002D2D2D;
  FPnlButtons.ParentBackground := False;
  
  FBtnAdd := TButton.Create(Self);
  FBtnAdd.Parent := FPnlButtons;
  FBtnAdd.Caption := '新建';
  FBtnAdd.Left := 5;
  FBtnAdd.Top := 5;
  FBtnAdd.Width := 50;
  FBtnAdd.OnClick := OnBtnAddClick;
  
  FBtnEdit := TButton.Create(Self);
  FBtnEdit.Parent := FPnlButtons;
  FBtnEdit.Caption := '编辑';
  FBtnEdit.Left := 60;
  FBtnEdit.Top := 5;
  FBtnEdit.Width := 50;
  FBtnEdit.OnClick := OnBtnEditClick;
  
  FBtnDelete := TButton.Create(Self);
  FBtnDelete.Parent := FPnlButtons;
  FBtnDelete.Caption := '删除';
  FBtnDelete.Left := 115;
  FBtnDelete.Top := 5;
  FBtnDelete.Width := 50;
  FBtnDelete.OnClick := OnBtnDeleteClick;
  
  FBtnRun := TButton.Create(Self);
  FBtnRun.Parent := FPnlButtons;
  FBtnRun.Caption := '运行';
  FBtnRun.Left := 170;
  FBtnRun.Top := 5;
  FBtnRun.Width := 50;
  FBtnRun.OnClick := OnBtnRunClick;
  
  // 任务列表
  FLvTasks := TListView.Create(Self);
  FLvTasks.Parent := Self;
  FLvTasks.Align := alClient;
  FLvTasks.ViewStyle := vsReport;
  FLvTasks.ReadOnly := True;
  FLvTasks.RowSelect := True;
  FLvTasks.GridLines := True;
  FLvTasks.Color := $002D2D2D;
  FLvTasks.Font.Color := clWhite;
  
  with FLvTasks.Columns.Add do
  begin
    Caption := '任务名';
    Width := 100;
  end;
  with FLvTasks.Columns.Add do
  begin
    Caption := '类型';
    Width := 50;
  end;
  with FLvTasks.Columns.Add do
  begin
    Caption := '计划';
    Width := 60;
  end;
  with FLvTasks.Columns.Add do
  begin
    Caption := '状态';
    Width := 50;
  end;
end;

procedure TSchedulerFrame.CreateEditPanel;
var
  Y: Integer;
begin
  FPnlEdit := TPanel.Create(Self);
  FPnlEdit.Parent := Self;
  FPnlEdit.Align := alBottom;
  FPnlEdit.Height := 240;
  FPnlEdit.BevelOuter := bvNone;
  FPnlEdit.Color := $003D3D3D;
  FPnlEdit.ParentBackground := False;
  
  Y := 8;
  
  // 任务名
  FLblName := TLabel.Create(Self);
  FLblName.Parent := FPnlEdit;
  FLblName.Caption := '任务名:';
  FLblName.Left := 8;
  FLblName.Top := Y;
  FLblName.Font.Color := clWhite;
  Inc(Y, 18);
  
  FEdtName := TEdit.Create(Self);
  FEdtName.Parent := FPnlEdit;
  FEdtName.Left := 8;
  FEdtName.Top := Y;
  FEdtName.Width := 180;
  FEdtName.Color := $002D2D2D;
  FEdtName.Font.Color := clWhite;
  Inc(Y, 28);
  
  // 任务类型
  FLblTaskType := TLabel.Create(Self);
  FLblTaskType.Parent := FPnlEdit;
  FLblTaskType.Caption := '类型:';
  FLblTaskType.Left := 8;
  FLblTaskType.Top := Y;
  FLblTaskType.Font.Color := clWhite;
  Inc(Y, 18);
  
  FCboTaskType := TComboBox.Create(Self);
  FCboTaskType.Parent := FPnlEdit;
  FCboTaskType.Left := 8;
  FCboTaskType.Top := Y;
  FCboTaskType.Width := 100;
  FCboTaskType.Style := csDropDownList;
  FCboTaskType.Items.Add('命令');
  FCboTaskType.Items.Add('程序');
  FCboTaskType.Items.Add('脚本');
  FCboTaskType.ItemIndex := 0;
  FCboTaskType.Color := $002D2D2D;
  FCboTaskType.Font.Color := clWhite;
  Inc(Y, 28);
  
  // 命令/程序
  FLblCommand := TLabel.Create(Self);
  FLblCommand.Parent := FPnlEdit;
  FLblCommand.Caption := '命令/路径:';
  FLblCommand.Left := 8;
  FLblCommand.Top := Y;
  FLblCommand.Font.Color := clWhite;
  Inc(Y, 18);
  
  FEdtCommand := TEdit.Create(Self);
  FEdtCommand.Parent := FPnlEdit;
  FEdtCommand.Left := 8;
  FEdtCommand.Top := Y;
  FEdtCommand.Width := 155;
  FEdtCommand.Color := $002D2D2D;
  FEdtCommand.Font.Color := clWhite;
  
  FBtnBrowse := TButton.Create(Self);
  FBtnBrowse.Parent := FPnlEdit;
  FBtnBrowse.Caption := '...';
  FBtnBrowse.Left := 168;
  FBtnBrowse.Top := Y;
  FBtnBrowse.Width := 25;
  FBtnBrowse.OnClick := OnBtnBrowseClick;
  Inc(Y, 28);
  
  // 计划类型
  FLblScheduleType := TLabel.Create(Self);
  FLblScheduleType.Parent := FPnlEdit;
  FLblScheduleType.Caption := '计划:';
  FLblScheduleType.Left := 8;
  FLblScheduleType.Top := Y;
  FLblScheduleType.Font.Color := clWhite;
  Inc(Y, 18);
  
  FCboScheduleType := TComboBox.Create(Self);
  FCboScheduleType.Parent := FPnlEdit;
  FCboScheduleType.Left := 8;
  FCboScheduleType.Top := Y;
  FCboScheduleType.Width := 80;
  FCboScheduleType.Style := csDropDownList;
  FCboScheduleType.Items.Add('一次性');
  FCboScheduleType.Items.Add('每日');
  FCboScheduleType.Items.Add('每周');
  FCboScheduleType.Items.Add('间隔');
  FCboScheduleType.ItemIndex := 0;
  FCboScheduleType.Color := $002D2D2D;
  FCboScheduleType.Font.Color := clWhite;
  FCboScheduleType.OnChange := OnScheduleTypeChange;
  
  FDtpTime := TDateTimePicker.Create(Self);
  FDtpTime.Parent := FPnlEdit;
  FDtpTime.Left := 95;
  FDtpTime.Top := Y;
  FDtpTime.Width := 75;
  FDtpTime.Kind := dtkTime;
  FDtpTime.Color := $002D2D2D;
  FDtpTime.Font.Color := clWhite;
  Inc(Y, 28);
  
  // 日期（用于一次性任务）
  FDtpDate := TDateTimePicker.Create(Self);
  FDtpDate.Parent := FPnlEdit;
  FDtpDate.Left := 8;
  FDtpDate.Top := Y;
  FDtpDate.Width := 100;
  FDtpDate.Kind := dtkDate;
  FDtpDate.Color := $002D2D2D;
  FDtpDate.Font.Color := clWhite;
  
  // 间隔分钟
  FLblInterval := TLabel.Create(Self);
  FLblInterval.Parent := FPnlEdit;
  FLblInterval.Caption := '间隔(分):';
  FLblInterval.Left := 8;
  FLblInterval.Top := Y + 3;
  FLblInterval.Font.Color := clWhite;
  FLblInterval.Visible := False;
  
  FEdtInterval := TEdit.Create(Self);
  FEdtInterval.Parent := FPnlEdit;
  FEdtInterval.Left := 65;
  FEdtInterval.Top := Y;
  FEdtInterval.Width := 50;
  FEdtInterval.Text := '30';
  FEdtInterval.Color := $002D2D2D;
  FEdtInterval.Font.Color := clWhite;
  FEdtInterval.Visible := False;
  
  // 启用复选框
  FChkEnabled := TCheckBox.Create(Self);
  FChkEnabled.Parent := FPnlEdit;
  FChkEnabled.Caption := '启用';
  FChkEnabled.Left := 120;
  FChkEnabled.Top := Y + 3;
  FChkEnabled.Checked := True;
  FChkEnabled.Font.Color := clWhite;
  Inc(Y, 30);
  
  // 保存/取消按钮
  FBtnSave := TButton.Create(Self);
  FBtnSave.Parent := FPnlEdit;
  FBtnSave.Caption := '保存';
  FBtnSave.Left := 8;
  FBtnSave.Top := Y;
  FBtnSave.Width := 75;
  FBtnSave.OnClick := OnBtnSaveClick;
  
  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := FPnlEdit;
  FBtnCancel.Caption := '取消';
  FBtnCancel.Left := 90;
  FBtnCancel.Top := Y;
  FBtnCancel.Width := 75;
  FBtnCancel.OnClick := OnBtnCancelClick;
end;

procedure TSchedulerFrame.LoadTasks;
var
  Query: TFDQuery;
  Task: TScheduledTask;
begin
  FTasks.Clear;
  
  if not TrayDB.Initialized then
    Exit;
    
  // 确保表存在
  try
    TrayDB.Connection.ExecSQL(
      'CREATE TABLE IF NOT EXISTS ScheduledTasks (' +
      '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
      '  TaskName TEXT NOT NULL,' +
      '  TaskType INTEGER NOT NULL DEFAULT 0,' +
      '  Command TEXT NOT NULL,' +
      '  ScheduleType INTEGER NOT NULL DEFAULT 0,' +
      '  ScheduleTime TEXT,' +
      '  ScheduleDate TEXT,' +
      '  IntervalMinutes INTEGER DEFAULT 30,' +
      '  WeekDays TEXT,' +
      '  IsEnabled INTEGER NOT NULL DEFAULT 1,' +
      '  LastRunAt DATETIME,' +
      '  NextRunAt DATETIME,' +
      '  CreatedAt DATETIME NOT NULL DEFAULT (datetime(''now'', ''localtime''))' +
      ')');
  except
    // 表可能已存在
  end;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := TrayDB.Connection;
    Query.SQL.Text := 'SELECT * FROM ScheduledTasks ORDER BY TaskName';
    Query.Open;
    
    while not Query.Eof do
    begin
      Task.Id := Query.FieldByName('Id').AsInteger;
      Task.TaskName := Query.FieldByName('TaskName').AsString;
      Task.TaskType := TTaskType(Query.FieldByName('TaskType').AsInteger);
      Task.Command := Query.FieldByName('Command').AsString;
      Task.ScheduleType := TScheduleType(Query.FieldByName('ScheduleType').AsInteger);
      Task.ScheduleTime := StrToTimeDef(Query.FieldByName('ScheduleTime').AsString, 0);
      Task.ScheduleDate := StrToDateDef(Query.FieldByName('ScheduleDate').AsString, Date);
      Task.IntervalMinutes := Query.FieldByName('IntervalMinutes').AsInteger;
      Task.WeekDays := Query.FieldByName('WeekDays').AsString;
      Task.IsEnabled := Query.FieldByName('IsEnabled').AsInteger = 1;
      if not Query.FieldByName('LastRunAt').IsNull then
        Task.LastRunAt := Query.FieldByName('LastRunAt').AsDateTime
      else
        Task.LastRunAt := 0;
      if not Query.FieldByName('NextRunAt').IsNull then
        Task.NextRunAt := Query.FieldByName('NextRunAt').AsDateTime
      else
        Task.NextRunAt := 0;
      Task.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      FTasks.Add(Task);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

procedure TSchedulerFrame.SaveTask;
var
  Query: TFDQuery;
  TaskName, Command: string;
  TaskType: TTaskType;
  ScheduleType: TScheduleType;
  NextRun: TDateTime;
begin
  TaskName := Trim(FEdtName.Text);
  if TaskName = '' then
  begin
    ShowMessage('请输入任务名');
    FEdtName.SetFocus;
    Exit;
  end;
  
  Command := Trim(FEdtCommand.Text);
  if Command = '' then
  begin
    ShowMessage('请输入命令或路径');
    FEdtCommand.SetFocus;
    Exit;
  end;
  
  TaskType := TTaskType(FCboTaskType.ItemIndex);
  ScheduleType := TScheduleType(FCboScheduleType.ItemIndex);
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := TrayDB.Connection;
    
    if FEditingId > 0 then
    begin
      Query.SQL.Text :=
        'UPDATE ScheduledTasks SET TaskName = :TaskName, TaskType = :TaskType, ' +
        'Command = :Command, ScheduleType = :ScheduleType, ScheduleTime = :ScheduleTime, ' +
        'ScheduleDate = :ScheduleDate, IntervalMinutes = :IntervalMinutes, ' +
        'IsEnabled = :IsEnabled, NextRunAt = :NextRunAt WHERE Id = :Id';
      Query.ParamByName('Id').AsInteger := FEditingId;
    end
    else
    begin
      Query.SQL.Text :=
        'INSERT INTO ScheduledTasks (TaskName, TaskType, Command, ScheduleType, ' +
        'ScheduleTime, ScheduleDate, IntervalMinutes, IsEnabled, NextRunAt) ' +
        'VALUES (:TaskName, :TaskType, :Command, :ScheduleType, :ScheduleTime, ' +
        ':ScheduleDate, :IntervalMinutes, :IsEnabled, :NextRunAt)';
    end;
    
    Query.ParamByName('TaskName').AsString := TaskName;
    Query.ParamByName('TaskType').AsInteger := Ord(TaskType);
    Query.ParamByName('Command').AsString := Command;
    Query.ParamByName('ScheduleType').AsInteger := Ord(ScheduleType);
    Query.ParamByName('ScheduleTime').AsString := TimeToStr(FDtpTime.Time);
    Query.ParamByName('ScheduleDate').AsString := DateToStr(FDtpDate.Date);
    Query.ParamByName('IntervalMinutes').AsInteger := StrToIntDef(FEdtInterval.Text, 30);
    Query.ParamByName('IsEnabled').AsInteger := Ord(FChkEnabled.Checked);
    
    // 计算下次运行时间
    var TempTask: TScheduledTask;
    TempTask.ScheduleType := ScheduleType;
    TempTask.ScheduleTime := FDtpTime.Time;
    TempTask.ScheduleDate := FDtpDate.Date;
    TempTask.IntervalMinutes := StrToIntDef(FEdtInterval.Text, 30);
    TempTask.LastRunAt := 0;
    NextRun := CalculateNextRun(TempTask);
    Query.ParamByName('NextRunAt').AsDateTime := NextRun;
    
    Query.ExecSQL;
  finally
    Query.Free;
  end;
  
  ShowEditPanel(False);
  RefreshData;
end;

procedure TSchedulerFrame.RefreshTaskList;
var
  Item: TListItem;
  Task: TScheduledTask;
begin
  FLvTasks.Items.BeginUpdate;
  try
    FLvTasks.Items.Clear;
    
    for Task in FTasks do
    begin
      Item := FLvTasks.Items.Add;
      Item.Caption := Task.TaskName;
      Item.SubItems.Add(GetTaskTypeText(Task.TaskType));
      Item.SubItems.Add(GetScheduleTypeText(Task.ScheduleType));
      if Task.IsEnabled then
        Item.SubItems.Add('启用')
      else
        Item.SubItems.Add('禁用');
      Item.Data := Pointer(Task.Id);
    end;
  finally
    FLvTasks.Items.EndUpdate;
  end;
end;

procedure TSchedulerFrame.ShowEditPanel(AShow: Boolean);
begin
  FPnlEdit.Visible := AShow;
  if AShow then
    FLvTasks.Align := alTop
  else
    FLvTasks.Align := alClient;
end;

procedure TSchedulerFrame.ClearEditPanel;
begin
  FEdtName.Text := '';
  FCboTaskType.ItemIndex := 0;
  FEdtCommand.Text := '';
  FCboScheduleType.ItemIndex := 0;
  FDtpTime.Time := EncodeTime(9, 0, 0, 0);
  FDtpDate.Date := Date;
  FEdtInterval.Text := '30';
  FChkEnabled.Checked := True;
  FEditingId := -1;
  OnScheduleTypeChange(nil);
end;

procedure TSchedulerFrame.RunTask(const ATask: TScheduledTask);
var
  ShellParams: string;
begin
  case ATask.TaskType of
    ttCommand:
      begin
        ShellExecute(0, 'open', 'cmd.exe', PChar('/c ' + ATask.Command), nil, SW_HIDE);
      end;
    ttProgram:
      begin
        ShellExecute(0, 'open', PChar(ATask.Command), nil, nil, SW_SHOWNORMAL);
      end;
    ttScript:
      begin
        // 根据扩展名判断脚本类型
        if ATask.Command.EndsWith('.ps1', True) then
          ShellParams := '-ExecutionPolicy Bypass -File "' + ATask.Command + '"'
        else
          ShellParams := ATask.Command;
        ShellExecute(0, 'open', 'powershell.exe', PChar(ShellParams), nil, SW_HIDE);
      end;
  end;
  
  // 更新最后运行时间
  TrayDB.Connection.ExecSQL(
    'UPDATE ScheduledTasks SET LastRunAt = ''' + 
    FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now) + ''' WHERE Id = ' +
    IntToStr(ATask.Id));
end;

procedure TSchedulerFrame.CheckAndRunTasks;
var
  Task: TScheduledTask;
  NowTime: TDateTime;
begin
  NowTime := Now;
  
  for Task in FTasks do
  begin
    if not Task.IsEnabled then
      Continue;
      
    if Task.NextRunAt <= NowTime then
    begin
      // 执行任务
      RunTask(Task);
      
      // 更新下次运行时间
      var NextRun := CalculateNextRun(Task);
      TrayDB.Connection.ExecSQL(Format(
        'UPDATE ScheduledTasks SET NextRunAt = ''%s'' WHERE Id = %d',
        [DateTimeToStr(NextRun), Task.Id]));
    end;
  end;
  
  // 刷新数据
  RefreshData;
end;

function TSchedulerFrame.GetTaskTypeText(AType: TTaskType): string;
begin
  Result := TASK_TYPE_TEXTS[AType];
end;

function TSchedulerFrame.GetScheduleTypeText(AType: TScheduleType): string;
begin
  Result := SCHEDULE_TYPE_TEXTS[AType];
end;

function TSchedulerFrame.CalculateNextRun(const ATask: TScheduledTask): TDateTime;
var
  NowTime: TDateTime;
  TaskTime: TDateTime;
begin
  NowTime := Now;
  
  case ATask.ScheduleType of
    stOnce:
      begin
        TaskTime := Trunc(ATask.ScheduleDate) + Frac(ATask.ScheduleTime);
        if TaskTime > NowTime then
          Result := TaskTime
        else
          Result := 0;  // 已过期
      end;
    stDaily:
      begin
        TaskTime := Trunc(NowTime) + Frac(ATask.ScheduleTime);
        if TaskTime <= NowTime then
          TaskTime := TaskTime + 1;  // 明天
        Result := TaskTime;
      end;
    stWeekly:
      begin
        // 简化实现：下周同一时间
        TaskTime := Trunc(NowTime) + Frac(ATask.ScheduleTime);
        if TaskTime <= NowTime then
          TaskTime := TaskTime + 7;
        Result := TaskTime;
      end;
    stInterval:
      begin
        if ATask.LastRunAt > 0 then
          Result := ATask.LastRunAt + (ATask.IntervalMinutes / 1440)
        else
          Result := NowTime + (ATask.IntervalMinutes / 1440);
      end;
  else
    Result := NowTime + 1;
  end;
end;

procedure TSchedulerFrame.OnBtnAddClick(Sender: TObject);
begin
  ClearEditPanel;
  ShowEditPanel(True);
  FEdtName.SetFocus;
end;

procedure TSchedulerFrame.OnBtnEditClick(Sender: TObject);
var
  Item: TListItem;
  TaskId: Integer;
  Task: TScheduledTask;
begin
  Item := FLvTasks.Selected;
  if Item = nil then
    Exit;
    
  TaskId := Integer(Item.Data);
  
  for Task in FTasks do
  begin
    if Task.Id = TaskId then
    begin
      FEdtName.Text := Task.TaskName;
      FCboTaskType.ItemIndex := Ord(Task.TaskType);
      FEdtCommand.Text := Task.Command;
      FCboScheduleType.ItemIndex := Ord(Task.ScheduleType);
      FDtpTime.Time := Task.ScheduleTime;
      FDtpDate.Date := Task.ScheduleDate;
      FEdtInterval.Text := IntToStr(Task.IntervalMinutes);
      FChkEnabled.Checked := Task.IsEnabled;
      FEditingId := Task.Id;
      OnScheduleTypeChange(nil);
      ShowEditPanel(True);
      Break;
    end;
  end;
end;

procedure TSchedulerFrame.OnBtnDeleteClick(Sender: TObject);
var
  Item: TListItem;
  TaskId: Integer;
begin
  Item := FLvTasks.Selected;
  if Item = nil then
    Exit;
    
  if MessageDlg('确定删除此任务?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
    
  TaskId := Integer(Item.Data);
  TrayDB.Connection.ExecSQL('DELETE FROM ScheduledTasks WHERE Id = ' + IntToStr(TaskId));
  RefreshData;
end;

procedure TSchedulerFrame.OnBtnRunClick(Sender: TObject);
var
  Item: TListItem;
  TaskId: Integer;
  Task: TScheduledTask;
begin
  Item := FLvTasks.Selected;
  if Item = nil then
    Exit;
    
  TaskId := Integer(Item.Data);
  
  for Task in FTasks do
  begin
    if Task.Id = TaskId then
    begin
      RunTask(Task);
      Break;
    end;
  end;
end;

procedure TSchedulerFrame.OnBtnBrowseClick(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(nil);
  try
    Dlg.Filter := '可执行文件|*.exe;*.bat;*.cmd;*.ps1|所有文件|*.*';
    if Dlg.Execute then
      FEdtCommand.Text := Dlg.FileName;
  finally
    Dlg.Free;
  end;
end;

procedure TSchedulerFrame.OnBtnSaveClick(Sender: TObject);
begin
  SaveTask;
end;

procedure TSchedulerFrame.OnBtnCancelClick(Sender: TObject);
begin
  ShowEditPanel(False);
  ClearEditPanel;
end;

procedure TSchedulerFrame.OnScheduleTypeChange(Sender: TObject);
begin
  case FCboScheduleType.ItemIndex of
    0: // 一次性
    begin
      FDtpDate.Visible := True;
      FLblInterval.Visible := False;
      FEdtInterval.Visible := False;
    end;
    1, 2: // 每日、每周
    begin
      FDtpDate.Visible := False;
      FLblInterval.Visible := False;
      FEdtInterval.Visible := False;
    end;
    3: // 间隔
    begin
      FDtpDate.Visible := False;
      FLblInterval.Visible := True;
      FEdtInterval.Visible := True;
    end;
  end;
end;

procedure TSchedulerFrame.OnCheckTimer(Sender: TObject);
begin
  CheckAndRunTasks;
end;

procedure TSchedulerFrame.RefreshData;
begin
  LoadTasks;
  RefreshTaskList;
end;

procedure TSchedulerFrame.StartScheduler;
begin
  FCheckTimer.Enabled := True;
end;

procedure TSchedulerFrame.StopScheduler;
begin
  FCheckTimer.Enabled := False;
end;

end.
