# UniFlow 开发任务清单

> 更新日期: 2025-12-07
>
> **当前状态: UniFlow v1.0 开发完成** ✅
>
> UniFlow Workflow Engine v1.0 功能完整，所有计划任务已完成。

---

## 已完成里程碑

### 核心开发里程碑

| 里程碑 | 内容 | 状态 |
|---------|------|------|
| M1 | 核心框架 (Phase 1-3) | ✅ |
| M2 | 完整流程 (Phase 4-6) | ✅ |
| M3 | 生产就绪 (Phase 7-8) | ✅ |
| P2 | 可选增强 (Audit/Metrics/Skills/Editor) | ✅ |
| P3 | 维护任务 (SQLite/WebSocket/CI/Docs) | ✅ |
| P4-A | UniBase 集成 | ✅ |
| P4-B | 中文文档 | ✅ |
| P4-C | Event Sourcing | ✅ |
| P4-D | 分析与可视化 | ✅ |
| P4-E | 性能优化 | ✅ |
| P4-F | 多租户支持 | ✅ |
| P4-G | 插件系统 | ✅ |
| P5-A | 生产加固 | ✅ |
| P5-B | 功能增强 | ✅ |
| P5-C | 平台集成 | ✅ |
| P6-A | 云原生支持 | ✅ |
| P6-B | AI 增强 | ✅ |

### 代码统计摘要

**总计: ~112,000+ 行** (含 P6 扩展)

| 类型 | 文件数 | 行数 |
|------|--------|------|
| Pascal (Source) | 64 | ~74,000 |
| Pascal (Examples/Tests) | 6 | ~3,500 |
| Python Skills | 4 | ~1,450 |
| Node.js Skills | 7 | ~1,100 |
| Web Editor | 11 | ~4,500 |
| Editor Tests | 7 | ~2,300 |
| Analytics Dashboard | 8 | ~4,900 |
| Tenant Console | 6 | ~4,200 |
| Deploy (K8s/Helm/Istio) | 15 | ~1,800 |
| CI/CD | 4 | ~550 |
| English Docs | 6 | ~2,250 |
| Chinese Docs | 4 | ~2,590 |

## 待开发任务 (Code Review 优化项)

### 方向 P: 安全漏洞修复 [TASK-2100~2104] 🔴

> 优先级: P0 (紧急) | 预估工时: 1-2 天 | 来源: 2025-12-07 AI 安全代码审查

| 任务 ID | 名称 | 严重度 | 描述 | 状态 |
|---------|------|--------|------|------|
| TASK-2100 | 沙箱逃逸修复 | 高 | 移除 `code_executor.py` 中的 `setattr`/`delattr`，包装 `getattr` 过滤危险属性 | ✅ 已完成 |
| TASK-2101 | SSRF 防护 | 高 | 为 `http-request.js` 添加内网 IP 过滤，阻止请求 localhost/私有网段 | ✅ 已完成 |
| TASK-2102 | JSON 解析安全 | 中 | 修复 `node-types.js` 中多处 `JSON.parse` 未捕获异常的问题 | ✅ 已完成 |
| TASK-2103 | 错误信息脱敏 | 中 | 修改 `main.py` 全局异常处理器，生产环境不返回详细错误 | ✅ 已完成 |
| TASK-2104 | 存储操作反馈 | 中 | 修改 `utils.js` 中 `Storage.set` 返回操作结果 | ✅ 已完成 |

### 方向 Q: 代码质量与安全增强 [TASK-2105~2109] 🟡

> 优先级: P1 | 预估工时: 1 天 | 来源: 2025-12-07 AI 代码深度审查

| 任务 ID | 名称 | 严重度 | 描述 | 状态 |
|---------|------|--------|------|------|
| TASK-2105 | Analytics 存储反馈 | 中 | 修复 `Analytics/utils.js` 中 `setStorage` 静默失败问题 | ✅ 已完成 |
| TASK-2106 | Timeline 日志完善 | 低 | 修复 `timeline.js` 中 `formatJson` 空 catch 块 | ✅ 已完成 |
| TASK-2107 | XSS 防护增强 | 中 | 增强 `dashboard.js` 中 `escapeHtml` 防护范围 | ✅ 已完成 |
| TASK-2108 | Python eval 注入防护 | 高 | 为 `python-data-transformer.py` 添加表达式安全验证 | ✅ 已完成 |
| TASK-2109 | JS Function 注入防护 | 高 | 为 `json-transform.js` 添加 `_validateExpression` 安全验证 | ✅ 已完成 |

