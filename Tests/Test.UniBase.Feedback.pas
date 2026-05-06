{ ============================================================================
  Test.UniBase.Feedback - Unit Tests for User Feedback Module
  
  Test Coverage:
    - TAttachmentInfo record operations
    - TSystemInfo record operations
    - TFeedbackItem management
    - TFeedbackComment operations
    - TUserNotification handling
    - Feedback enums
  ============================================================================ }

unit Test.UniBase.Feedback;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  UniBase.Feedback;

type
  [TestFixture]
  TTestAttachmentInfo = class
  public
    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_ToJSON;
    [Test]
    procedure Test_FromJSON;
    [Test]
    procedure Test_Properties;
  end;

  [TestFixture]
  TTestSystemInfo = class
  public
    [Test]
    procedure Test_ToJSON;
    [Test]
    procedure Test_FromJSON;
    [Test]
    procedure Test_AllProperties;
  end;

  [TestFixture]
  TTestFeedbackItem = class
  private
    FItem: TFeedbackItem;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create_Defaults;
    [Test]
    procedure Test_Properties_Basic;
    [Test]
    procedure Test_Properties_User;
    [Test]
    procedure Test_Properties_Timestamps;
    [Test]
    procedure Test_AddAttachment;
    [Test]
    procedure Test_RemoveAttachment;
    [Test]
    procedure Test_ClearAttachments;
    [Test]
    procedure Test_Tags;
    [Test]
    procedure Test_ToJSON;
    [Test]
    procedure Test_FromJSON;
    [Test]
    procedure Test_Validate_EmptyTitle;
    [Test]
    procedure Test_Validate_Valid;
  end;

  [TestFixture]
  TTestFeedbackComment = class
  private
    FComment: TFeedbackComment;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Properties;
    [Test]
    procedure Test_ToJSON;
    [Test]
    procedure Test_FromJSON;
    [Test]
    procedure Test_IsStaff;
  end;

  [TestFixture]
  TTestUserNotification = class
  private
    FNotification: TUserNotification;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Properties;
    [Test]
    procedure Test_ToJSON;
    [Test]
    procedure Test_FromJSON;
    [Test]
    procedure Test_IsRead;
  end;

  [TestFixture]
  TTestFeedbackEnums = class
  public
    [Test]
    procedure Test_FeedbackType_Values;
    [Test]
    procedure Test_FeedbackPriority_Values;
    [Test]
    procedure Test_FeedbackStatus_Values;
    [Test]
    procedure Test_NotificationType_Values;
  end;

implementation

{ TTestAttachmentInfo }

procedure TTestAttachmentInfo.Test_Create;
var
  Info: TAttachmentInfo;
begin
  Info := TAttachmentInfo.Create('screenshot.png', 'C:\Temp\screenshot.png');
  
  Assert.AreEqual('screenshot.png', Info.FileName);
  Assert.AreEqual('C:\Temp\screenshot.png', Info.LocalPath);
  Assert.IsNotEmpty(Info.Id);
end;

procedure TTestAttachmentInfo.Test_ToJSON;
var
  Info: TAttachmentInfo;
  JSON: TJSONObject;
begin
  Info := TAttachmentInfo.Create('log.txt', 'C:\Logs\log.txt');
  Info.FileSize := 1024;
  Info.MimeType := 'text/plain';
  Info.RemoteURL := 'https://storage.example.com/log.txt';
  
  JSON := Info.ToJSON;
  try
    Assert.IsNotNull(JSON);
    Assert.AreEqual('log.txt', JSON.GetValue<string>('fileName'));
    Assert.AreEqual(1024, JSON.GetValue<Integer>('fileSize'));
    Assert.AreEqual('text/plain', JSON.GetValue<string>('mimeType'));
  finally
    JSON.Free;
  end;
end;

procedure TTestAttachmentInfo.Test_FromJSON;
var
  JSON: TJSONObject;
  Info: TAttachmentInfo;
