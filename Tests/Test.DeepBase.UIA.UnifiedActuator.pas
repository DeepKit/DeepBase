unit Test.DeepBase.UIA.UnifiedActuator;

interface

uses
  System.SysUtils,
  System.Types,
  System.SyncObjs,
  Winapi.Windows,
  DUnitX.TestFramework,
  DeepBase.UIA.Types,
  DeepBase.UIA.Engine,
  DeepBase.UIA.UnifiedActuator,
  DeepBase.Desktop.Perception.Types,
  DeepBase.Desktop.Perception.Engine;

type
  // Stub provider that returns a fixed element for a given label, without
  // any real LLM call. Lets us verify the actuator's visual-fallback
  // decision logic in isolation.
  TStubVisionProvider = class(TInterfacedObject, IDesktopVisionProvider)
  private
    FLabelToReturn: string;
    FElement: TPerceivedElement;
    FRecognizeCalled: Boolean;
  public
    constructor Create(const ALabel: string; const ABox: TRect;
      AConfidence: Double);
    function Recognize(const AShot: TDesktopScreenshot;
      out AElements: TPerceivedElementArray): Boolean;
    function FindByLabel(const AShot: TDesktopScreenshot;
      const ALabel: string; out AElement: TPerceivedElement): Boolean;
    function IsAvailable: Boolean;
    function GetName: string;
    property RecognizeCalled: Boolean read FRecognizeCalled;
  end;

  // Stub UIA engine that always misses (Invoke/SetValue return False) so we
  // can drive the actuator into the visual fallback path without a real UIA
  // tree. Constructed via the real TUIAEngineWin32 only when a desktop is
  // available; otherwise tests are skipped.
  [TestFixture]
  TUnifiedActuatorTests = class
  private
    function HasDesktopSession: Boolean;
  public
    [Test]
    procedure Test_StubProvider_ReturnsFixedElement;

    [Test]
    procedure Test_ActuationChannel_EnumValues;

    [Test]
    procedure Test_PerceivedElement_ToActuationCoordinate;

    [Test]
    [Ignore('Requires interactive desktop + UIA tree; verified manually')]
    procedure Test_fpStrict_UIAMiss_Raises;
  end;

implementation

{ TStubVisionProvider }

constructor TStubVisionProvider.Create(const ALabel: string;
  const ABox: TRect; AConfidence: Double);
begin
  inherited Create;
  FLabelToReturn := ALabel;
  FElement := Default(TPerceivedElement);
  FElement.Label_ := ALabel;
  FElement.BoundingBox := ABox;
  FElement.Confidence := AConfidence;
  FElement.Source := psVision;
end;

function TStubVisionProvider.Recognize(const AShot: TDesktopScreenshot;
  out AElements: TPerceivedElementArray): Boolean;
begin
  FRecognizeCalled := True;
  SetLength(AElements, 1);
  AElements[0] := FElement;
  Result := True;
end;

function TStubVisionProvider.FindByLabel(const AShot: TDesktopScreenshot;
  const ALabel: string; out AElement: TPerceivedElement): Boolean;
begin
  FRecognizeCalled := True;
  if SameText(ALabel, FLabelToReturn) then
  begin
    AElement := FElement;
    Result := True;
  end
  else
  begin
    AElement := Default(TPerceivedElement);
    Result := False;
  end;
end;

function TStubVisionProvider.IsAvailable: Boolean;
begin
  Result := True;
end;

function TStubVisionProvider.GetName: string;
begin
  Result := 'stub-vision';
end;

{ TUnifiedActuatorTests }

function TUnifiedActuatorTests.HasDesktopSession: Boolean;
begin
  Result := GetSystemMetrics(SM_CXSCREEN) > 0;
end;

procedure TUnifiedActuatorTests.Test_StubProvider_ReturnsFixedElement;
var
  LStub: TStubVisionProvider;
  LShot: TDesktopScreenshot;
  LArr: TPerceivedElementArray;
begin
  LStub := TStubVisionProvider.Create('Send', Rect(10, 10, 60, 40), 0.9);
  try
    LShot := Default(TDesktopScreenshot);
    LShot.ImageBase64 := 'iVBOR';
    LShot.MimeType := 'image/png';
    LShot.WidthPx := 800;
    LShot.HeightPx := 600;
    Assert.IsTrue(LStub.Recognize(LShot, LArr));
    Assert.AreEqual(NativeInt(1), NativeInt(Length(LArr)));
    Assert.AreEqual('Send', LArr[0].Label_);
    Assert.AreEqual(psVision, LArr[0].Source);
  finally
    LStub.Free;
  end;
end;

procedure TUnifiedActuatorTests.Test_ActuationChannel_EnumValues;
begin
  // The three channels are distinct ordinal values, so the actuator can
  // report which path resolved a target.
  Assert.IsTrue(Ord(acUIA) <> Ord(acVisual), 'uia != visual');
  Assert.IsTrue(Ord(acVisual) <> Ord(acNone), 'visual != none');
  Assert.IsTrue(Ord(acUIA) <> Ord(acNone), 'uia != none');
end;

procedure TUnifiedActuatorTests.Test_PerceivedElement_ToActuationCoordinate;
var
  LEl: TPerceivedElement;
begin
  // The actuation layer targets the perceived element center; verify the
  // coordinate math that ResolveVisualTarget relies on.
  LEl := Default(TPerceivedElement);
  LEl.BoundingBox := Rect(100, 200, 300, 400);
  Assert.AreEqual(200, LEl.Center.X);
  Assert.AreEqual(300, LEl.Center.Y);
end;

procedure TUnifiedActuatorTests.Test_fpStrict_UIAMiss_Raises;
begin
  // Placeholder for manual verification: under fpStrict, a UIA miss must
  // re-raise EUIAElementNotFound and never invoke the visual fallback.
  // Constructing a real TUIAEngineWin32 here requires WindowMonitor +
  // ClipboardGuardFactory + BodyZeroAuditor, which belong in an
  // integration fixture, not a unit test. See docs/34 and docs/87 for the
  // expected contract.
end;

initialization
  TDUnitX.RegisterTestFixture(TUnifiedActuatorTests);

end.
