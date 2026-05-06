unit Test.Tools.UpdaterHelper;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
  System.Zip,
  UpdaterHelper.Core;

type
  [TestFixture]
  TTestUpdaterHelper = class
  private
    FTempRoot: string;
    FAppDir: string;
    FPackagePath: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_ParseArgs_ValidInstallArgs;

    [Test]
    procedure Test_ParseArgs_MissingPackage_Fails;
  end;

implementation

procedure TTestUpdaterHelper.Setup;
begin
  FTempRoot := TPath.Combine(TPath.GetTempPath, 'UniBaseUpdaterHelperTests_' + TGUID.NewGuid.ToString);
  FAppDir := TPath.Combine(FTempRoot, 'app');
  ForceDirectories(FTempRoot);
  ForceDirectories(FAppDir);
  FPackagePath := TPath.Combine(FTempRoot, 'update.zip');
  TFile.WriteAllText(TPath.Combine(FAppDir, 'app.exe'), 'dummy', TEncoding.UTF8);
  // Build an empty zip for parser validation (only existence is checked).
  with TZipFile.Create do
  try
    Open(FPackagePath, zmWrite);
    Close;
  finally
    Free;
  end;
end;

procedure TTestUpdaterHelper.TearDown;
begin
  if TDirectory.Exists(FTempRoot) then
    TDirectory.Delete(FTempRoot, True);
end;

procedure TTestUpdaterHelper.Test_ParseArgs_ValidInstallArgs;
var
  Options: THelperOptions;
  ErrorMessage: string;
  Args: TArray<string>;
begin
  SetLength(Args, 12);
  Args[0] := '--mode';
  Args[1] := 'install';
  Args[2] := '--package';
  Args[3] := FPackagePath;
  Args[4] := '--appdir';
  Args[5] := FAppDir;
  Args[6] := '--target';
  Args[7] := TPath.Combine(FAppDir, 'app.exe');
  Args[8] := '--restart';
  Args[9] := '0';
  Args[10] := '--wait-ms';
  Args[11] := '5000';

  Assert.IsTrue(TUpdaterHelper.ParseArgs(Args, Options, ErrorMessage), ErrorMessage);
  Assert.AreEqual('install', Options.Mode.ToLower);
  Assert.AreEqual(False, Options.Restart);
  Assert.AreEqual(Cardinal(5000), Options.WaitMs);
end;

procedure TTestUpdaterHelper.Test_ParseArgs_MissingPackage_Fails;
var
  Options: THelperOptions;
  ErrorMessage: string;
  Args: TArray<string>;
begin
  SetLength(Args, 6);
  Args[0] := '--mode';
  Args[1] := 'install';
  Args[2] := '--appdir';
  Args[3] := FAppDir;
  Args[4] := '--target';
  Args[5] := TPath.Combine(FAppDir, 'app.exe');

  Assert.IsFalse(TUpdaterHelper.ParseArgs(Args, Options, ErrorMessage));
  Assert.IsTrue(ErrorMessage.Contains('package'));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUpdaterHelper);

end.
