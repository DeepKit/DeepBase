# Design Document: Feedback Backend Service

## Overview

本设计文档描述 UniBase 用户反馈后端服务的技术架构和实现方案。

**推荐方案：基于 AipexBase 平台开发**

经过评估，使用 AipexBase 平台可以大幅减少开发工作量：
- 动态数据引擎提供自动 CRUD
- 内置 API Key 认证
- 统一文件存储服务
- 聚合统计功能

技术栈：
- **平台**: AipexBase BaaS
- **数据引擎**: 动态数据引擎（自动 CRUD）
- **认证**: API Key（CODE_FLYING header）
- **文件存储**: AipexBase 文件服务
- **测试**: pytest + hypothesis（属性测试）

如需独立部署，备选方案：
- **框架**: FastAPI 0.100+
- **数据库**: PostgreSQL + SQLAlchemy ORM
- **缓存**: Redis
- **认证**: API Key + JWT

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     UniBase Client (Delphi)                      │
│                    UniBase.Feedback.pas                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ HTTPS
┌─────────────────────────────────────────────────────────────────┐
│                      API Gateway / Nginx                         │
│                    (Rate Limiting, SSL)                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FastAPI Application                           │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Routers    │  │  Middleware  │  │   Schemas    │          │
│  │  /feedback   │  │  Auth/CORS   │  │   Pydantic   │          │
│  │  /comments   │  │  RateLimit   │  │   Models     │          │
│  │  /notify     │  │  Logging     │  │              │          │
│  │  /admin      │  │              │  │              │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Services   │  │ Repositories │  │    Utils     │          │
│  │  Feedback    │  │  SQLAlchemy  │  │  TrackCode   │          │
│  │  Comment     │  │  CRUD Ops    │  │  FileStore   │          │
│  │  Notify      │  │              │  │  Validators  │          │
│  │  Stats       │  │              │  │              │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
       ┌───────────┐   ┌───────────┐   ┌───────────┐
       │PostgreSQL │   │   Redis   │   │  Storage  │
       │ Database  │   │  (Cache)  │   │  (Files)  │
       └───────────┘   └───────────┘   └───────────┘
```

## Components and Interfaces

### 1. API Routers

#### 1.1 Feedback Router (`/api/v1/feedback`)

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/` | 提交新反馈 | API Key |
| GET | `/` | 获取用户反馈列表 | API Key |
| GET | `/{feedback_id}` | 获取反馈详情 | API Key |
| GET | `/track/{tracking_code}` | 通过追踪码查询 | API Key |
| POST | `/{feedback_id}/attachments` | 上传附件 | API Key |
| GET | `/{feedback_id}/attachments/{attachment_id}` | 下载附件 | API Key |

#### 1.2 Comment Router (`/api/v1/comments`)

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/feedback/{feedback_id}` | 获取反馈评论列表 | API Key |
| POST | `/feedback/{feedback_id}` | 添加评论 | API Key |

#### 1.3 Notification Router (`/api/v1/notifications`)

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/` | 获取用户通知列表 | API Key |
| GET | `/unread/count` | 获取未读数量 | API Key |
| PUT | `/{notification_id}/read` | 标记单个已读 | API Key |
| PUT | `/read-all` | 标记全部已读 | API Key |

#### 1.4 Admin Router (`/api/v1/admin`)

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/feedbacks` | 管理端反馈列表（支持筛选） | Admin |
| PUT | `/feedbacks/{feedback_id}/status` | 更新反馈状态 | Admin |
| PUT | `/feedbacks/{feedback_id}/assign` | 分配处理人 | Admin |
| POST | `/feedbacks/{feedback_id}/comments` | 客服添加评论 | Admin |
| GET | `/stats/overview` | 统计概览 | Admin |
| GET | `/stats/by-type` | 按类型统计 | Admin |
| GET | `/stats/trend` | 趋势统计 | Admin |
| GET | `/stats/efficiency` | 效率统计 | Admin |

### 2. Services Layer

```python
# feedback_service.py
class FeedbackService:
    async def create_feedback(self, data: FeedbackCreate, user_id: str) -> Feedback
    async def get_feedback(self, feedback_id: str, user_id: str) -> Feedback
    async def get_user_feedbacks(self, user_id: str, params: PaginationParams) -> Page[Feedback]
    async def search_by_tracking_code(self, code: str) -> Feedback
    async def update_status(self, feedback_id: str, status: FeedbackStatus) -> Feedback
    async def assign_feedback(self, feedback_id: str, assignee_id: str) -> Feedback

