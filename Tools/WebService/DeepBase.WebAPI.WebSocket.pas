{*******************************************************}
{                                                       }
{       DeepBase Framework                               }
{       WebSocket Support                               }
{                                                       }
{       版权所有 (C) 2025                               }
{                                                       }
{*******************************************************}

unit DeepBase.WebAPI.WebSocket;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.SyncObjs,
  System.DateUtils,
  System.Hash,
  System.NetEncoding,
  System.Rtti,
  IdHTTPServer,
  IdContext,
  IdCustomHTTPServer,
  IdTCPConnection,
  IdGlobal,
  IdIOHandler,
  DeepBase.Exceptions;

type
  // WebSocket 操作码
  TWebSocketOpcode = (
    wocContinuation = $0,
    wocText = $1,
    wocBinary = $2,
    wocClose = $8,
    wocPing = $9,
    wocPong = $A
  );

  // WebSocket 关闭状态码
  TWebSocketCloseCode = (
    wsccNormal = 1000,
    wsccGoingAway = 1001,
    wsccProtocolError = 1002,
    wsccUnsupported = 1003,
    wsccNoStatus = 1005,
    wsccAbnormal = 1006,
    wsccInvalidPayload = 1007,
    wsccPolicyViolation = 1008,
    wsccMessageTooBig = 1009,
    wsccMandatoryExtension = 1010,
    wsccInternalError = 1011,
    wsccServiceRestart = 1012,
    wsccTryAgainLater = 1013
  );

  // 前置声明
  TWebSocketConnection = class;
  TWebSocketServer = class;
  TWebSocketRoom = class;

  // WebSocket 消息
  TWebSocketMessage = class
  private
    FOpcode: TWebSocketOpcode;
    FData: TBytes;
    FText: string;
    FIsFinal: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    property Opcode: TWebSocketOpcode read FOpcode write FOpcode;
    property Data: TBytes read FData write FData;
    property Text: string read FText write FText;
    property IsFinal: Boolean read FIsFinal write FIsFinal;

    function IsText: Boolean;
    function IsBinary: Boolean;
    function IsControl: Boolean;
    function AsJSON: TJSONValue;
  end;

  // WebSocket 帧
  TWebSocketFrame = record
    Fin: Boolean;
    RSV1: Boolean;
    RSV2: Boolean;
    RSV3: Boolean;
    Opcode: TWebSocketOpcode;
    Masked: Boolean;
    PayloadLength: Int64;
    MaskingKey: array[0..3] of Byte;
    Payload: TBytes;
  end;

  // 连接状态
  TWebSocketState = (wssConnecting, wssOpen, wssClosing, wssClosed);

  // 事件回调
  TOnWebSocketConnect = reference to procedure(AConnection: TWebSocketConnection);
  TOnWebSocketDisconnect = reference to procedure(AConnection: TWebSocketConnection);
  TOnWebSocketMessage = reference to procedure(AConnection: TWebSocketConnection; AMessage: TWebSocketMessage);
  TOnWebSocketError = reference to procedure(AConnection: TWebSocketConnection; const AError: string);

  // WebSocket 连接
  TWebSocketConnection = class
  private
    FId: string;
    FContext: TIdContext;
    FState: TWebSocketState;
    FServer: TWebSocketServer;
    FPath: string;
    FHeaders: TDictionary<string, string>;
    FUserData: TDictionary<string, TValue>;
    FConnectedAt: TDateTime;
    FLastPingAt: TDateTime;
    FLastPongAt: TDateTime;
    FRooms: TStringList;
    FLock: TCriticalSection;
    FUserId: string;

    procedure SendFrame(const AFrame: TWebSocketFrame);
    function ReadFrame: TWebSocketFrame;
    procedure ProcessFrame(const AFrame: TWebSocketFrame);
    procedure HandleClose(const AData: TBytes);
    procedure HandlePing(const AData: TBytes);
    procedure HandlePong(const AData: TBytes);
  public
    constructor Create(AContext: TIdContext; AServer: TWebSocketServer);
    destructor Destroy; override;

    property Id: string read FId;
    property Context: TIdContext read FContext;
    property State: TWebSocketState read FState;
    property Server: TWebSocketServer read FServer;
    property Path: string read FPath write FPath;
    property Headers: TDictionary<string, string> read FHeaders;
    property UserData: TDictionary<string, TValue> read FUserData;
    property ConnectedAt: TDateTime read FConnectedAt;
    property LastPingAt: TDateTime read FLastPingAt;
    property LastPongAt: TDateTime read FLastPongAt;
    property Rooms: TStringList read FRooms;
    property UserId: string read FUserId write FUserId;

    // 发送消息
    procedure Send(const AText: string); overload;
    procedure Send(const AData: TBytes); overload;
    procedure SendJSON(AValue: TJSONValue; AOwnsValue: Boolean = True);

    // Ping/Pong
    procedure Ping(const AData: TBytes = nil);
    procedure Pong(const AData: TBytes = nil);

    // 关闭连接
    procedure Close(ACode: TWebSocketCloseCode = wsccNormal; const AReason: string = '');

    // 房间操作
    procedure Join(const ARoomName: string);
    procedure Leave(const ARoomName: string);
    function IsInRoom(const ARoomName: string): Boolean;

    // 用户数据
    procedure SetData(const AKey: string; const AValue: TValue);
    function GetData(const AKey: string): TValue;
    function GetDataOrDefault<T>(const AKey: string; const ADefault: T): T;

    // 获取头部
    function GetHeader(const AName: string; const ADefault: string = ''): string;

    // 处理循环
    procedure Run;
  end;

  // WebSocket 房间
  TWebSocketRoom = class
  private
    FName: string;
    FConnections: TList<TWebSocketConnection>;
    FLock: TCriticalSection;
    FCreatedAt: TDateTime;
    FMetadata: TDictionary<string, string>;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;

    property Name: string read FName;
    property Connections: TList<TWebSocketConnection> read FConnections;
    property CreatedAt: TDateTime read FCreatedAt;
    property Metadata: TDictionary<string, string> read FMetadata;

    procedure Add(AConnection: TWebSocketConnection);
    procedure Remove(AConnection: TWebSocketConnection);
    function Contains(AConnection: TWebSocketConnection): Boolean;
    function Count: Integer;

    // 广播
    procedure Broadcast(const AText: string; AExcept: TWebSocketConnection = nil);
    procedure BroadcastJSON(AValue: TJSONValue; AExcept: TWebSocketConnection = nil);
    procedure BroadcastBinary(const AData: TBytes; AExcept: TWebSocketConnection = nil);
  end;

  // WebSocket 服务器配置
  TWebSocketConfig = class
  private
    FMaxFrameSize: Int64;
    FMaxMessageSize: Int64;
    FPingInterval: Integer;
    FPongTimeout: Integer;
    FHandshakeTimeout: Integer;
    FAllowedOrigins: TStringList;
  public
    constructor Create;
    destructor Destroy; override;

    property MaxFrameSize: Int64 read FMaxFrameSize write FMaxFrameSize;
    property MaxMessageSize: Int64 read FMaxMessageSize write FMaxMessageSize;
    property PingInterval: Integer read FPingInterval write FPingInterval;
    property PongTimeout: Integer read FPongTimeout write FPongTimeout;
    property HandshakeTimeout: Integer read FHandshakeTimeout write FHandshakeTimeout;
    property AllowedOrigins: TStringList read FAllowedOrigins;

    function IsOriginAllowed(const AOrigin: string): Boolean;
  end;

  // WebSocket 服务器
  TWebSocketServer = class
  private
    FConnections: TObjectDictionary<string, TWebSocketConnection>;
    FRooms: TObjectDictionary<string, TWebSocketRoom>;
    FConfig: TWebSocketConfig;
    FLock: TCriticalSection;
    FOnConnect: TOnWebSocketConnect;
    FOnDisconnect: TOnWebSocketDisconnect;
    FOnMessage: TOnWebSocketMessage;
    FOnError: TOnWebSocketError;
    FPingThread: TThread;
    FRunning: Boolean;

    function GenerateAcceptKey(const AKey: string): string;
    procedure StartPingThread;
    procedure StopPingThread;
    procedure DoPing;
  public
    constructor Create; overload;
    constructor Create(AConfig: TWebSocketConfig); overload;
    destructor Destroy; override;

    property Connections: TObjectDictionary<string, TWebSocketConnection> read FConnections;
    property Rooms: TObjectDictionary<string, TWebSocketRoom> read FRooms;
    property Config: TWebSocketConfig read FConfig;
    property OnConnect: TOnWebSocketConnect read FOnConnect write FOnConnect;
    property OnDisconnect: TOnWebSocketDisconnect read FOnDisconnect write FOnDisconnect;
    property OnMessage: TOnWebSocketMessage read FOnMessage write FOnMessage;
    property OnError: TOnWebSocketError read FOnError write FOnError;

    // 启动/停止
    procedure Start;
    procedure Stop;

    // 处理升级请求
    function HandleUpgrade(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo): Boolean;

    // 连接管理
    procedure AddConnection(AConnection: TWebSocketConnection);
    procedure RemoveConnection(AConnection: TWebSocketConnection);
    function GetConnection(const AId: string): TWebSocketConnection;
    function GetConnectionByUserId(const AUserId: string): TWebSocketConnection;
    function GetConnectionsByUserId(const AUserId: string): TArray<TWebSocketConnection>;
    function ConnectionCount: Integer;

    // 房间管理
    function GetOrCreateRoom(const ARoomName: string): TWebSocketRoom;
    function GetRoom(const ARoomName: string): TWebSocketRoom;
    procedure DeleteRoom(const ARoomName: string);
    function RoomCount: Integer;

    // 广播
    procedure BroadcastAll(const AText: string; AExcept: TWebSocketConnection = nil);
    procedure BroadcastAllJSON(AValue: TJSONValue; AExcept: TWebSocketConnection = nil);
    procedure BroadcastToRoom(const ARoomName, AText: string; AExcept: TWebSocketConnection = nil);
    procedure BroadcastToUser(const AUserId, AText: string);
    procedure SendTo(const AConnectionId, AText: string);
  end;

  // WebSocket 路由处理
  TWebSocketHandler = reference to procedure(AConnection: TWebSocketConnection; AMessage: TWebSocketMessage);

  // WebSocket 消息处理器
  TWebSocketMessageRouter = class
  private
    FHandlers: TDictionary<string, TWebSocketHandler>;
    FDefaultHandler: TWebSocketHandler;
  public
    constructor Create;
    destructor Destroy; override;

    procedure On(const AEvent: string; AHandler: TWebSocketHandler);
    procedure SetDefault(AHandler: TWebSocketHandler);
    procedure HandleMessage(AConnection: TWebSocketConnection; AMessage: TWebSocketMessage);
  end;

  // 辅助函数
  function WebSocketCloseCodeToInt(ACode: TWebSocketCloseCode): Word;
  function IntToWebSocketCloseCode(ACode: Word): TWebSocketCloseCode;

