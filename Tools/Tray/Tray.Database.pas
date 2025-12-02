unit Tray.Database;

{*******************************************************************************
  UniBaseTray - 数据库管理模块
  
  功能:
  - 管理 studio.db 连接
  - 自动初始化数据库
  - 提供数据访问层
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.DateUtils,
  System.Generics.Collections, System.Masks,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Stan.Param,
  FireDAC.UI.Intf, FireDAC.VCLUI.Wait, FireDAC.Phys.Intf, FireDAC.Phys,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  FireDAC.DApt.Intf, FireDAC.DApt, FireDAC.DatS,
  FireDAC.Comp.DataSet, FireDAC.Comp.Client;

type
  { 开发日志记录 }
  TDevLogRecord = record
    Id: Integer;
    LogDate: TDate;
    ProjectName: string;
    Requirement: string;
    Implementation_: string;  // Implementation 是保留字
    Tags: string;
    Notes: string;
    CreatedAt: TDateTime;
    UpdatedAt: TDateTime;
  end;
  
  { 常用命令记录 }
  TQuickCommandRecord = record
    Id: Integer;
    CommandName: string;
    CommandText: string;
    ProjectName: string;
    Category: string;
    UsageCount: Integer;
    IsDangerous: Boolean;
    IsEnabled: Boolean;
    CreatedAt: TDateTime;
    LastUsedAt: TDateTime;
  end;
  
  { 命令黑名单记录 }
  TBlacklistRecord = record
    Id: Integer;
    Pattern: string;
    Reason: string;
    IsEnabled: Boolean;
  end;

  TTrayDatabase = class
  private
    FConnection: TFDConnection;
    FDatabasePath: string;
    FInitialized: Boolean;
    
    function GetDatabasePath: string;
    procedure ExecuteInitScript;
    function GetInitScriptPath: string;
  public
    constructor Create;
    destructor Destroy; override;
    
    { 初始化 }
    function Initialize: Boolean;
    procedure Finalize;
    
    { 开发日志操作 }
    function AddDevLog(const AProjectName, ARequirement, AImplementation, ATags: string;
      const ANotes: string = ''): Integer;
    function GetTodayLogs: TArray<TDevLogRecord>;
    function GetLogsByDateRange(AStartDate, AEndDate: TDate): TArray<TDevLogRecord>;
    function GetLogsByProject(const AProjectName: string): TArray<TDevLogRecord>;
    function UpdateDevLog(AId: Integer; const ARequirement, AImplementation, ATags, ANotes: string): Boolean;
    function DeleteDevLog(AId: Integer): Boolean;
    
    { 常用命令操作 }
    function AddCommand(const AName, ACommand: string; const AProjectName: string = '';
      const ACategory: string = 'General'; AIsDangerous: Boolean = False): Integer;
    function GetCommands(const AProjectName: string = ''): TArray<TQuickCommandRecord>;
    function GetCommandsByUsage(ALimit: Integer = 20): TArray<TQuickCommandRecord>;
    procedure IncrementCommandUsage(AId: Integer);
    function UpdateCommand(AId: Integer; const AName, ACommand, ACategory: string;
      AIsDangerous: Boolean): Boolean;
    function DeleteCommand(AId: Integer): Boolean;
    
    { 黑名单操作 }
    function IsCommandBlacklisted(const ACommand: string): Boolean;
    function GetBlacklist: TArray<TBlacklistRecord>;
    function AddToBlacklist(const APattern, AReason: string): Integer;
    function RemoveFromBlacklist(AId: Integer): Boolean;
    
    { 项目历史 }
    function GetProjectHistory: TArray<string>;
    procedure AddProjectHistory(const AProjectName: string; const AProjectPath: string = '');
    
    { 设置操作 }
    function GetSetting(const AKey: string; const ADefault: string = ''): string;
    procedure SetSetting(const AKey, AValue: string);
    function GetSettingInt(const AKey: string; ADefault: Integer = 0): Integer;
    function GetSettingBool(const AKey: string; ADefault: Boolean = False): Boolean;
    
    { 属性 }
    property Connection: TFDConnection read FConnection;
    property DatabasePath: string read FDatabasePath;
    property Initialized: Boolean read FInitialized;
  end;

{ 全局单例 }
function TrayDB: TTrayDatabase;

implementation

var
  GTrayDatabase: TTrayDatabase = nil;

function TrayDB: TTrayDatabase;
begin
  if GTrayDatabase = nil then
  begin
    GTrayDatabase := TTrayDatabase.Create;
    GTrayDatabase.Initialize;
  end;
  Result := GTrayDatabase;
end;

{ TTrayDatabase }

constructor TTrayDatabase.Create;
begin
  inherited Create;
  FInitialized := False;
  FDatabasePath := GetDatabasePath;
  
  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Database := FDatabasePath;
  FConnection.Params.Add('LockingMode=Normal');
  FConnection.Params.Add('Synchronous=Normal');
  FConnection.LoginPrompt := False;
end;

destructor TTrayDatabase.Destroy;
begin
  Finalize;
  FConnection.Free;
  inherited;
end;

function TTrayDatabase.GetDatabasePath: string;
var
  AppDataPath: string;
begin
  AppDataPath := GetEnvironmentVariable('APPDATA');
  Result := TPath.Combine(AppDataPath, 'UniBase');
  if not TDirectory.Exists(Result) then
    TDirectory.CreateDirectory(Result);
  Result := TPath.Combine(Result, 'studio.db');
end;

function TTrayDatabase.GetInitScriptPath: string;
begin
  // 首先尝试 EXE 所在目录
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'sql\studio_init.sql');
  if not TFile.Exists(Result) then
  begin
    // 尝试开发目录
    Result := TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\sql\studio_init.sql');
    if not TFile.Exists(Result) then
      Result := '';
  end;
