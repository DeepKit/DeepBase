# UniBase 开发任务

> **最后更新**: 2025-12-15
> **项目状态**: 核心完成，AipexBase 集成中

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
  - 将新增/修复的测试单元逐步纳入统一测试入口（`Tests/UniBaseTests.dpr` / `Scripts/run_tests.ps1`），并在 README/Docs 中明确一键测试命令。
  - 检查 `Test.UniBase.Config.pas` 等被注释的测试单元与当前 API 的兼容性问题（能恢复则恢复，不能则删除/重写，避免长期“注释债务”）。
- **当前测试状态** (2025-12-14):
  - 单元测试: 345/345 通过 ✅ (+22 LLM/DPAPI 测试)
  - 集成测试: 9/9 通过 ✅
- **备注**:
  - Unit 测试入口 `Tests/UniBaseTests.dpr` 已恢复包含 `Test.UniBase.FormState` / `Test.UniBase.Logging` / `Test.UniBase.License`。
  - Bug 修复记录统一写入 `bugfix.md`。
  - 已完成的测试模块清单见 `history.md` 中 “MAINT-002: 单元测试覆盖率提升 🟡” 小节。

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

### LLM 集成 (P2)

#### LLM-001: Delphi LLM 客户端封装库
- **状态**: ✅ 完成 (2025-12-14)
- **优先级**: P2
- **相关文档**: `../远程Delphi客户端连接和LLM调用指南.md`
- **实现文件**: `Core/UniBase.LLM.BillingClient.pas`
- **已完成**:
  - [x] `TBillingClient` 轻量级客户端（不依赖数据库）
  - [x] 流式/非流式响应支持 (SSE 解析)
  - [x] `TChatHistory` 对话历史管理
  - [x] 自定义异常层次 (`EBillingError`, `EBillingAuthError`, `EBillingBalanceError`, `EBillingRateLimitError`)
  - [x] 重试机制 (`ChatWithRetry` 指数退避)
  - [x] 请求取消 (`Cancel`)
  - [x] 异步调用 (`ChatAsync`)

#### LLM-002: API Key 安全存储模块
- **状态**: ✅ 完成 (2025-12-14)
- **优先级**: P2
- **实现文件**: `Core/UniBase.Security.DPAPI.pas`
- **已完成**:
  - [x] `TDPAPIHelper` - Windows DPAPI 加密/解密
  - [x] `ProtectString` / `UnprotectString` 字符串加解密
  - [x] `ProtectToFile` / `UnprotectFromFile` 文件加解密
  - [x] `TCredentialManager` - Windows Credential Manager 集成
  - [x] `TSecureString` - 安全字符串（自动清除内存）

#### LLM-003: VCL/FMX LLM 聊天组件
- **状态**: ✅ 完成 (2025-12-14)
- **优先级**: P3
- **实现文件**:
  - `VCL/UniBase.VCL.LLMChatFrame.pas`
  - `FMX/UniBase.FMX.LLMChatFrame.pas`
- **已完成**:
  - [x] VCL 聊天 Frame（RichEdit 支持富文本）
  - [x] FMX 聊天 Frame（跨平台）
  - [x] 流式文本逐字显示
  - [x] 取消按钮/加载状态
  - [x] 历史记录导出

#### LLM-004: LLM 模块单元测试
- **状态**: ✅ 完成 (2025-12-14)
- **优先级**: P2
- **测试文件**:
  - `Tests/Test.UniBase.LLM.BillingClient.pas` (22 测试用例)
  - `Tests/Test.UniBase.Security.DPAPI.pas` (23 测试用例)
- **测试覆盖**:
  - [x] `TChatMessage` 消息记录测试
  - [x] `TChatHistory` 历史管理测试
  - [x] `TBillingClient` 属性/URL 处理测试
  - [x] `TDPAPIHelper` 加解密测试
  - [x] `TCredentialManager` 凭据管理测试
  - [x] `TSecureString` 安全字符串测试

---

### AipexBase 集成 (P0)

