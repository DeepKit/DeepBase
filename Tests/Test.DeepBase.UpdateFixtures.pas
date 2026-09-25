{ ============================================================================
  Test.DeepBase.UpdateFixtures - 更新验签链测试夹具（单一真相源）

  职责：两条更新通道（DeepBase.Updater / DeepBase.AutoUpdate）的测试共用同一
  RSA-2048 测试密钥对与签名/假传输助手。密钥材料在此处只定义一次，避免两个
  测试单元各持一份而签名语义分叉——那正是本工单要消灭的 U-02 双实现问题在
  测试侧的复现路径。

  法源：WO-20260920-AUDIT-甲-R5 M1（Top20#01 更新验签链，docs/66 §16.10）。
  ============================================================================ }

unit Test.DeepBase.UpdateFixtures;

interface

uses
  System.SysUtils,
  System.Classes,
  DeepBase.Net.Transport,
  DeepBase.Update.Contracts;

type
  /// <summary>注入式 HTTP 假传输：记录调用次数，供"门禁前不得发出请求"断言。</summary>
  TFakeUpdaterTransport = class(TInterfacedObject, IDeepBaseHttpTransport)
  public
    LastRequest: TDeepBaseHttpTransportRequest;
    Response: TDeepBaseHttpTransportResponse;
    CallCount: Integer;
    function Send(const ARequest: TDeepBaseHttpTransportRequest):
      TDeepBaseHttpTransportResponse;
  end;

const
  // 测试用 RSA-2048 密钥对（仅测试用，已公开无关安全）。两端均走
  // DeepBase.Crypto.RSA 同实现，私钥签 → 公钥验，签名必然互通。
  // 私钥须为 PKCS#1 (BEGIN RSA PRIVATE KEY)——LoadPrivateKeyPEM 只解析
  // PKCS#1 RSAPrivateKey ASN.1 结构，不支持 PKCS#8 外层包装。
  TEST_PRIVATE_KEY_PEM =
    '-----BEGIN RSA PRIVATE KEY-----' + sLineBreak +
    'MIIEogIBAAKCAQEAuhMNc5e6NGCuObch/OOZnGdcM9Kt1a1DuZrQryKPxl1lbE+0' + sLineBreak +
    '8cG+o7GcVBWJF5hXY4ApcxkDO6xdEo2RBNp8QJ9cUMQEPxFuavGBGpgrj27l4pd8' + sLineBreak +
    '9DPrQ44xs+esY8Bp/GQHp+21NXQIQtXnyLpvz8IBcbl4sgvm4PKytQaGOByC1Vnu' + sLineBreak +
    'ay4aOrOejxypKOW7frXqb+voWAr/h7G0tZE3E2EjlQVRRVm7Khjp3JAo7NiwrlZC' + sLineBreak +
    '+LCuivrEzxveHUHKXwXf6scOt+w4snCNNT23nEuWIKYKnXxXMb83yq9G6bb1ZVpM' + sLineBreak +
    'hhJvJPfA4xRkOQyzRukC9jq2PUPpoSBE6QA3PwIDAQABAoIBACL44L7Yhg1BHI3J' + sLineBreak +
    'bzBmIKFmRcyRrM1rzr5MLCu2fbpFJIJaasJDbU6724tsLsOKBOa1GFVDHrnw9988' + sLineBreak +
    'T0TPwamtqf6eEMQ/xPaBpIe4kPtY1wki+r+1IGMmjw3mnZ5z9BeVP2EfCr9cqw7Q' + sLineBreak +
    'wEsYS1qLdpUGzHn+RasCwnbGnqRd2SA3PzVh5h6lwYJYfYAqQOM4CGvRPjsPaWIm' + sLineBreak +
    'ryEekfJ8Tuh4q/WndFvq/38NIpttP/SZAOeWHdmqeVDOxFJpP+FA6YWduaAeuEQX' + sLineBreak +
    'XrO3aRqvPJIxmQGZ9uXwu85BWx69XFK2/fXZ1Gk0vtJ6QQUnp5rhXqq8io2L9MuS' + sLineBreak +
    '3KuO/qUCgYEA7SDFaHDb1ItGgmYYRh/vLF9SDmVb8Ps8G/jQaU4QwEvxauQMf1a+' + sLineBreak +
    'uuzkW9Gxo1ZtnUYjRPAo83663J1H11sxZ6gfcsX+SJzQyRY9CCZSMJ2MOjSoS+Qv' + sLineBreak +
    'Ocs36/eMsF01fXll3BO0u0CT+OxTtserzlggD64jl5q6/QYuOdOKzWsCgYEAyOIe' + sLineBreak +
    'jDh2LPENcMnMPlwCKmAfKthDVjOSI9xb+9bIV5T6s9fLM6t3Y2Odtd911RU7PBqq' + sLineBreak +
    '3FoVfu0Gs3NonWnbjE1TFjoNDYVgSJKIvHRp4kt2ZLxHgFPrlAN4zhXOFdBye3a1' + sLineBreak +
    'e4m4eAulfMPHmTOjPXA0NnDqQKp7/WXMiNXuPn0CgYBGBR9Fr825/UZcyvjv/A4L' + sLineBreak +
    '9Dmuto9noUgmmlowPjUEE2i+P4jRMTQwzjLASjNCIAtOHZ/cg24UOJ/E9Ux5cxwr' + sLineBreak +
    'l6FxqrVji6q7Ni3fcjFi2aLGrTXk8wRe9HsW2opYqa1Z17cUPV1ozbDkGCTAHEXH' + sLineBreak +
    'MI6HEsy/v5jnjiOoP6cE8QKBgHAqGaZvrESBv+B3PMyg8TCaBS0WHdsW5oWRd+bR' + sLineBreak +
    'UYHdlHIwjqxmFD5xk9DGWfPFbBKuTTLGNfRuAmzWhtZGEilvz3G8ricbjtxWvXSE' + sLineBreak +
    'h86sFgo/OqlDsmkt2xkvAagagKHBcanuBws4bYmRg3ReacpXSUAQoivDRYICgkbx' + sLineBreak +
    'NJq9AoGAXzVP3gMPyNfhPZp4lWXZagjmfDUWzFPtmpk8h+MIvmOfQRghM1H8Jg7I' + sLineBreak +
    'ByqYe2qrG3kUTkemquhEh4XgYqglrHSuI7OMgn8CMKLkI0LHrObvwtk8eWSfFgZq' + sLineBreak +
    'SazofgDvL7U/VNLnCCMpFn6wZMVbpKp/6fDGAb3M9or629btvmI=' + sLineBreak +
    '-----END RSA PRIVATE KEY-----';

  TEST_PUBLIC_KEY_PEM =
    '-----BEGIN PUBLIC KEY-----' + sLineBreak +
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuhMNc5e6NGCuObch/OOZ' + sLineBreak +
    'nGdcM9Kt1a1DuZrQryKPxl1lbE+08cG+o7GcVBWJF5hXY4ApcxkDO6xdEo2RBNp8' + sLineBreak +
    'QJ9cUMQEPxFuavGBGpgrj27l4pd89DPrQ44xs+esY8Bp/GQHp+21NXQIQtXnyLpv' + sLineBreak +
    'z8IBcbl4sgvm4PKytQaGOByC1Vnuay4aOrOejxypKOW7frXqb+voWAr/h7G0tZE3' + sLineBreak +
    'E2EjlQVRRVm7Khjp3JAo7NiwrlZC+LCuivrEzxveHUHKXwXf6scOt+w4snCNNT23' + sLineBreak +
    'nEuWIKYKnXxXMb83yq9G6bb1ZVpMhhJvJPfA4xRkOQyzRukC9jq2PUPpoSBE6QA3' + sLineBreak +
    'PwIDAQAB' + sLineBreak +
    '-----END PUBLIC KEY-----';

