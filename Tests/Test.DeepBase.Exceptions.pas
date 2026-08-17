{ ============================================================================
  Test.DeepBase.Exceptions - Unit tests for exception hierarchy additions
  ============================================================================ }

unit Test.DeepBase.Exceptions;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  DeepBase.Exceptions;

type
  [TestFixture]
  TTestENotImplemented = class
  public
    [Test] procedure Test_ENotImplemented_InheritsFromEInvalidOperationException;
    [Test] procedure Test_ENotImplemented_InheritsFromEDeepBaseException;
    [Test] procedure Test_ENotImplemented_CarriesErrorCodeAndContext;
  end;

implementation

uses
  System.DateUtils;

{ TTestENotImplemented }

procedure TTestENotImplemented.Test_ENotImplemented_InheritsFromEInvalidOperationException;
var
  LE: Exception;
begin
  LE := ENotImplementedException.Create('test');
  try
    Assert.IsTrue(LE is EInvalidOperationException,
      'ENotImplementedException must inherit from EInvalidOperationException');
  finally
    LE.Free;
  end;
end;

procedure TTestENotImplemented.Test_ENotImplemented_InheritsFromEDeepBaseException;
var
  LE: Exception;
begin
  LE := ENotImplementedException.Create('test');
  try
    Assert.IsTrue(LE is EDeepBaseException,
      'ENotImplementedException must inherit from EDeepBaseException');
  finally
    LE.Free;
  end;
end;

procedure TTestENotImplemented.Test_ENotImplemented_CarriesErrorCodeAndContext;
var
  LE: ENotImplementedException;
  LBefore, LAfter: TDateTime;
begin
  LBefore := Now;
  LE := ENotImplementedException.Create('not yet implemented', 42, 'TestContext');
  LAfter := Now;

  Assert.AreEqual(42, LE.ErrorCode,
    'ErrorCode should be set from constructor parameter');
  Assert.AreEqual('TestContext', LE.Context,
    'Context should be set from constructor parameter');
  Assert.IsTrue(
    (LE.Timestamp >= LBefore) and (LE.Timestamp <= LAfter),
    'Timestamp should be set to approximately Now');
  Assert.AreEqual('not yet implemented', LE.Message,
    'Message should be preserved');
  LE.Free;
end;

end.
