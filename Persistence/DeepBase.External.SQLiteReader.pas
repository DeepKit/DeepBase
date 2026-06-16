{ ============================================================================
  DeepBase.External.SQLiteReader - SQLCipher External Database Reader
  Version: 0.7 — Dual-backend (FireDAC + BCryptDirect)
  ============================================================================ }

unit DeepBase.External.SQLiteReader;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Variants, System.Hash, System.Math, System.IOUtils,
  FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Stan.Error,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  DeepBase.Types, DeepBase.Exceptions, DeepBase.Logging,
  DeepBase.External.Types, DeepBase.External.Auditor,
  DeepBase.External.BCryptDecrypt,
  DeepBase.SchemaAdapter, DeepBase.SchemaAdapter.Registry;

type
  IExternalDBReader = interface
    ['{A86F1C3E-7D2B-4F92-8E15-3C6B09A4F7D2}']
    function OpenReadOnly(const DbPath: string; const KeyBytes: TBytes): IExternalDBReader;
    function OpenWithKeyCallback(const DbPath: string;
      const KeyCallback: TFunc<string, TBytes>): IExternalDBReader;
    function GetSchema: TExternalDBSchema;
    function GetSchemaFingerprint: string;
    function SafeQuery(const TableName: string;
      const ColumnNames: TArray<string>): TFDQuery;
    function SafeQueryAsDict(const TableName: string;
      const ColumnNames: TArray<string>): TArray<TDictionary<string, Variant>>;
    function QueryPragmaInt(const PragmaName: string): Integer;
    procedure Close;
    function IsOpen: Boolean;
    function GetCompatibilityReport: string;
  end;

  TExternalSQLiteReader = class(TInterfacedObject, IExternalDBReader, IBodyZeroAuditor)
  private
    FConnection: TFDConnection;
    FDriverLink: TFDPhysSQLiteDriverLink;
    FBackend: TDecryptBackend;
    FConfig: TSQLCipherCompatibilityConfig;
    FAuditor: TBodyZeroAuditorImpl;
    FSchema: TExternalDBSchema;
    FSchemaVersionAtOpen: Integer;
    FAdapterRegistry: ISchemaAdapterRegistry;
    FIsOpen: Boolean;
    FDbPath: string;
    FBCryptReader: TBCryptSQLiteReader;          // v0.7: BCrypt direct decryption backend
    function LoadSQLCipherLibrary: Boolean;
    procedure ApplyReadOnlySafeguards;
    function GetRawSQLiteHandle: Pointer;
    function TryResolveAdapter(const Fingerprint: string): Boolean;
    procedure ApplyFireDACConnection(const DbPath: string; const KeyBytes: TBytes);
    procedure ApplyBCryptConnection(const DbPath: string; const KeyBytes: TBytes);
  public
    constructor Create(const AConfig: TSQLCipherCompatibilityConfig;
      const AAuditor: IBodyZeroAuditor);
    destructor Destroy; override;
    procedure SetAdapterRegistry(const ARegistry: ISchemaAdapterRegistry);
    // IExternalDBReader
    function OpenReadOnly(const DbPath: string; const KeyBytes: TBytes): IExternalDBReader;
    function OpenWithKeyCallback(const DbPath: string;
      const KeyCallback: TFunc<string, TBytes>): IExternalDBReader;
    function GetSchema: TExternalDBSchema;
    function GetSchemaFingerprint: string;
    function SafeQuery(const TableName: string;
      const ColumnNames: TArray<string>): TFDQuery;
    function SafeQueryAsDict(const TableName: string;
      const ColumnNames: TArray<string>): TArray<TDictionary<string, Variant>>;
    function QueryPragmaInt(const PragmaName: string): Integer;
    procedure Close;
    function IsOpen: Boolean;
    function GetCompatibilityReport: string;
    // IBodyZeroAuditor
    procedure RecordColumnAccess(const ColumnName: string);
    function GetQueriedColumns: TArray<string>;
    function GetBodyColumnsSeen: Boolean;
    function GetWriteAttempts: Integer;
    function GetUIACallCount: Integer;
    function IsFaulted: Boolean;
    procedure IncrementFaultCount;
    procedure IncrementWriteAttempts;
    procedure RecordRawSQLAccess(const SQL: string);
    procedure RecordUIAOperation(const Path: string; const Value: string);
    procedure Reset;
    function GenerateBodyZeroReport: TBodyZeroReport;
  end;

