{ ============================================================================
  Test.UniBase.ORM - ORM Unit Tests
  ============================================================================ }

unit Test.UniBase.ORM;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Phys.SQLite,
  UniBase.ORM,
  UniBase.ORM.Mapping;

type
  // Test entity
  [Table('test_users')]
  TTestUser = class
  private
    [PrimaryKey]
    [Column('id')]
    FId: Integer;
    
    [Column('name', 100)]
    [Required]
    FName: string;
    
    [Column('email', 255)]
    FEmail: string;
    
    [Column('age')]
    FAge: Integer;
    
    [Column('active')]
    FActive: Boolean;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property Email: string read FEmail write FEmail;
    property Age: Integer read FAge write FAge;
    property Active: Boolean read FActive write FActive;
  end;

  [TestFixture]
  TORMTests = class
  private
    FConnection: TFDConnection;
    FContext: TDbContext;
    
    procedure CreateTestTable;
    procedure DropTestTable;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Metadata_Extraction;
    
    [Test]
    procedure Test_CreateTable;
    
    [Test]
    procedure Test_TableExists;
    
    [Test]
    procedure Test_Insert;
    
    [Test]
    procedure Test_Find;
    
    [Test]
    procedure Test_Update;
    
    [Test]
    procedure Test_Delete;
    
    [Test]
    procedure Test_GetAll;
    
    [Test]
    procedure Test_Query_Where;
    
    [Test]
    procedure Test_Query_OrderBy;
    
    [Test]
    procedure Test_Query_Limit;
    
    [Test]
    procedure Test_Query_Count;
    
    [Test]
    procedure Test_Transaction_Commit;
    
    [Test]
    procedure Test_Transaction_Rollback;
  end;

implementation

// ============================================================================
// TORMTests
// ============================================================================

procedure TORMTests.Setup;
begin
  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Database := ':memory:';
  FConnection.Connected := True;
  
  FContext := TDbContext.Create(FConnection, False);
  CreateTestTable;
end;

procedure TORMTests.TearDown;
begin
  DropTestTable;
  FContext.Free;
  FConnection.Free;
  TMetadataCache.ClearCache;
end;

procedure TORMTests.CreateTestTable;
begin
  FConnection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS test_users (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name VARCHAR(100) NOT NULL,' +
    '  email VARCHAR(255),' +
    '  age INTEGER,' +
    '  active INTEGER' +
    ')');
end;

procedure TORMTests.DropTestTable;
begin
  FConnection.ExecSQL('DROP TABLE IF EXISTS test_users');
end;

procedure TORMTests.Test_Metadata_Extraction;
var
  Metadata: TEntityMetadata;
begin
  Metadata := TMetadataCache.GetMetadata<TTestUser>;
  
  Assert.AreEqual('test_users', Metadata.TableName);
  Assert.IsNotNull(Metadata.PrimaryKey);
  Assert.AreEqual('id', Metadata.PrimaryKey.ColumnName);
  Assert.IsTrue(Metadata.PrimaryKey.IsAutoIncrement);
  Assert.AreEqual(5, Metadata.Columns.Count);
end;

procedure TORMTests.Test_CreateTable;
begin
  DropTestTable;
  Assert.IsFalse(FContext.TableExists<TTestUser>);
  
  FContext.CreateTable<TTestUser>;
  
  Assert.IsTrue(FContext.TableExists<TTestUser>);
end;

procedure TORMTests.Test_TableExists;
begin
  Assert.IsTrue(FContext.TableExists<TTestUser>);
  
  DropTestTable;
  
  Assert.IsFalse(FContext.TableExists<TTestUser>);
end;

procedure TORMTests.Test_Insert;
var
  User: TTestUser;
begin
  User := TTestUser.Create;
  try
    User.Name := 'John Doe';
    User.Email := 'john@example.com';
    User.Age := 30;
    User.Active := True;
    
    FContext.Insert<TTestUser>(User);
    
    Assert.IsTrue(User.Id > 0, 'Auto-generated ID should be set');
  finally
    User.Free;
  end;
end;

procedure TORMTests.Test_Find;
var
  User, FoundUser: TTestUser;
begin
  // Insert
  User := TTestUser.Create;
  try
    User.Name := 'Jane Doe';
    User.Email := 'jane@example.com';
    User.Age := 25;
    FContext.Insert<TTestUser>(User);
    
    // Find
    FoundUser := FContext.Find<TTestUser>(User.Id);
    try
      Assert.IsNotNull(FoundUser);
      Assert.AreEqual('Jane Doe', FoundUser.Name);
      Assert.AreEqual('jane@example.com', FoundUser.Email);
      Assert.AreEqual(25, FoundUser.Age);
    finally
      FoundUser.Free;
    end;
  finally
    User.Free;
  end;
end;

procedure TORMTests.Test_Update;
var
  User, FoundUser: TTestUser;
begin
  // Insert
  User := TTestUser.Create;
  try
    User.Name := 'Original Name';
    FContext.Insert<TTestUser>(User);
    
    // Update
    User.Name := 'Updated Name';
    User.Email := 'updated@example.com';
    FContext.Update<TTestUser>(User);
    
    // Verify
    FoundUser := FContext.Find<TTestUser>(User.Id);
    try
      Assert.AreEqual('Updated Name', FoundUser.Name);
      Assert.AreEqual('updated@example.com', FoundUser.Email);
    finally
      FoundUser.Free;
    end;
  finally
    User.Free;
  end;
end;

