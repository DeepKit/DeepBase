# UniBase 常见错误速查

> 版本: 1.1.0  
> 适用于: 集成 UniBase 框架的应用程序

本文档列出常见错误及其解决方案，帮助快速定位和解决问题。

---

## 错误码速查表

使用 `UniBase.DBException` 统一异常处理时，可通过错误码快速定位问题：

| 错误码 | 含义 | 常见原因 |
|--------|------|----------|
| DB-1001 | 无法连接到数据库 | 数据库文件不存在或路径错误 |
| DB-1002 | 数据库连接已断开 | 网络中断或连接超时 |
| DB-1006 | 数据库正被其他程序使用 | 多进程访问未启用 WAL |
| DB-2002 | SQL 语法错误 | SQL 语句拼写错误 |
| DB-2003 | 数据表不存在 | 未初始化 Schema |
| DB-2004 | 数据字段不存在 | Schema 版本过旧 |
| DB-3001 | 数据已存在，不能重复添加 | 唯一约束冲突 |
| DB-3002 | 关联数据不存在或无法删除 | 外键约束冲突 |
| DB-3003 | 必填字段不能为空 | NULL 约束冲突 |
| DB-9001 | 数据库操作失败 | 未知错误 |

---

## 数据库错误

### Table 'XXX' not found / no such table: XXX

**原因**: 数据库未初始化或 Schema 不完整

**解决方案**:
1. 确保调用了 `EnsureSchema` 初始化数据库
2. 运行诊断并自动修复：
   ```pascal
   var Results := DiagnoseAll(ConfigDB);
   AutoFix(ConfigDB, Results);
   ```
3. 或手动执行建表 SQL

---

### Column 'XXX' not found / no such column: XXX

**原因**: Schema 版本不匹配，缺少新增字段

**解决方案**:
1. 运行 `DiagnoseAll` 检查缺失字段
2. 使用 `AutoFix` 自动添加缺失字段
3. 或手动执行:
   ```sql
   ALTER TABLE TableName ADD COLUMN ColumnName TEXT;
   ```

---

### Database is locked / SQLITE_BUSY

**原因**: 多进程/多线程同时写入数据库

**解决方案**:
1. 启用 WAL 模式（推荐）:
   ```sql
   PRAGMA journal_mode=WAL;
   ```
2. 增加等待超时:
   ```sql
   PRAGMA busy_timeout=5000;
   ```
3. 确保写操作使用事务
4. 避免长时间持有数据库连接

---

### UNIQUE constraint failed

**原因**: 插入重复的主键或唯一索引值

**解决方案**:
1. 使用 `INSERT OR REPLACE` 替代 `INSERT`
2. 使用 `INSERT OR IGNORE` 忽略重复
3. 先查询是否存在，再决定插入或更新
4. 检查数据来源是否有重复

---

### Foreign key constraint failed

**原因**: 引用了不存在的外键记录

**解决方案**:
1. 确保先创建父表记录
2. 检查外键引用的 ID 是否正确
3. 如需跳过外键检查:
   ```sql
   PRAGMA foreign_keys=OFF;
   -- 执行操作
   PRAGMA foreign_keys=ON;
   ```

---

## 编码和乱码问题

### 中文显示为乱码

**原因**: 编码不一致

**解决方案**:
1. 确保数据库连接使用 UTF-8:
   ```pascal
   FDConnection.Params.Add('CharacterSet=UTF8');
   ```
2. 检查字符串是否正确转码
3. 确保界面控件支持 Unicode

---

### 存储时字符被截断

**原因**: 字符串长度计算问题

**解决方案**:
1. TEXT 类型在 SQLite 中没有长度限制，检查代码层面的截断
2. 检查是否使用了 VARCHAR 并超出长度
3. 检查传输过程中的编码转换

---

## LLM 相关错误

### Unable to decrypt API key

**原因**: DPAPI 加密的密钥在新机器上无法解密

**解决方案**:
1. **重新输入 API Key** - 最简单的方案
2. **使用导出/导入功能**:
   - 旧机器: 导出 API Key（临时密码保护）
   - 新机器: 导入并输入密码
3. **切换到主密码模式**: 使用 AES 加密代替 DPAPI

**重要提示**:
- DPAPI 密钥绑定到 Windows 用户账户
- 换机器、重装系统、域账户迁移都会导致失效
- 建议重要数据提前备份

---

### API call timeout

**原因**: 网络问题或 API 服务响应慢

**解决方案**:
1. 增加超时时间:
   ```pascal
   LLMConfig.TimeoutMs := 120000; // 2分钟
   ```
2. 检查网络连接和代理设置
3. 检查 API 服务状态
4. 使用更快的模型（如 gpt-4o-mini）

---

### Invalid API key

**原因**: API Key 无效或已过期

**解决方案**:
1. 检查 API Key 是否正确输入
2. 检查 API Key 是否已过期
3. 检查账户余额
4. 确认使用了正确的 Provider

---

### Model not found

**原因**: 请求的模型 ID 不存在或不可用

**解决方案**:
1. 检查模型 ID 是否拼写正确
2. 确认该模型对你的账户可用
3. 查看 Provider 的模型列表更新
4. 使用 `Models` 表中的预置模型

---

## 版本和升级问题

### Schema version mismatch

**原因**: 数据库版本与 UniBase 版本不一致