end;

procedure TTrayDatabase.ExecuteInitScript;
var
  ScriptPath: string;
  Script: TStringList;
begin
  ScriptPath := GetInitScriptPath;
  if ScriptPath = '' then
  begin
    // 如果找不到脚本文件，使用内置 SQL
    FConnection.ExecSQL(
      'CREATE TABLE IF NOT EXISTS DevLogs (' +
      '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
      '  LogDate DATE NOT NULL DEFAULT (date(''now'', ''localtime'')),' +
      '  ProjectName TEXT NOT NULL,' +
      '  Requirement TEXT,' +
      '  Implementation TEXT,' +
      '  Tags TEXT,' +
      '  Notes TEXT,' +
      '  CreatedAt DATETIME NOT NULL DEFAULT (datetime(''now'', ''localtime'')),' +
      '  UpdatedAt DATETIME NOT NULL DEFAULT (datetime(''now'', ''localtime''))' +
      ')');
      
    FConnection.ExecSQL(
      'CREATE TABLE IF NOT EXISTS QuickCommands (' +
      '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
      '  CommandName TEXT NOT NULL,' +
      '  CommandText TEXT NOT NULL,' +
      '  ProjectName TEXT,' +
      '  Category TEXT DEFAULT ''General'',' +
      '  UsageCount INTEGER NOT NULL DEFAULT 0,' +
      '  IsDangerous INTEGER NOT NULL DEFAULT 0,' +
      '  IsEnabled INTEGER NOT NULL DEFAULT 1,' +
      '  CreatedAt DATETIME NOT NULL DEFAULT (datetime(''now'', ''localtime'')),' +
      '  LastUsedAt DATETIME' +
      ')');
      
    FConnection.ExecSQL(
      'CREATE TABLE IF NOT EXISTS CommandBlacklist (' +
      '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
      '  Pattern TEXT NOT NULL UNIQUE,' +
      '  Reason TEXT,' +
      '  IsEnabled INTEGER NOT NULL DEFAULT 1' +
      ')');
      
    FConnection.ExecSQL(
      'CREATE TABLE IF NOT EXISTS ProjectHistory (' +
      '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
      '  ProjectName TEXT NOT NULL UNIQUE,' +
      '  ProjectPath TEXT,' +
      '  LastUsedAt DATETIME NOT NULL DEFAULT (datetime(''now'', ''localtime'')),' +
      '  UsageCount INTEGER NOT NULL DEFAULT 1' +
      ')');
      
    FConnection.ExecSQL(
      'CREATE TABLE IF NOT EXISTS TraySettings (' +
      '  Key TEXT PRIMARY KEY,' +
      '  Value TEXT,' +
      '  Description TEXT,' +
      '  UpdatedAt DATETIME NOT NULL DEFAULT (datetime(''now'', ''localtime''))' +
      ')');
    Exit;
  end;
  
  Script := TStringList.Create;
  try
    Script.LoadFromFile(ScriptPath, TEncoding.UTF8);
    FConnection.ExecSQL(Script.Text);
  finally
    Script.Free;
  end;
