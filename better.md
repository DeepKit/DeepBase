# DeepBase 架构质量校准与优化总控计划

> 更新日期: 2026-05-14  
> 用途: 作为 DeepBase 架构库后续质量评估、优化、修复和验收的推进总表。  
> 当前原则: 先建立可信基线，再做全局架构评估，再按板块逐项校准；DeepShell、浏览器自动化、意图识别三个仍在优化中的板块放到最后处理。

---

## 0. 工作原则

### 0.1 不直接跳入大改

- 先评估，再修复；先恢复编译和门禁，再做架构拆分。
- 每个修复必须能回答三个问题：
  - 修了什么风险。
  - 用什么测试或脚本验证。
  - 是否改变公开 API、包边界或下游接入方式。
- 已有未提交修改较多，任何修复都必须避免覆盖不相关改动。

### 0.2 当前暂缓到最后的板块

以下三个板块不作为前期质量收敛主线，除非它们阻塞全库编译：

1. `DeepShell` / VCL 统一桌面壳。
2. `BrowserAutomation` / 浏览器自动化。
3. `IntentClarification` / 意图识别与澄清。

处理顺序上，它们排在全局架构、基础核心、DB/安全/商业化、通用功能、UI 适配、工具示例之后。

### 0.3 每轮优化闭环

每个板块按同一闭环推进：

1. 读取设计文档、包文件、源码、测试和最近结果。
2. 给出板块评分与风险清单。
3. 修复 P0/P1 问题。
4. 补最小回归测试或架构检查。
5. 重跑对应门禁。
6. 更新 `better.md` 状态。

---

## 1. 全部架构评估

目标是先判断 DeepBase 作为公共架构库是否稳定、分层清晰、可发布、可被下游安全接入。

### 1.1 基线确认

- [ ] 记录当前工作区状态：`git status --short`。
- [ ] 确认当前可用 Delphi 环境、Win64 编译器和脚本入口。
- [ ] 不信任旧测试 XML，重跑当前门禁。
- [ ] 整理当前失败矩阵：编译失败、测试失败、架构失败、示例失败、文档/编码问题。

建议基线命令：

```powershell
cmd /c compile_test.bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Scripts\run_tests.ps1 -Type Unit -CI
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Scripts\run_tests.ps1 -Type Integration -CI
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Scripts\run_architecture_checks.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Scripts\build_examples_win64.ps1
```

### 1.2 全局评估维度

| 维度 | 检查内容 | 输出 |
|------|----------|------|
| 包边界 | `Core -> Services -> {Persistence, Features} -> {VCL, FMX}` 是否成立 | 违规依赖清单 |
| 编译健康 | 主包、测试、示例是否可编译 | 编译阻塞清单 |
| 测试可信度 | 是否存在 0 tests、过滤误报、旧 XML 误判 | 门禁可信度结论 |
| API 稳定性 | facade、接口、deprecated、异常语义是否一致 | 破坏性变更风险 |
| 生命周期 | Manager/EventBus/Scheduler/WorkerQueue/FileWatcher/Updater 是否统一 start/stop/drain | 并发释放风险 |
| DB/schema | SQLite/PG schema、迁移脚本、测试库是否漂移 | 漂移矩阵 |
| 安全 | 密钥、许可证、支付、插件、路径、日志、序列化是否 fail-closed | 安全缺陷清单 |
| 可维护性 | 大文件、重复类型、命名、编码、W1057、未用代码 | 整理任务清单 |
| 下游体验 | 文档、示例、快速接入、模板工程是否可靠 | 接入缺口清单 |

### 1.3 全局评分模板

每轮总评输出如下格式：

| 维度 | 分数 | 状态 | 主要问题 |
|------|------|------|----------|
| 架构分层 | /10 | 待评估 | |
| 编译与测试 | /10 | 待评估 | |
| 安全边界 | /10 | 待评估 | |
| 并发与生命周期 | /10 | 待评估 | |
| DB 与迁移 | /10 | 待评估 | |
| API 与下游体验 | /10 | 待评估 | |
| 文档与示例 | /10 | 待评估 | |
| 综合 | /10 | 待评估 | |

