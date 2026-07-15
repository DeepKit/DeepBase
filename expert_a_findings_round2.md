# 专家 A 审阅报告: Core 基础设施（第二轮）

> 审查日期: 2026-07-06
> 审查人: 专家 A（并发与基础设施专家）
> 审查范围: Cache, Collections, Memory, EventBus, Logging, Exception, Exceptions, Benchmark, RateLimiter, Metrics, Protection, KeyManager, ObjectPool, Reflection, Crypto, DateTime, Config
> 文件总数: 17 个 .pas 文件

## 概要

本轮审查在已修改的 Core 基础设施模块中发现 **18 个新问题**（未在上一轮 INFRA-001~021 中报告），其中包括 **2 个 P0 级严重缺陷**、**4 个 P1 级高风险问题**、**5 个 P2 级中等问题**，以及 **7 个 P3 级低风险/观察项**。

关键发现：
- **P0**: `Benchmark.pas` 中 `GenerateJSON` 方法的类型混淆将导致 JSON 报告生成时 AV 崩溃
- **P0**: `Crypto.pas` 中 `TSimpleCrypto.DecryptBytes` 对旧版 CBC 数据的解密路径在 GCM 升级后损坏，导致旧版加密数据永久不可解密
- **P1**: `KeyManager.pas` 高层加密方法使用未认证的 CBC 模式，与底层 `TDataKey` 的 GCM 认证加密不一致
- **P1**: `ObjectPool.pas` 中 `TScopedPoolObject` 的双重释放漏洞

## 发现列表

| 编号 | 严重度 | 模块 | 分类 | 简述 |
|------|--------|------|------|------|
| CORE-R2-001 | **P0** | Benchmark.pas | 类型混淆/运行时崩溃 | GenerateJSON 中 TJSONObject 被强转为 TJSONArray |
| CORE-R2-002 | **P0** | Crypto.pas | 回归/数据损坏 | TSimpleCrypto.DecryptBytes 旧版 CBC 数据路径使用 GCM 模式解密 |
| CORE-R2-003 | **P1** | KeyManager.pas | 安全/设计不一致 | TKeyManager.Encrypt/Decrypt 使用未认证的 CBC，TDataKey 使用 GCM |
| CORE-R2-004 | **P1** | ObjectPool.pas | 资源管理 | TScopedPoolObject 双重释放导致 EObjectPoolException |
| CORE-R2-005 | **P1** | Protection.pas | 密钥推导安全 | DeriveAes256Key 对 GCM 路径也使用单次 SHA-256 |
| CORE-R2-006 | **P1** | Config.pas | 并发/竟态 | SetConfigInternal 锁释放/重新获取窗口可能暴露不一致状态 |
| CORE-R2-007 | **P2** | KeyManager.pas | 信息不准确 | TDataKey.GetInfo 始终报告 'AES-256-CBC' 不论实际加密模式 |
| CORE-R2-008 | **P2** | ObjectPool.pas | 异常安全 | CleanupIdleObjects 后台任务无异常处理 |
| CORE-R2-009 | **P2** | Crypto.pas | 性能 | THashUtils.HashStream 将整个流读入内存 |
| CORE-R2-010 | **P2** | EventBus.pas | 安全 | IsValidEventType 白名单在安全检查中优先于黑名单评估 |
| CORE-R2-011 | **P2** | Metrics.pas | 性能 | TSummary.Observe 清理操作 O(n²) 时间复杂度 |
| CORE-R2-012 | **P2** | Cache.pas | 内存泄漏 | FInsertOrder FIFO 队列在 Remove 和 LRU/LFU 逐出时无限增长 |
| CORE-R2-013 | **P3** | Exceptions.pas | 安全/信息泄露 | EDatabaseException.FSQL 字段未做敏感信息脱敏 |
| CORE-R2-014 | **P3** | Crypto.pas | 偏倚 | RandomString/GenerateOTP 使用模运算存在轻微偏倚 |
| CORE-R2-015 | **P3** | ObjectPool.pas | 设计 | Release 使用 O(n) 线性扫描且在锁内执行 |
| CORE-R2-016 | **P3** | DateTime.pas | 可移植性 | Winapi.Windows 出现在 interface 的 uses 子句中 |
| CORE-R2-017 | **P3** | ObjectPool.pas | 设计 | GrowthFactor 配置字段已声明但未在扩池逻辑中使用 |
| CORE-R2-018 | **P3** | Reflection.pas | 健壮性 | 对 TValue.AsType<T> 的 TryConvert/Convert 无类型安全检查 |

