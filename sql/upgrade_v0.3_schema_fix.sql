-- ============================================================================
-- UniBase v0.3 Schema 修复脚本
-- 
-- 用途: 修复旧版 SQL 脚本创建的数据库中的表结构不一致问题
-- 执行前请备份数据库！
-- 
-- 执行方法:
--   sqlite3 Config.db < upgrade_v0.3_schema_fix.sql
-- ============================================================================

PRAGMA foreign_keys = OFF;

-- ============================================================================
-- 1. 修复 Logs 表
-- 旧版问题: Level (INTEGER) 应为 LogLevel (TEXT)，缺少多个列
-- ============================================================================

CREATE TABLE IF NOT EXISTS Logs_new (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  LogTime TEXT NOT NULL,
  LogLevel TEXT NOT NULL,
  Source TEXT,
  Message TEXT NOT NULL,
  ExceptionClass TEXT,
  ExceptionMessage TEXT,
  StackTrace TEXT,
  ThreadId INTEGER,
  UserId TEXT
);

-- 尝试从旧表迁移数据（兼容两种 Schema）
INSERT OR IGNORE INTO Logs_new (Id, LogTime, LogLevel, Source, Message, StackTrace, ThreadId)
SELECT 
  Id, 
  COALESCE(LogTime, datetime('now')), 
  CASE 
    WHEN typeof(Level) = 'integer' THEN 
      CASE Level 
        WHEN 0 THEN 'DEBUG' 
        WHEN 1 THEN 'INFO' 
        WHEN 2 THEN 'WARN' 
        WHEN 3 THEN 'ERROR' 
        ELSE 'FATAL' 
      END
    ELSE COALESCE(LogLevel, 'INFO') 
  END,
  Source, 
  Message, 
  StackTrace, 
  ThreadId
FROM Logs;

-- 替换旧表
DROP TABLE IF EXISTS Logs_backup;
ALTER TABLE Logs RENAME TO Logs_backup;
ALTER TABLE Logs_new RENAME TO Logs;

-- 重建索引
DROP INDEX IF EXISTS idx_logs_time;
DROP INDEX IF EXISTS idx_logs_level;
CREATE INDEX idx_logs_time ON Logs(LogTime);
CREATE INDEX idx_logs_level ON Logs(LogLevel);

-- ============================================================================
-- 2. 修复 MRU 表
-- 旧版问题: 列顺序不一致
-- ============================================================================

CREATE TABLE IF NOT EXISTS MRU_new (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  Category TEXT NOT NULL,
  ItemKey TEXT NOT NULL,
  DisplayName TEXT,
  LastAccess TEXT NOT NULL,
  AccessCount INTEGER DEFAULT 1,
  IconIndex INTEGER DEFAULT 0,
  IsPinned INTEGER DEFAULT 0,
  Extra TEXT,
  UNIQUE(Category, ItemKey)
);

INSERT OR IGNORE INTO MRU_new (Id, Category, ItemKey, DisplayName, LastAccess, AccessCount, IconIndex, IsPinned, Extra)
SELECT 
  Id, Category, ItemKey, DisplayName, LastAccess, 
  COALESCE(AccessCount, 1), 
  COALESCE(IconIndex, 0), 
  COALESCE(IsPinned, 0), 
  Extra
FROM MRU;

DROP TABLE IF EXISTS MRU_backup;
ALTER TABLE MRU RENAME TO MRU_backup;
ALTER TABLE MRU_new RENAME TO MRU;

DROP INDEX IF EXISTS idx_mru_category;
DROP INDEX IF EXISTS idx_mru_lastaccess;
DROP INDEX IF EXISTS idx_mru_pinned;
DROP INDEX IF EXISTS idx_mru_category_time;
CREATE INDEX idx_mru_category_time ON MRU(Category, LastAccess DESC);

-- ============================================================================
-- 3. 修复 Hotkeys 表
-- 旧版问题: Shortcut (INTEGER) 应为 (TEXT)，多余列
-- ============================================================================

CREATE TABLE IF NOT EXISTS Hotkeys_new (
  ActionName TEXT PRIMARY KEY,
  Shortcut TEXT NOT NULL,
  Description TEXT,
  Category TEXT
);

INSERT OR IGNORE INTO Hotkeys_new (ActionName, Shortcut, Description, Category)
SELECT 
  ActionName, 
  CASE 
    WHEN typeof(Shortcut) = 'integer' THEN CAST(Shortcut AS TEXT) 
    ELSE Shortcut 
  END,
  Description, 
  Category
FROM Hotkeys;

DROP TABLE IF EXISTS Hotkeys_backup;
ALTER TABLE Hotkeys RENAME TO Hotkeys_backup;
ALTER TABLE Hotkeys_new RENAME TO Hotkeys;

