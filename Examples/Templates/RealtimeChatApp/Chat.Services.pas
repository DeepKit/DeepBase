unit Chat.Services;

{*******************************************************************************
  Realtime Chat Application Template - Services
  
  Services:
    - TChatService: Message operations
    - TRoomService: Room management
    - TUserService: User management
    - TPresenceService: Online status tracking
    - TNotificationService: Push notifications
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.SyncObjs,
  Chat.Types,
  UniBase.ORM, UniBase.EventBus;

type
  TChatEvent = record
    EventType: string;
    RoomId: Integer;
    UserId: Integer;
    MessageId: Int64;
    Data: string;
  end;

  IRealtimeTransport = interface
    ['{A1B2C3D4-5678-9ABC-DEF0-123456789ABC}']
    procedure Send(const AUserId: Integer; const AEvent: TChatEvent);
    procedure Broadcast(const ARoomId: Integer; const AEvent: TChatEvent);
    procedure BroadcastExcept(const ARoomId, AExcludeUserId: Integer; const AEvent: TChatEvent);
  end;

  TChatService = class
  private
    FContext: TDbContext;
    FTransport: IRealtimeTransport;
    FEventBus: TEventBus;
  public
    constructor Create(AContext: TDbContext; ATransport: IRealtimeTransport = nil);
    destructor Destroy; override;
    
    // Message operations
    function SendMessage(ARoomId, ASenderId: Integer; const AContent: string;
      AMessageType: TMessageType = mtText; AReplyToId: Int64 = 0): TChatMessage;
    function SendMediaMessage(ARoomId, ASenderId: Integer; const AMediaUrl: string;
      AMediaSize: Int64; const AMediaName: string; AMessageType: TMessageType): TChatMessage;
    function EditMessage(AMessageId: Int64; AUserId: Integer; const ANewContent: string): Boolean;
    function DeleteMessage(AMessageId: Int64; AUserId: Integer): Boolean;
    function PinMessage(AMessageId: Int64; AUserId: Integer): Boolean;
    function UnpinMessage(AMessageId: Int64; AUserId: Integer): Boolean;
    
    // Message queries
    function GetMessages(ARoomId: Integer; ALimit: Integer = 50; 
      ABeforeId: Int64 = 0): TObjectList<TChatMessage>;
    function GetMessagesWithSenders(ARoomId: Integer; ALimit: Integer = 50;
      ABeforeId: Int64 = 0): TArray<TMessageWithSender>;
    function GetPinnedMessages(ARoomId: Integer): TObjectList<TChatMessage>;
    function SearchMessages(ARoomId: Integer; const AQuery: string): TObjectList<TChatMessage>;
    function GetMessage(AMessageId: Int64): TChatMessage;
    
    // Reactions
    procedure AddReaction(AMessageId: Int64; AUserId: Integer; const AEmoji: string);
    procedure RemoveReaction(AMessageId: Int64; AUserId: Integer; const AEmoji: string);
    function GetReactions(AMessageId: Int64): TArray<TReactionSummary>;
    
    // Read receipts
    procedure MarkAsRead(ARoomId, AUserId: Integer);
    function GetUnreadCount(ARoomId, AUserId: Integer): Integer;
    
    // Typing indicator
    procedure SetTyping(ARoomId, AUserId: Integer; AIsTyping: Boolean);
  end;

  TRoomService = class
  private
    FContext: TDbContext;
    FTransport: IRealtimeTransport;
    
    function GetOrCreatePrivateRoom(AUser1Id, AUser2Id: Integer): TChatRoom;
  public
    constructor Create(AContext: TDbContext; ATransport: IRealtimeTransport = nil);
    
    // Room CRUD
    function CreateRoom(const AName: string; ARoomType: TRoomType; 
      ACreatorId: Integer; const ADescription: string = ''): TChatRoom;
    function CreatePrivateChat(AUser1Id, AUser2Id: Integer): TChatRoom;
    function GetRoom(ARoomId: Integer): TChatRoom;
    procedure UpdateRoom(ARoom: TChatRoom);
    procedure ArchiveRoom(ARoomId: Integer);
    procedure DeleteRoom(ARoomId: Integer);
    
    // Room queries
    function GetUserRooms(AUserId: Integer): TArray<TRoomWithLastMessage>;
    function GetPublicRooms: TObjectList<TChatRoom>;
    function SearchRooms(const AQuery: string): TObjectList<TChatRoom>;
    
    // Member management
    procedure AddMember(ARoomId, AUserId: Integer; ARole: TMemberRole = mrMember);
    procedure RemoveMember(ARoomId, AUserId: Integer);
    procedure UpdateMemberRole(ARoomId, AUserId: Integer; ARole: TMemberRole);
    function GetMembers(ARoomId: Integer): TObjectList<TRoomMember>;
    function GetMembersWithUsers(ARoomId: Integer): TArray<TPair<TRoomMember, TChatUser>>;
    function IsMember(ARoomId, AUserId: Integer): Boolean;
    function GetMemberRole(ARoomId, AUserId: Integer): TMemberRole;
    
    // Room settings
    procedure MuteRoom(ARoomId, AUserId: Integer; AMuted: Boolean);
    procedure PinRoom(ARoomId, AUserId: Integer; APinned: Boolean);
  end;

  TUserService = class
  private
    FContext: TDbContext;
  public
    constructor Create(AContext: TDbContext);
    
    function GetUser(AUserId: Integer): TChatUser;
    function GetUserByUsername(const AUsername: string): TChatUser;
    function GetUsers(const AUserIds: TArray<Integer>): TObjectList<TChatUser>;
    function SearchUsers(const AQuery: string): TObjectList<TChatUser>;
    
    procedure UpdateUser(AUser: TChatUser);
    procedure UpdateStatus(AUserId: Integer; AStatus: TUserStatus; 
      const AStatusMessage: string = '');
    procedure UpdateAvatar(AUserId: Integer; const AAvatarUrl: string);
    
    function GetOnlineUsers: TObjectList<TChatUser>;
    function GetContacts(AUserId: Integer): TObjectList<TChatUser>;
    procedure AddContact(AUserId, AContactId: Integer);
    procedure RemoveContact(AUserId, AContactId: Integer);
  end;

  TPresenceService = class
  private
    FContext: TDbContext;
    FTransport: IRealtimeTransport;
    FOnlineUsers: TDictionary<Integer, TDateTime>;
    FTypingUsers: TDictionary<string, TTypingUser>; // "roomId:userId" -> info
    FLock: TCriticalSection;
    
    function GetTypingKey(ARoomId, AUserId: Integer): string;
  public
    constructor Create(AContext: TDbContext; ATransport: IRealtimeTransport = nil);
    destructor Destroy; override;
    
    procedure UserConnected(AUserId: Integer);
    procedure UserDisconnected(AUserId: Integer);
    procedure Heartbeat(AUserId: Integer);
    
    function IsOnline(AUserId: Integer): Boolean;
    function GetOnlineUserIds: TArray<Integer>;
    function GetLastSeen(AUserId: Integer): TDateTime;
    
    procedure StartTyping(ARoomId, AUserId: Integer);
    procedure StopTyping(ARoomId, AUserId: Integer);
    function GetTypingUsers(ARoomId: Integer): TArray<TTypingUser>;
    procedure CleanupStaleTyping;
  end;

implementation

uses
  System.DateUtils, System.JSON;

{ TChatService }

constructor TChatService.Create(AContext: TDbContext; ATransport: IRealtimeTransport);
begin
  FContext := AContext;
  FTransport := ATransport;
  FEventBus := TEventBus.Create;
end;

destructor TChatService.Destroy;
begin
  FEventBus.Free;
  inherited;
end;

function TChatService.SendMessage(ARoomId, ASenderId: Integer; const AContent: string;
  AMessageType: TMessageType; AReplyToId: Int64): TChatMessage;
var
  Event: TChatEvent;
begin
  Result := TChatMessage.Create;
  Result.RoomId := ARoomId;
  Result.SenderId := ASenderId;
  Result.MessageType := AMessageType;
  Result.Content := AContent;
  Result.ReplyToId := AReplyToId;
  Result.CreatedAt := Now;
  
  FContext.Insert(Result);
  
  // Update room's last message time
  FContext.ExecuteSQL('UPDATE ChatRooms SET LastMessageAt = :time WHERE Id = :id',
    [Now, ARoomId]);
  
  // Broadcast to room
  if Assigned(FTransport) then
  begin
    Event.EventType := 'message.new';
    Event.RoomId := ARoomId;
    Event.UserId := ASenderId;
    Event.MessageId := Result.Id;
    FTransport.Broadcast(ARoomId, Event);
  end;
end;

function TChatService.SendMediaMessage(ARoomId, ASenderId: Integer; 
  const AMediaUrl: string; AMediaSize: Int64; const AMediaName: string;
  AMessageType: TMessageType): TChatMessage;
begin
  Result := TChatMessage.Create;
  Result.RoomId := ARoomId;
  Result.SenderId := ASenderId;
  Result.MessageType := AMessageType;
  Result.MediaUrl := AMediaUrl;
  Result.MediaSize := AMediaSize;
  Result.MediaName := AMediaName;
  Result.CreatedAt := Now;
  
  FContext.Insert(Result);
  
  FContext.ExecuteSQL('UPDATE ChatRooms SET LastMessageAt = :time WHERE Id = :id',
    [Now, ARoomId]);
end;

function TChatService.EditMessage(AMessageId: Int64; AUserId: Integer;
  const ANewContent: string): Boolean;
var
  Msg: TChatMessage;
begin
  Result := False;
  Msg := GetMessage(AMessageId);
  if Assigned(Msg) and (Msg.SenderId = AUserId) then
  begin
    Msg.Content := ANewContent;
    Msg.IsEdited := True;
    Msg.EditedAt := Now;
    FContext.Update(Msg);
    Result := True;
    Msg.Free;
  end;
end;

function TChatService.DeleteMessage(AMessageId: Int64; AUserId: Integer): Boolean;
var
  Msg: TChatMessage;
begin
  Result := False;
  Msg := GetMessage(AMessageId);
  if Assigned(Msg) and (Msg.SenderId = AUserId) then
  begin
    Msg.IsDeleted := True;
    Msg.Content := '';
    FContext.Update(Msg);
    Result := True;
    Msg.Free;
  end;
end;

function TChatService.PinMessage(AMessageId: Int64; AUserId: Integer): Boolean;
var
  Msg: TChatMessage;
begin
  Result := False;
  Msg := GetMessage(AMessageId);
  if Assigned(Msg) then
  begin
    Msg.IsPinned := True;
    FContext.Update(Msg);
    Result := True;
    Msg.Free;
  end;
end;

function TChatService.UnpinMessage(AMessageId: Int64; AUserId: Integer): Boolean;
var
  Msg: TChatMessage;
begin
  Result := False;
  Msg := GetMessage(AMessageId);
  if Assigned(Msg) then
  begin
    Msg.IsPinned := False;
    FContext.Update(Msg);
    Result := True;
    Msg.Free;
  end;
end;

function TChatService.GetMessages(ARoomId: Integer; ALimit: Integer;
  ABeforeId: Int64): TObjectList<TChatMessage>;
var
  Query: TQueryBuilder<TChatMessage>;
begin
  Query := FContext.Query<TChatMessage>
    .Where('RoomId = :roomId AND IsDeleted = 0', [ARoomId]);
    
  if ABeforeId > 0 then
    Query.Where('Id < :beforeId', [ABeforeId]);
    
  Result := Query
    .OrderByDesc('Id')
    .Take(ALimit)
    .ToList;
end;

function TChatService.GetMessagesWithSenders(ARoomId: Integer; ALimit: Integer;
  ABeforeId: Int64): TArray<TMessageWithSender>;
var
  Messages: TObjectList<TChatMessage>;
  I: Integer;
begin
  Messages := GetMessages(ARoomId, ALimit, ABeforeId);
  try
    SetLength(Result, Messages.Count);
    for I := 0 to Messages.Count - 1 do
    begin
      Result[I].Message := Messages[I];
      Result[I].Sender := FContext.Find<TChatUser>(Messages[I].SenderId);
      Result[I].Reactions := GetReactions(Messages[I].Id);
      if Messages[I].ReplyToId > 0 then
        Result[I].ReplyTo := GetMessage(Messages[I].ReplyToId);
    end;
  finally
    Messages.Free;
  end;
end;

function TChatService.GetPinnedMessages(ARoomId: Integer): TObjectList<TChatMessage>;
begin
  Result := FContext.Query<TChatMessage>
    .Where('RoomId = :roomId AND IsPinned = 1 AND IsDeleted = 0', [ARoomId])
    .OrderByDesc('CreatedAt')
    .ToList;
end;

function TChatService.SearchMessages(ARoomId: Integer; const AQuery: string): TObjectList<TChatMessage>;
begin
  Result := FContext.Query<TChatMessage>
    .Where('RoomId = :roomId AND Content LIKE :query AND IsDeleted = 0',
      [ARoomId, '%' + AQuery + '%'])
    .OrderByDesc('CreatedAt')
    .Take(100)
    .ToList;
end;

function TChatService.GetMessage(AMessageId: Int64): TChatMessage;
begin
  Result := FContext.Find<TChatMessage>(AMessageId);
end;

procedure TChatService.AddReaction(AMessageId: Int64; AUserId: Integer; const AEmoji: string);
var
  Existing: TMessageReaction;
  Reaction: TMessageReaction;
begin
  Existing := FContext.Query<TMessageReaction>
    .Where('MessageId = :msgId AND UserId = :userId AND Emoji = :emoji',
      [AMessageId, AUserId, AEmoji])
    .FirstOrDefault;
    
  if not Assigned(Existing) then
  begin
    Reaction := TMessageReaction.Create;
    Reaction.MessageId := AMessageId;
    Reaction.UserId := AUserId;
    Reaction.Emoji := AEmoji;
    Reaction.CreatedAt := Now;
    FContext.Insert(Reaction);
    Reaction.Free;
  end
  else
    Existing.Free;
end;

procedure TChatService.RemoveReaction(AMessageId: Int64; AUserId: Integer; const AEmoji: string);
begin
  FContext.ExecuteSQL(
    'DELETE FROM MessageReactions WHERE MessageId = :msgId AND UserId = :userId AND Emoji = :emoji',
    [AMessageId, AUserId, AEmoji]);
end;

function TChatService.GetReactions(AMessageId: Int64): TArray<TReactionSummary>;
var
  Reactions: TObjectList<TMessageReaction>;
  Dict: TDictionary<string, TList<Integer>>;
  R: TMessageReaction;
  Key: string;
  I: Integer;
begin
  Reactions := FContext.Query<TMessageReaction>
    .Where('MessageId = :msgId', [AMessageId])
    .ToList;
  
  Dict := TDictionary<string, TList<Integer>>.Create;
  try
    for R in Reactions do
    begin
      if not Dict.ContainsKey(R.Emoji) then
        Dict.Add(R.Emoji, TList<Integer>.Create);
      Dict[R.Emoji].Add(R.UserId);
    end;
    
    SetLength(Result, Dict.Count);
    I := 0;
    for Key in Dict.Keys do
    begin
      Result[I].Emoji := Key;
      Result[I].Count := Dict[Key].Count;
      Result[I].UserIds := Dict[Key].ToArray;
      Dict[Key].Free;
      Inc(I);
    end;
  finally
    Dict.Free;
    Reactions.Free;
  end;
end;

procedure TChatService.MarkAsRead(ARoomId, AUserId: Integer);
begin
  FContext.ExecuteSQL(
    'UPDATE RoomMembers SET LastReadAt = :time WHERE RoomId = :roomId AND UserId = :userId',
    [Now, ARoomId, AUserId]);
end;

function TChatService.GetUnreadCount(ARoomId, AUserId: Integer): Integer;
var
  Member: TRoomMember;
begin
  Result := 0;
  Member := FContext.Query<TRoomMember>
    .Where('RoomId = :roomId AND UserId = :userId', [ARoomId, AUserId])
    .FirstOrDefault;
    
  if Assigned(Member) then
  begin
    Result := FContext.Query<TChatMessage>
      .Where('RoomId = :roomId AND CreatedAt > :lastRead AND SenderId <> :userId',
        [ARoomId, Member.LastReadAt, AUserId])
      .Count;
    Member.Free;
  end;
end;

procedure TChatService.SetTyping(ARoomId, AUserId: Integer; AIsTyping: Boolean);
var
  Event: TChatEvent;
begin
  if Assigned(FTransport) then
  begin
    if AIsTyping then
      Event.EventType := 'typing.start'
    else
      Event.EventType := 'typing.stop';
    Event.RoomId := ARoomId;
    Event.UserId := AUserId;
    FTransport.BroadcastExcept(ARoomId, AUserId, Event);
  end;
end;

{ TRoomService }

constructor TRoomService.Create(AContext: TDbContext; ATransport: IRealtimeTransport);
begin
  FContext := AContext;
  FTransport := ATransport;
end;

function TRoomService.CreateRoom(const AName: string; ARoomType: TRoomType;
  ACreatorId: Integer; const ADescription: string): TChatRoom;
begin
  Result := TChatRoom.Create;
  Result.Name := AName;
  Result.Description := ADescription;
  Result.RoomType := ARoomType;
  Result.CreatedById := ACreatorId;
  Result.CreatedAt := Now;
  Result.MemberCount := 1;
  
  FContext.Insert(Result);
  
  // Add creator as owner
  AddMember(Result.Id, ACreatorId, mrOwner);
end;

function TRoomService.GetOrCreatePrivateRoom(AUser1Id, AUser2Id: Integer): TChatRoom;
var
  RoomId: Integer;
begin
  // Find existing private room between these users
  RoomId := 0;
  // Complex query to find private room - simplified here
  
  if RoomId = 0 then
    Result := CreatePrivateChat(AUser1Id, AUser2Id)
  else
    Result := GetRoom(RoomId);
end;

function TRoomService.CreatePrivateChat(AUser1Id, AUser2Id: Integer): TChatRoom;
begin
  Result := TChatRoom.Create;
  Result.Name := '';
  Result.RoomType := rtPrivate;
  Result.CreatedById := AUser1Id;
  Result.CreatedAt := Now;
  Result.MemberCount := 2;
  
  FContext.Insert(Result);
  
  AddMember(Result.Id, AUser1Id, mrMember);
  AddMember(Result.Id, AUser2Id, mrMember);
end;

function TRoomService.GetRoom(ARoomId: Integer): TChatRoom;
begin
  Result := FContext.Find<TChatRoom>(ARoomId);
end;

procedure TRoomService.UpdateRoom(ARoom: TChatRoom);
begin
  FContext.Update(ARoom);
end;

procedure TRoomService.ArchiveRoom(ARoomId: Integer);
var
  Room: TChatRoom;
begin
  Room := GetRoom(ARoomId);
  if Assigned(Room) then
  begin
    Room.IsArchived := True;
    FContext.Update(Room);
    Room.Free;
  end;
end;

procedure TRoomService.DeleteRoom(ARoomId: Integer);
begin
  FContext.ExecuteSQL('DELETE FROM MessageReactions WHERE MessageId IN (SELECT Id FROM ChatMessages WHERE RoomId = :id)', [ARoomId]);
  FContext.ExecuteSQL('DELETE FROM ChatMessages WHERE RoomId = :id', [ARoomId]);
  FContext.ExecuteSQL('DELETE FROM RoomMembers WHERE RoomId = :id', [ARoomId]);
  FContext.ExecuteSQL('DELETE FROM ChatRooms WHERE Id = :id', [ARoomId]);
end;

function TRoomService.GetUserRooms(AUserId: Integer): TArray<TRoomWithLastMessage>;
var
  Members: TObjectList<TRoomMember>;
  I: Integer;
  Room: TChatRoom;
  LastMsg: TChatMessage;
begin
  Members := FContext.Query<TRoomMember>
    .Where('UserId = :userId', [AUserId])
    .OrderByDesc('IsPinned')
    .ToList;
  
  try
    SetLength(Result, Members.Count);
    for I := 0 to Members.Count - 1 do
    begin
      Room := GetRoom(Members[I].RoomId);
      Result[I].Room := Room;
      
      LastMsg := FContext.Query<TChatMessage>
        .Where('RoomId = :roomId AND IsDeleted = 0', [Room.Id])
        .OrderByDesc('Id')
        .FirstOrDefault;
      Result[I].LastMessage := LastMsg;
      
      Result[I].UnreadCount := FContext.Query<TChatMessage>
        .Where('RoomId = :roomId AND CreatedAt > :lastRead AND SenderId <> :userId',
          [Room.Id, Members[I].LastReadAt, AUserId])
        .Count;
    end;
  finally
    Members.Free;
  end;
end;

function TRoomService.GetPublicRooms: TObjectList<TChatRoom>;
begin
  Result := FContext.Query<TChatRoom>
    .Where('RoomType IN (:group, :channel) AND IsArchived = 0',
      [Ord(rtGroup), Ord(rtChannel)])
    .OrderByDesc('MemberCount')
    .ToList;
end;

function TRoomService.SearchRooms(const AQuery: string): TObjectList<TChatRoom>;
begin
  Result := FContext.Query<TChatRoom>
    .Where('(Name LIKE :query OR Description LIKE :query) AND IsArchived = 0',
      ['%' + AQuery + '%'])
    .ToList;
end;

procedure TRoomService.AddMember(ARoomId, AUserId: Integer; ARole: TMemberRole);
var
  Member: TRoomMember;
begin
  if not IsMember(ARoomId, AUserId) then
  begin
    Member := TRoomMember.Create;
    Member.RoomId := ARoomId;
    Member.UserId := AUserId;
    Member.Role := ARole;
    Member.JoinedAt := Now;
    Member.LastReadAt := Now;
    FContext.Insert(Member);
    Member.Free;
    
    FContext.ExecuteSQL('UPDATE ChatRooms SET MemberCount = MemberCount + 1 WHERE Id = :id',
      [ARoomId]);
  end;
end;

procedure TRoomService.RemoveMember(ARoomId, AUserId: Integer);
begin
  FContext.ExecuteSQL('DELETE FROM RoomMembers WHERE RoomId = :roomId AND UserId = :userId',
    [ARoomId, AUserId]);
  FContext.ExecuteSQL('UPDATE ChatRooms SET MemberCount = MemberCount - 1 WHERE Id = :id',
    [ARoomId]);
end;

procedure TRoomService.UpdateMemberRole(ARoomId, AUserId: Integer; ARole: TMemberRole);
begin
  FContext.ExecuteSQL('UPDATE RoomMembers SET Role = :role WHERE RoomId = :roomId AND UserId = :userId',
    [Ord(ARole), ARoomId, AUserId]);
end;

function TRoomService.GetMembers(ARoomId: Integer): TObjectList<TRoomMember>;
begin
  Result := FContext.Query<TRoomMember>
    .Where('RoomId = :roomId', [ARoomId])
    .ToList;
end;

function TRoomService.GetMembersWithUsers(ARoomId: Integer): TArray<TPair<TRoomMember, TChatUser>>;
var
  Members: TObjectList<TRoomMember>;
  I: Integer;
begin
  Members := GetMembers(ARoomId);
  try
    SetLength(Result, Members.Count);
    for I := 0 to Members.Count - 1 do
    begin
      Result[I].Key := Members[I];
      Result[I].Value := FContext.Find<TChatUser>(Members[I].UserId);
    end;
  finally
    Members.Free;
  end;
end;

function TRoomService.IsMember(ARoomId, AUserId: Integer): Boolean;
begin
  Result := FContext.Query<TRoomMember>
    .Where('RoomId = :roomId AND UserId = :userId', [ARoomId, AUserId])
    .Count > 0;
end;

function TRoomService.GetMemberRole(ARoomId, AUserId: Integer): TMemberRole;
var
  Member: TRoomMember;
begin
  Result := mrMember;
  Member := FContext.Query<TRoomMember>
    .Where('RoomId = :roomId AND UserId = :userId', [ARoomId, AUserId])
    .FirstOrDefault;
  if Assigned(Member) then
  begin
    Result := Member.Role;
    Member.Free;
  end;
end;

procedure TRoomService.MuteRoom(ARoomId, AUserId: Integer; AMuted: Boolean);
begin
  FContext.ExecuteSQL('UPDATE RoomMembers SET IsMuted = :muted WHERE RoomId = :roomId AND UserId = :userId',
    [AMuted, ARoomId, AUserId]);
end;

procedure TRoomService.PinRoom(ARoomId, AUserId: Integer; APinned: Boolean);
begin
  FContext.ExecuteSQL('UPDATE RoomMembers SET IsPinned = :pinned WHERE RoomId = :roomId AND UserId = :userId',
    [APinned, ARoomId, AUserId]);
end;

{ TUserService }

constructor TUserService.Create(AContext: TDbContext);
begin
  FContext := AContext;
end;

function TUserService.GetUser(AUserId: Integer): TChatUser;
begin
  Result := FContext.Find<TChatUser>(AUserId);
end;

function TUserService.GetUserByUsername(const AUsername: string): TChatUser;
begin
  Result := FContext.Query<TChatUser>
    .Where('Username = :username', [AUsername])
    .FirstOrDefault;
end;

function TUserService.GetUsers(const AUserIds: TArray<Integer>): TObjectList<TChatUser>;
begin
  Result := FContext.Query<TChatUser>
    .Where('Id IN (' + string.Join(',', TArray<string>(AUserIds)) + ')')
    .ToList;
end;

function TUserService.SearchUsers(const AQuery: string): TObjectList<TChatUser>;
begin
  Result := FContext.Query<TChatUser>
    .Where('Username LIKE :query OR DisplayName LIKE :query', ['%' + AQuery + '%'])
    .Take(20)
    .ToList;
end;

procedure TUserService.UpdateUser(AUser: TChatUser);
begin
  FContext.Update(AUser);
end;

procedure TUserService.UpdateStatus(AUserId: Integer; AStatus: TUserStatus;
  const AStatusMessage: string);
var
  User: TChatUser;
begin
  User := GetUser(AUserId);
  if Assigned(User) then
  begin
    User.Status := AStatus;
    User.StatusMessage := AStatusMessage;
    FContext.Update(User);
    User.Free;
  end;
end;

procedure TUserService.UpdateAvatar(AUserId: Integer; const AAvatarUrl: string);
var
  User: TChatUser;
begin
  User := GetUser(AUserId);
  if Assigned(User) then
  begin
    User.AvatarUrl := AAvatarUrl;
    FContext.Update(User);
    User.Free;
  end;
end;

function TUserService.GetOnlineUsers: TObjectList<TChatUser>;
begin
  Result := FContext.Query<TChatUser>
    .Where('IsOnline = 1')
    .ToList;
end;

function TUserService.GetContacts(AUserId: Integer): TObjectList<TChatUser>;
begin
  // Would query Contacts table
  Result := TObjectList<TChatUser>.Create;
end;

procedure TUserService.AddContact(AUserId, AContactId: Integer);
begin
  // Add to Contacts table
end;

procedure TUserService.RemoveContact(AUserId, AContactId: Integer);
begin
  // Remove from Contacts table
end;

{ TPresenceService }

constructor TPresenceService.Create(AContext: TDbContext; ATransport: IRealtimeTransport);
begin
  FContext := AContext;
  FTransport := ATransport;
  FOnlineUsers := TDictionary<Integer, TDateTime>.Create;
  FTypingUsers := TDictionary<string, TTypingUser>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TPresenceService.Destroy;
begin
  FOnlineUsers.Free;
  FTypingUsers.Free;
  FLock.Free;
  inherited;
end;

function TPresenceService.GetTypingKey(ARoomId, AUserId: Integer): string;
begin
  Result := Format('%d:%d', [ARoomId, AUserId]);
end;

procedure TPresenceService.UserConnected(AUserId: Integer);
begin
  FLock.Enter;
  try
    FOnlineUsers.AddOrSetValue(AUserId, Now);
  finally
    FLock.Leave;
  end;
  
  FContext.ExecuteSQL('UPDATE ChatUsers SET IsOnline = 1, LastSeenAt = :time WHERE Id = :id',
    [Now, AUserId]);
end;

procedure TPresenceService.UserDisconnected(AUserId: Integer);
begin
  FLock.Enter;
  try
    FOnlineUsers.Remove(AUserId);
  finally
    FLock.Leave;
  end;
  
  FContext.ExecuteSQL('UPDATE ChatUsers SET IsOnline = 0, LastSeenAt = :time WHERE Id = :id',
    [Now, AUserId]);
end;

procedure TPresenceService.Heartbeat(AUserId: Integer);
begin
  FLock.Enter;
  try
    FOnlineUsers.AddOrSetValue(AUserId, Now);
  finally
    FLock.Leave;
  end;
end;

function TPresenceService.IsOnline(AUserId: Integer): Boolean;
begin
  FLock.Enter;
  try
    Result := FOnlineUsers.ContainsKey(AUserId);
  finally
    FLock.Leave;
  end;
end;

function TPresenceService.GetOnlineUserIds: TArray<Integer>;
begin
  FLock.Enter;
  try
    Result := FOnlineUsers.Keys.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TPresenceService.GetLastSeen(AUserId: Integer): TDateTime;
var
  User: TChatUser;
begin
  Result := 0;
  User := FContext.Find<TChatUser>(AUserId);
  if Assigned(User) then
  begin
    Result := User.LastSeenAt;
    User.Free;
  end;
end;

procedure TPresenceService.StartTyping(ARoomId, AUserId: Integer);
var
  Key: string;
  Info: TTypingUser;
begin
  Key := GetTypingKey(ARoomId, AUserId);
  
  FLock.Enter;
  try
    Info.UserId := AUserId;
    Info.StartedAt := Now;
    FTypingUsers.AddOrSetValue(Key, Info);
  finally
    FLock.Leave;
  end;
end;

procedure TPresenceService.StopTyping(ARoomId, AUserId: Integer);
var
  Key: string;
begin
  Key := GetTypingKey(ARoomId, AUserId);
  
  FLock.Enter;
  try
    FTypingUsers.Remove(Key);
  finally
    FLock.Leave;
  end;
end;

function TPresenceService.GetTypingUsers(ARoomId: Integer): TArray<TTypingUser>;
var
  List: TList<TTypingUser>;
  Pair: TPair<string, TTypingUser>;
  RoomPrefix: string;
begin
  RoomPrefix := Format('%d:', [ARoomId]);
  List := TList<TTypingUser>.Create;
  try
    FLock.Enter;
    try
      for Pair in FTypingUsers do
        if Pair.Key.StartsWith(RoomPrefix) then
          List.Add(Pair.Value);
    finally
      FLock.Leave;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TPresenceService.CleanupStaleTyping;
var
  StaleKeys: TList<string>;
  Key: string;
  Info: TTypingUser;
begin
  StaleKeys := TList<string>.Create;
  try
    FLock.Enter;
    try
      for Key in FTypingUsers.Keys do
      begin
        Info := FTypingUsers[Key];
        if SecondsBetween(Now, Info.StartedAt) > 10 then
          StaleKeys.Add(Key);
      end;
      
      for Key in StaleKeys do
        FTypingUsers.Remove(Key);
    finally
      FLock.Leave;
    end;
  finally
    StaleKeys.Free;
  end;
end;

end.
