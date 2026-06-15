# AI/LLM 集成模块评估报告

> **评估日期**: 2026-06-15
> **评估范围**: Core/LLM、Features/LLM、Features/Inference、Features/IntentClarification
> **排除范围**: Core 基础加密模块、Browser 自动化模块

---

## 评估摘要

**总评分: 5.5 / 10**

架构意图良好（分层 Provider、Proxy/Direct 双路由、意图澄清 FSM、多级 Provider L0-L4），但存在多个 **CRITICAL 级缺陷**（死锁、内存损坏、流式端点错误），多个核心功能实际不可用（Anthropic 流式、Direct 模式视觉流式、YAML 导入、FetchModels），线程安全问题广泛，代码重复严重，部分模块存在死代码与半成品迁移。整体处于"设计超前、实现欠稳"状态，需要集中修复 5 个 CRITICAL 问题后方可用于生产环境。

---

## 各子模块评估

### 1. Core/DeepBase.LLM.pas (~2600 行)

- **职责**: 全局 LLM 上帝类。Provider 抽象（OpenAI/Anthropic/Azure/LiteLLM/Ollama/Custom）、Windows Credential Manager 密钥持久化、Prompt 模板继承、调用历史与成本估算、同步/异步/流式 Chat。
- **设计质量**: 6/10

| 级别 | 问题 | 行号 |
|------|------|------|
| CRITICAL | `GetConfig` 中 `FCacheLock` 可重入死锁。`GetConfig` 持有 `FCacheLock`，缓存未命中时调用 `RefreshConfigCache`，后者再次获取同一 `TCriticalSection`。标准临界区不可重入。 | 1084-1089 |
| HIGH | `ChatStream` 为伪流式——内部同步调用 `Chat`，然后触发一次 `OnChunk`。`TLLMRequestOptions.Stream` 字段从未写入 JSON 请求体。 | 1739 |
| HIGH | `ILLMProvider` 接口声明（`GetName`/`GetModels`/`Chat`/`IsAvailable`）从未使用。Provider 分发通过 `if lpAnthropic then ... else ...` 硬编码。 | 150 |
| HIGH | `lpAzure` 分支直接 fall through 到 OpenAI 兼容路径，未实现 Azure 特有的 `/openai/deployments/{deployment}/chat/completions` 端点和 `api-key` 头。 | 1699 |
| MEDIUM | JSON 注入：错误路径中 `StringReplace(E.Message, '"', '\"')` 未转义反斜杠、换行符和控制字符，可能产生格式错误的 JSON。 | 1424, 1444 |
| MEDIUM | 不安全转型：`TJSONObject.ParseJSONValue(...) as TJSONObject` 无 nil/类型守卫。`TJSONNull` 响应在 nil 检查之前触发 AV。 | 1462, 1528 |
| MEDIUM | Schema 二象性：`LLMConfig`/`LLMConfiguration`、`ProviderCode`/`Provider`、`ModelId`/`Model` 双路径贯穿全文，未完成迁移。 | 549-583, 1136-1238, 1595-1653 |
| LOW | 模板加载 N+1 查询：`LoadPromptVersions` + `LoadPromptMetaBindings` 按 prompt 逐条查询。 | — |
| LOW | Credential Manager I/O 在 `FCacheLock` 内执行（`PersistLLMApiKey`），在高竞争下产生延迟尖峰。 | 1244 |

**改进建议**:
1. 将 `TCriticalSection` 替换为 `TMonitor` 或 `TMREWSync` 以支持可重入锁定；或重构为无锁缓存刷新模式。
2. 实现真正的 SSE 流式：在请求体中设置 `"stream": true`，逐行解析 SSE 事件。
3. 激活 `ILLMProvider` 接口，消除硬编码 if-else 分发。
4. 完成 Azure Provider 的端点和头部适配。

---

### 2. Core/DeepBase.LLM.Manager.pas (~1700 行)

- **职责**: 高级 Prompt 管理——4 级分类树、版本化 Prompt（最多 4 个版本）、Meta-Prompt 合并（PREFIX/SUFFIX/WRAP）、`BoundQuery` 上下文注入、版本 A-B 对比。
- **设计质量**: 5.5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| HIGH | `CreateStorageFromConnection` 在初始化中被调用两次，第二次释放第一次创建的对象并重建。若此时 `FConnectionStorageFactory` 未注册则抛出 `EInvalidOp`。 | 650-657 |
| HIGH | `SaveVersion`/`SetProductionVersion`/`DeleteVersion`/`BindMetaPrompt` 中存在与 `DeepBase.LLM.pas` 相同的可重入 `FCacheLock` 死锁。 | — |
| MEDIUM | 每次变更触发全量缓存重载（`RefreshCache`），在并发写入场景下产生惊群效应。 | 1540 |
| MEDIUM | `Execute` 中缺少输入验证——缺失变量静默保留为 `{{varname}}` 令牌。 | — |
| LOW | `ReplaceVariables` 使用 `rfIgnoreCase`，`{{name}}` 和 `{{Name}}` 匹配同一键，可能导致双重替换。 | 1063 |