implementation

const
  WEBSOCKET_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

{ 辅助函数 }

function WebSocketCloseCodeToInt(ACode: TWebSocketCloseCode): Word;
begin
  Result := Word(ACode);
end;

function IntToWebSocketCloseCode(ACode: Word): TWebSocketCloseCode;
begin
  case ACode of
    1000: Result := wsccNormal;
    1001: Result := wsccGoingAway;
    1002: Result := wsccProtocolError;
    1003: Result := wsccUnsupported;
    1005: Result := wsccNoStatus;
    1006: Result := wsccAbnormal;
    1007: Result := wsccInvalidPayload;
    1008: Result := wsccPolicyViolation;
    1009: Result := wsccMessageTooBig;
    1010: Result := wsccMandatoryExtension;
    1011: Result := wsccInternalError;
    1012: Result := wsccServiceRestart;
    1013: Result := wsccTryAgainLater;
  else
    Result := wsccNormal;
  end;
end;

{ TWebSocketMessage }

constructor TWebSocketMessage.Create;
begin
  inherited;
  FIsFinal := True;
end;

destructor TWebSocketMessage.Destroy;
begin
  inherited;
end;

function TWebSocketMessage.IsText: Boolean;
begin
  Result := FOpcode = wocText;
end;

function TWebSocketMessage.IsBinary: Boolean;
begin
  Result := FOpcode = wocBinary;
