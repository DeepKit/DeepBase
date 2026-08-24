{ ============================================================================
  DeepBase.Persistence.Authorization.FireDAC - FireDAC adapter for Authorization
  ============================================================================
  Moves Authorization SQL/FireDAC persistence out of Core\DeepBase.Authorization.
  ============================================================================
}

unit DeepBase.Persistence.Authorization.FireDAC;

interface

uses
  DeepBase.Authorization,
  FireDAC.Comp.Client;

function CreateAuthorizationStorage(
  AConnection: TFDConnection): IAuthorizationStorage;
procedure RegisterAuthorizationStorageFactory;

implementation

uses
  System.SysUtils,
  System.Variants,
  FireDAC.Stan.Param,
  Data.DB;

type
  TFireDACAuthorizationStorage = class(TInterfacedObject, IAuthorizationStorage)
  private
    FConnection: TFDConnection;
    function IsPostgreSQL: Boolean;
    function ReadRoleIdByName(const RoleName: string): Integer;
    function ReadUserIdByName(const Username: string): Integer;
    class function FieldAsBool(const Field: TField): Boolean; static;
  public
    constructor Create(AConnection: TFDConnection);
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

constructor TFireDACAuthorizationStorage.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TFireDACAuthorizationStorage.IsPostgreSQL: Boolean;
var
  DriverName: string;
begin
  if not Assigned(FConnection) then
    Exit(False);
  DriverName := FConnection.DriverName;
  if DriverName = '' then
    DriverName := FConnection.Params.Values['DriverID'];
  Result := SameText(DriverName, 'PG') or SameText(DriverName, 'PostgreSQL');
end;

class function TFireDACAuthorizationStorage.FieldAsBool(
  const Field: TField): Boolean;
begin
  if (Field = nil) or Field.IsNull then
    Exit(False);
  if Field.DataType = ftBoolean then
    Exit(Field.AsBoolean);
  Result := Field.AsInteger <> 0;
end;