implementation

constructor TExternalSQLiteReader.Create(const AConfig: TSQLCipherCompatibilityConfig;
  const AAuditor: IBodyZeroAuditor);
begin
  inherited Create;
  FConfig := AConfig;
  FBackend := AConfig.Backend;
  FAuditor := TBodyZeroAuditorImpl(AAuditor);
  FIsOpen := False;
end;

destructor TExternalSQLiteReader.Destroy;
begin
  Close;
  FBCryptReader.Free;
  inherited;
end;

procedure TExternalSQLiteReader.SetAdapterRegistry(const ARegistry: ISchemaAdapterRegistry);
begin
  FAdapterRegistry := ARegistry;
end;

function TExternalSQLiteReader.TryResolveAdapter(const Fingerprint: string): Boolean;
begin
  if FAdapterRegistry = nil then
  begin
    Logger.Warn('ISchemaAdapterRegistry not injected, skipping adapter resolution', 'ExternalDB');
    Exit(True);
  end;
  var Adapter: ISchemaAdapter;
  Result := FAdapterRegistry.TryResolve(Fingerprint, '', Adapter);
end;

// ===== Backend: FireDAC =====

function TExternalSQLiteReader.LoadSQLCipherLibrary: Boolean;
begin
  FDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  FDriverLink.VendorLib := ExtractFilePath(ParamStr(0)) + 'sqlite3_sqlcipher_x64.dll';
  Result := FileExists(FDriverLink.VendorLib);
end;

procedure TExternalSQLiteReader.ApplyFireDACConnection(const DbPath: string;
  const KeyBytes: TBytes);
begin
  FConnection := TFDConnection.Create(nil);
  FConnection.Params.Values['Database'] := DbPath;
  FConnection.Params.Values['OpenMode'] := 'ReadOnly';

  // Convert key to hex string for SQLCipher raw key
  var HexKey := '';
  for var B in KeyBytes do
    HexKey := HexKey + IntToHex(B, 2);

  // Set SQLCipher key / cipher params via FireDAC connection params
  // (FireDAC passes these to the SQLite driver before reading data)
  FConnection.Params.Values['Encrypt'] := FConfig.Cipher;
  FConnection.Params.Values['Password'] := HexKey;

  FConnection.Open;

  try
    FConnection.ExecSQL('SELECT count(*) FROM sqlite_master');
  except
    on E: Exception do
    begin
      FConnection.Free;
      FConnection := nil;
      raise EExternalDBError.CreateFmt('Key verification failed: %s', [E.Message]);
    end;
  end;

  FSchemaVersionAtOpen := QueryPragmaInt('schema_version');
  FIsOpen := True;
  FDbPath := DbPath;
end;

// ===== Backend: BCryptDirect (from WxDecryptProbe verified implementation) =====

procedure TExternalSQLiteReader.ApplyBCryptConnection(const DbPath: string;
  const KeyBytes: TBytes);
