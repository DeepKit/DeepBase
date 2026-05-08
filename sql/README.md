# DeepBase 数据库脚本说�?

## 📁 文件结构

```
sql/
├── README.md                    # 本文�?
├── upgrade_v*.sql               # Schema 升级脚本
�?
├── [DEPRECATED] tier0_init.sql  # 已废弃，请使�?create_sample_db.sql
├── [DEPRECATED] tier1_init.sql  # 已废弃，请使�?create_sample_db.sql
├── [DEPRECATED] tier2_init.sql  # 已废弃，请使�?create_sample_db.sql
�?
data/
├── create_sample_db.sql         # �?标准初始化脚本（23张表�?
└── 样例Config.db                # �?可直接复制使用的样例数据�?
```

## �?推荐：使用样例数据库

**最简单的集成方式**：直接复�?`data/样例Config.db`，重命名�?`{AppName}Config.db`�?

## 🗄�?Schema 说明 (v1.0.0)

### 表结构概�?(�?3张表)

| Tier | 表名 | 用�?|
|------|------|------|
| **0-核心** | SchemaInfo | 数据库版本信�?|
| **0-核心** | Settings | 应用配置存储 |
| **0-核心** | FormStates | 窗体状态持久化 |
| **0-核心** | Languages | 支持的语言定义 |
| **0-核心** | I18nTexts | 翻译文本存储 |
| **1-推荐** | Logs | 应用日志 |
| **1-推荐** | MRU | 最近使用项 |
| **1-推荐** | Hotkeys | 快捷键配�?|
| **1-推荐** | Queries | SQL查询定义(doQry) |
| **1-推荐** | Themes | UI主题 |
| **1-推荐** | Categories | 通用分类�?|
| **1-推荐** | Tags | 标签系统 |
| **2-扩展** | Providers | LLM服务提供�?|
| **2-扩展** | Models | LLM模型元数�?|
| **2-扩展** | LLMConfig | LLM配置 |
| **2-扩展** | LLMCalls | LLM调用历史 |
| **2-扩展** | LLMPrompts | 提示词模�?|
| **2-扩展** | LLMApiKeys | API密钥(加密) |
| **2-扩展** | ExceptionReports | 异常报告 |
| **2-扩展** | AnimationAssets | 动画资源 |
| **2-扩展** | Attachments | 附件存储 |
| **2-扩展** | TagMappings | 标签关联 |
| **2-扩展** | Notifications | 用户通知 |

### 初始化脚本使�?

#### 方法一：复制样例数据库（推荐）

```bash
copy data\样例Config.db MyAppConfig.db
```

#### 方法二：通过 SQLite 命令�?

```bash
sqlite3 config.db < data/create_sample_db.sql
```

#### 方法三：通过 Delphi 代码

```delphi
var
  Connection: TFDConnection;
  Script: TFDScript;
begin
  Connection := TFDConnection.Create(nil);
  Script := TFDScript.Create(nil);
  try
    Connection.DriverName := 'SQLite';
    Connection.Params.Database := 'config.db';
    Connection.Open;
    
    Script.Connection := Connection;
    Script.SQLScripts[0].SQL.LoadFromFile('data/create_sample_db.sql');
    Script.ExecuteAll;
  finally
    Script.Free;
    Connection.Free;
  end;
end;
```

#### 方法四：通过 DeepBase Manager（自动）

```delphi
// DeepBase 会自动检测数据库是否存在，不存在则自动初始化
if not DeepBase.Initialize then
  ShowMessage('Failed to initialize');
```

## 🔄 Schema 版本管理

### 版本号规�?

- **v0.1**: 初版（仅概念设计�?
- **v0.2**: 规划阶段
- **v0.3**: Phase 0 实现（当前版本）
- **v0.4**: Phase 1 扩展（计划）

### 升级脚本命名规范

升级脚本使用以下命名格式�?

```
sql/upgrade_v{old}_to_v{new}.sql
```

**示例**:
- `upgrade_v0.2_to_v0.3.sql`
- `upgrade_v0.3_to_v0.4.sql`

### 升级脚本结构

```sql
-- ============================================================================
-- DeepBase Schema Upgrade: v0.2 -> v0.3
-- ============================================================================

BEGIN TRANSACTION;

-- 1. 添加新表
CREATE TABLE IF NOT EXISTS NewTable (...);

-- 2. 修改现有�?
ALTER TABLE ExistingTable ADD COLUMN NewColumn TEXT;

-- 3. 数据迁移
INSERT INTO NewTable SELECT ... FROM OldTable;

-- 4. 更新版本�?
UPDATE SchemaInfo SET Value = '0.3' WHERE Key = 'SchemaVersion';
UPDATE SchemaInfo SET Value = datetime('now') WHERE Key = 'LastUpgrade';

COMMIT;
```

## 🔍 Schema 验证

### 检查表结构

```sql
-- 列出所有表
SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;

-- 检查版�?
SELECT * FROM SchemaInfo WHERE Key = 'SchemaVersion';

-- 验证索引
SELECT name FROM sqlite_master WHERE type='index';
```

### 数据完整性检�?

```sql
-- 检查必需的配置是否存�?
SELECT Key FROM Settings WHERE Key IN ('App.Language', 'App.DebugMode', 'App.Theme');

-- 检查默认语言是否设置
SELECT COUNT(*) AS DefaultLangCount FROM Languages WHERE IsDefault = 1;

-- 检查翻译表是否有数�?
SELECT LangCode, COUNT(*) AS TextCount FROM I18nTexts GROUP BY LangCode;
```

## 🛠�?维护操作

### 备份数据�?

```bash
# 完整备份
cp config.db config_backup_$(date +%Y%m%d).db

# 或使�?SQLite 备份命令
sqlite3 config.db ".backup config_backup.db"
```

### 压缩数据�?

```sql
-- 清理未使用空�?
VACUUM;

-- 分析并优化查询计�?
ANALYZE;
```

### 重建索引

```sql
-- 删除现有索引
DROP INDEX IF EXISTS idx_i18n_lang;
DROP INDEX IF EXISTS idx_i18n_source;

-- 重新创建
CREATE INDEX idx_i18n_lang ON I18nTexts(LangCode);
CREATE INDEX idx_i18n_source ON I18nTexts(SourceText);
```

## 📊 性能优化建议

### 索引策略

1. **I18nTexts �?*�?
   - `SourceText` 列（查询最频繁�?
   - `LangCode` 列（按语言过滤�?
   - 联合索引 `(LangCode, SourceText)` 可进一步优�?

2. **Settings �?*�?
   - 主键 `Key` 已自动索�?
   - 如果频繁�?`Category` 查询，可考虑增加索引

3. **FormStates �?*�?
   - 主键 `FormName` 已足�?

### 缓存策略

- **Config**: 内存缓存，写时更�?
- **i18n**: LRU 缓存（容�?10000�?
- **FormStates**: 仅在需要时查询

## ⚠️ 注意事项

1. **不要直接修改 SchemaInfo �?*，除非你知道自己在做什�?
2. **升级前务必备份数据库**
3. **使用事务包裹数据迁移操作**
4. **测试环境先验证升级脚�?*
5. **生产环境升级需要停服维�?*

## 🔗 相关文档

- [DeepBase 规范](../docs/03.03.DeepBase-4H-技术规�?v1.0.md)
- [快速开始](../docs/01.01.DeepBase-4AI-集成指南-v1.0.md)
- [API 参考](../docs/05.01.DeepBase-4AI-API参�?v1.0.md)
