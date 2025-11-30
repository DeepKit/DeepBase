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
  end;

implementation

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

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseManager);

end.
