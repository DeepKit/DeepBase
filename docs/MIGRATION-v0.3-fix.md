# UniBase v0.3 Schema 修复指南

## 概述

UniBase v0.3 发现了多个 SQL 相关的 bug，可能导致以下错误：

- `[FireDAC][Phys][SQLite] ERROR: near "cn": syntax error`
- `[FireDAC][Phys][SQLite] ERROR: near "now": syntax error`
- `[FireDAC][Phys][SQLite]-335. Parameter [TIME] data type is unknown`
- 表结构不一致（列缺失或类型错误）

本文档提供修复步骤。

---

## 一、问题根源

### Bug 列表

| Bug ID | 严重程度 | 问题描述 |
|--------|----------|----------|
| BUG-015 | 🔴 高 | INSERT/UPDATE 中的 `datetime('now')` 被 FireDAC 误解析为参数 |
| BUG-016 | 🔴 高 | Schema SQL 常量拼接时缺少换行分隔符 |
| BUG-017 | 🔴 高 | SQL 脚本文件与 Pascal 代码定义不一致 |

### 受影响模块

- `UniBase.Schema.pas` - Schema SQL 定义
- `UniBase.LLM.pas` - LLM 配置和调用记录
- `UniBase.LLM.Manager.pas` - Prompt 管理
- `UniBase.MRU.pas` - 最近使用记录
- `Tray.Database.pas` - Tray 工具数据库
- `Tray.NotesFrame.pas` / `Tray.ProjectsFrame.pas` / `Tray.SchedulerFrame.pas`

---

## 二、修复步骤

### 步骤 1：更新 UniBase 框架

从最新的 UniBase 仓库拉取代码，确保以下文件已更新：

```
Core/UniBase.Schema.pas
Core/UniBase.LLM.pas
Core/UniBase.LLM.Manager.pas
Core/UniBase.MRU.pas
sql/tier0_init.sql
sql/tier1_init.sql
sql/tier2_init.sql
```

### 步骤 2：重新编译项目

完全重新编译您的项目，确保使用更新后的 UniBase 单元。

### 步骤 3：修复现有数据库

根据您的情况选择以下方案之一：

---

## 三、数据库修复方案

### 方案 A：删除并重建数据库（推荐用于开发环境）

如果数据库中没有重要数据，直接删除后让程序自动重建：

```
1. 关闭程序
2. 删除 Config.db 文件
3. 重新启动程序（将自动创建新数据库）
```

### 方案 B：运行迁移脚本（推荐用于生产环境）

将以下 SQL 保存为 `upgrade_schema_fix.sql` 并执行：

```sql
-- ============================================================================
-- UniBase v0.3 Schema 修复脚本
-- 执行前请备份数据库！
-- ============================================================================

-- 1. 修复 Logs 表（如果使用旧 Schema 创建）
-- 检查是否需要重建 Logs 表
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

-- 如果旧表存在且有数据，迁移数据
INSERT OR IGNORE INTO Logs_new (Id, LogTime, LogLevel, Source, Message, StackTrace, ThreadId)
SELECT Id, 
       COALESCE(LogTime, datetime('now')), 
       CASE WHEN typeof(Level) = 'integer' THEN 
         CASE Level WHEN 0 THEN 'DEBUG' WHEN 1 THEN 'INFO' WHEN 2 THEN 'WARN' WHEN 3 THEN 'ERROR' ELSE 'FATAL' END
       ELSE COALESCE(LogLevel, 'INFO') END,
       Source, 
       Message, 
       StackTrace, 
       ThreadId
FROM Logs WHERE 1=1;

-- 替换表（如果有数据）
DROP TABLE IF EXISTS Logs_backup;
ALTER TABLE Logs RENAME TO Logs_backup;
ALTER TABLE Logs_new RENAME TO Logs;

-- 重建索引
CREATE INDEX IF NOT EXISTS idx_logs_time ON Logs(LogTime);
CREATE INDEX IF NOT EXISTS idx_logs_level ON Logs(LogLevel);

-- 2. 修复 MRU 表
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
SELECT Id, Category, ItemKey, DisplayName, LastAccess, AccessCount, 
       COALESCE(IconIndex, 0), COALESCE(IsPinned, 0), Extra
FROM MRU WHERE 1=1;

DROP TABLE IF EXISTS MRU_backup;
ALTER TABLE MRU RENAME TO MRU_backup;
ALTER TABLE MRU_new RENAME TO MRU;

CREATE INDEX IF NOT EXISTS idx_mru_category_time ON MRU(Category, LastAccess DESC);

-- 3. 修复 Hotkeys 表
CREATE TABLE IF NOT EXISTS Hotkeys_new (
  ActionName TEXT PRIMARY KEY,
  Shortcut TEXT NOT NULL,
  Description TEXT,
  Category TEXT
);

INSERT OR IGNORE INTO Hotkeys_new (ActionName, Shortcut, Description, Category)
SELECT ActionName, 
       CASE WHEN typeof(Shortcut) = 'integer' THEN CAST(Shortcut AS TEXT) ELSE Shortcut END,
       Description, 
       Category
FROM Hotkeys WHERE 1=1;

DROP TABLE IF EXISTS Hotkeys_backup;
ALTER TABLE Hotkeys RENAME TO Hotkeys_backup;
ALTER TABLE Hotkeys_new RENAME TO Hotkeys;

-- 4. 修复 Themes 表
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
FROM Themes WHERE 1=1;

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

-- 5. 更新 Schema 版本
UPDATE SchemaInfo SET Value = '0.3' WHERE Key = 'SchemaVersion';
UPDATE SchemaInfo SET Value = CURRENT_TIMESTAMP WHERE Key = 'LastUpgrade';

-- 6. 清理备份表（可选，确认数据无误后执行）
-- DROP TABLE IF EXISTS Logs_backup;
-- DROP TABLE IF EXISTS MRU_backup;
-- DROP TABLE IF EXISTS Hotkeys_backup;
-- DROP TABLE IF EXISTS Themes_backup;

-- 完成
SELECT 'Schema migration completed. Version: ' || Value AS Result 
FROM SchemaInfo WHERE Key = 'SchemaVersion';
```

