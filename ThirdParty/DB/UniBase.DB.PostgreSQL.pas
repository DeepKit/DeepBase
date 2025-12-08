unit UniBase.DB.PostgreSQL;

{*******************************************************************************
  UniBase PostgreSQL Driver Adapter
  
  PostgreSQL specific features:
    - JSONB support
    - Array types
    - LISTEN/NOTIFY
    - Full-text search (tsvector/tsquery)
    - Connection pooling
    - SSL/TLS connection
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  FireDAC.Comp.Client, FireDAC.Phys.PG, FireDAC.Stan.Def,
  FireDAC.Stan.Async, FireDAC.Stan.Pool,
  UniBase.DB.DoQry;

type
  TPgSSLMode = (sslDisable, sslAllow, sslPrefer, sslRequire, sslVerifyCA, sslVerifyFull);
  
  TPgNotifyEvent = procedure(Sender: TObject; const AChannel, APayload: string) of object;

  TPgConnectionParams = record
    Host: string;
    Port: Integer;
    Database: string;
    Username: string;
    Password: string;
    SSLMode: TPgSSLMode;
    SSLCert: string;
    SSLKey: string;
    SSLRootCert: string;
    ApplicationName: string;
    ConnectTimeout: Integer;
    CommandTimeout: Integer;
    Pooled: Boolean;
    PoolSize: Integer;
    
    class function Default: TPgConnectionParams; static;
    function ToConnectionString: string;
  end;

  TPgJsonb = record
  private
    FValue: string;
  public
    class function Create(const AJson: string): TPgJsonb; static;
    class function FromObject(AObj: TObject): TPgJsonb; static;
    
    function AsString: string;
    function AsObject<T: class>: T;
    function Path(const APath: string): TPgJsonb;
    function Contains(const AJson: string): Boolean;
    function ContainsKey(const AKey: string): Boolean;
    
    class operator Implicit(const AValue: string): TPgJsonb;
    class operator Implicit(const AValue: TPgJsonb): string;
  end;

  TPgArray<T> = record
  private
    FItems: TArray<T>;
  public
    class function Create(const AItems: TArray<T>): TPgArray<T>; static;
    
    function ToArray: TArray<T>;
    function Contains(const AValue: T): Boolean;
    function Overlaps(const AOther: TPgArray<T>): Boolean;
    function ToString: string;
    
    class operator Implicit(const AItems: TArray<T>): TPgArray<T>;
  end;

  TPgFullTextQuery = record
  private
    FQuery: string;
    FConfig: string;
  public
    class function Create(const AQuery: string; const AConfig: string = 'english'): TPgFullTextQuery; static;
    class function PlainTo(const AText: string; const AConfig: string = 'english'): TPgFullTextQuery; static;
    class function PhraseTo(const APhrase: string; const AConfig: string = 'english'): TPgFullTextQuery; static;
    class function WebSearch(const AQuery: string; const AConfig: string = 'english'): TPgFullTextQuery; static;
    
    function ToString: string;
    function ToSql: string;
  end;

  TPostgreSQLDriver = class
  private
    FConnection: TFDConnection;
    FParams: TPgConnectionParams;
    FOnNotify: TPgNotifyEvent;
    FListenChannels: TList<string>;
    
    procedure SetupConnection;
    procedure HandleNotify(AMessage: TFDPhysPgEventMessage);
  public
    constructor Create(const AParams: TPgConnectionParams); overload;
    constructor Create(const AHost, ADatabase, AUsername, APassword: string); overload;
    destructor Destroy; override;
    
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;
    
    // Query execution
    function Query(const ASQL: string): TFDQuery;
    function Execute(const ASQL: string): Integer;
    function ExecuteScalar<T>(const ASQL: string): T;
    
    // JSONB operations
    function JsonbSet(const ATable, AColumn, APath, AValue: string; AId: Integer): Boolean;
    function JsonbRemove(const ATable, AColumn, APath: string; AId: Integer): Boolean;
    function JsonbConcat(const ATable, AColumn, AJson: string; AId: Integer): Boolean;
    
    // Array operations
    function ArrayAppend<T>(const ATable, AColumn: string; AValue: T; AId: Integer): Boolean;
    function ArrayRemove<T>(const ATable, AColumn: string; AValue: T; AId: Integer): Boolean;
    function ArrayContains<T>(const ATable, AColumn: string; AValue: T; AId: Integer): Boolean;
    
    // Full-text search
    function FullTextSearch(const ATable, AColumn, AQuery: string; 
      const AConfig: string = 'english'): TFDQuery;
    function FullTextRank(const ATable, AColumn, AQuery: string;
      const AConfig: string = 'english'): TFDQuery;
    
    // LISTEN/NOTIFY
    procedure Listen(const AChannel: string);
    procedure Unlisten(const AChannel: string);
    procedure Notify(const AChannel: string; const APayload: string = '');
    
    // Transactions
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    function InTransaction: Boolean;
    
    // Utilities
    function GetServerVersion: string;
    function GetDatabaseSize: Int64;
    function GetTableSize(const ATable: string): Int64;
    function VacuumAnalyze(const ATable: string = ''): Boolean;
    
    property Connection: TFDConnection read FConnection;
    property Params: TPgConnectionParams read FParams;
    property OnNotify: TPgNotifyEvent read FOnNotify write FOnNotify;
  end;

  TPgCopyManager = class
  private
    FDriver: TPostgreSQLDriver;
  public
    constructor Create(ADriver: TPostgreSQLDriver);
    
    procedure CopyFromFile(const ATable, AFileName: string; const ADelimiter: Char = ',');
    procedure CopyToFile(const ATable, AFileName: string; const ADelimiter: Char = ',');
    procedure CopyFromStream(const ATable: string; AStream: TStream; const ADelimiter: Char = ',');
    procedure CopyToStream(const ATable: string; AStream: TStream; const ADelimiter: Char = ',');
  end;

function CreatePostgreSQLConnection(const AParams: TPgConnectionParams): TFDConnection;
function PgQuoteLiteral(const AValue: string): string;
function PgQuoteIdent(const AIdent: string): string;

implementation

uses
  System.JSON, System.Rtti, FireDAC.Stan.Param;

const
  SSLModeStrings: array[TPgSSLMode] of string = (
    'disable', 'allow', 'prefer', 'require', 'verify-ca', 'verify-full'
  );

{ TPgConnectionParams }

class function TPgConnectionParams.Default: TPgConnectionParams;
begin
  Result.Host := 'localhost';
  Result.Port := 5432;
  Result.Database := '';
  Result.Username := 'postgres';
  Result.Password := '';
  Result.SSLMode := sslPrefer;
  Result.SSLCert := '';
  Result.SSLKey := '';
  Result.SSLRootCert := '';
  Result.ApplicationName := 'UniBase';
  Result.ConnectTimeout := 30;
  Result.CommandTimeout := 0;
  Result.Pooled := True;
  Result.PoolSize := 20;
end;

function TPgConnectionParams.ToConnectionString: string;
begin
  Result := Format(
    'DriverID=PG;Server=%s;Port=%d;Database=%s;User_Name=%s;Password=%s;' +
    'PGAdvanced=sslmode=%s;ApplicationName=%s;LoginTimeout=%d',
    [Host, Port, Database, Username, Password, 
     SSLModeStrings[SSLMode], ApplicationName, ConnectTimeout]
  );
end;

{ TPgJsonb }

class function TPgJsonb.Create(const AJson: string): TPgJsonb;
begin
  Result.FValue := AJson;
end;

class function TPgJsonb.FromObject(AObj: TObject): TPgJsonb;
var
  JsonObj: TJSONObject;
begin
  JsonObj := TJSONObject.Create;
  try
    // Simplified - would use RTTI to serialize
    Result.FValue := JsonObj.ToJSON;
  finally
    JsonObj.Free;
  end;
end;

function TPgJsonb.AsString: string;
begin
  Result := FValue;
end;

function TPgJsonb.AsObject<T>: T;
begin
  // Would use JSON deserialization
  Result := nil;
end;

function TPgJsonb.Path(const APath: string): TPgJsonb;
begin
  // Would extract path from JSON
  Result.FValue := '';
end;

function TPgJsonb.Contains(const AJson: string): Boolean;
begin
  Result := False;
end;

function TPgJsonb.ContainsKey(const AKey: string): Boolean;
begin
  Result := Pos('"' + AKey + '"', FValue) > 0;
end;

class operator TPgJsonb.Implicit(const AValue: string): TPgJsonb;
begin
  Result.FValue := AValue;
end;

class operator TPgJsonb.Implicit(const AValue: TPgJsonb): string;
begin
  Result := AValue.FValue;
end;

{ TPgArray<T> }

class function TPgArray<T>.Create(const AItems: TArray<T>): TPgArray<T>;
begin
  Result.FItems := AItems;
end;

function TPgArray<T>.ToArray: TArray<T>;
begin
  Result := FItems;
end;

function TPgArray<T>.Contains(const AValue: T): Boolean;
var
  Item: T;
begin
  Result := False;
  for Item in FItems do
  begin
    // Would use proper comparison
    Result := True;
    Break;
  end;
end;

function TPgArray<T>.Overlaps(const AOther: TPgArray<T>): Boolean;
begin
  Result := False;
end;

function TPgArray<T>.ToString: string;
begin
  Result := '{' + '}'; // Would format properly
end;

class operator TPgArray<T>.Implicit(const AItems: TArray<T>): TPgArray<T>;
begin
  Result.FItems := AItems;
end;

{ TPgFullTextQuery }

class function TPgFullTextQuery.Create(const AQuery: string; const AConfig: string): TPgFullTextQuery;
begin
  Result.FQuery := AQuery;
  Result.FConfig := AConfig;
end;

class function TPgFullTextQuery.PlainTo(const AText: string; const AConfig: string): TPgFullTextQuery;
begin
  Result.FQuery := Format('plainto_tsquery(''%s'', %s)', [AConfig, PgQuoteLiteral(AText)]);
  Result.FConfig := AConfig;
end;

class function TPgFullTextQuery.PhraseTo(const APhrase: string; const AConfig: string): TPgFullTextQuery;
begin
  Result.FQuery := Format('phraseto_tsquery(''%s'', %s)', [AConfig, PgQuoteLiteral(APhrase)]);
  Result.FConfig := AConfig;
end;

class function TPgFullTextQuery.WebSearch(const AQuery: string; const AConfig: string): TPgFullTextQuery;
begin
  Result.FQuery := Format('websearch_to_tsquery(''%s'', %s)', [AConfig, PgQuoteLiteral(AQuery)]);
  Result.FConfig := AConfig;
end;

function TPgFullTextQuery.ToString: string;
begin
  Result := FQuery;
end;

function TPgFullTextQuery.ToSql: string;
begin
  Result := FQuery;
end;

{ TPostgreSQLDriver }

constructor TPostgreSQLDriver.Create(const AParams: TPgConnectionParams);
begin
  FParams := AParams;
  FConnection := TFDConnection.Create(nil);
  FListenChannels := TList<string>.Create;
  SetupConnection;
end;

constructor TPostgreSQLDriver.Create(const AHost, ADatabase, AUsername, APassword: string);
var
  Params: TPgConnectionParams;
begin
  Params := TPgConnectionParams.Default;
  Params.Host := AHost;
  Params.Database := ADatabase;
  Params.Username := AUsername;
  Params.Password := APassword;
  Create(Params);
end;

destructor TPostgreSQLDriver.Destroy;
begin
  Disconnect;
  FListenChannels.Free;
  FConnection.Free;
  inherited;
end;

procedure TPostgreSQLDriver.SetupConnection;
begin
  FConnection.DriverName := 'PG';
  FConnection.Params.Values['Server'] := FParams.Host;
  FConnection.Params.Values['Port'] := IntToStr(FParams.Port);
  FConnection.Params.Values['Database'] := FParams.Database;
  FConnection.Params.Values['User_Name'] := FParams.Username;
  FConnection.Params.Values['Password'] := FParams.Password;
  FConnection.Params.Values['PGAdvanced'] := 'sslmode=' + SSLModeStrings[FParams.SSLMode];
  FConnection.Params.Values['ApplicationName'] := FParams.ApplicationName;
  FConnection.LoginPrompt := False;
  
  if FParams.Pooled then
  begin
    FConnection.Params.Values['Pooled'] := 'True';
    FConnection.Params.Values['POOL_MaximumItems'] := IntToStr(FParams.PoolSize);
  end;
end;

procedure TPostgreSQLDriver.HandleNotify(AMessage: TFDPhysPgEventMessage);
begin
  if Assigned(FOnNotify) then
    FOnNotify(Self, AMessage.Name, AMessage.Data);
end;

procedure TPostgreSQLDriver.Connect;
begin
  if not FConnection.Connected then
    FConnection.Open;
end;

procedure TPostgreSQLDriver.Disconnect;
begin
  if FConnection.Connected then
    FConnection.Close;
end;

function TPostgreSQLDriver.IsConnected: Boolean;
begin
  Result := FConnection.Connected;
end;

function TPostgreSQLDriver.Query(const ASQL: string): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := FConnection;
  Result.SQL.Text := ASQL;
  Result.Open;
end;

function TPostgreSQLDriver.Execute(const ASQL: string): Integer;
begin
  Result := FConnection.ExecSQL(ASQL);
end;

function TPostgreSQLDriver.ExecuteScalar<T>(const ASQL: string): T;
var
  Qry: TFDQuery;
begin
  Qry := Query(ASQL);
  try
    if not Qry.IsEmpty then
      Result := Qry.Fields[0].Value
    else
      Result := Default(T);
  finally
    Qry.Free;
  end;
end;

function TPostgreSQLDriver.JsonbSet(const ATable, AColumn, APath, AValue: string; AId: Integer): Boolean;
var
  SQL: string;
begin
  SQL := Format('UPDATE %s SET %s = jsonb_set(%s, %s, %s) WHERE id = %d',
    [PgQuoteIdent(ATable), PgQuoteIdent(AColumn), PgQuoteIdent(AColumn),
     PgQuoteLiteral(APath), PgQuoteLiteral(AValue), AId]);
  Result := Execute(SQL) > 0;
end;

function TPostgreSQLDriver.JsonbRemove(const ATable, AColumn, APath: string; AId: Integer): Boolean;
var
  SQL: string;
begin
  SQL := Format('UPDATE %s SET %s = %s #- %s WHERE id = %d',
    [PgQuoteIdent(ATable), PgQuoteIdent(AColumn), PgQuoteIdent(AColumn),
     PgQuoteLiteral(APath), AId]);
  Result := Execute(SQL) > 0;
end;

function TPostgreSQLDriver.JsonbConcat(const ATable, AColumn, AJson: string; AId: Integer): Boolean;
var
  SQL: string;
begin
  SQL := Format('UPDATE %s SET %s = %s || %s::jsonb WHERE id = %d',
    [PgQuoteIdent(ATable), PgQuoteIdent(AColumn), PgQuoteIdent(AColumn),
     PgQuoteLiteral(AJson), AId]);
  Result := Execute(SQL) > 0;
end;

function TPostgreSQLDriver.ArrayAppend<T>(const ATable, AColumn: string; AValue: T; AId: Integer): Boolean;
begin
  Result := False;
end;

function TPostgreSQLDriver.ArrayRemove<T>(const ATable, AColumn: string; AValue: T; AId: Integer): Boolean;
begin
  Result := False;
end;

function TPostgreSQLDriver.ArrayContains<T>(const ATable, AColumn: string; AValue: T; AId: Integer): Boolean;
begin
  Result := False;
end;

function TPostgreSQLDriver.FullTextSearch(const ATable, AColumn, AQuery: string;
  const AConfig: string): TFDQuery;
var
  SQL: string;
begin
  SQL := Format(
    'SELECT * FROM %s WHERE to_tsvector(''%s'', %s) @@ plainto_tsquery(''%s'', %s)',
    [PgQuoteIdent(ATable), AConfig, PgQuoteIdent(AColumn), AConfig, PgQuoteLiteral(AQuery)]);
  Result := Query(SQL);
end;

function TPostgreSQLDriver.FullTextRank(const ATable, AColumn, AQuery: string;
  const AConfig: string): TFDQuery;
var
  SQL: string;
begin
  SQL := Format(
    'SELECT *, ts_rank(to_tsvector(''%s'', %s), plainto_tsquery(''%s'', %s)) AS rank ' +
    'FROM %s WHERE to_tsvector(''%s'', %s) @@ plainto_tsquery(''%s'', %s) ' +
    'ORDER BY rank DESC',
    [AConfig, PgQuoteIdent(AColumn), AConfig, PgQuoteLiteral(AQuery),
     PgQuoteIdent(ATable), AConfig, PgQuoteIdent(AColumn), AConfig, PgQuoteLiteral(AQuery)]);
  Result := Query(SQL);
end;

procedure TPostgreSQLDriver.Listen(const AChannel: string);
begin
  Execute('LISTEN ' + PgQuoteIdent(AChannel));
  FListenChannels.Add(AChannel);
end;

procedure TPostgreSQLDriver.Unlisten(const AChannel: string);
begin
  Execute('UNLISTEN ' + PgQuoteIdent(AChannel));
  FListenChannels.Remove(AChannel);
end;

procedure TPostgreSQLDriver.Notify(const AChannel: string; const APayload: string);
begin
  if APayload = '' then
    Execute('NOTIFY ' + PgQuoteIdent(AChannel))
  else
    Execute(Format('NOTIFY %s, %s', [PgQuoteIdent(AChannel), PgQuoteLiteral(APayload)]));
end;

procedure TPostgreSQLDriver.BeginTransaction;
begin
  FConnection.StartTransaction;
end;

procedure TPostgreSQLDriver.Commit;
begin
  FConnection.Commit;
end;

procedure TPostgreSQLDriver.Rollback;
begin
  FConnection.Rollback;
end;

function TPostgreSQLDriver.InTransaction: Boolean;
begin
  Result := FConnection.InTransaction;
end;

function TPostgreSQLDriver.GetServerVersion: string;
begin
  Result := ExecuteScalar<string>('SELECT version()');
end;

function TPostgreSQLDriver.GetDatabaseSize: Int64;
begin
  Result := ExecuteScalar<Int64>(
    Format('SELECT pg_database_size(%s)', [PgQuoteLiteral(FParams.Database)]));
end;

function TPostgreSQLDriver.GetTableSize(const ATable: string): Int64;
begin
  Result := ExecuteScalar<Int64>(
    Format('SELECT pg_total_relation_size(%s)', [PgQuoteLiteral(ATable)]));
end;

function TPostgreSQLDriver.VacuumAnalyze(const ATable: string): Boolean;
begin
  if ATable = '' then
    Execute('VACUUM ANALYZE')
  else
    Execute('VACUUM ANALYZE ' + PgQuoteIdent(ATable));
  Result := True;
end;

{ TPgCopyManager }

constructor TPgCopyManager.Create(ADriver: TPostgreSQLDriver);
begin
  FDriver := ADriver;
end;

procedure TPgCopyManager.CopyFromFile(const ATable, AFileName: string; const ADelimiter: Char);
begin
  FDriver.Execute(Format(
    'COPY %s FROM %s WITH (FORMAT csv, DELIMITER %s, HEADER true)',
    [PgQuoteIdent(ATable), PgQuoteLiteral(AFileName), PgQuoteLiteral(ADelimiter)]));
end;

procedure TPgCopyManager.CopyToFile(const ATable, AFileName: string; const ADelimiter: Char);
begin
  FDriver.Execute(Format(
    'COPY %s TO %s WITH (FORMAT csv, DELIMITER %s, HEADER true)',
    [PgQuoteIdent(ATable), PgQuoteLiteral(AFileName), PgQuoteLiteral(ADelimiter)]));
end;

procedure TPgCopyManager.CopyFromStream(const ATable: string; AStream: TStream; const ADelimiter: Char);
begin
  // Would implement stream-based COPY
end;

procedure TPgCopyManager.CopyToStream(const ATable: string; AStream: TStream; const ADelimiter: Char);
begin
  // Would implement stream-based COPY
end;

{ Helper functions }

function CreatePostgreSQLConnection(const AParams: TPgConnectionParams): TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.DriverName := 'PG';
  Result.Params.Values['Server'] := AParams.Host;
  Result.Params.Values['Port'] := IntToStr(AParams.Port);
  Result.Params.Values['Database'] := AParams.Database;
  Result.Params.Values['User_Name'] := AParams.Username;
  Result.Params.Values['Password'] := AParams.Password;
  Result.LoginPrompt := False;
end;

function PgQuoteLiteral(const AValue: string): string;
begin
  Result := '''' + StringReplace(AValue, '''', '''''', [rfReplaceAll]) + '''';
end;

function PgQuoteIdent(const AIdent: string): string;
begin
  Result := '"' + StringReplace(AIdent, '"', '""', [rfReplaceAll]) + '"';
end;

end.
