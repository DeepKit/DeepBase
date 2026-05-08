unit Tray.CommandFrame;

{*******************************************************************************
  DeepBaseTray - 命令面板 Frame
  
  功能:
  - 显示常用命令列表（按频次排序）
  - 单击复制命令
  - 双击执行命令
  - 命令 CRUD 操作
  - 危险命令确认
*******************************************************************************}

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI,
  System.SysUtils, System.Classes, System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus, Vcl.Clipbrd,
  Tray.Database;

type
  TCommandFrame = class(TFrame)
  private
    { 界面组件 }
    FPnlToolbar: TPanel;
    FBtnAdd: TButton;
    FBtnEdit: TButton;
    FBtnDelete: TButton;
    FLvCommands: TListView;
    FPopupMenu: TPopupMenu;
    
    { 状态 }
    FCurrentProject: string;
    
    { 方法 }
    procedure CreateUI;
    procedure CreateToolbar;
    procedure CreateListView;
    procedure CreatePopupMenu;
    procedure LoadCommands;
    function CanExecuteCommand(const ACommand: string): Boolean;
    procedure ExecuteCommand(const ACommand: string; ACommandId: Integer);
    procedure CopyCommand(const ACommand: string);
    
    { 事件 }
    procedure OnBtnAddClick(Sender: TObject);
    procedure OnBtnEditClick(Sender: TObject);
    procedure OnBtnDeleteClick(Sender: TObject);
    procedure OnListClick(Sender: TObject);
    procedure OnListDblClick(Sender: TObject);
    procedure OnListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    
    { 弹出菜单事件 }
    procedure OnMenuCopy(Sender: TObject);
    procedure OnMenuExecute(Sender: TObject);
    procedure OnMenuEdit(Sender: TObject);
    procedure OnMenuDelete(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure RefreshData;
    
    property CurrentProject: string read FCurrentProject write FCurrentProject;
  end;

implementation

uses
  Tray.Launcher;

{ TCommandFrame }

constructor TCommandFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCurrentProject := '';
  CreateUI;
  RefreshData;
end;

destructor TCommandFrame.Destroy;
begin
  inherited;
end;

procedure TCommandFrame.CreateUI;
begin
  Width := 300;
  Height := 400;
  
  CreateToolbar;
  CreateListView;
  CreatePopupMenu;
end;

procedure TCommandFrame.CreateToolbar;
begin
  FPnlToolbar := TPanel.Create(Self);
  FPnlToolbar.Parent := Self;
  FPnlToolbar.Align := alTop;
  FPnlToolbar.Height := 32;
  FPnlToolbar.BevelOuter := bvNone;
  FPnlToolbar.Caption := '';
  
  FBtnAdd := TButton.Create(Self);
  FBtnAdd.Parent := FPnlToolbar;
  FBtnAdd.Caption := '+';
  FBtnAdd.Hint := '添加命令';
  FBtnAdd.ShowHint := True;
  FBtnAdd.Left := 5;
  FBtnAdd.Top := 3;
  FBtnAdd.Width := 32;
  FBtnAdd.Height := 26;
  FBtnAdd.OnClick := OnBtnAddClick;
  
  FBtnEdit := TButton.Create(Self);
  FBtnEdit.Parent := FPnlToolbar;
  FBtnEdit.Caption := '✎';
  FBtnEdit.Hint := '编辑命令';
  FBtnEdit.ShowHint := True;
  FBtnEdit.Left := 40;
  FBtnEdit.Top := 3;
  FBtnEdit.Width := 32;
  FBtnEdit.Height := 26;
  FBtnEdit.OnClick := OnBtnEditClick;
  
  FBtnDelete := TButton.Create(Self);
  FBtnDelete.Parent := FPnlToolbar;
  FBtnDelete.Caption := '×';
  FBtnDelete.Hint := '删除命令';
  FBtnDelete.ShowHint := True;
  FBtnDelete.Left := 75;
  FBtnDelete.Top := 3;
  FBtnDelete.Width := 32;
  FBtnDelete.Height := 26;
  FBtnDelete.OnClick := OnBtnDeleteClick;
end;

procedure TCommandFrame.CreateListView;
begin
  FLvCommands := TListView.Create(Self);
  FLvCommands.Parent := Self;
  FLvCommands.Align := alClient;
  FLvCommands.ViewStyle := vsReport;
  FLvCommands.ReadOnly := True;
  FLvCommands.RowSelect := True;
  FLvCommands.GridLines := True;
  FLvCommands.OnClick := OnListClick;
  FLvCommands.OnDblClick := OnListDblClick;
  FLvCommands.OnKeyDown := OnListKeyDown;
  
  with FLvCommands.Columns.Add do
  begin
    Caption := '名称';
    Width := 100;
  end;
  with FLvCommands.Columns.Add do
  begin
    Caption := '命令';
    Width := 150;
  end;
  with FLvCommands.Columns.Add do
  begin
    Caption := '次数';
    Width := 40;
  end;
end;

procedure TCommandFrame.CreatePopupMenu;
var
  MenuItem: TMenuItem;
begin
  FPopupMenu := TPopupMenu.Create(Self);
  FLvCommands.PopupMenu := FPopupMenu;
  
  MenuItem := TMenuItem.Create(FPopupMenu);
  MenuItem.Caption := '复制(&C)';
  MenuItem.ShortCut := TextToShortCut('Ctrl+C');
  MenuItem.OnClick := OnMenuCopy;
  FPopupMenu.Items.Add(MenuItem);
  
  MenuItem := TMenuItem.Create(FPopupMenu);
  MenuItem.Caption := '执行(&E)';
  MenuItem.ShortCut := TextToShortCut('Enter');
  MenuItem.OnClick := OnMenuExecute;
  FPopupMenu.Items.Add(MenuItem);
  
  MenuItem := TMenuItem.Create(FPopupMenu);
  MenuItem.Caption := '-';
  FPopupMenu.Items.Add(MenuItem);
  
  MenuItem := TMenuItem.Create(FPopupMenu);
  MenuItem.Caption := '编辑(&D)';
  MenuItem.OnClick := OnMenuEdit;
  FPopupMenu.Items.Add(MenuItem);
  
  MenuItem := TMenuItem.Create(FPopupMenu);
  MenuItem.Caption := '删除(&L)';
  MenuItem.ShortCut := TextToShortCut('Delete');
  MenuItem.OnClick := OnMenuDelete;
  FPopupMenu.Items.Add(MenuItem);
end;

procedure TCommandFrame.LoadCommands;
var
  Commands: TArray<TQuickCommandRecord>;
  Cmd: TQuickCommandRecord;
  Item: TListItem;
begin
  FLvCommands.Items.Clear;
  Commands := TrayDB.GetCommands(FCurrentProject);
  
  for Cmd in Commands do
  begin
    Item := FLvCommands.Items.Add;
    Item.Caption := Cmd.CommandName;
    Item.SubItems.Add(Cmd.CommandText);
    Item.SubItems.Add(IntToStr(Cmd.UsageCount));
    Item.Data := Pointer(Cmd.Id);
    
    // 危险命令显示红色
    if Cmd.IsDangerous then
      Item.Caption := '⚠ ' + Item.Caption;
  end;
end;

function TCommandFrame.CanExecuteCommand(const ACommand: string): Boolean;
begin
  Result := True;
  
  // 检查黑名单
  if TrayDB.IsCommandBlacklisted(ACommand) then
  begin
    ShowMessage('该命令在黑名单中，禁止执行！');
    Result := False;
    Exit;
  end;
  
  // 检查是否需要确认
  if TrayDB.GetSettingBool('Tray.CommandConfirm', True) then
  begin
    if MessageDlg('确定要执行命令吗？' + #13#10#13#10 + ACommand, 
      mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

procedure TCommandFrame.ExecuteCommand(const ACommand: string; ACommandId: Integer);
begin
  if not CanExecuteCommand(ACommand) then
    Exit;
    
  // 更新使用次数
  if ACommandId > 0 then
    TrayDB.IncrementCommandUsage(ACommandId);
  
  // 执行命令
  TTrayLauncher.LaunchProgram('cmd.exe', '/C ' + ACommand);
  
  // 刷新列表
  RefreshData;
end;

procedure TCommandFrame.CopyCommand(const ACommand: string);
begin
  Clipboard.AsText := ACommand;
end;

{ 按钮事件 }

procedure TCommandFrame.OnBtnAddClick(Sender: TObject);
var
  CmdName, CmdText, Category: string;
  IsDangerous: Boolean;
begin
  CmdName := '';
  CmdText := '';
  
  if not InputQuery('添加命令', '命令名称:', CmdName) then Exit;
  if CmdName = '' then Exit;
  
  if not InputQuery('添加命令', '命令内容:', CmdText) then Exit;
  if CmdText = '' then Exit;
  
  Category := 'General';
  IsDangerous := False;
  
  // 简单检测危险命令
  if (Pos('rm ', LowerCase(CmdText)) > 0) or
     (Pos('del ', LowerCase(CmdText)) > 0) or
     (Pos('format', LowerCase(CmdText)) > 0) or
     (Pos('drop ', LowerCase(CmdText)) > 0) then
  begin
    if MessageDlg('检测到可能的危险命令，是否标记为危险？', 
      mtConfirmation, [mbYes, mbNo], 0) = mrYes then
      IsDangerous := True;
  end;
  
  TrayDB.AddCommand(CmdName, CmdText, FCurrentProject, Category, IsDangerous);
  RefreshData;
end;

procedure TCommandFrame.OnBtnEditClick(Sender: TObject);
begin
  OnMenuEdit(Sender);
end;

procedure TCommandFrame.OnBtnDeleteClick(Sender: TObject);
begin
  OnMenuDelete(Sender);
end;

procedure TCommandFrame.OnListClick(Sender: TObject);
var
  Item: TListItem;
begin
  Item := FLvCommands.Selected;
  if Item = nil then Exit;
  
  // 单击复制命令
  CopyCommand(Item.SubItems[0]);
end;

procedure TCommandFrame.OnListDblClick(Sender: TObject);
var
  Item: TListItem;
  CmdId: Integer;
begin
  Item := FLvCommands.Selected;
  if Item = nil then Exit;
  
  CmdId := Integer(Item.Data);
  ExecuteCommand(Item.SubItems[0], CmdId);
end;

procedure TCommandFrame.OnListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
    OnListDblClick(Sender)
  else if Key = VK_DELETE then
    OnMenuDelete(Sender)
  else if (Key = Ord('C')) and (ssCtrl in Shift) then
    OnMenuCopy(Sender);
end;

{ 弹出菜单事件 }

procedure TCommandFrame.OnMenuCopy(Sender: TObject);
var
  Item: TListItem;
begin
  Item := FLvCommands.Selected;
  if Item = nil then Exit;
  
  CopyCommand(Item.SubItems[0]);
  ShowMessage('命令已复制到剪贴板');
end;

procedure TCommandFrame.OnMenuExecute(Sender: TObject);
begin
  OnListDblClick(Sender);
end;

procedure TCommandFrame.OnMenuEdit(Sender: TObject);
var
  Item: TListItem;
  CmdId: Integer;
  CmdName, CmdText: string;
  Commands: TArray<TQuickCommandRecord>;
  Cmd: TQuickCommandRecord;
begin
  Item := FLvCommands.Selected;
  if Item = nil then Exit;
  
  CmdId := Integer(Item.Data);
  
  // 获取当前值
  Commands := TrayDB.GetCommands(FCurrentProject);
  for Cmd in Commands do
  begin
    if Cmd.Id = CmdId then
    begin
      CmdName := Cmd.CommandName;
      CmdText := Cmd.CommandText;
      
      if not InputQuery('编辑命令', '命令名称:', CmdName) then Exit;
      if CmdName = '' then Exit;
      
      if not InputQuery('编辑命令', '命令内容:', CmdText) then Exit;
      if CmdText = '' then Exit;
      
      TrayDB.UpdateCommand(CmdId, CmdName, CmdText, Cmd.Category, Cmd.IsDangerous);
      RefreshData;
      Break;
    end;
  end;
end;

procedure TCommandFrame.OnMenuDelete(Sender: TObject);
var
  Item: TListItem;
  CmdId: Integer;
begin
  Item := FLvCommands.Selected;
  if Item = nil then Exit;
  
  if MessageDlg('确定要删除这条命令吗？', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    CmdId := Integer(Item.Data);
    TrayDB.DeleteCommand(CmdId);
    RefreshData;
  end;
end;

procedure TCommandFrame.RefreshData;
begin
  LoadCommands;
end;

end.
