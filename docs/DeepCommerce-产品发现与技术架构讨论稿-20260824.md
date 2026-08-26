# DeepCommerce 产品发现与技术架构讨论稿

> 状态：讨论稿 / 待老板裁决  
> 日期：2026-08-24  
> 范围：调查、边界与架构设计；不代表真实支付、结算或迁移已经完成。  
> 事实基线：DeepBase `56f0871`、DeepAxis `3c054e7`、DeepCompare/DeepRW `773bad9`；三个工作区均存在未提交改动，本稿未修改其业务代码。

## 1. 执行摘要

结论：老板提出的三层分法基本正确，但应把“DeepCommerce”定义得更严格：

- **DeepBase** 是稳定的技术底座和商业执行原语：认证/权限、许可、基础商品订单支付、基础 entitlement/quota、签名快照、安全客户端、持久化、队列、事件、加密和 LLM 原始用量。
- **DeepCommerce** 是跨产品的商业策略与账务编排内核：产品/能力/计划/Offer 定义、权益政策、价值工作单元、活动与贡献换权益、归因、渠道、佣金、结算、退款冲正、不可变账本和投影。
- **产品层** 只定义“卖什么、交付什么、什么结果值多少、哪些功能属于哪一档”，并执行产品业务；不得直接改商业账本。

修正点：`SKU → Order/Payment` 不应由 DeepCommerce 再实现一套。DeepCommerce 的 Offer/SKU 和策略编译为 DeepBase Commerce 能执行的商品/权益，并通过 DeepBase/DeepKit 的可信支付与快照接口落地。DeepCommerce 是 DeepBase Commerce 的**上层 bounded context**，不是替代品。

建议采用“**独立仓库 + 契约库 + 可嵌入服务模块**”：第一阶段建立独立 `DeepCommerce` 仓库，产出 Delphi 客户端 SDK、定义/校验器、领域内核、内存/SQLite 模拟器和 DeepKit 服务端模块；暂不急于拆成独立网络微服务。真实资金发生后，再按负载和组织边界决定是否独立部署。

## 2. DeepBase 现有商业能力盘点

### 2.1 已由当前代码/文档验证

| 能力 | 已验证入口 | 判断 |
|---|---|---|
| Free/PRO、Feature Matrix、试用、升级 | `Features/DeepBase.Licensing.pas`、`docs/80.feature-matrix.md` | 已有稳定许可入口，不重做 |
| 商品、订单、支付、entitlement、有效期、设备数、quota | `DeepBase.Commerce.Types/Service/Storage.pas` | 已有基础聚合与接口 |
| 支付适配、通知验证 | `Commerce.Service` 的 gateway/verifier；`Commerce.Backend.Http` | 已有抽象；真实商户验收仍未完成 |
| RequireFeature / ConsumeQuota | `Commerce.Permissions.pas`、`Licensing.pas` | 已有客户端安全门面和可信核销路径 |
| 退款、关闭订单、撤权、撤快照的服务端入口 | `Commerce.Backend.Http.pas` | 有 API 入口，不等于完整退款/账本/结算领域已完成 |
| SafeClient 与客户端/管理员写边界 | `Commerce.SafeClient.pas`、`docs/65...` | 客户端只暴露允许操作，管理写 fail-closed |
| 签名离线授权快照 | `Licensing.pas`、DeepKit 文档 | 支持签发/刷新/验签、设备与过期约束 |
| 支付安全基线 | `docs/65...` | HTTPS、验签、金额/币种校验、幂等、服务端发权 |
| DB1/DB2/DB3/DB4 边界 | AI one-file、`docs/65/66/67` | 客户端不得直连 DB4，不存生产支付真值 |
| Security | AI one-file、Security 单元 | DPAPI/UBS2，敏感值不得明文 |
| Persistence / Authorization | `Persistence/*`、`DeepBase.Authorization` | 通用持久化和 RBAC 原语已有 |
| WorkerQueue / EventBus | `Core/DeepBase.WorkerQueue.pas`、`EventBus.pas` | 可复用技术原语，不等于商业 Outbox |
| LLM 原始 usage/token/cost | `Core/DeepBase.LLM*`、`BillingClient` | 有调用与原始计量；不是用户价值计价账本 |
| HTTP/Firebase/Supabase 适配 | Commerce adapter 单元 | Firebase/Supabase 明确是 server-only/prototype，桌面不得生产直连 |

