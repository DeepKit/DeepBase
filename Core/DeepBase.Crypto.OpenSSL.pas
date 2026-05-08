{ ============================================================================
  DeepBase.Crypto.OpenSSL - OpenSSL libcrypto Backend for Cross-Platform Encryption

  Version: 1.0
  Description: Provides AES-256-GCM encryption and PBKDF2 key derivation using
               OpenSSL libcrypto. Dynamically loads the library at runtime.
               Used by DeepBase.Security on macOS and Linux platforms.

  Requirements:
    - libcrypto must be shipped with the application bundle
    - macOS: place libcrypto.3.dylib in app bundle's Frameworks folder or
             set DeepBase_LIBCRYPTO_PATH environment variable
    - Linux: place libcrypto.so.3 alongside executable or in LD_LIBRARY_PATH

  Thread Safety: All functions are thread-safe after initialization.
  ============================================================================ }

unit DeepBase.Crypto.OpenSSL;

interface

{$IF DEFINED(MACOS) OR DEFINED(LINUX)}

uses
  System.SysUtils,
  System.Classes;

type
  EOpenSSLError = class(Exception);
  EOpenSSLNotLoaded = class(EOpenSSLError);

  /// <summary>
  /// Initialize OpenSSL library. Call once at startup.
  /// Raises EOpenSSLNotLoaded if library cannot be found.
  /// </summary>
  procedure OpenSSL_Init;

  /// <summary>
  /// Check if OpenSSL is loaded and ready.
  /// </summary>
  function OpenSSL_IsLoaded: Boolean;

  /// <summary>
  /// Get OpenSSL version string.
  /// </summary>
  function OpenSSL_Version: string;

  /// <summary>
  /// Generate cryptographically secure random bytes.
  /// </summary>
  function OpenSSL_RandomBytes(ACount: Integer): TBytes;

  /// <summary>
  /// PBKDF2-HMAC-SHA256 key derivation.
  /// </summary>
  function OpenSSL_PBKDF2_SHA256(const APassword, ASalt: TBytes;
    AIterations, AKeyLen: Integer): TBytes;

  /// <summary>
  /// AES-256-GCM encryption.
  /// Returns ciphertext. ATag receives the 16-byte authentication tag.
  /// </summary>
  function OpenSSL_AES256GCM_Encrypt(const AKey, AIV, APlaintext: TBytes;
    const AAAD: TBytes; out ATag: TBytes): TBytes;

  /// <summary>
  /// AES-256-GCM decryption.
  /// Verifies the authentication tag. Raises EOpenSSLError if tag mismatch.
  /// </summary>
  function OpenSSL_AES256GCM_Decrypt(const AKey, AIV, ACiphertext: TBytes;
    const AAAD, ATag: TBytes): TBytes;

  /// <summary>
  /// AES-256-CBC encryption. Returns ciphertext (no padding â€?caller must pre-pad).
  /// </summary>
  function OpenSSL_AES256CBC_Encrypt(const AKey, AIV, APlaintext: TBytes): TBytes;

  /// <summary>
  /// AES-256-CBC decryption. Returns plaintext (no unpadding â€?caller must post-unpad).
  /// </summary>
  function OpenSSL_AES256CBC_Decrypt(const AKey, AIV, ACiphertext: TBytes): TBytes;

  /// <summary>
  /// RSA-SHA256 signature verification using PEM public key.
  /// ASignatureBase64 is the Base64-encoded signature.
  /// Returns True if the signature is valid.
  /// </summary>
  function OpenSSL_RSAVerifySHA256(const APEMPublicKey: string;
    const AData: TBytes; const ASignatureBase64: string;
    out AError: string): Boolean;

{$ENDIF}

implementation

{$IF DEFINED(MACOS) OR DEFINED(LINUX)}

uses
  {$IFDEF MACOS}
  Macapi.Helpers,
  {$ENDIF}
  System.IOUtils,
  System.SyncObjs,
  System.NetEncoding;

const
  // OpenSSL library names
  {$IFDEF MACOS}
  LIBCRYPTO_NAMES: array[0..2] of string = (
    'libcrypto.3.dylib',
    'libcrypto.1.1.dylib',
    'libcrypto.dylib'
  );
  {$ENDIF}
  {$IFDEF LINUX}
  LIBCRYPTO_NAMES: array[0..2] of string = (
    'libcrypto.so.3',
    'libcrypto.so.1.1',
    'libcrypto.so'
  );
  {$ENDIF}

  // GCM constants
  GCM_TAG_SIZE = 16;
  GCM_IV_SIZE = 12;
  AES_KEY_SIZE = 32; // AES-256
  AES_BLOCK_SIZE = 16;

