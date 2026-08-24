unit uDoQryLegacy;

interface

uses
  System.SysUtils, System.Variants, System.Classes, System.Generics.Collections,
  System.Generics.Defaults,
  FireDAC.Stan.Intf, ADODB, Data.DB, DBClient,Winapi.Windows,
  StrUtils, Vcl.Dialogs,
  DeepBase.Exceptions;

//  run_type ö
type
  TRunType = (rtSelect, rtUpdate, rtDelete, rtInsert, rtCall);
  TParaType = (ptString, ptInteger, ptFloat, ptDate, ptBoolean);
  TDatabaseType = (dtUnknown, dtMySQL, dtPostgreSQL, dtSQLServer, dtOracle, dtSQLite);

// 在interface部分声明所有需要的函数
function SplitParamString(const ParamString: string): TStringList;
function BuildSQL(qry: TAdoQuery; const ParamStr: string): string; overload;
function BuildSQL(qry: TAdoQuery; const Params: TDictionary<string, string>): string;    overload;
function ShowCurrRecord(aDataset: TDataset; field_num:Integer = 5): String;
function ParseParamString(const paramStr: string; out paramName, paramValue: string): Boolean;

// �?interface 部分添加以下函数声明
function BuildWhereClauseFromDict(qry: TAdoQuery; const Params: TDictionary<string, string>): string;
function QuoteValue(const Value: string): string;
function IsWhereField(const FieldName: string; qry: TAdoQuery; const ProcName: string = ''): Boolean;

// 同时�?interface 部分添加这些函数的声�?
function BuildSelectSQL(qry: TAdoQuery; const Params: TDictionary<string, string>): string;
function BuildUpdateSQL(qry: TAdoQuery; const Params: TDictionary<string, string>): string;
function BuildDeleteSQL(qry: TAdoQuery; const Params: TDictionary<string, string>): string;
function BuildInsertSQL(qry: TAdoQuery; const Params: TDictionary<string, string>): string;
function BuildCallSQL(qry: TAdoQuery; const Params: TDictionary<string, string>): string;

// �?interface 部分添加新的函数声明
function doQry(const ProcName: String; aQry: TAdoQuery; const ParamString: string=''): Integer; overload;
function doQry(const ProcName: String; aQry: TAdoQuery; var msg: string; const ParamString:string): Integer; overload;
//Ms级参数用于返回执行的结果。经常用于出错�?
//返回值说明：如果是选择状态返回选择到多少记录，如果是插入状态返回。最新插入记录的ID。如果是修改和更新状态返回影响到的行�?

implementation

// 内部使用的函数声�?
function StringToParams(const ParamStr: string): TDictionary<string, string>; forward;
procedure ValidateSQL(const SQL: string); forward;
function GetQueryDef(Connection: TADOConnection; const ProcName: string): TADOQuery; forward;
function ExecuteSQL(Connection: TADOConnection; const SQL: string): TDataSet; forward;
procedure DataSetToClientDataSet(Source: TDataSet; Dest: TClientDataSet); forward;

function ValidateSQLQuotes(const SQL: string): Boolean;
var
  i: Integer;
  inSingleQuote: Boolean;
