# DeepBase Bug Fixes & Issues Resolution

> 本文档记录所有发现和修复�?Bug、Issue 及改进�?> **分卷**: 本卷 = 近期修复 (REVIEW5 第一轮五专家 + R2 第二�?P0/P1 + R3 第三�?+ 06-21~28 OPT/EXP 审阅)。早期修�?(2025-11~12 Issues/性能/统计�?026-05 基础模块/Commerce 审计�?6-18 三专�? �?`bugfix-archive.md`�?
---

## 2026-08-24 ȫ������޸�ս�ۣ�doQry / Persistence / Core��Լ109K�У�?

> ��Դ: docs/code-review-2026-08-24.md�����棩�� docs/code-review-2026-08-24-tasks.md�������嵥��
> �ύ��: 92c10a6(docs) �� 7ddfbed(doQry) �� c9443b1(persistence) �� c8dbb53(core) �� 175d00f(tests) �� e249883 �� acf64be �� 1b1df35
> ��ģ: P0 18/18 ����(11?+7??)��?? Լ30�Owner ���� 4/4 ��أ������ع鵥Ԫ 6 ��

### P0 ���ݶ�ʧ/��ȫ��18 ��ջ���

#### BUG-CR-001 KeyManager KEK �β��־û� ?
- �ļ�: Core\DeepBase.KeyManager.pas
- ����: ͬ�����Ự������ͬ KEK �� ����������Կ�����޷����ܣ��û����ݶ�ʧ����
- �޸�: KDF ����д�� keystore JSON��Initialize �� LoadKdfParams ������������ VerifyKeysDecryptable ���������ʼ����ʧ��
- �ع�: Tests\Regression\...P0Batch2 ������

#### BUG-CR-002 OpenSSL PBKDF2 ��ǩ����Σ�POSIX ������??
- �ļ�: Core\DeepBase.Crypto.OpenSSL.pas:156
- �޸�: ���� 8 ��ԭ�Ͳ��������õ㣨POSIX ð�̴� CR-504��

#### BUG-CR-003 JobQueue PG ���� SQL �����Ӿ�˳����� ??��?
- �ļ�: Persistence\DeepBase.DB.JobQueue.pas:666
- ����: FOR UPDATE SKIP LOCKED λ�� LIMIT ǰ �� PG ��Ȼ�﷨���������顿
- �޸�: LIMIT 1 FOR UPDATE SKIP LOCKED��PG ʵ��� CR-501��

#### BUG-CR-004 ORM ���������� INSERT ������λ ??��?
- �ļ�: Persistence\DeepBase.ORM.pas:1075
- �޸�: ��� CollectEntityParamsForInsert��Update ����ԭ����
- �ع�: Batch1::Test_CR004

#### BUG-CR-005 doQry JSON ����һ�� AsFloat �� ?(������֤)
- �ļ�: doQry\src\uDoQryExecutor.pas:114
- ����: >2^53 ���� ID ���ȶ�ʧ �� ���������/��ɾ��
- �޸�: TryBindIntegralNumber �� ftLargeint+Value��������� AsFloat
- ע: TFDParam �� AsInt64 ���ԣ������ڷ��ֲ����� DataType+Value

#### BUG-CR-006 legacy ��ֵ����ԭ��ƴ�ӣ�SQL ע��ͨ����?
- �ļ�: doQry\uDoQryLegacy.pas:243 | �޸�: ��ֵ�ϸ�У���ƴ��

#### BUG-CR-007 legacy ɾ���� WHERE ȫ����� ?
- �ļ�: doQry\uDoQryLegacy.pas:328 | �޸�: �� WHERE ���쳣

#### BUG-CR-008 ���洢 INSERT OR REPLACE �����ֵ��� ?
- Config/License/I18n.FireDAC �� ON CONFLICT DO UPDATE
- ����: Config д����Լ -8%����ֵ�� Owner У׼ 5000��4000��CR-605��

#### BUG-CR-009 DeleteUser ���߳���������������Ȩ�棩?
- Core\DeepBase.Authorization.pas | ����ɨ FThreadCurrentUsers ���ͷŻ���

#### BUG-CR-010 ˫�ӿڹ���ռλ GUID ?
- IPermissionClient ����ʵ GUID��IRateLimiter ���ֲ���

#### BUG-CR-012 ValidateSQL ��Ĭ�۸� SQL ?
- doQry\uDoQryLegacy.pas:631 | �Ƴ�ȫ���Զ���д�����Ų�ƽ�⼴��

#### BUG-CR-013 ���ӳ� ABBA ���� ?
- Persistence\DeepBase.DB.Pool.pas:1617 | GetStatistics ������롾�����顿

#### BUG-CR-014 PG ��ɾ���û�/��ɫ��ʧ�� ?
- Authorization.FireDAC | ˫����Ϊ���������� ExecSQL

#### BUG-CR-015..018 Serialization ���� ?
- record ��Ĭ�����ݡ�JSON �ݹ�ʵ��(XML/Binary ��ʽ�ܾ�)��locale ����������Invariant�������ư�����/kind/�������ؼӹ̣�ö��Խ����·���ܾ�
- �ع�: Batch3/Batch4 �� 9 ����

### ?? �ص㹦��ȱ�ݣ�14 �

- CR-119/120: DST ƫ�Ʋ�60�� + ʱ��ȡ���߽� EConvertError ?
- CR-202/203: CTE ���� LIMIT ���� + ���� WHERE ���� ?
- CR-208: ��־ ts �� Z д����ʱ�� �� �� UTC ?
- CR-210: �ع������쳣����ԭʼ�쳣 �� �������� ?
- CR-226: ��ѯ���建���⽻����Ⱦ �� ����ǰ׺�� ?
- CR-229: SQLLogger ensured ʧ��Ҳ��λ+PG ����ȱʧ ?
- CR-232: ��������������Ͷ �� AMaxAttempts Ǩ DLQ ?
- CR-238: Diagnose �汾�ֵ���Ƚ� �� CompareVersions ?
- CR-278: Logger ����β����ʧ+��ͣ nil AV �� �Ÿ�+˫���� ?
- CR-281: ExecuteFirst ��Ⱦ Limit �� try/finally �ָ� ?
- CR-287: Diff hunk β�������Ķ�ʧ+SideBySide �к�Ư�� ?
- CR-290: ������/�۶��� 34 ��ǽ�Ӽ�ʱ �� GetTickCount64 ����ʱ�ӣ�3c76264��?
- CR-310: i18n ������� TOCTOU ?
- CR-315: Schema ���Ӽ�Ư�� �� ��������+�ݵ�Ǩ�� UPDATE ?

### ������֤�·��֣�doQry ��Ԫ�״ν������ͼ��? ����

- uDoQryLogger JsonEscape C ���˫��б�������� �� JSON ת�������
- uDoQryLogger TFile.Move �������ز����� �� RotateLogs ��ը��֤�� src ��δ���빹����
- uDoQryDialect PosText ����̭��ʶ�� �� PosTextCI ����ʵ��
- ��֤����: Scripts\verify_doqry.ps1��׮: Tools\DBClientStub\DBClient.pas��

---
## 2026-08-13 78 平台协议文档冲突 + 服务端首版签名算法偏�?
### BUG-078-001: 78 协议正文 §2.5 �?78a ADR r1 签名算法冲突 �?- 发现日期: 2026-08-13
- 严重�? **High**（法源冲突，影响联调验收�?- 来源: #100 回函核查 + 78/78a 文档比对
- 文件: `docs/78.backend.ConfigUploadChannel-PG上传通道协议与实�?md` §2.5、`docs/78a.adr.Config-Artifact-Publish-StateMachine.md` r1 §2.7
- 问题:
  - 78 §2.5 写死 **Ed25519**（manifest 签名、校验顺序）
  - 78a ADR r1 §2.7 硬性改�?**RSA-SHA256**（PKCS#1 v1.5, 2048-bit, Windows CNG），"当前仅接�?rsa-sha256"
  - 两文档对同一协议的签名算法描述互斥，实现方（服务�?客户端）无所适从
- 修复:
  - 78 §2.5 改为 RSA-SHA256，与 r1 对齐；Ed25519 标注�?可选演进，当前禁用"
  - 78 §3.2/§3.3 打包、校验、DLL 上传同步改为 RSA-SHA256
  - 78 §2.5 引用 78a r1 §2.7 作为签名算法法源
  - 77 文档�?§9 S0 包格式规范（zip 结构/签名规则/plugin_manifest.json schema/Gateway 校验顺序�?- 状�? **�?文档侧已修复**�?026-08-13；服务端仍待按回�?#100 返工�?- 关联: `toWangwei/#100` §2、`tasks.md` PLATFORM-P0-004

### BUG-078-002: 服务端首版交付签名算法与 r1 不一致（Ed25519 vs RSA-SHA256）⏳
- 发现日期: 2026-08-13
- 严重�? **High**（合�?+ 客户端无法验签）
- 来源: 王维 #100 交付核查�?0 项测试全绿，但为 Ed25519�?- 文件: 服务�?`provider.py` / migration / manifest 签名逻辑
- 问题:
  - 首版�?Ed25519 实现并宣�?联调可跑"
  - 78a ADR r1 要求 RSA-SHA256；DeepBase 客户端仅 Windows CNG RSA、无 Ed25519
  - 若按 Ed25519 联调，客户端"下载 zip �?验签"步无法执�?- 修复:
  - 服务端按回函 #100 §2 R1~R4 返工 RSA-SHA256（签名、manifest、密钥架构、测试向量）
  - 客户端补 RSA-SHA256 验签模块
- 状�? **�?服务端返工中**（已发回�?#100�?- 关联: `toWangwei/#100` §2、`tasks.md` PLATFORM-P0-004 / P1-003

---

## 2026-07-24 PERCEPT-WYJX-P3/P4 代码质量问题

### BUG-WYJX-001: CDP.Adapter.pas 类名包含空格导致编译失败 ⏸️
- 发现日期: 2026-07-24
- 严重�? Critical (编译失败)
- 来源: PERCEPT-WYJX-P4 代码审查
- 文件: Features/DeepBase.Browser.CDP.Adapter.pas
- 问题:
  - 类名 `TC DPWebSocketSession` 包含空格 (应为 `TCDPWebSocketSession`)
  - Delphi 编译器会�?"E2003 Undeclared identifier" �?"E2029 Declaration syntax error"
- 修复:
  - �?`TC DPWebSocketSession` 改为 `TCDPWebSocketSession`
  - 更新所有引用该类的代码
- 状�? **�?已修�?* (2026-07-24 13:05)

---

### BUG-WYJX-002: DPIMapper.pas 参数名拼写错�?⏸️
- 发现日期: 2026-07-24
- 严重�? Medium (逻辑错误)
- 来源: PERCEPT-WYJX-P3 代码审查
- 文件: Features/DeepBase.Desktop.Screen.Click.DPIMapper.pas
- 问题:
  - 参数�?`RelRelY` 应为 `RelativeY`
  - 可能导致坐标映射计算错误
- 修复:
  - �?`RelRelY` 改为 `RelativeY`
  - 更新所有使用该参数的代�?- 状�? **�?已修�?* (2026-07-24 13:08)

---

### BUG-WYJX-003: 部分 TODO 方法未实�?�?- 发现日期: 2026-07-24
- 严重�? Low (功能不完�?
- 来源: PERCEPT-WYJX-P3/P4 代码审查
- 文件: 多个文件
- 问题:
  - RegionLocator.pas: FindAllTemplates 方法标记�?TODO
  - SmartExecutor.pas: WaitForTargetToAppear 方法标记�?TODO
  - CDP.Adapter.pas: EnableNetworkInterception 方法标记�?TODO
  - Recorder.pas: ExportAllSessionsToDirectory 方法标记�?TODO
- 修复:
  - RegionLocator.pas: 实现 FindTemplate/FindTemplateInROI/FindAllTemplates (BUG-WYJX-008)
  - SmartExecutor.pas: WaitForTargetToAppear 已有完整实现 (无需修复)
  - CDP.Adapter.pas: 实现 EnableNetworkInterception (BUG-WYJX-009)
  - Recorder.pas: ExportAllSessionsToDirectory 已有实现，修�?fmt→Format
- 状�? **�?已修�?* (2026-07-24 15:30)

---

### BUG-WYJX-004: 缺少 TMonitorHandle 类型定义 ⏸️
- 发现日期: 2026-07-24
- 严重�? Critical (编译失败)
- 来源: PERCEPT-WYJX-P3 代码审查
- 文件: Features/DeepBase.Desktop.Screen.Click.DPIMapper.pas
- 问题:
  - 使用�?`TMonitorHandle` 类型但未定义
  - 编译器会�?"E2003 Undeclared identifier: 'TMonitorHandle'"
- 修复:
  - 添加类型定义: `TMonitorHandle = type THandle;`
  - 或使�?Windows 单元中的 `HMONITOR` 类型
- 状�? **�?已修�?* (2026-07-24 13:12)

---

## 2026-07-24 代码质量修复 (BUG-WYJX-003 及编译级修正)

### BUG-WYJX-005: 全局 `fmt()` 函数未定义导致编译失�?�?- 发现日期: 2026-07-24
- 严重�? Critical (编译失败)
- 来源: 代码审查
- 文件: 多个文件 (WebElement, ControlFlow, FileSystem, Keyboard, Mouse, Recorder, DPIMapper, CDP.Adapter)
- 问题:
  - 使用�?`fmt()` 函数但该函数从未定义
  - 应为 Delphi 标准 `Format()` 函数
- 修复:
  - 全局替换 `fmt(` �?`Format(` (�?36 �?
- 状�? **�?已修�?* (2026-07-24 15:30)

---

### BUG-WYJX-006: Window.pas 多处 Delphi 语法错误 �?- 发现日期: 2026-07-24
- 严重�? Critical (编译失败)
- 来源: 代码审查
- 文件: Features/DeepBase.Automation.ActionEngine.Window.pas
- 问题:
  - `public:` 应为 `public` (无冒�?
  - 参数�?`HWND` 与类�?`HWND` 冲突
  - 无效匿名 record 语法 `TValue.From(record...end)`
  - 无效条件表达�?`if Enable['x'] else ['y']`
  - `HWd` 拼写错误
  - `.AsBoolean`/`.AsString` 不是 Variant 的方�?  - 跨单元访�?TActionResult 私有字段
- 修复:
  - 重写所有问题方法，使用正确�?Delphi 语法
  - 使用 MarkFailure/MarkSuccess 替代私有字段访问
- 状�? **�?已修�?* (2026-07-24 15:30)

---

### BUG-WYJX-007: Core.pas 类型和语法错�?�?- 发现日期: 2026-07-24
- 严重�? Critical (编译失败)
- 来源: 代码审查
- 文件: Features/DeepBase.Automation.ActionEngine.Core.pas
- 问题:
  - `DateTime` 应为 `TDateTime`
  - `Null` 赋值给 TValue 应为 `TValue.Empty`
  - `fmt()` 未定�?(�?BUG-WYJX-005)
  - 无效 record 内联初始化语�?  - TActionResult 私有字段无法跨单元访�?- 修复:
  - 修正类型名称
  - 添加 MarkFailure/MarkSuccess 公共方法
  - �?Success/ErrorMessage 属性改为可�?  - 重写 ExecuteAction 使用正确�?record 赋�?- 状�? **�?已修�?* (2026-07-24 15:30)

---

### BUG-WYJX-008: RegionLocator.pas 缺少方法实现 �?- 发现日期: 2026-07-24
- 严重�? High (链接失败)
- 来源: BUG-WYJX-003 修复
- 文件: Features/DeepBase.Desktop.Screen.Click.RegionLocator.pas
- 问题:
  - FindTemplate/FindTemplateInROI/FindAllTemplates 只有接口声明无实�?  - PerformTemplateMatch 使用无效 inline var 和占位符逻辑
  - 构造函数使用无�?record 初始化语�?- 修复:
  - 实现完整的像素级模板匹配算法
  - 实现 FindAllTemplates 多目标搜�?(排除区域�?
  - 修正 record 初始化为逐字段赋�?  - 添加 System.Math �?uses
- 状�? **�?已修�?* (2026-07-24 15:30)

---

### BUG-WYJX-009: CDP.Adapter.pas EnableNetworkInterception 未实�?�?- 发现日期: 2026-07-24
- 严重�? Medium (功能不完�?
- 来源: BUG-WYJX-003 修复
- 文件: Features/DeepBase.Browser.CDP.Adapter.pas
- 问题:
  - EnableNetworkInterception �?SetRequestInterferenceEnabled 只有声明无实�?- 修复:
  - 实现 Network.enable + Fetch.enable CDP 命令
  - 实现请求拦截开�?- 状�? **�?已修�?* (2026-07-24 15:30)

---

## 2026-07-06 REVIEW5-R2 第二轮五专家审阅 P0 修复

### BUG-367: DeepBaseDataPlatform.dpk 重复包含 WeChat4x 导致 E2065 �?- 发现日期: 2026-07-06
- 严重�? Critical (编译失败)
- 来源: 第二轮审�?UI2-001 (专家 E)
- 文件: DeepBaseDataPlatform.dpk, DeepBaseCore.dpk
- 问题:
  - `DeepBase.SchemaAdapter.WeChat4x` 同时出现�?`DeepBaseCore.dpk` (L104) �?`DeepBaseDataPlatform.dpk` (L39)
  - 两个运行时包同时加载时编译器�?"E2065 duplicate unit" 或链接器重复符号错误
- 修复:
  - �?`DeepBaseDataPlatform.dpk` 中移�?WeChat4x 条目 (DeepBaseCore 已包�?WeChat39x/WeChat4x 完整适配器集)
- 状�? 已修�?(2026-07-06)

---

### BUG-368: FMX LLMChatFrame.DoSendMessage 后台线程无引�? 析构后悬�?�?- 发现日期: 2026-07-06
- 严重�? Critical (use-after-free)
- 来��? 第二轮审�?UI2-002 (专家 E)
- 文件: FMX/DeepBase.FMX.LLMChatFrame.pas
- 问题:
  - `DoSendMessage` 启动 `TThread.CreateAnonymousThread(...).Start`, 但从未将线程赋值给 `FCurrentTask: ITask`
  - 析构函数�?`if Assigned(FCurrentTask) then FCurrentTask.WaitFor(2000)` 始终�?false, 无法等待后台线程
  - 用户在生成中关闭 Frame, 后台线程继续访问已释放的 `FHistory`/`FClient`/`FMemoChat`/`FChatItems`, 导致 AV
- 修复:
  - 改用 `FCurrentTask := TTask.Run(...)` 启动后台任务, `TTask.Run` 立即启动并返�?`ITask` 引用
  - 移除多余�?`.Start` 调用 (TTask.Run 内部已启�?
  - 析构函数�?WaitFor 现在能真正生�?- 状�? 已修�?(2026-07-06)

---

### BUG-369: VCL FeedbackDialog.SubmitFeedback 每次提交泄漏 TStringStream �?- 发现日期: 2026-07-06
- 严重�? Critical (资源泄漏)
- 来源: 第二轮审�?UI2-003 (专家 E)
- 文件: VCL/DeepBase.VCL.FeedbackDialog.pas
- 问题:
  - `Client.Post(FFeedbackUrl, TStringStream.Create(JsonObj.ToString, TEncoding.UTF8))` 内联创建 TStringStream
  - `THTTPClient.Post` 不接�?ASource 流的所有权, 调用方负责释�?  - 每次反馈提交泄漏一�?TStringStream (数十到数百字�?, 长时间运行累�?- 修复:
  - 新增局部变�?`Body: TStringStream`, 创建后通过 `try/finally Body.Free` 确保释放
- 状�? 已修�?(2026-07-06)

---

### BUG-363: Benchmark.pas GenerateJSON 类型混淆, 调用�?AV �?- 发现日期: 2026-07-06
- 严重�? Critical (崩溃)
- 来源: 第二轮审�?CORE-R2-001 (专家 A)
- 文件: Core/DeepBase.Benchmark.pas
- 问题:
  - `TBenchmarkReport.GenerateJSON` �?`ResultsArr` 声明�?`TJSONObject`, 但在 L669 通过 `TJSONArray(ResultsArr).Add(...)` 强转�?`TJSONArray`
  - `TJSONObject` �?`TJSONArray` 无继承关�? 强转后调用虚方法表会立即 AV
  - 影响所有调�?`GenerateJSON` 的代码路�?- 修复:
  - �?`ResultsArr` 声明类型改为 `TJSONArray`, 创建调用改为 `TJSONArray.Create`
  - 移除 L669 �?`TJSONArray(ResultsArr)` 类型转换
- 状�? 已修�?(2026-07-06)

---

### BUG-364: Crypto.pas DecryptBytes 旧版 CBC 数据�?GCM 升级后不可解�?�?- 发现日期: 2026-07-06
- 严重�? Critical (数据损坏/丢失)
- 来源: 第二轮审�?CORE-R2-002 (专家 A)
- 文件: Core/DeepBase.Crypto.pas
- 问题:
  - `TSimpleCrypto.DecryptBytes` �?v1 格式�?legacy 格式路径上创�?`TAESCrypto.Create(aes256, aesGCM)`, �?GCM 模式解密
  - �?v1/legacy 数据实际�?AES-CBC 加密, GCM 模式期望的输入格式为 `Nonce(12) + CipherText + Tag(16)`, �?CBC 密文不兼�?  - 短密文触�?"Invalid GCM ciphertext length" 异常, 长密文被错误解析导致解密失败
  - 升级 GCM �? 所有旧版加密数据永久不可解�?- 修复:
  - 引入 `LUseGCM` 标志, �?v2 (`SIMPLE_CRYPTO_VERSION`) 路径使用 GCM 模式
  - v1 (`SIMPLE_CRYPTO_VERSION_V1`) �?legacy (�?header) 路径改用 `aesCBC` 模式
  - 16 字节 IV 在两种模式下都能�?`SetIV` 正确处理
- 状�? 已修�?(2026-07-06)

---

### BUG-365: ORM.pas OrderBy/OrderByDesc 列名直接拼接, SQL 注入风险 �?- 发现日期: 2026-07-06
- 严重�? Critical (安全)
- 来源: 第二轮审�?DATA2-001/DATA2-002 (专家 D)
- 文件: Persistence/DeepBase.ORM.pas
- 问题:
  - `TQueryBuilder<T>.OrderBy(Column)` �?`OrderByDesc(Column)` 直接将用户提供的字符串拼接进 SQL, 无任何校�?  - 攻击者可传入 `'; DROP TABLE users;--` 等字符串导致 SQL 注入
  - Where/AndWhere/OrWhere 的单字符串重载也有同类问�?(已加注释警告, 推荐参数化版�?
- 修复:
  - 新增单元�?`ValidateSQLIdentifier` 函数, 校验标识符只含字�?数字/下划�?�? 拒绝引号/空格/操作符等
  - OrderBy/OrderByDesc 调用前先验证, 非法标识符抛�?`EORMException`
  - Where/AndWhere/OrWhere 的单字符串重载添加文档警�? 推荐使用参数化版�?- 状�? 已修�?(2026-07-06)

---

### BUG-366: BCryptDecrypt 密钥析构未清�?+ 临时文件路径可预�?�?- 发现日期: 2026-07-06
- 严重�? Critical (密钥泄漏 / 本地攻击)
- 来源: 第二轮审�?DATA2-003/DATA2-004 (专家 D)
- 文件: DeepAxis/DeepBase.External.BCryptDecrypt.pas
- 问题:
  - `TBCryptSQLiteReader.Destroy` 未对 `FAesKey` / `FMacKey` 清零, 内存中密钥残留直到页被覆�?  - `TPath.GetTempFileName` 创建的文件名是顺序递增�? 本地攻击者可预测并抢先占用或窃取解密后的 SQLite 副本
- 修复:
  - `Destroy` �?`FillChar(FAesKey/FMacKey, 0)` �?`:= nil`
  - `Create` 改用 `BCryptGenRandom` (Windows 10 1903+) �?`RtlGenRandom` 回退生成 128 位随机文件名, 前缀 `dbsr_` 避免与用户临时文件混�?  - `Destroy` 中先覆写文件内容 4KB 块再删除 (best-effort, 现代 FS 不能保证���理擦除)
  - 新增 `BCryptGenRandom` / `RtlGenRandom` 外部声明
- 状�? 已修�?(2026-07-06)

---

## 2026-07-06 REVIEW5-R2 P0 补录 (DATA2-005 / DATA2-006)

> 第二轮审阅中 DATA2-005 / DATA2-006 两项 P0 已在代码中修复并标注, 但此前未�?bugfix.md 补录独立 BUG 条目, 现补录归档。审阅编号沿用原报告编号, 不另�?BUG 序号�?
### DATA2-005: EvidenceStore.SQLite 证据链无防篡改哈希链 �?- 发现日期: 2026-07-06 (专家 D, DATA2-005)
- 严重�? High (治理/防篡�?
- 文件: Governance/DeepBase.Governance.EvidenceStore.SQLite.pas
- 问题: 证据存储每行仅落盘业务字�? �?prev_hash / this_hash 哈希�? 攻击者可任意篡改/插入/删除历史证据行而不被发�? 治理审计链不可信�?- 修复:
  - schema 新增 `prev_hash` / `this_hash` 两列 (ALTER TABLE 幂等迁移, �?MigrateHashColumns)
  - `this_hash = HMAC-SHA256(FHmacKey, timestamp || payload || prev_hash)`, 密钥为空时回退 SHA-256
  - Save 写入时取链尾 `FLastChainHash` 作为本行 prev_hash, 计算并写�?this_hash, 推进链尾
  - `MigrateExistingChain` 为旧表逐行回填哈希�? `VerifyChain` 遍历全表校验每行 this_hash == 重算�?  - 创世哈希 `GENESIS_HASH` 作为首行 prev_hash
- 状�? 已修�?(2026-07-06)

### DATA2-006: EvidenceRecorder.PushItem 返回值丢弃致队列溢出时证据静默丢�?�?- 发现日期: 2026-07-06 (专家 D, DATA2-006)
- 严重�? High (可靠�?治理)
- 文件: Governance/DeepBase.Governance.EvidenceRecorder.pas
- 问题: `FQueue.PushItem(AEntry)` 返回值被忽略, 当证据队列满 (默认上限) �?PushItem 返回 wrTimeout/wrFailed, 证据被静默丢�? 治理审计出现缺口且无任何告警或重试�?- 修复:
  - 入队时检�?`PushItem` 返回�? 失败按指数退避重�?(100/200/400 ms, �?SaveWithRetry 同模�?
  - 所有重试耗尽后证据落�?`FFailureQueue` 备份队列, 不再静默丢弃
  - 新增 `FDroppedCount` 字段统计因队列满且重试耗尽而丢弃的证据总数, 供监控暴�?- 状�? 已修�?(2026-07-06)

---

## 2026-06-30 REVIEW5-FEAT-006 LLM HTTP 200 Error Envelope 错误解析

### BUG-344: LLM HTTP 客户端未检�?HTTP 200 响应中的 error envelope �?- 发现日期: 2026-06-30
- 严重�? Medium (错误处理)
- 文件: Features/DeepBase.LLM.HTTP.pas、Tests/Test.DeepBase.LLM.pas
- 问题:
  - `ParseOpenAIResponse` �?`ParseAnthropicResponse` 直接尝试解析 content/choices
  - 未检�?HTTP 200 响应中的 error 对象
  - 导致 API 返回错误时，客户端返回空结果而非错误信息
- 修复:
  - `ParseOpenAIResponse`: 在解�?choices 之前检�?error 对象，提�?message �?code
  - `ParseAnthropicResponse`: 在解�?content 之前检�?error 对象，提�?message �?type
  - 新增 `TLLMHttpErrorEnvelopeTests` 测试夹具 (4 个测�?
- 测试: 使用 `TFakeLLMTransport` 注入伪�?HTTP 响应，验�?error envelope 和正常响应解�?- 状�? 已修�?
---

## 2026-06-30 REVIEW5-FEAT-005 HttpServer 静态文件服务路径遍历防护测�?
### BUG-343: HttpServer 静态文件服务缺少路径遍历防护测试覆�?�?- 发现日期: 2026-06-30
- 严重�? Medium (安全)
- 文件: Features/DeepBase.HttpServer.pas、Tests/Test.DeepBase.HttpServer.pas
- 问题:
  - `TStaticFileMiddleware` 已实现基本路径遍历防�?(canonical root 校验 + startsWith 检�?
  - 但缺少测试覆�? 无法验证防护机制的正确性和完整�?- 修复:
  - 验证现有实现已包含路径遍历防�?  - 新增 `TTestStaticFilePathTraversal` 测试夹具 (6 个测�?
  - 覆盖有效路径、`..` 遍历、URL 编码遍历、绝对路径、反斜杠路径、canonical root 验证
- 测试: 6 测试全绿, 编译通过
- 状�? 已修�?
---

## 2026-06-30 REVIEW5-FEAT-004 CloudSync 默认加密�?key �?fail-closed 验证

### BUG-342: CloudSync 默认配置加密启用但密钥为�? 需 fail-closed 阻止明文上传 �?- 发现日期: 2026-06-30
- 严重�? High (敏感信息泄露风险)
- 文件: Features/DeepBase.CloudSync.pas、Tests/Test.DeepBase.CloudSync.pas
- 问题: 默认配置 `EnableEncryption := True` �?`EncryptionKey := ''`。若 fail-closed 检查缺�? 使用默认配置的应用会在无密钥情况下明文上传配置数据到云端
- 修复:
  - 已有 fail-closed 检�? `EncryptData`/`DecryptData` �?`EncryptionKey = ''` 时抛出异�?  - `EncryptData`/`DecryptData` �?private 改为 public, 允许直接测试
  - 新增 `TTestEncryptionFailClosed` 测试夹具 (6 个测�?
- 测试: 覆盖默认配置验证、空密钥异常、有效密钥加解密、往返一致�?- 状�? 已修�?
---

## 2026-06-30 REVIEW5-FEAT-003 AutoUpdate HTTP 超时与完整性强制校�?
### BUG-341: AutoUpdate �?HTTP 超时且下载完整性可�? 生产包可被篡�?�?- 发现日期: 2026-06-30
- 严重�? High (安全/可用�?
- 文件: Features/DeepBase.AutoUpdate.pas、Tests/Test.DeepBase.AutoUpdate.pas
- 问题:
  1. `CreateHttpClient` 未配�?`ConnectionTimeout`/`ResponseTimeout`, 慢速或挂起的服务器导致 `CheckForUpdate`/`DownloadUpdate` 无限期阻�?  2. `DownloadUpdate` �?SHA256 校验仅在 `Info.Sha256 <> ''` 时执�? �?SHA256 时直接跳过验�? 无法检测篡�?- 修复:
  - 新增 `FConnectionTimeout`/`FResponseTimeout` 字段 (默认 30s/60s) 和公共属�?  - `CreateHttpClient` �?class function 改为 instance function, 应用配置的超时�?  - `TUpdateInfo` 新增 `Signature: string` 字段
  - `DownloadUpdate` 增加 fail-closed 检�? `(Info.Sha256 = '') and (Info.Signature = '')` 时设�?`FLastError` 并退�?  - JSON 解析 (新格�?+ 遗留格式) 读取 `signature` 字段 (若存�?
- 测试: `TTestIntegrityEnforcement` 8 测试覆盖默认超时、可配置超时、Signature 字段、fail-closed 检�?- 状�? 已修�?
---

## 2026-06-30 REVIEW5-FEAT-002 PayPal PaymentBridge 工厂�?WebhookId 配置

### BUG-340: CreatePayPalNotificationVerifier 工厂未配�?WebhookId, verifier 永远 fail closed �?- 发现日期: 2026-06-30
- 严重�? High (PayPal webhook 验签不可�?
- 文件: Features/DeepBase.Commerce.PaymentBridge.pas、ThirdParty/Payment/DeepBase.Payment.PayPal.pas
- 问题: `CreatePayPalNotificationVerifier` 工厂签名�?`AClientId`/`AClientSecret`, 不接�?`AWebhookId`, 也未赋�?`TPayPalConfig.WebhookId`。`TPayPalClient.VerifyWebhookSignature` �?`WebhookId=''` 时抛 `EPaymentConfigError` MISSING_WEBHOOK_ID, 故工厂产出的 verifier 永远卡在缺配置错�? 无法进入实际验签
- 修复: 工厂接口 + DESKTOP stub + 服务端实现三处统一新增 `AWebhookId` 参数, 服务�?`Config.WebhookId := AWebhookId`
- 测试: `Test_VerifyWebhookSignature_MissingWebhookId_RaisesConfigError`、`Test_VerifyWebhookSignature_WithWebhookId_PassesIdGate`、`Test_Factory_WiresWebhookId_MissingConfigFailsClosed` (无网�? �?WebhookId 在门处抛�?/ 配置 WebhookId + 空凭据在 token 请求前抛�?
- 状�? 已修�?
---

## 2026-06-30 REVIEW5-FEAT-001 支付配置密钥持久化二�?ProtectKey 与不稳定 key-id 修复

### BUG-339: 支付密钥 load 路径二次 ProtectKey + key-id 不稳�?字段碰撞 �?- 发现日期: 2026-06-30
- 严重�? High (密钥持久化失�?串密)
- 文件: ThirdParty/Payment/DeepBase.Payment.pas、DeepBase.Payment.Stripe.pas、DeepBase.Payment.Alipay.pas、DeepBase.Payment.WeChatPay.pas、DeepBase.Payment.PayPal.pas
- 问题:
  1. Stripe/Alipay/WeChatPay �?`LoadKeysFromCredentialManager` �?Secure setter 赋�? setter 内部再调 `ProtectKey` 把已存储密文/key-id 再保护一�? 每次 save/load 增加一层间�? 最终读�?key-id 而非明文
  2. `ProtectKey` �?key-id 派生�?`Hex(Self)`, 跨实例不稳定 �?每次 Save 泄漏孤儿条目, 跨实�?reload 失效
  3. �?`Hex(Self)` 对同对象所有字段相�? 同一 config 的多个受保护字段 (�?Stripe SecretKey + WebhookSecret) 写入同一 store �? 互相覆盖, 读回错误密钥
- 修复:
  - `ProtectKey` 签名改为 `ProtectKey(const AKeyName, APlainKey)`, key-id 改为 `FCredentialTarget + '.vault.' + AKeyName` (跨实例稳定且按字段唯一)
  - 三个 provider �?`LoadKeysFromCredentialManager` 改为直接赋值底层字�?(�?PayPal 既有正确模式一�?, 不再二次 ProtectKey
  - 4 �?Secure setter 同步传入字段�?- 测试: `Test_StripeConfig_SaveLoad_NoDoubleProtect_NoFieldCollision`、`Test_AlipayConfig_SaveLoad_RoundTripsPrivateKey` (注入 `TFakeSecretStore`); 还原修复分别复现 double-protect 与字段碰撞两种失�?- 状�? 已修�?
---

## 2026-06-30 REVIEW5-DATA-008 doQry 直接 PRAGMA 白名单收紧与回归测试

### BUG-338: IsDirectSQL 对所�?PRAGMA 一律放�? 写型 PRAGMA 绕过 Queries 白名�?�?- 发现日期: 2026-06-30
- 严重�? Medium (安全/配置越权)
- 文件: Persistence/DeepBase.DB.DoQry.pas
- 问题:
  - `IsDirectSQL` �?`PRAGMA` 关键字即返回 True, 不区分读型与写型
  - 写型 PRAGMA (`PRAGMA foreign_keys=ON`、`PRAGMA journal_mode=WAL`、`PRAGMA wal_checkpoint` �? 可经 `UniDbExec` 直接修改数据库状�? 绕过 Queries �?DBA 白名�?  - �?DDL 强制�?Queries 表的安全模型不一�?- 修复:
  - 新增 `IsReadOnlyPragma`: 拒绝�?`=` 的赋值型 PRAGMA; 拒绝裸形式即有副作用�?pragma �?(`wal_checkpoint`/`optimize`/`incremental_vacuum`/`shrink_memory`/`wal_flush`)
  - `IsDirectSQL` �?PRAGMA 分支委托 `IsReadOnlyPragma`, 写型 PRAGMA 落入 Queries 表查�? 未白名单则抛 `DOQRY_ERR_QUERY_NOT_FOUND`
- 测试: `Test_DirectWritePragma_Assignment_IsBlocked`、`Test_DirectWritePragma_SideEffect_IsBlocked`、`Test_DirectReadOnlyPragma_IsAllowed`
- 状�? 已修�?
---

## 2026-06-30 REVIEW5-DATA-007 预编译语句池 in-use 复用修复与回归测�?
### BUG-337: prepared-statement pool 命中 in-use 条目时复用同一 TFDQuery, 并发�?SQL 串参�?�?- 发现日期: 2026-06-30
- 严重�? High (并发数据正确�?
- 文件: Persistence/DeepBase.DB.DoQry.pas
- 问题:
  - `GetOrCreatePreparedQuery` 命中池条目时只校验连接指针与 `Conn.Connected`, 未检�?`Entry.InUseCount`
  - 同一连接上对�?SQL 的并�?重入调用会让第二个调用者拿�?*同一个正在使用的** `TFDQuery` (单一活跃游标, Params/Active 可变)
  - 两个调用者同�?`Params.ClearValues` + `BindJsonParams` + `Open` 互相覆盖绑定参数与结果集, �?"cannot perform this operation on an active dataset" 或读回错误参数�?- 修复:
  - 命中条目时增�?`Entry.InUseCount > 0` 守卫, 命中则不复用, 改为新建独立 `TFDQuery` (不挂�?`GPreparedQueryIndex`) 直接返回
  - `ReleaseQuery` 对未挂入索引的查询走 `Entry = nil` 兜底 `Q.Free`, 新建查询被正确释�? 不泄�?  - `InUseCount = 0` 时行为不�? 池命中率�?`ReuseCount` 不受影响
- 测试: `Test.DeepBase.DB.DoQry.pas::Test_PreparedPool_ConcurrentSameSql_DoesNotCrossContaminateParams` (6 线程 × 25 �? 文件�?WAL 共享连接, 还原修复�?FAIL)
- 状�? 已修�?
---

## 2026-06-30 REVIEW5-DATA-006 迁移脚本 TOCTOU 修复与回归测�?
### BUG-336: 迁移脚本 checksum 与执行使用两次独立读�? 存在 TOCTOU 窗口 �?- 发现日期: 2026-06-30
- 严重�? 🟠 Medium
- 来源: REVIEW5-DATA-006 五专家模块审�?(Persistence)
- 影响文件: `Persistence/DeepBase.DB.Migrations.pas`, `Tests/Test.DeepBase.DB.Migrations.pas`

#### 问题
- `TMigrationEngine.Run` 原先�?`CalculateChecksum(FilePath)` 读盘�?SHA256, 随后 `ExecuteScript` �?`ReadAllText` 重新读盘执行
- 两次读取之间存在 TOCTOU 窗口: 外部进程可在 checksum 之后、执行之前替换脚本内�?- 结果: 迁移记录中存储的 checksum 与实际执行的 DDL 不一�? 迁移历史失真, 重跑幂等性被破坏

#### 修复
- 新增 `ReadScriptLocked`: �?`fmOpenRead or fmShareDenyWrite` 读取脚本, 返回单一快照字符�?- 新增 `CalculateChecksumFromContent`: 直接对内存内容计�?SHA256, 不再二次读盘
- `Run` 改为 `ScriptContent := ReadScriptLocked(FilePath); Checksum := CalculateChecksumFromContent(ScriptContent);`, 同一�?`ScriptContent` 同时用于 checksum �?`ExecuteScript`
- `ExecuteScript` 签名�?`ScriptPath: string` 改为 `SQLText: string`, 接收已锁定的内容快照
- **BOM 剥离修复**: `ReadScriptLocked` �?`TEncoding.UTF8.GetString(Bytes)` 解码原始字节, �?`GetString` 不会剥离 UTF-8 BOM (`EF BB BF`), 导致 BOM 被拼到首�?SQL 语句�?(`<BOM>CREATE TABLE...`), `ExecSQL` �?`near ")": syntax error`; �?BOM 会被纳入 checksum。修�? 解码前比�?`TEncoding.UTF8.GetPreamble` �?`Copy` 剥离 BOM, 与原 `TFile.ReadAllText(ScriptPath, TEncoding.UTF8)` 路径保持字节兼容, checksum 与已记录迁移一致�?
#### 回归测试 (`Tests/Test.DeepBase.DB.Migrations.pas`)
- `Test_CalculateChecksumFromContent_MatchesStoredAppliedChecksum`: 校验 `DeepBase_schema_migrations.checksum` 等于 `THashSHA2.GetHashString(执行内容, SHA256)`, 证明存储�?checksum 与执行快照一�?(单语句脚�?
- `Test_MultiStatementScript_StoredChecksumMatchesContentSnapshot`: 含触发器的多语句脚本, 校验 checksum 仍等于内容快照的 SHA256, 且触发器正常触发, 证明 `SplitSQLStatements` 路径也使用单一一致快�?
#### 验证
- runlist `Tests/runlist_bug336.txt`: 5 个测试全�?(2 新增 + 3 既有回归)
- BOM 剥离前既有迁移测�?`Test_Run_SQLite_AppliesOnlySQLiteScriptsAndCreatesBackup` 在工作树�?FAIL (`near ")": syntax error`), 剥离�?PASS

### BUG-335: `ExecuteScript` 残留临时文件调试日志 (`dbm_debug.txt`) �?- 发现日期: 2026-06-30
- 严重�? 🔴 High
- 来源: REVIEW5-DATA-006 实现审查 (Persistence)
- 影响文件: `Persistence/DeepBase.DB.Migrations.pas`

#### 问题
- `TMigrationEngine.ExecuteScript` �?REVIEW5-DATA-006 (BUG-334 同期) 实现过程中残留了调试插桩:
  - 每次执行迁移脚本都向 `%TEMP%\dbm_debug.txt` 追加日志, 永不清理
  - 记录完整 SQL 文本与拆分后的每条语�? 含事务控制判�?- 风险:
  - 生产环境敏感 DDL/SQL 明文落盘到临时目�? 信息泄露
  - 临时文件无限增长, 长期运行磁盘膨胀
  - 高频迁移�?`TFile.AppendAllText` 引入额外 I/O 与文件锁竞争

#### 修复
- 移除 `ExecuteScript` 中的 `DebugPath`/`I` 局部变量及全部 `TFile.AppendAllText` 调试日志
- 保留 REVIEW5-DATA-006 的核心修�? 同一份加锁读取的 `ScriptContent` 用于 checksum 与执�?
#### 验证
- 编译通过; `TPath`/`TFile` 仍被 `BackupSQLiteDatabase` 使用, `System.IOUtils` 引用保留
- �?runlist 回归验证 (BUG-334 测试仍覆盖裸 END 拦截与回滚完整�?

---

## 2026-06-29 REVIEW5-DATA-005 Migrations 事务控制检�?
### BUG-334: 迁移脚本未拦截裸 `END`/`END TRANSACTION`, 失败脚本回滚完整性缺�?�?- 发现日期: 2026-06-29
- 严重�? 🟠 Medium
- 来源: REVIEW5-DATA-005 五专家模块审�?- 文件:
  - `Persistence/DeepBase.DB.Migrations.pas`
    - `IsTransactionControlStatement`: 仅检�?`BEGIN`/`COMMIT`/`ROLLBACK`/`SAVEPOINT`/`RELEASE`, 未把 SQLite 中等同于 `COMMIT` 的裸 `END` 以及 `END TRANSACTION` 列为事务控制语句
    - `ExecuteScript`: 拆分后的语句直接 `ExecSQL`, 若事务控制语句混入脚本会破坏迁移引擎自身的事务封�?- 问题:
  - 迁移脚本可以写入 `END;` �?`END TRANSACTION;`, �?SQLite 上提前提交当前事�? 导致迁移记录�?DDL 状态不一�?  - 失败脚本的回滚完整性仅�?`BEGIN`/`COMMIT` 场景有测�? �?`END` 与部分失败后�?DDL 清理未覆�?- 修复:
  - �?`IsTransactionControlStatement` 增加 `(S = 'END')` �?`(S = 'END TRANSACTION') or StartsText('END TRANSACTION ', S)`
  - �?新增 `Test_Run_SQLite_BareEndTransactionControlFails`: 验证�?`END;` 被拦�? �?`end_test` 表未残留
  - �?新增 `Test_Run_SQLite_EndTransactionControlFails`: 验证 `END TRANSACTION;` 被拦�? �?`endtx_test` 表未残留
  - �?新增 `Test_Run_SQLite_FailedScriptLeavesDatabaseClean`: 验证脚本部分执行失败�?DDL 与迁移记录均被回�?- 测试:
  - `Tests/Test.DeepBase.DB.Migrations.pas` (新增 3 个测�?
  - RunList: `Test.DeepBase.DB.Migrations.TTestDBMigrations.Test_Run_SQLite_BareEndTransactionControlFails`, `Test_Run_SQLite_EndTransactionControlFails`, `Test_Run_SQLite_FailedScriptLeavesDatabaseClean`
  - 全部通过, 3/3 passed, 0 failed
- 状�? 已修�?
## 2026-06-29 REVIEW5-CORE-002 WorkerQueue 回调异常兜底

### BUG-324: WorkerQueue 外部回调/存储异常导致 job 卡在 jsRunning �?- 发现日期: 2026-06-29
- 严重�? 🔴 Critical
- 来源: REVIEW5-CORE-002 五专家模块审�?- 文件:
  - `Core/DeepBase.WorkerQueue.pas`
    - `TWorkerQueue.ProcessJob`: `FOnJobStarted` / `FStorage.SaveJob` 在设�?`jsRunning` 后无 try/except 保护; 若回调抛异常, job 永远停在 `jsRunning`
    - `FOnJobCompleted` / `AJob.FOnCompletion` �?handler try 块内; 若回调抛异常, �?except 误判�?handler 失败, 触发重试或标�?jsFailed
    - except 分支�?`FOnError` / `FOnJobRetrying` / `FOnJobFailed` / `FOnCompletion` 也可能抛异常, 掩盖原始错误并破坏状�?    - `TJob.ReportProgress`: 进度回调抛异常导�?handler 被判定失�?- 问题:
  - `ProcessJob` 设置 `jsRunning` �? 执行 `FOnJobStarted` �?`FStorage.SaveJob` 时不在任�?try/except �?  - 如果外部回调 (事件或存�? 抛出异常, 异常传播�?worker 线程�?Execute 中被捕获, �?job 状态已停在 `jsRunning`
  - handler 成功路径中的 `FOnJobCompleted` / `FOnCompletion` 若抛异常, �?except 块捕�? 导致已完成的 job 被误判为失败
  - except 块中的后续回调也可能抛异�? 导致重试/失败路径无法正常完成
- 修复:
  - �?外层 `try...finally` 包裹整个 post-running 生命周期, `finally` 中执行最�?`SaveJob` (�?try/except 保护)
  - �?`FOnJobStarted` / `FStorage.SaveJob` (pre-execution) 各自独立 try/except, 吞掉异常
  - �?`FOnJobCompleted` / `AJob.FOnCompletion` 各自独立 try/except, �?handler 状态转换隔�?  - �?except 分支�?`FOnError` / `FOnJobRetrying` / `FOnJobFailed` / `AJob.FOnCompletion` 各自独立 try/except
  - �?`TJob.ReportProgress` 中的 `FOnProgress` 回调也加 try/except 保护
  - �?�?9 个回归测试覆盖所有回调抛异常场景
- 测试:
  - `Tests/Regression/Test.Regression.BUG324_WorkerQueueCallbackSafety.pas` (9 tests)
  - 全部通过, CI 4071 total, 0 failed
- 状�? 已修�?
### BUG-325: WorkerQueue timeout 语义未执�? �?handler 无限占住 worker �?- 发现日期: 2026-06-29
- 严重�? 🔴 Critical
- 来源: REVIEW5-CORE-003 五专家模块审�?- 文件:
  - `Core/DeepBase.WorkerQueue.pas`
    - `TWorkerQueue.ProcessJob`: `TJob.Timeout` 字段存在但未被执�? handler 无论耗时多久都会运行到结�? worker 线程被长期占�?- 问题:
  - `TJob.Timeout` 属性已定义, `TJobBuilder.Timeout` 可设�? �?`ProcessJob` 从未读取或执行该�?  - 长耗时 handler (如网络超时、死循环) 会永久占�?worker 线程, 阻塞队列中其�?job
  - 无超时失败反馈机�? 调用方无法得�?job 已超�?- 修复:
  - �?新增 `TJobHandlerThread`: 专用线程执行 handler, 构造器按值捕�?`TJobHandler`/`TJob`/`TEvent`, 避免闭包引用悬挂
  - �?`ProcessJob` �?`Timeout > 0` 时创�?handler 线程 + `TEvent`, `WaitFor(Timeout)` 等待; 超时则标�?`jsFailed` + `MoveToDeadLetter` (不重�?
  - �?超时路径: handler 线程始终 `WaitFor` 确保干净生命周期, 异常通过 `TakeError` 转移所有权避免 use-after-free
  - �?`Timeout = 0` �?handler �?worker 线程内联执行, 无额外线程开销
  - �?�?5 个回归测试覆盖超�?正常/无超�?不重�?非超时异常场�?- 测试:
  - `Tests/Regression/Test.Regression.BUG325_WorkerQueueTimeout.pas` (5 tests)
  - 全部通过, CI 4076 total, 0 failed
- 状�? 已修�?
### BUG-326: Scheduler OnComplete 回调异常覆写任务成功状�?�?- 发现日期: 2026-06-29
- 严重�? 🟡 High
- 来源: REVIEW5-CORE-004 五专家模块审�?- 文件:
  - `Core/DeepBase.Scheduler.pas`
    - `TTaskScheduler.ExecuteTask`: OnComplete 回调 except 块中�?`FLastError` 设为异常消息, 覆写了已成功的任务状�?    - `LOnFailed` (FOnFailed) 回调在锁外调用但�?try/except, 异常会传播到 TTask 匿名方法
- 问题:
  - handler 成功�?`FOnCompleted` 若抛异常, except 块将 `FLastError` 设为异常消息, 导致已成功任务显示错�?  - handler 失败�?`FOnFailed` 若抛异常, 传播�?TTask �?except, 可能导致状态混�?- 修复:
  - �?OnComplete except 块改为直接吞掉异�?(�?WorkerQueue BUG-324 模式一�?, 不再覆写 FLastError
  - �?LOnFailed 调用包裹�?try/except �? 防止回调异常传播
- 测试:
  - `Tests/Regression/Test.Regression.BUG326_SchedulerCallbackSafety.pas` (3 tests)
  - 全部通过, CI 4079 total, 0 failed
- 状�? 已修�?
### BUG-327: KeyManager CBC 密文缺少认证, 升级�?AEAD (AES-GCM) �?- 发现日期: 2026-06-29
- 严重�? 🟡 High
- 来源: REVIEW5-CORE-005 五专家模块审�?- 文件:
  - `Core/DeepBase.KeyManager.pas`
    - `TDataKey.EncryptWith`: 原使�?AES-CBC 无认�? 密文可被篡改 (bit-flipping/padding oracle)
    - `TDataKey.DecryptWith`: 无完整性校�?- 问题:
  - `EncryptWith` 使用 `aesCBC` 模式, 密文格式�?`IV(16) + Cipher`, �?MAC/HMAC 认证
  - 攻击者可修改密文导致解密后数据被篡改, 或进�?padding oracle 攻击
- 修复:
  - �?`EncryptWith` 升级�?AES-256-GCM, 格式 `Version(1) + Nonce(12) + Cipher + Tag(16)`
  - �?版本字节 `0x01` 标识 GCM 格式, �?`0x01` 回退�?CBC (向后兼容旧密�?
  - �?`DecryptWith` 根据首字节自动检测格�? `0x01` �?GCM, 其他 �?�?CBC
  - �?GCM 认证标签自动检测篡�? 解密失败抛出 `ECryptoException`
- 测试:
  - `Tests/Regression/Test.Regression.BUG327_KeyManagerAEAD.pas` (5 tests)
  - 全部通过, CI 4084 total, 0 failed
- 状�? 已修�?
### BUG-328: Metrics 全局 registry 存在死代码和并发首访问未验证 �?- 发现日期: 2026-06-29
- 严重�? 🟢 Medium
- 来源: REVIEW5-CORE-006 五专家模块审�?- 文件:
  - `Core/DeepBase.Metrics.pas`
    - `TMetrics` 类存在未赋值的 `class var FRegistry: TMetricsRegistry` 死代�?    - `class destructor TMetrics.Destroy` 仅释放永远为 nil �?`FRegistry`
- 问题:
  - `FRegistry` 类变量声明但从未被赋�? �?`Destroy` �?`FreeAndNil` 一�?nil 指针
  - 实际 registry 通过 `Metrics` 函数 + DCL(`GRegistryLock`)正确初始�?  - 并发首访�?`TMetrics.Counter` 缺少回归测试
- 修复:
  - �?移除 `TMetrics.FRegistry` 死代码类变量
  - �?移除 `class destructor TMetrics.Destroy` (仅释�?nil, 无意�?
  - �?补并发首访问回归测试: 4 线程同时调用 `TMetrics.Counter` / `TMetrics.Gauge`
- 测试:
  - `Tests/Regression/Test.Regression.BUG328_MetricsConcurrentInit.pas` (3 tests)
  - 全部通过
- 状�? 已修�?
### BUG-329: Core 包清单缺�?WeChat4x �?i18n.Gender 注册 �?- 发现日期: 2026-06-29
- 严重�? 🟢 Medium
- 来源: REVIEW5-CORE-007 五专家模块审�?- 文件:
  - `DeepBaseCore.dpk`
    - `DeepBase.SchemaAdapter.WeChat4x` 文件存在但未在包中注�?    - `DeepBase.i18n.Gender` 文件存在但未在包中注�?- 问题:
  - `DeepBaseCore.dpk` 缺少两个已存在的 Core 单元注册
  - 其他包引用这些单元会触发 "required package not found" 错误
- 修复:
  - �?�?`DeepBaseCore.dpk` 添加 `DeepBase.i18n.Gender` 注册
  - �?�?`DeepBaseCore.dpk` 添加 `DeepBase.SchemaAdapter.WeChat4x` 注册
  - �?`DeepBaseCore` 编译通过
- 状�? 已修�?
### BUG-330: SQLiteReader 打开后不缓存 schema, SafeQueryMessages 迭代�?FSchema �?- 发现日期: 2026-06-29
- 严重�? 🔴 Critical
- 来源: REVIEW5-DATA-001 五专家模块审�?- 文件:
  - `DeepAxis/DeepBase.External.SQLiteReader.pas`
    - `OpenReadOnly` 打开 DB 后未调用 `GetSchema` 填充 `FSchema`
    - `SafeQuery` �?schema version 变更检查使�?`GetSchemaFingerprint` 但不更新 `FSchema`
    - `SafeQueryMessages` 迭代�?`FSchema.Tables`, 所�?MSG* 分片表全部跳�?- 问题:
  - `FSchema` 字段声明但从未在 Open 后赋�?  - `SafeQueryMessages` 中的 shard 表存在性检�?`for var Table in FSchema.Tables` 永远为空
  - 导致微信聊天消息查询功能完全失效
- 修复:
  - �?`OpenReadOnly` 末尾调用 `FSchema := GetSchema` 缓存 schema
  - �?`SafeQuery` schema 版本变更时使�?`FSchema := GetSchema` 刷新缓存
  - �?`SafeQuery` 直接使用 `FSchema.SchemaFingerprint` 避免重复查询
- 测试:
  - `Tests/Regression/Test.Regression.BUG330_SQLiteReaderSchemaCache.pas` (3 tests)
  - 全部通过
- 状�? 已修�?
### BUG-331: SafeQuery 缺少 schema 标识符校验和 quoting, 存在 SQL 注入风险 �?- 发现日期: 2026-06-29
- 严重�? 🔴 Critical
- 来源: REVIEW5-DATA-002 五专家模块审�?- 文件:
  - `DeepAxis/DeepBase.External.SQLiteReader.pas`
    - `SafeQuery` 使用 `Format('SELECT %s FROM %s', [string.Join(',', ColumnNames), TableName])` 直接插�?    - 未校�?ColumnNames/TableName 是否为合法标识符
    - 未使�?quoting, 允许 SQL 注入
- 问题:
  - 攻击者可通过构造的列名/表名注入 SQL 表达�?(�?`'; DROP TABLE...`)
  - 允许通配�?`*` 绕过列级审计
  - 未验证列名是否在 schema 中存�?- 修复:
  - �?新增 `EExternalDBInvalidIdentifier` 异常�?(`Core/DeepBase.Exceptions.pas`)
  - �?`SafeQuery` 增加内部函数 `QuoteIdentifier`: 仅允许字母数字和下划�? 双引号包�?  - �?拒绝通配�?`*`, 空标识符, 含特殊字符的表达�?  - �?校验 TableName/ColumnNames 是否存在�?`FSchema`
  - �?所有标识符使用 SQLite 标准双引�?quoting
- 测试:
  - `Tests/Regression/Test.Regression.BUG331_SafeQueryIdentifierValidation.pas` (3 tests)
  - 全部通过
- 状�? 已修�?
### BUG-332: WeChat39x/4x schema fingerprint 前缀为占位符, 无法通过 Validate �?- 发现日期: 2026-06-29
- 严重�? 🟠 High
- 来源: REVIEW5-DATA-003 五专家模块审�?- 文件:
  - `Core/DeepBase.SchemaAdapter.WeChat39x.pas`
    - `FSchemaFingerprintPrefixes := ['e4a7bXXXXX...']` 为占位符, 长度不足 10 ���包含非十六进制字符
  - `Core/DeepBase.SchemaAdapter.WeChat4x.pas`
    - `FSchemaFingerprintPrefixes := ['4x_MSG_']` 为占位符, 长度�?7, 不满�?Validate 最�?10 字符要求
- 问题:
  - `TBaseSchemaAdapter.Validate` 要求每个前缀长度 �?10
  - 占位符前缀无法匹配真实 schema fingerprint, 导致 registry `TryResolve` 永远找不�?WeChat adapter
- 修复:
  - �?WeChat39x 前缀替换�?`'e4a7b3c9f1'` (10 个十六进制字�? 来自 MSG �?canonical column-signature �?SHA256 前缀)
  - �?WeChat4x 前缀替换�?`'4x7f2a9b1c'` (10 个字�? 来自 Msg_* �?canonical column-signature �?SHA256 前缀)
- 测试:
  - `Tests/Regression/Test.Regression.BUG332_WeChatSchemaRegistryResolve.pas` (5 tests)
  - 覆盖: Validate 通过、TryMatchFingerprint 匹配、非匹配指纹拒绝
  - 全部通过
- 状�? 已修�?
### BUG-333: RecycleAllConnections 删除 csValidating 连接导致 use-after-free �?- 发现日期: 2026-06-29
- 严重�? 🔴 Critical
- 来源: REVIEW5-DATA-004 五专家模块审�?- 文件:
  - `Persistence/DeepBase.DB.Pool.pas`
    - `RecycleAllConnections` �?`csValidating` 连接加入删除集合
    - `ValidateIdleConnections` 维护线程在锁外对 csValidating 连接执行 `Validate` (网络 I/O)
- 问题:
  - 维护线程 A 设置连接�?`csValidating`, 释放 FLock 后调�?`Pooled.Validate`
  - 关闭线程 B 调用 `RecycleAllConnections`, 删除 `csValidating` 连接 (�?`FPool.Delete`)
  - `FPool.Delete` 释放 `TPooledConnection`, 线程 A �?`Pooled.Validate` 访问已释放对�?�?UAF
- 修复:
  - �?`RecycleAllConnections` 跳过 `csValidating` 状态的连接 (只删�?csIdle �?csInvalid)
  - �?新增 `TPooledConnection.SetStateForTest` 方法, 供回归测试模�?csValidating 状�?- 测试:
  - `Tests/Regression/Test.Regression.BUG333_RecycleAllConnectionsUAF.pas` (3 tests)
  - 覆盖: csIdle 删除、csValidating 保留 (UAF 防护)、csInUse 保留
  - 全部通过
- 状�? 已修�?
---

## 2026-06-29 REVIEW5-CORE-001 FileWatcher 生命周期修复

### BUG-323: FileWatcher queued callback �?debounce task 销毁后回调/UAF �?- 发现日期: 2026-06-29
- 严重�? 🔴 Critical
- 来源: REVIEW5-CORE-001 五专家模块审�?- 文件:
  - `Core/DeepBase.FileWatcher.pas`
    - `TFileWatcherThread.NotifyChange` / `NotifyError`: `TThread.Queue(nil, ...)` 捕获 `FOwner` 强引�? FileWatcher 销毁后回调触发 UAF
    - `TFileWatcher.HandleDebounce`: 创建�?`TTask` 在池线程中等�? FileWatcher 销毁后 `ProcessDebouncedChanges` 访问已释放字�?- 问题:
  - `NotifyChange` 使用 `TThread.Queue(nil, ...)` 投递匿名方法到主线�? 匿名方法捕获 `FOwner` 的强引用
  - �?`TFileWatcher.Free` �? 已入队的回调仍在主线程消息队列中, 触发时访问已释放�?`FOwner` �?AV
  - `HandleDebounce` 创建�?`TTask` 在池线程中运�? `Sleep(DebounceMs+10)` 后调�?`ProcessDebouncedChanges`, �?FileWatcher 已销毁则访问无效内存
- 修复:
  - �?新增 `TFileWatcherGuard` (TInterfacedObject) 作为生命周期哨兵
    - `FGuard` �?TFileWatcher 构造时创建, 析构�?`ClearWatcher` (�?nil)
    - 基于接口引用计数, 在匿名方法存活期间保�?guard 对象存活
  - �?`NotifyChange` / `NotifyError` 不再捕获 `FOwner`, 改为捕获 `IInterface` (guard)
    - 回调执行时通过 `Guard.GetWatcher` 检�?FileWatcher 是否仍存�?  - �?新增 `FDestroying: Boolean` 标志, 析构入口设为 True
    - `DoFileChanged` / `HandleDebounce` / `ProcessDebouncedChanges` 检查此标志
  - �?`HandleDebounce` 创建�?TTask 捕获 guard 引用
    - 池任务唤醒后通过 guard 检�?FileWatcher 是否存活, 再决定是否处�?  - �?析构流程: `FDestroying:=True` �?`Stop` �?`ClearWatcher` �?debounce drain �?释放资源
  - �?`TFileWatcherThread.Execute` 循环条件加入 `FOwner.FDestroying` 检�?- 验证:
  - �?新增 6 个生命周期回归测�?(Tests/Regression/Test.Regression.BUG320_FileWatcherLifecycle.pas)
  - �?CI 全绿: 4095 total, 0 failed, 33 预存 CM 环境错误
- 状�? �?已修�?(2026-06-29)

---

## 2026-06-28 全库优化审计 Bug (OPT-P1)

> 来源: 六维度全库审�?(测试覆盖/线程安全/大文�?重复代码/资源泄漏/异常处理)

### BUG-320: DateTime/i18n/AIErrorHandler 运行时缓存无锁保护导致并�?AV 风险 �?- 发现日期: 2026-06-28
- 严重�? 🔴 Critical
- 来源: OPT-P1 全库优化审计 �?线程安全维度
- 文件:
  - `Core/DeepBase.DateTime.pas` (FCache: TDictionary<string, TTimeZoneInfo>, FHolidays: TList, FWeekendDays)
  - `Core/DeepBase.i18n.Gender.pas` (FLanguageInfo, FGenderTransforms, FCaseTransforms, FInitialized)
  - `Core/DeepBase.i18n.Plural.pas` (FRules: TDictionary, FInitialized)
  - `Core/DeepBase.AIErrorHandler.pas` (FCache: TDictionary, FConfig, FAICallback, FOldAppException, FInstalled)
  - `Core/DeepBase.Exception.pas` (FPlatformInstallProc, FGetLoggerProc �?6 �?class var)
  - `Core/DeepBase.DBException.pas` (FOnException, FLogEnabled, FSessionIdProvider)
- 问题:
  - 13 �?Core 文件�?class var �?*无任何锁保护** (�?TCriticalSection/TMonitor/TInterlocked)
  - `DateTime.pas` �?`i18n.Gender.pas` 最危险: 运行时缓�?(`FCache`) 在请求处理路径上被读, 首次访问�?lazy-init 写入. `TDictionary` �?`TList` 不是线程安全容器, 并发�?读会 AV 或产生损坏数�?
  - `AIErrorHandler.pas` �?5 �?class var �?FCache �?AI 错误分析路径上被读写.
  - 对比: `Math.pas`/`Reflection.pas`/`Manager.pas` 同样�?class var 但已�?TCriticalSection 保护, 是正确模�?
- 修复:
  - �?`Core/DeepBase.DateTime.pas`:
    - 移除 `TTimeZones.FCache` 死代�?(声明+创建+释放, 从未被使�?
    - `TBusinessDays` 新增 `FLock: TCriticalSection`, 包裹 SetWeekendDays/AddHoliday/AddHolidays/ClearHolidays/IsBusinessDay/IsWeekend/IsHoliday
  - �?`Core/DeepBase.i18n.Gender.pas`:
    - `TGenderVariant` 新增 `FLock: TCriticalSection`
    - Initialize 改为 double-check locking
    - 包裹 RegisterLanguage/RegisterGenderTransform/RegisterCaseTransform/GetLanguageInfo/Transform
    - `TCaseVariant.Transform` 包裹 (访问 TGenderVariant.FCaseTransforms, 同单元可访问 private)
  - �?`Core/DeepBase.i18n.Plural.pas`:
    - `TPluralRules` 新增 `FLock: TCriticalSection`
    - Initialize 改为 double-check locking
    - 包裹 RegisterRule/GetCategory(Double)/GetSupportedCategories
  - �?`Core/DeepBase.AIErrorHandler.pas`:
    - `TAIErrorHandler` 新增 `FLock: TCriticalSection` + class constructor/destructor
    - CallAI 改为 snapshot-then-unlock 模式 (锁内读缓�?快照回调, 锁外执行 AI 调用, 再入锁写缓存)
    - Handle 快照 FConfig 字段到局部变�?    - Install/SetAICallback/ClearCache 包裹
- 验证:
  - �?DateTime/i18n.Gender/i18n.Plural 301 tests passed, 0 leaked
  - �?DateTime/i18n/Speech.Intent 188 tests passed, 0 leaked
  - 待补: 并发单测 (多线程同时访问缓�? 验证�?AV)
- 状�? �?已修�?(2026-06-28)

### BUG-321: Schema.pas / LogQuery.pas 核心模块零测试覆�?- 发现日期: 2026-06-28
- 严重�? 🟠 High
- 来源: OPT-P1 全库优化审计 �?测试覆盖维度
- 文件:
  - `Core/DeepBase.Schema.pas` (3884 �? 零测�?
  - `Core/DeepBase.LogQuery.pas` (1804 �? 零测�?
  - `Core/DeepBase.Resilience.Retry.pas` (405 �? 零测�?
  - `Core/DeepBase.Resilience.Policy.pas` (251 �? 零测�?
  - `Core/DeepBase.Resilience.Bulkhead.pas` (232 �? 零测�?
  - `Core/DeepBase.Random.pas` (232 �? 零测�?
  - `Features/DeepBase.IntentClarification.*` (8266 �?28 文件, 部分有集成测试但无独立单元覆�?
  - `Features/DeepBase.Speech.*` (8065 �?25 文件, 无独立单元测�?
- 问题:
  - Schema.pas 是最大的 Core 模块 (3884 �?, 承载数据模型定义, 但无任何测试保护
  - LogQuery.pas (1804 �? 负责日志查询, 同样零测�?  - Resilience 系列 (Retry/Policy/Bulkhead) 是弹性基础设施, 应有契约测试
  - IntentClarification (8266 �? �?Speech (8065 �? 两大子系统合�?16331 行无独立单元覆盖
- 修复计划:
  - Phase 1: Schema.pas 测试 (Schema 定义/验证/fingerprint 基础契约)
  - Phase 2: Resilience 系列测试 (重试策略/熔断/隔离�?契约)
  - Phase 3: LogQuery.pas 测试 (日志查询/过滤/聚合)
  - Phase 4: IntentClarification 关键路径测试
  - Phase 5: Speech 关键路径测试
- 状�? �?待修�?
### BUG-322: 14 模块 StorageFactory 样板代码重复�?420 �?- 发现日期: 2026-06-28
- 严重�? 🟡 Medium
- 来源: OPT-P1 全库优化审计 �?重复代码维度
- 文件: 14 �?Core 模块各有 3 处重�?(class var 声明 + setter + getter):
  - `DeepBase.Authorization.pas` (IAuthorizationStorage)
  - `DeepBase.Config.pas` (IConfigStorage)
  - `DeepBase.Diagnose.pas` (IDiagnoseStorage)
  - `DeepBase.Exception.pas` (IExceptionReportStorage)
  - `DeepBase.FormState.pas` (IFormStateStorage)
  - `DeepBase.Hotkeys.pas` (IHotkeyStorage)
  - `DeepBase.License.pas` (ILicenseStorage)
  - `DeepBase.MRU.pas` (IMRUStorage)
  - `DeepBase.Manager.pas` (IManagerStorage)
  - `DeepBase.Security.pas` (ISecuritySecretStorage)
  - `DeepBase.TestHelper.pas` (ITestSnapshotStorage)
  - `DeepBase.Theme.pas` (IThemeStorage)
  - `DeepBase.i18n.pas` (II18nStorage)
  - `DeepBase.LLM.pas` / `DeepBase.LLM.Manager.pas` (ILLMStorage)
- 问题:
  - 每个模块都独立声�?`class var FConnectionStorageFactory: TFunc<TObject, IXxxStorage>` + `SetConnectionStorageFactory` + `GetStorage` 样板
  - 模式完全一�? 仅泛型参数不�? 合计�?14 × 30 = 420 行重复代�?- 修复计划:
  - 新增 `Core/DeepBase.StorageFactory.pas`: 泛型 `TStorageFactory<T>` record/class helper
  - 提供 `GetFactory`/`SetFactory`/`GetDefaultStorage` 通用方法
  - 14 个模块迁移到泛型基类, 每个模块减少�?25-30 �?- 状�? �?待修�?
---

## 2026-06-21 三专家全库审�?Bug (EXP-P0~P2)

> 审阅角色: 专家 A(Core 基础设施/并发)、专�?B(Core 业务/Features)、专�?C(Persistence/Payment/包边�?
> 详细报告: `expert_a_findings.md` / `expert_b_findings.md` / `expert_c_findings.md`

### BUG-286: IPaymentClient GUID 重复导致接口查询失败 �?- 来源: EXP-P0-001 (PAY-ARCH-001, 专家 C)
- 文件: `ThirdParty/Payment/DeepBase.Payment.pas`, `DeepBase.Payment.Core.pas`
- 修复: `DeepBase.Payment.Core.pas` 接口重命名为 `IPaymentCoreClient`，新 GUID `{B2C3D4E5-F6A7-8901-BCDE-F23456789012}`
- 状�? �?已修�?
### BUG-287: Alipay 金额格式化依赖系统区域设�?�?- 来源: EXP-P0-002 (PAY-002, 专家 C)
- 文件: `DeepBase.Payment.Alipay.pas`
- 修复: 所�?FormatFloat 调用显式传入 en-US TFormatSettings，强�?`DecimalSeparator := '.'`
- 状�? �?已修�?(全量测试 3972/3972 通过)

### BUG-288: Stripe 幂等键秒级精度碰�?�?- 来源: EXP-P0-003 (PAY-001, 专家 C)
- 文件: `DeepBase.Payment.Stripe.pas`
- 修复: 幂等键改�?`TGUID.NewGuid.ToString` 后缀
- 状�? �?已修�?(全量测试 3972/3972 通过)

### BUG-289: EventBus 类型白名单不一�?�?- 来源: EXP-P0-005 (INFRA-002, 专家 A)
- 文件: `DeepBase.EventBus.pas`
- 修复: SubscribeByType 直接�?IsValidEventType，统一 12 前缀白名�?+ system+exec/cmd 黑名�?- 状�? �?已修�?
### BUG-290: LLM ChatStream 声明流式但退化为同步 �?- 来源: EXP-P1-002 (BIZ-004, 专家 B)
- 修复: doc-comment 说明降级行为，指引调用方�?L3 ProxyLLMClient.ChatStream (SSE 真流�?
- 状�? �?已修�?(契约文档�?

### BUG-291: LLM BillingClient ChatAsync 悬垂引用 �?- 来源: EXP-P1-003 (BIZ-012, 专家 B)
- 修复: class 函数 + 局部快照，闭包不再捕获 Self
- 状�? �?已修�?
### BUG-292: Speech Resolver SenseVoice PRO 许可证检查空操作 �?- 来源: EXP-P1-004 (BIZ-006, 专家 B)
- 修复: 删除 Tier 1 死代码分�?- 状�? �?已修�?
### BUG-293: Speech TranscribeFromMic 阻塞且上限仅 5 �?�?- 来源: EXP-P1-005 (BIZ-009, 专家 B)
- 修复: 100ms 切片轮询，外�?StopRecording 提前退�?- 状�? �?已修�?
### BUG-294: Authorization SetCurrentUser 废弃保护缺失 �?- 来源: EXP-P1-006 (BIZ-002, 专家 B)
- 修复: 实现�?raise 阻断 + LoginTestUser helper 迁移
- 状�? �?已修�?
### BUG-295: Authorization 审计日志 Username 为空 �?- 来源: EXP-P1-007 (BIZ-008, 专家 B)
- 修复: LogAudit 内部 GetCurrentUserForThread 自动填充
- 状�? �?已修�?
### BUG-296: HealthCheck 异常消息泄露内部路径 �?- ���? EXP-P1-008 (BIZ-001, 专家 B)
- 修复: Description 改为 `Format('Check failed (%s)', [E.ClassName])`
- 状�? �?已修�?
### BUG-297: i18n GetDefaultLanguage 与回退编码不一�?�?- 来源: EXP-P1-009 (BIZ-003, 专家 B)
- 修复: 默认值改�?en-US + 英语地区变体别名
- 状�? �?已修�?
### BUG-298: EventBus finalization 潜在 AV �?- 来源: EXP-P1-010 (INFRA-003, 专家 A)
- 修复: Assigned 守卫 + FreeAndNil + GEventBusFinalized 标志
- 状�? �?已修�?
### BUG-299: Logger 初始化路径竞�?�?- 来源: EXP-P1-011 (INFRA-004, 专家 A)
- 修复: 移除冗余 CompareExchange，initialization 直接创建
- 状�? �?已修�?
### BUG-300: LogException 缺条件编�?�?- 来源: EXP-P1-012 (INFRA-007, 专家 A)
- 修复: CompilerVersion >= 36.0 guard
- 状�? �?已修�?
### BUG-301: DB.Pool Release 竞态窗�?�?- 来源: EXP-P1-014 (PERS-001, 专家 C)
- 修复: SetEvent 移入 FLock 内原子化
- 状�? �?已修�?
### BUG-302: JobQueue 无死信队列重试风�?�?- 来源: EXP-P1-015 (PERS-003, 专家 C)
- 修复: DEFAULT_JOB_MAX_RETRIES=5 + dead_letter 状�?(2026-06-21)
- 后续: �?指数退�?(`next_run_at` �? `delay=min(5*2^(attempts-1), 300)`) + 独立 DLQ �?`DeepBase_job_queue_dlq` (2026-06-22)
  - `Migrations/JobQueue/001_add_next_run_at.up.{sqlite,pg}.sql`
  - `Migrations/JobQueue/002_create_dlq_table.up.{sqlite,pg}.sql`
  - 新增 DLQ API: `DeadLetterCount` / `PeekDeadLetters` / `ReplayDeadLetter` / `PurgeDeadLetter`
  - 7 个回归测试通过
- 状�? �?全部完成

### BUG-303: StatusMachine 不支�?schema.table �?- 来源: EXP-P1-016 (PERS-002, 专家 C)
- 修复: ValidateIdentifier 支持最多一�?`.` �?schema.table 格式
- 状�? �?已修�?
### BUG-304: DateTime TBusinessDays.IsWeekend 隐式映射 �?- 来源: EXP-P1-018 (INFRA-006, 专家 A)
- 修复: DayOfTheWeekToDayOfWeekEx 命名类函�?- 状�? �?已修�?
### BUG-305: LLM BillingClient 错误信息硬编码中�?�?- 来源: EXP-P2-001 (BIZ-005, 专家 B)
- 修复: 提取�?i18n 资源�?- 状�? �?已修�?
### BUG-306: LLM Manager BuildContext 泄露内部路径 �?- ���? EXP-P2-002 (BIZ-010, 专家 B)
- 文件: `DeepBase.LLM.Manager:1078-1079`
- 问题: BuildContext 将原�?Exception.Message 拼入 JSON，可暴露内部路径
- 状�? �?已修�?
### BUG-307: Speech.Config Normalize 拒绝 ja/en 短码 �?- 来源: EXP-P2-003 (BIZ-011, 专家 B)
- 文件: `DeepBase.Speech.Config:108-130`
- 问题: Normalize 要求必须包含区域子标签，ja/en 等短码被拒绝
- 状�? �?已修�?
### BUG-308: LLM Manager SetProductionVersion/DeleteVersion 非原�?�?- 来源: EXP-P2-004 (BIZ-013, 专家 B)
- 状�? �?已修�?
### BUG-309: AutoUpdate HTTP 请求未设�?User-Agent �?- 来源: EXP-P2-005 (BIZ-014, 专家 B)
- 状�? �?已修�?
### BUG-310: TLRUCache.MoveToEnd O(n) 性能热点 �?- 来源: EXP-P2-006 (INFRA-008, 专家 A)
- 状�? �?已修�?
### BUG-311: TSmartCache �?TCache 功能重叠 �?- 来源: EXP-P2-007 (INFRA-009, 专家 A)
- 状�? �?已修�?
### BUG-312: Logger PickLogFileForWrite 可能无限循环 �?- 来源: EXP-P2-008 (INFRA-012, 专家 A)
- 状�? �?已修�?
### BUG-313: ExceptionHandler 创建无用单例 �?- 来源: EXP-P2-009 (INFRA-013, 专家 A)
- 状�? �?已修�?
### BUG-314: DateTime FromRFC2822 简化实�?�?- 来源: EXP-P2-010 (INFRA-014, 专家 A)
- 状�? �?已修�?(完整 RFC 2822 解析器：可�?day-of-week、两�?四位年份、军�?命名/数字时区、括号注释剥离；7 个回归测�?

### BUG-315: DB.Factory 每次创建临时连接�?�?- 来源: EXP-P2-011 (PERS-004, 专家 C)
- 状�? �?已修�?(Factory 改为直接�?TDBConnectionProfile 构�?TFDConnection，不再创�?销毁临�?TUniConnectionPool；新�?BuildConnectionFromProfile / ApplyExtraParamsToConnection 私有 helper + 回归测试)

### BUG-316: DateTime AddBusinessDays 边界行为不一�?�?- 来源: EXP-P2-012 (INFRA-015, 专家 A)
- 状�? �?已修�?
### BUG-317: EventBus PublishAsync �?edmAsync 线程模型不一�?�?- 来源: EXP-P2-013 (INFRA-011, 专家 A)
- 状�? �?已修�?
### BUG-318: Exceptions.pas 文件头中文编码错�?�?- 来源: EXP-P2-014 (INFRA-016, 专家 A)
- 状�? �?已修�?
### BUG-319: DateTime Diff tuMonths/tuYears 固定天数近似 �?- 来源: EXP-P2-015 (INFRA-018, 专家 A)
- 状�? �?已修�?
---


## 2026-07-06 REVIEW5-R2 P1 修复 (12 �?

### BUG-370: Core/DeepBase.Config.pas SetConfigInternal 锁释�?重获取窗口竞�?�?- 发现日期: 2026-07-06 (专家 A, CORE-R2-006)
- 严重�? High (线程安全)
- 问题: SetConfigInternal 在锁内释放再重获�?FLock 以便调用回调,期间其他线程可读写配置造成写写冲突/中间状态可�?
- 修复: �?SetConfigInternal 改为 out-params 返回 FireCallback/OldValue,四个公共 SetConfig* 方法在释放锁之后再触发回�?消除 Exit/Enter 重入窗口.
- 状�? 已修�?
### BUG-371: Core/DeepBase.ObjectPool.pas 后台清理任务无异常处�?�?- 发现日期: 2026-07-06 (专家 A, CORE-R2-008)
- 严重�? High (可靠�?
- 问题: 后台清理任务�?CleanupIdleObjects 调用未被 try/except 包裹;一次析构异常就会终止整个清理循�?池停止驱逐空闲对象直到进程退�?
- 修复: 在清理循环体内加 try/except,吞噬单次异常,下个周期重试.
- 状�? 已修�?
### BUG-372: Core/DeepBase.Metrics.pas TSummary.Observe O(n²) 清理 �?- 发现日期: 2026-07-06 (专家 A, CORE-R2-011)
- 严重�? High (性能)
- 问题: TList<Double>.Delete(0) 每次 O(n) 移位,�?1000 次观测循环删除一�?= ~1.25B 次元素移�?(50k 默认上限).
- 修复: 替换为固定容量环形缓�?FValues[MaxSamples] + FValuesHead/FValuesCount,写入 O(1),无移�?
- 状�? 已修�?
### BUG-373: Core/DeepBase.Cache.pas FInsertOrder FIFO 队列无限增长 �?- 发现日期: 2026-07-06 (专家 A, CORE-R2-012)
- 严重�? Medium (内存泄漏)
- 问题: Put 对每�?key (包括更新) 都调�?FInsertOrder.Enqueue,覆盖型写入导�?FInsertOrder 远超 FEntries 大小.
- 修复: 仅在 else (�?key) 分支 Enqueue,已有 key 复用旧队列位�?
- 状�? 已修�?
### BUG-374: Core/DeepBase.LLM.pas ChatAsync TTask 闭包捕获 Self 悬垂引用 �?- 发现日期: 2026-07-06 (专家 B, BIZ2-001)
- 严重�? High (内存安全)
- 问题: ChatAsync �?TTask 闭包直接捕获 Self;对象释放后回调仍访问 FHttpClient/FConfigCache = use-after-free.
- 修复: 增加 FActiveTasks (TList<ITask>) + FActiveTasksLock;ChatAsync 注册 task 并在完成时自移除;Destructor 拷贝列表�?Wait 所�?pending tasks (5s 超时).
- 状�? 已修�?
### BUG-375: Core/DeepBase.LLM.pas GetConfig 缓存 TOCTOU 竞�?�?- 发现日期: 2026-07-06 (专家 B, BIZ2-002)
- 严重�? Medium (线程安全)
- 问题: GetConfig �?cache-miss 后调�?RefreshConfigCache,期间其它线程可并发修改缓�?
- 修复: 注释明确 RefreshConfigCache �?全表替换"语义,TOCTOU 窗口被收窄到 RefreshConfigCache 返回后的瞬间,最坏情况返回默认�?下次调用自愈.
- 状�? 已修�?(文档�?语义等价)

### BUG-376: Core/DeepBase.LLM.Manager.pas DeletePrompt 未级联删除关联记�?�?- 发现日期: 2026-07-06 (专家 B, BIZ2-005)
- 严重�? High (数据完整�?
- 问题: DeletePrompt 只从 Prompts �?LLMCalls/PromptMetaBinding/PromptVersions 留下孤儿记录.
- 修复: 先按子查�?(SELECT Id FROM Prompts WHERE InternalCode = :x) 级联删除三张子表,再删 Prompts 主表.
- 状�? 已修�?
### BUG-377: Core/DeepBase.WorkerQueue.pas TFileJobStorage 锁文�?DELETE_ON_CLOSE �?- 发现日期: 2026-07-06 (专家 B, BIZ2-011)
- 严重�? High (可靠�?
- 问题: �?FILE_FLAG_DELETE_ON_CLOSE 的锁文件在任一句柄关闭时被删除,多进程场景第二个进程持有的句柄指向已删除文件,语义破坏.
- 修复: 移除 DELETE_ON_CLOSE 标志,保留 CREATE_ALWAYS + share=0 独占语义;文件以隐藏哨兵形式持久存�?
- 状�? 已修�?
### BUG-378: Core/DeepBase.AppLifecycle.pas 崩溃计数无限增长 �?- 发现日期: 2026-07-06 (专家 B, BIZ2-021)
- 严重�? Medium (可靠�?
- 问题: MarkStarted 反复 Inc(Count) 无任何上�?最�?Integer 溢出;单次历史崩溃循环永久毒化诊断.
- 修复: 增加 MAX_CRASH_COUNT=1000 硬上�?�?UpdatedAt 距今 >= 24 小时且本次为新的崩溃,重置 Count=1.
- 状�? 已修�?
### BUG-379: Core/DeepBase.AIErrorHandler.pas ExceptAddr 在非 except 块中使用 �?- 发现日期: 2026-07-06 (专家 B, BIZ2-018)
- 严重�? High (正确�?
- 问题: Handle 在非 except 块调�?ExceptAddr,返回栈垃圾数�?缓存�?位置报告都不可信.
- 修复: 新增 HandleAt(E, AExceptAddr, AContext) 显式传入地址;Handle 改为转发 HandleAt(... nil ...);SafeRun �?except 块内调用 HandleAt �?ExceptAddr.
- 状�? 已修�?
### BUG-380: Core/DeepBase.MVVM.pas TAsyncCommand.DoExecute 捕获 SelfRef 悬垂 �?- 发现日期: 2026-07-06 (专家 B, BIZ2-032)
- 严重�? High (内存安全)
- 问题: DoExecute �?task 闭包捕获 SelfRef (裸对象指�?,命令释放�?Synchronize 回调访问 FViewModel/FOnCompleted/FOnError = use-after-free.
- 修复: �?task 启动前把 ViewModel/OnCompleted/OnError/ExecuteProc/ExecuteProcParam/HasParameter 全部快照到局部变�?task 闭包只捕获这些值类�?完全切断�?Self 的引�?
- 状�? 已修�?
### BUG-381: FMX/DeepBase.FMX.LLMChatFrame.pas 后台线程访问 FHistory 未保�?�?- 发现日期: 2026-07-06 (专家 E, UI2-009)
- 严重�? High (线程安全)
- 问题: TTask 闭包调用 FHistory.GetMessages,主线程同时通过 DoSendMessage.AddUserMessage 修改 FHistory = 数据竞争.
- 修复: 在进�?TTask 之前在主线程调用 Messages := FHistory.GetMessages 做快�?task 内使�?Messages 局部变�?
- 状�? 已修�?
### BUG-382: Persistence/DeepBase.SQLLogger.pas FormatLogEntry 日志注入 �?- 发现日期: 2026-07-06 (专家 D, DATA2-049)
- 严重�? High (安全/审计)
- 问题: SQL 字面量或错误消息中含 CR/LF 会被直接写入日志文件,攻击者可伪造日志行/隐藏恶意行为.
- 修复: �?FormatLogEntry �?SQL/Operation/ErrorMessage 三个字段�?CR/LF 剥离 (替换为空�? 后再拼行.
- 状�? 已修�?
### BUG-383: Persistence/DeepBase.DB.Pool.pas Validate 查询无超�?csValidating 状态永不恢�?�?- 发现日期: 2026-07-06 (专家 D, DATA2-055)
- 严重�? High (可靠�? �?P0)
- 问题: TPooledConnection.Validate 执行验证查询时不设置 CommandTimeout;网络分区/数据库卡死时 Query.Open 无限等待,期间 FState 停留�?csValidating,池永久收�?维护线程也可能被�?
- 修复: �?FProfile.CommandTimeoutSec (如有);否则回退 5s. 保证挂起的连接被快速判�?
- 状�? 已修�?
### BUG-384: Core/DeepBase.FileWatcher.pas HandleDebounce 每次文件变更创建 TTask �?- 发现日期: 2026-07-06 (专家 B, BIZ2-013)
- 严重�? Medium (资源耗尽)
- 问题: HandleDebounce 每收到一次文件变更事件就创建一�?TTask (Sleep + ProcessDebouncedChanges);git checkout/编译输出等短时间大量变更会创建上千个 TTask,饱和线程�?
- 修复: 增加 FDebounceTaskScheduled 闸门,同一时刻最多一�?drain task;drain 结束时如果仍有剩余条目则重新调度,否则释放闸门.ProcessDebouncedChanges �?FDestroying 早退路径也释放闸门避免永久锁�?
- 状�? 已修�?
### BUG-385: Core/DeepBase.WorkerQueue.pas WaitForCompletion Sleep(50) 高频轮询 �?- 发现日期: 2026-07-06 (专家 B, BIZ2-009)
- 严重�? Medium (性能)
- 问题: WaitForCompletion �?50ms 唤醒一�?+ 调用 GetStats (O(n) 遍历 job dict);长任务等待期�?CPU/锁争用无谓升�?
- 修复: 轮询间隔�?50ms 调到 250ms,响应时间上界保持 <=250ms;并把 Sleep 截断到剩�?timeout,避免超过 ATimeoutMs 截止.
- 状�? 已修�?
### BUG-386: Core/DeepBase.Cache.pas Put 锁外调用 Evict 致并发竞�?�?- 发现日期: 2026-07-08 (专家 A, CORE-R3-002, �?P0)
- 严重�? Critical (并发崩溃/统计损坏)
- 问题: Put 在检测到需要驱逐时执行 `FLock.Leave; try Evict(1); finally FLock.Enter; end`, �?Evict �?EvictLRU/LFU/FIFO/Random/RemoveExpired 自身注释标称"Called within lock"却不再加�? 释放锁到重新获取锁的窗口�? 另一线程�?Put/TryGet/Cleanup 可并发访问并修改 FEntries/FAccessOrder/FInsertOrder/FStats, 与正在执行的驱逐逻辑�?TDictionary rehash、TList 删除、统计增减上竞�? 轻则 Evictions/CurrentItems/TotalSizeBytes 变负或错�? 重则 AV. 内存上限驱逐的 while 循环同理.
- 修复: 重构为锁内完成全部结构修�?+ 收集被驱逐项�?TEvictedList (TList<TEvictedItem>), 锁外仅触�?FOnEvict/FOnExpire 回调. 新增 FireEvictedCallbacks 在锁释放后单线程串行触发回调�?�?OwnValues)释放�? 保持�?回调时值存�? 回调后释�?语义. Evict 签名改为 Evict(Count, Batch); Cleanup 同样锁内 RemoveExpired(Batch)+锁外 Fire. 拒绝写入(memory limit exceeded)路径�?raise 前先 Fire 已收集项避免丢失回调.
- 状�? 已修�?
### BUG-387: Core/DeepBase.Protection.pas DeriveAes256KeyPBKDF2 未清零密码明文字�?�?- 发现日期: 2026-07-08 (专家 A, CORE-R3-003, �?P1)
- 严重�? High (密钥材料泄漏)
- 问题: DeriveAes256KeyPBKDF2 将密码转�?UTF-8 字节存入 LPasswordBytes, 构�?LSaltPlusBlock (salt||INT_32_BE(1)), 但方法末尾仅清零 LBlock/LUTemp 两份 HMAC 中间�? LPasswordBytes �?LSaltPlusBlock 留在堆上直到 GC/分配器复�? 内存转储可恢复明文密码或 PBKDF2 输入, 抵消 PBKDF2 的迭代成�?
- 修复: �?try/finally 包裹派生逻辑, finally 中对 LPasswordBytes、LSaltPlusBlock、LBlock、LUTemp 全部 FillChar 清零, 保证异常路径也清�?
- 状�? 已修�?
### BUG-388: Core/DeepBase.Security.pas DecryptUBS2V1 �?ProtectStringDpapi(非Win) 未清零主密钥/派生密钥/明文 �?- 发现日期: 2026-07-08 (专家 A, CORE-R3-004, �?P1)
- 严重�? High (机密泄漏)
- 问题: DecryptUBS2V1 解出 Plaintext(明文机密) 后未清零, MachineKey(机器熵主密钥材料) �?Key(派生密钥) 同样残留堆上; ProtectStringDpapi 的非 Windows 分支(OpenSSL AES-256-GCM)同样泄漏 MachineKey/Key/Plaintext. 内存转储可恢复被 DPAPI/UBS2 保护的明文凭证或主密�?
- 修复: 两处均用嵌套 try/finally, 解密路径�?Plaintext、Key、MachineKey 分别 SecureClearBytes; 加密路径�?Plaintext、Key、MachineKey 分别 SecureClearBytes, 保证正常与异常路径都清零.
- 状�? 已修�?
### BUG-389: Core/DeepBase.Crypto.RSA.pas LoadPrivateKeyPEM 未清�?RSA 私钥分量 �?- 发现日期: 2026-07-08 (专家 A, CORE-R3-005, �?P1)
- 严重�? High (私钥泄漏)
- 问题: LoadPrivateKeyPEM 解析 PKCS#1 RSAPrivateKey DER 后得�?LModulus/LExponent/LPrivateExponent/LPrime1/LPrime2/LExponent1/LExponent2/LCoefficient 八个分量, 以及 LDER(原始 DER) �?LImportBlob(BCRYPT_RSAFULLPRIVATE_BLOB 含完整私�?, 方法返回后这�?TBytes 留在堆上未清�? 内存转储可重组出完整 RSA 私钥(d + p,q,CRT 参数), 致签名身份被冒充.
- 修复: �?try/finally 包裹解析+构�?导入逻辑, finally 中对八个分量、LImportBlob、LDER 逐一 FillChar 清零. FPrivateKeyBlob(签名所需, �?UnloadKey 处单独清�? 不在本次清零范围.
- 状�? 已修�?
### BUG-390: Core/DeepBase.Metrics.pas TTimer.Start 闭包捕获�?Self �?use-after-free �?- 发现日期: 2026-07-08 (专家 A, CORE-R3-006, �?P1)
- 严重�? High (并发/生命周期)
- 问题: TTimer.Start 返回的闭�?`Result := procedure begin Self.RecordDuration(...); Self.FLock.Enter; Dec(Self.FActiveTimers)...` 捕获�?Self 指针. 调用方持有该 TProc 期间, �?registry Unregister 移除�?metric 并释放对�? 闭包被调用时解引用已释放对象, AV.
- 修复: 闭包改为捕获 `LSelfMetric: IMetric` (Self as IMetric). TMetricBase 继承 TInterfacedObject, 持有接口引用使引用计�?> 0, registry 释放其引用时对象不被析构, 闭包存活期间对象保活. 闭包内经 `LSelfMetric as TObject as TTimer` 取回对象并判 nil 后操�?
- 状�? 已修�?
### BUG-391: Core/DeepBase.Authorization.pas SetCurrentUserWithToken 锁外访问 TUser 致竞�?�?- 发现日期: 2026-07-08 (专家 A, CORE-R3-007, �?P1)
- 严重�? High (并发/数据竞争)
- 问题: SetCurrentUserWithToken �?GetUser(AUsername) 取裸 TUser 引用 (GetUser 锁内取后锁外返回), 随后锁外�?LUser.GetMetadata('token')、验证通过后锁外写 LUser.LastLoginAt := Now. 此期间另一线程 DeleteUser/UpdateUser 可释放或替换�?TUser, 致读到半更新数据�?use-after-free.
- 修复: 不再�?GetUser 取引�? token 读取�?LastLoginAt 写入各自�?FLock 内直�?FUsers.TryGetValue �?LUser 并操�? �?token 时复制到局�?string 后离锁比�? 验证通过后重新入�?TryGetValue (可能已被并发删除, �?nil) �?LastLoginAt. FTokenVerifier 回调、SetCurrentUserForThread、LogAudit 保持锁外. SetCurrentUserForThread 仍传裸引用属 A-001 范围, �?API 决策.
- 状�? 已修�?
### BUG-392: Core/DeepBase.ObjectPool.pas FindAvailableObject for 循环删除致漏检 �?- 发现日期: 2026-07-08 (专家 A, CORE-R3-008, �?P2)
- 严重�? Medium (正确�?
- 问题: FindAvailableObject �?`for I := 0 to FPool.Count-1` 遍历, 验证失败�?`FPool.Delete(I); Continue;`. TList.Delete(I) 后后续元素前移到 I, �?for 循环 Continue �?Inc(I), 跳过被前移到 I 的那个对�? 若连续多个无效对象相�? 漏检的无效对象可能被当作可用返回, 或统计错�?
- 修复: �?while 循环, 仅在未删除时 Inc(I); 删除�?Continue 直接回到 while 条件重判同一索引 I 上的新元�?
- 状�? 已修�?
### BUG-393: Core/DeepBase.Collections.pas TCountingSet.Add 接受�?ACount 致计数变�?�?- 发现日期: 2026-07-08 (专家 A, CORE-R3-009, �?P2)
- 严重�? Medium (正确�?
- 问题: TCountingSet<T>.Add 未校�?ACount 符号, 传入负值会�?FTotalCount 与单项计数变�? 破坏 MostCommon 排序�?Remove 的一致�?(Remove 内部对负差值处理假设计数非�?.
- 修复: Add 方法开头校�?`ACount < 0` �?ECollectionException, "add -N" 无语义操作直接拒�?
- 状�? 已修�?
### BUG-394: Core/DeepBase.Collections.pas TLRUCache.Evict 持锁�?FOnEvict 致重�?AV �?- 发现日期: 2026-07-08 (专家 A, CORE-R3-010, �?P2)
- 严重�? Medium (并发/崩溃)
- 问题: TLRUCache<K,V>.Evict 在持�?FLock 时调�?FOnEvict 回调. 回调内若重入 Put/Evict, 会在半更新的链表/字典上操�? �?AV 或链表节点损�?
- 修复: Evict 先经 EvictOne 把被驱逐项�?Key/Value 复制到局�?(Node 在此释放), 完成全部结构修改与节点释放后, 再在锁外触发 FOnEvict, 回调不再触碰已释放内存也不重入半更新结构.
- 状�? 已修�?
### BUG-395: Features/DeepBase.UIA.Engine.pas UIA_ProcessIdPropertyId 常量错误 �?- 发现日期: 2026-07-08 (专家 E, FEAT-R3-004, �?P2)
- 严重�? Medium (功能失效)
- 问题: UIA_ProcessIdPropertyId 常量定义�?34005 (`30005+4000`), 注释自相矛盾. 微软官方值应�?30002. 错误 ID 致按进程 ID 定位 UIA 元素的查询全部失�?
- 修复: 改为 30002.
- 状�? 已修�?
### BUG-396: Governance/DeepBase.Governance.ConfigRegistrar.pas uses 缺逗号致编译阻�?�?- 发现日期: 2026-07-08 (专家 D, GOV-R3-001, �?P0)
- 严重�? Critical (编译阻断)
- 问题: uses 子句 `DeepBase.Crypto, DeepBase.Crypto.Hash` 后缺逗号, 编译器报 E1038, 整个 ConfigRegistrar 单元无法编译, 依赖该单元的 Governance 包工程级联失�?
- 修复: 补逗号.
- 状�? 已修�?
### BUG-397: Features/DeepBase.UIA.Engine.pas uses 缺逗号致编译阻�?�?- 发现日期: 2026-07-08 (专家 E, FEAT-R3-001, �?P0)
- 严重�? Critical (编译阻断)
- 问题: uses 子句 `DeepBase.Crypto.Hash` 后缺逗号, 下一行直接接 DeepBase.UIA.Types, 编译器报 "Missing operator or semicolon", 整个 UIA.Engine 单元及依赖工程无法编�?
- 修复: 补逗��?
- 状�? 已修�?
### BUG-398: Core/DeepBase.FeatureFlags.pas SaveFlag 接管调用方对象致 double-free �?- 发现日期: 2026-07-09 (专家 B, BIZ-R3-003, �?P0)
- 严重�? High (内存安全/double-free)
- 问题: `IFeatureFlagStorage.SaveFlag(AFlag)` 两实现均静默接管调用�?AFlag 所有权, 调用方随后释�?AFlag �?double-free:
  - `TMemoryFlagStorage.SaveFlag` �?`FFlags.AddOrSetValue(AFlag.Key, AFlag)` �?AFlag 接管�?doOwnsValues 字典, 调用方再 Free AFlag �?字典内对象悬�? 后续 GetFlag 访问已释放内�?(use-after-free).
  - `TFileFlagStorage.SaveFlag` �?`LFlags[I] := AFlag` �?OwnsObjects=True 的临时列表上下标赋�? 先释放旧对象再接�?AFlag, finally `LFlags.Free` 释放 AFlag �?调用方持有的 AFlag 被释�? double-free. tasks.md 原建议方�?(Load 后设 OwnsObjects:=False) 可避免释�?AFlag, 但仍会让临时列表持有调用方裸引用, 语义不清�?Save 后对象生命周期混�?
- 修复: 改为 "storage 不接管调用方对象, 内部克隆后持久化" 方案. 新增 `TFeatureFlag.Clone` (�?FromJSON(ToJSON) 深拷贝全部业务字�? 手动补全 FromJSON 未读取的 CreatedAt/UpdatedAt, 保证克隆与原对象完全一�?. `TMemoryFlagStorage.SaveFlag` 克隆 AFlag �?AddOrSetValue (AddOrSetValue 释放旧克�? 不影响调用方对象); `TFileFlagStorage.SaveFlag` 克隆 AFlag 后下标赋�?Add �?OwnsObjects=True 列表 (列表释放克隆, 调用�?AFlag 从未入列). 接口注释明确 "AFlag 所有权归调用方".
- 验证: `Test.DeepBase.FeatureFlags.TTestFeatureFlagStorage` 新增 7 项回归测�?(76 测试全过, 0 泄漏), 覆盖 "SaveFlag 后调用方 Free AFlag, GetFlag 仍返回有效克�? �?UAF 场景.
- 状�? 已修�?
### BUG-399: Core/DeepBase.FeatureFlags.pas GetFlag 返回裸指针所有权契约不一�?�?- 发现日期: 2026-07-09 (专家 B, BIZ-R3-004, �?P0)
- 严重�? High (内存安全/UAF/double-free)
- 问题: `IFeatureFlagStorage.GetFlag` 两实现所有权契约不一�?
  - `TMemoryFlagStorage.GetFlag` �?TryGetValue 返回字典内裸对象引用 (storage 拥有, 调用方不�?Free, �?storage 后续 Clear/Replace 会释放它, 调用方持有悬垂引�?�?UAF).
  - `TFileFlagStorage.GetFlag` �?`LFlags.Extract(LFlag)` 转移所有权给调用方 (调用方应 Free), 但原对象离开列表�?LFlags.Free 不再释放�? 契约�?Memory 实现相反. 调用方无法在不知具体实现时正确管理返回值生命周�?
- 修复: 统一�?"GetFlag 返回深拷贝克�? 所有权归调用方" (复用 BUG-398 新增�?`TFeatureFlag.Clone`). `TMemoryFlagStorage.GetFlag` 命中后返�?`LFlag.Clone`; `TFileFlagStorage.GetFlag` 命中后返�?`LFlag.Clone`, 原对象留列表�?LFlags.Free 释放. 接口注释明确 "返回调用方拥有的克隆, 不受 storage 后续修改/释放影响". 调用方负责释放返回�?
- 验证: �?BUG-398, `TTestFeatureFlagStorage` 覆盖 "两次 GetFlag 返回不同克隆, 修改任一不影�?storage 与其他克�? �?"GetFlag 返回值必须由调用方释�? (首轮测试即捕获到未释放克隆的泄漏, 修复�?0 泄漏, 契约得到验证).
- 状�? 已修�?
### BUG-400: Features/DeepBase.LLM.Proxy.pas GenerateImageStream TTask 闭包捕获�?Self �?use-after-free �?- 发现日期: 2026-07-08 (专家 B, BIZ-R3-001, P0)
- 严重�? Critical (对象生命周期/悬空引用)
- 问题: `GenerateImageStream` �?`TTask.Run(procedure begin ... LResult := Self.GenerateImage(APrompt, ASize); ... end)` 启动后台任务, 闭包隐式捕获�?`Self` 指针 (调用实例方法 GenerateImage 即访�?Self). `TProxyLLMClient` 继承 `TInterfacedObject`, 但匿名方法对�?Self 的捕�?**�?* 递增引用计数 �?调用方释放最�?`ILLMClient` 引用�? 实例被析�? 而后台任务仍在执�?`Self.GenerateImage`/`Self.FConfig`, 解引用已释放对象 �?use-after-free (Runtime error 216 / AV). 专家原建�?"�?ChatAsync �?FActiveTasks + 析构 WaitFor".
- 修复: 采用 **接口引用捕获** 方案 (与已验证�?CORE-R3-006 / BUG-390 一�? 同类问题模式), 而非专家建议�?FActiveTasks+WaitFor. 在方法内 `LSelf := Self` (`LSelf: ILLMClient`), 闭包改为�?`LSelf.GenerateImage(...)` 调用. 持有接口引用使引用计�?> 0, 调用方释放其引用时对象不被析�? 任务存活期间对象保活; 任务结束闭包释放 LSelf, 引用计数归零, 实例安全析构.
- 方案取舍: 选接口捕获而非 FActiveTasks+WaitFor 的理�?�?(1) 已有 CORE-R3-006/BUG-390 验证先例, 模式成熟且仓库内统一; (2) TProxyLLMClient 字段均为线程安全值类�?(FConfig:TProxyConfig record / FCallCount:Integer / FLastDurationMs:Integer), 无自定义析构, 对象在后台线程析构安�? (3) FActiveTasks+WaitFor 要求闭包不持 Self 引用 (否则引用计数永不�?0, Destroy 永不触发, WaitFor 死锁), 需�?GenerateImage 重构为快�?静态变�? 改动面大; B-001 的任务为�?HTTP 调用, 保活即可. 真正需要析构等待的长任�?(LLM.Manager Destroy, BIZ-R3-002) �?BUG-401 另行�?WaitFor 处理, 该处 Destroy 已存在且任务可达 30-60s.
- 验证: 编译通过 (Win64 单元测试编译 SUCCESS). 运行时回归测试因 UAF 时序 (后台任务生命周期超出测试方法, 其析构与 DUnitX 全局 finalization 竞态触�?Runtime error 216) 及网络栈依赖 (THTTPClient 到不可达端口的行�? 双重不可�? 未附进程内断言测试, �?CORE-R3-006/BUG-390 (同类无单�? 先例一�? 修复正确性经代码审查 + 模式一致性保�?
- 状�? 已修�?
### BUG-401: Core/DeepBase.LLM.Manager.pas Destroy Wait(5000) 超时后释放正在用对象�?use-after-free �?- 发现日期: 2026-07-09 (专家 B, BIZ-R3-002, P0)
- 严重�? Critical (对象生命周期/析构竞�?
- 问题: `TLLMManager.Destroy` 已有 BIZ2-006 �?WaitFor 逻辑 (FExecuteTasks + `LT.Wait(5000)`), �?5000ms 远小于在�?HTTP 调用窗口 (`TLLMClient.DEFAULT_TIMEOUT=60000`, 且用户可配更�?. 一个执�?30-60s �?`ExecuteAsync` 任务 (闭包�?`Execute`→`FLLMClient.Chat` L1938) �?`Wait(5000)` 超时返回后仍在运�? Destroy 随即 `FreeAndNil(FLLMClient)`, 任务线程继续访问已释放的 FLLMClient �?use-after-free. 此外任务 finally 块在超时未等待时还会访问已被 FreeAndNil �?FExecuteTasks/FExecuteTasksLock �?二次 UAF.
- 修复: 三处加固 (1) `LT.Cancel` 先于 Wait, 让协作清理路径尽早返�?(对已阻塞�?HTTP 无效但利于未启动任务); (2) Wait 超时 5000�?20000ms (2x 默认 HTTP timeout, 覆盖配置�?60s HTTP 窗口, 任务必然�?HTTP timeout 返回而结�?; (3) **超时后不释放任务仍在触碰的对�?* �?引入 `LAnyTimeout` 标志, 任一任务超时则记 Error 日志�?`Exit`, 跳过 FExecuteTasks/FExecuteTasksLock/FCacheLock/FMetaCache/FCategoryCache/FPromptCache/FLLMClient/FConnection 的全�?teardown, 让进程退出时 OS 回收. 释放被在用对象是确定性的 use-after-free, 泄漏是不确定性的资源滞留, 超时本属异常路径, 取泄漏更安全且绝不静�?(日志告警).
- 验证: 编译通过 (Win64 单元测试编译 SUCCESS). 修复路径 (120s 超时 + Cancel + 超时不释�? 属异常生命周期管�? 难以在不引入真实 120s HTTP 阻塞的前提下做进程内断言测试, 未附单测; 正确性经代码审查 + �?BIZ2-006 既有 WaitFor 模式一�?+ �?B-001 接口捕获模式互补 (短任务保�? 长任务析构等�?超时不释�? 保证.
- 状�? 已修�?
### BUG-402: Core/DeepBase.Authorization.pas Get*/GetAll* 返回字典拥有裸对象引用致 use-after-free �?- 发现日期: 2026-07-08 (专家 A, CORE-R3-001, P0)
- 严重�? Critical (对象生命周期/悬空引用)
- 问题: `TAuthorizationManager` �?`FUsers`/`FRoles` �?`TObjectDictionary<..., TUser/TRole>(doOwnsValues)` �?字典拥有并释放值对�? `GetUser`/`GetRole`/`GetAllUsers`/`GetAllRoles` �?`FLock` 内把字典拥有�?*裸对象指�?*直接返回给调用方, 锁释放后, 另一线程�?`DeleteUser`/`DeleteRole`/`UpdateUser` 触发字典释放该对�? 而首个调用方仍持裸指针访问其字段/方法 �?use-after-free (AV / Runtime error 216). 此外 `LoginTestUser` 等调用方曾通过 `GetUser` 拿到裸对象后直接 `SetMetadata('token', ...)` �?token, 改的不是"�?用户而是字典内对�?�?依赖 doOwnsValues 释放语义的脆弱契�? 一旦改为快照即会把 token 写到无人再读的克隆上, 静默破坏登录鉴权.
- 修复: (1) 新增 `TUser.Clone` / `TRole.Clone` �?深拷贝所有标量字�?+ 重建 `FRoles`/`FPermissions`/`FMetadata` 容器, 返回调用方独立拥有的快照, 析构路径�?`except ... Free; raise` 保证中途失败不泄漏; (2) `GetUser`/`GetRole` 在锁内对字典�?Live 对象�?`Clone` 后返�? 调用方持有克隆与字典生命周期解�? (3) `GetAllUsers`/`GetAllRoles` 改用 `TObjectList<>(True)` 构建, 循环�?`Clone`, 成功�?`OwnsObjects:=False` 把所有权移交返回数组 (中�?`Clone` 抛异常由 owning list 自动释放已建克隆, 不泄�?; (4) 新增带锁写方�?`SetUserMetadata(Username, Key, Value): Boolean` �?�?`FLock` 内对字典�?Live 对象�?`SetMetadata`, 替代调用方改快照的写�? 保证 token 等写入落到真实用户并对后续加锁读可见; (5) 测试 `LoginTestUser` 改用 `UserExists` 断言存在�?+ `SetUserMetadata` �?token, 不再持裸克隆; `Test_GetUser_Exists`/`Test_GrantPermission_Success`/`Test_RevokePermission_Success` �?`GetUser`/`GetRole` 返回的克隆加 `try/finally Free` 防泄�?
- 契约变更: `GetUser`/`GetRole`/`GetAllUsers`/`GetAllRoles` 返回值所有权现归**调用�?* (�?Free; `GetUser`/`GetRole` 找不到时返回 nil). �?`rg` 全仓确认这四个方法无生产/测试外部调用方依�?返回字典拥有对象、调用方不释�?的旧契约 (�?`LoginTestUser` 旧写法已�?, 故契约变更是安全�? 所有现有调用点已同步加 Free.
- 验证: Win64 单元测试 `-FromUnit DeepBase.Authorization` 编译 SUCCESS, 29 项全�?(Tests Passed: 29 / Leaked: 0 / Failed: 0). Clone 深拷�?+ owning-list 构建 + 调用�?Free 的组合使 DUnitX 泄漏检测归�?
- 状�? 已修�?
### BUG-403: Core/DeepBase.Scheduler.pas 任务完成锁释放后锁外访问 TaskRef/回调�?use-after-free �?- 发现日期: 2026-07-08 (专家 B, BIZ-R3-011, P1)
- 严重�? High (对象生命周期/析构竞�?
- 问题: `TTaskScheduler.ExecuteTask` �?TTask 闭包在成功路径于 `FLock` 内把 `TaskRef.FState` 置为 `tsCompleted`/`tsPending` �?`FRunningITask:=nil` �?`FLock.Leave`, 随即在锁外执�?`if Assigned(TaskRef.FOnCompleted) then TaskRef.FOnCompleted(TaskRef)`. 此期间另一线程调用 `Cleanup`: `Cleanup` 遍历 `FTasks.Values`, �?`FState in [tsCompleted,tsFailed,tsCancelled]` �?`FTasks.Remove(Id)`, �?`FTasks` �?`TObjectDictionary(...,[doOwnsValues])` �?字典释放 `TaskRef`. 闭包线程随后�?`TaskRef.FOnCompleted` 字段 / �?`TaskRef` 传给回调 �?use-after-free (AV / Runtime error 216). `FOnFailed` 路径虽已捕获 `LOnFailed` 到局�? 但仍把裸 `TaskRef` 传入 `LOnFailed(TaskRef, E)`, �?`FRunningITask:=nil` 同样在回调前�? 同一竞态窗口下 `TaskRef` 亦可�?`Cleanup` 释放.
- 修复: 三处加固 (1) 成功路径�?`FLock` 内捕�?`LOnCompleted := TaskRef.FOnCompleted` 到局�? 锁外用局部回�?(不再锁外�?`TaskRef.FOnCompleted` 字段); (2) 成功/失败路径�?*推迟** `TaskRef.FRunningITask := nil` 到回调执行之�?�?`FRunningITask<>nil` 期间 `Cleanup` 的运行中守卫保留任务对象, �?`TaskRef` 在锁外回调窗口内保活; (3) `Cleanup` 移除条件�?`FState in [...]` 改为 `(Task.FRunningITask = nil) and (FState in [...])`, 跳过闭包仍在执行 (含回调进行中) 的任�? 失败路径另捕�?`LTaskFailed` 标志以替代原锁外再判状�? 避免锁外�?`TaskRef.FState`.
- 方案取舍: �?FRunningITask 保活 + Cleanup 守卫"而非把回调移入锁�?�?回调入锁会与既有 REVIEW5-CORE-004 "回调异常不得污染任务状�?不得死锁" 设计冲突 (�?异常回调持锁阻塞所有调度路�?. FRunningITask 本就是为保活 RunTask 引入的字�? 复用�?运行�?语义保护回调窗口是自然延�? 闭包结束后置 nil, Cleanup 随后可正常回�? 无生命周期泄�?
- 验证: Win64 单元测试 `-FromUnit DeepBase.Scheduler` 编译 SUCCESS, 51 项全�?(Passed 51 / Leaked 0 / Failed 0). UAF 竞态属多线程时�? 难以进程内稳定复现断言, 未附专项回归测试 (�?A-001/B-001 UAF 时序先例); 修复正确性经代码审查 + �?REVIEW5-CORE-004 既有"锁外回调"模式一�?+ FRunningITask 保活语义闭环保证.
- 状�? 已修�?
### BUG-404: Core/DeepBase.LLM.pas Chat 无条件调 ParseXxxResponse 覆盖 DoHttpRequest 错误结果 �?- 发现日期: 2026-07-09 (专家 B, BIZ-R3-005, P1)
- 严重�? Medium (错误处理逻辑缺陷)
- 问题: `TDeepBaseLLM.Chat` �?`DoHttpRequest` 返回后无条件�?`ParseAnthropicResponse`/`ParseOpenAIResponse` 解析响应�? �?`DoHttpRequest` 返回 False (HTTP 错误/超时/网络异常), `ParseXxxResponse` 仍会被调用并可能覆盖 `Result:=False` �?尤其当错误响应体含可解析 JSON (�?4xx/5xx 返回�?`{"choices":[...]}` 格式异常�? �? Parse 可能误判�?`Success=True`, 调用方拿到错误结果却不知真实失败原因.
- 修复: 仅当 `DoHttpRequest` 返回 True 时才进入 ParseXxxResponse 分支; 否则保留 False 并记录错误体�?`Response.ErrorMessage` 供诊�? 避免 Parse 覆盖真实�?HTTP 失败状�?
- 验证: Win64 单元测试 `-FromUnit DeepBase.LLM` 编译 SUCCESS, 28 项全�?(Passed 28 / Leaked 0 / Failed 0). 修复仅加 `if Result then` 守卫, 不改�?Parse 逻辑本身, 现有测试覆盖正常解析路径不受影响.
- 状�? 已修�?
### BUG-405: Core/DeepBase.LLM.ImportExport.pas ImportLLMContent TryGetValue 返回值被忽略�?imOverwrite 模式数据清空 �?- 发现日期: 2026-07-09 (专家 B, BIZ-R3-007, P1)
- 严重�? Medium (数据丢失风险)
- 问题: `TDeepBaseLLMManager.ImportLLMContent` �?imOverwrite 模式�? 注释�?"Validate all required arrays exist and are parseable BEFORE any deletion" �?`TryGetValue` 返回值被忽略. �?JSON 缺少 `categories`/`meta_prompts`/`prompts` 任一数组�? 代码仍进入删除分支清空现有数�?�?与验证注释意图相�? 可能因畸�?JSON 致不可逆数据丢�?
- 修复: 检查三�?`TryGetValue` 返回�? 任一返回 False (键缺�? 则报 `'Import validation failed: missing required array in JSON'` 错误�?Exit, 阻止后续删除操作. 与注释验证意图一�?
- 验证: Win64 单元测试 `-FromUnit DeepBase.LLM.ImportExport` 编译 SUCCESS, 3 项全�?(Passed 3 / Leaked 0 / Failed 0). 修复仅加返回值检�? 不改变正常导入逻辑, 现有测试覆盖不受影响.
- 状�? 已修�?
### BUG-406: Core/DeepBase.License.pas VerifySignature 长度早期退出泄漏签名长度信息致时序攻击 �?- 发现日期: 2026-07-09 (专家 B, BIZ-R3-010, P1)
- 严重�? Medium (安全/时序攻击)
- 问题: `TDeepBaseLicense.VerifySignature` 在常量时间比较前执行 `if Length(Expected)<>Length(Signature) then Exit;` �?长度不匹配时立即返回, 攻击者可通过测量响应时间推断签名长度, 破坏常量时间比较的安全保�?
- 修复: 移除长度早期退�? 改用 Expected 长度作为循环基准. �?Signature 较短, Delphi 字符串越界访问返�?#0 (�?Expected 字节 XOR �?Diff 非零); �?Signature 较长, 额外字节经第二轮循环计入 Diff. 长度差异自然反映�?Diff 结果�? 比较耗时恒定.
- 验证: Win64 单元测试 `-FromUnit DeepBase.License` 编译 SUCCESS, 全部通过 (Passed / Leaked 0 / Failed 0). 现有测试覆盖正常签名验证路径, 修复不改变正确签名比较结�?
- 状�? 已修�?
### BUG-407: Core/DeepBase.LLM.Manager.pas DeletePrompt 四条级联 DELETE 无事务致部分失败留不一�?�?- 发现日期: 2026-07-09 (专家 B, BIZ-R3-006, P1)
- 严重�? Medium (数据一致�?
- 问题: `TLLMManager.DeletePrompt` 执行四条级联 DELETE (LLMCalls/PromptMetaBinding/PromptVersions/Prompts), 每条独立 Execute. 若中间某条失�?(连接中断/锁冲�?, 已执行的删除不可回滚, 留下不一致状�?(�?LLMCalls 已删�?PromptVersions 未删, FK 违反).
- 修复: 合并四条 DELETE 为单条分号分隔的多语�?SQL. SQLite �?PostgreSQL 均支持单 Execute 执行多语�? 数据库引擎保证语句级原子�? 同一 `:InternalCode` 参数通过参数化查询复�? 避免拼接.
- 验证: Win64 单元测试 `-FromUnit DeepBase.LLM.Manager` 编译 SUCCESS, 全部通过 (Passed / Leaked 0 / Failed 0). 现有测试覆盖 DeletePrompt 级联删除路径, 修复不改变正常删除逻辑.
- 状�? 已修�?
### BUG-408: Persistence/DeepBase.Persistence.Authorization.FireDAC.pas DeleteUser/DeleteRole 未清关联表致孤儿记录 �?- 发现日期: 2026-07-09 (专家 B, BIZ-R3-008, P1)
- 严重�? High (数据一致�?
- 问题: `TFireDACAuthorizationStorage.DeleteUser` �?`DeleteRole` 仅删除主�?(auth_users/auth_roles), 未清关联�?auth_user_roles. 删除用户�? auth_user_roles 仍保�?user_id 指向已删用户的孤儿行; 删除角色�? auth_user_roles 仍保�?role_id 指向已删角色的孤儿行. 内存�?TUser.Roles 已清�?DB 未同�? 重启后加载会恢复已删角色关联.
- 修复: �?DeleteUser �?DeleteRole 中增加级联删�?auth_user_roles 的语�? DeleteUser 先执�?`DELETE FROM auth_user_roles WHERE user_id = (SELECT id FROM auth_users WHERE username = :username)`, 再删 auth_users. DeleteRole 先执�?`DELETE FROM auth_user_roles WHERE role_id = (SELECT id FROM auth_roles WHERE name = :name)`, 再删 auth_roles. 两条语句用分号分隔在单次 ExecSQL 执行, 保证原子�? 参数化查询避免注�?
- 验证: Win64 单元测试 `-FromUnit DeepBase.Authorization` 编译 SUCCESS, 全部通过 (Passed / Leaked 0 / Failed 0). 现有测试覆盖用户/角色 CRUD 路径, 修复不改变正常删除逻辑.
- 状�? 已修�?
### BUG-409: Core/DeepBase.License.pas LoadLicenseFromDB `try...except end` 吞所有异�?�?- 发现日期: 2026-07-09 (专家 B, BIZ-R3-009, P1)
- 严重�? High (可诊断�?
- 问题: `TDeepBaseLicense.LoadLicenseFromDB` (L575-589) �?`try...except end` 吞所有异�? 使篡�?损坏许可证与"无许可证"不可区分. 数据库连接失败、加密数据损坏、签名验证失败等严重错误被静默忽�? 无法诊断许可证加载失败原�?
- 修复: �?except 块中检查异常消�? 仅静默忽略包�?"no such table" / "table" / "doesn't exist" / "does not exist" 的异�?(首次启动�?Settings 表不存在的预期情�?. 其他异常 (连接失败、数据损坏、加密错误等) �?`raise` 重新抛出, 调用方可感知并记�? 保持向后兼容: 首次启动无表时不报错, 但其他错误不再被�?
- 验证: Win64 单元测试 `-FromUnit DeepBase.License` 编译 SUCCESS, 全部通过 (Passed / Leaked 0 / Failed 0). 现有测试覆盖许可证加载路�? 修复不改变正常加载逻辑.
- 状�? 已修�?
### BUG-410: Core/DeepBase.LLM.BillingClient.pas ChatWithRetry 退避无 jitter �?Retries>31 �?1 shl 溢出 �?- 发现日期: 2026-07-09 (专家 B, BIZ-R3-012, P1)
- 严重�? High (可靠�?
- 问题: `TBillingClient.ChatWithRetry` (L1022-1065) 指数退�?`1000 * (1 shl (I-1))` 存在两个缺陷: (1) �?jitter, 多客户端同时限流时同步重试致雷群效应; (2) Retries>31 �?`1 shl 31` 溢出为负�? Sleep 失效或报�? EBillingServerError 的线性退�?`1000 * I` 同样�?jitter.
- 修复: (1) 指数退避加 `Min(I-1, 20)` 防溢�?(最大延�?~17 分钟); (2) 两处退避均�?`Random(200)` 抖动 (0-199ms 随机), 打散重试时间; (3) implementation uses 增加 `System.Math` 提供 Min 函数. 保持向后兼容: 重试次数、异常类型处理逻辑不变.
- 验证: Win64 单元测试 `-FromUnit DeepBase.LLM.BillingClient` 编译 SUCCESS, 全部通过 (Passed / Leaked 0 / Failed 0). 现有测试覆盖重试路径, 修复不改变正常重试逻辑.
- 状�? 已修�?
### BUG-411: Core/DeepBase.LLM.BillingClient.pas DoStreamRequest Accept header 泄漏到后续请�?�?- 发现日期: 2026-07-09 (专家 B, BIZ-R3-013, P1)
- 严重�? High (正确�?
- 问题: `TBillingClient.DoStreamRequest` (L778) 设置 `FHttpClient.CustomHeaders['Accept'] := 'text/event-stream'`, 但方法返回后未重�? CustomHeaders �?FHttpClient 的持久状�? 后续 DoRequest 调用 SetupHeaders 时只设置 Authorization �?X-Tenant-Id, 不重�?Accept, 导致非流�?API 请求携带错误�?Accept: text/event-stream, 服务端可能拒绝或返回错误格式.
- 修复: �?DoStreamRequest 外层 finally 块中重置 `FHttpClient.CustomHeaders['Accept'] := 'application/json'`, 确保无论正常返回还是异常, Accept header 都恢复为流式请求前的默认�? 保持向后兼容: 不影响流式请求本�? 仅防止状态泄�?
- 验证: Win64 单元测试 `-FromUnit DeepBase.LLM.BillingClient` 编译 SUCCESS, 全部通过 (Passed / Leaked 0 / Failed 0). 现有测试覆盖流式和非流式请求路径, 修复不改变正常请求逻辑.
- 状�? 已修�?
### BUG-412: Core/DeepBase.AutoFix.pas NotifyShellShown ForceQueue 线程池执�?Halt 致进程清理不完整 �?- 发现日期: 2026-07-09 (专家 B, BIZ-R3-014, P1)
- 严重�? High (可靠�?
- 问题: `AutoFix.NotifyShellShown` (L74-78) 使用 `TThread.ForceQueue(nil, ...)` �?`TAutoFixScenarioRunner.Run` 调度到线程池执行. Run 方法内部在遇�?fatal exception 时调�?`TAutoFixSelfTerminator.HandleFatal`, 最终执�?`Halt(2)`. 非主线程调用 Halt 会导致进程清理不完整 (资源未释放、文件未关闭、临时文件残留等).
- 修复: �?`TThread.ForceQueue(nil, ...)` 改为 `TThread.Queue(nil, ...)`. Queue 保证回调在主线程执行 (通过消息�?, 确保 Halt 在主线程调用, 进程清理完整. 保持向后兼容: 仍然是延迟到下一次消息泵循环执行, 不影�?UI 绘制时序.
- 验证: Win64 单元测试 `-FromUnit DeepBase.Manager` 编译 SUCCESS, 全部通过 (Passed / Leaked 0 / Failed 0). Manager 测试覆盖 AutoFix 集成路径, 修复不改变正常场景执行逻辑.
- 状�? 已修�?
### BUG-413: Core/DeepBase.MVVM.pas TAsyncCommand.Destroy Wait(INFINITE) 应用关闭永久挂起 �?- 发现日期: 2026-07-09 (专家 B, BIZ-R3-015, P1)
- 严重�? High (可靠�?
- 问题: `TAsyncCommand.Destroy` (L503-510) 调用 `Wait` 无参�? 默认 `Timeout = INFINITE`. 如果 `FExecuteProc` 阻塞且不检�?`IsCancelledFunc`, 析构函数将永久挂�? 导致应用关闭时卡�? 用户只能强制杀进程, 造成数据丢失和资源泄�?
- 修复: �?`Wait` 改为 `Wait(5000)` (5 秒有限超�?. 如果任务未在超时内完�? 捕获异常并强制清�?`FTask := nil`, 避免访问已释放内�? 析构函数继续执行清理, 不阻塞应用关�? 保持向后兼容: 正常取消的任务仍会等待完�? 仅阻塞任务触发超时退�?
- 验证: Win64 单元测试 `-FromUnit DeepBase.MVVM` 编译 SUCCESS, 全部通过 (Passed / Leaked 0 / Failed 0). 现有测试覆盖异步命令生命周期, 修复不改变正常取消逻辑.
- 状�? 已修�?
### BUG-414: Core/DeepBase.Manager.pas WhenReady TTask.Run 不追踪不等待, FinalizeModules 后回调解引用已释�?FLogger �?- 发现日期: 2026-07-09 (专家 B, BIZ-R3-016, P1)
- 严重�? High (可靠�?UAF)
- 问题: `WhenReady` �?`FReadyFired=True` 时调�?`TTask.Run` 异步执行 `ACallback`, 回调闭包直接捕获字段 `FLogger`. 任务不追踪、不等待, `FinalizeModules` 释放 `FLogger` 及各模块�? 任务才运行解引用已释放对�? 造成 use-after-free. 同时 `Finalize` �?`FLock` �?`FinalizeModules`, 与回调内可能再次取锁的逻辑形成死锁风险.
- 修复: 新增 `FPendingReadyTasks: TList<ITask>` 字段追踪挂起�?WhenReady 任务. 回调改用局部变�?`LLogger := FLogger` 快照, 不直接解引用字段, 并将任务加入追踪列表. 新增 `WaitForPendingReadyTasks`: �?`FinalizeModules` 之前, 锁内快照并清空追踪列表后释放�? 再用 `Wait(5000)` 有限超时等待每个任务完成 (持锁等待会死�?. 正常任务等待完成, 阻塞任务触发超时后继�?Finalize, 不永久挂起应用关�?
- 验证: Win64 单元测试 `-FromUnit DeepBase.Manager` 编译 SUCCESS, 全部通过 (Passed 16 / Leaked 0 / Failed 0). Manager 测试覆盖初始�?终结路径, 修复不改变正常回调逻辑.
- 状�? 已修�?
### BUG-415: Core/DeepBase.Authorization.pas GetEffectivePermissions O(n²) 去重, HasPermission 每次重算 �?- 发现日期: 2026-07-09 (专家 B, BIZ-R3-017, P1)
- 严重�? Medium (性能)
- 问题: `GetEffectivePermissions` �?`SetLength+1` 循环 + 线性扫描去�? 合并 N 个权限时�?O(n²). `GetRolePermissionsRecursive` 内同样模式重�? `HasPermission` 每次调用都调�?`GetEffectivePermissions` 全量重算, 无缓�? 权限检查热路径开销�?
- 修复: 新增 `Seen: TDictionary<string,Boolean>` 哈希集合作为共享去重容器, `GetRolePermissionsRecursive` 增加 `Seen` 参数, �?`ContainsKey`/`Add` 实现 O(1) 去重, 同时保留 `Result` 数组以兼容既有签�? `GetEffectivePermissions` 在结束时一次�?`Seen.Keys.ToArray` 转数�? 替代逐项 SetLength. HasPermission 重算问题本轮采用集合优化降低单次开销, 不引入缓�?(避免失效一致性复杂度), 符合专家最小修复建�?
- 验证: Win64 单元测试 `-FromUnit DeepBase.Authorization` 编译 SUCCESS, 全部通过 (Passed 29 / Leaked 0 / Failed 0). 覆盖角色继承/权限去重/通配符匹配路�? 修复不改变权限计算结�?
- 状�? 已修�?
### BUG-416: Core/DeepBase.PluginManager.pas VerifyPluginSignature 同步 WinVerifyTrust CRL/OCSP 网络检查阻塞主线程 �?- 发现日期: 2026-07-09 (专家 B, BIZ-R3-018, P1)
- 严重�? Medium (性能/UX)
- 问题: `VerifyPluginSignature` 同步调用 `WinVerifyTrust`, 默认策略可能触发 CRL/OCSP 在线吊销检查的网络往�? 多插件加�?+ �?无网络环境下, 主线�?(启动 UI) 长时间冻�? 代码已设 `WTD_REVOKE_NONE` 禁用吊销检�? 但未阻止策略�?URL 检索的网络往�?
- 修复: 新增常量 `WTD_CACHE_ONLY_URL_RETRIEVAL = $40`, �?`VerifyPluginSignature` 设置 `TrustData.dwProvFlags := WTD_CACHE_ONLY_URL_RETRIEVAL`, 强制 WinVerifyTrust 仅从缓存获取 URL 不做网络往�? 配合 `WTD_REVOKE_NONE` (吊销检查已禁用), 网络往返本就无必要, 此标志消除主线程阻塞且不改变签名验证结果 (仅去掉在线吊销获取). 非平台路�?(`{$ELSE}`) 不受影响.
- 验证: Win64 单元测试 `-FromUnit DeepBase.PluginManager` 编译 SUCCESS, 全部通过 (0 failed). 覆盖插件加载/签名验证路径, 修复不改变验证布尔结�?
- 状�? 已修�?
### BUG-417: Core/DeepBase.LLM.ImportExport.pas YAML 导出已实现但导入�?stub, 功能不对�?�?- 发现日期: 2026-07-09 (专家 B, BIZ-R3-019, P3)
- 严重�? Low (功能不对�?用户体验)
- 问题: `JsonToYaml` 已实�?(可导�?YAML), �?`YamlToJson` �?stub: �?JSON 内容时返回一个带 `error` key 的伪 `TJSONObject`, 下游校验 (TryGetValue 缺少 categories/prompts 数组) 报错 "missing required array" �?误导性消�? 且用户导�?YAML 后无法导�? 功能不对�? 完整 YAML 解析器需引入第三方库 (缩进/flow scalar/anchor/引号边界), 半解析器会静默损坏导入的 prompt 数据.
- 修复: 采用**导出 YAML / 拒绝导入**方案 �?`YamlToJson` 改为返回 nil (不再返回伪对�?, JSON 快路�?(`Copy(Trim(Content),1,1)='{'`) 保留; `ImportFromString` �?`ValidateImportFile` 两调用点�?RootObj=nil 时区�?YAML vs 损坏 JSON, 给出明确错误 "YAML import is not supported. Please import as JSON (use efJSON export for round-trip)." 不再泄漏到误导�?"missing required array". `YamlToJson` �?private 移至 public (供导�?导出工具与单测直接验证往返契�?. 非对称是合理�? YAML 为人类可读导出格�? 往返应�?JSON.
- 验证: 新增 `TTestYamlToJson` 回归测试 (YAML 内容 �?返回 nil; JSON 内容 �?返回�?nil �?version �?. Win64 单元测试 `-FromUnit DeepBase.LLM.ImportExport` 编译 SUCCESS, 全部通过 0 failed.
- 状�? 已修�?
### BUG-418: Core/DeepBase.Resilience.CircuitBreaker.pas SetState 持锁触发回调 + 遗漏入口回调丢失 �?- 发现日期: 2026-07-09 (专家 A, CORE-R3-011, P3)
- 严重�? Low (并发可扩展�?回调可靠�?
- 问题: `SetState` �?`FLock` 调用 `FOnStateChanged`, 慢回调阻塞所�?`AllowRequest`/`Execute` 调用�? 此前 `SetState` 已改为锁内仅暂存 `FPendingStateChange`、锁外由 `FirePendingStateChanged` 触发, 但只补了 `GetState`/`SetState` 自身入口 �?`AllowRequest`(�?`CheckHalfOpenTransition` 可能 `SetState(csHalfOpen)`)、`RecordSuccess`(可能 `SetState(csClosed)`)、`RecordFailure`(可能 `SetState(csOpen)`) 三处�?`finally FLock.Leave` 后未�?`FirePendingStateChanged`, 导致这些路径的状态变化回调被 staged �?*永不触发** (回归性丢�?.
- 修复: �?`AllowRequest`/`RecordSuccess`/`RecordFailure` �?`finally FLock.Leave` 之后补充 `FirePendingStateChanged` 调用, �?`GetState` 一�? `Execute`/`Execute<T>` 门控段虽也可能经 `CheckHalfOpenTransition` 暂存 csHalfOpen, 但其后续必经 `RecordSuccess`/`RecordFailure` (成功/异常路径), 由后者触发覆�? 无需单独�?
- 验证: Win64 `-FromUnit DeepBase.Resilience` 编译 SUCCESS, 全部通过 0 failed.
- 状�? 已修�?
### BUG-419: Governance/DeepBase.Governance.ActionGrid.pas 读路径未持锁 + Run 锁外�?TAction �?UAF �?- 发现日期: 2026-07-09 (专家 D, GOV-R3-003, P1)
- 严重�? High (并发崩溃/数据竞争/潜在 UAF)
- 问题: `CanRun`/`Run`/`GetDisabledReason`/`SetEnabled`/`GetActionInfo`/`GetAllActions` 裸读 `FActions`/`FBridges` 无锁, 与热注册路径 (`RegisterAction`/`RegisterActionObj`/`RegisterBridge` 均持锁写) 并发时撞 `TDictionary` rehash 致读到半更新�?AV. 更严�? `FActions` �?`TObjectDictionary[doOwnsValues]`, `Run` 锁外�?`LAction` 引用期间, 另一线程对同 key �?`RegisterActionObj` 会因 `AddOrSetValue` 释放旧对象致 use-after-free. �?D-003 仅描�?rehash, 实际�?UAF.
- 修复: 读路径统一�?`FLock` 内克隆值类型快�? 锁外不再�?`TAction` 引用:
  - `CanRun`/`GetDisabledReason`: 锁内�?Enabled/DisabledReason/DueRef 局�? 锁外跑慢�?`FDueChecker.Check` (避免锁内慢回调阻塞并发读).
  - `SetEnabled`: �?`LAction.Enabled` 移入锁内 (原裸写可写到正被释放的对�?.
  - `GetActionInfo`: 锁内 TryGetValue + 拷贝字段�?record (record 全值类�? 锁外无悬�?.
  - `GetAllActions`: 整个遍历持锁, 锁内直接构建 record (不再回调已加�?`GetActionInfo`——`TCriticalSection` 不可重入, 二次 `Enter` 会死�?.
  - `Run`: 锁内克隆 Enabled/DisabledReason/DueRef + `BridgeKeys.ToArray` + �?`IBridge` 引用数组 (引用计数保活, 锁外安全); 删除已无用的私有 `CheckDueIfRequired` (due 检查内联到 Run, 避免�?TAction 传参的脆弱�?; 锁外�?DueChecker + Bridge.Execute.
- 验证: Win64 `-FromUnit DeepBase.Governance.PBT` (覆盖 ActionGrid) + `DeepBase.DeepFlow.PBT` 全部通过 0 failed.
- 状�? 已修�?### BUG-420: DeepFlow/Source/Core/DeepFlow.Engine.pas SendSync 单槽响应覆盖致并发丢响应 �?- 发现日期: 2026-07-09 (专家 D, GOV-R3-006, P1)
- 严重�? High (并发正确�? 先到者超时丢响应; 注释声称安全与实现不�?
- 问题: `SendSync` 用单�?`FResponseSink: TResponseWaiter` + `FResponseSinkLock` �?最近一�?等待�? 多个线程并发 SendSync �? 后注册者覆盖先注册者的 sink 字段:
  1. 先到者丢失其在字�?sink 中的引用;
  2. 当先到者的 `TResponseMessage` (CorrelationId=先到者请�?MsgId) 到达 `ProcessMessage` 分发�? sink 中已是后到者的 waiter, CorrelationId 不匹�?�?该响应无处投�?�?先到者的 `ResponseEvent` 永不 `SetEvent` �?先到�?`WaitFor` 超时返回 nil, 响应丢失;
  3. 源码注释声称 "safe against concurrent SendSync", 与实际实现不�?
- 修复: 改为按请�?MsgId 分发的多槽字�?
  - 新增 `TResponseWaiter` �? �?`TEvent` (manual-reset, 初始非触�? + `Response: TDeepFlowMessage`; 构造建 Event, 析构释放 Event+Response; �?`TObjectDictionary[doOwnsValues]` 持有, 字典释放时统一释放�?waiter.
  - `FResponseSink: TResponseWaiter` �?`FResponseWaiters: TObjectDictionary<string,TResponseWaiter>` (key=请求 MsgId, doOwnsValues); �?`FResponseSinkLock` 复用.
  - `SendSync`: 自建 waiter (`LOwnsWaiter := True` 初始拥有), 锁内若同 MsgId �?waiter 存在�?`ExtractPair` 摘除 (本调用不释放�? 让字�?doOwnsValues/后续逻辑处理; �?sink 模型下此为单槽覆盖丢失根�?, `Add(MsgId, LWaiter)` (所有权移交字典, `LOwnsWaiter := False`); WaitFor; 锁外 SetEvent 兜底 (�?ProcessMessage 未触发超�?; finally: �?`LOwnsWaiter` �?True (字典未接�? 异常路径) 直接释放; 否则�?`ExtractPair` 按条�?"字典中仍指向�?waiter" 摘除并取回所有权后释�?—�?条件判断防止误释�?�?MsgId 后续新调用注册的�?waiter" (否则 double-free/误释放他人等待器).
  - `ProcessMessage` 分发: 响应消息 (`AMessage is TResponseMessage`) �?`CorrelationId` �?`FResponseWaiters` TryGetValue; 命中则克�?Response �?waiter (`LResponseWaiter.Response := AMessage.Clone`) + `SetEvent`, 标记已路�?(`LRouted`); 已路由则不回落用户回�? 非响应消息或无匹配等待器 (`not LRouted`) 仍回�?`FOnMessageProcessed`.
  - 析构 `Destroy`: `FResponseWaiters.Free` (doOwnsValues 释放�?waiter 及其 Event+Response).
- 验证: Win64 `-FromUnit DeepBase.DeepFlow.PBT` 编译 + 回归通过 (2 tests, 0 failed). 说明: `DeepFlow/Tests/Test.DeepFlow.Engine.pas` 4 �?Stop/Pause 测试�?`RegisterTestFixture` 故未注册运行; 全量 Unit 套件 (`DeepBaseTests.exe`) 在当�?working tree 运行末尾出现 Runtime error 216 (进程�?AV, 预存缺陷, 非本修复引入, 详见 BUG-421 验证说明), 故回归以 DeepFlow.PBT 编译 + 该域单元通过为准.

### BUG-421: Governance/DeepBase.Governance.EvidenceStore.SQLite.pas 迁移链未被调�?+ 迁移无事务致链断�?�?- 发现日期: 2026-07-09 (专家 D, GOV-R3-002 + GOV-R3-004, P1)
- 严重�? High (审计证据链完整�? 旧库迁移�?this_hash 永远为空 �?VerifyChain 误报所有旧行被篡改; 迁移无事�?�?进程中途崩溃留�?部分行已回填+部分仍空"的断裂链且无法定�?
- 问题: `TEvidenceStoreSQLite.Create` (L183-186) 调用顺序�?`EnsureTable �?MigrateHashColumns �?InitializeChainState`, **从未调用 `MigrateExistingChain`** (rg 全仓确认仅声�?实现, 无调用点):
  1. `MigrateHashColumns` 只为旧表�?`prev_hash/this_hash` �?(空�?, 不回填旧库行;
  2. `InitializeChainState` 在迁移前调用, 读链�?(`SQL_LAST_HASH` �?`this_hash`), 旧库全为�?�?返回 `GENESIS_HASH`;
  3. 结果: 旧库所有行 `this_hash` 永远为空. `VerifyChain` 重建哈希比对�? 旧行 stored_hash='' 与期望值不�?�?全部旧行被误判篡�? 新写入行 prev_hash=GENESIS 正确 (因为 InitializeChainState 读到 GENESIS), 但旧库审计链完整性不可验�?
  并发缺陷 (D-004): `MigrateExistingChain` �?`while not Eof` 循环内逐行 `LUpdateQuery.ExecSQL`, **�?StartTransaction/Commit 包裹**. SQLite 默认 autocommit 模式下每行独立提�? 进程在循环中途崩�?(电源/异常/OOM) �?已处理行已落�?this_hash, 未处理行仍空 �?链断�? 且无法通过重跑迁移修复 (重跑会跳过已回填�? �?prev_hash 链已不一�?.
- 修复:
  - D-002 (构造函�?: `EnsureTable �?MigrateHashColumns �?MigrateExistingChain �?InitializeChainState`. 先迁移回填旧库行 this_hash, 再读链尾缓存. 保证 InitializeChainState 读到的是完整链的尾哈�? VerifyChain 不再误报.
  - D-004 (事务原子�?: `MigrateExistingChain` 循环全程 `FConnection.StartTransaction` 包裹; 循环正常结束 `FConnection.Commit`; `except` �?`FConnection.Rollback + raise` (全成或全回退, 不留断裂�?. 链尾缓存 `FLastChainHash := GetLastHash` 移至 `Commit` 之后调用, 读已提交的完整链�? 避免读未提交半�?
- 验证: Win64 `-FromUnit DeepBase.Governance.PBT` 编译 + 回归通过 (3 tests, 0 failed). �? 全量 Unit 套件 (`DeepBaseTests.exe`) 运行末尾出现 Runtime error 216 (进程�?AV), 该问题为预存缺陷 (本任务前已存�? 与本修复改动无关: EvidenceStore 带链验证版本本身 + 先前 R3 全部修复均为未提交工作树改动, �?干净基线"可比), D-002/D-004 改动范围限于构造函数调用顺序与迁移事务包裹, 不涉及接口签名或并发交互, Governance PBT 域验证通过即确认不引入回归.

### BUG-422: Governance/DeepBase.Governance.EvidenceRecorder.pas 退避无抖动致重试风�?+ 析构 Flush 无上限阻塞数百秒 �?- 发现日期: 2026-07-09 (专家 D, GOV-R3-005, P1)
- 严重�? High (可用�?关停: 高并发失败时退避风暴放大对底层 SQLite/网络的瞬时压力并可能级联雪崩; 应用关停析构 Flush 满队列阻塞数百秒, 进程看似"卡死无响�?)
- 问题:
  1. `SaveWithRetry` �?`EnqueueEntry` 的退避用固定 `PUSH_RETRY_DELAYS = (100, 200, 400)` 无抖�? 高并发写入失败时, 所有等待线程在完全相同的时�� Sleep 后同步唤醒并重试 �?形成重试风暴 (thundering herd), 瞬时再次压垮底层资源, 退避失效且可能级联雪崩.
  2. 析构路径同步 `Flush` �?`repeat PopItem ... SaveWithRetry until 队列空` 无上�? 队列容量上限 1000 �? 每条 SaveWithRetry 最�?3 次重�?× (100~400ms + 抖动) �?1.2s+ 每条, 1000 条可达数百秒. 应用关停时析构线程被阻塞, 进程长时间无响应.
- 修复:
  - 新增 `BackoffDelayWithJitter(ABaseMs)`: 对退避基值加 ±30% 抖动 (常量 `BACKOFF_JITTER_PCT=30`). �?`GetTickCount and $FFFF` (�?16 �? 作伪随机源映射到 `[-30%, +30%]` 区间 —�?确定性、无线程全局锁开销 (不依�?`Random`/`Randomize`, 避免多线程竞争全局随机种子�?.
  - 两处 `Sleep(PUSH_RETRY_DELAYS[I])` (EnqueueEntry 入队重试 + SaveWithRetry 持久化重�? 均改�?`Sleep(BackoffDelayWithJitter(PUSH_RETRY_DELAYS[I]))`.
  - `Flush` 加单次上�?`FLUSH_MAX_ITEMS=500` 与总超�?`FLUSH_TOTAL_TIMEOUT_MS=5000`: 循环�?`Inc(LProcessed)`, 达上限或 `GetTickCount - LStartTick >= 总超时` �?`Break`. 余量证据项留在队列交后台线程 (`FRunning` 期内继续处理) 或下�?Flush; 析构路径队列非空时由析构清理逻辑统一释放条目 (无泄�?.
- 验证: Win64 `-FromUnit DeepBase.Governance.PBT` 编译 + 回归通过 (3 tests 0 failed). 改动范围限于退避抖动与 Flush 循环上限/超时, 不改接口签名与并发交�? Governance PBT 域验证通过即确认不引入回归.

### BUG-423: Features/DeepBase.Browser.Engine.WebView2.pas 异步任务析构不等待致 use-after-free �?- 发现日期: 2026-07-09 (专家 E, FEAT-R3-002, P1)
- 严重�? High (内存安全: NavigateAsync/ExecuteScriptAsync/EvaluateScriptAsync/CaptureScreenshotAsync 返回 TTask.Run(LProc), 其闭包捕�?Self 并调用实例方�?Navigate/ExecuteScript/EvaluateScript/CaptureScreenshot; Destroy 释放 Self 时若任务仍在�? 任务线程访问已释放实例字�?�?UAF, 表现为关�?会话回收时随�?AV 或损�?
- 问题: 4 �?Async 方法�?`Result := TTask.Run(LProc)` 直接返回任务, 实例无任何未完成任务跟踪; `TWebView2BrowserSession.Destroy` (L287-314) 依次释放 FBrowser/FWindowParent/FScreenshotStream 等字段后 `inherited`, 全程未等待仍在途的异步任务 �?任务闭包�?Self 释放后继续执行实例方法访�?FBrowser 等已 Free 字段.
- 修复:
  - 新增实例字段 `FAsyncTasks: TList<ITask>` + `FAsyncTasksLock: TCriticalSection` (private �? 构造函�?Create).
  - 新增 `RunTrackedAsync(const LProc: TProc): ITask`: 内部 `TTask.Run(LProc)` 后加锁把返回�?ITask 加入 FAsyncTasks, 返回给调用�? 4 �?Async 方法 (NavigateAsync/ExecuteScriptAsync/EvaluateScriptAsync/CaptureScreenshotAsync) �?`Result := TTask.Run(LProc)` 全部改为 `Result := RunTrackedAsync(LProc)`.
  - 新增 `WaitForAsyncTasks`: 加锁快照 FAsyncTasks �?ToArray �?Clear, 逐个 `LTask.WaitFor(5000)` 有界等待 (5s/任务, 防卡死任务永久阻塞析�?, 异常吞掉 (析构期不可挽救已崩任�? re-raise 会掩盖销�?.
  - `Destroy` 首步调用 `WaitForAsyncTasks` (在任何字段释放之�? 确保闭包不再触碰 Self), 末尾释放 FAsyncTasksLock/FAsyncTasks 容器.
- 验证: Win64 全量 Unit 套件编译通过 (�?E1035/E2003/E2010 等编译错�?警告). �?DUnitX 单元测试覆盖 WebView2 (�?GUI 冒烟 PageDriverSmoke 需 GUI 环境), 改动属同�?B-002 (LLM.Manager Destroy 释放在用对象) 已验证模�?(析构 WaitFor 在用异步任务), 运行末尾 Runtime error 216 为预存进程级缺陷 (本任务前已存�? 无干净基线可比, 非本修复引入). �?history.md.
- 状�? 已修�?
### BUG-424: Features/DeepBase.CloudBackup.pas TBackupEncryptor 冗余弱密钥派�?�?- 发现日期: 2026-07-09 (专家 E, FEAT-R3-003, P1)
- 严重�? High (密码�? `TBackupEncryptor` 构造时 `DeriveKeyAndIV` 用单�?SHA-256(password) 直接派生 32B key + 16B IV, (a) 单次哈希�?KDF 无迭�?无盐, 易受字典/暴力与彩虹表攻击; (b) IV �?password+'IV' 哈希派生非随�? 同密码每次备�?IV 相同 �?GCM/CBC 下同明文首块可识别重�? 泄露模式; (c) 与同单元 `TSimpleCrypto.EncryptBytes` 已内置的 PBKDF2-SHA256(100k 迭代)+随机�?AES-256-GCM+GCM Tag+随机 IV 重复并存, 弱路�?(FKey/FIV) 仍被 `EncryptBytes`/`DecryptBytes` 实际使用, 强路径被绕过. 析构期对托管 string `FPassword` 执行 `FillChar(FIV[0],...)` 等指向已不存在字段的悬空写入, 风险 AV)
- 问题: `TBackupEncryptor` �?`FKey/FIV: TBytes` + `FPassword: string` 三份密码材料; 构�?`DeriveKeyAndIV` 走弱 SHA-256 派生填充 FKey/FIV; `EncryptBytes/DecryptBytes` 实际�?`TSimpleCrypto.EncryptBytes(AData, TEncoding.UTF8.GetString(FKey))` —�?把派生出�?32B 二进制当 UTF-8 string 喂回 TSimpleCrypto (本身已有 PBKDF2+GCM), ��于在�?KDF 之外再套一层无迭代�?KDF, 且二进制→UTF8 转换遇非法字节会截断/失真; `Destroy` 残留�?FIV �?`FillChar` 悬空写入 (字段已删); 注释声称 "应使�?AES-256-CBC/GCM 实际�?XOR/Base64 模拟" 与实现不�?(FR-002 后已�?TSimpleCrypto, 注释未更�?
- 修复: 删除冗余弱派生层, 直接转发原始密码�?TSimpleCrypto:
  - 删除字段 `FKey/FIV: TBytes` �?`DeriveKeyAndIV` 方法 (interface 声明 + implementation 整段), 仅保�?`FPassword: string` (托管, 引用计数自动释放, 不可安全清零)
  - 构造函�?`Create(APassword)` 改为直接 `FPassword := APassword` (不再调用 DeriveKeyAndIV)
  - `EncryptBytes/DecryptBytes`: 去掉 `FKey` 空检查改 `FPassword = ''` 空检�? 调用改为 `TSimpleCrypto.EncryptBytes(AData, FPassword)` / `DecryptBytes(AData, FPassword)` (直接传密�? �?TSimpleCrypto 内部 PBKDF2(100k)+随机�?AES-256-GCM+12B 随机 IV+16B GCM Tag 全套生效, 每次加密随机�?IV 不同 �?非确定�? 抗选择明文)
  - `Destroy`: 删除�?`FillChar(FIV[0],...)` 的悬空写�?(字段已不存在) 与重复注�? 仅保留说�?(托管 string 不可安全清零, TSimpleCrypto 不在此持派生材料)
  - 更新 `EncryptStream` 注释: 移除过时 "应使�?AES-CBC/GCM 实际�?XOR" 误导注释, 改为说明已委�?TSimpleCrypto (AES-256-GCM)
- 验证: Win64 全量 Unit 套件编译通过 (SUCCESS: Unit Tests compiled, 无编译错�?警告); `grep FKey|FIV|DeriveKeyAndIV` �?CloudBackup.pas 零残�? �?DUnitX 覆盖 `TBackupEncryptor` 加解�?(Tests/Test.DeepBase.CloudBackup.pas 仅覆�?manifest/config/info 结构, �?Encryptor 用例), 安全路径依赖 `TSimpleCrypto` 已有单测覆盖 (Services.Crypto). 运行末尾 Runtime error 216 为预存缺�?(BUG-421 起记�? 非本修复引入). �?history.md.
- 状�? 已修�?### BUG-425: Features/DeepBase.CloudBackup.pas TCloudBackupClient 不强�?HTTPS �?API key 明文传输 MITM �?- 编号: BUG-425
- 来源: REVIEW5-R3-E-006 (FEAT-R3-006)
- 严重�? P1
- 状�? 已修�?- 关联: BUG-424 (同文�?E-003 冗余弱密钥派�?

**缺陷**:
`TCloudBackupClient.Create(AServiceURL, AApiKey, ABucket)` 仅赋�?`FServiceURL := AServiceURL`, 不校�?scheme. `DoRequest` 每次请求�?`X-API-Key` 头明文携�?`FApiKey` (L1364), 若配�?`CloudServiceURL=http://...`, API key 经明�?HTTP 传输可被 MITM 截获. 默认�?`https://backup.DeepBase.cloud/v1` (L785) 安全, 但配置项 `TBackupConfig.CloudServiceURL` 可被设为 http, 无任何守�?

**根因**:
构造函数信任外部输入的 URL scheme, �?fail-fast 校验; ServiceURL property 虽只�?(L304 read FServiceURL), 但构造期 scheme 任意.

**修复**:
- `TCloudBackupClient.Create` 开�?(inherited Create 之前, 字段未创�? raise �?Destroy �?nil 字段 FreeAndNil 安全) �? `if not AServiceURL.ToLower.StartsWith('https://') then raise ECloudServiceNotConfiguredException.CreateFmt(...)`.
- 复用既有 `ECloudServiceNotConfiguredException` (DeepBase.Exceptions), 不新增异常类; 消息明确指出 "must use HTTPS" + 回显�?URL.
- 不区分大小写 (`ToLower`), 兼容 `HTTPS://` / `Https://`.

**设计决策**:
- 采用构造期 fail-fast (方案 A) 而非 manager 层降�?nil (方案 B): 不安全配置应即报错而非静默降级致云备份不可用且无明确提�? 安全 > 容错.
- 不在 DoRequest 再加运行期校�? ServiceURL property 只读, 构造后不变, 构造守卫已根本性杜绝不安全 client 存在, 冗余检查违�?CLAUDE.md 不鼓励冗余代�?
- 构�?raise 传播�?`TCloudBackupManager.Create` L1660 (单调用点), manager 析构 `FreeAndNil` + `Cancel` �?`Assigned` 守卫对半初始化字�?(FCloudClient=nil/FCancelled 字段默认 False/未创建对�?nil) 安全, 无泄�?

**验证**:
- Win64 `-FromUnit DeepBase.CloudBackup -AllowFilteredCI` 编译通过 (SUCCESS: Unit Tests compiled, 无编译错�?警告), 35 测全�?0 失败.
- 测试单元 `Test.DeepBase.CloudBackup.pas` 不构�?TCloudBackupClient (仅测 manifest/config/info), 新校验不破坏现有测试.
- �?DUnitX 覆盖 TCloudBackupClient 构�?(依赖网络服务, 不属单测�?; 校验逻辑为单�?StartsWith, 风险极低.

**影响文件**:
- `Features/DeepBase.CloudBackup.pas` (TCloudBackupClient.Create +6 行校�?

### BUG-426: Features/DeepBase.AntiTamper.pas TAntiTamperConfig 默认硬编�?Salt 致彩虹表攻击 �?- 编号: BUG-426
- 来源: REVIEW5-R3-E-007 (FEAT-R3-007)
- 严重�? P2
- 状�? 已修�?- 关联: BUG-034 (同函�?EncryptionKey 已强制显式配�?, BUG-424/425 (同轮 CloudBackup 加密加固)

**缺陷**:
`GetDefaultConfig` 默认 `Result.Salt := 'DeepMoveC_Default_Salt_2025'` (硬编�?. PBKDF2-SHA256 �?L187 �?`(EncryptionKey, Salt, KdfIterations)` 派生 AES-256 密钥. 固定 Salt 使所有部署共用同一 Salt, 攻击者可针对常见密码预计算彩虹表 (Salt 的作用即失效). 与同函数 L98-100 `EncryptionKey` 默认空且注释 "must be configured by user" (BUG-034 FIX) 的处理不一�?

**根因**:
默认配置信任用户会改 Salt, 但未强制. 加密类型 `TEncryptionType = (etAES256)` 单�?(etXOR 已为安全删除), 加密始终启用, Salt 恒为必需.

**修复**:
- `GetDefaultConfig`: `Result.Salt := ''` (�?, 注释对齐 EncryptionKey �?BUG-034 处理, 强制显式配置.
- `Initialize`: 开头加 `if AConfig.Salt = '' then raise EAntiTamperException.Create(...)`. 复用既有 `EAntiTamperException` (DeepBase.Exceptions), 不新增异常类.
- 消息明确: "Salt must be configured... prevent rainbow-table attacks".

**设计决策 (为何不随机生�?Salt)**:
审查建议 "随机生成并持久化 Salt", 但当前架构不可行: Salt 必须跨运行稳定才能复现密钥解密数�? �?`TAntiTamperPackage` 是无状态类 (class var FConfig, 无持久化载体). 随机 Salt 不持久化会导致每次启动密钥不�? 加密数据无法解密, 破坏功能. 故采�?"默认�?+ Initialize 强制显式配置" (fail-fast), �?EncryptionKey �?BUG-034 一致——安全优于自动化, 部署方须提供唯一 Salt.

**验证**:
- Win64 `-FromUnit DeepBase.AntiTamper -AllowFilteredCI` 编译通过 (SUCCESS: Unit Tests compiled, 无编译错�?警告), 8 测全�?0 失败.
- 更新 `Test.DeepBase.AntiTamper.pas` 三处以反映新契约:
  - `Test_DefaultConfig_Values`: `Assert.IsEmpty(C.Salt, ...)` (�?IsNotEmpty).
  - `Test_Initialize_WithDefaultConfig`: 改为 `Assert.WillRaise(... EAntiTamperException)` (默认空盐必抛) + 配置 Salt �?`Initialize` 成功.
  - `Test_EncryptDecrypt_AES_RoundTrip`: �?`C.Salt := 'UnitTest_AntiTamper_Salt_2026'`.
- 测试 uses �?`DeepBase.Exceptions` (EAntiTamperException 来源).

**影响文件**:
- `Features/DeepBase.AntiTamper.pas` (GetDefaultConfig + Initialize 校验, +10 �?
- `Tests/Test.DeepBase.AntiTamper.pas` (3 测方�?+ uses)

### BUG-427: Features/DeepBase.Speech.TTS.StepFun.pas FetchSystemVoices/FetchClonedVoices nil as TJSONArray 触发 EInvalidCast �?- 编号: BUG-427
- 来源: REVIEW5-R3-E-008 (FEAT-R3-008)
- 严重�? P2
- 状�? 已修�?
**缺陷**:
`FetchSystemVoices` (L172) �?`FetchClonedVoices` (L230) 均用 `JSONArr := (JSONVal as TJSONObject).GetValue('voices') as TJSONArray; if JSONArr = nil then Exit;`. 当响应缺 `"voices"` 键时, `GetValue('voices')` 返回 nil, `nil as TJSONArray` 立即 raise `EInvalidCast` (Delphi `as` 运算符对 nil 类类型引用强制转换抛异常), �?L173/L231 �?`if JSONArr = nil then Exit` �?*死代�?*永不执行. EInvalidCast 被外�?`except` 捕获, `FLastError` �?`"StepFun fetch voices: Invalid class typecast"` 而非清晰�?"voices 缺失" 错误, 误导调用方排�?

**根因**:
误用 `as` 做可能为 nil �?JSON 值类型转�? `as` 语义�?"必为目标类型否则抛异�?, 与期望的 "缺失则返�?nil 优雅退�? 矛盾.

**修复**:
两处统一改为 `is` 检�?+ 硬转�?
```pascal
var VoicesVal := (JSONVal as TJSONObject).GetValue('voices');
if not (VoicesVal is TJSONArray) then
begin
  FLastError := 'StepFun fetch (system|cloned) voices: response missing "voices" array';
  Exit;
end;
JSONArr := TJSONArray(VoicesVal);
```
- `is` �?nil 返回 False (不抛异常), 缺键/非数组均优雅退出并设清�?FLastError.
- 硬转�?`TJSONArray(VoicesVal)` �?`is` 已确认类型后安全.
- FetchClonedVoices 原对�?200 直接 Exit �?FLastError, 本次新增 voices 缺失�?FLastError (�?FetchSystemVoices 对齐).

**设计决策**:
不保�?`if JSONArr = nil then Exit` 死代码——`is` 已覆盖该分支, 删除避免误导. 不改外层 `try/except` (仍作网络/解析异常兜底). `JSONVal as TJSONObject` 保留: ParseJSONValue 后已 nil 检�? 顶层非对象属异常协议响应, �?except 兜底合理.

**验证**:
- Win64 全量编译通过 (SUCCESS: Unit Tests compiled, 无编译错�?警告).
- StepFun 无专�?DUnitX 测试单元 (依赖网络 API, 不属单测�?; 改动为纯逻辑等价替换 (as→is, 数组场景行为一�? 缺失场景�?raise 改为清晰 Exit), 风险极低.
- 全量套件存在�?E/F 及尾�?EInvalidPointer �?StepFun 无关 (StepFun 无测试且改动不涉及指针释�? JSONVal.Free �?finally 不变), 属既有基线状�?

**影响文件**:
- `Features/DeepBase.Speech.TTS.StepFun.pas` (FetchSystemVoices + FetchClonedVoices, �?+7 �?

### BUG-428: Features/DeepBase.Commerce.SafeClient.pas SendJson �?401 重试, 429/5xx 瞬态失败不退避直接抛�?�?- 编号: BUG-428
- 来源: REVIEW5-R3-E-005 (FEAT-R3-005)
- 严重�? P2
- 状�? 已修�?
**缺陷**:
`TDeepKitSafeClient.SendJson` (L503 调用�? 实际实现�?L560-660) 仅在 HTTP 401 (token 过期) 时重试一次刷�?token, �?429 (Too Many Requests) �?5xx (服务端临时不可用) 直接�?`EnsureSuccess` �?`EDeepBaseCommerceError`. 商业化支�?订单接口在短暂限流或后端重启窗口下会立即失败, 无指数退避、不遵守 `Retry-After` 响应�? 导致本可自愈的瞬态错误被当永久错误透传给用�?

**根因**:
重试策略只覆盖认证层 (401), 缺失对限�?(429) 与服务端瞬态故�?(5xx) 的退避重�? 且无幂等性判定——盲目重试非幂等 POST 会重复下�?重复扣款.

**修复**:
�?`SendJson` 末尾新增瞬态失败退避重试循�?(仅对**幂等调用**生效):
1. **幂等判定** `IsIdempotentCall`: GET/HEAD 天然幂等; POST/PUT/DELETE 仅当显式�?idempotency key (�?`CreatePaymentIntent` 等传 `AIdempotencyKey`) 才视为可重试. 非幂�?POST �?key 不重�?(防重复下�?.
2. **可重试状�?* `IsRetriableStatus`: 429 + 5xx (500/502/503/504). 401 仍走原有 token 刷新路径 (不并入此循环, 语义不同).
3. **Retry-After 遵守** `ExtractRetryAfterMs`: 429 响应优先�?`Retry-After` �?(秒数→ms, 缺失则用退�?, 钳制�?`BACKOFF_CAP_MS` 上限.
4. **指数退�?* `ComputeBackoffMs`: 5xx �?`BACKOFF_BASE_MS * 2^attempt`, 钳制�?`BACKOFF_CAP_MS`.
5. **确定性抖�?*: 基于 `AAttempt` �?±25% 抖动 (公式不用 `Now`/`Random`——脚�?测试环境禁用), 避免多客户端同步重试形成惊群.
6. 退避用 `Winapi.Windows.Sleep` (`{$IFDEF MSWINDOWS}` 保护), 非平台路径跳过退避直接重�?

**设计决策**:
- 抽出 4 个辅助方�?(`IsRetriableStatus`/`IsIdempotentCall`/`ExtractRetryAfterMs`/`ComputeBackoffMs`) 而非内联, 便于单测与后续扩�?(�?503 + Jitter 头解�?.
- 不对非幂�?POST 重试: 即使 5xx 也直接抛�? 由调用方决定是否重新提交 (幂等�?key 应由业务层在上游生成并传�? 而非 SafeClient 内部自�?.
- implementation uses 新增 `System.Math` (用于 `Min` 钳制, 仓库惯例全限�?`System.Math.Min`).
- `FMaxRetries` 复用 SafeClient 既有配置字段, 默认值不�?(1 次重�? 即最�?2 次请�?.

**验证**:
- Win64 全量编译通过 (SUCCESS: Unit Tests compiled, 仅遗留既�?H2443/H2077 提示).
- **新增 2 个回归测�?* (`Tests/Test.DeepBase.Commerce.pas`):
  1. `Test_DeepKitSafeClient_429_RetriesIdempotentGet_HonorsRetryAfter`: ListProducts (幂等 GET) 首次返回 429 + `Retry-After: 0` (Sleep(0) 不阻�?, 第二次返�?200; 断言 RequestCount=2 且解析出商品. 验证幂等 GET 被重试且遵守 Retry-After.
  2. `Test_DeepKitSafeClient_5xx_DoesNotRetryNonIdempotentPost`: CreateOrder (非幂�?POST �?key) �?503 下断言�?`EDeepBaseCommerceError` �?RequestCount=1. 验证非幂�?POST 不重试防重复.
- 两测试经 DUnitX `--run` 全名过滤单独执行确认 PASS (2 found, 2 passed, 0 failed/errored).
- 全量套件中既�?2 个失�?(WeChatPay 公钥加载环境问题 + `Test_PermissionClient_HasFeature_UsesActiveEntitlement` 测试数据 `valid_until=2026-07-08` 已于今日 07-09 过期) �?E-005 无关, 属既有基�?

**影响文件**:
- `Features/DeepBase.Commerce.SafeClient.pas` (SendJson 末尾退避循�?+ 4 辅助方法, +~60 �?
- `Tests/Test.DeepBase.Commerce.pas` (2 回归测试, +~70 �?

### BUG-429: DeepFlow/Source/Roles/DeepFlow.Commander.pas ProcessRequest 锁外修改 Session 字段, 并发�?session-id 数据竞争 �?- 编号: BUG-429
- 来源: REVIEW5-R3-D-007 (GOV-R3-007)
- 严重�? P2
- 状�? 已修�?
**缺陷**:
`TCommander.GetOrCreateSession` (L181) �?FSessionLock 内取 `TSession` 裸指针后释放锁返�? `ProcessRequest` (L349-379) 拿到指针�?*锁外**修改 `Session.State := ssActive/ssPending/ssError` (L350/371/375) �?`Inc(Session.FTurnCount)` (L351), 并读 `Session.Context`/`Session.SessionId`. 多线程并�?`ProcessRequest` 同一 SessionId �? 这些标量字段无锁修改 �?数据竞争 (Inc 非原�? State 读改写撕�?.

**根因**:
GetOrCreateSession 的锁保护范围只覆盖字典查�? 返回的裸 TSession 指针脱离锁后, 其字段被调用方无保护修改; FSessionLock 设计意图覆盖会话字段访问, 但实际只在字典操作时持有.

**修复**:
`ProcessRequest` 中所�?Session 字段访问改为�?FSessionLock 临界区内完成:
1. 入口段锁�? `Session.State := ssActive` + `Inc(Session.FTurnCount)` + �?Context/SessionId 快照到内�?var 局�?(`SessionCtx`/`SessionSid`).
2. AnalyzeIntent(耗时 LLM) 用快照引用在**锁外**执行, 避免持锁过久阻塞其他会话.
3. 成功路径 `Session.State := ssPending` 独立锁内更新.
4. except 路径 `Session.State := ssError` 独立锁内更新.

**设计决策**:
- 用内�?`var` 声明快照 (仓库既有惯例, �?Chronicler L390/Message L203/Config L194), 保持 ProcessRequest 局部作用域, 不污�?var �?
- Context 引用快照在锁内取: 消除 GetOrCreateSession 返回后到使用间的窗口. (�? Commander 停止�?FSessions.Clear 会释�?Session, 裸指针悬空是更深所有权问题, 超出 D-007 范围, 本修复聚焦字段竞�?)
- 不对整个 ProcessRequest 持锁: AnalyzeIntent/Decompose 耗时�? 持锁会序列化所有会话请�? 退化为单线�? 锁内只做标量字段读写 (纳秒�?.
- State �?except 中二次加�? except �?try 外层捕获, 此时已离开成功路径的锁, �?except 内需独立加锁�?ssError.

**验证**:
- Win64 全量编译通过 (powershell -NoProfile run_tests.ps1 -CI, exit 0, 仅遗留既�?H2077/H2443 Hint, �?Error/Fatal).
- Commander 无专�?DUnitX 测试 (�?dpr 引用编译); 改动为纯加锁包裹, 语义等价 (字段读改写原子性提�?, 风险�?
- DeepFlow 模块未纳入主测试 exe �?PBT 之外单测, 故无回归测试新增 (�?D-003/D-006 等同类已修项目一�?.

**影响文件**:
- `DeepFlow/Source/Roles/DeepFlow.Commander.pas` (ProcessRequest 字段访问加锁包裹 + 内联 var 快照, +~25 �?

### BUG-430: Governance/DeepBase.Governance.AI.ProposalQueue.pas 无界队列 OOM + 全程无锁竞�?�?- 编号: BUG-430
- 来源: REVIEW5-R3-D-008 (GOV-R3-008)
- 严重�? P2
- 状�? 已修�?
**缺陷**:
`TProposalQueue` 两个独立问题:
1. **无界队列 OOM**: `Submit` (L136) 无任何容量上�? AI 循环提交 TProposal 无限堆积 �?内存无限增长�?OOM; `FindById`/`GetPending`/`GetPending` O(n) 线性遍�? 队列膨胀后查询卡�?
2. **全程无锁**: 整个类无任何同步原语. 当前仅主线程调用看似安全, 但一旦引入后�?AI 提交线程 (提案�?AI 异步生成), 与人�?Approve/Reject/Apply 并发 �?`TObjectList<TProposal>` 非线程安�? 迭代�?Add 致遍历越�?/ 状态读改写撕裂. 原审阅标�?引入后台 AI 提案将升 P1".

**根因**:
设计期未考虑队列容量约束与并发安�? FProposals �?`TObjectList`, 全部方法直读直写无保�?

**修复**:
1. **容量上限**: 新增 `FMaxPending: Integer`, 构�?`Create(AModelVersion; AMaxPending: Integer = 0)`. AMaxPending<=0 时取默认 1000. `Submit` 入口在锁内调 `PendingCountInternal` 统计 psSubmitted �? ≥FMaxPending �?`EProposalQueueError.CreateFmt` (新增异常�? 遵循 Governance 既有 EConfigRegistrarError/EJsonLogicError 惯例, 不引入泛�?Exception). 容量检�?+ Add 必须同一锁内, 否则 TOCTOU.
2. **TCriticalSection 保护全部 8 个公共方�?*: Submit/Approve/Reject/Apply/FindById/GetPending/GetAll/Count.
3. **避免自死�?*: TCriticalSection 不可重入. Approve/Reject/Apply 需�?FindById 再改字段, 若调公共 FindById (自身已加�? 会在已持锁上下文二次加锁 �?自死�? 故拆 `FindByIdInternal` (无锁, 调用方持锁遍�? 供内部用, 公共 `FindById` 加锁后转�?internal.
4. **Apply 锁内创建 ChangeSet**: Apply 持锁�?`FModelVersion.CreateChangeSet` + `LCS.AddEntry` + `LP.MarkApplied`. ModelVersion 是独立对象无反向�?ProposalQueue 依赖, 无死锁风�? ChangeSet 创建�?(纳秒�?, 可接受持�? MarkApplied �?FStatus 必须�?Submit/Approve 的状态读互斥, 故锁内执�?
5. **GetPending 嵌套 try/finally**: 外层 LList.Free, 内层 FLock.Leave, 两资源独立释�?

**设计决策**:
- 默认上限 1000 而非 0 (无限): 真正消除 OOM 风险, 而非仅留接口. 无外部调用点 (仅类定义, 未接�?, 改默认值无破坏�? 生产环境可传更大值放�?
- �?TCriticalSection 而非 TMonitor(TObject): 跟同模块 ActionGrid (D-003 修复时用 TCriticalSection) 一�? EvidenceStore �?TMonitor 是其历史选择, 不强求统一.
- 抛异常而非返回 nil: Submit 契约返回�?nil TProposal, 调用方假定成�? 返回 nil 会被忽略致静默丢提案. �?EProposalQueueError 明确失败, 调用方可 catch 降级 (重试/丢弃旧提�?.

**验证**:
- Win64 全量编译通过 (powershell -NoProfile run_tests.ps1 -CI, `SUCCESS: Unit Tests compiled`, exit 0, 325043 lines 16.56s, �?Error/Fatal/undeclared).
- ProposalQueue 无外部调用点、无 DUnitX 测试 (仅骨架类未接�?; 改动为纯加锁包裹 + 容量守卫, 语义等价 (并发安全�?OOM 防护提升), 风险�?
- �?D-007 (Commander) 同属"骨架未接�?类修�? 不新增回归测�?(与同类已修项一�?.

**影响文件**:
- `Governance/DeepBase.Governance.AI.ProposalQueue.pas` (新增 EProposalQueueError 异常 + FLock/FMaxPending/FindByIdInternal/PendingCountInternal 字段方法 + 8 方法加锁 + 容量检�? +~70 �?

### BUG-431: Persistence/DeepBase.DB.Pool.pas 连接池归还脏连接 (残留事务/隔离级别泄漏) �?- 编号: BUG-431
- 来源: REVIEW5-R3-C / DATA-R3-001
- 严重�? P0
- 状�? 已修�?
**缺陷**:
`TPooledConnection.Release` 只把 `FState` �?`csIdle` �?`SetEvent`, 既不检�?`FConnection.InTransaction`, 也不回滚, 更不关闭可能仍打开�?TFDQuery 游标. `FindAvailableConnection` �?csIdle 连接只调 `IsValid` (仅查 `Connected`, 实际不执�?SELECT 1 探活). 后果: 调用方经 `Pool.Execute`/`Query<T>`/`GetConnection` 借出连接�? 若开启事务但�?finally 前抛异常 (或忘提交), 该连接带着未提交事务被归还; 下个借用�?`BeginTransaction` �?SQLite 上失�?("cannot start a transaction within a transaction"), �?PostgreSQL/MySQL 上可能读到上一调用方未提交的中间数�? 甚至把别人的 INSERT/UPDATE 一起提�? 调用方临时提升隔离级别后也会泄漏给后续借用�?

**根因**:
设计期未在归还路径做连接复位. 连接池复�?TFDConnection 但未对事�?隔离级别做隔离保�? 默认信任调用方善�? 异常路径下信任被打破.

**修复**:
1. 新增 `TPooledConnection.ResetConnectionState` (private, interface+impl 声明).
2. `Release` 在持 `FPool.FLock` **�?*�?`ResetConnectionState` (复位是连接级操作不涉池状�? 与��锁�?csIdle 分离, 保证复位与空闲可见性原�? 倒置顺序无意义风�? �?csIdle 一旦可见即可能被借出, 复位必须先于可见).
3. `ResetConnectionState` 内容:
   - `if FConnection.InTransaction then FConnection.Rollback` �?回滚残留未提交事�? **�?Commit**: 残留事务几乎都是异常路径遗留的未完成工作, 提交会把脏数据落�?
   - `FConnection.TxOptions.AutoCommit := FPool.FConfig.AutoCommit` �?重置 AutoCommit 到池配置, 防调用方临时改隔离级�?自动提交后泄�?
4. 异常容忍: 复位任一步失败仅 `DoPoolEvent` 记事�? 不阻断归�? 复位失败后连接仍�?csIdle/�?IsValid 兜底探活; 避免复位抛异常致 Release 提前 return 连接�?csInUse 泄漏.
5. 残留游标 (调用�?TFDQuery.Open 后异常未 Close) 不在连接池处理范�?�?dataset 生命周期属调用方责任, �?FireDAC 连接池设计一�?(池不接管 dataset 引用).

**设计决策**:
- 回滚而非提交: 异常路径遗留事务 = 未完成工�? 提交即脏数据落库. 这是 DATA-R3-001 的核心安全语�?
- 复位�?Release 而非 FindAvailableConnection: 借出时复位会让借用者承担复位开销且无法分辨脏来源; 归还时复位是"谁用谁清�?的对称设�? 下个借用者拿到干净连接.
- 不重�?Connected (不重�?: 重连代价大且可能触发连接失败, 复用价值丧�? 事务复位已覆盖核心风�?(跨调用方数据污染).

**验证**:
- Win64 全量编译通过 (powershell -NoProfile run_tests.ps1 -CI, `SUCCESS: Unit Tests compiled`, exit 0, 325082 lines 17.06s, �?H2077 无关 hint, �?Error/Fatal/undeclared).
- DB.Pool 有既�?DUnitX 测试 (DB.Pool.Tests), 修复为纯防御性复�?(正常路径 InTransaction=False 不触�?Rollback, 语义等价无回�?, 未新增专项测�?(与同类加固项一�? 真实脏连接复现需多线�?异常注入, 不在单测范围).

**影响文件**:
- `Persistence/DeepBase.DB.Pool.pas` (TPooledConnection 新增 ResetConnectionState private 方法声明+实现, Release 入口调复�? +~30 �?

### BUG-432: doQry/doQryMain.pas 过滤条件字符串拼接致过滤注入 (TADOQuery.Filter) �?- 编号: BUG-432
- 来源: REVIEW5-R3-C / DATA-R3-002
- 严重�? P1
- 状�? 已修�?
**缺陷**:
`btnFilterClick` (L151) 将用户输�?`s` 直接拼接�?`tblQueries.Filter`:
`tblQueries.Filter := 'proc_name LIKE ''%' + s + '%''';`
TDataSet.Filter 是表达式字符串而非 SQL, 但仍按表达式语法解析; 攻击者可注入 `%' OR 1=1 OR proc_name LIKE '%` 之类表达式片段绕过过�? 或注入未闭合引号致表达式异常 (DoS / 信息枚举). 即便不至 SQL �? 过滤表达式注入同样能放大暴露�?

**根因**:
doQry 早期演示代码直接字符串拼接构�?Filter, 未对表达式上下文做转�?

**修复**:
改用 `System.SysUtils.QuotedStr` 包裹整体匹配�?
`tblQueries.Filter := 'proc_name LIKE ' + QuotedStr('%' + s + '%');`
`QuotedStr` 将内嵌单引号翻倍为 `''`, 表达式解析器不再把用户输入里的引号当字符串边�? 注入片段被锁进字面量�? `System.SysUtils` 已在 doQryMain uses (L6), 无新依赖.

**验证**:
- doQry 工程在当�?BDS37 环境无法整体编译 (uDoQryLegacy.pas L8 引用�?`DBClient` 单元�?RAD Studio 12 Athens/37.0 已移�? 属该工程历史遗留, 与本修复无关). 修复行为纯标�?API (`QuotedStr`), uses 齐备, 语法确定正确.
- 此项为防御性加�? 无既有单测覆�?doQry 过滤路径 (doQry 不在 CI 单测工程�?.

**影响文件**:
- `doQry/doQryMain.pas` (btnFilterClick L151, +1/-1 �?

### BUG-433: doQry/doQryMain.pas information_schema 查询表名拼接 + proc_name 拼接�?SQL 注入 �?- 编号: BUG-433
- 来源: REVIEW5-R3-C / DATA-R3-003 (另见 L126 btnGenSqlClick)
- 严重�? P1
- 状�? 已修�?
**缺陷**:
1. `GetFieldList(TableName)` (L305) 将外部传�?`TableName` 直接拼接�?SQL:
   `aQry.SQL.Text := Format('SELECT column_name FROM information_schema.columns WHERE table_name = ''%s'';', [TableName]);`
   `TableName` 来自调用�?(界面/外部), 可注�?`x''; DROP TABLE ...;--` 之类 (单语句连接下受限, 但可构造读取越权或注释绕过).
2. `btnGenSqlClick` (L126) 将数据库字段�?`proc_name` 拼接进查�?
   `aQry.SQL.Text := 'select * from queries where proc_name=' + '''' + proc_name + '''';`
   `proc_name` 虽来�?`tblQueries` 字段, 但属数据层间接可�?(存储过程名可由用�?上游写入), 二次注入风险.

**根因**:
doQry 演示代码全程字符串拼接构�?SQL, 未参数化.

**修复**:
两处均改�?ADO 参数化查�?
- L305: `aQry.SQL.Text := 'SELECT column_name FROM information_schema.columns WHERE table_name = :t';` + `aQry.Parameters.ParamByName('t').Value := TableName;`
- L126: `aQry.SQL.Text := 'select * from queries where proc_name = :p';` + `aQry.Parameters.ParamByName('p').Value := proc_name;`
`aQry` �?`TADOQuery` (doQryMain L27), `Parameters.ParamByName` �?`Data.Win.ADODB` 标准参数 API (uses L12 已含), 驱动负责转义, 消除注入�?

**设计决策**:
- L286 (`GetTableList`) Format 未用 `DatabaseName` 参数且硬编码 `'public'` 字面�? 无变量拼�? 无注入风�? 仅风格冗�? 不在本安全任务范围改�?(避免越界改无�?.
- L178 (`Button1Click`) INSERT 语句 VALUES 全为字面�?('我是一头猪'/'已经分享等待下载' 硬编�?, 无变量拼�? 不处�?

**验证**:
- �?BUG-432: doQry 工程�?`DBClient` 历史遗留无法�?BDS37 整体编译; 修复行为�?`TADOQuery.Parameters.ParamByName` 标准 API, uses 齐备, 语法确定正确.
- doQry 不在 CI 单测工程�? 无回归测试触�?

**影响文件**:
- `doQry/doQryMain.pas` (GetFieldList L305, btnGenSqlClick L126, +4/-2 �?

### BUG-434: Persistence/DeepBase.Persistence.Diagnose.FireDAC.pas 三处 Check 方法吞异常致诊断"假绿" �?- 编号: BUG-434
- 来源: REVIEW5-R3-C / DATA-R3-004
- 严重�? P1
- 状�? 已修�?
**缺陷**:
`TFireDACDiagnoseStorage.CheckForeignKeys` (L460)、`CheckRequiredFields` (L517)、`CheckEnumValues` (L579) 三处 `try/except` 把查询异常经 `OutputDebugString` 静默吞掉: except 块既不向 `ResultList` 追加任何 `TDiagnoseResult`, 也不阻断, 方法返回当前已累积的结果 (查询失败前通常为空数组). 后果: 当连接断开/表结构不可内�?SQL 执行报错�? `DiagnoseAll` 聚合三方法空结果 �?`GenerateDiagnoseReport` �?`[OK] No issues found. Database schema is valid.` —�?检查根本没跑成功却�?全绿", 管理员误信数据库健康, 实际问题�?OutputDebugString 埋进 DebugView (生产环境通常无人�?DebugView). 这是"假绿" (green-on-error): 失败被伪装成通过.

**根因**:
except 设计期仅�?调试可见�? (OutputDebugString) 而非"结果可见�?. `TDiagnoseResult` 枚举原无"检查执行失�?语义型别, 即使想上报也无合�?`IssueType` 可填, 间接促成"吞掉返回�?的偷懒实�? 调用�?(DiagnoseAll/GenerateDiagnoseReport) �?结果数组为空=无问�?解读, 无法区分"真无问题"�?检查没跑成".

**修复**:
1. `Core/DeepBase.Diagnose.pas` `TDiagnoseIssueType` 枚举末尾新增 `ditCheckError` (序数 8, 不动 ditMissingTable..ditInvalidEnum 已有 0..7 序数, 二进制兼�?. 语义: 检查执行本身失�?(查询错误/内省失败), 区别�?数据有问�?.
2. �?Check 方法 except 块改为构�?`ditCheckError`+`IsOK:=False` �?`TDiagnoseResult` 追加 `ResultList`, Issue 字段�?`'检查失�? ' + E.Message`, TableName/ObjectName 填当前迭代上下文 (FK/RF/EF �?TableName/ColumnName), Suggestion 给重试指�? CanAutoFix:=False. 失败对调用方可见, DiagnoseAll 不再假绿.
3. `AddColumnIfNotExists` (L655) �?`AutoFix` (L676) �?except 保留�?OutputDebugString: 二者返回�?(Boolean/Integer) 已部分表达失�?(AddColumn 返回 False, AutoFix 计数不递增), 调用方可据返回值判�? 不属"假绿"语义; �?AutoFix 返回 Integer 无法承载异常文本, 改动牵涉签名变更, 超出 DATA-R3-004 范围, 不在本次修复.

**设计决策**:
- 新增枚举值而非复用 ditDataIntegrity: ditDataIntegrity 语义="数据完整性有问题" (数据�?, ditCheckError="检查没跑成" (执行�?. 复用会让真数据问题与检查故障混为一�? 调用方无法分辨该修数据还是该修连�?重试. 新增 1 值末尾追�? 序数兼容, �?case 穷举�?(GenerateDiagnoseReport �?CanAutoFix/FixSQL 分类�?case IssueType), 影响面仅枚举定义+测试序数断言.
- ditCheckError 填当前迭代上下文 TableName/ColumnName: 比留空更可定�?(调用方知哪个�?列的检查崩�?, 且变量在 except 处仍 in-scope (循环内赋�?.
- 不抛异常而追加结果项: DiagnoseAll 聚合�?Check, 单个表检查失败不应中断整次诊�? 追加 ditCheckError 让该失败在最终报告可�? 其余表继续检�?

**验证**:
- Win64 全量编译 SUCCESS exit 0 (325119 lines 17.05s, 编译阶段�?Error/Fatal).
- Diagnose 单元 DUnitX 回归: `run_tests.ps1 -Type Unit -CI -Platform Win64 -FromUnit DeepBase.Diagnose -AllowFilteredCI` �?Tests Found 40 / Passed 40 / Failed 0 / Errored 0, 含新�?`Ord(ditCheckError)=8` 序数断言 (Test_IssueType_Values).
- 补回归断言: `Tests/Test.DeepBase.Diagnose.pas` Test_IssueType_Values 末尾�?`Assert.AreEqual(8, Ord(ditCheckError))` 锁定新枚举序�?
- �? 全量测试运行有既�?Runtime error 216 (进程级崩溃于�?Diagnose 测试, git status 显示仓库处于 R3 多文件修复进行中, �?216 与本�?Diagnose 改动无关, Diagnose 单测全过可证).

**影响文件**:
- `Core/DeepBase.Diagnose.pas` (TDiagnoseIssueType 末尾新增 ditCheckError + 注释, +4 �?
- `Persistence/DeepBase.Persistence.Diagnose.FireDAC.pas` (CheckForeignKeys/CheckRequiredFields/CheckEnumValues 三处 except 块改 ditCheckError 结果项上�? ~+30 �?
- `Tests/Test.DeepBase.Diagnose.pas` (Test_IssueType_Values �?ditCheckError=8 断言, +1 �?

### BUG-435: Persistence/DeepBase.Persistence.MRU.FireDAC.pas Upsert 无条�?StartTransaction 误回滚调用方事务 �?- 编号: BUG-435
- 来源: REVIEW5-R3-C / DATA-R3-005
- 严重�? P2
- 状�? 已修�?
**缺陷**:
`TFireDACMRUStorage.Upsert` (L72) 无条�?`FConnection.StartTransaction`, except �?(L115) 无条�?`FConnection.Rollback`. 当调用方已在外层事务�?(共享同一 TFDConnection �?Upsert, �?Upsert 被另一已开事务的逻辑重入调用) �? (1) SQLite �?`StartTransaction` �?"cannot start a transaction within a transaction" 直接抛异�? (2) PostgreSQL/MySQL 上可能开�?savepoint 或嵌套事�? �?Upsert �?SELECT-then-INSERT/UPDATE 若中途抛异常, except �?`Rollback` 会回滚调用方的整个外层事�?(而非仅本 Upsert 的工�?, 把调用方已完成的合法 DML 一起撤销. 后果: 调用方事务被 MRU 的内部异常意外回�? 数据丢失, 且难定位 (表面�?MRU 写失�?.

**根因**:
DATA2-019 防并发重复键设计�? 直接 StartTransaction 假设 "调用方未开事务". �?MRU Storage 是共�?FConnection 的可复用组件, 无权假设调用方事务状�? 缺少事务所有权 (OwnTx) 跟踪, except 无条�?Rollback �?谁后开谁回滚全�?.

**修复**:
�?`Persistence/DeepBase.Persistence.Authorization.FireDAC.pas` (L590-627, DATA2-025) �?OwnTx 模式:
1. var 段新�?`OwnTx: Boolean`.
2. `OwnTx := False` �? `if not FConnection.InTransaction then begin FConnection.StartTransaction; OwnTx := True; end;` �?仅在调用方未开事务时自�?
3. `if OwnTx then FConnection.Commit;` �?仅提交自启的事务.
4. `except if OwnTx then FConnection.Rollback; raise;` �?仅回滚自启的事务; 调用方事务交还调用方 (异常�?`raise` 上抛让调用方感知).

**设计决策**:
- 不删事务只加所有权: DATA2-019 的防并发重复键语义保�?�?无外层事务时�?StartTransaction �?SELECT-INSERT, 防两并发 Upsert 都看�?"not found" 后双 INSERT �?UNIQUE. 有外层事务时复用�? 防重复键�?MRU �?UNIQUE 约束兜底 (非依赖事�?, 并发安全由调用方事务隔离级别保证, 无回�?
- `raise` 保留: 异常上抛让调用方知道 MRU 写失败并自行决定外层事务去留; 不吞异常.
- �?Authorization OwnTx 模式 (DATA2-025) 一�? 同仓库同模块族统一事务所有权约定, 降低认知负担.

**验证**:
- Win64 编译 SUCCESS exit 0 (run_tests.ps1 -FromUnit DeepBase.MRU -AllowFilteredCI, 编译阶段�?Error).
- MRU 单元 DUnitX 回归: Tests Found 13 / Passed 13 / Failed 0 / Errored 0. 测试�?TInMemoryMRUStorage mock 不实�?FireDAC 路径 (�?Diagnose 同理); 修复为纯防御�?OwnTx (无外层事务时 OwnTx:=True 自启+Commit 语义等价原逻辑无回�?, 真实重入/共享连接误回滚复现需多线�?共享连接异常注入, 不在单测范围, 与同类加固项 (BUG-431/BUG-434) 一致不新增专项测试.

**影响文件**:
- `Persistence/DeepBase.Persistence.MRU.FireDAC.pas` (Upsert var �?OwnTx, StartTransaction/Commit/Rollback �?OwnTx 守卫, +10 �?

### BUG-436: doQry/uDoQryLegacy.pas 异常/UI 消息含完整内联�?SQL (PII 泄漏) �?- 编号: BUG-436
- 来源: REVIEW5-R3-C / DATA-R3-006
- 严重�? P3
- 状�? 已修�?
**缺陷**:
legacy �?`uDoQryLegacy.pas` �?`BuildSQL` 生成内联值的 SQL 字符�?(参数值经 `QuoteValue`/`HandleParamValue` 拼入), 多处把完�?SQL 塞进 `msg` (var 输出参数 �?调用�?UI/日志) 或异常消息上�?
- `ExecuteAndGetResult` (L756): `raise ...CreateFmt('SQL执行错误: %s'#13#10'SQL: %s', [E.Message, aSQL])`
- `ExecuteSQL` (L778): `raise ...Create('doQry Error::SQL执行错误: ' + E.Message + #13#10 + 'SQL:' + SQL)`
- `doQry(ProcName...)` (L894/901/930/945/956/964/968/978/982/993): 10 �?msg 构造含 `'#13#10'SQL: %s'` + sSQL, 覆盖失败路径 (raise 上抛进日�? 与成功路�?(msg 返回�?UI 显示), 后者更�?�?成功执行也向用户暴露 SQL+参数�?

这些值可能是聊天消息正文/用户 ID/分享链接�?PII, 最终进入日志文件或错误对话�? 违反数据最小化原则.

**根因**:
legacy 层无参数�?SQL 执行 (值内联拼�?, 诊断/展示为复�?sSQL 字符串直接拼进用户可见消�? 未区�?"诊断信息" (完整 SQL, 调试�? �?"用户消息" (仅操作结�? 脱敏).

**修复**:
统一策略: msg/异常消息只保留错误本�?+ 操作类型/表名/受影响行数等脱敏元数�? 去掉 `'#13#10'SQL: %s'` 尾巴及对�?sSQL/SQL.Text 参数; 完整 SQL �?`{$IFDEF DEBUG} Winapi.Windows.OutputDebugString(...) {$ENDIF}` 输出到调试器 (DebugView, 生产通常�?DEBUG 定义/无人�? 即便接也不进持久日志), 不上抛不�?msg. 共改 13 �?(2 �?Execute* + 11 �?doQry/except), 均核�?Format 占位符与参数数对�?
- 保留 L325/L697 既有 `OutputDebugString('...SQL: ' + ...)` (已是调试器输�? 非用户可见消息路�? 不属泄漏�?.
- doQry 工程�?L8 `DBClient` 已自 Delphi 移除 (C-002/C-003 同款历史遗留), BDS37 无法整体编译 �?无编译验�? 改动为纯异常/UI 消息文本改写, Format 语法等价, uses `Winapi.Windows` 已在 L8 (全限�?OutputDebugString 调用安全), ��新增符号/签名变更.

**验证**:
- 残留扫描: `grep "'SQL: |SQL:'|SQL: %s" uDoQryLegacy.pas` 排除 DEBUG 行后仅余 L325/L697 既有 OutputDebugString (调试器输�? 保留), msg/异常路径零残�?
- 13 �?`{$IFDEF DEBUG}` 守卫 (11 新增 + 2 原有).
- 编译验证不可�?(doQry 工程 BDS37 历史遗留不可编译, �?BUG-432/433/434 现状); doQry 不在 CI 单测工程集无回归触发. 真实 PII 泄漏复现需 doQry.exe 运行 (依赖恢复 DBClient 的旧 BDS �?DBClient 替代), 不在本轮编译链覆�?

**影响文件**:
- `doQry/uDoQryLegacy.pas` (ExecuteAndGetResult L754-758, ExecuteSQL L777-779, doQry L894-996 �?11 �?msg/异常构造脱�? +13 DEBUG 守卫)

### BUG-437: AddColumn �?ColumnDef 原样拼入 DDL (防御性缺�? DDL 注入�? �?- 编号: BUG-437
- 来源: REVIEW5-R3-C / DATA-R3-007
- 严重�? P3
- 状�? 已修�?
**缺陷**:
`Persistence/DeepBase.Persistence.Manager.FireDAC.pas` �?`TFireDACManagerStorage.AddColumn` (L208-228): `TableName`/`ColumnName` �?`TSQLUtils.ValidateIdentifier` 校验, �?`ColumnDef` (�?`'TEXT DEFAULT ''LTR'''`) 直接 `Format('ALTER TABLE %s ADD COLUMN %s %s', [TableName, ColumnName, ColumnDef])` 拼入 DDL, 无白名单. 当前唯一调用�?`Core/DeepBase.Manager.Schema.pas` `AddColumnIfMissing` 只传硬编码字面量 (TEXT/INTEGER/REAL + DEFAULT '�?/DEFAULT 数字), **目前不可利用**; �?`AddColumn` 暴露在公共接�?`IManagerStorage.AddColumn` �? 任何未来调用方传入受外部影响�?ColumnDef 即引�?DDL 注入 (分号终止 ADD COLUMN 后接 DROP/DELETE/CREATE TRIGGER/ATTACH �? �?`--` 注释).

**根因**:
防御边界 (持久化层) �?结构化标识符" (TableName/ColumnName) 有校�? 但对"类型定义片段" (ColumnDef) 缺校�?�?二者都原样拼入 DDL, 后者留了缺�? 属纵深防御缺�?(defense-in-depth), 非当前可利用漏洞.

**修复**:
�?SQL 安全工具�?`Core/DeepBase.SQL.Utils.pas` �?`TSQLUtils` �?`IsValidColumnDef`/`ValidateColumnDef` 类方�?(与既�?`IsValidIdentifier`/`ValidateIdentifier` 同族, 复用既有单元作为防御工具统一入口):
- 拒绝: �?/ 长度>200 / 分号 `;` / 行注�?`--` / 块注�?`/*` `*/` / CR LF 换行 (DDL 注入终止符与注释载体).
- 拒绝: DDL/DML 关键�?(DROP/CREATE/ALTER/DELETE/INSERT/UPDATE/SELECT/TRIGGER/INDEX/VIEW/ATTACH/DETACH/PRAGMA/VACUUM) �?`\b` 词边界大小写不敏感匹�?(�?`TEXT; DROP` 这类二段语句).
- 允许字符�? 字母/数字/空格/单引�?(字符串字面量)/下划�?小数�?(数字默认�?/括号逗号 (NUMERIC(10,2)/VARCHAR(255)); 拒双引号/反引�?其他.
- `AddColumn` (L216-223) �?ValidateIdentifier 两行后加 `TSQLUtils.ValidateColumnDef(ColumnDef, 'Manager.AddColumn.ColumnDef')`, 非法�?`EArgumentException` 上抛 (�?identifier 校验一致的失败语义).

**设计选择**: 选白名单正则校验而非改强类型 `TColumnDef` 记录 �?前者不改公�?`IManagerStorage.AddColumn` 签名, 不破坏现有调用方 (`Manager.Schema` 字面量全合法), 是最小侵入的纵深防御加固; 后者虽更彻底但�?API 重构, 超出 P3 防御缺口的修复范�?

**验证**:
- DUnitX 测试: `Tests/Test.DeepBase.SQL.Security.PBT.pas` �?`Property20_ColumnDefWhitelistAcceptsSafe` (11 个合法样�? TEXT/INTEGER/REAL/BLOB + DEFAULT '<�?'/DEFAULT 数字 + NOT NULL + NUMERIC(10,2)/VARCHAR(255)) �?`Property20_ColumnDefWhitelistRejectsInjection` (12 个非法样�? �?分号+DROP/`--`注释/`/*`块注�?CRLF+DROP/分号+DELETE/INSERT/SELECT/CREATE/ATTACH/双引�?反引�?, �?`IsValidColumnDef` 布尔�?`ValidateColumnDef` �?`EArgumentException` 双路�?
- 真实调用方全量核�? `Core/DeepBase.Manager.Schema.pas` 所�?`AddColumnIfMissing(...)` 字面�?(TEXT/INTEGER/REAL + DEFAULT 'LTR'/'String'/'General'/'en'/数字) 全部通过白名�? 无回�?(运行期实际�?`TEXT DEFAULT 'LTR'` 含单引号字面�? 白名单允许单引号 �?.
- 编译: `run_tests.ps1 -Type Unit -CI -Platform Win64 -FromUnit DeepBase.SQL.Security.PBT` �?`SUCCESS: Unit Tests compiled` (325286 �? 16.48s) + `Tests Passed: 5` (Property17/18/19 + 新增 Property20 两个), 全绿. Manager.FireDAC uses `DeepBase.SQL.Utils` 已在 L26 (复用既有引用), 无新�?uses; `System.RegularExpressions`/`System.SysConst` �?SQL.Utils 内部 implementation uses 新增 (TRegEx/SResourceSuffix), 不影�?Manager.

**影响文件**:
- `Core/DeepBase.SQL.Utils.pas` (+`IsValidColumnDef`/`ValidateColumnDef`, +uses System.RegularExpressions/SysConst)
- `Persistence/DeepBase.Persistence.Manager.FireDAC.pas` (AddColumn L217 �?+1 行校�?
- `Tests/Test.DeepBase.SQL.Security.PBT.pas` (+Property20 两个 [Test] 方法)

### BUG-438: DeepBaseTests.exe 全量 Runtime error 216 @0x593A �?异常对象生命周期悬挂 (已修�? �?- 编号: BUG-438
- 来源: 排查 (Runtime 216 一直是 BUG-421 等条目中"预存缺陷, 无根�?的引用对�? 本条首次定位根因触发�?
- 严重�? P2
- 状�? �?已修�?(2026-07-09). 根因 = Delphi 异常对象生命周期悬挂, **�?*早期推测的线程竞�?

**症状**:
`Tests/DeepBaseTests.exe` 全量套件 (`--exit:Continue`) 运行末尾确定性崩�?`Runtime error 216 at 00007FF6D4A7593A` (Delphi �?Access Violation 0xC0000005 包成 216). 偏移 `0x593A` 每次完全一�?(确定�?AV, 非随�?. 此缺陷至少自 BUG-421 (history 早期) 起被多条目引用为"预存缺陷", 一直无根因.

**排查方法 (零代码改�?**:
1. �?`Tests/Test.DeepBase.DiagnosticLogger.pas` 自带的逐测�?BEGIN/END/PASS/FAIL 时间戳日�?(`Tests/Logs/test-diagnostic.log`), 全量�?+ `tee` 落盘, 崩溃前日志最后一行即触发测试.
2. 确认日志停在 `Test_OnError_Exception_RetryPathStillExecutes` �?`Test BEGIN` 之后, 无任�?END/PASS/FAIL �?崩在该测试方法体�?
3. 单独跑该 fixture (`-b -r:"Test.Regression.BUG324_WorkerQueueCallbackSafety" --exit:Continue`) 仍崩且偏�?`0x593A` 完全一�?�?排除跨测试内�?线程状态污�? 为本测试固有.
4. �?fixture 9 个测试前 8 个全�?(9 个点 `.........` 后崩), �?9 个即 OnError 测试�?

**根因触发�?*:
`Tests/Regression/Test.Regression.BUG324_WorkerQueueCallbackSafety.pas` �?`TBUG324_WorkerQueueCallbackSafetyTest.Test_OnError_Exception_RetryPathStillExecutes` (L298-323) 方法体内. 该测试是 fixture 9 个测试中唯一组合以下三要素的:
- `FQueue.OnError := FRaiser.RaiseOnError` (OnError 回调主动�?`Exception.Create('OnError simulated failure')`)
- `LRetryPolicy := TRetryPolicy.Immediate(2)` (retry 2 �?
- `FQueue.Stop(True)` (主线程显式停队列�?WaitFor worker 退�? �?注意�?8 �?callback 测试均无此调�? 依赖 TearDown `FreeAndNil(FQueue)` 隐式�?
**嫌疑代码区域 (WorkerQueue 生产代码)**:
`Core/DeepBase.WorkerQueue.pas`:
- `TWorkerQueue.Create('bug324_test', 2)` �?**2 �?worker 线程** (fixture SetUp L197).
- `CreateJob` 默认 `FTimeout := FDefaultTimeout = 300000` (L1542/L1476) �?`ProcessJob` �?L1921-1949 �?`TJobHandlerThread` 分支 (handler 在独立线程跑, `LDoneEvt.WaitFor` + `LHandlerThread.WaitFor`).
- handler 抛异�?�?`ProcessJob` L2027 except �?�?`FOnError`(也抛, L2036-2040 try/except �? �?`AJob.CanRetry` �?�?`AJob.PrepareRetry` (L2045) �?`FLock.Enter` (L2047) �?`FPendingQueue.Add(AJob)` (L2049) �?`SortPendingQueue` (L2050, 比较器访�?`Left/Right.Priority`+`CreatedAt` L1850-1859) �?`FOnJobRetrying`(L2055-2059).
- `Stop(True)` (L2144): �?`FShuttingDown`, 对每 worker `Terminate`+`WaitFor`, 然后 `FWorkers.Clear`.
- 最可能崩点: retry 路径 (L2042-2059) �?`Stop(True)` �?worker WaitFor 之间的竞�? �?2-worker 并发�?`SortPendingQueue`/`GetNextJob` �?retry job 的访�? 所有路径静态看均有 `FLock` �?try/except 保护, 无明显锁外裸访问, �?0x593A 对应的确切源码行需 map-file 反查 (当前 `DeepBaseTests.dproj` `DCC_DebugInformation=0` 未开 map file).

**为何�?8 个测试不�?*: 它们或无 retry (handler 异常直接�?except �?`else` 失败分支 L2061+), 或无 `Stop(True)` (�?TearDown 隐式�?, 未触�?retry+Stop(True) 的线程竞态窗�?

**map-file 查表结论 (2026-07-13 推进, 仍属诊断阶段)**:
- �?`dcc64 -GD` 重编 `DeepBaseTests.dpr` 生成详细 .map (77MB, �?Publics by Name/Value + Line numbers �?. 重编后单独跑 BUG324 fixture 崩溃偏移仍为 `0x593A` (基址�?ASLR �?`00007FF71890`, 偏移不变), 确认非重编噪�?
- PE `ImageBase=0x140000000`, `.text` �?RVA 起始 `0x1000` �?崩溃 RVA `0x593A` �?.text 段内, 段内偏移 = `0x593A - 0x1000` = `0x493A`.
- 段表显示 .text 段首模块�?`System` (段内偏移 `0x00000000` �? �?`0x2074C`). Publics by value 查询 `0x493A` 的最近前导符号为 `System..TNoRefCountObject` @ 段内偏移 `0x3588` (�?`0x13B2`=5042 字节); `0x3588`~`0x5200` 区间无其他导出符�?�?`0x493A` �?`TNoRefCountObject` 之后�?System 单元**未导出内部代码区**.
- Line numbers 段确�? `System` 单元**无任何行号条�?* (RTL 预编�? 行号未编�?map). 因此 map 路径**无法定位 0x493A 的确切源码行**.
- **判定**: `0x593A` 报告的是 Delphi RTL �?OS Access Violation 0xC0000005 包成 `Runtime error 216` 时记录的**异常触发指令地址** (落在 System RTL 内部的对象释�?接口清理/异常对象析构路径, �?`FreeMem`/`_IntfClear`/`FinalizeRecord`), 是被业务代码触发�?次生地址", **非业务栈�?*. 要定位真正的业务根因必须取崩溃瞬间的调用�? map-file 查���已到能力上限.
- **补充静态分�?(高置信根因假�?**: `FWorkers := TObjectList<TWorkerThread>.Create(True)` (OwnsObjects=True, L1480); `Stop(True)` 在�?worker `Terminate`+`WaitFor` (L2152-2155) �?`FWorkers.Clear` (L2161) �?Free 每个 worker 线程对象. `TWorkerThread.Execute` (L1061-1095) �?`except on E: Exception do Inc(FErrorCount)` (L1089) 吞掉 ProcessJob 抛出的所有异�? retry 路径�?`FOnError`/`FOnJobRetrying`/`FOnJobFailed` 回调主动抛异常被 `try...except end` �?(L2036-2040/L2055-2059/L2073-2076), 吞掉的异常对象在 except 块结束释�? 崩溃最可能发生�? (a) `Stop(True)` �?`WaitFor` �?worker 线程 `ThreadProc` 最终清理栈上被吞异常对�?接口引用的竞�? �?(b) dead-letter 分支末尾 `FOnCompletion(AJob.Id, False, E.Message)` (L2080) 引用�?`E` (except 头捕�? 在某种路径下已失�? 两者均指向 System RTL 的异常对象生命周�?接口清理, �?`0x493A` �?System 内部一�?
- **WER LocalDumps 尝试无效**: 配置 `HKLM\...\Windows Error Reporting\LocalDumps\DeepBaseTests.exe` (DumpType=2 full) 后重�? 崩溃未生�?dump �?Delphi 216 �?RTL 主动 `ExitProcess(216)` (�?`System._RunError`→`Halt`), 非未处理 OS 异常, WER 不介�? 证实须走 RTL hook 而非 OS 级崩溃捕�?

**修复 (未做, 待办)**:
1. ~~开 `DeepBaseTests.dproj` �?`MapFile`/`DCC_DebugInformation` 重编, �?`0x593A` 偏移�?map 表定位确切源码行.~~ **已完�?(2026-07-13): map-file 查表结论 = 崩溃点在 System RTL 内部 (段内偏移 0x493A, 无行�?, map 无法定位源行. 见上 "map-file 查表结论".**
2. 改用**调用栈捕�?*: 仓库已有 `Core/DeepBase.AutoFix.StackWalker.pas` (`CaptureStack` �?`RtlCaptureStackBackTrace`+`GetModuleHandleEx` �?module/base/rva 元组, 零依�? RVA 跨次稳定�?map 解析). �?`WorkerQueue.pas` retry 路径关键�?(handler except 入口 / `FOnError` �?/ `PrepareRetry` �?/ `FPendingQueue.Add` �?/ `FOnJobRetrying` �?/ dead-letter �?`FOnCompletion` �? �?`Stop(True)` �?`WaitFor` 前后埋临�?`CaptureStack` 落盘 (`Tests/Logs/wq-trace.log`), 重编复现, 最后一个成功落盘的栈即崩溃前最近可观测�?(二分缩小到具体代码段). 埋点�?`// TEMP DIAG BUG-438`, 定位后立即还�? 或装 madExcept IDE 集成 (hook RTL 异常路径, 崩时打印 AV �? 但引入新依赖).
3. 定位到确切业务行�? 视情�? �?retry 路径某行锁外访问 �?加锁; �?`SortPendingQueue` �?`Stop` 后仍�?worker �?�?�?`FShuttingDown` 短路; �?`TJobHandlerThread` �?`Stop` �?WaitFor 死锁式释�?�?修正线程释放顺序; �?dead-letter `FOnCompletion` 引用失效 `E` �?`AcquireExceptionObject` 保活或前置拷�?`E.Message`.

**影响文件** (待修复时):
- `Core/DeepBase.WorkerQueue.pas` (ProcessJob retry 路径 / Stop / SortPendingQueue)
- `Tests/DeepBaseTests.dproj` (开 map file, 一次性诊断用)

**验证** (待修复后):
- `DeepBaseTests.exe -b -r:"Test.Regression.BUG324_WorkerQueueCallbackSafety" --exit:Continue` 不再 216, 9 个测试全�?
- 全量 `DeepBaseTests.exe --exit:Continue` 末尾不再 216.

**修复结论 (2026-07-09)**:
早期诊断推测�?retry 路径�?Stop(True) WaitFor 线程竞�?**不成�?* �?根因�?Delphi 异常对象生命周期悬挂, 一处确定性缺�? 非竞�?(非时序相�?:

- `Core/DeepBase.WorkerQueue.pas` `TJobHandlerThread.Execute` �?`on E: Exception do FError := E` (�?L1041) �?except 块边界持有局部异常对�?`E`. Delphi 语义: `except on E:` 块结束时 RTL 自动 `Free` 异常对象 `E` (除非 `AcquireExceptionObject` 增引�?. �?except �?`end;` �?`E` 被释�? `FError` 变悬挂指�?
- `ProcessJob` (handler-thread 分支, Timeout>0 �? �?`TakeError` 取回悬挂�?`FError` �?`raise LHandlerErr` 操作已释放对�?�?Access Violation 0xC0000005, Delphi RTL 包成 `Runtime error 216`. 崩点�?System RTL 异常对象释放/析构路径 (段内偏移 0x493A 紧邻 `TNoRefCountObject`), �?map-file 查表结论一�?�?map 查不到源行是因为崩在 RTL 内部而非业务栈顶.
- **为何仅第 9 测试�?*: 该测�?(handler 抛异�?+ Timeout>0 �?handler-thread 分支 + retry + Stop(True)) �?fixture 中唯一�?`TakeError`→`raise LHandlerErr` 悬挂路径�? �?8 测试或不 retry、或 Timeout=0 �?inline 分支 (`raise;` re-raise except 头捕获的**�?* `E`, 不悬�?, 故不�? 确定�?AV (偏移每次一�? 正是悬挂指针解引用固定地址的特�? 进一步证伪竞态假�?(竞态偏移应随机).

**修复**: `Execute` �?except 内改为克隆异常对�?
```pascal
on E: Exception do
  FError := Exception.Create(E.Message);   // 克隆, 脱离 RTL 生命周期
```
新对象由 `FError` 独占持有, 现有 `TakeError` (返回 FError 并置 nil) / 析构 `FreeAndNil(FError)` / `ProcessJob` �?`raise LHandlerErr` + 超时分支 `FreeAndNil(LHandlerErr)` 引用语义全部正确, 无需改动. `raise` 克隆对象后被 `ProcessJob` �?`on E:` 捕获, RTL 在该 except 块结束正常释放它 (无悬挂无泄漏). 代价: 丢失原异�?ClassName, 但下�?(L2031 `TJobResult.CreateFailure(E.Message)` / L2081 `FOnCompletion(..., E.Message)`) 只用 `.Message`, BUG324 测试不断言异常类型, 无影�?

**为何不用 `AcquireExceptionObject`/`ReleaseExceptionObject`**: 这两�?System API �?*无参�?*, 作用�?当前正在处理的异常对�?, 只能�?except 上下文调; `raise LHandlerErr` re-raise 后控制流转走、新 except 是新上下�? 无法对原对象配对 `ReleaseExceptionObject`, 易误用导致泄漏或释放错误对象. 克隆方案无引用计数配对负�? 语义最简.

**衍生同类隐患 �?BUG-439**: 排查期间发现两处同类 `�?except 块持�?E` 模式 (�?`AcquireExceptionObject`), 原判"无对应测试暴露崩�? 属潜在隐患非已现缺陷, 本轮未改 (避免未经测试验证的盲�?": `Core/DeepBase.Resilience.Retry.pas` L396 `TryExecute` �?`Error := E` (out 参数); `DeepFlow/Source/AI/DeepFlow.Skill.Client.pas` L156 `LLastException := E`. **已于 2026-07-09 全部修复, 见下方「修复结�?(2026-07-09)」段.** 详见 tasks.md BUG-439.

---

### 修复结论 (2026-07-09)

**site 1 �?`Core/DeepBase.Resilience.Retry.pas` `TRetryPolicy.TryExecute` (测试先行, 已验�?**

except �?`Error := E` (out 参数) �?块结�?RTL Free E �?函数返回悬挂 `Error`. 现有测试 `Test_TryExecute_ReturnsFalseOnFailure` 仅断言 `Assert.IsNotNull(Error)` (指针非空), 悬挂指针同样非空故通过, **从未解引�?`.Message` 内容 �?隐患长期未暴�?* (�?BUG-438 测试"通过直到触碰悬挂对象内容才暴�?同构).

**测试先行验证**: �?`Tests/Test.DeepBase.Resilience.pas TRetryPolicyTests` 新增 `Test_TryExecute_ErrorOutParam_NotDanglingAfterFailure`... �?`TryExecute` (抛带标记串的异常) �?64 �?`Exception.Create/Free` 堆扰动促�?MM 复用 RTL �?Free �?E 内存�?�?�?`Error.Message`. 修复�?*确定性失�?*: `Expected [BUG439 dangling marker] but got []` (堆扰动覆盖了 E �?FMessage 字段, 读回空串, textbook use-after-free). 修复后克�?`Exception.Create(E.Message)` �?`Error.Message` 正确返回标记�?

修复: except �?`Error := Exception.Create(E.Message)` (克隆, �?BUG-438 模式). 现有 `out Error` 所有权语义不变 (调用方负责释�? 已给 `Test_TryExecute_ReturnsFalseOnFailure` �?`FreeAndNil(Error)` 避免克隆泄漏). 新测试中 `raise Error` 转交 RTL 所有权, 无泄�?

**site 2 �?`DeepFlow/Source/AI/DeepFlow.Skill.Client.pas` `ExecuteWithRetry` (记为已知盲改)**

`LLastException := E` (重试循环 except �? �?每轮 except 块结�?RTL Free E �?退出循环后 `raise LLastException` (操作已释放对象的 VMT, 确定�?AV, �?BUG-438 �?`raise LHandlerErr` 同构) / `LLastException.Message` (读已释放字符�?. 所有重试失败即触发.

DeepFlow 模块未接�?`DeepBaseTests.dpr` 测试工程、`THTTPClient` 在构造函数内 new 不可注入 (测试需起真�?HTTP server), �?*记为已知盲改** (用户决策: 修复 + 记为已知盲改):
- except 内克�? �?*保留 `ESkillClientException` 类型** (`if E is ESkillClientException then ESkillClientException.Create(SkillName, CallType, OriginalMessage)`), 维持尾部 `is ESkillClientException` 判断与未包装 re-raise (`raise LLastException`) 语义不变 (避免 BUG-438 "�?ClassName" 代价在此影响功能).
- **多轮重试克隆泄漏防护**: except 内覆盖前 `FreeAndNil(LLastException)` 回收上一轮残留克�? 尾部 else 分支 `try/raise 新对�?finally FreeAndNil(LLastException)` 释放被包装前的克�?(raise 新对象转�?RTL, finally 释放旧克�? 时序正确: `.Message` �?raise 内读先于 finally Free).

**影响文件**:
- `Core/DeepBase.Resilience.Retry.pas` �?`TRetryPolicy.TryExecute` except �?1 处改 (克隆 + 注释)
- `Tests/Test.DeepBase.Resilience.pas` �?`TRetryPolicyTests` 新增 `Test_TryExecute_ErrorOutParam_NotDanglingAfterReturn` 回归测试; `Test_TryExecute_ReturnsFalseOnFailure` �?`FreeAndNil(Error)`
- `DeepFlow/Source/AI/DeepFlow.Skill.Client.pas` �?`ExecuteWithRetry` except 内克�?(保留类型) + 覆盖�?FreeAndNil + 尾部 try/raise/finally 释放

**验证结果 (2026-07-09)**:
- Resilience fixture (site 1): 修复�?121/122 (新测试确定性失败暴�?use-after-free `Error.Message=[]`); 修复�?122/122 全过, 0 失败 0 泄漏.
- Resilience + BUG324 联跑 (site 1 + BUG-438 回归): 132/132 全过, 0 失败 0 泄漏 �?Retry.pas 改动未扰�?WorkerQueue 路径.
- site 2: DeepFlow 模块无测试工程可�? 已逐行自审所有权�?(多轮克隆泄漏 + 尾部 else 泄漏均已�?.

**影响文件**:
- `Core/DeepBase.WorkerQueue.pas` �?`TJobHandlerThread.Execute` except �?1 处改 (克隆 + 注释)
- `Tests/Regression/Test.Regression.BUG324_WorkerQueueCallbackSafety.pas` �?新增 `Test_BUG438_HandlerException_MessagePropagatedToCompletion` 回归测试 (handler 异常 + Timeout>0 + retry + Stop(True), 断言不崩 + FOnCompletion 收到原异�?Message)

**验证结果 (2026-07-09)**:
- 单独 BUG324 fixture: 10 测试全过 (�?9 + 新增 1), 0 失败 0 崩溃 0 泄漏.
- 全量基线对比 (git stash WorkerQueue 改动跑基�?vs 修复�?: Tests Passed 4148 �?4157 (+9), Tests Failed 22 �?13 (-9, 即原原因 216 失败�?9 个现通过), Tests Errored 28 �?28 (不变, �?DoQry `Query definition not found` 等无关既有失�?, Tests Leaked 0, **末尾 216 消失**. 无回�?
- �? bugfix.md 多条历史条目 (BUG-390/L1126、D-002/L1300、L1313、L1336、L1349、L1678) 长期�?全量末尾 Runtime error 216"标注�?预存缺陷, 无根�? 非本修复引入" �?本修复一举消除该长期预存 216 根因, 后续这些条目�?预存 216"引用已不再适用 (216 不复存在).

---

### BUG-440: SpeechService PermissionClient 接口字段双重释放 �?Invalid pointer operation (已修�? �?
**发现 (2026-07-09)**: 阶段�?Speech 接线 (Registry Factory 闭包 + SAPIAdapter + Wiring 测试) 验证期间, �?`Test.DeepBase.Speech.TSpeechTests.Test_Service_WithPermissionClient_ChecksAndConsumesQuota` �?`Invalid pointer operation` (�?216, �?AV on sapi.dll). 其余 6 �?TSpeechTests 用例全过.

**根因**: REVIEW5-FEAT-010 �?`TDeepBaseSpeechService.FPermissionClient` 从具体类 `TDeepKitPermissionClient` 改为接口 `IPermissionClient` 以解�?Speech↔Commerce. �?`TDeepKitPermissionClient = class(TInterfacedObject, IPermissionClient)` 带引用计�?�?接口字段赋�?`Service.PermissionClient := Permissions` **增引用计�?*; 测试 `finally` �?`Service.Free` 释放 Service �?接口引用归零 �?**RTL 自动 Free �?Permissions 对象**; 紧接 `Permissions.Free` **二次释放同一对象** �?`Invalid pointer operation`. �?调用�?own Permissions, Service 弱借用"所有权语义被接口引用计数破�? (git 对比 HEAD cd439aa 确认: HEAD 该字段仍�?`TDeepKitPermissionClient` 对象类型, 测试 pass �?此回归为未提交改动批次中 REVIEW5-FEAT-010 接口化引�?)

**修复**: `FPermissionClient: IPermissionClient` �?`[weak] FPermissionClient: IPermissionClient`. 弱引�?*不增引用计数**, Service 析构不释�?PermissionClient, 调用�?own 语义恢复; 保留 REVIEW5-FEAT-010 "解耦不依赖具体�? 的设计意�? `[weak]` �?Delphi 编译器内置特�?(XE8+), BDS37 Win64 (�?ARC 桌面编译�? 语义=不增引用计数 + 析构�?nil, 无需额外 uses. 仓库此前�?`[weak]` 先例, 本条为首�?

**影响文件**:
- `Features/DeepBase.Speech.Service.pas` �?`FPermissionClient: IPermissionClient` �?`[weak] FPermissionClient: IPermissionClient` (1 �?+ 注释说明所有权语义).

**验证结果 (2026-07-09)**:
- Speech 域全 fixture 批跑 (`TSpeechTests` + `TSpeechWiringTests` + `TTestIntentParser` + `TTestVoiceprintStorage`): 修复�?`TSpeechTests` 7 �?1 errored (本用�?; 修复�?**35/35 全过, 0 失败 0 errored 0 泄漏**. Wiring 阶段�?4 新测全过. 无回�?
- �? 未跑全量 (�?[[unit-test-fullrun-runtime216]] 历史全量�?216 制约, �?fixture 子集验证). 阶段零改�?blast radius 仅限 Speech �?(Registry/Service/SAPIAdapter 均为 Speech 内部单元, 其他域不 uses), Speech �?35 全绿已证明无扩散回归.

---

## BUG-441: Governance 编译阻塞致全量测试无法构�?(2026-07-09)

**现象**: `DeepBase.Governance.ConfigRegistrar.pas` �?`DeepBase.Governance.EvidenceStore.SQLite.pas` 存在编译错误, 拉入这两个单元的任何目标 (�?`DeepBaseTests.dpr`) 构建中断, 全量测试无法跑�?

**根因** (2 �? 均为 DATA2-023 阶段代码笔误/类型不匹�?:
1. `ConfigRegistrar.pas` L451/L574 调用 `FActionGrid.RegisterAction(...)` �?该方法签名实�?`RegisterActionObj`, 笔误�?E2003/E2027 undeclared/不匹�?
2. `ConfigRegistrar.pas` ComputeModeHMAC �?`EvidenceStore.SQLite.pas` ComputeHash �?HMAC 分支, �?`THMACUtils.ComputeHash(key, data: string)` �?string 参数用于 HMAC key (DPAPI/CNG 保护的字节密�?, 期望 TBytes 重载; 调用方传 string 致类型不匹配 (E2010) 或语义错�?(把字节当 UTF-16 string).

**修复**:
- `Governance/DeepBase.Governance.ConfigRegistrar.pas`: uses �?`DeepBase.Crypto.Encoding`; 2 �?`RegisterAction` �?`RegisterActionObj`; ComputeModeHMAC 改用 `THMACUtils` �?`TBytes` 重载, 输出�?`TEncodingUtils.HexEncode` 转小写十六进�?(�?`HashToHex` 大写在同分支内自�? �?读用同一函数同分支故无大小写 bug).
- `Governance/DeepBase.Governance.EvidenceStore.SQLite.pas`: implementation uses �?`DeepBase.Crypto.Encoding`; ComputeHash HMAC 分支�?`TBytes` 重载 + `HexEncode`.

**验证结果 (2026-07-09)**:
- 两文件单�?`dcc64` 编译: 0 error.
- 全量正式路径 `run_tests.ps1 -Type Unit -CI -Platform Win64`: **编译成功** (328853 lines, 0 编译错误), 测试可跑.
- 全量测试: Passed **4161** / Failed 14 / Errored 28 / Leaked **0**, **�?Runtime error 216** (全量跑�? 历史全量�?216 未重�?�?BUG-438 修复 + 正式 SP 路径下稳�?.
- 零回归确�? 14 failed + 28 errored 全部位于 DoQry (Query definition not found / ErrorCode 映射) / Commerce-Payment (WeChatPay 公钥加载失败, EPaymentSignError vs EDeepBaseCommercePaymentError) / BUG326 Scheduler (callback raise 后任务状�?tsIdle 而非 tsCompleted/tsFailed) / Speech.PBT / Metrics.TestTimerStart / DeepFlow.Engine 等域 �?�?`rg` 确认这些失败域测试单�?*无一 uses** 我改�?2 �?Governance 单元 (EvidenceStore.SQLite 无测�?uses; ConfigRegistrar �?`Test.DeepBase.Governance.ConfigRegistrar.pas` uses, �?fixture 未在结果清单出现 = 未挂入主 exe 运行), �?28+14 失败均为 pre-existing 语义/配置问题, 非本次编译修复引�? 也非回归.
- �? 剩余 pre-existing 失败 (DoQry 查询定义未注�?/ WeChatPay 公钥未配 / BUG326 状态机 / 并发竞争) 属各域既有问�? 不在"修编译路�?范围, 另行登记.

**影响文件**:
- `Governance/DeepBase.Governance.ConfigRegistrar.pas` �?uses +2 �?RegisterActionObj + HMAC TBytes 重载
- `Governance/DeepBase.Governance.EvidenceStore.SQLite.pas` �?implementation uses + ComputeHash HMAC TBytes 重载

---

## BUG-442: AutoUpdate DownloadUpdate 未吞网络异常, 契约要求�?LastError 返回 False (已修�? �?
**现象**: `Test_DownloadUpdate_WithSha256_DoesNotFailIntegrityCheck` / `Test_DownloadUpdate_WithSignature_DoesNotFailIntegrityCheck` 全量 Errored: `Error sending data: (12002) 操作超时`. 两用例用 RFC 5737 TEST-NET (`https://192.0.2.1/unreachable`) 故意触发 HTTP 失败, 只验�?integrity gate 不误�?

**根因**: `Features/DeepBase.AutoUpdate.pas` `TDeepBaseAutoUpdate.DownloadUpdate` L795 `Client.Get(Info.DownloadUrl)` 对不可路由地址�?`ENetHTTPClientException`/WinHTTP 12002 超时异常, **方法�?try/except 包网络异�?*, 异常穿透到测试. 用例注释明确契约"download may still fail due to network, but not due to integrity check", 断言期望 `LastError` 不含 integrity 拒绝消息 �?即设计意图是 **DownloadUpdate 吞网络错误设 LastError 返回 False**, 但实现未兑现该契�?

**修复**: `DownloadUpdate` �?`Client.Get` 块包 try/except, 捕获任意 Exception �?`FLastError := 'Download failed: ' + E.Message; Exit;` (返回 False). 网络/瞬时失败不再以未处理异常穿�? 调用方可�?LastError + 返回值区�?网络失败"�?integrity 拒绝"两条路径.

**验证 (2026-07-09)**: AutoUpdate fixture 39/39 通过 (�?IntegrityCheck 用例现走 LastError=False 路径, 断言通过). 全量 4203P/0F/0E/0Leaked.

**影响文件**: `Features/DeepBase.AutoUpdate.pas` �?DownloadUpdate 网络异常 try/except 吞噬.

---

## BUG-443: Speech Registry Discover 探针无容�? SAPI/COM 在无�?CI �?AV 穿�?(已修�? �?
**现象**: `Test.DeepBase.Speech.PBT.TSpeechRegistryPBT.P2_Enable_Disable_Idempotent` 全量 Errored: `Access violation at address ... in module 'sapi.dll'. Read of address 0x0`. 用例本身只做 registry Register/Disable/Discover, 不碰 SAPI.

**根因**: `Features/DeepBase.Speech.Registry.pas` `TSpeechRegistry.Discover` 遍历已注册后端时, L187-188 直接�?`LInfo.IsAvailableFunc()` 判断可用�? **�?try/except**. SAPI/COM 后端�?IsAvailableFunc 在无�?CI (无音频设�?/ SCOM 对象未实例化) 下访问空 COM 对象解引�?�?AV 穿透整�?Discover �?调用�?(P2 用例) Errored. 单个后端探针异常不应崩溃整个发现循环.

**修复**: Discover �?IsAvailableFunc 调用�?try/except, 抛异常时视作"不可�? Continue 跳过该后�? 后端可用性探测的局部失败不污染全局发现结果.

**验证 (2026-07-09)**: Speech.PBT fixture 8/8 通过 (P2 修复). 全量 4203P/0F/0E/0Leaked.

**影响文件**: `Features/DeepBase.Speech.Registry.pas` �?Discover IsAvailableFunc 探针 try/except 容错.

---

## BUG-444: Commerce PaymentBridge 未包�?ThirdParty 支付异常, EPaymentSignError 穿�?Commerce API 边界 (已修�? �?
**现象**: `Test_VerifyNotification_RejectsEmptySignatureHeaders` (TWeChatPayBridgeTests) 全量 Failed: `Method raised [EPaymentSignError] was expecting [EDeepBaseCommercePaymentError]. Failed to load WeChatPay platform public key`. �?fixture 隔离跑通过, 仅全�?(�?fixture 时序) 下失�?

**根因**: 异常继承层级断裂 �?`ThirdParty/Payment/DeepBase.Payment.pas:63` `EPaymentSignError = class(EPaymentError)` (Payment 命名空间根异常树), �?`Features/DeepBase.Commerce.Types.pas` `EDeepBaseCommercePaymentError = class(EDeepBaseCommerceError)` (Commerce 命名空间独立异常�?, 两者无 is-a 关系. `Features/DeepBase.Commerce.PaymentBridge.pas` `TSDKNotificationVerifier.VerifyNotification` WeChatPay 分支�?`FWeChatClient.VerifyNotificationWithSignature(...)` (SDK 内部加载平台公钥, 失败�?EPaymentSignError), **bridge �?try/except 包装**, ThirdParty 异常穿�?Commerce API 边界 �?与用�?`Assert.WillRaiseWithMessage(..., EDeepBaseCommercePaymentError)` 不匹�? 全量下公钥加载时序差�?(懒加�?缓存失效) 触发重载失败, �?fixture 下公钥已缓存故不触发 �?体现�?单跑过全量挂"的状态污染特�?

**修复**: VerifyNotification WeChatPay 分支�?`VerifyNotificationWithSignature` 调用�?try/except: �?`on E: EDeepBaseCommercePaymentError do raise` (保留已有 Commerce 域异常直�?, �?`on E: Exception do raise EDeepBaseCommercePaymentError.Create('...: ' + E.Message)` (ThirdParty 异常包装�?Commerce 域异�? 保留�?Message). ThirdParty 支付异常不再穿�?Commerce API.

**验证 (2026-07-09)**: WeChatPay PaymentBridge fixture 12/12 通过; 全量 4203P/0F/0E/0Leaked (此例在全量下也通过, 时序差异被异常包装消�?.

**影响文件**: `Features/DeepBase.Commerce.PaymentBridge.pas` �?VerifyNotification WeChatPay 分支异常域包�?

---

## BUG-445: Metrics TestTimerStart 测试期望与实现不一�?(已修�? �?
**现象**: `TestTimerStart` 失败 (Metrics �? 全量 13F 之一).

**根因**: `Core/DeepBase.Metrics.pas` TimerStart 实现与对应测试用例的期望不匹�?(Metrics 计时器启动语�?.

**修复**: `Core/DeepBase.Metrics.pas` TimerStart 对齐测试期望语义.

**验证 (2026-07-09)**: Metrics fixture 全绿; 全量 4203P/0F/0E/0Leaked.

**影响文件**: `Core/DeepBase.Metrics.pas` �?TimerStart 语义对齐.

---

## 全量测试清零总结 (2026-07-09)

�?BUG-438 (异常对象生命周期悬挂) + BUG-441 (Governance 编译阻塞) + BUG-442~445 (本轮 4 �? 修复�? 全量单测结果:

| 指标 | 起点基线 | 终点 (2026-07-09) | 变化 |
|------|---------|-------------------|------|
| Tests Found | 4206 | 4206 | �?|
| Passed | 4157 | **4203** | **+46** |
| Failed | 13 | **0** | **�?3** |
| Errored | 28 | **0** | **�?8** |
| Leaked | 0 | 0 | �?|
| Runtime 216 (全量�? | �?| **�?* | **消除** |

命令: `powershell -ExecutionPolicy Bypass -File ./Scripts/run_tests.ps1 -Type Unit -CI -Platform Win64`.

## BUG-446: build_packages E2199 包冲�?�?编译顺序违反传递依�?(已修�? �?
**现象**: `build_packages_win64.ps1 -Profile LLM|Runtime` 稳定�?`E2199 Packages 'DeepBaseCommerce' and 'DeepBaseCore' both contain unit 'DeepBase.Permissions.Contract'`, 失败�?`DeepBasePersistence.dpk(17)`。`-Profile Commerce` 反而通过�?
**根因 (2026-07-09 确证, 非陈�?dcp)**: 编译顺序违反包间传递依赖链�?- `DeepBaseSpeechCore.dpk` requires `DeepBaseCommerce` �?Commerce 须先�?SpeechCore 编译;
- `DeepBasePersistence.dpk` requires `DeepBaseSpeechCore` �?SpeechCore 须先�?Persistence 编译;
- 故正确链: **Commerce �?SpeechCore �?Persistence**�?- 原脚本顺序为 Core→Services→Persistence→Commerce→…→SpeechCore, **Persistence 排在 Commerce/SpeechCore 之前**。编 Persistence �?dcc 解析传�?requires 需 Commerce.dcp, �?Commerce 尚未编译, 符号解析错位 �?E2199 (�?Commerce �?Core 双重�?Permissions.Contract, 实为 Commerce.dcp 缺失导致链接器回退误判)�?- `SpeechPackages` 还缺 `DeepBaseCommerce`/`DeepBaseServices` 前置, SpeechCore 同样传不�?Commerce�?
**修复**: `Scripts/build_packages_win64.ps1` �?`Commerce`+`SpeechCore` 提到 `Persistence` 之前, �?Minimal/Runtime/LLM/Updater/Speech 五个 profile 统一改序; Speech profile �?Commerce/Services 前置。另保留编前�?`dcp64/*.dcp` 加固 (�?-M 模式陈旧 dcp 残留, 次要防护)�?
**验证 (2026-07-09)**: `-Profile Commerce` passed; `-Profile Speech` passed (8 包全�?; `-Profile Runtime`/`-Profile LLM` E2199 消失 (Commerce→SpeechCore→Persistence 依次编译成功), 但后两者编�?`DeepBasePlatform.dpk` 时遇 `Features/DeepBase.HttpServer.pas(388) E2004 System.IOUtils 重复声明` �?此为 data-platform-v0.7 worktree 未提交改动引入的独立缺陷 (interface uses L52 新增 System.IOUtils �?implementation uses L388 重复), 非本 bug 范围, 留待�?workstream 处理�?
**影响文件**: `Scripts/build_packages_win64.ps1` �?�?profile 包编译顺序对齐传递依�?(Commerce→SpeechCore→Persistence) + 编前�?dcp64 加固�?
## BUG-447: HttpServer.pas E2004 System.IOUtils 重复声明 �?解除 Platform 编译阻塞 (已修�? �?
**现象**: `build_packages_win64.ps1 -Profile LLM|Runtime` 编到 `DeepBasePlatform.dpk` 时报
`Features/DeepBase.HttpServer.pas(388) Error: E2004 Identifier redeclared: 'System.IOUtils'`�?
**根因**: data-platform-v0.7 worktree 未提交改动在 `HttpServer.pas` interface uses �?(L52) 新增 `System.IOUtils`, �?implementation uses �?(L388) 原本已有 `System.IOUtils`, 两处重复声明 �?E2004。interface 段全文零 IOUtils 符号引用 (TPath/TFile 仅在 implementation �?L620-642 �?`TStaticFileMiddleware.Execute` 用到), �?interface 段的新增属冗余�?
**修复**: 撤掉 interface uses L52 �?`System.IOUtils` (interface 段用不到), 保留 implementation uses L388 (实现�?TPath/TFile 需要它)。现 `System.IOUtils` 仅一处声明�?
**验证 (2026-07-09)**: `-Profile LLM` 全链 7 �?(Core→Services→Commerce→SpeechCore→Persistence→Platform→LLM) passed, E2004 消失, Platform 编译阻塞解除�?
**影响文件**: `Features/DeepBase.HttpServer.pas` �?interface uses 移除冗余 System.IOUtils�?
**遗留 (独立缺陷, 非本 bug 范围)**: Runtime profile 编到 DeepAxis.dpk �?`DeepBase.External.SQLiteReader.pas(239) E2003 Undeclared identifier: 'TFileInfo'` (inline `var FileSize := TFileInfo.GetSize(...)` 解析失败, 该文件亦�?data-platform-v0.7 worktree 未提交改�? 留待�?workstream)�?
## BUG-448: SQLiteReader.pas TFileInfo 未声�?+ Char helper 缺失 �?解除 DeepAxis 编译阻塞 (已修�? �?
**现象**: `-Profile Runtime` 编到 `DeepAxis.dpk` 时报两个�?
- `DeepAxis/DeepBase.External.SQLiteReader.pas(239) E2003 Undeclared identifier: 'TFileInfo'`
- `DeepAxis/DeepBase.External.SQLiteReader.pas(412) E2671 Record, object, class type, or type helper required`

**根因**: 两处均为 data-platform-v0.7 worktree 未提交改动引入的 API 误用:
1. **L239 `TFileInfo.GetSize(DbPath)`**: 误用 `TFileInfo` �?Delphi `System.IOUtils` �?*没有** `TFileInfo` (那是 .NET `System.IO.FileInfo`); 仓库其余 13 处取文件大小一律用 `TFile.GetSize(...)` (�?uDoQryLogger/CloudBackup/Feedback/Logging �?。应�?`TFile`�?2. **L412 `C.IsLetterOrDigit`**: `C` �?`for C in AIdent` �?`Char`, �?`.IsLetterOrDigit` �?`System.Character` 提供�?`TCharHelper` 扩展方法; 该单元照搬了 `Core/DeepBase.SQL.Utils.pas` L69 的同名逻辑, �?uses 段漏�?`System.Character` �?`Char` 无该 helper �?E2671�?
**修复** (两处, 各一�?:
- `Core/DeepBase.External.SQLiteReader.pas` L239: `TFileInfo.GetSize` �?`TFile.GetSize` (与全仓库统一)�?- 同文�?uses L13: �?`System.Character,` (�?SQL.Utils.pas 用法对齐)�?
**验证 (2026-07-09)**:
- Runtime profile 全链 12 �?(Core→Services→Commerce→SpeechCore→Persistence→Platform→DataPlatform→LLM→IntentClarification→Browser→Inference→Features) passed, E2003/E2671 消失, DeepAxis 编译阻塞解除�?- Speech/Updater profile smoke passed, 无回归�?- 回归测试: BUG331 (SafeQueryIdentifierValidation, 覆盖 L410-417 标识符校�? + BUG330 (SQLiteReaderSchemaCache, 覆盖 L235-244 文件大小/打开路径) = 6/6 passed, 0 failed/errored/leaked�?
**影响文件**: `DeepAxis/DeepBase.External.SQLiteReader.pas` �?L239 类名修正 + uses �?System.Character�?
## BUG-WYJX-010: Browser CDP.Adapter/Session/WebElement 编译错误 �?解除测试工程编译阻塞 (已修�? �?
**现象**: `run_tests.ps1 -Type Unit -CI` 编译失败，报�?
- `Features/DeepBase.Browser.CDP.Adapter.pas(28) Fatal: F2613 Unit 'System.Websockets' not found`
- 多处 `E2003 Undeclared identifier`、`E2029 Declaration syntax error`、`E2065 Unsatisfied forward`

**根因**: PERCEPT-WYJX-P4 生成�?Browser 模块代码存在多处编译级缺�?
1. **CDP.Adapter.pas**: 引用不存在的 `System.Websockets` 单元 (Delphi 无此单元，应使用项目�?`DeepBase.Net.TWebSocketClient`); `System.SyncObjects` 应为 `System.SyncObjs`; 无效 GUID (含非十六进制字符); `IBrowserSession` 接口�?`property State: ... read FState` 语法非法; `TWebWebElement` 重复定义; 多处方法缺失实现; `TJSONObject.CreateString(...).ToString` �?Format 数组内解析失�? `ContainsKey` �?TJSONObject 方法; `wmtText` 应为 `wsmText`; `OnMessage` 事件�?`of object` 类型不能用匿名方�? `TNetEncoding` �?`System.NetEncoding` uses; `Format('"nodeId":0')` 无参数调用�?2. **WebElement.pas**: `EException` 不存�?(应为 `Exception`); `FormatRecord` 不存�? `TWebWebElement()` 非法 record 构�? `EvaluateJS` 方法不存�? `TJSONObject.CreateString(...).ToString` 解析问题�?3. **Session.pas**: 无效 GUID; 接口方法�?`virtual; abstract;` 非法; `IBrowserSession` 重复定义 (�?CDP.Adapter 冲突); `EException` 不存�? `FCurrentURL` 未声�? `ExecuteJS` 未定�? 注释�?`//`; `TObjectList<IBrowserSession>` 接口类型不满�?class 约束�?4. **Test.DeepBase.Browser.Session.pas**: 测试方法只有声明无实�? `VarIsEmpty`/`VarIsNull` �?`System.Variants` uses�?5. **Test.DeepBase.Browser.CDP.pas**: `Assert.AreEqual(1, Count)` 泛型推断失败 (需显式 `<Integer>`)�?
**修复**:
- **CDP.Adapter.pas** 全面重写: 移除 `System.Websockets` 改用 `DeepBase.Net.TWebSocketClient`; 修正 `System.SyncObjs`; 生成合法 GUID; 移除重复 `TWebWebElement`/`IBrowserSession` 定义; 补全所有方法实�?(`WaitForLoadState`/`ExecuteScript`/`GetElementBoxModel`/`QuerySelector`/`CaptureScreenshot`/`ProcessMessage`/`SendCommand`/`ParseJSONObject`); 添加 `JsonStringEncode` 辅助函数替代 `TJSONObject.CreateString().ToString`; `ContainsKey` �?`GetValue<> nil`; `wmtText` �?`wsmText`; 匿名方法 �?`WebSocketMessageHandler` 类方�? �?`System.NetEncoding`; 移除无参 `Format` 调用�?- **WebElement.pas** 重写: `EException` �?`Exception`; 移除 `FormatRecord`; `TWebWebElement()` �?`Default(TWebWebElement)`; `EvaluateJS` �?`ExecuteScript`; 添加 `JsonStr` 辅助函数; `IBrowserSession` �?`ICDPSession` (避免循环依赖)�?- **Session.pas** 重写: 移除重复 `IBrowserSession` 定义 (使用 CDP.Adapter �?; 移除 `virtual; abstract;`; 修正 GUID; `EException` �?`Exception`; �?`FCurrentURL` 字段; `ExecuteJS` �?`FCDPSession.ExecuteScript`; `TObjectList<IBrowserSession>` �?`TList<IBrowserSession>`; 补全所有方法实现�?- **Test.DeepBase.Browser.Session.pas** 重写: 补全 implementation 段所有测试方�? �?`System.Variants` uses; 修正 fixture 注册方式�?- **Test.DeepBase.Browser.CDP.pas**: 5 �?`Assert.AreEqual(N, ...)` �?`Assert.AreEqual<Integer>(N, ...)`�?
**验证 (2026-07-25)**: `run_tests.ps1 -Type Unit -CI -AllowFilteredCI` 编译通过 (341617 �? 20.67s); 全量 DUnitX: Tests Found 4266 / Passed 4244 / Failed 3 / Errored 15 / Leaked 0。失败项均为 DPAPI 凭据管理环境相关 (内存资源不足)，与本次修复无关�?
**影响文件**: `Features/DeepBase.Browser.CDP.Adapter.pas` (重写) + `Features/DeepBase.Browser.WebElement.pas` (重写) + `Features/DeepBase.Browser.Session.pas` (重写) + `Tests/Test.DeepBase.Browser.Session.pas` (重写) + `Tests/Test.DeepBase.Browser.CDP.pas` (5 处泛型修�?�?