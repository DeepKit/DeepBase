unit Test.DeepBase.Browser.Vision;

interface

uses
  System.SysUtils,
  System.Types,
  System.TypInfo,
  DUnitX.TestFramework,
  DeepBase.Browser.Types,
  DeepBase.Browser.Vision;

type
  [TestFixture]
  TBrowserVisionTests = class
  public
    [Test]
    procedure Test_DetectedElement_Record;

    [Test]
    procedure Test_VisionCache_PutAndGet;

    [Test]
    procedure Test_VisionCache_Clear;

    [Test]
    procedure Test_VisionCache_CaseInsensitive;

    [Test]
    procedure Test_VisionCache_GetNotFound;

    [Test]
    procedure Test_IVisionProvider_InterfaceGUID;

    [Test]
    procedure Test_Fallback_NoProvider_Disabled;
  end;

implementation

{ TBrowserVisionTests }

procedure TBrowserVisionTests.Test_DetectedElement_Record;
var
  LElement: TDetectedElement;
begin
  LElement := Default(TDetectedElement);
  LElement.Description := 'Submit button';
  LElement.Bounds := Rect(100, 200, 200, 240);
  LElement.Confidence := 0.95;
  LElement.Selector := 'button[type="submit"]';

  Assert.AreEqual('Submit button', LElement.Description);
  Assert.AreEqual(100, LElement.Bounds.Left);
  Assert.AreEqual(200, LElement.Bounds.Top);
  Assert.AreEqual(200, LElement.Bounds.Right);
  Assert.AreEqual(0.95, LElement.Confidence, 0.001);
end;

procedure TBrowserVisionTests.Test_VisionCache_PutAndGet;
var
  LCache: TVisionCache;
  LElement: TDetectedElement;
  LRetrieved: TDetectedElement;
begin
  LCache := TVisionCache.Create;
  try
    LElement := Default(TDetectedElement);
    LElement.Description := 'Search input';
    LElement.Bounds := Rect(50, 100, 400, 140);
    LElement.Confidence := 0.88;

    LCache.Put('Search input', LElement);
    Assert.IsTrue(LCache.Get('Search input', LRetrieved));
    Assert.AreEqual(50, LRetrieved.Bounds.Left);
    Assert.AreEqual(0.88, LRetrieved.Confidence, 0.001);
  finally
    LCache.Free;
  end;
end;

procedure TBrowserVisionTests.Test_VisionCache_Clear;
var
  LCache: TVisionCache;
  LElement: TDetectedElement;
  LRetrieved: TDetectedElement;
begin
  LCache := TVisionCache.Create;
  try
    LElement := Default(TDetectedElement);
    LElement.Description := 'btn';
    LCache.Put('btn', LElement);
    LCache.Clear;
    Assert.IsFalse(LCache.Get('btn', LRetrieved));
  finally
    LCache.Free;
  end;
end;

procedure TBrowserVisionTests.Test_VisionCache_CaseInsensitive;
var
  LCache: TVisionCache;
  LElement, LRetrieved: TDetectedElement;
begin
  LCache := TVisionCache.Create;
  try
    LElement := Default(TDetectedElement);
    LElement.Description := 'SearchBox';
    LCache.Put('SearchBox', LElement);

    Assert.IsTrue(LCache.Get('searchbox', LRetrieved));
    Assert.IsTrue(LCache.Get('SEARCHBOX', LRetrieved));
  finally
    LCache.Free;
  end;
end;

procedure TBrowserVisionTests.Test_VisionCache_GetNotFound;
var
  LCache: TVisionCache;
  LElement: TDetectedElement;
begin
  LCache := TVisionCache.Create;
  try
    Assert.IsFalse(
      LCache.Get('nonexistent', LElement));
  finally
    LCache.Free;
  end;
end;

procedure TBrowserVisionTests.Test_IVisionProvider_InterfaceGUID;
var
  LGUID: TGUID;
begin
  LGUID := GetTypeData(TypeInfo(IVisionProvider))^.Guid;
  Assert.IsFalse(LGUID = TGUID.Empty,
    'IVisionProvider should have a valid GUID');
end;

procedure TBrowserVisionTests.Test_Fallback_NoProvider_Disabled;
var
  LFallback: TBrowserVisionFallback;
  LBounds: TRect;
begin
  LFallback := TBrowserVisionFallback.Create(nil);
  try
    Assert.IsFalse(LFallback.Enabled);
    Assert.IsFalse(LFallback.TryVisionFind('anything',
      LBounds));
  finally
    LFallback.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBrowserVisionTests);

end.
