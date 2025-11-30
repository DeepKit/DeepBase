-- ============================================================================
-- UniBase Tier 2 Schema 初始化脚本
-- 版本: 1.0
-- 说明: 创建扩展功能表结构：LLM, Exception, Animation, Test
-- 依赖: tier0_init.sql, tier1_init.sql 必须先执行
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. LLM 配置表
-- ----------------------------------------------------------------------------

-- LLMConfiguration: LLM 服务配置
CREATE TABLE IF NOT EXISTS LLMConfiguration (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  Name TEXT NOT NULL UNIQUE,             -- 配置名称 (Default, Translation, CodeGen)
  Provider TEXT NOT NULL DEFAULT 'openai', -- 服务商 (openai, anthropic, litellm, azure, ollama)
  BaseUrl TEXT,                          -- API 基础 URL (LiteLLM: http://localhost:4000)
  ApiKey TEXT,                           -- API Key (加密存储)
  Model TEXT NOT NULL DEFAULT 'gpt-4o-mini', -- 模型名称
  MaxTokens INTEGER DEFAULT 4096,        -- 最大输出 Token
  Temperature REAL DEFAULT 0.7,          -- 温度参数 (0.0-2.0)
  SystemPrompt TEXT,                     -- 系统提示词
  -- 成本配置
  InputTokenPrice REAL DEFAULT 0.0,      -- 每 1K 输入 Token 价格 (USD)
  OutputTokenPrice REAL DEFAULT 0.0,     -- 每 1K 输出 Token 价格 (USD)
  -- 状态
  IsEnabled INTEGER DEFAULT 1,           -- 是否启用
  IsDefault INTEGER DEFAULT 0,           -- 是否为默认配置
  SortOrder INTEGER DEFAULT 0,           -- 排序顺序
  -- 时间戳
  CreatedAt TEXT DEFAULT (datetime('now', 'localtime')),
  UpdatedAt TEXT DEFAULT (datetime('now', 'localtime')),
  Extra TEXT                             -- 额外配置 (JSON)
);

CREATE INDEX IF NOT EXISTS idx_llm_config_provider ON LLMConfiguration(Provider);
CREATE INDEX IF NOT EXISTS idx_llm_config_enabled ON LLMConfiguration(IsEnabled);

-- 预置默认配置
INSERT OR IGNORE INTO LLMConfiguration (Name, Provider, Model, IsDefault, SystemPrompt, InputTokenPrice, OutputTokenPrice) VALUES
  ('Default', 'openai', 'gpt-4o-mini', 1, 'You are a helpful assistant.', 0.00015, 0.0006),
  ('Translation', 'openai', 'gpt-4o-mini', 0, 'You are a professional translator. Translate the following text accurately while preserving the original meaning and tone.', 0.00015, 0.0006),
  ('CodeGen', 'openai', 'gpt-4o', 0, 'You are an expert Delphi programmer. Generate clean, efficient, and well-documented code.', 0.0025, 0.01);

-- ----------------------------------------------------------------------------
-- 2. LLM 调用记录表
-- ----------------------------------------------------------------------------

-- LLMCalls: LLM API 调用历史
CREATE TABLE IF NOT EXISTS LLMCalls (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  ConfigName TEXT NOT NULL,              -- 使用的配置名称
  Provider TEXT NOT NULL,                -- 服务商
  Model TEXT NOT NULL,                   -- 模型
  -- 请求信息
  Prompt TEXT NOT NULL,                  -- 用户输入
  SystemPrompt TEXT,                     -- 系统提示词
  -- 响应信息
  Response TEXT,                         -- LLM 响应
  FinishReason TEXT,                     -- 完成原因 (stop, length, content_filter)
  -- Token 统计
  InputTokens INTEGER DEFAULT 0,         -- 输入 Token 数
  OutputTokens INTEGER DEFAULT 0,        -- 输出 Token 数
  TotalTokens INTEGER DEFAULT 0,         -- 总 Token 数
  -- 成本计算
  EstimatedCost REAL DEFAULT 0.0,        -- 估算成本 (USD)
  -- 性能指标
  DurationMs INTEGER DEFAULT 0,          -- 调用耗时 (毫秒)
  FirstTokenMs INTEGER,                  -- 首个 Token 耗时 (流式)
  -- 状态
  Success INTEGER DEFAULT 1,             -- 是否成功
  ErrorCode TEXT,                        -- 错误码
  ErrorMessage TEXT,                     -- 错误信息
  -- 来源
  CallerModule TEXT,                     -- 调用模块
  CallerFunction TEXT,                   -- 调用函数
  -- 时间戳
  CallTime TEXT DEFAULT (datetime('now', 'localtime')),
  Extra TEXT                             -- 额外信息 (JSON)
);

CREATE INDEX IF NOT EXISTS idx_llm_calls_time ON LLMCalls(CallTime DESC);
CREATE INDEX IF NOT EXISTS idx_llm_calls_config ON LLMCalls(ConfigName);
CREATE INDEX IF NOT EXISTS idx_llm_calls_success ON LLMCalls(Success);
CREATE INDEX IF NOT EXISTS idx_llm_calls_model ON LLMCalls(Model);

-- ----------------------------------------------------------------------------
-- 3. 异常报告表
-- ----------------------------------------------------------------------------

-- ExceptionReports: 异常和错误报告
CREATE TABLE IF NOT EXISTS ExceptionReports (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  -- 异常信息
  ExceptionClass TEXT NOT NULL,          -- 异常类名 (EAccessViolation)
  ExceptionMessage TEXT NOT NULL,        -- 异常消息
  StackTrace TEXT,                       -- 堆栈跟踪
  -- 上下文
  Module TEXT,                           -- 模块名
  UnitName TEXT,                         -- 单元名
  ClassName TEXT,                        -- 类名
  MethodName TEXT,                       -- 方法名
  LineNumber INTEGER,                    -- 行号
  -- 环境信息
  AppVersion TEXT,                       -- 应用版本
  DelphiVersion TEXT,                    -- Delphi 版本
  OSVersion TEXT,                        -- 操作系统版本
  ComputerName TEXT,                     -- 计算机名
  UserName TEXT,                         -- 用户名
  ProcessId INTEGER,                     -- 进程 ID
  ThreadId INTEGER,                      -- 线程 ID
  -- 用户操作
  UserAction TEXT,                       -- 用户正在执行的操作
  FormName TEXT,                         -- 当前窗体
  ControlName TEXT,                      -- 当前控件
  -- 状态
  Severity INTEGER DEFAULT 2,            -- 严重级别 (0=Info, 1=Warning, 2=Error, 3=Critical)
  IsHandled INTEGER DEFAULT 0,           -- 是否已处理
  IsReported INTEGER DEFAULT 0,          -- 是否已上报
  ReportedAt TEXT,                       -- 上报时间
  -- 备注
  Notes TEXT,                            -- 开发者备注
  Resolution TEXT,                       -- 解决方案
  -- 时间戳
  OccurredAt TEXT DEFAULT (datetime('now', 'localtime')),
  Extra TEXT                             -- 额外信息 (JSON)
);

CREATE INDEX IF NOT EXISTS idx_exception_time ON ExceptionReports(OccurredAt DESC);
CREATE INDEX IF NOT EXISTS idx_exception_class ON ExceptionReports(ExceptionClass);
CREATE INDEX IF NOT EXISTS idx_exception_severity ON ExceptionReports(Severity);
CREATE INDEX IF NOT EXISTS idx_exception_handled ON ExceptionReports(IsHandled);

-- ----------------------------------------------------------------------------
-- 4. 动画资源表
-- ----------------------------------------------------------------------------

-- AnimationAssets: SVG/Lottie 动画资源
CREATE TABLE IF NOT EXISTS AnimationAssets (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  Name TEXT NOT NULL UNIQUE,             -- 资源名称
  Category TEXT DEFAULT 'General',       -- 分类 (Loading, Success, Error, Empty)
  -- 内容
  AssetType TEXT NOT NULL DEFAULT 'svg', -- 资源类型 (svg, lottie, gif)
  Content TEXT,                          -- SVG/Lottie JSON 内容 (内嵌)
  FilePath TEXT,                         -- 或外部文件路径
  -- 动画参数
  FrameCount INTEGER DEFAULT 1,          -- 帧数 (SVG 动画)
  FrameDuration INTEGER DEFAULT 100,     -- 帧间隔 (毫秒)
  Width INTEGER DEFAULT 64,              -- 建议宽度
  Height INTEGER DEFAULT 64,             -- 建议高度
  -- 状态
  IsEnabled INTEGER DEFAULT 1,           -- 是否启用
  SortOrder INTEGER DEFAULT 0,           -- 排序顺序
  -- 元数据
  Author TEXT,                           -- 作者
  License TEXT,                          -- 许可证
  SourceUrl TEXT,                        -- 来源 URL
  -- 时间戳
  CreatedAt TEXT DEFAULT (datetime('now', 'localtime')),
  Extra TEXT                             -- 额外配置 (JSON)
);

CREATE INDEX IF NOT EXISTS idx_animation_category ON AnimationAssets(Category);
CREATE INDEX IF NOT EXISTS idx_animation_type ON AnimationAssets(AssetType);

-- 预置加载动画 (简单 SVG)
INSERT OR IGNORE INTO AnimationAssets (Name, Category, AssetType, Content, FrameCount, FrameDuration, Width, Height) VALUES
  ('spinner_circle', 'Loading', 'svg', 
   '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><circle cx="32" cy="32" r="28" fill="none" stroke="#007AFF" stroke-width="4" stroke-dasharray="88 88" stroke-linecap="round"><animateTransform attributeName="transform" type="rotate" from="0 32 32" to="360 32 32" dur="1s" repeatCount="indefinite"/></circle></svg>',
   1, 0, 64, 64),
  ('spinner_dots', 'Loading', 'svg',
   '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><circle cx="16" cy="32" r="6" fill="#007AFF"><animate attributeName="opacity" values="1;0.3;1" dur="1s" repeatCount="indefinite" begin="0s"/></circle><circle cx="32" cy="32" r="6" fill="#007AFF"><animate attributeName="opacity" values="1;0.3;1" dur="1s" repeatCount="indefinite" begin="0.33s"/></circle><circle cx="48" cy="32" r="6" fill="#007AFF"><animate attributeName="opacity" values="1;0.3;1" dur="1s" repeatCount="indefinite" begin="0.66s"/></circle></svg>',
   1, 0, 64, 64),
  ('checkmark', 'Success', 'svg',
   '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><circle cx="32" cy="32" r="28" fill="#34C759"/><path d="M20 32 L28 40 L44 24" fill="none" stroke="white" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/></svg>',
   1, 0, 64, 64),
  ('error_cross', 'Error', 'svg',
   '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><circle cx="32" cy="32" r="28" fill="#FF3B30"/><path d="M22 22 L42 42 M42 22 L22 42" fill="none" stroke="white" stroke-width="4" stroke-linecap="round"/></svg>',
   1, 0, 64, 64),
  ('empty_box', 'Empty', 'svg',
   '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><rect x="12" y="20" width="40" height="32" rx="4" fill="none" stroke="#8E8E93" stroke-width="2"/><path d="M12 28 L32 38 L52 28" fill="none" stroke="#8E8E93" stroke-width="2"/><circle cx="32" cy="12" r="4" fill="#8E8E93"/></svg>',
   1, 0, 64, 64);

-- ----------------------------------------------------------------------------
-- 5. 测试快照表
-- ----------------------------------------------------------------------------

-- TestSnapshots: GUI 测试快照
CREATE TABLE IF NOT EXISTS TestSnapshots (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  TestName TEXT NOT NULL,                -- 测试名称
  FormName TEXT NOT NULL,                -- 窗体名称
  -- 快照内容
  SnapshotType TEXT DEFAULT 'state',     -- 类型 (state, screenshot, both)
  StateJson TEXT,                        -- 窗体状态 JSON
  ScreenshotPath TEXT,                   -- 截图文件路径
  ScreenshotHash TEXT,                   -- 截图 SHA256 哈希
  -- 控件状态
  ControlCount INTEGER DEFAULT 0,        -- 控件数量
  EnabledControls INTEGER DEFAULT 0,     -- 启用的控件数
  VisibleControls INTEGER DEFAULT 0,     -- 可见的控件数
  FocusedControl TEXT,                   -- 当前焦点控件
  -- 环境
  ScreenWidth INTEGER,                   -- 屏幕宽度
  ScreenHeight INTEGER,                  -- 屏幕高度
  DPI INTEGER,                           -- DPI
  Theme TEXT,                            -- 当前主题
  -- 版本
  Version INTEGER DEFAULT 1,             -- 快照版本号
  IsBaseline INTEGER DEFAULT 0,          -- 是否为基线快照
  -- 时间戳
  CreatedAt TEXT DEFAULT (datetime('now', 'localtime')),
  UpdatedAt TEXT DEFAULT (datetime('now', 'localtime')),
  Extra TEXT,                            -- 额外信息 (JSON)
  UNIQUE(TestName, FormName, Version)
);

CREATE INDEX IF NOT EXISTS idx_snapshot_test ON TestSnapshots(TestName);
CREATE INDEX IF NOT EXISTS idx_snapshot_form ON TestSnapshots(FormName);
CREATE INDEX IF NOT EXISTS idx_snapshot_baseline ON TestSnapshots(IsBaseline);

-- ----------------------------------------------------------------------------
-- 6. LLM 提示词模板表
-- ----------------------------------------------------------------------------

-- LLMPromptTemplates: 提示词模板
CREATE TABLE IF NOT EXISTS LLMPromptTemplates (
  Id INTEGER PRIMARY KEY AUTOINCREMENT,
  Name TEXT NOT NULL UNIQUE,             -- 模板名称
  Category TEXT DEFAULT 'General',       -- 分类
  Description TEXT,                      -- 描述
  -- 模板内容
  SystemPrompt TEXT,                     -- 系统提示词
  UserPromptTemplate TEXT NOT NULL,      -- 用户提示词模板 (支持 {{variable}})
  -- 参数
  Variables TEXT,                        -- 变量列表 (JSON: ["source_lang", "target_lang"])
  DefaultValues TEXT,                    -- 默认值 (JSON: {"source_lang": "en"})
  -- 推荐配置
  RecommendedConfig TEXT,                -- 推荐的 LLM 配置名
  RecommendedModel TEXT,                 -- 推荐的模型
  MaxTokens INTEGER,                     -- 推荐的最大 Token
  Temperature REAL,                      -- 推荐的温度
  -- 状态
  IsEnabled INTEGER DEFAULT 1,
  IsBuiltIn INTEGER DEFAULT 0,           -- 是否内置
  SortOrder INTEGER DEFAULT 0,
  -- 时间戳
  CreatedAt TEXT DEFAULT (datetime('now', 'localtime')),
  UpdatedAt TEXT DEFAULT (datetime('now', 'localtime')),
  Extra TEXT
);

CREATE INDEX IF NOT EXISTS idx_prompt_category ON LLMPromptTemplates(Category);

-- 预置提示词模板
INSERT OR IGNORE INTO LLMPromptTemplates (Name, Category, Description, SystemPrompt, UserPromptTemplate, Variables, DefaultValues, RecommendedConfig, Temperature, IsBuiltIn) VALUES
  ('translate_text', 'Translation', 'Translate text between languages',
   'You are a professional translator. Translate accurately while preserving meaning and tone.',
   'Translate the following text from {{source_lang}} to {{target_lang}}:\n\n{{text}}',
   '["source_lang", "target_lang", "text"]',
   '{"source_lang": "English", "target_lang": "Chinese"}',
   'Translation', 0.3, 1),
  ('explain_code', 'Code', 'Explain code in plain language',
   'You are an expert programmer. Explain code clearly and concisely.',
   'Explain the following {{language}} code:\n\n```{{language}}\n{{code}}\n```',
   '["language", "code"]',
   '{"language": "Delphi"}',
   'Default', 0.5, 1),
  ('generate_docs', 'Code', 'Generate documentation for code',
   'You are a technical writer. Generate clear, comprehensive documentation.',
   'Generate XML documentation comments for the following {{language}} code:\n\n```{{language}}\n{{code}}\n```',
   '["language", "code"]',
   '{"language": "Delphi"}',
   'CodeGen', 0.3, 1);

-- ----------------------------------------------------------------------------
-- 7. 更新 Schema 版本
-- ----------------------------------------------------------------------------

UPDATE SchemaInfo SET Value = '2.0' WHERE Key = 'SchemaVersion';
UPDATE SchemaInfo SET Value = datetime('now') WHERE Key = 'LastUpgrade';

-- ============================================================================
-- 完成提示
-- ============================================================================

SELECT 'Tier 2 Schema initialized successfully. Version: ' || 
  (SELECT Value FROM SchemaInfo WHERE Key = 'SchemaVersion') AS Result;
