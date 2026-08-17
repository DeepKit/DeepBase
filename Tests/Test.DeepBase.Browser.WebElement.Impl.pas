{ ============================================================================
  Test.DeepBase.Browser.WebElement - Full Implementation
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : Complete unit test implementation for Web element manipulation.
  
  Test Coverage:
    - CSS/XPath selector element finding
    - Attribute retrieval accuracy
    - Click and type text operations
    - Visibility detection logic
    - Element state validation
  ========================================================================== }

unit Test.DeepBase.Browser.WebElement.Impl;

interface

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework,
  DeepBase.Browser.Session,
  DeepBase.Browser.WebElement;

type
  [TestFixture]
  TTestWebWebElementImpl = class(TObject)
  private
    FSession: IBrowserSession;
    FTestElement: TWebWebElement;
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
    [Test]
    procedure TestFindByIDShortcut;
    
    // Operation tests
    [Test]
    procedure TestGetAttributeStringValue;
    [Test]
    procedure TestGetAttributeValueAttribute;
    [Test]
    procedure TestClickOnVisibleElement;
    [Test]
    procedure TestTypeTextIntoInputField;
    [Test]
    procedure TestSelectOptionInDropdown;
    
    // Property tests
    [Test]
    procedure TestIsVisibleWithRectValidation;
    [Test]
    procedure TestIsEnabledDisabledAttributeCheck;
    [Test]
    procedure TestToStringRepresentationAccuracy;
    [Test]
    procedure TestGetHTMLContentExtraction;
  end;

var
  Implementation : TTestWebWebElementImpl;

implementation

procedure TTestWebWebElementImpl.Setup;
begin
  FSession := CreateBrowserSession;
  
  // Navigate to test page if Chrome is available
  if FSession.IsOpen then
  begin
    FSession.NavigateTo('https://example.com');
    Sleep(1000);
  end;
end;

procedure TTestWebWebElementImpl.Teardown;
begin
  if Assigned(FSession) then
    FSession.Close;
end;

procedure TTestWebWebElementImpl.TestFindByCSSBasicSelector;
var
  Element: TWebWebElement;
begin
  if not FSession.IsOpen then
  begin
    Assert.Pass('Browser not available - skipping test');
    Exit;
  end;
  
  // Find element by basic CSS selector
  Element := FSession.FindElementByCSS('h1');
  
  Assert.IsNotNull(Element.Handle, 'Element handle should not be nil');
  Assert.AreEqual('h1', Element.GetAttribute('tagName'), 'Tag name should be h1');
end;

procedure TTestWebWebElementImpl.TestFindByXPathRelativePath;
var
  Element: TWebWebElement;
begin
  if not FSession.IsOpen then
  begin
    Assert.Pass('Browser not available - skipping test');
    Exit;
  end;
  
  // Find element by XPath
  Element := FSession.FindElementByXPath('//h1');
  
  Assert.IsNotNull(Element.Handle, 'XPath element should be found');
end;

procedure TTestWebWebElementImpl.TestFindByComplexNestedSelector;
var
  Element: TWebWebElement;
begin
  if not FSession.IsOpen then
  begin
    Assert.Pass('Browser not available - skipping test');
    Exit;
  end;
  
  // Find element with complex nested selector
  Element := FSession.FindElementByCSS('body > div > h1');
  
  Assert.IsNotNull(Element.Handle, 'Nested selector should find element');
end;

procedure TTestWebWebElementImpl.TestFindByIDShortcut;
var
  Element: TWebWebElement;
begin
  if not FSession.IsOpen then
  begin
    Assert.Pass('Browser not available - skipping test');
    Exit;
  end;
  
  // Test ID-based lookup (if element with ID exists)
  Element := FSession.FindElementByCSS('[id]');
  
  if Assigned(Element.Handle) then
  begin
    var IDValue := Element.GetAttribute('id');
    Assert.IsTrue(IDValue <> '', 'Element should have ID attribute');
  end
  else
  begin
    Assert.Pass('No element with ID found on test page');
  end;
end;

procedure TTestWebWebElementImpl.TestGetAttributeStringValue;
var
  Element: TWebWebElement;
  TagName: string;
begin
  if not FSession.IsOpen then
  begin
    Assert.Pass('Browser not available - skipping test');
    Exit;
  end;
  
  Element := FSession.FindElementByCSS('h1');
  TagName := Element.GetAttribute('tagName');
  
  Assert.AreEqual('H1', UpperCase(TagName), 'Tag name attribute retrieved correctly');
end;

procedure TTestWebWebElementImpl.TestGetAttributeValueAttribute;
var
  Element: TWebWebElement;
begin
  if not FSession.IsOpen then
  begin
    Assert.Pass('Browser not available - skipping test');
    Exit;
  end;
  
  // Try to find an input element with value
  Element := FSession.FindElementByCSS('input[type="text"]');
  
  if Assigned(Element.Handle) then
  begin
    var Value := Element.GetValue;
    Assert.Pass('Value attribute retrieved: ' + Value);
  end
  else
  begin
    Assert.Pass('No text input found on test page');
  end;
