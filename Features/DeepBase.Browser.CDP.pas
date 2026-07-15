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
    FDetached: Boolean;
  public
    constructor Create(ACDP: TCDPStrategy);
    destructor Destroy; override;

    procedure Detach;
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

    /// <summary>Root node ID for selector queries. Write access is exposed for
    /// test setup (e.g. TAutomationCDPLifecycleTests).</summary>
    property RootNodeId: Integer read FRootNodeId write FRootNodeId;
  end;

implementation

uses
  System.DateUtils;

function KeyCodeFor(const AKey: string): string;
begin
  if (Length(AKey) = 1) and (CharInSet(AKey[1], ['A'..'Z'])) then
    Result := 'Key' + AKey
  else if (Length(AKey) = 1) and (CharInSet(AKey[1], ['a'..'z'])) then
    Result := 'Key' + UpperCase(AKey)
  else if (Length(AKey) = 1) and (CharInSet(AKey[1], ['0'..'9'])) then
    Result := 'Digit' + AKey
  else if AKey = 'Enter' then Result := 'Enter'
  else if AKey = 'Tab' then Result := 'Tab'
  else if AKey = 'Escape' then Result := 'Escape'
  else if AKey = 'Backspace' then Result := 'Backspace'
  else if AKey = 'Delete' then Result := 'Delete'
  else if AKey = 'ArrowUp' then Result := 'ArrowUp'
  else if AKey = 'ArrowDown' then Result := 'ArrowDown'
  else if AKey = 'ArrowLeft' then Result := 'ArrowLeft'
  else if AKey = 'ArrowRight' then Result := 'ArrowRight'
  else if AKey = 'Home' then Result := 'Home'
  else if AKey = 'End' then Result := 'End'
  else if AKey = 'PageUp' then Result := 'PageUp'
  else if AKey = 'PageDown' then Result := 'PageDown'
  else if AKey = ' ' then Result := 'Space'
  else Result := AKey;
end;

function VkCodeFor(const AKey: string): Integer;
begin
  if AKey = 'Enter' then Result := 13
  else if AKey = 'Tab' then Result := 9
  else if AKey = 'Escape' then Result := 27
  else if AKey = 'Backspace' then Result := 8
  else if AKey = 'Delete' then Result := 46
  else if AKey = 'ArrowUp' then Result := 38
  else if AKey = 'ArrowDown' then Result := 40
  else if AKey = 'ArrowLeft' then Result := 37
  else if AKey = 'ArrowRight' then Result := 39
  else if AKey = 'Home' then Result := 36
  else if AKey = 'End' then Result := 35
  else if AKey = 'PageUp' then Result := 33
  else if AKey = 'PageDown' then Result := 34
  else if AKey = ' ' then Result := 32
  else if (Length(AKey) = 1) and (CharInSet(AKey[1], ['A'..'Z', 'a'..'z'])) then
    Result := Ord(UpperCase(AKey)[1])
  else if (Length(AKey) = 1) and (CharInSet(AKey[1], ['0'..'9'])) then
    Result := Ord(AKey[1])
  else
    Result := 0;
end;

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
    // H9 fix: full JSON escape via JsStringLiteral
    LResult := '{"error":' + JsStringLiteral(LError) + '}';

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
    // H9 fix: full JSON escape via JsStringLiteral
    AResult := '{"error":' + JsStringLiteral(LError) + '}';
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
  LCode: string;
  LVk: Integer;
begin
  LCode := KeyCodeFor(AKey);
  LVk := VkCodeFor(AKey);

  LParams := TJSONObject.Create;
  try
    LParams.AddPair('type', 'keyDown');
    LParams.AddPair('key', AKey);
    LParams.AddPair('code', LCode);
    LParams.AddPair('modifiers', TJSONNumber.Create(AModifiers));
    if LVk <> 0 then
      LParams.AddPair('windowsVirtualKeyCode',
        TJSONNumber.Create(LVk));
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
            LUpParams.AddPair('code', LCode);
            LUpParams.AddPair('modifiers',
              TJSONNumber.Create(AModifiers));
            if LVk <> 0 then
              LUpParams.AddPair('windowsVirtualKeyCode',
                TJSONNumber.Create(LVk));
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
    LParams.AddPair('x', TJSONNumber.Create(0));
    LParams.AddPair('y', TJSONNumber.Create(0));
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
  FDetached := False;
end;

destructor TAutomationCDP.Destroy;
begin
  Detach;
  inherited;
end;

procedure TAutomationCDP.Detach;
begin
  FDetached := True;
  FCDP := nil;
end;

