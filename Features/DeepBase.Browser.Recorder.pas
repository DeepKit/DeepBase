{ ============================================================================
  DeepBase.Browser.Recorder
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : Macro recording engine that captures browser navigation,
                clicks, and form inputs, generating human-readable playback
                scripts in Pascal or JavaScript format.
  
  Features:
    - Record user interactions with timestamps
    - Generate Pascal/Delphi script files
    - Save generated scripts to disk by format
    
  Performance:
    - Async event capture without blocking main thread
    - Minimal overhead during recording session
  ========================================================================== }

unit DeepBase.Browser.Recorder;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.TypInfo,
  System.Generics.Collections,
  Winapi.Windows,
  DeepBase.Browser.Session;

type
  // Recorded action types
  TActionType = (
    actNavigate,        // NavigateTo(URL)
    actClick,           // Click(selector)
    actType,            // TypeText(selector, text)
    actScroll,          // Scroll(x, y)
    actWait,            // Wait(milliseconds)
    actScript           // ExecuteJS(code)
  );

  // Single recorded action record
  TBrowserAction = record
    ActionID: Integer;      // Unique action identifier
    ActionType: TActionType;
    TimestampMs: Int64;     // Time relative to start of session
    Parameters: TJSONObject;// Flexible parameters storage
    
    function ToPascalCode(IndentLevel: Integer): string;
    function ToJavaScriptCode(IndentLevel: Integer): string;
  end;

  // Recording session state
  TRecordingSession = class(TObject)
  private
    // Parameters 由会话拥有（见 AddActionInternal 入口克隆），出口在 Destroy 统一释放
    FActions: TArray<TBrowserAction>;
    FStartTime: Int64;
    FIsRecording: Boolean;

    procedure AddActionInternal(const Action: TBrowserAction);
    function GetActionsCount: Integer;
    function MakeAction(AType: TActionType; ATimestampMs: Int64;
      AParams: TJSONObject): TBrowserAction;
  public
    constructor Create;
    destructor Destroy; override;

    procedure StartRecording;
    procedure StopRecording;

    // Action capture methods
    procedure RecordNavigate(URL: string; TimestampMs: Int64);
    procedure RecordClick(Selector: string; TimestampMs: Int64);
    procedure RecordTypeText(Selector: string; Text: string; TimestampMs: Int64);
    procedure RecordScroll(X, Y: Integer; TimestampMs: Int64);
    procedure RecordWait(Milliseconds: Int64; TimestampMs: Int64);
    procedure RecordScript(Code: string; TimestampMs: Int64);

    // Export methods
    function GeneratePascalScript(ScriptName: string): string;
    function GenerateJavaScriptScript(ScriptName: string): string;
    function SaveToFile(const FileName: string; const AFormat: string): string;

    // Properties
    property ActionsCount: Integer read GetActionsCount;
    property IsRecording: Boolean read FIsRecording;
  end;

  // Recorder manager singleton
  IBrowserRecorder = interface
    ['{4A2E5C31-7B64-4B0E-9E2D-5F0A8C61D937}']
    
    // Session management
    function StartNewSession: TRecordingSession;
    function GetCurrentSession: TRecordingSession;
    procedure EndCurrentSession;
    
    // Batch export
    procedure ExportAllSessionsToDirectory(const OutputDir: string);
  end;

  TBrowserRecorderManager = class(TInterfacedObject, IBrowserRecorder)
  private
    FCurrentSession: TRecordingSession;
    FRecordedSessions: TObjectList<TRecordingSession>;
  public
    constructor Create;
    destructor Destroy; override;
    
    // IBrowserRecorder implementation
    function StartNewSession: TRecordingSession;
    function GetCurrentSession: TRecordingSession;
    procedure EndCurrentSession;
    procedure ExportAllSessionsToDirectory(const OutputDir: string);
  end;

// Global accessor
procedure InitializeBrowserRecorder;
function CurrentBrowserRecorder: IBrowserRecorder;

implementation

var
  GRecorder: IBrowserRecorder = nil;
  GLastActionID: Integer = 0;

{ TBrowserAction }

function TBrowserAction.ToPascalCode(IndentLevel: Integer): string;
var
  Indent: string;
