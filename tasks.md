# deepBase 开发任务
> **最后更新**: 2026-06-15 (data-platform v0.7 added)
> **代码核实**: 2026-06-11 QA-P0 Unit 已跑到 DUnitX 摘要并通过：3661 found，3658 passed，3 ignored，0 failed，0 errored。已知残留：退出阶段仍打印 System.JSON/FastMM unexpected memory leak。
> **项目状态**: 框架主体已完成，当前任务只保留未完成项；已完成内容已归档到 `history.md`，缺陷记录写入 `bugfix.md`。
> **维护规则**: `tasks.md` 只保留当前待办和下一步任务；完成后移动到 `history.md`；Bug 修复和待修复缺陷记录写入 `bugfix.md`。

---

## 文档导航

| 文档 | 说明 |
|------|------|
| [README.md](README.md) | 项目说明 |
| [docs/00.quickstart.AI集成总览-ai-one-file.md](docs/00.quickstart.AI集成总览-ai-one-file.md) | 对外集成入口 |
| [docs/02.quickstart.下游接入流程-downstream-integration.md](docs/02.quickstart.下游接入流程-downstream-integration.md) | 下游项目接入说明 |
| [history.md](history.md) | 已完成任务归档 |
| [bugfix.md](bugfix.md) | Bug 修复和待修复缺陷记录 |

---

## 当前判断

- `DeepLaunch.exe` 对应源码未在当前 `D:\_Progs\02Business\DeepBase` 仓库中找到；当前仓库只包含可复用层（DeepShell、DeepFlow、DeepBaseRun、Tools/Tray 等）。DeepLaunch 专属 Grid/Workflow UI 修复需要在下游 DeepLaunch 源码目录继续落地。
- DeepShell / DeepFlow 可作为 DeepLaunch 工作流区的基础能力，但当前还缺一个下游工作流 UI 适配层：右键编辑、工作流格子绘制、主题同步、i18n 文本绑定都需要在 DeepLaunch 主程序或其 workflow grid 组件中实现。
- QA-P0 Unit 功能摘要已通过，但退出阶段 System.JSON/FastMM leak 仍是当前质量债。
- 商业化上线阻塞仍集中在 DB4 服务端签发、微信支付真实回调、备案/DNS/HTTPS、包 DAG 拆分和发布门禁可信化。

---

## P0 当前开发（Blocking）

### DL-P0-2026-06-15: DeepLaunch Grid / Workflow UI 缺陷修复
- **状态**: 待开发
- **来源**: 2026-06-15 用户反馈；缺陷登记见 `bugfix.md` 的 BUG-248 ~ BUG-251。
- **目标**: 修复 DeepLaunch 工作流区可用性、i18n 和主题同步问题。
- **任务**:
- [ ] 定位 DeepLaunch 源码目录或把 DeepLaunch 工作流 UI 接入当前仓库可维护模块；当前仓库未找到 `DeepLaunch.exe` 对应主程序源码。
- [ ] 修复 Grid 右键菜单“编辑工作流”空指针崩溃：右键命中测试、选中行/对象绑定、菜单命令执行前必须校验 workflow 对象非空，空数据时禁用编辑命令并给出安全提示。
- [ ] 先将工作流区和相关窗体的界面文本统一改成英文默认文案，移除硬编码中文 UI 文本。
- [ ] 接入 i18n：程序启动时检测操作系统语言，中文系统自动切到 `zh-CN`，英文或未知语言回退 `en-US`；运行期刷新工作流区、Grid、右键菜单、设置页和对话框文本。
- [ ] 接入主题同步：Grid、工作流画布、单元格、选中态、右键菜单、空状态和编辑窗体都应响应当前主题切换。
- [ ] 修复工作流区高度和绘制布局：目标绘制 10 个工作流格子，当前只显示 5 个且单元格下半部分被裁剪；需要按容器高度、行列数、DPI、滚动区域和单元格间距重新计算。
- [ ] 增加最小回归验证：空 Grid 右键、有效 workflow 右键编辑、语言启动检测、主题切换、10 格工作流绘制完整显示。