type
  // OpenSSL opaque types
  PEVP_CIPHER_CTX = Pointer;
  PEVP_CIPHER = Pointer;
  PEVP_MD = Pointer;

  // OpenSSL function types
  TRAND_bytes = function(buf: PByte; num: Integer): Integer; cdecl;
  TEVP_CIPHER_CTX_new = function: PEVP_CIPHER_CTX; cdecl;
  TEVP_CIPHER_CTX_free = procedure(ctx: PEVP_CIPHER_CTX); cdecl;
  TEVP_aes_256_gcm = function: PEVP_CIPHER; cdecl;
  TEVP_aes_256_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_EncryptInit_ex = function(ctx: PEVP_CIPHER_CTX; cipher: PEVP_CIPHER;
    impl: Pointer; key, iv: PByte): Integer; cdecl;
  TEVP_DecryptInit_ex = function(ctx: PEVP_CIPHER_CTX; cipher: PEVP_CIPHER;
    impl: Pointer; key, iv: PByte): Integer; cdecl;
  TEVP_EncryptUpdate = function(ctx: PEVP_CIPHER_CTX; outbuf: PByte;
    var outlen: Integer; inbuf: PByte; inlen: Integer): Integer; cdecl;
  TEVP_DecryptUpdate = function(ctx: PEVP_CIPHER_CTX; outbuf: PByte;
    var outlen: Integer; inbuf: PByte; inlen: Integer): Integer; cdecl;
  TEVP_EncryptFinal_ex = function(ctx: PEVP_CIPHER_CTX; outbuf: PByte;
    var outlen: Integer): Integer; cdecl;
  TEVP_DecryptFinal_ex = function(ctx: PEVP_CIPHER_CTX; outbuf: PByte;
    var outlen: Integer): Integer; cdecl;
  TEVP_CIPHER_CTX_ctrl = function(ctx: PEVP_CIPHER_CTX; ctype, arg: Integer;
    ptr: Pointer): Integer; cdecl;
  TEVP_sha256 = function: PEVP_MD; cdecl;
  TPKCS5_PBKDF2_HMAC = function(pass: PAnsiChar; passlen: Integer;
    salt: PByte; saltlen, iter, digest_len: Integer; digest: PEVP_MD;
    keylen: Integer; outkey: PByte): Integer; cdecl;
  TOpenSSL_version = function(t: Integer): PAnsiChar; cdecl;

  // RSA verification types
  PBIO = Pointer;
  PEVP_PKEY = Pointer;
  PEVP_MD_CTX = Pointer;

  TBIO_new_mem_buf = function(buf: Pointer; len: Integer): PBIO; cdecl;
  TBIO_free = function(a: PBIO): Integer; cdecl;
  TPEM_read_bio_PUBKEY = function(bp: PBIO; x: Pointer; cb: Pointer; u: Pointer): PEVP_PKEY; cdecl;
  TEVP_PKEY_free = procedure(pkey: PEVP_PKEY); cdecl;
  TEVP_MD_CTX_new = function: PEVP_MD_CTX; cdecl;
  TEVP_MD_CTX_free = procedure(ctx: PEVP_MD_CTX); cdecl;
  TEVP_DigestVerifyInit = function(ctx: PEVP_MD_CTX; pctx: Pointer;
    const dtype: PEVP_MD; e: Pointer; pkey: PEVP_PKEY): Integer; cdecl;
  TEVP_DigestVerifyUpdate = function(ctx: PEVP_MD_CTX; data: PByte;
    datalen: NativeUInt): Integer; cdecl;
  TEVP_DigestVerifyFinal = function(ctx: PEVP_MD_CTX; const sigret: PByte;
    siglen: NativeUInt): Integer; cdecl;