## 各发现详细说明

### CORE-R2-001 [P0] — Benchmark.pas GenerateJSON 类型混淆

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.Benchmark.pas`
**位置**: 第 644 行到第 669 行

生成 JSON 报告的 `TBenchmarkReport.GenerateJSON` 方法声明 `ResultsArr` 变量为 `TJSONObject` 类型（第 644 行），但随后在第 669 行通过显式类型转换将其用作 `TJSONArray`：

```pascal
var
  ResultsArr: TJSONObject;  // 声明为 TJSONObject
...
begin
  ...
  TJSONArray(ResultsArr).Add(ResultObj);  // 第 669 行：强制转换为 TJSONArray
```

Delphi 的 `TJSONObject` 和 `TJSONArray` 是不同的类，没有继承关系。这个强制转换将导致运行时 AV。影响是所有调用 `TBenchmarkReport.GenerateJSON` 的路径都会崩溃。

**建议**: 将 `ResultsArr` 的声明改为 `TJSONArray`，第 669 行的强制转换移除。

---

### CORE-R2-002 [P0] — Crypto.pas TSimpleCrypto.DecryptBytes 旧版 CBC 数据路径损坏

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.Crypto.pas`
**位置**: 第 1936 行到第 2023 行

`TSimpleCrypto.DecryptBytes` 方法在处理旧版格式（无头部格式、v1 格式）时，提取出原始密文后，在第 2019 行创建 `TAESCrypto.Create(aes256, aesGCM)` 的 GCM 模式实例，然后将旧版 CBC 原始密文传递给 `Decrypt` 方法。

问题在于 `TAESCrypto.Decrypt` 在 GCM 模式下期望的输入格式为 `Nonce(12) + CipherText + Tag(16)`（见第 1640-1655 行），而旧版数据的 `Cipher` 变量仅为原始 CBC 密文，不包含 GCM 包装结构：
- 短密文（< 28 字节）会触发 "Invalid GCM ciphertext length" 异常
- 长密文会被误解析，前 12 字节被当作 nonce、后 16 字节被当作 tag，解密失败

这是 GCM 升级引入的回归——之前用旧版格式加密的所有数据（v1 格式和无头部格式）已永久不可解密。

**建议**:
1. 对旧版数据使用 CBC 模式的 `TAESCrypto` 实例
2. 或根据数据头部正确选择解密模式

---

### CORE-R2-003 [P1] — KeyManager.pas 高层加密方法使用未认证 CBC

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.KeyManager.pas`
**位置**: 第 908 行到第 948 行

`TKeyManager.Encrypt` 和 `Decrypt` 方法使用 AES-256-CBC 模式，不提供认证（无 MAC/无 AEAD）。而底层的 `TDataKey.EncryptWith`/`DecryptWith` 已经升级到 AES-256-GCM（带认证加密，仅限 REVIEW5-CORE-005）。

这种设计不一致意味着：
- `TKeyManager.Encrypt` 生成的密文可被篡改而不被检测到
- 使用者可能认为高层 API 同样提供认证保护
- 代码注释仍写着 "AES-256-CBC" 但无 "unauthenticated" 警告

**建议**: 将 `TKeyManager.Encrypt`/`Decrypt` 也升级为 GCM 模式（带认证）；或在 API 文档中明确标注 "无认证"。

---

### CORE-R2-004 [P1] — ObjectPool.pas TScopedPoolObject 双重释放

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.ObjectPool.pas`
**位置**: 第 975 行到第 987 行

`TScopedPoolObject` 在 `Destroy` 中自动调用 `FPool.Release(FObject)` 将对象归还池中。但如果调用者在作用域结束前手动调用了 `Release`，`ScopedPoolObject` 析构时再次调用 `Release`，由于对象已被释放回空闲池，第二次 `Release` 在 `FPool` 中线性搜索不到对象，会在第 784 行抛出 `EObjectPoolException`。

风险在于：在并发场景下，一个线程可能 Acquire 到刚被释放的对象，而 ScopedPoolObject 析构时错误地将另一个线程正在使用的对象释放掉。

**建议**:
1. 在 `TScopedPoolObject` 中添加 `FReleased` 标志防止双重释放
2. 或在 `Release` 方法中将对象在 ScopedPoolObject 中的引用置 nil

---