### COM-P0-001: DB4 收费后端与 deepKit 数据库
- **状态**: 进行中
- **任务**:
- [ ] 支付回调必须由服务器验签，服务器按产品价格发放 entitlement，禁止信任客户端提交的金额、状态或权益；微信支付真实商户配置后验收。
- [ ] 增加支付状态机：pending、paid、failed、closed、refunded，并要求所有状态变更写审计日志。
- [ ] 增加幂等键和重放保护：订单创建、支付回调、权益发放、许可证签发必须可重复调用但不重复发放。
- [ ] 服务端许可证机制必须替换：DB4 服务端私钥签发、撤销版本同步、公钥轮换和离线宽限策略仍需实部署。

### OPS-P0-2026-05-13: DeepKit 备案、DNS、HTTPS 和服务交接
- **状态**: 进行中
- **任务**:
- [ ] 完成 `deepkit.top` 备案。
- [ ] 完成 `deepkit.top` DNS 解析到 `124.221.136.137`；当前本机无法解析 `deepkit.top`，公网 IP + Host 访问被腾讯侧 DNSPod webblock 拦截。
- [ ] 配置 HTTPS 证书，优先使用 Let's Encrypt/certbot；完成后把 `DEEPKIT_PUBLIC_BASE_URL` 固化为 `https://deepkit.top`。
- [ ] 备案/DNS/HTTPS 完成后，从外网跑 `backend/scripts/acceptance-curl.md` 全链路验收。
- [ ] 微信支付接入后，补真实预下单、支付回调验签、重复回调幂等、退款撤权和对账验收。

### SEC-P0-001: 授权、权限和离线许可证安全边界
- **状态**: 进行中
- **任务**:
- [ ] 权益判断以 DB4 entitlement 为真源，本地许可证只作为离线缓存。
- [ ] 增加撤权、退款、封号、设备解绑后的许可证失效策略。
- [ ] 建立完整权限模型：feature code、license tier、quota、expires_at、device limit、offline grace days。
- [ ] 本地许可证缓存必须包含签名、公钥版本、撤销版本、签发时间和过期时间，超过宽限期必须回连服务器。
- [ ] 所有付费功能入口必须通过权限 API 检查，不能只判断本地 UI 状态或配置开关。

### QA-P0-001: 测试和 CI 门禁可信化
- **状态**: 进行中
- **任务**:
- [ ] 定位完整 Unit 退出阶段 System.JSON/FastMM unexpected memory leak：当前功能摘要已全绿，但退出仍报告 `TJSONObject x2`、`TJSONPair x5`、`TJSONString x9`、`TList<System.JSON.TJSONPair> x2` 等小块泄漏。
- [ ] 清理 0-fixture/未引用测试单元：`Test.DeepBase.Net`、`HttpServer`、`FileWatcher`、`Reflection`、`Math`、`Crypto.OpenSSL`、`i18n.Gender` 当前在默认 CI runner 下无注册 fixture。

### DB3-P0-2026-05-13: 下游产品 DB3/DB4 矩阵后续
- **状态**: 进行中
- **任务**:
- [ ] 为 DB3 各 schema 创建最小权限 runtime role，避免后端长期使用 admin 账号。
- [ ] 冻结并写入待补 DB4 SKU：`guideduse/deepguide/deepassist/deepinsight/deeprenew/deepdevlite/deepuitest`。
- [ ] 为 GuidedUse、DeepGuide、DeepAssist、DeepInsight、DeepRenew 补业务 API 文档和迁移脚本。

---

## P1 开发