### 2.2 尚不能宣称完成

- DeepKit 文档明确：本地 contract smoke 已通过，但真实 PostgreSQL、真实商户配置、公网回调和真实支付仍需验收。
- DeepBase 的基础 `EntitlementData` 适合“码、期限、quota、设备”等执行，不足以承载活动证据、复杂 Grant、钱包分桶、佣金成熟期、结算与重建投影。
- 通用 EventBus/WorkerQueue 不能直接等同于事务 Outbox/Inbox；商业消息必须与账本事务同提交。
- “退款 API 存在”不等于完整部分退款、权益按比例回收、佣金冲正和对账闭环已生产化。

## 3. DeepAxis 商业方案盘点

### 3.1 可提升为通用能力

由 DA-099/101/105 及当前代码验证，DeepAxis 已形成以下高价值模式：

1. Capability 与具体 UI/插件解耦，插件只声明能力和计量，不定价格与分佣。
2. 价值工作单元：不按按钮点击收费，而按可感知结果收费。
3. `reserve → capture/consume → release` 的失败安全计量；当前 `DeepAxis.Runtime.UsageLedger.pas` 和 operation catalog 已有本地实现/配置雏形。
4. 价格、活动、折扣、权益、渠道规则集中配置，不散落在 UI。
5. 商业真值在服务端，本地仅投影；Outbox/Inbox mock 已覆盖重试、租约、幂等、游标、乱序、墓碑等恢复场景。
6. 推荐、演示、实施、模板等多角色渠道；权益奖励与现金佣金分账。
7. 退款后撤权并冲正未结算佣金；插件不得直接改账。

### 3.2 必须留在 DeepAxis

CRM、微信账号/设备适配、联系人、聊天摘要语义、客户分群、销售诊断、跟进、素材、CRM 插件清单、微信版本持续适配、DeepAxis 的四版本名称、具体 operation code/倍率/价格、CRM 交付与风险门禁均属于产品层。

### 3.3 当前成熟度限制

DA-105 自己声明当前只允许契约、状态机、本地投影、模拟器和测试。DeepAxis 的 UsageLedger、PG schema、同步 mock 是很好的**候选参考实现**，但不能原样冒充通用生产账本；字段命名和不变量必须经 DeepRW 第二产品验证后再冻结。

## 4. 可复用能力与产品特有能力拆分

通用化判断标准：同时满足 (a) DeepAxis 与 DeepRW 都有实例；(b) 不依赖 CRM/科研词汇；(c) 有独立不变量；(d) 不能由 DeepBase 现有原语直接表达。满足者进入 DeepCommerce；否则留产品层或 DeepBase。

## 5. DeepBase / DeepCommerce / 产品层边界表

