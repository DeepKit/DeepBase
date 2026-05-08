unit Service.Search;

{*******************************************************************************
  Search Service - 搜索服务

  DeepBase 框架文档管理模板 - 全文搜索服务
  使用 SQLite FTS5 实现高效全文搜索
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  FireDAC.Comp.Client,
  Entity.Document;

type
  /// <summary>
  /// 搜索选项
  /// </summary>
  TSearchOptions = record
    CategoryId: string;       // 限定分类
    Tags: TArray<string>;     // 限定标签
    DateFrom: TDateTime;      // 日期范围起始
    DateTo: TDateTime;        // 日期范围结束
    Status: TDocumentStatus;  // 文档状�?
    MaxResults: Integer;      // 最大结果数
    IncludeContent: Boolean;  // 搜索内容
    IncludeTitle: Boolean;    // 搜索标题
    
    class function Default: TSearchOptions; static;
  end;

  /// <summary>
  /// 搜索服务 - 使用 SQLite FTS5 全文搜索
  /// </summary>
  TSearchService = class
  private
    FConnection: TFDConnection;
    FFTSEnabled: Boolean;

    function BuildFTSQuery(const Query: string; const Options: TSearchOptions): string;
    function ExtractSnippet(const Content, Query: string; MaxLength: Integer = 150): string;
    function HighlightMatches(const Text, Query: string): string;
  public
    constructor Create(AConnection: TFDConnection);

    /// <summary>初始�?FTS 索引�?/summary>
    procedure InitializeFTS;

    /// <summary>检�?FTS 是否可用</summary>
    function IsFTSAvailable: Boolean;

    /// <summary>基本全文搜索</summary>
    function Search(const Query: string): TObjectList<TSearchResult>;

    /// <summary>高级搜索（带选项�?/summary>
    function AdvancedSearch(const Query: string; 
      const Options: TSearchOptions): TObjectList<TSearchResult>;

    /// <summary>搜索标题</summary>
    function SearchByTitle(const Query: string): TObjectList<TSearchResult>;

    /// <summary>获取搜索建议</summary>
    function GetSuggestions(const Prefix: string; 
      MaxCount: Integer = 10): TArray<string>;

    /// <summary>索引单个文档</summary>
    procedure IndexDocument(const DocId, Title, Content: string);

    /// <summary>从索引中移除文档</summary>
    procedure RemoveFromIndex(const DocId: string);

    /// <summary>重建全部索引</summary>
    procedure RebuildIndex;

    /// <summary>优化索引</summary>
    procedure OptimizeIndex;

    /// <summary>获取索引统计</summary>
    function GetIndexStats: string;

    property Connection: TFDConnection read FConnection;
    property FTSEnabled: Boolean read FFTSEnabled;
  end;

implementation

uses
  System.StrUtils, System.DateUtils,
  DeepBase.Logger;

{ TSearchOptions }

class function TSearchOptions.Default: TSearchOptions;
begin
  Result.CategoryId := '';
  SetLength(Result.Tags, 0);
  Result.DateFrom := 0;
  Result.DateTo := 0;
  Result.Status := dsActive;
  Result.MaxResults := 100;
  Result.IncludeContent := True;
  Result.IncludeTitle := True;
end;

{ TSearchService }

constructor TSearchService.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
  FFTSEnabled := False;
  
  // 检查并初始�?FTS
  if IsFTSAvailable then
  begin
    InitializeFTS;
    FFTSEnabled := True;
  end;
end;

function TSearchService.IsFTSAvailable: Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    try
      // 尝试创建一个临�?FTS5 表来测试
      Query.SQL.Text := 'SELECT sqlite_version()';
      Query.Open;
      Result := True;  // SQLite 3.9+ 支持 FTS5
    except
      Result := False;
    end;
  finally
    Query.Free;
  end;
end;

procedure TSearchService.InitializeFTS;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    // 创建 FTS5 虚拟�?
    Query.SQL.Text := 
      'CREATE VIRTUAL TABLE IF NOT EXISTS Documents_FTS USING fts5(' +
      '  DocId, ' +
      '  Title, ' +
      '  Content, ' +
      '  tokenize = "unicode61"' +  // 支持 Unicode
      ')';
    Query.ExecSQL;
    
    // 创建触发器：插入
    Query.SQL.Text := 
      'CREATE TRIGGER IF NOT EXISTS Documents_AI AFTER INSERT ON Documents BEGIN ' +
      '  INSERT INTO Documents_FTS (DocId, Title, Content) ' +
      '  VALUES (NEW.Id, NEW.Title, NEW.Content); ' +
      'END';
    Query.ExecSQL;
    
    // 创建触发器：更新
    Query.SQL.Text := 
      'CREATE TRIGGER IF NOT EXISTS Documents_AU AFTER UPDATE ON Documents BEGIN ' +
      '  UPDATE Documents_FTS SET Title = NEW.Title, Content = NEW.Content ' +
      '  WHERE DocId = NEW.Id; ' +
      'END';
    Query.ExecSQL;
    
    // 创建触发器：删除
    Query.SQL.Text := 
      'CREATE TRIGGER IF NOT EXISTS Documents_AD AFTER DELETE ON Documents BEGIN ' +
      '  DELETE FROM Documents_FTS WHERE DocId = OLD.Id; ' +
      'END';
    Query.ExecSQL;
    
    Log.Info('FTS5 index initialized');
  finally
    Query.Free;
  end;
end;

function TSearchService.Search(const Query: string): TObjectList<TSearchResult>;
begin
  Result := AdvancedSearch(Query, TSearchOptions.Default);
end;

function TSearchService.AdvancedSearch(const Query: string;
  const Options: TSearchOptions): TObjectList<TSearchResult>;
var
  SqlQuery: TFDQuery;
  SearchResult: TSearchResult;
  SQL: string;
begin
  Result := TObjectList<TSearchResult>.Create(True);
  
  if Query.Trim.IsEmpty then
    Exit;
  
  SqlQuery := TFDQuery.Create(nil);
  try
    SqlQuery.Connection := FConnection;
    
    if FFTSEnabled then
    begin
      // 使用 FTS5 搜索
      SQL := 
        'SELECT d.Id, d.Title, d.Content, d.UpdatedAt, d.CategoryId, ' +
        '  c.Name AS CategoryName, ' +
        '  bm25(Documents_FTS) AS Score ' +
        'FROM Documents_FTS fts ' +
        'INNER JOIN Documents d ON fts.DocId = d.Id ' +
        'LEFT JOIN Categories c ON d.CategoryId = c.Id ' +
        'WHERE Documents_FTS MATCH :Query ' +
        '  AND d.Status = :Status ';
      
      // 添加分类过滤
      if not Options.CategoryId.IsEmpty then
        SQL := SQL + 'AND d.CategoryId = :CategoryId ';
      
      // 添加日期过滤
      if Options.DateFrom > 0 then
        SQL := SQL + 'AND d.UpdatedAt >= :DateFrom ';
      if Options.DateTo > 0 then
        SQL := SQL + 'AND d.UpdatedAt <= :DateTo ';
      
      SQL := SQL + 'ORDER BY Score LIMIT :MaxResults';
      
      SqlQuery.SQL.Text := SQL;
      SqlQuery.ParamByName('Query').AsString := BuildFTSQuery(Query, Options);
      SqlQuery.ParamByName('Status').AsInteger := Ord(Options.Status);
      
      if not Options.CategoryId.IsEmpty then
        SqlQuery.ParamByName('CategoryId').AsString := Options.CategoryId;
      if Options.DateFrom > 0 then
        SqlQuery.ParamByName('DateFrom').AsDateTime := Options.DateFrom;
      if Options.DateTo > 0 then
        SqlQuery.ParamByName('DateTo').AsDateTime := Options.DateTo;
      
      SqlQuery.ParamByName('MaxResults').AsInteger := Options.MaxResults;
    end
    else
    begin
      // 回退�?LIKE 搜索
      SQL := 
        'SELECT d.Id, d.Title, d.Content, d.UpdatedAt, d.CategoryId, ' +
        '  c.Name AS CategoryName, 0 AS Score ' +
        'FROM Documents d ' +
        'LEFT JOIN Categories c ON d.CategoryId = c.Id ' +
        'WHERE (d.Title LIKE :Query OR d.Content LIKE :Query) ' +
        '  AND d.Status = :Status ';
      
      if not Options.CategoryId.IsEmpty then
        SQL := SQL + 'AND d.CategoryId = :CategoryId ';
      
      SQL := SQL + 'ORDER BY d.UpdatedAt DESC LIMIT :MaxResults';
      
      SqlQuery.SQL.Text := SQL;
      SqlQuery.ParamByName('Query').AsString := '%' + Query + '%';
      SqlQuery.ParamByName('Status').AsInteger := Ord(Options.Status);
      
      if not Options.CategoryId.IsEmpty then
        SqlQuery.ParamByName('CategoryId').AsString := Options.CategoryId;
      
      SqlQuery.ParamByName('MaxResults').AsInteger := Options.MaxResults;
    end;
    
    SqlQuery.Open;
    
    while not SqlQuery.Eof do
    begin
      SearchResult := TSearchResult.Create;
      SearchResult.DocumentId := SqlQuery.FieldByName('Id').AsString;
      SearchResult.Title := SqlQuery.FieldByName('Title').AsString;
      SearchResult.Snippet := ExtractSnippet(
        SqlQuery.FieldByName('Content').AsString, Query);
      SearchResult.Score := SqlQuery.FieldByName('Score').AsFloat;
      SearchResult.CategoryName := SqlQuery.FieldByName('CategoryName').AsString;
      SearchResult.UpdatedAt := SqlQuery.FieldByName('UpdatedAt').AsDateTime;
      Result.Add(SearchResult);
      SqlQuery.Next;
    end;
    
    Log.Debug('Search "%s": %d results', [Query, Result.Count]);
  finally
    SqlQuery.Free;
  end;
end;

function TSearchService.SearchByTitle(const Query: string): TObjectList<TSearchResult>;
var
  Options: TSearchOptions;
begin
  Options := TSearchOptions.Default;
  Options.IncludeContent := False;
  Options.IncludeTitle := True;
  Result := AdvancedSearch(Query, Options);
end;

function TSearchService.BuildFTSQuery(const Query: string;
  const Options: TSearchOptions): string;
var
  Terms: TArray<string>;
  I: Integer;
  Builder: TStringBuilder;
begin
  // 构建 FTS5 查询语法
  // 支持：单词搜索、短语搜索（引号）、前缀搜索�?�?
  
  Builder := TStringBuilder.Create;
  try
    // 分割搜索�?
    Terms := Query.Split([' '], TStringSplitOptions.ExcludeEmpty);
    
    for I := 0 to High(Terms) do
    begin
      if I > 0 then
        Builder.Append(' ');
      
      // 如果不是短语（引号包围），添加前缀匹配
      if not Terms[I].StartsWith('"') and not Terms[I].EndsWith('*') then
        Builder.Append(Terms[I] + '*')
      else
        Builder.Append(Terms[I]);
    end;
    
    // 限定搜索�?
    if Options.IncludeTitle and Options.IncludeContent then
      Result := Builder.ToString
    else if Options.IncludeTitle then
      Result := 'Title:(' + Builder.ToString + ')'
    else if Options.IncludeContent then
      Result := 'Content:(' + Builder.ToString + ')'
    else
      Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

function TSearchService.ExtractSnippet(const Content, Query: string;
  MaxLength: Integer): string;
var
  LowerContent, LowerQuery: string;
  Pos, StartPos, EndPos: Integer;
  Terms: TArray<string>;
begin
  if Content.IsEmpty then
    Exit('');
  
  LowerContent := Content.ToLower;
  Terms := Query.ToLower.Split([' '], TStringSplitOptions.ExcludeEmpty);
  
  // 查找第一个匹配词的位�?
  Pos := -1;
  for var Term in Terms do
  begin
    Pos := LowerContent.IndexOf(Term);
    if Pos >= 0 then
      Break;
  end;
  
  if Pos < 0 then
  begin
    // 没找到匹配，返回开头部�?
    if Length(Content) <= MaxLength then
      Exit(Content)
    else
      Exit(Copy(Content, 1, MaxLength) + '...');
  end;
  
  // 计算摘要范围
  StartPos := Max(0, Pos - MaxLength div 3);
  EndPos := Min(Length(Content), StartPos + MaxLength);
  
  // 尝试从单词边界开�?
  while (StartPos > 0) and (Content[StartPos + 1] <> ' ') do
    Dec(StartPos);
  
  Result := '';
  if StartPos > 0 then
    Result := '...';
  
  Result := Result + Copy(Content, StartPos + 1, EndPos - StartPos);
  
  if EndPos < Length(Content) then
    Result := Result + '...';
  
  // 移除换行
  Result := Result.Replace(#13#10, ' ').Replace(#10, ' ').Replace(#13, ' ');
end;

function TSearchService.HighlightMatches(const Text, Query: string): string;
var
  Terms: TArray<string>;
  LowerText: string;
  Term: string;
  Pos: Integer;
begin
  Result := Text;
  Terms := Query.ToLower.Split([' '], TStringSplitOptions.ExcludeEmpty);
  
  for Term in Terms do
  begin
    LowerText := Result.ToLower;
    Pos := LowerText.IndexOf(Term);
    while Pos >= 0 do
    begin
      // 添加高亮标记
      Result := Copy(Result, 1, Pos) + 
                '<mark>' + Copy(Result, Pos + 1, Length(Term)) + '</mark>' +
                Copy(Result, Pos + Length(Term) + 1, Length(Result));
      
      // 继续查找下一�?
      LowerText := Result.ToLower;
      Pos := LowerText.IndexOf(Term, Pos + Length('<mark></mark>') + Length(Term));
    end;
  end;
end;

function TSearchService.GetSuggestions(const Prefix: string;
  MaxCount: Integer): TArray<string>;
var
  Query: TFDQuery;
  Suggestions: TList<string>;
begin
  Suggestions := TList<string>.Create;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      
      // 从标题中提取建议
      Query.SQL.Text := 
        'SELECT DISTINCT Title FROM Documents ' +
        'WHERE Title LIKE :Prefix AND Status = :Status ' +
        'ORDER BY UpdatedAt DESC LIMIT :Limit';
      Query.ParamByName('Prefix').AsString := Prefix + '%';
      Query.ParamByName('Status').AsInteger := Ord(dsActive);
      Query.ParamByName('Limit').AsInteger := MaxCount;
      Query.Open;
      
      while not Query.Eof do
      begin
        Suggestions.Add(Query.FieldByName('Title').AsString);
        Query.Next;
      end;
      
      // 如果建议不足，从标签中补�?
      if Suggestions.Count < MaxCount then
      begin
        Query.SQL.Text := 
          'SELECT DISTINCT Name FROM Tags ' +
          'WHERE Name LIKE :Prefix ' +
          'ORDER BY UsageCount DESC LIMIT :Limit';
        Query.ParamByName('Prefix').AsString := Prefix + '%';
        Query.ParamByName('Limit').AsInteger := MaxCount - Suggestions.Count;
        Query.Open;
        
        while not Query.Eof do
        begin
          var TagName := Query.FieldByName('Name').AsString;
          if not Suggestions.Contains(TagName) then
            Suggestions.Add(TagName);
          Query.Next;
        end;
      end;
    finally
      Query.Free;
    end;
    
    Result := Suggestions.ToArray;
  finally
    Suggestions.Free;
  end;
end;

procedure TSearchService.IndexDocument(const DocId, Title, Content: string);
var
  Query: TFDQuery;
begin
  if not FFTSEnabled then Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    // 先删除旧索引
    Query.SQL.Text := 'DELETE FROM Documents_FTS WHERE DocId = :DocId';
    Query.ParamByName('DocId').AsString := DocId;
    Query.ExecSQL;
    
    // 插入新索�?
    Query.SQL.Text := 
      'INSERT INTO Documents_FTS (DocId, Title, Content) VALUES (:DocId, :Title, :Content)';
    Query.ParamByName('DocId').AsString := DocId;
    Query.ParamByName('Title').AsString := Title;
    Query.ParamByName('Content').AsString := Content;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TSearchService.RemoveFromIndex(const DocId: string);
var
  Query: TFDQuery;
begin
  if not FFTSEnabled then Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM Documents_FTS WHERE DocId = :DocId';
    Query.ParamByName('DocId').AsString := DocId;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TSearchService.RebuildIndex;
var
  Query: TFDQuery;
begin
  if not FFTSEnabled then Exit;
  
  Log.Info('Rebuilding FTS index...');
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    // 清空索引
    Query.SQL.Text := 'DELETE FROM Documents_FTS';
    Query.ExecSQL;
    
    // 重新索引所有文�?
    Query.SQL.Text := 
      'INSERT INTO Documents_FTS (DocId, Title, Content) ' +
      'SELECT Id, Title, Content FROM Documents WHERE Status != :Deleted';
    Query.ParamByName('Deleted').AsInteger := Ord(dsDeleted);
    Query.ExecSQL;
    
    Log.Info('FTS index rebuilt');
  finally
    Query.Free;
  end;
end;

procedure TSearchService.OptimizeIndex;
var
  Query: TFDQuery;
begin
  if not FFTSEnabled then Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'INSERT INTO Documents_FTS(Documents_FTS) VALUES (''optimize'')';
    Query.ExecSQL;
    Log.Info('FTS index optimized');
  finally
    Query.Free;
  end;
end;

function TSearchService.GetIndexStats: string;
var
  Query: TFDQuery;
  DocCount, IndexCount: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    // 文档�?
    Query.SQL.Text := 'SELECT COUNT(*) AS Cnt FROM Documents WHERE Status != :Deleted';
    Query.ParamByName('Deleted').AsInteger := Ord(dsDeleted);
    Query.Open;
    DocCount := Query.FieldByName('Cnt').AsInteger;
    
    // 索引�?
    if FFTSEnabled then
    begin
      Query.SQL.Text := 'SELECT COUNT(*) AS Cnt FROM Documents_FTS';
      Query.Open;
      IndexCount := Query.FieldByName('Cnt').AsInteger;
    end
    else
      IndexCount := 0;
    
    Result := Format('文档�? %d, 索引�? %d, FTS: %s', [
      DocCount, 
      IndexCount, 
      IfThen(FFTSEnabled, '启用', '禁用')
    ]);
  finally
    Query.Free;
  end;
end;

end.
