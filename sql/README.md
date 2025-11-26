# UniBase 数据库脚本说明

## 📁 文件结构

```
sql/
├── tier0_init.sql        # Tier 0 最小核心表（必需）
├── tier1_init.sql        # Tier 1 推荐功能表（待创建）
├── tier2_init.sql        # Tier 2 高级功能表（待创建）
└── upgrade_v*.sql        # Schema 升级脚本（待创建）
```

## 🗄️ Tier 0 Schema 说明

### 表结构概览

| 表名 | 用途 | 记录数 |
|------|------|--------|
| `SchemaInfo` | 数据库版本信息 | 3 条 |
| `ProjectInfo` | 项目元信息 | 5 条 |
| `Settings` | 通用配置 | 3+ 条 |
| `FormStates` | 窗体状态 | 动态 |
| `Languages` | 支持的语言列表 | 4 条（预置） |
| `I18nTexts` | 国际化翻译文本 | 5+ 条（预置） |

### 初始化脚本使用

#### 方法一：通过 SQLite 命令行

```bash
sqlite3 config.db < tier0_init.sql
```

#### 方法二：通过 Delphi 代码

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
    Script.SQLScripts[0].SQL.LoadFromFile('sql/tier0_init.sql');
    Script.ExecuteAll;
  finally
    Script.Free;
    Connection.Free;
  end;
end;
```

#### 方法三：通过 UniBase Manager (推荐)

```delphi
// UniBase 会自动检测数据库是否存在，不存在则自动初始化
if not UniBase.Initialize then
  ShowMessage('Failed to initialize');
```

## 🔄 Schema 版本管理

### 版本号规范

- **v0.1**: 初版（仅概念设计）
- **v0.2**: 规划阶段
- **v0.3**: Phase 0 实现（当前版本）
- **v0.4**: Phase 1 扩展（计划）

### 升级脚本命名规范

升级脚本使用以下命名格式：

```
sql/upgrade_v{old}_to_v{new}.sql
```

**示例**:
- `upgrade_v0.2_to_v0.3.sql`
- `upgrade_v0.3_to_v0.4.sql`

### 升级脚本结构

```sql
-- ============================================================================
-- UniBase Schema Upgrade: v0.2 -> v0.3
-- ============================================================================

BEGIN TRANSACTION;

-- 1. 添加新表
CREATE TABLE IF NOT EXISTS NewTable (...);

-- 2. 修改现有表
ALTER TABLE ExistingTable ADD COLUMN NewColumn TEXT;

-- 3. 数据迁移
INSERT INTO NewTable SELECT ... FROM OldTable;

-- 4. 更新版本号
UPDATE SchemaInfo SET Value = '0.3' WHERE Key = 'SchemaVersion';
UPDATE SchemaInfo SET Value = datetime('now') WHERE Key = 'LastUpgrade';

COMMIT;
```

## 🔍 Schema 验证

### 检查表结构

```sql
-- 列出所有表
SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;

-- 检查版本
SELECT * FROM SchemaInfo WHERE Key = 'SchemaVersion';

-- 验证索引
SELECT name FROM sqlite_master WHERE type='index';
```

### 数据完整性检查

```sql
-- 检查必需的配置是否存在
SELECT Key FROM Settings WHERE Key IN ('App.Language', 'App.DebugMode', 'App.Theme');

-- 检查默认语言是否设置
SELECT COUNT(*) AS DefaultLangCount FROM Languages WHERE IsDefault = 1;

-- 检查翻译表是否有数据
SELECT LangCode, COUNT(*) AS TextCount FROM I18nTexts GROUP BY LangCode;
```

## 🛠️ 维护操作

### 备份数据库

```bash
# 完整备份
cp config.db config_backup_$(date +%Y%m%d).db

# 或使用 SQLite 备份命令
sqlite3 config.db ".backup config_backup.db"
```

### 压缩数据库

```sql
-- 清理未使用空间
VACUUM;

-- 分析并优化查询计划
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

1. **I18nTexts 表**：
   - `SourceText` 列（查询最频繁）
   - `LangCode` 列（按语言过滤）
   - 联合索引 `(LangCode, SourceText)` 可进一步优化

2. **Settings 表**：
   - 主键 `Key` 已自动索引
   - 如果频繁按 `Category` 查询，可考虑增加索引

3. **FormStates 表**：
   - 主键 `FormName` 已足够

### 缓存策略

- **Config**: 内存缓存，写时更新
- **i18n**: LRU 缓存（容量 10000）
- **FormStates**: 仅在需要时查询

## ⚠️ 注意事项

1. **不要直接修改 SchemaInfo 表**，除非你知道自己在做什么
2. **升级前务必备份数据库**
3. **使用事务包裹数据迁移操作**
4. **测试环境先验证升级脚本**
5. **生产环境升级需要停服维护**

## 🔗 相关文档

- [UniBase 规范](../docs/unibase-spec-v0.3.md)
- [快速开始](../docs/QuickStart.md)
- [API 参考](../docs/API-Reference-Phase0.md)
