# UniFlow Bug 修复记录

> 记录开发过程中发现和修复的 Bug

---

## Bug 记录格式

```
### BUG-XXX: 简短描述
- **发现日期**: YYYY-MM-DD
- **修复日期**: YYYY-MM-DD
- **严重程度**: Critical / High / Medium / Low
- **影响范围**: 模块/功能
- **问题描述**: 详细描述
- **根本原因**: 原因分析
- **修复方案**: 如何修复
- **相关文件**: 涉及的文件
```

---

## 已修复 Bug

### BUG-001: Source 目录未持久化
- **发现日期**: 2024-12-05
- **修复日期**: 2024-12-05
- **严重程度**: Medium
- **影响范围**: 项目结构
- **问题描述**: 上一轮会话创建的 Source 目录和文件未被保存，新会话启动时目录不存在
- **根本原因**: 会话中断导致文件系统操作未完成
- **修复方案**: 重新创建目录结构和所有源文件
- **相关文件**: `Source/Workflow/*.pas`

---

## 待修复 Bug (Delphi 12)

以下 3 个模块需要较大重构，暂缓修复：

### BUG-038: Graph.pas 泛型类中的本地过程
- **发现日期**: 2025-12-05
- **严重程度**: High
- **影响范围**: UniBase.Graph.pas
- **问题描述**: TTree.Traverse 等方法中包含本地过程，触发 NI19024 错误
- **预计工作量**: 大 - 需要重构多个方法

### BUG-039: Net.pas Indy DNS API 变更
- **发现日期**: 2025-12-05
- **严重程度**: High
- **影响范围**: UniBase.Net.pas
- **问题描述**: QueryTimeout/QueryRecords/qtCNAME/TCNAMERecord 在新版 Indy 中不存在
- **预计工作量**: 大 - 需要重写 DNS 查询功能

### BUG-040: Serialization.pas 接口泛型方法限制
- **发现日期**: 2025-12-05
- **严重程度**: High
- **影响范围**: UniBase.Serialization.pas
- **问题描述**: E2535 Interface methods must not have parameterized methods
- **预计工作量**: 大 - 需要重新设计 ISerializer 接口架构

---

## Bug 统计

| 严重程度 | 已修复 | 待修复 | 合计 |
|----------|--------|--------|------|
| Critical | 0 | 0 | 0 |
| High | 6 | 3 | 9 |
| Medium | 5 | 0 | 5 |
| Low | 0 | 0 | 0 |
| **合计** | **11** | **3** | **14** |

---

## 回归测试清单

完成 Bug 修复后，应执行以下回归测试：

- [ ] Workflow 定义加载测试
- [ ] 变量引用解析测试
- [ ] 步骤执行流程测试
- [ ] 状态持久化测试
- [ ] 错误处理测试
