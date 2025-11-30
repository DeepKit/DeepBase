unit uDoQryParamPool;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  FireDAC.Comp.Client, Data.DB,
  uDoQryTypes;

function GetQueryDef(const Ctx: TDoQryContext; const ProcName: string): TQueryDef;
procedure InvalidateQueryDef(const ProcName: string); overload;
procedure InvalidateAll;

implementation

var
  GCache: TDictionary<string, TQueryDef>;
  GLock: TObject;

function KeyOf(const DBType: TDBType; const ProcName: string): string;
begin
  case DBType of
    dbPostgreSQL: Result := 'pg|'+ProcName;
    dbSQLite: Result := 'sqlite|'+ProcName;
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

function LoadQueryDef(const Ctx: TDoQryContext; const ProcName: string): TQueryDef;
var
  Q: TFDQuery;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.ProcName := ProcName;
  Result.TimeoutSec := Ctx.TimeoutSec;
  Result.DefaultLimit := 1000;
  Result.AllowFullScan := False;
  Result.IdField := 'id';
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
    end;
  finally
    Q.Free;
  end;
end;

function GetQueryDef(const Ctx: TDoQryContext; const ProcName: string): TQueryDef;
var
  K: string;
  V: TQueryDef;
begin
  K := KeyOf(Ctx.DBType, ProcName);
  TMonitor.Enter(GLock);
  try
    if (GCache <> nil) and GCache.TryGetValue(K, V) then
      Exit(V);
  finally
    TMonitor.Exit(GLock);
  end;
  V := LoadQueryDef(Ctx, ProcName);
  TMonitor.Enter(GLock);
  try
    if GCache = nil then
      GCache := TDictionary<string, TQueryDef>.Create;
    GCache.AddOrSetValue(K, V);
  finally
    TMonitor.Exit(GLock);
  end;
  Result := V;
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
      if K.EndsWith('|'+ProcName) then
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
