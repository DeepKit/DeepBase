# deepBase 开发任务
> **最后更新**: 2026-06-16
> **代码核实**: 10 专家评估完成，P0 (12) + P1 (12) = 24 项修复全部完成，编译通过。
> **项目状态**: 框架主体已完成。数据平台 v0.7 12 单元已落地。P0/P1 安全修复已收敛。
> **维护规则**: `tasks.md` 只保留当前待办和下一步任务；完成后移动到 `history.md`；Bug 修复和待修复缺陷记录写入 `bugfix.md`。

---

## 文档导航

| 文档 | 说明 |
|------|------|
| [README.md](README.md) | 项目说明 |
| [docs/00.quickstart.AI集成总览-ai-one-file.md](docs/00.quickstart.AI集成总览-ai-one-file.md) | 对外集成入口 |
| [docs/32-36](docs/32.data.SQLCipher外部数据库读取-开发规格.md) | 数据平台 v0.7 设计规格 (5+1 文档) |
| [history.md](history.md) | 已完成任务归档 |
| [bugfix.md](bugfix.md) | Bug 修复和待修复缺陷记录 |

---

## 当前判断

- `DeepLaunch.exe` 对应源码未在当前仓库中找到；DeepLaunch 专属 Grid/Workflow UI 修复需要在下游 DeepLaunch 源码目录继续落地。
- 商业化上线阻塞仍集中在 DB4 服务端签发、微信支付真实回调、备案/DNS/HTTPS。
- 数据平台 v0.7: DeepBaseCore.dpk、DeepBasePersistence.dpk、DeepBaseServices.dpk 全部编译通过 (0 errors)。DeepBasePlatform.dpk / DeepBaseFeatures.dpk 存在预存编译错误（见 ARCH-P1-002），与本次数据平台工作无关。

---

## 数据平台 v0.7 剩余任务

### DATA-P0-001: 微信运行时密钥偏移确认
- **状态**: 待开发 (被阻塞 — 需微信 4.1.10.30 + 管理员权限)
- **阻塞原因**: 运行时探针需要目标机器上有微信进程运行才能扫描内存，同事有权限/环境
- **任务**:
- [ ] 在微信 4.1.10.30 运行时执行 WxDecryptProbe.exe，确认密钥偏移值。
- [ ] 将偏移值回填到 KeyCallback 的 KnownOffsets 列表。
- [ ] 解密 MicroMsg.db 后导出 MSG 表列名列表，更新 TWeChat4xAdapter 的 Schema 指纹前缀。

### DATA-P1-001: BCrypt 直接解密后端 ✅
- **状态**: 已完成
- **完成内容**: TBCryptSQLiteReader 类 (DeepBase.External.BCryptDecrypt.pas, 320 LOC)、DeriveSQLCipherKey (PBKDF2-HMAC-SHA1)、TryDecryptPage (AES-CBC + HMAC verify)、TryProbeCipherParams、beBCryptDirect 后端集成至 TExternalSQLiteReader。

### DATA-P2-001: 单元测试与集成测试 ✅
- **状态**: 已完成
- **完成内容**: SchemaAdapter 测试 (36 tests, DeepBase.DataPlatform.Tests.pas)、ClipboardGuard 测试 (6 fixtures)、TExternalSQLiteReader 集成测试 (SafeQuery/SafeQueryAsDict/GetSchema/GetSchemaFingerprint)。测试文件位于 Tests/DeepBase.DataPlatform.Tests.pas。

### ARCH-P1-002: DeepBasePlatform.dpk / DeepBaseFeatures.dpk 预存编译错误
- **状态**: 待修复 (同事的模块拆分引入，与数据平台工作无关)
- **错误详情**:
  - `DeepBasePlatform.dpk`: `DeepBase.Desktop.Lifecycle.pas(7)` → `Unit 'DeepBase.Commerce.Permissions' not found` — 该单元现在在 DeepBaseCommerce.dpk 中，Platform 的 `requires` 缺少 DeepBaseCommerce
  - `DeepBaseFeatures.dpk`: 因 DeepBasePlatform 编译失败而级联失败（Features → Platform 依赖链）
- **任务**:
- [ ] DeepBasePlatform.dpk `requires` 增加 `DeepBaseCommerce`（或等效修复）。
- [ ] 验证 DeepBasePlatform.dpk → DeepBaseFeatures.dpk → DeepBaseLLM.dpk 全链路编译。

---

## P0 当前开发（Blocking）

### DL-P0-2026-06-15: DeepLaunch Grid / Workflow UI 缺陷修复
- **状态**: 待开发
- **来源**: BUG-248 ~ BUG-251 (bugfix.md)
- **任务**:
- [ ] 定位 DeepLaunch 源码目录。
- [ ] 修复 Grid 右键菜单空指针崩溃（BUG-248）。
- [ ] 工作流区界面文本默认英文 + 接入 i18n（BUG-249）。
- [ ] 接入主题同步：Grid/工作流画布/单元格/选中态/编辑窗体（BUG-250）。
- [ ] 修复工作流区高度和绘制布局（BUG-251）。
- [ ] 增加最小回归验证。

### COM-P0-001: DB4 收费后端与 deepKit 数据库
- **状态**: 进行中
- **任务**:
- [ ] 支付回调服务器验签 + 状态机 (pending→paid→failed→closed→refunded)。
- [ ] 幂等键和重放保护。
- [ ] DB4 服务端私钥签发许可证、撤销版本同步、公钥轮换。

