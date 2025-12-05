unit UniFlow.Diagnostics.TraceExporter;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, DateUtils, fpjson, jsonparser, UniFlow.Diagnostics;

type
  // ============================================================================
  // 执行快照 - 用于复现问题
  // ============================================================================
  
  TExecutionSnapshot = record
    // 元数据
    Id: string;
    CapturedAt: TDateTime;
    Version: string;
    
    // 工作流信息
    WorkflowId: string;
    WorkflowName: string;
    WorkflowVersion: string;
    
    // 追踪信息
    CorrelationId: string;
    
    // 执行状态
    CurrentStepId: string;
    CurrentStepIndex: Integer;
    ExecutedSteps: TStringArray;
    
    // 数据快照
    Variables: TJSONObject;
    InputData: TJSONObject;
    SessionData: TJSONObject;
    
    // 追踪条目
    TraceEntries: TTraceEntryArray;
    
    // 错误信息（如果有）
    HasError: Boolean;
    ErrorMessage: string;
    ErrorClass: string;
    
    function ToJSON: TJSONObject;
    class function FromJSON(JSON: TJSONObject): TExecutionSnapshot; static;
    function ToString: string;
  end;

  // ============================================================================
  // 导出格式
  // ============================================================================
  
  TExportFormat = (
    efJSON,       // JSON 格式
    efText,       // 文本格式
    efMarkdown,   // Markdown 格式
    efHTML,       // HTML 报告
    efTimeline    // 时间线格式
  );

  // ============================================================================
  // 轨迹导出器
  // ============================================================================
  
  TTraceExporter = class
  private
    function FormatDuration(Ms: Int64): string;
    function GetActionIcon(const Action: string): string;
  public
    // 创建快照
    function CreateSnapshot(
      const WorkflowId, WorkflowName, CorrelationId, CurrentStepId: string;
      const ExecutedSteps: TStringArray;
      Variables, InputData: TJSONObject;
      const TraceEntries: TTraceEntryArray
    ): TExecutionSnapshot;
    
    // 导出快照
    function ExportSnapshot(const Snapshot: TExecutionSnapshot; Format: TExportFormat): string;
    
    // 导出追踪条目
    function ExportTraceEntries(const Entries: TTraceEntryArray; Format: TExportFormat): string;
    
    // 保存到文件
    procedure SaveSnapshotToFile(const Snapshot: TExecutionSnapshot; const FileName: string);
    function LoadSnapshotFromFile(const FileName: string): TExecutionSnapshot;
    
    // 生成报告
    function GenerateExecutionReport(const Snapshot: TExecutionSnapshot): string;
    function GenerateTimelineReport(const Entries: TTraceEntryArray): string;
    function GeneratePerformanceReport(const Entries: TTraceEntryArray): string;
  end;

// ============================================================================
// 便捷函数
// ============================================================================

function CreateTraceExporter: TTraceExporter;

// 快速导出当前追踪
function QuickExportTrace(Format: TExportFormat = efJSON): string;
function QuickSaveSnapshot(const FileName: string): Boolean;

implementation

// ============================================================================
// TExecutionSnapshot
// ============================================================================

