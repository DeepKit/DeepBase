# DeepBase 审查修复跟踪（进行中）

> 本文件只保留**未完成**工作。已完成任务见 `history.md`（2026-08-24 全库审查修复战役节），
> 逐条 Bug 详情见 `bugfix.md`（BUG-CR-xxx 编号），完整审查报告见 `docs/code-review-2026-08-24.md`。
> 状态图例：☐ 未开始 · 🔧 进行中 · ✅ 已修复（回归通过）· ⏸ 暂缓 · ❌ 不修（注理由）
> 提交规则：每个 ✅ 必须附 DUnitX 回归并跑通 `Scripts\run_tests.ps1 -Type Unit -CI -Platform Win64`

## 当前基线

- 单测：4300 found / ~4290 passed / 波动失败 = 下述环境项
- 已知环境红集：Perception 位图 ×2（CR-606）、PreparedPool 并发偶发（CR-608）、性能门禁本机不可信（CR-605 备注）

---

## 一、🔧 P0 待环境验证转正（7 条）

| ID | 验证动作 | 涉及 |
|---|---|---|
| CR-002 | POSIX 冒烟：OpenSSL_RandomBytes(16)+PBKDF2 加解密往返 | Core\DeepBase.Crypto.OpenSSL.pas |
| CR-003 | PG 实测出队（语法已修正，需真库） | Persistence\DeepBase.DB.JobQueue.pas |
| CR-005 | 补 >2^53 整数绑定专项用例（编译已过 dcc64） | doQry\src\uDoQryExecutor.pas |
| CR-006/007/012 | 运行时用例（**dcc64 编译验证已过**，Scripts\verify_doqry.ps1） | doQry\uDoQryLegacy.pas |
| CR-014 | PG 实测删除用户/角色事务路径 | Authorization.FireDAC |

## 二、⏸ 环境受限排查

| ID | 内容 |
|---|---|
| CR-606 | Perception 两测试（StaticPair/InjectedBitmap_FlowsThroughFrameDifferGate）在本 VM 确定性失败；代码链路走读无异常，需图形完整会话复跑；同步开启 DPI 感知对照 |
| CR-608 | Test_PreparedPool_ConcurrentSameSql 偶发（AV 一次 / 竞态 Expected0 got1 一次）；排查 DeepBase.DB.DoQry prepared-pool 并发领取路径 |

## 三、🟡 剩余子项（按模块，均为部分完成的余项）

### Core
- [ ] CR-268 余项：edmAsync handler 异常接入 OnError 统计通道
- [ ] CR-278 已✅；CR-281b 余项：无（决策A已落地）
- [ ] CR-283 余项：序列化默认可见性决策3仅覆盖 JSON 根对象——XML/Binary 嵌套空对象行为待 Owner 追加决策
- [ ] CR-284 余项：Reflection FromString 可诊断化 / DeepClone 真递归 / 列表识别结构化判定
- [ ] CR-286 余项：Template 未闭合标签报错 / 自定义分隔符 / 引号感知切分
- [ ] CR-287 余项：CompareChars 代理对 / Apply 换行保真 / IgnoreBlankLines 实现 / IsBinary 规则统一
- [ ] CR-288 余项：插件加载 psLoading 拒绝 / 门禁回滚 / GetMetadata 泄漏 / 拓扑排序 / 大小写统一
- [ ] CR-289 余项：Finalize 锁内复查 / WhenReady 入锁 / InitializeModules 失败回滚
- [ ] CR-291 余项：Bulkhead 快速路径空等 / 析构排空
- [ ] CR-292 余项：IgnoreIf 守卫生效 / 动作锁外化+重入检测 / FromJSON 白名单
- [ ] CR-293 余项：UpdateUser 合并活体 / token 单临界区+哈希存储 / 审计异步投递
- [ ] CR-295 余项：CheckAll 原子性 / TryExecute 异常保类型
- [ ] CR-299 余项：ISO 偏移量与小数秒支持
- [ ] CR-310 余项：Plural 小数操作数 Invariant 化
- [ ] CR-311 余项：MVVM 错误回调保类型 / 关停悬空 SelfRef
- [ ] CR-313 余项：CSV 公式前缀 / DOCX 属性转义复核
- [ ] CR-317 余项：GBK 乱码注释文件 UTF-8 重写（TestHelper/Constants 等）

### Persistence
- [ ] CR-231 Migrations 数值排序
- [ ] CR-233 EnsureSchemaIfNeeded 原子化
- [ ] CR-235 StatusMachine 乐观守卫+裸指针收敛
- [ ] CR-236 ORM Count 方言 / CreateTable PG 分支
- [ ] CR-240 Logging legacy 回退一次性切换 / 枚举范围钳制

### Tools/Infra
- [ ] 将 doQry 纳入主测试图（引入真 DBClient 或沿用 Tools\DBClientStub 于 CI）
- [ ] Scripts\verify_doqry.ps1 接入 CI 门禁

## 四、🔵 Backlog（低优）

- CR-601 性能族：LRU O(n)、日志每条开关文件、O(n²) 字符串累加、TFDQuery 逐调用创建
- CR-602 安全加固族：取模偏差、迭代上限、HTML/CSV 转义、WM_COPYDATA 校验
- CR-603 API 语义族：cepNone 抛异常、Exists LIMIT 1、ReDeepMoveCallback 更名
- CR-604 卫生族：Schema 空行整理、VER350 订正、CompilerVersion 注释订正
- CR-605 备注：Config 写门禁 4000 已校准；若实现连接级语句缓存可回调 5000
- CR-607 二进制流式 API 原生 raw-stream 重载（去 Base64 中转）
- CR-608 见上（与二合并排查）
- 新增: doQry Logger JsonEscape 修复后补运行时断言用例
- 新增: 存量库 App.LogLevel 迁移 UPDATE 已随种子执行，观察一个版本后可移除该语句
