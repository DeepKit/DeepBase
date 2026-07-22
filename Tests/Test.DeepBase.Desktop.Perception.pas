unit Test.DeepBase.Desktop.Perception;

interface

uses
  System.SysUtils,
  System.Types,
  System.Classes,
  Winapi.Windows,
  DUnitX.TestFramework,
  DeepBase.Desktop.Perception.Types,
  DeepBase.Desktop.Perception.Engine;

type
  [TestFixture]
  TDesktopPerceptionTests = class
  public
    [Test]
    procedure Test_PerceivedElement_IsValid;

    [Test]
    procedure Test_PerceivedElement_Center;

    [Test]
    procedure Test_DesktopScreenshot_IsValid;

    [Test]
    procedure Test_WindowLocator_IsEmpty;

    [Test]
    procedure Test_PerceptionCache_PutAndGet;

    [Test]
    procedure Test_PerceptionCache_Clear;

    [Test]
    procedure Test_PerceptionCache_GetNotFound;

    [Test]
    procedure Test_PerceptionCache_Overwrite;

    [Test]
    procedure Test_Engine_CaptureScreen_ReturnsBase64Png;

    [Test]
    procedure Test_Engine_NoProvider_DegradesToScreenshotOnly;

    [Test]
    procedure Test_Engine_EnabledToggle;

    [Test]
    procedure Test_InterfaceGUID_Stable;
  end;

implementation

{ TDesktopPerceptionTests }

procedure TDesktopPerceptionTests.Test_PerceivedElement_IsValid;
var
  LEl: TPerceivedElement;
begin
  LEl := Default(TPerceivedElement);
  LEl.BoundingBox := Rect(10, 20, 110, 60);
  LEl.Confidence := 0.8;
  Assert.IsTrue(LEl.IsValid, 'valid element should be valid');

  LEl.BoundingBox := Rect(0, 0, 0, 0);
  Assert.IsFalse(LEl.IsValid, 'zero-size box invalid');

  LEl.BoundingBox := Rect(10, 20, 110, 60);
  LEl.Confidence := 1.5;
  Assert.IsFalse(LEl.IsValid, 'confidence>1 invalid');
end;

procedure TDesktopPerceptionTests.Test_PerceivedElement_Center;
var
  LEl: TPerceivedElement;
begin
  LEl := Default(TPerceivedElement);
  LEl.BoundingBox := Rect(0, 0, 100, 50);
  Assert.AreEqual(50, LEl.Center.X);
  Assert.AreEqual(25, LEl.Center.Y);
end;

procedure TDesktopPerceptionTests.Test_DesktopScreenshot_IsValid;
var
  LShot: TDesktopScreenshot;
begin
  LShot := Default(TDesktopScreenshot);
  Assert.IsFalse(LShot.IsValid, 'empty shot invalid');
  LShot.ImageBase64 := 'iVBOR';
  LShot.MimeType := 'image/png';
  LShot.WidthPx := 800;
  LShot.HeightPx := 600;
  Assert.IsTrue(LShot.IsValid, 'filled shot valid');
end;

procedure TDesktopPerceptionTests.Test_WindowLocator_IsEmpty;
var
  LLoc: TWindowLocator;
begin
  LLoc := Default(TWindowLocator);
  Assert.IsTrue(LLoc.IsEmpty, 'default locator empty');
  LLoc.TitleContains := 'Notepad';
  Assert.IsFalse(LLoc.IsEmpty, 'titled locator not empty');
end;

procedure TDesktopPerceptionTests.Test_PerceptionCache_PutAndGet;
var
  LCache: TPerceptionCache;
  LEl, LOut: TPerceivedElement;
begin
  LCache := TPerceptionCache.Create;
  try
    LEl := Default(TPerceivedElement);
    LEl.Label_ := 'Send';
    LEl.BoundingBox := Rect(1, 2, 3, 4);
    LEl.Confidence := 0.9;
    LCache.Put('Send', LEl);
    Assert.IsTrue(LCache.Get('Send', LOut), 'get should find');
    Assert.AreEqual(1, LOut.BoundingBox.Left);
    Assert.AreEqual(0.9, LOut.Confidence);
  finally
    LCache.Free;
  end;
end;

procedure TDesktopPerceptionTests.Test_PerceptionCache_Clear;
var
  LCache: TPerceptionCache;
  LEl, LOut: TPerceivedElement;
begin
  LCache := TPerceptionCache.Create;
  try
    LEl := Default(TPerceivedElement);
    LEl.BoundingBox := Rect(1, 2, 3, 4);
    LCache.Put('X', LEl);
    LCache.Clear;
    Assert.IsFalse(LCache.Get('X', LOut), 'cleared cache returns false');
  finally
    LCache.Free;
  end;