/// <summary>对字符串（UTF-8 字节，单层摘要）做 RSA-SHA256 签名，返回 base64。
/// 对应 Updater 通道：data = 归一化 hash 串 / manifest payload。</summary>
function TestRSASign(const AData: string): string;

/// <summary>对字节序列做 RSA-SHA256 签名（单层摘要），返回 base64。
/// 对应 AutoUpdate 通道 AU-01：data = 包文件原始字节。</summary>
function TestRSASignBytes(const AData: TBytes): string;

/// <summary>对文件原始字节做 RSA-SHA256 签名，返回 base64（AU-01 KAT 用）。</summary>
function TestRSASignFile(const APath: string): string;

/// <summary>
/// 构造一份"自洽且已正确签名"的 manifest：包签名签归一化 PackageHash，
/// manifest 签名与 manifest hash 均由 Contracts 的唯一 payload 派生。
/// 篡改场景由调用方在装配完成后定向替换单个字段，验证门禁层级。
/// 装配配方全仓仅此一份：签名顺序即 §16.10 依赖顺序，测试侧各写一份就会
/// 重演 U-02（同一协议两套实现）。
/// </summary>
function BuildSignedManifestInfo(const APackageHash: string): TUpdateInfo;

implementation

uses
  System.Hash,
  System.IOUtils,
  DeepBase.Crypto.RSA,
  DeepBase.Crypto.Encoding;

function TFakeUpdaterTransport.Send(
  const ARequest: TDeepBaseHttpTransportRequest):
  TDeepBaseHttpTransportResponse;
begin
  Inc(CallCount);
  LastRequest := ARequest;
  Result := Response;
end;

function TestRSASignBytes(const AData: TBytes): string;
{$IFDEF MSWINDOWS}
var
  LSigner: TRSASigner;
  LSig: TBytes;
{$ENDIF}
begin
  Result := '';
  {$IFDEF MSWINDOWS}
  // TRSASigner 仅 MSWINDOWS 可用（CNG 路径，同 Updater/AutoUpdate 的验签端）。
  LSigner := TRSASigner.Create;
  try
    if not LSigner.LoadPrivateKeyPEM(TEST_PRIVATE_KEY_PEM) then
      Exit('');
    LSig := LSigner.Sign(AData);
    if LSig <> nil then
      Result := TEncodingUtils.Base64Encode(LSig);
  finally
    LSigner.Free;
  end;
  {$ENDIF}
end;

function TestRSASign(const AData: string): string;
begin
  Result := TestRSASignBytes(TEncoding.UTF8.GetBytes(AData));
end;

function TestRSASignFile(const APath: string): string;
begin
  Result := TestRSASignBytes(TFile.ReadAllBytes(APath));
end;

function BuildSignedManifestInfo(const APackageHash: string): TUpdateInfo;
var
  Payload: string;
begin
  Result := Default(TUpdateInfo);
  Result.AppId := 'deepbase_desktop';
  Result.Version := TSemanticVersion.Parse('2.0.0');
  Result.Channel := ucStable;
  Result.DownloadUrl := 'https://cdn.example.com/updates/deepbase-2.0.0.zip';
  Result.DownloadSize := 1024;
  Result.PackageHash := APackageHash;
  // 签名顺序即 §16.10 依赖顺序：包签名先入 payload 第 7 位，
  // 再由 payload 派生 manifest_hash 与 manifest_signature。
  Result.Signature := TestRSASign(APackageHash);
  Payload := BuildManifestSignaturePayload(Result);
  Result.ManifestHash := LowerCase(THashSHA2.GetHashString(Payload));
  Result.ManifestSignature := TestRSASign(Payload);
end;

end.
