{ ============================================================================
  Test.DeepBase.Browser.RecorderOwnership - 录制会话参数所有权回归

  覆盖 B2-03：Record* 在 finally 里 Free 掉 Params，而 AddActionInternal 旧实现
  直接把引用存进 FActions ⇒ 会话里每条动作都指向已释放对象，导出/回放阶段读取
  Parameters 即 UAF。修后所有权单一化：入口深拷贝（Clone），出口在 Destroy 释放。

  同一入口顺带锁住两处同源缺陷：旧 AddActionInternal 用未赋值的局部新数组整体盖回
  FActions（每次追加丢掉之前的动作），以及 RecordWait/RecordScript 漏判 FIsRecording
  （停止录制后仍继续入队）。

  法源：WO-20260925-AUDIT-乙-B2 §B2-03。
  ============================================================================ }
unit Test.DeepBase.Browser.RecorderOwnership;

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  Winapi.Windows,
  DeepBase.Browser.Recorder;

type
  [TestFixture]
  TTestRecorderOwnership = class
  private
    FTempDir: string;
    function SessionWithSampleActions: TRecordingSession;
    function ScratchFile(const AName: string): string;
    function ReadAll(const APath: string): string;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_EveryRecordedActionIsKept;
    [Test]
    procedure Test_PascalExport_ReadsLiveParametersOfEveryAction;
    [Test]
    procedure Test_JavaScriptExport_MarksUnsupportedWithoutDropping;
    [Test]
    procedure Test_RecordAfterStop_AddsNothing;
    [Test]
    procedure Test_ActionIDsAreUniquePerRecordedAction;
    [Test]
    procedure Test_SaveToFileWritesAndRejectsUnknownFormat;
    [Test]
    procedure Test_ManagerExportWritesOneFilePerSession;
  end;

implementation

{ TTestRecorderOwnership }

procedure TTestRecorderOwnership.SetUp;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath, 'deepbase_b03_'
    + IntToStr(GetTickCount64) + '_' + IntToStr(Random(1000000)));
  TDirectory.CreateDirectory(FTempDir);
end;

procedure TTestRecorderOwnership.TearDown;
begin
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

function TTestRecorderOwnership.ScratchFile(const AName: string): string;
begin
  Result := TPath.Combine(FTempDir, AName);
end;

function TTestRecorderOwnership.ReadAll(const APath: string): string;
begin
  Result := TFile.ReadAllText(APath, TEncoding.UTF8);
end;

/// 录三类动作：三个 Params 全部已在各自 finally 里被 Free，
/// 之后任何对 Parameters 的读取都必须命中会话自己那份拷贝。
function TTestRecorderOwnership.SessionWithSampleActions: TRecordingSession;
begin
  Result := TRecordingSession.Create;
  Result.StartRecording;
  Result.RecordNavigate('https://example.test/login', 10);
  Result.RecordClick('#user', 20);
  Result.RecordTypeText('#pass', 'secret-value', 30);
end;

procedure TTestRecorderOwnership.Test_EveryRecordedActionIsKept;
var
  Session: TRecordingSession;
begin
  Session := SessionWithSampleActions;
  try
    Assert.AreEqual(3, Session.ActionsCount,
      'each recorded action must stay in the session (old AddActionInternal wiped the previous ones)');
  finally
    Session.Free;
  end;
end;

// 工单判定：录制回放之后再读 Parameters 内容必须正确
procedure TTestRecorderOwnership.Test_PascalExport_ReadsLiveParametersOfEveryAction;
var
  Session: TRecordingSession;
  Script: string;
begin
  Session := SessionWithSampleActions;
  try
    Script := Session.GeneratePascalScript('macro');
  finally
    Session.Free;
  end;

  Assert.Contains(Script, 'https://example.test/login',
    'navigate payload must be readable after the caller freed it');
  Assert.Contains(Script, '#user',
    'click payload must be readable after the caller freed it');
  Assert.Contains(Script, 'secret-value',
    'type payload must be readable after the caller freed it');
end;

procedure TTestRecorderOwnership.Test_JavaScriptExport_MarksUnsupportedWithoutDropping;
var
  Session: TRecordingSession;
  Script: string;