### CORE-R2-005 [P1] — Protection.pas GCM 路径使用弱密钥派生

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.Protection.pas`
**位置**: 第 192 行到第 202 行，在第 232 行被调用

`TBasicProtection.DeriveAes256Key` 使用单次 SHA-256 从密码派生 AES-256 密钥（`THashSHA2.GetHashBytes(APassword)`）。该函数在 `EncryptGcmBytes`（第 232 行）和 `DecryptGcmBytes`（第 328 行）中被调用。

单次 SHA-256 作为密钥派生函数存在以下问题：
- 缺少盐值——同一密码始终派生相同密钥
- 缺少迭代——抵抗暴力破解/彩虹表的能力弱
- 与此形成对比的是 `DeepBase.Crypto.pas` 中的 `TPasswordUtils.PBKDF2` 和 `TAESCrypto.SetKeyFromPassword`，它们都使用 PBKDF2

**建议**:
- `TBasicProtection` 的 GCM 路径应使用 PBKDF2 派生密钥，与 Crypto 模块保持一致
- 添加随机盐值并随密文存储

---

### CORE-R2-006 [P1] — Config.pas SetConfigInternal 锁释放/重新获取窗口

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.Config.pas`
**位置**: 第 271 行到第 306 行

`SetConfigInternal` 方法在第 299-303 行临时释放调用者持有的锁以执行回调，然后重新获取：

```pascal
TMonitor.Exit(FLock);  // 释放锁
try
  CallbackRef(Self, Key, OldValue, NewValue);  // 回调执行时锁已释放
finally
  TMonitor.Enter(FLock);  // 重新获取
end;
```

虽然这解决了回调时持锁造成的阻塞问题（BASIC-027），但存在两个问题：
1. 在锁释放窗口内，其他线程可以读取到配置的中间状态（旧值已被覆盖写入存储但新值尚未完全生效）
2. 回调执行期间其他线程写入同一配置键可能造成写写冲突

**建议**: 在锁释放前完成所有写入操作，或使用更为严格的版本号/时间戳冲突检测。

---

### CORE-R2-007 [P2] — KeyManager.pas TDataKey.GetInfo 算法信息不准确

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.KeyManager.pas`
**位置**: 第 549 行到第 560 行

`TDataKey.GetInfo` 方法在第 558 行始终返回 `Algorithm := 'AES-256-CBC'`，但实际加密在 `EncryptWith`（第 479-497 行）中已使用 AES-256-GCM（版本字节 `$01` 标记 GCM 格式）。字段值不反映实际加密模式，可能误导审计或兼容性判断。

**建议**: 根据 `FEncryptedKeyData[0]` 版本字节返回实际使用的算法名称。

---

### CORE-R2-008 [P2] — ObjectPool.pas 后台清理任务无异常处理

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.ObjectPool.pas`
**位置**: 第 514 行到第 528 行

`TObjectPool<T>.Initialize` 使用 `TTask.Create` 创建后台清理任务。`CleanupIdleObjects` 方法内部没有 try/except 包裹。如果 `CleanupIdleObjects` 抛出异常（例如由于锁竞争失败或列表状态不一致），该异常将被 TTask 运行时吞没，清理循环终止且不被发现。

**建议**: 在 `CleanupIdleObjects` 调用周围添加 try/except，记录异常并继续循环。

---

### CORE-R2-009 [P2] — Crypto.pas HashStream 内存耗尽风险

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.Crypto.pas`
**位置**: 第 694 行到第 709 行

`THashUtils.HashStream` 方法将整个流读入内存：

```pascal
SetLength(LBytes, AStream.Size);
if AStream.Size > 0 then
  AStream.ReadBuffer(LBytes[0], AStream.Size);
Result := HashBytes(LBytes, AAlgorithm);
```

对于大文件（如数百 MB 的日志或备份），这将导致大量内存分配。System.Hash 的 `THashSHA2` 支持基于流/增量的哈希操作，无需整文件加载。

**建议**: 使用 `THashSHA2.GetHashString(AStream)` 等支持流式哈希的 API，或使用增量 Update 方式。

---

### CORE-R2-010 [P2] — EventBus.pas IsValidEventType 白名单覆盖黑名单

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.EventBus.pas`
**位置**: 第 1201 行到第 1257 行

根据前一轮摘要中提到的问题：如果类型名称以 'TSystem' 开头且同时包含 'exec'，白名单先匹配（返回 True）导致黑名单检查永远不会触发。这是一个安全检查逻辑顺序错误。白名单豁免后不应该再被黑名单拦截，但当前设计意图应该是先白名单放行常规类型，再用黑名单拦截危险类型——但白名单的实现过于宽泛。

