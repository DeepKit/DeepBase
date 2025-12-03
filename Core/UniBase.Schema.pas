{ ============================================================================
  UniBase.Schema - Database Schema SQL Definitions
  
  Version: 0.3
  Description: Centralized SQL schema definitions for UniBase config database.
               Separated into tiers for flexible deployment.
  
  Tier Structure:
    - Tier 0: Core tables required for UniBase operation
    - Tier 1: Recommended tables for full functionality
    - Tier 2: Optional tables for extended features
  ============================================================================ }

unit UniBase.Schema;

interface

const
  // Schema version - increment when schema changes
  SCHEMA_VERSION = '0.3';
  
  // Minimum compatible schema version (for version check)
  // Framework can work with schemas >= this version
  MIN_COMPATIBLE_SCHEMA_VERSION = '0.3';
  
  // Maximum compatible schema version
  // Set to SCHEMA_VERSION for strict compatibility
  MAX_COMPATIBLE_SCHEMA_VERSION = '0.3';

  // ============================================================================
  // Tier 0: Core Tables (Required)
  // Tables: SchemaInfo, ProjectInfo, Settings, FormStates, Languages, I18nTexts
  // ============================================================================
  
  SQL_TIER0_SCHEMA_INFO =
    'CREATE TABLE IF NOT EXISTS SchemaInfo (' +
    '  Key TEXT PRIMARY KEY,' +
    '  Value TEXT' +
    ');';
  
  SQL_TIER0_SCHEMA_INFO_DATA =
    'INSERT OR REPLACE INTO SchemaInfo VALUES (''SchemaVersion'', ''' + SCHEMA_VERSION + ''');' + #13#10 +
    'INSERT OR REPLACE INTO SchemaInfo VALUES (''CreatedAt'', CURRENT_TIMESTAMP);' + #13#10 +
    'INSERT OR REPLACE INTO SchemaInfo VALUES (''LastUpgrade'', CURRENT_TIMESTAMP);';
  
  SQL_TIER0_PROJECT_INFO =
    'CREATE TABLE IF NOT EXISTS ProjectInfo (' +
    '  Key TEXT PRIMARY KEY,' +
    '  Value TEXT' +
    ');';
  
  SQL_TIER0_PROJECT_INFO_DATA =
    'INSERT OR REPLACE INTO ProjectInfo VALUES (''ProjectName'', ''MyApp'');' + #13#10 +
    'INSERT OR REPLACE INTO ProjectInfo VALUES (''ProjectVersion'', ''1.0.0'');' + #13#10 +
    'INSERT OR REPLACE INTO ProjectInfo VALUES (''ProjectDescription'', '''');' + #13#10 +
    'INSERT OR REPLACE INTO ProjectInfo VALUES (''ProjectAuthor'', '''');' + #13#10 +
    'INSERT OR REPLACE INTO ProjectInfo VALUES (''ProjectWebsite'', '''');';
  
  SQL_TIER0_SETTINGS =
    'CREATE TABLE IF NOT EXISTS Settings (' +
    '  Key TEXT PRIMARY KEY,' +
    '  Value TEXT,' +
    '  ValueType TEXT DEFAULT ''String'',' +
    '  Category TEXT DEFAULT ''General'',' +
    '  Description TEXT,' +
    '  IsEncrypted INTEGER DEFAULT 0' +
    ');';
  
  SQL_TIER0_SETTINGS_DATA =
    'INSERT OR REPLACE INTO Settings (Key, Value, ValueType, Category, Description) ' +
    '  VALUES (''App.Language'', ''en-US'', ''String'', ''General'', ''Current language'');' + #13#10 +
    'INSERT OR REPLACE INTO Settings (Key, Value, ValueType, Category, Description) ' +
    '  VALUES (''App.DebugMode'', ''False'', ''Boolean'', ''General'', ''Debug mode enabled'');' + #13#10 +
    'INSERT OR REPLACE INTO Settings (Key, Value, ValueType, Category, Description) ' +
    '  VALUES (''App.Theme'', ''Windows11'', ''String'', ''UI'', ''Current theme'');';
  
  SQL_TIER0_FORM_STATES =
    'CREATE TABLE IF NOT EXISTS FormStates (' +
    '  FormName TEXT PRIMARY KEY,' +
    '  Left INTEGER,' +
    '  Top INTEGER,' +
    '  Width INTEGER,' +
    '  Height INTEGER,' +
    '  WindowState INTEGER DEFAULT 0,' +
    '  MonitorIndex INTEGER DEFAULT 0,' +
    '  Extra TEXT' +
    ');';
  
  SQL_TIER0_LANGUAGES =
    'CREATE TABLE IF NOT EXISTS Languages (' +
    '  LangCode TEXT PRIMARY KEY,' +
    '  LangName TEXT NOT NULL,' +
    '  NativeName TEXT,' +
    '  FlagIcon TEXT,' +
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  IsDefault INTEGER DEFAULT 0,' +
    '  SortOrder INTEGER DEFAULT 0' +
    ');';
  
  SQL_TIER0_LANGUAGES_DATA =
    'INSERT OR REPLACE INTO Languages (LangCode, LangName, NativeName, FlagIcon, IsEnabled, IsDefault, SortOrder) ' +
    '  VALUES (''en-US'', ''English'', ''English'', ''us.png'', 1, 1, 0);' + #13#10 +
    'INSERT OR REPLACE INTO Languages (LangCode, LangName, NativeName, FlagIcon, IsEnabled, IsDefault, SortOrder) ' +
    '  VALUES (''zh-CN'', ''Chinese (Simplified)'', ''简体中文'', ''cn.png'', 1, 0, 1);';
  
  SQL_TIER0_I18N_TEXTS =
    'CREATE TABLE IF NOT EXISTS I18nTexts (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  SourceText TEXT NOT NULL,' +
    '  LangCode TEXT NOT NULL,' +
    '  TranslatedText TEXT,' +
    '  PluralForm TEXT,' +
    '  Context TEXT,' +
    '  LastUsedTime TEXT,' +
    '  IsAutoTranslated INTEGER DEFAULT 0,' +
    '  IsVerified INTEGER DEFAULT 0,' +
    '  UNIQUE(SourceText, LangCode)' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_i18n_lang ON I18nTexts(LangCode);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_i18n_source ON I18nTexts(SourceText);';
  
  SQL_TIER0_I18N_TEXTS_DATA =
    'INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) ' +
    '  VALUES (''Welcome'', ''zh-CN'', ''欢迎'', 1);' + #13#10 +
    'INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) ' +
    '  VALUES (''Save'', ''zh-CN'', ''保存'', 1);' + #13#10 +
    'INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) ' +
    '  VALUES (''Cancel'', ''zh-CN'', ''取消'', 1);' + #13#10 +
    'INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) ' +
    '  VALUES (''OK'', ''zh-CN'', ''确定'', 1);' + #13#10 +
    'INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) ' +
    '  VALUES (''Error'', ''zh-CN'', ''错误'', 1);';

  // ============================================================================
  // Tier 1: Recommended Tables (Full Functionality)
  // Tables: Logs, MRU, Hotkeys, Themes
  // ============================================================================
  
  SQL_TIER1_LOGS =
    'CREATE TABLE IF NOT EXISTS Logs (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  LogTime TEXT NOT NULL,' +
    '  LogLevel TEXT NOT NULL,' +
    '  Source TEXT,' +
    '  Message TEXT NOT NULL,' +
    '  ExceptionClass TEXT,' +
    '  ExceptionMessage TEXT,' +
    '  StackTrace TEXT,' +
    '  ThreadId INTEGER,' +
    '  UserId TEXT' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_logs_time ON Logs(LogTime);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_logs_level ON Logs(LogLevel);';
  
  SQL_TIER1_MRU =
    'CREATE TABLE IF NOT EXISTS MRU (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  Category TEXT NOT NULL,' +
    '  ItemKey TEXT NOT NULL,' +
    '  DisplayName TEXT,' +
    '  LastAccess TEXT NOT NULL,' +
    '  AccessCount INTEGER DEFAULT 1,' +
    '  IconIndex INTEGER DEFAULT 0,' +
    '  IsPinned INTEGER DEFAULT 0,' +
    '  Extra TEXT,' +
    '  UNIQUE(Category, ItemKey)' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_mru_category_time ON MRU(Category, LastAccess DESC);';
  
  SQL_TIER1_HOTKEYS =
    'CREATE TABLE IF NOT EXISTS Hotkeys (' +
    '  ActionName TEXT PRIMARY KEY,' +
    '  Shortcut TEXT NOT NULL,' +
    '  Description TEXT,' +
    '  Category TEXT' +
    ');';
  
  SQL_TIER1_QUERIES =
    'CREATE TABLE IF NOT EXISTS Queries (' +
    '  ProcName TEXT PRIMARY KEY,' +
    '  SQL TEXT NOT NULL,' +
    '  Description TEXT,' +
    '  Category TEXT,' +
    '  TimeoutSec INTEGER DEFAULT 30,' +
    '  ParamSchema TEXT,' +  // JSON schema for parameter validation
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  CreatedAt TEXT DEFAULT CURRENT_TIMESTAMP,' +
    '  UpdatedAt TEXT DEFAULT CURRENT_TIMESTAMP' +
    ');';
  
  SQL_TIER1_THEMES =
    'CREATE TABLE IF NOT EXISTS Themes (' +
    '  ThemeName TEXT PRIMARY KEY,' +
    '  DisplayName TEXT,' +
    '  StyleFile TEXT,' +
    '  IsDark INTEGER DEFAULT 0,' +
    '  IsBuiltIn INTEGER DEFAULT 1,' +
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  SortOrder INTEGER DEFAULT 0,' +
    '  AccentColor INTEGER,' +
    '  CustomCSS TEXT' +
    ');';
  
  SQL_TIER1_THEMES_DATA =
    'INSERT OR IGNORE INTO Themes (ThemeName, DisplayName, IsDark, IsBuiltIn, SortOrder) ' +
    '  VALUES (''Windows'', ''Windows'', 0, 1, 0);' + #13#10 +
    'INSERT OR IGNORE INTO Themes (ThemeName, DisplayName, IsDark, IsBuiltIn, SortOrder) ' +
    '  VALUES (''Windows11'', ''Windows 11'', 0, 1, 1);' + #13#10 +
    'INSERT OR IGNORE INTO Themes (ThemeName, DisplayName, IsDark, IsBuiltIn, SortOrder) ' +
    '  VALUES (''Carbon'', ''Carbon (Dark)'', 1, 1, 2);';

  // ============================================================================
  // Tier 2: Optional Tables (Extended Features)
  // Tables: LLMConfiguration, LLMCalls, PromptCategories, Prompts, PromptVersions,
  //         PromptMeta, PromptMetaBinding, ExceptionReports, AnimationAssets, TestSnapshots
  // ============================================================================
  
  SQL_TIER2_LLM_CONFIG =
    'CREATE TABLE IF NOT EXISTS LLMConfiguration (' +
    '  ConfigName TEXT PRIMARY KEY,' +
    '  Provider TEXT NOT NULL,' +
    '  ApiUrl TEXT,' +
    '  ApiKey TEXT,' +
    '  Model TEXT,' +
    '  ContextWindow INTEGER DEFAULT 4096,' +
    '  PricePer1kPrompt REAL DEFAULT 0,' +
    '  PricePer1kCompletion REAL DEFAULT 0,' +
    '  IsActive INTEGER DEFAULT 0' +
    ');';
  
  SQL_TIER2_LLM_CONFIG_DATA =
    'INSERT OR IGNORE INTO LLMConfiguration (ConfigName, Provider, ApiUrl, Model, IsActive) ' +
    'VALUES (''Default'', ''OpenAI'', ''https://api.openai.com/v1'', ''gpt-3.5-turbo'', 1);';
  
  SQL_TIER2_LLM_CALLS =
    'CREATE TABLE IF NOT EXISTS LLMCalls (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  RequestTime TEXT NOT NULL,' +
    '  ConfigName TEXT,' +
    '  PromptId INTEGER,' +
    '  VersionNumber INTEGER,' +
    '  InputText TEXT,' +
    '  OutputText TEXT,' +
    '  InputTokens INTEGER DEFAULT 0,' +
    '  OutputTokens INTEGER DEFAULT 0,' +
    '  TotalTokens INTEGER DEFAULT 0,' +
    '  Duration INTEGER DEFAULT 0,' +
    '  Cost REAL DEFAULT 0,' +
    '  Status TEXT,' +
    '  ErrorMessage TEXT,' +
    '  Provider TEXT,' +
    '  Model TEXT,' +
    '  CreatedAt TEXT DEFAULT CURRENT_TIMESTAMP' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_llm_calls_time ON LLMCalls(RequestTime DESC);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_llm_calls_prompt ON LLMCalls(PromptId);';
  
  // ---- Prompt Management Tables ----
  
  SQL_TIER2_PROMPT_CATEGORIES =
    'CREATE TABLE IF NOT EXISTS PromptCategories (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  ParentId INTEGER,' +
    '  Level INTEGER NOT NULL DEFAULT 1,' +
    '  Code TEXT NOT NULL,' +
    '  Name TEXT NOT NULL,' +
    '  Description TEXT,' +
    '  SortOrder INTEGER DEFAULT 0,' +
    '  IsActive INTEGER DEFAULT 1,' +
    '  CreatedAt TEXT DEFAULT CURRENT_TIMESTAMP,' +
    '  UpdatedAt TEXT DEFAULT CURRENT_TIMESTAMP,' +
    '  FOREIGN KEY (ParentId) REFERENCES PromptCategories(Id)' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_prompt_cat_parent ON PromptCategories(ParentId);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_prompt_cat_level ON PromptCategories(Level);';
  
  SQL_TIER2_PROMPT_CATEGORIES_DATA =
    'INSERT OR IGNORE INTO PromptCategories (Id, ParentId, Level, Code, Name, Description, SortOrder) VALUES ' +
    '(1, NULL, 1, ''SYS'', ''系统提示词'', ''系统级通用提示词'', 1);' + #13#10 +
    'INSERT OR IGNORE INTO PromptCategories (Id, ParentId, Level, Code, Name, Description, SortOrder) VALUES ' +
    '(2, NULL, 1, ''BIZ'', ''业务提示词'', ''业务场景专用提示词'', 2);' + #13#10 +
    'INSERT OR IGNORE INTO PromptCategories (Id, ParentId, Level, Code, Name, Description, SortOrder) VALUES ' +
    '(3, 1, 2, ''TRANS'', ''翻译'', ''多语言翻译提示词'', 1);' + #13#10 +
    'INSERT OR IGNORE INTO PromptCategories (Id, ParentId, Level, Code, Name, Description, SortOrder) VALUES ' +
    '(4, 1, 2, ''CODE'', ''代码'', ''代码相关提示词'', 2);';
  
  SQL_TIER2_PROMPTS =
    'CREATE TABLE IF NOT EXISTS Prompts (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  CategoryId INTEGER,' +
    '  InternalCode TEXT NOT NULL UNIQUE,' +
    '  Name TEXT NOT NULL,' +
    '  Description TEXT,' +
    '  BoundQueryName TEXT,' +
    '  VariablesJson TEXT,' +
    '  IsActive INTEGER DEFAULT 1,' +
    '  CreatedAt TEXT DEFAULT CURRENT_TIMESTAMP,' +
    '  UpdatedAt TEXT DEFAULT CURRENT_TIMESTAMP,' +
    '  CreatedBy TEXT,' +
    '  UpdatedBy TEXT,' +
    '  FOREIGN KEY (CategoryId) REFERENCES PromptCategories(Id)' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_prompts_code ON Prompts(InternalCode);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_prompts_category ON Prompts(CategoryId);';
  
  SQL_TIER2_PROMPTS_DATA =
    'INSERT OR IGNORE INTO Prompts (Id, CategoryId, InternalCode, Name, Description, VariablesJson) VALUES ' +
    '(1, 3, ''SYS-TRANS-001'', ''通用翻译'', ''将文本翻译为目标语言'', ' +
    '''[{"name":"source_lang","type":"string","description":"源语言","required":false},' +
    '{"name":"target_lang","type":"string","description":"目标语言","required":true},' +
    '{"name":"text","type":"string","description":"待翻译文本","required":true}]'');' + #13#10 +
    'INSERT OR IGNORE INTO Prompts (Id, CategoryId, InternalCode, Name, Description, VariablesJson) VALUES ' +
    '(2, 4, ''SYS-CODE-001'', ''代码解释'', ''解释代码的功能和逻辑'', ' +
    '''[{"name":"language","type":"string","description":"编程语言","required":false},' +
    '{"name":"code","type":"string","description":"代码片段","required":true}]'');';
  
  SQL_TIER2_PROMPT_VERSIONS =
    'CREATE TABLE IF NOT EXISTS PromptVersions (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  PromptId INTEGER NOT NULL,' +
    '  VersionNumber INTEGER NOT NULL,' +
    '  Content TEXT NOT NULL,' +
    '  IsProduction INTEGER DEFAULT 0,' +
    '  TestCount INTEGER DEFAULT 0,' +
    '  SuccessCount INTEGER DEFAULT 0,' +
    '  TotalTokens INTEGER DEFAULT 0,' +
    '  TotalCost REAL DEFAULT 0,' +
    '  AvgDuration REAL DEFAULT 0,' +
    '  LastTestedAt TEXT,' +
    '  LastResponse TEXT,' +
    '  CreatedAt TEXT DEFAULT CURRENT_TIMESTAMP,' +
    '  UpdatedAt TEXT DEFAULT CURRENT_TIMESTAMP,' +
    '  UNIQUE(PromptId, VersionNumber),' +
    '  FOREIGN KEY (PromptId) REFERENCES Prompts(Id) ON DELETE CASCADE' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_prompt_ver_prompt ON PromptVersions(PromptId);';
  
  SQL_TIER2_PROMPT_VERSIONS_DATA =
    'INSERT OR IGNORE INTO PromptVersions (PromptId, VersionNumber, Content, IsProduction) VALUES ' +
    '(1, 1, ''请将以下{{source_lang}}文本翻译为{{target_lang}}：'' || char(10) || ''{{text}}'', 1);' + #13#10 +
    'INSERT OR IGNORE INTO PromptVersions (PromptId, VersionNumber, Content, IsProduction) VALUES ' +
    '(2, 1, ''请用简洁的中文解释以下{{language}}代码的功能：'' || char(10) || ''```'' || char(10) || ''{{code}}'' || char(10) || ''```'', 1);';
  
  SQL_TIER2_PROMPT_META =
    'CREATE TABLE IF NOT EXISTS PromptMeta (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  InternalCode TEXT NOT NULL UNIQUE,' +
    '  Name TEXT NOT NULL,' +
    '  Category TEXT NOT NULL,' +
    '  Content TEXT NOT NULL,' +
    '  MergeMode TEXT DEFAULT ''PREFIX'',' +
    '  Priority INTEGER DEFAULT 0,' +
    '  Level INTEGER DEFAULT 0,' +
    '  IsActive INTEGER DEFAULT 1,' +
    '  CreatedAt TEXT DEFAULT CURRENT_TIMESTAMP,' +
    '  UpdatedAt TEXT DEFAULT CURRENT_TIMESTAMP' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_prompt_meta_code ON PromptMeta(InternalCode);';
  
  SQL_TIER2_PROMPT_META_DATA =
    'INSERT OR IGNORE INTO PromptMeta (Id, InternalCode, Name, Category, Content, MergeMode, Priority, Level) VALUES ' +
    '(1, ''META-SEC-001'', ''安全约束'', ''SECURITY'', ''请确保回答安全、合规，不包含敏感信息。'', ''PREFIX'', 1, 0);' + #13#10 +
    'INSERT OR IGNORE INTO PromptMeta (Id, InternalCode, Name, Category, Content, MergeMode, Priority, Level) VALUES ' +
    '(2, ''META-FMT-001'', ''JSON输出'', ''FORMAT'', ''请以JSON格式输出结果。'', ''SUFFIX'', 10, 0);';
  
  SQL_TIER2_PROMPT_META_BINDING =
    'CREATE TABLE IF NOT EXISTS PromptMetaBinding (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  PromptId INTEGER NOT NULL,' +
    '  MetaPromptId INTEGER NOT NULL,' +
    '  OrderIndex INTEGER DEFAULT 0,' +
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  UNIQUE(PromptId, MetaPromptId),' +
    '  FOREIGN KEY (PromptId) REFERENCES Prompts(Id) ON DELETE CASCADE,' +
    '  FOREIGN KEY (MetaPromptId) REFERENCES PromptMeta(Id) ON DELETE CASCADE' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_prompt_meta_bind_prompt ON PromptMetaBinding(PromptId);';
  
  SQL_TIER2_EXCEPTION_REPORTS =
    'CREATE TABLE IF NOT EXISTS ExceptionReports (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  ReportTime TEXT NOT NULL,' +
    '  ExceptionClass TEXT,' +
    '  Message TEXT,' +
    '  StackTrace TEXT,' +
    '  Screenshot BLOB,' +
    '  SystemInfo TEXT,' +
    '  UserAction TEXT,' +
    '  IsResolved INTEGER DEFAULT 0,' +
    '  ResolutionNotes TEXT' +
    ');';
  
  SQL_TIER2_ANIMATION_ASSETS =
    'CREATE TABLE IF NOT EXISTS AnimationAssets (' +
    '  AssetName TEXT PRIMARY KEY,' +
    '  AssetType TEXT DEFAULT ''SVG'',' +
    '  Content TEXT,' +
    '  FrameCount INTEGER DEFAULT 1,' +
    '  FrameDuration INTEGER DEFAULT 30' +
    ');';
  
  SQL_TIER2_TEST_SNAPSHOTS =
    'CREATE TABLE IF NOT EXISTS TestSnapshots (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  TestName TEXT NOT NULL,' +
    '  SnapshotName TEXT NOT NULL,' +
    '  CreatedAt TEXT,' +
    '  WindowHierarchy TEXT,' +
    '  Screenshot BLOB,' +
    '  UNIQUE(TestName, SnapshotName)' +
    ');';
  
  // LLMPromptTemplates: 简化的提示词模板表
  SQL_TIER2_LLM_PROMPT_TEMPLATES =
    'CREATE TABLE IF NOT EXISTS LLMPromptTemplates (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  Name TEXT NOT NULL UNIQUE,' +              // 模板名称
    '  Category TEXT DEFAULT ''General'',' +      // 分类
    '  Description TEXT,' +                        // 描述
    '  SystemPrompt TEXT,' +                       // 系统提示词
    '  UserPromptTemplate TEXT NOT NULL,' +        // 用户提示词模板 ({{variable}})
    '  Variables TEXT,' +                          // 变量列表 JSON: ["var1", "var2"]
    '  DefaultValues TEXT,' +                      // 默认值 JSON: {"var1": "value"}
    '  ParentTemplate TEXT,' +                     // 父模板名称（继承）
    '  IncludeTemplates TEXT,' +                   // 组合模板 JSON: ["tpl1", "tpl2"]
    '  OutputFormat TEXT DEFAULT ''text'',' +      // 输出格式: text/json/markdown
    '  ValidationRegex TEXT,' +                    // 输出验证正则
    '  Examples TEXT,' +                           // 示例 JSON: [{"input":{},"output":""}]
    '  RecommendedConfig TEXT,' +                  // 推荐 LLM 配置名
    '  RecommendedModel TEXT,' +                   // 推荐模型
    '  MaxTokens INTEGER,' +                       // 推荐最大 Token
    '  Temperature REAL,' +                        // 推荐温度
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  IsBuiltIn INTEGER DEFAULT 0,' +             // 是否内置
    '  SortOrder INTEGER DEFAULT 0,' +
    '  CreatedAt TEXT DEFAULT CURRENT_TIMESTAMP,' +
    '  UpdatedAt TEXT DEFAULT CURRENT_TIMESTAMP,' +
    '  Extra TEXT' +                               // 额外配置 JSON
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_prompt_tpl_category ON LLMPromptTemplates(Category);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_prompt_tpl_parent ON LLMPromptTemplates(ParentTemplate);';
  
  SQL_TIER2_LLM_PROMPT_TEMPLATES_DATA =
    'INSERT OR IGNORE INTO LLMPromptTemplates (Name, Category, Description, SystemPrompt, UserPromptTemplate, Variables, DefaultValues, Temperature, IsBuiltIn) VALUES ' +
    '(''translate_text'', ''Translation'', ''Translate text between languages'', ' +
    '''You are a professional translator. Translate accurately while preserving meaning and tone.'', ' +
    '''Translate the following text from {{source_lang}} to {{target_lang}}:\n\n{{text}}'', ' +
    '''["source_lang", "target_lang", "text"]'', ' +
    '''{"source_lang": "English", "target_lang": "Chinese"}'', 0.3, 1);' + #13#10 +
    'INSERT OR IGNORE INTO LLMPromptTemplates (Name, Category, Description, SystemPrompt, UserPromptTemplate, Variables, DefaultValues, Temperature, IsBuiltIn) VALUES ' +
    '(''explain_code'', ''Code'', ''Explain code in plain language'', ' +
    '''You are an expert programmer. Explain code clearly and concisely.'', ' +
    '''Explain the following {{language}} code:\n\n```{{language}}\n{{code}}\n```'', ' +
    '''["language", "code"]'', ' +
    '''{"language": "Delphi"}'', 0.5, 1);' + #13#10 +
    'INSERT OR IGNORE INTO LLMPromptTemplates (Name, Category, Description, SystemPrompt, UserPromptTemplate, Variables, DefaultValues, Temperature, IsBuiltIn) VALUES ' +
    '(''generate_docs'', ''Code'', ''Generate documentation for code'', ' +
    '''You are a technical writer. Generate clear, comprehensive documentation.'', ' +
    '''Generate XML documentation comments for the following {{language}} code:\n\n```{{language}}\n{{code}}\n```'', ' +
    '''["language", "code"]'', ' +
    '''{"language": "Delphi"}'', 0.3, 1);' + #13#10 +
    // 继承示例模板
    'INSERT OR IGNORE INTO LLMPromptTemplates (Name, Category, Description, SystemPrompt, UserPromptTemplate, Variables, ParentTemplate, Temperature, IsBuiltIn) VALUES ' +
    '(''translate_to_chinese'', ''Translation'', ''Translate to Chinese (inherits from translate_text)'', ' +
    '''", ''Translate to Simplified Chinese:\n\n{{text}}'', ' +
    '''["text"]'', ''translate_text'', 0.3, 1);';

