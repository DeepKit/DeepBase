# AutoFix Hardening：加固清单

> 关联文档：`DeepBase.AutoFix-AI自动修复运行时错误方案.md`  
> 日期：2026-05-15  
> 版本：v1.1-simple  
> 状态：核心方案之外的加固项

核心方案只负责把 AutoFix 跑通。本文档负责回答两个问题：

1. 哪些护栏即使在 MVP 里也不能省？
2. 哪些增强可以等核心闭环稳定后再做？

---

## 1. 分级原则

### A 类：MVP 必守

不做会导致误判成功、误改文件、主循环失控。

### B 类：上线前加固

本地验证可以先不做，但进入长期使用、团队使用或无人值守前必须做。

### C 类：长期增强

提高诊断质量或自动化程度，不影响第一版闭环。

---

## 2. A 类：MVP 必守

### A-1. 异常 handler 不得破坏旧链

要求：

- `Application.OnException` 保存并调用旧 handler。
- `System.ExceptProc` 保存并调用旧 handler。
- 递归保护使用 `threadvar` 或线程安全计数。
- AutoFix 自己记录失败时必须吞掉异常。

核心目的：AutoFix 不能因为安装异常 hook 而改变宿主应用原有异常行为。

### A-2. JSONL 必须一行一个 JSON

要求：

- PowerShell 写 JSONL 必须使用 `ConvertTo-Json -Compress -Depth 10`。
- Delphi 写 JSONL 必须单行写入。
- 读取 JSONL 时允许跳过最后一条坏行，但要记录 warning。

核心目的：避免 timeout/fatal 时写出半截 JSON 导致主循环崩溃。

### A-3. runner 必须补齐场景终态

runner 结束后，每个请求场景都必须有终态：

```text
pass / fail / fatal / timeout / crashed / startup_failed
```

补齐规则：

- health 未就绪：未完成场景记为 `startup_failed`。
- 运行超时：未完成场景记为 `timeout`。
- 进程异常退出：未完成场景记为 `crashed`。
- 最后一条仍是 `running`：按 runner 状态补终态。

核心目的：禁止“没有错误但场景其实没跑完”的假成功。

### A-4. 成功判定必须完整

成功必须同时满足：

- runner status = `normal`
- exit code = `0`
- health run_id 正确
- 所有 requested scenarios 最后状态都是 `pass`
- 当前 run_id 没有 runtime error

任一条件不满足，都不能进入成功分支。

### A-5. boundary 必须 fail-closed

要求：

- `boundary.json` 缺失时停止。
- 不允许使用隐式默认白名单。
- hard block 不可被配置覆盖。
- tracked、untracked 都要检查。

最低 hard block（防御性兜底，正常情况下编译产物在 worktree 外不会触发，但必须防止 .gitignore 配置遗漏）：

```text
DeepBase/
*.dproj
*.dpr
*.ps1
*.bat
*.cmd
*.exe
*.dll
*.bpl
*.dcu
*.res
bin/
dcu/
build/
boundary.json
```

核心目的：AI 只能改应用层源码。

### A-6. git/native command 必须检查退出码

PowerShell 的 `$ErrorActionPreference = 'Stop'` 不可靠覆盖 native command。

要求：

- `git`、`msbuild`、`cmd` 调用后检查 exit code。
- 失败立即抛错或返回结构化失败对象。
- 不允许静默继续。

### A-7. 编译产物不得污染 worktree

要求：

- exe/dcu/map/res 输出到 worktree 外的 build-out。
- compile-errors 写到 output/audit，不写入 worktree。
- 初始编译后必须检查 worktree 干净。

核心目的：边界检查只看到 AI 源码修改，不混入编译副作用。

---

## 3. B 类：上线前加固

### B-1. AI 调用安全边界

包含两个子项：

**外部模型外发控制**：

默认不允许把源码、日志、dump、patch 发送给外部模型。

如果要接外部模型，必须有：

- 显式开关：`-AllowExternalAI`
- provider/model allowlist
- prompt 脱敏
- 不发送 dump
- 不发送完整 patch
- 记录 prompt hash 和 response hash

**Prompt 注入隔离**：

