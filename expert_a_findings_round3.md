# 专家 A 审阅报告: Core 安全/加密与并发基础设施（第三轮）

> 审查日期: 2026-07-08
> 审查范围: DeepBase.Protection.pas, DeepBase.Security.pas, DeepBase.Authorization.pas, DeepBase.Services.Crypto.pas, DeepBase.Crypto.PBKDF2.pas, DeepBase.Crypto.RSA.pas, DeepBase.Crypto.AES.pas, DeepBase.Crypto.pas, DeepBase.Crypto.Random.pas, DeepBase.Config.pas, DeepBase.ObjectPool.pas, DeepBase.Cache.pas, DeepBase.EventBus.pas, DeepBase.RateLimiter.pas, DeepBase.Resilience.CircuitBreaker.pas, DeepBase.Memory.pas, DeepBase.Collections.pas, DeepBase.Metrics.pas, DeepBase.Services.Protection.pas
> 文件总数: 19

## 概要

本第三轮审查发现 11 个新问题: 2 P0, 5 P1, 3 P2, 1 P3。主要发现:
- Authorization 管理器在锁外返回字典拥有的对象引用，`DeleteUser`/`DeleteRole` 并发执行会释放这些对象，造成 use-after-free（P0）
- Cache 的 `Evict` 在 `Put` 释放锁后执行，与并发 `Put`/`TryGet`/`Cleanup` 在 `FEntries`/`FAccessOrder`/`FStats` 上竞态，可导致 AV 或统计错误（P0）
- 多处加密代码（Protection、Security UBS2、RSA 私钥解析）将派生密钥/机器密钥/明文/RSA 私钥分量留在堆上未清零（P1）
- ObjectPool 的 `FindAvailableObject` 在 for 循环中删除元素后 `Continue`，跳过下一个被移位的元素（P2）
- Metrics 的 `TTimer.Start` 闭包捕获裸 `Self`，timer 被释放后调用闭包为 use-after-free（P1）

## 发现列表

| 编号 | 严重度 | 模块 | 分类 | 简述 |
|------|--------|------|------|------|
| CORE-R3-001 | P0 | DeepBase.Authorization.pas | use-after-free | GetUser/GetRole/GetAllUsers/GetAllRoles 返回字典拥有的对象，锁外可被 DeleteUser/DeleteRole 释放 |
| CORE-R3-002 | P0 | DeepBase.Cache.pas | 竞态/数据损坏 | Put 释放锁后调用 Evict，Evict 及其子方法未重新加锁，与并发 Put/TryGet/Cleanup 竞态 FEntries/FAccessOrder/FStats |
| CORE-R3-003 | P1 | DeepBase.Protection.pas | 密钥材料未清零 | DeriveAes256KeyPBKDF2 未清零 LPasswordBytes（UTF-8 密码字节），留在堆上 |
| CORE-R3-004 | P1 | DeepBase.Security.pas | 密钥材料未清零 | DecryptUBS2V1 与 ProtectStringDpapi(非 Win 路径) 的 MachineKey/Key/Plaintext 未清零 |
| CORE-R3-005 | P1 | DeepBase.Crypto.RSA.pas | 密钥材料未清零 | LoadPrivateKeyPEM 的 LDER/LModulus/LPrivateExponent/LPrime1/LPrime2/LImportBlob 等私钥分量未清零 |
| CORE-R3-006 | P1 | DeepBase.Metrics.pas | use-after-free | TTimer.Start 返回的闭包捕获裸 Self，timer 被释放后调用闭包解引用已释放对象 |
| CORE-R3-007 | P1 | DeepBase.Authorization.pas | 竞态/TOCTOU | SetCurrentUserWithToken 在锁外经 GetUser 访问 TUser，且在锁外写 LastLoginAt，与 DeleteUser/UpdateUser 竞态 |
| CORE-R3-008 | P2 | DeepBase.ObjectPool.pas | 逻辑错误 | FindAvailableObject 在 for 循环内 FPool.Delete(I)+Continue，跳过被移位到 I 的下一个对象 |
| CORE-R3-009 | P2 | DeepBase.Collections.pas | 输入校验缺失 | TCountingSet.Add 接受负 ACount，使 FTotalCount 与单项计数变负，破坏 MostCommon/Remove 一致性 |
| CORE-R3-010 | P2 | DeepBase.Collections.pas | 锁内回调/重入 | TLRUCache.Evict 持锁调用 FOnEvict，重入 Put/Evict 在半更新链表上操作可致 AV 或错误 LRU 顺序 |
| CORE-R3-011 | P3 | DeepBase.Resilience.CircuitBreaker.pas | 锁内慢回调 | SetState 持 FLock 调用 FOnStateChanged，慢回调阻塞所有 AllowRequest/Execute |

