unit uDoQryExecutor;

interface

uses
  System.SysUtils, System.Classes, System.StrUtils, System.JSON, System.Variants, Winapi.Windows,
  Data.DB, DBClient,
  FireDAC.Comp.Client, FireDAC.Stan.Param, FireDAC.Stan.Option,
  uDoQryTypes, uDoQryErrors, uDoQryParamPool, uDoQryDialect,
  uDoQryLogger, uDoQryJsonParams, uDoQryTxManager,
  UniBase.Exceptions;

function ExecSelect(const Proc: string; const ParamsJson: string; var Data: TClientDataSet; const Ctx: TDoQryContext): Integer;
function ExecNonQuery(const Proc: string; const ParamsJson: string; const Ctx: TDoQryContext): Integer;
function ExecInsertReturningId(const Proc: string; const ParamsJson: string; const Ctx: TDoQryContext): Integer;
function ExecScalar(const Proc: string; const ParamsJson: string; const Ctx: TDoQryContext): Variant;
function BuildSqlPreview(const Proc: string; const ParamsJson: string; const Ctx: TDoQryContext): string;

implementation

type
  TInExp = record
    Name: string;
    Count: Integer;
  end;

function IsSelectSQL(const S: string): Boolean;
var T: string;
begin
  T := TrimLeft(S);
  Result := StartsText('select', T);
end;

function IsUpdateOrDelete(const S: string): Boolean;
var T: string;
begin
  T := TrimLeft(S).ToLower;
  Result := StartsText('update ', T) or StartsText('delete ', T);
end;

function HasWhere(const S: string): Boolean;
begin
  Result := Pos(' where ', LowerCase(' ' + S + ' ')) > 0;
end;

function ExpandInPlaceholders(const SQL: string; Params: TJSONObject; out Expanded: TArray<TInExp>): string;
var
  OutSQL: string;
  p1, p2: Integer;
  Name: string;
  JArr: TJSONArray;
  i: Integer;
  Placeholders: TStringList;
  rec: TInExp;
begin
  OutSQL := SQL;
  SetLength(Expanded, 0);
  while True do
  begin
    p1 := Pos('{in:', OutSQL);
    if p1 = 0 then Break;
    p2 := PosEx('}', OutSQL, p1+4);
    if p2 = 0 then Break;
    Name := Trim(Copy(OutSQL, p1 + 4, p2 - (p1 + 4)));
    if not Assigned(Params) or (Params.GetValue(Name) = nil) or not (Params.GetValue(Name) is TJSONArray) then
      raise EDatabaseException.CreateFmt('IN 参数 %s 缺失或不是数组', [Name]);
    JArr := TJSONArray(Params.GetValue(Name));
    if JArr.Count = 0 then
      raise EDatabaseException.CreateFmt('IN 参数 %s 不能为空数组', [Name]);
    Placeholders := TStringList.Create;
    try
      Placeholders.Delimiter := ',';
      Placeholders.StrictDelimiter := True;
      for i := 0 to JArr.Count - 1 do
        Placeholders.Add(':' + Name + '_' + IntToStr(i+1));
      rec.Name := Name;
      rec.Count := JArr.Count;
      Expanded := Expanded + [rec];
      OutSQL := Copy(OutSQL, 1, p1-1) + '(' + Placeholders.CommaText + ')' + Copy(OutSQL, p2+1, MaxInt);
    finally
      Placeholders.Free;
    end;
  end;
  Result := OutSQL;
end;

procedure BindParams(Q: TFDQuery; Params: TJSONObject; const InExp: TArray<TInExp>);
var
  Pair: TJSONPair;
  PName: string;
  Val: TJSONValue;
  I, N: Integer;
  Arr: TJSONArray;
  Param: TFDParam;
  DT: TDateTime;