运行时错误、源码片段、编译日志都视为不可信数据。

要求：

- 用结构化块标注 `UNTRUSTED DATA`。
- 安全约束不能和错误文本混在一起。
- prompt 只作为辅助，真正约束靠 boundary check。

### B-2. AutoMerge 收紧

本地默认只输出修复分支，不自动 merge。

AutoMerge 只建议在 CI 中开启，并满足：

- 测试通过
- boundary 报告通过
- diff 风险等级低
- protected branch 或人工批准

### B-3. 审计 artifact

每次运行至少保留：

```text
run-id
base commit
fix branch
runtime-errors.jsonl
scenario-results.jsonl
exit-reason.json
compile-errors.txt
boundary verdict
final diff hash
```

团队使用时再升级为 `audit.jsonl`。

### B-4. repo 锁

同一 repo 同时只允许一个 AutoFix。

上线前建议：

- 锁放在 git common dir 或系统 temp。
- 锁内容包含 repo、pid、host、guid、start time。
- stale lock 需要人工确认或安全 TTL。

### B-5. ignored 文件清理

worktree rollback 建议清理 ignored 文件：

```text
git clean -fdx
```

前提：build/output/audit 都在 worktree 外。

---

## 4. C 类：长期增强

### C-1. 多模块 map 精确匹配

Phase 1 只解析主 EXE map。长期需要支持：

- BPL
- DLL
- 插件模块
- 同名模块区分

建议记录模块完整路径、ImageSize、TimeDateStamp 或 hash，再匹配 map。

### C-2. Delphi map 精确转换

长期要把转换公式固化到测试：

```text
VA → module RVA → segment:offset → unit:line/function
```

必须用真实 Delphi detailed map 文件做回归测试。

### C-3. 精确异常栈

Phase 1 可以只用 `ExceptAddr` 和 handler stack。

后续可选：

- JCL
- madExcept
- VEH + StackWalk64

### C-4. Dump 支持

默认不启用 full dump。

如果需要：

- 优先 minidump
- 按 run_id/PID 隔离目录
- ACL 仅当前用户可读
- 不自动发送给 AI
- TTL 清理

### C-5. 修复缓存

第一版不建议做缓存。

后续做缓存时，patch 必须视为不可信输入：

- 绑定 repo id
- 绑定 base commit
- 绑定 boundary hash
- apply 前后都跑 boundary + compile + scenario

### C-6. 震荡检测增强

MVP 只做同一 `dedup_key` 最多 3 次。

后续可增加：

- diff hash A/B/A 检测
- scenario pass 数是否改善
- 多错误根因聚合

---

## 5. 推荐落地顺序

1. 先实现核心文档 Phase 1。
2. 同时落实本文 A 类全部项目。
3. 用 DeepSpec 注入错误跑通端到端。
4. 稳定后补 B-1、B-2、B-4。
5. 团队使用或 CI 前补齐 B 类剩余项目。
6. C 类按真实痛点逐项做。

---

## 6. 检查表

| ID | 项目 | 等级 | MVP 是否必须 |
|----|------|------|--------------|
| A-1 | handler 不破坏旧链 | A | 是 |
| A-2 | JSONL 单行格式 | A | 是 |
| A-3 | scenario 终态补齐 | A | 是 |
| A-4 | 完整成功判定 | A | 是 |
| A-5 | boundary fail-closed | A | 是 |
| A-6 | native exit code 检查 | A | 是 |
| A-7 | 编译产物隔离 | A | 是 |
| B-1 | AI 调用安全边界 | B | 否 |
| B-2 | AutoMerge 收紧 | B | 否 |
| B-3 | 审计 artifact | B | 否 |
| B-4 | repo 锁 | B | 否 |
| B-5 | ignored 清理 | B | 否 |
| C-1 | 多模块 map | C | 否 |
| C-2 | map 精确公式 | C | 否 |
| C-3 | 精确异常栈 | C | 否 |
| C-4 | dump 支持 | C | 否 |
| C-5 | 修复缓存 | C | 否 |
| C-6 | 震荡增强 | C | 否 |

---

*文档版本：v1.1-simple · 2026-05-15*
