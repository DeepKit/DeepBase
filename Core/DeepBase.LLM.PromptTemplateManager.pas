{ ============================================================================
  DeepBase.LLM.PromptTemplateManager - Prompt Template Management

  Version: 1.0
  Description: CRUD + validation + rendering + import/export for LLM prompt
    templates, extracted from DeepBase.LLM (facade) per OPT-REFACTOR-001.

  Responsibilities (pure template logic):
    - CRUD: GetTemplate / GetAllTemplates / GetTemplatesByCategory /
            SaveTemplate / DeleteTemplate / CopyTemplate
    - Validation & rendering: ValidateTemplate / RenderWithInheritance
    - Import / export: ExportTemplates / ImportTemplates

  Out of scope (stays in TDeepBaseLLM facade as orchestration):
    - ExecuteTemplate (renders prompt -> GetConfig -> Chat): crosses template
      and LLM-execution responsibilities, so it remains in the facade. It
      delegates the template rendering step to this manager.

  Data access: a single injected ILLMStorage reference (FStorage). All SQL is
  parameterized via LLMParam (DeepBase.LLM.Config). The query-field helpers
  (QueryFieldBoolean etc.) also live in DeepBase.LLM.Config.

  Concurrency: template methods carry no locking here, matching the prior
  behavior in DeepBase.LLM. Any concurrency hardening is tracked separately.
  ============================================================================ }

unit DeepBase.LLM.PromptTemplateManager;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  Data.DB,
  System.Generics.Collections,
  DeepBase.LLM.Types;

type
  /// <summary>
  /// Manages the lifecycle of LLM prompt templates: persistence, validation,
  /// rendering (with inheritance and includes), and JSON import/export.
  /// </summary>
  TLLMPromptTemplateManager = class
  private
    FStorage: ILLMStorage;
  public
    /// <summary>Create the manager bound to a storage implementation.</summary>
    constructor Create(const AStorage: ILLMStorage);

    // --- Template retrieval ------------------------------------------------
    /// <summary>Load a single enabled template by name (empty Name if not found).</summary>
    function GetTemplate(const TemplateName: string): TLLMPromptTemplate;
    /// <summary>Load all enabled templates ordered by SortOrder, Name.</summary>
    function GetAllTemplates: TLLMPromptTemplateArray;
    /// <summary>Load enabled templates of a given category.</summary>
    function GetTemplatesByCategory(const Category: string): TLLMPromptTemplateArray;

    // --- Template mutation --------------------------------------------------
    /// <summary>Insert or update a template by name (name required).</summary>
    procedure SaveTemplate(const Template: TLLMPromptTemplate);
    /// <summary>Delete a non-built-in template by name (built-ins protected).</summary>
    procedure DeleteTemplate(const TemplateName: string);
    /// <summary>Clone an existing template under a new name.</summary>
    function CopyTemplate(const SourceName, NewName: string): Boolean;

    // --- Validation & rendering --------------------------------------------
    /// <summary>Validate a template: required fields, declared variables, inheritance depth.</summary>
    function ValidateTemplate(const Template: TLLMPromptTemplate): TTemplateValidation;
    /// <summary>Render a template, merging defaults from the inheritance chain and includes.</summary>
    function RenderWithInheritance(const TemplateName: string;
      const Variables: TDictionary<string, string>): string;

    // --- Import / export ---------------------------------------------------
    /// <summary>Serialize all templates to a formatted JSON array string.</summary>
    function ExportTemplates: string;
    /// <summary>Import templates from a JSON array, optionally overwriting existing names.</summary>
    function ImportTemplates(const Json: string; OverwriteExisting: Boolean): Integer;
  end;

implementation

uses
  System.Variants,
  System.RegularExpressions,
  System.StrUtils,
  DeepBase.LLM.Config;

{ TLLMPromptTemplateManager }

constructor TLLMPromptTemplateManager.Create(const AStorage: ILLMStorage);
begin
  inherited Create;
  FStorage := AStorage;
end;

// --- Implementation-internal helpers -----------------------------------------

/// <summary>Populate a TLLMPromptTemplate record from the current query row.</summary>
procedure LoadTemplateFromQuery(Query: TDataSet; var Template: TLLMPromptTemplate);
var
  VarJson, IncJson, DefJson: TJSONValue;
  I: Integer;
  Pair: TJSONPair;
