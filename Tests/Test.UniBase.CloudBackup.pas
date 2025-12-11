{ ============================================================================
  Test.UniBase.CloudBackup - Unit Tests for Cloud Backup Module
  
  Test Coverage:
    - TBackupFileInfo record operations
    - TBackupManifest management
    - TBackupVersion information
    - TBackupProgress tracking
    - TBackupConfig configuration
    - TBackupStatistics tracking
  ============================================================================ }

unit Test.UniBase.CloudBackup;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  UniBase.CloudBackup;

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
  Assert.AreEqual(0, FManifest.Files.Count);
  Assert.IsNotNull(FManifest.Tags);
end;

procedure TTestBackupManifest.Test_AddFile;
var
  FileInfo: TBackupFileInfo;
begin
  FileInfo := TBackupFileInfo.Create('test.txt', 100, Now, 'hash1');
  FManifest.AddFile(FileInfo);
  
  Assert.AreEqual(1, FManifest.Files.Count);
  Assert.AreEqual('test.txt', FManifest.Files[0].RelativePath);
end;

procedure TTestBackupManifest.Test_AddFile_Multiple;
begin
  FManifest.AddFile(TBackupFileInfo.Create('file1.txt', 100, Now, 'h1'));
  FManifest.AddFile(TBackupFileInfo.Create('file2.txt', 200, Now, 'h2'));
  FManifest.AddFile(TBackupFileInfo.Create('file3.txt', 300, Now, 'h3'));
  
  Assert.AreEqual(3, FManifest.Files.Count);
end;

procedure TTestBackupManifest.Test_RemoveFile;
begin
  FManifest.AddFile(TBackupFileInfo.Create('keep.txt', 100, Now, 'h1'));
  FManifest.AddFile(TBackupFileInfo.Create('remove.txt', 200, Now, 'h2'));
  
  FManifest.RemoveFile('remove.txt');
  
  Assert.AreEqual(1, FManifest.Files.Count);
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
  
  Assert.AreEqual(3, FManifest.Tags.Count);
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
  Progress.TotalBytes := 0;
  Progress.ProcessedBytes := 0;
  
  Assert.AreEqual(0, Progress.ProgressPercent);
end;

procedure TTestBackupProgress.Test_ProgressPercent_Partial;
var
  Progress: TBackupProgress;
begin
  Progress.TotalBytes := 1000;
  Progress.ProcessedBytes := 500;
  
  Assert.AreEqual(50, Progress.ProgressPercent);
end;

procedure TTestBackupProgress.Test_ProgressPercent_Complete;
var
  Progress: TBackupProgress;
begin
  Progress.TotalBytes := 1000;
  Progress.ProcessedBytes := 1000;
  
  Assert.AreEqual(100, Progress.ProgressPercent);
end;

procedure TTestBackupProgress.Test_FormattedProgress;
var
  Progress: TBackupProgress;
  Formatted: string;
begin
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
  
  Assert.AreEqual(3, Length(Config.SourcePaths));
  Assert.AreEqual('C:\Data', Config.SourcePaths[0]);
end;

procedure TTestBackupConfig.Test_ExcludePatterns;
var
  Config: TBackupConfig;
begin
  SetLength(Config.ExcludePatterns, 2);
  Config.ExcludePatterns[0] := '*.tmp';
  Config.ExcludePatterns[1] := '*.bak';
  
  Assert.AreEqual(2, Length(Config.ExcludePatterns));
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

initialization
  TDUnitX.RegisterTestFixture(TTestBackupFileInfo);
  TDUnitX.RegisterTestFixture(TTestBackupManifest);
  TDUnitX.RegisterTestFixture(TTestBackupVersion);
  TDUnitX.RegisterTestFixture(TTestBackupProgress);
  TDUnitX.RegisterTestFixture(TTestBackupConfig);
  TDUnitX.RegisterTestFixture(TTestBackupStatistics);
  TDUnitX.RegisterTestFixture(TTestBackupEnums);

end.