end;

procedure TDesktopPerceptionTests.Test_PerceptionCache_GetNotFound;
var
  LCache: TPerceptionCache;
  LOut: TPerceivedElement;
begin
  LCache := TPerceptionCache.Create;
  try
    Assert.IsFalse(LCache.Get('Nope', LOut));
  finally
    LCache.Free;
  end;
end;

procedure TDesktopPerceptionTests.Test_PerceptionCache_Overwrite;
var
  LCache: TPerceptionCache;
  LEl, LOut: TPerceivedElement;
begin
  LCache := TPerceptionCache.Create;
  try
    LEl := Default(TPerceivedElement);
    LEl.BoundingBox := Rect(1, 1, 2, 2);
    LEl.Confidence := 0.1;
    LCache.Put('K', LEl);
    LEl.BoundingBox := Rect(5, 5, 6, 6);
    LEl.Confidence := 0.9;
    LCache.Put('K', LEl);
    Assert.IsTrue(LCache.Get('K', LOut));
    Assert.AreEqual(5, LOut.BoundingBox.Left);
    Assert.AreEqual(0.9, LOut.Confidence);
  finally
    LCache.Free;
  end;
end;

procedure TDesktopPerceptionTests.Test_Engine_CaptureScreen_ReturnsBase64Png;
var
  LEngine: TDesktopPerceptionEngine;
  LShot: TDesktopScreenshot;
begin
  LEngine := TDesktopPerceptionEngine.Create(nil);
  try
    LShot := LEngine.CaptureScreen;
    // Capture should succeed on any real desktop session. If running headless
    // (CI without a desktop), this may be skipped via DUnitX Ignore.
    if (GetSystemMetrics(SM_CXSCREEN) = 0) then
      Exit;
    Assert.IsTrue(LShot.IsValid, 'captured shot should be valid');
    Assert.AreEqual('image/png', LShot.MimeType);
    Assert.IsTrue(LShot.WidthPx > 0, 'width positive');
    Assert.IsTrue(Length(LShot.ImageBase64) > 0, 'base64 non-empty');
    // PNG signature base64-decoded starts with iVBORw0KGgo.
    Assert.IsTrue(Pos('iVBOR', LShot.ImageBase64) = 1, 'looks like PNG base64');
  finally
    LEngine.Free;
  end;
end;

procedure TDesktopPerceptionTests.Test_Engine_NoProvider_DegradesToScreenshotOnly;
var
  LEngine: TDesktopPerceptionEngine;
  LElements: TPerceivedElementArray;
  LShot: TDesktopScreenshot;
begin
  // No provider configured: capture works, recognition returns False.
  LEngine := TDesktopPerceptionEngine.Create(nil);
  try
    Assert.IsFalse(LEngine.Recognize(Default(TDesktopScreenshot), LElements),
      'Recognize must be False without provider');
    Assert.AreEqual(NativeInt(0), NativeInt(Length(LElements)), 'no elements when no provider');
    if GetSystemMetrics(SM_CXSCREEN) > 0 then
    begin
      LShot := LEngine.CaptureScreen;
      Assert.IsTrue(LShot.IsValid, 'capture still works without provider');
    end;
  finally
    LEngine.Free;
  end;
end;

procedure TDesktopPerceptionTests.Test_Engine_EnabledToggle;
var
  LEngine: TDesktopPerceptionEngine;
begin
  LEngine := TDesktopPerceptionEngine.Create(nil);
  try
    Assert.IsTrue(LEngine.Enabled, 'default enabled');
    LEngine.Enabled := False;
    Assert.IsFalse(LEngine.Enabled);
    Assert.IsFalse(LEngine.CaptureScreen.IsValid,
      'disabled engine returns empty shot');
    LEngine.Enabled := True;
    Assert.IsTrue(LEngine.Enabled);
  finally
    LEngine.Free;
  end;
end;

procedure TDesktopPerceptionTests.Test_InterfaceGUID_Stable;
var
  LGUID: TGUID;
begin
  // The neutral desktop vision provider interface GUID must be stable across
  // rebuilds so providers and engines stay binary-compatible.
  LGUID := StringToGUID('{B7C1D8E4-9F2A-4C6D-8E1B-3A7F5D2C9E04}');
  Assert.IsTrue(IsEqualGUID(LGUID, IDesktopVisionProvider),
    'IDesktopVisionProvider GUID matches declared value');
end;

initialization
  TDUnitX.RegisterTestFixture(TDesktopPerceptionTests);

end.