### OPS-P0-2026-05-13: DeepKit 备案、DNS、HTTPS
- **状态**: 进行中
- **任务**:
- [ ] 完成 `deepkit.top` 备案 + DNS 解析 + HTTPS 证书。
- [ ] 微信支付接入后，补真实预下单、回调验签、退款撤权和对账。

### QA-P0-001: 测试和 CI 门禁可信化
- **状态**: 进行中
- **任务**:
- [ ] 退出阶段 System.JSON/FastMM memory leak 定位修复。
- [ ] 清理 0-fixture 测试单元。

---

## P1 开发

### ARCH-P1-001: Core 瘦身和包分层
- **状态**: 进行中（Features 拆分已完成，DAG 重切待续）
- **任务**:
- [x] Features 拆分 LLM/Inference/IntentClarification/Browser/Commerce/Platform 等可选包。
- [ ] 包 DAG 重切：Core→Services→{Persistence,Features}→{VCL,FMX}。

### UPD-P0-001: 免费版升级收费版和付费更新
- **状态**: 进行中
- **任务**:
- [ ] 服务器按 entitlement 返回版本、下载地址、签名 manifest。
- [ ] 更新包校验 hash 和签名。未付费用户仅可见免费通道。
- [ ] 增加 Updater 安全测试：签名错误、Zip Slip、降级攻击。

### QA-P1-001: 长期质量体系
- **状态**: 进行中
- **任务**:
- [ ] Updater 安全测试、LLM E2E mock、桌面工具模板 E2E。
- [ ] CI 增加可选包矩阵 (Minimal/Runtime/All/LLM/Speech/Commerce/Updater)。

---

## P2 中期整理

### OPS-P2-001: 服务器可观测性和运维
- [ ] 后端 `/health`、`/metrics`、审计日志和告警。
- [ ] 支付回调成功率、权益发放失败率、许可证签发失败率监控。

### PRODUCT-P2-001: 商业生命周期增强
- [ ] 多产品、多租户、组织席位、续费、升级、优惠码、退款撤权。

---

## 规范系统剩余项目

### deepbase-speech
- [ ] GitHub Actions CI、SAPI 语音占用检测、Types/Config/Registry PBT 测试。
- [ ] dpk 分包验证 (5 dpk)。
- [ ] DeepLaunch 语音集成 (TranscribeFromMic/Speak/WakeWord/Voiceprint)。

### speech-tts-migration — TTS 后端迁入 DeepBase + 三层回退 Resolver
> **来源**: DeepInput/DeepClip 商业化讨论 (2026-06-12)
> **目标**: 将 DeepInput 中的 Edge TTS / StepFun TTS 下沉到 DeepBase，新增统一 ASR/TTS Resolver（三层回退），使 DeepInput 瘦身 + DeepClip/DeepFlow 零成本接入语音能力。
> **总工时**: ~5h

#### SPEECH-01: TTS 后端迁入
- [ ] `DeepBase.Speech.TTS.Edge.pas` ← 从 `DeepInput/uTTS.Edge.pas` 迁移，适配 `ITTSBackend` 接口，自注册到 `TSpeechRegistry`
- [ ] `DeepBase.Speech.TTS.StepFun.pas` ← 从 `DeepInput/uTTS.StepFun.pas` 迁移，适配 `ITTSBackend` 接口，自注册到 `TSpeechRegistry`
- [ ] Edge TTS：WinHTTP WebSocket 无需额外 DLL，确认在 DeepBase 中无新增依赖

#### SPEECH-02: 统一 Resolver 工厂
- [ ] 新增 `DeepBase.Speech.Resolver.pas`
- [ ] `ResolveASR(ALicensing)` — 三层回退：SenseVoice(PRO+已安装) → Baidu(用户配Key) → SAPI(默认)
- [ ] `ResolveTTS(ALicensing)` — 三层回退：Edge(免费优先) → SAPI(离线兜底) → StepFun(用户配Key可选覆盖)
- [ ] `ALicensing` 参数：通过 `ILicensing.HasFeature('sensevoice_asr')` 判断 PRO 等级

#### SPEECH-03: DeepInput 瘦身
- [ ] 删除 `uOnlineASR.pas, uTTS.pas, uTTS.Edge.pas, uTTS.StepFun.pas, uTTS.Local.pas`
- [ ] `uMain.pas` → 调用 `TSpeechResolver.ResolveASR / ResolveTTS`
- [ ] `uAudioCapture.pas, uVAD.pas` 评估：替换为 `DeepBase.Speech.Audio.WinMM` + `DeepBase.Speech.VAD`

#### SPEECH-04: DeepClip 零成本接入
- [ ] `DeepClip/src/AI/DeepClip.AI.pas` 或新 `DeepClip/src/Speech/DeepClip.Speech.pas` 中调用 `TSpeechResolver`
- [ ] 语音输入集成：录音 → VAD → ASR → 文字注入剪贴板
- [ ] 确认 `TClipCommerce` 的 `CanUseVoice` 与 License 联动

### delphi-13-migration
- [ ] Skia4Delphi 7.1.0 unit path 变更。
- [ ] VCL/FMX 兼容性检查。IDE 组件面板确认。
- [ ] 96 DPI `.dfm`/`.fmx` 转换。下游兼容性验证。

### browser-automation
- [ ] `IBrowserSession`/`IBrowserAutomationSession` 接口合并。
- [ ] ResponseWaiter stale result 防护。

---

**维护**: 罗辑