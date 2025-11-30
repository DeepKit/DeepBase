{ ============================================================================
  UniBase.Authorization - Role-Based Access Control (RBAC)
  
  Version: 0.3
  Description: Provides role-based access control with users, roles, permissions,
               and audit logging. Supports hierarchical roles and permission inheritance.
  
  Thread Safety: TAuthorizationManager is thread-safe for read operations.
                 Write operations (user/role management) should be synchronized.
  
  Usage:
    // Setup
    AuthManager.CreateUser('admin', 'Admin User');
    AuthManager.CreateRole('administrators', 'Full access role');
    AuthManager.GrantPermission('administrators', 'users.manage');
    AuthManager.AssignRole('admin', 'administrators');
    
    // Check permissions
    if AuthManager.HasPermission('admin', 'users.manage') then
      // Allow action
    
    // Using current user context
    AuthManager.SetCurrentUser('admin');
    if AuthManager.CurrentUserCan('users.manage') then
      // Allow action
    
    // Require permission (raises exception if denied)
    AuthManager.RequirePermission('users.delete');
  ============================================================================ }

unit UniBase.Authorization;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.DateUtils,
  FireDAC.Comp.Client;

type
  // Forward declarations
  TAuthorizationManager = class;
  TUser = class;
  TRole = class;
  
  // ============================================================================
  // Permission Types
  // ============================================================================
  
  /// <summary>
  /// Permission action types
  /// </summary>
  TPermissionAction = (paRead, paWrite, paCreate, paDelete, paExecute, paManage, paAll);
  TPermissionActions = set of TPermissionAction;
  
  /// <summary>
  /// Permission definition
  /// </summary>
  TPermission = class
  private
    FName: string;           // e.g., 'users.manage', 'reports.view'
    FDisplayName: string;
    FDescription: string;
    FResource: string;       // e.g., 'users', 'reports'
    FActions: TPermissionActions;
  public
    constructor Create(const AName: string);
    
    property Name: string read FName;
    property DisplayName: string read FDisplayName write FDisplayName;
    property Description: string read FDescription write FDescription;
    property Resource: string read FResource write FResource;
    property Actions: TPermissionActions read FActions write FActions;
  end;
  
  // ============================================================================
  // Role Types
  // ============================================================================
  
  /// <summary>
  /// Role definition with permissions
  /// </summary>
  TRole = class
  private
    FId: Integer;
    FName: string;
    FDisplayName: string;
    FDescription: string;
    FPermissions: TList<string>;  // Permission names
    FParentRole: string;          // For hierarchical roles
    FIsActive: Boolean;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    
    procedure AddPermission(const PermissionName: string);
    procedure RemovePermission(const PermissionName: string);
    function HasPermission(const PermissionName: string): Boolean;
    
    property Id: Integer read FId write FId;
    property Name: string read FName;
    property DisplayName: string read FDisplayName write FDisplayName;
    property Description: string read FDescription write FDescription;
    property Permissions: TList<string> read FPermissions;
    property ParentRole: string read FParentRole write FParentRole;
    property IsActive: Boolean read FIsActive write FIsActive;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;
  
  // ============================================================================
  // User Types
  // ============================================================================
  
  /// <summary>
  /// User with roles
  /// </summary>
  TUser = class
  private
    FId: Integer;
    FUsername: string;
    FDisplayName: string;
    FEmail: string;
    FRoles: TList<string>;  // Role names
    FIsActive: Boolean;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
    FLastLoginAt: TDateTime;
    FMetadata: TDictionary<string, string>;
  public
    constructor Create(const AUsername: string);
    destructor Destroy; override;
    
    procedure AddRole(const RoleName: string);
    procedure RemoveRole(const RoleName: string);
    function HasRole(const RoleName: string): Boolean;
    
    function GetMetadata(const Key: string; const Default: string = ''): string;
    procedure SetMetadata(const Key, Value: string);
    
    property Id: Integer read FId write FId;
    property Username: string read FUsername;
    property DisplayName: string read FDisplayName write FDisplayName;
    property Email: string read FEmail write FEmail;
    property Roles: TList<string> read FRoles;
    property IsActive: Boolean read FIsActive write FIsActive;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
    property LastLoginAt: TDateTime read FLastLoginAt write FLastLoginAt;
    property Metadata: TDictionary<string, string> read FMetadata;
  end;
  
  // ============================================================================
  // Audit Types
  // ============================================================================
  
  /// <summary>
  /// Audit log entry type
  /// </summary>
  TAuditAction = (
    aaLogin, aaLogout, aaLoginFailed,
    aaPermissionGranted, aaPermissionDenied, aaPermissionRevoked,
    aaRoleAssigned, aaRoleRevoked,
    aaUserCreated, aaUserUpdated, aaUserDeleted,
    aaRoleCreated, aaRoleUpdated, aaRoleDeleted,
    aaResourceAccessed, aaResourceModified
  );
  
  /// <summary>
  /// Audit log entry
  /// </summary>
  TAuditLogEntry = record
    Id: Int64;
    Timestamp: TDateTime;
    Username: string;
    Action: TAuditAction;
    Resource: string;
    Details: string;
    IPAddress: string;
    Success: Boolean;
    
    class function Create(const AUsername: string; AAction: TAuditAction;
      const AResource, ADetails: string; ASuccess: Boolean): TAuditLogEntry; static;
  end;
  
  /// <summary>
  /// Audit log callback
  /// </summary>
  TAuditLogCallback = reference to procedure(const Entry: TAuditLogEntry);
  
  // ============================================================================
  // Authorization Manager
  // ============================================================================
  
  /// <summary>
  /// Main authorization manager
  /// </summary>
  TAuthorizationManager = class
  private
    FConnection: TFDConnection;
    FUsers: TObjectDictionary<string, TUser>;
    FRoles: TObjectDictionary<string, TRole>;
    FPermissions: TObjectDictionary<string, TPermission>;
    FCurrentUser: TUser;
    FLock: TCriticalSection;
    FOnAuditLog: TAuditLogCallback;
    FAuditEnabled: Boolean;
    
    procedure EnsureTablesExist;
    procedure LoadFromDatabase;
    procedure SaveUserToDatabase(User: TUser);
    procedure SaveRoleToDatabase(Role: TRole);
    procedure DeleteUserFromDatabase(const Username: string);
    procedure DeleteRoleFromDatabase(const RoleName: string);
    procedure LogAudit(const Username: string; Action: TAuditAction;
      const Resource, Details: string; Success: Boolean);
    function GetEffectivePermissions(User: TUser): TList<string>;
    function GetRolePermissionsRecursive(const RoleName: string; 
      Visited: TList<string>): TList<string>;
  public
    constructor Create(AConnection: TFDConnection);
    destructor Destroy; override;
    
    // ========================================================================
    // User Management
    // ========================================================================
    
    /// <summary>Create a new user</summary>
    function CreateUser(const Username, DisplayName: string): TUser;
    
    /// <summary>Get user by username</summary>
    function GetUser(const Username: string): TUser;
    
    /// <summary>Update user</summary>
    procedure UpdateUser(User: TUser);
    
    /// <summary>Delete user</summary>
    procedure DeleteUser(const Username: string);
    
    /// <summary>Check if user exists</summary>
    function UserExists(const Username: string): Boolean;
    
    /// <summary>Get all users</summary>
    function GetAllUsers: TArray<TUser>;
    
    // ========================================================================
    // Role Management
    // ========================================================================
    
    /// <summary>Create a new role</summary>
    function CreateRole(const RoleName, DisplayName: string): TRole;
    
    /// <summary>Get role by name</summary>
    function GetRole(const RoleName: string): TRole;
    
    /// <summary>Update role</summary>
    procedure UpdateRole(Role: TRole);
    
    /// <summary>Delete role</summary>
    procedure DeleteRole(const RoleName: string);
    
    /// <summary>Check if role exists</summary>
    function RoleExists(const RoleName: string): Boolean;
    
    /// <summary>Get all roles</summary>
    function GetAllRoles: TArray<TRole>;
    
    // ========================================================================
    // Permission Management
    // ========================================================================
    
    /// <summary>Register a permission</summary>
    procedure RegisterPermission(const Name, DisplayName, Description: string);
    
    /// <summary>Grant permission to role</summary>
    procedure GrantPermission(const RoleName, PermissionName: string);
    
    /// <summary>Revoke permission from role</summary>
    procedure RevokePermission(const RoleName, PermissionName: string);
    
    /// <summary>Get all registered permissions</summary>
    function GetAllPermissions: TArray<TPermission>;
    
    // ========================================================================
    // Role Assignment
    // ========================================================================
    
    /// <summary>Assign role to user</summary>
    procedure AssignRole(const Username, RoleName: string);
    
    /// <summary>Remove role from user</summary>
    procedure RemoveRole(const Username, RoleName: string);
    
    /// <summary>Get user's roles</summary>
    function GetUserRoles(const Username: string): TArray<string>;
    
    // ========================================================================
    // Permission Checking
    // ========================================================================
    
    /// <summary>Check if user has permission</summary>
    function HasPermission(const Username, PermissionName: string): Boolean;
    
    /// <summary>Check if user has any of the permissions</summary>
    function HasAnyPermission(const Username: string; 
      const Permissions: array of string): Boolean;
    
    /// <summary>Check if user has all of the permissions</summary>
    function HasAllPermissions(const Username: string; 
      const Permissions: array of string): Boolean;
    
    /// <summary>Check if user has role</summary>
    function UserHasRole(const Username, RoleName: string): Boolean;
    
    /// <summary>Get all effective permissions for user</summary>
    function GetUserPermissions(const Username: string): TArray<string>;
    
    // ========================================================================
    // Current User Context
    // ========================================================================
    
    /// <summary>Set current user context</summary>
    procedure SetCurrentUser(const Username: string);
    
    /// <summary>Clear current user context</summary>
    procedure ClearCurrentUser;
    
    /// <summary>Check if current user has permission</summary>
    function CurrentUserCan(const PermissionName: string): Boolean;
    
    /// <summary>Require permission (raises exception if denied)</summary>
    procedure RequirePermission(const PermissionName: string);
    
    /// <summary>Require any of the permissions</summary>
    procedure RequireAnyPermission(const Permissions: array of string);
    
    /// <summary>Require all permissions</summary>
    procedure RequireAllPermissions(const Permissions: array of string);
    
    // ========================================================================
    // Audit
    // ========================================================================
    
    /// <summary>Get audit log entries</summary>
    function GetAuditLog(const Username: string = ''; 
      StartDate: TDateTime = 0; EndDate: TDateTime = 0;
      MaxEntries: Integer = 100): TArray<TAuditLogEntry>;
    
    /// <summary>Clear old audit entries</summary>
    procedure ClearAuditLog(DaysToKeep: Integer = 90);
    
    // ========================================================================
    // Properties
    // ========================================================================
    
    property CurrentUser: TUser read FCurrentUser;
    property AuditEnabled: Boolean read FAuditEnabled write FAuditEnabled;
    property OnAuditLog: TAuditLogCallback read FOnAuditLog write FOnAuditLog;
  end;
  
  // ============================================================================
  // Exceptions
  // ============================================================================
  
  EAuthorizationException = class(Exception);
  EPermissionDeniedException = class(EAuthorizationException);
  EUserNotFoundException = class(EAuthorizationException);
  ERoleNotFoundException = class(EAuthorizationException);

  // ============================================================================
  // Global Functions
  // ============================================================================

