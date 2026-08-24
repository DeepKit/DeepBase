{ ============================================================================
  Test.Regression.CR20260824_P0Batch4 - Full-repo audit 2026-08-24, P0 batch 4

  Covers:
  - CR-015: record-typed properties silently serialized as an empty JSON
    object and dropped entirely in XML/binary. After the fix:
      a) JSON roundtrips records recursively (nested records included).
      b) XML/binary fail LOUDLY instead of losing data silently.
  - CR-017: binary deserializer hardening:
      a) string length field capped
      b) unknown kinds raise instead of returning Empty
      c) resolved class must pass IsAllowedType and inherit from declared type
  ============================================================================ }

unit Test.Regression.CR20260824_P0Batch4;

interface

uses
  System.SysUtils,
  System.Classes,
  System.TypInfo,
  System.NetEncoding,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.Serialization;

type
  TCR015Inner = record
    S: string;
    Code: Integer;
  end;

  TCR015Outer = record
    I: TCR015Inner;
    N: Integer;
  end;

  [Serializable]
  TCR015Entity = class
  private
    FPos: TCR015Outer;
  public
    [Serialize('pos')]
    property Pos: TCR015Outer read FPos write FPos;
  end;

  [Serializable]
  TCR017Entity = class
  private
    FName: string;
  public
    [Serialize('name')]
    property Name: string read FName write FName;
  end;

  TEvilNoAttr = class
  public
    Payload: Integer;
  end;

  [TestFixture]
  [Category('regression')]
  TCR20260824P0Batch4Test = class(TRegressionTestBase)
  private
    class function NewRecordEntity: TCR015Entity; static;
    procedure WriteBinStr(AStream: TStream; const AValue: string);
    procedure WriteEnvelope(AStream: TStream; const AClassName: string;
      APropCount: Integer);
    // 流式 API 契约：内容为 UTF8(Base64(raw))，raw 才是二进制格式本体
    procedure WriteBinaryPayload(AStream: TStream; const ARaw: TBytes);
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    procedure Test_CR015_Record_JsonRoundtrip_Nested;

    [Test]
    procedure Test_CR015_XmlRecord_FailsLoudly;

    [Test]
    procedure Test_CR015_BinaryRecord_FailsLoudly;

    [Test]
    procedure Test_CR017_StringLengthCap_RejectsHugeLength;

    [Test]
    procedure Test_CR017_UnwhitelistedClass_Rejected;

    [Test]
    procedure Test_CR017_BinaryRoundtrip_StillWorks;
  end;

implementation

{ helpers }

class function TCR20260824P0Batch4Test.NewRecordEntity: TCR015Entity;
var
  P: TCR015Outer;
begin
  P.I.S := 'hello';
  P.I.Code := 42;
  P.N := 7;
  Result := TCR015Entity.Create;
  Result.Pos := P;
end;

procedure TCR20260824P0Batch4Test.WriteBinStr(AStream: TStream; const AValue: string);
var
  B: TBytes;
  LLen: Integer;
begin
  B := TEncoding.UTF8.GetBytes(AValue);
  LLen := Length(B);
  AStream.WriteBuffer(LLen, SizeOf(LLen));
  if LLen > 0 then
    AStream.WriteBuffer(B[0], LLen);
end;

procedure TCR20260824P0Batch4Test.WriteEnvelope(AStream: TStream;
  const AClassName: string; APropCount: Integer);
var
  NullByte, KindByte: Byte;
  Cnt: Integer;
begin
  NullByte := 0;
  KindByte := Byte(Ord(tkUString));
  Cnt := APropCount;
  AStream.WriteBuffer(NullByte, 1);
  WriteBinStr(AStream, AClassName);
  AStream.WriteBuffer(Cnt, SizeOf(Cnt));
end;

procedure TCR20260824P0Batch4Test.WriteBinaryPayload(AStream: TStream; const ARaw: TBytes);
var
  B64: string;
  B: TBytes;
begin
  B64 := TNetEncoding.Base64.EncodeBytesToString(ARaw);
  B := TEncoding.UTF8.GetBytes(B64);
  AStream.WriteBuffer(B[0], Length(B));
end;

{ fixture }

function TCR20260824P0Batch4Test.GetBugNumber: string;
begin
  Result := 'CR-015/CR-017';
end;

function TCR20260824P0Batch4Test.GetBugDescription: string;
begin
  Result := 'Silent record data loss in serialization + binary deserializer hardening';
end;

function TCR20260824P0Batch4Test.GetFixDate: string;
begin
  Result := '2026-08-24';
end;

function TCR20260824P0Batch4Test.GetPriority: string;
begin
  Result := 'P0';
end;

function TCR20260824P0Batch4Test.GetAffectedFile: string;
begin
  Result := 'Core\DeepBase.Serialization.pas';
end;

procedure TCR20260824P0Batch4Test.Test_CR015_Record_JsonRoundtrip_Nested;
var
  E1, E2: TCR015Entity;
  Json: string;
  P: TCR015Outer;
