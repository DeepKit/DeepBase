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
  System.Hash,
  System.SyncObjs,
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

  /// <summary>
  /// Timeout-aware callback for AI analysis. Set via the
  /// SetAICallback(ATimeoutAwareCallback) overload. When assigned, CallAI
  /// passes AITimeoutMs through so the LLM client can honour it.
  /// BIZ2-020 fix: the plain TAIAnalysisCallback could not receive the
  /// configured timeout, so AITimeoutMs was stored but never used.
  /// </summary>
  TAIAnalysisCallbackWithTimeout = reference to function(
    const APrompt: string; ATimeoutMs: Integer): string;

  TAIErrorHandler = class
  private
    class var FLock: TCriticalSection;
    class var FConfig: TAIErrorConfig;
    class var FCache: TDictionary<string, string>;
    class var FInstalled: Boolean;
    class var FAICallback: TAIAnalysisCallback;
    class var FAICallbackWithTimeout: TAIAnalysisCallbackWithTimeout;
    class var FOldAppException: TExceptionEvent;
    class function ClassifyError(E: Exception): TErrorLevel;
    class function BuildPrompt(E: Exception; const AContext, AStack: string): string;
    class function CallAI(const APrompt: string): string;
    class function GetExceptionLocation(AExceptAddr: Pointer): string;
    class procedure DoApplicationException(Sender: TObject; E: Exception);
  public
    class constructor Create;
    class destructor Destroy;
    /// <summary>Install as global Application.OnException handler.</summary>
    class procedure Install; overload;
    class procedure Install(const AConfig: TAIErrorConfig); overload;
    /// <summary>Set the AI callback. Typically wraps DeepBase.LLM.Chat.</summary>
    class procedure SetAICallback(ACallback: TAIAnalysisCallback); overload;
    /// <summary>
    /// Set a timeout-aware AI callback. CallAI passes AIConfig.AITimeoutMs
    /// as the second parameter so the LLM client can honour the timeout.
    /// BIZ2-020 fix.
    /// </summary>
    class procedure SetAICallback(ACallback: TAIAnalysisCallbackWithTimeout); overload;
    /// <summary>Main entry point. Call from SafeRun or directly.</summary>
    class procedure Handle(E: Exception; const AContext: string = '');
    /// <summary>
    /// Handle with explicit except-address. Use from except blocks where
    /// ExceptAddr is valid; outside an except block pass nil. The legacy
    /// Handle overload routes through here.
    /// BIZ2-018 fix: the previous Handle called ExceptAddr directly from a
    /// non-except context, which is undefined behaviour — the returned
    /// address was stack garbage and the cached AI analysis key became
    /// unpredictable.
    /// </summary>
    class procedure HandleAt(E: Exception; AExceptAddr: Pointer;
      const AContext: string = '');
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

class constructor TAIErrorHandler.Create;
begin
  FLock := TCriticalSection.Create;
end;

class destructor TAIErrorHandler.Destroy;
begin
  FCache.Free;
  FreeAndNil(FLock);
end;

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
  LCallback: TAIAnalysisCallback;
  LCallbackTO: TAIAnalysisCallbackWithTimeout;
  LMaxCacheSize: Integer;
  LTimeoutMs: Integer;
begin
  Result := '';

  // BIZ2-019 fix: use SHA-256 hash (first 32 hex chars) of the full prompt
  // as cache key. The previous key was Copy(Prompt,1,100) which collided for
  // different errors sharing a common prefix (same exception class, same
  // context, divergent messages).
  LKey := THashSHA2.GetHashString(APrompt).Substring(0, 32);

  FLock.Enter;
  try
    if (FCache <> nil) and FCache.TryGetValue(LKey, Result) then
      Exit;
    LCallback := FAICallback;
    LCallbackTO := FAICallbackWithTimeout;
    LMaxCacheSize := FConfig.MaxCacheSize;
    LTimeoutMs := FConfig.AITimeoutMs;
  finally
    FLock.Leave;
  end;

  // Prefer the timeout-aware callback (BIZ2-020 fix: passes AITimeoutMs
  // through so the LLM client can enforce the configured deadline).
  if Assigned(LCallbackTO) then
  begin
    try
      Result := LCallbackTO(APrompt, LTimeoutMs);
    except
      Result := '';
    end;
  end
  else if Assigned(LCallback) then
  begin
    try
      Result := LCallback(APrompt);
    except
      Result := '';
    end;
  end;

  // Cache the result
  if (Result <> '') then
  begin
    FLock.Enter;
    try
      if FCache <> nil then
      begin
        if FCache.Count >= LMaxCacheSize then
          FCache.Clear;
        FCache.AddOrSetValue(LKey, Result);
      end;
    finally
      FLock.Leave;
    end;
  end;