begin
  Template.Init;
  Template.Id := Query.FieldByName('Id').AsInteger;
  Template.Name := Query.FieldByName('Name').AsString;
  Template.Category := Query.FieldByName('Category').AsString;
  Template.Description := Query.FieldByName('Description').AsString;
  Template.SystemPrompt := Query.FieldByName('SystemPrompt').AsString;
  Template.UserPromptTemplate := Query.FieldByName('UserPromptTemplate').AsString;
  Template.RecommendedConfig := Query.FieldByName('RecommendedConfig').AsString;
  Template.RecommendedModel := Query.FieldByName('RecommendedModel').AsString;
  Template.MaxTokens := Query.FieldByName('MaxTokens').AsInteger;
  Template.Temperature := Query.FieldByName('Temperature').AsFloat;
  Template.ParentTemplate := Query.FieldByName('ParentTemplate').AsString;
  Template.OutputFormat := Query.FieldByName('OutputFormat').AsString;
  Template.ValidationRegex := Query.FieldByName('ValidationRegex').AsString;
  Template.Examples := Query.FieldByName('Examples').AsString;
  Template.IsEnabled := QueryFieldBoolean(Query, 'IsEnabled', Template.IsEnabled);
  Template.IsBuiltIn := QueryFieldBoolean(Query, 'IsBuiltIn', Template.IsBuiltIn);
  Template.SortOrder := Query.FieldByName('SortOrder').AsInteger;

  // Parse Variables JSON array
  VarJson := nil;
  try
    try
      VarJson := TJSONObject.ParseJSONValue(Query.FieldByName('Variables').AsString);
      if VarJson is TJSONArray then
      begin
        SetLength(Template.Variables, TJSONArray(VarJson).Count);
        for I := 0 to TJSONArray(VarJson).Count - 1 do
          Template.Variables[I] := TJSONArray(VarJson).Items[I].Value;
      end;
    except
      SetLength(Template.Variables, 0);
    end;
  finally
    VarJson.Free;
  end;

  // Parse DefaultValues JSON object
  DefJson := nil;
  try
    try
      DefJson := TJSONObject.ParseJSONValue(Query.FieldByName('DefaultValues').AsString);
      if DefJson is TJSONObject then
      begin
        Template.DefaultValues := TDictionary<string, string>.Create;
        for Pair in TJSONObject(DefJson) do
          Template.DefaultValues.Add(Pair.JsonString.Value, Pair.JsonValue.Value);
      end;
    except
      FreeAndNil(Template.DefaultValues);
    end;
  finally
    DefJson.Free;
  end;

  // Parse IncludeTemplates JSON array
  IncJson := nil;
  try
    try
      IncJson := TJSONObject.ParseJSONValue(Query.FieldByName('IncludeTemplates').AsString);
      if IncJson is TJSONArray then
      begin
        SetLength(Template.IncludeTemplates, TJSONArray(IncJson).Count);
        for I := 0 to TJSONArray(IncJson).Count - 1 do
          Template.IncludeTemplates[I] := TJSONArray(IncJson).Items[I].Value;
      end;
    except
      SetLength(Template.IncludeTemplates, 0);
    end;
  finally
    IncJson.Free;
  end;
end;

/// <summary>Clear and shrink a template array.</summary>
procedure ClearPromptTemplates(var Templates: TLLMPromptTemplateArray);
var
  I: Integer;
begin
  for I := 0 to High(Templates) do
    Templates[I].Clear;
  SetLength(Templates, 0);
end;

// --- Template retrieval ------------------------------------------------------

function TLLMPromptTemplateManager.GetTemplate(const TemplateName: string): TLLMPromptTemplate;
var
  Query: TDataSet;
begin
  Result.Init;

  if not Assigned(FStorage) or not FStorage.IsConnected then
    Exit;

  Query := FStorage.OpenDataSet(
    'SELECT * FROM LLMPromptTemplates WHERE Name = :Name AND IsEnabled ' + IfThen(FStorage.IsPostgreSQL, '= TRUE', '= 1'),
    [LLMParam('Name', TemplateName)]);
  try
    if not Query.Eof then
      LoadTemplateFromQuery(Query, Result);
  finally
    Query.Free;
  end;
