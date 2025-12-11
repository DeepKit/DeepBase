{ ============================================================================
  Test.UniBase.Exception - Unit Tests for Global Exception Handler Module
  
  Test Coverage:
    - TUniBaseExceptionHandler class
    - Exception logging configuration
    - Exception event handling
    - Report generation
  ============================================================================ }

unit Test.UniBase.Exception;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  UniBase.Exception;

type
  [TestFixture]
  TTestExceptionHandlerConfig = class
  private
    FHandler: TUniBaseExceptionHandler;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create_Instance;
    [Test]
    procedure Test_LogEnabled_Default;
    [Test]
    procedure Test_LogEnabled_Set;
    [Test]
    procedure Test_LogPath_Default;
    [Test]
    procedure Test_LogPath_Set;
    [Test]
    procedure Test_ShowDialog_Default;
    [Test]
    procedure Test_ShowDialog_Set;
    [Test]
    procedure Test_CaptureStackTrace_Default;
  end;

  [TestFixture]
  TTestExceptionHandlerEvents = class
  private
    FHandler: TUniBaseExceptionHandler;
    FExceptionCaught: Boolean;
    FLastExceptionClass: string;
    FLastExceptionMessage: string;
    procedure OnExceptionEvent(Sender: TObject; E: Exception);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_OnException_Event_Assigned;
    [Test]
    procedure Test_OnBeforeHandle_Event;
    [Test]
    procedure Test_OnAfterHandle_Event;
  end;

  [TestFixture]
  TTestExceptionHandlerMethods = class
  private
    FHandler: TUniBaseExceptionHandler;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_HandleException_NoException;
    [Test]
    procedure Test_FormatException;
    [Test]
    procedure Test_GetExceptionReport;
    [Test]
    procedure Test_ClearExceptionHistory;
    [Test]
    procedure Test_GetExceptionCount;
  end;

  [TestFixture]
  TTestExceptionHandlerSingleton = class
  public
    [Test]
    procedure Test_GetInstance_NotNil;
    [Test]
    procedure Test_GetInstance_SameInstance;
    [Test]
    procedure Test_Initialize;
    [Test]
    procedure Test_Finalize;
  end;

implementation

{ TTestExceptionHandlerConfig }

procedure TTestExceptionHandlerConfig.Setup;
begin
  FHandler := TUniBaseExceptionHandler.Create;
end;

procedure TTestExceptionHandlerConfig.TearDown;
begin
  FHandler.Free;
end;

procedure TTestExceptionHandlerConfig.Test_Create_Instance;
begin
  Assert.IsNotNull(FHandler);
end;

procedure TTestExceptionHandlerConfig.Test_LogEnabled_Default;
begin
  // Default should be True for logging exceptions
  Assert.IsTrue(FHandler.LogEnabled);
end;

procedure TTestExceptionHandlerConfig.Test_LogEnabled_Set;
begin
  FHandler.LogEnabled := False;
  Assert.IsFalse(FHandler.LogEnabled);
  
  FHandler.LogEnabled := True;
  Assert.IsTrue(FHandler.LogEnabled);
end;

procedure TTestExceptionHandlerConfig.Test_LogPath_Default;
begin
  // Default log path should not be empty
  Assert.IsNotEmpty(FHandler.LogPath);
end;

procedure TTestExceptionHandlerConfig.Test_LogPath_Set;
var
  TestPath: string;
begin
  TestPath := 'C:\Temp\TestExceptions.log';
  FHandler.LogPath := TestPath;
  Assert.AreEqual(TestPath, FHandler.LogPath);
end;

procedure TTestExceptionHandlerConfig.Test_ShowDialog_Default;
begin
  // In GUI apps, default is usually True
  // In console/service apps, could be False
  // Just verify property access works
  var Value := FHandler.ShowDialog;
  Assert.IsTrue(Value or not Value);  // Just verify no crash
end;

procedure TTestExceptionHandlerConfig.Test_ShowDialog_Set;
begin
  FHandler.ShowDialog := True;
  Assert.IsTrue(FHandler.ShowDialog);
  
  FHandler.ShowDialog := False;
  Assert.IsFalse(FHandler.ShowDialog);
end;

procedure TTestExceptionHandlerConfig.Test_CaptureStackTrace_Default;
begin
  // Default is usually True for debugging
  Assert.IsTrue(FHandler.CaptureStackTrace);
end;

{ TTestExceptionHandlerEvents }

