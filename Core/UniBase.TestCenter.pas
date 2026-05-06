{ ============================================================================
  UniBase.TestCenter - Developer Test Center Core Logic
  
  Version: 1.0
  Description:
    Provides a unified test center for developers to organize and run
    manual tests during development. Supports categorization, test registration,
    execution tracking, and integration with external tools like UniPublisher.
    
    Features:
    - Test item registration with categories
    - Manual test execution tracking
    - Test result logging
    - Integration with UniPublisher
  ============================================================================ }

unit UniBase.TestCenter;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.IOUtils;

type
  /// <summary>Status of a test item.</summary>
  TTestStatus = (tsNotRun, tsRunning, tsPassed, tsFailed, tsSkipped);

  /// <summary>Category for organizing tests.</summary>
  TTestCategory = record
    Id: string;
    Name: string;
    Description: string;
    IconIndex: Integer;
    
    class function Create(const AId, AName: string; AIconIndex: Integer = -1): TTestCategory; static;
  end;

  /// <summary>A single test item.</summary>
  TTestItem = class
  private
    FId: string;
    FName: string;
    FDescription: string;
    FCategoryId: string;
    FStatus: TTestStatus;
    FLastRunTime: TDateTime;
    FLastResult: string;
    FExecuteProc: TProc;
    FExecuteProcStr: TProc<string>;
    FTag: NativeInt;
  public
    constructor Create(const AId, AName, ACategoryId: string);
    
    procedure Execute;
    procedure ExecuteWithParam(const Param: string);
    procedure MarkPassed(const ResultMsg: string = '');
    procedure MarkFailed(const ErrorMsg: string);
    procedure Reset;
    
    function StatusText: string;
    function ToJSON: TJSONObject;
    
    property Id: string read FId;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property CategoryId: string read FCategoryId write FCategoryId;
    property Status: TTestStatus read FStatus write FStatus;
    property LastRunTime: TDateTime read FLastRunTime write FLastRunTime;
    property LastResult: string read FLastResult write FLastResult;
    property ExecuteProc: TProc read FExecuteProc write FExecuteProc;
    property ExecuteProcStr: TProc<string> read FExecuteProcStr write FExecuteProcStr;
    property Tag: NativeInt read FTag write FTag;
  end;

  /// <summary>Test runner interface for custom test execution.</summary>
  ITestRunner = interface
    ['{8A7D3B5C-2E1F-4A9D-B8C6-7F5E4D3C2B1A}']
    function RunTest(ATest: TTestItem): Boolean;
    procedure BeforeRun(ATest: TTestItem);
    procedure AfterRun(ATest: TTestItem; Success: Boolean);
  end;

  /// <summary>Event for test status changes.</summary>
  TTestStatusChangeEvent = procedure(Sender: TObject; ATest: TTestItem) of object;
  
  /// <summary>Event for log messages.</summary>
  TTestLogEvent = procedure(Sender: TObject; const Msg: string) of object;

  /// <summary>Manages test categories and items.</summary>
  TTestCenterManager = class
  private
    FCategories: TList<TTestCategory>;
    FTests: TObjectList<TTestItem>;
    FRunner: ITestRunner;
    FOnStatusChange: TTestStatusChangeEvent;
    FOnLog: TTestLogEvent;
    
    procedure DoLog(const Msg: string);
    procedure DoStatusChange(ATest: TTestItem);
  public
    constructor Create;
    destructor Destroy; override;
    
    // Category management
    procedure AddCategory(const ACategory: TTestCategory);
    procedure AddCategorySimple(const AId, AName: string; AIconIndex: Integer = -1);
    function GetCategory(const ACategoryId: string): TTestCategory;
    function GetCategories: TArray<TTestCategory>;
    procedure ClearCategories;
    
    // Test management
    function RegisterTest(const AId, AName, ACategoryId: string): TTestItem;
    function RegisterTestWithProc(const AId, AName, ACategoryId: string; 
      AProc: TProc): TTestItem;
    function GetTest(const AId: string): TTestItem;
    function GetTestsByCategory(const ACategoryId: string): TArray<TTestItem>;
    function GetAllTests: TArray<TTestItem>;
    procedure RemoveTest(const AId: string);
    procedure ClearTests;
    
    // Execution
    function RunTest(const ATestId: string): Boolean;
    function RunTestsInCategory(const ACategoryId: string): Integer;
    function RunAllTests: Integer;
    procedure ResetAllTests;
    
    // Statistics
    function GetPassedCount: Integer;
    function GetFailedCount: Integer;
    function GetNotRunCount: Integer;
    function GetTotalCount: Integer;
    function GetSummary: string;
    
    // Persistence
    procedure SaveResultsToFile(const APath: string);
    procedure LoadResultsFromFile(const APath: string);
    
    property Runner: ITestRunner read FRunner write FRunner;
    property OnStatusChange: TTestStatusChangeEvent read FOnStatusChange write FOnStatusChange;
    property OnLog: TTestLogEvent read FOnLog write FOnLog;
  end;

  /// <summary>Default test runner implementation.</summary>
  TDefaultTestRunner = class(TInterfacedObject, ITestRunner)
  private
    FOnLog: TProc<string>;
  public
    function RunTest(ATest: TTestItem): Boolean;
    procedure BeforeRun(ATest: TTestItem);
    procedure AfterRun(ATest: TTestItem; Success: Boolean);
    
    property OnLog: TProc<string> read FOnLog write FOnLog;
  end;

  /// <summary>Standard test categories for UniBase development.</summary>
  TStandardCategories = class
  public
    const CAT_CORE = 'core';
    const CAT_VCL = 'vcl';
    const CAT_FMX = 'fmx';
    const CAT_NETWORK = 'network';
    const CAT_DATABASE = 'database';
    const CAT_AUTOUPDATE = 'autoupdate';
    const CAT_PUBLISHER = 'publisher';
    const CAT_TOOLS = 'tools';
    
    class procedure RegisterAll(AManager: TTestCenterManager); static;
  end;

