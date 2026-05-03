unit UniBase.DB.Factory;

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  UniBase.DB.Pool;

type
  TDBConnectionFactory = class
  private
    class var FLocalDatabasePath: string;
    class var FRootPath: string;
    class var FLastError: string;

    class procedure EnsureConfigured; static;
    class function ResolveLocalPath(const Path: string): string; static;
    class function ReadSetting(Connection: TFDConnection; const Key: string;
      const Default: string = ''): string; static;
    class procedure WriteSetting(Connection: TFDConnection; const Key,
      Value: string); static;
    class function IsCredentialRef(const Value: string): Boolean; static;
    class function ExtractCredentialTarget(const CredentialRef: string): string; static;
    class function BuildCredentialRef(const TargetName: string): string; static;
    class function MakePgPasswordCredentialTarget: string; static;
    class function ResolveSharedPassword(Connection: TFDConnection;
      const StoredPassword: string): string; static;
    class procedure PingConnection(Connection: TFDConnection); static;
    class function CreateConnectionFromProfile(
      const Profile: TDBConnectionProfile; OpenConnection: Boolean): TFDConnection; static;
  public
    class procedure Configure(const LocalDatabasePath: string;
      const RootPath: string = ''); static;
    class procedure Reset; static;

    class function LoadLocalProfile: TDBConnectionProfile; static;
    class function LoadSharedProfile: TDBConnectionProfile; static;

    class function CreateLocalUnopenedConnection: TFDConnection; static;
    class function CreateSharedUnopenedConnection: TFDConnection; static;

    class function GetLocal: TFDConnection; static;
    class function GetShared: TFDConnection; static;
    class function VerifyBoth: Boolean; static;
    class function LastError: string; static;
  end;

implementation

uses
  System.IOUtils,
  System.StrUtils,
  FireDAC.Stan.Param,
  UniBase.Exceptions
  {$IFDEF MSWINDOWS}
  , UniBase.Security.DPAPI
  {$ENDIF};

const
  PG_PASSWORD_CREDENTIAL_REF_PREFIX = 'credman:';
  PG_PASSWORD_CREDENTIAL_TARGET = 'UniBase_DB3_PostgreSQL_Password';

class procedure TDBConnectionFactory.Configure(const LocalDatabasePath,
  RootPath: string);
begin
  FRootPath := RootPath;
  FLocalDatabasePath := ResolveLocalPath(LocalDatabasePath);
  FLastError := '';
end;

class procedure TDBConnectionFactory.Reset;
begin
  FLocalDatabasePath := '';
  FRootPath := '';
  FLastError := '';
end;

class procedure TDBConnectionFactory.EnsureConfigured;
begin
  if Trim(FLocalDatabasePath) = '' then
    raise EInvalidOperationException.Create(
      'TDBConnectionFactory.Configure must be called before use');
end;

class function TDBConnectionFactory.ResolveLocalPath(const Path: string): string;
begin
  if Trim(Path) = '' then
    Exit('');

  if TPath.IsPathRooted(Path) or (FRootPath = '') then
    Result := Path
  else
    Result := TPath.Combine(FRootPath, Path);
end;

class function TDBConnectionFactory.LoadLocalProfile: TDBConnectionProfile;
begin
  EnsureConfigured;
  Result := TDBConnectionProfile.SQLite(FLocalDatabasePath);
  Result.ApplicationName := ExtractFileName(ChangeFileExt(ParamStr(0), ''));
end;

class function TDBConnectionFactory.LoadSharedProfile: TDBConnectionProfile;
var
  ConfigConnection: TFDConnection;
  DBType: string;
  SharedDbPath: string;
  StoredPassword: string;
