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

## 已修复 Bug (Delphi 12 兼容性)

### BUG-038: Graph.pas 泛型类中的本地过程 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: High
- **影响范围**: UniBase.Graph.pas
- **问题描述**: TTree.Traverse 等方法中包含本地过程，触发 NI19024 错误
- **修复方案**: 将所有递归遍历重构为迭代式实现 (Stack/Queue)
- **修复内容**:
  - `TTree.Traverse` 使用 TStack/TQueue 迭代
  - `TTree.ToArray` 使用 TStack/TQueue 迭代
  - `TTree.Find` 使用 TStack 迭代
  - `TTree.NodeCount` 使用 TStack 迭代
  - `TGraph.FindCycle` 使用 TStack 迭代 DFS
  - `TGraph.StronglyConnectedComponents` 使用 TStack 迭代 Kosaraju

### BUG-039: Net.pas Indy DNS API 变更 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: High
- **影响范围**: UniBase.Net.pas
- **问题描述**: QueryTimeout/qtCNAME/TCNAMERecord 在新版 Indy 中不存在
- **修复方案**: 使用新版 Indy API
- **修复内容**:
  - `QueryTimeout` → `WaitingTime`
  - `qtCNAME` → `qtName`
  - `TCNAMERecord` → `TCNRecord`

### BUG-040: Serialization.pas 接口泛型方法限制 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: High
- **影响范围**: UniBase.Serialization.pas
- **问题描述**: E2535 Interface methods must not have parameterized methods
- **修复方案**: 接口移除泛型方法，保留在类中实现
- **修复内容**:
  - `ISerializer` 接口只包含非泛型方法
  - `TBaseSerializer` 类保留泛型方法 (Delphi 12 允许类有泛型方法)
  - 添加 `TSerializer` 静态帮助类提供泛型入口

---

## 代码审查 Bug (2025-12-05)

### BUG-041: JSON Unicode 转义处理不完整 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: Medium
- **影响范围**: UniFlow.Performance.JSON.pas
- **问题描述**: `TJSONStreamReader.ReadString` 中 `\uXXXX` 未转换为字符
- **修复方案**: 解析 4 位十六进制并转换为 Char

### BUG-042: TJSONObjectPool 重置器内存泄漏 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: Medium
- **影响范围**: UniFlow.Performance.Pool.pas
- **问题描述**: `RemovePair().Free` 正序删除可能导致索引错误
- **修复方案**: 使用倒序删除并正确释放 Pair

### BUG-043: TWorkStealingQueue Pop 竞态条件 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: High
- **影响范围**: UniFlow.Performance.Concurrent.pas
- **问题描述**: Pop 方法在只有一个元素时逻辑错误
- **修复方案**: 简化 Pop 逻辑，先检查空再弹出

### BUG-044: TPoolStats.HitRate 除零风险 ✅
- **发现/修复日期**: 2025-12-05
- **严重程度**: Low
- **影响范围**: UniFlow.Performance.Pool.pas
- **问题描述**: `TotalAcquired = 0` 时除零
- **修复方案**: 添加除零保护

---

## Bug 统计

| 严重程度 | 已修复 | 待修复 | 合计 |
|----------|--------|--------|------|
| Critical | 0 | 0 | 0 |
| High | 79 | 0 | 79 |
| Medium | 5 | 0 | 5 |
| Low | 1 | 0 | 1 |
| **合计** | **85** | **0** | **85** |

---

## 回归测试清单

- [x] Workflow 定义加载测试
- [x] 变量引用解析测试
- [x] 步骤执行流程测试
- [x] 状态持久化测试
- [x] 错误处理测试
- [x] 编辑器单元测试
- [x] CI/CD 自动化测试