begin
  inSingleQuote := False;

  for i := 1 to Length(SQL) do
  begin
    if CharInSet(SQL[i], ['''']) then
      inSingleQuote := not inSingleQuote;
  end;

  // 如果最终inSingleQuote为true，表示引号不匹配
  Result := not inSingleQuote;
end;

function GetPrimaryKeyFieldName(aQry: TAdoQuery; TableName: string; DatabaseType: TDatabaseType): string;
begin
  Result := '';
  with aQry do
  begin
    Close;
    SQL.Clear;

    // �������ݿ����͹�����ͬ��Ԫ���ݲ�ѯ���?
    case DatabaseType of
      dtMySQL:
        begin
          SQL.Add('SELECT COLUMN_NAME');
          SQL.Add('FROM INFORMATION_SCHEMA.COLUMNS');
          SQL.Add('WHERE TABLE_NAME = :TableName AND COLUMN_KEY = ''PRI''');
          Parameters.ParamByName('TableName').Value := TableName;
        end;
      dtPostgreSQL:
        begin
          SQL.Add('SELECT c.column_name');
          SQL.Add('FROM information_schema.table_constraints tc');
          SQL.Add('JOIN information_schema.constraint_column_usage ccu');
          SQL.Add('  ON tc.constraint_name = ccu.constraint_name');
          SQL.Add('  AND tc.table_schema = ccu.table_schema');
          SQL.Add('JOIN information_schema.columns c');
          SQL.Add('  ON c.table_schema = tc.table_schema');
          SQL.Add('  AND c.table_name = tc.table_name');
          SQL.Add('  AND c.column_name = ccu.column_name');
          SQL.Add('WHERE tc.constraint_type = ''PRIMARY KEY''');
          SQL.Add('  AND tc.table_name = :TableName');
          Parameters.ParamByName('TableName').Value := TableName;
        end;
      dtSQLServer:
        begin
          SQL.Add('SELECT COLUMN_NAME');
          SQL.Add('FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE');
          SQL.Add('WHERE TABLE_NAME = :TableName AND CONSTRAINT_NAME LIKE ''PK_%''');
          Parameters.ParamByName('TableName').Value := TableName;
        end;
      dtOracle:
        begin
          SQL.Add('SELECT cols.column_name');
          SQL.Add('FROM all_constraints cons, all_cons_columns cols');
          SQL.Add('WHERE cons.constraint_type = ''P''');
          SQL.Add('  AND cons.constraint_name = cols.constraint_name');
          SQL.Add('  AND cols.table_name = :TableName');
          Parameters.ParamByName('TableName').Value := TableName;
        end;
      dtSQLite:
        begin
          SQL.Add('SELECT name');
          SQL.Add('FROM pragma_table_info(:TableName)');
          SQL.Add('WHERE pk = 1');
          Parameters.ParamByName('TableName').Value := TableName;
        end;
    else
      raise EDatabaseException.Create('不支持的数据库类型');
    end;

    // ִвѯ
    Open;

    // ��ȡ�����ֶ���
    if not IsEmpty then
      Result := FieldByName('column_name').AsString;

    Close;
  end;

  if Result = '' then
    raise EDatabaseException.Create('无法获取表 ' + TableName + ' 的主键字段名');
end;

function GetDatabaseType(Conn: TAdoConnection): TDatabaseType;
var
  Driver: string;
begin
  Driver := LowerCase(Conn.ConnectionString);
  if Pos('mysql', Driver) > 0 then
    Result := dtMySQL
  else if Pos('postgre', Driver) > 0 then
    Result := dtPostgreSQL
  else if Pos('sqlserver', Driver) > 0 then
    Result := dtSQLServer
  else if Pos('oracle', Driver) > 0 then
    Result := dtOracle
  else if Pos('sqlite', Driver) > 0 then
    Result := dtSQLite
  else
    Result := dtUnknown;
end;

function StringToRunType(const runType: string): TRunType;
var
  lowerRunType: string;
begin
  lowerRunType := LowerCase(runType);

  if lowerRunType = 'select' then
    Result := rtSelect
  else if lowerRunType = 'update' then
    Result := rtUpdate
  else if lowerRunType = 'delete' then
    Result := rtDelete
  else if lowerRunType = 'insert' then
    Result := rtInsert
  else if lowerRunType = 'call' then
    Result := rtCall
  else
    raise EDatabaseException.Create('不支持的 run_type: ' + runType);
end;

function StringToParaType(const paraType: string): TParaType;
begin
  if paraType = 'string' then
    Result := ptString
  else if (paraType = 'integer') then
    Result := ptInteger
  else if (paraType = 'float') then
    Result := ptFloat
  else if paraType = 'date' then
    Result := ptDate
  else if paraType = 'boolean' then
    Result := ptBoolean
  else
    raise EDatabaseException.Create('不支持的参数类型: ' + paraType);
end;

function ShowCurrRecord(aDataset: TDataset;field_num:Integer = 5): String;
var
  i: Integer;
  FieldValue: string;
  ResultStr: string; // ƴӽַ
begin
  // ݼǷѴ
  if not aDataset.Active then
    raise EDatabaseException.Create('数据集未打开');

  // ʼַ
  ResultStr := '';

  // ǰ5ֶ
  for i := 0 to aDataset.FieldCount - 1 do
  begin
    if i >= field_num then
      Break; // ֻǰ5ֶ

    // ƴֵֶֶ
    FieldValue := aDataset.Fields[i].FieldName + ': ' + aDataset.Fields[i].AsString;

    // ǰֶϢӵַ
    if ResultStr <> '' then
      ResultStr := ResultStr + sLineBreak; // ӻз
    ResultStr := ResultStr + FieldValue;
  end;

  // ƴӺַ
  Result := ResultStr;
end;

function BoolToPostgreSQL(Value: Boolean): string;
begin
  if Value then
    Result := 'TRUE'
  else
    Result := 'FALSE';
end;

function HandleParamValue(paramType: string; value: string): string;
var
  LInt: Int64;
  LFloat: Double;
  FSI: TFormatSettings;
begin
  // 如果值为空，返回 NULL
  if value = '' then
    Result := 'NULL'
  else
  begin
    FSI := TFormatSettings.Invariant;
    case StringToParaType(paramType) of
      ptString:
        Result := QuotedStr(StringReplace(value, '''', '''''', [rfReplaceAll]));
      ptInteger:
        begin
          // CR-006: 数值类型不再原样拼接，先严格校验，杜绝注入通道
          if not TryStrToInt64(Trim(value), LInt) then
            raise EDatabaseException.Create('非法的整型参数值: ' + value);
          Result := IntToStr(LInt);
        end;
      ptFloat:
        begin
          if not TryStrToFloat(Trim(value), LFloat, FSI) then
            raise EDatabaseException.Create('非法的浮点参数值: ' + value);
          Result := FloatToStr(LFloat, FSI);
        end;
      ptDate:
        Result := QuotedStr(FormatDateTime('yyyy-mm-dd', StrToDate(value)));
      ptBoolean:
        Result := BoolToPostgreSQL(StrToBool(value));
    end;
  end;
end;

function BuildWhereClause(qry: TAdoQuery; qryParams: TDataSet): string;
var
  firstWhere: Boolean;
  nextLogicOperator: string;
  bookmark: TBookmark;
begin
  Result := '';
  firstWhere := True;
  nextLogicOperator := 'AND';

  bookmark := qryParams.GetBookmark;
  try
    qryParams.First;
    while not qryParams.Eof do
    begin
      // 只处理有值的where条件
      if (qryParams.FieldByName('is_where').AsInteger = 1) and 
         not qryParams.FieldByName('para_value').IsNull then
      begin
        if not firstWhere then
          Result := Result + ' ' + nextLogicOperator + ' '
        else
          firstWhere := False;

        Result := Result + qryParams.FieldByName('para_name').AsString + ' = ' +
                 HandleParamValue(qryParams.FieldByName('para_type').AsString, 
                                qryParams.FieldByName('para_value').AsString);

        nextLogicOperator := qryParams.FieldByName('and_or').AsString;
        if nextLogicOperator = '' then
          nextLogicOperator := 'AND';
      end;
      qryParams.Next;
    end;
  finally
    if qryParams.BookmarkValid(bookmark) then
    begin
      qryParams.GotoBookmark(bookmark);
      qryParams.FreeBookmark(bookmark);
    end;
  end;
end;

function BuildSelectSQL(qry: TAdoQuery; const Params: TDictionary<string, string>): string;
var
  tableName, whereClause, orderBy: string;
  limits: Integer;
begin
  tableName := qry.FieldByName('table_name').AsString;
  Result := 'SELECT * FROM ' + tableName;
  
  // 构建 WHERE 子句
  whereClause := BuildWhereClauseFromDict(qry, Params);
  OutputDebugString(PChar('Select WHERE clause: ' + whereClause));
  
  if whereClause <> '' then
    Result := Result + ' WHERE ' + whereClause;

  // 添加排序
  orderBy := qry.FieldByName('order_by').AsString;
  if orderBy <> '' then
    Result := Result + ' ORDER BY ' + orderBy;

  // 添加限制 - 如果没有设置，默�?000
  limits := qry.FieldByName('limits').AsInteger;
  if limits <= 0 then
    limits := 1000;
  Result := Result + ' LIMIT ' + IntToStr(limits);

  // 输出最终的 SQL
  OutputDebugString(PChar('Final SELECT SQL: ' + Result));
end;

function BuildDeleteSQL(qry: TAdoQuery; const Params: TDictionary<string, string>): string;
var
  tableName, whereClause: string;
begin
  tableName := qry.FieldByName('table_name').AsString;
  Result := 'DELETE FROM ' + tableName;
  
  whereClause := BuildWhereClauseFromDict(qry, Params);
  if whereClause = '' then
    // CR-007: 与 BuildUpdateSQL 对齐——禁止无 WHERE 的全表删除
    raise EDatabaseException.Create('删除操作必须包含WHERE条件');
  Result := Result + ' WHERE ' + whereClause;
end;

function BuildCallSQL(qry: TAdoQuery; const Params: TDictionary<string, string>): string;
var
  procName, paramsStr: string;
  pair: TPair<string, string>;
  firstParam: Boolean;
begin
  procName := qry.FieldByName('proc_name').AsString;
  Result := 'CALL ' + procName + '(';
  
  paramsStr := '';
  firstParam := True;
  
  for pair in Params do
  begin
    if not firstParam then
      paramsStr := paramsStr + ', '
    else
      firstParam := False;

    paramsStr := paramsStr + QuoteValue(pair.Value);
  end;

  Result := Result + paramsStr + ')';
end;

function BuildUpdateSQL(qry: TAdoQuery; const Params: TDictionary<string, string>): string;
var
  tableName, setClause, whereClause, procName: string;
  qryParams: TAdoQuery;
  orderedFields: TDictionary<string, Integer>;
  sortedFields: TList<TPair<string, string>>;
  fieldOrder: array of Integer;
  i, j, tempOrder: Integer;
  tempField: string;
  pair: TPair<string, string>;
begin
  tableName := qry.FieldByName('table_name').AsString;
  procName := qry.FieldByName('proc_name').AsString;
  setClause := '';
  
  // 创建用于存储字段顺序的字�?
  orderedFields := TDictionary<string, Integer>.Create;
  sortedFields := TList<TPair<string, string>>.Create;
  
  try
    // 获取字段顺序信息
    qryParams := TAdoQuery.Create(nil);
    try
      qryParams.Connection := qry.Connection;
      qryParams.SQL.Text := 'SELECT para_name, para_order FROM query_parameters WHERE proc_name = :ProcName ORDER BY para_order';
      qryParams.Parameters.ParamByName('ProcName').Value := procName;
      qryParams.Open;
      
      // 将字段顺序信息存入字�?
      while not qryParams.Eof do
      begin
        orderedFields.Add(qryParams.FieldByName('para_name').AsString, 
                          qryParams.FieldByName('para_order').AsInteger);
        qryParams.Next;
      end;
    finally
      qryParams.Free;
    end;
    
    // 处理要更新的字段
    for pair in Params do
    begin
      if not IsWhereField(pair.Key, qry, procName) then
      begin
        sortedFields.Add(TPair<string, string>.Create(pair.Key, pair.Value));
      end;
    end;
    
    // 设置排序顺序数组
    SetLength(fieldOrder, sortedFields.Count);
    for i := 0 to sortedFields.Count - 1 do
    begin
      if orderedFields.ContainsKey(sortedFields[i].Key) then
        fieldOrder[i] := orderedFields[sortedFields[i].Key]
      else
        fieldOrder[i] := High(Integer); // 对于没有定义顺序的字段，给一个很大的顺序�?
    end;
    
    // 简单的冒泡排序
    for i := 0 to sortedFields.Count - 2 do
      for j := 0 to sortedFields.Count - i - 2 do
        if fieldOrder[j] > fieldOrder[j + 1] then
        begin
          // 交换顺序
          tempOrder := fieldOrder[j];
          fieldOrder[j] := fieldOrder[j + 1];
          fieldOrder[j + 1] := tempOrder;
          
          // 交换相应的字�?
          tempField := sortedFields[j].Key;
          sortedFields[j] := TPair<string, string>.Create(sortedFields[j + 1].Key, 
                                                         sortedFields[j + 1].Value);
          sortedFields[j + 1] := TPair<string, string>.Create(tempField, 
                                                             Params[tempField]);
        end;
    
    // 生成排序后的SET子句
    for i := 0 to sortedFields.Count - 1 do
    begin
      if i > 0 then
        setClause := setClause + ', ';
      
      setClause := setClause + sortedFields[i].Key + ' = ' + QuoteValue(sortedFields[i].Value);
    end;
    
    if setClause = '' then
      raise EDatabaseException.Create('没有找到任何字段用于更新');
    
    // 构建WHERE子句
    whereClause := BuildWhereClauseFromDict(qry, Params);
    if whereClause = '' then
      raise EDatabaseException.Create('更新操作必须包含WHERE条件');
    
    Result := Format('UPDATE %s SET %s WHERE %s', 
      [tableName, setClause, whereClause]);
      
  finally
    orderedFields.Free;
    sortedFields.Free;
  end;
end;

function BuildInsertSQL(qry: TAdoQuery; const Params: TDictionary<string, string>): string;
var
  tableName, fieldNames, fieldValues: string;
  fieldList: TStringList;
  defaultValues: TDictionary<string, string>;
  procName: string;
  paramQry: TADOQuery;
  i: Integer;
  fieldName: string;
begin
  // 获取表名和过程名
  tableName := qry.FieldByName('table_name').AsString;
  procName := qry.FieldByName('proc_name').AsString;
  
  // 获取所有参数名和默认�?
  fieldList := TStringList.Create;
  defaultValues := TDictionary<string, string>.Create;
  paramQry := TADOQuery.Create(nil);
  try
    paramQry.Connection := qry.Connection;
    // 从query_parameters表中获取所有参数和默认值，按para_order排序
    paramQry.SQL.Text := 'SELECT para_name, para_value FROM query_parameters WHERE proc_name = :proc_name ORDER BY para_order';
    paramQry.Parameters.ParamByName('proc_name').Value := procName;
    paramQry.Open;
    
    while not paramQry.Eof do
    begin
      fieldName := paramQry.FieldByName('para_name').AsString;
      fieldList.Add(fieldName);
      
      // 先存储默认�?
      if not paramQry.FieldByName('para_value').IsNull then
        defaultValues.Add(fieldName, paramQry.FieldByName('para_value').AsString);
        
      // 如果参数表中有值，则覆盖默认�?
      if Params.ContainsKey(fieldName) then
        defaultValues.AddOrSetValue(fieldName, Params[fieldName]);
        
      paramQry.Next;
    end;
    
    // 构建字段名列表和值列�?
    fieldNames := '';
    fieldValues := '';
    for i := 0 to fieldList.Count - 1 do
    begin
      if i > 0 then
      begin
        fieldNames := fieldNames + ', ';
        fieldValues := fieldValues + ', ';
      end;
      
      fieldName := fieldList[i];
      fieldNames := fieldNames + fieldName;
      
      // 使用最终的值（默认值或被参数覆盖的值）
      if defaultValues.ContainsKey(fieldName) then
        fieldValues := fieldValues + QuoteValue(defaultValues[fieldName])
      else
        fieldValues := fieldValues + 'NULL';
    end;
    
    if fieldNames = '' then
      raise EDatabaseException.Create('没有找到任何字段用于插入');
    
    Result := Format('INSERT INTO %s (%s) VALUES (%s)', 
      [tableName, fieldNames, fieldValues]);
      
  finally
    fieldList.Free;
    defaultValues.Free;
    paramQry.Free;
  end;
end;

// 添加一个重载版本的BuildSQL函数，接受字符串参数
function BuildSQL(qry: TAdoQuery; const ParamStr: string): string; overload;
var
  params: TDictionary<string, string>;
begin
  // 将参数字符串转换为字�?
  params := StringToParams(ParamStr);
  try
    // 调用接受字典参数的BuildSQL函数
    Result := BuildSQL(qry, params);
  finally
    params.Free;
  end;
end;

// 原来的BuildSQL函数，接受字典参�?
function BuildSQL(qry: TAdoQuery; const Params: TDictionary<string, string>): string;
var
  sqlType: string;
begin
  // 直接使用确切的字段名 run_type
  if qry.FindField('run_type') <> nil then
    sqlType := LowerCase(qry.FieldByName('run_type').AsString)
  else
    raise EDatabaseException.Create('字段 "run_type" 未找到，无法确定SQL类型');
  
  // 根据SQL类型调用相应的构建函�?
  if sqlType = 'select' then
    Result := BuildSelectSQL(qry, Params)
  else if sqlType = 'insert' then
    Result := BuildInsertSQL(qry, Params)
  else if sqlType = 'update' then
    Result := BuildUpdateSQL(qry, Params)
  else if sqlType = 'delete' then
    Result := BuildDeleteSQL(qry, Params)
  else if sqlType = 'call' then
    Result := BuildCallSQL(qry, Params)
  else
    raise EDatabaseException.Create('不支持的SQL类型: ' + sqlType);
    
  ValidateSQL(Result);
end;

// 将参数字符串转换为字典的函数
function StringToParams(const ParamStr: string): TDictionary<string, string>;
var
  params: TDictionary<string, string>;
  pairs: TArray<string>;
  pair: string;
  colonPos: Integer;
  key, value: string;
  i: Integer;
begin
  params := TDictionary<string, string>.Create;
  
  if ParamStr = '' then
    Exit(params);
  
  // 使用 ||| 分割参数�?
  pairs := ParamStr.Split(['|||']);
  
  for i := 0 to Length(pairs) - 1 do
  begin
    pair := pairs[i];
    
    // 查找第一个冒号（支持中文和英文冒号）
    colonPos := Pos(':', pair);
    if colonPos = 0 then
      colonPos := Pos('：', pair);
      
    if colonPos > 0 then
    begin
      // 分割键值对，只对键去空�?
      key := Trim(Copy(pair, 1, colonPos - 1));
      value := Copy(pair, colonPos + 1, Length(pair));
      
      // 如果是中文冒号，需要多偏移一个字�?
      if pair[colonPos] = '：' then
        value := Copy(pair, colonPos + 2, Length(pair));
        
      // 只有key不为空时才添�?
      if key <> '' then
        params.Add(key, value);
    end;
  end;
  
  Result := params;
end;

procedure ValidateSQL(const SQL: string);
var
  i: Integer;
  inSingleQuote: Boolean;
begin
  // CR-012: 移除全部"自动修复"改写逻辑（补引号/补括号/, ,→NULL, 等），
  // 它们会静默篡改含合法字符的 SQL 并损坏数据。本过程只做校验，
  // 引号不平衡时直接抛出，由调用方决定如何处理。
  inSingleQuote := False;

  for i := 1 to Length(SQL) do
  begin
    if CharInSet(SQL[i], ['''']) then
      inSingleQuote := not inSingleQuote;
  end;

  if inSingleQuote then
    raise EDatabaseException.Create('SQL语句中的引号不平衡，请检查参数值');
end;


// 获取最新插入记录的函数
function GetLastInsertedRecord(aQry: TADOQuery; const TableName, PrimaryKeyField: string): Integer;
begin
  Result := -1;
  if (TableName = '') or (PrimaryKeyField = '') then
    raise EDatabaseException.Create('表名或主键字段名不能为空');

  aQry.Close;
  aQry.SQL.Clear;
  var sqlText := Format('SELECT * FROM "%s" WHERE "%s" = (SELECT MAX("%s") FROM "%s")',
    [TableName, PrimaryKeyField, PrimaryKeyField, TableName]);
    
  OutputDebugString(PChar('获取最新记录SQL: ' + sqlText));
  
  aQry.SQL.Add(sqlText);
  aQry.Open;
  
  if not aQry.Eof then
    Result := aQry.FieldByName(PrimaryKeyField).AsInteger;
end;

function ExecuteAndGetResult(const aSQL: string; aQry: TAdoQuery;
  RunType: TRunType; TableName: string = ''; PrimaryKeyField: string = ''): Integer;
begin
  Result := -1;
  if aSQL = '' then
    raise EDatabaseException.Create('SQL语句为空');

  with aQry do
  begin
    Close;
    SQL.Clear;
    SQL.Text := aSQL;

    try
      case RunType of
        rtSelect:
          begin
            Open;
            Result := RecordCount;
            if Result = 0 then
              raise EDatabaseException.Create('查询没有返回任何记录');
          end;
        rtUpdate, rtDelete:
          begin
            ExecSQL;  // 执行更新或删�?
            Result := RowsAffected;  // 获取受影响的行数
            // 不再抛出异常，因为更�?行也可能是正常情�?
          end;
        rtInsert:
          begin
            if TableName = '' then
              raise EDatabaseException.Create('插入操作需要指定表名');

            // 执行INSERT
            ExecSQL;
            
            // 如果没有提供主键字段名，尝试获取
            if PrimaryKeyField = '' then
              PrimaryKeyField := GetPrimaryKeyFieldName(aQry, TableName, dtPostgreSQL);
              
            // 获取并装载新记录
            Result := GetLastInsertedRecord(aQry, TableName, PrimaryKeyField);
            if Result = -1 then
              raise EDatabaseException.Create('无法获取新插入记录的ID');
          end;
        rtCall:
          raise EDatabaseException.Create('存储过程调用未实现');
      end;
    except
      on E: Exception do
      begin
        // DATA-R3-006: 不把含���数值的完整 aSQL 写进异常消息 (PII 泄漏 —
        // 值可能为聊天正文/用户ID/分享链接, 会进入日志/错误对话框).
        // 完整 SQL 仅 DEBUG 经 OutputDebugString 输出到调试器, 不上抛.
        {$IFDEF DEBUG}
        Winapi.Windows.OutputDebugString(PChar('doQry DEBUG SQL: ' + aSQL));
        {$ENDIF}
        raise EDatabaseException.CreateFmt('SQL执行错误 (RunType=%d): %s',
          [Ord(RunType), E.Message]);
      end;
    end;
  end;
end;


function ExecuteSQL(Connection: TADOConnection; const SQL: string): TDataSet;
var
  qry: TADOQuery;
begin
  qry := TADOQuery.Create(nil);
  try
    qry.Connection := Connection;
    qry.SQL.Text := SQL;
    
    try
      qry.Open;
      Result := TClientDataSet.Create(nil);
      DataSetToClientDataSet(qry, TClientDataSet(Result));
    except
      on E: Exception do
      begin
        // DATA-R3-006: 不把含参数值的完整 SQL 写进异常消息 (PII 泄漏).
        // 完整 SQL 仅 DEBUG 经 OutputDebugString 输出到调试器, 不上抛.
        {$IFDEF DEBUG}
        Winapi.Windows.OutputDebugString(PChar('doQry DEBUG SQL: ' + SQL));
        {$ENDIF}
        raise EDatabaseException.Create('doQry Error::SQL执行错误: ' + E.Message);
      end;
    end;
  finally
    qry.Free;
  end;
end;

// 新增函数：分离参�?
procedure SplitParameters(qry: TAdoQuery; var whereParams, noWhereParams: TAdoQuery);
begin
  whereParams := TAdoQuery.Create(nil);
  noWhereParams := TAdoQuery.Create(nil);
  try
    // 复制连接和基本设�?
    whereParams.Connection := qry.Connection;
    noWhereParams.Connection := qry.Connection;

    // 获取参数定义
    var sql := 'SELECT * FROM query_parameters WHERE proc_name = :ProcName ORDER BY para_order';
    
    // 设置 WHERE 参数查询
    whereParams.SQL.Text := sql + ' AND is_where = 1';
    whereParams.Parameters.ParamByName('ProcName').Value := qry.FieldByName('proc_name').AsString;
    whereParams.Open;

    // 设置�?WHERE 参数查询
    noWhereParams.SQL.Text := sql + ' AND is_where = 0';
    noWhereParams.Parameters.ParamByName('ProcName').Value := qry.FieldByName('proc_name').AsString;
    noWhereParams.Open;
  except
    FreeAndNil(whereParams);
    FreeAndNil(noWhereParams);
    raise;
  end;
end;

// 新的 WHERE 子句构建函数
function BuildWhereClauseFromParams(whereParams: TAdoQuery; 
  const Params: TDictionary<string, string>): string;
var
  firstWhere: Boolean;
begin
  Result := '';
  firstWhere := True;
  
  while not whereParams.Eof do
  begin
    var fieldName := whereParams.FieldByName('para_name').AsString;
    if Params.ContainsKey(fieldName) then
    begin
      if not firstWhere then
        Result := Result + ' AND '
      else
        firstWhere := False;

      Result := Result + fieldName + ' = ' + 
        HandleParamValue(whereParams.FieldByName('para_type').AsString, Params[fieldName]);
    end;
    whereParams.Next;
  end;
end;


// 重构后的doQry函数
function doQry(const ProcName: String; aQry: TAdoQuery; const ParamString: string=''): Integer;
var
  msg: string;
begin
  try
    Result := doQry(ProcName, aQry, msg, ParamString);
  except
    on E: Exception do
    begin
      Result := -1;
      raise;  // 直接重新抛出异常，不修改异常信息
    end;
  end;
end;

function doQry(const ProcName: String; aQry: TAdoQuery; var msg: string; const ParamString: string): Integer;overload;
var
  sSQL: string;
  RunType: TRunType;
  TableName: string;
begin
  Result := -1;
  msg := '';
  sSQL := '';  // 初始�?SQL，以便在出错时也能显�?
  
  try
    // 1. 获取查询配置
    with aQry do
    begin
      Close;
      SQL.Clear;
      SQL.Add('SELECT * FROM queries WHERE proc_name = :ProcName');
      Parameters.ParamByName('ProcName').Value := ProcName;
      Open;

      if IsEmpty then
      begin
        msg := Format('未找到对应的 proc_name: %s', [ProcName]);
        {$IFDEF DEBUG}Winapi.Windows.OutputDebugString(PChar('doQry DEBUG SQL: ' + SQL.Text));{$ENDIF}
        raise EDatabaseException.Create(msg);
      end;
      
      if FindField('run_type') = nil then
      begin
        msg := '字段 run_type 不存在';
        {$IFDEF DEBUG}Winapi.Windows.OutputDebugString(PChar('doQry DEBUG SQL: ' + SQL.Text));{$ENDIF}
        raise EDatabaseException.Create(msg);
      end;

      RunType := StringToRunType(FieldByName('run_type').AsString);
      TableName := FieldByName('table_name').AsString;
    end;

    // 2. 构建并执行SQL
    sSQL := BuildSQL(aQry, ParamString);
    if sSQL = '' then
    begin
      msg := '无法构建SQL语句';
      raise EDatabaseException.Create(msg);
    end;

    // 在执行SQL前调用此函数
    if not ValidateSQLQuotes(sSQL) then
      raise EDatabaseException.Create('SQL语句中的引号不匹配，请检查参数值');

    Result := ExecuteAndGetResult(sSQL, aQry, RunType, TableName);
    
    // 根据不同的操作类型判断执行结�?
    case RunType of
      rtUpdate, rtDelete: 
        begin
          if Result < 0 then
          begin
            msg := 'SQL执行失败';
        {$IFDEF DEBUG}Winapi.Windows.OutputDebugString(PChar('doQry DEBUG SQL: ' + sSQL));{$ENDIF}
            raise EDatabaseException.Create(msg);
          end
          else if Result = 0 then
          begin
            var operationType: string;
            if RunType = rtUpdate then
              operationType := '更新'
            else
              operationType := '删除';
              
            msg := Format('没有记录被%s。可能原因：'#13#10 +
                        '1. 找不到匹配的记录'#13#10 +
                        '2. 更新的值与原值相同'#13#10 +
                        '3. WHERE条件不匹配', [operationType]);
            {$IFDEF DEBUG}Winapi.Windows.OutputDebugString(PChar('doQry DEBUG SQL: ' + sSQL));{$ENDIF}
          end
          else
          begin
            var operationType: string;
            if RunType = rtUpdate then
              operationType := '更新'
            else
              operationType := '删除';
              
            msg := Format('成功%s了%d 条记录', [operationType, Result]);
            {$IFDEF DEBUG}Winapi.Windows.OutputDebugString(PChar('doQry DEBUG SQL: ' + sSQL));{$ENDIF}
          end;
        end;
      rtSelect:
        begin
          if Result <= 0 then
          begin
            msg := '查询未返回数据';
          {$IFDEF DEBUG}Winapi.Windows.OutputDebugString(PChar('doQry DEBUG SQL: ' + sSQL));{$ENDIF}
            raise EDatabaseException.Create(msg);
          end
          else
            msg := Format('查询返回 %d 条记录', [Result]);
          {$IFDEF DEBUG}Winapi.Windows.OutputDebugString(PChar('doQry DEBUG SQL: ' + sSQL));{$ENDIF}
        end;
      rtInsert:
        begin
          if Result <= 0 then
          begin
            msg := '插入操作失败';
          {$IFDEF DEBUG}Winapi.Windows.OutputDebugString(PChar('doQry DEBUG SQL: ' + sSQL));{$ENDIF}
            raise EDatabaseException.Create(msg);
          end
          else
            msg := Format('成功插入记录，ID: %d', [Result]);
          {$IFDEF DEBUG}Winapi.Windows.OutputDebugString(PChar('doQry DEBUG SQL: ' + sSQL));{$ENDIF}
        end;
      rtCall:
        begin
          msg := '存储过程调用未实现';
        {$IFDEF DEBUG}Winapi.Windows.OutputDebugString(PChar('doQry DEBUG SQL: ' + sSQL));{$ENDIF}
          raise EDatabaseException.Create(msg);
        end;
    end;

  except
    on E: Exception do
    begin
      Result := -1;
      if msg = '' then  // 如果还没有设置错误消�?
      begin
        msg := Format('doQry Error: %s', [E.Message]);
      {$IFDEF DEBUG}Winapi.Windows.OutputDebugString(PChar('doQry DEBUG SQL: ' + sSQL));{$ENDIF}
      end;
      raise EDatabaseException.Create(msg);
    end;
  end;
end;

// 修改参数解析函数
function ParseParamString(const paramStr: string; out paramName, paramValue: string): Boolean;
begin
  Result := False;
  OutputDebugString(PChar('Parsing parameter string: ' + paramStr));
  
  // 查找第一个冒号（支持中英文冒号）
  var colonPos := Pos(':', paramStr);
  if colonPos = 0 then
    colonPos := Pos('：', paramStr);
    
  if colonPos > 0 then
  begin
    paramName := Trim(Copy(paramStr, 1, colonPos - 1));
    paramValue := Trim(Copy(paramStr, colonPos + 1, Length(paramStr)));
    Result := (paramName <> '') and (paramValue <> '');
    
    if Result then
      OutputDebugString(PChar(Format('Parsed: name="%s", value="%s"', [paramName, paramValue])))
    else
      OutputDebugString(PChar('Failed to parse parameter string'));
  end
  else
    OutputDebugString(PChar('No colon found in parameter string'));
end;

// 在implementation部分添加新函�?
function CreateParamsFromString(const ParamString: string): TParams;
var
  paramList: TStringList;
  paramName, paramValue: string;
begin
  Result := TParams.Create;
  try
    if ParamString = '' then
      Exit;
      
    paramList := SplitParamString(ParamString);
    try
      for var i := 0 to paramList.Count - 1 do
      begin
        if ParseParamString(paramList[i], paramName, paramValue) then
        begin
          with Result.AddParameter do
          begin
            Name := paramName;
            Value := paramValue;
          end;
        end;
      end;
    finally
      paramList.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

// 在implementation部分添加辅助函数
function SplitParamString(const ParamString: string): TStringList;
var
  splitArray: TArray<string>;
begin
  Result := TStringList.Create;
  try
    // 检查输入字符串是否为空
    if ParamString.Trim = '' then
      raise EDatabaseException.Create('参数字符串不能为空');

    // 使用分割方法
    splitArray := ParamString.Split(['|||']);
    for var part in splitArray do
    begin
      var trimmedPart := Trim(part);
      if trimmedPart <> '' then
        Result.Add(trimmedPart);
    end;
    
    // 检查是否成功分�?
    if Result.Count = 0 then
      raise EDatabaseException.CreateFmt('无法分割参数字符串: "%s"', [ParamString]);

    // 移除空项
    for var i := Result.Count - 1 downto 0 do
      if Result[i].Trim = '' then
        Result.Delete(i);

    // 如果分割后仍为空，抛出异�?
    if Result.Count = 0 then
      raise EDatabaseException.CreateFmt('分割后没有有效参数: "%s"', [ParamString]);
  except
    on E: Exception do
    begin
      Result.Free;
      raise EDatabaseException.Create('分割参数字符串失败: ' + E.Message);
    end;
  end;
end;

function BuildWhereClauseFromDict(qry: TAdoQuery; const Params: TDictionary<string, string>): string;
var
  firstWhere: Boolean;
  qryParams: TAdoQuery;
begin
  Result := '';
  firstWhere := True;
  
  qryParams := TAdoQuery.Create(nil);
  try
    // 获取参数定义
    qryParams.Connection := qry.Connection;
    qryParams.SQL.Text := 'SELECT * FROM query_parameters WHERE proc_name = :ProcName ORDER BY para_order';
    qryParams.Parameters.ParamByName('ProcName').Value := qry.FieldByName('proc_name').AsString;
    qryParams.Open;

    // 遍历所有参数定�?
    while not qryParams.Eof do
    begin
      // 如果�?WHERE 条件字段
      if qryParams.FieldByName('is_where').AsInteger = 1 then
      begin
        var fieldName := qryParams.FieldByName('para_name').AsString;
        
        // 如果在传入参数中有这个字段的�?
        if Params.ContainsKey(fieldName) then
        begin
          if not firstWhere then
            Result := Result + ' AND '
          else
            firstWhere := False;

          Result := Result + fieldName + ' = ' + 
            HandleParamValue(qryParams.FieldByName('para_type').AsString, Params[fieldName]);
        end;
      end;
      qryParams.Next;
    end;

  finally
    qryParams.Free;
  end;
end;

function QuoteValue(const Value: string): string;
var
  i: Integer;
  needQuote: Boolean;
  tempValue: string;
begin
  // 检查是否为空�?
  if (Value = '') or (Value = 'NULL') then
  begin
    Result := 'NULL';
    Exit;
  end;
  
  // 检查是否需要引�?
  needQuote := False;
  for i := 1 to Length(Value) do
  begin
    if not (Value[i] in ['0'..'9', '.', '-', '+']) then
    begin
      needQuote := True;
      Break;
    end;
  end;
  
  if not needQuote then
  begin
    Result := Value;
    Exit;
  end;
  
  // 替换所有中文括号为英文括号
  tempValue := Value;
  tempValue := StringReplace(tempValue, '（', '(', [rfReplaceAll]);
  tempValue := StringReplace(tempValue, '）', ')', [rfReplaceAll]);
  
  // 处理单引�?(在SQL中单引号需要用两个单引号表�?
  tempValue := StringReplace(tempValue, '''', '''''', [rfReplaceAll]);
  
  // 添加引号
  Result := '''' + tempValue + '''';
end;

function IsWhereField(const FieldName: string; qry: TAdoQuery; const ProcName: string = ''): Boolean;
var
  procNameToUse: string;
begin
  // 检查字段是否是WHERE条件字段
  with qry do
  begin
    // 确定使用哪个proc_name
    if ProcName <> '' then
      procNameToUse := ProcName
    else if FindField('proc_name') <> nil then
      procNameToUse := FieldByName('proc_name').AsString
    else
    begin
      // 没有有效的proc_name，返回false
      Result := False;
      Exit;
    end;
    
    Close;
    SQL.Text := 'SELECT is_where FROM query_parameters ' +
                'WHERE proc_name = :ProcName AND para_name = :ParaName';
    Parameters.ParamByName('ProcName').Value := procNameToUse;
    Parameters.ParamByName('ParaName').Value := FieldName;
    Open;
    
    Result := not IsEmpty and (FieldByName('is_where').AsInteger = 1);
    Close;
  end;
end;

// 添加一个新函数来检查表的主键字�?
function GetPrimaryKeyField(Connection: TADOConnection; const TableName: string): string;
var
  qry: TADOQuery;
begin
  Result := '';
  qry := TADOQuery.Create(nil);
  try
    qry.Connection := Connection;
    
    // PostgreSQL查询主键字段
    qry.SQL.Text := 
      'SELECT a.attname ' +
      'FROM pg_index i ' +
      'JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey) ' +
      'WHERE i.indrelid = :TableName::regclass AND i.indisprimary';
    
    qry.Parameters.ParamByName('TableName').Value := TableName;
    
    try
      qry.Open;
      if not qry.IsEmpty then
        Result := qry.Fields[0].AsString;
    except
      // 如果上面的查询失败，可能不是PostgreSQL或表名有问题
      // 返回默认�?
      if CompareText(TableName, 'texts') = 0 then
        Result := 'text_id'
      else
        Result := 'id';
    end;
  finally
    qry.Free;
  end;
end;

function RightStr(const Str: string; Count: Integer): string;
begin
  Result := Copy(Str, Length(Str) - Count + 1, Count);
end;

procedure DataSetToClientDataSet(Source: TDataSet; Dest: TClientDataSet);
var
  i: Integer;
  field: TField;
begin
  // 创建目标数据集的结构
  Dest.Close;
  for i := 0 to Source.Fields.Count - 1 do
  begin
    field := Source.Fields[i];
    Dest.FieldDefs.Add(field.FieldName, field.DataType, field.Size);
  end;
  Dest.CreateDataSet;
  
  // 复制数据
  Source.First;
  while not Source.Eof do
  begin
    Dest.Append;
    for i := 0 to Source.Fields.Count - 1 do
    begin
      field := Source.Fields[i];
      if not field.IsNull then
        Dest.Fields[i].Value := field.Value;
    end;
    Dest.Post;
    Source.Next;
  end;
end;

function GetQueryDef(Connection: TADOConnection; const ProcName: string): TADOQuery;
var
  qry: TADOQuery;
begin
  qry := TADOQuery.Create(nil);
  try
    qry.Connection := Connection;
    qry.SQL.Text := 'SELECT * FROM queries WHERE proc_name = :ProcName';
    qry.Parameters.ParamByName('ProcName').Value := ProcName;
    qry.Open;
    
    if qry.IsEmpty then
      raise EDatabaseException.Create('未找到查询定义: ' + ProcName);
      
    Result := qry;
  except
    qry.Free;
    raise;
  end;
end;

end.
