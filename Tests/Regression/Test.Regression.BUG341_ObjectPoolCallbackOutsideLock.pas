unit Test.Regression.BUG341_ObjectPoolCallbackOutsideLock;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.ObjectPool;

type
  TPoolTestObject = class
  end;

  [TestFixture]
  [Category('regression')]
  TBUG341_ObjectPoolCallbackOutsideLockTest = class(TRegressionTestBase)
  private
    FPool: TObjectPool<TPoolTestObject>;
    FInCallback: Integer;
    FReentrantAcquireOk: Boolean;
    FReentrancyProbeDone: Boolean;
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
    procedure OnObjectAcquired(Sender: TObject; AObject: TPoolTestObject);
  public
    [Setup]
    procedure SetUp; override;
    [TearDown]
    procedure TearDown; override;

    [Test]
    procedure Test_CallbacksOutsideLock_ReentrantAcquireDoesNotDeadlock;
  end;

implementation

procedure TBUG341_ObjectPoolCallbackOutsideLockTest.SetUp;
var
  LCfg: TPoolConfig;
  LFactory: IObjectFactory<TPoolTestObject>;
begin
  inherited;
  FInCallback := 0;
  FReentrantAcquireOk := False;
  FReentrancyProbeDone := False;
  LFactory := TDefaultObjectFactory<TPoolTestObject>.Create;
  LCfg := TPoolConfig.Default;
  LCfg.MinSize := 0;
  LCfg.MaxSize := 4;
  LCfg.AcquireTimeoutMs := 2000;
  FPool := TObjectPool<TPoolTestObject>.Create(LFactory, LCfg);
  FPool.OnObjectAcquired := OnObjectAcquired;
end;

procedure TBUG341_ObjectPoolCallbackOutsideLockTest.TearDown;
begin
  FreeAndNil(FPool);
  inherited;
end;

function TBUG341_ObjectPoolCallbackOutsideLockTest.GetBugNumber: string;
begin
  Result := 'BUG-341';
end;

function TBUG341_ObjectPoolCallbackOutsideLockTest.GetBugDescription: string;
begin
  Result := 'ObjectPool OnObjectAcquired/OnObjectCreated must fire outside FLock';
end;

function TBUG341_ObjectPoolCallbackOutsideLockTest.GetFixDate: string;
begin
  Result := '2026-09-03';
end;

function TBUG341_ObjectPoolCallbackOutsideLockTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBUG341_ObjectPoolCallbackOutsideLockTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.ObjectPool.pas';
end;

procedure TBUG341_ObjectPoolCallbackOutsideLockTest.OnObjectAcquired(
  Sender: TObject; AObject: TPoolTestObject);
var
  LExtra: TPoolTestObject;
  LSavedAcquired: TPoolEvent<TPoolTestObject>;
begin
  if FReentrancyProbeDone then
    Exit;

  FReentrancyProbeDone := True;
  TInterlocked.Increment(FInCallback);
  try
    LSavedAcquired := FPool.OnObjectAcquired;
    FPool.OnObjectAcquired := nil;
    try
      LExtra := FPool.Acquire(2000);
      try
        FReentrantAcquireOk := Assigned(LExtra);
      finally
        FPool.Release(LExtra);
      end;
    finally
      FPool.OnObjectAcquired := LSavedAcquired;
    end;
  finally
    TInterlocked.Decrement(FInCallback);
  end;
end;

procedure TBUG341_ObjectPoolCallbackOutsideLockTest.Test_CallbacksOutsideLock_ReentrantAcquireDoesNotDeadlock;
var
  LObj: TPoolTestObject;
  LTick: UInt64;
begin
  LTick := TThread.GetTickCount64;
  LObj := FPool.Acquire(2000);
  try
    LTick := TThread.GetTickCount64 - LTick;
    Assert.IsTrue(LTick < 2000,
      Format('Primary Acquire must finish within 2s (took %d ms)', [LTick]));
    Assert.IsTrue(FReentrantAcquireOk,
      'Reentrant Acquire from OnObjectAcquired must succeed outside FLock');
    Assert.AreEqual(0, FInCallback,
      'Callbacks must have completed before primary Acquire returns');
  finally
    FPool.Release(LObj);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBUG341_ObjectPoolCallbackOutsideLockTest);

end.