var
  GLibHandle: NativeUInt = 0;
  GInitLock: TCriticalSection = nil;
  GIsLoaded: Boolean = False;

  // Function pointers
  _RAND_bytes: TRAND_bytes = nil;
  _EVP_CIPHER_CTX_new: TEVP_CIPHER_CTX_new = nil;
  _EVP_CIPHER_CTX_free: TEVP_CIPHER_CTX_free = nil;
  _EVP_aes_256_gcm: TEVP_aes_256_gcm = nil;
  _EVP_aes_256_cbc: TEVP_aes_256_cbc = nil;
  _EVP_EncryptInit_ex: TEVP_EncryptInit_ex = nil;
  _EVP_DecryptInit_ex: TEVP_DecryptInit_ex = nil;
  _EVP_EncryptUpdate: TEVP_EncryptUpdate = nil;
  _EVP_DecryptUpdate: TEVP_DecryptUpdate = nil;
  _EVP_EncryptFinal_ex: TEVP_EncryptFinal_ex = nil;
  _EVP_DecryptFinal_ex: TEVP_DecryptFinal_ex = nil;
  _EVP_CIPHER_CTX_ctrl: TEVP_CIPHER_CTX_ctrl = nil;
  _EVP_sha256: TEVP_sha256 = nil;
  _PKCS5_PBKDF2_HMAC: TPKCS5_PBKDF2_HMAC = nil;
  _OpenSSL_version: TOpenSSL_version = nil;

  // RSA verification function pointers
  _BIO_new_mem_buf: TBIO_new_mem_buf = nil;
  _BIO_free: TBIO_free = nil;
  _PEM_read_bio_PUBKEY: TPEM_read_bio_PUBKEY = nil;
  _EVP_PKEY_free: TEVP_PKEY_free = nil;
  _EVP_MD_CTX_new: TEVP_MD_CTX_new = nil;
  _EVP_MD_CTX_free: TEVP_MD_CTX_free = nil;
  _EVP_DigestVerifyInit: TEVP_DigestVerifyInit = nil;
  _EVP_DigestVerifyUpdate: TEVP_DigestVerifyUpdate = nil;
  _EVP_DigestVerifyFinal: TEVP_DigestVerifyFinal = nil;

const
  EVP_CTRL_GCM_SET_IVLEN = $9;
  EVP_CTRL_GCM_GET_TAG = $10;
  EVP_CTRL_GCM_SET_TAG = $11;
  OPENSSL_VERSION_NUM = 0;

function LoadLib(const APath: string): NativeUInt;
begin
  {$IFDEF MACOS}
  Result := NativeUInt(dlopen(MarshaledAString(UTF8String(APath)), RTLD_NOW));
  {$ENDIF}
  {$IFDEF LINUX}
  Result := NativeUInt(dlopen(PAnsiChar(AnsiString(APath)), RTLD_NOW));
  {$ENDIF}
end;

function GetProc(ALib: NativeUInt; const AName: string): Pointer;
begin
  {$IFDEF MACOS}
  Result := dlsym(Pointer(ALib), MarshaledAString(UTF8String(AName)));
  {$ENDIF}
  {$IFDEF LINUX}
  Result := dlsym(Pointer(ALib), PAnsiChar(AnsiString(AName)));
  {$ENDIF}
end;

procedure FreeLib(ALib: NativeUInt);
begin
  if ALib <> 0 then
    dlclose(Pointer(ALib));
end;

function TryLoadLibrary: Boolean;
var
  SearchPaths: TArray<string>;
  LibName, FullPath, EnvPath: string;
  I, J: Integer;
begin
  Result := False;
  
  // Build search paths
  EnvPath := GetEnvironmentVariable('DeepBase_LIBCRYPTO_PATH');
  if EnvPath <> '' then
    SearchPaths := [EnvPath]
  else
  begin
    // App bundle paths
    {$IFDEF MACOS}
    SearchPaths := [
      TPath.GetDirectoryName(ParamStr(0)) + '/../Frameworks/',
      TPath.GetDirectoryName(ParamStr(0)) + '/',
      '/opt/homebrew/opt/openssl@3/lib/',
      '/usr/local/opt/openssl@3/lib/',
      '/usr/lib/'
    ];
    {$ENDIF}
    {$IFDEF LINUX}
    SearchPaths := [
      TPath.GetDirectoryName(ParamStr(0)) + '/',
      '/usr/lib/x86_64-linux-gnu/',
      '/usr/lib64/',
      '/usr/lib/',
      '/lib/x86_64-linux-gnu/',
      '/lib64/',
      '/lib/'
    ];
    {$ENDIF}
  end;
  
  // Try each path and library name combination
  for I := 0 to Length(SearchPaths) - 1 do
  begin
    for J := 0 to Length(LIBCRYPTO_NAMES) - 1 do
    begin
      LibName := LIBCRYPTO_NAMES[J];
      FullPath := SearchPaths[I] + LibName;
      
      if FileExists(FullPath) then
      begin
        GLibHandle := LoadLib(FullPath);
        if GLibHandle <> 0 then
        begin
          Result := True;
          Exit;
        end;
      end;
    end;
  end;
  
  // Try system library path without prefix
  for J := 0 to Length(LIBCRYPTO_NAMES) - 1 do
  begin
    GLibHandle := LoadLib(LIBCRYPTO_NAMES[J]);
    if GLibHandle <> 0 then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function LoadSymbols: Boolean;
