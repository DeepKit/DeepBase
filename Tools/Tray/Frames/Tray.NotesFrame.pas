unit Tray.NotesFrame;

{*******************************************************************************
  DeepBaseTray - 开发笔记与提醒 Frame
  
  功能:
  - 快速记录开发笔记
  - 设置提醒时间
  - 笔记分类（想法/TODO/问题/会议）
  - 笔记列表与搜索
  - 到期提醒通知
*******************************************************************************}

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.Generics.Collections, System.DateUtils,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls,
  FireDAC.Comp.Client,
  Tray.Database;

type
  TNoteCategory = (ncIdea, ncTodo, ncIssue, ncMeeting, ncOther);
  TNotePriority = (npLow, npMedium, npHigh);
  
  TNoteRecord = record
    Id: Integer;
    Title: string;
    Content: string;
    Category: TNoteCategory;
    Priority: TNotePriority;
    ReminderTime: TDateTime;
    HasReminder: Boolean;
    IsCompleted: Boolean;
    CreatedAt: TDateTime;
    UpdatedAt: TDateTime;
  end;
  
  TOnReminderDue = procedure(const ANote: TNoteRecord) of object;

  TNotesFrame = class(TFrame)
  private
    { 界面组件 - 输入区 }
    FPnlInput: TPanel;
    FEdtTitle: TEdit;
    FLblTitle: TLabel;
    FMemContent: TMemo;
    FLblContent: TLabel;
    FCboCategory: TComboBox;
    FLblCategory: TLabel;
    FCboProiority: TComboBox;
    FLblPriority: TLabel;
    FChkReminder: TCheckBox;
    FDtpReminder: TDateTimePicker;
    FBtnSave: TButton;
    FBtnClear: TButton;
    
    { 界面组件 - 列表区 }
    FPnlList: TPanel;
    FEdtSearch: TEdit;
    FCboFilter: TComboBox;
    FLvNotes: TListView;
    FSplitter: TSplitter;
    
    { 提醒定时器 }
    FReminderTimer: TTimer;
    FOnReminderDue: TOnReminderDue;
    
    { 状态 }
    FEditingId: Integer;
    FNotes: TList<TNoteRecord>;
    
    { 方法 }
    procedure CreateUI;
    procedure CreateInputPanel;
    procedure CreateListPanel;
    procedure LoadNotes;
    procedure SaveNote;
    procedure RefreshNotesList;
    procedure ClearInput;
    function GetCategoryText(ACat: TNoteCategory): string;
    function GetPriorityText(APri: TNotePriority): string;
    function GetCategoryFromIndex(AIndex: Integer): TNoteCategory;
    function GetPriorityFromIndex(AIndex: Integer): TNotePriority;
    procedure CheckReminders;
    function FilterNote(const ANote: TNoteRecord; const ASearch: string; AFilterIdx: Integer): Boolean;
    
    { 事件 }
    procedure OnBtnSaveClick(Sender: TObject);
    procedure OnBtnClearClick(Sender: TObject);
    procedure OnNoteDblClick(Sender: TObject);
    procedure OnNoteKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure OnChkReminderClick(Sender: TObject);
    procedure OnReminderTimer(Sender: TObject);
    procedure OnSearchChange(Sender: TObject);
    procedure OnFilterChange(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure RefreshData;
    procedure MarkComplete(ANoteId: Integer);
    
    property OnReminderDue: TOnReminderDue read FOnReminderDue write FOnReminderDue;
  end;

implementation

const
  CATEGORY_TEXTS: array[TNoteCategory] of string = ('💡 想法', '✅ TODO', '❗ 问题', '📅 会议', '📝 其他');
  PRIORITY_TEXTS: array[TNotePriority] of string = ('低', '中', '高');
  PRIORITY_COLORS: array[TNotePriority] of TColor = (clGray, clBlue, clRed);

{ TNotesFrame }

constructor TNotesFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEditingId := -1;
  FNotes := TList<TNoteRecord>.Create;
  
  CreateUI;
  
  // 设置提醒定时器（每分钟检查一次）
  FReminderTimer := TTimer.Create(Self);
  FReminderTimer.Interval := 60000;  // 1 分钟
  FReminderTimer.OnTimer := OnReminderTimer;
  FReminderTimer.Enabled := True;
  
  RefreshData;
end;

destructor TNotesFrame.Destroy;
begin
  FReminderTimer.Enabled := False;
  FNotes.Free;
  inherited;
end;

procedure TNotesFrame.CreateUI;
begin
  Width := 300;
  Height := 450;
  Color := $002D2D2D;
  
  // 分隔条
  FSplitter := TSplitter.Create(Self);
  FSplitter.Parent := Self;
  FSplitter.Align := alBottom;
  FSplitter.Height := 5;
  FSplitter.Cursor := crVSplit;
  FSplitter.Color := $003D3D3D;
  
  CreateListPanel;
  CreateInputPanel;
end;

procedure TNotesFrame.CreateInputPanel;
var
  Y: Integer;
begin
  FPnlInput := TPanel.Create(Self);
  FPnlInput.Parent := Self;
  FPnlInput.Align := alClient;
  FPnlInput.BevelOuter := bvNone;
  FPnlInput.Caption := '';
  FPnlInput.Color := $002D2D2D;
  FPnlInput.ParentBackground := False;
  
  Y := 8;
  
  // 标题
  FLblTitle := TLabel.Create(Self);
  FLblTitle.Parent := FPnlInput;
  FLblTitle.Caption := '标题:';
  FLblTitle.Left := 8;
  FLblTitle.Top := Y;
  FLblTitle.Font.Color := clWhite;
  Inc(Y, 18);
  
  FEdtTitle := TEdit.Create(Self);
  FEdtTitle.Parent := FPnlInput;
  FEdtTitle.Left := 8;
  FEdtTitle.Top := Y;
  FEdtTitle.Width := FPnlInput.Width - 16;
  FEdtTitle.Anchors := [akLeft, akTop, akRight];
  FEdtTitle.Color := $003D3D3D;
  FEdtTitle.Font.Color := clWhite;
  Inc(Y, 28);
  
  // 内容
  FLblContent := TLabel.Create(Self);
  FLblContent.Parent := FPnlInput;
  FLblContent.Caption := '内容:';
  FLblContent.Left := 8;
  FLblContent.Top := Y;
  FLblContent.Font.Color := clWhite;
  Inc(Y, 18);
  
  FMemContent := TMemo.Create(Self);
  FMemContent.Parent := FPnlInput;
  FMemContent.Left := 8;
  FMemContent.Top := Y;
  FMemContent.Width := FPnlInput.Width - 16;
  FMemContent.Height := 60;
  FMemContent.Anchors := [akLeft, akTop, akRight];
  FMemContent.ScrollBars := ssVertical;
  FMemContent.Color := $003D3D3D;
  FMemContent.Font.Color := clWhite;
  Inc(Y, 68);
  
  // 分类和优先级
  FLblCategory := TLabel.Create(Self);
  FLblCategory.Parent := FPnlInput;
  FLblCategory.Caption := '分类:';
  FLblCategory.Left := 8;
  FLblCategory.Top := Y;
  FLblCategory.Font.Color := clWhite;
  
  FLblPriority := TLabel.Create(Self);
  FLblPriority.Parent := FPnlInput;
  FLblPriority.Caption := '优先级:';
  FLblPriority.Left := 120;
  FLblPriority.Top := Y;
  FLblPriority.Font.Color := clWhite;
  Inc(Y, 18);
  
  FCboCategory := TComboBox.Create(Self);
  FCboCategory.Parent := FPnlInput;
  FCboCategory.Left := 8;
  FCboCategory.Top := Y;
  FCboCategory.Width := 100;
  FCboCategory.Style := csDropDownList;
  FCboCategory.Items.Add('💡 想法');
  FCboCategory.Items.Add('✅ TODO');
  FCboCategory.Items.Add('❗ 问题');
  FCboCategory.Items.Add('📅 会议');
  FCboCategory.Items.Add('📝 其他');
  FCboCategory.ItemIndex := 1;  // 默认 TODO
  FCboCategory.Color := $003D3D3D;
  FCboCategory.Font.Color := clWhite;
  
  FCboProiority := TComboBox.Create(Self);
  FCboProiority.Parent := FPnlInput;
  FCboProiority.Left := 120;
  FCboProiority.Top := Y;
  FCboProiority.Width := 70;
  FCboProiority.Style := csDropDownList;
  FCboProiority.Items.Add('低');
  FCboProiority.Items.Add('中');
  FCboProiority.Items.Add('高');
  FCboProiority.ItemIndex := 1;  // 默认中
  FCboProiority.Color := $003D3D3D;
  FCboProiority.Font.Color := clWhite;
  Inc(Y, 28);
  
  // 提醒
  FChkReminder := TCheckBox.Create(Self);
  FChkReminder.Parent := FPnlInput;
  FChkReminder.Caption := '设置提醒';
  FChkReminder.Left := 8;
  FChkReminder.Top := Y;
  FChkReminder.Font.Color := clWhite;
  FChkReminder.OnClick := OnChkReminderClick;
  
  FDtpReminder := TDateTimePicker.Create(Self);
  FDtpReminder.Parent := FPnlInput;
  FDtpReminder.Left := 100;
  FDtpReminder.Top := Y - 2;
  FDtpReminder.Width := 90;
  FDtpReminder.Kind := dtkDateTime;
  FDtpReminder.DateTime := Now + 1;  // 默认明天
  FDtpReminder.Enabled := False;
  FDtpReminder.Color := $003D3D3D;
  FDtpReminder.Font.Color := clWhite;
  Inc(Y, 28);
  
  // 按钮
  FBtnSave := TButton.Create(Self);
  FBtnSave.Parent := FPnlInput;
  FBtnSave.Caption := '保存';
  FBtnSave.Left := 8;
  FBtnSave.Top := Y;
  FBtnSave.Width := 75;
  FBtnSave.OnClick := OnBtnSaveClick;
  
  FBtnClear := TButton.Create(Self);
  FBtnClear.Parent := FPnlInput;
  FBtnClear.Caption := '清空';
  FBtnClear.Left := 90;
  FBtnClear.Top := Y;
  FBtnClear.Width := 75;
  FBtnClear.OnClick := OnBtnClearClick;
end;

procedure TNotesFrame.CreateListPanel;
begin
  FPnlList := TPanel.Create(Self);
  FPnlList.Parent := Self;
  FPnlList.Align := alBottom;
  FPnlList.Height := 200;
  FPnlList.BevelOuter := bvNone;
  FPnlList.Caption := '';
  FPnlList.Color := $002D2D2D;
  FPnlList.ParentBackground := False;
  
  // 搜索框
  FEdtSearch := TEdit.Create(Self);
  FEdtSearch.Parent := FPnlList;
  FEdtSearch.Left := 8;
  FEdtSearch.Top := 5;
  FEdtSearch.Width := 100;
  FEdtSearch.TextHint := '搜索...';
  FEdtSearch.Color := $003D3D3D;
  FEdtSearch.Font.Color := clWhite;
  FEdtSearch.OnChange := OnSearchChange;
  
  // 筛选下拉框
  FCboFilter := TComboBox.Create(Self);
  FCboFilter.Parent := FPnlList;
  FCboFilter.Left := 115;
  FCboFilter.Top := 5;
  FCboFilter.Width := 85;
  FCboFilter.Style := csDropDownList;
  FCboFilter.Items.Add('全部');
  FCboFilter.Items.Add('未完成');
  FCboFilter.Items.Add('已完成');
  FCboFilter.Items.Add('有提醒');
  FCboFilter.Items.Add('今日');
  FCboFilter.ItemIndex := 1;  // 默认显示未完成
  FCboFilter.Color := $003D3D3D;
  FCboFilter.Font.Color := clWhite;
  FCboFilter.OnChange := OnFilterChange;
  
  // 列表
  FLvNotes := TListView.Create(Self);
  FLvNotes.Parent := FPnlList;
  FLvNotes.Left := 0;
  FLvNotes.Top := 30;
  FLvNotes.Width := FPnlList.Width;
  FLvNotes.Height := FPnlList.Height - 30;
  FLvNotes.Align := alBottom;
  FLvNotes.Anchors := [akLeft, akTop, akRight, akBottom];
  FLvNotes.ViewStyle := vsReport;
  FLvNotes.ReadOnly := True;
  FLvNotes.RowSelect := True;
  FLvNotes.GridLines := True;
  FLvNotes.Color := $002D2D2D;
  FLvNotes.Font.Color := clWhite;
  FLvNotes.OnDblClick := OnNoteDblClick;
  FLvNotes.OnKeyDown := OnNoteKeyDown;
  
  with FLvNotes.Columns.Add do
  begin
    Caption := '分类';
    Width := 50;
  end;
  with FLvNotes.Columns.Add do
  begin
    Caption := '标题';
    Width := 100;
  end;
  with FLvNotes.Columns.Add do
  begin
    Caption := '优先级';
    Width := 50;
  end;
  with FLvNotes.Columns.Add do
  begin
    Caption := '提醒';
    Width := 80;
  end;
end;

procedure TNotesFrame.LoadNotes;
var
  Query: TFDQuery;
  Rec: TNoteRecord;
begin
  FNotes.Clear;
  
  if not TrayDB.Initialized then
    Exit;
    
  // 确保表存在
  try
    TrayDB.Connection.ExecSQL(
      'CREATE TABLE IF NOT EXISTS DevNotes (' +
      '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
      '  Title TEXT NOT NULL,' +
      '  Content TEXT,' +
      '  Category INTEGER NOT NULL DEFAULT 1,' +
      '  Priority INTEGER NOT NULL DEFAULT 1,' +
      '  ReminderTime DATETIME,' +
      '  HasReminder INTEGER NOT NULL DEFAULT 0,' +
      '  IsCompleted INTEGER NOT NULL DEFAULT 0,' +
      '  CreatedAt DATETIME NOT NULL DEFAULT (datetime(''now'', ''localtime'')),' +
      '  UpdatedAt DATETIME NOT NULL DEFAULT (datetime(''now'', ''localtime''))' +
      ')');
  except
    // 表可能已存在
  end;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := TrayDB.Connection;
    Query.SQL.Text := 'SELECT * FROM DevNotes ORDER BY Priority DESC, CreatedAt DESC';
    Query.Open;
    
    while not Query.Eof do
    begin
      Rec.Id := Query.FieldByName('Id').AsInteger;
      Rec.Title := Query.FieldByName('Title').AsString;
      Rec.Content := Query.FieldByName('Content').AsString;
      Rec.Category := TNoteCategory(Query.FieldByName('Category').AsInteger);
      Rec.Priority := TNotePriority(Query.FieldByName('Priority').AsInteger);
      if not Query.FieldByName('ReminderTime').IsNull then
        Rec.ReminderTime := Query.FieldByName('ReminderTime').AsDateTime
      else
        Rec.ReminderTime := 0;
      Rec.HasReminder := Query.FieldByName('HasReminder').AsInteger = 1;
      Rec.IsCompleted := Query.FieldByName('IsCompleted').AsInteger = 1;
      Rec.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Rec.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
      FNotes.Add(Rec);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

procedure TNotesFrame.SaveNote;
var
  Query: TFDQuery;
  Title, Content: string;
  Category: TNoteCategory;
  Priority: TNotePriority;
  ReminderTime: TDateTime;
  HasReminder: Boolean;
begin
  Title := Trim(FEdtTitle.Text);
  if Title = '' then
  begin
    ShowMessage('请输入标题');
    FEdtTitle.SetFocus;
    Exit;
  end;
  
  Content := Trim(FMemContent.Text);
  Category := GetCategoryFromIndex(FCboCategory.ItemIndex);
  Priority := GetPriorityFromIndex(FCboProiority.ItemIndex);
  HasReminder := FChkReminder.Checked;
  if HasReminder then
    ReminderTime := FDtpReminder.DateTime
  else
    ReminderTime := 0;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := TrayDB.Connection;
    
    if FEditingId > 0 then
    begin
      // 更新
      Query.SQL.Text :=
        'UPDATE DevNotes SET Title = :Title, Content = :Content, Category = :Category, ' +
        'Priority = :Priority, ReminderTime = :ReminderTime, HasReminder = :HasReminder, ' +
        'UpdatedAt = :UpdatedAt WHERE Id = :Id';
      Query.ParamByName('Id').AsInteger := FEditingId;
      Query.ParamByName('UpdatedAt').AsString := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
    end
    else
    begin
      // 新增
      Query.SQL.Text :=
        'INSERT INTO DevNotes (Title, Content, Category, Priority, ReminderTime, HasReminder) ' +
        'VALUES (:Title, :Content, :Category, :Priority, :ReminderTime, :HasReminder)';
    end;
    
    Query.ParamByName('Title').AsString := Title;
    Query.ParamByName('Content').AsString := Content;
    Query.ParamByName('Category').AsInteger := Ord(Category);
    Query.ParamByName('Priority').AsInteger := Ord(Priority);
    if HasReminder then
      Query.ParamByName('ReminderTime').AsDateTime := ReminderTime
    else
      Query.ParamByName('ReminderTime').Clear;
    Query.ParamByName('HasReminder').AsInteger := Ord(HasReminder);
    Query.ExecSQL;
  finally
    Query.Free;
  end;
  
  ClearInput;
  RefreshData;
end;

procedure TNotesFrame.RefreshNotesList;
var
  Item: TListItem;
  Note: TNoteRecord;
  SearchText: string;
  FilterIdx: Integer;
begin
  FLvNotes.Items.BeginUpdate;
  try
    FLvNotes.Items.Clear;
    SearchText := LowerCase(Trim(FEdtSearch.Text));
    FilterIdx := FCboFilter.ItemIndex;
    
    for Note in FNotes do
    begin
      if not FilterNote(Note, SearchText, FilterIdx) then
        Continue;
        
      Item := FLvNotes.Items.Add;
      Item.Caption := GetCategoryText(Note.Category);
      Item.SubItems.Add(Note.Title);
      Item.SubItems.Add(GetPriorityText(Note.Priority));
      
      if Note.HasReminder then
        Item.SubItems.Add(FormatDateTime('mm-dd hh:nn', Note.ReminderTime))
      else
        Item.SubItems.Add('-');
        
      Item.Data := Pointer(Note.Id);
      
      // 已完成项变灰
      if Note.IsCompleted then
        Item.StateIndex := 1;
    end;
  finally
    FLvNotes.Items.EndUpdate;
  end;
end;

function TNotesFrame.FilterNote(const ANote: TNoteRecord; const ASearch: string; AFilterIdx: Integer): Boolean;
begin
  Result := True;
  
  // 搜索过滤
  if ASearch <> '' then
  begin
    if (Pos(ASearch, LowerCase(ANote.Title)) = 0) and
       (Pos(ASearch, LowerCase(ANote.Content)) = 0) then
    begin
      Result := False;
      Exit;
    end;
  end;
  
  // 状态过滤
  case AFilterIdx of
    1: Result := not ANote.IsCompleted;  // 未完成
    2: Result := ANote.IsCompleted;       // 已完成
    3: Result := ANote.HasReminder and not ANote.IsCompleted;  // 有提醒
    4: Result := (Trunc(ANote.CreatedAt) = Trunc(Now)) and not ANote.IsCompleted;  // 今日
  end;
end;

procedure TNotesFrame.ClearInput;
begin
  FEdtTitle.Text := '';
  FMemContent.Text := '';
  FCboCategory.ItemIndex := 1;
  FCboProiority.ItemIndex := 1;
  FChkReminder.Checked := False;
  FDtpReminder.DateTime := Now + 1;
  FDtpReminder.Enabled := False;
  FEditingId := -1;
  FBtnSave.Caption := '保存';
end;

function TNotesFrame.GetCategoryText(ACat: TNoteCategory): string;
begin
  Result := CATEGORY_TEXTS[ACat];
end;

function TNotesFrame.GetPriorityText(APri: TNotePriority): string;
begin
  Result := PRIORITY_TEXTS[APri];
end;

function TNotesFrame.GetCategoryFromIndex(AIndex: Integer): TNoteCategory;
begin
  if (AIndex >= 0) and (AIndex <= Ord(High(TNoteCategory))) then
    Result := TNoteCategory(AIndex)
  else
    Result := ncOther;
end;

function TNotesFrame.GetPriorityFromIndex(AIndex: Integer): TNotePriority;
begin
  if (AIndex >= 0) and (AIndex <= Ord(High(TNotePriority))) then
    Result := TNotePriority(AIndex)
  else
    Result := npMedium;
end;

procedure TNotesFrame.CheckReminders;
var
  Note: TNoteRecord;
  NowTime: TDateTime;
begin
  NowTime := Now;
  
  for Note in FNotes do
  begin
    if Note.HasReminder and not Note.IsCompleted then
    begin
      // 提醒时间在当前时间前后1分钟内
      if (Note.ReminderTime <= NowTime) and (Note.ReminderTime >= IncMinute(NowTime, -1)) then
      begin
        if Assigned(FOnReminderDue) then
          FOnReminderDue(Note)
        else
          ShowMessage('提醒: ' + Note.Title);
      end;
    end;
  end;
end;

procedure TNotesFrame.OnBtnSaveClick(Sender: TObject);
begin
  SaveNote;
end;

procedure TNotesFrame.OnBtnClearClick(Sender: TObject);
begin
  ClearInput;
end;

procedure TNotesFrame.OnNoteDblClick(Sender: TObject);
var
  Item: TListItem;
  NoteId: Integer;
  Note: TNoteRecord;
begin
  Item := FLvNotes.Selected;
  if Item = nil then
    Exit;
    
  NoteId := Integer(Item.Data);
  
  for Note in FNotes do
  begin
    if Note.Id = NoteId then
    begin
      // 加载到编辑区
      FEdtTitle.Text := Note.Title;
      FMemContent.Text := Note.Content;
      FCboCategory.ItemIndex := Ord(Note.Category);
      FCboProiority.ItemIndex := Ord(Note.Priority);
      FChkReminder.Checked := Note.HasReminder;
      FDtpReminder.Enabled := Note.HasReminder;
      if Note.HasReminder then
        FDtpReminder.DateTime := Note.ReminderTime;
      FEditingId := Note.Id;
      FBtnSave.Caption := '更新';
      Break;
    end;
  end;
end;

procedure TNotesFrame.OnNoteKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Item: TListItem;
  NoteId: Integer;
begin
  Item := FLvNotes.Selected;
  if Item = nil then
    Exit;
    
  NoteId := Integer(Item.Data);
  
  case Key of
    VK_DELETE:
    begin
      if MessageDlg('确定删除此笔记?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
      begin
        TrayDB.Connection.ExecSQL('DELETE FROM DevNotes WHERE Id = ' + IntToStr(NoteId));
        RefreshData;
      end;
    end;
    VK_SPACE:
    begin
      // 空格键切换完成状态
      MarkComplete(NoteId);
    end;
  end;
end;

procedure TNotesFrame.OnChkReminderClick(Sender: TObject);
begin
  FDtpReminder.Enabled := FChkReminder.Checked;
end;

procedure TNotesFrame.OnReminderTimer(Sender: TObject);
begin
  CheckReminders;
end;

procedure TNotesFrame.OnSearchChange(Sender: TObject);
begin
  RefreshNotesList;
end;

procedure TNotesFrame.OnFilterChange(Sender: TObject);
begin
  RefreshNotesList;
end;

procedure TNotesFrame.RefreshData;
begin
  LoadNotes;
  RefreshNotesList;
end;

procedure TNotesFrame.MarkComplete(ANoteId: Integer);
var
  I: Integer;
  Note: TNoteRecord;
  NewStatus: Integer;
  NowStr: string;
begin
  NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
  for I := 0 to FNotes.Count - 1 do
  begin
    Note := FNotes[I];
    if Note.Id = ANoteId then
    begin
      NewStatus := Ord(not Note.IsCompleted);
      TrayDB.Connection.ExecSQL(
        'UPDATE DevNotes SET IsCompleted = ' + IntToStr(NewStatus) +
        ', UpdatedAt = ''' + NowStr + ''' WHERE Id = ' + IntToStr(ANoteId));
      RefreshData;
      Break;
    end;
  end;
end;

end.
