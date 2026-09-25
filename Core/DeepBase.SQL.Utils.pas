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
  /// <summary>
  /// A2-15: 受支持的 SQL 方言。判定只允许经 DriverNameToDialect 的
  /// FireDAC 驱动名精确匹配表得到，禁止在各调用点用 ToLower/Contains
  /// 之类的裸字符串包含判断（原 SQLLogger 用 Contains('postgres') 判 PG，
  /// 而 FireDAC 的 PG DriverName 是 'PG'，条件恒假）。
  /// </summary>
  TSQLDialect = (sdUnknown, sdSQLite, sdPostgreSQL, sdMSSQL, sdMySQL);

  TSQLUtils = class
  public
    /// <summary>
    /// A2-15: 把 FireDAC 连接驱动名映射为方言（大小写不敏感的精确匹配）。
    /// 未列入常量表的驱动名返回 sdUnknown，调用方必须自行决定 fail 语义，
    /// 不得猜测方言。
    /// </summary>
    class function DriverNameToDialect(const ADriverName: string): TSQLDialect; static;

    /// <summary>
    /// A2-16: 按方言生成分派"插入且冲突忽略"语句。
    /// SQLite 保留 INSERT OR IGNORE；PG 用 INSERT ... ON CONFLICT DO NOTHING。
    /// 其余方言（含 sdUnknown）抛 EArgumentException——不猜语义（fail-closed）。
    /// ATable/AColumns/AValues/AConflictColumns 必须由调用方以受信任常量拼接，
    /// 标识符需先过 ValidateIdentifier。
    /// </summary>
    class function BuildInsertIgnoreSQL(ADialect: TSQLDialect;
      const ATable, AColumns, AValues, AConflictColumns: string): string; static;

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

const
  // A2-15: FireDAC 驱动名集中定义（与 DriverNameToDialect 同处维护）。
  // 判定只允许走这张常量表的精确匹配，禁止调用点裸字符串包含判断。
  DRIVER_NAME_SQLITE = 'SQLITE';
  DRIVER_NAME_PG = 'PG';
  // 兼容部分部署里 Params.DriverID 写成全称的别名，仍是精确匹配而非 Contains
  DRIVER_NAME_PG_ALIAS = 'POSTGRESQL';
  DRIVER_NAME_MSSQL = 'MSSQL';
  DRIVER_NAME_MYSQL = 'MYSQL';

implementation

uses
  System.Character,
  System.RegularExpressions,
  System.SysConst;

class function TSQLUtils.DriverNameToDialect(const ADriverName: string): TSQLDialect;
begin
  if SameText(ADriverName, DRIVER_NAME_SQLITE) then
    Exit(sdSQLite);
  if SameText(ADriverName, DRIVER_NAME_PG) or
     SameText(ADriverName, DRIVER_NAME_PG_ALIAS) then
    Exit(sdPostgreSQL);
  if SameText(ADriverName, DRIVER_NAME_MSSQL) then
    Exit(sdMSSQL);
  if SameText(ADriverName, DRIVER_NAME_MYSQL) then
    Exit(sdMySQL);
  Result := sdUnknown;
end;

class function TSQLUtils.BuildInsertIgnoreSQL(ADialect: TSQLDialect;
  const ATable, AColumns, AValues, AConflictColumns: string): string;
begin
  case ADialect of
    sdSQLite:
      Result := Format('INSERT OR IGNORE INTO %s (%s) VALUES (%s)',
        [ATable, AColumns, AValues]);
    sdPostgreSQL:
      Result := Format('INSERT INTO %s (%s) VALUES (%s) ON CONFLICT (%s) DO NOTHING',
        [ATable, AColumns, AValues, AConflictColumns]);
  else
    // A2-16: 未支持的方言直接抛错——静默回退到某一方言语法会在另一
    // 引擎上报错或产生重复行，属 fail-open。
    raise EArgumentException.CreateFmt(
      'BuildInsertIgnoreSQL: unsupported SQL dialect %d for table %s ' +
      '(only SQLite and PostgreSQL emit INSERT-and-ignore-conflict)',
      [Ord(ADialect), ATable]);
  end;
end;

class function TSQLUtils.IsValidIdentifier(const AName: string): Boolean;
begin
  if (AName = '') or (AName.Length > 128) then
    Exit(False);
  // A2-11: 只用 ASCII 字符类判定（Char in 集合对 > #$FF 的 WideChar 恒 False）。
  // System.Character 的 IsLetter/IsLetterOrDigit 放行 Unicode 字母（如中文、
  // 西里尔同形字），会在“引号外拼标识符”的场合引入同形字注入面。
  // First character must be ASCII letter or underscore
  if not CharInSet(AName[1], ['A' .. 'Z', 'a' .. 'z', '_']) then
    Exit(False);
  // Remaining characters: ASCII letter, digit, or underscore
  for var I := 2 to AName.Length do
  begin
    if not CharInSet(AName[I], ['A' .. 'Z', 'a' .. 'z', '0' .. '9', '_']) then
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
  // A2-11: 补齐可终结/改写 ADD COLUMN 语义或开新语句的关键字。
  FORBIDDEN_KEYWORDS: array[0..21] of string = (
    'DROP', 'CREATE', 'ALTER', 'DELETE', 'INSERT', 'UPDATE', 'SELECT',
    'TRIGGER', 'INDEX', 'VIEW', 'ATTACH', 'DETACH', 'PRAGMA', 'VACUUM',
    'REPLACE', 'WITH', 'EXEC', 'CALL', 'BEGIN', 'COMMIT', 'GRANT', 'COPY');
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
