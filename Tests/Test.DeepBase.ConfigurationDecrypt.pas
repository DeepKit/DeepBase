unit Test.DeepBase.ConfigurationDecrypt;

{*******************************************************************************
  A2-02 regression: TEncryptedConfigurationSource must be fail-closed.
  Corrupt ciphertext under a decrypt-flagged key raises EConfigurationException
  instead of being stored as plaintext; a valid DPAPI roundtrip returns the
  original value; non-flagged keys pass through untouched.
*******************************************************************************}

interface

uses
  System.SysUtils,
  System.NetEncoding,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.Configuration;

type
  [TestFixture]
  TTestEncryptedConfigFailClosed = class
  private
    FMem: TMemoryConfigurationSource;
    FSource: IConfigurationSource;
    function EncryptToBase64Dpapi(const AText: string): string;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    /// <summary>Valid DPAPI ciphertext decrypts back to the original plaintext</summary>
    [Test]
    procedure Test_ValidCiphertext_Roundtrip;

    /// <summary>Base64 payload that is not a DPAPI blob must raise, never enter the table</summary>
    [Test]
    procedure Test_CorruptCiphertext_Raises;

    /// <summary>Keys outside the encrypted list are passed through unchanged</summary>
    [Test]
    procedure Test_NonFlaggedKey_Passthrough;
  end;

implementation

uses
  Winapi.Windows;

type
  TDataBlobWin = record
    cbData: DWORD;
    pbData: PByte;
  end;
  PDataBlobWin = ^TDataBlobWin;

function CryptProtectData(pDataIn: PDataBlobWin; ppszDataDescr: PWideChar;
  pOptionalEntropy: PDataBlobWin; pvReserved: Pointer;
  pPromptStruct: Pointer; dwFlags: DWORD; pDataOut: PDataBlobWin): BOOL; stdcall;
  external 'crypt32.dll' name 'CryptProtectData';

{ TTestEncryptedConfigFailClosed }

function TTestEncryptedConfigFailClosed.EncryptToBase64Dpapi(
  const AText: string): string;
var
  InBlob, OutBlob: TDataBlobWin;
  Wide: UnicodeString;
  Raw: TBytes;
begin
  Wide := AText;
  InBlob.cbData := Length(Wide) * SizeOf(Char);
  InBlob.pbData := PByte(@Wide[1]);
  if not CryptProtectData(@InBlob, nil, nil, nil, nil, 0, @OutBlob) then
    RaiseLastOSError;
  try
    SetLength(Raw, OutBlob.cbData);
    Move(OutBlob.pbData^, Raw[0], OutBlob.cbData);
  finally
    LocalFree(HLOCAL(OutBlob.pbData));
  end;
  Result := TNetEncoding.Base64.EncodeBytesToString(Raw);
end;

procedure TTestEncryptedConfigFailClosed.SetUp;
begin
  FMem := TMemoryConfigurationSource.Create;
  FMem.SetValue('Plain', 'visible');
  FSource := TEncryptedConfigurationSource.Create(FMem, ['Secret'], False);
end;

procedure TTestEncryptedConfigFailClosed.TearDown;
begin
  FSource := nil;
  FMem := nil;
end;

procedure TTestEncryptedConfigFailClosed.Test_ValidCiphertext_Roundtrip;
var
  LData: TDictionary<string, string>;
begin
  FMem.SetValue('Secret', EncryptToBase64Dpapi('s3cr3t-value'));
  LData := FSource.Load;
  try
    Assert.AreEqual('s3cr3t-value', LData['Secret']);
    Assert.AreEqual('visible', LData['Plain']);
  finally
    LData.Free;
  end;
end;

procedure TTestEncryptedConfigFailClosed.Test_CorruptCiphertext_Raises;
var
  LGarbage: TBytes;
begin
  // Valid Base64, but the decoded bytes are not a DPAPI blob: Load must fail
  // closed instead of storing the ciphertext as if it were plaintext.
  LGarbage := TEncoding.UTF8.GetBytes('this-is-not-a-dpapi-blob');
  FMem.SetValue('Secret', TNetEncoding.Base64.EncodeBytesToString(LGarbage));
  Assert.WillRaise(procedure
    var
      LResult: TDictionary<string, string>;
    begin
      LResult := FSource.Load;
      LResult.Free;
    end, EConfigurationException);
end;

procedure TTestEncryptedConfigFailClosed.Test_NonFlaggedKey_Passthrough;
var
  LData: TDictionary<string, string>;
begin
  FMem.SetValue('Secret', EncryptToBase64Dpapi('x'));
  FMem.SetValue('Plain', 'C:\not\encrypted');
  LData := FSource.Load;
  try
    Assert.AreEqual('C:\not\encrypted', LData['Plain']);
  finally
    LData.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestEncryptedConfigFailClosed);

end.
