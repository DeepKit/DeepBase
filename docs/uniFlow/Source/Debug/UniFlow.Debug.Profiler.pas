unit UniFlow.Debug.Profiler;
(*
  UniFlow Performance Profiler
  ============================
  UX-004: 工作流性能分析器
  
  功能：
  - 执行时间分析（各步骤耗时）
  - 内存使用监控
  - 热点检测（瓶颈识别）
  - 调用频率统计
  - 性能报告生成
  
  Author: UniFlow Team
  Date: 2025-12-06
*)

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.JSON, System.SyncObjs, System.Diagnostics,
  UniFlow.Workflow.Definition,
  UniFlow.Workflow.Context,
  UniFlow.Workflow.Executor;

type
  // ============================================================================
  // 步骤性能数据
  // ============================================================================
  
  TStepProfile = class
  private
    FStepId: string;
    FStepName: string;
    FStepType: string;
    FCallCount: Int64;
    FTotalTime: Int64;        // 总耗时 (微秒)
    FMinTime: Int64;          // 最小耗时
    FMaxTime: Int64;          // 最大耗时
    FSelfTime: Int64;         // 自身耗时（不含子调用）
    FChildTime: Int64;        // 子调用耗时
    FErrorCount: Integer;
    FLastCallTime: TDateTime;
    FMemoryDelta: Int64;      // 内存变化 (字节)
  public
    constructor Create(const AStepId, AStepName, AStepType: string);
    
    procedure RecordCall(ADuration: Int64; AMemoryDelta: Int64 = 0);
    procedure RecordError;
    procedure AddChildTime(ATime: Int64);
    function GetAverageTime: Double;
    function GetPercentage(ATotalTime: Int64): Double;
    function ToJSON: TJSONObject;
    
    property StepId: string read FStepId;
    property StepName: string read FStepName;
    property StepType: string read FStepType;
    property CallCount: Int64 read FCallCount;
    property TotalTime: Int64 read FTotalTime;
    property MinTime: Int64 read FMinTime;
    property MaxTime: Int64 read FMaxTime;
    property SelfTime: Int64 read FSelfTime;
    property ErrorCount: Integer read FErrorCount;
    property MemoryDelta: Int64 read FMemoryDelta;
  end;
  
  // ============================================================================
  // 调用栈帧（用于计算 SelfTime）
  // ============================================================================
  
  TProfileFrame = record
    StepId: string;
    StartTime: Int64;         // 高精度时间戳
    StartMemory: Int64;       // 起始内存
  end;
  
  // ============================================================================
  // 热点类型
  // ============================================================================
  
  THotspotType = (
    hsSlowStep,       // 慢步骤
    hsFrequentStep,   // 高频步骤
    hsMemoryHog,      // 内存消耗大
    hsErrorProne      // 易错步骤
  );
  
  THotspot = record
    StepId: string;
    StepName: string;
    HotspotType: THotspotType;
    Value: Double;            // 具体数值
    Description: string;
    Suggestion: string;
    
    function ToJSON: TJSONObject;
  end;
  
  // ============================================================================
  // 性能报告
  // ============================================================================
  
  TProfileReport = class
  private
    FWorkflowId: string;
    FInstanceId: string;
    FStartTime: TDateTime;
    FEndTime: TDateTime;
    FTotalDuration: Int64;
    FTotalSteps: Integer;
    FTotalErrors: Integer;
    FPeakMemory: Int64;
    FStepProfiles: TObjectDictionary<string, TStepProfile>;
    FHotspots: TList<THotspot>;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure AddStepProfile(AProfile: TStepProfile);
    procedure AddHotspot(const AHotspot: THotspot);
    procedure Finalize;
    
    function ToJSON: TJSONObject;
    function ToText: string;
    function ToHTML: string;
    
    property WorkflowId: string read FWorkflowId write FWorkflowId;
    property InstanceId: string read FInstanceId write FInstanceId;
    property StartTime: TDateTime read FStartTime write FStartTime;
    property EndTime: TDateTime read FEndTime write FEndTime;
    property TotalDuration: Int64 read FTotalDuration write FTotalDuration;
    property TotalSteps: Integer read FTotalSteps write FTotalSteps;
    property TotalErrors: Integer read FTotalErrors write FTotalErrors;
    property PeakMemory: Int64 read FPeakMemory write FPeakMemory;
    property Hotspots: TList<THotspot> read FHotspots;
  end;
  
  // ============================================================================
  // 性能分析器
  // ============================================================================
  
  TWorkflowProfiler = class
  private
    FExecutor: TWorkflowExecutor;
    FEnabled: Boolean;
    FStepProfiles: TObjectDictionary<string, TStepProfile>;
    FCallStack: TList<TProfileFrame>;
    FLock: TCriticalSection;
    FStopwatch: TStopwatch;
    FStartTime: TDateTime;
    FPeakMemory: Int64;
    FCurrentMemory: Int64;
    
    // 阈值配置
    FSlowStepThreshold: Int64;      // 慢步骤阈值 (微秒)
    FHighFrequencyThreshold: Int64; // 高频阈值 (调用次数)
    FMemoryThreshold: Int64;        // 内存阈值 (字节)
    FErrorThreshold: Integer;       // 错误阈值 (次数)
    
    procedure ExecutorStepStart(Sender: TObject; AStep: TWorkflowStep);
    procedure ExecutorStepComplete(Sender: TObject; AStep: TWorkflowStep; AResult: TStepResult);
    procedure ExecutorError(Sender: TObject; const ACode, AMessage: string);
    
    function GetOrCreateProfile(AStep: TWorkflowStep): TStepProfile;
    function GetCurrentMemory: Int64;
    procedure UpdatePeakMemory;
    function DetectHotspots: TList<THotspot>;
    
  public
    constructor Create(AExecutor: TWorkflowExecutor);
    destructor Destroy; override;
    
    /// <summary>开始性能采集</summary>
    procedure Start;
    
    /// <summary>停止性能采集</summary>
    procedure Stop;
    
    /// <summary>重置所有数据</summary>
    procedure Reset;
    
    /// <summary>生成性能报告</summary>
    function GenerateReport: TProfileReport;
    
    /// <summary>获取实时统计</summary>
    function GetRealTimeStats: TJSONObject;
    
    /// <summary>获取步骤排名（按耗时）</summary>
    function GetTopStepsByTime(ACount: Integer = 10): TJSONArray;
    
    /// <summary>获取步骤排名（按调用次数）</summary>
    function GetTopStepsByCount(ACount: Integer = 10): TJSONArray;
    
    /// <summary>获取热点</summary>
    function GetHotspots: TJSONArray;
    
    /// <summary>导出为 CSV</summary>
    function ExportToCSV: string;
    
    // 属性
    property Enabled: Boolean read FEnabled write FEnabled;
    property SlowStepThreshold: Int64 read FSlowStepThreshold write FSlowStepThreshold;
    property HighFrequencyThreshold: Int64 read FHighFrequencyThreshold write FHighFrequencyThreshold;
    property MemoryThreshold: Int64 read FMemoryThreshold write FMemoryThreshold;
    property ErrorThreshold: Integer read FErrorThreshold write FErrorThreshold;
  end;
  
  // ============================================================================
  // 性能监控面板（文本界面）
  // ============================================================================
  
  TProfilerPanel = class
  private
    FProfiler: TWorkflowProfiler;
    FOutput: TStrings;
    FRefreshInterval: Integer;
    
    procedure PrintSummary;
    procedure PrintTopSteps(ACount: Integer);
    procedure PrintHotspots;
    procedure PrintMemory;
  public
    constructor Create(AProfiler: TWorkflowProfiler);
    destructor Destroy; override;
    
    /// <summary>处理命令</summary>
    function ProcessCommand(const ACommand: string): string;
    
    /// <summary>获取面板输出</summary>
    function Render: string;
    
    property RefreshInterval: Integer read FRefreshInterval write FRefreshInterval;
    property Output: TStrings read FOutput;
  end;