begin
  E1 := NewRecordEntity;
  try
    Json := TSerializer.ToJson(E1);
  finally
    E1.Free;
  end;

  Assert.Contains(Json, '"S"', 'inner record string field must appear');
  Assert.Contains(Json, '"N"', 'outer record integer field must appear');

  E2 := TCR015Entity(TSerializer.FromJson(Json, TCR015Entity));
  try
    P := E2.Pos;
    Assert.AreEqual(7, P.N, 'outer.N');
    Assert.AreEqual(42, P.I.Code, 'inner.Code');
    Assert.AreEqual('hello', P.I.S, 'inner.S');
  finally
    E2.Free;
  end;
end;

procedure TCR20260824P0Batch4Test.Test_CR015_XmlRecord_FailsLoudly;
var
  E: TCR015Entity;
  LProc: TProc;
begin
  E := NewRecordEntity;
  try
    LProc := procedure
    begin
      TSerializer.ToXml(E);
    end;
    Assert.WillRaise(LProc, ESerializationException);
  finally
    E.Free;
  end;
end;

procedure TCR20260824P0Batch4Test.Test_CR015_BinaryRecord_FailsLoudly;
var
  E: TCR015Entity;
  MS: TBytesStream;
  Ser: TBinarySerializer;
  LProc: TProc;
begin
  E := NewRecordEntity;
  MS := TBytesStream.Create;
  try
    Ser := TBinarySerializer.Create;
    try
      LProc := procedure
      begin
        Ser.SerializeToStream(E, MS);
      end;
      Assert.WillRaise(LProc, ESerializationException);
    finally
      Ser.Free;
    end;
  finally
    MS.Free;
    E.Free;
  end;
end;

procedure TCR20260824P0Batch4Test.Test_CR017_StringLengthCap_RejectsHugeLength;
var
  Raw: TBytesStream;
  MS: TBytesStream;
  Ser: TBinarySerializer;
  HugeLen: Integer;
  KindByte: Byte;
  RawBytes: TBytes;
  O: TObject;
  LProc: TProc;
begin
  Raw := TBytesStream.Create;
  try
    WriteEnvelope(Raw, 'TCR017Entity', 1);
    WriteBinStr(Raw, 'name');
    KindByte := Byte(Ord(tkUString));
    Raw.WriteBuffer(KindByte, 1);
    HugeLen := MaxInt;
    Raw.WriteBuffer(HugeLen, SizeOf(HugeLen));

    SetLength(RawBytes, Raw.Size);
    if Raw.Size > 0 then
      Move(Raw.Memory^, RawBytes[0], Raw.Size);

    MS := TBytesStream.Create;
    try
      // 流式 API 契约：内容为 UTF8(Base64(raw))
      WriteBinaryPayload(MS, RawBytes);
      MS.Position := 0;

      Ser := TBinarySerializer.Create;
      try
        LProc := procedure
        begin
          O := Ser.DeserializeFromStream(MS, TCR017Entity);
          if Assigned(O) then
            O.Free;
        end;
        Assert.WillRaise(LProc, ESerializationException);
      finally
        Ser.Free;
      end;
    finally
      MS.Free;
    end;
  finally
    Raw.Free;
  end;
end;

procedure TCR20260824P0Batch4Test.Test_CR017_UnwhitelistedClass_Rejected;
var
  Raw: TBytesStream;
  MS: TBytesStream;
  Ser: TBinarySerializer;
  RawBytes: TBytes;
  O: TObject;
  LProc: TProc;
begin
  Raw := TBytesStream.Create;
  try
    WriteEnvelope(Raw, 'TEvilNoAttr', 0); // registered but NOT [Serializable]

    SetLength(RawBytes, Raw.Size);
    if Raw.Size > 0 then
      Move(Raw.Memory^, RawBytes[0], Raw.Size);

    MS := TBytesStream.Create;
    try
      WriteBinaryPayload(MS, RawBytes);
      MS.Position := 0;

      Ser := TBinarySerializer.Create;
      try
        Ser.RegisterType(TEvilNoAttr);
        LProc := procedure
        begin
          O := Ser.DeserializeFromStream(MS, TCR017Entity);
          if Assigned(O) then
            O.Free;
        end;
        Assert.WillRaise(LProc, ESerializationException);
      finally
        Ser.Free;
      end;
    finally
      MS.Free;
    end;
  finally
    Raw.Free;
  end;
end;

procedure TCR20260824P0Batch4Test.Test_CR017_BinaryRoundtrip_StillWorks;
var
  E1, E2: TCR017Entity;
  MS: TBytesStream;
  Ser: TBinarySerializer;
begin
  E1 := TCR017Entity.Create;
  try
    E1.Name := 'round-trip';
    MS := TBytesStream.Create;
    try
      Ser := TBinarySerializer.Create;
      try
        Assert.IsTrue(Ser.SerializeToStream(E1, MS));
        MS.Position := 0;
        E2 := Ser.DeserializeFromStream<TCR017Entity>(MS);
        try
          Assert.AreEqual('round-trip', E2.Name,
            'hardened binary serializer must still roundtrip valid payloads');
        finally
          E2.Free;
        end;
      finally
        Ser.Free;
      end;
    finally
      MS.Free;
    end;
  finally
    E1.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCR20260824P0Batch4Test);

end.
