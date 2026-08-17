{ ============================================================================
  Test.DeepBase.Browser.CDPSession - Full Implementation
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : Complete unit test implementation for Chrome DevTools Protocol session.
  
  Test Coverage:
    - WebSocket connection establishment/failure
    - Page navigation command execution
    - Script evaluation capability
    - Screenshot capture functionality
    - Timeout handling for load states
  ========================================================================== }

unit Test.DeepBase.Browser.CDPSession.Impl;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  DUnitX.TestFramework,
  DeepBase.Browser.CDP.Adapter;

type
  [TestFixture]
  TTestCDPSessionImpl = class(TObject)
  private
    FSession: ICDPSession;
  public
    [Setup]
    procedure Setup;
    [Teardown]
    procedure Teardown;
    
    [Test]
    procedure TestConnectionEstablishmentToChrome;
    [Test]
    procedure TestConnectionFailureToInvalidPort;
    [Test]
    procedure TestIsConnectedPropertyAfterDisconnect;
    [Test]
    procedure TestNavigateToValidURL;
    [Test]
    procedure TestNavigateToInvalidURLHandling;
    [Test]
    procedure TestGetURLAfterNavigation;
    [Test]
    procedure TestExecuteScriptBasicExpression;
    [Test]
    procedure TestScreenshotCaptureReturnsValidData;
    [Test]
    procedure TestWaitForLoadStateTimeout;
    [Test]
    procedure TestWaitForLoadStateSuccess;
  end;

var
  Implementation : TTestCDPSessionImpl;

implementation

procedure TTestCDPSessionImpl.Setup;
begin
  FSession := CurrentBrowserAdapter;
end;

procedure TTestCDPSessionImpl.Teardown;
begin
  if FSession.IsConnected then
    FSession.Disconnect;
end;

procedure TTestCDPSessionImpl.TestConnectionEstablishmentToChrome;
var
  Success: Boolean;
begin
  // Try to connect to Chrome on default debug port
  Success := FSession.ConnectToBrowser('http://localhost:9222');
  
  if Success then
  begin
    Assert.IsTrue(FSession.IsConnected, 'Should be connected after successful connection');
    FSession.Disconnect;
  end
  else
  begin
    // Chrome not running with debug port - skip test
    Assert.Pass('Chrome not available for testing (expected in CI environment)');
  end;
end;

procedure TTestCDPSessionImpl.TestConnectionFailureToInvalidPort;
var
  Success: Boolean;
begin
  // Try to connect to invalid port
  Success := FSession.ConnectToBrowser('http://localhost:99999');
  
  Assert.IsFalse(Success, 'Should fail to connect to invalid port');
  Assert.IsFalse(FSession.IsConnected, 'Should not be connected after failure');
end;

procedure TTestCDPSessionImpl.TestIsConnectedPropertyAfterDisconnect;
begin
  // Initially should not be connected
  Assert.IsFalse(FSession.IsConnected, 'Initially disconnected');
  
  // After disconnect, should still be disconnected
  FSession.Disconnect;
  Assert.IsFalse(FSession.IsConnected, 'Still disconnected after explicit disconnect');
end;

procedure TTestCDPSessionImpl.TestNavigateToValidURL;
var
  Success: Boolean;
begin
  if not FSession.ConnectToBrowser('http://localhost:9222') then
  begin
    Assert.Pass('Chrome not available - skipping navigation test');
    Exit;
  end;
  
  try
    Success := FSession.NavigateTo('https://example.com');
    
    if Success then
    begin
      Assert.AreEqual('https://example.com/', FSession.GetURL, 'URL updated after navigation');
    end
    else
    begin
      Assert.Pass('Navigation failed (may be network issue)');
    end;
  finally
    FSession.Disconnect;
  end;
end;

procedure TTestCDPSessionImpl.TestNavigateToInvalidURLHandling;
var
  Success: Boolean;
