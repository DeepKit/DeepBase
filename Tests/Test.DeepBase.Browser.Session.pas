{ ============================================================================
  Test.DeepBase.Browser.Session
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : Unit tests for high-level browser session management operations.
  
  Features Tested:
    - Browser lifecycle (open/close/restart)
    - Tab navigation and switching
    - Cookie serialization/deserialization
    - HTML content retrieval accuracy
    - Screenshot format validation
  ========================================================================== }

unit Test.DeepBase.Browser.Session;

interface

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework,
  DeepBase.Browser.Session;

type
  [TestFixture]
  TTestBrowserSession = class(TObject)
  public
    [Setup]
    procedure Setup;
    [Teardown]
    procedure Teardown;
    
    // Lifecycle tests
    [Test]
    procedure TestOpenAndCloseValidURL;
    [Test]
    procedure TestIsOpenAfterInitialization;
    [Test]
    procedure TestReopenAfterClose;
    
    // Navigation tests
    [Test]
    procedure TestGoBackFailsOnInitialNavigation;
    [Test]
    procedure TestReloadPageUpdatesContent;
    [Test]
    procedure TestGetURLMatchesCurrentLocation;
    
    // Content tests
    [Test]
    procedure TestGetHTMLContentReturnsValidDOM;
    [Test]
    procedure TestGetInnerTextExtractsTextOnly;
    [Test]
    procedure TestTakeScreenshotReturnsPNGFormat;
    
    // Element tests
    [Test]
    procedure TestFindElementByCSSReturnsNonNullOnMatch;
    [Test]
    procedure TestFindElementsReturnsArrayOnMultipleMatches;
    [Test]
    procedure TestClickViaCSSSelectorTriggersEvent;
    
    // Cookie tests
    [Test]
    procedure TestAddCookieToBrowserContext;
    [Test]
    procedure TestClearCookiesRemovesAllCookies;
    [Test]
    procedure TestGetCookiesReturnsJSONArrayStructure;
  end;

var
  Implementation : TTestBrowserSession;

initialization
  TDUnitX.RegisterTestFixture(Implementation);

end.
