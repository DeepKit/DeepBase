{ ============================================================================
  DeepBase.SQL.Splitter - Shared SQL statement splitter

  Version: 1.0
  Description: Single canonical SQL statement splitter shared by
               DeepBase.Manager.Schema and DeepBase.DB.Migrations.
               Handles single/double quotes, escaped quotes, line comments,
               block comments, dollar-quoted strings (PostgreSQL), and
               SQLite trigger bodies that span CREATE TRIGGER..END blocks.

  Use this instead of writing per-module ad-hoc splitters (BASIC-019).
  ============================================================================ }

unit DeepBase.SQL.Splitter;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.StrUtils;

type
  TDeepBaseSQLSplitter = class
  public
    /// <summary>
    /// Split a SQL script into individual statements. Handles:
    ///  - single/double quotes with doubled-quote escapes
    ///  - line comments (-- and //)
    ///  - block comments (slash-star ... star-slash)
    ///  - PostgreSQL dollar-quoted strings ($tag$ ... $tag$)
    ///  - SQLite/PG trigger bodies that span CREATE TRIGGER ... END
    /// </summary>
    class function Split(const SQLText: string): TArray<string>; static;
  end;

implementation

class function TDeepBaseSQLSplitter.Split(const SQLText: string): TArray<string>;
var
  Statements: TList<string>;
  Builder: TStringBuilder;
  I, J: Integer;
  Ch, NextCh: Char;
  Statement: string;
  InSingleQuote, InDoubleQuote: Boolean;
  DollarTag: string;
  InTriggerBody: Boolean;

  function IsTagChar(C: Char): Boolean;
  begin
    Result := CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
  end;

  function StartsWithCreateTrigger(const S: string): Boolean;
  var
    U: string;
  begin
    U := UpperCase(Trim(S));
    Result :=
      StartsText('CREATE TRIGGER ', U) or
      StartsText('CREATE TEMP TRIGGER ', U) or
      StartsText('CREATE TEMPORARY TRIGGER ', U);
  end;

  function EndsWithTriggerEnd(const S: string): Boolean;
  begin
    Result := EndsText('END', UpperCase(Trim(S)));
  end;

  procedure FlushStatement;
  begin
    Statement := Trim(Builder.ToString);
    if Statement <> '' then
      Statements.Add(Statement);
    Builder.Clear;
  end;

begin
  Statements := TList<string>.Create;
  Builder := TStringBuilder.Create;
  try
    I := 1;
    InSingleQuote := False;
    InDoubleQuote := False;
    DollarTag := '';
    InTriggerBody := False;

    while I <= Length(SQLText) do
    begin
      Ch := SQLText[I];
      if I < Length(SQLText) then
        NextCh := SQLText[I + 1]
      else
        NextCh := #0;

      // Inside dollar-quoted block: pass through until matching tag.
      if DollarTag <> '' then
      begin
        if Copy(SQLText, I, Length(DollarTag)) = DollarTag then
        begin
          Builder.Append(DollarTag);
          Inc(I, Length(DollarTag));
          DollarTag := '';
          Continue;
        end;
        Builder.Append(Ch);
        Inc(I);
        Continue;
      end;

      // Inside single-quoted string.
      if InSingleQuote then
      begin
        Builder.Append(Ch);
        if (Ch = '''') and (NextCh = '''') then
        begin
          Builder.Append(NextCh);
          Inc(I, 2);
          Continue;
        end;
        if Ch = '''' then
          InSingleQuote := False;
        Inc(I);
        Continue;
      end;

      // Inside double-quoted identifier.
      if InDoubleQuote then
      begin
        Builder.Append(Ch);
        if (Ch = '"') and (NextCh = '"') then
        begin
          Builder.Append(NextCh);
          Inc(I, 2);
          Continue;
        end;
        if Ch = '"' then
          InDoubleQuote := False;
        Inc(I);
        Continue;
      end;

      // Line comment -- ... \n
      if (Ch = '-') and (NextCh = '-') then
      begin
        while (I <= Length(SQLText)) and (SQLText[I] <> #10) and (SQLText[I] <> #13) do
        begin
          Builder.Append(SQLText[I]);
          Inc(I);
        end;
        Continue;
      end;

      // Block comment /* ... */
      if (Ch = '/') and (NextCh = '*') then
      begin
        Builder.Append(Ch);
        Builder.Append(NextCh);
        Inc(I, 2);
        while (I <= Length(SQLText) - 1) and
              not ((SQLText[I] = '*') and (SQLText[I + 1] = '/')) do
        begin
          Builder.Append(SQLText[I]);
          Inc(I);
        end;
        if I <= Length(SQLText) - 1 then
        begin
          Builder.Append(SQLText[I]);
          Builder.Append(SQLText[I + 1]);
          Inc(I, 2);
        end;
        Continue;
      end;

      // Begin single-quoted string
      if Ch = '''' then
      begin
        InSingleQuote := True;
        Builder.Append(Ch);
        Inc(I);
        Continue;
      end;

      // Begin double-quoted identifier
      if Ch = '"' then
      begin
        InDoubleQuote := True;
        Builder.Append(Ch);
        Inc(I);
        Continue;
      end;

      // Begin dollar-quoted block: $[tag]$
      if Ch = '$' then
      begin
        J := I + 1;
        while (J <= Length(SQLText)) and IsTagChar(SQLText[J]) do
          Inc(J);
        if (J <= Length(SQLText)) and (SQLText[J] = '$') then
        begin
          DollarTag := Copy(SQLText, I, J - I + 1);
          Builder.Append(DollarTag);
          Inc(I, Length(DollarTag));
          Continue;
        end;
      end;

      // Statement separator (outside strings/comments/triggers)
      if (Ch = ';') and not InTriggerBody then
      begin
        if StartsWithCreateTrigger(Builder.ToString) then
        begin
          // Trigger statements span until END;
          InTriggerBody := True;
          Builder.Append(Ch);
          Inc(I);
          Continue;
        end;
        FlushStatement;
        Inc(I);
        Continue;
      end;

      if (Ch = ';') and InTriggerBody then
      begin
        Builder.Append(Ch);
        if EndsWithTriggerEnd(Copy(Builder.ToString, 1, Builder.Length - 1)) then
        begin
          FlushStatement;
          InTriggerBody := False;
        end;
        Inc(I);
        Continue;
      end;

      Builder.Append(Ch);
      Inc(I);
    end;

    FlushStatement;
    Result := Statements.ToArray;
  finally
    Builder.Free;
    Statements.Free;
  end;
end;

end.