implementation

uses
  System.Math,
  System.DateUtils;

// ============================================================================
// TStepProfile
// ============================================================================

constructor TStepProfile.Create(const AStepId, AStepName, AStepType: string);
begin
  inherited Create;
  FStepId := AStepId;
  FStepName := AStepName;
  FStepType := AStepType;
  FCallCount := 0;
  FTotalTime := 0;
  FMinTime := High(Int64);
  FMaxTime := 0;
  FSelfTime := 0;
  FChildTime := 0;
  FErrorCount := 0;
  FMemoryDelta := 0;
end;

procedure TStepProfile.RecordCall(ADuration: Int64; AMemoryDelta: Int64);
begin
  Inc(FCallCount);
  Inc(FTotalTime, ADuration);
  Inc(FSelfTime, ADuration);
  Inc(FMemoryDelta, AMemoryDelta);
  
  if ADuration < FMinTime then
    FMinTime := ADuration;
  if ADuration > FMaxTime then
    FMaxTime := ADuration;
    
  FLastCallTime := Now;
end;

procedure TStepProfile.RecordError;
begin
  Inc(FErrorCount);
end;

procedure TStepProfile.AddChildTime(ATime: Int64);
begin
  Inc(FChildTime, ATime);
  Dec(FSelfTime, ATime);
  if FSelfTime < 0 then FSelfTime := 0;
end;

function TStepProfile.GetAverageTime: Double;
begin
  if FCallCount > 0 then
    Result := FTotalTime / FCallCount
  else
    Result := 0;
end;

function TStepProfile.GetPercentage(ATotalTime: Int64): Double;
begin
  if ATotalTime > 0 then
    Result := (FTotalTime * 100.0) / ATotalTime
  else
    Result := 0;
end;

