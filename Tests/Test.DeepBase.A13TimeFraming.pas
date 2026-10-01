{ ============================================================================
  Test.DeepBase.A13TimeFraming - framework sentinel for WO-20260929-AUDIT-甲-A13

  Delivery artefact of A13 (裁定件 §五 C.3 + §六 判据6): the same source file is
  run in a pre-fix tree and in the post-fix tree, so 判据1's 双向对照 is measured
  rather than reasoned. P1 is the standing sentinel: anyone who moves Verify back
  to the local naked framing makes P1 red again.

    P1 fake transport carrying GMT numbers   -> 判据1 as written
    P2 fake transport as the A11 fixture now injects it (UTC numbers) -> the
       accepted A11 assertion form pinned against the authorised arrange value
    P3 real transport against a truthful server -> the production defect site
    P4 rewind smaller than the UTC offset    -> 判据2
    P5 pre-fix watermark string read back    -> 存量键 direction
  ============================================================================ }

unit Test.DeepBase.A13TimeFraming;

interface

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.Net.HttpClient,
  System.Net.URLClient,
  DUnitX.TestFramework,
  IdHTTPServer,
  IdContext,
  IdCustomHTTPServer,
  IdSocketHandle,
  DeepBase.TimeGuard;

type
  /// <summary>In-memory watermark store so the probe leaves no credential behind.</summary>
  TFakeWatermarkStore = class(TInterfacedObject, ITimeGuardSecretStore)
  private
    FValue: string;
  public
    procedure SetRaw(const AValue: string);
    procedure SaveSecret(const AKey, AValue: string);
    function LoadSecret(const AKey: string): string;
    property Raw: string read FValue;
  end;

  /// <summary>Transport answering a fixed TDateTime; 0 means unreachable.</summary>
  TFixedTransport = class(TInterfacedObject, ITimeGuardHttpTransport)
  private
    FValue: TDateTime;
  public
    constructor Create(const AValue: TDateTime);
    function FetchServerTime(const AUrl: string): TDateTime;
  end;

  [TestFixture]
  TA13TimeFramingTests = class
  private
    FServer: TIdHTTPServer;
    FServerClock: TDateTime;
    FPort: Integer;
    /// <summary>Serves the Date header Indy writes for a server whose local
    /// clock is FServerClock (Indy puts the UTC numbers of that value on the
    /// wire, which is what a real server does).</summary>
    procedure HandleGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
    procedure StartServer(const AServerLocalClock: TDateTime);
    procedure StopServer;
    function WireDateHeader: string;
    function UtcOffsetHours: Double;
    procedure ProbeLog(const ATag: string; AResult: TTimeGuardResult;
      AGuard: TTimeGuard; AStore: TFakeWatermarkStore);
  public
    [Setup] procedure Setup;
    [Teardown] procedure TearDown;

    [Test] procedure P1_FakeTransportCarryingGmtNumbers_IsTrusted;
    [Test] procedure P2_FakeTransportCarryingUtcNumbersLikeA11_IsTrusted;
    [Test] procedure P3_RealTransportAgainstTruthfulServer_IsTrusted;
    [Test] procedure P4_RewindSmallerThanUtcOffset_IsDetected;
    [Test] procedure P5_LegacyWatermarkString_IsNotAFalseRewind;
  end;

function A13Num(const V: Double): string;

implementation

function A13Num(const V: Double): string;
begin
  Result := Format('%.4f', [V]);
end;

{ TFakeWatermarkStore }

procedure TFakeWatermarkStore.SetRaw(const AValue: string);
begin
  FValue := AValue;
end;

procedure TFakeWatermarkStore.SaveSecret(const AKey, AValue: string);
begin
  FValue := AValue;
end;

function TFakeWatermarkStore.LoadSecret(const AKey: string): string;
begin
  Result := FValue;
end;

{ TFixedTransport }

constructor TFixedTransport.Create(const AValue: TDateTime);
begin
  inherited Create;
  FValue := AValue;
end;

function TFixedTransport.FetchServerTime(const AUrl: string): TDateTime;
begin
  Result := FValue;
end;

{ TA13TimeFramingTests }

procedure TA13TimeFramingTests.Setup;
begin
  FServer := nil;
  FPort := 0;
end;

function TA13TimeFramingTests.UtcOffsetHours: Double;
begin
  Result := TTimeZone.Local.GetUtcOffset(Now).TotalHours;
end;

procedure TA13TimeFramingTests.ProbeLog(const ATag: string;
  AResult: TTimeGuardResult; AGuard: TTimeGuard; AStore: TFakeWatermarkStore);
begin
  System.WriteLn('[A13] ', ATag,
    ' | offset_hours=', A13Num(UtcOffsetHours),
    ' | result=', TimeGuardResultToStr(AResult),
    ' | trusted=', AGuard.IsTimeTrusted.ToString,
    ' | server_offset_hours=', A13Num(AGuard.ServerTimeOffset * 24),
    ' | LKG_minus_now_hours=', A13Num((AGuard.LastKnownGoodTime - Now) * 24),
    ' | LKG_minus_utcnow_hours=',
      A13Num((AGuard.LastKnownGoodTime - TTimeZone.Local.ToUniversalTime(Now)) * 24),
    ' | watermark_raw=', AStore.Raw);