begin
  if not Assigned(Params) then Exit;
  for Pair in Params do
  begin
    PName := Pair.JsonString.Value;
    Val := Pair.JsonValue;
    if Val is TJSONArray then
    begin
      // Only bind if there is an IN expansion generated
      for I := 0 to High(InExp) do
        if SameText(InExp[I].Name, PName) then
        begin
          Arr := TJSONArray(Val);
          for N := 0 to Arr.Count - 1 do
          begin
            Param := Q.ParamByName(PName + '_' + IntToStr(N+1));
            if Arr.Items[N] is TJSONNull then
              Param.Clear
            else if Arr.Items[N] is TJSONNumber then
              Param.AsFloat := TJSONNumber(Arr.Items[N]).AsDouble
            else if Arr.Items[N] is TJSONBool then
              Param.AsBoolean := TJSONBool(Arr.Items[N]).AsBoolean
            else // string or object
            begin
              if Arr.Items[N] is TJSONString then
              begin
                if TryAsISODateTime(TJSONString(Arr.Items[N]).Value, DT) then
                  Param.AsDateTime := DT
                else
                  Param.AsString := TJSONString(Arr.Items[N]).Value;
              end
              else
                Param.AsString := Arr.Items[N].ToJSON;
            end;
          end;
          Break;
        end;
    end
    else
    begin
      Param := Q.ParamByName(PName);
      if Val is TJSONNull then
        Param.Clear
      else if Val is TJSONNumber then
        Param.AsFloat := TJSONNumber(Val).AsDouble
      else if Val is TJSONBool then
        Param.AsBoolean := TJSONBool(Val).AsBoolean
      else if Val is TJSONString then
      begin
        if TryAsISODateTime(TJSONString(Val).Value, DT) then
          Param.AsDateTime := DT
        else
          Param.AsString := TJSONString(Val).Value;
      end
      else // object
        Param.AsString := Val.ToJSON;
    end;
  end;
end;

procedure CopyToClientDataSet(Src: TFDQuery; Dest: TClientDataSet);
var
  I: Integer;
  F: TField;
begin
  Dest.Close;
  Dest.FieldDefs.Clear;
  for I := 0 to Src.Fields.Count - 1 do
  begin
    F := Src.Fields[I];
    Dest.FieldDefs.Add(F.FieldName, F.DataType, F.Size, F.Required);
  end;
  Dest.CreateDataSet;
  Src.First;
  while not Src.Eof do
  begin
    Dest.Append;
    for I := 0 to Src.Fields.Count - 1 do
      if not Src.Fields[I].IsNull then
        Dest.Fields[I].Value := Src.Fields[I].Value
      else
        Dest.Fields[I].Clear;
    Dest.Post;
    Src.Next;
  end;
end;

function CompileSQL(const Def: TQueryDef; const Params: TJSONObject; const Ctx: TDoQryContext; const ForInsertId: Boolean; out InExp: TArray<TInExp>): string;
var
  S: string;
begin
  S := Def.SQLTemplate;
  if S.Trim = '' then
    raise EDatabaseException.CreateFmt('查询 %s 缺少 sql_template', [Def.ProcName]);
  // Expand IN placeholders
  S := ExpandInPlaceholders(S, Params, InExp);
  // Add default limit for SELECT
  if IsSelectSQL(S) and (Def.DefaultLimit > 0) then
    S := ApplyLimitOffset(S, Def.DefaultLimit, 0, Ctx.DBType);
  // Ensure INSERT returning id
  if ForInsertId then
    S := EnsureReturningId(S, Def.IdField, Ctx.DBType);
  Result := S;
end;

function ExecSelect(const Proc: string; const ParamsJson: string; var Data: TClientDataSet; const Ctx: TDoQryContext): Integer;
var
  Def: TQueryDef;
  Params: TJSONObject;
  Q: TFDQuery;
  SQL: string;
  t0: Int64;
  InExp: TArray<TInExp>;
