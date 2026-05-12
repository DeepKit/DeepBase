# DeepBase 对外集成唯一入口

> 版本: 1.1
> 更新日期: 2026-05-07
> 定位: 下游工程 / AI / 第三方接�?DeepBase 的唯一入口文件
> 发布状�? RC 候选。P0/P1/P2 框架阻塞项已清空；正式封版前等待 LLM �?SQLite+PostgreSQL 统一适配层合并后再跑全量门禁�?> 规则: 如果只能给下游或 AI 一份文档，就发本文件�?
---

## 1. 一句话定义

DeepBase �?Delphi 桌面应用基础框架，提供配置、日志、国际化、窗体状态、Security、IoC、EventBus、Scheduler、Resilience、DB/DoQry、LLM、Speech/ASR、Commerce、AutoUpdate、AntiTamper、VCL/FMX 控件等通用能力，避免每个下游项目重复实现基础设施�?
---

## 2. 当前可对接范�?
### 2.1 可以立即对接

- Core: Manager、Config、Logging、i18n、FormState、MRU、Hotkeys、Theme、Security�?- Services: IoC、EventBus、Scheduler、WorkerQueue、Resilience�?- Persistence: FireDAC SQLite、Manager storage、DoQry 基础能力�?- Features: Speech/ASR、Commerce HTTP 后端适配、AntiTamper、AutoUpdate、CloudSync/Backup 等按需接�?- VCL/FMX: 当前必选示例已能通过 Win64 编译门禁�?
### 2.2 需要等合并后复�?
- LLM 统一调用层�?- SQLite + PostgreSQL 统一适配层�?
下游现在可以�?facade/API 对接，不要在下游侧修�?LLM �?SQLite/PostgreSQL 底层适配实现。等统一适配层合并后重新编译即可�?
---

## 3. 包选择和编译顺�?
| �?| 依赖 | 提供能力 |
|----|------|----------|
| [DeepBaseCore.dpk](../DeepBaseCore.dpk) | �?VCL/FMX/FireDAC | Manager、Config、Logging、i18n、FormState、MRU、Hotkeys、Theme、Security schema |
| [DeepBaseServices.dpk](../DeepBaseServices.dpk) | Core | IoC、EventBus、Scheduler、WorkerQueue、Resilience、Crypto、RateLimiter、Metrics |
| [DeepBasePersistence.dpk](../DeepBasePersistence.dpk) | Core + Services + FireDAC | Manager FireDAC storage、DoQry、ORM、连接池 |
| [DeepBaseFeatures.dpk](../DeepBaseFeatures.dpk) | Services + Persistence | LLM、Speech/ASR、Commerce、AutoUpdate、AntiTamper、CloudSync、Graph、HttpServer |
| [DeepBaseVCL.dpk](../DeepBaseVCL.dpk) / [DeepBaseFMX.dpk](../DeepBaseFMX.dpk) | Core/Features | VCL/FMX 运行时控�?|
| [dclDeepBaseVCL.dpk](../dclDeepBaseVCL.dpk) / [dclDeepBaseFMX.dpk](../dclDeepBaseFMX.dpk) | 对应运行时包 | IDE 设计时控�?|

推荐顺序:

```text
DeepBaseCore
DeepBaseServices
DeepBasePersistence
DeepBaseFeatures
DeepBaseVCL / DeepBaseFMX
dclDeepBaseVCL / dclDeepBaseFMX
```

---

## 4. 初始�?
### 4.1 标准应用启动

EXE 目录�?`root.txt`，第一行写项目根路�?

```text
D:\Apps\MyTool
```

DeepBase 会使�?

```text
D:\Apps\MyTool\MyToolConfig.db
```

启动代码:

```delphi
uses
  DeepBase.Manager,
  DeepBase.Persistence.Manager.FireDAC;

begin
  DeepBase.InitializeOrRaise;
end;
```

`DeepBase.Persistence.Manager.FireDAC` 必须被链接，它负责注�?DB1 �?FireDAC SQLite 连接适配器和 storage factory�?
### 4.2 自定�?ConfigDB 路径

```delphi
DeepBase.InitializeWithDBOrRaise('D:\Apps\MyTool\MyToolConfig.db');
```

### 4.3 Boolean 模式

```delphi
var
  ErrorMsg: string;
begin
  if not DeepBase.InitializeEx(ErrorMsg) then
    ShowMessage(ErrorMsg);
end;
```

入口语义:

| API | 失败行为 |
|-----|----------|
| `InitializeEx(out ErrorMsg)` | 返回 `False`，写 `LastError` / `InitErrorCode` |
| `InitializeWithDB(DBPath)` | 返回 `False`，写 `LastError` / `InitErrorCode` |
| `InitializeOrRaise` | �?`EInitializationException` |
| `InitializeWithDBOrRaise(DBPath)` | �?`EInitializationException` |

---

## 5. 数据库职责边�?
| 数据�?| 类型 | 存放内容 | 禁止存放 |
|--------|------|----------|----------|
| DB1 ConfigDB | SQLite 本地 | DeepBase 框架表、配置、日志、i18n、FormState、MRU、Hotkeys、Theme、Secrets、LLM 本地配置/调用历史 | 生产用户、订单、支付流水、权�?|
| DB2 本地业务�?| SQLite 本地 | 工具自身业务数据、离线缓�?| 支付密钥 |
| DB3 远程业务�?| PostgreSQL/MySQL/其他 | 多端共享/协作业务数据 | 绕过统一 DB/Repository 约束 |
| DB4 认证与支付库 | 后端 DB | users/identities/orders/payments/entitlements/payment_notifications | 客户端直�?|

DB1 schema:

- 当前版本: `1.0.0`
- 最低兼容版�? `0.3`
- 初始化会自动创建/补齐核心表�?
---

## 6. 最小基础能力代码

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

关闭:

```delphi
DeepBase.Finalize;
```

---

## 7. Security �?Secret

敏感信息统一�?`DeepBase.Security`:

```delphi
DeepBase.Security.SaveSecret('LLM.Default.ApiKey', ApiKey);
ApiKey := DeepBase.Security.LoadSecret('LLM.Default.ApiKey');
```

规则:

- Windows 使用 DPAPI 用户作用域�?- macOS/Linux 使用 UBS2: AES-256-GCM + PBKDF2-SHA256�?- UBS2 已有版本分发，当前写�?v1；未知版本会提示升级或迁移�?- 不要�?API Key、Token、支付密钥写�?Settings 明文、日志或业务表�?
---

## 8. Resilience �?RuntimeContext

旧导入方式继续有�?

```delphi
uses DeepBase.Resilience;

Retry := TRetryPolicy.Create
  .MaxRetries(3)
  .ExponentialBackoff(100, 2.0, 5000)
  .MainThreadWaitMode(rmwRaise);
```

规则:

- UI 主线程不要同�?sleep/retry�?- UI 或主线程事件里使�?`ExecuteAsync` / `ExecuteAsync<T>`�?- `DeepBase.Resilience` 已拆成策略子单元，但 facade 保持兼容�?- RuntimeContext 默认注册 Manager、IoC、EventBus、Scheduler、WorkerQueue�?
---

## 9. LLM 集成边界

当前状�?

- LLM facade/API 可对接�?- SQLite + PostgreSQL 统一适配层正在优化�?- 下游先按 API 使用，不改底层适配器�?
下游可以�?

```delphi
uses DeepBase.LLM.Service;

Response := LLM.Chat(TierSmart, '解释这段代码');
```

下游不要�?

- 不要复制�?LLM 表结构到业务库�?- 不要明文保存 LLM API key�?- 不要�?UI 线程同步调用长耗时 LLM�?- 不要在下游私�?`Core/DeepBase.LLM*.pas` �?SQLite/PostgreSQL 适配层�?
---

## 10. Speech / ASR 语音识别

Speech 模块�?DeepInput 的语音链路抽取，放在 [DeepBaseFeatures.dpk](../DeepBaseFeatures.dpk):

| 单元 | 职责 |
|------|------|
| `DeepBase.Speech.Types` | 音频格式、识别结果、Provider 接口 |
| `DeepBase.Speech.Audio.WinMM` | Windows WaveIn 录音�?6kHz/16-bit/mono PCM |
| `DeepBase.Speech.VAD` | RMS 能量 VAD，支持静音自动停�?|
| `DeepBase.Speech.ASR.Baidu` | 百度语音 REST API Provider，支�?token 缓存和可注入 HTTP transport |
| `DeepBase.Speech.Service` | 录音、VAD、识�?Provider 的通用编排 |

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
  Result: TSpeechRecognitionResult;
begin
  Speech := TDeepBaseSpeechService.CreateBaidu(
    TSpeechBaiduConfig.Create(
      DeepBase.Security.LoadSecret('Speech.Baidu.ApiKey'),
      DeepBase.Security.LoadSecret('Speech.Baidu.SecretKey')));
  try
    if Speech.StartRecording then
    begin
      { UI timer can call Speech.ShouldAutoStop and then stop. }
      Result := Speech.StopAndRecognize;
      if Result.Success then
        DeepBase.Logger.Info('Speech text: ' + Result.Text, 'Speech');
    end;
  finally
    Speech.Free;
  end;
