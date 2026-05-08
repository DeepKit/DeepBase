-- ============================================================================
-- ⚠️ DEPRECATED - 此脚本已废弃
-- 请使�? data/create_sample_db.sql 或直接复�?data/样例Config.db
-- ============================================================================
--
-- DeepBase Tier 0 Schema 初始化脚�?(已废�?
-- 版本: 0.3
-- 说明: 创建最小核心表结构，包�?6 张表
-- 废弃原因: �?create_sample_db.sql 表结构不一致，已统一使用后�?
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 元信息表
-- ----------------------------------------------------------------------------

-- SchemaInfo: 数据库版本信�?
CREATE TABLE IF NOT EXISTS SchemaInfo (
  Key TEXT PRIMARY KEY,
  Value TEXT
);

INSERT OR REPLACE INTO SchemaInfo VALUES ('SchemaVersion', '0.3');
INSERT OR REPLACE INTO SchemaInfo VALUES ('CreatedAt', CURRENT_TIMESTAMP);
INSERT OR REPLACE INTO SchemaInfo VALUES ('LastUpgrade', CURRENT_TIMESTAMP);

-- ProjectInfo: 项目信息
CREATE TABLE IF NOT EXISTS ProjectInfo (
  Key TEXT PRIMARY KEY,
  Value TEXT
);

INSERT OR REPLACE INTO ProjectInfo VALUES ('ProjectName', 'MyApp');
INSERT OR REPLACE INTO ProjectInfo VALUES ('ProjectVersion', '1.0.0');
INSERT OR REPLACE INTO ProjectInfo VALUES ('ProjectDescription', '');
INSERT OR REPLACE INTO ProjectInfo VALUES ('ProjectAuthor', '');
INSERT OR REPLACE INTO ProjectInfo VALUES ('ProjectWebsite', '');

-- ----------------------------------------------------------------------------
-- 2. 核心配置�?
-- ----------------------------------------------------------------------------

-- Settings: 通用配置�?
CREATE TABLE IF NOT EXISTS Settings (
  Key TEXT PRIMARY KEY,
  Value TEXT,
  ValueType TEXT DEFAULT 'String',   -- String/Integer/Boolean/Float/JSON
  Category TEXT DEFAULT 'General',   -- General/UI/Logging/LLM/Update/Remote/License
  Description TEXT,
  IsEncrypted INTEGER DEFAULT 0      -- 是否加密存储（用于敏感信息）
);

-- 预置常用配置
INSERT OR REPLACE INTO Settings (Key, Value, ValueType, Category, Description) 
  VALUES ('App.Language', 'en-US', 'String', 'General', 'Current language');
INSERT OR REPLACE INTO Settings (Key, Value, ValueType, Category, Description) 
  VALUES ('App.DebugMode', 'False', 'Boolean', 'General', 'Debug mode enabled');
INSERT OR REPLACE INTO Settings (Key, Value, ValueType, Category, Description) 
  VALUES ('App.Theme', 'Windows11', 'String', 'UI', 'Current theme');

-- FormStates: 窗体状态表
CREATE TABLE IF NOT EXISTS FormStates (
  FormName TEXT PRIMARY KEY,
  Left INTEGER,
  Top INTEGER,
  Width INTEGER,
  Height INTEGER,
  WindowState INTEGER DEFAULT 0,   -- 0=Normal, 1=Minimized, 2=Maximized
  MonitorIndex INTEGER DEFAULT 0,  -- 多显示器支持
  Extra TEXT                       -- JSON 格式，存储其他自定义状�?
);

-- ----------------------------------------------------------------------------
-- 3. 国际化表
-- ----------------------------------------------------------------------------

-- Languages: 支持的语言列表
CREATE TABLE IF NOT EXISTS Languages (
  LangCode TEXT PRIMARY KEY,       -- zh-CN, en-US, ja-JP
  LangName TEXT NOT NULL,          -- Chinese (Simplified), English, Japanese
  NativeName TEXT,                 -- 简体中�? English, 日本�?
  FlagIcon TEXT,                   -- 国旗图标文件名（相对�?assets/flags/�?
  IsEnabled INTEGER DEFAULT 1,
  IsDefault INTEGER DEFAULT 0,
  SortOrder INTEGER DEFAULT 0
);

-- 预置语言
INSERT OR REPLACE INTO Languages VALUES ('en-US', 'English', 'English', 'us.png', 1, 1, 0);
INSERT OR REPLACE INTO Languages VALUES ('zh-CN', 'Chinese (Simplified)', '简体中�?, 'cn.png', 1, 0, 1);
INSERT OR REPLACE INTO Languages VALUES ('zh-TW', 'Chinese (Traditional)', '繁體中文', 'tw.png', 0, 0, 2);
INSERT OR REPLACE INTO Languages VALUES ('ja-JP', 'Japanese', '日本�?, 'jp.png', 0, 0, 3);

-- I18nTexts: 国际化文本表
CREATE TABLE IF NOT EXISTS I18nTexts (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  SourceText TEXT NOT NULL,            -- 英文原文（作�?Key�?
  LangCode TEXT NOT NULL,              -- 语言代码
  TranslatedText TEXT,                 -- 翻译后文�?
  PluralForm TEXT,                     -- 复数形式（JSON）：{"one": "...", "other": "..."}
  Context TEXT,                        -- 上下文说明（帮助翻译�?
  Module TEXT,                         -- 模块名称（用于分组）
  LastUsedAt TEXT,                     -- 最后使用时间（统一命名�?LastUsedAt�?
  IsAutoTranslated INTEGER DEFAULT 0,  -- 是否机器翻译
  IsVerified INTEGER DEFAULT 0,        -- 是否人工校验
  Extra TEXT,                          -- 扩展字段
  Remarks TEXT,                        -- 备注
  UNIQUE(SourceText, LangCode)
);

CREATE INDEX IF NOT EXISTS idx_i18n_lang ON I18nTexts(LangCode);
CREATE INDEX IF NOT EXISTS idx_i18n_source ON I18nTexts(SourceText);
CREATE INDEX IF NOT EXISTS idx_i18n_module ON I18nTexts(Module);

-- 预置基础翻译
INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) 
  VALUES ('Welcome', 'zh-CN', '欢迎', 1);
INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) 
  VALUES ('Save', 'zh-CN', '保存', 1);
INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) 
  VALUES ('Cancel', 'zh-CN', '取消', 1);
INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) 
  VALUES ('OK', 'zh-CN', '确定', 1);
INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, IsVerified) 
  VALUES ('Error', 'zh-CN', '错误', 1);

-- ============================================================================
-- 完成提示
-- ============================================================================

SELECT 'Tier 0 Schema initialized successfully. Version: ' || Value AS Result
FROM SchemaInfo WHERE Key = 'SchemaVersion';