# comment_service.py
class CommentService:
    async def add_comment(self, feedback_id: str, content: str, author: User) -> Comment
    async def get_comments(self, feedback_id: str) -> List[Comment]

# notification_service.py
class NotificationService:
    async def create_notification(self, user_id: str, type: NotificationType, ...) -> Notification
    async def get_user_notifications(self, user_id: str) -> List[Notification]
    async def mark_read(self, notification_id: str, user_id: str) -> None
    async def mark_all_read(self, user_id: str) -> int
    async def get_unread_count(self, user_id: str) -> int

# attachment_service.py
class AttachmentService:
    async def upload(self, feedback_id: str, file: UploadFile) -> Attachment
    async def download(self, attachment_id: str, user_id: str) -> FileResponse
    async def validate_size(self, file_size: int, feedback_id: str) -> bool
```

### 3. Middleware

```python
# auth_middleware.py
class APIKeyMiddleware:
    """验证 X-API-Key 请求头"""

# rate_limit_middleware.py  
class RateLimitMiddleware:
    """基于 IP/API Key 的请求限流"""

# logging_middleware.py
class RequestLoggingMiddleware:
    """请求日志记录"""
```

## Data Models

### Database Schema (SQLAlchemy)

```python
# models/feedback.py
class Feedback(Base):
    __tablename__ = "feedbacks"
    
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    feedback_type: Mapped[str] = mapped_column(String(20))  # Bug, Feature, etc.
    priority: Mapped[str] = mapped_column(String(20), default="Normal")
    status: Mapped[str] = mapped_column(String(20), default="New")
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text)
    steps_to_reproduce: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    expected_behavior: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    actual_behavior: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    user_id: Mapped[str] = mapped_column(String(100))
    user_email: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    user_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    tracking_code: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    assignee_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    submitted_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    
    # Relationships
    system_info: Mapped["SystemInfo"] = relationship(back_populates="feedback", uselist=False)
    attachments: Mapped[List["Attachment"]] = relationship(back_populates="feedback")
    comments: Mapped[List["Comment"]] = relationship(back_populates="feedback")
    tags: Mapped[List["FeedbackTag"]] = relationship(back_populates="feedback")

# models/system_info.py
class SystemInfo(Base):
    __tablename__ = "system_infos"
    
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    feedback_id: Mapped[str] = mapped_column(ForeignKey("feedbacks.id"))
    os_name: Mapped[Optional[str]] = mapped_column(String(50))
    os_version: Mapped[Optional[str]] = mapped_column(String(50))
    os_architecture: Mapped[Optional[str]] = mapped_column(String(20))
    cpu_name: Mapped[Optional[str]] = mapped_column(String(100))
    cpu_cores: Mapped[Optional[int]] = mapped_column(Integer)
    ram_total_mb: Mapped[Optional[int]] = mapped_column(Integer)
    ram_free_mb: Mapped[Optional[int]] = mapped_column(Integer)
    disk_total_mb: Mapped[Optional[int]] = mapped_column(Integer)
    disk_free_mb: Mapped[Optional[int]] = mapped_column(Integer)
    screen_width: Mapped[Optional[int]] = mapped_column(Integer)
    screen_height: Mapped[Optional[int]] = mapped_column(Integer)
    app_version: Mapped[Optional[str]] = mapped_column(String(50))
    app_build_date: Mapped[Optional[str]] = mapped_column(String(50))
    delphi_version: Mapped[Optional[str]] = mapped_column(String(50))
    user_locale: Mapped[Optional[str]] = mapped_column(String(20))
    time_zone: Mapped[Optional[str]] = mapped_column(String(50))
    
    feedback: Mapped["Feedback"] = relationship(back_populates="system_info")

