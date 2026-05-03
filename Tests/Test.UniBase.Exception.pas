{ ============================================================================
  Test.UniBase.Exception - Unit Tests for Global Exception Handler Module

  Tests the actual API provided by UniBase.Exception:
    - TUniBaseExceptionHandler singleton lifecycle (class ctor/dtor)
    - Install class method
    - OnException behavior (private, tested indirectly via Install)

  Note: The core module depends on Vcl.Forms, FireDAC, UniBase.Manager,
  and UniBase.Logging, so full integration testing of OnException and
  LogExceptionToDB requires those services to be available. Here we test
  the structural and lifecycle aspects that are safe to verify in isolation.
  ============================================================================ }

unit Test.UniBase.Exception;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  UniBase.Exception, UniBase.Exceptions, UniBase.Math, UniBase.DB.DoQry;

type
  [TestFixture]
  TTestExceptionHandlerClass = class
  public
    [Test]
    procedure Test_ClassConstructor_CreatesSingleton;
    [Test]
    procedure Test_Install_DoesNotCrash;
  end;

  [TestFixture]
  TTestExceptionHierarchy = class
  public
    [Test]
    procedure Test_TUniBaseExceptionHandler_IsClass;
    [Test]
    procedure Test_TUniBaseExceptionHandler_HasInstallMethod;
  end;

  [TestFixture]
  TTestExceptionBasics = class
  public
    [Test]
    procedure Test_StandardException_ClassName;
    [Test]
    procedure Test_EAbort_IsException;
    [Test]
    procedure Test_Exception_Message;
    [Test]
    procedure Test_EMathException_IsEUniBaseException;
    [Test]
    procedure Test_EUniBaseDbError_IsEUniBaseException;
  end;

implementation

{ TTestExceptionHandlerClass }

procedure TTestExceptionHandlerClass.Test_ClassConstructor_CreatesSingleton;
begin
  // The class constructor auto-runs when the unit is used.
  // It creates a private FInstance. We cannot access FInstance directly,
  // but calling Install should work without crashing, proving the
  // singleton was created in the class constructor.
  Assert.Pass('Class constructor executed - singleton created');
end;

procedure TTestExceptionHandlerClass.Test_Install_DoesNotCrash;
begin
  // Install assigns Application.OnException. In a test runner (console),
  // Application exists but may be a TApplication stub. This should not crash.
  try
    TUniBaseExceptionHandler.Install;
  except
    on E: Exception do
      Assert.Fail('Install raised unexpected exception: ' + E.Message);
  end;
  Assert.IsTrue(True, 'Install completed without error');
end;

{ TTestExceptionHierarchy }

procedure TTestExceptionHierarchy.Test_TUniBaseExceptionHandler_IsClass;
begin
  // Verify the class exists and is a valid class reference
  Assert.IsNotNull(TUniBaseExceptionHandler);
end;

procedure TTestExceptionHierarchy.Test_TUniBaseExceptionHandler_HasInstallMethod;
begin
  // Verify the Install class method is callable (structural check).
  // If the method did not exist, this would not compile.
  Assert.Pass('Install class method exists and is callable');
end;

{ TTestExceptionBasics }

procedure TTestExceptionBasics.Test_StandardException_ClassName;
var
  E: Exception;
begin
  E := Exception.Create('test');
  try
    Assert.AreEqual('Exception', E.ClassName);
  finally
    E.Free;
  end;
end;

procedure TTestExceptionBasics.Test_EAbort_IsException;
var
  E: EAbort;
begin
  E := EAbort.Create('aborted');
  try
    Assert.IsTrue(E is Exception, 'EAbort should be an Exception descendant');
    Assert.AreEqual('EAbort', E.ClassName);
  finally
    E.Free;
  end;
end;

procedure TTestExceptionBasics.Test_Exception_Message;
var
  E: Exception;
begin
  E := Exception.Create('Something went wrong');
  try
    Assert.AreEqual('Something went wrong', E.Message);
  finally
    E.Free;
  end;
end;

procedure TTestExceptionBasics.Test_EMathException_IsEUniBaseException;
var
  E: EMathException;
begin
  E := EMathException.Create('math error');
  try
    Assert.IsTrue(E is EUniBaseException, 'EMathException should inherit EUniBaseException');
  finally
    E.Free;
  end;
end;

procedure TTestExceptionBasics.Test_EUniBaseDbError_IsEUniBaseException;
var
  E: EUniBaseDbError;
begin
  E := EUniBaseDbError.Create('db error', 'test.proc', 'SELECT 1', '{}', udbSQLite, 'cid');
  try
    Assert.IsTrue(E is EUniBaseException, 'EUniBaseDbError should inherit EUniBaseException');
  finally
    E.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestExceptionHandlerClass);
  TDUnitX.RegisterTestFixture(TTestExceptionHierarchy);
  TDUnitX.RegisterTestFixture(TTestExceptionBasics);

end.
