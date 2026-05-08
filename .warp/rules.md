# DeepBase 项目 AI 开发规�?

> 本规则适用于所有使�?DeepBase 框架�?Delphi 项目开发�?

## 项目定位（最高优先级�?

**DeepBase = Delphi 企业级应用开发基础框架**

> �?Delphi 企业级应用开发像 Spring Boot 一样简�?

### 是什�?
- �?企业级业务应用基础设施
- �?现代化架构模式（IoC/事件驱动/MVVM�?
- �?常用功能的简化封�?
- �?生产环境可靠性保�?

### 不是什�?
- �?游戏/图形引擎
- �?科学计算�?
- �?网络协议�?
- �?"大而全"的万能框�?

### 开发边界（禁止越界�?

| 允许开�?| 禁止开�?|
|----------|----------|
| IoC/EventBus/MVVM | 游戏引擎/物理引擎 |
| 配置/日志/缓存 | FFT/机器学习/信号处理 |
| 验证/授权/国际�?| TCP/UDP协议�?|
| 弹性模�?限流/调度 | PDF/Excel/Word生成 |
| 集合/日期时间/加密 | 自定义UI组件�?|

**边界功能（已实现，禁止扩展）**�?
- DeepBase.Math - 保持现状，不添加高级数学
- DeepBase.Graph - 保持现状，不添加更多算法
- DeepBase.Net - 保持现状，HTTP客户端用原生
- DeepBase.Reflection - 保持现状
- DeepBase.Diff/Expression - 保持现状

详见：`docs/00_项目定位与开发边�?md`

---

## 铁律（必须遵守）

### 1. 搜索优先
写任何代码前�?*必须先搜�?*项目中是否已有类似实现：
- 搜索 `UT*.pas`、`BT*.pas`、`DB*.pas` 公共�?
- 搜索 `DeepBase.*` 模块
- 搜索 `docs/` 文档确认设计意图

### 2. 复用 DeepBase API
| 功能 | 必须使用 | 禁止使用 |
|------|----------|----------|
| 配置读写 | `DeepBase.GetConfig/SetConfig` | TIniFile/TRegistry |
| 国际�?| `T()` / `TFmt()` | 硬编码中文字符串 |
| 日志记录 | `Log/LogInfo/LogError` | OutputDebugString |
| 窗体状�?| `SaveFormState/RestoreFormState` | 手动保存位置 |
| MRU 列表 | `AddMRU/GetMRUList` | 自建最近文�?|
| 数据库访�?| `DoQry` 参数化查�?| �?SQL 字符串拼�?|

### 3. 分层架构
```
View (uFrm*.pas)      �?只处�?UI 展示和用户输�?
Controller (uCtrl*.pas) �?业务逻辑协调
Model (uDM*.pas)       �?数据访问
DeepBase.Core          �?基础设施
```
- View 不直接访问数据库
- Controller 不直接操�?UI 控件
- 依赖方向：View �?Controller �?Model �?DeepBase

### 4. 内存安全
```delphi
// �?正确：try/finally 保护
List := TStringList.Create;
try
  // 使用 List
finally
  List.Free;
end;

// �?错误：无保护
List := TStringList.Create;
// 使用 List（可能泄漏）
```

### 5. 线程安全
```delphi
// �?正确：通过 Queue 回主线程更新 UI
TTask.Run(
  procedure
  begin
    TThread.Queue(nil,
      procedure begin lblStatus.Caption := T('Done'); end
    );
  end
);

// �?错误：子线程直接更新 UI
TTask.Run(
  procedure begin lblStatus.Caption := '完成'; end  // 危险�?
);
```

## 绝对禁止

| 禁止�?| 替代方案 |
|--------|----------|
| 硬编码中文字符串 | `T('English text')` |
| `TIniFile` / `TRegistry` | `DeepBase.GetConfig/SetConfig` |
| `OutputDebugString` | `Log(llDebug, ...)` |
| �?SQL 拼接 | DoQry 参数化查�?|
| `Application.ProcessMessages` 循环 | `TTask.Run` |
| `TThread.Synchronize` | `TThread.Queue` |
| �?`except` �?| 至少记录日志 |
| 全局变量存状�?| 单例属性或依赖注入 |
| View 直接访问 DataModule | 通过 Controller |
| 直接 `raise Exception.Create` | 使用 `EDeepBase*` 异常�?|

## 标准代码模板

### 配置读写
```delphi
// 读取
Value := DeepBase.GetConfig('Section.Key', 'DefaultValue');
IntVal := DeepBase.GetConfigInt('Section.IntKey', 0);
BoolVal := DeepBase.GetConfigBool('Section.BoolKey', False);

// 写入
DeepBase.SetConfig('Section.Key', NewValue);
```

### 国际�?
```delphi
Caption := T('Window Title');
ShowMessage(T('Operation completed'));
ShowMessage(TFmt('Processed %d items', [Count]));
```

### 日志记录
```delphi
Log(llInfo, 'ModuleName', 'Operation completed');
Log(llError, 'ModuleName', 'Failed: ' + E.Message);
```

### 异步操作
```delphi
TTask.Run(
  procedure
  var Data: TMyData;
  begin
    Data := LoadDataFromServer;  // 耗时操作
    TThread.Queue(nil,
      procedure begin UpdateUI(Data); end  // 主线程更�?UI
    );
  end
);
```

## 命名规范

| 类型 | 前缀 | 示例 |
|------|------|------|
| �?| T | `TCustomerService` |
| 接口 | I | `ICustomerRepository` |
| 字段 | F | `FCustomerList` |
| 参数 | A | `ACustomerName` |
| 局部变�?| L | `LTempValue` |
| 单元-工具 | UT | `UTString.pas` |
| 单元-基础 | BT | `BTValidation.pas` |
| 单元-数据�?| DB | `DBRepository.pas` |
| 单元-窗体 | uFrm | `uFrmMain.pas` |
| 单元-控制�?| uCtrl | `uCtrlCustomer.pas` |

## 代码生成自检清单

生成代码后，AI 必须自检�?
- [ ] 是否先搜索了现有实现�?
- [ ] 是否复用�?DeepBase API�?
- [ ] 无硬编码中文字符串？
- [ ] 所�?Create 有对�?Free�?
- [ ] SQL 全部参数化？
- [ ] 异步操作 UI 更新在主线程�?
- [ ] 分层正确，无跨层访问�?

## 文档参�?

| 文档 | 路径 | 用�?|
|------|------|------|
| 文档索引 | `docs/00.00.DeepBase-文档索引-v1.0.md` | 全部文档导航 |
| AI集成指南 | `docs/01.01.DeepBase-4AI-集成指南-v1.0.md` | �?AI唯一入口 |
| 技术规�?| `docs/03.03.DeepBase-4H-技术规�?v1.0.md` | 架构设计参�?|
| 数据库指�?| `docs/04.03.DeepBase-4AI-数据库指�?v1.0.md` | DoQry 使用 |
| Schema说明 | `docs/04.01.DeepBase-4AI-数据库Schema说明-v1.0.md` | 23张表定义 |
