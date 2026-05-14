{ ============================================================================
  DeepBase.Browser.CDP
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Chrome DevTools Protocol (CDP) strategy layer.
                Provides DOM operations, input simulation, and runtime
                evaluation via CDP commands through IBrowserSession.
                Generalized from DeepCompare AutoStrategyCDP.
  Thread Safety: All public methods are thread-safe via FLock.
  ============================================================================ }

unit DeepBase.Browser.CDP;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  System.JSON,
  DeepBase.Browser.Types;

type
  TCDPStrategy = class
  private
    FSession: IBrowserSession;
    FPendingCallbacks: TDictionary<Integer, TCDPCallback>;
    FEventCallbacks: TDictionary<string, TCDPCDEventCallback>;
    FCallbackId: Integer;
    FLock: TCriticalSection;

    function GetNextCallbackId: Integer;
    function SendCDPCommand(const AMethod: string;
      const AParams: string): string;
  public
    constructor Create(ASession: IBrowserSession);
    destructor Destroy; override;

    procedure Attach(ASession: IBrowserSession);
    procedure Detach;

    procedure SendCommand(const AMethod: string;
      AParams: TJSONObject; ACallback: TCDPCallback);
    function SendCommandSync(const AMethod: string;
      AParams: TJSONObject; out AResult: string): Boolean;

    procedure Subscribe(const AEventName: string;
      ACallback: TCDPCDEventCallback);
    procedure Unsubscribe(const AEventName: string);

    procedure HandleDevToolsEvent(const AMethod, AParams: string);
    procedure HandleDevToolsMethodResult(AMessageId: Integer;
      ASuccess: Boolean; const AResult: string);

    { DOM }
    procedure GetDocument(ACallback: TCDPCallback);
    procedure QuerySelector(ANodeId: Integer;
      const ASelector: string; ACallback: TCDPCallback);
    procedure QuerySelectorAll(ANodeId: Integer;
      const ASelector: string; ACallback: TCDPCallback);
    procedure GetBoxModel(ANodeId: Integer;
      ACallback: TCDPCallback);
    procedure FocusNode(ANodeId: Integer;
      ACallback: TCDPCallback = nil);
    procedure GetOuterHTML(ANodeId: Integer;
      ACallback: TCDPCallback);

    { Input }
    procedure TypeText(const AText: string;
      ACallback: TCDPCallback = nil);
    procedure PressKey(const AKey: string;
      AModifiers: Integer = 0;
      ACallback: TCDPCallback = nil);
    procedure Click(AX, AY: Double;
      const AButton: string = 'left';
      AClickCount: Integer = 1;
      ACallback: TCDPCallback = nil);
    procedure MouseMove(AX, AY: Double;
      ACallback: TCDPCallback = nil);
    procedure Scroll(ADeltaX, ADeltaY: Double;
      ACallback: TCDPCallback = nil);

    { Network }
    procedure EnableNetwork(ACallback: TCDPCallback = nil);
    procedure DisableNetwork(ACallback: TCDPCallback = nil);

    { Runtime }
    procedure Evaluate(const AExpression: string;
      ACallback: TCDPCallback = nil);

    property Session: IBrowserSession read FSession;
  end;

  TAutomationCDP = class
  private
    FCDP: TCDPStrategy;
    FRootNodeId: Integer;
  public
    constructor Create(ACDP: TCDPStrategy);
    destructor Destroy; override;

    procedure InitDOM(ACallback: TCDPCallback);
    procedure InputText(const ASelector, AText: string;
      ACallback: TCDPCallback);
    procedure ClickElement(const ASelector: string;
      ACallback: TCDPCallback);
    procedure WaitForSelector(const ASelector: string;
      ATimeoutMs: Integer; ACallback: TCDPCallback);
    procedure GetElementText(const ASelector: string;
      ACallback: TCDPCallback);
    procedure ScrollToElement(const ASelector: string;
      ACallback: TCDPCallback);

    property RootNodeId: Integer read FRootNodeId;
  end;

implementation

uses
  System.DateUtils;