procedure TFireDACAuthorizationStorage.EnsureTablesExist;
const
  SQLITE_CREATE_USERS_TABLE =
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
  SQLITE_CREATE_ROLES_TABLE =
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
  SQLITE_CREATE_ROLE_PERMISSIONS_TABLE =
    'CREATE TABLE IF NOT EXISTS auth_role_permissions (' +
    '  role_id INTEGER NOT NULL,' +
    '  permission VARCHAR(100) NOT NULL,' +
    '  granted_at DATETIME DEFAULT CURRENT_TIMESTAMP,' +
    '  PRIMARY KEY (role_id, permission),' +
    '  FOREIGN KEY (role_id) REFERENCES auth_roles(id) ON DELETE CASCADE' +
    ')';
  SQLITE_CREATE_USER_ROLES_TABLE =
    'CREATE TABLE IF NOT EXISTS auth_user_roles (' +
    '  user_id INTEGER NOT NULL,' +
    '  role_id INTEGER NOT NULL,' +
    '  assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP,' +
    '  PRIMARY KEY (user_id, role_id),' +
    '  FOREIGN KEY (user_id) REFERENCES auth_users(id) ON DELETE CASCADE,' +
    '  FOREIGN KEY (role_id) REFERENCES auth_roles(id) ON DELETE CASCADE' +
    ')';
  SQLITE_CREATE_AUDIT_LOG_TABLE =
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
  PG_CREATE_USERS_TABLE =
    'CREATE TABLE IF NOT EXISTS auth_users (' +
    '  id BIGSERIAL PRIMARY KEY,' +
    '  username VARCHAR(100) NOT NULL UNIQUE,' +
    '  display_name VARCHAR(200),' +
    '  email VARCHAR(255),' +
    '  is_active BOOLEAN DEFAULT TRUE,' +
    '  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,' +
    '  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,' +
    '  last_login_at TIMESTAMP,' +
    '  metadata TEXT' +
    ')';
  PG_CREATE_ROLES_TABLE =
    'CREATE TABLE IF NOT EXISTS auth_roles (' +
    '  id BIGSERIAL PRIMARY KEY,' +
    '  name VARCHAR(100) NOT NULL UNIQUE,' +
    '  display_name VARCHAR(200),' +
    '  description TEXT,' +
    '  parent_role VARCHAR(100),' +
    '  is_active BOOLEAN DEFAULT TRUE,' +
    '  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,' +
    '  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP' +
    ')';
  PG_CREATE_ROLE_PERMISSIONS_TABLE =
    'CREATE TABLE IF NOT EXISTS auth_role_permissions (' +
    '  role_id BIGINT NOT NULL,' +
    '  permission VARCHAR(100) NOT NULL,' +
    '  granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,' +
    '  PRIMARY KEY (role_id, permission),' +
    '  FOREIGN KEY (role_id) REFERENCES auth_roles(id) ON DELETE CASCADE' +
    ')';
  PG_CREATE_USER_ROLES_TABLE =
    'CREATE TABLE IF NOT EXISTS auth_user_roles (' +
    '  user_id BIGINT NOT NULL,' +
    '  role_id BIGINT NOT NULL,' +
    '  assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,' +
    '  PRIMARY KEY (user_id, role_id),' +
    '  FOREIGN KEY (user_id) REFERENCES auth_users(id) ON DELETE CASCADE,' +
    '  FOREIGN KEY (role_id) REFERENCES auth_roles(id) ON DELETE CASCADE' +
    ')';
  PG_CREATE_AUDIT_LOG_TABLE =
    'CREATE TABLE IF NOT EXISTS auth_audit_log (' +
    '  id BIGSERIAL PRIMARY KEY,' +
    '  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,' +
    '  username VARCHAR(100),' +
    '  action VARCHAR(50) NOT NULL,' +
    '  resource VARCHAR(200),' +
    '  details TEXT,' +
    '  ip_address VARCHAR(50),' +
    '  success BOOLEAN DEFAULT TRUE' +
    ')';
  CREATE_AUDIT_INDEX =
    'CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON auth_audit_log(timestamp)';
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  if IsPostgreSQL then
  begin
    FConnection.ExecSQL(PG_CREATE_USERS_TABLE);
    FConnection.ExecSQL(PG_CREATE_ROLES_TABLE);
    FConnection.ExecSQL(PG_CREATE_ROLE_PERMISSIONS_TABLE);
    FConnection.ExecSQL(PG_CREATE_USER_ROLES_TABLE);
    FConnection.ExecSQL(PG_CREATE_AUDIT_LOG_TABLE);
  end
  else
  begin
    FConnection.ExecSQL(SQLITE_CREATE_USERS_TABLE);
    FConnection.ExecSQL(SQLITE_CREATE_ROLES_TABLE);
    FConnection.ExecSQL(SQLITE_CREATE_ROLE_PERMISSIONS_TABLE);
    FConnection.ExecSQL(SQLITE_CREATE_USER_ROLES_TABLE);
    FConnection.ExecSQL(SQLITE_CREATE_AUDIT_LOG_TABLE);
  end;

  FConnection.ExecSQL(CREATE_AUDIT_INDEX);
end;

function TFireDACAuthorizationStorage.ReadRoles: TArray<TAuthorizationRoleData>;
var
  Query: TFDQuery;
  Data: TAuthorizationRoleData;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    if IsPostgreSQL then
      Query.SQL.Text := 'SELECT * FROM auth_roles WHERE is_active = TRUE'
    else
      Query.SQL.Text := 'SELECT * FROM auth_roles WHERE is_active = 1';
    Query.Open;
    while not Query.Eof do
    begin
      Data.Id := Query.FieldByName('id').AsInteger;
      Data.Name := Query.FieldByName('name').AsString;
      Data.DisplayName := Query.FieldByName('display_name').AsString;
      Data.Description := Query.FieldByName('description').AsString;
      Data.ParentRole := Query.FieldByName('parent_role').AsString;
      Data.IsActive := FieldAsBool(Query.FieldByName('is_active'));
      if Query.FieldByName('created_at').IsNull then
        Data.CreatedAt := 0
      else
        Data.CreatedAt := Query.FieldByName('created_at').AsDateTime;
      if Query.FieldByName('updated_at').IsNull then
        Data.UpdatedAt := 0
      else
        Data.UpdatedAt := Query.FieldByName('updated_at').AsDateTime;

      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Data;
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

