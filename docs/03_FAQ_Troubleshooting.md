# UniBase FAQ 与故障排查指南

> Version 1.0 | 最后更新: 2025-11-29

## 目录

1. [常见问题 (FAQ)](#1-常见问题-faq)
2. [故障排查](#2-故障排查)
3. [性能优化](#3-性能优化)
4. [迁移指南](#4-迁移指南)
5. [已知问题](#5-已知问题)

---

## 1. 常见问题 (FAQ)

### 1.1 初始化相关

#### Q: UniBase.Initialize 返回 False，如何排查？

**A:** 常见原因：

1. **数据库文件权限不足**
   ```delphi
   // 检查路径是否可写
   if not DirectoryExists(ExtractFilePath(DatabasePath)) then
     ForceDirectories(ExtractFilePath(DatabasePath));
   ```

2. **SQLite DLL 缺失**
   - 确保 `sqlite3.dll` 在应用目录或系统 PATH 中
   - 64位应用需要64位 DLL

3. **数据库文件损坏**
   ```delphi
   // 尝试恢复
   if FileExists('config.db.bak') then
   begin
     DeleteFile('config.db');
     RenameFile('config.db.bak', 'config.db');
   end;
   ```

#### Q: 可以同时使用多个 config.db 吗？

**A:** UniBase 使用单例模式，一次只能连接一个数据库。如需多数据库：

```delphi
// 方案1: 切换数据库
UniBase.Finalize;
UniBase.Initialize('another.db');

// 方案2: 使用独立连接
var Conn := TFDConnection.Create(nil);
Conn.DriverName := 'SQLite';
Conn.Params.Database := 'secondary.db';
```

### 1.2 配置相关

#### Q: 配置修改后为什么没有生效？

**A:** 检查以下几点：

1. **缓存问题** - 调用 `ClearCache` 强制刷新
   ```delphi
   UniBase.Config.ClearCache;
   ```

2. **事务未提交** - 如果在事务中操作
   ```delphi
   UniBase.Connection.Commit;
   ```

3. **键名大小写** - 配置键区分大小写
   ```delphi
   // 错误
   Config.GetConfig('App.Theme');
   // 正确
   Config.GetConfig('app.theme');
   ```

#### Q: 如何批量导入配置？

**A:**
```delphi
procedure ImportConfigs(const FileName: string);
var
  JSON: TJSONObject;
  Pair: TJSONPair;
begin
  JSON := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName)) as TJSONObject;
  try
    for Pair in JSON do
      UniBase.SetConfig(Pair.JsonString.Value, Pair.JsonValue.Value);
  finally
    JSON.Free;
  end;
end;
```

### 1.3 国际化相关

#### Q: T() 函数返回原文而不是翻译？

**A:** 检查以下几点：

1. **翻译条目是否存在**
   ```delphi
   // 检查翻译
   var Value := UniBase.i18n.Translate('Welcome');
   if Value = 'Welcome' then
     // 翻译不存在
   ```

2. **语言是否正确设置**
   ```delphi
   // 检查当前语言
   ShowMessage(UniBase.i18n.CurrentLanguage);
   ```

3. **翻译文件是否加载**
   ```delphi
   UniBase.i18n.LoadTranslations('lang_zh-CN.json');
   ```

#### Q: 如何实现动态语言切换？

**A:**
```delphi
procedure SwitchLanguage(const LangCode: string);
begin
  UniBase.i18n.SetLanguage(LangCode);
  
  // 方案1: 重新翻译当前窗体
  UniBase.i18n.TranslateForm(Self);
  
  // 方案2: 手动更新关键控件
  btnOK.Caption := T('OK');
  btnCancel.Caption := T('Cancel');
  
  // 方案3: 重启应用（最可靠）
  // Application.Terminate;
end;
```

### 1.4 日志相关

#### Q: 日志文件越来越大，如何限制？

**A:**
```delphi
// 设置日志轮转
UniBase.Log.MaxFileSize := 10 * 1024 * 1024;  // 10 MB
UniBase.Log.MaxFiles := 5;  // 保留最近5个文件

// 手动清理旧日志
UniBase.Log.Clear(Now - 30);  // 删除30天前的日志
```

#### Q: 如何记录到自定义位置？

**A:**
```delphi
UniBase.Log.LogFilePath := 'D:\Logs\MyApp';
```

### 1.5 插件相关

#### Q: 插件加载失败如何排查？

**A:**
1. **检查 BPL 依赖**
   ```
   tdump.exe -ee MyPlugin.bpl  // 查看依赖
   ```

2. **版本兼容性** - 插件需要与宿主使用相同 Delphi 版本编译

3. **接口 GUID 匹配**
   ```delphi
   // 确保 GUID 一致
   IUniBasePlugin = interface
     ['{A1B2C3D4-E5F6-...}']
   end;
   ```

4. **查看加载错误**
   ```delphi
   try
     PluginManager.LoadPlugin('MyPlugin.bpl');
   except
     on E: Exception do
       Log.Error('Plugin load failed: ' + E.Message);
   end;
   ```

---

## 2. 故障排查

### 2.1 数据库问题

#### 症状：数据库锁定 (Database is locked)

**原因:** 多进程/线程同时写入

**解决方案:**
```delphi
// 1. 启用 WAL 模式
UniBase.Connection.ExecSQL('PRAGMA journal_mode=WAL');

// 2. 设置超时
UniBase.Connection.ExecSQL('PRAGMA busy_timeout=5000');

// 3. 使用单一连接
// 确保应用只有一个 UniBase 实例
```

#### 症状：数据库损坏

**恢复步骤:**
```delphi
procedure RepairDatabase;
begin
  // 1. 备份当前数据库
  CopyFile('config.db', 'config.db.corrupt');
  
  // 2. 尝试导出
  var Conn := TFDConnection.Create(nil);
  Conn.DriverName := 'SQLite';
  Conn.Params.Database := 'config.db';
  try
    Conn.ExecSQL('.dump > backup.sql');  // SQLite CLI
  finally
    Conn.Free;
  end;
  
  // 3. 重建数据库
  DeleteFile('config.db');
  UniBase.Initialize('config.db');
  // 导入备份...
end;
```

### 2.2 内存问题

#### 症状：内存泄漏

**排查工具:**
```delphi
// 启用内存泄漏报告
ReportMemoryLeaksOnShutdown := True;

// 使用 FastMM 详细报告
{$DEFINE FullDebugMode}
```

**常见泄漏源:**
1. Query 未 Free
   ```delphi
   // 错误
   var Query := UniBase.Config.QuerySQL('...');
   // Query 未释放
   
   // 正确
   var Query := UniBase.Config.QuerySQL('...');
   try
     // 使用 Query
   finally
     Query.Free;
   end;
   ```

2. 事件处理器未解除
   ```delphi
   // FormDestroy 中清理
   UniBase.Config.OnConfigChanged := nil;
   ```

### 2.3 线程问题

#### 症状：随机崩溃、数据不一致

**检查点:**

1. **跨线程 UI 更新**
   ```delphi
   // 错误 - 直接在线程中更新 UI
   TTask.Run(procedure
   begin
     Label.Caption := T('Done');  // 危险！
   end);
   
   // 正确 - 使用 Synchronize
   TTask.Run(procedure
   begin
     TThread.Synchronize(nil, procedure
     begin
       Label.Caption := T('Done');
     end);
   end);
   ```

2. **共享数据访问**
   ```delphi
   // 使用 TMonitor 保护
   TMonitor.Enter(FData);
   try
     FData.Value := NewValue;
   finally
     TMonitor.Exit(FData);
   end;
   ```

### 2.4 编译问题

#### 症状：单元找不到

**解决方案:**
1. 检查搜索路径
   ```
   Project Options > Delphi Compiler > Search path
   ```

2. 检查包依赖
   ```
   Project Options > Packages > Runtime packages
   ```

#### 症状：接口不兼容

**解决方案:**
- 重新编译所有相关单元
- 清除 DCU 缓存
  ```
  del /s *.dcu
  ```

---

## 3. 性能优化

### 3.1 配置访问优化

```delphi
// 不推荐 - 频繁数据库访问
for I := 1 to 1000 do
  Value := Config.GetConfig('key' + IntToStr(I));

// 推荐 - 批量获取
var Configs := Config.GetAllConfigs('myCategory');
for I := 1 to 1000 do
  Value := Configs['key' + IntToStr(I)];
```

### 3.2 翻译优化

```delphi
// 不推荐 - 每次都翻译
procedure UpdateUI;
begin
  Label1.Caption := T('Name');
  Label2.Caption := T('Age');
  // ... 100+ 个控件
end;

// 推荐 - 只在语言切换时翻译
procedure OnLanguageChanged;
begin
  UniBase.i18n.TranslateForm(Self);
end;
```

### 3.3 日志优化

```delphi
// 不推荐 - 频繁日志
for I := 1 to 10000 do
begin
  Log.Debug('Processing item ' + IntToStr(I));
  ProcessItem(I);
end;

// 推荐 - 汇总日志
Log.Info('Processing 10000 items...');
for I := 1 to 10000 do
  ProcessItem(I);
Log.Info('Processing complete');

// 或使用条件日志
if Log.MinLevel <= llDebug then
  for I := 1 to 10000 do
    if I mod 1000 = 0 then
      Log.Debug('Progress: ' + IntToStr(I));
```

### 3.4 数据库优化

```delphi
// 批量操作使用事务
UniBase.Connection.StartTransaction;
try
  for I := 1 to 1000 do
    Config.SetConfig('key' + IntToStr(I), 'value');
  UniBase.Connection.Commit;
except
  UniBase.Connection.Rollback;
  raise;
end;

// 启用 WAL 模式提升并发
UniBase.Connection.ExecSQL('PRAGMA journal_mode=WAL');
```

---

## 4. 迁移指南

### 4.1 从 INI 文件迁移

```delphi
procedure MigrateFromINI(const IniFile: string);
var
  Ini: TIniFile;
  Sections: TStringList;
  Keys: TStringList;
  Section, Key, Value: string;
begin
  Ini := TIniFile.Create(IniFile);
  Sections := TStringList.Create;
  Keys := TStringList.Create;
  try
    Ini.ReadSections(Sections);
    for Section in Sections do
    begin
      Keys.Clear;
      Ini.ReadSection(Section, Keys);
      for Key in Keys do
      begin
        Value := Ini.ReadString(Section, Key, '');
        UniBase.SetConfig(Section + '.' + Key, Value);
      end;
    end;
  finally
    Keys.Free;
    Sections.Free;
    Ini.Free;
  end;
end;
```

### 4.2 从 Registry 迁移

```delphi
procedure MigrateFromRegistry(const RootKey: string);
var
  Reg: TRegistry;
  Keys: TStringList;
  Key: string;
begin
  Reg := TRegistry.Create;
  Keys := TStringList.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly(RootKey) then
    begin
      Reg.GetValueNames(Keys);
      for Key in Keys do
        UniBase.SetConfig('registry.' + Key, Reg.ReadString(Key));
    end;
  finally
    Keys.Free;
    Reg.Free;
  end;
end;
```

### 4.3 版本升级迁移

```delphi
procedure MigrateConfig;
var
  Version: Integer;
begin
  Version := Config.GetConfigInt('system.version', 0);
  
  case Version of
    0: begin
      // v0 -> v1: 重命名配置键
      if Config.ConfigExists('oldKey') then
      begin
        Config.SetConfig('newKey', Config.GetConfig('oldKey'));
        Config.DeleteConfig('oldKey');
      end;
      Config.SetConfigInt('system.version', 1);
    end;
    
    1: begin
      // v1 -> v2: 添加新配置
      if not Config.ConfigExists('feature.enabled') then
        Config.SetConfigBool('feature.enabled', True);
      Config.SetConfigInt('system.version', 2);
    end;
  end;
end;
```

---

## 5. 已知问题

### 5.1 当前版本限制

| 问题 | 状态 | 解决方案 |
|------|------|---------|
| FMX 支持有限 | 计划中 | 使用 VCL 或等待更新 |
| 无远程数据库支持 | 设计限制 | 使用本地 SQLite |
| 加密配置不支持搜索 | 设计限制 | 对敏感数据使用唯一键 |

### 5.2 Delphi 版本兼容性

| Delphi 版本 | 状态 | 备注 |
|-------------|------|------|
| 12.2 Athens | ✅ 完全支持 | 推荐版本 |
| 11.x Alexandria | ✅ 支持 | |
| 10.4 Sydney | ✅ 支持 | |
| 10.3 Rio | ⚠️ 部分支持 | 缺少部分泛型功能 |
| 10.2 及更早 | ❌ 不支持 | |

### 5.3 报告问题

发现新问题请提供：
1. Delphi 版本
2. UniBase 版本
3. 最小复现代码
4. 错误信息和堆栈跟踪
5. config.db 结构（如适用）

---

## 附录：诊断代码片段

### 系统信息收集

```delphi
function GetDiagnosticInfo: string;
begin
  Result := Format(
    'UniBase Version: %s' + sLineBreak +
    'Database: %s' + sLineBreak +
    'Initialized: %s' + sLineBreak +
    'Language: %s' + sLineBreak +
    'Config Count: %d' + sLineBreak +
    'Memory Usage: %d MB',
    [
      UniBase.Version,
      UniBase.DatabasePath,
      BoolToStr(UniBase.Initialized, True),
      UniBase.i18n.CurrentLanguage,
      UniBase.Config.GetAllConfigs.Count,
      GetCurrentMemoryUsage div (1024 * 1024)
    ]);
end;
```

### 健康检查

```delphi
function HealthCheck: Boolean;
begin
  Result := True;
  
  // 检查初始化
  if not UniBase.Initialized then
  begin
    Log.Error('UniBase not initialized');
    Exit(False);
  end;
  
  // 检查数据库连接
  try
    UniBase.Connection.ExecSQL('SELECT 1');
  except
    on E: Exception do
    begin
      Log.Error('Database check failed', E);
      Exit(False);
    end;
  end;
  
  // 检查配置读写
  try
    UniBase.SetConfig('_health_check', DateTimeToStr(Now));
    UniBase.Config.DeleteConfig('_health_check');
  except
    on E: Exception do
    begin
      Log.Error('Config check failed', E);
      Exit(False);
    end;
  end;
  
  Log.Info('Health check passed');
end;
```