-- ============================================================================
-- 4. 修复 Themes 表
-- 旧版问题: 缺少 AccentColor/CustomCSS，有多余列
-- ============================================================================

CREATE TABLE IF NOT EXISTS Themes_new (
  ThemeName TEXT PRIMARY KEY,
  DisplayName TEXT,
  StyleFile TEXT,
  IsDark INTEGER DEFAULT 0,
  IsBuiltIn INTEGER DEFAULT 1,
  IsEnabled INTEGER DEFAULT 1,
  SortOrder INTEGER DEFAULT 0,
  AccentColor INTEGER,
  CustomCSS TEXT
);

INSERT OR IGNORE INTO Themes_new (ThemeName, DisplayName, StyleFile, IsDark, IsBuiltIn, IsEnabled, SortOrder)
SELECT ThemeName, DisplayName, StyleFile, IsDark, IsBuiltIn, IsEnabled, SortOrder
FROM Themes;

DROP TABLE IF EXISTS Themes_backup;
ALTER TABLE Themes RENAME TO Themes_backup;
ALTER TABLE Themes_new RENAME TO Themes;

-- 插入默认主题（如果不存在）
INSERT OR IGNORE INTO Themes (ThemeName, DisplayName, IsDark, IsBuiltIn, SortOrder) 
  VALUES ('Windows', 'Windows', 0, 1, 0);
INSERT OR IGNORE INTO Themes (ThemeName, DisplayName, IsDark, IsBuiltIn, SortOrder) 
  VALUES ('Windows11', 'Windows 11', 0, 1, 1);
INSERT OR IGNORE INTO Themes (ThemeName, DisplayName, IsDark, IsBuiltIn, SortOrder) 
  VALUES ('Carbon', 'Carbon (Dark)', 1, 1, 2);

-- ============================================================================
-- 5. 确保核心表存在（Tier 0）
-- ============================================================================

CREATE TABLE IF NOT EXISTS SchemaInfo (
  Key TEXT PRIMARY KEY,
  Value TEXT
);

CREATE TABLE IF NOT EXISTS ProjectInfo (
  Key TEXT PRIMARY KEY,
  Value TEXT
);

CREATE TABLE IF NOT EXISTS Settings (
  Key TEXT PRIMARY KEY,
  Value TEXT,
  ValueType TEXT DEFAULT 'String',
  Category TEXT DEFAULT 'General',
  Description TEXT,
  IsEncrypted INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS FormStates (
  FormName TEXT PRIMARY KEY,
  Left INTEGER,
  Top INTEGER,
  Width INTEGER,
  Height INTEGER,
  WindowState INTEGER DEFAULT 0,
  MonitorIndex INTEGER DEFAULT 0,
  Extra TEXT
);

CREATE TABLE IF NOT EXISTS Languages (
  LangCode TEXT PRIMARY KEY,
  LangName TEXT NOT NULL,
  NativeName TEXT,
  FlagIcon TEXT,
  IsEnabled INTEGER DEFAULT 1,
  IsDefault INTEGER DEFAULT 0,
  SortOrder INTEGER DEFAULT 0
);

-- 确保默认语言存在
INSERT OR IGNORE INTO Languages VALUES ('en-US', 'English', 'English', 'us.png', 1, 1, 0);
INSERT OR IGNORE INTO Languages VALUES ('zh-CN', 'Chinese (Simplified)', '简体中文', 'cn.png', 1, 0, 1);

-- ============================================================================
-- 6. 更新 Schema 版本
-- ============================================================================

INSERT OR REPLACE INTO SchemaInfo VALUES ('SchemaVersion', '0.3');
INSERT OR REPLACE INTO SchemaInfo VALUES ('LastUpgrade', CURRENT_TIMESTAMP);

PRAGMA foreign_keys = ON;

-- ============================================================================
-- 7. 验证结果
-- ============================================================================

SELECT '=== Migration Results ===' AS Info;
SELECT 'SchemaVersion: ' || Value AS Version FROM SchemaInfo WHERE Key = 'SchemaVersion';
SELECT 'Tables migrated: Logs, MRU, Hotkeys, Themes' AS Status;
SELECT 'Backup tables created: *_backup' AS Note;

-- ============================================================================
-- 8. 清理备份表（可选 - 取消注释以执行）
-- ============================================================================

-- DROP TABLE IF EXISTS Logs_backup;
-- DROP TABLE IF EXISTS MRU_backup;
-- DROP TABLE IF EXISTS Hotkeys_backup;
-- DROP TABLE IF EXISTS Themes_backup;