/// <summary>Get global authorization manager</summary>
function AuthManager: TAuthorizationManager;

/// <summary>Set global authorization manager</summary>
procedure SetAuthManager(Manager: TAuthorizationManager);

/// <summary>Permission check attribute helper</summary>
function RequirePermissions(const Permissions: array of string): Boolean;

implementation

var
  FAuthManager: TAuthorizationManager = nil;
  FAuthManagerLock: TCriticalSection = nil;

function AuthManager: TAuthorizationManager;
begin
  Result := FAuthManager;
  if Result = nil then
    raise EAuthorizationException.Create('Authorization manager not initialized');
end;

procedure SetAuthManager(Manager: TAuthorizationManager);
begin
  FAuthManagerLock.Enter;
  try
    if (FAuthManager <> nil) and (FAuthManager <> Manager) then
      FAuthManager.Free;
    FAuthManager := Manager;
  finally
    FAuthManagerLock.Leave;
  end;
end;

function RequirePermissions(const Permissions: array of string): Boolean;
begin
  Result := AuthManager.HasAllPermissions(
    AuthManager.CurrentUser.Username, Permissions);
end;

// ============================================================================
// TPermission
// ============================================================================

constructor TPermission.Create(const AName: string);
var
  DotPos: Integer;
begin
  inherited Create;
  FName := AName;
  FDisplayName := AName;
  FDescription := '';
  FActions := [];
  
  // Extract resource from name (e.g., 'users.manage' -> 'users')
  DotPos := Pos('.', AName);
  if DotPos > 0 then
    FResource := Copy(AName, 1, DotPos - 1)
  else
    FResource := AName;
