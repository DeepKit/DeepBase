{ ============================================================================
  DeepBase.AutoFix.StackWalker

  Captures call-stack frames as (module_name, module_base, rva) tuples using
  Windows RtlCaptureStackBackTrace + GetModuleHandleEx. No JCL / MadExcept.

  Returned RVA values are stable across runs of the same binary, which is
  what the external AutoFix loop needs for .map resolution.

  Target: Delphi 13.1 (CompilerVersion 37). Win32 / Win64.
  ============================================================================ }

unit DeepBase.AutoFix.StackWalker;

interface

uses
  Winapi.Windows,
  System.SysUtils;

type
  TStackFrame = record
    ModuleName: string;
    ModuleBase: NativeUInt;
    Rva: NativeUInt;
  end;

/// <summary>Capture the current call stack starting <c>ASkip</c> frames above
/// the caller, up to <c>AMaxFrames</c> entries. Sets <c>ATruncated</c> to true
/// when the actual depth exceeds <c>AMaxFrames</c>.</summary>
function CaptureStack(ASkip: Integer; AMaxFrames: Integer;
  out ATruncated: Boolean): TArray<TStackFrame>;

/// <summary>Resolve a single absolute address to module + base + RVA.</summary>
function ResolveAddr(AAddr: Pointer; out AModuleName: string;
  out AModuleBase: NativeUInt; out ARva: NativeUInt): Boolean;

implementation

const
  GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS       = $00000004;
  GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT = $00000002;
  CAPTURE_BUFFER_FRAMES                        = 64;

function GetModuleHandleEx(dwFlags: DWORD; lpModuleName: LPCWSTR;
  out phModule: HMODULE): BOOL; stdcall;
  external kernel32 name 'GetModuleHandleExW';

function RtlCaptureStackBackTrace(FramesToSkip, FramesToCapture: ULONG;
  BackTrace: PPointer; BackTraceHash: PULONG): WORD; stdcall;
  external kernel32 name 'RtlCaptureStackBackTrace';

function ResolveAddr(AAddr: Pointer; out AModuleName: string;
  out AModuleBase: NativeUInt; out ARva: NativeUInt): Boolean;
var
  LModule: HMODULE;
  LBuf: array[0..MAX_PATH] of Char;
begin
  Result := False;
  AModuleName := '<unknown>';
  AModuleBase := 0;
  ARva := 0;

  if AAddr = nil then Exit;

  LModule := 0;
  if not GetModuleHandleEx(
    GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS or
    GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
    LPCWSTR(AAddr), LModule) then
    Exit;

  if LModule = 0 then Exit;

  if GetModuleFileName(LModule, LBuf, Length(LBuf)) > 0 then
    AModuleName := ExtractFileName(string(LBuf));

  AModuleBase := NativeUInt(LModule);
  ARva := NativeUInt(AAddr) - AModuleBase;
  Result := True;
end;

function CaptureStack(ASkip: Integer; AMaxFrames: Integer;
  out ATruncated: Boolean): TArray<TStackFrame>;
var
  LBuf: array[0..CAPTURE_BUFFER_FRAMES - 1] of Pointer;
  LCount, LCapped: Integer;
begin
  ATruncated := False;
  Result := nil;

  if AMaxFrames <= 0 then Exit;
  if ASkip < 0 then ASkip := 0;

  LCount := 0;
  try
    LCount := RtlCaptureStackBackTrace(ASkip, CAPTURE_BUFFER_FRAMES, @LBuf[0], nil);
  except
    LCount := 0;
  end;

  if LCount <= 0 then Exit;

  if LCount > AMaxFrames then LCapped := AMaxFrames else LCapped := LCount;
  ATruncated := LCount > AMaxFrames;

  SetLength(Result, LCapped);
  for var I := 0 to LCapped - 1 do
    ResolveAddr(LBuf[I], Result[I].ModuleName, Result[I].ModuleBase, Result[I].Rva);
end;

end.
