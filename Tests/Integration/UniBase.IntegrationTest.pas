{ ============================================================================
  UniBase.IntegrationTest - 集成测试框架核心模块
  
  Version: 1.0
  Description: 提供端到端集成测试能力，支持完整业务流程测试
  
  Features:
    - 测试环境自动配置与清理
    - 测试数据库隔离
    - 测试数据生成与管理
    - 断言增强
    - 测试报告生成
    - 性能基准测试
    - CI/CD 集成支持
  ============================================================================ }

unit UniBase.IntegrationTest;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.Diagnostics,
  System.Generics.Collections,
  System.SyncObjs,
  System.DateUtils,
  System.Math,
  DUnitX.TestFramework,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.DApt;

type
  // Forward declarations
  TIntegrationTestContext = class;
  TTestDataGenerator = class;
  TTestReporter = class;
  TPerformanceBenchmark = class;
  
  // ============================================================================
  // Test Result Types
  // ============================================================================
  
  TTestResultStatus = (trsPass, trsFail, trsSkip, trsError);
  
  /// <summary>
  /// Single test result
  /// </summary>
  TTestResult = record
    TestName: string;
    FixtureName: string;
    Status: TTestResultStatus;
    Message: string;
    Duration: Int64;  // milliseconds
    StartTime: TDateTime;
    StackTrace: string;
    
    class function Pass(const ATestName: string; ADuration: Int64): TTestResult; static;
    class function Fail(const ATestName, AMessage: string; ADuration: Int64): TTestResult; static;
    class function Skip(const ATestName, AReason: string): TTestResult; static;
    class function Error(const ATestName, AMessage, AStack: string): TTestResult; static;
  end;
  
  TTestResults = TArray<TTestResult>;
  
  /// <summary>
  /// Test suite summary
  /// </summary>
  TTestSummary = record
    TotalTests: Integer;
    PassCount: Integer;
    FailCount: Integer;
    SkipCount: Integer;
    ErrorCount: Integer;
    TotalDuration: Int64;
    StartTime: TDateTime;
    EndTime: TDateTime;
    
    function PassRate: Double;
    procedure Reset;
  end;
  
  // ============================================================================
  // Test Environment
  // ============================================================================
  
  /// <summary>
  /// Test environment configuration
  /// </summary>
  TTestEnvironment = record
    DatabasePath: string;
    TempPath: string;
    LogPath: string;
    ReportPath: string;
    Isolation: Boolean;     // Use isolated database
    Cleanup: Boolean;       // Cleanup after tests
    Verbose: Boolean;       // Verbose logging
    ParallelExecution: Boolean;
    Timeout: Integer;       // Test timeout in seconds
    
    class function Default: TTestEnvironment; static;
    class function CI: TTestEnvironment; static;
  end;
  
  // ============================================================================
  // Test Context
  // ============================================================================
  
  /// <summary>
  /// Provides test execution context and utilities
  /// </summary>
  TIntegrationTestContext = class
  private
    FEnvironment: TTestEnvironment;
    FConnection: TFDConnection;
    FResults: TList<TTestResult>;
    FSummary: TTestSummary;
    FDataGenerator: TTestDataGenerator;
    FReporter: TTestReporter;
    FBenchmark: TPerformanceBenchmark;
    FStopwatch: TStopwatch;
    FCurrentTest: string;
    FTempFiles: TList<string>;
    FLock: TCriticalSection;
    FInitialized: Boolean;
    
    procedure CreateTables;
    procedure CleanupTempFiles;
  public
    constructor Create(const AEnvironment: TTestEnvironment);
    destructor Destroy; override;
    
    /// <summary>Initialize test environment</summary>
    procedure Initialize;
    
    /// <summary>Cleanup test environment</summary>
    procedure Cleanup;
    
    /// <summary>Start a test</summary>
    procedure BeginTest(const TestName: string);
    
    /// <summary>End current test with result</summary>
    procedure EndTest(Status: TTestResultStatus; const Message: string = '');
    
    /// <summary>Record a test result</summary>
    procedure RecordResult(const Result: TTestResult);
    
    /// <summary>Create a temporary file</summary>
    function CreateTempFile(const Extension: string = '.tmp'): string;
    
    /// <summary>Create a temporary directory</summary>
    function CreateTempDir: string;
    
    /// <summary>Execute SQL in test database</summary>
    procedure ExecuteSQL(const SQL: string);
    
    /// <summary>Query test database</summary>
    function QuerySQL(const SQL: string): TFDQuery;
    
    /// <summary>Get test results</summary>
    function GetResults: TTestResults;
    
    /// <summary>Get test summary</summary>
    function GetSummary: TTestSummary;
    
    /// <summary>Generate report</summary>
    procedure GenerateReport(const Format: string = 'html');
    
    property Environment: TTestEnvironment read FEnvironment;
    property Connection: TFDConnection read FConnection;
    property DataGenerator: TTestDataGenerator read FDataGenerator;
    property Reporter: TTestReporter read FReporter;
    property Benchmark: TPerformanceBenchmark read FBenchmark;
    property Initialized: Boolean read FInitialized;
  end;
  
  // ============================================================================
  // Test Data Generator
  // ============================================================================
  
  /// <summary>
  /// Generates test data for various scenarios
  /// </summary>
  TTestDataGenerator = class
  private
    FConnection: TFDConnection;
    FRandomSeed: Integer;
    
    function GetRandomString(Length: Integer): string;
    function GetRandomInt(Min, Max: Integer): Integer;
    function GetRandomDate(const MinDate, MaxDate: TDateTime): TDateTime;
  public
    constructor Create(AConnection: TFDConnection);
    
    /// <summary>Set random seed for reproducible tests</summary>
    procedure SetSeed(Seed: Integer);
    
    /// <summary>Generate random user data</summary>
    function GenerateUser: TJSONObject;
    
    /// <summary>Generate random config entries</summary>
    function GenerateConfig(Count: Integer): TJSONArray;
    
    /// <summary>Generate random log entries</summary>
    function GenerateLogs(Count: Integer): TJSONArray;
    
    /// <summary>Insert test users into database</summary>
    procedure InsertUsers(Count: Integer);
    
    /// <summary>Insert test configs into database</summary>
    procedure InsertConfigs(Count: Integer);
    
    /// <summary>Insert test logs into database</summary>
    procedure InsertLogs(Count: Integer);
    
    /// <summary>Clear all test data</summary>
    procedure ClearAllData;
    
    /// <summary>Generate random email</summary>
    function RandomEmail: string;
    
    /// <summary>Generate random phone</summary>
    function RandomPhone: string;
    
    /// <summary>Generate random name</summary>
    function RandomName: string;
    
    /// <summary>Generate random lorem ipsum text</summary>
    function RandomText(WordCount: Integer): string;
  end;
  
  // ============================================================================
  // Test Reporter
  // ============================================================================
  
  TReportFormat = (rfText, rfHTML, rfJSON, rfXML, rfJUnit);
  
  /// <summary>
  /// Generates test reports in various formats
  /// </summary>
  TTestReporter = class
  private
    FOutputPath: string;
    
    function GenerateTextReport(const Results: TTestResults; const Summary: TTestSummary): string;
    function GenerateHTMLReport(const Results: TTestResults; const Summary: TTestSummary): string;
    function GenerateJSONReport(const Results: TTestResults; const Summary: TTestSummary): string;
    function GenerateXMLReport(const Results: TTestResults; const Summary: TTestSummary): string;
    function GenerateJUnitReport(const Results: TTestResults; const Summary: TTestSummary): string;
    
    function StatusToString(Status: TTestResultStatus): string;
    function StatusToColor(Status: TTestResultStatus): string;
  public
    constructor Create(const AOutputPath: string);
    
    /// <summary>Generate report in specified format</summary>
    function Generate(const Results: TTestResults; const Summary: TTestSummary;
      Format: TReportFormat): string;
    
    /// <summary>Save report to file</summary>
    procedure SaveReport(const Results: TTestResults; const Summary: TTestSummary;
      Format: TReportFormat; const FileName: string = '');
    
    /// <summary>Print summary to console</summary>
    procedure PrintSummary(const Summary: TTestSummary);
    
    property OutputPath: string read FOutputPath write FOutputPath;
  end;
  
  // ============================================================================
  // Performance Benchmark
  // ============================================================================
  
  TBenchmarkResult = record
    Name: string;
    Iterations: Integer;
    TotalTime: Int64;    // milliseconds
    MinTime: Int64;
    MaxTime: Int64;
    AvgTime: Double;
    MedianTime: Int64;
    StdDev: Double;
    OpsPerSecond: Double;
    
    function ToString: string;
  end;
  
  TBenchmarkResults = TArray<TBenchmarkResult>;
  
  /// <summary>
  /// Performance benchmarking utility
  /// </summary>
  TPerformanceBenchmark = class
  private
    FResults: TList<TBenchmarkResult>;
    FWarmupIterations: Integer;
    FBaselines: TDictionary<string, Double>;
    
    function CalculateStats(const Times: TArray<Int64>): TBenchmarkResult;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Run a benchmark</summary>
    function Run(const Name: string; Iterations: Integer;
      const Action: TProc): TBenchmarkResult;
    
    /// <summary>Run benchmark with setup and teardown</summary>
    function RunWithSetup(const Name: string; Iterations: Integer;
      const Setup, Action, Teardown: TProc): TBenchmarkResult;
    
    /// <summary>Compare with baseline</summary>
    function CompareWithBaseline(const Name: string;
      const ABenchmark: TBenchmarkResult): Double;
    
    /// <summary>Set baseline for comparison</summary>
    procedure SetBaseline(const Name: string; OpsPerSecond: Double);
    
    /// <summary>Load baselines from file</summary>
    procedure LoadBaselines(const FileName: string);
    
    /// <summary>Save baselines to file</summary>
    procedure SaveBaselines(const FileName: string);
    
    /// <summary>Get all benchmark results</summary>
    function GetResults: TBenchmarkResults;
    
    /// <summary>Clear results</summary>
    procedure ClearResults;
    
    /// <summary>Generate benchmark report</summary>
    function GenerateReport: string;
    
    property WarmupIterations: Integer read FWarmupIterations write FWarmupIterations;
  end;
  
  // ============================================================================
  // Enhanced Assertions
  // ============================================================================
  
  /// <summary>
  /// Extended assertion methods for integration tests
  /// </summary>
  TIntegrationAssert = class
  public
    /// <summary>Assert that database table exists</summary>
    class procedure TableExists(Connection: TFDConnection; const TableName: string;
      const Message: string = '');
    
    /// <summary>Assert row count in table</summary>
    class procedure RowCount(Connection: TFDConnection; const TableName: string;
      Expected: Integer; const Message: string = '');
    
    /// <summary>Assert row exists with conditions</summary>
    class procedure RowExists(Connection: TFDConnection; const TableName, Where: string;
      const Message: string = '');
    
    /// <summary>Assert query returns expected count</summary>
    class procedure QueryCount(Connection: TFDConnection; const SQL: string;
      Expected: Integer; const Message: string = '');
    
    /// <summary>Assert file exists</summary>
    class procedure FileExists(const FileName: string; const Message: string = '');
    
    /// <summary>Assert file contains text</summary>
    class procedure FileContains(const FileName, Text: string; const Message: string = '');
    
    /// <summary>Assert JSON structure</summary>
    class procedure JSONHasKey(const JSON: TJSONObject; const Key: string;
      const Message: string = '');
    
    /// <summary>Assert JSON value</summary>
    class procedure JSONEquals(const JSON: TJSONObject; const Key, Expected: string;
      const Message: string = '');
    
    /// <summary>Assert execution time</summary>
    class procedure ExecutesWithin(const Action: TProc; MaxMilliseconds: Int64;
      const Message: string = '');
    
    /// <summary>Assert no memory leak</summary>
    class procedure NoMemoryLeak(const Action: TProc; ToleranceBytes: Int64 = 1024;
      const Message: string = '');
    
    /// <summary>Assert exception type</summary>
    class procedure RaisesException<T: Exception>(const Action: TProc;
      const Message: string = '');
    
    /// <summary>Assert exception with message</summary>
    class procedure RaisesExceptionWithMessage(const Action: TProc;
      const ExpectedMessage: string; const Message: string = '');
  end;
  
  // ============================================================================
  // Integration Test Base Class
  // ============================================================================
  
  /// <summary>
  /// Base class for integration tests
  /// </summary>
  [TestFixture]
  TIntegrationTestBase = class
  private
    class var FSharedContext: TIntegrationTestContext;
  protected
    FContext: TIntegrationTestContext;
    
    /// <summary>Get shared test context (singleton)</summary>
    class function GetSharedContext: TIntegrationTestContext;
    
    /// <summary>Initialize test data specific to this test class</summary>
    procedure InitializeTestData; virtual;
    
    /// <summary>Cleanup test data specific to this test class</summary>
    procedure CleanupTestData; virtual;
  public
    [SetupFixture]
    procedure SetupFixture; virtual;
    
    [TearDownFixture]
    procedure TearDownFixture; virtual;
    
    [Setup]
    procedure Setup; virtual;
    
    [TearDown]
    procedure TearDown; virtual;
    
    class destructor Destroy;
  end;

