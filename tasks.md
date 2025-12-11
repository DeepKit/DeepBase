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
-  - （可选）在后续 CI 环境中补充针对数据库 Integration Tests 的专用配置说明文档（如何启用 UNIBASE_RUN_DB_INTEGRATION 与 FireDAC/SQLite 驱动）。
- **已完成工作**:
  - 已完成的大量测试模块（Math/Metrics/Net/HttpServer/FileWatcher/CLI/CloudBackup/Feedback 等）已记录在 `history.md` 中的 “MAINT-002: 单元测试覆盖率提升 🟡” 小节，此处不再重复列出。

### 商业化与工具集成 (P1)

#### PUBL-105: 工具项目接入 AboutFrame + aboutMeImages（TwoKeyRun / OmniSync / 其它）
- **状态**: 🟡 进行中 (规划完成)
- **优先级**: P1
- **规划文档**: `docs/integrations/README.md`
- **已完成**:
  - ✅ 5个工具项目集成规划文档:
    - `01.TwoKeyRun-Integration.md` - VCL, 已有Frame, 3-4h
    - `02.OmniSync-Integration.md` - FMX, 需新建, 4.5-5.5h (含FMX组件开发)
    - `03.SVGThing-Integration.md` - VCL, 已有Frame, 2h
    - `04.Stocks-Integration.md` - FMX, 需新建, 2h
    - `05.TransSuccess-Integration.md` - VCL, 需新建, 2.5h
  - ✅ 总工时估算: ~14h
- **待实施**:
  - [ ] VCL项目实施 (TwoKeyRun → SVGThing → TransSuccess)
  - [ ] 创建 `UniBase.FMX.AboutFrame.pas` (FMX版组件)
  - [ ] FMX项目实施 (OmniSync → Stocks/InfoCenter)

#### PUBL-106: UniPublisher 配置模型与 version.json 统一规范落地 ✅
- **状态**: ✅ 完成
- **完成日期**: 2025-12-11
- **内容摘要**:
  - 新增 `Publisher.Config.pas`: `TPublishConfig` 配置模型、`TPublishConfigMRU` MRU 管理
  - 新增 `Publisher.Manifest.pas`: `TVersionManifest` 新版格式、`TManifestGenerator` 新旧格式生成
  - 扩展 `UniBase.AutoUpdate.pas`: 自动识别新版/旧版 version.json 格式
  - 重构 `UniPublisher.MainForm.pas`: 集成配置加载/保存和 MRU 下拉框
  - 新增单元测试 `Test.UniBase.PublishConfig.pas`: 26 个测试用例

#### PUBL-107: UniPublisher 发布目标与开发体验优化 ✅
- **状态**: ✅ 完成
- **完成日期**: 2025-12-11
- **内容摘要**:
  - 新增 `Tools/UniPublisher/Core/Publisher.Targets.pas` (~895 行): TPublishResult/TPublishResults/TValidationResult 结果类型，TTargetValidator 配置验证，THttpPublisher/TGitHubPublisher/TGiteePublisher 三类发布器，TUnifiedPublisher 统一发布入口
  - 增强 `UniPublisher.MainForm.pas`: 右侧状态面板（目标状态指示灯 + 验证按钮），快捷操作按钮（重新加载配置/打开输出目录/打开 version URL/一键发布），发布日志 Memo
  - GitHub 发布通过 gh CLI 执行，输出命令和 Release URL；Gitee 发布通过 HTTP API + Access Token

#### PUBL-108: Developer Test Center + UniPublisher 集成参考实现 ✅
- **状态**: ✅ 完成
- **完成日期**: 2025-12-11
- **内容摘要**:
  - 新增 `Core/UniBase.TestCenter.pas` (~636 行): TTestCategory/TTestItem/TTestStatus 测试模型，ITestRunner 接口，TTestCenterManager 测试管理器，TStandardCategories 标准分类
  - 新增 `VCL/UniBase.VCL.TestCenterFrame.pas` (~655 行): 左树（分类）/中列表（测试项）/右详情（日志）/底部控制区布局，"打开 UniPublisher..." 按钮通过 ShellExecute 启动
  - 在 `Examples/FullDemo/FullDemo.MainForm.pas` 中集成测试中心页签，注册示例测试用例

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