**建议**: 重写类型安全检查逻辑，使用允许列表（allowlist）模式替代黑名单+白名单的组合。

---

### CORE-R2-011 [P2] — Metrics.pas TSummary.Observe O(n²) 清理

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.Metrics.pas`
**位置**: 第 1096 行到第 1108 行

`TSummary.Observe` 方法中，有 `FValues.Delete(0)` 的调用在 O(n) 的 `TList<Double>.Delete` 上操作。如果 `FMaxSamples` 检查和 modulo-1000 的周期清理都使用 `Delete(0)`，而且两者同时存在，那么每次调用都会删除前部元素，导致总体复杂度为 O(n²)。

**建议**: 使用 `TQueue<Double>` 或环形缓冲区替代 `TList<Double>` + Delete(0)，或使用 `DeleteRange` 批量删除前移元素。

---

### CORE-R2-012 [P2] — Cache.pas FInsertOrder FIFO 队列无限增长

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.Cache.pas`
**位置**: 第 477 行（FInsertOrder.Enqueue），以及 Remove 方法

`TCache<K,V>.Put` 方法在第 477 行调用 `FInsertOrder.Enqueue(Key)` 追踪插入顺序。但只有当逐出策略为 FIFO 时，`Evict` 方法才调用 `FInsertOrder.Dequeue`。当策略为 LRU、LFU 或 TTL 时，Remove 操作不清理 `FInsertOrder`。这导致 `FInsertOrder` 队列持续增长，包含大量已经被移除或逐出的键。

**建议**:
1. `Remove()` 方法应该从 `FInsertOrder` 删除键（但 TQueue<T> 不支持随机删除）
2. 或者改用支持删除的 `TDoublyLinkedList` 结构
3. 或者在非 FIFO 策略下不维护 `FInsertOrder`

---

### CORE-R2-013 [P3] — Exceptions.pas EDatabaseException.FSQL 敏感信息

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.Exceptions.pas`
**位置**: 第 94 行到第 102 行

`EDatabaseException` 在 `FSQL` 字段中存储完整的 SQL 语句。虽然当前 ToString 不包含 SQL 内容，但该字段通过 `property SQL: string read FSQL;` 公开可访问。在没有访问控制的情况下，未经脱敏的 SQL 可能包含敏感信息（表名、列名、业务逻辑结构）。

**建议**: 对 SQL 属性添加访问审计，或提供可选的脱敏方法。

---

### CORE-R2-014 [P3] — Crypto.pas RandomString/GenerateOTP 模偏倚

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.Crypto.pas`
**位置**: 第 1043 行到第 1054 行（RandomString），第 1114 行到第 1124 行（GenerateOTP）

`RandomString` 使用 `LBytes[I-1] mod Length(Chars)`（Len=62，256 mod 62 = 8，值 0~7 略高频次），`GenerateOTP` 使用 `mod 10`（256 mod 10 = 6，值 0~5 略高频次）。虽然偏倚较小，但对于安全敏感场景（OTP、令牌）不理想。`RandomInt` 方法已正确使用拒绝采样消除偏倚，但 `RandomString` 和 `GenerateOTP` 未采用此方式。

**建议**: 对安全敏感场景使用拒绝采样消除偏倚，或使用 `SecureToken` 方法替代。

---

### CORE-R2-015 [P3] — ObjectPool.pas Release 线性扫描竞争

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.ObjectPool.pas`
**位置**: 第 730 行到第 784 行

`Release` 和 `Discard` 方法使用线性扫描（O(n)）在池中查找对象，且扫描期间持有锁。对于大池，这可能导致调用者阻塞时间过长。

**建议**: 使用对象引用字典（TDictionary<Pointer, TPooledObject<T>>）实现 O(1) 查找，避免全池扫描。

---

### CORE-R2-016 [P3] — DateTime.pas 非 Windows 平台不可编译

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.DateTime.pas`
**位置**: 第 22 行

```pascal
uses
  System.SysUtils, System.Classes, System.DateUtils, System.TimeSpan,
  System.Generics.Collections, System.SyncObjs, Winapi.Windows;
```

`Winapi.Windows` 出现在 `interface` 的 `uses` 子句中，没有 `{$IFDEF MSWINDOWS}` 守卫。这使得整个单元在 Linux/macOS 上无法编译。单元中的 `TTimeZones`、`TDateTimeFormat.FromUnixTime` 等方法使用了 `TTimeZone.Local` 等跨平台 API，不应依赖 Windows 单元。

