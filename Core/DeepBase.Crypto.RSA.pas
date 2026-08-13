unit DeepBase.Crypto.RSA;

{*******************************************************************************
  DeepBase Crypto - RSA Utilities
  RSA signature verification and signing using Windows CNG (BCrypt).
  Supports RSA-SHA256 with PKCS#1 v1.5 padding.

  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  DeepBase.Crypto.Platform, DeepBase.Crypto.Encoding;

{$IFDEF MSWINDOWS}
type
  /// <summary>
  /// RSA signature verification using Windows CNG (BCrypt).
  /// Supports RSA-SHA256 with PKCS#1 v1.5 padding.
  /// </summary>
  TRSAVerifier = class
  private
    FPublicKey: TBytes;       // Raw public key blob for BCrypt
    FPublicKeyLoaded: Boolean;
    FLastError: string;

    function ParsePEMPublicKey(const APEM: string): TBytes;
    function ParseDERPublicKey(const ADER: TBytes): TBytes;
    function BuildBCryptKeyBlob(const AModulus, AExponent: TBytes): TBytes;
  public
    constructor Create;

    /// <summary>Load public key from PEM string</summary>
    function LoadPublicKeyPEM(const APEM: string): Boolean;

    /// <summary>Load public key from DER bytes</summary>
    function LoadPublicKeyDER(const ADER: TBytes): Boolean;

    /// <summary>Load public key from file (PEM or DER)</summary>
    function LoadPublicKeyFile(const AFileName: string): Boolean;

    /// <summary>Verify RSA-SHA256 signature</summary>
    function VerifySignature(const AData, ASignature: TBytes): Boolean; overload;

    /// <summary>Verify RSA-SHA256 signature (Base64 encoded signature)</summary>
    function VerifySignature(const AData: TBytes; const ASignatureBase64: string): Boolean; overload;

    /// <summary>Verify RSA-SHA256 signature (string data, Base64 signature)</summary>
    function VerifySignature(const AData, ASignatureBase64: string): Boolean; overload;

    property IsKeyLoaded: Boolean read FPublicKeyLoaded;
    property LastError: string read FLastError;
  end;

  /// <summary>
  /// RSA-SHA256 signing using Windows CNG (BCrypt).
  /// Loads a PEM private key. Container: PKCS#1 only (BEGIN RSA PRIVATE KEY);
  /// PKCS#8 (BEGIN PRIVATE KEY) is rejected with a diagnostic error.
  /// </summary>
  TRSASigner = class
  private
    FPrivateKeyBlob: TBytes;
    FKeyLoaded: Boolean;
    FLastError: string;
    function ParsePEMPrivateKey(const APEM: string): TBytes;
  public
    constructor Create;
    destructor Destroy; override;
    function LoadPrivateKeyPEM(const APEM: string): Boolean;
    function Sign(const AData: TBytes): TBytes; overload;
    function Sign(const AData: string): string; overload;
    property IsKeyLoaded: Boolean read FKeyLoaded;
    property LastError: string read FLastError;
  end;
{$ENDIF}

implementation

{$IFDEF MSWINDOWS}
{ TRSAVerifier }

constructor TRSAVerifier.Create;
begin
  inherited Create;
  FPublicKeyLoaded := False;
  FLastError := '';
end;

function TRSAVerifier.ParsePEMPublicKey(const APEM: string): TBytes;
var
  LLines: TArray<string>;
  LBase64: string;
  LLine: string;
  LInKey: Boolean;
begin
  Result := nil;
  LBase64 := '';
  LInKey := False;

  LLines := APEM.Split([#10, #13], TStringSplitOptions.ExcludeEmpty);
  for LLine in LLines do
  begin
    // 公钥仅支持 SPKI 容器（BEGIN PUBLIC KEY）。PKCS#1 公钥（BEGIN RSA PUBLIC KEY）
    // 的 RSAPublicKey ::= SEQUENCE 布局与 ParseDERPublicKey 的 SubjectPublicKeyInfo
    // 解析不兼容——此处显式拒绝，避免误导性报错。
    if LLine.Contains('-----BEGIN RSA PUBLIC KEY-----') then
    begin
      FLastError := 'Unsupported key container: PKCS#1 public key (BEGIN RSA PUBLIC KEY). '
        + 'Use SPKI (BEGIN PUBLIC KEY), e.g. openssl rsa -in key.pem -pubout';
      Exit;
    end;
    if LLine.Contains('-----BEGIN') and LLine.Contains('PUBLIC KEY') then
    begin
      LInKey := True;
      Continue;
    end;
    if LLine.Contains('-----END') and LLine.Contains('PUBLIC KEY') then
      Break;
    if LInKey then
      LBase64 := LBase64 + LLine.Trim;
  end;

  if LBase64 = '' then
  begin
    FLastError := 'Invalid PEM format: no public key found';
    Exit;
  end;

  try
    Result := TEncodingUtils.Base64Decode(LBase64);
  except
    on E: Exception do
    begin
      FLastError := 'Base64 decode failed: ' + E.Message;
      Result := nil;
    end;
  end;
end;

function TRSAVerifier.ParseDERPublicKey(const ADER: TBytes): TBytes;
var
  LPos: Integer;
  LLen, LModulusLen, LExponentLen: Integer;
  LModulus, LExponent: TBytes;

  function ReadLength(var APos: Integer): Integer;
  var
    LFirst: Byte;
    LNumBytes, I: Integer;
  begin
    if APos >= Length(ADER) then
      raise ECryptoException.Create('Invalid DER: unexpected end');
    LFirst := ADER[APos];
    Inc(APos);
    if LFirst < $80 then
      Result := LFirst
    else
    begin
      LNumBytes := LFirst and $7F;
      if LNumBytes > 4 then
        raise ECryptoException.Create('Invalid DER: length field too large');
      Result := 0;
      for I := 1 to LNumBytes do
      begin
        if APos >= Length(ADER) then
          raise ECryptoException.Create('Invalid DER: unexpected end in length');
        Result := (Result shl 8) or ADER[APos];
        Inc(APos);
      end;
    end;
    // Validate that declared length does not exceed remaining data
    if Result < 0 then
      raise ECryptoException.Create('Invalid DER: negative length');
    if APos + Result > Length(ADER) then
      raise ECryptoException.CreateFmt(
        'Invalid DER: length %d exceeds remaining data (%d bytes)',
        [Result, Length(ADER) - APos]);
  end;

  procedure SkipTag(AExpectedTag: Byte; var APos: Integer);
  begin
    if APos >= Length(ADER) then
      raise ECryptoException.Create('Invalid DER: unexpected end before tag');
    if ADER[APos] <> AExpectedTag then
      raise ECryptoException.CreateFmt('Invalid DER: expected tag $%x, got $%x', [AExpectedTag, ADER[APos]]);
    Inc(APos);
  end;

begin
  Result := nil;
  if Length(ADER) < 20 then
  begin
    FLastError := 'DER data too short';
    Exit;
  end;

  try
    LPos := 0;

    // SubjectPublicKeyInfo ::= SEQUENCE
    SkipTag($30, LPos); // SEQUENCE
    ReadLength(LPos);

    // algorithm AlgorithmIdentifier ::= SEQUENCE
    SkipTag($30, LPos); // SEQUENCE
    LLen := ReadLength(LPos);
    LPos := LPos + LLen; // Skip algorithm identifier

    // subjectPublicKey BIT STRING
    SkipTag($03, LPos); // BIT STRING
    ReadLength(LPos);
    if LPos >= Length(ADER) then
      raise ECryptoException.Create('Invalid DER: no bit string content');
    Inc(LPos); // Skip unused bits byte (should be 0)

    // The BIT STRING contains RSAPublicKey ::= SEQUENCE
    SkipTag($30, LPos); // SEQUENCE
    ReadLength(LPos);

    // modulus INTEGER
    SkipTag($02, LPos); // INTEGER
    LModulusLen := ReadLength(LPos);
    // Skip leading zero if present (sign byte)
    if (LModulusLen > 0) and (ADER[LPos] = 0) then
    begin
      Inc(LPos);
      Dec(LModulusLen);
    end;
    SetLength(LModulus, LModulusLen);
    if LModulusLen > 0 then
      Move(ADER[LPos], LModulus[0], LModulusLen);
    Inc(LPos, LModulusLen);

    // publicExponent INTEGER
    SkipTag($02, LPos); // INTEGER
    LExponentLen := ReadLength(LPos);
    // Skip leading zero if present
    if (LExponentLen > 0) and (ADER[LPos] = 0) then
    begin
      Inc(LPos);
      Dec(LExponentLen);
    end;
    SetLength(LExponent, LExponentLen);
    if LExponentLen > 0 then
      Move(ADER[LPos], LExponent[0], LExponentLen);

    // Build BCrypt key blob
    Result := BuildBCryptKeyBlob(LModulus, LExponent);
  except
    on E: Exception do
    begin
      FLastError := 'DER parse error: ' + E.Message;
      Result := nil;
    end;
  end;
end;

function TRSAVerifier.BuildBCryptKeyBlob(const AModulus, AExponent: TBytes): TBytes;
var
  LHeader: BCRYPT_RSAKEY_BLOB;
  LBlobSize: Integer;
  LPos: Integer;
begin
  // Build BCRYPT_RSAPUBLIC_BLOB format:
  // BCRYPT_RSAKEY_BLOB header + PublicExponent + Modulus

  LHeader.Magic := BCRYPT_RSAPUBLIC_MAGIC;
  LHeader.BitLength := Length(AModulus) * 8;
  LHeader.cbPublicExp := Length(AExponent);
  LHeader.cbModulus := Length(AModulus);
  LHeader.cbPrime1 := 0;
  LHeader.cbPrime2 := 0;

  LBlobSize := SizeOf(BCRYPT_RSAKEY_BLOB) + Length(AExponent) + Length(AModulus);
  SetLength(Result, LBlobSize);

  LPos := 0;
  Move(LHeader, Result[LPos], SizeOf(BCRYPT_RSAKEY_BLOB));
  Inc(LPos, SizeOf(BCRYPT_RSAKEY_BLOB));

  // Exponent
  if Length(AExponent) > 0 then
    Move(AExponent[0], Result[LPos], Length(AExponent));
  Inc(LPos, Length(AExponent));

  // Modulus
  if Length(AModulus) > 0 then
    Move(AModulus[0], Result[LPos], Length(AModulus));
end;

function TRSAVerifier.LoadPublicKeyPEM(const APEM: string): Boolean;
var
  LDER: TBytes;
begin
  FLastError := '';
  FPublicKeyLoaded := False;

  LDER := ParsePEMPublicKey(APEM);
  if LDER = nil then
    Exit(False);

  FPublicKey := ParseDERPublicKey(LDER);
  FPublicKeyLoaded := FPublicKey <> nil;
  Result := FPublicKeyLoaded;
end;

function TRSAVerifier.LoadPublicKeyDER(const ADER: TBytes): Boolean;
begin
  FLastError := '';
  FPublicKeyLoaded := False;

  FPublicKey := ParseDERPublicKey(ADER);
  FPublicKeyLoaded := FPublicKey <> nil;
  Result := FPublicKeyLoaded;
end;

function TRSAVerifier.LoadPublicKeyFile(const AFileName: string): Boolean;
var
  LStream: TFileStream;
  LBytes: TBytes;
  LPEM: string;
begin
  FLastError := '';
  FPublicKeyLoaded := False;

  if not FileExists(AFileName) then
  begin
    FLastError := 'File not found: ' + AFileName;
    Exit(False);
  end;

  try
    LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(LBytes, LStream.Size);
      if LStream.Size > 0 then
        LStream.ReadBuffer(LBytes[0], LStream.Size);
    finally
      LStream.Free;
    end;

    // Try to detect format - PEM starts with '-----'
    if (Length(LBytes) > 5) and (LBytes[0] = Ord('-')) then
    begin
      LPEM := TEncoding.UTF8.GetString(LBytes);
      Result := LoadPublicKeyPEM(LPEM);
    end
    else
      Result := LoadPublicKeyDER(LBytes);
  except
    on E: Exception do
    begin
      FLastError := 'Failed to read file: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TRSAVerifier.VerifySignature(const AData, ASignature: TBytes): Boolean;
var
  LAlgHandle: BCRYPT_ALG_HANDLE;
  LKeyHandle: BCRYPT_KEY_HANDLE;
  LHashAlgHandle: BCRYPT_ALG_HANDLE;
  LHash: TBytes;
  LPaddingInfo: BCRYPT_PKCS1_PADDING_INFO;
  LStatus: NTSTATUS;
  LAlgId: WideString;
begin
  Result := False;
  FLastError := '';

  if not FPublicKeyLoaded then
  begin
    FLastError := 'Public key not loaded';
    Exit;
  end;

  if Length(ASignature) = 0 then
  begin
    FLastError := 'Empty signature';
    Exit;
  end;

  LAlgHandle := 0;
  LKeyHandle := 0;
  LHashAlgHandle := 0;

  try
    // Open RSA algorithm provider
    LStatus := BCryptOpenAlgorithmProvider(LAlgHandle, BCRYPT_RSA_ALGORITHM, nil, 0);
    if LStatus <> STATUS_SUCCESS then
    begin
      FLastError := Format('BCryptOpenAlgorithmProvider (RSA) failed: $%x', [LStatus]);
      Exit;
    end;

    // Import the public key
    LStatus := BCryptImportKeyPair(LAlgHandle, 0, BCRYPT_RSAPUBLIC_BLOB, LKeyHandle,
      @FPublicKey[0], Length(FPublicKey), 0);
    if LStatus <> STATUS_SUCCESS then
    begin
      FLastError := Format('BCryptImportKeyPair failed: $%x', [LStatus]);
      Exit;
    end;

    // Hash the data with SHA256
    LStatus := BCryptOpenAlgorithmProvider(LHashAlgHandle, BCRYPT_SHA256_ALGORITHM, nil, 0);
    if LStatus <> STATUS_SUCCESS then
    begin
      FLastError := Format('BCryptOpenAlgorithmProvider (SHA256) failed: $%x', [LStatus]);
      Exit;
    end;

    SetLength(LHash, 32); // SHA256 = 32 bytes
    if Length(AData) > 0 then
      LStatus := BCryptHash(LHashAlgHandle, nil, 0, @AData[0], Length(AData), @LHash[0], 32)
    else
      LStatus := BCryptHash(LHashAlgHandle, nil, 0, nil, 0, @LHash[0], 32);

    if LStatus <> STATUS_SUCCESS then
    begin
      FLastError := Format('BCryptHash failed: $%x', [LStatus]);
      Exit;
    end;

    // Setup padding info for PKCS#1 v1.5
    LAlgId := BCRYPT_SHA256_ALGORITHM;
    LPaddingInfo.pszAlgId := PWideChar(LAlgId);

    // Verify signature
    LStatus := BCryptVerifySignature(LKeyHandle, @LPaddingInfo,
      @LHash[0], Length(LHash), @ASignature[0], Length(ASignature), BCRYPT_PAD_PKCS1);

    Result := (LStatus = STATUS_SUCCESS);
    if not Result then
      FLastError := Format('Signature verification failed: $%x', [LStatus]);
  finally
    if LHashAlgHandle <> 0 then
      BCryptCloseAlgorithmProvider(LHashAlgHandle, 0);
    if LKeyHandle <> 0 then
      BCryptDestroyKey(LKeyHandle);
    if LAlgHandle <> 0 then
      BCryptCloseAlgorithmProvider(LAlgHandle, 0);
  end;
end;

function TRSAVerifier.VerifySignature(const AData: TBytes; const ASignatureBase64: string): Boolean;
var
  LSignature: TBytes;
begin
  try
    LSignature := TEncodingUtils.Base64Decode(ASignatureBase64);
    Result := VerifySignature(AData, LSignature);
  except
    on E: Exception do
    begin
      FLastError := 'Invalid Base64 signature: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TRSAVerifier.VerifySignature(const AData, ASignatureBase64: string): Boolean;
begin
  Result := VerifySignature(TEncoding.UTF8.GetBytes(AData), ASignatureBase64);
end;

{ TRSASigner }

destructor TRSASigner.Destroy;
begin
  if Length(FPrivateKeyBlob) > 0 then
  begin
    FillChar(FPrivateKeyBlob[0], Length(FPrivateKeyBlob), 0);
    FPrivateKeyBlob := nil;
  end;
  inherited Destroy;
end;

constructor TRSASigner.Create;
begin
  inherited Create;
  FKeyLoaded := False;
  FLastError := '';
end;

function TRSASigner.ParsePEMPrivateKey(const APEM: string): TBytes;
var
  LLines: TArray<string>;
  LBase64: string;
  LLine: string;
  LInKey: Boolean;
begin
  Result := nil;
  LBase64 := '';
  LInKey := False;
  LLines := APEM.Split([#10, #13], TStringSplitOptions.ExcludeEmpty);
  for LLine in LLines do
  begin
    // 仅支持 PKCS#1 私钥容器（BEGIN RSA PRIVATE KEY）。
    // PKCS#8（BEGIN PRIVATE KEY，如 openssl genpkey / .NET ExportPkcs8PrivateKey）
    // 的 DER 布局（OneAsymmetricKey: algorithm SEQUENCE + OCTET STRING）与下方
    // RSAPrivateKey 解析不兼容，会误当 n/e 字段解出错误结果——此处显式拒绝，
    // 避免误导性报错。
    if LLine.Contains('-----BEGIN PRIVATE KEY-----') and
       not LLine.Contains('RSA PRIVATE KEY') then
    begin
      FLastError := 'Unsupported key container: PKCS#8 (BEGIN PRIVATE KEY). '
        + 'Convert to PKCS#1 (BEGIN RSA PRIVATE KEY) first, e.g. '
        + 'openssl rsa -in key.pem -out pkcs1.pem';
      Exit;
    end;
    if LLine.Contains('-----BEGIN') and
       (LLine.Contains('PRIVATE KEY') or LLine.Contains('RSA PRIVATE KEY')) then
    begin
      LInKey := True;
      Continue;
    end;
    if LLine.Contains('-----END') then
      Break;
    if LInKey then
      LBase64 := LBase64 + LLine.Trim;
  end;
  if LBase64 = '' then
  begin
    FLastError := 'Invalid PEM: no private key found';
    Exit;
  end;
  try
    Result := TEncodingUtils.Base64Decode(LBase64);
  except
    on E: Exception do
    begin
      FLastError := 'Base64 decode failed: ' + E.Message;
      Result := nil;
    end;
  end;
end;

function TRSASigner.LoadPrivateKeyPEM(const APEM: string): Boolean;
var
  LDER: TBytes;
  LAlgHandle: BCRYPT_ALG_HANDLE;
  LKeyHandle: BCRYPT_KEY_HANDLE;
  LImportBlob: TBytes;
  LStatus: NTSTATUS;
  LPos, LSeqLen: Integer;
  LModulus, LExponent, LPrivateExponent: TBytes;
  LPrime1, LPrime2, LExponent1, LExponent2, LCoefficient: TBytes;
  LKeyBlob: PBCRYPT_RSAKEY_BLOB;

  function ReadASN1Length(const ABuf: TBytes; var APos: Integer): Integer;
  var
    B: Byte;
    I, N: Integer;
  begin
    if APos >= Length(ABuf) then
      raise ECryptoException.Create('Invalid DER: unexpected end in length');
    B := ABuf[APos]; Inc(APos);
    if B < $80 then
      Exit(B);
    N := B and $7F;
    Result := 0;
    for I := 1 to N do
    begin
      if APos >= Length(ABuf) then
        raise ECryptoException.Create('Invalid DER: unexpected end in length bytes');
      Result := (Result shl 8) or ABuf[APos]; Inc(APos);
    end;
  end;

  function ReadASN1Integer(const ABuf: TBytes; var APos: Integer): TBytes;
  var
    LLen: Integer;
    LStart: Integer;
  begin
    if APos >= Length(ABuf) then begin Result := nil; Exit; end;
    if ABuf[APos] <> $02 then begin Result := nil; Exit; end;
    Inc(APos);
    LLen := ReadASN1Length(ABuf, APos);
    if APos + LLen > Length(ABuf) then begin Result := nil; Exit; end;
    if (ABuf[APos] = 0) and (LLen > 1) then
    begin
      Inc(APos); Dec(LLen);
    end;
    LStart := APos;
    Inc(APos, LLen);
    Result := Copy(ABuf, LStart, LLen);
  end;
begin
  FLastError := '';
  FKeyLoaded := False;
  FPrivateKeyBlob := nil;

  LDER := ParsePEMPrivateKey(APEM);
  if LDER = nil then
    Exit(False);

  try
    // PKCS#1 RSAPrivateKey DER: SEQUENCE { version, n, e, d, p, q, dp, dq, qInv }
    LPos := 0;
    if LDER[LPos] <> $30 then begin FLastError := 'Not a SEQUENCE'; Exit(False); end;
    Inc(LPos);
    LSeqLen := ReadASN1Length(LDER, LPos);
    ReadASN1Integer(LDER, LPos);  // version
    LModulus := ReadASN1Integer(LDER, LPos);          // n
    LExponent := ReadASN1Integer(LDER, LPos);          // e
    LPrivateExponent := ReadASN1Integer(LDER, LPos);   // d
    LPrime1 := ReadASN1Integer(LDER, LPos);            // p
    LPrime2 := ReadASN1Integer(LDER, LPos);            // q
    LExponent1 := ReadASN1Integer(LDER, LPos);         // dp
    LExponent2 := ReadASN1Integer(LDER, LPos);         // dq
    LCoefficient := ReadASN1Integer(LDER, LPos);        // qInv

    if (LModulus = nil) or (LExponent = nil) or (LPrivateExponent = nil) or
       (LPrime1 = nil) or (LPrime2 = nil) then
    begin
      FLastError := 'Failed to parse RSA private key fields (need full PKCS#1 with primes)';
      Exit(False);
    end;

    // BCRYPT_RSAFULLPRIVATE_BLOB layout:
    //   header | exp | mod | prime1 | prime2 | exp1 | exp2 | coeff | privateExp
    SetLength(LImportBlob, SizeOf(BCRYPT_RSAKEY_BLOB) +
      Length(LExponent) + Length(LModulus) +
      Length(LPrime1) + Length(LPrime2) +
      Length(LExponent1) + Length(LExponent2) +
      Length(LCoefficient) + Length(LPrivateExponent));

    LKeyBlob := @LImportBlob[0];
    LKeyBlob.Magic := BCRYPT_RSAFULLPRIVATE_MAGIC;
    LKeyBlob.BitLength := Length(LModulus) * 8;
    LKeyBlob.cbPublicExp := Length(LExponent);
    LKeyBlob.cbModulus := Length(LModulus);
    LKeyBlob.cbPrime1 := Length(LPrime1);
    LKeyBlob.cbPrime2 := Length(LPrime2);

    LPos := SizeOf(BCRYPT_RSAKEY_BLOB);
    Move(LExponent[0], LImportBlob[LPos], Length(LExponent)); Inc(LPos, Length(LExponent));
    Move(LModulus[0], LImportBlob[LPos], Length(LModulus)); Inc(LPos, Length(LModulus));
    Move(LPrime1[0], LImportBlob[LPos], Length(LPrime1)); Inc(LPos, Length(LPrime1));
    Move(LPrime2[0], LImportBlob[LPos], Length(LPrime2)); Inc(LPos, Length(LPrime2));
    Move(LExponent1[0], LImportBlob[LPos], Length(LExponent1)); Inc(LPos, Length(LExponent1));
    Move(LExponent2[0], LImportBlob[LPos], Length(LExponent2)); Inc(LPos, Length(LExponent2));
    Move(LCoefficient[0], LImportBlob[LPos], Length(LCoefficient)); Inc(LPos, Length(LCoefficient));
    Move(LPrivateExponent[0], LImportBlob[LPos], Length(LPrivateExponent));

    LAlgHandle := 0;
    LKeyHandle := 0;
    try
      LStatus := BCryptOpenAlgorithmProvider(LAlgHandle, BCRYPT_RSA_ALGORITHM, nil, 0);
      if LStatus <> STATUS_SUCCESS then
      begin
        FLastError := Format('BCryptOpenAlgorithmProvider failed: $%x', [LStatus]);
        Exit(False);
      end;
      LStatus := BCryptImportKeyPair(LAlgHandle, 0, BCRYPT_RSAFULLPRIVATE_BLOB,
        LKeyHandle, @LImportBlob[0], Length(LImportBlob), 0);
      if LStatus <> STATUS_SUCCESS then
      begin
        FLastError := Format('BCryptImportKeyPair failed: $%x', [LStatus]);
        Exit(False);
      end;
      FKeyLoaded := True;
      FPrivateKeyBlob := Copy(LImportBlob);
      Result := True;
    finally
      if LKeyHandle <> 0 then BCryptDestroyKey(LKeyHandle);
      if LAlgHandle <> 0 then BCryptCloseAlgorithmProvider(LAlgHandle, 0);
    end;
  finally
    // Zeroize all RSA private-key material that lived on the stack/heap during
    // parsing and blob construction, so a memory dump cannot recover the
    // private exponent or CRT primes (CORE-R3-005 fix). FPrivateKeyBlob is
    // kept (it is required for signing) and zeroed separately on unload.
    if Length(LPrivateExponent) > 0 then FillChar(LPrivateExponent[0], Length(LPrivateExponent), 0);
    if Length(LPrime1) > 0        then FillChar(LPrime1[0], Length(LPrime1), 0);
    if Length(LPrime2) > 0        then FillChar(LPrime2[0], Length(LPrime2), 0);
    if Length(LExponent1) > 0     then FillChar(LExponent1[0], Length(LExponent1), 0);
    if Length(LExponent2) > 0     then FillChar(LExponent2[0], Length(LExponent2), 0);
    if Length(LCoefficient) > 0   then FillChar(LCoefficient[0], Length(LCoefficient), 0);
    if Length(LModulus) > 0       then FillChar(LModulus[0], Length(LModulus), 0);
    if Length(LExponent) > 0      then FillChar(LExponent[0], Length(LExponent), 0);
    if Length(LImportBlob) > 0    then FillChar(LImportBlob[0], Length(LImportBlob), 0);
    if Length(LDER) > 0           then FillChar(LDER[0], Length(LDER), 0);
  end;
end;

function TRSASigner.Sign(const AData: TBytes): TBytes;
var
  LAlgHandle, LHashAlgHandle: BCRYPT_ALG_HANDLE;
  LKeyHandle: BCRYPT_KEY_HANDLE;
  LHash: TBytes;
  LPaddingInfo: BCRYPT_PKCS1_PADDING_INFO;
  LStatus: NTSTATUS;
  LAlgId: WideString;
  LSigLen: ULONG;
begin
  Result := nil;
  if not FKeyLoaded then
  begin
    FLastError := 'Private key not loaded';
    Exit;
  end;

  LAlgHandle := 0;
  LHashAlgHandle := 0;
  LKeyHandle := 0;
  try
    LStatus := BCryptOpenAlgorithmProvider(LAlgHandle, BCRYPT_RSA_ALGORITHM, nil, 0);
    if LStatus <> STATUS_SUCCESS then begin
      FLastError := Format('BCryptOpenAlgorithmProvider(RSA) failed: $%x', [LStatus]);
      Exit;
    end;

    LStatus := BCryptImportKeyPair(LAlgHandle, 0, BCRYPT_RSAFULLPRIVATE_BLOB,
      LKeyHandle, @FPrivateKeyBlob[0], Length(FPrivateKeyBlob), 0);
    if LStatus <> STATUS_SUCCESS then begin
      FLastError := Format('BCryptImportKeyPair failed: $%x', [LStatus]);
      Exit;
    end;

    LStatus := BCryptOpenAlgorithmProvider(LHashAlgHandle, BCRYPT_SHA256_ALGORITHM, nil, 0);
    if LStatus <> STATUS_SUCCESS then begin
      FLastError := Format('BCryptOpenAlgorithmProvider(SHA256) failed: $%x', [LStatus]);
      Exit;
    end;

    SetLength(LHash, 32);
    if Length(AData) > 0 then
      LStatus := BCryptHash(LHashAlgHandle, nil, 0, @AData[0], Length(AData), @LHash[0], 32)
    else
      LStatus := BCryptHash(LHashAlgHandle, nil, 0, nil, 0, @LHash[0], 32);
    if LStatus <> STATUS_SUCCESS then begin
      FLastError := Format('BCryptHash failed: $%x', [LStatus]);
      Exit;
    end;

    LAlgId := BCRYPT_SHA256_ALGORITHM;
    LPaddingInfo.pszAlgId := PWideChar(LAlgId);

    LStatus := BCryptSignHash(LKeyHandle, @LPaddingInfo,
      @LHash[0], 32, nil, 0, LSigLen, BCRYPT_PAD_PKCS1);
    if LStatus <> STATUS_SUCCESS then begin
      FLastError := Format('BCryptSignHash(size query) failed: $%x', [LStatus]);
      Exit;
    end;

    SetLength(Result, LSigLen);
    LStatus := BCryptSignHash(LKeyHandle, @LPaddingInfo,
      @LHash[0], 32, @Result[0], LSigLen, LSigLen, BCRYPT_PAD_PKCS1);
    if LStatus <> STATUS_SUCCESS then begin
      FLastError := Format('BCryptSignHash failed: $%x', [LStatus]);
      Result := nil;
    end;
  finally
    if LKeyHandle <> 0 then BCryptDestroyKey(LKeyHandle);
    if LHashAlgHandle <> 0 then BCryptCloseAlgorithmProvider(LHashAlgHandle, 0);
    if LAlgHandle <> 0 then BCryptCloseAlgorithmProvider(LAlgHandle, 0);
  end;
end;

function TRSASigner.Sign(const AData: string): string;
var
  LSignature: TBytes;
begin
  LSignature := Sign(TEncoding.UTF8.GetBytes(AData));
  if LSignature <> nil then
    Result := TEncodingUtils.Base64Encode(LSignature)
  else
    Result := '';
end;
{$ENDIF}

end.