begin
  JSON := TJSONObject.Create;
  try
    JSON.AddPair('id', 'attach-001');
    JSON.AddPair('fileName', 'report.pdf');
    JSON.AddPair('fileSize', TJSONNumber.Create(2048));
    JSON.AddPair('mimeType', 'application/pdf');
    JSON.AddPair('localPath', 'C:\Reports\report.pdf');
    JSON.AddPair('remoteURL', 'https://cdn.example.com/report.pdf');
    JSON.AddPair('uploadedAt', FloatToStr(Now));
    
    Info := TAttachmentInfo.FromJSON(JSON);
    Assert.AreEqual('attach-001', Info.Id);
    Assert.AreEqual('report.pdf', Info.FileName);
    Assert.AreEqual(Int64(2048), Info.FileSize);
    Assert.AreEqual('application/pdf', Info.MimeType);
  finally
    JSON.Free;
  end;
end;

procedure TTestAttachmentInfo.Test_Properties;
var
  Info: TAttachmentInfo;
begin
  Info.Id := 'test-id';
  Info.FileName := 'test.zip';
  Info.FileSize := 5000;
  Info.MimeType := 'application/zip';
  Info.LocalPath := 'C:\Temp\test.zip';
  Info.RemoteURL := 'https://example.com/test.zip';
  Info.UploadedAt := Now;
  
  Assert.AreEqual('test-id', Info.Id);
  Assert.AreEqual('test.zip', Info.FileName);
  Assert.AreEqual(Int64(5000), Info.FileSize);
  Assert.AreEqual('application/zip', Info.MimeType);
end;

{ TTestSystemInfo }

procedure TTestSystemInfo.Test_ToJSON;
var
  Info: TSystemInfo;
  JSON: TJSONObject;
begin
  Info.OSName := 'Windows';
  Info.OSVersion := '10.0.19041';
  Info.CPUName := 'Intel Core i7';
  Info.CPUCores := 8;
  Info.RAMTotalMB := 16384;
  Info.AppVersion := '1.0.0';
  
  JSON := Info.ToJSON;
  try
    Assert.IsNotNull(JSON);
    Assert.AreEqual('Windows', JSON.GetValue<string>('osName'));
    Assert.AreEqual('Intel Core i7', JSON.GetValue<string>('cpuName'));
    Assert.AreEqual(8, JSON.GetValue<Integer>('cpuCores'));
  finally
    JSON.Free;
  end;
end;

procedure TTestSystemInfo.Test_FromJSON;
var
  JSON: TJSONObject;
  Info: TSystemInfo;
begin
  JSON := TJSONObject.Create;
  try
    JSON.AddPair('osName', 'Windows');
    JSON.AddPair('osVersion', '11.0.22000');
    JSON.AddPair('osArchitecture', 'x64');
    JSON.AddPair('cpuName', 'AMD Ryzen 9');
    JSON.AddPair('cpuCores', TJSONNumber.Create(12));
    JSON.AddPair('ramTotalMB', TJSONNumber.Create(32768));
    JSON.AddPair('ramFreeMB', TJSONNumber.Create(16000));
    JSON.AddPair('appVersion', '2.0.0');
    
    Info := TSystemInfo.FromJSON(JSON);
    Assert.AreEqual('Windows', Info.OSName);
    Assert.AreEqual('11.0.22000', Info.OSVersion);
    Assert.AreEqual('x64', Info.OSArchitecture);
    Assert.AreEqual(12, Info.CPUCores);
    Assert.AreEqual(32768, Info.RAMTotalMB);
  finally
    JSON.Free;
  end;
end;

procedure TTestSystemInfo.Test_AllProperties;
var
  Info: TSystemInfo;