function TStepProfile.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('stepId', FStepId);
  Result.AddPair('stepName', FStepName);
  Result.AddPair('stepType', FStepType);
  Result.AddPair('callCount', TJSONNumber.Create(FCallCount));
  Result.AddPair('totalTimeUs', TJSONNumber.Create(FTotalTime));
  Result.AddPair('totalTimeMs', TJSONNumber.Create(FTotalTime / 1000));
  Result.AddPair('avgTimeUs', TJSONNumber.Create(Round(GetAverageTime)));
  Result.AddPair('minTimeUs', TJSONNumber.Create(FMinTime));
  Result.AddPair('maxTimeUs', TJSONNumber.Create(FMaxTime));
  Result.AddPair('selfTimeUs', TJSONNumber.Create(FSelfTime));
  Result.AddPair('childTimeUs', TJSONNumber.Create(FChildTime));
  Result.AddPair('errorCount', TJSONNumber.Create(FErrorCount));
  Result.AddPair('memoryDeltaBytes', TJSONNumber.Create(FMemoryDelta));
end;

// ============================================================================
// THotspot
// ============================================================================

function THotspot.ToJSON: TJSONObject;
const
  TypeNames: array[THotspotType] of string = ('slow', 'frequent', 'memory', 'error');
begin
  Result := TJSONObject.Create;
  Result.AddPair('stepId', StepId);
  Result.AddPair('stepName', StepName);
  Result.AddPair('type', TypeNames[HotspotType]);
  Result.AddPair('value', TJSONNumber.Create(Value));
  Result.AddPair('description', Description);
  Result.AddPair('suggestion', Suggestion);
end;

// ============================================================================
// TProfileReport
// ============================================================================

constructor TProfileReport.Create;
begin
  inherited Create;
  FStepProfiles := TObjectDictionary<string, TStepProfile>.Create([doOwnsValues]);
  FHotspots := TList<THotspot>.Create;
end;

destructor TProfileReport.Destroy;
begin
  FStepProfiles.Free;
  FHotspots.Free;
  inherited;
end;

procedure TProfileReport.AddStepProfile(AProfile: TStepProfile);
var
  Clone: TStepProfile;
begin
  Clone := TStepProfile.Create(AProfile.StepId, AProfile.StepName, AProfile.StepType);
  Clone.FCallCount := AProfile.CallCount;
  Clone.FTotalTime := AProfile.TotalTime;
  Clone.FMinTime := AProfile.MinTime;
  Clone.FMaxTime := AProfile.MaxTime;
  Clone.FSelfTime := AProfile.SelfTime;
  Clone.FChildTime := AProfile.FChildTime;
  Clone.FErrorCount := AProfile.ErrorCount;
  Clone.FMemoryDelta := AProfile.MemoryDelta;
  FStepProfiles.Add(Clone.StepId, Clone);
end;

procedure TProfileReport.AddHotspot(const AHotspot: THotspot);
begin
  FHotspots.Add(AHotspot);
end;

procedure TProfileReport.Finalize;
var
  Profile: TStepProfile;
begin
  FTotalSteps := 0;
  FTotalErrors := 0;
  
  for Profile in FStepProfiles.Values do
  begin
    Inc(FTotalSteps, Profile.CallCount);
    Inc(FTotalErrors, Profile.ErrorCount);
  end;
end;

function TProfileReport.ToJSON: TJSONObject;
var
  StepsArray, HotspotsArray: TJSONArray;
  Profile: TStepProfile;
  Hotspot: THotspot;
begin
  Result := TJSONObject.Create;
  
  // 基本信息
  Result.AddPair('workflowId', FWorkflowId);
  Result.AddPair('instanceId', FInstanceId);
  Result.AddPair('startTime', DateTimeToStr(FStartTime));
  Result.AddPair('endTime', DateTimeToStr(FEndTime));
  Result.AddPair('totalDurationMs', TJSONNumber.Create(FTotalDuration / 1000));
  Result.AddPair('totalSteps', TJSONNumber.Create(FTotalSteps));
  Result.AddPair('totalErrors', TJSONNumber.Create(FTotalErrors));
  Result.AddPair('peakMemoryMB', TJSONNumber.Create(FPeakMemory / (1024 * 1024)));
  
  // 步骤详情
  StepsArray := TJSONArray.Create;
  for Profile in FStepProfiles.Values do
    StepsArray.AddElement(Profile.ToJSON);
  Result.AddPair('steps', StepsArray);
  
  // 热点
  HotspotsArray := TJSONArray.Create;
  for Hotspot in FHotspots do
    HotspotsArray.AddElement(Hotspot.ToJSON);
  Result.AddPair('hotspots', HotspotsArray);
end;