## 各发现详细说明

### CORE-R3-001 [P0] — GetUser/GetRole 返回字典拥有的对象，锁外可被并发删除释放
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.Authorization.pas
**位置**: 第 990-999 行（GetUser）、1083-1092 行（GetRole）、1040-1058 行（GetAllUsers）、1139-1157 行（GetAllRoles），以及第 450 行 CurrentUser 属性

`FUsers`/`FRoles` 是 `TObjectDictionary<..., [doOwnsValues]>`（第 676-678 行），字典在 `Remove` 时会 `Free` 值对象。`GetUser` 在 `FLock` 内取出 `TUser` 引用作为 `Result` 返回，离开锁后调用方持裸引用；若另一线程此时调用 `DeleteUser(Username)`（第 1013-1028 行，`FUsers.Remove(Username)` 会释放该 `TUser`），调用方即持有悬垂引用，后续访问触发 AV。`GetRole`/`GetAllRoles`/`GetAllUsers` 同构。`CurrentUser` 属性经 `GetCurrentUserForThread`（第 1426-1435 行）返回的 `TUser` 同样是 `FUsers` 拥有的同一实例，故 `DeleteUser(当前线程用户)` 会让 `CurrentUser` 指向已释放对象。场景：线程 A `LUser := AuthManager.GetUser('admin');` → 线程 B `AuthManager.DeleteUser('admin');` → 线程 A 访问 `LUser.Username` → AV。

```pascal
function TAuthorizationManager.GetUser(const Username: string): TUser;
begin
  FLock.Enter;
  try
    if not FUsers.TryGetValue(Username, Result) then  // Result 指向 FUsers 拥有的对象
      Result := nil;
  finally
    FLock.Leave;   // 锁已释放，但 Result 仍指向可被 DeleteUser 释放的对象
  end;
end;
```
**建议**: 改为返回不可变快照（值/记录副本）或引入引用计数（让 `TUser`/`TRole` 实现 interface 并返回 interface，字典不再 doOwnsValues，改由管理器在销毁时显式释放），或要求调用方在持锁范围内使用对象。当前“返回裸引用+锁外使用”的 API 与 `doOwnsValues` 语义根本冲突。

### CORE-R3-002 [P0] — Cache 的 Evict 在 Put 释放锁后无锁执行，与并发操作竞态
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.Cache.pas
**位置**: 第 455-528 行（Put 释放锁调 Evict）、702-836 行（Evict/EvictLRU/.../RemoveExpired，注释称“Called within lock”但不获取锁）

`Put` 在检测到需要驱逐时执行 `FLock.Leave; try Evict(1); finally FLock.Enter; end;`（约 457-465 行），目的是让 `FOnEvict` 回调在锁外触发以避免重入。但 `Evict` 及 `EvictLRU`/`EvictLFU`/`EvictFIFO`/`EvictRandom`/`RemoveExpired` 的自身注释都写明“Called within lock”，它们并不重新获取 `FLock`，却在遍历并修改 `FEntries`、`FAccessOrder`、`FInsertOrder`、`FStats`。此时另一线程可进入 `Put`/`TryGet`/`Remove`/`Cleanup` 同时修改这些结构。`cepTTL` 路径最严重：`RemoveExpired` 遍历 `FEntries` 时，另一 `Put` 在做 `FEntries.AddOrSetValue` + `UpdateAccessOrder`（`FAccessOrder.IndexOf`+`Delete`+`Add`）。后果：字典/链表内部损坏致 AV、驱逐了刚加入的键、`FStats.TotalSizeBytes` 被多次扣减。场景：高并发写 + TTL 策略 + 容量接近上限 → 间歇性 AV 或缓存大小统计为负。