implementation

{ TTestCategory }

class function TTestCategory.Create(const AId, AName: string; 
  AIconIndex: Integer): TTestCategory;
begin
  Result.Id := AId;
  Result.Name := AName;
  Result.Description := '';
  Result.IconIndex := AIconIndex;
end;

{ TTestItem }

constructor TTestItem.Create(const AId, AName, ACategoryId: string);
begin
  inherited Create;
  FId := AId;
  FName := AName;
  FCategoryId := ACategoryId;
  FStatus := tsNotRun;
  FLastRunTime := 0;
  FLastResult := '';
  FTag := 0;
end;

procedure TTestItem.Execute;
begin
  FStatus := tsRunning;
  FLastRunTime := Now;
  try
    if Assigned(FExecuteProc) then
      FExecuteProc;
  except
    on E: Exception do
    begin
      MarkFailed(E.Message);
      raise;
    end;
  end;
end;

procedure TTestItem.ExecuteWithParam(const Param: string);
begin
  FStatus := tsRunning;
  FLastRunTime := Now;
  try
    if Assigned(FExecuteProcStr) then
      FExecuteProcStr(Param)
    else if Assigned(FExecuteProc) then
      FExecuteProc;
  except
    on E: Exception do
    begin
      MarkFailed(E.Message);
      raise;
    end;
  end;
end;

procedure TTestItem.MarkPassed(const ResultMsg: string);
begin
  FStatus := tsPassed;
  FLastResult := ResultMsg;
  if FLastResult = '' then
    FLastResult := '测试通过';
end;

procedure TTestItem.MarkFailed(const ErrorMsg: string);
begin
  FStatus := tsFailed;
  FLastResult := ErrorMsg;
end;

procedure TTestItem.Reset;
begin
  FStatus := tsNotRun;
  FLastRunTime := 0;
  FLastResult := '';
end;

function TTestItem.StatusText: string;
begin
  case FStatus of
    tsNotRun:  Result := '未运行';
    tsRunning: Result := '运行中';
    tsPassed:  Result := '通过';
    tsFailed:  Result := '失败';
    tsSkipped: Result := '跳过';
  else
    Result := '未知';
  end;
end;

function TTestItem.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', FId);
  Result.AddPair('name', FName);
  Result.AddPair('categoryId', FCategoryId);
  Result.AddPair('status', Ord(FStatus));
  Result.AddPair('lastRunTime', DateTimeToStr(FLastRunTime));
  Result.AddPair('lastResult', FLastResult);
end;

{ TTestCenterManager }

constructor TTestCenterManager.Create;
begin
  inherited Create;
  FCategories := TList<TTestCategory>.Create;
  FTests := TObjectList<TTestItem>.Create(True);
end;

destructor TTestCenterManager.Destroy;
begin
  FreeAndNil(FTests);
  FreeAndNil(FCategories);
  inherited;
end;

procedure TTestCenterManager.DoLog(const Msg: string);
begin
  if Assigned(FOnLog) then
    FOnLog(Self, Msg);
end;

