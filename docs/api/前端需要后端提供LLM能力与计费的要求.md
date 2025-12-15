# 前端需要后端提供 LLM 能力与计费的 API 要求

> **文档版本**: 1.0
> **创建日期**: 2025-12-15
> **用途**: 定义 Delphi 桌面端调用 LLM 服务和查看用量统计的 API 接口规范

---

## 概述

本文档定义了 UniBase 桌面客户端（VCL/FMX）需要的 LLM 调用和用量统计相关 API 接口。

### 通用约定

- **Base URL**: `https://api.aipexbase.com` (生产) / `https://dev.aipexbase.com/api` (开发)
- **Content-Type**: `application/json`
- **认证方式**: Bearer Token (`Authorization: Bearer {access_token}`)
- **日期格式**: ISO 8601 (`yyyy-mm-ddThh:nn:ss.sssZ`)
- **货币单位**: CNY（人民币），精度 6 位小数（Token 计费精度）

---

## 一、LLM 调用 API

### 1.1 Chat Completions（对话补全）

**请求**
```
POST /api/llm/chat/completions
Authorization: Bearer {access_token}
Content-Type: application/json
```

```json
{
  "model": "gpt-4",
  "messages": [
    { "role": "system", "content": "You are a helpful assistant." },
    { "role": "user", "content": "Hello, who are you?" }
  ],
  "temperature": 0.7,
  "max_tokens": 2000,
  "stream": false
}
```

**参数说明**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| model | string | ✅ | 模型名称 |
| messages | array | ✅ | 对话消息列表 |
| temperature | number | ❌ | 温度参数 (0-2)，默认 0.7 |
| max_tokens | integer | ❌ | 最大生成 Token 数 |
| stream | boolean | ❌ | 是否流式返回，默认 false |
| top_p | number | ❌ | 核采样参数 |
| frequency_penalty | number | ❌ | 频率惩罚 (-2 to 2) |
| presence_penalty | number | ❌ | 存在惩罚 (-2 to 2) |

**messages 格式**
```json
{
  "role": "system|user|assistant",
  "content": "消息内容"
}
```

**非流式响应**
```json
{
  "success": true,
  "data": {
    "id": "chatcmpl-123456",
    "object": "chat.completion",
    "created": 1702636800,
    "model": "gpt-4",
    "choices": [
      {
        "index": 0,
        "message": {
          "role": "assistant",
          "content": "Hello! I'm an AI assistant..."
        },
        "finish_reason": "stop"
      }
    ],
    "usage": {
      "prompt_tokens": 25,
      "completion_tokens": 100,
      "total_tokens": 125
    },
    "cost": 0.003750
  }
}
```

**流式响应 (SSE)**

当 `stream: true` 时，返回 Server-Sent Events：

```
data: {"id":"chatcmpl-123","object":"chat.completion.chunk","created":1702636800,"model":"gpt-4","choices":[{"index":0,"delta":{"role":"assistant","content":"Hello"},"finish_reason":null}]}

data: {"id":"chatcmpl-123","object":"chat.completion.chunk","created":1702636800,"model":"gpt-4","choices":[{"index":0,"delta":{"content":"!"},"finish_reason":null}]}

data: {"id":"chatcmpl-123","object":"chat.completion.chunk","created":1702636800,"model":"gpt-4","choices":[{"index":0,"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":25,"completion_tokens":100,"total_tokens":125},"cost":0.003750}

data: [DONE]
```

---

### 1.2 获取可用模型列表

**请求**
```
GET /api/llm/models
Authorization: Bearer {access_token}
```

**响应**
```json
{
  "success": true,
  "data": [
    {
      "id": "gpt-4",
      "name": "GPT-4",
      "provider": "openai",
      "description": "Most capable GPT-4 model",
      "context_length": 8192,
      "pricing": {
        "input": 0.00003,
        "output": 0.00006,
        "unit": "token",
        "currency": "CNY"
      },
      "capabilities": ["chat", "function_calling"],
      "status": "available"
    },
    {
      "id": "gpt-3.5-turbo",
      "name": "GPT-3.5 Turbo",
      "provider": "openai",
      "description": "Fast and cost-effective",
      "context_length": 16384,
      "pricing": {
        "input": 0.000001,
        "output": 0.000002,
        "unit": "token",
        "currency": "CNY"
      },
      "capabilities": ["chat"],
      "status": "available"
    },
    {
      "id": "claude-3-opus",
      "name": "Claude 3 Opus",
      "provider": "anthropic",
      "description": "Most powerful Claude model",
      "context_length": 200000,
      "pricing": {
        "input": 0.00015,
        "output": 0.00075,
        "unit": "token",
        "currency": "CNY"
      },
      "capabilities": ["chat", "vision"],
      "status": "available"
    }
  ]
}
```