**解决方案**:
1. 运行 `DiagnoseAll` 查看差异
2. 使用 `AutoFix` 自动升级缺失项
3. 或运行 Migration 脚本手动升级

---

### Database too old

**原因**: 数据库版本低于 `MIN_COMPATIBLE_SCHEMA_VERSION`

**解决方案**:
1. 备份旧数据库
2. 运行完整 Migration 脚本
3. 或创建新数据库并迁移数据

---

## 诊断工具使用

### 快速诊断（含数据完整性检查）

```pascal
uses UniBase.Diagnose;

// 一键诊断（包含 Schema + 数据完整性检查）
var Results := DiagnoseAll(ConfigDB);

// 查看报告
if Length(Results) > 0 then
begin
  ShowMessage(GenerateDiagnoseReport(Results));
  
  // 询问是否自动修复
  if MessageDlg('是否自动修复?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    var Fixed := AutoFix(ConfigDB, Results);
    ShowMessage(Format('已修复 %d 个问题', [Fixed]));
  end;
end
else
  ShowMessage('数据库检查通过，一切正常！');
```

### 单独检查数据完整性

```pascal
// 仅检查数据完整性（外键、必填字段、枚举值）
var IntegrityResults := CheckDataIntegrity(ConfigDB);
for var R in IntegrityResults do
begin
  case R.IssueType of
    ditForeignKey: ShowMessage('外键问题: ' + R.Issue);
    ditNullValue:  ShowMessage('空值问题: ' + R.Issue);
    ditInvalidEnum: ShowMessage('枚举问题: ' + R.Issue);
  end;
end;
```

### 检查特定表

```pascal
// 检查表是否存在
if not TableExists(ConfigDB, 'Categories') then
  ShowMessage('Categories 表不存在');

// 检查列是否存在
if not ColumnExists(ConfigDB, 'Settings', 'DefaultValue') then
  AddColumnIfNotExists(ConfigDB, 'Settings', 'DefaultValue', 'TEXT');
```

---

## API Key 加密配置说明

### 加密方式

UniBase 支持两种 API Key 加密方式：

| 方式 | 说明 | 优点 | 缺点 |
|-----|------|------|------|
| DPAPI | Windows 数据保护 API | 无需密码，自动加密 | 绑定机器，不可迁移 |
| AES | 主密码派生密钥 | 可跨机器，可迁移 | 需要记住密码 |

### 配置方式

在 `LLMApiKeys` 表中：
- `IsEncrypted`: 是否加密 (1=是, 0=否)
- `EncryptionMethod`: 加密方式 ('DPAPI' 或 'AES')

### 建议

1. **本地开发**: 使用 DPAPI（方便）
2. **需要迁移**: 使用 AES + 主密码
3. **团队协作**: 使用环境变量或密钥管理服务，不存储在数据库

### 迁移流程 (DPAPI → 新机器)

```
旧机器:
1. 导出 API Key (临时密码保护)
2. 发送加密包到新机器

新机器:
1. 导入加密包
2. 输入临时密码
3. 用新机器的 DPAPI 重新加密
```

---

## SQL 日志与慢查询分析

使用 `UniBase.SQLLogger` 监控 SQL 执行：

### 启用 SQL 日志

```pascal
uses UniBase.SQLLogger;

// 启用日志
TSQLLogger.Enabled := True;
TSQLLogger.SlowQueryThresholdMs := 500;  // 超过 500ms 视为慢查询

// 设置慢查询回调
TSQLLogger.OnSlowQuery := procedure(Entry: TSQLLogEntry)
begin
  ShowMessage(Format('慢查询警告: %dms - %s', [Entry.DurationMs, Entry.SQL]));
end;
```

### 查看统计

```pascal
// 获取统计报告
ShowMessage(TSQLLogger.GetStatistics);

// 获取失败的查询
var FailedQueries := TSQLLogger.GetFailedQueries(10);
for var Q in FailedQueries do
  Memo1.Lines.Add(Format('%s: %s', [Q.ErrorMessage, Q.SQL]));
```

---

## 统一异常处理

使用 `UniBase.DBException` 包装数据库异常：

```pascal
uses UniBase.DBException;

try
  Query.ExecSQL;
except
  on E: Exception do
  begin
    var DBEx := EUniBaseDB.Wrap(E, Query.SQL.Text, '保存用户资料');
    // 给用户看友好消息（不含 SQL）
    ShowMessage(DBEx.UserMessage);
    // 记录详细日志（含 SQL）
    Logger.Error(DBEx.DetailedMessage);
    raise DBEx;
  end;
end;
```

---

## 联系支持

如果以上方案无法解决问题，请：

1. 运行 `DiagnoseAll` 并保存诊断报告
2. 启用 `TSQLLogger` 并导出日志
3. 记录错误码和堆栈跟踪
4. 准备最小复现步骤
5. 联系开发团队

---

## 相关文档

- [集成uniBase系统初始数据库和字段说明.md](集成uniBase系统初始数据库和字段说明.md)
- [UniBase集成检查清单.md](UniBase集成检查清单.md)

## 调试相关单元

| 单元 | 用途 |
|------|------|
| `UniBase.Diagnose` | Schema 检查、数据完整性检查、自动修复 |
| `UniBase.DBException` | 统一异常处理、友好错误消息、错误码 |
| `UniBase.SQLLogger` | SQL 执行日志、慢查询检测、统计分析 |