**改进建议**:
1. 修复重入锁死锁，改用细粒度锁定或无锁方案。
2. 实施增量缓存更新（仅刷新变更的 prompt/category）。
3. `Execute` 中对未替换变量发出警告或异常。

---

### 3. Core/DeepBase.LLM.BillingClient.pas (~950 行)

- **职责**: 面向 Billing-Admin 代理的轻量 DB-independent LLM 客户端。SSE 流式、指数退避重试、取消、异步执行。
- **设计质量**: 6.5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| HIGH | 异常消息乱码：`'֤ʧ: '` 等中文因源文件编码不匹配而变成乱码。 | 510-516, 886 |
| MEDIUM | 伪流式：将整个 SSE 响应读入字符串后按 `#10` 分割，在所有 chunk 回调触发前完成全量缓冲。 | 711 |
| MEDIUM | 退避无抖动：`1000 * (1 shl (I - 1))` 精确产生 1s、2s、4s，多客户端同时重试时产生惊群。 | 867 |
| MEDIUM | `ChatAsync` 闭包捕获 `Self`，若调用方在 Task 完成前释放 `TBillingClient`，`Self` 指针悬空。 | 812-841 |
| LOW | `TChatHistory.TrimToSize` 仅裁剪 `FMessages`，加上 system prompt 槽位，实际输出可超过 `FMaxMessages` 1 条。 | 389 |
| LOW | `GetModels` 在非 2xx 时静默返回空数组，无法区分"无模型"与"端点不可达"。 | 919-946 |

**改进建议**:
1. 修复源文件编码（UTF-8 BOM 或统一编码约定）。
2. 实现真正的逐事件 SSE 流式解析。
3. 退避添加随机抖动（`Random(500)` ms）。
4. `ChatAsync` 使用 `IInterface` 引用计数保护 `Self`。

---

### 4. Core/DeepBase.LLM.ImportExport.pas

- **职责**: Prompt 域（分类、Prompt、版本、Meta-Prompt）的 JSON/YAML 序列化与反序列化，三种导入模式。
- **设计质量**: 4.5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| CRITICAL | `imOverwrite` 模式非原子：先删除所有 prompt、meta-prompt、分类，**再**解析导入内容。若解析或插入失败，数据库清空，无事务、无备份。 | 633-649 |
| HIGH | `YamlToJson` 为桩函数：返回 `{"error": "YAML parsing not fully implemented"}`。导出到 YAML 可用，导入不可用，API 表面具有误导性。 | 387-405 |
| MEDIUM | 分类去重仅依据 `(Level, Name)`，同名不同层级分类产生歧义 ID 映射。父 ID 重映射依赖父级先被处理。 | 662-693 |
| MEDIUM | `ExportSelectedPrompts` 在 `FLLMManager = nil` 时提前退出，泄漏 `UsedCategories`/`UsedMetas` 字典。 | 443-446 |
| LOW | `imReplace` 模式不清除已有 `PromptMetaBinding` 行，最终绑定集为旧+新的并集。 | 750-765 |
| LOW | 变量类型保真度丢失：`VarToStr(V.DefaultValue)` 对列表/JSON 默认值产生不可反序列化的表示。 | 229 |

**改进建议**:
1. **紧急**: 将 `imOverwrite` 包裹在数据库事务中，先解析验证成功后再执行删除+插入。
2. 实现 `YamlToJson` 或从 API 表面中移除 YAML 导入选项。
3. 使用 `try/finally` 确保字典在所有退出路径被释放。

---

### 5. Core/DeepBase.AIErrorHandler.LLMBridge.pas (65 行)