{ TCDPStrategy }

constructor TCDPStrategy.Create(ASession: IBrowserSession);
begin
  inherited Create;
  FSession := ASession;
  FPendingCallbacks := TDictionary<Integer, TCDPCallback>.Create;
  FEventCallbacks := TDictionary<string, TCDPCDEventCallback>.Create;
  FCallbackId := 0;
  FLock := TCriticalSection.Create;
end;

destructor TCDPStrategy.Destroy;
begin
  Detach;
  FLock.Free;
  FEventCallbacks.Free;
  FPendingCallbacks.Free;
  inherited;
end;

procedure TCDPStrategy.Attach(ASession: IBrowserSession);
begin
  FLock.Enter;
  try
    FSession := ASession;
  finally
    FLock.Leave;
  end;
end;

procedure TCDPStrategy.Detach;
begin
  FLock.Enter;
  try
    FSession := nil;
    FPendingCallbacks.Clear;
  finally
    FLock.Leave;
  end;
end;

function TCDPStrategy.GetNextCallbackId: Integer;
begin
  FLock.Enter;
  try
    Inc(FCallbackId);
    Result := FCallbackId;
  finally
    FLock.Leave;
  end;
end;

function TCDPStrategy.SendCDPCommand(const AMethod: string;
  const AParams: string): string;
var
  LResult, LError: string;
  LSession: IBrowserSession;
begin
  // H2 fix: snapshot FSession under lock so concurrent Detach can't null it
  // mid-call. The local interface ref keeps the session alive for the
  // duration of the call.
  FLock.Enter;
  try
    LSession := FSession;
  finally
    FLock.Leave;
  end;

  if LSession = nil then
    Exit('{"error":"no_session"}');
  if LSession.CallDevToolsProtocol(AMethod, AParams, 10000,
    LResult, LError) then
    Result := LResult
  else
    Result := '{"error":"' + LError.Replace('"', '\"') + '"}';
end;

procedure TCDPStrategy.SendCommand(const AMethod: string;
  AParams: TJSONObject; ACallback: TCDPCallback);
var
  LId: Integer;
  LParamsStr: string;
  LResult, LError: string;
  LSuccess: Boolean;
  LSession: IBrowserSession;
begin
  // H2 fix: snapshot session under lock
  FLock.Enter;
  try
    LSession := FSession;
  finally
    FLock.Leave;
  end;

  if LSession = nil then
  begin
    if Assigned(ACallback) then
      ACallback(False, '{"error":"no_session"}');
    Exit;
  end;

  LId := GetNextCallbackId;

  FLock.Enter;
  try
    if Assigned(ACallback) then
      FPendingCallbacks.AddOrSetValue(LId, ACallback);
  finally
    FLock.Leave;
  end;

  if AParams <> nil then
    LParamsStr := AParams.ToJSON
  else
    LParamsStr := '{}';

  LSuccess := LSession.CallDevToolsProtocol(AMethod, LParamsStr,
    10000, LResult, LError);

  if not LSuccess then
    LResult := '{"error":"' + LError.Replace('"', '\"') + '"}';

  HandleDevToolsMethodResult(LId, LSuccess, LResult);
end;

function TCDPStrategy.SendCommandSync(const AMethod: string;
  AParams: TJSONObject; out AResult: string): Boolean;
var
  LParamsStr: string;
  LError: string;
  LSession: IBrowserSession;
begin
  // H2 fix: snapshot session under lock
  FLock.Enter;
  try
    LSession := FSession;
  finally
    FLock.Leave;
  end;

  if LSession = nil then
  begin
    AResult := '{"error":"no_session"}';
    Exit(False);
  end;

  if AParams <> nil then
    LParamsStr := AParams.ToJSON
  else
    LParamsStr := '{}';

  Result := LSession.CallDevToolsProtocol(AMethod, LParamsStr,
    10000, AResult, LError);
  if not Result then
    AResult := '{"error":"' + LError.Replace('"', '\"') + '"}';
end;

