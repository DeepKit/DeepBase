# UniFlow 开发任务清单

> 最后更新: 2025-12-05
>
> 当前: Phase 8 调试与诊断

---

## 开发进度

| Phase | 名称 | 状态 |
|-------|------|------|
| Phase 1 | 核心框架 | ✅ |
| Phase 2 | 调度能力 | ✅ |
| Phase 3 | AI 集成 | ✅ |
| Phase 4 | 校验与安全 | ✅ |
| Phase 5 | 会话管理 | ✅ |
| Phase 6 | 集成测试 | ✅ |
| Phase 7 | 可选增强 (P2) | ✅ |
| Phase 8 | 调试与诊断 | ✅ |

**累计代码**: ~40,100 行
- Pascal: 30 文件 (~32,100 行)
- Python: 4 文件 (~1,450 行)
- Node.js: 7 文件 (~1,100 行)
- Web Editor: 8 文件 (~2,600 行)
- Editor Tests: 7 文件 (~2,300 行)
- CI/CD: 4 文件 (~550 行)

---

## 已完成任务 ✅

详见 `history.md`

| 任务 ID | 名称 | 完成日期 |
|---------|------|----------|
| TASK-307 | Python Skill 服务 | 2025-12-05 |
| TASK-308 | Delphi Skill 客户端 | 2025-12-05 |
| TASK-701 | 审计日志增强 | 2025-12-05 |
| TASK-702 | 监控指标 (Prometheus) | 2025-12-05 |
| TASK-703 | Node.js Skill 服务 | 2025-12-05 |
| TASK-704 | 可视化编辑器 (Web UI) | 2025-12-05 |

---

## Phase 8: 调试与诊断 [P0/P1]

> 目标: 集成到宿主程序后容易定位和修复 Bug

| 任务 ID | 名称 | 描述 | 优先级 | 状态 |
|---------|------|------|--------|------|
| TASK-901 | 诊断模块 | `UniFlow.Diagnostics.pas` - 统一日志门面 + 追踪开关 | P0 | ✅ |
| TASK-902 | CorrelationId 支持 | 跨系统调用链追踪，全链路日志关联 | P0 | ✅ |
| TASK-903 | 错误上下文收集 | 异常时自动快照（变量/输入/堆栈/已执行步骤） | P1 | ✅ |
| TASK-904 | 执行轨迹导出 | 导出执行历史用于复现问题 | P1 | ✅ |
| TASK-905 | 调试模式 | 单步执行/断点机制（开发期调试） | P2 | ✅ |

### TASK-901 详细设计

```pascal
TUniFlowDiagnostics = class
  // 统一日志门面 - 允许宿主注入
  LoggerFactory: ILoggerFactory;
  
  // 执行追踪
  TraceEnabled: Boolean;
  TraceLevel: (tlMinimal, tlNormal, tlVerbose);
  
  // 调试钩子
  OnBeforeStep: TStepEvent;
  OnAfterStep: TStepEvent;
  OnError: TErrorEvent;
  
  // 状态导出
  function DumpState: string;
  function ExportTrace: string;
end;
```

设计原则:
- **零侵入** - 宿主不用改代码就能用默认日志
- **可插拔** - 想用自己的 Logger 随时替换
- **低开销** - 关闭追踪时性能影响 < 1%

---

## 后续维护任务 [P3]

| 任务 ID | 名称 | 描述 | 状态 |
|---------|------|------|------|
| TASK-801 | SQLite 存储实现 | 实现 TSQLiteAuditStore 和 TSQLiteSessionStore | ✅ |
| TASK-802 | WebSocket 实时推送 | 工作流状态实时通知 | ✅ |
| TASK-803 | 编辑器测试 | 可视化编辑器单元测试 | ✅ |
| TASK-804 | CI/CD 集成 | GitHub Actions 自动化测试 | ✅ |
| TASK-805 | 多语言文档 | 英文 API 文档 | |

---

## 已完成: Delphi 12 迁移 [DELPHI12-001] ✅

> UniBase Core 模块 Delphi 12 兼容性修复
>
> **进度**: 78/78 (100%) ✅
> **完成日期**: 2025-12-05

### 已修复模块

| 任务 ID | 文件 | 修复内容 | 状态 |
|---------|------|------|------|
| DELPHI12-002 | UniBase.Graph.pas | 迭代实现替代本地过程/匿名方法 | ✅ |
| DELPHI12-003 | UniBase.Net.pas | Indy DNS API 更新 (WaitingTime/QueryType) | ✅ |
| DELPHI12-004 | UniBase.Serialization.pas | ISerializer 移除泛型方法，类保留 | ✅ |

**详细修复记录**: 见 `../bugfix.md` BUG-028 ~ BUG-053

---

## 优先级说明

- **P0**: 阻塞核心功能
- **P1**: MVP 必需
- **P2**: 增强功能
- **P3**: 维护/优化

---

## 相关文档

- `history.md` - 已完成任务记录
- `bugfix.md` - Bug 修复记录
- `docs/api-reference.md` - API 参考
- `docs/quick-start.md` - 快速入门