// ============================================================================
// Global Functions
// ============================================================================

/// <summary>Create test context with default environment</summary>
function CreateTestContext: TIntegrationTestContext;

/// <summary>Create test context with CI environment</summary>
function CreateCITestContext: TIntegrationTestContext;

/// <summary>Run all integration tests</summary>
function RunIntegrationTests(const OutputPath: string = ''): Boolean;

implementation

uses
  Winapi.Windows,
  Winapi.PsAPI;

// ============================================================================
// TTestResult
// ============================================================================

class function TTestResult.Pass(const ATestName: string; ADuration: Int64): TTestResult;
begin
  Result.TestName := ATestName;
  Result.Status := trsPass;
  Result.Message := '';
  Result.Duration := ADuration;
  Result.StartTime := Now;
  Result.StackTrace := '';
end;

class function TTestResult.Fail(const ATestName, AMessage: string; ADuration: Int64): TTestResult;
begin
  Result.TestName := ATestName;
  Result.Status := trsFail;
  Result.Message := AMessage;
  Result.Duration := ADuration;
  Result.StartTime := Now;
  Result.StackTrace := '';
end;

class function TTestResult.Skip(const ATestName, AReason: string): TTestResult;
begin
  Result.TestName := ATestName;
  Result.Status := trsSkip;
  Result.Message := AReason;
  Result.Duration := 0;
  Result.StartTime := Now;
  Result.StackTrace := '';