end;

function TLLMPromptTemplateManager.GetAllTemplates: TLLMPromptTemplateArray;
var
  Query: TDataSet;
  List: TList<TLLMPromptTemplate>;
  Template: TLLMPromptTemplate;
begin
  SetLength(Result, 0);

  if not Assigned(FStorage) or not FStorage.IsConnected then
    Exit;

  List := TList<TLLMPromptTemplate>.Create;
  try
    Query := FStorage.OpenDataSet(
      'SELECT * FROM LLMPromptTemplates WHERE IsEnabled ' + IfThen(FStorage.IsPostgreSQL, '= TRUE', '= 1') + ' ORDER BY SortOrder, Name',
      []);
    try
      while not Query.Eof do
      begin
        LoadTemplateFromQuery(Query, Template);
        List.Add(Template);
        Query.Next;
      end;
    finally
      Query.Free;
    end;

    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TLLMPromptTemplateManager.GetTemplatesByCategory(const Category: string): TLLMPromptTemplateArray;
var
  Query: TDataSet;
  List: TList<TLLMPromptTemplate>;
  Template: TLLMPromptTemplate;
begin
  SetLength(Result, 0);

  if not Assigned(FStorage) or not FStorage.IsConnected then
    Exit;

  List := TList<TLLMPromptTemplate>.Create;
  try
    Query := FStorage.OpenDataSet(
      'SELECT * FROM LLMPromptTemplates WHERE Category = :Category AND IsEnabled ' + IfThen(FStorage.IsPostgreSQL, '= TRUE', '= 1') + ' ORDER BY SortOrder, Name',
      [LLMParam('Category', Category)]);
    try
      while not Query.Eof do
      begin
        LoadTemplateFromQuery(Query, Template);
        List.Add(Template);
        Query.Next;
      end;
    finally
      Query.Free;
    end;

    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

// --- Template mutation ------------------------------------------------------

procedure TLLMPromptTemplateManager.SaveTemplate(const Template: TLLMPromptTemplate);
var
  VarsJson, IncJson: TJSONArray;
  DefsJson: TJSONObject;
  I: Integer;
  Key: string;
  NowStr: string;
  ExistingId: Variant;
