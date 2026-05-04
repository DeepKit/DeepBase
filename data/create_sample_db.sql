-- ============================================================================
-- UniBase Sample Config Database
-- Version: 1.0.0
-- Created: 2025-12-05
-- Description: Complete schema for UniBase infrastructure tables
-- Encoding: UTF-8
-- ============================================================================

-- ============================================================================
-- TIER 0: Core Required Tables (5 tables)
-- ============================================================================

-- 1. SchemaInfo - Database version management
CREATE TABLE IF NOT EXISTS SchemaInfo (
  Key TEXT PRIMARY KEY,
  Value TEXT,
  Extra TEXT,
  Remarks TEXT
);

INSERT OR REPLACE INTO SchemaInfo (Key, Value) VALUES ('SchemaVersion', '1.0.0');
INSERT OR REPLACE INTO SchemaInfo (Key, Value) VALUES ('CreatedAt', datetime('now'));
INSERT OR REPLACE INTO SchemaInfo (Key, Value) VALUES ('UniBaseVersion', '1.0.0');

-- 2. Settings - Application configuration storage
CREATE TABLE IF NOT EXISTS Settings (
  Key TEXT PRIMARY KEY,
  Value TEXT,
  ValueType TEXT DEFAULT 'String',
  Category TEXT DEFAULT 'General',
  Description TEXT,
  DefaultValue TEXT,
  IsEncrypted INTEGER DEFAULT 0,
  IsReadOnly INTEGER DEFAULT 0,
  IsSystem INTEGER DEFAULT 0,
  SortOrder INTEGER DEFAULT 0,
  CreatedAt TEXT DEFAULT (datetime('now')),
  UpdatedAt TEXT DEFAULT (datetime('now')),
  Extra TEXT,
  Remarks TEXT
);

CREATE INDEX IF NOT EXISTS idx_settings_category ON Settings(Category);

-- Default settings
INSERT OR IGNORE INTO Settings (Key, Value, ValueType, Category, Description, DefaultValue) VALUES 
  ('App.Language', 'en-US', 'String', 'General', 'Application language', 'en-US'),
  ('App.Theme', 'Windows11', 'String', 'UI', 'Application theme', 'Windows11'),
  ('App.LogLevel', 'INFO', 'String', 'General', 'Logging level', 'INFO'),
  ('App.AutoSave', 'True', 'Boolean', 'General', 'Auto save on exit', 'True'),
  ('App.DebugMode', 'False', 'Boolean', 'General', 'Debug mode', 'False'),
  ('UI.FontSize', '9', 'Integer', 'UI', 'Default font size', '9'),
  ('UI.ShowToolbar', 'True', 'Boolean', 'UI', 'Show main toolbar', 'True'),
  ('UI.ShowStatusBar', 'True', 'Boolean', 'UI', 'Show status bar', 'True'),
  ('LLM.DefaultProvider', 'openai', 'String', 'LLM', 'Default LLM provider', 'openai'),
  ('LLM.DefaultModel', 'gpt-4o-mini', 'String', 'LLM', 'Default LLM model', 'gpt-4o-mini'),
  ('LLM.DefaultTemperature', '0.7', 'Float', 'LLM', 'Default temperature', '0.7'),
  ('Network.Timeout', '60000', 'Integer', 'Network', 'HTTP timeout ms', '60000'),
  ('Network.ProxyEnabled', 'False', 'Boolean', 'Network', 'Use proxy', 'False');

-- 3. FormStates - Window position and state persistence
CREATE TABLE IF NOT EXISTS FormStates (
  FormName TEXT PRIMARY KEY,
  Left INTEGER,
  Top INTEGER,
  Width INTEGER,
  Height INTEGER,
  WindowState INTEGER DEFAULT 0,
  MonitorIndex INTEGER DEFAULT 0,
  Splitters TEXT,
  Columns TEXT,
  TabIndex INTEGER DEFAULT 0,
  ScrollPos TEXT,
  LastAccess TEXT,
  Extra TEXT,
  Remarks TEXT
);

-- 4. Languages - Supported languages definition
CREATE TABLE IF NOT EXISTS Languages (
  LangCode TEXT PRIMARY KEY,
  LangName TEXT NOT NULL,
  NativeName TEXT,
  FlagIcon TEXT,
  DateFormat TEXT,
  TimeFormat TEXT,
  NumberFormat TEXT,
  CurrencySymbol TEXT,
  TextDirection TEXT DEFAULT 'LTR',
  FontFamily TEXT,
  IsEnabled INTEGER DEFAULT 1,
  IsDefault INTEGER DEFAULT 0,
  IsComplete INTEGER DEFAULT 0,
  SortOrder INTEGER DEFAULT 0,
  Extra TEXT,
  Remarks TEXT
);

