# UniBase Tool Projects Integration

本目录包含各工具项目集成 UniBase AboutFrame 的规划文档。

## 概览

| # | 项目 | UI 框架 | 当前数据库 | 目标数据库 | 状态 | 预估时间 |
|---|------|---------|------------|------------|------|----------|
| 01 | TwoKeyRun | VCL | TwoKeyRun.db | TwoKeyRunConfig.db | 已有 Frame | 3-4h |
| 02 | OmniSync | FMX | SyncLocal.db | OmniSyncConfig.db | 需新建 | 4.5-5.5h |
| 03 | SVGThing | VCL | data.db | SVGThingConfig.db | 已有 Frame | 2h |
| 04 | Stocks/InfoCenter | FMX | InfoCenterConfig.db | InfoCenterConfig.db | 需新建 | 2h* |
| 05 | TransSuccess | VCL | 无 | TransSuccessConfig.db | 需新建 | 2.5h |

*注: Stocks/InfoCenter 依赖 FMX 版 AboutFrame，需先完成 OmniSync 的 FMX 组件开发

## 关键依赖

### VCL 项目
- `UniBase.VCL.AboutFrame` ✅ 已完成

### FMX 项目
- `UniBase.FMX.AboutFrame` ⏳ 待开发 (作为 OmniSync 集成的一部分)

## 建议执行顺序

1. **TwoKeyRun** (VCL, 已有 Frame) - 验证方案可行性
2. **SVGThing** (VCL, 已有 Frame) - 类似模式，快速复制
3. **TransSuccess** (VCL, 新建) - 简单集成
4. **OmniSync** (FMX, 新建) - 需开发 FMX 版组件
5. **Stocks/InfoCenter** (FMX, 新建) - 复用 FMX 组件

## 标准 aboutMeImages 表结构

```sql
CREATE TABLE IF NOT EXISTS aboutMeImages (
    image_key      TEXT PRIMARY KEY,
    image_data     BLOB,
    address_text   TEXT,
    sha256_hash    TEXT,
    hmac_signature TEXT,
    enabled        INTEGER DEFAULT 1
);
```

## 标准 ImageKeys

| Key | 描述 | Tab 名称 |
|-----|------|----------|
| `official_gzh` | 官方公众号二维码 | 公众号 |
| `wechat` | 微信收款码 | 微信 |
| `alipay` | 支付宝收款码 | 支付宝 |
| `btc` | BTC 钱包地址二维码 | BTC |
| `usdt` | USDT 钱包地址二维码 | USDT |
| `aboutme` | 个人介绍/名片 | 关于我 |

## SeedTool 通用命令

```batch
# 初始化表
SeedTool.exe --db {AppName}Config.db --init-table aboutMeImages

# 填充数据
SeedTool.exe --db {AppName}Config.db --seed-images ^
  --source UniBase/Tools/SeedTool/assets/ ^
  --keys official_gzh,wechat,alipay,btc,usdt,aboutme
```

## 文档列表

- [01.TwoKeyRun-Integration.md](01.TwoKeyRun-Integration.md)
- [02.OmniSync-Integration.md](02.OmniSync-Integration.md)
- [03.SVGThing-Integration.md](03.SVGThing-Integration.md)
- [04.Stocks-Integration.md](04.Stocks-Integration.md)
- [05.TransSuccess-Integration.md](05.TransSuccess-Integration.md)

## 总工时估算

| 类别 | 时间 |
|------|------|
| VCL 项目 (TwoKeyRun + SVGThing + TransSuccess) | ~7.5h |
| FMX 组件开发 | ~3h |
| FMX 项目 (OmniSync + Stocks) | ~3.5h |
| **总计** | **~14h** |
