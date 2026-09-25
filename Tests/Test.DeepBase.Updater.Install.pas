{ ============================================================================
  Test.DeepBase.Updater.Install - 就地安装链的验签门禁与回滚回归

  覆盖 InstallDownloadedUpdate → 清单/包哈希/包签名三道门禁 → InstallPackage
  → CreateBackup/ApplyUpdate/RestoreBackup。这一段此前零覆盖（Tests 下无任何
  InstallPackage/备份/回滚用例），而"备份清单恒空"能长期存在正是零覆盖的产物；
  判据本身（备份条数可核对、回滚能还原）也只能落在真实文件系统上。

  夹具唯一真相源：密钥对与"已正确签名的 manifest"装配配方取自
  Test.DeepBase.UpdateFixtures，本单元不自建第二套签名配方。

  法源：WO-20260925-AUDIT-乙-B2 §B2-08。
  ============================================================================ }
unit Test.DeepBase.Updater.Install;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.JSON,
  System.Hash,
  System.IOUtils,
  System.Zip,
  DeepBase.Net.Transport,
  DeepBase.Update.Contracts,
  DeepBase.Updater,
  Test.DeepBase.UpdateFixtures;

type

  /// <summary>
  /// B2-08 判据回归：无签名/坏签名包拒绝安装且现场原样保留；好签名包安装成功，
  /// 备份清单是清单声明的真实受影响文件（条数与路径可核对），回滚可还原旧字节。
  /// </summary>
  [TestFixture]
  TTestUpdaterInstallChain = class
  private const
    UPDATE_URL = 'https://cdn.example.com/updates';
    OLD_EXE = 'OLD-EXE-BYTES';
    OLD_DATA = 'OLD-DATA-BYTES';
    NEW_EXE = 'NEW-EXE-BYTES';
    NEW_DATA = 'NEW-DATA-BYTES';
  private
    FRoot: string;
    FAppDir: string;
    FStagingDir: string;
    FBackupDir: string;
    FPackagePath: string;
    FInfo: TUpdateInfo;
    FManager: TUpdateManager;
    FFake: TFakeUpdaterTransport;
    FTransport: IDeepBaseHttpTransport;
    function AppFile(const ARelPath: string): string;
    function LatestBackupDir: string;
    function BackupPayloadFiles: TStringList;
    /// <summary>把一份 manifest 经真实的清单协商通道装进管理器的当前更新状态。</summary>
    procedure Negotiate(const AInfo: TUpdateInfo);
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_SignedPackage_InstallsAndBacksUpRealFileList;
    [Test]
    procedure Test_MissingSignature_RejectsInstall_KeepsOldBytes;
    [Test]
    procedure Test_ForgedPackageSignature_RejectsInstall;
    [Test]
    procedure Test_PackageReplacedAfterManifest_RejectsInstall;
    [Test]
    procedure Test_ManifestWithoutFileList_RejectsInstall;
    [Test]
    procedure Test_RollbackAfterInstall_RestoresOldBytes;
  end;

implementation

{ TTestUpdaterInstallChain }

function TTestUpdaterInstallChain.AppFile(const ARelPath: string): string;
begin
  Result := TPath.Combine(FAppDir, ARelPath);
end;

function TTestUpdaterInstallChain.LatestBackupDir: string;
var
  LDirs: TStringDynArray;
  I: Integer;
begin
  Result := '';
  if not TDirectory.Exists(FBackupDir) then
    Exit;
  LDirs := TDirectory.GetDirectories(FBackupDir);
  if Length(LDirs) = 0 then
    Exit;
  // 备份目录名是 yyyymmdd_hhnnss 定宽串，字典序即时间序（与 RestoreBackup 同口径）
  Result := LDirs[0];
  for I := 1 to High(LDirs) do
    if LDirs[I] > Result then
      Result := LDirs[I];
end;

function TTestUpdaterInstallChain.BackupPayloadFiles: TStringList;
var
  LBackup, LRel: string;
  LFiles: TStringDynArray;
  I: Integer;
begin
  Result := TStringList.Create;
  LBackup := LatestBackupDir;
  if LBackup = '' then
    Exit;
  LFiles := TDirectory.GetFiles(LBackup, '*.*', TSearchOption.soAllDirectories);
  for I := 0 to High(LFiles) do
  begin
    if SameText(TPath.GetFileName(LFiles[I]), 'manifest.json') then
      Continue; // 备份自述文件，不算受影响文件
    LRel := Copy(LFiles[I], Length(LBackup) + 2, MaxInt);
    Result.Add(LRel);
  end;
  Result.Sort;
end;

procedure TTestUpdaterInstallChain.Negotiate(const AInfo: TUpdateInfo);
var
  Root: TJSONObject;
  Files: TJSONArray;
  FileObj: TJSONObject;
  LParsed: TUpdateInfo;
  I: Integer;