### 方向 H: 架构与安全加固 [TASK-1100~1103]

> 优先级: P1 | 预估工时: 3-4 天 | 来源: 2025-12-06 AI Code Review

| 任务 ID | 名称 | 描述 | 状态 |
|---------|------|------|------|
| TASK-1100 | 安全审计: SQL 注入防御 | 审查 Storage 层，确保强制使用参数化查询，禁止依赖 `SanitizeSQL` 拼接 | 待开发 |
| TASK-1101 | 架构重构: Engine 拆分 | 将 `TUniFlowEngine` 的加载与注册逻辑拆分为 `TWorkflowLoader` 和 `TRegistryManager` | 待开发 |
| TASK-1102 | 并发优化: 及时取消机制 | 为 `IActionExecutor` 增加 Cancellation 支持，优化 `ExecuteParallel` 的 FailFast 响应速度 | 待开发 |
| TASK-1103 | 内存优化: 循环结果流式处理 | 优化 `ExecuteLoop`，增加配置项以支持不收集结果或流式处理，防止大数据量 OOM | 待开发 |

### 方向 I: UniBase Core 深度优化 [TASK-1200~1102]

> 优先级: P2 | 预估工时: 2-3 天 | 来源: 2025-12-06 UniBase Core Code Review

| 任务 ID | 名称 | 描述 | 状态 |
|---------|------|------|------|
| TASK-1200 | IoC 性能优化 | 移除 `TryResolve` 中的异常捕获，改用 `PeekResolve` 或返回状态码；优化 Singleton 锁机制 | 待开发 |
| TASK-1201 | ORM 映射加速 | 优化 `MapRowToEntity`，引入预编译 Setter 或 RTTI 缓存，提升大数据量查询性能 | 待开发 |
| TASK-1202 | 安全接口加固 | 标记 `ExecuteSQL` 为 Unsafe，增加 `ExecuteSQLUnsafe` 别名，并在文档中强调参数化查询 | 待开发 |

### 方向 J: UniBase 基础设施加固 [TASK-1300~1306]

> 优先级: P2 | 预估工时: 3-4 天 | 来源: 2025-12-06 UniBase Full Review

| 任务 ID | 名称 | 描述 | 状态 |
|---------|------|------|------|
| TASK-1300 | EventBus 内存保护 | 为 `TEventBus.FEventHistory` 增加最大内存限制或默认禁用历史记录，防止内存泄漏 | 待开发 |
| TASK-1301 | 日志脱敏机制 | 在 `TUniBaseLogger` 中实现 `LogSanitizer` 拦截器，自动掩盖密码/Token等敏感字段 | 待开发 |
| TASK-1302 | WorkerQueue 持久化 | 实现 `TFileJobStorage` 或 `TDbJobStorage`，并设为生产环境默认，防止重启丢单 | 待开发 |
| TASK-1303 | 安全配置加固 | 标记 `GetConfigEncrypted` 为已过时，强制迁移到 `UniBase.Security`；TCorsMiddleware 增加白名单 | 待开发 |
| TASK-1304 | 网络安全增强 | `THttpClient_` 增加 SSRF 防御（内网 IP 过滤）；补全 WebSocket 空壳实现 | 待开发 |
| TASK-1305 | 序列化补全与安全 | 实现 `TXmlSerializer.Deserialize`；增加反序列化类型白名单机制 | 待开发 |
| TASK-1306 | MVVM 性能优化 | 为 `TBindingManager` 增加 RTTI 属性缓存，提升高频更新场景下的 UI 性能 | 待开发 |

### 方向 K: 数据库与核心加固 [TASK-1400~1403]

> 优先级: P2 | 预估工时: 2-3 天 | 来源: 2025-12-06 UniBase DB Review

| 任务 ID | 名称 | 描述 | 状态 |
|---------|------|------|------|
| TASK-1400 | 统一连接池 | 标记 `UniBase.DB.ConnectionPool.pas` 为已过时，统一迁移到 `UniBase.DB.Pool.pas` | 待开发 |
| TASK-1401 | 查询日志脱敏 | 在 `UniBase.DB.DoQry.LogQuery` 中增加参数脱敏，防止日志记录密码/Token | 待开发 |
| TASK-1402 | DoQry 易用性增强 | 为 `UniDbSelect/Exec` 增加 `TJSONObject` 重载，减少 JSON 序列化开销 | 待开发 |
| TASK-1403 | 预编译池内存管理 | 为 `GPreparedPool` 增加 LRU 或定时清理机制，防止长期运行内存泄漏 | 待开发 |

