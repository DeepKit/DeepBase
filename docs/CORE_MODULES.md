# UniBase 核心层模块清单

> 版本: 1.0
> 更新日期: 2025-12-07
> ENTROPY-013: 核心层边界明确化

---

## 核心层规则

### AI 开发约束
- **核心层**: AI **禁止修改**，仅人工审核后可变更
- **外壳层**: AI **可自由迭代**，需遵循低熵约束

### 变更流程
1. 核心层变更需提交 RFC 文档
2. 需通过代码审查 + 单元测试覆盖 >80%
3. 变更需在 `history.md` 记录

---

## 核心层模块列表

### UniBase Core (77 个模块)

| 模块 | 类别 | 说明 |
|------|------|------|
| `UniBase.Manager.pas` | 框架 | 框架生命周期管理 |
| `UniBase.Config.pas` | 配置 | 配置系统核心 |
| `UniBase.Configuration.pas` | 配置 | 高级配置管理 |
| `UniBase.Consts.pas` | 常量 | 全局常量定义 |
| `UniBase.Types.pas` | 类型 | 基础类型定义 |
| `UniBase.Interfaces.pas` | 接口 | 核心接口定义 |
| `UniBase.IoC.pas` | DI | 依赖注入容器 |
| `UniBase.Exception.pas` | 异常 | 异常处理基类 |
| `UniBase.DBException.pas` | 异常 | 数据库异常 |
| `UniBase.Logging.pas` | 日志 | 日志系统核心 |
| `UniBase.LogQuery.pas` | 日志 | 日志查询 |
| `UniBase.LogAggregator.pas` | 日志 | 日志聚合 |
| `UniBase.LogAlert.pas` | 日志 | 日志告警 |
| `UniBase.LogDashboard.pas` | 日志 | 日志仪表盘 |
| `UniBase.Metrics.pas` | 监控 | 指标收集 |
| `UniBase.Benchmark.pas` | 监控 | 性能基准测试 |
| `UniBase.Diagnose.pas` | 诊断 | 诊断工具 |
| `UniBase.EventBus.pas` | 事件 | 事件总线 |
| `UniBase.StateMachine.pas` | 状态 | 有限状态机 |
| `UniBase.Scheduler.pas` | 调度 | 任务调度器 |
| `UniBase.WorkerQueue.pas` | 并发 | 工作队列 |
| `UniBase.Cache.pas` | 缓存 | 缓存系统 |
| `UniBase.ObjectPool.pas` | 池化 | 对象池 |
| `UniBase.Memory.pas` | 内存 | 内存管理 |
| `UniBase.Collections.pas` | 集合 | 集合扩展 |
| `UniBase.Serialization.pas` | 序列化 | 序列化框架 |
| `UniBase.Compression.pas` | 压缩 | 压缩算法 |
| `UniBase.Crypto.pas` | 安全 | 加密核心 |
| `UniBase.Crypto.OpenSSL.pas` | 安全 | OpenSSL 封装 |
| `UniBase.Security.pas` | 安全 | 安全工具 |
| `UniBase.Authorization.pas` | 权限 | 授权框架 |
| `UniBase.RateLimiter.pas` | 限流 | 速率限制 |
| `UniBase.Resilience.pas` | 容错 | 弹性模式 |
| `UniBase.DB.Pool.pas` | 数据库 | 连接池 |
| `UniBase.DB.ConnectionPool.pas` | 数据库 | 连接池实现 |
| `UniBase.DB.DoQry.pas` | 数据库 | 查询执行 |
| `UniBase.ORM.pas` | ORM | 对象关系映射 |
| `UniBase.ORM.Mapping.pas` | ORM | 映射定义 |
| `UniBase.Schema.pas` | 数据库 | Schema 管理 |
| `UniBase.SQLLogger.pas` | 数据库 | SQL 日志 |
| `UniBase.Net.pas` | 网络 | 网络工具 |
| `UniBase.HttpServer.pas` | 网络 | HTTP 服务器 |
| `UniBase.CLI.Interactive.pas` | CLI | 交互式命令行 |
| `UniBase.CLI.Pipeline.pas` | CLI | 管道支持 |
| `UniBase.CLI.SSH.pas` | CLI | SSH 支持 |
| `UniBase.i18n.pas` | 国际化 | 多语言核心 |
| `UniBase.i18n.Plural.pas` | 国际化 | 复数规则 |
| `UniBase.i18n.Gender.pas` | 国际化 | 性别/格/RTL 变体 |
| `UniBase.DateTime.pas` | 工具 | 日期时间 |
| `UniBase.Math.pas` | 工具 | 数学工具 |
| `UniBase.Diff.pas` | 工具 | 差异比较 |
| `UniBase.Expression.pas` | 工具 | 表达式求值 |
| `UniBase.Reflection.pas` | 工具 | 反射工具 |
| `UniBase.Template.pas` | 工具 | 模板引擎 |
| `UniBase.Validation.pas` | 工具 | 数据验证 |
| `UniBase.Graph.pas` | 工具 | 图算法 |
| `UniBase.Export.pas` | 导出 | 数据导出 |
| `UniBase.Plugin.pas` | 插件 | 插件接口 |
| `UniBase.PluginManager.pas` | 插件 | 插件管理 |
| `UniBase.License.pas` | 授权 | 许可证管理 |
| `UniBase.Updater.pas` | 更新 | 自动更新 |
| `UniBase.FeatureFlags.pas` | 功能 | 功能开关 |
| `UniBase.CloudSync.pas` | 云 | 云同步 |
| `UniBase.CloudBackup.pas` | 云 | 云备份 |
| `UniBase.LLM.pas` | AI | LLM 核心接口 |
| `UniBase.LLM.Manager.pas` | AI | LLM 管理器 |
| `UniBase.LLM.ImportExport.pas` | AI | LLM 配置导入导出 |

