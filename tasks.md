# deepBase 开发任务
> **最后更新**: 2026-07-09
> **本次更新**: 完成 OPT-REFACTOR-001 — LLM.pas 模板管理提取架构重构。新建 `Core/DeepBase.LLM.PromptTemplateManager.pas` (TLLMPromptTemplateManager 类, 迁入 9 方法 + 2 辅助), `TDeepBaseLLM` 持 `FPromptTemplateMgr` 字段, 9 公开模板方法改一行委托, 门面签名不变 (调用方 Persistence/VCL/FMX/BillingClient 零改动)。Win64 编译通过 (329078 行), 全量 DUnitX 4206/4203/0/0/0 (无 216 无回归)。DeepBaseLLM.dpk/.dproj 已加 contains。另 BUG-438 (Tests 全套 Runtime 216) 已修 (WorkerQueue 异常对象生命周期悬垂 → Clone 模式), 派生 BUG-439 待办。
> **前次更新**: 二次复核 OPT-P2-002 三大文件拆分项 — 逐文件结构+引用追踪证明 2026-07-10 更正仍基于错误前提: Schema.pas 是纯 SQL DDL 常量单元 (无 Table/Column/Index/Constraint 类型, Diagnose 直接引用 20+ 单常量, 拆分只增耦合 → 标记不适用); Math.pas 已拆分完成 (Geometry/Random/Interpolation/Statistics 四子单元 + 527 行门面 → 标记完成); LLM.pas 是门面单元, 剩余 1778 行为 TDeepBaseLLM 单体类, 真正拆分需提取模板管理为独立类属架构重构 (影响 Persistence/VCL/FMX 调用方) → 拆出独立待办 OPT-REFACTOR-001。零代码改动, 仅文档对齐。REVIEW5-R3 全闭环 (53/53, BUG-386~437)。
> **项目状态**: 框架主体已完成。数据平台 v0.7 12 单元已落地。三专家审阅 42 项全部完成 (已归档)。第二轮五专家审阅 (REVIEW5-R2, 2026-07-06) **本轮修复 23 项已全部归档** history.md (BUG-363~BUG-385 + DATA2-005/006 补录), 详见 history.md「2026-07-06 REVIEW5-R2」段。WebAPI 可观测性模块已落地 (33 新测)。商业化模块增强: 微信支付 V3 回调验证 (9 新测)、权益 Tier/MaxDevices/OfflineGraceDays、正确性修复 4 项、测试覆盖补齐 11 验证路径。CI 单元全绿 (4084 total, 0 failed, 33 预存 CM 环境错误, STUB/编码门禁 PASSED); 编码门禁 0 硬违反, ~224 软告警。
> **第三轮审阅 (2026-07-08, REVIEW5-R3)**: 五专家全模块只读审阅完成 (A=Core安全/加密/并发, B=Core业务/AI/LLM, C=Persistence/DataPlatform归档, D=Governance/DeepFlow, E=Features商业化/浏览器/语音/集成), 共 54 项发现 (7 P0 / 18 P1 / 22 P2 / 7 P3)。修复进行中: **已修 53 项** (BUG-386~BUG-437, 已归档 history.md「2026-07-08 REVIEW5-R3」段, 含 2026-07-09 续修 B-001~B-019 + A-001 + D-006 + D-002/D-004 + D-005 + E-002 + E-003 + E-006 + E-007 + E-008 + E-005 + D-007 + D-008 + C-001 + C-002 + C-003 + C-004 + C-005 + C-006 + C-007), **待修 0 项** (REVIEW5-R3 全部 53 项编号发现已修复闭环; 另 1 项 D 附加 P3 风格说明为非 bug 不计入发现数, 见下方 D 段), 详见下方 REVIEW5-R3 清单; 报告存档 `expert_{a,b,c,d,e}_findings_round3.md`。
> **维护规则**: `tasks.md` 只保留当前待办和下一步任务; 完成后移动到 `history.md`; Bug 修复和待修复缺陷记录写入 `bugfix.md`。

---

## 文档导航

| 文档 | 说明 |
|------|------|
| [README.md](README.md) | 项目说明 |
| [docs/00.quickstart.AI集成总览-ai-one-file.md](docs/00.quickstart.AI集成总览-ai-one-file.md) | 对外集成入口 |
| [docs/32-36](docs/32.data.SQLCipher外部数据库读取-开发规格.md) | 数据平台 v0.7 设计规格 (5+1 文档) |
| [history.md](history.md) | 已完成任务归档 (近期: REVIEW5/R2/R3 + 2026-05~06) |
| [history-archive.md](history-archive.md) | 开发历史归档 (早期: Phase 0~5 + 2025-12 + 06-18) |
| [bugfix.md](bugfix.md) | Bug 修复和待修复缺陷记录 (近期: REVIEW5/R2/R3 + OPT/EXP) |
| [bugfix-archive.md](bugfix-archive.md) | Bug 修复归档 (早期: 2025-11~12 + 2026-05~06-18) |

---

## 当前判断

- `DeepLaunch.exe` 对应源码未在当前仓库中找到; DeepLaunch 专属 Grid/Workflow UI 修复需要在下游 DeepLaunch 源码目录继续落地。
- 商业化上线阻塞仍集中在 DB4 服务端签发、微信支付真实回调、备案/DNS/HTTPS。
- DB4 后端工作清单已投递 (`D:/_Progs/.to-server/toWangwei/#046-DB4后端工作清单与核对方案.md`), 等待王维回信。
- 数据平台 v0.7: 全链路 11 包编译通过, DeepBaseFMX.dpk 预存 E2280 已修复 + 平台 delegate 串联完成。
- 包构建健康 (2026-07-09): `build_packages_win64.ps1` E2199 包冲突根因查明为编译顺序违反传递依赖 (Commerce→SpeechCore→Persistence), 已对 Minimal/Runtime/LLM/Updater/Speech 五 profile 改序修复 (BUG-446); HttpServer.pas E2004 已修 (BUG-447, 撤冗余 interface uses); SQLiteReader.pas TFileInfo E2003 + Char E2671 已修 (BUG-448, `TFileInfo`→`TFile` 与全仓库统一, uses 补 System.Character)。**五 profile (Minimal/Runtime/LLM/Updater/Speech) 全链 passed, 全包构建阻塞解除**。Runtime profile 回归验证 BUG331+BUG330 = 6/6 passed 无回归。
- 三专家审阅 42 项: **全部完成** (已归档)。
- 第一轮五专家审阅 (REVIEW5): 39 项修复清单已全部完成 (已归档)。
- 第二轮五专家审阅 (REVIEW5-R2, 2026-07-06): 本轮修复 23 项已全部归档 history.md, 余 R2 发现项留待后续轮次或已并入 R3 重审。
- 第三轮五专家审阅 (REVIEW5-R3, 2026-07-08): **完成**, 已修 53 项 (BUG-386~437, 含 2026-07-09 续修 B-001~B-019 + A-001 + D-006 + D-002/D-004 + D-005 + E-002 + E-003 + E-006 + E-007 + E-008 + E-005 + D-007 + D-008 + C-001 + C-002 + C-003 + C-004 + C-005 + C-006 + C-007), 待修 0 项 (全部 53 项编号发现已修复闭环; 另 1 项 D 附加 P3 风格说明为非 bug 不计入), 详见下方 REVIEW5-R3 清单。

---

## ~~第二轮五专家审阅 (REVIEW5-R2, 2026-07-06)~~ ✅ 已归档

> 本轮修复 23 项 (7 P0 + 16 P1/P2, 含 DATA2-005/006 补录) 已全部归档 history.md「2026-07-06 REVIEW5-R2」段, 对应 BUG-363~BUG-385。
> R2 报告中尚未独立修复的 P1/P2 发现项 (专家 D 的 28 个 P1 中未展开部分、各专家 P2+) 已在第三轮审阅 (REVIEW5-R3) 中重新覆盖重审, 详见下方 REVIEW5-R3 清单, 不在本文档重复列出。

---

## P1 重要 (测试覆盖)

