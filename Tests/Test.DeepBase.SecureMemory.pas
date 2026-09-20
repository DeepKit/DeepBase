{ ============================================================================
  Test.DeepBase.SecureMemory - Unit tests for the secure-wipe SSOT unit.

  Test Coverage:
    - SecureZeroMemory / SecureClearBytes over byte arrays
    - SecureZeroMemory over strings
    - SecureZeroBuffer on a raw pointer, including the nil / zero-length guards
  ============================================================================ }

unit Test.DeepBase.SecureMemory;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  DeepBase.SecureMemory;

type
  [TestFixture]
  TTestSecureMemory = class
  public
    [Test]
    procedure Test_SecureZeroMemory_Bytes;
    [Test]
    procedure Test_SecureClearBytes_ReleasesStorage;
    [Test]
    procedure Test_SecureZeroMemory_String;
    [Test]
    procedure Test_SecureZeroMemory_EmptyInputs_AreNoOps;
    [Test]
    procedure Test_SecureZeroBuffer_WritesAcrossWholeRange;
  end;

implementation

procedure AssertAllZero(const AData: TBytes);
var
  B: Byte;
begin
  for B in AData do
    Assert.AreEqual(Byte(0), B);
end;

{ TTestSecureMemory }

procedure TTestSecureMemory.Test_SecureZeroMemory_Bytes;
var
  Data: TBytes;
begin
  Data := TEncoding.UTF8.GetBytes('sensitive-bytes');
  Assert.IsTrue(Length(Data) > 0);

  SecureZeroMemory(Data);

  AssertAllZero(Data);
Assert.IsTrue(Length(Data) = 15, 'Zeroing must keep the buffer alive for the caller');
end;

procedure TTestSecureMemory.Test_SecureClearBytes_ReleasesStorage;
var
  Data: TBytes;
begin
  Data := TEncoding.UTF8.GetBytes('sensitive-bytes');
  SecureClearBytes(Data);
  Assert.IsTrue(Length(Data) = 0);
end;

procedure TTestSecureMemory.Test_SecureZeroMemory_String;
var
  Data: string;
  I: Integer;
begin
  Data := 'sensitive-string';
  Assert.IsTrue(Length(Data) > 0);

  SecureZeroMemory(Data);

  for I := 1 to Length(Data) do
    Assert.AreEqual(#0, Data[I]);
end;

procedure TTestSecureMemory.Test_SecureZeroMemory_EmptyInputs_AreNoOps;
var
  Data: TBytes;
  Text: string;
begin
  Data := nil;
  SecureZeroMemory(Data);
  Assert.IsTrue(Length(Data) = 0);

  Text := '';
  SecureZeroMemory(Text);
  Assert.AreEqual('', Text);

  SecureZeroBuffer(nil, 0);
end;

procedure TTestSecureMemory.Test_SecureZeroBuffer_WritesAcrossWholeRange;
const
  SIZE = 64;
var
  Buffer: TBytes;
begin
  SetLength(Buffer, SIZE);
  FillChar(Buffer[0], SIZE, $FF);
  SecureZeroBuffer(@Buffer[0], SIZE);
  AssertAllZero(Buffer);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSecureMemory);

end.