**字段说明**

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 模型 ID（调用时使用） |
| name | string | 模型显示名称 |
| provider | string | 提供商：openai/anthropic/google/... |
| description | string | 模型描述 |
| context_length | integer | 上下文窗口大小 |
| pricing.input | number | 输入 Token 单价 |
| pricing.output | number | 输出 Token 单价 |
| capabilities | array | 能力列表：chat/vision/function_calling |
| status | string | 状态：available/maintenance/deprecated |

---

### 1.3 计算 Token 数量

**请求**
```
POST /api/llm/tokenize
Authorization: Bearer {access_token}
Content-Type: application/json
```

```json
{
  "model": "gpt-4",
  "messages": [
    { "role": "user", "content": "Hello, world!" }
  ]
}
```

**响应**
```json
{
  "success": true,
  "data": {
    "token_count": 15,
    "estimated_cost": 0.000450
  }
}
```

---

## 二、用量统计 API

### 2.1 获取用量汇总

**请求**
```
GET /api/usage/summary?start=2025-12-01&end=2025-12-15
Authorization: Bearer {access_token}
```

**参数**

| 参数 | 类型 | 说明 |
|------|------|------|
| start | string | 开始日期 (yyyy-mm-dd) |
| end | string | 结束日期 (yyyy-mm-dd) |

**响应**
```json
{
  "success": true,
  "data": {
    "total_calls": 1500,
    "input_tokens": 500000,
    "output_tokens": 200000,
    "total_cost": 25.50,
    "period_start": "2025-12-01T00:00:00Z",
    "period_end": "2025-12-15T23:59:59Z"
  }
}
```

---

### 2.2 获取用量趋势

**请求**
```
GET /api/usage/trend?start=2025-12-01&end=2025-12-15&group_by=day
Authorization: Bearer {access_token}
```

**参数**

| 参数 | 类型 | 说明 |
|------|------|------|
| start | string | 开始日期 |
| end | string | 结束日期 |
| group_by | string | 分组方式：day/week/month |

**响应**
```json
{
  "success": true,
  "data": [
    {
      "date": "2025-12-01",
      "calls": 100,
      "input_tokens": 35000,
      "output_tokens": 12000,
      "cost": 1.80
    },
    {
      "date": "2025-12-02",
      "calls": 120,
      "input_tokens": 40000,
      "output_tokens": 15000,
      "cost": 2.10
    }
  ]
}
```

---

### 2.3 获取模型用量分布

**请求**
```
GET /api/usage/models?start=2025-12-01&end=2025-12-15
Authorization: Bearer {access_token}
```

**响应**
```json
{
  "success": true,
  "data": [
    {
      "model": "gpt-4",
      "calls": 500,
      "tokens": 250000,
      "cost": 15.00,
      "percentage": 58.82
    },
    {
      "model": "gpt-3.5-turbo",
      "calls": 800,
      "tokens": 400000,
      "cost": 8.00,
      "percentage": 31.37
    },
    {
      "model": "claude-3-opus",
      "calls": 200,
      "tokens": 50000,
      "cost": 2.50,
      "percentage": 9.80
    }
  ]
}
```

---

### 2.4 获取最近调用记录

**请求**
```
GET /api/usage/calls?limit=20
Authorization: Bearer {access_token}
```

**响应**
```json
{
  "success": true,
  "data": [
    {
      "call_id": "call_abc123",
      "model": "gpt-4",
      "input_tokens": 500,
      "output_tokens": 200,
      "duration": 1500,
      "cost": 0.021,
      "status": "success",
      "created_at": "2025-12-15T10:30:00Z"
    },
    {
      "call_id": "call_def456",
      "model": "gpt-3.5-turbo",
      "input_tokens": 300,
      "output_tokens": 150,
      "duration": 800,
      "cost": 0.0006,
      "status": "success",
      "created_at": "2025-12-15T10:25:00Z"
    }
  ]
}
```

**字段说明**

| 字段 | 类型 | 说明 |
|------|------|------|
| call_id | string | 调用唯一 ID |
| model | string | 使用的模型 |
| input_tokens | integer | 输入 Token 数 |
| output_tokens | integer | 输出 Token 数 |
| duration | integer | 调用耗时（毫秒） |
| cost | number | 本次调用费用 |
| status | string | 状态：success/error/timeout |
| created_at | string | 调用时间 |