end;

function TWebSocketMessage.IsControl: Boolean;
begin
  Result := FOpcode in [wocClose, wocPing, wocPong];
end;

function TWebSocketMessage.AsJSON: TJSONValue;
begin
  if IsText then
    Result := TJSONObject.ParseJSONValue(FText)
  else
    Result := nil;
end;

{ TWebSocketConnection }

constructor TWebSocketConnection.Create(AContext: TIdContext; AServer: TWebSocketServer);
var
  LGUID: TGUID;
begin
  inherited Create;
  FContext := AContext;
  FServer := AServer;
  FState := wssConnecting;
  FHeaders := TDictionary<string, string>.Create;
  FUserData := TDictionary<string, TValue>.Create;
  FRooms := TStringList.Create;
  FLock := TCriticalSection.Create;
  FConnectedAt := Now;

  CreateGUID(LGUID);
  FId := GUIDToString(LGUID).Replace('{', '').Replace('}', '').Replace('-', '');
end;

destructor TWebSocketConnection.Destroy;
begin
  FHeaders.Free;
  FUserData.Free;
  FRooms.Free;
  FLock.Free;
  inherited;
end;

procedure TWebSocketConnection.SendFrame(const AFrame: TWebSocketFrame);
var
  LHeader: TBytes;
  LFirstByte: Byte;
  LPayloadLen: Int64;
begin
  FLock.Enter;
  try
    if FState <> wssOpen then
      Exit;

    LPayloadLen := Length(AFrame.Payload);

    // 构建帧头
    LFirstByte := Byte(AFrame.Opcode);
    if AFrame.Fin then
      LFirstByte := LFirstByte or $80;

    // 服务器发送不需要掩码
    if LPayloadLen < 126 then
    begin
      SetLength(LHeader, 2);
      LHeader[0] := LFirstByte;
      LHeader[1] := Byte(LPayloadLen);
    end
    else if LPayloadLen < 65536 then
    begin
      SetLength(LHeader, 4);
      LHeader[0] := LFirstByte;
      LHeader[1] := 126;
      LHeader[2] := Byte((LPayloadLen shr 8) and $FF);
      LHeader[3] := Byte(LPayloadLen and $FF);
    end
    else
    begin
      SetLength(LHeader, 10);
      LHeader[0] := LFirstByte;
      LHeader[1] := 127;
      LHeader[2] := Byte((LPayloadLen shr 56) and $FF);
      LHeader[3] := Byte((LPayloadLen shr 48) and $FF);
      LHeader[4] := Byte((LPayloadLen shr 40) and $FF);
      LHeader[5] := Byte((LPayloadLen shr 32) and $FF);
      LHeader[6] := Byte((LPayloadLen shr 24) and $FF);
      LHeader[7] := Byte((LPayloadLen shr 16) and $FF);
      LHeader[8] := Byte((LPayloadLen shr 8) and $FF);
      LHeader[9] := Byte(LPayloadLen and $FF);
    end;

    // 发送
    FContext.Connection.IOHandler.Write(TIdBytes(LHeader), Length(LHeader));
    if LPayloadLen > 0 then
      FContext.Connection.IOHandler.Write(TIdBytes(AFrame.Payload), Length(AFrame.Payload));
  finally
    FLock.Leave;
  end;
