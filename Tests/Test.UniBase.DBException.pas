{ ============================================================================ 
  Test.UniBase.DBException - Unit tests for UniBase.DBException

  Coverage:
    - Error message and suggestion lookup by code
    - Exception analysis (AnalyzeException)
    - EUniBaseDB.Wrap and FromCode helpers
    - UserMessage / Detailed fields basic behavior
    - OnException and SessionIdProvider callbacks
  ============================================================================ }

unit Test.UniBase.DBException;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.StrUtils,
  UniBase.DBException;

type
  [TestFixture]
  TTestUniBaseDBException = class
  private
    FPrevOnException: TProc<EUniBaseDB>;
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

{ TTestUniBaseDBException }

procedure TTestUniBaseDBException.Setup;
begin
  FPrevOnException := EUniBaseDB.OnException;
  FPrevLogEnabled := EUniBaseDB.LogEnabled;
  FPrevSessionIdProvider := EUniBaseDB.SessionIdProvider;

  EUniBaseDB.OnException := nil;
  EUniBaseDB.LogEnabled := False;
  EUniBaseDB.SessionIdProvider := nil;
end;

procedure TTestUniBaseDBException.TearDown;
begin
  EUniBaseDB.OnException := FPrevOnException;
  EUniBaseDB.LogEnabled := FPrevLogEnabled;
  EUniBaseDB.SessionIdProvider := FPrevSessionIdProvider;
end;

procedure TTestUniBaseDBException.GetErrorMessage_ReturnsKnownMessages;
begin
  Assert.AreEqual('无法连接到数据库', GetErrorMessage(ERR_DB_CONNECTION_FAILED));
  Assert.AreEqual('数据已存在，不能重复添加', GetErrorMessage(ERR_DB_UNIQUE_VIOLATION));
  Assert.AreEqual('数据库结构版本不匹配', GetErrorMessage(ERR_DB_SCHEMA_MISMATCH));
end;

procedure TTestUniBaseDBException.GetErrorSuggestion_UnknownCodeContainsCode;
var
  Suggestion: string;
begin
  Suggestion := GetErrorSuggestion('DB-9999');
  Assert.IsTrue(ContainsText(Suggestion, 'DB-9999'),
    'Suggestion for unknown code should mention the error code');
end;

procedure TTestUniBaseDBException.AnalyzeException_MapsCommonPatterns;
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

procedure TTestUniBaseDBException.Wrap_PopulatesFieldsAndUserMessage;
var
  Orig: Exception;
  DBE: EUniBaseDB;
  UserMsg: string;
begin
  Orig := Exception.Create('UNIQUE constraint failed: users.email');
  try
    DBE := EUniBaseDB.Wrap(Orig, 'SELECT * FROM Users', 'Saving user profile');
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

procedure TTestUniBaseDBException.FromCode_UsesErrorCodeAndDetail;
var
  E: EUniBaseDB;
begin
  E := EUniBaseDB.FromCode(ERR_DB_CONNECTION_FAILED, '数据库文件: test.db');
  try
    Assert.AreEqual(ERR_DB_CONNECTION_FAILED, E.ErrorCode);
    Assert.IsTrue(ContainsText(E.Message, GetErrorMessage(ERR_DB_CONNECTION_FAILED)));
    Assert.IsTrue(ContainsText(E.Message, 'test.db'));
    Assert.IsNotEmpty(E.Suggestion);
  finally
    E.Free;
  end;
end;

procedure TTestUniBaseDBException.SessionIdProvider_IsUsedForNewExceptions;
var
  E: EUniBaseDB;
begin
  EUniBaseDB.SessionIdProvider :=
    function: string
    begin
      Result := 'TEST-SESSION-ID';
    end;

  E := EUniBaseDB.FromCode(ERR_DB_QUERY_FAILED, '');
  try
    Assert.AreEqual('TEST-SESSION-ID', E.SessionId);
  finally
    E.Free;
  end;
end;

procedure TTestUniBaseDBException.OnException_CallbackIsInvoked;
var
  CallbackCount: Integer;
begin
  CallbackCount := 0;
  EUniBaseDB.OnException :=
    procedure(DBE: EUniBaseDB)
    begin
      Inc(CallbackCount);
    end;

  EUniBaseDB.FromCode(ERR_DB_QUERY_FAILED, '').Free;

  Assert.AreEqual(1, CallbackCount);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseDBException);

end.