end;

procedure TA13TimeFramingTests.HandleGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
begin
  AResponseInfo.ResponseNo := 200;
  AResponseInfo.ContentType := 'text/plain';
  AResponseInfo.ContentText := 'a13 probe';
  AResponseInfo.Date := FServerClock;
end;

procedure TA13TimeFramingTests.StartServer(const AServerLocalClock: TDateTime);
var
  LBinding: TIdSocketHandle;
  LTry: Integer;
  LOk: Boolean;
begin
  FServerClock := AServerLocalClock;
  FServer := TIdHTTPServer.Create(nil);
  try
    FServer.Bindings.Clear;
    LBinding := FServer.Bindings.Add;
    LBinding.IP := '127.0.0.1';
    FServer.OnCommandGet := HandleGet;
    LOk := False;
    for LTry := 18083 to 18092 do
    begin
      LBinding.Port := LTry;
      try
        FServer.Active := True;
        LOk := True;
        FPort := LTry;
        Break;
      except
        FServer.Active := False;
      end;
    end;
    Assert.IsTrue(LOk, 'probe HTTP server could not bind 127.0.0.1 on 18083..18092');
  except
    FreeAndNil(FServer);
    raise;
  end;
end;

procedure TA13TimeFramingTests.StopServer;
begin
  if FServer <> nil then
  begin
    FServer.Active := False;
    FreeAndNil(FServer);
  end;
  FPort := 0;
end;

function TA13TimeFramingTests.WireDateHeader: string;
var
  LHTTP: THTTPClient;
  LResponse: IHTTPResponse;
  LHeaders: TNetHeaders;
  I: Integer;
begin
  Result := '(none)';
  LHTTP := THTTPClient.Create;
  try
    LHTTP.ConnectionTimeout := 5000;
    LHTTP.ResponseTimeout := 5000;
    LResponse := LHTTP.Get('http://127.0.0.1:' + FPort.ToString);
    LHeaders := LResponse.Headers;
    for I := 0 to Length(LHeaders) - 1 do
    begin
      if SameText(LHeaders[I].Name, 'Date') then
        Exit(LHeaders[I].Value);
    end;
  finally
    LHTTP.Free;
  end;
end;

procedure TA13TimeFramingTests.TearDown;
begin
  StopServer;
end;

procedure TA13TimeFramingTests.P1_FakeTransportCarryingGmtNumbers_IsTrusted;
var
  LStore: TFakeWatermarkStore;
  LIfStore: ITimeGuardSecretStore;
  LGuard: TTimeGuard;
  LResult: TTimeGuardResult;
begin
  // 判据1 verbatim: the transport hands Verify the GMT numbers of the current
  // instant, which IS the true UTC reading. A correct chain must call that tgOk.
  LStore := TFakeWatermarkStore.Create;
  LIfStore := LStore;
  LGuard := TTimeGuard.Create('a13.probe.p1', 5);
  try
    LGuard.SetServerUrl('http://127.0.0.1:1');
    LGuard.SetHttpTransport(TFixedTransport.Create(TTimeZone.Local.ToUniversalTime(Now)));
    LGuard.SetSecretStore(LIfStore);
    LResult := LGuard.Verify;
    ProbeLog('P1', LResult, LGuard, LStore);
    Assert.AreEqual(Ord(tgOk), Ord(LResult),
      'A server reading at the true instant must not be classified as skew, got '
      + TimeGuardResultToStr(LResult));
  finally
    LGuard.Free;
  end;
end;

procedure TA13TimeFramingTests.P2_FakeTransportCarryingUtcNumbersLikeA11_IsTrusted;
var
  LStore: TFakeWatermarkStore;
  LIfStore: ITimeGuardSecretStore;
  LGuard: TTimeGuard;
  LResult: TTimeGuardResult;
begin
  // The arrange value A11's accepted unit now carries after the authorised
  // re-framing (裁定件 §五 B: TFakeTimeServer.Create(ToUniversalTime(Now))), and
  // the verdict its accepted assertion requires. Before the re-framing this
  // injected System.SysUtils.Now, which only read honestly under the old
  // local-naked mixing.
  LStore := TFakeWatermarkStore.Create;
  LIfStore := LStore;
  LGuard := TTimeGuard.Create('a13.probe.p2', 5);
  try
    LGuard.SetServerUrl('http://127.0.0.1:1');
    LGuard.SetHttpTransport(TFixedTransport.Create(
      TTimeZone.Local.ToUniversalTime(System.SysUtils.Now)));
    LGuard.SetSecretStore(LIfStore);
    LResult := LGuard.Verify;
    ProbeLog('P2', LResult, LGuard, LStore);
    Assert.IsTrue(LResult in [tgOk, tgSkewMinor, tgOffline],
      'A11 BackendFailures_DoNotEscapeThroughVerify requires tgOk/tgSkewMinor/'
      + 'tgOffline for this reading, got ' + TimeGuardResultToStr(LResult));
    Assert.IsTrue(LGuard.IsTimeTrusted,
      'A11 requires the clock to stay trusted for that same reading');
  finally
    LGuard.Free;
  end;