begin
  Def := GetQueryDef(Ctx, Proc);
  Params := ParseParamsJson(ParamsJson);
  try
    try
      SQL := CompileSQL(Def, Params, Ctx, False, InExp);
      Q := TFDQuery.Create(nil);
      try
        Q.Connection := Ctx.Connection;
        if Def.TimeoutSec > 0 then
          Q.ResourceOptions.CmdExecTimeout := Def.TimeoutSec
        else
          Q.ResourceOptions.CmdExecTimeout := Ctx.TimeoutSec;
        Q.SQL.Text := SQL;
        BindParams(Q, Params, InExp);
        t0 := GetTickCount64;
        Q.Open;
        if Data = nil then
          Data := TClientDataSet.Create(nil);
        CopyToClientDataSet(Q, Data);
        Result := Q.RecordCount;
        DoQryLogEvent('INFO', Ctx.CorrelationId, Proc, Ctx.DBType, 'select', SQL, ParamsJson, GetTickCount64 - t0, Result, '');
      finally
        Q.Free;
      end;
    except
      on E: Exception do
      begin
        DoQryLogEvent('ERROR', Ctx.CorrelationId, Proc, Ctx.DBType, 'select', SQL, ParamsJson, 0, -1, E.Message);
        raise EDoQryError.Create('Select 执行失败: ' + E.Message, Proc, SQL, ParamsJson, Ctx.DBType, Ctx.CorrelationId);
      end;
    end;
  finally
    Params.Free;
  end;
end;

procedure GuardNonQuery(const SQL: string; const Def: TQueryDef);
begin
  if IsUpdateOrDelete(SQL) and (not Def.AllowFullScan) and (not HasWhere(SQL)) then
    raise EDatabaseException.Create('非查询语句缺少 WHERE，已阻止执行');
end;

function ExecNonQuery(const Proc: string; const ParamsJson: string; const Ctx: TDoQryContext): Integer;
var
  Def: TQueryDef;
  Params: TJSONObject;
  Q: TFDQuery;
  SQL: string;
  t0: Int64;
  InExp: TArray<TInExp>;
  Tx: IDoQryTx;
begin
  Def := GetQueryDef(Ctx, Proc);
  Params := ParseParamsJson(ParamsJson);
  try
    try
      SQL := CompileSQL(Def, Params, Ctx, False, InExp);
      GuardNonQuery(SQL, Def);
      Q := TFDQuery.Create(nil);
      try
        Q.Connection := Ctx.Connection;
        if Def.TimeoutSec > 0 then
          Q.ResourceOptions.CmdExecTimeout := Def.TimeoutSec
        else
          Q.ResourceOptions.CmdExecTimeout := Ctx.TimeoutSec;
        Q.SQL.Text := SQL;
        BindParams(Q, Params, InExp);
        if not Ctx.Connection.InTransaction then
          Tx := uDoQryTxManager.StartTx(Ctx);
        t0 := GetTickCount64;
        Q.ExecSQL;
        Result := Q.RowsAffected;
        if Assigned(Tx) then Tx.Commit;
        DoQryLogEvent('INFO', Ctx.CorrelationId, Proc, Ctx.DBType, 'nonquery', SQL, ParamsJson, GetTickCount64 - t0, Result, '');
      finally
        Q.Free;
      end;
    except
      on E: Exception do
      begin
        if Assigned(Tx) then Tx.Rollback;
        DoQryLogEvent('ERROR', Ctx.CorrelationId, Proc, Ctx.DBType, 'nonquery', SQL, ParamsJson, 0, -1, E.Message);
        raise EDoQryError.Create('NonQuery 执行失败: ' + E.Message, Proc, SQL, ParamsJson, Ctx.DBType, Ctx.CorrelationId);
      end;
    end;
  finally
    Params.Free;
  end;
end;

function ExecInsertReturningId(const Proc: string; const ParamsJson: string; const Ctx: TDoQryContext): Integer;
var
  Def: TQueryDef;
  Params: TJSONObject;
  Q: TFDQuery;
  SQL: string;
  t0: Int64;
  InExp: TArray<TInExp>;
  Tx: IDoQryTx;
  Q2: TFDQuery;
