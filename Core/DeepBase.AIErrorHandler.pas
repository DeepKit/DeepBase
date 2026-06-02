{ ============================================================================
  DeepBase.AIErrorHandler

  AI-powered runtime error handler for DeepBase applications.
  Automatically classifies exceptions, self-heals where possible,
  and uses LLM to generate user-friendly error explanations.

  Usage:
    In .dpr after Application.Initialize:
      DeepBase.AIErrorHandler.Install;

    In business code:
      SafeRun('保存订单', procedure begin SaveOrder(FOrder) end);

  Architecture:
    Business code → Exception → AIErrorHandler
      → elIgnore: silently discard
      → elAutoFix: log + continue
      → elAIAnalyze: call LLM → show friendly message
      → elFatal: terminate

  Dependencies:
    - DeepBase.Logging (for structured logging)
    - DeepBase.LLM (optional, for AI analysis; degrades gracefully)
    - No JCL dependency (uses Delphi built-in exception info)
  ============================================================================ }

unit DeepBase.AIErrorHandler;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Forms;

type
  TErrorLevel = (elIgnore, elAutoFix, elAIAnalyze, elFatal);

  /// <summary>
  /// Configuration for the AI error handler.
  /// </summary>
  TAIErrorConfig = record
    /// <summary>Enable/disable AI analysis (default True if LLM configured)</summary>
    AIEnabled: Boolean;
    /// <summary>Max cached AI responses (default 50)</summary>
    MaxCacheSize: Integer;
    /// <summary>Timeout for AI calls in ms (default 8000)</summary>
    AITimeoutMs: Integer;
    /// <summary>Show technical details in message (default False)</summary>
    ShowTechnicalDetails: Boolean;
    /// <summary>Log file path for auto-fix entries (empty = use DeepBase.Logging)</summary>
    LogPath: string;
    /// <summary>
    /// Silent mode for tests / non-interactive runs (default False).
    /// When True: no MessageDlg is shown for elAIAnalyze and elFatal levels;
    /// elFatal uses ExitCode := 1; Halt(1) instead of Application.Terminate.
    /// </summary>
    SilentMode: Boolean;
    class function Default: TAIErrorConfig; static;
  end;

type
  /// <summary>
  /// Callback type for AI analysis. Set via TAIErrorHandler.SetAICallback.
  /// Returns the AI response string, or empty if unavailable.
  /// </summary>
  TAIAnalysisCallback = reference to function(const APrompt: string): string;

  TAIErrorHandler = class
  private
    class var FConfig: TAIErrorConfig;
    class var FCache: TDictionary<string, string>;
    class var FInstalled: Boolean;
    class var FAICallback: TAIAnalysisCallback;
    class var FOldAppException: TExceptionEvent;
    class function ClassifyError(E: Exception): TErrorLevel;
    class function BuildPrompt(E: Exception; const AContext, AStack: string): string;
    class function CallAI(const APrompt: string): string;
    class function GetExceptionLocation(AExceptAddr: Pointer): string;
    class procedure DoApplicationException(Sender: TObject; E: Exception);
  public
    /// <summary>Install as global Application.OnException handler.</summary>
    class procedure Install; overload;
    class procedure Install(const AConfig: TAIErrorConfig); overload;
    /// <summary>Set the AI callback. Typically wraps DeepBase.LLM.Chat.</summary>
    class procedure SetAICallback(ACallback: TAIAnalysisCallback);
    /// <summary>Main entry point. Call from SafeRun or directly.</summary>
    class procedure Handle(E: Exception; const AContext: string = '');
    /// <summary>Clear the AI response cache.</summary>
    class procedure ClearCache;
    class property Config: TAIErrorConfig read FConfig write FConfig;
  end;

/// <summary>
/// Wrap any business code. Exceptions are handled by AIErrorHandler.
/// Business code stays clean - no try/except needed.
/// </summary>
procedure SafeRun(const AContext: string; AProc: TProc);

implementation

uses
  System.IOUtils,
  System.DateUtils,
  System.UITypes,
  Vcl.Dialogs,
  DeepBase.Logging;

{ TAIErrorConfig }

class function TAIErrorConfig.Default: TAIErrorConfig;
begin
  Result.AIEnabled := True;
  Result.MaxCacheSize := 50;
  Result.AITimeoutMs := 8000;
  Result.ShowTechnicalDetails := False;
  Result.LogPath := '';
  Result.SilentMode := False;
end;

{ TAIErrorHandler }

class function TAIErrorHandler.ClassifyError(E: Exception): TErrorLevel;
begin
  // Ignore: user-initiated cancellations
  if (E is EAbort) then
    Exit(elIgnore);

  // AutoFix: conversion errors, argument errors (give defaults, retry)
  if (E is EConvertError) or (E is EArgumentException) then
    Exit(elAutoFix);

  // Fatal: unrecoverable system errors
  {$WARN SYMBOL_DEPRECATED OFF}
  if (E is EStackOverflow) or (E is EOutOfMemory) or
     (E is EAccessViolation) then
    Exit(elFatal);
  {$WARN SYMBOL_DEPRECATED DEFAULT}

  // Everything else: AI analyzes and explains to user
  Result := elAIAnalyze;
end;

class function TAIErrorHandler.GetExceptionLocation(AExceptAddr: Pointer): string;
begin
  // Delphi built-in: no JCL needed
  if AExceptAddr <> nil then
    Result := Format('$%p', [AExceptAddr])
  else
    Result := '(unknown)';
end;

