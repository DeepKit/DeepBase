"""
UniFlow Skill Service
=====================
Python 服务端，提供 Skill 执行和 LLM 调用能力。

功能：
- Skill 执行引擎
- LLM 调用代理
- 健康检查

作者：鲁班（开发者）
日期：2025-12-04
版本：1.0
"""

import os
import time
import json
import asyncio
import httpx
import uvicorn
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Dict, Any, Optional, List
from datetime import datetime
from pathlib import Path


# ============== 配置 ==============

class Config:
    """Skill Service 配置"""
    HOST = os.getenv("UNIFLOW_SKILL_HOST", "127.0.0.1")
    PORT = int(os.getenv("UNIFLOW_SKILL_PORT", "8000"))
    MOCK_LLM_URL = os.getenv("UNIFLOW_MOCK_LLM_URL", "http://127.0.0.1:8766")
    USE_MOCK_AI = os.getenv("UNIFLOW_USE_MOCK_AI", "true").lower() == "true"
    DEBUG = os.getenv("UNIFLOW_DEBUG", "true").lower() == "true"


# ============== 数据模型 ==============

class SkillRequest(BaseModel):
    """Skill 执行请求"""
    skill_name: str
    input_data: Dict[str, Any]
    context: Optional[Dict[str, Any]] = None
    trace_id: Optional[str] = None


class SkillResponse(BaseModel):
    """Skill 执行响应"""
    success: bool
    output_data: Dict[str, Any]
    error: Optional[str] = None
    execution_time_ms: Optional[int] = None


class LLMRequest(BaseModel):
    """LLM 调用请求"""
    prompt: str
    max_tokens: int = 1000
    temperature: float = 0.7
    model: str = "gpt-4"
    stream: bool = False
    context: Optional[Dict[str, Any]] = None
    system_prompt: Optional[str] = None


class LLMResponse(BaseModel):
    """LLM 调用响应"""
    success: bool
    content: str = ""
    tokens_used: int = 0
    model: str = ""
    latency_ms: int = 0
    mock: bool = False
    error: Optional[str] = None


# ============== Skill 注册表 ==============

class SkillRegistry:
    """技能注册表"""
    
    def __init__(self):
        self._skills: Dict[str, callable] = {}
    
    def register(self, name: str):
        """装饰器：注册 Skill"""
        def decorator(func):
            self._skills[name] = func
            return func
        return decorator
    
    def get(self, name: str) -> Optional[callable]:
        return self._skills.get(name)
    
    def list_skills(self) -> List[str]:
        return list(self._skills.keys())


registry = SkillRegistry()


# ============== 内置 Skills ==============

@registry.register("echo")
async def skill_echo(input_data: Dict[str, Any], context: Dict[str, Any] = None) -> Dict[str, Any]:
    """回声 Skill - 用于测试"""
    return {
        "echo": input_data,
        "timestamp": datetime.now().isoformat()
    }


@registry.register("query")
async def skill_query(input_data: Dict[str, Any], context: Dict[str, Any] = None) -> Dict[str, Any]:
    """查询 Skill - 模拟数据查询"""
    query = input_data.get("query", "")
    # 模拟查询结果
    return {
        "query": query,
        "results": [
            {"id": 1, "name": "示例结果 1", "score": 0.95},
            {"id": 2, "name": "示例结果 2", "score": 0.87}
        ],
        "total": 2
    }


@registry.register("create")
async def skill_create(input_data: Dict[str, Any], context: Dict[str, Any] = None) -> Dict[str, Any]:
    """创建 Skill - 模拟资源创建"""
    resource_type = input_data.get("type", "unknown")
    data = input_data.get("data", {})
    
    # 模拟创建
    new_id = f"{resource_type}_{int(time.time())}"
    return {
        "created": True,
        "id": new_id,
        "type": resource_type,
        "data": data
    }


@registry.register("analyze")
async def skill_analyze(input_data: Dict[str, Any], context: Dict[str, Any] = None) -> Dict[str, Any]:
    """分析 Skill - 需要调用 LLM"""
    content = input_data.get("content", "")
    
    # 调用 LLM 进行分析
    llm_service = LLMService()
    llm_response = await llm_service.call(
        prompt=f"请分析以下内容：\n\n{content}",
        max_tokens=500
    )
    
    return {
        "analysis": llm_response.content if llm_response.success else "分析失败",
        "confidence": 0.85 if llm_response.success else 0,
        "llm_used": True,
        "mock": llm_response.mock
    }


# ============== LLM 服务 ==============