### QA-P1-001: BUG-321 核心模块零测试覆盖
- **状态**: 进行中
- **已完成**:
  - [x] Updater 安全测试 (14 用例)
  - [x] LLM E2E mock (15 用例)
  - [x] 桌面工具模板 E2E
  - [x] CI 可选包矩阵
  - [x] REVIEW-P0-001 编码扫描门禁+旧库迁移 (20)
  - [x] REVIEW-P0-002 代码层 (23)
  - [x] REVIEW-P1-001 TDBVoiceProfileStorage+11 DB 测试
  - [x] REVIEW-P1-002 官方 LLM 意图分类后端+9 测试
  - [x] REVIEW-P1-004 CI STUB/编码门禁+3 测试
  - [x] Commerce 测试覆盖 #10 (11 验证路径)
- **待办** (2026-07-10 核查更正, 以下描述基于实际仓库现状):
  - [x] ~~Phase 1: Schema.pas 测试~~ ✅ 已覆盖 — `Tests/Test.DeepBase.Schema.pas` 500 行/82 测试方法 (SCHEMA/CompatibleVersionRange/SQL 系列/Tier0-2/FullSchema/LanguagesData/I18nTextsData)。注: 文件实际 971 行 (非旧记 3884 行), OPT-P2-002 的"拆 4 文件"未落地 (见下方 P2 段更正)。
  - [x] ~~Phase 2: Resilience 系列测试~~ ✅ 已覆盖 — `Test.DeepBase.Resilience.pas` 118 测试 + `Test.DeepBase.Resilience.CircuitBreaker.PBT` 1 测试 + `Test.DeepBase.Resilience.Timeout.PBT` 2 测试 (共 121)。Retry/Policy/Bulkhead/Fallback/Timeout/CircuitBreaker 各路径有测。
  - [x] ~~Phase 3: LogQuery.pas 测试~~ ✅ 已覆盖 — `Test.DeepBase.LogAggregator.pas` 500 行/34 测试, 32 处 LogQuery 引用。文件 1804 行。
  - [x] ~~Phase 4: IntentClarification 关键路径测试~~ ✅ 已覆盖 — 6 测试文件: `.pas`/`.PBT`/`.Concurrent.PBT`/`.Round2.PBT`/`.SignalDetector.PBT`/`.Integration`。
  - [x] ~~Phase 5: Speech 关键路径测试~~ ✅ 已覆盖 — 8 测试文件: `.pas`/`.PBT`/`.Performance.PBT`/`.Voiceprint`/`.WakeWord`/`.Intent`/`.Intent.LLMBackend`/`.MFCC`。Features/DeepBase.Speech.* 共 20+ 单元已落地。
  - [ ] REVIEW-P0-002 后续 (真机): iOS/Android 权限查询真机补全 — 需要 Xcode + iOS 设备 (外部阻塞)。

---

## ~~第一轮五专家模块审阅 (REVIEW5, 2026-06-29~30)~~ ✅ 已归档

> 39 项修复清单 (REVIEW5-CORE-001~007 / DATA-001~008 / FEAT-001~010 / UI-001~006 / GOV-001~008) 全部完成, 对应 BUG-323~BUG-362, 已归档 history.md「2026-06-30 REVIEW5 五专家模块审阅」段, 不在本文档重复列出。

---

## P0 当前开发 (Blocking)

### DATA-P0-001: 微信运行时密钥偏移确认
- **状态**: 待开发 (被阻塞 — 需微信 4.1.10.30 + 管理员权限)
- **阻塞原因**: 运行时探针需要目标机器上有微信进程运行才能扫描内存
- **任务**:
- [ ] 在微信 4.1.10.30 运行时执行 WxDecryptProbe.exe, 确认密钥偏移值。
- [ ] 将偏移值回填到 KeyCallback 的 KnownOffsets 列表。
- [ ] 解密 MicroMsg.db 后导出 MSG 表列名���表, 更新 TWeChat4xAdapter 的 Schema 指纹前缀。

### DL-P0-2026-06-15: DeepLaunch Grid / Workflow UI 缺陷修复
- **状态**: 待开发
- **来源**: BUG-248 ~ BUG-251 (bugfix.md)
- **任务**:
- [ ] 定位 DeepLaunch 源码目录。
- [ ] 修复 Grid 右键菜单空指针崩溃 (BUG-248)。
- [ ] 工作流区界面文本默认英文 + 接入 i18n (BUG-249)。
- [ ] 接入主题同步: Grid/工作流画布/单元格/选中态/编辑窗体 (BUG-250)。
- [ ] 修复工作流区高度和绘制布局 (BUG-251)。
- [ ] 增加最小回归验证。

### COM-P0-001: DB4 收费后端与 deepKit 数据库
- **状态**: 进行中 (等待王维回信)
- **进���**: 工作清单已投递 `D:/_Progs/.to-server/toWangwei/#046-DB4后端工作清单与核对方案.md`, 验证脚本 `scripts/db4_server_verify.py` 已就绪
- **任务**:
- [ ] 等待王维确认 6 个 P0 端点和签名机制。
- [ ] 收到回信后运行 `scripts/db4_server_verify.py` 验证。
- [ ] 幂等键和重放保护。
- [ ] DB4 服务端私钥签发许可证、撤销版本同步、公钥轮换。

### OPS-P0-2026-05-13: DeepKit 备案、DNS、HTTPS
- **状态**: 进行中
- **任务**:
- [ ] 完成 `deepkit.top` 备案 + DNS 解析 + HTTPS 证书。
- [ ] 微信支付接入后, 补真实预下单、回调验签、退款撤权和对账。

### UPD-P0-001: 免费版升级收费版和付费更新
- **状态**: 进行中
- **任务**:
- [ ] 服务器按 entitlement 返回版本、下载地址、签名 manifest。
- [ ] 更新包校验 hash 和签名。未付费用户仅可见免费通道。
- **已完成**: Updater 安全测试 14 用例

---

## P2 中期整理

### ~~OPT-P2-001: BUG-322 StorageFactory 泛型化~~ ✅ 已完成
- **状态**: 已完成 (归档 history.md 全库优化审计段)
- **来源**: 全库优化审计 (BUG-322)
- **任务**:
- [x] 新增 `Core/DeepBase.StorageFactory.pas`: 泛型 `TStorageFactory<T>` helper
- [x] 14 个模块迁移到泛型基类, 消除约 420 行重复代码
- [x] 回归测试验证所有 Storage 注入/获取路径不变

### ~~OPT-P2-002: 大文件拆分~~ ✅ 核实完成 (2026-07-09 复核)
- **状态**: Crypto 确已拆分; **Math 已拆分完成**; **Schema 不适用** (纯 DDL 常量单元); **LLM 转独立重构待办 OPT-REFACTOR-001** (属架构重构非拆文件)。原"部分完成"更正 (2026-07-10) 仍基于错误前提, 已二次复核更正。
- **来源**: 全库优化审计
- **任务**:
- [x] `Core/DeepBase.Crypto.pas` (原 2856 行) → 确已按算法族拆分: 主文件 150 行 + `DeepBase.Crypto.AES.pas`/`Crypto.Hash.pas`/`Crypto.PBKDF2.pas`/`Crypto.RSA.pas`
- [x] `Core/DeepBase.Schema.pas` (971 行, 非旧记 3884 行) → **不适用, 不拆分**。纯 SQL DDL 常量单元 (24 个 `SQL_TIER0/1/2_*` 字符串 + 5 个 `Get*SchemaSQL` 聚合函数), 无 Table/Column/Index/Constraint 类型; `Persistence.Diagnose.FireDAC` 直接引用 20+ 单常量, 拆分只增跨单元耦合。
- [ ] `Core/DeepBase.LLM.pas` (1778 行, 非旧记 2635 行) → **转独立重构待办 OPT-REFACTOR-001** (见下方)。门面单元, 类型已迁 `LLM.Types`/`LLM.Config`/`LLM.Providers`, 剩余为 `TDeepBaseLLM` 单体类; 真正"拆分"需把模板管理 (~850 行 L918-1778) 提取为独立 `TLLMPromptTemplateManager`, 属架构重构, 影响 Persistence/VCL/FMX 调用方。
- [x] `Core/DeepBase.Math.pas` (527 行, 非旧记 2621 行) → **已拆分完成**。门面 + `DeepBase.Math.Geometry.pas`/`Math.Random.pas`/`Math.Interpolation.pas`/`Math.Statistics.pas` 四子单元 (各子单元头部注释 "Extracted from DeepBase.Math to keep the facade under 800 lines" 确认), `DeepBase.Services.Math.pas` 已 uses 全部子单元。