end;

// ============================================================================
// TRole
// ============================================================================

constructor TRole.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FDisplayName := AName;
  FDescription := '';
  FPermissions := TList<string>.Create;
  FParentRole := '';
  FIsActive := True;
  FCreatedAt := Now;
  FUpdatedAt := Now;
end;

destructor TRole.Destroy;
begin
  FPermissions.Free;
  inherited;
end;

procedure TRole.AddPermission(const PermissionName: string);
begin
  if not FPermissions.Contains(PermissionName) then
  begin
    FPermissions.Add(PermissionName);
    FUpdatedAt := Now;
  end;
end;

procedure TRole.RemovePermission(const PermissionName: string);
begin
  if FPermissions.Remove(PermissionName) >= 0 then
    FUpdatedAt := Now;
end;

function TRole.HasPermission(const PermissionName: string): Boolean;
begin
  Result := FPermissions.Contains(PermissionName);
end;

// ============================================================================
// TUser
// ============================================================================

constructor TUser.Create(const AUsername: string);
begin
  inherited Create;
  FUsername := AUsername;
  FDisplayName := AUsername;
  FEmail := '';
  FRoles := TList<string>.Create;
  FIsActive := True;
  FCreatedAt := Now;
  FUpdatedAt := Now;
  FLastLoginAt := 0;
  FMetadata := TDictionary<string, string>.Create;
end;

destructor TUser.Destroy;
begin
  FMetadata.Free;
  FRoles.Free;
  inherited;
end;

procedure TUser.AddRole(const RoleName: string);
begin
  if not FRoles.Contains(RoleName) then
  begin
    FRoles.Add(RoleName);
    FUpdatedAt := Now;
  end;
end;

procedure TUser.RemoveRole(const RoleName: string);
begin
  if FRoles.Remove(RoleName) >= 0 then
    FUpdatedAt := Now;
end;

function TUser.HasRole(const RoleName: string): Boolean;
begin
  Result := FRoles.Contains(RoleName);
end;

function TUser.GetMetadata(const Key: string; const Default: string): string;
begin
  if not FMetadata.TryGetValue(Key, Result) then
    Result := Default;
end;

procedure TUser.SetMetadata(const Key, Value: string);
begin
  FMetadata.AddOrSetValue(Key, Value);
  FUpdatedAt := Now;
end;

// ============================================================================
// TAuditLogEntry
// ============================================================================

class function TAuditLogEntry.Create(const AUsername: string; AAction: TAuditAction;
  const AResource, ADetails: string; ASuccess: Boolean): TAuditLogEntry;
begin
  Result.Id := 0;
  Result.Timestamp := Now;
  Result.Username := AUsername;
  Result.Action := AAction;
  Result.Resource := AResource;
  Result.Details := ADetails;
  Result.IPAddress := '';
  Result.Success := ASuccess;
end;

// ============================================================================
// TAuthorizationManager
// ============================================================================

constructor TAuthorizationManager.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
  FUsers := TObjectDictionary<string, TUser>.Create([doOwnsValues]);
  FRoles := TObjectDictionary<string, TRole>.Create([doOwnsValues]);
  FPermissions := TObjectDictionary<string, TPermission>.Create([doOwnsValues]);
  FCurrentUser := nil;
  FLock := TCriticalSection.Create;
  FAuditEnabled := True;
  
  EnsureTablesExist;
  LoadFromDatabase;
end;

destructor TAuthorizationManager.Destroy;
begin
  FLock.Enter;
  try
    FPermissions.Free;
    FRoles.Free;
    FUsers.Free;
  finally
    FLock.Leave;
  end;
  FLock.Free;
  inherited;
end;

