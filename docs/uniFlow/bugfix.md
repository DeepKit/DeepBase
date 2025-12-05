# UniFlow Bug 修复记录

> 记录开发过程中发现和修复的 Bug
>
> 最后更新: 2025-12-05

---

## 已修复 Bug

### BUG-001: Source 目录未持久化
- **发现/修复日期**: 2024-12-05
- **严重程度**: Medium
- **影响范围**: 项目结构
- **问题描述**: 会话中断导致文件系统操作未完成
- **修复方案**: 重新创建目录结构和所有源文件

---

## Delphi 12 兼容性修复

> 共 78 个文件修复，详见 `../bugfix.md` 主文件

### 已修复模块

| 模块 | 修复内容 | 日期 |
|------|----------|------|
| UniBase.IoC.pas | PTypeInfo 本地变量, TValue.AsType<T> | 2025-12-05 |
| UniBase.StateMachine.pas | 本地过程重构为私有方法 | 2025-12-05 |
| UniBase.Diff.pas | TObjectList 改 TList (记录类型) | 2025-12-05 |
| UniBase.FileWatcher.pas | TEvent 替代 TTimer, TTask.Create | 2025-12-05 |
| UniBase.Template.pas | 内联变量声明, 属性访问器 | 2025-12-05 |
| UniBase.CloudSync.pas | HTTP 空请求体, TThread.Queue | 2025-12-05 |

### 常见修复模式

```pascal
// 1. TStringDynArray 缺少单元
uses System.Types;

// 2. 线程同步
TThread.Synchronize(nil, proc) → TThread.Queue(nil, proc)

// 3. 异步任务
TTask.Run(proc) → TTask.Create(proc).Start

// 4. 泛型类中本地过程 (E2570)
procedure TMyClass<T>.Method;
  function LocalFunc: string; // 禁止!
end;
→ 重构为私有类方法

// 5. 记录类型容器
TObjectList<TMyRecord> → TList<TMyRecord>

// 6. 记录属性 Inc
Inc(LRecord.Count) → 
  LCount := LRecord.Count; Inc(LCount); LRecord.Count := LCount;

// 7. 注释格式
{*...*} → (*...*)
```

---

## 待修复 Bug (Delphi 12)

> 以下 3 个模块需要较大重构，暂缓修复

### BUG-038: Graph.pas 泛型类中的本地过程
- **严重程度**: High
- **影响范围**: UniBase.Graph.pas
- **问题描述**: TTree.Traverse 等方法中包含本地过程，触发 NI19024 错误
- **预计工作量**: 大 - 需要重构多个方法
- **修复方案**: 将本地过程重构为私有方法或使用迭代实现

### BUG-039: Net.pas Indy DNS API 变更
- **严重程度**: High
- **影响范围**: UniBase.Net.pas
- **问题描述**: QueryTimeout/QueryRecords/qtCNAME/TCNAMERecord 在新版 Indy 中不存在
- **预计工作量**: 大 - 需要重写 DNS 查询功能
- **修复方案**: 使用 WaitingTime 替代 QueryTimeout，QueryType 替代 qtXXX

### BUG-040: Serialization.pas 接口泛型方法限制
- **严重程度**: High
- **影响范围**: UniBase.Serialization.pas
- **问题描述**: E2535 Interface methods must not have parameterized methods
- **预计工作量**: 大 - 需要重新设计 ISerializer 接口架构
- **修复方案**: 接口移除泛型方法，改用泛型类实现

---

## Bug 统计

| 严重程度 | 已修复 | 待修复 | 合计 |
|----------|--------|--------|------|
| Critical | 0 | 0 | 0 |
| High | 75 | 3 | 78 |
| Medium | 3 | 0 | 3 |
| Low | 0 | 0 | 0 |
| **合计** | **78** | **3** | **81** |

---

## 回归测试清单

- [x] Workflow 定义加载测试
- [x] 变量引用解析测试
- [x] 步骤执行流程测试
- [x] 状态持久化测试
- [x] 错误处理测试
- [x] 编辑器单元测试
- [x] CI/CD 自动化测试