end;

function TWebSocketConnection.ReadFrame: TWebSocketFrame;
var
  LFirstByte: Byte;
  LSecondByte: Byte;
  LPayloadLen: Int64;
  LExtLen: TBytes;
  LMaskBytes: TIdBytes;
  I: Integer;
begin
  Result := Default(TWebSocketFrame);

  // 读取前两个字节
  LFirstByte := FContext.Connection.IOHandler.ReadByte;
  LSecondByte := FContext.Connection.IOHandler.ReadByte;

  Result.Fin := (LFirstByte and $80) <> 0;
  Result.RSV1 := (LFirstByte and $40) <> 0;
  Result.RSV2 := (LFirstByte and $20) <> 0;
  Result.RSV3 := (LFirstByte and $10) <> 0;
  Result.Opcode := TWebSocketOpcode(LFirstByte and $0F);
  Result.Masked := (LSecondByte and $80) <> 0;
  LPayloadLen := LSecondByte and $7F;

  // 读取扩展长度
  if LPayloadLen = 126 then
  begin
    SetLength(LExtLen, 2);
    FContext.Connection.IOHandler.ReadBytes(TIdBytes(LExtLen), 2, False);
    LPayloadLen := (LExtLen[0] shl 8) or LExtLen[1];
  end
  else if LPayloadLen = 127 then
  begin
    SetLength(LExtLen, 8);
    FContext.Connection.IOHandler.ReadBytes(TIdBytes(LExtLen), 8, False);
    LPayloadLen := 0;
    for I := 0 to 7 do
      LPayloadLen := (LPayloadLen shl 8) or LExtLen[I];
  end;

  Result.PayloadLength := LPayloadLen;

  // 读取掩码
  if Result.Masked then
  begin
    SetLength(LMaskBytes, 4);
    FContext.Connection.IOHandler.ReadBytes(LMaskBytes, 4, False);
    // 拷贝到固定数组
    Move(LMaskBytes[0], Result.MaskingKey[0], 4);
  end;

  // 读取负载
  if LPayloadLen > 0 then
  begin
    if LPayloadLen > FServer.Config.MaxFrameSize then
      raise EWebSocketException.Create('Frame too large');

    SetLength(Result.Payload, LPayloadLen);
    FContext.Connection.IOHandler.ReadBytes(TIdBytes(Result.Payload), LPayloadLen, False);

    // 解除掩码
    if Result.Masked then
    begin
      for I := 0 to Length(Result.Payload) - 1 do
        Result.Payload[I] := Result.Payload[I] xor Result.MaskingKey[I mod 4];
    end;
  end;
end;

procedure TWebSocketConnection.ProcessFrame(const AFrame: TWebSocketFrame);
var
  LMessage: TWebSocketMessage;
begin
  case AFrame.Opcode of
    wocText, wocBinary:
    begin
      LMessage := TWebSocketMessage.Create;
      try
        LMessage.Opcode := AFrame.Opcode;
        LMessage.Data := AFrame.Payload;
        LMessage.IsFinal := AFrame.Fin;
        if AFrame.Opcode = wocText then
          LMessage.Text := TEncoding.UTF8.GetString(AFrame.Payload);

        if Assigned(FServer.OnMessage) then
          FServer.OnMessage(Self, LMessage);
      finally
        LMessage.Free;
      end;
    end;
    wocClose:
      HandleClose(AFrame.Payload);
    wocPing:
      HandlePing(AFrame.Payload);
    wocPong:
      HandlePong(AFrame.Payload);
  end;
end;

procedure TWebSocketConnection.HandleClose(const AData: TBytes);
var
  LCode: Word;
  LReason: string;
  LFrame: TWebSocketFrame;
begin
  if FState = wssClosing then
  begin
    FState := wssClosed;
    Exit;
  end;

  FState := wssClosing;

  // 解析关闭码和原因
  if Length(AData) >= 2 then
  begin
    LCode := (AData[0] shl 8) or AData[1];
    if Length(AData) > 2 then
      LReason := TEncoding.UTF8.GetString(AData, 2, Length(AData) - 2);
  end
  else
    LCode := Word(wsccNoStatus);

  // 发送关闭回复
  FillChar(LFrame, SizeOf(LFrame), 0);
  LFrame.Fin := True;
  LFrame.Opcode := wocClose;
  LFrame.Payload := AData;
  SendFrame(LFrame);

  FState := wssClosed;
end;

procedure TWebSocketConnection.HandlePing(const AData: TBytes);
begin
  Pong(AData);
end;

procedure TWebSocketConnection.HandlePong(const AData: TBytes);
begin
  FLastPongAt := Now;
end;

procedure TWebSocketConnection.Send(const AText: string);
var
  LFrame: TWebSocketFrame;
begin
  FillChar(LFrame, SizeOf(LFrame), 0);
  LFrame.Fin := True;
  LFrame.Opcode := wocText;
  LFrame.Payload := TEncoding.UTF8.GetBytes(AText);
  SendFrame(LFrame);
