{ ============================================================================
  Test.DeepBase.Commerce.Adapter.Firebase
  ---------------------------------------------------------------------------
  Description : TFirebaseFieldCodec 的读写对称性离线回归。映射层从持有 THTTPClient
                的适配器里拆成无状态 codec 后，「写进 Firestore 的形状读回来必须等价」
                这条才能在无网络、无凭据的条件下咬住。
  Note        : 覆盖 B2-01 判定要求的 is_active 往返；同时钉住写入侧落的是真 JSON
                布尔（不是 "true" 字符串），因为读侧收紧后错型一律 fail-closed。
  ========================================================================== }

unit Test.DeepBase.Commerce.Adapter.Firebase;

interface

uses
  System.SysUtils,
  System.JSON,
  DUnitX.TestFramework,
  DeepBase.Commerce.Types,
  DeepBase.Commerce.Adapter.Firebase;

type

  [TestFixture]
  TTestFirebaseFieldCodec = class
  private
    class function UserFromDocJson(const ADocJson: string): TCommerceUserData; static;
    class function ProductFromDocJson(const ADocJson: string): TCommerceProductData; static;
    class function BoolFromDocJson(const ADocJson, AKey: string): Boolean; static;
    class function IsActiveWireText(AIsActive: Boolean): string; static;
  public
    [Test]
    procedure TestUserIsActiveTrueRoundTripsAsTrue;
    [Test]
    procedure TestUserIsActiveFalseRoundTripsAsFalse;
    [Test]
    procedure TestProductIsActiveTrueRoundTripsAsTrue;
    [Test]
    procedure TestStringTypedBooleanFailsClosed;
    [Test]
    procedure TestMissingBooleanFieldDefaultsFalse;
    [Test]
    procedure TestIsActiveWrittenAsRealJSONBoolean;
    [Test]
    procedure TestHandBuiltFirestoreDocumentDecodesIsActive;
    [Test]
    procedure TestNonBooleanFieldsRoundTrip;
  end;

implementation

{ TTestFirebaseFieldCodec }

class function TTestFirebaseFieldCodec.UserFromDocJson(const ADocJson: string): TCommerceUserData;
var
  Doc: TJSONValue;
  Fields: TJSONObject;
begin
  Doc := TJSONObject.ParseJSONValue(ADocJson);
  Assert.IsNotNull(Doc, '测试文档应可解析: ' + ADocJson);
  try
    Fields := TFirebaseFieldCodec.ExtractFields(TJSONObject(Doc));
    Result := TFirebaseFieldCodec.ParseUser(Fields);
  finally
    Doc.Free; // Fields 是 Doc 的子节点，随父释放
  end;
end;

class function TTestFirebaseFieldCodec.ProductFromDocJson(const ADocJson: string): TCommerceProductData;
var
  Doc: TJSONValue;
  Fields: TJSONObject;
begin
  Doc := TJSONObject.ParseJSONValue(ADocJson);
  Assert.IsNotNull(Doc, '测试文档应可解析: ' + ADocJson);
  try
    Fields := TFirebaseFieldCodec.ExtractFields(TJSONObject(Doc));
    Result := TFirebaseFieldCodec.ParseProduct(Fields);
  finally
    Doc.Free;
  end;
end;

class function TTestFirebaseFieldCodec.BoolFromDocJson(const ADocJson, AKey: string): Boolean;
var
  Doc: TJSONValue;
  Fields: TJSONObject;
begin
  Doc := TJSONObject.ParseJSONValue(ADocJson);
  Assert.IsNotNull(Doc, '测试文档应可解析: ' + ADocJson);
  try
    Fields := TFirebaseFieldCodec.ExtractFields(TJSONObject(Doc));
    Result := TFirebaseFieldCodec.BoolField(Fields, AKey);
  finally
    Doc.Free;
  end;
end;

// 把一个用户写成 Firestore 文档再序列化成上线报文，只保留 is_active 一项，
// 用于钉死「写入侧到底落了什么形状」
class function TTestFirebaseFieldCodec.IsActiveWireText(AIsActive: Boolean): string;
var
  User: TCommerceUserData;
  Fields: TJSONObject;
begin
  User := TCommerceUserData.CreateNew('wire');
  User.IsActive := AIsActive;
  Fields := TFirebaseFieldCodec.UserToFields(User);
  try
    Result := Fields.GetValue('is_active').ToJSON;
  finally
    Fields.Free;
  end;
end;

procedure TTestFirebaseFieldCodec.TestUserIsActiveTrueRoundTripsAsTrue;
var
  User: TCommerceUserData;
  Doc: TJSONObject;
  Wire: string;
  Back: TCommerceUserData;