```pascal
// Put, 约 457-465:
if NeedsEviction then
begin
  FLock.Leave;          // 锁释放
  try
    Evict(1);           // Evict 及其子方法均不重新加锁
  finally
    FLock.Enter;
  end;
end;
```
**建议**: 在锁内完成所有 `FEntries`/`FAccessOrder`/`FStats` 的读取与修改，将被驱逐的 `(Key, Entry)` 对收集到局部列表，然后 `FLock.Leave` 后再触发 `FOnEvict`/`FOnExpire` 回调。这样既保留“回调在锁外”的重入安全目标，又不暴露内部数据结构给并发修改。

### CORE-R3-003 [P1] — DeriveAes256KeyPBKDF2 未清零 UTF-8 密码字节
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.Protection.pas
**位置**: 第 701-751 行（特别是第 717 行 LPasswordBytes、第 746-750 行只清零 LBlock/LUTemp）

`DeriveAes256KeyPBKDF2` 在第 717 行 `LPasswordBytes := TEncoding.UTF8.GetBytes(APassword)` 获取密码的 UTF-8 字节，第 746-750 行只对中间 `LBlock`/`LUTemp` 调 `FillChar(...,0)`，却未清零 `LPasswordBytes` 与 `LSaltPlusBlock`。`LPasswordBytes` 是用户密码的明文字节，是最高敏感材料；函数返回后这些字节留在堆上直到该内存被重新分配。场景：进程被内存转储或攻击者读取堆残留 → 密码泄漏。注意同单元 `Security.pas` 提供了 `SecureZeroMemory`/`SecureClearBytes`，但此处未用。

```pascal
LPasswordBytes := TEncoding.UTF8.GetBytes(APassword);   // 第 717 行，密码明文字节
...
// 第 746-750 行只清零 LBlock/LUTemp：
if Length(LBlock) > 0 then FillChar(LBlock[0], Length(LBlock), 0);
if Length(LUTemp) > 0 then FillChar(LUTemp[0], Length(LUTemp), 0);
// LPasswordBytes 从未被清零
```
**建议**: 在 finally/末尾对 `LPasswordBytes` 与 `LSaltPlusBlock` 调 `SecureZeroMemory`（或 `FillChar(...,0)` 后 `SetLength(...,0)`）。同样审查 `DeriveAes256Key`（第 218 行）的 `Result` 是否需要由调用方清零。

### CORE-R3-004 [P1] — Security UBS2 解密/加密路径未清零 MachineKey/Key/Plaintext
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.Security.pas
**位置**: 第 398-451 行（DecryptUBS2V1）、第 496-562 行（ProtectStringDpapi 非 Windows 路径）

`DecryptUBS2V1` 声明 `MachineKey, Salt, IV, Key, Ciphertext, Tag, Plaintext: TBytes`（第 400 行），其中 `MachineKey`（来自 `GetMachineEntropy`，可能含 `DeepBase_MASTER_KEY` 环境变量）、`Key`（PBKDF2 派生密钥）、`Plaintext`（解密后的明文机密）均为高敏感材料，但函数返回前未对其清零，残留于堆。`ProtectStringDpapi` 的 macOS/Linux 路径（第 498 行声明同样的局部 TBytes）同样未清零 `MachineKey`/`Key`/`Plaintext`。场景：进程内存转储或 core dump → 主密钥/机器熵/明文机密泄漏，绕过 DPAPI/UBS2 保护。本单元已实现 `SecureClearBytes`（第 249 行）却未在自身加密路径使用。

```pascal
// DecryptUBS2V1, 第 444-450 行：
MachineKey := GetMachineEntropy;                                   // 机器熵/主密钥
Key := OpenSSL_PBKDF2_SHA256(MachineKey, Salt, Iterations, UBS2_KEY_SIZE);  // 派生密钥
Plaintext := OpenSSL_AES256GCM_Decrypt(Key, IV, Ciphertext, nil, Tag);        // 明文机密
Result := TEncoding.UTF8.GetString(Plaintext);
// 函数结束，MachineKey/Key/Plaintext 均未清零
```
**建议**: 在 `DecryptUBS2V1` 与 `ProtectStringDpapi`(非 Win) 末尾对 `MachineKey`、`Key`、`Plaintext`（及派生过程中的中间 TBytes）调 `SecureClearBytes`。

