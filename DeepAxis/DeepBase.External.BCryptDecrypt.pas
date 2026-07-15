{ ============================================================================
  DeepBase.External.BCryptDecrypt - BCrypt Direct Decryption Backend
  Version: 0.7
  Based on WxDecryptProbe v0.2 (colleague's verified implementation)
  Zero external DLL — uses Windows built-in BCrypt API
  ============================================================================ }

unit DeepBase.External.BCryptDecrypt;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows;

type
  BCRYPT_ALG_HANDLE = THandle;

const
  bcrypt = 'bcrypt.dll';
  advapi32 = 'advapi32.dll';

  BCRYPT_USE_SYSTEM_PREFERRED_RNG = $00000002;

  PAGE_SIZE      = 4096;
  KEY_SIZE       = 32;
  IV_SIZE        = 16;
  HMAC_SHA1_SIZE = 20;
  AES_BLOCK      = 16;
  PBKDF2_ITER    = 64000;

  SQLITE_HEADER  = 'SQLite format 3'#0;

function BCryptGenRandom(hAlgorithm: BCRYPT_ALG_HANDLE; pbBuffer: PBYTE;
  cbBuffer: ULONG; dwFlags: DWORD): Cardinal; stdcall; external bcrypt;
// Fallback for OSes older than Windows 10 1903 — RtlGenRandom is exported
// from advapi32.dll under the name SystemFunction036.
function RtlGenRandom(RandomBuffer: Pointer; RandomBufferLength: ULONG): Boolean;
  stdcall; external advapi32 name 'SystemFunction036';

function BCryptOpenAlgorithmProvider(out hAlg: BCRYPT_ALG_HANDLE;
  const pszAlgId: LPCWSTR; pszImpl: LPCWSTR; dwFlags: DWORD): Cardinal; stdcall; external bcrypt;
function BCryptCloseAlgorithmProvider(hAlg: BCRYPT_ALG_HANDLE;
  dwFlags: DWORD): Cardinal; stdcall; external bcrypt;
function BCryptSetProperty(hObject: THandle; const pszProperty: LPCWSTR;
  pbInput: PBYTE; cbInput: DWORD; dwFlags: DWORD): Cardinal; stdcall; external bcrypt;
function BCryptGenerateSymmetricKey(hAlg: BCRYPT_ALG_HANDLE;
  out hKey: THandle; pbKeyObject: PBYTE; cbKeyObject: DWORD;
  pbSecret: PBYTE; cbSecret: DWORD; dwFlags: DWORD): Cardinal; stdcall; external bcrypt;
function BCryptDestroyKey(hKey: THandle): Cardinal; stdcall; external bcrypt;
function BCryptDecrypt(hKey: THandle; pbInput: PBYTE; cbInput: DWORD;
  pPaddingInfo: Pointer; pbIV: PBYTE; cbIV: DWORD; pbOutput: PBYTE;
  cbOutput: DWORD; var pcbResult: DWORD; dwFlags: DWORD): Cardinal; stdcall; external bcrypt;
function BCryptDeriveKeyPBKDF2(hPrf: BCRYPT_ALG_HANDLE;
  pbPassword: PBYTE; cbPassword: DWORD; pbSalt: PBYTE; cbSalt: DWORD;
  cIterations: UInt64; pbDerivedKey: PBYTE; cbDerivedKey: DWORD;
  dwFlags: DWORD): Cardinal; stdcall; external bcrypt;
function BCryptCreateHash(hAlg: BCRYPT_ALG_HANDLE;
  out hHash: THandle; pbHashObject: PBYTE; cbHashObject: DWORD;
  pbSecret: PBYTE; cbSecret: DWORD; dwFlags: DWORD): Cardinal; stdcall; external bcrypt;
function BCryptHashData(hHash: THandle; pbInput: PBYTE;
  cbInput: DWORD; dwFlags: DWORD): Cardinal; stdcall; external bcrypt;
function BCryptFinishHash(hHash: THandle; pbOutput: PBYTE;
  cbOutput: DWORD; dwFlags: DWORD): Cardinal; stdcall; external bcrypt;
function BCryptDestroyHash(hHash: THandle): Cardinal; stdcall; external bcrypt;

function IsNTSTATUS_Success(Status: Cardinal): Boolean; inline;

procedure DeriveSQLCipherKey(const ARawKey, ASalt: TBytes;
  out AKey, AMacKey: TBytes);

function ComputeHMAC(const AData: TBytes; const AMacKey: TBytes;
  APageNum: Integer): TBytes;

function DecryptPage(const AEncrypted: TBytes; const AKey: TBytes;
  const AIV: TBytes; APageNum: Integer; AReserve: Integer): TBytes;

function TryDecryptDB(const ADbPath, AOutPath: string;
  const AKey, AMacKey: TBytes): Boolean;

type
  TBCryptSQLiteReader = class
  private
    FAesKey: TBytes;
    FMacKey: TBytes;
    FDecryptedPath: string;
  public
    constructor Create(const ARawKey, ASalt: TBytes);
    destructor Destroy; override;
    function OpenDatabase(const ADbPath: string): Boolean;
    function ReadPage(APageNum: Integer): TBytes;
    property DecryptedPath: string read FDecryptedPath;
  end;

implementation

uses
  System.Generics.Collections, System.IOUtils;

function IsNTSTATUS_Success(Status: Cardinal): Boolean;
begin
  Result := (Status and $80000000) = 0;
end;

procedure CheckNTSTATUS(Status: Cardinal; const Msg: string);
begin
  if not IsNTSTATUS_Success(Status) then
    raise Exception.CreateFmt('%s (0x%x)', [Msg, Status]);
end;

{ ─── BCrypt PBKDF2-HMAC-SHA1 Key Derivation (from WxDecryptProbe verified) ─── }

procedure DeriveSQLCipherKey(const ARawKey, ASalt: TBytes;
  out AKey, AMacKey: TBytes);
const
  BCRYPT_SHA1_ALGORITHM = 'SHA1';
begin
  SetLength(AKey, KEY_SIZE);
  SetLength(AMacKey, KEY_SIZE);

  var hSha1: BCRYPT_ALG_HANDLE;
  CheckNTSTATUS(
    BCryptOpenAlgorithmProvider(hSha1, BCRYPT_SHA1_ALGORITHM, nil, 0),
    'BCryptOpenAlgorithmProvider(SHA1)');

  try
    // PBKDF2-HMAC-SHA1(raw_key, salt, 64000) -> AES key
    CheckNTSTATUS(
      BCryptDeriveKeyPBKDF2(hSha1, @ARawKey[0], Length(ARawKey),
        @ASalt[0], Length(ASalt), PBKDF2_ITER, @AKey[0], KEY_SIZE, 0),
      'BCryptDeriveKeyPBKDF2 (key)');

    // MAC salt = salt XOR 0x3a
    var MacSalt: TBytes := Copy(ASalt);
    for var I := 0 to Length(MacSalt) - 1 do
      MacSalt[I] := MacSalt[I] xor $3a;

    // PBKDF2-HMAC-SHA1(AES_key, mac_salt, 2) -> MAC key
    CheckNTSTATUS(
      BCryptDeriveKeyPBKDF2(hSha1, @AKey[0], Length(AKey),
        @MacSalt[0], Length(MacSalt), 2, @AMacKey[0], KEY_SIZE, 0),
      'BCryptDeriveKeyPBKDF2 (mac_key)');
  finally
    BCryptCloseAlgorithmProvider(hSha1, 0);
  end;
end;

{ ─── BCrypt HMAC-SHA1 ─── }

function ComputeHMAC(const AData: TBytes; const AMacKey: TBytes;
  APageNum: Integer): TBytes;
const
  BCRYPT_SHA1_ALGORITHM = 'SHA1';
  BCRYPT_ALG_HANDLE_HMAC_FLAG = $00000008;
begin
  SetLength(Result, HMAC_SHA1_SIZE);

  var hSha1: BCRYPT_ALG_HANDLE;
  CheckNTSTATUS(
    BCryptOpenAlgorithmProvider(hSha1, BCRYPT_SHA1_ALGORITHM, nil,
      BCRYPT_ALG_HANDLE_HMAC_FLAG),
    'BCryptOpenAlgorithmProvider(SHA1 HMAC)');

  try
    var hHash: THandle;
    CheckNTSTATUS(
      BCryptCreateHash(hSha1, hHash, nil, 0, @AMacKey[0], Length(AMacKey), 0),
      'BCryptCreateHash');
    try
      CheckNTSTATUS(BCryptHashData(hHash, @AData[0], Length(AData), 0),
        'BCryptHashData');
      var PageLE: Integer := APageNum;
      CheckNTSTATUS(BCryptHashData(hHash, @PageLE, SizeOf(PageLE), 0),
        'BCryptHashData(page)');
      CheckNTSTATUS(BCryptFinishHash(hHash, @Result[0], HMAC_SHA1_SIZE, 0),
        'BCryptFinishHash');
    finally
      BCryptDestroyHash(hHash);
    end;
  finally
    BCryptCloseAlgorithmProvider(hSha1, 0);
  end;
end;

{ ─── BCrypt AES-256-CBC Decrypt ─── }

function DecryptPage(const AEncrypted: TBytes; const AKey: TBytes;
  const AIV: TBytes; APageNum: Integer; AReserve: Integer): TBytes;
const
  BCRYPT_AES_ALGORITHM = 'AES';
  BCRYPT_CHAIN_MODE_CBC = 'ChainingModeCBC';
  BCRYPT_CHAINING_MODE = 'ChainingMode';
var
  hAes: BCRYPT_ALG_HANDLE;
  hKey: THandle;
  OutLen, Offset: DWORD;
begin
  SetLength(Result, PAGE_SIZE);

  if APageNum = 1 then
  begin
    Move(PAnsiChar(SQLITE_HEADER)^, Result[0], 16);
    Offset := 16;
  end
  else
    Offset := 0;

  CheckNTSTATUS(
    BCryptOpenAlgorithmProvider(hAes, BCRYPT_AES_ALGORITHM, nil, 0),
    'BCryptOpenAlgorithmProvider(AES)');
  try
    var LChainMode: TBytes := TEncoding.Unicode.GetBytes(BCRYPT_CHAIN_MODE_CBC);
    CheckNTSTATUS(
      BCryptSetProperty(hAes, BCRYPT_CHAINING_MODE, @LChainMode[0],
        Length(LChainMode), 0),
      'BCryptSetProperty(ChainingModeCBC)');

    CheckNTSTATUS(
      BCryptGenerateSymmetricKey(hAes, hKey, nil, 0,
        @AKey[0], KEY_SIZE, 0),
      'BCryptGenerateSymmetricKey');
    try
      var InLen := PAGE_SIZE - AReserve - Offset;
      var IVCopy: TBytes := Copy(AIV);

      CheckNTSTATUS(
        BCryptDecrypt(hKey, @AEncrypted[Offset], InLen, nil,
          @IVCopy[0], Length(IVCopy), @Result[Offset], InLen, OutLen, 0),
        'BCryptDecrypt');

      Move(AEncrypted[PAGE_SIZE - AReserve], Result[PAGE_SIZE - AReserve], AReserve);
    finally
      BCryptDestroyKey(hKey);
    end;
  finally
    BCryptCloseAlgorithmProvider(hAes, 0);
  end;
end;

{ ─── Full Database Decryption with HMAC Verification ─── }

function TryDecryptDB(const ADbPath, AOutPath: string;
  const AKey, AMacKey: TBytes): Boolean;
var
  InStream, OutStream: TFileStream;
  FileSize: Int64;
  Salt: TBytes;
  PageBuf, DecPage, ExpectedMac: TBytes;
  NumPages, Reserve, DataLen: Integer;
begin
  Result := False;
  if not TFile.Exists(ADbPath) then Exit;

  InStream := TFileStream.Create(ADbPath, fmOpenRead or fmShareDenyNone);
  try
    FileSize := InStream.Size;

    Reserve := IV_SIZE + HMAC_SHA1_SIZE;
    if (Reserve mod AES_BLOCK) <> 0 then
      Reserve := ((Reserve div AES_BLOCK) + 1) * AES_BLOCK;

    NumPages := FileSize div PAGE_SIZE;
    InStream.Position := 0;

    SetLength(PageBuf, PAGE_SIZE);
    SetLength(ExpectedMac, HMAC_SHA1_SIZE);
    DataLen := PAGE_SIZE - Reserve;

    OutStream := TFileStream.Create(AOutPath, fmCreate);
    try
      for var Page := 1 to NumPages do
      begin
        InStream.Read(PageBuf[0], PAGE_SIZE);

        // Verify HMAC
        Move(PageBuf[PAGE_SIZE - Reserve + IV_SIZE], ExpectedMac[0], HMAC_SHA1_SIZE);
        var DataForHMAC := Copy(PageBuf, 0, DataLen);
        var ComputedMac := ComputeHMAC(DataForHMAC, AMacKey, Page);
        if not CompareMem(@ComputedMac[0], @ExpectedMac[0], HMAC_SHA1_SIZE) then
          Exit(False);

        // Extract IV and decrypt
        var IV: TBytes;
        SetLength(IV, IV_SIZE);
        Move(PageBuf[PAGE_SIZE - Reserve], IV[0], IV_SIZE);

        DecPage := DecryptPage(PageBuf, AKey, IV, Page, Reserve);
        OutStream.Write(DecPage[0], PAGE_SIZE);
      end;

      Result := True;
    finally
      OutStream.Free;
    end;
  finally
    InStream.Free;
  end;
end;

{ TBCryptSQLiteReader }

constructor TBCryptSQLiteReader.Create(const ARawKey, ASalt: TBytes);
var
  LRandom: TBytes;
  I: Integer;
  LHex: string;
  LStatus: NTSTATUS;
begin
  inherited Create;
  DeriveSQLCipherKey(ARawKey, ASalt, FAesKey, FMacKey);
  // DATA2-004 fix: avoid TPath.GetTempFileName, whose names are predictable
  // (sequential) and discoverable by other local users. Use a 128-bit
  // cryptographically random hex name inside the user's temp directory.
  SetLength(LRandom, 16);
  // BCryptGenRandom (Windows 10 1903+) uses the OS CSPRNG; fall back to
  // RtlGenRandom (SystemFunction036) on older OSes.
  LStatus := BCryptGenRandom(0, @LRandom[0], Length(LRandom),
    BCRYPT_USE_SYSTEM_PREFERRED_RNG);
  if not IsNTSTATUS_Success(LStatus) then
  begin
    // Fallback: RtlGenRandom (exported as SystemFunction036 from advapi32)
    if not RtlGenRandom(@LRandom[0], Length(LRandom)) then
      raise Exception.Create('Failed to generate random temp filename');
  end;
  LHex := '';
  for I := 0 to High(LRandom) do
    LHex := LHex + IntToHex(LRandom[I], 2);
  FDecryptedPath := TPath.Combine(TPath.GetTempPath, 'dbsr_' + LHex + '.db');
end;

destructor TBCryptSQLiteReader.Destroy;
begin
  // DATA2-003 fix: erase AES/MAC key material from heap before freeing.
  // Note: on modern filesystems (NTFS + journaling, SSD wear leveling) this
  // does not guarantee physical erasure of all copies, but it prevents simple
  // heap-scanning recovery of the plaintext key while the process is alive.
  if Length(FAesKey) > 0 then
  begin
    FillChar(FAesKey[0], Length(FAesKey), 0);
    FAesKey := nil;
  end;
  if Length(FMacKey) > 0 then
  begin
    FillChar(FMacKey[0], Length(FMacKey), 0);
    FMacKey := nil;
  end;
  if FDecryptedPath <> '' then
  begin
    // Best-effort content wipe before unlink; ignored if file doesn't exist.
    try
      if TFile.Exists(FDecryptedPath) then
      begin
        var FS := TFileStream.Create(FDecryptedPath, fmOpenReadWrite);
        try
          var Zeros: TBytes;
          SetLength(Zeros, 4096);
          FillChar(Zeros[0], 4096, 0);
          var Remaining := FS.Size;
          while Remaining > 0 do
          begin
            var ToWrite := Remaining;
            if ToWrite > 4096 then ToWrite := 4096;
            FS.WriteBuffer(Zeros[0], ToWrite);
            Dec(Remaining, ToWrite);
          end;
        finally
          FS.Free;
        end;
        TFile.Delete(FDecryptedPath);
      end;
    except
      // Swallow cleanup errors; we're in a destructor.
    end;
  end;
  inherited;
end;

function TBCryptSQLiteReader.OpenDatabase(const ADbPath: string): Boolean;
begin
  Result := TryDecryptDB(ADbPath, FDecryptedPath, FAesKey, FMacKey);
  if not Result then
  begin
    TFile.Delete(FDecryptedPath);
    FDecryptedPath := '';
  end;
end;

function TBCryptSQLiteReader.ReadPage(APageNum: Integer): TBytes;
begin
  Result := nil;
end;

end.