# UniBase 编码规范

## 📋 目录

- [命名规范](#命名规范)
- [代码结构](#代码结构)
- [注释规范](#注释规范)
- [异常处理](#异常处理)
- [内存管理](#内存管理)
- [线程安全](#线程安全)
- [性能考虑](#性能考虑)

## 🏷️ 命名规范

### 类名
- 使用 PascalCase
- 以 `T` 开头
- 描述性名称，避免缩写

```delphi
// ✅ 正确
TUserManager
TDatabaseConnection
TConfigurationService

// ❌ 错误
TUsrMgr
TDbConn
TConfigSvc
```

### 接口名
- 使用 PascalCase
- 以 `I` 开头
- 描述行为或能力

```delphi
// ✅ 正确
IUserRepository
IConfigurationProvider
ILoggingService

// ❌ 错误
IUser
IConfig
ILog
```

### 方法名
- 使用 PascalCase
- 动词开头，描述操作

```delphi
// ✅ 正确
function GetUserById(const Id: Integer): TUser;
procedure SaveConfiguration(const Config: TConfiguration);
function ValidateInput(const Input: string): Boolean;

// ❌ 错误
function User(const Id: Integer): TUser;
procedure Config(const Config: TConfiguration);
function Input(const Input: string): Boolean;
```

### 变量名
- 局部变量使用 camelCase
- 字段使用 `F` 前缀 + PascalCase
- 参数使用 `A` 前缀 + PascalCase

```delphi
// ✅ 正确
var
  userName: string;
  isValid: Boolean;

private
  FUserName: string;
  FIsConnected: Boolean;

procedure ProcessUser(const AUserName: string; AAge: Integer);

// ❌ 错误
var
  UserName: string;  // 应该是 camelCase
  user_name: string; // 不使用下划线

private
  UserName: string;  // 缺少 F 前缀

procedure ProcessUser(const UserName: string; Age: Integer); // 缺少 A 前缀
```

### 常量名
- 使用 UPPER_CASE
- 描述性名称

```delphi
// ✅ 正确
const
  DEFAULT_TIMEOUT_MS = 30000;
  MAX_RETRY_COUNT = 3;
  CONFIG_FILE_NAME = 'config.db';

// ❌ 错误
const
  TIMEOUT = 30000;
  MAX = 3;
  FILE = 'config.db';
```

## 🏗️ 代码结构

### 单元文件结构
```delphi
unit UniBase.ModuleName;

interface

uses
  // 系统单元
  System.SysUtils,
  System.Classes,
  // 第三方单元
  FireDAC.Comp.Client,
  // UniBase 单元
  UniBase.Common,
  UniBase.Constants;

type
  // 类型声明

implementation

uses
  // 实现部分的 uses

// 实现代码

end.
```

### 类声明结构
```delphi
type
  TExampleClass = class(TInterfacedObject, IExampleInterface)
  private
    // 私有字段
    FFieldName: string;
    
    // 私有方法
    procedure InternalMethod;
    
  protected
    // 受保护方法
    
  public
    // 构造/析构
    constructor Create;
    destructor Destroy; override;
    
    // 公共方法
    function PublicMethod: Boolean;
    
    // 属性
    property FieldName: string read FFieldName write FFieldName;
  end;
```

## 📝 注释规范

### XML 文档注释
```delphi
/// <summary>
/// 获取指定用户的详细信息
/// </summary>
/// <param name="AUserId">用户ID</param>
/// <returns>用户对象，如果不存在返回nil</returns>
/// <exception cref="EArgumentException">当用户ID无效时抛出</exception>
function GetUser(const AUserId: Integer): TUser;
```

### 行内注释
```delphi
// 验证用户输入的有效性
if not ValidateInput(userInput) then
  Exit;

// TODO: 实现缓存机制以提高性能
// FIXME: 修复并发访问时的竞态条件
// NOTE: 这里使用了特殊的算法，参考 RFC 3986
```

### 复杂逻辑注释
```delphi
// 使用二分查找算法在排序数组中查找元素
// 时间复杂度: O(log n)
// 空间复杂度: O(1)
function BinarySearch(const AArray: TArray<Integer>; ATarget: Integer): Integer;
var
  left, right, mid: Integer;
begin
  left := 0;
  right := Length(AArray) - 1;
  
  while left <= right do
  begin
    // 防止整数溢出的中点计算
    mid := left + (right - left) div 2;
    
    if AArray[mid] = ATarget then
      Exit(mid)
    else if AArray[mid] < ATarget then
      left := mid + 1
    else
      right := mid - 1;
  end;
  
  Result := -1; // 未找到
end;
```

## ⚠️ 异常处理

### 异常类型
```delphi
// 自定义异常类
type
  EUniBaseException = class(Exception);
  EConfigurationException = class(EUniBaseException);
  EValidationException = class(EUniBaseException);
```

### 异常处理模式
```delphi
// ✅ 正确的异常处理
function ProcessData(const AData: string): Boolean;
begin
  Result := False;
  
  if AData.IsEmpty then
    raise EArgumentException.Create('Data cannot be empty');
    
  try
    // 处理数据
    Result := True;
  except
    on E: ESpecificException do
    begin
      // 处理特定异常
      Logger.Error('Specific error: ' + E.Message);
      raise; // 重新抛出
    end;
    on E: Exception do
    begin
      // 处理通用异常
      Logger.Error('Unexpected error: ' + E.Message);
      raise EProcessingException.Create('Failed to process data', E);
    end;
  end;
end;

// ❌ 错误的异常处理
function ProcessData(const AData: string): Boolean;
begin
  try
    // 处理数据
    Result := True;
  except
    // 吞掉所有异常
    Result := False;
  end;
end;
```

## 💾 内存管理

### 对象生命周期
```delphi
// ✅ 正确的内存管理
procedure ProcessUsers;
var
  userList: TObjectList<TUser>;
  user: TUser;
begin
  userList := TObjectList<TUser>.Create(True); // 拥有对象
  try
    for user in GetUsers do
      userList.Add(user);
      
    // 处理用户列表
  finally
    userList.Free; // 自动释放所有用户对象
  end;
end;

// 使用 FreeAndNil 避免悬空指针
destructor TMyClass.Destroy;
begin
  FreeAndNil(FMyObject);
  inherited;
end;
```

### 接口使用
```delphi
// ✅ 推荐使用接口进行内存管理
function CreateService: IUserService;
begin
  Result := TUserService.Create; // 自动内存管理
end;

procedure UseService;
var
  service: IUserService;
begin
  service := CreateService;
  // 无需手动释放，接口会自动管理
end;
```

## 🔒 线程安全

### 同步机制
```delphi
// ✅ 正确的线程同步
type
  TThreadSafeCounter = class
  private
    FValue: Integer;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Increment;
    function GetValue: Integer;
  end;

procedure TThreadSafeCounter.Increment;
begin
  FLock.Enter;
  try
    Inc(FValue);
  finally
    FLock.Leave;
  end;
end;

// 使用 TMonitor 的现代方式
procedure TThreadSafeClass.SafeMethod;
begin
  TMonitor.Enter(Self);
  try
    // 线程安全的操作
  finally
    TMonitor.Exit(Self);
  end;
end;
```

## ⚡ 性能考虑

### 字符串操作
```delphi
// ✅ 高效的字符串拼接
function BuildString(const AItems: TArray<string>): string;
var
  sb: TStringBuilder;
  item: string;
begin
  sb := TStringBuilder.Create;
  try
    for item in AItems do
      sb.Append(item);
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

// ❌ 低效的字符串拼接
function BuildString(const AItems: TArray<string>): string;
var
  item: string;
begin
  Result := '';
  for item in AItems do
    Result := Result + item; // 每次都创建新字符串
end;
```

### 集合操作
```delphi
// ✅ 预分配容量
procedure ProcessLargeData;
var
  list: TList<Integer>;
begin
  list := TList<Integer>.Create;
  try
    list.Capacity := 10000; // 预分配容量
    // 添加数据
  finally
    list.Free;
  end;
end;

// ✅ 使用合适的集合类型
var
  lookup: TDictionary<string, TUser>; // O(1) 查找
  // 而不是 TList<TUser> 的 O(n) 查找
```

### 资源管理
```delphi
// ✅ 及时释放资源
procedure ProcessFile(const AFileName: string);
var
  stream: TFileStream;
begin
  stream := TFileStream.Create(AFileName, fmOpenRead);
  try
    // 处理文件
  finally
    stream.Free; // 及时释放文件句柄
  end;
end;
```

## 📋 检查清单

在提交代码前，请确保：

- [ ] 遵循命名规范
- [ ] 添加了适当的注释
- [ ] 处理了所有可能的异常
- [ ] 正确管理了内存
- [ ] 考虑了线程安全
- [ ] 优化了性能关键路径
- [ ] 编写了单元测试
- [ ] 更新了相关文档