begin
  { FCurrentUpdate 的唯一写入口是 CheckForUpdatesSync：测试不得旁路塞状态，
    必须经真实的清单协商通道，否则"就地安装"用的就不是同一条链路。 }
  Root := TJSONObject.Create;
  try
    Root.AddPair('app_id', AInfo.AppId);
    Root.AddPair('latest_version', AInfo.Version.ToString);
    Root.AddPair('channel', ChannelToString(AInfo.Channel));
    Root.AddPair('package_url', AInfo.DownloadUrl);
    Root.AddPair('download_size', TJSONNumber.Create(AInfo.DownloadSize));
    Root.AddPair('package_hash', AInfo.PackageHash);
    Root.AddPair('signature', AInfo.Signature);
    Root.AddPair('manifest_hash', AInfo.ManifestHash);
    Root.AddPair('manifest_signature', AInfo.ManifestSignature);
    Files := TJSONArray.Create;
    for I := 0 to High(AInfo.Files) do
    begin
      FileObj := TJSONObject.Create;
      FileObj.AddPair('name', AInfo.Files[I].FileName);
      FileObj.AddPair('path', AInfo.Files[I].RelativePath);
      Files.AddElement(FileObj);
    end;
    Root.AddPair('files', Files);
    FFake.Response := TDeepBaseHttpTransportResponse.Create(200, Root.ToString);
  finally
    Root.Free;
  end;
  Assert.IsTrue(FManager.CheckForUpdatesSync(LParsed),
    '测试前提失效：清单未能协商成功 —— ' + FManager.LastError);
end;

procedure TTestUpdaterInstallChain.SetUp;
var
  Zip: TZipFile;
  LNested: string;
begin
  // 目录名直接向 OS 借一个已保证唯一的临时文件名，避免多宿主/并发跑用例互踩
  FRoot := TPath.GetTempFileName;
  TFile.Delete(FRoot);
  FAppDir := TPath.Combine(FRoot, 'app');
  FStagingDir := TPath.Combine(FRoot, 'staging');
  FBackupDir := TPath.Combine(FRoot, 'backup');
  FPackagePath := TPath.Combine(FRoot, 'package.zip');
  LNested := 'data' + TPath.DirectorySeparatorChar + 'core.dat';
  ForceDirectories(TPath.GetDirectoryName(AppFile(LNested)));
  ForceDirectories(FStagingDir);
  ForceDirectories(FBackupDir);

  TFile.WriteAllText(AppFile('app.exe'), OLD_EXE);
  TFile.WriteAllText(AppFile(LNested), OLD_DATA);

  Zip := TZipFile.Create;
  try
    Zip.Open(FPackagePath, zmWrite);
    // zip 条目按规范用 '/'，清单里的受影响路径按本机分隔符写
    Zip.Add(TEncoding.UTF8.GetBytes(NEW_EXE), 'app.exe');
    Zip.Add(TEncoding.UTF8.GetBytes(NEW_DATA), 'data/core.dat');
    Zip.Close;
  finally
    Zip.Free;
  end;

  FInfo := BuildSignedManifestInfo(LowerCase(THashSHA2.GetHashStringFromFile(FPackagePath)));
  SetLength(FInfo.Files, 2);
  FInfo.Files[0].FileName := 'app.exe';
  FInfo.Files[0].RelativePath := 'app.exe';
  FInfo.Files[1].FileName := 'core.dat';
  FInfo.Files[1].RelativePath := LNested;

  FManager := TUpdateManager.Create;
  FManager.Initialize(UPDATE_URL, '1.0.0', FAppDir);
  FManager.SetPublicKey(TEST_PUBLIC_KEY_PEM);
  FManager.TempDirectory := FStagingDir;
  FManager.BackupDirectory := FBackupDir;

  FFake := TFakeUpdaterTransport.Create;
  FTransport := FFake as IDeepBaseHttpTransport;
  FManager.HttpTransport := FTransport;
end;

procedure TTestUpdaterInstallChain.TearDown;
begin
  FManager.Free;
  FTransport := nil;
  try
    if TDirectory.Exists(FRoot) then
      TDirectory.Delete(FRoot, True);
  except
    // 清理失败不影响判据，临时目录由 OS 侧回收
  end;
end;

procedure TTestUpdaterInstallChain.Test_SignedPackage_InstallsAndBacksUpRealFileList;
var
  LBackup, LExpectedNested: string;
  LBacked: TStringList;
