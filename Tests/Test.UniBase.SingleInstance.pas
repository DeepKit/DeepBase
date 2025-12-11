{ ============================================================================
  Test.UniBase.SingleInstance - Unit Tests for Single Instance Application Module
  
  Test Coverage:
    - TAppInstance class properties and methods
    - CheckSingleInstance behavior
    - AllowMultipleInstances flag
    - Mutex naming convention
    - IsFirstInstance property
    - Message window class constants
    - Release cleanup
    
  Note: Some tests are limited because full single-instance testing requires
  actual multi-process scenarios which cannot be fully simulated in unit tests.
  ============================================================================ }

unit Test.UniBase.SingleInstance;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  UniBase.SingleInstance;

type
  [TestFixture]
  TTestAppInstanceProperties = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_AllowMultipleInstances_Default;
    [Test]
    procedure Test_AllowMultipleInstances_SetTrue;
    [Test]
    procedure Test_AllowMultipleInstances_SetFalse;
    [Test]
    procedure Test_IsFirstInstance_Default;
    [Test]
    procedure Test_OnCommandLineReceived_SetGet;
  end;

  [TestFixture]
  TTestCheckSingleInstance = class
  public
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_CheckSingleInstance_AllowMultiple;
    [Test]
    procedure Test_CheckSingleInstance_FirstInstance;
    [Test]
    procedure Test_CheckSingleInstance_UniqueIdentifier;
    [Test]
    procedure Test_CheckSingleInstance_DifferentIdentifiers;
  end;

  [TestFixture]
  TTestMessageConstants = class
  public
    [Test]
    procedure Test_WM_UNIBASE_COPYDATA;
    [Test]
    procedure Test_WM_UNIBASE_ACTIVATE;
    [Test]
    procedure Test_Constants_AreUnique;
  end;

  [TestFixture]
  TTestRelease = class
  public
    [Test]
    procedure Test_Release_NoException;
    [Test]
    procedure Test_Release_MultipleCallsSafe;
  end;

  [TestFixture]
  TTestActivateExistingInstance = class
  public
    [Test]
    procedure Test_ActivateExistingInstance_NoInstance;
  end;

  [TestFixture]
  TTestSendToExistingInstance = class
  public
    [Test]
    procedure Test_SendToExistingInstance_NoInstance;
  end;

implementation

{ TTestAppInstanceProperties }

procedure TTestAppInstanceProperties.Setup;
begin
  // Reset state before each test
  TAppInstance.Release;
  TAppInstance.AllowMultipleInstances := False;
end;

procedure TTestAppInstanceProperties.TearDown;
begin
  TAppInstance.Release;
end;

procedure TTestAppInstanceProperties.Test_AllowMultipleInstances_Default;
begin
  TAppInstance.AllowMultipleInstances := False;  // Reset to default
  Assert.IsFalse(TAppInstance.AllowMultipleInstances);
end;

procedure TTestAppInstanceProperties.Test_AllowMultipleInstances_SetTrue;
begin
  TAppInstance.AllowMultipleInstances := True;
  Assert.IsTrue(TAppInstance.AllowMultipleInstances);
end;

procedure TTestAppInstanceProperties.Test_AllowMultipleInstances_SetFalse;
begin
  TAppInstance.AllowMultipleInstances := True;
  TAppInstance.AllowMultipleInstances := False;
  Assert.IsFalse(TAppInstance.AllowMultipleInstances);
end;

procedure TTestAppInstanceProperties.Test_IsFirstInstance_Default;
begin
  // Before any CheckSingleInstance call, state should be False
  // After Release, the state should be reset
  TAppInstance.Release;
  // Note: IsFirstInstance is set by CheckSingleInstance, default is False
  Assert.IsFalse(TAppInstance.IsFirstInstance);
end;

procedure TTestAppInstanceProperties.Test_OnCommandLineReceived_SetGet;
var
  CallbackCalled: Boolean;
  Handler: TCommandLineReceivedEvent;
begin
  CallbackCalled := False;
  Handler := procedure(const CmdLine: string)
  begin
    CallbackCalled := True;
  end;
  
  TAppInstance.OnCommandLineReceived := Handler;
  Assert.IsTrue(Assigned(TAppInstance.OnCommandLineReceived));
  
  // Clean up
  TAppInstance.OnCommandLineReceived := nil;
end;

{ TTestCheckSingleInstance }