end;

procedure TWebSocketConnection.Send(const AData: TBytes);
var
  LFrame: TWebSocketFrame;
begin
  FillChar(LFrame, SizeOf(LFrame), 0);
  LFrame.Fin := True;
  LFrame.Opcode := wocBinary;
  LFrame.Payload := AData;
  SendFrame(LFrame);
end;

procedure TWebSocketConnection.SendJSON(AValue: TJSONValue; AOwnsValue: Boolean);
begin
  try
    Send(AValue.ToJSON);
  finally
    if AOwnsValue then
      AValue.Free;
  end;
end;

procedure TWebSocketConnection.Ping(const AData: TBytes);
var
  LFrame: TWebSocketFrame;
begin
  FillChar(LFrame, SizeOf(LFrame), 0);
  LFrame.Fin := True;
  LFrame.Opcode := wocPing;
  LFrame.Payload := AData;
  SendFrame(LFrame);
  FLastPingAt := Now;
end;

procedure TWebSocketConnection.Pong(const AData: TBytes);
var
  LFrame: TWebSocketFrame;
begin
  FillChar(LFrame, SizeOf(LFrame), 0);
  LFrame.Fin := True;
  LFrame.Opcode := wocPong;
  LFrame.Payload := AData;
  SendFrame(LFrame);
end;

procedure TWebSocketConnection.Close(ACode: TWebSocketCloseCode; const AReason: string);
var
  LFrame: TWebSocketFrame;
  LPayload: TBytes;
  LReasonBytes: TBytes;
  LCode: Word;
begin
  if FState <> wssOpen then
    Exit;

  FState := wssClosing;

  LCode := WebSocketCloseCodeToInt(ACode);
  LReasonBytes := TEncoding.UTF8.GetBytes(AReason);
  SetLength(LPayload, 2 + Length(LReasonBytes));
  LPayload[0] := Byte((LCode shr 8) and $FF);
  LPayload[1] := Byte(LCode and $FF);
  if Length(LReasonBytes) > 0 then
    Move(LReasonBytes[0], LPayload[2], Length(LReasonBytes));

  FillChar(LFrame, SizeOf(LFrame), 0);
  LFrame.Fin := True;
  LFrame.Opcode := wocClose;
  LFrame.Payload := LPayload;
  SendFrame(LFrame);
end;

procedure TWebSocketConnection.Join(const ARoomName: string);
var
  LRoom: TWebSocketRoom;
begin
  LRoom := FServer.GetOrCreateRoom(ARoomName);
  LRoom.Add(Self);
  if FRooms.IndexOf(ARoomName) < 0 then
    FRooms.Add(ARoomName);
end;

procedure TWebSocketConnection.Leave(const ARoomName: string);
var
  LRoom: TWebSocketRoom;
begin
  LRoom := FServer.GetRoom(ARoomName);
  if LRoom <> nil then
    LRoom.Remove(Self);
  FRooms.Delete(FRooms.IndexOf(ARoomName));
end;

function TWebSocketConnection.IsInRoom(const ARoomName: string): Boolean;
begin
  Result := FRooms.IndexOf(ARoomName) >= 0;
end;

procedure TWebSocketConnection.SetData(const AKey: string; const AValue: TValue);
begin
  FUserData.AddOrSetValue(AKey, AValue);
end;

function TWebSocketConnection.GetData(const AKey: string): TValue;
begin
  FUserData.TryGetValue(AKey, Result);
end;

function TWebSocketConnection.GetDataOrDefault<T>(const AKey: string; const ADefault: T): T;
var
  LValue: TValue;
begin
  if FUserData.TryGetValue(AKey, LValue) then
    Result := LValue.AsType<T>
  else
    Result := ADefault;
end;

function TWebSocketConnection.GetHeader(const AName: string; const ADefault: string): string;
begin
  if not FHeaders.TryGetValue(LowerCase(AName), Result) then
    Result := ADefault;
end;

procedure TWebSocketConnection.Run;
var
  LFrame: TWebSocketFrame;
begin
  FState := wssOpen;

  try
    if Assigned(FServer.OnConnect) then
      FServer.OnConnect(Self);

    while FState = wssOpen do
    begin
      try
        LFrame := ReadFrame;
        ProcessFrame(LFrame);
      except
        on E: Exception do
        begin
          if Assigned(FServer.OnError) then
            FServer.OnError(Self, E.Message);
          Break;
        end;
      end;
    end;
  finally
    // 离开所有房间
    while FRooms.Count > 0 do
      Leave(FRooms[0]);

    FState := wssClosed;

    if Assigned(FServer.OnDisconnect) then
      FServer.OnDisconnect(Self);

    FServer.RemoveConnection(Self);
  end;
end;

{ TWebSocketRoom }

constructor TWebSocketRoom.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FConnections := TList<TWebSocketConnection>.Create;
  FLock := TCriticalSection.Create;
  FMetadata := TDictionary<string, string>.Create;
  FCreatedAt := Now;
end;

destructor TWebSocketRoom.Destroy;
begin
  FConnections.Free;
  FLock.Free;
  FMetadata.Free;
  inherited;