- **职责**: 将 `TAIErrorHandler.SetAICallback` 桥接到 `LLM().Chat`，使用 `TierFast`。
- **设计质量**: 5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| MEDIUM | 无日志记录：LLM 失败时无诊断输出。 | — |
| MEDIUM | 60 秒超时（继承自 `TDeepBaseLLM`），对错误诊断回调不合适，应为 5-10 秒。 | — |
| MEDIUM | 无熔断器：中断期间每次调用都触发完整超时。 | — |
| LOW | 无重试：瞬态 429 导致单次失败。 | — |
| LOW | `TierFast` 硬编码（行 45），无备用层降级。 | 45 |

---

### 6. Features/DeepBase.LLM.Types.pas

- **职责**: 纯类型声明——`TModelTier`、`TChatMessage`、`TChatResult`、`TImageGenerationResult`、`TProviderConfig`。
- **设计质量**: 6/10

| 级别 | 问题 | 行号 |
|------|------|------|
| LOW | `TierVision`/`TierImageFallback` 均映射到 `'vision_fallback'`，命名空间语义冲突。 | 39-41 |
| LOW | `TModelInfo` 声明但从未使用。 | 127-141 |

---

### 7. Features/DeepBase.LLM.Client.pas

- **职责**: 定义 `ILLMClient` 和 `ILLMAdmin` 接口。
- **设计质量**: 7/10

| 级别 | 问题 | 行号 |
|------|------|------|
| LOW | `ChatVisionStream` 要求 `ASystemPrompt: string` 无默认值，而 `ChatVision`（行 39）有 `= ''` 默认值，接口不一致。 | 58 |

---

### 8. Features/DeepBase.LLM.Config.pas

- **职责**: 内存配置存储、DPAPI 加密密钥持久化、层-模型映射。
- **设计质量**: 5.5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| MEDIUM | `ProviderCanRunWithoutKey` 在 Config.pas 和 Service.pas 中重复实现。 | 214-228 |
| MEDIUM | DPAPI 在非 Windows 平台静默失败关闭，所有 API 密钥静默消失，无诊断。 | 73-101 |
| MEDIUM | `GetApiKey` 每次调用都执行 DPAPI 解密（DPAPI 调用非免费操作），应缓存。 | 155-160 |
| LOW | `ParseJSONValue as TJSONObject` 不安全转型，JSON 合法���非对象时抛出 `EInvalidCast`。 | 188 |
| LOW | `AddProvider` 无验证：空端点、格式错误、负优先级均被静默接受。 | 116-129 |

---

### 9. Features/DeepBase.LLM.ConfigBridge.pas

- **职责**: 从旧式 `TLLMConfigArray` 到 `TLLMConfigStore` 的单向迁移。
- **设计质量**: 4/10

| 级别 | 问题 | 行号 |
|------|------|------|
| MEDIUM | `ConfigToProvider` 丢弃 Priority，始终为 0。 | 31 |
| MEDIUM | `ImportConfigs` 每个 Provider 仅保留一个模型：`SetLength(LModels, 1)`。 | 48-53 |
| LOW | Nil store 守卫静默失败。 | 41 |

---

### 10. Features/DeepBase.LLM.HTTP.pas

- **职责**: HTTP 传输与格式适配（OpenAI/Anthropic API）。
- **设计质量**: 3.5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| CRITICAL | **Anthropic 流式请求发送到错误端点**：始终使用 `/chat/completions` 而非 `/messages`。所有 Anthropic 流式调用返回 404。 | 592 |
| HIGH | 伪流式：整个 SSE 响应在 chunk 回调触发前全量缓冲。 | 553-665 |
| CRITICAL | `FillChar(Result, SizeOf(Result), 0)` 用于托管记录（含 string 字段），**破坏字符串引用计数**，可能导致 AV 或内存泄漏。应使用 `Result := Default(TChatResult)`。 | 565 |
| MEDIUM | `ParseAnthropicResponse` 仅读取第一个 content block，多 block 响应（text + tool_use + thinking）静默丢失。 | 296-313 |
| HIGH | `FetchModels` 为桩函数，返回空数组。Admin 模型发现功能不可用。 | 667-670 |
| MEDIUM | HTTP 层无重试逻辑。 | — |

**改进建议**:
1. **紧急**: 修复 Anthropic 流式端点为 `/messages`。
2. **紧急**: 将所有 `FillChar(Result, SizeOf(Result), 0)` 替换为 `Result := Default(TChatResult)`。
3. 实现真正的逐事件 SSE 流式解析。
4. `ParseAnthropicResponse` 遍历所有 content blocks。

---

### 11. Features/DeepBase.LLM.Proxy.pas

