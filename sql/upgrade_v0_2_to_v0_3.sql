-- ============================================================================
-- UniBase Schema Migration Script: v0.2 -> v0.3
-- 
-- Description: Adds missing columns to support v0.3 features
-- Date: 2025-12-01
-- 
-- Usage: 
--   1. Backup your database first
--   2. Run this script using SQLite CLI or UniBase.Manager.RunMigrationScript
-- ============================================================================

-- === Settings table ===
-- Add ValueType column for type-safe configuration
ALTER TABLE Settings ADD COLUMN ValueType TEXT DEFAULT 'String';
-- Add Category for grouping
ALTER TABLE Settings ADD COLUMN Category TEXT DEFAULT 'General';
-- Add Description for documentation
ALTER TABLE Settings ADD COLUMN Description TEXT;
-- Add IsEncrypted flag
ALTER TABLE Settings ADD COLUMN IsEncrypted INTEGER DEFAULT 0;

-- === Languages table ===
-- Add NativeName (native language name)
ALTER TABLE Languages ADD COLUMN NativeName TEXT;
-- Add FlagIcon for UI display
ALTER TABLE Languages ADD COLUMN FlagIcon TEXT;
-- Add IsEnabled to toggle languages
ALTER TABLE Languages ADD COLUMN IsEnabled INTEGER DEFAULT 1;
-- Add IsDefault flag
ALTER TABLE Languages ADD COLUMN IsDefault INTEGER DEFAULT 0;
-- Add SortOrder for display ordering
ALTER TABLE Languages ADD COLUMN SortOrder INTEGER DEFAULT 0;

-- === Logs table (if using old schema) ===
-- Add LogTime (replaces Timestamp)
ALTER TABLE Logs ADD COLUMN LogTime TEXT;
-- Add LogLevel (replaces Level)
ALTER TABLE Logs ADD COLUMN LogLevel TEXT;
-- Add Source (replaces Module)
ALTER TABLE Logs ADD COLUMN Source TEXT;
-- Add new exception fields
ALTER TABLE Logs ADD COLUMN ExceptionClass TEXT;
ALTER TABLE Logs ADD COLUMN ExceptionMessage TEXT;
ALTER TABLE Logs ADD COLUMN ThreadId INTEGER;
ALTER TABLE Logs ADD COLUMN UserId TEXT;

-- Migrate data from old columns to new (if old columns exist)
UPDATE Logs SET LogTime = Timestamp WHERE LogTime IS NULL AND Timestamp IS NOT NULL;
UPDATE Logs SET LogLevel = Level WHERE LogLevel IS NULL AND Level IS NOT NULL;
UPDATE Logs SET Source = Module WHERE Source IS NULL AND Module IS NOT NULL;

-- === MRU table ===
ALTER TABLE MRU ADD COLUMN DisplayName TEXT;
ALTER TABLE MRU ADD COLUMN IconIndex INTEGER DEFAULT 0;
ALTER TABLE MRU ADD COLUMN IsPinned INTEGER DEFAULT 0;
ALTER TABLE MRU ADD COLUMN Extra TEXT;

-- === FormStates table ===
ALTER TABLE FormStates ADD COLUMN MonitorIndex INTEGER DEFAULT 0;
ALTER TABLE FormStates ADD COLUMN Extra TEXT;

-- === Hotkeys table ===
ALTER TABLE Hotkeys ADD COLUMN Description TEXT;
ALTER TABLE Hotkeys ADD COLUMN Category TEXT;

-- === Themes table ===
ALTER TABLE Themes ADD COLUMN DisplayName TEXT;
ALTER TABLE Themes ADD COLUMN StyleFile TEXT;
ALTER TABLE Themes ADD COLUMN AccentColor INTEGER;
ALTER TABLE Themes ADD COLUMN CustomCSS TEXT;

-- === LLMConfiguration table ===
ALTER TABLE LLMConfiguration ADD COLUMN ContextWindow INTEGER DEFAULT 4096;
ALTER TABLE LLMConfiguration ADD COLUMN PricePer1kPrompt REAL DEFAULT 0;
ALTER TABLE LLMConfiguration ADD COLUMN PricePer1kCompletion REAL DEFAULT 0;

