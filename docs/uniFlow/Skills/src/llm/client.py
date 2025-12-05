"""
UniFlow LLM Client
==================
LiteLLM wrapper for unified LLM access.
"""

import asyncio
from dataclasses import dataclass, field
from typing import Any, AsyncIterator, Dict, List, Optional
import structlog

try:
    import litellm
    from litellm import acompletion
    LITELLM_AVAILABLE = True
except ImportError:
    LITELLM_AVAILABLE = False

logger = structlog.get_logger(__name__)

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

@dataclass
class LLMConfig:
    """LLM client configuration."""
    api_key: str = ""
    default_model: str = "gpt-4o-mini"
    timeout: float = 30.0
    max_retries: int = 3
    retry_delay: float = 1.0
    
    # Optional provider-specific settings
    azure_api_base: Optional[str] = None
    azure_api_version: Optional[str] = None
    anthropic_api_key: Optional[str] = None

# -----------------------------------------------------------------------------
# Response Models
# -----------------------------------------------------------------------------

@dataclass
class LLMMessage:
    """Chat message."""
    role: str
    content: str
    name: Optional[str] = None
    
    def to_dict(self) -> Dict[str, str]:
        """Convert to dictionary format."""
        d = {"role": self.role, "content": self.content}
        if self.name:
            d["name"] = self.name
        return d

@dataclass
class LLMResponse:
    """LLM completion response."""
    content: str
    model: str
    usage: Dict[str, int] = field(default_factory=dict)
    finish_reason: str = "stop"
    raw_response: Optional[Any] = None
    
    @classmethod
    def from_litellm(cls, response: Any) -> "LLMResponse":
        """Create from LiteLLM response."""
        choice = response.choices[0]
        return cls(
            content=choice.message.content or "",
            model=response.model,
            usage={
                "prompt_tokens": response.usage.prompt_tokens,
                "completion_tokens": response.usage.completion_tokens,
                "total_tokens": response.usage.total_tokens,
            },
            finish_reason=choice.finish_reason or "stop",
            raw_response=response
        )

@dataclass
class StreamChunk:
    """Streaming response chunk."""
    content: str
    is_final: bool = False
    finish_reason: Optional[str] = None

# -----------------------------------------------------------------------------
# LLM Client
# -----------------------------------------------------------------------------

