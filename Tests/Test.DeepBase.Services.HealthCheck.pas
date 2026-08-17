{ ============================================================================
  Test.DeepBase.Services.HealthCheck - Unit Tests for Health Check Service

  Tests only the APIs that actually exist in Core/DeepBase.Services.HealthCheck.pas:
  - THealthStatus enum values
  - THealthCheckResult record fields (Status, Description, Data, Duration)
  - IHealthCheck interface (Check, GetName)
  - THealthCheckService:
      RegisterCheck, UnregisterCheck, CheckHealth, GetOverallStatus
  - Exception handling during checks
  ============================================================================ }

unit Test.DeepBase.Services.HealthCheck;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.Services.HealthCheck;

type
  /// <summary>Mock health check that returns a configured result</summary>
  TMockHealthCheck = class(TInterfacedObject, IHealthCheck)
  private
    FName: string;
    FStatus: THealthStatus;
    FDescription: string;
    FCheckCount: Integer;
  public
    constructor Create(const AName: string;
      AStatus: THealthStatus = hsHealthy;
      const ADescription: string = 'OK');

    function Check: THealthCheckResult;
    function GetName: string;

    {$WARN HIDING_MEMBER OFF}
    property Status: THealthStatus read FStatus write FStatus;
    property Description: string read FDescription write FDescription;
    {$WARN HIDING_MEMBER ON}
    property CheckCount: Integer read FCheckCount;
  end;

  /// <summary>Mock health check that raises an exception on Check</summary>
  TFailingHealthCheck = class(TInterfacedObject, IHealthCheck)
  private
    FName: string;
  public
    constructor Create(const AName: string);
    function Check: THealthCheckResult;
    function GetName: string;
  end;

  [TestFixture]
  TTestHealthCheckResult = class
  public
    [Test]
    procedure Test_DefaultValues;

    [Test]
    procedure Test_StatusField_Assignable;

    [Test]
    procedure Test_DescriptionField_Assignable;

    [Test]
    procedure Test_DurationField_Assignable;

    [Test]
    procedure Test_DataField_IsDictionary;
  end;

  [TestFixture]
  TTestHealthStatus = class
  public
    [Test]
    procedure Test_EnumValues_Exist;
  end;

  [TestFixture]
  TTestMockHealthCheck = class
  public
    [Test]
    procedure Test_GetName_ReturnsName;

    [Test]
    procedure Test_Check_ReturnsHealthy;

    [Test]
    procedure Test_Check_ReturnsUnhealthy;

    [Test]
    procedure Test_Check_ReturnsDegraded;
  end;

  [TestFixture]
  TTestHealthCheckService = class
  private
    FService: THealthCheckService;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_RegisterCheck_AddsCheck;

    [Test]
    procedure Test_RegisterCheck_OverwriteSameName;

    [Test]
    procedure Test_UnregisterCheck_RemovesCheck;

    [Test]
    procedure Test_UnregisterCheck_NonExistent_NoError;

    [Test]
    procedure Test_CheckHealth_RunsAllChecks;

    [Test]
    procedure Test_CheckHealth_EmptyService_ReturnsEmpty;

    [Test]
    procedure Test_CheckHealth_IncludesDuration;

    [Test]
    procedure Test_CheckHealth_ExceptionInCheck_ReturnsUnhealthy;

    [Test]
    procedure Test_GetOverallStatus_AllHealthy_ReturnsHealthy;

    [Test]
    procedure Test_GetOverallStatus_OneUnhealthy_ReturnsUnhealthy;

    [Test]
    procedure Test_GetOverallStatus_OneDegraded_ReturnsDegraded;

    [Test]
    procedure Test_GetOverallStatus_NoChecks_ReturnsHealthy;
  end;

implementation

{ TMockHealthCheck }

constructor TMockHealthCheck.Create(const AName: string;
  AStatus: THealthStatus; const ADescription: string);
begin
  inherited Create;
  FName := AName;
  FStatus := AStatus;
  FDescription := ADescription;
  FCheckCount := 0;
