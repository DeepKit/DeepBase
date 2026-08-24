{ ============================================================================
  Test.Regression.CR20260824_P0Batch2 - Full-repo audit 2026-08-24, P0 batch 2

  Covers:
  - CR-001: TKeyDerivationParams.Default/High generated a fresh random salt on
    EVERY process start and the salt was never persisted. The KEK therefore
    changed between sessions and every stored data key became permanently
    undecryptable. After the fix:
      a) KDF params are persisted inside the keystore JSON ('kdf' node).
      b) Initialize reuses persisted params -> same password reproduces the
         same KEK across sessions (round-trip decrypt works).
      c) Wrong password fails fast at Initialize via VerifyKeysDecryptable.
  ============================================================================ }

unit Test.Regression.CR20260824_P0Batch2;

interface

uses
  System.SysUtils,
  System.IOUtils,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.KeyManager;

type
  [TestFixture]
  [Category('regression')]
  TCR20260824P0Batch2Test = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    procedure Test_CR001_KEK_Reproducible_AcrossSessions;

    [Test]
    procedure Test_CR001_WrongPassword_FailsFastAtInitialize;
  end;

implementation

{ TCR20260824P0Batch2Test }

function TCR20260824P0Batch2Test.GetBugNumber: string;
begin
  Result := 'CR-001';
end;

function TCR20260824P0Batch2Test.GetBugDescription: string;
begin
  Result := 'Master-key KDF salt regenerated per session without persistence: stored data keys unrecoverable after restart';
end;

function TCR20260824P0Batch2Test.GetFixDate: string;
begin
  Result := '2026-08-24';
end;

function TCR20260824P0Batch2Test.GetPriority: string;
begin
  Result := 'P0';
end;

function TCR20260824P0Batch2Test.GetAffectedFile: string;
begin
  Result := 'Core\DeepBase.KeyManager.pas';
end;

procedure TCR20260824P0Batch2Test.Test_CR001_KEK_Reproducible_AcrossSessions;
var
  StorePath: string;
  M1, M2: TKeyManager;
  Token, Decrypted: string;
const
  Password = 'CR001-Correct-Horse-Battery';
begin
  StorePath := TPath.Combine(TPath.GetTempPath,
    'km_cr001_' + TGUID.NewGuid.ToString + '.json');
  try
    // Session 1: initialize, encrypt, then "process exit"
    M1 := TKeyManager.Create(StorePath);
    try
      M1.Initialize(Password, False); // skip hardware binding for determinism
      Token := M1.EncryptString('cr001-secret-payload', kpConfig);
    finally
      M1.Free;
    end;

    Assert.IsTrue(TFile.Exists(StorePath), 'keystore file must be created');

    // Session 2: same store, same password -> must decrypt
    M2 := TKeyManager.Create(StorePath);
    try
      // Pre-fix this Initialize derived a different KEK; with the fix the
      // persisted salt reproduces the original KEK.
      M2.Initialize(Password, False);
      Decrypted := M2.DecryptString(Token, kpConfig);
    finally
      M2.Free;
    end;

    Assert.AreEqual('cr001-secret-payload', Decrypted,
      'Data encrypted in session 1 must be decryptable in session 2');
  finally
    if TFile.Exists(StorePath) then
      TFile.Delete(StorePath);
  end;
end;

procedure TCR20260824P0Batch2Test.Test_CR001_WrongPassword_FailsFastAtInitialize;
var
  StorePath: string;
  M1, M2: TKeyManager;
const
  Password = 'CR001-right-password';
begin
  StorePath := TPath.Combine(TPath.GetTempPath,
    'km_cr001w_' + TGUID.NewGuid.ToString + '.json');
  try
    M1 := TKeyManager.Create(StorePath);
    try
      M1.Initialize(Password, False);
      M1.EncryptString('payload', kpConfig);
    finally
      M1.Free;
    end;

    // With persisted KDF params present, a wrong password must be detected
    // immediately by VerifyKeysDecryptable instead of silently producing a
    // useless KEK that corrupts later writes.
    M2 := TKeyManager.Create(StorePath);
    try
      Assert.WillRaise(
        procedure
        begin
          M2.Initialize('definitely-wrong-password', False);
        end,
        EKeyManagerException);
    finally
      M2.Free;
    end;
  finally
    if TFile.Exists(StorePath) then
      TFile.Delete(StorePath);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCR20260824P0Batch2Test);

end.
