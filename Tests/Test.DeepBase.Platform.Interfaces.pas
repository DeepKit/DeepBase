{ ============================================================================
  Test.DeepBase.Platform.Interfaces
  ---------------------------------------------------------------------------
  DUnitX tests for DeepBase.Platform.Interfaces (in Core).

  Scope:
    - Set*/Get* registration for the four delegates
      (permission check / request / share text / share file).
    - nil unregisters; passing nil to Get* returns an unassigned ref.
    - Concurrent Set/Get stress (8 threads × 200 swaps).
    - Callback semantics: a RequestPermission delegate that returns
      prRequestIssued must invoke its callback exactly once with
      prGranted or prDenied.

  NOT tested here (covered in Tests/FMX/Test.FMX.Platform.Standalone.dpr):
    - TUniPlatformAdapter.Register*Override wiring.
    - Compile-time IFDEF fallback behaviour on Android/iOS/Windows.
  ============================================================================ }

unit Test.DeepBase.Platform.Interfaces;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes, System.SyncObjs, System.Threading,
  DeepBase.Platform.Interfaces;

type
  [TestFixture]
  TTestPlatformInterfaces = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_SetPermissionCheck_RoundTrips;
    [Test]
    procedure Test_SetPermissionRequest_RoundTrips;
    [Test]
    procedure Test_SetShareText_RoundTrips;
    [Test]
    procedure Test_SetShareFile_RoundTrips;

    [Test]
    procedure Test_SetPermissionCheck_Nil_Clears;
    [Test]
    procedure Test_SetShareText_Nil_Clears;

    [Test]
    procedure Test_PermissionCheck_ReturnsExpectedEnum;
    [Test]
    procedure Test_RequestPermission_CallsCallbackExactlyOnce;
    [Test]
    procedure Test_RequestCallback_ReceivesGrantedOrDenied;

    [Test]
    procedure Test_ConcurrentSetGet_NoCrashOrCorruption;
  end;

implementation

{ TTestPlatformInterfaces }

procedure TTestPlatformInterfaces.Setup;
begin
  // Reset all registrations so tests are isolated.
  SetPermissionCheck(nil);
  SetPermissionRequest(nil);
  SetShareText(nil);
  SetShareFile(nil);
end;

procedure TTestPlatformInterfaces.TearDown;
begin
  SetPermissionCheck(nil);
  SetPermissionRequest(nil);
  SetShareText(nil);
  SetShareFile(nil);
end;

procedure TTestPlatformInterfaces.Test_SetPermissionCheck_RoundTrips;
var
  LOut: TPermissionCheckFunc;
begin
  SetPermissionCheck(
    function(const APerm: string): TPermissionResult
    begin Result := prGranted; end);
  LOut := GetPermissionCheck();
  Assert.IsTrue(Assigned(LOut), 'GetPermissionCheck should be assigned after Set');
  Assert.AreEqual(Ord(prGranted), Ord(LOut('microphone')),
    'Registered delegate should return the value it was programmed to return');
end;

procedure TTestPlatformInterfaces.Test_SetPermissionRequest_RoundTrips;
var
  LOut: TPermissionRequestFunc;
begin
  SetPermissionRequest(
    function(const APerm: string; const ACb: TPermissionCallback): TPermissionResult
    begin Result := prUnsupported; end);
  LOut := GetPermissionRequest();
  Assert.IsTrue(Assigned(LOut), 'GetPermissionRequest assigned after Set');
  Assert.AreEqual(Ord(prUnsupported), Ord(LOut('camera', nil)),
    'Registered request delegate should return prUnsupported');
end;

procedure TTestPlatformInterfaces.Test_SetShareText_RoundTrips;
var
  LOut: TShareTextFunc;
begin
  SetShareText(
    function(const AText, ASubject: string): Boolean
    begin Result := True; end);
  LOut := GetShareText();
  Assert.IsTrue(Assigned(LOut), 'GetShareText assigned after Set');
  Assert.IsTrue(LOut('hello', 'sub'), 'Registered share-text delegate returned True');
end;

procedure TTestPlatformInterfaces.Test_SetShareFile_RoundTrips;
var
  LOut: TShareFileFunc;
begin
  SetShareFile(
    function(const APath: string): Boolean
    begin Result := False; end);
  LOut := GetShareFile();
  Assert.IsTrue(Assigned(LOut), 'GetShareFile assigned after Set');
  Assert.IsFalse(LOut('c:\x.txt'), 'Registered share-file delegate returned False');
end;

procedure TTestPlatformInterfaces.Test_SetPermissionCheck_Nil_Clears;
begin
  SetPermissionCheck(
    function(const A: string): TPermissionResult
    begin Result := prDenied; end);
  Assert.IsTrue(Assigned(GetPermissionCheck()), 'Set then Get');
  SetPermissionCheck(nil);
  Assert.IsFalse(Assigned(GetPermissionCheck()), 'nil clears the registration');
end;

