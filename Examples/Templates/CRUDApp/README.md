# CRUD Application Template

基于 DeepBase 框架�?CRUD（增删改查）应用程序模板�?

## 功能特�?

- 客户管理（Customer）完�?CRUD 操作
- 搜索和过滤功�?
- 状态筛选（活跃/停用/暂停�?
- 表单验证
- 软删除支�?
- 窗体状态持久化

## 项目结构

```
CRUDApp/
├── CRUDApp.dpr           # 项目主文�?
├── Main.Form.pas/dfm     # 主窗体（客户列表�?
├── Data.Module.pas/dfm   # 数据访问模块
├── Entity.Customer.pas   # 客户实体类（ORM 映射�?
├── Form.CustomerEdit.pas/dfm  # 客户编辑窗体
└── README.md             # 本文�?
```

## DeepBase 功能演示

### 1. 数据库初始化
```pascal
// Data.Module.pas
DeepBase.Manager.DeepBase.InitializeWithDB(FDatabasePath);
```

### 2. ORM 实体定义
```pascal
// Entity.Customer.pas
[Table('Customers')]
[Index('IX_Customers_Email', 'Email', True)]
TCustomer = class
  [PrimaryKey]
  [Column('Id')]
  FId: string;
  // ...
end;
```

### 3. 配置管理
```pascal
// Main.Form.pas - 保存窗体状�?
DeepBase.Config.SetConfigInt('MainForm.Left', Left);
DeepBase.Config.SetConfigInt('MainForm.Width', Width);
```

### 4. 日志记录
```pascal
// 操作日志
Log.Info('Customer created: %s', [Customer.DisplayName]);
Log.Error('Failed to load customers: %s', [E.Message]);
```

### 5. 数据验证
```pascal
// Entity.Customer.pas
function TCustomer.Validate(out ErrorMessage: string): Boolean;
begin
  if Trim(FFirstName) = '' then
  begin
    ErrorMessage := 'First name is required';
    Exit(False);
  end;
  // ...
end;
```

## 如何使用

1. �?RAD Studio 中打开 `CRUDApp.dproj`
2. 确保 DeepBase 框架路径已添加到搜索路径
3. 编译并运�?

## 自定义指�?

### 添加新实�?

1. 创建实体类（参�?`Entity.Customer.pas`�?
2. �?`Data.Module.pas` 中添�?CRUD 方法
3. 创建列表和编辑窗�?

### 添加字段

1. 在实体类中添加属性和 `[Column]` 属�?
2. 更新 `CreateXxxTable` 方法
3. 更新窗体 UI

### 国际�?

将所有用户可见文本替换为 `T()` 函数调用�?
```pascal
Caption := T('Customer Management');
MessageDlg(T('Are you sure?'), mtConfirmation, [mbYes, mbNo], 0);
```

## 依赖

- DeepBase Framework
- FireDAC (SQLite)
- VCL

## 许可

MIT License
