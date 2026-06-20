unit Test.DeepBase.Browser.Registry;

interface

uses
  DUnitX.TestFramework,
  DeepBase.Browser.Types,
  DeepBase.Browser.Registry;

type
  [TestFixture]
  TBrowserRegistryTests = class
  public
    [Test]
    procedure Test_RegisterAndFindBest;

    [Test]
    procedure Test_RegisterMultiple_PrioritySorting;

    [Test]
    procedure Test_Disable_RemovesFromDiscover;

    [Test]
    procedure Test_Unregister_RemovesBackend;

    [Test]
    procedure Test_FindBest_NoneAvailable_ReturnsEmpty;

    [Test]
    procedure Test_IsRegistered;

    [Test]
    procedure Test_Register_UpsertsExisting;
  end;

implementation

{ TBrowserRegistryTests }

procedure TBrowserRegistryTests.Test_RegisterAndFindBest;
var
  LInfo: TBrowserBackendInfo;
  LBest: TBrowserBackendInfo;
begin
  LInfo := Default(TBrowserBackendInfo);
  LInfo.Kind := bbkCustom;
  LInfo.Name := 'TestBackend_RegFind';
  LInfo.Enabled := True;
  LInfo.Priority := 10;
  LInfo.IsAvailableFunc :=
    function: Boolean
    begin
      Result := True;
    end;

  TBrowserRegistry.Register(LInfo);
  try
    LBest := TBrowserRegistry.FindBest;
    Assert.AreEqual('TestBackend_RegFind', LBest.Name);
  finally
    TBrowserRegistry.Unregister('TestBackend_RegFind', bbkCustom);
  end;
end;

procedure TBrowserRegistryTests.Test_RegisterMultiple_PrioritySorting;
var
  LInfo1, LInfo2: TBrowserBackendInfo;
  LAll: TArray<TBrowserBackendInfo>;
begin
  LInfo1 := Default(TBrowserBackendInfo);
  LInfo1.Kind := bbkCustom;
  LInfo1.Name := 'TestBackend_Priority1';
  LInfo1.Enabled := True;
  LInfo1.Priority := 20;
  LInfo1.IsAvailableFunc :=
    function: Boolean begin Result := True; end;

  LInfo2 := Default(TBrowserBackendInfo);
  LInfo2.Kind := bbkCustom;
  LInfo2.Name := 'TestBackend_Priority2';
  LInfo2.Enabled := True;
  LInfo2.Priority := 5;
  LInfo2.IsAvailableFunc :=
    function: Boolean begin Result := True; end;

  TBrowserRegistry.Register(LInfo1);
  TBrowserRegistry.Register(LInfo2);
  try
    LAll := TBrowserRegistry.Discover(True);
    Assert.IsTrue(Length(LAll) >= 2);
    // First should be the one with lower priority value
    Assert.AreEqual('TestBackend_Priority2', LAll[0].Name);
  finally
    TBrowserRegistry.Unregister('TestBackend_Priority1', bbkCustom);
    TBrowserRegistry.Unregister('TestBackend_Priority2', bbkCustom);
  end;
end;

procedure TBrowserRegistryTests.Test_Disable_RemovesFromDiscover;
var
  LInfo: TBrowserBackendInfo;
  LCountBefore, LCountAfter: Integer;
begin
  LInfo := Default(TBrowserBackendInfo);
  LInfo.Kind := bbkCustom;
  LInfo.Name := 'TestBackend_Disable';
  LInfo.Enabled := True;
  LInfo.Priority := 50;
  LInfo.IsAvailableFunc :=
    function: Boolean begin Result := True; end;

  TBrowserRegistry.Register(LInfo);
  LCountBefore := Length(TBrowserRegistry.Discover(True));

  TBrowserRegistry.Disable('TestBackend_Disable', bbkCustom);
  LCountAfter := Length(TBrowserRegistry.Discover(True));

  Assert.IsTrue(LCountAfter < LCountBefore);
  TBrowserRegistry.Unregister('TestBackend_Disable', bbkCustom);
end;

procedure TBrowserRegistryTests.Test_Unregister_RemovesBackend;
var
  LInfo: TBrowserBackendInfo;
begin
  LInfo := Default(TBrowserBackendInfo);
  LInfo.Kind := bbkCustom;
  LInfo.Name := 'TestBackend_Unreg';
  LInfo.Enabled := True;
  LInfo.Priority := 99;

  TBrowserRegistry.Register(LInfo);
  Assert.IsTrue(
    TBrowserRegistry.IsRegistered('TestBackend_Unreg', bbkCustom));

  TBrowserRegistry.Unregister('TestBackend_Unreg', bbkCustom);
  Assert.IsFalse(
    TBrowserRegistry.IsRegistered('TestBackend_Unreg', bbkCustom));
end;

procedure TBrowserRegistryTests.Test_FindBest_NoneAvailable_ReturnsEmpty;
var
  LBest: TBrowserBackendInfo;
begin
  LBest := TBrowserRegistry.FindBest;
  // With no backends registered in this isolated test, result should be default (empty)
  Assert.AreEqual('', LBest.Name);
end;

procedure TBrowserRegistryTests.Test_IsRegistered;
var
  LInfo: TBrowserBackendInfo;
begin
  LInfo := Default(TBrowserBackendInfo);
  LInfo.Kind := bbkCustom;
  LInfo.Name := 'TestBackend_IsReg';
  LInfo.Enabled := True;

  Assert.IsFalse(
    TBrowserRegistry.IsRegistered('TestBackend_IsReg', bbkCustom));

  TBrowserRegistry.Register(LInfo);
  try
    Assert.IsTrue(
      TBrowserRegistry.IsRegistered('TestBackend_IsReg', bbkCustom));
  finally
    TBrowserRegistry.Unregister('TestBackend_IsReg', bbkCustom);
  end;
end;

procedure TBrowserRegistryTests.Test_Register_UpsertsExisting;
var
  LInfo: TBrowserBackendInfo;
begin
  LInfo := Default(TBrowserBackendInfo);
  LInfo.Kind := bbkCustom;
  LInfo.Name := 'TestBackend_Upsert';
  LInfo.Enabled := True;
  LInfo.Priority := 10;

  TBrowserRegistry.Register(LInfo);

  LInfo.Priority := 5;
  TBrowserRegistry.Register(LInfo);
  try
    Assert.AreEqual(1, TBrowserRegistry.Count);
  finally
    TBrowserRegistry.Unregister('TestBackend_Upsert', bbkCustom);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBrowserRegistryTests);

end.
