unit Chat.Types;

{*******************************************************************************
  Realtime Chat Application Template - Type Definitions
  
  Types:
    - TChatUser: User profile
    - TChatRoom: Chat room/channel
    - TChatMessage: Message content
    - TMessageType: Text/Image/File/System
    - TUserStatus: Online/Away/Busy/Offline
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  DeepBase.ORM.Mapping;

type
  TUserStatus = (usOnline, usAway, usBusy, usOffline, usInvisible);
  
  TMessageType = (mtText, mtImage, mtFile, mtAudio, mtVideo, mtLocation, 
                  mtSystem, mtJoin, mtLeave, mtTyping);
  
  TRoomType = (rtPrivate, rtGroup, rtChannel, rtSupport);
  
  TMemberRole = (mrMember, mrModerator, mrAdmin, mrOwner);

  [Table('ChatUsers')]
  TChatUser = class
  private
    FId: Integer;
    FUsername: string;
    FDisplayName: string;
    FAvatarUrl: string;
    FStatus: TUserStatus;
    FStatusMessage: string;
    FLastSeenAt: TDateTime;
    FCreatedAt: TDateTime;
    FIsOnline: Boolean;
  public
    [PrimaryKey]
    [Column('Id')]
    property Id: Integer read FId write FId;
    
    [Column('Username')]
    [Index]
    property Username: string read FUsername write FUsername;
    
    [Column('DisplayName')]
    property DisplayName: string read FDisplayName write FDisplayName;
    
    [Column('AvatarUrl')]
    property AvatarUrl: string read FAvatarUrl write FAvatarUrl;
    
    [Column('Status')]
    property Status: TUserStatus read FStatus write FStatus;
    
    [Column('StatusMessage')]
    property StatusMessage: string read FStatusMessage write FStatusMessage;
    
    [Column('LastSeenAt')]
    property LastSeenAt: TDateTime read FLastSeenAt write FLastSeenAt;
    
    [Column('CreatedAt')]
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    
    [Column('IsOnline')]
    property IsOnline: Boolean read FIsOnline write FIsOnline;
    
    function StatusText: string;
    function GetInitials: string;
  end;

  [Table('ChatRooms')]
  TChatRoom = class
  private
    FId: Integer;
    FName: string;
    FDescription: string;
    FRoomType: TRoomType;
    FAvatarUrl: string;
    FCreatedById: Integer;
    FCreatedAt: TDateTime;
    FLastMessageAt: TDateTime;
    FMemberCount: Integer;
    FIsArchived: Boolean;
  public
    [PrimaryKey]
    [Column('Id')]
    property Id: Integer read FId write FId;
    
    [Column('Name')]
    property Name: string read FName write FName;
    
    [Column('Description')]
    property Description: string read FDescription write FDescription;
    
    [Column('RoomType')]
    property RoomType: TRoomType read FRoomType write FRoomType;
    
    [Column('AvatarUrl')]
    property AvatarUrl: string read FAvatarUrl write FAvatarUrl;
    
    [Column('CreatedById')]
    [ForeignKey('ChatUsers', 'Id')]
    property CreatedById: Integer read FCreatedById write FCreatedById;
    
    [Column('CreatedAt')]
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    
    [Column('LastMessageAt')]
    property LastMessageAt: TDateTime read FLastMessageAt write FLastMessageAt;
    
    [Column('MemberCount')]
    property MemberCount: Integer read FMemberCount write FMemberCount;
    
    [Column('IsArchived')]
    property IsArchived: Boolean read FIsArchived write FIsArchived;
    
    function RoomTypeText: string;
    function IsPrivateChat: Boolean;
  end;

  [Table('RoomMembers')]
  TRoomMember = class
  private
    FId: Integer;
    FRoomId: Integer;
    FUserId: Integer;
    FRole: TMemberRole;
    FJoinedAt: TDateTime;
    FLastReadAt: TDateTime;
    FIsMuted: Boolean;
    FIsPinned: Boolean;
  public
    [PrimaryKey]
    [Column('Id')]
    property Id: Integer read FId write FId;
    
    [Column('RoomId')]
    [ForeignKey('ChatRooms', 'Id')]
    property RoomId: Integer read FRoomId write FRoomId;
    
    [Column('UserId')]
    [ForeignKey('ChatUsers', 'Id')]
    property UserId: Integer read FUserId write FUserId;
    
    [Column('Role')]
    property Role: TMemberRole read FRole write FRole;
    
    [Column('JoinedAt')]
    property JoinedAt: TDateTime read FJoinedAt write FJoinedAt;
    
    [Column('LastReadAt')]
    property LastReadAt: TDateTime read FLastReadAt write FLastReadAt;
    
    [Column('IsMuted')]
    property IsMuted: Boolean read FIsMuted write FIsMuted;
    
    [Column('IsPinned')]
    property IsPinned: Boolean read FIsPinned write FIsPinned;
    
    function RoleText: string;
    function CanModerate: Boolean;
  end;

  [Table('ChatMessages')]
  TChatMessage = class
  private
    FId: Int64;
    FRoomId: Integer;
    FSenderId: Integer;
    FMessageType: TMessageType;
    FContent: string;
    FMediaUrl: string;
    FMediaSize: Int64;
    FMediaName: string;
    FReplyToId: Int64;
    FCreatedAt: TDateTime;
    FEditedAt: TDateTime;
    FIsDeleted: Boolean;
    FIsEdited: Boolean;
    FIsPinned: Boolean;
  public
    [PrimaryKey]
    [Column('Id')]
    property Id: Int64 read FId write FId;
    
    [Column('RoomId')]
    [ForeignKey('ChatRooms', 'Id')]
    [Index]
    property RoomId: Integer read FRoomId write FRoomId;
    
    [Column('SenderId')]
    [ForeignKey('ChatUsers', 'Id')]
    property SenderId: Integer read FSenderId write FSenderId;
    
    [Column('MessageType')]
    property MessageType: TMessageType read FMessageType write FMessageType;
    
    [Column('Content')]
    property Content: string read FContent write FContent;
    
    [Column('MediaUrl')]
    property MediaUrl: string read FMediaUrl write FMediaUrl;
    
    [Column('MediaSize')]
    property MediaSize: Int64 read FMediaSize write FMediaSize;
    
    [Column('MediaName')]
    property MediaName: string read FMediaName write FMediaName;
    
    [Column('ReplyToId')]
    property ReplyToId: Int64 read FReplyToId write FReplyToId;
    
    [Column('CreatedAt')]
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    
    [Column('EditedAt')]
    property EditedAt: TDateTime read FEditedAt write FEditedAt;
    
    [Column('IsDeleted')]
    property IsDeleted: Boolean read FIsDeleted write FIsDeleted;
    
    [Column('IsEdited')]
    property IsEdited: Boolean read FIsEdited write FIsEdited;
    
    [Column('IsPinned')]
    property IsPinned: Boolean read FIsPinned write FIsPinned;
    
    function IsSystemMessage: Boolean;
    function IsMediaMessage: Boolean;
    function GetTimeAgo: string;
  end;

  [Table('MessageReactions')]
  TMessageReaction = class
  private
    FId: Integer;
    FMessageId: Int64;
    FUserId: Integer;
    FEmoji: string;
    FCreatedAt: TDateTime;
  public
    [PrimaryKey]
    [Column('Id')]
    property Id: Integer read FId write FId;
    
    [Column('MessageId')]
    [ForeignKey('ChatMessages', 'Id')]
    property MessageId: Int64 read FMessageId write FMessageId;
    
    [Column('UserId')]
    [ForeignKey('ChatUsers', 'Id')]
    property UserId: Integer read FUserId write FUserId;
    
    [Column('Emoji')]
    property Emoji: string read FEmoji write FEmoji;
    
    [Column('CreatedAt')]
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
  end;

  TReactionSummary = record
    Emoji: string;
    Count: Integer;
    UserIds: TArray<Integer>;
  end;

  TMessageWithSender = record
    Message: TChatMessage;
    Sender: TChatUser;
    Reactions: TArray<TReactionSummary>;
    ReplyTo: TChatMessage;
  end;

  TRoomWithLastMessage = record
    Room: TChatRoom;
    LastMessage: TChatMessage;
    UnreadCount: Integer;
    OtherUser: TChatUser; // For private chats
  end;

  TTypingUser = record
    UserId: Integer;
    Username: string;
    StartedAt: TDateTime;
  end;

implementation

uses
  System.DateUtils;

{ TChatUser }

function TChatUser.StatusText: string;
const
  StatusTexts: array[TUserStatus] of string = (
    'Online', 'Away', 'Busy', 'Offline', 'Invisible'
  );
begin
  Result := StatusTexts[FStatus];
end;

function TChatUser.GetInitials: string;
var
  Parts: TArray<string>;
begin
  if FDisplayName <> '' then
  begin
    Parts := FDisplayName.Split([' ']);
    if Length(Parts) >= 2 then
      Result := UpperCase(Parts[0][1] + Parts[High(Parts)][1])
    else if Length(Parts) = 1 then
      Result := UpperCase(Copy(Parts[0], 1, 2));
  end
  else
    Result := UpperCase(Copy(FUsername, 1, 2));
end;

{ TChatRoom }

function TChatRoom.RoomTypeText: string;
const
  TypeTexts: array[TRoomType] of string = (
    'Private', 'Group', 'Channel', 'Support'
  );
begin
  Result := TypeTexts[FRoomType];
end;

function TChatRoom.IsPrivateChat: Boolean;
begin
  Result := FRoomType = rtPrivate;
end;

{ TRoomMember }

function TRoomMember.RoleText: string;
const
  RoleTexts: array[TMemberRole] of string = (
    'Member', 'Moderator', 'Admin', 'Owner'
  );
begin
  Result := RoleTexts[FRole];
end;

function TRoomMember.CanModerate: Boolean;
begin
  Result := FRole in [mrModerator, mrAdmin, mrOwner];
end;

{ TChatMessage }

function TChatMessage.IsSystemMessage: Boolean;
begin
  Result := FMessageType in [mtSystem, mtJoin, mtLeave];
end;

function TChatMessage.IsMediaMessage: Boolean;
begin
  Result := FMessageType in [mtImage, mtFile, mtAudio, mtVideo];
end;

function TChatMessage.GetTimeAgo: string;
var
  Diff: TDateTime;
  Minutes, Hours, Days: Integer;
begin
  Diff := Now - FCreatedAt;
  Minutes := MinutesBetween(Now, FCreatedAt);
  Hours := HoursBetween(Now, FCreatedAt);
  Days := DaysBetween(Now, FCreatedAt);
  
  if Minutes < 1 then
    Result := 'Just now'
  else if Minutes < 60 then
    Result := Format('%d min ago', [Minutes])
  else if Hours < 24 then
    Result := Format('%d hr ago', [Hours])
  else if Days < 7 then
    Result := Format('%d days ago', [Days])
  else
    Result := FormatDateTime('yyyy-mm-dd', FCreatedAt);
end;

end.