procedure TTestCenterManager.DoStatusChange(ATest: TTestItem);
begin
  if Assigned(FOnStatusChange) then
    FOnStatusChange(Self, ATest);
end;

procedure TTestCenterManager.AddCategory(const ACategory: TTestCategory);
begin
  FCategories.Add(ACategory);
end;

procedure TTestCenterManager.AddCategorySimple(const AId, AName: string; 
  AIconIndex: Integer);
begin
  AddCategory(TTestCategory.Create(AId, AName, AIconIndex));
end;

function TTestCenterManager.GetCategory(const ACategoryId: string): TTestCategory;
var
  Cat: TTestCategory;
begin
  Result.Id := '';
  Result.Name := '';
  for Cat in FCategories do
    if SameText(Cat.Id, ACategoryId) then
      Exit(Cat);
end;

function TTestCenterManager.GetCategories: TArray<TTestCategory>;
begin
  Result := FCategories.ToArray;
end;

procedure TTestCenterManager.ClearCategories;
begin
  FCategories.Clear;
end;

function TTestCenterManager.RegisterTest(const AId, AName, 
  ACategoryId: string): TTestItem;
begin
  Result := TTestItem.Create(AId, AName, ACategoryId);
  FTests.Add(Result);
end;

function TTestCenterManager.RegisterTestWithProc(const AId, AName, 
  ACategoryId: string; AProc: TProc): TTestItem;
begin
  Result := RegisterTest(AId, AName, ACategoryId);
  Result.ExecuteProc := AProc;
end;

function TTestCenterManager.GetTest(const AId: string): TTestItem;
var
  Test: TTestItem;
begin
  Result := nil;
  for Test in FTests do
    if SameText(Test.Id, AId) then
      Exit(Test);
end;

function TTestCenterManager.GetTestsByCategory(
  const ACategoryId: string): TArray<TTestItem>;
var
  Test: TTestItem;
  List: TList<TTestItem>;
begin
  List := TList<TTestItem>.Create;
  try
    for Test in FTests do
      if SameText(Test.CategoryId, ACategoryId) then
        List.Add(Test);
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TTestCenterManager.GetAllTests: TArray<TTestItem>;
begin
  Result := FTests.ToArray;
end;

procedure TTestCenterManager.RemoveTest(const AId: string);
var
  I: Integer;
begin
  for I := FTests.Count - 1 downto 0 do
    if SameText(FTests[I].Id, AId) then
    begin
      FTests.Delete(I);
      Break;
    end;
end;

procedure TTestCenterManager.ClearTests;
begin
  FTests.Clear;
end;

function TTestCenterManager.RunTest(const ATestId: string): Boolean;
var
  Test: TTestItem;
begin
  Result := False;
  Test := GetTest(ATestId);
  if Test = nil then
    Exit;
  
  DoLog('运行测试: ' + Test.Name);
  
  if Assigned(FRunner) then
  begin
    FRunner.BeforeRun(Test);
    try
      Result := FRunner.RunTest(Test);
    finally
      FRunner.AfterRun(Test, Result);
    end;
  end
  else
  begin
    // Default execution
    try
      Test.Execute;
      if Test.Status = tsRunning then
        Test.MarkPassed;
      Result := Test.Status = tsPassed;
    except
      on E: Exception do
      begin
        Test.MarkFailed(E.Message);
        Result := False;
      end;
    end;
  end;
  
  DoStatusChange(Test);
  DoLog(Format('测试 %s: %s', [Test.Name, Test.StatusText]));
end;

function TTestCenterManager.RunTestsInCategory(
  const ACategoryId: string): Integer;
var
  Tests: TArray<TTestItem>;
  Test: TTestItem;
begin
  Result := 0;
  Tests := GetTestsByCategory(ACategoryId);
  
  DoLog('运行分类 [' + ACategoryId + '] 中的所有测试...');
  
  for Test in Tests do
    if RunTest(Test.Id) then
      Inc(Result);
      
  DoLog(Format('分类测试完成: %d/%d 通过', [Result, Length(Tests)]));
end;

function TTestCenterManager.RunAllTests: Integer;
var
  Test: TTestItem;
begin
  Result := 0;
  
  DoLog('运行所有测试...');
  
  for Test in FTests do
    if RunTest(Test.Id) then
      Inc(Result);
      
  DoLog(GetSummary);
end;

procedure TTestCenterManager.ResetAllTests;
var
  Test: TTestItem;
begin
  for Test in FTests do
  begin
    Test.Reset;
    DoStatusChange(Test);
  end;
  DoLog('已重置所有测试');