CREATE INDEX IF NOT EXISTS idx_languages_enabled ON Languages(IsEnabled);

-- Default languages
INSERT OR IGNORE INTO Languages (LangCode, LangName, NativeName, DateFormat, TimeFormat, IsEnabled, IsDefault, SortOrder) VALUES
  ('en-US', 'English (US)', 'English', 'MM/dd/yyyy', 'h:mm:ss tt', 1, 1, 0),
  ('zh-CN', 'Chinese (Simplified)', '简体中文', 'yyyy-MM-dd', 'HH:mm:ss', 1, 0, 1),
  ('zh-TW', 'Chinese (Traditional)', '繁體中文', 'yyyy/MM/dd', 'HH:mm:ss', 1, 0, 2),
  ('ja-JP', 'Japanese', '日本語', 'yyyy/MM/dd', 'HH:mm:ss', 1, 0, 3),
  ('ko-KR', 'Korean', '한국어', 'yyyy-MM-dd', 'HH:mm:ss', 1, 0, 4),
  ('de-DE', 'German', 'Deutsch', 'dd.MM.yyyy', 'HH:mm:ss', 1, 0, 5),
  ('fr-FR', 'French', 'Français', 'dd/MM/yyyy', 'HH:mm:ss', 1, 0, 6),
  ('es-ES', 'Spanish', 'Español', 'dd/MM/yyyy', 'HH:mm:ss', 1, 0, 7);

-- 5. I18nTexts - Translation texts
CREATE TABLE IF NOT EXISTS I18nTexts (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  SourceText TEXT NOT NULL,
  LangCode TEXT NOT NULL,
  TranslatedText TEXT,
  Context TEXT,
  Module TEXT,
  IsAutoTranslated INTEGER DEFAULT 0,
  IsVerified INTEGER DEFAULT 0,
  LastUsedAt TEXT,
  Extra TEXT,
  Remarks TEXT,
  UNIQUE(SourceText, LangCode)
);

CREATE INDEX IF NOT EXISTS idx_i18n_lang ON I18nTexts(LangCode);
CREATE INDEX IF NOT EXISTS idx_i18n_source ON I18nTexts(SourceText);
CREATE INDEX IF NOT EXISTS idx_i18n_module ON I18nTexts(Module);

-- Sample translations
INSERT OR IGNORE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) VALUES
  ('OK', 'zh-CN', '确定', 1),
  ('Cancel', 'zh-CN', '取消', 1),
  ('Save', 'zh-CN', '保存', 1),
  ('Close', 'zh-CN', '关闭', 1),
  ('Error', 'zh-CN', '错误', 1),
  ('Warning', 'zh-CN', '警告', 1),
  ('Information', 'zh-CN', '信息', 1),
  ('Confirm', 'zh-CN', '确认', 1);

-- ============================================================================
-- TIER 1: Recommended Tables (7 tables)
-- ============================================================================

-- 6. Logs - Application logging
CREATE TABLE IF NOT EXISTS Logs (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  LogTime TEXT NOT NULL,
  LogLevel TEXT NOT NULL,
  Source TEXT,
  Message TEXT NOT NULL,
  ExceptionClass TEXT,
  ExceptionMessage TEXT,
  StackTrace TEXT,
  ThreadId INTEGER,
  UserId TEXT,
  SessionId TEXT,
  MachineName TEXT,
  Extra TEXT,
  Remarks TEXT
);

CREATE INDEX IF NOT EXISTS idx_logs_time ON Logs(LogTime DESC);
CREATE INDEX IF NOT EXISTS idx_logs_level ON Logs(LogLevel);
CREATE INDEX IF NOT EXISTS idx_logs_source ON Logs(Source);

-- 7. MRU - Most Recently Used items
CREATE TABLE IF NOT EXISTS MRU (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  Category TEXT NOT NULL DEFAULT 'File',
  ItemKey TEXT NOT NULL,
  DisplayName TEXT,
  IconIndex INTEGER DEFAULT 0,
  IsPinned INTEGER DEFAULT 0,
  AccessCount INTEGER DEFAULT 1,
  LastAccess TEXT DEFAULT (datetime('now')),
  CreatedAt TEXT DEFAULT (datetime('now')),
  Extra TEXT,
  Remarks TEXT,
  UNIQUE(Category, ItemKey)
);