begin
  ConfigConnection := GetLocal;
  try
    DBType := ReadSetting(ConfigConnection, 'DB3.Type', 'PostgreSQL');

    if SameText(DBType, 'PostgreSQL') or SameText(DBType, 'PG') then
    begin
      StoredPassword := ReadSetting(ConfigConnection, 'DB3.Password', '');
      Result := TDBConnectionProfile.PostgreSQL(
        ReadSetting(ConfigConnection, 'DB3.Server', ''),
        ReadSetting(ConfigConnection, 'DB3.Database', ''),
        ReadSetting(ConfigConnection, 'DB3.User', ''),
        ResolveSharedPassword(ConfigConnection, StoredPassword),
        StrToIntDef(ReadSetting(ConfigConnection, 'DB3.Port', '5432'), 5432));

      Result.ApplicationName := ReadSetting(ConfigConnection,
        'DB3.ApplicationName', Result.ApplicationName);
      Result.SSLMode := ReadSetting(ConfigConnection, 'DB3.SSLMode',
        Result.SSLMode);
      Result.VendorLib := ReadSetting(ConfigConnection, 'DB3.VendorLib', '');
      Result.ExtraParams := ReadSetting(ConfigConnection, 'DB3.ExtraParams', '');
      Result.ConnectTimeoutSec := StrToIntDef(ReadSetting(ConfigConnection,
        'DB3.ConnectTimeoutSec', IntToStr(Result.ConnectTimeoutSec)),
        Result.ConnectTimeoutSec);
      Result.CommandTimeoutSec := StrToIntDef(ReadSetting(ConfigConnection,
        'DB3.CommandTimeoutSec', IntToStr(Result.CommandTimeoutSec)),
        Result.CommandTimeoutSec);
      Result.Validate;
      Exit;
    end;

    if SameText(DBType, 'SQLite') then
    begin
      SharedDbPath := ReadSetting(ConfigConnection, 'DB3.Database', '');
      if SharedDbPath = '' then
        SharedDbPath := ReadSetting(ConfigConnection, 'DB3.Path', '');
      SharedDbPath := ResolveLocalPath(SharedDbPath);

      Result := TDBConnectionProfile.SQLite(SharedDbPath);
      Result.ApplicationName := ReadSetting(ConfigConnection,
        'DB3.ApplicationName', Result.ApplicationName);
      Result.SQLiteLockingMode := ReadSetting(ConfigConnection,
        'DB3.SQLiteLockingMode', Result.SQLiteLockingMode);
      Result.SQLiteSynchronous := ReadSetting(ConfigConnection,
        'DB3.SQLiteSynchronous', Result.SQLiteSynchronous);
      Result.SQLiteJournalMode := ReadSetting(ConfigConnection,
        'DB3.SQLiteJournalMode', Result.SQLiteJournalMode);
      Result.SQLiteOpenMode := ReadSetting(ConfigConnection,
        'DB3.SQLiteOpenMode', Result.SQLiteOpenMode);
      Result.ExtraParams := ReadSetting(ConfigConnection, 'DB3.ExtraParams', '');
      Result.ConnectTimeoutSec := StrToIntDef(ReadSetting(ConfigConnection,
        'DB3.ConnectTimeoutSec', IntToStr(Result.ConnectTimeoutSec)),
        Result.ConnectTimeoutSec);
      Result.CommandTimeoutSec := StrToIntDef(ReadSetting(ConfigConnection,
        'DB3.CommandTimeoutSec', IntToStr(Result.CommandTimeoutSec)),
        Result.CommandTimeoutSec);
      Result.Validate;
      Exit;
    end;

    raise EDatabaseException.CreateFmt(
      'Unsupported shared database type in DB3.Type: %s', [DBType]);
  finally
    ConfigConnection.Free;
  end;
end;

class function TDBConnectionFactory.CreateConnectionFromProfile(
  const Profile: TDBConnectionProfile; OpenConnection: Boolean): TFDConnection;
var
  Pool: TUniConnectionPool;
begin
  Pool := TUniConnectionPool.Create;
  try
    Pool.Configure(Profile);
    Result := Pool.CreateUnopenedConnection;
    try
      if OpenConnection then
        Result.Open;
    except
      Result.Free;
      raise;
    end;
  finally
    Pool.Free;
  end;
end;

class function TDBConnectionFactory.CreateLocalUnopenedConnection: TFDConnection;
begin
  Result := CreateConnectionFromProfile(LoadLocalProfile, False);
end;

class function TDBConnectionFactory.CreateSharedUnopenedConnection: TFDConnection;
begin
  Result := CreateConnectionFromProfile(LoadSharedProfile, False);
end;

class function TDBConnectionFactory.GetLocal: TFDConnection;
begin
  Result := CreateConnectionFromProfile(LoadLocalProfile, True);
end;

