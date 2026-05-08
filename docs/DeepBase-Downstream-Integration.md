# DeepBase 下游集成指南

> 更新日期: 2026-05-07
> 对接基线: RC 候�?> 目标: 给下�?Delphi 工程、网页测评包、小程序后端提供一份可立即执行的接入指南�?> 当前状�? P0/P1/P2 框架阻塞项已清空；LLM �?SQLite+PostgreSQL 统一适配层仍在并行优化，相关模块�?facade/API 对接，不在下游侧自行改底层适配层�?
---

## 1. 下游先按这个顺序�?
1. 只接基础框架: [DeepBaseCore.dpk](../DeepBaseCore.dpk) + [DeepBasePersistence.dpk](../DeepBasePersistence.dpk)�?2. 需�?IoC/EventBus/Scheduler/Resilience 时加 [DeepBaseServices.dpk](../DeepBaseServices.dpk)�?3. 需�?Speech/ASR、Commerce、LLM、AutoUpdate、AntiTamper 时加 [DeepBaseFeatures.dpk](../DeepBaseFeatures.dpk)�?4. VCL 工程�?[DeepBaseVCL.dpk](../DeepBaseVCL.dpk)；FMX 工程�?[DeepBaseFMX.dpk](../DeepBaseFMX.dpk)�?5. 设计期控件只�?IDE 安装时加 [dclDeepBaseVCL.dpk](../dclDeepBaseVCL.dpk) / [dclDeepBaseFMX.dpk](../dclDeepBaseFMX.dpk)，不要放进运行时依赖�?
推荐包顺�?

```text
DeepBaseCore
DeepBaseServices
DeepBasePersistence
DeepBaseFeatures
DeepBaseVCL / DeepBaseFMX
dclDeepBaseVCL / dclDeepBaseFMX
```

---

## 2. 初始化方�?
### 2.1 推荐: root.txt + ConfigDB

EXE 目录�?`root.txt`，第一行写项目根目录绝对路�?

```text
D:\Apps\MyTool
```

运行时会定位:

```text
D:\Apps\MyTool\MyToolConfig.db
```

Delphi 入口:

```delphi
uses
  DeepBase.Manager,
  DeepBase.Persistence.Manager.FireDAC;

begin
  DeepBase.InitializeOrRaise;
end;
```

`DeepBase.Persistence.Manager.FireDAC` 必须�?uses 或链接进包里，它会注�?Manager �?FireDAC SQLite 连接适配器和 storage factory。缺少它时初始化会失败，并提�?`No DB connection adapter registered`�?
### 2.2 测试或自定义路径: InitializeWithDB

Boolean 模式:

```delphi
var
  ErrorMsg: string;
begin
  if not DeepBase.InitializeWithDB('D:\Apps\MyTool\MyToolConfig.db') then
    raise Exception.Create(DeepBase.LastError);
end;
```

异常模式:

```delphi
begin
  DeepBase.InitializeWithDBOrRaise('D:\Apps\MyTool\MyToolConfig.db');
end;
```

规则:

| 入口 | 失败行为 | 适合场景 |
|------|----------|----------|
| `InitializeEx(out ErrorMsg)` | 返回 `False`，写�?`LastError` / `InitErrorCode` | 需要自己展示错�?UI |
| `InitializeWithDB(DBPath)` | 返回 `False`，写�?`LastError` / `InitErrorCode` | 单测、自定义配置库路�?|
| `InitializeOrRaise` | �?`EInitializationException` | 标准应用启动 |
| `InitializeWithDBOrRaise(DBPath)` | �?`EInitializationException` | 测试、工具、服务进�?|

异常中包�?

- `ErrorCode`
- `Context`，例�?`DeepBase.Manager.InitializeWithDB`
- 保留底层失败原因�?message

---

## 3. 数据库边�?
| 数据�?| 位置 | 用�?| 下游禁止做的�?|
|--------|------|------|----------------|
| DB1 ConfigDB | 本地 SQLite | DeepBase 配置、日志、i18n、FormState、MRU、Hotkeys、Theme、Secrets、AboutFrame、LLM 本地配置/调用历史 | 不放生产用户、订单、支付流�?|
| DB2 本地业务�?| 本地 SQLite | 单机业务数据、缓存、离线数�?| 不放支付密钥 |
| DB3 远程业务�?| PostgreSQL/MySQL/其他 | 多端共享业务数据 | 不绕过统一 DB/DoQry/Repository 约束 |
| DB4 生产后端�?| 后端数据�?| 用户、身份、商品、订单、支付、权益、通知原文 | 客户端不直连 |

Schema:

- 当前 DB1 schema: `1.0.0`
- 最低兼�?schema: `0.3`
- Manager 初始化会自动创建/补齐核心表和兼容列�?
---

## 4. 基础能力最小接�?
```delphi
uses
  DeepBase.Manager,
  DeepBase.Persistence.Manager.FireDAC;

begin
  DeepBase.InitializeOrRaise;

  DeepBase.Config.SetConfig('App.Language', 'zh-CN');
  DeepBase.Logger.Info('App started', 'MyTool');

  Caption := DeepBase.I18n.T('Main.Title', 'My Tool');
  DeepBase.FormState.RestoreFormState(Self);
end;
```

关闭�?

```delphi
begin
  DeepBase.Finalize;
end;
```

---

## 5. Security / Secret

敏感信息不要�?Settings 明文，统一�?Security:

```delphi
DeepBase.Security.SaveSecret('LLM.Default.ApiKey', ApiKey);
ApiKey := DeepBase.Security.LoadSecret('LLM.Default.ApiKey');
```

规则:

- Windows: DPAPI 用户作用域�?- macOS/Linux: UBS2 格式，AES-256-GCM + PBKDF2-SHA256�?- UBS2 当前写出 v1，解密端已按版本分发，未知版本会提示升级或迁移�?- LLM API Key 只保存引用或密文，不写明文�?
---

## 6. Resilience / RuntimeContext

可直接使用兼容门�?

```delphi
uses DeepBase.Resilience;

Retry := TRetryPolicy.Create
  .MaxRetries(3)
  .ExponentialBackoff(100, 2.0, 5000)
  .MainThreadWaitMode(rmwRaise);
```

规则:

- UI 主线程内不要同步 sleep/retry�?- UI 场景优先使用 `ExecuteAsync` / `ExecuteAsync<T>`�?- `DeepBase.Resilience` 已拆成子单元，但下游仍继�?`uses DeepBase.Resilience`，不需要改 import�?- RuntimeContext 默认组件已注�?Manager、IoC、EventBus、Scheduler、WorkerQueue；启�?停止生命周期�?RuntimeContext 管�?
---

## 7. LLM 对接边界

当前 LLM �?SQLite+PostgreSQL 统一适配层仍在并行优化。下游现在可以做:

- 使用 `DeepBase.LLM.*` facade/API 对接调用层�?- 使用 DB1 �?LLM 配置表存配置和调用历史�?- 使用 `DeepBase.Security.SaveSecret/LoadSecret` �?Credential Manager 引用保存 API key�?
下游暂时不要�?

- 不要�?`Core/DeepBase.LLM*.pas`�?- 不要�?SQLite/PostgreSQL 统一适配层实现�?- 不要复制旧版 LLM 表结构到业务库�?- 不要�?UI 线程同步调用长耗时 LLM 请求�?
待统一适配层合并后，下游只需重新编译并跑当前检查清单�?

### 7.1 五模型槽和生图

下游 LLM 配置面板统一按 5 个槽位做，不要自行发明新的 tier 名称：

| 槽位 | tier 常量 | 典型用途 |
|------|-----------|----------|
| 聪明 | `TierSmart` / `smart` | 高质量推理、复杂任务 |
| 平衡 | `TierBalanced` / `balanced` | 默认聊天和常规处理 |
| 快速 | `TierFast` / `fast` | 低延迟、轻量任务 |
| 生图 | `TierImageGen` / `image_gen` | 文生图 |
| 图片兜底 | `TierImageFallback` / `vision_fallback` | 视觉失败后的低成本兜底 |

`TLLMConfigStore.BuiltInTiers` 会返回上述 5 个槽位顺序；`NormalizeTier`/`LoadTierModelsJson` 会把旧配置里的 `vision` 自动迁移到 `image_gen`。如果只是文本聊天，`IsConfigured` 检查前三个文本槽；如果要作为完整桌面产品发布，应使用 `IsFullyConfigured` 检查 5 个槽位。

```delphi
uses
  DeepBase.LLM.Config,
  DeepBase.LLM.Types;

Store.SetTierModels(string(TierSmart), ['gpt-4.1']);
Store.SetTierModels(string(TierBalanced), ['gpt-4.1-mini']);
Store.SetTierModels(string(TierFast), ['gpt-4.1-nano']);
Store.SetTierModels(string(TierImageGen), ['gpt-image-1']);
Store.SetTierModels(string(TierImageFallback), ['gpt-4.1-mini']);
```

