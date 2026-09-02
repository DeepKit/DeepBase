{ ============================================================================
  DeepBase.External.SQLiteReader - SQLCipher External Database Reader
  Version: 0.7 — Dual-backend (FireDAC + BCryptDirect)
  ============================================================================ }

unit DeepBase.External.SQLiteReader;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Variants, System.Hash, System.Math, System.IOUtils,
  System.Character,
  FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Stan.Error,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  DeepBase.Types, DeepBase.Exceptions, DeepBase.Logging,
  DeepBase.External.Types, DeepBase.External.Auditor,
  DeepBase.External.BCryptDecrypt,
  DeepBase.SchemaAdapter, DeepBase.SchemaAdapter.Registry;

/// <summary>Append PRAGMA table_info rows via External.Types SSOT column format.</summary>
procedure AppendColumnSignatureEntriesFromQuery(SB: TStringBuilder; ColQ: TFDQuery);

type
  IExternalDBReader = interface
    ['{A86F1C3E-7D2B-4F92-8E15-3C6B09A4F7D2}']
    function OpenReadOnly(const DbPath: string; const KeyBytes: TBytes): IExternalDBReader;
    function OpenWithKeyCallback(const DbPath: string;
      const KeyCallback: TFunc<string, TBytes>): IExternalDBReader;
    function GetSchema: TExternalDBSchema;
    function GetSchemaFingerprint: string;
    function GetMessageColumnSignatureFingerprint: string;
    function SafeQuery(const TableName: string;
      const ColumnNames: TArray<string>): TFDQuery;
    function SafeQueryAsDict(const TableName: string;
      const ColumnNames: TArray<string>): TArray<TDictionary<string, Variant>>;
    function SafeQueryMessages(const ColumnNames: TArray<string>):
      TArray<TDictionary<string, Variant>>;
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
    FMaxFileSizeBytes: Int64;
    FMaxRows: Integer;
    function LoadSQLCipherLibrary: Boolean;
    procedure ApplyReadOnlySafeguards;
    function GetRawSQLiteHandle: Pointer;
    function TryResolveAdapter(const Fingerprint: string): Boolean;
    procedure ResolveAdapterOrRaise;
    procedure ApplyFireDACConnection(const DbPath: string; const KeyBytes: TBytes);
    procedure ApplyBCryptConnection(const DbPath: string; const KeyBytes: TBytes);
  public
    constructor Create(const AConfig: TSQLCipherCompatibilityConfig;
      const AAuditor: IBodyZeroAuditor);
    destructor Destroy; override;
    procedure SetAdapterRegistry(const ARegistry: ISchemaAdapterRegistry);
    property MaxFileSizeBytes: Int64 read FMaxFileSizeBytes write FMaxFileSizeBytes;
    property MaxRows: Integer read FMaxRows write FMaxRows;
    // IExternalDBReader
    function OpenReadOnly(const DbPath: string; const KeyBytes: TBytes): IExternalDBReader;
    function OpenWithKeyCallback(const DbPath: string;
      const KeyCallback: TFunc<string, TBytes>): IExternalDBReader;
    function GetSchema: TExternalDBSchema;
    function GetSchemaFingerprint: string;
    function GetMessageColumnSignatureFingerprint: string;
    function SafeQuery(const TableName: string;
      const ColumnNames: TArray<string>): TFDQuery;
    function SafeQueryAsDict(const TableName: string;
      const ColumnNames: TArray<string>): TArray<TDictionary<string, Variant>>;
    function SafeQueryMessages(const ColumnNames: TArray<string>):
      TArray<TDictionary<string, Variant>>;
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

procedure AppendColumnSignatureEntriesFromQuery(SB: TStringBuilder; ColQ: TFDQuery);
var
  Names, Types: TList<string>;
begin
  // Collect then delegate to External.Types SSOT (single name:type, format).
  Names := TList<string>.Create;
  Types := TList<string>.Create;
  try
    while not ColQ.Eof do
    begin
      Names.Add(ColQ.Fields[1].AsString);
      Types.Add(ColQ.Fields[2].AsString);
      ColQ.Next;
    end;
    AppendColumnSignatureEntries(SB, Names.ToArray, Types.ToArray);
  finally
    Names.Free;
    Types.Free;
  end;
end;

constructor TExternalSQLiteReader.Create(const AConfig: TSQLCipherCompatibilityConfig;
  const AAuditor: IBodyZeroAuditor);