end;

class function TTestResult.Error(const ATestName, AMessage, AStack: string): TTestResult;
begin
  Result.TestName := ATestName;
  Result.Status := trsError;
  Result.Message := AMessage;
  Result.Duration := 0;
  Result.StartTime := Now;
  Result.StackTrace := AStack;
end;

// ============================================================================
// TTestSummary
// ============================================================================

function TTestSummary.PassRate: Double;
begin
  if TotalTests > 0 then
    Result := (PassCount / TotalTests) * 100
  else
    Result := 0;
end;

procedure TTestSummary.Reset;
begin
  TotalTests := 0;
  PassCount := 0;
  FailCount := 0;
  SkipCount := 0;
  ErrorCount := 0;
  TotalDuration := 0;
  StartTime := Now;
  EndTime := 0;
end;

// ============================================================================
// TTestEnvironment
// ============================================================================

class function TTestEnvironment.Default: TTestEnvironment;
begin
  Result.DatabasePath := ':memory:';
  Result.TempPath := TPath.Combine(TPath.GetTempPath, 'UniBaseTests');
  Result.LogPath := TPath.Combine(Result.TempPath, 'Logs');
  Result.ReportPath := TPath.Combine(Result.TempPath, 'Reports');
  Result.Isolation := True;
  Result.Cleanup := True;
  Result.Verbose := False;
  Result.ParallelExecution := False;
  Result.Timeout := 30;
end;

class function TTestEnvironment.CI: TTestEnvironment;
begin
  Result := Default;
  Result.Verbose := True;
  Result.ParallelExecution := True;
  Result.ReportPath := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'TestResults');
end;

// ============================================================================
// TIntegrationTestContext
// ============================================================================

constructor TIntegrationTestContext.Create(const AEnvironment: TTestEnvironment);
begin
  inherited Create;
  FEnvironment := AEnvironment;
  FResults := TList<TTestResult>.Create;
  FTempFiles := TList<string>.Create;
  FLock := TCriticalSection.Create;
  FSummary.Reset;
  FInitialized := False;
end;

destructor TIntegrationTestContext.Destroy;
begin
  Cleanup;
  FBenchmark.Free;
  FReporter.Free;
  FDataGenerator.Free;
  FConnection.Free;
  FLock.Free;
  FTempFiles.Free;
  FResults.Free;
  inherited;
end;

procedure TIntegrationTestContext.Initialize;
begin
  if FInitialized then Exit;
  
  FLock.Enter;
  try
    // Create directories
    if not TDirectory.Exists(FEnvironment.TempPath) then
      TDirectory.CreateDirectory(FEnvironment.TempPath);
    if not TDirectory.Exists(FEnvironment.LogPath) then
      TDirectory.CreateDirectory(FEnvironment.LogPath);
    if not TDirectory.Exists(FEnvironment.ReportPath) then
      TDirectory.CreateDirectory(FEnvironment.ReportPath);
    
    // Create database connection
    FConnection := TFDConnection.Create(nil);
    FConnection.DriverName := 'SQLite';
    FConnection.Params.Database := FEnvironment.DatabasePath;
    FConnection.LoginPrompt := False;
    FConnection.Connected := True;
    
    // Create test tables
    CreateTables;
    
    // Create helpers
    FDataGenerator := TTestDataGenerator.Create(FConnection);
    FReporter := TTestReporter.Create(FEnvironment.ReportPath);
    FBenchmark := TPerformanceBenchmark.Create;
    
    FSummary.StartTime := Now;
    FInitialized := True;
  finally
    FLock.Leave;
  end;
end;

procedure TIntegrationTestContext.CreateTables;
begin
  // Config table
  FConnection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS Config (' +
    '  Key TEXT PRIMARY KEY,' +
    '  Value TEXT,' +
    '  Category TEXT,' +
    '  Description TEXT,' +
    '  CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,' +
    '  UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP' +
    ')'
  );
  
  // Logs table
  FConnection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS Logs (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  Level TEXT,' +
    '  Message TEXT,' +
    '  Category TEXT,' +
    '  Timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP' +
    ')'
  );
  
  // Users table (for test data)
  FConnection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS Users (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  Username TEXT UNIQUE,' +
    '  Email TEXT,' +
    '  PasswordHash TEXT,' +
    '  Role TEXT DEFAULT ''user'',' +
    '  Active INTEGER DEFAULT 1,' +
    '  CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP' +
    ')'
  );
  
  // Test snapshots table
  FConnection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS TestSnapshots (' +
    '  TestName TEXT PRIMARY KEY,' +
    '  FormClass TEXT,' +
    '  StateJSON TEXT,' +
    '  ScreenshotPath TEXT,' +
    '  CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP' +
    ')'
  );
end;

procedure TIntegrationTestContext.Cleanup;
begin
  if not FInitialized then Exit;
  
  FLock.Enter;
  try
    FSummary.EndTime := Now;
    
    if FEnvironment.Cleanup then
    begin
      CleanupTempFiles;
      
      // Disconnect and cleanup database
      if Assigned(FConnection) then
      begin
        FConnection.Connected := False;
        
        // Delete database file if not in-memory
        if (FEnvironment.DatabasePath <> ':memory:') and
           TFile.Exists(FEnvironment.DatabasePath) then
          TFile.Delete(FEnvironment.DatabasePath);
      end;
    end;
    
    FInitialized := False;
  finally
    FLock.Leave;
  end;
end;

procedure TIntegrationTestContext.CleanupTempFiles;
var
  TempFile: string;
begin
  for TempFile in FTempFiles do
  begin
    try
      if TFile.Exists(TempFile) then
        TFile.Delete(TempFile)
      else if TDirectory.Exists(TempFile) then
        TDirectory.Delete(TempFile, True);
    except
      // Ignore cleanup errors
    end;
  end;
  FTempFiles.Clear;
end;

procedure TIntegrationTestContext.BeginTest(const TestName: string);
begin
  FCurrentTest := TestName;
  FStopwatch := TStopwatch.StartNew;
end;

procedure TIntegrationTestContext.EndTest(Status: TTestResultStatus; const Message: string);
var
  Result: TTestResult;
begin
  FStopwatch.Stop;
  
  Result.TestName := FCurrentTest;
  Result.Status := Status;
  Result.Message := Message;
  Result.Duration := FStopwatch.ElapsedMilliseconds;
  Result.StartTime := Now - (FStopwatch.ElapsedMilliseconds / MSecsPerDay);
  
  RecordResult(Result);
end;

procedure TIntegrationTestContext.RecordResult(const Result: TTestResult);
begin
  FLock.Enter;
  try
    FResults.Add(Result);
    Inc(FSummary.TotalTests);
    FSummary.TotalDuration := FSummary.TotalDuration + Result.Duration;
    
    case Result.Status of
      trsPass: Inc(FSummary.PassCount);
      trsFail: Inc(FSummary.FailCount);
      trsSkip: Inc(FSummary.SkipCount);
      trsError: Inc(FSummary.ErrorCount);
    end;
  finally
    FLock.Leave;
  end;
