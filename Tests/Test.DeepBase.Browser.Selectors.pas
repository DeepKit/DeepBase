unit Test.DeepBase.Browser.Selectors;

interface

uses
  DUnitX.TestFramework,
  DeepBase.Browser.Types,
  DeepBase.Browser.Selectors;

type
  [TestFixture]
  TBrowserSelectorManagerTests = class
  public
    [Test]
    procedure Test_RegisterSelector;

    [Test]
    procedure Test_ResolveSelector_WithNoSession;

    [Test]
    procedure Test_RegisterMultipleAndGetNames;

    [Test]
    procedure Test_InvalidateSelector;

    [Test]
    procedure Test_InvalidateCache;

    [Test]
    procedure Test_LoadFromConfig;

    [Test]
    procedure Test_ToConfig_RoundTrip;

    [Test]
    procedure Test_GetSelectorInfo_NotFound;

    [Test]
    procedure Test_Count;
  end;

implementation

{ TBrowserSelectorManagerTests }

procedure TBrowserSelectorManagerTests.Test_RegisterSelector;
var
  LMgr: TBrowserSelectorManager;
begin
  LMgr := TBrowserSelectorManager.Create(nil);
  try
    LMgr.RegisterSelector('input', 'textarea.prompt');
    Assert.AreEqual('textarea.prompt',
      LMgr.ResolveSelector('input'));
  finally
    LMgr.Free;
  end;
end;

procedure TBrowserSelectorManagerTests.Test_ResolveSelector_WithNoSession;
var
  LMgr: TBrowserSelectorManager;
begin
  // No session means validation always passes
  LMgr := TBrowserSelectorManager.Create(nil);
  try
    LMgr.RegisterSelector('send', 'button[type="submit"]');
    Assert.AreEqual('button[type="submit"]',
      LMgr.ResolveSelector('send'));
  finally
    LMgr.Free;
  end;
end;

procedure TBrowserSelectorManagerTests.Test_RegisterMultipleAndGetNames;
var
  LMgr: TBrowserSelectorManager;
  LNames: TArray<string>;
begin
  LMgr := TBrowserSelectorManager.Create(nil);
  try
    LMgr.RegisterSelector('input', 'textarea');
    LMgr.RegisterSelector('send', 'button.send');
    LMgr.RegisterSelector('assistant', '.msg');

    LNames := LMgr.GetRegisteredNames;
    Assert.AreEqual<Integer>(3, Length(LNames));
  finally
    LMgr.Free;
  end;
end;

procedure TBrowserSelectorManagerTests.Test_InvalidateSelector;
var
  LMgr: TBrowserSelectorManager;
  LInfo: TBrowserSelectorInfo;
begin
  LMgr := TBrowserSelectorManager.Create(nil);
  try
    LMgr.RegisterSelector('input', 'textarea');
    LMgr.InvalidateSelector('input');

    LInfo := LMgr.GetSelectorInfo('input');
    Assert.IsFalse(LInfo.IsValid);
  finally
    LMgr.Free;
  end;
end;

procedure TBrowserSelectorManagerTests.Test_InvalidateCache;
var
  LMgr: TBrowserSelectorManager;
begin
  LMgr := TBrowserSelectorManager.Create(nil);
  try
    LMgr.RegisterSelector('input', 'textarea');
    LMgr.RegisterSelector('send', 'button');
    LMgr.InvalidateCache;
    Assert.AreEqual(0, LMgr.Count);
  finally
    LMgr.Free;
  end;
end;

procedure TBrowserSelectorManagerTests.Test_LoadFromConfig;
var
  LMgr: TBrowserSelectorManager;
  LJson: string;
begin
  LMgr := TBrowserSelectorManager.Create(nil);
  try
    LJson := '[' +
      '{"name":"input","selector":"textarea","fallback":"[name=prompt]"},' +
      '{"name":"send","selector":"button.send"}' +
      ']';
    LMgr.LoadFromConfig(LJson);
    Assert.AreEqual(2, LMgr.Count);
    Assert.AreEqual('textarea', LMgr.ResolveSelector('input'));
    Assert.AreEqual('button.send', LMgr.ResolveSelector('send'));
  finally
    LMgr.Free;
  end;
end;

procedure TBrowserSelectorManagerTests.Test_ToConfig_RoundTrip;
var
  LMgr1, LMgr2: TBrowserSelectorManager;
  LJson: string;
begin
  LMgr1 := TBrowserSelectorManager.Create(nil);
  try
    LMgr1.RegisterSelector('input', 'textarea',
      '[name="prompt"]');
    LMgr1.RegisterSelector('send', 'button.send');
    LJson := LMgr1.ToConfig;

    LMgr2 := TBrowserSelectorManager.Create(nil);
    try
      LMgr2.LoadFromConfig(LJson);
      Assert.AreEqual(2, LMgr2.Count);
      Assert.AreEqual('textarea',
        LMgr2.ResolveSelector('input'));
      Assert.AreEqual('button.send',
        LMgr2.ResolveSelector('send'));

      var LInfo := LMgr2.GetSelectorInfo('input');
      Assert.AreEqual('[name="prompt"]',
        LInfo.FallbackSelector);
    finally
      LMgr2.Free;
    end;
  finally
    LMgr1.Free;
  end;
end;

procedure TBrowserSelectorManagerTests.Test_GetSelectorInfo_NotFound;
var
  LMgr: TBrowserSelectorManager;
  LInfo: TBrowserSelectorInfo;
begin
  LMgr := TBrowserSelectorManager.Create(nil);
  try
    LInfo := LMgr.GetSelectorInfo('nonexistent');
    Assert.AreEqual('nonexistent', LInfo.Name);
    Assert.AreEqual('', LInfo.Selector);
  finally
    LMgr.Free;
  end;
end;

procedure TBrowserSelectorManagerTests.Test_Count;
var
  LMgr: TBrowserSelectorManager;
begin
  LMgr := TBrowserSelectorManager.Create(nil);
  try
    Assert.AreEqual(0, LMgr.Count);
    LMgr.RegisterSelector('input', 'textarea');
    Assert.AreEqual(1, LMgr.Count);
    LMgr.RegisterSelector('send', 'button');
    Assert.AreEqual(2, LMgr.Count);
    // Upsert on same name
    LMgr.RegisterSelector('input', 'textarea.new');
    Assert.AreEqual(2, LMgr.Count);
  finally
    LMgr.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBrowserSelectorManagerTests);

end.
