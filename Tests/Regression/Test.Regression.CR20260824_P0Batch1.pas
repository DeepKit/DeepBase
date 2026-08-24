{ ============================================================================
  Test.Regression.CR20260824_P0Batch1 - Full-repo audit 2026-08-24, P0 batch 1

  Covers:
  - CR-011: TSecureRandom.NextDouble used (1 shl 53) which shifts as 32-bit
    ordinal (= 1 shl 21), inflating output domain to [0, 4.3e9].
    After fix all values must fall in [0, 1).
  - CR-010: IPermissionClient shared template placeholder GUID
    A1B2C3D4-E5F6-7890-ABCD-EF1234567890 with IRateLimiter, making
    GUID-based interface queries ambiguous.
  - CR-004: TDbContext.CollectEntityParams skipped ALL primary keys while
    BuildInsertSQL only skips autoincrement PKs -> INSERT params shifted by
    one for entities with non-autoincrement PK. After fix placeholder count
    must equal param count.
  ============================================================================ }

unit Test.Regression.CR20260824_P0Batch1;

interface

uses
  System.SysUtils,
  System.TypInfo,
  Data.DB,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.Random,
  DeepBase.RateLimiter,
  DeepBase.Permissions.Contract,
  DeepBase.ORM.Mapping,
  DeepBase.ORM;

type
  // Entity with non-autoincrement (natural) primary key
  [Table('cr004_docs')]
  TCR004Doc = class
  private
    [PrimaryKey(False)]
    [Column('doc_id')]
    FDocId: string;
    [Column('title')]
    FTitle: string;
    [Column('body')]
    FBody: string;
  public
    property DocId: string read FDocId write FDocId;
    property Title: string read FTitle write FTitle;
    property Body: string read FBody write FBody;
  end;

  /// <summary>Storage stub that captures Execute(SQL, Params)</summary>
  TCaptureStorage = class(TInterfacedObject, IORMStorage)
  public
    LastSQL: string;
    LastParams: TArray<Variant>;
    function Execute(const SQL: string; const Params: array of Variant): Integer;
    function OpenDataSet(const SQL: string; const Params: array of Variant): TDataSet;
    function ExecuteScalar(const SQL: string; const Params: array of Variant): Variant;
    function BeginTransaction: IORMTransaction;
    function GetLastAutoGenValue(const AGeneratorName: string): Variant;
  end;

  [TestFixture]
  [Category('regression')]
  TCR20260824P0Batch1Test = class(TRegressionTestBase)
  private const
    OldSharedPlaceholderGuid = '{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}';
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    procedure Test_CR011_NextDouble_InUnitRange;

    [Test]
    procedure Test_CR010_InterfaceGuids_DistinctAndNotPlaceholder;

    [Test]
    procedure Test_CR004_NonAutoIncrementPk_InsertParamsAligned;
  end;

implementation

uses
  System.Variants;

{ TCaptureStorage }

function TCaptureStorage.Execute(const SQL: string;
  const Params: array of Variant): Integer;
var
  I: Integer;
begin
  LastSQL := SQL;
  SetLength(LastParams, Length(Params));
  for I := 0 to High(Params) do
    LastParams[I] := Params[I];
  Result := 1;
end;

function TCaptureStorage.OpenDataSet(const SQL: string;
  const Params: array of Variant): TDataSet;
begin
  Result := nil;
end;

function TCaptureStorage.ExecuteScalar(const SQL: string;
  const Params: array of Variant): Variant;
begin
  Result := Null;
end;

function TCaptureStorage.BeginTransaction: IORMTransaction;
begin
  Result := nil;
end;

function TCaptureStorage.GetLastAutoGenValue(const AGeneratorName: string): Variant;
begin
  Result := 0;
end;

{ TCR20260824P0Batch1Test }

function TCR20260824P0Batch1Test.GetBugNumber: string;
begin
  Result := 'CR-004/CR-010/CR-011';
end;