end;

function TIntegrationTestContext.CreateTempFile(const Extension: string): string;
begin
  Result := TPath.Combine(FEnvironment.TempPath, 
    'test_' + TGUID.NewGuid.ToString + Extension);
  FTempFiles.Add(Result);
end;

function TIntegrationTestContext.CreateTempDir: string;
begin
  Result := TPath.Combine(FEnvironment.TempPath, 
    'testdir_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(Result);
  FTempFiles.Add(Result);
end;

procedure TIntegrationTestContext.ExecuteSQL(const SQL: string);
begin
  FConnection.ExecSQL(SQL);
end;

function TIntegrationTestContext.QuerySQL(const SQL: string): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := FConnection;
  Result.SQL.Text := SQL;
  Result.Open;
end;

function TIntegrationTestContext.GetResults: TTestResults;
begin
  FLock.Enter;
  try
    Result := FResults.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TIntegrationTestContext.GetSummary: TTestSummary;
begin
  FLock.Enter;
  try
    Result := FSummary;
    if Result.EndTime = 0 then
      Result.EndTime := Now;
  finally
    FLock.Leave;
  end;
end;

procedure TIntegrationTestContext.GenerateReport(const Format: string);
var
  ReportFormat: TReportFormat;
begin
  if SameText(Format, 'text') then
    ReportFormat := rfText
  else if SameText(Format, 'html') then
    ReportFormat := rfHTML
  else if SameText(Format, 'json') then
    ReportFormat := rfJSON
  else if SameText(Format, 'xml') then
    ReportFormat := rfXML
  else if SameText(Format, 'junit') then
    ReportFormat := rfJUnit
  else
    ReportFormat := rfHTML;
  
  FReporter.SaveReport(GetResults, GetSummary, ReportFormat);
end;

// ============================================================================
// TTestDataGenerator
// ============================================================================

constructor TTestDataGenerator.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
  FRandomSeed := GetTickCount;
  Randomize;
end;

procedure TTestDataGenerator.SetSeed(Seed: Integer);
begin
  FRandomSeed := Seed;
  RandSeed := Seed;
end;

function TTestDataGenerator.GetRandomString(Length: Integer): string;
const
  Chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
var
  I: Integer;
begin
  SetLength(Result, Length);
  for I := 1 to Length do
    Result[I] := Chars[Random(System.Length(Chars)) + 1];
end;

function TTestDataGenerator.GetRandomInt(Min, Max: Integer): Integer;
begin
  Result := Min + Random(Max - Min + 1);
end;

function TTestDataGenerator.GetRandomDate(const MinDate, MaxDate: TDateTime): TDateTime;
var
  Range: Double;
begin
  Range := MaxDate - MinDate;
  Result := MinDate + Random * Range;
end;

function TTestDataGenerator.GenerateUser: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('username', 'user_' + GetRandomString(8));
  Result.AddPair('email', RandomEmail);
  Result.AddPair('role', 'user');
  Result.AddPair('active', TJSONBool.Create(True));
end;

function TTestDataGenerator.GenerateConfig(Count: Integer): TJSONArray;
var
  I: Integer;
  Item: TJSONObject;
begin
  Result := TJSONArray.Create;
  for I := 1 to Count do
  begin
    Item := TJSONObject.Create;
    Item.AddPair('key', 'config.test.' + GetRandomString(10));
    Item.AddPair('value', GetRandomString(20));
    Item.AddPair('category', 'test');
    Result.Add(Item);
  end;
end;

function TTestDataGenerator.GenerateLogs(Count: Integer): TJSONArray;
const
  Levels: array[0..4] of string = ('DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL');
var
  I: Integer;
  Item: TJSONObject;
begin
  Result := TJSONArray.Create;
  for I := 1 to Count do
  begin
    Item := TJSONObject.Create;
    Item.AddPair('level', Levels[Random(Length(Levels))]);
    Item.AddPair('message', RandomText(5 + Random(10)));
    Item.AddPair('category', 'test');
    Result.Add(Item);
  end;
end;

procedure TTestDataGenerator.InsertUsers(Count: Integer);
var
  Query: TFDQuery;
  I: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'INSERT INTO Users (Username, Email, PasswordHash, Role, Active) ' +
      'VALUES (:Username, :Email, :Hash, :Role, :Active)';
    
    for I := 1 to Count do
    begin
      Query.ParamByName('Username').AsString := 'testuser_' + IntToStr(I);
      Query.ParamByName('Email').AsString := 'test' + IntToStr(I) + '@example.com';
      Query.ParamByName('Hash').AsString := GetRandomString(64);
      Query.ParamByName('Role').AsString := 'user';
      Query.ParamByName('Active').AsInteger := 1;
      Query.ExecSQL;
    end;
  finally
    Query.Free;
  end;
end;

procedure TTestDataGenerator.InsertConfigs(Count: Integer);
var
  Query: TFDQuery;
  I: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'INSERT INTO Config (Key, Value, Category) VALUES (:Key, :Value, :Category)';
    
    for I := 1 to Count do
    begin
      Query.ParamByName('Key').AsString := 'test.config.' + IntToStr(I);
      Query.ParamByName('Value').AsString := GetRandomString(20);
      Query.ParamByName('Category').AsString := 'test';
      Query.ExecSQL;
    end;
  finally
    Query.Free;
  end;
end;

procedure TTestDataGenerator.InsertLogs(Count: Integer);
const
  Levels: array[0..4] of string = ('DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL');
var
  Query: TFDQuery;
  I: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'INSERT INTO Logs (Level, Message, Category) VALUES (:Level, :Msg, :Cat)';
    
    for I := 1 to Count do
    begin
      Query.ParamByName('Level').AsString := Levels[Random(Length(Levels))];
      Query.ParamByName('Msg').AsString := 'Test log message ' + IntToStr(I);
      Query.ParamByName('Cat').AsString := 'test';
      Query.ExecSQL;
    end;
  finally
    Query.Free;
  end;
end;

procedure TTestDataGenerator.ClearAllData;
begin
  FConnection.ExecSQL('DELETE FROM Users WHERE Username LIKE ''testuser_%''');
  FConnection.ExecSQL('DELETE FROM Config WHERE Category = ''test''');
  FConnection.ExecSQL('DELETE FROM Logs WHERE Category = ''test''');
end;

function TTestDataGenerator.RandomEmail: string;
const
  Domains: array[0..3] of string = ('example.com', 'test.org', 'demo.net', 'sample.io');
begin
  Result := GetRandomString(8) + '@' + Domains[Random(Length(Domains))];
end;

function TTestDataGenerator.RandomPhone: string;
begin
  Result := Format('+86-%d-%d', [100 + Random(900), 10000000 + Random(90000000)]);
end;

function TTestDataGenerator.RandomName: string;
const
  FirstNames: array[0..9] of string = (
    'Alice', 'Bob', 'Charlie', 'Diana', 'Eve',
    'Frank', 'Grace', 'Henry', 'Ivy', 'Jack');
  LastNames: array[0..9] of string = (
    'Smith', 'Johnson', 'Williams', 'Brown', 'Jones',
    'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez');
begin
  Result := FirstNames[Random(Length(FirstNames))] + ' ' + 
            LastNames[Random(Length(LastNames))];
end;

function TTestDataGenerator.RandomText(WordCount: Integer): string;
const
  Words: array[0..19] of string = (
    'lorem', 'ipsum', 'dolor', 'sit', 'amet',
    'consectetur', 'adipiscing', 'elit', 'sed', 'do',
    'eiusmod', 'tempor', 'incididunt', 'ut', 'labore',
    'et', 'dolore', 'magna', 'aliqua', 'enim');
var
  I: Integer;
begin
  Result := '';
  for I := 1 to WordCount do
  begin
    if I > 1 then Result := Result + ' ';
    Result := Result + Words[Random(Length(Words))];
  end;
end;

// ============================================================================
// TTestReporter
// ============================================================================

constructor TTestReporter.Create(const AOutputPath: string);
begin
  inherited Create;
  FOutputPath := AOutputPath;
end;

function TTestReporter.StatusToString(Status: TTestResultStatus): string;
begin
  case Status of
    trsPass: Result := 'PASS';
    trsFail: Result := 'FAIL';
    trsSkip: Result := 'SKIP';
    trsError: Result := 'ERROR';
  else
    Result := 'UNKNOWN';
  end;
end;

function TTestReporter.StatusToColor(Status: TTestResultStatus): string;
begin
  case Status of
    trsPass: Result := '#28a745';  // green
    trsFail: Result := '#dc3545';  // red
    trsSkip: Result := '#ffc107';  // yellow
    trsError: Result := '#6f42c1'; // purple
  else
    Result := '#6c757d';  // gray
  end;
end;

function TTestReporter.GenerateTextReport(const Results: TTestResults;
  const Summary: TTestSummary): string;
var
  SB: TStringBuilder;
  R: TTestResult;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('================================================================================');
    SB.AppendLine('                        UNIBASE INTEGRATION TEST REPORT');
    SB.AppendLine('================================================================================');
    SB.AppendLine;
    SB.AppendFormat('Start Time: %s', [FormatDateTime('yyyy-mm-dd hh:nn:ss', Summary.StartTime)]);
    SB.AppendLine;
    SB.AppendFormat('End Time:   %s', [FormatDateTime('yyyy-mm-dd hh:nn:ss', Summary.EndTime)]);
    SB.AppendLine;
    SB.AppendFormat('Duration:   %d ms', [Summary.TotalDuration]);
    SB.AppendLine;
    SB.AppendLine;
    SB.AppendLine('SUMMARY');
    SB.AppendLine('--------');
    SB.AppendFormat('Total:  %d', [Summary.TotalTests]);
    SB.AppendLine;
    SB.AppendFormat('Passed: %d', [Summary.PassCount]);
    SB.AppendLine;
    SB.AppendFormat('Failed: %d', [Summary.FailCount]);
    SB.AppendLine;
    SB.AppendFormat('Skipped: %d', [Summary.SkipCount]);
    SB.AppendLine;
    SB.AppendFormat('Errors: %d', [Summary.ErrorCount]);
    SB.AppendLine;
    SB.AppendFormat('Pass Rate: %.1f%%', [Summary.PassRate]);
    SB.AppendLine;
    SB.AppendLine;
    SB.AppendLine('TEST RESULTS');
    SB.AppendLine('-------------');
    
    for R in Results do
    begin
      SB.AppendFormat('[%s] %s (%d ms)', [StatusToString(R.Status), R.TestName, R.Duration]);
      SB.AppendLine;
      if R.Message <> '' then
      begin
        SB.AppendFormat('       Message: %s', [R.Message]);
        SB.AppendLine;
      end;
    end;
    
    SB.AppendLine;
    SB.AppendLine('================================================================================');
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TTestReporter.GenerateHTMLReport(const Results: TTestResults;
  const Summary: TTestSummary): string;
var
  SB: TStringBuilder;
  R: TTestResult;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('<!DOCTYPE html>');
    SB.AppendLine('<html lang="zh-CN">');
    SB.AppendLine('<head>');
    SB.AppendLine('  <meta charset="UTF-8">');
    SB.AppendLine('  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    SB.AppendLine('  <title>UniBase Integration Test Report</title>');
    SB.AppendLine('  <style>');
    SB.AppendLine('    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }');
    SB.AppendLine('    .container { max-width: 1200px; margin: 0 auto; }');
    SB.AppendLine('    h1 { color: #333; border-bottom: 2px solid #4a90d9; padding-bottom: 10px; }');
    SB.AppendLine('    .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; margin: 20px 0; }');
    SB.AppendLine('    .card { background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); text-align: center; }');
    SB.AppendLine('    .card h3 { margin: 0 0 10px; color: #666; font-size: 14px; }');
    SB.AppendLine('    .card .value { font-size: 32px; font-weight: bold; }');
    SB.AppendLine('    .pass { color: #28a745; }');
    SB.AppendLine('    .fail { color: #dc3545; }');
    SB.AppendLine('    .skip { color: #ffc107; }');
    SB.AppendLine('    .error { color: #6f42c1; }');
    SB.AppendLine('    table { width: 100%; border-collapse: collapse; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-top: 20px; }');
    SB.AppendLine('    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #eee; }');
    SB.AppendLine('    th { background: #4a90d9; color: white; }');
    SB.AppendLine('    tr:hover { background: #f9f9f9; }');
    SB.AppendLine('    .status-badge { padding: 4px 12px; border-radius: 20px; color: white; font-size: 12px; font-weight: bold; }');
    SB.AppendLine('  </style>');
    SB.AppendLine('</head>');
    SB.AppendLine('<body>');
    SB.AppendLine('<div class="container">');
    SB.AppendLine('  <h1>UniBase Integration Test Report</h1>');
    SB.AppendFormat('  <p>Generated: %s</p>', [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)]);
    SB.AppendLine;
    SB.AppendLine('  <div class="summary">');
    SB.AppendFormat('    <div class="card"><h3>Total Tests</h3><div class="value">%d</div></div>', [Summary.TotalTests]);
    SB.AppendLine;
    SB.AppendFormat('    <div class="card"><h3>Passed</h3><div class="value pass">%d</div></div>', [Summary.PassCount]);
    SB.AppendLine;
    SB.AppendFormat('    <div class="card"><h3>Failed</h3><div class="value fail">%d</div></div>', [Summary.FailCount]);
    SB.AppendLine;
    SB.AppendFormat('    <div class="card"><h3>Skipped</h3><div class="value skip">%d</div></div>', [Summary.SkipCount]);
    SB.AppendLine;
    SB.AppendFormat('    <div class="card"><h3>Pass Rate</h3><div class="value">%.1f%%</div></div>', [Summary.PassRate]);
    SB.AppendLine;
    SB.AppendFormat('    <div class="card"><h3>Duration</h3><div class="value">%d ms</div></div>', [Summary.TotalDuration]);
    SB.AppendLine;
    SB.AppendLine('  </div>');
    SB.AppendLine('  <table>');
    SB.AppendLine('    <thead><tr><th>Status</th><th>Test Name</th><th>Duration</th><th>Message</th></tr></thead>');
    SB.AppendLine('    <tbody>');
    
    for R in Results do
    begin
      SB.AppendFormat('      <tr><td><span class="status-badge" style="background:%s">%s</span></td>',
        [StatusToColor(R.Status), StatusToString(R.Status)]);
      SB.AppendFormat('<td>%s</td><td>%d ms</td><td>%s</td></tr>',
        [R.TestName, R.Duration, R.Message]);
      SB.AppendLine;
    end;
    
    SB.AppendLine('    </tbody>');
    SB.AppendLine('  </table>');
    SB.AppendLine('</div>');
    SB.AppendLine('</body>');
    SB.AppendLine('</html>');
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TTestReporter.GenerateJSONReport(const Results: TTestResults;
  const Summary: TTestSummary): string;
var
  JSON, SummaryObj: TJSONObject;
  ResultsArray: TJSONArray;
  R: TTestResult;
  ResultObj: TJSONObject;
begin
  JSON := TJSONObject.Create;
  try
    // Summary
    SummaryObj := TJSONObject.Create;
    SummaryObj.AddPair('totalTests', TJSONNumber.Create(Summary.TotalTests));
    SummaryObj.AddPair('passCount', TJSONNumber.Create(Summary.PassCount));
    SummaryObj.AddPair('failCount', TJSONNumber.Create(Summary.FailCount));
    SummaryObj.AddPair('skipCount', TJSONNumber.Create(Summary.SkipCount));
    SummaryObj.AddPair('errorCount', TJSONNumber.Create(Summary.ErrorCount));
    SummaryObj.AddPair('passRate', TJSONNumber.Create(Summary.PassRate));
    SummaryObj.AddPair('totalDuration', TJSONNumber.Create(Summary.TotalDuration));
    SummaryObj.AddPair('startTime', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Summary.StartTime));
    SummaryObj.AddPair('endTime', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Summary.EndTime));
    JSON.AddPair('summary', SummaryObj);
    
    // Results
    ResultsArray := TJSONArray.Create;
    for R in Results do
    begin
      ResultObj := TJSONObject.Create;
      ResultObj.AddPair('testName', R.TestName);
      ResultObj.AddPair('status', StatusToString(R.Status));
      ResultObj.AddPair('duration', TJSONNumber.Create(R.Duration));
      ResultObj.AddPair('message', R.Message);
      ResultObj.AddPair('stackTrace', R.StackTrace);
      ResultsArray.Add(ResultObj);
    end;
    JSON.AddPair('results', ResultsArray);
    
    Result := JSON.Format(2);
  finally
    JSON.Free;
  end;