class function TDBConnectionFactory.GetShared: TFDConnection;
begin
  Result := CreateConnectionFromProfile(LoadSharedProfile, True);
end;

class function TDBConnectionFactory.ReadSetting(Connection: TFDConnection;
  const Key, Default: string): string;
var
  Query: TFDQuery;
begin
  Result := Default;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text := 'SELECT Value FROM Settings WHERE Key = :Key';
    Query.ParamByName('Key').AsString := Key;
    Query.Open;
    if not Query.Eof then
      Result := Query.FieldByName('Value').AsString;
  finally
    Query.Free;
  end;
end;

class procedure TDBConnectionFactory.WriteSetting(Connection: TFDConnection;
  const Key, Value: string);
var
  Query: TFDQuery;
begin
  if not Assigned(Connection) or not Connection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text := 'UPDATE Settings SET Value = :Value WHERE Key = :Key';
    Query.ParamByName('Value').AsString := Value;
    Query.ParamByName('Key').AsString := Key;
    Query.ExecSQL;

    if Query.RowsAffected = 0 then
    begin
      Query.SQL.Text :=
        'INSERT INTO Settings (Key, Value) VALUES (:Key, :Value)';
      Query.ParamByName('Key').AsString := Key;
      Query.ParamByName('Value').AsString := Value;
      Query.ExecSQL;
    end;
  finally
    Query.Free;
  end;
end;

class function TDBConnectionFactory.IsCredentialRef(const Value: string): Boolean;
begin
  Result := StartsText(PG_PASSWORD_CREDENTIAL_REF_PREFIX, Trim(Value));
end;

class function TDBConnectionFactory.ExtractCredentialTarget(
  const CredentialRef: string): string;
begin
  Result := '';
  if IsCredentialRef(CredentialRef) then
    Result := Copy(Trim(CredentialRef),
      Length(PG_PASSWORD_CREDENTIAL_REF_PREFIX) + 1, MaxInt);
end;

class function TDBConnectionFactory.BuildCredentialRef(
  const TargetName: string): string;
begin
  if TargetName = '' then
    Result := ''
  else
    Result := PG_PASSWORD_CREDENTIAL_REF_PREFIX + TargetName;
end;

class function TDBConnectionFactory.MakePgPasswordCredentialTarget: string;
begin
  Result := PG_PASSWORD_CREDENTIAL_TARGET;
end;

class function TDBConnectionFactory.ResolveSharedPassword(
  Connection: TFDConnection; const StoredPassword: string): string;
var
  TargetName: string;
  PlainPassword: string;
begin
  Result := StoredPassword;
  if Result = '' then
    Exit;

  if IsCredentialRef(Result) then
  begin
    TargetName := ExtractCredentialTarget(Result);
    if TargetName = '' then
      Exit('');
    {$IFDEF MSWINDOWS}
    Result := TCredentialManager.GetCredential(TargetName, '');
    {$ELSE}
    Result := '';
    {$ENDIF}
    Exit;
  end;

  {$IFDEF MSWINDOWS}
  TargetName := MakePgPasswordCredentialTarget;
  PlainPassword := Result;
  try
    TCredentialManager.SaveCredential(TargetName, '', PlainPassword);
    WriteSetting(Connection, 'DB3.Password', BuildCredentialRef(TargetName));
  except
    // Keep backward-compatible plaintext fallback when Credential Manager fails.
  end;
  Result := PlainPassword;
  {$ENDIF}
end;

class procedure TDBConnectionFactory.PingConnection(Connection: TFDConnection);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text := 'SELECT 1';
    Query.Open;
  finally
    Query.Free;
  end;
end;

class function TDBConnectionFactory.VerifyBoth: Boolean;
var
  LocalConnection: TFDConnection;
  SharedConnection: TFDConnection;
begin
  FLastError := '';
  try
    LocalConnection := GetLocal;
    try
      PingConnection(LocalConnection);
    finally
      LocalConnection.Free;
    end;

    SharedConnection := GetShared;
    try
      PingConnection(SharedConnection);
    finally
      SharedConnection.Free;
    end;

    Result := True;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      Result := False;
    end;
  end;
end;

class function TDBConnectionFactory.LastError: string;
begin
  Result := FLastError;
end;

end.