end;

function TTrayDatabase.Initialize: Boolean;
begin
  Result := False;
  if FInitialized then
    Exit(True);
    
  try
    FConnection.Open;
    ExecuteInitScript;
    FInitialized := True;
    Result := True;
  except
    on E: Exception do
    begin
      // 记录错误但不抛出
      FInitialized := False;
    end;
  end;
end;

procedure TTrayDatabase.Finalize;
begin
  if FConnection.Connected then
    FConnection.Close;
  FInitialized := False;
end;

{ 开发日志操作 }

function TTrayDatabase.AddDevLog(const AProjectName, ARequirement, AImplementation, ATags: string;
  const ANotes: string): Integer;
var
  Query: TFDQuery;
begin
  Result := -1;
  if not FInitialized then Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT INTO DevLogs (ProjectName, Requirement, Implementation, Tags, Notes) ' +
      'VALUES (:ProjectName, :Requirement, :Implementation, :Tags, :Notes)';
    Query.ParamByName('ProjectName').AsString := AProjectName;
    Query.ParamByName('Requirement').AsString := ARequirement;
    Query.ParamByName('Implementation').AsString := AImplementation;
    Query.ParamByName('Tags').AsString := ATags;
    Query.ParamByName('Notes').AsString := ANotes;
    Query.ExecSQL;
    
    // 获取插入的 ID
    Query.SQL.Text := 'SELECT last_insert_rowid()';
    Query.Open;
    Result := Query.Fields[0].AsInteger;
    
    // 更新项目历史
    AddProjectHistory(AProjectName);
  finally
    Query.Free;
  end;
end;

function TTrayDatabase.GetTodayLogs: TArray<TDevLogRecord>;
var
  Query: TFDQuery;
  List: TList<TDevLogRecord>;
  Rec: TDevLogRecord;
begin
  SetLength(Result, 0);
  if not FInitialized then Exit;
  
  List := TList<TDevLogRecord>.Create;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'SELECT * FROM DevLogs WHERE LogDate = date(''now'', ''localtime'') ORDER BY CreatedAt DESC';
    Query.Open;
    
    while not Query.Eof do
    begin
      Rec.Id := Query.FieldByName('Id').AsInteger;
      Rec.LogDate := Query.FieldByName('LogDate').AsDateTime;
      Rec.ProjectName := Query.FieldByName('ProjectName').AsString;
      Rec.Requirement := Query.FieldByName('Requirement').AsString;
      Rec.Implementation_ := Query.FieldByName('Implementation').AsString;
      Rec.Tags := Query.FieldByName('Tags').AsString;
      Rec.Notes := Query.FieldByName('Notes').AsString;
      Rec.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Rec.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
      List.Add(Rec);
      Query.Next;
    end;
    
    Result := List.ToArray;
  finally
    Query.Free;
    List.Free;
  end;
end;

function TTrayDatabase.GetLogsByDateRange(AStartDate, AEndDate: TDate): TArray<TDevLogRecord>;
var
  Query: TFDQuery;
  List: TList<TDevLogRecord>;
  Rec: TDevLogRecord;
