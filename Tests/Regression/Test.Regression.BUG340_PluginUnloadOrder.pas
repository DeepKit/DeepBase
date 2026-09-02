unit Test.Regression.BUG340_PluginUnloadOrder;

interface

uses
  System.SysUtils,
  System.IOUtils,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.Plugin,
  DeepBase.PluginManager;

type
  [TestFixture]
  [Category('regression')]
  TBUG340_PluginUnloadOrderTest = class(TRegressionTestBase)
  private
    FPluginsDir: string;
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Setup]
    procedure SetUp; override;
    [TearDown]
    procedure TearDown; override;

    [Test]
    procedure Test_UnloadNotLoaded_ReturnsFalseWithoutAV;

    [Test]
    procedure Test_ManagerDestroy_AfterFailedLoad_NoAV;
  end;

implementation

procedure TBUG340_PluginUnloadOrderTest.SetUp;
begin
  inherited;
  FPluginsDir := TPath.Combine(TPath.GetTempPath,
    Format('bug340_plugins_%d', [Random(MaxInt)]));
  ForceDirectories(FPluginsDir);
end;

procedure TBUG340_PluginUnloadOrderTest.TearDown;
begin
  if TDirectory.Exists(FPluginsDir) then
    TDirectory.Delete(FPluginsDir, True);
  inherited;
end;

function TBUG340_PluginUnloadOrderTest.GetBugNumber: string;
begin
  Result := 'BUG-340';
end;

function TBUG340_PluginUnloadOrderTest.GetBugDescription: string;
begin
  Result := 'PluginManager must release interface refs before UnloadBPL';
end;

function TBUG340_PluginUnloadOrderTest.GetFixDate: string;
begin
  Result := '2026-09-02';
end;

function TBUG340_PluginUnloadOrderTest.GetPriority: string;
begin
  Result := 'P0';
end;

function TBUG340_PluginUnloadOrderTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.PluginManager.pas';
end;

procedure TBUG340_PluginUnloadOrderTest.Test_UnloadNotLoaded_ReturnsFalseWithoutAV;
var
  Mgr: TDeepBasePluginManager;
  RandomId: TGUID;
begin
  CreateGUID(RandomId);
  Mgr := TDeepBasePluginManager.Create(FPluginsDir, nil);
  try
    Assert.IsFalse(Mgr.UnloadPlugin(RandomId),
      'Unload of unknown plugin should return False without AV');
  finally
    Mgr.Free;
  end;
end;

procedure TBUG340_PluginUnloadOrderTest.Test_ManagerDestroy_AfterFailedLoad_NoAV;
var
  Mgr: TDeepBasePluginManager;
  BadPath: string;
begin
  BadPath := TPath.Combine(FPluginsDir, 'NotAPlugin.txt');
  TFile.WriteAllText(BadPath, 'not a bpl');

  Mgr := TDeepBasePluginManager.Create(FPluginsDir, nil);
  try
    Assert.IsFalse(Mgr.LoadPlugin(BadPath));
    Assert.AreEqual(0, Mgr.PluginCount);
  finally
    Mgr.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBUG340_PluginUnloadOrderTest);

end.
