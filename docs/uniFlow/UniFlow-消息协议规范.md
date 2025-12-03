# UniFlow 消息协议规范

> 规范 UniFlow 内部 11 角色之间的消息格式、序列化、版本演进与安全规则。

创建日期: 2025-12-03  版本: 1.0

## 1. 目标与范围

- 目标：提供稳定、可演进、可审计的统一消息协议，使角色间通信在本地/分布式两种形态下保持一致。
- 范围：角色间的 Command/Response、Event、告警、错误回执；不包含外部系统原生协议（由通信官适配）。

## 2. 核心概念

- 消息类型：`command`（命令，需要响应）、`event`（事件，不需要直接响应）。
- 相关 ID：`id`（消息 ID）、`correlationId`（关联一次业务链路）、`traceId`（分布式追踪，OpenTelemetry）。
- 版本：`schemaVersion`（消息模式版本）、`apiVersion`（接收方接口版本）。

## 3. 消息信封（Envelope）

```json
{
  "header": {
    "id": "2a0a0f2b-8c4f-4c51-9d2d-5d4a7f7a2c79",
    "type": "command",
    "from": "dispatcher",
    "to": ["advisor"],
    "timestamp": "2025-12-03T08:20:00Z",
    "schemaVersion": "1.0",
    "apiVersion": "2025-12",
    "correlationId": "b1b8a9c7-6d2c-4a99-8b1e-1c7a5b2f9d00",
    "traceId": "c2e1f1f7d522a4a1",
    "replyTo": "dispatcher",
    "idempotencyKey": "wflw-req-12345",
    "sig": {
      "alg": "HMAC-SHA256",
      "keyId": "role:dispatcher@v1",
      "nonce": "1698912345678-xyz",
      "value": "Base64(hmac(header+body))"
    }
  },
  "body": {
    "action": "UNDERSTAND_INTENT",
    "payload": {"text": "请把这段脚本转成分镜表"},
    "context": {
      "workflowInstanceId": "wfi-00001",
      "user": {"id": "u-123", "roles": ["editor"]},
      "locale": "zh-CN"
    }
  },
  "metadata": {
    "priority": 5,
    "timeout": 120000,
    "retryPolicy": {"maxRetries": 2, "backoff": "exponential", "baseMs": 500}
  }
}
```

### 3.1 字段规则

- `id`：UUIDv4，系统内全局唯一。
- `type`：`command` | `event`。
- `from`/`to`：取值为角色枚举（见接口契约定义）。`to` 可为多个（广播事件）。
- `replyTo`：命令类消息的响应目标角色。
- `idempotencyKey`：请求幂等性键，同一键在`timeout`窗口内只执行一次。
- `schemaVersion`：消息结构版本；`apiVersion`：接口契约版本（语义化年-月）。

## 4. 序列化与大小限制

- 默认序列化：`application/json; charset=utf-8`。
- 可选：`application/x-msgpack` 或 `application/x-protobuf`（需通信官和双方支持）。
- 大小限制：
  - Header ≤ 8 KB；Body ≤ 1 MB（默认）。
  - 如需传大对象（>1 MB），使用外部存储（对象存储/DB）并在 `payload` 放置 `uri`；由通信官取回。
- 字段命名：小驼峰（camelCase）。

## 5. 命令与响应语义

- 命令必须以响应结束：成功或错误回执。
- 响应消息类型固定为 `event`，`action` 为 `COMMAND_RESULT`。
- 响应体：

```json
{
  "header": {"type": "event", "to": ["dispatcher"], "correlationId": "..."},
  "body": {
    "action": "COMMAND_RESULT",
    "payload": {"ok": true, "data": {"intent": {"type": "shotlist"}}},
    "error": null
  }
}
```

- 错误回执示例：
```json
{
  "body": {
    "action": "COMMAND_RESULT",
    "payload": null,
    "error": {"code": "AI_TIMEOUT", "message": "LLM 超时", "retryable": true}
  }
}
```

## 6. 事件语义

- 事件不要求响应；由记录员订阅以供审计。
- 关键事件：`SECURITY_ALERT`（守卫）、`WORKFLOW_STATUS_CHANGED`（调度员）、`ROLE_HEARTBEAT`（引擎）。

## 7. 版本演进与兼容

- `schemaVersion` 采用语义化：主版本变化（不兼容）、次版本（向后兼容新增）、修订（无结构变化）。
- 兼容策略：接收方必须容忍未知字段；发送方避免删除字段，用废弃标记 `deprecated: true`。

## 8. 安全与签名

- 所有命令必须携带 `sig`：对 `header` 与 `body` 的稳定序列化结果做 HMAC/ECDSA 签名。
- `nonce` + `timestamp` 防重放；通信官应拒绝过期消息（默认 5 分钟）。
- 角色身份密钥由后勤安全模块管理，支持轮换（`keyId` 版本化）。

## 9. QoS 与投递语义

- 默认 At-Most-Once；支持 At-Least-Once（开启时需接收方实现幂等处理）。
- 失败重投：遵循 `retryPolicy`；超过次数转入 DLQ（死信队列）并告警。

## 10. JSON Schema（简化）

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "UniFlowMessage",
  "type": "object",
  "properties": {
    "header": {"type": "object", "required": ["id","type","from","to","timestamp","schemaVersion"]},
    "body": {"type": "object", "required": ["action"]},
    "metadata": {"type": "object"}
  },
  "required": ["header","body"]
}
```

## 11. 示例集

- 调度员→智囊：`UNDERSTAND_INTENT`
- 智囊→军械官：`GET_PROMPT_TEMPLATE`
- 执行者→通信官：`CALL_EXTERNAL`
- 守卫→总指挥：`SECURITY_ALERT`

## 12. 与现有文档的关系

- 本文细化《UniFlow-角色图谱.md》的消息流；与《UniFlow-安全机制.md》在签名与 RBAC 上协同；与《UniFlow-错误处理策略.md》共享错误码。