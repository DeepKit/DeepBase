# Implementation Plan: Regression Tests System

## Overview

为 UniBase 框架建立系统化的回归测试体系，覆盖已修复的 74 个 Bug，并集成到 CI 流程中。

## Tasks

- [x] 1. 创建回归测试基础设施
  - [x] 1.1 创建 `Tests/Regression/` 目录结构
    - 创建目录和 README.md 说明文档
    - _Requirements: 1.1, 6.1_
  - [x] 1.2 创建回归测试基类 `Test.Regression.Base.pas`
    - 实现 TRegressionTestBase 类
    - 提供 GetBugNumber, GetBugDescription, GetFixDate 抽象方法
    - _Requirements: 1.2_
  - [x] 1.3 创建测试注册表 `RegressionTestRegistry.pas`
    - 定义 P0_TESTS 和 P1_TESTS 常量数组
    - _Requirements: 1.3_

- [x] 2. 实现 P0 级别回归测试（Critical 安全漏洞）
  - [x] 2.1 创建 BUG-058 测试：XOR加密安全缺陷
    - 验证 GetConfigEncrypted/SetConfigEncrypted 抛出异常
    - 验证 Security.SaveSecret 正常工作
    - _Requirements: 2.1_
  - [x] 2.2 创建 BUG-062 测试：插件沙箱逃逸风险
    - 验证插件路径验证
    - 验证数字签名验证机制
    - _Requirements: 2.2_
  - [x] 2.3 创建 BUG-063 测试：插件配置权限绕过
    - 验证插件只能修改 Plugin. 前缀的配置
    - _Requirements: 2.3_
  - [x] 2.4 创建 BUG-013 测试：支付模块RSA签名
    - 验证 RSA2-SHA256 签名实现
    - _Requirements: 2.4_
  - [x] 2.5 创建 BUG-035 测试：不安全随机数生成
    - 验证使用安全随机数生成器
    - _Requirements: 2.5_
  - [x] 2.6 创建 BUG-007 测试：死锁风险-WhenReady
    - 验证回调中调用 UniBase 功能不会死锁
    - _Requirements: 2.6_
  - [x] 2.7 创建 BUG-014 测试：微信支付签名验证
    - 验证 RSA-SHA256 签名和验签
    - _Requirements: 2.7_
  - [x] 2.8 创建 BUG-033 测试：弱加密算法
    - 验证强制使用 AES-256 加密
    - _Requirements: 2.8_
  - [x] 2.9 创建 BUG-034 测试：硬编码密钥
    - 验证无硬编码默认密钥
    - _Requirements: 2.9_
  - [x] 2.10 创建 BUG-008 测试：UI线程竞态条件
    - 验证 TThread.Synchronize 中的控件有效性检查
    - _Requirements: 2.10_

- [x] 3. Checkpoint - P0 测试完成
  - 所有 P0 测试已创建完成，等待用户确认是否继续 P1 测试

- [x] 4. 实现 P1 级别回归测试（High 优先级）
  - [x] 4.1 创建内存泄漏相关测试
    - BUG-001: 动画对象内存泄漏
    - BUG-002: 悬空指针风险
    - _Requirements: 3.1_
  - [x] 4.2 创建序列化安全相关测试
    - BUG-059: JSON反序列化类型验证
    - BUG-060: 序列化深度限制
    - BUG-018: 反序列化安全漏洞
    - _Requirements: 3.2_
  - [x] 4.3 创建路径遍历相关测试
    - BUG-066: 文件监控路径遍历
    - BUG-027: 文件监控路径遍历
    - _Requirements: 3.3_
  - [x] 4.4 创建注入攻击相关测试
    - BUG-070: 日志注入攻击
    - BUG-073: 事件类型注入
    - BUG-019: 日志注入攻击
    - BUG-039: HTTP请求头注入
    - _Requirements: 3.4_
  - [x] 4.5 创建密码学相关测试
    - BUG-037: 密钥派生不当
    - BUG-020: 密钥名称验证
    - _Requirements: 3.5_
  - [x] 4.6 创建并发相关测试
    - BUG-010: 工作队列状态竞争
    - BUG-054: 弹性模式信号量泄漏
    - BUG-009: 日志系统竞态条件
    - _Requirements: 3.6_

- [x] 5. Checkpoint - P1 测试完成
  - 所有 P1 测试已创建完成，等待用户确认是否继续 CI 集成

- [x] 6. CI 集成
  - [x] 6.1 更新 `Scripts/run_tests.ps1`
    - 添加 `-Type Regression` 参数支持
    - 添加 `-Priority P0|P1|All` 过滤器
    - 添加 `-FailOnRegressionFailure` 选项
    - _Requirements: 4.1, 4.4_
  - [x] 6.2 添加回归测试失败时构建失败逻辑
    - 检查回归测试结果，失败时设置退出码
    - _Requirements: 4.2_
  - [x] 6.3 配置 XML 报告输出
    - 生成 RegressionTestResults.xml
    - _Requirements: 4.3_

- [x] 7. 覆盖率检查
  - [x] 7.1 创建 `Scripts/coverage_check.ps1`
    - 解析覆盖率报告
    - 实现阈值检查逻辑
    - _Requirements: 5.1, 5.2, 5.3_
  - [x] 7.2 添加覆盖率趋势报告
    - 记录历史覆盖率数据
    - 生成趋势图表
    - _Requirements: 5.4_

- [x] 8. 文档完善
  - [x] 8.1 创建 `Tests/Regression/README.md`
    - 说明目录结构和命名规范
    - 说明如何添加新的回归测试
    - _Requirements: 6.1_
  - [x] 8.2 创建 `Tests/Regression/BugTestMapping.md`
    - 列出所有 Bug 与测试的映射关系
    - _Requirements: 6.3_

- [x] 9. 将回归测试注册到主测试工程
  - [x] 9.1 更新 `Tests/UniBaseTests.dpr`
    - 添加回归测试单元引用
    - _Requirements: 4.1_

- [x] 10. Final Checkpoint - 全部完成
  - 回归测试系统实现完成
  - 22 个回归测试文件已创建（10 个 P0 + 12 个 P1）
  - CI 脚本已更新支持回归测试
  - 覆盖率检查脚本已创建

## Notes

- 任务按优先级排序：P0 测试 > P1 测试 > CI 集成 > 覆盖率 > 文档
- 每个 Checkpoint 后暂停，等待用户确认
- P0 测试是最关键的安全相关测试，必须首先完成
- 并发相关测试（4.6）需要使用 `[RepeatTest(100)]` 属性多次运行
- 测试文件命名必须遵循 `Test.Regression.BUG{number}_{ShortDescription}.pas` 格式
