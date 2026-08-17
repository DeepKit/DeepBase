# DeepFlow - AI Agent Workflow Engine

> **版本**: 1.0 MVP  
> **创建时间**: 2025-12-04  
> **状态**: 开发中

---

## 概述

DeepFlow 是一个 AI Agent 工作流引擎，用于编排和管理多个 AI 角色（Commander、Executor、Guard、Chronicler）的协作。

### 核心架构

```
┌─────────────┐
│  Commander  │  ← 任务编排
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌──────────┐
│  Executor   │────▶│  Skills  │  ← Python LLM 服务
└──────┬──────┘     └──────────┘
       │
       ▼
┌─────────────┐
│    Guard    │  ← 输入/输出校验
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Chronicler  │  ← 审计日志
└─────────────┘
```

---

## 目录结构

```
DeepFlow/
├── Source/              # Delphi 源码
│   ├── Core/           # 核心引擎
│   │   ├── DeepFlow.Engine.pas
│   │   ├── DeepFlow.Message.pas
│   │   └── DeepFlow.Role.pas
│   ├── Roles/          # 角色实现
│   │   ├── DeepFlow.Commander.pas
│   │   ├── DeepFlow.Executor.pas
│   │   ├── DeepFlow.Guard.pas
│   │   └── DeepFlow.Chronicler.pas
│   └── Workflow/       # 工作流定义
│       ├── DeepFlow.Workflow.Definition.pas
│       └── DeepFlow.Workflow.Context.pas
├── Skills/             # Python LLM 服务
│   └── src/
│       └── main.py
├── Config/             # 配置文件
│   └── DeepFlow.config.json
├── Tests/              # 测试
├── Demo/               # 演示
└── sql/                # 数据库脚本
    └── migrations/
```

---

## 快速开始

### 1. 启动 Python LLM 服务

```bash
cd Skills
pip install -r requirements.txt
python src/main.py
```

### 2. 配置 DeepFlow

编辑 `Config/DeepFlow.config.json`：

```json
{
  "llm_endpoint": "http://localhost:8000",
  "max_retries": 3,
  "timeout_seconds": 30
}
```

### 3. 运行工作流

```delphi
uses
  DeepFlow.Engine, DeepFlow.Workflow.Definition;

var
  Engine: TDeepFlowEngine;
  Workflow: TWorkflowDefinition;
begin
  Engine := TDeepFlowEngine.Create;
  try
    Workflow := TWorkflowDefinition.Create;
    Workflow.Name := 'SimpleWorkflow';
    // 添加步骤...
    
    Engine.Execute(Workflow);
  finally
    Engine.Free;
  end;
end;
```

---

## 核心组件

### Engine (引擎)
- 管理角色生命周期
- 消息路由
- 状态机管理

### Commander (指挥官)
- 任务分解
- 步骤编排
- 错误恢复

### Executor (执行者)
- 调用 Python LLM 服务
- 执行具体任务
- 结果返回

### Guard (守卫)
- 输入验证
- 输出校验
- 安全检查

### Chronicler (记录者)
- 审计日志
- 执行轨迹
- 性能指标

---

## 开发状态

- [x] 核心引擎骨架
- [x] 角色接口定义
- [x] Python LLM 服务
- [ ] 完整工作流执行
- [ ] 错误恢复机制
- [ ] 性能优化

---

## 相关文档

- [架构白皮书](./00.ApexOS-融合架构白皮书-v2.0.md)
- [开发任务清单](./tasks.md)
- [数据库迁移](./sql/migrations/README.md)

---

## 许可证

内部项目，仅限 DeepBase 团队使用。