begin
  // Read salt from DB file (first 16 bytes)
  var Salt: TBytes;
  SetLength(Salt, 16);
  var FS := TFileStream.Create(DbPath, fmOpenRead or fmShareDenyNone);
  try
    FS.Read(Salt[0], 16);
  finally
    FS.Free;
  end;

  // Derive keys via BCrypt PBKDF2-HMAC-SHA1
  FBCryptReader := TBCryptSQLiteReader.Create(KeyBytes, Salt);
  try
    if not FBCryptReader.OpenDatabase(DbPath) then
    begin
      FreeAndNil(FBCryptReader);
      raise EExternalDBError.Create('BCrypt decryption failed: HMAC verification mismatch');
    end;

    // Connect FireDAC to the decrypted copy
    FConnection := TFDConnection.Create(nil);
    FConnection.Params.Values['Database'] := FBCryptReader.DecryptedPath;
    FConnection.Params.Values['OpenMode'] := 'ReadOnly';
    FConnection.Open;

    try
      FConnection.ExecSQL('SELECT count(*) FROM sqlite_master');
    except
      on E: Exception do
      begin
        FConnection.Free;
        FConnection := nil;
        raise EExternalDBError.CreateFmt('Decrypted DB verification failed: %s', [E.Message]);
      end;
    end;

    FSchemaVersionAtOpen := QueryPragmaInt('schema_version');
    FIsOpen := True;
    FDbPath := DbPath;
  except
    on E: Exception do
    begin
      FreeAndNil(FBCryptReader);
      raise;
    end;
  end;
end;

function TExternalSQLiteReader.OpenReadOnly(const DbPath: string;
  const KeyBytes: TBytes): IExternalDBReader;
begin
  if FBackend = beBCryptDirect then
    ApplyBCryptConnection(DbPath, KeyBytes)
  else
  begin
    if not LoadSQLCipherLibrary then
      raise EExternalDBError.Create('Cannot load SQLCipher library');
    ApplyFireDACConnection(DbPath, KeyBytes);
  end;
  Result := Self;
end;

procedure TExternalSQLiteReader.ApplyReadOnlySafeguards;
begin
  // No-op: ReadOnly constraints are enforced via OpenMode='ReadOnly' + IsWriteStatement check
end;

function TExternalSQLiteReader.GetRawSQLiteHandle: Pointer;
begin
  Result := nil;
end;

// ===== IExternalDBReader core — see OpenReadOnly above in BCrypt section =====
// OpenWithKeyCallback is unchanged from previous implementation

function TExternalSQLiteReader.OpenWithKeyCallback(const DbPath: string;
  const KeyCallback: TFunc<string, TBytes>): IExternalDBReader;
begin
  var KeyBytes: TBytes := KeyCallback(DbPath);
  try
    Result := OpenReadOnly(DbPath, KeyBytes);
  finally
    if Length(KeyBytes) > 0 then
      FillChar(KeyBytes[0], Length(KeyBytes), 0);
  end;
end;

function TExternalSQLiteReader.QueryPragmaInt(const PragmaName: string): Integer;
begin
  Result := 0;
  if FConnection = nil then Exit;
  var Q := TFDQuery.Create(FConnection);
  try
    Q.Open(Format('PRAGMA %s', [PragmaName]));
    if not Q.Eof then
      Result := Q.Fields[0].AsInteger;
  finally
    Q.Free;
  end;
end;

function TExternalSQLiteReader.GetSchema: TExternalDBSchema;
begin
  Result.DbPath := FDbPath;
  if not FIsOpen then Exit;

  var Q := TFDQuery.Create(FConnection);
  try
    Q.Open('SELECT name FROM sqlite_master ' +
           'WHERE type=''table'' AND name NOT LIKE ''sqlite_%'' ORDER BY name');
    var TableList := TList<TTableInfo>.Create;
    try
      while not Q.Eof do
      begin
        var Table: TTableInfo;
        Table.Name := Q.Fields[0].AsString;
        Table.RowCount := 0;

        var ColQ := TFDQuery.Create(FConnection);
        try
          ColQ.Open(Format('PRAGMA table_info(''%s'')', [Table.Name]));
          var ColList := TList<TColumnInfo>.Create;
          try
            while not ColQ.Eof do
            begin
              var Col: TColumnInfo;
              Col.Name := ColQ.Fields[1].AsString;
              Col.DataType := ColQ.Fields[2].AsString;
              Col.IsBodyColumn := False;
              Col.IsPII := False;
              ColList.Add(Col);
              ColQ.Next;
            end;
            Table.Columns := ColList.ToArray;
          finally
            ColList.Free;
          end;
        finally
          ColQ.Free;
        end;

        TableList.Add(Table);
        Q.Next;
      end;

      Result.Tables := TableList.ToArray;
    finally
      TableList.Free;
    end;
  finally
    Q.Free;
  end;

  Result.SchemaFingerprint := GetSchemaFingerprint;
