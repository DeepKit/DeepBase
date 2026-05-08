# DeepBase Tool Projects Integration

> 更新日期: 2026-05-07
> 对接状�? RC 候选。P0/P1/P2 框架阻塞项已清空；正式封版前等待 LLM �?SQLite+PostgreSQL 统一适配层合并后再跑全量门禁�?
本目录只保留当前有效的下游集成文档。旧的后端认�?计费试验路线和旧商业化发布文档不再作为入口�?
## 对外唯一入口

**[DeepBase-Integration-OneFile.md](./DeepBase-Integration-OneFile.md)** �?下游工程 / AI / 第三方接�?DeepBase 的唯一入口文件，包含当�?RC 状态、DB1~DB4 边界、包编译顺序、初始化方式、Security/Resilience/LLM/Speech/Commerce 对接规则和封版前检查清单。发给其�?AI 或下游团队时只需发送此文件�?
> 以下为内部参考文档�?
## 集成指南

- [DeepBase-Downstream-Integration.md](./DeepBase-Downstream-Integration.md) - 下游工程接入 DeepBase 的标准执行指南，适合开发负责人拆任�?- [Commerce-Backend-Adapter-Spec.md](./Commerce-Backend-Adapter-Spec.md) - 统一用户、订单、支付、权益的生产后端契约
- [IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md) - AboutFrame 集成实施指南
- [06.AntiTamper-Integration.md](./06.AntiTamper-Integration.md) - 防篡改机制集成指�?- [07.Project-Classification.md](./07.Project-Classification.md) - 项目分类与多租户规划

## 项目分类

### 单机运行

本地工具，无需多租户账号体系：

| # | 项目 | UI 框架 | AntiTamper | Unlock | AboutFrame |
|---|------|---------|------------|--------|------------|
| 1 | DeepDeepDeepDeepDeepMoveC | VCL | 已接�?| - | 已接�?|
| 2 | TwoKeyRun | VCL | 待集�?| 已接�?| 待集�?|
| 3 | DeepCharset | VCL | 待集�?| 待集�?| 待集�?|
| 4 | DeepSVG | VCL | 已接�?| 待集�?| 已接�?|
| 5 | EasyConfig | FMX | 待集�?| 待集�?| 待集�?|
| 6 | DeepSync | FMX | 待集�?| 待集�?| 待集�?|
| 7 | DeepCompare | VCL | 待集�?| 待集�?| 待集�?|
| 8 | wyjx | VCL | 待集�?| 待集�?| 待集�?|
| 9 | Chain2VFactory | VCL | 待集�?| 待集�?| 待集�?|

### 需要统一用户/付款/权益

这些项目应走 `Features/DeepBase.Commerce.*`，再�?`TCommerceHttpStorage` / `TCommerceHttpPaymentGateway` 对接真实后端�?
| 项目 | 需�?|
|------|------|
| TheSenate | 用户账号 + Token 计费 + 账务中心 |
| DeepDeepDeepDeepDeepInsight | 用户身份 + 数据同步 |
| InfoCenter | 用户账号 + 订阅会员 |
| DevDirector | 团队协作 + 云端项目 |
| TheLot | 用户账号 + 云存�?|
| 网页测评�?小程�?| 登录、下单、微信支付、权益发�?|

## root/config.db �?AboutFrame

工具类项目仍�?`root.txt + {AppName}Config.db` 管理框架配置、日志、AboutFrame 图片和防篡改资源�?
标准 `aboutMeImages` 表通过 SeedTool 创建/填充�?
```sql
CREATE TABLE IF NOT EXISTS aboutMeImages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  image_key TEXT NOT NULL UNIQUE,
  image_data BLOB NOT NULL,
  address_text TEXT,
  description TEXT,
  enabled INTEGER NOT NULL DEFAULT 1,
  sha256_hash TEXT NOT NULL,
  hmac_sha256 TEXT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

标准 ImageKey�?
| ImageKey | 用�?|
|----------|------|
| official_gzh | 官方公众号二维码 |
| wechat | 微信收款�?|
| alipay | 支付宝收款码 |
| btc | BTC 钱包地址二维�?|
| usdt | USDT 钱包地址二维�?|
| aboutme | 关于�?|

## 认证与支�?
DeepBase 当前框架内只提供统一流程和接口：

- `Features/DeepBase.Commerce.Types.pas`
- `Features/DeepBase.Commerce.Storage.pas`
- `Features/DeepBase.Commerce.Service.pas`
- `Features/DeepBase.Commerce.Backend.Contract.pas`
- `Features/DeepBase.Commerce.Backend.Http.pas`

生产环境还需要后端配合：

- 后端 HTTP API：保存用户、身份、商品、订单、支付记录、权益；DeepBase 侧可�?`TCommerceHttpStorage` 接入�?- 支付意图 API：创建微信支�?支付宝等支付参数；DeepBase 侧可�?`TCommerceHttpPaymentGateway` 接入�?
客户端不要直接改订单和权益状态；支付成功必须以可信后端回调或可信服务确认为准�?
后端表结构、API、通知验签和幂等规则见 [Commerce-Backend-Adapter-Spec.md](./Commerce-Backend-Adapter-Spec.md)�?
## 项目集成文档

- [01.TwoKeyRun-Integration.md](./01.TwoKeyRun-Integration.md)
- [02.DeepSync-Integration.md](./02.DeepSync-Integration.md)
- [03.SVGThing-Integration.md](./03.SVGThing-Integration.md)
- [04.Stocks-Integration.md](./04.Stocks-Integration.md)
- [05.DeepCharset-Integration.md](./05.DeepCharset-Integration.md)

## SeedTool 文档

- [SeedTool_README.md](../Tools/SeedTool/SeedTool_README.md)
- [加密防篡改集成说�?md](../Tools/SeedTool/加密防篡改集成说�?md)
- [播种与主程序对应说明.md](../Tools/SeedTool/播种与主程序对应说明.md)