procedure TAuthorizationManager.EnsureTablesExist;
const
  CREATE_USERS_TABLE = 
    'CREATE TABLE IF NOT EXISTS auth_users (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  username VARCHAR(100) NOT NULL UNIQUE,' +
    '  display_name VARCHAR(200),' +
    '  email VARCHAR(255),' +
    '  is_active INTEGER DEFAULT 1,' +
    '  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,' +
    '  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,' +
    '  last_login_at DATETIME,' +
    '  metadata TEXT' +
    ')';
    
  CREATE_ROLES_TABLE = 
    'CREATE TABLE IF NOT EXISTS auth_roles (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name VARCHAR(100) NOT NULL UNIQUE,' +
    '  display_name VARCHAR(200),' +
    '  description TEXT,' +
    '  parent_role VARCHAR(100),' +
    '  is_active INTEGER DEFAULT 1,' +
    '  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,' +
    '  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP' +
    ')';
    
  CREATE_ROLE_PERMISSIONS_TABLE = 
    'CREATE TABLE IF NOT EXISTS auth_role_permissions (' +
    '  role_id INTEGER NOT NULL,' +
    '  permission VARCHAR(100) NOT NULL,' +
    '  granted_at DATETIME DEFAULT CURRENT_TIMESTAMP,' +
    '  PRIMARY KEY (role_id, permission),' +
    '  FOREIGN KEY (role_id) REFERENCES auth_roles(id) ON DELETE CASCADE' +
    ')';
    
  CREATE_USER_ROLES_TABLE = 
    'CREATE TABLE IF NOT EXISTS auth_user_roles (' +
    '  user_id INTEGER NOT NULL,' +
    '  role_id INTEGER NOT NULL,' +
    '  assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP,' +
    '  PRIMARY KEY (user_id, role_id),' +
    '  FOREIGN KEY (user_id) REFERENCES auth_users(id) ON DELETE CASCADE,' +
    '  FOREIGN KEY (role_id) REFERENCES auth_roles(id) ON DELETE CASCADE' +
    ')';
    
  CREATE_AUDIT_LOG_TABLE = 
    'CREATE TABLE IF NOT EXISTS auth_audit_log (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,' +
    '  username VARCHAR(100),' +
    '  action VARCHAR(50) NOT NULL,' +
    '  resource VARCHAR(200),' +
    '  details TEXT,' +
    '  ip_address VARCHAR(50),' +
    '  success INTEGER DEFAULT 1' +
    ')';
    
  CREATE_AUDIT_INDEX = 
    'CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON auth_audit_log(timestamp)';
begin
  FConnection.ExecSQL(CREATE_USERS_TABLE);
  FConnection.ExecSQL(CREATE_ROLES_TABLE);
  FConnection.ExecSQL(CREATE_ROLE_PERMISSIONS_TABLE);
  FConnection.ExecSQL(CREATE_USER_ROLES_TABLE);
  FConnection.ExecSQL(CREATE_AUDIT_LOG_TABLE);
  FConnection.ExecSQL(CREATE_AUDIT_INDEX);
end;

procedure TAuthorizationManager.LoadFromDatabase;
var
  Query: TFDQuery;
  User: TUser;
  Role: TRole;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    // Load roles
    Query.SQL.Text := 'SELECT * FROM auth_roles WHERE is_active = 1';
    Query.Open;
    while not Query.Eof do
    begin
      Role := TRole.Create(Query.FieldByName('name').AsString);
      Role.Id := Query.FieldByName('id').AsInteger;
      Role.DisplayName := Query.FieldByName('display_name').AsString;
      Role.Description := Query.FieldByName('description').AsString;
      Role.ParentRole := Query.FieldByName('parent_role').AsString;
      Role.CreatedAt := Query.FieldByName('created_at').AsDateTime;
      Role.UpdatedAt := Query.FieldByName('updated_at').AsDateTime;
      FRoles.Add(Role.Name, Role);
      Query.Next;
    end;
    Query.Close;
    
    // Load role permissions
    Query.SQL.Text := 
      'SELECT r.name as role_name, rp.permission ' +
      'FROM auth_role_permissions rp ' +
      'JOIN auth_roles r ON r.id = rp.role_id';
    Query.Open;
    while not Query.Eof do
    begin
      if FRoles.TryGetValue(Query.FieldByName('role_name').AsString, Role) then
        Role.AddPermission(Query.FieldByName('permission').AsString);
      Query.Next;
    end;
    Query.Close;
    
    // Load users
    Query.SQL.Text := 'SELECT * FROM auth_users WHERE is_active = 1';
    Query.Open;
    while not Query.Eof do
    begin
      User := TUser.Create(Query.FieldByName('username').AsString);
      User.Id := Query.FieldByName('id').AsInteger;
      User.DisplayName := Query.FieldByName('display_name').AsString;
      User.Email := Query.FieldByName('email').AsString;
      User.CreatedAt := Query.FieldByName('created_at').AsDateTime;
      User.UpdatedAt := Query.FieldByName('updated_at').AsDateTime;
      if not Query.FieldByName('last_login_at').IsNull then
        User.LastLoginAt := Query.FieldByName('last_login_at').AsDateTime;
      FUsers.Add(User.Username, User);
      Query.Next;
    end;
    Query.Close;
    
    // Load user roles
    Query.SQL.Text := 
      'SELECT u.username, r.name as role_name ' +
      'FROM auth_user_roles ur ' +
      'JOIN auth_users u ON u.id = ur.user_id ' +
      'JOIN auth_roles r ON r.id = ur.role_id';
    Query.Open;
    while not Query.Eof do
    begin
      if FUsers.TryGetValue(Query.FieldByName('username').AsString, User) then
        User.AddRole(Query.FieldByName('role_name').AsString);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

