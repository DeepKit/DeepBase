{ ============================================================================
  Test.Regression.BUG035_InsecureRandom - Insecure Random Generation Regression Test

  BUG-035: Insecure Random Number Generation
  
  Original Issue: Using Delphi Random() function on non-Windows platforms,
                  which is not cryptographically secure and may produce
                  predictable random sequences.
  
  Fix: Use /dev/urandom for secure random on non-Windows platforms;
       Improve RandomString, RandomHex, RandomInt, GenerateOTP,
       GeneratePassword methods to use secure random bytes.
  
  Fix Date: 2025-12-16
  File: Core/DeepBase.Crypto.pas
  Priority: P0 (Critical)
  Category: Security
  ============================================================================ }

unit Test.Regression.BUG035_InsecureRandom;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  Test.Regression.Base;

type
  [TestFixture]
  [Category('Regression')]
  [Category('P0')]
  [Category('Security')]
  TBug035_InsecureRandomTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    [Description('Verify RandomBytes generates bytes with sufficient entropy')]
    procedure Test_RandomBytes_HasSufficientEntropy;
    
    [Test]
    [Description('Verify RandomString does not produce predictable sequences')]
    procedure Test_RandomString_IsNotPredictable;
    
    [Test]
    [Description('Verify RandomHex generates random hex strings')]
    procedure Test_RandomHex_IsRandom;
    
    [Test]
    [Description('Verify RandomInt is uniformly distributed')]
    procedure Test_RandomInt_IsUniformlyDistributed;
    
    [Test]
    [Description('Verify GenerateOTP generates unique OTPs')]
    procedure Test_GenerateOTP_IsUnique;
    
    [Test]
    [Description('Verify SecureToken generates tokens with sufficient strength')]
    procedure Test_SecureToken_HasSufficientStrength;
    
    [Test]
    [Description('Verify consecutive randoms are different')]
    procedure Test_ConsecutiveRandoms_AreDifferent;
  end;

implementation

uses
  DeepBase.Crypto;

{ TBug035_InsecureRandomTest }

function TBug035_InsecureRandomTest.GetBugNumber: string;
begin
  Result := 'BUG-035';
end;

function TBug035_InsecureRandomTest.GetBugDescription: string;
begin
  Result := 'Insecure random number generation';
end;

function TBug035_InsecureRandomTest.GetFixDate: string;
begin
  Result := '2025-12-16';
end;

function TBug035_InsecureRandomTest.GetPriority: string;
begin
  Result := 'P0';
end;

function TBug035_InsecureRandomTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.Crypto.pas';
end;

procedure TBug035_InsecureRandomTest.Test_RandomBytes_HasSufficientEntropy;
var
  Bytes: TBytes;
  ByteCounts: array[0..255] of Integer;
  I: Integer;
  ZeroCount: Integer;
  UniqueBytes: Integer;
begin
  LogTestStart('Test_RandomBytes_HasSufficientEntropy');
  
  // Generate 1000 bytes of random data
  Bytes := TRandomGenerator.RandomBytes(1000);
  
  Assert.AreEqual(Integer(1000), Integer(Length(Bytes)), 'Should generate specified length');
  
  // Count occurrences of each byte value
  FillChar(ByteCounts, SizeOf(ByteCounts), 0);
  for I := 0 to High(Bytes) do
    Inc(ByteCounts[Bytes[I]]);
  
  // Check not all zeros
  ZeroCount := 0;
  for I := 0 to High(Bytes) do
    if Bytes[I] = 0 then
      Inc(ZeroCount);
  
  Assert.IsTrue(ZeroCount < 100, 
    'Too many zero bytes (expected < 100, got: ' + IntToStr(ZeroCount) + ')');
  
  // Check sufficient variety (at least 200 different values)
  UniqueBytes := 0;
  for I := 0 to 255 do
    if ByteCounts[I] > 0 then
      Inc(UniqueBytes);
  
  Assert.IsTrue(UniqueBytes >= 200, 
    'Should have sufficient byte variety (expected >= 200, got: ' + IntToStr(UniqueBytes) + ')');
  
  LogTestEnd('Test_RandomBytes_HasSufficientEntropy', True);
end;

procedure TBug035_InsecureRandomTest.Test_RandomString_IsNotPredictable;
var
  Strings: TList<string>;
  I: Integer;
  S: string;
