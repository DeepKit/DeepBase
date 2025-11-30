# 23. AI 编码硬约束（强约束 AI）

> ⚠️ **本文件是 AI 编码辅助的强制约束规范**
> AI 在为 UniBase 项目生成代码时，必须严格遵守以下规则。违反任何一条都将导致代码不可接受。

---

## 0. 元规则

```
【绝对禁止】= 任何情况下都不得违反
【必须执行】= 每次编码前/后必须检查
【强制要求】= 输出代码必须满足
```

---

## 1. 复用优先（绝对禁止重复造轮子）

### 1.1 禁止重复实现已有功能

```pascal
// 【绝对禁止】自行实现以下功能：
❌ function MyGetConfigValue(Key: string): string;  // 已有 TConfigManager
❌ procedure MyLogError(Msg: string);               // 已有 TLogManager
❌ function MyLoadI18N(Key: string): string;        // 已有 TLanguageManager
❌ procedure MyShowException(E: Exception);         // 已有 TExceptionReporter
❌ function MyEncryptPassword(S: string): string;   // 已有安全模块

// 【必须执行】使用框架已有组件：
✅ TConfigManager.Instance.GetValue('Key')
✅ TLogManager.Instance.LogError('Msg')
✅ TLanguageManager.Instance.GetText('Key')
✅ TExceptionReporter.Instance.ReportException(E)
```

### 1.2 禁止绕过 Manager 直接操作

```pascal
// 【绝对禁止】直接操作底层资源：
❌ SQLiteConnection.ExecSQL('INSERT INTO Settings...')  // 绕过 ConfigManager
❌ TFile.WriteAllText(LogPath, LogContent)              // 绕过 LogManager
❌ FDQuery.Open('SELECT * FROM config...')              // 绕过 QueryManager

// 【强制要求】通过 Manager 层操作：
✅ TConfigManager.Instance.SetValue(...)
✅ TLogManager.Instance.LogInfo(...)
✅ TQueryManager.Instance.Execute(...)
```

### 1.3 新增代码前必须搜索

```
【必须执行】在编写新函数/类之前：
1. 搜索 UT*.pas、BT*.pas、DB*.pas 是否有类似功能
2. 搜索 Manager 类是否已提供相关 API
3. 搜索 docs/ 文档确认设计意图
4. 若找到可复用代码，必须使用而非重写
```

---

## 2. 分层约束（绝对禁止跨层访问）

### 2.1 层级依赖方向

```
【强制要求】依赖方向必须是单向的：
UI层 → 业务层 → 数据层 → 基础设施层

【绝对禁止】反向依赖：
❌ 数据层 uses Forms, Dialogs;      // 数据层引用UI
❌ 基础层 uses MyBusinessUnit;      // 基础层引用业务
❌ UT单元 uses BTxxx, DBxxx;        // 工具层引用高层
```

### 2.2 UI 层禁止直接数据库操作

```pascal
// 【绝对禁止】在 Form/Frame 中：
❌ procedure TMainForm.ButtonClick;
   begin
     FDQuery.SQL.Text := 'SELECT * FROM ...';  // UI直接访问数据库
     FDQuery.Open;
   end;

// 【强制要求】通过服务层调用：
✅ procedure TMainForm.ButtonClick;
   begin
     FDataService.LoadCustomers;  // 委托给服务层
   end;
```

### 2.3 单元命名必须反映层级

```
【强制要求】遵守命名前缀：
- UT*.pas = 通用工具（无业务依赖）
- BT*.pas = 基础工具（可依赖 UT）
- DB*.pas = 数据库访问
- PG*.pas = PostgreSQL 专用
- UI*.pas = 界面层
- Svc*.pas = 服务层
```

---

## 3. 内存管理（绝对禁止泄漏）

### 3.1 创建即绑定 Owner 或显式释放

```pascal
// 【绝对禁止】孤立创建无 Owner 对象：
❌ FList := TStringList.Create;  // 无 try-finally，可能泄漏

// 【强制要求】二选一：
✅ // 方案A：指定 Owner
   FList := TStringList.Create;
   FList.Owner := Self;  // 或在构造时传入

✅ // 方案B：try-finally 保护
   LList := TStringList.Create;
   try
     // 使用 LList
   finally
     LList.Free;
   end;
```

### 3.2 接口引用计数规则

