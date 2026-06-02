{ ============================================================================
  DeepBase.AutoFix.HealthSignal

  Writes health-signal.json once after the application is fully initialized.
  The external runner polls this file (matching run_id) to confirm the EXE
  started successfully.

  Usage: call TAutoFixHealthSignal.Emit after the shell is shown
  (e.g. AfterShellShown) -- or via AutoFix.NotifyShellShown facade.

  See: design v2.0 §3.3 / §4.1
  ============================================================================ }

unit DeepBase.AutoFix.HealthSignal;

interface

uses
  System.SysUtils;

type
  TAutoFixHealthSignal = class
  public
    /// <summary>Write health-signal.json. Call once after the app is ready.</summary>
    class procedure Emit;
    /// <summary>Read FileVersion from this EXE's VersionInfo resource. Returns
    /// 'unknown' on failure.</summary>
    class function ReadOwnVersion: string;
  end;

implementation

uses
  System.IOUtils,
  System.Classes,
  Winapi.Windows,
  DeepBase.AutoFix.ErrorRecorder;

{ Version.dll imports (declared locally to avoid pulling Winapi.WinVer) }

function GetFileVersionInfoSizeW(lptstrFilename: PWideChar;
  lpdwHandle: PDWORD): DWORD; stdcall;
  external 'version.dll' name 'GetFileVersionInfoSizeW';

function GetFileVersionInfoW(lptstrFilename: PWideChar;
  dwHandle, dwLen: DWORD; lpData: Pointer): BOOL; stdcall;
  external 'version.dll' name 'GetFileVersionInfoW';

function VerQueryValueW(pBlock: Pointer; lpSubBlock: PWideChar;
  out lplpBuffer: Pointer; out puLen: UINT): BOOL; stdcall;
  external 'version.dll' name 'VerQueryValueW';

type
  PVSFixedFileInfo = ^TVSFixedFileInfo;
  TVSFixedFileInfo = record
    dwSignature: DWORD;
    dwStrucVersion: DWORD;
    dwFileVersionMS: DWORD;
    dwFileVersionLS: DWORD;
    dwProductVersionMS: DWORD;
    dwProductVersionLS: DWORD;
    dwFileFlagsMask: DWORD;
    dwFileFlags: DWORD;
    dwFileOS: DWORD;
    dwFileType: DWORD;
    dwFileSubtype: DWORD;
    dwFileDateMS: DWORD;
    dwFileDateLS: DWORD;
  end;

function EscapeJson(const S: string): string;
begin
  Result := S;
  Result := Result.Replace('\', '\\');
  Result := Result.Replace('"', '\"');
  Result := Result.Replace(#13, '\r');
  Result := Result.Replace(#10, '\n');
  Result := Result.Replace(#9, '\t');
end;

{ TAutoFixHealthSignal }

class function TAutoFixHealthSignal.ReadOwnVersion: string;
var
  LFile: string;
  LSize, LHandle: DWORD;
  LBuf: TBytes;
  LFixed: PVSFixedFileInfo;
  LFixedLen: UINT;
  LPtr: Pointer;
begin
  Result := 'unknown';
  try
    LFile := ParamStr(0);
    if LFile = '' then Exit;

    LHandle := 0;
    LSize := GetFileVersionInfoSizeW(PWideChar(LFile), @LHandle);
    if LSize = 0 then Exit;

    SetLength(LBuf, LSize);
    if not GetFileVersionInfoW(PWideChar(LFile), 0, LSize, @LBuf[0]) then Exit;

    LPtr := nil;
    LFixedLen := 0;
    if not VerQueryValueW(@LBuf[0], '\', LPtr, LFixedLen) then Exit;
    if (LPtr = nil) or (LFixedLen < SizeOf(TVSFixedFileInfo)) then Exit;

    LFixed := PVSFixedFileInfo(LPtr);
    Result := Format('%d.%d.%d.%d', [
      HiWord(LFixed^.dwFileVersionMS),
      LoWord(LFixed^.dwFileVersionMS),
      HiWord(LFixed^.dwFileVersionLS),
      LoWord(LFixed^.dwFileVersionLS)]);
  except
    Result := 'unknown';
  end;
end;

class procedure TAutoFixHealthSignal.Emit;
var
  LScenarios: string;
begin
  if not TAutoFixErrorRecorder.Active then Exit;

  LScenarios := '';
  for var I := 1 to ParamCount do
  begin
    var LParam := ParamStr(I);
    if LParam.StartsWith('--autofix-scenario=', True) then
    begin
      var LNames := LParam.Substring(Length('--autofix-scenario=')).Split([',']);
      for var J := 0 to High(LNames) do
      begin
        if J > 0 then LScenarios := LScenarios + ',';
        LScenarios := LScenarios + '"' + EscapeJson(LNames[J]) + '"';
      end;
    end;
  end;

  var LVersion := ReadOwnVersion;

  var LBuilder := TStringBuilder.Create;
  try
    LBuilder
      .Append('{"run_id":"').Append(EscapeJson(TAutoFixErrorRecorder.RunId)).Append('"')
      .Append(',"ready":true')
      .Append(',"pid":').Append(GetCurrentProcessId)
      .Append(',"timestamp":"')
        .Append(FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"+08:00"', Now)).Append('"')
      .Append(',"version":"').Append(EscapeJson(LVersion)).Append('"')
      .Append(',"autofix_mode":true')
      .Append(',"scenarios":[').Append(LScenarios).Append(']')
      .Append('}');

    var LPath := TPath.Combine(TAutoFixErrorRecorder.OutputDir, 'health-signal.json');
    var LTmpPath := LPath + '.tmp';
    TFile.WriteAllText(LTmpPath, LBuilder.ToString, TEncoding.UTF8);
    if TFile.Exists(LPath) then
      TFile.Delete(LPath);
    TFile.Move(LTmpPath, LPath);
  finally
    LBuilder.Free;
  end;
end;

end.