procedure TAuthorizationManager.SaveUserToDatabase(User: TUser);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    if User.Id = 0 then
    begin
      // Insert new user
      Query.SQL.Text := 
        'INSERT INTO auth_users (username, display_name, email, is_active) ' +
        'VALUES (:username, :display_name, :email, :is_active)';
      Query.ParamByName('username').AsString := User.Username;
      Query.ParamByName('display_name').AsString := User.DisplayName;
      Query.ParamByName('email').AsString := User.Email;
      Query.ParamByName('is_active').AsInteger := Ord(User.IsActive);
      Query.ExecSQL;
      User.Id := FConnection.GetLastAutoGenValue('');
    end
    else
    begin
      // Update existing user
      Query.SQL.Text := 
        'UPDATE auth_users SET display_name = :display_name, email = :email, ' +
        'is_active = :is_active, updated_at = CURRENT_TIMESTAMP ' +
        'WHERE id = :id';
      Query.ParamByName('display_name').AsString := User.DisplayName;
      Query.ParamByName('email').AsString := User.Email;
      Query.ParamByName('is_active').AsInteger := Ord(User.IsActive);
      Query.ParamByName('id').AsInteger := User.Id;
      Query.ExecSQL;
    end;
  finally
    Query.Free;
  end;
end;

procedure TAuthorizationManager.SaveRoleToDatabase(Role: TRole);
var
  Query: TFDQuery;
  Perm: string;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    if Role.Id = 0 then
    begin
      // Insert new role
      Query.SQL.Text := 
        'INSERT INTO auth_roles (name, display_name, description, parent_role, is_active) ' +
        'VALUES (:name, :display_name, :description, :parent_role, :is_active)';
      Query.ParamByName('name').AsString := Role.Name;
      Query.ParamByName('display_name').AsString := Role.DisplayName;
      Query.ParamByName('description').AsString := Role.Description;
      Query.ParamByName('parent_role').AsString := Role.ParentRole;
      Query.ParamByName('is_active').AsInteger := Ord(Role.IsActive);
      Query.ExecSQL;
      Role.Id := FConnection.GetLastAutoGenValue('');
    end
    else
    begin
      // Update existing role
      Query.SQL.Text := 
        'UPDATE auth_roles SET display_name = :display_name, description = :description, ' +
        'parent_role = :parent_role, is_active = :is_active, updated_at = CURRENT_TIMESTAMP ' +
        'WHERE id = :id';
      Query.ParamByName('display_name').AsString := Role.DisplayName;
      Query.ParamByName('description').AsString := Role.Description;
      Query.ParamByName('parent_role').AsString := Role.ParentRole;
      Query.ParamByName('is_active').AsInteger := Ord(Role.IsActive);
      Query.ParamByName('id').AsInteger := Role.Id;
      Query.ExecSQL;
    end;
    
    // Update permissions
    Query.SQL.Text := 'DELETE FROM auth_role_permissions WHERE role_id = :role_id';
    Query.ParamByName('role_id').AsInteger := Role.Id;
    Query.ExecSQL;
    
    for Perm in Role.Permissions do
    begin
      Query.SQL.Text := 
        'INSERT INTO auth_role_permissions (role_id, permission) VALUES (:role_id, :permission)';
      Query.ParamByName('role_id').AsInteger := Role.Id;
      Query.ParamByName('permission').AsString := Perm;
      Query.ExecSQL;
    end;
  finally
    Query.Free;
  end;
end;

procedure TAuthorizationManager.DeleteUserFromDatabase(const Username: string);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM auth_users WHERE username = :username';
    Query.ParamByName('username').AsString := Username;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TAuthorizationManager.DeleteRoleFromDatabase(const RoleName: string);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM auth_roles WHERE name = :name';
    Query.ParamByName('name').AsString := RoleName;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TAuthorizationManager.LogAudit(const Username: string; Action: TAuditAction;
  const Resource, Details: string; Success: Boolean);
const
  ACTION_NAMES: array[TAuditAction] of string = (
    'LOGIN', 'LOGOUT', 'LOGIN_FAILED',
    'PERMISSION_GRANTED', 'PERMISSION_DENIED', 'PERMISSION_REVOKED',
    'ROLE_ASSIGNED', 'ROLE_REVOKED',
    'USER_CREATED', 'USER_UPDATED', 'USER_DELETED',
    'ROLE_CREATED', 'ROLE_UPDATED', 'ROLE_DELETED',
    'RESOURCE_ACCESSED', 'RESOURCE_MODIFIED'
  );
var
  Query: TFDQuery;
  Entry: TAuditLogEntry;
begin
  if not FAuditEnabled then
    Exit;
  
  Entry := TAuditLogEntry.Create(Username, Action, Resource, Details, Success);
  
  // Call callback if set
  if Assigned(FOnAuditLog) then
    FOnAuditLog(Entry);
  
  // Save to database
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'INSERT INTO auth_audit_log (username, action, resource, details, success) ' +
      'VALUES (:username, :action, :resource, :details, :success)';
    Query.ParamByName('username').AsString := Username;
    Query.ParamByName('action').AsString := ACTION_NAMES[Action];
    Query.ParamByName('resource').AsString := Resource;
    Query.ParamByName('details').AsString := Details;
    Query.ParamByName('success').AsInteger := Ord(Success);
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TAuthorizationManager.GetEffectivePermissions(User: TUser): TList<string>;
var
  RoleName: string;
  RolePerms: TList<string>;
  Perm: string;
  Visited: TList<string>;
begin
  Result := TList<string>.Create;
  Visited := TList<string>.Create;
  try
    for RoleName in User.Roles do
    begin
      RolePerms := GetRolePermissionsRecursive(RoleName, Visited);
      try
        for Perm in RolePerms do
          if not Result.Contains(Perm) then
            Result.Add(Perm);
      finally
        RolePerms.Free;
      end;
    end;
  finally
    Visited.Free;
  end;
end;

function TAuthorizationManager.GetRolePermissionsRecursive(const RoleName: string;
  Visited: TList<string>): TList<string>;