### ARCH-P1-001: Core 瘦身和包分层
- **状态**: 进行中
- **任务**:
- [ ] 迁移/schema 剩余治理：继续审计现有脚本与 `Core/DeepBase.Schema.pas` 的剩余表结构漂移。
- [ ] 全局生命周期协议仍需统一：连接池/WorkerQueue/Scheduler/FileWatcher/Updater/EventBus 必须阻止新任务、取消/等待后台任务、归还或转移借出资源后再释放内部结构。
- [ ] 包 DAG 必须重切：`Core -> Services -> {Persistence, Features} -> {VCL, FMX}`，Services 禁止 `vcl/FireDAC/dbrtl`，运行时包不得包含测试辅助单元。
- [ ] `Features` 拆分 Commerce、LLM、Speech、Updater 等可选包，避免下游被迫引入全部重依赖。
- [ ] 将 LLM、Speech、Updater、Commerce、ICS adapter 作为可选包，不让最小桌面工具强制引入重依赖。

### UPD-P0-001: 免费版升级收费版和付费更新
- **状态**: 进行中
- **任务**:
- [ ] 服务器根据 entitlement 返回可见版本、下载地址、强制更新策略和签名 manifest。
- [ ] 更新包必须校验 hash 和签名，防止篡改、路径穿越和降级攻击。
- [ ] 未付费用户只能看到免费通道，付费用户才能看到 Pro/商业通道。
- [ ] 更新检查必须接入权限系统：免费版、试用版、Pro 版、企业版看到不同 release channel。
- [ ] 更新 manifest 必须包含 app_id、version、channel、min_version、package_hash、signature、download_url、release_notes。
- [ ] 增加更新失败回滚、断点/失败重试、强制更新、稍后安装、退出安装、静默下载策略。
- [ ] 增加 Updater 安全测试：签名错误、hash 错误、Zip Slip、降级攻击、断网、服务器返回越权通道。

### APP-P0-001: 桌面工具型产品上线公共能力套件
- **状态**: 进行中
- **任务**:
- [ ] 提供标准启动流程：初始化 DB1、本地配置、日志、异常、许可证、更新检查、托盘、热键。
- [ ] 提供标准用户入口：登录、查看当前版本、查看授权状态、升级到收费版、检查更新、反馈问题。
- [ ] 提供完整标准 UI 模板：VCL 和 FMX 至少各一个桌面工具模板，覆盖升级、授权、托盘、热键、LLM 配置。
- [ ] 明确 DB1 本地配置、DB2 本地业务、DB3 团队/共享业务、DB4 服务器收费授权的职责边界。

### DESKTOP-P1-2026-05-14-AUX: DeepShell governance/audit 默认值
- **状态**: 进行中
- **任务**:
- [ ] 真实 `DeepShell.GovernanceAdapter`（OCGS 包装）在第二阶段提供，默认 `gmObserve`，稳定后 L2/L3 切 `gmEnforce`。
- [ ] Shell 主窗体加一条命令 `shell.governance.toggleObserve`（仅 Pro/Admin 可见），方便在演示和验收期切换观察 / 阻断模式。

### HOTKEY-P1-001: 热键模块强化为桌面工具标准能力
- **状态**: 进行中
- **任务**:
- [ ] 保留现有 `DeepBase.Hotkeys` 配置、默认值、冲突检测能力。

### TRAY-P1-001: 托盘模块强化为桌面工具生命周期组件
- **状态**: 进行中
- **任务**:
- [ ] 增加 FMX Windows 托盘适配；非 Windows 平台明确降级策略。
- [ ] 与 SingleInstance、Updater、License、Hotkeys 联动，避免后台驻留时状态不同步（`Tools/Tray` 已接入 Hotkeys，剩余 SingleInstance/Updater/License 待完成）。

### SPEECH-P1-001: 语音录入和 ASR 组件化
- **状态**: 进行中
- **任务**:
- [ ] 支持按住说话、热键开始/停止录音、自动断句、录音状态 UI。
- [ ] 支持在线 ASR 和本地/离线兜底接口，具体实现可后续扩展。
- [ ] 增加 VCL/FMX 语音录入控件，支持把识别文本写入 Edit/Memo 或发送给 LLM。
- [ ] 增加测试：空音频、超时、取消、配额不足。

