# UniBase 开发任务

> **最后更新**: 2025-12-12
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
  - （可选）在后续 CI 环境中补充针对数据库 Integration Tests 的专用配置说明文档（如何启用 `UNIBASE_RUN_DB_INTEGRATION=1` 与 FireDAC/SQLite 驱动）。
  - 将已新增的测试单元逐步纳入统一测试入口（`Tests/UniBaseTests.dpr` / `Scripts/run_tests.ps1`），避免“写了但没跑”的覆盖率失真。
  - 检查 Test.UniBase.Config.pas 等被注释的测试单元与当前 API 的兼容性问题。
- **当前测试状态** (2025-12-13):
  - 单元测试: 265/267 通过 ✅ (从 181 增加到 267)
  - 集成测试: 9/9 通过 ✅
- **最近修复**:
  - BUG-068: I18nTexts 列名 LastUsedTime -> LastUsedAt
  - BUG-067: 主题 EFOpenError 问题 (IsStyleInList 替代 IsValidStyle)
- **新增测试模块**:
  - Test.UniBase.i18n (12 tests)
  - Test.UniBase.Theme (10 tests)
  - Test.UniBase.Updater (64 tests)
- **已完成工作**:
  - 已完成的大量测试模块（Math/Metrics/Net/HttpServer/FileWatcher/CLI/CloudBackup/Feedback 等）已记录在 `history.md` 中的 “MAINT-002: 单元测试覆盖率提升 🟡” 小节，此处不再重复列出。

### 商业化与工具集成 (P1)

#### PUBL-105: 工具项目接入 AboutFrame + aboutMeImages（TwoKeyRun / OmniSync / 其它）
- **状态**: 🟡 进行中（UniBase 侧开发已完成，待人工集成）
- **优先级**: P1
- **实施指南**: `docs/integrations/IMPLEMENTATION_GUIDE.md`
- **已完成**:
  - ✅ 5 个工具项目集成规划文档（见 `docs/integrations/`）
  - ✅ VCL 版 AboutFrame：`VCL/UniBase.VCL.AboutFrame.pas`（6 个 Tab，含公众号）
  - ✅ FMX 版 AboutFrame：`FMX/UniBase.FMX.AboutFrame.pas`（6 个 Tab，已对齐 AntiTamper）
  - ✅ SeedTool（GUI）已包含 Enabled 字段、可播种 `aboutMeImages`
  - ✅ IMPLEMENTATION_GUIDE.md 文档已更新（2025-12-12）
- **待人工完成（集成）**:
  - [ ] 准备 6 张标准图片资源
  - [ ] 运行 SeedTool 为各项目创建 `*Config.db` 并播种 6 个标准 key
  - [ ] 在 IDE 中按指南修改各项目代码并编译测试

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
