# CRUD Application Template

基于 UniBase 框架的 CRUD（增删改查）应用程序模板。

## 功能特性

- 客户管理（Customer）完整 CRUD 操作
- 搜索和过滤功能
- 状态筛选（活跃/停用/暂停）
- 表单验证
- 软删除支持
- 窗体状态持久化

## 项目结构

```
CRUDApp/
├── CRUDApp.dpr           # 项目主文件
├── Main.Form.pas/dfm     # 主窗体（客户列表）
├── Data.Module.pas/dfm   # 数据访问模块
├── Entity.Customer.pas   # 客户实体类（ORM 映射）
├── Form.CustomerEdit.pas/dfm  # 客户编辑窗体
└── README.md             # 本文件
```

## UniBase 功能演示

### 1. 数据库初始化
```pascal
// Data.Module.pas
UniBase.Manager.UniBase.InitializeWithDB(FDatabasePath);
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
// Main.Form.pas - 保存窗体状态
UniBase.Config.SetConfigInt('MainForm.Left', Left);
UniBase.Config.SetConfigInt('MainForm.Width', Width);
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

1. 在 RAD Studio 中打开 `CRUDApp.dproj`
2. 确保 UniBase 框架路径已添加到搜索路径
3. 编译并运行

## 自定义指南

### 添加新实体

1. 创建实体类（参考 `Entity.Customer.pas`）
2. 在 `Data.Module.pas` 中添加 CRUD 方法
3. 创建列表和编辑窗体

### 添加字段

1. 在实体类中添加属性和 `[Column]` 属性
2. 更新 `CreateXxxTable` 方法
3. 更新窗体 UI

### 国际化

将所有用户可见文本替换为 `_()` 函数调用：
```pascal
Caption := _('Customer Management');
MessageDlg(_('Are you sure?'), mtConfirmation, [mbYes, mbNo], 0);
```

## 依赖

- UniBase Framework
- FireDAC (SQLite)
- VCL

## 许可

MIT License
