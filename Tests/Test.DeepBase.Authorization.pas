{ ============================================================================
  Test.DeepBase.Authorization - Authorization Module Unit Tests
  ============================================================================ }

unit Test.DeepBase.Authorization;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DeepBase.Authorization;

type
  [TestFixture]
  TAuthorizationTests = class
  private
    FAuthManager: TAuthorizationManager;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    // User Management Tests
    [Test]
    procedure Test_CreateUser_Success;
    [Test]
    procedure Test_CreateUser_Duplicate_Fails;
    [Test]
    procedure Test_GetUser_Exists;
    [Test]
    procedure Test_GetUser_NotExists_ReturnsNil;
    [Test]
    procedure Test_DeleteUser_Success;
    [Test]
    procedure Test_DeleteUser_NotExists_Raises;
    
    // Role Management Tests
    [Test]
    procedure Test_CreateRole_Success;
    [Test]
    procedure Test_CreateRole_Duplicate_Fails;
    [Test]
    procedure Test_DeleteRole_Success;
    
    // Permission Tests
    [Test]
    procedure Test_GrantPermission_Success;
    [Test]
    procedure Test_RevokePermission_Success;
    [Test]
    procedure Test_HasPermission_Direct;
    [Test]
    procedure Test_HasPermission_NoPermission;
    
    // Role Assignment Tests
    [Test]
    procedure Test_AssignRole_Success;
    [Test]
    procedure Test_RemoveRole_Success;
    [Test]
    procedure Test_UserHasRole;
    
    // Permission Inheritance Tests
    [Test]
    procedure Test_HasPermission_FromRole;
    [Test]
    procedure Test_HasPermission_FromParentRole;
    [Test]
    procedure Test_HasAnyPermission;
    [Test]
    procedure Test_HasAllPermissions;
    
    // Current User Context Tests
    [Test]
    procedure Test_SetCurrentUser_Success;
    [Test]
    procedure Test_CurrentUserCan_HasPermission;
    [Test]
    procedure Test_CurrentUserCan_NoPermission;
    [Test]
    procedure Test_RequirePermission_Success;
    [Test]
    procedure Test_RequirePermission_Denied;
    
    // Audit Tests
    [Test]
    procedure Test_AuditLog_UserCreated;
    [Test]
    procedure Test_AuditLog_PermissionDenied;
    [Test]
    procedure Test_GetAuditLog;
    [Test]
    procedure Test_StorageInjection_BasicFlow;
  end;

implementation

