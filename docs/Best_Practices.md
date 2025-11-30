# UniBase 最佳实践指南

> 版本: 1.0 | 最后更新: 2025-11-29

本指南汇集了使用 UniBase 框架进行开发的推荐做法和模式，帮助开发者编写高质量、可维护的代码。

---

## 目录

1. [配置管理最佳实践](#配置管理最佳实践)
2. [国际化实现最佳实践](#国际化实现最佳实践)
3. [日志记录策略](#日志记录策略)
4. [异常处理模式](#异常处理模式)
5. [性能优化技巧](#性能优化技巧)
6. [数据库使用指南](#数据库使用指南)
7. [插件开发规范](#插件开发规范)
8. [MVVM 架构指南](#mvvm-架构指南)
9. [安全编码实践](#安全编码实践)
10. [测试策略](#测试策略)

---

## 配置管理最佳实践

### 1. 使用常量定义配置键

**推荐：** 使用 `UniBase.Consts` 中的常量

```pascal
uses
  UniBase.Consts;

// Good - 使用预定义常量
Config.SetConfig(SConfigKeyLanguage, 'zh-CN');
Config.SetConfig(SConfigKeyTheme, 'dark');

// Bad - 硬编码字符串
Config.SetConfig('language', 'zh-CN');  // 容易拼写错误
```

**自定义配置键常量：**

```pascal
const
  // 应用程序专属配置键
  SConfigKeyServerUrl = 'app.server.url';
  SConfigKeyMaxRetries = 'app.network.maxRetries';
  SConfigKeyCacheTimeout = 'app.cache.timeout';
```

### 2. 分类组织配置

**推荐：** 使用分层命名和分类

```pascal
// Good - 分层命名，清晰的分类
Config.SetConfig('database.connection.host', 'localhost', 'Database');
Config.SetConfig('database.connection.port', '5432', 'Database');
Config.SetConfig('database.pool.maxSize', '10', 'Database');

Config.SetConfig('ui.theme.name', 'dark', 'UI');
Config.SetConfig('ui.font.size', '12', 'UI');

// Bad - 扁平命名，无分类
Config.SetConfig('dbHost', 'localhost');
Config.SetConfig('themeName', 'dark');
```

### 3. 敏感配置加密存储

**推荐：** 使用加密配置存储敏感信息

```pascal
// Good - 敏感信息加密存储
Config.SetConfigEncrypted('database.password', 'secret123');
Config.SetConfigEncrypted('api.key', 'sk-xxxxxxxx');

// 读取时自动解密
Password := Config.GetConfigEncrypted('database.password', '');

// Bad - 明文存储敏感信息
Config.SetConfig('database.password', 'secret123');
```

### 4. 提供合理的默认值

**推荐：** 总是提供默认值，避免空值异常

```pascal
// Good - 提供默认值
MaxRetries := Config.GetConfigInt('network.maxRetries', 3);
Timeout := Config.GetConfigInt('network.timeout', 30000);
Theme := Config.GetConfig('ui.theme', 'light');

// Bad - 不提供默认值，可能返回空
Theme := Config.GetConfig('ui.theme');  // 可能为空
```

### 5. 配置变更监听

**推荐：** 监听配置变更，实时响应

```pascal
procedure TMainForm.FormCreate(Sender: TObject);
begin
  UniBase.Config.OnConfigChanged := HandleConfigChanged;
end;

procedure TMainForm.HandleConfigChanged(const Key, OldValue, NewValue: string);
begin
  if Key = 'ui.theme' then
    ApplyTheme(NewValue)
  else if Key = 'ui.language' then
    ReloadLanguage(NewValue);
end;
```

### 6. 批量配置操作

**推荐：** 批量操作提高性能

```pascal
// Good - 批量写入
Config.BeginUpdate;
try
  Config.SetConfig('window.left', IntToStr(Left));
  Config.SetConfig('window.top', IntToStr(Top));
  Config.SetConfig('window.width', IntToStr(Width));
  Config.SetConfig('window.height', IntToStr(Height));
finally
  Config.EndUpdate;  // 一次性提交
end;

// Bad - 逐个写入，多次 I/O
Config.SetConfig('window.left', IntToStr(Left));
Config.SetConfig('window.top', IntToStr(Top));
// 每次都触发保存
```

---

## 国际化实现最佳实践

### 1. 统一使用翻译函数

**推荐：** 所有用户可见文本都使用 `_()` 函数

```pascal
// Good - 使用翻译函数
ShowMessage(_('File saved successfully'));
Button1.Caption := _('Save');
Label1.Caption := Format(_('Welcome, %s'), [UserName]);

// Bad - 硬编码文本
ShowMessage('File saved successfully');
Button1.Caption := 'Save';
```

### 2. 翻译键规范命名

**推荐：** 使用 `模块.功能.描述` 格式

```pascal
// Good - 规范的键名
_('common.button.ok')
_('common.button.cancel')
_('main.menu.file')
_('main.menu.file.open')
_('settings.general.language')
_('error.database.connectionFailed')

// Bad - 不规范的键名
_('OK')  // 太短，容易冲突
_('The file could not be opened')  // 用原文做键名
```

### 3. 参数化翻译

**推荐：** 使用参数化而非字符串拼接

```pascal
// Good - 参数化翻译
Msg := Format(_('Found %d files in %s'), [Count, FolderName]);
Msg := Format(_('User %s logged in at %s'), [UserName, TimeStr]);

// Bad - 字符串拼接（不同语言语序可能不同）
Msg := _('Found ') + IntToStr(Count) + _(' files');
```

### 4. 使用 I18n 控件

**推荐：** 使用自动翻译控件

```pascal
// Good - 使用 I18n 控件，自动响应语言切换
uses UniBase.VCL.I18nControls;

var
  LblTitle: TI18nLabel;
  BtnSave: TI18nButton;
begin
  LblTitle := TI18nLabel.Create(Self);
  LblTitle.TranslationKey := 'main.title';  // 自动翻译
  
  BtnSave := TI18nButton.Create(Self);
  BtnSave.TranslationKey := 'common.button.save';
end;
```

### 5. 语言切换处理

**推荐：** 集中处理语言切换

```pascal
procedure TMainForm.ChangeLanguage(const LangCode: string);
begin
  // 设置语言
  UniBase.I18n.CurrentLanguage := LangCode;
  
  // 保存用户偏好
  UniBase.Config.SetConfig(SConfigKeyLanguage, LangCode);
  
  // 刷新动态生成的 UI
  RefreshDynamicUI;
  
  // 通知其他模块
  EventBus.Publish<TLanguageChangedEvent>(
    TLanguageChangedEvent.Create(LangCode));
end;
```

### 6. 复数形式处理

**推荐：** 考虑复数形式

```pascal
// Good - 处理复数
function GetItemCountText(Count: Integer): string;
begin
  if Count = 0 then
    Result := _('No items')
  else if Count = 1 then
    Result := _('1 item')
  else
    Result := Format(_('%d items'), [Count]);
end;

// 或使用复数翻译键
_('item.count.zero')   // "No items"
_('item.count.one')    // "1 item"  
_('item.count.other')  // "%d items"
```

---

## 日志记录策略

### 1. 选择正确的日志级别

```pascal
// Debug - 开发调试信息，生产环境关闭
Log.Debug('Processing item %d of %d', [I, Total]);
Log.Debug('Cache hit for key: %s', [Key]);

// Info - 重要的业务流程节点
Log.Info('User %s logged in', [UserName]);
Log.Info('Order #%s created successfully', [OrderId]);

// Warn - 异常但可恢复的情况
Log.Warn('Connection timeout, retrying... (attempt %d)', [Attempt]);
Log.Warn('Configuration key not found, using default: %s', [Key]);

// Error - 错误但程序可继续运行
Log.Error('Failed to save file: %s', [FileName]);
Log.Error('Database query failed: %s', [E.Message]);

// Fatal - 严重错误，程序可能需要终止
Log.Fatal('Database connection lost, shutting down');
Log.Fatal('Critical configuration missing');
```

### 2. 结构化日志内容

**推荐：** 日志包含足够上下文

```pascal
// Good - 包含上下文信息
Log.Info('[OrderService] Order created - ID: %s, User: %s, Amount: %.2f',
  [OrderId, UserId, Amount]);
Log.Error('[FileManager] Save failed - Path: %s, Size: %d, Error: %s',
  [FilePath, FileSize, E.Message]);

// Bad - 信息不足
Log.Info('Order created');
Log.Error('Save failed');
```

### 3. 使用 Source 标记

**推荐：** 使用 Source 参数标记日志来源

```pascal
// 定义模块常量
const
  LOG_SOURCE_ORDER = 'OrderService';
  LOG_SOURCE_USER = 'UserService';
  LOG_SOURCE_FILE = 'FileManager';

// 使用 Source 参数
Log.Info('Order created: %s', [OrderId], LOG_SOURCE_ORDER);
Log.Error('Login failed for user: %s', [UserName], LOG_SOURCE_USER);
```

### 4. 异常日志记录

**推荐：** 记录完整异常信息

```pascal
procedure TOrderService.ProcessOrder(const OrderId: string);
begin
  try
    DoProcessOrder(OrderId);
  except
    on E: Exception do
    begin
      // Good - 记录异常类型和堆栈
      Log.Error('[OrderService] ProcessOrder failed - OrderId: %s, ' +
        'Exception: %s, Message: %s',
        [OrderId, E.ClassName, E.Message], LOG_SOURCE_ORDER);
      raise;  // 重新抛出或处理
    end;
  end;
end;
```

### 5. 性能敏感代码的日志

**推荐：** 高频代码使用条件日志

```pascal
// Good - 检查日志级别后再格式化
if Log.IsDebugEnabled then
  Log.Debug('Processing batch: %s', [BuildBatchInfoString(Batch)]);

// Bad - 无论是否记录都执行格式化
Log.Debug('Processing batch: %s', [BuildBatchInfoString(Batch)]);
// BuildBatchInfoString 可能很耗时
```

### 6. 日志文件管理

**推荐：** 配置日志轮转和清理

```pascal
// 在应用启动时配置
UniBase.Logger.MaxLogFileSizeMB := 10;  // 单文件最大 10MB
UniBase.Logger.LogLevel := llInfo;      // 生产环境用 Info

// 定期清理旧日志（可在定时任务中执行）
procedure CleanOldLogs;
var
  Files: TStringDynArray;
  F: string;
  FileAge: TDateTime;
begin
  Files := TDirectory.GetFiles(LogPath, '*.log');
  for F in Files do
  begin
    FileAge := TFile.GetLastWriteTime(F);
    if DaysBetween(Now, FileAge) > 30 then
      TFile.Delete(F);
  end;
end;
```

---

## 异常处理模式

### 1. 分层异常处理

**推荐：** 在适当的层级处理异常

```pascal
// 数据访问层 - 转换为领域异常
function TUserRepository.GetById(const Id: string): TUser;
begin
  try
    Result := DoQueryUser(Id);
  except
    on E: EDatabaseError do
      raise EUserRepositoryException.Create('Failed to load user: ' + E.Message);
  end;
end;

// 服务层 - 处理业务逻辑异常
function TUserService.Login(const Username, Password: string): TUser;
begin
  try
    Result := FRepository.FindByUsername(Username);
    if not VerifyPassword(Result, Password) then
      raise EAuthenticationException.Create('Invalid credentials');
  except
    on E: EUserRepositoryException do
    begin
      Log.Error('Login failed: %s', [E.Message]);
      raise ELoginException.Create('Login service unavailable');
    end;
  end;
end;

// UI 层 - 显示用户友好消息
procedure TLoginForm.BtnLoginClick(Sender: TObject);
begin
  try
    FUser := FUserService.Login(EdtUsername.Text, EdtPassword.Text);
    ModalResult := mrOK;
  except
    on E: EAuthenticationException do
      ShowMessage(_('Invalid username or password'));
    on E: ELoginException do
      ShowMessage(_('Service temporarily unavailable, please try later'));
    on E: Exception do
    begin
      Log.Error('Unexpected login error: %s', [E.Message]);
      ShowMessage(_('An unexpected error occurred'));
    end;
  end;
end;
```

### 2. 自定义异常类

**推荐：** 定义有意义的异常类

```pascal
type
  // 基础应用异常
  EAppException = class(Exception)
  private
    FErrorCode: Integer;
  public
    constructor Create(const Msg: string; AErrorCode: Integer = 0);
    property ErrorCode: Integer read FErrorCode;
  end;

  // 领域异常
  EValidationException = class(EAppException);
  EBusinessRuleException = class(EAppException);
  ENotFoundException = class(EAppException);
  
  // 基础设施异常
  EDatabaseException = class(EAppException);
  ENetworkException = class(EAppException);
  EConfigurationException = class(EAppException);
```

### 3. 资源清理模式

**推荐：** 使用 try-finally 确保资源释放

```pascal
// Good - 确保资源释放
procedure ProcessFile(const FileName: string);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead);
  try
    DoProcessStream(Stream);
  finally
    Stream.Free;
  end;
end;

// Better - 使用接口自动释放
procedure ProcessFile(const FileName: string);
var
  Stream: IStream;
begin
  Stream := TStreamWrapper.Create(FileName);
  DoProcessStream(Stream);
  // 自动释放
end;
```

### 4. 不要吞掉异常

**推荐：** 处理或重新抛出，不要静默忽略

```pascal
// Bad - 吞掉异常
try
  DoSomething;
except
  // 什么都不做
end;

// Bad - 只记录不处理
try
  DoSomething;
except
  on E: Exception do
    Log.Error(E.Message);  // 然后呢？
end;

// Good - 记录并重新抛出
try
  DoSomething;
except
  on E: Exception do
  begin
    Log.Error('Operation failed: %s', [E.Message]);
    raise;  // 让上层处理
  end;
end;

// Good - 处理并提供降级方案
try
  Data := LoadFromCache(Key);
except
  on E: ECacheException do
  begin
    Log.Warn('Cache miss, loading from database: %s', [E.Message]);
    Data := LoadFromDatabase(Key);  // 降级方案
  end;
end;
```

### 5. 异常信息国际化

**推荐：** 用户可见的异常消息要国际化

```pascal
type
  EUserException = class(Exception)
  public
    constructor Create(const MsgKey: string); overload;
    constructor CreateFmt(const MsgKey: string; const Args: array of const); overload;
  end;

constructor EUserException.Create(const MsgKey: string);
begin
  inherited Create(_(MsgKey));
end;

// 使用
raise EUserException.Create('error.file.notFound');
raise EUserException.CreateFmt('error.file.accessDenied', [FileName]);
```

---

## 性能优化技巧

### 1. 使用连接池

**推荐：** 数据库连接使用连接池

```pascal
// Good - 使用连接池
var
  Conn: TFDConnection;
begin
  Conn := ConnectionPool.Acquire;
  try
    // 使用连接
    Query.Connection := Conn;
    Query.Open;
    // ...
  finally
    ConnectionPool.Release(Conn);
  end;
end;

// Bad - 每次创建新连接
var
  Conn: TFDConnection;
begin
  Conn := TFDConnection.Create(nil);
  try
    Conn.ConnectionDefName := 'MyDB';
    Conn.Open;
    // ...
  finally
    Conn.Free;
  end;
end;
```

### 2. 配置缓存

**推荐：** 频繁读取的配置使用缓存

```pascal
// UniBase.Config 内置缓存，直接使用即可
// 第一次读取从数据库，后续从缓存

// 高频访问场景，可以在本地缓存
type
  TAppSettings = class
  private
    FMaxRetries: Integer;
    FTimeout: Integer;
    FLoaded: Boolean;
    procedure EnsureLoaded;
  public
    property MaxRetries: Integer read GetMaxRetries;
    property Timeout: Integer read GetTimeout;
    procedure Reload;
  end;

procedure TAppSettings.EnsureLoaded;
begin
  if not FLoaded then
  begin
    FMaxRetries := Config.GetConfigInt('network.maxRetries', 3);
    FTimeout := Config.GetConfigInt('network.timeout', 30000);
    FLoaded := True;
  end;
end;
```

### 3. 延迟加载

**推荐：** 延迟加载非必要数据

```pascal
type
  TOrder = class
  private
    FId: string;
    FItems: TObjectList<TOrderItem>;
    FItemsLoaded: Boolean;
    function GetItems: TObjectList<TOrderItem>;
  public
    property Items: TObjectList<TOrderItem> read GetItems;
  end;

function TOrder.GetItems: TObjectList<TOrderItem>;
begin
  if not FItemsLoaded then
  begin
    FItems := FRepository.LoadOrderItems(FId);
    FItemsLoaded := True;
  end;
  Result := FItems;
end;
```

### 4. 批量操作

**推荐：** 批量处理而非逐条处理

```pascal
// Good - 批量插入
procedure InsertOrders(const Orders: TArray<TOrder>);
begin
  Connection.StartTransaction;
  try
    Query.SQL.Text := 'INSERT INTO Orders (Id, CustomerId, Total) VALUES (:Id, :CustomerId, :Total)';
    for Order in Orders do
    begin
      Query.ParamByName('Id').AsString := Order.Id;
      Query.ParamByName('CustomerId').AsString := Order.CustomerId;
      Query.ParamByName('Total').AsFloat := Order.Total;
      Query.ExecSQL;
    end;
    Connection.Commit;
  except
    Connection.Rollback;
    raise;
  end;
end;

// Bad - 逐条插入，每次提交
for Order in Orders do
  InsertOrder(Order);  // 每次都开启和提交事务
```

### 5. 字符串构建优化

**推荐：** 大量字符串拼接使用 TStringBuilder

```pascal
// Good - 使用 TStringBuilder
function BuildReport(const Items: TArray<TItem>): string;
var
  SB: TStringBuilder;
  Item: TItem;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('Report');
    SB.AppendLine('======');
    for Item in Items do
      SB.AppendFormat('%s: %.2f', [Item.Name, Item.Value]).AppendLine;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

// Bad - 字符串拼接
function BuildReport(const Items: TArray<TItem>): string;
var
  Item: TItem;
begin
  Result := 'Report' + sLineBreak + '======' + sLineBreak;
  for Item in Items do
    Result := Result + Item.Name + ': ' + FloatToStr(Item.Value) + sLineBreak;
end;
```

### 6. 使用性能分析

**推荐：** 使用 Benchmark 工具定位瓶颈

```pascal
uses UniBase.Benchmark;

procedure OptimizeProcess;
var
  Timer: IScopedTimer;
begin
  Timer := TScopedTimer.Start('ProcessData');
  
  // ... 执行操作
  
  // Timer 销毁时自动记录耗时
end;

// 或者使用 MeasureTime
var
  ElapsedMs: Double;
begin
  ElapsedMs := MeasureTime(procedure
  begin
    DoSomething;
  end);
  
  if ElapsedMs > 1000 then
    Log.Warn('Operation took too long: %.2f ms', [ElapsedMs]);
end;
```

---

## 数据库使用指南

### 1. 使用参数化查询

**推荐：** 总是使用参数化查询，防止 SQL 注入

```pascal
// Good - 参数化查询
Query.SQL.Text := 'SELECT * FROM Users WHERE Username = :Username AND Status = :Status';
Query.ParamByName('Username').AsString := Username;
Query.ParamByName('Status').AsInteger := 1;
Query.Open;

// Bad - 字符串拼接（SQL 注入风险）
Query.SQL.Text := 'SELECT * FROM Users WHERE Username = ''' + Username + '''';
Query.Open;
```

### 2. 事务管理

**推荐：** 相关操作放在同一事务中

```pascal
procedure TransferFunds(const FromAccount, ToAccount: string; Amount: Currency);
begin
  Connection.StartTransaction;
  try
    // 扣款
    Query.SQL.Text := 'UPDATE Accounts SET Balance = Balance - :Amount WHERE Id = :Id';
    Query.ParamByName('Amount').AsCurrency := Amount;
    Query.ParamByName('Id').AsString := FromAccount;
    Query.ExecSQL;
    
    // 入账
    Query.ParamByName('Id').AsString := ToAccount;
    Query.SQL.Text := 'UPDATE Accounts SET Balance = Balance + :Amount WHERE Id = :Id';
    Query.ExecSQL;
    
    Connection.Commit;
  except
    Connection.Rollback;
    raise;
  end;
end;
```

### 3. 使用 ORM

**推荐：** 简单 CRUD 使用 ORM

```pascal
uses UniBase.ORM;

// 定义实体
type
  [Table('Users')]
  TUser = class
  private
    [PrimaryKey, Column('Id')]
    FId: string;
    [Column('Username')]
    FUsername: string;
    [Column('Email')]
    FEmail: string;
  public
    property Id: string read FId write FId;
    property Username: string read FUsername write FUsername;
    property Email: string read FEmail write FEmail;
  end;

// 使用 ORM
var
  Context: TDbContext;
  User: TUser;
begin
  Context := TDbContext.Create(Connection);
  try
    // 查询
    User := Context.Find<TUser>('user-001');
    
    // 更新
    User.Email := 'new@email.com';
    Context.Update<TUser>(User);
    
    // 复杂查询
    Users := Context.Query<TUser>
      .Where('Status = :Status', [1])
      .OrderBy('Username')
      .ToList;
  finally
    Context.Free;
  end;
end;
```

### 4. 索引优化

**推荐：** 为常用查询字段创建索引

```pascal
// 在实体定义中声明索引
type
  [Table('Orders')]
  [Index('IX_Orders_CustomerId', 'CustomerId')]
  [Index('IX_Orders_CreatedAt', 'CreatedAt')]
  TOrder = class
    // ...
  end;

// 或手动创建
Context.ExecuteSQL(
  'CREATE INDEX IF NOT EXISTS IX_Orders_Status ON Orders(Status)');
```

### 5. 分页查询

**推荐：** 大数据集使用分页

```pascal
function GetOrders(PageIndex, PageSize: Integer): TArray<TOrder>;
begin
  Result := Context.Query<TOrder>
    .OrderBy('CreatedAt DESC')
    .Skip(PageIndex * PageSize)
    .Take(PageSize)
    .ToArray;
end;

// 获取总数
TotalCount := Context.Query<TOrder>.Count;
TotalPages := (TotalCount + PageSize - 1) div PageSize;
```

---

## 插件开发规范

### 1. 实现必要接口

```pascal
type
  TMyPlugin = class(TUniBasePluginBase, IUniBasePlugin)
  public
    function GetInfo: TPluginInfo; override;
    function Initialize(const Context: IPluginContext): Boolean; override;
    procedure Finalize; override;
  end;

function TMyPlugin.GetInfo: TPluginInfo;
begin
  Result.Id := 'com.mycompany.myplugin';
  Result.Name := 'My Plugin';
  Result.Version := '1.0.0';
  Result.Author := 'My Company';
  Result.Description := 'Plugin description';
  Result.MinHostVersion := '1.0.0';
end;
```

### 2. 正确处理生命周期

```pascal
function TMyPlugin.Initialize(const Context: IPluginContext): Boolean;
begin
  FContext := Context;
  FLogger := Context.GetService<ILogger>;
  
  // 初始化资源
  FMyResource := TMyResource.Create;
  
  FLogger.Info('Plugin initialized');
  Result := True;
end;

procedure TMyPlugin.Finalize;
begin
  // 清理资源
  FreeAndNil(FMyResource);
  FLogger.Info('Plugin finalized');
end;
```

### 3. 使用宿主服务

```pascal
procedure TMyPlugin.DoSomething;
var
  Config: IConfigService;
  Logger: ILogger;
begin
  // 通过 Context 获取宿主服务
  Config := FContext.GetService<IConfigService>;
  Logger := FContext.GetService<ILogger>;
  
  // 使用服务
  Value := Config.GetConfig('my.setting', 'default');
  Logger.Info('Doing something with: %s', [Value]);
end;
```

### 4. 版本兼容性

```pascal
function TMyPlugin.GetInfo: TPluginInfo;
begin
  // ...
  Result.MinHostVersion := '1.0.0';  // 最低宿主版本
  Result.MaxHostVersion := '2.0.0';  // 最高宿主版本（可选）
end;

function TMyPlugin.Initialize(const Context: IPluginContext): Boolean;
begin
  // 检查宿主版本
  if not Context.IsHostVersionCompatible('1.5.0') then
  begin
    Context.GetService<ILogger>.Error('Host version too old');
    Exit(False);
  end;
  // ...
end;
```

---

## MVVM 架构指南

### 1. ViewModel 设计

```pascal
type
  TLoginViewModel = class(TViewModelBase)
  private
    FUsername: string;
    FPassword: string;
    FLoginCommand: ICommand;
    FIsLoading: Boolean;
    procedure SetUsername(const Value: string);
    procedure SetPassword(const Value: string);
  protected
    procedure SetupValidation; override;
  public
    constructor Create;
    property Username: string read FUsername write SetUsername;
    property Password: string read FPassword write SetPassword;
    property LoginCommand: ICommand read FLoginCommand;
    property IsLoading: Boolean read FIsLoading;
  end;

constructor TLoginViewModel.Create;
begin
  inherited;
  FLoginCommand := TAsyncCommand.Create(
    procedure(CancelToken: ICancellationToken)
    begin
      DoLogin;
    end,
    function: Boolean  // CanExecute
    begin
      Result := (FUsername <> '') and (FPassword <> '') and not FIsLoading;
    end
  );
end;
```

### 2. 验证规则

```pascal
procedure TLoginViewModel.SetupValidation;
begin
  AddValidation('Username', TValidationRules.Required(_('Username is required')));
  AddValidation('Username', TValidationRules.MinLength(3, _('Username too short')));
  AddValidation('Password', TValidationRules.Required(_('Password is required')));
  AddValidation('Password', TValidationRules.MinLength(6, _('Password too short')));
end;

procedure TLoginViewModel.SetUsername(const Value: string);
begin
  if FUsername <> Value then
  begin
    FUsername := Value;
    NotifyPropertyChanged('Username');
    ValidateProperty('Username');
    (FLoginCommand as TCommandBase).RaiseCanExecuteChanged;
  end;
end;
```

### 3. View 绑定

```pascal
type
  TLoginForm = class(TMVVMForm<TLoginViewModel>)
  private
    EdtUsername: TBindableEdit;
    EdtPassword: TBindableEdit;
    BtnLogin: TCommandButton;
    LblError: TValidationErrorLabel;
  protected
    procedure SetupBindings; override;
  end;

procedure TLoginForm.SetupBindings;
begin
  inherited;
  
  // 绑定输入框
  BindingManager.Bind(EdtUsername, 'Text', ViewModel, 'Username', bmTwoWay);
  BindingManager.Bind(EdtPassword, 'Text', ViewModel, 'Password', bmTwoWay);
  
  // 绑定命令
  BtnLogin.Command := ViewModel.LoginCommand;
  
  // 绑定验证错误
  LblError.BindToViewModel(ViewModel);
end;
```

### 4. 命令模式

```pascal
// 同步命令
FSaveCommand := TRelayCommand.Create(
  procedure
  begin
    DoSave;
  end,
  function: Boolean
  begin
    Result := HasChanges and IsValid;
  end
);

// 异步命令
FSearchCommand := TAsyncCommand.Create(
  procedure(CancelToken: ICancellationToken)
  begin
    Results := SearchService.Search(SearchText, CancelToken);
    TThread.Queue(nil, procedure
    begin
      UpdateResults(Results);
    end);
  end
);

// 取消上一次搜索
if FSearchCommand.IsExecuting then
  FSearchCommand.Cancel;
FSearchCommand.Execute;
```

---

## 安全编码实践

### 1. 敏感数据处理

```pascal
// 使用安全字符串（使用后清零）
var
  Password: TSecureString;
begin
  Password := TSecureString.Create(EdtPassword.Text);
  try
    AuthService.Login(Username, Password);
  finally
    Password.Free;  // 自动清零内存
  end;
end;

// 加密存储
Config.SetConfigEncrypted('api.key', ApiKey);
Config.SetConfigEncrypted('database.password', DbPassword);
```

### 2. 输入验证

```pascal
// 验证所有外部输入
function ValidateUsername(const Value: string): Boolean;
begin
  // 长度检查
  if (Length(Value) < 3) or (Length(Value) > 50) then
    Exit(False);
    
  // 字符检查
  if not TRegEx.IsMatch(Value, '^[a-zA-Z0-9_]+$') then
    Exit(False);
    
  Result := True;
end;

// 路径遍历防护
function SafeJoinPath(const BasePath, SubPath: string): string;
begin
  Result := TPath.Combine(BasePath, SubPath);
  
  // 确保结果仍在基础路径下
  if not Result.StartsWith(BasePath) then
    raise ESecurityException.Create('Invalid path');
end;
```

### 3. 错误信息安全

```pascal
// Good - 不泄露内部信息
try
  DoLogin;
except
  on E: EAuthException do
    ShowMessage(_('Invalid credentials'));  // 统一的错误消息
  on E: Exception do
  begin
    Log.Error('Login error: %s', [E.Message]);  // 详细记录
    ShowMessage(_('Login failed'));  // 简单提示
  end;
end;

// Bad - 泄露内部信息
except
  on E: Exception do
    ShowMessage('Error: ' + E.Message);  // 可能暴露数据库结构等
end;
```

### 4. 权限检查

```pascal
procedure TOrderService.DeleteOrder(const OrderId: string);
begin
  // 检查权限
  if not FSecurityContext.HasPermission('order.delete') then
    raise EAccessDeniedException.Create('No permission to delete orders');
    
  // 检查数据所有权
  Order := FRepository.GetById(OrderId);
  if Order.CreatedBy <> FSecurityContext.CurrentUserId then
    if not FSecurityContext.HasPermission('order.delete.any') then
      raise EAccessDeniedException.Create('Cannot delete others'' orders');
      
  FRepository.Delete(OrderId);
end;
```

---

## 测试策略

### 1. 单元测试

```pascal
type
  [TestFixture]
  TConfigTest = class
  private
    FConfig: TUniBaseConfig;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure TestSetAndGetConfig;
    
    [Test]
    procedure TestDefaultValue;
    
    [Test]
    [TestCase('Empty', '')]
    [TestCase('Spaces', '   ')]
    procedure TestEmptyKey(const Key: string);
  end;

procedure TConfigTest.TestSetAndGetConfig;
begin
  FConfig.SetConfig('test.key', 'test.value');
  Assert.AreEqual('test.value', FConfig.GetConfig('test.key'));
end;

procedure TConfigTest.TestDefaultValue;
begin
  Assert.AreEqual('default', FConfig.GetConfig('nonexistent', 'default'));
end;
```

### 2. 模拟对象

```pascal
type
  TMockUserRepository = class(TInterfacedObject, IUserRepository)
  private
    FUsers: TDictionary<string, TUser>;
  public
    constructor Create;
    destructor Destroy; override;
    function GetById(const Id: string): TUser;
    procedure Add(const User: TUser);
  end;

procedure TUserServiceTest.TestGetUser;
var
  MockRepo: TMockUserRepository;
  Service: TUserService;
  User: TUser;
begin
  MockRepo := TMockUserRepository.Create;
  MockRepo.Add(TUser.Create('1', 'John'));
  
  Service := TUserService.Create(MockRepo);
  try
    User := Service.GetById('1');
    Assert.AreEqual('John', User.Name);
  finally
    Service.Free;
  end;
end;
```

### 3. 集成测试

```pascal
type
  [TestFixture]
  TOrderIntegrationTest = class
  private
    FConnection: TFDConnection;
    FContext: TDbContext;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;
    
    [Test]
    procedure TestCreateAndQueryOrder;
  end;

procedure TOrderIntegrationTest.TestCreateAndQueryOrder;
var
  Order: TOrder;
  LoadedOrder: TOrder;
begin
  Order := TOrder.Create;
  Order.Id := TGUID.NewGuid.ToString;
  Order.CustomerId := 'cust-001';
  Order.Total := 100.00;
  
  FContext.Insert<TOrder>(Order);
  
  LoadedOrder := FContext.Find<TOrder>(Order.Id);
  Assert.IsNotNull(LoadedOrder);
  Assert.AreEqual(Order.CustomerId, LoadedOrder.CustomerId);
  Assert.AreEqual(Order.Total, LoadedOrder.Total, 0.01);
end;
```

### 4. 测试覆盖率目标

- **核心模块**: 90%+ 覆盖率
- **业务逻辑**: 80%+ 覆盖率
- **UI 层**: 60%+ 覆盖率
- **边界条件**: 必须覆盖
- **异常路径**: 必须覆盖

---

## 总结

### 核心原则

1. **一致性** - 遵循统一的代码风格和模式
2. **可读性** - 代码是写给人看的
3. **可测试性** - 设计时考虑测试
4. **安全性** - 安全是功能，不是附加项
5. **性能** - 在正确性基础上优化

### 推荐阅读

- UniBase 架构设计文档 (`docs/01_Architecture.md`)
- UniBase API 参考手册 (`docs/02_API_Reference.md`)
- UniBase FAQ 与故障排查 (`docs/03_FAQ_Troubleshooting.md`)

---

*文档版本: 1.0*
*最后更新: 2025-11-29*
