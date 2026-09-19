{ ============================================================================
  DeepBase.UITest.FmxProbe

  Embedded HTTP probe for FMX target programs. Installed with a single
  line in the FMX .dpr file:

    TFmxProbe.Install;

  Only activates when --uitest-probe-port=<port> is on the command line.
  When active, serves three endpoints on localhost:<port>:

    GET  /tree           → full control tree as JSON
    POST /tap            → simulate a tap on a named control
    GET  /state?name=xxx → query a control's runtime state

  See: DeepUITest.017-FMX探针策略.md
  ============================================================================ }

unit DeepBase.UITest.FmxProbe;

interface

uses
  System.SysUtils;

type
  TFmxProbeResult = record
    Status: string;      // ok / not_found
    Data: string;        // JSON payload
  end;

  TFmxProbe = class
  private class var
    FPort: Integer;
    FActive: Boolean;
    FServerStarted: Boolean;
  private
    class function EnumerateTree: string;
    class function TapControl(const AName: string): TFmxProbeResult;
    class function QueryState(const AName: string): TFmxProbeResult;
    class function WaitForServer(ATimeoutMs: Integer): Boolean;
  public
    class procedure Install;
    class property Port: Integer read FPort;
    class property Active: Boolean read FActive;
  end;

implementation

uses
  System.Classes,
  System.JSON,
  System.Types,
  System.Rtti,
  System.Threading,
  System.SyncObjs,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  DeepBase.HttpServer;

type
  { Exposes protected TControl.Click without requiring FMX.StdCtrls. }
  TProbeControlAccess = class(TControl);

var
  GServer: THttpServer;

{ ---- Helpers ---- }

/// Constant-time string comparison to prevent timing side-channel on token check.
function SecureTokenEqual(const A, B: string): Boolean;
var
  I, LDiff, LLenA, LLenB: Integer;
begin
  LLenA := Length(A);
  LLenB := Length(B);
  LDiff := LLenA xor LLenB; // if lengths differ, non-zero
  // Compare up to the shorter length without early exit:
  if LLenA < LLenB then
  begin
    for I := 1 to LLenA do
      LDiff := LDiff or (Ord(A[I]) xor Ord(B[I]));
  end
  else
  begin
    for I := 1 to LLenB do
      LDiff := LDiff or (Ord(A[I]) xor Ord(B[I]));
  end;
  Result := LDiff = 0;
end;

function SafeGetText(const AObj: TFMXObject): string;
var
  LCtx: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
begin
  Result := '';
  LCtx := TRttiContext.Create;
  LType := LCtx.GetType(AObj.ClassType);
  if LType = nil then Exit;
  LProp := LType.GetProperty('Text');
  if (LProp <> nil) and LProp.IsReadable then
  begin
    var LVal := LProp.GetValue(AObj);
    if not LVal.IsEmpty then
      Result := LVal.AsString;
  end;
end;

function SafeGetEnabled(const AObj: TFMXObject): Boolean;
var
  LCtx: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
begin
  Result := True;
  LCtx := TRttiContext.Create;
  LType := LCtx.GetType(AObj.ClassType);
  if LType = nil then Exit;
  LProp := LType.GetProperty('Enabled');
  if (LProp <> nil) and LProp.IsReadable then
    Result := LProp.GetValue(AObj).AsBoolean;
end;

function SafeGetIsFocused(const AObj: TFMXObject): Boolean;
var
  LCtx: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
begin
  Result := False;
  LCtx := TRttiContext.Create;
  LType := LCtx.GetType(AObj.ClassType);
  if LType = nil then Exit;
  LProp := LType.GetProperty('IsFocused');
  if (LProp <> nil) and LProp.IsReadable then
    Result := LProp.GetValue(AObj).AsBoolean;
end;

{ TFmxProbe }

class procedure TFmxProbe.Install;
var
  I: Integer;
  LParam: string;
  LAllowRemote: Boolean;
  LToken: string;
  LBindAddr: string;
