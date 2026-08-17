{ ============================================================================
  DeepBase.TimeGuard - Time Manipulation Detection

  Version: 1.0
  Description:
    Detects system clock manipulation (time rewinding) to prevent users from
    bypassing trial periods or license expiry by changing their system clock.

    Strategy:
      1. Fetch server time via HTTP Date response header (any HEAD/GET request)
      2. Compare local time vs server time to compute offset
      3. Store last known good time in encrypted storage
      4. On next launch, compare local time vs stored last-known-good
      5. If local < last-known-good → clock was rewound

    Integration:
      TTimeGuard is designed to work with any HTTP transport. Pass an
      ITimeGuardHttpTransport implementation or use the default TNetTimeGuardHttp
      (which uses TNetHTTPClient). The Licensing facade creates one automatically.

    Thread safety:
      TTimeGuard is NOT thread-safe. Callers should synchronize externally if
      accessing from multiple threads.

  Usage:
    var TG := TTimeGuard.Create('myapp.timeguard', 5);
    TG.SetServerUrl('https://api.deepkit.top');
    var R := TG.Verify;
    if R = tgClockRewound then
      ShowMessage('Clock manipulation detected');
    var CorrectedTime := TG.GetCorrectedNow;
  ============================================================================ }

unit DeepBase.TimeGuard;

interface

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.Net.HTTPClient,
  System.Net.URLClient;

type
  /// <summary>Result of time verification.</summary>
  TTimeGuardResult = (
    tgOk,             // Local time matches server time within tolerance
    tgSkewMinor,      // Deviation <= MaxDriftMinutes (NTP sync normal range)
    tgSkewMajor,      // Deviation > MaxDriftMinutes but < 24 hours (suspicious)
    tgClockRewound,   // Local time < last known good time (clock was set back)
    tgOffline         // Cannot reach server — using cached data
  );

  /// <summary>
  /// HTTP transport abstraction for TimeGuard. Enables unit testing without
  /// real network calls.
  /// </summary>
  ITimeGuardHttpTransport = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']
    /// <summary>
    /// Send a HEAD or GET request and return the server's Date header as TDateTime.
    /// Returns 0 if the request fails or Date header is missing.
    /// </summary>
    function FetchServerTime(const AUrl: string): TDateTime;
  end;

  /// <summary>
  /// Default HTTP transport using TNetHTTPClient. Fetches server time via
  /// HEAD request and reads the Date response header.
  /// </summary>
  TNetTimeGuardHttp = class(TInterfacedObject, ITimeGuardHttpTransport)
  private
    FTimeoutMs: Integer;
  public
    constructor Create(ATimeoutMs: Integer = 10000);
    function FetchServerTime(const AUrl: string): TDateTime;
  end;

  /// <summary>
  /// Secret store interface for persisting last known good time.
  /// Minimal interface — DeepBase.Security.SecretStore implements this.
  /// </summary>
  ITimeGuardSecretStore = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-123456789012}']
    procedure SaveSecret(const AKey, AValue: string);
    function LoadSecret(const AKey: string): string;
  end;

  /// <summary>
  /// Time manipulation detection service.
  ///
  /// Lifecycle:
  ///   1. Create with a storage key and max drift tolerance
  ///   2. Set ServerUrl (the backend URL to query for time)
  ///   3. Optionally inject SecretStore and HttpTransport for testing
  ///   4. Call Verify to check time integrity
  ///   5. Use GetCorrectedNow for time-sensitive operations
  /// </summary>
  TTimeGuard = class
  private
    FStorageKey: string;
    FServerUrl: string;
    FMaxDriftMinutes: Integer;
    FLastKnownGoodTime: TDateTime;
    FServerTimeOffset: TDateTime;  // ServerTime - LocalTime
    FLastVerifyResult: TTimeGuardResult;
    FHttpTransport: ITimeGuardHttpTransport;
    FSecretStore: ITimeGuardSecretStore;
    FVerified: Boolean;

    function GetHttpTransport: ITimeGuardHttpTransport;
    function GetSecretStore: ITimeGuardSecretStore;
    procedure SaveLastKnownGoodTime(ATime: TDateTime);
    function LoadLastKnownGoodTime: TDateTime;
  public
    /// <summary>
    /// Create a TimeGuard instance.
    /// @param AStorageKey Key for encrypted storage (e.g. 'myapp.timeguard.last_known')
    /// @param AMaxDriftMinutes Maximum tolerated deviation in minutes (default 5)
    /// </summary>
    constructor Create(const AStorageKey: string = 'timeguard.last_known';
      AMaxDriftMinutes: Integer = 5);

    /// <summary>Set the server URL to query for time verification.</summary>
    procedure SetServerUrl(const AUrl: string);

    /// <summary>Inject custom HTTP transport (for testing).</summary>
    procedure SetHttpTransport(const ATransport: ITimeGuardHttpTransport);

    /// <summary>Inject custom secret store (for testing).</summary>
    procedure SetSecretStore(const AStore: ITimeGuardSecretStore);

    /// <summary>
    /// Verify local time against server time.
    ///
    /// Steps:
    ///   1. Load last known good time from encrypted storage
    ///   2. Fetch current server time via HTTP Date header
    ///   3. Compare local time vs server time → compute offset
    ///   4. Compare local time vs last known good time → detect rewinding
    ///   5. Save new last known good time if verification succeeded
    ///
    /// Returns the verification result status.
    /// </summary>
    function Verify: TTimeGuardResult;

    /// <summary>
    /// Get the current time corrected for server offset.
    /// If Verify has not been called or was offline, returns local Now.
    /// </summary>
    function GetCorrectedNow: TDateTime;

    /// <summary>
    /// Returns True if the local clock appears trustworthy.
    /// True for tgOk and tgSkewMinor (within NTP tolerance).
    /// </summary>
    function IsTimeTrusted: Boolean;

    /// <summary>Last verification result.</summary>
    property LastVerifyResult: TTimeGuardResult read FLastVerifyResult;

    /// <summary>Server time offset: ServerTime - LocalTime.</summary>
    property ServerTimeOffset: TDateTime read FServerTimeOffset;

    /// <summary>Last known good time from storage.</summary>
    property LastKnownGoodTime: TDateTime read FLastKnownGoodTime;

    /// <summary>Whether Verify has been called at least once.</summary>
    property Verified: Boolean read FVerified;
  end;