begin
  Result := False;
  if GLibHandle = 0 then
    Exit;
    
  @_RAND_bytes := GetProc(GLibHandle, 'RAND_bytes');
  @_EVP_CIPHER_CTX_new := GetProc(GLibHandle, 'EVP_CIPHER_CTX_new');
  @_EVP_CIPHER_CTX_free := GetProc(GLibHandle, 'EVP_CIPHER_CTX_free');
  @_EVP_aes_256_gcm := GetProc(GLibHandle, 'EVP_aes_256_gcm');
  @_EVP_aes_256_cbc := GetProc(GLibHandle, 'EVP_aes_256_cbc');
  @_EVP_EncryptInit_ex := GetProc(GLibHandle, 'EVP_EncryptInit_ex');
  @_EVP_DecryptInit_ex := GetProc(GLibHandle, 'EVP_DecryptInit_ex');
  @_EVP_EncryptUpdate := GetProc(GLibHandle, 'EVP_EncryptUpdate');
  @_EVP_DecryptUpdate := GetProc(GLibHandle, 'EVP_DecryptUpdate');
  @_EVP_EncryptFinal_ex := GetProc(GLibHandle, 'EVP_EncryptFinal_ex');
  @_EVP_DecryptFinal_ex := GetProc(GLibHandle, 'EVP_DecryptFinal_ex');
  @_EVP_CIPHER_CTX_ctrl := GetProc(GLibHandle, 'EVP_CIPHER_CTX_ctrl');
  @_EVP_sha256 := GetProc(GLibHandle, 'EVP_sha256');
  @_PKCS5_PBKDF2_HMAC := GetProc(GLibHandle, 'PKCS5_PBKDF2_HMAC');
  @_OpenSSL_version := GetProc(GLibHandle, 'OpenSSL_version');

  // RSA verification symbols
  @_BIO_new_mem_buf := GetProc(GLibHandle, 'BIO_new_mem_buf');
  @_BIO_free := GetProc(GLibHandle, 'BIO_free');
  @_PEM_read_bio_PUBKEY := GetProc(GLibHandle, 'PEM_read_bio_PUBKEY');
  @_EVP_PKEY_free := GetProc(GLibHandle, 'EVP_PKEY_free');
  @_EVP_MD_CTX_new := GetProc(GLibHandle, 'EVP_MD_CTX_new');
  @_EVP_MD_CTX_free := GetProc(GLibHandle, 'EVP_MD_CTX_free');
  @_EVP_DigestVerifyInit := GetProc(GLibHandle, 'EVP_DigestVerifyInit');
  @_EVP_DigestVerifyUpdate := GetProc(GLibHandle, 'EVP_DigestVerifyUpdate');
  @_EVP_DigestVerifyFinal := GetProc(GLibHandle, 'EVP_DigestVerifyFinal');
  
  // Check required symbols
  Result := Assigned(_RAND_bytes) and
            Assigned(_EVP_CIPHER_CTX_new) and
            Assigned(_EVP_CIPHER_CTX_free) and
            Assigned(_EVP_aes_256_gcm) and
            Assigned(_EVP_EncryptInit_ex) and
            Assigned(_EVP_DecryptInit_ex) and
            Assigned(_EVP_EncryptUpdate) and
            Assigned(_EVP_DecryptUpdate) and
            Assigned(_EVP_EncryptFinal_ex) and
            Assigned(_EVP_DecryptFinal_ex) and
            Assigned(_EVP_CIPHER_CTX_ctrl) and
            Assigned(_EVP_sha256) and
            Assigned(_PKCS5_PBKDF2_HMAC);
end;