var
  Role: TRole;
  Perm: string;
  ParentPerms: TList<string>;
begin
  Result := TList<string>.Create;
  
  if Visited.Contains(RoleName) then
    Exit; // Prevent circular references
    
  Visited.Add(RoleName);
  
  if not FRoles.TryGetValue(RoleName, Role) then
    Exit;
  
  // Add direct permissions
  for Perm in Role.Permissions do
    if not Result.Contains(Perm) then
      Result.Add(Perm);
  
  // Add inherited permissions from parent
  if Role.ParentRole <> '' then
  begin
    ParentPerms := GetRolePermissionsRecursive(Role.ParentRole, Visited);
    try
      for Perm in ParentPerms do
        if not Result.Contains(Perm) then
          Result.Add(Perm);
    finally
      ParentPerms.Free;
    end;
  end;
end;

// ============================================================================
// User Management
// ============================================================================

function TAuthorizationManager.CreateUser(const Username, DisplayName: string): TUser;
begin
  FLock.Enter;
  try
    if FUsers.ContainsKey(Username) then
      raise EAuthorizationException.CreateFmt('User already exists: %s', [Username]);
    
    Result := TUser.Create(Username);
    Result.DisplayName := DisplayName;
    SaveUserToDatabase(Result);
    FUsers.Add(Username, Result);
    
    LogAudit(Username, aaUserCreated, 'user', 
      Format('Created user: %s', [Username]), True);
  finally
    FLock.Leave;
  end;
end;

