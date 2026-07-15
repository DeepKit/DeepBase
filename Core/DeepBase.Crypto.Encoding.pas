unit DeepBase.Crypto.Encoding;

{*******************************************************************************
  DeepBase Crypto - Encoding Utilities
  Base64, Base64Url, Hex, URL, and HTML encoding/decoding.

  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.NetEncoding,
  DeepBase.Crypto.Platform;

type
  /// <summary>Encoding utilities</summary>
  TEncodingUtils = class
  public
    /// <summary>Base64 encode</summary>
    class function Base64Encode(const AData: TBytes): string; overload; static;
    class function Base64Encode(const AData: string): string; overload; static;

    /// <summary>Base64 decode</summary>
    class function Base64Decode(const AData: string): TBytes; overload; static;
    class function Base64DecodeString(const AData: string): string; static;

    /// <summary>Base64 URL-safe encode (RFC 4648)</summary>
    class function Base64UrlEncode(const AData: TBytes): string; overload; static;
    class function Base64UrlEncode(const AData: string): string; overload; static;

    /// <summary>Base64 URL-safe decode</summary>
    class function Base64UrlDecode(const AData: string): TBytes; static;
    class function Base64UrlDecodeString(const AData: string): string; static;

    /// <summary>Hex encode</summary>
    class function HexEncode(const AData: TBytes): string; overload; static;
    class function HexEncode(const AData: string): string; overload; static;

    /// <summary>Hex decode</summary>
    class function HexDecode(const AData: string): TBytes; static;
    class function HexDecodeString(const AData: string): string; static;

    /// <summary>URL encode</summary>
    class function UrlEncode(const AData: string): string; static;

    /// <summary>URL decode</summary>
    class function UrlDecode(const AData: string): string; static;

    /// <summary>HTML encode</summary>
    class function HtmlEncode(const AData: string): string; static;

    /// <summary>HTML decode</summary>
    class function HtmlDecode(const AData: string): string; static;
  end;

implementation

{ TEncodingUtils }

class function TEncodingUtils.Base64Encode(const AData: TBytes): string;
begin
  Result := TNetEncoding.Base64.EncodeBytesToString(AData);
end;

class function TEncodingUtils.Base64Encode(const AData: string): string;
begin
  Result := TNetEncoding.Base64.Encode(AData);
end;

class function TEncodingUtils.Base64Decode(const AData: string): TBytes;
begin
  Result := TNetEncoding.Base64.DecodeStringToBytes(AData);
end;

class function TEncodingUtils.Base64DecodeString(const AData: string): string;
begin
  Result := TNetEncoding.Base64.Decode(AData);
end;

class function TEncodingUtils.Base64UrlEncode(const AData: TBytes): string;
begin
  Result := TNetEncoding.Base64.EncodeBytesToString(AData);
  // Convert to URL-safe base64
  Result := Result.Replace('+', '-').Replace('/', '_').TrimRight(['=']);
end;

class function TEncodingUtils.Base64UrlEncode(const AData: string): string;
begin
  Result := Base64UrlEncode(TEncoding.UTF8.GetBytes(AData));
end;

class function TEncodingUtils.Base64UrlDecode(const AData: string): TBytes;
var
  LData: string;
  LPadding: Integer;
begin
  // Convert from URL-safe base64
  LData := AData.Replace('-', '+').Replace('_', '/');

  // Add padding
  LPadding := (4 - Length(LData) mod 4) mod 4;
  LData := LData + StringOfChar('=', LPadding);

  Result := TNetEncoding.Base64.DecodeStringToBytes(LData);
end;

class function TEncodingUtils.Base64UrlDecodeString(const AData: string): string;
begin
  Result := TEncoding.UTF8.GetString(Base64UrlDecode(AData));
end;

class function TEncodingUtils.HexEncode(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + IntToHex(AData[I], 2);
  Result := LowerCase(Result);
end;

class function TEncodingUtils.HexEncode(const AData: string): string;
begin
  Result := HexEncode(TEncoding.UTF8.GetBytes(AData));
end;

class function TEncodingUtils.HexDecode(const AData: string): TBytes;
var
  I: Integer;
  LClean: string;
begin
  LClean := AData.Replace(' ', '').Replace('-', '');
  if Length(LClean) mod 2 <> 0 then
    raise ECryptoException.Create('Invalid hex string length');

  SetLength(Result, Length(LClean) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(LClean, I * 2 + 1, 2));
end;

class function TEncodingUtils.HexDecodeString(const AData: string): string;
begin
  Result := TEncoding.UTF8.GetString(HexDecode(AData));
end;

class function TEncodingUtils.UrlEncode(const AData: string): string;
begin
  Result := TNetEncoding.URL.Encode(AData);
end;

class function TEncodingUtils.UrlDecode(const AData: string): string;
begin
  Result := TNetEncoding.URL.Decode(AData);
end;

class function TEncodingUtils.HtmlEncode(const AData: string): string;
begin
  Result := TNetEncoding.HTML.Encode(AData);
end;

class function TEncodingUtils.HtmlDecode(const AData: string): string;
begin
  Result := TNetEncoding.HTML.Decode(AData);
end;

end.
