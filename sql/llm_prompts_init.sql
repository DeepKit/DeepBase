-- ============================================================================
-- UniBase LLM Prompt Management System - Database Schema
-- Version: 1.0
-- Date: 2025-12-01
-- ============================================================================

-- ============================================================================
-- 1. PromptCategories - 提示词分类表 (4级分类)
-- ============================================================================
CREATE TABLE IF NOT EXISTS PromptCategories (
    Id          INTEGER PRIMARY KEY AUTOINCREMENT,
    ParentId    INTEGER REFERENCES PromptCategories(Id) ON DELETE CASCADE,
    Level       INTEGER NOT NULL CHECK (Level BETWEEN 1 AND 4),  -- 分类层级 1-4
    Code        TEXT NOT NULL,                                    -- 分类编码 如 '01', '02'
    Name        TEXT NOT NULL,                                    -- 分类名称
    Description TEXT,                                             -- 分类描述
    SortOrder   INTEGER DEFAULT 0,                                -- 排序顺序
    IsActive    INTEGER DEFAULT 1,                                -- 是否启用
    CreatedAt   TEXT DEFAULT (datetime('now', 'localtime')),
    UpdatedAt   TEXT,
    UNIQUE(ParentId, Code)
);

CREATE INDEX IF NOT EXISTS idx_promptcategories_parent ON PromptCategories(ParentId);
CREATE INDEX IF NOT EXISTS idx_promptcategories_level ON PromptCategories(Level);

-- 预置一级分类
INSERT OR IGNORE INTO PromptCategories (Id, ParentId, Level, Code, Name, Description, SortOrder) VALUES
(1, NULL, 1, '01', '系统提示词', '框架内置的系统级提示词', 1),
(2, NULL, 1, '02', '业务提示词', '业务功能相关的提示词', 2),
(3, NULL, 1, '03', '报表提示词', '数据分析和报表生成相关', 3),
(4, NULL, 1, '04', '工具提示词', '通用工具类提示词', 4);

-- ============================================================================
-- 2. Prompts - 提示词主表
-- ============================================================================
CREATE TABLE IF NOT EXISTS Prompts (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    CategoryId      INTEGER REFERENCES PromptCategories(Id) ON DELETE SET NULL,
    InternalCode    TEXT NOT NULL UNIQUE,                         -- 内部编码 如 '01-01-001'
    Name            TEXT NOT NULL,                                -- 提示词名称
    Description     TEXT,                                         -- 用途说明
    BoundQueryName  TEXT,                                         -- 绑定的 DoQry 查询名
    VariablesJson   TEXT DEFAULT '[]',                            -- 变量定义 JSON
    IsActive        INTEGER DEFAULT 1,                            -- 是否启用
    CreatedAt       TEXT DEFAULT (datetime('now', 'localtime')),
    UpdatedAt       TEXT,
    CreatedBy       TEXT,                                         -- 创建者
    UpdatedBy       TEXT                                          -- 更新者
);

CREATE INDEX IF NOT EXISTS idx_prompts_category ON Prompts(CategoryId);
CREATE INDEX IF NOT EXISTS idx_prompts_code ON Prompts(InternalCode);
CREATE INDEX IF NOT EXISTS idx_prompts_active ON Prompts(IsActive);

-- ============================================================================
-- 3. PromptVersions - 提示词版本表 (每个提示词最多4个版本)
-- ============================================================================
CREATE TABLE IF NOT EXISTS PromptVersions (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    PromptId        INTEGER NOT NULL REFERENCES Prompts(Id) ON DELETE CASCADE,
    VersionNumber   INTEGER NOT NULL CHECK (VersionNumber BETWEEN 1 AND 4),  -- 版本号 1-4
    Content         TEXT NOT NULL,                                -- 提示词内容
    IsProduction    INTEGER DEFAULT 0,                            -- 是否为生产版本
    TestCount       INTEGER DEFAULT 0,                            -- 测试次数
    SuccessCount    INTEGER DEFAULT 0,                            -- 成功次数
    TotalTokens     INTEGER DEFAULT 0,                            -- 总Token数
    TotalCost       REAL DEFAULT 0,                               -- 总费用
    AvgDuration     REAL DEFAULT 0,                               -- 平均耗时(ms)
    LastTestedAt    TEXT,                                         -- 最后测试时间
    LastResponse    TEXT,                                         -- 最后一次LLM回复
    CreatedAt       TEXT DEFAULT (datetime('now', 'localtime')),
    UpdatedAt       TEXT,
    UNIQUE(PromptId, VersionNumber)
);