### OPT-REFACTOR-001: LLM.pas TDeepBaseLLM 模板管理提取 (架构重构)
- **优先级**: P2
- **状态**: ✅ 已完成 (2026-07-09)
- **来源**: OPT-P2-002 复核
- **任务**: 将 `Core/DeepBase.LLM.pas` 中 `TDeepBaseLLM` 的 Prompt 模板管理方法提取为独立 `TLLMPromptTemplateManager` 类, `TDeepBaseLLM` 委托之。
- **实施**: 新建 `Core/DeepBase.LLM.PromptTemplateManager.pas` (TLLMPromptTemplateManager 类), 迁入 9 方法 (Save/Get/Delete/Copy/Validate/Render/Export/ImportTemplate + GetAllTemplates) + 2 辅助 (LoadTemplateFromQuery/ClearPromptTemplates); `TDeepBaseLLM` 持有 `FPromptTemplateMgr` 字段, 9 公开模板方法改为一行委托; 门面签名不变, 调用方 (Persistence/VCL/FMX/BillingClient) 无需改动。
- **验证**: Win64 Tests.dpr 编译通过 (329078 行, 含新单元); 全量 DUnitX 4206 测试 Found / 4203 Passed / 0 Failed / 0 Errored / 0 Leaked / 3 Ignored; 无 216; 无新增警告。
- **后置**: ~~`DeepBase.Security.DPAPI`/`System.Variants`/`System.NetEncoding`/`System.RegularExpressions` 在 LLM.pas implementation uses 中的冗余清理属次要整洁项, 留待后续 (避免与本次重构混入)。~~ **已完成 (2026-07-09)**: 四项冗余 uses 全部清除 (`System.Variants`/`System.NetEncoding`/`System.RegularExpressions` + `DeepBase.Security.DPAPI`, 后者 implementation uses L251 声明但全文零符号引用)。Commerce→SpeechCore→Persistence 链编译通过, 无回归。

### OPS-P2-001: 服务器可观测性和运维
> **真相修正 (2026-07-11)**: 经拓扑核查, 可观测性是 **DB4 服务端职责**, 非客户端任务。`Tools/WebService/DeepBase.WebAPI.Observability.pas` (TApiServer) 仅在测试中被实例化, 无生产代码起它; `Features/DeepBase.HttpServer.pas` 仅被 UITest.FmxProbe 起用。桌面端不挂 /metrics//audit 端点、不建本地审计表。诉求已发函王维: #038 (2026-06-18 概要) + #045 (2026-06-24 完整方案 write_audit/refresh token 重放/health 泄露) + #073 (2026-07-09 收口催办) + #075 (2026-07-11 逐项答复)。王维 #074 回函确认三项排期可后置, 客户端先按无审计上线。
- [x] `DeepBase.WebAPI.Observability` 单元 (测试用, 非生产服务端): `GET /health` + `GET /metrics` (Prometheus) + 请求度量中间件 (33 单测, 2026-06-25)
- [ ] 审计日志持久化和告警路由 (邮件/Webhook) — **服务端待办 (DB4 王维)**: audit_logs 写入 + write_audit 函数 + 支付/权益/许可证三处写入点; #074 排期后置。
- [ ] 支付回调成功率、权益发放失败率、许可证签发失败率业务指标 — **服务端待办 (DB4 王维)**: GET /dk/metrics 三 counter; #074 排期后置。
- [ ] (DB4 侧) grant_entitlement 发放入口 + GET /dk/commerce/entitlements 端点 — **#075 提出, 待王维确认今天是否一并完成** (不应后置, 权益真相源根基)。

### PRODUCT-P2-001: 商业生命周期增强
- [ ] 多产品、多租户、组织席位、续费、升级、优惠码、退款撤权。

---

## 第三轮五专家全模块代码审阅 (REVIEW5-R3, 2026-07-08)

> **范围**: 5 位专家并行只读审阅, 一位专家负责一个模块域, 覆盖 Core 安全/加密/并发基础设施 (A)、Core 业务逻辑/AI/LLM (B)、Persistence/DataPlatform/doQry (C, 仅归档)、Governance/DeepFlow (D)、Features 商业化/浏览器/语音/集成 (E)。
> **报告**: `expert_{a,b,c,d,e}_findings_round3.md`
> **统计**: 共发现 **54 项** (A=11, B=19, C=7 项新发现, D=8, E=8; 另 D 附加 1 项 P3 风格问题未编号) — **7 个 P0 / 18 个 P1 / 22 个 P2 / 7 个 P3**。C 模块 7 项为 R3 新发现 (DATA-R3-001~007: 1 P0 / 3 P1 / 1 P2 / 2 P3), 非前轮归档; 此前统计误标 "C已在前轮归档" 已更正。
> **进度**: 已修 **53 项** (D-001, E-001, E-004, A-001~A-010, B-001~B-019, A-011, D-003, D-006, D-002, D-004, D-005, E-002, E-003, E-006, E-007, E-008, E-005, D-007, D-008, C-001, C-002, C-003, C-004, C-005, C-006, C-007), 待修 **0 项** (REVIEW5-R3 全部 53 项编号发现已修复闭环; 另 1 项 D 附加 P3 风格说明为非 bug 不计入发现数)。已修 53 项归档 history.md (2026-07-08 REVIEW5-R3 段, 含 2026-07-09 续修 B-001~B-019 + A-001 + D-006 + D-002/D-004 + D-005 + E-002 + E-003 + E-006 + E-007 + E-008 + E-005 + D-007 + D-008 + C-001 + C-002 + C-003 + C-004 + C-005 + C-006 + C-007), 对应 BUG-386~BUG-437。
> **注**: 专家 C 本轮报告已单独存档 (`expert_c_findings_round3.md`), 其发现与本轮主清单合并时按既有编号体系处理, 下方清单以 A/B/D/E 为准。

### REVIEW5-R3-A: Core 安全/加密/并发基础设施 (专家 A, 11 项: 2 P0 / 5 P1 / 3 P2 / 1 P3)

#### P0 — 崩溃/数据损坏/安全
- [x] **REVIEW5-R3-A-001** (CORE-R3-001): 修复 `Core/DeepBase.Authorization.pas` GetUser/GetRole/GetAllUsers/GetAllRoles 返回 `TObjectDictionary[doOwnsValues]` 拥有的裸对象引用, 锁外可被 DeleteUser/DeleteRole 释放致 use-after-free — **采用深克隆方案**: 新增 `TUser.Clone`/`TRole.Clone`, Get* 锁内返回克隆 (调用方拥有并释放), GetAll* 用 owning `TObjectList` 构建后移交所有权; 新增带锁写方法 `SetUserMetadata` 替代调用方改快照的脆弱写法 (写 token 落到真实用户). 优于原建议的引用计数 (record 字段不适合引用计数, 克隆契约与 B-003/B-004 FeatureFlags 一致). 契约变更: Get* 返回值所有权归调用方 (已 rg 全仓确认无外部旧契约依赖) ✅ BUG-402

### ~~REVIEW5-R3-A-002 ~ A-010 (已修 9 项)~~ �� → history.md
> A-002 Cache 锁外 Evict 竞态 (BUG-386) / A-003 PBKDF2 清零 (BUG-387) / A-004 UBS2·DPAPI 清零 (BUG-388) / A-005 RSA 私钥分量清零 (BUG-389) / A-006 Metrics 闭包 UAF (BUG-390) / A-007 Authorization 锁外竞态 (BUG-391) / A-008 ObjectPool 漏检 (BUG-392) / A-009 CountingSet 负计数 (BUG-393) / A-010 LRU 持锁回调 (BUG-394)

#### P1 — 待办 (A-003~A-007 已修, 见上方归档指针)

#### P2 — 待办 (A-008~A-010 已修, 见上方归档指针)

#### P3
- [x] **REVIEW5-R3-A-011** (CORE-R3-011): 优化 `Core/DeepBase.Resilience.CircuitBreaker.pas` SetState 持 FLock 调 FOnStateChanged, 慢回调阻塞所有 AllowRequest/Execute — **`SetState` 已改为锁内仅暂存 pending 变更 (`FPendingStateChange`), 锁外由 `FirePendingStateChanged` 触发回调**; 本轮补齐遗漏入口: `AllowRequest`/`RecordSuccess`/`RecordFailure` 在 `finally FLock.Leave` 后补充 `FirePendingStateChanged` 调用 (此前 SetState 改为不锁内触发后, 这三处的状态变化回调会丢失). `Execute`/`Execute<T>` 路径经 RecordSuccess/RecordFailure 覆盖无需单独触发 ✅ BUG-418