begin
  Indent := StringOfChar(' ', IndentLevel);

  case ActionType of
    actNavigate:
      Result := Format('%sSession.NavigateTo(%s);' + sLineBreak,
                    [Indent, QuotedStr(Parameters.GetValue('url').Value)]);

    actClick:
      Result := Format('%sSession.FindElementByCSS(%s).Click;' + sLineBreak,
                    [Indent, QuotedStr(Parameters.GetValue('selector').Value)]);

    actType:
      Result := Format('%sSession.FindElementByCSS(%s).TypeText(%s);' + sLineBreak,
                    [Indent,
                     QuotedStr(Parameters.GetValue('selector').Value),
                     QuotedStr(Parameters.GetValue('text').Value)]);

    actWait:
      Result := Format('%sSleep(%d);' + sLineBreak,
                    [Indent, Parameters.GetValue<Int64>('milliseconds')]);

    else
      // 录到了但生成器没有对应写法（actScroll/actScript）：显式留在导出文本里，
      // 静默返回空串会让导出的宏悄悄少动作，看起来却像"完整录制"。
      Result := Format('%s// UNSUPPORTED RECORDED ACTION: %s (ActionID=%d)' + sLineBreak,
                    [Indent, GetEnumName(TypeInfo(TActionType), Ord(ActionType)), ActionID]);
  end;
end;

function TBrowserAction.ToJavaScriptCode(IndentLevel: Integer): string;
var
  Indent: string;
begin
  Indent := StringOfChar(' ', IndentLevel);

  case ActionType of
    actNavigate:
      Result := Format('%sawait session.navigate(%s);' + sLineBreak,
                    [Indent, QuotedStr(Parameters.GetValue('url').Value)]);

    actClick:
      Result := Format('%sawait session.click(%s);' + sLineBreak,
                    [Indent, QuotedStr(Parameters.GetValue('selector').Value)]);

    actType:
      Result := Format('%sawait session.type(%s, %s);' + sLineBreak,
                    [Indent,
                     QuotedStr(Parameters.GetValue('selector').Value),
                     QuotedStr(Parameters.GetValue('text').Value)]);

    actWait:
      Result := Format('%sawait new Promise(r => setTimeout(r, %d));' + sLineBreak,
                    [Indent, Parameters.GetValue<Int64>('milliseconds')]);

    else
      Result := Format('%s// UNSUPPORTED RECORDED ACTION: %s (ActionID=%d)' + sLineBreak,
                    [Indent, GetEnumName(TypeInfo(TActionType), Ord(ActionType)), ActionID]);
  end;
end;

{ TRecordingSession }

constructor TRecordingSession.Create;
begin
  inherited Create;
  SetLength(FActions, 0);
  FStartTime := GetTickCount64;
  FIsRecording := False;
end;

destructor TRecordingSession.Destroy;
var
  I: Integer;
begin
  // 与 AddActionInternal 的入口克隆配对：会话是 Parameters 的唯一所有者，出口只在这里
  for I := Low(FActions) to High(FActions) do
    FActions[I].Parameters.Free;
  SetLength(FActions, 0);
  inherited Destroy;
end;

function TRecordingSession.GetActionsCount: Integer;
begin
  Result := Length(FActions);
end;

function TRecordingSession.MakeAction(AType: TActionType; ATimestampMs: Int64;
  AParams: TJSONObject): TBrowserAction;
begin
  // 六个 Record* 共用一个装配点：ActionID 只有一个来源（GLastActionID），
  // Parameters 的所有权仍留在调用方（本函数只拷引用，克隆发生在 AddActionInternal）。
  Result.ActionID := InterlockedIncrement(GLastActionID);
  Result.ActionType := AType;
  Result.TimestampMs := ATimestampMs;
  Result.Parameters := AParams;
end;

procedure TRecordingSession.StartRecording;
begin
  FIsRecording := True;
  FStartTime := GetTickCount64;
end;

procedure TRecordingSession.StopRecording;
begin
  FIsRecording := False;
end;

procedure TRecordingSession.RecordNavigate(URL: string; TimestampMs: Int64);
var
  Params: TJSONObject;
begin
  if not FIsRecording then
    Exit;

  Params := TJSONObject.Create;
  try
    Params.AddPair('url', TJSONString.Create(URL));
    AddActionInternal(MakeAction(actNavigate, TimestampMs, Params));
  finally
    Params.Free;
  end;