begin
  User := TCommerceUserData.CreateNew('u-1');
  User.DisplayName := '活跃商户';
  User.IsActive := True;
  Doc := TJSONObject.Create;
  try
    Doc.AddPair('fields', TFirebaseFieldCodec.UserToFields(User));
    Wire := Doc.ToJSON;
  finally
    Doc.Free;
  end;
  Back := UserFromDocJson(Wire);
  Assert.IsTrue(Back.IsActive, '写入 is_active=true 必须读回 true');
  Assert.AreEqual('u-1', Back.UserId);
  Assert.AreEqual('活跃商户', Back.DisplayName);
end;

procedure TTestFirebaseFieldCodec.TestUserIsActiveFalseRoundTripsAsFalse;
var
  User: TCommerceUserData;
  Doc: TJSONObject;
begin
  User := TCommerceUserData.CreateNew('u-2');
  User.IsActive := False;
  Doc := TJSONObject.Create;
  try
    Doc.AddPair('fields', TFirebaseFieldCodec.UserToFields(User));
    Assert.IsFalse(UserFromDocJson(Doc.ToJSON).IsActive);
  finally
    Doc.Free;
  end;
end;

procedure TTestFirebaseFieldCodec.TestProductIsActiveTrueRoundTripsAsTrue;
var
  Product: TCommerceProductData;
  Doc: TJSONObject;
  Back: TCommerceProductData;
begin
  Product := TCommerceProductData.Create('app-1', 'p-1', '专业版', 9900, 'CNY',
    'PRO_MONTH', 30, 30, 'pro', 3, 7);
  Product.IsActive := True;
  Doc := TJSONObject.Create;
  try
    Doc.AddPair('fields', TFirebaseFieldCodec.ProductToFields(Product));
    Back := ProductFromDocJson(Doc.ToJSON);
  finally
    Doc.Free;
  end;
  Assert.IsTrue(Back.IsActive, '商品 is_active 与用户走同一读通道，须同样往返');
  Assert.AreEqual<Int64>(9900, Back.AmountMinor);
  Assert.AreEqual(3, Back.MaxDevices);
end;

procedure TTestFirebaseFieldCodec.TestStringTypedBooleanFailsClosed;
begin
  // 写侧只会产出 booleanValue:true/false；出现字符串型说明数据已损坏，
  // 静默降级成 False 等于把同一缺陷再藏一遍（WO §〇-8 fail-closed）
  Assert.WillRaise(
    procedure
    begin
      BoolFromDocJson('{"fields":{"is_active":{"booleanValue":"true"}}}', 'is_active');
    end, EDeepBaseCommerceError, '错型布尔必须抛错，不得静默返回 False');
end;

procedure TTestFirebaseFieldCodec.TestMissingBooleanFieldDefaultsFalse;
begin
  Assert.IsFalse(
    BoolFromDocJson('{"fields":{"user_id":{"stringValue":"u-3"}}}', 'is_active'),
    '字段缺失 = 未设置，按默认 False，不当作数据损坏');
end;

procedure TTestFirebaseFieldCodec.TestIsActiveWrittenAsRealJSONBoolean;
begin
  Assert.AreEqual('{"booleanValue":true}', IsActiveWireText(True));
  Assert.AreEqual('{"booleanValue":false}', IsActiveWireText(False));
end;

procedure TTestFirebaseFieldCodec.TestHandBuiltFirestoreDocumentDecodesIsActive;
var
  User: TCommerceUserData;
begin
  // 脱离本仓写入代码，直接按 Firestore REST 回读报文钉死读侧契约
  User := UserFromDocJson('{"fields":{' +
    '"user_id":{"stringValue":"u-5"},' +
    '"display_name":{"stringValue":"丁女士"},' +
    '"is_active":{"booleanValue":true},' +
    '"created_at":{"stringValue":"2026-09-25T00:00:00Z"}}}');
  Assert.IsTrue(User.IsActive);
  Assert.AreEqual('u-5', User.UserId);
  Assert.AreEqual('2026-09-25T00:00:00Z', User.CreatedAtISO);
end;

procedure TTestFirebaseFieldCodec.TestNonBooleanFieldsRoundTrip;
var
  User: TCommerceUserData;
  Doc: TJSONObject;
  Back: TCommerceUserData;
begin
  User := TCommerceUserData.CreateNew('u-6');
  User.Email := 'a@b.example';
  User.Phone := '+8613800000000';
  User.IsActive := True;
  User.CreatedAtISO := '2026-09-01T00:00:00Z';
  User.UpdatedAtISO := '2026-09-25T00:00:00Z';
  Doc := TJSONObject.Create;
  try
    Doc.AddPair('fields', TFirebaseFieldCodec.UserToFields(User));
    Back := UserFromDocJson(Doc.ToJSON);
  finally
    Doc.Free;
  end;
  Assert.AreEqual(User.Email, Back.Email);
  Assert.AreEqual(User.Phone, Back.Phone);
  Assert.AreEqual(User.CreatedAtISO, Back.CreatedAtISO);
  Assert.AreEqual(User.UpdatedAtISO, Back.UpdatedAtISO);
  Assert.IsTrue(Back.IsActive, '字符串字段往返不得影响布尔字段');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestFirebaseFieldCodec);

end.
