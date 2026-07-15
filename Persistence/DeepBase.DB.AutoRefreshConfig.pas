unit DeepBase.DB.AutoRefreshConfig;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  DeepBase.Interfaces;

type
  TAutoRefreshConfigOptions = record
    TableName: string;
    SectionColumn: string;
    KeyColumn: string;
    ValueColumn: string;
    UpdatedAtColumn: string;
    AutoEnsureSchema: Boolean;

    class function Default: TAutoRefreshConfigOptions; static;
    procedure Validate;
  end;

  /// <summary>
  /// 自动刷新配置读取器。从数据库表读取 key/value 配置并缓存，
  /// 当底层 updated_at 变化时自动重新加载缓存。
  /// </summary>
  /// <remarks>
  /// <para>DATA2-056 修复：FConnection 可能是调用方共享的 TFDConnection 实例，
  /// TFDConnection 不是线程安全的。因此所有对 FConnection 的访问（包括 Open、
  /// ExecSQL、Query）都通过 FLock 序列化。对于周期性刷新场景（每 N 秒轮询一次），
  /// 锁争用可以忽略不计。</para>
  /// <para>如果 FConnectionProvider 返回每次调用独立的连接（例如连接池），
  /// 则 FLock 只保护缓存字典；否则 FLock 同时保护连接和缓存。</para>
  /// </remarks>
  TAutoRefreshConfig = class(TInterfacedObject, IAutoRefreshConfig)
  private
    /// <summary>
    /// 共享的数据库连接。当通过 Create(AConnection) 构造时，此字段指向
    /// 调用方传入的连接，可能被多线程共享。所有访问必须通过 FLock 序列化。
    /// </summary>
    FConnection: TFDConnection;
    /// <summary>
    /// 连接提供者。如果非 nil，每次 AcquireConnection 会调用它获取一个独立连接，
    /// 调用方负责释放。此时 FLock 不保护连接本身（每次都是新的），只保护缓存。
    /// </summary>
    FConnectionProvider: TFunc<TFDConnection>;
    FOptions: TAutoRefreshConfigOptions;
    /// <summary>
    /// 序列化所有对 FConnection（共享模式）和 FCache/FLoaded/FLastChangeToken 的访问。
    /// TCriticalSection 是可重入的（同一线程可多次 Enter），因此内部调用可嵌套加锁。
    /// </summary>
    FLock: TCriticalSection;
    FCache: TDictionary<string, string>;
    FLoaded: Boolean;
    FSchemaEnsured: Boolean;
    FLastChangeToken: string;

    class function MakeCacheKey(const Section, Key: string): string; static;
    class function IsPostgreSQL(Connection: TFDConnection): Boolean; static;
    class procedure ValidateIdentifier(const Identifier, Subject: string); static;
    class procedure ValidateQualifiedIdentifier(const Identifier,
      Subject: string); static;

    /// <summary>
    /// 获取数据库连接。若使用 ConnectionProvider，返回新连接（MustFree=True）；
    /// 否则返回共享的 FConnection（MustFree=False，不要释放）。
    /// </summary>
    function AcquireConnection(out MustFree: Boolean): TFDConnection;
    /// <summary>确保连接已打开。调用方必须持有 FLock。</summary>
    procedure EnsureConnectionOpen(Connection: TFDConnection);
    /// <summary>确保 schema 存在。调用方必须持有 FLock。</summary>
    procedure EnsureSchema(Connection: TFDConnection);
    /// <summary>读取变更令牌（MAX(updated_at)）。调用方必须持有 FLock。</summary>
    function ReadChangeToken(Connection: TFDConnection): string;
    /// <summary>重新加载缓存。调用方必须持有 FLock。</summary>
    procedure ReloadCache(Connection: TFDConnection;
      const ChangeToken: string);
    /// <summary>
    /// 确保缓存是最新的。所有 FConnection 访问都在 FLock 内完成。
    /// 调用方不需要持有 FLock（本方法内部会加锁）。
    /// </summary>
    procedure EnsureCacheFresh;
  public
    constructor Create(AConnection: TFDConnection); overload;
    constructor Create(AConnection: TFDConnection;
      const Options: TAutoRefreshConfigOptions); overload;
    constructor Create(const ConnectionProvider: TFunc<TFDConnection>); overload;
    constructor Create(const ConnectionProvider: TFunc<TFDConnection>;
      const Options: TAutoRefreshConfigOptions); overload;
    destructor Destroy; override;

    class function CreateLocal: IAutoRefreshConfig; overload; static;
    class function CreateLocal(
      const Options: TAutoRefreshConfigOptions): IAutoRefreshConfig; overload; static;
    class function CreateShared: IAutoRefreshConfig; overload; static;
    class function CreateShared(
      const Options: TAutoRefreshConfigOptions): IAutoRefreshConfig; overload; static;

    function GetValue(const ASection, AKey, ADefault: string): string;
    function GetInt(const ASection, AKey: string; ADefault: Integer): Integer;
    function GetBool(const ASection, AKey: string; ADefault: Boolean): Boolean;
    procedure ClearCache;
  end;