### QA-P1-001: 长期质量体系
- **状态**: 进行中
- **任务**:
- [ ] 增加 Updater 安全测试：签名、hash、Zip Slip、回滚、断网、灰度。
- [ ] 增加 LLM E2E mock：5 模型槽、fallback、生图失败、图片兜底、费用统计。
- [ ] 增加桌面工具模板 E2E：托盘、热键、自动升级、付费升级、权限控制、语音录入。
- [ ] CI 增加可选包矩阵：Minimal、Runtime、All、LLM、Speech、Commerce、Updater、ICS adapter。

### AUTOFIX-P1-2026-06-05: AutoFix 审查剩余项
- **状态**: 进行中
- **任务**:
- [ ] AF-M7: runner health signal 轮询改为退避或事件化。
- [ ] AF-M14: compiler.ps1 Delphi 环境路径改为自动检测/参数化。

---

## 数据平台 v0.7 剩余任务

### DATA-P0-001: 微信运行时密钥偏移确认
- **状态**: 待开发
- **任务**:
- [ ] 在微信 4.1.10.30 运行时执行 WxDecryptProbe.exe 确认密钥偏移值。
- [ ] 将偏移值回填到 KeyCallback 的 KnownOffsets 列表。
- [ ] 解密 MicroMsg.db 后导出 MSG 表列名列表，更新 WeChat4xAdapter Schema 指纹。

### DATA-P1-001: BCrypt 直接解密后端实现
- **状态**: 待开发
- **任务**:
- [ ] 实现 TBCryptSQLiteReader 类（基于探针的 DeriveSQLCipherKey + TryDecryptPage 算法）。
- [ ] 实现 TryProbeCipherParams 枚举探测算法。
- [ ] 实现 FindWeChatDB 自动路径发现。
- [ ] 将 beBCryptDirect 后端集成到 TExternalSQLiteReader.BackendOpen。

### DATA-P1-002: 缺失实现补全
- **状态**: 待开发
- **任务**:
- [ ] TUIAMappingRegistry 补全 Add/TryGetValue 方法。
- [ ] 实现 ParseUIAMappingJSON 解析逻辑。
- [ ] LoadMappingsFromConfig 中恢复 RegisterMapping 注入调用。
- [ ] CheckHookHealth 在 WindowMonitor 中注册定时器触发（当前已实现但从未被调用）。
- [ ] GetOriginalContent 从存根实现为读取 FOriginalData 的 CF_UNICODETEXT 格式。

### DATA-P1-003: 编译验证与 .dpk
- **状态**: 待开发
- **任务**:
- [ ] dcc64 编译全部 12 新单元 + 3 .dpk，验证 package 门禁通过。
- [ ] 修复 UIAutomationClient_TLB 的 VCL 依赖（可能需要移到 dclDeepBaseVCL 或创建独立 design-time 包）。

### DATA-P2-001: 单元测试与集成测试
- **状态**: 待开发
- **任务**:
- [ ] SchemaAdapter 单元测试（MapRow/MapRows/Validate/ForbiddenFields）。
- [ ] ClipboardGuard 单元测试（Save/Restore/SetContent/DoPaste/backup）。
- [ ] WindowMonitor 集成测试（SetWinEventHook/AddWatchTarget/callback）。
- [ ] TExternalSQLiteReader 集成测试（OpenReadOnly/SafeQuery/SafeQueryAsDict）。
- [ ] UIA Engine 集成测试（FindElement/SetValue with mock IClipboardGuard）。

## P2 中期整理

### OPS-P2-001: 服务器可观测性和运维
- **状态**: 待开发
- **任务**:
- [ ] 后端提供 `/health`、`/metrics`、审计日志和告警。
- [ ] 监控支付回调成功率、权益发放失败率、许可证签发失败率、升级成功率。
- [ ] 建立 migration 执行时长、失败、回滚统计。

