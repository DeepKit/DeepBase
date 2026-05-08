# DeepBase Third-Party Database Drivers

第三方数据库驱动适配器，提供 PostgreSQL �?MySQL 的高级功能支持�?
## 文件列表

| 文件 | 说明 |
|------|------|
| `DeepBase.DB.PostgreSQL.pas` | PostgreSQL 驱动适配�?|
| `DeepBase.DB.MySQL.pas` | MySQL 驱动适配�?|

## PostgreSQL 驱动

### 特色功能

- **JSONB 操作**: jsonb_set, jsonb_remove, jsonb_concat
- **全文搜索**: tsvector/tsquery, 多种搜索模式
- **LISTEN/NOTIFY**: 实时事件通知
- **数组类型**: PostgreSQL 原生数组支持
- **COPY 命令**: 高速数据导入导�?- **SSL/TLS**: 安全连接支持

### 使用示例

```pascal
uses DeepBase.DB.PostgreSQL;

var
  Params: TPgConnectionParams;
  Driver: TPostgreSQLDriver;
begin
  Params := TPgConnectionParams.Default;
  Params.Host := 'localhost';
  Params.Database := 'mydb';
  Params.Username := 'postgres';
  Params.Password := 'secret';
  Params.SSLMode := sslRequire;
  
  Driver := TPostgreSQLDriver.Create(Params);
  try
    Driver.Connect;
    
    // JSONB 操作
    Driver.JsonbSet('users', 'metadata', '{profile,theme}', '"dark"', 1);
    
    // 全文搜索
    var Results := Driver.FullTextRank('articles', 'content', 'database optimization');
    
    // LISTEN/NOTIFY
    Driver.OnNotify := procedure(Sender: TObject; const Channel, Payload: string)
    begin
      WriteLn('Received: ', Channel, ' - ', Payload);
    end;
    Driver.Listen('orders');
    Driver.Notify('orders', '{"id": 123, "status": "paid"}');
    
  finally
    Driver.Free;
  end;
end;
```

### 全文搜索模式

```pascal
// 简单查�?TPgFullTextQuery.PlainTo('database optimization');

// 短语查询
TPgFullTextQuery.PhraseTo('quick brown fox');

// Web 搜索语法 (支持 AND, OR, -, "")
TPgFullTextQuery.WebSearch('database -mysql "high performance"');
```

## MySQL 驱动

### 特色功能

- **JSON 操作**: JSON_SET, JSON_REMOVE, JSON_SEARCH (MySQL 5.7+)
- **全文搜索**: MATCH AGAINST, 布尔模式
- **存储过程**: 调用和执行存储过�?- **批量插入**: 高效批量数据插入
- **表维�?*: OPTIMIZE, ANALYZE, REPAIR
- **复制状�?*: 主从复制状态查�?
### 使用示例

```pascal
uses DeepBase.DB.MySQL;

var
  Params: TMySQLConnectionParams;
  Driver: TMySQLDriver;
begin
  Params := TMySQLConnectionParams.Default;
  Params.Host := 'localhost';
  Params.Database := 'mydb';
  Params.Username := 'root';
  Params.Password := 'secret';
  Params.Charset := csUtf8mb4;
  
  Driver := TMySQLDriver.Create(Params);
  try
    Driver.Connect;
    
    // JSON 操作
    Driver.JsonSet('products', 'attributes', '$.color', '"red"', 1);
    Driver.JsonArrayAppend('products', 'tags', '$', '"new"', 1);
    
    // 全文搜索
    var Results := Driver.FullTextSearchWithRelevance(
      'articles', ['title', 'content'], 
      'database optimization',
      ftNaturalLanguage
    );
    
    // 布尔模式搜索
    var BoolResults := Driver.FullTextSearch(
      'articles', ['title', 'content'],
      '+mysql -oracle "high performance"',
      ftBooleanMode
    );
    
    // 存储过程
    Driver.ExecProc('sp_update_inventory', [ProductId, Quantity]);
    
    // 批量插入
    var BulkInsert := TMySQLBulkInsert.Create(Driver, 'logs', ['level', 'message', 'created_at']);
    try
      BulkInsert.BatchSize := 5000;
      for var I := 1 to 100000 do
        BulkInsert.Add(['INFO', 'Log message ' + IntToStr(I), Now]);
      BulkInsert.Flush;
    finally
      BulkInsert.Free;
    end;
    
  finally
    Driver.Free;
  end;
end;
```

### 全文搜索模式

| 模式 | 说明 |
|------|------|
| `ftNaturalLanguage` | 自然语言模式，按相关性排�?|
| `ftBooleanMode` | 布尔模式，支�?+, -, *, "", () |
| `ftQueryExpansion` | 查询扩展，自动添加相关词 |

## 连接参数

### PostgreSQL

| 参数 | 默认�?| 说明 |
|------|--------|------|
| Host | localhost | 服务器地址 |
| Port | 5432 | 端口 |
| SSLMode | sslPrefer | SSL 模式 |
| Pooled | True | 启用连接�?|
| PoolSize | 20 | 连接池大�?|

### MySQL

| 参数 | 默认�?| 说明 |
|------|--------|------|
| Host | localhost | 服务器地址 |
| Port | 3306 | 端口 |
| Charset | utf8mb4 | 字符�?|
| Compress | False | 启用压缩 |
| Pooled | True | 启用连接�?|
| PoolSize | 20 | 连接池大�?|

## 依赖

- FireDAC
- FireDAC.Phys.PG (PostgreSQL)
- FireDAC.Phys.MySQL (MySQL)

## 注意事项

1. 需要安装对应的数据库客户端�?2. PostgreSQL 需�?libpq.dll
3. MySQL 需�?libmysql.dll
4. 建议生产环境启用 SSL
