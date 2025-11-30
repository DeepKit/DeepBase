-- ============================================================================
-- UniBase Tier 1 Schema 初始化脚本
-- 版本: 1.0
-- 说明: 创建推荐功能表结构：Logs, MRU, Hotkeys, Themes
-- 依赖: tier0_init.sql 必须先执行
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 日志表
-- ----------------------------------------------------------------------------

-- Logs: 系统运行日志
CREATE TABLE IF NOT EXISTS Logs (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  LogTime TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  Level INTEGER NOT NULL DEFAULT 1,       -- 0=Debug, 1=Info, 2=Warn, 3=Error, 4=Fatal
  Source TEXT,                            -- 来源模块/类名
  Message TEXT NOT NULL,                  -- 日志内容
  StackTrace TEXT,                        -- 堆栈信息（Error/Fatal）
  ThreadId INTEGER,                       -- 线程ID
  Extra TEXT                              -- 额外信息 (JSON)
);

CREATE INDEX IF NOT EXISTS idx_logs_time ON Logs(LogTime);
CREATE INDEX IF NOT EXISTS idx_logs_level ON Logs(Level);
CREATE INDEX IF NOT EXISTS idx_logs_source ON Logs(Source);
CREATE INDEX IF NOT EXISTS idx_logs_time_level ON Logs(LogTime, Level);

-- ----------------------------------------------------------------------------
-- 2. 最近使用记录 (MRU)
-- ----------------------------------------------------------------------------

-- MRU: 最近使用项
CREATE TABLE IF NOT EXISTS MRU (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  Category TEXT NOT NULL,                 -- 分类：File, Project, Command, Search
  ItemKey TEXT NOT NULL,                  -- 唯一键（如文件路径）
  DisplayName TEXT,                       -- 显示名称
  IconIndex INTEGER DEFAULT 0,            -- 图标索引
  LastAccess TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  AccessCount INTEGER DEFAULT 1,          -- 访问次数
  IsPinned INTEGER DEFAULT 0,             -- 是否置顶
  Extra TEXT,                             -- 额外信息 (JSON)
  UNIQUE(Category, ItemKey)
);

CREATE INDEX IF NOT EXISTS idx_mru_category ON MRU(Category);
CREATE INDEX IF NOT EXISTS idx_mru_lastaccess ON MRU(LastAccess DESC);
CREATE INDEX IF NOT EXISTS idx_mru_pinned ON MRU(IsPinned DESC, LastAccess DESC);

-- ----------------------------------------------------------------------------
-- 3. 快捷键
-- ----------------------------------------------------------------------------

-- Hotkeys: 用户自定义快捷键
CREATE TABLE IF NOT EXISTS Hotkeys (
  ActionName TEXT PRIMARY KEY,            -- 动作名称 (File.Save, Edit.Copy)
  Shortcut INTEGER NOT NULL,              -- TShortCut 值
  DefaultShortcut INTEGER,                -- 默认快捷键（用于重置）
  Category TEXT DEFAULT 'General',        -- 分类 (General, File, Edit, View, Tools)
  Description TEXT,                       -- 描述
  IsEnabled INTEGER DEFAULT 1,            -- 是否启用
  IsCustomized INTEGER DEFAULT 0          -- 是否被用户修改过
);

CREATE INDEX IF NOT EXISTS idx_hotkeys_category ON Hotkeys(Category);
CREATE INDEX IF NOT EXISTS idx_hotkeys_shortcut ON Hotkeys(Shortcut);

-- ----------------------------------------------------------------------------
-- 4. 主题
-- ----------------------------------------------------------------------------

-- Themes: 主题配置
-- 当前主题选择存储在 Settings 表的 'App.Theme' 中
CREATE TABLE IF NOT EXISTS Themes (
  ThemeName TEXT PRIMARY KEY,             -- 主题名称
  DisplayName TEXT,                       -- 显示名称
  StyleFile TEXT,                         -- .vsf 文件路径
  IsDark INTEGER DEFAULT 0,               -- 是否深色主题
  IsBuiltIn INTEGER DEFAULT 1,            -- 是否内置主题
  IsEnabled INTEGER DEFAULT 1,            -- 是否启用
  SortOrder INTEGER DEFAULT 0,            -- 排序顺序
  PreviewImage TEXT,                      -- 预览图路径
  Extra TEXT                              -- 额外配置 (JSON)
);

-- 预置主题
INSERT OR REPLACE INTO Themes (ThemeName, DisplayName, StyleFile, IsDark, IsBuiltIn, SortOrder) VALUES
  ('Windows', 'Windows (Default)', '', 0, 1, 0),
  ('Windows10', 'Windows 10', 'Windows10.vsf', 0, 1, 1),
  ('Windows11', 'Windows 11', 'Windows11.vsf', 0, 1, 2),
  ('Windows11Dark', 'Windows 11 Dark', 'Windows11Dark.vsf', 1, 1, 3),
  ('Glow', 'Glow', 'Glow.vsf', 0, 1, 4),
  ('Iceberg', 'Iceberg', 'Iceberg.vsf', 0, 1, 5),
  ('Slate', 'Slate', 'Slate.vsf', 1, 1, 6),
  ('Carbon', 'Carbon', 'Carbon.vsf', 1, 1, 7);

-- ----------------------------------------------------------------------------
-- 5. 更新 Schema 版本
-- ----------------------------------------------------------------------------

UPDATE SchemaInfo SET Value = '1.0' WHERE Key = 'SchemaVersion';
UPDATE SchemaInfo SET Value = datetime('now') WHERE Key = 'LastUpgrade';

-- ============================================================================
-- 完成提示
-- ============================================================================

SELECT 'Tier 1 Schema initialized successfully. Version: ' || 
  (SELECT Value FROM SchemaInfo WHERE Key = 'SchemaVersion') AS Result;