### CORE-R3-005 [P1] — RSA LoadPrivateKeyPEM 未清零私钥分量与 DER/Blob
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.Crypto.RSA.pas
**位置**: 第 523-653 行（特别是第 578 行 LDER、606 行 LImportBlob、588-595 行各私钥分量）

`LoadPrivateKeyPEM` 解析 PKCS#1 RSA 私钥，得到 `LModulus`、`LExponent`、`LPrivateExponent`(d)、`LPrime1`(p)、`LPrime2`(q)、`LExponent1`(dp)、`LExponent2`(dq)、`LCoefficient`(qInv)，以及完整的 `LDER`（第 578 行，含整私钥的 PKCS#1 DER）和 `LImportBlob`（第 606 行，BCRYPT_RSAFULLPRIVATE_BLOB）。这些局部 TBytes 在函数返回前均未清零，私钥分量以明文残留于堆。析构函数确实清零了 `FPrivateKeyBlob`（第 468-472 行），但 `FPrivateKeyBlob` 只是 `LImportBlob` 的副本，原始分量仍在堆上。场景：内存转储 → RSA 私钥（p, q, d）泄漏 → 可解密所有用对应公钥加密的数据、可伪造签名。

```pascal
LModulus := ReadASN1Integer(LDER, LPos);          // n, 第 588 行
LPrivateExponent := ReadASN1Integer(LDER, LPos);  // d, 第 590 行
LPrime1 := ReadASN1Integer(LDER, LPos);           // p, 第 591 行
LPrime2 := ReadASN1Integer(LDER, LPos);           // q, 第 592 行
...
// 第 647 行：FPrivateKeyBlob := Copy(LImportBlob);
// finally 仅释放句柄，LDER/LModulus/LPrivateExponent/LPrime1/LPrime2/LImportBlob 未清零
```
**建议**: 在 `finally` 块中对 `LDER`、`LImportBlob` 及所有私钥分量（`LPrivateExponent`/`LPrime1`/`LPrime2`/`LExponent1`/`LExponent2`/`LCoefficient`）调用 `FillChar(X[0], Length(X), 0)`（长度>0 时）。公钥分量 `LModulus`/`LExponent` 非敏感可不处理，但统一清零更稳妥。

### CORE-R3-006 [P1] — TTimer.Start 闭包捕获裸 Self，timer 释放后调用为 use-after-free
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.Metrics.pas
**位置**: 第 974-997 行

`TTimer.Start` 返回一个 `TProc`，闭包捕获 `Self`（`TTimer` 实例）并在被调用时执行 `Self.RecordDuration(...)`/`Self.FLock.Enter`。`TTimer` 作为 `IMetric` 由 `TMetricsRegistry.FMetrics` 持有，当 registry 被销毁或 `Unregister`/`Clear` 调用时 `TTimer` 即被释放。若调用方存储了返回的闭包（或 `TMetrics.StartTimer` 返回的 `IScopedTimer`），在 registry/timer 释放后再调用闭包，即解引用已释放内存 → AV。场景：非单例 `TMetricsRegistry` 在测试或按请求创建，`Timer('x').Start` 的闭包存于字段，registry 释放后再调用闭包 → use-after-free。

```pascal
Result := procedure
begin
  Self.RecordDuration(SecondSpan(LStartTime, Now));   // Self 可能已被释放
  Self.FLock.Enter;
  ...
end;
```
**建议**: 让 `TTimer` 实现一个内部 interface 并在闭包中捕获该 interface（`TTimer` 已是 `IMetric`，可直接捕获 `IMetric(Self)` 并在闭包内判 nil），或由 `TMetricsRegistry` 跟踪未完成的 timer 并在销毁前等待/置 nil；至少在文档中强制闭包不得超出 registry 生命周期并加运行时检测。

### CORE-R3-007 [P1] — SetCurrentUserWithToken 锁外访问/修改 TUser，与删除/更新竞态
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.Authorization.pas
**位置**: 第 1475-1516 行