function TProfileReport.ToText: string;
var
  SB: TStringBuilder;
  Profile: TStepProfile;
  Hotspot: THotspot;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('═══════════════════════════════════════════════════════════════');
    SB.AppendLine('                    UniFlow Performance Report                   ');
    SB.AppendLine('═══════════════════════════════════════════════════════════════');
    SB.AppendLine;
    
    // 概览
    SB.AppendLine('【概览】');
    SB.AppendFormat('  工作流: %s', [FWorkflowId]).AppendLine;
    SB.AppendFormat('  实例: %s', [FInstanceId]).AppendLine;
    SB.AppendFormat('  开始时间: %s', [DateTimeToStr(FStartTime)]).AppendLine;
    SB.AppendFormat('  结束时间: %s', [DateTimeToStr(FEndTime)]).AppendLine;
    SB.AppendFormat('  总耗时: %.2f ms', [FTotalDuration / 1000]).AppendLine;
    SB.AppendFormat('  总步骤: %d', [FTotalSteps]).AppendLine;
    SB.AppendFormat('  错误数: %d', [FTotalErrors]).AppendLine;
    SB.AppendFormat('  峰值内存: %.2f MB', [FPeakMemory / (1024 * 1024)]).AppendLine;
    SB.AppendLine;
    
    // 步骤详情
    SB.AppendLine('【步骤性能】');
    SB.AppendLine('  步骤ID                  调用次数   总耗时(ms)   平均(ms)   错误');
    SB.AppendLine('  ─────────────────────────────────────────────────────────────');
    for Profile in FStepProfiles.Values do
    begin
      SB.AppendFormat('  %-22s %8d %12.2f %10.2f %6d', [
        Profile.StepId.Substring(0, 22),
        Profile.CallCount,
        Profile.TotalTime / 1000,
        Profile.GetAverageTime / 1000,
        Profile.ErrorCount
      ]).AppendLine;
    end;
    SB.AppendLine;
    
    // 热点
    if FHotspots.Count > 0 then
    begin
      SB.AppendLine('【性能热点】');
      for Hotspot in FHotspots do
      begin
        SB.AppendFormat('  ⚠ [%s] %s', [Hotspot.StepId, Hotspot.Description]).AppendLine;
        SB.AppendFormat('    建议: %s', [Hotspot.Suggestion]).AppendLine;
      end;
    end;
    
    SB.AppendLine;
    SB.AppendLine('═══════════════════════════════════════════════════════════════');
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TProfileReport.ToHTML: string;
var
  SB: TStringBuilder;
  Profile: TStepProfile;
  Hotspot: THotspot;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('<!DOCTYPE html>');
    SB.AppendLine('<html><head>');
    SB.AppendLine('<meta charset="utf-8">');
    SB.AppendLine('<title>UniFlow Performance Report</title>');
    SB.AppendLine('<style>');
    SB.AppendLine('body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 20px; }');
    SB.AppendLine('h1 { color: #333; }');
    SB.AppendLine('table { border-collapse: collapse; width: 100%; margin: 20px 0; }');
    SB.AppendLine('th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }');
    SB.AppendLine('th { background-color: #4CAF50; color: white; }');
    SB.AppendLine('tr:nth-child(even) { background-color: #f2f2f2; }');
    SB.AppendLine('.hotspot { background-color: #ffeb3b; padding: 10px; margin: 5px 0; border-radius: 4px; }');
    SB.AppendLine('.summary { background-color: #e3f2fd; padding: 15px; border-radius: 4px; }');
    SB.AppendLine('</style>');
    SB.AppendLine('</head><body>');
    
    SB.AppendLine('<h1>🚀 UniFlow Performance Report</h1>');
    
    // 概览
    SB.AppendLine('<div class="summary">');
    SB.AppendFormat('<p><strong>工作流:</strong> %s</p>', [FWorkflowId]);
    SB.AppendFormat('<p><strong>总耗时:</strong> %.2f ms</p>', [FTotalDuration / 1000]);
    SB.AppendFormat('<p><strong>步骤数:</strong> %d</p>', [FTotalSteps]);
    SB.AppendFormat('<p><strong>错误数:</strong> %d</p>', [FTotalErrors]);
    SB.AppendFormat('<p><strong>峰值内存:</strong> %.2f MB</p>', [FPeakMemory / (1024 * 1024)]);
    SB.AppendLine('</div>');
    
    // 步骤表格
    SB.AppendLine('<h2>📊 步骤性能</h2>');
    SB.AppendLine('<table>');
    SB.AppendLine('<tr><th>步骤ID</th><th>名称</th><th>调用次数</th><th>总耗时(ms)</th><th>平均(ms)</th><th>错误</th></tr>');
    for Profile in FStepProfiles.Values do
    begin
      SB.AppendFormat('<tr><td>%s</td><td>%s</td><td>%d</td><td>%.2f</td><td>%.2f</td><td>%d</td></tr>', [
        Profile.StepId,
        Profile.StepName,
        Profile.CallCount,
        Profile.TotalTime / 1000,
        Profile.GetAverageTime / 1000,
        Profile.ErrorCount
      ]);
    end;
    SB.AppendLine('</table>');
    
    // 热点
    if FHotspots.Count > 0 then
    begin
      SB.AppendLine('<h2>⚠️ 性能热点</h2>');
      for Hotspot in FHotspots do
      begin
        SB.AppendFormat('<div class="hotspot"><strong>[%s]</strong> %s<br><em>建议: %s</em></div>', [
          Hotspot.StepId,
          Hotspot.Description,
          Hotspot.Suggestion
        ]);
      end;
    end;
    
    SB.AppendLine('</body></html>');
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

