-- ============================================================================
-- ⚠️ DEPRECATED - 此脚本已废弃
-- 请使用: data/create_sample_db.sql 或直接复制 data/样例Config.db
-- ============================================================================
--
-- UniBase Tier 1 Schema 初始化脚本 (已废弃)
-- 版本: 0.3
-- 说明: 创建推荐功能表结构：Logs, MRU, Hotkeys, Themes
-- 依赖: tier0_init.sql 必须先执行
-- 废弃原因: 与 create_sample_db.sql 表结构不一致，已统一使用后者
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 日志表
-- ----------------------------------------------------------------------------

-- Logs: 系统运行日志
CREATE TABLE IF NOT EXISTS Logs (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  LogTime TEXT NOT NULL,                  -- ISO8601 格式时间
  LogLevel TEXT NOT NULL,                 -- DEBUG/INFO/WARN/ERROR/FATAL
  Source TEXT,                            -- 来源模块/类名
  Message TEXT NOT NULL,                  -- 日志内容
  ExceptionClass TEXT,                    -- 异常类名
  ExceptionMessage TEXT,                  -- 异常消息
  StackTrace TEXT,                        -- 堆栈信息（Error/Fatal）
  ThreadId INTEGER,                       -- 线程ID
  UserId TEXT                             -- 用户ID
);

CREATE INDEX IF NOT EXISTS idx_logs_time ON Logs(LogTime);
CREATE INDEX IF NOT EXISTS idx_logs_level ON Logs(LogLevel);

-- ----------------------------------------------------------------------------
-- 2. 最近使用记录 (MRU)
-- ----------------------------------------------------------------------------

-- MRU: 最近使用项
CREATE TABLE IF NOT EXISTS MRU (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  Category TEXT NOT NULL,                 -- 分类：File, Project, Command, Search
  ItemKey TEXT NOT NULL,                  -- 唯一键（如文件路径）
  DisplayName TEXT,                       -- 显示名称
  LastAccess TEXT NOT NULL,               -- ISO8601 格式时间
  AccessCount INTEGER DEFAULT 1,          -- 访问次数
  IconIndex INTEGER DEFAULT 0,            -- 图标索引
  IsPinned INTEGER DEFAULT 0,             -- 是否置顶
  Extra TEXT,                             -- 额外信息 (JSON)
  UNIQUE(Category, ItemKey)
);

CREATE INDEX IF NOT EXISTS idx_mru_category_time ON MRU(Category, LastAccess DESC);

-- ----------------------------------------------------------------------------
-- 3. 快捷键
-- ----------------------------------------------------------------------------

-- Hotkeys: 用户自定义快捷键
CREATE TABLE IF NOT EXISTS Hotkeys (
  ActionName TEXT PRIMARY KEY,            -- 动作名称 (File.Save, Edit.Copy)
  Shortcut TEXT NOT NULL,                 -- 快捷键字符串 (Ctrl+S, F1)
  Description TEXT,                       -- 描述
  Category TEXT                           -- 分类
);

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
  AccentColor INTEGER,                    -- 主题色
  CustomCSS TEXT                          -- 自定义样式
);

-- 预置主题
INSERT OR IGNORE INTO Themes (ThemeName, DisplayName, IsDark, IsBuiltIn, SortOrder) VALUES
  ('Windows', 'Windows', 0, 1, 0);
INSERT OR IGNORE INTO Themes (ThemeName, DisplayName, IsDark, IsBuiltIn, SortOrder) VALUES
  ('Windows11', 'Windows 11', 0, 1, 1);
INSERT OR IGNORE INTO Themes (ThemeName, DisplayName, IsDark, IsBuiltIn, SortOrder) VALUES
  ('Carbon', 'Carbon (Dark)', 1, 1, 2);

-- ----------------------------------------------------------------------------
-- 5. 更新 Schema 版本
-- ----------------------------------------------------------------------------

UPDATE SchemaInfo SET Value = '0.3' WHERE Key = 'SchemaVersion';
UPDATE SchemaInfo SET Value = CURRENT_TIMESTAMP WHERE Key = 'LastUpgrade';

-- ============================================================================
-- 完成提示
-- ============================================================================

SELECT 'Tier 1 Schema initialized successfully. Version: ' || 
  (SELECT Value FROM SchemaInfo WHERE Key = 'SchemaVersion') AS Result;
