# UniBase 开发任务

> **最后更新**: 2026-05-06
> **项目状态**: 框架主体功能完成，封板前质量门禁进行中
> **维护规则**: `tasks.md` 只保留当前待办和下一步任务；已完成任务移入 `history.md`；Bug 修复记录写入 `bugfix.md`。

---

## 文档导航

| 文档 | 说明 |
|------|------|
| [history.md](history.md) | 已完成任务和功能迭代归档 |
| [bugfix.md](bugfix.md) | Bug 修复记录 |
| [docs/UniBase-Integration-OneFile.md](docs/UniBase-Integration-OneFile.md) | 对外唯一集成入口 |
| [docs/Commerce-Backend-Adapter-Spec.md](docs/Commerce-Backend-Adapter-Spec.md) | Commerce 生产后端契约 |
| [README.md](README.md) | 项目说明 |

---

## 当前判断

- P0 封板阻塞全部解决（PKG-001/002/003、TEST-001）。
- P1 进行中：SEC-001/003、ARCH-046、QUAL-001、COMMERCE-002。
- Commerce MVP 已完成，生产适配继续推进。

---

## P0 封板阻塞（Blocking）

### PKG-001: 86 个孤立 .pas 文件注册到 .dpk 包 ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**:
  - 32 个 Core/ 文件 → UniBaseCore.dpk（纯逻辑，无 VCL/FMX/FireDAC）
  - 22 个 Core/ 文件 → UniBaseServices.dpk（基础设施服务）
  - 3 个 Core/ 文件 → UniBaseFeatures.dpk（LLM.Manager/BillingClient/ImportExport）
  - 4 个 Core/ 文件 → UniBaseVCL.dpk（Export/SplashScreen/VirtualScroll/TestHelper，含 VCL 依赖）
  - 16 个 VCL/ 文件 → UniBaseVCL.dpk
  - 13 个 FMX/ 文件 → UniBaseFMX.dpkg（含 UniBaseFeatures requires）
  - 1 个 Persistence/ 文件 → UniBasePersistence.dpk

### PKG-002: UniBase.Math 双包冲突修复 ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**: Core/UniBase.Math.pas 已在之前删除；Features/UniBase.Math.pas 注册在 UniBaseServices.dpk，无冲突。

### PKG-003: 删除重复 Core/UniBase.Unlock.pas ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**: Core/UniBase.Unlock.pas 与 Features/UniBase.Unlock.pas 完全相同。删除 Core/ 副本，保留 Features/ 在 UniBaseFeatures.dpk 中注册。

### TEST-001: 53 个测试文件注册到 UniBaseTests.dpr ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**:
  - 注册 53 个缺失测试文件到 UniBaseTests.dpr
  - 排除 Test.UniBase.FMX（需 FMX 框架，不适用于 VCL 控制台 runner）
  - 排除 Test.UniBase.CLI.Interactive/Pipeline/SSH（引用已删除的 Core/ 模块）

---

## P1 封板重要（Important）

### SEC-001: 非 Windows AES XOR fallback 替换为 OpenSSL ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**:
  - `UniBase.Crypto.OpenSSL.pas` 新增 `EVP_aes_256_cbc` 符号加载 + `OpenSSL_AES256CBC_Encrypt/Decrypt` 函数
  - `UniBase.Crypto.pas` 的 `{$ELSE}` 分支从 XOR 伪加密替换为 OpenSSL AES-256-CBC 真加密
  - 保持 Windows 平台继续使用 CNG (BCrypt)，macOS/Linux 使用 OpenSSL EVP

### SEC-002: 移除硬编码默认 Salt ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**:
  - `TAESCrypto.SetKeyFromPassword` 现在要求必传 Salt 参数（移除 `= nil` 默认值）
  - 无 Salt 时抛出 `ECryptoException` 而非使用弱默认值
  - `TSimpleCrypto` 增加 `DeriveSalt` 方法，基于密码确定性派生 Salt
  - 所有测试文件已更新传入 Salt