| 能力 | 主责 | 说明 |
|---|---|---|
| Commerce 技术基础设施、Licensing、Feature Gate、Signed Snapshot、Offline Entitlement、Device Binding | DeepBase | 稳定执行原语 |
| 基础 Entitlement 数据与核销 | DeepBase | DeepCommerce 定义政策并投影到它 |
| ProductDefinition、CapabilityDefinition、PlanDefinition、OfferDefinition | DeepCommerce | 产品提供实例，DC 校验、版本化、发布 |
| SKU | 共同边界 | DC 定义商业 SKU/Offer；DB 承载可交易 product_id 和订单快照 |
| Pricing | DeepCommerce + 产品输入 | 产品给定价假设；DC 版本化、币种、税和价格快照 |
| Trial、Subscription、Perpetual、按次、混合 | DeepCommerce 政策；DeepBase 执行期限/权益 | 不重做快照和基础有效期 |
| Usage Quota | DeepBase 基础核销；DeepCommerce 复杂政策 | 简单 quota 复用 DB；预留/分桶/共享池由 DC |
| 价值工作单元、Usage Ledger、Grant | DeepCommerce | 跨产品核心 |
| Campaign、Coupon、Referral、Affiliate、Implementation Partner | DeepCommerce | 产品仅选规则和奖励 |
| Template/Plugin Marketplace | DC 提供交易/分成原语；产品提供内容、审核与交付 | 第一阶段不做完整市场 |
| Wallet、Credit | DeepCommerce | 仅做非现金工作单元钱包；现金余额必须严格独立 |
| Commission、Settlement、Reversal、Reconciliation | DeepCommerce 服务端 | 不在桌面执行 |
| Refund | DeepBase 对接支付提供方；DC 编排权益与佣金补偿 | Saga/事务边界清晰 |
| Payment Provider Adapter | DeepBase/DeepKit | DC 不接商户私钥 |
| Team Seat、Organization Account | DC 通用租户/席位；产品定义协作语义 | 组织数据治理仍在产品 |
| Cost Ledger、LLM Token Cost | DB 采原始 usage；DC 归集成本 | 产品可提供非 LLM 成本标签 |
| BYOK/平台额度路由 | DB/产品执行路由；DC 定权益与计费政策 | BYOK token 不扣平台成本，但可扣价值单元 |
| 云同步、团队空间收费 | 产品定义容量/服务；DC 计价授权 | 实际同步/存储在产品/云服务 |
| 商业审计日志、运营后台 | DC | 复用 DB 日志/权限组件；Admin 写操作服务端化 |
| 产品内升级流程 | DeepBase UI/生命周期原语 + 产品 UX | DC 返回 eligible offers，不硬编码 UI |
| Permission/RBAC | DeepBase 原语 | DC 定义商业 Admin 权限集合，产品定义业务角色 |

## 6. DeepCommerce 定位及非目标

**定位**：商业政策编译器 + 价值计量/Grant/渠道账务编排 + 服务端权威账本。

**非目标**：CRM、科研工作流、微信、LLM provider SDK、桌面 UI 框架、支付密码学、数据库通用 ORM、插件宿主、税务代理、真实资金托管、首期完整商城。DeepCommerce 不创造第二套 Licensing、Payment、Order 或签名系统。

## 7. 最小稳定领域模型

建议将参考链修正为四条相交的链：

1. **定义链**：`ProductDefinition → CapabilityDefinition → PlanDefinition → OfferDefinition → SKU`
2. **权利链**：`Source(Order/Campaign/Admin) → Grant → Entitlement → Signed Projection`
3. **使用链**：`WorkUnitDefinition → Reservation → UsageEntry → CostEntry`
4. **资金/渠道链**：`Order/Payment(DB) → Refund/Reversal → Attribution → Commission → Settlement`

| 对象 | 单一职责 | 权威位置 |
|---|---|---|
| ProductDefinition | 产品命名空间、定义版本、数据可携带底线 | 配置发布仓/服务端 |
| CapabilityDefinition | 稳定 capability code、类型、scope、离线级别 | 版本化定义 |
| PlanDefinition | Base/Pro/Team 等能力组合，不含渠道价格 | 版本化定义 |
| OfferDefinition | 某市场/渠道/时间可购买或兑换的商业提议 | 服务端 |
| SKU | 可下单的不可歧义标识，绑定 Offer 版本 | DB 商品目录 + DC 映射 |
| EntitlementPolicy | Grant 如何产生功能、期限、quota、seat | 服务端策略 |
| Grant | 有来源、有期限、可撤销的权益发放事实 | 不可变事件 + 当前投影 |
| WorkUnitDefinition | 用户可感知结果、计量单位和完成判据 | 产品注册，DC 校验 |
| Reservation/UsageEntry | 预占、完成、释放、补偿 | 不可变 UsageLedger |
| CampaignPolicy | 资格、证据、奖励、反欺诈、冷却 | 服务端版本化 |
| Attribution | 谁影响了哪次激活/订单/贡献 | 不可变事实 |
| ChannelPolicy | 角色、归因窗、奖励种类和优先级 | 服务端版本化 |
| Commission | 已计提但未必可提现的现金债务 | 不可变 CommissionLedger |
| Settlement | 一批成熟佣金的封账、支付和失败结果 | 服务端状态机 |
| CostEntry | provider token、现金成本、人工/基础设施分摊 | 不可变 CostLedger |
| WalletProjection | 各 bucket 的当前余额视图 | 可重建投影，非原始真值 |

