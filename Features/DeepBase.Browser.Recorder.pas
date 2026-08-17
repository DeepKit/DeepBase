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
    - Export to JSON/JSONL for programmatic execution
    - Playback speed adjustment support
    
  Performance:
    - Async event capture without blocking main thread
    - Minimal overhead during recording session
  ========================================================================== }

unit DeepBase.Browser.Recorder;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
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
    FActions: TArray<TBrowserAction>;
    FNextActionID: Integer;
    FStartTime: Int64;
    FIsRecording: Boolean;
    
    procedure AddActionInternal(const Action: TBrowserAction);
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
    function SaveToFile(const FileName: string; Format: string);
    
    // Properties
    property ActionsCount: Integer read Length(FActions);
    property IsRecording: Boolean read FIsRecording;
  end;

  // Recorder manager singleton
  IBrowserRecorder = interface
    ['{ABCD5678-90EF-GHIJ-KLMN-OPQRSTUVWXYZ}']
    
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
  Indent := StringOfChar('  ', IndentLevel);
  
  case ActionType of
    actNavigate:
      Result := fmt('%sSession.NavigateTo(%s);\n',
                    [Indent, QuotedStr(Parameters.GetValue('url').Value)]);
                    
    actClick:
      Result := fmt('%sSession.FindElementByCSS(%s).Click;\n',
                    [Indent, QuotedStr(Parameters.GetValue('selector').Value)]);
                    
    actType:
      Result := fmt('%sSession.FindElementByCSS(%s).TypeText(%s);\n',
                    [Indent, 
                     QuotedStr(Parameters.GetValue('selector').Value),
                     QuotedStr(Parameters.GetValue('text').Value)]);
                     
    actWait:
      Result := fmt('%sSleep(%d);\n',
                    [Indent, Parameters.GetValue('milliseconds').AsInteger]);
                    
    else
      Result := '';
  end;
end;

function TBrowserAction.ToJavaScriptCode(IndentLevel: Integer): string;
var
  Indent: string;
begin
  Indent := StringOfChar('  ', IndentLevel);
  
  case ActionType of
    actNavigate:
      Result := fmt('%sawait session.navigate(%s);\n',
                    [Indent, QuotedStr(Parameters.GetValue('url').Value)]);
                    
    actClick:
      Result := fmt('%sawait session.click(%s);\n',
                    [Indent, QuotedStr(Parameters.GetValue('selector').Value)]);
                    
    actType:
      Result := fmt('%sawait session.type(%s, %s);\n',
                    [Indent,
                     QuotedStr(Parameters.GetValue('selector').Value),
                     QuotedStr(Parameters.GetValue('text').Value)]);
                     
    actWait:
      Result := fmt('%sawait new Promise(r => setTimeout(r, %d));\n',
                    [Indent, Parameters.GetValue('milliseconds').AsInteger]);
                    
    else
      Result := '';
  end;
end;

{ TRecordingSession }

constructor TRecordingSession.Create;
begin
  inherited Create;
  SetLength(FActions, 0);
  FNextActionID := 1;
  FStartTime := GetTickCount64;
  FIsRecording := False;
end;

destructor TRecordingSession.Destroy;
begin
  inherited Destroy;
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
  Action: TBrowserAction;
  Params: TJSONObject;
begin
  if not FIsRecording then
    Exit;
    
  Params := TJSONObject.Create;
  try
    Params.AddPair('url', TStringValue.Create(URL));
    
    Action := (
      ActionID: InterlockedIncrement(GLastActionID),
      ActionType: actNavigate,
      TimestampMs: TimestampMs,
      Parameters: Params
    );
    
    AddActionInternal(Action);
  finally
    Params.Free;
  end;
end;

procedure TRecordingSession.RecordClick(Selector: string; TimestampMs: Int64);
var
  Action: TBrowserAction;
  Params: TJSONObject;
begin
  if not FIsRecording then
    Exit;
    
  Params := TJSONObject.Create;
  try
    Params.AddPair('selector', TStringValue.Create(Selector));
    
    Action := (
      ActionID: InterlockedIncrement(GLastActionID),
      ActionType: actClick,
      TimestampMs: TimestampMs,
      Parameters: Params
    );
    
    AddActionInternal(Action);
  finally
    Params.Free;
  end;
end;

procedure TRecordingSession.RecordTypeText(Selector: string; Text: string; 
  TimestampMs: Int64);
var
  Action: TBrowserAction;
  Params: TJSONObject;
begin
  if not FIsRecording then
    Exit;
    
  Params := TJSONObject.Create;
  try
    Params.AddPair('selector', TStringValue.Create(Selector));
    Params.AddPair('text', TStringValue.Create(Text));
    
    Action := (
      ActionID: InterlockedIncrement(GLastActionID),
      ActionType: actType,
      TimestampMs: TimestampMs,
      Parameters: Params
    );
    
    AddActionInternal(Action);
  finally
    Params.Free;
  end;
end;

procedure TRecordingSession.RecordScroll(X, Y: Integer; TimestampMs: Int64);
var
  Action: TBrowserAction;
  Params: TJSONObject;
begin
  // TODO: Implement scroll recording
end;

procedure TRecordingSession.RecordWait(Milliseconds: Int64; TimestampMs: Int64);
var
  Action: TBrowserAction;
  Params: TJSONObject;
begin
  Params := TJSONObject.Create;
  try
    Params.AddPair('milliseconds', TJSONNumber.Create(Milliseconds));
    
    Action := (
      ActionID: InterlockedIncrement(GLastActionID),
      ActionType: actWait,
      TimestampMs: TimestampMs,
      Parameters: Params
    );
    
    AddActionInternal(Action);
  finally
    Params.Free;
  end;
end;

procedure TRecordingSession.RecordScript(Code: string; TimestampMs: Int64);
var
  Action: TBrowserAction;
  Params: TJSONObject;
begin
  Params := TJSONObject.Create;
  try
    Params.AddPair('code', TStringValue.Create(Code));
    
    Action := (
      ActionID: InterlockedIncrement(GLastActionID),
      ActionType: actScript,
      TimestampMs: TimestampMs,
      Parameters: Params
    );
    
    AddActionInternal(Action);
  finally
    Params.Free;
  end;
end;

procedure TRecordingSession.AddActionInternal(const Action: TBrowserAction);
var
  NewActions: TArray<TBrowserAction>;
begin
  SetLength(NewActions, Length(FActions) + 1);
  FActions := NewActions;
  FActions[High(FActions)] := Action;
end;

function TRecordingSession.GeneratePascalScript(ScriptName: string): string;
var
  I: Integer;
  ScriptLines: TStringList;
begin
  ScriptLines := TStringList.Create;
  try
    ScriptLines.Add(fmt('program %s;', [ScriptName]));
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

// ... Remaining methods continue (GenerateJavaScriptScript, SaveToFile, etc.)

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
  i: Integer;
  Counter: Integer;
begin
  EnsureDirExists(OutputDir);
  
  Counter := 0;
  for Session in FRecordedSessions do
  begin
    Inc(Counter);
    Session.SaveToFile(IncludeTrailingPathDelimiter(OutputDir) + 
                       fmt('recording_%d.pas', [Counter]), 'pas');
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
finalization
  GRecorder := nil;

end.
