-- ============================================================================
-- DeepBase Studio 全局数据库初始化脚本
-- 数据库位�? %APPDATA%/DeepBase/studio.db
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 开发日志表
-- 记录每日开发工作内�?
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS DevLogs (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    LogDate         DATE NOT NULL DEFAULT (date('now', 'localtime')),
    ProjectName     TEXT NOT NULL,
    Requirement     TEXT,           -- 提出的需�?
    Implementation  TEXT,           -- 实现的功�?
    Tags            TEXT,           -- 标签，逗号分隔 (Bug修复,新功�?重构,文档,测试)
    Notes           TEXT,           -- 备注
    CreatedAt       DATETIME NOT NULL DEFAULT (datetime('now', 'localtime')),
    UpdatedAt       DATETIME NOT NULL DEFAULT (datetime('now', 'localtime'))
);

CREATE INDEX IF NOT EXISTS idx_devlogs_date ON DevLogs(LogDate DESC);
CREATE INDEX IF NOT EXISTS idx_devlogs_project ON DevLogs(ProjectName);
CREATE INDEX IF NOT EXISTS idx_devlogs_tags ON DevLogs(Tags);

-- ----------------------------------------------------------------------------
-- 常用命令�?
-- 存储用户常用的命�?
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS QuickCommands (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    CommandName     TEXT NOT NULL,          -- 命令名称/描述
    CommandText     TEXT NOT NULL,          -- 命令内容
    ProjectName     TEXT,                   -- 所属项�?(NULL 表示全局)
    Category        TEXT DEFAULT 'General', -- 分类
    UsageCount      INTEGER NOT NULL DEFAULT 0,  -- 使用次数
    IsDangerous     INTEGER NOT NULL DEFAULT 0,  -- 是否危险命令 (0/1)
    IsEnabled       INTEGER NOT NULL DEFAULT 1,  -- 是否启用
    CreatedAt       DATETIME NOT NULL DEFAULT (datetime('now', 'localtime')),
    LastUsedAt      DATETIME
);

CREATE INDEX IF NOT EXISTS idx_quickcmd_project ON QuickCommands(ProjectName);
CREATE INDEX IF NOT EXISTS idx_quickcmd_usage ON QuickCommands(UsageCount DESC);
CREATE INDEX IF NOT EXISTS idx_quickcmd_category ON QuickCommands(Category);

-- ----------------------------------------------------------------------------
-- 自动化脚本表
-- 存储多步操作自动化脚�?(JSON 格式)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS AutomationScripts (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ScriptName      TEXT NOT NULL,
    Description     TEXT,
    ScriptData      TEXT NOT NULL,          -- JSON 格式的脚本步�?
    ProjectName     TEXT,                   -- 所属项�?(NULL 表示全局)
    IsEnabled       INTEGER NOT NULL DEFAULT 1,
    UsageCount      INTEGER NOT NULL DEFAULT 0,
    CreatedAt       DATETIME NOT NULL DEFAULT (datetime('now', 'localtime')),
    UpdatedAt       DATETIME NOT NULL DEFAULT (datetime('now', 'localtime')),
    LastRunAt       DATETIME
);

CREATE INDEX IF NOT EXISTS idx_automation_project ON AutomationScripts(ProjectName);
CREATE INDEX IF NOT EXISTS idx_automation_name ON AutomationScripts(ScriptName);

-- ----------------------------------------------------------------------------
-- 托盘设置�?
-- 存储 DeepBaseTray 的配置项
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS TraySettings (
    Key             TEXT PRIMARY KEY,
    Value           TEXT,
    Description     TEXT,
    UpdatedAt       DATETIME NOT NULL DEFAULT (datetime('now', 'localtime'))
);

-- ----------------------------------------------------------------------------
-- 项目历史�?
-- 记录用户使用过的项目名称
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ProjectHiDeepStory (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ProjectName     TEXT NOT NULL UNIQUE,
    ProjectPath     TEXT,                   -- 项目路径 (可�?
    LastUsedAt      DATETIME NOT NULL DEFAULT (datetime('now', 'localtime')),
    UsageCount      INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_projhist_lastused ON ProjectHiDeepStory(LastUsedAt DESC);

-- ----------------------------------------------------------------------------
-- 命令黑名单表
-- 存储禁止执行的危险命令模�?
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS CommandBlacklist (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    Pattern         TEXT NOT NULL UNIQUE,   -- 命令模式 (支持通配�?
    Reason          TEXT,                   -- 禁止原因
    IsEnabled       INTEGER NOT NULL DEFAULT 1
);

-- 预置黑名单命�?
INSERT OR IGNORE INTO CommandBlacklist (Pattern, Reason) VALUES 
    ('rm -rf /*', '危险：删除根目录'),
    ('rm -rf /', '危险：删除根目录'),
    ('del /f /s /q c:\*', '危险：删除系统盘'),
    ('format c:', '危险：格式化系统�?),
    ('format d:', '危险：格式化硬盘'),
    ('fdisk', '危险：磁盘分�?),
    ('shutdown', '危险：关机命�?),
    ('DROP TABLE', '危险：删除数据库�?),
    ('DROP DATABASE', '危险：删除数据库'),
    ('DELETE FROM%WHERE%', '警告：无条件删除');

-- ----------------------------------------------------------------------------
-- 预置设置
-- ----------------------------------------------------------------------------
INSERT OR IGNORE INTO TraySettings (Key, Value, Description) VALUES
    ('Tray.Opacity', '217', '窗口透明�?(0-255, 217=85%)'),
    ('Tray.AlwaysOnTop', '1', '窗口置顶 (0/1)'),
    ('Tray.StudioPath', '', 'Studio 可执行文件路�?),
    ('Tray.DefaultProject', '', '默认项目名称'),
    ('Tray.CommandConfirm', '1', '执行命令前确�?(0/1)'),
    ('Tray.DangerousConfirm', '1', '危险命令双重确认 (0/1)'),
    ('Tray.AutoStart', '0', '开机自动启�?(0/1)'),
    ('Tray.MinimizeOnClose', '1', '关闭时最小化到托�?(0/1)');

-- ----------------------------------------------------------------------------
-- Schema 版本信息
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS StudioSchemaInfo (
    Version         TEXT PRIMARY KEY,
    AppliedAt       DATETIME NOT NULL DEFAULT (datetime('now', 'localtime')),
    Description     TEXT
);

INSERT OR IGNORE INTO StudioSchemaInfo (Version, Description) VALUES 
    ('1.0.0', '初始版本: DevLogs, QuickCommands, AutomationScripts, TraySettings');
