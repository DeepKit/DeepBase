{ ============================================================================
  UniBase.Types - 公共类型定义
  
  版本: 0.3
  说明: 定义 UniBase 框架使用的所有公共类型、枚举和记录
  ============================================================================ }

unit UniBase.Types;

interface

uses
  System.SysUtils;

type
  /// <summary>
  /// 初始化错误码
  /// </summary>
  TInitErrorCode = (
    ecSuccess = 0,           // 成功
    ecConfigDBNotFound = 1,  // config.db 不存在，尝试自动创建失败
    ecConfigDBCorrupted = 2, // config.db 损坏，表结构检查失败
    ecPermissionDenied = 3,  // 无法写入 root.txt 或 config.db
    ecInvalidPath = 4,       // root.txt 指向的目录不存在
    ecMissingAssets = 5,     // assets 目录结构不完整
    ecUnknown = 99           // 未知错误，见错误消息详情
  );

  /// <summary>
  /// 日志级别
  /// </summary>
  TLogLevel = (
    llDebug,
    llInfo,
    llWarn,
    llError,
    llFatal
  );

  /// <summary>
  /// 语言信息记录
  /// </summary>
  TLanguageInfo = record
    LangCode: string;    // zh-CN, en-US
    LangName: string;    // Chinese (Simplified), English
    NativeName: string;  // 简体中文, English
    FlagIcon: string;    // 国旗图标文件名
    IsEnabled: Boolean;
    IsDefault: Boolean;
  end;
  TLanguageInfoArray = TArray<TLanguageInfo>;

  /// <summary>
  /// MRU 项记录
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
  /// 主题信息记录
  /// </summary>
  TThemeInfo = record
    Name: string;
    StyleFile: string;
    IsDark: Boolean;
    IsBuiltIn: Boolean;
  end;
  TThemeInfoArray = TArray<TThemeInfo>;

  /// <summary>
  /// 动画资源数据（Core 层，不含 Bitmap）
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
  /// 更新信息记录
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
  /// 快捷键默认值记录
  /// </summary>
  THotkeyDefault = record
    ActionName: string;
    Shortcut: string;
    Description: string;
    Category: string;
  end;

  /// <summary>
  /// 健康检查结果
  /// </summary>
  THealthCheckResult = record
    IsHealthy: Boolean;
    ConfigDBOk: Boolean;
    AssetsDirOk: Boolean;
    LLMConnectionOk: Boolean;
    Messages: TArray<string>;
    
    procedure AddMessage(const Msg: string);
  end;

  /// <summary>
  /// 配置变更事件
  /// </summary>
  TConfigChangedEvent = procedure(Sender: TObject; const Key, OldValue, NewValue: string) of object;

  /// <summary>
  /// LLM 完成回调事件
  /// </summary>
  TLLMCompleteEvent = procedure(Sender: TObject; Success: Boolean; const Response, ErrorMsg: string) of object;

  /// <summary>
  /// 进度事件
  /// </summary>
  TProgressEvent = procedure(Sender: TObject; Current, Total: Int64; const Status: string) of object;

  /// <summary>
  /// 更新可用事件
  /// </summary>
  TUpdateAvailableEvent = procedure(Sender: TObject; const UpdateInfo: TUpdateInfo) of object;

  /// <summary>
  /// 保存额外状态事件
  /// </summary>
  TSaveExtraEvent = procedure(Sender: TObject; var Extra: string) of object;

  /// <summary>
  /// 恢复额外状态事件
  /// </summary>
  TRestoreExtraEvent = procedure(Sender: TObject; const Extra: string) of object;

/// <summary>
/// 初始化错误码转字符串
/// </summary>
function InitErrorCodeToStr(Code: TInitErrorCode): string;

/// <summary>
/// 日志级别转字符串
/// </summary>
function LogLevelToStr(Level: TLogLevel): string;

/// <summary>
/// 字符串转日志级别
/// </summary>
function StrToLogLevel(const S: string): TLogLevel;

implementation

{ THealthCheckResult }

procedure THealthCheckResult.AddMessage(const Msg: string);
begin
  SetLength(Messages, Length(Messages) + 1);
  Messages[High(Messages)] := Msg;
end;

{ 辅助函数 }

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