begin
  LogTestStart('Test_RandomString_IsNotPredictable');
  
  Strings := TList<string>.Create;
  try
    // Generate 100 random strings
    for I := 1 to 100 do
    begin
      S := TRandomGenerator.RandomString(32);
      Assert.AreEqual(32, Integer(Length(S), 'Random string length should be correct');
      
      // Check for duplicates
      Assert.IsFalse(Strings.Contains(S), 
        'Random strings should not repeat (at index ' + IntToStr(I) + ')');
      
      Strings.Add(S);
    end;
  finally
    Strings.Free;
  end;
  
  LogTestEnd('Test_RandomString_IsNotPredictable', True);
end;

procedure TBug035_InsecureRandomTest.Test_RandomHex_IsRandom;
var
  HexStrings: TList<string>;
  I: Integer;
  S: string;
  C: Char;
begin
  LogTestStart('Test_RandomHex_IsRandom');
  
  HexStrings := TList<string>.Create;
  try
    for I := 1 to 50 do
    begin
      S := TRandomGenerator.RandomHex(64);
      Assert.AreEqual(64, Integer(Length(S), 'Random hex string length should be correct');
      
      // Verify only valid hex characters
      for C in S do
        Assert.IsTrue(CharInSet(C, ['0'..'9', 'a'..'f', 'A'..'F']),
          'Should only contain valid hex characters');
      
      Assert.IsFalse(HexStrings.Contains(S), 'Random hex strings should not repeat');
      HexStrings.Add(S);
    end;
  finally
    HexStrings.Free;
  end;
  
  LogTestEnd('Test_RandomHex_IsRandom', True);
end;

procedure TBug035_InsecureRandomTest.Test_RandomInt_IsUniformlyDistributed;
var
  Counts: array[0..9] of Integer;
  I, R: Integer;
  MinCount, MaxCount: Integer;
begin
  LogTestStart('Test_RandomInt_IsUniformlyDistributed');
  
  FillChar(Counts, SizeOf(Counts), 0);
  
  // Generate 10000 random numbers in range 0-9
  for I := 1 to 10000 do
  begin
    R := TRandomGenerator.RandomInt(0, 9);
    Assert.IsTrue((R >= 0) and (R <= 9), 'Random number should be in specified range');
    Inc(Counts[R]);
  end;
  
  // Check distribution is roughly uniform (each should appear ~1000 times, allow 30% deviation)
  MinCount := 10000;
  MaxCount := 0;
  for I := 0 to 9 do
  begin
    if Counts[I] < MinCount then MinCount := Counts[I];
    if Counts[I] > MaxCount then MaxCount := Counts[I];
  end;
  
  Assert.IsTrue(MinCount >= 700, 
    'Minimum count should be >= 700 (got: ' + IntToStr(MinCount) + ')');
  Assert.IsTrue(MaxCount <= 1300, 
    'Maximum count should be <= 1300 (got: ' + IntToStr(MaxCount) + ')');
  
  LogTestEnd('Test_RandomInt_IsUniformlyDistributed', True);
end;

procedure TBug035_InsecureRandomTest.Test_GenerateOTP_IsUnique;
var
  OTPs: TList<string>;
  I: Integer;
  OTP: string;
  OTPInt: Integer;
  DuplicateCount: Integer;
begin
  LogTestStart('Test_GenerateOTP_IsUnique');
  
  OTPs := TList<string>.Create;
  try
    DuplicateCount := 0;
    for I := 1 to 100 do
    begin
      OTP := TRandomGenerator.GenerateOTP(6);
      Assert.AreEqual(6, Integer(Length(OTP), 'OTP length should be correct');
      
      // Verify only contains digits
      Assert.IsTrue(TryStrToInt(OTP, OTPInt), 'OTP should only contain digits');
      
      if OTPs.Contains(OTP) then
        Inc(DuplicateCount)
      else
        OTPs.Add(OTP);
    end;

    // For 6-digit OTP space (1,000,000 possibilities), 100 samples should
    // have very low collision rate; allow a small buffer to avoid flaky CI.
    Assert.IsTrue(DuplicateCount <= 5,
      'OTP collision rate is unexpectedly high (duplicates: ' +
      IntToStr(DuplicateCount) + ')');
  finally
    OTPs.Free;
  end;
  
  LogTestEnd('Test_GenerateOTP_IsUnique', True);
end;

procedure TBug035_InsecureRandomTest.Test_SecureToken_HasSufficientStrength;
var
  Token: string;
  I: Integer;
  Tokens: TList<string>;
begin
  LogTestStart('Test_SecureToken_HasSufficientStrength');
  
  Tokens := TList<string>.Create;
  try
    for I := 1 to 50 do
    begin
      Token := TRandomGenerator.SecureToken(32);
      
      // Verify length (Base64 encoding makes it longer)
      Assert.IsTrue(Length(Token) >= 32, 
        'Secure token should have sufficient length (got: ' + IntToStr(Length(Token)) + ')');
      
      Assert.IsFalse(Tokens.Contains(Token), 'Secure tokens should not repeat');
      Tokens.Add(Token);
    end;
  finally
    Tokens.Free;
  end;
  
  LogTestEnd('Test_SecureToken_HasSufficientStrength', True);
end;

procedure TBug035_InsecureRandomTest.Test_ConsecutiveRandoms_AreDifferent;
var
  Bytes1, Bytes2, Bytes3: TBytes;
  S1, S2, S3: string;
begin
  LogTestStart('Test_ConsecutiveRandoms_AreDifferent');
  
  // Generate three consecutive random byte arrays
  Bytes1 := TRandomGenerator.RandomBytes(32);
  Bytes2 := TRandomGenerator.RandomBytes(32);
  Bytes3 := TRandomGenerator.RandomBytes(32);
  
  // Convert to hex strings for comparison
  S1 := TEncodingUtils.HexEncode(Bytes1);
  S2 := TEncodingUtils.HexEncode(Bytes2);
  S3 := TEncodingUtils.HexEncode(Bytes3);
  
  Assert.AreNotEqual(S1, S2, 'Consecutive random bytes should differ (1 vs 2)');
  Assert.AreNotEqual(S2, S3, 'Consecutive random bytes should differ (2 vs 3)');
  Assert.AreNotEqual(S1, S3, 'Consecutive random bytes should differ (1 vs 3)');
  
  LogTestEnd('Test_ConsecutiveRandoms_AreDifferent', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug035_InsecureRandomTest);

end.