begin
  if not Assigned(FStorage) or not FStorage.IsConnected then
    Exit;
  if Template.Name = '' then
    raise ELLMException.Create('Template name cannot be empty');

  NowStr := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);

  // Build Variables JSON array
  VarsJson := TJSONArray.Create;
  try
    for I := 0 to High(Template.Variables) do
      VarsJson.Add(Template.Variables[I]);

    // Build IncludeTemplates JSON array
    IncJson := TJSONArray.Create;
    try
      for I := 0 to High(Template.IncludeTemplates) do
        IncJson.Add(Template.IncludeTemplates[I]);

      // Build DefaultValues JSON object
      DefsJson := TJSONObject.Create;
      try
        if Assigned(Template.DefaultValues) then
          for Key in Template.DefaultValues.Keys do
            DefsJson.AddPair(Key, Template.DefaultValues[Key]);

        ExistingId := FStorage.ExecuteScalar(
          'SELECT Id FROM LLMPromptTemplates WHERE Name = :Name',
          [LLMParam('Name', Template.Name)]);

        if VarIsNull(ExistingId) then
        begin
          FStorage.Execute(
            'INSERT INTO LLMPromptTemplates (Name, Category, Description, SystemPrompt, ' +
            'UserPromptTemplate, Variables, DefaultValues, ParentTemplate, IncludeTemplates, ' +
            'OutputFormat, ValidationRegex, Examples, RecommendedConfig, RecommendedModel, ' +
            'MaxTokens, Temperature, IsEnabled, IsBuiltIn, SortOrder, CreatedAt, UpdatedAt) ' +
            'VALUES (:Name, :Category, :Description, :SystemPrompt, :UserPromptTemplate, ' +
            ':Variables, :DefaultValues, :ParentTemplate, :IncludeTemplates, :OutputFormat, ' +
            ':ValidationRegex, :Examples, :RecommendedConfig, :RecommendedModel, :MaxTokens, ' +
            ':Temperature, :IsEnabled, :IsBuiltIn, :SortOrder, :CreatedAt, :UpdatedAt)',
            [
              LLMParam('Name', Template.Name),
              LLMParam('Category', Template.Category),
              LLMParam('Description', Template.Description),
              LLMParam('SystemPrompt', Template.SystemPrompt),
              LLMParam('UserPromptTemplate', Template.UserPromptTemplate),
              LLMParam('Variables', VarsJson.ToString),
              LLMParam('DefaultValues', DefsJson.ToString),
              LLMParam('ParentTemplate', Template.ParentTemplate),
              LLMParam('IncludeTemplates', IncJson.ToString),
              LLMParam('OutputFormat', Template.OutputFormat),
              LLMParam('ValidationRegex', Template.ValidationRegex),
              LLMParam('Examples', Template.Examples),
              LLMParam('RecommendedConfig', Template.RecommendedConfig),
              LLMParam('RecommendedModel', Template.RecommendedModel),
              LLMParam('MaxTokens', Template.MaxTokens),
              LLMParam('Temperature', Template.Temperature),
              LLMParam('IsEnabled', Template.IsEnabled),
              LLMParam('IsBuiltIn', Template.IsBuiltIn),
              LLMParam('SortOrder', Template.SortOrder),
              LLMParam('CreatedAt', NowStr),
              LLMParam('UpdatedAt', NowStr)
            ]);
        end
        else
        begin
          FStorage.Execute(
            'UPDATE LLMPromptTemplates SET Category = :Category, Description = :Description, ' +
            'SystemPrompt = :SystemPrompt, UserPromptTemplate = :UserPromptTemplate, ' +
            'Variables = :Variables, DefaultValues = :DefaultValues, ParentTemplate = :ParentTemplate, ' +
            'IncludeTemplates = :IncludeTemplates, OutputFormat = :OutputFormat, ' +
            'ValidationRegex = :ValidationRegex, Examples = :Examples, ' +
            'RecommendedConfig = :RecommendedConfig, RecommendedModel = :RecommendedModel, ' +
            'MaxTokens = :MaxTokens, Temperature = :Temperature, IsEnabled = :IsEnabled, ' +
            'SortOrder = :SortOrder, UpdatedAt = :UpdatedAt WHERE Name = :Name',
            [
              LLMParam('Name', Template.Name),
              LLMParam('Category', Template.Category),
              LLMParam('Description', Template.Description),
              LLMParam('SystemPrompt', Template.SystemPrompt),
              LLMParam('UserPromptTemplate', Template.UserPromptTemplate),
              LLMParam('Variables', VarsJson.ToString),
              LLMParam('DefaultValues', DefsJson.ToString),
              LLMParam('ParentTemplate', Template.ParentTemplate),
              LLMParam('IncludeTemplates', IncJson.ToString),
              LLMParam('OutputFormat', Template.OutputFormat),
              LLMParam('ValidationRegex', Template.ValidationRegex),
              LLMParam('Examples', Template.Examples),
              LLMParam('RecommendedConfig', Template.RecommendedConfig),
              LLMParam('RecommendedModel', Template.RecommendedModel),
              LLMParam('MaxTokens', Template.MaxTokens),
              LLMParam('Temperature', Template.Temperature),
              LLMParam('IsEnabled', Template.IsEnabled),
              LLMParam('SortOrder', Template.SortOrder),
              LLMParam('UpdatedAt', NowStr)
            ]);
        end;
      finally
        DefsJson.Free;
      end;
    finally
      IncJson.Free;
    end;
  finally
    VarsJson.Free;
  end;
end;

procedure TLLMPromptTemplateManager.DeleteTemplate(const TemplateName: string);
begin
  if not Assigned(FStorage) or not FStorage.IsConnected then
    Exit;

  FStorage.Execute(
    'DELETE FROM LLMPromptTemplates WHERE Name = :Name AND IsBuiltIn ' + IfThen(FStorage.IsPostgreSQL, '= FALSE', '= 0'),
    [LLMParam('Name', TemplateName)]);
end;

function TLLMPromptTemplateManager.CopyTemplate(const SourceName, NewName: string): Boolean;
var
  Source: TLLMPromptTemplate;
  NewTemplate: TLLMPromptTemplate;
