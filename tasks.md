# DeepBase 待办任务清单
> 更新时间：2026-08-13
> 执行人：AI Assistant (罗辑人格)
> 已完成任务已归档至 history.md | Bug 记录见 bugfix.md

---

## 🎯 **当前状态**

✅ **P0~P6 + DEV-001~004 全部完成并归档**
✅ **BUG-WYJX-001~010 全部修复并记录**
✅ 编译通过 (466,654 行) | P5/P6 新增 46 测试全部通过
✅ WebSocket RFC 6455 实现 + Browser 实战集成完成
✅ P5 视觉定位增强 + P6 智能等待与重试完成
✅ **78 服务端首版交付**（王维 #100）：migration 004 / 3 API / publish worker / 幂等表 / 限流，线上 10 项测试通过
✅ **78 同步链路修正**（王维 #101）：同步目录与服务器代码一致
✅ **客户端 TConfigUploader Preview 完成**：JCS + SHA256 + Idempotency-Key + 重试
✅ **FastMeet 多模型裁决**：签名基线按 78a r1 坚持 RSA-SHA256
✅ **回函 #100 已发**：要求服务端 Ed25519 → RSA-SHA256 返工 + P0 复验

**主要里程碑**:
- P0~P4: PERCEPT-WYJX 桌面 RPA 原语提炼 (2026-07-24) ✅
- DEV-001~004: Process Management/Window Operations/Recording Engine/Debugging Overlay (2026-07-24) ✅
- P5: 视觉定位增强 - 多尺度模板匹配、旋转不变性、亚像素精化 (2026-07-25) ✅
- P6: 智能等待与重试机制 - 指数退避、条件组合器、策略预设 (2026-07-25) ✅
- WebSocket: RFC 6455 完整实现 (649 行) + CDP.Adapter 迁移 ✅
- Browser 重构：CDP.Adapter/Session/WebElement重写，TEST-001 验证通过 ✅

---


## 🔴 DeepBase 参数化 / DLL / 制品发布平台（2026-08-12 多模型再审）

> **开发授权：已授权（2026-08-12）**。协议 r1 为受控实施基线；可直接开发、测试和局部重构，无需逐项再请示。DeepBase.Plugins 生命周期实现 41/41，但 SDK Preview 被纯 C ABI r2 阻断；ConfigUploader 为客户端 Preview；王维已交付服务端首版（#100/#101），当前为 acceptance pending——签名算法需按 78a r1 从 Ed25519 返工为 RSA-SHA256，差异修复见 #099 + 回函 #100。

### P0 — 发布阻断项

- [ ] **PLATFORM-P0-001：迁移 DeepBase.Plugins 到纯 C ABI r2**（Owner：DeepBase/SPW；S0 契约冻结中）
  - ✅ **S0 包格式规范已补**（77 §9，2026-08-13）：zip 目录结构 / RSA-SHA256 签名规则 / plugin_manifest.json schema / Gateway 校验顺序 / 验收标准；78 与 78a 严格按此打包。
  - ✅ **S0 C ABI r2 证据包已存在**（77a §4.1）：`include/deepbase_plugins_c.h` + `DeepBase.Plugins.CAbi.pas` 1:1；`Scripts/check_cabi_pure_c.py` EXIT 0；CAbiLoader 封装；8 个 C ABI 用例 + 原 41/41 = 49 passed。
  - [ ] S1：四单元创建 + Contracts 公共/业务拆分 + Lease 门禁（依赖 S0 完成）
  - [ ] S2：TPluginManager 泛化（注册制）+ Assayer 切换 + 回归
  - [ ] S3：热重载/崩溃/签名/卸载泄漏/跨语言 JCS 测试脚本化
  - [ ] S4：ISiteAdapterPlugin 契约（字节缓冲区版本）+ Gateway 示例插件冒烟（依赖 78 制品仓库）
  - 输出固定导出函数、不透明句柄、固定宽度整数、`PByte + Length + Capacity`、显式错误码和 `FreeBuffer`。
  - 禁止稳定 ABI 暴露 Delphi interface/string/TBytes/动态数组/对象/异常。
  - 保留现有 Delphi 接口仅作为宿主内部 wrapper。
  - 验收：ABI 头文件与 Delphi 声明扫描无管理类型；不同内存管理器/不同模块配置完成创建、调用、释放、错误路径测试；旧 41/41 全绿。

- [ ] **PLATFORM-P0-002：复核并修正 PostgreSQL migration**（Owner：王维/后端；客户端协助契约测试；首版见王维 #100；返工待回函 #100）
  - 使用 PG `~` CHECK；移除 `GENERATED ALWAYS AS (id)`；补真实 API key FK、审计表、artifact job、唯一约束和 downgrade。
  - 状态统一为 draft/building/published/failed/deprecated；当前版本仅由 release_heads 决定。
  - 首版已报告 migration 004 和 commit `3f25d09`；按 #099 补真实 api_key FK、统一 release head 命名/兼容、config/job 状态分层和 downgrade。
  - ⚠️ 待王维返工回函后复验（回函 #100 §3 P0-1）。
  - 验收：空库 apply、重复 apply、rollback 全通过；约束负例与索引计划有证据；提交新 commit/hash。