function TCR20260824P0Batch1Test.GetBugDescription: string;
begin
  Result := 'Audit 2026-08-24 P0 batch: NextDouble domain inflation / interface GUID clash / ORM PK param misalignment';
end;

function TCR20260824P0Batch1Test.GetFixDate: string;
begin
  Result := '2026-08-24';
end;

function TCR20260824P0Batch1Test.GetPriority: string;
begin
  Result := 'P0';
end;

function TCR20260824P0Batch1Test.GetAffectedFile: string;
begin
  Result := 'Core\DeepBase.Random.pas; Core\DeepBase.Permissions.Contract.pas; Persistence\DeepBase.ORM.pas';
end;

procedure TCR20260824P0Batch1Test.Test_CR011_NextDouble_InUnitRange;
const
  SampleCount = 100000;
var
  I: Integer;
  V: Double;
  SawDifferent: Boolean;
  First: Double;
  SR: TSecureRandom;
begin
  SR := TSecureRandom.Instance;
  First := SR.NextDouble;
  SawDifferent := False;
  for I := 0 to SampleCount - 1 do
  begin
    V := SR.NextDouble;
    Assert.IsTrue((V >= 0.0) and (V < 1.0),
      Format('NextDouble out of range: %.6f (pre-fix shift bug could return ~4e9)', [V]));
    if V <> First then
      SawDifferent := True;
  end;
  Assert.IsTrue(SawDifferent, 'NextDouble output constant, generator broken');
end;

procedure TCR20260824P0Batch1Test.Test_CR010_InterfaceGuids_DistinctAndNotPlaceholder;
var
  PermGuid, RateGuid, OldGuid: TGUID;
begin
  PermGuid := GetTypeData(TypeInfo(IPermissionClient)).Guid;
  RateGuid := GetTypeData(TypeInfo(IRateLimiter)).Guid;
  OldGuid := StringToGUID(OldSharedPlaceholderGuid);

  Assert.IsFalse(IsEqualGUID(PermGuid, RateGuid),
    'IPermissionClient and IRateLimiter still share the same GUID');
  Assert.IsFalse(IsEqualGUID(PermGuid, OldGuid),
    'IPermissionClient still uses the old placeholder GUID');
  // IRateLimiter keeps its original GUID for compatibility; not asserted here.
end;

procedure TCR20260824P0Batch1Test.Test_CR004_NonAutoIncrementPk_InsertParamsAligned;
var
  Storage: TCaptureStorage;
  Context: TDbContext;
  Doc: TCR004Doc;
  PlaceholderCount, I: Integer;
begin
  Storage := TCaptureStorage.Create;
  Context := TDbContext.Create(Storage as IORMStorage);
  try
    Doc := TCR004Doc.Create;
    try
      Doc.DocId := 'D-0001';
      Doc.Title := 't';
      Doc.Body := 'b';
      Context.Insert<TCR004Doc>(Doc);
    finally
      Doc.Free;
    end;

    // INSERT columns: doc_id (non-autoinc PK) + title + body => 3 placeholders
    PlaceholderCount := 0;
    for I := 2 to Length(Storage.LastSQL) do
      if (Storage.LastSQL[I] = ':') and
         (not CharInSet(Storage.LastSQL[I - 1], ['''', ':'])) then
        Inc(PlaceholderCount);

    Assert.Contains(Storage.LastSQL, 'doc_id',
      'INSERT missing non-autoincrement PK column doc_id');
    Assert.AreEqual<Integer>(Length(Storage.LastParams), PlaceholderCount,
      Format('Placeholder count(%d) <> param count(%d) - misalignment regression',
        [PlaceholderCount, Length(Storage.LastParams)]));
    Assert.AreEqual<Integer>(3, Length(Storage.LastParams),
      'Non-autoincrement PK entity must submit all 3 field params');
  finally
    Context.Free;
    TMetadataCache.ClearCache;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCR20260824P0Batch1Test);

end.
