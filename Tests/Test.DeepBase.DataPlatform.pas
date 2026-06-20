{ ============================================================================
  Test.DeepBase.DataPlatform - Data Platform v0.7 Unit Tests
  ============================================================================ }

unit Test.DeepBase.DataPlatform;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Variants,
  DUnitX.TestFramework,
  DeepBase.Exceptions,
  DeepBase.SchemaAdapter.Types,
  DeepBase.SchemaAdapter;

type
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
    procedure TestMapRowAllColumns;

    [Test]
    procedure TestMapRowMissingFieldIsNull;

    [Test]
    procedure TestMapRowForbiddenFieldIsNull;

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
  FFieldMappings[0] := FieldMap('UserName', 'contact_id');
  FFieldMappings[1] := FieldMap('NickName', 'nickname');
  FFieldMappings[2] := FieldMap('Type', 'raw_type');
  FFieldMappings[3] := FieldMap('IsSender', 'raw_direction',
    function(v: Variant): Variant
    begin
      case Integer(v) of
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
    if VarIsNull(v) or VarIsEmpty(v) then
      Result := 0
    else
      Result := TDateTime(Int64(v) / SecsPerDay + UnixDateDelta);
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
  Assert.AreEqual<Integer>(4, Length(Row));
  Assert.AreEqual('User1', VarToStr(Row[0]));
  Assert.AreEqual('Alice',  VarToStr(Row[1]));
  Assert.AreEqual(1,        Integer(Row[2]));
  Assert.AreEqual('inbound', VarToStr(Row[3]));
end;

procedure TTestSchemaAdapter.TestMapRowMissingFieldIsNull;
begin
  var Raw := TDictionary<string, Variant>.Create;
  Raw.Add('UserName', 'User2');
  var Row := FAdapter.MapRow(Raw);
  Assert.AreEqual('User2', VarToStr(Row[0]));
  Assert.IsTrue(VarIsNull(Row[1]), 'Missing NickName should be Null');
end;

procedure TTestSchemaAdapter.TestMapRowForbiddenFieldIsNull;
begin
  var Raw := TDictionary<string, Variant>.Create;
  Raw.Add('StrContent', 'this should be blocked');
  var Row := FAdapter.MapRow(Raw);
  for var I := 0 to High(Row) do
    Assert.IsTrue(VarIsNull(Row[I]), Format('forbidden field leaked at index %d', [I]));
end;

procedure TTestSchemaAdapter.TestMapRowTransformDirectionMapping;
begin
  var Raw := TDictionary<string, Variant>.Create;
  Raw.Add('UserName', 'test');
  Raw.Add('NickName', 'test');
  Raw.Add('Type', 1);
  Raw.Add('IsSender', 1);
  var Row := FAdapter.MapRow(Raw);
  Assert.AreEqual('outbound', VarToStr(Row[3]));
end;

procedure TTestSchemaAdapter.TestMapRowColumnIndexAccess;
begin
  Assert.AreEqual<Integer>(0, FAdapter.GetColumnIndex('contact_id'));
  Assert.AreEqual<Integer>(1, FAdapter.GetColumnIndex('nickname'));
  Assert.AreEqual<Integer>(-1, FAdapter.GetColumnIndex('nonexistent'));
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
  Assert.AreEqual<Integer>(3, Length(results));
  for var R in results do
  begin
    Assert.IsTrue(R.IsSuccess, R.GetError);
    Assert.AreEqual<Integer>(4, Length(R.GetRow));
  end;
end;

procedure TTestSchemaAdapter.TestMapRowsBulkPartialFailure;
begin
  var rawRows: TArray<TDictionary<string, Variant>>;
  SetLength(rawRows, 1);
  rawRows[0] := TDictionary<string, Variant>.Create;
  rawRows[0].Add('UserName', 'only-field');

  var results := FAdapter.MapRows(rawRows);
  Assert.AreEqual<Integer>(1, Length(results));
  Assert.IsTrue(results[0].IsSuccess);
end;

procedure TTestSchemaAdapter.TestValidate_ForbiddenInMappings;
var Adapter: TTestAdapter;
begin
  Adapter := TTestAdapter.Create;
  try
    Adapter.FForbiddenFieldNames := ['UserName'];
    Assert.WillRaise(
      procedure begin Adapter.Validate; end,
      ESchemaAdapterValidationError);
  finally
    Adapter.Free;
  end;
end;

procedure TTestSchemaAdapter.TestValidate_ShortFingerprint;
var Adapter: TTestAdapter;
begin
  Adapter := TTestAdapter.Create;
  try
    Adapter.FSchemaFingerprintPrefixes := ['abc'];
    Assert.WillRaise(
      procedure begin Adapter.Validate; end,
      ESchemaAdapterValidationError);
  finally
    Adapter.Free;
  end;
end;

procedure TTestSchemaAdapter.TestValidate_ColumnIndexMismatch;
var Adapter: TTestAdapter;
begin
  Adapter := TTestAdapter.Create;
  try
    Adapter.FFieldMappings[1].ColumnIndex := 99;
    Assert.WillRaise(
      procedure begin Adapter.Validate; end,
      ESchemaAdapterValidationError);
  finally
    Adapter.Free;
  end;
end;

procedure TTestSchemaAdapter.TestGetColumnIndex;
begin
  Assert.AreEqual<Integer>(0, FAdapter.GetColumnIndex('contact_id'));
  Assert.AreEqual<Integer>(1, FAdapter.GetColumnIndex('nickname'));
  Assert.AreEqual<Integer>(2, FAdapter.GetColumnIndex('raw_type'));
  Assert.AreEqual<Integer>(3, FAdapter.GetColumnIndex('raw_direction'));
  Assert.AreEqual<Integer>(-1, FAdapter.GetColumnIndex('does_not_exist'));
end;

procedure TTestSchemaAdapter.TestGetColumnCount;
begin
  Assert.AreEqual<Integer>(4, FAdapter.GetColumnCount);
end;

procedure TTestSchemaAdapter.TestTryMatchFingerprint;
var Adapter: TTestAdapter;
begin
  Adapter := TTestAdapter.Create;
  try
    Assert.IsTrue(Adapter.TryMatchFingerprint('abc1234567def'));
    Assert.IsFalse(Adapter.TryMatchFingerprint('DEADBEEF12345'));
  finally
    Adapter.Free;
  end;
end;

procedure TTestSchemaAdapter.TestForbiddenFieldNames;
begin
  var names := FAdapter.GetForbiddenFields;
  Assert.AreEqual<Integer>(1, Length(names));
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
  Assert.AreEqual<Integer>(2, Length(mr.GetRow));
  Assert.AreEqual('hello', VarToStr(mr.GetRow[0]));
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
  Assert.AreEqual<Integer>(-1, m.ColumnIndex);
end;

procedure TTestFieldMap.TestFieldMapWithTransform;
begin
  var m := FieldMap('IsSender', 'direction',
    function(v: Variant): Variant
    begin
      case Integer(v) of
        0: Result := Variant(dInbound);
        1: Result := Variant(dOutbound);
      end;
    end);
  Assert.AreEqual(Integer(dInbound), Integer(m.Transform(0)));
  Assert.AreEqual(Integer(dOutbound), Integer(m.Transform(1)));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestFieldMap);
  TDUnitX.RegisterTestFixture(TTestMapperResult);
  TDUnitX.RegisterTestFixture(TTestSchemaAdapter);
end.