begin
  Info.OSName := 'macOS';
  Info.OSVersion := '14.0';
  Info.OSArchitecture := 'arm64';
  Info.CPUName := 'Apple M2';
  Info.CPUCores := 8;
  Info.RAMTotalMB := 16384;
  Info.RAMFreeMB := 8000;
  Info.DiskTotalMB := 512000;
  Info.DiskFreeMB := 256000;
  Info.ScreenWidth := 2560;
  Info.ScreenHeight := 1600;
  Info.AppVersion := '1.5.0';
  Info.AppBuildDate := '2025-12-01';
  Info.DelphiVersion := 'Delphi 12';
  Info.UserLocale := 'zh-CN';
  Info.TimeZone := 'Asia/Shanghai';
  
  Assert.AreEqual('macOS', Info.OSName);
  Assert.AreEqual('arm64', Info.OSArchitecture);
  Assert.AreEqual(8, Info.CPUCores);
  Assert.AreEqual(2560, Info.ScreenWidth);
  Assert.AreEqual('zh-CN', Info.UserLocale);
end;

{ TTestFeedbackItem }

procedure TTestFeedbackItem.Setup;
begin
  FItem := TFeedbackItem.Create;
end;

procedure TTestFeedbackItem.TearDown;
begin
  FItem.Free;
end;

procedure TTestFeedbackItem.Test_Create_Defaults;
begin
  Assert.IsNotNull(FItem.Attachments);
  Assert.IsNotNull(FItem.Tags);
  Assert.AreEqual(0, Integer(FItem.Attachments.Count));
  Assert.IsFalse(FItem.IsSubmitted);
end;

procedure TTestFeedbackItem.Test_Properties_Basic;
begin
  FItem.Id := 'fb-001';
  FItem.FeedbackType := ftBug;
  FItem.Priority := fpHigh;
  FItem.Status := fsNew;
  FItem.Title := 'Application crashes on startup';
  FItem.Description := 'When I start the app, it crashes immediately.';
  FItem.StepsToReproduce := '1. Launch app\n2. Wait for crash';
  FItem.ExpectedBehavior := 'App should start normally';
  FItem.ActualBehavior := 'App crashes with error';
  
  Assert.AreEqual('fb-001', FItem.Id);
  Assert.AreEqual(ftBug, FItem.FeedbackType);
  Assert.AreEqual(fpHigh, FItem.Priority);
  Assert.AreEqual(fsNew, FItem.Status);
  Assert.AreEqual('Application crashes on startup', FItem.Title);
end;

procedure TTestFeedbackItem.Test_Properties_User;
begin
  FItem.UserId := 'user-123';
  FItem.UserEmail := 'user@example.com';
  FItem.UserName := 'John Doe';
  FItem.TrackingCode := 'TRK-2025-001';
  
  Assert.AreEqual('user-123', FItem.UserId);
  Assert.AreEqual('user@example.com', FItem.UserEmail);
  Assert.AreEqual('John Doe', FItem.UserName);
  Assert.AreEqual('TRK-2025-001', FItem.TrackingCode);
end;

procedure TTestFeedbackItem.Test_Properties_Timestamps;
var
  CreateTime, UpdateTime, SubmitTime: TDateTime;
begin
  CreateTime := Now;
  UpdateTime := Now + 1;
  SubmitTime := Now + 2;
  
  FItem.CreatedAt := CreateTime;
  FItem.UpdatedAt := UpdateTime;
  FItem.SubmittedAt := SubmitTime;
  FItem.IsSubmitted := True;
  
  Assert.AreEqual(CreateTime, FItem.CreatedAt);
  Assert.AreEqual(UpdateTime, FItem.UpdatedAt);
  Assert.AreEqual(SubmitTime, FItem.SubmittedAt);
  Assert.IsTrue(FItem.IsSubmitted);
end;

procedure TTestFeedbackItem.Test_AddAttachment;
var
  Attachment: TAttachmentInfo;
begin
  Attachment := TAttachmentInfo.Create('test.png', 'C:\Temp\test.png');
  FItem.AddAttachment(Attachment);
  
  Assert.AreEqual(1, Integer(FItem.Attachments.Count));
  Assert.AreEqual('test.png', FItem.Attachments[0].FileName);
end;