end;

function TTestCenterManager.GetPassedCount: Integer;
var
  Test: TTestItem;
begin
  Result := 0;
  for Test in FTests do
    if Test.Status = tsPassed then
      Inc(Result);
end;

function TTestCenterManager.GetFailedCount: Integer;
var
  Test: TTestItem;
begin
  Result := 0;
  for Test in FTests do
    if Test.Status = tsFailed then
      Inc(Result);
end;

function TTestCenterManager.GetNotRunCount: Integer;
var
  Test: TTestItem;
begin
  Result := 0;
  for Test in FTests do
    if Test.Status = tsNotRun then
      Inc(Result);
end;

function TTestCenterManager.GetTotalCount: Integer;
begin
  Result := FTests.Count;
end;

function TTestCenterManager.GetSummary: string;
begin
  Result := Format('测试结果: 通过 %d, 失败 %d, 未运行 %d, 总计 %d',
    [GetPassedCount, GetFailedCount, GetNotRunCount, GetTotalCount]);
end;

procedure TTestCenterManager.SaveResultsToFile(const APath: string);
var
  Root, TestsArray: TJSONArray;
  Test: TTestItem;
  JsonText: string;
begin
  Root := TJSONArray.Create;
  try
    for Test in FTests do
      Root.AddElement(Test.ToJSON);
      
    JsonText := Root.Format(2);
    ForceDirectories(ExtractFilePath(APath));
    TFile.WriteAllText(APath, JsonText, TEncoding.UTF8);
    
    DoLog('测试结果已保存: ' + APath);
  finally
    Root.Free;
  end;
end;

procedure TTestCenterManager.LoadResultsFromFile(const APath: string);
var
  JsonText: string;
  Root: TJSONArray;
  Item: TJSONValue;
  Obj: TJSONObject;
  Test: TTestItem;
  TestId: string;
begin
  if not TFile.Exists(APath) then
    Exit;
    
  JsonText := TFile.ReadAllText(APath, TEncoding.UTF8);
  Root := TJSONObject.ParseJSONValue(JsonText) as TJSONArray;
  if Root = nil then
    Exit;
    
  try
    for Item in Root do
    begin
      Obj := Item as TJSONObject;
      TestId := Obj.GetValue<string>('id', '');
      Test := GetTest(TestId);
      if Test <> nil then
      begin
        Test.Status := TTestStatus(Obj.GetValue<Integer>('status', 0));
        Test.LastResult := Obj.GetValue<string>('lastResult', '');
        DoStatusChange(Test);
      end;
    end;
    
    DoLog('测试结果已加载: ' + APath);
  finally
    Root.Free;
  end;
end;

{ TDefaultTestRunner }

function TDefaultTestRunner.RunTest(ATest: TTestItem): Boolean;
begin
  Result := False;
  try
    ATest.Execute;
    if ATest.Status = tsRunning then
      ATest.MarkPassed;
    Result := ATest.Status = tsPassed;
  except
    on E: Exception do
    begin
      ATest.MarkFailed(E.Message);
      if Assigned(FOnLog) then
        FOnLog('测试异常: ' + E.Message);
    end;
  end;
end;

procedure TDefaultTestRunner.BeforeRun(ATest: TTestItem);
begin
  ATest.Status := tsRunning;
  ATest.LastRunTime := Now;
  if Assigned(FOnLog) then
    FOnLog('开始测试: ' + ATest.Name);
end;

procedure TDefaultTestRunner.AfterRun(ATest: TTestItem; Success: Boolean);
begin
  if Assigned(FOnLog) then
    FOnLog(Format('测试完成 [%s]: %s', [ATest.Name, ATest.StatusText]));
end;

{ TStandardCategories }

class procedure TStandardCategories.RegisterAll(AManager: TTestCenterManager);
begin
  AManager.AddCategorySimple(CAT_CORE, '核心功能', 0);
  AManager.AddCategorySimple(CAT_VCL, 'VCL 组件', 1);
  AManager.AddCategorySimple(CAT_FMX, 'FMX 组件', 2);
  AManager.AddCategorySimple(CAT_NETWORK, '网络功能', 3);
  AManager.AddCategorySimple(CAT_DATABASE, '数据库', 4);
  AManager.AddCategorySimple(CAT_AUTOUPDATE, '自动更新', 5);
  AManager.AddCategorySimple(CAT_PUBLISHER, '发布工具', 6);
  AManager.AddCategorySimple(CAT_TOOLS, '辅助工具', 7);
end;

end.
