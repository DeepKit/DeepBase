# UniBase 开发任务

> **最后更新**: 2025-12-11
> **项目状态**: 核心完成，扩展开发中

---

## 文档导航

| 文档 | 说明 |
|------|------|
| **[history.md](history.md)** | 已完成任务记录 (80+ 任务) |
| **[bugfix.md](bugfix.md)** | Bug 修复记录 (60+ Bug) |
| **[tasks_next.md](tasks_next.md)** | 后续扩展任务规划 |
| **[README.md](README.md)** | 项目说明 |

---

## 项目进度概览

| 阶段 | 状态 | 完成日期 |
|------|------|----------|
| Phase 0: 最小核心 | ✅ 完成 | 2025-11-27 |
| Phase 1: 推荐功能 | ✅ 完成 | 2025-11-27 |
| Phase 2: 扩展功能 | ✅ 完成 | 2025-11-27 |
| Phase 3: 高级功能 | ✅ 完成 | 2025-11-27 |
| Phase 4: 完善与文档 | ✅ 完成 | 2025-11-27 |
| Phase 5: 代码审查优化 | ✅ 完成 | 2025-11-28 |
| Phase P0: 商业化基础 | ✅ 完成 | 2025-12-09 |
| Phase P1: 商业化扩展 | ✅ 完成 | 2025-12-10 |
| Phase P2: 工具与CLI | ✅ 完成 | 2025-11-29 |
| Phase MAINT: 维护优化 | 🟡 进行中 | - |

---

## 待开发任务

### 进行中 (MAINT)

#### MAINT-002: 单元测试覆盖率提升至 95%+
- **状态**: 🟡 进行中
- **优先级**: P0
- **目标**:
  - 单元测试整体覆盖率提升到 95%+，并确保关键安全/网络模块有稳定回归测试。
- **下一步任务**:
  - 将覆盖率统计集成到 `Scripts/run_tests.ps1` 与 CI/CD 流程，生成 HTML/XML 覆盖率报告。
  - （可选）进一步稳定数据库相关 Integration Tests（FireDAC/SQLite 驱动配置），或在默认集成测试运行中将其标记为「环境依赖」测试。
- **已完成工作**:
  - 已完成的大量测试模块（Math/Metrics/Net/HttpServer/FileWatcher/CLI/CloudBackup/Feedback 等）已记录在 `history.md` 中的 “MAINT-002: 单元测试覆盖率提升 🟡” 小节，此处不再重复列出。

### 商业化与工具集成 (P1)

#### PUBL-101: AboutFrame + AntiTamper 规范与文档更新
- **状态**: 🔲 待开始
- **优先级**: P1
- **内容**:
  - 在 `04.01.uniBase-4AI-数据库Schema说明-v1.0.md` 中明确定义 `aboutMeImages` 表结构，新增 `enabled INTEGER NOT NULL DEFAULT 1` 字段，约定 6 个标准 key（official_gzh / wechat / alipay / btc / usdt / aboutme）。
  - 在 `10.01.uniBase-4AI-发布更新解锁集成指南-v1.0.md` 中补充 AboutFrame 接入规范：DB1 = `{AppName}Config.db`（目标规范）、最小尺寸 600×320、「公司公众号」页签文案与跳转 `https://www.goodmem.cn/tools`。
  - 在 `10.03.uniBase-4H-私域流量运营指南-v1.0.md` 中增加“关于页面推荐结构”小节，说明与公众号/解锁体系的关系。

#### PUBL-102: 实现 UniBase.AntiTamper 与 UniBase.VCL.AboutFrame
- **状态**: 🔲 待开始
- **优先级**: P1
- **内容**:
  - 从 `uAntiTamperPackage` / `uBasicProtection` 抽象出 `UniBase.AntiTamper`，提供统一的初始化与 `LoadSecureImage` API，默认表名为 `aboutMeImages`。
  - 在 `UniBase.VCL.AboutFrame` 中实现 About/打赏/公司公众号通用 Frame：6 个 Tab（公司公众号/微信/支付宝/BTC/USDT/关于我），从 DB1 的 `aboutMeImages` 表按 key 读取图像和文本，按 `enabled` 控制显隐。
  - 对接 `UniBase.i18n`，预留文案本地化能力。

