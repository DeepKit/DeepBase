{ ============================================================================
  DeepBase.External.Types - External Database Type Definitions
  Version: 0.7
  ============================================================================ }

unit DeepBase.External.Types;

interface

uses
  System.SysUtils, System.Generics.Collections;

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
  Result.SqlcipherVersion := '3.4.3';  // v0.7 fix: assign version
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
  Result.SqlcipherVersion := '3.4.3';  // v0.7 fix: assign version
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
  Result.SqlcipherVersion := '4.5.x';  // v0.7 fix: assign version
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