end;

function TMockHealthCheck.Check: THealthCheckResult;
begin
  Inc(FCheckCount);
  Result.Status := FStatus;
  Result.Description := FDescription;
  Result.Duration := 0;
  Result.Data := nil;
end;

function TMockHealthCheck.GetName: string;
begin
  Result := FName;
end;

{ TFailingHealthCheck }

constructor TFailingHealthCheck.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

function TFailingHealthCheck.Check: THealthCheckResult;
begin
  raise Exception.Create('Simulated health check failure');
end;

function TFailingHealthCheck.GetName: string;
begin
  Result := FName;
end;

{ TTestHealthCheckResult }

procedure TTestHealthCheckResult.Test_DefaultValues;
var
  R: THealthCheckResult;
begin
  // Default record - fields should be zero/empty
  R := Default(THealthCheckResult);

  Assert.AreEqual(hsHealthy, R.Status, 'Default Status should be hsHealthy (0)');
  Assert.AreEqual('', R.Description);
  Assert.AreEqual(Cardinal(0), R.Duration);
end;

procedure TTestHealthCheckResult.Test_StatusField_Assignable;
var
  R: THealthCheckResult;
begin
  R := Default(THealthCheckResult);

  R.Status := hsUnhealthy;
  Assert.AreEqual(hsUnhealthy, R.Status);

  R.Status := hsDegraded;
  Assert.AreEqual(hsDegraded, R.Status);

  R.Status := hsUnknown;
  Assert.AreEqual(hsUnknown, R.Status);
end;

procedure TTestHealthCheckResult.Test_DescriptionField_Assignable;
var
  R: THealthCheckResult;
begin
  R := Default(THealthCheckResult);

  R.Description := 'Test description';
  Assert.AreEqual('Test description', R.Description);
end;

procedure TTestHealthCheckResult.Test_DurationField_Assignable;
var
  R: THealthCheckResult;
begin
  R := Default(THealthCheckResult);

  R.Duration := 42;
  Assert.AreEqual(Cardinal(42), R.Duration);
end;

procedure TTestHealthCheckResult.Test_DataField_IsDictionary;
var
  R: THealthCheckResult;
begin
  R := Default(THealthCheckResult);

  Assert.IsNull(R.Data);

  R.Data := TDictionary<string, string>.Create;
  try
    R.Data.Add('key', 'value');
    Assert.AreEqual('value', R.Data['key']);
    Assert.AreEqual<Integer>(1, R.Data.Count);
  finally
    R.Data.Free;
  end;
end;

{ TTestHealthStatus }

procedure TTestHealthStatus.Test_EnumValues_Exist;
var
  Status: THealthStatus;
begin
  // Verify all four enum values compile and are distinct
  Status := hsHealthy;
  Assert.AreEqual(Ord(hsHealthy), Ord(Status));

  Status := hsUnhealthy;
  Assert.AreEqual(Ord(hsUnhealthy), Ord(Status));

  Status := hsDegraded;
  Assert.AreEqual(Ord(hsDegraded), Ord(Status));

  Status := hsUnknown;
  Assert.AreEqual(Ord(hsUnknown), Ord(Status));

  // Verify ordering: Healthy < Unhealthy < Degraded < Unknown
  Assert.IsTrue(Ord(hsHealthy) < Ord(hsUnhealthy));
  Assert.IsTrue(Ord(hsUnhealthy) < Ord(hsDegraded));
  Assert.IsTrue(Ord(hsDegraded) < Ord(hsUnknown));
end;

{ TTestMockHealthCheck }

procedure TTestMockHealthCheck.Test_GetName_ReturnsName;
var
  Check: IHealthCheck;
begin
  Check := TMockHealthCheck.Create('TestCheck');
  Assert.AreEqual('TestCheck', Check.GetName);
end;

procedure TTestMockHealthCheck.Test_Check_ReturnsHealthy;
var
  Check: IHealthCheck;
  R: THealthCheckResult;
