# 需求文档：意图澄清模块 (Intent Clarification Module)

## 简介

意图澄清模块是 DeepBase 框架的核心可插拔引擎，为所有 Deep 系列产品提供多层级、多姿态的意图澄清能力。该模块基于"姿态×深度"内部模型，对外呈现 L0-L4 五级澄清体系，支持从简单槽位填充到多专家圆桌讨论的完整意图理解链路。现有 L1 槽位填充实现（DeepBase.IntentClarification.pas）将作为 L1 Provider 保留并集成。

## 术语表

- **Engine（引擎）**: 意图澄清的核心协调器，管理会话生命周期和轮次循环
- **Posture（姿态）**: 引擎的内部行为模式，包括 Executive、Clarifying、Exploring、Advisory、Reflective 五种
- **Depth（深度）**: 0.0-1.0 的连续值，对外映射为 L0-L4 离散级别
- **Level（级别）**: 对外呈现的离散澄清层级（L0 背景识别、L1 指令型、L2 问题识别型、L3 单专家指导、L4 多专家决策）
- **Session（会话）**: 一次完整的意图澄清交互过程，包含多个轮次
- **Turn（轮次）**: 会话中的一次系统-用户交互
- **Signal（信号）**: 用户行为中检测到的模式（犹豫、矛盾、挫败、回避、突破）
- **Rapport（融洽度）**: 系统与用户之间的信任和熟悉程度模型
- **Budget（预算）**: 澄清过程的资源限制，包括轮次数、时间、信息价值
- **DomainAdapter（领域适配器）**: 为特定产品/领域提供上下文和知识的插件接口
- **Presenter（呈现器）**: 负责将澄清结果渲染为用户界面的插件接口
- **Anticipation（预判）**: 基于多信号源预测用户意图的子系统
- **Scaffold（脚手架）**: 系统生成假设供用户确认/否认，降低认知负荷的机制
- **Option_Framework（选项框架）**: 0-9 编号的标准化用户交互选项体系


## 需求

### 需求 1：引擎核心生命周期

**用户故事：** 作为产品开发者，我希望有一个统一的澄清引擎骨架来管理会话生命周期，以便各产品可以复用相同的澄清流程而无需重复实现。

#### 验收标准

1. WHEN 调用方发起一次新的澄清请求, THE Engine SHALL 创建一个新的 Session 并返回唯一的 SessionId
2. WHEN 一个 Session 被创建, THE Engine SHALL 将其状态初始化为 Active 并记录创建时间戳
3. WHEN 用户在一个 Active Session 中提交输入, THE Engine SHALL 执行一个完整的轮次循环（分析→决策→响应）并返回 TurnResult
4. WHEN 用户显式取消或选择选项 0, THE Engine SHALL 将 Session 状态转为 Completed 并执行优雅退出流程
5. WHEN Session 超过配置的空闲超时时间, THE Engine SHALL 将 Session 状态转为 Suspended 并保存检查点
6. WHEN 调用方请求恢复一个 Suspended Session, THE Engine SHALL 恢复检查点上下文并将状态转回 Active
7. IF Engine 在轮次处理中遇到未预期异常, THEN THE Engine SHALL 记录错误、保存当前状态并返回包含错误信息的 TurnResult 而非崩溃

### 需求 2：姿态与深度路由

**用户故事：** 作为产品开发者，我希望引擎能根据上下文自动选择合适的姿态和深度，以便用户获得恰当层级的澄清体验。

#### 验收标准

1. WHEN 引擎收到用户输入和上下文信息, THE Engine SHALL 计算一个 Posture（五选一）和 Depth（0.0-1.0）组合
2. WHEN Depth 值在 [0.0, 0.2) 范围内, THE Engine SHALL 将其映射为外部级别 L0（背景识别）
3. WHEN Depth 值在 [0.2, 0.4) 范围内, THE Engine SHALL 将其映射为外部级别 L1（指令型）
4. WHEN Depth 值在 [0.4, 0.6) 范围内, THE Engine SHALL 将其映射为外部级别 L2（问题识别型）
5. WHEN Depth 值在 [0.6, 0.8) 范围内, THE Engine SHALL 将其映射为外部级别 L3（单专家指导）
6. WHEN Depth 值在 [0.8, 1.0] 范围内, THE Engine SHALL 将其映射为外部级别 L4（多专家决策）
7. WHILE 一个 Session 处于 Active 状态, THE Engine SHALL 允许姿态在轮次之间动态切换
8. WHEN DomainAdapter 配置了 MaxLevel 限制, THE Engine SHALL 将 Depth 值钳制在对应的上限范围内