begin
  Negotiate(FInfo);
  Assert.IsTrue(FManager.InstallDownloadedUpdate(FPackagePath),
    'Fully signed package must install: ' + FManager.LastError);
  Assert.AreEqual(usComplete, FManager.Status);

  Assert.AreEqual(NEW_EXE, TFile.ReadAllText(AppFile('app.exe')),
    'listed file must be replaced by the package version');
  LExpectedNested := 'data' + TPath.DirectorySeparatorChar + 'core.dat';
  Assert.AreEqual(NEW_DATA, TFile.ReadAllText(AppFile(LExpectedNested)));

  LBackup := LatestBackupDir;
  Assert.IsTrue(LBackup <> '', 'install must create a backup');
  LBacked := BackupPayloadFiles;
  try
    // 旧实现塞的是字面量 '*.*'：它匹配不到任何真实文件，所以备份里一条受影响
    // 文件都不会有。条数 + 逐条相对路径同时钉住"非空"和"是清单声明的真清单"。
    Assert.AreEqual(2, LBacked.Count,
      'backup must hold exactly the manifest-declared affected files');
    Assert.AreEqual('app.exe', LBacked[0]);
    Assert.AreEqual(LExpectedNested, LBacked[1]);
    Assert.AreEqual(OLD_EXE,
      TFile.ReadAllText(TPath.Combine(LBackup, LBacked[0])));
    Assert.AreEqual(OLD_DATA,
      TFile.ReadAllText(TPath.Combine(LBackup, LBacked[1])));
  finally
    LBacked.Free;
  end;
end;

procedure TTestUpdaterInstallChain.Test_MissingSignature_RejectsInstall_KeepsOldBytes;
var
  LTampered: TUpdateInfo;
  LBacked: TStringList;
begin
  LTampered := FInfo;
  LTampered.Signature := '';
  Negotiate(LTampered);

  Assert.IsFalse(FManager.InstallDownloadedUpdate(FPackagePath),
    'Package signature missing must refuse install');
  Assert.AreEqual(usFailed, FManager.Status);
  Assert.AreEqual(OLD_EXE, TFile.ReadAllText(AppFile('app.exe')),
    'scene must be left untouched on refusal');
  LBacked := BackupPayloadFiles;
  try
    Assert.AreEqual(0, LBacked.Count, 'refused install must not back up anything');
  finally
    LBacked.Free;
  end;
end;

procedure TTestUpdaterInstallChain.Test_ForgedPackageSignature_RejectsInstall;
var
  LTampered: TUpdateInfo;
  LPayload: string;
begin
  { manifest 层重算自洽，使攻击只落在包签名一层：验签必须用本地信任锚，
    伪造的 base64 签名过不了 RSA 层。 }
  LTampered := FInfo;
  LTampered.Signature := TestRSASign(StringOfChar('f', 64));
  LPayload := BuildManifestSignaturePayload(LTampered);
  LTampered.ManifestHash := LowerCase(THashSHA2.GetHashString(LPayload));
  LTampered.ManifestSignature := TestRSASign(LPayload);
  Negotiate(LTampered);

  Assert.IsFalse(FManager.InstallDownloadedUpdate(FPackagePath),
    'Forged package signature must refuse install');
  Assert.AreEqual(OLD_EXE, TFile.ReadAllText(AppFile('app.exe')));
end;

procedure TTestUpdaterInstallChain.Test_PackageReplacedAfterManifest_RejectsInstall;
begin
  { 清单已经谈好，包被换成别的字节（CDN 投毒/中间人换包）：哈希层必须拦下。 }
  Negotiate(FInfo);
  TFile.WriteAllText(FPackagePath, 'attacker-supplied-package-bytes');

  Assert.IsFalse(FManager.InstallDownloadedUpdate(FPackagePath),
    'Package not matching the manifest hash must refuse install');
  Assert.IsTrue(Pos('hash', LowerCase(FManager.LastError)) > 0,
    'refusal reason must name the failing layer, got: ' + FManager.LastError);
  Assert.AreEqual(OLD_EXE, TFile.ReadAllText(AppFile('app.exe')));
end;

procedure TTestUpdaterInstallChain.Test_ManifestWithoutFileList_RejectsInstall;
var
  LTampered: TUpdateInfo;
begin
  { 清单不声明受影响文件 ⇒ 备份清单必然为空 ⇒ 覆盖后无现场可还原。
    fail-closed：拒装，而不是"备份 0 条照样装"。 }
  LTampered := FInfo;
  SetLength(LTampered.Files, 0);
  Negotiate(LTampered);

  Assert.IsFalse(FManager.InstallDownloadedUpdate(FPackagePath),
    'Manifest without a file list must refuse install');
  Assert.AreEqual(OLD_EXE, TFile.ReadAllText(AppFile('app.exe')));
end;

procedure TTestUpdaterInstallChain.Test_RollbackAfterInstall_RestoresOldBytes;
var
  LNested: string;
begin
  LNested := 'data' + TPath.DirectorySeparatorChar + 'core.dat';
  Negotiate(FInfo);
  Assert.IsTrue(FManager.InstallDownloadedUpdate(FPackagePath),
    'precondition: signed package must install: ' + FManager.LastError);

  Assert.IsTrue(FManager.Rollback,
    'Rollback must restore from the real backup list: ' + FManager.LastError);
  Assert.AreEqual(OLD_EXE, TFile.ReadAllText(AppFile('app.exe')));
  Assert.AreEqual(OLD_DATA, TFile.ReadAllText(AppFile(LNested)));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUpdaterInstallChain);

end.