// ============================================================================
// TWorkflowProfiler
// ============================================================================

constructor TWorkflowProfiler.Create(AExecutor: TWorkflowExecutor);
begin
  inherited Create;
  FExecutor := AExecutor;
  FEnabled := False;
  FStepProfiles := TObjectDictionary<string, TStepProfile>.Create([doOwnsValues]);
  FCallStack := TList<TProfileFrame>.Create;
  FLock := TCriticalSection.Create;
  FStopwatch := TStopwatch.Create;
  
  // 默认阈值
  FSlowStepThreshold := 1000000;    // 1 秒
  FHighFrequencyThreshold := 100;   // 100 次
  FMemoryThreshold := 10 * 1024 * 1024; // 10 MB
  FErrorThreshold := 5;             // 5 次错误
  
  // 挂接执行器事件
  FExecutor.OnStepStart := ExecutorStepStart;
  FExecutor.OnStepComplete := ExecutorStepComplete;
  FExecutor.OnWorkflowError := ExecutorError;
end;

destructor TWorkflowProfiler.Destroy;
begin
  FStepProfiles.Free;
  FCallStack.Free;
  FLock.Free;
  inherited;
end;

procedure TWorkflowProfiler.ExecutorStepStart(Sender: TObject; AStep: TWorkflowStep);
var
  Frame: TProfileFrame;
begin
  if not FEnabled then Exit;
  
  FLock.Enter;
  try
    Frame.StepId := AStep.Id;
    Frame.StartTime := FStopwatch.GetTimeStamp;
    Frame.StartMemory := GetCurrentMemory;
    FCallStack.Add(Frame);
  finally
    FLock.Leave;
  end;
end;

procedure TWorkflowProfiler.ExecutorStepComplete(Sender: TObject; AStep: TWorkflowStep; AResult: TStepResult);
var
  Frame: TProfileFrame;
  Duration, MemoryDelta: Int64;
  Profile: TStepProfile;
begin
  if not FEnabled then Exit;
  
  FLock.Enter;
  try
    if FCallStack.Count = 0 then Exit;
    
    Frame := FCallStack.Last;
    FCallStack.Delete(FCallStack.Count - 1);
    
    Duration := TStopwatch.GetTimeStamp - Frame.StartTime;
    Duration := Round(Duration / (TStopwatch.Frequency / 1000000)); // 转换为微秒
    
    MemoryDelta := GetCurrentMemory - Frame.StartMemory;
    
    Profile := GetOrCreateProfile(AStep);
    Profile.RecordCall(Duration, MemoryDelta);
    
    // 更新父步骤的 ChildTime
    if FCallStack.Count > 0 then
    begin
      var ParentId := FCallStack.Last.StepId;
      if FStepProfiles.ContainsKey(ParentId) then
        FStepProfiles[ParentId].AddChildTime(Duration);
    end;
    
    UpdatePeakMemory;
  finally
    FLock.Leave;
  end;
end;

procedure TWorkflowProfiler.ExecutorError(Sender: TObject; const ACode, AMessage: string);
var
  Profile: TStepProfile;
begin
  if not FEnabled then Exit;
  
  FLock.Enter;
  try
    if FCallStack.Count > 0 then
    begin
      var StepId := FCallStack.Last.StepId;
      if FStepProfiles.TryGetValue(StepId, Profile) then
        Profile.RecordError;
    end;
  finally
    FLock.Leave;
  end;
end;

function TWorkflowProfiler.GetOrCreateProfile(AStep: TWorkflowStep): TStepProfile;
var
  StepType: string;
begin
  if not FStepProfiles.TryGetValue(AStep.Id, Result) then
  begin
    case AStep.StepType of
      stAction: StepType := 'action';
      stCondition: StepType := 'condition';
      stLoop: StepType := 'loop';
      stParallel: StepType := 'parallel';
      stWait: StepType := 'wait';
      stSubWorkflow: StepType := 'subworkflow';
      stEnd: StepType := 'end';
    else
      StepType := 'unknown';
    end;
    
    Result := TStepProfile.Create(AStep.Id, AStep.Name, StepType);
    FStepProfiles.Add(AStep.Id, Result);
  end;
end;

function TWorkflowProfiler.GetCurrentMemory: Int64;
begin
  // 简化实现：返回当前进程工作集大小
  // 在实际实现中应使用 GetProcessMemoryInfo
  Result := 0;
  // TODO: 实现实际内存获取
end;

procedure TWorkflowProfiler.UpdatePeakMemory;
begin
  FCurrentMemory := GetCurrentMemory;
  if FCurrentMemory > FPeakMemory then
    FPeakMemory := FCurrentMemory;
