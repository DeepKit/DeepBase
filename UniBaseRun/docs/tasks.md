# UniBaseRun 开发任务清单

> **状态更新**: 2025-12-12
>
> - Phase 1（基础设施）已在 2025-11-28 完成，详见：`UniBaseRun/PHASE1_COMPLETE.md`
> - 当前代码实现已能编译运行，但与本文件最初的“阶段 1/2/3”拆分存在偏差（例如：主窗体结构、Frame 集成方式等）。
> - 本文件保留原规划结构，后续将以“现有代码 + 验收标准”为准逐段重写对齐。

**项目版本**: v0.1.0-dev  
**开始时间**: 2025-11-28  
**状态**: 进行中  
**完成度**: Phase 1 ✅ / Phase 2 🟡 / Phase 3+ 🔲

---

## 📋 任务清单符号
* `[ ]` 未开始
* `[~]` 进行中
* `[x]` 已完成
* `[!]` 被阻止/需要讨论

---

## 🎯 阶段 1：基础设施（P0）
**周期**: Week 1-2  
**目标**: 搭建可编译运行的最小骨架，验证 UniBase 集成  
**验收标准**: 程序可编译且运行不崩溃；主窗体显示五面板布局；UniBase 正常初始化

### 1.1 主程序入口
- [~] UniBaseRun.dpr - FMX 应用主入口
- [ ] UniBaseRun.dproj - 工程配置文件
- [ ] 实现 UniBase.InitializeEx 调用
- [ ] 实现 UniBase.Finalize 清理
- [ ] 验证编译通过（Release & Debug）

### 1.2 视图层（View）
- [ ] ViewMain.pas - 主窗体代码
- [ ] ViewMain.fmx - 主窗体设计文件
  - [ ] 五面板布局（Top/Left/Center/Right/Bottom）
  - [ ] 主菜单（File/View/Tools/Help）
  - [ ] 状态栏
  - [ ] TreeView（左侧配置/日志树）
  - [ ] Panel（中央主内容）
  - [ ] Panel（右侧信息）

### 1.3 控制层（Controller）
- [ ] CtrlMain.pas - 主控制器实现
  - [ ] ICtrlMain 接口定义
  - [ ] 初始化逻辑
  - [ ] 日志加载接口（存根实现）
  - [ ] 配置加载接口（存根实现）
  - [ ] 错误处理

### 1.4 数据层（Model）
- [ ] uDM.pas - 数据模块
  - [ ] PostgreSQL 连接配置（从 config.db 读取）
  - [ ] TFDConnection 初始化
  - [ ] SQLite config.db 连接
  - [ ] 错误处理

### 1.5 项目配置
- [x] root.txt - 项目根目录锚点文件
- [ ] 创建 scripts/ 目录
- [ ] 创建 tests/ 目录
- [ ] 创建 assets/ 目录（资源）
- [ ] .gitignore 配置

---

## 🎯 阶段 2：核心功能（P0）
**周期**: Week 2-3  
**目标**: 实现日志查看和配置编辑两大核心功能  
**验收标准**: 日志能正常读取显示；配置能正常读写；过滤搜索功能正常

### 2.1 日志查看功能
- [ ] FrameLogViewer.pas - 日志查看 Frame 代码
- [ ] FrameLogViewer.fmx - 日志查看 Frame 设计
  - [ ] 日志文件列表
  - [ ] 日志内容显示区（TMemo 或 TText）
  - [ ] 过滤栏（关键字、级别、时间）
  - [ ] 统计信息显示
- [ ] CtrlMain.GetLogFileList - 获取日志文件列表
- [ ] CtrlMain.LoadLogPreview - 加载日志内容
- [ ] CtrlMain.FilterLogLines - 过滤日志
- [ ] logs/ 目录扫描实现
- [ ] 日志文件大小限制和分页加载

### 2.2 配置编辑功能
- [ ] FrameConfigEditor.pas - 配置编辑 Frame 代码
- [ ] FrameConfigEditor.fmx - 配置编辑 Frame 设计
  - [ ] 配置项列表
  - [ ] 编辑控件区（TextEdit/ComboBox/CheckBox）
  - [ ] 保存/还原按钮
  - [ ] 配置说明显示
- [ ] CtrlMain.GetConfigGroups - 获取配置分组
- [ ] CtrlMain.GetConfigsInGroup - 获取分组内配置
- [ ] CtrlMain.GetConfigValue - 读配置值
- [ ] CtrlMain.SetConfigValue - 写配置值
- [ ] CtrlMain.ValidateConfig - 配置验证
- [ ] config.db 配置项初始化

### 2.3 ViewMain 集成
- [ ] 在 ViewMain 中嵌入 FrameLogViewer
- [ ] 在 ViewMain 中嵌入 FrameConfigEditor
- [ ] 实现左侧树的切换逻辑
- [ ] 实现主菜单功能（重新加载、打开目录等）
- [ ] 实现状态栏更新

---

## 🎯 阶段 3：业务骨架（P1）
**周期**: Week 3-4  
**目标**: 提供典型业务结构示例  
**验收标准**: 登录窗体可打开；CRUD Frame 可交互；PostgreSQL 连接可配置

### 3.1 登录模块
- [ ] ViewLogin.pas - 登录窗体代码
- [ ] ViewLogin.fmx - 登录窗体设计
  - [ ] 用户名/密码输入框
  - [ ] 登录/取消按钮
  - [ ] 记住密码复选框
- [ ] CtrlLogin.pas - 登录控制器
  - [ ] ICtrlLogin 接口
  - [ ] 验证逻辑（存根）
  - [ ] 错误处理

### 3.2 用户模型
- [ ] ModelUser.pas - 用户实体
  - [ ] TUser = record（用户名、密码、权限等）
  - [ ] 字段验证逻辑

