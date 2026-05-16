# DeepBase 文档索引

> 更新：2026-05-12 · 对接基线：RC 候选
> 常驻文档平铺，命名格式 `序号.分类.中文-english.md`；专项工作文档保留可读标题并集中列在 active 区。

---

## 给 AI 的唯一入口

**[00.quickstart.AI集成总览-ai-one-file.md](./00.quickstart.AI集成总览-ai-one-file.md)** — AI 先读这一份，再按需取其它细节文件。

## 给下游 / 第三方的唯一入口

**[01.quickstart.对外集成入口-integration-onefile.md](./01.quickstart.对外集成入口-integration-onefile.md)** — 只发一份文档时发这份。

---

## 按分类浏览

### quickstart · 快速入门

- [00 AI 集成总览](./00.quickstart.AI集成总览-ai-one-file.md)
- [01 对外集成入口](./01.quickstart.对外集成入口-integration-onefile.md)
- [02 下游接入流程](./02.quickstart.下游接入流程-downstream-integration.md)
- [03 AI 深挖集成指南](./03.quickstart.AI深挖集成指南-ai-deep-integration.md)
- [04 AboutFrame 接入](./04.quickstart.AboutFrame接入-aboutframe-guide.md)

### product · 产品定位

- [10 项目定位与边界](./10.product.项目定位与边界-scope-and-boundary.md)
- [11 术语表](./11.product.术语表-glossary.md)

### architecture · 架构与设计

- [20 技术规范](./20.architecture.技术规范-tech-spec.md)
- [21 LLM 架构设计](./21.architecture.LLM架构设计-llm-architecture.md)
- [22 公共库架构审阅报告](./22.architecture.公共库架构审阅报告-library-review.md)

### data · 数据与模型

- [30 数据库 Schema 说明](./30.data.数据库Schema说明-database-schema.md)
- [31 数据库指南](./31.data.数据库指南-database-guide.md)

### api · 接口与 API

- [40 API 参考](./40.api.API参考-api-reference.md)
- [41 DoQry 指南](./41.api.DoQry指南-doqry-guide.md)
- [42 LLM 集成指南](./42.api.LLM集成指南-llm-integration.md)

### extend · 扩展开发

- [50 ThirdParty 扩展开发指南](./50.extend.ThirdParty扩展开发指南-thirdparty-extension.md)
- [51 Governance 治理扩展](./51.extend.Governance治理扩展-governance-integration.md)
- [52 Governance 代码注册示例](./52.extend.Governance代码注册示例-governance-setup-via-code.md)
- [52 BrowserAutomation 接入指南](./52.extend.BrowserAutomation接入指南.md)

### backend · 生产后端对接

- [60 Commerce 后端契约](./60.backend.Commerce后端契约-commerce-backend-spec.md)
- [61 DB4 后端交接说明](./61.backend.DB4后端交接说明-db4-backend-handoff.md)
- [62 DeepKit.top DB4 商用验收](./62.backend.DeepKitTop-DB4商用验收与支付接入.md)
- [63 DB4 支付渠道接入配置](./63.backend.DB4支付渠道接入配置.md)
- [64 DB3/DB4 下游产品数据库矩阵](./64.backend.DB3-DB4下游产品数据库矩阵.md)

### integrations · 下游项目接入

- [70 TwoKeyRun](./70.integrations.TwoKeyRun接入-twokeyrun.md)
- [71 DeepSync](./71.integrations.DeepSync接入-deepsync.md)
- [72 SVGThing](./72.integrations.SVGThing接入-svgthing.md)
- [73 Stocks](./73.integrations.Stocks接入-stocks.md)
- [74 DeepCharset](./74.integrations.DeepCharset接入-deepcharset.md)
- [75 AntiTamper](./75.integrations.AntiTamper接入-antitamper.md)
- [76 项目分类表](./76.integrations.项目分类表-project-classification.md)

### ops · 运维与手册

- [80 CLI 用户手册](./80.ops.CLI用户手册-cli-manual.md)
- [81 Studio 用户手册](./81.ops.Studio用户手册-studio-manual.md)
- [82 Tray 用户手册](./82.ops.Tray用户手册-tray-manual.md)
- [83 FAQ 与错误速查](./83.ops.FAQ与错误速查-faq-troubleshooting.md)
- [84 集成检查清单](./84.ops.集成检查清单-integration-checklist.md)
- [85 安全与测试](./85.ops.安全与测试-security-and-testing.md)