class LLMService:
    """LLM 调用服务"""
    
    def __init__(self):
        self.mock_url = Config.MOCK_LLM_URL
        self.use_mock = Config.USE_MOCK_AI
        self.client = httpx.AsyncClient(timeout=30.0)
    
    async def call(self, prompt: str, max_tokens: int = 1000, 
                   temperature: float = 0.7, context: Dict = None) -> LLMResponse:
        """LLM 调用"""
        start_time = time.time()
        
        try:
            if self.use_mock:
                return await self._call_mock(prompt, max_tokens, temperature)
            else:
                return await self._call_real(prompt, max_tokens, temperature, context)
        except Exception as e:
            return LLMResponse(
                success=False,
                error=str(e),
                latency_ms=int((time.time() - start_time) * 1000)
            )
    
    async def _call_mock(self, prompt: str, max_tokens: int, temperature: float) -> LLMResponse:
        """Mock LLM 调用"""
        start_time = time.time()
        
        try:
            response = await self.client.post(
                f"{self.mock_url}/execute",
                json={
                    "prompt": prompt,
                    "max_tokens": max_tokens,
                    "temperature": temperature,
                    "model": "mock-gpt-4",
                    "stream": False
                }
            )
            
            if response.status_code == 200:
                data = response.json()
                return LLMResponse(
                    success=True,
                    content=data.get("content", ""),
                    tokens_used=data.get("tokens_used", 0),
                    model=data.get("model", "mock-gpt-4"),
                    latency_ms=int((time.time() - start_time) * 1000),
                    mock=True
                )
            else:
                return LLMResponse(
                    success=False,
                    error=f"HTTP {response.status_code}",
                    latency_ms=int((time.time() - start_time) * 1000),
                    mock=True
                )
        except httpx.ConnectError:
            # Mock LLM 不可用，返回默认响应
            return LLMResponse(
                success=True,
                content=f"[Mock 离线模式] 无法连接 Mock LLM 服务\n原始输入: {prompt[:100]}...",
                tokens_used=50,
                model="mock-offline",
                latency_ms=int((time.time() - start_time) * 1000),
                mock=True
            )
    
    async def _call_real(self, prompt: str, max_tokens: int, 
                         temperature: float, context: Dict = None) -> LLMResponse:
        """真实 LLM 调用（TODO: 集成 LiteLLM）"""
        # 待实现：集成 LiteLLM 或其他 LLM 服务
        return LLMResponse(
            success=False,
            error="Real LLM not implemented yet",
            mock=False
        )


# ============== FastAPI 应用 ==============

app = FastAPI(
    title="UniFlow Skill Service",
    description="UniFlow 技能执行服务",
    version="1.0.0"
)

# CORS 配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# LLM 服务实例
llm_service = LLMService()


@app.get("/health")
async def health_check():
    """健康检查"""
    return {
        "status": "ok",
        "service": "uniflow-skills",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat(),
        "config": {
            "use_mock_ai": Config.USE_MOCK_AI,
            "mock_llm_url": Config.MOCK_LLM_URL
        }
    }


@app.get("/skills")
async def list_skills():
    """列出所有可用 Skill"""
    return {
        "skills": registry.list_skills(),
        "count": len(registry.list_skills())
    }


@app.post("/execute", response_model=SkillResponse)
async def execute_skill(request: SkillRequest):
    """执行 Skill"""
    start_time = time.time()
    
    try:
        # 查找 Skill
        skill_func = registry.get(request.skill_name)
        
        if skill_func is None:
            # 未注册的 Skill，使用 echo 作为默认
            return SkillResponse(
                success=True,
                output_data={
                    "echo": request.input_data,
                    "message": f"Skill '{request.skill_name}' not found, echoing input.",
                    "available_skills": registry.list_skills()
                },
                execution_time_ms=int((time.time() - start_time) * 1000)
            )
        
        # 执行 Skill
        result = await skill_func(request.input_data, request.context)
        
        return SkillResponse(
            success=True,
            output_data=result,
            execution_time_ms=int((time.time() - start_time) * 1000)
        )
        
    except Exception as e:
        return SkillResponse(
            success=False,
            output_data={},
            error=str(e),
            execution_time_ms=int((time.time() - start_time) * 1000)
        )


@app.post("/llm/execute", response_model=LLMResponse)
async def execute_llm(request: LLMRequest):
    """LLM 调用端点"""
    return await llm_service.call(
        prompt=request.prompt,
        max_tokens=request.max_tokens,
        temperature=request.temperature,
        context=request.context
    )


@app.post("/llm/chat")
async def chat(request: LLMRequest):
    """Chat 接口（兼容）"""
    return await execute_llm(request)


# ============== 主入口 ==============

if __name__ == "__main__":
    print(f"""
╔══════════════════════════════════════════════════════════════╗
║           UniFlow Skill Service v1.0                       ║
╠══════════════════════════════════════════════════════════════╣
║  Endpoints:                                                 ║
║    GET  /health     - 健康检查                               ║
║    GET  /skills     - 列出 Skills                            ║
║    POST /execute    - 执行 Skill                             ║
║    POST /llm/execute - LLM 调用                              ║
╠══════════════════════════════════════════════════════════════╣
║  Config:                                                    ║
║    Host: {Config.HOST}                                         ║
║    Port: {Config.PORT}                                           ║
║    Mock AI: {Config.USE_MOCK_AI}                                       ║
║    Mock LLM URL: {Config.MOCK_LLM_URL}                ║
╚══════════════════════════════════════════════════════════════╝
    """)
    
    uvicorn.run(app, host=Config.HOST, port=Config.PORT)
