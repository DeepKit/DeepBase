# DeepBase 文档索引

> 更新：2026-06-02 · 对接基线：RC 候选
> 常驻文档平铺，命名格式 `序号.分类.中文-english.md`。

---

## 架构全景

**[05.overview.DeepBase架构全景.md](./05.overview.DeepBase架构全景.md)** — 一份文档讲清楚 DeepBase 是什么、怎么组织的、怎么用。

## 给 AI 的唯一入口

**[00.quickstart.AI集成总览-ai-one-file.md](./00.quickstart.AI集成总览-ai-one-file.md)** — AI 先读这一份，再按需取其它细节文件。

## 给下游 / 第三方的唯一入口

**[02.quickstart.下游接入流程-downstream-integration.md](./02.quickstart.下游接入流程-downstream-integration.md)** — 如果只能给下游发一份文档，发这份。

---

## 按分类浏览

### quickstart · 快速入门

- [00 AI 集成总览](./00.quickstart.AI集成总览-ai-one-file.md)
- [02 下游接入流程](./02.quickstart.下游接入流程-downstream-integration.md)
- [03 AI 高级开发指南](./03.quickstart.AI深挖集成指南-ai-deep-integration.md)
- [04 AboutFrame 接入](./04.quickstart.AboutFrame接入-aboutframe-guide.md)
- [05 架构全景](./05.overview.DeepBase架构全景.md)

### product · 产品定位

- [10 项目定位与边界](./10.product.项目定位与边界-scope-and-boundary.md)
- [11 术语表](./11.product.术语表-glossary.md)

### architecture · 架构与设计

- [20 技术规范](./20.architecture.技术规范-tech-spec.md)
- [21 LLM 架构设计](./21.architecture.LLM架构设计-llm-architecture.md)
- [22 公共库架构审阅报告](./22.architecture.公共库架构审阅报告-library-review.md)

### ui · 控件规范

- [25 UI 控件规范](./25.ui.VCL-FMX控件规范.md)

### data · 数据与模型

- [30 数据库 Schema 说明](./30.data.数据库Schema说明-database-schema.md)
- [31 数据库指南](./31.data.数据库指南-database-guide.md)
- [32 SQLCipher 外部数据库读取](./32.data.SQLCipher外部数据库读取-开发规格.md)
- [33 SchemaAdapter 通用适配器](./33.data.SchemaAdapter通用适配器-开发规格.md)
- [34 UIA 自动化引擎](./34.data.UIA自动化引擎-开发规格.md)
- [35 剪贴板保护与窗口监控](./35.data.剪贴板保护与窗口监控-开发规格.md)
- [35a R1综合评估](./35a.synthesis.32-35修复后综合评估.md)
- [35b R2综合评估](./35b.synthesis.10专家综合评估.md)
- [35c R3综合评估](./35c.synthesis.14专家最终报告.md)
- [36 Bootstrap与CompositionRoot](./36.data.Bootstrap与CompositionRoot-开发规格.md)

### api · 接口与 API

- [40 API 参考](./40.api.API参考-api-reference.md)
- [41 DoQry 指南](./41.api.DoQry指南-doqry-guide.md)
- [42 LLM 集成指南](./42.api.LLM集成指南-llm-integration.md)

### extend · 扩展开发

- [50 ThirdParty 扩展开发指南](./50.extend.ThirdParty扩展开发指南-thirdparty-extension.md)
- [51 Governance 治理扩展](./51.extend.Governance治理扩展-governance-integration.md)
- [52 BrowserAutomation 接入指南](./52.extend.BrowserAutomation接入指南.md)
- [53 IntentClarification 接入指南](./53.extend.IntentClarification接入指南.md)
- [54 Governance 代码注册示例](./54.extend.Governance代码注册示例-governance-setup-via-code.md)

### vcl · DeepShell 桌面壳

- [55 DeepShell 总览与 AI 入口](./55.vcl.DeepShell-总览与AI入口.md)
- [56 DeepShell 结构规范](./56.vcl.DeepShell-结构规范.md)
- [57 DeepShell 核心接口与服务契约](./57.vcl.DeepShell-核心接口与服务契约.md)
- [58 DeepShell 生命周期与启动顺序](./58.vcl.DeepShell-生命周期与启动顺序.md)
- [59 DeepShell MRU/Layout/Settings 设计](./59.vcl.DeepShell-MRU-Layout-Settings设计.md)
- [60 DeepShell Command/Governance 集成](./60.vcl.DeepShell-Command-Governance集成.md)
- [61 DeepShell 新 VCL 程序接入指南](./61.vcl.DeepShell-新VCL程序接入指南.md)
- [62 DeepShell 旧 VCL 程序改造指南](./62.vcl.DeepShell-旧VCL程序改造指南.md)
- [63 DeepShell 验收清单](./63.vcl.DeepShell-验收清单.md)