begin
  SetLength(Result, 0);
  if not FInitialized then Exit;
  
  List := TList<TDevLogRecord>.Create;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'SELECT * FROM DevLogs WHERE LogDate BETWEEN :StartDate AND :EndDate ORDER BY LogDate DESC, CreatedAt DESC';
    Query.ParamByName('StartDate').AsDate := AStartDate;
    Query.ParamByName('EndDate').AsDate := AEndDate;
    Query.Open;
    
    while not Query.Eof do
    begin
      Rec.Id := Query.FieldByName('Id').AsInteger;
      Rec.LogDate := Query.FieldByName('LogDate').AsDateTime;
      Rec.ProjectName := Query.FieldByName('ProjectName').AsString;
      Rec.Requirement := Query.FieldByName('Requirement').AsString;
      Rec.Implementation_ := Query.FieldByName('Implementation').AsString;
      Rec.Tags := Query.FieldByName('Tags').AsString;
      Rec.Notes := Query.FieldByName('Notes').AsString;
      Rec.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Rec.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
      List.Add(Rec);
      Query.Next;
    end;
    
    Result := List.ToArray;
  finally
    Query.Free;
    List.Free;
  end;
end;

function TTrayDatabase.GetLogsByProject(const AProjectName: string): TArray<TDevLogRecord>;
var
  Query: TFDQuery;
  List: TList<TDevLogRecord>;
  Rec: TDevLogRecord;
begin
  SetLength(Result, 0);
  if not FInitialized then Exit;
  
  List := TList<TDevLogRecord>.Create;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'SELECT * FROM DevLogs WHERE ProjectName = :ProjectName ORDER BY LogDate DESC, CreatedAt DESC';
    Query.ParamByName('ProjectName').AsString := AProjectName;
    Query.Open;
    
    while not Query.Eof do
    begin
      Rec.Id := Query.FieldByName('Id').AsInteger;
      Rec.LogDate := Query.FieldByName('LogDate').AsDateTime;
      Rec.ProjectName := Query.FieldByName('ProjectName').AsString;
      Rec.Requirement := Query.FieldByName('Requirement').AsString;
      Rec.Implementation_ := Query.FieldByName('Implementation').AsString;
      Rec.Tags := Query.FieldByName('Tags').AsString;
      Rec.Notes := Query.FieldByName('Notes').AsString;
      Rec.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Rec.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
      List.Add(Rec);
      Query.Next;
    end;
    
    Result := List.ToArray;
  finally
    Query.Free;
    List.Free;
  end;
end;

function TTrayDatabase.UpdateDevLog(AId: Integer; 
  const ARequirement, AImplementation, ATags, ANotes: string): Boolean;
var
  Query: TFDQuery;
  NowStr: string;
begin
  Result := False;
  if not FInitialized then Exit;
  
  NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'UPDATE DevLogs SET Requirement = :Requirement, Implementation = :Implementation, ' +
      'Tags = :Tags, Notes = :Notes, UpdatedAt = :UpdatedAt WHERE Id = :Id';
    Query.ParamByName('Requirement').AsString := ARequirement;
    Query.ParamByName('Implementation').AsString := AImplementation;
    Query.ParamByName('Tags').AsString := ATags;
    Query.ParamByName('Notes').AsString := ANotes;
    Query.ParamByName('UpdatedAt').AsString := NowStr;
    Query.ParamByName('Id').AsInteger := AId;
    Query.ExecSQL;
    Result := Query.RowsAffected > 0;
  finally
    Query.Free;
  end;
end;

function TTrayDatabase.DeleteDevLog(AId: Integer): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not FInitialized then Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM DevLogs WHERE Id = :Id';
    Query.ParamByName('Id').AsInteger := AId;
    Query.ExecSQL;
    Result := Query.RowsAffected > 0;
  finally
    Query.Free;
  end;
end;

{ 常用命令操作 }

function TTrayDatabase.AddCommand(const AName, ACommand, AProjectName, ACategory: string;
  AIsDangerous: Boolean): Integer;
var
  Query: TFDQuery;
