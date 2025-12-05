unit UniBase.Template;

(*******************************************************************************
  UniBase Template Engine
  A flexible string template rendering engine with:
  - Variable substitution: {{variable}}
  - Conditionals: {{#if condition}}...{{else}}...{{/if}}
  - Loops: {{#foreach item in items}}...{{/foreach}}
  - Filters: {{variable | upper | trim}}
  - Includes: {{#include "template.txt"}}
  - Comments: {{! this is a comment }}
  - Raw output: {{{rawVariable}}} (no HTML escaping)
  - Custom functions and filters

  Author: UniBase Team
  Created: 2025-11-28
*******************************************************************************)

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Variants, System.RegularExpressions, System.StrUtils, System.IOUtils,
  System.JSON, System.NetEncoding;

type
  ETemplateException = class(Exception);
  ETemplateParseException = class(ETemplateException);
  ETemplateRenderException = class(ETemplateException);

  /// <summary>Template context for variable resolution</summary>
  ITemplateContext = interface
    ['{A1B2C3D4-1234-5678-9ABC-DEF012345678}']
    function GetValue(const AName: string): Variant;
    function HasValue(const AName: string): Boolean;
    function GetValues: TDictionary<string, Variant>;
    function GetParent: ITemplateContext;
    procedure SetValue(const AName: string; const AValue: Variant);
    property Values: TDictionary<string, Variant> read GetValues;
    property Parent: ITemplateContext read GetParent;
  end;

  /// <summary>Template filter function type</summary>
  TTemplateFilter = reference to function(const AValue: Variant; const AArgs: array of Variant): Variant;

  /// <summary>Template function type</summary>
  TTemplateFunction = reference to function(const AArgs: array of Variant; const AContext: ITemplateContext): Variant;

  /// <summary>Template include resolver</summary>
  TTemplateIncludeResolver = reference to function(const ATemplateName: string): string;

  /// <summary>Template context implementation</summary>
  TTemplateContext = class(TInterfacedObject, ITemplateContext)
  private
    FValues: TDictionary<string, Variant>;
    FParent: ITemplateContext;
    function GetValues: TDictionary<string, Variant>;
    function GetParent: ITemplateContext;
  public
    constructor Create(AParent: ITemplateContext = nil);
    destructor Destroy; override;
    
    function GetValue(const AName: string): Variant;
    function HasValue(const AName: string): Boolean;
    procedure SetValue(const AName: string; const AValue: Variant);
    
    /// <summary>Add value with fluent API</summary>
    function Add(const AName: string; const AValue: Variant): TTemplateContext;
    /// <summary>Add object properties as values</summary>
    function AddObject(const AName: string; AObject: TObject): TTemplateContext;
    /// <summary>Add JSON object as values</summary>
    function AddJSON(const AName: string; AJSON: TJSONObject): TTemplateContext;
    /// <summary>Add dictionary values</summary>
    function AddDictionary(const ADict: TDictionary<string, Variant>): TTemplateContext;
    /// <summary>Create child context</summary>
    function CreateChild: TTemplateContext;
    
    property Values: TDictionary<string, Variant> read GetValues;
    property Parent: ITemplateContext read GetParent;
  end;

  /// <summary>AST node types</summary>
  TTemplateNodeType = (
    ntText,        // Plain text
    ntVariable,    // {{variable}}
    ntRawVariable, // {{{variable}}}
    ntIf,          // {{#if condition}}
    ntElse,        // {{else}}
    ntElseIf,      // {{#elseif condition}}
    ntEndIf,       // {{/if}}
    ntForeach,     // {{#foreach item in items}}
    ntEndForeach,  // {{/foreach}}
    ntInclude,     // {{#include "name"}}
    ntComment,     // {{! comment }}
    ntSet,         // {{#set name = value}}
    ntWith,        // {{#with object}}
    ntEndWith,     // {{/with}}
    ntPartial,     // {{> partial}}
    ntBlock,       // {{#block name}}
    ntEndBlock     // {{/block}}
  );

  TTemplateNode = class;
  TTemplateNodeList = TObjectList<TTemplateNode>;

  /// <summary>Template AST node</summary>
  TTemplateNode = class
  private
    FNodeType: TTemplateNodeType;
    FContent: string;
    FFilters: TArray<string>;
    FChildren: TTemplateNodeList;
    FElseBranch: TTemplateNodeList;
    FVarName: string;
    FCollectionName: string;
    FCondition: string;
    FLine: Integer;
    FColumn: Integer;
  public
    constructor Create(ANodeType: TTemplateNodeType);
    destructor Destroy; override;
    
    property NodeType: TTemplateNodeType read FNodeType;
    property Content: string read FContent write FContent;
    property Filters: TArray<string> read FFilters write FFilters;
    property Children: TTemplateNodeList read FChildren;
    property ElseBranch: TTemplateNodeList read FElseBranch;
    property VarName: string read FVarName write FVarName;
    property CollectionName: string read FCollectionName write FCollectionName;
    property Condition: string read FCondition write FCondition;
    property Line: Integer read FLine write FLine;
    property Column: Integer read FColumn write FColumn;
  end;

  /// <summary>Template parser</summary>
  TTemplateParser = class
  private
    FTemplate: string;
    FPosition: Integer;
    FLine: Integer;
    FColumn: Integer;
    FStartDelimiter: string;
    FEndDelimiter: string;
    
    procedure SkipWhitespace;
    function Peek(ACount: Integer = 1): string;
    function Read(ACount: Integer = 1): string;
    function ReadUntil(const ADelimiter: string): string;
    function ReadIdentifier: string;
    function IsAtEnd: Boolean;
    function ParseTag: TTemplateNode;
    function ParseText: TTemplateNode;
    procedure ParseNodes(ANodes: TTemplateNodeList; const AEndTags: array of string);
    procedure ParseError(const AMessage: string);
  public
    constructor Create;
    
    function Parse(const ATemplate: string): TTemplateNodeList;
    
    property StartDelimiter: string read FStartDelimiter write FStartDelimiter;
    property EndDelimiter: string read FEndDelimiter write FEndDelimiter;
  end;

  /// <summary>Template renderer</summary>
  TTemplateRenderer = class
  private
    FFilters: TDictionary<string, TTemplateFilter>;
    FFunctions: TDictionary<string, TTemplateFunction>;
    FIncludeResolver: TTemplateIncludeResolver;
    FHtmlEscape: Boolean;
    FStrictMode: Boolean;
    FPartials: TDictionary<string, TTemplateNodeList>;
    FBlocks: TDictionary<string, TTemplateNodeList>;
    
    function RenderNodes(const ANodes: TTemplateNodeList; const AContext: ITemplateContext): string;
    function RenderNode(const ANode: TTemplateNode; const AContext: ITemplateContext): string;
    function RenderVariable(const ANode: TTemplateNode; const AContext: ITemplateContext): string;
    function RenderIf(const ANode: TTemplateNode; const AContext: ITemplateContext): string;
    function RenderForeach(const ANode: TTemplateNode; const AContext: ITemplateContext): string;
    function RenderInclude(const ANode: TTemplateNode; const AContext: ITemplateContext): string;
    function RenderWith(const ANode: TTemplateNode; const AContext: ITemplateContext): string;
    function RenderPartial(const ANode: TTemplateNode; const AContext: ITemplateContext): string;
    function RenderBlock(const ANode: TTemplateNode; const AContext: ITemplateContext): string;
    
    function ResolveValue(const APath: string; const AContext: ITemplateContext): Variant;
    function ApplyFilters(const AValue: Variant; const AFilters: TArray<string>; const AContext: ITemplateContext): Variant;
    function EvaluateCondition(const ACondition: string; const AContext: ITemplateContext): Boolean;
    function ParseFilterArgs(const AFilter: string; out AFilterName: string; out AArgs: TArray<Variant>): Boolean;
    function VariantToString(const AValue: Variant): string;
    function HtmlEscapeString(const AValue: string): string;
    function IsTruthy(const AValue: Variant): Boolean;
    
    procedure RegisterBuiltInFilters;
    procedure RegisterBuiltInFunctions;
  public
    constructor Create;
    destructor Destroy; override;
    
    function Render(const ANodes: TTemplateNodeList; const AContext: ITemplateContext): string;
    
    /// <summary>Register custom filter</summary>
    procedure RegisterFilter(const AName: string; AFilter: TTemplateFilter);
    /// <summary>Register custom function</summary>
    procedure RegisterFunction(const AName: string; AFunc: TTemplateFunction);
    /// <summary>Register partial template</summary>
    procedure RegisterPartial(const AName: string; const ATemplate: string);
    /// <summary>Register block content</summary>
    procedure RegisterBlock(const AName: string; const ANodes: TTemplateNodeList);
    
    property IncludeResolver: TTemplateIncludeResolver read FIncludeResolver write FIncludeResolver;
    property HtmlEscape: Boolean read FHtmlEscape write FHtmlEscape;
    property StrictMode: Boolean read FStrictMode write FStrictMode;
  end;

  /// <summary>Main template engine class</summary>
  TTemplateEngine = class
  private
    FParser: TTemplateParser;
    FRenderer: TTemplateRenderer;
    FCache: TDictionary<string, TTemplateNodeList>;
    FCacheEnabled: Boolean;
    FBasePath: string;
    
    function GetCachedTemplate(const ATemplate: string): TTemplateNodeList;
    function DefaultIncludeResolver(const ATemplateName: string): string;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Render template string with context</summary>
    function Render(const ATemplate: string; const AContext: ITemplateContext): string; overload;
    /// <summary>Render template string with dictionary</summary>
    function Render(const ATemplate: string; const AValues: TDictionary<string, Variant>): string; overload;
    /// <summary>Render template string with name-value pairs</summary>
    function Render(const ATemplate: string; const ANames: array of string; const AValues: array of Variant): string; overload;
    
    /// <summary>Render template file with context</summary>
    function RenderFile(const AFileName: string; const AContext: ITemplateContext): string; overload;
    /// <summary>Render template file with dictionary</summary>
    function RenderFile(const AFileName: string; const AValues: TDictionary<string, Variant>): string; overload;
    
    /// <summary>Parse template without rendering</summary>
    function Parse(const ATemplate: string): TTemplateNodeList;
    
    /// <summary>Register custom filter</summary>
    procedure RegisterFilter(const AName: string; AFilter: TTemplateFilter);
    /// <summary>Register custom function</summary>
    procedure RegisterFunction(const AName: string; AFunc: TTemplateFunction);
    /// <summary>Register partial template</summary>
    procedure RegisterPartial(const AName: string; const ATemplate: string);
    
    /// <summary>Clear template cache</summary>
    procedure ClearCache;
    
    /// <summary>Set custom delimiters</summary>
    procedure SetDelimiters(const AStart, AEnd: string);
    
    /// <summary>Set include resolver</summary>
    procedure SetIncludeResolver(AResolver: TTemplateIncludeResolver);
    
    property CacheEnabled: Boolean read FCacheEnabled write FCacheEnabled;
    property BasePath: string read FBasePath write FBasePath;
  private
    function GetHtmlEscape: Boolean;
    procedure SetHtmlEscape(Value: Boolean);
    function GetStrictMode: Boolean;
    procedure SetStrictMode(Value: Boolean);
  public
    property HtmlEscape: Boolean read GetHtmlEscape write SetHtmlEscape;
    property StrictMode: Boolean read GetStrictMode write SetStrictMode;
  end;

  /// <summary>Static template helper class</summary>
  TTemplate = class
  private
    class var FInstance: TTemplateEngine;
    class function GetInstance: TTemplateEngine; static;
  public
    class destructor Destroy;
    
    /// <summary>Quick render template with name-value pairs</summary>
    class function Render(const ATemplate: string; const ANames: array of string; const AValues: array of Variant): string; overload;
    /// <summary>Quick render template with dictionary</summary>
    class function Render(const ATemplate: string; const AValues: TDictionary<string, Variant>): string; overload;
    /// <summary>Quick render template with context</summary>
    class function Render(const ATemplate: string; const AContext: ITemplateContext): string; overload;
    
    /// <summary>Create new context</summary>
    class function CreateContext: TTemplateContext;
    
    /// <summary>Register global filter</summary>
    class procedure RegisterFilter(const AName: string; AFilter: TTemplateFilter);
    /// <summary>Register global function</summary>
    class procedure RegisterFunction(const AName: string; AFunc: TTemplateFunction);
    
    /// <summary>Get global engine instance</summary>
    class property Instance: TTemplateEngine read GetInstance;
  end;

implementation

uses
  System.TypInfo, System.RTTI, System.Math;

{ TTemplateContext }

constructor TTemplateContext.Create(AParent: ITemplateContext);
begin
  inherited Create;
  FValues := TDictionary<string, Variant>.Create;
  FParent := AParent;
end;

destructor TTemplateContext.Destroy;
begin
  FValues.Free;
  inherited;
end;

function TTemplateContext.GetValues: TDictionary<string, Variant>;
begin
  Result := FValues;
end;

function TTemplateContext.GetParent: ITemplateContext;
begin
  Result := FParent;
end;

function TTemplateContext.GetValue(const AName: string): Variant;
begin
  if FValues.TryGetValue(AName, Result) then
    Exit;
  if Assigned(FParent) then
    Result := FParent.GetValue(AName)
  else
    Result := Null;
end;

function TTemplateContext.HasValue(const AName: string): Boolean;
begin
  Result := FValues.ContainsKey(AName);
  if (not Result) and Assigned(FParent) then
    Result := FParent.HasValue(AName);
end;

procedure TTemplateContext.SetValue(const AName: string; const AValue: Variant);
begin
  FValues.AddOrSetValue(AName, AValue);
end;

function TTemplateContext.Add(const AName: string; const AValue: Variant): TTemplateContext;
begin
  FValues.AddOrSetValue(AName, AValue);
  Result := Self;
end;

function TTemplateContext.AddObject(const AName: string; AObject: TObject): TTemplateContext;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LPrefix: string;
begin
  if not Assigned(AObject) then
    Exit(Self);
    
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(AObject.ClassType);
    if not Assigned(LType) then
      Exit(Self);
      
    if AName <> '' then
      LPrefix := AName + '.'
    else
      LPrefix := '';
      
    for LProp in LType.GetProperties do
    begin
      if LProp.IsReadable then
      begin
        try
          FValues.AddOrSetValue(LPrefix + LProp.Name, LProp.GetValue(AObject).AsVariant);
        except
          // Skip properties that cannot be converted to Variant
        end;
      end;
    end;
  finally
    LContext.Free;
  end;
  Result := Self;
end;

function TTemplateContext.AddJSON(const AName: string; AJSON: TJSONObject): TTemplateContext;
var
  LPair: TJSONPair;
  LPrefix: string;
begin
  if not Assigned(AJSON) then
    Exit(Self);
    
  if AName <> '' then
    LPrefix := AName + '.'
  else
    LPrefix := '';
    
  for LPair in AJSON do
  begin
    if LPair.JsonValue is TJSONString then
      FValues.AddOrSetValue(LPrefix + LPair.JsonString.Value, TJSONString(LPair.JsonValue).Value)
    else if LPair.JsonValue is TJSONNumber then
      FValues.AddOrSetValue(LPrefix + LPair.JsonString.Value, TJSONNumber(LPair.JsonValue).AsDouble)
    else if LPair.JsonValue is TJSONBool then
      FValues.AddOrSetValue(LPrefix + LPair.JsonString.Value, TJSONBool(LPair.JsonValue).AsBoolean)
    else if LPair.JsonValue is TJSONNull then
      FValues.AddOrSetValue(LPrefix + LPair.JsonString.Value, Null)
    else if LPair.JsonValue is TJSONObject then
      AddJSON(LPrefix + LPair.JsonString.Value, TJSONObject(LPair.JsonValue));
  end;
  Result := Self;
end;

function TTemplateContext.AddDictionary(const ADict: TDictionary<string, Variant>): TTemplateContext;
var
  LPair: TPair<string, Variant>;
begin
  for LPair in ADict do
    FValues.AddOrSetValue(LPair.Key, LPair.Value);
  Result := Self;
end;

function TTemplateContext.CreateChild: TTemplateContext;
begin
  Result := TTemplateContext.Create(Self);
end;

{ TTemplateNode }

constructor TTemplateNode.Create(ANodeType: TTemplateNodeType);
begin
  inherited Create;
  FNodeType := ANodeType;
  FChildren := TTemplateNodeList.Create(True);
  FElseBranch := TTemplateNodeList.Create(True);
end;

destructor TTemplateNode.Destroy;
begin
  FChildren.Free;
  FElseBranch.Free;
  inherited;
end;

{ TTemplateParser }

constructor TTemplateParser.Create;
begin
  inherited;
  FStartDelimiter := '{{';
  FEndDelimiter := '}}';
end;

procedure TTemplateParser.SkipWhitespace;
begin
  while (FPosition <= Length(FTemplate)) and CharInSet(FTemplate[FPosition], [' ', #9]) do
  begin
    Inc(FPosition);
    Inc(FColumn);
  end;
end;

function TTemplateParser.Peek(ACount: Integer): string;
begin
  if FPosition + ACount - 1 <= Length(FTemplate) then
    Result := Copy(FTemplate, FPosition, ACount)
  else
    Result := '';
end;

function TTemplateParser.Read(ACount: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to ACount do
  begin
    if FPosition <= Length(FTemplate) then
    begin
      Result := Result + FTemplate[FPosition];
      if FTemplate[FPosition] = #10 then
      begin
        Inc(FLine);
        FColumn := 1;
      end
      else
        Inc(FColumn);
      Inc(FPosition);
    end;
  end;
end;

function TTemplateParser.ReadUntil(const ADelimiter: string): string;
var
  LDelimLen: Integer;
begin
  Result := '';
  LDelimLen := Length(ADelimiter);
  while not IsAtEnd do
  begin
    if Peek(LDelimLen) = ADelimiter then
      Break;
    Result := Result + Read(1);
  end;
end;

function TTemplateParser.ReadIdentifier: string;
begin
  Result := '';
  SkipWhitespace;
  while (FPosition <= Length(FTemplate)) and 
        (CharInSet(FTemplate[FPosition], ['a'..'z', 'A'..'Z', '0'..'9', '_', '.', '[', ']'])) do
  begin
    Result := Result + FTemplate[FPosition];
    Inc(FPosition);
    Inc(FColumn);
  end;
end;

function TTemplateParser.IsAtEnd: Boolean;
begin
  Result := FPosition > Length(FTemplate);
end;

procedure TTemplateParser.ParseError(const AMessage: string);
begin
  raise ETemplateParseException.CreateFmt('Parse error at line %d, column %d: %s', 
    [FLine, FColumn, AMessage]);
end;

function TTemplateParser.ParseTag: TTemplateNode;
var
  LContent, LCmd, LPart1, LPart2, LPart3: string;
  LFilters: TArray<string>;
  LFilterParts: TArray<string>;
  I: Integer;
  LIsRaw: Boolean;
begin
  Result := nil;
  
  // Read opening delimiter
  if Peek(3) = '{{{' then
  begin
    Read(3);
    LIsRaw := True;
  end
  else
  begin
    Read(Length(FStartDelimiter));
    LIsRaw := False;
  end;
  
  SkipWhitespace;
  
  // Check for special tag types
  if Peek(1) = '!' then
  begin
    // Comment tag: {{! comment }}
    Read(1);
    LContent := ReadUntil(FEndDelimiter);
    if LIsRaw then
      Read(3)
    else
      Read(Length(FEndDelimiter));
    Result := TTemplateNode.Create(ntComment);
    Result.Content := Trim(LContent);
    Exit;
  end;
  
  if Peek(1) = '#' then
  begin
    // Block tag
    Read(1);
    LCmd := ReadIdentifier;
    SkipWhitespace;
    
    if SameText(LCmd, 'if') or SameText(LCmd, 'elseif') then
    begin
      LContent := Trim(ReadUntil(FEndDelimiter));
      Read(Length(FEndDelimiter));
      if SameText(LCmd, 'if') then
        Result := TTemplateNode.Create(ntIf)
      else
        Result := TTemplateNode.Create(ntElseIf);
      Result.Condition := LContent;
      Exit;
    end;
    
    if SameText(LCmd, 'foreach') or SameText(LCmd, 'each') or SameText(LCmd, 'for') then
    begin
      // Parse: item in collection
      LPart1 := ReadIdentifier;
      SkipWhitespace;
      LPart2 := ReadIdentifier; // 'in'
      SkipWhitespace;
      LPart3 := ReadIdentifier;
      Read(Length(FEndDelimiter));
      
      Result := TTemplateNode.Create(ntForeach);
      Result.VarName := LPart1;
      Result.CollectionName := LPart3;
      Exit;
    end;
    
    if SameText(LCmd, 'include') then
    begin
      SkipWhitespace;
      // Read quoted string or identifier
      if Peek(1) = '"' then
      begin
        Read(1);
        LContent := ReadUntil('"');
        Read(1);
      end
      else
        LContent := ReadIdentifier;
      SkipWhitespace;
      Read(Length(FEndDelimiter));
      
      Result := TTemplateNode.Create(ntInclude);
      Result.Content := LContent;
      Exit;
    end;
    
    if SameText(LCmd, 'set') then
    begin
      LPart1 := ReadIdentifier;
      SkipWhitespace;
      if Peek(1) = '=' then
        Read(1);
      SkipWhitespace;
      LContent := Trim(ReadUntil(FEndDelimiter));
      Read(Length(FEndDelimiter));
      
      Result := TTemplateNode.Create(ntSet);
      Result.VarName := LPart1;
      Result.Content := LContent;
      Exit;
    end;
    
    if SameText(LCmd, 'with') then
    begin
      LContent := Trim(ReadUntil(FEndDelimiter));
      Read(Length(FEndDelimiter));
      
      Result := TTemplateNode.Create(ntWith);
      Result.Content := LContent;
      Exit;
    end;
    
    if SameText(LCmd, 'block') then
    begin
      LContent := Trim(ReadUntil(FEndDelimiter));
      Read(Length(FEndDelimiter));
      
      Result := TTemplateNode.Create(ntBlock);
      Result.Content := LContent;
      Exit;
    end;
    
    ParseError('Unknown block command: ' + LCmd);
  end;
  
  if Peek(1) = '/' then
  begin
    // End tag
    Read(1);
    LCmd := ReadIdentifier;
    Read(Length(FEndDelimiter));
    
    if SameText(LCmd, 'if') then
      Result := TTemplateNode.Create(ntEndIf)
    else if SameText(LCmd, 'foreach') or SameText(LCmd, 'each') or SameText(LCmd, 'for') then
      Result := TTemplateNode.Create(ntEndForeach)
    else if SameText(LCmd, 'with') then
      Result := TTemplateNode.Create(ntEndWith)
    else if SameText(LCmd, 'block') then
      Result := TTemplateNode.Create(ntEndBlock)
    else
      ParseError('Unknown end tag: ' + LCmd);
    Exit;
  end;
  
  if SameText(Peek(4), 'else') then
  begin
    Read(4);
    SkipWhitespace;
    // Check for elseif
    if SameText(Peek(2), 'if') then
    begin
      Read(2);
      SkipWhitespace;
      LContent := Trim(ReadUntil(FEndDelimiter));
      Read(Length(FEndDelimiter));
      Result := TTemplateNode.Create(ntElseIf);
      Result.Condition := LContent;
    end
    else
    begin
      Read(Length(FEndDelimiter));
      Result := TTemplateNode.Create(ntElse);
    end;
    Exit;
  end;
  
  if Peek(1) = '>' then
  begin
    // Partial: {{> partial}}
    Read(1);
    SkipWhitespace;
    LContent := Trim(ReadUntil(FEndDelimiter));
    Read(Length(FEndDelimiter));
    Result := TTemplateNode.Create(ntPartial);
    Result.Content := LContent;
    Exit;
  end;
  
  // Variable tag with optional filters
  if LIsRaw then
  begin
    LContent := Trim(ReadUntil('}}}'));
    Read(3);
  end
  else
  begin
    LContent := Trim(ReadUntil(FEndDelimiter));
    Read(Length(FEndDelimiter));
  end;
  
  // Parse filters: variable | filter1 | filter2(arg)
  LFilterParts := LContent.Split(['|']);
  
  if LIsRaw then
    Result := TTemplateNode.Create(ntRawVariable)
  else
    Result := TTemplateNode.Create(ntVariable);
    
  Result.Content := Trim(LFilterParts[0]);
  
  if Length(LFilterParts) > 1 then
  begin
    SetLength(LFilters, Length(LFilterParts) - 1);
    for I := 1 to High(LFilterParts) do
      LFilters[I - 1] := Trim(LFilterParts[I]);
    Result.Filters := LFilters;
  end;
end;

function TTemplateParser.ParseText: TTemplateNode;
var
  LText: string;
  LStartLen: Integer;
begin
  LStartLen := Length(FStartDelimiter);
  LText := '';
  
  while not IsAtEnd do
  begin
    // Check for triple brace first
    if Peek(3) = '{{{' then
      Break;
    if Peek(LStartLen) = FStartDelimiter then
      Break;
    LText := LText + Read(1);
  end;
  
  if LText = '' then
    Result := nil
  else
  begin
    Result := TTemplateNode.Create(ntText);
    Result.Content := LText;
  end;
end;

procedure TTemplateParser.ParseNodes(ANodes: TTemplateNodeList; const AEndTags: array of string);
var
  LNode: TTemplateNode;
  LStartLen: Integer;
  
  function IsEndTag(ANode: TTemplateNode): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    for I := Low(AEndTags) to High(AEndTags) do
    begin
      if SameText(AEndTags[I], 'endif') and (ANode.NodeType = ntEndIf) then
        Exit(True);
      if SameText(AEndTags[I], 'endforeach') and (ANode.NodeType = ntEndForeach) then
        Exit(True);
      if SameText(AEndTags[I], 'endwith') and (ANode.NodeType = ntEndWith) then
        Exit(True);
      if SameText(AEndTags[I], 'endblock') and (ANode.NodeType = ntEndBlock) then
        Exit(True);
      if SameText(AEndTags[I], 'else') and (ANode.NodeType = ntElse) then
        Exit(True);
      if SameText(AEndTags[I], 'elseif') and (ANode.NodeType = ntElseIf) then
        Exit(True);
    end;
  end;
  
begin
  LStartLen := Length(FStartDelimiter);
  
  while not IsAtEnd do
  begin
    // Check for tag
    if (Peek(3) = '{{{') or (Peek(LStartLen) = FStartDelimiter) then
    begin
      LNode := ParseTag;
      if Assigned(LNode) then
      begin
        LNode.Line := FLine;
        LNode.Column := FColumn;
        
        // Check for end tags
        if IsEndTag(LNode) then
        begin
          LNode.Free;
          Break;
        end;
        
        // Handle if blocks
        if LNode.NodeType = ntIf then
        begin
          ParseNodes(LNode.Children, ['else', 'elseif', 'endif']);
          // Check for else/elseif
          while not IsAtEnd do
          begin
            if (Peek(3) = '{{{') or (Peek(LStartLen) = FStartDelimiter) then
            begin
              var LNextNode := ParseTag;
              if Assigned(LNextNode) then
              begin
                if LNextNode.NodeType = ntElse then
                begin
                  LNextNode.Free;
                  ParseNodes(LNode.ElseBranch, ['endif']);
                  Break;
                end
                else if LNextNode.NodeType = ntElseIf then
                begin
                  // Add elseif as child of else branch
                  ParseNodes(LNextNode.Children, ['else', 'elseif', 'endif']);
                  LNode.ElseBranch.Add(LNextNode);
                  // Continue checking for more elseif or else
                end
                else if LNextNode.NodeType = ntEndIf then
                begin
                  LNextNode.Free;
                  Break;
                end
                else
                begin
                  LNextNode.Free;
                  Break;
                end;
              end;
            end
            else
              Break;
          end;
        end
        // Handle foreach blocks
        else if LNode.NodeType = ntForeach then
        begin
          ParseNodes(LNode.Children, ['endforeach']);
        end
        // Handle with blocks
        else if LNode.NodeType = ntWith then
        begin
          ParseNodes(LNode.Children, ['endwith']);
        end
        // Handle block definitions
        else if LNode.NodeType = ntBlock then
        begin
          ParseNodes(LNode.Children, ['endblock']);
        end;
        
        ANodes.Add(LNode);
      end;
    end
    else
    begin
      // Parse text
      LNode := ParseText;
      if Assigned(LNode) then
        ANodes.Add(LNode);
    end;
  end;
end;

function TTemplateParser.Parse(const ATemplate: string): TTemplateNodeList;
begin
  FTemplate := ATemplate;
  FPosition := 1;
  FLine := 1;
  FColumn := 1;
  
  Result := TTemplateNodeList.Create(True);
  try
    ParseNodes(Result, []);
  except
    Result.Free;
    raise;
  end;
end;

{ TTemplateRenderer }

constructor TTemplateRenderer.Create;
begin
  inherited;
  FFilters := TDictionary<string, TTemplateFilter>.Create;
  FFunctions := TDictionary<string, TTemplateFunction>.Create;
  FPartials := TDictionary<string, TTemplateNodeList>.Create;
  FBlocks := TDictionary<string, TTemplateNodeList>.Create;
  FHtmlEscape := True;
  FStrictMode := False;
  
  RegisterBuiltInFilters;
  RegisterBuiltInFunctions;
end;

destructor TTemplateRenderer.Destroy;
var
  LPair: TPair<string, TTemplateNodeList>;
begin
  FFilters.Free;
  FFunctions.Free;
  
  for LPair in FPartials do
    LPair.Value.Free;
  FPartials.Free;
  
  for LPair in FBlocks do
    LPair.Value.Free;
  FBlocks.Free;
  
  inherited;
end;

procedure TTemplateRenderer.RegisterBuiltInFilters;
begin
  // String filters
  RegisterFilter('upper', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      Result := UpperCase(VarToStr(AValue));
    end);
    
  RegisterFilter('lower', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      Result := LowerCase(VarToStr(AValue));
    end);
    
  RegisterFilter('capitalize', function(const AValue: Variant; const AArgs: array of Variant): Variant
    var
      S: string;
    begin
      S := VarToStr(AValue);
      if S <> '' then
        S := UpperCase(S[1]) + LowerCase(Copy(S, 2));
      Result := S;
    end);
    
  RegisterFilter('title', function(const AValue: Variant; const AArgs: array of Variant): Variant
    var
      S: string;
      Words: TArray<string>;
      I: Integer;
    begin
      S := VarToStr(AValue);
      Words := S.Split([' ']);
      for I := 0 to High(Words) do
        if Words[I] <> '' then
          Words[I] := UpperCase(Words[I][1]) + LowerCase(Copy(Words[I], 2));
      Result := string.Join(' ', Words);
    end);
    
  RegisterFilter('trim', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      Result := Trim(VarToStr(AValue));
    end);
    
  RegisterFilter('ltrim', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      Result := TrimLeft(VarToStr(AValue));
    end);
    
  RegisterFilter('rtrim', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      Result := TrimRight(VarToStr(AValue));
    end);
    
  RegisterFilter('truncate', function(const AValue: Variant; const AArgs: array of Variant): Variant
    var
      S: string;
      Len: Integer;
      Suffix: string;
    begin
      S := VarToStr(AValue);
      Len := 50;
      Suffix := '...';
      if Length(AArgs) > 0 then
        Len := AArgs[0];
      if Length(AArgs) > 1 then
        Suffix := VarToStr(AArgs[1]);
      if Length(S) > Len then
        S := Copy(S, 1, Len) + Suffix;
      Result := S;
    end);
    
  RegisterFilter('replace', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      if Length(AArgs) >= 2 then
        Result := StringReplace(VarToStr(AValue), VarToStr(AArgs[0]), VarToStr(AArgs[1]), [rfReplaceAll])
      else
        Result := AValue;
    end);
    
  RegisterFilter('split', function(const AValue: Variant; const AArgs: array of Variant): Variant
    var
      Delim: string;
    begin
      Delim := ',';
      if Length(AArgs) > 0 then
        Delim := VarToStr(AArgs[0]);
      Result := VarToStr(AValue).Split([Delim]);
    end);
    
  RegisterFilter('join', function(const AValue: Variant; const AArgs: array of Variant): Variant
    var
      Delim: string;
      Arr: Variant;
      I: Integer;
      S: string;
    begin
      Delim := ', ';
      if Length(AArgs) > 0 then
        Delim := VarToStr(AArgs[0]);
      if VarIsArray(AValue) then
      begin
        S := '';
        for I := VarArrayLowBound(AValue, 1) to VarArrayHighBound(AValue, 1) do
        begin
          if S <> '' then
            S := S + Delim;
          S := S + VarToStr(AValue[I]);
        end;
        Result := S;
      end
      else
        Result := AValue;
    end);
    
  // Number filters
  RegisterFilter('abs', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      Result := Abs(Double(AValue));
    end);
    
  RegisterFilter('round', function(const AValue: Variant; const AArgs: array of Variant): Variant
    var
      Decimals: Integer;
    begin
      Decimals := 0;
      if Length(AArgs) > 0 then
        Decimals := AArgs[0];
      Result := RoundTo(Double(AValue), -Decimals);
    end);
    
  RegisterFilter('floor', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      Result := Floor(Double(AValue));
    end);
    
  RegisterFilter('ceil', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      Result := Ceil(Double(AValue));
    end);
    
  RegisterFilter('format', function(const AValue: Variant; const AArgs: array of Variant): Variant
    var
      Fmt: string;
    begin
      Fmt := '%s';
      if Length(AArgs) > 0 then
        Fmt := VarToStr(AArgs[0]);
      Result := Format(Fmt, [AValue]);
    end);
    
  RegisterFilter('number', function(const AValue: Variant; const AArgs: array of Variant): Variant
    var
      Decimals: Integer;
    begin
      Decimals := 0;
      if Length(AArgs) > 0 then
        Decimals := AArgs[0];
      Result := FormatFloat('#,##0.' + StringOfChar('0', Decimals), Double(AValue));
    end);
    
  // Date filters
  RegisterFilter('date', function(const AValue: Variant; const AArgs: array of Variant): Variant
    var
      Fmt: string;
    begin
      Fmt := 'yyyy-mm-dd';
      if Length(AArgs) > 0 then
        Fmt := VarToStr(AArgs[0]);
      Result := FormatDateTime(Fmt, VarToDateTime(AValue));
    end);
    
  RegisterFilter('time', function(const AValue: Variant; const AArgs: array of Variant): Variant
    var
      Fmt: string;
    begin
      Fmt := 'hh:nn:ss';
      if Length(AArgs) > 0 then
        Fmt := VarToStr(AArgs[0]);
      Result := FormatDateTime(Fmt, VarToDateTime(AValue));
    end);
    
  RegisterFilter('datetime', function(const AValue: Variant; const AArgs: array of Variant): Variant
    var
      Fmt: string;
    begin
      Fmt := 'yyyy-mm-dd hh:nn:ss';
      if Length(AArgs) > 0 then
        Fmt := VarToStr(AArgs[0]);
      Result := FormatDateTime(Fmt, VarToDateTime(AValue));
    end);
    
  // Collection filters
  RegisterFilter('length', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      if VarIsArray(AValue) then
        Result := VarArrayHighBound(AValue, 1) - VarArrayLowBound(AValue, 1) + 1
      else if VarIsStr(AValue) then
        Result := Length(VarToStr(AValue))
      else
        Result := 0;
    end);
    
  RegisterFilter('first', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      if VarIsArray(AValue) then
        Result := AValue[VarArrayLowBound(AValue, 1)]
      else if VarIsStr(AValue) then
      begin
        var S := VarToStr(AValue);
        if S <> '' then
          Result := S[1]
        else
          Result := '';
      end
      else
        Result := AValue;
    end);
    
  RegisterFilter('last', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      if VarIsArray(AValue) then
        Result := AValue[VarArrayHighBound(AValue, 1)]
      else if VarIsStr(AValue) then
      begin
        var S := VarToStr(AValue);
        if S <> '' then
          Result := S[Length(S)]
        else
          Result := '';
      end
      else
        Result := AValue;
    end);
    
  RegisterFilter('reverse', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      if VarIsStr(AValue) then
        Result := ReverseString(VarToStr(AValue))
      else
        Result := AValue;
    end);
    
  // Boolean/conditional filters
  RegisterFilter('default', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      if VarIsNull(AValue) or VarIsEmpty(AValue) or (VarToStr(AValue) = '') then
      begin
        if Length(AArgs) > 0 then
          Result := AArgs[0]
        else
          Result := '';
      end
      else
        Result := AValue;
    end);
    
  RegisterFilter('escape', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      Result := TNetEncoding.HTML.Encode(VarToStr(AValue));
    end);
    
  RegisterFilter('raw', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      Result := AValue; // No escaping
    end);
    
  RegisterFilter('nl2br', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      Result := StringReplace(VarToStr(AValue), #13#10, '<br/>', [rfReplaceAll]);
      Result := StringReplace(VarToStr(Result), #10, '<br/>', [rfReplaceAll]);
    end);
    
  RegisterFilter('json', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      if VarIsStr(AValue) then
        Result := '"' + StringReplace(StringReplace(VarToStr(AValue), '\', '\\', [rfReplaceAll]), '"', '\"', [rfReplaceAll]) + '"'
      else
        Result := VarToStr(AValue);
    end);
    
  RegisterFilter('urlencode', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      Result := TNetEncoding.URL.Encode(VarToStr(AValue));
    end);
    
  RegisterFilter('base64', function(const AValue: Variant; const AArgs: array of Variant): Variant
    begin
      Result := TNetEncoding.Base64.Encode(VarToStr(AValue));
    end);
end;

procedure TTemplateRenderer.RegisterBuiltInFunctions;
begin
  RegisterFunction('now', function(const AArgs: array of Variant; const AContext: ITemplateContext): Variant
    begin
      Result := Now;
    end);
    
  RegisterFunction('today', function(const AArgs: array of Variant; const AContext: ITemplateContext): Variant
    begin
      Result := Date;
    end);
    
  RegisterFunction('random', function(const AArgs: array of Variant; const AContext: ITemplateContext): Variant
    var
      Min, Max: Integer;
    begin
      Min := 0;
      Max := MaxInt;
      if Length(AArgs) > 0 then
        Max := AArgs[0];
      if Length(AArgs) > 1 then
      begin
        Min := AArgs[0];
        Max := AArgs[1];
      end;
      Result := Min + Random(Max - Min + 1);
    end);
    
  RegisterFunction('range', function(const AArgs: array of Variant; const AContext: ITemplateContext): Variant
    var
      Start, Stop, Step, I, Idx: Integer;
      Arr: Variant;
    begin
      Start := 0;
      Stop := 10;
      Step := 1;
      
      if Length(AArgs) >= 1 then
        Stop := AArgs[0];
      if Length(AArgs) >= 2 then
      begin
        Start := AArgs[0];
        Stop := AArgs[1];
      end;
      if Length(AArgs) >= 3 then
        Step := AArgs[2];
        
      if Step = 0 then
        Step := 1;
        
      Arr := VarArrayCreate([0, Abs((Stop - Start) div Step)], varInteger);
      Idx := 0;
      I := Start;
      while (Step > 0) and (I < Stop) or (Step < 0) and (I > Stop) do
      begin
        Arr[Idx] := I;
        Inc(Idx);
        Inc(I, Step);
      end;
      Result := Arr;
    end);
    
  RegisterFunction('concat', function(const AArgs: array of Variant; const AContext: ITemplateContext): Variant
    var
      I: Integer;
      S: string;
    begin
      S := '';
      for I := 0 to High(AArgs) do
        S := S + VarToStr(AArgs[I]);
      Result := S;
    end);
    
  RegisterFunction('iif', function(const AArgs: array of Variant; const AContext: ITemplateContext): Variant
    begin
      if Length(AArgs) >= 3 then
      begin
        if AArgs[0] then
          Result := AArgs[1]
        else
          Result := AArgs[2];
      end
      else
        Result := Null;
    end);
end;

procedure TTemplateRenderer.RegisterFilter(const AName: string; AFilter: TTemplateFilter);
begin
  FFilters.AddOrSetValue(LowerCase(AName), AFilter);
end;

procedure TTemplateRenderer.RegisterFunction(const AName: string; AFunc: TTemplateFunction);
begin
  FFunctions.AddOrSetValue(LowerCase(AName), AFunc);
end;

procedure TTemplateRenderer.RegisterPartial(const AName: string; const ATemplate: string);
var
  LParser: TTemplateParser;
begin
  LParser := TTemplateParser.Create;
  try
    if FPartials.ContainsKey(AName) then
      FPartials[AName].Free;
    FPartials.AddOrSetValue(AName, LParser.Parse(ATemplate));
  finally
    LParser.Free;
  end;
end;

procedure TTemplateRenderer.RegisterBlock(const AName: string; const ANodes: TTemplateNodeList);
begin
  if not FBlocks.ContainsKey(AName) then
    FBlocks.Add(AName, ANodes);
end;

function TTemplateRenderer.Render(const ANodes: TTemplateNodeList; const AContext: ITemplateContext): string;
begin
  Result := RenderNodes(ANodes, AContext);
end;

function TTemplateRenderer.RenderNodes(const ANodes: TTemplateNodeList; const AContext: ITemplateContext): string;
var
  LNode: TTemplateNode;
begin
  Result := '';
  for LNode in ANodes do
    Result := Result + RenderNode(LNode, AContext);
end;

function TTemplateRenderer.RenderNode(const ANode: TTemplateNode; const AContext: ITemplateContext): string;
begin
  case ANode.NodeType of
    ntText:
      Result := ANode.Content;
    ntVariable:
      Result := RenderVariable(ANode, AContext);
    ntRawVariable:
      Result := RenderVariable(ANode, AContext);
    ntIf:
      Result := RenderIf(ANode, AContext);
    ntForeach:
      Result := RenderForeach(ANode, AContext);
    ntInclude:
      Result := RenderInclude(ANode, AContext);
    ntComment:
      Result := ''; // Comments produce no output
    ntSet:
      begin
        var LValue := ResolveValue(ANode.Content, AContext);
        AContext.SetValue(ANode.VarName, LValue);
        Result := '';
      end;
    ntWith:
      Result := RenderWith(ANode, AContext);
    ntPartial:
      Result := RenderPartial(ANode, AContext);
    ntBlock:
      Result := RenderBlock(ANode, AContext);
  else
    Result := '';
  end;
end;

function TTemplateRenderer.RenderVariable(const ANode: TTemplateNode; const AContext: ITemplateContext): string;
var
  LValue: Variant;
begin
  // Check if it's a function call
  if Pos('(', ANode.Content) > 0 then
  begin
    var LFuncName := Copy(ANode.Content, 1, Pos('(', ANode.Content) - 1);
    var LArgsStr := Copy(ANode.Content, Pos('(', ANode.Content) + 1);
    LArgsStr := Copy(LArgsStr, 1, Length(LArgsStr) - 1); // Remove closing )
    
    var LFunc: TTemplateFunction;
    if FFunctions.TryGetValue(LowerCase(LFuncName), LFunc) then
    begin
      // Parse arguments (simplified - just split by comma for now)
      var LArgStrings := LArgsStr.Split([',']);
      var LArgs: TArray<Variant>;
      SetLength(LArgs, Length(LArgStrings));
      for var I := 0 to High(LArgStrings) do
      begin
        var LArg := Trim(LArgStrings[I]);
        var LInt: Integer;
        var LFloat: Double;
        if LArg = '' then
          LArgs[I] := Null
        else if (LArg[1] = '"') or (LArg[1] = '''') then
          LArgs[I] := Copy(LArg, 2, Length(LArg) - 2)
        else if TryStrToInt(LArg, LInt) then
          LArgs[I] := LInt
        else if TryStrToFloat(LArg, LFloat) then
          LArgs[I] := LFloat
        else
          LArgs[I] := ResolveValue(LArg, AContext);
      end;
      LValue := LFunc(LArgs, AContext);
    end
    else
      LValue := Null;
  end
  else
    LValue := ResolveValue(ANode.Content, AContext);
  
  // Apply filters
  if Length(ANode.Filters) > 0 then
    LValue := ApplyFilters(LValue, ANode.Filters, AContext);
  
  Result := VariantToString(LValue);
  
  // HTML escape unless raw
  if FHtmlEscape and (ANode.NodeType <> ntRawVariable) then
    Result := HtmlEscapeString(Result);
end;

function TTemplateRenderer.RenderIf(const ANode: TTemplateNode; const AContext: ITemplateContext): string;
var
  LConditionMet: Boolean;
  LElseNode: TTemplateNode;
begin
  LConditionMet := EvaluateCondition(ANode.Condition, AContext);
  
  if LConditionMet then
    Result := RenderNodes(ANode.Children, AContext)
  else if ANode.ElseBranch.Count > 0 then
  begin
    // Check for elseif nodes
    for LElseNode in ANode.ElseBranch do
    begin
      if LElseNode.NodeType = ntElseIf then
      begin
        if EvaluateCondition(LElseNode.Condition, AContext) then
        begin
          Result := RenderNodes(LElseNode.Children, AContext);
          Exit;
        end;
      end
      else
      begin
        // Regular else content
        Result := RenderNode(LElseNode, AContext);
      end;
    end;
    // If no elseif matched, render else branch
    if Result = '' then
      Result := RenderNodes(ANode.ElseBranch, AContext);
  end
  else
    Result := '';
end;

function TTemplateRenderer.RenderForeach(const ANode: TTemplateNode; const AContext: ITemplateContext): string;
var
  LCollection: Variant;
  LChildContext: TTemplateContext;
  I, LLow, LHigh, LIndex: Integer;
begin
  Result := '';
  LCollection := ResolveValue(ANode.CollectionName, AContext);
  
  if VarIsNull(LCollection) or VarIsEmpty(LCollection) then
    Exit;
    
  LChildContext := TTemplateContext.Create(AContext);
  try
    LIndex := 0;
    
    if VarIsArray(LCollection) then
    begin
      LLow := VarArrayLowBound(LCollection, 1);
      LHigh := VarArrayHighBound(LCollection, 1);
      
      for I := LLow to LHigh do
      begin
        LChildContext.SetValue(ANode.VarName, LCollection[I]);
        LChildContext.SetValue('$index', LIndex);
        LChildContext.SetValue('$first', LIndex = 0);
        LChildContext.SetValue('$last', I = LHigh);
        LChildContext.SetValue('$odd', (LIndex mod 2) = 1);
        LChildContext.SetValue('$even', (LIndex mod 2) = 0);
        
        Result := Result + RenderNodes(ANode.Children, LChildContext);
        Inc(LIndex);
      end;
    end
    else if VarIsStr(LCollection) then
    begin
      // Iterate over characters
      var S := VarToStr(LCollection);
      for I := 1 to Length(S) do
      begin
        LChildContext.SetValue(ANode.VarName, S[I]);
        LChildContext.SetValue('$index', LIndex);
        LChildContext.SetValue('$first', I = 1);
        LChildContext.SetValue('$last', I = Length(S));
        
        Result := Result + RenderNodes(ANode.Children, LChildContext);
        Inc(LIndex);
      end;
    end;
  finally
    LChildContext.Free;
  end;
end;

function TTemplateRenderer.RenderInclude(const ANode: TTemplateNode; const AContext: ITemplateContext): string;
var
  LTemplate: string;
  LParser: TTemplateParser;
  LNodes: TTemplateNodeList;
begin
  Result := '';
  
  if not Assigned(FIncludeResolver) then
    Exit;
    
  LTemplate := FIncludeResolver(ANode.Content);
  if LTemplate = '' then
    Exit;
    
  LParser := TTemplateParser.Create;
  try
    LNodes := LParser.Parse(LTemplate);
    try
      Result := RenderNodes(LNodes, AContext);
    finally
      LNodes.Free;
    end;
  finally
    LParser.Free;
  end;
end;

function TTemplateRenderer.RenderWith(const ANode: TTemplateNode; const AContext: ITemplateContext): string;
var
  LChildContext: TTemplateContext;
  LValue: Variant;
begin
  LValue := ResolveValue(ANode.Content, AContext);
  
  LChildContext := TTemplateContext.Create(AContext);
  try
    // For now, just add the value as 'this'
    LChildContext.SetValue('this', LValue);
    Result := RenderNodes(ANode.Children, LChildContext);
  finally
    LChildContext.Free;
  end;
end;

function TTemplateRenderer.RenderPartial(const ANode: TTemplateNode; const AContext: ITemplateContext): string;
var
  LPartialNodes: TTemplateNodeList;
begin
  Result := '';
  
  if FPartials.TryGetValue(ANode.Content, LPartialNodes) then
    Result := RenderNodes(LPartialNodes, AContext);
end;

function TTemplateRenderer.RenderBlock(const ANode: TTemplateNode; const AContext: ITemplateContext): string;
var
  LBlockNodes: TTemplateNodeList;
begin
  // Check if block has been overridden
  if FBlocks.TryGetValue(ANode.Content, LBlockNodes) then
    Result := RenderNodes(LBlockNodes, AContext)
  else
    // Render default content
    Result := RenderNodes(ANode.Children, AContext);
    
  // Register this block for potential override
  RegisterBlock(ANode.Content, ANode.Children);
end;

function TTemplateRenderer.ResolveValue(const APath: string; const AContext: ITemplateContext): Variant;
var
  LParts: TArray<string>;
  LValue: Variant;
  LIdx: Integer;
  LPart, LArrayPart: string;
  LBracketPos: Integer;
begin
  if APath = '' then
    Exit(Null);
    
  // Handle literals
  var LIntVal: Integer;
  var LFloatVal: Double;
  if (APath[1] = '"') or (APath[1] = '''') then
    Exit(Copy(APath, 2, Length(APath) - 2));
  if TryStrToInt(APath, LIntVal) then
    Exit(LIntVal);
  if TryStrToFloat(APath, LFloatVal) then
    Exit(LFloatVal);
  if SameText(APath, 'true') then
    Exit(True);
  if SameText(APath, 'false') then
    Exit(False);
  if SameText(APath, 'null') or SameText(APath, 'nil') then
    Exit(Null);
    
  // Handle dot notation: user.name.first
  LParts := APath.Split(['.']);
  LValue := AContext.GetValue(LParts[0]);
  
  // Handle array indexing in first part: items[0]
  LBracketPos := Pos('[', LParts[0]);
  if LBracketPos > 0 then
  begin
    LPart := Copy(LParts[0], 1, LBracketPos - 1);
    LArrayPart := Copy(LParts[0], LBracketPos + 1);
    LArrayPart := Copy(LArrayPart, 1, Length(LArrayPart) - 1); // Remove ]
    
    LValue := AContext.GetValue(LPart);
    if VarIsArray(LValue) and TryStrToInt(LArrayPart, LIdx) then
      LValue := LValue[LIdx];
  end;
  
  // Navigate through remaining parts
  for var I := 1 to High(LParts) do
  begin
    if VarIsNull(LValue) then
      Break;
      
    LPart := LParts[I];
    
    // Handle array indexing: [0]
    LBracketPos := Pos('[', LPart);
    if LBracketPos > 0 then
    begin
      LArrayPart := Copy(LPart, LBracketPos + 1);
      LArrayPart := Copy(LArrayPart, 1, Length(LArrayPart) - 1);
      LPart := Copy(LPart, 1, LBracketPos - 1);
      
      if (LPart <> '') and AContext.HasValue(APath.Split(['.'])[0] + '.' + LPart) then
        LValue := AContext.GetValue(APath.Split(['.'])[0] + '.' + LPart);
        
      if VarIsArray(LValue) and TryStrToInt(LArrayPart, LIdx) then
        LValue := LValue[LIdx];
    end
    else
    begin
      // Try to get nested value
      var LNestedPath := '';
      for var J := 0 to I do
      begin
        if LNestedPath <> '' then
          LNestedPath := LNestedPath + '.';
        LNestedPath := LNestedPath + LParts[J];
      end;
      
      if AContext.HasValue(LNestedPath) then
        LValue := AContext.GetValue(LNestedPath)
      else if FStrictMode then
        raise ETemplateRenderException.CreateFmt('Undefined variable: %s', [APath])
      else
        LValue := Null;
    end;
  end;
  
  Result := LValue;
end;

function TTemplateRenderer.ApplyFilters(const AValue: Variant; const AFilters: TArray<string>; 
  const AContext: ITemplateContext): Variant;
var
  LFilter: TTemplateFilter;
  LFilterName: string;
  LArgs: TArray<Variant>;
  I: Integer;
begin
  Result := AValue;
  
  for I := 0 to High(AFilters) do
  begin
    if ParseFilterArgs(AFilters[I], LFilterName, LArgs) then
    begin
      if FFilters.TryGetValue(LowerCase(LFilterName), LFilter) then
        Result := LFilter(Result, LArgs)
      else if FStrictMode then
        raise ETemplateRenderException.CreateFmt('Unknown filter: %s', [LFilterName]);
    end;
  end;
end;

function TTemplateRenderer.ParseFilterArgs(const AFilter: string; out AFilterName: string; 
  out AArgs: TArray<Variant>): Boolean;
var
  LParenPos: Integer;
  LArgsStr: string;
  LArgStrings: TArray<string>;
  I: Integer;
begin
  Result := True;
  
  LParenPos := Pos('(', AFilter);
  if LParenPos > 0 then
  begin
    AFilterName := Trim(Copy(AFilter, 1, LParenPos - 1));
    LArgsStr := Copy(AFilter, LParenPos + 1);
    LArgsStr := Trim(Copy(LArgsStr, 1, Length(LArgsStr) - 1)); // Remove closing )
    
    if LArgsStr <> '' then
    begin
      LArgStrings := LArgsStr.Split([',']);
      SetLength(AArgs, Length(LArgStrings));
      
      for I := 0 to High(LArgStrings) do
      begin
        var LArg := Trim(LArgStrings[I]);
        var LIntArg: Integer;
        var LFloatArg: Double;
        if (LArg <> '') and ((LArg[1] = '"') or (LArg[1] = '''')) then
          AArgs[I] := Copy(LArg, 2, Length(LArg) - 2)
        else if TryStrToInt(LArg, LIntArg) then
          AArgs[I] := LIntArg
        else if TryStrToFloat(LArg, LFloatArg) then
          AArgs[I] := LFloatArg
        else
          AArgs[I] := LArg;
      end;
    end
    else
      SetLength(AArgs, 0);
  end
  else
  begin
    AFilterName := Trim(AFilter);
    SetLength(AArgs, 0);
  end;
end;

function TTemplateRenderer.EvaluateCondition(const ACondition: string; const AContext: ITemplateContext): Boolean;
var
  LCondition: string;
  LParts: TArray<string>;
  LLeft, LRight: Variant;
  LOp: string;
begin
  LCondition := Trim(ACondition);
  
  // Handle NOT operator
  if StartsText('not ', LCondition) or StartsText('!', LCondition) then
  begin
    if StartsText('not ', LCondition) then
      LCondition := Trim(Copy(LCondition, 5))
    else
      LCondition := Trim(Copy(LCondition, 2));
    Result := not EvaluateCondition(LCondition, AContext);
    Exit;
  end;
  
  // Handle AND operator
  if ContainsText(LCondition, ' and ') then
  begin
    LParts := LCondition.Split([' and '], TStringSplitOptions.None);
    Result := True;
    for var Part in LParts do
      Result := Result and EvaluateCondition(Part, AContext);
    Exit;
  end;
  
  // Handle OR operator
  if ContainsText(LCondition, ' or ') then
  begin
    LParts := LCondition.Split([' or '], TStringSplitOptions.None);
    Result := False;
    for var Part in LParts do
      Result := Result or EvaluateCondition(Part, AContext);
    Exit;
  end;
  
  // Handle comparison operators
  if ContainsText(LCondition, '==') or ContainsText(LCondition, '=') then
  begin
    if ContainsText(LCondition, '==') then
      LParts := LCondition.Split(['=='])
    else
      LParts := LCondition.Split(['=']);
    if Length(LParts) = 2 then
    begin
      LLeft := ResolveValue(Trim(LParts[0]), AContext);
      LRight := ResolveValue(Trim(LParts[1]), AContext);
      Exit(VarToStr(LLeft) = VarToStr(LRight));
    end;
  end;
  
  if ContainsText(LCondition, '!=') or ContainsText(LCondition, '<>') then
  begin
    if ContainsText(LCondition, '!=') then
      LParts := LCondition.Split(['!='])
    else
      LParts := LCondition.Split(['<>']);
    if Length(LParts) = 2 then
    begin
      LLeft := ResolveValue(Trim(LParts[0]), AContext);
      LRight := ResolveValue(Trim(LParts[1]), AContext);
      Exit(VarToStr(LLeft) <> VarToStr(LRight));
    end;
  end;
  
  if ContainsText(LCondition, '>=') then
  begin
    LParts := LCondition.Split(['>=']);
    if Length(LParts) = 2 then
    begin
      LLeft := ResolveValue(Trim(LParts[0]), AContext);
      LRight := ResolveValue(Trim(LParts[1]), AContext);
      Exit(Double(LLeft) >= Double(LRight));
    end;
  end;
  
  if ContainsText(LCondition, '<=') then
  begin
    LParts := LCondition.Split(['<=']);
    if Length(LParts) = 2 then
    begin
      LLeft := ResolveValue(Trim(LParts[0]), AContext);
      LRight := ResolveValue(Trim(LParts[1]), AContext);
      Exit(Double(LLeft) <= Double(LRight));
    end;
  end;
  
  if ContainsText(LCondition, '>') then
  begin
    LParts := LCondition.Split(['>']);
    if Length(LParts) = 2 then
    begin
      LLeft := ResolveValue(Trim(LParts[0]), AContext);
      LRight := ResolveValue(Trim(LParts[1]), AContext);
      Exit(Double(LLeft) > Double(LRight));
    end;
  end;
  
  if ContainsText(LCondition, '<') then
  begin
    LParts := LCondition.Split(['<']);
    if Length(LParts) = 2 then
    begin
      LLeft := ResolveValue(Trim(LParts[0]), AContext);
      LRight := ResolveValue(Trim(LParts[1]), AContext);
      Exit(Double(LLeft) < Double(LRight));
    end;
  end;
  
  // Simple truthiness check
  LLeft := ResolveValue(LCondition, AContext);
  Result := IsTruthy(LLeft);
end;

function TTemplateRenderer.VariantToString(const AValue: Variant): string;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Result := ''
  else if VarType(AValue) = varBoolean then
  begin
    if AValue then
      Result := 'true'
    else
      Result := 'false';
  end
  else
    Result := VarToStr(AValue);
end;

function TTemplateRenderer.HtmlEscapeString(const AValue: string): string;
begin
  Result := AValue;
  Result := StringReplace(Result, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&#39;', [rfReplaceAll]);
end;

function TTemplateRenderer.IsTruthy(const AValue: Variant): Boolean;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Result := False
  else if VarType(AValue) = varBoolean then
    Result := AValue
  else if VarIsNumeric(AValue) then
    Result := AValue <> 0
  else if VarIsStr(AValue) then
    Result := VarToStr(AValue) <> ''
  else if VarIsArray(AValue) then
    Result := VarArrayHighBound(AValue, 1) >= VarArrayLowBound(AValue, 1)
  else
    Result := True;
end;

{ TTemplateEngine }

constructor TTemplateEngine.Create;
begin
  inherited;
  FParser := TTemplateParser.Create;
  FRenderer := TTemplateRenderer.Create;
  FCache := TDictionary<string, TTemplateNodeList>.Create;
  FCacheEnabled := True;
  FBasePath := '';
  
  // Set default include resolver
  FRenderer.IncludeResolver := DefaultIncludeResolver;
end;

destructor TTemplateEngine.Destroy;
begin
  ClearCache;
  FCache.Free;
  FRenderer.Free;
  FParser.Free;
  inherited;
end;

function TTemplateEngine.DefaultIncludeResolver(const ATemplateName: string): string;
var
  LPath: string;
begin
  Result := '';
  
  if FBasePath <> '' then
    LPath := TPath.Combine(FBasePath, ATemplateName)
  else
    LPath := ATemplateName;
    
  if TFile.Exists(LPath) then
    Result := TFile.ReadAllText(LPath, TEncoding.UTF8);
end;

function TTemplateEngine.GetCachedTemplate(const ATemplate: string): TTemplateNodeList;
var
  LHash: string;
begin
  if not FCacheEnabled then
    Exit(FParser.Parse(ATemplate));
    
  LHash := ATemplate.GetHashCode.ToString;
  
  if not FCache.TryGetValue(LHash, Result) then
  begin
    Result := FParser.Parse(ATemplate);
    FCache.Add(LHash, Result);
  end;
end;

function TTemplateEngine.Render(const ATemplate: string; const AContext: ITemplateContext): string;
var
  LNodes: TTemplateNodeList;
begin
  LNodes := GetCachedTemplate(ATemplate);
  Result := FRenderer.Render(LNodes, AContext);
  
  if not FCacheEnabled then
    LNodes.Free;
end;

function TTemplateEngine.Render(const ATemplate: string; const AValues: TDictionary<string, Variant>): string;
var
  LContext: TTemplateContext;
begin
  LContext := TTemplateContext.Create;
  try
    LContext.AddDictionary(AValues);
    Result := Render(ATemplate, LContext);
  finally
    LContext.Free;
  end;
end;

function TTemplateEngine.Render(const ATemplate: string; const ANames: array of string; 
  const AValues: array of Variant): string;
var
  LContext: TTemplateContext;
  I: Integer;
begin
  if Length(ANames) <> Length(AValues) then
    raise ETemplateException.Create('Names and Values arrays must have the same length');
    
  LContext := TTemplateContext.Create;
  try
    for I := 0 to High(ANames) do
      LContext.Add(ANames[I], AValues[I]);
    Result := Render(ATemplate, LContext);
  finally
    LContext.Free;
  end;
end;

function TTemplateEngine.RenderFile(const AFileName: string; const AContext: ITemplateContext): string;
var
  LTemplate: string;
begin
  LTemplate := TFile.ReadAllText(AFileName, TEncoding.UTF8);
  Result := Render(LTemplate, AContext);
end;

function TTemplateEngine.RenderFile(const AFileName: string; const AValues: TDictionary<string, Variant>): string;
var
  LContext: TTemplateContext;
begin
  LContext := TTemplateContext.Create;
  try
    LContext.AddDictionary(AValues);
    Result := RenderFile(AFileName, LContext);
  finally
    LContext.Free;
  end;
end;

function TTemplateEngine.Parse(const ATemplate: string): TTemplateNodeList;
begin
  Result := FParser.Parse(ATemplate);
end;

procedure TTemplateEngine.RegisterFilter(const AName: string; AFilter: TTemplateFilter);
begin
  FRenderer.RegisterFilter(AName, AFilter);
end;

procedure TTemplateEngine.RegisterFunction(const AName: string; AFunc: TTemplateFunction);
begin
  FRenderer.RegisterFunction(AName, AFunc);
end;

procedure TTemplateEngine.RegisterPartial(const AName: string; const ATemplate: string);
begin
  FRenderer.RegisterPartial(AName, ATemplate);
end;

procedure TTemplateEngine.ClearCache;
var
  LPair: TPair<string, TTemplateNodeList>;
begin
  for LPair in FCache do
    LPair.Value.Free;
  FCache.Clear;
end;

procedure TTemplateEngine.SetDelimiters(const AStart, AEnd: string);
begin
  FParser.StartDelimiter := AStart;
  FParser.EndDelimiter := AEnd;
end;

procedure TTemplateEngine.SetIncludeResolver(AResolver: TTemplateIncludeResolver);
begin
  FRenderer.IncludeResolver := AResolver;
end;

function TTemplateEngine.GetHtmlEscape: Boolean;
begin
  Result := FRenderer.HtmlEscape;
end;

procedure TTemplateEngine.SetHtmlEscape(Value: Boolean);
begin
  FRenderer.HtmlEscape := Value;
end;

function TTemplateEngine.GetStrictMode: Boolean;
begin
  Result := FRenderer.StrictMode;
end;

procedure TTemplateEngine.SetStrictMode(Value: Boolean);
begin
  FRenderer.StrictMode := Value;
end;

{ TTemplate }

class destructor TTemplate.Destroy;
begin
  FreeAndNil(FInstance);
end;

class function TTemplate.GetInstance: TTemplateEngine;
begin
  if not Assigned(FInstance) then
    FInstance := TTemplateEngine.Create;
  Result := FInstance;
end;

class function TTemplate.Render(const ATemplate: string; const ANames: array of string; 
  const AValues: array of Variant): string;
begin
  Result := Instance.Render(ATemplate, ANames, AValues);
end;

class function TTemplate.Render(const ATemplate: string; const AValues: TDictionary<string, Variant>): string;
begin
  Result := Instance.Render(ATemplate, AValues);
end;

class function TTemplate.Render(const ATemplate: string; const AContext: ITemplateContext): string;
begin
  Result := Instance.Render(ATemplate, AContext);
end;

class function TTemplate.CreateContext: TTemplateContext;
begin
  Result := TTemplateContext.Create;
end;

class procedure TTemplate.RegisterFilter(const AName: string; AFilter: TTemplateFilter);
begin
  Instance.RegisterFilter(AName, AFilter);
end;

class procedure TTemplate.RegisterFunction(const AName: string; AFunc: TTemplateFunction);
begin
  Instance.RegisterFunction(AName, AFunc);
end;

end.
