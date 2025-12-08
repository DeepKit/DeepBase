-- ============================================================================
-- UniBase Schema Migration Script: Rename IsCustom to IsCustomized
-- 
-- Description: Fixes column name mismatch between schema and code
-- Date: 2025-12-08
-- Bug: HOTKEYS-001
-- 
-- Usage: 
--   1. Backup your database first
--   2. Run this script using SQLite CLI or UniBase migration API
--
-- Note: SQLite doesn't support ALTER TABLE RENAME COLUMN in older versions,
--       so we recreate the table with the correct schema.
-- ============================================================================

-- Step 1: Rename old table
ALTER TABLE Hotkeys RENAME TO Hotkeys_old;

-- Step 2: Create new table with correct column name
CREATE TABLE Hotkeys (
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

-- Step 3: Copy data from old table to new table
INSERT INTO Hotkeys (Id, ActionName, Shortcut, DefaultShortcut, Category, Description, IsEnabled, IsGlobal, IsCustomized, SortOrder, Extra, Remarks)
SELECT Id, ActionName, Shortcut, DefaultShortcut, Category, Description, IsEnabled, IsGlobal, 
       COALESCE(IsCustom, 0), -- Map old IsCustom to IsCustomized
       SortOrder, Extra, Remarks
FROM Hotkeys_old;

-- Step 4: Recreate index
CREATE INDEX IF NOT EXISTS idx_hotkeys_category ON Hotkeys(Category);

-- Step 5: Drop old table
DROP TABLE Hotkeys_old;

-- Step 6: Update schema version (optional, depends on your versioning strategy)
-- UPDATE SchemaInfo SET Value = '1.0.1' WHERE Key = 'SchemaVersion';

-- ============================================================================
-- Done: Hotkeys table now has IsCustomized column instead of IsCustom
-- ============================================================================
