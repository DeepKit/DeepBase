unit uDoQryDialect;

interface

uses
  System.SysUtils, System.StrUtils, uDoQryTypes;

function QuoteIdent(const Name: string; DBType: TDBType): string;
function ApplyLimitOffset(const SQL: string; Limit, Offset: Integer; DBType: TDBType): string;
function EnsureReturningId(const SQL: string; const IdField: string; DBType: TDBType): string;
function NeedsLastInsertRowId(DBType: TDBType): Boolean;

implementation

function QuoteIdent(const Name: string; DBType: TDBType): string;
begin
  Result := '"' + Name.Replace('"', '""') + '"';
end;

function HasLimitClause(const SQL: string): Boolean;
begin
  Result := PosText(' LIMIT ', ' ' + SQL + ' ') > 0;
end;

function ApplyLimitOffset(const SQL: string; Limit, Offset: Integer; DBType: TDBType): string;
var
  S: string;
begin
  S := Trim(SQL);
  if Limit > 0 then
  begin
    if not HasLimitClause(S) then
    begin
      S := S + Format(' LIMIT %d', [Limit]);
      if Offset > 0 then
        S := S + Format(' OFFSET %d', [Offset]);
    end;
  end;
  Result := S;
end;

function EnsureReturningId(const SQL: string; const IdField: string; DBType: TDBType): string;
var
  S: string;
begin
  S := TrimRight(SQL);
  case DBType of
    dbPostgreSQL:
      begin
        if PosText(' RETURNING ', S) = 0 then
          S := S + ' RETURNING ' + IdField;
      end;
    dbSQLite:
      begin
        // SQLite 不支持 RETURNING（老版本）。在执行器中通过 last_insert_rowid() 获取
      end;
  end;
  Result := S;
end;

function NeedsLastInsertRowId(DBType: TDBType): Boolean;
begin
  Result := DBType = dbSQLite;
end;

end.
