# 专家 E 审阅报告: Features 商业化/浏览器/推理/语音/集成（第三轮）

> 审查日期: 2026-07-08
> 审查范围: Commerce (Service, Storage, Idempotency, Backend.Http, SafeClient, SDKGateway, PaymentBridge, Adapter.Supabase, Permissions, UpgradeFlow, JsonUtil, Types), Browser (Engine.WebView2, Session, ResponseWaiter, Selectors, ScriptStore, WindowPool, PageDriver, BrowserAutomation), Speech (ASR.SenseVoice, ASR.Baidu, ASR.SAPI, TTS.StepFun, Voiceprint, Intent.LLMBackend), Integration (HttpServer, Net.Transport.ICS, CloudBackup, AntiTamper, UIA.Engine, UIA.Types, Licensing), VCL/FMX dirs, .dpk files
> 文件总数: 28+

## 概要

8 new issues: 1 P0 / 2 P1 / 3 P2 / 2 P3.

- UIA.Engine.pas 在最近编辑中引入了 uses 子句缺失逗号，导致编译阻断——这是最高优先级。
- WebView2 的四个 Async 方法返回 TTask 但析构函数不等待未完成任务，是 UI2-002 的相邻实例（Browser 侧而非 VCL/FMX 侧）。
- CloudBackup 的密钥派生使用无盐单次 SHA-256，且未校验 HTTPS，两个问题叠加使备份加密与 API key 传输均有风险。

## 发现列表

| 编号 | 严重度 | 模块 | 分类 | 简述 |
|------|--------|------|------|------|
| FEAT-R3-001 | P0 | UIA.Engine | 编译阻断 | uses 子句缺失逗号导致无法编译 |
| FEAT-R3-002 | P1 | Browser.Engine.WebView2 | 线程安全/悬空引用 | NavigateAsync 等 4 个 Async 方法的 TTask 在析构中不等待 |
| FEAT-R3-003 | P1 | CloudBackup | 弱密钥派生 | DeriveKeyAndIV 使用无盐单次 SHA-256 派生加密密钥 |
| FEAT-R3-004 | P2 | UIA.Engine | 功能缺陷 | UIA_ProcessIdPropertyId 常量值错误 (34005 vs 30002) |
| FEAT-R3-005 | P2 | Commerce.SafeClient | 重试/限流 | 无 429/5xx 重试与退避逻辑 |
| FEAT-R3-006 | P2 | CloudBackup | 传输安全 | 未校验 HTTPS，API key 可能明文传输 |
| FEAT-R3-007 | P3 | AntiTamper | 硬编码盐 | 默认 salt 为固定字符串 |
| FEAT-R3-008 | P3 | Speech.TTS.StepFun | 无效空检查 | nil as TJSONArray 永不返回 nil，空检查为死代码 |

## 各发现详细说明

### FEAT-R3-001 [P0] — UIA.Engine uses 子句缺失逗号，编译阻断
**文件**: D:\_Progs\02Business\DeepBase\Features\DeepBase.UIA.Engine.pas
**位置**: 第 16-17 行

最近一次 git diff（`HEAD` → 工作区）将第 16 行从
```
  DeepBase.Types, DeepBase.Exceptions, DeepBase.Logging, DeepBase.Crypto,
```
改为
```
  DeepBase.Types, DeepBase.Exceptions, DeepBase.Logging, DeepBase.Crypto, DeepBase.Crypto.Hash
  DeepBase.UIA.Types,
```
`DeepBase.Crypto.Hash` 后面缺少逗号，下一行直接是 `DeepBase.UIA.Types`。Delphi 编译器会报 "Missing operator or semicolon" 或 "Undeclared identifier"，整个单元无法编译，任何 uses 它的工程都会连锁失败。

**修复**: 在 `DeepBase.Crypto.Hash` 后补逗号：
```pascal
  DeepBase.Types, DeepBase.Exceptions, DeepBase.Logging, DeepBase.Crypto, DeepBase.Crypto.Hash,
  DeepBase.UIA.Types,
```

---