begin
  Result := False;

  Source := GetTemplate(SourceName);
  try
    if Source.Name = '' then
      Exit;

    NewTemplate := Source.Clone;
    try
      NewTemplate.Name := NewName;
      NewTemplate.IsBuiltIn := False;

      try
        SaveTemplate(NewTemplate);
        Result := True;
      except
        Result := False;
      end;
    finally
      NewTemplate.Clear;
    end;
  finally
    Source.Clear;
  end;
end;

// --- Validation & rendering -------------------------------------------------

function TLLMPromptTemplateManager.ValidateTemplate(const Template: TLLMPromptTemplate): TTemplateValidation;
var
  VarPattern: string;
  Match: TMatch;
  FoundVars: TList<string>;
  V: string;
  I: Integer;
  Depth: Integer;
  Parent: TLLMPromptTemplate;
  ParentName: string;
begin
  Result.IsValid := True;
  SetLength(Result.Errors, 0);
  SetLength(Result.MissingVariables, 0);

  FoundVars := TList<string>.Create;
  try
    // Check required fields
    if Template.Name = '' then
    begin
      Result.IsValid := False;
      SetLength(Result.Errors, Length(Result.Errors) + 1);
      Result.Errors[High(Result.Errors)] := 'Template name is required';
    end;

    if Template.UserPromptTemplate = '' then
    begin
      Result.IsValid := False;
      SetLength(Result.Errors, Length(Result.Errors) + 1);
      Result.Errors[High(Result.Errors)] := 'UserPromptTemplate is required';
    end;

    // Extract variables from template
    VarPattern := '\{\{([^}]+)\}\}';
    for Match in TRegEx.Matches(Template.UserPromptTemplate, VarPattern) do
    begin
      V := Match.Groups[1].Value;
      if not FoundVars.Contains(V) then
        FoundVars.Add(V);
    end;

    // Check if all found variables are declared
    for I := 0 to FoundVars.Count - 1 do
    begin
      V := FoundVars[I];
      if not V.StartsWith('include:') then // Skip include directives
      begin
        // Check if variable is in declared list
        if IndexStr(V, Template.Variables) < 0 then
        begin
          SetLength(Result.MissingVariables, Length(Result.MissingVariables) + 1);
          Result.MissingVariables[High(Result.MissingVariables)] := V;
        end;
      end;
    end;

    // Check circular inheritance (max 5 levels)
    if Template.ParentTemplate <> '' then
    begin
      Depth := 0;
      ParentName := Template.ParentTemplate;
      while (ParentName <> '') and (Depth < 5) do
      begin
        Parent.Init;
        try
          Parent := GetTemplate(ParentName);
          if Parent.Name = '' then
            Break;
          if Parent.Name = Template.Name then
          begin
            Result.IsValid := False;
            SetLength(Result.Errors, Length(Result.Errors) + 1);
            Result.Errors[High(Result.Errors)] := 'Circular inheritance detected: ' + Template.Name;
            Break;
          end;
          ParentName := Parent.ParentTemplate;
        finally
          Parent.Clear;
        end;
        Inc(Depth);
      end;

      if Depth >= 5 then
      begin
        Result.IsValid := False;
        SetLength(Result.Errors, Length(Result.Errors) + 1);
        Result.Errors[High(Result.Errors)] := 'Inheritance depth exceeds maximum (5)';
      end;
    end;
  finally
    FoundVars.Free;
  end;
end;

function TLLMPromptTemplateManager.RenderWithInheritance(const TemplateName: string;
  const Variables: TDictionary<string, string>): string;
var
  Template, Parent: TLLMPromptTemplate;
  MergedVars: TDictionary<string, string>;
  Depth: Integer;
  Key, Val: string;
  IncludeName, IncludeContent: string;
  IncTemplate: TLLMPromptTemplate;
  ParentName: string;
  I: Integer;
