# Delphi 前端 - LLM 能力与计费 API 接口文档

> 版本: v1.1
> 更新日期: 2025-12-15
> 后端实现状态: Phase 5-6 开发中

## 1. 概述

### 1.1 基础信息
| 项目 | 开发环境 | 生产环境 |
|------|----------|----------|
| 基础 URL | http://localhost:8090 | https://api.aipexbase.com |
| 认证方式 | Bearer Token | Bearer Token |
| 内容类型 | application/json | application/json |
| 字符编码 | UTF-8 | UTF-8 |

### 1.2 通用请求头
```
Authorization: Bearer {access_token}
Content-Type: application/json
X-App-Id: {app_id}  // 可选，指定应用
```

### 1.3 通用响应格式
```json
{
  "success": true,
  "message": "操作成功",
  "data": { ... },
  "error_code": null
}
```

---

## 2. LLM 调用接口

### 2.1 聊天补全
**POST** `/api/llm/chat/completions`

#### 请求体
```json
{
  "model": "deepseek-ai/DeepSeek-V3",
  "messages": [
    {"role": "system", "content": "你是一个有帮助的助手"},
    {"role": "user", "content": "你好"}
  ],
  "temperature": 0.7,
  "max_tokens": 2048,
  "stream": false,
  "top_p": 0.9,
  "frequency_penalty": 0,
  "presence_penalty": 0
}
```

#### 非流式响应
```json
{
  "success": true,
  "data": {
    "id": "chatcmpl-xxxxx",
    "object": "chat.completion",
    "created": 1734567890,
    "model": "deepseek-ai/DeepSeek-V3",
    "choices": [
      {
        "index": 0,
        "message": {
          "role": "assistant",
          "content": "你好！有什么我可以帮助你的吗？"
        },
        "finish_reason": "stop"
      }
    ],
    "usage": {
      "prompt_tokens": 20,
      "completion_tokens": 15,
      "total_tokens": 35
    },
    "cost": {
      "input_cost": 0.000028,
      "output_cost": 0.000021,
      "total_cost": 0.000049,
      "currency": "CNY"
    }
  }
}
```

#### 流式响应 (stream=true)
```
data: {"id":"chatcmpl-xxx","choices":[{"delta":{"role":"assistant"},"index":0}]}

data: {"id":"chatcmpl-xxx","choices":[{"delta":{"content":"你"},"index":0}]}

data: {"id":"chatcmpl-xxx","choices":[{"delta":{"content":"好"},"index":0}]}

data: {"id":"chatcmpl-xxx","choices":[{"delta":{},"finish_reason":"stop","index":0}],"usage":{"prompt_tokens":20,"completion_tokens":15,"total_tokens":35}}

data: [DONE]
```

### 2.2 获取可用模型列表
**GET** `/api/llm/models`

#### 响应
```json
{
  "success": true,
  "data": [
    {
      "id": "deepseek-ai/DeepSeek-V3",
      "name": "DeepSeek-V3",
      "provider": "siliconflow",
      "description": "DeepSeek 最新大模型",
      "context_length": 64000,
      "pricing": {
        "input": 0.0014,
        "output": 0.0014,
        "unit": "1K tokens",
        "currency": "CNY"
      },
      "capabilities": ["chat", "reasoning"],
      "status": "available"
    }
  ]
}
```

### 2.3 Token 计数与费用预估
**POST** `/api/llm/tokenize`

#### 请求体
```json
{
  "model": "deepseek-ai/DeepSeek-V3",
  "messages": [
    {"role": "user", "content": "你好，请帮我写一篇文章"}
  ]
}
```

#### 响应
```json
{
  "success": true,
  "data": {
    "token_count": 15,
    "estimated_cost": {
      "min": 0.000021,
      "max": 0.0021,
      "currency": "CNY"
    }
  }
}
```

---

## 3. 使用统计接口

### 3.1 汇总统计
**GET** `/api/usage/summary?start=2025-12-01&end=2025-12-15`

#### 响应
```json
{
  "success": true,
  "data": {
    "total_calls": 1250,
    "total_input_tokens": 125000,
    "total_output_tokens": 87500,
    "total_cost": 156.78,
    "currency": "CNY",
    "period_start": "2025-12-01",
    "period_end": "2025-12-15"
  }
}
```

### 3.2 趋势数据
**GET** `/api/usage/trend?start=2025-12-01&end=2025-12-15&group_by=day`

#### 响应
```json
{
  "success": true,
  "data": [
    {
      "date": "2025-12-01",
      "calls": 85,
      "input_tokens": 8500,
      "output_tokens": 5950,
      "cost": 10.23
    },
    {
      "date": "2025-12-02",
      "calls": 92,
      "input_tokens": 9200,
      "output_tokens": 6440,
      "cost": 11.05
    }
  ]
}
```

### 3.3 按模型统计
**GET** `/api/usage/models?start=2025-12-01&end=2025-12-15`