### 1.4 全局 P0 判断标准

出现以下任一项，先停下做 P0 修复：

- 主测试工程或主包无法编译。
- Unit/Integration/Architecture 门禁不能可信运行。
- Core 直接依赖 UI、FireDAC、Features 或不该依赖的 Manager。
- 支付、许可证、密钥、插件、路径处理存在 fail-open 行为。
- 后台线程或异步回调在 shutdown 后仍可能访问已释放对象。
- DB/schema 漂移导致已有数据或测试库不可迁移。
- 示例和文档引导下游走错误接入路径。

---

## 2. 分板块评估

分板块评估的目标是把库拆成可治理的工作单元。每个板块都输出评分、风险、修复任务、验证命令。

### 2.1 板块顺序

| 顺序 | 板块 | 范围 | 当前策略 |
|------|------|------|----------|
| 1 | Core 基础内核 | Manager、IoC、EventBus、Config、i18n、Logging、RuntimeContext、Exception、StateMachine、Template、Expression 等 | 最先评估和修复 |
| 2 | Services 与运行期注册 | `DeepBase.Services.*`、Runtime components、HealthCheck、Protection facade | 跟随 Core |
| 3 | Persistence / DB | DB.Factory、ConnectionPool、Pool、Migrations、DoQry、SQLLogger、FireDAC adapters | 优先修 schema 和迁移漂移 |
| 4 | Security / Auth / License | Security、DPAPI、KeyManager、Authorization、License、AntiTamper、Protection | 优先保证 fail-closed |
| 5 | Commerce / DB4 客户端 | SafeClient、PaymentBridge、Permissions、UpgradeFlow、Backend contract | 聚焦后端边界和许可证快照 |
| 6 | LLM | LLM facade、Client、Config、HTTP、Service、PromptTemplate、Billing | 保证五槽位和下游可用 |
| 7 | 通用 Features | Updater、AutoUpdate、CloudBackup、CloudSync、HttpServer、Net.Transport、Graph、Compression 等 | 按门禁失败排序 |
| 8 | Speech | Speech Core/ASR/TTS/Wake/Voice/Runtime/Policy | 在通用 Features 后评估 |
| 9 | UI 适配 | VCL、FMX、控件包、设计时包、主题、窗体状态、热键、托盘普通能力 | DeepShell 之外先做 |
| 10 | Tools / Examples / Docs | Studio、Tray、CLI、WebService、示例工程、对外文档 | 用作下游体验验收 |
| 11 | Governance | Governance runtime、route/evidence store、AI steering、ActionGrid | 在主体稳定后评估 |
| 12 | DeepShell | `VCL\DeepBase.VCL.DeepShell.*`、Demo、桌面壳文档 | 放最后 |
| 13 | BrowserAutomation | `Features\DeepBase.Browser*`、browser tests、CDP/WebView2 | 放最后 |
| 14 | IntentClarification | `Features\DeepBase.IntentClarification*`、IC tests、IC docs | 放最后 |

### 2.2 每个板块统一评估模板

```text
板块:
范围:
当前状态:
评分:
P0:
P1:
P2:
公开 API 风险:
包边界风险:
并发/生命周期风险:
安全风险:
DB/schema 风险:
测试覆盖:
验证命令:
下一步:
```

### 2.3 板块验收定义

一个板块只有同时满足以下条件，才标记为“已校准”：

- 包文件包含正确单元，且不混入测试、设计时或不该进入运行时的单元。
- 对应测试能被主 runner 引用，不是孤立测试文件。
- 至少有 targeted regression，可在 1 到 5 分钟内重跑。
- 公开 API 文档或示例不误导下游。
- P0/P1 风险清零或有明确延期理由。
- 修复后全局门禁没有退化。

---

## 3. 第一轮执行计划

### M0: 建立真实基线

- [ ] 保存当前失败日志。
- [ ] 重跑编译、Unit、Integration、Architecture、Examples。
- [ ] 对比 `tasks.md`、`bugfix.md`、`TestResults/*.xml`，标记哪些结果已过期。
- [ ] 建立 `P0-Failures` 清单。

