# UniBase Tool Projects Integration

本目录只保留当前有效的下游集成文档。旧的后端认证/计费试验路线和旧商业化发布文档不再作为入口。

## 对外唯一入口

**[UniBase-Integration-OneFile.md](./UniBase-Integration-OneFile.md)** — 下游工程 / AI / 第三方接入 UniBase 的唯一入口文件，包含 DB1~DB4 规范、全模块清单、推荐接入组合、平台网站跳转流程。发给其它 AI 时只需发送此文件。

> 以下为内部参考文档。

## 集成指南

- [UniBase-Downstream-Integration.md](./UniBase-Downstream-Integration.md) - 下游工程接入 UniBase 的标准指南
- [Commerce-Backend-Adapter-Spec.md](./Commerce-Backend-Adapter-Spec.md) - 统一用户、订单、支付、权益的生产后端契约
- [IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md) - AboutFrame 集成实施指南
- [06.AntiTamper-Integration.md](./06.AntiTamper-Integration.md) - 防篡改机制集成指南
- [07.Project-Classification.md](./07.Project-Classification.md) - 项目分类与多租户规划

## 项目分类

### 单机运行

本地工具，无需多租户账号体系：

| # | 项目 | UI 框架 | AntiTamper | Unlock | AboutFrame |
|---|------|---------|------------|--------|------------|
| 1 | MoveC | VCL | 已接入 | - | 已接入 |
| 2 | TwoKeyRun | VCL | 待集成 | 已接入 | 待集成 |
| 3 | TransSuccess | VCL | 待集成 | 待集成 | 待集成 |
| 4 | uniSVG | VCL | 已接入 | 待集成 | 已接入 |
| 5 | EasyConfig | FMX | 待集成 | 待集成 | 待集成 |
| 6 | OmniSync | FMX | 待集成 | 待集成 | 待集成 |
| 7 | Touchstone | VCL | 待集成 | 待集成 | 待集成 |
| 8 | wyjx | VCL | 待集成 | 待集成 | 待集成 |
| 9 | Chain2VFactory | VCL | 待集成 | 待集成 | 待集成 |

### 需要统一用户/付款/权益

这些项目应走 `Features/UniBase.Commerce.*`，再用 `TCommerceHttpStorage` / `TCommerceHttpPaymentGateway` 对接真实后端：

| 项目 | 需求 |
|------|------|
| TheSenate | 用户账号 + Token 计费 + 账务中心 |
| Insight | 用户身份 + 数据同步 |
| InfoCenter | 用户账号 + 订阅会员 |
| DevDirector | 团队协作 + 云端项目 |
| TheLot | 用户账号 + 云存储 |
| 网页测评包/小程序 | 登录、下单、微信支付、权益发放 |

## root/config.db 和 AboutFrame

工具类项目仍按 `root.txt + {AppName}Config.db` 管理框架配置、日志、AboutFrame 图片和防篡改资源。

标准 `aboutMeImages` 表通过 SeedTool 创建/填充：

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

标准 ImageKey：

| ImageKey | 用途 |
|----------|------|
| official_gzh | 官方公众号二维码 |
| wechat | 微信收款码 |
| alipay | 支付宝收款码 |
| btc | BTC 钱包地址二维码 |
| usdt | USDT 钱包地址二维码 |
| aboutme | 关于我 |

## 认证与支付

UniBase 当前框架内只提供统一流程和接口：

- `Features/UniBase.Commerce.Types.pas`
- `Features/UniBase.Commerce.Storage.pas`
- `Features/UniBase.Commerce.Service.pas`
- `Features/UniBase.Commerce.Backend.Contract.pas`
- `Features/UniBase.Commerce.Backend.Http.pas`

生产环境还需要后端配合：

- 后端 HTTP API：保存用户、身份、商品、订单、支付记录、权益；UniBase 侧可用 `TCommerceHttpStorage` 接入。
- 支付意图 API：创建微信支付/支付宝等支付参数；UniBase 侧可用 `TCommerceHttpPaymentGateway` 接入。

客户端不要直接改订单和权益状态；支付成功必须以可信后端回调或可信服务确认为准。

后端表结构、API、通知验签和幂等规则见 [Commerce-Backend-Adapter-Spec.md](./Commerce-Backend-Adapter-Spec.md)。

## 项目集成文档

- [01.TwoKeyRun-Integration.md](./01.TwoKeyRun-Integration.md)
- [02.OmniSync-Integration.md](./02.OmniSync-Integration.md)
- [03.SVGThing-Integration.md](./03.SVGThing-Integration.md)
- [04.Stocks-Integration.md](./04.Stocks-Integration.md)
- [05.TransSuccess-Integration.md](./05.TransSuccess-Integration.md)

## SeedTool 文档

- [SeedTool_README.md](../Tools/SeedTool/SeedTool_README.md)
- [加密防篡改集成说明.md](../Tools/SeedTool/加密防篡改集成说明.md)
- [播种与主程序对应说明.md](../Tools/SeedTool/播种与主程序对应说明.md)