- [ ] **PLATFORM-P0-003：补强发布并发串行化和 publish=false 语义**（Owner：王维/后端；差异单 #099；返工待回函 #100）
  - publish=false 只写 draft，不创建打包任务。
  - Worker 使用唯一 job lease；事务 B 锁 release head/manifest，校验 expected generation/version，拒绝并发降级。
  - 王维 #100 的顺序发布/唯一 head 测试不等于并发竞争证明。
  - ⚠️ 待王维返工回函后复验（回函 #100 §3 P0-3）。
  - 验收：同版本竞争、首发竞争、旧版本降级竞争均只有合法 generation 生效；重复 worker 不重复发布；失败保持旧 LKG。

- [ ] **PLATFORM-P0-004：冻结 Manifest v1 信任根与防回滚**（Owner：DeepBase + 王维；签名算法按 78a r1 为 RSA-SHA256）
  - RFC 8785 JCS + **RSA-SHA256（PKCS#1 v1.5, 2048-bit, Windows CNG）**；算法门禁仅接受 `rsa-sha256`；可信安装/旧密钥签署 keyset；KMS/HSM 或受控签名服务；key rotation/revocation。
  - 客户端持久化最高 generation；普通 manifest 不得授权降级；rollback token 独立签名和审计。
  - 验收：自签公钥、未知 key、篡改、过期、目标不符、generation 降低全部拒绝并继续 LKG；轮换演练通过。
  - ⚠️ 服务端 #100 首版为 Ed25519，**需按回函 #100 §2 R1~R4 返工为 RSA-SHA256**。

- [ ] **PLATFORM-P0-005：修正文档与交付声明一致性**（Owner：DeepBase/SPW）
  - [x] 77/77a/78/78a/79 状态和关键规范已按多模型再审修订。
  - [ ] 同步 DeepCompare `GATEWAY_CLOUD_CONFIG_DESIGN.md`、history/release notes 和对外说明。
  - 验收：全仓搜索不再把 Plugins 标为已发布 SDK Preview，不再把 ConfigUploader mock 测试描述为生产链路完成。

### P1 — 最小 Pilot 闭环

- [ ] **PLATFORM-P1-001：打包 DeepBase.Plugins SDK Preview**（依赖 P0-001）
  - 交付 Contracts C ABI、Delphi wrapper、Verifier、SafeGuard、Manager、fixture、接入指南、兼容矩阵和 evidence manifest。
  - 验收：干净机编译；41/41 + ABI/内存所有权测试全绿；Preview 限制清单公开。

- [ ] **PLATFORM-P1-002：实现独立 UpdateAgent 与双槽 LKG**
  - staging 校验、真实退出、原子切换、`--after-update` 健康检查、失败回滚、pending restart。
  - 验收：文件占用、断电点、签名失败、启动失败、回滚、用户取消和自动重启一次场景通过。

- [ ] **PLATFORM-P1-003：完成真实服务端上传发布 E2E**（依赖王维 #099 返工；#100 首版为 Ed25519，已按回函 #100 要求返工 RSA-SHA256）
  - ConfigUploader → FastAPI → PG → artifact job → Manifest → Gateway → RSA 验签 → 生效/LKG。
  - 客户端先补 RSA-SHA256 验签 + zip 下载 + manifest 校验（对接 78 §2.4/§2.7）。
  - 验收：记录 Base URL、受控凭据交接、server/client commit、migration、请求/审计 ID 与可复跑脚本；不得只用 mock。

- [ ] **PLATFORM-P1-004：接入一个真实下游进入 Pilot**
  - 首选 DeepCompare Gateway；桌面进程与 server_process 分别验证更新行为。
  - 验收：Canary 可停止/回滚；连续运行窗口无未解释严重故障；遥测可查。

### P2 — 隔离与规模化

- [ ] **PLATFORM-P2-001：PluginHost 进程隔离与权限 profile**
  - 高风险/第三方插件进程外运行，具备 timeout、quota、circuit breaker、kill switch、崩溃拉起上限。
  - 验收：插件进程 AV/内存破坏/死循环不导致宿主退出；资源配额和审计生效。

- [ ] **PLATFORM-P2-002：capability 协商与 active/staged 实验**
  - 验收：旧 Lease 排空、新请求原子进入 staged；失败可回旧实例；实验通过后另行评审是否升基线。