-- === LLMCalls table ===
ALTER TABLE LLMCalls ADD COLUMN CallTime TEXT;
ALTER TABLE LLMCalls ADD COLUMN Prompt TEXT;
ALTER TABLE LLMCalls ADD COLUMN Response TEXT;
ALTER TABLE LLMCalls ADD COLUMN EstimatedCost REAL DEFAULT 0;
ALTER TABLE LLMCalls ADD COLUMN DurationMs INTEGER DEFAULT 0;
ALTER TABLE LLMCalls ADD COLUMN Success INTEGER DEFAULT 1;
ALTER TABLE LLMCalls ADD COLUMN ErrorCode TEXT;
ALTER TABLE LLMCalls ADD COLUMN CallerModule TEXT;
ALTER TABLE LLMCalls ADD COLUMN CallerFunc TEXT;

-- Migrate data from old columns
UPDATE LLMCalls SET CallTime = RequestTime WHERE CallTime IS NULL AND RequestTime IS NOT NULL;
UPDATE LLMCalls SET Prompt = InputText WHERE Prompt IS NULL AND InputText IS NOT NULL;
UPDATE LLMCalls SET Response = OutputText WHERE Response IS NULL AND OutputText IS NOT NULL;
UPDATE LLMCalls SET DurationMs = Duration WHERE DurationMs IS NULL AND Duration IS NOT NULL;
UPDATE LLMCalls SET EstimatedCost = Cost WHERE EstimatedCost IS NULL AND Cost IS NOT NULL;

-- === providers table (LLM infrastructure) ===
CREATE TABLE IF NOT EXISTS providers (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  Code TEXT NOT NULL UNIQUE,
  Name TEXT NOT NULL,
  Description TEXT,
  BaseUrl TEXT,
  DefaultModel TEXT,
  AuthType TEXT DEFAULT 'bearer',
  AuthHeader TEXT DEFAULT 'Authorization',
  ModelsEndpoint TEXT DEFAULT '/models',
  ChatEndpoint TEXT DEFAULT '/chat/completions',
  EmbeddingEndpoint TEXT,
  SupportsStreaming INTEGER DEFAULT 1,
  SupportsVision INTEGER DEFAULT 0,
  SupportsTools INTEGER DEFAULT 0,
  ApiVersion TEXT,
  RateLimitRPM INTEGER,
  RateLimitTPM INTEGER,
  IconFile TEXT,
  Website TEXT,
  DocsUrl TEXT,
  IsEnabled INTEGER DEFAULT 1,
  IsBuiltIn INTEGER DEFAULT 1,
  SortOrder INTEGER DEFAULT 0,
  Extra TEXT
);

CREATE INDEX IF NOT EXISTS idx_providers_code ON providers(Code);
CREATE INDEX IF NOT EXISTS idx_providers_enabled ON providers(IsEnabled);

-- Add new columns to existing providers table if it exists
ALTER TABLE providers ADD COLUMN Description TEXT;
ALTER TABLE providers ADD COLUMN AuthType TEXT DEFAULT 'bearer';
ALTER TABLE providers ADD COLUMN AuthHeader TEXT DEFAULT 'Authorization';
ALTER TABLE providers ADD COLUMN ModelsEndpoint TEXT DEFAULT '/models';
ALTER TABLE providers ADD COLUMN ChatEndpoint TEXT DEFAULT '/chat/completions';
ALTER TABLE providers ADD COLUMN EmbeddingEndpoint TEXT;
ALTER TABLE providers ADD COLUMN SupportsStreaming INTEGER DEFAULT 1;
ALTER TABLE providers ADD COLUMN SupportsVision INTEGER DEFAULT 0;
ALTER TABLE providers ADD COLUMN SupportsTools INTEGER DEFAULT 0;
ALTER TABLE providers ADD COLUMN ApiVersion TEXT;
ALTER TABLE providers ADD COLUMN RateLimitRPM INTEGER;
ALTER TABLE providers ADD COLUMN RateLimitTPM INTEGER;
ALTER TABLE providers ADD COLUMN IconFile TEXT;
ALTER TABLE providers ADD COLUMN Website TEXT;
ALTER TABLE providers ADD COLUMN DocsUrl TEXT;
ALTER TABLE providers ADD COLUMN IsBuiltIn INTEGER DEFAULT 1;