### 执行迁移脚本

**方法 1：使用 SQLite 命令行**
```bash
sqlite3 Config.db < upgrade_schema_fix.sql
```

**方法 2：使用 Delphi 代码**
```delphi
procedure RunMigrationScript(Connection: TFDConnection);
var
  Script: TFDScript;
  SQL: string;
begin
  SQL := TFile.ReadAllText('upgrade_schema_fix.sql', TEncoding.UTF8);
  
  Script := TFDScript.Create(nil);
  try
    Script.Connection := Connection;
    Script.SQLScripts.Add;
    Script.SQLScripts[0].SQL.Text := SQL;
    Script.ExecuteAll;
  finally
    Script.Free;
  end;
end;
```

**方法 3：使用 DB Browser for SQLite**
1. 打开 `Config.db`
2. 切换到 "Execute SQL" 标签
3. 粘贴脚本内容并执行

---

## 四、代码修改清单

如果您在自己的代码中直接使用了 `datetime('now')` 的写法，需要修改为参数化查询：

### ❌ 错误写法
```delphi
Query.SQL.Text := 
  'INSERT INTO MyTable (Name, CreatedAt) VALUES (:Name, datetime(''now'', ''localtime''))';
Query.ParamByName('Name').AsString := 'Test';
Query.ExecSQL;
```

### ✅ 正确写法
```delphi
var
  NowStr: string;
begin
  NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
  
  Query.SQL.Text := 
    'INSERT INTO MyTable (Name, CreatedAt) VALUES (:Name, :CreatedAt)';
  Query.ParamByName('Name').AsString := 'Test';
  Query.ParamByName('CreatedAt').AsString := NowStr;
  Query.ExecSQL;
end;
```

### 快速搜索受影响代码

在您的项目中搜索以下模式：

```
datetime('now
datetime(''now
```

将所有匹配项改为参数化方式。

---

## 五、验证修复

运行以下 SQL 验证表结构：

```sql
-- 检查 Logs 表
PRAGMA table_info(Logs);
-- 应该看到: LogTime (TEXT), LogLevel (TEXT), ExceptionClass, ExceptionMessage, UserId

-- 检查 MRU 表
PRAGMA table_info(MRU);
-- 应该看到: DisplayName (TEXT)

-- 检查 Hotkeys 表
PRAGMA table_info(Hotkeys);
-- 应该看到: Shortcut (TEXT)

-- 检查 Themes 表
PRAGMA table_info(Themes);
-- 应该看到: AccentColor (INTEGER), CustomCSS (TEXT)

-- 检查版本
SELECT * FROM SchemaInfo;
-- SchemaVersion 应该是 0.3
```

---

## 六、常见问题

### Q: 迁移脚本执行失败怎么办？

A: 
1. 确保先备份数据库
2. 检查错误消息，可能是某些表不存在
3. 可以分段执行脚本，跳过不需要的部分

### Q: 程序启动时仍然报错？

A:
1. 确认已完全重新编译项目
2. 检查是否有缓存的 .dcu 文件
3. 清理项目后重新编译：`Build > Clean` 然后 `Build > Build All`

### Q: 数据丢失了怎么办？

A: 迁移脚本会创建 `*_backup` 表，可以从中恢复数据：
```sql
INSERT INTO Logs SELECT * FROM Logs_backup;
```

---

## 七、联系支持

如有问题，请在 UniBase 仓库提交 Issue，附上：
- 错误消息截图
- 数据库 Schema 信息 (`PRAGMA table_info(表名)`)
- UniBase 版本号

---

*文档版本: 2025-12-01*
*适用于: UniBase v0.3*
