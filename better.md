# UniBase 改进任务清单

> 基于代码审查生成的开发任务，按优先级排序。
> 创建日期: 2025-11-28

---

## P0 - 严重问题（立即修复）

### 1. [BUG] DoQry 内存泄漏修复 ✅ 已完成
**文件**: `Core/UniBase.DB.DoQry.pas`
**问题**: TFDQuery 对象在 try 块外释放，异常时会泄漏
**完成日期**: 2025-11-28

**修复内容**: 将 4 个函数的 `Q.Free` 移入 `finally` 块
- `UniDbSelect` - 已修复
- `UniDbExec` - 已修复
- `UniDbInsertReturningId` - 已修复
- `UniDbScalar` - 已修复

---

## P1 - 重要问题（本周内修复）

### 2. [BUG] 空 except 块添加日志 ✅ 已完成
**文件**: 多处
**问题**: 异常被吞没，难以排查问题
**完成日期**: 2025-11-28

**修复内容**:
- Manager.pas: ReadRootTxt/WriteRootTxt - 添加 Logger.Warn
- Logging.pas: WriteToFile - 使用 OutputDebugString（避免递归）
- i18n.pas: RecordMissingTranslation - 使用 OutputDebugString（避免循环依赖）
- Theme.pas: LoadThemeCache - 使用 OutputDebugString

### 3. [SECURITY] 配置加密安全性文档 ✅ 已完成
**文件**: `Core/UniBase.Config.pas`
**问题**: XOR 加密强度不足，需明确安全边界
**完成日期**: 2025-11-28

**修复内容**:
- 添加详细的安全警告注释（25行）
- 明确说明 XOR 仅提供混淆而非加密
- 列出适用/不适用场景
- 提供更安全方案的建议（DPAPI/AES/Keychain）
- 更新 GetConfigEncrypted/SetConfigEncrypted 的 XML 文档

---

## P2 - 中等问题（两周内处理）

### 4. [REFACTOR] Schema SQL 外部化 ✅ 已完成
**文件**: `Core/UniBase.Schema.pas` (新建)
**问题**: 200+ 行 SQL 硬编码在 CreateSchema 方法中
**完成日期**: 2025-11-28

**修复内容**:
- 新建 `Core/UniBase.Schema.pas` 单元
- SQL 定义分为 Tier0/Tier1/Tier2 常量
- 提供 `GetTier0SchemaSQL/GetTier1SchemaSQL/GetTier2SchemaSQL/GetFullSchemaSQL` 函数
- `Manager.CreateSchema` 改用 `GetFullSchemaSQL()`

### 5. [FEATURE] MRU 模块 ✅ 已存在
**文件**: `Core/UniBase.MRU.pas`
**状态**: 模块已实现，更新了 Schema 支持 IsPinned 字段
**完成日期**: 2025-11-28

**已实现功能**:
- `AddMRU`, `GetMRUList`, `GetMRUItems`
- `ClearMRU`, `RemoveMRU`, `RemoveInvalidMRU`
- `SetPinned`, `IsPinned` 置顶功能
- `GetMRUCount`, `GetAccessCount` 统计功能

### 6. [REFACTOR] DoQry 从 queries 表加载 SQL ✅ 已完成
**文件**: `Core/UniBase.DB.DoQry.pas`, `Core/UniBase.Schema.pas`
**问题**: 当前 ProcName 直接作为 SQL 使用
**完成日期**: 2025-11-28

**修复内容**:
- 添加 `Queries` 表到 Schema (Tier1)
- 实现 `LoadQuerySQL(ProcName, Ctx)` 带缓存
- 实现 `IsDirectSQL()` 判断 SQL 关键字
- 实现 `UniDbClearQueryCache()` 清除缓存
- 所有 UniDb* 函数更新使用 `LoadQuerySQL`
- 向后兼容：直接 SQL 仍然支持

### 7. [REFACTOR] Logger 初始化改进 ✅ 已完成
**文件**: `Core/UniBase.Logging.pas`, `Core/UniBase.Manager.pas`
**问题**: Logger 懒加载时没有 DBPath
**完成日期**: 2025-11-28

**修复内容**:
- 添加 `SetGlobalLogger(ALogger)` 过程
- 添加 `IsLoggerInitialized()` 检查函数
- `Logger()` 未初始化时返回文件日志模式
- Manager.InitializeModules 调用 `SetGlobalLogger`

---

## P3 - 建议改进（按需处理）

### 8. [REFACTOR] 核心模块接口抽象 ✅ 已完成
**文件**: `Core/UniBase.Interfaces.pas` (新建)
**目标**: 提高可测试性和可替换性
**完成日期**: 2025-11-28

