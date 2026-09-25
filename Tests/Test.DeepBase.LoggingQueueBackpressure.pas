{ ============================================================================
  Test.DeepBase.LoggingQueueBackpressure - A2-12 regression

  TDeepBaseLogger async queue must have a configurable capacity bound:
  flood beyond capacity => bounded memory + accurate drop counter +
  backpressure warning in the written artifact; below capacity => strict
  FIFO with zero loss.
  ============================================================================ }

unit Test.DeepBase.LoggingQueueBackpressure;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Character,
  System.StrUtils,
  System.IOUtils,
  System.Generics.Collections,
  DeepBase.Constants,
  DeepBase.Logging;

type
  [TestFixture]
  TTestLoggingQueueBackpressureA212 = class
  private
    function LogDir: string;
    function ReadAllLogText: string;
    function CountMarkerLines(const AText, AMarker: string): Integer;
  public
    [Test]
    procedure Test_DefaultCapacity_ComesFromConstants;

    [Test]
    procedure Test_NonPositiveCapacity_Rejected;

    [Test]
    procedure Test_BelowCapacity_NoLossAndFifoOrder;

    [Test]
    procedure Test_Flood_DropCountExactAndBounded;
  end;

implementation

{ TTestLoggingQueueBackpressureA212 }

function TTestLoggingQueueBackpressureA212.LogDir: string;
begin
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Logs');
end;

function TTestLoggingQueueBackpressureA212.ReadAllLogText: string;
var
  F: string;
begin
  Result := '';
  if not DirectoryExists(LogDir) then
    Exit;
  for F in TDirectory.GetFiles(LogDir, 'Log_*.txt') do
    Result := Result + TFile.ReadAllText(F) + sLineBreak;
end;

function TTestLoggingQueueBackpressureA212.CountMarkerLines(
  const AText, AMarker: string): Integer;
var
  Lines: array of string;
  L: string;
begin
  Result := 0;
  Lines := SplitString(AText, sLineBreak);
  for L in Lines do
    if L.Contains(AMarker) then
      Inc(Result);
end;

procedure TTestLoggingQueueBackpressureA212.Test_DefaultCapacity_ComesFromConstants;
var
  Logger: TDeepBaseLogger;
begin
  Logger := TDeepBaseLogger.Create('');
  try
    Logger.StorageMode := lsmFile;
    Assert.AreEqual(DEFAULT_LOG_QUEUE_CAPACITY, Logger.MaxQueueCapacity);
    Assert.AreEqual<Int64>(0, Logger.DroppedEntryCount);
  finally
    Logger.Free;
  end;
end;

procedure TTestLoggingQueueBackpressureA212.Test_NonPositiveCapacity_Rejected;
var
  Logger: TDeepBaseLogger;
begin
  Logger := TDeepBaseLogger.Create('');
  try
    Logger.StorageMode := lsmFile;
    try
      Logger.MaxQueueCapacity := 0;
      Assert.Fail('capacity 0 must be rejected (fail-closed, no unlimited option)');
    except
      on E: EArgumentOutOfRangeException do
        ; // expected
    end;
    try
      Logger.MaxQueueCapacity := -5;
      Assert.Fail('negative capacity must be rejected');
    except
      on E: EArgumentOutOfRangeException do
        ; // expected
    end;
    // valid change sticks
    Logger.MaxQueueCapacity := 700;
    Assert.AreEqual(700, Logger.MaxQueueCapacity);
  finally
    Logger.Free;
  end;
end;

procedure TTestLoggingQueueBackpressureA212.Test_BelowCapacity_NoLossAndFifoOrder;
const
  N = 1000;
  CAP = 2000;
var
  Logger: TDeepBaseLogger;
  Text: string;
  Lines: array of string;
  I, Seen, LastIdx: Integer;
  Marker, Prefix: string;
  RunTag: string;
begin
  // per-run tag: Log_*.txt files persist in the runner temp dir across
  // executions, so only count lines emitted by THIS run
  RunTag := GUIDToString(TGUID.NewGuid).Replace('-', '').Replace('{', '').Replace('}', '');
  Prefix := 'A212OK-' + RunTag + '-';

  Logger := TDeepBaseLogger.Create('');
  try
    Logger.StorageMode := lsmFile;
    Logger.MaxQueueCapacity := CAP;
    for I := 0 to N - 1 do
      Logger.Log(Prefix + Format('%4.4d', [I]));
    Assert.AreEqual<Int64>(0, Logger.DroppedEntryCount);
  finally
    Logger.Free; // destructor drains the queue fully (CR-278)
  end;

  Text := ReadAllLogText;
  Assert.AreEqual(N, CountMarkerLines(Text, Prefix),
    'all entries below capacity must be written');
  // FIFO: sequence numbers strictly increasing across written lines
  Lines := SplitString(Text, sLineBreak);
  Seen := 0;
  LastIdx := -1;
  for I := 0 to High(Lines) do
  begin
    Marker := Lines[I];
    if Marker.Contains(Prefix) then
    begin
      var K := System.Pos(Prefix, Marker) + Length(Prefix);
      var Digits := '';
      while (K <= Length(Marker)) and CharInSet(Marker[K], ['0' .. '9']) do
      begin
        Digits := Digits + Marker[K];
        Inc(K);
      end;
      var P := StrToIntDef(Digits, -1);
      Assert.IsTrue(P >= 0, 'parseable index expected');
      Assert.IsTrue(P > LastIdx, 'FIFO order violated');
      LastIdx := P;
      Inc(Seen);
    end;
  end;
  Assert.AreEqual(N, Seen);
end;

procedure TTestLoggingQueueBackpressureA212.Test_Flood_DropCountExactAndBounded;
const
  N = 5000;
  CAP = 500;
var
  Logger: TDeepBaseLogger;
  I: Integer;
  Dropped, Written: Int64;
  Text: string;
  Prefix, RunTag: string;
begin
  RunTag := GUIDToString(TGUID.NewGuid).Replace('-', '').Replace('{', '').Replace('}', '');
  Prefix := 'A212F-' + RunTag + '-';

  Logger := TDeepBaseLogger.Create('');
  try
    Logger.StorageMode := lsmFile;
    Logger.MaxQueueCapacity := CAP;
    for I := 0 to N - 1 do
      Logger.Log(Prefix + Format('%4.4d', [I]));
    Dropped := Logger.DroppedEntryCount;
  finally
    Logger.Free; // drain remainder synchronously before counting
  end;

  Assert.IsTrue(Dropped > 0, 'flood far above capacity must drop entries');
  Text := ReadAllLogText;
  Written := CountMarkerLines(Text, Prefix);
  // exact accounting: every offered entry is either written or counted dropped
  Assert.AreEqual<Int64>(N, Written + Dropped,
    'drop counter must exactly complement the written entries');
  // loss is observable inside the artifact itself
  Assert.IsTrue(CountMarkerLines(Text, '[backpressure]') > 0,
    'backpressure warning line expected in log output');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestLoggingQueueBackpressureA212);

end.