### 需求 3：0-9 选项框架

**用户故事：** 作为用户，我希望每次系统提问时都有清晰的编号选项可选，同时保留自由输入能力，以便我能快速响应而不必费力组织语言。

#### 验收标准

1. WHEN Engine 生成一个需要用户响应的 TurnResult, THE Engine SHALL 提供编号 1-8 的实质性选项列表（最多 8 个）
2. WHEN 提供选项列表时, THE Engine SHALL 标记一个推荐选项（高亮）
3. WHEN 用户输入数字 9, THE Engine SHALL 以不同角度重新生成选项和问题而非简单重复
4. WHEN 用户输入数字 0, THE Engine SHALL 执行分层退出行为（当前子话题→上一层→完全退出）
5. THE Engine SHALL 始终接受自由文本输入作为选项之外的替代响应方式
6. WHEN Engine 生成 TurnResult, THE Engine SHALL 包含进度提示信息（如"第 2 轮/预计还需 1-2 轮"）
7. WHEN 选项数量超过 8 个, THE Engine SHALL 截断为 8 个并将剩余选项归入"更多"类别

### 需求 4：L0-L1 纯规则处理

**用户故事：** 作为产品开发者，我希望 L0 和 L1 级别的澄清完全不依赖 LLM，以便在无网络或 LLM 不可用时仍能正常工作。

#### 验收标准

1. WHEN Depth 路由结果为 L0 或 L1, THE Engine SHALL 仅使用规则引擎处理而不调用 ILLMClient
2. WHEN 处理 L1 级别请求, THE Engine SHALL 复用现有 TIntentClarifier 的槽位填充逻辑
3. WHEN 处理 L0 级别请求, THE Engine SHALL 基于上下文状态和配置规则直接路由到目标意图
4. IF LLM 服务不可用, THEN THE Engine SHALL 将 L2-L4 请求降级到最高可用级别处理
5. WHEN 降级发生时, THE Engine SHALL 在 TurnResult 中标注降级信息以便 Presenter 告知用户

### 需求 5：L2 问题识别

**用户故事：** 作为用户，我希望系统能识别我表面请求背后的真实问题，以便获得更有针对性的帮助。

#### 验收标准

1. WHEN Depth 路由结果为 L2, THE Engine SHALL 使用 LLM 分析用户输入背后的潜在问题
2. WHEN 进行 L2 分析时, THE Engine SHALL 生成至少一个假设（Scaffold）供用户确认或否认
3. WHEN 用户否认一个假设, THE Engine SHALL 将否认信息作为约束条件纳入后续分析
4. WHEN L2 分析达成共识（用户确认问题定义）, THE Engine SHALL 将确认的问题定义记录到 Session 上下文中
5. WHILE 处于 L2 分析中, THE Engine SHALL 限制最大轮次数为 Budget 配置值

### 需求 6：L3 单专家指导

**用户故事：** 作为用户，我希望在需要专业方向指导时能获得一位虚拟专家的帮助，以便在复杂决策中获得专业视角。

#### 验收标准

1. WHEN Depth 路由结果为 L3, THE Engine SHALL 从 IPersonaRegistry 中选择一个最匹配的专家角色
2. WHEN 专家角色被选定, THE Engine SHALL 以该角色的知识背景和沟通风格生成响应
3. WHEN 用户对当前专家不满意, THE Engine SHALL 允许切换到另一个可用专家角色
4. WHILE 处于 L3 专家指导中, THE Engine SHALL 维持专家角色的一致性直到用户请求切换或会话结束

### 需求 7：L4 多专家圆桌

**用户故事：** 作为用户，我希望在面对重大决策时能获得多位虚拟专家的讨论和建议，以便从多角度理解问题并做出更好的决定。

