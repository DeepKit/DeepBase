unit DeepBase.Crypto.Random;

{*******************************************************************************
  DeepBase Crypto - Random Data Generation
  Cryptographically secure random bytes, strings, GUIDs, tokens, and OTPs.

  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes,
  DeepBase.Crypto.Platform, DeepBase.Crypto.Encoding;

/// <summary>
/// Standalone convenience function returning cryptographically secure random bytes.
/// Delegates to TRandomGenerator.RandomBytes — use this when a class reference is
/// inconvenient (e.g. from other units that only need random bytes).
/// </summary>
function CryptoRandomBytes(ALength: Integer): TBytes;

type
  /// <summary>Random data generator</summary>
  TRandomGenerator = class
  public
    /// <summary>Generate random bytes</summary>
    class function RandomBytes(ALength: Integer): TBytes; static;

    /// <summary>Generate random string (alphanumeric)</summary>
    class function RandomString(ALength: Integer): string; static;

    /// <summary>Generate random hex string</summary>
    class function RandomHex(ALength: Integer): string; static;

    /// <summary>Generate random number in range</summary>
    class function RandomInt(AMin, AMax: Integer): Integer; static;

    /// <summary>Generate UUID/GUID</summary>
    class function NewGuid: string; static;
    class function NewGuidNoDashes: string; static;

    /// <summary>Generate secure token</summary>
    class function SecureToken(ALength: Integer = 32): string; static;

    /// <summary>Generate OTP (One-Time Password)</summary>
    class function GenerateOTP(ADigits: Integer = 6): string; static;
  end;

implementation

function CryptoRandomBytes(ALength: Integer): TBytes;
begin
  Result := TRandomGenerator.RandomBytes(ALength);
end;

{ TRandomGenerator }

class function TRandomGenerator.RandomBytes(ALength: Integer): TBytes;
{$IFDEF MSWINDOWS}
var
  LStatus: NTSTATUS;
{$ELSE}
var
  I: Integer;
{$ENDIF}
begin
  SetLength(Result, ALength);
  if ALength = 0 then
    Exit;

  {$IFDEF MSWINDOWS}
  // Use cryptographically secure random number generator
  LStatus := BCryptGenRandom(0, @Result[0], ALength, BCRYPT_USE_SYSTEM_PREFERRED_RNG);
  if LStatus <> STATUS_SUCCESS then
    raise ECryptoException.CreateFmt('BCryptGenRandom failed with status: %d', [LStatus]);
  {$ELSE}
  // BUG-035 FIX: Use /dev/urandom on non-Windows platforms for cryptographically secure random
  var URandom: TFileStream;
  try
    URandom := TFileStream.Create('/dev/urandom', fmOpenRead or fmShareDenyNone);
    try
      if URandom.Read(Result[0], ALength) <> ALength then
        raise ECryptoException.Create('Failed to read from /dev/urandom');
    finally
      URandom.Free;
    end;
  except
    on E: Exception do
    begin
      // BASIC-015 fix: fail-closed. A security-critical random generator
      // must NOT silently degrade to Delphi's non-cryptographic Random().
      // If /dev/urandom is unavailable, raise so the caller knows the
      // output is not safe for keys, tokens, or nonces.
      raise ECryptoException.Create(
        'Cryptographic random unavailable: /dev/urandom failed (' + E.Message + ')');
    end;
  end;
  {$ENDIF}
end;

class function TRandomGenerator.RandomString(ALength: Integer): string;
const
  Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
var
  I: Integer;
  LBytes: TBytes;
begin
  // BUG-035 FIX: Use cryptographically secure random bytes
  SetLength(Result, ALength);
  LBytes := RandomBytes(ALength);
  for I := 1 to ALength do
    Result[I] := Chars[(LBytes[I-1] mod Length(Chars)) + 1];
end;

class function TRandomGenerator.RandomHex(ALength: Integer): string;
const
  HexChars = '0123456789abcdef';
var
  I: Integer;
  LBytes: TBytes;
begin
  // BUG-035 FIX: Use cryptographically secure random bytes
  SetLength(Result, ALength);
  LBytes := RandomBytes(ALength);
  for I := 1 to ALength do
    Result[I] := HexChars[(LBytes[I-1] mod 16) + 1];
end;

class function TRandomGenerator.RandomInt(AMin, AMax: Integer): Integer;
var
  LBytes: TBytes;
  LRaw: Cardinal;
  LRange, LThreshold, LVal: UInt64;
begin
  if AMax < AMin then
    raise ECryptoException.CreateFmt('Invalid random range: %d..%d', [AMin, AMax]);

  LRange := UInt64(Int64(AMax) - Int64(AMin)) + 1;
  // Rejection sampling to eliminate modulo bias
  // Reject values >= largest multiple of LRange that fits in 32 bits
  LThreshold := (UInt64(Cardinal($FFFFFFFF)) + 1) mod LRange;
  repeat
    LBytes := RandomBytes(4);
    Move(LBytes[0], LRaw, SizeOf(LRaw));
    LVal := UInt64(LRaw);
  until LVal >= LThreshold;
  Result := Integer(Int64(AMin) + Int64(LVal mod LRange));
end;

class function TRandomGenerator.NewGuid: string;
var
  LGuid: TGUID;
begin
  CreateGUID(LGuid);
  // Return canonical 36-char GUID without braces: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Result := GUIDToString(LGuid).Replace('{', '').Replace('}', '');
end;

class function TRandomGenerator.NewGuidNoDashes: string;
var
  LGuid: TGUID;
begin
  CreateGUID(LGuid);
  Result := GUIDToString(LGuid).Replace('{', '').Replace('}', '').Replace('-', '');
end;

class function TRandomGenerator.SecureToken(ALength: Integer): string;
begin
  Result := TEncodingUtils.Base64UrlEncode(RandomBytes(ALength));
end;

class function TRandomGenerator.GenerateOTP(ADigits: Integer): string;
var
  I: Integer;
  LBytes: TBytes;
begin
  // BUG-035 FIX: Use cryptographically secure random bytes for OTP
  SetLength(Result, ADigits);
  LBytes := RandomBytes(ADigits);
  for I := 1 to ADigits do
    Result[I] := Chr(Ord('0') + (LBytes[I-1] mod 10));
end;

end.