产出：

- 当前质量总览。
- 当前阻塞清单。
- 可以立刻修复的问题排序。

### M1: 恢复编译与测试可信度

- [ ] 修复主测试工程编译阻塞。
- [ ] 修复 0 tests、过滤误报、旧 XML 误导问题。
- [ ] 确认 `-CI` 模式不能跳过编译。
- [ ] 清理或标记未接入 runner 的测试单元。

产出：

- Unit/Integration/Architecture 可以真实失败或真实通过。
- 门禁失败原因可定位。

### M2: 全局架构评估报告

- [ ] 包边界扫描。
- [ ] Core 依赖扫描。
- [ ] 生命周期扫描。
- [ ] schema/migration 漂移扫描。
- [ ] 安全 fail-closed 扫描。
- [ ] 编译警告与编码问题扫描。

产出：

- 全局评分。
- P0/P1/P2 优化任务。
- 建议进入长期治理的架构项。

### M3: 基础核心板块修复

优先级：

1. Core 基础内核。
2. Services 与 RuntimeContext。
3. Persistence / DB。
4. Security / Auth / License。
5. Commerce / DB4 客户端。

产出：

- 关键公共能力稳定。
- 下游接入不被基础层问题拖累。

### M4: 通用能力与 UI 普通适配

优先级：

1. LLM。
2. Updater / Cloud / HttpServer / Net / Graph。
3. Speech。
4. VCL/FMX 普通控件与适配层。
5. Tools / Examples / Docs。
6. Governance。

产出：

- 常用功能可以作为公共库交付。
- 示例和文档可作为验收材料。

### M5: 最后三个优化中板块

按以下顺序处理：

1. DeepShell。
2. BrowserAutomation。
3. IntentClarification。

原因：

- 三者仍在持续优化，早期评估容易和正在进行的重构互相干扰。
- 它们依赖 Core、Runtime、VCL/Features 的稳定边界。
- 放到最后可以用已经校准好的基础设施反向约束它们。

产出：

- 三个板块独立质量报告。
- 独立 targeted tests。
- 是否纳入默认发布包的结论。

---

## 4. 质量任务池

### 4.1 P0 阻塞

- [ ] 恢复当前主编译链。
- [ ] 恢复完整 Unit 可信运行。
- [ ] 恢复 Integration 可信运行。
- [ ] 恢复 Architecture checks 可信运行。
- [ ] 阻止旧 XML 被误用为当前结论。

### 4.2 P1 架构治理

- [ ] 校准包 DAG，避免运行时包混入设计时、测试、可选实验模块。
- [ ] 统一 RuntimeContext 生命周期协议。
- [ ] 审计 Manager 是否继续过重，决定是否进一步拆分。
- [ ] 审计 Services 注册是否保持 side-effect free。
- [ ] 审计 Core facade 与 Features 实现的边界。

### 4.3 P1 安全治理

- [ ] License 客户端只验证可信快照，不承担生产签发职责。
- [ ] PaymentBridge 继续保持未验签不成功。
- [ ] 插件路径、配置命名空间和 sandbox 行为 fail-closed。
- [ ] Secret、KeyManager、DPAPI、UBS2 格式保持可迁移诊断。
- [ ] 日志输出默认脱敏，避免 token、key、path PII 泄漏。

### 4.4 P1 DB/schema 治理

- [ ] 对齐 `Core/DeepBase.Schema.pas`、`data/create_sample_db.sql`、`sql/*.sql`。
- [ ] 迁移脚本 parser 不误拆 trigger/procedure。
- [ ] migration checksum mismatch 有明确诊断。
- [ ] DB3/DB4 边界继续保持：客户端不直连 DB4。

### 4.5 P1 测试治理

- [ ] 每个活跃模块至少有 targeted regression。
- [ ] 清理未注册 fixture 和未被 DPR 引用的测试。
- [ ] 对安全、并发、迁移类 bug 保留 regression。
- [ ] 性能和压力测试不阻塞普通 CI，但要有独立入口。

### 4.6 P2 可维护性治理