/// <summary>Convert TTimeGuardResult to human-readable string.</summary>
function TimeGuardResultToStr(AResult: TTimeGuardResult): string;

implementation

uses
  System.StrUtils;

{ ---- HTTP Date parsing ---- }

function ParseRfc822Date(const S: string): TDateTime;
var
  LParts: TArray<string>;
  LDay, LMonth, LYear, LHour, LMin, LSec: Integer;
  LMonthStr: string;
begin
  // Format: "Thu, 03 Jul 2026 12:34:56 GMT"
  // or:     "Thu, 03-Jul-2026 12:34:56 GMT"
  Result := 0;
  LParts := S.Split([',', ' ', '-']);

  // Find the day number, month, year, and time parts
  // After splitting by comma and space: ['Thu', '03', 'Jul', '2026', '12:34:56', 'GMT']
  // Or with dash: ['Thu', '03', 'Jul', '2026', '12:34:56', 'GMT']
  if Length(LParts) < 5 then
    Exit;

  // Try to find numeric day
  LDay := 0;
  LMonth := 0;
  LYear := 0;
  LHour := 0;
  LMin := 0;
  LSec := 0;

  var I: Integer;
  var LTimeParsed := False;
  for I := 1 to High(LParts) do
  begin
    if LParts[I].Trim = '' then
      Continue;

    // Try as day number (1-31)
    if (LDay = 0) and TryStrToInt(LParts[I].Trim, LDay) and (LDay >= 1) and (LDay <= 31) then
      Continue;

    // Try as year (4 digits)
    if (LYear = 0) and TryStrToInt(LParts[I].Trim, LYear) and (LYear >= 1970) then
      Continue;

    // Try as month name
    if LMonth = 0 then
    begin
      LMonthStr := Copy(LParts[I].Trim, 1, 3).ToLower;
      if LMonthStr = 'jan' then LMonth := 1
      else if LMonthStr = 'feb' then LMonth := 2
      else if LMonthStr = 'mar' then LMonth := 3
      else if LMonthStr = 'apr' then LMonth := 4
      else if LMonthStr = 'may' then LMonth := 5
      else if LMonthStr = 'jun' then LMonth := 6
      else if LMonthStr = 'jul' then LMonth := 7
      else if LMonthStr = 'aug' then LMonth := 8
      else if LMonthStr = 'sep' then LMonth := 9
      else if LMonthStr = 'oct' then LMonth := 10
      else if LMonthStr = 'nov' then LMonth := 11
      else if LMonthStr = 'dec' then LMonth := 12;
      if LMonth > 0 then
        Continue;
    end;

    // Try as time HH:MM:SS
    if not LTimeParsed then
    begin
      var LTimeParts := LParts[I].Split([':']);
      if Length(LTimeParts) >= 2 then
      begin
        if TryStrToInt(LTimeParts[0].Trim, LHour) and
           TryStrToInt(LTimeParts[1].Trim, LMin) then
        begin
          if Length(LTimeParts) >= 3 then
            TryStrToInt(LTimeParts[2].Trim, LSec);
          LTimeParsed := True;
        end;
      end;
    end;
  end;

  if (LDay > 0) and (LMonth > 0) and (LYear > 0) and LTimeParsed then
  begin
    try
      Result := EncodeDateTime(LYear, LMonth, LDay, LHour, LMin, LSec, 0);
    except
      Result := 0;
    end;
  end;