INSERT OR IGNORE INTO providers (Code, Name, Description, BaseUrl, DefaultModel, ChatEndpoint, ModelsEndpoint, SupportsStreaming, SupportsVision, SupportsTools, Website, SortOrder) VALUES
  ('openai', 'OpenAI', 'OpenAI GPT models', 'https://api.openai.com/v1', 'gpt-4o-mini', '/chat/completions', '/models', 1, 1, 1, 'https://openai.com', 10);
INSERT OR IGNORE INTO providers (Code, Name, Description, BaseUrl, DefaultModel, ChatEndpoint, AuthType, SupportsStreaming, SupportsVision, SupportsTools, Website, SortOrder) VALUES
  ('anthropic', 'Anthropic', 'Claude AI models', 'https://api.anthropic.com/v1', 'claude-3-5-sonnet-latest', '/messages', 'apikey', 1, 1, 1, 'https://anthropic.com', 20);
INSERT OR IGNORE INTO providers (Code, Name, Description, BaseUrl, DefaultModel, AuthType, Website, SortOrder) VALUES
  ('azure', 'Azure OpenAI', 'Microsoft Azure OpenAI Service', '', '', 'apikey', 'https://azure.microsoft.com', 30);
INSERT OR IGNORE INTO providers (Code, Name, Description, BaseUrl, DefaultModel, ChatEndpoint, ModelsEndpoint, SupportsStreaming, Website, SortOrder) VALUES
  ('litellm', 'LiteLLM', 'LiteLLM Proxy Server', 'http://localhost:4000', '', '/chat/completions', '/models', 1, 'https://litellm.ai', 40);
INSERT OR IGNORE INTO providers (Code, Name, Description, BaseUrl, DefaultModel, ChatEndpoint, ModelsEndpoint, AuthType, SupportsStreaming, Website, SortOrder) VALUES
  ('ollama', 'Ollama', 'Run LLMs locally', 'http://localhost:11434', 'llama3.1', '/api/chat', '/api/tags', 'none', 1, 'https://ollama.ai', 50);
INSERT OR IGNORE INTO providers (Code, Name, Description, BaseUrl, DefaultModel, SortOrder) VALUES
  ('deepseek', 'DeepSeek', 'DeepSeek AI models', 'https://api.deepseek.com/v1', 'deepseek-chat', 60);
INSERT OR IGNORE INTO providers (Code, Name, Description, BaseUrl, DefaultModel, SortOrder) VALUES
  ('groq', 'Groq', 'Fast inference on Groq hardware', 'https://api.groq.com/openai/v1', 'llama-3.1-70b-versatile', 70);
INSERT OR IGNORE INTO providers (Code, Name, Description, IsBuiltIn, SortOrder) VALUES
  ('custom', 'Custom Provider', 'User-defined provider', 0, 999);

-- === models table (LLM model metadata) ===
CREATE TABLE IF NOT EXISTS models (
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
  CreatedAt TEXT DEFAULT datetime('now'),
  UpdatedAt TEXT DEFAULT datetime('now'),
  Extra TEXT,
  UNIQUE(ProviderCode, ModelId)
);

CREATE INDEX IF NOT EXISTS idx_models_provider ON models(ProviderCode);
CREATE INDEX IF NOT EXISTS idx_models_family ON models(ModelFamily);

-- Preset models
INSERT OR IGNORE INTO models (ProviderCode, ModelId, DisplayName, ModelFamily, ContextWindow, MaxOutputTokens, InputPricePer1M, OutputPricePer1M, SupportsVision, SupportsTools, SupportsJson, SortOrder) VALUES
  ('openai', 'gpt-4o', 'GPT-4o', 'gpt-4o', 128000, 16384, 2.5, 10.0, 1, 1, 1, 10),
  ('openai', 'gpt-4o-mini', 'GPT-4o Mini', 'gpt-4o', 128000, 16384, 0.15, 0.6, 1, 1, 1, 11),
  ('openai', 'gpt-4-turbo', 'GPT-4 Turbo', 'gpt-4', 128000, 4096, 10.0, 30.0, 1, 1, 1, 20),
  ('openai', 'gpt-3.5-turbo', 'GPT-3.5 Turbo', 'gpt-3.5', 16385, 4096, 0.5, 1.5, 0, 1, 0, 30);

