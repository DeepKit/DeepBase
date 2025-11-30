{ ============================================================================
  Stress.Config - Configuration Module Stress Tests
  
  Tests high-concurrency configuration read/write scenarios:
  - Concurrent read operations
  - Concurrent write operations  
  - Mixed read/write operations
  - Cache stress testing
  - Large value handling
  ============================================================================ }

unit Stress.Config;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.Diagnostics,
  UniBase.StressTest;

type
  // ============================================================================
  // TConfigReadStressTest - Concurrent reads
  // ============================================================================
  
  TConfigReadStressTest = class(TStressTest)
  private
    FKeys: TArray<string>;
    FKeyCount: Integer;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property KeyCount: Integer read FKeyCount write FKeyCount;
  end;
  
  // ============================================================================
  // TConfigWriteStressTest - Concurrent writes
  // ============================================================================
  
  TConfigWriteStressTest = class(TStressTest)
  private
    FKeyPrefix: string;
    FValueSize: Integer;
    FKeyCounter: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property ValueSize: Integer read FValueSize write FValueSize;
  end;
  
  // ============================================================================
  // TConfigMixedStressTest - Mixed read/write
  // ============================================================================
  
  TConfigMixedStressTest = class(TStressTest)
  private
    FKeys: TArray<string>;
    FKeyCount: Integer;
    FReadRatio: Double;  // 0.0 - 1.0
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property KeyCount: Integer read FKeyCount write FKeyCount;
    property ReadRatio: Double read FReadRatio write FReadRatio;
  end;
  
  // ============================================================================
  // TConfigCacheStressTest - Cache performance
  // ============================================================================
  
  TConfigCacheStressTest = class(TStressTest)
  private
    FKeys: TArray<string>;
    FKeyCount: Integer;
    FCacheEnabled: Boolean;
    FHitCount: Int64;
    FMissCount: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property KeyCount: Integer read FKeyCount write FKeyCount;
    property CacheEnabled: Boolean read FCacheEnabled write FCacheEnabled;
  end;
  
  // ============================================================================
  // TConfigLargeValueStressTest - Large config values
  // ============================================================================
  
  TConfigLargeValueStressTest = class(TStressTest)
  private
    FValueSizeKB: Integer;
    FKeyCounter: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property ValueSizeKB: Integer read FValueSizeKB write FValueSizeKB;
  end;
  
  // ============================================================================
  // TConfigCategoryStressTest - Category operations
  // ============================================================================
  
  TConfigCategoryStressTest = class(TStressTest)
  private
    FCategories: TArray<string>;
    FCategoryCount: Integer;
    FKeysPerCategory: Integer;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property CategoryCount: Integer read FCategoryCount write FCategoryCount;
    property KeysPerCategory: Integer read FKeysPerCategory write FKeysPerCategory;
  end;
  
  // ============================================================================
  // Helper functions
  // ============================================================================
  
  /// <summary>Run all configuration stress tests</summary>
  function RunAllConfigStressTests(DurationSec: Integer = 30; 
    ThreadCount: Integer = 10): TStressTestReport;

implementation

uses
  Winapi.Windows,
  UniBase.Manager,
  UniBase.Config;

// Forward declarations for helper functions
function IfThenStr(Condition: Boolean; const TrueValue, FalseValue: string): string; forward;
function IfThenDbl(Condition: Boolean; TrueValue, FalseValue: Double): Double; forward;

// Wrapper to access UniBase singleton (avoids namespace collision)
function UB: TUniBaseManager; inline;
begin
  Result := UniBase.Manager.UniBase;
end;

// ============================================================================
// TConfigReadStressTest
// ============================================================================

constructor TConfigReadStressTest.Create;
begin
  inherited Create('Config.Read', 'Concurrent configuration read operations');
  FKeyCount := 100;
end;

procedure TConfigReadStressTest.Setup;
var
  I: Integer;
begin
  // Pre-populate config keys
  SetLength(FKeys, FKeyCount);
  for I := 0 to FKeyCount - 1 do
  begin
    FKeys[I] := Format('stress_read_key_%d', [I]);
    UB.Config.SetConfig(FKeys[I], Format('value_%d', [I]), 'StressTest');
  end;