### PRODUCT-P2-001: 商业生命周期增强
- **状态**: 待开发
- **任务**:
- [ ] 支持多产品、多租户、组织席位、设备限制。
- [ ] 支持续费、升级、优惠码、发票、退款撤权。
- [ ] 支持离线宽限期和上线后的许可证重新对账。

### SPEC-P2-001: Commerce 后端契约未完成实施步骤
- **状态**: 待开发
- **任务**:
- [ ] 步骤 5: 实现微信支付 notify 验签和幂等确认。
- [ ] 步骤 6: 跑通一个下游端到端样例。
- [ ] 步骤 7: 评估 CloudBase/Firebase/Supabase 等托管后端是否需要官方适配。

### DOC-P3-001: 视频教程
- **状态**: 待开发
- **任务**:
- [ ] 在 P0/P1 发布治理完成后再制作视频教程。

---

## 规范系统剩余项目

### deepbase-speech
- [ ] GitHub Actions CI 验证。
- [ ] SAPI 语音占用检测（需交互式麦克风，Spike 中跳过）。
- [ ] Types PBT 测试：PCM16 round-trip、Float round-trip、DurationMs、PCM16ToFloat range。
- [ ] Config PBT 读写幂等测试（P12）。
- [ ] Registry/Policy/Runtime/Schema/ASR.SAPI/TTS.SAPI 单元测试。
- [ ] dpk 分包验证（5 dpk 文件）。
- [ ] SAPI Live Streaming + WinMM 低延迟 + AudioSession 仲裁单元测试。
- [ ] DeepInput 回归测试（替换后的语音集成）。
- [ ] DeepLaunch 语音集成（TranscribeFromMic、Speak）、设置页 + 麦克风授权、M4 集成测试。
- [ ] WakeWord 词表 round-trip PBT、单元测试、DeepLaunch WakeWord 集成。
- [ ] 全模块回归测试、合规文档、Trace 验收、Stop time limits。
- [ ] Voiceprint MFCC/DTW/Verify PBT、features_hmac 验证、DeepLaunch Voiceprint 集成、完整单元测试。
- [ ] IntentParser PBT、WinRT ASR、Whisper.cpp、Cloud TTS Backend。

### delphi-13-migration
- [ ] 确认 Skia4Delphi 7.1.0 unit path 变更并更新所有 dpk Search Path。
- [ ] VCL Styles / Win11 兼容性检查；FMX 控件在 13.1 下的渲染检查。
- [ ] dclDeepBaseCore / dclDeepBaseVCL / dclDeepBaseFMX IDE Install，并确认 IDE 组件面板正常。
- [ ] 启用 96 DPI 保存模式，转换所有 `.dfm` / `.fmx`，验证 UI 无错位。
- [ ] 下游兼容性验证：Assayer、FMX 项目、VCL 项目。
- [ ] 合并 upgrade/delphi-13 到 main，打标签 `d13-deepbase-done`，通知 4 个 AI 团队。

### feedback-backend-service
- [ ] 登录 AipexBase 管理端，创建新应用并获取 API Key。
- [ ] 创建 feedbacks、system_infos、attachments、comments、notifications、feedback_tags 表并配置权限。
- [ ] 修改 `DeepBase.Feedback.pas`，适配提交、详情、列表、tracking code 查询、评论、通知和附件。
- [ ] 实现 tracking code、状态变更通知、评论通知、已关闭反馈评论限制。
- [ ] 增加单元测试、属性测试和集成测试。

### browser-automation
- [ ] `IBrowserSession` / `IBrowserAutomationSession` 接口合并。
- [ ] ResponseWaiter stale result 防护。
- [ ] CDP.WaitForSelector 取消 token。

---

**维护**: 罗辑
