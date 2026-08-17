unit DeepBase.Crypto.Hash;

{*******************************************************************************
  DeepBase Crypto - Hash Utilities
  Hash algorithms (MD5, SHA1, SHA256, SHA384, SHA512), HMAC, CRC32/Adler32,
  and password hashing (PBKDF2).

  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Hash, System.NetEncoding, System.Math,
  DeepBase.Crypto.Platform, DeepBase.Crypto.Encoding, DeepBase.Crypto.Random;

type
  /// <summary>Hash algorithm type</summary>
  THashAlgorithm = (haMD5, haSHA1, haSHA256, haSHA384, haSHA512);

  /// <summary>Hash utilities</summary>
  THashUtils = class
  public
    /// <summary>Compute hash of bytes</summary>
    class function HashBytes(const AData: TBytes; AAlgorithm: THashAlgorithm = haSHA256): TBytes; static;

    /// <summary>Compute hash of string</summary>
    class function HashString(const AData: string; AAlgorithm: THashAlgorithm = haSHA256;
      AEncoding: TEncoding = nil): TBytes; static;

    /// <summary>Compute hash of stream</summary>
    class function HashStream(AStream: TStream; AAlgorithm: THashAlgorithm = haSHA256): TBytes; static;

    /// <summary>Compute hash of file</summary>
    class function HashFile(const AFileName: string; AAlgorithm: THashAlgorithm = haSHA256): TBytes; static;

    /// <summary>Get hash as hex string</summary>
    class function HashToHex(const AData: TBytes; AAlgorithm: THashAlgorithm = haSHA256): string; overload; static;
    class function HashToHex(const AData: string; AAlgorithm: THashAlgorithm = haSHA256): string; overload; static;

    /// <summary>MD5 shortcuts</summary>
    class function MD5(const AData: TBytes): TBytes; overload; static;
    class function MD5(const AData: string): string; overload; static;
    class function MD5File(const AFileName: string): string; static;

    /// <summary>SHA1 shortcuts</summary>
    class function SHA1(const AData: TBytes): TBytes; overload; static;
    class function SHA1(const AData: string): string; overload; static;
    class function SHA1File(const AFileName: string): string; static;

    /// <summary>SHA256 shortcuts</summary>
    class function SHA256(const AData: TBytes): TBytes; overload; static;
    class function SHA256(const AData: string): string; overload; static;
    class function SHA256File(const AFileName: string): string; static;

    /// <summary>SHA512 shortcuts</summary>
    class function SHA512(const AData: TBytes): TBytes; overload; static;
    class function SHA512(const AData: string): string; overload; static;
    class function SHA512File(const AFileName: string): string; static;

    /// <summary>HMAC</summary>
    class function HMAC(const AKey, AData: TBytes; AAlgorithm: THashAlgorithm = haSHA256): TBytes; overload; static;
    class function HMAC(const AKey, AData: string; AAlgorithm: THashAlgorithm = haSHA256): string; overload; static;
  end;

  /// <summary>Password hashing options</summary>
  TPasswordHashOptions = record
    Iterations: Integer;     // PBKDF2 iterations (default: 100000)
    SaltLength: Integer;     // Salt length in bytes (default: 16)
    HashLength: Integer;     // Hash output length in bytes (default: 32)
    Algorithm: THashAlgorithm; // Hash algorithm (default: haSHA256)

    class function Default: TPasswordHashOptions; static;
  end;

  /// <summary>Password hashing utilities</summary>
  TPasswordUtils = class
  public
    /// <summary>Hash password with PBKDF2</summary>
    class function HashPassword(const APassword: string;
      const AOptions: TPasswordHashOptions): string; overload; static;
    class function HashPassword(const APassword: string): string; overload; static;

    /// <summary>Verify password against hash</summary>
    class function VerifyPassword(const APassword, AHash: string): Boolean; static;

    /// <summary>Generate salt</summary>
    class function GenerateSalt(ALength: Integer = 16): TBytes; static;

    /// <summary>PBKDF2 key derivation</summary>
    class function PBKDF2(const APassword: string; const ASalt: TBytes;
      AIterations, AKeyLength: Integer; AAlgorithm: THashAlgorithm = haSHA256): TBytes; static;

    /// <summary>Check password strength</summary>
    class function CheckStrength(const APassword: string): Integer; static;

    /// <summary>Generate random password</summary>
    class function GeneratePassword(ALength: Integer = 16;
      AIncludeUppercase: Boolean = True;
      AIncludeLowercase: Boolean = True;
      AIncludeDigits: Boolean = True;
      AIncludeSpecial: Boolean = True): string; static;
  end;

  /// <summary>CRC utilities</summary>
  TCRCUtils = class
  public
    /// <summary>CRC32 checksum</summary>
    class function CRC32(const AData: TBytes): Cardinal; overload; static;
    class function CRC32(const AData: string): Cardinal; overload; static;
    class function CRC32File(const AFileName: string): Cardinal; static;

    /// <summary>Adler32 checksum</summary>
    class function Adler32(const AData: TBytes): Cardinal; overload; static;
    class function Adler32(const AData: string): Cardinal; overload; static;
  end;

implementation

{ THashUtils }

class function THashUtils.HashBytes(const AData: TBytes; AAlgorithm: THashAlgorithm): TBytes;
var
  Hash: THashMD5;
  HashSHA1: THashSHA1;
  HashSHA2: THashSHA2;
begin
  case AAlgorithm of
    haMD5:
      begin
        Hash := THashMD5.Create;
        Hash.Update(AData, Length(AData));
        Result := Hash.HashAsBytes;
      end;
    haSHA1:
      begin
        HashSHA1 := THashSHA1.Create;
        HashSHA1.Update(AData, Length(AData));
        Result := HashSHA1.HashAsBytes;
      end;
    haSHA256:
      begin
        HashSHA2 := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
        HashSHA2.Update(AData, Length(AData));
        Result := HashSHA2.HashAsBytes;
      end;
    haSHA384:
      begin
        HashSHA2 := THashSHA2.Create(THashSHA2.TSHA2Version.SHA384);
        HashSHA2.Update(AData, Length(AData));
        Result := HashSHA2.HashAsBytes;
      end;
    haSHA512:
      begin
        HashSHA2 := THashSHA2.Create(THashSHA2.TSHA2Version.SHA512);
        HashSHA2.Update(AData, Length(AData));
        Result := HashSHA2.HashAsBytes;
      end;
  else
    begin
      HashSHA2 := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
      HashSHA2.Update(AData, Length(AData));
      Result := HashSHA2.HashAsBytes;
    end;
  end;
end;

class function THashUtils.HashString(const AData: string; AAlgorithm: THashAlgorithm;
  AEncoding: TEncoding): TBytes;
begin
  if AEncoding = nil then
    AEncoding := TEncoding.UTF8;
  Result := HashBytes(AEncoding.GetBytes(AData), AAlgorithm);
end;

class function THashUtils.HashStream(AStream: TStream; AAlgorithm: THashAlgorithm): TBytes;
const
  HASH_STREAM_BUFFER_SIZE = 65536; // 64 KB chunks — keeps memory bounded for large streams
var
  LBuffer: TBytes;
  LBytesRead: Integer;
  LHashMD5: THashMD5;
  LHashSHA1: THashSHA1;
  LHashSHA2: THashSHA2;
  LPos: Int64;
begin
  LPos := AStream.Position;
  SetLength(LBuffer, HASH_STREAM_BUFFER_SIZE);
  try
    AStream.Position := 0;

    // CORE-R2-009: Feed the stream in fixed-size chunks via Update() so
    // memory usage stays bounded regardless of stream/file size.
    case AAlgorithm of
      haMD5:
        begin
          LHashMD5 := THashMD5.Create;
          repeat
            LBytesRead := AStream.Read(LBuffer[0], HASH_STREAM_BUFFER_SIZE);
            if LBytesRead > 0 then
              LHashMD5.Update(LBuffer[0], LBytesRead);
          until LBytesRead = 0;
          Result := LHashMD5.HashAsBytes;
        end;
      haSHA1:
        begin
          LHashSHA1 := THashSHA1.Create;
          repeat
            LBytesRead := AStream.Read(LBuffer[0], HASH_STREAM_BUFFER_SIZE);
            if LBytesRead > 0 then
              LHashSHA1.Update(LBuffer[0], LBytesRead);
          until LBytesRead = 0;
          Result := LHashSHA1.HashAsBytes;
        end;
      haSHA256:
        begin
          LHashSHA2 := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
          repeat
            LBytesRead := AStream.Read(LBuffer[0], HASH_STREAM_BUFFER_SIZE);
            if LBytesRead > 0 then
              LHashSHA2.Update(LBuffer[0], LBytesRead);
          until LBytesRead = 0;
          Result := LHashSHA2.HashAsBytes;
        end;
      haSHA384:
        begin
          LHashSHA2 := THashSHA2.Create(THashSHA2.TSHA2Version.SHA384);
          repeat
            LBytesRead := AStream.Read(LBuffer[0], HASH_STREAM_BUFFER_SIZE);
            if LBytesRead > 0 then
              LHashSHA2.Update(LBuffer[0], LBytesRead);
          until LBytesRead = 0;
          Result := LHashSHA2.HashAsBytes;
        end;
      haSHA512:
        begin
          LHashSHA2 := THashSHA2.Create(THashSHA2.TSHA2Version.SHA512);
          repeat
            LBytesRead := AStream.Read(LBuffer[0], HASH_STREAM_BUFFER_SIZE);
            if LBytesRead > 0 then
              LHashSHA2.Update(LBuffer[0], LBytesRead);
          until LBytesRead = 0;
          Result := LHashSHA2.HashAsBytes;
        end;
    else
      begin
        LHashSHA2 := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
        repeat
          LBytesRead := AStream.Read(LBuffer[0], HASH_STREAM_BUFFER_SIZE);
          if LBytesRead > 0 then
            LHashSHA2.Update(LBuffer[0], LBytesRead);
        until LBytesRead = 0;
        Result := LHashSHA2.HashAsBytes;
      end;
    end;
  finally
    AStream.Position := LPos;
  end;
end;

class function THashUtils.HashFile(const AFileName: string; AAlgorithm: THashAlgorithm): TBytes;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := HashStream(LStream, AAlgorithm);
  finally
    LStream.Free;
  end;
end;

class function THashUtils.HashToHex(const AData: TBytes; AAlgorithm: THashAlgorithm): string;
var
  LHash: TBytes;
  I: Integer;
begin
  LHash := HashBytes(AData, AAlgorithm);
  Result := '';
  for I := 0 to High(LHash) do
    Result := Result + IntToHex(LHash[I], 2);
  Result := LowerCase(Result);
end;

class function THashUtils.HashToHex(const AData: string; AAlgorithm: THashAlgorithm): string;
begin
  Result := HashToHex(TEncoding.UTF8.GetBytes(AData), AAlgorithm);
end;

class function THashUtils.MD5(const AData: TBytes): TBytes;
begin
  Result := HashBytes(AData, haMD5);
end;

class function THashUtils.MD5(const AData: string): string;
begin
  Result := HashToHex(AData, haMD5);
end;

class function THashUtils.MD5File(const AFileName: string): string;
var
  LHash: TBytes;
  I: Integer;
begin
  LHash := HashFile(AFileName, haMD5);
  Result := '';
  for I := 0 to High(LHash) do
    Result := Result + IntToHex(LHash[I], 2);
  Result := LowerCase(Result);
end;

class function THashUtils.SHA1(const AData: TBytes): TBytes;
begin
  Result := HashBytes(AData, haSHA1);
end;

class function THashUtils.SHA1(const AData: string): string;
begin
  Result := HashToHex(AData, haSHA1);
end;

class function THashUtils.SHA1File(const AFileName: string): string;
var
  LHash: TBytes;
  I: Integer;
begin
  LHash := HashFile(AFileName, haSHA1);
  Result := '';
  for I := 0 to High(LHash) do
    Result := Result + IntToHex(LHash[I], 2);
  Result := LowerCase(Result);
end;

class function THashUtils.SHA256(const AData: TBytes): TBytes;
begin
  Result := HashBytes(AData, haSHA256);
end;

class function THashUtils.SHA256(const AData: string): string;
begin
  Result := HashToHex(AData, haSHA256);
end;

class function THashUtils.SHA256File(const AFileName: string): string;
var
  LHash: TBytes;
  I: Integer;
begin
  LHash := HashFile(AFileName, haSHA256);
  Result := '';
  for I := 0 to High(LHash) do
    Result := Result + IntToHex(LHash[I], 2);
  Result := LowerCase(Result);
end;

class function THashUtils.SHA512(const AData: TBytes): TBytes;
begin
  Result := HashBytes(AData, haSHA512);
end;

class function THashUtils.SHA512(const AData: string): string;
begin
  Result := HashToHex(AData, haSHA512);
end;

class function THashUtils.SHA512File(const AFileName: string): string;
var
  LHash: TBytes;
  I: Integer;
begin
  LHash := HashFile(AFileName, haSHA512);
  Result := '';
  for I := 0 to High(LHash) do
    Result := Result + IntToHex(LHash[I], 2);
  Result := LowerCase(Result);
end;

class function THashUtils.HMAC(const AKey, AData: TBytes; AAlgorithm: THashAlgorithm): TBytes;
var
  LBlockSize: Integer;
  LKeyBlock, LInnerPad, LOuterPad: TBytes;
  LInnerHash: TBytes;
  I: Integer;
begin
  // Block sizes for different algorithms
  case AAlgorithm of
    haMD5: LBlockSize := 64;
    haSHA1: LBlockSize := 64;
    haSHA256: LBlockSize := 64;
    haSHA384: LBlockSize := 128;
    haSHA512: LBlockSize := 128;
  else
    LBlockSize := 64;
  end;

  // Prepare key block
  if Length(AKey) > LBlockSize then
    LKeyBlock := HashBytes(AKey, AAlgorithm)
  else
    LKeyBlock := Copy(AKey);

  SetLength(LKeyBlock, LBlockSize);

  // Create inner and outer pads
  SetLength(LInnerPad, LBlockSize + Length(AData));
  SetLength(LOuterPad, LBlockSize);

  for I := 0 to LBlockSize - 1 do
  begin
    LInnerPad[I] := LKeyBlock[I] xor $36;
    LOuterPad[I] := LKeyBlock[I] xor $5C;
  end;

  // Copy data to inner pad
  if Length(AData) > 0 then
    Move(AData[0], LInnerPad[LBlockSize], Length(AData));

  // Inner hash
  LInnerHash := HashBytes(LInnerPad, AAlgorithm);

  // Outer hash
  SetLength(LOuterPad, LBlockSize + Length(LInnerHash));
  Move(LInnerHash[0], LOuterPad[LBlockSize], Length(LInnerHash));

  Result := HashBytes(LOuterPad, AAlgorithm);
end;

class function THashUtils.HMAC(const AKey, AData: string; AAlgorithm: THashAlgorithm): string;
var
  LHash: TBytes;
  I: Integer;
begin
  LHash := HMAC(TEncoding.UTF8.GetBytes(AKey), TEncoding.UTF8.GetBytes(AData), AAlgorithm);
  Result := '';
  for I := 0 to High(LHash) do
    Result := Result + IntToHex(LHash[I], 2);
  Result := LowerCase(Result);
end;

{ TPasswordHashOptions }

class function TPasswordHashOptions.Default: TPasswordHashOptions;
begin
  Result.Iterations := 100000;
  Result.SaltLength := 16;
  Result.HashLength := 32;
  Result.Algorithm := haSHA256;
end;

{ TPasswordUtils }

class function TPasswordUtils.HashPassword(const APassword: string;
  const AOptions: TPasswordHashOptions): string;
var
  LSalt, LHash: TBytes;
  LSaltB64, LHashB64: string;
begin
  LSalt := GenerateSalt(AOptions.SaltLength);
  LHash := PBKDF2(APassword, LSalt, AOptions.Iterations, AOptions.HashLength, AOptions.Algorithm);

  LSaltB64 := TEncodingUtils.Base64Encode(LSalt);
  LHashB64 := TEncodingUtils.Base64Encode(LHash);

  // Format: $pbkdf2$iterations$algorithm$salt$hash
  Result := Format('$pbkdf2$%d$%d$%s$%s', [AOptions.Iterations, Ord(AOptions.Algorithm), LSaltB64, LHashB64]);
end;

class function TPasswordUtils.HashPassword(const APassword: string): string;
begin
  Result := HashPassword(APassword, TPasswordHashOptions.Default);
end;

class function TPasswordUtils.VerifyPassword(const APassword, AHash: string): Boolean;
var
  LParts: TArray<string>;
  LIterations: Integer;
  LAlgorithm: THashAlgorithm;
  LSalt, LStoredHash, LComputedHash: TBytes;
begin
  Result := False;

  // Validate hash format before any comparison
  if AHash = '' then
    Exit;
  if not AHash.StartsWith('$pbkdf2$') then
    Exit;

  LParts := AHash.Split(['$']);
  if Length(LParts) < 6 then
    Exit;

  // Validate iterations field is a positive integer
  if not TryStrToInt(LParts[2], LIterations) then
    Exit;
  if LIterations <= 0 then
    Exit;

  // Validate algorithm field is in valid enum range
  var LAlgOrd: Integer;
  if not TryStrToInt(LParts[3], LAlgOrd) then
    Exit;
  if (LAlgOrd < Ord(Low(THashAlgorithm))) or (LAlgOrd > Ord(High(THashAlgorithm))) then
    Exit;
  LAlgorithm := THashAlgorithm(LAlgOrd);

  // Validate salt and hash are non-empty
  if (LParts[4] = '') or (LParts[5] = '') then
    Exit;

  try
    LSalt := TEncodingUtils.Base64Decode(LParts[4]);
    LStoredHash := TEncodingUtils.Base64Decode(LParts[5]);

    if (Length(LSalt) = 0) or (Length(LStoredHash) = 0) then
      Exit;

    LComputedHash := PBKDF2(APassword, LSalt, LIterations, Length(LStoredHash), LAlgorithm);

    // Constant-time comparison
    if Length(LComputedHash) <> Length(LStoredHash) then
      Exit;

    var LDiff: Integer := 0;
    for var I := 0 to High(LComputedHash) do
      LDiff := LDiff or (LComputedHash[I] xor LStoredHash[I]);

    Result := LDiff = 0;
  except
    Result := False;
  end;
end;

class function TPasswordUtils.GenerateSalt(ALength: Integer): TBytes;
begin
  Result := TRandomGenerator.RandomBytes(ALength);
end;

class function TPasswordUtils.PBKDF2(const APassword: string; const ASalt: TBytes;
  AIterations, AKeyLength: Integer; AAlgorithm: THashAlgorithm): TBytes;
var
  LHashLen, LBlocks, I, J, K: Integer;
  LPasswordBytes, LBlock, LPrev, LTemp: TBytes;
  LCounter: array[0..3] of Byte;
begin
  LPasswordBytes := TEncoding.UTF8.GetBytes(APassword);

  // Determine hash length
  case AAlgorithm of
    haMD5: LHashLen := 16;
    haSHA1: LHashLen := 20;
    haSHA256: LHashLen := 32;
    haSHA384: LHashLen := 48;
    haSHA512: LHashLen := 64;
  else
    LHashLen := 32;
  end;

  LBlocks := (AKeyLength + LHashLen - 1) div LHashLen;
  SetLength(Result, AKeyLength);

  for I := 1 to LBlocks do
  begin
    // Counter in big-endian
    LCounter[0] := Byte(I shr 24);
    LCounter[1] := Byte(I shr 16);
    LCounter[2] := Byte(I shr 8);
    LCounter[3] := Byte(I);

    // U1 = HMAC(password, salt || counter)
    SetLength(LTemp, Length(ASalt) + 4);
    if Length(ASalt) > 0 then
      Move(ASalt[0], LTemp[0], Length(ASalt));
    Move(LCounter[0], LTemp[Length(ASalt)], 4);

    LPrev := THashUtils.HMAC(LPasswordBytes, LTemp, AAlgorithm);
    LBlock := Copy(LPrev);

    // U2..Uc
    for J := 2 to AIterations do
    begin
      LPrev := THashUtils.HMAC(LPasswordBytes, LPrev, AAlgorithm);
      for K := 0 to High(LBlock) do
        LBlock[K] := LBlock[K] xor LPrev[K];
    end;

    // Copy to result
    for J := 0 to Min(LHashLen, AKeyLength - (I - 1) * LHashLen) - 1 do
      Result[(I - 1) * LHashLen + J] := LBlock[J];
  end;
end;

class function TPasswordUtils.CheckStrength(const APassword: string): Integer;
var
  LHasLower, LHasUpper, LHasDigit, LHasSpecial: Boolean;
  I: Integer;
  C: Char;
begin
  Result := 0;
  if Length(APassword) < 8 then
    Exit(1);

  LHasLower := False;
  LHasUpper := False;
  LHasDigit := False;
  LHasSpecial := False;

  for I := 1 to Length(APassword) do
  begin
    C := APassword[I];
    if CharInSet(C, ['a'..'z']) then LHasLower := True
    else if CharInSet(C, ['A'..'Z']) then LHasUpper := True
    else if CharInSet(C, ['0'..'9']) then LHasDigit := True
    else LHasSpecial := True;
  end;

  // Score based on length
  if Length(APassword) >= 16 then Result := 2
  else if Length(APassword) >= 12 then Result := 1
  else Result := 0;

  // Score based on character types
  if LHasLower then Inc(Result);
  if LHasUpper then Inc(Result);
  if LHasDigit then Inc(Result);
  if LHasSpecial then Inc(Result);

  // Cap at 5 (very strong)
  if Result > 5 then Result := 5;
end;

class function TPasswordUtils.GeneratePassword(ALength: Integer;
  AIncludeUppercase, AIncludeLowercase, AIncludeDigits, AIncludeSpecial: Boolean): string;
var
  LCharset: string;
  I: Integer;
  LBytes: TBytes;
begin
  LCharset := '';
  if AIncludeUppercase then LCharset := LCharset + 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  if AIncludeLowercase then LCharset := LCharset + 'abcdefghijklmnopqrstuvwxyz';
  if AIncludeDigits then LCharset := LCharset + '0123456789';
  if AIncludeSpecial then LCharset := LCharset + '!@#$%^&*()_+-=[]{}|;:,.<>?';

  if LCharset = '' then
    LCharset := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  // BUG-035 FIX: Use cryptographically secure random bytes for password generation
  SetLength(Result, ALength);
  LBytes := TRandomGenerator.RandomBytes(ALength);
  for I := 1 to ALength do
    Result[I] := LCharset[(LBytes[I-1] mod Length(LCharset)) + 1];
end;

{ TCRCUtils }

class function TCRCUtils.CRC32(const AData: TBytes): Cardinal;
const
  CRCTable: array[0..255] of Cardinal = (
    $00000000, $77073096, $EE0E612C, $990951BA, $076DC419, $706AF48F, $E963A535, $9E6495A3,
    $0EDB8832, $79DCB8A4, $E0D5E91E, $97D2D988, $09B64C2B, $7EB17CBD, $E7B82D07, $90BF1D91,
    $1DB71064, $6AB020F2, $F3B97148, $84BE41DE, $1ADAD47D, $6DDDE4EB, $F4D4B551, $83D385C7,
    $136C9856, $646BA8C0, $FD62F97A, $8A65C9EC, $14015C4F, $63066CD9, $FA0F3D63, $8D080DF5,
    $3B6E20C8, $4C69105E, $D56041E4, $A2677172, $3C03E4D1, $4B04D447, $D20D85FD, $A50AB56B,
    $35B5A8FA, $42B2986C, $DBBBC9D6, $ACBCF940, $32D86CE3, $45DF5C75, $DCD60DCF, $ABD13D59,
    $26D930AC, $51DE003A, $C8D75180, $BFD06116, $21B4F4B5, $56B3C423, $CFBA9599, $B8BDA50F,
    $2802B89E, $5F058808, $C60CD9B2, $B10BE924, $2F6F7C87, $58684C11, $C1611DAB, $B6662D3D,
    $76DC4190, $01DB7106, $98D220BC, $EFD5102A, $71B18589, $06B6B51F, $9FBFE4A5, $E8B8D433,
    $7807C9A2, $0F00F934, $9609A88E, $E10E9818, $7F6A0DBB, $086D3D2D, $91646C97, $E6635C01,
    $6B6B51F4, $1C6C6162, $856530D8, $F262004E, $6C0695ED, $1B01A57B, $8208F4C1, $F50FC457,
    $65B0D9C6, $12B7E950, $8BBEB8EA, $FCB9887C, $62DD1DDF, $15DA2D49, $8CD37CF3, $FBD44C65,
    $4DB26158, $3AB551CE, $A3BC0074, $D4BB30E2, $4ADFA541, $3DD895D7, $A4D1C46D, $D3D6F4FB,
    $4369E96A, $346ED9FC, $AD678846, $DA60B8D0, $44042D73, $33031DE5, $AA0A4C5F, $DD0D7CC9,
    $5005713C, $270241AA, $BE0B1010, $C90C2086, $5768B525, $206F85B3, $B966D409, $CE61E49F,
    $5EDEF90E, $29D9C998, $B0D09822, $C7D7A8B4, $59B33D17, $2EB40D81, $B7BD5C3B, $C0BA6CAD,
    $EDB88320, $9ABFB3B6, $03B6E20C, $74B1D29A, $EAD54739, $9DD277AF, $04DB2615, $73DC1683,
    $E3630B12, $94643B84, $0D6D6A3E, $7A6A5AA8, $E40ECF0B, $9309FF9D, $0A00AE27, $7D079EB1,
    $F00F9344, $8708A3D2, $1E01F268, $6906C2FE, $F762575D, $806567CB, $196C3671, $6E6B06E7,
    $FED41B76, $89D32BE0, $10DA7A5A, $67DD4ACC, $F9B9DF6F, $8EBEEFF9, $17B7BE43, $60B08ED5,
    $D6D6A3E8, $A1D1937E, $38D8C2C4, $4FDFF252, $D1BB67F1, $A6BC5767, $3FB506DD, $48B2364B,
    $D80D2BDA, $AF0A1B4C, $36034AF6, $41047A60, $DF60EFC3, $A867DF55, $316E8EEF, $4669BE79,
    $CB61B38C, $BC66831A, $256FD2A0, $5268E236, $CC0C7795, $BB0B4703, $220216B9, $5505262F,
    $C5BA3BBE, $B2BD0B28, $2BB45A92, $5CB36A04, $C2D7FFA7, $B5D0CF31, $2CD99E8B, $5BDEAE1D,
    $9B64C2B0, $EC63F226, $756AA39C, $026D930A, $9C0906A9, $EB0E363F, $72076785, $05005713,
    $95BF4A82, $E2B87A14, $7BB12BAE, $0CB61B38, $92D28E9B, $E5D5BE0D, $7CDCEFB7, $0BDBDF21,
    $86D3D2D4, $F1D4E242, $68DDB3F8, $1FDA836E, $81BE16CD, $F6B9265B, $6FB077E1, $18B74777,
    $88085AE6, $FF0F6A70, $66063BCA, $11010B5C, $8F659EFF, $F862AE69, $616BFFD3, $166CCF45,
    $A00AE278, $D70DD2EE, $4E048354, $3903B3C2, $A7672661, $D06016F7, $4969474D, $3E6E77DB,
    $AED16A4A, $D9D65ADC, $40DF0B66, $37D83BF0, $A9BCAE53, $DEBB9EC5, $47B2CF7F, $30B5FFE9,
    $BDBDF21C, $CABAC28A, $53B39330, $24B4A3A6, $BAD03605, $CDD706B3, $54DE5729, $23D967BF,
    $B3667A2E, $C4614AB8, $5D681B02, $2A6F2B94, $B40BBE37, $C30C8EA1, $5A05DF1B, $2D02EF8D
  );
var
  I: Integer;
begin
  Result := $FFFFFFFF;
  for I := 0 to High(AData) do
    Result := CRCTable[(Result xor AData[I]) and $FF] xor (Result shr 8);
  Result := Result xor $FFFFFFFF;
end;

class function TCRCUtils.CRC32(const AData: string): Cardinal;
begin
  Result := CRC32(TEncoding.UTF8.GetBytes(AData));
end;

class function TCRCUtils.CRC32File(const AFileName: string): Cardinal;
var
  LStream: TFileStream;
  LData: TBytes;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(LData, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(LData[0], LStream.Size);
    Result := CRC32(LData);
  finally
    LStream.Free;
  end;
end;

class function TCRCUtils.Adler32(const AData: TBytes): Cardinal;
var
  A, B: Cardinal;
  I: Integer;
begin
  A := 1;
  B := 0;
  for I := 0 to High(AData) do
  begin
    A := (A + AData[I]) mod 65521;
    B := (B + A) mod 65521;
  end;
  Result := (B shl 16) or A;
end;

class function TCRCUtils.Adler32(const AData: string): Cardinal;
begin
  Result := Adler32(TEncoding.UTF8.GetBytes(AData));
end;

end.
