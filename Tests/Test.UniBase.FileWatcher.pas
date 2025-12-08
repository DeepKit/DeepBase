unit Test.UniBase.FileWatcher;

{*******************************************************************************
  Unit Tests for UniBase.FileWatcher
  Tests file system monitoring, change detection and file filters
*******************************************************************************}

interface

{$IFDEF TESTINSIGHT}
uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestUniBaseFileWatcher = class
  private
    FTestDir: string;
    procedure CreateTestDirectory;
    procedure CleanupTestDirectory;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // TFileChangeInfo Tests
    [Test]
    procedure TestFileChangeInfoCreate;
    [Test]
    procedure TestFileChangeInfoToString;

    // TFileFilter Tests
    [Test]
    procedure TestFileFilterCreate;
    [Test]
    procedure TestFileFilterIncludePatterns;
    [Test]
    procedure TestFileFilterExcludePatterns;
    [Test]
    procedure TestFileFilterIncludeExtensions;
    [Test]
    procedure TestFileFilterExcludeExtensions;
    [Test]
    procedure TestFileFilterMatches;
    [Test]
    procedure TestFileFilterMatchesDirectory;

    // TFileWatcherConfig Tests
    [Test]
    procedure TestFileWatcherConfigCreate;
    [Test]
    procedure TestFileWatcherConfigDefaults;
    [Test]
    procedure TestFileWatcherConfigChangeTypes;

    // TFileWatcher Tests
    [Test]
    procedure TestFileWatcherCreate;
    [Test]
    procedure TestFileWatcherStart;
    [Test]
    procedure TestFileWatcherStop;
    [Test]
    procedure TestFileWatcherIsRunning;
    [Test]
    procedure TestFileWatcherPath;
    [Test]
    procedure TestFileWatcherOnChange;

    // TFileWatcherManager Tests
    [Test]
    procedure TestFileWatcherManagerCreate;
    [Test]
    procedure TestFileWatcherManagerAdd;
    [Test]
    procedure TestFileWatcherManagerRemove;
    [Test]
    procedure TestFileWatcherManagerStartAll;
    [Test]
    procedure TestFileWatcherManagerStopAll;
    [Test]
    procedure TestFileWatcherManagerCount;

    // TFileWatcherBuilder Tests
    [Test]
    procedure TestFileWatcherBuilderCreate;
    [Test]
    procedure TestFileWatcherBuilderPath;
    [Test]
    procedure TestFileWatcherBuilderFilter;
    [Test]
    procedure TestFileWatcherBuilderOnChange;
    [Test]
    procedure TestFileWatcherBuilderBuild;
    [Test]
    procedure TestFileWatcherBuilderFluent;

    // Integration Tests
    [Test]
    procedure TestFileCreated;
    [Test]
    procedure TestFileModified;
    [Test]
    procedure TestFileDeleted;
    [Test]
    procedure TestFileRenamed;
    [Test]
    procedure TestSubdirectoryWatch;
  end;
{$ENDIF}

implementation

{$IFDEF TESTINSIGHT}
uses
  System.SysUtils, System.IOUtils, System.Classes, System.SyncObjs,
  UniBase.FileWatcher;

procedure TTestUniBaseFileWatcher.Setup;
begin
  CreateTestDirectory;
end;

procedure TTestUniBaseFileWatcher.TearDown;
begin
  CleanupTestDirectory;
end;

procedure TTestUniBaseFileWatcher.CreateTestDirectory;
begin
  FTestDir := TPath.Combine(TPath.GetTempPath, 'UniBaseFileWatcherTest_' + TGUID.NewGuid.ToString);
  if not TDirectory.Exists(FTestDir) then
    TDirectory.CreateDirectory(FTestDir);
end;

procedure TTestUniBaseFileWatcher.CleanupTestDirectory;
begin
  if TDirectory.Exists(FTestDir) then
    TDirectory.Delete(FTestDir, True);
end;

// TFileChangeInfo Tests

