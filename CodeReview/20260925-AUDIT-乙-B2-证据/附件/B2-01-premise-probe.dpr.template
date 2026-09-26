program probe_b01;
{$APPTYPE CONSOLE}
{ B2-01 前提实测探针：逐字拷贝修前/修后两版 BoolField，喂同一份 Firestore REST 文档形状，
  取机器真值判断「is_active 恒读成 False」这条工单前提是否成立。产物落 .tmp，不入库。 }
uses
  System.SysUtils,
  System.JSON;

function OldBoolField(Fields: TJSONObject; const AKey: string): Boolean;
var
  Fld: TJSONObject;
  S: string;
begin
  if Fields.TryGetValue<TJSONObject>(AKey, Fld) then
  begin
    if Fld.TryGetValue<string>('booleanValue', S) then
      Exit(SameText(S, 'true'));
  end;
  Result := False;
end;

function NewBoolField(Fields: TJSONObject; const AKey: string): Boolean;
var
  Fld: TJSONObject;
  LVal: TJSONValue;
begin
  Result := False;
  if not Fields.TryGetValue<TJSONObject>(AKey, Fld) then
    Exit;
  LVal := Fld.GetValue('booleanValue');
  if LVal = nil then
    Exit;
  if LVal is TJSONBool then
    Exit(TJSONBool(LVal).AsBoolean);
  raise Exception.CreateFmt('type mismatch: %s', [LVal.ClassName]);
end;

procedure Probe(const ALabel, ADoc: string);
var
  Doc: TJSONObject;
  Fields: TJSONObject;
  LOld, LNew: string;
begin
  Write('[' + ALabel + '] ');
  Doc := TJSONObject.ParseJSONValue(ADoc) as TJSONObject;
  try
    Fields := Doc.GetValue('fields') as TJSONObject;
    try
      LOld := BoolToStr(OldBoolField(Fields, 'is_active'), True);
    except
      on E: Exception do
        LOld := 'RAISE(' + E.Message + ')';
    end;
    try
      LNew := BoolToStr(NewBoolField(Fields, 'is_active'), True);
    except
      on E: Exception do
        LNew := 'RAISE(' + E.Message + ')';
    end;
    WriteLn('OLD=', LOld, '  NEW=', LNew);
  finally
    Doc.Free; // Fields 是 Doc 的子节点，随父释放
  end;
end;

begin
  try
    // 写路径 WrapValue(Boolean) 经 HTTP 序列化后 Firestore 回读的真实形状
    Probe('bool-true ', '{"fields":{"is_active":{"booleanValue":true}}}');
    Probe('bool-false', '{"fields":{"is_active":{"booleanValue":false}}}');
    // 字段缺失
    Probe('missing   ', '{"fields":{"display_name":{"stringValue":"x"}}}');
    // 类型损坏：booleanValue 落成字符串
    Probe('as-string ', '{"fields":{"is_active":{"booleanValue":"true"}}}');
    // 类型损坏：booleanValue 落成数字
    Probe('as-number ', '{"fields":{"is_active":{"booleanValue":1}}}');
    WriteLn('PROBE_EXIT=0');
  except
    on E: Exception do
    begin
      WriteLn('PROBE_ABORT: ', E.ClassName, ' ', E.Message);
      WriteLn('PROBE_EXIT=1');
    end;
  end;
end.
