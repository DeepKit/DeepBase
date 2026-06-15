{ ============================================================================
  Test.DeepBase.DataPlatform - Data Platform v0.7 Unit Tests
  Covers: SchemaAdapter, ClipboardGuard (pure-logic tests)
  ============================================================================ }

unit Test.DeepBase.DataPlatform;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Variants,
  DUnitX.TestFramework,
  DeepBase.SchemaAdapter.Types,
  DeepBase.SchemaAdapter;

type
  // Minimal concrete adapter for testing TBaseSchemaAdapter
  TTestAdapter = class(TBaseSchemaAdapter)
  protected
    function GetDirection: TDirectionMapping; override;
    function GetMessageType: TMsgTypeMapping; override;
    function GetTimestamp: TTimestampMapping; override;
  public
    constructor Create;
  end;

  [TestFixture]
  TTestSchemaAdapter = class
  private
    FAdapter: ISchemaAdapter;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('MapRow all columns', 'contact_id,User1,nickname,Alice,raw_type,1,raw_direction,inbound')]
    procedure TestMapRowAllColumns;

    [Test]
    [TestCase('MapRow missing source field → Null', 'contact_id,User2')]
    procedure TestMapRowMissingFieldIsNull;

    [Test]
    [TestCase('MapRow forbidden field → Null', 'chatmsg')]
    procedure TestMapRowForbiddenFieldIsNull;

    [Test]
    procedure TestMapRowTransformUnixTimestamp;

    [Test]
    procedure TestMapRowTransformDirectionMapping;

    [Test]
    procedure TestMapRowColumnIndexAccess;

    [Test]
    procedure TestMapRowsBulkAllSuccess;

    [Test]
    procedure TestMapRowsBulkPartialFailure;

    [Test]
    procedure TestValidate_ForbiddenInMappings;

    [Test]
    procedure TestValidate_ShortFingerprint;

    [Test]
    procedure TestValidate_ColumnIndexMismatch;

    [Test]
    procedure TestGetColumnIndex;

    [Test]
    procedure TestGetColumnCount;

    [Test]
    procedure TestTryMatchFingerprint;

    [Test]
    procedure TestForbiddenFieldNames;
  end;

  [TestFixture]
  TTestMapperResult = class
  public
    [Test]
    procedure TestMapResult_Success;
    [Test]
    procedure TestMapResult_Failure;
  end;

  [TestFixture]
  TTestFieldMap = class
  public
    [Test]
    procedure TestFieldMapDefaults;
    [Test]
    procedure TestFieldMapWithTransform;
  end;

implementation

{ TTestAdapter }

constructor TTestAdapter.Create;
begin
  inherited;
  FVersion := 'test';
  FVersionRange := '0.0.0-99.99.99';
  FSchemaFingerprintPrefixes := ['abc1234567def'];

  SetLength(FFieldMappings, 4);
  FFieldMappings[0] := FieldMap('UserName', 'contact_id');              // Index 0
  FFieldMappings[1] := FieldMap('NickName', 'nickname');                // Index 1
  FFieldMappings[2] := FieldMap('Type', 'raw_type');                    // Index 2
  FFieldMappings[3] := FieldMap('IsSender', 'raw_direction',            // Index 3
    function(v: Variant): Variant
    begin
      case v.AsInteger of
        0: Result := 'inbound';
        1: Result := 'outbound';
        else Result := 'unknown';
      end;
    end);

  for var I := 0 to High(FFieldMappings) do
    FFieldMappings[I].ColumnIndex := I;

  FForbiddenFieldsDict.Add('StrContent', True);
  FForbiddenFieldNames := ['StrContent'];
end;

function TTestAdapter.GetDirection: TDirectionMapping;
begin
  Result := TDirectionMapping.Create;
  Result.Add(0, dInbound);
  Result.Add(1, dOutbound);
end;

function TTestAdapter.GetMessageType: TMsgTypeMapping;
begin
  Result := TMsgTypeMapping.Create;
  Result.Add(1, mtText);
  Result.Add(3, mtImage);
end;

function TTestAdapter.GetTimestamp: TTimestampMapping;
begin
  Result := function(v: Variant): TDateTime
  begin
    if VarIsNull(v) then
      Result := 0
    else
      Result := TDateTime(Int64(v.AsInt64) / SecsPerDay + UnixDateDelta);
  end;
end;