// ============================================================================
// Helper Functions
// ============================================================================

/// <summary>
/// Get complete Tier 0 schema SQL (required tables + data)
/// </summary>
function GetTier0SchemaSQL: string;

/// <summary>
/// Get complete Tier 1 schema SQL (recommended tables + data)
/// </summary>
function GetTier1SchemaSQL: string;

/// <summary>
/// Get complete Tier 2 schema SQL (optional tables + data)
/// </summary>
function GetTier2SchemaSQL: string;

/// <summary>
/// Get all schema SQL (Tier 0 + 1 + 2)
/// </summary>
function GetFullSchemaSQL: string;

implementation

function GetTier0SchemaSQL: string;
begin
  Result :=
    SQL_TIER0_SCHEMA_INFO + #13#10 + SQL_TIER0_SCHEMA_INFO_DATA + #13#10 +
    SQL_TIER0_PROJECT_INFO + #13#10 + SQL_TIER0_PROJECT_INFO_DATA + #13#10 +
    SQL_TIER0_SETTINGS + #13#10 + SQL_TIER0_SETTINGS_DATA + #13#10 +
    SQL_TIER0_FORM_STATES + #13#10 +
    SQL_TIER0_LANGUAGES + #13#10 + SQL_TIER0_LANGUAGES_DATA + #13#10 +
    SQL_TIER0_I18N_TEXTS + #13#10 + SQL_TIER0_I18N_TEXTS_DATA;