begin
  Result := -1;
  if not FInitialized then Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT INTO QuickCommands (CommandName, CommandText, ProjectName, Category, IsDangerous) ' +
      'VALUES (:Name, :Command, :Project, :Category, :Dangerous)';
    Query.ParamByName('Name').AsString := AName;
    Query.ParamByName('Command').AsString := ACommand;
    if AProjectName <> '' then
      Query.ParamByName('Project').AsString := AProjectName
    else
      Query.ParamByName('Project').Clear;
    Query.ParamByName('Category').AsString := ACategory;
    Query.ParamByName('Dangerous').AsInteger := Ord(AIsDangerous);
    Query.ExecSQL;
    
    Query.SQL.Text := 'SELECT last_insert_rowid()';
    Query.Open;
    Result := Query.Fields[0].AsInteger;
  finally
    Query.Free;
  end;
end;

function TTrayDatabase.GetCommands(const AProjectName: string): TArray<TQuickCommandRecord>;
var
  Query: TFDQuery;
  List: TList<TQuickCommandRecord>;
  Rec: TQuickCommandRecord;
begin
  SetLength(Result, 0);
  if not FInitialized then Exit;
  
  List := TList<TQuickCommandRecord>.Create;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    if AProjectName = '' then
      Query.SQL.Text := 'SELECT * FROM QuickCommands WHERE IsEnabled = 1 ORDER BY UsageCount DESC'
    else
    begin
      Query.SQL.Text :=
        'SELECT * FROM QuickCommands WHERE IsEnabled = 1 AND (ProjectName IS NULL OR ProjectName = :Project) ORDER BY UsageCount DESC';
      Query.ParamByName('Project').AsString := AProjectName;
    end;
    Query.Open;
    
    while not Query.Eof do
    begin
      Rec.Id := Query.FieldByName('Id').AsInteger;
      Rec.CommandName := Query.FieldByName('CommandName').AsString;
      Rec.CommandText := Query.FieldByName('CommandText').AsString;
      Rec.ProjectName := Query.FieldByName('ProjectName').AsString;
      Rec.Category := Query.FieldByName('Category').AsString;
      Rec.UsageCount := Query.FieldByName('UsageCount').AsInteger;
      Rec.IsDangerous := Query.FieldByName('IsDangerous').AsInteger = 1;
      Rec.IsEnabled := Query.FieldByName('IsEnabled').AsInteger = 1;
      Rec.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      if not Query.FieldByName('LastUsedAt').IsNull then
        Rec.LastUsedAt := Query.FieldByName('LastUsedAt').AsDateTime
      else
        Rec.LastUsedAt := 0;
      List.Add(Rec);
      Query.Next;
    end;
    
    Result := List.ToArray;
  finally
    Query.Free;
    List.Free;
  end;
end;

function TTrayDatabase.GetCommandsByUsage(ALimit: Integer): TArray<TQuickCommandRecord>;
var
  Query: TFDQuery;
  List: TList<TQuickCommandRecord>;
  Rec: TQuickCommandRecord;
begin
  SetLength(Result, 0);
  if not FInitialized then Exit;
  
  List := TList<TQuickCommandRecord>.Create;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'SELECT * FROM QuickCommands WHERE IsEnabled = 1 ORDER BY UsageCount DESC LIMIT :Limit';
    Query.ParamByName('Limit').AsInteger := ALimit;
    Query.Open;
    
    while not Query.Eof do
    begin
      Rec.Id := Query.FieldByName('Id').AsInteger;
      Rec.CommandName := Query.FieldByName('CommandName').AsString;
      Rec.CommandText := Query.FieldByName('CommandText').AsString;
      Rec.ProjectName := Query.FieldByName('ProjectName').AsString;
      Rec.Category := Query.FieldByName('Category').AsString;
      Rec.UsageCount := Query.FieldByName('UsageCount').AsInteger;
      Rec.IsDangerous := Query.FieldByName('IsDangerous').AsInteger = 1;
      Rec.IsEnabled := Query.FieldByName('IsEnabled').AsInteger = 1;
      Rec.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      if not Query.FieldByName('LastUsedAt').IsNull then
        Rec.LastUsedAt := Query.FieldByName('LastUsedAt').AsDateTime
      else
        Rec.LastUsedAt := 0;
      List.Add(Rec);
      Query.Next;
    end;
    
    Result := List.ToArray;
  finally
    Query.Free;
    List.Free;
  end;
