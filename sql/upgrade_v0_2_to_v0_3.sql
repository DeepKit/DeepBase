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