end;

function TWorkflowProfiler.DetectHotspots: TList<THotspot>;
var
  Profile: TStepProfile;
  Hotspot: THotspot;
begin
  Result := TList<THotspot>.Create;
  
  for Profile in FStepProfiles.Values do
  begin
    // 慢步骤
    if Profile.GetAverageTime > FSlowStepThreshold then
    begin
      Hotspot.StepId := Profile.StepId;
      Hotspot.StepName := Profile.StepName;
      Hotspot.HotspotType := hsSlowStep;
      Hotspot.Value := Profile.GetAverageTime / 1000;
      Hotspot.Description := Format('平均耗时 %.2f ms，超过阈值 %.2f ms', [
        Profile.GetAverageTime / 1000, FSlowStepThreshold / 1000]);
      Hotspot.Suggestion := '考虑优化此步骤逻辑，或拆分为更小的步骤';
      Result.Add(Hotspot);
    end;
    
    // 高频步骤
    if Profile.CallCount > FHighFrequencyThreshold then
    begin
      Hotspot.StepId := Profile.StepId;
      Hotspot.StepName := Profile.StepName;
      Hotspot.HotspotType := hsFrequentStep;
      Hotspot.Value := Profile.CallCount;
      Hotspot.Description := Format('调用 %d 次，超过阈值 %d 次', [
        Profile.CallCount, FHighFrequencyThreshold]);
      Hotspot.Suggestion := '检查是否存在不必要的重复调用，考虑缓存结果';
      Result.Add(Hotspot);
    end;
    
    // 内存消耗大
    if Profile.MemoryDelta > FMemoryThreshold then
    begin
      Hotspot.StepId := Profile.StepId;
      Hotspot.StepName := Profile.StepName;
      Hotspot.HotspotType := hsMemoryHog;
      Hotspot.Value := Profile.MemoryDelta / (1024 * 1024);
      Hotspot.Description := Format('内存增长 %.2f MB，超过阈值 %.2f MB', [
        Profile.MemoryDelta / (1024 * 1024), FMemoryThreshold / (1024 * 1024)]);
      Hotspot.Suggestion := '检查大对象创建，考虑使用对象池或流式处理';
      Result.Add(Hotspot);
    end;
    
    // 易错步骤
    if Profile.ErrorCount > FErrorThreshold then
    begin
      Hotspot.StepId := Profile.StepId;
      Hotspot.StepName := Profile.StepName;
      Hotspot.HotspotType := hsErrorProne;
      Hotspot.Value := Profile.ErrorCount;
      Hotspot.Description := Format('错误 %d 次，超过阈值 %d 次', [
        Profile.ErrorCount, FErrorThreshold]);
      Hotspot.Suggestion := '加强输入验证和错误处理，添加重试机制';
      Result.Add(Hotspot);
    end;
  end;
end;

procedure TWorkflowProfiler.Start;
begin
  FLock.Enter;
  try
    FEnabled := True;
    FStartTime := Now;
    FPeakMemory := 0;
    FStopwatch.Reset;
    FStopwatch.Start;
  finally
    FLock.Leave;
  end;
end;

procedure TWorkflowProfiler.Stop;
begin
  FLock.Enter;
  try
    FEnabled := False;
    FStopwatch.Stop;
  finally
    FLock.Leave;
  end;
end;

procedure TWorkflowProfiler.Reset;
begin
  FLock.Enter;
  try
    FStepProfiles.Clear;
    FCallStack.Clear;
    FPeakMemory := 0;
    FStopwatch.Reset;
  finally
    FLock.Leave;
  end;
end;

function TWorkflowProfiler.GenerateReport: TProfileReport;
var
  Profile: TStepProfile;
  Hotspots: TList<THotspot>;
  Hotspot: THotspot;
begin
  FLock.Enter;
  try
    Result := TProfileReport.Create;
    Result.WorkflowId := FExecutor.Workflow.Id;
    Result.InstanceId := FExecutor.Context.InstanceId;
    Result.StartTime := FStartTime;
    Result.EndTime := Now;
    Result.TotalDuration := FStopwatch.ElapsedTicks * 1000000 div TStopwatch.Frequency;
    Result.PeakMemory := FPeakMemory;
    
    // 复制步骤数据
    for Profile in FStepProfiles.Values do
      Result.AddStepProfile(Profile);
    
    // 检测热点
    Hotspots := DetectHotspots;
    try
      for Hotspot in Hotspots do
        Result.AddHotspot(Hotspot);
    finally
      Hotspots.Free;
    end;
    
    Result.Finalize;
  finally
    FLock.Leave;
  end;
end;

function TWorkflowProfiler.GetRealTimeStats: TJSONObject;
var
  TotalTime, TotalCalls: Int64;
  Profile: TStepProfile;
