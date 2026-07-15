# 专家 B 审阅报告: Core 业务逻辑与 AI/LLM（第三轮）

> 审查日期: 2026-07-08
> 审查范围: DeepBase.LLM.pas, DeepBase.LLM.Manager.pas, DeepBase.LLM.BillingClient.pas, DeepBase.LLM.ImportExport.pas, DeepBase.AIErrorHandler.pas, DeepBase.AutoFix.pas, DeepBase.AutoFix.HealthSignal.pas, DeepBase.AutoFix.ScenarioRunner.pas, DeepBase.AutoFix.StackWalker.pas, DeepBase.Scheduler.pas, DeepBase.Manager.pas, DeepBase.MVVM.pas, DeepBase.Authorization.pas, DeepBase.FeatureFlags.pas, DeepBase.PluginManager.pas, DeepBase.License.pas, DeepBase.AppLifecycle.pas, Features/DeepBase.LLM.Proxy.pas, Features/DeepBase.LLM.Types.pas, Features/DeepBase.LLM.Config.pas
> 文件总数: 20

## 概要

19 new issues: 4 P0 / 6 P1 / 7 P2 / 2 P3. 关键要点:
- **TProxyLLMClient.GenerateImageStream** 启动未追踪的 TTask 并捕获 Self，对象释放后回调悬空（P0）
- **TLLMManager.Destroy** 的 5 秒 WaitFor 超时后仍释放 FLLMClient，正在执行的 ExecuteAsync 任务访问已释放对象（P0）
- **TFileFlagStorage.SaveFlag** 在 OwnsObjects=True 的列表上做下标赋值，静默释放调用方的 AFlag 对象（P0）
- **LLM Manager/LLM.pas** 的 ParseResponse 覆盖 DoHttpRequest 返回的 False，错误响应体可能被解析为 Success=True（P1）

## 发现列表

| 编号 | 严重度 | 模块 | 分类 | 简述 |
|------|--------|------|------|------|
| BIZ-R3-001 | P0 | LLM.Proxy | async Self capture | GenerateImageStream 未追踪 TTask，Self 悬空 |
| BIZ-R3-002 | P0 | LLM.Manager | dangling ref | Destroy 5s 超时后释放 FLLMClient，任务仍在调用 |
| BIZ-R3-003 | P0 | FeatureFlags | object lifetime | SaveFlag 在 OwnsObjects 列表上下标赋值，释放调用方对象 |
| BIZ-R3-004 | P0 | FeatureFlags | ownership ambiguity | GetFlag 返回裸指针，所有权契约不明确，double-free 风险 |
| BIZ-R3-005 | P1 | LLM.pas | wrong error propagation | ParseResponse 覆盖 DoHttpRequest 的 False 返回值 |
| BIZ-R3-006 | P1 | LLM.Manager | cascade-delete gap | DeletePrompt 级联删除无事务，部分失败留下不一致状态 |
| BIZ-R3-007 | P1 | LLM.ImportExport | data loss | imOverwrite 先删后验，TryGetValue 返回值未检查 |
| BIZ-R3-008 | P1 | Authorization | orphan rows | DeleteRole/DeleteUser 未清理 DB 中 UserRole 关联行 |
| BIZ-R3-009 | P1 | License | exception swallowed | LoadLicenseFromDB except end 吞掉所有异常 |
| BIZ-R3-010 | P1 | License | timing side-channel | VerifySignature 长度早期退出破坏常量时间比较 |
| BIZ-R3-011 | P2 | Scheduler | use-after-free | Cleanup 可在 FOnCompleted 调用前释放已完成任务对象 |
| BIZ-R3-012 | P2 | LLM.BillingClient | retry storm | ChatWithRetry 无 jitter，1 shl (I-1) 在大 Retries 时溢出 |
| BIZ-R3-013 | P2 | LLM.BillingClient | header leak | DoStreamRequest 设置 Accept:text/event-stream 未重置，泄漏到 DoRequest |
| BIZ-R3-014 | P2 | AutoFix | wrong thread | NotifyShellShown 用 ForceQueue 在线程池执行 Run，非主线程 Halt |
| BIZ-R3-015 | P2 | MVVM | hang on shutdown | TAsyncCommand.Destroy Wait(INFINITE) 任务卡死时永久阻塞 |
| BIZ-R3-016 | P2 | Manager | async captures Self | WhenReady TTask.Run 捕获 FLogger/ACallback，FinalizeModules 释放后悬空 |
| BIZ-R3-017 | P2 | Authorization | O(n²) | GetEffectivePermissions SetLength+1 循环 + 线性去重 |
| BIZ-R3-018 | P2 | PluginManager | blocking on UI | VerifyPluginSignature WinVerifyTrust 可能网络阻塞主线程 |
| BIZ-R3-019 | P3 | LLM.ImportExport | dead config | YAML 导出已实现但导入是 stub，用户导出后无法导入 |