INSERT OR IGNORE INTO models (ProviderCode, ModelId, DisplayName, ModelFamily, ContextWindow, MaxOutputTokens, InputPricePer1M, OutputPricePer1M, SupportsVision, SupportsTools, SortOrder) VALUES
  ('anthropic', 'claude-3-5-sonnet-latest', 'Claude 3.5 Sonnet', 'claude-3.5', 200000, 8192, 3.0, 15.0, 1, 1, 10),
  ('anthropic', 'claude-3-5-haiku-latest', 'Claude 3.5 Haiku', 'claude-3.5', 200000, 8192, 1.0, 5.0, 1, 1, 11),
  ('anthropic', 'claude-3-opus-latest', 'Claude 3 Opus', 'claude-3', 200000, 4096, 15.0, 75.0, 1, 1, 20);

INSERT OR IGNORE INTO models (ProviderCode, ModelId, DisplayName, ModelFamily, ContextWindow, MaxOutputTokens, InputPricePer1M, OutputPricePer1M, SortOrder) VALUES
  ('deepseek', 'deepseek-chat', 'DeepSeek Chat', 'deepseek', 64000, 8192, 0.14, 0.28, 10),
  ('deepseek', 'deepseek-reasoner', 'DeepSeek Reasoner', 'deepseek', 64000, 8192, 0.55, 2.19, 11);

INSERT OR IGNORE INTO models (ProviderCode, ModelId, DisplayName, ModelFamily, ContextWindow, InputPricePer1M, OutputPricePer1M, SortOrder) VALUES
  ('ollama', 'llama3.1', 'Llama 3.1', 'llama', 128000, 0, 0, 10),
  ('ollama', 'qwen2.5', 'Qwen 2.5', 'qwen', 32000, 0, 0, 20),
  ('ollama', 'deepseek-r1', 'DeepSeek R1', 'deepseek', 64000, 0, 0, 30);

-- === LLMApiKeys table (API key storage) ===
CREATE TABLE IF NOT EXISTS LLMApiKeys (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  Name TEXT NOT NULL UNIQUE,
  ProviderCode TEXT NOT NULL,
  ApiKey TEXT NOT NULL,
  OrgId TEXT,
  IsEnabled INTEGER DEFAULT 1,
  IsDefault INTEGER DEFAULT 0,
  UsageCount INTEGER DEFAULT 0,
  LastUsedAt TEXT,
  ExpiresAt TEXT,
  CreatedAt TEXT DEFAULT datetime('now'),
  UpdatedAt TEXT DEFAULT datetime('now'),
  Extra TEXT
);

CREATE INDEX IF NOT EXISTS idx_api_keys_provider ON LLMApiKeys(ProviderCode);

-- === LLMPromptTemplates table ===
ALTER TABLE LLMPromptTemplates ADD COLUMN DefaultValues TEXT;
ALTER TABLE LLMPromptTemplates ADD COLUMN ParentTemplate TEXT;
ALTER TABLE LLMPromptTemplates ADD COLUMN IncludeTemplates TEXT;
ALTER TABLE LLMPromptTemplates ADD COLUMN OutputFormat TEXT DEFAULT 'text';
ALTER TABLE LLMPromptTemplates ADD COLUMN ValidationRegex TEXT;
ALTER TABLE LLMPromptTemplates ADD COLUMN Examples TEXT;
ALTER TABLE LLMPromptTemplates ADD COLUMN RecommendedConfig TEXT;
ALTER TABLE LLMPromptTemplates ADD COLUMN RecommendedModel TEXT;
ALTER TABLE LLMPromptTemplates ADD COLUMN MaxTokens INTEGER DEFAULT 0;

-- === Update Schema Version ===
INSERT OR REPLACE INTO SchemaInfo (Key, Value) VALUES ('SchemaVersion', '0.3');
INSERT OR REPLACE INTO SchemaInfo (Key, Value) VALUES ('LastUpgrade', datetime('now'));

-- ============================================================================
-- Migration Complete
-- ============================================================================