# models/attachment.py
class Attachment(Base):
    __tablename__ = "attachments"
    
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    feedback_id: Mapped[str] = mapped_column(ForeignKey("feedbacks.id"))
    file_name: Mapped[str] = mapped_column(String(255))
    file_size: Mapped[int] = mapped_column(BigInteger)
    mime_type: Mapped[str] = mapped_column(String(100))
    storage_path: Mapped[str] = mapped_column(String(500))
    remote_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    uploaded_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    
    feedback: Mapped["Feedback"] = relationship(back_populates="attachments")

# models/comment.py
class Comment(Base):
    __tablename__ = "comments"
    
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    feedback_id: Mapped[str] = mapped_column(ForeignKey("feedbacks.id"))
    author_id: Mapped[str] = mapped_column(String(100))
    author_name: Mapped[str] = mapped_column(String(100))
    content: Mapped[str] = mapped_column(Text)
    is_staff: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    
    feedback: Mapped["Feedback"] = relationship(back_populates="comments")

# models/notification.py
class Notification(Base):
    __tablename__ = "notifications"
    
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(100), index=True)
    notification_type: Mapped[str] = mapped_column(String(20))
    title: Mapped[str] = mapped_column(String(200))
    message: Mapped[str] = mapped_column(Text)
    feedback_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    read_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
```

### Pydantic Schemas (API Models)

```python
# schemas/feedback.py
class FeedbackCreate(BaseModel):
    feedback_type: FeedbackType = Field(alias="feedbackType")
    priority: FeedbackPriority = FeedbackPriority.NORMAL
    title: str = Field(min_length=1, max_length=200)
    description: str = Field(min_length=1)
    steps_to_reproduce: Optional[str] = Field(None, alias="stepsToReproduce")
    expected_behavior: Optional[str] = Field(None, alias="expectedBehavior")
    actual_behavior: Optional[str] = Field(None, alias="actualBehavior")
    user_email: Optional[str] = Field(None, alias="userEmail")
    user_name: Optional[str] = Field(None, alias="userName")
    system_info: Optional[SystemInfoSchema] = Field(None, alias="systemInfo")
    tags: List[str] = []
    
    class Config:
        populate_by_name = True

class FeedbackResponse(BaseModel):
    id: str
    feedback_type: FeedbackType = Field(serialization_alias="feedbackType")
    priority: FeedbackPriority
    status: FeedbackStatus
    title: str
    description: str
    steps_to_reproduce: Optional[str] = Field(serialization_alias="stepsToReproduce")
    expected_behavior: Optional[str] = Field(serialization_alias="expectedBehavior")
    actual_behavior: Optional[str] = Field(serialization_alias="actualBehavior")
    user_id: str = Field(serialization_alias="userId")
    user_email: Optional[str] = Field(serialization_alias="userEmail")
    user_name: Optional[str] = Field(serialization_alias="userName")
    tracking_code: str = Field(serialization_alias="trackingCode")
    system_info: Optional[SystemInfoSchema] = Field(serialization_alias="systemInfo")
    attachments: List[AttachmentSchema] = []
    tags: List[str] = []
    created_at: datetime = Field(serialization_alias="createdAt")
    updated_at: datetime = Field(serialization_alias="updatedAt")
    submitted_at: Optional[datetime] = Field(serialization_alias="submittedAt")
    is_submitted: bool = Field(serialization_alias="isSubmitted")
    
    class Config:
        from_attributes = True
        populate_by_name = True

# schemas/enums.py
class FeedbackType(str, Enum):
    BUG = "Bug"
    FEATURE = "Feature"
    QUESTION = "Question"
    IMPROVEMENT = "Improvement"
    CRASH = "Crash"
    PERFORMANCE = "Performance"
    OTHER = "Other"

class FeedbackPriority(str, Enum):
    LOW = "Low"
    NORMAL = "Normal"
    HIGH = "High"
    CRITICAL = "Critical"

