{ ============================================================================
  Test.UniBase.Authorization - Authorization Module Unit Tests
  ============================================================================ }

unit Test.UniBase.Authorization;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Phys.SQLite,
  UniBase.Authorization;

type
  [TestFixture]
  TAuthorizationTests = class
  private
    FConnection: TFDConnection;
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
  end;

implementation

{ TAuthorizationTests }

procedure TAuthorizationTests.Setup;
begin
  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Database := ':memory:';
  FConnection.Connected := True;
  
  FAuthManager := TAuthorizationManager.Create(FConnection);
end;

procedure TAuthorizationTests.TearDown;
begin
  FAuthManager.Free;
  FConnection.Free;
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
  Assert.AreEqual(1, Length(Roles));
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
  Assert.AreEqual(0, Length(Roles));
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
begin
  FAuthManager.CreateUser('testuser', 'Test User');
  FAuthManager.SetCurrentUser('testuser');
  
  Assert.WillRaise(
    procedure
    begin
      FAuthManager.RequirePermission('users.manage');
    end,
    EPermissionDeniedException
  );
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

initialization
  TDUnitX.RegisterTestFixture(TAuthorizationTests);

end.