CREATE INDEX IF NOT EXISTS idx_mru_category ON MRU(Category);
CREATE INDEX IF NOT EXISTS idx_mru_access ON MRU(LastAccess DESC);

-- 8. Hotkeys - Keyboard shortcuts
CREATE TABLE IF NOT EXISTS Hotkeys (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  ActionName TEXT NOT NULL UNIQUE,
  Shortcut TEXT,
  DefaultShortcut TEXT,
  Category TEXT DEFAULT 'General',
  Description TEXT,
  IsEnabled INTEGER DEFAULT 1,
  IsGlobal INTEGER DEFAULT 0,
  IsCustomized INTEGER DEFAULT 0,
  SortOrder INTEGER DEFAULT 0,
  Extra TEXT,
  Remarks TEXT
);

CREATE INDEX IF NOT EXISTS idx_hotkeys_category ON Hotkeys(Category);

-- Default hotkeys
INSERT OR IGNORE INTO Hotkeys (ActionName, Shortcut, DefaultShortcut, Category, Description) VALUES
  ('File.New', 'Ctrl+N', 'Ctrl+N', 'File', 'Create new file'),
  ('File.Open', 'Ctrl+O', 'Ctrl+O', 'File', 'Open file'),
  ('File.Save', 'Ctrl+S', 'Ctrl+S', 'File', 'Save file'),
  ('File.SaveAs', 'Ctrl+Shift+S', 'Ctrl+Shift+S', 'File', 'Save file as'),
  ('File.Close', 'Ctrl+W', 'Ctrl+W', 'File', 'Close file'),
  ('Edit.Undo', 'Ctrl+Z', 'Ctrl+Z', 'Edit', 'Undo'),
  ('Edit.Redo', 'Ctrl+Y', 'Ctrl+Y', 'Edit', 'Redo'),
  ('Edit.Cut', 'Ctrl+X', 'Ctrl+X', 'Edit', 'Cut'),
  ('Edit.Copy', 'Ctrl+C', 'Ctrl+C', 'Edit', 'Copy'),
  ('Edit.Paste', 'Ctrl+V', 'Ctrl+V', 'Edit', 'Paste'),
  ('Edit.SelectAll', 'Ctrl+A', 'Ctrl+A', 'Edit', 'Select all'),
  ('Edit.Find', 'Ctrl+F', 'Ctrl+F', 'Edit', 'Find'),
  ('Edit.Replace', 'Ctrl+H', 'Ctrl+H', 'Edit', 'Replace'),
  ('View.Refresh', 'F5', 'F5', 'View', 'Refresh'),
  ('Help.About', 'F1', 'F1', 'Help', 'About');

-- 9. Queries - Predefined SQL queries (for doQry)
CREATE TABLE IF NOT EXISTS Queries (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  Name TEXT NOT NULL UNIQUE,
  Category TEXT DEFAULT 'General',
  Description TEXT,
  SqlText TEXT NOT NULL,
  ConnectionName TEXT,
  Parameters TEXT,
  ReturnType TEXT DEFAULT 'Dataset',
  CacheSeconds INTEGER DEFAULT 0,
  IsSystem INTEGER DEFAULT 0,
  IsEnabled INTEGER DEFAULT 1,
  SortOrder INTEGER DEFAULT 0,
  CreatedAt TEXT DEFAULT (datetime('now')),
  UpdatedAt TEXT DEFAULT (datetime('now')),
  CreatedBy TEXT,
  Extra TEXT,
  Remarks TEXT
);

CREATE INDEX IF NOT EXISTS idx_queries_category ON Queries(Category);
CREATE INDEX IF NOT EXISTS idx_queries_name ON Queries(Name);

-- 10. Themes - UI themes
CREATE TABLE IF NOT EXISTS Themes (
  ThemeName TEXT PRIMARY KEY,
  DisplayName TEXT,
  Description TEXT,
  StyleFile TEXT,
  PreviewImage TEXT,
  IsDark INTEGER DEFAULT 0,
  IsBuiltIn INTEGER DEFAULT 1,
  IsEnabled INTEGER DEFAULT 1,
  AccentColor TEXT,
  BackgroundColor TEXT,
  TextColor TEXT,
  FontName TEXT,
  FontSize INTEGER,
  SortOrder INTEGER DEFAULT 0,
  Extra TEXT,
  Remarks TEXT
);

-- Default themes
INSERT OR IGNORE INTO Themes (ThemeName, DisplayName, IsDark, IsBuiltIn, SortOrder) VALUES
  ('Windows', 'Windows Classic', 0, 1, 0),
  ('Windows11', 'Windows 11', 0, 1, 1),
  ('Windows11Dark', 'Windows 11 Dark', 1, 1, 2),
  ('Carbon', 'Carbon', 1, 1, 3),
  ('Aqua', 'Aqua Light Slate', 0, 1, 4);

