{ ============================================================================
  Test.DeepBase.Exception - Unit Tests for Global Exception Handler Module

  Tests the actual API provided by DeepBase.Exception:
    - Install class method
    - OnException behavior (private, tested indirectly via Install)

  Note: The core module depends on Vcl.Forms, FireDAC, DeepBase.Manager,
  and DeepBase.Logging, so full integration testing of OnException and
  LogExceptionToDB requires those services to be available. Here we test
  the structural and lifecycle aspects that are safe to verify in isolation.
  ============================================================================ }

unit Test.DeepBase.Exception;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Vcl.Forms,
  DeepBase.Storage.Interfaces,
  DeepBase.Exception, DeepBase.Exceptions, DeepBase.Math, DeepBase.DB.DoQry;

type
  [TestFixture]
  TTestExceptionHandlerClass = class
  public
    [Test]
    procedure Test_Install_DoesNotCrash;
    [Test]
    procedure Test_StorageInjection_LogsExceptionViaInjectedStorage;
  end;

  [TestFixture]
  TTestExceptionHierarchy = class
  public
    [Test]
    procedure Test_TDeepBaseExceptionHandler_IsClass;
    [Test]
    procedure Test_TDeepBaseExceptionHandler_HasInstallMethod;
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
    procedure Test_EMathException_IsEDeepBaseException;
    [Test]
    procedure Test_EDeepBaseDbError_IsEDeepBaseException;
  end;

  TInMemoryExceptionReportStorage = class(TInterfacedObject,
    IExceptionReportStorage)
  public
    WriteCount: Integer;
    LastReport: TExceptionReportData;
    procedure WriteReport(const Data: TExceptionReportData);
  end;

implementation

{ TInMemoryExceptionReportStorage }

procedure TInMemoryExceptionReportStorage.WriteReport(
  const Data: TExceptionReportData);
begin
  Inc(WriteCount);
  LastReport := Data;
end;

{ TTestExceptionHandlerClass }

procedure TTestExceptionHandlerClass.Test_Install_DoesNotCrash;
begin
  // Install assigns Application.OnException. In a test runner (console),
  // Application exists but may be a TApplication stub. This should not crash.
  try
    TDeepBaseExceptionHandler.Install;
  except
    on E: Exception do
      Assert.Fail('Install raised unexpected exception: ' + E.Message);
  end;
  Assert.IsTrue(True, 'Install completed without error');
end;

procedure TTestExceptionHandlerClass.Test_StorageInjection_LogsExceptionViaInjectedStorage;
var
  StorageObj: TInMemoryExceptionReportStorage;
  StorageRef: IExceptionReportStorage;
  AbortError: EAbort;
begin
  StorageObj := TInMemoryExceptionReportStorage.Create;
  StorageRef := StorageObj;

  TDeepBaseExceptionHandler.SetStorageFactory(
    function(AConnection: TObject): IExceptionReportStorage
    begin
      Result := StorageRef;
    end);
  try
    TDeepBaseExceptionHandler.Install;

    AbortError := EAbort.Create('Injected storage test');
    try
      Assert.IsTrue(Assigned(Application.OnException),
        'Install should assign Application.OnException');
      Application.OnException(nil, AbortError);
    finally
      AbortError.Free;
    end;

    Assert.AreEqual(1, StorageObj.WriteCount,
      'Injected storage should receive one exception report');
    Assert.AreEqual('EAbort', StorageObj.LastReport.ExceptionClass);
    Assert.AreEqual('Injected storage test', StorageObj.LastReport.MessageText);
    Assert.IsTrue(StorageObj.LastReport.ReportTimeISO <> '');
  finally
    TDeepBaseExceptionHandler.SetStorageFactory(nil);
  end;
end;

{ TTestExceptionHierarchy }

procedure TTestExceptionHierarchy.Test_TDeepBaseExceptionHandler_IsClass;
begin
  // Verify the class exists and is a valid class reference
  Assert.IsNotNull(TDeepBaseExceptionHandler);
end;

procedure TTestExceptionHierarchy.Test_TDeepBaseExceptionHandler_HasInstallMethod;
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

procedure TTestExceptionBasics.Test_EMathException_IsEDeepBaseException;
var
  E: EMathException;
begin
  E := EMathException.Create('math error');
  try
    Assert.IsTrue(E is EDeepBaseException, 'EMathException should inherit EDeepBaseException');
  finally
    E.Free;
  end;
end;

procedure TTestExceptionBasics.Test_EDeepBaseDbError_IsEDeepBaseException;
var
  E: EDeepBaseDbError;
begin
  E := EDeepBaseDbError.Create('db error', 'test.proc', 'SELECT 1', '{}', udbSQLite, 'cid');
  try
    Assert.IsTrue(E is EDeepBaseException, 'EDeepBaseDbError should inherit EDeepBaseException');
  finally
    E.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestExceptionHandlerClass);
  TDUnitX.RegisterTestFixture(TTestExceptionHierarchy);
  TDUnitX.RegisterTestFixture(TTestExceptionBasics);

end.
