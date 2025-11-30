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
    'INSERT OR REPLACE INTO SchemaInfo VALUES (''SchemaVersion'', ''' + SCHEMA_VERSION + ''');' +
    'INSERT OR REPLACE INTO SchemaInfo VALUES (''CreatedAt'', datetime(''now''));' +
    'INSERT OR REPLACE INTO SchemaInfo VALUES (''LastUpgrade'', datetime(''now''));';
  
  SQL_TIER0_PROJECT_INFO =
    'CREATE TABLE IF NOT EXISTS ProjectInfo (' +
    '  Key TEXT PRIMARY KEY,' +
    '  Value TEXT' +
    ');';
  
  SQL_TIER0_PROJECT_INFO_DATA =
    'INSERT OR REPLACE INTO ProjectInfo VALUES (''ProjectName'', ''MyApp'');' +
    'INSERT OR REPLACE INTO ProjectInfo VALUES (''ProjectVersion'', ''1.0.0'');' +
    'INSERT OR REPLACE INTO ProjectInfo VALUES (''ProjectDescription'', '''');' +
    'INSERT OR REPLACE INTO ProjectInfo VALUES (''ProjectAuthor'', '''');' +
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
    '  VALUES (''App.Language'', ''en-US'', ''String'', ''General'', ''Current language'');' +
    'INSERT OR REPLACE INTO Settings (Key, Value, ValueType, Category, Description) ' +
    '  VALUES (''App.DebugMode'', ''False'', ''Boolean'', ''General'', ''Debug mode enabled'');' +
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
    'INSERT OR REPLACE INTO Languages VALUES (''en-US'', ''English'', ''English'', ''us.png'', 1, 1, 0);' +
    'INSERT OR REPLACE INTO Languages VALUES (''zh-CN'', ''Chinese (Simplified)'', ''简体中文'', ''cn.png'', 1, 0, 1);';
  
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
    ');' +
    'CREATE INDEX IF NOT EXISTS idx_i18n_lang ON I18nTexts(LangCode);' +
    'CREATE INDEX IF NOT EXISTS idx_i18n_source ON I18nTexts(SourceText);';
  
  SQL_TIER0_I18N_TEXTS_DATA =
    'INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) ' +
    '  VALUES (''Welcome'', ''zh-CN'', ''欢迎'', 1);' +
    'INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) ' +
    '  VALUES (''Save'', ''zh-CN'', ''保存'', 1);' +
    'INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) ' +
    '  VALUES (''Cancel'', ''zh-CN'', ''取消'', 1);' +
    'INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) ' +
    '  VALUES (''OK'', ''zh-CN'', ''确定'', 1);' +
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
    ');' +
    'CREATE INDEX IF NOT EXISTS idx_logs_time ON Logs(LogTime);' +
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
    ');' +
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
    '  CreatedAt TEXT DEFAULT (datetime(''now'')),' +
    '  UpdatedAt TEXT DEFAULT (datetime(''now''))' +
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
    '  VALUES (''Windows'', ''Windows'', 0, 1, 0);' +
    'INSERT OR IGNORE INTO Themes (ThemeName, DisplayName, IsDark, IsBuiltIn, SortOrder) ' +
    '  VALUES (''Windows11'', ''Windows 11'', 0, 1, 1);' +
    'INSERT OR IGNORE INTO Themes (ThemeName, DisplayName, IsDark, IsBuiltIn, SortOrder) ' +
    '  VALUES (''Carbon'', ''Carbon (Dark)'', 1, 1, 2);';

  // ============================================================================
  // Tier 2: Optional Tables (Extended Features)
  // Tables: LLMConfiguration, LLMCalls, ExceptionReports, AnimationAssets, TestSnapshots
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
    '  Prompt TEXT,' +
    '  Response TEXT,' +
    '  TokensPrompt INTEGER DEFAULT 0,' +
    '  TokensCompletion INTEGER DEFAULT 0,' +
    '  DurationMs INTEGER,' +
    '  Cost REAL,' +
    '  Status TEXT,' +
    '  ErrorMessage TEXT,' +
    '  TraceId TEXT' +
    ');' +
    'CREATE INDEX IF NOT EXISTS idx_llm_time ON LLMCalls(RequestTime DESC);';
  
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
    SQL_TIER0_SCHEMA_INFO + SQL_TIER0_SCHEMA_INFO_DATA +
    SQL_TIER0_PROJECT_INFO + SQL_TIER0_PROJECT_INFO_DATA +
    SQL_TIER0_SETTINGS + SQL_TIER0_SETTINGS_DATA +
    SQL_TIER0_FORM_STATES +
    SQL_TIER0_LANGUAGES + SQL_TIER0_LANGUAGES_DATA +
    SQL_TIER0_I18N_TEXTS + SQL_TIER0_I18N_TEXTS_DATA;
end;

function GetTier1SchemaSQL: string;
begin
  Result :=
    SQL_TIER1_LOGS +
    SQL_TIER1_MRU +
    SQL_TIER1_HOTKEYS +
    SQL_TIER1_QUERIES +
    SQL_TIER1_THEMES + SQL_TIER1_THEMES_DATA;
end;

function GetTier2SchemaSQL: string;
begin
  Result :=
    SQL_TIER2_LLM_CONFIG + SQL_TIER2_LLM_CONFIG_DATA +
    SQL_TIER2_LLM_CALLS +
    SQL_TIER2_EXCEPTION_REPORTS +
    SQL_TIER2_ANIMATION_ASSETS +
    SQL_TIER2_TEST_SNAPSHOTS;
end;

function GetFullSchemaSQL: string;
begin
  Result := GetTier0SchemaSQL + GetTier1SchemaSQL + GetTier2SchemaSQL;
end;

end.
