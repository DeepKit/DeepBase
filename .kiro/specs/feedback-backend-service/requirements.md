# Requirements Document

## Introduction

本文档定义了 UniBase 用户反馈后端服务的需求规范。该服务作为平台方接收和管理来自 UniBase 前端客户端的 Bug 报告、功能建议、问题咨询等反馈信息，提供完整的反馈生命周期管理、附件存储、通知推送和统计分析功能。

前端组件 `UniBase.Feedback.pas` 已经实现，后端服务需要与其 API 契约保持一致。

## Glossary

- **Feedback（反馈）**: 用户提交的 Bug 报告、功能建议、问题咨询等信息
- **Tracking Code（追踪码）**: 用户用于查询反馈状态的唯一标识符
- **Attachment（附件）**: 反馈关联的文件，如截图、日志文件等
- **System Info（系统信息）**: 客户端自动采集的操作系统、硬件、应用版本等信息
- **Notification（通知）**: 反馈状态变更时推送给用户的消息
- **Comment（评论）**: 用户或客服在反馈下的交流信息
- **Staff（客服/工作人员）**: 平台方处理反馈的人员

## Requirements

### Requirement 1: 反馈提交

**User Story:** As a 前端用户, I want to 提交反馈信息到平台, so that 开发团队能够收到并处理我的问题或建议。

#### Acceptance Criteria

1. WHEN 客户端发送反馈提交请求 THEN THE 后端服务 SHALL 验证请求数据完整性并返回反馈 ID 和追踪码
2. WHEN 反馈数据缺少必填字段（标题或描述） THEN THE 后端服务 SHALL 返回 400 错误码和具体的验证错误信息
3. WHEN 反馈提交成功 THEN THE 后端服务 SHALL 将反馈数据持久化到数据库并设置状态为 New
4. WHEN 反馈包含系统信息 THEN THE 后端服务 SHALL 将系统信息与反馈关联存储
5. WHEN 生成追踪码 THEN THE 后端服务 SHALL 确保追踪码在系统内唯一且格式为 TRK-YYYY-XXXXXX

### Requirement 2: 附件管理

**User Story:** As a 前端用户, I want to 上传截图和日志文件作为反馈附件, so that 开发团队能够更好地理解和复现问题。

#### Acceptance Criteria

1. WHEN 客户端上传附件文件 THEN THE 后端服务 SHALL 存储文件并返回附件 ID 和访问 URL
2. WHEN 附件文件大小超过配置的最大限制（默认 10MB） THEN THE 后端服务 SHALL 拒绝上传并返回 413 错误码
3. WHEN 单个反馈的附件总大小超过配置限制（默认 50MB） THEN THE 后端服务 SHALL 拒绝上传并返回错误信息
4. WHEN 附件上传成功 THEN THE 后端服务 SHALL 记录文件名、大小、MIME 类型和上传时间
5. WHEN 请求下载附件 THEN THE 后端服务 SHALL 验证请求者权限后返回文件内容

### Requirement 3: 反馈查询

**User Story:** As a 前端用户, I want to 查询我提交的反馈状态, so that 我能够了解问题处理进度。

#### Acceptance Criteria

1. WHEN 用户通过追踪码查询反馈 THEN THE 后端服务 SHALL 返回反馈详情包括状态、评论和更新时间
2. WHEN 用户查询自己的反馈列表 THEN THE 后端服务 SHALL 返回该用户所有反馈的摘要信息
3. WHEN 查询的追踪码不存在 THEN THE 后端服务 SHALL 返回 404 错误码
4. WHEN 返回反馈列表 THEN THE 后端服务 SHALL 支持分页参数（page、pageSize）和排序参数
5. WHEN 查询反馈详情 THEN THE 后端服务 SHALL 包含关联的附件信息和系统信息

### Requirement 4: 评论交互

**User Story:** As a 前端用户, I want to 在反馈下添加评论与客服沟通, so that 我能够提供更多信息或询问进度。

#### Acceptance Criteria