**建议**: 将 `Winapi.Windows` 移到 `implementation` 部分并添加 `{$IFDEF MSWINDOWS}` 守卫。

---

### CORE-R2-017 [P3] — ObjectPool.pas GrowthFactor 未被使用

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.ObjectPool.pas`
**位置**: 第 115 行（声明），第 446 行到第 455 行（Default 实现）

`TPoolConfig.GrowthFactor` 字段已声明和默认赋值（2.0），但在 `TObjectPool<T>.TryAcquire` 方法中，当池满时直接等待而非按 GrowthFactor 扩展。该配置字段无实际效果。

**建议**: 在池满时应用 GrowthFactor 逻辑（如创建 `Min(Growth * CurrentSize, MaxSize)` 个新对象），或移除未使用的字段。

---

### CORE-R2-018 [P3] — Reflection.pas TValueConverter 无类型安全检查

**文件**: `D:\_Progs\02Business\DeepBase\Core\DeepBase.Reflection.pas`
**位置**: 第 1629 行到第 1642 行

`TValueConverter.Convert<T>` 和 `TryConvert<T>` 直接调用 `AValue.AsType<T>`，如果 TValue 不能转换为目标类型将抛出异常。`TryConvert` 捕获异常将其转为布尔返回值，这是一种效率较低的模式。

**建议**: 使用 `TValue.TryAsType<T>`（如果 Delphi 版本支持），或在转换前进行类型兼容性检查。

---

## 良好实践记录

1. **ObjectPool.pas 双检锁模式正确**：`TPoolManager.Instance` 使用正确的双检锁模式，外层 `if not Assigned` 配合内层锁内再次检查。

2. **Benchmark.pas RandomInt 拒绝采样**：`TRandomGenerator.RandomInt` 正确实现拒绝采样消除模偏倚，是 `RandomString` 和 `GenerateOTP` 的正确模式的参考。

3. **KeyManager.pas TDataKey 敏感数据清零**：`TDataKey.Destroy` 和 `TMasterKey.ClearKey` 在释放前用 `FillChar` 清零密钥数据，符合安全编码规范。

4. **Benchmark.pas TBenchmarkStats 统计数据计算正确**：均值、标准差、百分位数的计算逻辑正确，修正了可能的累积浮点误差。

5. **Events Bus ISubscription 接口引用计数管理正确**：调用者持有 ISubscription 接口引用确保订阅生命周期正确管理，TComponent 所有者清理机制提供了额外的安全保障。

## 综合评估

**整体评估**: Core 基础设施层代码质量较高，大部分并发路径有正确的锁保护，资源管理基本遵守 try/finally 模式。关键问题集中在：

1. **GCM 升级引入的回归**（CORE-R2-002）—— 旧版加密数据无法解密是最高优先级修复项。
2. **Benchmark.pas 类型混淆**（CORE-R2-001）—— 一个明显的编译/代码审查遗漏，任何 JSON 报告生成都会崩溃。
3. **安全一致性**（CORE-R2-003, CORE-R2-005）—— CBC 与 GCM 的混用需要统一。
4. **并发边界**（CORE-R2-006, CORE-R2-010）—— 锁释放窗口和安全检查顺序需要审查。

### 严重度分布

| 严重度 | 数量 | 占比 |
|--------|------|------|
| P0（严重） | 2 | 11% |
| P1（高） | 4 | 22% |
| P2（中） | 6 | 33% |
| P3（低） | 6 | 33% |
| **总计** | **18** | **100%** |

### 按模块分布

| 模块 | 发现数 | 关键问题 |
|------|--------|----------|
| Crypto.pas | 3 | GCM 回归、模偏倚、内存读取 |
| ObjectPool.pas | 4 | 双重释放、无异常处理、线性扫描、未启用特性 |
| KeyManager.pas | 2 | CBC vs GCM 不一致、算法标签错误 |
| Benchmark.pas | 1 | 类型混淆 AV |
| Protection.pas | 1 | 弱密钥派生 |
| Config.pas | 1 | 锁释放窗口 |
| EventBus.pas | 1 | 安全检查顺序 |
| Metrics.pas | 1 | O(n²) 性能 |
| Cache.pas | 1 | FIFO 队列增长 |
| Exceptions.pas | 1 | 敏感信息 |
| DateTime.pas | 1 | 平台依赖 |
| Reflection.pas | 1 | 类型转换健壮性 |