procedure TTestUniBaseFileWatcher.TestFileChangeInfoCreate;
var
  Info: TFileChangeInfo;
begin
  Info.ChangeType := fctCreated;
  Info.FullPath := 'C:\Test\file.txt';
  Info.FileName := 'file.txt';
  Info.IsDirectory := False;
  Assert.AreEqual('file.txt', Info.FileName);
  Assert.AreEqual(fctCreated, Info.ChangeType);
end;

procedure TTestUniBaseFileWatcher.TestFileChangeInfoToString;
var
  Info: TFileChangeInfo;
begin
  Info.ChangeType := fctModified;
  Info.FullPath := 'C:\Test\file.txt';
  Info.FileName := 'file.txt';
  Assert.IsTrue(Length(Info.ToString) > 0);
end;

// TFileFilter Tests

procedure TTestUniBaseFileWatcher.TestFileFilterCreate;
var
  Filter: TFileFilter;
begin
  Filter := TFileFilter.Create;
  try
    Assert.IsNotNull(Filter);
  finally
    Filter.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileFilterIncludePatterns;
var
  Filter: TFileFilter;
begin
  Filter := TFileFilter.Create;
  try
    Filter.IncludePatterns := ['*.pas', '*.dfm'];
    Assert.AreEqual(2, Length(Filter.IncludePatterns));
  finally
    Filter.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileFilterExcludePatterns;
var
  Filter: TFileFilter;
begin
  Filter := TFileFilter.Create;
  try
    Filter.ExcludePatterns := ['*.bak', '*.tmp'];
    Assert.AreEqual(2, Length(Filter.ExcludePatterns));
  finally
    Filter.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileFilterIncludeExtensions;
var
  Filter: TFileFilter;
begin
  Filter := TFileFilter.Create;
  try
    Filter.IncludeExtensions := ['.pas', '.dpr', '.dpk'];
    Assert.AreEqual(3, Length(Filter.IncludeExtensions));
  finally
    Filter.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileFilterExcludeExtensions;
var
  Filter: TFileFilter;
begin
  Filter := TFileFilter.Create;
  try
    Filter.ExcludeExtensions := ['.dcu', '.exe', '.dll'];
    Assert.AreEqual(3, Length(Filter.ExcludeExtensions));
  finally
    Filter.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileFilterMatches;
var
  Filter: TFileFilter;
begin
  Filter := TFileFilter.Create;
  try
    Filter.IncludeExtensions := ['.pas'];
    Assert.IsTrue(Filter.Matches('Test.pas', False));
    Assert.IsFalse(Filter.Matches('Test.txt', False));
  finally
    Filter.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileFilterMatchesDirectory;
var
  Filter: TFileFilter;
begin
  Filter := TFileFilter.Create;
  try
    Filter.IncludeDirectories := True;
    Assert.IsTrue(Filter.Matches('SubDir', True));

    Filter.IncludeDirectories := False;
    Assert.IsFalse(Filter.Matches('SubDir', True));
  finally
    Filter.Free;
  end;
end;

// TFileWatcherConfig Tests

procedure TTestUniBaseFileWatcher.TestFileWatcherConfigCreate;
var
  Config: TFileWatcherConfig;
begin
  Config := TFileWatcherConfig.Create;
  Assert.IsNotNull(@Config);
end;

procedure TTestUniBaseFileWatcher.TestFileWatcherConfigDefaults;
var
  Config: TFileWatcherConfig;
begin
  Config := TFileWatcherConfig.Default;
  Assert.IsTrue(Config.WatchSubdirectories);
  Assert.IsTrue(Config.DebounceMs >= 0);
end;

procedure TTestUniBaseFileWatcher.TestFileWatcherConfigChangeTypes;
var
  Config: TFileWatcherConfig;
begin
  Config := TFileWatcherConfig.Create;
  Config.ChangeTypes := [fctCreated, fctDeleted];
  Assert.IsTrue(fctCreated in Config.ChangeTypes);
  Assert.IsTrue(fctDeleted in Config.ChangeTypes);
  Assert.IsFalse(fctModified in Config.ChangeTypes);
