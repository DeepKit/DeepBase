# DeepBase 文档区优化计划（Draft�?
> 更新日期�?026-05-05  
> 目标：把 `docs/` 全部文档“可用、可维护、可对外复用”，并保证你发给其它 AI 接入 DeepBase 时只需要发 **1 个文�?*�? 
> 关键约束：工具类软件的付费必须经过你�?**平台网站跳转**（统一入口），客户端不直连支付渠道，不保存支付密钥；认�?支付数据统一归于 DB4（后端）�?
---

## 1. 核心交付与入口收�?
### 1.1 唯一对外接入文件（给其它 AI/下游用）

- 新增并维护：`docs/DeepBase-Integration-OneFile.md`
- 该文件作为“对外唯一入口”，必须包含�?  - `root.txt` + DB1/DB2/DB3/DB4 的职责边界（必须写清楚）
  - DeepBase **全部模块能力清单**（不遗漏：自动升级、主题模板、LLM、Commerce、云同步、工�?管理软件常用模块等）
  - 适配点清单（下游要实�?配置什么，如何选包�?  - “工具类/管理类软件”的推荐接入项（给出明确推荐组合�?  - 商业化流程：**统一平台网站跳转**、后端确认支付、权益查询与发放（禁止客户端改订�?权益�?  - 最小端到端流程要点（要点式，不写长篇叙述）

### 1.2 docs 入口统一

- `docs/README.md`：只保留“文档总览 + 指向 `docs/DeepBase-Integration-OneFile.md` 的首要入口”，避免下游/AI 误入旧文档�?- `docs/00.00.DeepBase-文档索引-v1.0.md`：首行明确“对外唯一入口�?`docs/DeepBase-Integration-OneFile.md`”，其余文档为内部深挖参考�?- `ARCH-QUICKSTART.md`：保留为仓库级架构入口（人读），但在对外接入时不作为必须材料�?
验收标准�?- 你发给其�?AI 的材料：只发 `docs/DeepBase-Integration-OneFile.md`�? 文件即可完成接入方案输出）�?
---

## 2. DB1~DB4 规范（必须统一口径�?
把所有现有文档里的“DB 说法”统一为以下模型，并在对外接入文件中作为强约束�?
### DB1：配置库（SQLite，本地，DeepBase 框架库）

- 文件：`{AppName}Config.db`
- 存放内容：DeepBase 框架表与本地状态（Config/Logs/i18n/FormState/MRU/Hotkeys/Theme/AboutFrame 等）
- 禁止存放：生产用户、订单、支付流水、权益（这些都属�?DB4�?
### DB2：本地业务库（SQLite，本地，业务自定义）

- 存放内容：工具自身业务数据（单机/离线优先�?- DeepBase 提供：DoQry/DB 工具、连接与迁移能力（不强制 schema�?
### DB3：高级业务库（网�?DB：PG/MySQL/…）

- 存放内容：需要多端共�?协作的业务数据（项目/任务/资产等）
- DeepBase 提供：DB.Factory、连接池、迁移、可选驱动适配

### DB4：认证与支付库（生产后端 DB�?
- 存放内容：users/identities/orders/payments/entitlements/payment_notifications（含支付通知原文与审计字段）
- 客户端原则：
  - 只通过后端 HTTP API 访问 DB4（不直连 DB，不保存支付密钥�?  - 支付确认以可信后端通知为准（验签、查单、金�?币种/订单号校验）
- DeepBase 客户端侧推荐实现�?  - `TCommerceHttpStorage`（存储走后端�?  - `TCommerceHttpPaymentGateway`（支付意图走后端�?
验收标准�?- docs 中不再出现“把订单/支付/权益放本�?config.db”这类冲突说法�?- 对外接入文件明确：DB4 永远是后端可信域�?
---

## 3. 模块全量清单（避免重复造轮子）

对外接入文件必须列“模块清单表”，按以下维度写清楚�?
- 模块名（Core/Services/Persistence/Features/VCL/FMX/ThirdParty�?- 解决的问题（下游为什么用它）
- 典型使用场景（工具类/管理类分别怎么用）
- 依赖与边界（是否需�?DB、是否需要网络、是否需要后端）
- 关键配置�?环境变量（在哪里配、谁负责�?- 适配点（是否需要实现某接口、是否只需配置�?
必须覆盖（不遗漏）：
- 自动升级：`Updater/AutoUpdate`（更新源、签名校验、回滚策略、离线策略）
- 主题与模板：Theme 模块 + UI Themes 扩展（VCL/FMX 的使用差异、主题存储位置、默认主题策略）
- i18n：翻译表、缺失翻译策略、导入导�?扫描工具（若有）
- 日志：本�?文件/DB、脱敏原则、保留期
- FormState：多屏恢复规则（已修复的边界明确�?- MRU/Hotkeys：适用工具类软�?- 安全与密钥：DPAPI/CredMan、敏感信息存放策�?- Authorization：令牌保�?刷新（管理类软件常用�?- Commerce：统一用户/订单/支付/权益（只走后端可信域�?- LLM：Provider/密钥存储、调用记录、导入导�?- CloudSync/CloudBackup：使用边界与安全说明
- HttpServer（若用于内嵌服务/回调）：CORS/鉴权策略
- DoQry/DB.Factory/连接�?迁移：DB2/DB3 的推荐接�?- 事件总线/调度/Resilience/RateLimiter/Metrics/Compression/ObjectPool 等通用基础设施
- VCL/FMX 组件：AboutFrame、控件包、平台差异与接入�?
验收标准�?- 下游不需要再自建“日�?配置/i18n/窗体状�?重试/限流/对象�?升级”等重复实现�?
---