-- 11. Categories - Universal category/enum storage
CREATE TABLE IF NOT EXISTS Categories (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  GroupName TEXT NOT NULL,
  Code TEXT NOT NULL,
  Name TEXT NOT NULL,
  Description TEXT,
  ParentCode TEXT,
  IconName TEXT,
  Color TEXT,
  SortOrder INTEGER DEFAULT 0,
  IsEnabled INTEGER DEFAULT 1,
  IsBuiltIn INTEGER DEFAULT 1,
  IsDefault INTEGER DEFAULT 0,
  Extra TEXT,
  Remarks TEXT,
  UNIQUE(GroupName, Code)
);

CREATE INDEX IF NOT EXISTS idx_categories_group ON Categories(GroupName);
CREATE INDEX IF NOT EXISTS idx_categories_parent ON Categories(ParentCode);

-- Sample categories
INSERT OR IGNORE INTO Categories (GroupName, Code, Name, Description, SortOrder, IsDefault) VALUES
  ('Priority', 'low', 'Low', 'Low priority', 0, 0),
  ('Priority', 'normal', 'Normal', 'Normal priority', 1, 1),
  ('Priority', 'high', 'High', 'High priority', 2, 0),
  ('Priority', 'urgent', 'Urgent', 'Urgent priority', 3, 0),
  ('Status', 'draft', 'Draft', 'Draft status', 0, 1),
  ('Status', 'pending', 'Pending', 'Pending status', 1, 0),
  ('Status', 'active', 'Active', 'Active status', 2, 0),
  ('Status', 'completed', 'Completed', 'Completed status', 3, 0),
  ('Status', 'archived', 'Archived', 'Archived status', 4, 0),
  ('LogLevel', 'debug', 'Debug', 'Debug level', 0, 0),
  ('LogLevel', 'info', 'Info', 'Info level', 1, 1),
  ('LogLevel', 'warn', 'Warning', 'Warning level', 2, 0),
  ('LogLevel', 'error', 'Error', 'Error level', 3, 0),
  ('LogLevel', 'fatal', 'Fatal', 'Fatal level', 4, 0);

-- 12. Tags - Tag system
CREATE TABLE IF NOT EXISTS Tags (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  GroupName TEXT DEFAULT 'Default',
  Name TEXT NOT NULL,
  Description TEXT,
  Color TEXT,
  IconName TEXT,
  SortOrder INTEGER DEFAULT 0,
  UsageCount INTEGER DEFAULT 0,
  IsBuiltIn INTEGER DEFAULT 0,
  IsEnabled INTEGER DEFAULT 1,
  CreatedAt TEXT DEFAULT (datetime('now')),
  Extra TEXT,
  Remarks TEXT,
  UNIQUE(GroupName, Name)
);

CREATE INDEX IF NOT EXISTS idx_tags_group ON Tags(GroupName);
CREATE INDEX IF NOT EXISTS idx_tags_usage ON Tags(UsageCount DESC);

-- ============================================================================
-- TIER 2: Extended Tables (12 tables)
-- ============================================================================

-- 13. Providers - LLM service providers
CREATE TABLE IF NOT EXISTS Providers (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  Code TEXT NOT NULL UNIQUE,
  Name TEXT NOT NULL,
  Description TEXT,
  BaseUrl TEXT,
  DefaultModel TEXT,
  AuthType TEXT DEFAULT 'Bearer',
  AuthHeader TEXT DEFAULT 'Authorization',
  ChatEndpoint TEXT DEFAULT '/chat/completions',
  ModelsEndpoint TEXT DEFAULT '/models',
  SupportsStreaming INTEGER DEFAULT 1,
  SupportsVision INTEGER DEFAULT 0,
  SupportsTools INTEGER DEFAULT 0,
  RateLimitRPM INTEGER,
  RateLimitTPM INTEGER,
  Website TEXT,
  DocsUrl TEXT,
  IconName TEXT,
  IsEnabled INTEGER DEFAULT 1,
  IsBuiltIn INTEGER DEFAULT 1,
  SortOrder INTEGER DEFAULT 0,
  Extra TEXT,
  Remarks TEXT
);