function TFireDACAuthorizationStorage.ReadRolePermissions: TArray<TAuthorizationRolePermissionData>;
var
  Query: TFDQuery;
  Data: TAuthorizationRolePermissionData;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'SELECT r.name as role_name, rp.permission ' +
      'FROM auth_role_permissions rp ' +
      'JOIN auth_roles r ON r.id = rp.role_id';
    Query.Open;
    while not Query.Eof do
    begin
      Data.RoleName := Query.FieldByName('role_name').AsString;
      Data.Permission := Query.FieldByName('permission').AsString;
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Data;
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

function TFireDACAuthorizationStorage.ReadUsers: TArray<TAuthorizationUserData>;
var
  Query: TFDQuery;
  Data: TAuthorizationUserData;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    if IsPostgreSQL then
      Query.SQL.Text := 'SELECT * FROM auth_users WHERE is_active = TRUE'
    else
      Query.SQL.Text := 'SELECT * FROM auth_users WHERE is_active = 1';
    Query.Open;
    while not Query.Eof do
    begin
      Data.Id := Query.FieldByName('id').AsInteger;
      Data.Username := Query.FieldByName('username').AsString;
      Data.DisplayName := Query.FieldByName('display_name').AsString;
      Data.Email := Query.FieldByName('email').AsString;
      Data.IsActive := FieldAsBool(Query.FieldByName('is_active'));
      if Query.FieldByName('created_at').IsNull then
        Data.CreatedAt := 0
      else
        Data.CreatedAt := Query.FieldByName('created_at').AsDateTime;
      if Query.FieldByName('updated_at').IsNull then
        Data.UpdatedAt := 0
      else
        Data.UpdatedAt := Query.FieldByName('updated_at').AsDateTime;
      Data.HasLastLoginAt := not Query.FieldByName('last_login_at').IsNull;
      if Data.HasLastLoginAt then
        Data.LastLoginAt := Query.FieldByName('last_login_at').AsDateTime
      else
        Data.LastLoginAt := 0;

      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Data;
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

function TFireDACAuthorizationStorage.ReadUserRoles: TArray<TAuthorizationUserRoleData>;
var
  Query: TFDQuery;
  Data: TAuthorizationUserRoleData;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'SELECT u.username, r.name as role_name ' +
      'FROM auth_user_roles ur ' +
      'JOIN auth_users u ON u.id = ur.user_id ' +
      'JOIN auth_roles r ON r.id = ur.role_id';
    Query.Open;
    while not Query.Eof do
    begin
      Data.Username := Query.FieldByName('username').AsString;
      Data.RoleName := Query.FieldByName('role_name').AsString;
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Data;
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

function TFireDACAuthorizationStorage.ReadUserIdByName(
  const Username: string): Integer;
var
  Query: TFDQuery;
begin
  Result := 0;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT id FROM auth_users WHERE username = :username';
    Query.ParamByName('username').AsString := Username;
    Query.Open;
    if not Query.Eof then
      Result := Query.FieldByName('id').AsInteger;
  finally
    Query.Free;
  end;
end;

function TFireDACAuthorizationStorage.ReadRoleIdByName(
  const RoleName: string): Integer;
var
  Query: TFDQuery;
begin
  Result := 0;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT id FROM auth_roles WHERE name = :name';
    Query.ParamByName('name').AsString := RoleName;
    Query.Open;
    if not Query.Eof then
      Result := Query.FieldByName('id').AsInteger;
  finally
    Query.Free;
  end;
end;