end;

procedure TTrayDatabase.IncrementCommandUsage(AId: Integer);
var
  Query: TFDQuery;
  NowStr: string;
begin
  if not FInitialized then Exit;
  
  NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'UPDATE QuickCommands SET UsageCount = UsageCount + 1, LastUsedAt = :LastUsedAt WHERE Id = :Id';
    Query.ParamByName('LastUsedAt').AsString := NowStr;
    Query.ParamByName('Id').AsInteger := AId;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TTrayDatabase.UpdateCommand(AId: Integer; const AName, ACommand, ACategory: string;
  AIsDangerous: Boolean): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not FInitialized then Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'UPDATE QuickCommands SET CommandName = :Name, CommandText = :Command, ' +
      'Category = :Category, IsDangerous = :Dangerous WHERE Id = :Id';
    Query.ParamByName('Name').AsString := AName;
    Query.ParamByName('Command').AsString := ACommand;
    Query.ParamByName('Category').AsString := ACategory;
    Query.ParamByName('Dangerous').AsInteger := Ord(AIsDangerous);
    Query.ParamByName('Id').AsInteger := AId;
    Query.ExecSQL;
    Result := Query.RowsAffected > 0;
  finally
    Query.Free;
  end;
end;

function TTrayDatabase.DeleteCommand(AId: Integer): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not FInitialized then Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM QuickCommands WHERE Id = :Id';
    Query.ParamByName('Id').AsInteger := AId;
    Query.ExecSQL;
    Result := Query.RowsAffected > 0;
  finally
    Query.Free;
  end;
end;

{ 黑名单操作 }

function TTrayDatabase.IsCommandBlacklisted(const ACommand: string): Boolean;
var
  Query: TFDQuery;
  Pattern: string;
  Cmd: string;
begin
  Result := False;
  if not FInitialized then Exit;
  
  Cmd := UpperCase(Trim(ACommand));
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT Pattern FROM CommandBlacklist WHERE IsEnabled = 1';
    Query.Open;
    
    while not Query.Eof do
    begin
      Pattern := UpperCase(Query.FieldByName('Pattern').AsString);
      // 简单通配符匹配
      if (Pos(Pattern, Cmd) > 0) or 
         (Pattern = Cmd) or
         ((Pos('%', Pattern) > 0) and MatchesMask(Cmd, StringReplace(Pattern, '%', '*', [rfReplaceAll]))) then
      begin
        Result := True;
        Break;
      end;
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

function TTrayDatabase.GetBlacklist: TArray<TBlacklistRecord>;
var
  Query: TFDQuery;
  List: TList<TBlacklistRecord>;
  Rec: TBlacklistRecord;
begin
  SetLength(Result, 0);
  if not FInitialized then Exit;
  
  List := TList<TBlacklistRecord>.Create;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT * FROM CommandBlacklist ORDER BY Id';
    Query.Open;
    
    while not Query.Eof do
    begin
      Rec.Id := Query.FieldByName('Id').AsInteger;
      Rec.Pattern := Query.FieldByName('Pattern').AsString;
      Rec.Reason := Query.FieldByName('Reason').AsString;
      Rec.IsEnabled := Query.FieldByName('IsEnabled').AsInteger = 1;
      List.Add(Rec);
      Query.Next;
    end;
    
    Result := List.ToArray;
  finally
    Query.Free;
    List.Free;
  end;
end;

function TTrayDatabase.AddToBlacklist(const APattern, AReason: string): Integer;
var
  Query: TFDQuery;
