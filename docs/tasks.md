# UniBase 任务清单

本文件仅跟踪“待办/进行中”事项。
- 已完成任务请见 `history.md`
- Bug 修复请见 `bugfix.md`

---

## 已完成（P3）

### DOC-002: 补充 QuickStart.md ✅
- **状态**: ✅ 已完成
- **完成日期**: 2025-12-02
- **输出物**: `docs/QuickStart.md` (433 行)
- **内容**:
  - 系统要求和安装步骤
  - 控制台和 VCL 应用示例
  - 8 个核心功能速览（配置/i18n/日志/窗体状态/单实例/导出/启动画面/LLM）
  - VCL 控件一览表
  - 常见问题解答

---

## 已完成（P4）

### PERF-002: SSH 连接复用优化 ✅
- **状态**: ✅ 已完成
- **完成日期**: 2025-12-02
- **文件**: `Core/UniBase.CLI.SSH.pas` (v0.2 → v0.3)
- **实现内容**:
  - `GetSessionWithTimeout` - 带超时的同步获取
  - `TryGetSession` - 无等待尝试获取
  - `GetSessionAsync` - 异步获取（回调在主线程）
  - `TSSHAcquireResult` 枚举 (arSuccess/arTimeout/arPoolFull/arConnectFailed)
  - `FAvailableEvent` - 会话释放时信号通知等待线程
  - `WaitingCount` - 跟踪等待线程数
  - `DefaultAcquireTimeout` - 可配置默认超时 (30s)
- **测试**: 6 个新增测试用例

---

## 🎉 所有任务已完成！

UniBase 框架已进入维护阶段。

最近完成: PERF-002 SSH连接池优化 (2025-12-02)

最后更新：2025-12-02