### 7.1 关键不变量

- 每个 Grant 必有 `source_type/source_id/policy_version`；撤销只能追加 Reversal，不改历史。
- 同一 source + grant_rule + beneficiary 的发放唯一。
- 余额 = 全部已生效账本分录代数和；不得直接 `UPDATE balance` 作为真值。
- reserve 后只能 capture、release 或 expire；总 capture 不得超过 reserve，除非明确允许追加授权。
- 支付金额、币种、merchant、order snapshot 全匹配才可激活付费 Grant。
- 退款总额不超过可退余额；退款导致的权益回收与佣金冲正可重放且不重复。
- Commission 在退款/争议期结束前只能 `pending`，不得进入 payout。
- Base 用户自己的内容、基础导出和删除权不受 Grant 撤销影响。

## 8. 关键状态机

- **Offer**：draft → active → suspended/retired；已下单必须保留价格和政策快照。
- **Order/Payment**：复用 DeepBase 状态；只允许服务端通知推进 paid，乱序失败通知不得覆盖 paid。
- **Grant**：pending → active → expired；active → suspended/revoked；撤销追加 reversal。
- **Reservation**：reserved → captured | released | expired；部分完成可 partial-captured 后 release remainder。
- **CampaignClaim**：submitted → evidence_pending → qualified → granted；或 rejected/revoked；人工复核可 appeal。
- **Commission**：pending → mature → locked → payable → paid；任意未 paid 状态可 reversed；paid 后冲正形成负债/后续抵扣，不篡改旧批次。
- **SettlementBatch**：open → sealed → approved → paying → paid/partially_failed → reconciled。
- **Refund**：requested → approved → provider_pending → succeeded/failed → commerce_compensated → reconciled。

所有状态转换携带 `command_id`、actor、reason、expected_version；高风险转换要求 Admin 权限和双人/二次确认接口预留。

## 9. 关键账本与不变量

至少四本不可变账：

1. **Entitlement/Grant Ledger**：发放、延期、暂停、撤销、过期。
2. **Usage Ledger**：reserve/capture/release/compensate/expire，按 wallet bucket 分账。
3. **Commission Ledger**：计提、成熟、封账、冲正、支付。
4. **Cost Ledger**：LLM、外部 API、存储、人工服务等实际/估算成本。

真实现金支付仍以 DeepBase/DeepKit Payment/Refund 账为准；DC 保存引用与业务补偿，不另造支付真值。所有投影（余额、当前权益、渠道应付、活动进度）必须可从定义版本 + 不可变事件全量重建，并支持 checkpoint 后重放。

## 10. API / Command / Event 草案

### 10.1 客户端查询/命令

- `GET /commerce/v1/catalog?product_code=&market=`
- `GET /commerce/v1/me/entitlements`
- `GET /commerce/v1/me/wallets`
- `POST /commerce/v1/usage/reservations`（Idempotency-Key）
- `POST /commerce/v1/usage/{reservation_id}/capture|release`
- `POST /commerce/v1/campaigns/{id}/claims`
- `POST /commerce/v1/redemptions`
- `GET /commerce/v1/eligible-offers`

### 10.2 服务端/Admin 命令

`PublishDefinitionVersion`、`ActivateOffer`、`QualifyClaim`、`IssueGrant`、`RevokeGrant`、`RequestRefund`、`ReverseCommission`、`SealSettlementBatch`、`ApproveSettlement`、`RebuildProjection`、`ReconcileProvider`。

### 10.3 领域事件