end;

procedure TRecordingSession.RecordClick(Selector: string; TimestampMs: Int64);
var
  Params: TJSONObject;
begin
  if not FIsRecording then
    Exit;

  Params := TJSONObject.Create;
  try
    Params.AddPair('selector', TJSONString.Create(Selector));
    AddActionInternal(MakeAction(actClick, TimestampMs, Params));
  finally
    Params.Free;
  end;
end;

procedure TRecordingSession.RecordTypeText(Selector: string; Text: string;
  TimestampMs: Int64);
var
  Params: TJSONObject;
begin
  if not FIsRecording then
    Exit;

  Params := TJSONObject.Create;
  try
    Params.AddPair('selector', TJSONString.Create(Selector));
    Params.AddPair('text', TJSONString.Create(Text));
    AddActionInternal(MakeAction(actType, TimestampMs, Params));
  finally
    Params.Free;
  end;
end;

procedure TRecordingSession.RecordScroll(X, Y: Integer; TimestampMs: Int64);
var
  Params: TJSONObject;
begin
  if not FIsRecording then
    Exit;

  Params := TJSONObject.Create;
  try
    Params.AddPair('x', TJSONNumber.Create(X));
    Params.AddPair('y', TJSONNumber.Create(Y));
    AddActionInternal(MakeAction(actScroll, TimestampMs, Params));
  finally
    Params.Free;
  end;
end;

procedure TRecordingSession.RecordWait(Milliseconds: Int64; TimestampMs: Int64);
var
  Params: TJSONObject;
begin
  // 六个 Record* 一律先判 FIsRecording：停止录制后仍继续入队会让"已停"与"仍在记"
  // 两个状态并存（旧实现里 Wait/Script 两条漏了这道门）。
  if not FIsRecording then
    Exit;

  Params := TJSONObject.Create;
  try
    Params.AddPair('milliseconds', TJSONNumber.Create(Milliseconds));
    AddActionInternal(MakeAction(actWait, TimestampMs, Params));
  finally
    Params.Free;
  end;
end;

procedure TRecordingSession.RecordScript(Code: string; TimestampMs: Int64);
var
  Params: TJSONObject;
begin
  if not FIsRecording then
    Exit;

  Params := TJSONObject.Create;
  try
    Params.AddPair('code', TJSONString.Create(Code));
    AddActionInternal(MakeAction(actScript, TimestampMs, Params));
  finally
    Params.Free;
  end;
end;

procedure TRecordingSession.AddActionInternal(const Action: TBrowserAction);
var
  Stored: TBrowserAction;
begin
  // B2-03 所有权单一化：入参的 Parameters 归调用方（各 Record* 在 finally 里 Free），
  // 旧实现直接存引用 ⇒ 会话里留下的每一条动作都指向已释放对象，回放/导出阶段读取
  // Parameters 即 UAF。这里在唯一入口做深拷贝，会话成为自己那份的唯一所有者
  // （释放点见 Destroy）。
  Stored := Action;
  if Action.Parameters <> nil then
    Stored.Parameters := Action.Parameters.Clone as TJSONObject
  else
    Stored.Parameters := nil;
  // 旧写法把未赋值的局部新数组整体盖回 FActions ⇒ 每次追加都丢掉之前的所有动作
  SetLength(FActions, Length(FActions) + 1);
  FActions[High(FActions)] := Stored;
end;

function TRecordingSession.GeneratePascalScript(ScriptName: string): string;
var
  I: Integer;
  ScriptLines: TStringList;
begin
  ScriptLines := TStringList.Create;
  try
    ScriptLines.Add(Format('program %s;', [ScriptName]));
    ScriptLines.Add('');
    ScriptLines.Add('uses');
    ScriptLines.Add('  System.SysUtils,');
    ScriptLines.Add('  DeepBase.Browser.Session;');
    ScriptLines.Add('');
    ScriptLines.Add('var');
    ScriptLines.Add('  Session: IBrowserSession;');
    ScriptLines.Add('begin');
    ScriptLines.Add('  Session := CreateBrowserSession;');
    ScriptLines.Add('  try');
    ScriptLines.Add('');
    
    for I := Low(FActions) to High(FActions) do
      ScriptLines.Add(FActions[I].ToPascalCode(3));
      
    ScriptLines.Add('  finally');
    ScriptLines.Add('    Session.Close;');
    ScriptLines.Add('  end;');
    ScriptLines.Add('end.');
    
    Result := ScriptLines.Text;
  finally
    ScriptLines.Free;
  end;