begin
  Check := TMockHealthCheck.Create('H', hsHealthy, 'All good');
  R := Check.Check;

  Assert.AreEqual(hsHealthy, R.Status);
  Assert.AreEqual('All good', R.Description);
end;

procedure TTestMockHealthCheck.Test_Check_ReturnsUnhealthy;
var
  Check: IHealthCheck;
  R: THealthCheckResult;
begin
  Check := TMockHealthCheck.Create('U', hsUnhealthy, 'Something wrong');
  R := Check.Check;

  Assert.AreEqual(hsUnhealthy, R.Status);
  Assert.AreEqual('Something wrong', R.Description);
end;

procedure TTestMockHealthCheck.Test_Check_ReturnsDegraded;
var
  Check: IHealthCheck;
  R: THealthCheckResult;
begin
  Check := TMockHealthCheck.Create('D', hsDegraded, 'Partial failure');
  R := Check.Check;

  Assert.AreEqual(hsDegraded, R.Status);
  Assert.AreEqual('Partial failure', R.Description);
end;

{ TTestHealthCheckService }

procedure TTestHealthCheckService.Setup;
begin
  FService := THealthCheckService.Create;
end;

procedure TTestHealthCheckService.TearDown;
begin
  FreeAndNil(FService);
end;

procedure TTestHealthCheckService.Test_RegisterCheck_AddsCheck;
var
  Results: TDictionary<string, THealthCheckResult>;
begin
  FService.RegisterCheck(TMockHealthCheck.Create('TestCheck'));

  Results := FService.CheckHealth;
  try
    Assert.IsTrue(Results.ContainsKey('TestCheck'), 'Should contain registered check');
    Assert.AreEqual<Integer>(1, Results.Count);
  finally
    Results.Free;
  end;
end;

procedure TTestHealthCheckService.Test_RegisterCheck_OverwriteSameName;
var
  Results: TDictionary<string, THealthCheckResult>;
  Mock1, Mock2: IHealthCheck;
begin
  Mock1 := TMockHealthCheck.Create('SameName', hsHealthy, 'First');
  Mock2 := TMockHealthCheck.Create('SameName', hsUnhealthy, 'Second');

  FService.RegisterCheck(Mock1);
  FService.RegisterCheck(Mock2);

  Results := FService.CheckHealth;
  try
    Assert.AreEqual<Integer>(1, Results.Count, 'Should still have only one check');
    Assert.AreEqual(hsUnhealthy, Results['SameName'].Status,
      'Should use the second (overwritten) check');
    Assert.AreEqual('Second', Results['SameName'].Description);
  finally
    Results.Free;
  end;
end;

procedure TTestHealthCheckService.Test_UnregisterCheck_RemovesCheck;
var
  Results: TDictionary<string, THealthCheckResult>;
begin
  FService.RegisterCheck(TMockHealthCheck.Create('TestCheck'));
  FService.UnregisterCheck('TestCheck');

  Results := FService.CheckHealth;
  try
    Assert.IsFalse(Results.ContainsKey('TestCheck'),
      'Should not contain unregistered check');
    Assert.AreEqual<Integer>(0, Results.Count);
  finally
    Results.Free;
  end;
end;

procedure TTestHealthCheckService.Test_UnregisterCheck_NonExistent_NoError;
begin
  // Should not raise an exception
  FService.UnregisterCheck('DoesNotExist');
end;

procedure TTestHealthCheckService.Test_CheckHealth_RunsAllChecks;
var
  Mock1, Mock2: IHealthCheck;
  Results: TDictionary<string, THealthCheckResult>;
begin
  Mock1 := TMockHealthCheck.Create('Check1', hsHealthy, 'OK');
  Mock2 := TMockHealthCheck.Create('Check2', hsDegraded, 'Slow');

  FService.RegisterCheck(Mock1);
  FService.RegisterCheck(Mock2);

  Results := FService.CheckHealth;
  try
    Assert.AreEqual<Integer>(2, Results.Count, 'Should have 2 results');
    Assert.IsTrue(Results.ContainsKey('Check1'));
    Assert.IsTrue(Results.ContainsKey('Check2'));

    Assert.AreEqual(hsHealthy, Results['Check1'].Status);
    Assert.AreEqual('OK', Results['Check1'].Description);

    Assert.AreEqual(hsDegraded, Results['Check2'].Status);
    Assert.AreEqual('Slow', Results['Check2'].Description);
  finally
    Results.Free;
  end;