end;

procedure TWebSocketRoom.Add(AConnection: TWebSocketConnection);
begin
  FLock.Enter;
  try
    if not FConnections.Contains(AConnection) then
      FConnections.Add(AConnection);
  finally
    FLock.Leave;
  end;
end;

procedure TWebSocketRoom.Remove(AConnection: TWebSocketConnection);
begin
  FLock.Enter;
  try
    FConnections.Remove(AConnection);
  finally
    FLock.Leave;
  end;
end;

function TWebSocketRoom.Contains(AConnection: TWebSocketConnection): Boolean;
begin
  FLock.Enter;
  try
    Result := FConnections.Contains(AConnection);
  finally
    FLock.Leave;
  end;
end;

function TWebSocketRoom.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FConnections.Count;
  finally
    FLock.Leave;
  end;
end;

procedure TWebSocketRoom.Broadcast(const AText: string; AExcept: TWebSocketConnection);
var
  LConn: TWebSocketConnection;
  LList: TArray<TWebSocketConnection>;
begin
  FLock.Enter;
  try
    LList := FConnections.ToArray;
  finally
    FLock.Leave;
  end;

  for LConn in LList do
  begin
    if (LConn <> AExcept) and (LConn.State = wssOpen) then
    begin
      try
        LConn.Send(AText);
      except
        // 忽略发送错误
      end;
    end;
  end;
end;

procedure TWebSocketRoom.BroadcastJSON(AValue: TJSONValue; AExcept: TWebSocketConnection);
begin
  try
    Broadcast(AValue.ToJSON, AExcept);
  finally
    AValue.Free;
  end;
end;

procedure TWebSocketRoom.BroadcastBinary(const AData: TBytes; AExcept: TWebSocketConnection);
var
  LConn: TWebSocketConnection;
  LList: TArray<TWebSocketConnection>;
begin
  FLock.Enter;
  try
    LList := FConnections.ToArray;
  finally
    FLock.Leave;
  end;

  for LConn in LList do
  begin
    if (LConn <> AExcept) and (LConn.State = wssOpen) then
    begin
      try
        LConn.Send(AData);
      except
        // 忽略发送错误
      end;
    end;
  end;
end;

{ TWebSocketConfig }

constructor TWebSocketConfig.Create;
begin
  inherited;
  FMaxFrameSize := 1024 * 1024;  // 1 MB
  FMaxMessageSize := 10 * 1024 * 1024;  // 10 MB
  FPingInterval := 30000;  // 30 秒
  FPongTimeout := 10000;   // 10 秒
  FHandshakeTimeout := 10000;  // 10 秒
  FAllowedOrigins := TStringList.Create;
end;

destructor TWebSocketConfig.Destroy;
begin
  FAllowedOrigins.Free;
  inherited;
end;

function TWebSocketConfig.IsOriginAllowed(const AOrigin: string): Boolean;
var
  LOrigin: string;
begin
  if Trim(AOrigin) = '' then
    Exit(True);

  if FAllowedOrigins.IndexOf('*') >= 0 then
    Exit(True);

  for LOrigin in FAllowedOrigins do
  begin
    if SameText(LOrigin, AOrigin) then
      Exit(True);
  end;
  Result := False;
end;

{ TWebSocketServer }

constructor TWebSocketServer.Create;
begin
  Create(TWebSocketConfig.Create);
end;