- **职责**: 本地 `DeepLLMProxy` 服务客户端，实现 `ILLMClient`。
- **设计质量**: 4.5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| CRITICAL | `FillChar(Result, SizeOf(Result), 0)` 用于托管记录——同 HTTP.pas 的内存损坏 bug，共 4 处。 | 199, 338, 497 |
| MEDIUM | `Probe` 超时 200ms 过于激进，误报导致 60 秒的直连模式降级。 | 95 |
| MEDIUM | `ChatVisionStream` 使用代理特有格式 `[image:%s;base64,%s] %s`，与 Service.pas 的 `data:%s;base64,%s|%s` 不一致。同一负载根据代理/直连路径序列化方式不同。 | 576-588 |
| LOW | `GenerateImageStream` 进度仅触发 0.0 和 1.0，无中间事件。 | 536-566 |
| LOW | 无连接池：每次调用新建 `THTTPClient`。 | 119 |
| LOW | `FCallCount` 非线程安全，并发调用产生竞态。 | 346 |

---

### 12. Features/DeepBase.LLM.Service.pas

- **职责**: 中心服务。`TLLMService` 实现 `ILLMClient` + `ILLMAdmin`。全局 `LLM()`/`LLMAdmin()` 代理优先路由。
- **设计质量**: 4/10

| 级别 | 问题 | 行号 |
|------|------|------|
| CRITICAL | `ChatVisionStream` 发送格式错误的消息：图像以 `data:%s;base64,%s|%s` 嵌入纯文本，OpenAI 和 Anthropic 均无法识别。**直连模式视觉流式对两个 Provider 均不可用。** | 692-705 |
| HIGH | `ModelMatchesProvider` 硬编码启发式：仅匹配 `claude`、`llama`、`mistral`、`gpt` 等。DeepSeek、Grok、Cohere、GLM、Yi 等新模型全部落入 OpenAI catch-all。 | 251-272 |
| HIGH | `CallWithFallback` 无退避：失败 Provider 立即重试所有层模型，产生重试放大。 | 349-375 |
| HIGH | `GLLMLock` 在网络探测期间持有：`TryGetProxyClient` 获取锁后执行阻塞 HTTP 调用（200ms-30s），所有其他线程阻塞于 `LLM()`。 | 144-172 |
| MEDIUM | `FCallCount`/`FLastDurationMs` 非线程安全，多线程写入无同步。 | 28-29 |
| MEDIUM | Finalization 释放已接口引用的对象：`GLLMService.Free` 时可能存在接口引用，导致释放后使用。 | 846-857 |
| LOW | Tier 默认值在三处重复定义。 | 404-425, 436-452, 478-489 |

---

### 13. Features/DeepBase.Inference.Types.pas

- **职责**: ONNX 推理框架纯类型声明。异常层次、枚举、记录、接口。
- **设计质量**: 5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| LOW | `GraphOptLevel := 99` 依赖 ONNX 枚举序数的魔法数字，枚举变动时静默失效。 | 152 |
| LOW | `TInferenceConfig.FromConfig` 无范围验证，负线程数被接受。 | 166-176 |
| HIGH | `TInferenceInput.Int32` 工厂分配 `SizeOf(Integer)` 字节，不考虑 shape。`Shape=[1000]` 仅分配 4 字节而非 4000 字节。 | 192-200 |

---

### 14. Features/DeepBase.Inference.Runtime.pas

- **职责**: ONNX 运行时生命周期管理。执行提供者附加（CPU/DirectML/CUDA）。
- **设计质量**: 5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| MEDIUM | 进程全局 `DefaultSessionOptions` 在无协调下修改，两个并发 `Initialize` 调用互相损坏。 | 102-138 |
| MEDIUM | `Shutdown` 后无法分离 EP：DirectML/CUDA 一旦附加，即使 shutdown 后仍持续存在。 | 160-178 |
| LOW | `AttachProviderDML` 的 `DisableMemPattern` 和 `SetExecutionMode(ORT_SEQUENTIAL)` 影响所有会话。 | 188-217 |

---

### 15. Features/DeepBase.Inference.Service.pas

- **职责**: 推理静态门面。`TInferenceService` 类方法。
- **设计质量**: 5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| HIGH | 不安全转型：`(ASession as TInferenceSession).RunTyped(AInputs)`。`RunTyped` 不在接口上，替代实现触发 `EInvalidCast`。违反 Liskov 替换原则。 | 179 |
| MEDIUM | `CreateSession` 在整个模型文件加载期间持有 `FLock`，阻塞所有其他线程。 | 136-162 |

---

### 16. Features/DeepBase.Inference.Session.pas