procedure OpenSSL_Init;
begin
  if GIsLoaded then
    Exit;
    
  GInitLock.Enter;
  try
    if GIsLoaded then
      Exit;
      
    if not TryLoadLibrary then
      raise EOpenSSLNotLoaded.Create(
        'OpenSSL libcrypto not found. Please ensure libcrypto is included in ' +
        'the application bundle. ' +
        {$IFDEF MACOS}
        'On macOS, place libcrypto.3.dylib in the Frameworks folder or set ' +
        'DeepBase_LIBCRYPTO_PATH environment variable.'
        {$ELSE}
        'On Linux, place libcrypto.so.3 alongside the executable or set ' +
        'DeepBase_LIBCRYPTO_PATH environment variable.'
        {$ENDIF}
      );
      
    if not LoadSymbols then
    begin
      FreeLib(GLibHandle);
      GLibHandle := 0;
      raise EOpenSSLNotLoaded.Create(
        'OpenSSL library loaded but required symbols not found. ' +
        'Please ensure you are using OpenSSL 1.1.x or 3.x.'
      );
    end;
    
    GIsLoaded := True;
  finally
    GInitLock.Leave;
  end;
end;

function OpenSSL_IsLoaded: Boolean;
begin
  Result := GIsLoaded;
end;

function OpenSSL_Version: string;
begin
  if not GIsLoaded then
    OpenSSL_Init;
    
  if Assigned(_OpenSSL_version) then
    Result := string(AnsiString(_OpenSSL_version(OPENSSL_VERSION_NUM)))
  else
    Result := 'Unknown';
end;

function OpenSSL_RandomBytes(ACount: Integer): TBytes;
begin
  if not GIsLoaded then
    OpenSSL_Init;
    
  SetLength(Result, ACount);
  if ACount > 0 then
  begin
    if _RAND_bytes(@Result[0], ACount) <> 1 then
      raise EOpenSSLError.Create('RAND_bytes failed');
  end;
end;

function OpenSSL_PBKDF2_SHA256(const APassword, ASalt: TBytes;
  AIterations, AKeyLen: Integer): TBytes;
var
  PassPtr: PAnsiChar;
  SaltPtr: PByte;
begin
  if not GIsLoaded then
    OpenSSL_Init;
    
  SetLength(Result, AKeyLen);
  
  if Length(APassword) > 0 then
    PassPtr := @APassword[0]
  else
    PassPtr := nil;
    
  if Length(ASalt) > 0 then
    SaltPtr := @ASalt[0]
  else
    SaltPtr := nil;
  
  if _PKCS5_PBKDF2_HMAC(
       PassPtr, Length(APassword),
       SaltPtr, Length(ASalt),
       AIterations, AKeyLen,
       _EVP_sha256(),
       AKeyLen, @Result[0]) <> 1 then
    raise EOpenSSLError.Create('PKCS5_PBKDF2_HMAC failed');
end;

function OpenSSL_AES256GCM_Encrypt(const AKey, AIV, APlaintext: TBytes;
  const AAAD: TBytes; out ATag: TBytes): TBytes;
var
  Ctx: PEVP_CIPHER_CTX;
  OutLen, FinalLen: Integer;