begin
  Def := GetQueryDef(Ctx, Proc);
  Params := ParseParamsJson(ParamsJson);
  try
    try
      SQL := CompileSQL(Def, Params, Ctx, True, InExp);
      Q := TFDQuery.Create(nil);
      try
        Q.Connection := Ctx.Connection;
        if Def.TimeoutSec > 0 then
          Q.ResourceOptions.CmdExecTimeout := Def.TimeoutSec
        else
          Q.ResourceOptions.CmdExecTimeout := Ctx.TimeoutSec;
        Q.SQL.Text := SQL;
        BindParams(Q, Params, InExp);
        if not Ctx.Connection.InTransaction then
          Tx := uDoQryTxManager.StartTx(Ctx);
        t0 := GetTickCount64;
        if Ctx.DBType = dbPostgreSQL then
        begin
          Q.Open;
          if (Q.Fields.Count = 0) or Q.IsEmpty then
            raise EDatabaseException.Create('未返回插入 ID');
          Result := Q.Fields[0].AsInteger;
        end
        else
        begin
          Q.ExecSQL;
          Q2 := TFDQuery.Create(nil);
          try
            Q2.Connection := Ctx.Connection;
            Q2.SQL.Text := 'SELECT last_insert_rowid() AS id';
            Q2.Open;
            Result := Q2.FieldByName('id').AsInteger;
          finally
            Q2.Free;
          end;
        end;
        if Assigned(Tx) then Tx.Commit;
        DoQryLogEvent('INFO', Ctx.CorrelationId, Proc, Ctx.DBType, 'insert', SQL, ParamsJson, GetTickCount64 - t0, 1, '');
      finally
        Q.Free;
      end;
    except
      on E: Exception do
      begin
        if Assigned(Tx) then Tx.Rollback;
        DoQryLogEvent('ERROR', Ctx.CorrelationId, Proc, Ctx.DBType, 'insert', SQL, ParamsJson, 0, -1, E.Message);
        raise EDoQryError.Create('Insert 执行失败: ' + E.Message, Proc, SQL, ParamsJson, Ctx.DBType, Ctx.CorrelationId);
      end;
    end;
  finally
    Params.Free;
  end;
end;

function ExecScalar(const Proc: string; const ParamsJson: string; const Ctx: TDoQryContext): Variant;
var
  Def: TQueryDef;
  Params: TJSONObject;
  Q: TFDQuery;
  SQL: string;
  t0: Int64;
  InExp: TArray<TInExp>;
begin
  Def := GetQueryDef(Ctx, Proc);
  Params := ParseParamsJson(ParamsJson);
  try
    try
      SQL := CompileSQL(Def, Params, Ctx, False, InExp);
      Q := TFDQuery.Create(nil);
      try
        Q.Connection := Ctx.Connection;
        if Def.TimeoutSec > 0 then
          Q.ResourceOptions.CmdExecTimeout := Def.TimeoutSec
        else
          Q.ResourceOptions.CmdExecTimeout := Ctx.TimeoutSec;
        Q.SQL.Text := SQL;
        BindParams(Q, Params, InExp);
        t0 := GetTickCount64;
        Q.Open;
        if Q.IsEmpty or (Q.Fields.Count = 0) then
          Result := Null
        else
          Result := Q.Fields[0].Value;
        DoQryLogEvent('INFO', Ctx.CorrelationId, Proc, Ctx.DBType, 'scalar', SQL, ParamsJson, GetTickCount64 - t0, 1, '');
      finally
        Q.Free;
      end;
    except
      on E: Exception do
      begin
        DoQryLogEvent('ERROR', Ctx.CorrelationId, Proc, Ctx.DBType, 'scalar', SQL, ParamsJson, 0, -1, E.Message);
        raise EDoQryError.Create('Scalar 执行失败: ' + E.Message, Proc, SQL, ParamsJson, Ctx.DBType, Ctx.CorrelationId);
      end;
    end;
  finally
    Params.Free;
  end;
end;

function BuildSqlPreview(const Proc: string; const ParamsJson: string; const Ctx: TDoQryContext): string;
var
  Def: TQueryDef;
  Params: TJSONObject;
  InExp: TArray<TInExp>;
begin
  Def := GetQueryDef(Ctx, Proc);
  Params := ParseParamsJson(ParamsJson);
  try
    Result := CompileSQL(Def, Params, Ctx, False, InExp);
  finally
    Params.Free;
  end;
end;

end.