- **职责**: ONNX 会话管理——模型加载、推理、元数据提取。
- **设计质量**: 4.5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| CRITICAL | 输出字节计数溢出：`LByteCount := 1; for j := 0 to High(LOutShape) do LByteCount := LByteCount * NativeUInt(LOutShape[j]); LByteCount := LByteCount * SizeOf(Single)`，无溢出检查。Shape `[100000, 100000, 100000]` 产生 ~4TB 分配。 | 364-367 |
| MEDIUM | 编码不一致：`GetCustomMetadata` 使用 `AnsiString(PAnsiChar(...))` 而 `ExtractModelInfo` 使用 `UTF8ToString(PAnsiChar(...))`，Unicode 键被损坏。 | 522, 265 |
| MEDIUM | 托管记录堆复制：`GetMem(FOrtSession, SizeOf(TORTSession)); TORTSessionPtr(FOrtSession)^ := LSession`，安全性取决于 `TORTSession` 的复制语义。 | 126-127 |
| MEDIUM | `TInferenceSession` 无线程安全：并发 `Run` 调用共享 `TORTSession` 指针无保护。 | — |

---

### 17. Features/DeepBase.Inference.IoC.pas

- **职责**: 一次性推理 IoC 引导。
- **设计质量**: 5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| LOW | 嵌套双重 shutdown：两个 `try/except` 块含重叠 `Shutdown` 调用。功能安全但令人困惑。 | 52-80 |
| LOW | `Initialize` 无超时：GPU 驱动枚举挂起时无限阻塞。 | — |

---

### 18. Features/DeepBase.IntentClarification.pas (823 行)

- **职责**: 基础单元，定义所有共享类型、`TIntentClarifier` 类、JSON 解析辅助。
- **设计质量**: 5.5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| HIGH | `CreateEngineWithPreset` 忽略预设参数：无论 `APresetName` 值如何，创建相同引擎。 | 812-821 |
| MEDIUM | `Chr(Ord('A') + I)` 在超过 26 个选项后产生非字母字符。 | 306 |
| MEDIUM | 逗号替换为点号破坏千位分隔符：`StringReplace(LValue.Value, ',', '.', [rfReplaceAll])`。 | 229 |
| LOW | `Copy(Result, 1, FPolicy.MaxPromptChars)` 可能在代理对中间截断。 | 618-620 |
| LOW | `EIntentClarification` 声明但从未抛出。 | 11 |

---

### 19. Features/DeepBase.IntentClarification.Engine.pas (1299 行)

- **职责**: 核心引擎，编排完整澄清轮次循环。上帝对象。
- **设计质量**: 4.5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| HIGH | `FLock`/`FGlobalLock` 别名：同一 `TCriticalSection` 的两个名称，不同方法使用不同名称，维护隐患。 | 207 |
| HIGH | 每会话锁在 LLM 调用期间持有：会话锁定贯穿整个 LLM 超时周期（10s+），阻塞并发访问。 | 860-1091 |
| MEDIUM | 缩进混乱：`FLock.Enter` 块缩进错位，看似位于错误的 `if` 块内。 | 783-808 |
| MEDIUM | Checkpoint 保存在 4 个位置重复。 | 515-526, 1041-1053, 1141-1154, 1249-1261 |
| MEDIUM | Token 估算粗糙：`Length(Question) div 4`，对 CJK 文本严重偏离。 | 963 |
| LOW | 三重会话管理：Engine 自有内联会话字典、`TSessionManager`、`TSessionFSMFactory`。仅 Engine 的实际连接。 | — |

---

### 20. Features/DeepBase.IntentClarification.Router.pas (282 行)

- **职责**: 从信号计算姿态（posture）、深度和层级。
- **设计质量**: 5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| MEDIUM | 魔法数字 `0.01`：`Result := LMaxDepth - 0.01`，层级边界变化时脆弱。 | 112 |
| MEDIUM | 线性深度增长：`LDepth + (TurnCount * 0.02)`，50 轮后无论行为如何始终达到 L4。 | 246 |
| LOW | 所有阈值硬编码，无配置接口。 | — |

---

### 21. Features/DeepBase.IntentClarification.Session.pas (465 行)

- **职责**: 会话生命周期——状态机验证、空闲超时、检查点保存/恢复。
- **设计质量**: 5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| MEDIUM | 魔法数字转型：`IC_STATUS_COMPLETED = TSessionStatus(2)`，枚举顺序变更时失效。 | 141-142 |
| LOW | `TStateMachine` 每次调用创建——配置为静态的，可缓存。 | 278 |
| LOW | `StatusToTrigger` 默认返回 `stComplete`，未知状态静默触发完成，应抛出异常。 | 187 |