## 各发现详细说明

### BIZ-R3-001 [P0] — GenerateImageStream 未追踪 TTask，Self 悬空
**文件**: D:\_Progs\02Business\DeepBase\Features\DeepBase.LLM.Proxy.pas
**位置**: 第 536-565 行
`GenerateImageStream` 通过 `TTask.Run(procedure begin ... LResult := GenerateImage(APrompt, ASize); ... end)` 启动后台任务。闭包通过 `GenerateImage`（实例方法）捕获 `Self`（TProxyLLMClient）。该 ITask 既未存入字段追踪，也无析构函数等待。`TProxyLLMClient` 无 `Destroy` 重写（全文搜索确认），依赖默认 `TObject.Destroy`。如果客户端在任务执行期间被释放，`GenerateImage` 访问已释放的 `Self`。

```pascal
procedure TProxyLLMClient.GenerateImageStream(...);
begin
  TTask.Run(
    procedure
    begin
      ...
      LResult := GenerateImage(APrompt, ASize);  // 捕获 Self
      ...
    end);
end;
```
**建议**: 仿照 `ChatAsync` 的 BIZ2-001 修复模式——将 ITask 存入 `FActiveTasks` 列表，析构时 `WaitFor` 后再释放字段；或改为 static 方法快照所需字段。

### BIZ-R3-002 [P0] — Destroy 5 秒超时后释放 FLLMClient，ExecuteAsync 任务仍在调用
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.LLM.Manager.pas
**位置**: 第 740-752 行
`Destroy` 在第 743 行调用 `LT.Wait(5000)`——仅等待 5 秒。但 `ExecuteAsync` 的任务通过 `Execute` 调用 `FLLMClient.Chat`（第 1938 行），HTTP 请求可能需要 30-60 秒。5 秒超时后 `WaitFor` 返回 `wrTimeout`，`Destroy` 继续执行第 752 行 `FreeAndNil(FLLMClient)`，而任务仍在调用 `FLLMClient.Chat`——use-after-free。

```pascal
for LT in LLocalTasks do
begin
  if Assigned(LT) then
    LT.Wait(5000);  // 超时后继续释放
end;
...
FreeAndNil(FLLMClient);  // 任务可能仍在使用
```
**建议**: 在 `Wait` 前先调用 `TTask.Cancel` 通知任务中止；或增大超时至 30s+ 并在超时后记录日志但不释放正在使用的对象（推迟释放到任务完成回调中）。

### BIZ-R3-003 [P0] — SaveFlag 在 OwnsObjects 列表上下标赋值，释放调用方对象
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.FeatureFlags.pas
**位置**: 第 1426-1452 行（关键行 1439）
`SaveFlag` 调用 `Load`（第 1432 行），返回 `TObjectList<TFeatureFlag>.Create(True)`（OwnsObjects=True）。当找到匹配项时，第 1439 行执行 `LFlags[I] := AFlag`——在 OwnsObjects=True 的列表上，下标赋值会 **先释放旧对象**，然后列表接管 `AFlag` 的所有权。当 `LFlags.Free`（第 1450 行）执行时，`AFlag` 被释放。如果调用方在 `SaveFlag` 返回后继续使用 `AFlag`，就是 use-after-free。