### REVIEW5-R3-C: Persistence/DataPlatform 归档与连接池 (专家 C, 7 项: 1 P0 / 3 P1 / 1 P2 / 2 P3)

> 来源 `expert_c_findings_round3.md`. 第二轮 (R2) 已修 ORM 参数化/BCryptDecrypt 清零/DB.Pool Validate 超时等, 本轮 (R3) 为 R3 新发现的 7 项, 非前轮归档.

#### P0 — 数据损坏/安全
- [x] **REVIEW5-R3-C-001** (DATA-R3-001 / BUG-431): 修复 `Persistence/DeepBase.DB.Pool.pas` `TPooledConnection.Release` 归还连接前不回滚残留事务/不关闭游标, 下个借用者继承脏连接 (SQLite 报 "cannot start a transaction within a transaction"; PG/MySQL 可能读到上一调用方未提交的中间数据甚至把别人的 INSERT/UPDATE 一起提交) — **Release 持 FPool.FLock 前先调 `ResetConnectionState`: `if FConnection.InTransaction then FConnection.Rollback` 回滚残留未提交事务 (不 Commit, 残留事务几乎都是异常路径遗留的未完成工作) + `FConnection.TxOptions.AutoCommit := FPool.FConfig.AutoCommit` 重置隔离级别防止调用方临时提升后泄漏; 复位失败仅记事件不阻断归还 (IsValid 探活兜底, 避免复位失败致连接泄漏卡 csInUse). 残留游标 (调用方 TFDQuery.Open 后异常未 Close) 属调用方 dataset 生命周期责任, 连接池不接管 (与 FireDAC 连接池设计一致).** ✅ BUG-431

#### P1 — 已修 (3/3)
- [x] **REVIEW5-R3-C-002** (DATA-R3-002 / BUG-432): `doQry/doQryMain.pas` btnFilterClick (L151) 过滤条件字符串拼接致过滤表达式注入 (`tblQueries.Filter := 'proc_name LIKE ''%' + s + '%'''`) — 改用 `tblQueries.Filter := 'proc_name LIKE ' + QuotedStr('%' + s + '%')`, `QuotedStr` 将内嵌单引号翻倍为 `''` 锁进字面量. `System.SysUtils` 已在 uses (L6). 注: doQry 工程在 BDS37 无法整体编译 (uDoQryLegacy L8 `DBClient` 已移除, 历史遗留), 修复为纯标准 API, 语法确定正确. ✅ BUG-432
- [x] **REVIEW5-R3-C-003** (DATA-R3-003 / BUG-433): `doQry/doQryMain.pas` GetFieldList (L305) 用 `Format` 拼接 TableName 到 information_schema 查询 + btnGenSqlClick (L126) 拼接 proc_name — 两处均改 ADO 参数化: `WHERE table_name = :t`/`WHERE proc_name = :p` + `Parameters.ParamByName(...).Value := ...`. aQry 为 TADOQuery (L27), Data.Win.ADODB 已在 uses (L12). L286 (硬编码 'public' 无拼接) 与 L178 (VALUES 全字面量) 无注入风险未改. ✅ BUG-433
- [x] **REVIEW5-R3-C-004** (DATA-R3-004 / BUG-434): `Persistence.Diagnose.FireDAC` CheckForeignKeys (L460)/CheckRequiredFields (L517)/CheckEnumValues (L579) 三处 except 经 `OutputDebugString` 吞查询异常致诊断“假绿” (查询失败返回空数组 → DiagnoseAll 报“全绿”) — `Core/DeepBase.Diagnose.pas` `TDiagnoseIssueType` 枚举末尾新增 `ditCheckError` (序数 8, 兼容已有 0..7), 三 except 块改为构造 `ditCheckError`+`IsOK:=False` 的 TDiagnoseResult 追加 ResultList, Issue 填 “检查失败: ”+E.Message, TableName/ObjectName 填当前迭代上下文 (FK/RF/EF). AddColumnIfNotExists/AutoFix 的 except 保留 (返回值已部分表达失败, 不属假绿语义, 超 DATA-R3-004 范围). ✅ BUG-434

#### P2 — 已修 (1/1)
- [x] **REVIEW5-R3-C-005** (DATA-R3-005 / BUG-435): `Persistence.MRU.FireDAC` Upsert 无条件 `StartTransaction` + except 无条件 `Rollback`, 重入/共享连接场景误回滚调用方事务 (SQLite 报 "cannot start a transaction within a transaction"; PG/MySQL 回滚调用方外层事务撤销其合法 DML) — 仿 Authorization OwnTx 模式 (DATA2-025): var 加 `OwnTx: Boolean`, `if not FConnection.InTransaction then StartTransaction + OwnTx:=True`, Commit/Rollback 仅 `if OwnTx` 时执行, 异常 `raise` 上抛让调用方感知. DATA2-019 防并发重复键语义保留 (无外层事务时仍自启包裹 SELECT-INSERT, 有则复用 + UNIQUE 约束兜底). ✅ BUG-435

#### P3 — 待办
- [x] **REVIEW5-R3-C-006** (DATA-R3-006 / BUG-436): `doQry/uDoQryLegacy.pas` 异常/UI 消息含完整内联值 SQL (PII 泄漏) — `ExecuteAndGetResult` L756 / `ExecuteSQL` L778 / `doQry` L894-996 共 13 处把 BuildSQL 生成的含参数值 SQL 塞进 msg(var 输出参数→UI/日志) 或异常上抛, 含聊天正文/用户ID/分享链接. 修复: msg/异常消息只保留错误本身+操作类型/表名/行数等脱敏元数据, 去 `SQL:` 尾巴; 完整 SQL 经 `{$IFDEF DEBUG} OutputDebugString {$ENDIF}` 输出调试器不上抛不进 msg. ✅ BUG-436
- [x] **REVIEW5-R3-C-007** (DATA-R3-007 / BUG-437): `AddColumn` 的 `ColumnDef` 原样拼入 DDL (防御性缺口) — `Persistence.Manager.FireDAC.AddColumn` L222 `Format('ALTER TABLE %s ADD COLUMN %s %s', [TableName, ColumnName, ColumnDef])` 中 ColumnDef 无校验, 暴露在公共 `IManagerStorage.AddColumn`, 未来调用方传受外部影响值即 DDL 注入. 修复: `Core/DeepBase.SQL.Utils.pas` `TSQLUtils` 加 `IsValidColumnDef`/`ValidateColumnDef` (拒分号/`--`/`/*`/换行/DDL-DML关键字, 允许字符白名单), `AddColumn` L217 后加校验 (与 identifier 校验同失败语义). 选白名单非强类型 TColumnDef (不改公共签名, 最小侵入). DUnitX `Property20` 2 测试 (11 合法+12 非法) 全过, `run_tests -FromUnit DeepBase.SQL.Security.PBT` → 5/5 PASSED. ✅ BUG-437

### REVIEW5-R3-B: Core 业务逻辑与 AI/LLM (专家 B, 19 项: 4 P0 / 6 P1 / 7 P2 / 2 P3)

#### P0 — 崩溃/悬空引用/对象生命周期
- [x] **REVIEW5-R3-B-001** (BIZ-R3-001): 修复 `Features/DeepBase.LLM.Proxy.pas` GenerateImageStream 用 TTask.Run 捕获 Self 但未存入追踪列表、无析构等待, 客户端释放后 GenerateImage 访问已释放 Self — **采用接口引用捕获方案** (与 CORE-R3-006/BUG-390 一致): 方法内 `LSelf := Self` (ILLMClient), 闭包经 LSelf 调用, 引用计数保活对象至任务结束. 未用专家建议的 FActiveTasks+WaitFor (理由: 已有验证先例 + 字段均线程安全值类型 + 避免 WaitFor 死锁, 详见 bugfix.md BUG-400) ✅ BUG-400
- [x] **REVIEW5-R3-B-002** (BIZ-R3-002): 修复 `Core/DeepBase.LLM.Manager.pas` Destroy 仅 Wait(5000) 超时后仍 FreeAndNil(FLLMClient), 而 ExecuteAsync 任务(HTTP 可达 30-60s) 仍在调用 FLLMClient.Chat 致 use-after-free — Wait 前 `LT.Cancel`, 超时 5000→120000ms (2x 默认 HTTP timeout 60s), 超时则 LAnyTimeout 标志记 Error 日志后 Exit 跳过全部 teardown (释放被在用对象是确定性 UAF, 取泄漏更安全) ✅ BUG-401
- [x] **REVIEW5-R3-B-003** (BIZ-R3-003): 修复 `Core/DeepBase.FeatureFlags.pas` SaveFlag 在 OwnsObjects=True 的列表上做下标赋值 LFlags[I]:=AFlag, 静默释放旧对象并接管 AFlag, LFlags.Free 时释放调用方 AFlag — **改为克隆方案**: 新增 TFeatureFlag.Clone, SaveFlag 内部克隆 AFlag 后入库 (不接管调用方对象), 优于原建议的 OwnsObjects:=False (后者仍让临时列表持裸引用, 语义不清) ✅ BUG-398
- [x] **REVIEW5-R3-B-004** (BIZ-R3-004): 修复 `Core/DeepBase.FeatureFlags.pas` GetFlag 返回裸 TFeatureFlag 指针, 所有权契约不明确, double-free/泄漏风险 — **统一返回 Clone** (Memory/File 两实现契约一致, 调用方拥有并释放), 复用 BUG-398 的 Clone ✅ BUG-399