---

### 22. Features/DeepBase.IntentClarification.SessionFSM.pas (165 行)

- **职责**: 替代性更丰富的 FSM——7 个触发器，EventBus 插桩工厂。
- **设计质量**: 3/10

| 级别 | 问题 | 行号 |
|------|------|------|
| HIGH | **死代码**：从未被 Engine 或 `TSessionManager` 引用。并行会话触发枚举（`TSessionFSMTrigger` vs `TSessionTrigger`）冗余。 | — |
| MEDIUM | `CreateWithEvents` 名称误导：仅日志记录，不发布 EventBus 事件。 | 117-163 |

---

### 23. Features/DeepBase.IntentClarification.LLMResilience.pas (650 行)

- **职责**: 装饰器，为 `ILLMClient` 添加重试、超时和熔断。
- **设计质量**: 5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| CRITICAL | `TTask.Run` + `Wait` 线程泄漏：超时后 Task 继续运行，消耗线程池线程和网络连接。在持续超时下导致线程池耗尽。 | 293-304 |
| MEDIUM | 线性退避：`Sleep(100 * (LAttempt + 1))`，对 LLM 服务器过载过于激进。 | 353 |
| MEDIUM | 重复的 harness 方法：`ExecuteWithResilience` / `ExecuteWithResilienceImage` 近乎相同，将逐渐漂移。 | 248-355, 362-481 |
| MEDIUM | 流式韧性不一致：`ChatStream`/`ChatVisionStream` 检查熔断但无重试/超时。`GenerateImageStream` 完全无熔断检查。 | 565 |

**改进建议**:
1. 超时时使用 `TTask.Run` + `CancellationTokenSource` 取消底层 HTTP 请求，而非仅 `Wait(timeout)`。
2. 退避改为指数 + 随机抖动。
3. 合并重复的 harness 方法为泛型实现。

---

### 24. Features/DeepBase.IntentClarification.Anticipation.pas (272 行)

- **职责**: 基于 4 个信号源的启发式意图预测。
- **设计质量**: 4.5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| MEDIUM | 反馈收集但从未消费：`FFeedback` 列表无界增长，死状态。 | 62-63 |
| LOW | `AnalyzeTemporal` 使用 `Now`，非确定性，不可测试。 | 89 |
| LOW | PII 泄漏：`BuildSource('historical', AContext.UserId, ...)` 将 UserId 放入信号标签。 | 223 |

---

### 25. Features/DeepBase.IntentClarification.Budget.pas (93 行)

- **职责**: 轮次/时间/Token 预算追踪。
- **设计质量**: 5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| LOW | `TBudgetController` 未接口化，无法在测试中 mock 替换。 | 17 |
| LOW | `IsExhausted` 为单行包装器，未增加价值。 | 88 |

---

### 26. Features/DeepBase.IntentClarification.SignalDetector.pas (377 行)

- **职责**: 基于关键词的信号检测（犹豫、矛盾、沮丧、回避、突破）。
- **设计质量**: 5/10

| 级别 | 问题 | 行号 |
|------|------|------|
| MEDIUM | 仅中文关键词，无区域感知。 | — |
| MEDIUM | 矛盾检测高误报率：`"要"` 出现在许多与意愿无关的词语中。 | 200-211 |
| LOW | `.Contains` 字符串依赖 `StrUtils` helper，需验证编译。 | 128, 134, 142 |
| LOW | 冗余 `ToLower`：每次 `Detect` 调用计算 5 次。 | 179 |

---

### 27. Provider 分层文件 (L0-L4)

| Provider | 行数 | 质量 | 主要问题 |
|----------|------|------|----------|
| **L0** | 92 | 7/10 | 清晰最简，快速路由路径。 |
| **L1** | 169 | 5/10 | 适配器到旧式 `TIntentClarifier`，始终将第一选项标记为推荐（行 150），丢弃澄清器自身逻辑。 |
| **L2** | 347 | 6/10 | 每会话拒绝假设追踪，有界增长。英文系统提示用于中文 UI（行 111-118）。 |
| **L3** | 339 | 5.5/10 | 每会话专家一致性，冗余专家切换逻辑（行 296-303 vs 130-167）。 |
| **L4** | 393 | 4/10 | 最复杂。多专家圆桌与部分失败处理。**硬编码字符串比较判断合成失败**（行 371）`LSynthesis = '综合分析...'`，极度脆弱。**无每会话状态**——违反 L3 提供的专家一致性。 |