begin
  if not GIsLoaded then
    OpenSSL_Init;
    
  if Length(AKey) <> AES_KEY_SIZE then
    raise EOpenSSLError.CreateFmt('Invalid key size: expected %d, got %d',
      [AES_KEY_SIZE, Length(AKey)]);
      
  if Length(AIV) <> GCM_IV_SIZE then
    raise EOpenSSLError.CreateFmt('Invalid IV size: expected %d, got %d',
      [GCM_IV_SIZE, Length(AIV)]);
  
  Ctx := _EVP_CIPHER_CTX_new();
  if Ctx = nil then
    raise EOpenSSLError.Create('EVP_CIPHER_CTX_new failed');
    
  try
    // Initialize encryption
    if _EVP_EncryptInit_ex(Ctx, _EVP_aes_256_gcm(), nil, nil, nil) <> 1 then
      raise EOpenSSLError.Create('EVP_EncryptInit_ex failed (cipher)');
      
    // Set IV length
    if _EVP_CIPHER_CTX_ctrl(Ctx, EVP_CTRL_GCM_SET_IVLEN, GCM_IV_SIZE, nil) <> 1 then
      raise EOpenSSLError.Create('EVP_CIPHER_CTX_ctrl failed (IV len)');
      
    // Set key and IV
    if _EVP_EncryptInit_ex(Ctx, nil, nil, @AKey[0], @AIV[0]) <> 1 then
      raise EOpenSSLError.Create('EVP_EncryptInit_ex failed (key/IV)');
      
    // Process AAD if provided
    if Length(AAAD) > 0 then
    begin
      if _EVP_EncryptUpdate(Ctx, nil, OutLen, @AAAD[0], Length(AAAD)) <> 1 then
        raise EOpenSSLError.Create('EVP_EncryptUpdate failed (AAD)');
    end;
    
    // Allocate output buffer
    SetLength(Result, Length(APlaintext) + 16); // Extra space for potential block
    
    // Encrypt plaintext
    if Length(APlaintext) > 0 then
    begin
      if _EVP_EncryptUpdate(Ctx, @Result[0], OutLen, @APlaintext[0], 
           Length(APlaintext)) <> 1 then
        raise EOpenSSLError.Create('EVP_EncryptUpdate failed (plaintext)');
    end
    else
      OutLen := 0;
      
    // Finalize
    if _EVP_EncryptFinal_ex(Ctx, @Result[OutLen], FinalLen) <> 1 then
      raise EOpenSSLError.Create('EVP_EncryptFinal_ex failed');
      
    SetLength(Result, OutLen + FinalLen);
    
    // Get authentication tag
    SetLength(ATag, GCM_TAG_SIZE);
    if _EVP_CIPHER_CTX_ctrl(Ctx, EVP_CTRL_GCM_GET_TAG, GCM_TAG_SIZE, @ATag[0]) <> 1 then
      raise EOpenSSLError.Create('EVP_CIPHER_CTX_ctrl failed (get tag)');
  finally
    _EVP_CIPHER_CTX_free(Ctx);
  end;
end;

function OpenSSL_AES256GCM_Decrypt(const AKey, AIV, ACiphertext: TBytes;
  const AAAD, ATag: TBytes): TBytes;
var
  Ctx: PEVP_CIPHER_CTX;
  OutLen, FinalLen: Integer;
  TagCopy: TBytes;
begin
  if not GIsLoaded then
    OpenSSL_Init;
    
  if Length(AKey) <> AES_KEY_SIZE then
    raise EOpenSSLError.CreateFmt('Invalid key size: expected %d, got %d',
      [AES_KEY_SIZE, Length(AKey)]);
      
  if Length(AIV) <> GCM_IV_SIZE then
    raise EOpenSSLError.CreateFmt('Invalid IV size: expected %d, got %d',
      [GCM_IV_SIZE, Length(AIV)]);
      
  if Length(ATag) <> GCM_TAG_SIZE then
    raise EOpenSSLError.CreateFmt('Invalid tag size: expected %d, got %d',
      [GCM_TAG_SIZE, Length(ATag)]);
  
  Ctx := _EVP_CIPHER_CTX_new();
  if Ctx = nil then
    raise EOpenSSLError.Create('EVP_CIPHER_CTX_new failed');
    
  try
    // Initialize decryption
    if _EVP_DecryptInit_ex(Ctx, _EVP_aes_256_gcm(), nil, nil, nil) <> 1 then
      raise EOpenSSLError.Create('EVP_DecryptInit_ex failed (cipher)');
      
    // Set IV length
    if _EVP_CIPHER_CTX_ctrl(Ctx, EVP_CTRL_GCM_SET_IVLEN, GCM_IV_SIZE, nil) <> 1 then
      raise EOpenSSLError.Create('EVP_CIPHER_CTX_ctrl failed (IV len)');
      
    // Set key and IV
    if _EVP_DecryptInit_ex(Ctx, nil, nil, @AKey[0], @AIV[0]) <> 1 then
      raise EOpenSSLError.Create('EVP_DecryptInit_ex failed (key/IV)');
      
    // Process AAD if provided
    if Length(AAAD) > 0 then
    begin
      if _EVP_DecryptUpdate(Ctx, nil, OutLen, @AAAD[0], Length(AAAD)) <> 1 then
        raise EOpenSSLError.Create('EVP_DecryptUpdate failed (AAD)');
    end;
    
    // Allocate output buffer
    SetLength(Result, Length(ACiphertext) + 16);
    
    // Decrypt ciphertext
    if Length(ACiphertext) > 0 then
    begin
      if _EVP_DecryptUpdate(Ctx, @Result[0], OutLen, @ACiphertext[0], 
           Length(ACiphertext)) <> 1 then
        raise EOpenSSLError.Create('EVP_DecryptUpdate failed (ciphertext)');
    end
    else
      OutLen := 0;
      
    // Set expected tag (make a copy since OpenSSL may modify it)
    TagCopy := Copy(ATag);
    if _EVP_CIPHER_CTX_ctrl(Ctx, EVP_CTRL_GCM_SET_TAG, GCM_TAG_SIZE, @TagCopy[0]) <> 1 then
      raise EOpenSSLError.Create('EVP_CIPHER_CTX_ctrl failed (set tag)');
      
    // Finalize and verify tag
    if _EVP_DecryptFinal_ex(Ctx, @Result[OutLen], FinalLen) <> 1 then
      raise EOpenSSLError.Create('Authentication failed: tag mismatch');
      
    SetLength(Result, OutLen + FinalLen);
  finally
    _EVP_CIPHER_CTX_free(Ctx);
  end;