- [ ] 清理 W1057 隐式字符串转换。
- [ ] 对 Delphi `.pas/.dfm/.fmx/.dpr` 源码做 UTF-8 BOM 审计，必要时用 DeepCharset 转换。
- [ ] 清理未使用变量、无效占位代码、重复类型。
- [ ] 对过大单元做风险评估，避免无收益拆分。
- [ ] 文档入口统一，避免下游 AI 读到过期接入方案。

---

## 5. 记录格式

后续每次完成一个板块，在本文件追加如下记录：

```text
## YYYY-MM-DD 板块名 校准记录

范围:
发现:
修复:
测试:
残留风险:
状态:
```

---

## 6. 当前执行状态

| 项目 | 状态 | 备注 |
|------|------|------|
| 总控计划 | 已建立 | 本文件 |
| 真实基线 | 待执行 | 需要重跑门禁 |
| 全部架构评估 | 待执行 | 基线后开始 |
| 分板块评估 | 待执行 | 从 Core 开始 |
| DeepShell | 延后 | 最后三板块之一 |
| BrowserAutomation | 延后 | 最后三板块之一 |
| IntentClarification | 延后 | 最后三板块之一 |

---

## 7. 2026-05-14 第一次框架评审确认

来源：外部第一次综合评审。以下为源码核验后的确认状态，后续修复按 P0 -> P1 -> P2 和板块顺序推进。

### 7.1 评审结论接收口径

- 总体判断“架构成熟、分层较清晰、测试和安全意识较强”基本成立。
- 数字口径需要以当前仓库为准：当前根目录 `.dpk` 为 15 个；统计到 Core/Persistence/Features/VCL/FMX/ThirdParty/Governance/Tools/Tests/DeepFlow 的 `.pas` 为 587 个；`Tests` 下 `.pas` 为 170 个。
- “DeepShell、BrowserAutomation、IntentClarification”继续按本计划放最后，除非阻塞主编译链。

### 7.2 P0 已确认问题

| 编号 | 问题 | 确认状态 | 证据 | 后续处理板块 |
|------|------|----------|------|--------------|
| FR-001 | 版本号混乱 | Confirmed | `Core/DeepBase.Manager.pas` 与 `Core/DeepBase.PluginManager.pas` 为 `0.3`；`Core/DeepBase.Consts.pas` 为 `1.0.2`；`Core/DeepBase.Schema.pas` 为 `1.0.0` | Core |
| FR-002 | CloudBackup/CloudSync/LLM.Config 弱加密或硬编码 key | Confirmed | `Features/DeepBase.CloudBackup.pas` 使用 XOR；`Features/DeepBase.CloudSync.pas` 用 Base64 模拟加密；`Features/DeepBase.LLM.Config.pas` 使用 `@DeepBase.LLM.Key` | Security + Features + LLM |
| FR-003 | `Authorization.FireDAC.ReplaceRolePermissions` 无事务 | Confirmed | `Persistence/DeepBase.Persistence.Authorization.FireDAC.pas` 先 DELETE 后循环 INSERT，无 `StartTransaction/Commit/Rollback` | Persistence + Auth |
| FR-004 | `Logging.FireDAC` lazy init 线程不安全 | Confirmed | `EnsureConnection/EnsureInsertQuery/EnsureLegacyInsertQuery` 直接 `if Assigned then Exit`，无锁保护 | Persistence + Logging |

### 7.3 P1 已确认或部分确认问题