---

## LLM 代理层评估

**代理优先路由架构**:
```
LLM() → TryGetProxyClient(200ms probe) → [Proxy: DeepLLMProxy 服务]
                                        → [Direct: HTTP.pas 直连 Provider]
```

**问题**:
1. **全局锁阻塞**: `GLLMLock` 在代理探测期间持有（200ms-30s），所有并发 `LLM()` 调用串行化。
2. **探测超时过短**: 200ms 在负载下频繁误报，降级到直连模式 60 秒。
3. **直连模式视觉流式损坏**: Service.pas 和 Proxy.pas 序列化格式不一致，两个 Provider 均无法识别。
4. **模型-Provider 匹配启发式过窄**: 仅识别 `claude`/`gpt`/`llama`/`mistral`，新模型全部落入 OpenAI catch-all。
5. **无连接池**: 直连模式每次调用新建 `THTTPClient`。

**评分**: 4.5/10 — 设计意图合理但实现问题严重。

---

## 意图澄清系统评估

**架构**:
```
用户输入 → SignalDetector → Router(posture/depth/level) → Provider(L0-L4) → Engine → LLM → 响应
                              ↑ Anticipation (预测)
                              ↑ Budget (预算控制)
                              ↑ SessionFSM (状态机)
                              ↑ LLMResilience (韧性)
```

**优点**:
- 分层 Provider 设计（L0 快速路由 → L4 多专家圆桌）思路优秀。
- 信号检测 + 意图预测的双轨设计有创新性。
- 预算控制（轮次/时间/Token）实用。

**问题**:
1. **会话管理三重冗余**: Engine 内联字典、`TSessionManager`、`TSessionFSMFactory` 并存，仅 Engine 实际连接。
2. **SessionFSM 为死代码**: 165 行的 FSM 实现未被任何模块引用。
3. **Engine 锁粒度过粗**: 会话锁贯穿 LLM 调用全程（10s+），阻塞并发。
4. **L4 Provider 脆弱**: 硬编码中文字符串比较判断合成失败，无每会话状态。
5. **Token 估算对 CJK 不准确**: `Length(Question) div 4` 对中文文本严重低估。
6. **`CreateEngineWithPreset` 为桩**: 预设参数被忽略。

**评分**: 5/10 — 架构创新但实现不成熟。

---

## 优先级排序的改进建议（Top 5）

### P0 — CRITICAL（必须在下��迭代修复）

1. **修复 `FillChar(Result, SizeOf(Result), 0)` 内存损坏**
   - 文件: `Features/DeepBase.LLM.HTTP.pas:565`, `Features/DeepBase.LLM.Proxy.pas:199,338,497`
   - 替换为: `Result := Default(TChatResult)`
   - 影响: 所有 Chat/ChatVision/GenerateImage 调用均存在字符串引用计数损坏风险

2. **修复 Anthropic 流式端点错误**
   - 文件: `Features/DeepBase.LLM.HTTP.pas:592`
   - 修复: Anthropic 流式请求发送到 `/messages` 而非 `/chat/completions`
   - 影响: Anthropic 流式功能完全不可用

3. **修复可重入锁死锁**
   - 文件: `Core/DeepBase.LLM.pas:1084-1089`, `Core/DeepBase.LLM.Manager.pas`（多处）
   - 修复: 将 `TCriticalSection` 替换为 `TMonitor` 或重构为无锁缓存刷新
   - 影响: 缓存未命中时线程死锁

4. **修复 `imOverwrite` 数据丢失风险**
   - 文件: `Core/DeepBase.LLM.ImportExport.pas:633-649`
   - 修复: 先解析验证成功后在事务中执行删除+插入
   - 影响: 导入失败时数据库被清空

5. **修复 LLMResilience 线程池耗尽**
   - 文件: `Features/DeepBase.IntentClarification.LLMResilience.pas:293-304`
   - 修复: 超时时通过 `CancellationTokenSource` 取消底层请求
   - 影响: 持续超时下线程池耗尽

### P1 — HIGH（应在本迭代修复）

6. 修复直连模式视觉流式消息格式（Service.pas:692-705）
7. 实现 `GLLMLock` 细粒度化，避免网络 I/O 期间全局阻塞（Service.pas:144-172）
8. 完成 Azure Provider 端点和头部适配（Core/DeepBase.LLM.pas:1699）
9. 修复 BillingClient 异常消息编码乱码（Core/DeepBase.LLM.BillingClient.pas:510-516）
10. 修复 Inference.Session 输出字节计数溢出（Features/DeepBase.Inference.Session.pas:364-367）