procedure TCDPStrategy.Subscribe(const AEventName: string;
  ACallback: TCDPCDEventCallback);
begin
  FLock.Enter;
  try
    FEventCallbacks.AddOrSetValue(AEventName, ACallback);
  finally
    FLock.Leave;
  end;
end;

procedure TCDPStrategy.Unsubscribe(const AEventName: string);
begin
  FLock.Enter;
  try
    FEventCallbacks.Remove(AEventName);
  finally
    FLock.Leave;
  end;
end;

procedure TCDPStrategy.HandleDevToolsEvent(
  const AMethod, AParams: string);
var
  LCallback: TCDPCDEventCallback;
begin
  FLock.Enter;
  try
    if not FEventCallbacks.TryGetValue(AMethod, LCallback) then
      LCallback := nil;
  finally
    FLock.Leave;
  end;

  if Assigned(LCallback) then
    LCallback(AMethod, AParams);
end;

procedure TCDPStrategy.HandleDevToolsMethodResult(
  AMessageId: Integer; ASuccess: Boolean; const AResult: string);
var
  LCallback: TCDPCallback;
begin
  FLock.Enter;
  try
    if not FPendingCallbacks.TryGetValue(AMessageId, LCallback) then
      LCallback := nil;
    FPendingCallbacks.Remove(AMessageId);
  finally
    FLock.Leave;
  end;

  if Assigned(LCallback) then
    LCallback(ASuccess, AResult);
end;

{ TCDPStrategy -- DOM }

procedure TCDPStrategy.GetDocument(ACallback: TCDPCallback);
begin
  SendCommand('DOM.getDocument', nil, ACallback);
end;

procedure TCDPStrategy.QuerySelector(ANodeId: Integer;
  const ASelector: string; ACallback: TCDPCallback);
var
  LParams: TJSONObject;
begin
  LParams := TJSONObject.Create;
  try
    LParams.AddPair('nodeId', TJSONNumber.Create(ANodeId));
    LParams.AddPair('selector', ASelector);
    SendCommand('DOM.querySelector', LParams, ACallback);
  finally
    LParams.Free;
  end;
end;

procedure TCDPStrategy.QuerySelectorAll(ANodeId: Integer;
  const ASelector: string; ACallback: TCDPCallback);
var
  LParams: TJSONObject;
begin
  LParams := TJSONObject.Create;
  try
    LParams.AddPair('nodeId', TJSONNumber.Create(ANodeId));
    LParams.AddPair('selector', ASelector);
    SendCommand('DOM.querySelectorAll', LParams, ACallback);
  finally
    LParams.Free;
  end;
end;

procedure TCDPStrategy.GetBoxModel(ANodeId: Integer;
  ACallback: TCDPCallback);
var
  LParams: TJSONObject;
begin
  LParams := TJSONObject.Create;
  try
    LParams.AddPair('nodeId', TJSONNumber.Create(ANodeId));
    SendCommand('DOM.getBoxModel', LParams, ACallback);
  finally
    LParams.Free;
  end;
end;

procedure TCDPStrategy.FocusNode(ANodeId: Integer;
  ACallback: TCDPCallback);
var
  LParams: TJSONObject;
begin
  LParams := TJSONObject.Create;
  try
    LParams.AddPair('nodeId', TJSONNumber.Create(ANodeId));
    SendCommand('DOM.focus', LParams, ACallback);
  finally
    LParams.Free;
  end;
end;

procedure TCDPStrategy.GetOuterHTML(ANodeId: Integer;
  ACallback: TCDPCallback);
var
  LParams: TJSONObject;
begin
  LParams := TJSONObject.Create;
  try
    LParams.AddPair('nodeId', TJSONNumber.Create(ANodeId));
    SendCommand('DOM.getOuterHTML', LParams, ACallback);
  finally
    LParams.Free;
  end;
end;

{ TCDPStrategy -- Input }

procedure TCDPStrategy.TypeText(const AText: string;
  ACallback: TCDPCallback);
var
  LParams: TJSONObject;
