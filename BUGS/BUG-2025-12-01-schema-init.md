# DeepBase v0.3 Schema 初始�?Bug 报告

**报告日期**: 2025-12-01
**报告�?*: DeepDeepDeepDeepDeepInsight 项目集成测试
**DeepBase 版本**: v0.3
**严重程度**: 🔴 �?(阻塞应用启动)
**状�?*: �?已修�?(2025-12-01)

---

## 概述

�?DeepDeepDeepDeepDeepInsight 项目集成 DeepBase 框架后，应用启动时出现多�?SQLite 错误，导�?DeepBase 配置数据库初始化失败�?

---

## 错误信息

启动时抛出以下异常：

```
[FireDAC][Phys][SQLite] ERROR: table SchemaInfo has 3 columns but 2 values were supplied
[FireDAC][Phys][SQLite] ERROR: table ProjectInfo has 5 columns but 2 values were supplied
[FireDAC][Phys][SQLite] ERROR: table Settings has no column named ValueType
[FireDAC][Phys][SQLite] ERROR: table Languages has 5 columns but 7 values were supplied
[FireDAC][Phys][SQLite] ERROR: near "now": syntax error
[FireDAC][Phys][SQLite] ERROR: no such column: DisplayName
[FireDAC][Phys][SQLite] ERROR: table Logs has no column named LogTime
```

---

## Bug 分析

### BUG-018: SchemaInfo INSERT 列数不匹�?

**文件**: `DeepBase.Schema.pas` �?`DeepBase.Manager.pas`
**问题**: `INSERT INTO SchemaInfo` 语句提供的值数量与表定义的列数不一�?

**预期**: SchemaInfo 表有 3 列，INSERT 应提�?3 个�?
**实际**: INSERT 只提供了 2 个�?

### BUG-019: ProjectInfo INSERT 列数不匹�?

**文件**: `DeepBase.Schema.pas` �?`DeepBase.Manager.pas`
**问题**: `INSERT INTO ProjectInfo` 语句提供的值数量与表定义的列数不一�?

**预期**: ProjectInfo 表有 5 列，INSERT 应提�?5 个�?
**实际**: INSERT 只提供了 2 个�?

### BUG-020: Settings 表缺�?ValueType �?

**文件**: `DeepBase.Schema.pas`
**问题**: 代码尝试访问 `ValueType` 列，�?Settings 表定义中没有该列

**建议修复**: 
- 检�?`SQL_TIER0_SETTINGS` 常量，确保包�?`ValueType` �?
- 或修改访问代码，不使用该�?

### BUG-021: Languages INSERT 列数不匹�?

**文件**: `DeepBase.Schema.pas`
**位置**: `SQL_TIER0_LANGUAGES_DATA` 常量
**问题**: Languages 表有 5 列，�?INSERT 提供�?7 个�?

**当前代码** (line 101-102):
```pascal
SQL_TIER0_LANGUAGES_DATA =
  'INSERT OR REPLACE INTO Languages VALUES (''en-US'', ''English'', ''English'', ''us.png'', 1, 1, 0);' + #13#10 +
  'INSERT OR REPLACE INTO Languages VALUES (''zh-CN'', ''Chinese (Simplified)'', ''简体中�?', ''cn.png'', 1, 0, 1);';
```

**建议修复**: 调整 INSERT 语句或表定义使列数匹�?

### BUG-022: datetime('now') 语法错误

**文件**: `DeepBase.LLM.pas`
**位置**: lines 1394, 1402, 1429
**问题**: �?SQL 查询字符串中使用 `datetime('now')` 会被 FireDAC 误解析为参数 `:now`

**问题代码**:
```pascal
// GetUsageStats (line 1394)
Query.SQL.Text :=
  'SELECT ... WHERE CallTime >= datetime(''now'', ''-' + IntToStr(DaysBack) + ' days'')';

// ClearOldCalls (line 1429)  
Query.SQL.Text := 'DELETE FROM LLMCalls WHERE CallTime < datetime(''now'', ''-' + IntToStr(DaysToKeep) + ' days'')';
```

**建议修复**:
```pascal
var
  CutoffTime: string;
begin
  CutoffTime := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now - DaysBack);
  Query.SQL.Text := 'SELECT ... WHERE CallTime >= :CutoffTime';
  Query.ParamByName('CutoffTime').AsString := CutoffTime;
```

### BUG-023: MRU 表缺�?DisplayName �?

**文件**: `DeepBase.Schema.pas` �?`DeepBase.MRU.pas`
**问题**: 代码访问 `DisplayName` 列，但表中不存在

**�?*: 根据 `SQL_TIER1_MRU` 定义 (line 153-166)，表定义�?*�?* `DisplayName` 列�?
问题可能是旧数据库没有该列，需要迁移脚本�?

### BUG-024: Logs 表缺�?LogTime �?

**文件**: `DeepBase.Schema.pas` vs 实际表结�?
**问题**: 旧版 Logs 表使�?`Timestamp` 列，新代码期�?`LogTime` �?

**旧表结构**:
```
LogID, Timestamp, Level, Module, Message, Details, StackTrace
```

**新表结构** (SQL_TIER1_LOGS):
```
Id, LogTime, LogLevel, Source, Message, ExceptionClass, ExceptionMessage, StackTrace, ThreadId, UserId
```

**建议修复**: 提供数据库迁移脚本，或在初始化时检测并迁移旧表

---

## 复现步骤

1. 使用 DeepBase v0.3 创建新项�?
2. 调用 `DeepBase.Manager.Initialize()` 初始化框�?
3. 观察控制�?日志输出

---

## 环境信息

- **Delphi 版本**: RAD Studio 12.2 (Delphi 12 Athens)
- **编译�?*: dcc64.exe version 36.0
- **数据�?*: SQLite (FireDAC)
- **操作系统**: Windows

---

## 临时解决方案

根据当前 Schema 迁移策略�?
1. **方案 A (开发环�?**: 删除 `Config.db` 文件，让程序重建
2. **方案 B (生产环境)**: 执行 `upgrade_schema_fix.sql` 迁移脚本

---

## 建议优先�?

| Bug ID | 优先�?| 说明 |
|--------|--------|------|
| BUG-022 | P0 | datetime 语法错误导致查询完全失败 |
| BUG-018/019/021 | P0 | INSERT 失败导致初始化数据缺�?|
| BUG-020/023/024 | P1 | 列缺失导致运行时错误 |

---

## 附件

- 错误日志截图: (见上方错误信�?
- 相关代码位置: `DeepBase.Schema.pas`, `DeepBase.LLM.pas`, `DeepBase.Manager.pas`

---

*报告完成*

---

## 修复记录 (2025-12-01)

### 修复方案

1. **`DeepBase.Schema.pas`**:
   - `SQL_TIER0_LANGUAGES_DATA` 改用显式列名 INSERT，避免旧表结构冲�?

2. **`DeepBase.Manager.pas`**:
   - `CreateSchema` 重构为容错机制：首次失败后尝试修复列结构
   - 新增 `EnsureSchemaColumns` 方法自动检测并添加缺失�?

3. **迁移脚本**:
   - 创建 `sql/upgrade_v0_2_to_v0_3.sql`
   - 包含所有表�?ALTER TABLE 语句
   - 包含旧列到新列的数据迁移

### 影响范围

- 现有旧版数据库将自动升级
- 新建数据库不受影�?
- 无需手动干预