function TExecutionSnapshot.ToJSON: TJSONObject;
var
  StepsArr, TracesArr: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  
  // 元数据
  Result.Add('id', Id);
  Result.Add('capturedAt', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"Z"', CapturedAt));
  Result.Add('version', Version);
  
  // 工作流信息
  Result.Add('workflowId', WorkflowId);
  Result.Add('workflowName', WorkflowName);
  Result.Add('workflowVersion', WorkflowVersion);
  
  // 追踪信息
  Result.Add('correlationId', CorrelationId);
  
  // 执行状态
  Result.Add('currentStepId', CurrentStepId);
  Result.Add('currentStepIndex', CurrentStepIndex);
  
  StepsArr := TJSONArray.Create;
  for I := 0 to High(ExecutedSteps) do
    StepsArr.Add(ExecutedSteps[I]);
  Result.Add('executedSteps', StepsArr);
  
  // 数据快照
  if Assigned(Variables) then
    Result.Add('variables', Variables.Clone);
  if Assigned(InputData) then
    Result.Add('inputData', InputData.Clone);
  if Assigned(SessionData) then
    Result.Add('sessionData', SessionData.Clone);
  
  // 追踪条目
  TracesArr := TJSONArray.Create;
  for I := 0 to High(TraceEntries) do
    TracesArr.Add(TraceEntries[I].ToJSON);
  Result.Add('traceEntries', TracesArr);
  
  // 错误信息
  Result.Add('hasError', HasError);
  if HasError then
  begin
    Result.Add('errorMessage', ErrorMessage);
    Result.Add('errorClass', ErrorClass);
  end;
end;

class function TExecutionSnapshot.FromJSON(JSON: TJSONObject): TExecutionSnapshot;
var
  StepsArr, TracesArr: TJSONArray;
  I: Integer;
  TraceJSON: TJSONObject;
begin
  Result.Id := JSON.Get('id', '');
  Result.CapturedAt := ISO8601ToDate(JSON.Get('capturedAt', ''));
  Result.Version := JSON.Get('version', '1.0');
  
  Result.WorkflowId := JSON.Get('workflowId', '');
  Result.WorkflowName := JSON.Get('workflowName', '');
  Result.WorkflowVersion := JSON.Get('workflowVersion', '');
  
  Result.CorrelationId := JSON.Get('correlationId', '');
  
  Result.CurrentStepId := JSON.Get('currentStepId', '');
  Result.CurrentStepIndex := JSON.Get('currentStepIndex', 0);
  
  // 执行步骤
  StepsArr := JSON.Get('executedSteps', TJSONArray(nil));
  if Assigned(StepsArr) then
  begin
    SetLength(Result.ExecutedSteps, StepsArr.Count);
    for I := 0 to StepsArr.Count - 1 do
      Result.ExecutedSteps[I] := StepsArr.Strings[I];
  end;
  
  // 数据
  if JSON.Find('variables') <> nil then
    Result.Variables := JSON.Objects['variables'].Clone as TJSONObject
  else
    Result.Variables := nil;
    
  if JSON.Find('inputData') <> nil then
    Result.InputData := JSON.Objects['inputData'].Clone as TJSONObject
  else
    Result.InputData := nil;
    
  if JSON.Find('sessionData') <> nil then
    Result.SessionData := JSON.Objects['sessionData'].Clone as TJSONObject
  else
    Result.SessionData := nil;
  
  // 追踪条目
  TracesArr := JSON.Get('traceEntries', TJSONArray(nil));
  if Assigned(TracesArr) then
  begin
    SetLength(Result.TraceEntries, TracesArr.Count);
    for I := 0 to TracesArr.Count - 1 do
    begin
      TraceJSON := TracesArr.Objects[I];
      Result.TraceEntries[I].Timestamp := ISO8601ToDate(TraceJSON.Get('timestamp', ''));
      Result.TraceEntries[I].CorrelationId := TraceJSON.Get('correlationId', '');
      Result.TraceEntries[I].WorkflowId := TraceJSON.Get('workflowId', '');
      Result.TraceEntries[I].StepId := TraceJSON.Get('stepId', '');
      Result.TraceEntries[I].StepType := TraceJSON.Get('stepType', '');
      Result.TraceEntries[I].Action := TraceJSON.Get('action', '');
      Result.TraceEntries[I].Duration := TraceJSON.Get('durationMs', Int64(0));
      Result.TraceEntries[I].InputData := TraceJSON.Get('input', '');
      Result.TraceEntries[I].OutputData := TraceJSON.Get('output', '');
      Result.TraceEntries[I].ErrorMessage := TraceJSON.Get('error', '');
    end;
  end;
  
  // 错误
  Result.HasError := JSON.Get('hasError', False);
  Result.ErrorMessage := JSON.Get('errorMessage', '');
  Result.ErrorClass := JSON.Get('errorClass', '');
end;

function TExecutionSnapshot.ToString: string;
var
  SB: TStringBuilder;
  I: Integer;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('╔════════════════════════════════════════════════════════════════╗');
    SB.AppendLine('║                    EXECUTION SNAPSHOT                          ║');
    SB.AppendLine('╠════════════════════════════════════════════════════════════════╣');
    SB.AppendFormat('║ ID:             %s', [Id]).AppendLine;
    SB.AppendFormat('║ Captured:       %s', [FormatDateTime('yyyy-mm-dd hh:nn:ss', CapturedAt)]).AppendLine;
    SB.AppendFormat('║ Correlation:    %s', [CorrelationId]).AppendLine;
    SB.AppendLine('╠════════════════════════════════════════════════════════════════╣');
    SB.AppendFormat('║ Workflow:       %s v%s', [WorkflowName, WorkflowVersion]).AppendLine;
    SB.AppendFormat('║ Current Step:   %s (#%d)', [CurrentStepId, CurrentStepIndex]).AppendLine;
    SB.AppendLine('╠════════════════════════════════════════════════════════════════╣');
    SB.AppendLine('║ Execution Path:');
    for I := 0 to High(ExecutedSteps) do
      SB.AppendFormat('║   %d. %s', [I + 1, ExecutedSteps[I]]).AppendLine;
    
    if HasError then
    begin
      SB.AppendLine('╠════════════════════════════════════════════════════════════════╣');
      SB.AppendLine('║ ⚠ ERROR:');
      SB.AppendFormat('║   %s: %s', [ErrorClass, ErrorMessage]).AppendLine;
    end;
    
    SB.AppendLine('╚════════════════════════════════════════════════════════════════╝');
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

// ============================================================================
// TTraceExporter
// ============================================================================

function TTraceExporter.FormatDuration(Ms: Int64): string;
begin
  if Ms < 1000 then
    Result := Format('%dms', [Ms])
  else if Ms < 60000 then
    Result := Format('%.2fs', [Ms / 1000])
  else
    Result := Format('%dm %ds', [Ms div 60000, (Ms mod 60000) div 1000]);
end;

function TTraceExporter.GetActionIcon(const Action: string): string;
begin
  if Action = 'enter' then
    Result := '▶'
  else if Action = 'exit' then
    Result := '✓'
  else if Action = 'error' then
    Result := '✗'
  else
    Result := '•';
end;

function TTraceExporter.CreateSnapshot(
  const WorkflowId, WorkflowName, CorrelationId, CurrentStepId: string;
  const ExecutedSteps: TStringArray;
  Variables, InputData: TJSONObject;
  const TraceEntries: TTraceEntryArray
): TExecutionSnapshot;
var
  G: TGUID;
begin
  CreateGUID(G);
  Result.Id := 'SNAP-' + Copy(GUIDToString(G), 2, 8);
  Result.CapturedAt := Now;
  Result.Version := '1.0';
  
  Result.WorkflowId := WorkflowId;
  Result.WorkflowName := WorkflowName;
  Result.WorkflowVersion := '1.0.0';
  
  Result.CorrelationId := CorrelationId;
  
  Result.CurrentStepId := CurrentStepId;
  Result.CurrentStepIndex := Length(ExecutedSteps);
  Result.ExecutedSteps := ExecutedSteps;
  
  if Assigned(Variables) then
    Result.Variables := Variables.Clone as TJSONObject
  else
    Result.Variables := nil;
    
  if Assigned(InputData) then
    Result.InputData := InputData.Clone as TJSONObject
  else
    Result.InputData := nil;
    
  Result.SessionData := nil;
  Result.TraceEntries := TraceEntries;
  Result.HasError := False;
  Result.ErrorMessage := '';
  Result.ErrorClass := '';
end;

function TTraceExporter.ExportSnapshot(const Snapshot: TExecutionSnapshot; 
  Format: TExportFormat): string;
begin
  case Format of
    efJSON:
      Result := Snapshot.ToJSON.FormatJSON;
    efText:
      Result := Snapshot.ToString;
    efMarkdown:
      Result := GenerateExecutionReport(Snapshot);
    efHTML:
      Result := GenerateExecutionReport(Snapshot); // TODO: HTML template
    efTimeline:
      Result := GenerateTimelineReport(Snapshot.TraceEntries);
  else
    Result := Snapshot.ToJSON.FormatJSON;
  end;
end;

function TTraceExporter.ExportTraceEntries(const Entries: TTraceEntryArray; 
  Format: TExportFormat): string;
var
  SB: TStringBuilder;
  Arr: TJSONArray;
  I: Integer;
begin
  case Format of
    efJSON:
      begin
        Arr := TJSONArray.Create;
        try
          for I := 0 to High(Entries) do
            Arr.Add(Entries[I].ToJSON);
          Result := Arr.FormatJSON;
        finally
          Arr.Free;
        end;
      end;
    efText:
      begin
        SB := TStringBuilder.Create;
        try
          SB.AppendLine('=== Execution Trace ===');
          SB.AppendLine;
          for I := 0 to High(Entries) do
          begin
            SB.AppendFormat('%s [%s] %s.%s %s',
              [GetActionIcon(Entries[I].Action),
               FormatDateTime('hh:nn:ss.zzz', Entries[I].Timestamp),
               Entries[I].WorkflowId,
               Entries[I].StepId,
               Entries[I].Action]);
            if Entries[I].Duration > 0 then
              SB.AppendFormat(' (%s)', [FormatDuration(Entries[I].Duration)]);
            if Entries[I].ErrorMessage <> '' then
              SB.AppendFormat(' ERROR: %s', [Entries[I].ErrorMessage]);
            SB.AppendLine;
          end;
          Result := SB.ToString;
        finally
          SB.Free;
        end;
      end;
    efTimeline:
      Result := GenerateTimelineReport(Entries);
  else
    Result := '';
  end;
end;

procedure TTraceExporter.SaveSnapshotToFile(const Snapshot: TExecutionSnapshot; 
  const FileName: string);
var
  JSON: TJSONObject;
  SL: TStringList;
begin
  JSON := Snapshot.ToJSON;
  try
    SL := TStringList.Create;
    try
      SL.Text := JSON.FormatJSON;
      SL.SaveToFile(FileName);
    finally
      SL.Free;
    end;
  finally
    JSON.Free;
  end;
end;

function TTraceExporter.LoadSnapshotFromFile(const FileName: string): TExecutionSnapshot;
var
  SL: TStringList;
  JSON: TJSONObject;
begin
  SL := TStringList.Create;
  try
    SL.LoadFromFile(FileName);
    JSON := GetJSON(SL.Text) as TJSONObject;
    try
      Result := TExecutionSnapshot.FromJSON(JSON);
    finally
      JSON.Free;
    end;
  finally
    SL.Free;
  end;
end;

function TTraceExporter.GenerateExecutionReport(const Snapshot: TExecutionSnapshot): string;
var
  SB: TStringBuilder;
  I: Integer;
  TotalDuration: Int64;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('# Execution Report');
    SB.AppendLine;
    SB.AppendFormat('**Snapshot ID:** `%s`  ', [Snapshot.Id]).AppendLine;
    SB.AppendFormat('**Captured:** %s', [FormatDateTime('yyyy-mm-dd hh:nn:ss', Snapshot.CapturedAt)]).AppendLine;
    SB.AppendLine;
    
    SB.AppendLine('## Workflow');
    SB.AppendFormat('- **Name:** %s', [Snapshot.WorkflowName]).AppendLine;
    SB.AppendFormat('- **ID:** `%s`', [Snapshot.WorkflowId]).AppendLine;
    SB.AppendFormat('- **Correlation:** `%s`', [Snapshot.CorrelationId]).AppendLine;
    SB.AppendLine;
    
    SB.AppendLine('## Execution Path');
    for I := 0 to High(Snapshot.ExecutedSteps) do
      SB.AppendFormat('%d. `%s`', [I + 1, Snapshot.ExecutedSteps[I]]).AppendLine;
    SB.AppendLine;
    
    if Snapshot.HasError then
    begin
      SB.AppendLine('## ⚠️ Error');
      SB.AppendLine('```');
      SB.AppendFormat('%s: %s', [Snapshot.ErrorClass, Snapshot.ErrorMessage]).AppendLine;
      SB.AppendLine('```');
      SB.AppendLine;
    end;
    
    SB.AppendLine('## Trace Timeline');
    SB.AppendLine;
    TotalDuration := 0;
    for I := 0 to High(Snapshot.TraceEntries) do
    begin
      SB.AppendFormat('- `%s` %s **%s** `%s`',
        [FormatDateTime('hh:nn:ss.zzz', Snapshot.TraceEntries[I].Timestamp),
         GetActionIcon(Snapshot.TraceEntries[I].Action),
         Snapshot.TraceEntries[I].StepId,
         Snapshot.TraceEntries[I].Action]);
      if Snapshot.TraceEntries[I].Duration > 0 then
      begin
        SB.AppendFormat(' (%s)', [FormatDuration(Snapshot.TraceEntries[I].Duration)]);
        TotalDuration := TotalDuration + Snapshot.TraceEntries[I].Duration;
      end;
      SB.AppendLine;
    end;
    SB.AppendLine;
    SB.AppendFormat('**Total Duration:** %s', [FormatDuration(TotalDuration)]).AppendLine;
    
    if Assigned(Snapshot.Variables) then
    begin
      SB.AppendLine;
      SB.AppendLine('## Variables');
      SB.AppendLine('```json');
      SB.AppendLine(Snapshot.Variables.FormatJSON);
      SB.AppendLine('```');
    end;
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TTraceExporter.GenerateTimelineReport(const Entries: TTraceEntryArray): string;
var
  SB: TStringBuilder;
  I: Integer;
  PrevTime: TDateTime;
  Gap: Int64;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('┌──────────────────────────────────────────────────────────────┐');
    SB.AppendLine('│                     EXECUTION TIMELINE                       │');
    SB.AppendLine('├──────────────────────────────────────────────────────────────┤');
    
    PrevTime := 0;
    for I := 0 to High(Entries) do
    begin
      // 显示时间间隔
      if (PrevTime > 0) and (Entries[I].Timestamp > PrevTime) then
      begin
        Gap := MilliSecondsBetween(Entries[I].Timestamp, PrevTime);
        if Gap > 10 then
          SB.AppendFormat('│     ... %s ...', [FormatDuration(Gap)]).AppendLine;
      end;
      
      SB.AppendFormat('│ %s %s %-20s %s',
        [FormatDateTime('hh:nn:ss.zzz', Entries[I].Timestamp),
         GetActionIcon(Entries[I].Action),
         Entries[I].StepId,
         Entries[I].Action]);
      
      if Entries[I].Duration > 0 then
        SB.AppendFormat(' [%s]', [FormatDuration(Entries[I].Duration)]);
      
      SB.AppendLine;
      
      if Entries[I].ErrorMessage <> '' then
        SB.AppendFormat('│     └─ ERROR: %s', [Entries[I].ErrorMessage]).AppendLine;
      
      PrevTime := Entries[I].Timestamp;
    end;
    
    SB.AppendLine('└──────────────────────────────────────────────────────────────┘');
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TTraceExporter.GeneratePerformanceReport(const Entries: TTraceEntryArray): string;
var
  SB: TStringBuilder;
  StepDurations: TStringList;
  I: Integer;
  TotalDuration, MaxDuration: Int64;
  MaxStep: string;
begin
  SB := TStringBuilder.Create;
  StepDurations := TStringList.Create;
  try
    TotalDuration := 0;
    MaxDuration := 0;
    MaxStep := '';
    
    // 收集每个步骤的耗时
    for I := 0 to High(Entries) do
    begin
      if (Entries[I].Action = 'exit') and (Entries[I].Duration > 0) then
      begin
        StepDurations.Values[Entries[I].StepId] := IntToStr(Entries[I].Duration);
        TotalDuration := TotalDuration + Entries[I].Duration;
        
        if Entries[I].Duration > MaxDuration then
        begin
          MaxDuration := Entries[I].Duration;
          MaxStep := Entries[I].StepId;
        end;
      end;
    end;
    
    SB.AppendLine('# Performance Report');
    SB.AppendLine;
    SB.AppendFormat('**Total Duration:** %s', [FormatDuration(TotalDuration)]).AppendLine;
    SB.AppendFormat('**Steps Executed:** %d', [StepDurations.Count]).AppendLine;
    if MaxStep <> '' then
      SB.AppendFormat('**Slowest Step:** %s (%s)', [MaxStep, FormatDuration(MaxDuration)]).AppendLine;
    SB.AppendLine;
    
    SB.AppendLine('## Step Durations');
    SB.AppendLine;
    for I := 0 to StepDurations.Count - 1 do
    begin
      SB.AppendFormat('- `%s`: %s', 
        [StepDurations.Names[I], FormatDuration(StrToInt64(StepDurations.ValueFromIndex[I]))]).AppendLine;
    end;
    
    Result := SB.ToString;
  finally
    StepDurations.Free;
    SB.Free;
  end;
end;

// ============================================================================
// 便捷函数
// ============================================================================

function CreateTraceExporter: TTraceExporter;
begin
  Result := TTraceExporter.Create;
end;

function QuickExportTrace(Format: TExportFormat): string;
var
  Exporter: TTraceExporter;
begin
  Exporter := TTraceExporter.Create;
  try
    Result := Exporter.ExportTraceEntries(Diagnostics.TraceEntries, Format);
  finally
    Exporter.Free;
  end;
end;

function QuickSaveSnapshot(const FileName: string): Boolean;
var
  Exporter: TTraceExporter;
  Snapshot: TExecutionSnapshot;
begin
  Result := False;
  Exporter := TTraceExporter.Create;
  try
    Snapshot := Exporter.CreateSnapshot(
      '', '', Diagnostics.CorrelationId, '',
      nil, nil, nil, Diagnostics.TraceEntries
    );
    Exporter.SaveSnapshotToFile(Snapshot, FileName);
    Result := True;
  finally
    Exporter.Free;
  end;
end;

end.