`SetCurrentUserWithToken` 调用 `GetUser(AUsername)`（第 1492、1508 行）取得 `TUser` 后，在 `FLock` 之外访问 `LUser.GetMetadata('token')`（第 1495 行）并写 `LUser.LastLoginAt := Now`（第 1512 行）。`GetUser` 内部加锁取出引用后即释放锁，故这些访问均无锁保护。若此时另一线程调用 `DeleteUser(AUsername)`（释放该 `TUser`）或 `UpdateUser`/`SetMetadata`（并发修改同一对象），则读 `GetMetadata` 可能读到半更新状态或 AV（对象已释放），写 `LastLoginAt` 与并发 `SaveUserToDatabase` 竞态可丢失更新。这是 CORE-R3-001 的具体触发路径之一。场景：用户登录（`SetCurrentUserWithToken`）与管理员删除该用户并发 → AV 或 token 比较读到脏数据。

```pascal
LUser := GetUser(AUsername);           // 第 1492 行，锁已释放
if LUser = nil then Exit(False);
LStoredToken := LUser.GetMetadata('token');   // 第 1495 行，锁外访问
...
LUser := GetUser(AUsername);           // 第 1508 行，再次锁外取引用
if LUser = nil then Exit(False);
LUser.LastLoginAt := Now;              // 第 1512 行，锁外写对象字段
SetCurrentUserForThread(LUser);
```
**建议**: 将 token 校验与 `LastLoginAt` 更新整体放入 `FLock` 内执行（在锁内 `TryGetValue` 取 `TUser` 并完成所有读写），再在锁外触发审计日志；`SetCurrentUserForThread` 已自带锁可继续在锁外调用。根治仍需解决 CORE-R3-001 的对象所有权/生命周期问题。

### CORE-R3-008 [P2] — ObjectPool.FindAvailableObject 在 for 循环中删除元素后跳过下一个
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.ObjectPool.pas
**位置**: 第 594-629 行

`FindAvailableObject` 用 `for I := 0 to FPool.Count - 1 do` 扫描池，当 `ValidationOnAcquire` 失败时执行 `DestroyPooledObject(LPooled); FPool.Delete(I); Continue;`。`FPool.Delete(I)` 后，原 `I+1` 处的元素移位到 `I`，但 for 循环会 `Inc(I)`，于是移位到 `I` 的元素被跳过。场景：池 = [无效(inUse=false), 有效(空闲), 有效(空闲)]，`ValidationOnAcquire=True`；删除索引 0 的无效对象后，有效的对象移到索引 0，但循环转到索引 1，`FindAvailableObject` 返回 nil（调用方可能新建对象或超时），尽管索引 0 就有有效空闲对象。连续多个无效对象时会跳过多个有效对象。

```pascal
for I := 0 to FPool.Count - 1 do
begin
  LPooled := FPool[I];
  if not LPooled.InUse then
  begin
    if FConfig.ValidationOnAcquire then
    begin
      LValid := FFactory.ValidateObject(LPooled.Obj);
      if not LValid then
      begin
        DestroyPooledObject(LPooled);
        FPool.Delete(I);   // 下一元素移位到 I
        Continue;          // 循环 Inc(I) → 跳过移位到 I 的元素
      end;
    end;
    ...
```
**建议**: 改为 `while I < FPool.Count do`，仅在未删除时 `Inc(I)`；或倒序遍历 `for I := FPool.Count - 1 downto 0`（但会改变获取顺序，故 while 更稳妥）。

### CORE-R3-009 [P2] — TCountingSet.Add 接受负 ACount，破坏 FTotalCount 与单项计数一致性
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.Collections.pas
**位置**: 第 1661-1675 行

`Add(AItem, ACount)` 无下界校验，`Add(x, -5)` 会执行 `FCounts[x] := LCurrent + (-5)`（可能为负）并 `Inc(FTotalCount, -5)`，使 `FTotalCount` 变负、`CountOf` 返回负数。`Remove` 的 `if LCurrent <= ACount` 判断在计数被污染后会错误删除键（如计数=2，`Remove(x,5)` 删除键却只扣减 FTotalCount 2），`MostCommon` 的 `B.Value - A.Value` 为有符号减法，负计数扭曲排序。场景：上游误传负数（如 `Add(item, Delta)` 而 `Delta` 来自外部计算）→ 统计数据全面失真。

```pascal
procedure TCountingSet<T>.Add(const AItem: T; ACount: Integer);
...
  if FCounts.TryGetValue(AItem, LCurrent) then
    FCounts[AItem] := LCurrent + ACount   // ACount 可为负
  else
    FCounts.Add(AItem, ACount);
  Inc(FTotalCount, ACount);               // FTotalCount 可为负
```
**建议**: 在方法开头 `if ACount < 0 then raise ECollectionException.Create('ACount must be non-negative')`（或视语义将负值视为 0）；`Remove` 同样应校验 `ACount`。

