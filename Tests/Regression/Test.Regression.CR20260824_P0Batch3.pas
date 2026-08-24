{ ============================================================================
  Test.Regression.CR20260824_P0Batch3 - Full-repo audit 2026-08-24, P0 batch 3

  Covers:
  - CR-016: TDateTime deserialization used locale-dependent StrToDateTime
    against a fixed-format serialized value ('yyyy-mm-dd"T"hh:nn:ss').
    On locales whose date word order differs (zh-CN, en-US, de-DE ...) the
    roundtrip produced wrong dates or EConvertError. After the fix parsing is
    ISO8601/Invariant based and locale independent.
  - CR-018: Enum deserialization accepted unknown names (GetEnumValue=-1) and
    arbitrary ordinals without range check -> invalid enum values silently
    written into business objects. After the fix both paths raise
    ESerializationException.
  ============================================================================ }

unit Test.Regression.CR20260824_P0Batch3;

interface

uses
  System.SysUtils,
  System.DateUtils,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.Serialization;

type
  TCR018Fruit = (frApple, frBanana, frCherry);

  [Serializable]
  TCR016Entity = class
  private
    FWhen: TDateTime;
    FFruit: TCR018Fruit;
  public
    [Serialize('when')]
    property When: TDateTime read FWhen write FWhen;
    [Serialize('fruit')]
    property Fruit: TCR018Fruit read FFruit write FFruit;
  end;

  [TestFixture]
  [Category('regression')]
  TCR20260824P0Batch3Test = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    procedure Test_CR016_DateRoundtrip_LocaleIndependent;

    [Test]
    procedure Test_CR016_UnparseableDate_RaisesSerializationException;

    [Test]
    procedure Test_CR018_EnumRoundtrip;

    [Test]
    procedure Test_CR018_UnknownEnumName_Raises;

    [Test]
    procedure Test_CR018_OutOfRangeOrdinal_Raises;
  end;

implementation

{ TCR20260824P0Batch3Test }

function TCR20260824P0Batch3Test.GetBugNumber: string;
begin
  Result := 'CR-016/CR-018';
end;

function TCR20260824P0Batch3Test.GetBugDescription: string;
begin
  Result := 'Locale-dependent datetime roundtrip + unchecked enum ordinals in serialization';
end;

function TCR20260824P0Batch3Test.GetFixDate: string;
begin
  Result := '2026-08-24';
end;

function TCR20260824P0Batch3Test.GetPriority: string;
begin
  Result := 'P0';
end;

function TCR20260824P0Batch3Test.GetAffectedFile: string;
begin
  Result := 'Core\DeepBase.Serialization.pas';
end;

procedure TCR20260824P0Batch3Test.Test_CR016_DateRoundtrip_LocaleIndependent;
var
  E1, E2: TCR016Entity;
  Json: string;
  ExpectedSecs: Int64;
begin
  E1 := TCR016Entity.Create;
  try
    E1.When := EncodeDateTime(2026, 8, 24, 14, 30, 45, 0);
    ExpectedSecs := Trunc(E1.When * SecsPerDay);
    Json := TSerializer.ToJson(E1);
  finally
    E1.Free;
  end;

  // Fixed template must be present regardless of machine locale settings
  Assert.Contains(Json, '2026-08-24T14:30:45',
    'serialized datetime must use the invariant fixed template');

  E2 := TCR016Entity(TSerializer.FromJson(Json, TCR016Entity));
  try
    Assert.AreEqual(ExpectedSecs, Trunc(E2.When * SecsPerDay),
      'datetime must survive a serialize/deserialize roundtrip on any locale');
  finally
    E2.Free;
  end;
end;

procedure TCR20260824P0Batch3Test.Test_CR016_UnparseableDate_RaisesSerializationException;
var
  E: TCR016Entity;
const
  BadJson = '{"when":"not-a-date-at-all"}';
begin
  Assert.WillRaise(
    procedure
    begin
      E := TCR016Entity(TSerializer.FromJson(BadJson, TCR016Entity));
      E.Free;
    end,
    ESerializationException);
end;

procedure TCR20260824P0Batch3Test.Test_CR018_EnumRoundtrip;
var
  E1, E2: TCR016Entity;
  Json: string;
begin
  E1 := TCR016Entity.Create;
  try
    E1.Fruit := frBanana;
    Json := TSerializer.ToJson(E1);
  finally
    E1.Free;
  end;

  E2 := TCR016Entity(TSerializer.FromJson(Json, TCR016Entity));
  try
    Assert.IsTrue(Ord(E2.Fruit) = Ord(frBanana),
      'enum value must survive the roundtrip');
  finally
    E2.Free;
  end;
end;

procedure TCR20260824P0Batch3Test.Test_CR018_UnknownEnumName_Raises;
const
  BadJson = '{"fruit":"frMango"}';
begin
  // Pre-fix: GetEnumValue returned -1 and was written into the object silently
  Assert.WillRaise(
    procedure
    var
      E: TCR016Entity;
    begin
      E := TCR016Entity(TSerializer.FromJson(BadJson, TCR016Entity));
      E.Free;
    end,
    ESerializationException);
end;

procedure TCR20260824P0Batch3Test.Test_CR018_OutOfRangeOrdinal_Raises;
const
  BadJson = '{"fruit":99}';
begin
  Assert.WillRaise(
    procedure
    var
      E: TCR016Entity;
    begin
      E := TCR016Entity(TSerializer.FromJson(BadJson, TCR016Entity));
      E.Free;
    end,
    ESerializationException);
end;

initialization
  TDUnitX.RegisterTestFixture(TCR20260824P0Batch3Test);

end.