### P2 — MEDIUM（技术债清理）

11. 实现真正的 SSE 流式（HTTP.pas、BillingClient.pas、Core/DeepBase.LLM.pas）
12. 激活 `ILLMProvider` 接口，消除硬编码 Provider 分发
13. 消除死代码：`ILLMProvider`、`TModelInfo`、`EIntentClarification`、`SessionFSM`、`CreateEngineWithPreset` 预设参数
14. 统一直连/代理视觉流式序列化格式
15. 消除代码重复：`ProviderCanRunWithoutKey`、Tier 默认值（3 处）、Checkpoint 保存（4 处）、`ExecuteWithResilience` 双版本

---

## 附录：模块质量矩阵

| 模块 | 行数 | 评分 | CRITICAL | HIGH | MEDIUM | LOW |
|------|------|------|----------|------|--------|-----|
| Core/DeepBase.LLM.pas | ~2600 | 6.0 | 1 | 3 | 3 | 2 |
| Core/DeepBase.LLM.Manager.pas | ~1700 | 5.5 | 0 | 2 | 2 | 1 |
| Core/DeepBase.LLM.BillingClient.pas | ~950 | 6.5 | 0 | 1 | 3 | 2 |
| Core/DeepBase.LLM.ImportExport.pas | ~800 | 4.5 | 1 | 1 | 2 | 2 |
| Core/DeepBase.AIErrorHandler.LLMBridge.pas | 65 | 5.0 | 0 | 0 | 3 | 2 |
| Features/DeepBase.LLM.Types.pas | ~140 | 6.0 | 0 | 0 | 0 | 2 |
| Features/DeepBase.LLM.Client.pas | ~80 | 7.0 | 0 | 0 | 0 | 1 |
| Features/DeepBase.LLM.Config.pas | ~300 | 5.5 | 0 | 0 | 3 | 2 |
| Features/DeepBase.LLM.ConfigBridge.pas | ~55 | 4.0 | 0 | 0 | 2 | 1 |
| Features/DeepBase.LLM.HTTP.pas | ~670 | 3.5 | 2 | 1 | 2 | 0 |
| Features/DeepBase.LLM.Proxy.pas | ~600 | 4.5 | 1 | 0 | 2 | 3 |
| Features/DeepBase.LLM.Service.pas | ~860 | 4.0 | 1 | 3 | 2 | 1 |
| Features/DeepBase.Inference.Types.pas | ~210 | 5.0 | 0 | 1 | 0 | 2 |
| Features/DeepBase.Inference.Runtime.pas | ~220 | 5.0 | 0 | 0 | 2 | 1 |
| Features/DeepBase.Inference.Service.pas | ~180 | 5.0 | 0 | 1 | 1 | 0 |
| Features/DeepBase.Inference.Session.pas | ~530 | 4.5 | 1 | 0 | 3 | 0 |
| Features/DeepBase.Inference.IoC.pas | ~80 | 5.0 | 0 | 0 | 0 | 2 |
| Features/DeepBase.IntentClarification.pas | 823 | 5.5 | 0 | 1 | 2 | 2 |
| Features/DeepBase.IntentClarification.Engine.pas | 1299 | 4.5 | 0 | 2 | 3 | 1 |
| Features/DeepBase.IntentClarification.Router.pas | 282 | 5.0 | 0 | 0 | 2 | 1 |
| Features/DeepBase.IntentClarification.Session.pas | 465 | 5.0 | 0 | 0 | 1 | 2 |
| Features/DeepBase.IntentClarification.SessionFSM.pas | 165 | 3.0 | 0 | 1 | 1 | 0 |
| Features/DeepBase.IntentClarification.LLMResilience.pas | 650 | 5.0 | 1 | 0 | 3 | 0 |
| Features/DeepBase.IntentClarification.Anticipation.pas | 272 | 4.5 | 0 | 0 | 1 | 2 |
| Features/DeepBase.IntentClarification.Budget.pas | 93 | 5.0 | 0 | 0 | 0 | 2 |
| Features/DeepBase.IntentClarification.SignalDetector.pas | 377 | 5.0 | 0 | 0 | 2 | 2 |
| Provider L0-L4 | ~1340 | 5.0 | 0 | 0 | 2 | 1 |
| **合计** | **~15,374** | **5.5** | **8** | **16** | **42** | **35** |
