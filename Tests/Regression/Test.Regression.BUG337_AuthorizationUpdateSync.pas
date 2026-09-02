unit Test.Regression.BUG337_AuthorizationUpdateSync;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.Authorization;

type
  TRegressionAuthStorage = class(TInterfacedObject, IAuthorizationStorage)
  private
    FUsers: TDictionary<string, TAuthorizationUserData>;
    FRoles: TDictionary<string, TAuthorizationRoleData>;
    FRolePerms: TList<TAuthorizationRolePermissionData>;
    FUserRoles: TList<TAuthorizationUserRoleData>;
    FNextUserId: Integer;
    FNextRoleId: Integer;
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
    procedure ReplaceRolePermissions(RoleId: Integer;
      const Permissions: TArray<string>);
    procedure DeleteRole(const RoleName: string);
    procedure AssignUserRole(UserId, RoleId: Integer);
    procedure RemoveUserRole(UserId, RoleId: Integer);
    procedure InsertAudit(const Username, ActionName, Resource, Details: string;
      Success: Boolean);
    function ReadAudit(const Username: string; StartDate, EndDate: TDateTime;
      MaxEntries: Integer): TArray<TAuthorizationAuditData>;
    procedure ClearAuditBefore(const CutoffDate: TDateTime);
  end;

  [TestFixture]
  [Category('regression')]
  TBUG337_AuthorizationUpdateSyncTest = class(TRegressionTestBase)
  private
    FStorage: IAuthorizationStorage;
    FManager: TAuthorizationManager;
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Setup]
    procedure SetUp; override;
    [TearDown]
    procedure TearDown; override;

    [Test]
    procedure Test_UpdateUser_SyncsMemoryBeforeGetUser;

    [Test]
    procedure Test_UpdateRole_SyncsPermissionsForHasPermission;
  end;

implementation

{ TRegressionAuthStorage }

constructor TRegressionAuthStorage.Create;
begin
  inherited;
  FUsers := TDictionary<string, TAuthorizationUserData>.Create;
  FRoles := TDictionary<string, TAuthorizationRoleData>.Create;
  FRolePerms := TList<TAuthorizationRolePermissionData>.Create;
  FUserRoles := TList<TAuthorizationUserRoleData>.Create;
  FNextUserId := 1;
  FNextRoleId := 1;
end;

destructor TRegressionAuthStorage.Destroy;
begin
  FUserRoles.Free;
  FRolePerms.Free;
  FRoles.Free;
  FUsers.Free;
  inherited;
end;

procedure TRegressionAuthStorage.EnsureTablesExist;
begin
end;

function TRegressionAuthStorage.ReadRoles: TArray<TAuthorizationRoleData>;
var
  Data: TAuthorizationRoleData;
begin
  SetLength(Result, 0);
  for Data in FRoles.Values do
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Data;
  end;
end;

function TRegressionAuthStorage.ReadRolePermissions: TArray<TAuthorizationRolePermissionData>;
begin
  Result := FRolePerms.ToArray;
end;

function TRegressionAuthStorage.ReadUsers: TArray<TAuthorizationUserData>;
var
  Data: TAuthorizationUserData;
begin
  SetLength(Result, 0);
  for Data in FUsers.Values do
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Data;
  end;
end;

function TRegressionAuthStorage.ReadUserRoles: TArray<TAuthorizationUserRoleData>;
begin
  Result := FUserRoles.ToArray;
end;

function TRegressionAuthStorage.InsertUser(const Data: TAuthorizationUserData): Integer;
var
  Copy: TAuthorizationUserData;
begin
  Copy := Data;
  Copy.Id := FNextUserId;
  Inc(FNextUserId);
  FUsers.AddOrSetValue(Copy.Username, Copy);
  Result := Copy.Id;
end;

procedure TRegressionAuthStorage.UpdateUser(const Data: TAuthorizationUserData);
begin
  FUsers.AddOrSetValue(Data.Username, Data);
end;

procedure TRegressionAuthStorage.DeleteUser(const Username: string);
begin
  FUsers.Remove(Username);
end;

function TRegressionAuthStorage.InsertRole(const Data: TAuthorizationRoleData): Integer;
var
  Copy: TAuthorizationRoleData;
begin
  Copy := Data;
  Copy.Id := FNextRoleId;
  Inc(FNextRoleId);
  FRoles.AddOrSetValue(Copy.Name, Copy);
  Result := Copy.Id;
end;

procedure TRegressionAuthStorage.UpdateRole(const Data: TAuthorizationRoleData);
begin
  FRoles.AddOrSetValue(Data.Name, Data);
end;