### UniBase UI Core (UI 层核心)

| 模块 | 说明 |
|------|------|
| `UniBase.Theme.pas` | 主题系统 |
| `UniBase.MVVM.pas` | MVVM 框架 |
| `UniBase.DataBinding.pas` | 数据绑定 |
| `UniBase.FormState.pas` | 窗体状态 |
| `UniBase.Hotkeys.pas` | 快捷键 |
| `UniBase.VirtualScroll.pas` | 虚拟滚动 |
| `UniBase.SplashScreen.pas` | 启动画面 |
| `UniBase.SingleInstance.pas` | 单实例 |
| `UniBase.MRU.pas` | 最近使用 |
| `UniBase.FileWatcher.pas` | 文件监控 |
| `UniBase.Feedback.pas` | 用户反馈 |
| `UniBase.TestHelper.pas` | 测试辅助 |

### UniBase FMX (跨平台 UI)

| 模块 | 说明 |
|------|------|
| `UniBase.FMX.Platform.pas` | 平台适配 |
| `UniBase.FMX.Theme.pas` | 主题系统 |
| `UniBase.FMX.Controls.pas` | 基础控件 |
| `UniBase.FMX.FormControls.pas` | 表单控件 |
| `UniBase.FMX.ListView.pas` | 列表视图 |
| `UniBase.FMX.Dialogs.pas` | 对话框 |
| `UniBase.FMX.WaitForm.pas` | 等待窗体 |
| `UniBase.FMX.ConfigControls.pas` | 配置控件 |
| `UniBase.FMX.ConfigEdit.pas` | 配置编辑器 |
| `UniBase.FMX.I18nControls.pas` | 国际化控件 |
| `UniBase.FMX.MRUControls.pas` | 最近使用控件 |
| `UniBase.FMX.FormStateHelper.pas` | 窗体状态助手 |
| `UniBase.FMX.LLMConfigPanel.pas` | LLM 配置面板 |
| `UniBase.FMX.AutoUpdater.pas` | 自动更新组件 |
| `UniBase.FMX.UpdateDialog.pas` | 更新对话框 |

### UniFlow Core (流程引擎核心)

| 模块 | 说明 |
|------|------|
| `UniFlow.Workflow.Definition.pas` | 工作流定义 |
| `UniFlow.Workflow.Context.pas` | 执行上下文 |
| `UniFlow.Workflow.Executor.pas` | 执行引擎 |
| `UniFlow.Workflow.Errors.pas` | 错误定义 |
| `UniFlow.EventSourcing.Types.pas` | 事件类型 |
| `UniFlow.EventSourcing.Store.pas` | 事件存储 |

---

## 外壳层模块（AI 可迭代）

以下模块 AI 可自由修改：

- `UniFlow.LLM.Providers.pas` - LLM Provider 实现
- `UniFlow.Skill.*` - Skill 执行层
- `UniFlow.AI.*` - AI 功能扩展
- `UniFlow.Cloud.*` - 云集成
- `UniFlow.Plugin.*` - 插件加载
- `UniFlow.Diagnostics.*` - 诊断集成
- `UniFlow.Audit.*` - 审计日志
- `UniFlow.Metrics.*` - 指标收集
- `UniFlow.Realtime.*` - 实时通信
- `Skills/*` - Python/Node.js Skills

---

## 代码标记规范

核心层文件应在文件头添加以下标记：

```pascal
{$REGION 'CORE-LAYER'}
(*
  Core Layer Module - AI Modification Prohibited
  
  变更需经人工审核，参见 docs/CORE_MODULES.md
*)
{$ENDREGION}
```

---

## 版本历史

| 日期 | 版本 | 变更 |
|------|------|------|
| 2025-12-07 | 1.0 | 初始版本，定义核心层边界 |