begin
  LParams := TJSONObject.Create;
  try
    LParams.AddPair('text', AText);
    SendCommand('Input.insertText', LParams, ACallback);
  finally
    LParams.Free;
  end;
end;

procedure TCDPStrategy.PressKey(const AKey: string;
  AModifiers: Integer; ACallback: TCDPCallback);
var
  LParams: TJSONObject;
begin
  LParams := TJSONObject.Create;
  try
    LParams.AddPair('type', 'keyDown');
    LParams.AddPair('key', AKey);
    LParams.AddPair('modifiers', TJSONNumber.Create(AModifiers));
    SendCommand('Input.dispatchKeyEvent', LParams,
      procedure(ASuccess: Boolean; const AResult: string)
      var
        LUpParams: TJSONObject;
      begin
        if ASuccess then
        begin
          LUpParams := TJSONObject.Create;
          try
            LUpParams.AddPair('type', 'keyUp');
            LUpParams.AddPair('key', AKey);
            LUpParams.AddPair('modifiers',
              TJSONNumber.Create(AModifiers));
            SendCommand('Input.dispatchKeyEvent', LUpParams,
              ACallback);
          finally
            LUpParams.Free;
          end;
        end
        else if Assigned(ACallback) then
          ACallback(False, AResult);
      end);
  finally
    LParams.Free;
  end;
end;

procedure TCDPStrategy.Click(AX, AY: Double;
  const AButton: string; AClickCount: Integer;
  ACallback: TCDPCallback);
var
  LParams: TJSONObject;
begin
  LParams := TJSONObject.Create;
  try
    LParams.AddPair('type', 'mousePressed');
    LParams.AddPair('x', TJSONNumber.Create(AX));
    LParams.AddPair('y', TJSONNumber.Create(AY));
    LParams.AddPair('button', AButton);
    LParams.AddPair('clickCount',
      TJSONNumber.Create(AClickCount));
    SendCommand('Input.dispatchMouseEvent', LParams,
      procedure(ASuccess: Boolean; const AResult: string)
      var
        LUpParams: TJSONObject;
      begin
        if ASuccess then
        begin
          LUpParams := TJSONObject.Create;
          try
            LUpParams.AddPair('type', 'mouseReleased');
            LUpParams.AddPair('x', TJSONNumber.Create(AX));
            LUpParams.AddPair('y', TJSONNumber.Create(AY));
            LUpParams.AddPair('button', AButton);
            LUpParams.AddPair('clickCount',
              TJSONNumber.Create(AClickCount));
            SendCommand('Input.dispatchMouseEvent',
              LUpParams, ACallback);
          finally
            LUpParams.Free;
          end;
        end
        else if Assigned(ACallback) then
          ACallback(False, AResult);
      end);
  finally
    LParams.Free;
  end;
end;

procedure TCDPStrategy.MouseMove(AX, AY: Double;
  ACallback: TCDPCallback);
var
  LParams: TJSONObject;
begin
  LParams := TJSONObject.Create;
  try
    LParams.AddPair('type', 'mouseMoved');
    LParams.AddPair('x', TJSONNumber.Create(AX));
    LParams.AddPair('y', TJSONNumber.Create(AY));
    SendCommand('Input.dispatchMouseEvent', LParams, ACallback);
  finally
    LParams.Free;
  end;
end;

procedure TCDPStrategy.Scroll(ADeltaX, ADeltaY: Double;
  ACallback: TCDPCallback);
var
  LParams: TJSONObject;
begin
  LParams := TJSONObject.Create;
  try
    LParams.AddPair('type', 'mouseWheel');
    LParams.AddPair('deltaX', TJSONNumber.Create(ADeltaX));
    LParams.AddPair('deltaY', TJSONNumber.Create(ADeltaY));
    SendCommand('Input.dispatchMouseEvent', LParams, ACallback);
  finally
    LParams.Free;
  end;
end;

{ TCDPStrategy -- Network }

procedure TCDPStrategy.EnableNetwork(ACallback: TCDPCallback);
begin
  SendCommand('Network.enable', nil, ACallback);
end;