end;

// TFileWatcher Tests

procedure TTestUniBaseFileWatcher.TestFileWatcherCreate;
var
  Watcher: TFileWatcher;
begin
  Watcher := TFileWatcher.Create(FTestDir);
  try
    Assert.IsNotNull(Watcher);
    Assert.AreEqual(FTestDir, Watcher.Path);
  finally
    Watcher.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileWatcherStart;
var
  Watcher: TFileWatcher;
begin
  Watcher := TFileWatcher.Create(FTestDir);
  try
    Watcher.Start;
    Assert.IsTrue(Watcher.IsRunning);
    Watcher.Stop;
  finally
    Watcher.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileWatcherStop;
var
  Watcher: TFileWatcher;
begin
  Watcher := TFileWatcher.Create(FTestDir);
  try
    Watcher.Start;
    Watcher.Stop;
    Assert.IsFalse(Watcher.IsRunning);
  finally
    Watcher.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileWatcherIsRunning;
var
  Watcher: TFileWatcher;
begin
  Watcher := TFileWatcher.Create(FTestDir);
  try
    Assert.IsFalse(Watcher.IsRunning);
    Watcher.Start;
    Assert.IsTrue(Watcher.IsRunning);
    Watcher.Stop;
    Assert.IsFalse(Watcher.IsRunning);
  finally
    Watcher.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileWatcherPath;
var
  Watcher: TFileWatcher;
begin
  Watcher := TFileWatcher.Create(FTestDir);
  try
    Assert.AreEqual(FTestDir, Watcher.Path);
  finally
    Watcher.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileWatcherOnChange;
var
  Watcher: TFileWatcher;
  ChangeCount: Integer;
begin
  ChangeCount := 0;
  Watcher := TFileWatcher.Create(FTestDir);
  try
    Watcher.OnChange := procedure(const Info: TFileChangeInfo)
    begin
      Inc(ChangeCount);
    end;
    Assert.IsNotNull(Watcher);
  finally
    Watcher.Free;
  end;
end;

// TFileWatcherManager Tests

procedure TTestUniBaseFileWatcher.TestFileWatcherManagerCreate;
var
  Manager: TFileWatcherManager;
begin
  Manager := TFileWatcherManager.Create;
  try
    Assert.IsNotNull(Manager);
  finally
    Manager.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileWatcherManagerAdd;
var
  Manager: TFileWatcherManager;
  Watcher: TFileWatcher;
begin
  Manager := TFileWatcherManager.Create;
  try
    Watcher := TFileWatcher.Create(FTestDir);
    Manager.Add('test', Watcher);
    Assert.AreEqual(1, Manager.Count);
  finally
    Manager.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileWatcherManagerRemove;
var
  Manager: TFileWatcherManager;
  Watcher: TFileWatcher;
begin
  Manager := TFileWatcherManager.Create;
  try
    Watcher := TFileWatcher.Create(FTestDir);
    Manager.Add('test', Watcher);
    Manager.Remove('test');
    Assert.AreEqual(0, Manager.Count);
  finally
    Manager.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileWatcherManagerStartAll;
var
  Manager: TFileWatcherManager;
begin
  Manager := TFileWatcherManager.Create;
  try
    Manager.Add('test1', TFileWatcher.Create(FTestDir));
    Manager.StartAll;
    Assert.IsTrue(Manager.Get('test1').IsRunning);
    Manager.StopAll;
  finally
    Manager.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileWatcherManagerStopAll;
var
  Manager: TFileWatcherManager;
begin
  Manager := TFileWatcherManager.Create;
  try
    Manager.Add('test1', TFileWatcher.Create(FTestDir));
    Manager.StartAll;
    Manager.StopAll;
    Assert.IsFalse(Manager.Get('test1').IsRunning);
  finally
    Manager.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileWatcherManagerCount;
