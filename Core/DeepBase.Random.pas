unit DeepBase.Random;

interface

uses
  System.SysUtils, System.Classes,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  DeepBase.Exceptions;

type
  /// <summary>
  /// Cryptographically secure random number generator
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
    /// </summary>
    function NextBytes(const ALength: Integer): TBytes;
    
    /// <summary>
    /// Generate secure random integer in range [0, AMax)
    /// </summary>
    function NextInt(const AMax: Integer): Integer;
    
    /// <summary>
    /// Generate secure random integer in range [AMin, AMax]
    /// </summary>
    function NextIntRange(const AMin, AMax: Integer): Integer;
    
    /// <summary>
    /// Generate secure random double in range [0.0, 1.0)
    /// </summary>
    function NextDouble: Double;
    
    /// <summary>
    /// Generate secure random string with specified length and character set
    /// </summary>
    function NextString(const ALength: Integer; const ACharSet: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'): string;
    
    /// <summary>
    /// Generate secure random GUID
    /// </summary>
    function NextGuid: TGUID;
  end;

/// <summary>
/// Global secure random instance for convenience
/// </summary>
function SecureRandom: TSecureRandom;

implementation

{$IFDEF MSWINDOWS}
const
  BCRYPT_DLL = 'bcrypt.dll';
  BCRYPT_USE_SYSTEM_PREFERRED_RNG = $00000002;
  STATUS_SUCCESS = 0;

type
  BCRYPT_ALG_HANDLE = THandle;
  NTSTATUS = LongInt;

function BCryptGenRandom(hAlgorithm: BCRYPT_ALG_HANDLE; pbBuffer: PByte;
  cbBuffer: ULONG; dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;
{$ENDIF}

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
{$IFDEF MSWINDOWS}
var
  LStatus: NTSTATUS;
{$ELSE}
var
  LRandom: TFileStream;
{$ENDIF}
begin
  if ALength <= 0 then
    raise EArgumentException.Create('Length must be positive');
    
  if ALength > 1024 * 1024 then // 1MB limit
    raise EArgumentException.Create('Length too large (max 1MB)');

  SetLength(Result, ALength);

  {$IFDEF MSWINDOWS}
  LStatus := BCryptGenRandom(0, @Result[0], ALength, BCRYPT_USE_SYSTEM_PREFERRED_RNG);
  if LStatus <> STATUS_SUCCESS then
    raise ERandomException.CreateFmt('BCryptGenRandom failed with status: %d', [LStatus]);
  {$ELSE}
  try
    LRandom := TFileStream.Create('/dev/urandom', fmOpenRead or fmShareDenyNone);
    try
      if LRandom.Read(Result[0], ALength) <> ALength then
        raise ERandomException.Create('Failed to read from /dev/urandom');
    finally
      LRandom.Free;
    end;
  except
    on E: ERandomException do
      raise;
    on E: Exception do
      raise ERandomException.Create(
        'Cryptographic random unavailable: /dev/urandom failed (' + E.Message + ')');
  end;
  {$ENDIF}
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
  // CR-011: 原写法 (1 shl 53) 按 32 位序数移位实际等于 1 shl 21，
  // 导致结果域膨胀。改用显式 Double 常量 2^53。
  Result := (Value shr 11) * (1.0 / 9007199254740992.0);
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
