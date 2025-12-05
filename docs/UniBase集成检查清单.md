# UniBase 集成检查清单

> 版本: 1.0.0  
> 适用于: 集成 UniBase 框架的应用程序

本清单帮助您在发布应用程序前验证 UniBase 集成是否正确。

---

## 第一步：初始化检查

### 1.1 数据库文件
- [ ] 数据库文件路径配置正确
- [ ] 首次运行成功创建数据库
- [ ] 数据库文件编码为 UTF-8
- [ ] 数据库文件具有读写权限

### 1.2 Schema 验证
- [ ] `SchemaInfo` 表存在且有版本记录
- [ ] 运行 `DiagnoseAll` 无错误或已修复

```pascal
// 诊断示例代码
uses UniBase.Diagnose;

var
  Results: TDiagnoseResults;
begin
  Results := DiagnoseAll(ConfigDB);
  if Length(Results) > 0 then
  begin
    // 显示诊断报告
    ShowMessage(GenerateDiagnoseReport(Results));
    // 自动修复
    AutoFix(ConfigDB, Results);
  end;
end;
```

---

## 第二步：基础功能测试

### 2.1 Settings（设置）
- [ ] 读取设置正常: `GetSetting('App.Language')`
- [ ] 写入设置正常: `SetSetting('App.Theme', 'Windows11')`
- [ ] 设置值类型转换正确（String/Integer/Boolean/Float）
- [ ] 加密设置可正常存取

### 2.2 FormStates（窗口状态）
- [ ] 窗口位置保存正确
- [ ] 窗口位置恢复正确
- [ ] 多显示器环境窗口位置正确
- [ ] 最大化/最小化状态恢复正确
- [ ] 分隔条位置保存/恢复正确（如适用）

### 2.3 i18n（多语言）
- [ ] 语言切换正常
- [ ] 翻译文本显示正确
- [ ] 中文和特殊字符显示正常（UTF-8）
- [ ] 未翻译文本回退到默认语言

### 2.4 Logs（日志）
- [ ] 日志记录正常
- [ ] 日志级别过滤正常
- [ ] 异常日志包含堆栈跟踪
- [ ] 日志查询/导出正常

### 2.5 MRU（最近使用）
- [ ] 最近打开的文件记录正常
- [ ] 列表排序正确（最近在前）
- [ ] 置顶功能正常
- [ ] 列表数量限制生效

---

## 第三步：LLM 功能测试（如使用）

### 3.1 Provider 和 Model
- [ ] Provider 列表加载正常
- [ ] Model 列表加载正常
- [ ] 自定义 Provider 配置正常

### 3.2 API Key 管理
- [ ] API Key 存储正常
- [ ] API Key 读取正常
- [ ] 加密存储有效（DPAPI/AES）
- [ ] 了解换机器后 DPAPI 密钥失效的限制

### 3.3 LLM 调用
- [ ] 实际调用 LLM 成功
- [ ] 调用历史记录正常（LLMCalls 表）
- [ ] Token 统计正确
- [ ] 错误处理正常

### 3.4 Prompt 模板
- [ ] 模板加载正常
- [ ] 变量替换正常
- [ ] 自定义模板保存/加载正常

---

## 第四步：边界测试

### 4.1 字符编码
- [ ] 中文内容存储正常
- [ ] 日文/韩文等多语言内容正常
- [ ] 特殊字符（emoji等）处理正常
- [ ] 超长文本（>10KB）存储正常

### 4.2 空值处理
- [ ] NULL 值查询不报错
- [ ] 空字符串和 NULL 区分正确
- [ ] 必填字段缺失时有友好提示

### 4.3 并发访问
- [ ] 多窗口同时读取正常
- [ ] 多窗口同时写入无冲突（WAL 模式）
- [ ] 数据库锁定时有友好提示

### 4.4 性能测试
- [ ] 大数据量（>10000条）查询性能可接受
- [ ] 批量插入性能可接受
- [ ] 内存占用在合理范围

---

## 第五步：升级测试

### 5.1 从旧版本升级
- [ ] 旧版本数据库升级成功
- [ ] 升级后数据完整
- [ ] 升级后功能正常
- [ ] 新增表/字段自动创建

### 5.2 回退测试
- [ ] 升级失败时数据不丢失
- [ ] 可回退到备份

---

## 第六步：发布前清理

### 6.1 移除不需要的表
```sql
-- 如果不用 LLM 功能，可删除以下表
DROP TABLE IF EXISTS LLMCalls;
DROP TABLE IF EXISTS LLMPrompts;
DROP TABLE IF EXISTS LLMApiKeys;
DROP TABLE IF EXISTS LLMConfig;
DROP TABLE IF EXISTS Models;
DROP TABLE IF EXISTS Providers;

-- 如果不用标签功能
DROP TABLE IF EXISTS TagMappings;
DROP TABLE IF EXISTS Tags;
```

### 6.2 清理测试数据
- [ ] 删除测试日志
- [ ] 清除测试设置
- [ ] 重置为默认状态

### 6.3 最终验证
- [ ] 运行完整诊断无错误
- [ ] 数据库大小合理
- [ ] 所有功能正常

---

## 快速诊断命令

```pascal
// 一键诊断
var Results := DiagnoseAll(ConfigDB);
ShowMessage(GenerateDiagnoseReport(Results));

// 自动修复
AutoFix(ConfigDB, Results);

// 检查版本
var Version := GetSchemaVersion(ConfigDB);
ShowMessage('Schema Version: ' + Version);
```

---

## 相关文档

- [集成uniBase系统初始数据库和字段说明.md](集成uniBase系统初始数据库和字段说明.md)
- [UniBase常见错误速查.md](UniBase常见错误速查.md)