**已创建接口** (192行):
- `IUniBaseConfig` - 配置管理接口
- `IUniBaseLogger` - 日志接口
- `IUniBaseI18n` - 国际化接口
- `IUniBaseMRU` - MRU 接口
- `IUniBaseManager` - 管理器接口

**后续**: 各模块可逐步实现这些接口

### 9. [FEATURE] 运行时日志级别配置 ✅ 已完成
**文件**: `Core/UniBase.Consts.pas`, `Core/UniBase.Manager.pas`
**需求**: 通过 Settings 表动态调整日志级别
**完成日期**: 2025-11-28

**修复内容**:
- 添加 `SConfigKeyLogLevel` 和 `SConfigKeyLogStorageMode` 常量
- `InitializeModules` 从 Settings 读取并设置日志级别
- `HandleConfigChanged` 响应日志级别变更（热更新）

### 10. [STYLE] 常量命名规范统一 ✅ 已完成
**文件**: `Core/UniBase.Consts.pas`
**问题**: 需要明确命名规范
**完成日期**: 2025-11-28

**修复内容**:
- Consts.pas 已统一使用 `S` 前缀风格
- 添加详细的命名规范文档注释
- 记录各类前缀: SConfigKey*, SDefault*, STable*, etc.

### 11. [DOC] 版本兼容性检查 ✅ 已完成
**文件**: `Core/UniBase.Schema.pas`, `Core/UniBase.Manager.pas`
**需求**: 初始化时检查框架版本与 Schema 版本兼容
**完成日期**: 2025-11-28

**修复内容**:
- Schema 添加 `MIN_COMPATIBLE_SCHEMA_VERSION` 和 `MAX_COMPATIBLE_SCHEMA_VERSION`
- 添加 `ecSchemaVersionMismatch` 错误码
- 实现 `ValidateSchemaVersion` 方法
- `ValidateSchema` 中调用版本检查
- 版本过旧/过新时给出明确错误提示

### 12. [REFACTOR] 解耦 i18n 与 Manager 循环引用 ✅ 已完成
**文件**: `Core/UniBase.i18n.pas`, `Core/UniBase.Manager.pas`
**问题**: `UniBase.i18n` uses `UniBase.Manager`
**完成日期**: 2025-11-28

**修复内容**:
- 移除 i18n 对 Manager 的直接引用
- 添加 `SetGlobalTranslateCallback` 回调模式
- 添加 `IsTranslateCallbackSet` 检查函数
- Manager.InitializeModules 设置翻译回调
- T() 函数未初始化时返回原文

---

## 测试任务

### 13. [TEST] 单元测试 ✅ 已存在
**状态**: 测试文件已完善

**已有测试**:
- `Test.UniBase.Config.pas` - 18 个测试用例
- `Test.UniBase.Logging.pas` - 13 个测试用例
- `Test.UniBase.i18n.pas` - 12 个测试用例
- `Test.UniBase.DB.DoQry.pas` - 10 个测试用例
- `Test.UniBase.MRU.pas` - MRU 测试

---

## 任务统计

| 优先级 | 数量 | 状态 |
|--------|------|------|
| P0 | 1 | ✅ 已完成 |
| P1 | 2 | ✅ 已完成 |
| P2 | 4 | ✅ 已完成 |
| P3 | 5 | ✅ 已完成 |
| TEST | 1 | ✅ 已存在 |

---

## 更新日志

- **2025-11-28**: 初始版本，基于代码审查创建
- **2025-11-28**: 完成 P0 - DoQry 内存泄漏修复
- **2025-11-28**: 完成 P1-1 - 空 except 块添加日志（5处）
- **2025-11-28**: 完成 P1-2 - 配置加密安全性文档
- **2025-11-28**: 完成 P2-1 - Schema SQL 外部化（新建 UniBase.Schema.pas）
- **2025-11-28**: 完成 P2-2 - MRU 模块确认已实现，更新 Schema
- **2025-11-28**: 完成 P2-3 - DoQry 支持从 Queries 表加载 SQL
- **2025-11-28**: 完成 P2-4 - Logger 初始化改进（SetGlobalLogger）
- **2025-11-28**: 完成 P3-9 - 运行时日志级别配置
- **2025-11-28**: 完成 P3-11 - 版本兼容性检查
- **2025-11-28**: 完成 P3-10 - 常量命名规范文档
- **2025-11-28**: 完成 P3-12 - i18n 与 Manager 解耦
- **2025-11-28**: TEST - 确认测试文件已完善
- **2025-11-28**: 完成 P3-8 - 创建接口定义单元 UniBase.Interfaces.pas
