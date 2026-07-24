{ ============================================================================
  Test.DeepBase.Browser.WebElement
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : Unit tests for Web element manipulation and location strategies.
  
  Features Tested:
    - CSS selector element finding
    - XPath selector element finding
    - Attribute retrieval accuracy
    - Click and type text operations
    - Visibility detection logic
  ========================================================================== }

unit Test.DeepBase.Browser.WebElement;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DeepBase.Browser.Session;

type
  [TestFixture]
  TTestWebWebElement = class(TObject)
  public
    [Setup]
    procedure Setup;
    [Teardown]
    procedure Teardown;
    
    // Locator tests
    [Test]
    procedure TestFindByCSSBasicSelector;
    [Test]
    procedure TestFindByXPathRelativePath;
    [Test]
    procedure TestFindByComplexNestedSelector;
    
    // Operation tests
    [Test]
    procedure TestGetAttributeStringValue;
    [Test]
    procedure TestClickOnVisibleElement;
    [Test]
    procedure TestTypeTextIntoInputField;
    
    // Property tests
    [Test]
    procedure TestIsVisibleWithRectValidation;
    [Test]
    procedure TestIsEnabledDisabledAttributeCheck;
    [Test]
    procedure TestToStringRepresentationAccuracy;
  end;

var
  Implementation : TTestWebWebElement;

initialization
  TDUnitX.RegisterTestFixture(Implementation);

end.
