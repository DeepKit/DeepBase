# UniFlow 接口契约文档

> 版本: 1.0
> 更新日期: 2025-12-07
> ENTROPY-014: 接口契约文档化

---

## 概述

本文档定义 UniFlow 核心接口的契约规范，包括方法签名、前置条件、后置条件和异常处理。

---

## 核心接口

### IEventStore

**位置**: `UniFlow.EventSourcing.Store.pas`

**职责**: 事件存储与检索

```pascal
IEventStore = interface
  ['{GUID}']
  procedure Append(const AFlowId: string; AEvent: TUniFlowEvent);
  procedure AppendBatch(const AFlowId: string; AEvents: TObjectList<TUniFlowEvent>);
  function ReadEvents(const AFlowId: string; AFromVersion: Int64 = 0): TObjectList<TUniFlowEvent>;
  function GetLatestVersion(const AFlowId: string): Int64;
  procedure SaveSnapshot(const AFlowId: string; ASnapshot: TUniFlowSnapshot);
  function LoadSnapshot(const AFlowId: string): TUniFlowSnapshot;
end;
```

**契约**:

| 方法 | 前置条件 | 后置条件 | 异常 |
|------|----------|----------|------|
| `Append` | `AFlowId` 非空，`AEvent` 非 nil | 事件持久化，版本号递增 | `EEventStoreError` |
| `AppendBatch` | 事件列表非空 | 原子写入所有事件 | `EEventStoreError` |
| `ReadEvents` | `AFlowId` 存在 | 返回按版本排序的事件列表 | 空列表（无事件时） |
| `GetLatestVersion` | - | 返回最新版本号，无事件返回 0 | - |
| `SaveSnapshot` | 快照版本 >= 当前版本 | 覆盖旧快照 | `ESnapshotError` |
| `LoadSnapshot` | - | 返回最近快照或 nil | - |

---

### IActionExecutor

**位置**: `UniFlow.Workflow.Executor.pas`

**职责**: 执行工作流中的 Action 步骤

```pascal
IActionExecutor = interface
  ['{GUID}']
  function Execute(const AAction: TActionDefinition; 
    AContext: TWorkflowContext): TStepResult;
  function CanHandle(const AActionType: TActionType): Boolean;
  function GetMetadata: TExecutorMetadata;
end;
```

**契约**:

| 方法 | 前置条件 | 后置条件 | 异常 |
|------|----------|----------|------|
| `Execute` | `CanHandle(AAction.ActionType) = True` | 返回成功/失败结果 | 不抛异常，错误通过 `TStepResult.Fail` 返回 |
| `CanHandle` | - | 返回是否支持该 ActionType | - |
| `GetMetadata` | - | 返回执行器元数据 | - |

**Result 模式**:
- 成功: `TStepResult.OK` 或 `TStepResult.OKWithData(AData)`
- 失败: `TStepResult.Fail(AErrorCode, AMessage)`
- 错误码格式: `{Source}/{Category}/{Specific}`

---

### IPluginActionExecutor

**位置**: `UniFlow.Plugin.Intf.pas`

**职责**: 插件 Action 执行接口

```pascal
IPluginActionExecutor = interface
  ['{GUID}']
  function Execute(const AInput: TJSONObject): TPluginExecuteResult;
  function GetMetadata: TPluginMetadata;
  function ValidateInput(const AInput: TJSONObject): TValidationResult;
end;
```

**契约**:

| 方法 | 前置条件 | 后置条件 | 异常 |
|------|----------|----------|------|
| `Execute` | `ValidateInput(AInput).IsValid = True` | 返回执行结果 | `EPluginError`（严重错误时） |
| `GetMetadata` | - | 返回包含 `Id`, `Name`, `Version`, `InputSchema` 的元数据 | - |
| `ValidateInput` | - | 返回验证结果，包含错误列表 | - |

---

### IWorkflowStateStore

**位置**: `UniFlow.Workflow.State.pas`

**职责**: 工作流实例状态持久化

```pascal
IWorkflowStateStore = interface
  ['{GUID}']
  procedure SaveInstance(AInstance: TWorkflowInstance);
  function LoadInstance(const AInstanceId: string): TWorkflowInstance;
  function ListInstances(const AFilter: TInstanceFilter): TObjectList<TWorkflowInstance>;
  procedure UpdateStatus(const AInstanceId: string; AStatus: TInstanceStatus);
  procedure DeleteInstance(const AInstanceId: string);
end;
```

**契约**:

| 方法 | 前置条件 | 后置条件 | 异常 |
|------|----------|----------|------|
| `SaveInstance` | `AInstance.Id` 非空 | 持久化实例状态 | `EStateStoreError` |
| `LoadInstance` | - | 返回实例或 nil | - |
| `ListInstances` | - | 返回匹配的实例列表 | - |
| `UpdateStatus` | 实例存在 | 状态更新 + 发布 `wetStatusChanged` 事件 | `EInstanceNotFound` |
| `DeleteInstance` | - | 软删除或硬删除 | - |

---

### ILogger

**位置**: `UniFlow.Diagnostics.pas`

**职责**: 日志记录接口

```pascal
ILogger = interface
  ['{GUID}']
  procedure Debug(const AMessage: string);
  procedure Info(const AMessage: string);
  procedure Warning(const AMessage: string);
  procedure Error(const AMessage: string);
  procedure Error(const AMessage: string; AException: Exception);
end;
```

**契约**:
- 所有方法线程安全
- 日志格式: `[{Timestamp}] [{Level}] [{Category}] {Message}`
- 不应抛出异常（内部处理）

---

### IAuditStore

**位置**: `UniFlow.Audit.Store.pas`

**职责**: 审计日志存储

```pascal
IAuditStore = interface
  ['{GUID}']
  procedure Log(AEntry: TAuditEntry);
  function Query(const AQuery: TAuditQuery): TAuditQueryResult;
  function GetById(AId: Int64): TAuditEntry;
end;
```

**契约**:

| 方法 | 前置条件 | 后置条件 | 异常 |
|------|----------|----------|------|
| `Log` | `AEntry` 完整 | 异步写入审计日志 | 静默失败（不影响主流程） |
| `Query` | - | 返回分页结果 | - |
| `GetById` | - | 返回条目或 nil | - |

---

## 通用契约规则

### 1. 错误处理

- **核心层**: 使用 Result 模式（`TStepResult`, `TValidationResult`）
- **外壳层**: 可使用异常，但必须记录日志
- **空 except 块**: 禁止，必须至少记录 DEBUG 日志

### 2. 线程安全

- 所有 `I*Store` 接口实现必须线程安全
- 使用 `TMonitor` 或 `TCriticalSection` 保护共享状态

### 3. 资源管理

- 接口返回的对象，调用方负责释放（除非文档另有说明）
- `TObjectList` 参数：调用方保持所有权，接口不释放

### 4. 版本兼容

- 接口新增方法使用 `default` 实现保持向后兼容
- 移除方法先标记 `deprecated`，下个大版本移除

---

## 版本历史

| 日期 | 版本 | 变更 |
|------|------|------|
| 2025-12-07 | 1.0 | 初始版本，定义 6 个核心接口契约 |