type
  TInMemoryAuthorizationStorage = class(TInterfacedObject, IAuthorizationStorage)
  private
    FRoles: TDictionary<string, TAuthorizationRoleData>;
    FUsers: TDictionary<string, TAuthorizationUserData>;
    FRolePermissions: TList<TAuthorizationRolePermissionData>;
    FUserRoles: TList<TAuthorizationUserRoleData>;
    FAudit: TList<TAuthorizationAuditData>;
    FNextRoleId: Integer;
    FNextUserId: Integer;
    FNextAuditId: Int64;
    function TryFindRoleNameById(RoleId: Integer; out RoleName: string): Boolean;
    function TryFindUserNameById(UserId: Integer; out Username: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure EnsureTablesExist;
    function ReadRoles: TArray<TAuthorizationRoleData>;
    function ReadRolePermissions: TArray<TAuthorizationRolePermissionData>;
    function ReadUsers: TArray<TAuthorizationUserData>;
    function ReadUserRoles: TArray<TAuthorizationUserRoleData>;
    function InsertUser(const Data: TAuthorizationUserData): Integer;
    procedure UpdateUser(const Data: TAuthorizationUserData);
    procedure DeleteUser(const Username: string);
    function InsertRole(const Data: TAuthorizationRoleData): Integer;
    procedure UpdateRole(const Data: TAuthorizationRoleData);
    procedure ReplaceRolePermissions(RoleId: Integer; const Permissions: TArray<string>);
    procedure DeleteRole(const RoleName: string);
    procedure AssignUserRole(UserId, RoleId: Integer);
    procedure RemoveUserRole(UserId, RoleId: Integer);
    procedure InsertAudit(const Username, ActionName, Resource, Details: string;
      Success: Boolean);
    function ReadAudit(const Username: string; StartDate, EndDate: TDateTime;
      MaxEntries: Integer): TArray<TAuthorizationAuditData>;
    procedure ClearAuditBefore(const CutoffDate: TDateTime);
  end;

constructor TInMemoryAuthorizationStorage.Create;
begin
  inherited Create;
  FRoles := TDictionary<string, TAuthorizationRoleData>.Create;
  FUsers := TDictionary<string, TAuthorizationUserData>.Create;
  FRolePermissions := TList<TAuthorizationRolePermissionData>.Create;
  FUserRoles := TList<TAuthorizationUserRoleData>.Create;
  FAudit := TList<TAuthorizationAuditData>.Create;
  FNextRoleId := 1;
  FNextUserId := 1;
  FNextAuditId := 1;
end;

destructor TInMemoryAuthorizationStorage.Destroy;
begin
  FAudit.Free;
  FUserRoles.Free;
  FRolePermissions.Free;
  FUsers.Free;
  FRoles.Free;
  inherited;
end;

procedure TInMemoryAuthorizationStorage.EnsureTablesExist;
begin
  // no-op for in-memory storage
end;

function TInMemoryAuthorizationStorage.ReadRoles: TArray<TAuthorizationRoleData>;
var
  Data: TAuthorizationRoleData;
begin
  SetLength(Result, 0);
  for Data in FRoles.Values do
    if Data.IsActive then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Data;
    end;
end;

function TInMemoryAuthorizationStorage.ReadRolePermissions: TArray<TAuthorizationRolePermissionData>;
begin
  Result := FRolePermissions.ToArray;
end;

function TInMemoryAuthorizationStorage.ReadUsers: TArray<TAuthorizationUserData>;
var
  Data: TAuthorizationUserData;
begin
  SetLength(Result, 0);
  for Data in FUsers.Values do
    if Data.IsActive then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Data;
    end;
end;

function TInMemoryAuthorizationStorage.ReadUserRoles: TArray<TAuthorizationUserRoleData>;
begin
  Result := FUserRoles.ToArray;
end;

function TInMemoryAuthorizationStorage.InsertUser(const Data: TAuthorizationUserData): Integer;
var
  Stored: TAuthorizationUserData;
begin
  Stored := Data;
  Stored.Id := FNextUserId;
  Inc(FNextUserId);
  if Stored.CreatedAt = 0 then
    Stored.CreatedAt := Now;
  Stored.UpdatedAt := Now;
  FUsers.AddOrSetValue(Stored.Username, Stored);
  Result := Stored.Id;
end;

procedure TInMemoryAuthorizationStorage.UpdateUser(const Data: TAuthorizationUserData);
begin
  FUsers.AddOrSetValue(Data.Username, Data);
end;

procedure TInMemoryAuthorizationStorage.DeleteUser(const Username: string);
var
  I: Integer;
begin
  FUsers.Remove(Username);
  for I := FUserRoles.Count - 1 downto 0 do
    if SameText(FUserRoles[I].Username, Username) then
      FUserRoles.Delete(I);
end;

function TInMemoryAuthorizationStorage.InsertRole(const Data: TAuthorizationRoleData): Integer;
var
  Stored: TAuthorizationRoleData;
begin
  Stored := Data;
  Stored.Id := FNextRoleId;
  Inc(FNextRoleId);
  if Stored.CreatedAt = 0 then
    Stored.CreatedAt := Now;
  Stored.UpdatedAt := Now;
  FRoles.AddOrSetValue(Stored.Name, Stored);
  Result := Stored.Id;
end;

procedure TInMemoryAuthorizationStorage.UpdateRole(const Data: TAuthorizationRoleData);
begin
  FRoles.AddOrSetValue(Data.Name, Data);
end;

function TInMemoryAuthorizationStorage.TryFindRoleNameById(RoleId: Integer;
  out RoleName: string): Boolean;
var
  Pair: TPair<string, TAuthorizationRoleData>;
begin
  for Pair in FRoles do
    if Pair.Value.Id = RoleId then
    begin
      RoleName := Pair.Key;
      Exit(True);
    end;
  RoleName := '';
  Result := False;
end;

function TInMemoryAuthorizationStorage.TryFindUserNameById(UserId: Integer;
  out Username: string): Boolean;
var
  Pair: TPair<string, TAuthorizationUserData>;
begin
  for Pair in FUsers do
    if Pair.Value.Id = UserId then
    begin
      Username := Pair.Key;
      Exit(True);
    end;
  Username := '';
  Result := False;
end;

procedure TInMemoryAuthorizationStorage.ReplaceRolePermissions(RoleId: Integer;
  const Permissions: TArray<string>);
var
  RoleName: string;
  I: Integer;
  Item: TAuthorizationRolePermissionData;
  Permission: string;
begin
  if not TryFindRoleNameById(RoleId, RoleName) then
    Exit;

  for I := FRolePermissions.Count - 1 downto 0 do
    if SameText(FRolePermissions[I].RoleName, RoleName) then
      FRolePermissions.Delete(I);

  for Permission in Permissions do
  begin
    Item.RoleName := RoleName;
    Item.Permission := Permission;
    FRolePermissions.Add(Item);
  end;
end;

procedure TInMemoryAuthorizationStorage.DeleteRole(const RoleName: string);
var
  I: Integer;
begin
  FRoles.Remove(RoleName);

  for I := FRolePermissions.Count - 1 downto 0 do
    if SameText(FRolePermissions[I].RoleName, RoleName) then
      FRolePermissions.Delete(I);

  for I := FUserRoles.Count - 1 downto 0 do
    if SameText(FUserRoles[I].RoleName, RoleName) then
      FUserRoles.Delete(I);
end;

procedure TInMemoryAuthorizationStorage.AssignUserRole(UserId, RoleId: Integer);
var
  Username: string;
  RoleName: string;
  I: Integer;
  Item: TAuthorizationUserRoleData;
begin
  if not TryFindUserNameById(UserId, Username) then
    Exit;
  if not TryFindRoleNameById(RoleId, RoleName) then
    Exit;

  for I := 0 to FUserRoles.Count - 1 do
    if SameText(FUserRoles[I].Username, Username) and
       SameText(FUserRoles[I].RoleName, RoleName) then
      Exit;

  Item.Username := Username;
  Item.RoleName := RoleName;
  FUserRoles.Add(Item);
end;

procedure TInMemoryAuthorizationStorage.RemoveUserRole(UserId, RoleId: Integer);
var
  Username: string;
  RoleName: string;
  I: Integer;
begin
  if not TryFindUserNameById(UserId, Username) then
    Exit;
  if not TryFindRoleNameById(RoleId, RoleName) then
    Exit;

  for I := FUserRoles.Count - 1 downto 0 do
    if SameText(FUserRoles[I].Username, Username) and
       SameText(FUserRoles[I].RoleName, RoleName) then
      FUserRoles.Delete(I);
end;

procedure TInMemoryAuthorizationStorage.InsertAudit(const Username, ActionName,
  Resource, Details: string; Success: Boolean);
var
  Item: TAuthorizationAuditData;
begin
  Item.Id := FNextAuditId;
  Inc(FNextAuditId);
  Item.Timestamp := Now;
  Item.Username := Username;
  Item.Action := ActionName;
  Item.Resource := Resource;
  Item.Details := Details;
  Item.IPAddress := '';
  Item.Success := Success;
  FAudit.Add(Item);
end;

function TInMemoryAuthorizationStorage.ReadAudit(const Username: string;
  StartDate, EndDate: TDateTime; MaxEntries: Integer): TArray<TAuthorizationAuditData>;
var
  I: Integer;
  Item: TAuthorizationAuditData;
begin
  SetLength(Result, 0);
  for I := FAudit.Count - 1 downto 0 do
  begin
    Item := FAudit[I];
    if (Username <> '') and (not SameText(Item.Username, Username)) then
      Continue;
    if (StartDate > 0) and (Item.Timestamp < StartDate) then
      Continue;
    if (EndDate > 0) and (Item.Timestamp > EndDate) then
      Continue;

    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Item;
    if (MaxEntries > 0) and (Length(Result) >= MaxEntries) then
      Break;
  end;
end;

procedure TInMemoryAuthorizationStorage.ClearAuditBefore(const CutoffDate: TDateTime);
var
  I: Integer;
begin
  for I := FAudit.Count - 1 downto 0 do
    if FAudit[I].Timestamp < CutoffDate then
      FAudit.Delete(I);
end;

{ TAuthorizationTests }

procedure TAuthorizationTests.Setup;
var
  Storage: IAuthorizationStorage;
begin
  Storage := TInMemoryAuthorizationStorage.Create;
  FAuthManager := TAuthorizationManager.Create(Storage);
end;

procedure TAuthorizationTests.TearDown;
begin
  FAuthManager.Free;
end;

// ============================================================================
// User Management Tests
// ============================================================================

procedure TAuthorizationTests.Test_CreateUser_Success;
var
  User: TUser;
begin
  User := FAuthManager.CreateUser('testuser', 'Test User');
  
  Assert.IsNotNull(User);
  Assert.AreEqual('testuser', User.Username);
  Assert.AreEqual('Test User', User.DisplayName);
  Assert.IsTrue(User.Id > 0);
  Assert.IsTrue(User.IsActive);
end;

procedure TAuthorizationTests.Test_CreateUser_Duplicate_Fails;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  
  Assert.WillRaise(
    procedure
    begin
      FAuthManager.CreateUser('testuser', 'Another User');
    end,
    EAuthorizationException
  );
end;

procedure TAuthorizationTests.Test_GetUser_Exists;
var
  User: TUser;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  
  User := FAuthManager.GetUser('testuser');
  
  Assert.IsNotNull(User);
  Assert.AreEqual('testuser', User.Username);
end;

procedure TAuthorizationTests.Test_GetUser_NotExists_ReturnsNil;
var
  User: TUser;
begin
  User := FAuthManager.GetUser('nonexistent');
  
  Assert.IsNull(User);
end;

procedure TAuthorizationTests.Test_DeleteUser_Success;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  
  FAuthManager.DeleteUser('testuser');
  
  Assert.IsFalse(FAuthManager.UserExists('testuser'));
end;

procedure TAuthorizationTests.Test_DeleteUser_NotExists_Raises;
begin
  Assert.WillRaise(
    procedure
    begin
      FAuthManager.DeleteUser('nonexistent');
    end,
    EUserNotFoundException
  );
end;

// ============================================================================
// Role Management Tests
// ============================================================================

procedure TAuthorizationTests.Test_CreateRole_Success;
var
  Role: TRole;
begin
  Role := FAuthManager.CreateRole('admin', 'Administrator');
  
  Assert.IsNotNull(Role);
  Assert.AreEqual('admin', Role.Name);
  Assert.AreEqual('Administrator', Role.DisplayName);
  Assert.IsTrue(Role.Id > 0);
end;

procedure TAuthorizationTests.Test_CreateRole_Duplicate_Fails;
begin
  FAuthManager.CreateRole('admin', 'Administrator');
  
  Assert.WillRaise(
    procedure
    begin
      FAuthManager.CreateRole('admin', 'Another Admin');
    end,
    EAuthorizationException
  );
end;

procedure TAuthorizationTests.Test_DeleteRole_Success;
begin
  FAuthManager.CreateRole('admin', 'Administrator');
  
  FAuthManager.DeleteRole('admin');
  
  Assert.IsFalse(FAuthManager.RoleExists('admin'));
end;

// ============================================================================
// Permission Tests
// ============================================================================

procedure TAuthorizationTests.Test_GrantPermission_Success;
var
  Role: TRole;
begin
  FAuthManager.CreateRole('admin', 'Administrator');
  
  FAuthManager.GrantPermission('admin', 'users.manage');
  
  Role := FAuthManager.GetRole('admin');
  Assert.IsTrue(Role.HasPermission('users.manage'));
end;

procedure TAuthorizationTests.Test_RevokePermission_Success;
var
  Role: TRole;
begin
  FAuthManager.CreateRole('admin', 'Administrator');
  FAuthManager.GrantPermission('admin', 'users.manage');
  
  FAuthManager.RevokePermission('admin', 'users.manage');
  
  Role := FAuthManager.GetRole('admin');
  Assert.IsFalse(Role.HasPermission('users.manage'));
end;

procedure TAuthorizationTests.Test_HasPermission_Direct;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  FAuthManager.CreateRole('admin', 'Administrator');
  FAuthManager.GrantPermission('admin', 'users.manage');
  FAuthManager.AssignRole('testuser', 'admin');
  
  Assert.IsTrue(FAuthManager.HasPermission('testuser', 'users.manage'));
end;

procedure TAuthorizationTests.Test_HasPermission_NoPermission;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  
  Assert.IsFalse(FAuthManager.HasPermission('testuser', 'users.manage'));
end;

// ============================================================================
// Role Assignment Tests
// ============================================================================

procedure TAuthorizationTests.Test_AssignRole_Success;
var
  Roles: TArray<string>;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  FAuthManager.CreateRole('admin', 'Administrator');
  
  FAuthManager.AssignRole('testuser', 'admin');
  
  Roles := FAuthManager.GetUserRoles('testuser');
  Assert.AreEqual<Integer>(1, Length(Roles));
  Assert.AreEqual('admin', Roles[0]);
end;

procedure TAuthorizationTests.Test_RemoveRole_Success;
var
  Roles: TArray<string>;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  FAuthManager.CreateRole('admin', 'Administrator');
  FAuthManager.AssignRole('testuser', 'admin');
  
  FAuthManager.RemoveRole('testuser', 'admin');
  
  Roles := FAuthManager.GetUserRoles('testuser');
  Assert.AreEqual<Integer>(0, Length(Roles));
end;

procedure TAuthorizationTests.Test_UserHasRole;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  FAuthManager.CreateRole('admin', 'Administrator');
  FAuthManager.AssignRole('testuser', 'admin');
  
  Assert.IsTrue(FAuthManager.UserHasRole('testuser', 'admin'));
  Assert.IsFalse(FAuthManager.UserHasRole('testuser', 'viewer'));
end;

// ============================================================================
// Permission Inheritance Tests
// ============================================================================

procedure TAuthorizationTests.Test_HasPermission_FromRole;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  FAuthManager.CreateRole('editor', 'Editor');
  FAuthManager.GrantPermission('editor', 'articles.edit');
  FAuthManager.GrantPermission('editor', 'articles.view');
  FAuthManager.AssignRole('testuser', 'editor');
  
  Assert.IsTrue(FAuthManager.HasPermission('testuser', 'articles.edit'));
  Assert.IsTrue(FAuthManager.HasPermission('testuser', 'articles.view'));
  Assert.IsFalse(FAuthManager.HasPermission('testuser', 'articles.delete'));
end;

procedure TAuthorizationTests.Test_HasPermission_FromParentRole;
var
  Role: TRole;
begin
  // Create parent role with base permissions
  FAuthManager.CreateRole('viewer', 'Viewer');
  FAuthManager.GrantPermission('viewer', 'articles.view');
  
  // Create child role that inherits from parent
  Role := FAuthManager.CreateRole('editor', 'Editor');
  Role.ParentRole := 'viewer';
  FAuthManager.UpdateRole(Role);
  FAuthManager.GrantPermission('editor', 'articles.edit');
  
  // Create user with child role
  FAuthManager.CreateUser('testuser', 'Test User');
  FAuthManager.AssignRole('testuser', 'editor');
  
  // Should have both direct and inherited permissions
  Assert.IsTrue(FAuthManager.HasPermission('testuser', 'articles.edit'));
  Assert.IsTrue(FAuthManager.HasPermission('testuser', 'articles.view'));
end;

procedure TAuthorizationTests.Test_HasAnyPermission;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  FAuthManager.CreateRole('editor', 'Editor');
  FAuthManager.GrantPermission('editor', 'articles.edit');
  FAuthManager.AssignRole('testuser', 'editor');
  
  Assert.IsTrue(FAuthManager.HasAnyPermission('testuser', 
    ['articles.edit', 'articles.delete']));
  Assert.IsFalse(FAuthManager.HasAnyPermission('testuser', 
    ['users.manage', 'users.delete']));
end;

procedure TAuthorizationTests.Test_HasAllPermissions;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  FAuthManager.CreateRole('editor', 'Editor');
  FAuthManager.GrantPermission('editor', 'articles.edit');
  FAuthManager.GrantPermission('editor', 'articles.view');
  FAuthManager.AssignRole('testuser', 'editor');
  
  Assert.IsTrue(FAuthManager.HasAllPermissions('testuser', 
    ['articles.edit', 'articles.view']));
  Assert.IsFalse(FAuthManager.HasAllPermissions('testuser', 
    ['articles.edit', 'articles.delete']));
end;

// ============================================================================
// Current User Context Tests
// ============================================================================

procedure TAuthorizationTests.Test_SetCurrentUser_Success;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  
  FAuthManager.SetCurrentUser('testuser');
  
  Assert.IsNotNull(FAuthManager.CurrentUser);
  Assert.AreEqual('testuser', FAuthManager.CurrentUser.Username);
end;

procedure TAuthorizationTests.Test_CurrentUserCan_HasPermission;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  FAuthManager.CreateRole('admin', 'Administrator');
  FAuthManager.GrantPermission('admin', 'users.manage');
  FAuthManager.AssignRole('testuser', 'admin');
  FAuthManager.SetCurrentUser('testuser');
  
  Assert.IsTrue(FAuthManager.CurrentUserCan('users.manage'));
end;

procedure TAuthorizationTests.Test_CurrentUserCan_NoPermission;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  FAuthManager.SetCurrentUser('testuser');
  
  Assert.IsFalse(FAuthManager.CurrentUserCan('users.manage'));
end;

procedure TAuthorizationTests.Test_RequirePermission_Success;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  FAuthManager.CreateRole('admin', 'Administrator');
  FAuthManager.GrantPermission('admin', 'users.manage');
  FAuthManager.AssignRole('testuser', 'admin');
  FAuthManager.SetCurrentUser('testuser');
  
  // Should not raise
  FAuthManager.RequirePermission('users.manage');
  Assert.Pass;
end;

procedure TAuthorizationTests.Test_RequirePermission_Denied;
var
  Raised: Boolean;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  FAuthManager.SetCurrentUser('testuser');

  Raised := False;
  try
    FAuthManager.RequirePermission('users.manage');
  except
    on E: EPermissionDeniedException do
      Raised := True;
  end;
  Assert.IsTrue(Raised);
end;

// ============================================================================
// Audit Tests
// ============================================================================

procedure TAuthorizationTests.Test_AuditLog_UserCreated;
var
  Logs: TArray<TAuditLogEntry>;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  
  Logs := FAuthManager.GetAuditLog('testuser');
  
  Assert.IsTrue(Length(Logs) >= 1);
end;

procedure TAuthorizationTests.Test_AuditLog_PermissionDenied;
var
  Logs: TArray<TAuditLogEntry>;
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  FAuthManager.SetCurrentUser('testuser');
  
  try
    FAuthManager.RequirePermission('users.manage');
  except
    // Expected
  end;
  
  Logs := FAuthManager.GetAuditLog('testuser');
  
  // Should have login and permission denied entries
  Assert.IsTrue(Length(Logs) >= 2);
end;

procedure TAuthorizationTests.Test_GetAuditLog;
var
  Logs: TArray<TAuditLogEntry>;
begin
  FAuthManager.CreateUser('user1', 'User 1');
  FAuthManager.CreateUser('user2', 'User 2');
  FAuthManager.CreateRole('admin', 'Admin');
  
  // Get all logs
  Logs := FAuthManager.GetAuditLog('', 0, 0, 100);
  Assert.IsTrue(Length(Logs) >= 3);
  
  // Get logs for specific user
  Logs := FAuthManager.GetAuditLog('user1');
  Assert.IsTrue(Length(Logs) >= 1);
end;

procedure TAuthorizationTests.Test_StorageInjection_BasicFlow;
var
  Storage: IAuthorizationStorage;
  ManagerA: TAuthorizationManager;
  ManagerB: TAuthorizationManager;
begin
  Storage := TInMemoryAuthorizationStorage.Create;

  ManagerA := TAuthorizationManager.Create(Storage);
  try
    ManagerA.CreateUser('inject_user', 'Inject User');
    ManagerA.CreateRole('inject_admin', 'Inject Admin');
    ManagerA.GrantPermission('inject_admin', 'users.manage');
    ManagerA.AssignRole('inject_user', 'inject_admin');
    Assert.IsTrue(ManagerA.HasPermission('inject_user', 'users.manage'));
  finally
    ManagerA.Free;
  end;

  ManagerB := TAuthorizationManager.Create(Storage);
  try
    Assert.IsTrue(ManagerB.UserExists('inject_user'));
    Assert.IsTrue(ManagerB.RoleExists('inject_admin'));
    Assert.IsTrue(ManagerB.HasPermission('inject_user', 'users.manage'));
  finally
    ManagerB.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAuthorizationTests);

end.