#### 验收标准

1. WHEN Depth 路由结果为 L4, THE Engine SHALL 从 IPersonaRegistry 中选择 2-4 个互补的专家角色组成圆桌
2. WHEN 圆桌讨论进行时, THE Engine SHALL 让各专家依次发表观点并标注发言者身份
3. WHEN 专家观点存在分歧, THE Engine SHALL 明确呈现分歧点并请用户参与判断
4. WHEN 圆桌讨论达成结论, THE Engine SHALL 生成综合建议摘要并标注各专家的贡献

### 需求 8：信号检测器

**用户故事：** 作为产品开发者，我希望引擎能自动检测用户的情绪和行为信号，以便系统能适时调整交互策略。

#### 验收标准

1. WHILE Session 处于 Active 状态, THE Engine SHALL 在每个轮次对用户输入运行信号检测
2. WHEN 检测到 Hesitation 信号, THE Engine SHALL 增加 Scaffold 生成的数量以降低用户认知负荷
3. WHEN 检测到 Frustration 信号, THE Engine SHALL 触发姿态向 Executive 方向调整并缩短预计轮次
4. WHEN 检测到 Contradiction 信号, THE Engine SHALL 温和地指出矛盾并请求用户澄清
5. WHEN 检测到 Breakthrough 信号, THE Engine SHALL 确认突破并加速向结论收敛
6. THE Signal_Detector SHALL 为每个检测到的信号提供置信度分数（0.0-1.0）

### 需求 9：预判引擎

**用户故事：** 作为用户，我希望系统能预测我的意图并主动提供建议，以便减少我需要表达的信息量。

#### 验收标准

1. WHEN 用户开始输入时, THE Anticipation_Engine SHALL 基于时间模式、操作序列、上下文状态和历史模式四个信号源计算预测
2. WHEN 预判置信度超过配置阈值, THE Engine SHALL 将预判结果作为首选项呈现给用户
3. WHEN 呈现预判结果时, THE Engine SHALL 附带透明的证据说明（如"根据您上次的操作模式推测"）
4. WHEN 用户否认预判结果, THE Anticipation_Engine SHALL 将否认作为负反馈更新模型
5. IF 预判引擎不可用或未配置, THEN THE Engine SHALL 正常运行而不提供预判功能

### 需求 10：优雅退出机制

**用户故事：** 作为用户，我希望在任何时候都能退出澄清过程而不丢失进度，以便我可以稍后继续或直接执行当前最佳理解。

#### 验收标准

1. WHEN 用户显式请求退出, THE Engine SHALL 保存当前检查点并生成进度摘要
2. WHEN 信息已充分（所有必要槽位已填充）, THE Engine SHALL 自动结束澄清并输出最终意图
3. WHEN Budget 耗尽（达到最大轮次或时间限制）, THE Engine SHALL 基于当前最佳理解生成"最佳猜测+安全措施"执行方案
4. WHEN 检测到用户持续 Frustration, THE Engine SHALL 主动提议退出并提供当前最佳理解
5. WHEN 退出时, THE Engine SHALL 提供恢复提示以便用户日后可以继续
6. THE Engine SHALL 确保在任何退出路径下都不会进入死循环或无响应状态

### 需求 11：融洽度层

**用户故事：** 作为用户，我希望系统能记住我的偏好和沟通风格，以便随着使用时间增长获得越来越个性化的体验。

#### 验收标准

1. THE Rapport_Layer SHALL 维护每个用户的信任等级、熟悉度、偏好深度、沟通风格和边界信息
2. WHEN 一个 Session 完成时, THE Rapport_Layer SHALL 更新用户的融洽度模型
3. WHEN 开始新 Session 时, THE Engine SHALL 加载用户的融洽度模型以影响初始姿态和深度选择
4. WHILE 用户的信任等级低于阈值, THE Engine SHALL 采用更保守的交互策略（更少假设、更多确认）
5. THE Rapport_Layer SHALL 将融洽度数据持久化到 SQLite 存储以支持跨会话记忆

### 需求 12：插件架构