#### P1
- [x] **REVIEW5-R3-B-005** (BIZ-R3-005): 修复 `Core/DeepBase.LLM.pas` ParseResponse 无条件调 ParseOpenAIResponse/ParseAnthropicResponse 覆盖 DoHttpRequest 返回的 False, 错误响应体含可解析 JSON 时被误判 Success=True — **仅 `if Result then` 守卫**: DoHttpRequest 返回 True 时才进入 ParseXxxResponse, 否则保留 False 并记录错误体到 Response.ErrorMessage 供诊断. 避免 Parse 覆盖真实 HTTP 失败状态 ✅ BUG-404
- [x] **REVIEW5-R3-B-006** (BIZ-R3-006): 修复 `Core/DeepBase.LLM.Manager.pas` DeletePrompt 四条级联 DELETE (LLMCalls/PromptMetaBinding/PromptVersions/Prompts) 无事务, 部分失败留不一致 — **合并为单条分号分隔多语句 SQL**, SQLite 和 PostgreSQL 均支持单 Execute 执行多语句, 数据库引擎保证语句级原子性. 同一 `:InternalCode` 参数通过参数化查询复用 (L1525-1539) ✅ BUG-407
- [x] **REVIEW5-R3-B-007** (BIZ-R3-007): 修复 `Core/DeepBase.LLM.ImportExport.pas` ImportLLMContent `TryGetValue` 返回值被忽略, 键缺失仍进入删除分支清空现有数据 — **检查三个 `TryGetValue` 返回值**, 任一返回 False (键缺失) 则报 `'Import validation failed: missing required array in JSON'` 错误并 Exit, 阻止后续删除操作, 与注释验证意图一致 ✅ BUG-405
- [x] **REVIEW5-R3-B-008** (BIZ-R3-008): 修复 `Persistence/DeepBase.Persistence.Authorization.FireDAC.pas` DeleteUser/DeleteRole 仅删主表未清 auth_user_roles 关联表, 留孤儿行, 重启后加载恢复已删关联 — **在 DeleteUser 和 DeleteRole 中增加级联删除 auth_user_roles 语句**, 先删关联再删主表, 分号分隔单 ExecSQL 保证原子性. 参数化查询避免注入 (L491-498/L636-643) ✅ BUG-408
- [x] **REVIEW5-R3-B-009** (BIZ-R3-009): 修复 `Core/DeepBase.License.pas` LoadLicenseFromDB `try...except end` 吞所有异常, 篡改/损坏许可证与"无许可证"不可区分 — **仅静默忽略 "table not found" 异常** (首次启动预期), 检查异常消息包含 "no such table" / "table" / "doesn't exist" / "does not exist" 时静默, 其他异常经 raise 重新抛出. 保持向后兼容: 首次启动无表时不报错, 但连接失败、数据损坏等错误不再被吞 (L575-589) ✅ BUG-409
- [x] **REVIEW5-R3-B-010** (BIZ-R3-010): 修复 `Core/DeepBase.License.pas` VerifySignature 长度早期退出 `if Length(Expected)<>Length(Signature) then Exit` 泄漏签名长度信息, 破坏常量时间比较 — **移除长度早期退出**, 用 Expected 长度作循环基准, Signature 较短时 Delphi 字符串越界返回 #0 (XOR 后 Diff 非零), Signature 较长时额外字节经第二轮循环计入 Diff, 长度差异自然反映在 Diff 结果中, 比较耗时恒定 ✅ BUG-406

#### P2
- [x] **REVIEW5-R3-B-011** (BIZ-R3-011): 修复 `Core/DeepBase.Scheduler.pas` 任务完成锁释放后锁外调 TaskRef.FOnCompleted, 期间另一线程 Cleanup 可从 FTasks 移除并释放任务对象(doOwnsValues) 致 use-after-free; FOnFailed 同 — **采用 FRunningITask 保活 + Cleanup 运行中守卫方案**: 成功路径锁内捕获 LOnCompleted 局部 (不再锁外读 TaskRef.FOnCompleted 字段); 成功/失败路径推迟 FRunningITask:=nil 至回调后, 使 TaskRef 在锁外回调窗口保活; Cleanup 移除条件加 `(FRunningITask=nil) and` 跳过闭包仍执行的任务. 优于把回调移入锁 (与 REVIEW5-CORE-004 锁外回调+异常隔离设计冲突) ✅ BUG-403
- [x] **REVIEW5-R3-B-012** (BIZ-R3-012): 修复 `Core/DeepBase.LLM.BillingClient.pas` ChatWithRetry 退避 `1000*(1 shl (I-1))` 无 jitter 致重试风暴, 且 Retries>31 时 1 shl 31 溢出为负 Sleep 失效 — **加 Min(I-1,20) 防溢出** (最大延迟 ~17 分钟) + **加 Random(200) 抖动** (0-199ms 随机打散重试). EBillingServerError 线性退避也加 jitter. implementation uses 增加 System.Math 提供 Min. 保持重试次数、异常处理不变 (L1044-1055) ✅ BUG-410
- [x] **REVIEW5-R3-B-013** (BIZ-R3-013): 修复 `Core/DeepBase.LLM.BillingClient.pas` DoStreamRequest 设 Accept:text/event-stream 未重置, 泄漏到后续 DoRequest 致非流式 API 异常 — **DoStreamRequest 外层 finally 重置 Accept:application/json**, 确保正常返回或异常都恢复默认值. 不影响流式请求本身, 仅防止状态泄漏 (L831-834) ✅ BUG-411
- [x] **REVIEW5-R3-B-014** (BIZ-R3-014): 修复 `Core/DeepBase.AutoFix.pas` NotifyShellShown 用 TThread.ForceQueue(nil,...) 在线程池而非主线程执行 TAutoFixScenarioRunner.Run(内含 Halt), 非主线程 Halt 致进程清理不完整 — **改 TThread.Queue(nil,...)** 确保主线程执行, Halt 调用进程清理完整. 仍延迟到下一次消息泵循环, 不影响 UI 绘制时序 (L74-78) ✅ BUG-412
- [x] **REVIEW5-R3-B-015** (BIZ-R3-015): 修复 `Core/DeepBase.MVVM.pas` TAsyncCommand.Destroy Wait(INFINITE), FExecuteProc 阻塞且不检查 IsCancelledFunc 时应用关闭永久挂起 — **Wait(5000) 有限超时**, 超时捕获异常并清空 FTask, 析构继续清理不阻塞. 正常取消任务仍等待完成, 仅阻塞任务触发超时退出 (L503-518) ✅ BUG-413
- [x] **REVIEW5-R3-B-016** (BIZ-R3-016): 修复 `Core/DeepBase.Manager.pas` WhenReady 在 FReadyFired=True 时 TTask.Run 执行 ACallback 不追踪不等待, FinalizeModules 释放模块后任务运行解引用已释放对象 — **新增 FPendingReadyTasks 追踪 + WaitForPendingReadyTasks (Wait 5000 有限超时) 在 FinalizeModules 前等待**, 回调用 LLogger 快照避免解引用已释放 FLogger. 持锁等待死锁风险消除 (锁内快照后释放锁再 Wait) ✅ BUG-414
- [x] **REVIEW5-R3-B-017** (BIZ-R3-017): 优化 `Core/DeepBase.Authorization.pas` GetEffectivePermissions SetLength+1 循环+线性去重 O(n²), HasPermission 每次调用都执行 — **新增 Seen: TDictionary<string,Boolean> 哈希集合 O(1) 去重, GetRolePermissionsRecursive 增加 Seen 参数, 结束时 Seen.Keys.ToArray 一次性转数组**. HasPermission 单次开销降低 (不引入缓存避免失效一致性) ✅ BUG-415

