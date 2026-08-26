# WO-20260825-DEEPRW-HB-RESEARCH-DISCOVERY

> ⛔ **本工单已作废（2026-08-26）**：基于过时的“双工作台”假设与 v1.1 之前组件清单，
> 由 [WO-20260826-DEEPRW-HB-V2](WO-20260826-DEEPRW-HB-V2.md) 取代。
> 其中仍然有效的研究语义组件需求（ClaimCard / EvidenceExcerpt / 矩阵网格等）
> 已按两层边界原则改由 DeepRW 业务层自建，不再请求 DeepBase 实现。以下原文仅作历史留档。

> 类型：HB 视觉系统下游组件与交互原型工单  
> 提出方：DeepRW  
> 承接方：DeepBase 视觉 AI / HB 组件线  
> 日期：2026-08-25  
> 优先级：P0  
> 状态：待承接  
> 目标主题：DeepRW「研究问题显影 → 研究执行与证据审计」双工作台视觉基础

## 1. 背景

DeepRW 是本地优先、证据优先的 AI 研究工作台。产品分成前后两个连续部分：

1. **研究发现 / 问题显影工作台**：帮助科研人员从模糊不适、异常观察、矛盾表达、反复失败、知识缺口和弱信号中显影问题场，形成多个可比较的研究主题/问题候选；
2. **研究执行 / 证据审计工作台**：冻结协议，运行模型与检索，管理 Source、Claim、EvidenceLink、Disagreement、ReviewDecision，构建并签发可复核成果。

前半部分法源为：

- `D:\_Progs\一元论\54-前线显影层（PFM）\SOURCE_OF_TRUTH.md`
- `D:\_Progs\一元论\54-前线显影层（PFM）\AA-母版源层\PFM.000-公共面统一理论主文.md`

PFM 最小输出为 `structured_problem_intake` 七字段：

- `issue_field`
- `pressure_bearer`
- `constraint`
- `weak_signal`
- `boundary_notice`
- `handoff_target`
- `stop_condition`

权威显影六步为：收声 → 定场 → 定压 → 定约 → 成形 → 转交。

参考工程：

- DeepBase `IntentClarification`：L0–L4 澄清、预算、退出、降级、持久化；
- DeepSpec：问题优先、Fog 状态、来源/问题/人类决策、research/grilling ticket；
- DeepFlow：Workflow、HumanTask、检查点、暂停恢复、过程/结果/状态产物。

## 2. 视觉目标

采用 DeepBase HB 视觉系统，默认建议：

- Theme：`deeparw-indigo`
- Density：`hdComfortable`
- 专业、克制、可信；风险状态不得只靠颜色表达；
- 首次用户 3 分钟内能理解：“系统不是替我决定选题，而是帮助我看见问题、比较候选、知道为什么值得研究”。

整体采用统一三栏研究桌面：

```text
左：阶段/对象导航
中：显影或证据主工作区
右：来源、边界、风险、历史 Inspector
底：任务、模型、成本、保存与恢复状态
```

## 3. 请求开发的 HB 通用组件

下列组件应优先设计为可被多个 Deep 产品复用的 HB 复合组件。业务规则仍留在 DeepRW，不下沉 DeepBase。

### 3.1 `THbStageRail`

用途：显示线性或带回退的阶段进度。

需要：

- completed / active / pending / warning / blocked；
- 每阶段计数、简短副标题；
- 支持键盘导航、紧凑/舒适密度；
- 可用于“收声→定场→定压→定约→成形→转交”和“问题→协议→运行→证据→报告→签发”。

### 3.2 `THbWorkspaceSplit`

用途：标准化左导航—中央工作区—右 Inspector 三栏布局。

需要：

- 左右栏可折叠、拖动、记忆宽度；
- 右侧 Inspector 支持 pin；
- 中央最小宽度保护；
- HiDPI、多显示器与 125%/150%/200% 缩放验证。

### 3.3 `THbSignalCard`

用途：保留原始表达、异常、矛盾、弱信号或观察片段。

显示：

- 原话/原始片段；
- 来源与时间；
- signal type；
- 置信度与是否人工确认；
- “保留原话”“关联问题场”“排除”动作。

### 3.4 `THbStructuredFieldCard`

用途：显示一个结构化字段的“当前判断—依据—不确定性—历史”。

适配：问题场、承压者、约束、边界、转交目标、停止条件，以及其他 Deep 产品结构字段。

需要：

- value / empty / candidate / confirmed / disputed；
- 来源计数、冲突提示；
- AI 候选与人工确认视觉上明确区分；
- 不允许用高亮制造“AI 已经判断正确”的暗示。

### 3.5 `THbCandidateCompare`

用途：2–5 个候选并排比较，并允许保留多个候选而不是强迫单选。

需要：

- 候选名称、核心问题、依据、反证、边界、下一步；
- pin / merge / split / reject / promote；
- 比较维度可由下游注入；
- 不能把综合评分设计成“系统替人决定”。

### 3.6 `THbEvidenceExcerpt`

用途：来源原文片段和精确定位。

需要：

- quote、source title、page/section/paragraph/URL anchor；
- snapshot/hash/verification 状态；
- 支持/反对/背景/未知语义；
- 点击定位原文；
- 截断展开与复制引用。

