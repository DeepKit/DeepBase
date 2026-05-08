{ ============================================================================ 
  Test.DeepBase.DBException - Unit tests for DeepBase.DBException

  Coverage:
    - Error message and suggestion lookup by code
    - Exception analysis (AnalyzeException)
    - EDeepBaseDB.Wrap and FromCode helpers
    - UserMessage / Detailed fields basic behavior
    - OnException and SessionIdProvider callbacks
  ============================================================================ }

unit Test.DeepBase.DBException;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.StrUtils,
  DeepBase.DBException;

type
  [TestFixture]
  TTestDeepBaseDBException = class
  private
    FPrevOnException: TProc<EDeepBaseDB>;
    FPrevLogEnabled: Boolean;
    FPrevSessionIdProvider: TFunc<string>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure GetErrorMessage_ReturnsKnownMessages;
    [Test]
    procedure GetErrorSuggestion_UnknownCodeContainsCode;
    [Test]
    procedure AnalyzeException_MapsCommonPatterns;
    [Test]
    procedure Wrap_PopulatesFieldsAndUserMessage;
    [Test]
    procedure FromCode_UsesErrorCodeAndDetail;
    [Test]
    procedure SessionIdProvider_IsUsedForNewExceptions;
    [Test]
    procedure OnException_CallbackIsInvoked;
  end;

implementation

{ TTestDeepBaseDBException }

procedure TTestDeepBaseDBException.Setup;
begin
  FPrevOnException := EDeepBaseDB.OnException;
  FPrevLogEnabled := EDeepBaseDB.LogEnabled;
  FPrevSessionIdProvider := EDeepBaseDB.SessionIdProvider;

  EDeepBaseDB.OnException := nil;
  EDeepBaseDB.LogEnabled := False;
  EDeepBaseDB.SessionIdProvider := nil;
end;

procedure TTestDeepBaseDBException.TearDown;
begin
  EDeepBaseDB.OnException := FPrevOnException;
  EDeepBaseDB.LogEnabled := FPrevLogEnabled;
  EDeepBaseDB.SessionIdProvider := FPrevSessionIdProvider;
end;

procedure TTestDeepBaseDBException.GetErrorMessage_ReturnsKnownMessages;
begin
  Assert.AreEqual('无法连接到数据库', GetErrorMessage(ERR_DB_CONNECTION_FAILED));
  Assert.AreEqual('数据已存在，不能重复添加', GetErrorMessage(ERR_DB_UNIQUE_VIOLATION));
  Assert.AreEqual('数据库结构版本不匹配', GetErrorMessage(ERR_DB_SCHEMA_MISMATCH));
end;

procedure TTestDeepBaseDBException.GetErrorSuggestion_UnknownCodeContainsCode;
var
  Suggestion: string;
begin
  Suggestion := GetErrorSuggestion('DB-9999');
  Assert.IsTrue(ContainsText(Suggestion, 'DB-9999'),
    'Suggestion for unknown code should mention the error code');
end;

procedure TTestDeepBaseDBException.AnalyzeException_MapsCommonPatterns;
var
  E: Exception;
begin
  E := Exception.Create('UNIQUE constraint failed: users.email');
  try
    Assert.AreEqual(ERR_DB_UNIQUE_VIOLATION, AnalyzeException(E));
  finally
    E.Free;
  end;

  E := Exception.Create('database is locked');
  try
    Assert.AreEqual(ERR_DB_DATABASE_LOCKED, AnalyzeException(E));
  finally
    E.Free;
  end;

  E := Exception.Create('syntax error near FROM');
  try
    Assert.AreEqual(ERR_DB_SYNTAX_ERROR, AnalyzeException(E));
  finally
    E.Free;
  end;
end;

procedure TTestDeepBaseDBException.Wrap_PopulatesFieldsAndUserMessage;
var
  Orig: Exception;
  DBE: EDeepBaseDB;
  UserMsg: string;
begin
  Orig := Exception.Create('UNIQUE constraint failed: users.email');
  try
    DBE := EDeepBaseDB.Wrap(Orig, 'SELECT * FROM Users', 'Saving user profile');
    try
      Assert.AreEqual(ERR_DB_UNIQUE_VIOLATION, DBE.ErrorCode);
      Assert.AreEqual('SELECT * FROM Users', DBE.SQL);
      Assert.AreEqual('Saving user profile', DBE.Operation);
      Assert.AreEqual(Orig.Message, DBE.OriginalError);
      Assert.IsNotEmpty(DBE.Suggestion, 'Suggestion should not be empty');

      UserMsg := DBE.UserMessage;
      Assert.IsTrue(ContainsText(UserMsg, 'Saving user profile'), 'UserMessage should include operation text');
      Assert.IsTrue(ContainsText(UserMsg, DBE.Suggestion), 'UserMessage should include suggestion text');
    finally
      DBE.Free;
    end;
  finally
    Orig.Free;
  end;
end;

procedure TTestDeepBaseDBException.FromCode_UsesErrorCodeAndDetail;
var
  E: EDeepBaseDB;
begin
  E := EDeepBaseDB.FromCode(ERR_DB_CONNECTION_FAILED, '数据库文�? test.db');
  try
    Assert.AreEqual(ERR_DB_CONNECTION_FAILED, E.ErrorCode);
    Assert.IsTrue(ContainsText(E.Message, GetErrorMessage(ERR_DB_CONNECTION_FAILED)));
    Assert.IsTrue(ContainsText(E.Message, 'test.db'));
    Assert.IsNotEmpty(E.Suggestion);
  finally
    E.Free;
  end;
end;

procedure TTestDeepBaseDBException.SessionIdProvider_IsUsedForNewExceptions;
var
  E: EDeepBaseDB;
begin
  EDeepBaseDB.SessionIdProvider :=
    function: string
    begin
      Result := 'TEST-SESSION-ID';
    end;

  E := EDeepBaseDB.FromCode(ERR_DB_QUERY_FAILED, '');
  try
    Assert.AreEqual('TEST-SESSION-ID', E.SessionId);
  finally
    E.Free;
  end;
end;

procedure TTestDeepBaseDBException.OnException_CallbackIsInvoked;
var
  CallbackCount: Integer;
begin
  CallbackCount := 0;
  EDeepBaseDB.OnException :=
    procedure(DBE: EDeepBaseDB)
    begin
      Inc(CallbackCount);
    end;

  EDeepBaseDB.FromCode(ERR_DB_QUERY_FAILED, '').Free;

  Assert.AreEqual(1, CallbackCount);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDeepBaseDBException);

end.
