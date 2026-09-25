{ ============================================================================
  Test.DeepBase.CloudBackup.EncryptedVerify - 加密备份的解密校验链回归

  覆盖 VerifyBackup 与 InternalRestore 共用的明文解析入口 PlainArchivePath。
  旧实现把未解密的 .zip.enc 直接交给 TZipFile.Open，启用加密的备份必然校验失败，
  而恢复链又以 VerifyBackup 作前置门禁 ⇒ "启用加密即不可验证、不可恢复"。
  判据全部落在真实文件系统上：加密往返可恢复、损坏密文/错误密钥必须拒绝、
  且任何失败路径都不得在备份根留下解密后的半开临时明文。

  法源：WO-20260925-AUDIT-乙-B2 §B2-07（含 §〇-8 fail-closed 总原则）。
  ============================================================================ }
unit Test.DeepBase.CloudBackup.EncryptedVerify;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  DeepBase.CloudBackup;

type

  /// <summary>
  /// B2-07 判据回归：加密备份解密后再校验/恢复必须成功；损坏密文与错误密钥
  /// 必须 fail-closed 拒绝且不留临时明文；请求加密但未配密钥时拒绝产出伪密文归档。
  /// </summary>
  [TestFixture]
  TTestEncryptedBackupVerify = class
  private const
    PAYLOAD = 'B2-07 encrypted round-trip payload';
    GOOD_KEY = 'b07-test-key';
  private
    FSrcDir: string;
    FBakDir: string;
    FManager: TCloudBackupManager;
    FBackupId: string;
    FRestoreSuccess: Boolean;
    FRestoreError: string;
    FBackupSuccess: Boolean;
    FBackupError: string;
    // InternalBackup/InternalRestore 的失败路径吞异常转事件，事件是唯一可观察出口
    procedure HandleRestoreComplete(Sender: TObject; Success: Boolean;
      const ErrorMsg: string);
    procedure HandleBackupComplete(Sender: TObject; Success: Boolean;
      const BackupId, ErrorMsg: string);
    function SourceFile: string;
    function ArchivePath: string;
    function TmpResidueCount: Integer;
    function ManagerWith(const AEncryptionKey: string;
      AEnableEncryption: Boolean = True): TCloudBackupManager;
    procedure MakeEncryptedBackup;
    procedure TamperArchive;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_EncryptedBackup_VerifiesTrue;
    [Test]
    procedure Test_EncryptedBackup_RestoresPayloadAndLeavesNoTemp;
    [Test]
    procedure Test_CorruptedCiphertext_VerifyFailsAndLeavesNoTemp;
    [Test]
    procedure Test_CorruptedCiphertext_RestoreBlockedAndLeavesNoTemp;
    [Test]
    procedure Test_WrongKey_VerifyFailsAndLeavesNoTemp;
    [Test]
    procedure Test_EncryptionRequestedWithoutKey_RefusesBackup;
    [Test]
    procedure Test_PlainBackup_StillVerifiesAndRestores;
  end;

implementation

{ TTestEncryptedBackupVerify }

function TTestEncryptedBackupVerify.SourceFile: string;
begin
  Result := TPath.Combine(FSrcDir, 'payload.txt');
end;

function TTestEncryptedBackupVerify.ArchivePath: string;
begin
  Result := TPath.Combine(FBakDir, FBackupId + '.zip.enc');
end;

function TTestEncryptedBackupVerify.TmpResidueCount: Integer;
begin
  if not TDirectory.Exists(FBakDir) then
    Exit(0);
  // 解密明文统一落在 <id>.tmp.zip：任何残留都等于把备份内容以明文留在磁盘上
  Result := Length(TDirectory.GetFiles(FBakDir, '*.tmp.zip'));
end;

function TTestEncryptedBackupVerify.ManagerWith(const AEncryptionKey: string;
  AEnableEncryption: Boolean): TCloudBackupManager;
var
  LCfg: TBackupConfig;