## 4. 工具�?vs 管理类：推荐接入组合（必须给结论�?
�?`docs/DeepBase-Integration-OneFile.md` 里给两套“推荐组合”，每套写：
- 必选模�?- 常见可选模�?- 不推荐模块（或慎用条件）
- 推荐数据库组合（DB1/DB2/DB3/DB4 取舍�?
### 4.1 工具类软件（桌面单机/弱后端）

推荐�?- DB1 + DB2 为主；如涉及账号/付费/权益则接 DB4（后端）
- 必选：Manager/Config/Logging/i18n/FormState/MRU/Hotkeys/Theme
- 可选：Updater/AutoUpdate、AboutFrame/AntiTamper、LLM（若需要）
- 付费统一：必须走平台网站跳转 + 后端确认（见�?5 节）

### 4.2 管理类软件（多用�?强后�?审计风控�?
推荐�?- DB1（本地状态）+ DB3（业务数据）+ DB4（认证支付）
- 必选：Authorization（token 管理）、Logging（审计策略）、Resilience（重�?熔断）、Commerce（权益）
- 可选：Metrics、RateLimiter、Cloud*（按业务�?
---

## 5. 平台网站跳转（商业化流程统一规范�?
统一规定：所有工具的“购�?续费/升级”必须通过你的平台网站跳转，客户端不直接展示支付二维码/不直连微信支�?SDK�?
### 5.1 推荐流程（要点）

1. 工具端触发“购�?升级�?�?打开平台网站 URL（带 app_id、device/user identity、return_url 等参数）
2. 网站侧完成登录、下单、支�?3. 后端接收支付通知 �?验签/查单/校验 �?幂等确认支付 �?发放 entitlement（DB4�?4. 工具端回到应用后�?   - 调后端查�?entitlement（或轮询/推送）刷新本地 UI
   - 不允许工具端自行把订单置为已支付

### 5.2 DeepBase 客户端侧对接建议

- 存储：`TCommerceHttpStorage`
- 支付意图：`TCommerceHttpPaymentGateway`（调�?`/commerce/payments/intents`�?- 工具端“跳�?URL”来源：
  - 平台网站统一的购买入口（推荐由后端返�?`pay_url` 或统一�?platform url�?  - 工具端只负责打开链接 + 之后查权�?
验收标准�?- 任何工具项目中不出现“客户端保存微信支付密钥/客户端验�?客户端确认支付”的生产路径�?
---

## 6. docs 全区整理/合并/纠错/删除计划

### 6.1 文档分级与生命周�?
- **L0 对外入口（只 1 个）**：`docs/DeepBase-Integration-OneFile.md`
- **L1 下游工程参�?*：API 参考、DB 指南、ThirdParty 指南、集成检查清�?- **L2 内部实现细节**：架构设计、迁移记录、历史与 BugFix
- **L3 归档/历史**：统一�?`docs/99.*`，并明确“非入口、仅追溯�?
### 6.2 必做清单（执行顺序）

1. 新增 `docs/DeepBase-Integration-OneFile.md`（对外唯一入口�?2. 对齐并纠错：
   - 所有涉�?DB 的文档：统一 DB1~DB4 口径
   - Commerce/支付文档：统一“平台网站跳�?+ 后端确认 + entitlement�?   - 自动升级/主题模板：补齐边界、配置与推荐组合
3. 合并重复入口�?   - `docs/README.md`、`docs/00.00...索引` 只保留必要入口指�?   - 其它文档保留但降级为“内部参考”，避免误导 AI
4. 删除无价�?重复/过期文档�?   - 标准：与现行封板架构冲突、内容过时、与新入口重复、或长期无人维护
   - 删除后必须修正剩余文档引用，确保 `Scripts/check_doc_links.ps1` 全绿

### 6.3 “不留历史”要求（需要你决策�?
你之前要求“删除多余文档且不要留在历史里”。Git 默认无法做到“删除即不留历史”。这里给两种方案�?
- 方案 A（默认、安全）：仅从工作树删除文件，Git 历史保留（推荐，风险低）
- 方案 B（彻底抹除历史）：使�?`git filter-repo` 重写历史并强制推送（风险高，需要你明确批准并安排协作窗口）

�?`docs/DeepBase-Integration-OneFile.md` 完成并稳定后，再决定是否执行方案 B�?
---

## 7. 自动化门禁与维护规则

- 文档链接门禁：所�?L0/L1 文档必须通过 `Scripts/check_doc_links.ps1`
- 入口门禁：对外入口只允许 `docs/DeepBase-Integration-OneFile.md`（其他入口在标题处标记“内部参考”）
- 更新规则�?  - 每次框架能力变更：必须同步更�?L0（单文件）中的“模块清单表”和“推荐接入组合�?  - 每次支付/认证流程变更：必须同步更�?DB4 与平台跳转流程章�?
---

## 8. 执行里程碑（供你审）

- M1：新�?`docs/DeepBase-Integration-OneFile.md`（包�?DB1~DB4 + 全模块清�?+ 两类推荐组合 + 平台跳转流程�?- M2：对�?`docs/README.md` �?`docs/00.00...索引`，收敛入�?- M3：全量纠错与合并（DB/Commerce/Updater/Theme 等口径一致）
- M4：删除过�?重复文档 + 链接门禁全绿
- M5（可选）：若你坚持“不留历史”，执行 git 历史重写方案（需你批准）