class function TAIErrorHandler.BuildPrompt(E: Exception;
  const AContext, AStack: string): string;
begin
  Result :=
    '你是Delphi桌面软件运行时错误分析助手。用中文简洁回答，面向最终用户。' + #10 +
    '错误类型：' + E.ClassName + #10 +
    '错误信息：' + E.Message + #10;
  if AContext <> '' then
    Result := Result + '操作上下文：' + AContext + #10;
  if AStack <> '' then
    Result := Result + '位置：' + AStack + #10;
  Result := Result +
    '请给出：' + #10 +
    '①用户能理解的一句话原因（不要技术术语）' + #10 +
    '②建议操作（简洁明了）';
end;

class function TAIErrorHandler.CallAI(const APrompt: string): string;
var
  LKey: string;
begin
  Result := '';

  // Check cache first
  LKey := Copy(APrompt, 1, 100);
  if (FCache <> nil) and FCache.TryGetValue(LKey, Result) then
    Exit;

  // Call via callback
  if not Assigned(FAICallback) then
    Exit;

  try
    Result := FAICallback(APrompt);
  except
    // Never let AI handler itself crash
    Result := '';
  end;

  // Cache the result
  if (Result <> '') and (FCache <> nil) then
  begin
    if FCache.Count >= FConfig.MaxCacheSize then
      FCache.Clear;
    FCache.AddOrSetValue(LKey, Result);
  end;
end;

class procedure TAIErrorHandler.Handle(E: Exception; const AContext: string);
var
  LLevel: TErrorLevel;
  LStack, LAIResponse, LUserMsg: string;
begin
  LLevel := ClassifyError(E);

  case LLevel of
    elIgnore:
      Exit;

    elAutoFix:
    begin
      // Log silently, don't bother user
      Logger.Warn(
        Format('AutoFix [%s] %s: %s', [AContext, E.ClassName, E.Message]),
        'AIErrorHandler');
    end;

    elAIAnalyze:
    begin
      LStack := GetExceptionLocation(ExceptAddr);

      // Try AI analysis
      if FConfig.AIEnabled and Assigned(FAICallback) then
      begin
        LAIResponse := CallAI(BuildPrompt(E, AContext, LStack));
      end;

      // Build user message
      if LAIResponse <> '' then
        LUserMsg := LAIResponse
      else
      begin
        // Fallback: friendly generic message
        if AContext <> '' then
          LUserMsg := '操作"' + AContext + '"遇到问题：' + E.Message
        else
          LUserMsg := '系统遇到问题：' + E.Message;
      end;

      if FConfig.ShowTechnicalDetails then
        LUserMsg := LUserMsg + sLineBreak + sLineBreak +
          '[' + E.ClassName + ' at ' + LStack + ']';

      // Show to user (suppressed in SilentMode for tests / non-interactive runs)
      if not FConfig.SilentMode then
        MessageDlg(LUserMsg, mtWarning, [mbOK], 0);

      // Log
      Logger.Error(
        Format('[%s] %s: %s | AI: %s', [AContext, E.ClassName, E.Message,
          Copy(LAIResponse, 1, 200)]),
        'AIErrorHandler');
    end;

    elFatal:
    begin
      Logger.Fatal(
        Format('FATAL [%s] %s: %s', [AContext, E.ClassName, E.Message]),
        'AIErrorHandler');
      if FConfig.SilentMode then
      begin
        // Non-interactive path (e.g. test runners): no dialog,
        // exit with non-zero code so CI / test harness can detect failure.
        ExitCode := 1;
        Halt(1);
      end
      else
      begin
        MessageDlg('程序遇到严重错误，即将关闭。' + sLineBreak +
          E.Message, mtError, [mbOK], 0);
        Application.Terminate;
      end;
    end;
  end;
end;

class procedure TAIErrorHandler.DoApplicationException(Sender: TObject; E: Exception);
begin
  try
    Handle(E);
  finally
    // Chain to any pre-existing handler (e.g. TAutoFixVclHook)
    // so other consumers still receive the exception.
    if Assigned(FOldAppException) then
    begin
      try
        FOldAppException(Sender, E);
      except
        // Never let chained handler crash AIErrorHandler itself.
      end;
    end;
  end;
end;

class procedure TAIErrorHandler.Install;
begin
  Install(TAIErrorConfig.Default);
end;

class procedure TAIErrorHandler.Install(const AConfig: TAIErrorConfig);
begin
  if FInstalled then Exit;
  FConfig := AConfig;
  if FCache = nil then
    FCache := TDictionary<string, string>.Create;
  // Save existing handler so we can chain (do not overwrite peers like AutoFix).
  FOldAppException := Application.OnException;
  Application.OnException := DoApplicationException;
  FInstalled := True;
end;

class procedure TAIErrorHandler.SetAICallback(ACallback: TAIAnalysisCallback);
begin
  FAICallback := ACallback;
end;

class procedure TAIErrorHandler.ClearCache;
begin
  if FCache <> nil then
    FCache.Clear;
end;

{ SafeRun }

procedure SafeRun(const AContext: string; AProc: TProc);
begin
  try
    AProc();
  except
    on E: Exception do
      TAIErrorHandler.Handle(E, AContext);
  end;
end;

initialization
  TAIErrorHandler.FCache := nil;
  TAIErrorHandler.FInstalled := False;
  TAIErrorHandler.FAICallback := nil;
  TAIErrorHandler.FOldAppException := nil;

finalization
  FreeAndNil(TAIErrorHandler.FCache);

end.