procedure TTestFeedbackItem.Test_RemoveAttachment;
var
  Att1, Att2: TAttachmentInfo;
begin
  Att1 := TAttachmentInfo.Create('keep.png', 'C:\keep.png');
  Att2 := TAttachmentInfo.Create('remove.png', 'C:\remove.png');
  
  FItem.AddAttachment(Att1);
  FItem.AddAttachment(Att2);
  
  FItem.RemoveAttachment(Att2.Id);
  
  Assert.AreEqual(1, Integer(FItem.Attachments.Count));
  Assert.AreEqual('keep.png', FItem.Attachments[0].FileName);
end;

procedure TTestFeedbackItem.Test_ClearAttachments;
begin
  FItem.AddAttachment(TAttachmentInfo.Create('a.png', 'C:\a.png'));
  FItem.AddAttachment(TAttachmentInfo.Create('b.png', 'C:\b.png'));
  FItem.AddAttachment(TAttachmentInfo.Create('c.png', 'C:\c.png'));
  
  FItem.ClearAttachments;
  
  Assert.AreEqual(0, Integer(FItem.Attachments.Count));
end;

procedure TTestFeedbackItem.Test_Tags;
begin
  FItem.Tags.Add('urgent');
  FItem.Tags.Add('ui');
  FItem.Tags.Add('crash');
  
  Assert.AreEqual(3, Integer(FItem.Tags.Count));
  Assert.AreEqual('urgent', FItem.Tags[0]);
  Assert.AreEqual('ui', FItem.Tags[1]);
  Assert.AreEqual('crash', FItem.Tags[2]);
end;

procedure TTestFeedbackItem.Test_ToJSON;
var
  JSON: TJSONObject;
begin
  FItem.Id := 'json-test';
  FItem.Title := 'JSON Test Feedback';
  FItem.FeedbackType := ftFeature;
  FItem.Priority := fpNormal;
  FItem.Status := fsPending;
  
  JSON := FItem.ToJSON;
  try
    Assert.IsNotNull(JSON);
    Assert.AreEqual('json-test', JSON.GetValue<string>('id'));
    Assert.AreEqual('JSON Test Feedback', JSON.GetValue<string>('title'));
  finally
    JSON.Free;
  end;
end;

procedure TTestFeedbackItem.Test_FromJSON;
var
  JSON: TJSONObject;
  Item: TFeedbackItem;
begin
  JSON := TJSONObject.Create;
  try
    JSON.AddPair('id', 'from-json');
    JSON.AddPair('feedbackType', TJSONNumber.Create(Ord(ftBug)));
    JSON.AddPair('priority', TJSONNumber.Create(Ord(fpCritical)));
    JSON.AddPair('status', TJSONNumber.Create(Ord(fsInProgress)));
    JSON.AddPair('title', 'Critical Bug');
    JSON.AddPair('description', 'System failure');
    JSON.AddPair('userId', 'admin');
    JSON.AddPair('isSubmitted', TJSONBool.Create(True));
    JSON.AddPair('createdAt', FloatToStr(Now));
    
    Item := TFeedbackItem.FromJSON(JSON);
    try
      Assert.AreEqual('from-json', Item.Id);
      Assert.AreEqual(ftBug, Item.FeedbackType);
      Assert.AreEqual(fpCritical, Item.Priority);
      Assert.AreEqual(fsInProgress, Item.Status);
      Assert.AreEqual('Critical Bug', Item.Title);
    finally
      Item.Free;
    end;
  finally
    JSON.Free;
  end;
end;

procedure TTestFeedbackItem.Test_Validate_EmptyTitle;
var
  Errors: TArray<string>;
begin
  FItem.Title := '';
  FItem.Description := 'Some description';
  
  Errors := FItem.Validate;
  
  Assert.IsTrue(Length(Errors) > 0);
end;

procedure TTestFeedbackItem.Test_Validate_Valid;
var
  Errors: TArray<string>;