function TFireDACAuthorizationStorage.InsertUser(
  const Data: TAuthorizationUserData): Integer;
var
  Query: TFDQuery;
  AutoValue: Variant;
begin
  Result := 0;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    if IsPostgreSQL then
    begin
      Query.SQL.Text :=
        'INSERT INTO auth_users (username, display_name, email, is_active) ' +
        'VALUES (:username, :display_name, :email, :is_active) RETURNING id';
      Query.ParamByName('username').AsString := Data.Username;
      Query.ParamByName('display_name').AsString := Data.DisplayName;
      Query.ParamByName('email').AsString := Data.Email;
      Query.ParamByName('is_active').AsBoolean := Data.IsActive;
      Query.Open;
      if not Query.Eof then
        Result := Query.FieldByName('id').AsInteger;
    end
    else
    begin
      Query.SQL.Text :=
        'INSERT INTO auth_users (username, display_name, email, is_active) ' +
        'VALUES (:username, :display_name, :email, :is_active)';
      Query.ParamByName('username').AsString := Data.Username;
      Query.ParamByName('display_name').AsString := Data.DisplayName;
      Query.ParamByName('email').AsString := Data.Email;
      Query.ParamByName('is_active').AsInteger := Ord(Data.IsActive);
      Query.ExecSQL;
      AutoValue := FConnection.GetLastAutoGenValue('');
      if not VarIsNull(AutoValue) and not VarIsEmpty(AutoValue) then
        Result := Integer(AutoValue)
      else
        Result := ReadUserIdByName(Data.Username);
    end;
  finally
    Query.Free;
  end;
end;

procedure TFireDACAuthorizationStorage.UpdateUser(const Data: TAuthorizationUserData);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'UPDATE auth_users SET display_name = :display_name, email = :email, ' +
      'is_active = :is_active, last_login_at = :last_login_at, ' +
      'updated_at = CURRENT_TIMESTAMP WHERE id = :id';
    Query.ParamByName('display_name').AsString := Data.DisplayName;
    Query.ParamByName('email').AsString := Data.Email;
    if IsPostgreSQL then
      Query.ParamByName('is_active').AsBoolean := Data.IsActive
    else
      Query.ParamByName('is_active').AsInteger := Ord(Data.IsActive);
    if Data.HasLastLoginAt then
      Query.ParamByName('last_login_at').AsDateTime := Data.LastLoginAt
    else
      Query.ParamByName('last_login_at').Clear;
    Query.ParamByName('id').AsInteger := Data.Id;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TFireDACAuthorizationStorage.DeleteUser(const Username: string);
var
  Query: TFDQuery;
  OwnTx: Boolean;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  // CR-014: 单条 ExecSQL 内放两条语句只有 SQLite 驱动支持，
  // PG prepared protocol 在 prepare 阶段即报错。拆成两次执行并包入事务，
  // 保持 BIZ-R3-008 的级联删除顺序（先关联表后主表）。
  OwnTx := False;
  if not FConnection.InTransaction then
  begin
    FConnection.StartTransaction;
    OwnTx := True;
  end;

  Query := TFDQuery.Create(nil);
  try
    try
      Query.Connection := FConnection;
      Query.SQL.Text :=
        'DELETE FROM auth_user_roles WHERE user_id = ' +
        '(SELECT id FROM auth_users WHERE username = :username)';
      Query.ParamByName('username').AsString := Username;
      Query.ExecSQL;

      Query.SQL.Text := 'DELETE FROM auth_users WHERE username = :username';
      Query.ParamByName('username').AsString := Username;
      Query.ExecSQL;

      if OwnTx then
        FConnection.Commit;
    except
      if OwnTx then
        FConnection.Rollback;
      raise;
    end;
  finally
    Query.Free;
  end;
end;

function TFireDACAuthorizationStorage.InsertRole(
  const Data: TAuthorizationRoleData): Integer;
var
  Query: TFDQuery;
  AutoValue: Variant;