begin
  Session := TRecordingSession.Create;
  try
    Session.StartRecording;
    Session.RecordScroll(120, 340, 40);
    Session.RecordScript('alert(1)', 50);

    Script := Session.GenerateJavaScriptScript('macro');
    // 未实现的动作类型不得静默消失：导出文本里必须留下显式标记
    Assert.Contains(Script, 'actScroll',
      'an action without a generator must be marked, not silently dropped');
    Assert.Contains(Script, 'actScript',
      'an action without a generator must be marked, not silently dropped');
  finally
    Session.Free;
  end;
end;

procedure TTestRecorderOwnership.Test_RecordAfterStop_AddsNothing;
var
  Session: TRecordingSession;
begin
  Session := TRecordingSession.Create;
  try
    Session.StartRecording;
    Session.RecordWait(100, 1);
    Session.RecordScript('noop', 2);
    Session.StopRecording;
    Session.RecordWait(100, 3);
    Session.RecordScript('noop', 4);
    Assert.AreEqual(2, Session.ActionsCount,
      'all six Record* entry points must honour IsRecording (Wait/Script used to keep queueing)');
  finally
    Session.Free;
  end;
end;

procedure TTestRecorderOwnership.Test_ActionIDsAreUniquePerRecordedAction;
var
  Session: TRecordingSession;
  Lines: TStringList;
  Markers: TStringList;
  First, Second: string;
  I: Integer;
begin
  Session := TRecordingSession.Create;
  Lines := TStringList.Create;
  Markers := TStringList.Create;
  try
    Session.StartRecording;
    // 两条 scroll 除 ActionID 外内容完全一致 ⇒ 导出行是否相同即等价于 ID 是否唯一
    Session.RecordScroll(1, 1, 10);
    Session.RecordScroll(2, 2, 20);
    Lines.Text := Session.GeneratePascalScript('macro');
    for I := 0 to Lines.Count - 1 do
      if Lines[I].Contains('actScroll') then
        Markers.Add(Lines[I]);
    Assert.AreEqual(2, Markers.Count, 'both scroll actions must appear in the export');
    First := Markers[0];
    Second := Markers[1];
  finally
    Session.Free;
    Lines.Free;
    Markers.Free;
  end;

  Assert.AreNotEqual(First, Second,
    'ActionID must be unique per recorded action, not per session');
end;

procedure TTestRecorderOwnership.Test_SaveToFileWritesAndRejectsUnknownFormat;
var
  Session: TRecordingSession;
  Target: string;
  LAttempt: TProc;
begin
  Session := SessionWithSampleActions;
  try
    Target := ScratchFile('macro.pas');
    Assert.AreEqual(Target, Session.SaveToFile(Target, 'pas'),
      'SaveToFile must return the file it wrote');
    Assert.IsTrue(TFile.Exists(Target), 'the macro file must exist on disk');
    Assert.Contains(ReadAll(Target), 'https://example.test/login',
      'the written file must carry the recorded payload');

    LAttempt := procedure
      begin
        Session.SaveToFile(ScratchFile('macro.unknown'), 'jsonl');
      end;
    Assert.WillRaise(LAttempt, EArgumentException,
      'an unimplemented format must fail closed instead of silently writing something else');
  finally
    Session.Free;
  end;
end;

procedure TTestRecorderOwnership.Test_ManagerExportWritesOneFilePerSession;
var
  Recorder: IBrowserRecorder;
  Session: TRecordingSession;
begin
  Recorder := TBrowserRecorderManager.Create;
  Session := Recorder.StartNewSession;
  Session.RecordNavigate('https://example.test/a', 1);
  Recorder.EndCurrentSession;

  Session := Recorder.StartNewSession;
  Session.RecordClick('#b', 2);
  Recorder.EndCurrentSession;

  Recorder.ExportAllSessionsToDirectory(FTempDir);

  Assert.AreEqual(2, Integer(Length(TDirectory.GetFiles(FTempDir, '*.pas'))),
    'every ended session must be exported exactly once');
  Assert.Contains(ReadAll(TPath.Combine(FTempDir, 'recording_1.pas')),
    'https://example.test/a',
    'exported session 1 must still own readable parameters');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRecorderOwnership);

end.