-- Default providers
INSERT OR IGNORE INTO Providers (Code, Name, Description, BaseUrl, DefaultModel, SupportsStreaming, SupportsVision, SupportsTools, Website, SortOrder) VALUES
  ('openai', 'OpenAI', 'OpenAI GPT models', 'https://api.openai.com/v1', 'gpt-4o-mini', 1, 1, 1, 'https://openai.com', 10),
  ('anthropic', 'Anthropic', 'Claude AI models', 'https://api.anthropic.com/v1', 'claude-3-5-sonnet-latest', 1, 1, 1, 'https://anthropic.com', 20),
  ('azure', 'Azure OpenAI', 'Microsoft Azure OpenAI', '', '', 1, 1, 1, 'https://azure.microsoft.com', 30),
  ('ollama', 'Ollama', 'Run LLMs locally', 'http://localhost:11434', 'llama3.1', 1, 0, 0, 'https://ollama.ai', 40),
  ('deepseek', 'DeepSeek', 'DeepSeek AI models', 'https://api.deepseek.com/v1', 'deepseek-chat', 1, 0, 0, 'https://deepseek.com', 50),
  ('groq', 'Groq', 'Fast inference', 'https://api.groq.com/openai/v1', 'llama-3.1-70b-versatile', 1, 0, 1, 'https://groq.com', 60),
  ('litellm', 'LiteLLM', 'LiteLLM Proxy', 'http://localhost:4000', '', 1, 0, 0, 'https://litellm.ai', 70),
  ('custom', 'Custom', 'Custom provider', '', '', 1, 0, 0, '', 999);

-- 14. Models - LLM models metadata
CREATE TABLE IF NOT EXISTS Models (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  ProviderCode TEXT NOT NULL,
  ModelId TEXT NOT NULL,
  DisplayName TEXT,
  Description TEXT,
  ModelFamily TEXT,
  ContextWindow INTEGER DEFAULT 4096,
  MaxOutputTokens INTEGER DEFAULT 4096,
  InputPricePer1M REAL DEFAULT 0,
  OutputPricePer1M REAL DEFAULT 0,
  SupportsVision INTEGER DEFAULT 0,
  SupportsTools INTEGER DEFAULT 0,
  SupportsStreaming INTEGER DEFAULT 1,
  SupportsJson INTEGER DEFAULT 0,
  IsChat INTEGER DEFAULT 1,
  IsEmbedding INTEGER DEFAULT 0,
  IsDeprecated INTEGER DEFAULT 0,
  DeprecationDate TEXT,
  ReleaseDate TEXT,
  IsEnabled INTEGER DEFAULT 1,
  IsBuiltIn INTEGER DEFAULT 1,
  SortOrder INTEGER DEFAULT 0,
  Extra TEXT,
  Remarks TEXT,
  UNIQUE(ProviderCode, ModelId)
);

CREATE INDEX IF NOT EXISTS idx_models_provider ON Models(ProviderCode);
CREATE INDEX IF NOT EXISTS idx_models_family ON Models(ModelFamily);

-- Default models
INSERT OR IGNORE INTO Models (ProviderCode, ModelId, DisplayName, ModelFamily, ContextWindow, MaxOutputTokens, InputPricePer1M, OutputPricePer1M, SupportsVision, SupportsTools, SortOrder) VALUES
  ('openai', 'gpt-4o', 'GPT-4o', 'gpt-4o', 128000, 16384, 2.5, 10.0, 1, 1, 10),
  ('openai', 'gpt-4o-mini', 'GPT-4o Mini', 'gpt-4o', 128000, 16384, 0.15, 0.6, 1, 1, 11),
  ('openai', 'gpt-4-turbo', 'GPT-4 Turbo', 'gpt-4', 128000, 4096, 10.0, 30.0, 1, 1, 20),
  ('anthropic', 'claude-3-5-sonnet-latest', 'Claude 3.5 Sonnet', 'claude-3.5', 200000, 8192, 3.0, 15.0, 1, 1, 10),
  ('anthropic', 'claude-3-5-haiku-latest', 'Claude 3.5 Haiku', 'claude-3.5', 200000, 8192, 1.0, 5.0, 1, 1, 11),
  ('deepseek', 'deepseek-chat', 'DeepSeek Chat', 'deepseek', 64000, 8192, 0.14, 0.28, 0, 0, 10),
  ('deepseek', 'deepseek-reasoner', 'DeepSeek Reasoner', 'deepseek', 64000, 8192, 0.55, 2.19, 0, 0, 11),
  ('ollama', 'llama3.1', 'Llama 3.1', 'llama', 128000, 4096, 0, 0, 0, 0, 10),
  ('ollama', 'qwen2.5', 'Qwen 2.5', 'qwen', 32000, 4096, 0, 0, 0, 0, 20);