begin
  FLock.Enter;
  try
    Result := TJSONObject.Create;
    
    TotalTime := 0;
    TotalCalls := 0;
    
    for Profile in FStepProfiles.Values do
    begin
      Inc(TotalTime, Profile.TotalTime);
      Inc(TotalCalls, Profile.CallCount);
    end;
    
    Result.AddPair('enabled', TJSONBool.Create(FEnabled));
    Result.AddPair('elapsedMs', TJSONNumber.Create(FStopwatch.ElapsedMilliseconds));
    Result.AddPair('totalStepTimeMs', TJSONNumber.Create(TotalTime / 1000));
    Result.AddPair('totalCalls', TJSONNumber.Create(TotalCalls));
    Result.AddPair('uniqueSteps', TJSONNumber.Create(FStepProfiles.Count));
    Result.AddPair('peakMemoryMB', TJSONNumber.Create(FPeakMemory / (1024 * 1024)));
    Result.AddPair('callStackDepth', TJSONNumber.Create(FCallStack.Count));
  finally
    FLock.Leave;
  end;
end;

function TWorkflowProfiler.GetTopStepsByTime(ACount: Integer): TJSONArray;
var
  List: TList<TPair<Int64, TStepProfile>>;
  Profile: TStepProfile;
  I: Integer;
begin
  FLock.Enter;
  try
    List := TList<TPair<Int64, TStepProfile>>.Create;
    try
      for Profile in FStepProfiles.Values do
        List.Add(TPair<Int64, TStepProfile>.Create(Profile.TotalTime, Profile));
      
      List.Sort(TComparer<TPair<Int64, TStepProfile>>.Construct(
        function(const L, R: TPair<Int64, TStepProfile>): Integer
        begin
          Result := R.Key - L.Key; // 降序
        end
      ));
      
      Result := TJSONArray.Create;
      for I := 0 to Min(ACount - 1, List.Count - 1) do
        Result.AddElement(List[I].Value.ToJSON);
    finally
      List.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function TWorkflowProfiler.GetTopStepsByCount(ACount: Integer): TJSONArray;
var
  List: TList<TPair<Int64, TStepProfile>>;
  Profile: TStepProfile;
  I: Integer;
begin
  FLock.Enter;
  try
    List := TList<TPair<Int64, TStepProfile>>.Create;
    try
      for Profile in FStepProfiles.Values do
        List.Add(TPair<Int64, TStepProfile>.Create(Profile.CallCount, Profile));
      
      List.Sort(TComparer<TPair<Int64, TStepProfile>>.Construct(
        function(const L, R: TPair<Int64, TStepProfile>): Integer
        begin
          Result := R.Key - L.Key;
        end
      ));
      
      Result := TJSONArray.Create;
      for I := 0 to Min(ACount - 1, List.Count - 1) do
        Result.AddElement(List[I].Value.ToJSON);
    finally
      List.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function TWorkflowProfiler.GetHotspots: TJSONArray;
var
  Hotspots: TList<THotspot>;
  Hotspot: THotspot;
begin
  FLock.Enter;
  try
    Hotspots := DetectHotspots;
    try
      Result := TJSONArray.Create;
      for Hotspot in Hotspots do
        Result.AddElement(Hotspot.ToJSON);
    finally
      Hotspots.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function TWorkflowProfiler.ExportToCSV: string;
var
  SB: TStringBuilder;
  Profile: TStepProfile;
begin
  FLock.Enter;
  try
    SB := TStringBuilder.Create;
    try
      SB.AppendLine('StepId,StepName,StepType,CallCount,TotalTimeMs,AvgTimeMs,MinTimeMs,MaxTimeMs,SelfTimeMs,ErrorCount,MemoryDeltaMB');
      
      for Profile in FStepProfiles.Values do
      begin
        SB.AppendFormat('%s,%s,%s,%d,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%.3f', [
          Profile.StepId,
          Profile.StepName,
          Profile.StepType,
          Profile.CallCount,
          Profile.TotalTime / 1000,
          Profile.GetAverageTime / 1000,
          Profile.MinTime / 1000,
          Profile.MaxTime / 1000,
          Profile.SelfTime / 1000,
          Profile.ErrorCount,
          Profile.MemoryDelta / (1024 * 1024)
        ]).AppendLine;
      end;
      
      Result := SB.ToString;
    finally
      SB.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// TProfilerPanel
// ============================================================================

constructor TProfilerPanel.Create(AProfiler: TWorkflowProfiler);
begin
  inherited Create;
  FProfiler := AProfiler;
  FOutput := TStringList.Create;
  FRefreshInterval := 1000;
end;

destructor TProfilerPanel.Destroy;
begin
  FOutput.Free;
  inherited;
end;

function TProfilerPanel.ProcessCommand(const ACommand: string): string;
var
  Parts: TArray<string>;
  Cmd: string;