- [ ] **PLATFORM-P2-003：Shadow/Canary/Ring 自动化与 GA 证据包**
  - 验收：错误阈值自动停止扩圈；Kill Switch 生效；密钥轮换、灾备、LKG 和审计证据完整。

### 外部依赖 / 阻塞

- [x] 王维已通过 #100 返回首版 FastAPI commit `3f25d09`、migration 004、Base URL 和部署/测试证据（Ed25519 版）。
- [ ] 王维按 `toWangwei/#100-回函-78服务端按r1返工RSA-SHA256并补P0复验.md` + `#099` 完成差异修复和复验（签名返工 RSA-SHA256 + P0-1~P0-4）。
- [ ] 我方客户端补 RSA-SHA256 验签 + zip 下载 + manifest 校验（对接 77 S0 / 78 §2.4/§2.7）。
- [ ] API Key 通过受控凭据渠道交接；禁止写入仓库、文档或用户端二进制。
- [ ] 生产链路完成前，78 与 ConfigUploader 对外状态保持 Preview/blocked，不得宣称 Pilot 或 GA。

---

## 📋 **待开发任务**

### 🔵 Low Priority

- [ ] ActionEngine 性能优化 (减少 Sleep, 异步管道)
  - [x] 异步动作管道实现 (TAsyncMotionPipe) ✅ COMPLETED
    - Enqueue/CancelAll 队列管理
    - 多动作连续执行支持
    - OnMotionComplete 回调机制
  - [x] 连续路径动画完善 ✅ COMPLETED
    - ✅ GetTickCount 高精度时间驱动
    - ✅ Easing function 平滑曲线计算
    - ✅ Pause/Resume/Stop 控制机制
    - ✅ 60-120 FPS 实时更新接口
  - [ ] 批量操作支持 (MVP 版本已完成) ⏳ PARTIAL
    - ✅ AsyncMoveMouse(AMotions[]) 多坐标批量移动
    - ✅ 自动插值计算与错误校验
    - [ ] 实际集成验证 (需真实鼠标环境)
    - [ ] 性能基准测试对比

- [ ] Browser.Session 集成测试 (需真实 Chrome) ⏳ PARTIAL
  - [x] E2E 集成测试框架设计 ✅ COMPLETED
    - 12 个完整测试场景覆盖
    - 连接稳定性、多 Tab、Cookie 管理
    - 长时间运行压力测试 (30 分钟)
    - 错误恢复验证
  - [ ] 真实 Chrome 环境执行 ⏳ PENDING
    - 需安装并启动 Google Chrome
    - CDP 端口 9222 开放
    - 网络环境影响
  - [ ] 性能基准对比

- [ ] 边界条件测试补充 ✅ COMPLETED
  - [x] 无效输入处理 ✅
    - Empty string URL handling
    - Invalid URL escapes and special chars (XSS/path traversal)
    - 超长 Path (>4096 characters)
    - Null pointer simulation in JavaScript
  - [x] 资源限制测试 ✅
    - Extremely large HTML content (>10MB page)
    - Deep nesting structure (1000+ div levels)
    - Massive element count performance (10000 elements)
  - [x] 网络异常处理 ✅
    - Network timeout with slow server
    - Connection reset during navigation
    - SSL error handling
  - [x] Motion Engine 边界测试 ✅
    - Extreme coordinates validation
    - Zero/Negative duration handling
    - Queue overflow protection
    - Rapid pause/resume cycle stress
  - [x] Cookie 边界测试 ✅
    - Cookie name max length (RFC 6265)
    - Cookie value max size (browser limits)
    - Excessive cookie count per domain (50-100 limit)

- [ ] 文档完善与代码注释补充
  - API 文档自动生成 (基于接口定义)
  - 示例代码仓库整理
  - 最佳实践指南编写

---

## 📊 **进度统计**

- **已完成模块**: 16/16 (P0~P6 + DEV-001~004)
- **总代码行数**: ~18,500 行 (含 P5/P6 新增 ~2,000 行，DEV-003/004新增 ~2,650 行)
- **P5/P6 测试**: 46 个，通过率 100%
- **已修复 Bug**: 10 项 (BUG-WYJX-001~010，详见 bugfix.md)
- **待优化任务**:
  - 性能优化 (ActionEngine Sleep 减少、异步管道)
  - 集成测试补充 (需真实 Chrome)
  - 边界条件测试
  - 文档与注释完善

---

## 🔜 **下一步开发方向**

1. **性能优化阶段**: ActionEngine 异步化、Sleep 减少、批量操作支持
2. **集成测试完善**: Browser.Session 真实环境测试、端到端场景验证
3. **稳定性提升**: 边界条件处理、异常恢复机制优化
4. **文档完善**: API 文档、示例代码、最佳实践指南

---

**Generated Following BCW-D20260722-002 Engineering Discipline**
