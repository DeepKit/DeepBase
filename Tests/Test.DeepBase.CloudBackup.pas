{ ============================================================================
  Test.DeepBase.CloudBackup - Unit Tests for Cloud Backup Module
  
  Test Coverage:
    - TBackupFileInfo record operations
    - TBackupManifest management
    - TBackupVersion information
    - TBackupProgress tracking
    - TBackupConfig configuration
    - TBackupStatistics tracking
  ============================================================================ }

unit Test.DeepBase.CloudBackup;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  System.Generics.Collections,
  System.Net.URLClient,
  DeepBase.Exceptions,
  DeepBase.CloudBackup;

type
  [TestFixture]
  TTestBackupFileInfo = class
  public
    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_ToJSON;
    [Test]
    procedure Test_FromJSON;
    [Test]
    procedure Test_RoundTrip;
  end;

  [TestFixture]
  TTestBackupManifest = class
  private
    FManifest: TBackupManifest;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create_Defaults;
    [Test]
    procedure Test_AddFile;
    [Test]
    procedure Test_AddFile_Multiple;
    [Test]
    procedure Test_RemoveFile;
    [Test]
    procedure Test_FindFile_Exists;
    [Test]
    procedure Test_FindFile_NotExists;
    [Test]
    procedure Test_ToJSON;
    [Test]
    procedure Test_FromJSON;
    [Test]
    procedure Test_Properties;
    [Test]
    procedure Test_Tags;
  end;

  [TestFixture]
  TTestBackupVersion = class
  private
    FVersion: TBackupVersion;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Properties;
    [Test]
    procedure Test_ToJSON;
    [Test]
    procedure Test_FromJSON;
    [Test]
    procedure Test_RoundTrip;
  end;

  [TestFixture]
  TTestBackupProgress = class
  public
    [Test]
    procedure Test_ProgressPercent_Zero;
    [Test]
    procedure Test_ProgressPercent_Partial;
    [Test]
    procedure Test_ProgressPercent_Complete;
    [Test]
    procedure Test_FormattedProgress;
    [Test]
    procedure Test_Status_Values;
  end;

  [TestFixture]
  TTestBackupConfig = class
  public
    [Test]
    procedure Test_Default_Values;
    [Test]
    procedure Test_Default_CompressionLevel;
    [Test]
    procedure Test_Default_MaxVersions;
    [Test]
    procedure Test_SourcePaths;
    [Test]
    procedure Test_ExcludePatterns;
  end;

  [TestFixture]
  TTestBackupStatistics = class
  public
    [Test]
    procedure Test_Fields;
    [Test]
    procedure Test_Default_Values;
  end;

  [TestFixture]
  TTestBackupEnums = class
  public
    [Test]
    procedure Test_BackupStatus_Values;
    [Test]
    procedure Test_BackupType_Values;
    [Test]
    procedure Test_CompressionLevel_Values;
    [Test]
    procedure Test_ScheduleType_Values;
    [Test]
    procedure Test_FileChangeType_Values;
  end;

  // ============================================================================
  // Top20 #15 / E4: 恢复链必须前置 VerifyBackup，校验失败即阻断恢复
  // ============================================================================
  [TestFixture]
  TTestRestoreChainVerification = class
  private
    FSrcDir: string;
    FBakDir: string;
    FManager: TCloudBackupManager;
    FBackupId: string;
    FRestoreEventCount: Integer;
    FRestoreSuccess: Boolean;
    FRestoreError: string;
    // TRestoreCompleteEvent 是 of object 事件，只能绑对象方法；
    // InternalRestore 失败路径吞异常转事件，事件是唯一可观察出口
    procedure HandleRestoreComplete(Sender: TObject; Success: Boolean;
      const ErrorMsg: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_FreshBackup_VerifiesTrue;

    [Test]
    procedure Test_TamperedManifest_BlocksRestore;
  end;

  // ============================================================================
  // Top20 #06 / R5-N1: ABackupId 路径遍历——一切消费点经 SafeBackupId 单一校验入口，
  // 非法 id fail-closed 拒绝；`.`/`..` 等点段本身不在白名单字符集内，因此在第一道闸即被拒，
  // 拼接后的根前缀二次防御则由未受信的扩展名参数实证可达（id 与 extension 拼接面整体受根约束）。
  // ============================================================================
  [TestFixture]
  TTestBackupIdPathTraversal = class
  private
    FBakDir: string;
    procedure AssertRejectedId(const ABadId: string);
    function NewBakDir: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Negative_MalformedIds_AllRejected;
    [Test]
    procedure Test_Negative_DotSegmentsAndEscapingExtension;
    [Test]
    procedure Test_Negative_EmptyId_Rejected;
    [Test]
    procedure Test_Negative_PoisonedVersionsJson_FailClosed;
    [Test]
    procedure Test_Negative_SyncFromCloudPoisonedId_RejectedAtEntry;
    [Test]
    procedure Test_Positive_LegitimateIds_PassAndStayUnderRoot;
    [Test]
    procedure Test_Positive_FullFlow_NoRegression;
  end;

  /// <summary>
  /// R7-P1 回归覆盖：非加密归档落盘在目标已存在时必须能覆盖。
  /// TFile.Move 对已存在目标抛 ERROR_ALREADY_EXISTS，同 LBackupId
  /// 二次备份曾因此直接失败；修法为 delete-then-move 守卫。
  ///
  /// 固定 ID 子类：GenerateBackupId 每次由时间戳+MD5 生成，公开 API
  /// 下两次备份必然拿到不同 ID，覆盖分支无从触发。父类
  /// GenerateBackupId 已声明 virtual，子类 override 固定 ID，
  /// 走公开 BackupFull 真跑缺陷路径。
  /// </summary>
  TFixedIdBackupManager = class(TCloudBackupManager)
  public
    function GenerateBackupId: string; override;
  end;

  [TestFixture]
  TTestBackupArchiveOverwrite = class
  private
    FSrcDir: string;
    FBakDir: string;
    FRestoreEventCount: Integer;
    FRestoreSuccess: Boolean;
    FRestoreError: string;
    // TRestoreCompleteEvent 是 of object 事件，只能绑对象方法；
    // 失败路径吞异常转事件，事件是唯一可观察出口
    procedure HandleRestoreComplete(Sender: TObject; Success: Boolean;
      const ErrorMsg: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_SameIdSecondBackup_Succeeds;
    [Test]
    procedure Test_SameIdSecondBackup_ArchiveStaysReadable;
  end;

  /// <summary>
  /// T4 回归覆盖（WO-20260919-AUDIT-乙-R2 E7）：含 string 托管字段的
  /// TNetHeaders 组装必须逐元素赋值；若回退为 Move 裸拷贝，重复构建用例
  /// 会在释放阶段 double-free/AV。
  /// </summary>
  [TestFixture]
  TTestBuildRequestHeaders = class
  public
    [Test]
    procedure Test_DefaultsOnly;
    [Test]
    procedure Test_MergesExtraHeaders;
    [Test]
    procedure Test_RepeatedBuild_ManagedCopySafe;
  end;

implementation

{ TTestBackupFileInfo }

procedure TTestBackupFileInfo.Test_Create;
var
  Info: TBackupFileInfo;
begin
  Info := TBackupFileInfo.Create('test/file.txt', 1024, Now, 'abc123');
  
  Assert.AreEqual('test/file.txt', Info.RelativePath);
  Assert.AreEqual(Int64(1024), Info.FileSize);
  Assert.AreEqual('abc123', Info.Checksum);
end;

procedure TTestBackupFileInfo.Test_ToJSON;
var
  Info: TBackupFileInfo;
  JSON: TJSONObject;
begin
  Info := TBackupFileInfo.Create('data/config.json', 512, Now, 'sha256hash');
  JSON := Info.ToJSON;
  try
    Assert.IsNotNull(JSON);
    Assert.AreEqual('data/config.json', JSON.GetValue<string>('relativePath'));
    Assert.AreEqual(512, JSON.GetValue<Integer>('fileSize'));
    Assert.AreEqual('sha256hash', JSON.GetValue<string>('checksum'));
  finally
    JSON.Free;
  end;
end;

procedure TTestBackupFileInfo.Test_FromJSON;
var
  JSON: TJSONObject;
  Info: TBackupFileInfo;
begin
  JSON := TJSONObject.Create;
  try
    JSON.AddPair('relativePath', 'logs/app.log');
    JSON.AddPair('fileSize', TJSONNumber.Create(2048));
    JSON.AddPair('checksum', 'checksum123');
    JSON.AddPair('modifiedTime', FloatToStr(Now));
    JSON.AddPair('changeType', TJSONNumber.Create(Ord(fctModified)));
    
    Info := TBackupFileInfo.FromJSON(JSON);
    Assert.AreEqual('logs/app.log', Info.RelativePath);
    Assert.AreEqual(Int64(2048), Info.FileSize);
    Assert.AreEqual('checksum123', Info.Checksum);
  finally
    JSON.Free;
  end;
end;

procedure TTestBackupFileInfo.Test_RoundTrip;
var
  Original, Restored: TBackupFileInfo;
  JSON: TJSONObject;
begin
  Original := TBackupFileInfo.Create('backup/data.db', 4096, Now, 'sha256test');
  Original.ChangeType := fctAdded;
  
  JSON := Original.ToJSON;
  try
    Restored := TBackupFileInfo.FromJSON(JSON);
    Assert.AreEqual(Original.RelativePath, Restored.RelativePath);
    Assert.AreEqual(Original.FileSize, Restored.FileSize);
    Assert.AreEqual(Original.Checksum, Restored.Checksum);
  finally
    JSON.Free;
  end;
end;

{ TTestBackupManifest }

procedure TTestBackupManifest.Setup;
begin
  FManifest := TBackupManifest.Create;
end;

procedure TTestBackupManifest.TearDown;
begin
  FManifest.Free;
end;

procedure TTestBackupManifest.Test_Create_Defaults;
begin
  Assert.IsNotNull(FManifest.Files);
  Assert.AreEqual(Integer(0), Integer(FManifest.Files.Count));
  Assert.IsNotNull(FManifest.Tags);
end;

procedure TTestBackupManifest.Test_AddFile;
var
  FileInfo: TBackupFileInfo;
begin
  FileInfo := TBackupFileInfo.Create('test.txt', 100, Now, 'hash1');
  FManifest.AddFile(FileInfo);
  
  Assert.AreEqual(Integer(1), Integer(FManifest.Files.Count));
  Assert.AreEqual('test.txt', FManifest.Files[0].RelativePath);
end;

procedure TTestBackupManifest.Test_AddFile_Multiple;
begin
  FManifest.AddFile(TBackupFileInfo.Create('file1.txt', 100, Now, 'h1'));
  FManifest.AddFile(TBackupFileInfo.Create('file2.txt', 200, Now, 'h2'));
  FManifest.AddFile(TBackupFileInfo.Create('file3.txt', 300, Now, 'h3'));
  
  Assert.AreEqual(Integer(3), Integer(FManifest.Files.Count));
end;

procedure TTestBackupManifest.Test_RemoveFile;
begin
  FManifest.AddFile(TBackupFileInfo.Create('keep.txt', 100, Now, 'h1'));
  FManifest.AddFile(TBackupFileInfo.Create('remove.txt', 200, Now, 'h2'));
  
  FManifest.RemoveFile('remove.txt');
  
  Assert.AreEqual(Integer(1), Integer(FManifest.Files.Count));
  Assert.AreEqual('keep.txt', FManifest.Files[0].RelativePath);
end;

procedure TTestBackupManifest.Test_FindFile_Exists;
var
  Index: Integer;
begin
  FManifest.AddFile(TBackupFileInfo.Create('first.txt', 100, Now, 'h1'));
  FManifest.AddFile(TBackupFileInfo.Create('second.txt', 200, Now, 'h2'));
  
  Index := FManifest.FindFile('second.txt');
  Assert.AreEqual(1, Index);
end;

procedure TTestBackupManifest.Test_FindFile_NotExists;
var
  Index: Integer;
begin
  FManifest.AddFile(TBackupFileInfo.Create('existing.txt', 100, Now, 'h1'));
  
  Index := FManifest.FindFile('notfound.txt');
  Assert.AreEqual(-1, Index);
end;

procedure TTestBackupManifest.Test_ToJSON;
var
  JSON: TJSONObject;
begin
  FManifest.BackupId := 'backup-001';
  FManifest.BackupType := btFull;
  FManifest.Description := 'Test backup';
  FManifest.AddFile(TBackupFileInfo.Create('test.txt', 100, Now, 'hash'));
  
  JSON := FManifest.ToJSON;
  try
    Assert.IsNotNull(JSON);
    Assert.AreEqual('backup-001', JSON.GetValue<string>('backupId'));
    Assert.AreEqual('Test backup', JSON.GetValue<string>('description'));
  finally
    JSON.Free;
  end;
end;

procedure TTestBackupManifest.Test_FromJSON;
var
  JSON: TJSONObject;
  FilesArray: TJSONArray;
  FileJSON: TJSONObject;
  Manifest: TBackupManifest;
begin
  JSON := TJSONObject.Create;
  try
    JSON.AddPair('backupId', 'test-backup');
    JSON.AddPair('backupType', TJSONNumber.Create(Ord(btIncremental)));
    JSON.AddPair('description', 'Incremental backup');
    JSON.AddPair('createdAt', FloatToStr(Now));
    JSON.AddPair('basePath', 'C:\Data');
    JSON.AddPair('totalSize', TJSONNumber.Create(10000));
    JSON.AddPair('compressedSize', TJSONNumber.Create(5000));
    JSON.AddPair('fileCount', TJSONNumber.Create(5));
    
    FilesArray := TJSONArray.Create;
    FileJSON := TJSONObject.Create;
    FileJSON.AddPair('relativePath', 'data.db');
    FileJSON.AddPair('fileSize', TJSONNumber.Create(1000));
    FileJSON.AddPair('checksum', 'abc');
    FileJSON.AddPair('modifiedTime', FloatToStr(Now));
    FileJSON.AddPair('changeType', TJSONNumber.Create(0));
    FilesArray.Add(FileJSON);
    JSON.AddPair('files', FilesArray);
    
    Manifest := TBackupManifest.FromJSON(JSON);
    try
      Assert.AreEqual('test-backup', Manifest.BackupId);
      Assert.AreEqual(btIncremental, Manifest.BackupType);
      Assert.AreEqual('Incremental backup', Manifest.Description);
    finally
      Manifest.Free;
    end;
  finally
    JSON.Free;
  end;
end;

procedure TTestBackupManifest.Test_Properties;
begin
  FManifest.BackupId := 'id-123';
  FManifest.BackupType := btDifferential;
  FManifest.BasePath := 'C:\Backups';
  FManifest.TotalSize := 1000000;
  FManifest.CompressedSize := 500000;
  FManifest.FileCount := 42;
  FManifest.ParentBackupId := 'parent-001';
  FManifest.Description := 'Daily backup';
  
  Assert.AreEqual('id-123', FManifest.BackupId);
  Assert.AreEqual(btDifferential, FManifest.BackupType);
  Assert.AreEqual('C:\Backups', FManifest.BasePath);
  Assert.AreEqual(Int64(1000000), FManifest.TotalSize);
  Assert.AreEqual(Int64(500000), FManifest.CompressedSize);
  Assert.AreEqual(42, FManifest.FileCount);
  Assert.AreEqual('parent-001', FManifest.ParentBackupId);
  Assert.AreEqual('Daily backup', FManifest.Description);
end;

procedure TTestBackupManifest.Test_Tags;
begin
  FManifest.Tags.Add('production');
  FManifest.Tags.Add('critical');
  FManifest.Tags.Add('database');
  
  Assert.AreEqual(Integer(3), Integer(FManifest.Tags.Count));
  Assert.AreEqual('production', FManifest.Tags[0]);
  Assert.AreEqual('critical', FManifest.Tags[1]);
  Assert.AreEqual('database', FManifest.Tags[2]);
end;

{ TTestBackupVersion }

procedure TTestBackupVersion.Setup;
begin
  FVersion := TBackupVersion.Create;
end;

procedure TTestBackupVersion.TearDown;
begin
  FVersion.Free;
end;

procedure TTestBackupVersion.Test_Properties;
begin
  FVersion.BackupId := 'ver-001';
  FVersion.BackupType := btFull;
  FVersion.CreatedAt := Now;
  FVersion.FileCount := 100;
  FVersion.TotalSize := 50000;
  FVersion.CompressedSize := 25000;
  FVersion.Description := 'Full backup v1';
  FVersion.IsLocal := True;
  FVersion.IsCloud := True;
  FVersion.ParentBackupId := '';
  
  Assert.AreEqual('ver-001', FVersion.BackupId);
  Assert.AreEqual(btFull, FVersion.BackupType);
  Assert.AreEqual(100, FVersion.FileCount);
  Assert.AreEqual(Int64(50000), FVersion.TotalSize);
  Assert.AreEqual(Int64(25000), FVersion.CompressedSize);
  Assert.AreEqual('Full backup v1', FVersion.Description);
  Assert.IsTrue(FVersion.IsLocal);
  Assert.IsTrue(FVersion.IsCloud);
end;

procedure TTestBackupVersion.Test_ToJSON;
var
  JSON: TJSONObject;
begin
  FVersion.BackupId := 'json-test';
  FVersion.BackupType := btIncremental;
  FVersion.FileCount := 10;
  
  JSON := FVersion.ToJSON;
  try
    Assert.IsNotNull(JSON);
    Assert.AreEqual('json-test', JSON.GetValue<string>('backupId'));
    Assert.AreEqual(10, JSON.GetValue<Integer>('fileCount'));
  finally
    JSON.Free;
  end;
end;

procedure TTestBackupVersion.Test_FromJSON;
var
  JSON: TJSONObject;
  Version: TBackupVersion;
begin
  JSON := TJSONObject.Create;
  try
    JSON.AddPair('backupId', 'from-json');
    JSON.AddPair('backupType', TJSONNumber.Create(Ord(btFull)));
    JSON.AddPair('fileCount', TJSONNumber.Create(50));
    JSON.AddPair('totalSize', TJSONNumber.Create(100000));
    JSON.AddPair('compressedSize', TJSONNumber.Create(40000));
    JSON.AddPair('description', 'From JSON test');
    JSON.AddPair('isLocal', TJSONBool.Create(True));
    JSON.AddPair('isCloud', TJSONBool.Create(False));
    JSON.AddPair('createdAt', FloatToStr(Now));
    
    Version := TBackupVersion.FromJSON(JSON);
    try
      Assert.AreEqual('from-json', Version.BackupId);
      Assert.AreEqual(50, Version.FileCount);
      Assert.IsTrue(Version.IsLocal);
      Assert.IsFalse(Version.IsCloud);
    finally
      Version.Free;
    end;
  finally
    JSON.Free;
  end;
end;

procedure TTestBackupVersion.Test_RoundTrip;
var
  JSON: TJSONObject;
  Restored: TBackupVersion;
begin
  FVersion.BackupId := 'roundtrip';
  FVersion.BackupType := btDifferential;
  FVersion.FileCount := 25;
  FVersion.TotalSize := 75000;
  FVersion.CompressedSize := 30000;
  FVersion.Description := 'Roundtrip test';
  FVersion.IsLocal := True;
  FVersion.IsCloud := True;
  
  JSON := FVersion.ToJSON;
  try
    Restored := TBackupVersion.FromJSON(JSON);
    try
      Assert.AreEqual(FVersion.BackupId, Restored.BackupId);
      Assert.AreEqual(FVersion.BackupType, Restored.BackupType);
      Assert.AreEqual(FVersion.FileCount, Restored.FileCount);
      Assert.AreEqual(FVersion.TotalSize, Restored.TotalSize);
    finally
      Restored.Free;
    end;
  finally
    JSON.Free;
  end;
end;

{ TTestBackupProgress }

procedure TTestBackupProgress.Test_ProgressPercent_Zero;
var
  Progress: TBackupProgress;
begin
  Progress := Default(TBackupProgress);
  Progress.TotalBytes := 0;
  Progress.ProcessedBytes := 0;
  
  Assert.AreEqual(0, Progress.ProgressPercent);
end;

procedure TTestBackupProgress.Test_ProgressPercent_Partial;
var
  Progress: TBackupProgress;
begin
  Progress := Default(TBackupProgress);
  Progress.TotalBytes := 1000;
  Progress.ProcessedBytes := 500;
  
  Assert.AreEqual(50, Progress.ProgressPercent);
end;

procedure TTestBackupProgress.Test_ProgressPercent_Complete;
var
  Progress: TBackupProgress;
begin
  Progress := Default(TBackupProgress);
  Progress.TotalBytes := 1000;
  Progress.ProcessedBytes := 1000;
  
  Assert.AreEqual(100, Progress.ProgressPercent);
end;

procedure TTestBackupProgress.Test_FormattedProgress;
var
  Progress: TBackupProgress;
  Formatted: string;
begin
  Progress := Default(TBackupProgress);
  Progress.TotalFiles := 100;
  Progress.ProcessedFiles := 50;
  Progress.TotalBytes := 10000;
  Progress.ProcessedBytes := 5000;
  Progress.CurrentFile := 'test.txt';
  
  Formatted := Progress.FormattedProgress;
  Assert.IsNotEmpty(Formatted);
end;

procedure TTestBackupProgress.Test_Status_Values;
var
  Progress: TBackupProgress;
begin
  Progress := Default(TBackupProgress);
  Progress.Status := bsIdle;
  Assert.AreEqual(bsIdle, Progress.Status);
  
  Progress.Status := bsUploading;
  Assert.AreEqual(bsUploading, Progress.Status);
  
  Progress.Status := bsCompleted;
  Assert.AreEqual(bsCompleted, Progress.Status);
  
  Progress.Status := bsError;
  Assert.AreEqual(bsError, Progress.Status);
end;

{ TTestBackupConfig }

procedure TTestBackupConfig.Test_Default_Values;
var
  Config: TBackupConfig;
begin
  Config := TBackupConfig.Default;
  
  Assert.IsNotEmpty(Config.LocalBackupPath);
  Assert.IsFalse(Config.EnableEncryption);
end;

procedure TTestBackupConfig.Test_Default_CompressionLevel;
var
  Config: TBackupConfig;
begin
  Config := TBackupConfig.Default;
  
  Assert.AreEqual(clNormal, Config.CompressionLevel);
end;

procedure TTestBackupConfig.Test_Default_MaxVersions;
var
  Config: TBackupConfig;
begin
  Config := TBackupConfig.Default;
  
  Assert.IsTrue(Config.MaxVersionsToKeep > 0);
end;

procedure TTestBackupConfig.Test_SourcePaths;
var
  Config: TBackupConfig;
begin
  SetLength(Config.SourcePaths, 3);
  Config.SourcePaths[0] := 'C:\Data';
  Config.SourcePaths[1] := 'C:\Config';
  Config.SourcePaths[2] := 'C:\Logs';
  
  Assert.AreEqual(Integer(3), Integer(Length(Config.SourcePaths)));
  Assert.AreEqual('C:\Data', Config.SourcePaths[0]);
end;

procedure TTestBackupConfig.Test_ExcludePatterns;
var
  Config: TBackupConfig;
begin
  SetLength(Config.ExcludePatterns, 2);
  Config.ExcludePatterns[0] := '*.tmp';
  Config.ExcludePatterns[1] := '*.bak';
  
  Assert.AreEqual(Integer(2), Integer(Length(Config.ExcludePatterns)));
  Assert.AreEqual('*.tmp', Config.ExcludePatterns[0]);
end;

{ TTestBackupStatistics }

procedure TTestBackupStatistics.Test_Fields;
var
  Stats: TBackupStatistics;
begin
  Stats.TotalBackups := 10;
  Stats.SuccessfulBackups := 9;
  Stats.FailedBackups := 1;
  Stats.TotalBytesBackedUp := 1000000;
  Stats.TotalBytesRestored := 500000;
  Stats.LastBackupTime := Now;
  Stats.LastRestoreTime := Now - 1;
  
  Assert.AreEqual(10, Stats.TotalBackups);
  Assert.AreEqual(9, Stats.SuccessfulBackups);
  Assert.AreEqual(1, Stats.FailedBackups);
  Assert.AreEqual(Int64(1000000), Stats.TotalBytesBackedUp);
  Assert.AreEqual(Int64(500000), Stats.TotalBytesRestored);
end;

procedure TTestBackupStatistics.Test_Default_Values;
var
  Stats: TBackupStatistics;
begin
  FillChar(Stats, SizeOf(Stats), 0);
  
  Assert.AreEqual(0, Stats.TotalBackups);
  Assert.AreEqual(0, Stats.SuccessfulBackups);
  Assert.AreEqual(0, Stats.FailedBackups);
end;

{ TTestBackupEnums }

procedure TTestBackupEnums.Test_BackupStatus_Values;
begin
  Assert.AreEqual(0, Ord(bsIdle));
  Assert.AreEqual(1, Ord(bsPreparing));
  Assert.AreEqual(4, Ord(bsUploading));
  Assert.AreEqual(9, Ord(bsCompleted));
  Assert.AreEqual(10, Ord(bsError));
end;

procedure TTestBackupEnums.Test_BackupType_Values;
begin
  Assert.AreEqual(0, Ord(btFull));
  Assert.AreEqual(1, Ord(btIncremental));
  Assert.AreEqual(2, Ord(btDifferential));
end;

procedure TTestBackupEnums.Test_CompressionLevel_Values;
begin
  Assert.AreEqual(0, Ord(clNone));
  Assert.AreEqual(1, Ord(clFast));
  Assert.AreEqual(2, Ord(clNormal));
  Assert.AreEqual(3, Ord(clMax));
end;

procedure TTestBackupEnums.Test_ScheduleType_Values;
begin
  Assert.AreEqual(0, Ord(stNone));
  Assert.AreEqual(1, Ord(stHourly));
  Assert.AreEqual(2, Ord(stDaily));
  Assert.AreEqual(3, Ord(stWeekly));
  Assert.AreEqual(4, Ord(stMonthly));
end;

procedure TTestBackupEnums.Test_FileChangeType_Values;
begin
  Assert.AreEqual(0, Ord(fctAdded));
  Assert.AreEqual(1, Ord(fctModified));
  Assert.AreEqual(2, Ord(fctDeleted));
end;

{ TTestRestoreChainVerification }

procedure TTestRestoreChainVerification.Setup;
var
  LCfg: TBackupConfig;
begin
  FSrcDir := TPath.Combine(TPath.GetTempPath, 'e4_src_' + TGUID.NewGuid.ToString);
  FBakDir := TPath.Combine(TPath.GetTempPath, 'e4_bak_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FSrcDir);
  TDirectory.CreateDirectory(FBakDir);
  TFile.WriteAllText(TPath.Combine(FSrcDir, 'data.txt'), 'E4 restore-chain fixture payload');

  LCfg := Default(TBackupConfig);
  LCfg.SourcePaths := [FSrcDir];
  LCfg.LocalBackupPath := FBakDir;
  LCfg.EnableEncryption := False;
  LCfg.MaxVersionsToKeep := 5;
  FManager := TCloudBackupManager.Create(LCfg);
  FManager.BackupFull('e4-fixture');
  Assert.AreEqual(1, Integer(FManager.GetVersions.Count), 'setup must produce exactly one local backup');
  FBackupId := FManager.GetVersions[0].BackupId;
end;

procedure TTestRestoreChainVerification.TearDown;
begin
  FreeAndNil(FManager);
  try
    TDirectory.Delete(FSrcDir, True);
    TDirectory.Delete(FBakDir, True);
  except
    // 临时目录清理失败不影响断言结果
  end;
end;

// VerifyBackup 不得恒返回失败（否则恢复链前置接入会把所有恢复都断掉）
procedure TTestRestoreChainVerification.Test_FreshBackup_VerifiesTrue;
begin
  Assert.IsTrue(FManager.VerifyBackup(FBackupId),
    'freshly created backup must pass verification');
end;

// 验收核心：篡改清单校验和 ⇒ VerifyBackup 失败 ⇒ Restore 被阻断且不写回任何文件
procedure TTestRestoreChainVerification.Test_TamperedManifest_BlocksRestore;
var
  LManifestPath: string;
  LManifest: TBackupManifest;
  LInfo: TBackupFileInfo;
  LTargetFile: string;
begin
  Assert.IsTrue(FManager.VerifyBackup(FBackupId));

  LManifestPath := TPath.Combine(FBakDir, FBackupId + '.manifest.json');
  Assert.IsTrue(TFile.Exists(LManifestPath), 'manifest must sit next to the archive');
  LManifest := TBackupManifest.LoadFromFile(LManifestPath);
  try
    Assert.IsTrue(LManifest.Files.Count > 0);
    LInfo := LManifest.Files[0];
    LInfo.Checksum := StringOfChar('0', 64);
    LManifest.Files[0] := LInfo;
    LManifest.SaveToFile(LManifestPath);
  finally
    LManifest.Free;
  end;

  Assert.IsFalse(FManager.VerifyBackup(FBackupId),
    'tampered manifest checksum must fail verification');

  // 删除源文件后尝试恢复：InternalRestore 同步路径在 VerifyBackup 失败时
  // 抛 EBackupException 阻断，被阻断则文件不得回来
  LTargetFile := TPath.Combine(FSrcDir, 'data.txt');
  TFile.Delete(LTargetFile);

  FRestoreEventCount := 0;
  FRestoreSuccess := True;
  FRestoreError := '';
  FManager.OnRestoreComplete := HandleRestoreComplete;
  FManager.Restore(FBackupId);

  Assert.AreEqual(1, FRestoreEventCount,
    'blocked restore must still report completion exactly once');
  Assert.IsFalse(FRestoreSuccess,
    'restore must be blocked when VerifyBackup fails; got success with: ' + FRestoreError);
  Assert.IsFalse(TFile.Exists(LTargetFile),
    'blocked restore must not write any file back');
end;

procedure TTestRestoreChainVerification.HandleRestoreComplete(Sender: TObject;
  Success: Boolean; const ErrorMsg: string);
begin
  Inc(FRestoreEventCount);
  FRestoreSuccess := Success;
  FRestoreError := ErrorMsg;
end;

{ TTestBackupIdPathTraversal }

procedure TTestBackupIdPathTraversal.Setup;
begin
  FBakDir := NewBakDir;
end;

procedure TTestBackupIdPathTraversal.TearDown;
begin
  try
    TDirectory.Delete(FBakDir, True);
  except
    // 临时目录清理失败不影响断言结果
  end;
end;

function TTestBackupIdPathTraversal.NewBakDir: string;
begin
  Result := TPath.Combine(TPath.GetTempPath, 'n1_bak_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(Result);
end;

// 统一断言：非法 id 在消费入口即被 EBackupInvalidIdException 拒绝，错误消息可区分（含拒绝原因）。
// 异常实例在 except 块结束时即由 RTL 释放，断言所需的类型与消息必须在块内取出。
procedure TTestBackupIdPathTraversal.AssertRejectedId(const ABadId: string);
var
  LRejected: Boolean;
  LMsg: string;
begin
  LRejected := False;
  LMsg := '';
  try
    SafeBackupId(ABadId);
  except
    on X: EBackupInvalidIdException do
    begin
      LRejected := True;
      LMsg := X.Message;
    end;
  end;
  Assert.IsTrue(LRejected, 'id must be rejected by whitelist: [' + ABadId + ']');
  Assert.IsTrue(LMsg.Contains('Invalid backup id'),
    'rejection message must be distinguishable, id=[' + ABadId + '] msg=[' + LMsg + ']');
end;

procedure TTestBackupIdPathTraversal.Test_Negative_MalformedIds_AllRejected;
begin
  Assert.IsFalse(IsValidBackupId('../..'));
  AssertRejectedId('../..');
  AssertRejectedId('../../..');
  AssertRejectedId('../../etc/passwd');
  AssertRejectedId('....//....//etc/passwd');
  AssertRejectedId('..%2f..%2fetc');
  AssertRejectedId('C:\Windows\temp\x');
  AssertRejectedId('\\server\share\x');
  AssertRejectedId('/etc/passwd');
  AssertRejectedId(#0);
  AssertRejectedId('abc' + #0 + 'def');
  AssertRejectedId(StringOfChar('a', 65));
  AssertRejectedId('backup id with spaces');
  AssertRejectedId('backup@id');
  AssertRejectedId('backup+id');
end;

// 点段 id 不在白名单字符集内 → 第一道闸即拒。二次防御经未受信的 AExtension 参数验证：
// 白名单只覆盖 id，拼接面（root/id/extension）整体仍受根前缀约束，口径同 BuildSafeDestination。
procedure TTestBackupIdPathTraversal.Test_Negative_DotSegmentsAndEscapingExtension;
begin
  Assert.IsFalse(IsValidBackupId('.'));
  Assert.IsFalse(IsValidBackupId('..'));
  Assert.WillRaise(
    procedure
    begin
      BackupFileUnderRoot(FBakDir, '..', 'zip');
    end, EBackupInvalidIdException);
  Assert.WillRaise(
    procedure
    begin
      BackupFileUnderRoot(FBakDir, '.', 'zip');
    end, EBackupInvalidIdException);
  // id 合法但扩展名带逃逸段 → 由拼接后的根前缀检查拒绝（错误类别与白名单拒绝可区分）。
  // 三级 ..：拼接式为 root/id + '.' + extension，id 后的那个点与首个 .. 合并成普通段名
  // （legit_id...），会被下一级 .. 抵消，故需三级才能跳出根目录。
  Assert.WillRaise(
    procedure
    begin
      BackupFileUnderRoot(FBakDir, 'legit_id', '..\..\..\outside\zip');
    end, EBackupException);
end;

procedure TTestBackupIdPathTraversal.Test_Negative_EmptyId_Rejected;
begin
  AssertRejectedId('');
  AssertRejectedId('   ');
  // '.' 被白名单拒绝，不进入拼接
  Assert.WillRaise(
    procedure
    begin
      BackupFileUnderRoot(FBakDir, '.', 'zip');
    end, EBackupInvalidIdException);
end;

// versions.json 被本地篡改/历史投毒写入恶意 id → 载入即 fail-closed（管理器构造抛异常）
procedure TTestBackupIdPathTraversal.Test_Negative_PoisonedVersionsJson_FailClosed;
var
  LCfg: TBackupConfig;
  LMgr: TCloudBackupManager;
begin
  TFile.WriteAllText(
    TPath.Combine(FBakDir, 'versions.json'),
    '[{"backupId":"../../../outside","fileCount":1}]');
  LCfg := Default(TBackupConfig);
  LCfg.LocalBackupPath := FBakDir;
  Assert.WillRaise(
    procedure
    begin
      LMgr := TCloudBackupManager.Create(LCfg);
      FreeAndNil(LMgr);
    end, EBackupInvalidIdException);
end;

// 云端投毒模拟：恶意 id 在 SyncFromCloud 入口即被拒，先于"云服务未配置"检查（顺序即证明）
procedure TTestBackupIdPathTraversal.Test_Negative_SyncFromCloudPoisonedId_RejectedAtEntry;
var
  LCfg: TBackupConfig;
  LMgr: TCloudBackupManager;
begin
  LCfg := Default(TBackupConfig);
  LCfg.LocalBackupPath := FBakDir;
  LMgr := TCloudBackupManager.Create(LCfg);
  try
    Assert.WillRaise(
      procedure
      begin
        LMgr.SyncFromCloud('../../../evil');
      end, EBackupInvalidIdException);
    // 对照组：合法 id 才走到云服务配置检查
    Assert.WillRaise(
      procedure
      begin
        LMgr.SyncFromCloud('backup_20260920_101500_deadbeef');
      end, ECloudServiceNotConfiguredException);
  finally
    LMgr.Free;
  end;
end;

procedure TTestBackupIdPathTraversal.Test_Positive_LegitimateIds_PassAndStayUnderRoot;
var
  LRoot: string;
  LPath: string;
  LGuidId: string;
begin
  LRoot := BackupRootPrefix(FBakDir);
  LPath := BackupFileUnderRoot(FBakDir, '20260920_101500_deadbeef', 'zip');
  Assert.IsTrue(SameText(Copy(LPath, 1, Length(LRoot)), LRoot));
  Assert.IsTrue(LPath.EndsWith('.zip'));

  LGuidId := 'b7d9f3a1-4c2e-4f6a-9d8b-1e2c3a4b5d6f';
  Assert.IsTrue(IsValidBackupId(LGuidId), 'GUID-format id must pass whitelist');
  LPath := BackupFileUnderRoot(FBakDir, LGuidId, 'manifest.json');
  Assert.IsTrue(SameText(Copy(LPath, 1, Length(LRoot)), LRoot));

  Assert.AreEqual(64, Length(SafeBackupId(StringOfChar('a', 64))), '64-char id is the whitelist boundary');
end;

// 正向全流程：创建/校验/恢复/删除不回归
procedure TTestBackupIdPathTraversal.Test_Positive_FullFlow_NoRegression;
var
  LCfg: TBackupConfig;
  LMgr: TCloudBackupManager;
  LSrcDir, LRestDir, LBackupId: string;
begin
  LSrcDir := TPath.Combine(TPath.GetTempPath, 'n1_src_' + TGUID.NewGuid.ToString);
  LRestDir := TPath.Combine(TPath.GetTempPath, 'n1_rest_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(LSrcDir);
  TFile.WriteAllText(TPath.Combine(LSrcDir, 'payload.txt'), 'N1 full-flow payload');
  try
    LCfg := Default(TBackupConfig);
    LCfg.SourcePaths := [LSrcDir];
    LCfg.LocalBackupPath := FBakDir;
    LCfg.EnableEncryption := False;
    LCfg.MaxVersionsToKeep := 5;
    LMgr := TCloudBackupManager.Create(LCfg);
    try
      LMgr.BackupFull('n1-positive');
      Assert.AreEqual(1, Integer(LMgr.GetVersions.Count));
      LBackupId := LMgr.GetVersions[0].BackupId;
      Assert.IsTrue(IsValidBackupId(LBackupId), 'generated id must satisfy whitelist');
      Assert.IsTrue(LMgr.VerifyBackup(LBackupId));

      LMgr.Restore(LBackupId, LRestDir);
      Assert.IsTrue(TFile.Exists(TPath.Combine(LRestDir, 'payload.txt')),
        'positive restore must not regress');

      LMgr.DeleteVersion(LBackupId);
      Assert.AreEqual(0, Integer(LMgr.GetVersions.Count));
      Assert.IsFalse(TFile.Exists(TPath.Combine(FBakDir, LBackupId + '.zip')));
    finally
      LMgr.Free;
    end;
  finally
    try
      TDirectory.Delete(LSrcDir, True);
      TDirectory.Delete(LRestDir, True);
    except
    end;
  end;
end;

{ TFixedIdBackupManager }

function TFixedIdBackupManager.GenerateBackupId: string;
begin
  Result := 'r7_fixed_id';
end;

{ TTestBackupArchiveOverwrite }

procedure TTestBackupArchiveOverwrite.Setup;
begin
  FSrcDir := TPath.Combine(TPath.GetTempPath, 'r7ovw_src_' + TGUID.NewGuid.ToString);
  FBakDir := TPath.Combine(TPath.GetTempPath, 'r7ovw_bak_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FSrcDir);
  TDirectory.CreateDirectory(FBakDir);
  TFile.WriteAllText(TPath.Combine(FSrcDir, 'data.txt'), 'r7 overwrite fixture payload');
  FRestoreEventCount := 0;
  FRestoreSuccess := True;
  FRestoreError := '';
end;

procedure TTestBackupArchiveOverwrite.TearDown;
begin
  try
    TDirectory.Delete(FSrcDir, True);
    TDirectory.Delete(FBakDir, True);
  except
  end;
end;

procedure TTestBackupArchiveOverwrite.Test_SameIdSecondBackup_Succeeds;
var
  LCfg: TBackupConfig;
  LManager: TFixedIdBackupManager;
  LId1, LId2: string;
  LFirstSize: Int64;
begin
  LCfg := Default(TBackupConfig);
  LCfg.SourcePaths := [FSrcDir];
  LCfg.LocalBackupPath := FBakDir;
  LCfg.EnableEncryption := False;
  LCfg.MaxVersionsToKeep := 5;

  LManager := TFixedIdBackupManager.Create(LCfg);
  try
    LManager.BackupFull('r7-overwrite');
    Assert.AreEqual(1, Integer(LManager.GetVersions.Count), 'first backup must register one version');
    LId1 := LManager.GetVersions[0].BackupId;
    LFirstSize := TFile.GetSize(BackupFileUnderRoot(FBakDir, LId1, 'zip'));
    Assert.IsTrue(LFirstSize > 0, 'first archive must be non-empty');

    // 同 LBackupId 二次备份：修前此处抛 ERROR_ALREADY_EXISTS 直接失败
    LManager.BackupFull('r7-overwrite');

    Assert.IsTrue(TFile.Exists(BackupFileUnderRoot(FBakDir, LId1, 'zip')),
      'archive for the reused backup id must still exist after second backup');
    LId2 := LManager.GetVersions[0].BackupId;
    Assert.AreEqual(LId1, LId2, 'backup id must remain stable across repeated backups');
  finally
    LManager.Free;
  end;
end;

procedure TTestBackupArchiveOverwrite.Test_SameIdSecondBackup_ArchiveStaysReadable;
var
  LCfg: TBackupConfig;
  LManager: TFixedIdBackupManager;
  LId: string;
  LRestoreDir, LTargetFile: string;
begin
  LCfg := Default(TBackupConfig);
  LCfg.SourcePaths := [FSrcDir];
  LCfg.LocalBackupPath := FBakDir;
  LCfg.EnableEncryption := False;
  LCfg.MaxVersionsToKeep := 5;

  LManager := TFixedIdBackupManager.Create(LCfg);
  try
    LManager.BackupFull('r7-verify');
    LManager.BackupFull('r7-verify');
    LId := LManager.GetVersions[0].BackupId;

    LManager.OnRestoreComplete := HandleRestoreComplete;

    LRestoreDir := TPath.Combine(TPath.GetTempPath, 'r7ovw_rst_' + TGUID.NewGuid.ToString);
    try
      LManager.Restore(LId, LRestoreDir);

      Assert.AreEqual(1, FRestoreEventCount, 'restore must report completion exactly once');
      Assert.IsTrue(FRestoreSuccess,
        'restore after overwrite must succeed; got: ' + FRestoreError);
      LTargetFile := TPath.Combine(LRestoreDir, 'data.txt');
      Assert.IsTrue(TFile.Exists(LTargetFile),
        'archive left behind by the overwrite must still be extractable');
    finally
      try
        TDirectory.Delete(LRestoreDir, True);
      except
      end;
    end;
  finally
    LManager.Free;
  end;
end;

procedure TTestBackupArchiveOverwrite.HandleRestoreComplete(Sender: TObject;
  Success: Boolean; const ErrorMsg: string);
begin
  Inc(FRestoreEventCount);
  FRestoreSuccess := Success;
  FRestoreError := ErrorMsg;
end;

procedure TTestBuildRequestHeaders.Test_DefaultsOnly;
var
  LH: TNetHeaders;
begin
  LH := TCloudBackupClient.BuildRequestHeaders('key1', 'bucket1', nil);
  Assert.AreEqual(2, Integer(Length(LH)));
  Assert.AreEqual('X-API-Key', LH[0].Name);
  Assert.AreEqual('key1', LH[0].Value);
  Assert.AreEqual('X-Bucket', LH[1].Name);
  Assert.AreEqual('bucket1', LH[1].Value);
end;

procedure TTestBuildRequestHeaders.Test_MergesExtraHeaders;
var
  LExtra, LH: TNetHeaders;
begin
  SetLength(LExtra, 2);
  LExtra[0] := TNameValuePair.Create('Content-Type', 'application/zip');
  LExtra[1] := TNameValuePair.Create('X-Backup-Id', 'bk-20260919');
  LH := TCloudBackupClient.BuildRequestHeaders('k', 'b', LExtra);
  Assert.AreEqual(4, Integer(Length(LH)));
  Assert.AreEqual('X-API-Key', LH[0].Name);
  Assert.AreEqual('Content-Type', LH[2].Name);
  Assert.AreEqual('X-Backup-Id', LH[3].Name);
  Assert.AreEqual('bk-20260919', LH[3].Value);
  // 源数组不受影响：若为 Move 裸拷贝，两侧共享字符串指针会重复释放
  Assert.AreEqual('bk-20260919', LExtra[1].Value);
end;

procedure TTestBuildRequestHeaders.Test_RepeatedBuild_ManagedCopySafe;
var
  LExtra, LH: TNetHeaders;
  I: Integer;
  LLong: string;
begin
  LLong := StringOfChar('x', 300); // 超过字符串内联缓冲，堆分配引用计数路径
  SetLength(LExtra, 3);
  LExtra[0] := TNameValuePair.Create('A', LLong);
  LExtra[1] := TNameValuePair.Create('B', 'yy');
  LExtra[2] := TNameValuePair.Create('C', 'zz');
  for I := 1 to 200 do
  begin
    LH := TCloudBackupClient.BuildRequestHeaders('key', 'bkt', LExtra);
    Assert.AreEqual(5, Integer(Length(LH)));
    Assert.AreEqual(LLong, LH[2].Value);
  end;
  // 循环内 LH 每轮重赋值会释放上一轮元素；若拷贝是 Move 裸内存，
  // 源 LExtra 字符串已悬垂，此处必 AV 或 DUnitX 报 leak。
  Assert.AreEqual(LLong, LExtra[0].Value);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestBackupFileInfo);
  TDUnitX.RegisterTestFixture(TTestBackupManifest);
  TDUnitX.RegisterTestFixture(TTestBackupVersion);
  TDUnitX.RegisterTestFixture(TTestBackupProgress);
  TDUnitX.RegisterTestFixture(TTestBackupConfig);
  TDUnitX.RegisterTestFixture(TTestBackupStatistics);
  TDUnitX.RegisterTestFixture(TTestBackupEnums);
  TDUnitX.RegisterTestFixture(TTestRestoreChainVerification);
  TDUnitX.RegisterTestFixture(TTestBackupArchiveOverwrite);
  TDUnitX.RegisterTestFixture(TTestBackupIdPathTraversal);
  TDUnitX.RegisterTestFixture(TTestBuildRequestHeaders);

end.