class LLMClient:
    """
    Unified LLM client using LiteLLM.
    
    Supports:
    - Multiple providers (OpenAI, Anthropic, Azure, etc.)
    - Async operations
    - Streaming responses
    - Automatic retries
    - Token counting
    """
    
    def __init__(self, config: LLMConfig):
        """
        Initialize LLM client.
        
        Args:
            config: Client configuration
        """
        self._config = config
        self._initialized = False
        
        if not LITELLM_AVAILABLE:
            logger.warning("LiteLLM not available, LLM features disabled")
            return
            
        # Configure LiteLLM
        if config.api_key:
            litellm.api_key = config.api_key
            
        if config.azure_api_base:
            litellm.api_base = config.azure_api_base
            
        # Set timeouts
        litellm.request_timeout = config.timeout
        
        # Enable caching (optional)
        # litellm.cache = litellm.Cache()
        
        self._initialized = True
        logger.info(
            "LLM client initialized",
            default_model=config.default_model,
            timeout=config.timeout
        )
    
    @property
    def is_available(self) -> bool:
        """Check if LLM client is available."""
        return self._initialized and LITELLM_AVAILABLE
    
    async def chat(
        self,
        messages: List[Dict[str, str]],
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
        **kwargs
    ) -> LLMResponse:
        """
        Send chat completion request.
        
        Args:
            messages: List of chat messages
            model: Model to use (defaults to config default)
            temperature: Sampling temperature
            max_tokens: Maximum tokens in response
            **kwargs: Additional LiteLLM parameters
            
        Returns:
            LLMResponse with completion
            
        Raises:
            RuntimeError: If LLM not available
            Exception: On API errors
        """
        if not self.is_available:
            raise RuntimeError("LLM client not available")
        
        model = model or self._config.default_model
        
        logger.debug(
            "LLM chat request",
            model=model,
            messages_count=len(messages),
            temperature=temperature,
            max_tokens=max_tokens
        )
        
        # Retry loop
        last_error = None
        for attempt in range(self._config.max_retries):
            try:
                response = await acompletion(
                    model=model,
                    messages=messages,
                    temperature=temperature,
                    max_tokens=max_tokens,
                    **kwargs
                )
                
                result = LLMResponse.from_litellm(response)
                
                logger.info(
                    "LLM chat completed",
                    model=result.model,
                    tokens=result.usage.get("total_tokens", 0),
                    finish_reason=result.finish_reason
                )
                
                return result
                
            except Exception as e:
                last_error = e
                logger.warning(
                    "LLM request failed, retrying",
                    attempt=attempt + 1,
                    max_retries=self._config.max_retries,
                    error=str(e)
                )
                if attempt < self._config.max_retries - 1:
                    await asyncio.sleep(self._config.retry_delay * (attempt + 1))
        
        raise last_error or RuntimeError("LLM request failed")
    
    async def chat_stream(
        self,
        messages: List[Dict[str, str]],
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
        **kwargs
    ) -> AsyncIterator[StreamChunk]:
        """
        Send streaming chat completion request.
        
        Args:
            messages: List of chat messages
            model: Model to use
            temperature: Sampling temperature
            max_tokens: Maximum tokens
            **kwargs: Additional parameters
            
        Yields:
            StreamChunk for each response chunk
        """
        if not self.is_available:
            raise RuntimeError("LLM client not available")
        
        model = model or self._config.default_model
        
        logger.debug(
            "LLM stream request",
            model=model,
            messages_count=len(messages)
        )
        
        try:
            response = await acompletion(
                model=model,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
                stream=True,
                **kwargs
            )
            
            async for chunk in response:
                if chunk.choices and chunk.choices[0].delta:
                    content = chunk.choices[0].delta.content or ""
                    finish_reason = chunk.choices[0].finish_reason
                    
                    yield StreamChunk(
                        content=content,
                        is_final=finish_reason is not None,
                        finish_reason=finish_reason
                    )
                    
        except Exception as e:
            logger.error("LLM stream error", error=str(e))
            raise
    
    async def count_tokens(
        self,
        text: str,
        model: Optional[str] = None
    ) -> int:
        """
        Count tokens in text.
        
        Args:
            text: Text to count tokens for
            model: Model to use for tokenization
            
        Returns:
            Token count
        """
        if not LITELLM_AVAILABLE:
            # Rough estimate: ~4 chars per token
            return len(text) // 4
        
        try:
            model = model or self._config.default_model
            return litellm.token_counter(model=model, text=text)
        except Exception as e:
            logger.warning(f"Token counting failed: {e}, using estimate")
            return len(text) // 4
    
    async def close(self) -> None:
        """Close client and cleanup resources."""
        logger.info("LLM client closed")

# -----------------------------------------------------------------------------
# Factory Functions
# -----------------------------------------------------------------------------

def create_openai_client(api_key: str, **kwargs) -> LLMClient:
    """Create an OpenAI-configured client."""
    config = LLMConfig(
        api_key=api_key,
        default_model=kwargs.get("model", "gpt-4o-mini"),
        **kwargs
    )
    return LLMClient(config)

def create_anthropic_client(api_key: str, **kwargs) -> LLMClient:
    """Create an Anthropic-configured client."""
    config = LLMConfig(
        anthropic_api_key=api_key,
        default_model=kwargs.get("model", "claude-3-sonnet-20240229"),
        **kwargs
    )
    return LLMClient(config)

def create_azure_client(
    api_key: str,
    api_base: str,
    api_version: str = "2024-02-01",
    **kwargs
) -> LLMClient:
    """Create an Azure OpenAI-configured client."""
    config = LLMConfig(
        api_key=api_key,
        azure_api_base=api_base,
        azure_api_version=api_version,
        default_model=kwargs.get("model", "azure/gpt-4"),
        **kwargs
    )
    return LLMClient(config)

# -----------------------------------------------------------------------------
# Package Init
# -----------------------------------------------------------------------------

__all__ = [
    "LLMConfig",
    "LLMMessage",
    "LLMResponse",
    "StreamChunk",
    "LLMClient",
    "create_openai_client",
    "create_anthropic_client",
    "create_azure_client",
    "LITELLM_AVAILABLE",
]