begin
  Result := -1;
  if not FInitialized then Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'INSERT OR IGNORE INTO CommandBlacklist (Pattern, Reason) VALUES (:Pattern, :Reason)';
    Query.ParamByName('Pattern').AsString := APattern;
    Query.ParamByName('Reason').AsString := AReason;
    Query.ExecSQL;
    
    if Query.RowsAffected > 0 then
    begin
      Query.SQL.Text := 'SELECT last_insert_rowid()';
      Query.Open;
      Result := Query.Fields[0].AsInteger;
    end;
  finally
    Query.Free;
  end;
end;

function TTrayDatabase.RemoveFromBlacklist(AId: Integer): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not FInitialized then Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM CommandBlacklist WHERE Id = :Id';
    Query.ParamByName('Id').AsInteger := AId;
    Query.ExecSQL;
    Result := Query.RowsAffected > 0;
  finally
    Query.Free;
  end;
end;

{ 项目历史 }

function TTrayDatabase.GetProjectHistory: TArray<string>;
var
  Query: TFDQuery;
  List: TList<string>;
begin
  SetLength(Result, 0);
  if not FInitialized then Exit;
  
  List := TList<string>.Create;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT ProjectName FROM ProjectHistory ORDER BY LastUsedAt DESC LIMIT 50';
    Query.Open;
    
    while not Query.Eof do
    begin
      List.Add(Query.FieldByName('ProjectName').AsString);
      Query.Next;
    end;
    
    Result := List.ToArray;
  finally
    Query.Free;
    List.Free;
  end;
end;

procedure TTrayDatabase.AddProjectHistory(const AProjectName: string; const AProjectPath: string);
var
  Query: TFDQuery;
  NowStr: string;
begin
  if not FInitialized then Exit;
  if Trim(AProjectName) = '' then Exit;
  
  NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    // 使用 UPSERT 模式
    Query.SQL.Text :=
      'INSERT INTO ProjectHistory (ProjectName, ProjectPath, LastUsedAt, UsageCount) ' +
      'VALUES (:Name, :Path, :NowTime, 1) ' +
      'ON CONFLICT(ProjectName) DO UPDATE SET ' +
      'LastUsedAt = :NowTime, UsageCount = UsageCount + 1';
    Query.ParamByName('Name').AsString := AProjectName;
    if AProjectPath <> '' then
      Query.ParamByName('Path').AsString := AProjectPath
    else
      Query.ParamByName('Path').Clear;
    Query.ParamByName('NowTime').AsString := NowStr;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

{ 设置操作 }

function TTrayDatabase.GetSetting(const AKey: string; const ADefault: string): string;
var
  Query: TFDQuery;
begin
  Result := ADefault;
  if not FInitialized then Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT Value FROM TraySettings WHERE Key = :Key';
    Query.ParamByName('Key').AsString := AKey;
    Query.Open;
    
    if not Query.Eof then
      Result := Query.FieldByName('Value').AsString;
  finally
    Query.Free;
  end;
end;

procedure TTrayDatabase.SetSetting(const AKey, AValue: string);
var
  Query: TFDQuery;
  NowStr: string;
begin
  if not FInitialized then Exit;
  
  NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT INTO TraySettings (Key, Value, UpdatedAt) VALUES (:Key, :Value, :UpdatedAt) ' +
      'ON CONFLICT(Key) DO UPDATE SET Value = :Value, UpdatedAt = :UpdatedAt';
    Query.ParamByName('Key').AsString := AKey;
    Query.ParamByName('Value').AsString := AValue;
    Query.ParamByName('UpdatedAt').AsString := NowStr;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TTrayDatabase.GetSettingInt(const AKey: string; ADefault: Integer): Integer;
var
  S: string;
begin
  S := GetSetting(AKey, '');
  if S = '' then
    Result := ADefault
  else
    Result := StrToIntDef(S, ADefault);
end;

function TTrayDatabase.GetSettingBool(const AKey: string; ADefault: Boolean): Boolean;
var
  S: string;
begin
  S := GetSetting(AKey, '');
  if S = '' then
    Result := ADefault
  else
    Result := (S = '1') or (UpperCase(S) = 'TRUE');
end;

initialization

finalization
  FreeAndNil(GTrayDatabase);

end.
