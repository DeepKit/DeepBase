{ ============================================================================
  DeepBase.SQL.Utils - SQL Safety Utilities

  Version: 1.0
  Description: Shared SQL identifier validation to prevent SQL injection
               in dynamic table/column name usage.
  ============================================================================ }

unit DeepBase.SQL.Utils;

interface

uses
  System.SysUtils;

type
  TSQLUtils = class
  public
    /// <summary>
    /// Returns True if AName is a valid SQL identifier:
    /// starts with letter or underscore, contains only [a-zA-Z0-9_],
    /// max 128 characters.
    /// </summary>
    class function IsValidIdentifier(const AName: string): Boolean; static;

    /// <summary>
    /// Raises EArgumentException if AName is not a valid SQL identifier.
    /// AContext is included in the error message for diagnostics.
    /// </summary>
    class procedure ValidateIdentifier(const AName, AContext: string); static;

    /// <summary>
    /// Returns True if AColumnDef is a safe SQLite column definition fragment
    /// for splicing into an `ALTER TABLE ... ADD COLUMN &lt;name&gt; &lt;def&gt;` DDL.
    /// Allows type words (TEXT/INTEGER/REAL/BLOB/NUMERIC/VARCHAR/CHAR/...),
    /// DEFAULT, NOT NULL, numbers, single-quoted string literals, parentheses,
    /// commas. Rejects statement terminators (``;``), SQL comments (``--``,
    /// ``/*`` ``*/``), newlines, and any DDL/DML keyword (DROP/CREATE/...),
    /// which would enable injection when a future caller passes attacker-
    /// influenced input through the public IManagerStorage.AddColumn API.
    /// See REVIEW5-R3 DATA-R3-007.
    /// </summary>
    class function IsValidColumnDef(const AColumnDef: string): Boolean; static;

    /// <summary>
    /// Raises EArgumentException if AColumnDef is not a safe column definition
    /// fragment. AContext is included in the error message for diagnostics.
    /// </summary>
    class procedure ValidateColumnDef(const AColumnDef, AContext: string); static;
  end;

implementation

uses
  System.Character,
  System.RegularExpressions,
  System.SysConst;

class function TSQLUtils.IsValidIdentifier(const AName: string): Boolean;
begin
  if (AName = '') or (AName.Length > 128) then
    Exit(False);
  // First character must be letter or underscore
  if not (AName[1].IsLetter or (AName[1] = '_')) then
    Exit(False);
  // Remaining characters: letter, digit, or underscore
  for var I := 2 to AName.Length do
  begin
    if not (AName[I].IsLetterOrDigit or (AName[I] = '_')) then
      Exit(False);
  end;
  Result := True;
end;

class procedure TSQLUtils.ValidateIdentifier(const AName, AContext: string);
begin
  if not IsValidIdentifier(AName) then
    raise EArgumentException.CreateFmt(
      'Invalid SQL identifier in %s: "%s"', [AContext, AName]);
end;

class function TSQLUtils.IsValidColumnDef(const AColumnDef: string): Boolean;
const
  // Absolute upper bound on a single column definition fragment.
  MAX_LEN = 200;
  // Keywords that, if present, indicate this is not a bare column def but an
  // attempt to chain a second statement or smuggle in a DDL/DML side effect.
  // Word-boundary, case-insensitive. ORDER MATTERS for nothing here (OR'd).
  FORBIDDEN_KEYWORDS: array[0..13] of string = (
    'DROP', 'CREATE', 'ALTER', 'DELETE', 'INSERT', 'UPDATE', 'SELECT',
    'TRIGGER', 'INDEX', 'VIEW', 'ATTACH', 'DETACH', 'PRAGMA', 'VACUUM');
var
  UpperDef: string;
  KW: string;
begin
  if (AColumnDef = '') or (AColumnDef.Length > MAX_LEN) then
    Exit(False);

  // Reject statement terminators, comments, and line breaks — anything that
  // could close the ADD COLUMN clause and start a new one.
  if AColumnDef.Contains(';') or AColumnDef.Contains('--') or
     AColumnDef.Contains('/*') or AColumnDef.Contains('*/') or
     AColumnDef.Contains(#13) or AColumnDef.Contains(#10) then
    Exit(False);

  // Reject DDL/DML keywords on word boundaries.
  UpperDef := UpperCase(AColumnDef);
  for KW in FORBIDDEN_KEYWORDS do
  begin
    if TRegEx.IsMatch(UpperDef, '\b' + KW + '\b') then
      Exit(False);
  end;

  // Allowed character set: letters, digits, whitespace, single quote (string
  // literals), underscore, period (numeric decimals / qualified defaults),
  // parentheses and commas (e.g. NUMERIC(10,2)). Everything else — double
  // quotes, backticks, semicolons, etc. — is rejected.
  for var I := 1 to AColumnDef.Length do
  begin
    if not (AColumnDef[I].IsLetterOrDigit or (AColumnDef[I] = ' ') or
            (AColumnDef[I] = '''') or (AColumnDef[I] = '_') or
            (AColumnDef[I] = '.') or (AColumnDef[I] = '(') or
            (AColumnDef[I] = ')') or (AColumnDef[I] = ',')) then
      Exit(False);
  end;

  Result := True;
end;

class procedure TSQLUtils.ValidateColumnDef(const AColumnDef, AContext: string);
begin
  if not IsValidColumnDef(AColumnDef) then
    raise EArgumentException.CreateFmt(
      'Invalid column definition in %s: "%s"', [AContext, AColumnDef]);
end;

end.
