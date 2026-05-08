# Realtime Chat Application Template

完整的实时通信应用模板，展�?DeepBase ORM、EventBus 和实时消息架构�?
## 功能特�?
- **聊天�?*: 私聊、群组、频道、客�?- **消息**: 文本、图片、文件、音视频、位�?- **互动**: 回复、表情反应、置顶、编辑、删�?- **状�?*: 在线状态、正在输入、已读回�?- **成员**: 角色权限、静音、置�?
## 文件结构

```
RealtimeChatApp/
├── Chat.Types.pas      # 类型和实体定�?├── Chat.Services.pas   # 业务服务�?└── README.md
```

## 实体模型

| 实体 | 说明 |
|------|------|
| `TChatUser` | 用户 (状�?头像/昵称) |
| `TChatRoom` | 聊天�?(类型/成员�? |
| `TRoomMember` | 成员关系 (角色/静音/置顶) |
| `TChatMessage` | 消息 (类型/内容/媒体) |
| `TMessageReaction` | 消息反应 (表情) |

## 服务�?
| 服务 | 功能 |
|------|------|
| `TChatService` | 消息 CRUD、反应、已�?|
| `TRoomService` | 聊天室管理、成员管�?|
| `TUserService` | 用户管理、联系人 |
| `TPresenceService` | 在线状态、正在输�?|

## 消息类型

```pascal
TMessageType = (
  mtText,      // 文本消息
  mtImage,     // 图片
  mtFile,      // 文件
  mtAudio,     // 语音
  mtVideo,     // 视频
  mtLocation,  // 位置
  mtSystem,    // 系统消息
  mtJoin,      // 加入通知
  mtLeave,     // 离开通知
  mtTyping     // 正在输入
);
```

## 使用示例

### 发送消�?
```pascal
var Msg := ChatService.SendMessage(
  RoomId,
  CurrentUserId,
  'Hello, World!',
  mtText
);

// 回复消息
var Reply := ChatService.SendMessage(
  RoomId,
  CurrentUserId,
  'This is a reply',
  mtText,
  OriginalMessageId  // ReplyToId
);

// 发送图�?var ImageMsg := ChatService.SendMediaMessage(
  RoomId,
  CurrentUserId,
  'https://cdn.example.com/image.jpg',
  102400,  // 100KB
  'photo.jpg',
  mtImage
);
```

### 消息互动

```pascal
// 添加表情反应
ChatService.AddReaction(MessageId, UserId, '👍');
ChatService.AddReaction(MessageId, UserId, '❤️');

// 获取反应统计
var Reactions := ChatService.GetReactions(MessageId);
// [{ Emoji: '👍', Count: 5, UserIds: [...] }]

// 编辑消息
ChatService.EditMessage(MessageId, UserId, 'Updated content');

// 删除消息
ChatService.DeleteMessage(MessageId, UserId);
```

### 聊天室操�?
```pascal
// 创建群组
var Room := RoomService.CreateRoom(
  'Project Team',
  rtGroup,
  CreatorId,
  'Discussion for project'
);

// 创建私聊
var PrivateRoom := RoomService.CreatePrivateChat(User1Id, User2Id);

// 添加成员
RoomService.AddMember(RoomId, NewUserId, mrMember);

// 设置管理�?RoomService.UpdateMemberRole(RoomId, UserId, mrAdmin);

// 获取用户的所有聊天室
var Rooms := RoomService.GetUserRooms(UserId);
for var R in Rooms do
begin
  // R.Room, R.LastMessage, R.UnreadCount
end;
```

### 在线状�?
```pascal
// 用户上线
PresenceService.UserConnected(UserId);

// 心跳保活
PresenceService.Heartbeat(UserId);

// 用户下线
PresenceService.UserDisconnected(UserId);

// 检查在�?if PresenceService.IsOnline(UserId) then ...

// 正在输入
PresenceService.StartTyping(RoomId, UserId);
// 5秒后自动清理或手动停�?PresenceService.StopTyping(RoomId, UserId);

// 获取正在输入的用�?var TypingUsers := PresenceService.GetTypingUsers(RoomId);
```

### 已读回执

```pascal
// 标记已读
ChatService.MarkAsRead(RoomId, UserId);

// 获取未读�?var UnreadCount := ChatService.GetUnreadCount(RoomId, UserId);
```

## 实时传输接口

```pascal
IRealtimeTransport = interface
  procedure Send(UserId: Integer; Event: TChatEvent);
  procedure Broadcast(RoomId: Integer; Event: TChatEvent);
  procedure BroadcastExcept(RoomId, ExcludeUserId: Integer; Event: TChatEvent);
end;
```

可以实现此接口对�?WebSocket、SignalR、Socket.IO 等实时通信协议�?
## 成员角色

| 角色 | 权限 |
|------|------|
| `mrMember` | 普通成�?|
| `mrModerator` | 可管理消�?|
| `mrAdmin` | 可管理成�?|
| `mrOwner` | 完全控制 |

## 数据库表

- ChatUsers
- ChatRooms
- RoomMembers
- ChatMessages
- MessageReactions

## 扩展建议

1. **消息已读**: 添加 MessageReadReceipts 表记录每条消息的已读状�?2. **消息搜索**: 集成全文搜索 (FTS5)
3. **@提及**: 解析消息内容中的 @username
4. **消息撤回**: 添加撤回时间限制
5. **消息加密**: 端到端加密支�?6. **推送通知**: 离线用户推�?7. **消息同步**: 多端消息同步机制