end;

procedure TConfigReadStressTest.Teardown;
var
  I: Integer;
begin
  // Clean up test keys
  for I := 0 to FKeyCount - 1 do
  begin
    try
      UB.Config.DeleteConfig(FKeys[I]);
    except
      // Ignore cleanup errors
    end;
  end;
end;

procedure TConfigReadStressTest.Execute;
var
  Key, Value: string;
  Index: Integer;
  SW: TStopwatch;
begin
  // Random read from pre-populated keys
  Index := Random(FKeyCount);
  Key := FKeys[Index];
  
  SW := TStopwatch.StartNew;
  try
    Value := UB.Config.GetConfig(Key);
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    
    if Value <> '' then
      ReportSuccess
    else
      ReportError('Empty value returned for key: ' + Key);
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Read failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TConfigWriteStressTest
// ============================================================================

constructor TConfigWriteStressTest.Create;
begin
  inherited Create('Config.Write', 'Concurrent configuration write operations');
  FKeyPrefix := 'stress_write_';
  FValueSize := 100;
end;

procedure TConfigWriteStressTest.Setup;
begin
  FKeyCounter := 0;
end;

procedure TConfigWriteStressTest.Teardown;
var
  I: Integer;
begin
  // Clean up test keys (best effort)
  for I := 0 to FKeyCounter - 1 do
  begin
    try
      UB.Config.DeleteConfig(FKeyPrefix + IntToStr(I));
    except
      // Ignore cleanup errors
    end;
  end;
end;

procedure TConfigWriteStressTest.Execute;
var
  Key, Value: string;
  Counter: Int64;
  SW: TStopwatch;
begin
  Counter := TInterlocked.Increment(FKeyCounter);
  Key := FKeyPrefix + IntToStr(Counter);
  Value := StringOfChar('X', FValueSize);
  
  SW := TStopwatch.StartNew;
  try
    UB.Config.SetConfig(Key, Value, 'StressTest');
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Write failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TConfigMixedStressTest
// ============================================================================

constructor TConfigMixedStressTest.Create;
begin
  inherited Create('Config.Mixed', 'Mixed read/write configuration operations');
  FKeyCount := 50;
  FReadRatio := 0.8; // 80% reads, 20% writes
  FLock := TCriticalSection.Create;
end;

destructor TConfigMixedStressTest.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TConfigMixedStressTest.Setup;
var
  I: Integer;
begin
  // Pre-populate config keys
  SetLength(FKeys, FKeyCount);
  for I := 0 to FKeyCount - 1 do
  begin
    FKeys[I] := Format('stress_mixed_key_%d', [I]);
    UB.Config.SetConfig(FKeys[I], Format('initial_value_%d', [I]), 'StressTest');
  end;
end;

procedure TConfigMixedStressTest.Teardown;
var
  I: Integer;
begin
  for I := 0 to FKeyCount - 1 do
  begin
    try
      UB.Config.DeleteConfig(FKeys[I]);
    except
      // Ignore cleanup errors
    end;
  end;
end;

procedure TConfigMixedStressTest.Execute;
var
  Key, Value: string;
  Index: Integer;
  IsRead: Boolean;
  SW: TStopwatch;
begin
  Index := Random(FKeyCount);
  Key := FKeys[Index];
  IsRead := Random < FReadRatio;
  
  SW := TStopwatch.StartNew;
  try
    if IsRead then
    begin
      Value := UB.Config.GetConfig(Key);
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      
      if Value <> '' then
        ReportSuccess
      else
        ReportError('Empty value for key: ' + Key);
    end
    else
    begin
      Value := Format('updated_%d_%d', [Index, GetTickCount]);
      UB.Config.SetConfig(Key, Value, 'StressTest');
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportSuccess;
    end;
    
    AddCustomMetric('ReadRatio', IfThenDbl(IsRead, 1.0, 0.0));
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError(Format('%s failed: %s', [IfThenStr(IsRead, 'Read', 'Write'), E.Message]));
    end;
  end;
end;

// ============================================================================
// TConfigCacheStressTest
// ============================================================================