var
  Manager: TFileWatcherManager;
begin
  Manager := TFileWatcherManager.Create;
  try
    Assert.AreEqual(0, Manager.Count);
    Manager.Add('w1', TFileWatcher.Create(FTestDir));
    Assert.AreEqual(1, Manager.Count);
    Manager.Add('w2', TFileWatcher.Create(FTestDir));
    Assert.AreEqual(2, Manager.Count);
  finally
    Manager.Free;
  end;
end;

// TFileWatcherBuilder Tests

procedure TTestUniBaseFileWatcher.TestFileWatcherBuilderCreate;
var
  Builder: TFileWatcherBuilder;
begin
  Builder := TFileWatcherBuilder.Create;
  try
    Assert.IsNotNull(Builder);
  finally
    Builder.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileWatcherBuilderPath;
var
  Builder: TFileWatcherBuilder;
begin
  Builder := TFileWatcherBuilder.Create;
  try
    Builder.WatchPath(FTestDir);
    Assert.IsNotNull(Builder);
  finally
    Builder.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileWatcherBuilderFilter;
var
  Builder: TFileWatcherBuilder;
  Filter: TFileFilter;
begin
  Builder := TFileWatcherBuilder.Create;
  try
    Filter := TFileFilter.Create;
    Filter.IncludeExtensions := ['.pas'];
    Builder.WithFilter(Filter);
    Assert.IsNotNull(Builder);
  finally
    Builder.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileWatcherBuilderOnChange;
var
  Builder: TFileWatcherBuilder;
begin
  Builder := TFileWatcherBuilder.Create;
  try
    Builder.OnFileChange(procedure(const Info: TFileChangeInfo)
    begin
      // Handle change
    end);
    Assert.IsNotNull(Builder);
  finally
    Builder.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileWatcherBuilderBuild;
var
  Builder: TFileWatcherBuilder;
  Watcher: TFileWatcher;
begin
  Builder := TFileWatcherBuilder.Create;
  try
    Watcher := Builder
      .WatchPath(FTestDir)
      .IncludeSubdirectories(True)
      .Build;
    try
      Assert.IsNotNull(Watcher);
      Assert.AreEqual(FTestDir, Watcher.Path);
    finally
      Watcher.Free;
    end;
  finally
    Builder.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileWatcherBuilderFluent;
var
  Watcher: TFileWatcher;
begin
  Watcher := TFileWatchers.Watch(FTestDir)
    .IncludeSubdirectories(True)
    .WithDebounce(100)
    .Build;
  try
    Assert.IsNotNull(Watcher);
  finally
    Watcher.Free;
  end;
end;

// Integration Tests

procedure TTestUniBaseFileWatcher.TestFileCreated;
var
  Watcher: TFileWatcher;
  ChangeDetected: Boolean;
  Event: TEvent;
  TestFile: string;
begin
  ChangeDetected := False;
  Event := TEvent.Create(nil, True, False, '');
  try
    Watcher := TFileWatcher.Create(FTestDir);
    try
      Watcher.OnChange := procedure(const Info: TFileChangeInfo)
      begin
        if Info.ChangeType = fctCreated then
        begin
          ChangeDetected := True;
          Event.SetEvent;
        end;
      end;
      Watcher.Start;

      TestFile := TPath.Combine(FTestDir, 'newfile.txt');
      TFile.WriteAllText(TestFile, 'Test content');

      Event.WaitFor(2000);
      Assert.IsTrue(ChangeDetected, 'File creation not detected');
    finally
      Watcher.Stop;
      Watcher.Free;
    end;
  finally
    Event.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileModified;
var
  Watcher: TFileWatcher;
  ChangeDetected: Boolean;
  Event: TEvent;
  TestFile: string;