### backend · 生产后端对接

- [65 Commerce 后端契约](./65.backend.Commerce后端契约-commerce-backend-spec.md)
- [66 DB4 后端交接说明](./66.backend.DB4后端交接说明-db4-backend-handoff.md)
- [67 DeepKit.top DB4 商用验收](./67.backend.DeepKitTop-DB4商用验收与支付接入.md)
- [68 DB4 支付渠道接入配置](./68.backend.DB4支付渠道接入配置.md)
- [69 DB3/DB4 下游产品数据库矩阵](./69.backend.DB3-DB4下游产品数据库矩阵.md)

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
- [86 AutoFix 自动修复指南](./86.ops.AutoFix自动修复指南.md)

### history · 历史与变更

- [90 BugFix 记录](./90.history.BugFix记录-bugfix-log.md)
- [91 开发历史](./91.history.开发历史-dev-history.md)
- [92 任务清单](./92.history.任务清单-task-list.md)
- [93 D13.1 迁移说明](./93.history.D13.1迁移说明-d13-migration-notes.md)

---

## 按受众推荐阅读顺序

### 下游开发负责人

1. [05 架构全景](./05.overview.DeepBase架构全景.md)
2. [02 下游接入流程](./02.quickstart.下游接入流程-downstream-integration.md)
3. [10 项目定位与边界](./10.product.项目定位与边界-scope-and-boundary.md)
4. [84 集成检查清单](./84.ops.集成检查清单-integration-checklist.md)

### 架构师

1. [05 架构全景](./05.overview.DeepBase架构全景.md)
2. [20 技术规范](./20.architecture.技术规范-tech-spec.md)
3. [22 公共库架构审阅报告](./22.architecture.公共库架构审阅报告-library-review.md)
4. [85 安全与测试](./85.ops.安全与测试-security-and-testing.md)

### AI / Agent

直接读 [00 AI 集成总览](./00.quickstart.AI集成总览-ai-one-file.md)，它会告诉 AI 下一步该读哪份细节文件。

### 服务器后端开发

1. [66 DB4 后端交接说明](./66.backend.DB4后端交接说明-db4-backend-handoff.md)
2. [65 Commerce 后端契约](./65.backend.Commerce后端契约-commerce-backend-spec.md)
3. [69 DB3/DB4 下游产品数据库矩阵](./69.backend.DB3-DB4下游产品数据库矩阵.md)
4. [30 数据库 Schema 说明](./30.data.数据库Schema说明-database-schema.md)

### 运维 / 工具使用者

1. [80-82 CLI / Studio / Tray 手册](./80.ops.CLI用户手册-cli-manual.md)
2. [83 FAQ 与错误速查](./83.ops.FAQ与错误速查-faq-troubleshooting.md)

---

## 子目录说明

- `ui/` — UI 控件 / Frame 设计稿

姊妹目录：`../DeepFlow/`（移出到 `02Business/DeepFlow/`，AI 开发方法归档，不属于 DeepBase 框架范畴）。

---

## 命名规范

```
{序号2位}.{分类}.{中文描述}-{english-slug}.md

序号段分配：
  00     AI 总入口
  01-09  quickstart（快速入门 / 集成入口 / 架构全景）
  10-19  product（产品定位 / 术语）
  20-24  architecture（架构 / 设计 / ADR）
  25-29  ui（UI 控件规范）
  30-39  data（数据库 / 模型）
  40-49  api（接口 / SDK）
  50-54  extend（扩展 / 第三方 / 治理 / 浏览器自动化 / 意图澄清）
  55-63  vcl（DeepShell 桌面壳）
  64     speech（语音识别/合成/声纹/唤醒词）
  65-69  backend（生产后端 / 契约）
  70-79  integrations（下游项目接入）
  80-89  ops（运维 / 手册 / FAQ / 安全测试 / AutoFix）
  90-99  history（变更 / 任务 / 迁移）
```

旧的双轨 `4AI` / `4H` 命名已废弃。营销 / 产品类（10、80-82）按"给人看"定位撰写；其余技术类文档统一按"AI 可读"深度编写（AI 能读的人类也能读）。