end;

function TExternalSQLiteReader.GetSchemaFingerprint: string;
begin
  Result := '';
  if not FIsOpen then Exit;

  var SB := TStringBuilder.Create;
  try
    var Q := TFDQuery.Create(FConnection);
    try
      Q.Open('SELECT name FROM sqlite_master ' +
             'WHERE type=''table'' AND name NOT LIKE ''sqlite_%'' ORDER BY name');
      while not Q.Eof do
      begin
        var TableName := Q.Fields[0].AsString;
        SB.Append(TableName).Append('(');

        var ColQ := TFDQuery.Create(FConnection);
        try
          ColQ.Open(Format('PRAGMA table_info(''%s'')', [TableName]));
          while not ColQ.Eof do
          begin
            SB.Append(ColQ.Fields[1].AsString).Append(':');
            SB.Append(ColQ.Fields[2].AsString).Append(',');
            ColQ.Next;
          end;
        finally
          ColQ.Free;
        end;

        SB.Append(')');
        Q.Next;
      end;

      Result := THashSHA2.GetHashString(SB.ToString, SHA256);
    finally
      Q.Free;
    end;
  finally
    SB.Free;
  end;
end;

function TExternalSQLiteReader.SafeQuery(const TableName: string;
  const ColumnNames: TArray<string>): TFDQuery;
begin
  if not FIsOpen then
    raise EExternalDBError.Create('Database not open');

  // === Audit (non-blocking) ===
  try
    for var Col in ColumnNames do
      FAuditor.RecordColumnAccess(Col);
    for var Col in ColumnNames do
      if FSchema.IsBodyColumn(TableName, Col) then
        Logger.WarnFmt('BodyZero: body column %s.%s accessed', [TableName, Col], 'ExternalDB');
  except
    on E: Exception do
    begin
      Logger.ErrorFmt('Audit record failed (non-blocking): %s', [E.Message], 'ExternalDB');
      FAuditor.IncrementFaultCount;
      if FAuditor.IsFaulted then
        Logger.Fatal('BodyZero audit disabled due to consecutive failures', 'ExternalDB');
    end;
  end;

  // === Schema version check ===
  var CurrentVer := QueryPragmaInt('schema_version');
  if CurrentVer <> FSchemaVersionAtOpen then
  begin
    Logger.WarnFmt('Schema version changed: %d -> %d, refreshing fingerprint',
      [FSchemaVersionAtOpen, CurrentVer], 'ExternalDB');
    FSchemaVersionAtOpen := CurrentVer;
    var NewFingerprint := GetSchemaFingerprint;
    if not TryResolveAdapter(NewFingerprint) then
      raise EExternalSchemaChanged.CreateFmt(
        'Schema changed to fingerprint %s, no matching adapter', [NewFingerprint]);
  end;

  // === SQLITE_BUSY retry ===
  var MaxRetries := 5;
  var BaseDelayMs := 200;
  for var Retry := 1 to MaxRetries + 1 do
  begin
    try
      var SQL := Format('SELECT %s FROM %s', [string.Join(',', ColumnNames), TableName]);
      try
        if IsWriteStatement(SQL) then
        begin
          FAuditor.IncrementWriteAttempts;
          raise EWriteAttemptBlocked.Create('Write blocked on external database');
        end;
      except
        on E: EWriteAttemptBlocked do raise;
        on E: Exception do
          Logger.ErrorFmt('Write-check failed (non-blocking): %s', [E.Message], 'ExternalDB');
      end;

      Result := TFDQuery.Create(FConnection);
      Result.Open(SQL);
      Exit;
    except
      on E: EFDDBEngineException do
      begin
        if (Retry > MaxRetries) or (E.Kind <> ekRecordLocked) then
          raise EExternalDBBusy.CreateFmt(
            'Database busy after %d retries (wait for WeChat to finish)', [MaxRetries]);
        Sleep(BaseDelayMs shl (Retry - 1));
      end;
      on E: EWriteAttemptBlocked do raise;
      on E: EExternalSchemaChanged do raise;
    end;
  end;
