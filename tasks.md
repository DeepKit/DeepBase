# deepBase 开发任务
> **最后更新**: 2026-06-15
> **代码核实**: DeepBaseCore.dpk 编译通过 (0 errors, 6 new Core units registered)；DATA-P1-002/003 已收敛并归档
> **项目状态**: 框架主体已完成。数据平台 v0.7 (docs 32-36) 12 单元已落地。
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
- 数据平台 v0.7 的 Core 已加入编译门禁；Persistence/Features 包待环境修复后验证。

---

## 数据平台 v0.7 剩余任务

### DATA-P0-001: 微信运行时密钥偏移确认
- **状态**: 待开发
- **任务**:
- [ ] 在微信 4.1.10.30 运行时执行 WxDecryptProbe.exe，确认密钥偏移值。
- [ ] 将偏移值回填到 KeyCallback 的 KnownOffsets 列表。
- [ ] 解密 MicroMsg.db 后导出 MSG 表列名列表，更新 TWeChat4xAdapter 的 Schema 指纹前缀。

### DATA-P1-001: BCrypt 直接解密后端实现
- **状态**: 待开发
- **任务**:
- [ ] 实现 `TBCryptSQLiteReader` 类（复用探针的 DeriveSQLCipherKey + TryDecryptPage 算法）。
- [ ] 实现 `TryProbeCipherParams` 枚举探测（page_size × kdf_iter × hmac 组合）。
- [ ] 实现 `FindWeChatDataRoots` 和 `FindWeChatDB`（DB 路径自动发现）。
- [ ] 将 `beBCryptDirect` 后端集成到 `TExternalSQLiteReader`。

### DATA-P2-001: 单元测试与集成测试
- **状态**: 待开发
- **任务**:
- [ ] SchemaAdapter 单元测试 (MapRow/MapRows/Validate/ForbiddenFields)。
- [ ] ClipboardGuard 单元测试 (Save/Restore/SetContent/DoPaste/backup)。
- [ ] TExternalSQLiteReader 集成测试 (OpenReadOnly/SafeQuery/SafeQueryAsDict)。
- [ ] UIA Engine 集成测试 (FindElement/SetValue with mock IClipboardGuard)。

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
- **状态**: 进行中
- **任务**:
- [ ] 包 DAG 重切：Core→Services→{Persistence,Features}→{VCL,FMX}。
- [ ] Features 拆分 Commerce/LLM/Speech/Updater 等可选包。

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

### delphi-13-migration
- [ ] Skia4Delphi 7.1.0 unit path 变更。
- [ ] VCL/FMX 兼容性检查。IDE 组件面板确认。
- [ ] 96 DPI `.dfm`/`.fmx` 转换。下游兼容性验证。

### browser-automation
- [ ] `IBrowserSession`/`IBrowserAutomationSession` 接口合并。
- [ ] ResponseWaiter stale result 防护。

---

**维护**: 罗辑