end;

function TTestReporter.GenerateXMLReport(const Results: TTestResults;
  const Summary: TTestSummary): string;
var
  SB: TStringBuilder;
  R: TTestResult;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('<?xml version="1.0" encoding="UTF-8"?>');
    SB.AppendFormat('<testReport generated="%s">', [FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now)]);
    SB.AppendLine;
    SB.AppendFormat('  <summary totalTests="%d" passCount="%d" failCount="%d" skipCount="%d" errorCount="%d" passRate="%.1f" duration="%d"/>',
      [Summary.TotalTests, Summary.PassCount, Summary.FailCount, Summary.SkipCount, Summary.ErrorCount, Summary.PassRate, Summary.TotalDuration]);
    SB.AppendLine;
    SB.AppendLine('  <results>');
    
    for R in Results do
    begin
      SB.AppendFormat('    <test name="%s" status="%s" duration="%d">',
        [R.TestName, StatusToString(R.Status), R.Duration]);
      if R.Message <> '' then
        SB.AppendFormat('<message>%s</message>', [R.Message]);
      SB.AppendLine('</test>');
    end;
    
    SB.AppendLine('  </results>');
    SB.AppendLine('</testReport>');
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TTestReporter.GenerateJUnitReport(const Results: TTestResults;
  const Summary: TTestSummary): string;