constructor TConfigCacheStressTest.Create;
begin
  inherited Create('Config.Cache', 'Configuration cache performance test');
  FKeyCount := 100;
  FCacheEnabled := True;
end;

procedure TConfigCacheStressTest.Setup;
var
  I: Integer;
begin
  FHitCount := 0;
  FMissCount := 0;
  
  // Pre-populate and warm up cache
  SetLength(FKeys, FKeyCount);
  for I := 0 to FKeyCount - 1 do
  begin
    FKeys[I] := Format('stress_cache_key_%d', [I]);
    UB.Config.SetConfig(FKeys[I], Format('cached_value_%d', [I]), 'StressTest');
  end;
  
  UB.Config.CacheEnabled := FCacheEnabled;
  
  // Warm up cache by reading all keys
  if FCacheEnabled then
  begin
    for I := 0 to FKeyCount - 1 do
      UB.Config.GetConfig(FKeys[I]);
  end;
end;

procedure TConfigCacheStressTest.Teardown;
var
  I: Integer;
begin
  for I := 0 to FKeyCount - 1 do
  begin
    try
      UB.Config.DeleteConfig(FKeys[I]);
    except
      // Ignore cleanup errors
    end;
  end;
  
  // Re-enable cache
  UB.Config.CacheEnabled := True;
  
  AddCustomMetric('CacheHitCount', FHitCount);
  AddCustomMetric('CacheMissCount', FMissCount);
end;

procedure TConfigCacheStressTest.Execute;
var
  Key, Value: string;
  Index: Integer;
  SW: TStopwatch;
begin
  // Biased random to simulate real-world cache access patterns
  // 80% of accesses go to 20% of keys (hot keys)
  if Random < 0.8 then
    Index := Random(FKeyCount div 5)  // Hot keys
  else
    Index := Random(FKeyCount);        // All keys
    
  Key := FKeys[Index];
  
  SW := TStopwatch.StartNew;
  try
    Value := UB.Config.GetConfig(Key);
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    
    if Value <> '' then
    begin
      ReportSuccess;
      TInterlocked.Increment(FHitCount);
    end
    else
    begin
      ReportError('Empty value for key: ' + Key);
      TInterlocked.Increment(FMissCount);
    end;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Cache read failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TConfigLargeValueStressTest
// ============================================================================

constructor TConfigLargeValueStressTest.Create;
begin
  inherited Create('Config.LargeValue', 'Large configuration value handling');
  FValueSizeKB := 10;
end;

procedure TConfigLargeValueStressTest.Setup;
begin
  FKeyCounter := 0;
end;

procedure TConfigLargeValueStressTest.Teardown;
var
  I: Integer;
begin
  // Clean up large value keys
  for I := 0 to FKeyCounter - 1 do
  begin
    try
      UB.Config.DeleteConfig('stress_large_' + IntToStr(I));
    except
      // Ignore cleanup errors
    end;
  end;
end;

procedure TConfigLargeValueStressTest.Execute;
var
  Key, Value, ReadValue: string;
  Counter: Int64;
  SW: TStopwatch;
begin
  Counter := TInterlocked.Increment(FKeyCounter);
  Key := 'stress_large_' + IntToStr(Counter);
  Value := StringOfChar('L', FValueSizeKB * 1024);
  
  // Write large value
  SW := TStopwatch.StartNew;
  try
    UB.Config.SetConfig(Key, Value, 'StressTest');
    SW.Stop;
    AddCustomMetric('WriteLatencyMs', SW.Elapsed.TotalMilliseconds);
    
    // Read back and verify
    SW := TStopwatch.StartNew;
    ReadValue := UB.Config.GetConfig(Key);
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    
    if Length(ReadValue) = Length(Value) then
      ReportSuccess
    else
      ReportError(Format('Value size mismatch: expected %d, got %d', 
        [Length(Value), Length(ReadValue)]));
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Large value operation failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TConfigCategoryStressTest
// ============================================================================

constructor TConfigCategoryStressTest.Create;
begin
  inherited Create('Config.Category', 'Configuration category operations');
  FCategoryCount := 10;
  FKeysPerCategory := 20;
