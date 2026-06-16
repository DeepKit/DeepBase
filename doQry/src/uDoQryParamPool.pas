unit uDoQryParamPool;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  FireDAC.Comp.Client, Data.DB,
  uDoQryTypes;

const
  ///  <summary>Cache TTL in seconds. After this elapses the entry is evicted
  ///  and reloaded from the database on next access.</summary>
  TTLSeconds = 300; // 5 minutes

function GetQueryDef(const Ctx: TDoQryContext; const ProcName: string;
  ForceReload: Boolean = False): TQueryDef;
procedure InvalidateQueryDef(const ProcName: string); overload;
procedure InvalidateAll;

implementation

uses
  System.DateUtils;

type
  TCacheEntry = record
    Def: TQueryDef;
    CachedAt: TDateTime;
  end;

var
  GCache: TDictionary<string, TCacheEntry>;
  GLock: TObject;

function KeyOf(const DBType: TDBType; const DBId, ProcName: string): string;
begin
  case DBType of
    dbPostgreSQL: Result := 'pg|' + DBId + '|' + ProcName;
    dbSQLite:     Result := 'sqlite|' + DBId + '|' + ProcName;
  end;
end;

function SafeFieldStr(Q: TFDQuery; const Name: string; const Def: string): string;
var F: TField;
begin
  F := Q.FindField(Name);
  if F <> nil then Result := F.AsString else Result := Def;
end;

function SafeFieldInt(Q: TFDQuery; const Name: string; const Def: Integer): Integer;
var F: TField;
begin
  F := Q.FindField(Name);
  if F <> nil then Result := F.AsInteger else Result := Def;
end;

function SafeFieldBool(Q: TFDQuery; const Name: string; const Def: Boolean): Boolean;
var F: TField;
begin
  F := Q.FindField(Name);
  if F <> nil then Result := F.AsBoolean else Result := Def;
end;

function SafeFieldDateTime(Q: TFDQuery; const Name: string; const Def: TDateTime): TDateTime;
var F: TField;
begin
  F := Q.FindField(Name);
  if F <> nil then
  begin
    try
      Result := F.AsDateTime;
    except
      Result := Def;
    end;
  end
  else
    Result := Def;
end;

///  <summary>Builds a database identifier from the connection. Prefers
///  <c>ConnectionName</c>; falls back to <c>DatabaseName</c>; last resort is
///  the raw connection string.</summary>
function DBIdOf(Conn: TFDConnection): string;
begin
  if Conn = nil then
    Exit('');
  Result := Conn.ConnectionName;
  if Result <> '' then
    Exit;
  Result := Conn.Params.Database;
  if Result <> '' then
    Exit;
  Result := Conn.ConnectionString;
end;

function LoadQueryDef(const Ctx: TDoQryContext; const ProcName: string): TQueryDef;
var
  Q: TFDQuery;
begin
  Result := Default(TQueryDef);
  Result.ProcName := ProcName;
  Result.TimeoutSec := Ctx.TimeoutSec;
  Result.DefaultLimit := 1000;
  Result.AllowFullScan := False;
  Result.IdField := 'id';
  Result.Version := 0;
  Result.UpdatedAt := 0;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Ctx.Connection;
    Q.SQL.Text := 'SELECT * FROM queries WHERE proc_name = :p';
    Q.ParamByName('p').AsString := ProcName;
    Q.Open;
    if not Q.IsEmpty then
    begin
      Result.SQLTemplate := SafeFieldStr(Q, 'sql_template', SafeFieldStr(Q, 'sql', ''));
      Result.ParamSchemaJson := SafeFieldStr(Q, 'param_schema_json', '');
      Result.TimeoutSec := SafeFieldInt(Q, 'timeout_sec', Result.TimeoutSec);
      Result.DefaultLimit := SafeFieldInt(Q, 'default_limit', Result.DefaultLimit);
      Result.AllowFullScan := SafeFieldBool(Q, 'allow_full_scan', Result.AllowFullScan);
      Result.IdField := SafeFieldStr(Q, 'id_field', Result.IdField);
      Result.Version := SafeFieldInt(Q, 'version', 0);
      Result.UpdatedAt := SafeFieldDateTime(Q, 'updated_at', 0);
    end;
  finally
    Q.Free;
  end;