#### P3
- [x] **REVIEW5-R3-B-018** (BIZ-R3-018): 优化 `Core/DeepBase.PluginManager.pas` VerifyPluginSignature 同步 WinVerifyTrust 可能 CRL/OCSP 网络检查阻塞主线程, 多插件+慢网络致启动 UI 冻结 — **设置 dwProvFlags := WTD_CACHE_ONLY_URL_RETRIEVAL 强制仅用缓存 URL (无网络往返), 配合已有 WTD_REVOKE_NONE 禁用吊销检查, 消除主线程阻塞** ✅ BUG-416
- [x] **REVIEW5-R3-B-019** (BIZ-R3-019): 修复 `Core/DeepBase.LLM.ImportExport.pas` YAML 导出已实现(JsonToYaml)但导入是 stub 返回错误串, 用户导出 YAML 后无法导入, 功能不对称 — **采用导出 YAML / 拒绝导入方案**: `YamlToJson` 改为返回 nil (不再返回带 error key 的伪对象), JSON 快路径保留; `ImportFromString` 与 `ValidateImportFile` 两调用点在 nil 时区分给出明确错误 "YAML import is not supported, please import as JSON". `YamlToJson` 移至 public 供工具与单测直接验证. 新增 `TTestYamlToJson` 回归 (YAML→nil / JSON→对象) ✅ BUG-417

### REVIEW5-R3-D: Governance/DeepFlow (专家 D, 8 项: 1 P0 / 5 P1 / 2 P2)

#### P0 — 编译阻断
- ~~**REVIEW5-R3-D-001** (GOV-R3-001): ConfigRegistrar uses 缺逗号致 E1038 编译阻断 (BUG-396)~~ ✅ → history.md
- [x] **REVIEW5-R3-D-009** (GOV-R3-009): DATA2-023 新增的 Governance 代码引入第二处编译阻断 — `ConfigRegistrar.pas` L451/L574 调用不存在的方法 `FActionGrid.RegisterAction(...)` (签名实为 `RegisterActionObj`) + ComputeModeHMAC 与 `EvidenceStore.SQLite.pas` ComputeHash 的 HMAC 分支用 string 参数调 `THMACUtils.ComputeHash` 致类型不匹配 (E2010), 拉入此二单元的任何目标 (含 `DeepBaseTests.dpr`) 构建中断 — **uses 补 `DeepBase.Crypto.Encoding`; 2 处 `RegisterAction` → `RegisterActionObj`; ComputeModeHMAC/ComputeHash HMAC 分支改用 `THMACUtils` 的 `TBytes` 重载, 输出经 `TEncodingUtils.HexEncode` 转十六进制** ✅ BUG-441 (2026-07-09)

#### P1
- [x] **REVIEW5-R3-D-002** (GOV-R3-002): 修复 `Governance/DeepBase.Governance.EvidenceStore.SQLite.pas` MigrateExistingChain 从未被构造函数调用(已 rg 全仓确认仅声明+实现), 旧库行 this_hash 永远为空致 VerifyChain 误报所有旧行被篡改 — **构造函数 MigrateHashColumns 后、InitializeChainState 前调用 MigrateExistingChain**, 使旧库行回填 this_hash, VerifyChain 不再误报; InitializeChainState 读到的是已回填的链尾哈希 ✅ BUG-421
- [x] **REVIEW5-R3-D-003** (GOV-R3-003): 修复 `Governance/DeepBase.Governance.ActionGrid.pas` CanRun/Run/GetDisabledReason/SetEnabled/GetActionInfo/GetAllActions 读 FActions/FBridges 未持 FLock, 与热注册路径并发致 rehash 期半更新/AV; 更严重的是 Run 锁外持 `TAction` 引用期间同 key `RegisterActionObj` 会因 `doOwnsValues` 释放该对象致 UAF — **采用锁内克隆值类型快照方案**: CanRun/GetDisabledReason/SetEnabled/GetActionInfo/GetAllActions 均在 `FLock` 内读+拷贝到 record/局部, 锁外不再持 `TAction` 引用; Run 锁内克隆 Enabled/DisabledReason/DueRef + BridgeKeys.ToArray + 取 IBridge 引用数组(引用计数保活), 锁外跑慢速 DueChecker 与 Bridge.Execute; 删除已无用的私有 `CheckDueIfRequired`(due 检查内联到 Run, 避免持 TAction 传参). GetAllActions 改为锁内直接构建 record(不再回调已加锁 GetActionInfo, 规避 TCriticalSection 不可重入死锁) ✅ BUG-419
- [x] **REVIEW5-R3-D-004** (GOV-R3-004): 修复 `Governance/DeepBase.Governance.EvidenceStore.SQLite.pas` MigrateExistingChain 多行 UPDATE 在 while 循环中无事务包裹, 进程中途崩溃致链断裂且无法定位 — **循环全程 StartTransaction/Commit 包裹, except Rollback+raise 保证全成或全回退, 不会出现"部分行已回填+部分仍空"的断裂链**; 链尾缓存 GetLastHash 在事务提交后读取 (避免读未提交半态) ✅ BUG-421
- [x] **REVIEW5-R3-D-005** (GOV-R3-005): 修复 `Governance/DeepBase.Governance.EvidenceRecorder.pas` SaveWithRetry 用固定 (100,200,400) 退避无抖动, 高并发失败时重试风暴; 析构同步 Flush 队列满 1000 条可阻塞数百秒 — **退避加 ±30% 抖动** (BackoffDelayWithJitter, 以 GetTickCount 低 16 位作伪随机源避免重试风暴; 两处 Sleep 调用点 EnqueueEntry L293 + SaveWithRetry L328 均改用); **Flush 加单次上限 FLUSH_MAX_ITEMS=500 + 总超时 FLUSH_TOTAL_TIMEOUT_MS=5000**, 余量交后台线程/下次 Flush ✅ BUG-422
- [x] **REVIEW5-R3-D-006** (GOV-R3-006): 修复 `DeepFlow/Source/Core/DeepFlow.Engine.pas` SendSync 用单槽 FResponseSink, 并发调用互相覆盖致先到者 correlationId 匹配失败、ResponseEvent 永不 SetEvent 而超时丢响应, 注释声称"safe against concurrent SendSync"与实现不符 — **改为 `TObjectDictionary<string,TResponseWaiter>` 按 MsgId 分发**: 新增 `TResponseWaiter` (持 TEvent+Response), SendSync 按请求 MsgId 注册 waiter (Add, 所有权移交字典), ProcessMessage 分发时按 `TResponseMessage.CorrelationId` TryGetValue 路由到对应 waiter 并 SetEvent; waiter 用 ExtractPair 在 SendSync finally 取回所有权后统一释放 (无 double-free). 无匹配等待器的响应/非响应消息仍回落 FOnMessageProcessed. DeepFlow.PBT 编译+回归通过 ✅ BUG-420

#### P2
- [x] **REVIEW5-R3-D-007** (GOV-R3-007): 修复 `DeepFlow/Source/Roles/DeepFlow.Commander.pas` GetOrCreateSession 锁内返回 Session 指针后释放锁, ProcessRequest 锁外修改 Session.State/FTurnCount(Inc), 同 session-id 并发请求数据竞争 — ProcessRequest 中 Session.State/FTurnCount 读写 + Context/SessionId 快照取值全部包裹 FSessionLock 临界区 (内联 var 局部快照, AnalyzeIntent 耗时 LLM 调用锁外执行); 成功路径 ssPending 与 except 路径 ssError 状态更新也各自锁内. ✅ BUG-429
- [x] **REVIEW5-R3-D-008** (GOV-R3-008): 修复 `Governance/DeepBase.Governance.AI.ProposalQueue.pas` Submit 无容量上限, AI 循环提交可无限堆积 TProposal 致 OOM, FindById/GetPending O(n) 膨胀后卡顿; 全程无锁, 引入后台 AI 提交将升 P1 — 加 FMaxPending (默认 1000, 满则抛 EProposalQueueError) + TCriticalSection 保护 Submit/Approve/Reject/Apply/FindById/GetPending/GetAll/Count 全部方法 (FindById 拆 FindByIdInternal 避免不可重入自死锁). ✅ BUG-430

