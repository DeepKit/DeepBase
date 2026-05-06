# UniBase 对外集成唯一入口

> **版本**: 1.0 | **更新日期**: 2026-05-06
> **定位**: 下游工程 / AI / 第三方接入 UniBase 的唯一入口文件
> **规则**: 只发本文件即可完成接入方案输出；其余文档为内部深挖参考

---

## 1. 一句话定义

UniBase 是一个 Delphi 桌面应用框架，提供配置、日志、国际化、窗体状态、LLM、Commerce（用户/订单/支付/权益）等开箱即用能力，避免每个项目重复造轮子。

---

## 2. 数据库职责边界（DB1~DB4）

| 数据库 | 类型 | 存放内容 | 禁止存放 |
|--------|------|----------|----------|
| **DB1** 配置库 | SQLite 本地 | UniBase 框架表（Settings/Logs/i18n/FormState/MRU/Hotkeys/Theme/AboutFrame 等） | 生产用户、订单、支付流水、权益 |
| **DB2** 本地业务库 | SQLite 本地 | 工具自身业务数据（单机/离线优先） | — |
| **DB3** 高级业务库 | PG/MySQL 网络 | 多端共享/协作的业务数据 | — |
| **DB4** 认证与支付库 | 生产后端 DB | users/identities/orders/payments/entitlements/payment_notifications | 客户端禁止直连 |

### 2.1 DB1 配置库

- 文件：`{AppName}Config.db`（SQLite，WAL 模式，UTF-8）
- 路径解析：`root.txt` 第一行 → `RootPath\{AppName}Config.db`
- Schema 版本：`0.3`
- 表结构按 Tier 分层（Tier 0 必选 → Tier 1 推荐 → Tier 2 可选），共 24 张基础表

### 2.2 DB2 本地业务库

- UniBase 提供 DoQry/DB 工具、连接与迁移能力，不强制 schema
- 配置：`Settings` 表中 `DB2.Type=SQLite`, `DB2.Path=data\MyAppData.db`

### 2.3 DB3 高级业务库

- UniBase 提供 DB.Factory、连接池、迁移、可选驱动适配
- 配置：`DB3.Type=PostgreSQL`, `DB3.Server`, `DB3.Port`, `DB3.Database` 等

### 2.4 DB4 认证与支付库

- **客户端原则**：只通过后端 HTTP API 访问，不直连 DB，不保存支付密钥
- 支付确认以可信后端通知为准（验签、查单、金额/币种/订单号校验）
- UniBase 客户端侧实现：`TCommerceHttpStorage`（存储走后端）+ `TCommerceHttpPaymentGateway`（支付意图走后端）

---

## 3. DB1 Schema 表清单

### 3.1 Tier 0 — 必选（5 表）

| 表 | 用途 |
|----|------|
| SchemaInfo | DB 版本管理 |
| Settings | Key-Value 配置（支持加密、类型、分类） |
| FormStates | 窗口位置/大小/状态持久化 |
| Languages | 支持语言定义 |
| I18nTexts | 翻译文本 |

### 3.2 Tier 1 — 推荐（7 表）

| 表 | 用途 |
|----|------|
| Logs | 应用日志（级别、来源、异常堆栈） |
| MRU | 最近使用列表 |
| Hotkeys | 快捷键配置 |
| Queries | 预定义 SQL 查询 |
| Themes | UI 主题 |
| Categories | 通用分类/枚举 |
| Tags | 标签系统 |

### 3.3 Tier 2 — 可选扩展（12 表）

| 表 | 用途 |
|----|------|
| Providers | LLM 提供商 |
| Models | LLM 模型元数据 |
| LLMConfig | LLM 配置档案 |
| LLMCalls | LLM 调用历史与费用 |
| LLMPrompts | Prompt 模板 |
| LLMApiKeys | API 密钥（credman 引用） |
| ExceptionReports | 崩溃报告 |
| AnimationAssets | SVG/Lottie 动画资源 |
| Attachments | 通用文件附件 |
| TagMappings | 标签-实体关联 |
| Notifications | 用户通知 |
| aboutMeImages | 关于/打赏图像（AES-256 加密） |

---

## 4. 全模块能力清单

### 4.1 包选择

| 包 | 依赖 | 提供的能力 |
|----|------|-----------|
| UniBaseCore.dpk | 无 VCL/FMX/FireDAC | Manager、Config、Logging、i18n、FormState、MRU、Hotkeys、Theme、Schema |
| UniBaseServices.dpk | Core | IoC、EventBus、Scheduler、Crypto、Security、Resilience、RateLimiter、Metrics |
| UniBasePersistence.dpk | Core + Services | FireDAC/DoQry、ORM、连接池 |
| UniBaseFeatures.dpk | Services | LLM、Commerce、AutoUpdate、AntiTamper、CloudSync、CloudBackup、Graph、HttpServer |
| UniBaseVCL.dpk / UniBaseFMX.dpk | Core | UI 控件运行时包 |
| dclUniBaseVCL.dpk / dclUniBaseFMX.dpk | 对应运行时包 | 设计时控件（IDE 注册） |