`OfferPublished`、`PaymentConfirmed`、`GrantIssued/Revoked/Expired`、`UsageReserved/Captured/Released/Compensated`、`CampaignQualified`、`AttributionRecorded`、`CommissionAccrued/Matured/Reversed`、`SettlementPaid`、`RefundSucceeded`、`ProjectionRebuilt`。

外部副作用一律经事务 **Outbox**；消费者使用 **Inbox** 去重。支付 webhook、任务回调、活动证据、Grant、Usage、退款、佣金、结算均必须有幂等键。EventBus 可作为进程内分发，但不能替代持久 Outbox。

## 11. 本地、服务端和 Admin 部署边界

### 桌面本地允许

- 签名、带 `aud/product/device/subject/issued_at/not_before/expires_at/key_id/schema_version` 的 entitlement snapshot。
- 只读产品定义缓存、余额/使用投影、待同步 usage reservation（仅对政策明确允许离线的工作单元）。
- 产品业务数据、用户内容及可导出数据。

### 必须服务端

订单/支付/退款真值、钱包权威账、现金佣金、结算、活动资格终审、反欺诈、跨设备共享 quota、组织席位分配、Admin Grant、定义发布、签名密钥和全局对账。

### Admin 专属高风险权限

发布/撤回 Offer，人工 Grant/撤权，批准退款，豁免反欺诈，封账/解封，批准提现，重跑对账，投影重建切换，签名密钥轮换，组织所有权转移。运营人员只可提交，不默认批准；桌面 Admin 也必须调用服务端，不持 PG 超级凭据。

### 离线策略

只允许：已签名能力门禁、有限期限/有限额度、设备绑定、可接受双花风险的本地 reserve。现金、佣金、Campaign 资格、团队共享池和高价值工作单元不得离线最终确认。恢复联网后服务端可拒绝超限并采取“停止后续使用”而非劫持用户既有数据。

## 12. 多产品注册和配置机制

每个产品提交一个签名、版本化 `ProductPackage`：

```text
product.json
capabilities.json
plans.json
offers.json
work-units.json
entitlement-policies.json
usage-policies.json
campaign-policies.json
channel-policies.json
settlement-policies.json
```

定义必须含 `definition_id/version/effective_at/schema_version/content_hash`，发布后不可原地改；变更产生新版本。DC 做 schema、引用、循环、冲突、不变量和“数据人质”红线校验，再编译为：

- DeepBase product/entitlement 配置；
- 服务端政策快照；
- 客户端签名 capability manifest；
- Admin 可解释的 diff。

禁止产品代码上传可执行表达式。第一阶段使用声明式枚举/条件 AST；复杂 qualification 走注册的受控 evaluator，带版本和超时。

## 13. 价值工作单元设计

### 13.1 与 token 分离

必须分离。Work Unit 是用户购买的结果；token 是内部成本驱动。一次工作单元可调用多个模型、网页、本地算法和人工步骤。产品记录 `work_unit_code` 和完成判据，成本账记录每个 provider call。价格不随 token 自动等价变动。

### 13.2 生命周期

1. `QuoteUsage` 返回预计工作单元、包含额度、额外费用和 BYOK 路由。
2. `Reserve` 预占上限。
3. 产品执行任务并报告阶段性 artifact/checkpoint。
4. 满足完成判据则 `Capture`；部分完成按政策 capture 已交付部分并 release 余量。
5. 可重试故障复用同一 reservation/attempt group，不重复收费。
6. 无有效交付则 release；已扣后发现质量/系统故障则 compensate（反向分录）。

### 13.3 成本与价值

CostEntry 分 `direct_actual`（token/API）、`direct_estimated`、`infrastructure_allocated`、`human_service`；价值侧记录 `value_metric`（节省时间、风险降低、可交付 artifact）和用户反馈，但不将其伪装成会计事实。免费网页/本地算法即使边际成本低，仍可因编排、可靠性、验证、持续维护和交付结果成为付费工作单元。

### 13.4 降低按次焦虑