### FEAT-R3-002 [P1] — WebView2 Async 方法 TTask 悬空引用（UI2-002 相邻实例）
**文件**: D:\_Progs\02Business\DeepBase\Features\DeepBase.Browser.Engine.WebView2.pas
**位置**: 第 824-899 行（NavigateAsync / ExecuteScriptAsync / EvaluateScriptAsync / CaptureScreenshotAsync），析构函数第 287-314 行

四个 Async 方法均返回 `TTask.Run(LProc)`，其中 `LProc` 捕获了 `Self`（TWebView2BrowserSession 实例），并调用 `Self.Navigate`、`Self.ExecuteScript`、`Self.EvaluateScript`、`Self.CaptureScreenshot`——全部访问实例字段（FBrowser、FNavigationEvent、FScreenshotStream 等）。

析构函数 `Destroy`（第 287-314 行）释放了 FBrowser、FScreenshotStream、FNavigationEvent 等，但没有任何机制等待未完成的 TTask。如果调用者拿到 `ITask` 后不显式 `WaitFor` 就释放 Session，后台任务会在已释放的对象上执行，导致 AV 或内存损坏。

```pascal
// 第 830-840 行
LProc :=
  procedure
  var LError: string; LSuccess: Boolean;
  begin
    LSuccess := Navigate(AUrl, ATimeoutMs, LError);  // 访问 Self.FBrowser
    ...
  end;
Result := TTask.Run(LProc);  // 返回给调用者，析构不等待

// 第 287-314 行析构——无 FAsyncTasks 列表，无 WaitFor
```

**修复建议**: 在类中维护 `FAsyncTasks: TList<ITask>`，每次 `TTask.Run` 后加入列表；析构中先 `TTask.WaitFor` 所有未完成任务再释放底层资源。或在 Async 方法中用 `TInterfacedObject` 保活 + 取消令牌。

---

### FEAT-R3-003 [P1] — CloudBackup DeriveKeyAndIV 使用无盐单次 SHA-256
**文件**: D:\_Progs\02Business\DeepBase\Features\DeepBase.CloudBackup.pas
**位置**: 第 1242-1257 行

```pascal
procedure TBackupEncryptor.DeriveKeyAndIV(const APassword: string);
begin
  // 使用SHA-256生成密钥（实际应使用PBKDF2）
  LHash := THashSHA2.GetHashBytes(APassword);
  Move(LHash[0], FKey[0], 32);
  // 用另一个哈希生成IV
  LHash := THashSHA2.GetHashBytes(APassword + 'IV');
  Move(LHash[0], FIV[0], 16);
end;
```

密码仅经一次 SHA-256（无 salt、无迭代、无 PBKDF2/Argon2）直接作为 AES-256 密钥。攻击者获取加密备份文件后，可用 GPU 每秒尝试数十亿密码，普通用户密码会在分钟内被破解。代码注释自己也承认"实际应使用PBKDF2"。IV 从 `password + 'IV'` 派生，同一密码永远产生相同 IV，进一步削弱语义安全。

**修复建议**: 改用 `TPasswordUtils.PBKDF2(APassword, ASalt, 100000, 32, haSHA256)`，salt 随机生成并存储于备份文件头；IV 每次随机生成并写入文件头。

---

### FEAT-R3-004 [P2] — UIA_ProcessIdPropertyId 常量值错误
**文件**: D:\_Progs\02Business\DeepBase\Features\DeepBase.UIA.Engine.pas
**位置**: 第 28 行

```pascal
UIA_ProcessIdPropertyId    = 30005 + 4000; // 近似值 — 实际为 30010
```

`30005 + 4000 = 34005`。根据 Microsoft UIAutomation 规范，`UIA_ProcessIdPropertyId = 30002`。注释自己说"实际为 30010"——这也不对，官方值为 30002。使用错误的属性 ID 调用 `GetCurrentPropertyValue(34005)` 会返回空值或报错，导致按进程 ID 定位 UIA 元素的功能完全失效。

**修复建议**: 改为 `UIA_ProcessIdPropertyId = 30002;`

