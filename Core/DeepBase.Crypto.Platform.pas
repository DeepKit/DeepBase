unit DeepBase.Crypto.Platform;

{*******************************************************************************
  DeepBase Crypto - Platform Layer
  BCrypt/CryptoAPI external declarations, shared low-level Windows API bindings,
  and cross-platform constants used by all DeepBase.Crypto sub-modules.

  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils
  {$IFDEF MSWINDOWS}
  , Winapi.Windows
  {$ENDIF};

type
  /// <summary>Base exception class for all cryptographic errors.</summary>
  ECryptoException = class(Exception);

{$IFDEF MSWINDOWS}
const
  // ---- BCrypt DLL and algorithm identifiers ----
  BCRYPT_DLL = 'bcrypt.dll';
  BCRYPT_AES_ALGORITHM = 'AES';
  BCRYPT_CHAIN_MODE_CBC = 'ChainingModeCBC';
  BCRYPT_CHAIN_MODE_GCM = 'ChainingModeGCM';
  BCRYPT_CHAINING_MODE = 'ChainingMode';
  BCRYPT_OBJECT_LENGTH = 'ObjectLength';
  BCRYPT_BLOCK_LENGTH = 'BlockLength';

type
  BCRYPT_ALG_HANDLE = THandle;
  BCRYPT_KEY_HANDLE = THandle;
  NTSTATUS = LongInt;

function BCryptOpenAlgorithmProvider(out phAlgorithm: BCRYPT_ALG_HANDLE;
  pszAlgId: PWideChar; pszImplementation: PWideChar; dwFlags: ULONG): NTSTATUS; stdcall;
  external BCRYPT_DLL;

function BCryptCloseAlgorithmProvider(hAlgorithm: BCRYPT_ALG_HANDLE;
  dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;

function BCryptGetProperty(hObject: THandle; pszProperty: PWideChar;
  pbOutput: PByte; cbOutput: ULONG; out pcbResult: ULONG;
  dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;

function BCryptSetProperty(hObject: THandle; pszProperty: PWideChar;
  pbInput: PByte; cbInput: ULONG; dwFlags: ULONG): NTSTATUS; stdcall;
  external BCRYPT_DLL;

function BCryptGenerateSymmetricKey(hAlgorithm: BCRYPT_ALG_HANDLE;
  out phKey: BCRYPT_KEY_HANDLE; pbKeyObject: PByte; cbKeyObject: ULONG;
  pbSecret: PByte; cbSecret: ULONG; dwFlags: ULONG): NTSTATUS; stdcall;
  external BCRYPT_DLL;

function BCryptDestroyKey(hKey: BCRYPT_KEY_HANDLE): NTSTATUS; stdcall;
  external BCRYPT_DLL;

function BCryptEncrypt(hKey: BCRYPT_KEY_HANDLE; pbInput: PByte; cbInput: ULONG;
  pPaddingInfo: Pointer; pbIV: PByte; cbIV: ULONG; pbOutput: PByte;
  cbOutput: ULONG; out pcbResult: ULONG; dwFlags: ULONG): NTSTATUS; stdcall;
  external BCRYPT_DLL;

function BCryptDecrypt(hKey: BCRYPT_KEY_HANDLE; pbInput: PByte; cbInput: ULONG;
  pPaddingInfo: Pointer; pbIV: PByte; cbIV: ULONG; pbOutput: PByte;
  cbOutput: ULONG; out pcbResult: ULONG; dwFlags: ULONG): NTSTATUS; stdcall;
  external BCRYPT_DLL;

function BCryptGenRandom(hAlgorithm: BCRYPT_ALG_HANDLE; pbBuffer: PByte;
  cbBuffer: ULONG; dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;

const
  BCRYPT_USE_SYSTEM_PREFERRED_RNG = $00000002;
  BCRYPT_BLOCK_PADDING = $00000001;
  STATUS_SUCCESS = 0;

  // GCM authenticated encryption constants
  BCRYPT_AUTH_MODE_CHAIN_CALLS_FLAG = $00000001;
  BCRYPT_AUTH_MODE_IN_PROGRESS_FLAG = $00000002;
  BCRYPT_INIT_AUTH_MODE_INFO_VERSION = 1;
  BCRYPT_GCM_NONCE_SIZE = 12;
  BCRYPT_GCM_TAG_SIZE = 16;

  // RSA algorithm identifiers
  BCRYPT_RSA_ALGORITHM = 'RSA';
  BCRYPT_SHA256_ALGORITHM = 'SHA256';

  // Padding schemes
  BCRYPT_PAD_PKCS1 = $00000002;

  // Key blob types
  BCRYPT_RSAPUBLIC_BLOB = 'RSAPUBLICBLOB';
  BCRYPT_RSAPRIVATE_BLOB = 'RSAPRIVATEBLOB';
  BCRYPT_RSAFULLPRIVATE_BLOB = 'RSAFULLPRIVATEBLOB';

  // RSAPUBKEY structure magic
  BCRYPT_RSAPUBLIC_MAGIC = $31415352;   // 'RSA1'
  BCRYPT_RSAPRIVATE_MAGIC = $32415352;  // 'RSA2'
  BCRYPT_RSAFULLPRIVATE_MAGIC = $33415352; // 'RSA3'

type
  // BCrypt RSA public key blob header
  BCRYPT_RSAKEY_BLOB = record
    Magic: ULONG;
    BitLength: ULONG;
    cbPublicExp: ULONG;
    cbModulus: ULONG;
    cbPrime1: ULONG;
    cbPrime2: ULONG;
  end;
  PBCRYPT_RSAKEY_BLOB = ^BCRYPT_RSAKEY_BLOB;

  // PKCS1 padding info
  BCRYPT_PKCS1_PADDING_INFO = record
    pszAlgId: PWideChar;
  end;
  PBCRYPT_PKCS1_PADDING_INFO = ^BCRYPT_PKCS1_PADDING_INFO;

  // Authenticated cipher mode info (used for AES-GCM)
  BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO = record
    cbSize: ULONG;
    dwInfoVersion: ULONG;
    pbNonce: PByte;
    cbNonce: ULONG;
    pbAuthData: PByte;
    cbAuthData: ULONG;
    pbTag: PByte;
    cbTag: ULONG;
    pbMacContext: PByte;
    cbMacContext: ULONG;
    cbAAD: ULONG;
    cbData: UInt64;
    dwFlags: ULONG;
  end;
  PBCRYPT_AUTHENTICATED_CIPHER_MODE_INFO = ^BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO;

function BCryptImportKeyPair(hAlgorithm: BCRYPT_ALG_HANDLE; hImportKey: BCRYPT_KEY_HANDLE;
  pszBlobType: PWideChar; out phKey: BCRYPT_KEY_HANDLE; pbInput: PByte; cbInput: ULONG;
  dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;

function BCryptVerifySignature(hKey: BCRYPT_KEY_HANDLE; pPaddingInfo: Pointer;
  pbHash: PByte; cbHash: ULONG; pbSignature: PByte; cbSignature: ULONG;
  dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;

function BCryptSignHash(hKey: BCRYPT_KEY_HANDLE; pPaddingInfo: Pointer;
  pbHash: PByte; cbHash: ULONG; pbSignature: PByte; cbSignature: ULONG;
  out pcbResult: ULONG; dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;

function BCryptHash(hAlgorithm: BCRYPT_ALG_HANDLE; pbSecret: PByte; cbSecret: ULONG;
  pbInput: PByte; cbInput: ULONG; pbOutput: PByte; cbOutput: ULONG): NTSTATUS; stdcall;
  external BCRYPT_DLL;

const
  // ---- Legacy CryptoAPI (advapi32) constants ----
  CRYPTOAPI_DLL = 'advapi32.dll';
  PROV_RSA_FULL = 1;
  PROV_RSA_AES = 24;
  CRYPT_VERIFYCONTEXT = $F0000000;
  CRYPT_EXPORTABLE = $00000001;
  CALG_SHA_256 = $0000800C;
  CALG_AES_256 = $00006610;
  KP_MODE = 4;
  KP_IV = 1;
  CRYPT_MODE_CBC = 1;
  HP_HASHVAL = 2;
  MS_ENH_RSA_AES_PROV = 'Microsoft Enhanced RSA and AES Cryptographic Provider';

type
  HCRYPTPROV = THandle;
  HCRYPTKEY = THandle;
  HCRYPTHASH = THandle;

function CryptAcquireContext(var phProv: HCRYPTPROV; pszContainer: PAnsiChar;
  pszProvider: PAnsiChar; dwProvType: DWORD; dwFlags: DWORD): BOOL; stdcall;
  external CRYPTOAPI_DLL name 'CryptAcquireContextA';

function CryptReleaseContext(hProv: HCRYPTPROV; dwFlags: DWORD): BOOL; stdcall;
  external CRYPTOAPI_DLL;

function CryptGenRandom(hProv: HCRYPTPROV; dwLen: DWORD; pbBuffer: PByte): BOOL; stdcall;
  external CRYPTOAPI_DLL;

function CryptCreateHash(hProv: HCRYPTPROV; Algid: DWORD; hKey: HCRYPTKEY;
  dwFlags: DWORD; var phHash: HCRYPTHASH): BOOL; stdcall; external CRYPTOAPI_DLL;

function CryptHashData(hHash: HCRYPTHASH; pbData: PByte; dwDataLen: DWORD;
  dwFlags: DWORD): BOOL; stdcall; external CRYPTOAPI_DLL;

function CryptDeriveKey(hProv: HCRYPTPROV; Algid: DWORD; hBaseData: HCRYPTHASH;
  dwFlags: DWORD; var phKey: HCRYPTKEY): BOOL; stdcall; external CRYPTOAPI_DLL;

function CryptSetKeyParam(hKey: HCRYPTKEY; dwParam: DWORD; pbData: PByte;
  dwFlags: DWORD): BOOL; stdcall; external CRYPTOAPI_DLL;

function CryptEncrypt(hKey: HCRYPTKEY; hHash: HCRYPTHASH; Final: BOOL;
  dwFlags: DWORD; pbData: PByte; var pdwDataLen: DWORD; dwBufLen: DWORD): BOOL; stdcall;
  external CRYPTOAPI_DLL;

function CryptDecrypt(hKey: HCRYPTKEY; hHash: HCRYPTHASH; Final: BOOL;
  dwFlags: DWORD; pbData: PByte; var pdwDataLen: DWORD): BOOL; stdcall;
  external CRYPTOAPI_DLL;

function CryptDestroyKey(hKey: HCRYPTKEY): BOOL; stdcall; external CRYPTOAPI_DLL;

function CryptDestroyHash(hHash: HCRYPTHASH): BOOL; stdcall; external CRYPTOAPI_DLL;

function CryptGetHashParam(hHash: HCRYPTHASH; dwParam: DWORD; pbData: PByte;
  var pdwDataLen: DWORD; dwFlags: DWORD): BOOL; stdcall; external CRYPTOAPI_DLL;
{$ENDIF}

// Cross-platform GCM parameters (match BCrypt constants on Windows)
const
  AES_GCM_NONCE_SIZE = 12;
  AES_GCM_TAG_SIZE = 16;

implementation

end.