生图调用走 `ILLMClient.GenerateImage` / `TLLMService.GenerateImage`，返回 `TImageGenerationResult`，支持 OpenAI-compatible `/images/generations` 响应里的 `b64_json` 或 `url`。流式/异步生图和更完整 provider fallback 仍是后续强化项。

---

## 8. Speech / ASR 接入

语音识别基础模块已放�?[DeepBaseFeatures.dpk](../DeepBaseFeatures.dpk)，下游不要复�?DeepInput 的语音代码�?
核心单元:

| 单元 | 用�?|
|------|------|
| `DeepBase.Speech.Types` | 音频数据、识别结果、Provider 接口 |
| `DeepBase.Speech.Audio.WinMM` | Windows 麦克风录�?|
| `DeepBase.Speech.VAD` | 静音自动停止 |
| `DeepBase.Speech.ASR.Baidu` | 百度在线语音识别 |
| `DeepBase.Speech.Service` | 录音 + VAD + Provider 编排 |

最小接�?

```delphi
uses
  DeepBase.Manager,
  DeepBase.Security,
  DeepBase.Speech.ASR.Baidu,
  DeepBase.Speech.Service,
  DeepBase.Speech.Types;

var
  Speech: TDeepBaseSpeechService;
  Rec: TSpeechRecognitionResult;
begin
  Speech := TDeepBaseSpeechService.CreateBaidu(
    TSpeechBaiduConfig.Create(
      DeepBase.Security.LoadSecret('Speech.Baidu.ApiKey'),
      DeepBase.Security.LoadSecret('Speech.Baidu.SecretKey')));
  try
    if Speech.StartRecording then
    begin
      Rec := Speech.StopAndRecognize;
      if Rec.Success then
        ShowMessage(Rec.Text);
    end;
  finally
    Speech.Free;
  end;
end;
```

规则:

- 百度 `ApiKey/SecretKey` �?`DeepBase.Security.SaveSecret/LoadSecret` 保存，不�?INI 明文�?- UI 按钮、全局热键、浮动条、文本注入仍由下游应用自己处理�?- `StopAndRecognize` 可能访问网络，UI 应放�?`TTask.Run` �?WorkerQueue�?- 本地 Whisper �?DeepInput 的旧兼容路径，当前不作为 DeepBase 基础 Provider�?

### 8.1 ASR 权限和配额

如果语音识别属于付费能力，必须把 `TDeepBaseSpeechService` 接到 `DeepBase.Commerce.Permissions`。默认 feature code 是 `speech.asr`，识别前会调用 `RequireFeature`，识别成功后会调用 `ConsumeQuota`。

```delphi
uses
  DeepBase.Commerce.Permissions,
  DeepBase.Speech.Service;

Speech.PermissionClient := Permissions;
Speech.PermissionFeatureCode := 'speech.asr';
Result := Speech.StopAndRecognize;
```

如果工程已经使用 `TDeepBaseDesktopLifecycle`，可直接复用生命周期 facade 中的 permission client：

```delphi
Speech.PermissionClient := Lifecycle.GetPermissionClient;
Speech.PermissionFeatureCode := 'speech.asr';
```

未配置 `PermissionClient` 时保持旧行为，适合纯本地免费语音或测试场景。生产在线 ASR 不建议裸跑，避免未授权用户无限消耗服务端 ASR 成本。

---

## 9. Network / Transport 接入

统一网络传输入口：

| 单元 | 用途 |
|------|------|
| `DeepBase.Net.Transport` | 统一 HTTP transport 接口和 `System.Net.HttpClient` 默认实现 |
| `DeepBase.Net.Transport.ICS` | ICS 可选 adapter 入口；未启用 ICS 编译时会明确报错 |

当前已支持通过统一 transport 注入：

- Commerce: `TCommerceBackendUnifiedTransport`
- Speech/Baidu ASR: `TSpeechUnifiedHttpTransport`

示例：

```delphi
uses
  DeepBase.Net.Transport,
  DeepBase.Commerce.Backend.Http;

var
  Net: IDeepBaseHttpTransport;
  CommerceTransport: ICommerceBackendHttpTransport;
begin
  Net := TDeepBaseSystemNetTransport.Create;
  CommerceTransport := TCommerceBackendUnifiedTransport.Create(Net);
end;
```

ICS 说明：

- ICS 是传统 Delphi 项目的可选兼容层，不是 deepBase Core 的硬依赖。
- 未定义 `DEEPBASE_HAS_ICS` 并接入 Overbyte ICS 单元时，`TDeepBaseIcsHttpTransport.Create` 会 fail-fast。
- 下游默认使用 `TDeepBaseSystemNetTransport`，需要 ICS 时再单独启用。

---

## 10. Commerce 接入