默认采用“订阅含宽松额度 + 透明用量 + 任务前报价 + 上限保护 + 失败不扣 + 宽限提示 + 可选自动加包”，避免每次点击显示零钱。工作单元宜按任务包/成果包而非细碎步骤计量。

### 13.5 订阅、加包与 BYOK

钱包按 bucket 分离：`subscription_included`（先到期先用）、`promotional`、`purchased`、`service_credit`；不得隐式兑换现金。BYOK 只改变成本路由：可免平台模型额度，但仍可扣产品编排/验证工作单元。平台额度不足时必须明确征得用户同意切 BYOK 或加包。

## 14. Base 免费传播与 Campaign / Grant

通用流程：`Campaign → Claim → Evidence → Qualification → Attribution/Fraud Check → Grant → Expiration/Redemption → Reversal/Audit`。

- **QualificationRule**：激活、首次有效工作、内容采纳、访谈完成等可验证条件。
- **EvidenceRequirement**：事件引用、脱敏 artifact hash、审核记录、授权版本；最小化收集。
- **GrantRule**：Pro 天数、Team 试用、工作单元、特定 capability、模板/插件、服务抵扣或佣金。
- **FraudRule**：自购、同设备/支付工具闭环、循环推荐、异常速率、撤销后重领。
- **Cooldown**：按 actor/campaign/reward 控制频率和总上限。
- **Attribution**：last/first/assisted 规则、窗口和冲突优先级版本化。
- **Reversal**：证据撤回、退款、欺诈确认后追加反向 Grant/Commission。
- **Expiration/Redemption**：到期和领取是不同事件；默认不自动把非现金奖励变现。
- **Audit**：谁提交、谁审核、证据 hash、规则版本、理由和申诉。

硬禁止项写入 policy validator：强制分享才能访问自有数据、群发/刷屏/强制好评、虚假宣传、骚扰裂变、未授权公开报告、数据不可导出/删除、退款期内结佣、自购/循环套利/刷单。用户撤回公开授权后停止后续展示；已给奖励是否收回需在活动前明示且符合合同/法律。

## 15. 推荐、渠道、佣金和结算

统一 `ChannelActor` 角色：referrer、affiliate、implementer、trainer、template_author、plugin_author、solution_partner、institution_introducer；一个主体可多角色。

分五类经济结果，绝不混账：

1. 软件权益奖励 → Grant Ledger；
2. 现金佣金 → Commission Ledger；
3. 服务收入 → 独立服务订单/交付验收；
4. 模板/插件收入 → Marketplace order + 作者分成；
5. 机构项目分成 → 项目合同与里程碑结算。

佣金在支付确认后计提为 pending，经过退款/争议期和交付条件后 mature；封账后才 payable。退款在 paid 前直接 reverse；已 payout 后生成负余额或下一批抵扣，禁止改历史。提现需要 beneficiary、KYC/tax status、payout method token、最低额、风险 hold；DeepCommerce 只定义接口和状态，不保存银行卡明文，不代替税务合规判断。服务端每日 provider 对账、批次封账、差异单和人工复核均留审计。

## 16. DeepAxis 映射示例

- ProductDefinition：`deepaxis`。
- Capability：联系人工作台、聊天摘要、个性化草稿、分群、诊断、多账号、插件 host 等；具体语义留 DeepAxis。
- Work Unit：`contact.organize`、`conversation.digest`、`sales.next_action` 等由 DeepAxis 注册完成判据和权重。
- DC 负责 reserve/capture/release、套餐包含量、促销 Grant、推荐归因、退款撤权、佣金成熟与冲正。
- 微信适配、账号上下文、CRM 数据、风险门禁、插件执行健康仍在 DeepAxis；插件只能调用 `RequestUsage/ReportOutcome`，不能发 Grant 或改余额。

可原样提升的是原则、契约形状、operation catalog 思路、reserve/release 模式、真值/投影分离、渠道分账和 Outbox/Inbox 测试场景；必须重命名并二产品验证的是 DeepAxis UsageLedger 具体字段和 PG schema。

## 17. DeepRW Base / Pro / Team 示例（非最终价格）