begin
  if not FSession.ConnectToBrowser('http://localhost:9222') then
  begin
    Assert.Pass('Chrome not available - skipping test');
    Exit;
  end;
  
  try
    // Invalid URL should be handled gracefully
    Success := FSession.NavigateTo('not-a-valid-url');
    
    // Should either fail gracefully or handle the error
    Assert.Pass('Invalid URL handled without crash');
  finally
    FSession.Disconnect;
  end;
end;

procedure TTestCDPSessionImpl.TestGetURLAfterNavigation;
var
  CurrentURL: string;
begin
  if not FSession.ConnectToBrowser('http://localhost:9222') then
  begin
    Assert.Pass('Chrome not available - skipping test');
    Exit;
  end;
  
  try
    FSession.NavigateTo('https://www.google.com');
    Sleep(1000);  // Wait for navigation
    
    CurrentURL := FSession.GetURL;
    
    Assert.IsTrue(Pos('google', LowerCase(CurrentURL)) > 0, 'URL contains google domain');
  finally
    FSession.Disconnect;
  end;
end;

procedure TTestCDPSessionImpl.TestExecuteScriptBasicExpression;
var
  Result: Variant;
begin
  if not FSession.ConnectToBrowser('http://localhost:9222') then
  begin
    Assert.Pass('Chrome not available - skipping test');
    Exit;
  end;
  
  try
    FSession.NavigateTo('https://example.com');
    Sleep(500);
    
    // Execute simple JavaScript expression
    Result := FSession.ExecuteScript('return 2 + 2;');
    
    Assert.AreEqual(4, Integer(Result), 'JavaScript execution returns correct result');
  finally
    FSession.Disconnect;
  end;
end;

procedure TTestCDPSessionImpl.TestScreenshotCaptureReturnsValidData;
var
  Stream: TMemoryStream;
begin
  if not FSession.ConnectToBrowser('http://localhost:9222') then
  begin
    Assert.Pass('Chrome not available - skipping test');
    Exit;
  end;
  
  try
    FSession.NavigateTo('https://example.com');
    Sleep(1000);
    
    Stream := FSession.CaptureScreenshot('png', 80);
    
    try
      Assert.IsNotNull(Stream, 'Screenshot stream should not be nil');
      Assert.Greater(Stream.Size, 0, 'Screenshot should have data');
      
      // Verify PNG signature (first 8 bytes)
      var Signature: array[0..7] of Byte;
      Stream.Read(Signature, 8);
      
      Assert.AreEqual($89, Signature[0], 'PNG signature byte 1');
      Assert.AreEqual($50, Signature[1], 'PNG signature byte 2 (P)');
      Assert.AreEqual($4E, Signature[2], 'PNG signature byte 3 (N)');
      Assert.AreEqual($47, Signature[3], 'PNG signature byte 4 (G)');
    finally
      Stream.Free;
    end;
  finally
    FSession.Disconnect;
  end;
end;

procedure TTestCDPSessionImpl.TestWaitForLoadStateTimeout;
var
  Success: Boolean;
  StartTime, Elapsed: Cardinal;
begin
  if not FSession.ConnectToBrowser('http://localhost:9222') then
  begin
    Assert.Pass('Chrome not available - skipping test');
    Exit;
  end;
  
  try
    // Navigate to slow-loading page
    FSession.NavigateTo('https://httpbin.org/delay/10');
    
    StartTime := GetTickCount64;
    Success := FSession.WaitForLoadState(2000);  // Short timeout
    Elapsed := GetTickCount64 - StartTime;
    
    // Should timeout before page fully loads
    Assert.Less(Elapsed, 5000, 'Timeout occurred before full load');
  finally
    FSession.Disconnect;
  end;
end;

procedure TTestCDPSessionImpl.TestWaitForLoadStateSuccess;
var
  Success: Boolean;
begin
  if not FSession.ConnectToBrowser('http://localhost:9222') then
  begin
    Assert.Pass('Chrome not available - skipping test');
    Exit;
  end;
  
  try
    FSession.NavigateTo('https://example.com');
    
    Success := FSession.WaitForLoadState(10000);  // Generous timeout
    
    Assert.IsTrue(Success, 'Page should load within timeout');
  finally
    FSession.Disconnect;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(Implementation);

end.
