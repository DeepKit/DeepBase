# DeepBase 架构质量校准与优化总控计划

> 更新日期: 2026-05-15
> 用途: 作为 DeepBase 架构库后续质量评估、优化、修复和验收的推进总表。  
> 当前原则: 先建立可信基线，再做全局架构评估，再按板块逐项校准；DeepShell、浏览器自动化、意图识别三个最后板块已进入第一轮评审记录。

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
| 真实基线 | ✅ 已完成 | 18/18 构建目标全部 Win64/Debug 0 errors |
| 全部架构评估 | ✅ 已完成 | 基础模块、LLM、Cloud/Updater/Net/Graph/Math、Commerce、Speech、Governance 全部评审 |
| 基础层修复 | ✅ 已完成 | 三轮修复: BASIC-001~027 + FR-001~017 全部 P0/P1 已修复; 详见 bugfix.md BUG-181~203 |
| 架构重构 | ✅ 已完成 | Services 包拆分、Crypto 统一、Config 接口清理; 详见 .kiro/specs/services-crypto-config-refactor/ |
| DeepShell | ✅ 骨架完成 | 15 单元 + Demo + 24 测试; BUG-166~180 全修; 剩余 4 个 pending feature |
| BrowserAutomation | ✅ 编译通过 | 功能层面待评审 |
| IntentClarification | ✅ 编译通过 | 功能层面 BUG-134~142 待修复 |
| 下一阶段 | 进行中 | 周边模块 P0/P1 (LLM/Cloud/Updater/IC/Browser/Math); 见第 14 节; BUG-210~217 已修 |

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

---

## 8. 2026-05-14 基础模块分板块评审

范围：

- `DeepBaseCore.dpk`、`DeepBaseServices.dpk`、`DeepBasePersistence.dpk`。
- `Core/` 中的 Manager、RuntimeContext、IoC、EventBus、Scheduler、WorkerQueue、Logging、Config、Security/Crypto/KeyManager、Schema 等基础能力。
- `Persistence/` 中的 FireDAC adapters、DB Factory、Pool、DoQry、Migrations、SQLLogger。
- 本轮不处理 DeepShell、BrowserAutomation、IntentClarification，也不做源码修复。

### 8.1 基础模块总览

| 子板块 | 评分 | 当前判断 |
|--------|------|----------|
| Core 包边界 | 7/10 | `DeepBaseCore.dpk` 本身较克制，但 `Core/` 目录混入 UI/DB/测试辅助单元，目录边界与包边界不一致。 |
| Services / Runtime | 6.5/10 | `RuntimeContext` 抽象方向正确，但全局上下文和生命周期状态没有同步；`DeepBaseServices.dpk` 已经拉入 VCL/FireDAC/Features。 |
| Persistence / DB | 6/10 | FireDAC adapter 边界基本清楚，但 Pool、Logging adapter、Factory、Migration 存在线程安全、原子性和契约漂移风险。 |
| Security 基础能力 | 7/10 | 已有 DPAPI、AES/PBKDF2、KeyManager 等能力，但仍存在 fail-open fallback、重复 crypto primitive 和“硬件绑定”表述过强。 |
| 测试可信度 | 7/10 | 基础模块测试文件较多，且主 DPR 已引用；但缺少并发/生命周期/包 DAG 的定向压力用例。 |

### 8.2 P0 / P1 / P2 任务清单