procedure TAutomationCDP.InitDOM(ACallback: TCDPCallback);
begin
  if FDetached or (FCDP = nil) then
  begin
    if Assigned(ACallback) then
      ACallback(False, '{"error":"detached"}');
    Exit;
  end;

  FCDP.GetDocument(
    procedure(ASuccess: Boolean; const AResult: string)
    var
      LJson: TJSONValue;
      LRoot: TJSONObject;
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
  if FDetached or (FCDP = nil) then
  begin
    if Assigned(ACallback) then
      ACallback(False, '{"error":"detached"}');
    Exit;
  end;

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
  if FDetached or (FCDP = nil) then
  begin
    if Assigned(ACallback) then
      ACallback(False, '{"error":"detached"}');
    Exit;
  end;

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
  LSelf: TAutomationCDP;
begin
  if FDetached or (FCDP = nil) then
  begin
    if Assigned(ACallback) then
      ACallback(False, '{"error":"detached"}');
    Exit;
  end;

  if FRootNodeId = 0 then
  begin
    if Assigned(ACallback) then
      ACallback(False, '{"error":"dom_not_initialized"}');
    Exit;
  end;

  LRootNodeId := FRootNodeId;
  // REVIEW5-FEAT-009: Capture Self instead of FCDP to avoid use-after-free.
  // Check FDetached on each iteration to detect detach/destroy during polling.
  LSelf := Self;
  var LThread := TThread.CreateAnonymousThread(
    procedure
    var
      LStartTime: TDateTime;
      LElapsed: Int64;
      LParams: TJSONObject;
      LResult: string;
      LJson: TJSONValue;
      LNodeId: Integer;
      LCallbackRef: TCDPCallback;
      LLiveCDP: TCDPStrategy;
    begin
      // H12 fix: capture callback locally + wrap in try/except so any
      // exception in the polling loop surfaces back to the caller as an
      // error instead of silently terminating the worker thread.
      LCallbackRef := ACallback;
      try
        LStartTime := Now;
        repeat
          // REVIEW5-FEAT-009: Check detached flag on each iteration
          // to avoid accessing destroyed FCDP
          if LSelf.FDetached then
          begin
            if Assigned(LCallbackRef) then
              TThread.Queue(nil,
                procedure
                begin
                  LCallbackRef(False, '{"error":"detached"}');
                end);
            Exit;
          end;

          // REVIEW5-FEAT-009: Capture FCDP under each iteration to get
          // the latest value. If it's nil, we've been detached.
          LLiveCDP := LSelf.FCDP;
          if LLiveCDP = nil then
          begin
            if Assigned(LCallbackRef) then
              TThread.Queue(nil,
                procedure
                begin
                  LCallbackRef(False, '{"error":"detached"}');
                end);
            Exit;
          end;

          LParams := TJSONObject.Create;
          try
            LParams.AddPair('nodeId',
              TJSONNumber.Create(LRootNodeId));
            LParams.AddPair('selector', ASelector);
            if LLiveCDP.SendCommandSync('DOM.querySelector',
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
                if Assigned(LCallbackRef) then
                  TThread.Queue(nil,
                    procedure
                    begin
                      LCallbackRef(True, LResult);
                    end);
                Exit;
              end;
            end;
          finally
            LParams.Free;
          end;

          TThread.Sleep(100);  // PollIntervalMs
          LElapsed := MilliSecondsBetween(Now, LStartTime);
        until LElapsed >= ATimeoutMs;

        if Assigned(LCallbackRef) then
          TThread.Queue(nil,
            procedure
            begin
              LCallbackRef(False, '{"error":"timeout"}');
            end);
      except
        on E: Exception do
          if Assigned(LCallbackRef) then
          begin
            // Capture message so the closure below sees the right text
            var LMsg := E.Message;
            TThread.Queue(nil,
              procedure
              begin
                LCallbackRef(False, '{"error":' +
                  JsStringLiteral(LMsg) + '}');
              end);
          end;
      end;
    end);
  LThread.FreeOnTerminate := True;
  LThread.Start;
end;

procedure TAutomationCDP.GetElementText(
  const ASelector: string; ACallback: TCDPCallback);
var
  LExpr: string;
begin
  if FDetached or (FCDP = nil) then
  begin
    if Assigned(ACallback) then
      ACallback(False, '{"error":"detached"}');
    Exit;
  end;

  // H4 fix: use JsStringLiteral so selectors with quotes / Unicode survive
  LExpr :=
    'document.querySelector(' + JsStringLiteral(ASelector) +
    ')?.textContent || ""';
  FCDP.Evaluate(LExpr, ACallback);
end;

procedure TAutomationCDP.ScrollToElement(
  const ASelector: string; ACallback: TCDPCallback);
var
  LExpr: string;
begin
  if FDetached or (FCDP = nil) then
  begin
    if Assigned(ACallback) then
      ACallback(False, '{"error":"detached"}');
    Exit;
  end;

  // H4 fix: use JsStringLiteral so selectors with quotes / Unicode survive
  LExpr :=
    '(function(){var el=document.querySelector(' +
    JsStringLiteral(ASelector) +
    ');if(el&&el.scrollIntoView)el.scrollIntoView(' +
    '{block:"center"});return !!el;})()';
  FCDP.Evaluate(LExpr, ACallback);
end;

end.
