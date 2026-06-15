{*******************************************************}
{                                                       }
{       DeepBase Exception Hierarchy                     }
{                                                       }
{       Copyright (C) 2025 DeepBase                      }
{                                                       }
{       ç»ä¸å¼å¸¸ç±»å±æ¬¡ç»æ?                             }
{       ç¨äºæ¿æ¢æ³å Exception.Create è°ç¨             }
{                                                       }
{*******************************************************}

unit DeepBase.Exceptions;

interface

uses
  System.SysUtils, System.Classes;

type
  /// <summary>
  /// DeepBase å¼å¸¸åºç±»
  /// ææ?DeepBase ç¹å®å¼å¸¸é½åºç»§æ¿èªæ­¤ç±?
  /// </summary>
  EDeepBaseException = class(Exception)
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
  // å®å¨ä¸å å¯å¼å¸?
  //============================================================================

  /// <summary>
  /// å®å¨æ¨¡åå¼å¸¸åºç±»
  /// </summary>
  ESecurityException = class(EDeepBaseException);

  /// <summary>
  /// å å¯/è§£å¯æä½å¤±è´¥
  /// </summary>
  EEncryptionException = class(ESecurityException);

  /// <summary>
  /// è§£å¯æä½å¤±è´¥
  /// </summary>
  EDecryptionException = class(ESecurityException);

  /// <summary>
  /// åå¸è®¡ç®å¤±è´¥
  /// </summary>
  EHashException = class(ESecurityException);

  /// <summary>
  /// æ°å­ç­¾åç¸å³å¼å¸¸
  /// </summary>
  ESignatureException = class(ESecurityException);

  /// <summary>
  /// é²ç¯¡æ¹ç¸å³å¼å¸?
  /// </summary>
  EAntiTamperException = class(ESecurityException);

  /// <summary>
  /// ä¿æ¤æ¨¡åå¼å¸¸
  /// </summary>
  EProtectionException = class(ESecurityException);

  /// <summary>
  /// éæºæ°çæå¼å¸?
  /// </summary>
  ERandomException = class(ESecurityException);

  //============================================================================
  // æ°æ®åºå¼å¸?
  //============================================================================

  /// <summary>
  /// æ°æ®åºæ¨¡åå¼å¸¸åºç±?
  /// </summary>
  EDatabaseException = class(EDeepBaseException)
  private
    FSQL: string;
    FDBType: string;
  public
    constructor Create(const AMessage: string; const ASQL: string = ''); overload;
    property SQL: string read FSQL;
    property DBType: string read FDBType write FDBType;
  end;

  /// <summary>
  /// è¿æ¥æ± å¼å¸?
  /// </summary>
  EPoolException = class(EDatabaseException);

  /// <summary>
  /// è¿æ¥è¶æ¶å¼å¸¸
  /// </summary>
  EConnectionTimeoutException = class(EPoolException);

  /// <summary>
  /// è¿æ¥æ± æªåå§åå¼å¸?
  /// </summary>
  EPoolNotInitializedException = class(EPoolException);

  //============================================================================
  // éç½®å¼å¸¸
  //============================================================================

  /// <summary>
  /// éç½®æ¨¡åå¼å¸¸åºç±»
  /// </summary>
  EConfigException = class(EDeepBaseException);

  /// <summary>
  /// éç½®æªæ¾å?
  /// </summary>
  EConfigNotFoundException = class(EConfigException);

  /// <summary>
  /// éç½®å¼æ æ?
  /// </summary>
  EConfigInvalidValueException = class(EConfigException);

  //============================================================================
  // å¤ä»½å¼å¸¸
  //============================================================================

  /// <summary>
  /// å¤ä»½æ¨¡åå¼å¸¸åºç±»
  /// </summary>
  EBackupException = class(EDeepBaseException);

  /// <summary>
  /// å¤ä»½æä½åæ¶
  /// </summary>
  EBackupCancelledException = class(EBackupException);

  /// <summary>
  /// å¤ä»½æä½æ­£å¨è¿è¡ä¸?
  /// </summary>
  EBackupInProgressException = class(EBackupException);

  /// <summary>
  /// äºæå¡æªéç½®
  /// </summary>
  ECloudServiceNotConfiguredException = class(EBackupException);

  /// <summary>
  /// å¤ä»½æä»¶ä¸å­å?
  /// </summary>
  EBackupFileNotFoundException = class(EBackupException);

  /// <summary>
  /// å¤ä»½ä¸ä¼ /ä¸è½½å¤±è´¥
  /// </summary>
  EBackupTransferException = class(EBackupException);

  //============================================================================
  // ç½ç»ä¸æå¡å¼å¸?
  //============================================================================

  /// <summary>
  /// ç½ç»æ¨¡åå¼å¸¸åºç±»
  /// </summary>
  ENetworkException = class(EDeepBaseException);

  /// <summary>
  /// HTTP æå¡å¨å¼å¸?
  /// </summary>
  EHttpServerException = class(ENetworkException);

  /// <summary>
  /// æå¡å¨å·²å¨è¿è¡?
  /// </summary>
  EServerAlreadyRunningException = class(EHttpServerException);

  /// <summary>
  /// WebSocket å¼å¸¸
  /// </summary>
  EWebSocketException = class(ENetworkException);

  //============================================================================
  // å¼¹æ§ä¸å®¹éå¼å¸¸
  //============================================================================

  /// <summary>
  /// å¼¹æ§æ¨¡åå¼å¸¸åºç±?
  /// </summary>
  EResilienceException = class(EDeepBaseException);

  /// <summary>
  /// æ­è·¯å¨å¼å¸?
  /// </summary>
  ECircuitBreakerException = class(EResilienceException);

  /// <summary>
  /// æ­è·¯å¨æ³¨åè¡¨æªåå§å
  /// </summary>
  ECircuitBreakerNotInitializedException = class(ECircuitBreakerException);

  //============================================================================
  // åå§åå¼å¸?
  //============================================================================

  /// <summary>
  /// åå§åå¼å¸¸åºç±?
  /// </summary>
  EInitializationException = class(EDeepBaseException);

  /// <summary>
  /// æ¨¡åæªåå§å
  /// </summary>
  ENotInitializedException = class(EInitializationException);

  /// <summary>
  /// éç½®ç¼ºå¤±
  /// </summary>
  EMissingConfigurationException = class(EInitializationException);

  //============================================================================
  // æä½å¼å¸¸
  //============================================================================

  /// <summary>
  /// æä½å¼å¸¸åºç±»
  /// </summary>
  EOperationException = class(EDeepBaseException);

  /// <summary>
  /// æä½æ­£å¨è¿è¡ä¸?
  /// </summary>
  EOperationInProgressException = class(EOperationException);

  /// <summary>
  /// æä½å·²åæ¶?
  /// </summary>
  EOperationCancelledException = class(EOperationException);

  /// <summary>
  /// æ ææä½
  /// </summary>
  EInvalidOperationException = class(EOperationException);

  //============================================================================
  // æä»¶å¼å¸¸
  //============================================================================

  /// <summary>
  /// æä»¶æä½å¼å¸¸åºç±»
  /// </summary>
  EFileOperationException = class(EDeepBaseException);

  /// <summary>
  /// æä»¶æªæ¾å?
  /// </summary>
  EFileNotFoundExceptionEx = class(EFileOperationException);

  //============================================================================
  // è¾å©å½æ°
  //============================================================================

  /// <summary>
  /// è·åç³»ç»éè¯¯æ¶æ¯ï¼Windowsï¼?
  /// </summary>
  function GetLastErrorMessage: string;

  /// <summary>
  /// æåºå¸¦ç³»ç»éè¯¯çå¼å¸¸
  /// </summary>
  procedure RaiseLastOSError(const AContext: string = '');

  //============================================================================
  // External database exceptions (32.data)
  //============================================================================
  EExternalDBException = class(EDeepBaseException);
  EExternalDBError = class(EExternalDBException);
  EExternalDBBusy = class(EExternalDBException);
  EWriteAttemptBlocked = class(EExternalDBException);
  EExternalSchemaChanged = class(EExternalDBException);
  EUnsupportedSQLCipherConfig = class(EExternalDBException);

  //============================================================================
  // SchemaAdapter exceptions (33.data)
  //============================================================================
  ESchemaAdapterException = class(EDeepBaseException);
  ESchemaAdapterValidationError = class(ESchemaAdapterException);
  EUnsupportedSchemaVersion = class(ESchemaAdapterException);

  //============================================================================
  // UIA exceptions (34.data)
  //============================================================================
  EUIAException = class(EDeepBaseException);
  EUIAEngineError = class(EUIAException);
  EUIAElementNotFound = class(EUIAException);
  EUIAInvalidContent = class(EUIAException);
  EUIAUnsupportedVersion = class(EUIAException);

  //============================================================================
  // Clipboard and Window exceptions (35.data)
  //============================================================================
  EClipboardException = class(EDeepBaseException);
  EClipboardError = class(EClipboardException);
  EWindowMonitorException = class(EDeepBaseException);
  EWindowMonitorError = class(EWindowMonitorException);

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  System.DateUtils;

