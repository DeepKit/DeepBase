program DoQryDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Comp.Client,
  Data.DB,
  DBClient,
  MidasLib,
  uDoQry in '..\..\src\uDoQry.pas',
  uDoQryTypes in '..\..\src\uDoQryTypes.pas',
  uDoQryErrors in '..\..\src\uDoQryErrors.pas',
  uDoQryLogger in '..\..\src\uDoQryLogger.pas',
  uDoQryDialect in '..\..\src\uDoQryDialect.pas',
  uDoQryParamPool in '..\..\src\uDoQryParamPool.pas',
  uDoQryTxManager in '..\..\src\uDoQryTxManager.pas',
  uDoQryJsonParams in '..\..\src\uDoQryJsonParams.pas',
  uDoQryExecutor in '..\..\src\uDoQryExecutor.pas';

procedure Exec;
var
  Conn: TFDConnection;
  Ctx: TDoQryContext;
  Q: TFDQuery;
  Data: TClientDataSet;
  Rows, NewId: Integer;
  Root: string;
begin
  Root := TDirectory.GetCurrentDirectory;
  DoQryInit(Root); // logs/query.log under current dir

  Conn := TFDConnection.Create(nil);
  try
    Conn.LoginPrompt := False;
    Conn.DriverName := 'SQLite';
    Conn.Params.Values['Database'] := ':memory:'; // in-memory demo
    Conn.Connected := True;

    // Prepare demo schema and query definitions
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Conn;
      Q.ExecSQL('CREATE TABLE texts (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, created_at TEXT)');
      Q.ExecSQL('CREATE TABLE queries (proc_name TEXT PRIMARY KEY, sql_template TEXT, param_schema_json TEXT, timeout_sec INTEGER, default_limit INTEGER, allow_full_scan INTEGER, id_field TEXT)');
      Q.ExecSQL('INSERT INTO queries (proc_name, sql_template, id_field, timeout_sec, default_limit, allow_full_scan) VALUES (
        ''texts.insert'', ''INSERT INTO texts (title, created_at) VALUES (:title, :created_at)'', ''id'', 30, 1000, 0)');
      Q.ExecSQL('INSERT INTO queries (proc_name, sql_template, timeout_sec, default_limit, allow_full_scan) VALUES (
        ''texts.list'', ''SELECT id, title, created_at FROM texts ORDER BY id'', 30, 1000, 0)');
    finally
      Q.Free;
    end;

    // Build context
    Ctx := DoQryMakeContext(Conn, dbSQLite, 30, DoQryNewCorrelationId);

    // Insert and get id
    NewId := DoQryExecInsertReturningId('texts.insert', '{"title":"Hello doQry","created_at":"2025-11-27T12:00:00Z"}', Ctx);
    Writeln('Inserted ID = ', NewId);

    // Select
    Data := nil;
    Rows := DoQryExecSelect('texts.list', '{}', Data, Ctx);
    try
      Writeln('Rows = ', Rows);
      if (Data <> nil) and (Rows > 0) then
      begin
        Data.First;
        while not Data.Eof do
        begin
          Writeln(Format('Row id=%s title=%s created_at=%s', [Data.FieldByName('id').AsString, Data.FieldByName('title').AsString, Data.FieldByName('created_at').AsString]));
          Data.Next;
        end;
      end;
    finally
      Data.Free;
    end;
  finally
    Conn.Free;
  end;
end;

begin
  try
    Exec;
  except
    on E: Exception do
    begin
      Writeln('Error: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