1. WHEN 用户添加评论 THEN THE 后端服务 SHALL 将评论关联到指定反馈并标记为非客服评论
2. WHEN 客服添加评论 THEN THE 后端服务 SHALL 将评论标记为客服评论（isStaff=true）
3. WHEN 查询反馈评论 THEN THE 后端服务 SHALL 返回按时间排序的评论列表
4. WHEN 评论内容为空 THEN THE 后端服务 SHALL 拒绝添加并返回验证错误
5. WHEN 新评论添加成功 THEN THE 后端服务 SHALL 创建通知发送给相关方

### Requirement 5: 通知管理

**User Story:** As a 前端用户, I want to 接收反馈状态变更通知, so that 我能够及时了解问题处理进展。

#### Acceptance Criteria

1. WHEN 反馈状态发生变更 THEN THE 后端服务 SHALL 创建状态变更通知
2. WHEN 用户查询通知列表 THEN THE 后端服务 SHALL 返回该用户的所有通知按时间倒序排列
3. WHEN 用户标记通知为已读 THEN THE 后端服务 SHALL 更新通知的已读状态和已读时间
4. WHEN 用户请求未读通知数量 THEN THE 后端服务 SHALL 返回准确的未读计数
5. WHEN 用户批量标记所有通知为已读 THEN THE 后端服务 SHALL 更新该用户所有未读通知

### Requirement 6: 反馈状态管理（管理端）

**User Story:** As a 平台客服, I want to 管理反馈状态和分配处理人, so that 反馈能够被有效跟踪和处理。

#### Acceptance Criteria

1. WHEN 客服更新反馈状态 THEN THE 后端服务 SHALL 记录状态变更并更新 updatedAt 时间戳
2. WHEN 状态从任意状态变更为 Resolved THEN THE 后端服务 SHALL 创建解决通知发送给用户
3. WHEN 客服分配反馈给处理人 THEN THE 后端服务 SHALL 记录分配信息并通知被分配人
4. WHEN 查询待处理反馈列表 THEN THE 后端服务 SHALL 支持按类型、优先级、状态筛选
5. WHEN 反馈状态为 Closed 或 Rejected THEN THE 后端服务 SHALL 阻止用户添加新评论

### Requirement 7: 数据统计（管理端）

**User Story:** As a 平台管理员, I want to 查看反馈统计数据, so that 我能够了解产品问题分布和处理效率。

#### Acceptance Criteria

1. WHEN 请求反馈统计概览 THEN THE 后端服务 SHALL 返回各状态的反馈数量
2. WHEN 请求按类型统计 THEN THE 后端服务 SHALL 返回各反馈类型的数量分布
3. WHEN 请求时间范围统计 THEN THE 后端服务 SHALL 返回指定时间段内的反馈趋势数据
4. WHEN 请求处理效率统计 THEN THE 后端服务 SHALL 返回平均响应时间和解决时间

### Requirement 8: API 安全与认证

**User Story:** As a 系统架构师, I want to 确保 API 安全访问, so that 反馈数据不被未授权访问或篡改。

#### Acceptance Criteria

1. WHEN 客户端请求 API THEN THE 后端服务 SHALL 验证请求头中的 API Key
2. WHEN API Key 无效或缺失 THEN THE 后端服务 SHALL 返回 401 错误码
3. WHEN 用户访问其他用户的反馈 THEN THE 后端服务 SHALL 返回 403 错误码
4. WHEN 管理端 API 被调用 THEN THE 后端服务 SHALL 验证调用者具有管理员权限
5. WHEN 请求频率超过限制 THEN THE 后端服务 SHALL 返回 429 错误码并包含重试时间

### Requirement 9: 数据序列化

**User Story:** As a 开发者, I want to 确保前后端数据格式一致, so that 数据能够正确传输和解析。

#### Acceptance Criteria

1. WHEN 序列化反馈数据 THEN THE 后端服务 SHALL 使用与前端一致的 JSON 字段命名（camelCase）
2. WHEN 序列化日期时间 THEN THE 后端服务 SHALL 使用 ISO 8601 格式
3. WHEN 反序列化请求数据 THEN THE 后端服务 SHALL 正确解析前端发送的 JSON 结构
4. WHEN 序列化枚举值 THEN THE 后端服务 SHALL 使用字符串表示（如 "Bug"、"Feature"）
5. WHEN 解析反馈数据后再序列化 THEN THE 后端服务 SHALL 产生与原始数据等价的 JSON 输出
