# DeepBase UI 文档索引

本目录包�?DeepBase 框架的所�?UI 相关设计文档。这些文档使�?Mermaid 图表生成，可在支�?Mermaid �?Markdown 查看器中查看�?

---

## 📑 文档列表

### **01 - 架构总览�?* (`01-Architecture-Overview.md`)

**内容**�?
- 整体架构概览（核心库、UI 控件、工具、云端服务）
- Tier 0/1/2 分层结构
- 模块依赖关系�?
- 数据流向
- 编译依赖关系

**适用人群**�?
- 项目经理：了解整体结�?
- 架构师：理解设计决策
- 新加入开发者：快速上�?

**图表数量**�? �?Mermaid �?

---

### **02 - UI 控件体系结构�?* (`02-UI-Controls-System.md`)

**内容**�?
- 15 �?UI 控件的全景分类（MRU、i18n、Config、Selection、Utility�?
- VCL �?FMX 继承�?
- 控件功能映射矩阵
- 控件�?Manager 的数据流
- 设计模式应用
- 控件功能对应�?

**适用人群**�?
- 前端开发者：选择合适控�?
- UI 设计者：理解控件功能
- 集成工程师：规划集成策略

**图表数量**�? �?Mermaid �?+ 1 个表�?

---

### **03 - 数据流向与交互图** (`03-Data-Flow-Diagram.md`)

**内容**�?
- 配置数据流（GetConfig/SetConfig�?
- 国际化数据流（T/TN 翻译�?
- 日志数据流（Log 记录�?
- MRU 最近使用数据流
- 主题数据�?
- 快捷键数据流
- 窗体状态数据流
- 完整应用启动流程

**适用人群**�?
- Core 模块开发者：理解内部机制
- 性能优化工程师：识别瓶颈
- 集成测试人员：验证流�?

**图表数量**�? �?Mermaid �?

---

### **04 - 渐进式集成流程图** (`04-Integration-Workflow.md`)

**内容**�?
- 8 步渐进式迁移流程详解
- 集成决策树（根据需求选择集成顺序�?
- 集成检查清单（8 个阶段各 3 项检查）
- 风险评估与缓解方�?
- 集成时间表（甘特图）
- 回滚计划与应急策�?

**适用人群**�?
- 项目经理：制定集成计�?
- QA 工程师：验证各阶�?
- 开发人员：按步骤实施集�?

**图表数量**�? �?Mermaid �?+ 1 个甘特图

---

## 🎨 图表渲染工具

这些文档支持以下工具查看和渲染：

1. **GitHub/GitLab**：原生支�?Mermaid 渲染
2. **VS Code**：安�?`Markdown Preview Mermaid Support` 扩展
3. **MkDocs**：配�?`pymdown-extensions` �?superfences
4. **在线查看�?*：https://mermaid.live
5. **导出图片**�?
   ```bash
   npx @mermaid-js/mermaid-cli -i document.md -o document.png
   # 或使�?PlantUML 导出工具
   ```

---

## 📊 文档统计

| 文档 | 图表�?| 表格�?| 代码�?| 行数 |
|------|--------|--------|--------|------|
| 01-Architecture-Overview.md | 5 | 0 | 5 | ~216 |
| 02-UI-Controls-System.md | 5 | 1 | 6 | ~200+ |
| 03-Data-Flow-Diagram.md | 8 | 0 | 8 | ~165+ |
| 04-Integration-Workflow.md | 6 | 0 | 7 | ~200+ |
| **合计** | **24** | **1** | **26** | **~800** |

---

## 🔄 推荐阅读顺序

### 按角色分类：

**项目经理**�?
1. 01-Architecture-Overview.md（整体认知）
2. 04-Integration-Workflow.md（制定计划）

**架构�?*�?
1. 01-Architecture-Overview.md（全貌）
2. 02-UI-Controls-System.md（组件设计）
3. 03-Data-Flow-Diagram.md（交互设计）

**前端开发�?*�?
1. 02-UI-Controls-System.md（控件库�?
2. 03-Data-Flow-Diagram.md（数据流�?
3. 04-Integration-Workflow.md（集成指南）

**后端开发�?*（Core 模块）：
1. 01-Architecture-Overview.md（架构）
2. 03-Data-Flow-Diagram.md（数据模型）

**集成工程�?*�?
1. 04-Integration-Workflow.md（集成计划）
2. 02-UI-Controls-System.md（控件集成）
3. 03-Data-Flow-Diagram.md（数据验证）

**QA / 测试**�?
1. 04-Integration-Workflow.md（检查清单）
2. 01-Architecture-Overview.md（系统理解）
3. 03-Data-Flow-Diagram.md（测试场景）

---

## 💡 使用建议

### 查看图表
- 使用支持 Mermaid �?Markdown 阅读器（推荐 GitHub�?
- 遇到渲染问题可复制代码块�?https://mermaid.live 在线查看

### 导出为图�?
```bash
# 需�?Node.js �?mermaid-cli
npm install -g @mermaid-js/mermaid-cli

# 导出单个文件
mmdc -i 01-Architecture-Overview.md -o 01-Architecture-Overview.png

# 批量导出
for file in *.md; do mmdc -i "$file" -o "${file%.md}.png"; done
```

### 更新维护
- 每次架构变更时应同步更新图表
- 保持版本号与主规范文档一?
- 检查链接引用的完整?

---

## 🔗 相关文档与 Efficient Human-AI Interaction 核心规范

