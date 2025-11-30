unit Tray.ProjectsFrame;

{*******************************************************************************
  UniBaseTray - 项目切换器 Frame
  
  功能:
  - 显示最近项目列表
  - 快速打开项目目录
  - 打开 IDE 或编辑器
  - 支持收藏/置顶项目
  - 项目搜索过滤
*******************************************************************************}

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI,
  System.SysUtils, System.Classes, System.Generics.Collections, System.IOUtils,
  System.StrUtils, System.Types,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus,
  FireDAC.Comp.Client,
  Tray.Database;

type
  TProjectRecord = record
    Id: Integer;
    ProjectName: string;
    ProjectPath: string;
    ProjectType: string;  // Delphi, VS, Python, etc.
    IsFavorite: Boolean;
    LastOpenedAt: TDateTime;
    OpenCount: Integer;
  end;

  TProjectsFrame = class(TFrame)
  private
    { 界面组件 }
    FPnlTop: TPanel;
    FEdtSearch: TEdit;
    FBtnAdd: TButton;
    FLvProjects: TListView;
    FPopupMenu: TPopupMenu;
    
    { 数据 }
    FProjects: TList<TProjectRecord>;
    
    { 方法 }
    procedure CreateUI;
    procedure LoadProjects;
    procedure RefreshProjectList;
    procedure AddProject(const APath: string);
    procedure OpenProject(const AProject: TProjectRecord);
    procedure OpenInExplorer(const APath: string);
    procedure OpenInIDE(const AProject: TProjectRecord);
    procedure OpenInTerminal(const APath: string);
    procedure ToggleFavorite(AProjectId: Integer);
    procedure DeleteProject(AProjectId: Integer);
    function DetectProjectType(const APath: string): string;
    function GetProjectIcon(const AType: string): Integer;
    function FilterProject(const AProject: TProjectRecord; const ASearch: string): Boolean;
    
    { 事件 }
    procedure OnSearchChange(Sender: TObject);
    procedure OnBtnAddClick(Sender: TObject);
    procedure OnProjectDblClick(Sender: TObject);
    procedure OnProjectKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure OnMenuOpenFolder(Sender: TObject);
    procedure OnMenuOpenIDE(Sender: TObject);
    procedure OnMenuOpenTerminal(Sender: TObject);
    procedure OnMenuFavorite(Sender: TObject);
    procedure OnMenuDelete(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure RefreshData;
    procedure AddRecentProject(const APath: string);
  end;

implementation

const
  PROJECT_TYPE_DELPHI = 'Delphi';
  PROJECT_TYPE_VS = 'VS';
  PROJECT_TYPE_PYTHON = 'Python';
  PROJECT_TYPE_NODE = 'Node';
  PROJECT_TYPE_GO = 'Go';
  PROJECT_TYPE_RUST = 'Rust';
  PROJECT_TYPE_OTHER = 'Other';

{ TProjectsFrame }

constructor TProjectsFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FProjects := TList<TProjectRecord>.Create;
  CreateUI;
  RefreshData;
end;

destructor TProjectsFrame.Destroy;
begin
  FProjects.Free;
  inherited;
end;

procedure TProjectsFrame.CreateUI;
var
  MenuItem: TMenuItem;
begin
  Width := 300;
  Height := 450;
  Color := $002D2D2D;
  
  // 顶部面板
  FPnlTop := TPanel.Create(Self);
  FPnlTop.Parent := Self;
  FPnlTop.Align := alTop;
  FPnlTop.Height := 35;
  FPnlTop.BevelOuter := bvNone;
  FPnlTop.Color := $002D2D2D;
  FPnlTop.ParentBackground := False;
  
  // 搜索框
  FEdtSearch := TEdit.Create(Self);
  FEdtSearch.Parent := FPnlTop;
  FEdtSearch.Left := 5;
  FEdtSearch.Top := 5;
  FEdtSearch.Width := 180;
  FEdtSearch.TextHint := '搜索项目...';
  FEdtSearch.Color := $003D3D3D;
  FEdtSearch.Font.Color := clWhite;
  FEdtSearch.OnChange := OnSearchChange;
  
  // 添加按钮
  FBtnAdd := TButton.Create(Self);
  FBtnAdd.Parent := FPnlTop;
  FBtnAdd.Caption := '+添加';
  FBtnAdd.Left := 190;
  FBtnAdd.Top := 5;
  FBtnAdd.Width := 60;
  FBtnAdd.OnClick := OnBtnAddClick;
  
  // 项目列表
  FLvProjects := TListView.Create(Self);
  FLvProjects.Parent := Self;
  FLvProjects.Align := alClient;
  FLvProjects.ViewStyle := vsReport;
  FLvProjects.ReadOnly := True;
  FLvProjects.RowSelect := True;
  FLvProjects.GridLines := True;
  FLvProjects.Color := $002D2D2D;
  FLvProjects.Font.Color := clWhite;
  FLvProjects.OnDblClick := OnProjectDblClick;
  FLvProjects.OnKeyDown := OnProjectKeyDown;
  
  with FLvProjects.Columns.Add do
  begin
    Caption := '项目名';
    Width := 120;
  end;
  with FLvProjects.Columns.Add do
  begin
    Caption := '类型';
    Width := 60;
  end;
  with FLvProjects.Columns.Add do
  begin
    Caption := '最近';
    Width := 70;
  end;
  
  // 右键菜单
  FPopupMenu := TPopupMenu.Create(Self);
  FLvProjects.PopupMenu := FPopupMenu;
  
  MenuItem := TMenuItem.Create(FPopupMenu);
  MenuItem.Caption := '打开文件夹';
  MenuItem.OnClick := OnMenuOpenFolder;
  FPopupMenu.Items.Add(MenuItem);
  
  MenuItem := TMenuItem.Create(FPopupMenu);
  MenuItem.Caption := '用 IDE 打开';
  MenuItem.OnClick := OnMenuOpenIDE;
  FPopupMenu.Items.Add(MenuItem);
  
  MenuItem := TMenuItem.Create(FPopupMenu);
  MenuItem.Caption := '打开终端';
  MenuItem.OnClick := OnMenuOpenTerminal;
  FPopupMenu.Items.Add(MenuItem);
  
  MenuItem := TMenuItem.Create(FPopupMenu);
  MenuItem.Caption := '-';
  FPopupMenu.Items.Add(MenuItem);
  
  MenuItem := TMenuItem.Create(FPopupMenu);
  MenuItem.Caption := '收藏/取消收藏';
  MenuItem.OnClick := OnMenuFavorite;
  FPopupMenu.Items.Add(MenuItem);
  
  MenuItem := TMenuItem.Create(FPopupMenu);
  MenuItem.Caption := '删除';
  MenuItem.OnClick := OnMenuDelete;
  FPopupMenu.Items.Add(MenuItem);
end;

procedure TProjectsFrame.LoadProjects;
var
  Query: TFDQuery;
  Proj: TProjectRecord;
begin
  FProjects.Clear;
  
  if not TrayDB.Initialized then
    Exit;
    
  // 确保表存在
  try
    TrayDB.Connection.ExecSQL(
      'CREATE TABLE IF NOT EXISTS Projects (' +
      '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
      '  ProjectName TEXT NOT NULL,' +
      '  ProjectPath TEXT NOT NULL UNIQUE,' +
      '  ProjectType TEXT DEFAULT ''Other'',' +
      '  IsFavorite INTEGER NOT NULL DEFAULT 0,' +
      '  LastOpenedAt DATETIME,' +
      '  OpenCount INTEGER NOT NULL DEFAULT 0,' +
      '  CreatedAt DATETIME NOT NULL DEFAULT (datetime(''now'', ''localtime''))' +
      ')');
  except
    // 表可能已存在
  end;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := TrayDB.Connection;
    // 收藏优先，然后按最近打开排序
    Query.SQL.Text := 'SELECT * FROM Projects ORDER BY IsFavorite DESC, LastOpenedAt DESC';
    Query.Open;
    
    while not Query.Eof do
    begin
      Proj.Id := Query.FieldByName('Id').AsInteger;
      Proj.ProjectName := Query.FieldByName('ProjectName').AsString;
      Proj.ProjectPath := Query.FieldByName('ProjectPath').AsString;
      Proj.ProjectType := Query.FieldByName('ProjectType').AsString;
      Proj.IsFavorite := Query.FieldByName('IsFavorite').AsInteger = 1;
      if not Query.FieldByName('LastOpenedAt').IsNull then
        Proj.LastOpenedAt := Query.FieldByName('LastOpenedAt').AsDateTime
      else
        Proj.LastOpenedAt := 0;
      Proj.OpenCount := Query.FieldByName('OpenCount').AsInteger;
      FProjects.Add(Proj);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

procedure TProjectsFrame.RefreshProjectList;
var
  Item: TListItem;
  Proj: TProjectRecord;
  SearchText: string;
begin
  FLvProjects.Items.BeginUpdate;
  try
    FLvProjects.Items.Clear;
    SearchText := LowerCase(Trim(FEdtSearch.Text));
    
    for Proj in FProjects do
    begin
      if not FilterProject(Proj, SearchText) then
        Continue;
        
      Item := FLvProjects.Items.Add;
      if Proj.IsFavorite then
        Item.Caption := '⭐ ' + Proj.ProjectName
      else
        Item.Caption := Proj.ProjectName;
      Item.SubItems.Add(Proj.ProjectType);
      
      if Proj.LastOpenedAt > 0 then
        Item.SubItems.Add(FormatDateTime('mm-dd hh:nn', Proj.LastOpenedAt))
      else
        Item.SubItems.Add('-');
        
      Item.Data := Pointer(Proj.Id);
    end;
  finally
    FLvProjects.Items.EndUpdate;
  end;
end;

procedure TProjectsFrame.AddProject(const APath: string);
var
  Query: TFDQuery;
  ProjectName, ProjectType: string;
begin
  if not TDirectory.Exists(APath) and not TFile.Exists(APath) then
  begin
    ShowMessage('路径不存在: ' + APath);
    Exit;
  end;
  
  ProjectName := ExtractFileName(ExcludeTrailingPathDelimiter(APath));
  ProjectType := DetectProjectType(APath);
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := TrayDB.Connection;
    Query.SQL.Text :=
      'INSERT OR REPLACE INTO Projects (ProjectName, ProjectPath, ProjectType, LastOpenedAt) ' +
      'VALUES (:Name, :Path, :Type, datetime(''now'', ''localtime''))';
    Query.ParamByName('Name').AsString := ProjectName;
    Query.ParamByName('Path').AsString := APath;
    Query.ParamByName('Type').AsString := ProjectType;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
  
  RefreshData;
end;

procedure TProjectsFrame.OpenProject(const AProject: TProjectRecord);
begin
  // 更新访问时间和计数
  TrayDB.Connection.ExecSQL(Format(
    'UPDATE Projects SET LastOpenedAt = datetime(''now'', ''localtime''), ' +
    'OpenCount = OpenCount + 1 WHERE Id = %d', [AProject.Id]));
  
  // 打开文件夹
  OpenInExplorer(AProject.ProjectPath);
end;

procedure TProjectsFrame.OpenInExplorer(const APath: string);
var
  TargetPath: string;
begin
  if TFile.Exists(APath) then
    TargetPath := ExtractFilePath(APath)
  else
    TargetPath := APath;
    
  ShellExecute(0, 'explore', PChar(TargetPath), nil, nil, SW_SHOWNORMAL);
end;

procedure TProjectsFrame.OpenInIDE(const AProject: TProjectRecord);
var
  IDEPath, ProjectFile: string;
  Files: TStringDynArray;
begin
  case IndexStr(AProject.ProjectType, [PROJECT_TYPE_DELPHI, PROJECT_TYPE_VS, PROJECT_TYPE_PYTHON, PROJECT_TYPE_NODE, PROJECT_TYPE_GO]) of
    0: // Delphi
    begin
      // 查找 .dproj 或 .dpr 文件
      Files := TDirectory.GetFiles(AProject.ProjectPath, '*.dproj');
      if Length(Files) > 0 then
        ProjectFile := Files[0]
      else
      begin
        Files := TDirectory.GetFiles(AProject.ProjectPath, '*.dpr');
        if Length(Files) > 0 then
          ProjectFile := Files[0];
      end;
      
      if ProjectFile <> '' then
        ShellExecute(0, 'open', PChar(ProjectFile), nil, nil, SW_SHOWNORMAL)
      else
        OpenInExplorer(AProject.ProjectPath);
    end;
    1: // VS
    begin
      // 查找 .sln 文件
      Files := TDirectory.GetFiles(AProject.ProjectPath, '*.sln');
      if Length(Files) > 0 then
        ShellExecute(0, 'open', PChar(Files[0]), nil, nil, SW_SHOWNORMAL)
      else
        OpenInExplorer(AProject.ProjectPath);
    end;
    2, 3, 4: // Python, Node, Go - 用 VS Code 打开
    begin
      ShellExecute(0, 'open', 'code', PChar('"' + AProject.ProjectPath + '"'), nil, SW_SHOWNORMAL);
    end;
  else
    // 默认：尝试用 VS Code 打开
    ShellExecute(0, 'open', 'code', PChar('"' + AProject.ProjectPath + '"'), nil, SW_SHOWNORMAL);
  end;
  
  // 更新访问时间
  TrayDB.Connection.ExecSQL(Format(
    'UPDATE Projects SET LastOpenedAt = datetime(''now'', ''localtime''), ' +
    'OpenCount = OpenCount + 1 WHERE Id = %d', [AProject.Id]));
end;

procedure TProjectsFrame.OpenInTerminal(const APath: string);
var
  WorkDir: string;
begin
  if TFile.Exists(APath) then
    WorkDir := ExtractFilePath(APath)
  else
    WorkDir := APath;
    
  // 用 PowerShell 打开
  ShellExecute(0, 'open', 'powershell.exe', nil, PChar(WorkDir), SW_SHOWNORMAL);
end;

procedure TProjectsFrame.ToggleFavorite(AProjectId: Integer);
begin
  TrayDB.Connection.ExecSQL(Format(
    'UPDATE Projects SET IsFavorite = NOT IsFavorite WHERE Id = %d', [AProjectId]));
  RefreshData;
end;

procedure TProjectsFrame.DeleteProject(AProjectId: Integer);
begin
  TrayDB.Connection.ExecSQL('DELETE FROM Projects WHERE Id = ' + IntToStr(AProjectId));
  RefreshData;
end;

function TProjectsFrame.DetectProjectType(const APath: string): string;
var
  SearchDir: string;
begin
  Result := PROJECT_TYPE_OTHER;
  
  if TFile.Exists(APath) then
    SearchDir := ExtractFilePath(APath)
  else
    SearchDir := APath;
    
  // Delphi
  if (Length(TDirectory.GetFiles(SearchDir, '*.dpr')) > 0) or
     (Length(TDirectory.GetFiles(SearchDir, '*.dproj')) > 0) then
  begin
    Result := PROJECT_TYPE_DELPHI;
    Exit;
  end;
  
  // Visual Studio
  if (Length(TDirectory.GetFiles(SearchDir, '*.sln')) > 0) or
     (Length(TDirectory.GetFiles(SearchDir, '*.csproj')) > 0) then
  begin
    Result := PROJECT_TYPE_VS;
    Exit;
  end;
  
  // Python
  if TFile.Exists(TPath.Combine(SearchDir, 'requirements.txt')) or
     TFile.Exists(TPath.Combine(SearchDir, 'setup.py')) or
     TFile.Exists(TPath.Combine(SearchDir, 'pyproject.toml')) then
  begin
    Result := PROJECT_TYPE_PYTHON;
    Exit;
  end;
  
  // Node.js
  if TFile.Exists(TPath.Combine(SearchDir, 'package.json')) then
  begin
    Result := PROJECT_TYPE_NODE;
    Exit;
  end;
  
  // Go
  if TFile.Exists(TPath.Combine(SearchDir, 'go.mod')) then
  begin
    Result := PROJECT_TYPE_GO;
    Exit;
  end;
  
  // Rust
  if TFile.Exists(TPath.Combine(SearchDir, 'Cargo.toml')) then
  begin
    Result := PROJECT_TYPE_RUST;
    Exit;
  end;
end;

function TProjectsFrame.GetProjectIcon(const AType: string): Integer;
begin
  // 将来可以添加图标支持
  Result := 0;
end;

function TProjectsFrame.FilterProject(const AProject: TProjectRecord; const ASearch: string): Boolean;
begin
  Result := True;
  if ASearch = '' then
    Exit;
    
  Result := (Pos(ASearch, LowerCase(AProject.ProjectName)) > 0) or
            (Pos(ASearch, LowerCase(AProject.ProjectPath)) > 0) or
            (Pos(ASearch, LowerCase(AProject.ProjectType)) > 0);
end;

procedure TProjectsFrame.OnSearchChange(Sender: TObject);
begin
  RefreshProjectList;
end;

procedure TProjectsFrame.OnBtnAddClick(Sender: TObject);
var
  Dlg: TFileOpenDialog;
begin
  Dlg := TFileOpenDialog.Create(nil);
  try
    Dlg.Title := '选择项目文件夹';
    Dlg.Options := [fdoPickFolders, fdoPathMustExist];
    if Dlg.Execute then
      AddProject(Dlg.FileName);
  finally
    Dlg.Free;
  end;
end;

procedure TProjectsFrame.OnProjectDblClick(Sender: TObject);
var
  Item: TListItem;
  ProjectId: Integer;
  Proj: TProjectRecord;
begin
  Item := FLvProjects.Selected;
  if Item = nil then
    Exit;
    
  ProjectId := Integer(Item.Data);
  
  for Proj in FProjects do
  begin
    if Proj.Id = ProjectId then
    begin
      OpenProject(Proj);
      Break;
    end;
  end;
end;

procedure TProjectsFrame.OnProjectKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Item: TListItem;
  ProjectId: Integer;
begin
  Item := FLvProjects.Selected;
  if Item = nil then
    Exit;
    
  ProjectId := Integer(Item.Data);
  
  case Key of
    VK_DELETE:
      if MessageDlg('确定从列表中删除?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
        DeleteProject(ProjectId);
    VK_F2:
      ToggleFavorite(ProjectId);
  end;
end;

procedure TProjectsFrame.OnMenuOpenFolder(Sender: TObject);
var
  Item: TListItem;
  ProjectId: Integer;
  Proj: TProjectRecord;
begin
  Item := FLvProjects.Selected;
  if Item = nil then
    Exit;
    
  ProjectId := Integer(Item.Data);
  
  for Proj in FProjects do
  begin
    if Proj.Id = ProjectId then
    begin
      OpenInExplorer(Proj.ProjectPath);
      Break;
    end;
  end;
end;

procedure TProjectsFrame.OnMenuOpenIDE(Sender: TObject);
var
  Item: TListItem;
  ProjectId: Integer;
  Proj: TProjectRecord;
begin
  Item := FLvProjects.Selected;
  if Item = nil then
    Exit;
    
  ProjectId := Integer(Item.Data);
  
  for Proj in FProjects do
  begin
    if Proj.Id = ProjectId then
    begin
      OpenInIDE(Proj);
      Break;
    end;
  end;
end;

procedure TProjectsFrame.OnMenuOpenTerminal(Sender: TObject);
var
  Item: TListItem;
  ProjectId: Integer;
  Proj: TProjectRecord;
begin
  Item := FLvProjects.Selected;
  if Item = nil then
    Exit;
    
  ProjectId := Integer(Item.Data);
  
  for Proj in FProjects do
  begin
    if Proj.Id = ProjectId then
    begin
      OpenInTerminal(Proj.ProjectPath);
      Break;
    end;
  end;
end;

procedure TProjectsFrame.OnMenuFavorite(Sender: TObject);
var
  Item: TListItem;
begin
  Item := FLvProjects.Selected;
  if Item = nil then
    Exit;
    
  ToggleFavorite(Integer(Item.Data));
end;

procedure TProjectsFrame.OnMenuDelete(Sender: TObject);
var
  Item: TListItem;
begin
  Item := FLvProjects.Selected;
  if Item = nil then
    Exit;
    
  if MessageDlg('确定从列表中删除?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    DeleteProject(Integer(Item.Data));
end;

procedure TProjectsFrame.RefreshData;
begin
  LoadProjects;
  RefreshProjectList;
end;

procedure TProjectsFrame.AddRecentProject(const APath: string);
begin
  AddProject(APath);
end;

end.