### CORE-R3-010 [P2] — TLRUCache.Evict 持锁调用 FOnEvict，重入 Put/Evict 可损坏链表
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.Collections.pas
**位置**: 第 720-735 行（Evict），由第 741-761 行 Put 在容量满时持锁调用

`TLRUCache.Put` 持 `FLock` 调 `Evict`；`Evict` 在 `FMap.Remove`、`UnlinkNode` 之后、`Node.Free` 之前调用 `FOnEvict(Node.Key, Node.Value)`（第 731 行），全程处于锁内。Delphi `TCriticalSection` 可重入，故不致死锁，但若回调重入缓存（如驱逐回调中再 `Put`/`Get`/`Remove` 另一键——这是驱逐回调的常见用途，例如持久化被驱逐值时查另一缓存），则在半更新的 `FMap`/`FHead`/`FTail` 链表上操作；传给回调的 `Node` 已从 `FMap` 摘除且已 unlink，回调返回后立即 `Node.Free`（第 733 行）。重入的 `Put` 还可能触发嵌套 `Evict`，在半更新链表上操作 → AV 或 LRU 顺序错乱。场景：驱逐回调内调用 `Cache.Get(relatedKey)` → 重入操作正在驱逐的链表 → AV。

```pascal
procedure TLRUCache<K,V>.Evict;
begin
  if FHead <> nil then
  begin
    Node := FHead;
    FMap.Remove(Node.Key);
    UnlinkNode(Node);
    if Assigned(FOnEvict) then
      FOnEvict(Node.Key, Node.Value);   // 持锁；重入 Put/Evict 损坏链表
    Node.Free;
  end;
end;
```
**建议**: 将 `(Node.Key, Node.Value)` 复制到局部变量，完成所有 `FMap`/链表修改与 `Node.Free`，释放 `FLock` 后再触发 `FOnEvict`（批量驱逐时先将被驱逐对收集到局部列表，锁外统一触发）。

### CORE-R3-011 [P3] — CircuitBreaker.SetState 持锁调用 FOnStateChanged，慢回调阻塞所有操作
**文件**: D:\_Progs\02Business\DeepBase\Core\DeepBase.Resilience.CircuitBreaker.pas
**位置**: 第 214-227 行（SetState），由 AllowRequest/RecordSuccess/RecordFailure 在持锁时调用

`SetState` 在 `FLock` 内执行 `FState := NewState` 并调用 `FOnStateChanged(FName, OldState, NewState)`（第 225 行）。所有调用方（`CheckHalfOpenTransition`、`RecordSuccess`、`RecordFailure`）都在 `FLock.Enter/Leave` 内调用 `SetState`。可重入锁不死锁，但若回调较慢（日志落盘、发事件、I/O），会阻塞所有其他线程对该熔断器的 `AllowRequest`/`Execute`/`RecordSuccess`，在频繁状态切换的高负载下将熔断器串行化。场景：Open↔HalfOpen 频繁切换 + 慢日志回调 → 熔断器成为吞吐瓶颈。

```pascal
procedure TCircuitBreaker.SetState(NewState: TCircuitState);
begin
  if FState <> NewState then
  begin
    OldState := FState;
    FState := NewState;
    FLastStateChange := Now;
    if Assigned(FOnStateChanged) then
      FOnStateChanged(FName, OldState, NewState);   // 持 FLock
  end;
end;
```
**建议**: 将 `(OldState, NewState)` 存入局部变量，在锁内完成 `FState`/`FLastStateChange` 切换，释放 `FLock` 后再触发 `FOnStateChanged`。

---

**补充说明**: EventBus.pas 与 RateLimiter.pas 经审查未发现新问题（EventBus 在触发处理程序前快照订阅列表并隔离每处理程序异常；RateLimiter 清理路径受 `CLEANUP_THRESHOLD` 约束并释放拥有的 `TList<TDateTime>` 值）。Config.pas 的 `SetConfigInternal` 竞到端修复（第 266-302 行）经核实无新引入问题。Crypto.AES.pas 在析构中正确清零 `FKey`/`FIV`（第 188、191 行）。