var
  SB: TStringBuilder;
  R: TTestResult;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('<?xml version="1.0" encoding="UTF-8"?>');
    SB.AppendFormat('<testsuite name="UniBase.IntegrationTests" tests="%d" failures="%d" errors="%d" skipped="%d" time="%.3f">',
      [Summary.TotalTests, Summary.FailCount, Summary.ErrorCount, Summary.SkipCount, Summary.TotalDuration / 1000]);
    SB.AppendLine;
    
    for R in Results do
    begin
      SB.AppendFormat('  <testcase name="%s" classname="IntegrationTests" time="%.3f">',
        [R.TestName, R.Duration / 1000]);
      SB.AppendLine;
      
      case R.Status of
        trsFail:
          SB.AppendFormat('    <failure message="%s"/>', [R.Message]);
        trsError:
          SB.AppendFormat('    <error message="%s"><![CDATA[%s]]></error>', [R.Message, R.StackTrace]);
        trsSkip:
          SB.AppendFormat('    <skipped message="%s"/>', [R.Message]);
      end;
      
      if R.Status <> trsPass then
        SB.AppendLine;
      
      SB.AppendLine('  </testcase>');
    end;
    
    SB.AppendLine('</testsuite>');
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TTestReporter.Generate(const Results: TTestResults; const Summary: TTestSummary;
  Format: TReportFormat): string;
begin
  case Format of
    rfText: Result := GenerateTextReport(Results, Summary);
    rfHTML: Result := GenerateHTMLReport(Results, Summary);
    rfJSON: Result := GenerateJSONReport(Results, Summary);
    rfXML: Result := GenerateXMLReport(Results, Summary);
    rfJUnit: Result := GenerateJUnitReport(Results, Summary);
  else
    Result := GenerateTextReport(Results, Summary);
  end;
end;

procedure TTestReporter.SaveReport(const Results: TTestResults; const Summary: TTestSummary;
  Format: TReportFormat; const FileName: string);
var
  ReportContent, OutputFile, Ext: string;
begin
  ReportContent := Generate(Results, Summary, Format);
  
  case Format of
    rfText: Ext := '.txt';
    rfHTML: Ext := '.html';
    rfJSON: Ext := '.json';
    rfXML: Ext := '.xml';
    rfJUnit: Ext := '_junit.xml';
  else
    Ext := '.txt';
  end;
  
  if FileName <> '' then
    OutputFile := FileName
  else
    OutputFile := TPath.Combine(FOutputPath, 
      'TestReport_' + FormatDateTime('yyyymmdd_hhnnss', Now) + Ext);
  
  TFile.WriteAllText(OutputFile, ReportContent, TEncoding.UTF8);
end;

procedure TTestReporter.PrintSummary(const Summary: TTestSummary);
begin
  WriteLn('');
  WriteLn('========================================');
  WriteLn('           TEST SUMMARY');
  WriteLn('========================================');
  WriteLn(Format('Total:    %d', [Summary.TotalTests]));
  WriteLn(Format('Passed:   %d', [Summary.PassCount]));
  WriteLn(Format('Failed:   %d', [Summary.FailCount]));
  WriteLn(Format('Skipped:  %d', [Summary.SkipCount]));
  WriteLn(Format('Errors:   %d', [Summary.ErrorCount]));
  WriteLn(Format('Pass Rate: %.1f%%', [Summary.PassRate]));
  WriteLn(Format('Duration: %d ms', [Summary.TotalDuration]));
  WriteLn('========================================');
  WriteLn('');
end;

// ============================================================================
// TBenchmarkResult
// ============================================================================