### history · 历史与变更

- [90 BugFix 记录](./90.history.BugFix记录-bugfix-log.md)
- [91 开发历史](./91.history.开发历史-dev-history.md)
- [92 任务清单](./92.history.任务清单-task-list.md)
- [93 D13.1 迁移说明](./93.history.D13.1迁移说明-d13-migration-notes.md)

### active · 专项工作文档

- [DeepBase.Speech 扩展方案](./DeepBase.Speech扩展方案.md)
- [DeepBase.Speech 开发规范](./DeepBase.Speech开发规范.md)
- [DeepBase.Speech 专家评审优化方案](./DeepBase.Speech专家评审优化方案.md)
- [DeepBase.Speech 二轮专家评审](./DeepBase.Speech二轮专家评审.md)
- [DeepGovern OCGS 设计纪要](./DeepGovern-OCGS设计纪要-v1.md)
- [Governance Round 2 交接](./handoff-governance-round2.md)
- [Governance 接入轮任务清单](./tasks.md)
- [Governance 接入轮完成历史](./history.md)
- [Governance 接入轮 Bug 修复记录](./bugfix.md)

---

## 按受众推荐阅读顺序

### 下游开发负责人

1. [01 对外集成入口](./01.quickstart.对外集成入口-integration-onefile.md)
2. [10 项目定位与边界](./10.product.项目定位与边界-scope-and-boundary.md)
3. [02 下游接入流程](./02.quickstart.下游接入流程-downstream-integration.md)
4. [84 集成检查清单](./84.ops.集成检查清单-integration-checklist.md)

### 架构师

1. [10 项目定位与边界](./10.product.项目定位与边界-scope-and-boundary.md)
2. [20 技术规范](./20.architecture.技术规范-tech-spec.md)
3. [22 公共库架构审阅报告](./22.architecture.公共库架构审阅报告-library-review.md)
4. [85 安全与测试](./85.ops.安全与测试-security-and-testing.md)

### AI / Agent

直接读 [00 AI 集成总览](./00.quickstart.AI集成总览-ai-one-file.md)，它会告诉 AI 下一步该读哪份细节文件。

### 服务器后端开发

1. [61 DB4 后端交接说明](./61.backend.DB4后端交接说明-db4-backend-handoff.md)
2. [60 Commerce 后端契约](./60.backend.Commerce后端契约-commerce-backend-spec.md)
3. [64 DB3/DB4 下游产品数据库矩阵](./64.backend.DB3-DB4下游产品数据库矩阵.md)
4. [30 数据库 Schema 说明](./30.data.数据库Schema说明-database-schema.md)

### 运维 / 工具使用者

1. [80-82 CLI / Studio / Tray 手册](./80.ops.CLI用户手册-cli-manual.md)
2. [83 FAQ 与错误速查](./83.ops.FAQ与错误速查-faq-troubleshooting.md)

---

## 子目录说明

- `api/` — 由工具生成的 API 文档（自动）
- `ui/` — UI 控件 / Frame 设计稿

姊妹目录：`../DeepFlow/`（移出到 `02Business/DeepFlow/`，AI 开发方法归档，不属于 DeepBase 框架范畴）。

---

## 命名规范

```
{序号2位}.{分类}.{中文描述}-{english-slug}.md

序号段分配：
  00     AI 总入口
  01-09  quickstart（快速入门 / 集成入口）
  10-19  product（产品定位 / 术语）
  20-29  architecture（架构 / 设计 / ADR）
  30-39  data（数据库 / 模型）
  40-49  api（接口 / SDK）
  50-59  extend（扩展 / 第三方 / 治理）
  60-69  backend（生产后端 / 契约）
  70-79  integrations（下游项目接入）
  80-89  ops（运维 / 手册 / FAQ / 安全测试）
  90-99  history（变更 / 任务 / 迁移）
```

旧的双轨 `4AI` / `4H` 命名已废弃。营销 / 产品类（10、80-82）按"给人看"定位撰写；其余技术类文档统一按"AI 可读"深度编写（AI 能读的人类也能读）。进行中的专项评审、交接、任务和 Bug 记录放在 active 区，稳定后再并入编号体系。