begin
  FOutput.Clear;
  Parts := ACommand.Trim.Split([' '], 2);
  if Length(Parts) = 0 then Exit('');
  
  Cmd := LowerCase(Parts[0]);
  
  if Cmd = 'start' then
  begin
    FProfiler.Start;
    FOutput.Add('Profiler started');
  end
  else if Cmd = 'stop' then
  begin
    FProfiler.Stop;
    FOutput.Add('Profiler stopped');
  end
  else if Cmd = 'reset' then
  begin
    FProfiler.Reset;
    FOutput.Add('Profiler reset');
  end
  else if Cmd = 'summary' then
    PrintSummary
  else if Cmd = 'top' then
  begin
    var Count := 10;
    if Length(Parts) > 1 then
      TryStrToInt(Parts[1], Count);
    PrintTopSteps(Count);
  end
  else if Cmd = 'hotspots' then
    PrintHotspots
  else if Cmd = 'memory' then
    PrintMemory
  else if Cmd = 'report' then
  begin
    var Report := FProfiler.GenerateReport;
    try
      FOutput.Add(Report.ToText);
    finally
      Report.Free;
    end;
  end
  else if Cmd = 'csv' then
    FOutput.Add(FProfiler.ExportToCSV)
  else if Cmd = 'help' then
  begin
    FOutput.Add('=== Profiler Commands ===');
    FOutput.Add('  start     - Start profiling');
    FOutput.Add('  stop      - Stop profiling');
    FOutput.Add('  reset     - Reset all data');
    FOutput.Add('  summary   - Show summary');
    FOutput.Add('  top [n]   - Show top N steps by time');
    FOutput.Add('  hotspots  - Show performance hotspots');
    FOutput.Add('  memory    - Show memory stats');
    FOutput.Add('  report    - Generate full report');
    FOutput.Add('  csv       - Export to CSV');
  end
  else
    FOutput.Add('Unknown command. Type "help" for available commands.');
  
  Result := FOutput.Text;
end;

function TProfilerPanel.Render: string;
begin
  FOutput.Clear;
  PrintSummary;
  FOutput.Add('');
  PrintTopSteps(5);
  FOutput.Add('');
  PrintHotspots;
  Result := FOutput.Text;
end;

procedure TProfilerPanel.PrintSummary;
var
  Stats: TJSONObject;
begin
  Stats := FProfiler.GetRealTimeStats;
  try
    FOutput.Add('=== Performance Summary ===');
    FOutput.Add(Format('Status: %s', [IfThen(Stats.GetValue<Boolean>('enabled'), 'Running', 'Stopped')]));
    FOutput.Add(Format('Elapsed: %.2f s', [Stats.GetValue<Integer>('elapsedMs') / 1000]));
    FOutput.Add(Format('Total Calls: %d', [Stats.GetValue<Int64>('totalCalls')]));
    FOutput.Add(Format('Unique Steps: %d', [Stats.GetValue<Integer>('uniqueSteps')]));
    FOutput.Add(Format('Peak Memory: %.2f MB', [Stats.GetValue<Double>('peakMemoryMB')]));
  finally
    Stats.Free;
  end;
end;

procedure TProfilerPanel.PrintTopSteps(ACount: Integer);
var
  Top: TJSONArray;
  I: Integer;
  Step: TJSONObject;
begin
  Top := FProfiler.GetTopStepsByTime(ACount);
  try
    FOutput.Add(Format('=== Top %d Steps by Time ===', [ACount]));
    for I := 0 to Top.Count - 1 do
    begin
      Step := Top.Items[I] as TJSONObject;
      FOutput.Add(Format('%d. %s - %.2f ms (%d calls)', [
        I + 1,
        Step.GetValue<string>('stepId'),
        Step.GetValue<Double>('totalTimeMs'),
        Step.GetValue<Int64>('callCount')
      ]));
    end;
  finally
    Top.Free;
  end;
end;

procedure TProfilerPanel.PrintHotspots;
var
  Hotspots: TJSONArray;
  I: Integer;
  HS: TJSONObject;
begin
  Hotspots := FProfiler.GetHotspots;
  try
    FOutput.Add('=== Hotspots ===');
    if Hotspots.Count = 0 then
    begin
      FOutput.Add('  No hotspots detected');
      Exit;
    end;
    
    for I := 0 to Hotspots.Count - 1 do
    begin
      HS := Hotspots.Items[I] as TJSONObject;
      FOutput.Add(Format('⚠ [%s] %s', [
        HS.GetValue<string>('type'),
        HS.GetValue<string>('description')
      ]));
    end;
  finally
    Hotspots.Free;
  end;
end;

procedure TProfilerPanel.PrintMemory;
var
  Stats: TJSONObject;
begin
  Stats := FProfiler.GetRealTimeStats;
  try
    FOutput.Add('=== Memory Stats ===');
    FOutput.Add(Format('Peak Memory: %.2f MB', [Stats.GetValue<Double>('peakMemoryMB')]));
    FOutput.Add(Format('Call Stack Depth: %d', [Stats.GetValue<Integer>('callStackDepth')]));
  finally
    Stats.Free;
  end;
end;

end.