```pascal
LFlags := Load;  // OwnsObjects=True
...
LFlags[I] := AFlag;  // 旧对象被释放，AFlag 所有权转移给列表
...
LFlags.Free;  // AFlag 在此处被释放！
```
对比：`SaveFlags`（第 1887 行）正确使用 `TObjectList.Create(False)`。`SaveFlag` 没有做同样的处理。
**建议**: 在 `SaveFlag` 中 `LFlags := Load` 后立即设 `LFlags.OwnsObjects := False`，或在循环中 clone `AFlag` 再赋值。

### BIZ-R3-004 [P0] — GetFlag 返回裸指针，所有权契约不明确
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.FeatureFlags.pas
**位置**: 第 1475-1495 行
`GetFlag` 调用 `Load`（每次创建新 `TObjectList<TFeatureFlag>.Create(True)`），找到匹配项后 `Extract` 出来返回。调用方获得一个裸 `TFeatureFlag` 指针，但方法签名 `function GetFlag(const AKey: string): TFeatureFlag` 没有任何所有权���示。如果调用方不释放——内存泄漏；如果调用方将其加入 `FFlags`（`doOwnsValues`）后又自己释放——double-free。

```pascal
Result := LFlag;
LFlags.Extract(LFlag);  // 列表不再释放此项
// 调用方获得所有权，但不知情
```
**建议**: 返回 clone（`Result := TFeatureFlag.Clone(LFlag)`），或在接口文档中明确标注"调用方拥有返回对象的所有权并须释放"。

### BIZ-R3-005 [P1] — ParseResponse 覆盖 DoHttpRequest 的 False 返回值
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.LLM.pas
**位置**: 第 824-830 行
`DoHttpRequest` 返回 `Result: Boolean`（第 678 行：`Result := (StatusCode >= 200) and (StatusCode < 300)`）。但即使返回 False，`Response` 仍包含 HTTP 错误体（第 677 行）。随后第 828/830 行 **无条件** 调用 `ParseOpenAIResponse`/`ParseAnthropicResponse` 并覆盖 `Result`。如果错误体恰好包含可解析的 JSON（某些代理在 4xx/5xx 返回带 `choices` 的 JSON），`Result` 可能被设为 `True`，掩盖 HTTP 失败。

```pascal
Result := DoHttpRequest(...);  // 可能 False
if Config.Provider = lpAnthropic then
  Result := ParseAnthropicResponse(HttpResponse, Response)  // 覆盖 False
else
  Result := ParseOpenAIResponse(HttpResponse, Response);   // 覆盖 False
```
**建议**: 仅在 `DoHttpRequest` 返回 True 时才解析：`if Result then Result := ParseOpenAIResponse(...)`。False 时直接填充错误信息。

### BIZ-R3-006 [P1] — DeletePrompt 级联删除无事务，部分失败留下不一致状态
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.LLM.Manager.pas
**位置**: 第 1497-1511 行
Round 2 修复添加了级联删除 LLMCalls → PromptMetaBinding → PromptVersions → Prompts，但四条 DELETE 语句各自独立执行，**无事务包裹**。`ILLMStorage` 接口（DeepBase.LLM.Types.pas 第 230-242 行）没有 `BeginTransaction`/`Commit`/`Rollback` 方法。如果进程在第二条 DELETE 后崩溃，PromptMetaBinding 已删但 PromptVersions 和 Prompts 仍在——数据库处于不一致状态。

```pascal
FStorage.Execute('DELETE FROM LLMCalls WHERE ...');      // 1
FStorage.Execute('DELETE FROM PromptMetaBinding WHERE ...'); // 2
FStorage.Execute('DELETE FROM PromptVersions WHERE ...');    // 3
FStorage.Execute('DELETE FROM Prompts WHERE ...');           // 4
// 任何一步失败，前面的已提交，后面的未执行
```
**建议**: 在 `ILLMStorage` 接口添加事务方法，或将四条删除合并为一条带子查询的 SQL（某些后端支持 CTE 批量删除）。

### BIZ-R3-007 [P1] — imOverwrite 先删后验，TryGetValue 返回值未检查
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.LLM.ImportExport.pas
**位置**: 第 632-655 行
注释说"Validate all required arrays exist and are parseable BEFORE any deletion"（第 632 行），但第 634-636 行的 `TryGetValue<TJSONArray>` 返回值被忽略——如果 `prompts` 键缺失或不是数组，`PromptsArray` 为 nil，但代码仍进入 `imOverwrite` 分支删除全部现有数据。验证形同虚设。

