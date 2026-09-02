{ ============================================================================
  DeepBase.External.Types - External Database Type Definitions
  Version: 0.7
  ============================================================================ }

unit DeepBase.External.Types;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.Hash;

type
  TDecryptBackend = (beFireDAC, beBCryptDirect);

  TSQLCipherCompatibilityConfig = record
    Backend: TDecryptBackend;
    Cipher: string;
    KdfIter: Integer;
    CipherPageSize: Integer;
    HmacAlgorithm: string;
    KdfAlgorithm: string;
    SqlcipherVersion: string;
    PageSize: Integer;
    KeySize: Integer;
    IvSize: Integer;
    HmacSize: Integer;
    SaltSize: Integer;
    ReserveAlgorithm: string;
  end;

  TColumnInfo = record
    Name: string;
    DataType: string;
    IsBodyColumn: Boolean;
    IsPII: Boolean;
  end;

  TTableInfo = record
    Name: string;
    Columns: TArray<TColumnInfo>;
    RowCount: Int64;
  end;

  TExternalDBSchema = record
    DbPath: string;
    DbSize: Int64;
    Tables: TArray<TTableInfo>;
    SchemaFingerprint: string;
    function IsBodyColumn(const TableName, ColumnName: string): Boolean;
    function IsPiiColumn(const TableName, ColumnName: string): Boolean;
  end;

  TBodyZeroReport = record
    BodyColumnsSeen: Boolean;
    WriteAttempts: Integer;
    UIACallCount: Integer;
    QueriedColumns: TArray<string>;
    Faulted: Boolean;
    CompatibilityReport: string;
  end;

  TKeyCandidate = record
    Key: TBytes;
    Address: UInt64;
    Entropy: Double;
  end;

function WeChat39xCipherConfig: TSQLCipherCompatibilityConfig;
function WeChat4xCipherConfig: TSQLCipherCompatibilityConfig;
function IsWriteStatement(const SQL: string): Boolean;

/// <summary>
/// Column-signature SSOT helpers (shared by SQLiteReader full fingerprint and
/// Msg column-signature fingerprint). Each column is ``name:type,`` including
/// a trailing comma after the last column; whole signature is wrapped in ``()``.
/// </summary>
procedure AppendColumnSignatureEntries(SB: TStringBuilder;
  const ANames, ATypes: TArray<string>);
function FormatColumnSignature(const ANames, ATypes: TArray<string>): string;
function HashColumnSignatureFingerprint(const AColumnSignature: string): string;

implementation

function WeChat39xCipherConfig: TSQLCipherCompatibilityConfig;
begin
  Result.Backend := beBCryptDirect;
  Result.Cipher := 'aes-256-cbc';
  Result.KdfIter := 64000;
  Result.CipherPageSize := 1024;
  Result.HmacAlgorithm := 'HMAC_SHA1';
  Result.KdfAlgorithm := 'PBKDF2_HMAC_SHA1';
  Result.PageSize := 4096;
  Result.KeySize := 32;
  Result.IvSize := 16;
  Result.HmacSize := 20;
  Result.SaltSize := 16;
  Result.ReserveAlgorithm := 'HMAC_SHA1';
end;

function WeChat4xCipherConfig: TSQLCipherCompatibilityConfig;
begin
  Result.Backend := beBCryptDirect;
  Result.Cipher := 'aes-256-cbc';
  Result.KdfIter := 64000;
  Result.CipherPageSize := 4096;
  Result.HmacAlgorithm := 'HMAC_SHA1';
  Result.KdfAlgorithm := 'PBKDF2_HMAC_SHA1';
  Result.PageSize := 4096;
  Result.KeySize := 32;
  Result.IvSize := 16;
  Result.HmacSize := 20;
  Result.SaltSize := 16;
  Result.ReserveAlgorithm := 'HMAC_SHA1';
end;

function IsWriteStatement(const SQL: string): Boolean;
var
  TrimmedUpper: string;
begin
  TrimmedUpper := SQL.Trim.ToUpper;
  Result := TrimmedUpper.StartsWith('INSERT') or
            TrimmedUpper.StartsWith('UPDATE') or
            TrimmedUpper.StartsWith('DELETE') or
            TrimmedUpper.StartsWith('DROP')   or
            TrimmedUpper.StartsWith('ALTER')  or
            TrimmedUpper.StartsWith('CREATE') or
            TrimmedUpper.StartsWith('ATTACH') or
            TrimmedUpper.StartsWith('DETACH') or
            (TrimmedUpper.Contains('PRAGMA') and
             (TrimmedUpper.Contains('JOURNAL_MODE') or
              TrimmedUpper.Contains('WAL_CHECKPOINT') or
              TrimmedUpper.Contains('OPTIMIZE') or
              TrimmedUpper.Contains('SHRINK_MEMORY')));
end;

procedure AppendColumnSignatureEntries(SB: TStringBuilder;
  const ANames, ATypes: TArray<string>);
var
  I: Integer;
begin
  if Length(ANames) <> Length(ATypes) then
    raise EArgumentException.Create(
      'AppendColumnSignatureEntries: name/type array length mismatch');
  for I := 0 to High(ANames) do
    SB.Append(ANames[I]).Append(':').Append(ATypes[I]).Append(',');
end;

function FormatColumnSignature(const ANames, ATypes: TArray<string>): string;
var
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('(');
    AppendColumnSignatureEntries(SB, ANames, ATypes);
    SB.Append(')');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function HashColumnSignatureFingerprint(const AColumnSignature: string): string;
begin
  Result := LowerCase(THashSHA2.GetHashString(AColumnSignature, SHA256));
end;

{ TExternalDBSchema }

function TExternalDBSchema.IsBodyColumn(const TableName, ColumnName: string): Boolean;
begin
  for var Table in Tables do
    if SameText(Table.Name, TableName) then
      for var Col in Table.Columns do
        if SameText(Col.Name, ColumnName) then
          Exit(Col.IsBodyColumn);
  Result := False;
end;

function TExternalDBSchema.IsPiiColumn(const TableName, ColumnName: string): Boolean;
begin
  for var Table in Tables do
    if SameText(Table.Name, TableName) then
      for var Col in Table.Columns do
        if SameText(Col.Name, ColumnName) then
          Exit(Col.IsPII);
  Result := False;
end;

end.