begin
  FItem.Title := 'Valid title';
  FItem.Description := 'Valid description';
  FItem.FeedbackType := ftBug;
  
  Errors := FItem.Validate;
  
  Assert.AreEqual(0, Integer(Length(Errors)));
end;

{ TTestFeedbackComment }

procedure TTestFeedbackComment.Setup;
begin
  FComment := TFeedbackComment.Create;
end;

procedure TTestFeedbackComment.TearDown;
begin
  FComment.Free;
end;

procedure TTestFeedbackComment.Test_Properties;
begin
  FComment.Id := 'comment-001';
  FComment.FeedbackId := 'fb-001';
  FComment.AuthorId := 'user-001';
  FComment.AuthorName := 'Support Team';
  FComment.Content := 'We are looking into this issue.';
  FComment.IsStaff := True;
  FComment.CreatedAt := Now;
  
  Assert.AreEqual('comment-001', FComment.Id);
  Assert.AreEqual('fb-001', FComment.FeedbackId);
  Assert.AreEqual('Support Team', FComment.AuthorName);
  Assert.AreEqual('We are looking into this issue.', FComment.Content);
  Assert.IsTrue(FComment.IsStaff);
end;

procedure TTestFeedbackComment.Test_ToJSON;
var
  JSON: TJSONObject;
begin
  FComment.Id := 'json-comment';
  FComment.Content := 'Test comment';
  FComment.IsStaff := False;
  
  JSON := FComment.ToJSON;
  try
    Assert.IsNotNull(JSON);
    Assert.AreEqual('json-comment', JSON.GetValue<string>('id'));
    Assert.AreEqual('Test comment', JSON.GetValue<string>('content'));
  finally
    JSON.Free;
  end;
end;

procedure TTestFeedbackComment.Test_FromJSON;
var
  JSON: TJSONObject;
  Comment: TFeedbackComment;
begin
  JSON := TJSONObject.Create;
  try
    JSON.AddPair('id', 'parsed-comment');
    JSON.AddPair('feedbackId', 'fb-123');
    JSON.AddPair('authorId', 'support-1');
    JSON.AddPair('authorName', 'Admin');
    JSON.AddPair('content', 'Issue resolved');
    JSON.AddPair('isStaff', TJSONBool.Create(True));
    JSON.AddPair('createdAt', FloatToStr(Now));
    
    Comment := TFeedbackComment.FromJSON(JSON);
    try
      Assert.AreEqual('parsed-comment', Comment.Id);
      Assert.AreEqual('Issue resolved', Comment.Content);
      Assert.IsTrue(Comment.IsStaff);
    finally
      Comment.Free;
    end;
  finally
    JSON.Free;
  end;
end;

procedure TTestFeedbackComment.Test_IsStaff;
begin
  FComment.IsStaff := False;
  Assert.IsFalse(FComment.IsStaff);
  
  FComment.IsStaff := True;
  Assert.IsTrue(FComment.IsStaff);
end;

{ TTestUserNotification }

procedure TTestUserNotification.Setup;
begin
  FNotification := TUserNotification.Create;
end;

procedure TTestUserNotification.TearDown;
begin
  FNotification.Free;
end;

procedure TTestUserNotification.Test_Properties;
begin
  FNotification.Id := 'notif-001';
  FNotification.NotificationType := ntStatusChange;
  FNotification.Title := 'Status Updated';
  FNotification.Message := 'Your feedback has been marked as In Progress';
  FNotification.FeedbackId := 'fb-001';
  FNotification.IsRead := False;
  FNotification.CreatedAt := Now;
  
  Assert.AreEqual('notif-001', FNotification.Id);
  Assert.AreEqual(ntStatusChange, FNotification.NotificationType);
  Assert.AreEqual('Status Updated', FNotification.Title);
  Assert.AreEqual('fb-001', FNotification.FeedbackId);
  Assert.IsFalse(FNotification.IsRead);
end;

procedure TTestUserNotification.Test_ToJSON;
var
  JSON: TJSONObject;
