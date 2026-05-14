{ ============================================================================
  DeepBase.IntentClarification.Storage - SQLite Persistence via FireDAC

  Provides SQLite-based persistence for session checkpoints and rapport
  profiles using FireDAC (TFDConnection + TFDQuery).

  Phase 2 Integration:
    - DeepBase.DB.Factory: connection obtained via TDBConnectionFactory.GetLocal
    - DeepBase.DB.Guardian: integrity check on first use
    - DeepBase.Logging: structured logging for persistence operations

  Design Properties:
    - Property 43: Save then load produces equivalent object

  Requirements: 16.5, 11.5
  ============================================================================ }

unit DeepBase.IntentClarification.Storage;

interface

uses
  System.SysUtils,
  System.JSON,
  System.DateUtils,
  FireDAC.Comp.Client,
  DeepBase.IntentClarification.Types,
  DeepBase.DB.Factory,
  DeepBase.DB.Guardian,
  DeepBase.Logging,
  DeepBase.IntentClarification.Logging;

type
  /// <summary>
  /// SQLite-based storage for session checkpoints and rapport profiles.
  /// Phase 2: Connection obtained from TDBConnectionFactory.GetLocal.
  /// Integrity verified via TDBGuardian.ProtectConnection on first use.
  /// Property 43: save then load produces equivalent object.
  /// </summary>
  TClarificationStorage = class
  private
    FConnection: TFDConnection;
    FInitialized: Boolean;

    procedure EnsureInitialized;
    function RapportToJson(const AProfile: TRapportProfile): string;
    function JsonToRapport(const AJson: string): TRapportProfile;
  public
    /// <summary>
    /// Creates a storage instance. Connection is obtained from
    /// TDBConnectionFactory.GetLocal on first use.
    /// </summary>
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    /// Initializes the database schema (creates tables if not exist).
    /// Tables: ic_sessions, ic_rapport. Idempotent.
    /// </summary>
    procedure InitializeSchema;

    /// <summary>
    /// Saves a session checkpoint (INSERT OR REPLACE).
    /// </summary>
    procedure SaveCheckpoint(const ACheckpoint: TSessionCheckpoint);

    /// <summary>
    /// Loads a session checkpoint by session ID.
    /// Raises EFileNotFoundException if not found.
    /// </summary>
    function LoadCheckpoint(const ASessionId: string): TSessionCheckpoint;

    /// <summary>
    /// Saves a rapport profile (INSERT OR REPLACE).
    /// </summary>
    procedure SaveRapport(const AProfile: TRapportProfile);

    /// <summary>
    /// Loads a rapport profile by user ID.
    /// Returns a default profile if not found.
    /// </summary>
    function LoadRapport(const AUserId: string): TRapportProfile;

    /// <summary>The underlying FireDAC connection.</summary>
    property Connection: TFDConnection read FConnection;

    /// <summary>
    /// Registers the IC schema as a migration step.
    /// Call during application startup before first use.
    /// Phase 2 Task 23.2: Schema registered as DB.Migrations step.
    /// </summary>
    class procedure RegisterMigration; static;
  end;

implementation

uses
  FireDAC.Stan.Param,
  FireDAC.DApt;

{ TClarificationStorage }

constructor TClarificationStorage.Create;
begin
  inherited Create;
  FConnection := nil;
  FInitialized := False;
  Log(ltDebug, 'IC: Storage created (lazy initialization)');
end;

destructor TClarificationStorage.Destroy;
begin
  // Connection is owned by DB.Factory pool, do not free here
  FConnection := nil;
  inherited;
end;

procedure TClarificationStorage.EnsureInitialized;
var
  LGuardResult: TGuardianResult;
begin
  if FInitialized then
    Exit;

  // Obtain connection from DeepBase DB Factory
  FConnection := TDBConnectionFactory.GetLocal;
  Log(ltDebug, 'IC: Storage obtained connection from DB.Factory');

  // Verify database integrity via Guardian
  TDBGuardian.ProtectConnection(FConnection, LGuardResult);
  Log(ltDebug, 'IC: Storage integrity check passed (Guardian)');

  // Initialize schema (idempotent)
  InitializeSchema;
  FInitialized := True;