begin
  inherited Create;
  FConfig := AConfig;
  FBackend := AConfig.Backend;
  FAuditor := TBodyZeroAuditorImpl(AAuditor);
  FIsOpen := False;
  FMaxFileSizeBytes := 100 * 1024 * 1024;  // 100 MB default
  FMaxRows := 1000000;                      // 1,000,000 rows default
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
  // Empty column-signature fingerprint must not reach Registry (no false match).
  if Fingerprint = '' then
  begin
    Logger.Warn(
      'Message column-signature fingerprint empty (no Msg_* tables or inconsistent); skip resolve',
      'ExternalDB');
    Exit(True);
  end;
  var Adapter: ISchemaAdapter;
  Result := FAdapterRegistry.TryResolve(Fingerprint, '', Adapter);
end;

procedure TExternalSQLiteReader.ResolveAdapterOrRaise;
var
  FullFp, ColFp: string;
begin
  FullFp := GetSchemaFingerprint;
  ColFp := GetMessageColumnSignatureFingerprint;
  if ColFp = '' then
  begin
    Logger.WarnFmt(
      'Skip adapter resolve: empty Msg column signature (fullFp=%s)', [FullFp], 'ExternalDB');
    Exit;
  end;
  if not TryResolveAdapter(ColFp) then
    raise EExternalSchemaChanged.CreateFmt(
      'No matching SchemaAdapter; fullFingerprint=%s columnSignatureFingerprint=%s',
      [FullFp, ColFp]);
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
  // Enforce file size limit before opening (DATA2-016)
  if not FileExists(DbPath) then
    raise EExternalDBError.CreateFmt('Database file not found: %s', [DbPath]);
  var FileSize := TFile.GetSize(DbPath);
  if FileSize > FMaxFileSizeBytes then
    raise ESQLiteReaderLimitExceeded.CreateFmt(
      'Database file size (%d bytes) exceeds limit (%d bytes): %s',
      [FileSize, FMaxFileSizeBytes, DbPath]);

  if FBackend = beBCryptDirect then
    ApplyBCryptConnection(DbPath, KeyBytes)
  else
  begin
    if not LoadSQLCipherLibrary then
      raise EExternalDBError.Create('Cannot load SQLCipher library');
    ApplyFireDACConnection(DbPath, KeyBytes);
  end;
  // Cache schema so SafeQueryMessages can enumerate shard tables without
  // re-querying sqlite_master on every call (BUG-330 / REVIEW5-DATA-001).
  FSchema := GetSchema;
  // Resolve with Msg column-signature fingerprint (not full schema fingerprint).
  ResolveAdapterOrRaise;
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
          AppendColumnSignatureEntriesFromQuery(SB, ColQ);
        finally
          ColQ.Free;
        end;

        SB.Append(')');
        Q.Next;
      end;

      // Full fingerprint keeps historical casing; adapters match on column-sig path.
      Result := THashSHA2.GetHashString(SB.ToString, SHA256);
    finally
      Q.Free;
    end;
  finally
    SB.Free;
  end;
end;

function TExternalSQLiteReader.GetMessageColumnSignatureFingerprint: string;
var
  Q, ColQ: TFDQuery;
  TableName, ThisSig, CommonSig: string;
  SB: TStringBuilder;
  MsgCount: Integer;
begin
  Result := '';
  if not FIsOpen then Exit;

  CommonSig := '';
  MsgCount := 0;
  Q := TFDQuery.Create(FConnection);
  try
    Q.Open('SELECT name FROM sqlite_master ' +
           'WHERE type=''table'' AND name LIKE ''Msg_%'' ORDER BY name');
    while not Q.Eof do
    begin
      TableName := Q.Fields[0].AsString;
      SB := TStringBuilder.Create;
      try
        SB.Append('(');
        ColQ := TFDQuery.Create(FConnection);
        try
          ColQ.Open(Format('PRAGMA table_info(''%s'')', [TableName]));
          AppendColumnSignatureEntriesFromQuery(SB, ColQ);
        finally
          ColQ.Free;
        end;
        SB.Append(')');
        ThisSig := SB.ToString;
      finally
        SB.Free;
      end;

      if MsgCount = 0 then
        CommonSig := ThisSig
      else if ThisSig <> CommonSig then
      begin
        Logger.WarnFmt(
          'Msg_* column signatures inconsistent (table=%s); refusing fingerprint',
          [TableName], 'ExternalDB');
        Exit('');
      end;
      Inc(MsgCount);
      Q.Next;
    end;
  finally
    Q.Free;
  end;

  if MsgCount = 0 then
    Exit('');

  Result := HashColumnSignatureFingerprint(CommonSig);
end;

