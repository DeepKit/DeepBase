unit Test.DeepBase.KeyManagerFormat;

{*******************************************************************************
  A2-04 regression: TKeyManager.Decrypt must not select the cipher suite from
  an unprotected leading byte. Unknown/tampered markers raise instead of
  silently downgrading to legacy CBC; valid $02 GCM blobs roundtrip.
*******************************************************************************}

interface

uses
  System.SysUtils,
  System.IOUtils,
  DUnitX.TestFramework,
  DeepBase.KeyManager;

type
  [TestFixture]
  TTestKeyManagerFormatFailClosed = class
  private
    FStorePath: string;
    FKM: TKeyManager;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    /// <summary>Encrypt emits the $02 marker and Decrypt roundtrips plaintext</summary>
    [Test]
    procedure Test_ValidGCM_Roundtrip;

    /// <summary>Flipping the format marker to any other byte must raise (fail-closed)</summary>
    [Test]
    procedure Test_TamperedMarker_Rejects;

    /// <summary>$02 marker with a truncated GCM payload must raise</summary>
    [Test]
    procedure Test_TruncatedPayload_Rejects;
  end;

implementation

const
  FMT_AES256_GCM = $02;
  /// Version(1) + Nonce(12) + Tag(16) minimum for a $02 envelope
  MIN_GCM_ENVELOPE = 1 + 12 + 16;

procedure TTestKeyManagerFormatFailClosed.SetUp;
begin
  FStorePath := TPath.Combine(TPath.GetTempPath,
    Format('a204_km_%d.json', [Random(MaxInt)]));
  FKM := TKeyManager.Create(FStorePath);
  FKM.Initialize('a204-master-password');
end;

procedure TTestKeyManagerFormatFailClosed.TearDown;
begin
  FKM.Free;
  if TFile.Exists(FStorePath) then
    TFile.Delete(FStorePath);
end;

procedure TTestKeyManagerFormatFailClosed.Test_ValidGCM_Roundtrip;
var
  LPlain, LCipher, LDecrypted: TBytes;
  I: Integer;
begin
  SetLength(LPlain, 32);
  for I := 0 to 31 do
    LPlain[I] := Byte(I * 7 + 3);

  LCipher := FKM.Encrypt(LPlain, kpEncryption);
  Assert.AreEqual(Byte(FMT_AES256_GCM), LCipher[0],
    'Encrypt must emit the $02 GCM format marker');
  Assert.IsTrue(Length(LCipher) >= MIN_GCM_ENVELOPE + Length(LPlain),
    'Envelope must carry Nonce(12)+Cipher(32)+Tag(16) after the marker');

  LDecrypted := FKM.Decrypt(LCipher, kpEncryption);
  Assert.AreEqual(Length(LPlain), Length(LDecrypted), 'Roundtrip length');
  for I := 0 to Length(LPlain) - 1 do
    Assert.AreEqual(LPlain[I], LDecrypted[I],
      Format('Roundtrip byte %d mismatch', [I]));
end;

procedure TTestKeyManagerFormatFailClosed.Test_TamperedMarker_Rejects;
var
  LPlain, LCipher: TBytes;
  LMarker: Byte;
  LRaised: Boolean;
begin
  for LMarker in [$00, $01, $03, $FF] do
  begin
    LPlain := TEncoding.UTF8.GetBytes('a204-tamper-probe');
    LCipher := FKM.Encrypt(LPlain, kpEncryption);
    LCipher[0] := LMarker;
    LRaised := False;
    try
      FKM.Decrypt(LCipher, kpEncryption);
    except
      on E: EKeyManagerException do
        LRaised := True;
    end;
    Assert.IsTrue(LRaised,
      Format('Marker $%.2x must be rejected instead of downgrading decryption',
        [LMarker]));
  end;
end;

procedure TTestKeyManagerFormatFailClosed.Test_TruncatedPayload_Rejects;
var
  LPlain, LCipher, LTruncated: TBytes;
  LRaised: Boolean;
begin
  LPlain := TEncoding.UTF8.GetBytes('a204-truncation-probe');
  LCipher := FKM.Encrypt(LPlain, kpEncryption);
  // Keep the valid $02 marker but cut the payload below Nonce+Tag minimum
  LTruncated := Copy(LCipher, 0, MIN_GCM_ENVELOPE - 1);
  LRaised := False;
  try
    FKM.Decrypt(LTruncated, kpEncryption);
  except
    on E: EKeyManagerException do
      LRaised := True;
  end;
  Assert.IsTrue(LRaised,
    'Truncated $02 envelope must raise instead of decrypting garbage');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestKeyManagerFormatFailClosed);

end.