begin
  LCfg := TBackupConfig.Default;
  LCfg.SourcePaths := [FSrcDir];
  LCfg.LocalBackupPath := FBakDir;
  LCfg.EnableEncryption := AEnableEncryption;
  LCfg.EncryptionKey := AEncryptionKey;
  LCfg.MaxVersionsToKeep := 5;
  Result := TCloudBackupManager.Create(LCfg);
end;

procedure TTestEncryptedBackupVerify.Setup;
begin
  FSrcDir := TPath.Combine(TPath.GetTempPath, 'b07_src_' + TGUID.NewGuid.ToString);
  FBakDir := TPath.Combine(TPath.GetTempPath, 'b07_bak_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FSrcDir);
  TDirectory.CreateDirectory(FBakDir);
  TFile.WriteAllText(SourceFile, PAYLOAD);
  FManager := ManagerWith(GOOD_KEY);
end;

procedure TTestEncryptedBackupVerify.TearDown;
begin
  FreeAndNil(FManager);
  try
    TDirectory.Delete(FSrcDir, True);
    TDirectory.Delete(FBakDir, True);
  except
    // 临时目录清理失败不影响断言结果
  end;
end;

procedure TTestEncryptedBackupVerify.HandleRestoreComplete(Sender: TObject;
  Success: Boolean; const ErrorMsg: string);
begin
  FRestoreSuccess := Success;
  FRestoreError := ErrorMsg;
end;

procedure TTestEncryptedBackupVerify.HandleBackupComplete(Sender: TObject;
  Success: Boolean; const BackupId, ErrorMsg: string);
begin
  FBackupSuccess := Success;
  FBackupError := ErrorMsg;
end;

procedure TTestEncryptedBackupVerify.MakeEncryptedBackup;
begin
  FManager.BackupFull('b07-encrypted');
  Assert.AreEqual(1, Integer(FManager.GetVersions.Count),
    'encrypted backup must register exactly one version');
  FBackupId := FManager.GetVersions[0].BackupId;
  Assert.IsTrue(TFile.Exists(ArchivePath),
    'encrypted backup must write <id>.zip.enc: ' + ArchivePath);
  Assert.AreEqual(0, TmpResidueCount,
    'precondition: a successful backup must leave no decrypted temp archive');
end;

procedure TTestEncryptedBackupVerify.TamperArchive;
var
  LBytes: TBytes;
  LIndex: Integer;
begin
  LBytes := TFile.ReadAllBytes(ArchivePath);
  LIndex := High(LBytes) div 2;
  LBytes[LIndex] := LBytes[LIndex] xor $5A;
  TFile.WriteAllBytes(ArchivePath, LBytes);
end;

// 判据 1（加密备份往返 EXIT=0）：修前此用例必红——旧实现以 zip 方式打开未解密归档
procedure TTestEncryptedBackupVerify.Test_EncryptedBackup_VerifiesTrue;
begin
  MakeEncryptedBackup;
  Assert.IsTrue(FManager.VerifyBackup(FBackupId),
    'encrypted backup must verify via decrypt-then-open');
end;

procedure TTestEncryptedBackupVerify.Test_EncryptedBackup_RestoresPayloadAndLeavesNoTemp;
var
  LRestDir: string;
begin
  MakeEncryptedBackup;
  LRestDir := TPath.Combine(TPath.GetTempPath, 'b07_rest_' + TGUID.NewGuid.ToString);
  try
    FRestoreSuccess := False;
    FRestoreError := '';
    FManager.OnRestoreComplete := HandleRestoreComplete;
    FManager.Restore(FBackupId, LRestDir);

    Assert.IsTrue(FRestoreSuccess,
      'encrypted restore must succeed; error: ' + FRestoreError);
    Assert.AreEqual(PAYLOAD,
      TFile.ReadAllText(TPath.Combine(LRestDir, 'payload.txt')));
    Assert.AreEqual(0, TmpResidueCount,
      'restore must delete the decrypted temp archive on the success path');
  finally
    try
      TDirectory.Delete(LRestDir, True);
    except
    end;
  end;
end;

// 判据 2（损坏密文 EXIT≠0 且不留半开临时文件）：MAC 校验失败即拒绝
procedure TTestEncryptedBackupVerify.Test_CorruptedCiphertext_VerifyFailsAndLeavesNoTemp;
begin
  MakeEncryptedBackup;
  TamperArchive;

  Assert.IsFalse(FManager.VerifyBackup(FBackupId),
    'corrupted ciphertext must fail verification');
  Assert.AreEqual(0, TmpResidueCount,
    'failed decrypt must not leave a half-written decrypted temp archive');
end;

procedure TTestEncryptedBackupVerify.Test_CorruptedCiphertext_RestoreBlockedAndLeavesNoTemp;
var
  LRestDir: string;
begin
  MakeEncryptedBackup;
  TamperArchive;
  LRestDir := TPath.Combine(TPath.GetTempPath, 'b07_blocked_' + TGUID.NewGuid.ToString);
  try
    FRestoreSuccess := True;
    FRestoreError := '';
    FManager.OnRestoreComplete := HandleRestoreComplete;
    FManager.Restore(FBackupId, LRestDir);

    Assert.IsFalse(FRestoreSuccess,
      'restore must be blocked when the ciphertext is corrupted');
    Assert.IsFalse(TDirectory.Exists(LRestDir) and
      TFile.Exists(TPath.Combine(LRestDir, 'payload.txt')),
      'blocked restore must not write any file back');
    Assert.AreEqual(0, TmpResidueCount,
      'blocked restore must not leave decrypted plaintext behind');
  finally
    try
      TDirectory.Delete(LRestDir, True);
    except
    end;
  end;
end;

procedure TTestEncryptedBackupVerify.Test_WrongKey_VerifyFailsAndLeavesNoTemp;
var
  LOther: TCloudBackupManager;
begin
  MakeEncryptedBackup;
  LOther := ManagerWith('a-different-key');
  try
    Assert.IsFalse(LOther.VerifyBackup(FBackupId),
      'wrong key must not verify (fail-closed, no fallback to plaintext read)');
  finally
    LOther.Free;
  end;
  Assert.AreEqual(0, TmpResidueCount);
end;

procedure TTestEncryptedBackupVerify.Test_EncryptionRequestedWithoutKey_RefusesBackup;
var
  LNoKey: TCloudBackupManager;
begin
  // EnableEncryption=True 而 EncryptionKey='' 时旧行为：写出明文却挂 .zip.enc 后缀
  LNoKey := ManagerWith('', True);
  try
    FBackupSuccess := True;
    FBackupError := '';
    LNoKey.OnBackupComplete := HandleBackupComplete;
    LNoKey.BackupFull('b07-no-key');

    Assert.IsFalse(FBackupSuccess,
      'encryption requested without a key must refuse the backup');
    Assert.AreEqual(0, Integer(LNoKey.GetVersions.Count),
      'refused backup must not register a version');
    Assert.AreEqual(0, Integer(Length(TDirectory.GetFiles(FBakDir, '*.zip.enc'))),
      'refused backup must not produce a fake-ciphertext archive');
  finally
    LNoKey.Free;
  end;
end;

// 共享入口的非加密分支不得回归（旧的两套解密判断合一后仍要能直接开 zip）
procedure TTestEncryptedBackupVerify.Test_PlainBackup_StillVerifiesAndRestores;
var
  LPlain: TCloudBackupManager;
  LId: string;
  LRestDir: string;
begin
  LPlain := ManagerWith('', False);
  LRestDir := TPath.Combine(TPath.GetTempPath, 'b07_plain_' + TGUID.NewGuid.ToString);
  try
    LPlain.BackupFull('b07-plain');
    Assert.AreEqual(1, Integer(LPlain.GetVersions.Count));
    LId := LPlain.GetVersions[0].BackupId;

    Assert.IsTrue(LPlain.VerifyBackup(LId),
      'plain backup verification must not regress');

    LPlain.Restore(LId, LRestDir);
    Assert.AreEqual(PAYLOAD,
      TFile.ReadAllText(TPath.Combine(LRestDir, 'payload.txt')));
    Assert.AreEqual(0, TmpResidueCount);
  finally
    try
      TDirectory.Delete(LRestDir, True);
    except
    end;
    LPlain.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestEncryptedBackupVerify);

end.