begin
{$IFNDEF DEBUG}
  // A15: probe excluded from production builds entirely.
  Exit;
{$ENDIF}
  if FActive then Exit;

  for I := 1 to ParamCount do
  begin
    LParam := ParamStr(I);
    if LParam.StartsWith('--uitest-probe-port=') then
    begin
      FPort := StrToIntDef(LParam.Substring(Length('--uitest-probe-port=')), 0);
      Break;
    end;
  end;

  if FPort = 0 then Exit;

  // A15/Top20#12: probe default-disabled, loopback-only, token-authenticated.
  LAllowRemote := False;
  LToken := '';
  for I := 1 to ParamCount do
  begin
    LParam := ParamStr(I);
    if LParam = '--uitest-probe-allow-remote' then
      LAllowRemote := True;
    if LParam.StartsWith('--uitest-probe-token=') then
      LToken := LParam.Substring(Length('--uitest-probe-token='));
  end;
  // No token = refuse to start (fail-closed):
  if LToken = '' then
    Exit;
  if not LAllowRemote then
    LBindAddr := '127.0.0.1'
  else
    LBindAddr := '0.0.0.0';
  FActive := True;

  TThread.CreateAnonymousThread(
    procedure
    begin
      try
        GServer := THttpServer.Create;
        // A15: token auth middleware — reject requests without valid token
        GServer.Use(
          procedure(const ACtx: THttpContext; Next: TProc)
          var
            LProvided: string;
          begin
            LProvided := ACtx.Request.Headers['X-Probe-Token'];
            // constant-time compare (BUG-036)
            if not SecureTokenEqual(LProvided, LToken) then
            begin
              ACtx.Response.Status(403).Text('{"error":"invalid or missing token"}');
              Exit;
            end;
            Next;
          end);
        GServer
          .Get('/tree',
            procedure(const ACtx: THttpContext)
            begin
              ACtx.Response.Json(EnumerateTree);
            end)
          .Get('/state',
            procedure(const ACtx: THttpContext)
            var
              LName: string;
              LResult: TFmxProbeResult;
            begin
              LName := ACtx.Request.Query['name'];
              if LName = '' then
              begin
                ACtx.Response.Status(400).Text('{"error":"missing ?name="}');
                Exit;
              end;
              LResult := QueryState(LName);
              if LResult.Status = 'ok' then
                ACtx.Response.Json(LResult.Data)
              else
                ACtx.Response.Status(404).Text('{"error":"' + LResult.Data + '"}');
            end)
          .Post('/tap',
            procedure(const ACtx: THttpContext)
            var
              LBody: string;
              LJson: TJSONValue;
              LName: string;
              LResult: TFmxProbeResult;
            begin
              LBody := ACtx.Request.Body;
              LJson := TJSONObject.ParseJSONValue(LBody);
              try
                if (LJson = nil) or not (LJson is TJSONObject) then
                begin
                  ACtx.Response.Status(400).Text('{"error":"invalid JSON body"}');
                  Exit;
                end;
                LName := TJSONObject(LJson).GetValue<string>('name');
              finally
                LJson.Free;
              end;

              if LName = '' then
              begin
                ACtx.Response.Status(400).Text('{"error":"missing name in body"}');
                Exit;
              end;

              LResult := TapControl(LName);
              if LResult.Status = 'ok' then
                ACtx.Response.Json(LResult.Data)
              else
                ACtx.Response.Status(404).Text('{"error":"' + LResult.Data + '"}');
            end);

        GServer.Listen(FPort, LBindAddr);
        FServerStarted := True;
      except
        FServerStarted := False;
      end;
    end).Start;
end;

class function TFmxProbe.WaitForServer(ATimeoutMs: Integer): Boolean;
var
  LDeadline: Cardinal;