begin
  Result := '';

  Template := GetTemplate(TemplateName);
  try
    if Template.Name = '' then
      Exit;

    // Merge variables with defaults from inheritance chain
    MergedVars := TDictionary<string, string>.Create;
    try
      // Start with provided variables
      if Assigned(Variables) then
        for Key in Variables.Keys do
          MergedVars.AddOrSetValue(Key, Variables[Key]);

      // Add defaults from this template (don't overwrite)
      if Assigned(Template.DefaultValues) then
      begin
        for Key in Template.DefaultValues.Keys do
        begin
          if not MergedVars.ContainsKey(Key) then
            MergedVars.Add(Key, Template.DefaultValues[Key]);
        end;
      end;

      // Walk up inheritance chain and add missing defaults
      Depth := 0;
      ParentName := Template.ParentTemplate;
      while (ParentName <> '') and (Depth < 5) do
      begin
        Parent.Init;
        try
          Parent := GetTemplate(ParentName);
          if Parent.Name = '' then
            Break;

          if Assigned(Parent.DefaultValues) then
          begin
            for Key in Parent.DefaultValues.Keys do
            begin
              if not MergedVars.ContainsKey(Key) then
                MergedVars.Add(Key, Parent.DefaultValues[Key]);
            end;
          end;

          ParentName := Parent.ParentTemplate;
        finally
          Parent.Clear;
        end;
        Inc(Depth);
      end;

      // Render template
      Result := Template.UserPromptTemplate;

      // Replace variables
      for Key in MergedVars.Keys do
      begin
        if MergedVars.TryGetValue(Key, Val) then
          Result := StringReplace(Result, '{{' + Key + '}}', Val, [rfReplaceAll]);
      end;

      // Process includes {{include:template_name}}
      for I := 0 to High(Template.IncludeTemplates) do
      begin
        IncludeName := Template.IncludeTemplates[I];
        IncTemplate.Init;
        try
          IncTemplate := GetTemplate(IncludeName);
          if IncTemplate.Name <> '' then
          begin
            IncludeContent := RenderWithInheritance(IncludeName, MergedVars);
            Result := StringReplace(Result, '{{include:' + IncludeName + '}}', IncludeContent, [rfReplaceAll]);
          end;
        finally
          IncTemplate.Clear;
        end;
      end;
    finally
      MergedVars.Free;
    end;
  finally
    Template.Clear;
  end;
end;

// --- Import / export --------------------------------------------------------

function TLLMPromptTemplateManager.ExportTemplates: string;
var
  Templates: TLLMPromptTemplateArray;
  JsonArr: TJSONArray;
  JsonObj: TJSONObject;
  VarsArr, IncArr: TJSONArray;
  DefsObj: TJSONObject;
  T: TLLMPromptTemplate;
  I: Integer;
  Key: string;
begin
  Templates := GetAllTemplates;
  try
    JsonArr := TJSONArray.Create;
    try
      for T in Templates do
      begin
        JsonObj := TJSONObject.Create;
        JsonObj.AddPair('name', T.Name);
        JsonObj.AddPair('category', T.Category);
        JsonObj.AddPair('description', T.Description);
        JsonObj.AddPair('systemPrompt', T.SystemPrompt);
        JsonObj.AddPair('userPromptTemplate', T.UserPromptTemplate);
        JsonObj.AddPair('parentTemplate', T.ParentTemplate);
        JsonObj.AddPair('outputFormat', T.OutputFormat);
        JsonObj.AddPair('validationRegex', T.ValidationRegex);
        JsonObj.AddPair('examples', T.Examples);
        JsonObj.AddPair('recommendedConfig', T.RecommendedConfig);
        JsonObj.AddPair('recommendedModel', T.RecommendedModel);
        JsonObj.AddPair('maxTokens', TJSONNumber.Create(T.MaxTokens));
        JsonObj.AddPair('temperature', TJSONNumber.Create(T.Temperature));
        JsonObj.AddPair('isEnabled', TJSONBool.Create(T.IsEnabled));
        JsonObj.AddPair('isBuiltIn', TJSONBool.Create(T.IsBuiltIn));
        JsonObj.AddPair('sortOrder', TJSONNumber.Create(T.SortOrder));

        // Variables array
        VarsArr := TJSONArray.Create;
        for I := 0 to High(T.Variables) do
          VarsArr.Add(T.Variables[I]);
        JsonObj.AddPair('variables', VarsArr);

        // Include templates array
        IncArr := TJSONArray.Create;
        for I := 0 to High(T.IncludeTemplates) do
          IncArr.Add(T.IncludeTemplates[I]);
        JsonObj.AddPair('includeTemplates', IncArr);

        // Default values object
        DefsObj := TJSONObject.Create;
        if Assigned(T.DefaultValues) then
          for Key in T.DefaultValues.Keys do
            DefsObj.AddPair(Key, T.DefaultValues[Key]);
        JsonObj.AddPair('defaultValues', DefsObj);

        JsonArr.Add(JsonObj);
      end;

      Result := JsonArr.Format(2);
    finally
      JsonArr.Free;
    end;
  finally
    ClearPromptTemplates(Templates);
  end;