```pascal
RootObj.TryGetValue<TJSONArray>('categories', CategoriesArray);  // 返回值丢弃
RootObj.TryGetValue<TJSONArray>('meta_prompts', MetaArray);     // 返回值丢弃
RootObj.TryGetValue<TJSONArray>('prompts', PromptsArray);       // 返回值丢弃
if Mode = imOverwrite then
begin
  // 删除所有现有数据...（即使上面解析失败也照删）
```
**建议**: 检查 `TryGetValue` 返回值，任一必需数组缺失则返回错误并退出，不进入删除分支。

### BIZ-R3-008 [P1] — DeleteRole/DeleteUser 未清理 DB 中 UserRole 关联行
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.Authorization.pas
**位置**: 第 1106-1127 行（DeleteRole），第 1013-1028 行（DeleteUser）
`DeleteRole` 在内存中移除用户的角色引用（第 1117 行），然后调用 `FStorage.DeleteRole(RoleName)`（第 824 行）。但 **未调用** `FStorage.RemoveUserRole(UserId, RoleId)` 清理 DB 中的 `UserRole` 关联表。`DeleteUser` 同理——调用 `FStorage.DeleteUser` 但不清理 `UserRole` 行。存储接口有 `RemoveUserRole`（第 265 行）但仅从 `RemoveRoleFromUser`（第 1291 行）调用。

```pascal
// DeleteRole: 清理了内存，没清理 DB 的 UserRole 表
for User in FUsers.Values do
  User.RemoveRole(RoleName);  // 内存
DeleteRoleFromDatabase(RoleName);  // 只删 Role 表，不删 UserRole 表
```
**失败场景**: 删除角色 "admin" 后，DB `UserRole` 表仍保留指向已删除 RoleId 的行。若新角色复用相同 RoleId（自增列复用），用户静默获得新角色权限。
**建议**: `DeleteRole` 中遍历拥有该角色的用户，调用 `FStorage.RemoveUserRole(User.Id, Role.Id)`；`DeleteUser` 同理。

### BIZ-R3-009 [P1] — LoadLicenseFromDB except end 吞掉所有异常
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.License.pas
**位置**: 第 565-579 行
`try ... except end`（第 572-578 行）注释说"Table might not exist yet"，但实际吞掉 **所有** 异常——包括 SQL 错误、JSON 解析错误、签名验证失败、I/O 错误。被篡改或损坏的许可证与"无许可证"无法区分，管理员无法诊断应用突然变为未授权状态的原因。

```pascal
try
  StoredKey := FStorage.ReadLicenseKey;
  if StoredKey <> '' then
    FCurrentLicense := ValidateLicense(StoredKey);
except
  // Table might not exist yet  ← 吞掉一切
end;
```
**建议**: 检查表是否存在（`TableExists`），仅在表不存在时静默跳过；其他异常通过 `FLogger` 记录。

### BIZ-R3-010 [P1] — VerifySignature 长度早期退出破���常量时间比较
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.License.pas
**位置**: 第 366-385 行
注释声明"Constant-time comparison to prevent timing attacks"（第 380 行），但第 377 行 `if Length(Expected) <> Length(Signature) then Exit` 是一个早期退出，泄漏签名长度信息。攻击者可通过响应时间差异判断提交的签名长度是否正确。

```pascal
if Length(Expected) <> Length(Signature) then
  Exit;  // ← 泄漏长度信息，非常量时间
// Constant-time comparison to prevent timing attacks
Diff := 0;
for I := 1 to Length(Expected) do ...
```
**建议**: 移除长度检查，将两个字符串零填充到相同固定长度后循环比较；或至少在长度不匹配时仍执行等长循环。