#### PUBL-103: SeedTool aboutMeImages + enabled 改造
- **状态**: 🔲 待开始
- **优先级**: P1
- **内容**:
  - 将 SeedTool 默认目标表从 `images` 迁移为 `aboutMeImages`，并支持新字段 `enabled`（0/1）。
  - 在 SeedTool UI 中增加启用勾选或列，允许为 each image_key（official_gzh / wechat / alipay / btc / usdt / aboutme）控制是否在 AboutFrame 中显示。
  - 同步更新 `加密防篡改集成说明.md` 与 `播种与主程序对应说明.md` 的表结构与示例 SQL。

#### PUBL-104: MoveC 参考实现对齐新规范
- **状态**: 🔲 待开始
- **优先级**: P1
- **内容**:
  - 将 MoveC 当前使用的 `images` 表迁移/改名为 `aboutMeImages`，增加 `enabled` 字段并默认置为 1。
  - 逐步将 MoveC 的配置数据库命名统一为目标规范（例如 `MoveCConfig.db`），并更新 `FrameAboutMe` 中的连接与 `FDTable1.TableName`。
  - 使用 SeedTool 为 aboutMeImages 表补齐 6 个 key（official_gzh / wechat / alipay / btc / usdt / aboutme），作为 UniBase.VCL.AboutFrame 的演示样例数据库。
  - 同步更新 `02.MoveC-Integration.md` 文档，标注“现状 vs 目标规范”。

#### PUBL-105: 工具项目接入 AboutFrame + aboutMeImages（TwoKeyRun / OmniSync / 其它）
- **状态**: 🔲 待开始
- **优先级**: P1
- **内容**:
  - TwoKeyRun: 规划/实现 DB1（目标名 `TwoKeyRunConfig.db`），在其 DB1 中创建 `aboutMeImages` 表并通过 SeedTool 播种 6 个 key；在主窗体 About/帮助区域嵌入 UniBase.VCL.AboutFrame，并验证与解锁/公众号流程的一致性。
  - OmniSync: 规划/实现 DB1（目标名 `OmniSyncConfig.db`），按同样模式接入 AboutFrame 与公司公众号页签。
  - SVGThing / Stocks / TransSuccess 等其它 GUI 工具：分别创建 `0X.ProjectName-Integration.md`，记录现状 DB1 名称与目标 `{AppName}Config.db`，并规划接入 AboutFrame + aboutMeImages 的步骤。

---

### 低优先级 (P3)

#### ECO-002: 社区扩展包 (持续)
- **状态**: 🟡 进行中
- **性质**: ThirdParty 可选扩展（非 Core 核心功能）
- **已完成阶段**:
  - 第一批扩展（PostgreSQL/MySQL 驱动、UI 主题包、云存储集成）已记录在 `history.md` 的 “ECO-002: 社区扩展包（第一阶段）” 小节，此处不再重复细节。
- **下一步任务**:
  - [ ] 支付接口集成 (`ThirdParty/Payment/`) - Stripe/PayPal/Alipay
  - [ ] 社交媒体集成 (`ThirdParty/Social/`) - WeChat/Weibo/Twitter
- **开发指南**:
  - 参考 [06.01.uniBase-4H-ThirdParty扩展开发指南-v1.0.md](docs/06.01.uniBase-4H-ThirdParty扩展开发指南-v1.0.md)
  - 参考已实现的 `ThirdParty/Cloud/UniBase.Cloud.Storage.pas` 模式

#### DOC-004: 视频教程
- **状态**: 🔲 待开始
- **优先级**: P3
- **内容**:
  - [ ] 快速入门视频
  - [ ] 模块深度讲解
  - [ ] 实战案例演示

---

## 性能基准

| 操作 | 目标 | 实际 |
|------|------|------|
| Config 读取 (缓存) | < 1ms | ✅ |
| Config 写入 | < 10ms | ✅ |
| 日志写入 10000条 | < 5s | ✅ 3s |
| i18n 查询 | < 0.5ms | ✅ |

---

## Schema 迁移

升级脚本位置: `sql/upgrade_v{old}_to_v{new}.sql`

---

**维护者**: 李冰、鲁班、Claude