end;

class procedure TAIErrorHandler.Handle(E: Exception; const AContext: string);
begin
  // BIZ2-018 fix: route through HandleAt with nil address. Callers of this
  // overload may not be inside an except block, so ExceptAddr would return
  // undefined stack garbage. HandleAt skips the location component when
  // AExceptAddr is nil.
  HandleAt(E, nil, AContext);
end;

class procedure TAIErrorHandler.HandleAt(E: Exception; AExceptAddr: Pointer;
  const AContext: string);
var
  LLevel: TErrorLevel;
  LStack, LAIResponse, LUserMsg: string;
  LAIEnabled: Boolean;
  LShowTech: Boolean;
  LSilentMode: Boolean;
begin
  LLevel := ClassifyError(E);

  // Snapshot config under lock
  FLock.Enter;
  try
    LAIEnabled := FConfig.AIEnabled;
    LShowTech := FConfig.ShowTechnicalDetails;
    LSilentMode := FConfig.SilentMode;
  finally
    FLock.Leave;
  end;

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
      LStack := GetExceptionLocation(AExceptAddr);

      // Try AI analysis
      if LAIEnabled then
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

      if LShowTech then
        LUserMsg := LUserMsg + sLineBreak + sLineBreak +
          '[' + E.ClassName + ' at ' + LStack + ']';

      // Show to user (suppressed in SilentMode for tests / non-interactive runs)
      if not LSilentMode then
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
      if LSilentMode then
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
  FLock.Enter;
  try
    if FInstalled then Exit;
    FConfig := AConfig;
    if FCache = nil then
      FCache := TDictionary<string, string>.Create;
    // Save existing handler so we can chain (do not overwrite peers like AutoFix).
    FOldAppException := Application.OnException;
    Application.OnException := DoApplicationException;
    FInstalled := True;
  finally
    FLock.Leave;
  end;
end;

class procedure TAIErrorHandler.SetAICallback(ACallback: TAIAnalysisCallback);
begin
  FLock.Enter;
  try
    FAICallback := ACallback;
    FAICallbackWithTimeout := nil;  // new overload takes precedence
  finally
    FLock.Leave;
  end;
end;

class procedure TAIErrorHandler.SetAICallback(
  ACallback: TAIAnalysisCallbackWithTimeout);
begin
  FLock.Enter;
  try
    FAICallbackWithTimeout := ACallback;
    FAICallback := nil;  // new overload takes precedence
  finally
    FLock.Leave;
  end;
end;

class procedure TAIErrorHandler.ClearCache;
begin
  FLock.Enter;
  try
    if FCache <> nil then
      FCache.Clear;
  finally
    FLock.Leave;
  end;
end;

{ SafeRun }

procedure SafeRun(const AContext: string; AProc: TProc);
begin
  try
    AProc();
  except
    on E: Exception do
      // BIZ2-018 fix: pass ExceptAddr explicitly. This is safe because we
      // are inside an except block; the address is valid and lets the
      // cached AI analysis key include a stable location.
      TAIErrorHandler.HandleAt(E, ExceptAddr, AContext);
  end;
end;

initialization
  TAIErrorHandler.FCache := nil;
  TAIErrorHandler.FInstalled := False;
  TAIErrorHandler.FAICallback := nil;
  TAIErrorHandler.FAICallbackWithTimeout := nil;
  TAIErrorHandler.FOldAppException := nil;

finalization
  FreeAndNil(TAIErrorHandler.FCache);

end.