#### 响应
```json
{
  "success": true,
  "data": [
    {
      "model": "deepseek-ai/DeepSeek-V3",
      "calls": 800,
      "tokens": 160000,
      "cost": 100.50,
      "percentage": 64.0
    },
    {
      "model": "Qwen/Qwen2.5-72B-Instruct",
      "calls": 450,
      "tokens": 52500,
      "cost": 56.28,
      "percentage": 36.0
    }
  ]
}
```

### 3.4 最近调用记录
**GET** `/api/usage/calls?limit=20`

#### 响应
```json
{
  "success": true,
  "data": [
    {
      "call_id": "call-xxxxx",
      "model": "deepseek-ai/DeepSeek-V3",
      "input_tokens": 120,
      "output_tokens": 85,
      "duration_ms": 1250,
      "cost": 0.000287,
      "status": "success",
      "created_at": "2025-12-15T10:30:00Z"
    }
  ]
}
```

---

## 4. 计费说明

### 4.1 计费公式
```
费用 = 输入Token数 × 输入单价 + 输出Token数 × 输出单价
```

### 4.2 扣费优先级
1. 次数额度 (call_quota) - 如果有次卡额度，优先扣次数
2. 时长额度 (time_quota) - 如果有时卡额度，按时长扣费
3. 余额 (balance) - 扣余额
4. 后付费 (postpaid) - 如果开通后付费，允许透支

### 4.3 余额不足响应
**HTTP 402 Payment Required**
```json
{
  "success": false,
  "error_code": "BALANCE_INSUFFICIENT",
  "message": "余额不足",
  "data": {
    "current_balance": 0.50,
    "estimated_cost": 1.20,
    "shortfall": 0.70
  }
}
```

---

## 5. 错误码

| 错误码 | HTTP状态码 | 说明 |
|--------|-----------|------|
| LLM_MODEL_NOT_FOUND | 400 | 模型不存在 |
| LLM_MODEL_UNAVAILABLE | 503 | 模型暂不可用 |
| LLM_CONTEXT_TOO_LONG | 400 | 上下文超长 |
| LLM_RATE_LIMITED | 429 | 请求频率限制 |
| LLM_CONTENT_FILTERED | 400 | 内容被过滤 |
| BALANCE_INSUFFICIENT | 402 | 余额不足 |
| AUTH_TOKEN_EXPIRED | 401 | Token已过期 |
| AUTH_TOKEN_INVALID | 401 | Token无效 |
| INTERNAL_ERROR | 500 | 内部错误 |

---

## 6. Delphi 集成示例

### 6.1 SSE 流式处理
```pascal
procedure TLLMClient.HandleSSEResponse(const AStream: TStream);
var
  Reader: TStreamReader;
  Line, Data: string;
  JSON: TJSONObject;
  Content: string;
begin
  Reader := TStreamReader.Create(AStream, TEncoding.UTF8);
  try
    while not Reader.EndOfStream do
    begin
      Line := Reader.ReadLine;
      if Line.StartsWith('data: ') then
      begin
        Data := Line.Substring(6);
        if Data = '[DONE]' then
        begin
          // 流结束
          if Assigned(FOnComplete) then
            FOnComplete(Self);
          Break;
        end;
        
        JSON := TJSONObject.ParseJSONValue(Data) as TJSONObject;
        try
          Content := JSON.GetValue<string>('choices[0].delta.content');
          if Content <> '' then
          begin
            if Assigned(FOnContent) then
              FOnContent(Self, Content);
          end;
        finally
          JSON.Free;
        end;
      end;
    end;
  finally
    Reader.Free;
  end;
end;
```

### 6.2 错误处理
```pascal
procedure TLLMClient.HandleError(const AResponse: IHTTPResponse);
var
  JSON: TJSONObject;
  ErrorCode, Message: string;
begin
  JSON := TJSONObject.ParseJSONValue(AResponse.ContentAsString) as TJSONObject;
  try
    ErrorCode := JSON.GetValue<string>('error_code');
    Message := JSON.GetValue<string>('message');
    
    case AResponse.StatusCode of
      401: raise EAuthException.Create(Message);
      402: raise EBalanceException.Create(Message);
      429: raise ERateLimitException.Create(Message);
      else raise ELLMException.Create(Message);
    end;
  finally
    JSON.Free;
  end;
end;
```

---

## 7. 后端实现进度

| 接口 | 状态 | 备注 |
|------|------|------|
| POST /api/llm/chat/completions | ⏳ Phase 5 | 增强路由和计费 |
| GET /api/llm/models | ⏳ Phase 6 | 待实现 |
| POST /api/llm/tokenize | ⏳ Phase 6 | 待实现 |
| GET /api/usage/summary | ⏳ Phase 6 | 待实现 |
| GET /api/usage/trend | ⏳ Phase 6 | 待实现 |
| GET /api/usage/models | ⏳ Phase 6 | 待实现 |
| GET /api/usage/calls | ⏳ Phase 6 | 待实现 |

---

## 8. WebSocket 实时通知 (可选)

### 连接地址
```
wss://api.aipexbase.com/ws?token={access_token}
```

### 消息类型
```json
{
  "type": "balance_changed",
  "data": {
    "balance": 88.50,
    "change": -1.50,
    "reason": "LLM调用"
  }
}
```