function TRegressionAuthStorage.TryFindRoleNameById(RoleId: Integer;
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

function TRegressionAuthStorage.TryFindUserNameById(UserId: Integer;
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

procedure TRegressionAuthStorage.ReplaceRolePermissions(RoleId: Integer;
  const Permissions: TArray<string>);
var
  RoleName: string;
  I: Integer;
  Entry: TAuthorizationRolePermissionData;
  Permission: string;
begin
  if not TryFindRoleNameById(RoleId, RoleName) then
    Exit;

  for I := FRolePerms.Count - 1 downto 0 do
    if SameText(FRolePerms[I].RoleName, RoleName) then
      FRolePerms.Delete(I);
  for Permission in Permissions do
  begin
    Entry.RoleName := RoleName;
    Entry.Permission := Permission;
    FRolePerms.Add(Entry);
  end;
end;

procedure TRegressionAuthStorage.DeleteRole(const RoleName: string);
begin
  FRoles.Remove(RoleName);
end;

procedure TRegressionAuthStorage.AssignUserRole(UserId, RoleId: Integer);
var
  Username: string;
  RoleName: string;
  Entry: TAuthorizationUserRoleData;
begin
  if not TryFindUserNameById(UserId, Username) then
    Exit;
  if not TryFindRoleNameById(RoleId, RoleName) then
    Exit;

  Entry.Username := Username;
  Entry.RoleName := RoleName;
  FUserRoles.Add(Entry);
end;

procedure TRegressionAuthStorage.RemoveUserRole(UserId, RoleId: Integer);
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

procedure TRegressionAuthStorage.InsertAudit(const Username, ActionName, Resource,
  Details: string; Success: Boolean);
begin
end;

function TRegressionAuthStorage.ReadAudit(const Username: string; StartDate,
  EndDate: TDateTime; MaxEntries: Integer): TArray<TAuthorizationAuditData>;
begin
  SetLength(Result, 0);
end;

procedure TRegressionAuthStorage.ClearAuditBefore(const CutoffDate: TDateTime);
begin
end;

{ TBUG337_AuthorizationUpdateSyncTest }

procedure TBUG337_AuthorizationUpdateSyncTest.SetUp;
begin
  inherited;
  FStorage := TRegressionAuthStorage.Create;
  FManager := TAuthorizationManager.Create(FStorage);
end;

procedure TBUG337_AuthorizationUpdateSyncTest.TearDown;
begin
  FreeAndNil(FManager);
  FStorage := nil;
  inherited;
end;

function TBUG337_AuthorizationUpdateSyncTest.GetBugNumber: string;
begin
  Result := 'BUG-337';
end;

function TBUG337_AuthorizationUpdateSyncTest.GetBugDescription: string;
begin
  Result := 'UpdateUser/UpdateRole must sync in-memory RBAC dictionaries';
end;

function TBUG337_AuthorizationUpdateSyncTest.GetFixDate: string;
begin
  Result := '2026-09-02';
end;

function TBUG337_AuthorizationUpdateSyncTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBUG337_AuthorizationUpdateSyncTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.Authorization.pas';
end;

procedure TBUG337_AuthorizationUpdateSyncTest.Test_UpdateUser_SyncsMemoryBeforeGetUser;
var
  Live, Snapshot: TUser;
begin
  FManager.CreateUser('alice', 'Alice');
  FManager.CreateRole('editor', 'Editor');
  FManager.AssignRole('alice', 'editor');

  Live := FManager.GetUser('alice');
  try
    Live.AddRole('editor');
    Live.DisplayName := 'Alice Updated';
    FManager.UpdateUser(Live);
  finally
    Live.Free;
  end;

  Snapshot := FManager.GetUser('alice');
  try
    Assert.AreEqual('Alice Updated', Snapshot.DisplayName);
  finally
    Snapshot.Free;
  end;
end;

procedure TBUG337_AuthorizationUpdateSyncTest.Test_UpdateRole_SyncsPermissionsForHasPermission;
var
  Role: TRole;
begin
  FManager.CreateRole('ops', 'Ops');
  FManager.CreateUser('bob', 'Bob');
  FManager.AssignRole('bob', 'ops');

  Assert.IsFalse(FManager.HasPermission('bob', 'deploy.run'));

  Role := FManager.GetRole('ops');
  try
    Role.AddPermission('deploy.run');
    FManager.UpdateRole(Role);
  finally
    Role.Free;
  end;

  Assert.IsTrue(FManager.HasPermission('bob', 'deploy.run'),
    'HasPermission must see updated role permissions without reload');
end;

initialization
  TDUnitX.RegisterTestFixture(TBUG337_AuthorizationUpdateSyncTest);

end.