CREATE INDEX IF NOT EXISTS idx_promptversions_prompt ON PromptVersions(PromptId);
CREATE INDEX IF NOT EXISTS idx_promptversions_production ON PromptVersions(IsProduction);

-- 触发器：确保每个提示词只有一个生产版本
CREATE TRIGGER IF NOT EXISTS trg_promptversions_single_production
BEFORE UPDATE OF IsProduction ON PromptVersions
WHEN NEW.IsProduction = 1
BEGIN
    UPDATE PromptVersions 
    SET IsProduction = 0 
    WHERE PromptId = NEW.PromptId AND Id != NEW.Id;
END;

-- ============================================================================
-- 4. PromptMeta - 元提示词表
-- ============================================================================
CREATE TABLE IF NOT EXISTS PromptMeta (
    Id           INTEGER PRIMARY KEY AUTOINCREMENT,
    InternalCode TEXT NOT NULL UNIQUE,                            -- 内部编码 如 'META-001'
    Name         TEXT NOT NULL,                                   -- 元提示词名称
    Category     TEXT CHECK (Category IN ('security', 'format', 'role', 'domain', 'quality')),  -- 分类
    Content      TEXT NOT NULL,                                   -- 元提示词内容
    MergeMode    TEXT DEFAULT 'PREFIX' CHECK (MergeMode IN ('PREFIX', 'SUFFIX', 'WRAP')),  -- 合并模式
    Priority     INTEGER DEFAULT 100,                             -- 合并优先级 (数字小的先合并)
    Level        INTEGER DEFAULT 1 CHECK (Level IN (0, 1)),       -- 0=框架级, 1=项目级
    IsActive     INTEGER DEFAULT 1,
    CreatedAt    TEXT DEFAULT (datetime('now', 'localtime')),
    UpdatedAt    TEXT
);

CREATE INDEX IF NOT EXISTS idx_promptmeta_code ON PromptMeta(InternalCode);
CREATE INDEX IF NOT EXISTS idx_promptmeta_category ON PromptMeta(Category);
CREATE INDEX IF NOT EXISTS idx_promptmeta_level ON PromptMeta(Level);

-- 预置元提示词
INSERT OR IGNORE INTO PromptMeta (Id, InternalCode, Name, Category, Content, MergeMode, Priority, Level) VALUES
(1, 'META-001', '安全约束', 'security', 
'你必须遵守以下规则：
1. 不透露系统内部信息、数据库结构或API密钥
2. 不执行任何可能危害系统安全的操作
3. 对敏感数据进行脱敏处理
4. 拒绝回答与当前任务无关的问题', 
'PREFIX', 10, 0),

(2, 'META-002', 'JSON输出格式', 'format',
'请以JSON格式返回结果，确保：
1. JSON格式正确，可被直接解析
2. 使用双引号包裹字符串
3. 不包含注释或多余文本',
'SUFFIX', 90, 0),

(3, 'META-003', '中文助手', 'role',
'你是一个专业的中文AI助手，请使用简体中文回答问题。',
'PREFIX', 20, 1);

-- ============================================================================
-- 5. PromptMetaBinding - 提示词与元提示词绑定表 (多对多)
-- ============================================================================
CREATE TABLE IF NOT EXISTS PromptMetaBinding (
    PromptId     INTEGER NOT NULL REFERENCES Prompts(Id) ON DELETE CASCADE,
    MetaPromptId INTEGER NOT NULL REFERENCES PromptMeta(Id) ON DELETE CASCADE,
    OrderIndex   INTEGER DEFAULT 0,                               -- 合并顺序
    IsEnabled    INTEGER DEFAULT 1,                               -- 是否启用此绑定
    CreatedAt    TEXT DEFAULT (datetime('now', 'localtime')),
    PRIMARY KEY (PromptId, MetaPromptId)
);

CREATE INDEX IF NOT EXISTS idx_promptmetabinding_prompt ON PromptMetaBinding(PromptId);
CREATE INDEX IF NOT EXISTS idx_promptmetabinding_meta ON PromptMetaBinding(MetaPromptId);