end;

function GetTier1SchemaSQL: string;
begin
  Result :=
    SQL_TIER1_LOGS + #13#10 +
    SQL_TIER1_MRU + #13#10 +
    SQL_TIER1_HOTKEYS + #13#10 +
    SQL_TIER1_QUERIES + #13#10 +
    SQL_TIER1_THEMES + #13#10 + SQL_TIER1_THEMES_DATA;
end;

function GetTier2SchemaSQL: string;
begin
  Result :=
    SQL_TIER2_LLM_CONFIG + #13#10 + SQL_TIER2_LLM_CONFIG_DATA + #13#10 +
    SQL_TIER2_LLM_CALLS + #13#10 +
    // Prompt Management Tables (Advanced)
    SQL_TIER2_PROMPT_CATEGORIES + #13#10 + SQL_TIER2_PROMPT_CATEGORIES_DATA + #13#10 +
    SQL_TIER2_PROMPTS + #13#10 + SQL_TIER2_PROMPTS_DATA + #13#10 +
    SQL_TIER2_PROMPT_VERSIONS + #13#10 + SQL_TIER2_PROMPT_VERSIONS_DATA + #13#10 +
    SQL_TIER2_PROMPT_META + #13#10 + SQL_TIER2_PROMPT_META_DATA + #13#10 +
    SQL_TIER2_PROMPT_META_BINDING + #13#10 +
    // LLM Prompt Templates (Simplified)
    SQL_TIER2_LLM_PROMPT_TEMPLATES + #13#10 + SQL_TIER2_LLM_PROMPT_TEMPLATES_DATA + #13#10 +
    // Other Tier 2 Tables
    SQL_TIER2_EXCEPTION_REPORTS + #13#10 +
    SQL_TIER2_ANIMATION_ASSETS + #13#10 +
    SQL_TIER2_TEST_SNAPSHOTS;
end;

function GetFullSchemaSQL: string;
begin
  Result := GetTier0SchemaSQL + #13#10 + GetTier1SchemaSQL + #13#10 + GetTier2SchemaSQL;
end;

end.
