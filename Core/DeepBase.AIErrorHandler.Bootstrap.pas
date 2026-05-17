{ ============================================================================
  DeepBase.AIErrorHandler.Bootstrap

  One-line entry point for installing the DeepBase AI runtime-error handler.
  Each Deep* program (and Assayer, plus all test entry points) calls
  InstallAIErrorHandler in its .dpr after Application.Initialize.

  Production_Mode (default):
    - AIAnalyze exceptions show MessageDlg with friendly LLM-generated text
    - Fatal exceptions show MessageDlg then Application.Terminate

  Test_Mode (env DEEP_AIEH_MODE=test, define DEEPBASE_AIEH_TEST, or
  InstallAIErrorHandlerForTests):
    - No MessageDlg (won't block test runners / CI)
    - Fatal exceptions cause ExitCode := 1; Halt(1)

  Coexists with TAutoFixErrorRecorderVCL.HookApplication: TAIErrorHandler.Install
  saves the previous Application.OnException and chains to it after handling.
  ============================================================================ }

unit DeepBase.AIErrorHandler.Bootstrap;

interface

uses
  System.SysUtils,
  DeepBase.AIErrorHandler;

type
  /// <summary>
  /// Bootstrap mode selector.
  /// </summary>
  TAIErrorBootstrapMode = (
    bmAuto,        // Detect via env var DEEP_AIEH_MODE / define DEEPBASE_AIEH_TEST
    bmProduction,  // Force interactive (MessageDlg) mode
    bmTest         // Force silent / non-interactive mode
  );

/// <summary>
/// Install AIErrorHandler with default config and given mode.
/// Idempotent within a single process; subsequent calls return False.
/// Never raises: any internal failure is swallowed and reported via
/// OutputDebugString.
/// </summary>
function InstallAIErrorHandler(AMode: TAIErrorBootstrapMode = bmAuto): Boolean; overload;

/// <summary>
/// Install AIErrorHandler with caller-supplied config.
/// In bmAuto / bmTest mode, SilentMode is forced to True regardless of
/// the AConfig.SilentMode value.
/// </summary>
function InstallAIErrorHandler(const AConfig: TAIErrorConfig;
  AMode: TAIErrorBootstrapMode = bmAuto): Boolean; overload;

/// <summary>Sugar for InstallAIErrorHandler(bmTest).</summary>
function InstallAIErrorHandlerForTests: Boolean;

/// <summary>
/// True iff env var DEEP_AIEH_MODE = 'test' (case-insensitive) OR the unit
/// was compiled with DEEPBASE_AIEH_TEST defined.
/// </summary>
function IsTestMode: Boolean;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  DeepBase.AIErrorHandler.LLMBridge;

var
  GInstalled: Boolean = False;

procedure DebugOut(const AMessage: string);
begin
  {$IFDEF MSWINDOWS}
  OutputDebugString(PChar('[AIEH.Bootstrap] ' + AMessage));
  {$ENDIF}
end;

function IsTestMode: Boolean;
var
  LEnv: string;
begin
  LEnv := GetEnvironmentVariable('DEEP_AIEH_MODE');
  Result := SameText(Trim(LEnv), 'test')
    {$IFDEF DEEPBASE_AIEH_TEST}
    or True
    {$ENDIF}
    ;
end;

function ResolveSilent(AMode: TAIErrorBootstrapMode): Boolean;
begin
  case AMode of
    bmTest:       Result := True;
    bmProduction: Result := False;
  else
    // bmAuto
    Result := IsTestMode;
  end;
end;

function InstallAIErrorHandler(const AConfig: TAIErrorConfig;
  AMode: TAIErrorBootstrapMode): Boolean;
var
  LConfig: TAIErrorConfig;
begin
  // Idempotent: only the first successful call wires anything up.
  if GInstalled then
    Exit(False);

  try
    LConfig := AConfig;
    if ResolveSilent(AMode) then
      LConfig.SilentMode := True;

    // 1. Install handler (chains to any prior Application.OnException).
    TAIErrorHandler.Install(LConfig);

    // 2. Wire LLM bridge. If the LLM service is unconfigured / unreachable,
    //    the bridge silently returns empty strings -> AIErrorHandler falls
    //    back to a generic friendly message.
    try
      InstallLLMBridge;
    except
      on E: Exception do
        DebugOut('LLMBridge install failed (continuing without AI): ' +
          E.ClassName + ' ' + E.Message);
    end;

    GInstalled := True;
    Result := True;
  except
    on E: Exception do
    begin
      // Never let bootstrap failures propagate into the host program.
      DebugOut('InstallAIErrorHandler failed: ' + E.ClassName + ' ' +
        E.Message);
      Result := False;
    end;
  end;
end;

function InstallAIErrorHandler(AMode: TAIErrorBootstrapMode): Boolean;
begin
  Result := InstallAIErrorHandler(TAIErrorConfig.Default, AMode);
end;

function InstallAIErrorHandlerForTests: Boolean;
begin
  Result := InstallAIErrorHandler(TAIErrorConfig.Default, bmTest);
end;

end.