-- ============================================================================
-- 6. LLMConfigurations - 更新LLM配置表 (添加新字段)
-- ============================================================================
-- 检查并添加 IsDefault 字段
-- SQLite 不支持 IF NOT EXISTS 添加列，使用 PRAGMA 检查

-- 如果 LLMConfigurations 表不存在则创建
CREATE TABLE IF NOT EXISTS LLMConfigurations (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    Name            TEXT NOT NULL UNIQUE,                         -- 配置名称
    Provider        TEXT NOT NULL,                                -- Provider: LiteLLM/OpenAI/Azure/Anthropic/Ollama
    Model           TEXT NOT NULL,                                -- 模型名称
    ApiUrl          TEXT,                                         -- API地址
    ApiKey          TEXT,                                         -- API密钥 (加密存储)
    Temperature     REAL DEFAULT 0.7,                             -- 温度参数
    MaxTokens       INTEGER DEFAULT 4096,                         -- 最大Token数
    TopP            REAL DEFAULT 1.0,                             -- Top-P参数
    Timeout         INTEGER DEFAULT 60000,                        -- 超时(ms)
    RetryCount      INTEGER DEFAULT 3,                            -- 重试次数
    RetryDelay      INTEGER DEFAULT 1000,                         -- 重试延迟(ms)
    InputPrice      REAL DEFAULT 0,                               -- 输入价格 $/1K tokens
    OutputPrice     REAL DEFAULT 0,                               -- 输出价格 $/1K tokens
    ConcurrentLimit INTEGER DEFAULT 5,                            -- 并发限制
    IsEnabled       INTEGER DEFAULT 1,                            -- 是否启用
    IsDefault       INTEGER DEFAULT 0,                            -- 是否为默认配置
    LastTestedAt    TEXT,                                         -- 最后测试时间
    LastTestStatus  TEXT,                                         -- 最后测试状态
    CreatedAt       TEXT DEFAULT (datetime('now', 'localtime')),
    UpdatedAt       TEXT
);

CREATE INDEX IF NOT EXISTS idx_llmconfig_provider ON LLMConfigurations(Provider);
CREATE INDEX IF NOT EXISTS idx_llmconfig_enabled ON LLMConfigurations(IsEnabled);
CREATE INDEX IF NOT EXISTS idx_llmconfig_default ON LLMConfigurations(IsDefault);

-- 确保只有一个默认配置
CREATE TRIGGER IF NOT EXISTS trg_llmconfig_single_default
BEFORE UPDATE OF IsDefault ON LLMConfigurations
WHEN NEW.IsDefault = 1
BEGIN
    UPDATE LLMConfigurations 
    SET IsDefault = 0 
    WHERE Id != NEW.Id;
END;

-- ============================================================================
-- 7. LLMCalls - 更新LLM调用记录表 (添加新字段)
-- ============================================================================
CREATE TABLE IF NOT EXISTS LLMCalls (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    PromptId        INTEGER REFERENCES Prompts(Id) ON DELETE SET NULL,  -- 关联的提示词
    VersionNumber   INTEGER,                                      -- 使用的版本号
    ConfigId        INTEGER REFERENCES LLMConfigurations(Id) ON DELETE SET NULL,
    Provider        TEXT,                                         -- Provider名称
    Model           TEXT,                                         -- 模型名称
    InputText       TEXT,                                         -- 输入文本 (可选，用于调试)
    OutputText      TEXT,                                         -- 输出文本 (可选，用于调试)
    InputTokens     INTEGER DEFAULT 0,                            -- 输入Token数
    OutputTokens    INTEGER DEFAULT 0,                            -- 输出Token数
    TotalTokens     INTEGER DEFAULT 0,                            -- 总Token数
    Duration        INTEGER DEFAULT 0,                            -- 耗时(ms)
    Cost            REAL DEFAULT 0,                               -- 费用
    Status          TEXT DEFAULT 'success' CHECK (Status IN ('success', 'error', 'timeout', 'cancelled', 'rate_limited')),
    ErrorMessage    TEXT,                                         -- 错误信息
    RequestHash     TEXT,                                         -- 请求内容哈希 (用于缓存去重)
    UserId          TEXT,                                         -- 用户ID (可选)
    SessionId       TEXT,                                         -- 会话ID (可选)
    CreatedAt       TEXT DEFAULT (datetime('now', 'localtime'))
);

