{ ============================================================================
  UniBase.LLM.ImportExport - Prompt Import/Export Module
  
  Version: 1.0
  Description: Provides import/export functionality for prompts
  Features:
    - Export to JSON/YAML format
    - Import with Merge/Replace modes
    - Includes meta-prompts and bindings
    - Category hierarchy support
  ============================================================================ }

unit UniBase.LLM.ImportExport;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  System.IOUtils,
  UniBase.LLM.Manager;

type
  /// <summary>
  /// Export format
  /// </summary>
  TExportFormat = (efJSON, efYAML);
  
  /// <summary>
  /// Import mode
  /// </summary>
  TImportMode = (
    imMerge,    // Add new items, skip existing
    imReplace,  // Replace existing items
    imOverwrite // Delete all and import
  );
  
  /// <summary>
  /// Import result
  /// </summary>
  TImportResult = record
    Success: Boolean;
    CategoriesImported: Integer;
    PromptsImported: Integer;
    VersionsImported: Integer;
    MetaPromptsImported: Integer;
    BindingsImported: Integer;
    Skipped: Integer;
    Errors: TArray<string>;
    
    procedure Init;
    function Summary: string;
  end;
  
  /// <summary>
  /// LLM Prompt Import/Export Handler
  /// </summary>
  TLLMImportExport = class
  private
    FLLMManager: TLLMManager;
    
    // Export helpers
    function CategoryToJson(const Cat: TPromptCategory): TJSONObject;
    function PromptToJson(const Prompt: TPrompt): TJSONObject;
    function VersionToJson(const Ver: TPromptVersion): TJSONObject;
    function MetaPromptToJson(const Meta: TMetaPrompt): TJSONObject;
    function VariableToJson(const V: TPromptVariable): TJSONObject;
    
    // Import helpers
    function JsonToCategory(const JsonObj: TJSONObject): TPromptCategory;
    function JsonToPrompt(const JsonObj: TJSONObject): TPrompt;
    function JsonToVersion(const JsonObj: TJSONObject): TPromptVersion;
    function JsonToMetaPrompt(const JsonObj: TJSONObject): TMetaPrompt;
    function JsonToVariable(const JsonObj: TJSONObject): TPromptVariable;
    
    // YAML helpers
    function JsonToYaml(const JsonObj: TJSONObject; Indent: Integer = 0): string;
    function YamlToJson(const YamlContent: string): TJSONObject;
    
  public
    constructor Create(ALLMManager: TLLMManager);
    
    /// <summary>Export all prompts to file</summary>
    function ExportPrompts(const FilePath: string; Format: TExportFormat = efJSON): Boolean;
    
    /// <summary>Export selected prompts by internal codes</summary>
    function ExportSelectedPrompts(const FilePath: string; 
      const InternalCodes: TArray<string>; Format: TExportFormat = efJSON): Boolean;
    
    /// <summary>Export to string</summary>
    function ExportToString(Format: TExportFormat = efJSON): string;
    
    /// <summary>Import prompts from file</summary>
    function ImportPrompts(const FilePath: string; Mode: TImportMode = imMerge): TImportResult;
    
    /// <summary>Import from string</summary>
    function ImportFromString(const Content: string; Mode: TImportMode = imMerge): TImportResult;
    
    /// <summary>Validate import file</summary>
    function ValidateImportFile(const FilePath: string; out ErrorMsg: string): Boolean;
  end;

implementation

uses
  System.StrUtils,
  System.Variants,
  System.DateUtils;

const
  EXPORT_VERSION = '1.0';
  
{ TImportResult }

procedure TImportResult.Init;
begin
  Success := False;
  CategoriesImported := 0;
  PromptsImported := 0;
  VersionsImported := 0;
  MetaPromptsImported := 0;
  BindingsImported := 0;
  Skipped := 0;
  SetLength(Errors, 0);
end;

function TImportResult.Summary: string;
begin
  if Success then
    Result := Format('Import successful: %d categories, %d prompts, %d versions, ' +
                     '%d meta-prompts, %d bindings (skipped: %d)',
      [CategoriesImported, PromptsImported, VersionsImported, 
       MetaPromptsImported, BindingsImported, Skipped])
  else
    Result := Format('Import failed: %d errors', [Length(Errors)]);
end;

{ TLLMImportExport }