> **D 附加(非 bug, 不编号)**: ActionGrid.CheckDueIfRequired L192 `raise Exception.CreateFmt` 用泛型 Exception, 违反 CLAUDE.md "不引入泛型 Exception.Create" 约定 — 建议改 DeepBase.Exceptions 具体类或模块内 EGovernanceError。P3 风格, 本轮不计入发现数。

### REVIEW5-R3-E: Features 商业化/浏览器/语音/集成 (专家 E, 8 项: 1 P0 / 2 P1 / 3 P2 / 2 P3)

#### P0 — 编译阻断
- ~~**REVIEW5-R3-E-001** (FEAT-R3-001): UIA.Engine uses 缺逗号致编译阻断 (BUG-397)~~ ✅ → history.md

#### P1
- [x] **REVIEW5-R3-E-002** (FEAT-R3-002): 修复 `Features/DeepBase.Browser.Engine.WebView2.pas` NavigateAsync/ExecuteScriptAsync/EvaluateScriptAsync/CaptureScreenshotAsync 返回 TTask.Run(LProc) 捕获 Self 访问实例字段, 析构不等待未完成任务致 use-after-free — **新增 FAsyncTasks: TList<ITask> + FAsyncTasksLock 字段**; **RunTrackedAsync(LProc) 封装 TTask.Run 并注册任务** (4 处 Async 方法调用点全部改用); **WaitForAsyncTasks 析构首步以 5s/任务有界等待全部在途任务** 后才释放 Self; 析构末尾释放 FAsyncTasksLock/FAsyncTasks 容器 ✅ BUG-423
- [x] **REVIEW5-R3-E-003** (FEAT-R3-003): 修复 `Features/DeepBase.CloudBackup.pas` `TBackupEncryptor` 构造时 `DeriveKeyAndIV` 用无盐单次 SHA-256(password) 派生 32B key+16B IV (无迭代/IV 非随机, 同密码每次 IV 相同), 与同单元 `TSimpleCrypto` 已内置 PBKDF2(100k)+随机盐+AES-256-GCM 重复且弱路径被 `EncryptBytes` 实际使用强路径被绕过 — **删除冗余弱派生层**: 删字段 FKey/FIV 与 `DeriveKeyAndIV` 方法 (interface+impl), 仅保留托管 `FPassword:string`; 构造直接赋值; `EncryptBytes/DecryptBytes` 空检查改 `FPassword=''` 并直接转发密码 `TSimpleCrypto.EncryptBytes(AData, FPassword)`/`DecryptBytes` (让 TSimpleCrypto 全套 KDF/GCM/随机盐+IV 生效, 非确定加密); `Destroy` 删 `FillChar(FIV..)` 悬空写入; `EncryptStream` 注释改为已委托 TSimpleCrypto AES-GCM (移除过时 XOR 注释). **方案优于原建议**: 原建议手写 PBKDF2+文件头, 实际复用 TSimpleCrypto 已测安全路径更简单可靠 ✅ BUG-424

#### P2
- ~~**REVIEW5-R3-E-004** (FEAT-R3-004): UIA_ProcessIdPropertyId 常量 34005 错误 (官方 30002) (BUG-395)~~ ✅ → history.md
- [x] **REVIEW5-R3-E-005** (FEAT-R3-005): 修复 `Features/DeepBase.Commerce.SafeClient.pas` SendJson 仅 401 重试, 对 429/5xx 不重试不退避, 支付/订单类短暂限流直接失败 — **新增 429/5xx 瞬态失败退避**: `SendJson` 末尾对幂等调用 (GET/HEAD 或带 idempotency key) 的 429/5xx 循环重试 `FMaxRetries` 次, 429 优先遵守 `Retry-After` 响应头 (秒数→ms, 钳制到 `BACKOFF_CAP_MS`), 5xx 用指数退避 `BACKOFF_BASE_MS*2^attempt` + 基于 attempt 的确定性 ±25% 抖动 (避免 `Now`/`Random`); 非幂等 POST 无 idempotency key 不重试 (防重复下单). 抽出 `IsRetriableStatus`/`IsIdempotentCall`/`ExtractRetryAfterMs`/`ComputeBackoffMs` 辅助方法. implementation uses 增加 `System.Math`. **新增 2 个回归测试**: 429 幂等 GET 重试成功 (Retry-After:0 无 Sleep 阻塞, RequestCount=2)、非幂等 POST 5xx 不重试 (RequestCount=1 防重复) ✅ BUG-428
- [x] **REVIEW5-R3-E-006** (FEAT-R3-006): 修复 `Features/DeepBase.CloudBackup.pas` `TCloudBackupClient.Create` 不校验 FServiceURL scheme, 配置 http:// 时 API key 在 X-API-Key 头明文传输可被 MITM 截获 — **构造函数开头 (inherited 前) 加 `if not AServiceURL.ToLower.StartsWith('https://') then raise ECloudServiceNotConfiguredException.CreateFmt(...)`**, 复用既有异常类不新增, 不区分大小写, fail-fast 拒绝不安全配置; ServiceURL 只读 property 构造后不变, 不在 DoRequest 加冗余校验 (符合 CLAUDE.md). 单调用点 Manager.Create L1660, 析构 FreeAndNil+Assigned 守卫对半初始化安全 ✅ BUG-425

#### P3
- [x] **REVIEW5-R3-E-007** (FEAT-R3-007): 修复 `Features/DeepBase.AntiTamper.pas` `GetDefaultConfig` 默认 salt 为硬编码固定串 'DeepMoveC_Default_Salt_2025', 攻击者可针对该 salt+常见密码预计算彩虹表 — **`GetDefaultConfig` Salt 默认空 (对齐 EncryptionKey BUG-034); `Initialize` 开头校验 `if AConfig.Salt = '' then raise EAntiTamperException.Create(...)`, 复用既有异常不新增**. 不随机生成: Salt 须跨运行稳定复现密钥, 而此类无持久化载体, 随机不持久化致加密数据无法解密 ✅ BUG-426
- [x] **REVIEW5-R3-E-008** (FEAT-R3-008): 修复 `Features/DeepBase.Speech.TTS.StepFun.pas` `FetchSystemVoices`/`FetchClonedVoices` `nil as TJSONArray` 触发 EInvalidCast 而非返回 nil, `if JSONArr=nil then Exit` 为死代码, voices 键缺失时 FLastError 含 EInvalidCast 信息而非清晰错误 — **两处统一改 `is TJSONArray` 检查 + 硬转换 `TJSONArray(VoicesVal)`, 缺失/非数组优雅 Exit 并设清晰 FLastError, 删除死代码** ✅ BUG-427