### 3.7 `THbBoundaryBanner`

用途：显示边界提示、停止条件、专业转介和阻断原因。

级别：notice / caution / stop / handoff。

要求：

- 图标＋标题＋正文＋动作，不只依赖颜色；
- stop/handoff 与普通 warning 视觉语义清晰区分；
- 支持“为什么”“转交到哪里”“记录决定”。

### 3.8 `THbProvenanceTrail`

用途：显示对象来源与变换链。

示例：

```text
原始表达 → 弱信号 → 问题场 → 研究主题候选 → 研究问题 → 协议
报告句子 → Finding → Claim → EvidenceLink → SourceSnapshot
```

要求支持：当前节点、缺失节点、断链、跳转与历史版本。

### 3.9 `THbGateResult`

用途：像构建/编译结果一样呈现 Pass / Warning / Error / Blocked。

适用：

- “是否足以进入选题候选”；
- “是否足以冻结研究问题”；
- “报告是否允许签发”。

需要：规则编号、解释、关联对象和修复动作。

### 3.10 `THbDecisionBar`

用途：人类审阅动作条。

默认动作：确认、否定、澄清、拆分、合并、暂缓、转交。

需要：

- Reject/Clarify 比 Accept 更低摩擦；
- 高影响确认可要求理由；
- 明示“AI 建议不等于人类决定”；
- 支持只读审阅状态。

## 4. DeepRW 业务专用组件（先在 DeepRW 层实现）

以下仅请求视觉规范/API 草案与 SVG 原型，不要求直接进入 DeepBase 通用包：

- `TDrwProblemFieldCanvas`：七字段 structured_problem_intake 总览；
- `TDrwResearchSeedCard`：从问题场生成的研究种子；
- `TDrwResearchQuestionCard`：研究问题候选及可行性、价值、证据可得性、伦理/风险；
- `TDrwClaimEvidenceCard`：Claim 与支持、反证、未知；
- `TDrwResearchBuildPanel`：选题冻结或报告签发门禁。

只有在第二个产品复用后，才提议下沉 DeepBase。

## 5. 关键页面原型

请优先提交 5 张可评审原型：

1. **问题显影首页**：输入不是“请输入研究题目”，而是“最近什么现象让你觉得解释不通？”；
2. **显影工作台**：左六步阶段，中间原始材料/问题场，右来源与边界 Inspector；
3. **研究候选比较页**：多个 ResearchSeed / ResearchQuestionCandidate 并列，显示依据、冲突和未知；
4. **Claim–Evidence 工作台**：后半部分证据审计主界面；
5. **Research Build 页**：选题冻结与报告签发共用的门禁视觉语言。

请同时给出 1366×768、1920×1080、150% DPI 三种关键截图。

## 6. 三分钟演示所需视觉状态

演示必须能连续表达：

1. 用户放入三段散乱研究笔记；
2. 系统保留原话并提取弱信号，不立即给答案；
3. 形成可编辑的七字段问题场；
4. 暴露“错场/错人/伪清/越界”等风险；
5. 生成 3 个研究主题候选并说明各自依据与未知；
6. 人类选择、拆分或合并候选；
7. 一个候选通过门禁，冻结为 ResearchQuestion；
8. 无缝进入后半部分 Research Protocol / Claim–Evidence 工作台。

## 7. 验收标准

- 使用 HB token，不在业务窗体硬编码颜色、圆角、间距和字体；
- WCAG AA；所有状态均有图标/文本冗余表达；
- 支持主题与密度实时切换；
- 支持键盘焦点和 screen-reader 可读标签（在 VCL 可达范围内）；
- 无数据、加载、降级、失败、只读、冻结状态齐全；
- 组件画廊中加入交互样例；
- 组件不嵌入 PFM 判断规则或 DeepRW 领域逻辑；
- 提供 Delphi API 草案、SVG、状态矩阵和最小交互说明；
- 若进入 DeepBase 包，需提供 DUnitX/截图基线或等价验收证据。

## 8. 非目标

- 不开发大型知识图谱画布；
- 不开发通用聊天窗；
- 不让 AI 自动替用户冻结题目；
- 不把显影设计成一次性长问卷；
- 不在 DeepBase 中实现 PFM、研究选题或证据裁决业务规则；
- 不以“综合评分最高”替代研究者判断。

## 9. 交付顺序建议

1. 视觉 token 映射与五页 SVG；
2. `THbWorkspaceSplit`、`THbStageRail`、`THbStructuredFieldCard`；
3. `THbSignalCard`、`THbBoundaryBanner`、`THbDecisionBar`；
4. `THbCandidateCompare`、`THbEvidenceExcerpt`、`THbProvenanceTrail`；
5. `THbGateResult` 与 HB Gallery；
6. DeepRW 业务组件视觉/API 草案。

## 10. 待视觉 AI 反馈

- 哪些组件已有 HB 组件可组合完成，无需新增类；
- 哪些组件值得下沉为 DeepBase 通用组件；
- 三栏布局在 VCL/HiDPI 下的最稳实现；
- Candidate Compare 在 1366 宽度下应改为横向滚动、卡片切换还是主从布局；
- 风险色、证据色与冻结/签发色的 token 映射建议；
- 完整工作量、拆批计划和首批可交付日期。