begin
  FNotification.Id := 'json-notif';
  FNotification.Title := 'New Comment';
  FNotification.NotificationType := ntComment;
  
  JSON := FNotification.ToJSON;
  try
    Assert.IsNotNull(JSON);
    Assert.AreEqual('json-notif', JSON.GetValue<string>('id'));
    Assert.AreEqual('New Comment', JSON.GetValue<string>('title'));
  finally
    JSON.Free;
  end;
end;

procedure TTestUserNotification.Test_FromJSON;
var
  JSON: TJSONObject;
  Notification: TUserNotification;
begin
  JSON := TJSONObject.Create;
  try
    JSON.AddPair('id', 'parsed-notif');
    JSON.AddPair('notificationType', TJSONNumber.Create(Ord(ntResolution)));
    JSON.AddPair('title', 'Issue Resolved');
    JSON.AddPair('message', 'Your issue has been fixed in v2.0.1');
    JSON.AddPair('feedbackId', 'fb-999');
    JSON.AddPair('isRead', TJSONBool.Create(True));
    JSON.AddPair('createdAt', FloatToStr(Now));
    
    Notification := TUserNotification.FromJSON(JSON);
    try
      Assert.AreEqual('parsed-notif', Notification.Id);
      Assert.AreEqual(ntResolution, Notification.NotificationType);
      Assert.AreEqual('Issue Resolved', Notification.Title);
      Assert.IsTrue(Notification.IsRead);
    finally
      Notification.Free;
    end;
  finally
    JSON.Free;
  end;
end;

procedure TTestUserNotification.Test_IsRead;
begin
  FNotification.IsRead := False;
  Assert.IsFalse(FNotification.IsRead);
  
  FNotification.IsRead := True;
  FNotification.ReadAt := Now;
  Assert.IsTrue(FNotification.IsRead);
end;

{ TTestFeedbackEnums }

procedure TTestFeedbackEnums.Test_FeedbackType_Values;
begin
  Assert.AreEqual(0, Ord(ftBug));
  Assert.AreEqual(1, Ord(ftFeature));
  Assert.AreEqual(2, Ord(ftQuestion));
  Assert.AreEqual(3, Ord(ftImprovement));
  Assert.AreEqual(4, Ord(ftCrash));
  Assert.AreEqual(5, Ord(ftPerformance));
  Assert.AreEqual(6, Ord(ftOther));
end;

procedure TTestFeedbackEnums.Test_FeedbackPriority_Values;
begin
  Assert.AreEqual(0, Ord(fpLow));
  Assert.AreEqual(1, Ord(fpNormal));
  Assert.AreEqual(2, Ord(fpHigh));
  Assert.AreEqual(3, Ord(fpCritical));
end;

procedure TTestFeedbackEnums.Test_FeedbackStatus_Values;
begin
  Assert.AreEqual(0, Ord(fsNew));
  Assert.AreEqual(1, Ord(fsPending));
  Assert.AreEqual(2, Ord(fsInProgress));
  Assert.AreEqual(3, Ord(fsResolved));
  Assert.AreEqual(4, Ord(fsClosed));
  Assert.AreEqual(5, Ord(fsRejected));
end;

procedure TTestFeedbackEnums.Test_NotificationType_Values;
begin
  Assert.AreEqual(0, Ord(ntStatusChange));
  Assert.AreEqual(1, Ord(ntComment));
  Assert.AreEqual(2, Ord(ntAssignment));
  Assert.AreEqual(3, Ord(ntResolution));
  Assert.AreEqual(4, Ord(ntAnnouncement));
  Assert.AreEqual(5, Ord(ntReminder));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestAttachmentInfo);
  TDUnitX.RegisterTestFixture(TTestSystemInfo);
  TDUnitX.RegisterTestFixture(TTestFeedbackItem);
  TDUnitX.RegisterTestFixture(TTestFeedbackComment);
  TDUnitX.RegisterTestFixture(TTestUserNotification);
  TDUnitX.RegisterTestFixture(TTestFeedbackEnums);

end.