constructor TWebSocketServer.Create(AConfig: TWebSocketConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FConnections := TObjectDictionary<string, TWebSocketConnection>.Create([]);
  FRooms := TObjectDictionary<string, TWebSocketRoom>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
  FRunning := False;
end;

destructor TWebSocketServer.Destroy;
begin
  Stop;
  FConnections.Free;
  FRooms.Free;
  FConfig.Free;
  FLock.Free;
  inherited;
end;

function TWebSocketServer.GenerateAcceptKey(const AKey: string): string;
var
  LHash: TBytes;
begin
  LHash := THashSHA1.GetHashBytes(AKey + WEBSOCKET_GUID);
  Result := TNetEncoding.Base64.EncodeBytesToString(LHash);
end;

procedure TWebSocketServer.StartPingThread;
begin
  if FConfig.PingInterval <= 0 then
    Exit;

  FPingThread := TThread.CreateAnonymousThread(
    procedure
    begin
      while FRunning do
      begin
        Sleep(FConfig.PingInterval);
        if FRunning then
          DoPing;
      end;
    end
  );
  FPingThread.Start;
end;

procedure TWebSocketServer.StopPingThread;
begin
  if FPingThread <> nil then
  begin
    FPingThread.Terminate;
    FPingThread.WaitFor;
    FreeAndNil(FPingThread);
  end;
end;

procedure TWebSocketServer.DoPing;
var
  LConn: TWebSocketConnection;
  LConns: TArray<TWebSocketConnection>;
  LPair: TPair<string, TWebSocketConnection>;
begin
  FLock.Enter;
  try
    SetLength(LConns, FConnections.Count);
    var I := 0;
    for LPair in FConnections do
    begin
      LConns[I] := LPair.Value;
      Inc(I);
    end;
  finally
    FLock.Leave;
  end;

  for LConn in LConns do
  begin
    if LConn.State = wssOpen then
    begin
      try
        LConn.Ping;
      except
        // 忽略
      end;
    end;
  end;
end;

procedure TWebSocketServer.Start;
begin
  if FRunning then
    Exit;
  FRunning := True;
  StartPingThread;
end;

procedure TWebSocketServer.Stop;
var
  LPair: TPair<string, TWebSocketConnection>;
begin
  if not FRunning then
    Exit;

  FRunning := False;
  StopPingThread;

  // 关闭所有连接
  FLock.Enter;
  try
    for LPair in FConnections do
      LPair.Value.Close(wsccGoingAway, 'Server shutdown');
  finally
    FLock.Leave;
  end;
end;

function TWebSocketServer.HandleUpgrade(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo): Boolean;
var
  LKey: string;
  LAcceptKey: string;
  LConnection: TWebSocketConnection;
  LHeader: string;
  LPos: Integer;
begin
  Result := False;

  // 检查是否是 WebSocket 升级请求
  if not SameText(ARequestInfo.RawHeaders.Values['Upgrade'], 'websocket') then
    Exit;
  if not ARequestInfo.RawHeaders.Values['Connection'].ToLower.Contains('upgrade') then
    Exit;

  // 获取 Sec-WebSocket-Key
  LKey := ARequestInfo.RawHeaders.Values['Sec-WebSocket-Key'];
  if LKey = '' then
  begin
    AResponseInfo.ResponseNo := 400;
    AResponseInfo.ResponseText := 'Bad Request';
    Exit;
  end;

  // 检查 Origin
  if not FConfig.IsOriginAllowed(ARequestInfo.RawHeaders.Values['Origin']) then
  begin
    AResponseInfo.ResponseNo := 403;
    AResponseInfo.ResponseText := 'Forbidden';
    Exit;
  end;

  // 生成接受密钥
  LAcceptKey := GenerateAcceptKey(LKey);

  // 发送升级响应
  AResponseInfo.ResponseNo := 101;
  AResponseInfo.ResponseText := 'Switching Protocols';
  AResponseInfo.CustomHeaders.Values['Upgrade'] := 'websocket';
  AResponseInfo.CustomHeaders.Values['Connection'] := 'Upgrade';
  AResponseInfo.CustomHeaders.Values['Sec-WebSocket-Accept'] := LAcceptKey;

  // 写入响应头
  AContext.Connection.IOHandler.WriteLn('HTTP/1.1 101 Switching Protocols');
  AContext.Connection.IOHandler.WriteLn('Upgrade: websocket');
  AContext.Connection.IOHandler.WriteLn('Connection: Upgrade');
  AContext.Connection.IOHandler.WriteLn('Sec-WebSocket-Accept: ' + LAcceptKey);
  AContext.Connection.IOHandler.WriteLn('');

  // 创建 WebSocket 连接
  LConnection := TWebSocketConnection.Create(AContext, Self);
  LConnection.Path := ARequestInfo.URI;

  // 复制请求头
  for LHeader in ARequestInfo.RawHeaders do
  begin
    LPos := Pos(':', LHeader);
    if LPos > 0 then
      LConnection.Headers.AddOrSetValue(
        LowerCase(Trim(Copy(LHeader, 1, LPos - 1))),
        Trim(Copy(LHeader, LPos + 1, Length(LHeader)))
      );
  end;

  AddConnection(LConnection);

  // 启动处理循环（在新线程中）
  TThread.CreateAnonymousThread(
    procedure
    begin
      LConnection.Run;
    end
  ).Start;

  Result := True;
end;

procedure TWebSocketServer.AddConnection(AConnection: TWebSocketConnection);
begin
  FLock.Enter;
  try
    FConnections.Add(AConnection.Id, AConnection);
  finally
    FLock.Leave;
  end;
end;

procedure TWebSocketServer.RemoveConnection(AConnection: TWebSocketConnection);
begin
  FLock.Enter;
  try
    FConnections.Remove(AConnection.Id);
  finally
    FLock.Leave;
  end;
end;

function TWebSocketServer.GetConnection(const AId: string): TWebSocketConnection;
begin
  FLock.Enter;
  try
    FConnections.TryGetValue(AId, Result);
  finally
    FLock.Leave;
  end;
end;

function TWebSocketServer.GetConnectionByUserId(const AUserId: string): TWebSocketConnection;
var
  LPair: TPair<string, TWebSocketConnection>;
begin
  Result := nil;
  FLock.Enter;
  try
    for LPair in FConnections do
    begin
      if LPair.Value.UserId = AUserId then
        Exit(LPair.Value);
    end;
  finally
    FLock.Leave;
  end;
end;

function TWebSocketServer.GetConnectionsByUserId(const AUserId: string): TArray<TWebSocketConnection>;
var
  LList: TList<TWebSocketConnection>;
  LPair: TPair<string, TWebSocketConnection>;
begin
  LList := TList<TWebSocketConnection>.Create;
  try
    FLock.Enter;
    try
      for LPair in FConnections do
      begin
        if LPair.Value.UserId = AUserId then
          LList.Add(LPair.Value);
      end;
    finally
      FLock.Leave;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TWebSocketServer.ConnectionCount: Integer;
begin
  FLock.Enter;
  try
    Result := FConnections.Count;
  finally
    FLock.Leave;
  end;
end;

function TWebSocketServer.GetOrCreateRoom(const ARoomName: string): TWebSocketRoom;
begin
  FLock.Enter;
  try
    if not FRooms.TryGetValue(ARoomName, Result) then
    begin
      Result := TWebSocketRoom.Create(ARoomName);
      FRooms.Add(ARoomName, Result);
    end;
  finally
    FLock.Leave;
  end;
end;

function TWebSocketServer.GetRoom(const ARoomName: string): TWebSocketRoom;
begin
  FLock.Enter;
  try
    FRooms.TryGetValue(ARoomName, Result);
  finally
    FLock.Leave;
  end;
end;

procedure TWebSocketServer.DeleteRoom(const ARoomName: string);
begin
  FLock.Enter;
  try
    FRooms.Remove(ARoomName);
  finally
    FLock.Leave;
  end;
end;

function TWebSocketServer.RoomCount: Integer;
begin
  FLock.Enter;
  try
    Result := FRooms.Count;
  finally
    FLock.Leave;
  end;
end;

procedure TWebSocketServer.BroadcastAll(const AText: string; AExcept: TWebSocketConnection);
var
  LConn: TWebSocketConnection;
  LConns: TArray<TWebSocketConnection>;
  LPair: TPair<string, TWebSocketConnection>;
begin
  FLock.Enter;
  try
    SetLength(LConns, FConnections.Count);
    var I := 0;
    for LPair in FConnections do
    begin
      LConns[I] := LPair.Value;
      Inc(I);
    end;
  finally
    FLock.Leave;
  end;

  for LConn in LConns do
  begin
    if (LConn <> AExcept) and (LConn.State = wssOpen) then
    begin
      try
        LConn.Send(AText);
      except
        // 忽略
      end;
    end;
  end;
end;

procedure TWebSocketServer.BroadcastAllJSON(AValue: TJSONValue; AExcept: TWebSocketConnection);
begin
  try
    BroadcastAll(AValue.ToJSON, AExcept);
  finally
    AValue.Free;
  end;
end;

procedure TWebSocketServer.BroadcastToRoom(const ARoomName, AText: string;
  AExcept: TWebSocketConnection);
var
  LRoom: TWebSocketRoom;
begin
  LRoom := GetRoom(ARoomName);
  if LRoom <> nil then
    LRoom.Broadcast(AText, AExcept);
end;

procedure TWebSocketServer.BroadcastToUser(const AUserId, AText: string);
var
  LConns: TArray<TWebSocketConnection>;
  LConn: TWebSocketConnection;
begin
  LConns := GetConnectionsByUserId(AUserId);
  for LConn in LConns do
  begin
    if LConn.State = wssOpen then
    begin
      try
        LConn.Send(AText);
      except
        // 忽略
      end;
    end;
  end;
end;

procedure TWebSocketServer.SendTo(const AConnectionId, AText: string);
var
  LConn: TWebSocketConnection;
begin
  LConn := GetConnection(AConnectionId);
  if (LConn <> nil) and (LConn.State = wssOpen) then
    LConn.Send(AText);
end;

{ TWebSocketMessageRouter }

constructor TWebSocketMessageRouter.Create;
begin
  inherited;
  FHandlers := TDictionary<string, TWebSocketHandler>.Create;
end;

destructor TWebSocketMessageRouter.Destroy;
begin
  FHandlers.Free;
  inherited;
end;

procedure TWebSocketMessageRouter.On(const AEvent: string; AHandler: TWebSocketHandler);
begin
  FHandlers.AddOrSetValue(AEvent, AHandler);
end;

procedure TWebSocketMessageRouter.SetDefault(AHandler: TWebSocketHandler);
begin
  FDefaultHandler := AHandler;
end;

procedure TWebSocketMessageRouter.HandleMessage(AConnection: TWebSocketConnection;
  AMessage: TWebSocketMessage);
var
  LJson: TJSONObject;
  LEvent: string;
  LHandler: TWebSocketHandler;
begin
  if not AMessage.IsText then
  begin
    if Assigned(FDefaultHandler) then
      FDefaultHandler(AConnection, AMessage);
    Exit;
  end;

  // 尝试解析为 JSON { "event": "...", ... }
  try
    LJson := TJSONObject.ParseJSONValue(AMessage.Text) as TJSONObject;
    if LJson = nil then
    begin
      if Assigned(FDefaultHandler) then
        FDefaultHandler(AConnection, AMessage);
      Exit;
    end;

    try
      LEvent := LJson.GetValue<string>('event', '');
      if (LEvent <> '') and FHandlers.TryGetValue(LEvent, LHandler) then
        LHandler(AConnection, AMessage)
      else if Assigned(FDefaultHandler) then
        FDefaultHandler(AConnection, AMessage);
    finally
      LJson.Free;
    end;
  except
    if Assigned(FDefaultHandler) then
      FDefaultHandler(AConnection, AMessage);
  end;
end;

end.