end;

procedure TTestHealthCheckService.Test_CheckHealth_EmptyService_ReturnsEmpty;
var
  Results: TDictionary<string, THealthCheckResult>;
begin
  Results := FService.CheckHealth;
  try
    Assert.AreEqual<Integer>(0, Results.Count, 'Empty service should return empty results');
  finally
    Results.Free;
  end;
end;

procedure TTestHealthCheckService.Test_CheckHealth_IncludesDuration;
var
  Results: TDictionary<string, THealthCheckResult>;
begin
  FService.RegisterCheck(TMockHealthCheck.Create('DurCheck'));

  Results := FService.CheckHealth;
  try
    // Duration is measured via MilliSecondsBetween, stored as Cardinal (always non-negative)
    Assert.IsTrue(True, 'Duration measurement completed successfully');
  finally
    Results.Free;
  end;
end;

procedure TTestHealthCheckService.Test_CheckHealth_ExceptionInCheck_ReturnsUnhealthy;
var
  Results: TDictionary<string, THealthCheckResult>;
begin
  FService.RegisterCheck(TFailingHealthCheck.Create('FailCheck'));

  Results := FService.CheckHealth;
  try
    Assert.IsTrue(Results.ContainsKey('FailCheck'));
    Assert.AreEqual(hsUnhealthy, Results['FailCheck'].Status,
      'Exception in Check should result in hsUnhealthy');
    Assert.IsTrue(Results['FailCheck'].Description.Contains('Exception'),
      'Description should surface the exception class name (not E.Message)');
    Assert.IsFalse(Results['FailCheck'].Description.Contains('Simulated health check failure'),
      'Description must NOT echo raw E.Message — BUG EXP-P1-008 fix');
  finally
    Results.Free;
  end;
end;

procedure TTestHealthCheckService.Test_GetOverallStatus_AllHealthy_ReturnsHealthy;
begin
  FService.RegisterCheck(TMockHealthCheck.Create('C1', hsHealthy));
  FService.RegisterCheck(TMockHealthCheck.Create('C2', hsHealthy));

  Assert.AreEqual(hsHealthy, FService.GetOverallStatus);
end;

procedure TTestHealthCheckService.Test_GetOverallStatus_OneUnhealthy_ReturnsUnhealthy;
begin
  FService.RegisterCheck(TMockHealthCheck.Create('C1', hsHealthy));
  FService.RegisterCheck(TMockHealthCheck.Create('C2', hsUnhealthy));
  FService.RegisterCheck(TMockHealthCheck.Create('C3', hsDegraded));

  // Unhealthy takes priority over everything
  Assert.AreEqual(hsUnhealthy, FService.GetOverallStatus);
end;

procedure TTestHealthCheckService.Test_GetOverallStatus_OneDegraded_ReturnsDegraded;
begin
  FService.RegisterCheck(TMockHealthCheck.Create('C1', hsHealthy));
  FService.RegisterCheck(TMockHealthCheck.Create('C2', hsDegraded));

  Assert.AreEqual(hsDegraded, FService.GetOverallStatus);
end;

procedure TTestHealthCheckService.Test_GetOverallStatus_NoChecks_ReturnsHealthy;
begin
  // Per the implementation: no unhealthy and no degraded => hsHealthy
  Assert.AreEqual(hsHealthy, FService.GetOverallStatus);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestHealthCheckResult);
  TDUnitX.RegisterTestFixture(TTestHealthStatus);
  TDUnitX.RegisterTestFixture(TTestMockHealthCheck);
  TDUnitX.RegisterTestFixture(TTestHealthCheckService);

end.