### 4.2 Core 核心模块

| 模块 | 解决的问题 | 依赖 | 适配点 |
|------|-----------|------|--------|
| `UniBase.Manager` | 初始化/终结入口，root.txt 解析 | 无 | 调用 `UniBase.Initialize` |
| `UniBase.Config` | 集中配置读写（替代 INI/Registry） | DB1 | 自动，无需适配 |
| `UniBase.Logging` | 统一日志（SQLite + 文件） | DB1 | `Logger()` 返回日志器 |
| `UniBase.i18n` | 国际化 `T()` / `TFmt()` | DB1 | 设置 `TextKey` 属性 |
| `UniBase.FormState` | 窗口位置/大小自动保存恢复 | DB1 | 拖放 `TFormStateHelper` |
| `UniBase.MRU` | 最近使用列表 | DB1 | 使用 `TMRUPopupMenu` / `TMRUComboBox` |
| `UniBase.Hotkeys` | 用户可配置快捷键 | DB1 | 自动加载/保存 |
| `UniBase.Theme` | UI 主题管理 | DB1 | 使用 `TThemeComboBox` |
| `UniBase.Schema` | DB1 Schema 版本管理与迁移 | DB1 | 自动运行 |
| `UniBase.SingleInstance` | 单实例检测 | 无 | `UniBase.WhenReady` |

### 4.3 Services 基础设施模块

| 模块 | 解决的问题 | 依赖 | 适配点 |
|------|-----------|------|--------|
| `UniBase.EventBus` | 发布/订阅事件总线 | 无 | 注册处理器 |
| `UniBase.IoC` | 控制反转容器 | 无 | 注册/解析服务 |
| `UniBase.Scheduler` | 任务调度 | 无 | 配置调度规则 |
| `UniBase.ObjectPool` | 对象池复用 | 无 | 池化重对象 |
| `UniBase.Resilience` | 重试/熔断器 | 无 | 包装不可靠操作 |
| `UniBase.RateLimiter` | 速率限制 | 无 | 限制调用频率 |
| `UniBase.Metrics` | 应用指标采集 | 无 | 注册指标 |
| `UniBase.Compression` | 数据压缩 | 无 | 自动 |
| `UniBase.Cache` | 内存缓存 | 无 | 配置过期策略 |
| `UniBase.Serialization` | JSON/通用序列化 | 无 | 自动 |
| `UniBase.FeatureFlags` | 功能开关 | DB1 | 配置开关状态 |
| `UniBase.Feedback` | 用户反馈收集 | 无 | 使用 `TFeedbackDialog` |
| `UniBase.FileWatcher` | 文件系统监视 | 无 | 注册路径 |
| `UniBase.MVVM` | MVVM 模式支持 | 无 | 继承 ViewModel |
| `UniBase.Plugin` | 插件接口 | 无 | 实现 `IPlugin` |
| `UniBase.Validation` | 数据验证 | 无 | 定义规则 |

### 4.4 Security 安全模块

| 模块 | 解决的问题 | 依赖 | 适配点 |
|------|-----------|------|--------|
| `UniBase.Security` | 安全门面（加密 API 密钥） | Windows | 自动 |
| `UniBase.KeyManager` | 密钥/凭据管理 | DPAPI/CredMan | 配置存储策略 |
| `UniBase.Protection` | 应用保护 | Windows | 配置保护参数 |
| `UniBase.Authorization` | 授权/RBAC | 无 | 定义角色/权限 |
| `UniBase.License` | 许可证管理 | 无 | 配置验证方式 |
| `UniBase.Unlock` | 解锁/试用门控 | 无 | 配置试用策略 |

### 4.5 Persistence 持久化模块

| 模块 | 解决的问题 | 依赖 | 适配点 |
|------|-----------|------|--------|
| `UniBase.DB.DoQry` | 通用 SQL 访问 | FireDAC | `UniDbExec` / `UniDbSelect` / `UniDbScalar` |
| `UniBase.ORM` | 对象关系映射 | FireDAC | 定义 Mapping |
| `UniBase.DB.ConnectionPool` | 连接池 | FireDAC | 配置最大连接数 |

### 4.6 Features 扩展模块