### BIZ-R3-011 [P2] — Cleanup 可在 FOnCompleted 调用前释放已完成任务对象
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.Scheduler.pas
**位置**: 第 1030-1042 行
任务完成后在锁内设置 `FState := tsCompleted`、`Dec(FRunningCount)`（第 1025-1030 行），释放锁（第 1033 行），然后在锁外调用 `TaskRef.FOnCompleted(TaskRef)`（第 1038 行）。如果另一个线程在锁释放和回调调用之间调用 `Cleanup`（public 方法），`Cleanup` 获取锁、看到 `tsCompleted`、从 `FTasks` 移除并释放任务对象（`doOwnsValues`）。随后第 1038 行解引用已释放的 `TaskRef`——use-after-free。`FOnFailed` 路径（第 1080-1082 行）有相同问题。

```pascal
finally
  FLock.Leave;           // 1033: 锁释放
end;
if Assigned(TaskRef.FOnCompleted) then  // 1036: TaskRef 可能已被 Cleanup 释放
  TaskRef.FOnCompleted(TaskRef);        // 1038: use-after-free
```
**建议**: 在释放锁前捕获 `LOnCompleted := TaskRef.FOnCompleted` 和所需参数到局部变量；或延迟从 `FTasks` 移除到回调执行完毕后。

### BIZ-R3-012 [P2] — ChatWithRetry 无 jitter，1 shl (I-1) 在大 Retries 时溢出
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.LLM.BillingClient.pas
**位置**: 第 1022-1065 行
退避公式 `DelayMs := 1000 * (1 shl (I - 1))`（第 1045 行）无随机抖动（jitter）。多个客户端同时收到 429 后会同步重试，形成重试风暴。此外，当 `Retries > 31` 时 `1 shl (I-1)` 溢出 Integer（`1 shl 31` 为负值），`Sleep(负数)` 在 Windows 上被截断为 0，退避失效变为立即重试。默认 `MaxRetries=3` 不触发溢出，但用户可设更大值。

```pascal
DelayMs := 1000 * (1 shl (I - 1));  // 无 jitter；I=32 时溢出
Sleep(DelayMs);
```
**建议**: 添加 `+ Random(200)` 抖动；限制位移量 `Min(I-1, 20)` 防止溢出。

### BIZ-R3-013 [P2] — DoStreamRequest 设置 Accept:text/event-stream 未重置，泄漏到 DoRequest
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.LLM.BillingClient.pas
**位置**: 第 778 行（设置），第 459-463 行（SetupHeaders 不设 Accept）
`DoStreamRequest` 在第 778 行设置 `FHttpClient.CustomHeaders['Accept'] := 'text/event-stream'`。但 `SetupHeaders`（第 459-463 行）只设置 Authorization 和 X-Tenant-Id，不设置也不重置 Accept。流式调用后，`DoRequest` 的 `FHttpClient.Post` 仍发送 `Accept: text/event-stream`，可能导致非流式 API 返回 SSE 格式或拒绝请求。

**建议**: 在 `SetupHeaders` 中显式设置 `FHttpClient.CustomHeaders['Accept'] := 'application/json'`，或在 `DoStreamRequest` 的 `finally` 块中重置。

### BIZ-R3-014 [P2] — NotifyShellShown 用 ForceQueue 在线程池执行 Run，非主线程 Halt
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.AutoFix.pas
**位置**: 第 66-79 行
注释说"Defer scenario execution to the next message-pump turn"（第 72-73 行），暗示期望在主线程消息循环执行。但 `TThread.ForceQueue(nil, ...)`（第 74 行）的第一个参数为 nil，表示在线程池线程执行，不是主线程。`TAutoFixScenarioRunner.Run` 最终调用 `Halt`（ScenarioRunner 第 187 行），`Halt` 在非主线程调用可能导致进程清理不完整。

```pascal
// Defer scenario execution to the next message-pump turn...
TThread.ForceQueue(nil,          // nil = 线程池，非主线程
  procedure
  begin
    TAutoFixScenarioRunner.Run;  // 内部调用 Halt
  end);
```
**建议**: 改用 `TThread.Queue(nil, ...)` 将回调排队到主线程消息循环。

### BIZ-R3-015 [P2] — TAsyncCommand.Destroy Wait(INFINITE) 任务卡死时永久阻塞
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.MVVM.pas
**位置**: 第 503-510 行（Destroy），第 689-722 行（Wait）
`Destroy` 调用 `Cancel`（仅设 `FCancelled := True`，不阻塞）然后 `Wait`（默认 `INFINITE`）。如果用户代码中的 `FExecuteProc` 在阻塞调用中（如无超时的 HTTP）且不检查 `IsCancelledFunc`，`Wait(INFINITE)` 永久阻塞，应用关闭时挂起。