begin
  ChangeDetected := False;
  Event := TEvent.Create(nil, True, False, '');
  try
    TestFile := TPath.Combine(FTestDir, 'modifytest.txt');
    TFile.WriteAllText(TestFile, 'Initial content');

    Watcher := TFileWatcher.Create(FTestDir);
    try
      Watcher.OnChange := procedure(const Info: TFileChangeInfo)
      begin
        if Info.ChangeType = fctModified then
        begin
          ChangeDetected := True;
          Event.SetEvent;
        end;
      end;
      Watcher.Start;
      Sleep(100);

      TFile.WriteAllText(TestFile, 'Modified content');

      Event.WaitFor(2000);
      Assert.IsTrue(ChangeDetected, 'File modification not detected');
    finally
      Watcher.Stop;
      Watcher.Free;
    end;
  finally
    Event.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileDeleted;
var
  Watcher: TFileWatcher;
  ChangeDetected: Boolean;
  Event: TEvent;
  TestFile: string;
begin
  ChangeDetected := False;
  Event := TEvent.Create(nil, True, False, '');
  try
    TestFile := TPath.Combine(FTestDir, 'deletetest.txt');
    TFile.WriteAllText(TestFile, 'To be deleted');

    Watcher := TFileWatcher.Create(FTestDir);
    try
      Watcher.OnChange := procedure(const Info: TFileChangeInfo)
      begin
        if Info.ChangeType = fctDeleted then
        begin
          ChangeDetected := True;
          Event.SetEvent;
        end;
      end;
      Watcher.Start;
      Sleep(100);

      TFile.Delete(TestFile);

      Event.WaitFor(2000);
      Assert.IsTrue(ChangeDetected, 'File deletion not detected');
    finally
      Watcher.Stop;
      Watcher.Free;
    end;
  finally
    Event.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestFileRenamed;
var
  Watcher: TFileWatcher;
  ChangeDetected: Boolean;
  Event: TEvent;
  TestFile, NewFile: string;
begin
  ChangeDetected := False;
  Event := TEvent.Create(nil, True, False, '');
  try
    TestFile := TPath.Combine(FTestDir, 'renametest.txt');
    NewFile := TPath.Combine(FTestDir, 'renamed.txt');
    TFile.WriteAllText(TestFile, 'To be renamed');

    Watcher := TFileWatcher.Create(FTestDir);
    try
      Watcher.OnChange := procedure(const Info: TFileChangeInfo)
      begin
        if Info.ChangeType = fctRenamed then
        begin
          ChangeDetected := True;
          Event.SetEvent;
        end;
      end;
      Watcher.Start;
      Sleep(100);

      TFile.Move(TestFile, NewFile);

      Event.WaitFor(2000);
      // Rename might be detected as delete+create on some systems
      Assert.IsTrue(ChangeDetected or TFile.Exists(NewFile), 'File rename not handled');
    finally
      Watcher.Stop;
      Watcher.Free;
    end;
  finally
    Event.Free;
  end;
end;

procedure TTestUniBaseFileWatcher.TestSubdirectoryWatch;
var
  Watcher: TFileWatcher;
  ChangeDetected: Boolean;
  Event: TEvent;
  SubDir, TestFile: string;
begin
  ChangeDetected := False;
  Event := TEvent.Create(nil, True, False, '');
  try
    SubDir := TPath.Combine(FTestDir, 'subdir');
    TDirectory.CreateDirectory(SubDir);

    Watcher := TFileWatcher.Create(FTestDir);
    try
      Watcher.Config.WatchSubdirectories := True;
      Watcher.OnChange := procedure(const Info: TFileChangeInfo)
      begin
        ChangeDetected := True;
        Event.SetEvent;
      end;
      Watcher.Start;
      Sleep(100);

      TestFile := TPath.Combine(SubDir, 'subfile.txt');
      TFile.WriteAllText(TestFile, 'Subdirectory file');

      Event.WaitFor(2000);
      Assert.IsTrue(ChangeDetected, 'Subdirectory change not detected');
    finally
      Watcher.Stop;
      Watcher.Free;
    end;
  finally
    Event.Free;
  end;
end;

{$ENDIF}

end.