| 档位 | 产品定义的能力 | DC 通用支持 |
|---|---|---|
| Base | 基础研究、基础多模型比较、本地项目、基础导出、有限任务；自有数据永不锁 | 免费 Plan、月度工作单元 Grant、贡献 Campaign、基础快照 |
| Pro | 深度研究、引用核验、主张—证据审计、高级溯源报告、模板、更多模型/长任务、社群/服务 | 订阅 + included wallet + add-on、BYOK 混合政策、专业 capability Grant |
| Team | 团队项目、审阅/签发、团队模板、组织治理、机构部署/服务 | Organization、seat、共享 wallet、角色映射、审计与服务 Offer |

示例 Work Unit：`research.multi_model`、`research.deep`、`citation.verify`、`claim_evidence.audit`、`provenance.report`、`report.issue`、`team.review_flow`。DeepRW 必须定义每项的输入边界、完成 artifact、失败/部分完成判据和权重；DC 不理解“引用”或“主张”。

Base 可通过有效推荐、脱敏案例授权、模板/兼容性报告采纳、真实方法内容、访谈、翻译/测试/文档获得限时 Grant。不得把基础导出、删除或用户已有研究成果作为传播交换条件。

## 18. 从 DeepAxis 迁移到 DeepCommerce 的兼容策略

1. **冻结不重写**：先冻结 DA operation catalog、entitlement source 和 UsageLedger v1 契约。
2. **Anti-corruption adapter**：`DeepAxisCommerceAdapter` 把旧 operation/quota 映射到 DC work unit/wallet，不改 UI 主路径。
3. **影子双算**：同一任务让旧账和 DC simulator 计算，比较 reserve、capture、余额和补偿，不双扣。
4. **导入只追加**：旧余额转成带 `legacy_import` source 的 opening Grant；保留 hash、回执和幂等键。
5. **按能力切流**：先新工作单元，后促销，再渠道；支付/授权继续走 DeepBase。
6. **可回滚**：在证据窗口内旧系统仍为读真值；切换门以对账差异为零/可解释为条件。

## 19. 分阶段实施路线

### Phase 0：发现与裁决（当前）

冻结词汇、边界、不变量、红线；用 DeepAxis 与 DeepRW 做实例化评审。只产文档和 schema 草案。

### Phase 1：最小稳定内核

- 独立仓、Definition schemas/validator/versioning；
- WorkUnit + Usage reservation ledger；
- Grant/Entitlement policy 与 DeepBase entitlement adapter；
- 内存/SQLite simulator、投影重建、Outbox/Inbox contract；
- DeepAxis/DeepRW 两套示例包和 contract tests；
- 无真实资金、无现金钱包、无提现。

### Phase 2：Campaign 与非现金奖励

证据、资格、冷却、反欺诈、Grant/reversal/audit；先人工审核和模拟活动。

### Phase 3：付费编排

接 DeepKit 测试环境，Offer/SKU 编译、PaymentConfirmed → Grant、退款 Saga、对账；完成真实商户沙箱/小额验收后才标生产。

### Phase 4：渠道与佣金模拟

归因、pending/mature/reversal、结算批次模拟、KYC/tax/payout 接口桩；没有真实交易量不自动提现。

### Phase 5：组织与市场

Team seat/shared wallet；只有出现真实模板/插件交易需求后才做 marketplace 与作者结算。

## 20. 风险、红线与待老板裁决

### 20.1 主要风险

过度抽象、双系统真值、离线双花、把信用点误当现金、活动欺诈、部分退款无法公平撤权、定义版本漂移、佣金早结、团队共享池并发、历史导入不可解释、先做市场后无供需。

### 20.2 待老板裁决