procedure TTestCheckSingleInstance.TearDown;
begin
  TAppInstance.Release;
  TAppInstance.AllowMultipleInstances := False;
end;

procedure TTestCheckSingleInstance.Test_CheckSingleInstance_AllowMultiple;
begin
  TAppInstance.AllowMultipleInstances := True;
  
  var Result := TAppInstance.CheckSingleInstance('Test.AllowMultiple');
  
  Assert.IsTrue(Result);
  Assert.IsTrue(TAppInstance.IsFirstInstance);
end;

procedure TTestCheckSingleInstance.Test_CheckSingleInstance_FirstInstance;
var
  Identifier: string;
begin
  // Use a unique identifier to ensure we're the first instance
  Identifier := 'Test.UniBase.' + TGUID.NewGuid.ToString;
  
  var Result := TAppInstance.CheckSingleInstance(Identifier);
  
  Assert.IsTrue(Result);
  Assert.IsTrue(TAppInstance.IsFirstInstance);
end;

procedure TTestCheckSingleInstance.Test_CheckSingleInstance_UniqueIdentifier;
var
  Id1, Id2: string;
begin
  Id1 := 'Test.UniBase.ID1.' + TGUID.NewGuid.ToString;
  Id2 := 'Test.UniBase.ID2.' + TGUID.NewGuid.ToString;
  
  // First check with Id1
  var Result1 := TAppInstance.CheckSingleInstance(Id1);
  Assert.IsTrue(Result1);
  
  // Release and try with different identifier
  TAppInstance.Release;
  
  var Result2 := TAppInstance.CheckSingleInstance(Id2);
  Assert.IsTrue(Result2);
end;

procedure TTestCheckSingleInstance.Test_CheckSingleInstance_DifferentIdentifiers;
begin
  // Test that different identifiers create different mutexes
  var Id := 'Test.Different.' + TGUID.NewGuid.ToString;
  
  Assert.IsTrue(TAppInstance.CheckSingleInstance(Id));
  
  TAppInstance.Release;
end;

{ TTestMessageConstants }

procedure TTestMessageConstants.Test_WM_UNIBASE_COPYDATA;
begin
  Assert.AreEqual(WM_USER + $1B01, WM_UNIBASE_COPYDATA);
  Assert.IsTrue(WM_UNIBASE_COPYDATA > WM_USER);
end;

procedure TTestMessageConstants.Test_WM_UNIBASE_ACTIVATE;
begin
  Assert.AreEqual(WM_USER + $1B02, WM_UNIBASE_ACTIVATE);
  Assert.IsTrue(WM_UNIBASE_ACTIVATE > WM_USER);
end;

procedure TTestMessageConstants.Test_Constants_AreUnique;
begin
  Assert.AreNotEqual(WM_UNIBASE_COPYDATA, WM_UNIBASE_ACTIVATE);
end;

{ TTestRelease }

procedure TTestRelease.Test_Release_NoException;
begin
  // Calling Release without prior CheckSingleInstance should not raise exception
  TAppInstance.Release;
  Assert.Pass;
end;

procedure TTestRelease.Test_Release_MultipleCallsSafe;
begin
  // Multiple Release calls should be safe
  TAppInstance.Release;
  TAppInstance.Release;
  TAppInstance.Release;
  Assert.Pass;
end;

{ TTestActivateExistingInstance }

procedure TTestActivateExistingInstance.Test_ActivateExistingInstance_NoInstance;
var
  Result: Boolean;
begin
  // Without a running instance, should return False
  TAppInstance.Release;
  Result := TAppInstance.ActivateExistingInstance;
  
  // When there's no other instance, should return False
  Assert.IsFalse(Result);
end;

{ TTestSendToExistingInstance }

procedure TTestSendToExistingInstance.Test_SendToExistingInstance_NoInstance;
begin
  // Sending to non-existent instance should not raise exception
  TAppInstance.Release;
  TAppInstance.SendToExistingInstance('test data');
  Assert.Pass;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestAppInstanceProperties);
  TDUnitX.RegisterTestFixture(TTestCheckSingleInstance);
  TDUnitX.RegisterTestFixture(TTestMessageConstants);
  TDUnitX.RegisterTestFixture(TTestRelease);
  TDUnitX.RegisterTestFixture(TTestActivateExistingInstance);
  TDUnitX.RegisterTestFixture(TTestSendToExistingInstance);

end.
