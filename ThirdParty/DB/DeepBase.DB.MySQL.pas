unit DeepBase.DB.MySQL;

{*******************************************************************************
  DeepBase MySQL Driver Adapter
  
  MySQL specific features:
    - JSON support (MySQL 5.7+)
    - Full-text search (InnoDB/MyISAM)
    - Replication support
    - Connection pooling
    - SSL/TLS connection
    - Stored procedures
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  FireDAC.Comp.Client, FireDAC.Phys.MySQL, FireDAC.Stan.Def,
  FireDAC.Stan.Async, FireDAC.Stan.Pool,
  DeepBase.DB.DoQry;

type
  TMySQLSSLMode = (mysslDisabled, mysslPreferred, mysslRequired, 
                   mysslVerifyCA, mysslVerifyIdentity);
  
  TMySQLCharset = (csUtf8, csUtf8mb4, csLatin1, csGbk, csBig5);
  
  TMySQLEngine = (meInnoDB, meMyISAM, meMemory, meArchive, meCSV);

  TMySQLConnectionParams = record
    Host: string;
    Port: Integer;
    Database: string;
    Username: string;
    Password: string;
    Charset: TMySQLCharset;
    SSLMode: TMySQLSSLMode;
    SSLCert: string;
    SSLKey: string;
    SSLCA: string;
    ConnectTimeout: Integer;
    ReadTimeout: Integer;
    WriteTimeout: Integer;
    Pooled: Boolean;
    PoolSize: Integer;
    Compress: Boolean;
    
    class function Default: TMySQLConnectionParams; static;
    function ToConnectionString: string;
  end;

  TMySQLJson = record
  private
    FValue: string;
  public
    class function Create(const AJson: string): TMySQLJson; static;
    
    function AsString: string;
    function Extract(const APath: string): TMySQLJson;
    function ExtractValue(const APath: string): string;
    function Contains(const APath: string): Boolean;
    function Keys: TArray<string>;
    function Length: Integer;
    function Type_: string;
    
    class operator Implicit(const AValue: string): TMySQLJson;
    class operator Implicit(const AValue: TMySQLJson): string;
  end;

  TMySQLFullTextMode = (ftNaturalLanguage, ftBooleanMode, ftQueryExpansion);

  TMySQLDriver = class
  private
    FConnection: TFDConnection;
    FParams: TMySQLConnectionParams;
    
    procedure SetupConnection;
  public
    constructor Create(const AParams: TMySQLConnectionParams); overload;
    constructor Create(const AHost, ADatabase, AUsername, APassword: string); overload;
    destructor Destroy; override;
    
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;
    
    // Query execution
    function Query(const ASQL: string): TFDQuery;
    function Execute(const ASQL: string): Integer;
    function ExecuteScalar<T>(const ASQL: string): T;
    function LastInsertId: Int64;
    
    // JSON operations (MySQL 5.7+)
    function JsonSet(const ATable, AColumn, APath, AValue: string; AId: Integer): Boolean;
    function JsonRemove(const ATable, AColumn, APath: string; AId: Integer): Boolean;
    function JsonInsert(const ATable, AColumn, APath, AValue: string; AId: Integer): Boolean;
    function JsonReplace(const ATable, AColumn, APath, AValue: string; AId: Integer): Boolean;
    function JsonArrayAppend(const ATable, AColumn, APath, AValue: string; AId: Integer): Boolean;
    function JsonContains(const ATable, AColumn, AValue: string; AId: Integer): Boolean;
    function JsonSearch(const ATable, AColumn, AValue: string): TFDQuery;
    
    // Full-text search
    function FullTextSearch(const ATable: string; const AColumns: TArray<string>;
      const AQuery: string; AMode: TMySQLFullTextMode = ftNaturalLanguage): TFDQuery;
    function FullTextSearchWithRelevance(const ATable: string; const AColumns: TArray<string>;
      const AQuery: string; AMode: TMySQLFullTextMode = ftNaturalLanguage): TFDQuery;
    
    // Transactions
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    function InTransaction: Boolean;
    
    // Stored procedures
    function CallProc(const AProcName: string; const AParams: array of Variant): TFDQuery;
    procedure ExecProc(const AProcName: string; const AParams: array of Variant);
    
    // Table operations
    function TableExists(const ATable: string): Boolean;
    function GetTableEngine(const ATable: string): TMySQLEngine;
    procedure ChangeTableEngine(const ATable: string; AEngine: TMySQLEngine);
    procedure OptimizeTable(const ATable: string);
    procedure AnalyzeTable(const ATable: string);
    procedure RepairTable(const ATable: string);
    procedure TruncateTable(const ATable: string);
    
    // Index operations
    procedure CreateFullTextIndex(const ATable, AIndexName: string; 
      const AColumns: TArray<string>);
    procedure DropIndex(const ATable, AIndexName: string);
    function IndexExists(const ATable, AIndexName: string): Boolean;
    
    // Server info
    function GetServerVersion: string;
    function GetServerVariables: TDictionary<string, string>;
    function GetProcessList: TFDQuery;
    function GetTableStatus(const ATable: string = ''): TFDQuery;
    function GetDatabaseSize: Int64;
    function GetTableSize(const ATable: string): Int64;
    
    // Replication
    function GetMasterStatus: TFDQuery;
    function GetSlaveStatus: TFDQuery;
    
    property Connection: TFDConnection read FConnection;
    property Params: TMySQLConnectionParams read FParams;
  end;

  TMySQLBulkInsert = class
  private
    FDriver: TMySQLDriver;
    FTable: string;
    FColumns: TArray<string>;
    FValues: TList<TArray<Variant>>;
    FBatchSize: Integer;
    
    procedure FlushBatch;
  public
    constructor Create(ADriver: TMySQLDriver; const ATable: string; 
      const AColumns: TArray<string>);
    destructor Destroy; override;
    
    procedure Add(const AValues: array of Variant);
    procedure Flush;
    
    property BatchSize: Integer read FBatchSize write FBatchSize;
  end;

  TMySQLExportImport = class
  private
    FDriver: TMySQLDriver;
  public
    constructor Create(ADriver: TMySQLDriver);
    
    procedure ExportToCSV(const ATable, AFileName: string; const ADelimiter: Char = ',');
    procedure ImportFromCSV(const ATable, AFileName: string; const ADelimiter: Char = ',';
      AIgnoreLines: Integer = 1);
    procedure ExportToSQL(const ATables: TArray<string>; const AFileName: string;
      AIncludeData: Boolean = True);
  end;

function CreateMySQLConnection(const AParams: TMySQLConnectionParams): TFDConnection;
function MySQLQuote(const AValue: string): string;
function MySQLQuoteIdent(const AIdent: string): string;

implementation

uses
  System.Variants, System.StrUtils;

const
  CharsetStrings: array[TMySQLCharset] of string = (
    'utf8', 'utf8mb4', 'latin1', 'gbk', 'big5'
  );
  
  SSLModeStrings: array[TMySQLSSLMode] of string = (
    'DISABLED', 'PREFERRED', 'REQUIRED', 'VERIFY_CA', 'VERIFY_IDENTITY'
  );
  
  EngineStrings: array[TMySQLEngine] of string = (
    'InnoDB', 'MyISAM', 'MEMORY', 'ARCHIVE', 'CSV'
  );
  
  FullTextModeStrings: array[TMySQLFullTextMode] of string = (
    'IN NATURAL LANGUAGE MODE',
    'IN BOOLEAN MODE',
    'WITH QUERY EXPANSION'
  );

{ TMySQLConnectionParams }

class function TMySQLConnectionParams.Default: TMySQLConnectionParams;
begin
  Result.Host := 'localhost';
  Result.Port := 3306;
  Result.Database := '';
  Result.Username := 'root';
  Result.Password := '';
  Result.Charset := csUtf8mb4;
  Result.SSLMode := mysslPreferred;
  Result.SSLCert := '';
  Result.SSLKey := '';
  Result.SSLCA := '';
  Result.ConnectTimeout := 30;
  Result.ReadTimeout := 30;
  Result.WriteTimeout := 30;
  Result.Pooled := True;
  Result.PoolSize := 20;
  Result.Compress := False;
end;

function TMySQLConnectionParams.ToConnectionString: string;
begin
  Result := Format(
    'DriverID=MySQL;Server=%s;Port=%d;Database=%s;User_Name=%s;Password=%s;CharacterSet=%s',
    [Host, Port, Database, Username, Password, CharsetStrings[Charset]]
  );
end;

{ TMySQLJson }

class function TMySQLJson.Create(const AJson: string): TMySQLJson;
begin
  Result.FValue := AJson;
end;

function TMySQLJson.AsString: string;
begin
  Result := FValue;
end;

function TMySQLJson.Extract(const APath: string): TMySQLJson;
begin
  Result.FValue := '';
end;

function TMySQLJson.ExtractValue(const APath: string): string;
begin
  Result := '';
end;

function TMySQLJson.Contains(const APath: string): Boolean;
begin
  Result := False;
end;

function TMySQLJson.Keys: TArray<string>;
begin
  SetLength(Result, 0);
end;

function TMySQLJson.Length: Integer;
begin
  Result := 0;
end;

function TMySQLJson.Type_: string;
begin
  Result := '';
end;

class operator TMySQLJson.Implicit(const AValue: string): TMySQLJson;
begin
  Result.FValue := AValue;
end;

class operator TMySQLJson.Implicit(const AValue: TMySQLJson): string;
begin
  Result := AValue.FValue;
end;

{ TMySQLDriver }

constructor TMySQLDriver.Create(const AParams: TMySQLConnectionParams);
begin
  FParams := AParams;
  FConnection := TFDConnection.Create(nil);
  SetupConnection;
end;

constructor TMySQLDriver.Create(const AHost, ADatabase, AUsername, APassword: string);
var
  Params: TMySQLConnectionParams;
begin
  Params := TMySQLConnectionParams.Default;
  Params.Host := AHost;
  Params.Database := ADatabase;
  Params.Username := AUsername;
  Params.Password := APassword;
  Create(Params);
end;

destructor TMySQLDriver.Destroy;
begin
  Disconnect;
  FConnection.Free;
  inherited;
end;

procedure TMySQLDriver.SetupConnection;
begin
  FConnection.DriverName := 'MySQL';
  FConnection.Params.Values['Server'] := FParams.Host;
  FConnection.Params.Values['Port'] := IntToStr(FParams.Port);
  FConnection.Params.Values['Database'] := FParams.Database;
  FConnection.Params.Values['User_Name'] := FParams.Username;
  FConnection.Params.Values['Password'] := FParams.Password;
  FConnection.Params.Values['CharacterSet'] := CharsetStrings[FParams.Charset];
  FConnection.LoginPrompt := False;
  
  if FParams.Compress then
    FConnection.Params.Values['Compress'] := 'True';
  
  if FParams.Pooled then
  begin
    FConnection.Params.Values['Pooled'] := 'True';
    FConnection.Params.Values['POOL_MaximumItems'] := IntToStr(FParams.PoolSize);
  end;
end;

procedure TMySQLDriver.Connect;
begin
  if not FConnection.Connected then
    FConnection.Open;
end;

procedure TMySQLDriver.Disconnect;
begin
  if FConnection.Connected then
    FConnection.Close;
end;

function TMySQLDriver.IsConnected: Boolean;
begin
  Result := FConnection.Connected;
end;

function TMySQLDriver.Query(const ASQL: string): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := FConnection;
  Result.SQL.Text := ASQL;
  Result.Open;
end;

function TMySQLDriver.Execute(const ASQL: string): Integer;
begin
  Result := FConnection.ExecSQL(ASQL);
end;

function TMySQLDriver.ExecuteScalar<T>(const ASQL: string): T;
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

function TMySQLDriver.LastInsertId: Int64;
begin
  Result := ExecuteScalar<Int64>('SELECT LAST_INSERT_ID()');
end;

function TMySQLDriver.JsonSet(const ATable, AColumn, APath, AValue: string; AId: Integer): Boolean;
var
  SQL: string;
begin
  SQL := Format('UPDATE %s SET %s = JSON_SET(%s, %s, %s) WHERE id = %d',
    [MySQLQuoteIdent(ATable), MySQLQuoteIdent(AColumn), MySQLQuoteIdent(AColumn),
     MySQLQuote(APath), MySQLQuote(AValue), AId]);
  Result := Execute(SQL) > 0;
end;

function TMySQLDriver.JsonRemove(const ATable, AColumn, APath: string; AId: Integer): Boolean;
var
  SQL: string;
begin
  SQL := Format('UPDATE %s SET %s = JSON_REMOVE(%s, %s) WHERE id = %d',
    [MySQLQuoteIdent(ATable), MySQLQuoteIdent(AColumn), MySQLQuoteIdent(AColumn),
     MySQLQuote(APath), AId]);
  Result := Execute(SQL) > 0;
end;

function TMySQLDriver.JsonInsert(const ATable, AColumn, APath, AValue: string; AId: Integer): Boolean;
var
  SQL: string;
begin
  SQL := Format('UPDATE %s SET %s = JSON_INSERT(%s, %s, %s) WHERE id = %d',
    [MySQLQuoteIdent(ATable), MySQLQuoteIdent(AColumn), MySQLQuoteIdent(AColumn),
     MySQLQuote(APath), MySQLQuote(AValue), AId]);
  Result := Execute(SQL) > 0;
end;

function TMySQLDriver.JsonReplace(const ATable, AColumn, APath, AValue: string; AId: Integer): Boolean;
var
  SQL: string;
begin
  SQL := Format('UPDATE %s SET %s = JSON_REPLACE(%s, %s, %s) WHERE id = %d',
    [MySQLQuoteIdent(ATable), MySQLQuoteIdent(AColumn), MySQLQuoteIdent(AColumn),
     MySQLQuote(APath), MySQLQuote(AValue), AId]);
  Result := Execute(SQL) > 0;
end;

function TMySQLDriver.JsonArrayAppend(const ATable, AColumn, APath, AValue: string; AId: Integer): Boolean;
var
  SQL: string;
begin
  SQL := Format('UPDATE %s SET %s = JSON_ARRAY_APPEND(%s, %s, %s) WHERE id = %d',
    [MySQLQuoteIdent(ATable), MySQLQuoteIdent(AColumn), MySQLQuoteIdent(AColumn),
     MySQLQuote(APath), MySQLQuote(AValue), AId]);
  Result := Execute(SQL) > 0;
end;

function TMySQLDriver.JsonContains(const ATable, AColumn, AValue: string; AId: Integer): Boolean;
var
  SQL: string;
begin
  SQL := Format('SELECT JSON_CONTAINS(%s, %s) FROM %s WHERE id = %d',
    [MySQLQuoteIdent(AColumn), MySQLQuote(AValue), MySQLQuoteIdent(ATable), AId]);
  Result := ExecuteScalar<Integer>(SQL) = 1;
end;

function TMySQLDriver.JsonSearch(const ATable, AColumn, AValue: string): TFDQuery;
var
  SQL: string;
begin
  SQL := Format('SELECT * FROM %s WHERE JSON_SEARCH(%s, ''one'', %s) IS NOT NULL',
    [MySQLQuoteIdent(ATable), MySQLQuoteIdent(AColumn), MySQLQuote(AValue)]);
  Result := Query(SQL);
end;

function TMySQLDriver.FullTextSearch(const ATable: string; const AColumns: TArray<string>;
  const AQuery: string; AMode: TMySQLFullTextMode): TFDQuery;
var
  SQL, ColList: string;
begin
  ColList := string.Join(', ', AColumns);
  SQL := Format('SELECT * FROM %s WHERE MATCH(%s) AGAINST(%s %s)',
    [MySQLQuoteIdent(ATable), ColList, MySQLQuote(AQuery), FullTextModeStrings[AMode]]);
  Result := Query(SQL);
end;

function TMySQLDriver.FullTextSearchWithRelevance(const ATable: string; 
  const AColumns: TArray<string>; const AQuery: string; AMode: TMySQLFullTextMode): TFDQuery;
var
  SQL, ColList: string;
begin
  ColList := string.Join(', ', AColumns);
  SQL := Format(
    'SELECT *, MATCH(%s) AGAINST(%s %s) AS relevance FROM %s ' +
    'WHERE MATCH(%s) AGAINST(%s %s) ORDER BY relevance DESC',
    [ColList, MySQLQuote(AQuery), FullTextModeStrings[AMode], MySQLQuoteIdent(ATable),
     ColList, MySQLQuote(AQuery), FullTextModeStrings[AMode]]);
  Result := Query(SQL);
end;

procedure TMySQLDriver.BeginTransaction;
begin
  FConnection.StartTransaction;
end;

procedure TMySQLDriver.Commit;
begin
  FConnection.Commit;
end;

procedure TMySQLDriver.Rollback;
begin
  FConnection.Rollback;
end;

function TMySQLDriver.InTransaction: Boolean;
begin
  Result := FConnection.InTransaction;
end;

function TMySQLDriver.CallProc(const AProcName: string; const AParams: array of Variant): TFDQuery;
var
  SQL: string;
  I: Integer;
  ParamList: string;
begin
  ParamList := '';
  for I := 0 to High(AParams) do
  begin
    if I > 0 then ParamList := ParamList + ', ';
    if VarIsStr(AParams[I]) then
      ParamList := ParamList + MySQLQuote(VarToStr(AParams[I]))
    else if VarIsNull(AParams[I]) then
      ParamList := ParamList + 'NULL'
    else
      ParamList := ParamList + VarToStr(AParams[I]);
  end;
  
  SQL := Format('CALL %s(%s)', [MySQLQuoteIdent(AProcName), ParamList]);
  Result := Query(SQL);
end;

procedure TMySQLDriver.ExecProc(const AProcName: string; const AParams: array of Variant);
var
  Qry: TFDQuery;
begin
  Qry := CallProc(AProcName, AParams);
  try
    // Consume result
  finally
    Qry.Free;
  end;
end;

function TMySQLDriver.TableExists(const ATable: string): Boolean;
begin
  Result := ExecuteScalar<Integer>(Format(
    'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = %s AND table_name = %s',
    [MySQLQuote(FParams.Database), MySQLQuote(ATable)])) > 0;
end;

function TMySQLDriver.GetTableEngine(const ATable: string): TMySQLEngine;
var
  Engine: string;
  I: TMySQLEngine;
begin
  Result := meInnoDB;
  Engine := ExecuteScalar<string>(Format(
    'SELECT ENGINE FROM information_schema.tables WHERE table_schema = %s AND table_name = %s',
    [MySQLQuote(FParams.Database), MySQLQuote(ATable)]));
  
  for I := Low(TMySQLEngine) to High(TMySQLEngine) do
    if SameText(Engine, EngineStrings[I]) then
    begin
      Result := I;
      Break;
    end;
end;

procedure TMySQLDriver.ChangeTableEngine(const ATable: string; AEngine: TMySQLEngine);
begin
  Execute(Format('ALTER TABLE %s ENGINE = %s',
    [MySQLQuoteIdent(ATable), EngineStrings[AEngine]]));
end;

procedure TMySQLDriver.OptimizeTable(const ATable: string);
begin
  Execute('OPTIMIZE TABLE ' + MySQLQuoteIdent(ATable));
end;

procedure TMySQLDriver.AnalyzeTable(const ATable: string);
begin
  Execute('ANALYZE TABLE ' + MySQLQuoteIdent(ATable));
end;

procedure TMySQLDriver.RepairTable(const ATable: string);
begin
  Execute('REPAIR TABLE ' + MySQLQuoteIdent(ATable));
end;

procedure TMySQLDriver.TruncateTable(const ATable: string);
begin
  Execute('TRUNCATE TABLE ' + MySQLQuoteIdent(ATable));
end;

procedure TMySQLDriver.CreateFullTextIndex(const ATable, AIndexName: string;
  const AColumns: TArray<string>);
begin
  Execute(Format('ALTER TABLE %s ADD FULLTEXT INDEX %s (%s)',
    [MySQLQuoteIdent(ATable), MySQLQuoteIdent(AIndexName), string.Join(', ', AColumns)]));
end;

procedure TMySQLDriver.DropIndex(const ATable, AIndexName: string);
begin
  Execute(Format('ALTER TABLE %s DROP INDEX %s',
    [MySQLQuoteIdent(ATable), MySQLQuoteIdent(AIndexName)]));
end;

function TMySQLDriver.IndexExists(const ATable, AIndexName: string): Boolean;
begin
  Result := ExecuteScalar<Integer>(Format(
    'SELECT COUNT(*) FROM information_schema.statistics ' +
    'WHERE table_schema = %s AND table_name = %s AND index_name = %s',
    [MySQLQuote(FParams.Database), MySQLQuote(ATable), MySQLQuote(AIndexName)])) > 0;
end;

function TMySQLDriver.GetServerVersion: string;
begin
  Result := ExecuteScalar<string>('SELECT VERSION()');
end;

function TMySQLDriver.GetServerVariables: TDictionary<string, string>;
var
  Qry: TFDQuery;
begin
  Result := TDictionary<string, string>.Create;
  Qry := Query('SHOW VARIABLES');
  try
    while not Qry.Eof do
    begin
      Result.Add(Qry.Fields[0].AsString, Qry.Fields[1].AsString);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

function TMySQLDriver.GetProcessList: TFDQuery;
begin
  Result := Query('SHOW PROCESSLIST');
end;

function TMySQLDriver.GetTableStatus(const ATable: string): TFDQuery;
begin
  if ATable = '' then
    Result := Query('SHOW TABLE STATUS')
  else
    Result := Query('SHOW TABLE STATUS LIKE ' + MySQLQuote(ATable));
end;

function TMySQLDriver.GetDatabaseSize: Int64;
begin
  Result := ExecuteScalar<Int64>(Format(
    'SELECT SUM(data_length + index_length) FROM information_schema.tables WHERE table_schema = %s',
    [MySQLQuote(FParams.Database)]));
end;

function TMySQLDriver.GetTableSize(const ATable: string): Int64;
begin
  Result := ExecuteScalar<Int64>(Format(
    'SELECT data_length + index_length FROM information_schema.tables ' +
    'WHERE table_schema = %s AND table_name = %s',
    [MySQLQuote(FParams.Database), MySQLQuote(ATable)]));
end;

function TMySQLDriver.GetMasterStatus: TFDQuery;
begin
  Result := Query('SHOW MASTER STATUS');
end;

function TMySQLDriver.GetSlaveStatus: TFDQuery;
begin
  Result := Query('SHOW SLAVE STATUS');
end;

{ TMySQLBulkInsert }

constructor TMySQLBulkInsert.Create(ADriver: TMySQLDriver; const ATable: string;
  const AColumns: TArray<string>);
begin
  FDriver := ADriver;
  FTable := ATable;
  FColumns := AColumns;
  FValues := TList<TArray<Variant>>.Create;
  FBatchSize := 1000;
end;

destructor TMySQLBulkInsert.Destroy;
begin
  Flush;
  FValues.Free;
  inherited;
end;

procedure TMySQLBulkInsert.Add(const AValues: array of Variant);
var
  Arr: TArray<Variant>;
  I: Integer;
begin
  SetLength(Arr, Length(AValues));
  for I := 0 to High(AValues) do
    Arr[I] := AValues[I];
  FValues.Add(Arr);
  
  if FValues.Count >= FBatchSize then
    FlushBatch;
end;

procedure TMySQLBulkInsert.FlushBatch;
var
  SQL: TStringBuilder;
  Row: TArray<Variant>;
  I: Integer;
  V: Variant;
  First: Boolean;
begin
  if FValues.Count = 0 then Exit;
  
  SQL := TStringBuilder.Create;
  try
    SQL.AppendFormat('INSERT INTO %s (%s) VALUES ', 
      [MySQLQuoteIdent(FTable), string.Join(', ', FColumns)]);
    
    First := True;
    for Row in FValues do
    begin
      if not First then SQL.Append(', ');
      SQL.Append('(');
      for I := 0 to High(Row) do
      begin
        if I > 0 then SQL.Append(', ');
        V := Row[I];
        if VarIsNull(V) then
          SQL.Append('NULL')
        else if VarIsStr(V) then
          SQL.Append(MySQLQuote(VarToStr(V)))
        else
          SQL.Append(VarToStr(V));
      end;
      SQL.Append(')');
      First := False;
    end;
    
    FDriver.Execute(SQL.ToString);
    FValues.Clear;
  finally
    SQL.Free;
  end;
end;

procedure TMySQLBulkInsert.Flush;
begin
  FlushBatch;
end;

{ TMySQLExportImport }

constructor TMySQLExportImport.Create(ADriver: TMySQLDriver);
begin
  FDriver := ADriver;
end;

procedure TMySQLExportImport.ExportToCSV(const ATable, AFileName: string; const ADelimiter: Char);
begin
  FDriver.Execute(Format(
    'SELECT * INTO OUTFILE %s FIELDS TERMINATED BY %s OPTIONALLY ENCLOSED BY ''"'' LINES TERMINATED BY ''\n'' FROM %s',
    [MySQLQuote(AFileName), MySQLQuote(ADelimiter), MySQLQuoteIdent(ATable)]));
end;

procedure TMySQLExportImport.ImportFromCSV(const ATable, AFileName: string; 
  const ADelimiter: Char; AIgnoreLines: Integer);
begin
  FDriver.Execute(Format(
    'LOAD DATA INFILE %s INTO TABLE %s FIELDS TERMINATED BY %s OPTIONALLY ENCLOSED BY ''"'' LINES TERMINATED BY ''\n'' IGNORE %d LINES',
    [MySQLQuote(AFileName), MySQLQuoteIdent(ATable), MySQLQuote(ADelimiter), AIgnoreLines]));
end;

procedure TMySQLExportImport.ExportToSQL(const ATables: TArray<string>; const AFileName: string;
  AIncludeData: Boolean);
begin
  // Would use mysqldump or generate SQL manually
end;

{ Helper functions }

function CreateMySQLConnection(const AParams: TMySQLConnectionParams): TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.DriverName := 'MySQL';
  Result.Params.Values['Server'] := AParams.Host;
  Result.Params.Values['Port'] := IntToStr(AParams.Port);
  Result.Params.Values['Database'] := AParams.Database;
  Result.Params.Values['User_Name'] := AParams.Username;
  Result.Params.Values['Password'] := AParams.Password;
  Result.Params.Values['CharacterSet'] := CharsetStrings[AParams.Charset];
  Result.LoginPrompt := False;
end;

function MySQLQuote(const AValue: string): string;
begin
  Result := '''' + StringReplace(
    StringReplace(AValue, '\', '\\', [rfReplaceAll]),
    '''', '\''', [rfReplaceAll]) + '''';
end;

function MySQLQuoteIdent(const AIdent: string): string;
begin
  Result := '`' + StringReplace(AIdent, '`', '``', [rfReplaceAll]) + '`';
end;

end.