| 编号 | 优先级 | 模块 | 证据 | 问题 | 修复建议 | 验证建议 |
|------|--------|------|------|------|----------|----------|
| BASIC-001 | P1 | Package DAG / Services | `DeepBaseServices.dpk:10-17` requires `vcl`、`dbrtl`、`FireDAC*`；`DeepBaseServices.dpk:21` 直接包含 `Features\DeepBase.Math.pas` | Services 层不再是纯 L1 服务抽象包，会把 UI/DB/Features 依赖传递给下游。 | 拆成 `DeepBaseServices` 纯接口/实现包与 `DeepBaseServices.Adapters` 或 `DeepBaseRuntime` 包；把 `Features\DeepBase.Math.pas` 移回 Features 或改由 Core services 实现。 | 增加 package DAG 测试：Services 不允许 `vcl`、`firedac`、`dbrtl`、`Features\` source entry。 |
| BASIC-002 | P1 | Core / Cross-platform | `Core/DeepBase.Random.pas:6`、`Core/DeepBase.Protection.pas:6` 无条件使用 `Winapi.Windows`；`Core/DeepBase.TrayIcon.pas:41` 在非 Windows 下仍引用 `WM_USER`/Win32 类型 | Core 对外有跨平台叙事，但多个基础单元 Windows-only，且部分 IFDEF 不完整。 | 把 Windows-only 能力移到 `Core.Win`/VCL/Platform adapter；纯 Core 保留接口与无平台实现；补非 Windows 编译门禁或静态 IFDEF 检查。 | 在架构测试中扫描 `DeepBaseCore.dpk` 与 `DeepBaseServices.dpk` 的 unguarded `Winapi.*`/Win32 symbol。 |
| BASIC-003 | P2 | Core directory hygiene | `Core/DeepBase.Export.pas` 使用 `Data.DB`/`Vcl.Grids`；`Core/DeepBase.Feedback.pas:457` 使用 `Vcl.Graphics`/`Vcl.Forms`；`Core/DeepBase.VirtualScroll.pas:28` 使用 VCL controls；`Core/DeepBase.LLM.pas:22`、`Core/DeepBase.ORM.pas:51` 使用 `Data.DB` | `Core/` 目录并不等同于 Core 包；维护者和下游 AI 容易误判依赖方向。 | 建立目录级分层：`Core` 只放真正核心，VCL-only 移到 `VCL/`，DB facade/adapter 明确拆到 `Persistence/` 或 `Core.Contracts/`。短期在文档中声明“以 dpk 为准”。 | 生成 `directory -> package -> dependency` 矩阵，避免只靠 dpk 检查。 |
| BASIC-004 | P1 | Architecture tests | `Tests/Architecture/Test.Arch.PackageBoundaries.pas:397-404` 的 Services 检查只禁止 FMX/DesignIDE，没有禁止 VCL/FireDAC；`CORE_UI_DEPENDENCY_ALLOWLIST` 包含未必在 Core 包内的历史单元 | 架构测试存在盲区，当前不能证明 Services 是干净 L1，也不能证明目录边界一致。 | 重写包边界测试为声明式 DAG：每个包允许的 requires、source roots、禁止单元前缀、平台依赖都显式列出。 | 让架构测试对 `DeepBaseServices.dpk` 的 `vcl`/`FireDAC` 依赖失败。 |
| BASIC-005 | P1 | RuntimeContext | `Core/DeepBase.RuntimeContext.pas:118` 全局 `GRuntimeContext`；`RuntimeContext()` 懒创建无锁；`RegisterComponent/Start/Stop/Shutdown` 状态读写无锁 | Runtime 生命周期协调器不是线程安全的；并发注册、启动、关闭可能出现重复创建、状态错乱或 shutdown 后注册。 | 给 `TDeepBaseRuntimeContext` 增加私有锁；全局实例用双检锁或显式 bootstrap；定义状态机转换规则和重复调用语义。 | 增加并发测试：多线程同时 `RuntimeContext`、`RegisterComponent`、`Start/Shutdown`。 |
| BASIC-006 | P1 | Scheduler lifecycle | `Core/DeepBase.Scheduler.pas:873-878` stop timer；`886-896` timer sleep；`936-1030` async task closure 持有 `TScheduledTask` 指针；`Stop` 只轮询等待运行任务最多 10 秒 | 长任务超过 stop 等待上限后，析构会释放 `FTasks`，后台 `TTask` 仍可能访问已释放 `TScheduledTask`；`FRunningCount` 读写也不完全同步。 | 建立任务句柄/引用计数；Stop 支持明确的 drain timeout 和 cancel timeout；超时后不释放仍运行任务或强制进入 fail-fast 状态。 | 增加回归：任务 sleep > 10s 后销毁 scheduler，不应 use-after-free。 |
| BASIC-007 | P1 | WorkerQueue lifecycle | `Core/DeepBase.WorkerQueue.pas:1941-1966` `Stop(True)` 立即 `Terminate/WaitFor` worker；`1982-2001` 另有 `WaitForCompletion`；`2070-2083` 动态缩容删除 worker | `Stop(True)` 名称像“等待完成”，实际是终止 worker，并不会 drain pending jobs；缩容/停止与 worker 列表、`FShuttingDown/FPaused` 状态的同步边界不清。 | API 拆成 `DrainAndStop`、`StopNow`、`Shutdown`；缩容只标记 worker 退出并在退出后回收；所有队列状态走同一锁或原子变量。 | 增加 pending/running job 场景测试：Stop/Drain/Destroy 的语义分别验证。 |
| BASIC-008 | P0 | DB Pool | `Persistence/DeepBase.DB.Pool.pas:1535-1560` 复制 idle 连接后在锁外 `Validate`；`721-730` `TPooledConnection.Release` 无锁；`1369-1380` `RecycleAllConnections` 删除所有连接；`906-929` `Shutdown` 清空 pool | idle 连接在锁外验证期间可能被另一个线程获取并并发使用同一个 `TFDConnection`；Recycle/Shutdown 可能释放 in-use connection，存在数据损坏或 use-after-free 风险。 | 引入连接 lease/ref-count；验证前在锁内把状态从 idle 改为 validating；Recycle/Shutdown 只处理 idle，active 连接进入 draining 并等待或超时失败。 | 增加压力测试：并发 acquire/release + maintenance validate + recycle/shutdown。 |
| BASIC-009 | P0 | Authorization persistence | `Persistence/DeepBase.Persistence.Authorization.FireDAC.pas:579-604` 先 DELETE 再循环 INSERT，无事务 | 中途失败会导致角色权限被清空，属于数据完整性风险。 | 用显式事务包裹 DELETE/INSERT；嵌套事务场景使用 savepoint 或由调用方事务接管。 | 增加回归：模拟第二条 permission insert 失败，原权限必须保留。 |
| BASIC-010 | P1 | Logging persistence | `Persistence/DeepBase.Persistence.Logging.FireDAC.pas:48-124` lazy init 无锁；`WriteLog` 复用同一 `FInsertQuery/FLegacyInsertQuery` 写参数 | adapter 本身不是线程安全的；即使当前 logger 写线程串行，公共 `ILogStorage` 实现仍会在并发调用下串参数或崩溃。 | 增加 adapter 内部锁，或改为每次写创建短生命周期 query；明确 `ILogStorage` 线程安全契约。 | 增加多线程直接调用 `ILogStorage.WriteLog` 的 race test。 |
| BASIC-011 | P1 | DB Factory / credentials | `Persistence/DeepBase.DB.Factory.pas:173-192` 每次创建临时 pool 只为生成连接；`324-325` Credential Manager 失败后保留明文密码 | Factory 绕过池化，且 DB3 密码迁移存在静默明文 fallback。 | Factory 只负责 profile 解析；连接获取交给命名 pool/provider；凭据保存失败应 fail-closed 或写入加密 secret store，不应静默保持明文。 | 增加测试：Credential 保存失败时不得返回成功迁移状态；GetLocal/GetShared 不应每次创建临时 pool。 |
| BASIC-012 | P1 | DB Migrations | `Persistence/DeepBase.DB.Migrations.pas:255-282` 只识别 `*.up.sqlite.sql` / `*.up.pg.sql`；当前 `sql/` 下没有匹配文件，只有 `upgrade_v0_2_to_v0_3.sql` 等历史脚本 | migration engine 的文件命名约定与现有脚本不匹配，运行时会出现“成功但 0 个迁移”的假象。 | 迁移脚本统一迁入 `migrations/` 并按 engine 约定命名，或 engine 支持 manifest/legacy alias；0 files 应可配置为 warning/failure。 | 增加测试：现有 sql 目录至少发现预期迁移；空迁移目录在 CI 中失败。 |
| BASIC-013 | P1 | Schema / version | `Core/DeepBase.Schema.pas:28` 为 `1.0.0`；`sql/tier2_init.sql:286` 写 `0.3`；`sql/upgrade_v0_2_to_v0_3.sql:246` 写 `0.3`；`Core/DeepBase.Consts.pas` 另有 `1.0.2` | schema、框架版本、升级脚本版本仍未统一，升级判断和兼容窗口会漂移。 | 建立单一版本源：framework version、schema version、migration version 分别命名但从同一清单生成；禁止 SQL 脚本手写当前版本。 | 增加版本一致性测试：Consts/Schema/SQL migration expected version。 |
| BASIC-014 | P1 | DoQry | `Persistence/DeepBase.DB.DoQry.pas:256-272` 大量全局状态；`461-584` prepared pool 以连接指针和 SQL hash 做 key | prepared statement 池依赖全局可变状态和连接指针身份，连接释放/地址复用仍有错误复用风险；多库实例隔离也不清楚。 | 把 DoQry 状态封装到 DB context/pool 实例；prepared cache 绑定 connection lease lifetime，连接释放时强制清理。 | 增加连接销毁后地址复用/多数据库并发测试。 |
| BASIC-015 | P1 | Crypto / Random | `Core/DeepBase.Crypto.pas:884-900` 非 Windows `/dev/urandom` 失败后 fallback 到 Delphi `Random` | 安全随机数不应 fail-open；fallback 只在 DEBUG 输出警告，生产环境会静默降级。 | `/dev/urandom` 或平台 CSPRNG 失败时直接抛安全异常；需要测试模式时显式注入 deterministic RNG。 | 增加测试/静态检查：生产代码不得从 CSPRNG 降级到 `Random()`。 |
| BASIC-016 | P1 | Crypto primitive duplication | `Core/DeepBase.Random.pas` 自己声明 CryptoAPI；`Core/DeepBase.Protection.pas` 自己声明 CryptoAPI/CNG；`Core/DeepBase.Crypto.pas` 也实现 BCrypt/AES/PBKDF2 | 基础安全能力重复实现，修复和审计会分裂；也增加 Windows-only API 泄漏。 | 统一安全 primitive 到 `DeepBase.Crypto` + `DeepBase.Security.*`，其他单元只依赖接口或 wrapper；旧 API 标记 deprecated。 | 增加依赖检查：除平台 adapter 外禁止直接 external `advapi32.dll`/`bcrypt.dll`。 |
| BASIC-017 | P2 | KeyManager | `Core/DeepBase.KeyManager.pas:314-337` “硬件指纹”主要来自环境变量和计算机名，注释也写着 production 需补 WMI | 文档声称 hardware-bound，但当前实现更接近 machine/user affinity，安全语义被夸大。 | 调整命名和文档，或实现真正平台硬件 ID adapter；允许可迁移恢复策略，不把弱指纹当强安全边界。 | 增加文档/测试：指纹字段为空或变化时行为可预测。 |

### 8.3 本轮基础模块结论

- 基础层的主要问题不是“没有抽象”，而是抽象和包边界没有完全对齐：Services 包、Core 目录、Core 包三者的含义不同。
- 运行期生命周期已经有统一入口，但线程安全、停止语义、长任务释放语义需要先校准，否则上层 Features/UI 会继承不稳定行为。
- Persistence 是当前基础层最高风险区域，优先顺序应为：DB Pool active connection 生命周期、Authorization 事务、Logging adapter 并发、Migration 命名/版本漂移、DoQry 全局状态。
- 安全基础能力总体方向正确，但必须消除 fail-open fallback 和重复 crypto primitive，避免后续 Cloud/LLM/Commerce 各自绕开统一安全层。

### 8.4 下一步评审顺序

1. 基础层第一轮已覆盖 Core/Services/Runtime/Persistence/Security，后续只在需要时补专项证据。
2. 下一轮进入周边通用模块：LLM、Cloud/Updater/Net/Graph、Commerce、Speech、Governance。
3. 最后处理 UI：VCL/FMX 普通适配，再处理 DeepShell；BrowserAutomation 与 IntentClarification 仍按要求放最后。

### 8.5 基础核心 API 补充评审

| 编号 | 优先级 | 模块 | 证据 | 问题 | 修复建议 | 验证建议 |
|------|--------|------|------|------|----------|----------|
| BASIC-018 | P1 | Manager lifecycle | `Core/DeepBase.Manager.pas:664-709`、`720-779` 的 `InitializeEx/InitializeWithDB` 未进入 `FLock`；`Finalize` 才使用 `FLock` | 注释要求主线程调用，但类内已有锁并暴露全局 singleton；并发初始化会重复连接 DB、创建模块、设置全局 logger/i18n callback。 | 初始化入口也纳入同一生命周期锁；把 main-thread-only 作为断言或文档，不作为唯一保护。 | 增加并发调用 `InitializeWithDB(:memory:)` 的测试，模块只能创建一次。 |
| BASIC-019 | P1 | Manager migration | `Core/DeepBase.Manager.Schema.pas:425-466` 有独立 SQL splitter；`Core/DeepBase.Manager.Schema.pas:486-497` 查找 `sql/upgrade_vX_to_vY.sql`；`Persistence/DeepBase.DB.Migrations.pas:255-282` 查找 `*.up.sqlite.sql`/`*.up.pg.sql` | 同一库存在两套迁移引擎和两种命名约定；Manager 的 splitter 比 `DB.Migrations` 简化，容易误拆复杂 SQL。 | 统一到一个 migration engine；Manager 只调用 `TMigrationEngine` 或一个 migration service，不再维护第二套 parser。 | 增加测试：Manager 和 DB migration 对同一迁移目录给出相同待执行列表。 |
| BASIC-020 | P1 | Manager global callbacks | `Core/DeepBase.Manager.pas:929-933` 设置全局翻译 callback 捕获 `FI18n`；`FinalizeModules` 释放 `FI18n` 但未清空 callback | Manager finalize 后，`T()` 仍可能调用已释放的 i18n 实例。 | `FinalizeModules` 中调用 `SetGlobalTranslateCallback(nil)` 和语言 callback cleanup；或 callback 内弱检查 manager 初始化状态。 | 增加回归：Initialize -> Finalize -> 调用 `T('OK')` 不应访问已释放对象。 |
| BASIC-021 | P1 | EventBus async/drain | `Core/DeepBase.EventBus.pas:861-884` 只跟踪 `edmAsync` anonymous thread；`924-936` `PublishAsync<T>` 使用 `TTask.Run` 但不进入 `FAsyncCount`；`WaitForAsyncHandlers` 只看 `FAsyncDrained` | `WaitForAsyncHandlers` 不能等待 `PublishAsync<T>`，Runtime shutdown 可能误判事件已 drain。 | 所有异步入口统一通过同一个 tracker；`PublishAsync` 返回的 task 也登记到 pending set 或改名为 fire-and-forget。 | 增加测试：`PublishAsync` 中 handler 阻塞时，`WaitForAsyncHandlers` 必须等待或超时。 |
| BASIC-022 | P1 | EventBus stats/thread safety | `Core/DeepBase.EventBus.pas:946-995` 在锁外更新 `FStats.TotalPublished/Delivered/Filtered/Errors`；`Enabled` 属性直接读写 | EventBus 声称线程安全，但统计和 enabled 状态存在数据竞争，多线程 publish 下统计不可信。 | 统计改用 `TInterlocked` 或统一锁；`Enabled` 用锁/原子封装。 | 增加多线程 publish 统计一致性测试。 |
| BASIC-023 | P2 | EventBus subscription lifetime | `TSubscription` 保存 `FEventBus: TObject`；`TEventBus.Destroy` 只 detach weak links，不会让外部强 subscription token 失效 | 外部持有的 `ISubscription` 在 EventBus 已销毁后调用 `Unsubscribe`，存在悬空指针风险。 | token 持有可失效的 shared state，而不是裸对象指针；EventBus 销毁时标记所有 token inactive。 | 增加测试：销毁 EventBus 后调用旧 token.Unsubscribe 不崩溃。 |
| BASIC-024 | P1 | IoC concurrency | `Core/DeepBase.IoC.pas:785-799` `FResolving` 是容器全局字典，不区分线程；`ResolveInternal/ResolveInterfaceInternal` 使用它判断循环依赖 | 两个线程同时解析同一服务时，第二个线程可能被误判为 circular dependency。 | 把 resolving stack 改成线程局部或 resolve call context；循环依赖只在同一解析链内判断。 | 增加并发测试：多个线程同时 resolve 同一 transient/singleton 不应抛 circular dependency。 |
| BASIC-025 | P1 | IoC mutation vs resolve | `FindRegistration` 在锁内取出 registration 指针后释放锁；`Clear` 可同时清空并释放 registration；`ResolveInternal` 后续继续使用 Reg | “注册和解析线程安全”的声明不完整；并发 Clear/Register 与 Resolve 可能 use-after-free 或行为漂移。 | 明确冻结期：启动后禁止 mutation；或用读写锁/registration snapshot/reference counting。 | 增加并发测试：resolve 压力下 Clear/Register 应被禁止或安全失败。 |
| BASIC-026 | P2 | Config API contract | `Core/DeepBase.Interfaces.pas:63-65` 仍保留 `GetConfigEncrypted/SetConfigEncrypted`；`Core/DeepBase.Config.pas:262-276` 运行时直接抛 `ENotSupportedException` | deprecated API 仍在核心接口中，导致实现者必须保留一个必抛方法，接口语义不干净。 | 下一个 breaking 版本从 `IDeepBaseConfig` 移除；当前版本新增 `ISecretStore`/`ISecuritySecretStorage` 明确替代路径。 | API compatibility test 标记 deprecated removal plan；文档禁止新代码调用。 |
| BASIC-027 | P2 | Config callback lock scope | `Core/DeepBase.Config.pas:300-317` 在持有 `FLock` 时执行 `FOnConfigChanged` | 配置变更回调如果执行慢逻辑或反向调用其他模块，会扩大锁范围并增加死锁/卡顿风险。 | 在锁内只完成写入和缓存更新，复制事件参数后锁外触发 callback。 | 增加回调重入/慢回调测试，确认不会阻塞读配置。 |

### 8.6 基础模块下一步修复优先级建议

已完成项 (2026-05-14 本轮修复):
- ✅ BASIC-005, 009, 010, 011, 015, 018, 020, 021, 022, 024, 027
- ✅ FR-001, 002, 013, 014, 017

已完成项 (2026-05-15 第二轮修复):
- ✅ BASIC-008: DB Pool active connection 生命周期 — Release 加锁、ValidateIdleConnections 先转 csValidating、RecycleAllConnections 只回收 idle、Shutdown 增加 drain 等待
- ✅ BASIC-004: 架构测试增加 Services 包 VCL/FireDAC/dbrtl 违规追踪测试和 Features 目录禁入检查
- ✅ BASIC-025: IoC 容器增加 Freeze 机制 — 首次 Resolve 自动冻结，冻结后 Register/Clear 抛异常，消除并发 mutation vs resolve 的 use-after-free 风险；新增 3 个回归测试
- ✅ BASIC-006: Scheduler 生命周期 — Stop 改为返回 Boolean 支持 drain timeout 配置（默认 30s，-1 = 无限），TimerProc 用 ShutdownEvent.WaitFor 响应停止信号；析构器强制无限等待防止 use-after-free
- ✅ BASIC-007: WorkerQueue 生命周期 — 新增 DrainAndStop 方法明确 drain pending jobs 语义，并在 Stop 注释中明确 AWaitForCompletion 不会 drain 待处理任务
- ✅ BASIC-023: EventBus subscription lifetime — TEventBus 跟踪所有 live TSubscription，Destroy 时 InvalidateBus 把 FEventBus 置 nil；TSubscription 析构器自动从 tracker 移除；外部 ISubscription 在 EventBus 销毁后调用 Unsubscribe 不再悬空指针；新增 2 个回归测试
- ✅ BASIC-014/FR-008: DoQry 预编译池连接生命周期 — 新增 UniDbSweepConnectionFromPool 函数；DB.Pool 的 TPooledConnection.Destroy 在释放连接前调用 sweep，防止 TFDConnection 地址重用导致 stale prepared statements 指向已释放连接
- ✅ BASIC-012: Migration 命名约定漂移 — DB.Migrations.FindMigrationFiles 同时识别 *.up.sqlite.sql/*.up.pg.sql (新规范) 和 upgrade_vX_Y_to_vA_B.sql (历史规范)，避免 0 migrations 假成功；ExtractVersion 从历史命名提取 "to" 版本
- ✅ BASIC-017: KeyManager 文档诚实化 — 文件头和 Collect 注释明确说明当前是 machine-affinity fingerprint 而非真正硬件指纹；production 硬件绑定需要平台 adapter (WMI/IOKit/udev)；旧代码 BIOS-/DISK- placeholder 标记为占位符
- ✅ BASIC-019 (部分): Manager 迁移 SQL 拆分统一 — 新建 `Core/DeepBase.SQL.Splitter.pas` 共享拆分器，处理 dollar-quoted、行/块注释、转义引号、CREATE TRIGGER..END 触发器体；Manager.Schema.SplitSQLStatements 和 RunMigrationScript 都改为委托给共享拆分器；DB.Migrations 保留独立实现避免回归（下轮可统一）

仍需架构重构: ✅ 全部完成 (BASIC-001/016/026)。详见 bugfix.md BUG-201~203。

---

## 14. 下一阶段待办

基础层 P0/P1 全部清零。以下为后续推进方向：

### 14.1 周边模块 P0/P1 修复

| 编号 | 优先级 | 模块 | 问题 |
|------|--------|------|------|
| LLM-001 | P0 | LLM Schema | 两套 prompt/schema 模型并存,Manager 假设手工执行了另一套 SQL |
| LLM-002 | P0 | LLM Secrets | 非 Windows fail-closed 返回空需要跨平台 secret store |
| EDGE-002 | P1 | CloudBackup | ✅ 已修复 — VerifyBackup 逐 entry SHA256 校验 + manifest 双向匹配 |
| EDGE-003 | P1 | Cloud async | ✅ 已修复 — CancelSync 改为 Terminate+WaitFor+Free; 移除 FreeOnTerminate |
| EDGE-006 | P1 | Updater trust | ✅ 已修复 — SignatureRequired 默认 fail-closed; 缺公钥/hash 时拒绝 |
| EDGE-007 | P1 | Updater install | ✅ 已修复 — 逐 entry 路径验证 + 复制时 canonical path 检查 |
| LLM-004 | P1 | Provider routing | ✅ 已修复 — 按 model 前缀匹配 provider + Priority 排序 |
| LLM-005 | P1 | Anthropic adapter | ✅ 已修复 — text request 根据 apiFormat 选择 /messages endpoint |
| LLM-006 | P1 | Streaming | 三套入口都是 buffered replay,不是真流式 |
| LLM-008 | P1 | LLM singleton | ✅ 已修复 — GLLMLock 双检锁保护 singleton 创建和 proxy 状态 |

### 14.2 P2 可维护性治理

| 编号 | 模块 | 问题 |
|------|------|------|
| FR-011 | Cross-cutting | 注释编码损坏 (锟斤拷/乱码) |
| FR-016 | DeepFlow | Pause/Resume 空桩,优先队列插入排序 |
| BASIC-019 剩余 | Persistence | DB.Migrations 切换到共享 SQL Splitter |
| SPEECH-001~020 | Speech | 包边界/接口/线程安全/COM 生命周期 |
| GOV-001~018 | Governance | 包边界/schema/runtime/evidence/AI steering |

### 14.3 最后三个板块功能评审

1. DeepShell — 剩余 4 个 pending feature (tasks.md)
2. BrowserAutomation — 功能层面评审
3. IntentClarification — BUG-134~142 功能修复

## 9. 2026-05-14 周边模块第一轮：LLM 分板块评审

范围：

- 非 UI LLM 能力：`Core/DeepBase.LLM*.pas`、`Features/DeepBase.LLM.*.pas`、`Persistence/DeepBase.Persistence.LLM.FireDAC.pas`、LLM SQL/迁移脚本、LLM 单元测试。
- 本轮明确排除：`VCL/DeepBase.VCL.LLM*`、`FMX/DeepBase.FMX.LLM*`、`Tools/Studio/Frames/Studio.LLMFrame*` 等 UI；`IntentClarification.*` 与 `Browser.*` 继续放最后。
- 本轮只评审和记录建议，不修复源码。

### 9.1 LLM 模块总览

| 子板块 | 评分 | 当前判断 |
|--------|------|----------|
| 包边界 | 5.5/10 | `DeepBaseFeatures.dpk` 同时包含 Features LLM、Core LLM、Persistence adapter，并与 Intent/Browser/Commerce 混包，模块边界不清。 |
| Provider / 协议适配 | 5/10 | OpenAI 兼容路径可测，但 Anthropic、Ollama、vision stream、provider/model 绑定存在明显断裂。 |
| 流式能力 | 4/10 | 三套入口都不是严格真流式，部分代码注释已承认 buffered stream。 |
| 密钥与配置安全 | 5.5/10 | Core 路径已引入 Credential Manager，但 Features 配置仍用硬编码 key；非 Windows 仍有明文 fallback。 |
| Prompt / Schema | 4.5/10 | `LLMPrompts`、`LLMPromptTemplates`、`Prompts/PromptVersions` 三套模型并存，`LLMCalls` 字段也存在两代结构。 |
| 测试可信度 | 6/10 | 有配置、凭据、基础 HTTP adapter 测试；缺 Anthropic、流式、provider routing、schema 兼容、并发测试。 |

### 9.2 P0 / P1 / P2 任务清单

| 编号 | 优先级 | 模块 | 证据 | 问题 | 修复建议 | 验证建议 |
|------|--------|------|------|------|----------|----------|
| LLM-001 | P0 | Schema / Prompt 管理 | `Core/DeepBase.Schema.pas:461-596` 创建 `LLMConfig/LLMCalls/LLMPrompts/LLMApiKeys`；`sql/llm_prompts_init.sql:10-149` 创建 `PromptCategories/Prompts/PromptVersions/PromptMeta/PromptMetaBinding/LLMConfig`；`Core/DeepBase.LLM.Manager.pas:753/789/868/911` 直接查询 prompt-manager 表；`Core/DeepBase.LLM.Manager.pas:1085-1108` 写旧版 `LLMCalls` 字段 | LLM 存在至少两套 prompt/schema 模型。用 Core schema 初始化的库不包含 `Prompts/PromptVersions`，而 prompt manager 依赖这些表；`LLMCalls` 也有 canonical 字段和 prompt-manager 字段两套写法。 | 明确唯一 canonical LLM schema：配置、调用记录、prompt 模板、版本管理各自只有一个表模型；旧表只走 migration/compat adapter。`TLLMManager` 不应直接假设另一套 SQL 文件已手工执行。 | 增加 schema compatibility 测试：仅执行 `DeepBase.Schema` tier2 后创建 `TLLMManager.Initialize/Execute`，不得缺表/缺列；再测试旧库迁移到 canonical schema。 |
| LLM-002 | P0 | Secrets / Config | `Features/DeepBase.LLM.Config.pas:72-85` 使用 `TSimpleCrypto.Encrypt/Decrypt(..., '@DeepBase.LLM.Key')`；`Core/DeepBase.LLM.pas:732-741` 非 Windows 保存 API key 时 fallback 为原值 | Features 配置的 API key 加密是静态硬编码密钥；Core 的 Credential Manager 方案是 Windows 优先，非 Windows 会落回明文存储，和跨平台框架目标冲突。 | LLM 密钥统一走 `ISecretStore` 或 `DeepBase.Security` 抽象：Windows Credential Manager、macOS Keychain、Linux Secret Service/libsecret/可配置 KMS；没有安全后端时 fail-closed 或要求显式 insecure dev mode。移除 `TLLMConfigStore` 自带 crypto。 | 增加测试：保存 API key 后 DB/DeepBase.Config 不出现明文或可静态解密密文；非 Windows secret backend 缺失时返回明确错误。 |
| LLM-003 | P1 | Package DAG | `DeepBaseFeatures.dpk:48-54` 包含 LLM Features；`DeepBaseFeatures.dpk:98-101` 又包含 `Core\DeepBase.LLM.Manager.pas`、`Persistence\DeepBase.Persistence.LLM.FireDAC.pas`、Billing/ImportExport | Features 包直接装入 Core 与 Persistence 源文件，导致包边界和目录边界反向耦合；LLM 不能作为独立周边模块演进。 | 拆出 `DeepBaseLLM` 或 `DeepBaseLLMCore/DeepBaseLLMPersistence` 包：公共类型/接口、HTTP provider adapter、prompt manager、FireDAC adapter 分层；Features 包只引用 LLM 包或只保留 facade。 | 增加 dpk 规则：Features 包不得包含 `Core\DeepBase.LLM.*` 和 `Persistence\DeepBase.Persistence.LLM.*` source entry。 |
| LLM-004 | P1 | Provider routing | `Features/DeepBase.LLM.Types.pas` 的 `TProviderConfig` 只有 Name/Endpoint/ApiFormat/Priority；`Features/DeepBase.LLM.Service.pas:221-241` `FindProviderForModel` 忽略 `AModelId` 和 `Priority`，只取第一个有 key/provider 的 endpoint | tier 中的 model id 没有绑定 provider，`gpt-*`、`claude-*`、`ollama` 模型都可能被发到第一个 provider；Priority 字段没有实际排序语义。 | 配置结构改为 provider -> models/capabilities，tier 存 provider+model 或 model registry id；路由时校验 provider 支持该 model、vision/stream/image 能力、priority、health。 | 增加测试：两个 provider 同时配置时，`claude-*` 必须路由到 Anthropic，`gpt-*` 路由到 OpenAI；priority 和 fallback 顺序可预测。 |
| LLM-005 | P1 | Anthropic adapter | `Features/DeepBase.LLM.HTTP.pas:379-386` 对 Anthropic text request 仍 POST `AEndpoint + '/chat/completions'`；同文件 `431-437` vision 分支才切到 `messages`；`327-349` Anthropic headers 同时可能带 Bearer 和 `x-api-key` | Anthropic 文本聊天路径和 header 策略不一致，可能直接调用错误 endpoint；不同方法对 Anthropic endpoint 拼接规则不同。 | Provider adapter 抽象出 endpoint path、auth header、request/response parser；Anthropic text/vision/stream 统一走 `/messages`，不混入 OpenAI Bearer header。 | 增加 Anthropic fake transport 测试：text、vision、stream 三种调用都验证 URL、headers、body。 |
| LLM-006 | P1 | Streaming | `Features/DeepBase.Net.Transport.pas` 将 `Response.ContentStream` 复制到内存后返回完整 body；`Features/DeepBase.LLM.HTTP.pas:601-605` 注释说明先拿完整 body 再解析 SSE；`Core/DeepBase.LLM.pas:1688-1701` `ChatStream` fallback 到普通 chat；`Core/DeepBase.LLM.BillingClient.pas:667-668` 也先 `ContentAsString` 再 split | 当前“stream”命名实际大多是 buffered response replay，无法降低首 token 延迟，也不能支持长响应实时取消。 | 在 `IDeepBaseHttpTransport` 增加 streaming API：按行/按 chunk 回调、支持 cancel token、首 token 时间；旧方法改名或文档标注为 buffered。 | 增加 fake SSE transport 测试：服务端分 3 次推送时，回调必须在响应完成前触发；记录 `FirstTokenMs`。 |
| LLM-007 | P1 | Streaming / Vision | `Features/DeepBase.LLM.HTTP.pas:563-582` Anthropic stream body 未加入 `stream: true`；`623-637` SSE parser 只解析 OpenAI `choices.delta.content`；`Features/DeepBase.LLM.Service.pas:551-568` vision stream 把图片编码成 `data:mime;base64|prompt` 文本消息 | Vision streaming 和 Anthropic streaming 不是真正协议实现，实际请求格式与 provider 规范不匹配。 | stream parser 按 provider 分离：OpenAI SSE、Anthropic event stream、Ollama NDJSON；vision stream 复用 vision request builder，不把图片塞进普通文本消息。 | 增加 OpenAI vision stream、Anthropic stream、Ollama stream 的 provider fixture；验证 body 结构和 chunk 解析。 |
| LLM-008 | P1 | Thread safety / singleton | `Features/DeepBase.LLM.Service.pas:77-82` `GLLMService/GProxyClient/GProxyChecked` 全局变量无锁；`126-158` proxy probe/cache 更新无锁；`170-178` singleton lazy create 无锁；`200-205` `EnsureLoaded` 无锁；`TLLMConfigStore` 内部 list/dictionary 也无同步 | 共享 LLM facade 在并发首次调用、proxy 探测、配置加载/保存时存在重复创建、状态竞争和 dictionary/list 并发访问风险。 | 用 runtime context/IoC 管理 LLM service 生命周期；全局 proxy cache 和 config store 加锁或改不可变 snapshot；`CallCount/LastDurationMs` 用原子/锁。 | 增加并发测试：多线程同时 `LLM.Chat/LLMAdmin.Load/AddProvider/Save`，不得重复初始化或抛 dictionary/list 异常。 |
| LLM-009 | P1 | Model discovery / TestConnection | `Features/DeepBase.LLM.HTTP.pas:662-665` `FetchModels` 直接返回空数组；`Features/DeepBase.LLM.Service.pas:641-648` `GetAvailableModels` 依赖该方法；`651-678` `TestConnection` 未传 model 时会因空模型列表失败 | 管理 UI/配置向导需要模型发现，但当前 adapter 是空桩，导致自动测试连接和模型选择不可用。 | 实现 provider-specific models endpoint：OpenAI `/models`、Anthropic 兼容策略、Ollama `/api/tags`、proxy model list；失败时返回结构化错误而不是空数组。 | 增加 fake transport 测试：模型列表 JSON -> `GetAvailableModels`；无模型/网络失败有明确错误。 |
| LLM-010 | P1 | Prompt Manager 原子性 | `Core/DeepBase.LLM.Manager.pas:1533-1551` `SetProductionVersion` 先重置所有版本再设置目标版本，无事务；`1846-1848` `Execute` 先插调用记录再更新版本统计；`1716-1736` bind meta prompt 使用 upsert/replace 后刷新 cache | prompt 版本切换、执行统计、meta 绑定属于复合写操作，中途失败会留下“无生产版本”、调用记录与统计不一致等状态。 | 在 `ILLMStorage` 增加事务能力，或让 manager 接收事务边界；生产版本切换、执行记录+统计、绑定/解绑都走事务。 | 增加回归：模拟第二条 UPDATE/INSERT 失败，原生产版本和统计必须保持一致。 |
| LLM-011 | P1 | Persistence adapter | `Persistence/DeepBase.Persistence.LLM.FireDAC.pas:51-96` 每次创建 query，参数类型从 Variant 推断；`189-202` `TableHasColumn` 用 `Format('SELECT * FROM %s ...')` 拼表名；`215-246` 初始化时注册全局 storage factory | adapter 能跑，但事务、字段类型、schema introspection 和全局工厂注册契约偏薄；表名拼接虽多为内部常量，但公共接口未限制输入。 | 扩展 `ILLMStorage`：事务、schema metadata API、safe identifier validation；全局 factory 注册改成显式 bootstrap 或 idempotent registration。 | 增加测试：非法 table/column 名拒绝；SQLite/PG 参数类型保持；多次注册 factory 行为明确。 |
| LLM-012 | P2 | Metrics / Cost | `Features/DeepBase.LLM.HTTP.pas:369-410` `Send` 没有设置 `DurationMs`；`548-660` `SendStream` 也没有 duration/first-token；`286-309` Anthropic parser 未设置 `TotalTokens`；Features `TChatResult.FinishReason` 基本未填 | 上层 `LastDurationMs`、成本估算、调用统计和 UI 调试面板会拿到 0 或不完整数据。 | HTTP adapter 统一记录 started/duration/first-token；所有 provider parser 填 `FinishReason/TotalTokens/ModelUsed/Usage`；缺失字段明确为 unknown。 | 增加 parser 测试：OpenAI/Anthropic usage、finish reason、duration 断言。 |
| LLM-013 | P2 | Timeout / Retry / Cancellation | `Core/DeepBase.LLM.pas:377` `DefaultTimeout` 只是字段直写，修改后不更新 `FHttpClient`；Features HTTP 只有构造超时，无 retry/cancel；BillingClient 的 cancel 只在完整响应 split 后检查，不能中止 HTTP POST | LLM 调用缺少统一 resiliency 契约：超时、重试、取消、退避、可重试错误分类在多套客户端中不一致。 | 定义 `TLLMRequestOptions`/cancel token/retry policy 作为公共调用参数；HTTP transport 支持 abort；所有 client 使用同一错误分类。 | 增加取消测试：请求进行中 cancel 后 transport 被中断；429/5xx 按策略重试，401 不重试。 |
| LLM-014 | P2 | Import / Export | `Core/DeepBase.LLM.ImportExport.pas:393-404` YAML parser 只是占位，非 JSON YAML 返回 error；`docs/42.api...llm-integration.md:455` 示例导出 `prompts.yaml` | 文档/API 暴露 YAML 导入导出，但实现不支持真正 YAML，容易造成备份/迁移失败。 | 要么引入可靠 YAML parser，要么在 API 层暂时禁用 YAML import 并把 docs 示例改成 JSON；导出 YAML 也需 round-trip 测试。 | 增加 JSON/YAML round-trip 测试，YAML 不支持时必须返回明确错误并不写 DB。 |
| LLM-015 | P2 | Docs / Encoding | `docs/21.architecture.LLM架构设计-llm-architecture.md` 仍描述 `LLMConfiguration`；`docs/42.api.LLM集成指南-llm-integration.md`、`sql/llm_prompts_init.sql` 有明显中文乱码 | LLM 文档和 SQL 注释已经落后于 canonical `LLMConfig/ApiKeyRef/CredMan` 路径，且编码损坏影响维护。 | 文档随 schema 统一后重写：一个快速接入、一个 schema/provider adapter 设计、一个 migration/secret 管理说明；编码按 `charset` 流程统一。 | 文档测试：示例表名、字段名、API 名称必须能在源码中匹配；编码扫描不再出现 mojibake。 |
| LLM-016 | P2 | Tests gap | 现有 `Tests/Test.DeepBase.LLM.pas` 覆盖 tier/config、基础 HTTP send、Credential Manager；未看到 Anthropic text/stream、真 SSE、provider routing、schema manager 兼容、并发 singleton 测试 | 当前测试能证明部分 adapter 可注入，但不能证明 LLM 模块可生产使用。 | 先补风险最高的 contract tests，不依赖真实外网：fake transport、fake storage、并发 harness、schema smoke。 | 新增测试矩阵：Provider x Method(Chat/Vision/Stream/Models) x Schema(New/Legacy) x Secret backend。 |

### 9.3 本轮 LLM 结论

- LLM 当前最大问题不是“功能少”，而是两条演进路线并存：`Core/DeepBase.LLM` 偏 DB/Prompt/历史调用，`Features/DeepBase.LLM.Service/HTTP/Config` 偏轻量 facade；二者配置、安全、stream、provider 路由和 schema 没有统一。
- 修复优先级应先锁定 schema 和 secret store，否则 UI、配置向导和下游接入都会踩到缺表/明文/错路由。
- 真流式需要从 transport contract 开始改；只在 `SendStream` 内解析完整 body 不能解决首 token、取消和长响应体验。
- Anthropic、Ollama、vision/image 这些非 OpenAI 兼容路径需要独立 adapter contract test，不能只靠 OpenAI-compatible happy path。

### 9.4 LLM 后续修复优先级建议

只记录建议，暂不修复。后续若进入修复阶段，建议顺序如下：

1. P0：`LLM-001` 统一 LLM schema/prompt 表模型；`LLM-002` 统一 secret store 并移除硬编码密钥/非 Windows 明文 fallback。
2. P1：`LLM-003/004/005/009` 先明确包边界、provider/model 路由、Anthropic endpoint、模型发现。
3. P1：`LLM-006/007/013` 重做 streaming/cancel/retry transport contract。
4. P1/P2：`LLM-008/010/011/012/014/015/016` 并发、事务、metrics、导入导出、文档和测试补齐。

---

## 10. 2026-05-14 周边模块第二轮：Cloud / Updater / Net / Graph / Math 分板块评审

范围：

- Cloud：`Features/DeepBase.CloudBackup.pas`、`Features/DeepBase.CloudSync.pas`。
- Updater：`Features/DeepBase.Updater.pas`、`Features/DeepBase.AutoUpdate.pas`、`Tools/UpdaterHelper/UpdaterHelper.Core.pas`。
- Net / HTTP：`Features/DeepBase.Net.Transport.pas`、`Features/DeepBase.Net.Transport.ICS.pas`、`Core/DeepBase.Net.pas`、`Features/DeepBase.HttpServer.pas`。
- Graph / Math：`Features/DeepBase.Graph.pas`、`Features/DeepBase.Math.pas`、`Core/DeepBase.Services.Math.pas`。
- 本轮继续排除：`DeepShell`、`BrowserAutomation`、`IntentClarification`，它们按用户要求放到最后。
- 本轮只评审和记录建议，不修复源码。

### 10.1 周边模块总览

| 子板块 | 评分 | 当前判断 |
|--------|------|----------|
| Cloud Backup / Sync | 5.5/10 | 功能覆盖完整，备份解压已有路径逃逸防护；但加密、完整性验证、异步生命周期仍不达生产安全线。 |
| Updater / AutoUpdate | 5/10 | 版本解析、分发策略、Helper 进程有雏形；但签名默认策略、包安装原子性、zip 安全和取消语义还不够。 |
| Net Transport | 5.5/10 | System.Net adapter 可用作基础抽象；但 proxy、streaming、binary、response limit、ICS adapter 都存在契约缺口。 |
| HttpServer | 6/10 | Router/Middleware API 简洁，适合内嵌服务；运行期配置可变、请求体无限读、空二进制响应存在风险。 |
| Graph / Math | 6/10 | 算法覆盖面广，Graph 优先队列已用 heap；但 Graph 并发快照、负权边、Math 安全随机和边界数值仍需校准。 |
| 测试可信度 | 5.5/10 | 有基础单测，但安全、生命周期、zip/path、真网络失败和大数据路径覆盖不足；`Test.DeepBase.Net` 被 `TESTDeepInsight` 条件包住。 |

### 10.2 P0 / P1 / P2 任务清单

| 编号 | 优先级 | 模块 | 证据 | 问题 | 修复建议 | 验证建议 |
|------|--------|------|------|------|----------|----------|
| EDGE-001 | P0 | Cloud encryption | `Features/DeepBase.CloudBackup.pas:1240-1326` 用 SHA-256 直接派生 key/IV，并以 XOR 加密；`Features/DeepBase.CloudSync.pas:985-1001` 用 Base64 模拟加密且忽略 `EncryptionKey` | `EnableEncryption` 给了调用者安全预期，但实际没有机密性和认证完整性；CloudSync 默认启用加密却只是编码。 | 统一走 `DeepBase.Crypto` 或 `ISecretStore` 能力：AES-256-GCM、随机 nonce、PBKDF2/Argon2 salt、auth tag、密钥轮换；不允许“加密开启但 key 空或 mock crypto”。 | 增加测试：密文不能被 Base64 还原，篡改任意 byte 解密失败；同一明文两次加密输出不同；CloudSync key 缺失应 fail closed。 |
| EDGE-002 | P1 | CloudBackup integrity | `TBackupFileInfo.Checksum` 在 `Features/DeepBase.CloudBackup.pas:74-81` 定义且生成于 `826-833/885-890/925-930`；但 `VerifyBackup` 在 `2409-2433` 只比较 `LZip.FileCount = LManifest.FileCount`；`InternalRestore` 在 `1939-1986` 未按 manifest 校验每个 entry | 备份包被替换、entry 内容被改、manifest 与 archive 不匹配时可能仍通过验证并被恢复。解压路径逃逸已在 `1158-1218` 做了防护，这里缺的是内容完整性和 manifest 可信度。 | 恢复前按 manifest 校验 entry 集合、大小、SHA256；manifest 本身做 HMAC/签名或纳入 GCM AAD；增量备份还要校验 parent 链。 | 构造“文件数量相同但内容被替换”的 zip，`VerifyBackup` 必须失败；篡改 manifest/parent chain 也必须失败。 |
| EDGE-003 | P1 | Cloud async lifecycle | CloudBackup async thread 字段在 `Features/DeepBase.CloudBackup.pas:2147-2217` 创建，`2228-2251` `Cancel` 无锁交换字段并 `WaitFor`；CloudSync `SyncAsync` 在 `1761-1772` 使用 `FreeOnTerminate=True`，`CancelSync` 在 `1775-1782` 只 `Terminate` 后置空；AutoSync timer 同样在 `2047-2067` 只 terminate 不 wait | 取消是协作式但内部大段 I/O 不检查 token；字段无锁、FreeOnTerminate 后存在悬空指针窗口；`Cancel` 可能在 UI/main thread 长时间阻塞。 | 建立统一 task/state machine：锁保护 thread/task 字段，取消 token 贯穿下载、压缩、上传、解压；停止时支持 timeout join，超时返回 pending 状态而不是无限等待。 | 增加并发测试：连续 `SyncAsync/CancelSync/Destroy`、`BackupAsync/Cancel` 不应 AV、泄漏或卡死；长 I/O 取消必须在可控时间内返回。 |
| EDGE-004 | P1 | CloudBackup API contract | `Features/DeepBase.CloudBackup.pas:2254-2257` `GetVersions` 直接返回内部 `FVersions`；`InternalBackup` 在 `1861-1875` 会向同一 list 添加并保存 | 外部调用者可直接修改/释放版本对象，且和备份线程并发读写同一 `TObjectList`，破坏 manager 不变量。 | 返回只读 snapshot 或 DTO array；所有版本查询、删除、保存都走 manager 锁；不要暴露 owning collection。 | 增加测试：调用者拿到版本列表后修改，不影响 manager 内部状态；备份进行中枚举版本不抛异常。 |
| EDGE-005 | P1 | CloudSync store contract | `TLocalConfigStore.Get` 在 `Features/DeepBase.CloudSync.pas:1293-1301` 返回内部 `TConfigItem`；`GetAll/GetDirtyItems` 在 `1360-1387` 返回非 owning list，元素仍是内部对象 | 本地配置存储有锁，但锁外暴露可变对象指针，调用者可绕过 `Put/Delete/MarkAllClean` 修改状态，也可能在 store 销毁后持有悬空引用。 | 读 API 返回 clone/snapshot；写入只能通过显式 mutation API；对性能敏感路径可引入 copy-on-write item。 | 增加测试：`GetAll` 返回对象被外部修改后，store 内部值不变；销毁 store 后旧 snapshot 仍安全。 |
| EDGE-006 | P1 | Updater trust policy | `Features/DeepBase.Updater.pas:831` `SignatureRequired` 默认 false，`937-941` 仅在 metadata 带签名时自动要求签名；`1388-1400` hash 为空直接通过；`1356-1359` RSA 公钥为空时 `VerifySignature` 返回 true；`Features/DeepBase.AutoUpdate.pas:708-719` 也只在 `Sha256` 存在时校验 | “Secure Auto-Update” 默认可以无签名、无 hash；如果 metadata 未被可信根保护，攻击者可发布无签名包或复用同源 hash 字段。 | 更新包验签改为默认强制：内置或配置 pinned public key，manifest/package hash 必填；没有 trust anchor 时只能进入显式 insecure/dev 模式。`VerifySignature` 不应在缺公钥时成功。 | 增加测试：缺签名、缺 hash、缺公钥、签名算法未知均失败；仅 dev mode 可放行且日志明确标记。 |
| EDGE-007 | P1 | Updater install safety | `Features/DeepBase.Updater.pas:1514-1536` 直接 `Zip.ExtractAll(ExtractPath)`；`1541-1558` 枚举解压目录下所有文件并复制到 `FApplicationDir`；`Info.Files.RelativePath/Hash/Action` 在 `913-919` 解析后安装阶段未用于白名单和逐文件校验 | 包内多余文件、路径逃逸 entry、单文件篡改、delete/action 语义都无法被严格约束；安装不是基于 manifest 的原子应用。 | 手写 safe unzip：逐 entry canonicalize，禁止绝对路径和父目录逃逸；只允许 manifest 中的文件；复制前校验每个文件 hash/action；以 staging 目录和 rename/replace 事务化应用。 | 增加恶意 zip 测试：`../x.exe`、绝对路径、多余文件、hash mismatch、delete action 都必须按预期拒绝或执行。 |
| EDGE-008 | P1 | UpdaterHelper safety | Helper 在 `Tools/UpdaterHelper/UpdaterHelper.Core.pas:60-75/483-487` 校验 appdir/target；但 `287-291` 仍先 `Zip.ExtractAll(ExtractDir)`，`296-303` 才检查目标路径；`510-516` hash 也是可选；`Tests/Test.Tools.UpdaterHelper.pas:58-99` 只测参数解析 | Helper 比主流程更接近安全安装，但 zip entry 写入临时目录前仍未验证；测试没有覆盖真实安装、回滚、恶意 zip。 | Helper 也改为逐 entry 安全抽取；`--sha256` 默认必填或由 signed manifest 传入；补安装/回滚/路径逃逸集成测试。 | 新增 Helper 测试：恶意 zip 不应在 temp/appdir 外创建文件；复制中途失败能回滚已写文件；缺 sha256 默认失败。 |
| EDGE-009 | P2 | Updater lifecycle / cancel | `DownloadAndInstall/DownloadOnly` 在 `Features/DeepBase.Updater.pas:1580-1715/1717-1776` 创建 fire-and-forget task；`DownloadFile` 在 `1274-1294` 等完整 `FTransport.Send` 返回后才检查 `FCancelled`；`StopSilentInstallLoop` 在 `1950-1954` 只 set event；`Cancel` 在 `2005-2008` 只写布尔值 | 上层无法等待或取消正在进行的 HTTP 下载/安装；silent loop stop 语义不保证 drain；任务生命周期和状态上报容易漂移。 | 返回 task/operation handle，提供 `CancelAndWait(timeout)`；transport 支持 cancellation token；silent loop 的 stop 分为 signal 和 wait 两步。 | 增加测试：下载阻塞时调用 cancel 必须中断 transport；stop silent loop 后 `IsSilentInstallLoopRunning` 在 timeout 内变 false。 |
| EDGE-010 | P2 | AutoUpdate duplication | `Features/DeepBase.AutoUpdate.pas:457-487/675-725` 直接创建 `THTTPClient` 拉取 version/download，未复用 `IDeepBaseHttpTransport`、签名策略、重试/取消策略；进度只在开始和完成回调 | `AutoUpdate` 和 `Updater` 形成两套更新路径，高层 helper 可能绕过更安全的 `Updater` 策略。 | `AutoUpdate` 降级为 `TUpdateManager` facade：只负责解析渠道和 UI 友好的 DTO；下载、校验、签名、安装全部委托 Updater。 | 增加 contract test：AutoUpdate 触发下载时必须走注入 transport 和同一签名校验策略。 |
| EDGE-011 | P1 | Net transport contract | `Features/DeepBase.Net.Transport.pas:17-28` 定义 `ProxyUrl`，但 `Send` 在 `133-233` 未使用；`195-213` 将完整 `ContentStream` 复制到内存并按 UTF-8 解码；`220-228` fallback 也把字符串再编码成 bytes | transport contract 暴露了 proxy/binary/streaming 语义，但实现是 buffered text-first；大响应会内存膨胀，二进制可能被错误解码，LLM/Updater 无法真实取消或流式处理。 | 明确 response model：binary 和 text 分离、可配置最大响应大小、stream/chunk API、proxy 实现或移除字段、TLS/cert policy 注入。 | 增加 transport conformance tests：proxy 被传递、二进制 round-trip 不经过 UTF-8、超大响应被拒绝、stream callback 在响应完成前触发。 |
| EDGE-012 | P1 | ICS transport adapter | `Features/DeepBase.Net.Transport.ICS.pas:38-48` 暴露 `TDeepBaseIcsHttpTransport`；`91-93` 未编译 ICS 时构造失败；即使可用，`136-141` `Send` 仍直接 raise “requires implementation unit” | `DeepBaseFeatures.dpk:46-47` 打包了 SystemNet 和 ICS 两个 transport，但 ICS adapter 只是占位；调用者会在运行时踩到非实现。 | 要么完整实现 ICS adapter 并纳入同一 conformance suite，要么从默认包移除并改为明确的 optional package。 | 增加测试：启用 `DEEPBASE_HAS_ICS` 后 GET/POST/proxy/TLS/cancel 行为与 SystemNet adapter 一致；未启用时 API 文档明确不可实例化。 |
| EDGE-013 | P1 | HttpServer runtime mutation | `Features/DeepBase.HttpServer.pas:1127-1151` `Use/Mount/Route` 直接修改 middleware/router；`1213-1323` Indy worker thread 在处理请求时读取 router/middleware；`Listen/Stop` 在 `1325-1357` 只保护 active 状态 | server 启动后继续添加 route/middleware 会和请求处理并发访问同一 collection；配置期和运行期边界不清。 | `Listen` 后冻结 router/middleware，或用 RW lock/snapshot；运行期热更新必须通过原子替换 route table。 | 增加测试：Listen 后调用 Route/Use 明确失败，或并发请求期间热更新不抛异常且请求视图一致。 |
| EDGE-014 | P1 | HttpServer request body / binary edge | `Features/DeepBase.HttpServer.pas:1252-1258` 对 `PostStream` 无限制读入 string；`1295-1299` 二进制响应直接写 `BodyBytesContent[0]` | 大请求体可造成内存压力；空二进制响应可能访问空数组；非文本 body 被强制 UTF-8 string 化。 | 支持 max body size、streaming body、binary body；写响应前判断 `Length(BodyBytesContent) > 0`；默认限制 request body。 | 增加测试：超过限制返回 413；空 bytes 响应为 200 且 content length 0；二进制 request 不被 UTF-8 破坏。 |
| EDGE-015 | P1 | Graph correctness / concurrency | `Features/DeepBase.Graph.pas:435-455` `AddEdge` 接收任意 `AWeight`；`879-956/958-1036` 用 Dijkstra 但未拒绝负权边；`342-346` `GetNeighbors` 返回内部 list，多个算法在 `901/979/1064/1140/1228/1565` 等位置无锁遍历 `FNodes/FAdjacency` | Graph 声称有锁，但长算法没有稳定快照；并发修改会破坏遍历。负权边会让 `ShortestPath` 结果不可靠。 | 明确 Graph 是构建后只读，或算法入口创建 nodes/edges snapshot；Dijkstra 拒绝负权，另提供 Bellman-Ford；`Neighbors` 返回数组 snapshot。 | 增加测试：负权边调用 `ShortestPath` 必须失败或使用 Bellman-Ford；算法运行期间并发 Add/Remove 被禁止或不会 AV。 |
| EDGE-016 | P1 | Math package / secure random | `DeepBaseServices.dpk:21` 把 `Features/DeepBase.Math.pas` 装进 Services 包；`Features/DeepBase.Math.pas:2557-2567` `TSecureRandom.NextBytes` 调 `Randomize` 和 `Random(256)`；`2611-2612` 注释却写“已移除 Randomize” | 包边界上 Services 反向引用 Features 文件；`TSecureRandom` 名称给出安全承诺，但实现是伪随机且注释与代码矛盾。 | Math 放回明确的 Core/Services math 单元或拆包；`TSecureRandom` 删除或委托 OS CSPRNG/`DeepBase.Crypto`；普通随机和安全随机分类型命名。 | 增加测试/扫描：任何 `SecureRandom` 实现不得调用 `Random/Randomize`；Services 包不得包含 `Features\*.pas`。 |
| EDGE-017 | P2 | Math numerical edges | `Features/DeepBase.Math.pas:2396-2399` `LCM(0,0)` 会除以 `GCD(0,0)`；`2430-2442` `IsPrime` 使用 `I * I <= N`，大 Int64 可能溢出；`2416-2427` 排列组合依赖 factorial，缺更细的溢出边界 | 常规样例测试通过，但极值和数学定义边界不稳。 | `LCM(0,0)` 明确定义为 0 或抛异常；`IsPrime` 用 `I <= N div I`；组合数使用乘除约分算法并做 checked overflow。 | 增加边界测试：`LCM(0,0)`、大素数/接近 `High(Int64)`、`C(67,33)` 等应有明确结果或错误。 |
| EDGE-018 | P2 | Test coverage | `Tests/Test.DeepBase.CloudBackup.pas:690-696` 只注册 metadata/config/progress 等基础 fixture；`Tests/Test.DeepBase.CloudSync.pas:1225-1231` 以 JSON merge/local store 为主；`Tests/Test.DeepBase.Updater.pas:815-824` 只覆盖部分 metadata parse；`Tests/Test.Tools.UpdaterHelper.pas:58-99` 只测 args；`Tests/Test.DeepBase.Net.pas:9` 被 `{$IFDEF TESTDeepInsight}` 包住 | 周边模块测试能证明基础 DTO/算法，但没有覆盖最危险的安全、生命周期、真实安装、transport contract 和大数据路径。 | 先补无外网 contract tests：fake transport、恶意 zip、hash/signature、cancel/drain、body limit、Graph 并发/负权、Math 极值。 | CI 增加专门 suite：`Tests.Edge.Security`、`Tests.Edge.Transport`、`Tests.Edge.Lifecycle`；`Test.DeepBase.Net` 从条件编译中拆出可常跑子集。 |

### 10.3 本轮结论

- Cloud 模块不是缺功能，而是“安全承诺”和“实际实现”不一致：加密、完整性和取消语义必须先收敛，否则越上层越难补。
- Updater 已经有 manifest、signature、helper、rollback 的形状，但默认信任策略和 zip 安装流程仍然不能按 secure updater 宣称使用。
- Net transport 是 LLM、Updater、AutoUpdate 等模块的共同瓶颈；stream/cancel/binary/proxy 需要作为公共契约修，而不是每个上层模块各自绕开。
- Graph/Math 属于基础能力外溢到周边包的典型案例：包边界、命名安全承诺和极值行为要校准，否则会污染 Services 层可信度。

### 10.4 周边模块后续修复优先级建议

只记录建议，暂不修复。后续若进入修复阶段，建议顺序如下：

1. P0：`EDGE-001` 统一 Cloud 加密和密钥语义。
2. P1：`EDGE-006/007/008` Updater 信任链、safe unzip、Helper 安装安全。
3. P1：`EDGE-011/012/013/014` Net transport contract 与 HttpServer 运行期安全。
4. P1/P2：`EDGE-003/004/005/009/010/015/016/017/018` 生命周期、API snapshot、Graph/Math 边界和测试补齐。

---

## 11. 2026-05-14 周边模块第三轮：Commerce / Payment / License / Unlock / AntiTamper 分板块评审

范围：

- Commerce：`Features/DeepBase.Commerce.*.pas`，含 SafeClient、Backend、Storage、Service、Permissions、UpgradeFlow、SDKGateway、PaymentBridge、Supabase/Firebase adapter。
- Payment：`ThirdParty/Payment/DeepBase.Payment*.pas` 与 `ThirdParty/Payment/README.md`。
- License / Unlock / AntiTamper：`Core/DeepBase.License.pas`、`Persistence/DeepBase.Persistence.License.FireDAC.pas`、`Features/DeepBase.Unlock.pas`、`Features/DeepBase.AntiTamper.pas`。
- 测试参考：`Tests/Test.DeepBase.Commerce.pas`、`Tests/Integration/Test.Integration.CommerceE2E.pas`、`Tests/Test.DeepBase.Payment.pas`、`Tests/Test.DeepBase.License.pas`、`Tests/Test.DeepBase.Unlock.pas`、`Tests/Test.DeepBase.AntiTamper.pas`。
- 本轮继续排除：`DeepShell`、`BrowserAutomation`、`IntentClarification`，它们按用户要求放到最后。
- 本轮只评审和记录建议，不修复源码。

### 11.1 周边商业化模块总览

| 子板块 | 评分 | 当前判断 |
|--------|------|----------|
| Commerce client / backend contract | 6/10 | SafeClient、权限、升级流和后端契约已有形状；但 token 生命周期、license snapshot canonicalization、额度消费幂等性和包边界仍需收敛。 |
| Commerce storage adapters | 5/10 | In-memory、HTTP、Supabase、Firebase 覆盖了多种接入；但 direct DB adapter 仍暴露服务端密钥边界，quota consume 在多个实现中不是原子操作。 |
| Payment providers | 5.5/10 | Stripe/PayPal/Alipay/WeChatPay 都有实现和测试雏形；但第三方支付单元未纳入运行时包，webhook 验签契约分裂，PayPal/WeChatPay 回调路径存在明显缺口。 |
| License / entitlement | 5.5/10 | 新 Commerce snapshot 方向比旧本地 license 更合理；但旧 License 仍是短签名方案，FireDAC 存储明文 license key，snapshot revocation freshness 未闭合。 |
| Unlock | 7/10 | 文档明确它不是强安全边界，适合作轻量营销解锁；风险在于不能被误用为付费授权或长期 entitlement。 |
| AntiTamper | 5/10 | 已从 XOR 收敛到 AES/PBKDF2/HMAC，但仍是 CBC + 外置明文 HMAC 组合，且 library 代码会弹窗、打开浏览器并 `Halt(1)`，不适合作通用框架默认行为。 |
| 测试可信度 | 6/10 | Commerce/Payment/License/Unlock/AntiTamper 测试文件较多；但缺少并发额度消费、重复 webhook、snapshot canonicalization/revocation、包纳入和真实密钥存储的 contract tests。 |

### 11.2 P0 / P1 / P2 任务清单

| 编号 | 优先级 | 模块 | 证据 | 问题 | 修复建议 | 验证建议 |
|------|--------|------|------|------|----------|----------|
| COMM-001 | P1 | Package boundary | `DeepBaseFeatures.dpk:102-109` 只包含 Commerce core 8 个单元；`Features/DeepBase.Commerce.SDKGateway.pas`、`PaymentBridge.pas`、`Adapter.Supabase.pas`、`Adapter.Firebase.pas` 不在包内；`rg -n "Payment" -g "*.dpk"` 未发现 `ThirdParty/Payment` 单元入包 | 源码、测试和发布包边界漂移。调用者看到仓库有 SDKGateway/PaymentBridge/Payment provider，但运行时包不一定发布这些能力。 | 明确 Commerce 发布边界：core client、server/admin adapter、third-party payment provider 分包；可选适配器用独立 dpk 或明确不发布。 | 增加 package coverage 测试：测试引用的 Commerce/Payment 单元必须属于某个运行时包或被显式标记为 optional/source-only。 |
| COMM-002 | P1 | Server-only boundary | `SupabaseConfig.CreateServerOnly` 在 `Features/DeepBase.Commerce.Adapter.Supabase.pas:120-124` 设置 server-only prototype；构造器在 `132-138` 用环境变量放行；`FirebaseConfig.CreateServerOnly` 在 `Features/DeepBase.Commerce.Adapter.Firebase.pas:131-136`，构造器在 `143-149` 同样用环境变量放行 | Supabase/Firebase direct adapter 需要 API key/access token，虽然已有 server-only 提示，但环境变量放行和源码同包放置仍容易被桌面客户端误用。 | server/admin adapter 移出默认 Features 包；要求 server compile symbol 或 runtime context；桌面客户端只能使用 `TDeepKitSafeClient` 访问受控后端。 | 增加静态检查：桌面发布配置不得引用 `DeepBase.Commerce.Adapter.*`；未开启 server/admin symbol 时不能实例化 direct adapter。 |
| COMM-003 | P1 | SafeClient token lifecycle | `TDeepKitSafeClientConfig` 保存 `BearerToken/ApiKey` 于 `Features/DeepBase.Commerce.SafeClient.pas:66-67`；`SetAccessToken/GetAccessToken` 在 `539-546` 直接读写 `FConfig.BearerToken`；登录/刷新在 `745-771` 更新 token | token 存在普通 record/string 中，且读写无锁；并发请求、刷新、登出会出现竞态，密钥/令牌生命周期也没有 secret-store 边界。 | 抽象 `IAccessTokenProvider/ISecretStore`；请求构建使用 immutable auth snapshot；refresh 用 singleflight 和过期时间；登出/刷新/请求之间定义锁语义。 | 并发测试：多线程请求 + refresh/logout 不应串 token；token 过期只触发一次刷新；内存配置不落盘。 |
| COMM-004 | P1 | HTTP transport contract | Commerce 自有 `ICommerceBackendHttpTransport` / `TCommerceBackendHttpClientTransport`，`BuildHeaders` 在 `Features/DeepBase.Commerce.SafeClient.pas:601-612`、`Backend.Http.pas:1302-1312` 重复拼 header；前一轮 `EDGE-011` 已确认公共 `IDeepBaseHttpTransport` 缺 streaming/proxy/cancel/binary | Commerce 继续复制 HTTP transport 会让 timeout、retry、cancel、proxy、TLS 策略和 LLM/Updater 分裂。 | 先修公共 transport/resilience contract，再让 Commerce 只依赖 shared transport；Commerce 保留 fake transport 作为 contract test 注入点。 | transport conformance tests 覆盖 Commerce：取消、超时、429/5xx 分类、proxy/header/idempotency 均一致。 |
| COMM-005 | P1 | License snapshot canonicalization | `LicenseSnapshotFromJson` 在 `Features/DeepBase.Commerce.SafeClient.pas:428-445` 遇到 JSON object payload 时调用 `TJSONObject(PayloadValue).ToJSON`；`ValidateLicenseSnapshot` 在 `645-719` 直接验证 `ASnapshot.Payload` 签名 | 如果后端签名的是原始 JSON 字符串，客户端重新序列化后的字段顺序、空白和转义可能改变，导致验签不稳定；如果后端按对象签名，则必须明确 canonical 规范。 | 后端返回 raw signed payload string 或 base64 payload；或者采用 JCS 等 canonical JSON；签名输入写入协议文档。 | 增加测试：同一 payload 不同字段顺序/空白必须按协议稳定验签；篡改字段必须失败。 |
| COMM-006 | P1 | License snapshot freshness | snapshot record 有 `RevocationVersion` 字段并在 `SafeClient.pas:37/115/438` 读取；`ValidateLicenseSnapshot` 只校验 expires/app/device/signature；`Permissions.pas:31/180-181` 保存 `FLastSnapshot` 但没有本地 revocation floor/max-age 策略 | 离线或缓存 snapshot 在过期前可能继续可用，即使服务端已经撤销；`RevocationVersion` 没有形成单调约束。 | 引入 signed revocation floor、snapshot max age、在线 refresh policy；本地缓存记录最高 revocation version，低版本拒绝。 | 增加回归：旧 revocation version snapshot 被拒绝；超过 max-age 的离线 snapshot 降级或拒绝。 |
| COMM-007 | P1 | Quota idempotency | `Permissions.pas:155-171` 先 `HasFeature` 再 `ConsumeEntitlement`；`SafeClient.ConsumeEntitlement` 在 `Features/DeepBase.Commerce.SafeClient.pas:961-984` 允许空 `ARequestId`，空时不发送 request id 或 `Idempotency-Key` | 额度消费是高风险写操作，当前可以无幂等键；check-then-consume 分离在并发场景下也可能重复授权。 | 消费型调用必须要求 request id；后端提供 atomic authorize+consume；客户端无 request id 时直接失败。 | 并发测试：同一 request id 重放只消费一次；无 request id 的 metered feature 调用失败。 |
| COMM-008 | P1 | Commerce storage atomicity | `TInMemoryCommerceStorage` 在 `Features/DeepBase.Commerce.Storage.pas:44-51` 使用多个 `TDictionary` 且无锁；`ConsumeEntitlement` 在 `263-285` 读改写 quota；Supabase/Firebase 在 `Adapter.Supabase.pas:675-706`、`Adapter.Firebase.pas:853-887` 先 GET 再 PATCH，且 `ACount > RemainingQuota` 时把 quota 置 0 仍返回 True | 内存实现不是线程安全；Supabase/Firebase adapter 的 quota consume 不是原子操作，且和 in-memory 的“余额不足失败”语义不一致，存在超额消费。 | storage contract 明确 atomic consume 语义；生产 adapter 使用 DB transaction/RPC/conditional update；in-memory 加锁或标记 test-only；余额不足必须返回 False。 | 同一 entitlement 并发消费压力测试；余额 1 消费 2 必须失败；各 adapter 行为一致。 |
| COMM-009 | P1 | Payment confirmation idempotency | `ConfirmPayment` 在 `Features/DeepBase.Commerce.Service.pas:239-282` 查询订单、更新 payment、更新 order、再 `GrantEntitlementForOrder`；`GrantEntitlementForOrder` 在 `318-338` 先 list entitlement 再 upsert | 重复 webhook 虽然有 paid/status/source order 检查，但没有事务或唯一约束保护；并发重复回调可能同时通过检查并重复授予 entitlement。 | 支付确认应由 storage/backend 提供事务化状态机：按 provider trade no/out_trade_no 幂等，order paid 和 entitlement grant 同事务提交。 | 重复 webhook 并发测试：同一支付通知 N 次只产生一个 paid transition 和一个 entitlement。 |
| COMM-010 | P1 | PaymentBridge webhook context | `PaymentBridge.pas:122-160` 只把 raw body 和 string headers 传给 SDK；Stripe 使用 `Stripe-Signature`，PayPal 使用 `Paypal-Transmission-*`；WeChatPay 直接 fail-closed，提示需要 header signature + AES-GCM | 支付 webhook 需要 raw bytes、headers、timestamp、证书序列号、provider event id 等上下文；当前接口太薄，导致 WeChatPay 无法实现，PayPal/Stripe 也缺少 replay/event-id 约束。 | 定义 typed `TPaymentWebhookContext`：raw bytes、normalized headers、remote ip、received_at、provider event id、cert serial；所有 verifier 只接受 context。 | provider contract tests：缺 header、header 大小写、重复 event id、过期 timestamp、证书序列号不匹配都必须失败。 |
| COMM-011 | P1 | Payment secrets | SDKGateway 工厂在 `Features/DeepBase.Commerce.SDKGateway.pas:167/180/194/207` 直接写 `ApiKeyV3/PrivateKey/SecretKey/ClientSecret`；PaymentBridge 在 `188-235` 也直接写密钥；Payment config 虽有 `Set*Secure` 方法，如 Stripe `DeepBase.Payment.Stripe.pas:130-147` | 安全 setter 存在，但 factory 和桥接层绕过它，文档/示例容易鼓励明文字符串长期驻留。 | 工厂改为接收 secret reference 或 `ISecretStore`；直接字符串 API 标记 dev/test only；敏感字段使用 secure setter 并尽量缩短明文生命周期。 | 静态测试：生产 factory 不允许直接赋值 `SecretKey/PrivateKey/ApiKeyV3/ClientSecret`；README 示例不出现硬编码密钥。 |
| COMM-012 | P1 | Payment provider contracts | `DeepBase.Payment.Core.pas:12-35` 定义一套 `IPaymentClient`；`DeepBase.Payment.pas`/provider 单元另有实际 `IPaymentClient` 体系；`CreatePaymentClient` 在 `DeepBase.Payment.Core.pas:82-88` 直接 `ENotSupportedException` | Payment 存在两套抽象，且 Core factory 是不可用占位；调用者容易接入错接口，测试也可能覆盖不到真实 provider。 | 合并或废弃 `DeepBase.Payment.Core`；保留一个 canonical payment interface/factory，provider adapter 全部按同一 contract 测试。 | 编译期检查：文档中的 payment facade 能创建真实 provider；不可用 factory 不进入默认导出路径。 |
| COMM-013 | P1 | PayPal webhook regression | `TPayPalClient.VerifyNotification` 在 `ThirdParty/Payment/DeepBase.Payment.PayPal.pas:756-759` 的生产拒绝判断被乱码注释并留下无条件 `Exit(False)`，导致解析路径总是返回 False；`PaymentBridge.pas:150-156` 先验签后仍调用 `FClient.VerifyNotification` | PayPal webhook 即使验签成功也会在后续解析阶段失败，属于商业化回调链路的功能性缺陷。 | 修复编码/换行并明确 `VerifyNotification` 是否只解析；推荐改为 `ParseVerifiedNotification`，由 webhook context 一次性完成 verify+parse。 | 增加 PayPal signed webhook happy path 测试：验签成功后能解析订单和金额；生产无签名必须失败。 |
| COMM-014 | P1 | WeChatPay notification verification | `TWeChatPayClient.VerifyNotification` 在 `ThirdParty/Payment/DeepBase.Payment.WeChatPay.pas:1130-1187` 只解析 JSON resource 并用 `ApiKeyV3` 解密；PaymentBridge 在 `Features/DeepBase.Commerce.PaymentBridge.pas:122-126` 直接 fail-closed | WeChatPay V3 回调需要先校验 `Wechatpay-Signature/Timestamp/Nonce/Serial`，再 AES-GCM 解密；当前 provider parse 方法无 header 输入，桥接层只能禁用。 | 用 typed webhook context 重写 WeChatPay verifier：平台证书/公钥序列号匹配、timestamp tolerance、nonce/signature 校验、AES-GCM 解密。 | WeChatPay contract tests：缺任一 header、签名错误、timestamp 过期、serial 不匹配、ciphertext 篡改均失败。 |
| COMM-015 | P1 | Core License legacy signing | `Core/DeepBase.License.pas:160-168` 只从 `DEEPBASE_LEGACY_LICENSE_SIGNING_KEY` 读取 legacy secret；`SignData` 在 `363-374` 使用 `SHA256(Data + Secret)` 并截断 16 字符；`GenerateLicenseKey` 在 `397-440` 仍生成这种 key | 旧本地 license 是拼接哈希 + 64-bit-ish 短签名，不是标准 HMAC，也没有 key id/rotation；如果被用于生产付费授权，强度不足。 | 将 legacy generator 限定为迁移工具；生产统一使用 server-issued signed snapshot；若保留本地签名，使用完整 HMAC-SHA256/Ed25519/RSA 并带 key id。 | 测试：无 legacy secret 时生成失败；生产配置不得调用 legacy generator；snapshot 验签路径覆盖 key rotation。 |
| COMM-016 | P1 | License storage | `Persistence/DeepBase.Persistence.License.FireDAC.pas:54` 从 `Settings.Value` 读 `license_key`，`78-94` 直接写明文，`119` 删除；写入 update/select/insert 无事务 | license key 明文存储且可复制/篡改；写入路径也不是原子 upsert。 | 存储 signed snapshot + device binding metadata；必要时用 DPAPI/secret store 加密 at rest；写入走事务或统一 upsert。 | 篡改 Settings.Value 后必须 fail closed；写入失败回滚；跨设备复制后 snapshot 被拒绝。 |
| COMM-017 | P2 | Unlock boundary | `Features/DeepBase.Unlock.pas:1-23` 明确不是强安全边界；但 `UNLOCK_SECRET` 在 `167` 写死，`ComputeCheckChar` 在 `314-338` 用 SHA256 seed 生成单字符校验，`GenerateCode` 在 `525-536` 公开生成 | Unlock 适合作营销/低摩擦解锁，不应被误用为付费 license 或长期 entitlement；当前 API 没有从命名和文档上强制边界。 | 文档和 API 标注 `MarketingUnlock`/`PromoUnlock` 语义；付费功能必须走 Commerce entitlement/license snapshot。 | 增加文档检查：付费/License/Commerce 文档不得建议用 Unlock 保护商业功能。 |
| COMM-018 | P1 | AntiTamper crypto composition | `AntiTamper.pas:153-188` PBKDF2 后把 key 转 hex string，再对 `THash.DigestAsString(Data)` 做 HMAC；`206-269` 使用 AES-256-CBC，wire format 只有 `IV || Ciphertext`；`459/559-564` 对明文数据计算/校验 HMAC | 当前是 CBC + 明文 hash/HMAC 元数据，密文自身未被认证；读取时先解密再校验，错误处理面更大；HMAC key 和输入也不是标准 raw bytes over ciphertext。 | 改为 AES-256-GCM；或 Encrypt-then-MAC：HMAC(raw key, version || iv || ciphertext || metadata)，解密前先验 tag。 | 篡改密文任意 byte 必须在解密前失败；同一明文两次加密输出不同；HMAC 使用标准 test vector。 |
| COMM-019 | P1 | AntiTamper library side effects | `Features/DeepBase.AntiTamper.pas:12` 直接依赖 `Winapi.ShellAPI/Windows`；`HandleSecurityViolation` 在 `590-619` 弹 `MessageBox`、`ShellExecute` 打开下载页并 `Halt(1)` | 架构库的 feature 模块直接控制 UI 和进程退出，下游无法捕获或自定义响应，也破坏非 Windows/服务端场景。 | 改为抛出 typed exception 或触发 `IAntiTamperViolationHandler`；VCL/FMX/UI 层再决定弹窗、下载或退出。 | 测试：检测失败只返回错误/异常，不直接终止进程；无 UI 环境可运行。 |
| COMM-020 | P2 | AntiTamper config / SQL boundary | `AntiTamper.pas:38-39` class var `FConfig/FInitialized` 无锁；表名只在 `SetupDatabase` 的 `305-316` 验证，后续 `SaveSecureImage/ClearTable/ReseedMinimal` 在 `429/438/445/630/652` 继续拼接 `FConfig.TableName` | 全局 mutable config 不是线程安全；如果调用者绕过 `SetupDatabase` 或运行期修改 config，SQL identifier 约束不稳定。 | 初始化加锁并冻结 config；所有 SQL 入口统一使用 validated identifier；禁止未 setup 直接操作。 | 并发 Initialize/Save/Load 测试；非法 table name 在所有入口都失败。 |
| COMM-021 | P2 | Test coverage | 当前有 `Tests/Test.DeepBase.Commerce.pas`、`Tests/Test.DeepBase.Payment.pas`、`Tests/Integration/Test.Integration.CommerceE2E.pas` 等，但未看到覆盖包纳入、并发 quota、重复 webhook、snapshot canonicalization/revocation、PayPal happy path、WeChat header verifier、secret store 使用的用例 | 现有测试能证明大量 DTO/happy path，但还不能证明商业化链路可生产承载支付和授权。 | 建立 Commerce/Payment contract suite，不依赖真实外网：fake backend、fake verifier、fake clock、fake secret store、并发 harness。 | CI 增加 `Commerce.Security`、`Commerce.Idempotency`、`Payment.WebhookContract`、`License.SnapshotContract` 分组。 |

### 11.3 本轮结论

- Commerce 的方向正确：把桌面客户端通过 `TDeepKitSafeClient` 接到后端，而不是直接暴露数据库或支付密钥。但当前 direct adapter、SDKGateway、PaymentBridge、Payment provider 的包边界和安全边界还没有完全隔离。
- 商业化链路最高风险集中在三处：支付 webhook 验签/幂等、license snapshot 签名输入与 revocation freshness、quota consume 的原子性和幂等性。
- Payment provider 不是“没有实现”，而是抽象不统一：`DeepBase.Payment.Core` 的 factory 不可用，provider 单元另走一套接口；PaymentBridge 再包一层，导致验签责任分散。
- License/Unlock/AntiTamper 都有明确用途，但安全等级需要写进 API 边界：Unlock 是营销解锁，legacy License 是迁移/本地兼容，AntiTamper 不应在框架层直接弹窗和退出进程。

### 11.4 商业化模块后续修复优先级建议

只记录建议，暂不修复。后续若进入修复阶段，建议顺序如下：

1. P1：`COMM-001/002/011/012` 先明确发布包、server-only adapter 和 Payment canonical interface。
2. P1：`COMM-010/013/014` 统一 webhook context，修 PayPal 回调解析，补 WeChatPay V3 header verifier。
3. P1：`COMM-005/006/015/016` 收敛 license snapshot 和 legacy License 边界。
4. P1：`COMM-007/008/009` 修 quota consume 和支付确认的原子性/幂等性。
5. P1/P2：`COMM-003/004/018/019/020/021` token lifecycle、transport contract、AntiTamper crypto/UI side effects 和测试矩阵补齐。

---

## 12. 2026-05-14 周边模块第四轮：Speech / Audio / ASR / TTS / Wake / Voiceprint 分板块评审

范围：

- Speech packages：`DeepBaseSpeechCore.dpk`、`DeepBaseSpeechASR.dpk`、`DeepBaseSpeechTTS.dpk`、`DeepBaseSpeechWake.dpk`、`DeepBaseSpeechVoice.dpk`，以及 `DeepBaseFeatures.dpk` 中收录的 Speech 单元。
- Speech source：`Features/DeepBase.Speech.*.pas`，含 Types、Config、Registry、Runtime、Policy、Schema、Audio.WinMM、ASR.Baidu、ASR.SAPI、TTS.SAPI、WakeWord、Voiceprint、MFCC、DTW、Service。
- 测试参考：`Tests/Test.DeepBase.Speech.pas`、`Tests/DeepBaseTests.dpr`、`Tests/Speech/TestSpeechHeadless.dpr`、`Tests/Speech/*.bat`。
- 本轮只评审 Speech 自身；更大的 IntentClarification 板块仍按要求放到最后。
- 本轮只评审和记录建议，不修复源码。

### 12.1 Speech 模块总览

| 子板块 | 评分 | 当前判断 |
|--------|------|----------|
| 包边界 | 4.5/10 | 有 5 个独立 Speech 包，但 `DeepBaseFeatures.dpk` 又收录一部分 Speech 单元；独立包、Features 包和测试引用的单元集合不一致。 |
| 接口与注册 | 4/10 | `Speech.Types` 定义了统一接口，但 SAPI/Wake/Voiceprint/Intent 实现多处没有实现这些接口；`SpeechRegistry` 只能发现 metadata，不能创建可用 backend。 |
| Audio / Runtime | 5/10 | 有 WinMM capture 和 AudioSession 状态机雏形；但 callback、停止、buffer、锁语义还不够稳，且 SpeechCore 引入 Windows/FireDAC 依赖。 |
| ASR / TTS / Wake | 4.5/10 | Baidu batch ASR 可测；SAPI streaming、WakeWord grammar、TTS async 仍有占位和 COM 线程模型风险。 |
| Voiceprint / MFCC / DTW | 5/10 | 本地 MFCC/DTW 原型完整；但文档宣称 DPAPI/ConfigDB 持久化，实际只存内存，算法和注释也有不一致。 |
| Policy / Privacy | 5/10 | 有 policy gate 的形状；但治理接入是占位，语义和实现相反，voiceprint 默认允许不符合“显式授权”口径。 |
| 测试可信度 | 5.5/10 | 主 DUnit 覆盖 Baidu/VAD/Service；Headless DPR 覆盖更多纯逻辑，但未确认进入主 CI，且缺 SAPI/WinMM/COM 生命周期和 package 编译门禁。 |

### 12.2 P0 / P1 / P2 任务清单

| 编号 | 优先级 | 模块 | 证据 | 问题 | 修复建议 | 验证建议 |
|------|--------|------|------|------|----------|----------|
| SPEECH-001 | P1 | Package boundary | `DeepBaseSpeechCore.dpk:36-41` 包含 Registry/Config/Policy/Runtime/Schema/Intent，但没有 `Speech.Types`；`DeepBaseSpeechASR.dpk:37-39` 包含 SAPI/Baidu；`DeepBaseFeatures.dpk:112-116` 只包含 Types/VAD/Audio.WinMM/ASR.Baidu/Service；`Tests/DeepBaseTests.dpr:229-233` 也只引用这 5 个单元 | Speech 存在三套边界：独立包、Features 包、主测试引用。调用者无法判断 canonical 发布路径，独立包和主测试也覆盖不同能力。 | 确定唯一包图：`SpeechCore` 至少包含 Types/Config/Registry/Policy；Audio/ASR/TTS/Wake/Voiceprint 各自独立；`DeepBaseFeatures` 不再重复收录实现单元，或只 re-export facade。 | 增加 dpk coverage 测试：每个 `Features/DeepBase.Speech.*.pas` 必须属于唯一 runtime package 或显式标记 experimental；主测试矩阵按 package 编译。 |
| SPEECH-002 | P1 | SpeechCore dependencies | `DeepBaseSpeechCore.dpk:31-33` 只 requires `rtl`、`DeepBaseCore`；但 `Features/DeepBase.Speech.Schema.pas:15` uses `FireDAC.Comp.Client`，`Runtime.pas:17` uses `Winapi.Windows` | `SpeechCore` 名义上是核心包，却直接包含 FireDAC schema 和 Windows runtime。包依赖声明不完整，也破坏跨平台/无 DB 的 core 口径。 | 将 Schema 移到 `DeepBaseSpeechPersistence` 或已有 Persistence 包；Runtime 的 QPC/Windows 依赖抽到 platform adapter；Core 包只保留无平台接口、config、registry、types。 | 编译门禁：`DeepBaseSpeechCore.dpk` 不允许 FireDAC/Winapi 依赖；非 Windows 静态扫描不出现 unguarded `Winapi.*`。 |
| SPEECH-003 | P1 | Interface contract | `Speech.Types.pas:160-209` 定义 `ISpeechRecognizerEx/ITTSBackend/IWakeWordDetector/IVoiceprint/IIntentParser`；`Speech.Service.pas:63-83` facade 持有这些接口；但 `ASR.SAPI.pas`、`TTS.SAPI.pas`、`WakeWord.pas`、`Voiceprint.pas` 各自定义普通类/重复 record，不实现这些接口 | Speech 的“统一接口”与实际 backend 脱节。自注册 backend 只能进入 `SpeechRegistry` metadata，不能赋值给 `TSpeechService.ASR/TTS/WakeWord/Voiceprint`。 | 所有 backend 实现 canonical interfaces；`TSpeechRegistry` 存 factory/provider，而不是只存可用性 metadata；`TSpeechService` 从 registry/IoC 懒加载默认 backend。 | Contract tests：注册 SAPI/Baidu/mock backend 后，`TSpeechService.ASR/TTS/WakeWord/Voiceprint` 能返回可调用接口。 |
| SPEECH-004 | P1 | Registry lifecycle / thread safety | `Speech.Registry.pas:54-59` `EnsureInit` 无同步创建 class var；`Discover` 在 `155-166` 持有 registry 锁时调用 `IsAvailableFunc()`；SAPI/Wake/TTS 的 `IsAvailableFunc` 会懒创建全局对象并触发 COM 探测 | 并发首次注册/发现可能重复创建 registry state；可用性检查在锁内执行慢 COM/系统调用，阻塞所有 registry 操作，也有重入死锁风险。 | `EnsureInit` 用 class constructor 或原子锁；Discover 在锁内复制 snapshot，锁外执行 availability check；backend availability 加缓存和 timeout。 | 并发 Discover/Register/Disable 压力测试；模拟慢 `IsAvailableFunc` 不应阻塞 unrelated registry 操作。 |
| SPEECH-005 | P1 | Static facade thread safety | `Speech.Service.pas:63-68` 使用 class var 保存全局 backend；`219-274` Register/Accessor 直接读写无锁；注释声称 Thread-safe；`TranscribeFromMic` 在 `279-313` 直接 `Sleep(Min(AMaxSeconds * 1000, 5000))`，且识别时使用 `TSpeechRecognitionOptions.Default` 忽略传入语言/超时 | facade 注册、读取、录音、识别没有统一生命周期；便利方法会阻塞调用线程、不能取消，并且参数没有真正传给 ASR。 | 用 RuntimeContext/IoC 管理 SpeechService；全局 backend snapshot 加锁或 immutable；Transcribe 返回 operation handle，支持 cancel，并正确传递 `ALanguage/ASilenceTimeoutMs/AMaxSeconds`。 | 多线程注册/读取测试；`TranscribeFromMic('en-US')` 必须把语言传入 recognizer；阻塞录音可取消。 |
| SPEECH-006 | P1 | Runtime state machine | `Speech.Runtime.pas:38-43` 有 `FLock/FOnStateChange`；`DoTransition` 在 `123-126` 持锁调用 callback；`State/LastTransition/OnStateChange` 属性直接读写；全局 `SpeechRuntime` 在 `220-223` 初始化/释放 | Runtime 声称所有 public methods thread-safe，但属性读写和 callback 不受保护；持锁回调会导致 reentrant deadlock 或长时间持锁。 | 状态读写都走锁或 atomic snapshot；锁内只更新状态，锁外触发 callback；全局实例改为显式 bootstrap/shutdown。 | 回调中再次调用 `RequestMic/ReleaseMic` 不死锁；多线程读 State/切换状态不出现不一致。 |
| SPEECH-007 | P1 | WinMM audio capture lifecycle | `Audio.WinMM.pas:17/82/210/231/266` 直接读写 `FIsRecording`；`StartRecording` 未拒绝重复 start；`WaveInProc` 在 `44-61` 回调里根据 `IsRecording` 写 stream 并 re-add buffer；`StopRecording` 在 `228-235` stop/reset/free/close 无统一锁；`FStream` 持续增长直到 stop | WaveIn 回调、Stop/Destroy、GetPCMData 之间存在竞态；重复 start 可能打开多个 wave handle；长录音内存无上限。 | 用独立 capture state lock/ref-count；Stop 先阻止回调 requeue，再等待回调 drain，再释放 buffer；限制最大录音字节或提供 streaming ring buffer。 | 压力测试：快速 start/stop/destroy 不 AV；重复 start 被拒绝；长录音超过上限可控失败或滚动缓冲。 |
| SPEECH-008 | P1 | Baidu ASR secrets / token | `ASR.Baidu.pas:13-18` config 保存 `ApiKey/SecretKey`；`263-274` 用 query string 发送 `client_secret`；`269-313` token cache `FAccessToken/FTokenExpireTime/FLastError` 无锁；默认 transport 直接 `THTTPClient`，统一 transport 只是可选 adapter | 云 ASR 密钥和 token 生命周期没有走统一 secret store；并发识别会重复刷新或串改 `FLastError`；URL 中的 secret 更容易被日志/代理记录。 | API key/secret 改为 secret reference；token cache 加锁/singleflight；默认使用统一 transport，支持 cancel/retry/response limit；敏感 URL 日志脱敏。 | 并发 token 刷新只请求一次；日志/recorded request 不出现 raw secret；401/429/5xx 分类测试。 |
| SPEECH-009 | P1 | SAPI ASR streaming | `ASR.SAPI.pas:42` 注释说 partial/final callback；`Start` 在 `288-301` 只启动 dictation和 worker；`WorkerProc` 在 `353-363` 只是 wait/sleep，注释说明完整 event-driven 需 M2；`RegisterSAPIASRBackend` 在 `379-380` 标记 SupportsStreaming/Grammar=True | SAPI ASR 对外宣称 streaming/grammar，但当前不读取 SAPI events，不产生 partial/final 识别结果；`Stop` 只 `Sleep(100)` 后释放 COM 对象，线程未 join。 | 暂时把 SupportsStreaming/Grammar 置 False 或 experimental；实现 `ISpNotifySource/GetEvents` 事件循环和明确 join/cancel；Stop 等待 worker 退出后再释放 COM 对象。 | fake/real SAPI smoke：Start 后讲话能触发 partial/final；Stop 后 worker 已退出且不访问释放的 COM 对象。 |
| SPEECH-010 | P1 | WakeWord detector | `WakeWord.pas:163-165` 只保存 callback；`Start` 在 `208-213` 明确用 dictation placeholder；没有事件循环触发 `FCallback`；注册信息在 `251-252` 标记 SupportsStreaming/Grammar=True | WakeWord 当前不是 wake-word detector，只是开启 SAPI dictation 占位；设置的 wake words 没有进入 SRGS grammar，也不会回调检测事件。 | 未实现前在 registry 中降级为 unavailable/experimental；实现 SRGS grammar、SAPI event loop、threshold 过滤和 callback thread 策略。 | 测试：给定 grammar 和模拟 SAPI event，只匹配配置 wake words；非 wake words 不触发。 |
| SPEECH-011 | P1 | SAPI / COM threading | `TTS.SAPI.pas:138-148` `SpeakAsync` 创建匿名线程并在该线程访问 `FVoice.WaitUntilDone`；析构 `50-54` 可释放 `FVoice`；`ASR.SAPI.pas:299-300` worker `FreeOnTerminate=True` 且 `Stop` 不 join | COM 对象跨线程/公寓使用没有 marshal；异步线程可能和析构并发访问同一 COM interface；SAPI lifecycle 不可预测。 | 所有 SAPI COM 对象绑定到专用 STA worker，调用通过队列投递；析构先 cancel+join worker，再释放 COM；跨线程回调同步到调用者指定 scheduler。 | COM lifecycle 测试：SpeakAsync 后立即 Destroy 不崩溃；Stop/Destroy 后无后台线程访问对象。 |
| SPEECH-012 | P1 | SAPI declaration risk | `SAPI.Decl.pas:6-8` 说明手写 SAPI IDL；`101`、`171-187`、`197-222` 使用 placeholder 方法维持 vtable；没有看到与官方 type library 的自动生成或 ABI 验证 | 手写 COM interface 的 vtable 顺序只要错一项就会调用错误方法，风险比普通 Delphi 接口高。 | 优先使用导入的 type library 或生成文件；如果必须手写，建立 ABI conformance smoke：创建对象、调用每个声明方法、校验 HRESULT 和行为。 | Win64 SAPI smoke 测试覆盖 Voice.Speak/WaitUntilDone、Recognizer.CreateRecoContext、Grammar.LoadDictation。 |
| SPEECH-013 | P1 | Voiceprint persistence / privacy | `Voiceprint.pas:7-9` 声称 ConfigDB + DPAPI 加密；`154-172` 实际只写内存并 TODO 持久化；`188` 删除也 TODO；`Speech.Schema.pas:25-53` 创建了 `voice_profiles` 表但未被 Voiceprint 使用 | 声纹属于生物特征数据，文档声称加密持久化但实现只在内存缓存，重启丢失且没有 consent/retention/audit 边界。 | 实现 voice profile repository：DPAPI/SecretStore 加密特征、HMAC、owner app、consent timestamp、删除审计；未启用存储前文档标记为 in-memory experimental。 | 重启后 profile 可恢复；DB 中 features 不为明文；删除后列表和 DB 都清理。 |
| SPEECH-014 | P2 | Voiceprint algorithm / concurrency | `Voiceprint.pas:242-243` Verify 使用 mean vector 欧氏距离而非 full DTW；`Identify` 在 `286` 释放锁后于 `290` 访问 `FProfileInfos`；`Speech.Types.pas:199-206` 的 `IVoiceprint` 和 `Voiceprint.pas` 自定义类型不一致 | 算法描述和实现不一致；并发 Delete/Profile 修改时 Identify 有字典访问竞态；接口类型不统一导致无法作为 `IVoiceprint` backend。 | 明确 v1 是 mean-vector similarity，或实现 full DTW/PLDA 等可解释算法；所有 profile 字典访问在同一锁内或 snapshot；统一 Types 中的 voiceprint 类型。 | 并发 Identify/Delete 测试；同一 profile 的 Verify/Identify 使用一致阈值；实现 `IVoiceprint` contract test。 |
| SPEECH-015 | P2 | MFCC / DTW correctness | `MFCC.pas:8` 注释声称 13 + delta + delta-delta = 39 维，但 `TMFCCFrame` 在 `20` 只有 13 维；`ComputeFFT` 在 `153-160` 是 O(N^2) DFT；`DTW.pas:73` 空序列 distance=0，`105` path length 是近似值；Headless test 在 `Tests/Speech/TestSpeechHeadless.dpr:240` 还断言空序列 distance=0 | 特征维度、性能和边界语义不一致；空序列距离 0 容易被误解为完美匹配，DTW path/score 也不适合生产阈值校准。 | 注释和类型统一；用 radix-2 FFT 或成熟库；空序列返回 invalid/infinite；DTW 做真实 backtracking 或明确 approximation。 | MFCC golden vector 测试；长音频性能基准；空序列和不同长度序列边界测试。 |
| SPEECH-016 | P1 | Policy / governance | `Speech.Policy.pas:5-8` 注释说 Governance 未初始化时全部禁用；实现 `45-52` 却默认允许 ASR/TTS/Wake/Voiceprint；`RegisterGates` 在 `58-67` 是 placeholder | 隐私/权限策略的文档和实现相反，尤其 voiceprint 默认允许不符合“显式用户授权”的安全口径。 | Policy 接入 Governance/RuntimeContext；voiceprint、cloud ASR、long-running mic 默认 fail closed，只有明确配置/用户授权后允许。 | 测试：未初始化 governance 时 voiceprint/cloud ASR/wake listening 默认拒绝；显式 gate 开启后才允许。 |
| SPEECH-017 | P1 | Commerce coupling / quota | `Speech.Service.pas:6-10` 直接 uses `DeepBase.Commerce.Permissions` 和 `ASR.Baidu`；`RecognizeCaptured` 在 `202-208` 先 `RequireFeature`，成功后 `ConsumeQuota(FPermissionFeatureCode, 1)` 但不传 request id | Speech 服务层直接耦合 Commerce，并继承 Commerce quota 的非幂等问题；同时 Service facade 默认拉入 Baidu/WinMM，难以作为纯接口包复用。 | 把 entitlement 检查抽象成 `ISpeechPermissionGate`；quota-consuming ASR 调用必须带 request id；Baidu/WinMM 作为 adapter 注入。 | SpeechService contract test：无 Commerce 包也能编译纯服务接口；重复识别提交不会重复消费同一 request id。 |
| SPEECH-018 | P2 | VAD / auto-stop semantics | `Speech.VAD.pas:68-76` `ProcessAll` 每次先 `Reset`；`Speech.Service.pas:192-196` `ShouldAutoStop` 每次对完整 `GetFloatSamples` 调用 `ProcessAll` | 自动停顿检测不是增量流式处理，轮询时会反复重扫全部录音，时间复杂度随录音时长增长；VAD 状态也无法表达“上次处理到哪里”。 | VAD 增加 streaming cursor / ProcessChunk；capture 暴露新增样本或 ring buffer；ShouldAutoStop 只处理增量音频。 | 长录音轮询性能测试；speech -> silence 的停止时间不随录音总时长退化。 |
| SPEECH-019 | P2 | Speech.Intent boundary | `Speech.Intent.pas:50-55` 声称 LLM fallback；`161-165` TODO 后返回 `llm_unavailable`；该单元在 `DeepBaseSpeechCore.dpk:41` 被放进 SpeechCore | Speech 内置 Intent 是规则 parser 占位，且和 `Speech.Types.IIntentParser` 类型不统一；它不应和最后要评审的 IntentClarification 混为一个能力。 | 将 Speech.Intent 标记为 local command parser 或移到最后的 Intent/IC 板块；LLM fallback 未实现前不要暴露为 speech core 默认能力。 | 文档/包检查：SpeechCore 不默认暴露 LLM/IntentClarification 路径；规则 parser 有独立 contract test。 |
| SPEECH-020 | P2 | Test coverage | 主测试 `Tests/DeepBaseTests.dpr:64/229-233` 只接入 `Test.DeepBase.Speech` 和 5 个 Speech 单元；Headless DPR 覆盖 Registry/Runtime/MFCC/DTW/Wake/Intent/Voiceprint，但在 `Tests/Speech/TestSpeechHeadless.dpr` 独立存在；SAPI/WinMM/COM lifecycle 没有主 CI 证据 | 测试覆盖分裂：主 CI 看不到大部分 Speech 包，Headless 又可能成为孤立测试；真实麦克风、COM、包编译和隐私策略缺门禁。 | 将 Headless test 纳入 CI；新增 package compile suite 和 Windows SAPI smoke suite；硬件/麦克风测试可作为 opt-in integration。 | CI 至少跑：package compile、headless logic、fake audio capture、fake SAPI/transport；夜间跑真实 SAPI/WinMM smoke。 |

### 12.3 本轮结论

- Speech 模块目前是“原型能力较多、包和接口未收敛”的状态。最先要校准的是 package map 和 canonical interfaces，否则 ASR/TTS/Wake/Voiceprint 后续都无法被统一 facade、registry 和测试可靠驱动。
- SAPI/Wake/Voiceprint 的文档叙事比实现走得更远：streaming、wake-word grammar、DPAPI 持久化、治理 gate 都还没有闭合，需要先降级为 experimental 或补齐实现。
- 语音涉及麦克风常驻、云端 ASR、声纹生物特征，默认策略必须比普通 features 更保守；当前 policy 和 privacy 口径需要优先调整。
- 性能层面 MFCC/DTW 可以先作为 v1 原型，但必须修正注释、边界语义和基准测试，避免下游把它当作生产级声纹认证。

### 12.4 Speech 后续修复优先级建议

只记录建议，暂不修复。后续若进入修复阶段，建议顺序如下：

1. P1：`SPEECH-001/002/003` 先统一包边界、Core 依赖和 canonical interfaces。
2. P1：`SPEECH-004/005/006/007` 修 registry、facade、runtime、WinMM capture 的线程安全和生命周期。
3. P1：`SPEECH-008/009/010/011/012` 收敛 Baidu secret/token、SAPI streaming/Wake/TTS/COM 风险。
4. P1：`SPEECH-013/016/017` 修 voiceprint privacy、policy governance 和 Commerce quota 耦合。
5. P2：`SPEECH-014/015/018/019/020` 算法、VAD、Speech.Intent 边界和测试矩阵补齐。

---

## 13. 2026-05-14 周边模块第五轮：Governance / OCGS 分板块评审

范围：

- Governance runtime package：`DeepBaseGovernance.dpk`。
- Governance source：`Governance/DeepBase.Governance.*.pas`，含 Types、Interfaces、Model、Runtime、ActionGrid、GateResolver、RouteResolver、JsonLogic、DueChecker、Evidence、Schema、ConfigRegistrar、Lifecycle、Registration、Validation、Seal、Accountability、AI Steering/ViewScope/ProposalQueue。
- Governance tests：`Tests/Governance/ConfigRegistrarPBT.dpr`、`Tests/Governance/DeepBase.Governance.BehaviorMock.pas`、`Tests/Governance/build_pbt.bat`。
- 本轮明确排除：`VCL/DeepBase.VCL.DeepShell.Governance.pas` 及 DeepShell UI 集成；DeepShell、BrowserAutomation、IntentClarification 仍按要求放最后。
- 本轮只评审和记录建议，不修复源码。

### 13.1 Governance 模块总览

| 子板块 | 评分 | 当前判断 |
|--------|------|----------|
| 包边界 | 4.5/10 | Governance 有独立 dpk，但运行包直接 requires `vcl` 和 `DeepBasePersistence`，同时混入 runtime、SQLite store、AI steering、lifecycle 和 config registrar，难以作为纯治理内核复用。 |
| Runtime / ActionGrid | 5/10 | EnterGate、GateResolver、RouteResolver、ActionGrid 的主链路已成形；但执行结果、证据记录、bridge 缺失、dry-run/commit、可用 action 过滤和事务语义还没有收敛。 |
| Gate / Route / JsonLogic | 5/10 | Gate fail-closed 和 JsonLogic 条件路由方向正确；但空 gate 默认 open、路由 fallback 过期、JsonLogic 引擎共享临时对象、错误吞掉等问题会削弱治理可信度。 |
| ConfigDB / SQLite persistence | 4/10 | 存在 ConfigRegistrar、Schema、RouteStore、EvidenceStore 多套存储实现；表结构、枚举存储方式、route 表名和条件存储方式互相不兼容。 |
| Evidence / Audit | 5/10 | 白名单脱敏、失败队列和 async writer 是正确方向；但 shutdown drain、队列满处理、FireDAC 连接线程归属和成功 action 证据链仍有缺口。 |
| Validation / Seal / Accountability | 4.5/10 | 骨架完整，但大量规则和 seal/accountability 能力没有接入 runtime；DueChecker 也没有真正消费 evidence/seal。 |
| AI Steering / ViewScope / Proposal | 4.5/10 | 有自动导出、AI 视图限制和提案队列雏形；但默认 AI 可见、markdown 未转义、提案审批/应用缺少持久化和审计闭环。 |
| 测试可信度 | 4/10 | 只有 ConfigRegistrar standalone PBT 和 BehaviorMock；未见主 DUnit runner 纳入 Governance，runtime/gate/route/evidence/concurrency/schema compatibility 缺少门禁。 |

### 13.2 P0 / P1 / P2 任务清单

| 编号 | 优先级 | 模块 | 证据 | 问题 | 修复建议 | 验证建议 |
|------|--------|------|------|------|----------|----------|
| GOV-001 | P1 | Package boundary | `DeepBaseGovernance.dpk:31-35` requires `rtl/vcl/DeepBaseCore/DeepBasePersistence`；`contains` 同时收录 runtime、SQLite store、AI、Lifecycle、Registration、ConfigRegistrar | Governance runtime 包直接依赖 VCL 和 Persistence，不是纯治理 core；服务端、console、FMX、headless 测试都会被 UI/DB 依赖牵连。 | 拆成 `GovernanceCore/Runtime/PersistenceSQLite/AI/UIAdapter` 或至少 `DeepBaseGovernanceCore` + `DeepBaseGovernancePersistence`；VCL/DeepShell 集成留到 UI 包。 | 包依赖门禁：GovernanceCore 不允许 `vcl`、FireDAC、`DeepBasePersistence`；SQLite adapter 单独编译测试。 |
| GOV-002 | P1 | ConfigDB schema | `Schema.pas:114-134` 使用 `governance_gates` 的 `name/action_keys/conditions` 和 `governance_actions.bridge_keys`；`ConfigRegistrar.pas:95-129` 使用 `display_name/risk_level INTEGER/governance_gate_conditions`；`RouteStore.SQLite.pas:55-80` 使用 `governance_route_rules`，而 `Schema.pas:139-150` 是 `governance_routes` | Governance 至少有三套 schema 口径：Schema helper、ConfigRegistrar、RouteStore。字段名、枚举类型、route 表名、conditions 存储模型不一致，导致不同入口初始化的 DB 不能互相加载。 | 定义唯一 canonical DB schema 和 migration 版本；ConfigRegistrar、Schema helper、RouteStore 都走同一 migration/DAO；旧表只通过 compat loader 迁移。 | Schema compatibility tests：分别用 `EnsureGovernanceSchema`、`TConfigRegistrar`、`TRouteStoreSQLite` 初始化，再互相 `LoadFromDB/ReloadRules`，不得缺表/缺列/字段丢失。 |
| GOV-003 | P1 | ConfigRegistrar relationship | `ConfigRegistrar.pas:369-428` RegisterGate/RegisterAction 分别写 gate/action，但没有把 action 写入 gate 的 `ActionKeys`；`Runtime.pas:119-125` 路由为空时只从 `AvailableActions[0]` 回退；`Schema.pas:532-538` 另一套 loader 才会从 `action_keys` JSON 填 gate actions | Code-first 注册 gate/action 后，gate 到 action 的关系不会自动形成；没有 route 规则时 `EnterGate` 可能得到 `No action resolved`，下游必须手动补关系。 | 在 Registrar 中提供 `BindActionToGate` 或 RegisterAction 自动维护关系表；用独立 `governance_gate_actions` 表替代 JSON/隐式字段；文档不要求下游手改 resolver 内存对象。 | PBT 增加：RegisterGate + RegisterAction(gate) 后，fresh `LoadFromDB` 的 gate 必须含 action key，`EnterGate` 能解析目标 action。 |
| GOV-004 | P1 | Lifecycle / singleton | `Registration.pas:42-59` 已有 `GovernanceLifecycle` 时直接 `Exit`；`Lifecycle.pas:79-80` `FMode/FStarted` 普通字段；`SwitchMode` 在 `264-276` 直接改 mode 并写 DB；全局 `GovernanceLifecycle` 在 `Lifecycle.pas:128` | 注册、启动、模式切换和 shutdown 都没有同步；重复注册不同配置会被静默忽略；并发 `RegisterGovernance/ShutdownGovernance/SwitchMode` 可能拿到半初始化或已释放对象。 | 用 RuntimeContext/IoC 管理 lifecycle；注册重复时校验配置一致或返回错误；状态机加锁，Start/Stop/Shutdown/SwitchMode 定义幂等语义。 | 并发测试：多线程 register/shutdown/switch mode；重复注册不同 DB/setup 必须失败而不是静默忽略。 |
| GOV-005 | P1 | Runtime orchestration / evidence | `Runtime.pas:96` 无保护调用 `FGateResolver.Resolve`；`107` 取 `LFeedback` 后未使用；`130-132` 执行 action；`145-148` `GetAvailableActions` 直接返回全部 action；`Lifecycle.pas:185` 创建 `TActionExecutor(..., nil)`，但 `Runtime` 在 `219-227` 才拿到 `FEvidenceRecorderIntf` | Runtime 构造器不校验必需依赖；反馈信息被丢弃；可用 action 不按 context/gate 过滤；默认 lifecycle 下 `ActionExecutor` 没拿到 recorder，成功 commit 的 action 证据可能不写入，只记录 gate blocked。 | 构造器 fail-fast 校验必需服务；Runtime 负责统一记录 `ActionRun/Evidence`；Feedback 放进 `TActionResult` 或返回结构；`GetAvailableActions` 按 gate/context/due 过滤。 | Runtime contract tests：成功 commit 写 evidence；blocked 返回 feedback；缺关键 resolver 构造失败；不同 context 下 available actions 不同。 |
| GOV-006 | P1 | ActionGrid execution | `ActionGrid.pas:28-29` 字典无锁；`170-207` bridge 链执行；`191-203` 未注册 bridge 被直接跳过；`207-209` bridge count 大于 0 时仍返回 Success；`CanRun` 在 `103-124` 不检查 bridge `CanExecute` | Action 配了不存在的 bridge 时可能“成功但什么都没执行”；多 bridge 执行没有事务/补偿，前一个 bridge 已产生副作用后后一个失败无法回滚；最终成功结果覆盖 bridge 输出。 | 缺 bridge 必须 blocked/fail；`CanRun` 纳入 bridge availability；ActionResult 聚合每个 bridge call；L2+ commit 支持 compensation 或明确不可事务化。 | Tests：未注册 bridge 不能 Success；两个 bridge 第二个失败时记录 partial failure；bridge 输出不被覆盖。 |
| GOV-007 | P1 | Shared model / resolver thread safety | `KeyResolver.pas:20-24/83-104` 多个 `TObjectDictionary` 直接 AddOrSet；`ActionGrid.pas:64-65/78/87/94` 字典直接读写；`Model.pas:38-46/66-76` 暴露 mutable `TObjectList/TList` | 治理模型在运行期注册、reload、AI export、runtime resolve 之间共享可变对象和裸 list，缺少锁或 immutable snapshot，容易出现枚举中修改、悬挂对象或配置半更新。 | 初始化后冻结模型；热更新走 copy-on-write snapshot；公开只返回数组/只读视图；所有 registry/resolver 的写操作进入单线程配置阶段或加锁。 | 并发测试：Reload/Register 与 EnterGate/GetAll/AI export 同时运行，不出现 dictionary/list 异常或半更新结果。 |
| GOV-008 | P1 | GateResolver fail-open | `GateResolver.pas:75-83` 缺 evaluator 时 fail-closed；但 `DetermineState` 在 `97-98` 遇到 `Conditions.Count = 0` 直接 `gsOpen` | 有条件但缺 evaluator 会拒绝，无条件 gate 却默认开放。对治理系统而言，漏配 conditions 很可能是配置错误，不应默认放行高风险 gate。 | 按 gate/action risk 决定默认策略：L0 可 open，L1+ 无条件需要显式 `allow_all` 或 observe 模式；Registrar/Validation 对空条件 gate 给 warning/severe。 | 测试：L2/L3 gate 无条件默认 blocked 或 validation severe；只有显式 allow-all 才 open。 |
| GOV-009 | P1 | RouteResolver correctness | `RouteResolver.pas:40-43` `FJsonLogic/FFallbacks/FLastDecision` 共享状态；`139-141` JsonLogic 异常被吞掉并跳过规则；`187-222` ReloadRules 只 ClearRules 不清 FFallbacks；`207/164-165` TargetType 被复制但 Resolve 只返回 TargetKey | Reload 后旧 fallback 会残留；坏 JsonLogic 配置不会暴露；`LastDecision` 是共享可变记录，不能并发读取；route target type 没进入 runtime 决策，gate/field route 会被当作 action key。 | Reload 时构建新 rules/fallback snapshot 后原子替换；表达式错误记录 validation/evidence；Resolve 返回 typed route decision；去掉共享 LastDecision 或改为每次返回。 | Tests：删除 fallback 后 reload 不再使用；坏表达式产生诊断；rttGate/rttField 不会被当 action 执行；并发 Resolve decision 不串。 |
| GOV-010 | P1 | JsonLogic engine | `JsonLogic.pas:33/101-110` 用实例级 `FManagedResults` 管理返回值；`272-288` ApplyBool/ApplyStr 每次 ClearManaged；`212-263` Apply 可递归创建和 clone；`138-141` RegisterOperator 无锁 | JsonLogic 引擎不是线程安全的；共享 `FManagedResults` 会让并发 Apply 互相清理返回对象；RouteResolver 复用同一个 engine，路由并发时风险放大。 | JsonLogic 设计成无状态 evaluator，或每次 Apply 创建 eval context；自定义 operator 注册只允许初始化阶段或加锁；补齐 JsonLogic 官方语义差异清单。 | 并发 ApplyStr 压力测试；JsonLogic conformance fixture 覆盖 var、missing、and/or、if、数字/字符串比较。 |
| GOV-011 | P1 | Evidence async lifecycle | `EvidenceRecorder.pas:132-142` 创建队列和后台线程；`149-157` 析构时先 `FRunning := False` 再 terminate/wait/free；`257/279` PushItem 返回值未处理；`288-303` worker 循环退出时不 drain；`EvidenceStore.SQLite.pas:149-181` worker 线程直接使用传入 `TFDConnection` | 关闭时队列剩余 evidence 可能丢失；队列满时调用方不知道写入失败；后台线程使用外部 FireDAC connection，和调用线程共享连接会有线程归属风险。 | Shutdown 先 stop accepting，再 drain queue/flush，最后停 worker；PushItem 失败进入 failure callback；EvidenceStore 使用专用连接或 connection provider。 | Tests：LogAction 后立即 Destroy 不丢 evidence；队列满可观测失败；共享 connection 并发访问被禁止或自动隔离。 |
| GOV-012 | P1 | SQLite stores / migrations | `EvidenceStore.SQLite.pas:49-64` 只有 CREATE IF NOT EXISTS；`RouteStore.SQLite.pas:80-86` 用 `INSERT OR REPLACE`；`LoadBySource` 只恢复 `Version/Enabled` 于 `272-273`，`LoadAll` 在 `282-305` 不恢复 risk、fallback、effective/expired、description 等字段 | 持久化不是完整对象 round-trip；schema 演进没有 migration/version 检查；`INSERT OR REPLACE` 可能重建行并重置 metadata；RouteResolver ReloadRules 从 RouteStore 读到的是丢字段规则。 | DAO 必须完整 hydrate/save 所有字段；引入 schema_version/migrations；SQLite upsert 改为 `ON CONFLICT DO UPDATE`，避免 delete+insert 语义。 | RouteStore round-trip 测试覆盖 every field；旧 schema migration 测试；Save 不应改变 created_at/approved_by 等不可变字段。 |
| GOV-013 | P1 | ConfigRegistrar atomicity | `ConfigRegistrar.pas:294-326` ReplaceGateConditions 先 DELETE 再逐条 INSERT；`369-397` RegisterGate 先写 DB 再写内存；`413-428` RegisterAction 同样 DB 和内存分离；未见 StartTransaction/Commit/Rollback | 配置注册不是事务；中途异常会留下 gate 无 conditions、DB 与内存 resolver 不一致，且 LoadFromDB 后状态和当前进程状态不同。 | RegisterGate/RegisterAction/RegisterPurpose 每个 public mutation 包事务；事务提交后再更新 immutable in-memory snapshot，失败回滚并不改变 resolver。 | Fault injection：插入第 N 条 condition 失败后，旧 conditions 和内存状态保持不变。 |
| GOV-014 | P1 | Due / Accountability / Seal wiring | `DueChecker.pas:92-113` 自动生成 `RequireEvidence/RequireAccountability/RequireConfirm/RequireSeal`；但 `CheckRiskLevel` 在 `142-160` 只检查 accountability 和 confirm；`Seal.pas:86-224`、`Accountability.pas:67-297` 未见 Lifecycle/Runtime 接入 | L3 标记 RequireSeal 但执行路径没有 seal 检查；EvidencePolicy/AccountabilityChecker/SealRegistry 是平行骨架，没有纳入 Runtime/DueChecker 的真实决策链。 | 将 DuePolicy 拆成 evidence/accountability/confirm/seal 四个 provider；L2/L3 检查必须调用对应模块；未配置 provider 时按风险 fail-closed。 | Tests：L3 无 seal 被 frozen/blocked；审核通过后才执行；evidence provider 失败时 L1/L2/L3 按策略处理。 |
| GOV-015 | P2 | Validation / PassGate | `Validation.pas:111-143` 注册 INV-1..15；`398-435` INV-8..15 均返回 nil；`CanRelease` 在 `494-497` 只看 severe=0；Lifecycle Start 未见调用 Validation | Validation 有方向但未成为发布门禁；后半规则是空实现，`CanRelease` 可能给出过度乐观结论；运行期也不会因为 validation severe 阻止启动。 | 建立 `GovernanceValidate` 门禁：初始化后必须跑 validation，severe 阻止 enforce mode；补 INV-8..15 或在输出中标记 unsupported。 | CI 增加 validation fixtures：循环 route、unreachable gate、missing feedback/projection/L3 seal 都必须被检测。 |
| GOV-016 | P1 | AI Steering export | `Lifecycle.pas:233/248-250` Start 自动写 `.kiro\steering\governance-model.md`；`SteeringExporter.pas:77-82/99-103/122-126` 直接把 key/name/purpose 拼进 Markdown table；`152-157` 直接写文件 | 来自 DB 的 DisplayName/Purpose/Key 未做 Markdown 转义或 prompt-injection 边界，可能破坏 steering 文件结构或把非预期指令写入 AI 上下文；库启动还会产生副作用文件。 | 转义 `|`、换行、HTML/Markdown 控制字符；导出字段白名单和长度限制；默认不自动写文件，改为显式 export 或 dev mode；输出目录可配置并限制在项目根下。 | Tests：包含 `|`、换行、markdown link、prompt-like 文本的治理对象不会破坏 steering；Start 默认不写文件或可禁用。 |
| GOV-017 | P1 | AI ViewScope / ProposalQueue | `ModelVersion.pas:220` 未配置 visibility 时默认 `vsvVisible`；`ViewScopeEnforcer.pas:86-117` sensitive/tenant map 只在内存；`ProposalQueue.pas:136-174` 提案 Submit/Approve/Apply 只操作内存，Apply 用 proposer 创建 ChangeSet | AI 视图默认可见是 fail-open；敏感和 tenant 规则重启丢失；AI proposal 的人审身份、权限、持久化、审计和变更应用边界都没有闭合。 | AI audience 默认 hidden 或要求显式 allow；ViewScope/sensitive/tenant 持久化并纳入 validation；Proposal Apply 必须记录 reviewer、approval evidence 和权限检查。 | Tests：未配置对象 AI 不可见；重启后 sensitive/tenant 规则仍生效；未审批/无权限 reviewer 不能 Apply。 |
| GOV-018 | P2 | Test coverage | `Tests/Governance/ConfigRegistrarPBT.dpr:1-41` 是 standalone harness；`build_pbt.bat:13-22` 单独编译运行；`rg` 未发现 Governance tests 被 `Tests/DeepBaseTests.dpr` 纳入；DeepShell Governance tests 属 UI 且放最后 | Governance 关键链路没有主 CI 证据：Runtime EnterGate、ActionGrid bridge、Gate/Route/JsonLogic、Evidence async、Lifecycle mode、schema compatibility、concurrency 都缺少门禁。 | 把 Governance core tests 纳入主 runner 或独立 CI job；保留 ConfigRegistrarPBT，但补 runtime contract suite、schema migration suite、concurrency suite。 | CI 至少跑：ConfigRegistrarPBT、Runtime contract、RouteResolver/JsonLogic fixtures、Evidence async flush/drain、Lifecycle observe/enforce switch、package compile。 |

### 13.3 本轮结论

- Governance 是一个有完整愿景的 OCGS 原型：门禁、路由、行为、证据、配置、AI steering、人审、封存都已经有对象模型。但目前更像“多条能力线并行落地”，还没有收敛成一个可信的 runtime contract。
- 最优先的问题不是补功能，而是统一边界：包边界、ConfigDB schema、runtime evidence contract、gate/action/bridge 关系和 lifecycle 状态机必须先定住。
- 当前 enforce 模式不宜作为强治理边界默认发布。尤其是空 gate 默认 open、未注册 bridge 可能 success、成功 action 证据可能不落库、schema 多口径这些问题，会让下游以为自己启用了治理，实际得到的是局部治理。
- AI 相关能力要更保守：steering 文件是进入 AI 上下文的材料，必须做转义和显式导出；ViewScope 不应默认 AI 可见。

### 13.4 Governance 后续修复优先级建议

只记录建议，暂不修复。后续若进入修复阶段，建议顺序如下：

1. P1：`GOV-001/002/003/013` 先统一包边界、DB schema、gate-action 关系和 Registrar 事务。
2. P1：`GOV-005/006/008/009/010/011` 修 Runtime、ActionGrid、Gate/Route/JsonLogic、Evidence 的执行可信度。
3. P1：`GOV-004/007/012` 收敛 lifecycle、shared model snapshot 和 SQLite store round-trip/migration。
4. P1/P2：`GOV-014/015` 把 Due/Accountability/Seal/Validation 接成真正 PassGate。
5. P1/P2：`GOV-016/017/018` 修 AI steering/view scope/proposal 安全边界，并补测试矩阵。

---

## 14. 2026-05-15 最后三板块第一轮：DeepShell 分板块评审

范围：

- DeepShell source：`VCL/DeepBase.VCL.DeepShell.*.pas`，含 Types、Intf、Events、Services、Context、Commands、Recent、Layout、Theme、Localization、Settings、Panels、ToolWindow、Governance、MainForm、Facade。
- Package / tests：`DeepBaseVCL.dpk`、`Tests/Test.DeepBase.VCL.DeepShell.pas`、`Tests/DeepBaseTests.dpr`。
- 本轮按当前工作区源码复核；同事已修复的旧问题只记录为“已修复迹象”，不重复登记为待修 bug。
- 本轮只评审和记录建议，不修复源码；未重跑测试。

### 14.1 已确认的同事修复迹象

- `Commands.pas` 已把后台线程 `Execute` 切到主线程队列，新增 `ExecuteSync`；治理判断也已同时检查 `EnterGate` 返回值和 `LResult.Allowed`。
- `Commands.pas` 的通用 command evidence 已改为 `TJSONObject` 构造，并默认不写 `project_path`，减少 PII 泄漏。
- `Events.pas` 已修后台 publish 的 bus lifetime 和 unsubscribe-before-queue-drain 语义，测试里已有 `BackgroundPublish_DoesNotUAF_AfterBusReleased` 与 `UnsubscribeBeforeQueueDrain_QueuedHandlerDoesNotRun`。
- `Layout.pas` 已新增 `sequence` 和 `RemoteIsNewer`，测试覆盖远端新写跳过、本实例 last-write-wins。
- `MainForm.pas` 已补结构树节点 payload 释放、懒加载 children、`SetObject` 上下文更新；Settings per-page reset 已接入 governance action。

### 14.2 DeepShell 模块总览

| 子板块 | 评分 | 当前判断 |
|--------|------|----------|
| 包边界 | 5/10 | DeepShell 单元收拢在 VCL 包内，但 `DeepBaseVCL.dpk` 仍整体 requires `vclFireDAC` 和 `DeepBaseFeatures`，桌面壳最小依赖不清晰。 |
| 命令 / 治理 | 6/10 | 主线程执行和 gate 判断已明显收敛；但命令风险清单、per-page evidence JSON、默认 audit-only governance 仍需要校准。 |
| EventBus / lifecycle | 6/10 | UAF 和 unsubscribe 语义已有回归；仍缺 drain/shutdown、异常诊断和队列刷新契约。 |
| Layout / settings | 6/10 | 多实例写入保护有进展；project key、事务化 store、错误展示可替换性仍不足。 |
| Theme / locale / status | 5/10 | 基础服务可用；UI 线程派发、status sanitizer fail-safe、progress event 语义仍需收敛。 |
| 测试可信度 | 6/10 | DeepShell 测试已经覆盖 event/command/layout/lifecycle 多个 bug；仍缺真实 MainForm 菜单刷新、theme/locale 跨线程、settings error surface 等测试。 |

### 14.3 P0 / P1 / P2 任务清单

| 编号 | 优先级 | 模块 | 证据 | 当前问题 | 修复建议 | 验证建议 |
|------|--------|------|------|----------|----------|----------|
| DSHELL-001 | P1 | Package boundary | `DeepBaseVCL.dpk:11/15` requires `vclFireDAC`、`DeepBaseFeatures`，同时 contains `VCL/DeepBase.VCL.DeepShell.*` | DeepShell 作为桌面壳被整个 VCL 包的 DB/Features 依赖拖住，无法作为轻量 shell core 或 headless UI contract 使用。 | 拆出 `DeepBaseVCLShellCore` 或至少把 DeepShell core 单元与需要 FireDAC/Features 的 adapter 分包；VCL 包只聚合。 | 包依赖门禁：Shell core 不允许 FireDAC、LLM、Browser、Persistence；VCL 聚合包单独编译。 |
| DSHELL-002 | P1 | Service registry | `Services.pas:90` `SupportsCapability` 注释为 “capability == service id” | capability 模型仍是 MVP，服务 id 和能力 id 混用后无法表达一个 service 支持多个能力、版本、可选权限或降级能力。 | 给 service metadata 增加 capabilities 数组、version、risk、owner；`SupportsCapability` 按 metadata 判断。 | 注册一个 service 暴露两个 capabilities；禁用其中一个 capability 不影响 service lookup。 |
| DSHELL-003 | P1 | EventBus diagnostics / shutdown | `Events.pas:145/225-226` handler 异常被吞；`230` 后台 publish 只 `TThread.Queue`，接口无 drain/flush/shutdown | 同事已修 UAF/取消订阅，但事件系统仍无法诊断坏 handler，也不能在关闭前确认队列清空。 | 增加 `OnDispatchError` 或 status logger；增加 `Drain/Flush/Shutdown`，关闭后拒绝新 publish。 | 测试：坏 handler 产生诊断；Shutdown 后 publish 返回失败；Drain 后 queued handler 全部处理完。 |
| DSHELL-004 | P1 | Settings governance evidence | `MainForm.pas:1566-1567` per-page restore defaults 用 `Format('{"command_id":"%s","page_id":"%s","risk_level":1}', ...)` 拼 JSON | 通用 command evidence 已用 `TJSONObject`，但 Settings per-page reset 仍手拼 JSON；`PageId` 含引号/反斜杠会破坏 evidence 或绕过解析。 | 改为 `TJSONObject` 构造 per-page evidence；统一走 `BuildContextJson` 扩展字段。 | 测试：`PageId='a"b\\c'` 时 governance 收到合法 JSON。 |
| DSHELL-005 | P1 | Command risk manifest | `MainForm.pas:977/1023/1034/1042` 注册 Exit、ResetLayout、ClearRecent、ClearLog；`1057-1063` 只有 `CMD_SETTINGS_DEFAULTS` 设置 `RiskLevel/GateKey` | 内置命令缺少统一风险清单；清日志、清最近项目、重置布局、退出应用这类 destructive/interrupting 操作默认不进 gate。 | 建立内置命令 risk manifest：clear/reset/exit 至少 L1/L2；所有 destructive command 必须有 GateKey、PurposeKey、audit event。 | 测试：上述命令在 fake governance deny 时 handler 不执行并发布 rejected event。 |
| DSHELL-006 | P1 | Default governance | `MainForm.pas:337` 默认 `TShellAuditOnlyGovernanceService`；`Governance.pas:10` 注释说明 observe-style default allows | 默认服务是 audit-only，容易让下游误以为 shell 已启用强治理。 | 默认模式显式命名为 observe；enforce 需要外部注入；UI/status 标出当前治理模式。 | 测试：未注入强治理时 L2+ destructive command 不应宣称 enforce；注入 enforce 后按 gate 拒绝。 |
| DSHELL-007 | P1 | Status sanitizer / event kind | `Panels.pas:303-323` sanitizer 异常回退原文；`291/370` progress 映射为 `sekTaskStarted` | sanitizer 本身出错时会输出未脱敏原文；progress 更新和 task started 混用会让订阅者重复创建任务。 | sanitizer 失败时输出固定占位和诊断，不输出 raw；新增 `sekTaskProgress` 或用独立 progress payload。 | 测试：抛异常 sanitizer 不泄露 token；连续 Progress 事件不会被当作多个 task started。 |
| DSHELL-008 | P1 | Layout key / store atomicity | `Layout.pas:285` `ProjectKey := 'shell.layout.project.' + AProjectId`；`RemoteIsNewer` 注释说明跨实例同 tick 仍依赖 store | `AProjectId` 未做 key escaping；多实例保护仍不是事务化 CAS，非内存 store 下仍可能 lost update。 | 对 project id 做 namespace-safe encoding；DB/settings store 增加 compare-and-swap 或 versioned write。 | 测试：project id 含 `.`、`/`、换行时不污染其他 key；并发 save 只有新版本成功。 |
| DSHELL-009 | P2 | Theme / localization thread affinity | `Theme.pas:97`、`Localization.pas:178` 修改后同步调用 subscribers | 后台线程调用 ApplyTheme/SetLocale 时，订阅者可能直接触碰 VCL 控件，存在 UI 线程风险。 | 引入 shell dispatcher；默认在主线程派发 UI subscribers，非 UI subscriber 可选择 inline。 | 测试：后台调用 ApplyTheme/SetLocale，handler 运行在主线程。 |
| DSHELL-010 | P2 | Settings error surface | `Settings.pas:334/349/387/394` 仍直接 `ShowMessage` | Shell 框架层直接弹框，host 无法统一接管错误展示、日志、自动化测试和无 UI 模式。 | 注入 `IUserNotification` 或复用 status manager；dialog 只返回错误或发布 status。 | 测试：fake notifier 捕获 apply/defaults 错误；无 UI 测试不弹系统对话框。 |
| DSHELL-011 | P2 | Menu state refresh | `Commands.pas:263-278` `UpdateCommandState` 只更新 command 字典；`MainForm.pas:1248-1295` 菜单只在 `RebuildMainMenu` 时重建 | 运行期 Enable/Visible 改变后已有菜单项可能保持旧状态。 | command manager 发布 state changed event，MainForm 增量刷新菜单项或自动 rebuild。 | 测试：`UpdateCommandState(false,false)` 后现有菜单项立即 disabled/hidden。 |
| DSHELL-012 | P2 | Test coverage | `Tests/Test.DeepBase.VCL.DeepShell.pas` 已覆盖 24 项左右 event/command/layout/lifecycle；但未见 settings JSON escape、theme/locale background dispatch、menu refresh、default governance mode 测试 | 当前新增测试能证明部分 bug 已修，但还不足以守住 remaining shell contract。 | 补 targeted regression，不需要先扩大到 UI 自动化；MainForm 真实菜单可用 DUnitX + VCL 控件实例测试。 | CI 增加 DeepShell targeted suite，并在主 runner 中稳定执行。 |

### 14.4 DeepShell 后续修复优先级建议

只记录建议，暂不修复。后续若进入修复阶段，建议顺序如下：

1. P1：`DSHELL-004/005/006/007` 先修治理 evidence、命令风险和 status 脱敏。
2. P1：`DSHELL-001/002/003/008` 收敛包边界、capability 模型、EventBus lifecycle、layout store。
3. P2：`DSHELL-009/010/011/012` 补 UI 派发、通知抽象、菜单刷新和测试缺口。

---

## 15. 2026-05-15 最后三板块第二轮：BrowserAutomation 分板块评审

范围：

- Browser source：`Features/DeepBase.Browser*.pas`、`Features/DeepBase.BrowserAutomation.pas`。
- Package / docs / tests：`DeepBaseFeatures.dpk`、`docs/52.extend.BrowserAutomation接入指南.md`、`Tests/Test.DeepBase.Browser*.pas`、`Tests/DeepBaseTests.dpr`。
- 本轮按当前工作区源码复核；BrowserAutomation 已有大量同事修复痕迹，本节只登记当前仍残留的问题。
- 本轮只评审和记录建议，不修复源码；未重跑测试。

### 15.1 已确认的同事修复迹象

- `Engine.WebView2.pas` 已加入 per-call CDP routing、导航完成事件、Navigate/Screenshot 互斥、主线程 COM 调用、message pump、WebMessage handler、owner provider、global loader cleanup。
- `CDP.pas` 已补 selector/JSON escape、session snapshot、callback exception 转 error。
- `ResponseWaiter.pas` 已有 atomic waiting flag、函数式 template builder、注入前注册 message handler、取消时清 handler。
- `Recovery.pas` 已把长耗时 recovery 移到锁外，并补 factory recreate / callback / best-effort integration tests。
- `WindowPool.pas` 已把 slow factory 调用移到锁外，并区分 release-to-pool 与 close。
- `Tests/DeepBaseTests.dpr` 已纳入 BrowserAutomation、Recovery integration、Selectors integration、ResponseWaiter、ScriptStore、WindowPool、CDP、Service 等测试单元。

### 15.2 BrowserAutomation 模块总览

| 子板块 | 评分 | 当前判断 |
|--------|------|----------|
| 包边界 | 4.5/10 | Browser 仍在巨大 `DeepBaseFeatures` 包内；默认 WebView2 实现文档化但不在 dpk 中，发布路径不闭合。 |
| WebView2 engine | 6/10 | 主线程/并发修复明显；nil owner、防御性 timeout、screenshot 超时策略、真实 WebView2 smoke 仍缺。 |
| Script / Runner contract | 4.5/10 | Runner 期望结构化结果，但 builtin ScriptStore 仍返回 void/string，ScriptStore-first 会激活旧 contract bug。 |
| ResponseWaiter / messaging | 5/10 | 已有 message handler 桥；但 postMessage 字符串与 WebView2 JSON 获取语义仍可能不匹配，多 waiter 也没有 multiplex。 |
| Registry / pooling / recovery | 5.5/10 | 多项锁粒度已改善；registry lock 内调用 factory/availability、pool VCL 依赖、recovery 重入仍有风险。 |
| 测试可信度 | 6/10 | 单元和 integration 数量增加；仍缺真实 WebView2、脚本 contract、postMessage payload 和并发池化测试。 |

### 15.3 P0 / P1 / P2 任务清单

| 编号 | 优先级 | 模块 | 证据 | 当前问题 | 修复建议 | 验证建议 |
|------|--------|------|------|----------|----------|----------|
| BROWSER-001 | P1 | Package boundary | `DeepBaseFeatures.dpk:84-98` 收录 Browser 多数单元但没有 `DeepBase.Browser.Engine.WebView2`；`docs/52...:32/43` 明确默认 WebView2 engine 并通过 uses 自动注册 | 文档承诺的默认后端不在发布包内；下游按文档接入可能编译不到默认实现，或必须手动加未声明依赖。 | 拆 `DeepBaseBrowserCore`、`DeepBaseBrowserWebView2`；Features 只聚合 core facade；文档按包说明 uses 和 conditional define。 | 包编译测试：core 无 WebView2；WebView2 包在 `USE_WEBVIEW2` 下可编译并自动注册。 |
| BROWSER-002 | P1 | WebView2 owner / VCL coupling | `Engine.WebView2.pas:25` uses `Vcl.Forms`；`251` 仍 `FBrowser.CreateBrowser(AOwner.Handle)` | Factory path 已校验 owner provider，但 public constructor 仍可传 nil 后 AV；engine 与 VCL 控件强绑定，不能作为非 UI/headless backend。 | constructor 显式拒绝 nil owner；将 VCL host 作为 WebView2 adapter，不放在 core；公开 API 只暴露 factory。 | 测试：nil owner 抛清晰异常；core package 不 uses VCL；factory owner nil 有诊断。 |
| BROWSER-003 | P1 | Timeout semantics | `Engine.WebView2.pas:443` `Cardinal(ATimeoutMs)`；`727` screenshot 固定 `5000` | 负 timeout 会变成超长等待；screenshot 不接受调用方超时策略，也不能和 runner per-call timeout 对齐。 | 统一 `NormalizeTimeout`：`<0` 表示 infinite、`0` default、正数原值；screenshot 增加 timeout 参数或从 session config 取。 | 测试：`-1/0/1` 三类 timeout 行为明确；screenshot timeout 可配置。 |
| BROWSER-004 | P1 | Registry locking | `Registry.pas:221` Discover 在锁内调用 `IsAvailableFunc()`；`301` 指定 backend 时在锁内调用 `FactoryFunc()` | availability/factory 可能执行 COM、UI、磁盘、注册表或用户代码；锁内调用会阻塞 registry 操作，也有重入死锁风险。 | 锁内复制 backend snapshot，锁外执行 availability/factory；CreateSession 指定 backend 先取 factory 再释放锁调用。 | 慢 factory/availability 测试：不阻塞 Enable/Disable/Discover；factory 重入 registry 不死锁。 |
| BROWSER-005 | P1 | ScriptStore vs Runner contract | `ScriptStore.pas:189/192-198` builtin click/input/get_text 返回 void/string；`BrowserAutomation.pas:645/664/692` 优先 ScriptStore；runner 在 `845/863/881` 期望 `success/found/text` 等结构 | ScriptStore 激活时会绕过 fallback 的结构化脚本，导致 click/input 被误判失败，get_text 空字符串和 not-found 不可区分。 | 更新 builtin templates 为 canonical structured contract；ScriptStore 替换脚本时做 contract validation 或版本号。 | 测试：默认 ScriptStore 下 click/input/get_text runner 全通过；自定义脚本缺 `success/found` 时被拒绝或降级。 |
| BROWSER-006 | P1 | ResponseWaiter message payload | `ResponseWaiter.pas:152` JS `postMessage(msg)` 传字符串；`Engine.WebView2.pas:362` 用 `Get_WebMessageAsJson`；`ResponseWaiter.pas:227-229` 直接按 JSON object parse；`291` ExecuteScript 成功后才 `SetWaitingFlag(True)` | WebView2 对 JS string 的 JSON 可能是 JSON string literal，Delphi 侧期望 object；极快回调可能先到，后续再置 waiting=true；单 session 只有一个 global handler，多 waiter 会互相覆盖。 | JS 改为 post object 或 Delphi 侧 unwrap `TJSONString`；注入前设置 waiting=true，失败再回滚；message handler 做 waiter id multiplex。 | 真实 WebView2 test：postMessage string/object 都可解析；两个 waiter 并发互不覆盖；极快 success 不留下 waiting=true。 |
| BROWSER-007 | P1 | CDP async lifecycle | `CDP.pas:771` `WaitForSelector` 创建匿名线程，闭包继续访问 `FCDP`；`FreeOnTerminate=True` | 同事已补 callback exception，但线程没有 cancel/join，`TAutomationCDP` 或 session 销毁后仍可能访问释放对象。 | 引入 operation token/cancellation；对象析构等待 worker drain；或统一走 scheduler/async abstraction。 | 测试：WaitForSelector 未完成时 Destroy CDP/session，不发生 UAF，callback 返回 cancelled。 |
| BROWSER-008 | P1 | WindowPool boundary / validation | `WindowPool.pas:20/113/242` uses `Winapi.Windows/Vcl.Forms/Screen.WorkAreaRect`；`222` constructor 不校验 factory/max size；`380` unknown release 也发布 `betWindowReleased`；`501` ApplyLayout 只改 config | Browser core 被 VCL Screen 绑定；无效 pool size/factory 会晚期失败；Release 未知 id 产生虚假事件；ApplyLayout 没有真正移动窗口。 | Pool core 只管理 sessions；VCL layout adapter 单独实现；constructor fail-fast；Release 返回 Boolean；ApplyLayout 调 backend window move/resize 能力。 | 测试：nil factory/0 size 抛异常；unknown release 不发 event；ApplyLayout 对 fake window backend 收到 move/resize。 |
| BROWSER-009 | P1 | Recovery concurrency | `Recovery.pas:91-95/341-358` OnSessionRebuilt/SessionFactory/Config 直接读写；`476-590` DoRecovery 无 per-session in-progress guard | recovery 锁粒度已有改进，但同一 session 可并发触发多次 recovery，factory/callback/config 可被其他线程中途替换。 | 为每个 session 增加 recovering flag；callback/factory/config 用锁内 snapshot；配置只允许启动前修改或 copy-on-write。 | 并发 TriggerRecovery 同一 session 只执行一次；修改 callback 不影响已开始 recovery。 |
| BROWSER-010 | P1 | Session state reads | `Session.pas:379/385` `CanFire/GetPermittedTriggers` 直接访问 state machine；`NotifyError` 等写路径加锁 | read/write 锁语义不一致，状态查询和 transition 并发时可能读到中间状态或触发 state machine 内部竞态。 | 所有 state machine 访问走 `FLock` 或 immutable snapshot。 | 多线程 Notify/CanFire/GetPermittedTriggers 压测不报错且结果一致。 |
| BROWSER-011 | P2 | Selector JSON / self-heal parsing | `Selectors.pas:169` event JSON 拼接 selector name；`229` 直接 `ParseJSONValue(LResult)` 后要求 `TJSONArray` | selector name 未 JSON escape；如果 EvaluateScript unwrap 后返回 JSON string literal，self-heal 结果可能是 `TJSONString` 而不是 `TJSONArray`。 | 用 `TJSONObject` 构造 event data；self-heal parser 支持 string literal unwrap 或让 JS 直接返回 array。 | 测试：selector name 含引号/反斜杠时 event JSON 合法；WebView2 raw result 为 string literal 也能 heal。 |
| BROWSER-012 | P2 | Test coverage | `Tests/DeepBaseTests.dpr:50-60/217-225` 纳入多项 Browser tests；但未见真实 WebView2 compile/smoke，ResponseWaiter 只验证 JS 包含 `postMessage`，ScriptStore 未验证 runner contract | 当前 tests 证明部分 bug 已修，但关键发布路径和真实浏览器消息语义还没守住。 | 增加 opt-in WebView2 smoke；默认 CI 加 pure contract tests；夜间跑真实 browser。 | CI：ScriptStore canonical contract、postMessage payload fixture、多 waiter、WindowPool concurrent acquire、WebView2 package compile。 |

### 15.4 BrowserAutomation 后续修复优先级建议

只记录建议，暂不修复。后续若进入修复阶段，建议顺序如下：

1. P1：`BROWSER-005/006` 先修脚本 contract 和 ResponseWaiter 真实消息语义，因为它们直接影响自动化成功率。
2. P1：`BROWSER-001/002/003/004` 收敛默认 WebView2 发布路径、owner/timeout 和 registry 锁。
3. P1：`BROWSER-007/008/009/010` 修 CDP lifecycle、pool 边界、recovery 重入和 session state 读锁。
4. P2：`BROWSER-011/012` 补 selector JSON/self-heal 和测试矩阵。

---

## 16. 2026-05-15 最后三板块第三轮：IntentClarification 分板块评审

范围：

- IntentClarification source：`Features/DeepBase.IntentClarification*.pas`，含 facade、Types、Interfaces、Engine、IoC、Providers L0-L4、Session/FSM、Router、SignalDetector、Budget、Exit、Storage、Metrics、FeatureConfig、Templates、Validation、LLMResilience、Anticipation、Degradation、Moments、Rapport、Registration。
- Package / docs / tests：`DeepBaseFeatures.dpk`、`docs/51.extend.IntentClarification接入指南.md`、`Tests/Test.DeepBase.IntentClarification*.pas`、`Tests/DeepBaseTests.dpr`。
- 本轮按当前工作区源码复核；同事已修复部分并发/容错 bug，但 facade/API、会话一致性、预算、存储和 provider 状态仍需校准。
- 本轮只评审和记录建议，不修复源码；未重跑测试。

### 16.1 已确认的同事修复迹象

- `Engine.pas` 已给 `HandleExit` 和 budget exhausted 两处 `FSessions.AddOrSetValue` 补锁。
- `LLMResilience.pas` 的 `MakeFailureResult` 已填 `ErrorMessage` 和 `ErrorCode`。
- `Storage.pas` 的 `JsonToRapport` 已对缺字段和 `boundaries` 类型做 nil/type guard。
- `Types.pas` 的 `TSessionCheckpoint.FromJson` 已对缺失或非 object 的 `sessionState` 做保护。
- `IoC.pas` 的容器路径确实注册 `IClarificationEngine -> TClarificationEngine`，integration test 走的是 IoC path，不是旧 facade path。

### 16.2 IntentClarification 模块总览

| 子板块 | 评分 | 当前判断 |
|--------|------|----------|
| API / facade | 3/10 | IoC path 可用，但 `DeepBase.IntentClarification.pas` 仍定义空接口和 facade，文档示例走的入口会误导下游。 |
| Engine / session | 4.5/10 | lifecycle 基本可跑；StartRequest 字段、per-session 并发、history/token/provider 锁、EventBus 默认语义未闭合。 |
| Provider L0-L4 | 4.5/10 | 分层概念清晰；L1 slots、L2/L3 provider 共享状态、L4 预算/超时/取消、prompt 边界仍有明显风险。 |
| Budget / feature config | 4/10 | 有 Budget/FeatureConfig 类，但 Engine 使用默认预算，未消费 override/config/feature flags。 |
| Persistence / privacy | 4/10 | Storage 可保存基本数据；但 FireDAC 依赖重、schema/migration 简化、checkpoint 不完整、隐私数据未加密。 |
| Resilience / metrics / rapport | 4.5/10 | LLM resilience 有 circuit breaker 形状；timeout 不强制，stream/image bypass，metrics/rapport 未真正接入 engine。 |
| 测试可信度 | 5/10 | 主 runner 纳入基础/集成测试；仍缺 facade path、domain slots、budget override、并发 submit、storage privacy/migration 等关键门禁。 |

### 16.3 P0 / P1 / P2 任务清单

| 编号 | 优先级 | 模块 | 证据 | 当前问题 | 修复建议 | 验证建议 |
|------|--------|------|------|----------|----------|----------|
| IC-001 | P0 | Public facade / interface | `DeepBase.IntentClarification.pas:92/157/813-825` 定义空 `IClarificationEngine` 和空壳 `TClarificationEngineFacade`；`Interfaces.pas:178-190` 是完整接口；`docs/51...:91-94` 示例用 `TIntentClarifier.CreateEngineWithPreset` 后注册 adapter | facade 入口返回的不是真实 engine；与完整接口同 GUID/同名但方法集不同，可能导致编译歧义、QueryInterface/vtable 风险或下游拿到无法工作的对象。 | 删除重复空接口；`TIntentClarifier.CreateEngine*` 返回 `Interfaces.IClarificationEngine` 的真实 `TClarificationEngine` 或转发到 IoC path；文档改为唯一入口。 | 测试：文档示例原样编译并能 StartSession/SubmitInput/RegisterDomainAdapter；facade 返回对象支持完整接口。 |
| IC-002 | P1 | StartSession request contract | `Interfaces.pas:25-29` 定义 `InitialInput/Template/BudgetOverride/HasBudgetOverride`；`Engine.pas:603-642` StartSession 只写 user/domain/intent 等基础字段；`Engine.pas:203-204` 默认 EventBus=nil | StartRequest 的关键字段被忽略；默认 engine 不发布事件；Template/BudgetOverride 对会话没有影响。 | StartSession 消费 initial input、template、budget override；保存到 session context；默认 EventBus 由 IoC/RuntimeContext 注入或明确 documented nil。 | 测试：InitialInput 进入首轮/历史；Template 影响 max level/posture；BudgetOverride 改变 budget exit；默认事件策略明确。 |
| IC-003 | P1 | Engine concurrency | `Engine.pas:252/267/278/291/299` `FProviders/FHistory/FTokenUsage` 读写无锁；SubmitInput 只短暂锁读 session，后续整轮无 per-session lock | 同一 session 并发 SubmitInput 可能丢 turn、乱 history/token；RegisterProvider/FindProvider 并发可能枚举时修改。 | 每个 session 串行化 turn；`FHistory/FTokenUsage/FProviders` 加锁或 copy-on-write；注册 provider 只允许启动阶段。 | 并发 SubmitInput 100 次 turn 顺序不丢；运行中 RegisterProvider 被拒绝或安全 snapshot。 |
| IC-004 | P1 | Provider routing / degradation | `Interfaces.pas:226` 有 `CanHandle`；`Engine.pas:252` `FindProvider` 只按 level；`731-733` LLM provider 且 `FLLM=nil` 时直接置 nil；`Degradation.pas` 未被 Engine 调用 | Provider 自身能力条件被忽略；缺 LLM 时不走 provider 的 degraded result 或统一 DegradationHandler，而是通用 rule fallback。 | `FindProvider` 接受 context 并调用 `CanHandle`；RequiresLLM 且无 LLM 时调用 provider degraded path 或统一 `TDegradationHandler`。 | 测试：L2/L3/L4 无 LLM 返回 provider-specific degradation；CanHandle=false 的 provider 不被调用。 |
| IC-005 | P1 | Budget / FeatureConfig | `Engine.pas:757-759` 每轮 `LBudgetConfig := TBudgetConfig.Default`；`FeatureConfig.pas:143-155` Reload 只是注释，不读 Config/FeatureFlags | 模板、feature flags、StartRequest override 都不会影响预算、超时、max level；配置类与 engine 脱节。 | Engine 注入 `TICFeatureConfig` 和 per-session budget config；StartSession freeze budget snapshot；Reload 读 DeepBase.Config/FeatureFlags。 | 测试：预算覆盖 max turns=1 第二轮退出；关闭 L4 后 router 不进入 L4。 |
| IC-006 | P1 | L1 slots / domain adapter | `Interfaces.pas:205` `IDomainAdapter.GetPresetSlots`；`Provider.L1.pas:113-114` 注释说 engine 会填 slots；Engine 未见填充 | L1 slot provider 基本拿不到领域预设 slots，意图澄清的核心“槽位追问”无法通过 engine path 工作。 | Engine 在 BuildProcessingContext 或 L1 request 构造时调用 domain adapter slots；slots 进入 `TIntentClarificationRequest`。 | 测试：domain adapter 返回 required slot，首次 SubmitInput 追问该 slot。 |
| IC-007 | P1 | Provider instance state | `Provider.L2.pas:28/134/269-285` `FDeniedHypotheses` 是 provider 实例级；`Provider.L3.pas:29-30/118-139/269-289` `FCurrentExpert/FExpertSelected` 是实例级 | IoC 注册 provider singleton 时，多用户/多 session 的 denied hypotheses 和 current expert 会互相污染，且无锁。 | provider 变 stateless，session state 保存 hypotheses/expert；或按 session id 建状态表并加锁/清理。 | 测试：两个 session 分别 deny/switch expert，不互相影响。 |
| IC-008 | P1 | L4 LLM orchestration / prompt boundary | `Provider.L4.pas:212/244` 顺序多次 LLM 调用；`Provider.L2.pas:101-104`、`Provider.L3.pas:145-160` prompts 直接拼 user input/history | L4 没有统一 token budget、timeout、cancel、partial failure 策略；prompt 直接拼接用户内容和历史，缺边界标记/注入防护。 | 给 L4 引入 per-turn budget/cancel token；专家失败不参与合成或标记；prompt 使用结构化消息和明确 untrusted input boundary。 | 测试：某专家失败不污染 synthesis；超预算取消后返回可解释 degraded result；prompt fixtures 保留边界。 |
| IC-009 | P1 | LLM resilience semantics | `LLMResilience.pas:270-272` 超时只记录 slow log；`296` retry `Sleep` 不可取消；`378-380` GenerateImage 直接透传；streaming 直接 passthrough 并立即 `RecordSuccess` | error fields 已修，但 timeout 不强制，retry 无取消，stream/image 不走统一 circuit breaker/timeout 语义。 | 用 cancellable future/transport timeout；stream 成功以结束回调为准；image generation 也进 circuit breaker/retry 或明确不支持。 | 测试：超时调用被取消并计 failure；stream 中途 error 计 failure；GenerateImage 连续失败打开 circuit。 |
| IC-010 | P1 | Storage boundary / schema | `Storage.pas:2/26/28/42` FireDAC + DB.Factory；`118` EnsureInitialized 无锁；`183/241` `INSERT OR REPLACE`；`356-395` migration 只是占位 | IC 被 `DeepBaseFeatures.dpk` 收录时强拉 FireDAC/DB；懒初始化并发风险；SQLite replace 语义可能重建行；迁移未接入统一 schema 体系。 | 拆 `IntentClarificationPersistenceFireDAC`；EnsureInitialized 加锁；改 canonical upsert；接入 migration registry/version。 | 测试：Features core 无 FireDAC；并发 Save/Load 初始化一次；schema version migration 可重跑。 |
| IC-011 | P1 | Checkpoint completeness / privacy | `Types.pas:294-325` ToJson 只保存基础 `sessionState/resumeHint`；`Session.pas:339-349` checkpoint 中 `TurnHistory/OpenQuestions` 置 nil；Storage 保存 rapport/session 明文 | checkpoint 不能完整恢复 turn history、open questions、rapport snapshot；IC 持有用户上下文和关系画像，明文落库不符合隐私预期。 | 完整序列化 checkpoint；隐私字段加密/脱敏；增加 retention/delete/audit。 | round-trip 测试：保存再恢复 history/open questions/rapport 不丢；DB 中敏感字段非明文。 |
| IC-012 | P1 | Session model duplication | `Engine.pas` 自管 `FSessions/FHistory/FTokenUsage`；`Session.pas` 另有 `TSessionManager`；`SessionFSM.pas` 另有 FSM；`Session.pas:411-421` 枚举 `FSessions` 时 `AddOrSetValue` 修改字典 | Engine、SessionManager、FSM 三套会话状态并行，行为难以一致；SuspendIdleSessions 还有枚举期间修改字典风险。 | 选择一个 canonical session manager/FSM；Engine 只调用它；枚举时收集 keys 后再更新。 | 测试：Engine lifecycle 与 SessionManager/FSM 状态一致；SuspendIdleSessions 不抛 dictionary modified。 |
| IC-013 | P2 | Metrics / Rapport / config integration | `Metrics.pas` 计数器无锁；Engine 未调用 metrics；`Rapport.pas:105-128` 内存 profile 字典无锁且未接 Storage；`FeatureConfig.Reload` 不读真实配置 | 辅助能力存在但没有进入主运行合同，容易被下游误认为已生产化。 | metrics 用 atomic/lock 并在 Engine turn/session 中记录；Rapport 接 storage repository；FeatureConfig 接 Config/FeatureFlags。 | 测试：一次 turn 更新 metrics；Rapport 重启可恢复；Reload 后配置生效。 |
| IC-014 | P2 | Test coverage | `Tests/DeepBaseTests.dpr:44-45/178-206` 已纳入 IC basic/integration；Integration 走 IoC path；未覆盖 facade 文档入口、BudgetOverride、GetPresetSlots、provider state isolation、storage privacy/migration、并发 submit | 当前 tests 证明 IoC path 可跑，但最危险的下游入口和生产语义没有门禁。 | 把 docs 示例变成 compile/run test；补 engine contract、provider isolation、storage migration/privacy、concurrency suite。 | CI 至少跑：facade path、budget override、slots、parallel submit、checkpoint round-trip、storage migration。 |

### 16.4 IntentClarification 后续修复优先级建议

只记录建议，暂不修复。后续若进入修复阶段，建议顺序如下：

1. P0：`IC-001` 先修 public facade 和重复接口，这是下游接入的硬阻塞。
2. P1：`IC-002/003/004/005/006` 收敛 Engine request contract、并发、provider routing、budget/config、domain slots。
3. P1：`IC-007/008/009` 修 provider state isolation、L4 orchestration 和 LLM resilience。
4. P1：`IC-010/011/012` 收敛 persistence/schema/privacy、checkpoint 和 session canonical model。
5. P2：`IC-013/014` 接入 metrics/rapport/config，并补足测试矩阵。
