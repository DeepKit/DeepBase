-- ============================================================================
-- DeepBase LLM Prompt Management System - Database Schema
-- Version: 1.0
-- Date: 2025-12-01
-- ============================================================================

-- ============================================================================
-- 1. PromptCategories - 提示词分类表 (4级分�?
-- ============================================================================
CREATE TABLE IF NOT EXISTS PromptCategories (
    Id          INTEGER PRIMARY KEY AUTOINCREMENT,
    ParentId    INTEGER REFERENCES PromptCategories(Id) ON DELETE CASCADE,
    Level       INTEGER NOT NULL CHECK (Level BETWEEN 1 AND 4),  -- 分类层级 1-4
    Code        TEXT NOT NULL,                                    -- 分类编码 �?'01', '02'
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

-- 预置一级分�?
INSERT OR IGNORE INTO PromptCategories (Id, ParentId, Level, Code, Name, Description, SortOrder) VALUES
(1, NULL, 1, '01', '系统提示�?, '框架内置的系统级提示�?, 1),
(2, NULL, 1, '02', '业务提示�?, '业务功能相关的提示词', 2),
(3, NULL, 1, '03', '报表提示�?, '数据分析和报表生成相�?, 3),
(4, NULL, 1, '04', '工具提示�?, '通用工具类提示词', 4);

-- ============================================================================
-- 2. Prompts - 提示词主�?
-- ============================================================================
CREATE TABLE IF NOT EXISTS Prompts (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    CategoryId      INTEGER REFERENCES PromptCategories(Id) ON DELETE SET NULL,
    InternalCode    TEXT NOT NULL UNIQUE,                         -- 内部编码 �?'01-01-001'
    Name            TEXT NOT NULL,                                -- 提示词名�?
    Description     TEXT,                                         -- 用途说�?
    BoundQueryName  TEXT,                                         -- 绑定�?DoQry 查询�?
    VariablesJson   TEXT DEFAULT '[]',                            -- 变量定义 JSON
    IsActive        INTEGER DEFAULT 1,                            -- 是否启用
    CreatedAt       TEXT DEFAULT (datetime('now', 'localtime')),
    UpdatedAt       TEXT,
    CreatedBy       TEXT,                                         -- 创建�?
    UpdatedBy       TEXT                                          -- 更新�?
);

CREATE INDEX IF NOT EXISTS idx_prompts_category ON Prompts(CategoryId);
CREATE INDEX IF NOT EXISTS idx_prompts_code ON Prompts(InternalCode);
CREATE INDEX IF NOT EXISTS idx_prompts_active ON Prompts(IsActive);

-- ============================================================================
-- 3. PromptVersions - 提示词版本表 (每个提示词最�?个版�?
-- ============================================================================
CREATE TABLE IF NOT EXISTS PromptVersions (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    PromptId        INTEGER NOT NULL REFERENCES Prompts(Id) ON DELETE CASCADE,
    VersionNumber   INTEGER NOT NULL CHECK (VersionNumber BETWEEN 1 AND 4),  -- 版本�?1-4
    Content         TEXT NOT NULL,                                -- 提示词内�?
    IsProduction    INTEGER DEFAULT 0,                            -- 是否为生产版�?
    TestCount       INTEGER DEFAULT 0,                            -- 测试次数
    SuccessCount    INTEGER DEFAULT 0,                            -- 成功次数
    TotalTokens     INTEGER DEFAULT 0,                            -- 总Token�?
    TotalCost       REAL DEFAULT 0,                               -- 总费�?
    AvgDuration     REAL DEFAULT 0,                               -- 平均耗时(ms)
    LastTestedAt    TEXT,                                         -- 最后测试时�?
    LastResponse    TEXT,                                         -- 最后一次LLM回复
    CreatedAt       TEXT DEFAULT (datetime('now', 'localtime')),
    UpdatedAt       TEXT,
    UNIQUE(PromptId, VersionNumber)
);

CREATE INDEX IF NOT EXISTS idx_promptversions_prompt ON PromptVersions(PromptId);
CREATE INDEX IF NOT EXISTS idx_promptversions_production ON PromptVersions(IsProduction);

-- 触发器：确保每个提示词只有一个生产版�?
CREATE TRIGGER IF NOT EXISTS trg_promptversions_single_production
BEFORE UPDATE OF IsProduction ON PromptVersions
WHEN NEW.IsProduction = 1
BEGIN
    UPDATE PromptVersions 
    SET IsProduction = 0 
    WHERE PromptId = NEW.PromptId AND Id != NEW.Id;
END;

-- ============================================================================
-- 4. PromptMeta - 元提示词�?
-- ============================================================================
CREATE TABLE IF NOT EXISTS PromptMeta (
    Id           INTEGER PRIMARY KEY AUTOINCREMENT,
    InternalCode TEXT NOT NULL UNIQUE,                            -- 内部编码 �?'META-001'
    Name         TEXT NOT NULL,                                   -- 元提示词名称
    Category     TEXT CHECK (Category IN ('security', 'format', 'role', 'domain', 'quality')),  -- 分类
    Content      TEXT NOT NULL,                                   -- 元提示词内容
    MergeMode    TEXT DEFAULT 'PREFIX' CHECK (MergeMode IN ('PREFIX', 'SUFFIX', 'WRAP')),  -- 合并模式
    Priority     INTEGER DEFAULT 100,                             -- 合并优先�?(数字小的先合�?
    Level        INTEGER DEFAULT 1 CHECK (Level IN (0, 1)),       -- 0=框架�? 1=项目�?
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
3. 对敏感数据进行脱敏处�?
4. 拒绝回答与当前任务无关的问题', 
'PREFIX', 10, 0),

(2, 'META-002', 'JSON输出格式', 'format',
'请以JSON格式返回结果，确保：
1. JSON格式正确，可被直接解�?
2. 使用双引号包裹字符串
3. 不包含注释或多余文本',
'SUFFIX', 90, 0),

(3, 'META-003', '中文助手', 'role',
'你是一个专业的中文AI助手，请使用简体中文回答问题�?,
'PREFIX', 20, 1);

-- ============================================================================
-- 5. PromptMetaBinding - 提示词与元提示词绑定�?(多对�?
-- ============================================================================
CREATE TABLE IF NOT EXISTS PromptMetaBinding (
    PromptId     INTEGER NOT NULL REFERENCES Prompts(Id) ON DELETE CASCADE,
    MetaPromptId INTEGER NOT NULL REFERENCES PromptMeta(Id) ON DELETE CASCADE,
    OrderIndex   INTEGER DEFAULT 0,                               -- 合并顺序
    IsEnabled    INTEGER DEFAULT 1,                               -- 是否启用此绑�?
    CreatedAt    TEXT DEFAULT (datetime('now', 'localtime')),
    PRIMARY KEY (PromptId, MetaPromptId)
);

CREATE INDEX IF NOT EXISTS idx_promptmetabinding_prompt ON PromptMetaBinding(PromptId);
CREATE INDEX IF NOT EXISTS idx_promptmetabinding_meta ON PromptMetaBinding(MetaPromptId);

-- ============================================================================
-- 6. LLMConfig - LLM配置�?-- ============================================================================
-- LLMConfig �?DeepBase 统一�?LLM 配置表名；不要再创建旧版配置表名�?CREATE TABLE IF NOT EXISTS LLMConfig (
    Id               INTEGER PRIMARY KEY AUTOINCREMENT,
    Name             TEXT NOT NULL UNIQUE,
    Description      TEXT,
    ProviderCode     TEXT NOT NULL,
    ModelId          TEXT NOT NULL,
    BaseUrl          TEXT,
    ApiKeyRef        TEXT,
    MaxTokens        INTEGER DEFAULT 4096,
    Temperature      REAL DEFAULT 0.7,
    TopP             REAL DEFAULT 1.0,
    FrequencyPenalty REAL DEFAULT 0,
    PresencePenalty  REAL DEFAULT 0,
    SystemPrompt     TEXT,
    StopSequences    TEXT,
    TimeoutMs        INTEGER DEFAULT 60000,
    RetryCount       INTEGER DEFAULT 3,
    IsEnabled        INTEGER DEFAULT 1,
    IsDefault        INTEGER DEFAULT 0,
    SortOrder        INTEGER DEFAULT 0,
    CreatedAt        TEXT DEFAULT (datetime('now', 'localtime')),
    UpdatedAt        TEXT,
    Extra            TEXT,
    Remarks          TEXT
);

CREATE INDEX IF NOT EXISTS idx_llmconfig_provider ON LLMConfig(ProviderCode);
CREATE INDEX IF NOT EXISTS idx_llmconfig_enabled ON LLMConfig(IsEnabled);
CREATE INDEX IF NOT EXISTS idx_llmconfig_default ON LLMConfig(IsDefault);

-- 确保只有一个默认配�?
CREATE TRIGGER IF NOT EXISTS trg_llmconfig_single_default
BEFORE UPDATE OF IsDefault ON LLMConfig
WHEN NEW.IsDefault = 1
BEGIN
    UPDATE LLMConfig
    SET IsDefault = 0 
    WHERE Id != NEW.Id;
END;

-- ============================================================================
-- 7. LLMCalls - 更新LLM调用记录�?(添加新字�?
-- ============================================================================
CREATE TABLE IF NOT EXISTS LLMCalls (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    PromptId        INTEGER REFERENCES Prompts(Id) ON DELETE SET NULL,  -- 关联的提示词
    VersionNumber   INTEGER,                                      -- 使用的版本号
    ConfigId        INTEGER REFERENCES LLMConfig(Id) ON DELETE SET NULL,
    Provider        TEXT,                                         -- Provider名称
    Model           TEXT,                                         -- 模型名称
    InputText       TEXT,                                         -- 输入文本 (可选，用于调试)
    OutputText      TEXT,                                         -- 输出文本 (可选，用于调试)
    InputTokens     INTEGER DEFAULT 0,                            -- 输入Token�?
    OutputTokens    INTEGER DEFAULT 0,                            -- 输出Token�?
    TotalTokens     INTEGER DEFAULT 0,                            -- 总Token�?
    Duration        INTEGER DEFAULT 0,                            -- 耗时(ms)
    Cost            REAL DEFAULT 0,                               -- 费用
    Status          TEXT DEFAULT 'success' CHECK (Status IN ('success', 'error', 'timeout', 'cancelled', 'rate_limited')),
    ErrorMessage    TEXT,                                         -- 错误信息
    RequestHash     TEXT,                                         -- 请求内容哈希 (用于缓存去重)
    UserId          TEXT,                                         -- 用户ID (可�?
    SessionId       TEXT,                                         -- 会话ID (可�?
    CreatedAt       TEXT DEFAULT (datetime('now', 'localtime'))
);

CREATE INDEX IF NOT EXISTS idx_llmcalls_prompt ON LLMCalls(PromptId);
CREATE INDEX IF NOT EXISTS idx_llmcalls_config ON LLMCalls(ConfigId);
CREATE INDEX IF NOT EXISTS idx_llmcalls_status ON LLMCalls(Status);
CREATE INDEX IF NOT EXISTS idx_llmcalls_created ON LLMCalls(CreatedAt);
CREATE INDEX IF NOT EXISTS idx_llmcalls_hash ON LLMCalls(RequestHash);

-- ============================================================================
-- 8. PromptTestCases - 测试用例�?(可�?
-- ============================================================================
CREATE TABLE IF NOT EXISTS PromptTestCases (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    PromptId        INTEGER NOT NULL REFERENCES Prompts(Id) ON DELETE CASCADE,
    VersionNumber   INTEGER,                                      -- 关联版本�?
    Name            TEXT NOT NULL,                                -- 测试用例名称
    InputVariables  TEXT,                                         -- 输入变量 JSON
    ExpectedOutput  TEXT,                                         -- 期望输出 (可�?
    ActualOutput    TEXT,                                         -- 实际输出
    ConfigId        INTEGER REFERENCES LLMConfig(Id),             -- 使用的LLM配置
    Status          TEXT CHECK (Status IN ('pending', 'passed', 'failed', 'error')),
    Duration        INTEGER,                                      -- 耗时(ms)
    Tokens          INTEGER,                                      -- Token�?
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
-- 视图：提示词完整信息 (含分类路�?
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
