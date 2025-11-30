{ ============================================================================
  UniBase.Types - Common Type Definitions
  
  Version: 0.3
  Description: Defines all common types, enums and records used by the
               UniBase framework.
  ============================================================================ }

unit UniBase.Types;

interface

uses
  System.SysUtils;

type
  /// <summary>
  /// Initialization error codes
  /// </summary>
  TInitErrorCode = (
    ecSuccess = 0,           // Success
    ecConfigDBNotFound = 1,  // config.db not found, auto-create failed
    ecConfigDBCorrupted = 2, // config.db corrupted, schema check failed
    ecPermissionDenied = 3,  // Cannot write root.txt or config.db
    ecInvalidPath = 4,       // Path in root.txt does not exist
    ecMissingAssets = 5,     // Assets directory structure incomplete
    ecUnknown = 99           // Unknown error, see error message
  );

  /// <summary>
  /// Log level
  /// </summary>
  TLogLevel = (
    llDebug,
    llInfo,
    llWarn,
    llError,
    llFatal
  );

  /// <summary>
  /// Language info record
  /// </summary>
  TLanguageInfo = record
    LangCode: string;    // e.g. zh-CN, en-US
    LangName: string;    // e.g. Chinese (Simplified), English
    NativeName: string;  // e.g. 简体中文, English
    FlagIcon: string;    // Flag icon filename
    IsEnabled: Boolean;
    IsDefault: Boolean;
  end;
  TLanguageInfoArray = TArray<TLanguageInfo>;

  /// <summary>
  /// MRU item record
  /// </summary>
  TMRUItem = record
    ItemKey: string;
    DisplayName: string;
    LastAccess: TDateTime;
    AccessCount: Integer;
    IconIndex: Integer;
  end;
  TMRUItemArray = TArray<TMRUItem>;

  /// <summary>
  /// Theme info record
  /// </summary>
  TThemeInfo = record
    Name: string;
    StyleFile: string;
    IsDark: Boolean;
    IsBuiltIn: Boolean;
  end;
  TThemeInfoArray = TArray<TThemeInfo>;

  /// <summary>
  /// Animation asset data (Core layer, no Bitmap)
  /// </summary>
  TAnimationAssetData = record
    Name: string;
    SvgContent: string;
    FrameCount: Integer;
    FrameDuration: Integer;
    Width: Integer;
    Height: Integer;
  end;

  /// <summary>
  /// Update info record
  /// </summary>
  TUpdateInfo = record
    Version: string;
    ReleaseDate: TDateTime;
    DownloadUrl: string;
    FileSize: Int64;
    SHA256: string;
    Changelog: string;
    ForceUpdate: Boolean;
  end;

  /// <summary>
  /// Hotkey default record
  /// </summary>
  THotkeyDefault = record
    ActionName: string;
    Shortcut: string;
    Description: string;
    Category: string;
  end;

  /// <summary>
  /// Health check result
  /// </summary>
  THealthCheckResult = record
  private
    FMessageCount: Integer;  // Actual message count (may be less than Length(Messages))
  public
    IsHealthy: Boolean;
    ConfigDBOk: Boolean;
    AssetsDirOk: Boolean;
    LLMConnectionOk: Boolean;
    Messages: TArray<string>;
    
    /// <summary>Add message with optimized allocation (grows by 8)</summary>
    procedure AddMessage(const Msg: string);
    /// <summary>Initialize the record</summary>
    procedure Init;
    /// <summary>Get actual message count</summary>
    function MessageCount: Integer;
    /// <summary>Trim Messages array to actual count</summary>
    procedure TrimMessages;
  end;

  /// <summary>
  /// Config changed event
  /// </summary>
  TConfigChangedEvent = procedure(Sender: TObject; const Key, OldValue, NewValue: string) of object;

  /// <summary>
  /// LLM completion callback event
  /// </summary>
  TLLMCompleteEvent = procedure(Sender: TObject; Success: Boolean; const Response, ErrorMsg: string) of object;

  /// <summary>
  /// Progress event
  /// </summary>
  TProgressEvent = procedure(Sender: TObject; Current, Total: Int64; const Status: string) of object;

  /// <summary>
  /// Update available event
  /// </summary>
  TUpdateAvailableEvent = procedure(Sender: TObject; const UpdateInfo: TUpdateInfo) of object;

  /// <summary>
  /// Save extra state event
  /// </summary>
  TSaveExtraEvent = procedure(Sender: TObject; var Extra: string) of object;

  /// <summary>
  /// Restore extra state event
  /// </summary>
  TRestoreExtraEvent = procedure(Sender: TObject; const Extra: string) of object;

/// <summary>
/// Convert init error code to string
/// </summary>
function InitErrorCodeToStr(Code: TInitErrorCode): string;

/// <summary>
/// Convert log level to string
/// </summary>
function LogLevelToStr(Level: TLogLevel): string;

/// <summary>
/// Convert string to log level
/// </summary>
function StrToLogLevel(const S: string): TLogLevel;

implementation

{ THealthCheckResult }

procedure THealthCheckResult.Init;
begin
  IsHealthy := False;
  ConfigDBOk := False;
  AssetsDirOk := False;
  LLMConnectionOk := False;
  FMessageCount := 0;
  SetLength(Messages, 0);
end;

procedure THealthCheckResult.AddMessage(const Msg: string);
const
  GROW_SIZE = 8;  // Grow by 8 to reduce reallocations
begin
  // Grow array if needed
  if FMessageCount >= Length(Messages) then
    SetLength(Messages, Length(Messages) + GROW_SIZE);
  
  Messages[FMessageCount] := Msg;
  Inc(FMessageCount);
end;

function THealthCheckResult.MessageCount: Integer;
begin
  Result := FMessageCount;
end;

procedure THealthCheckResult.TrimMessages;
begin
  if FMessageCount < Length(Messages) then
    SetLength(Messages, FMessageCount);
end;

{ Helper Functions }

function InitErrorCodeToStr(Code: TInitErrorCode): string;
begin
  case Code of
    ecSuccess:          Result := 'Success';
    ecConfigDBNotFound: Result := 'ConfigDB Not Found';
    ecConfigDBCorrupted:Result := 'ConfigDB Corrupted';
    ecPermissionDenied: Result := 'Permission Denied';
    ecInvalidPath:      Result := 'Invalid Path';
    ecMissingAssets:    Result := 'Missing Assets';
  else
    Result := 'Unknown Error';
  end;
end;

function LogLevelToStr(Level: TLogLevel): string;
begin
  case Level of
    llDebug: Result := 'DEBUG';
    llInfo:  Result := 'INFO';
    llWarn:  Result := 'WARN';
    llError: Result := 'ERROR';
    llFatal: Result := 'FATAL';
  else
    Result := 'UNKNOWN';
  end;
end;

function StrToLogLevel(const S: string): TLogLevel;
var
  Upper: string;
begin
  Upper := UpperCase(S);
  if Upper = 'DEBUG' then Result := llDebug
  else if Upper = 'INFO' then Result := llInfo
  else if Upper = 'WARN' then Result := llWarn
  else if Upper = 'WARNING' then Result := llWarn
  else if Upper = 'ERROR' then Result := llError
  else if Upper = 'FATAL' then Result := llFatal
  else Result := llInfo; // 默认
end;

end.