#### AIPEX-001: 用户认证与计费 UI 组件
- **状态**: ✅ 前端完成，等待后端 (2025-12-15)
- **优先级**: P0
- **API 文档**: `docs/api/前端对接后端用户认证、计费指南.md`
- **已完成 (前端)**:
  - [x] `Core/UniBase.AipexBase.Client.pas` - API 客户端
  - [x] VCL 组件 (7个): LoginDialog, RegisterDialog, ForgotPasswordDialog, UserProfileFrame, BalanceFrame, UsageStatsFrame, BillingFrame
  - [x] FMX 组件 (7个): 同上 FMX 版本
  - [x] `Examples/UserAuthDemo/` - VCL 演示程序
  - [x] `docs/ui/svg/` - 7 个 UI 线框图
  - [x] `docs/integrations/AipexBase-Integration.md` - 集成指南
- **等待后端 (Phase 6)**:
  - [ ] POST /api/auth/login
  - [ ] POST /api/auth/register
  - [ ] POST /api/auth/forgot-password
  - [ ] POST /api/auth/refresh
  - [ ] GET /api/user/profile
  - [ ] GET /api/billing/balance
  - [ ] POST /api/billing/recharge
  - [ ] GET /api/billing/transactions
  - [ ] GET /api/billing/invoices

#### AIPEX-002: LLM 调用与用量统计 UI
- **状态**: ✅ 前端完成，等待后端 (2025-12-15)
- **优先级**: P0
- **API 文档**: `docs/api/前端对接后端LLM能力与计费指南.md`
- **已完成 (前端)**:
  - [x] `VCL/UniBase.VCL.UsageStatsFrame.pas` - VCL 用量统计
  - [x] `FMX/UniBase.FMX.UsageStatsFrame.pas` - FMX 用量统计
  - [x] `VCL/UniBase.VCL.LLMChatFrame.pas` - VCL 聊天界面
  - [x] `FMX/UniBase.FMX.LLMChatFrame.pas` - FMX 聊天界面
- **等待后端 (Phase 5-6)**:
  - [ ] POST /api/llm/chat/completions (流式)
  - [ ] GET /api/llm/models
  - [ ] GET /api/usage/summary
  - [ ] GET /api/usage/trend
  - [ ] GET /api/usage/models
  - [ ] GET /api/usage/calls

#### AIPEX-003: 前后端联调测试
- **状态**: 🔲 待后端就绪
- **优先级**: P0
- **任务**:
  - [ ] 后端部署开发环境 (http://localhost:8090)
  - [ ] 运行 UserAuthDemo 测试登录/注册
  - [ ] 测试余额充值流程 (沙箱支付)
  - [ ] 测试 LLM 调用和计费
  - [ ] 测试用量统计数据展示
  - [ ] 修复前后端字段对接问题

---

### 低优先级 (P3)

#### ECO-002: 社区扩展包 (持续)
- **状态**: 🟡 进行中
- **性质**: ThirdParty 可选扩展（非 Core 核心功能）
- **已完成阶段**:
  - 第一批扩展（PostgreSQL/MySQL 驱动、UI 主题包、云存储集成）已记录在 `history.md` 的 "ECO-002: 社区扩展包（第一阶段）" 小节
  - 支付接口集成 (2025-12-15):
    - [x] `ThirdParty/Payment/UniBase.Payment.pas` - 统一支付接口
    - [x] `ThirdParty/Payment/UniBase.Payment.Alipay.pas` - 支付宝实现
    - [x] `ThirdParty/Payment/UniBase.Payment.WeChatPay.pas` - 微信支付实现 (APIv3)
    - [x] `ThirdParty/Payment/UniBase.Payment.Stripe.pas` - Stripe 实现
  - 社交媒体集成 (2025-12-15):
    - [x] `ThirdParty/Social/UniBase.Social.pas` - 统一社交接口
    - [x] `ThirdParty/Social/UniBase.Social.OAuth.pas` - OAuth 2.0 通用实现 (GitHub/Google)
    - [x] `ThirdParty/Social/UniBase.Social.WeChat.pas` - 微信登录实现
- **下一步任务**:
  - [ ] 支付接口扩展: PayPal
  - [ ] 社交媒体扩展: Weibo/QQ
- **开发指南**:
  - 参考 [06.01.uniBase-4H-ThirdParty扩展开发指南-v1.0.md](docs/06.01.uniBase-4H-ThirdParty扩展开发指南-v1.0.md)
  - 参考已实现的 `ThirdParty/Cloud/UniBase.Cloud.Storage.pas` 模式
  - 支付接口文档: `ThirdParty/Payment/README.md`

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