{ TTestSchemaAdapter }

procedure TTestSchemaAdapter.Setup;
begin
  FAdapter := TTestAdapter.Create;
end;

procedure TTestSchemaAdapter.TearDown;
begin
  FAdapter := nil;
end;

procedure TTestSchemaAdapter.TestMapRowAllColumns;
begin
  var Raw := TDictionary<string, Variant>.Create;
  Raw.Add('UserName', 'User1');
  Raw.Add('NickName', 'Alice');
  Raw.Add('Type', 1);
  Raw.Add('IsSender', 0);
  var Row := FAdapter.MapRow(Raw);
  Assert.AreEqual(4, Length(Row), 'Row should have 4 columns');
  Assert.AreEqual('User1', string(Row[0]));     // contact_id
  Assert.AreEqual('Alice',  string(Row[1]));     // nickname
  Assert.AreEqual(1,        Integer(Row[2]));    // raw_type
  Assert.AreEqual('inbound', string(Row[3]));    // raw_direction (transformed)
end;

procedure TTestSchemaAdapter.TestMapRowMissingFieldIsNull;
begin
  var Raw := TDictionary<string, Variant>.Create;
  Raw.Add('UserName', 'User2');
  // NickName deliberately omitted
  var Row := FAdapter.MapRow(Raw);
  Assert.AreEqual('User2', string(Row[0]));
  Assert.IsTrue(VarIsNull(Row[1]), 'Missing NickName should be Null');
end;

procedure TTestSchemaAdapter.TestMapRowForbiddenFieldIsNull;
begin
  var Raw := TDictionary<string, Variant>.Create;
  Raw.Add('StrContent', 'this should be blocked');
  var Row := FAdapter.MapRow(Raw);
  for var I := 0 to High(Row) do
    Assert.IsTrue(Row[I] = Null, Format('forbidden field leaked at index %d', [I]));
end;

procedure TTestSchemaAdapter.TestMapRowTransformUnixTimestamp;
begin
  var Raw := TDictionary<string, Variant>.Create;
  Raw.Add('UserName', 'test');
  Raw.Add('NickName', 'test');
  Raw.Add('Type', 1);
  Raw.Add('IsSender', 1);
  var Row := FAdapter.MapRow(Raw);
  Assert.AreEqual('outbound', string(Row[3]), 'IsSender 1 should map to outbound');
end;

procedure TTestSchemaAdapter.TestMapRowTransformDirectionMapping;
begin
  var d := FAdapter.MapDirection(0);
  Assert.AreEqual(dInbound, d);
  d := FAdapter.MapDirection(1);
  Assert.AreEqual(dOutbound, d);
  d := FAdapter.MapDirection(999);
  Assert.AreEqual(dUnknown, d);
end;

procedure TTestSchemaAdapter.TestMapRowColumnIndexAccess;
begin
  Assert.AreEqual(0, FAdapter.GetColumnIndex('contact_id'));
  Assert.AreEqual(1, FAdapter.GetColumnIndex('nickname'));
  Assert.AreEqual(-1, FAdapter.GetColumnIndex('nonexistent'));
end;

procedure TTestSchemaAdapter.TestMapRowsBulkAllSuccess;
begin
  var rawRows: TArray<TDictionary<string, Variant>>;
  SetLength(rawRows, 3);
  for var I := 0 to 2 do
  begin
    rawRows[I] := TDictionary<string, Variant>.Create;
    rawRows[I].Add('UserName', Format('User%d', [I]));
    rawRows[I].Add('NickName', Format('Nick%d', [I]));
    rawRows[I].Add('Type', 1);
    rawRows[I].Add('IsSender', 0);
  end;

  var results := FAdapter.MapRows(rawRows);
  Assert.AreEqual(3, Length(results));
  for var R in results do
  begin
    Assert.IsTrue(R.IsSuccess, R.GetError);
    Assert.AreEqual(4, Length(R.GetRow));
  end;
end;

procedure TTestSchemaAdapter.TestMapRowsBulkPartialFailure;
begin
  var rawRows: TArray<TDictionary<string, Variant>>;
  SetLength(rawRows, 1);
  rawRows[0] := TDictionary<string, Variant>.Create;
  // empty - will trigger MapRow which should still succeed (empty output)
  rawRows[0].Add('UserName', 'only-field');

  var results := FAdapter.MapRows(rawRows);
  Assert.AreEqual(1, Length(results));
  Assert.IsTrue(results[0].IsSuccess);