-- 15. LLMConfig - LLM configurations
CREATE TABLE IF NOT EXISTS LLMConfig (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  Name TEXT NOT NULL UNIQUE,
  Description TEXT,
  ProviderCode TEXT NOT NULL,
  ModelId TEXT NOT NULL,
  BaseUrl TEXT,
  ApiKeyRef TEXT, -- Credential Manager ref (credman:...) or LLMApiKeys.Name
  MaxTokens INTEGER DEFAULT 4096,
  Temperature REAL DEFAULT 0.7,
  TopP REAL DEFAULT 1.0,
  FrequencyPenalty REAL DEFAULT 0,
  PresencePenalty REAL DEFAULT 0,
  SystemPrompt TEXT,
  StopSequences TEXT,
  TimeoutMs INTEGER DEFAULT 60000,
  RetryCount INTEGER DEFAULT 3,
  IsEnabled INTEGER DEFAULT 1,
  IsDefault INTEGER DEFAULT 0,
  SortOrder INTEGER DEFAULT 0,
  CreatedAt TEXT DEFAULT (datetime('now')),
  UpdatedAt TEXT DEFAULT (datetime('now')),
  Extra TEXT,
  Remarks TEXT
);

CREATE INDEX IF NOT EXISTS idx_llmconfig_provider ON LLMConfig(ProviderCode);

-- Default LLM configs
INSERT OR IGNORE INTO LLMConfig (Name, Description, ProviderCode, ModelId, Temperature, IsDefault, SortOrder) VALUES
  ('Default', 'Default configuration', 'openai', 'gpt-4o-mini', 0.7, 1, 10),
  ('Creative', 'Creative writing', 'openai', 'gpt-4o', 0.9, 0, 20),
  ('Precise', 'Precise/coding tasks', 'openai', 'gpt-4o', 0.2, 0, 30);

-- 16. LLMCalls - LLM API call history
CREATE TABLE IF NOT EXISTS LLMCalls (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  ConfigName TEXT,
  ProviderCode TEXT NOT NULL,
  ModelId TEXT NOT NULL,
  SystemPrompt TEXT,
  UserPrompt TEXT,
  AssistantResponse TEXT,
  FinishReason TEXT,
  InputTokens INTEGER DEFAULT 0,
  OutputTokens INTEGER DEFAULT 0,
  TotalTokens INTEGER DEFAULT 0,
  EstimatedCost REAL DEFAULT 0,
  DurationMs INTEGER DEFAULT 0,
  FirstTokenMs INTEGER,
  Success INTEGER DEFAULT 1,
  ErrorCode TEXT,
  ErrorMessage TEXT,
  CallerModule TEXT,
  CallerFunction TEXT,
  SessionId TEXT,
  RequestId TEXT,
  CallTime TEXT DEFAULT (datetime('now')),
  Extra TEXT,
  Remarks TEXT
);

CREATE INDEX IF NOT EXISTS idx_llmcalls_time ON LLMCalls(CallTime DESC);
CREATE INDEX IF NOT EXISTS idx_llmcalls_config ON LLMCalls(ConfigName);
CREATE INDEX IF NOT EXISTS idx_llmcalls_success ON LLMCalls(Success);

-- 17. LLMPrompts - Prompt templates
CREATE TABLE IF NOT EXISTS LLMPrompts (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  Name TEXT NOT NULL UNIQUE,
  Category TEXT DEFAULT 'General',
  Description TEXT,
  SystemPrompt TEXT,
  UserPromptTemplate TEXT NOT NULL,
  Variables TEXT,
  DefaultValues TEXT,
  OutputFormat TEXT DEFAULT 'text',
  RecommendedModel TEXT,
  Temperature REAL,
  MaxTokens INTEGER,
  Examples TEXT,
  ParentTemplate TEXT,
  Version INTEGER DEFAULT 1,
  IsEnabled INTEGER DEFAULT 1,
  IsBuiltIn INTEGER DEFAULT 1,
  SortOrder INTEGER DEFAULT 0,
  CreatedAt TEXT DEFAULT (datetime('now')),
  UpdatedAt TEXT DEFAULT (datetime('now')),
  CreatedBy TEXT,
  Extra TEXT,
  Remarks TEXT
);

CREATE INDEX IF NOT EXISTS idx_llmprompts_category ON LLMPrompts(Category);

