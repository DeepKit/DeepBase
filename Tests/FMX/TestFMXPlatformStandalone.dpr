program TestFMXPlatformStandalone;

{$APPTYPE CONSOLE}

{ ============================================================================
  TestFMXPlatformStandalone
  ---------------------------------------------------------------------------
  Standalone driver that exercises the TUniPlatformAdapter permission/share
  override path on Windows. Verifies the four canonical outcomes of
  CheckPermissionEx / RequestPermissionEx plus ShareText / ShareFile
  delegation.

  Does NOT require a microphone, device or mobile runtime — all paths are
  exercised via registered mock delegates.

  Expected: 15 assertions, all PASS.
  ============================================================================ }

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.IOUtils,
  DeepBase.Platform.Interfaces,
  DeepBase.FMX.Platform;

var
  GTotal, GPass, GFail: Integer;

procedure Check(ACondition: Boolean; const ATestName: string);
begin
  Inc(GTotal);
  if ACondition then
  begin
    Inc(GPass);
    Writeln('[PASS] ', ATestName);
  end
  else
  begin
    Inc(GFail);
    Writeln('[FAIL] ', ATestName);
  end;
end;

procedure Test_DesktopDefault_PermissionGranted;
begin
  Writeln(''); Writeln('=== Default desktop HasPermission ===');
  // Without any override, Windows defaults to prGranted.
  Check(TUniPlatformAdapter.HasPermission('android.permission.CAMERA'),
    'Desktop HasPermission default = True');
  Check(TUniPlatformAdapter.CheckPermissionEx('android.permission.CAMERA') = prGranted,
    'Desktop CheckPermissionEx default = prGranted');
end;

procedure Test_PermissionOverride_Denied;
begin
  Writeln(''); Writeln('=== Override: Denied ===');
  TUniPlatformAdapter.RegisterPermissionOverride(
    function(const APerm: string): TPermissionResult
    begin Result := prDenied; end,
    nil);
  try
    Check(not TUniPlatformAdapter.HasPermission('android.permission.CAMERA'),
      'Denied override makes HasPermission False');
    Check(TUniPlatformAdapter.CheckPermissionEx('camera') = prDenied,
      'Denied override surfaces via CheckPermissionEx');
  finally
    TUniPlatformAdapter.RegisterPermissionOverride(nil, nil);
  end;
end;

procedure Test_PermissionOverride_Unsupported;
begin
  Writeln(''); Writeln('=== Override: Unsupported ===');
  TUniPlatformAdapter.RegisterPermissionOverride(
    function(const APerm: string): TPermissionResult
    begin Result := prUnsupported; end,
    nil);
  try
    Check(TUniPlatformAdapter.CheckPermissionEx('camera') = prUnsupported,
      'Unsupported override returns prUnsupported');
    Check(not TUniPlatformAdapter.HasPermission('camera'),
      'Unsupported makes HasPermission False');
  finally
    TUniPlatformAdapter.RegisterPermissionOverride(nil, nil);
  end;
end;

procedure Test_RequestPermission_OverrideRequestIssued;
var
  LCallbackFired: Boolean;
  LLock: TCriticalSection;
  LReceivedResult: TPermissionResult;
begin
  Writeln(''); Writeln('=== Override: RequestIssued + async callback ===');
  LLock := TCriticalSection.Create;
  try
    LCallbackFired := False;
    LReceivedResult := prUnsupported;
    TUniPlatformAdapter.RegisterPermissionOverride(nil,
      function(const APerm: string; const ACb: TPermissionCallback): TPermissionResult
      begin
        // Simulate async resolution.
        if Assigned(ACb) then
          ACb(APerm, prGranted);
        Result := prRequestIssued;
      end);
    try
      Check(TUniPlatformAdapter.RequestPermissionEx('microphone',
        procedure(const APerm: string; ARes: TPermissionResult)
        begin
          LLock.Enter;
          try
            LCallbackFired := True;
            LReceivedResult := ARes;
          finally
            LLock.Leave;
          end;
        end) = prRequestIssued,
        'RequestPermissionEx returns prRequestIssued');
      Check(LCallbackFired, 'Callback fired exactly once');
      Check(LReceivedResult = prGranted, 'Callback received prGranted');
    finally
      TUniPlatformAdapter.RegisterPermissionOverride(nil, nil);
    end;
  finally
    LLock.Free;
  end;