implementation

uses
  FireDAC.Stan.Param,
  DeepBase.DB.Factory,
  DeepBase.Exceptions;

{ TAutoRefreshConfigOptions }

class function TAutoRefreshConfigOptions.Default: TAutoRefreshConfigOptions;
begin
  Result.TableName := 'pg_config';
  Result.SectionColumn := 'section_name';
  Result.KeyColumn := 'config_key';
  Result.ValueColumn := 'config_value';
  Result.UpdatedAtColumn := 'updated_at';
  Result.AutoEnsureSchema := True;
end;

procedure TAutoRefreshConfigOptions.Validate;
begin
  TAutoRefreshConfig.ValidateQualifiedIdentifier(TableName, 'config table name');
  TAutoRefreshConfig.ValidateIdentifier(SectionColumn, 'section column');
  TAutoRefreshConfig.ValidateIdentifier(KeyColumn, 'key column');
  TAutoRefreshConfig.ValidateIdentifier(ValueColumn, 'value column');
  TAutoRefreshConfig.ValidateIdentifier(UpdatedAtColumn, 'updated_at column');
end;

{ TAutoRefreshConfig }

constructor TAutoRefreshConfig.Create(AConnection: TFDConnection);
begin
  Create(AConnection, TAutoRefreshConfigOptions.Default);
end;

constructor TAutoRefreshConfig.Create(AConnection: TFDConnection;
  const Options: TAutoRefreshConfigOptions);
begin
  inherited Create;
  if not Assigned(AConnection) then
    raise EInvalidOperationException.Create('Auto refresh config connection cannot be nil');

  FConnection := AConnection;
  FOptions := Options;
  FOptions.Validate;
  FLock := TCriticalSection.Create;
  FCache := TDictionary<string, string>.Create;
end;

constructor TAutoRefreshConfig.Create(
  const ConnectionProvider: TFunc<TFDConnection>);
begin
  Create(ConnectionProvider, TAutoRefreshConfigOptions.Default);
end;

constructor TAutoRefreshConfig.Create(
  const ConnectionProvider: TFunc<TFDConnection>;
  const Options: TAutoRefreshConfigOptions);
begin
  inherited Create;
  if not Assigned(ConnectionProvider) then
    raise EInvalidOperationException.Create('Auto refresh config provider returned nil connection');

  FConnectionProvider := ConnectionProvider;
  FOptions := Options;
  FOptions.Validate;
  FLock := TCriticalSection.Create;
  FCache := TDictionary<string, string>.Create;
end;

destructor TAutoRefreshConfig.Destroy;
begin
  FreeAndNil(FCache);
  FreeAndNil(FLock);
  inherited;
end;

class function TAutoRefreshConfig.CreateLocal: IAutoRefreshConfig;
begin
  Result := CreateLocal(TAutoRefreshConfigOptions.Default);
end;

class function TAutoRefreshConfig.CreateLocal(
  const Options: TAutoRefreshConfigOptions): IAutoRefreshConfig;
begin
  Result := TAutoRefreshConfig.Create(
    function: TFDConnection
    begin
      Result := TDBConnectionFactory.GetLocal;
    end,
    Options);
end;

