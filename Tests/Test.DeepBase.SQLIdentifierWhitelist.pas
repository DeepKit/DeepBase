{ ============================================================================
  Test.DeepBase.SQLIdentifierWhitelist - A2-11 regression

  TSQLUtils.IsValidIdentifier must accept only ASCII [A-Za-z_][A-Za-z0-9_]*
  (System.Character's IsLetter let Unicode homoglyphs through) and
  IsValidColumnDef's forbidden-keyword blacklist must cover the words added
  by A2-11 (REPLACE/WITH/EXEC/CALL/BEGIN/COMMIT/GRANT/COPY) on top of the
  original set, per-word.
  ============================================================================ }

unit Test.DeepBase.SQLIdentifierWhitelist;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  DeepBase.SQL.Utils;

type
  [TestFixture]
  TTestSQLIdentifierWhitelistA211 = class
  public
    [Test]
    procedure Test_LegalAsciiIdentifiers_Accepted;

    [Test]
    procedure Test_UnicodeLetters_Rejected;

    [Test]
    procedure Test_HomoglyphCyrillic_Rejected;

    [Test]
    procedure Test_ValidateIdentifier_RaisesOnUnicode;

    [Test]
    procedure Test_ColumnDef_AllForbiddenKeywords_Rejected;

    [Test]
    procedure Test_ColumnDef_LegalDefinitions_Accepted;
  end;

implementation

{ TTestSQLIdentifierWhitelistA211 }

procedure TTestSQLIdentifierWhitelistA211.Test_LegalAsciiIdentifiers_Accepted;
begin
  Assert.IsTrue(TSQLUtils.IsValidIdentifier('users'));
  Assert.IsTrue(TSQLUtils.IsValidIdentifier('_tmp'));
  Assert.IsTrue(TSQLUtils.IsValidIdentifier('A1'));
  Assert.IsTrue(TSQLUtils.IsValidIdentifier('user_id_2'));
  Assert.IsTrue(TSQLUtils.IsValidIdentifier(StringOfChar('a', 128)));
  Assert.IsFalse(TSQLUtils.IsValidIdentifier(StringOfChar('a', 129)));
  Assert.IsFalse(TSQLUtils.IsValidIdentifier(''));
  Assert.IsFalse(TSQLUtils.IsValidIdentifier('1abc'));
  Assert.IsFalse(TSQLUtils.IsValidIdentifier('a b'));
  Assert.IsFalse(TSQLUtils.IsValidIdentifier('a"b'));
end;

procedure TTestSQLIdentifierWhitelistA211.Test_UnicodeLetters_Rejected;
begin
  // CJK ideograph U+8868 ('table' in Chinese) as first char and in body
  Assert.IsFalse(TSQLUtils.IsValidIdentifier(Char($8868) + 'name'),
    'leading CJK letter must be rejected (A2-11 ASCII-only whitelist)');
  Assert.IsFalse(TSQLUtils.IsValidIdentifier('user' + Char($8868)),
    'embedded CJK letter must be rejected');
  // Latin-1 letter A-acute is still non-ASCII for this whitelist
  Assert.IsFalse(TSQLUtils.IsValidIdentifier(Char($00C9) + 'cole'));
end;

procedure TTestSQLIdentifierWhitelistA211.Test_HomoglyphCyrillic_Rejected;
begin
  // Cyrillic small ie U+0435 looks like ASCII 'e': homoglyph injection face
  Assert.IsFalse(TSQLUtils.IsValidIdentifier(Char($0435) + 'ole'),
    'Cyrillic homoglyph must be rejected even though IsLetter said yes');
end;

procedure TTestSQLIdentifierWhitelistA211.Test_ValidateIdentifier_RaisesOnUnicode;
begin
  Assert.WillRaise(
    procedure
    begin
      TSQLUtils.ValidateIdentifier(Char($0435) + 'ole', 'Test');
    end, EArgumentException);
  // legal name must not raise
  TSQLUtils.ValidateIdentifier('orders', 'Test');
end;

procedure TTestSQLIdentifierWhitelistA211.Test_ColumnDef_AllForbiddenKeywords_Rejected;
const
  ALL_KEYWORDS: array [0 .. 21] of string = (
    'DROP', 'CREATE', 'ALTER', 'DELETE', 'INSERT', 'UPDATE', 'SELECT',
    'TRIGGER', 'INDEX', 'VIEW', 'ATTACH', 'DETACH', 'PRAGMA', 'VACUUM',
    'REPLACE', 'WITH', 'EXEC', 'CALL', 'BEGIN', 'COMMIT', 'GRANT', 'COPY');
var
  KW: string;
begin
  for KW in ALL_KEYWORDS do
  begin
    Assert.IsFalse(TSQLUtils.IsValidColumnDef('TEXT ' + KW + ' TABLE x'),
      'forbidden keyword must reject column def: ' + KW);
    // lowercase on a word boundary must hit the same verdict
    Assert.IsFalse(TSQLUtils.IsValidColumnDef('INTEGER ' + LowerCase(KW)),
      'lowercase forbidden keyword must reject column def: ' + KW);
  end;
end;

procedure TTestSQLIdentifierWhitelistA211.Test_ColumnDef_LegalDefinitions_Accepted;
begin
  Assert.IsTrue(TSQLUtils.IsValidColumnDef('TEXT'));
  Assert.IsTrue(TSQLUtils.IsValidColumnDef('INTEGER NOT NULL DEFAULT 0'));
  Assert.IsTrue(TSQLUtils.IsValidColumnDef('NUMERIC(10,2)'));
  Assert.IsTrue(TSQLUtils.IsValidColumnDef('VARCHAR(64) DEFAULT ''ok'''));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSQLIdentifierWhitelistA211);

end.