```pascal
// 【绝对禁止】混用接口和对象引用：
❌ var
     Obj: TMyClass;
     Intf: IMyInterface;
   begin
     Obj := TMyClass.Create;
     Intf := Obj;       // 引用计数 +1
     Obj.Free;          // 危险！Intf 仍指向已释放内存
   end;

// 【强制要求】统一使用接口或对象：
✅ var Intf: IMyInterface;
   begin
     Intf := TMyClass.Create;  // 仅用接口引用
     // 离开作用域自动释放
   end;
```

### 3.3 容器对象所有权

```pascal
// 【强制要求】明确容器所有权：
✅ FList := TObjectList<TMyItem>.Create(True);   // OwnsObjects = True
✅ FDict := TObjectDictionary<K,V>.Create([doOwnsValues]);
```

---

## 4. 字符串与国际化（绝对禁止硬编码）

### 4.1 用户可见文本必须走 i18n

```pascal
// 【绝对禁止】硬编码用户可见文本：
❌ ShowMessage('操作成功');
❌ Label1.Caption := '请输入用户名';
❌ raise Exception.Create('文件不存在');

// 【强制要求】使用 LanguageManager：
✅ ShowMessage(Lang.GetText('MSG_SUCCESS'));
✅ Label1.Caption := Lang.GetText('LBL_USERNAME');
✅ raise Exception.Create(Lang.GetText('ERR_FILE_NOT_FOUND'));
```

### 4.2 资源字符串用于框架级消息

```pascal
// 【强制要求】框架内部用 resourcestring：
resourcestring
  SConfigNotFound = 'Configuration key not found: %s';
  SConnectionFailed = 'Database connection failed: %s';
```

---

## 5. 异常处理（绝对禁止吞没异常）

### 5.1 禁止空 except 块

```pascal
// 【绝对禁止】：
❌ try
     DoSomething;
   except
     // 空的，吞没所有异常
   end;

❌ try
     DoSomething;
   except
     on E: Exception do;  // 空处理
   end;

// 【强制要求】至少记录日志：
✅ try
     DoSomething;
   except
     on E: Exception do
       TLogManager.Instance.LogException(E);
   end;
```

### 5.2 使用框架异常类型

```pascal
// 【强制要求】使用 UniBase 异常体系：
✅ raise EUniBaseConfigException.Create('...');
✅ raise EUniBaseDBException.Create('...');
✅ raise EUniBaseValidationException.Create('...');

// 【绝对禁止】直接使用基础 Exception：
❌ raise Exception.Create('业务错误');  // 应使用具体子类
```

---

## 6. 线程安全（绝对禁止竞态条件）

### 6.1 Manager 单例访问

```pascal
// Manager 单例已内置线程安全，可直接使用：
✅ TConfigManager.Instance.GetValue(...)  // 线程安全
✅ TLogManager.Instance.LogInfo(...)      // 线程安全

// 【绝对禁止】自行缓存单例引用后跨线程传递：
❌ var GlobalConfig: TConfigManager;  // 危险的全局缓存
```

### 6.2 UI 更新必须同步到主线程

```pascal
// 【绝对禁止】从子线程直接更新 UI：
❌ TThread.CreateAnonymousThread(
     procedure
     begin
       Label1.Caption := '完成';  // 跨线程访问 VCL
     end
   ).Start;

// 【强制要求】使用 Synchronize 或 Queue：
✅ TThread.CreateAnonymousThread(
     procedure
     begin
       TThread.Synchronize(nil,
         procedure
         begin
           Label1.Caption := '完成';
         end);
     end
   ).Start;
```

---

## 7. 数据库操作（绝对禁止 SQL 注入）

### 7.1 参数化查询

```pascal
// 【绝对禁止】字符串拼接 SQL：
❌ Query.SQL.Text := 'SELECT * FROM Users WHERE Name = ''' + UserInput + '''';

// 【强制要求】参数化：
✅ Query.SQL.Text := 'SELECT * FROM Users WHERE Name = :Name';
   Query.ParamByName('Name').AsString := UserInput;
```

### 7.2 使用 doQry 框架

```pascal
// 【强制要求】通过 doQry 执行查询：
✅ TQueryManager.Instance.Execute('GetUserByName', ['Name', UserInput]);
```

---

## 8. 命名规范（强制一致性）