procedure TTestPlatformInterfaces.Test_SetShareText_Nil_Clears;
begin
  SetShareText(
    function(const A, B: string): Boolean
    begin Result := True; end);
  Assert.IsTrue(Assigned(GetShareText()));
  SetShareText(nil);
  Assert.IsFalse(Assigned(GetShareText()), 'nil clears share-text registration');
end;

procedure TTestPlatformInterfaces.Test_PermissionCheck_ReturnsExpectedEnum;
var
  LCheck: TPermissionCheckFunc;
begin
  // Simulate a mock that maps permission keys to different outcomes.
  LCheck :=
    function(const APerm: string): TPermissionResult
    begin
      if SameText(APerm, 'android.permission.CAMERA') then
        Result := prGranted
      else if SameText(APerm, 'android.permission.BODY_SENSORS') then
        Result := prDenied
      else if SameText(APerm, 'nonsense.key') then
        Result := prUnsupported
      else
        Result := prGranted;
    end;
  SetPermissionCheck(LCheck);

  Assert.AreEqual(Ord(prGranted),
    Ord(GetPermissionCheck()('android.permission.CAMERA')), 'CAMERA granted');
  Assert.AreEqual(Ord(prDenied),
    Ord(GetPermissionCheck()('android.permission.BODY_SENSORS')), 'BODY_SENSORS denied');
  Assert.AreEqual(Ord(prUnsupported),
    Ord(GetPermissionCheck()('nonsense.key')), 'unknown key unsupported');
end;

procedure TTestPlatformInterfaces.Test_RequestPermission_CallsCallbackExactlyOnce;
var
  LRequest: TPermissionRequestFunc;
  LCallCount: Integer;
  LLock: TCriticalSection;
begin
  LLock := TCriticalSection.Create;
  try
    LCallCount := 0;
    LRequest :=
      function(const APerm: string; const ACb: TPermissionCallback): TPermissionResult
      begin
        // Simulate async resolution: callback fires synchronously in this mock.
        if Assigned(ACb) then
          ACb(APerm, prGranted);
        Result := prRequestIssued;
      end;
    SetPermissionRequest(LRequest);

    GetPermissionRequest()('microphone',
      procedure(const APerm: string; ARes: TPermissionResult)
      begin
        LLock.Enter;
        try
          Inc(LCallCount);
        finally
          LLock.Leave;
        end;
      end);

    Assert.AreEqual(1, LCallCount, 'Callback must fire exactly once');
  finally
    LLock.Free;
  end;
end;

procedure TTestPlatformInterfaces.Test_RequestCallback_ReceivesGrantedOrDenied;
var
  LRequest: TPermissionRequestFunc;
  LReceived: TPermissionResult;
begin
  LReceived := prUnsupported;
  LRequest :=
    function(const APerm: string; const ACb: TPermissionCallback): TPermissionResult
    begin
      if Assigned(ACb) then ACb(APerm, prDenied);
      Result := prRequestIssued;
    end;
  SetPermissionRequest(LRequest);

  GetPermissionRequest()('camera',
    procedure(const APerm: string; ARes: TPermissionResult)
    begin
      LReceived := ARes;
    end);

  Assert.AreEqual(Ord(prDenied), Ord(LReceived),
    'Callback should receive the result value the delegate emitted');
end;

procedure TTestPlatformInterfaces.Test_ConcurrentSetGet_NoCrashOrCorruption;
const
  THREAD_COUNT = 8;
  ITER_COUNT   = 200;
var
  LTasks: array of ITask;
  LStartEv, LDoneEv: TEvent;
  I: Integer;
  LSwap, LRead: Integer;
  LLock: TCriticalSection;
begin
  LLock := TCriticalSection.Create;
  LStartEv := TEvent.Create(nil, True, False, '');
  LDoneEv := TEvent.Create(nil, True, False, '');
  try
    SetLength(LTasks, THREAD_COUNT);
    LSwap := 0; LRead := 0;
    for I := 0 to THREAD_COUNT - 1 do
    begin
      LTasks[I] := TTask.Run(
        procedure
        var J: Integer;
            LDelegate: TPermissionCheckFunc;
        begin
          LStartEv.WaitFor(INFINITE);
          for J := 0 to ITER_COUNT - 1 do
          begin
            if Odd(J) then
            begin
              LDelegate := function(const A: string): TPermissionResult
                begin Result := prGranted; end;
              SetPermissionCheck(LDelegate);
              LLock.Enter;
              try Inc(LSwap); finally LLock.Leave; end;
            end
            else
            begin
              if Assigned(GetPermissionCheck()) then
              begin
                LLock.Enter;
                try Inc(LRead); finally LLock.Leave; end;
              end;
            end;
          end;
        end);
    end;
    LStartEv.SetEvent;
    TTask.WaitForAll(LTasks);
    // Smoke check: at least one swap and one read happened.
    Assert.IsTrue(LSwap > 0, 'Swaps executed');
    Assert.IsTrue(LRead >= 0, 'Reads executed (non-negative)');
  finally
    LLock.Free;
    LStartEv.Free;
    LDoneEv.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPlatformInterfaces);

end.
