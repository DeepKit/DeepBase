{*******************************************************}
{                                                       }
{       UniBase Exception Hierarchy                     }
{                                                       }
{       Copyright (C) 2025 UniBase                      }
{                                                       }
{       统一异常类层次结构                              }
{       用于替换泛型 Exception.Create 调用             }
{                                                       }
{*******************************************************}

unit UniBase.Exceptions;

interface

uses
  System.SysUtils, System.Classes;

type
  /// <summary>
  /// UniBase 异常基类
  /// 所有 UniBase 特定异常都应继承自此类
  /// </summary>
  EUniBaseException = class(Exception)
  private
    FErrorCode: Integer;
    FContext: string;
    FTimestamp: TDateTime;
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AMessage: string; AErrorCode: Integer); overload;
    constructor Create(const AMessage: string; const AContext: string); overload;
    constructor Create(const AMessage: string; AErrorCode: Integer; const AContext: string); overload;
    constructor CreateFmt(const AFormat: string; const AArgs: array of const);

    property ErrorCode: Integer read FErrorCode;
    property Context: string read FContext;
    property Timestamp: TDateTime read FTimestamp;

    function ToString: string; override;
  end;

  //============================================================================
  // 安全与加密异常
  //============================================================================

  /// <summary>
  /// 安全模块异常基类
  /// </summary>
  ESecurityException = class(EUniBaseException);

  /// <summary>
  /// 加密/解密操作失败
  /// </summary>
  EEncryptionException = class(ESecurityException);

  /// <summary>
  /// 解密操作失败
  /// </summary>
  EDecryptionException = class(ESecurityException);

  /// <summary>
  /// 哈希计算失败
  /// </summary>
  EHashException = class(ESecurityException);

  /// <summary>
  /// 数字签名相关异常
  /// </summary>
  ESignatureException = class(ESecurityException);

  /// <summary>
  /// 防篡改相关异常
  /// </summary>
  EAntiTamperException = class(ESecurityException);

  /// <summary>
  /// 保护模块异常
  /// </summary>
  EProtectionException = class(ESecurityException);

  /// <summary>
  /// 随机数生成异常
  /// </summary>
  ERandomException = class(ESecurityException);

  //============================================================================
  // 数据库异常
  //============================================================================

  /// <summary>
  /// 数据库模块异常基类
  /// </summary>
  EDatabaseException = class(EUniBaseException)
  private
    FSQL: string;
    FDBType: string;
  public
    constructor Create(const AMessage: string; const ASQL: string = ''); overload;
    property SQL: string read FSQL;
    property DBType: string read FDBType write FDBType;
  end;

  /// <summary>
  /// 连接池异常
  /// </summary>
  EPoolException = class(EDatabaseException);

  /// <summary>
  /// 连接超时异常
  /// </summary>
  EConnectionTimeoutException = class(EPoolException);

  /// <summary>
  /// 连接池未初始化异常
  /// </summary>
  EPoolNotInitializedException = class(EPoolException);

  //============================================================================
  // 配置异常
  //============================================================================

  /// <summary>
  /// 配置模块异常基类
  /// </summary>
  EConfigException = class(EUniBaseException);

  /// <summary>
  /// 配置未找到
  /// </summary>
  EConfigNotFoundException = class(EConfigException);

  /// <summary>
  /// 配置值无效
  /// </summary>
  EConfigInvalidValueException = class(EConfigException);

  //============================================================================
  // 备份异常
  //============================================================================

  /// <summary>
  /// 备份模块异常基类
  /// </summary>
  EBackupException = class(EUniBaseException);

  /// <summary>
  /// 备份操作取消
  /// </summary>
  EBackupCancelledException = class(EBackupException);

  /// <summary>
  /// 备份操作正在进行中
  /// </summary>
  EBackupInProgressException = class(EBackupException);

  /// <summary>
  /// 云服务未配置
  /// </summary>
  ECloudServiceNotConfiguredException = class(EBackupException);

  /// <summary>
  /// 备份文件不存在
  /// </summary>
  EBackupFileNotFoundException = class(EBackupException);

  /// <summary>
  /// 备份上传/下载失败
  /// </summary>
  EBackupTransferException = class(EBackupException);

  //============================================================================
  // 网络与服务异常
  //============================================================================

  /// <summary>
  /// 网络模块异常基类
  /// </summary>
  ENetworkException = class(EUniBaseException);

  /// <summary>
  /// HTTP 服务器异常
  /// </summary>
  EHttpServerException = class(ENetworkException);

  /// <summary>
  /// 服务器已在运行
  /// </summary>
  EServerAlreadyRunningException = class(EHttpServerException);

  /// <summary>
  /// WebSocket 异常
  /// </summary>
  EWebSocketException = class(ENetworkException);

  //============================================================================
  // 弹性与容错异常
  //============================================================================

  /// <summary>
  /// 弹性模块异常基类
  /// </summary>
  EResilienceException = class(EUniBaseException);

  /// <summary>
  /// 断路器异常
  /// </summary>
  ECircuitBreakerException = class(EResilienceException);

  /// <summary>
  /// 断路器注册表未初始化
  /// </summary>
  ECircuitBreakerNotInitializedException = class(ECircuitBreakerException);

  //============================================================================
  // 初始化异常
  //============================================================================

  /// <summary>
  /// 初始化异常基类
  /// </summary>
  EInitializationException = class(EUniBaseException);

  /// <summary>
  /// 模块未初始化
  /// </summary>
  ENotInitializedException = class(EInitializationException);

  /// <summary>
  /// 配置缺失
  /// </summary>
  EMissingConfigurationException = class(EInitializationException);

  //============================================================================
  // 操作异常
  //============================================================================

  /// <summary>
  /// 操作异常基类
  /// </summary>
  EOperationException = class(EUniBaseException);

  /// <summary>
  /// 操作正在进行中
  /// </summary>
  EOperationInProgressException = class(EOperationException);

  /// <summary>
  /// 操作已取消
  /// </summary>
  EOperationCancelledException = class(EOperationException);

  /// <summary>
  /// 无效操作
  /// </summary>
  EInvalidOperationException = class(EOperationException);

  //============================================================================
  // 文件异常
  //============================================================================

  /// <summary>
  /// 文件操作异常基类
  /// </summary>
  EFileOperationException = class(EUniBaseException);

  /// <summary>
  /// 文件未找到
  /// </summary>
  EFileNotFoundExceptionEx = class(EFileOperationException);

  //============================================================================
  // 辅助函数
  //============================================================================

  /// <summary>
  /// 获取系统错误消息（Windows）
  /// </summary>
  function GetLastErrorMessage: string;

  /// <summary>
  /// 抛出带系统错误的异常
  /// </summary>
  procedure RaiseLastOSError(const AContext: string = '');

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  System.DateUtils;