涉及登录、购买、订阅、权益时，生产数据必须走后端:

1. `EnsureUserForIdentity`
2. `CreateOrder`
3. `BeginPayment`
4. 后端支付通知验签
5. `ConfirmPayment`
6. 发放 entitlement
7. 客户端查�?`HasEntitlement` / `ConsumeEntitlement`

`TCommerceHttpStorage` 是 server-admin storage adapter，默认禁止写订单、支付和权益。桌面端不要直接用它跑完整收费流程；服务器侧确需通过 HTTP storage 写后端时必须使用 `CreateServerAdmin`。

桌面端请使用 `TDeepKitSafeClient`（`Features/DeepBase.Commerce.SafeClient.pas`）调用 `/dk` 安全 API，不要用 storage adapter 做管理写操作。`TDeepKitSafeClient` 已封装：

- `AuthLoginDeviceAnonymous` / `AuthRefresh` / `AuthMe`
- `CreateOrder` / `GetOrder` / `CreatePaymentIntent`
- `ListEntitlements` / `ConsumeEntitlement`
- `IssueLicenseSnapshot` / `RefreshLicenseSnapshot`
- `GetUpdatesManifest`

最小示例：

```delphi
uses
  DeepBase.Commerce.SafeClient;

var
  Client: TDeepKitSafeClient;
  Session: TDeepKitAuthSession;
begin
  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.com'));
  try
    Session := Client.AuthLoginDeviceAnonymous('deepbase_desktop', '{device_id}');
    // Session.AccessToken 已自动写回 client，后续请求直接复用
  finally
    Client.Free;
  end;
end;
```

开发期可用:

```delphi
Storage := TInMemoryCommerceStorage.Create;
```

服务器侧管理存储:

```delphi
Storage := TCommerceHttpStorage.Create(
  TCommerceBackendHttpConfig.CreateServerAdmin(
    'https://api.example.com',
    '<bearer-token-or-empty>',
    '<api-key-or-empty>'));

// server-admin only
Storage.RefundOrder('ord_001', 3900, 'customer_request');
Storage.RevokeEntitlement('ent_001', 'risk_control');
Storage.RevokeLicenseSnapshot('deepbase_desktop', '{device_id}', 'snap_001', 'refund');
```

支付网关:

```delphi
Commerce.RegisterPaymentGateway(
  cppWeChatPay,
  TCommerceHttpPaymentGateway.Create(
    TCommerceBackendHttpConfig.Create(
      'https://api.example.com',
      '<bearer-token-or-empty>',
      '<api-key-or-empty>')));
```

生产禁止:

- 客户端直�?DB4�?- 客户端保存支付密钥�?- 客户端把订单直接改成 paid�?- 生产使用 `TInMemoryCommerceStorage`�?
- Supabase/Firebase/PaymentBridge 适配器默认是 server-only/prototype，桌面生产端禁止直连；仅服务器调试或迁移期可通过 `CreateServerOnly` 或环境变量 `DEEPBASE_ALLOW_PROTOTYPE_COMMERCE_ADAPTERS=1` 显式开启
后端契约�?[Commerce-Backend-Adapter-Spec.md](Commerce-Backend-Adapter-Spec.md)�?

### 10.1 付费升级和权限控制

桌面工具型产品推荐优先接 `DeepBase.Desktop.Lifecycle`，不要在业务窗体里分散拼登录、授权、付费升级和更新逻辑。它已经把 DeepKit 安全客户端、权限 facade、付费升级 facade、Updater token 注入串起来。

```delphi
uses
  DeepBase.Commerce.SafeClient,
  DeepBase.Desktop.Lifecycle,
  DeepBase.VCL.DesktopLifecycle; // FMX 使用 DeepBase.FMX.DesktopLifecycle

var
  Client: TDeepKitSafeClient;
  Lifecycle: TDeepBaseDesktopLifecycle;
  Config: TDeepBaseDesktopLifecycleConfig;
begin
  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.com', ''));
  Config := TDeepBaseDesktopLifecycleConfig.Create(
    'deepbase_desktop', DeviceId, '1.0.0', 'https://api.example.com/dk', 'stable');
  Lifecycle := TDeepBaseDesktopLifecycle.Create(Config, Client, True);

  Lifecycle.LoginDeviceAnonymous;
  TDeepBaseVCLDesktopLifecycleHelper.RefreshLicenseStatus(
    Lifecycle, lblLicense, 'pro_full');
  TDeepBaseVCLDesktopLifecycleHelper.ApplyFeatureGate(
    Lifecycle, btnPaidFeature, 'speech.asr', btnUpgrade);
end;
```