end;

{ ---- TNetTimeGuardHttp ---- }

constructor TNetTimeGuardHttp.Create(ATimeoutMs: Integer);
begin
  inherited Create;
  FTimeoutMs := ATimeoutMs;
end;

function TNetTimeGuardHttp.FetchServerTime(const AUrl: string): TDateTime;
var
  LHTTP: THTTPClient;
  LResponse: IHTTPResponse;
  LDateStr: string;
  LHeaders: TNetHeaders;
  I: Integer;
begin
  Result := 0;
  LHTTP := THTTPClient.Create;
  try
    LHTTP.ConnectionTimeout := FTimeoutMs;
    LHTTP.ResponseTimeout := FTimeoutMs;
    try
      LResponse := LHTTP.Get(AUrl);
      if Assigned(LResponse) and (LResponse.StatusCode < 400) then
      begin
        LHeaders := LResponse.Headers;
        for I := 0 to Length(LHeaders) - 1 do
        begin
          if SameText(LHeaders[I].Name, 'Date') then
          begin
            LDateStr := LHeaders[I].Value;
            Break;
          end;
        end;
        if LDateStr <> '' then
          Result := ParseRfc822Date(LDateStr);
      end;
    except
      // Network error — return 0
      Result := 0;
    end;
  finally
    LHTTP.Free;
  end;
end;

{ ---- TTimeGuard ---- }

constructor TTimeGuard.Create(const AStorageKey: string; AMaxDriftMinutes: Integer);
begin
  inherited Create;
  FStorageKey := AStorageKey;
  FMaxDriftMinutes := AMaxDriftMinutes;
  FServerTimeOffset := 0;
  FLastKnownGoodTime := 0;
  FLastVerifyResult := tgOffline;
  FVerified := False;
end;

procedure TTimeGuard.SetServerUrl(const AUrl: string);
begin
  FServerUrl := AUrl;
  // Strip trailing slash
  while (FServerUrl <> '') and (FServerUrl[Length(FServerUrl)] = '/') do
    Delete(FServerUrl, Length(FServerUrl), 1);
end;

procedure TTimeGuard.SetHttpTransport(const ATransport: ITimeGuardHttpTransport);
begin
  FHttpTransport := ATransport;
end;

procedure TTimeGuard.SetSecretStore(const AStore: ITimeGuardSecretStore);
begin
  FSecretStore := AStore;
end;