-- Sample prompts
INSERT OR IGNORE INTO LLMPrompts (Name, Category, Description, SystemPrompt, UserPromptTemplate, Variables, Temperature, IsBuiltIn) VALUES
  ('translate_text', 'Translation', 'Translate text between languages', 
   'You are a professional translator. Translate accurately while preserving meaning and tone.',
   'Translate the following text from {{source_lang}} to {{target_lang}}:\n\n{{text}}',
   '["source_lang", "target_lang", "text"]', 0.3, 1),
  ('summarize', 'Writing', 'Summarize text',
   'You are a helpful assistant that summarizes text concisely.',
   'Summarize the following text in {{length}} sentences:\n\n{{text}}',
   '["length", "text"]', 0.5, 1),
  ('explain_code', 'Code', 'Explain code',
   'You are an expert programmer. Explain code clearly.',
   'Explain the following {{language}} code:\n\n```{{language}}\n{{code}}\n```',
   '["language", "code"]', 0.3, 1);

-- 18. LLMApiKeys - API key storage (encrypted)
CREATE TABLE IF NOT EXISTS LLMApiKeys (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  Name TEXT NOT NULL UNIQUE,
  ProviderCode TEXT NOT NULL,
  ApiKey TEXT NOT NULL, -- Credential Manager ref (credman:...)
  OrgId TEXT,
  IsEncrypted INTEGER DEFAULT 1,
  EncryptionMethod TEXT DEFAULT 'CREDMAN',
  IsEnabled INTEGER DEFAULT 1,
  IsDefault INTEGER DEFAULT 0,
  UsageCount INTEGER DEFAULT 0,
  LastUsedAt TEXT,
  ExpiresAt TEXT,
  CreatedAt TEXT DEFAULT (datetime('now')),
  UpdatedAt TEXT DEFAULT (datetime('now')),
  Extra TEXT,
  Remarks TEXT
);

CREATE INDEX IF NOT EXISTS idx_apikeys_provider ON LLMApiKeys(ProviderCode);

-- 19. ExceptionReports - Exception/crash reports
CREATE TABLE IF NOT EXISTS ExceptionReports (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  ExceptionClass TEXT NOT NULL,
  ExceptionMessage TEXT NOT NULL,
  StackTrace TEXT,
  Module TEXT,
  UnitName TEXT,
  ClassName TEXT,
  MethodName TEXT,
  LineNumber INTEGER,
  AppVersion TEXT,
  OSVersion TEXT,
  MachineName TEXT,
  UserName TEXT,
  ProcessId INTEGER,
  ThreadId INTEGER,
  UserAction TEXT,
  FormName TEXT,
  ControlName TEXT,
  Severity INTEGER DEFAULT 2,
  IsHandled INTEGER DEFAULT 0,
  IsReported INTEGER DEFAULT 0,
  ReportedAt TEXT,
  Resolution TEXT,
  OccurredAt TEXT DEFAULT (datetime('now')),
  Extra TEXT,
  Remarks TEXT
);

CREATE INDEX IF NOT EXISTS idx_exceptions_time ON ExceptionReports(OccurredAt DESC);
CREATE INDEX IF NOT EXISTS idx_exceptions_class ON ExceptionReports(ExceptionClass);
CREATE INDEX IF NOT EXISTS idx_exceptions_severity ON ExceptionReports(Severity);

-- 20. AnimationAssets - SVG/Lottie animations
CREATE TABLE IF NOT EXISTS AnimationAssets (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  Name TEXT NOT NULL UNIQUE,
  DisplayName TEXT,
  Category TEXT DEFAULT 'General',
  Description TEXT,
  AssetType TEXT DEFAULT 'svg',
  Content TEXT,
  FilePath TEXT,
  ContentHash TEXT,
  Width INTEGER DEFAULT 64,
  Height INTEGER DEFAULT 64,
  FrameCount INTEGER DEFAULT 1,
  FrameDuration INTEGER DEFAULT 100,
  Duration INTEGER,
  LoopCount INTEGER DEFAULT -1,
  Author TEXT,
  License TEXT,
  SourceUrl TEXT,
  IsEnabled INTEGER DEFAULT 1,
  IsBuiltIn INTEGER DEFAULT 1,
  SortOrder INTEGER DEFAULT 0,
  CreatedAt TEXT DEFAULT (datetime('now')),
  Extra TEXT,
  Remarks TEXT
);

CREATE INDEX IF NOT EXISTS idx_animations_category ON AnimationAssets(Category);
CREATE INDEX IF NOT EXISTS idx_animations_type ON AnimationAssets(AssetType);