> **【体系与规范定位声明】**  
> **Efficient Human-AI Interaction（高效 AI 人机交互体系）**定义 AI 与 Human 高效共同工作所需要的核心原则、交互规则、机器语义和产品实现边界。**Efficient Human-AI Interaction Specification（高效 AI 人机交互规范）**是其正式规范表达。**DeepBase** 是用于工程化实现和承载高效 AI 人机交互规范的 Delphi 软件框架。**HB** 是 DeepBase 中面向 Human 的统一人机交互承载与呈现基础设施，负责把高效 AI 人机交互体系中的语义、逻辑、状态、功能与交互行为，转化为 Human 可感知、可理解、可判断、可操作的交互。行为适配是 HB 的重要能力之一，但不是 HB 的全部。

### 高效 AI 人机交互规范分层结构（L1～L7）
- **L1：AI 人机认知哲学**：[`../DeepBase-AI-Human-Cognition-Philosophy-v1.md`](../DeepBase-AI-Human-Cognition-Philosophy-v1.md)（Frozen v1.0 · P1~P12 认知哲学母源，源于 ASTO 理论）
- **L2：AI 交付原则**：[`../DeepBase-AI-Delivery-Principles-v1.md`](../DeepBase-AI-Delivery-Principles-v1.md)（Frozen v1.0 · D1~D7 认知交付结构、四自质量检查框架）
- **L3：AI 人类介入原则**：[`../DeepBase-AI-Human-Intervention-Principles-v1.md`](../DeepBase-AI-Human-Intervention-Principles-v1.md)（Freeze Candidate v1.0 · H/A/E 三轴模型、最小必要介入、承诺边界）
- **L4：通用 AI 交互协议**：[`../DeepBase-General-AI-Interaction-Protocol-v1.md`](../DeepBase-General-AI-Interaction-Protocol-v1.md)（Freeze Candidate v1.0 · 判断协议、认知语素与选择语义）
- **L5：HB 人机行为适配基础设施**：[`../DeepBase-HB-Human-Behavior-Adaptation-Infrastructure-v1.md`](../DeepBase-HB-Human-Behavior-Adaptation-Infrastructure-v1.md)（Freeze Candidate v1.0 · 认知投射与行为适配母稿）
- **L6：机器语义与介入基础设施**：[`../DeepBase-Machine-Semantics-and-Intervention-Infrastructure-v1.md`](../DeepBase-Machine-Semantics-and-Intervention-Infrastructure-v1.md)（Frozen v1.0 · DeepBase 工程实现：DB-MSI）
- **L7：产品实现边界**：[`../DeepBase-Product-Realization-Boundary-v1.md`](../DeepBase-Product-Realization-Boundary-v1.md) / [`-r2`](../DeepBase-Product-Realization-Boundary-v1-r2.md)（Freeze Candidate v1.0 · 规范性产品绑定与符合性边界）

### HB 交互实现标准与下游接入资料
- **HB AI 选择式交互标准**：[`DeepBase-HB-AI-Choice-Interaction-Standard.md`](DeepBase-HB-AI-Choice-Interaction-Standard.md)（0–9 协议、1–7 多选扩展、Truthful State Machine）
- **AI 交付质量“四自”检查规范**：[`DeepBase-HB-AI-Delivery-Four-Self-Inspection-Standard.md`](DeepBase-HB-AI-Delivery-Four-Self-Inspection-Standard.md)（自营销/自承接/自成长/低客服验收标准、打分表与一票说明规则）
- **AI 偏好学习交互标准 [让我学习]**：[`DeepBase-HB-AI-Preference-Learning-Interaction-Standard.md`](DeepBase-HB-AI-Preference-Learning-Interaction-Standard.md)（4-A 交互母稿：偏好沉淀闭环、AI猜人确认、防过度泛化）
- **Core AI 人类判断记忆模型**：[`../DeepBase-AI-Human-Judgment-Memory.md`](../DeepBase-AI-Human-Judgment-Memory.md)（4-B 存储母稿：通用判断沉淀 Schema、场景指纹检索与注入）
- **通用大模型成本阶梯架构规范**：[`../DeepBase-AI-Cost-Optimization-and-Template-Tiering-Standard.md`](../DeepBase-AI-Cost-Optimization-and-Template-Tiering-Standard.md)（三级调用阶梯、本地模型暂缓；话术资产单一母稿在唤金 24）
- **HB 触点引擎与四自度量权威源**：[`../30.touchpoint.md`](../30.touchpoint.md)（触点契约、分级采样与四自验收 SSOT）
- **AsWish × 唤金共性现状资料包**：[`../AsWish-HuanJin-DeepBase-HB-AI-Interaction-Commonality-Pack.md`](../AsWish-HuanJin-DeepBase-HB-AI-Interaction-Commonality-Pack.md)

### 基础设计与集成指南
- 文档索引：`../00.00.DeepBase-文档索引-v1.0.md`
- 技术规范：`../03.03.DeepBase-4H-技术规范-v1.0.md`
- AI集成指南：`../02.quickstart.下游接入流程-downstream-integration.md`

---

## 📝 文档版本

| 版本 | 日期 | 文档�?| 变更 |
|------|------|--------|------|
| v0.3 | 2025-11-26 | 5 | 初版完成（包括索引） |

---

## 📞 反馈与建�?

- 有问题？检查图表渲染器兼容�?
- 图表不清晰？�?mermaid.live 上查看源代码
- 建议改进？提�?Issue �?Pull Request

---

**最后更�?*�?025-11-26  
**维护�?*：DeepBase 开发团�? 
**许可�?*：与 DeepBase 相同