function TTimeGuard.GetHttpTransport: ITimeGuardHttpTransport;
begin
  if FHttpTransport = nil then
    FHttpTransport := TNetTimeGuardHttp.Create;
  Result := FHttpTransport;
end;

function TTimeGuard.GetSecretStore: ITimeGuardSecretStore;
begin
  Result := FSecretStore;
end;

procedure TTimeGuard.SaveLastKnownGoodTime(ATime: TDateTime);
var
  LStore: ITimeGuardSecretStore;
  LISO: string;
begin
  LStore := GetSecretStore;
  if LStore = nil then
    Exit;
  try
    LISO := DateToISO8601(ATime, False);  // UTC
    LStore.SaveSecret(FStorageKey, LISO);
  except
    // Storage failure is non-fatal
  end;
end;

function TTimeGuard.LoadLastKnownGoodTime: TDateTime;
var
  LStore: ITimeGuardSecretStore;
  LISO: string;
begin
  Result := 0;
  LStore := GetSecretStore;
  if LStore = nil then
    Exit;
  try
    LISO := LStore.LoadSecret(FStorageKey);
    if LISO <> '' then
      TryISO8601ToDate(LISO, Result, False);
  except
    Result := 0;
  end;
end;

function TTimeGuard.Verify: TTimeGuardResult;
var
  LServerTime, LLocalNow: TDateTime;
  LDriftMinutes: Double;
  LLastGood: TDateTime;
begin
  FVerified := True;
  LLocalNow := Now;

  // Load last known good time
  LLastGood := LoadLastKnownGoodTime;
  FLastKnownGoodTime := LLastGood;

  // Try to fetch server time
  LServerTime := 0;
  if FServerUrl <> '' then
  begin
    try
      LServerTime := GetHttpTransport.FetchServerTime(FServerUrl);
    except
      LServerTime := 0;
    end;
  end;

  if LServerTime = 0 then
  begin
    // Offline — check rewinding against last known good
    if (LLastGood > 0) and (LLocalNow < LLastGood) then
    begin
      // Local time is before last known good — likely rewound
      Result := tgClockRewound;
    end
    else
    begin
      Result := tgOffline;
    end;
    FLastVerifyResult := Result;
    Exit;
  end;

  // Compute offset: how much server time differs from local
  FServerTimeOffset := LServerTime - LLocalNow;
  LDriftMinutes := Abs(FServerTimeOffset * MinsPerDay);  // FServerTimeOffset is in days

  // Check for rewinding against last known good
  if (LLastGood > 0) and (LLocalNow < LLastGood - (FMaxDriftMinutes / MinsPerDay)) then
  begin
    // Local time went backward significantly — clock was rewound
    Result := tgClockRewound;
    // Don't update last known good — keep the previous trustworthy value
    FLastVerifyResult := Result;
    Exit;
  end;

  // Save server time as new last known good
  SaveLastKnownGoodTime(LServerTime);
  FLastKnownGoodTime := LServerTime;

  // Classify the deviation
  if LDriftMinutes <= FMaxDriftMinutes then
    Result := tgOk
  else if LDriftMinutes <= (FMaxDriftMinutes * 2) then
    Result := tgSkewMinor
  else
    Result := tgSkewMajor;  // Suspicious deviation

  FLastVerifyResult := Result;
end;

function TTimeGuard.GetCorrectedNow: TDateTime;
begin
  if FVerified and (FServerTimeOffset <> 0) then
    Result := Now + FServerTimeOffset
  else
    Result := Now;
end;

function TTimeGuard.IsTimeTrusted: Boolean;
begin
  Result := FLastVerifyResult in [tgOk, tgSkewMinor, tgOffline];
end;

function TimeGuardResultToStr(AResult: TTimeGuardResult): string;
begin
  case AResult of
    tgOk:           Result := 'OK';
    tgSkewMinor:    Result := 'MinorSkew';
    tgSkewMajor:    Result := 'MajorSkew';
    tgClockRewound: Result := 'ClockRewound';
    tgOffline:      Result := 'Offline';
  else
    Result := 'Unknown';
  end;
end;

end.