class FeedbackStatus(str, Enum):
    NEW = "New"
    PENDING = "Pending"
    IN_PROGRESS = "InProgress"
    RESOLVED = "Resolved"
    CLOSED = "Closed"
    REJECTED = "Rejected"

class NotificationType(str, Enum):
    STATUS_CHANGE = "StatusChange"
    COMMENT = "Comment"
    ASSIGNMENT = "Assignment"
    RESOLUTION = "Resolution"
    ANNOUNCEMENT = "Announcement"
    REMINDER = "Reminder"
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

基于前置分析，以下是经过去重和合并后的核心正确性属性：

### Property 1: 反馈提交完整性
*For any* 有效的反馈数据（包含非空标题和描述），提交后系统应返回唯一的反馈 ID 和格式为 TRK-YYYY-XXXXXX 的追踪码，且反馈状态为 New
**Validates: Requirements 1.1, 1.3, 1.5**

### Property 2: 反馈验证拒绝
*For any* 缺少必填字段（标题或描述为空/纯空白）的反馈数据，提交时系统应返回 400 错误码和具体的验证错误信息
**Validates: Requirements 1.2**

### Property 3: 系统信息关联存储
*For any* 包含系统信息的反馈，提交后查询该反馈时应能获取到完整的系统信息
**Validates: Requirements 1.4, 3.5**

### Property 4: 附件上传与元数据记录
*For any* 有效的附件文件（大小在限制内），上传后系统应返回附件 ID 和访问 URL，并正确记录文件名、大小、MIME 类型
**Validates: Requirements 2.1, 2.4**

### Property 5: 附件权限验证
*For any* 附件下载请求，系统应验证请求者是反馈所有者或管理员，否则返回 403 错误
**Validates: Requirements 2.5, 8.3**

### Property 6: 追踪码查询一致性
*For any* 已提交的反馈，通过其追踪码查询应返回完整的反馈详情，包括状态、评论、附件和系统信息
**Validates: Requirements 3.1, 3.5**

### Property 7: 用户反馈列表分页
*For any* 用户的反馈列表查询，系统应正确支持分页参数，返回的结果数量不超过 pageSize，且按指定排序
**Validates: Requirements 3.2, 3.4**

### Property 8: 评论创建与排序
*For any* 反馈的评论列表，评论应按创建时间升序排列，用户评论的 isStaff=false，客服评论的 isStaff=true
**Validates: Requirements 4.1, 4.2, 4.3**

### Property 9: 空评论拒绝
*For any* 内容为空或纯空白的评论，系统应拒绝添加并返回验证错误
**Validates: Requirements 4.4**

### Property 10: 评论触发通知
*For any* 成功添加的评论，系统应为相关方创建通知（用户评论通知客服，客服评论通知用户）
**Validates: Requirements 4.5, 5.1**

### Property 11: 通知列表排序与已读状态
*For any* 用户的通知列表，通知应按创建时间倒序排列；标记已读后，isRead=true 且 readAt 有值
**Validates: Requirements 5.2, 5.3**

### Property 12: 未读通知计数准确性
*For any* 用户，未读通知数量应等于该用户 isRead=false 的通知总数
**Validates: Requirements 5.4**

### Property 13: 批量标记已读
*For any* 用户执行批量标记已读操作后，该用户所有通知的 isRead 应为 true
**Validates: Requirements 5.5**

### Property 14: 状态变更记录
*For any* 反馈状态变更操作，updatedAt 时间戳应更新，且变更为 Resolved 时应创建解决通知
**Validates: Requirements 6.1, 6.2**

### Property 15: 已关闭反馈评论限制
*For any* 状态为 Closed 或 Rejected 的反馈，用户添加评论应被拒绝
**Validates: Requirements 6.5**

### Property 16: 反馈筛选功能
*For any* 管理端反馈列表查询，按类型/优先级/状态筛选后的结果应只包含符合条件的反馈
**Validates: Requirements 6.4**