begin
  LDeadline := TThread.GetTickCount + Cardinal(ATimeoutMs);
  while TThread.GetTickCount < LDeadline do
  begin
    if FServerStarted then Exit(True);
    TThread.Sleep(50);
  end;
  Result := False;
end;

{ ---- Control tree enumeration ---- }

class function TFmxProbe.EnumerateTree: string;

  procedure Walk(const AParent: TFMXObject; const AArray: TJSONArray);
  var
    LChild: TFMXObject;
    LItem: TJSONObject;
    LControl: TControl;
    LRect: TRectF;
  begin
    for var I := 0 to AParent.ChildrenCount - 1 do
    begin
      LChild := AParent.Children.Items[I];
      if LChild = nil then Continue;

      LItem := TJSONObject.Create;
      LItem.AddPair('class', LChild.ClassName);
      LItem.AddPair('name', LChild.StyleName);
      LItem.AddPair('visible', TJSONBool.Create(
        (LChild is TControl) and TControl(LChild).Visible));

      if LChild is TControl then
      begin
        LControl := TControl(LChild);
        LRect := LControl.AbsoluteRect;
        LItem.AddPair('x', TJSONNumber.Create(LRect.Left));
        LItem.AddPair('y', TJSONNumber.Create(LRect.Top));
        LItem.AddPair('w', TJSONNumber.Create(LRect.Width));
        LItem.AddPair('h', TJSONNumber.Create(LRect.Height));

        LItem.AddPair('text', SafeGetText(LChild));
        LItem.AddPair('enabled', TJSONBool.Create(SafeGetEnabled(LChild)));
        LItem.AddPair('focused', TJSONBool.Create(SafeGetIsFocused(LChild)));
      end
      else
      begin
        // Non-control children: Layouts, Effects, etc.
        LItem.AddPair('x', TJSONNumber.Create(0));
        LItem.AddPair('y', TJSONNumber.Create(0));
        LItem.AddPair('w', TJSONNumber.Create(0));
        LItem.AddPair('h', TJSONNumber.Create(0));
        LItem.AddPair('text', '');
        LItem.AddPair('enabled', TJSONBool.Create(False));
        LItem.AddPair('focused', TJSONBool.Create(False));
      end;

      // Recurse into children
      if LChild.ChildrenCount > 0 then
      begin
        var LChildren := TJSONArray.Create;
        Walk(LChild, LChildren);
        if LChildren.Count > 0 then
          LItem.AddPair('children', LChildren)
        else
          LChildren.Free;
      end;

      AArray.AddElement(LItem);
    end;
  end;

begin
  if Application = nil then
    Exit('{"error":"Application not initialized"}');

  var LRoot := TJSONArray.Create;
  try
    for var I := 0 to Screen.FormCount - 1 do
    begin
      var LForm := Screen.Forms[I];
      var LItem := TJSONObject.Create;
      LItem.AddPair('class', LForm.ClassName);
      LItem.AddPair('name', LForm.StyleName);
      LItem.AddPair('visible', TJSONBool.Create(LForm.Visible));
      LItem.AddPair('caption', LForm.Caption);
      LItem.AddPair('x', TJSONNumber.Create(LForm.Left));
      LItem.AddPair('y', TJSONNumber.Create(LForm.Top));
      LItem.AddPair('w', TJSONNumber.Create(LForm.Width));
      LItem.AddPair('h', TJSONNumber.Create(LForm.Height));

      var LChildren := TJSONArray.Create;
      Walk(LForm, LChildren);
      LItem.AddPair('children', LChildren);
      LRoot.AddElement(LItem);
    end;

    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

{ ---- Control tap simulation ---- }

class function TFmxProbe.TapControl(const AName: string): TFmxProbeResult;

  function FindControlRecursive(const AParent: TFMXObject): TControl;
  begin
    Result := nil;
    for var I := 0 to AParent.ChildrenCount - 1 do
    begin
      var LChild := AParent.Children.Items[I];
      if SameText(LChild.StyleName, AName) and (LChild is TControl) then
        Exit(TControl(LChild));
      if LChild.ChildrenCount > 0 then
      begin
        Result := FindControlRecursive(LChild);
        if Result <> nil then Exit;
      end;
    end;
  end;