---

### FEAT-R3-005 [P2] — Commerce.SafeClient 无 429/5xx 重试与退避
**文件**: D:\_Progs\02Business\DeepBase\Features\DeepBase.Commerce.SafeClient.pas
**位置**: 第 503-543 行（SendJson）

`SendJson` 仅在 `StatusCode = 401` 时重试（刷新 token 后重发），对 429（Too Many Requests）和 5xx（服务端临时错误）不做任何重试或退避，直接将错误返回调用者。

对于支付/订单类操作，服务器短暂限流时直接失败会导致用户体验中断。标准做法是：对 429 遵守 `Retry-After` 头，对 5xx 使用指数退避重试（仅对幂等请求或带 idempotency key 的请求）。

**修复建议**: 在 `SendJson` 中增加 `MaxRetries`（默认 3），429 时解析 `Retry-After` 头并 `Sleep`；5xx 时指数退避（如 500ms、1s、2s）；仅对 `AIdempotencyKey <> ''` 或 GET/HEAD 重试。

---

### FEAT-R3-006 [P2] — CloudBackup 未校验 HTTPS，API key 可能明文传输
**文件**: D:\_Progs\02Business\DeepBase\Features\DeepBase.CloudBackup.pas
**位置**: 第 1363-1394 行（DoRequest）

```pascal
LURL := FServiceURL + AEndpoint;
...
LDefaultHeaders[0] := TNameValuePair.Create('X-API-Key', FApiKey);
```

`FServiceURL` 由构造函数传入（第 1347 行），不做 scheme 校验。如果配置为 `http://` 而非 `https://`，API key 会在明文 HTTP 中传输，中间人可截获。`THTTPClient` 默认不阻止 HTTP。

**修复建议**: 在构造函数或 `DoRequest` 入口校验 `FServiceURL.StartsWith('https://', True)`，否则 raise。

---

### FEAT-R3-007 [P3] — AntiTamper 默认 salt 为硬编码固定字符串
**文件**: D:\_Progs\02Business\DeepBase\Features\DeepBase.AntiTamper.pas
**位置**: 第 106 行

```pascal
Result.Salt := 'DeepMoveC_Default_Salt_2025';
```

`GetDefaultConfig` 提供硬编码默认 salt。虽然 `EncryptionKey` 已改为空（第 100 行，必须用户配置），但如果用户配置了自定义 key 却未覆盖 salt，PBKDF2 会使用已知 salt 派生密钥。攻击者可针对该 salt + 常见密码预计算彩虹表，降低暴力破解成本。

**修复建议**: `Salt` 默认设为空，在 `Initialize` 中校验若 `Salt = ''` 则 raise；或每次随机生成 salt 并持久化到配置中。

---

### FEAT-R3-008 [P3] — StepFun FetchSystemVoices 中 nil as TJSONArray 的空检查为死代码
**文件**: D:\_Progs\02Business\DeepBase\Features\DeepBase.Speech.TTS.StepFun.pas
**位置**: 第 172-173 行

```pascal
JSONArr := (JSONVal as TJSONObject).GetValue('voices') as TJSONArray;
if JSONArr = nil then Exit;
```

`GetValue('voices')` 在键不存在时返回 `nil`。`nil as TJSONArray` 会触发 `EInvalidCast`（`as` 对 `nil` 源操作数的行为是抛异常，不是返回 `nil`）。因此第 173 行的 `if JSONArr = nil then Exit` 永远不会执行——它是死代码。当 `voices` 键缺失时，异常会被第 206 行的外层 `try/except` 捕获，`FLastError` 会被设置为包含 `EInvalidCast` 信息的字符串，而非"voices 字段缺失"这样的清晰错误。

`FetchClonedVoices`（第 226-230 行）有相同模式。

**修复建议**: 改用 `is` 检查：
```pascal
var LVoices := (JSONVal as TJSONObject).GetValue('voices');
if not (LVoices is TJSONArray) then Exit;
JSONArr := LVoices as TJSONArray;
```