### SEC-003: 插件签名验证实现 ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**:
  - Windows: 使用 `WinVerifyTrust` (wintrust.dll) 验证 Authenticode 数字签名
  - 签名验证失败时拒绝加载并记录日志
  - 非 Windows 暂放行 + 日志警告（后续可用 OpenSSL 代码签名验证补充）

### ARCH-046: Exception→Manager 循环依赖解除 ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**:
  - `UniBase.Exception.pas` 不再 `uses UniBase.Manager`
  - 改为通过 `SetManagerCallbacks` 注册 3 个匿名函数（IsInitialized、GetLogger、GetConfigDB）
  - Manager 在 `InitializeModules` 之后注册回调，解除编译时循环依赖
  - VCL/FMX ExceptionAdapter 无需修改（API 向后兼容）

### QUAL-001: 438 处 .Free → FreeAndNil 规范化 ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**:
  - 82 个文件中 438 处析构函数内 `F*.Free` → `FreeAndNil(F*)`
  - 13 个文件中 19 处字段重新赋值前 `F*.Free` → `FreeAndNil(F*)`
  - 局部变量 `try/finally` 中的 `.Free` 不变（安全）

### COMMERCE-002: 生产存储与支付网关适配器
- **状态**: 🟡 进行中
- **优先级**: P1
- **目标**: 在 Commerce MVP 基础上补齐真实后端、真实支付和多端统一权益闭环。
- **已完成**:
  - [x] COMMERCE-002A: 后端契约文档
  - [x] COMMERCE-002B: 后端 API 路由/JSON 字段契约 + 单元测试
  - [x] COMMERCE-002C: `TCommerceHttpStorage` HTTP 后端适配器
  - [x] COMMERCE-002D: `TCommerceHttpPaymentGateway` 微信支付代理
- **待办**:
  - [ ] COMMERCE-002E: 支付通知确认流程（验签、查单、金额/币种/订单号校验、幂等确认）
  - [ ] COMMERCE-002F: 下游端到端最小样例

---

## P2 后续优化

### VERSION-001: 统一版本号 + Version.inc ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**:
  - 在 `UniBase.Consts.pas` 添加 `UNIBASE_VERSION_MAJOR/MINOR/PATCH/STRING` 常量
  - 版本号提升至 1.0.2

### DOC-005: README 示例修复 ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**: 修复 CRUDApp 模板 `_('text')` → `T('text')`

### ARCH-045: 包隐式导入告警清理 ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**:
  - UniBaseServices.dpk requires 加入 `vcl`, `IndySystem`, `IndyCore`, `IndyProtocols`（消除隐式导入冲突）
  - UniBaseCore.dpk 加入 `UniBase.Security`（Manager 依赖）、移除 `UniBase.i18n.Gender`（编译器解析 Bug）
  - UniBasePersistence.dpk 加入 `{$IMPORTEDDATA ON}`
  - 修复 12 个源文件编译错误：TRttiContext→.Free、TRegEx 异常类型、TTask/TThread 调用语法、TPanel.OnPaint→TPaintBox、bsSingle、CF_TEXT、FMX 类型冲突等
  - `Profile All` 6 个包全部零 Error 编译通过

### MAINT-002: 单元测试编译修复 + 覆盖率提升 ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**:
  - 51 个测试文件编译错误修复（AreEqual 类型推断、WillRaise 重载、匿名方法类型转换等）
  - 53 个测试文件注册到 UniBaseTests.dpr
  - Win64 DCU 编译脚本（compile_packages_win64.ps1），176 个 DCU 零错误
  - 180,479 行代码编译通过，0 Error

### PUBL-105: 工具项目接入 AboutFrame + aboutMeImages
- **状态**: 🟡 进行中（UniBase 侧已完成，待人工集成）
- **优先级**: P2

### ECO-002: 社区扩展包后续阶段
- **状态**: 🔲 待开始
- **优先级**: P2
- **范围**: 评估 CloudBase/Firebase/Supabase 适配、支付宝/Stripe/PayPal 接入