end;
```

规则:

- API key �?secret 统一�?`DeepBase.Security.SaveSecret/LoadSecret`�?- UI 按钮、热键、托盘、浮动条、文本注入由下游自己处理�?- 不要�?UI 线程直接执行长耗时识别；使�?`TTask.Run` �?WorkerQueue�?- 本地 Whisper �?DeepInput 中是兼容回退路径，当前没有作�?DeepBase 基础 Provider 封装�?
---

## 11. Commerce 统一商业流程

生产原则:

- 客户端只调用后端 HTTP API�?- 客户端不直连 DB4�?- 客户端不保存支付密钥�?- 客户端不自行把订单置�?paid�?
- `TCommerceHttpStorage` 是 server-admin storage adapter，默认禁止写订单、支付和权益。桌面端不要直接用它跑完整收费流程；服务器侧确需通过 HTTP storage 写后端时必须使用 `CreateServerAdmin`。
流程:

1. `EnsureUserForIdentity`
2. `CreateOrder`
3. `BeginPayment`
4. 后端支付通知验签/查单/金额币种校验
5. `ConfirmPayment`
6. 后端幂等发放 entitlement
7. 客户端查�?`HasEntitlement` / `ConsumeEntitlement`

服务器侧管理存储:

```delphi
Storage := TCommerceHttpStorage.Create(
  TCommerceBackendHttpConfig.CreateServerAdmin(
    'https://api.example.com',
    '<bearer-token-or-empty>',
    '<api-key-or-empty>'));
```

生产支付网关:

```delphi
Commerce.RegisterPaymentGateway(
  cppWeChatPay,
  TCommerceHttpPaymentGateway.Create(
    TCommerceBackendHttpConfig.Create(
      'https://api.example.com',
      '<bearer-token-or-empty>',
      '<api-key-or-empty>')));
```

开发期可用 `TInMemoryCommerceStorage`；生产禁止使用�?
后端契约�?[Commerce-Backend-Adapter-Spec.md](Commerce-Backend-Adapter-Spec.md)�?
---

## 12. Examples 和验�?
必选示�?

| 示例 | 用�?|
|------|------|
| `Examples/Phase0Demo` | 最小初始化 |
| `Examples/Phase1Demo` | VCL 基础控件 |
| `Examples/FullDemo` | 综合 VCL |
| `Examples/FMXDemo` | FMX 平台能力 |
| `Examples/CommerceE2EDemo` | Commerce 端到�?|

本地门禁:

```powershell
cmd /c compile_test.bat
Scripts\build_examples_win64.ps1
Scripts\run_tests.ps1 -Type Unit -Run Test.DeepBase.Manager
Scripts\run_tests.ps1 -Type Unit -Run Test.DeepBase.Speech
```

如要声明跨平台，补跑 Linux/macOS �?Security/OpenSSL/UBS2 测试�?
---

## 13. 下游集成检查清�?
- [ ] 引用�?`DeepBase.Persistence.Manager.FireDAC`�?- [ ] 初始化使�?`InitializeOrRaise` �?`InitializeWithDBOrRaise`�?- [ ] DB1/DB2/DB3/DB4 边界清楚�?- [ ] Secret/API Key 没有明文落库或落日志�?- [ ] UI 线程没有同步重试、同�?LLM、长时间阻塞�?- [ ] Speech/ASR 密钥�?`DeepBase.Security`，识别请求不�?UI 线程同步执行�?- [ ] Commerce 生产环境不使用内存存储�?- [ ] 支付成功只信任后端通知/查单�?- [ ] LLM �?SQLite+PostgreSQL 适配层未在下游私改�?- [ ] [compile_test.bat](../compile_test.bat) 通过�?- [ ] `Scripts\build_examples_win64.ps1` 通过�?
---

## 14. 相关文档

| 文档 | 用�?|
|------|------|
| [DeepBase-Downstream-Integration.md](DeepBase-Downstream-Integration.md) | 下游工程落地指南 |
| [Commerce-Backend-Adapter-Spec.md](Commerce-Backend-Adapter-Spec.md) | Commerce 后端契约 |
| [docs/README.md](README.md) | 下游项目文档索引 |
| [../ARCH-QUICKSTART.md](../ARCH-QUICKSTART.md) | 仓库级架构入�?|