end;

{$IFDEF POSIX}
function dlopen(filename: MarshaledAString; flag: Integer): Pointer; cdecl;
  external 'libdl.dylib' name 'dlopen';
function dlsym(handle: Pointer; symbol: MarshaledAString): Pointer; cdecl;
  external 'libdl.dylib' name 'dlsym';
function dlclose(handle: Pointer): Integer; cdecl;
  external 'libdl.dylib' name 'dlclose';
{$ENDIF}

function OpenSSL_AES256CBC_Encrypt(const AKey, AIV, APlaintext: TBytes): TBytes;
var
  Ctx: PEVP_CIPHER_CTX;
  OutLen, FinalLen: Integer;
begin
  if not GIsLoaded then
    OpenSSL_Init;

  if Length(AKey) <> AES_KEY_SIZE then
    raise EOpenSSLError.CreateFmt('Invalid key size: expected %d, got %d',
      [AES_KEY_SIZE, Length(AKey)]);
  if Length(AIV) <> AES_BLOCK_SIZE then
    raise EOpenSSLError.CreateFmt('Invalid IV size: expected %d, got %d',
      [AES_BLOCK_SIZE, Length(AIV)]);

  Ctx := _EVP_CIPHER_CTX_new();
  if Ctx = nil then
    raise EOpenSSLError.Create('EVP_CIPHER_CTX_new failed');
  try
    if _EVP_EncryptInit_ex(Ctx, _EVP_aes_256_cbc(), nil, @AKey[0], @AIV[0]) <> 1 then
      raise EOpenSSLError.Create('EVP_EncryptInit_ex (CBC) failed');
    // Disable padding â€?caller provides pre-padded data
    _EVP_CIPHER_CTX_ctrl(Ctx, 1, 0, nil);
    SetLength(Result, Length(APlaintext) + AES_BLOCK_SIZE);
    if _EVP_EncryptUpdate(Ctx, @Result[0], OutLen, @APlaintext[0],
         Length(APlaintext)) <> 1 then
      raise EOpenSSLError.Create('EVP_EncryptUpdate (CBC) failed');
    if _EVP_EncryptFinal_ex(Ctx, @Result[OutLen], FinalLen) <> 1 then
      raise EOpenSSLError.Create('EVP_EncryptFinal_ex (CBC) failed');
    SetLength(Result, OutLen + FinalLen);
  finally
    _EVP_CIPHER_CTX_free(Ctx);
  end;
end;

function OpenSSL_AES256CBC_Decrypt(const AKey, AIV, ACiphertext: TBytes): TBytes;
var
  Ctx: PEVP_CIPHER_CTX;
  OutLen, FinalLen: Integer;
