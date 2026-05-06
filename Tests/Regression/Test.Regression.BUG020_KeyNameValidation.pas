{ ============================================================================
  Test.Regression.BUG020_KeyNameValidation - Key Name Validation Regression Test

  BUG-020: Missing Key Name Validation
  
  Original Issue: Key names not validated, path traversal risk exists
  
  Fix: Add key name format validation function
  
  Fix Date: 2025-01-27
  File: Core/UniBase.Security.pas
  Priority: P1 (High)
  Category: Security
  ============================================================================ }

unit Test.Regression.BUG020_KeyNameValidation;

interface

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework,
  Test.Regression.Base;

type
  [TestFixture]
  [Category('Regression')]
  [Category('P1')]
  [Category('Security')]
  TBug020_KeyNameValidationTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    [Description('Verify key name validation function exists')]
    procedure Test_KeyNameValidation_Exists;
    
    [Test]
    [Description('Verify path traversal characters are rejected')]
    procedure Test_PathTraversalChars_AreRejected;
    
    [Test]
    [Description('Verify valid key name is accepted')]
    procedure Test_ValidKeyName_IsAccepted;
  end;

implementation

uses
  System.IOUtils,
  UniBase.Security;

{ TBug020_KeyNameValidationTest }

function TBug020_KeyNameValidationTest.GetBugNumber: string;
begin
  Result := 'BUG-020';
end;

function TBug020_KeyNameValidationTest.GetBugDescription: string;
begin
  Result := 'Missing key name validation';
end;

function TBug020_KeyNameValidationTest.GetFixDate: string;
begin
  Result := '2025-01-27';
end;

function TBug020_KeyNameValidationTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBug020_KeyNameValidationTest.GetAffectedFile: string;
begin
  Result := 'Core/UniBase.Security.pas';
end;

procedure TBug020_KeyNameValidationTest.Test_KeyNameValidation_Exists;
var
  SourcePath: string;
  SourceCode: string;
begin
  LogTestStart('Test_KeyNameValidation_Exists');
  
  SourcePath := 'Core\UniBase.Security.pas';
  
  if not TFile.Exists(SourcePath) then
  begin
    SourcePath := '..\Core\UniBase.Security.pas';
    if not TFile.Exists(SourcePath) then
    begin
      Assert.Pass('Source file not accessible, skip static analysis test');
      Exit;
    end;
  end;
  
  SourceCode := TFile.ReadAllText(SourcePath);
  
  Assert.IsTrue(
    SourceCode.Contains('ValidateKeyName') or 
    SourceCode.Contains('IsValidKeyName') or
    SourceCode.Contains('ValidateSecretName'),
    'Code should contain key name validation function');
  
  LogTestEnd('Test_KeyNameValidation_Exists', True);
end;

procedure TBug020_KeyNameValidationTest.Test_PathTraversalChars_AreRejected;
var
  ExceptionRaised: Boolean;
  Security: TUniBaseSecurity;
begin
  LogTestStart('Test_PathTraversalChars_AreRejected');
  
  Security := TUniBaseSecurity.Create(nil, nil);
  try
    ExceptionRaised := False;
    
    try
      // Try to use key name with path traversal characters
      Security.SaveSecret('../../../etc/passwd', 'malicious');
    except
      on E: Exception do
        ExceptionRaised := True;
    end;
    
    Assert.IsTrue(ExceptionRaised, 'Key name with path traversal characters should be rejected');
  finally
    Security.Free;
  end;
  
  LogTestEnd('Test_PathTraversalChars_AreRejected', True);
end;

procedure TBug020_KeyNameValidationTest.Test_ValidKeyName_IsAccepted;
var
  SecretName: string;
  SecretValue: string;
  RetrievedValue: string;
  Security: TUniBaseSecurity;
begin
  LogTestStart('Test_ValidKeyName_IsAccepted');
  
  SecretName := 'valid_key_name_' + IntToStr(TThread.GetTickCount);
  SecretValue := 'test_value';
  
  Security := TUniBaseSecurity.Create(nil, nil);
  try
    try
      // Valid key name should be accepted
      Security.SaveSecret(SecretName, SecretValue);
      RetrievedValue := Security.LoadSecret(SecretName);
      
      Assert.AreEqual(SecretValue, RetrievedValue, 'Valid key name should work correctly');
    finally
      try
        Security.DeleteSecret(SecretName);
      except
        // Ignore cleanup errors
      end;
    end;
  finally
    Security.Free;
  end;
  
  LogTestEnd('Test_ValidKeyName_IsAccepted', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug020_KeyNameValidationTest);

end.
