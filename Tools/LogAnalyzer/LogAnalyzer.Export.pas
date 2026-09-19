{ ============================================================================
  LogAnalyzer.Export - 鏃ュ織瀵煎嚭妯″潡

  鐗堟湰: 1.0
  鍔熻兘:
    - 瀵煎嚭涓?CSV 鏍煎紡
    - 瀵煎嚭涓?JSON 鏍煎紡
    - 瀵煎嚭涓?HTML 鏍煎紡 (甯︽牱寮?
  ============================================================================ }

unit LogAnalyzer.Export;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.DateUtils,
  LogAnalyzer.Data;

type
  /// <summary>
  /// 鏃ュ織瀵煎嚭鍣?
  /// </summary>
  TLogExporter = class
  private
    class function LevelToString(ALevel: TLogLevel): string;
    class function EscapeCSV(const AValue: string): string;
    class function EscapeHTML(const AValue: string): string;
  public
    /// <summary>
    /// 瀵煎嚭涓?CSV 鏍煎紡
    /// </summary>
    class procedure ExportToCSV(const ALogs: TArray<TLogEntry>; const AFileName: string);

    /// <summary>
    /// 瀵煎嚭涓?JSON 鏍煎紡
    /// </summary>
    class procedure ExportToJSON(const ALogs: TArray<TLogEntry>; const AFileName: string);

    /// <summary>
    /// 瀵煎嚭涓?HTML 鏍煎紡 (甯︽牱寮忓拰琛ㄦ牸)
    /// </summary>
    class procedure ExportToHTML(const ALogs: TArray<TLogEntry>; const AFileName: string;
      const ATitle: string = '鏃ュ織瀵煎嚭');

    /// <summary>
    /// 瀵煎嚭涓虹函鏂囨湰鏍煎紡
    /// </summary>
    class procedure ExportToText(const ALogs: TArray<TLogEntry>; const AFileName: string);
  end;

implementation

{ TLogExporter }

class function TLogExporter.LevelToString(ALevel: TLogLevel): string;
begin
  case ALevel of
    llTrace: Result := 'TRACE';
    llDebug: Result := 'DEBUG';
    llInfo:  Result := 'INFO';
    llWarn:  Result := 'WARN';
    llError: Result := 'ERROR';
    llFatal: Result := 'FATAL';
  else
    Result := '?';
  end;
end;

class function TLogExporter.EscapeCSV(const AValue: string): string;
begin
  // CSV 瀛楁涓寘鍚€楀彿銆佸紩鍙锋垨鎹㈣绗︽椂闇€瑕佺敤寮曞彿鍖呭洿
  if (Pos(',', AValue) > 0) or (Pos('"', AValue) > 0) or
     (Pos(#13, AValue) > 0) or (Pos(#10, AValue) > 0) then
  begin
    // 鍙屽紩鍙疯浆涔変负涓や釜鍙屽紩鍙?
    Result := '"' + StringReplace(AValue, '"', '""', [rfReplaceAll]) + '"';
  end
  else
    Result := AValue;
end;

class function TLogExporter.EscapeHTML(const AValue: string): string;
begin
  Result := AValue;
  Result := StringReplace(Result, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&#39;', [rfReplaceAll]);
  Result := StringReplace(Result, #13#10, '<br/>', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '<br/>', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '<br/>', [rfReplaceAll]);
end;

class procedure TLogExporter.ExportToCSV(const ALogs: TArray<TLogEntry>;
  const AFileName: string);
var
  SL: TStringList;
  I: Integer;
  Line: string;
begin
  SL := TStringList.Create;
  try
    // UTF-8 BOM for Excel compatibility
    SL.WriteBOM := True;

    // 鏍囬琛?
    SL.Add('ID,鏃堕棿,绾у埆,鏉ユ簮,娑堟伅,璇︽儏');

    // 鏁版嵁琛?
    for I := 0 to High(ALogs) do
    begin
      Line := Format('%d,%s,%s,%s,%s,%s', [
        ALogs[I].Id,
        EscapeCSV(FormatDateTime('yyyy-mm-dd hh:nn:ss', ALogs[I].Timestamp)),
        EscapeCSV(LevelToString(ALogs[I].Level)),
        EscapeCSV(ALogs[I].Source),
        EscapeCSV(ALogs[I].Message),
        EscapeCSV(ALogs[I].Details)
      ]);
      SL.Add(Line);
    end;

    SL.SaveToFile(AFileName, TEncoding.UTF8);
  finally
    SL.Free;
  end;
end;

class procedure TLogExporter.ExportToJSON(const ALogs: TArray<TLogEntry>;
  const AFileName: string);
var
  JArray: TJSONArray;
  JObj: TJSONObject;
  I: Integer;
  SL: TStringList;
begin
  JArray := TJSONArray.Create;
  try
    for I := 0 to High(ALogs) do
    begin
      JObj := TJSONObject.Create;
      JObj.AddPair('id', TJSONNumber.Create(ALogs[I].Id));
      JObj.AddPair('timestamp', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', ALogs[I].Timestamp));
      JObj.AddPair('level', LevelToString(ALogs[I].Level));
      JObj.AddPair('source', ALogs[I].Source);
      JObj.AddPair('message', ALogs[I].Message);
      if ALogs[I].Details <> '' then
        JObj.AddPair('details', ALogs[I].Details);
      JArray.AddElement(JObj);
    end;

    SL := TStringList.Create;
    try
      SL.Text := JArray.Format(2);  // 鏍煎紡鍖栬緭鍑猴紝缂╄繘2绌烘牸
      SL.SaveToFile(AFileName, TEncoding.UTF8);
    finally
      SL.Free;
    end;
  finally
    JArray.Free;
  end;
end;

class procedure TLogExporter.ExportToHTML(const ALogs: TArray<TLogEntry>;
  const AFileName: string; const ATitle: string);
var
  SL: TStringList;
  I: Integer;
  LevelClass: string;

  function GetLevelClass(ALevel: TLogLevel): string;
  begin
    case ALevel of
      llTrace: Result := 'level-trace';
      llDebug: Result := 'level-debug';
      llInfo:  Result := 'level-info';
      llWarn:  Result := 'level-warn';
      llError: Result := 'level-error';
      llFatal: Result := 'level-fatal';
    else
      Result := '';
    end;
  end;

begin
  SL := TStringList.Create;
  try
    // HTML 澶撮儴
    SL.Add('<!DOCTYPE html>');
    SL.Add('<html lang="zh-CN">');
    SL.Add('<head>');
    SL.Add('  <meta charset="UTF-8">');
    SL.Add('  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    SL.Add('  <title>' + EscapeHTML(ATitle) + '</title>');
    SL.Add('  <style>');
    SL.Add('    body { font-family: "Microsoft YaHei", Arial, sans-serif; margin: 20px; background: #f5f5f5; }');
    SL.Add('    h1 { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }');
    SL.Add('    .stats { background: #fff; padding: 15px; border-radius: 5px; margin-bottom: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }');
    SL.Add('    .stats span { margin-right: 20px; }');
    SL.Add('    table { width: 100%; border-collapse: collapse; background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }');
    SL.Add('    th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }');
    SL.Add('    th { background: #007bff; color: #fff; position: sticky; top: 0; }');
    SL.Add('    tr:hover { background: #f8f9fa; }');
    SL.Add('    .level-trace { color: #6c757d; }');
    SL.Add('    .level-debug { color: #17a2b8; }');
    SL.Add('    .level-info { color: #28a745; }');
    SL.Add('    .level-warn { color: #ffc107; background: #fff3cd; }');
    SL.Add('    .level-error { color: #dc3545; background: #f8d7da; }');
    SL.Add('    .level-fatal { color: #fff; background: #721c24; }');
    SL.Add('    .timestamp { white-space: nowrap; color: #666; font-size: 0.9em; }');
    SL.Add('    .source { font-weight: bold; color: #495057; }');
    SL.Add('    .message { max-width: 500px; word-wrap: break-word; }');
    SL.Add('    .footer { margin-top: 20px; color: #666; font-size: 0.85em; text-align: center; }');
    SL.Add('  </style>');
    SL.Add('</head>');
    SL.Add('<body>');

    // 鏍囬
    SL.Add('  <h1>' + EscapeHTML(ATitle) + '</h1>');

    // 缁熻淇℃伅
    SL.Add('  <div class="stats">');
    SL.Add(Format('    <span><strong>鎬绘潯鏁?</strong> %d</span>', [Length(ALogs)]));
    if Length(ALogs) > 0 then
    begin
      SL.Add(Format('    <span><strong>鏃堕棿鑼冨洿:</strong> %s ~ %s</span>', [
        FormatDateTime('yyyy-mm-dd hh:nn', ALogs[0].Timestamp),
        FormatDateTime('yyyy-mm-dd hh:nn', ALogs[High(ALogs)].Timestamp)
      ]));
    end;
    SL.Add(Format('    <span><strong>瀵煎嚭鏃堕棿:</strong> %s</span>', [
      FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)
    ]));
    SL.Add('  </div>');

    // 琛ㄦ牸
    SL.Add('  <table>');
    SL.Add('    <thead>');
    SL.Add('      <tr>');
    SL.Add('        <th style="width:60px">ID</th>');
    SL.Add('        <th style="width:150px">鏃堕棿</th>');
    SL.Add('        <th style="width:60px">绾у埆</th>');
    SL.Add('        <th style="width:120px">鏉ユ簮</th>');
    SL.Add('        <th>娑堟伅</th>');
    SL.Add('      </tr>');
    SL.Add('    </thead>');
    SL.Add('    <tbody>');

    // 鏁版嵁琛?
    for I := 0 to High(ALogs) do
    begin
      LevelClass := GetLevelClass(ALogs[I].Level);
      SL.Add('      <tr>');
      SL.Add(Format('        <td>%d</td>', [ALogs[I].Id]));
      SL.Add(Format('        <td class="timestamp">%s</td>',
        [FormatDateTime('yyyy-mm-dd hh:nn:ss', ALogs[I].Timestamp)]));
      SL.Add(Format('        <td class="%s">%s</td>',
        [LevelClass, LevelToString(ALogs[I].Level)]));
      SL.Add(Format('        <td class="source">%s</td>',
        [EscapeHTML(ALogs[I].Source)]));
      SL.Add(Format('        <td class="message">%s</td>',
        [EscapeHTML(ALogs[I].Message)]));
      SL.Add('      </tr>');
    end;

    SL.Add('    </tbody>');
    SL.Add('  </table>');

    // 椤佃剼
    SL.Add('  <div class="footer">');
    SL.Add('    Generated by DeepBase LogAnalyzer v1.0');
    SL.Add('  </div>');

    SL.Add('</body>');
    SL.Add('</html>');

    SL.SaveToFile(AFileName, TEncoding.UTF8);
  finally
    SL.Free;
  end;
end;

class procedure TLogExporter.ExportToText(const ALogs: TArray<TLogEntry>;
  const AFileName: string);
var
  SL: TStringList;
  I: Integer;
begin
  SL := TStringList.Create;
  try
    SL.Add('===============================================================================');
    SL.Add('  DeepBase 鏃ュ織瀵煎嚭');
    SL.Add('  瀵煎嚭鏃堕棿: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    SL.Add('  鎬绘潯鏁? ' + IntToStr(Length(ALogs)));
    SL.Add('===============================================================================');
    SL.Add('');

    for I := 0 to High(ALogs) do
    begin
      SL.Add(Format('[%d] %s [%s] <%s>',
        [ALogs[I].Id,
         FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', ALogs[I].Timestamp),
         LevelToString(ALogs[I].Level),
         ALogs[I].Source]));
      SL.Add('    ' + ALogs[I].Message);
      if ALogs[I].Details <> '' then
      begin
        SL.Add('    --- 璇︽儏 ---');
        SL.Add('    ' + StringReplace(ALogs[I].Details, #13#10, #13#10 + '    ', [rfReplaceAll]));
      end;
      SL.Add('');
    end;

    SL.Add('===============================================================================');
    SL.Add('  End of Export');
    SL.Add('===============================================================================');

    SL.SaveToFile(AFileName, TEncoding.UTF8);
  finally
    SL.Free;
  end;
end;

end.