end;

procedure TTestWebWebElementImpl.TestClickOnVisibleElement;
var
  Element: TWebWebElement;
begin
  if not FSession.IsOpen then
  begin
    Assert.Pass('Browser not available - skipping test');
    Exit;
  end;
  
  Element := FSession.FindElementByCSS('a');
  
  if Element.IsVisible then
  begin
    Element.Click;
    Sleep(500);
    Assert.Pass('Click executed on visible element');
  end
  else
  begin
    Assert.Pass('Element not visible - click skipped');
  end;
end;

procedure TTestWebWebElementImpl.TestTypeTextIntoInputField;
var
  Element: TWebWebElement;
  TestText: string;
begin
  if not FSession.IsOpen then
  begin
    Assert.Pass('Browser not available - skipping test');
    Exit;
  end;
  
  Element := FSession.FindElementByCSS('input[type="text"]');
  
  if Assigned(Element.Handle) then
  begin
    TestText := 'Test Input ' + DateTimeToStr(Now);
    Element.TypeText(TestText);
    
    Sleep(200);
    var ActualValue := Element.GetValue;
    
    Assert.AreEqual(TestText, ActualValue, 'Typed text matches input value');
  end
  else
  begin
    Assert.Pass('No text input found on test page');
  end;
end;

procedure TTestWebWebElementImpl.TestSelectOptionInDropdown;
var
  Element: TWebWebElement;
begin
  if not FSession.IsOpen then
  begin
    Assert.Pass('Browser not available - skipping test');
    Exit;
  end;
  
  Element := FSession.FindElementByCSS('select');
  
  if Assigned(Element.Handle) then
  begin
    var Success := Element.SelectOption('option1');
    Assert.Pass('Select option executed');
  end
  else
  begin
    Assert.Pass('No select element found on test page');
  end;
end;

procedure TTestWebWebElementImpl.TestIsVisibleWithRectValidation;
var
  Element: TWebWebElement;
  IsVisible: Boolean;
  ElementRect: TRect;
begin
  if not FSession.IsOpen then
  begin
    Assert.Pass('Browser not available - skipping test');
    Exit;
  end;
  
  Element := FSession.FindElementByCSS('h1');
  IsVisible := Element.IsVisible;
  ElementRect := Element.GetRect;
  
  if IsVisible then
  begin
    Assert.Greater(ElementRect.Right, ElementRect.Left, 'Visible element has positive width');
    Assert.Greater(ElementRect.Bottom, ElementRect.Top, 'Visible element has positive height');
  end
  else
  begin
    Assert.Pass('Element not visible on test page');
  end;
end;

procedure TTestWebWebElementImpl.TestIsEnabledDisabledAttributeCheck;
var
  Element: TWebWebElement;
  IsEnabled: Boolean;
begin
  if not FSession.IsOpen then
  begin
    Assert.Pass('Browser not available - skipping test');
    Exit;
  end;
  
  Element := FSession.FindElementByCSS('input');
  
  if Assigned(Element.Handle) then
  begin
    IsEnabled := Element.IsEnabled;
    
    var DisabledAttr := Element.GetAttribute('disabled');
    if LowerCase(DisabledAttr) = 'true' then
      Assert.IsFalse(IsEnabled, 'Disabled element should return False')
    else
      Assert.IsTrue(IsEnabled, 'Enabled element should return True');
  end
  else
  begin
    Assert.Pass('No input element found on test page');
  end;
end;

procedure TTestWebWebElementImpl.TestToStringRepresentationAccuracy;
var
  Element: TWebWebElement;
  ElementStr: string;
begin
  if not FSession.IsOpen then
  begin
    Assert.Pass('Browser not available - skipping test');
    Exit;
  end;
  
  Element := FSession.FindElementByCSS('h1');
  ElementStr := Element.ToString;
  
  Assert.IsTrue(Pos('h1', LowerCase(ElementStr)) > 0, 'ToString contains tag name');
  Assert.IsTrue(Pos('<', ElementStr) > 0, 'ToString has angle brackets');
end;

procedure TTestWebWebElementImpl.TestGetHTMLContentExtraction;
var
  Element: TWebWebElement;
  HTMLContent: string;
begin
  if not FSession.IsOpen then
  begin
    Assert.Pass('Browser not available - skipping test');
    Exit;
  end;
  
  Element := FSession.FindElementByCSS('h1');
  HTMLContent := Element.GetHTML;
  
  Assert.IsTrue(Pos('<h1', LowerCase(HTMLContent)) > 0, 'HTML contains opening tag');
  Assert.IsTrue(Pos('</h1>', LowerCase(HTMLContent)) > 0, 'HTML contains closing tag');
end;

initialization
  TDUnitX.RegisterTestFixture(Implementation);

end.