function TBenchmarkResult.ToString: string;
begin
  Result := Format('%s: %d iterations, avg %.2f ms, min %d ms, max %d ms, %.0f ops/sec',
    [Name, Iterations, AvgTime, MinTime, MaxTime, OpsPerSecond]);
end;

// ============================================================================
// TPerformanceBenchmark
// ============================================================================

constructor TPerformanceBenchmark.Create;
begin
  inherited Create;
  FResults := TList<TBenchmarkResult>.Create;
  FBaselines := TDictionary<string, Double>.Create;
  FWarmupIterations := 3;
end;

destructor TPerformanceBenchmark.Destroy;
begin
  FBaselines.Free;
  FResults.Free;
  inherited;
end;

function TPerformanceBenchmark.CalculateStats(const Times: TArray<Int64>): TBenchmarkResult;
var
  I, N: Integer;
  Sum, SumSq, Mean: Double;
  Sorted: TArray<Int64>;
begin
  N := Length(Times);
  if N = 0 then Exit;
  
  // Calculate basic stats
  Result.MinTime := Times[0];
  Result.MaxTime := Times[0];
  Sum := 0;
  
  for I := 0 to N - 1 do
  begin
    Sum := Sum + Times[I];
    if Times[I] < Result.MinTime then Result.MinTime := Times[I];
    if Times[I] > Result.MaxTime then Result.MaxTime := Times[I];
  end;
  
  Result.TotalTime := Round(Sum);
  Result.AvgTime := Sum / N;
  Result.Iterations := N;
  
  // Ops per second
  if Result.AvgTime > 0 then
    Result.OpsPerSecond := 1000 / Result.AvgTime
  else
    Result.OpsPerSecond := 0;
  
  // Standard deviation
  Mean := Result.AvgTime;
  SumSq := 0;
  for I := 0 to N - 1 do
    SumSq := SumSq + Sqr(Times[I] - Mean);
  Result.StdDev := Sqrt(SumSq / N);
  
  // Median
  Sorted := Copy(Times);
  TArray.Sort<Int64>(Sorted);
  if N mod 2 = 0 then
    Result.MedianTime := (Sorted[N div 2 - 1] + Sorted[N div 2]) div 2
  else
    Result.MedianTime := Sorted[N div 2];
end;

function TPerformanceBenchmark.Run(const Name: string; Iterations: Integer;
  const Action: TProc): TBenchmarkResult;
var
  Times: TArray<Int64>;
  SW: TStopwatch;
  I: Integer;
begin
  SetLength(Times, Iterations);
  
  // Warmup
  for I := 1 to FWarmupIterations do
    Action();
  
  // Actual benchmark
  for I := 0 to Iterations - 1 do
  begin
    SW := TStopwatch.StartNew;
    Action();
    SW.Stop;
    Times[I] := SW.ElapsedMilliseconds;
  end;
  
  Result := CalculateStats(Times);
  Result.Name := Name;
  FResults.Add(Result);
end;

function TPerformanceBenchmark.RunWithSetup(const Name: string; Iterations: Integer;
  const Setup, Action, Teardown: TProc): TBenchmarkResult;
var
  Times: TArray<Int64>;
  SW: TStopwatch;
  I: Integer;
begin
  SetLength(Times, Iterations);
  
  // Warmup
  for I := 1 to FWarmupIterations do
  begin
    if Assigned(Setup) then Setup();
    Action();
    if Assigned(Teardown) then Teardown();
  end;
  
  // Actual benchmark
  for I := 0 to Iterations - 1 do
  begin
    if Assigned(Setup) then Setup();
    
    SW := TStopwatch.StartNew;
    Action();
    SW.Stop;
    
    Times[I] := SW.ElapsedMilliseconds;
    
    if Assigned(Teardown) then Teardown();
  end;
  
  Result := CalculateStats(Times);
  Result.Name := Name;
  FResults.Add(Result);
end;

function TPerformanceBenchmark.CompareWithBaseline(const Name: string;
  const ABenchmark: TBenchmarkResult): Double;
var
  Baseline: Double;
begin
  if FBaselines.TryGetValue(Name, Baseline) and (Baseline > 0) then
    Result := ((ABenchmark.OpsPerSecond - Baseline) / Baseline) * 100
  else
    Result := 0;
end;

procedure TPerformanceBenchmark.SetBaseline(const Name: string; OpsPerSecond: Double);
begin
  FBaselines.AddOrSetValue(Name, OpsPerSecond);
end;

procedure TPerformanceBenchmark.LoadBaselines(const FileName: string);
var
  JSON: TJSONObject;
  Pair: TJSONPair;
begin
  if not TFile.Exists(FileName) then Exit;
  
  try
    JSON := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName)) as TJSONObject;
    if JSON = nil then Exit;
    
    try
      for Pair in JSON do
        FBaselines.AddOrSetValue(Pair.JsonString.Value, 
          (Pair.JsonValue as TJSONNumber).AsDouble);
    finally
      JSON.Free;
    end;
  except
    // Ignore parse errors
  end;
end;

procedure TPerformanceBenchmark.SaveBaselines(const FileName: string);
var
  JSON: TJSONObject;
  Name: string;
begin
  JSON := TJSONObject.Create;
  try
    for Name in FBaselines.Keys do
      JSON.AddPair(Name, TJSONNumber.Create(FBaselines[Name]));
    
    TFile.WriteAllText(FileName, JSON.Format(2), TEncoding.UTF8);
  finally
    JSON.Free;
  end;
end;

function TPerformanceBenchmark.GetResults: TBenchmarkResults;
begin
  Result := FResults.ToArray;
end;

procedure TPerformanceBenchmark.ClearResults;
begin
  FResults.Clear;
end;

function TPerformanceBenchmark.GenerateReport: string;
var
  SB: TStringBuilder;
  R: TBenchmarkResult;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('PERFORMANCE BENCHMARK REPORT');
    SB.AppendLine('============================');
    SB.AppendLine;
    
    for R in FResults do
    begin
      SB.AppendLine(R.ToString);
    end;
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

// ============================================================================
// TIntegrationAssert
// ============================================================================

class procedure TIntegrationAssert.TableExists(Connection: TFDConnection;
  const TableName: string; const Message: string);
var
  Query: TFDQuery;
  Exists: Boolean;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text := 
      'SELECT COUNT(*) FROM sqlite_master WHERE type=''table'' AND name=:Name';
    Query.ParamByName('Name').AsString := TableName;
    Query.Open;
    Exists := Query.Fields[0].AsInteger > 0;
  finally
    Query.Free;
  end;
  
  if not Exists then
  begin
    if Message <> '' then
      Assert.Fail(Message)
    else
      Assert.Fail(Format('Table "%s" does not exist', [TableName]));
  end;
end;

class procedure TIntegrationAssert.RowCount(Connection: TFDConnection;
  const TableName: string; Expected: Integer; const Message: string);
var
  Query: TFDQuery;
  Actual: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text := 'SELECT COUNT(*) FROM ' + TableName;
    Query.Open;
    Actual := Query.Fields[0].AsInteger;
  finally
    Query.Free;
  end;
  
  if Actual <> Expected then
  begin
    if Message <> '' then
      Assert.Fail(Message)
    else
      Assert.Fail(Format('Table "%s" row count: expected %d, actual %d', 
        [TableName, Expected, Actual]));
  end;