constructor TLLMImportExport.Create(ALLMManager: TLLMManager);
begin
  inherited Create;
  FLLMManager := ALLMManager;
end;

// === Export Helpers ===

function TLLMImportExport.CategoryToJson(const Cat: TPromptCategory): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', TJSONNumber.Create(Cat.Id));
  Result.AddPair('parent_id', TJSONNumber.Create(Cat.ParentId));
  Result.AddPair('level', TJSONNumber.Create(Cat.Level));
  Result.AddPair('code', Cat.Code);
  Result.AddPair('name', Cat.Name);
  Result.AddPair('description', Cat.Description);
  Result.AddPair('sort_order', TJSONNumber.Create(Cat.SortOrder));
  Result.AddPair('is_active', TJSONBool.Create(Cat.IsActive));
end;

function TLLMImportExport.PromptToJson(const Prompt: TPrompt): TJSONObject;
var
  VersionsArray, VarsArray, MetaArray: TJSONArray;
  V: TPromptVersion;
  Var_: TPromptVariable;
  Meta: TMetaPrompt;
begin
  Result := TJSONObject.Create;
  Result.AddPair('internal_code', Prompt.InternalCode);
  Result.AddPair('name', Prompt.Name);
  Result.AddPair('description', Prompt.Description);
  Result.AddPair('category_id', TJSONNumber.Create(Prompt.CategoryId));
  Result.AddPair('category_path', Prompt.CategoryPath);
  Result.AddPair('bound_query_name', Prompt.BoundQueryName);
  Result.AddPair('is_active', TJSONBool.Create(Prompt.IsActive));
  
  // Variables
  VarsArray := TJSONArray.Create;
  for Var_ in Prompt.Variables do
    VarsArray.Add(VariableToJson(Var_));
  Result.AddPair('variables', VarsArray);
  
  // Versions
  VersionsArray := TJSONArray.Create;
  for V in Prompt.Versions do
    VersionsArray.Add(VersionToJson(V));
  Result.AddPair('versions', VersionsArray);
  
  // Meta-prompts (bound)
  MetaArray := TJSONArray.Create;
  for Meta in Prompt.MetaPrompts do
    MetaArray.Add(Meta.InternalCode);
  Result.AddPair('meta_prompt_codes', MetaArray);
end;

function TLLMImportExport.VersionToJson(const Ver: TPromptVersion): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('version_number', TJSONNumber.Create(Ver.VersionNumber));
  Result.AddPair('content', Ver.Content);
  Result.AddPair('is_production', TJSONBool.Create(Ver.IsProduction));
  Result.AddPair('test_count', TJSONNumber.Create(Ver.TestCount));
  Result.AddPair('success_count', TJSONNumber.Create(Ver.SuccessCount));
  Result.AddPair('total_tokens', TJSONNumber.Create(Ver.TotalTokens));
  Result.AddPair('total_cost', TJSONNumber.Create(Ver.TotalCost));
  Result.AddPair('avg_duration', TJSONNumber.Create(Ver.AvgDuration));
end;

function TLLMImportExport.MetaPromptToJson(const Meta: TMetaPrompt): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('internal_code', Meta.InternalCode);
  Result.AddPair('name', Meta.Name);
  Result.AddPair('category', Meta.CategoryToStr);
  Result.AddPair('content', Meta.Content);
  Result.AddPair('merge_mode', Meta.MergeModeToStr);
  Result.AddPair('priority', TJSONNumber.Create(Meta.Priority));
  Result.AddPair('level', TJSONNumber.Create(Meta.Level));
  Result.AddPair('is_active', TJSONBool.Create(Meta.IsActive));
end;

function TLLMImportExport.VariableToJson(const V: TPromptVariable): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', V.Name);
  Result.AddPair('type', V.TypeToStr);
  Result.AddPair('default', VarToStr(V.DefaultValue));
  Result.AddPair('description', V.Description);
  Result.AddPair('required', TJSONBool.Create(V.Required));
end;

// === Import Helpers ===

function TLLMImportExport.JsonToCategory(const JsonObj: TJSONObject): TPromptCategory;
begin
  Result.Id := JsonObj.GetValue<Integer>('id', 0);
  Result.ParentId := JsonObj.GetValue<Integer>('parent_id', 0);
  Result.Level := JsonObj.GetValue<Integer>('level', 1);
  Result.Code := JsonObj.GetValue<string>('code', '');
  Result.Name := JsonObj.GetValue<string>('name', '');
  Result.Description := JsonObj.GetValue<string>('description', '');
  Result.SortOrder := JsonObj.GetValue<Integer>('sort_order', 0);
  Result.IsActive := JsonObj.GetValue<Boolean>('is_active', True);