function TExternalSQLiteReader.SafeQuery(const TableName: string;
  const ColumnNames: TArray<string>): TFDQuery;

  // Validate and quote a SQLite identifier (REVIEW5-DATA-002).
  // Rejects: empty, wildcards (*), SQL injection chars, expressions.
  // Returns double-quoted identifier safe for SQL interpolation.
  function QuoteIdentifier(const AIdent: string): string;
  var
    C: Char;
  begin
    if AIdent = '' then
      raise EExternalDBInvalidIdentifier.Create('Empty identifier');
    if AIdent = '*' then
      raise EExternalDBInvalidIdentifier.Create(
        'Wildcard (*) not allowed in SafeQuery; enumerate columns explicitly');
    for C in AIdent do
    begin
      if not (C.IsLetterOrDigit or (C = '_')) then
        raise EExternalDBInvalidIdentifier.CreateFmt(
          'Invalid character ''%s'' in identifier ''%s''', [C, AIdent]);
    end;
    // SQLite quoting: wrap in double quotes, escape embedded double quotes by doubling
    Result := '"' + AIdent.Replace('"', '""') + '"';
  end;

  function FindTable(const AName: string): Integer;
  begin
    for Result := 0 to High(FSchema.Tables) do
      if SameText(FSchema.Tables[Result].Name, AName) then
        Exit;
    Result := -1;
  end;

  function FindColumn(const ATableIdx: Integer; const AColName: string): Boolean;
  var
    LCol: TColumnInfo;
  begin
    for LCol in FSchema.Tables[ATableIdx].Columns do
      if SameText(LCol.Name, AColName) then
        Exit(True);
    Result := False;
  end;

var
  LTableIdx: Integer;
  LQuotedTable: string;
  LQuotedCols: TArray<string>;
  LCol: string;
  LSQL: string;
  I: Integer;
begin
  if not FIsOpen then
    raise EExternalDBError.Create('Database not open');

  // === Identifier validation against cached schema (REVIEW5-DATA-002) ===
  if Length(ColumnNames) = 0 then
    raise EExternalDBInvalidIdentifier.Create('ColumnNames must not be empty');

  LTableIdx := FindTable(TableName);
  if LTableIdx < 0 then
    raise EExternalDBInvalidIdentifier.CreateFmt(
      'Table ''%s'' not found in cached schema', [TableName]);

  for LCol in ColumnNames do
    if not FindColumn(LTableIdx, LCol) then
      raise EExternalDBInvalidIdentifier.CreateFmt(
        'Column ''%s'' not found in table ''%s''', [LCol, TableName]);

  // Build quoted identifiers
  LQuotedTable := QuoteIdentifier(TableName);
  SetLength(LQuotedCols, Length(ColumnNames));
  for I := 0 to High(ColumnNames) do
    LQuotedCols[I] := QuoteIdentifier(ColumnNames[I]);

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
    FSchema := GetSchema; // refresh cached schema (REVIEW5-DATA-001)
    // Re-resolve on Msg column signature (full fingerprint still drives change detect).
    ResolveAdapterOrRaise;
  end;

  // === SQLITE_BUSY retry ===
  var MaxRetries := 5;
  var BaseDelayMs := 200;
  for var Retry := 1 to MaxRetries + 1 do
  begin
    try
      LSQL := Format('SELECT %s FROM %s', [string.Join(',', LQuotedCols), LQuotedTable]);
      try
        if IsWriteStatement(LSQL) then
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
      Result.Open(LSQL);
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
      on E: EExternalDBInvalidIdentifier do raise;
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
        if RowList.Count >= FMaxRows then
          raise ESQLiteReaderLimitExceeded.CreateFmt(
            'Row limit (%d) reached for table ''%s''', [FMaxRows, TableName]);
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

function TExternalSQLiteReader.SafeQueryMessages(
  const ColumnNames: TArray<string>): TArray<TDictionary<string, Variant>>;
const
  CShardTableNames: array[0..5] of string = (
    'MSG', 'MSG0', 'MSG1', 'MSG2', 'MSG3', 'MSG4'
  );
begin
  SetLength(Result, 0);
  if not FIsOpen then
    raise EExternalDBError.Create('Database not open');

  for var TableName in CShardTableNames do
  begin
    // Check if the shard table exists in the schema
    var TableExists := False;
    for var Table in FSchema.Tables do
      if SameText(Table.Name, TableName) then
      begin
        TableExists := True;
        Break;
      end;
    if not TableExists then
      Continue;

    var ShardRows := SafeQueryAsDict(TableName, ColumnNames);
    if Length(ShardRows) > 0 then
    begin
      if Length(Result) + Length(ShardRows) > FMaxRows then
        raise ESQLiteReaderLimitExceeded.CreateFmt(
          'Row limit (%d) would be exceeded by shard table ''%s''',
          [FMaxRows, TableName]);
      var OldLen := Length(Result);
      SetLength(Result, OldLen + Length(ShardRows));
      for var I := 0 to High(ShardRows) do
        Result[OldLen + I] := ShardRows[I];
    end;
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