### Property 17: 统计数据准确性
*For any* 统计查询，返回的各状态/类型数量应与数据库中实际数量一致
**Validates: Requirements 7.1, 7.2**

### Property 18: API 认证
*For any* API 请求，缺少或无效的 API Key 应返回 401 错误码
**Validates: Requirements 8.1, 8.2**

### Property 19: 管理员权限验证
*For any* 管理端 API 调用，非管理员用户应返回 403 错误码
**Validates: Requirements 8.4**

### Property 20: JSON 序列化往返一致性
*For any* 有效的反馈数据，序列化为 JSON 后再反序列化应产生等价的数据对象，字段使用 camelCase，日期使用 ISO 8601 格式，枚举使用字符串
**Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5**

## Error Handling

### HTTP Status Codes

| Code | Scenario |
|------|----------|
| 200 | 成功 |
| 201 | 创建成功 |
| 400 | 请求数据验证失败 |
| 401 | API Key 无效或缺失 |
| 403 | 无权限访问资源 |
| 404 | 资源不存在 |
| 413 | 文件大小超限 |
| 429 | 请求频率超限 |
| 500 | 服务器内部错误 |

### Error Response Format

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "请求数据验证失败",
    "details": [
      {"field": "title", "message": "标题不能为空"},
      {"field": "description", "message": "描述不能为空"}
    ]
  }
}
```

### Exception Handlers

```python
@app.exception_handler(ValidationError)
async def validation_exception_handler(request, exc):
    return JSONResponse(status_code=400, content={"error": {...}})

@app.exception_handler(NotFoundError)
async def not_found_exception_handler(request, exc):
    return JSONResponse(status_code=404, content={"error": {...}})

@app.exception_handler(ForbiddenError)
async def forbidden_exception_handler(request, exc):
    return JSONResponse(status_code=403, content={"error": {...}})
```

## Testing Strategy

### 测试框架

- **单元测试**: pytest
- **属性测试**: hypothesis
- **API 测试**: pytest + httpx (TestClient)
- **数据库测试**: pytest-asyncio + SQLAlchemy test fixtures

### 单元测试

单元测试覆盖：
- 追踪码生成格式验证
- 数据验证逻辑
- 服务层业务逻辑
- 枚举转换函数

### 属性测试

使用 hypothesis 库进行属性测试，每个属性测试运行至少 100 次迭代。

属性测试标注格式：
```python
# **Feature: feedback-backend-service, Property {number}: {property_text}**
```

核心属性测试：

1. **Property 1 测试**: 生成随机有效反馈数据，验证提交返回 ID 和追踪码格式
2. **Property 2 测试**: 生成缺少必填字段的数据，验证返回 400
3. **Property 7 测试**: 生成随机分页参数，验证返回结果符合分页规则
4. **Property 8 测试**: 生成多个评论，验证排序和 isStaff 标记
5. **Property 12 测试**: 生成随机通知并部分标记已读，验证计数准确
6. **Property 16 测试**: 生成不同类型/状态的反馈，验证筛选结果
7. **Property 17 测试**: 生成随机反馈数据，验证统计结果与实际一致
8. **Property 20 测试**: 生成随机反馈数据，验证 JSON 往返一致性

### 测试目录结构

```
tests/
├── conftest.py              # pytest fixtures
├── test_schemas.py          # Pydantic schema 测试
├── test_services/
│   ├── test_feedback.py     # 反馈服务测试
│   ├── test_comment.py      # 评论服务测试
│   └── test_notification.py # 通知服务测试
├── test_api/
│   ├── test_feedback_api.py # 反馈 API 测试
│   ├── test_comment_api.py  # 评论 API 测试
│   ├── test_notify_api.py   # 通知 API 测试
│   └── test_admin_api.py    # 管理 API 测试
├── test_properties/
│   ├── test_feedback_props.py    # 反馈属性测试
│   ├── test_serialization_props.py # 序列化属性测试
│   └── test_pagination_props.py  # 分页属性测试
└── test_utils/
    └── test_tracking_code.py # 追踪码工具测试
```