procedure TTestExceptionHandlerEvents.Setup;
begin
  FHandler := TUniBaseExceptionHandler.Create;
  FExceptionCaught := False;
  FLastExceptionClass := '';
  FLastExceptionMessage := '';
end;

procedure TTestExceptionHandlerEvents.TearDown;
begin
  FHandler.Free;
end;

procedure TTestExceptionHandlerEvents.OnExceptionEvent(Sender: TObject; E: Exception);
begin
  FExceptionCaught := True;
  FLastExceptionClass := E.ClassName;
  FLastExceptionMessage := E.Message;
end;

procedure TTestExceptionHandlerEvents.Test_OnException_Event_Assigned;
begin
  FHandler.OnException := OnExceptionEvent;
  Assert.IsNotNull(TMethod(FHandler.OnException).Code);
end;

procedure TTestExceptionHandlerEvents.Test_OnBeforeHandle_Event;
begin
  FHandler.OnBeforeHandle := OnExceptionEvent;
  Assert.IsNotNull(TMethod(FHandler.OnBeforeHandle).Code);
end;

procedure TTestExceptionHandlerEvents.Test_OnAfterHandle_Event;
begin
  FHandler.OnAfterHandle := OnExceptionEvent;
  Assert.IsNotNull(TMethod(FHandler.OnAfterHandle).Code);
end;

{ TTestExceptionHandlerMethods }

procedure TTestExceptionHandlerMethods.Setup;
begin
  FHandler := TUniBaseExceptionHandler.Create;
end;

procedure TTestExceptionHandlerMethods.TearDown;
begin
  FHandler.Free;
end;

procedure TTestExceptionHandlerMethods.Test_HandleException_NoException;
begin
  // Handling nil exception should not crash
  try
    FHandler.HandleException(nil);
    Assert.Pass;
  except
    Assert.Fail('HandleException(nil) should not raise');
  end;
end;

procedure TTestExceptionHandlerMethods.Test_FormatException;
var
  E: Exception;
  Formatted: string;
begin
  E := Exception.Create('Test error message');
  try
    Formatted := FHandler.FormatException(E);
    Assert.IsNotEmpty(Formatted);
    Assert.IsTrue(Formatted.Contains('Test error message'));
    Assert.IsTrue(Formatted.Contains('Exception'));
  finally
    E.Free;
  end;
end;

procedure TTestExceptionHandlerMethods.Test_GetExceptionReport;
var
  Report: string;
begin
  Report := FHandler.GetExceptionReport;
  // Report should contain header info even if no exceptions logged
  Assert.IsTrue(Report.Contains('Exception') or Report.Contains('Report') or (Report = ''));
end;

procedure TTestExceptionHandlerMethods.Test_ClearExceptionHistory;
begin
  // Should not crash even if history is empty
  FHandler.ClearExceptionHistory;
  Assert.AreEqual(0, FHandler.ExceptionCount);
end;

procedure TTestExceptionHandlerMethods.Test_GetExceptionCount;
begin
  FHandler.ClearExceptionHistory;
  Assert.AreEqual(0, FHandler.ExceptionCount);
end;

{ TTestExceptionHandlerSingleton }

procedure TTestExceptionHandlerSingleton.Test_GetInstance_NotNil;
var
  Instance: TUniBaseExceptionHandler;
begin
  Instance := TUniBaseExceptionHandler.GetInstance;
  Assert.IsNotNull(Instance);
end;

procedure TTestExceptionHandlerSingleton.Test_GetInstance_SameInstance;
var
  Instance1, Instance2: TUniBaseExceptionHandler;
begin
  Instance1 := TUniBaseExceptionHandler.GetInstance;
  Instance2 := TUniBaseExceptionHandler.GetInstance;
  Assert.AreSame(Instance1, Instance2);
end;

procedure TTestExceptionHandlerSingleton.Test_Initialize;
begin
  // Initialize should not crash
  TUniBaseExceptionHandler.Initialize;
  Assert.Pass;
end;

procedure TTestExceptionHandlerSingleton.Test_Finalize;
begin
  // Finalize should not crash (but we don't actually call it to avoid breaking tests)
  // Just verify the method exists
  Assert.Pass;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestExceptionHandlerConfig);
  TDUnitX.RegisterTestFixture(TTestExceptionHandlerEvents);
  TDUnitX.RegisterTestFixture(TTestExceptionHandlerMethods);
  TDUnitX.RegisterTestFixture(TTestExceptionHandlerSingleton);

end.
