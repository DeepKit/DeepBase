{ ============================================================================
  DeepBase.Browser.WebElement
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : Web element abstraction class with XPath/CSS selector support,
                providing Selenium-like API for DOM manipulation and inspection.
  
  Features:
    - CSS Selector + XPath location strategies
    - GetAttribute, GetValue, Click, TypeText methods
    - Screenshot capture support for OCR integration
    - Visibility checks and rect extraction
    
  Performance:
    - Cached element handles to avoid repeated lookups
    - Lazy evaluation of visibility/geometry properties
  ========================================================================== }

unit DeepBase.Browser.WebElement;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  Winapi.Windows,
  DeepBase.Browser.CDP.Adapter;

type
  TWebWebElement = record
  private
    FHandle: TJSONValue;        // CDP DOM node handle
    FSession: IBrowserSession;  // Parent browser session reference
    FIsVisibleCached: Boolean;
    FRectCached: TRect;
    FVisibilityChecked: Boolean;
    
    function GetAttributeInternal(AttrName: string): string;
    function GetValueInternal: string;
  public
    // Location strategies
    class function FindByCSS(Session: IBrowserSession; 
      Selector: string): TWebWebElement; static; overload;
    class function FindByXPath(Session: IBrowserSession; 
      XPath: string): TWebWebElement; static; overload;
      
    // Basic operations
    procedure Click;
    procedure TypeText(Text: string);
    function GetAttribute(AttrName: string): string;
    function GetValue: string;
    function SelectOption(Value: string): Boolean;
    
    // Properties
    function IsVisible: Boolean;
    function IsEnabled: Boolean;
    function GetRect: TRect;
    function GetHTML: string;
    
    // Chaining methods
    function FirstChild: TWebWebElement;
    function Parent: TWebWebElement;
    function ChildAt(Index: Integer): TWebWebElement;
    
    // Operators
    class operator Implicit(const Value: TWebWebElement): Variant;
    function ToString: string; override;
  end;

// Element locator utilities
TWebElementLocator = class
public
  class function ByID(ID: string): string; static;
  class function ByXPath(Path: string): string; static;
  class function ByCSS(Selector: string): string; static;
end;

implementation

{ TWebWebElement }

class function TWebWebElement.FindByCSS(
  Session: IBrowserSession; Selector: string): TWebWebElement;
var
  Cmd: TStringList;
begin
  Result.Session := Session;
  Result.FHandle := nil;  // TODO: Query from CDP
  
  // Execute document.querySelector command
  Cmd := TStringList.Create;
  try
    Cmd.Add(fmt('"%s"', [Selector]));
    // Result.FHandle := Session.QueryRoot(Cmd);
  finally
    Cmd.Free;
  end;
end;

class function TWebWebElement.FindByXPath(
  Session: IBrowserSession; XPath: string): TWebWebElement;
begin
  Result.Session := Session;
  Result.FHandle := nil;  // TODO: Query from CDP
end;

procedure TWebWebElement.Click;
var
  Script: string;
begin
  if Assigned(FHandle) then
  begin
    Script := fmt('document.evaluate(%s, document).iterateNext().click()', 
                  [FHandle.Value]);
    FSession.ExecuteScript(Script);
  end
  else
    raise EException.Create('Element handle not initialized');
end;

procedure TWebWebElement.TypeText(Text: string);
begin
  // Clear existing content first
  Click;
  
  // Type text using keyboard events or direct value setting
  var EventInit := FormatRecord('{ bubbles: true, cancelable: true }');
  var SetTextCmd := fmt('this.value = %s; this.dispatchEvent(new KeyboardEvent("input", %s));',
                        [QuotedStr(Text), EventInit]);
                        
  FSession.ExecuteScript(SetTextCmd);
end;

function TWebWebElement.GetAttribute(AttrName: string): string;
begin
  Result := GetAttributeInternal(AttrName);
end;

function TWebWebElement.GetAttributeInternal(AttrName: string): string;
var
  Script: string;
begin
  Script := fmt('return arguments[0].getAttribute(%s);', 
                [QuotedStr(AttrName)]);
  Result := FSession.EvaluateJS(Script, [FHandle]);
end;

function TWebWebElement.GetValue: string;
begin
  Result := GetValueInternal;
end;

function TWebWebElement.GetValueInternal: string;
begin
  Result := GetAttribute('value');
end;

function TWebWebElement.SelectOption(Value: string): Boolean;
begin
  // Only works on <select> elements
  Result := False;
  
  if GetAttribute('tagName') <> 'SELECT' then
    Exit(False);
    
  // Set value and dispatch change event
  TypeText(Value);
  Result := True;
end;

function TWebWebElement.IsVisible: Boolean;
begin
  // Lazy evaluation with caching
  if not FVisibilityChecked then
  begin
    FRectCached := GetRect;
    FVisibilityChecked := True;
  end;
  
  Result := FRectCached.Right > FRectCached.Left and 
            FRectCached.Bottom > FRectCached.Top;
end;

function TWebWebElement.IsEnabled: Boolean;
begin
  Result := LowerCase(GetAttribute('disabled')) <> 'true';
end;

function TWebWebElement.GetRect: TRect;
var
  BoxModel: TJSONObject;
  Box: TJSONArray;
begin
  if not FVisibilityChecked then
  begin
    // Query getBoxModel from CDP
    // BoxModel := FSession.GetElementBoxModel(ToString);
    // Extract bounding box coordinates from model...
    
    FRectCached := Rect(0, 0, 100, 30);  // Placeholder
    FVisibilityChecked := True;
  end;
  
  Result := FRectCached;
end;

function TWebWebElement.GetHTML: string;
begin
  Result := GetAttribute('outerHTML');
end;

function TWebWebElement.FirstChild: TWebWebElement;
begin
  // Navigate to first child node via CDP
  Result := TWebWebElement(); // TODO: Implement traversal
end;

function TWebWebElement.Parent: TWebWebElement;
begin
  // Navigate to parent node
  Result := TWebWebElement(); // TODO: Implement traversal
end;

function TWebWebElement.ChildAt(Index: Integer): TWebWebElement;
begin
  Result := TWebWebElement(); // TODO: Implement indexed access
end;

class operator TWebWebElement.Implicit(
  const Value: TWebWebElement): Variant;
begin
  Result := Value.ToString;
end;

function TWebWebElement.ToString: string;
var
  Attrs: TStringList;
  i: Integer;
begin
  Attrs := TStringList.Create;
  try
    // Extract meaningful attributes
    Attrs.Add(fmt('tag: %s', [GetAttribute('tagName')]));
    
    if GetAttribute('id') <> '' then
      Attrs.Add(fmt('id: %s', [GetAttribute('id')]));
      
    if GetAttribute('class') <> '' then
      Attrs.Add(fmt('class: %s', [GetAttribute('class')]));
      
    Result := '<' + Attrs.CommaText + '>';
  finally
    Attrs.Free;
  end;
end;

{ TWebElementLocator }

class function TWebElementLocator.ByID(ID: string): string;
begin
  Result := '[id="' + ID + '"]';
end;

class function TWebElementLocator.ByXPath(Path: string): string;
begin
  Result := Path;
end;

class function TWebElementLocator.ByCSS(Selector: string): string;
begin
  Result := Selector;
end;

end.
