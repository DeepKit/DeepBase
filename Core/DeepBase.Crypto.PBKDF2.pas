unit DeepBase.Crypto.PBKDF2;

interface

uses
  System.SysUtils, System.Classes, System.Hash, System.Math;

type
  /// <summary>
  /// PBKDF2 (Password-Based Key Derivation Function 2) implementation
  /// RFC 2898 compliant key derivation function
  /// </summary>
  TPBKDF2 = class
  public
    /// <summary>
    /// Derives a key using PBKDF2-HMAC-SHA256
    /// </summary>
    /// <param name="APassword">Password bytes</param>
    /// <param name="ASalt">Salt bytes</param>
    /// <param name="AIterations">Number of iterations (minimum 1000)</param>
    /// <param name="AKeyLength">Desired key length in bytes</param>
    /// <returns>Derived key bytes</returns>
    function GetBytes(const APassword, ASalt: TBytes; AIterations, AKeyLength: Integer): TBytes;
  private
    function HMACSHA256(const AKey, AData: TBytes): TBytes;
    function XorBytes(const A, B: TBytes): TBytes;
  end;

implementation

function TPBKDF2.HMACSHA256(const AKey, AData: TBytes): TBytes;
const
  BLOCK_SIZE = 64; // SHA-256 block size
var
  Key: TBytes;
  InnerPad, OuterPad: TBytes;
  I: Integer;
  InnerHash, OuterHash: THashSHA2;
begin
  // Prepare key
  if Length(AKey) > BLOCK_SIZE then
  begin
    // Key is longer than block size, hash it (raw bytes, no UTF-8 round-trip)
    InnerHash := THashSHA2.Create;
    InnerHash.Update(AKey);
    Key := InnerHash.HashAsBytes;
  end
  else
  begin
    Key := Copy(AKey);
  end;
  
  // Pad key to block size
  SetLength(Key, BLOCK_SIZE);
  for I := Length(AKey) to BLOCK_SIZE - 1 do
    Key[I] := 0;
  
  // Create inner and outer padding
  SetLength(InnerPad, BLOCK_SIZE);
  SetLength(OuterPad, BLOCK_SIZE);
  
  for I := 0 to BLOCK_SIZE - 1 do
  begin
    InnerPad[I] := Key[I] xor $36;
    OuterPad[I] := Key[I] xor $5C;
  end;
  
  // Inner hash: SHA256(key XOR ipad || data)
  InnerHash := THashSHA2.Create;
  InnerHash.Update(InnerPad);
  InnerHash.Update(AData);
  
  // Outer hash: SHA256(key XOR opad || inner_hash)
  OuterHash := THashSHA2.Create;
  OuterHash.Update(OuterPad);
  OuterHash.Update(InnerHash.HashAsBytes);
  
  Result := OuterHash.HashAsBytes;
end;

function TPBKDF2.XorBytes(const A, B: TBytes): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(A));
  for I := 0 to Length(A) - 1 do
    Result[I] := A[I] xor B[I];
end;

function TPBKDF2.GetBytes(const APassword, ASalt: TBytes; AIterations, AKeyLength: Integer): TBytes;
var
  BlockCount, I, J: Integer;
  Block: TBytes;
  U, F: TBytes;
  SaltWithIndex: TBytes;
begin
  if AIterations < 1000 then
    raise EArgumentException.Create('PBKDF2 iterations must be at least 1000');
    
  if AKeyLength <= 0 then
    raise EArgumentException.Create('Key length must be positive');
  
  // Calculate number of blocks needed
  BlockCount := (AKeyLength + 31) div 32; // 32 bytes per SHA-256 hash
  
  SetLength(Result, 0);
  
  for I := 1 to BlockCount do
  begin
    // Prepare salt with block index
    SetLength(SaltWithIndex, Length(ASalt) + 4);
    Move(ASalt[0], SaltWithIndex[0], Length(ASalt));
    SaltWithIndex[Length(ASalt)] := (I shr 24) and $FF;
    SaltWithIndex[Length(ASalt) + 1] := (I shr 16) and $FF;
    SaltWithIndex[Length(ASalt) + 2] := (I shr 8) and $FF;
    SaltWithIndex[Length(ASalt) + 3] := I and $FF;
    
    // First iteration: U1 = HMAC(password, salt || i)
    U := HMACSHA256(APassword, SaltWithIndex);
    F := Copy(U);
    
    // Subsequent iterations: Ui = HMAC(password, Ui-1)
    for J := 2 to AIterations do
    begin
      U := HMACSHA256(APassword, U);
      F := XorBytes(F, U);
    end;
    
    // Append block to result
    Block := Copy(F, 0, Min(32, AKeyLength - Length(Result)));
    SetLength(Result, Length(Result) + Length(Block));
    Move(Block[0], Result[Length(Result) - Length(Block)], Length(Block));
  end;
  
  // Truncate to desired length
  SetLength(Result, AKeyLength);
end;

end.