### REVIEW5-R3 修复优先级建议
1. **立即修(P0, 8 项, 编译阻断+崩溃+安全)**: ~~REVIEW5-R3-D-001 与 REVIEW5-R3-E-001 同模式(`DeepBase.Crypto.Hash` 后缺逗号, 全仓仅此两处)~~ ✅ 已修 (BUG-396/397); ~~REVIEW5-R3-A-002 Cache 锁外 Evict 竞态~~ ✅ 已修 (BUG-386); ~~REVIEW5-R3-B-003/B-004 (FeatureFlags OwnsObjects 下标赋值/裸指针所有权)~~ ✅ 已修 (BUG-398/399); ~~REVIEW5-R3-B-001 (LLM.Proxy GenerateImageStream 悬空)~~ ✅ 已修 (BUG-400, 接口引用捕获方案); ~~REVIEW5-R3-B-002 (LLM.Manager Destroy 释放在用对象)~~ ✅ 已修 (BUG-401, Cancel+120s Wait+超时不释放)。**仍待修 1 项 P0**: ~~REVIEW5-R3-A-001 (Authorization 裸引用 UAF)~~ ✅ 已修 (BUG-402, 深克隆方案); ~~REVIEW5-R3-C-001 (DB.Pool 连接池脏连接归还)~~ ✅ 已修 (BUG-431, Release 前回滚残留事务+重置隔离级别)。**全部 8 项 P0 已修完。**
2. **尽快修(P1, 18 项)**: ~~加密材料未清零(A-003/004/005)~~ ✅ 已修 (BUG-387/388/389)、~~并发竞态(A-007)~~ ✅ 已修 (BUG-391)、~~并发竞态(D-006 SendSync 单槽覆盖)~~ ✅ 已修 (BUG-420)、~~并发竞态(E-002 WebView2 异步析构)~~ ✅ 已修 (BUG-423)、~~证据链迁移(D-002/004)~~ ✅ 已修 (BUG-421)、~~退避风暴(D-005)~~ ✅ 已修 (BUG-422)、~~冗余弱密钥派生(E-003)~~ ✅ 已修 (BUG-424)、~~对象生命周期/错误传播(B-005)~~ ✅ 已修 (BUG-404)、~~错误传播/数据一致性(B-006/007/008/009)~~ ✅ 已修 (BUG-407/405/408/409)、~~License 时序侧信道(B-010)~~ ✅ 已修 (BUG-406)、~~退避风暴(B-012)~~ ✅ 已修 (BUG-410)、~~CloudBackup 传输安全(E-006)~~ ✅ 已修 (BUG-425)。**P1 全部完成 (18/18)**。
3. **排期修(P2, 22 项)**: ~~性能优化(A-009 CountingSet 负计数)~~ ✅ 已修 (BUG-393)、~~线程/挂起(A-008/010)~~ ✅ 已修 (BUG-392/394)、~~UIA 常量(E-004)~~ ✅ 已修 (BUG-395)、~~性能优化(B-012/017)~~ ✅ 已修 (BUG-410/415)、~~重试/header(B-013)~~ ✅ 已修 (BUG-411)、~~线程/挂起(B-014/015/016)~~ ✅ 已修 (BUG-412/413/414)、~~Scheduler 悬空(B-011)~~ ✅ 已修 (BUG-403)、~~CloudBackup 传输安全(E-006)~~ ✅ 已修 (BUG-425, 已归并 P1)、~~AntiTamper 固定 salt(E-007)~~ ✅ 已修 (BUG-426)、~~TTS EInvalidCast(E-008)~~ ✅ 已修 (BUG-427)、~~重试退避(E-005)~~ ✅ 已修 (BUG-428)、~~Commander 会话字段锁外(D-007)~~ ✅ 已修 (BUG-429)、~~ProposalQueue 无界/无锁(D-008)~~ ✅ 已修 (BUG-430)。**P2 全部 22 项已修完**, P2 档清空, 剩余为 P3 (7 项) + 跨档项, 见下方清单。
4. **低优先(P3, 5 项)**: D-附加 (P3 风格说明, 非 bug 不计入编号发现数), ~~E-007/008~~ ✅ 已修 (BUG-426/427)。(A-011/B-018/019 已修)

---

## 进程级崩溃待办 (REVIEW5 之外的独立缺陷)

> ~~BUG-438 (DeepBaseTests.exe 全量 Runtime 216 @0x593A)~~ ✅ 已修复并归档 (2026-07-09), 详见 history.md「2026-07-09 ... 修复归档」段 + bugfix.md BUG-438.

### 全量单测清零 (2026-07-09) ✅
- [x] **全量 4206 测试全绿**: Passed **4203** / Failed **0** / Errored **0** / Leaked **0**, 无 Runtime 216. 起点基线 4157P/13F/28E + 全量崩 216 → 终点 4203P/0F/0E, 消除 +46 Passed / −13 Failed / −28 Errored / 216 崩溃. 命令 `run_tests.ps1 -Type Unit -CI -Platform Win64`.
- [x] **本轮 4 处生产 fix** (BUG-442~445, 详见 bugfix.md):
  - BUG-442 `Features/DeepBase.AutoUpdate.pas` DownloadUpdate 网络异常未吞 (契约要求设 LastError 返 False, 非抛异常穿透).
  - BUG-443 `Features/DeepBase.Speech.Registry.pas` Discover 的 IsAvailableFunc 探针无 try/except, SAPI/COM 无头 CI 抛 AV 穿透整个发现循环.
  - BUG-444 `Features/DeepBase.Commerce.PaymentBridge.pas` VerifyNotification 未包装 ThirdParty EPaymentSignError, 穿透 Commerce API 边界与 EDeepBaseCommercePaymentError 契约不匹配 (单 fixture 过/全量挂 的状态污染特征).
  - BUG-445 `Core/DeepBase.Metrics.pas` TestTimerStart 实现与测试期望不一致.
- [x] **各域 fixture 单独回归**: AutoUpdate 39/39, Speech.PBT 8/8, WeChatPay PaymentBridge 12/12, Metrics 全绿, Commerce 62/62.

### BUG-439: 同类"跨 except 块持有 E"潜在悬挂隐患 (衍生, 已修复 2026-07-09) ✅
- [x] **P2 修复**: BUG-438 排查期间发现两处同类 Delphi 异常对象生命周期隐患 (`on E: do FSomeField := E` 跨 except 块持有 RTL 自动释放的 E → 悬挂). **已全部修复**:
  - (1) `Core/DeepBase.Resilience.Retry.pas` `TRetryPolicy.TryExecute` 的 `Error := E` — **测试先行**: 新增回归测试 `Test_TryExecute_ErrorOutParam_NotDanglingAfterReturn`, 修复前确定性失败 (`Error.Message` 返回空串, 堆扰动复用已 Free 的 E 内存块 → use-after-free); 修复后克隆 `Exception.Create(E.Message)` → 122/122 通过.
  - (2) `DeepFlow/Source/AI/DeepFlow.Skill.Client.pas` `LLastException := E` — 同构确定性 AV (`raise LLastException` 操作 RTL 已 Free 的 E). DeepFlow 模块未接入 DeepBaseTests.dpr 测试工程、`THTTPClient` 构造函数内 new 不可注入, 故**记为已知盲改**: 克隆 + 保留 `ESkillClientException` 类型 (维持尾部 `is` 判断与未包装 re-raise 语义) + 多轮重试克隆泄漏防护 (`FreeAndNil` 覆盖前回收 + 尾部 `try/raise/finally` 释放).
- 详见 bugfix.md BUG-439「修复结论 (2026-07-09)」段.

## 规范系统剩余项目

### deepbase-speech
- [x] **阶段零: Speech 接线 (Registry Factory 闭包 + SAPIAdapter + Wiring 测试)** (2026-07-09 完成): `TSpeechRegistry` 加 `ASRFactory/TTSFactory/WakeWordFactory/VoiceprintFactory` 闭包字段 + `Discover` 透传; 6 后端 Register (Edge/StepFun/SenseVoice/SAPI×2 + Voiceprint) 注入工厂闭包, 解决 Service 跨包 uses 倒置; 新增 `Features/DeepBase.Speech.ASR.SAPIAdapter.pas` (`TDeepBaseSAPIASRAdapter` 适配 `TDeepBaseSAPIASR` 的 Start/Stop/CheckStatus → `ISpeechRecognizerEx`, Recognize 诚实返回 `srsProviderNotReady`); `TSpeechService.WireFromRegistry` 从 Registry 按优先级选首个非 nil 工厂闭包自动接线; `DeepBaseTests.dpr/dproj` 引入 Speech 单元 + `Test.DeepBase.Speech.Wiring.pas` (4 回归测: Factory 闭包存在性 / ASR 优先级排序 / SAPIAdapter 接口+Kind / Recognize 不支持诚实返回). **附带修复 BUG-440** (REVIEW5-FEAT-010 接口化 PermissionClient 致双重释放 → `[weak]` 弱持有). Speech 域 35/35 全绿, 0 回归. 详见 bugfix.md BUG-440.
- [ ] DeepLaunch 语音集成 (TranscribeFromMic/Speak/WakeWord/Voiceprint) — 需要 DeepLaunch 源码。

### speech-tts-migration — TTS 后端迁入 DeepBase + 三层回退 Resolver
> **来源**: DeepInput/DeepClip 商业化讨论 (2026-06-12)
> **已完成**: SPEECH-01 (TTS 迁入)、SPEECH-02 (Resolver 工厂)、SPEECH-03 (DeepInput 瘦身)

#### SPEECH-04: DeepClip 零成本接入
- [ ] `DeepClip/src/AI/DeepClip.AI.pas` 或新 `DeepClip/src/Speech/DeepClip.Speech.pas` 中调用 `TSpeechResolver`
- [ ] 语音输入集成: 录音 → VAD → ASR → 文字注入剪贴板
- [ ] 确认 `TClipCommerce` 的 `CanUseVoice` 与 License 联动

---

**维护**: 罗辑