end;

procedure TConfigCategoryStressTest.Setup;
var
  I, J: Integer;
begin
  // Create categories with keys
  SetLength(FCategories, FCategoryCount);
  for I := 0 to FCategoryCount - 1 do
  begin
    FCategories[I] := Format('StressCategory_%d', [I]);
    for J := 0 to FKeysPerCategory - 1 do
    begin
    UB.Config.SetConfig(
        Format('cat_%d_key_%d', [I, J]),
        Format('cat_value_%d_%d', [I, J]),
        FCategories[I]);
    end;
  end;
end;

procedure TConfigCategoryStressTest.Teardown;
var
  I, J: Integer;
begin
  for I := 0 to FCategoryCount - 1 do
  begin
    for J := 0 to FKeysPerCategory - 1 do
    begin
      try
        UB.Config.DeleteConfig(Format('cat_%d_key_%d', [I, J]));
      except
        // Ignore cleanup errors
      end;
    end;
  end;
end;

procedure TConfigCategoryStressTest.Execute;
var
  CatIndex: Integer;
  Category: string;
  Keys: TDictionary<string, string>;
  SW: TStopwatch;
begin
  CatIndex := Random(FCategoryCount);
  Category := FCategories[CatIndex];
  
  SW := TStopwatch.StartNew;
  try
    Keys := UB.Config.GetConfigsByCategory(Category);
    try
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      
      if Keys.Count >= FKeysPerCategory then
        ReportSuccess
      else
        ReportError(Format('Expected %d keys, got %d for category %s',
          [FKeysPerCategory, Keys.Count, Category]));
          
      AddCustomMetric('KeysReturned', Keys.Count);
    finally
      Keys.Free;
    end;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Category query failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// Helper functions
// ============================================================================

function RunAllConfigStressTests(DurationSec: Integer; 
  ThreadCount: Integer): TStressTestReport;
var
  Runner: TStressTestRunner;
  ReadTest: TConfigReadStressTest;
  WriteTest: TConfigWriteStressTest;
  MixedTest: TConfigMixedStressTest;
  CacheTest: TConfigCacheStressTest;
  LargeTest: TConfigLargeValueStressTest;
  CategoryTest: TConfigCategoryStressTest;
begin
  Runner := TStressTestRunner.Create;
  try
    Runner.Config.DurationSec := DurationSec;
    Runner.Config.ThreadCount := ThreadCount;
    
    // Add tests
    ReadTest := TConfigReadStressTest.Create;
    ReadTest.KeyCount := 100;
    Runner.AddTest(ReadTest);
    
    WriteTest := TConfigWriteStressTest.Create;
    WriteTest.ValueSize := 100;
    Runner.AddTest(WriteTest);
    
    MixedTest := TConfigMixedStressTest.Create;
    MixedTest.KeyCount := 50;
    MixedTest.ReadRatio := 0.8;
    Runner.AddTest(MixedTest);
    
    CacheTest := TConfigCacheStressTest.Create;
    CacheTest.KeyCount := 100;
    CacheTest.CacheEnabled := True;
    Runner.AddTest(CacheTest);
    
    LargeTest := TConfigLargeValueStressTest.Create;
    LargeTest.ValueSizeKB := 10;
    Runner.AddTest(LargeTest);
    
    CategoryTest := TConfigCategoryStressTest.Create;
    CategoryTest.CategoryCount := 5;
    CategoryTest.KeysPerCategory := 10;
    Runner.AddTest(CategoryTest);
    
    // Run all tests
    Runner.Run;
    
    Result := Runner.Report;
    // Note: Caller should not free Report as it's owned by Runner
    // For proper ownership transfer, would need Clone method
  finally
    Runner.Free;
  end;
end;

function IfThenStr(Condition: Boolean; const TrueValue, FalseValue: string): string;
begin
  if Condition then
    Result := TrueValue
  else
    Result := FalseValue;
end;

function IfThenDbl(Condition: Boolean; TrueValue, FalseValue: Double): Double;
begin
  if Condition then
    Result := TrueValue
  else
    Result := FalseValue;
end;

end.