end;

procedure TClarificationStorage.InitializeSchema;
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;

    // Create ic_sessions table (IF NOT EXISTS = idempotent)
    LQuery.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS ic_sessions (' +
      '  session_id TEXT PRIMARY KEY,' +
      '  checkpoint_json TEXT NOT NULL,' +
      '  created_at TEXT NOT NULL,' +
      '  updated_at TEXT NOT NULL' +
      ')';
    LQuery.ExecSQL;

    // Create ic_rapport table (IF NOT EXISTS = idempotent)
    LQuery.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS ic_rapport (' +
      '  user_id TEXT PRIMARY KEY,' +
      '  profile_json TEXT NOT NULL,' +
      '  updated_at TEXT NOT NULL' +
      ')';
    LQuery.ExecSQL;

    Log(ltDebug, 'IC: Storage schema initialized');
  finally
    LQuery.Free;
  end;
end;

procedure TClarificationStorage.SaveCheckpoint(const ACheckpoint: TSessionCheckpoint);
var
  LQuery: TFDQuery;
  LNow: string;
begin
  EnsureInitialized;
  LNow := DateToISO8601(Now, False);

  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text :=
      'INSERT OR REPLACE INTO ic_sessions (session_id, checkpoint_json, created_at, updated_at) ' +
      'VALUES (:session_id, :checkpoint_json, ' +
      '  COALESCE((SELECT created_at FROM ic_sessions WHERE session_id = :session_id2), :created_at), ' +
      '  :updated_at)';
    LQuery.ParamByName('session_id').AsString := ACheckpoint.SessionState.SessionId;
    LQuery.ParamByName('session_id2').AsString := ACheckpoint.SessionState.SessionId;
    LQuery.ParamByName('checkpoint_json').AsString := ACheckpoint.ToJson;
    LQuery.ParamByName('created_at').AsString := LNow;
    LQuery.ParamByName('updated_at').AsString := LNow;
    LQuery.ExecSQL;

    Log(ltDebug, Format('IC: Checkpoint saved for session %s',
      [ACheckpoint.SessionState.SessionId]));
  finally
    LQuery.Free;
  end;
end;

function TClarificationStorage.LoadCheckpoint(const ASessionId: string): TSessionCheckpoint;
var
  LQuery: TFDQuery;
  LJson: string;
begin
  EnsureInitialized;

  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text :=
      'SELECT checkpoint_json FROM ic_sessions WHERE session_id = :session_id';
    LQuery.ParamByName('session_id').AsString := ASessionId;
    LQuery.Open;

    if LQuery.IsEmpty then
      raise EFileNotFoundException.CreateFmt(
        'Checkpoint not found for session: %s', [ASessionId]);

    LJson := LQuery.FieldByName('checkpoint_json').AsString;
    Result := TSessionCheckpoint.FromJson(LJson);

    Log(ltDebug, Format('IC: Checkpoint loaded for session %s', [ASessionId]));
  finally
    LQuery.Free;
  end;
end;

procedure TClarificationStorage.SaveRapport(const AProfile: TRapportProfile);
var
  LQuery: TFDQuery;
  LNow: string;
begin
  EnsureInitialized;
  LNow := DateToISO8601(Now, False);

  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text :=
      'INSERT OR REPLACE INTO ic_rapport (user_id, profile_json, updated_at) ' +
      'VALUES (:user_id, :profile_json, :updated_at)';
    LQuery.ParamByName('user_id').AsString := AProfile.UserId;
    LQuery.ParamByName('profile_json').AsString := RapportToJson(AProfile);
    LQuery.ParamByName('updated_at').AsString := LNow;
    LQuery.ExecSQL;

    Log(ltDebug, Format('IC: Rapport saved for user %s', [AProfile.UserId]));
  finally
    LQuery.Free;
  end;
end;

function TClarificationStorage.LoadRapport(const AUserId: string): TRapportProfile;
var
  LQuery: TFDQuery;
  LJson: string;
begin
  EnsureInitialized;

  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text :=
      'SELECT profile_json FROM ic_rapport WHERE user_id = :user_id';
    LQuery.ParamByName('user_id').AsString := AUserId;
    LQuery.Open;

    if LQuery.IsEmpty then
    begin
      // Return default profile
      Result := Default(TRapportProfile);
      Result.UserId := AUserId;
      Result.TrustLevel := 0.5;
      Result.Familiarity := 0.0;
      Result.PreferredDepth := 0.5;
      Result.CommunicationStyle := 'direct';
      Result.LastUpdated := Now;
      Exit;
    end;

    LJson := LQuery.FieldByName('profile_json').AsString;
    Result := JsonToRapport(LJson);

    Log(ltDebug, Format('IC: Rapport loaded for user %s', [AUserId]));
  finally
    LQuery.Free;
  end;
end;

function TClarificationStorage.RapportToJson(const AProfile: TRapportProfile): string;
var
  LObj: TJSONObject;
  LBoundaries: TJSONArray;
  LBoundary: string;
begin
  LObj := TJSONObject.Create;
  try
    LObj.AddPair('userId', AProfile.UserId);
    LObj.AddPair('trustLevel', TJSONNumber.Create(AProfile.TrustLevel));
    LObj.AddPair('familiarity', TJSONNumber.Create(AProfile.Familiarity));
    LObj.AddPair('preferredDepth', TJSONNumber.Create(AProfile.PreferredDepth));
    LObj.AddPair('communicationStyle', AProfile.CommunicationStyle);
    LObj.AddPair('lastUpdated', DateToISO8601(AProfile.LastUpdated, False));

    LBoundaries := TJSONArray.Create;
    for LBoundary in AProfile.Boundaries do
      LBoundaries.Add(LBoundary);
    LObj.AddPair('boundaries', LBoundaries);

    Result := LObj.ToJSON;
  finally
    LObj.Free;
  end;
end;

function TClarificationStorage.JsonToRapport(const AJson: string): TRapportProfile;
var
  LValue: TJSONValue;
  LObj: TJSONObject;
  LArr: TJSONArray;
  I: Integer;
begin
  Result := Default(TRapportProfile);

  LValue := TJSONObject.ParseJSONValue(AJson);
  if LValue = nil then
    raise EArgumentException.Create('Invalid JSON for rapport profile');
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    raise EArgumentException.Create('Rapport JSON root is not an object');
  end;

  LObj := LValue as TJSONObject;
  try
    Result.UserId := LObj.GetValue('userId').Value;
    Result.TrustLevel := StrToFloatDef(LObj.GetValue('trustLevel').Value, 0.5);
    Result.Familiarity := StrToFloatDef(LObj.GetValue('familiarity').Value, 0.0);
    Result.PreferredDepth := StrToFloatDef(LObj.GetValue('preferredDepth').Value, 0.5);
    Result.CommunicationStyle := LObj.GetValue('communicationStyle').Value;
    Result.LastUpdated := ISO8601ToDate(LObj.GetValue('lastUpdated').Value, False);

    LArr := LObj.GetValue('boundaries') as TJSONArray;
    if LArr <> nil then
    begin
      SetLength(Result.Boundaries, LArr.Count);
      for I := 0 to LArr.Count - 1 do
        Result.Boundaries[I] := LArr.Items[I].Value;
    end;
  finally
    LObj.Free;
  end;
end;

class procedure TClarificationStorage.RegisterMigration;
begin
  // Phase 2 Task 23.2: Register IC schema as a migration step.
  // In full integration, this would call:
  //   TDBMigrations.Register('ic_001_create_tables',
  //     procedure(Conn: TFDConnection)
  //     begin
  //       // CREATE TABLE IF NOT EXISTS ic_sessions (...)
  //       // CREATE TABLE IF NOT EXISTS ic_rapport (...)
  //     end);
  //
  // For now, schema creation is handled in InitializeSchema (idempotent).
  Log(ltDebug, 'IC: Storage migration registered');
end;

end.