| 模块 | 解决的问题 | 依赖 | 适配点 |
|------|-----------|------|--------|
| `UniBase.LLM.*` | LLM 调用（多 Provider/Model） | Services + DB1 | 配置 Provider/Key，调用 `LLM.Chat()` |
| `UniBase.Commerce.*` | 用户/订单/支付/权益全流程 | Services + 后端 | 实现 `ICommerceStorage` + `ICommercePaymentGateway` |
| `UniBase.AntiTamper` | 资源防篡改保护 | Features + DB1 | 配置密钥，使用 SeedTool 播种 |
| `UniBase.AutoUpdate` | 自动更新 | Features | 配置更新源 |
| `UniBase.CloudSync` | 多设备配置同步 | Features + 网络 | 配置同步端点 |
| `UniBase.CloudBackup` | 备份/恢复 | Features + 网络 | 配置存储后端 |

### 4.7 UI 控件（VCL + FMX 各 14 个）

| 控件 | 功能 | 对应模块 |
|------|------|---------|
| `TConfigEdit` / `TConfigCheckBox` / `TConfigSpinEdit` | 配置自动绑定 | Config |
| `TI18nLabel` / `TI18nButton` / `TI18nMenuItem` | 自动翻译 | i18n |
| `TLanguageComboBox` / `TThemeComboBox` | 语言/主题选择 | i18n / Theme |
| `TMRUPopupMenu` / `TMRUComboBox` | 最近使用列表 | MRU |
| `TWaitForm` | 等待窗口（SVG 动画） | Animation |
| `TAutoUpdater` | 自动更新 | AutoUpdate |
| `TFeedbackDialog` | 反馈收集 | Feedback |
| `TFormStateHelper` | 窗体状态助手 | FormState |

---

## 5. 推荐接入组合

### 5.1 工具类软件（桌面单机 / 弱后端）

典型场景：C盘瘦身、文本转换、SVG编辑、快捷启动等

**推荐数据库组合**：DB1（配置）+ DB2（业务），涉及付费时接 DB4（后端）

| 类别 | 模块 | 说明 |
|------|------|------|
| 必选 | Manager、Config、Logging、i18n、FormState、MRU、Hotkeys、Theme | 基础能力 |
| 推荐 | AntiTamper、AboutFrame | 保护收款二维码/关于页面 |
| 可选 | AutoUpdate | 自动更新（有网络环境） |
| 可选 | LLM | 需要大模型能力时 |
| 付费统一 | Commerce（走平台网站跳转 + 后端确认） | 见第 6 节 |

### 5.2 管理类软件（多用户 / 强后端 / 审计风控）

典型场景：决策推演、信息聚合、团队协作、内容创作等

**推荐数据库组合**：DB1（本地状态）+ DB3（业务数据）+ DB4（认证支付）

| 类别 | 模块 | 说明 |
|------|------|------|
| 必选 | Manager、Config、Logging、i18n、FormState | 基础能力 |
| 必选 | Authorization | Token 管理（多用户） |
| 必选 | Commerce | 用户/权益（必须走后端） |
| 必选 | Resilience | 重试/熔断（网络依赖） |
| 推荐 | Logging（审计策略） | 操作审计 |
| 可选 | Metrics、RateLimiter | 性能监控、限流 |
| 可选 | CloudSync、CloudBackup | 按业务需求 |

---

## 6. 平台网站跳转流程（商业化统一规范）

**核心约束**：所有工具的购买/续费/升级必须通过平台网站跳转，客户端不直连支付渠道。

### 6.1 推荐流程

1. 工具端触发"购买/升级" → 打开平台网站 URL（带 app_id、device identity、return_url）
2. 网站侧完成登录、下单、支付
3. 后端接收支付通知 → 验签/查单/校验 → 幂等确认 → 发放 entitlement（DB4）
4. 工具端回到应用后查询 entitlement，刷新 UI
5. 工具端不允许自行把订单置为已支付

### 6.2 Commerce 后端数据模型（6 表）

| 表 | 键字段 | 说明 |
|----|--------|------|
| users | user_id | 用户主表 |
| identities | identity_id, user_id | 外部身份（微信 openid/邮箱/手机） |
| products | app_id, product_id | 商品定义（名称、金额、权益码） |
| orders | order_id, out_trade_no (unique) | 订单（created/paying/paid/closed/failed/refunded） |
| payments | payment_id, order_id (unique) | 支付记录 |
| entitlements | entitlement_id, user_id, source_order_id (unique) | 权益（active/consumed/expired） |

### 6.3 后端 HTTP API

| 方法 | 路径 | 用途 |
|------|------|------|
| POST | `/commerce/users/ensure` | 创建/复用用户（幂等） |
| POST | `/commerce/orders` | 创建订单（服务端定价） |
| POST | `/commerce/payments/intents` | 创建支付意图（返回 pay_url） |
| POST | `/commerce/payments/wechat_pay/notify` | 微信支付通知 |
| GET | `/commerce/entitlements` | 查询权益 |
| POST | `/commerce/entitlements/consume` | 原子扣减权益配额 |

