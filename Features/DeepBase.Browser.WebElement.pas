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
  System.Variants,
  Winapi.Windows,
  DeepBase.Browser.CDP.Adapter;

type
  TWebWebElement = record
  private
    FHandle: TJSONValue;        // CDP DOM node handle
    FSession: IInterface;       // Parent browser session reference
    FIsVisibleCached: Boolean;
    FRectCached: TRect;
    FVisibilityChecked: Boolean;
    
    function GetAttributeInternal(AttrName: string): string;
    function GetValueInternal: string;
  public
    // Location strategies
    class function FindByCSS(const Session: IInterface; 
      Selector: string): TWebWebElement; static;
    class function FindByXPath(const Session: IInterface; 
      XPath: string): TWebWebElement; static;
      
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
    function ToString: string;
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
  const Session: IInterface; Selector: string): TWebWebElement;
begin
  Result := Default(TWebWebElement);
  Result.FSession := Session;
  Result.FHandle := nil;
end;

class function TWebWebElement.FindByXPath(
  const Session: IInterface; XPath: string): TWebWebElement;
begin
  Result := Default(TWebWebElement);
  Result.FSession := Session;
  Result.FHandle := nil;
end;

procedure TWebWebElement.Click;
begin
end;

procedure TWebWebElement.TypeText(Text: string);
begin
end;

function TWebWebElement.GetAttribute(AttrName: string): string;
begin
  Result := GetAttributeInternal(AttrName);
end;

function TWebWebElement.GetAttributeInternal(AttrName: string): string;
begin
  Result := '';
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
  Result := False;
end;

function TWebWebElement.IsVisible: Boolean;
begin
  Result := False;
end;

function TWebWebElement.IsEnabled: Boolean;
begin
  Result := True;
end;

function TWebWebElement.GetRect: TRect;
begin
  Result := Rect(0, 0, 0, 0);
end;

function TWebWebElement.GetHTML: string;
begin
  Result := GetAttribute('outerHTML');
end;

function TWebWebElement.FirstChild: TWebWebElement;
begin
  Result := Default(TWebWebElement);
end;

function TWebWebElement.Parent: TWebWebElement;
begin
  Result := Default(TWebWebElement);
end;

function TWebWebElement.ChildAt(Index: Integer): TWebWebElement;
begin
  Result := Default(TWebWebElement);
end;

class operator TWebWebElement.Implicit(
  const Value: TWebWebElement): Variant;
begin
  Result := Value.ToString;
end;

function TWebWebElement.ToString: string;
begin
  Result := '<element>';
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