-- Sample animations
INSERT OR IGNORE INTO AnimationAssets (Name, DisplayName, Category, AssetType, Content, Width, Height) VALUES
  ('spinner_circle', 'Circle Spinner', 'Loading', 'svg', 
   '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><circle cx="32" cy="32" r="28" fill="none" stroke="#007AFF" stroke-width="4" stroke-dasharray="88 88" stroke-linecap="round"><animateTransform attributeName="transform" type="rotate" from="0 32 32" to="360 32 32" dur="1s" repeatCount="indefinite"/></circle></svg>',
   64, 64),
  ('checkmark', 'Checkmark', 'Success', 'svg',
   '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><circle cx="32" cy="32" r="28" fill="#34C759"/><path d="M20 32 L28 40 L44 24" fill="none" stroke="white" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/></svg>',
   64, 64),
  ('error_cross', 'Error Cross', 'Error', 'svg',
   '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><circle cx="32" cy="32" r="28" fill="#FF3B30"/><path d="M22 22 L42 42 M42 22 L22 42" fill="none" stroke="white" stroke-width="4" stroke-linecap="round"/></svg>',
   64, 64);

-- 21. Attachments - File attachments
CREATE TABLE IF NOT EXISTS Attachments (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  RefType TEXT NOT NULL,
  RefId TEXT NOT NULL,
  FileName TEXT NOT NULL,
  OriginalName TEXT,
  FilePath TEXT,
  FileSize INTEGER DEFAULT 0,
  MimeType TEXT,
  ContentHash TEXT,
  ThumbnailPath TEXT,
  IsEmbedded INTEGER DEFAULT 0,
  Content BLOB,
  Description TEXT,
  UploadedBy TEXT,
  UploadedAt TEXT DEFAULT (datetime('now')),
  CreatedAt TEXT DEFAULT (datetime('now')),
  Extra TEXT,
  Remarks TEXT
);

CREATE INDEX IF NOT EXISTS idx_attachments_ref ON Attachments(RefType, RefId);
CREATE INDEX IF NOT EXISTS idx_attachments_hash ON Attachments(ContentHash);

-- 22. TagMappings - Tag associations
CREATE TABLE IF NOT EXISTS TagMappings (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  TagId INTEGER NOT NULL,
  RefType TEXT NOT NULL,
  RefId TEXT NOT NULL,
  CreatedAt TEXT DEFAULT (datetime('now')),
  CreatedBy TEXT,
  Extra TEXT,
  Remarks TEXT,
  UNIQUE(TagId, RefType, RefId),
  FOREIGN KEY (TagId) REFERENCES Tags(Id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_tagmappings_tag ON TagMappings(TagId);
CREATE INDEX IF NOT EXISTS idx_tagmappings_ref ON TagMappings(RefType, RefId);

-- 23. Notifications - User notifications
CREATE TABLE IF NOT EXISTS Notifications (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  Type TEXT DEFAULT 'Info',
  Title TEXT NOT NULL,
  Content TEXT,
  Source TEXT,
  RefType TEXT,
  RefId TEXT,
  ActionUrl TEXT,
  IconName TEXT,
  IsRead INTEGER DEFAULT 0,
  ReadAt TEXT,
  IsDismissed INTEGER DEFAULT 0,
  DismissedAt TEXT,
  ExpiresAt TEXT,
  Priority INTEGER DEFAULT 0,
  UserId TEXT,
  CreatedAt TEXT DEFAULT (datetime('now')),
  Extra TEXT,
  Remarks TEXT
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON Notifications(UserId);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON Notifications(IsRead);
CREATE INDEX IF NOT EXISTS idx_notifications_time ON Notifications(CreatedAt DESC);

-- 24. aboutMeImages - About/Donation/Official QR images (DB1 optional)
CREATE TABLE IF NOT EXISTS aboutMeImages (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  ImageKey TEXT NOT NULL UNIQUE,
  ImageData BLOB NOT NULL,
  AddressText TEXT,
  Description TEXT,
  Enabled INTEGER NOT NULL DEFAULT 1,
  Sha256Hash TEXT NOT NULL,
  HmacSha256 TEXT NOT NULL,
  Md5Hash TEXT,
  CreatedAt TEXT DEFAULT (datetime('now')),
  UpdatedAt TEXT DEFAULT (datetime('now')),
  Extra TEXT,
  Remarks TEXT
);

CREATE INDEX IF NOT EXISTS idx_aboutmeimages_enabled ON aboutMeImages(Enabled);
CREATE INDEX IF NOT EXISTS idx_aboutmeimages_updated ON aboutMeImages(UpdatedAt DESC);

-- ============================================================================
-- Final: Update schema info
-- ============================================================================
UPDATE SchemaInfo SET Value = datetime('now') WHERE Key = 'CreatedAt';