end;

procedure TA13TimeFramingTests.P3_RealTransportAgainstTruthfulServer_IsTrusted;
var
  LStore: TFakeWatermarkStore;
  LIfStore: ITimeGuardSecretStore;
  LGuard: TTimeGuard;
  LResult: TTimeGuardResult;
begin
  // The production defect site: the real TNetTimeGuardHttp, its own RFC 822
  // header parsing, against a server whose clock is honest.
  LStore := TFakeWatermarkStore.Create;
  LIfStore := LStore;
  StartServer(Now);
  System.WriteLn('[A13] P3 wire Date=', WireDateHeader,
    ' | true UTC now as numbers=',
      FormatDateTime('yyyy-mm-dd" "hh:nn:ss', TTimeZone.Local.ToUniversalTime(Now)),
    ' | server local clock=', FormatDateTime('yyyy-mm-dd" "hh:nn:ss', Now));
  LGuard := TTimeGuard.Create('a13.probe.p3', 5);
  try
    LGuard.SetServerUrl('http://127.0.0.1:' + FPort.ToString);
    LGuard.SetHttpTransport(TNetTimeGuardHttp.Create(5000));
    LGuard.SetSecretStore(LIfStore);
    LResult := LGuard.Verify;
    ProbeLog('P3', LResult, LGuard, LStore);
    Assert.AreEqual(Ord(tgOk), Ord(LResult),
      'An honest server over the real parser must classify as tgOk, got '
      + TimeGuardResultToStr(LResult));
  finally
    LGuard.Free;
    StopServer;
  end;
end;

procedure TA13TimeFramingTests.P4_RewindSmallerThanUtcOffset_IsDetected;
var
  LStore: TFakeWatermarkStore;
  LIfStore: ITimeGuardSecretStore;
  LFirst: TTimeGuard;
  LSecond: TTimeGuard;
  LR1: TTimeGuardResult;
  LR2: TTimeGuardResult;
begin
  // 判据2: the watermark is recorded one hour ahead of the wall clock, so the
  // wall clock sits one hour behind it. One hour is smaller than this machine
  // UTC offset, which is the钝化 case the order asks to see red before the fix.
  LStore := TFakeWatermarkStore.Create;
  LIfStore := LStore;
  StartServer(IncHour(Now, 1));
  LFirst := TTimeGuard.Create('a13.probe.p4', 5);
  try
    LFirst.SetServerUrl('http://127.0.0.1:' + FPort.ToString);
    LFirst.SetHttpTransport(TNetTimeGuardHttp.Create(5000));
    LFirst.SetSecretStore(LIfStore);
    LR1 := LFirst.Verify;
    ProbeLog('P4.step1', LR1, LFirst, LStore);
  finally
    LFirst.Free;
  end;
  StopServer;

  LSecond := TTimeGuard.Create('a13.probe.p4', 5);
  try
    LSecond.SetServerUrl('http://127.0.0.1:1');
    LSecond.SetHttpTransport(TFixedTransport.Create(0));
    LSecond.SetSecretStore(LIfStore);
    LR2 := LSecond.Verify;
    ProbeLog('P4.step2', LR2, LSecond, LStore);
    Assert.AreEqual(Ord(tgClockRewound), Ord(LR2),
      'A wall clock one hour behind the persisted watermark must be refused as '
      + 'rewound, got ' + TimeGuardResultToStr(LR2));
  finally
    LSecond.Free;
  end;
end;

procedure TA13TimeFramingTests.P5_LegacyWatermarkString_IsNotAFalseRewind;
var
  LStore: TFakeWatermarkStore;
  LIfStore: ITimeGuardSecretStore;
  LGuard: TTimeGuard;
  LResult: TTimeGuardResult;
begin
  // A watermark as the pre-fix code left it in the credential store: the GMT
  // numbers of the true instant written with DateToISO8601(..., False), i.e. a
  // "+08:00" string whose numbers are UTC. Built here from the wire fact, so
  // the same source is meaningful in all three trees.
  LStore := TFakeWatermarkStore.Create;
  LIfStore := LStore;
  LStore.SetRaw(DateToISO8601(TTimeZone.Local.ToUniversalTime(Now), False));
  LGuard := TTimeGuard.Create('a13.probe.p5', 5);
  try
    LGuard.SetServerUrl('http://127.0.0.1:1');
    LGuard.SetHttpTransport(TFixedTransport.Create(0));
    LGuard.SetSecretStore(LIfStore);
    LResult := LGuard.Verify;
    ProbeLog('P5', LResult, LGuard, LStore);
    Assert.AreNotEqual(Ord(tgClockRewound), Ord(LResult),
      'Reading a pre-fix watermark must not produce a false rewind verdict, got '
      + TimeGuardResultToStr(LResult));
  finally
    LGuard.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TA13TimeFramingTests);

end.