procedure TORMTests.Test_Delete;
var
  User, FoundUser: TTestUser;
  UserId: Integer;
begin
  // Insert
  User := TTestUser.Create;
  try
    User.Name := 'To Delete';
    FContext.Insert<TTestUser>(User);
    UserId := User.Id;
    
    // Delete
    FContext.Delete<TTestUser>(User);
  finally
    User.Free;
  end;
  
  // Verify deleted
  FoundUser := FContext.Find<TTestUser>(UserId);
  Assert.IsNull(FoundUser);
end;

procedure TORMTests.Test_GetAll;
var
  User1, User2: TTestUser;
  AllUsers: TObjectList<TTestUser>;
begin
  // Insert multiple
  User1 := TTestUser.Create;
  User2 := TTestUser.Create;
  try
    User1.Name := 'User 1';
    User2.Name := 'User 2';
    FContext.Insert<TTestUser>(User1);
    FContext.Insert<TTestUser>(User2);
  finally
    User1.Free;
    User2.Free;
  end;
  
  // Get all
  AllUsers := FContext.GetAll<TTestUser>;
  try
    Assert.AreEqual(2, AllUsers.Count);
  finally
    AllUsers.Free;
  end;
end;

procedure TORMTests.Test_Query_Where;
var
  User1, User2: TTestUser;
  Results: TObjectList<TTestUser>;
begin
  // Insert
  User1 := TTestUser.Create;
  User2 := TTestUser.Create;
  try
    User1.Name := 'Alice';
    User1.Age := 20;
    User2.Name := 'Bob';
    User2.Age := 30;
    FContext.Insert<TTestUser>(User1);
    FContext.Insert<TTestUser>(User2);
  finally
    User1.Free;
    User2.Free;
  end;
  
  // Query with WHERE
  Results := FContext.Query<TTestUser>
    .Where('age > ?', [25])
    .ToList;
  try
    Assert.AreEqual(1, Results.Count);
    Assert.AreEqual('Bob', Results[0].Name);
  finally
    Results.Free;
  end;
end;

procedure TORMTests.Test_Query_OrderBy;
var
  User1, User2, User3: TTestUser;
  Results: TObjectList<TTestUser>;
begin
  // Insert
  User1 := TTestUser.Create;
  User2 := TTestUser.Create;
  User3 := TTestUser.Create;
  try
    User1.Name := 'Charlie';
    User2.Name := 'Alice';
    User3.Name := 'Bob';
    FContext.Insert<TTestUser>(User1);
    FContext.Insert<TTestUser>(User2);
    FContext.Insert<TTestUser>(User3);
  finally
    User1.Free;
    User2.Free;
    User3.Free;
  end;
  
  // Query with ORDER BY
  Results := FContext.Query<TTestUser>
    .OrderBy('name')
    .ToList;
  try
    Assert.AreEqual(3, Results.Count);
    Assert.AreEqual('Alice', Results[0].Name);
    Assert.AreEqual('Bob', Results[1].Name);
    Assert.AreEqual('Charlie', Results[2].Name);
  finally
    Results.Free;
  end;
end;

procedure TORMTests.Test_Query_Limit;
var
  I: Integer;
  User: TTestUser;
  Results: TObjectList<TTestUser>;
begin
  // Insert 5 users
  for I := 1 to 5 do
  begin
    User := TTestUser.Create;
    try
      User.Name := 'User ' + IntToStr(I);
      FContext.Insert<TTestUser>(User);
    finally
      User.Free;
    end;
  end;
  
  // Query with LIMIT
  Results := FContext.Query<TTestUser>
    .Limit(3)
    .ToList;
  try
    Assert.AreEqual(3, Results.Count);
  finally
    Results.Free;
  end;
end;

procedure TORMTests.Test_Query_Count;
var
  I: Integer;
  User: TTestUser;
  Count: Integer;
begin
  // Insert 5 users
  for I := 1 to 5 do
  begin
    User := TTestUser.Create;
    try
      User.Name := 'User ' + IntToStr(I);
      User.Age := I * 10;
      FContext.Insert<TTestUser>(User);
    finally
      User.Free;
    end;
  end;
  
  // Count all
  Count := FContext.Query<TTestUser>.Count;
  Assert.AreEqual(5, Count);
  
  // Count with filter
  Count := FContext.Query<TTestUser>
    .Where('age >= ?', [30])
    .Count;
  Assert.AreEqual(3, Count);
end;

procedure TORMTests.Test_Transaction_Commit;
var
  User: TTestUser;
  Count: Integer;
begin
  FContext.BeginTransaction;
  try
    User := TTestUser.Create;
    try
      User.Name := 'Transaction User';
      FContext.Insert<TTestUser>(User);
    finally
      User.Free;
    end;
    FContext.Commit;
  except
    FContext.Rollback;
    raise;
  end;
  
  Count := FContext.Query<TTestUser>.Count;
  Assert.AreEqual(1, Count);
end;

procedure TORMTests.Test_Transaction_Rollback;
var
  User: TTestUser;
  Count: Integer;
begin
  FContext.BeginTransaction;
  try
    User := TTestUser.Create;
    try
      User.Name := 'Rollback User';
      FContext.Insert<TTestUser>(User);
    finally
      User.Free;
    end;
    // Intentionally rollback
    FContext.Rollback;
  except
    FContext.Rollback;
    raise;
  end;
  
  Count := FContext.Query<TTestUser>.Count;
  Assert.AreEqual(0, Count);
end;

initialization
  TDUnitX.RegisterTestFixture(TORMTests);

end.
