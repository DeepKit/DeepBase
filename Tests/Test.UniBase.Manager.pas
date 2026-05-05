unit Test.UniBase.Manager;

{*******************************************************************************
  UniBase Manager 模块单元测试
  
  测试内容:
  - Initialize / InitializeEx / InitializeWithDB
  - Finalize
  - 错误码
  - 健康检查
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.IOUtils, System.Classes,
  FireDAC.Comp.Client,
  UniBase.Types, UniBase.Manager;

type
  [TestFixture]
  TTestUniBaseManager = class
  private
    FTempPath: string;
    FManager: TUniBaseManager;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Initialize_WithMemoryDB;
    
    [Test]
    procedure Test_Initialize_WithFilePath;
    
    [Test]
    procedure Test_Initialize_DoubleInit_ShouldSucceed;
    
    [Test]
    procedure Test_Finalize_WithoutInit;
    
    [Test]
    procedure Test_InitializeEx_ReturnsErrorMsg;
    
    [Test]
    procedure Test_HealthCheck_AfterInit;
    
    [Test]
    procedure Test_HealthCheck_BeforeInit_ShouldFail;
    
    [Test]
    procedure Test_ErrorCode_Success_AfterSuccessfulInit;
    
    [Test]
    procedure Test_Singleton_ReturnsSameInstance;
    
    [Test]
    procedure Test_Properties_AfterInit;

    [Test]
    procedure Test_MRUItemPath_IsMigratedToItemKey_OnLegacyDatabase;

    [Test]
    procedure Test_OperationalRetention_ArchivesOldRowsAcrossCoreTables;
  end;

implementation

uses
  System.DateUtils;

{ TTestUniBaseManager }

procedure TTestUniBaseManager.Setup;
begin
  // 创建临时目录用于测试
  FTempPath := TPath.Combine(TPath.GetTempPath, 'UniBaseTest_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FTempPath);
  
  // 获取全局单例引用
  FManager := UniBase.Manager.UniBase;
  
  // 确保全局单例被重置
  if FManager.IsInitialized then
    FManager.Finalize;
end;

procedure TTestUniBaseManager.TearDown;
begin
  // 清理
  if FManager.IsInitialized then
    FManager.Finalize;
    
  // 删除临时目录
  if TDirectory.Exists(FTempPath) then
    TDirectory.Delete(FTempPath, True);
end;

procedure TTestUniBaseManager.Test_Initialize_WithMemoryDB;
var
  InitResult: Boolean;
begin
  // 使用内存数据库初始化
  InitResult := FManager.InitializeWithDB(':memory:');
  
  Assert.IsTrue(InitResult, '使用内存数据库初始化应该成功');
  Assert.IsTrue(FManager.IsInitialized, 'IsInitialized 属性应该为 True');
  Assert.AreEqual(ecSuccess, FManager.InitErrorCode, '错误码应该为 ecSuccess');
end;

procedure TTestUniBaseManager.Test_Initialize_WithFilePath;
var
  DBPath: string;
  InitResult: Boolean;
begin
  DBPath := TPath.Combine(FTempPath, 'test.db');
  
  InitResult := FManager.InitializeWithDB(DBPath);
  
  Assert.IsTrue(InitResult, '使用文件路径初始化应该成功');
  Assert.IsTrue(TFile.Exists(DBPath), '数据库文件应该被创建');
end;

procedure TTestUniBaseManager.Test_Initialize_DoubleInit_ShouldSucceed;
var
  Result1, Result2: Boolean;
begin
  Result1 := FManager.InitializeWithDB(':memory:');
  Result2 := FManager.InitializeWithDB(':memory:');
  
  Assert.IsTrue(Result1, '第一次初始化应该成功');
  Assert.IsTrue(Result2, '第二次初始化应该也返回成功（已经初始化）');
end;

procedure TTestUniBaseManager.Test_Finalize_WithoutInit;
begin
  // 在未初始化的情况下调用 Finalize 不应该崩溃
  FManager.Finalize;
  // 如果执行到这里，说明没有崩溃
  Assert.Pass('未初始化时调用 Finalize 没有抛出异常');
end;

procedure TTestUniBaseManager.Test_InitializeEx_ReturnsErrorMsg;
var
  ErrorMsg: string;
  InitResult: Boolean;
begin
  // 使用内存数据库测试 InitializeWithDB (InitializeEx 需要 root.txt)
  FManager.Finalize;
  InitResult := FManager.InitializeWithDB(':memory:');
  
  Assert.IsTrue(InitResult, 'InitializeWithDB 应该成功');
  Assert.IsTrue(FManager.IsInitialized, 'IsInitialized 应该为 True');
end;

procedure TTestUniBaseManager.Test_HealthCheck_AfterInit;
var
  Health: THealthCheckResult;
begin
  FManager.InitializeWithDB(':memory:');
  
  Health := FManager.HealthCheck;
  
  Assert.IsTrue(Health.IsHealthy, 'HealthCheck 应该返回健康状态');
  Assert.IsTrue(Health.ConfigDBOk, '数据库应该已连接');
end;

procedure TTestUniBaseManager.Test_HealthCheck_BeforeInit_ShouldFail;
var
  Health: THealthCheckResult;
begin
  // 不调用 Initialize
  Health := FManager.HealthCheck;
  
  Assert.IsFalse(Health.IsHealthy, '未初始化时 HealthCheck 应该返回不健康');
  Assert.IsFalse(Health.ConfigDBOk, '数据库不应该连接');
end;

procedure TTestUniBaseManager.Test_ErrorCode_Success_AfterSuccessfulInit;
begin
  FManager.InitializeWithDB(':memory:');
  
  Assert.AreEqual(ecSuccess, FManager.InitErrorCode, 
    '成功初始化后错误码应该为 ecSuccess');
end;

procedure TTestUniBaseManager.Test_Singleton_ReturnsSameInstance;
var
  Instance1, Instance2: TUniBaseManager;
begin
  Instance1 := UniBase.Manager.UniBase;
  Instance2 := UniBase.Manager.UniBase;
  
  Assert.AreSame(Instance1, Instance2, 'UniBase 函数应该返回相同的实例');
end;

procedure TTestUniBaseManager.Test_Properties_AfterInit;
begin
  FManager.InitializeWithDB(':memory:');
  
  Assert.AreEqual(UNIBASE_VERSION, UNIBASE_VERSION, 'Version 常量应存在');
  Assert.IsTrue(FManager.IsInitialized, 'IsInitialized 应该为 True');
end;

procedure TTestUniBaseManager.Test_MRUItemPath_IsMigratedToItemKey_OnLegacyDatabase;
var
  DBPath, LegacyItemPath: string;
  SetupConn: TFDConnection;
  Query: TFDQuery;
begin
  DBPath := TPath.Combine(FTempPath, 'legacy_mru.db');
  LegacyItemPath := TPath.Combine(FTempPath, 'legacy_file.txt');

  SetupConn := TFDConnection.Create(nil);
  try
    SetupConn.DriverName := 'SQLite';
    SetupConn.Params.Database := DBPath;
    SetupConn.LoginPrompt := False;
    SetupConn.Connected := True;

    Query := TFDQuery.Create(nil);
    try
      Query.Connection := SetupConn;
      Query.SQL.Text :=
        'CREATE TABLE IF NOT EXISTS MRU (' +
        'ID INTEGER PRIMARY KEY AUTOINCREMENT, ' +
        'Category TEXT NOT NULL DEFAULT ''File'', ' +
        'ItemPath TEXT NOT NULL, ' +
        'DisplayName TEXT, ' +
        'IconIndex INTEGER DEFAULT 0, ' +
        'LastAccess TEXT, ' +
        'AccessCount INTEGER DEFAULT 1, ' +
        'IsPinned INTEGER DEFAULT 0, ' +
        'Extra TEXT, ' +
        'UNIQUE(Category, ItemPath)' +
        ')';
      Query.ExecSQL;

      Query.SQL.Text :=
        'INSERT INTO MRU (Category, ItemPath, DisplayName, IconIndex, LastAccess, AccessCount, IsPinned) ' +
        'VALUES (''File'', :ItemPath, ''legacy-item'', 0, :LastAccess, 3, 0)';
      Query.ParamByName('ItemPath').AsString := LegacyItemPath;
      Query.ParamByName('LastAccess').AsString := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    SetupConn.Free;
  end;

  Assert.IsTrue(FManager.InitializeWithDB(DBPath), '初始化旧 MRU 数据库应成功');

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := TFDConnection(FManager.ConfigDB);

    Query.SQL.Text := 'SELECT COUNT(*) FROM pragma_table_info(''MRU'') WHERE name = ''ItemKey''';
    Query.Open;
    try
      Assert.AreEqual(1, Query.Fields[0].AsInteger, 'MRU.ItemKey 列应被自动补齐');
    finally
      Query.Close;
    end;

    Query.SQL.Text :=
      'SELECT ItemKey FROM MRU WHERE Category = ''File'' AND DisplayName = ''legacy-item''';
    Query.Open;
    try
      Assert.IsFalse(Query.Eof, '旧 MRU 记录应继续存在');
      Assert.AreEqual(LegacyItemPath, Query.FieldByName('ItemKey').AsString,
        '旧 ItemPath 应迁移到 ItemKey');
    finally
      Query.Close;
    end;
  finally
    Query.Free;
  end;
end;

procedure TTestUniBaseManager.Test_OperationalRetention_ArchivesOldRowsAcrossCoreTables;
var
  DBPath: string;
  Query: TFDQuery;
  OldTime, NewTime: string;

  function CountRows(const SQL: string): Integer;
  begin
    Result := 0;
    Query.SQL.Text := SQL;
    Query.Open;
    try
      if not Query.Eof then
        Result := Query.Fields[0].AsInteger;
    finally
      Query.Close;
    end;
  end;
begin
  DBPath := TPath.Combine(FTempPath, 'retention_test.db');
  Assert.IsTrue(FManager.InitializeWithDB(DBPath));

  OldTime := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', IncDay(Now, -45));
  NewTime := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', IncDay(Now, -5));

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := TFDConnection(FManager.ConfigDB);

    // Force retention to run again on next initialization.
    Query.SQL.Text :=
      'INSERT OR REPLACE INTO Settings (Key, Value) VALUES ' +
      '(:Key1, :Value1), (:Key2, :Value2), (:Key3, :Value3), (:Key4, :Value4)';
    Query.ParamByName('Key1').AsString := 'Maintenance.Retention.LogsDays';
    Query.ParamByName('Value1').AsString := '30';
    Query.ParamByName('Key2').AsString := 'Maintenance.Retention.LLMCallsDays';
    Query.ParamByName('Value2').AsString := '30';
    Query.ParamByName('Key3').AsString := 'Maintenance.Retention.ExceptionReportsDays';
    Query.ParamByName('Value3').AsString := '30';
    Query.ParamByName('Key4').AsString := 'Maintenance.Retention.LastRunDate';
    Query.ParamByName('Value4').AsString := '2000-01-01';
    Query.ExecSQL;

    Query.SQL.Text :=
      'INSERT INTO Logs (LogTime, LogLevel, Source, Message, StackTrace, ThreadId) ' +
      'VALUES (:LogTime, ''INFO'', ''RetentionCase'', :Msg, '''', 1)';
    Query.ParamByName('LogTime').AsString := OldTime;
    Query.ParamByName('Msg').AsString := 'old-log';
    Query.ExecSQL;
    Query.ParamByName('LogTime').AsString := NewTime;
    Query.ParamByName('Msg').AsString := 'new-log';
    Query.ExecSQL;

    Query.SQL.Text :=
      'INSERT INTO LLMCalls (ConfigName, ProviderCode, ModelId, UserPrompt, AssistantResponse, CallTime) ' +
      'VALUES (''RetentionCfg'', ''openai'', ''gpt-test'', :Prompt, ''ok'', :CallTime)';
    Query.ParamByName('Prompt').AsString := 'old-llm';
    Query.ParamByName('CallTime').AsString := OldTime;
    Query.ExecSQL;
    Query.ParamByName('Prompt').AsString := 'new-llm';
    Query.ParamByName('CallTime').AsString := NewTime;
    Query.ExecSQL;

    Query.SQL.Text :=
      'INSERT INTO ExceptionReports (ExceptionClass, ExceptionMessage, StackTrace, OccurredAt) ' +
      'VALUES (''RetentionCaseEx'', :Msg, '''', :OccurredAt)';
    Query.ParamByName('Msg').AsString := 'old-ex';
    Query.ParamByName('OccurredAt').AsString := OldTime;
    Query.ExecSQL;
    Query.ParamByName('Msg').AsString := 'new-ex';
    Query.ParamByName('OccurredAt').AsString := NewTime;
    Query.ExecSQL;
  finally
    Query.Free;
  end;

  FManager.Finalize;
  Assert.IsTrue(FManager.InitializeWithDB(DBPath));

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := TFDConnection(FManager.ConfigDB);

    Assert.AreEqual(0, CountRows(
      'SELECT COUNT(*) FROM Logs WHERE Source = ''RetentionCase'' AND Message = ''old-log'''));
    Assert.AreEqual(1, CountRows(
      'SELECT COUNT(*) FROM Logs WHERE Source = ''RetentionCase'' AND Message = ''new-log'''));
    Assert.AreEqual(1, CountRows(
      'SELECT COUNT(*) FROM Logs_Archive WHERE Source = ''RetentionCase'' AND Message = ''old-log'''));

    Assert.AreEqual(0, CountRows(
      'SELECT COUNT(*) FROM LLMCalls WHERE ConfigName = ''RetentionCfg'' AND UserPrompt = ''old-llm'''));
    Assert.AreEqual(1, CountRows(
      'SELECT COUNT(*) FROM LLMCalls WHERE ConfigName = ''RetentionCfg'' AND UserPrompt = ''new-llm'''));
    Assert.AreEqual(1, CountRows(
      'SELECT COUNT(*) FROM LLMCalls_Archive WHERE ConfigName = ''RetentionCfg'' AND UserPrompt = ''old-llm'''));

    Assert.AreEqual(0, CountRows(
      'SELECT COUNT(*) FROM ExceptionReports WHERE ExceptionClass = ''RetentionCaseEx'' AND ExceptionMessage = ''old-ex'''));
    Assert.AreEqual(1, CountRows(
      'SELECT COUNT(*) FROM ExceptionReports WHERE ExceptionClass = ''RetentionCaseEx'' AND ExceptionMessage = ''new-ex'''));
    Assert.AreEqual(1, CountRows(
      'SELECT COUNT(*) FROM ExceptionReports_Archive WHERE ExceptionClass = ''RetentionCaseEx'' AND ExceptionMessage = ''old-ex'''));
  finally
    Query.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseManager);

end.