**用户故事：** 作为产品开发者，我希望通过实现少量接口就能将意图澄清能力集成到我的产品中，以便快速获得澄清功能而无需理解引擎内部实现。

#### 验收标准

1. THE Engine SHALL 通过 IClarificationEngine 接口暴露引擎骨架、会话管理和轮次循环功能
2. THE Engine SHALL 通过 IDomainAdapter 接口接收领域特定的上下文、知识和级别处理逻辑
3. THE Engine SHALL 通过 IPresenter 接口将澄清结果委托给调用方进行 UI 渲染
4. WHEN IDomainAdapter 未注册时, THE Engine SHALL 使用默认的通用领域适配器
5. WHEN IPresenter 未注册时, THE Engine SHALL 返回结构化数据而不尝试渲染
6. WHERE IPersonaRegistry 已注册, THE Engine SHALL 使用其提供的专家角色进行 L3/L4 处理
7. WHERE IAnticipationEngine 已注册, THE Engine SHALL 启用预判功能
8. WHERE IFeasibilityChecker 已注册, THE Engine SHALL 在澄清完成后验证意图的可执行性

### 需求 13：预设模板

**用户故事：** 作为产品开发者，我希望有预配置的模板可以快速启用适合我产品的澄清行为，以便无需从零配置所有参数。

#### 验收标准

1. WHEN 使用 'tool-command' 模板时, THE Engine SHALL 配置为 MaxLevel=L1、直接风格、无专家角色
2. WHEN 使用 'creative-assistant' 模板时, THE Engine SHALL 配置为 MaxLevel=L2、探索风格
3. WHEN 使用 'decision-advisor' 模板时, THE Engine SHALL 配置为 MaxLevel=L4、完整专家面板
4. THE Engine SHALL 允许在模板基础上覆盖单个配置项
5. WHEN 加载模板时, THE Engine SHALL 验证模板配置的完整性并报告缺失项

### 需求 14：降级与容错

**用户故事：** 作为产品开发者，我希望引擎在各种故障条件下都能提供有意义的响应，以便用户体验不会因为后端问题而完全中断。

#### 验收标准

1. WHEN LLM 调用失败, THE Engine SHALL 按 L4→L3→L2→L1→L0 路径逐级降级直到找到可用级别
2. WHEN 降级到 L0/L1 时, THE Engine SHALL 使用纯规则引擎提供基本澄清能力
3. WHEN 降级发生时, THE Engine SHALL 在 TurnResult 中包含降级原因和当前实际级别
4. IF 所有处理路径均失败, THEN THE Engine SHALL 返回包含错误描述的 TurnResult 而非抛出异常
5. WHEN LLM 响应超时, THE Engine SHALL 在配置的超时时间后中断等待并触发降级

### 需求 15："被理解"微时刻

**用户故事：** 作为用户，我希望系统的回应让我感到被理解和被尊重，以便我愿意继续深入交流。

#### 验收标准

1. WHEN 用户确认一个意图后, THE Engine SHALL 用系统自己的话复述确认（回声确认）
2. WHERE Rapport_Layer 记录了用户的历史陈述, THE Engine SHALL 在适当时机引用用户之前的表述（记忆引用）
3. WHEN 系统对用户意图不确定时, THE Engine SHALL 坦诚表达不确定性（如"我不太确定，帮我确认一下？"）
4. WHEN 预计还需多轮交互时, THE Engine SHALL 提供期望管理信息（如"再问一个问题就可以开始了"）

### 需求 16：会话序列化与恢复

**用户故事：** 作为用户，我希望能在数天后继续之前未完成的澄清过程，以便不必重新开始复杂的意图表达。

#### 验收标准

1. WHEN Session 进入 Suspended 状态, THE Engine SHALL 将完整会话状态序列化为 JSON 格式
2. WHEN 恢复 Session 时, THE Engine SHALL 从 JSON 反序列化恢复完整会话状态
3. FOR ALL 有效的 Session 状态对象, 序列化后再反序列化 SHALL 产生等价的对象（往返一致性）
4. WHEN 序列化数据损坏或版本不兼容, THE Engine SHALL 返回描述性错误而非崩溃
5. THE Engine SHALL 将序列化的 Session 数据持久化到 SQLite 存储

