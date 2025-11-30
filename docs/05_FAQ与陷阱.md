# 05. 常见问题与陷阱防范

> 本文档整合了 FAQ、故障排除和 Delphi 架构陷阱防范。

---

## 第一部分：常见问题 FAQ

### 1. 初始化与配置

**Q: UniBase 初始化失败 `[1] ConfigDB Not Found`**

检查：
- EXE 目录下是否有 `root.txt`
- `root.txt` 中路径是否正确
- 是否运行过 Studio 初始化

**Q: `[3] Permission Denied`**

程序安装在 `Program Files` 且未以管理员运行。解决：
- 将数据目录指向 `%APPDATA%`
- 或赋予安装目录写入权限

**Q: 配置是否自动保存？**

是，每次 `SetConfig*` 立即保存。

### 2. 国际化

**Q: 如何添加翻译？**

```bash
unibase i18n scan --path ./src -r --output strings.json
unibase i18n import -i zh-CN.json -o config.db
```

**Q: 界面未翻译**

检查：
- `I18nTexts` 表是否有对应 Key
- 当前语言设置是否正确

### 3. 日志

**Q: 日志存储位置？**

取决于 `StorageMode`：
- `lsmDatabase`: `Logs` 表
- `lsmFile`: `logs/` 目录
- `lsmBoth`: 两者

**Q: 如何清理旧日志？**

```pascal
UniBase.Log.ClearOldLogs(30);  // 保留30天
```

### 4. 编译错误

**Q: `E2035: Incompatible types` (LLMChatAsync)**

```pascal
// 错误
procedure(Response: string)
// 正确
procedure(const Response: string; Success: Boolean)
```

**Q: `E2003: Undeclared identifier 'Log'`**

添加 `uses UniBase.Manager;`

### 5. 运行时异常

**Q: `EAccessViolation at FormDestroy`**

不要手动 `Free` 放在窗体上的组件，Owner 会自动释放。

**Q: `Database is locked` (SQLite)**

多进程同时写入。UniBase 已开启 WAL 模式，检查是否有进程挂死。

**Q: `FireDAC Object factory missing`**

缺少驱动单元，添加：
- `FireDAC.VCLUI.Wait`
- `FireDAC.Phys.PG` 或 `FireDAC.Phys.SQLite`

---

## 第二部分：Delphi 架构陷阱

### 1. 循环引用

**问题**：两单元在 `interface` 互相 `uses`

```pascal
// ❌ 错误
unit ViewMain;
interface
uses CtrlMain;

unit CtrlMain;
interface
uses ViewMain;  // 编译错误 F2047
```

**解决 1：接口解耦**

```pascal
// ✅ 创建接口单元
unit IViewMainIntf;
interface
type
  IViewMain = interface
    procedure ShowMessage(const Msg: string);
  end;

// Ctrl 只依赖接口
unit CtrlMain;
interface
uses IViewMainIntf;
```

**解决 2：移到 implementation**

```pascal
unit ViewMain;
interface
// 不在这里 uses CtrlMain

implementation
uses CtrlMain;  // 移到这里
```

### 2. 内存泄漏

**问题**：TFDQuery 忘记释放

```pascal
// ❌ 错误
Q := TFDQuery.Create(nil);
Q.Open;
// 忘记 Q.Free

// ✅ 正确
Q := TFDQuery.Create(nil);
try
  Q.Open;
finally
  Q.Free;
end;
```

**规则**：
- `Create(nil)` → 必须手动 `Free`
- `Create(Self)` → 由 Self 释放

### 3. 线程死锁

**问题**：同步等待自己的线程

```pascal
// ❌ 错误：主线程等待子线程，子线程 Synchronize 等待主线程
TThread.CreateAnonymousThread(
  procedure begin
    TThread.Synchronize(nil, procedure begin UpdateUI; end);
  end).WaitFor;
```

**正确**：使用回调或 Queue

```pascal
// ✅ 使用 Queue 不阻塞
TThread.Queue(nil, procedure begin UpdateUI; end);
```

### 4. 接口引用计数

**问题**：混用对象和接口引用

```pascal
// ❌ 危险
var
  Obj: TMyClass;
  Intf: IMyInterface;
begin
  Obj := TMyClass.Create;
  Intf := Obj;   // 引用计数 +1
  Obj.Free;      // 对象被释放，但 Intf 还在引用！
end;

// ✅ 正确：统一使用接口
var Intf: IMyInterface;
begin
  Intf := TMyClass.Create;
  // 离开作用域自动释放
end;
```

### 5. TDataModule 滥用

**问题**：在 DataModule 中放 UI 代码

```pascal
// ❌ 错误：uDM 引用 VCL
unit uDM;
uses Vcl.Forms, Vcl.Dialogs;

// ✅ 正确：uDM 只做数据访问
unit uDM;
uses FireDAC.Comp.Client;
```

### 6. FireDAC 陷阱

**问题**：忘记 ScriptCommands

```pascal
// ❌ TFDScript 执行无效果
FDScript1.ExecuteAll;

// ✅ 添加依赖
uses FireDAC.Stan.Script, FireDAC.Comp.ScriptCommands;
```

### 7. 字符串编码

**问题**：中文乱码

```pascal
// ❌ .pas 保存为 ANSI
ShowMessage('你好');  // 乱码

// ✅ .pas 保存为 UTF-8 with BOM
// 或使用 T() 函数
ShowMessage(T('Hello'));
```

### 8. 事件处理

**问题**：仅绑定 OnDblClick

```pascal
// ❌ 用户可能期望单击
ListView1.OnDblClick := HandleClick;

// ✅ 同时提供 Action/右键菜单
ListView1.OnDblClick := HandleClick;
ListView1.PopupMenu := PopupMenu1;  // 右键也能操作
```

### 9. 泛型与 RTTI

**问题**：泛型类型信息丢失

```pascal
// ❌ 运行时无法获取 T 的信息
function GetTypeName<T>: string;
begin
  Result := T.ClassName;  // 编译错误
end;

// ✅ 使用 TypeInfo
function GetTypeName<T>: string;
begin
  Result := PTypeInfo(TypeInfo(T))^.Name;
end;
```

---

## 检查清单

### 架构检查
- [ ] 无循环引用（接口解耦或移到 implementation）
- [ ] View/Ctrl/uDM 分层清晰
- [ ] uDM 无 UI 代码

### 内存检查
- [ ] 所有 `Create(nil)` 有对应 `Free`
- [ ] 接口和对象引用不混用
- [ ] 启用 `ReportMemoryLeaksOnShutdown`

### 编码检查
- [ ] .pas/.dfm 为 UTF-8
- [ ] 用户文本使用 `T()`
- [ ] SQL 全部参数化