{ EUniBaseException }

constructor EUniBaseException.Create(const AMessage: string);
begin
  inherited Create(AMessage);
  FErrorCode := 0;
  FContext := '';
  FTimestamp := Now;
end;

constructor EUniBaseException.Create(const AMessage: string; AErrorCode: Integer);
begin
  inherited Create(AMessage);
  FErrorCode := AErrorCode;
  FContext := '';
  FTimestamp := Now;
end;

constructor EUniBaseException.Create(const AMessage: string; const AContext: string);
begin
  inherited Create(AMessage);
  FErrorCode := 0;
  FContext := AContext;
  FTimestamp := Now;
end;

constructor EUniBaseException.Create(const AMessage: string; AErrorCode: Integer;
  const AContext: string);
begin
  inherited Create(AMessage);
  FErrorCode := AErrorCode;
  FContext := AContext;
  FTimestamp := Now;
end;

constructor EUniBaseException.CreateFmt(const AFormat: string;
  const AArgs: array of const);
begin
  inherited CreateFmt(AFormat, AArgs);
  FErrorCode := 0;
  FContext := '';
  FTimestamp := Now;
end;

function EUniBaseException.ToString: string;
begin
  Result := Format('[%s] %s', [ClassName, Message]);
  if FErrorCode <> 0 then
    Result := Result + Format(' (Code: %d)', [FErrorCode]);
  if FContext <> '' then
    Result := Result + Format(' [Context: %s]', [FContext]);
end;

{ EDatabaseException }

constructor EDatabaseException.Create(const AMessage: string; const ASQL: string);
begin
  inherited Create(AMessage);
  FSQL := ASQL;
  FDBType := '';
end;

{ Helper Functions }

function GetLastErrorMessage: string;
{$IFDEF MSWINDOWS}
var
  ErrorCode: DWORD;
begin
  ErrorCode := GetLastError;
  if ErrorCode <> 0 then
    Result := SysErrorMessage(ErrorCode)
  else
    Result := '';
end;
{$ELSE}
begin
  Result := '';
end;
{$ENDIF}

procedure RaiseLastOSError(const AContext: string);
{$IFDEF MSWINDOWS}
var
  ErrorCode: DWORD;
  ErrorMsg: string;
begin
  ErrorCode := GetLastError;
  if ErrorCode <> 0 then
  begin
    ErrorMsg := SysErrorMessage(ErrorCode);
    if AContext <> '' then
      raise EUniBaseException.Create(AContext + ': ' + ErrorMsg, ErrorCode)
    else
      raise EUniBaseException.Create(ErrorMsg, ErrorCode);
  end;
end;
{$ELSE}
begin
  // Non-Windows platforms
end;
{$ENDIF}

end.
