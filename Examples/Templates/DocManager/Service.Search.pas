unit Service.Search;

{*******************************************************************************
  Search Service - 鎼滅储鏈嶅姟

  DeepBase 妗嗘灦鏂囨。绠＄悊妯℃澘 - 鍏ㄦ枃鎼滅储鏈嶅姟
  浣跨敤 SQLite FTS5 瀹炵幇楂樻晥鍏ㄦ枃鎼滅储
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  FireDAC.Comp.Client,
  Entity.Document;

type
  /// <summary>
  /// 鎼滅储閫夐」
  /// </summary>
  TSearchOptions = record
    CategoryId: string;       // 闄愬畾鍒嗙被
    Tags: TArray<string>;     // 闄愬畾鏍囩
    DateFrom: TDateTime;      // 鏃ユ湡鑼冨洿璧峰
    DateTo: TDateTime;        // 鏃ユ湡鑼冨洿缁撴潫
    Status: TDocumentStatus;  // 鏂囨。鐘舵€?
    MaxResults: Integer;      // 鏈€澶х粨鏋滄暟
    IncludeContent: Boolean;  // 鎼滅储鍐呭
    IncludeTitle: Boolean;    // 鎼滅储鏍囬
    
    class function Default: TSearchOptions; static;
  end;

  /// <summary>
  /// 鎼滅储鏈嶅姟 - 浣跨敤 SQLite FTS5 鍏ㄦ枃鎼滅储
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

    /// <summary>鍒濆鍖?FTS 绱㈠紩琛?/summary>
    procedure InitializeFTS;

    /// <summary>妫€鏌?FTS 鏄惁鍙敤</summary>
    function IsFTSAvailable: Boolean;

    /// <summary>鍩烘湰鍏ㄦ枃鎼滅储</summary>
    function Search(const Query: string): TObjectList<TSearchResult>;

    /// <summary>楂樼骇鎼滅储锛堝甫閫夐」锛?/summary>
    function AdvancedSearch(const Query: string; 
      const Options: TSearchOptions): TObjectList<TSearchResult>;

    /// <summary>鎼滅储鏍囬</summary>
    function SearchByTitle(const Query: string): TObjectList<TSearchResult>;

    /// <summary>鑾峰彇鎼滅储寤鸿</summary>
    function GetSuggestions(const Prefix: string; 
      MaxCount: Integer = 10): TArray<string>;

    /// <summary>绱㈠紩鍗曚釜鏂囨。</summary>
    procedure IndexDocument(const DocId, Title, Content: string);

    /// <summary>浠庣储寮曚腑绉婚櫎鏂囨。</summary>
    procedure RemoveFromIndex(const DocId: string);

    /// <summary>閲嶅缓鍏ㄩ儴绱㈠紩</summary>
    procedure RebuildIndex;

    /// <summary>浼樺寲绱㈠紩</summary>
    procedure OptimizeIndex;

    /// <summary>鑾峰彇绱㈠紩缁熻</summary>
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
  
  // 妫€鏌ュ苟鍒濆鍖?FTS
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
      // 灏濊瘯鍒涘缓涓€涓复鏃?FTS5 琛ㄦ潵娴嬭瘯
      Query.SQL.Text := 'SELECT sqlite_version()';
      Query.Open;
      Result := True;  // SQLite 3.9+ 鏀寔 FTS5
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
    
    // 鍒涘缓 FTS5 铏氭嫙琛?
    Query.SQL.Text := 
      'CREATE VIRTUAL TABLE IF NOT EXISTS Documents_FTS USING fts5(' +
      '  DocId, ' +
      '  Title, ' +
      '  Content, ' +
      '  tokenize = "unicode61"' +  // 鏀寔 Unicode
      ')';
    Query.ExecSQL;
    
    // 鍒涘缓瑙﹀彂鍣細鎻掑叆
    Query.SQL.Text := 
      'CREATE TRIGGER IF NOT EXISTS Documents_AI AFTER INSERT ON Documents BEGIN ' +
      '  INSERT INTO Documents_FTS (DocId, Title, Content) ' +
      '  VALUES (NEW.Id, NEW.Title, NEW.Content); ' +
      'END';
    Query.ExecSQL;
    
    // 鍒涘缓瑙﹀彂鍣細鏇存柊
    Query.SQL.Text := 
      'CREATE TRIGGER IF NOT EXISTS Documents_AU AFTER UPDATE ON Documents BEGIN ' +
      '  UPDATE Documents_FTS SET Title = NEW.Title, Content = NEW.Content ' +
      '  WHERE DocId = NEW.Id; ' +
      'END';
    Query.ExecSQL;
    
    // 鍒涘缓瑙﹀彂鍣細鍒犻櫎
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
      // 浣跨敤 FTS5 鎼滅储
      SQL := 
        'SELECT d.Id, d.Title, d.Content, d.UpdatedAt, d.CategoryId, ' +
        '  c.Name AS CategoryName, ' +
        '  bm25(Documents_FTS) AS Score ' +
        'FROM Documents_FTS fts ' +
        'INNER JOIN Documents d ON fts.DocId = d.Id ' +
        'LEFT JOIN Categories c ON d.CategoryId = c.Id ' +
        'WHERE Documents_FTS MATCH :Query ' +
        '  AND d.Status = :Status ';
      
      // 娣诲姞鍒嗙被杩囨护
      if not Options.CategoryId.IsEmpty then
        SQL := SQL + 'AND d.CategoryId = :CategoryId ';
      
      // 娣诲姞鏃ユ湡杩囨护
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
      // 鍥為€€鍒?LIKE 鎼滅储
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
  // 鏋勫缓 FTS5 鏌ヨ璇硶
  // 鏀寔锛氬崟璇嶆悳绱€€佺煭璇悳绱紙寮曞彿锛夈€佸墠缂€鎼滅储锛?锛?
  
  Builder := TStringBuilder.Create;
  try
    // 鍒嗗壊鎼滅储璇?
    Terms := Query.Split([' '], TStringSplitOptions.ExcludeEmpty);
    
    for I := 0 to High(Terms) do
    begin
      if I > 0 then
        Builder.Append(' ');
      
      // 濡傛灉涓嶆槸鐭锛堝紩鍙峰寘鍥达級锛屾坊鍔犲墠缂€鍖归厤
      if not Terms[I].StartsWith('"') and not Terms[I].EndsWith('*') then
        Builder.Append(Terms[I] + '*')
      else
        Builder.Append(Terms[I]);
    end;
    
    // 闄愬畾鎼滅储鍒?
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
  
  // 鏌ユ壘绗竴涓尮閰嶈瘝鐨勪綅缃?
  Pos := -1;
  for var Term in Terms do
  begin
    Pos := LowerContent.IndexOf(Term);
    if Pos >= 0 then
      Break;
  end;
  
  if Pos < 0 then
  begin
    // 娌℃壘鍒板尮閰嶏紝杩斿洖寮€澶撮儴鍒?
    if Length(Content) <= MaxLength then
      Exit(Content)
    else
      Exit(Copy(Content, 1, MaxLength) + '...');
  end;
  
  // 璁＄畻鎽樿鑼冨洿
  StartPos := Max(0, Pos - MaxLength div 3);
  EndPos := Min(Length(Content), StartPos + MaxLength);
  
  // 灏濊瘯浠庡崟璇嶈竟鐣屽紑濮?
  while (StartPos > 0) and (Content[StartPos + 1] <> ' ') do
    Dec(StartPos);
  
  Result := '';
  if StartPos > 0 then
    Result := '...';
  
  Result := Result + Copy(Content, StartPos + 1, EndPos - StartPos);
  
  if EndPos < Length(Content) then
    Result := Result + '...';
  
  // 绉婚櫎鎹㈣
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
      // 娣诲姞楂樹寒鏍囪
      Result := Copy(Result, 1, Pos) + 
                '<mark>' + Copy(Result, Pos + 1, Length(Term)) + '</mark>' +
                Copy(Result, Pos + Length(Term) + 1, Length(Result));
      
      // 缁х画鏌ユ壘涓嬩竴涓?
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
      
      // 浠庢爣棰樹腑鎻愬彇寤鸿
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
      
      // 濡傛灉寤鸿涓嶈冻锛屼粠鏍囩涓ˉ鍏?
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
    
    // 鍏堝垹闄ゆ棫绱㈠紩
    Query.SQL.Text := 'DELETE FROM Documents_FTS WHERE DocId = :DocId';
    Query.ParamByName('DocId').AsString := DocId;
    Query.ExecSQL;
    
    // 鎻掑叆鏂扮储寮?
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
    
    // 娓呯┖绱㈠紩
    Query.SQL.Text := 'DELETE FROM Documents_FTS';
    Query.ExecSQL;
    
    // 閲嶆柊绱㈠紩鎵€鏈夋枃妗?
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
    
    // 鏂囨。鏁?
    Query.SQL.Text := 'SELECT COUNT(*) AS Cnt FROM Documents WHERE Status != :Deleted';
    Query.ParamByName('Deleted').AsInteger := Ord(dsDeleted);
    Query.Open;
    DocCount := Query.FieldByName('Cnt').AsInteger;
    
    // 绱㈠紩鏁?
    if FFTSEnabled then
    begin
      Query.SQL.Text := 'SELECT COUNT(*) AS Cnt FROM Documents_FTS';
      Query.Open;
      IndexCount := Query.FieldByName('Cnt').AsInteger;
    end
    else
      IndexCount := 0;
    
    Result := Format('鏂囨。鏁? %d, 绱㈠紩鏁? %d, FTS: %s', [
      DocCount, 
      IndexCount, 
      IfThen(FFTSEnabled, '鍚敤', '绂佺敤')
    ]);
  finally
    Query.Free;
  end;
end;

end.