### 3.3 CRUD 框架
- [ ] FrameCRUD.pas - CRUD Frame 代码
- [ ] FrameCRUD.fmx - CRUD Frame 设计
  - [ ] 上方：列表 StringGrid
  - [ ] 下方：编辑区（输入框组）
  - [ ] 右侧：新建/编辑/删除按钮
  - [ ] 查询/保存/取消按钮

### 3.4 数据库集成
- [ ] uDM 中实现 PostgreSQL 连接（从 config.db 读取参数）
- [ ] 实现连接池管理（可选）
- [ ] 实现 DoQry 参数化查询示例
- [ ] 实现事务管理示例
- [ ] 错误处理和日志

---

## 🎯 阶段 4：脚本与自动化（P0）
**周期**: Week 4  
**目标**: 完善项目初始化和构建脚本，实现一键迁移  
**验收标准**: 脚本能成功重命名工程；能成功编译；能成功启动

### 4.1 项目初始化脚本
- [ ] scripts/init-project.bat
  - [ ] 检查 Delphi 编译器
  - [ ] 提示输入新项目名
  - [ ] 重命名 .dpr/.dproj 文件
  - [ ] 更新代码中的项目名占位符
  - [ ] 重写 root.txt 为新路径
  - [ ] 清理临时文件
  - [ ] 验证成功

### 4.2 编译脚本
- [ ] scripts/build.bat
  - [ ] 支持 Debug/Release 参数
  - [ ] 编译 .dproj 主工程
  - [ ] 输出成功/失败信息
  - [ ] 设置返回码（0=成功）

### 4.3 测试脚本
- [ ] scripts/test.bat
  - [ ] 编译测试工程
  - [ ] 运行命令行测试
  - [ ] 设置返回码（0=全部通过）

### 4.4 GUI 测试脚本
- [ ] scripts/test-gui.bat
  - [ ] 编译 GUI 测试工程
  - [ ] 启动 GUI 测试程序

### 4.5 运行脚本
- [ ] scripts/run.bat
  - [ ] 查找主程序 EXE
  - [ ] 启动应用
  - [ ] 提示信息

---

## 🎯 阶段 5：测试框架（P1）
**周期**: Week 4-5  
**目标**: 建立单元测试框架  
**验收标准**: 测试工程可编译运行；返回码正确；GUI 显示结果

### 5.1 命令行测试工程
- [ ] tests/UniBaseRun.Tests.dpr
  - [ ] DUnitX 框架集成
  - [ ] 测试注册
  - [ ] 返回码处理

### 5.2 GUI 测试工程
- [ ] tests/UniBaseRun.GuiTests.dpr
  - [ ] FMX 测试运行器集成
  - [ ] 可视化结果展示

### 5.3 配置测试
- [ ] Tests.Config.pas
  - [ ] 配置读取测试
  - [ ] 配置写入测试
  - [ ] 配置验证测试

### 5.4 控制器测试
- [ ] Tests.CtrlMain.pas
  - [ ] 初始化测试
  - [ ] 接口功能测试

### 5.5 日志查看测试
- [ ] Tests.LogView.pas
  - [ ] 日志列表加载
  - [ ] 日志过滤功能

---

## 🎯 阶段 6：文档与发布（P1）
**周期**: Week 5  
**目标**: 补充文档，准备发布  
**验收标准**: 新开发者能快速上手；模板能成功迁移；功能正常

### 6.1 代码文档
- [ ] 补充所有单元的文件头注释
- [ ] 补充关键接口的方法注释
- [ ] 补充复杂逻辑的代码注释

### 6.2 用户文档
- [ ] 创建 README.md（快速开始指南）
- [ ] 创建 DEVELOPMENT.md（开发者指南）
- [ ] 创建 CHANGELOG.md（变更日志）
- [ ] 创建 ARCHITECTURE.md（架构详解）

### 6.3 验收测试
- [ ] 完整端到端测试
- [ ] 跨 Windows 版本测试
- [ ] 项目模板迁移测试
- [ ] 性能基准测试

### 6.4 发布准备
- [ ] 版本标记（v0.1.0）
- [ ] 发布说明
- [ ] 向上级反馈

---

## 📊 进度追踪

### 阶段完成度
- 阶段 1（基础设施）: 0% (0/5)
- 阶段 2（核心功能）: 0% (0/9)
- 阶段 3（业务骨架）: 0% (0/8)
- 阶段 4（脚本自动化）: 0% (0/5)
- 阶段 5（测试框架）: 0% (0/5)
- 阶段 6（文档发布）: 0% (0/4)

### 总体完成度: 0%

---

## 🚀 关键决策与约束

1. **FMX 主版本** - 不开发 VCL 版本，专注跨平台支持
2. **零目录结构** - 所有 .pas/.fmx 平铺在根目录
3. **分层严格** - View → Ctrl → Model/uDM 单向依赖
4. **配置统一** - 禁用 INI/Registry，统一使用 UniBase.Config
5. **日志统一** - 禁用 OutputDebugString，统一使用 UniBase.Logging
6. **参数化查询** - 数据库操作必须使用 DoQry
7. **国际化** - 所有用户文本使用 T() 宏

---

## 📚 相关文档

- [01. 项目概览与架构映射](./01.UniBaseRun_项目概览与架构映射.md)
- [02. 文件命名与零目录实践](./02.UniBaseRun_文件命名与零目录实践.md)
- [03. 日志查看与配置编辑设计](./03.UniBaseRun_日志查看与配置编辑设计.md)
- [04. 测试与脚本使用说明](./04.UniBaseRun_测试与脚本使用说明.md)
- [开发计划](./plan.md)（详细实现路线图）