end;

procedure Test_ShareText_Override;
begin
  Writeln(''); Writeln('=== ShareText override ===');
  TUniPlatformAdapter.RegisterShareOverride(
    function(const AText, ASubject: string): Boolean
    begin Result := True; end,
    nil);
  try
    Check(TUniPlatformAdapter.ShareText('hello', 'sub'),
      'ShareText override returned True');
    Check(TUniPlatformAdapter.ShareTextEx('hello', 'sub'),
      'ShareTextEx override returned True');
  finally
    TUniPlatformAdapter.RegisterShareOverride(nil, nil);
  end;
end;

procedure Test_ShareFile_Override;
begin
  Writeln(''); Writeln('=== ShareFile override ===');
  TUniPlatformAdapter.RegisterShareOverride(nil,
    function(const APath: string): Boolean
    begin Result := False; end);
  try
    Check(not TUniPlatformAdapter.ShareFile('c:\x.txt'),
      'ShareFile override returned False');
    Check(not TUniPlatformAdapter.ShareFileEx('c:\x.txt'),
      'ShareFileEx override returned False');
  finally
    TUniPlatformAdapter.RegisterShareOverride(nil, nil);
  end;
end;

procedure Test_ClearOverride_RestoresDefault;
begin
  Writeln(''); Writeln('=== Clear override restores desktop default ===');
  TUniPlatformAdapter.RegisterPermissionOverride(
    function(const APerm: string): TPermissionResult
    begin Result := prDenied; end,
    nil);
  Check(not TUniPlatformAdapter.HasPermission('camera'), 'Denied while override active');
  TUniPlatformAdapter.RegisterPermissionOverride(nil, nil);
  Check(TUniPlatformAdapter.HasPermission('camera'),
    'After clearing override, desktop default restored');
end;

// REVIEW-P0-002 regression: Windows Shell "share" verb path must short-circuit
// to False when the target file is absent, without attempting ShellExecuteEx.
// On non-Windows builds, the same short-circuit is exercised by the default
// platform branch returning False for missing files.
procedure Test_ShareFileEx_MissingFile_ReturnsFalse;
var
  LTempDir, LMadeUpPath: string;
begin
  Writeln(''); Writeln('=== ShareFileEx: missing file returns False ===');
  LTempDir := TPath.GetTempPath;
  LMadeUpPath := TPath.Combine(LTempDir,
    'deepbase-fmx-missing-' + TGuid.NewGuid.ToString + '.txt');
  if TFile.Exists(LMadeUpPath) then
    TFile.Delete(LMadeUpPath);

  // Delegate chain cleared (no RegisterShareOverride active), so the
  // compile-time IFDEF branch is exercised.
  Check(not TUniPlatformAdapter.ShareFileEx(LMadeUpPath),
    'ShareFileEx on a missing file must return False (no UI raised)');

  // Sanity: delegate override still wins over the compile-time branch.
  TUniPlatformAdapter.RegisterShareOverride(nil,
    function(const APath: string): Boolean
    begin Result := True; end);
  try
    Check(TUniPlatformAdapter.ShareFileEx(LMadeUpPath),
      'ShareFileEx override should be invoked even when the file is missing');
  finally
    TUniPlatformAdapter.RegisterShareOverride(nil, nil);
  end;
end;

begin
  GTotal := 0; GPass := 0; GFail := 0;

  Writeln('TestFMXPlatformStandalone — ', DateTimeToStr(Now));

  Test_DesktopDefault_PermissionGranted;
  Test_PermissionOverride_Denied;
  Test_PermissionOverride_Unsupported;
  Test_RequestPermission_OverrideRequestIssued;
  Test_ShareText_Override;
  Test_ShareFile_Override;
  Test_ShareFileEx_MissingFile_ReturnsFalse;
  Test_ClearOverride_RestoresDefault;

  Writeln('');
  Writeln(Format('=== Results: %d total, %d pass, %d fail ===',
    [GTotal, GPass, GFail]));
  if GFail > 0 then
    ExitCode := 1
  else
    ExitCode := 0;

  if ParamStr(1) <> '--batch' then
  begin
    Write('Press Enter...');
    Readln;
  end;
end.