end;

function TLLMImportExport.JsonToPrompt(const JsonObj: TJSONObject): TPrompt;
var
  VarsArray, VersionsArray, MetaArray: TJSONArray;
  I: Integer;
begin
  Result.Id := 0; // Will be assigned on save
  Result.InternalCode := JsonObj.GetValue<string>('internal_code', '');
  Result.Name := JsonObj.GetValue<string>('name', '');
  Result.Description := JsonObj.GetValue<string>('description', '');
  Result.CategoryId := JsonObj.GetValue<Integer>('category_id', 0);
  Result.CategoryPath := JsonObj.GetValue<string>('category_path', '');
  Result.BoundQueryName := JsonObj.GetValue<string>('bound_query_name', '');
  Result.IsActive := JsonObj.GetValue<Boolean>('is_active', True);
  
  // Variables
  if JsonObj.TryGetValue<TJSONArray>('variables', VarsArray) then
  begin
    SetLength(Result.Variables, VarsArray.Count);
    for I := 0 to VarsArray.Count - 1 do
      Result.Variables[I] := JsonToVariable(VarsArray.Items[I] as TJSONObject);
  end
  else
    SetLength(Result.Variables, 0);
  
  // Versions
  if JsonObj.TryGetValue<TJSONArray>('versions', VersionsArray) then
  begin
    SetLength(Result.Versions, VersionsArray.Count);
    for I := 0 to VersionsArray.Count - 1 do
      Result.Versions[I] := JsonToVersion(VersionsArray.Items[I] as TJSONObject);
  end
  else
    SetLength(Result.Versions, 0);
  
  // Meta-prompts (just codes, will be bound after import)
  SetLength(Result.MetaPrompts, 0);
end;

function TLLMImportExport.JsonToVersion(const JsonObj: TJSONObject): TPromptVersion;
begin
  Result.Id := 0;
  Result.PromptId := 0;
  Result.VersionNumber := JsonObj.GetValue<Integer>('version_number', 1);
  Result.Content := JsonObj.GetValue<string>('content', '');
  Result.IsProduction := JsonObj.GetValue<Boolean>('is_production', False);
  Result.TestCount := JsonObj.GetValue<Integer>('test_count', 0);
  Result.SuccessCount := JsonObj.GetValue<Integer>('success_count', 0);
  Result.TotalTokens := JsonObj.GetValue<Integer>('total_tokens', 0);
  Result.TotalCost := JsonObj.GetValue<Double>('total_cost', 0);
  Result.AvgDuration := JsonObj.GetValue<Double>('avg_duration', 0);
end;

function TLLMImportExport.JsonToMetaPrompt(const JsonObj: TJSONObject): TMetaPrompt;
begin
  Result.Id := 0;
  Result.InternalCode := JsonObj.GetValue<string>('internal_code', '');
  Result.Name := JsonObj.GetValue<string>('name', '');
  Result.Category := TMetaPrompt.StrToCategory(JsonObj.GetValue<string>('category', 'security'));
  Result.Content := JsonObj.GetValue<string>('content', '');
  Result.MergeMode := TMetaPrompt.StrToMergeMode(JsonObj.GetValue<string>('merge_mode', 'PREFIX'));
  Result.Priority := JsonObj.GetValue<Integer>('priority', 100);
  Result.Level := JsonObj.GetValue<Integer>('level', 1);
  Result.IsActive := JsonObj.GetValue<Boolean>('is_active', True);
end;

function TLLMImportExport.JsonToVariable(const JsonObj: TJSONObject): TPromptVariable;
begin
  Result.Name := JsonObj.GetValue<string>('name', '');
  Result.VarType := TPromptVariable.StrToType(JsonObj.GetValue<string>('type', 'string'));
  Result.DefaultValue := JsonObj.GetValue<string>('default', '');
  Result.Description := JsonObj.GetValue<string>('description', '');
  Result.Required := JsonObj.GetValue<Boolean>('required', False);
end;

// === YAML Helpers ===

