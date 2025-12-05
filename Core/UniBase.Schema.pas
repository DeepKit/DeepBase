{ ============================================================================
  UniBase.Schema - Database Schema SQL Definitions
  
  Version: 1.0.0
  Description: Centralized SQL schema definitions for UniBase config database.
               Separated into tiers for flexible deployment.
               Synchronized with data/样例Config.db
  
  Tier Structure:
    - Tier 0: Core tables (5): SchemaInfo, Settings, FormStates, Languages, I18nTexts
    - Tier 1: Recommended tables (7): Logs, MRU, Hotkeys, Queries, Themes, Categories, Tags
    - Tier 2: Extended tables (11): Providers, Models, LLMConfig, LLMCalls, LLMPrompts,
              LLMApiKeys, ExceptionReports, AnimationAssets, Attachments, TagMappings, Notifications
  
  Design Principles:
    - Every table has Extra TEXT (JSON) and Remarks TEXT fallback fields
    - Field redundancy preferred over minimalism
    - UTF-8 support, English field names
  ============================================================================ }

unit UniBase.Schema;

interface

const
  // Schema version - increment when schema changes
  SCHEMA_VERSION = '1.0.0';
  
  // Minimum compatible schema version (for version check)
  MIN_COMPATIBLE_SCHEMA_VERSION = '0.3';
  
  // Maximum compatible schema version
  MAX_COMPATIBLE_SCHEMA_VERSION = '1.0.0';

  // ============================================================================
  // Tier 0: Core Tables (5 tables - Required)
  // Tables: SchemaInfo, Settings, FormStates, Languages, I18nTexts
  // ============================================================================
  
  // 1. SchemaInfo - Database version management
  SQL_TIER0_SCHEMA_INFO =
    'CREATE TABLE IF NOT EXISTS SchemaInfo (' +
    '  Key TEXT PRIMARY KEY,' +
    '  Value TEXT,' +
    '  Extra TEXT,' +
    '  Remarks TEXT' +
    ');';
  
  SQL_TIER0_SCHEMA_INFO_DATA =
    'INSERT OR REPLACE INTO SchemaInfo (Key, Value) VALUES (''SchemaVersion'', ''' + SCHEMA_VERSION + ''');' + #13#10 +
    'INSERT OR REPLACE INTO SchemaInfo (Key, Value) VALUES (''CreatedAt'', datetime(''now''));' + #13#10 +
    'INSERT OR REPLACE INTO SchemaInfo (Key, Value) VALUES (''UniBaseVersion'', ''' + SCHEMA_VERSION + ''');';
  
  // 2. Settings - Application configuration storage
  SQL_TIER0_SETTINGS =
    'CREATE TABLE IF NOT EXISTS Settings (' +
    '  Key TEXT PRIMARY KEY,' +
    '  Value TEXT,' +
    '  ValueType TEXT DEFAULT ''String'',' +
    '  Category TEXT DEFAULT ''General'',' +
    '  Description TEXT,' +
    '  DefaultValue TEXT,' +
    '  IsEncrypted INTEGER DEFAULT 0,' +
    '  IsReadOnly INTEGER DEFAULT 0,' +
    '  IsSystem INTEGER DEFAULT 0,' +
    '  SortOrder INTEGER DEFAULT 0,' +
    '  CreatedAt TEXT DEFAULT (datetime(''now'')),' +
    '  UpdatedAt TEXT DEFAULT (datetime(''now'')),' +
    '  Extra TEXT,' +
    '  Remarks TEXT' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_settings_category ON Settings(Category);';
  
  SQL_TIER0_SETTINGS_DATA =
    'INSERT OR IGNORE INTO Settings (Key, Value, ValueType, Category, Description, DefaultValue) VALUES ' +
    '  (''App.Language'', ''en-US'', ''String'', ''General'', ''Application language'', ''en-US'');' + #13#10 +
    'INSERT OR IGNORE INTO Settings (Key, Value, ValueType, Category, Description, DefaultValue) VALUES ' +
    '  (''App.Theme'', ''Windows11'', ''String'', ''UI'', ''Application theme'', ''Windows11'');' + #13#10 +
    'INSERT OR IGNORE INTO Settings (Key, Value, ValueType, Category, Description, DefaultValue) VALUES ' +
    '  (''App.LogLevel'', ''INFO'', ''String'', ''General'', ''Logging level'', ''INFO'');' + #13#10 +
    'INSERT OR IGNORE INTO Settings (Key, Value, ValueType, Category, Description, DefaultValue) VALUES ' +
    '  (''App.DebugMode'', ''False'', ''Boolean'', ''General'', ''Debug mode'', ''False'');' + #13#10 +
    'INSERT OR IGNORE INTO Settings (Key, Value, ValueType, Category, Description, DefaultValue) VALUES ' +
    '  (''LLM.DefaultProvider'', ''openai'', ''String'', ''LLM'', ''Default LLM provider'', ''openai'');' + #13#10 +
    'INSERT OR IGNORE INTO Settings (Key, Value, ValueType, Category, Description, DefaultValue) VALUES ' +
    '  (''LLM.DefaultModel'', ''gpt-4o-mini'', ''String'', ''LLM'', ''Default LLM model'', ''gpt-4o-mini'');' + #13#10 +
    'INSERT OR IGNORE INTO Settings (Key, Value, ValueType, Category, Description, DefaultValue) VALUES ' +
    '  (''UniBase.AutoDiagnose'', ''True'', ''Boolean'', ''UniBase'', ''Auto diagnose on startup'', ''True'');' + #13#10 +
    'INSERT OR IGNORE INTO Settings (Key, Value, ValueType, Category, Description, DefaultValue) VALUES ' +
    '  (''UniBase.AutoFix'', ''False'', ''Boolean'', ''UniBase'', ''Auto fix issues'', ''False'');';
  
  // 3. FormStates - Window position and state persistence
  SQL_TIER0_FORM_STATES =
    'CREATE TABLE IF NOT EXISTS FormStates (' +
    '  FormName TEXT PRIMARY KEY,' +
    '  Left INTEGER,' +
    '  Top INTEGER,' +
    '  Width INTEGER,' +
    '  Height INTEGER,' +
    '  WindowState INTEGER DEFAULT 0,' +
    '  MonitorIndex INTEGER DEFAULT 0,' +
    '  Splitters TEXT,' +
    '  Columns TEXT,' +
    '  TabIndex INTEGER DEFAULT 0,' +
    '  ScrollPos TEXT,' +
    '  LastAccess TEXT,' +
    '  Extra TEXT,' +
    '  Remarks TEXT' +
    ');';
  
  // 4. Languages - Supported languages definition
  SQL_TIER0_LANGUAGES =
    'CREATE TABLE IF NOT EXISTS Languages (' +
    '  LangCode TEXT PRIMARY KEY,' +
    '  LangName TEXT NOT NULL,' +
    '  NativeName TEXT,' +
    '  FlagIcon TEXT,' +
    '  DateFormat TEXT,' +
    '  TimeFormat TEXT,' +
    '  NumberFormat TEXT,' +
    '  CurrencySymbol TEXT,' +
    '  TextDirection TEXT DEFAULT ''LTR'',' +
    '  FontFamily TEXT,' +
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  IsDefault INTEGER DEFAULT 0,' +
    '  IsComplete INTEGER DEFAULT 0,' +
    '  SortOrder INTEGER DEFAULT 0,' +
    '  Extra TEXT,' +
    '  Remarks TEXT' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_languages_enabled ON Languages(IsEnabled);';
  
  SQL_TIER0_LANGUAGES_DATA =
    'INSERT OR IGNORE INTO Languages (LangCode, LangName, NativeName, DateFormat, TimeFormat, IsEnabled, IsDefault, SortOrder) VALUES ' +
    '  (''en-US'', ''English (US)'', ''English'', ''MM/dd/yyyy'', ''h:mm:ss tt'', 1, 1, 0);' + #13#10 +
    'INSERT OR IGNORE INTO Languages (LangCode, LangName, NativeName, DateFormat, TimeFormat, IsEnabled, IsDefault, SortOrder) VALUES ' +
    '  (''zh-CN'', ''Chinese (Simplified)'', ''简体中文'', ''yyyy-MM-dd'', ''HH:mm:ss'', 1, 0, 1);' + #13#10 +
    'INSERT OR IGNORE INTO Languages (LangCode, LangName, NativeName, DateFormat, TimeFormat, IsEnabled, IsDefault, SortOrder) VALUES ' +
    '  (''zh-TW'', ''Chinese (Traditional)'', ''繁體中文'', ''yyyy/MM/dd'', ''HH:mm:ss'', 1, 0, 2);' + #13#10 +
    'INSERT OR IGNORE INTO Languages (LangCode, LangName, NativeName, DateFormat, TimeFormat, IsEnabled, IsDefault, SortOrder) VALUES ' +
    '  (''ja-JP'', ''Japanese'', ''日本語'', ''yyyy/MM/dd'', ''HH:mm:ss'', 1, 0, 3);';
  
  // 5. I18nTexts - Translation texts
  SQL_TIER0_I18N_TEXTS =
    'CREATE TABLE IF NOT EXISTS I18nTexts (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  SourceText TEXT NOT NULL,' +
    '  LangCode TEXT NOT NULL,' +
    '  TranslatedText TEXT,' +
    '  Context TEXT,' +
    '  Module TEXT,' +
    '  IsAutoTranslated INTEGER DEFAULT 0,' +
    '  IsVerified INTEGER DEFAULT 0,' +
    '  LastUsedAt TEXT,' +
    '  Extra TEXT,' +
    '  Remarks TEXT,' +
    '  UNIQUE(SourceText, LangCode)' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_i18n_lang ON I18nTexts(LangCode);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_i18n_source ON I18nTexts(SourceText);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_i18n_module ON I18nTexts(Module);';
  
  SQL_TIER0_I18N_TEXTS_DATA =
    'INSERT OR IGNORE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) VALUES (''OK'', ''zh-CN'', ''确定'', 1);' + #13#10 +
    'INSERT OR IGNORE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) VALUES (''Cancel'', ''zh-CN'', ''取消'', 1);' + #13#10 +
    'INSERT OR IGNORE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) VALUES (''Save'', ''zh-CN'', ''保存'', 1);' + #13#10 +
    'INSERT OR IGNORE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) VALUES (''Close'', ''zh-CN'', ''关闭'', 1);' + #13#10 +
    'INSERT OR IGNORE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) VALUES (''Error'', ''zh-CN'', ''错误'', 1);' + #13#10 +
    'INSERT OR IGNORE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) VALUES (''Warning'', ''zh-CN'', ''警告'', 1);' + #13#10 +
    'INSERT OR IGNORE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) VALUES (''Information'', ''zh-CN'', ''信息'', 1);' + #13#10 +
    'INSERT OR IGNORE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) VALUES (''Confirm'', ''zh-CN'', ''确认'', 1);';

  // ============================================================================
  // Tier 1: Recommended Tables (7 tables)
  // Tables: Logs, MRU, Hotkeys, Queries, Themes, Categories, Tags
  // ============================================================================
  
  // 6. Logs - Application logging
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
    '  UserId TEXT,' +
    '  SessionId TEXT,' +
    '  MachineName TEXT,' +
    '  Extra TEXT,' +
    '  Remarks TEXT' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_logs_time ON Logs(LogTime DESC);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_logs_level ON Logs(LogLevel);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_logs_source ON Logs(Source);';
  
  // 7. MRU - Most Recently Used items
  SQL_TIER1_MRU =
    'CREATE TABLE IF NOT EXISTS MRU (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  Category TEXT NOT NULL DEFAULT ''File'',' +
    '  ItemPath TEXT NOT NULL,' +
    '  DisplayName TEXT,' +
    '  IconIndex INTEGER DEFAULT 0,' +
    '  IsPinned INTEGER DEFAULT 0,' +
    '  AccessCount INTEGER DEFAULT 1,' +
    '  LastAccess TEXT DEFAULT (datetime(''now'')),' +
    '  CreatedAt TEXT DEFAULT (datetime(''now'')),' +
    '  Extra TEXT,' +
    '  Remarks TEXT,' +
    '  UNIQUE(Category, ItemPath)' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_mru_category ON MRU(Category);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_mru_access ON MRU(LastAccess DESC);';
  
  // 8. Hotkeys - Keyboard shortcuts
  SQL_TIER1_HOTKEYS =
    'CREATE TABLE IF NOT EXISTS Hotkeys (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  ActionName TEXT NOT NULL UNIQUE,' +
    '  Shortcut TEXT,' +
    '  DefaultShortcut TEXT,' +
    '  Category TEXT DEFAULT ''General'',' +
    '  Description TEXT,' +
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  IsGlobal INTEGER DEFAULT 0,' +
    '  IsCustom INTEGER DEFAULT 0,' +
    '  SortOrder INTEGER DEFAULT 0,' +
    '  Extra TEXT,' +
    '  Remarks TEXT' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_hotkeys_category ON Hotkeys(Category);';
  
  SQL_TIER1_HOTKEYS_DATA =
    'INSERT OR IGNORE INTO Hotkeys (ActionName, Shortcut, DefaultShortcut, Category, Description) VALUES ' +
    '  (''File.New'', ''Ctrl+N'', ''Ctrl+N'', ''File'', ''Create new file'');' + #13#10 +
    'INSERT OR IGNORE INTO Hotkeys (ActionName, Shortcut, DefaultShortcut, Category, Description) VALUES ' +
    '  (''File.Open'', ''Ctrl+O'', ''Ctrl+O'', ''File'', ''Open file'');' + #13#10 +
    'INSERT OR IGNORE INTO Hotkeys (ActionName, Shortcut, DefaultShortcut, Category, Description) VALUES ' +
    '  (''File.Save'', ''Ctrl+S'', ''Ctrl+S'', ''File'', ''Save file'');' + #13#10 +
    'INSERT OR IGNORE INTO Hotkeys (ActionName, Shortcut, DefaultShortcut, Category, Description) VALUES ' +
    '  (''Edit.Undo'', ''Ctrl+Z'', ''Ctrl+Z'', ''Edit'', ''Undo'');' + #13#10 +
    'INSERT OR IGNORE INTO Hotkeys (ActionName, Shortcut, DefaultShortcut, Category, Description) VALUES ' +
    '  (''Edit.Redo'', ''Ctrl+Y'', ''Ctrl+Y'', ''Edit'', ''Redo'');' + #13#10 +
    'INSERT OR IGNORE INTO Hotkeys (ActionName, Shortcut, DefaultShortcut, Category, Description) VALUES ' +
    '  (''Edit.Copy'', ''Ctrl+C'', ''Ctrl+C'', ''Edit'', ''Copy'');' + #13#10 +
    'INSERT OR IGNORE INTO Hotkeys (ActionName, Shortcut, DefaultShortcut, Category, Description) VALUES ' +
    '  (''Edit.Paste'', ''Ctrl+V'', ''Ctrl+V'', ''Edit'', ''Paste'');' + #13#10 +
    'INSERT OR IGNORE INTO Hotkeys (ActionName, Shortcut, DefaultShortcut, Category, Description) VALUES ' +
    '  (''Edit.Find'', ''Ctrl+F'', ''Ctrl+F'', ''Edit'', ''Find'');';
  
  // 9. Queries - Predefined SQL queries (for doQry)
  SQL_TIER1_QUERIES =
    'CREATE TABLE IF NOT EXISTS Queries (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  Name TEXT NOT NULL UNIQUE,' +
    '  Category TEXT DEFAULT ''General'',' +
    '  Description TEXT,' +
    '  SqlText TEXT NOT NULL,' +
    '  ConnectionName TEXT,' +
    '  Parameters TEXT,' +
    '  ReturnType TEXT DEFAULT ''Dataset'',' +
    '  CacheSeconds INTEGER DEFAULT 0,' +
    '  IsSystem INTEGER DEFAULT 0,' +
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  SortOrder INTEGER DEFAULT 0,' +
    '  CreatedAt TEXT DEFAULT (datetime(''now'')),' +
    '  UpdatedAt TEXT DEFAULT (datetime(''now'')),' +
    '  CreatedBy TEXT,' +
    '  Extra TEXT,' +
    '  Remarks TEXT' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_queries_category ON Queries(Category);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_queries_name ON Queries(Name);';
  
  // 10. Themes - UI themes
  SQL_TIER1_THEMES =
    'CREATE TABLE IF NOT EXISTS Themes (' +
    '  ThemeName TEXT PRIMARY KEY,' +
    '  DisplayName TEXT,' +
    '  Description TEXT,' +
    '  StyleFile TEXT,' +
    '  PreviewImage TEXT,' +
    '  IsDark INTEGER DEFAULT 0,' +
    '  IsBuiltIn INTEGER DEFAULT 1,' +
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  AccentColor TEXT,' +
    '  BackgroundColor TEXT,' +
    '  TextColor TEXT,' +
    '  FontName TEXT,' +
    '  FontSize INTEGER,' +
    '  SortOrder INTEGER DEFAULT 0,' +
    '  Extra TEXT,' +
    '  Remarks TEXT' +
    ');';
  
  SQL_TIER1_THEMES_DATA =
    'INSERT OR IGNORE INTO Themes (ThemeName, DisplayName, IsDark, IsBuiltIn, SortOrder) VALUES ' +
    '  (''Windows'', ''Windows Classic'', 0, 1, 0);' + #13#10 +
    'INSERT OR IGNORE INTO Themes (ThemeName, DisplayName, IsDark, IsBuiltIn, SortOrder) VALUES ' +
    '  (''Windows11'', ''Windows 11'', 0, 1, 1);' + #13#10 +
    'INSERT OR IGNORE INTO Themes (ThemeName, DisplayName, IsDark, IsBuiltIn, SortOrder) VALUES ' +
    '  (''Windows11Dark'', ''Windows 11 Dark'', 1, 1, 2);' + #13#10 +
    'INSERT OR IGNORE INTO Themes (ThemeName, DisplayName, IsDark, IsBuiltIn, SortOrder) VALUES ' +
    '  (''Carbon'', ''Carbon'', 1, 1, 3);' + #13#10 +
    'INSERT OR IGNORE INTO Themes (ThemeName, DisplayName, IsDark, IsBuiltIn, SortOrder) VALUES ' +
    '  (''Aqua'', ''Aqua Light Slate'', 0, 1, 4);';
  
  // 11. Categories - Universal category/enum storage
  SQL_TIER1_CATEGORIES =
    'CREATE TABLE IF NOT EXISTS Categories (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  GroupName TEXT NOT NULL,' +
    '  Code TEXT NOT NULL,' +
    '  Name TEXT NOT NULL,' +
    '  Description TEXT,' +
    '  ParentCode TEXT,' +
    '  IconName TEXT,' +
    '  Color TEXT,' +
    '  SortOrder INTEGER DEFAULT 0,' +
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  IsBuiltIn INTEGER DEFAULT 1,' +
    '  IsDefault INTEGER DEFAULT 0,' +
    '  Extra TEXT,' +
    '  Remarks TEXT,' +
    '  UNIQUE(GroupName, Code)' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_categories_group ON Categories(GroupName);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_categories_parent ON Categories(ParentCode);';
  
  SQL_TIER1_CATEGORIES_DATA =
    'INSERT OR IGNORE INTO Categories (GroupName, Code, Name, Description, SortOrder, IsDefault) VALUES ' +
    '  (''Priority'', ''low'', ''Low'', ''Low priority'', 0, 0);' + #13#10 +
    'INSERT OR IGNORE INTO Categories (GroupName, Code, Name, Description, SortOrder, IsDefault) VALUES ' +
    '  (''Priority'', ''normal'', ''Normal'', ''Normal priority'', 1, 1);' + #13#10 +
    'INSERT OR IGNORE INTO Categories (GroupName, Code, Name, Description, SortOrder, IsDefault) VALUES ' +
    '  (''Priority'', ''high'', ''High'', ''High priority'', 2, 0);' + #13#10 +
    'INSERT OR IGNORE INTO Categories (GroupName, Code, Name, Description, SortOrder, IsDefault) VALUES ' +
    '  (''Priority'', ''urgent'', ''Urgent'', ''Urgent priority'', 3, 0);' + #13#10 +
    'INSERT OR IGNORE INTO Categories (GroupName, Code, Name, Description, SortOrder, IsDefault) VALUES ' +
    '  (''Status'', ''draft'', ''Draft'', ''Draft status'', 0, 1);' + #13#10 +
    'INSERT OR IGNORE INTO Categories (GroupName, Code, Name, Description, SortOrder, IsDefault) VALUES ' +
    '  (''Status'', ''active'', ''Active'', ''Active status'', 1, 0);' + #13#10 +
    'INSERT OR IGNORE INTO Categories (GroupName, Code, Name, Description, SortOrder, IsDefault) VALUES ' +
    '  (''Status'', ''completed'', ''Completed'', ''Completed status'', 2, 0);' + #13#10 +
    'INSERT OR IGNORE INTO Categories (GroupName, Code, Name, Description, SortOrder, IsDefault) VALUES ' +
    '  (''Status'', ''archived'', ''Archived'', ''Archived status'', 3, 0);';
  
  // 12. Tags - Tag system
  SQL_TIER1_TAGS =
    'CREATE TABLE IF NOT EXISTS Tags (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  GroupName TEXT DEFAULT ''Default'',' +
    '  Name TEXT NOT NULL,' +
    '  Description TEXT,' +
    '  Color TEXT,' +
    '  IconName TEXT,' +
    '  SortOrder INTEGER DEFAULT 0,' +
    '  UsageCount INTEGER DEFAULT 0,' +
    '  IsBuiltIn INTEGER DEFAULT 0,' +
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  CreatedAt TEXT DEFAULT (datetime(''now'')),' +
    '  Extra TEXT,' +
    '  Remarks TEXT,' +
    '  UNIQUE(GroupName, Name)' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_tags_group ON Tags(GroupName);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_tags_usage ON Tags(UsageCount DESC);';

  // ============================================================================
  // Tier 2: Extended Tables (11 tables)
  // Tables: Providers, Models, LLMConfig, LLMCalls, LLMPrompts, LLMApiKeys,
  //         ExceptionReports, AnimationAssets, Attachments, TagMappings, Notifications
  // ============================================================================
  
  // 13. Providers - LLM service providers
  SQL_TIER2_PROVIDERS =
    'CREATE TABLE IF NOT EXISTS Providers (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  Code TEXT NOT NULL UNIQUE,' +
    '  Name TEXT NOT NULL,' +
    '  Description TEXT,' +
    '  BaseUrl TEXT,' +
    '  DefaultModel TEXT,' +
    '  AuthType TEXT DEFAULT ''Bearer'',' +
    '  AuthHeader TEXT DEFAULT ''Authorization'',' +
    '  ChatEndpoint TEXT DEFAULT ''/chat/completions'',' +
    '  ModelsEndpoint TEXT DEFAULT ''/models'',' +
    '  SupportsStreaming INTEGER DEFAULT 1,' +
    '  SupportsVision INTEGER DEFAULT 0,' +
    '  SupportsTools INTEGER DEFAULT 0,' +
    '  RateLimitRPM INTEGER,' +
    '  RateLimitTPM INTEGER,' +
    '  Website TEXT,' +
    '  DocsUrl TEXT,' +
    '  IconName TEXT,' +
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  IsBuiltIn INTEGER DEFAULT 1,' +
    '  SortOrder INTEGER DEFAULT 0,' +
    '  Extra TEXT,' +
    '  Remarks TEXT' +
    ');';
  
  SQL_TIER2_PROVIDERS_DATA =
    'INSERT OR IGNORE INTO Providers (Code, Name, Description, BaseUrl, DefaultModel, SupportsStreaming, SupportsVision, SupportsTools, Website, SortOrder) VALUES ' +
    '  (''openai'', ''OpenAI'', ''OpenAI GPT models'', ''https://api.openai.com/v1'', ''gpt-4o-mini'', 1, 1, 1, ''https://openai.com'', 10);' + #13#10 +
    'INSERT OR IGNORE INTO Providers (Code, Name, Description, BaseUrl, DefaultModel, SupportsStreaming, SupportsVision, SupportsTools, Website, SortOrder) VALUES ' +
    '  (''anthropic'', ''Anthropic'', ''Claude AI models'', ''https://api.anthropic.com/v1'', ''claude-3-5-sonnet-latest'', 1, 1, 1, ''https://anthropic.com'', 20);' + #13#10 +
    'INSERT OR IGNORE INTO Providers (Code, Name, Description, BaseUrl, DefaultModel, SupportsStreaming, SupportsVision, SupportsTools, Website, SortOrder) VALUES ' +
    '  (''ollama'', ''Ollama'', ''Run LLMs locally'', ''http://localhost:11434'', ''llama3.1'', 1, 0, 0, ''https://ollama.ai'', 40);' + #13#10 +
    'INSERT OR IGNORE INTO Providers (Code, Name, Description, BaseUrl, DefaultModel, SupportsStreaming, SupportsVision, SupportsTools, Website, SortOrder) VALUES ' +
    '  (''deepseek'', ''DeepSeek'', ''DeepSeek AI models'', ''https://api.deepseek.com/v1'', ''deepseek-chat'', 1, 0, 0, ''https://deepseek.com'', 50);';
  
  // 14. Models - LLM models metadata
  SQL_TIER2_MODELS =
    'CREATE TABLE IF NOT EXISTS Models (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  ProviderCode TEXT NOT NULL,' +
    '  ModelId TEXT NOT NULL,' +
    '  DisplayName TEXT,' +
    '  Description TEXT,' +
    '  ModelFamily TEXT,' +
    '  ContextWindow INTEGER DEFAULT 4096,' +
    '  MaxOutputTokens INTEGER DEFAULT 4096,' +
    '  InputPricePer1M REAL DEFAULT 0,' +
    '  OutputPricePer1M REAL DEFAULT 0,' +
    '  SupportsVision INTEGER DEFAULT 0,' +
    '  SupportsTools INTEGER DEFAULT 0,' +
    '  SupportsStreaming INTEGER DEFAULT 1,' +
    '  SupportsJson INTEGER DEFAULT 0,' +
    '  IsChat INTEGER DEFAULT 1,' +
    '  IsEmbedding INTEGER DEFAULT 0,' +
    '  IsDeprecated INTEGER DEFAULT 0,' +
    '  DeprecationDate TEXT,' +
    '  ReleaseDate TEXT,' +
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  IsBuiltIn INTEGER DEFAULT 1,' +
    '  SortOrder INTEGER DEFAULT 0,' +
    '  Extra TEXT,' +
    '  Remarks TEXT,' +
    '  UNIQUE(ProviderCode, ModelId)' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_models_provider ON Models(ProviderCode);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_models_family ON Models(ModelFamily);';
  
  SQL_TIER2_MODELS_DATA =
    'INSERT OR IGNORE INTO Models (ProviderCode, ModelId, DisplayName, ModelFamily, ContextWindow, MaxOutputTokens, InputPricePer1M, OutputPricePer1M, SupportsVision, SupportsTools, SortOrder) VALUES ' +
    '  (''openai'', ''gpt-4o'', ''GPT-4o'', ''gpt-4o'', 128000, 16384, 2.5, 10.0, 1, 1, 10);' + #13#10 +
    'INSERT OR IGNORE INTO Models (ProviderCode, ModelId, DisplayName, ModelFamily, ContextWindow, MaxOutputTokens, InputPricePer1M, OutputPricePer1M, SupportsVision, SupportsTools, SortOrder) VALUES ' +
    '  (''openai'', ''gpt-4o-mini'', ''GPT-4o Mini'', ''gpt-4o'', 128000, 16384, 0.15, 0.6, 1, 1, 11);' + #13#10 +
    'INSERT OR IGNORE INTO Models (ProviderCode, ModelId, DisplayName, ModelFamily, ContextWindow, MaxOutputTokens, InputPricePer1M, OutputPricePer1M, SupportsVision, SupportsTools, SortOrder) VALUES ' +
    '  (''anthropic'', ''claude-3-5-sonnet-latest'', ''Claude 3.5 Sonnet'', ''claude-3.5'', 200000, 8192, 3.0, 15.0, 1, 1, 10);' + #13#10 +
    'INSERT OR IGNORE INTO Models (ProviderCode, ModelId, DisplayName, ModelFamily, ContextWindow, MaxOutputTokens, InputPricePer1M, OutputPricePer1M, SupportsVision, SupportsTools, SortOrder) VALUES ' +
    '  (''deepseek'', ''deepseek-chat'', ''DeepSeek Chat'', ''deepseek'', 64000, 8192, 0.14, 0.28, 0, 0, 10);';
  
  // 15. LLMConfig - LLM configurations
  SQL_TIER2_LLM_CONFIG =
    'CREATE TABLE IF NOT EXISTS LLMConfig (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  Name TEXT NOT NULL UNIQUE,' +
    '  Description TEXT,' +
    '  ProviderCode TEXT NOT NULL,' +
    '  ModelId TEXT NOT NULL,' +
    '  BaseUrl TEXT,' +
    '  ApiKeyRef TEXT,' +
    '  MaxTokens INTEGER DEFAULT 4096,' +
    '  Temperature REAL DEFAULT 0.7,' +
    '  TopP REAL DEFAULT 1.0,' +
    '  FrequencyPenalty REAL DEFAULT 0,' +
    '  PresencePenalty REAL DEFAULT 0,' +
    '  SystemPrompt TEXT,' +
    '  StopSequences TEXT,' +
    '  TimeoutMs INTEGER DEFAULT 60000,' +
    '  RetryCount INTEGER DEFAULT 3,' +
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  IsDefault INTEGER DEFAULT 0,' +
    '  SortOrder INTEGER DEFAULT 0,' +
    '  CreatedAt TEXT DEFAULT (datetime(''now'')),' +
    '  UpdatedAt TEXT DEFAULT (datetime(''now'')),' +
    '  Extra TEXT,' +
    '  Remarks TEXT' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_llmconfig_provider ON LLMConfig(ProviderCode);';
  
  SQL_TIER2_LLM_CONFIG_DATA =
    'INSERT OR IGNORE INTO LLMConfig (Name, Description, ProviderCode, ModelId, Temperature, IsDefault, SortOrder) VALUES ' +
    '  (''Default'', ''Default configuration'', ''openai'', ''gpt-4o-mini'', 0.7, 1, 10);' + #13#10 +
    'INSERT OR IGNORE INTO LLMConfig (Name, Description, ProviderCode, ModelId, Temperature, IsDefault, SortOrder) VALUES ' +
    '  (''Creative'', ''Creative writing'', ''openai'', ''gpt-4o'', 0.9, 0, 20);' + #13#10 +
    'INSERT OR IGNORE INTO LLMConfig (Name, Description, ProviderCode, ModelId, Temperature, IsDefault, SortOrder) VALUES ' +
    '  (''Precise'', ''Precise/coding tasks'', ''openai'', ''gpt-4o'', 0.2, 0, 30);';
  
  // 16. LLMCalls - LLM API call history
  SQL_TIER2_LLM_CALLS =
    'CREATE TABLE IF NOT EXISTS LLMCalls (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  ConfigName TEXT,' +
    '  ProviderCode TEXT NOT NULL,' +
    '  ModelId TEXT NOT NULL,' +
    '  SystemPrompt TEXT,' +
    '  UserPrompt TEXT,' +
    '  AssistantResponse TEXT,' +
    '  FinishReason TEXT,' +
    '  InputTokens INTEGER DEFAULT 0,' +
    '  OutputTokens INTEGER DEFAULT 0,' +
    '  TotalTokens INTEGER DEFAULT 0,' +
    '  EstimatedCost REAL DEFAULT 0,' +
    '  DurationMs INTEGER DEFAULT 0,' +
    '  FirstTokenMs INTEGER,' +
    '  Success INTEGER DEFAULT 1,' +
    '  ErrorCode TEXT,' +
    '  ErrorMessage TEXT,' +
    '  CallerModule TEXT,' +
    '  CallerFunction TEXT,' +
    '  SessionId TEXT,' +
    '  RequestId TEXT,' +
    '  CallTime TEXT DEFAULT (datetime(''now'')),' +
    '  Extra TEXT,' +
    '  Remarks TEXT' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_llmcalls_time ON LLMCalls(CallTime DESC);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_llmcalls_config ON LLMCalls(ConfigName);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_llmcalls_success ON LLMCalls(Success);';
  
  // 17. LLMPrompts - Prompt templates
  SQL_TIER2_LLM_PROMPTS =
    'CREATE TABLE IF NOT EXISTS LLMPrompts (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  Name TEXT NOT NULL UNIQUE,' +
    '  Category TEXT DEFAULT ''General'',' +
    '  Description TEXT,' +
    '  SystemPrompt TEXT,' +
    '  UserPromptTemplate TEXT NOT NULL,' +
    '  Variables TEXT,' +
    '  DefaultValues TEXT,' +
    '  OutputFormat TEXT DEFAULT ''text'',' +
    '  RecommendedModel TEXT,' +
    '  Temperature REAL,' +
    '  MaxTokens INTEGER,' +
    '  Examples TEXT,' +
    '  ParentTemplate TEXT,' +
    '  Version INTEGER DEFAULT 1,' +
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  IsBuiltIn INTEGER DEFAULT 1,' +
    '  SortOrder INTEGER DEFAULT 0,' +
    '  CreatedAt TEXT DEFAULT (datetime(''now'')),' +
    '  UpdatedAt TEXT DEFAULT (datetime(''now'')),' +
    '  CreatedBy TEXT,' +
    '  Extra TEXT,' +
    '  Remarks TEXT' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_llmprompts_category ON LLMPrompts(Category);';
  
  SQL_TIER2_LLM_PROMPTS_DATA =
    'INSERT OR IGNORE INTO LLMPrompts (Name, Category, Description, SystemPrompt, UserPromptTemplate, Variables, Temperature, IsBuiltIn) VALUES ' +
    '  (''translate_text'', ''Translation'', ''Translate text between languages'', ' +
    '   ''You are a professional translator. Translate accurately while preserving meaning and tone.'', ' +
    '   ''Translate the following text from {{source_lang}} to {{target_lang}}:'' || char(10) || char(10) || ''{{text}}'', ' +
    '   ''["source_lang", "target_lang", "text"]'', 0.3, 1);' + #13#10 +
    'INSERT OR IGNORE INTO LLMPrompts (Name, Category, Description, SystemPrompt, UserPromptTemplate, Variables, Temperature, IsBuiltIn) VALUES ' +
    '  (''summarize'', ''Writing'', ''Summarize text'', ' +
    '   ''You are a helpful assistant that summarizes text concisely.'', ' +
    '   ''Summarize the following text in {{length}} sentences:'' || char(10) || char(10) || ''{{text}}'', ' +
    '   ''["length", "text"]'', 0.5, 1);' + #13#10 +
    'INSERT OR IGNORE INTO LLMPrompts (Name, Category, Description, SystemPrompt, UserPromptTemplate, Variables, Temperature, IsBuiltIn) VALUES ' +
    '  (''explain_code'', ''Code'', ''Explain code'', ' +
    '   ''You are an expert programmer. Explain code clearly.'', ' +
    '   ''Explain the following {{language}} code:'' || char(10) || char(10) || ''```{{language}}'' || char(10) || ''{{code}}'' || char(10) || ''```'', ' +
    '   ''["language", "code"]'', 0.3, 1);';
  
  // 18. LLMApiKeys - API key storage (encrypted)
  SQL_TIER2_LLM_API_KEYS =
    'CREATE TABLE IF NOT EXISTS LLMApiKeys (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  Name TEXT NOT NULL UNIQUE,' +
    '  ProviderCode TEXT NOT NULL,' +
    '  ApiKey TEXT NOT NULL,' +
    '  OrgId TEXT,' +
    '  IsEncrypted INTEGER DEFAULT 1,' +
    '  EncryptionMethod TEXT DEFAULT ''DPAPI'',' +
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  IsDefault INTEGER DEFAULT 0,' +
    '  UsageCount INTEGER DEFAULT 0,' +
    '  LastUsedAt TEXT,' +
    '  ExpiresAt TEXT,' +
    '  CreatedAt TEXT DEFAULT (datetime(''now'')),' +
    '  UpdatedAt TEXT DEFAULT (datetime(''now'')),' +
    '  Extra TEXT,' +
    '  Remarks TEXT' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_apikeys_provider ON LLMApiKeys(ProviderCode);';
  
  // 19. ExceptionReports - Exception/crash reports
  SQL_TIER2_EXCEPTION_REPORTS =
    'CREATE TABLE IF NOT EXISTS ExceptionReports (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  ExceptionClass TEXT NOT NULL,' +
    '  ExceptionMessage TEXT NOT NULL,' +
    '  StackTrace TEXT,' +
    '  Module TEXT,' +
    '  UnitName TEXT,' +
    '  ClassName TEXT,' +
    '  MethodName TEXT,' +
    '  LineNumber INTEGER,' +
    '  AppVersion TEXT,' +
    '  OSVersion TEXT,' +
    '  MachineName TEXT,' +
    '  UserName TEXT,' +
    '  ProcessId INTEGER,' +
    '  ThreadId INTEGER,' +
    '  UserAction TEXT,' +
    '  FormName TEXT,' +
    '  ControlName TEXT,' +
    '  Severity INTEGER DEFAULT 2,' +
    '  IsHandled INTEGER DEFAULT 0,' +
    '  IsReported INTEGER DEFAULT 0,' +
    '  ReportedAt TEXT,' +
    '  Resolution TEXT,' +
    '  OccurredAt TEXT DEFAULT (datetime(''now'')),' +
    '  Extra TEXT,' +
    '  Remarks TEXT' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_exceptions_time ON ExceptionReports(OccurredAt DESC);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_exceptions_class ON ExceptionReports(ExceptionClass);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_exceptions_severity ON ExceptionReports(Severity);';
  
  // 20. AnimationAssets - SVG/Lottie animations
  SQL_TIER2_ANIMATION_ASSETS =
    'CREATE TABLE IF NOT EXISTS AnimationAssets (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  Name TEXT NOT NULL UNIQUE,' +
    '  DisplayName TEXT,' +
    '  Category TEXT DEFAULT ''General'',' +
    '  Description TEXT,' +
    '  AssetType TEXT DEFAULT ''svg'',' +
    '  Content TEXT,' +
    '  FilePath TEXT,' +
    '  ContentHash TEXT,' +
    '  Width INTEGER DEFAULT 64,' +
    '  Height INTEGER DEFAULT 64,' +
    '  FrameCount INTEGER DEFAULT 1,' +
    '  FrameDuration INTEGER DEFAULT 100,' +
    '  Duration INTEGER,' +
    '  LoopCount INTEGER DEFAULT -1,' +
    '  Author TEXT,' +
    '  License TEXT,' +
    '  SourceUrl TEXT,' +
    '  IsEnabled INTEGER DEFAULT 1,' +
    '  IsBuiltIn INTEGER DEFAULT 1,' +
    '  SortOrder INTEGER DEFAULT 0,' +
    '  CreatedAt TEXT DEFAULT (datetime(''now'')),' +
    '  Extra TEXT,' +
    '  Remarks TEXT' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_animations_category ON AnimationAssets(Category);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_animations_type ON AnimationAssets(AssetType);';
  
  // 21. Attachments - File attachments
  SQL_TIER2_ATTACHMENTS =
    'CREATE TABLE IF NOT EXISTS Attachments (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  RefType TEXT NOT NULL,' +
    '  RefId TEXT NOT NULL,' +
    '  FileName TEXT NOT NULL,' +
    '  OriginalName TEXT,' +
    '  FilePath TEXT,' +
    '  FileSize INTEGER DEFAULT 0,' +
    '  MimeType TEXT,' +
    '  ContentHash TEXT,' +
    '  ThumbnailPath TEXT,' +
    '  IsEmbedded INTEGER DEFAULT 0,' +
    '  Content BLOB,' +
    '  Description TEXT,' +
    '  UploadedBy TEXT,' +
    '  UploadedAt TEXT DEFAULT (datetime(''now'')),' +
    '  CreatedAt TEXT DEFAULT (datetime(''now'')),' +
    '  Extra TEXT,' +
    '  Remarks TEXT' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_attachments_ref ON Attachments(RefType, RefId);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_attachments_hash ON Attachments(ContentHash);';
  
  // 22. TagMappings - Tag associations
  SQL_TIER2_TAG_MAPPINGS =
    'CREATE TABLE IF NOT EXISTS TagMappings (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  TagId INTEGER NOT NULL,' +
    '  RefType TEXT NOT NULL,' +
    '  RefId TEXT NOT NULL,' +
    '  CreatedAt TEXT DEFAULT (datetime(''now'')),' +
    '  CreatedBy TEXT,' +
    '  Extra TEXT,' +
    '  Remarks TEXT,' +
    '  UNIQUE(TagId, RefType, RefId),' +
    '  FOREIGN KEY (TagId) REFERENCES Tags(Id) ON DELETE CASCADE' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_tagmappings_tag ON TagMappings(TagId);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_tagmappings_ref ON TagMappings(RefType, RefId);';
  
  // 23. Notifications - User notifications
  SQL_TIER2_NOTIFICATIONS =
    'CREATE TABLE IF NOT EXISTS Notifications (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  Type TEXT DEFAULT ''Info'',' +
    '  Title TEXT NOT NULL,' +
    '  Content TEXT,' +
    '  Source TEXT,' +
    '  RefType TEXT,' +
    '  RefId TEXT,' +
    '  ActionUrl TEXT,' +
    '  IconName TEXT,' +
    '  IsRead INTEGER DEFAULT 0,' +
    '  ReadAt TEXT,' +
    '  IsDismissed INTEGER DEFAULT 0,' +
    '  DismissedAt TEXT,' +
    '  ExpiresAt TEXT,' +
    '  Priority INTEGER DEFAULT 0,' +
    '  UserId TEXT,' +
    '  CreatedAt TEXT DEFAULT (datetime(''now'')),' +
    '  Extra TEXT,' +
    '  Remarks TEXT' +
    ');' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_notifications_user ON Notifications(UserId);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_notifications_read ON Notifications(IsRead);' + #13#10 +
    'CREATE INDEX IF NOT EXISTS idx_notifications_time ON Notifications(CreatedAt DESC);';

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
    SQL_TIER1_HOTKEYS + #13#10 + SQL_TIER1_HOTKEYS_DATA + #13#10 +
    SQL_TIER1_QUERIES + #13#10 +
    SQL_TIER1_THEMES + #13#10 + SQL_TIER1_THEMES_DATA + #13#10 +
    SQL_TIER1_CATEGORIES + #13#10 + SQL_TIER1_CATEGORIES_DATA + #13#10 +
    SQL_TIER1_TAGS;
end;

function GetTier2SchemaSQL: string;
begin
  Result :=
    // LLM Infrastructure
    SQL_TIER2_PROVIDERS + #13#10 + SQL_TIER2_PROVIDERS_DATA + #13#10 +
    SQL_TIER2_MODELS + #13#10 + SQL_TIER2_MODELS_DATA + #13#10 +
    SQL_TIER2_LLM_CONFIG + #13#10 + SQL_TIER2_LLM_CONFIG_DATA + #13#10 +
    SQL_TIER2_LLM_CALLS + #13#10 +
    SQL_TIER2_LLM_PROMPTS + #13#10 + SQL_TIER2_LLM_PROMPTS_DATA + #13#10 +
    SQL_TIER2_LLM_API_KEYS + #13#10 +
    // Other Extended Tables
    SQL_TIER2_EXCEPTION_REPORTS + #13#10 +
    SQL_TIER2_ANIMATION_ASSETS + #13#10 +
    SQL_TIER2_ATTACHMENTS + #13#10 +
    SQL_TIER2_TAG_MAPPINGS + #13#10 +
    SQL_TIER2_NOTIFICATIONS;
end;

function GetFullSchemaSQL: string;
begin
  Result := GetTier0SchemaSQL + #13#10 + GetTier1SchemaSQL + #13#10 + GetTier2SchemaSQL;
end;

end.