### 6.4 客户端侧对接

- 存储：`TCommerceHttpStorage`（实现 `ICommerceStorage`）
- 支付意图：`TCommerceHttpPaymentGateway`（实现 `ICommercePaymentGateway`）
- 开发/测试：`TInMemoryCommerceStorage`（禁止用于生产）

### 6.5 幂等键设计

| 操作 | 幂等键 |
|------|--------|
| 用户创建 | `provider + provider_user_id + app_id` |
| 订单创建 | `Idempotency-Key` 或 `client_order_key` |
| 支付意图 | `order_id + provider` |
| 支付通知 | 微信通知 `id` 或 `sha256(raw_payload)` |
| 权益发放 | `source_order_id` |

---

## 7. 最小端到端接入步骤

### 7.1 初始化（5 分钟）

1. 编译 UniBaseCore.dpk
2. 项目目录放 `root.txt`，第一行写绝对路径
3. `UniBase.Initialize` → 自动创建 `{AppName}Config.db`

### 7.2 核心功能

```delphi
// 配置
UniBase.SetConfig('App.Language', 'zh-CN');
var val := UniBase.GetConfig('App.Language');

// 国际化
Caption := T('Welcome');

// 窗体状态（拖放 TFormStateHelper 即可自动）
UniBase.SaveFormState(Self);
UniBase.RestoreFormState(Self);
```

### 7.3 业务数据库

```delphi
uses UniBase.DB.DoQry;
UniDbInit(RootPath);
var Ctx := UniDbMakeContext(Conn, udbSQLite, 5000);
UniDbExec(Ctx, 'INSERT INTO MyTable (Name) VALUES (:Name)', ['Test']);
```

### 7.4 LLM 调用

```delphi
uses UniBase.LLM.Service;
var Result := LLM.Chat(TierSmart, '解释这段代码');
// 支持 TierSmart / TierBalanced / TierFast
// 支持 ChatWithHistory / ChatStream
```

### 7.5 Commerce 集成

```delphi
// 1. 注册生产存储 + 支付网关
Service.SetStorage(TCommerceHttpStorage.Create('https://api.example.com'));
Service.SetPaymentGateway(TCommerceHttpPaymentGateway.Create('https://api.example.com'));

// 2. 用户/下单/支付
var UserId := Service.EnsureUserForIdentity('wechat', OpenId, AppId);
var OrderId := Service.CreateOrder(UserId, ProductId, 1);
Service.BeginPayment(OrderId, 'wechat_pay');  // 返回 pay_url，跳转浏览器

// 3. 支付完成后查询权益
if Service.HasEntitlement(UserId, 'pro_access') then ...
```

---

## 8. 关键约束（请勿违反）

| 约束 | 说明 |
|------|------|
| 不直连 DB4 | 客户端通过后端 HTTP API 访问用户/订单/支付/权益 |
| 不保存支付密钥 | 支付密钥仅在后端 |
| 不客户端确认支付 | 支付确认必须以可信后端通知为准 |
| 不拼接 SQL | 所有 SQL 必须参数化（DoQry 自动处理） |
| 不直连支付 SDK | 走平台网站跳转 |
| 不使用 INI/Registry | 统一用 `UniBase.Config` |
| 不硬编码文本 | 使用 `T()` / `TFmt()` |
| 禁止 `TThread.Synchronize` | 使用 `TThread.Queue` |
| 文件编码 UTF-8 BOM | 所有 .pas/.dfm/.fmx 文件 |

---

## 9. 线程规则

- 异步操作：`TTask.Run + TThread.Queue`
- 禁止 `TThread.Synchronize`（用 `TThread.Queue` 替代）
- 禁止循环中 `Application.ProcessMessages`

---

## 10. 相关文档索引

| 文档 | 用途 |
|------|------|
| `docs/UniBase-Downstream-Integration.md` | 下游工程接入标准流程 |
| `docs/Commerce-Backend-Adapter-Spec.md` | Commerce 生产后端契约 |
| `docs/04.01.uniBase-4AI-数据库Schema说明-v1.0.md` | 24 张表完整字段定义 |
| `docs/01.01.uniBase-4AI-集成指南-v1.0.md` | AI 集成约束和 API 参考 |
| `docs/05.01.uniBase-4AI-API参考-v1.0.md` | 完整 API 参考手册 |
| `docs/05.03.uniBase-4AI-DoQry指南-v1.0.md` | DoQry 数据访问指南 |
| `../ARCH-QUICKSTART.md` | 架构快速入门（仓库级入口） |
