unit Test.DeepBase.LicenseSecret;

{*******************************************************************************
  A2-01 regression: the legacy license signing key has no built-in fallback.
  Missing environment variable must reject construction (fail-closed);
  an explicitly injected key must construct normally.
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  Winapi.Windows,
  System.SysUtils,
  DeepBase.Exceptions,
  DeepBase.License,
  DeepBase.Storage.Interfaces;

type
  [TestFixture]
  TTestLicenseSecretFailClosed = class
  private
    function SaveEnv: string;
    procedure RestoreEnv(const APrior: string);
  public
    [Test]
    procedure Test_MissingEnv_RejectsConstruction;

    [Test]
    procedure Test_InjectedEnv_ConstructsNormally;
  end;

implementation

const
  SECRET_ENV = 'DEEPBASE_LEGACY_LICENSE_SIGNING_KEY';
  INJECTED_SECRET = 'unit-test-injected-signing-key';

function TTestLicenseSecretFailClosed.SaveEnv: string;
begin
  Result := GetEnvironmentVariable(SECRET_ENV);
end;

procedure TTestLicenseSecretFailClosed.RestoreEnv(const APrior: string);
begin
  if APrior = '' then
    Winapi.Windows.SetEnvironmentVariable(PChar(SECRET_ENV), nil)
  else
    Winapi.Windows.SetEnvironmentVariable(PChar(SECRET_ENV), PChar(APrior));
end;

procedure TTestLicenseSecretFailClosed.Test_MissingEnv_RejectsConstruction;
var
  LPrior: string;
  LStorage: ILicenseStorage;
  LLicense: TDeepBaseLicense;
  LRaised: Boolean;
begin
  LPrior := SaveEnv;
  Winapi.Windows.SetEnvironmentVariable(PChar(SECRET_ENV), nil);
  try
    LStorage := nil;
    LRaised := False;
    try
      LLicense := TDeepBaseLicense.Create(LStorage);
      LLicense.Free;
    except
      on E: EMissingConfigurationException do
        LRaised := True;
      else
        raise;
    end;
    Assert.IsTrue(LRaised,
      'Missing signing key env must raise EMissingConfigurationException (fail-closed)');
  finally
    RestoreEnv(LPrior);
  end;
end;

procedure TTestLicenseSecretFailClosed.Test_InjectedEnv_ConstructsNormally;
var
  LPrior: string;
  LStorage: ILicenseStorage;
  LLicense: TDeepBaseLicense;
begin
  LPrior := SaveEnv;
  Winapi.Windows.SetEnvironmentVariable(PChar(SECRET_ENV), PChar(INJECTED_SECRET));
  try
    LStorage := nil;
    LLicense := TDeepBaseLicense.Create(LStorage);
    try
      Assert.IsNotNull(LLicense,
        'Explicitly injected signing key must allow construction');
    finally
      LLicense.Free;
    end;
  finally
    RestoreEnv(LPrior);
  end;
end;

end.
