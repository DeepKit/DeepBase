# 数据平台 v0.7 交接说明 — 2026-06-16

**撰写**: Claude (fuyi4it 的结对编程助手)
**提交**: `a769c56` — data platform v0.7: 12 units, 3 packages compile-clean, dual decrypt backend, tests

---

## 一、本次完成的工作

提交了数据平台 v0.7 的全部代码，65 个文件变更，+3980/-1031 行。

### 新增 12 个 Pas 单元

| 文件 | 层 | 说明 |
|------|-----|------|
| `Core/DeepBase.External.Types.pas` | Core | TSQLCipherCompatibilityConfig, TColumnInfo, TTableInfo, TExternalDBSchema, TBodyZeroReport, TKeyCandidate, IsWriteStatement |
| `Core/DeepBase.External.Auditor.pas` | Core | TBodyZeroAuditorImpl — 列访问审计 + 写入拦截 + 故障隔离 |
| `Core/DeepBase.SchemaAdapter.Types.pas` | Core | TFieldMapping, TDirection, TNormalizedMsgType, TMapResult, FieldMap 工厂 |
| `Core/DeepBase.SchemaAdapter.pas` | Core | ISchemaAdapter, TBaseSchemaAdapter — MapRow/MapRows 带 per-row 错误隔离, 懒加载缓存的 MapDirection/MapMessageType |
| `Core/DeepBase.SchemaAdapter.Registry.pas` | Core | ISchemaAdapterRegistry — 指纹+版本双重匹配 |
| `Core/DeepBase.SchemaAdapter.WeChat39x.pas` | Core | WeChat 3.9.x 联系人+聊天完整 schema 映射 |
| `Persistence/DeepBase.External.SQLiteReader.pas` | Persistence | FireDAC 只读 SQLCipher 读取器 — SafeQuery/SafeQueryAsDict, schema 指纹, body-zero 审计集成 |
| `Persistence/DeepBase.External.BCryptDecrypt.pas` | Persistence | TBCryptSQLiteReader (320 LOC) — PBKDF2-HMAC-SHA1 密钥派生, AES-CBC 逐页解密+HMAC 验证, cipher 参数探测 |
| `Features/DeepBase.ClipboardGuard.pas` | Features | RAII 剪贴板保护 — 三级备份降级, SendInput Ctrl+V + wScan, 大格式文件映射 fallback |
| `Features/DeepBase.WindowMonitor.pas` | Features | SetWinEventHook 前景窗口检测 — 速率限制回调, TThreadList 线程安全, 30s fallback 轮询, hook 健康检查 |
| `Features/DeepBase.UIA.Types.pas` | Features | TUIAElementLocator, TUIAMapping, TUIAMappingRegistry |
| `Features/DeepBase.UIA.Engine.pas` | Features | IUIAElementFinder + IUIAValueOperator + IUIAMappingProvider — FindElement 三策略 fallback, 剪贴板粘贴+验证, 元素归属反欺骗 |
| `Features/DeepBase.DataPlatform.Bootstrap.pas` | Features | 数据平台服务 composition root |

### 基础设施修改

- `Core/DeepBase.Exceptions.pas` — 新增 13 个异常类 (EExternalDBError, EClipboardError, EUIAEngineError 等)
- `DeepBase.ORM.pas` — 从 Core 移至 Persistence 层
- 5 个新的 .dpk 包 (Browser/Commerce/Inference/IntentClarification/LLM) 已注册
- `DeepBaseFeatures.dpk` 重构 — 新增 requires DeepBaseServices + DeepBasePersistence
- 包 DAG: Core → Services → {Persistence, Features} → {VCL, FMX}

### 测试

- `Tests/Test.DeepBase.DataPlatform.pas` — SchemaAdapter 16 用例, ClipboardGuard 6 fixtures, SQLiteReader 集成测试

---

## 二、剩余任务

### DATA-P0-001: 微信运行时密钥偏移确认 (阻塞项)

**状态**: 需要你（同事）来完成 — 被阻塞，需要微信 4.1.10.30 + 管理员权限。

**背景**: 我们已经实现了 BCrypt 直接解密后端 (`TBCryptSQLiteReader`) 和密钥扫描框架 (`TKeyCandidate` / `ScanForKeyByEntropy`)，但**微信进程内存中的具体密钥偏移地址**需要在有微信运行的目标机器上用探针确认。

**需要你做**:
1. 在有微信 4.1.10.30 运行的机器上，以管理员权限执行 `WxDecryptProbe.exe`（或手动编写探针）
2. 扫描 WeChatWin.dll 内存空间，找到高熵 32 字节密钥候选
3. 将确认的偏移值回填到 `KeyCallback` 的 `KnownOffsets` 列表
4. 解密 MicroMsg.db 后导出 MSG 表列名列表，更新 `TWeChat4xAdapter` 的 Schema 指纹前缀

### ARCH-P1-002: Platform/Features dpk 预存编译错误

**状态**: 与数据平台工作无关，是同事模块拆分引入的

**错误**:
- `DeepBasePlatform.dpk`: `DeepBase.Desktop.Lifecycle.pas(7)` → `Unit 'DeepBase.Commerce.Permissions' not found`
- 修复: Platform 的 `requires` 增加 `DeepBaseCommerce`

---

## 三、关键项目上下文

### 包编译顺序

```
Core → Services → Persistence → Features → Platform → VCL/FMX
```

### 当前编译状态

| 包 | 状态 |
|----|------|
| DeepBaseCore.dpk | ✅ 0 errors |
| DeepBaseServices.dpk | ✅ 0 errors |
| DeepBasePersistence.dpk | ✅ 0 errors |
| DeepBaseFeatures.dpk | ❌ 预存错误 (级联自 Platform) |
| DeepBasePlatform.dpk | ❌ 预存错误 (Commerce.Permissions 引用缺失) |

### 任务跟踪文件

- `tasks.md` — 当前待办
- `history.md` — 已完成任务归档
- `bugfix.md` — Bug 修复记录 (BUG-252~BUG-268 是数据平台相关的)
- `docs/32-36/` — 设计规格文档

### 设计文档

5+1 份设计文档 (docs/32-36) 经历了 15 位专家审查:
- R1 (5 experts): 安全/加密/COM/Delphi实现/威胁建模
- R2 (5 experts): 威胁/并发/容错/性能/测试
- R3 (4 experts): 集成/可测试/实现就绪/代码审计
- R4 (1 expert): 生命周期完整性

---

## 四、给你同事的备注

1. **微信密钥偏移**是当前唯一阻塞数据平台上线的事情。BCrypt 后端和密钥扫描框架都已经就绪，只需要确认运行时的真实偏移值。

2. **预存 dpk 错误** (ARCH-P1-002) 不是我们引入的，但会影响整个 Features 和 Platform 包的编译。如果你有时间修掉它，整个项目就能完整编译了。

3. 测试文件在 `Tests/Test.DeepBase.DataPlatform.pas`，包含 SchemaAdapter、ClipboardGuard 和 SQLiteReader 的测试用例。跑测试需要先编译 Core 和 Persistence 包。

4. 如果需要了解数据平台的设计细节，入口是 `docs/32.data.SQLCipher外部数据库读取-开发规格.md`，这 5 份文档包含完整的设计决策和专家审查历史。

---

**撰写日期**: 2026-06-16
**关联提交**: `a769c56`