### 8.1 Pascal 命名法

```pascal
// 【强制要求】：
✅ TCustomerService     // 类名：T 前缀 + PascalCase
✅ ICustomerRepository  // 接口：I 前缀 + PascalCase
✅ FCustomerList        // 字段：F 前缀 + PascalCase
✅ ACustomerName        // 参数：A 前缀 + PascalCase（可选但推荐）
✅ LTempValue           // 局部变量：L 前缀（可选但推荐）

// 【绝对禁止】：
❌ customerService      // 小写开头
❌ customer_service     // 下划线风格
❌ CUSTOMER_SERVICE     // 全大写（除常量外）
```

### 8.2 布尔属性/函数命名

```pascal
// 【强制要求】布尔返回值使用 Is/Has/Can/Should 前缀：
✅ function IsValid: Boolean;
✅ function HasPermission: Boolean;
✅ function CanExecute: Boolean;
✅ property IsActive: Boolean read FIsActive;

// 【绝对禁止】：
❌ function Valid: Boolean;      // 缺少 Is
❌ function CheckPermission: Boolean;  // 动词不明确
```

---

## 9. 配置与敏感数据（绝对禁止硬编码）

### 9.1 禁止硬编码配置值

```pascal
// 【绝对禁止】：
❌ const API_URL = 'https://api.example.com';
❌ const DB_PASSWORD = 'mypassword';
❌ const LICENSE_KEY = 'XXXX-XXXX-XXXX';

// 【强制要求】从配置读取：
✅ FAPI_URL := TConfigManager.Instance.GetValue('API_URL');
✅ FDBPassword := TConfigManager.Instance.GetSecureValue('DB_PASSWORD');
```

### 9.2 敏感数据加密存储

```pascal
// 【强制要求】敏感配置使用加密接口：
✅ TConfigManager.Instance.SetSecureValue('Password', AValue);
✅ TConfigManager.Instance.GetSecureValue('Password');
```

---

## 10. 代码提交前检查清单

```
【必须执行】每次生成代码后自检：

□ 复用检查
  □ 是否搜索过现有 UT/BT/DB/Manager？
  □ 是否存在可复用的现有实现？
  □ 新增代码是否与现有代码功能重复？

□ 分层检查
  □ uses 子句是否符合分层约束？
  □ UI 层是否有直接数据库访问？
  □ 依赖方向是否正确（高层→低层）？

□ 内存安全
  □ 所有 Create 是否有对应的 Free 或 Owner？
  □ 接口和对象引用是否正确分离？
  □ 容器所有权是否明确？

□ 字符串检查
  □ 是否有硬编码的用户可见文本？
  □ 是否使用了 LanguageManager？

□ 异常处理
  □ 是否有空的 except 块？
  □ 是否使用了正确的异常类型？

□ 线程安全
  □ UI 更新是否在主线程？
  □ 共享资源是否有保护？

□ 安全检查
  □ SQL 是否参数化？
  □ 敏感数据是否加密？
  □ 配置是否硬编码？

□ 命名规范
  □ 类/接口/字段命名是否符合规范？
  □ 布尔值命名是否清晰？
```

---

## 11. 违规严重程度分级

| 级别 | 描述 | 示例 | 处理 |
|------|------|------|------|
| **P0-致命** | 安全漏洞或数据损坏风险 | SQL 注入、密码硬编码 | 立即修复，禁止合并 |
| **P1-严重** | 内存泄漏或程序崩溃风险 | 无 Free、空 except | 必须修复后合并 |
| **P2-重要** | 违反架构约束 | 跨层访问、重复实现 | 应当修复 |
| **P3-建议** | 命名或风格问题 | 命名不规范 | 建议修复 |

---

## 12. AI 自检声明模板

```
在提交代码时，AI 应附加以下声明：

---
## 自检声明
- [x] 已搜索 UT/BT/DB/Manager，未发现可复用实现
- [x] uses 子句符合分层约束
- [x] 所有对象创建有对应释放机制
- [x] 无硬编码字符串（或已标注待处理）
- [x] 无空 except 块
- [x] SQL 已参数化
- [x] 命名符合规范
---
```

---

> 📌 **本文档由人类架构师维护，AI 必须严格遵守。如有规则冲突或特殊情况，应明确标注并请求人类审核。**