var
  LControl: TControl;
  LPoint: TPointF;
begin
  if Screen = nil then
    Exit(Default(TFmxProbeResult)); // Status='', Data=''

  LControl := nil;
  for var I := 0 to Screen.FormCount - 1 do
  begin
    LControl := FindControlRecursive(Screen.Forms[I]);
    if LControl <> nil then Break;
  end;

  if LControl = nil then
  begin
    Result.Status := 'not_found';
    Result.Data := 'control not found: ' + AName;
    Exit;
  end;

  // Simulate tap at control center
  LPoint := PointF(LControl.AbsoluteRect.Left + LControl.AbsoluteRect.Width / 2,
                   LControl.AbsoluteRect.Top + LControl.AbsoluteRect.Height / 2);

  TThread.Queue(nil,
    procedure
    begin
      TProbeControlAccess(LControl).Click;
    end);

  Result.Status := 'ok';
  Result.Data := Format(
    '{"tapped":"%s","class":"%s","x":%.0f,"y":%.0f}',
    [AName, LControl.ClassName, LPoint.X, LPoint.Y]);
end;

{ ---- Control state query ---- }

class function TFmxProbe.QueryState(const AName: string): TFmxProbeResult;

  function FindControlRecursive(const AParent: TFMXObject): TFMXObject;
  begin
    Result := nil;
    for var I := 0 to AParent.ChildrenCount - 1 do
    begin
      var LChild := AParent.Children.Items[I];
      if SameText(LChild.StyleName, AName) then
        Exit(LChild);
      if LChild.ChildrenCount > 0 then
      begin
        Result := FindControlRecursive(LChild);
        if Result <> nil then Exit;
      end;
    end;
  end;

var
  LFound: TFMXObject;
  LJson: TJSONObject;
begin
  if Screen = nil then
    Exit(Default(TFmxProbeResult));

  LFound := nil;
  for var I := 0 to Screen.FormCount - 1 do
  begin
    LFound := FindControlRecursive(Screen.Forms[I]);
    if LFound <> nil then Break;
  end;

  if LFound = nil then
  begin
    Result.Status := 'not_found';
    Result.Data := 'control not found: ' + AName;
    Exit;
  end;

  LJson := TJSONObject.Create;
  try
    LJson.AddPair('name', LFound.StyleName);
    LJson.AddPair('class', LFound.ClassName);
    LJson.AddPair('visible', TJSONBool.Create(
      (LFound is TControl) and TControl(LFound).Visible));

    if LFound is TControl then
    begin
      var LCtrl := TControl(LFound);
      var LRect := LCtrl.AbsoluteRect;
      LJson.AddPair('x', TJSONNumber.Create(LRect.Left));
      LJson.AddPair('y', TJSONNumber.Create(LRect.Top));
      LJson.AddPair('w', TJSONNumber.Create(LRect.Width));
      LJson.AddPair('h', TJSONNumber.Create(LRect.Height));
      LJson.AddPair('text', SafeGetText(LCtrl));
      LJson.AddPair('enabled', TJSONBool.Create(SafeGetEnabled(LCtrl)));
      LJson.AddPair('focused', TJSONBool.Create(SafeGetIsFocused(LCtrl)));
    end
    else
    begin
      LJson.AddPair('x', TJSONNumber.Create(0));
      LJson.AddPair('y', TJSONNumber.Create(0));
      LJson.AddPair('w', TJSONNumber.Create(0));
      LJson.AddPair('h', TJSONNumber.Create(0));
      LJson.AddPair('text', '');
      LJson.AddPair('enabled', TJSONBool.Create(False));
      LJson.AddPair('focused', TJSONBool.Create(False));
    end;

    Result.Status := 'ok';
    Result.Data := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

end.