VCL/FMX helper 已提供这些标准动作：

- GUI 测试窗体固定位置：`Left=100, Top=300`，避免挡住其它程序。
- 授权状态标签刷新：免费/已授权/检查失败。
- 付费功能灰显和升级按钮显示。
- 免费版到收费版升级：创建订单、创建支付意图、打开系统浏览器。
- 自动更新检查：通过生命周期 facade 让 updater 携带 app_id、device_id、access_token。

桌面端免费版升级到收费版不要直接拼 API。使用 `DeepBase.Commerce.UpgradeFlow` 串联标准流程：

1. `ListProducts` 获取当前 app 可购买 SKU。
2. `StartPaidUpgrade` 创建订单并向服务器申请支付意图。
3. 客户端用系统浏览器打开 `PaymentIntent.PayUrl`。
4. 支付完成后用 `CheckEntitlement` 轮询权益。
5. 权益生效后 `RefreshLicenseSnapshot` 刷新本地授权快照。
6. `GetUpdateManifest` 获取免费/Pro/企业通道对应更新。

```delphi
uses
  DeepBase.Commerce.SafeClient,
  DeepBase.Commerce.UpgradeFlow,
  DeepBase.Commerce.Types;

var
  Client: TDeepKitSafeClient;
  Flow: TDeepKitUpgradeFlowClient;
  Upgrade: TDeepKitUpgradeStartResult;
begin
  Client := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.com', AccessToken));
  Flow := TDeepKitUpgradeFlowClient.Create(Client, 'deepbase_desktop', UserId, DeviceId, True);
  try
    Upgrade := Flow.StartPaidUpgrade('pro_monthly', cppWeChatPay, cpcH5, '', 'upgrade-req-001');
    // Open Upgrade.PaymentIntent.PayUrl in the system browser, then poll CheckEntitlement('pro_full', ...)
  finally
    Flow.Free;
  end;
end;
```

付费功能入口统一用 `DeepBase.Commerce.Permissions` 检查：

- `HasFeature` 用于 UI 灰显和提示升级。
- `RequireFeature` 用于进入付费功能前强制拦截。
- `ConsumeQuota` 用于 ASR、LLM、生图等按量能力扣减。
- `RefreshLicenseSnapshot` 用于在线同步授权快照。

---

## 11. Examples 和门�?
下游可参考这些必选示�?

| 示例 | 用�?|
|------|------|
| `Examples/Phase0Demo` | 最小初始化 |
| `Examples/Phase1Demo` | VCL 基础控件 |
| `Examples/FullDemo` | 综合 VCL 场景 |
| `Examples/FMXDemo` | FMX 平台能力 |
| `Examples/CommerceE2EDemo` | Commerce 端到端流�?|

本地检�?

```powershell
Scripts\build_examples_win64.ps1
cmd /c compile_test.bat
Scripts\run_tests.ps1 -Type Unit -Run Test.DeepBase.Manager
Scripts\run_tests.ps1 -Type Unit -Run Test.DeepBase.Speech
```

---

## 12. 下游封版前检查清�?
- [ ] 引用�?`DeepBase.Persistence.Manager.FireDAC`，Manager 能注册连接适配器�?- [ ] 使用 `InitializeOrRaise` �?`InitializeWithDBOrRaise`，启动失败能显示具体原因�?- [ ] DB1 只放框架配置和本地状态�?- [ ] DB4 只通过后端 HTTP API 访问�?- [ ] Secret/API Key 没有明文写入 Settings、日志或业务表�?- [ ] UI 线程没有同步重试、同�?LLM 请求或长时间阻塞�?- [ ] Speech/ASR 不复�?DeepInput 旧代码，统一使用 `DeepBase.Speech.*`�?- [ ] Speech/ASR 在线识别放后台线程，百度密钥�?`DeepBase.Security`�?- [ ] Commerce 生产环境不用内存存储�?- [ ] LLM �?SQLite+PostgreSQL 统一适配层没有在下游私自改动�?- [ ] `Scripts\build_examples_win64.ps1` 通过�?- [ ] [compile_test.bat](../compile_test.bat) 通过�?
---

## 13. 发给下游的最小包

只发这些文档即可:

1. [DeepBase-Integration-OneFile.md](DeepBase-Integration-OneFile.md)
2. [DeepBase-Downstream-Integration.md](DeepBase-Downstream-Integration.md)
3. [Commerce-Backend-Adapter-Spec.md](Commerce-Backend-Adapter-Spec.md)

如只允许发一份，�?[DeepBase-Integration-OneFile.md](DeepBase-Integration-OneFile.md)�?