begin
  Result := 0;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    if IsPostgreSQL then
    begin
      Query.SQL.Text :=
        'INSERT INTO auth_roles (name, display_name, description, parent_role, is_active) ' +
        'VALUES (:name, :display_name, :description, :parent_role, :is_active) RETURNING id';
      Query.ParamByName('name').AsString := Data.Name;
      Query.ParamByName('display_name').AsString := Data.DisplayName;
      Query.ParamByName('description').AsString := Data.Description;
      Query.ParamByName('parent_role').AsString := Data.ParentRole;
      Query.ParamByName('is_active').AsBoolean := Data.IsActive;
      Query.Open;
      if not Query.Eof then
        Result := Query.FieldByName('id').AsInteger;
    end
    else
    begin
      Query.SQL.Text :=
        'INSERT INTO auth_roles (name, display_name, description, parent_role, is_active) ' +
        'VALUES (:name, :display_name, :description, :parent_role, :is_active)';
      Query.ParamByName('name').AsString := Data.Name;
      Query.ParamByName('display_name').AsString := Data.DisplayName;
      Query.ParamByName('description').AsString := Data.Description;
      Query.ParamByName('parent_role').AsString := Data.ParentRole;
      Query.ParamByName('is_active').AsInteger := Ord(Data.IsActive);
      Query.ExecSQL;
      AutoValue := FConnection.GetLastAutoGenValue('');
      if not VarIsNull(AutoValue) and not VarIsEmpty(AutoValue) then
        Result := Integer(AutoValue)
      else
        Result := ReadRoleIdByName(Data.Name);
    end;
  finally
    Query.Free;
  end;
end;

procedure TFireDACAuthorizationStorage.UpdateRole(const Data: TAuthorizationRoleData);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'UPDATE auth_roles SET display_name = :display_name, description = :description, ' +
      'parent_role = :parent_role, is_active = :is_active, ' +
      'updated_at = CURRENT_TIMESTAMP WHERE id = :id';
    Query.ParamByName('display_name').AsString := Data.DisplayName;
    Query.ParamByName('description').AsString := Data.Description;
    Query.ParamByName('parent_role').AsString := Data.ParentRole;
    if IsPostgreSQL then
      Query.ParamByName('is_active').AsBoolean := Data.IsActive
    else
      Query.ParamByName('is_active').AsInteger := Ord(Data.IsActive);
    Query.ParamByName('id').AsInteger := Data.Id;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TFireDACAuthorizationStorage.ReplaceRolePermissions(RoleId: Integer;
  const Permissions: TArray<string>);
var
  Query: TFDQuery;
  Permission: string;
  OwnTx: Boolean;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  // DATA2-025: Only start a transaction if the caller hasn't already started
  // one. Track ownership so we only commit/rollback what we started.
  OwnTx := False;
  try
    if not FConnection.InTransaction then
    begin
      FConnection.StartTransaction;
      OwnTx := True;
    end;
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'DELETE FROM auth_role_permissions WHERE role_id = :role_id';
      Query.ParamByName('role_id').AsInteger := RoleId;
      Query.ExecSQL;

      Query.SQL.Text :=
        'INSERT INTO auth_role_permissions (role_id, permission) VALUES (:role_id, :permission)';
      for Permission in Permissions do
      begin
        Query.ParamByName('role_id').AsInteger := RoleId;
        Query.ParamByName('permission').AsString := Permission;
        Query.ExecSQL;
      end;
    finally
      Query.Free;
    end;
    if OwnTx then
      FConnection.Commit;
  except
    if OwnTx then
      FConnection.Rollback;
    raise;
  end;
end;