end;

class procedure TIntegrationAssert.RowExists(Connection: TFDConnection;
  const TableName, Where: string; const Message: string);
var
  Query: TFDQuery;
  Exists: Boolean;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text := 'SELECT COUNT(*) FROM ' + TableName + ' WHERE ' + Where;
    Query.Open;
    Exists := Query.Fields[0].AsInteger > 0;
  finally
    Query.Free;
  end;
  
  if not Exists then
  begin
    if Message <> '' then
      Assert.Fail(Message)
    else
      Assert.Fail(Format('No row found in "%s" where %s', [TableName, Where]));
  end;
end;

class procedure TIntegrationAssert.QueryCount(Connection: TFDConnection;
  const SQL: string; Expected: Integer; const Message: string);
var
  Query: TFDQuery;
  Actual: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text := SQL;
    Query.Open;
    Actual := Query.RecordCount;
  finally
    Query.Free;
  end;
  
  if Actual <> Expected then
  begin
    if Message <> '' then
      Assert.Fail(Message)
    else
      Assert.Fail(Format('Query returned %d rows, expected %d', [Actual, Expected]));
  end;
end;

class procedure TIntegrationAssert.FileExists(const FileName: string;
  const Message: string);
begin
  if not TFile.Exists(FileName) then
  begin
    if Message <> '' then
      Assert.Fail(Message)
    else
      Assert.Fail(Format('File not found: %s', [FileName]));
  end;
end;

class procedure TIntegrationAssert.FileContains(const FileName, Text: string;
  const Message: string);
var
  Content: string;
begin
  if not TFile.Exists(FileName) then
    Assert.Fail(Format('File not found: %s', [FileName]));
  
  Content := TFile.ReadAllText(FileName);
  if not Content.Contains(Text) then
  begin
    if Message <> '' then
      Assert.Fail(Message)
    else
      Assert.Fail(Format('File does not contain expected text: %s', [Text]));
  end;
end;

class procedure TIntegrationAssert.JSONHasKey(const JSON: TJSONObject;
  const Key: string; const Message: string);
begin
  if JSON.GetValue(Key) = nil then
  begin
    if Message <> '' then
      Assert.Fail(Message)
    else
      Assert.Fail(Format('JSON missing key: %s', [Key]));
  end;
end;

class procedure TIntegrationAssert.JSONEquals(const JSON: TJSONObject;
  const Key, Expected: string; const Message: string);
var
  Value: TJSONValue;
begin
  Value := JSON.GetValue(Key);
  if Value = nil then
    Assert.Fail(Format('JSON missing key: %s', [Key]));
  
  if Value.Value <> Expected then
  begin
    if Message <> '' then
      Assert.Fail(Message)
    else
      Assert.Fail(Format('JSON[%s]: expected "%s", actual "%s"', 
        [Key, Expected, Value.Value]));
  end;
end;

class procedure TIntegrationAssert.ExecutesWithin(const Action: TProc;
  MaxMilliseconds: Int64; const Message: string);
var
  SW: TStopwatch;
begin
  SW := TStopwatch.StartNew;
  Action();
  SW.Stop;
  
  if SW.ElapsedMilliseconds > MaxMilliseconds then
  begin
    if Message <> '' then
      Assert.Fail(Message)
    else
      Assert.Fail(Format('Execution took %d ms, expected max %d ms',
        [SW.ElapsedMilliseconds, MaxMilliseconds]));
  end;
end;

class procedure TIntegrationAssert.NoMemoryLeak(const Action: TProc;
  ToleranceBytes: Int64; const Message: string);
var
  MemBefore, MemAfter: Int64;
  PMC: PROCESS_MEMORY_COUNTERS;
begin
  PMC.cb := SizeOf(PMC);
  GetProcessMemoryInfo(GetCurrentProcess, @PMC, SizeOf(PMC));
  MemBefore := PMC.WorkingSetSize;
  
  Action();
  
  GetProcessMemoryInfo(GetCurrentProcess, @PMC, SizeOf(PMC));
  MemAfter := PMC.WorkingSetSize;
  
  if (MemAfter - MemBefore) > ToleranceBytes then
  begin
    if Message <> '' then
      Assert.Fail(Message)
    else
      Assert.Fail(Format('Potential memory leak detected: %d bytes',
        [MemAfter - MemBefore]));
  end;
end;

class procedure TIntegrationAssert.RaisesException<T>(const Action: TProc;
  const Message: string);
var
  Raised: Boolean;
begin
  Raised := False;
  try
    Action();
  except
    on E: Exception do
      Raised := E is T;
  end;
  
  if not Raised then
  begin
    if Message <> '' then
      Assert.Fail(Message)
    else
      Assert.Fail(Format('Expected exception %s was not raised', [T.ClassName]));
  end;
end;

class procedure TIntegrationAssert.RaisesExceptionWithMessage(const Action: TProc;
  const ExpectedMessage: string; const Message: string);
var
  ActualMessage: string;
begin
  ActualMessage := '';
  try
    Action();
  except
    on E: Exception do
      ActualMessage := E.Message;
  end;
  
  if ActualMessage = '' then
    Assert.Fail('Expected exception was not raised');
  
  if not ActualMessage.Contains(ExpectedMessage) then
  begin
    if Message <> '' then
      Assert.Fail(Message)
    else
      Assert.Fail(Format('Exception message mismatch: expected "%s", actual "%s"',
        [ExpectedMessage, ActualMessage]));
  end;
end;

// ============================================================================
// TIntegrationTestBase
// ============================================================================

class function TIntegrationTestBase.GetSharedContext: TIntegrationTestContext;
begin
  if FSharedContext = nil then
  begin
    FSharedContext := TIntegrationTestContext.Create(TTestEnvironment.Default);
    FSharedContext.Initialize;
  end;
  Result := FSharedContext;
end;

class destructor TIntegrationTestBase.Destroy;
begin
  FreeAndNil(FSharedContext);
end;

procedure TIntegrationTestBase.SetupFixture;
begin
  FContext := GetSharedContext;
end;

procedure TIntegrationTestBase.TearDownFixture;
begin
  // Context is shared, don't cleanup here
end;

procedure TIntegrationTestBase.Setup;
begin
  InitializeTestData;
end;

procedure TIntegrationTestBase.TearDown;
begin
  CleanupTestData;
end;

procedure TIntegrationTestBase.InitializeTestData;
begin
  // Override in subclasses
end;

procedure TIntegrationTestBase.CleanupTestData;
begin
  // Override in subclasses
end;

// ============================================================================
// Global Functions
// ============================================================================

function CreateTestContext: TIntegrationTestContext;
begin
  Result := TIntegrationTestContext.Create(TTestEnvironment.Default);
  Result.Initialize;
end;

function CreateCITestContext: TIntegrationTestContext;
begin
  Result := TIntegrationTestContext.Create(TTestEnvironment.CI);
  Result.Initialize;
end;

function RunIntegrationTests(const OutputPath: string): Boolean;
var
  Runner: ITestRunner;
  Results: IRunResults;
begin
  Runner := TDUnitX.CreateRunner;
  Runner.UseRTTI := True;
  
  Results := Runner.Execute;
  Result := Results.AllPassed;
end;

end.