### 方向 L: 业务模块深度优化 [TASK-1500~1503]

> 优先级: P2 | 预估工时: 2-3 天 | 来源: 2025-12-06 UniBase Business Review

| 任务 ID | 名称 | 描述 | 状态 |
|---------|------|------|------|
| TASK-1500 | License 安全加固 | 移除 `UniBase.License.pas` 中硬编码的 `LICENSE_SECRET`，改为外部配置或混淆 | 待开发 |
| TASK-1501 | CSV 导出安全 | 在 `TDataExport.EscapeCSV` 中增加对 `=, +, -, @` 开头字段的转义，防御 CSV 注入 | 待开发 |
| TASK-1502 | Diff 性能保护 | 为 `TTextDiff` 增加超时机制或最大行数限制，防止大文件比对导致 UI 冻结 | 待开发 |
| TASK-1503 | LLM 架构重构 | 将 `TUniBaseLLM` 中的模板管理功能拆分到 `TLLMTemplateManager`，减轻上帝类负担 | 待开发 |

### 方向 M: 核心管理与弹性优化 [TASK-1600~1603]

> 优先级: P2 | 预估工时: 2-3 天 | 来源: 2025-12-06 UniBase Core Review

| 任务 ID | 名称 | 描述 | 状态 |
|---------|------|------|------|
| TASK-1600 | 插件签名验证 | 在 `TUniBasePluginManager.LoadPlugin` 中增加对 BPL 文件的签名校验，防止加载恶意插件 | 待开发 |
| TASK-1601 | 插件配置隔离 | 修改 `TPluginContext.SetConfig`，强制为 Key 加上插件 ID 前缀，防止插件篡改系统配置 | 待开发 |
| TASK-1602 | 限流锁优化 | 优化 `TRateLimiter`，使用原子操作替代互斥锁，提升高并发吞吐量 | 待开发 |
| TASK-1603 | 数据库抽象 | 提取 `ISchemaProvider` 接口，将 `ValidateSchema` 中的 SQLite 特定 SQL 解耦 | 待开发 |

### 方向 N: 架构支撑优化 [TASK-1700~1703]

> 优先级: P3 | 预估工时: 2-3 天 | 来源: 2025-12-06 UniBase Support Review

| 任务 ID | 名称 | 描述 | 状态 |
|---------|------|------|------|
| TASK-1700 | Schema 资源化 | 将 `UniBase.Schema.pas` 中的 SQL 常量移至 `.sql` 资源文件，简化代码并方便 DBA 审查 | 待开发 |
| TASK-1701 | 反射缓存 | 优化 `TReflect`，增加 `TProperty` 和 `TMethod` 缓存，提升 `GetProp/Call` 性能 | 待开发 |
| TASK-1702 | 迁移测试套件 | 建立自动化 Schema 迁移测试，覆盖从最低兼容版本到当前版本的所有升级路径 | 待开发 |
| TASK-1703 | 插件反射规范 | 在文档和 CI 检查中增加规则，限制插件使用 `TFieldAccess` 修改私有字段 | 待开发 |

### 方向 O: 低熵代码重构 [TASK-1800~1805]

> 优先级: P2 | 预估工时: 3-4 天 | 来源: 2025-12-07 代码熵管理分析
>
> 参考文档: `../01.01.uniBase-4AI-集成指南-v1.0.md`

| 任务 ID | 名称 | 描述 | 状态 |
|---------|------|------|------|
| TASK-1800 | 删除重复 LLM 代码 | 删除 `UniFlow.AI.Types.pas` 和 `UniFlow.AI.LLMClient.pas`，统一使用 UniBase.LLM，已创建 UniFlow.AI.Adapter.pas | ✅ 已完成 |
| TASK-1801 | 统一错误码模型 | 实现 `{Source}/{Category}/{Specific}` 格式错误码，添加 TErrorCode 解析器 | ✅ 已完成 |
| TASK-1802 | 命名一致性审计 | 根据 Glossary.md 审计代码，统一术语使用 (FlowInstance/TUniFlowEvent/Step/Snapshot 等) | 待开发 |
| TASK-1803 | Event Sourcing 合规检查 | 检查所有 FlowInstance 状态变化是否都写了 TUniFlowEvent，修复遗漏 | 待开发 |
| TASK-1804 | 分层边界检查脚本 | 创建 `scripts/check-layer-violations.ps1` 检测违规依赖 | ✅ 已完成 |
| TASK-1805 | Step 命名审计 | 审计现有步骤名，生成 `docs/naming-audit-report.md`，核心代码符合规范 | ✅ 已完成 |