end;

function TRecordingSession.GenerateJavaScriptScript(ScriptName: string): string;
var
  I: Integer;
  ScriptLines: TStringList;
begin
  ScriptLines := TStringList.Create;
  try
    ScriptLines.Add('// Auto-generated by DeepBase.Browser.Recorder');
    ScriptLines.Add(Format('// Script: %s', [ScriptName]));
    ScriptLines.Add('''use strict'';');
    ScriptLines.Add('');
    ScriptLines.Add('async function run(session) {');

    for I := Low(FActions) to High(FActions) do
      ScriptLines.Add(FActions[I].ToJavaScriptCode(2));

    ScriptLines.Add('}');
    ScriptLines.Add('');
    ScriptLines.Add('module.exports = { run };');

    Result := ScriptLines.Text;
  finally
    ScriptLines.Free;
  end;
end;

function TRecordingSession.SaveToFile(const FileName: string;
  const AFormat: string): string;
var
  Script: string;
begin
  // 格式分派保持单一入口；未知格式直接报错，不静默写成 Pascal（导出内容错了比导不出来更难查）
  if SameText(AFormat, 'pas') or SameText(AFormat, 'pascal') then
    Script := GeneratePascalScript(TPath.GetFileNameWithoutExtension(FileName))
  else if SameText(AFormat, 'js') or SameText(AFormat, 'javascript') then
    Script := GenerateJavaScriptScript(TPath.GetFileNameWithoutExtension(FileName))
  else
    raise EArgumentException.Create('Unsupported recording format: ' + AFormat);

  TFile.WriteAllText(FileName, Script, TEncoding.UTF8);
  Result := FileName;
end;

{ TBrowserRecorderManager }

constructor TBrowserRecorderManager.Create;
begin
  inherited Create;
  FCurrentSession := nil;
  FRecordedSessions := TObjectList<TRecordingSession>.Create(True);
end;

destructor TBrowserRecorderManager.Destroy;
begin
  FRecordedSessions.Free;
  inherited Destroy;
end;

function TBrowserRecorderManager.StartNewSession: TRecordingSession;
begin
  // Finalize previous session if any
  if Assigned(FCurrentSession) then
  begin
    FCurrentSession.StopRecording;
    FRecordedSessions.Add(FCurrentSession);
  end;
  
  FCurrentSession := TRecordingSession.Create;
  FCurrentSession.StartRecording;
  Result := FCurrentSession;
end;

function TBrowserRecorderManager.GetCurrentSession: TRecordingSession;
begin
  Result := FCurrentSession;
end;

procedure TBrowserRecorderManager.EndCurrentSession;
begin
  if Assigned(FCurrentSession) then
  begin
    FCurrentSession.StopRecording;
    FRecordedSessions.Add(FCurrentSession);
    FCurrentSession := nil;
  end;
end;

procedure TBrowserRecorderManager.ExportAllSessionsToDirectory(
  const OutputDir: string);
var
  Session: TRecordingSession;
  Counter: Integer;
begin
  ForceDirectories(OutputDir);

  Counter := 0;
  for Session in FRecordedSessions do
  begin
    Inc(Counter);
    Session.SaveToFile(IncludeTrailingPathDelimiter(OutputDir) +
                       Format('recording_%d.pas', [Counter]), 'pas');
  end;
end;

// Global initialization
procedure InitializeBrowserRecorder;
begin
  if not Assigned(GRecorder) then
    GRecorder := TBrowserRecorderManager.Create;
end;

function CurrentBrowserRecorder: IBrowserRecorder;
begin
  if not Assigned(GRecorder) then
    InitializeBrowserRecorder;
    
  Result := GRecorder;
end;

initialization
  // 空段是语法要求：finalization 必须挂在 initialization 之后，删掉这行就编不过
finalization
  GRecorder := nil;

end.