class function TAutoRefreshConfig.CreateShared: IAutoRefreshConfig;
begin
  Result := CreateShared(TAutoRefreshConfigOptions.Default);
end;

class function TAutoRefreshConfig.CreateShared(
  const Options: TAutoRefreshConfigOptions): IAutoRefreshConfig;
begin
  Result := TAutoRefreshConfig.Create(
    function: TFDConnection
    begin
      Result := TDBConnectionFactory.GetShared;
    end,
    Options);
end;

class function TAutoRefreshConfig.MakeCacheKey(const Section,
  Key: string): string;
begin
  Result := Trim(Section).ToLowerInvariant + #31 + Trim(Key).ToLowerInvariant;
end;

class function TAutoRefreshConfig.IsPostgreSQL(
  Connection: TFDConnection): Boolean;
var
  DriverName: string;
begin
  DriverName := Connection.DriverName;
  if DriverName = '' then
    DriverName := Connection.Params.Values['DriverID'];

  Result := SameText(DriverName, 'PG') or SameText(DriverName, 'PostgreSQL');
end;

class procedure TAutoRefreshConfig.ValidateIdentifier(const Identifier,
  Subject: string);
var
  I: Integer;
  Ch: Char;
begin
  if Trim(Identifier) = '' then
    raise EInvalidOperationException.CreateFmt('%s cannot be empty', [Subject]);

  for I := 1 to Length(Identifier) do
  begin
    Ch := Identifier[I];
    if I = 1 then
    begin
      if not CharInSet(Ch, ['A'..'Z', 'a'..'z', '_']) then
        raise EInvalidOperationException.CreateFmt('Invalid %s: %s',
          [Subject, Identifier]);
    end
    else if not CharInSet(Ch, ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      raise EInvalidOperationException.CreateFmt('Invalid %s: %s',
        [Subject, Identifier]);
  end;
end;

class procedure TAutoRefreshConfig.ValidateQualifiedIdentifier(
  const Identifier, Subject: string);
var
  Part: string;
  Parts: TArray<string>;
begin
  Parts := Identifier.Split(['.']);
  if Length(Parts) = 0 then
    raise EInvalidOperationException.CreateFmt('%s cannot be empty', [Subject]);

  for Part in Parts do
    ValidateIdentifier(Part, Subject);
end;

function TAutoRefreshConfig.AcquireConnection(out MustFree: Boolean): TFDConnection;
begin
  MustFree := False;
  if Assigned(FConnectionProvider) then
  begin
    Result := FConnectionProvider();
    MustFree := True;
  end
  else
    Result := FConnection;

  if not Assigned(Result) then
    raise EDatabaseException.Create('Auto refresh config provider returned nil connection');
end;

{ 调用方必须持有 FLock }
procedure TAutoRefreshConfig.EnsureConnectionOpen(Connection: TFDConnection);
begin
  if not Connection.Connected then
    Connection.Open;
end;

{ 调用方必须持有 FLock }
procedure TAutoRefreshConfig.EnsureSchema(Connection: TFDConnection);
var
  SQLText: string;
begin
  if IsPostgreSQL(Connection) then
    SQLText := Format(
      'CREATE TABLE IF NOT EXISTS %s (' +
      '%s VARCHAR(128) NOT NULL, ' +
      '%s VARCHAR(256) NOT NULL, ' +
      '%s TEXT NOT NULL, ' +
      '%s TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, ' +
      'PRIMARY KEY (%s, %s))',
      [FOptions.TableName,
       FOptions.SectionColumn,
       FOptions.KeyColumn,
       FOptions.ValueColumn,
       FOptions.UpdatedAtColumn,
       FOptions.SectionColumn,
       FOptions.KeyColumn])
  else
    SQLText := Format(
      'CREATE TABLE IF NOT EXISTS %s (' +
      '%s TEXT NOT NULL, ' +
      '%s TEXT NOT NULL, ' +
      '%s TEXT NOT NULL, ' +
      '%s TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, ' +
      'PRIMARY KEY (%s, %s))',
      [FOptions.TableName,
       FOptions.SectionColumn,
       FOptions.KeyColumn,
       FOptions.ValueColumn,
       FOptions.UpdatedAtColumn,
       FOptions.SectionColumn,
       FOptions.KeyColumn]);

  Connection.ExecSQL(SQLText);
end;

{ 调用方必须持有 FLock }
function TAutoRefreshConfig.ReadChangeToken(
  Connection: TFDConnection): string;
var
  Query: TFDQuery;
begin
  Result := '';
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text := Format('SELECT MAX(%s) AS change_token FROM %s',
      [FOptions.UpdatedAtColumn, FOptions.TableName]);
    Query.Open;
    if not Query.Eof and not Query.FieldByName('change_token').IsNull then
      Result := Query.FieldByName('change_token').AsString;
  finally
    Query.Free;
  end;
end;

{ 调用方必须持有 FLock }
procedure TAutoRefreshConfig.ReloadCache(Connection: TFDConnection;
  const ChangeToken: string);
var
  Query: TFDQuery;
begin
  FCache.Clear;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text := Format('SELECT %s, %s, %s FROM %s',
      [FOptions.SectionColumn,
       FOptions.KeyColumn,
       FOptions.ValueColumn,
       FOptions.TableName]);
    Query.Open;
    while not Query.Eof do
    begin
      FCache.AddOrSetValue(
        MakeCacheKey(Query.Fields[0].AsString, Query.Fields[1].AsString),
        Query.Fields[2].AsString);
      Query.Next;
    end;
  finally
    Query.Free;
  end;

  FLastChangeToken := ChangeToken;
  FLoaded := True;
end;

{ DATA2-056: 所有 FConnection 访问都在 FLock 内完成。
  对于共享连接模式（无 ConnectionProvider），这意味着连接操作被序列化，
  可能影响性能；但对于配置读取的低频场景（周期性轮询），影响可以忽略。 }
procedure TAutoRefreshConfig.EnsureCacheFresh;
var
  Connection: TFDConnection;
  MustFree: Boolean;
  ChangeToken: string;
begin
  FLock.Enter;
  try
    Connection := AcquireConnection(MustFree);
    try
      EnsureConnectionOpen(Connection);
      if FOptions.AutoEnsureSchema and not FSchemaEnsured then
      begin
        EnsureSchema(Connection);
        FSchemaEnsured := True;
      end;

      ChangeToken := ReadChangeToken(Connection);
      if (not FLoaded) or (ChangeToken <> FLastChangeToken) then
        ReloadCache(Connection, ChangeToken);
    finally
      if MustFree then
        Connection.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

{ DATA2-056: GetValue 先在 FLock 下刷新缓存，再在同一个锁持有期内读取值。
  TCriticalSection 可重入，所以 EnsureCacheFresh 的内层 Enter 是安全的。 }
function TAutoRefreshConfig.GetValue(const ASection, AKey,
  ADefault: string): string;
var
  Value: string;
begin
  Result := ADefault;
  EnsureCacheFresh;
  FLock.Enter;
  try
    if FCache.TryGetValue(MakeCacheKey(ASection, AKey), Value) then
      Result := Value;
  finally
    FLock.Leave;
  end;
end;

function TAutoRefreshConfig.GetInt(const ASection, AKey: string;
  ADefault: Integer): Integer;
begin
  Result := StrToIntDef(GetValue(ASection, AKey, IntToStr(ADefault)), ADefault);
end;

function TAutoRefreshConfig.GetBool(const ASection, AKey: string;
  ADefault: Boolean): Boolean;
var
  Value: string;
begin
  Value := Trim(GetValue(ASection, AKey, ''));
  if Value = '' then
    Exit(ADefault);

  if SameText(Value, 'true') or SameText(Value, '1') or
     SameText(Value, 'yes') or SameText(Value, 'y') or
     SameText(Value, 'on') then
    Exit(True);

  if SameText(Value, 'false') or SameText(Value, '0') or
     SameText(Value, 'no') or SameText(Value, 'n') or
     SameText(Value, 'off') then
    Exit(False);

  Result := ADefault;
end;

procedure TAutoRefreshConfig.ClearCache;
begin
  FLock.Enter;
  try
    FCache.Clear;
    FLoaded := False;
    FLastChangeToken := '';
  finally
    FLock.Leave;
  end;
end;

end.