procedure TFireDACAuthorizationStorage.DeleteRole(const RoleName: string);
var
  Query: TFDQuery;
  OwnTx: Boolean;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  // CR-014: 同 DeleteUser——拆双语句为事务内两次执行（PG 兼容）
  OwnTx := False;
  if not FConnection.InTransaction then
  begin
    FConnection.StartTransaction;
    OwnTx := True;
  end;

  Query := TFDQuery.Create(nil);
  try
    try
      Query.Connection := FConnection;
      Query.SQL.Text :=
        'DELETE FROM auth_user_roles WHERE role_id = ' +
        '(SELECT id FROM auth_roles WHERE name = :name)';
      Query.ParamByName('name').AsString := RoleName;
      Query.ExecSQL;

      Query.SQL.Text := 'DELETE FROM auth_roles WHERE name = :name';
      Query.ParamByName('name').AsString := RoleName;
      Query.ExecSQL;

      if OwnTx then
        FConnection.Commit;
    except
      if OwnTx then
        FConnection.Rollback;
      raise;
    end;
  finally
    Query.Free;
  end;
end;

procedure TFireDACAuthorizationStorage.AssignUserRole(UserId, RoleId: Integer);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  // INSERT OR IGNORE eliminates the TOCTOU race between SELECT and INSERT
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT OR IGNORE INTO auth_user_roles (user_id, role_id) VALUES (:user_id, :role_id)';
    Query.ParamByName('user_id').AsInteger := UserId;
    Query.ParamByName('role_id').AsInteger := RoleId;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TFireDACAuthorizationStorage.RemoveUserRole(UserId, RoleId: Integer);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'DELETE FROM auth_user_roles WHERE user_id = :user_id AND role_id = :role_id';
    Query.ParamByName('user_id').AsInteger := UserId;
    Query.ParamByName('role_id').AsInteger := RoleId;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TFireDACAuthorizationStorage.InsertAudit(const Username, ActionName,
  Resource, Details: string; Success: Boolean);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT INTO auth_audit_log (username, action, resource, details, success) ' +
      'VALUES (:username, :action, :resource, :details, :success)';
    Query.ParamByName('username').AsString := Username;
    Query.ParamByName('action').AsString := ActionName;
    Query.ParamByName('resource').AsString := Resource;
    Query.ParamByName('details').AsString := Details;
    if IsPostgreSQL then
      Query.ParamByName('success').AsBoolean := Success
    else
      Query.ParamByName('success').AsInteger := Ord(Success);
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TFireDACAuthorizationStorage.ReadAudit(const Username: string;
  StartDate, EndDate: TDateTime; MaxEntries: Integer): TArray<TAuthorizationAuditData>;
var
  Query: TFDQuery;
  SQL: string;
  Data: TAuthorizationAuditData;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

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
      Data.Id := Query.FieldByName('id').AsLargeInt;
      if Query.FieldByName('timestamp').IsNull then
        Data.Timestamp := 0
      else
        Data.Timestamp := Query.FieldByName('timestamp').AsDateTime;
      Data.Username := Query.FieldByName('username').AsString;
      Data.Action := Query.FieldByName('action').AsString;
      Data.Resource := Query.FieldByName('resource').AsString;
      Data.Details := Query.FieldByName('details').AsString;
      Data.IPAddress := Query.FieldByName('ip_address').AsString;
      Data.Success := FieldAsBool(Query.FieldByName('success'));

      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Data;
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

procedure TFireDACAuthorizationStorage.ClearAuditBefore(const CutoffDate: TDateTime);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM auth_audit_log WHERE timestamp < :cutoff_date';
    Query.ParamByName('cutoff_date').AsDateTime := CutoffDate;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function CreateAuthorizationStorage(
  AConnection: TFDConnection): IAuthorizationStorage;
begin
  Result := TFireDACAuthorizationStorage.Create(AConnection);
end;

procedure RegisterAuthorizationStorageFactory;
begin
  TAuthorizationManager.SetStorageFactory(
    function(AConnection: TObject): IAuthorizationStorage
    var
      FDConnection: TFDConnection;
    begin
      if not (AConnection is TFDConnection) then
        raise EInvalidCast.Create(
          'Expected TFDConnection for Authorization FireDAC storage.');
      FDConnection := TFDConnection(AConnection);
      Result := CreateAuthorizationStorage(FDConnection);
    end);
end;

initialization
  RegisterAuthorizationStorageFactory;

end.