end;

function TExternalSQLiteReader.SafeQueryAsDict(const TableName: string;
  const ColumnNames: TArray<string>): TArray<TDictionary<string, Variant>>;
begin
  var Q := SafeQuery(TableName, ColumnNames);
  try
    var RowList := TList<TDictionary<string, Variant>>.Create;
    try
      while not Q.Eof do
      begin
        var RowDict := TDictionary<string, Variant>.Create(Length(ColumnNames));
        for var ColName in ColumnNames do
          RowDict.Add(ColName, Q.FieldByName(ColName).AsVariant);
        RowList.Add(RowDict);
        Q.Next;
      end;
      Result := RowList.ToArray;
    finally
      RowList.Free;
    end;
  finally
    Q.Free;
  end;
end;

procedure TExternalSQLiteReader.Close;
begin
  if Assigned(FConnection) then
  begin
    FConnection.Free;
    FConnection := nil;
  end;
  if Assigned(FDriverLink) then
  begin
    FDriverLink.Free;
    FDriverLink := nil;
  end;
  FIsOpen := False;
end;

function TExternalSQLiteReader.IsOpen: Boolean;
begin
  Result := FIsOpen;
end;

function TExternalSQLiteReader.GetCompatibilityReport: string;
begin
  Result := Format('Backend: %d, Cipher: %s, PageSize: %d, DB: %s',
    [Ord(FBackend), FConfig.Cipher, FConfig.PageSize, FDbPath]);
end;

// ===== IBodyZeroAuditor delegates =====

procedure TExternalSQLiteReader.RecordColumnAccess(const ColumnName: string);
begin
  FAuditor.RecordColumnAccess(ColumnName);
end;

function TExternalSQLiteReader.GetQueriedColumns: TArray<string>;
begin
  Result := FAuditor.GetQueriedColumns;
end;

function TExternalSQLiteReader.GetBodyColumnsSeen: Boolean;
begin
  Result := FAuditor.GetBodyColumnsSeen;
end;

function TExternalSQLiteReader.GetWriteAttempts: Integer;
begin
  Result := FAuditor.GetWriteAttempts;
end;

function TExternalSQLiteReader.GetUIACallCount: Integer;
begin
  Result := FAuditor.GetUIACallCount;
end;

function TExternalSQLiteReader.IsFaulted: Boolean;
begin
  Result := FAuditor.IsFaulted;
end;

procedure TExternalSQLiteReader.IncrementFaultCount;
begin
  FAuditor.IncrementFaultCount;
end;

procedure TExternalSQLiteReader.IncrementWriteAttempts;
begin
  FAuditor.IncrementWriteAttempts;
end;

procedure TExternalSQLiteReader.RecordRawSQLAccess(const SQL: string);
begin
  FAuditor.RecordRawSQLAccess(SQL);
end;

procedure TExternalSQLiteReader.RecordUIAOperation(const Path: string; const Value: string);
begin
  FAuditor.RecordUIAOperation(Path, Value);
end;

procedure TExternalSQLiteReader.Reset;
begin
  FAuditor.Reset;
end;

function TExternalSQLiteReader.GenerateBodyZeroReport: TBodyZeroReport;
begin
  Result := FAuditor.GenerateBodyZeroReport;
end;

end.