procedure TCDPStrategy.DisableNetwork(ACallback: TCDPCallback);
begin
  SendCommand('Network.disable', nil, ACallback);
end;

{ TCDPStrategy -- Runtime }

procedure TCDPStrategy.Evaluate(const AExpression: string;
  ACallback: TCDPCallback);
var
  LParams: TJSONObject;
begin
  LParams := TJSONObject.Create;
  try
    LParams.AddPair('expression', AExpression);
    LParams.AddPair('returnByValue', TJSONBool.Create(True));
    SendCommand('Runtime.evaluate', LParams, ACallback);
  finally
    LParams.Free;
  end;
end;

{ TAutomationCDP }

constructor TAutomationCDP.Create(ACDP: TCDPStrategy);
begin
  inherited Create;
  FCDP := ACDP;
  FRootNodeId := 0;
end;

destructor TAutomationCDP.Destroy;
begin
  inherited;
end;

procedure TAutomationCDP.InitDOM(ACallback: TCDPCallback);
begin
  FCDP.GetDocument(
    procedure(ASuccess: Boolean; const AResult: string)
    var
      LJson: TJSONValue;
      LRoot: TJSONObject;
      LNodeId: Integer;
    begin
      if ASuccess then
      begin
        LJson := TJSONObject.ParseJSONValue(AResult);
        try
          if (LJson <> nil) and (LJson is TJSONObject) then
          begin
            LRoot := LJson as TJSONObject;
            FRootNodeId := LRoot.GetValue<Integer>(
              'root.nodeId', 0);
          end;
        finally
          LJson.Free;
        end;
      end;
      if Assigned(ACallback) then
        ACallback(ASuccess, AResult);
    end);
end;

procedure TAutomationCDP.InputText(const ASelector, AText: string;
  ACallback: TCDPCallback);
begin
  if FRootNodeId = 0 then
  begin
    if Assigned(ACallback) then
      ACallback(False, '{"error":"dom_not_initialized"}');
    Exit;
  end;

  FCDP.QuerySelector(FRootNodeId, ASelector,
    procedure(ASuccess: Boolean; const AResult: string)
    var
      LJson: TJSONValue;
      LNodeId: Integer;
    begin
      if not ASuccess then
      begin
        if Assigned(ACallback) then
          ACallback(False, AResult);
        Exit;
      end;

      LJson := TJSONObject.ParseJSONValue(AResult);
      try
        LNodeId := 0;
        if LJson <> nil then
          LNodeId := LJson.GetValue<Integer>('nodeId', 0);
      finally
        LJson.Free;
      end;

      if LNodeId = 0 then
      begin
        if Assigned(ACallback) then
          ACallback(False, '{"error":"element_not_found"}');
        Exit;
      end;

      FCDP.FocusNode(LNodeId,
        procedure(AFocusSuccess: Boolean;
          const AFocusResult: string)
        begin
          if not AFocusSuccess then
          begin
            if Assigned(ACallback) then
              ACallback(False, AFocusResult);
            Exit;
          end;
          FCDP.TypeText(AText, ACallback);
        end);
    end);
end;

procedure TAutomationCDP.ClickElement(const ASelector: string;
  ACallback: TCDPCallback);