function TAuthorizationManager.GetUser(const Username: string): TUser;
begin
  FLock.Enter;
  try
    if not FUsers.TryGetValue(Username, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

procedure TAuthorizationManager.UpdateUser(User: TUser);
begin
  FLock.Enter;
  try
    SaveUserToDatabase(User);
    LogAudit(User.Username, aaUserUpdated, 'user',
      Format('Updated user: %s', [User.Username]), True);
  finally
    FLock.Leave;
  end;
end;

procedure TAuthorizationManager.DeleteUser(const Username: string);
begin
  FLock.Enter;
  try
    if not FUsers.ContainsKey(Username) then
      raise EUserNotFoundException.CreateFmt('User not found: %s', [Username]);
    
    DeleteUserFromDatabase(Username);
    FUsers.Remove(Username);
    
    LogAudit(Username, aaUserDeleted, 'user',
      Format('Deleted user: %s', [Username]), True);
  finally
    FLock.Leave;
  end;
end;

function TAuthorizationManager.UserExists(const Username: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FUsers.ContainsKey(Username);
  finally
    FLock.Leave;
  end;
end;

function TAuthorizationManager.GetAllUsers: TArray<TUser>;
var
  List: TList<TUser>;
  User: TUser;
begin
  FLock.Enter;
  try
    List := TList<TUser>.Create;
    try
      for User in FUsers.Values do
        List.Add(User);
      Result := List.ToArray;
    finally
      List.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// Role Management
// ============================================================================

function TAuthorizationManager.CreateRole(const RoleName, DisplayName: string): TRole;
begin
  FLock.Enter;
  try
    if FRoles.ContainsKey(RoleName) then
      raise EAuthorizationException.CreateFmt('Role already exists: %s', [RoleName]);
    
    Result := TRole.Create(RoleName);
    Result.DisplayName := DisplayName;
    SaveRoleToDatabase(Result);
    FRoles.Add(RoleName, Result);
    
    LogAudit('', aaRoleCreated, 'role',
      Format('Created role: %s', [RoleName]), True);
  finally
    FLock.Leave;
  end;
end;

function TAuthorizationManager.GetRole(const RoleName: string): TRole;
begin
  FLock.Enter;
  try
    if not FRoles.TryGetValue(RoleName, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

procedure TAuthorizationManager.UpdateRole(Role: TRole);
begin
  FLock.Enter;
  try
    SaveRoleToDatabase(Role);
    LogAudit('', aaRoleUpdated, 'role',
      Format('Updated role: %s', [Role.Name]), True);
  finally
    FLock.Leave;
  end;
end;

procedure TAuthorizationManager.DeleteRole(const RoleName: string);
begin
  FLock.Enter;
  try
    if not FRoles.ContainsKey(RoleName) then
      raise ERoleNotFoundException.CreateFmt('Role not found: %s', [RoleName]);
    
    DeleteRoleFromDatabase(RoleName);
    FRoles.Remove(RoleName);
    
    LogAudit('', aaRoleDeleted, 'role',
      Format('Deleted role: %s', [RoleName]), True);
  finally
    FLock.Leave;
  end;
end;

function TAuthorizationManager.RoleExists(const RoleName: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FRoles.ContainsKey(RoleName);
  finally
    FLock.Leave;
  end;
end;

function TAuthorizationManager.GetAllRoles: TArray<TRole>;
var
  List: TList<TRole>;
  Role: TRole;
begin
  FLock.Enter;
  try
    List := TList<TRole>.Create;
    try
      for Role in FRoles.Values do
        List.Add(Role);
      Result := List.ToArray;
    finally
      List.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// Permission Management
// ============================================================================

procedure TAuthorizationManager.RegisterPermission(const Name, DisplayName, 
  Description: string);
var
  Perm: TPermission;
begin
  FLock.Enter;
  try
    if not FPermissions.ContainsKey(Name) then
    begin
      Perm := TPermission.Create(Name);
      Perm.DisplayName := DisplayName;
      Perm.Description := Description;
      FPermissions.Add(Name, Perm);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TAuthorizationManager.GrantPermission(const RoleName, PermissionName: string);
var
  Role: TRole;
begin
  FLock.Enter;
  try
    if not FRoles.TryGetValue(RoleName, Role) then
      raise ERoleNotFoundException.CreateFmt('Role not found: %s', [RoleName]);
    
    Role.AddPermission(PermissionName);
    SaveRoleToDatabase(Role);
    
    LogAudit('', aaPermissionGranted, PermissionName,
      Format('Granted %s to role %s', [PermissionName, RoleName]), True);
  finally
    FLock.Leave;
  end;
end;

procedure TAuthorizationManager.RevokePermission(const RoleName, PermissionName: string);
var
  Role: TRole;
begin
  FLock.Enter;
  try
    if not FRoles.TryGetValue(RoleName, Role) then
      raise ERoleNotFoundException.CreateFmt('Role not found: %s', [RoleName]);
    
    Role.RemovePermission(PermissionName);
    SaveRoleToDatabase(Role);
    
    LogAudit('', aaPermissionRevoked, PermissionName,
      Format('Revoked %s from role %s', [PermissionName, RoleName]), True);
  finally
    FLock.Leave;
  end;
end;

function TAuthorizationManager.GetAllPermissions: TArray<TPermission>;
var
  List: TList<TPermission>;
  Perm: TPermission;
begin
  FLock.Enter;
  try
    List := TList<TPermission>.Create;
    try
      for Perm in FPermissions.Values do
        List.Add(Perm);
      Result := List.ToArray;
    finally
      List.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// Role Assignment
// ============================================================================

procedure TAuthorizationManager.AssignRole(const Username, RoleName: string);
var
  User: TUser;
  Role: TRole;
  Query: TFDQuery;
begin
  FLock.Enter;
  try
    if not FUsers.TryGetValue(Username, User) then
      raise EUserNotFoundException.CreateFmt('User not found: %s', [Username]);
    
    if not FRoles.TryGetValue(RoleName, Role) then
      raise ERoleNotFoundException.CreateFmt('Role not found: %s', [RoleName]);
    
    if not User.HasRole(RoleName) then
    begin
      User.AddRole(RoleName);
      
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := FConnection;
        Query.SQL.Text := 
          'INSERT OR IGNORE INTO auth_user_roles (user_id, role_id) ' +
          'VALUES (:user_id, :role_id)';
        Query.ParamByName('user_id').AsInteger := User.Id;
        Query.ParamByName('role_id').AsInteger := Role.Id;
        Query.ExecSQL;
      finally
        Query.Free;
      end;
      
      LogAudit(Username, aaRoleAssigned, RoleName,
        Format('Assigned role %s to user %s', [RoleName, Username]), True);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TAuthorizationManager.RemoveRole(const Username, RoleName: string);
var
  User: TUser;
  Role: TRole;
  Query: TFDQuery;
begin
  FLock.Enter;
  try
    if not FUsers.TryGetValue(Username, User) then
      raise EUserNotFoundException.CreateFmt('User not found: %s', [Username]);
    
    if not FRoles.TryGetValue(RoleName, Role) then
      raise ERoleNotFoundException.CreateFmt('Role not found: %s', [RoleName]);
    
    User.RemoveRole(RoleName);
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 
        'DELETE FROM auth_user_roles WHERE user_id = :user_id AND role_id = :role_id';
      Query.ParamByName('user_id').AsInteger := User.Id;
      Query.ParamByName('role_id').AsInteger := Role.Id;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
    
    LogAudit(Username, aaRoleRevoked, RoleName,
      Format('Removed role %s from user %s', [RoleName, Username]), True);
  finally
    FLock.Leave;
  end;
end;

function TAuthorizationManager.GetUserRoles(const Username: string): TArray<string>;
var
  User: TUser;
begin
  FLock.Enter;
  try
    if not FUsers.TryGetValue(Username, User) then
      raise EUserNotFoundException.CreateFmt('User not found: %s', [Username]);
    
    Result := User.Roles.ToArray;
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// Permission Checking
// ============================================================================

function TAuthorizationManager.HasPermission(const Username, PermissionName: string): Boolean;
var
  User: TUser;
  Permissions: TList<string>;
begin
  FLock.Enter;
  try
    if not FUsers.TryGetValue(Username, User) then
    begin
      Result := False;
      Exit;
    end;
    
    Permissions := GetEffectivePermissions(User);
    try
      // Check for exact match or wildcard
      Result := Permissions.Contains(PermissionName) or
                Permissions.Contains('*') or
                Permissions.Contains(User.GetMetadata('resource', '') + '.*');
    finally
      Permissions.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function TAuthorizationManager.HasAnyPermission(const Username: string;
  const Permissions: array of string): Boolean;
var
  Perm: string;
begin
  for Perm in Permissions do
    if HasPermission(Username, Perm) then
      Exit(True);
  Result := False;
end;

function TAuthorizationManager.HasAllPermissions(const Username: string;
  const Permissions: array of string): Boolean;
var
  Perm: string;
begin
  for Perm in Permissions do
    if not HasPermission(Username, Perm) then
      Exit(False);
  Result := True;
end;

function TAuthorizationManager.UserHasRole(const Username, RoleName: string): Boolean;
var
  User: TUser;
begin
  FLock.Enter;
  try
    if not FUsers.TryGetValue(Username, User) then
      Exit(False);
    Result := User.HasRole(RoleName);
  finally
    FLock.Leave;
  end;
end;

function TAuthorizationManager.GetUserPermissions(const Username: string): TArray<string>;
var
  User: TUser;
  Permissions: TList<string>;
begin
  FLock.Enter;
  try
    if not FUsers.TryGetValue(Username, User) then
      Exit(nil);
    
    Permissions := GetEffectivePermissions(User);
    try
      Result := Permissions.ToArray;
    finally
      Permissions.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// Current User Context
// ============================================================================

procedure TAuthorizationManager.SetCurrentUser(const Username: string);
begin
  FLock.Enter;
  try
    if not FUsers.TryGetValue(Username, FCurrentUser) then
      raise EUserNotFoundException.CreateFmt('User not found: %s', [Username]);
    
    // Update last login
    FCurrentUser.LastLoginAt := Now;
    
    LogAudit(Username, aaLogin, 'session', 'User logged in', True);
  finally
    FLock.Leave;
  end;
end;

procedure TAuthorizationManager.ClearCurrentUser;
var
  Username: string;
begin
  FLock.Enter;
  try
    if FCurrentUser <> nil then
    begin
      Username := FCurrentUser.Username;
      FCurrentUser := nil;
      LogAudit(Username, aaLogout, 'session', 'User logged out', True);
    end;
  finally
    FLock.Leave;
  end;
end;

function TAuthorizationManager.CurrentUserCan(const PermissionName: string): Boolean;
begin
  if FCurrentUser = nil then
    Exit(False);
  Result := HasPermission(FCurrentUser.Username, PermissionName);
end;

procedure TAuthorizationManager.RequirePermission(const PermissionName: string);
var
  Username: string;
begin
  if FCurrentUser = nil then
  begin
    LogAudit('', aaPermissionDenied, PermissionName, 'No user context', False);
    raise EPermissionDeniedException.Create('No user context');
  end;
  
  Username := FCurrentUser.Username;
  if not HasPermission(Username, PermissionName) then
  begin
    LogAudit(Username, aaPermissionDenied, PermissionName,
      Format('Permission denied: %s', [PermissionName]), False);
    raise EPermissionDeniedException.CreateFmt(
      'Permission denied: %s for user %s', [PermissionName, Username]);
  end;
end;

procedure TAuthorizationManager.RequireAnyPermission(const Permissions: array of string);
var
  Username: string;
begin
  if FCurrentUser = nil then
    raise EPermissionDeniedException.Create('No user context');
  
  Username := FCurrentUser.Username;
  if not HasAnyPermission(Username, Permissions) then
  begin
    LogAudit(Username, aaPermissionDenied, string.Join(',', Permissions),
      'Permission denied: none of required permissions', False);
    raise EPermissionDeniedException.Create('Permission denied');
  end;
end;

procedure TAuthorizationManager.RequireAllPermissions(const Permissions: array of string);
var
  Username: string;
begin
  if FCurrentUser = nil then
    raise EPermissionDeniedException.Create('No user context');
  
  Username := FCurrentUser.Username;
  if not HasAllPermissions(Username, Permissions) then
  begin
    LogAudit(Username, aaPermissionDenied, string.Join(',', Permissions),
      'Permission denied: missing required permissions', False);
    raise EPermissionDeniedException.Create('Permission denied');
  end;
end;

// ============================================================================
// Audit
// ============================================================================

function TAuthorizationManager.GetAuditLog(const Username: string;
  StartDate, EndDate: TDateTime; MaxEntries: Integer): TArray<TAuditLogEntry>;
const
  ACTION_MAP: array[0..15] of TAuditAction = (
    aaLogin, aaLogout, aaLoginFailed,
    aaPermissionGranted, aaPermissionDenied, aaPermissionRevoked,
    aaRoleAssigned, aaRoleRevoked,
    aaUserCreated, aaUserUpdated, aaUserDeleted,
    aaRoleCreated, aaRoleUpdated, aaRoleDeleted,
    aaResourceAccessed, aaResourceModified
  );
var
  Query: TFDQuery;
  List: TList<TAuditLogEntry>;
  Entry: TAuditLogEntry;
  SQL: string;
begin
  List := TList<TAuditLogEntry>.Create;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      
      SQL := 'SELECT * FROM auth_audit_log WHERE 1=1';
      if Username <> '' then
        SQL := SQL + ' AND username = :username';
      if StartDate > 0 then
        SQL := SQL + ' AND timestamp >= :start_date';
      if EndDate > 0 then
        SQL := SQL + ' AND timestamp <= :end_date';
      SQL := SQL + ' ORDER BY timestamp DESC LIMIT :max_entries';
      
      Query.SQL.Text := SQL;
      if Username <> '' then
        Query.ParamByName('username').AsString := Username;
      if StartDate > 0 then
        Query.ParamByName('start_date').AsDateTime := StartDate;
      if EndDate > 0 then
        Query.ParamByName('end_date').AsDateTime := EndDate;
      Query.ParamByName('max_entries').AsInteger := MaxEntries;
      
      Query.Open;
      while not Query.Eof do
      begin
        Entry.Id := Query.FieldByName('id').AsLargeInt;
        Entry.Timestamp := Query.FieldByName('timestamp').AsDateTime;
        Entry.Username := Query.FieldByName('username').AsString;
        Entry.Resource := Query.FieldByName('resource').AsString;
        Entry.Details := Query.FieldByName('details').AsString;
        Entry.IPAddress := Query.FieldByName('ip_address').AsString;
        Entry.Success := Query.FieldByName('success').AsInteger = 1;
        // Note: Action mapping would need proper implementation
        Entry.Action := aaResourceAccessed;
        List.Add(Entry);
        Query.Next;
      end;
    finally
      Query.Free;
    end;
    
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TAuthorizationManager.ClearAuditLog(DaysToKeep: Integer);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'DELETE FROM auth_audit_log WHERE timestamp < :cutoff_date';
    Query.ParamByName('cutoff_date').AsDateTime := IncDay(Now, -DaysToKeep);
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

initialization
  FAuthManagerLock := TCriticalSection.Create;

finalization
  if FAuthManager <> nil then
    FreeAndNil(FAuthManager);
  FreeAndNil(FAuthManagerLock);

end.