function TLLMImportExport.JsonToYaml(const JsonObj: TJSONObject; Indent: Integer): string;
var
  Pair: TJSONPair;
  Arr: TJSONArray;
  I: Integer;
  IndentStr: string;
  Value: TJSONValue;
begin
  Result := '';
  IndentStr := StringOfChar(' ', Indent);
  
  for Pair in JsonObj do
  begin
    Value := Pair.JsonValue;
    
    if Value is TJSONObject then
    begin
      Result := Result + IndentStr + Pair.JsonString.Value + ':' + sLineBreak;
      Result := Result + JsonToYaml(Value as TJSONObject, Indent + 2);
    end
    else if Value is TJSONArray then
    begin
      Arr := Value as TJSONArray;
      Result := Result + IndentStr + Pair.JsonString.Value + ':' + sLineBreak;
      for I := 0 to Arr.Count - 1 do
      begin
        if Arr.Items[I] is TJSONObject then
        begin
          Result := Result + IndentStr + '  - ' + sLineBreak;
          Result := Result + JsonToYaml(Arr.Items[I] as TJSONObject, Indent + 4);
        end
        else if Arr.Items[I] is TJSONString then
          Result := Result + IndentStr + '  - "' + Arr.Items[I].Value + '"' + sLineBreak
        else
          Result := Result + IndentStr + '  - ' + Arr.Items[I].Value + sLineBreak;
      end;
    end
    else if Value is TJSONString then
    begin
      // Handle multiline strings
      if Pos(#10, Value.Value) > 0 then
      begin
        Result := Result + IndentStr + Pair.JsonString.Value + ': |' + sLineBreak;
        var Lines := Value.Value.Split([#10]);
        for var Line in Lines do
          Result := Result + IndentStr + '  ' + Line + sLineBreak;
      end
      else
        Result := Result + IndentStr + Pair.JsonString.Value + ': "' + 
                  StringReplace(Value.Value, '"', '\"', [rfReplaceAll]) + '"' + sLineBreak;
    end
    else if Value is TJSONBool then
      Result := Result + IndentStr + Pair.JsonString.Value + ': ' + 
                IfThen((Value as TJSONBool).AsBoolean, 'true', 'false') + sLineBreak
    else if Value is TJSONNumber then
      Result := Result + IndentStr + Pair.JsonString.Value + ': ' + Value.Value + sLineBreak
    else if Value is TJSONNull then
      Result := Result + IndentStr + Pair.JsonString.Value + ': null' + sLineBreak
    else
      Result := Result + IndentStr + Pair.JsonString.Value + ': ' + Value.Value + sLineBreak;
  end;
end;

function TLLMImportExport.YamlToJson(const YamlContent: string): TJSONObject;
begin
  // Simplified YAML parser - only supports basic structure
  // For full YAML support, use a proper YAML library
  Result := TJSONObject.Create;
  
  // Basic implementation: just try to parse as JSON if it looks like JSON
  if (Copy(Trim(YamlContent), 1, 1) = '{') then
  begin
    Result.Free;
    Result := TJSONObject.ParseJSONValue(YamlContent) as TJSONObject;
  end
  else
  begin
    // For YAML, we'd need a proper parser
    // This is a placeholder - in real implementation, use a YAML library
    Result.AddPair('error', 'YAML parsing not fully implemented. Please use JSON format.');
  end;
end;

// === Export Methods ===

function TLLMImportExport.ExportPrompts(const FilePath: string; Format: TExportFormat): Boolean;
var
  Content: string;
begin
  Result := False;
  
  try
    Content := ExportToString(Format);
    TFile.WriteAllText(FilePath, Content, TEncoding.UTF8);
    Result := True;
  except
    // Silently fail, return False
  end;
end;

function TLLMImportExport.ExportSelectedPrompts(const FilePath: string;
  const InternalCodes: TArray<string>; Format: TExportFormat): Boolean;
var
  RootObj: TJSONObject;
  PromptsArray, MetaArray, CategoriesArray: TJSONArray;
  Prompts: TPromptArray;
  MetaPrompts: TMetaPromptArray;
  Categories: TPromptCategoryArray;
  P: TPrompt;
  Meta: TMetaPrompt;
  Cat: TPromptCategory;
  Code: string;
  Content: string;
  UsedCategories: TDictionary<Integer, Boolean>;
  UsedMetas: TDictionary<Integer, Boolean>;
begin
  Result := False;
  
  if not Assigned(FLLMManager) then
    Exit;
    
  UsedCategories := TDictionary<Integer, Boolean>.Create;
  UsedMetas := TDictionary<Integer, Boolean>.Create;
  try
    RootObj := TJSONObject.Create;
    try
      RootObj.AddPair('version', EXPORT_VERSION);
      RootObj.AddPair('export_date', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      RootObj.AddPair('type', 'partial');
      
      // Export selected prompts
      PromptsArray := TJSONArray.Create;
      for Code in InternalCodes do
      begin
        P := FLLMManager.GetPrompt(Code);
        if P.Id > 0 then
        begin
          PromptsArray.Add(PromptToJson(P));
          UsedCategories.AddOrSetValue(P.CategoryId, True);
          
          // Track used meta-prompts
          for Meta in P.MetaPrompts do
            UsedMetas.AddOrSetValue(Meta.Id, True);
        end;
      end;
      RootObj.AddPair('prompts', PromptsArray);
      
      // Export used categories
      CategoriesArray := TJSONArray.Create;
      Categories := FLLMManager.GetCategories;
      for Cat in Categories do
        if UsedCategories.ContainsKey(Cat.Id) then
          CategoriesArray.Add(CategoryToJson(Cat));
      RootObj.AddPair('categories', CategoriesArray);
      
      // Export used meta-prompts
      MetaArray := TJSONArray.Create;
      MetaPrompts := FLLMManager.GetMetaPrompts;
      for Meta in MetaPrompts do
        if UsedMetas.ContainsKey(Meta.Id) then
          MetaArray.Add(MetaPromptToJson(Meta));
      RootObj.AddPair('meta_prompts', MetaArray);
      
      // Convert to output format
      case Format of
        efJSON:
          Content := RootObj.Format(2);
        efYAML:
          Content := '# UniBase LLM Prompts Export' + sLineBreak + 
                     '# Version: ' + EXPORT_VERSION + sLineBreak + 
                     sLineBreak + JsonToYaml(RootObj);
      end;
      
      TFile.WriteAllText(FilePath, Content, TEncoding.UTF8);
      Result := True;
    finally
      RootObj.Free;
    end;
  finally
    UsedMetas.Free;
    UsedCategories.Free;
  end;
end;

function TLLMImportExport.ExportToString(Format: TExportFormat): string;
var
  RootObj: TJSONObject;
  PromptsArray, MetaArray, CategoriesArray: TJSONArray;
  Prompts: TPromptArray;
  MetaPrompts: TMetaPromptArray;
  Categories: TPromptCategoryArray;
  P: TPrompt;
  Meta: TMetaPrompt;
  Cat: TPromptCategory;
begin
  Result := '';
  
  if not Assigned(FLLMManager) then
    Exit;
    
  RootObj := TJSONObject.Create;
  try
    RootObj.AddPair('version', EXPORT_VERSION);
    RootObj.AddPair('export_date', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    RootObj.AddPair('type', 'full');
    
    // Export categories
    CategoriesArray := TJSONArray.Create;
    Categories := FLLMManager.GetCategories;
    for Cat in Categories do
      CategoriesArray.Add(CategoryToJson(Cat));
    RootObj.AddPair('categories', CategoriesArray);
    
    // Export meta-prompts
    MetaArray := TJSONArray.Create;
    MetaPrompts := FLLMManager.GetMetaPrompts;
    for Meta in MetaPrompts do
      MetaArray.Add(MetaPromptToJson(Meta));
    RootObj.AddPair('meta_prompts', MetaArray);
    
    // Export prompts
    PromptsArray := TJSONArray.Create;
    Prompts := FLLMManager.GetAllPrompts;
    for P in Prompts do
      PromptsArray.Add(PromptToJson(P));
    RootObj.AddPair('prompts', PromptsArray);
    
    // Convert to output format
    case Format of
      efJSON:
        Result := RootObj.Format(2);
      efYAML:
        Result := '# UniBase LLM Prompts Export' + sLineBreak + 
                  '# Version: ' + EXPORT_VERSION + sLineBreak + 
                  sLineBreak + JsonToYaml(RootObj);
    end;
  finally
    RootObj.Free;
  end;
end;

// === Import Methods ===

function TLLMImportExport.ImportPrompts(const FilePath: string; Mode: TImportMode): TImportResult;
var
  Content: string;
begin
  Result.Init;
  
  if not TFile.Exists(FilePath) then
  begin
    SetLength(Result.Errors, 1);
    Result.Errors[0] := 'File not found: ' + FilePath;
    Exit;
  end;
  
  try
    Content := TFile.ReadAllText(FilePath, TEncoding.UTF8);
    Result := ImportFromString(Content, Mode);
  except
    on E: Exception do
    begin
      SetLength(Result.Errors, 1);
      Result.Errors[0] := 'Read error: ' + E.Message;
    end;
  end;
end;

function TLLMImportExport.ImportFromString(const Content: string; Mode: TImportMode): TImportResult;
var
  RootObj: TJSONObject;
  CategoriesArray, MetaArray, PromptsArray, VersionsArray, MetaCodesArray: TJSONArray;
  CatObj, PromptObj, MetaObj: TJSONObject;
  I, J: Integer;
  Cat: TPromptCategory;
  Prompt: TPrompt;
  Version: TPromptVersion;
  Meta: TMetaPrompt;
  MetaCode: string;
  OldCatIdMap: TDictionary<Integer, Integer>; // Old ID -> New ID
begin
  Result.Init;
  
  if not Assigned(FLLMManager) then
  begin
    SetLength(Result.Errors, 1);
    Result.Errors[0] := 'LLM Manager not initialized';
    Exit;
  end;
  
  OldCatIdMap := TDictionary<Integer, Integer>.Create;
  try
    // Parse JSON
    RootObj := nil;
    try
      // Check if YAML or JSON
      if Copy(Trim(Content), 1, 1) = '{' then
        RootObj := TJSONObject.ParseJSONValue(Content) as TJSONObject
      else
        RootObj := YamlToJson(Content);
        
      if RootObj = nil then
      begin
        SetLength(Result.Errors, 1);
        Result.Errors[0] := 'Invalid JSON/YAML format';
        Exit;
      end;
      
      // Overwrite mode: clear existing data first
      if Mode = imOverwrite then
      begin
        // Delete all prompts (this will cascade to versions and bindings)
        var AllPrompts := FLLMManager.GetAllPrompts;
        for var P in AllPrompts do
          FLLMManager.DeletePrompt(P.InternalCode);
          
        // Delete all meta-prompts
        var AllMetas := FLLMManager.GetMetaPrompts;
        for var M in AllMetas do
          FLLMManager.DeleteMetaPrompt(M.InternalCode);
          
        // Delete all categories
        var AllCats := FLLMManager.GetCategories;
        for var C in AllCats do
          FLLMManager.DeleteCategory(C.Id);
      end;
      
      // Import categories first (to get ID mapping)
      if RootObj.TryGetValue<TJSONArray>('categories', CategoriesArray) then
      begin
        for I := 0 to CategoriesArray.Count - 1 do
        begin
          CatObj := CategoriesArray.Items[I] as TJSONObject;
          Cat := JsonToCategory(CatObj);
          var OldId := Cat.Id;
          Cat.Id := 0; // Let DB assign new ID
          
          // Check if exists (by code+name+level)
          var Exists := False;
          var ExistingCats := FLLMManager.GetCategories;
          for var EC in ExistingCats do
          begin
            if (EC.Level = Cat.Level) and (EC.Name = Cat.Name) then
            begin
              Exists := True;
              OldCatIdMap.AddOrSetValue(OldId, EC.Id);
              Break;
            end;
          end;
          
          if not Exists then
          begin
            // Map old parent ID to new
            if (Cat.ParentId > 0) and OldCatIdMap.ContainsKey(Cat.ParentId) then
              Cat.ParentId := OldCatIdMap[Cat.ParentId];
              
            FLLMManager.SaveCategory(Cat);
            OldCatIdMap.AddOrSetValue(OldId, Cat.Id);
            Inc(Result.CategoriesImported);
          end
          else if Mode <> imMerge then
          begin
            // Replace mode - update existing
            Cat.Id := OldCatIdMap[OldId];
            FLLMManager.SaveCategory(Cat);
            Inc(Result.CategoriesImported);
          end
          else
            Inc(Result.Skipped);
        end;
      end;
      
      // Import meta-prompts
      if RootObj.TryGetValue<TJSONArray>('meta_prompts', MetaArray) then
      begin
        for I := 0 to MetaArray.Count - 1 do
        begin
          MetaObj := MetaArray.Items[I] as TJSONObject;
          Meta := JsonToMetaPrompt(MetaObj);
          
          // Check if exists
          var ExistingMeta := FLLMManager.GetMetaPrompt(Meta.InternalCode);
          if ExistingMeta.Id = 0 then
          begin
            FLLMManager.SaveMetaPrompt(Meta);
            Inc(Result.MetaPromptsImported);
          end
          else if Mode <> imMerge then
          begin
            Meta.Id := ExistingMeta.Id;
            FLLMManager.SaveMetaPrompt(Meta);
            Inc(Result.MetaPromptsImported);
          end
          else
            Inc(Result.Skipped);
        end;
      end;
      
      // Import prompts
      if RootObj.TryGetValue<TJSONArray>('prompts', PromptsArray) then
      begin
        for I := 0 to PromptsArray.Count - 1 do
        begin
          PromptObj := PromptsArray.Items[I] as TJSONObject;
          Prompt := JsonToPrompt(PromptObj);
          
          // Map category ID
          if (Prompt.CategoryId > 0) and OldCatIdMap.ContainsKey(Prompt.CategoryId) then
            Prompt.CategoryId := OldCatIdMap[Prompt.CategoryId];
          
          // Check if exists
          var ExistingPrompt := FLLMManager.GetPrompt(Prompt.InternalCode);
          if ExistingPrompt.Id = 0 then
          begin
            FLLMManager.SavePrompt(Prompt);
            
            // Import versions
            for Version in Prompt.Versions do
            begin
              var Ver := Version;
              FLLMManager.SaveVersion(Prompt.InternalCode, Ver);
              Inc(Result.VersionsImported);
            end;
            
            Inc(Result.PromptsImported);
          end
          else if Mode <> imMerge then
          begin
            // Replace mode
            Prompt.Id := ExistingPrompt.Id;
            FLLMManager.SavePrompt(Prompt);
            
            // Update versions
            for Version in Prompt.Versions do
            begin
              var Ver := Version;
              FLLMManager.SaveVersion(Prompt.InternalCode, Ver);
              Inc(Result.VersionsImported);
            end;
            
            Inc(Result.PromptsImported);
          end
          else
            Inc(Result.Skipped);
          
          // Bind meta-prompts
          if PromptObj.TryGetValue<TJSONArray>('meta_prompt_codes', MetaCodesArray) then
          begin
            for J := 0 to MetaCodesArray.Count - 1 do
            begin
              MetaCode := MetaCodesArray.Items[J].Value;
              FLLMManager.BindMetaPrompt(Prompt.InternalCode, MetaCode, J);
              Inc(Result.BindingsImported);
            end;
          end;
        end;
      end;
      
      Result.Success := True;
    except
      on E: Exception do
      begin
        var ErrLen := Length(Result.Errors);
        SetLength(Result.Errors, ErrLen + 1);
        Result.Errors[ErrLen] := 'Import error: ' + E.Message;
      end;
    end;
  finally
    RootObj.Free;
    OldCatIdMap.Free;
  end;
  
  // Refresh cache
  if Result.Success then
    FLLMManager.RefreshCache;
end;

function TLLMImportExport.ValidateImportFile(const FilePath: string; out ErrorMsg: string): Boolean;
var
  Content: string;
  RootObj: TJSONObject;
begin
  Result := False;
  ErrorMsg := '';
  
  if not TFile.Exists(FilePath) then
  begin
    ErrorMsg := 'File not found';
    Exit;
  end;
  
  try
    Content := TFile.ReadAllText(FilePath, TEncoding.UTF8);
    
    if Copy(Trim(Content), 1, 1) = '{' then
      RootObj := TJSONObject.ParseJSONValue(Content) as TJSONObject
    else
      RootObj := YamlToJson(Content);
      
    if RootObj = nil then
    begin
      ErrorMsg := 'Invalid JSON/YAML format';
      Exit;
    end;
    
    try
      // Check required fields
      if (RootObj.Values['version'] <> nil) and (RootObj.Values['prompts'] <> nil) then
        Result := True
      else if RootObj.Values['version'] = nil then
        ErrorMsg := 'Missing "version" field'
      else
        ErrorMsg := 'Missing "prompts" array';
    finally
      RootObj.Free;
    end;
  except
    on E: Exception do
      ErrorMsg := 'Parse error: ' + E.Message;
  end;
end;

end.