| 编号 | 问题 | 确认状态 | 证据/说明 | 后续处理板块 |
|------|------|----------|-----------|--------------|
| FR-005 | `DeepBaseFeatures.dpk` 过大 | Confirmed | 当前包含 78 个 source entries，混有 LLM、IC、Browser、Commerce、Speech、Cloud、Graph、HttpServer | Package DAG |
| FR-006 | `TDBConnectionFactory` connection-per-call | Confirmed | `CreateConnectionFromProfile` 临时创建 `TUniConnectionPool`，只调用 `CreateUnopenedConnection` 后释放 pool | Persistence / DB |
| FR-007 | UPSERT 写法不统一 | Confirmed | `INSERT OR REPLACE`、`ON CONFLICT`、手写 UPDATE/INSERT 分散在 Core/Persistence/Features | Persistence / DB |
| FR-008 | DoQry 预编译池原始连接指针 key 风险 | Partial | 当前确实用 `NativeInt(Conn)` 作为 key；源码已加入 stale entry 清理注释和判断，但仍依赖指针身份，需要专项压力测试验证 | Persistence / DoQry |
| FR-009 | LLM 流式传输不是真流式 | Confirmed | `Features/DeepBase.LLM.HTTP.pas` 注释明确 transport 返回完整 body 后再解析 SSE lines | LLM |

### 7.4 P2 已确认问题

| 编号 | 问题 | 确认状态 | 证据/说明 | 后续处理板块 |
|------|------|----------|-----------|--------------|
| FR-010 | MFCC 使用 O(N^2) DFT | Confirmed | `Features/DeepBase.Speech.MFCC.pas` 注释为 simplified DFT，production would use radix-2 FFT | Speech |
| FR-011 | 注释编码损坏 | Confirmed | 多个 `.pas/.md` 中出现 `锟斤拷`、乱码中文注释；按 `charset` 流程先审计再转换 | Cross-cutting |
| FR-012 | deprecated config encrypted 接口仍在接口内 | Confirmed | `Core/DeepBase.Interfaces.pas` 和 `Core/DeepBase.Config.pas` 中仍声明，运行时抛 `ENotSupportedException` | Core API |
| FR-013 | `CompareVersions` 重复实现 | Confirmed | `Core/DeepBase.Types.pas`、`Core/DeepBase.Plugin.pas`、`Core/DeepBase.LLM.Manager.pas` 均有版本比较逻辑 | Core |
| FR-014 | 日志 sanitizer 破坏合法内容 | Confirmed | `Core/DeepBase.Logging.pas` 将 `\` 替换为 `/`，`< >` 替换为 `?`，`&` 替换为 `and` | Core Logging |
| FR-015 | DoQry 全局可变状态 | Confirmed | `GQueryCache/GPreparedPool/GPreparedPoolLock/GPreparedPoolEnabled` 等均为单元全局变量 | Persistence / DoQry |
| FR-016 | DeepFlow Pause/Resume 空桩，优先队列插入排序 | Confirmed | `DeepFlow.Engine.Pause/Resume` 为空实现；`InsertSorted` 线性扫描插入 | DeepFlow |
| FR-017 | `.editorconfig` 标题仍是 UniBase | Confirmed | 第一行 `# UniBase Delphi Framework EditorConfig` | Repo hygiene |

### 7.5 需要专项复核的问题

| 问题 | 当前判断 | 复核方式 |
|------|----------|----------|
| “17 个包” | 当前根目录 `.dpk` 统计为 15 个，评审数字可能包含历史/设计外工程 | 后续以包 DAG 清单重新建账 |
| “Features 93 个单元无对应测试” | `Features` 当前为 92 个 `.pas`；测试覆盖映射需要按 unit -> active DPR fixture 专项生成 | 建立 Features 测试覆盖矩阵 |
| “Core 完全不依赖 FireDAC/VCL/FMX” | 旧架构测试曾通过，但当前工作区变化较多，不能沿用旧 XML | 重跑 `Scripts/run_architecture_checks.ps1` |

### 7.6 后续执行顺序调整

第一次评审确认后，前两轮修复顺序调整为：

1. Core P0：统一版本源，修复 logger sanitizer 策略，整理 CompareVersions 归属。
2. Security/Features P0：替换 CloudBackup、CloudSync、LLM.Config 弱加密路径。
3. Persistence P0：为 Authorization role permission replacement 加事务；为 Logging.FireDAC lazy init 加锁。
4. Persistence P1：评估 DB factory 与 pool 的真实契约，补 DoQry prepared pool 压力测试。
5. LLM P1：拆出真 SSE streaming transport 或明确 API 命名为 buffered stream。
6. 其余 P2：编码、deprecated、DeepFlow、editorconfig、MFCC FFT。