---

## 已完成任务

### 方向 B: 中文文档补全 [TASK-1010~1013] ✅

| 任务 ID | 内容 | 输出文件 | 状态 |
|---------|------|------|------|
| TASK-1010 | 中文快速入门 | `docs/zh/quick-start.md` | ✅ |
| TASK-1011 | 中文 Workflow 格式 | `docs/zh/workflow-definition.md` | ✅ |
| TASK-1012 | 中文 Skill 开发 | `docs/zh/skills-development.md` | ✅ |
| TASK-1013 | 中文部署指南 | `docs/zh/deployment.md` | ✅ |

### 方向 G: 插件系统 [TASK-1060~1063] ✅

| 任务 ID | 内容 | 输出文件 | 状态 |
|---------|------|------|------|
| TASK-1060 | 插件接口定义 | `UniFlow.Plugin.Intf.pas` | ✅ |
| TASK-1061 | 插件加载器 | `UniFlow.Plugin.Loader.pas` | ✅ |
| TASK-1062 | 插件注册表 | `UniFlow.Plugin.Registry.pas` | ✅ |
| TASK-1063 | 示例插件 | `UniFlow.Plugin.Examples.pas` | ✅ |

---

## Bug 修复状态

详细 Bug 修复记录见 `bugfix.md`

| 严重程度 | 已修复 |
|----------|--------|
| Critical | 1 |
| High | 95 |
| Medium | 22 |
| Low | 7 |
| **合计** | **125** |

---

## 已完成问题清单 (2025-12-06)

### 架构问题 (全部完成)

| ID | 问题描述 | 严重程度 | 状态 |
|----|------|----------|------|
| ARCH-001 | 依赖注入容器 | Medium | ✅ (BUG-058) |
| ARCH-002 | TTenantEventStore 接口不一致 | High | ✅ (BUG-049) |
| ARCH-003 | Skill Service URL 配置外置 | Low | ✅ (BUG-060) |
| ARCH-004 | ExecuteParallel 真正并行 | Medium | ✅ (BUG-055) |

### 代码质量问题 (全部完成)

| ID | 问题描述 | 严重程度 | 状态 |
|----|------|----------|------|
| CODE-001 | TStepResult.Output 所有权 | High | ✅ (BUG-050) |
| CODE-002 | ExecuteLoop 对象池优化 | Medium | ✅ (BUG-061) |
| CODE-003 | 缺少 try-finally 保护 | High | ✅ (BUG-051) |
| CODE-004 | HTTP/重试超时配置化 | Low | ✅ (BUG-054) |
| CODE-005 | 子工作流变量隔离 | Medium | ✅ (BUG-052) |

### 安全问题 (全部完成)

| ID | 问题描述 | 严重程度 | 状态 |
|----|------|----------|------|
| SEC-001 | 表达式注入白名单 | High | ✅ (BUG-045) |
| SEC-002 | 审计日志敏感信息脱敏 | High | ✅ (BUG-046) |
| SEC-003 | 租户隔离签名验证 | High | ✅ (BUG-047) |
| SEC-004 | Skill 服务身份认证 | Medium | ✅ (BUG-053) |
| SEC-005 | 配额检查原子操作 | Medium | ✅ (BUG-048) |

### 质量保证问题 (全部完成)

| ID | 问题描述 | 优先级 | 状态 |
|----|------|------|------|
| QA-001 | 核心单元测试 | Critical | ✅ (BUG-056) |
| QA-002 | 边界条件测试 | High | ✅ (BUG-059) |
| QA-003 | 并发场景测试 | High | ✅ (BUG-059) |
| QA-004 | 错误恢复测试 | Medium | ✅ (BUG-059) |

### 用户体验问题 (全部完成)