1. 是否批准“独立仓库，但 Phase 1 以 DeepKit 内嵌服务模块部署”，而非 DeepBase 子模块或立即微服务？
2. `Credit` 中文是否统一称“工作单元/服务额度”，明确永不承诺提现，避免与现金余额混淆？
3. Base 每月额度是自动刷新、滚存上限，还是永久购买点优先级如何？
4. Campaign 的人工审核责任人、案例撤回后奖励处理和申诉窗口。
5. DeepRW 哪些成果算“有效完成”，部分完成如何计量；这是产品定义的首要输入。
6. Team 的组织所有者、席位回收、共享额度和成员离队数据归属。
7. 佣金归因采用 first、last 还是 assisted，多角色冲突如何分配。
8. 是否允许离线消耗少量 purchased work units；可接受的双花损失上限是多少。
9. 首个真实付费试点、退款窗口和履约承诺；在此之前不得冻结最终价格/毛利结论。

## 21. 事实、推断与方案假设

### 已由代码/当前文档验证的事实

- DeepBase 已有 Licensing、基础 Commerce、SafeClient、permission/quota、签名快照、设备/期限、订单支付契约、安全与桌面基础设施。
- DeepBase 生产边界要求客户端不直连 DB4、不持支付密钥；支付通知验签、金额/币种校验和幂等。
- DeepKit 当前不是已完成真实商户生产验收的系统。
- DeepAxis 有 Capability/Operation、UsageLedger reserve/release、配置化商业政策和同步 mock 雏形，并明确 CRM/插件不能改商业真值。
- DeepRW 的最新讨论已确认 Base/Pro/Team 和合规价值交换方向；旧 DeepCompare 定价文档与新定位冲突，只能视为历史材料。

### 架构推断（需通过实现验证）

- 四本账、定义编译器、独立仓 + 内嵌服务模块是当前最小复杂度方案。
- DeepAxis 本地 ledger 可经 adapter 迁移；具体字段仍需双算验证。
- Organization/seat 能同时覆盖 DeepRW Team 和未来产品，但尚缺第二个已运行团队实例。

### 商业假设（没有真实交易证据前不得写成事实）

- 用户愿意为某类工作单元付多少钱、订阅包含量、加包率、BYOK 偏好。
- Base 贡献活动能带来合规有效传播，且奖励成本低于获客价值。
- 推荐/实施/模板渠道会产生可持续成交。
- Pro/Team 的转化率、留存、退款率、支持成本、毛利和现金流。
- 高级溯源、审计、签发或团队协作是主要付费驱动。

## 最终明确判断

- **归属**：DeepCommerce 不应成为 DeepBase 子模块，也不宜与任一产品同仓。应建独立仓库/独立领域库；首期服务端能力以内嵌模块部署到 DeepKit，客户端通过独立 SDK/HTTP 契约接入，待真实规模证明后再拆独立服务。
- **第一阶段最小范围**：版本化产品/能力/Plan/Offer 定义，WorkUnit + reserve/capture/release/compensate，Grant/Entitlement policy，DeepBase adapter，不可变本地模拟账、投影重建、Outbox/Inbox 契约，以及 DeepAxis/DeepRW 双实例 contract tests。
- **现在绝对不要做**：第二套支付/License/签名系统；现金钱包和真实提现；自动税务/KYC；完整模板/插件市场；复杂动态定价；无上限离线共享额度；把 CRM/科研术语写进核心；大规模迁移 DeepAxis；宣称生产支付完成。
- **DeepAxis 可提升**：Capability/Operation 声明、价值工作单元、reserve/capture/release、失败补偿、策略集中、真值/投影分离、插件不可改账、Outbox/Inbox 场景、渠道分类和退款冲正原则。
- **必须留 DeepAxis**：微信/CRM/联系人/聊天/销售语义、具体 operation/倍率/价格、插件执行与适配、产品风险门禁和版本组合。
- **DeepRW 最小接入定义**：product code；Base/Pro/Team；capability 清单；7 类候选 work unit 的完成/失败/部分完成判据；基础导出与数据权利底线；额度和 BYOK 路由；Team seat/role 最小模型；首批 Campaign 的证据与奖励；非最终 Offer 假设。
- **必须标假设**：全部价格、包含量、付费意愿、传播转化、渠道效率、退款率、支持成本、毛利、现金流和“最美好顾客”画像，直到有真实触达、成交、交付与复购证据。
