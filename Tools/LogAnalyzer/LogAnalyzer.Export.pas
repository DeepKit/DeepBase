{ ============================================================================
  LogAnalyzer.Export - 日志导出模块

  版本: 1.0
  功能:
    - 导出为 CSV 格式
    - 导出为 JSON 格式
    - 导出为 HTML 格式 (带样式)
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
  /// 日志导出器
  /// </summary>
  TLogExporter = class
  private
    class function LevelToString(ALevel: TLogLevel): string;
    class function EscapeCSV(const AValue: string): string;
    class function EscapeHTML(const AValue: string): string;
  public
    /// <summary>
    /// 导出为 CSV 格式
    /// </summary>
    class procedure ExportToCSV(const ALogs: TArray<TLogEntry>; const AFileName: string);

    /// <summary>
    /// 导出为 JSON 格式
    /// </summary>
    class procedure ExportToJSON(const ALogs: TArray<TLogEntry>; const AFileName: string);

    /// <summary>
    /// 导出为 HTML 格式 (带样式和表格)
    /// </summary>
    class procedure ExportToHTML(const ALogs: TArray<TLogEntry>; const AFileName: string;
      const ATitle: string = '日志导出');

    /// <summary>
    /// 导出为纯文本格式
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
  // CSV 字段中包含逗号、引号或换行符时需要用引号包围
  if (Pos(',', AValue) > 0) or (Pos('"', AValue) > 0) or
     (Pos(#13, AValue) > 0) or (Pos(#10, AValue) > 0) then
  begin
    // 双引号转义为两个双引号
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

    // 标题行
    SL.Add('ID,时间,级别,来源,消息,详情');

    // 数据行
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
      SL.Text := JArray.Format(2);  // 格式化输出，缩进2空格
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
    // HTML 头部
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

    // 标题
    SL.Add('  <h1>' + EscapeHTML(ATitle) + '</h1>');

    // 统计信息
    SL.Add('  <div class="stats">');
    SL.Add(Format('    <span><strong>总条数:</strong> %d</span>', [Length(ALogs)]));
    if Length(ALogs) > 0 then
    begin
      SL.Add(Format('    <span><strong>时间范围:</strong> %s ~ %s</span>', [
        FormatDateTime('yyyy-mm-dd hh:nn', ALogs[0].Timestamp),
        FormatDateTime('yyyy-mm-dd hh:nn', ALogs[High(ALogs)].Timestamp)
      ]));
    end;
    SL.Add(Format('    <span><strong>导出时间:</strong> %s</span>', [
      FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)
    ]));
    SL.Add('  </div>');

    // 表格
    SL.Add('  <table>');
    SL.Add('    <thead>');
    SL.Add('      <tr>');
    SL.Add('        <th style="width:60px">ID</th>');
    SL.Add('        <th style="width:150px">时间</th>');
    SL.Add('        <th style="width:60px">级别</th>');
    SL.Add('        <th style="width:120px">来源</th>');
    SL.Add('        <th>消息</th>');
    SL.Add('      </tr>');
    SL.Add('    </thead>');
    SL.Add('    <tbody>');

    // 数据行
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

    // 页脚
    SL.Add('  <div class="footer">');
    SL.Add('    Generated by UniBase LogAnalyzer v1.0');
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
    SL.Add('  UniBase 日志导出');
    SL.Add('  导出时间: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    SL.Add('  总条数: ' + IntToStr(Length(ALogs)));
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
        SL.Add('    --- 详情 ---');
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