begin
  if not GIsLoaded then
    OpenSSL_Init;

  if Length(AKey) <> AES_KEY_SIZE then
    raise EOpenSSLError.CreateFmt('Invalid key size: expected %d, got %d',
      [AES_KEY_SIZE, Length(AKey)]);
  if Length(AIV) <> AES_BLOCK_SIZE then
    raise EOpenSSLError.CreateFmt('Invalid IV size: expected %d, got %d',
      [AES_BLOCK_SIZE, Length(AIV)]);
  if (Length(ACiphertext) mod AES_BLOCK_SIZE) <> 0 then
    raise EOpenSSLError.Create('Invalid ciphertext length for CBC');

  Ctx := _EVP_CIPHER_CTX_new();
  if Ctx = nil then
    raise EOpenSSLError.Create('EVP_CIPHER_CTX_new failed');
  try
    if _EVP_DecryptInit_ex(Ctx, _EVP_aes_256_cbc(), nil, @AKey[0], @AIV[0]) <> 1 then
      raise EOpenSSLError.Create('EVP_DecryptInit_ex (CBC) failed');
    _EVP_CIPHER_CTX_ctrl(Ctx, 1, 0, nil);
    SetLength(Result, Length(ACiphertext));
    if _EVP_DecryptUpdate(Ctx, @Result[0], OutLen, @ACiphertext[0],
         Length(ACiphertext)) <> 1 then
      raise EOpenSSLError.Create('EVP_DecryptUpdate (CBC) failed');
    if _EVP_DecryptFinal_ex(Ctx, @Result[OutLen], FinalLen) <> 1 then
      raise EOpenSSLError.Create('EVP_DecryptFinal_ex (CBC) failed');
    SetLength(Result, OutLen + FinalLen);
  finally
    _EVP_CIPHER_CTX_free(Ctx);
  end;
end;

function OpenSSL_RSAVerifySHA256(const APEMPublicKey: string;
  const AData: TBytes; const ASignatureBase64: string;
  out AError: string): Boolean;
var
  Bio: PBIO;
  PKey: PEVP_PKEY;
  MDCtx: PEVP_MD_CTX;
  SigBytes, PemBytes: TBytes;
begin
  Result := False;
  AError := '';
  PKey := nil;
  Bio := nil;
  MDCtx := nil;

  if not GIsLoaded then
    OpenSSL_Init;

  if not Assigned(_BIO_new_mem_buf) or not Assigned(_PEM_read_bio_PUBKEY) or
     not Assigned(_EVP_PKEY_free) or not Assigned(_EVP_MD_CTX_new) or
     not Assigned(_EVP_MD_CTX_free) or not Assigned(_EVP_DigestVerifyInit) or
     not Assigned(_EVP_DigestVerifyUpdate) or not Assigned(_EVP_DigestVerifyFinal) then
  begin
    AError := 'OpenSSL RSA verification symbols not available';
    Exit;
  end;

  SigBytes := TNetEncoding.Base64.DecodeStringToBytes(ASignatureBase64);
  if Length(SigBytes) = 0 then
  begin
    AError := 'Invalid Base64 signature';
    Exit;
  end;

  PemBytes := TEncoding.ANSI.GetBytes(APEMPublicKey);
  if Length(PemBytes) = 0 then
  begin
    AError := 'Empty public key';
    Exit;
  end;

  Bio := _BIO_new_mem_buf(@PemBytes[0], Length(PemBytes));
  if Bio = nil then
  begin
    AError := 'BIO_new_mem_buf failed';
    Exit;
  end;
  try
    PKey := _PEM_read_bio_PUBKEY(Bio, nil, nil, nil);
    if PKey = nil then
    begin
      AError := 'Failed to parse PEM public key';
      Exit;
    end;
    try
      MDCtx := _EVP_MD_CTX_new();
      if MDCtx = nil then
      begin
        AError := 'EVP_MD_CTX_new failed';
        Exit;
      end;
      try
        if _EVP_DigestVerifyInit(MDCtx, nil, _EVP_sha256(), nil, PKey) <> 1 then
        begin
          AError := 'EVP_DigestVerifyInit failed';
          Exit;
        end;

        if Length(AData) > 0 then
        begin
          if _EVP_DigestVerifyUpdate(MDCtx, @AData[0], Length(AData)) <> 1 then
          begin
            AError := 'EVP_DigestVerifyUpdate failed';
            Exit;
          end;
        end;

        if _EVP_DigestVerifyFinal(MDCtx, @SigBytes[0], Length(SigBytes)) = 1 then
          Result := True
        else
          AError := 'RSA-SHA256 signature verification failed';
      finally
        _EVP_MD_CTX_free(MDCtx);
      end;
    finally
      _EVP_PKEY_free(PKey);
    end;
  finally
    _BIO_free(Bio);
  end;
end;

initialization
  GInitLock := TCriticalSection.Create;

finalization
  if GLibHandle <> 0 then
    FreeLib(GLibHandle);
  FreeAndNil(GInitLock);

{$ENDIF}

end.