end;

function TLLMPromptTemplateManager.ImportTemplates(const Json: string; OverwriteExisting: Boolean): Integer;
var
  JsonArr: TJSONArray;
  JsonObj: TJSONObject;
  Template: TLLMPromptTemplate;
  VarsArr, IncArr: TJSONArray;
  DefsObj: TJSONObject;
  I, J: Integer;
  Pair: TJSONPair;
  Existing: TLLMPromptTemplate;
begin
  Result := 0;

  JsonArr := TJSONObject.ParseJSONValue(Json) as TJSONArray;
  if not Assigned(JsonArr) then
    Exit;

  try
    for I := 0 to JsonArr.Count - 1 do
    begin
      JsonObj := JsonArr.Items[I] as TJSONObject;

      Template.Init;
      try
        Template.Name := JsonObj.GetValue<string>('name', '');
        if Template.Name = '' then
          Continue;

        // Check if exists
        if not OverwriteExisting then
        begin
          Existing.Init;
          try
            Existing := GetTemplate(Template.Name);
            if Existing.Name <> '' then
              Continue;
          finally
            Existing.Clear;
          end;
        end;

        Template.Category := JsonObj.GetValue<string>('category', 'General');
        Template.Description := JsonObj.GetValue<string>('description', '');
        Template.SystemPrompt := JsonObj.GetValue<string>('systemPrompt', '');
        Template.UserPromptTemplate := JsonObj.GetValue<string>('userPromptTemplate', '');
        Template.ParentTemplate := JsonObj.GetValue<string>('parentTemplate', '');
        Template.OutputFormat := JsonObj.GetValue<string>('outputFormat', 'text');
        Template.ValidationRegex := JsonObj.GetValue<string>('validationRegex', '');
        Template.Examples := JsonObj.GetValue<string>('examples', '');
        Template.RecommendedConfig := JsonObj.GetValue<string>('recommendedConfig', '');
        Template.RecommendedModel := JsonObj.GetValue<string>('recommendedModel', '');
        Template.MaxTokens := JsonObj.GetValue<Integer>('maxTokens', 0);
        Template.Temperature := JsonObj.GetValue<Double>('temperature', 0.7);
        Template.IsEnabled := JsonObj.GetValue<Boolean>('isEnabled', True);
        Template.IsBuiltIn := False; // Imported templates are never built-in
        Template.SortOrder := JsonObj.GetValue<Integer>('sortOrder', 0);

        // Variables array
        VarsArr := JsonObj.GetValue<TJSONArray>('variables');
        if Assigned(VarsArr) then
        begin
          SetLength(Template.Variables, VarsArr.Count);
          for J := 0 to VarsArr.Count - 1 do
            Template.Variables[J] := VarsArr.Items[J].Value;
        end;

        // Include templates array
        IncArr := JsonObj.GetValue<TJSONArray>('includeTemplates');
        if Assigned(IncArr) then
        begin
          SetLength(Template.IncludeTemplates, IncArr.Count);
          for J := 0 to IncArr.Count - 1 do
            Template.IncludeTemplates[J] := IncArr.Items[J].Value;
        end;

        // Default values object
        DefsObj := JsonObj.GetValue<TJSONObject>('defaultValues');
        if Assigned(DefsObj) then
        begin
          Template.DefaultValues := TDictionary<string, string>.Create;
          for Pair in DefsObj do
            Template.DefaultValues.Add(Pair.JsonString.Value, Pair.JsonValue.Value);
        end;

        try
          SaveTemplate(Template);
          Inc(Result);
        except
          // Skip failed imports
        end;
      finally
        Template.Clear;
      end;
    end;
  finally
    JsonArr.Free;
  end;
end;

end.