```pascal
destructor TAsyncCommand.Destroy;
begin
  Cancel;           // 设标志，不阻塞
  if FTask <> nil then
    Wait;            // INFINITE，可能永久阻塞
```
**建议**: 在 `Destroy` 中使用有限超时（如 5000ms），超时后记录警告日志。或额外调用 `FTask.Cancel`（PPL 级取消）。

### BIZ-R3-016 [P2] — WhenReady TTask.Run 捕获 ACallback，FinalizeModules 释放后悬空
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.Manager.pas
**位置**: 第 814-823 行
`WhenReady` 在 `FReadyFired=True` 时调用 `TTask.Run` 执行 `ACallback()`。该任务不追踪、不等待。`FinalizeModules`（第 1084 行）释放所有模块（FPluginManager、FI18n 等）。如果任务在线程池队列中等待执行，`FinalizeModules` 完成后任务运行，`ACallback` 可能解引用已释放的模块对象。`FLogger` 字段虽因 `FreeAndNil` 先设 nil 再 Free 而不会 crash（闭包看到 nil 跳过日志），但 `ACallback` 本身捕获的调用方对象不受此保护。

```pascal
TTask.Run(procedure
begin
  try
    ACallback();  // 捕获调用方 Self，可能已释放
  except
    on E: Exception do
      if Assigned(FLogger) then ...  // FLogger 可能已 nil
  end;
end);
```
**建议**: 在 `Finalize` 中等待 pending WhenReady 任务完成；或将 `ACallback` 和 `FLogger` 快照到局部变量后传入闭包。

### BIZ-R3-017 [P2] — GetEffectivePermissions O(n²) SetLength+1 循环 + 线性去重
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.Authorization.pas
**位置**: 第 869-907 行
`GetEffectivePermissions` 对每个新权限执行 `SetLength(Result, Length(Result) + 1)`（第 899 行）——每次都重新分配并复制整个数组。加上线性去重扫描（第 891-896 行），总复杂度为 O(n²)。`HasPermission`（第 1319 行）每次调用都执行此操作，在高频权限检查场景下产生性能问题。

```pascal
for I := 0 to High(Result) do    // 线性扫描去重
  if Result[I] = Perm then ...
if not Found then
begin
  SetLength(Result, Length(Result) + 1);  // O(n) 重分配
  Result[High(Result)] := Perm;
end;
```
**建议**: 使用 `TDictionary<string, Boolean>` 或 `THashSet<string>` 去重，最后一次性 `TArray.Copy` 转换为数组。

### BIZ-R3-018 [P2] — VerifyPluginSignature WinVerifyTrust 可能网络阻塞主线程
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.PluginManager.pas
**位置**: 第 1048-1091 行
`VerifyPluginSignature` 同步调用 `WinVerifyTrust`（第 1072 行），该方法可能执行证书链验证和 CRL/OCSP 网络检查。`LoadPlugin` 从 `LoadAllPlugins`（第 835 行）调用，后者从 `InitializeModules`（第 1036 行）在初始化期间（通常主线程）执行。多个插件 + 慢网络 = 启动时 UI 冻结。

**建议**: 在 `dwProvFlags` 中设置 `WTD_CACHE_ONLY_URL_RETRIEVAL` 限制为缓存撤销检查；或将插件加载移到后台线程带进度回调。

### BIZ-R3-019 [P3] — YAML 导出已实现但导入是 stub
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.LLM.ImportExport.pas
**位置**: 第 554-557 行（导出），第 401-403 行（导入）
YAML **导出**已实现（第 555 行调用 `JsonToYaml`），但 YAML **导入**是 stub（第 403 行返回错误字符串 `"YAML parsing not fully implemented. Please use JSON format."`）。用户导出为 YAML 后，无法用同一文件导入恢复数据。功能不对称。

**建议**: 集成 YAML 库实现导入；或在导出时拒绝 YAML 格式并提示"仅支持 JSON 导入"；在 UI/API 层面禁用 `efYAML` 导入选项。