begin
  if FRootNodeId = 0 then
  begin
    if Assigned(ACallback) then
      ACallback(False, '{"error":"dom_not_initialized"}');
    Exit;
  end;

  FCDP.QuerySelector(FRootNodeId, ASelector,
    procedure(ASuccess: Boolean; const AResult: string)
    var
      LJson: TJSONValue;
      LNodeId: Integer;
    begin
      if not ASuccess then
      begin
        if Assigned(ACallback) then
          ACallback(False, AResult);
        Exit;
      end;

      LJson := TJSONObject.ParseJSONValue(AResult);
      try
        LNodeId := 0;
        if LJson <> nil then
          LNodeId := LJson.GetValue<Integer>('nodeId', 0);
      finally
        LJson.Free;
      end;

      if LNodeId = 0 then
      begin
        if Assigned(ACallback) then
          ACallback(False, '{"error":"element_not_found"}');
        Exit;
      end;

      FCDP.GetBoxModel(LNodeId,
        procedure(ABoxSuccess: Boolean;
          const ABoxResult: string)
        var
          LBoxJson: TJSONValue;
          LContent: TJSONArray;
          LX, LY: Double;
          I: Integer;
        begin
          if not ABoxSuccess then
          begin
            if Assigned(ACallback) then
              ACallback(False, ABoxResult);
            Exit;
          end;

          LBoxJson := TJSONObject.ParseJSONValue(ABoxResult);
          try
            LX := 0;
            LY := 0;
            if LBoxJson <> nil then
            begin
              LContent := (LBoxJson as TJSONObject).GetValue(
                'model.content') as TJSONArray;
              if (LContent <> nil) and
                (LContent.Count >= 8) then
              begin
                for I := 0 to 3 do
                begin
                  LX := LX +
                    LContent.Items[I * 2].AsType<Double>;
                  LY := LY +
                    LContent.Items[I * 2 + 1].AsType<Double>;
                end;
                LX := LX / 4;
                LY := LY / 4;
              end;
            end;
          finally
            LBoxJson.Free;
          end;

          FCDP.Click(LX, LY, 'left', 1, ACallback);
        end);
    end);
end;

procedure TAutomationCDP.WaitForSelector(const ASelector: string;
  ATimeoutMs: Integer; ACallback: TCDPCallback);
var
  LRootNodeId: Integer;
begin
  if FRootNodeId = 0 then
  begin
    if Assigned(ACallback) then
      ACallback(False, '{"error":"dom_not_initialized"}');
    Exit;
  end;

  LRootNodeId := FRootNodeId;
  TThread.CreateAnonymousThread(
    procedure
    const
      PollIntervalMs = 100;
    var
      LStartTime: TDateTime;
      LElapsed: Int64;
      LParams: TJSONObject;
      LResult: string;
      LJson: TJSONValue;
      LNodeId: Integer;
    begin
      LStartTime := Now;
      repeat
        LParams := TJSONObject.Create;
        try
          LParams.AddPair('nodeId',
            TJSONNumber.Create(LRootNodeId));
          LParams.AddPair('selector', ASelector);
          if FCDP.SendCommandSync('DOM.querySelector',
            LParams, LResult) then
          begin
            LJson := TJSONObject.ParseJSONValue(LResult);
            try
              LNodeId := 0;
              if LJson <> nil then
                LNodeId := LJson.GetValue<Integer>(
                  'nodeId', 0);
            finally
              LJson.Free;
            end;

            if LNodeId > 0 then
            begin
              if Assigned(ACallback) then
                TThread.Queue(nil, TThreadProcedure(
                  procedure
                  begin
                    ACallback(True, LResult);
                  end));
              Exit;
            end;
          end;
        finally
          LParams.Free;
        end;

        TThread.Sleep(PollIntervalMs);
        LElapsed := MilliSecondsBetween(Now, LStartTime);
      until LElapsed >= ATimeoutMs;

      if Assigned(ACallback) then
        TThread.Queue(nil, TThreadProcedure(
          procedure
          begin
            ACallback(False, '{"error":"timeout"}');
          end));
    end).Start;
end;

procedure TAutomationCDP.GetElementText(
  const ASelector: string; ACallback: TCDPCallback);
var
  LExpr: string;
begin
  LExpr :=
    'document.querySelector(' + QuotedStr(ASelector) +
    ')?.textContent || ""';
  FCDP.Evaluate(LExpr, ACallback);
end;

procedure TAutomationCDP.ScrollToElement(
  const ASelector: string; ACallback: TCDPCallback);
var
  LExpr: string;
begin
  LExpr :=
    '(function(){var el=document.querySelector(' +
    QuotedStr(ASelector) +
    ');if(el&&el.scrollIntoView)el.scrollIntoView(' +
    '{block:"center"});return !!el;})()';
  FCDP.Evaluate(LExpr, ACallback);
end;

end.
