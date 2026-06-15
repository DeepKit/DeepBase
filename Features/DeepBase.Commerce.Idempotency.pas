{ ============================================================================
  DeepBase.Commerce.Idempotency - Client-side idempotency nonce tracking

  Generates unique idempotency keys for commerce operations and tracks used
  nonces to prevent accidental replay of completed operations (e.g. double
  payment, duplicate quota consumption).

  Usage:
    FTracker := TIdempotencyNonceTracker.Create;
    Key := FTracker.NewKey('create_order');
    // ... perform HTTP request with Key as Idempotency-Key header ...
    FTracker.RecordSuccess(Key, ResponseJson);
    // Later, before retrying:
    if FTracker.IsAlreadyCompleted(Key) then
      CachedResponse := FTracker.GetCachedResponse(Key);

  Requirements: idempotency replay protection
  ============================================================================ }

unit DeepBase.Commerce.Idempotency;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.SyncObjs,
  System.DateUtils;

type
  TNonceRecord = record
    Key: string;
    Operation: string;
    CreatedAt: TDateTime;
    CompletedAt: TDateTime;
    ResponseJson: string;
    Completed: Boolean;
  end;

  /// <summary>
  /// Tracks idempotency nonces to prevent replay of completed commerce
  /// operations. Thread-safe. Entries expire after ExpiryMinutes (default 60).
  /// </summary>
  TIdempotencyNonceTracker = class
  private
    FNonces: TDictionary<string, TNonceRecord>;
    FLock: TCriticalSection;
    FExpiryMinutes: Integer;
    FCounter: Int64;

    procedure PurgeExpired;
  public
    constructor Create(AExpiryMinutes: Integer = 60);
    destructor Destroy; override;

    /// <summary>
    /// Generates a new unique idempotency key for the named operation.
    /// The key format is: operation-timestamp-counter-guid.
    /// </summary>
    function NewKey(const AOperation: string): string;

    /// <summary>
    /// Records a successful completion for the given key, caching the
    /// response JSON. Subsequent calls to IsAlreadyCompleted will return True.
    /// </summary>
    procedure RecordSuccess(const AKey: string; const AResponseJson: string = '');

    /// <summary>
    /// Returns True if the given key was previously recorded as completed
    /// (and has not expired). Use GetCachedResponse to retrieve the response.
    /// </summary>
    function IsAlreadyCompleted(const AKey: string): Boolean;

    /// <summary>
    /// Returns the cached response for a completed key. Returns empty string
    /// if the key is not found or not completed.
    /// </summary>
    function GetCachedResponse(const AKey: string): string;

    /// <summary>
    /// Marks a key as failed (will not be cached, allowing retry with the
    /// same key). This is the default state — only RecordSuccess prevents replay.
    /// </summary>
    procedure RecordFailure(const AKey: string);

    /// <summary>Number of tracked nonces (for diagnostics).</summary>
    function Count: Integer;

    /// <summary>Expires completed entries older than ExpiryMinutes.</summary>
    procedure Expire;
  end;

implementation

{ TIdempotencyNonceTracker }

constructor TIdempotencyNonceTracker.Create(AExpiryMinutes: Integer);
begin
  inherited Create;
  FNonces := TDictionary<string, TNonceRecord>.Create;
  FLock := TCriticalSection.Create;
  FExpiryMinutes := AExpiryMinutes;
  FCounter := 0;
end;

destructor TIdempotencyNonceTracker.Destroy;
begin
  FLock.Free;
  FNonces.Free;
  inherited;
end;

procedure TIdempotencyNonceTracker.PurgeExpired;
var
  NowUtc: TDateTime;
  KeysToRemove: TList<string>;
  Pair: TPair<string, TNonceRecord>;
begin
  NowUtc := TTimeZone.Local.ToUniversalTime(Now);
  KeysToRemove := TList<string>.Create;
  try
    for Pair in FNonces do
      if Pair.Value.Completed and
         ((NowUtc - Pair.Value.CompletedAt) * MinsPerDay > FExpiryMinutes) then
        KeysToRemove.Add(Pair.Key);
    var Key: string;
    for Key in KeysToRemove do
      FNonces.Remove(Key);
  finally
    KeysToRemove.Free;
  end;
end;

function TIdempotencyNonceTracker.NewKey(const AOperation: string): string;
var
  Guid: TGUID;
  LRec: TNonceRecord;
begin
  CreateGUID(Guid);
  FLock.Enter;
  try
    Inc(FCounter);
    Result := AOperation + '-' +
      FormatDateTime('yyyymmddhhnnsszzz', Now) + '-' +
      IntToStr(FCounter) + '-' +
      GUIDToString(Guid);

    LRec.Key := Result;
    LRec.Operation := AOperation;
    LRec.CreatedAt := TTimeZone.Local.ToUniversalTime(Now);
    LRec.CompletedAt := 0;
    LRec.ResponseJson := '';
    LRec.Completed := False;
    FNonces.AddOrSetValue(Result, LRec);
  finally
    FLock.Leave;
  end;
end;

procedure TIdempotencyNonceTracker.RecordSuccess(const AKey,
  AResponseJson: string);
var
  LRec: TNonceRecord;
begin
  FLock.Enter;
  try
    if FNonces.TryGetValue(AKey, LRec) then
    begin
      LRec.Completed := True;
      LRec.CompletedAt := TTimeZone.Local.ToUniversalTime(Now);
      LRec.ResponseJson := AResponseJson;
      FNonces.AddOrSetValue(AKey, LRec);
    end;
  finally
    FLock.Leave;
  end;
end;

function TIdempotencyNonceTracker.IsAlreadyCompleted(const AKey: string): Boolean;
var
  LRec: TNonceRecord;
begin
  FLock.Enter;
  try
    if FNonces.TryGetValue(AKey, LRec) then
      Result := LRec.Completed
    else
      Result := False;
  finally
    FLock.Leave;
  end;
end;

function TIdempotencyNonceTracker.GetCachedResponse(const AKey: string): string;
var
  LRec: TNonceRecord;
begin
  Result := '';
  FLock.Enter;
  try
    if FNonces.TryGetValue(AKey, LRec) and LRec.Completed then
      Result := LRec.ResponseJson;
  finally
    FLock.Leave;
  end;
end;

procedure TIdempotencyNonceTracker.RecordFailure(const AKey: string);
var
  LRec: TNonceRecord;
begin
  FLock.Enter;
  try
    if FNonces.TryGetValue(AKey, LRec) then
    begin
      LRec.Completed := False;
      LRec.ResponseJson := '';
      FNonces.AddOrSetValue(AKey, LRec);
    end;
  finally
    FLock.Leave;
  end;
end;

function TIdempotencyNonceTracker.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FNonces.Count;
  finally
    FLock.Leave;
  end;
end;

procedure TIdempotencyNonceTracker.Expire;
begin
  FLock.Enter;
  try
    PurgeExpired;
  finally
    FLock.Leave;
  end;
end;

end.