| ID | 问题描述 | 优先级 | 状态 |
|----|------|------|------|
| UX-001 | 错误信息友好化 | High | ✅ (BUG-057) |
| UX-002 | 工作流模板库 | Medium | ✅ (BUG-062) |
| UX-003 | 调试器可视化 | Medium | ✅ (BUG-063) |
| UX-004 | 性能分析面板 | Low | ✅ (BUG-064) |

---

## 已完成 P5 任务

### P5-A: 生产加固 ✅

| 任务 | 描述 | 状态 |
|------|------|------|
| TASK-2001 | 端到端集成测试 | ✅ |
| TASK-2002 | 压力测试与基准 | ✅ |
| TASK-2003 | 生产部署脚本 | ✅ |
| TASK-2004 | 监控告警集成 | ✅ |

### P5-B: 功能增强 ✅

| 任务 | 描述 | 状态 |
|------|------|------|
| TASK-2010 | 工作流版本控制 | ✅ |
| TASK-2011 | 可视化编辑器增强 | ✅ |
| TASK-2012 | 更多 Skill 模板 | ✅ |
| TASK-2013 | 工作流导入/导出 | ✅ |

### P5-C: 平台集成 ✅

| 任务 | 描述 | 状态 |
|------|------|------|
| TASK-2020 | MCP 协议完整支持 | ✅ |
| TASK-2021 | 更多 LLM 提供商 | ✅ |
| TASK-2022 | 消息队列集成 (RabbitMQ/Kafka) | ✅ |
| TASK-2023 | 数据库存储后端 (PostgreSQL) | ✅ |

---

## 已完成 P6 任务

### P6-A: 云原生支持 ✅

| 任务 | 描述 | 状态 |
|------|------|------|
| TASK-3001 | Kubernetes 部署模板 | ✅ |
| TASK-3002 | Helm Chart 包 | ✅ |
| TASK-3003 | Service Mesh 集成 (Istio) | ✅ |
| TASK-3004 | 分布式追踪 (OpenTelemetry) | ✅ |

### P6-B: AI 增强 ✅

| 任务 | 描述 | 状态 |
|------|------|------|
| TASK-3010 | 智能工作流推荐 | ✅ |
| TASK-3011 | 自然语言工作流生成 | ✅ |
| TASK-3012 | AI 异常检测 | ✅ |
| TASK-3013 | 智能重试策略 | ✅ |

---

## 后续发展建议 (P7)

### P7-A: 企业级功能

| 任务 | 描述 | 复杂度 |
|------|------|--------|
| TASK-4001 | SSO/SAML/OAuth2 集成 | High |
| TASK-4002 | 工作流审批/人工介入节点 | Medium |
| TASK-4003 | 企业级审计合规 (SOC2/GDPR) | High |
| TASK-4004 | 多数据中心容灾 | High |

### P7-B: 开发体验优化

| 任务 | 描述 | 复杂度 |
|------|------|--------|
| TASK-4010 | 工作流 DSL 语言设计 | High |
| TASK-4011 | VS Code / IDE 插件 | Medium |
| TASK-4012 | CLI 工具完善 | Low |
| TASK-4013 | SDK (Python/Go/TypeScript) | Medium |

### P7-C: 生态集成

| 任务 | 描述 | 复杂度 |
|------|------|--------|
| TASK-4020 | Webhook 运营商集成 (Stripe/Twilio/SendGrid) | Medium |
| TASK-4021 | 低代码平台集成 (Retool/Appsmith) | Medium |
| TASK-4022 | BI 工具集成 (Metabase/Superset) | Low |
| TASK-4023 | 工单系统集成 (Jira/ServiceNow) | Medium |

### P7-D: 性能与质量

| 任务 | 描述 | 复杂度 |
|------|------|--------|
| TASK-4030 | 工作流执行回放 (Replay/Debug) | High |
| TASK-4031 | 性能基线自动化 | Medium |
| TASK-4032 | 混沌工程测试 | High |
| TASK-4033 | 全链路压测平台 | Medium |

---

## 相关文档

- `history.md` - 开发历史详细记录
- `bugfix.md` - Bug 修复详细记录
- `docs/en/` - 英文文档
- `docs/zh/` - 中文文档
- `docs/api-reference.md` - API 参考
- `docs/quick-start.md` - 快速入门

---

## 优先级说明

- **P0**: 紧急阻塞性问题
- **P1**: MVP 必需
- **P2**: 完整功能
- **P3**: 维护优化
- **P4**: 扩展增强
- **P5**: 生产加固
- **P6**: 云原生/AI
- **P7**: 企业级
