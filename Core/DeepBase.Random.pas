unit DeepBase.Random;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows, System.Hash,
  DeepBase.Exceptions;

type
  /// <summary>
  /// Cryptographically secure random number generator
  /// 密码学安全的随机数生成器
  /// </summary>
  TSecureRandom = class
  private
    class var FInstance: TSecureRandom;
    class var FLock: TObject;
    class constructor Create;
    class destructor Destroy;
  public
    /// <summary>
    /// Get singleton instance
    /// </summary>
    class function Instance: TSecureRandom;
    
    /// <summary>
    /// Generate cryptographically secure random bytes
    /// 生成密码学安全的随机字节
    /// </summary>
    function NextBytes(const ALength: Integer): TBytes;
    
    /// <summary>
    /// Generate secure random integer in range [0, AMax)
    /// 生成范围内的安全随机整数
    /// </summary>
    function NextInt(const AMax: Integer): Integer;
    
    /// <summary>
    /// Generate secure random integer in range [AMin, AMax]
    /// 生成指定范围的安全随机整数
    /// </summary>
    function NextIntRange(const AMin, AMax: Integer): Integer;
    
    /// <summary>
    /// Generate secure random double in range [0.0, 1.0)
    /// 生成安全随机浮点数
    /// </summary>
    function NextDouble: Double;
    
    /// <summary>
    /// Generate secure random string with specified length and character set
    /// 生成指定长度和字符集的安全随机字符串
    /// </summary>
    function NextString(const ALength: Integer; const ACharSet: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'): string;
    
    /// <summary>
    /// Generate secure random GUID
    /// 生成安全随机GUID
    /// </summary>
    function NextGuid: TGUID;
  end;

/// <summary>
/// Global secure random instance for convenience
/// 全局安全随机实例
/// </summary>
function SecureRandom: TSecureRandom;

implementation

uses
  DeepBase.Logging;

type
  HCRYPTPROV = THandle;

const
  PROV_RSA_FULL = 1;
  CRYPT_VERIFYCONTEXT = $F0000000;

function CryptAcquireContext(var phProv: HCRYPTPROV; pszContainer: PAnsiChar;
  pszProvider: PAnsiChar; dwProvType: DWORD; dwFlags: DWORD): BOOL; stdcall;
  external 'advapi32.dll' name 'CryptAcquireContextA';

function CryptReleaseContext(hProv: HCRYPTPROV; dwFlags: DWORD): BOOL; stdcall;
  external 'advapi32.dll';

function CryptGenRandom(hProv: HCRYPTPROV; dwLen: DWORD; pbBuffer: PByte): BOOL; stdcall;
  external 'advapi32.dll';

{ TSecureRandom }

class constructor TSecureRandom.Create;
begin
  FLock := TObject.Create;
end;

class destructor TSecureRandom.Destroy;
begin
  FreeAndNil(FInstance);
  FreeAndNil(FLock);
end;

class function TSecureRandom.Instance: TSecureRandom;
begin
  if not Assigned(FInstance) then
  begin
    TMonitor.Enter(FLock);
    try
      if not Assigned(FInstance) then
        FInstance := TSecureRandom.Create;
    finally
      TMonitor.Exit(FLock);
    end;
  end;
  Result := FInstance;
end;

function TSecureRandom.NextBytes(const ALength: Integer): TBytes;
var
  hProv: HCRYPTPROV;
begin
  if ALength <= 0 then
    raise EArgumentException.Create('Length must be positive');
    
  if ALength > 1024 * 1024 then // 1MB limit
    raise EArgumentException.Create('Length too large (max 1MB)');
    
  SetLength(Result, ALength);
  
  // Use Windows CryptoAPI for cryptographically secure random bytes
  if not CryptAcquireContext(hProv, nil, nil, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT) then
    raise ERandomException.Create('Failed to acquire crypto context');

  try
    if not CryptGenRandom(hProv, ALength, @Result[0]) then
      raise ERandomException.Create('Failed to generate secure random bytes');
  finally
    CryptReleaseContext(hProv, 0);
  end;
end;

function TSecureRandom.NextInt(const AMax: Integer): Integer;
var
  Bytes: TBytes;
  Value: Cardinal;
begin
  if AMax <= 0 then
    raise EArgumentException.Create('Max must be positive');
    
  // Generate 4 random bytes
  Bytes := NextBytes(4);
  Value := (Cardinal(Bytes[0]) shl 24) or (Cardinal(Bytes[1]) shl 16) or 
           (Cardinal(Bytes[2]) shl 8) or Cardinal(Bytes[3]);
           
  // Use modulo with bias reduction
  Result := Integer(Value mod Cardinal(AMax));
end;

function TSecureRandom.NextIntRange(const AMin, AMax: Integer): Integer;
begin
  if AMin >= AMax then
    raise EArgumentException.Create('Min must be less than Max');
    
  Result := AMin + NextInt(AMax - AMin + 1);
end;

function TSecureRandom.NextDouble: Double;
var
  Bytes: TBytes;
  Value: UInt64;
begin
  // Generate 8 random bytes
  Bytes := NextBytes(8);
  Value := (UInt64(Bytes[0]) shl 56) or (UInt64(Bytes[1]) shl 48) or
           (UInt64(Bytes[2]) shl 40) or (UInt64(Bytes[3]) shl 32) or
           (UInt64(Bytes[4]) shl 24) or (UInt64(Bytes[5]) shl 16) or
           (UInt64(Bytes[6]) shl 8) or UInt64(Bytes[7]);
           
  // Convert to double in range [0.0, 1.0)
  Result := (Value shr 11) * (1.0 / (1 shl 53));
end;

function TSecureRandom.NextString(const ALength: Integer; const ACharSet: string): string;
var
  I: Integer;
  CharIndex: Integer;
begin
  if ALength <= 0 then
    raise EArgumentException.Create('Length must be positive');
    
  if ALength > 10000 then // Reasonable limit
    raise EArgumentException.Create('Length too large (max 10000)');
    
  if ACharSet.IsEmpty then
    raise EArgumentException.Create('Character set cannot be empty');
    
  SetLength(Result, ALength);
  
  for I := 1 to ALength do
  begin
    CharIndex := NextInt(Length(ACharSet));
    Result[I] := ACharSet[CharIndex + 1]; // Delphi strings are 1-based
  end;
end;

function TSecureRandom.NextGuid: TGUID;
var
  Bytes: TBytes;
begin
  // Generate 16 random bytes
  Bytes := NextBytes(16);
  
  // Set version (4) and variant bits according to RFC 4122
  Bytes[6] := (Bytes[6] and $0F) or $40; // Version 4
  Bytes[8] := (Bytes[8] and $3F) or $80; // Variant 10
  
  // Copy to GUID structure
  Move(Bytes[0], Result, SizeOf(TGUID));
end;

function SecureRandom: TSecureRandom;
begin
  Result := TSecureRandom.Instance;
end;

end.