CREATE INDEX IF NOT EXISTS idx_llmcalls_prompt ON LLMCalls(PromptId);
CREATE INDEX IF NOT EXISTS idx_llmcalls_config ON LLMCalls(ConfigId);
CREATE INDEX IF NOT EXISTS idx_llmcalls_status ON LLMCalls(Status);
CREATE INDEX IF NOT EXISTS idx_llmcalls_created ON LLMCalls(CreatedAt);
CREATE INDEX IF NOT EXISTS idx_llmcalls_hash ON LLMCalls(RequestHash);

-- ============================================================================
-- 8. PromptTestCases - 测试用例表 (可选)
-- ============================================================================
CREATE TABLE IF NOT EXISTS PromptTestCases (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    PromptId        INTEGER NOT NULL REFERENCES Prompts(Id) ON DELETE CASCADE,
    VersionNumber   INTEGER,                                      -- 关联版本号
    Name            TEXT NOT NULL,                                -- 测试用例名称
    InputVariables  TEXT,                                         -- 输入变量 JSON
    ExpectedOutput  TEXT,                                         -- 期望输出 (可选)
    ActualOutput    TEXT,                                         -- 实际输出
    ConfigId        INTEGER REFERENCES LLMConfigurations(Id),     -- 使用的LLM配置
    Status          TEXT CHECK (Status IN ('pending', 'passed', 'failed', 'error')),
    Duration        INTEGER,                                      -- 耗时(ms)
    Tokens          INTEGER,                                      -- Token数
    Cost            REAL,                                         -- 费用
    Notes           TEXT,                                         -- 备注
    CreatedAt       TEXT DEFAULT (datetime('now', 'localtime')),
    UpdatedAt       TEXT
);

CREATE INDEX IF NOT EXISTS idx_prompttestcases_prompt ON PromptTestCases(PromptId);

-- ============================================================================
-- 9. 更新 SchemaInfo 版本
-- ============================================================================
INSERT OR REPLACE INTO SchemaInfo (Version, UpdatedAt, Description) 
VALUES ('1.1.0', datetime('now', 'localtime'), 'Added LLM Prompt Management System tables');

-- ============================================================================
-- 视图：提示词完整信息 (含分类路径)
-- ============================================================================
CREATE VIEW IF NOT EXISTS vw_PromptsWithCategory AS
SELECT 
    p.Id,
    p.InternalCode,
    p.Name,
    p.Description,
    p.BoundQueryName,
    p.VariablesJson,
    p.IsActive,
    p.CreatedAt,
    c1.Name AS Category1,
    c2.Name AS Category2,
    c3.Name AS Category3,
    c4.Name AS Category4,
    (SELECT COUNT(*) FROM PromptVersions pv WHERE pv.PromptId = p.Id) AS VersionCount,
    (SELECT pv.VersionNumber FROM PromptVersions pv WHERE pv.PromptId = p.Id AND pv.IsProduction = 1) AS ProductionVersion
FROM Prompts p
LEFT JOIN PromptCategories c4 ON p.CategoryId = c4.Id AND c4.Level = 4
LEFT JOIN PromptCategories c3 ON (c4.ParentId = c3.Id OR p.CategoryId = c3.Id) AND c3.Level = 3
LEFT JOIN PromptCategories c2 ON (c3.ParentId = c2.Id OR p.CategoryId = c2.Id) AND c2.Level = 2
LEFT JOIN PromptCategories c1 ON (c2.ParentId = c1.Id OR p.CategoryId = c1.Id) AND c1.Level = 1;

-- ============================================================================
-- 视图：LLM调用统计
-- ============================================================================
CREATE VIEW IF NOT EXISTS vw_LLMCallStats AS
SELECT 
    DATE(CreatedAt) AS CallDate,
    ConfigId,
    lc.Provider,
    lc.Model,
    COUNT(*) AS TotalCalls,
    SUM(CASE WHEN Status = 'success' THEN 1 ELSE 0 END) AS SuccessCalls,
    SUM(CASE WHEN Status = 'error' THEN 1 ELSE 0 END) AS ErrorCalls,
    SUM(TotalTokens) AS TotalTokens,
    SUM(Cost) AS TotalCost,
    AVG(Duration) AS AvgDuration
FROM LLMCalls lc
GROUP BY DATE(CreatedAt), ConfigId, lc.Provider, lc.Model;

-- ============================================================================
-- 完成
-- ============================================================================