### FWK-001: 系统托盘模块（Shell_NotifyIcon） ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**:
  - `Core/UniBase.TrayIcon.pas`（~230 行）：静态类 + Shell_NotifyIcon API，气泡通知、Tooltip、PopupMenu 适配器接口
  - `VCL/UniBase.VCL.TrayIcon.pas`（~130 行）：TUniTrayIcon 组件 + TVclPopupMenuAdapter
  - `Tests/Test.UniBase.TrayIcon.pas`：12 个测试用例
  - 注册到 UniBaseCore.dpk + UniBaseVCL.dpk

### FWK-002: Serialization XML 反序列化 ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**:
  - 实现 `TXmlSerializer.DoDeserialize`：标签解析→属性赋值
  - 支持 Integer/Int64/Float/DateTime/String/Boolean/Enum 类型
  - 支持嵌套对象、IValueConverter、属性特性兼容
  - 自动跳过 XML 声明、按 ClassName 查找根元素

### FWK-003: Scheduler 任务持久化 ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**:
  - 新增 `IJobStore` 接口 + `TTaskMeta` 记录
  - `TTaskScheduler.SetJobStore`/`GetPersistedTaskIds`/`SaveTaskMeta`
  - 修复 `Stop()` 竞态：等待运行中任务完成（最多 10 秒）
  - 新增 `FShutdownEvent` 用于优雅关机

### FWK-004: VCL/FMX I18n 控件补齐 ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**:
  - VCL 新增 6 个控件：TI18nCheckBox, TI18nRadioButton, TI18nGroupBox, TI18nTabSheet, TI18nBitBtn, TI18nMenuItem
  - FMX 新增 2 个控件：TFMXi18nCheckBox, TFMXi18nGroupBox
  - 所有控件遵循 TextKey + Loaded 订阅 + Destroy 取消订阅模式

### FWK-005: FMX Theme 桥接 Core Theme ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**:
  - `UniBase.FMX.Theme` initialization 中注册 Core `TUniBaseTheme.SetPlatformAdapter`
  - 支持 light/dark/system 三种模式切换
  - 桥接 Apply/Exists/Current 四个回调

### FWK-006: Export 新增 JSON 格式 ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**:
  - 新增 `DataSetToJSON`/`GridToJSON`/`ArrayToJSON`/`ToJSON`
  - 使用 System.JSON 生成格式化 JSON 数组输出

### FWK-007: Updater 非 Windows RSA 签名验证 ✅
- **状态**: ✅ 已完成
- **完成日期**: 2026-05-06
- **内容**:
  - `UniBase.Crypto.OpenSSL.pas` 新增 `OpenSSL_RSAVerifySHA256` 函数
  - 加载 9 个 OpenSSL 符号（BIO、EVP_PKEY、EVP_MD_CTX、DigestVerify 系列）
  - `UniBase.Updater.pas` 非 Windows 分支从 stub 替换为 OpenSSL RSA-SHA256 真实验证
  - 修复 uses 子句非 Windows 平台尾逗号编译问题

---

## P3 低优先级

### DOC-004: 视频教程
- **状态**: 🔲 待开始
- **优先级**: P3

---

## 已完成任务归档

- 2026-05-06 FWK-007（Updater 非 Windows RSA 签名验证）、FWK-004 FMX 侧补齐（TFMXi18nCheckBox、TFMXi18nGroupBox）已完成。
- 2026-05-06 SEC-001（XOR→OpenSSL）、SEC-003（插件签名验证）已完成。
- 2026-05-06 DOC-OPT-001/002（文档编号统一 + OneFile 创建 + 过期清理 + 专家评估）已归档到 `history.md`。
- 2026-05-05 架构整理、Commerce MVP、HTTP 后端存储/支付网关适配已归档到 `history.md`。
- BUG-061~064 已记录到 `bugfix.md`。

---

**维护者**: 李冰、鲁班、Claude
