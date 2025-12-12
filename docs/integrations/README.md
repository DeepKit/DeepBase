# UniBase Tool Projects Integration

本目录包含各工具项目集成 UniBase AboutFrame 的规划文档。

## 概览

| # | 项目 | UI 框架 | 当前数据库 | 目标数据库 | 状态 | 预估时间 |
|---|------|---------|------------|------------|------|----------|
| 01 | TwoKeyRun | VCL | TwoKeyRun.db | TwoKeyRunConfig.db | 已有 Frame | 3-4h |
| 02 | OmniSync | FMX | SyncLocal.db | OmniSyncConfig.db | 需新建 | 4.5-5.5h |
| 03 | SVGThing | VCL | data.db | SVGThingConfig.db | 已有 Frame | 2h |
| 04 | Stocks/InfoCenter | FMX | InfoCenterConfig.db | InfoCenterConfig.db | 需新建 | 2h |
| 05 | TransSuccess | VCL | 无 | TransSuccessConfig.db | 需新建 | 2.5h |

## 关键依赖

### VCL 项目
- `UniBase.VCL.AboutFrame` OK

### FMX 项目
- `UniBase.FMX.AboutFrame` OK（需与 SeedTool/AntiTamper 校验对齐）

## 建议执行顺序

1. **TwoKeyRun** (VCL, 已有 Frame) - 验证方案可行性
2. **SVGThing** (VCL, 已有 Frame) - 类似模式，快速复制
3. **TransSuccess** (VCL, 新建) - 简单集成
4. **OmniSync** (FMX, 新建) - 需开发 FMX 版组件
5. **Stocks/InfoCenter** (FMX, 新建) - 复用 FMX 组件

## 标准 aboutMeImages 表结构

以下为实际数据库表（通过 SeedTool 创建/填充）：

```sql
CREATE TABLE IF NOT EXISTS aboutMeImages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  image_key TEXT NOT NULL UNIQUE,
  image_data BLOB NOT NULL,              -- AES-256 加密的图像数据(SeedTool 写入)
  address_text TEXT,
  description TEXT,
  enabled INTEGER NOT NULL DEFAULT 1,    -- 0=隐藏, 1=显示
  sha256_hash TEXT NOT NULL,             -- 解密后 SHA-256
  hmac_sha256 TEXT NOT NULL,             -- 解密后 HMAC-SHA256
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## 标准 ImageKeys

| ImageKey | 对应页签 | 用途 |
|----------|----------|------|
| official_gzh | 公众号 | 官方公众号二维码 |
| wechat | 微信 | 微信收款码 |
| alipay | 支付宝 | 支付宝收款码 |
| btc | BTC | BTC 钱包地址二维码 |
| usdt | USDT | USDT 钱包地址二维码 |
| aboutme | 关于我 | 开发者照片/介绍 |

## SeedTool 使用方式(GUI)

仓库内 SeedTool 当前以 GUI 方式使用(未实现 CLI 参数)。

1. 运行 SeedTool.exe
2. 选择目标数据库(建议命名: {AppName}Config.db)
3. 初始化 aboutMeImages 表(如不存在)
4. 导入 6 张图片并填写 key / 地址文本 / enabled
5. 点击"播种"，再点击"查看数据"确认

更详细步骤见: IMPLEMENTATION_GUIDE.md

## 支付集成

UniBase 不直接实现支付渠道 SDK(Stripe/微信/PayPal 等)。

请使用 AipexBase 后端提供的统一支付网关: ../ThirdParty/AipexBase/

- 参考: UniBase.AipexBase.GeneralOrder.pas + README.md
- 所有支付操作由 AipexBase 后端承担

## 总工时估算

| 类别 | 时间 |
|------|------|
| VCL 项目 (TwoKeyRun + SVGThing + TransSuccess) | ~7.5h |
| FMX 组件开发 | ~3h |
| FMX 项目 (OmniSync + Stocks) | ~3.5h |
| **总计** | **~14h** |

## 文档列表

- 01.TwoKeyRun-Integration.md
- 02.OmniSync-Integration.md
- 03.SVGThing-Integration.md
- 04.Stocks-Integration.md
- 05.TransSuccess-Integration.md
- IMPLEMENTATION_GUIDE.md