{ EDeepBaseException }

constructor EDeepBaseException.Create(const AMessage: string);
begin
  inherited Create(AMessage);
  FErrorCode := 0;
  FContext := '';
  FTimestamp := Now;
end;

constructor EDeepBaseException.Create(const AMessage: string; AErrorCode: Integer);
begin
  inherited Create(AMessage);
  FErrorCode := AErrorCode;
  FContext := '';
  FTimestamp := Now;
end;

constructor EDeepBaseException.Create(const AMessage: string; const AContext: string);
begin
  inherited Create(AMessage);
  FErrorCode := 0;
  FContext := AContext;
  FTimestamp := Now;
end;

constructor EDeepBaseException.Create(const AMessage: string; AErrorCode: Integer;
  const AContext: string);
begin
  inherited Create(AMessage);
  FErrorCode := AErrorCode;
  FContext := AContext;
  FTimestamp := Now;
end;

constructor EDeepBaseException.CreateFmt(const AFormat: string;
  const AArgs: array of const);
begin
  inherited CreateFmt(AFormat, AArgs);
  FErrorCode := 0;
  FContext := '';
  FTimestamp := Now;
end;

function EDeepBaseException.ToString: string;
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
      raise EDeepBaseException.Create(AContext + ': ' + ErrorMsg, ErrorCode)
    else
      raise EDeepBaseException.Create(ErrorMsg, ErrorCode);
  end;
end;
{$ELSE}
begin
  // Non-Windows platforms
end;
{$ENDIF}

end.