end;

///  <summary>Lightweight version probe — fetches only the version and
///  updated_at for a given proc_name. Returns True when the row exists.</summary>
function ProbeVersion(const Ctx: TDoQryContext; const ProcName: string;
  out Version: Integer; out UpdatedAt: TDateTime): Boolean;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Ctx.Connection;
    Q.SQL.Text := 'SELECT version, updated_at FROM queries WHERE proc_name = :p';
    Q.ParamByName('p').AsString := ProcName;
    Q.Open;
    if not Q.IsEmpty then
    begin
      Version := SafeFieldInt(Q, 'version', 0);
      UpdatedAt := SafeFieldDateTime(Q, 'updated_at', 0);
      Result := True;
    end
    else
    begin
      Version := 0;
      UpdatedAt := 0;
      Result := False;
    end;
  finally
    Q.Free;
  end;
end;

function GetQueryDef(const Ctx: TDoQryContext; const ProcName: string;
  ForceReload: Boolean): TQueryDef;
var
  K: string;
  Entry: TCacheEntry;
  DBId: string;
  RemoteVersion: Integer;
  RemoteUpdatedAt: TDateTime;
  HaveCachedEntry: Boolean;
begin
  DBId := DBIdOf(Ctx.Connection);
  K := KeyOf(Ctx.DBType, DBId, ProcName);

  // --- Step 1: read cached entry under lock (no DB call) ------------------
  HaveCachedEntry := False;
  if not ForceReload then
  begin
    TMonitor.Enter(GLock);
    try
      if (GCache <> nil) and GCache.TryGetValue(K, Entry) then
        HaveCachedEntry := True;
    finally
      TMonitor.Exit(GLock);
    end;
  end;

  // --- Step 2: validate cached entry outside the lock ---------------------
  if HaveCachedEntry then
  begin
    // TTL expired?
    if SecondsBetween(Now, Entry.CachedAt) > TTLSeconds then
      HaveCachedEntry := False;

    if HaveCachedEntry then
    begin
      // Lightweight version probe (DB call — must NOT hold GLock)
      if ProbeVersion(Ctx, ProcName, RemoteVersion, RemoteUpdatedAt) then
      begin
        if (RemoteVersion = Entry.Def.Version) and
           (RemoteUpdatedAt = Entry.Def.UpdatedAt) then
          Exit(Entry.Def) // still fresh
        // else: version changed — fall through to reload
      end
      else
      begin
        // Row disappeared — evict
        TMonitor.Enter(GLock);
        try
          if GCache <> nil then
            GCache.Remove(K);
        finally
          TMonitor.Exit(GLock);
        end;
      end;
    end;
  end;

  // --- Step 3: slow path — load from DB -----------------------------------
  Result := LoadQueryDef(Ctx, ProcName);
  Entry.Def := Result;
  Entry.CachedAt := Now;
  TMonitor.Enter(GLock);
  try
    if GCache = nil then
      GCache := TDictionary<string, TCacheEntry>.Create;
    GCache.AddOrSetValue(K, Entry);
  finally
    TMonitor.Exit(GLock);
  end;
end;

procedure InvalidateQueryDef(const ProcName: string);
var
  Keys: TArray<string>;
  K: string;
begin
  TMonitor.Enter(GLock);
  try
    if GCache = nil then Exit;
    Keys := GCache.Keys.ToArray;
    for K in Keys do
      if K.EndsWith('|' + ProcName) then
        GCache.Remove(K);
  finally
    TMonitor.Exit(GLock);
  end;
end;

procedure InvalidateAll;
begin
  TMonitor.Enter(GLock);
  try
    FreeAndNil(GCache);
  finally
    TMonitor.Exit(GLock);
  end;
end;

initialization
  GCache := nil;
  GLock := TObject.Create;

finalization
  InvalidateAll;
  FreeAndNil(GLock);

end.