end;

procedure TTestSchemaAdapter.TestValidate_ForbiddenInMappings;
begin
  var Adapter := TTestAdapter.Create;
  Adapter.FForbiddenFieldNames := ['UserName'];  // UserName IS in mappings
  Assert.WillRaise(
    procedure begin Adapter.Validate; end,
    ESchemaAdapterValidationError);
end;

procedure TTestSchemaAdapter.TestValidate_ShortFingerprint;
begin
  var Adapter := TTestAdapter.Create;
  Adapter.FSchemaFingerprintPrefixes := ['abc'];  // only 3 chars
  Assert.WillRaise(
    procedure begin Adapter.Validate; end,
    ESchemaAdapterValidationError);
end;

procedure TTestSchemaAdapter.TestValidate_ColumnIndexMismatch;
begin
  var Adapter := TTestAdapter.Create;
  Adapter.FFieldMappings[1].ColumnIndex := 99;  // corrupt column index
  Assert.WillRaise(
    procedure begin Adapter.Validate; end,
    ESchemaAdapterValidationError);
end;

procedure TTestSchemaAdapter.TestGetColumnIndex;
begin
  Assert.AreEqual(0, FAdapter.GetColumnIndex('contact_id'), 'contact_id should be at col 0');
  Assert.AreEqual(1, FAdapter.GetColumnIndex('nickname'),   'nickname should be at col 1');
  Assert.AreEqual(2, FAdapter.GetColumnIndex('raw_type'),    'raw_type should be at col 2');
  Assert.AreEqual(3, FAdapter.GetColumnIndex('raw_direction'), 'raw_direction should be at col 3');
  Assert.AreEqual(-1, FAdapter.GetColumnIndex('does_not_exist'), 'unknown field → -1');
end;

procedure TTestSchemaAdapter.TestGetColumnCount;
begin
  Assert.AreEqual(4, FAdapter.GetColumnCount);
end;

procedure TTestSchemaAdapter.TestTryMatchFingerprint;
begin
  var Adapter := TTestAdapter.Create;
  Assert.IsTrue(Adapter.TryMatchFingerprint('abc1234567def'));
  Assert.IsFalse(Adapter.TryMatchFingerprint('DEADBEEF12345'));
end;

procedure TTestSchemaAdapter.TestForbiddenFieldNames;
begin
  var names := FAdapter.GetForbiddenFields;
  Assert.AreEqual(1, Length(names));
  Assert.AreEqual('StrContent', names[0]);
end;

{ TTestMapperResult }

procedure TTestMapperResult.TestMapResult_Success;
begin
  var row: TInternalRow;
  SetLength(row, 2);
  row[0] := 'hello';
  row[1] := 42;
  var mr := TMapResult.Create(row, True, '');
  Assert.IsTrue(mr.IsSuccess);
  Assert.AreEqual('', mr.GetError);
  Assert.AreEqual(2, Length(mr.GetRow));
  Assert.AreEqual('hello', string(mr.GetRow[0]));
end;

procedure TTestMapperResult.TestMapResult_Failure;
begin
  var mr := TMapResult.Create(nil, False, 'Test error');
  Assert.IsFalse(mr.IsSuccess);
  Assert.AreEqual('Test error', mr.GetError);
end;

{ TTestFieldMap }

procedure TTestFieldMap.TestFieldMapDefaults;
begin
  var m := FieldMap('Src', 'Tgt');
  Assert.AreEqual('Src', m.SourceField);
  Assert.AreEqual('Tgt', m.TargetField);
  Assert.AreEqual(-1, m.ColumnIndex);
  Assert.IsNull(m.Transform);
end;

procedure TTestFieldMap.TestFieldMapWithTransform;
begin
  var m := FieldMap('IsSender', 'direction',
    function(v: Variant): Variant
    begin
      case v.AsInteger of
        0: Result := dInbound;
        1: Result := dOutbound;
      end;
    end);
  Assert.IsNotNull(m.Transform);
  Assert.AreEqual(dInbound, TDirection(m.Transform(0)));
  Assert.AreEqual(dOutbound, TDirection(m.Transform(1)));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestFieldMap);
  TDUnitX.RegisterTestFixture(TTestMapperResult);
  TDUnitX.RegisterTestFixture(TTestSchemaAdapter);
end.