---

## 三、计费规则

### 3.1 计费方式

- **按 Token 计费**: 每次 API 调用按实际使用的 Token 数计费
- **输入/输出分开计价**: 输入 Token 和输出 Token 价格不同
- **实时扣费**: 调用完成后立即从余额扣除

### 3.2 计费公式

```
费用 = 输入Token数 × 输入单价 + 输出Token数 × 输出单价
```

### 3.3 余额不足处理

当用户余额不足时：
- API 返回 HTTP 402 Payment Required
- 响应体包含 `error_code: "BALANCE_INSUFFICIENT"`
- 前端提示用户充值

**示例响应**
```json
{
  "success": false,
  "error_code": "BALANCE_INSUFFICIENT",
  "message": "余额不足，请充值后重试",
  "data": {
    "current_balance": 0.50,
    "estimated_cost": 1.20,
    "shortfall": 0.70
  }
}
```

---

## 四、错误码参考

| 错误码 | HTTP 状态码 | 说明 |
|--------|-------------|------|
| LLM_MODEL_NOT_FOUND | 400 | 模型不存在 |
| LLM_MODEL_UNAVAILABLE | 503 | 模型暂时不可用 |
| LLM_CONTEXT_TOO_LONG | 400 | 上下文超出限制 |
| LLM_RATE_LIMITED | 429 | 请求频率超限 |
| LLM_CONTENT_FILTERED | 400 | 内容被安全过滤 |
| BALANCE_INSUFFICIENT | 402 | 余额不足 |
| AUTH_TOKEN_EXPIRED | 401 | Token 已过期 |
| INTERNAL_ERROR | 500 | 服务器内部错误 |

---

## 五、流式响应处理

### 前端处理流程

1. 发送请求时设置 `stream: true`
2. 接收 SSE (Server-Sent Events) 数据流
3. 逐块解析 JSON 数据
4. 拼接 `delta.content` 构建完整回复
5. 收到 `[DONE]` 时结束

### Delphi 实现要点

```pascal
// 伪代码示例
procedure HandleStreamResponse(const Line: string);
var
  Json: TJSONObject;
  Delta: TJSONObject;
  Content: string;
begin
  if Line.StartsWith('data: ') then
  begin
    var Data := Line.Substring(6);
    if Data = '[DONE]' then
    begin
      // 流结束
      OnStreamComplete;
      Exit;
    end;
    
    Json := TJSONObject.ParseJSONValue(Data) as TJSONObject;
    if Assigned(Json) then
    try
      // 提取增量内容
      if Json.TryGetValue('choices[0].delta', Delta) then
        if Delta.TryGetValue('content', Content) then
          OnContentReceived(Content);
    finally
      Json.Free;
    end;
  end;
end;
```

---

## 六、对接检查清单

### 后端需要提供

**LLM 调用**
- [ ] POST `/api/llm/chat/completions` - 对话补全（支持流式）
- [ ] GET `/api/llm/models` - 获取可用模型列表
- [ ] POST `/api/llm/tokenize` - 计算 Token 数量

**用量统计**
- [ ] GET `/api/usage/summary` - 获取用量汇总
- [ ] GET `/api/usage/trend` - 获取用量趋势
- [ ] GET `/api/usage/models` - 获取模型用量分布
- [ ] GET `/api/usage/calls` - 获取最近调用记录

### 前端已实现

- [x] `UniBase.LLM.Client.pas` - LLM 客户端
- [x] `UniBase.VCL.LLMChatFrame.pas` - VCL 聊天界面
- [x] `UniBase.FMX.LLMChatFrame.pas` - FMX 聊天界面
- [x] `UniBase.VCL.UsageStatsFrame.pas` - VCL 用量统计
- [x] `UniBase.FMX.UsageStatsFrame.pas` - FMX 用量统计

---

## 七、WebSocket 实时通知（可选）

如果后端支持 WebSocket，可用于：
- 余额变动通知
- 调用完成通知
- 系统公告推送

**连接地址**
```
wss://api.aipexbase.com/ws?token={access_token}
```

**消息格式**
```json
{
  "type": "balance_changed",
  "data": {
    "old_balance": 100.00,
    "new_balance": 99.50,
    "change": -0.50,
    "reason": "LLM API 调用"
  }
}
```

> 注：WebSocket 为可选功能，前端主要通过轮询或手动刷新获取最新数据。
