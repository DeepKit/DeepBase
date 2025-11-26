{ ============================================================================
  UniBase.i18n - 国际化模块
  
  版本: 0.3
  说明: 提供国际化翻译功能，带 LRU 缓存和线程安全保护
  线程安全: 所有公共方法均线程安全
  ============================================================================ }

unit UniBase.i18n;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  UniBase.Types;

const
  DEFAULT_CACHE_CAPACITY = 10000;

type
  /// <summary>
  /// LRU 缓存项
  /// </summary>
  TLRUCacheItem = record
    Value: string;
    LastAccess: TDateTime;
  end;

  /// <summary>
  /// 国际化管理器
  /// </summary>
  TUniBaseI18n = class
  private
    FConnection: TFDConnection;
    FLock: TObject;
    FCache: TDictionary<string, TLRUCacheItem>;
    FCacheCapacity: Integer;
    FCurrentLanguage: string;
    FOnLanguageChanged: TNotifyEvent;
    
    function MakeCacheKey(const SourceText, LangCode: string): string;
    function ReadFromDB(const SourceText, LangCode: string): string;
    procedure EvictOldestIfNeeded;
    procedure RecordMissingTranslation(const SourceText, LangCode: string);
    
  public
    constructor Create(AConnection: TFDConnection; ALock: TObject);
    destructor Destroy; override;
    
    /// <summary>清空缓存</summary>
    procedure ClearCache;
    
    /// <summary>预加载指定语言的翻译到缓存</summary>
    procedure PreloadCache(const LangCode: string);
    
    // ========================================
    // 翻译方法
    // ========================================
    
    /// <summary>
    /// 翻译文本（使用当前语言）
    /// </summary>
    function Translate(const Text: string): string;
    
    /// <summary>
    /// 翻译文本（指定语言）
    /// </summary>
    function TranslateTo(const Text, LangCode: string): string;
    
    /// <summary>
    /// 格式化翻译文本
    /// </summary>
    function TranslateFormat(const Text: string; const Args: array of const): string;
    
    /// <summary>
    /// 复数形式翻译
    /// </summary>
    function TranslatePlural(const Singular, Plural: string; Count: Integer): string;
    
    // ========================================
    // 语言管理
    // ========================================
    
    /// <summary>
    /// 获取所有可用语言
    /// </summary>
    function GetAvailableLanguages: TLanguageInfoArray;
    
    /// <summary>
    /// 获取已启用的语言
    /// </summary>
    function GetEnabledLanguages: TLanguageInfoArray;
    
    /// <summary>
    /// 获取默认语言
    /// </summary>
    function GetDefaultLanguage: string;
    
    // ========================================
    // 属性
    // ========================================
    
    /// <summary>当前语言代码</summary>
    property CurrentLanguage: string read FCurrentLanguage write FCurrentLanguage;
    
    /// <summary>缓存容量</summary>
    property CacheCapacity: Integer read FCacheCapacity write FCacheCapacity;
    
    /// <summary>语言变更事件</summary>
    property OnLanguageChanged: TNotifyEvent read FOnLanguageChanged write FOnLanguageChanged;
  end;

/// <summary>
/// 全局翻译函数（快捷方式）
/// </summary>
function T(const Text: string): string;

/// <summary>
/// 全局格式化翻译函数
/// </summary>
function TFmt(const Text: string; const Args: array of const): string;

/// <summary>
/// 全局复数翻译函数
/// </summary>
function TN(const Singular, Plural: string; Count: Integer): string;

implementation

uses
  System.DateUtils,
  UniBase.Manager;

{ 全局函数实现 }

function T(const Text: string): string;
begin
  if UniBase.Manager.UniBase.IsInitialized then
  begin
    // 使用 Manager 的简化方式，避免依赖内部模块
    // 后续集成时会通过 Manager 调用 i18n 模块
    Result := Text; // 临时实现
  end
  else
    Result := Text;
end;

function TFmt(const Text: string; const Args: array of const): string;
begin
  Result := Format(T(Text), Args);
end;

function TN(const Singular, Plural: string; Count: Integer): string;
begin
  if Count = 1 then
    Result := T(Singular)
  else
    Result := T(Plural);
end;

{ TUniBaseI18n }

constructor TUniBaseI18n.Create(AConnection: TFDConnection; ALock: TObject);
begin
  inherited Create;
  FConnection := AConnection;
  FLock := ALock;
  FCache := TDictionary<string, TLRUCacheItem>.Create;
  FCacheCapacity := DEFAULT_CACHE_CAPACITY;
  FCurrentLanguage := 'en-US';
end;

destructor TUniBaseI18n.Destroy;
begin
  FCache.Free;
  inherited;
end;

function TUniBaseI18n.MakeCacheKey(const SourceText, LangCode: string): string;
begin
  Result := LangCode + #1 + SourceText;
end;

procedure TUniBaseI18n.ClearCache;
begin
  TMonitor.Enter(FLock);
  try
    FCache.Clear;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseI18n.PreloadCache(const LangCode: string);
var
  Query: TFDQuery;
  CacheKey: string;
  Item: TLRUCacheItem;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT SourceText, TranslatedText FROM I18nTexts WHERE LangCode = :LangCode';
      Query.ParamByName('LangCode').AsString := LangCode;
      Query.Open;
      
      while not Query.Eof do
      begin
        CacheKey := MakeCacheKey(Query.FieldByName('SourceText').AsString, LangCode);
        Item.Value := Query.FieldByName('TranslatedText').AsString;
        Item.LastAccess := Now;
        FCache.AddOrSetValue(CacheKey, Item);
        Query.Next;
      end;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseI18n.EvictOldestIfNeeded;
var
  OldestKey: string;
  OldestTime: TDateTime;
  Pair: TPair<string, TLRUCacheItem>;
begin
  // 已在锁内调用
  if FCache.Count < FCacheCapacity then
    Exit;
    
  // 查找最旧的条目
  OldestTime := MaxDateTime;
  OldestKey := '';
  
  for Pair in FCache do
  begin
    if Pair.Value.LastAccess < OldestTime then
    begin
      OldestTime := Pair.Value.LastAccess;
      OldestKey := Pair.Key;
    end;
  end;
  
  if OldestKey <> '' then
    FCache.Remove(OldestKey);
end;

function TUniBaseI18n.ReadFromDB(const SourceText, LangCode: string): string;
var
  Query: TFDQuery;
begin
  Result := '';
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'SELECT TranslatedText FROM I18nTexts ' +
      'WHERE SourceText = :SourceText AND LangCode = :LangCode';
    Query.ParamByName('SourceText').AsString := SourceText;
    Query.ParamByName('LangCode').AsString := LangCode;
    Query.Open;
    
    if not Query.Eof then
      Result := Query.FieldByName('TranslatedText').AsString;
  finally
    Query.Free;
  end;
end;

procedure TUniBaseI18n.RecordMissingTranslation(const SourceText, LangCode: string);
var
  Query: TFDQuery;
begin
  // 记录缺失的翻译（用于后续翻译）
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 
        'INSERT OR IGNORE INTO I18nTexts (SourceText, LangCode, LastUsedTime) ' +
        'VALUES (:SourceText, :LangCode, datetime(''now''))';
      Query.ParamByName('SourceText').AsString := SourceText;
      Query.ParamByName('LangCode').AsString := LangCode;
      Query.ExecSQL;
      
      // 更新最后使用时间
      Query.SQL.Text := 
        'UPDATE I18nTexts SET LastUsedTime = datetime(''now'') ' +
        'WHERE SourceText = :SourceText AND LangCode = :LangCode';
      Query.ParamByName('SourceText').AsString := SourceText;
      Query.ParamByName('LangCode').AsString := LangCode;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  except
    // 忽略记录失败（非关键操作）
  end;
end;

function TUniBaseI18n.Translate(const Text: string): string;
begin
  Result := TranslateTo(Text, FCurrentLanguage);
end;

function TUniBaseI18n.TranslateTo(const Text, LangCode: string): string;
var
  CacheKey: string;
  Item: TLRUCacheItem;
begin
  // 英文原文不需要翻译（英文是源语言）
  if LangCode = 'en-US' then
  begin
    Result := Text;
    Exit;
  end;
  
  TMonitor.Enter(FLock);
  try
    CacheKey := MakeCacheKey(Text, LangCode);
    
    // 查缓存
    if FCache.TryGetValue(CacheKey, Item) then
    begin
      // 更新访问时间
      Item.LastAccess := Now;
      FCache.AddOrSetValue(CacheKey, Item);
      
      if Item.Value <> '' then
        Result := Item.Value
      else
        Result := Text; // 翻译为空，返回原文
      Exit;
    end;
    
    // 查数据库
    Result := ReadFromDB(Text, LangCode);
    
    // 缓存结果（即使为空也缓存，避免重复查询）
    EvictOldestIfNeeded;
    Item.Value := Result;
    Item.LastAccess := Now;
    FCache.AddOrSetValue(CacheKey, Item);
    
    // 如果没找到翻译，返回原文并记录
    if Result = '' then
    begin
      Result := Text;
      // 异步记录缺失翻译（在锁外执行）
    end;
  finally
    TMonitor.Exit(FLock);
  end;
  
  // 在锁外记录缺失翻译
  if Result = Text then
    RecordMissingTranslation(Text, LangCode);
end;

function TUniBaseI18n.TranslateFormat(const Text: string; const Args: array of const): string;
begin
  Result := Format(Translate(Text), Args);
end;

function TUniBaseI18n.TranslatePlural(const Singular, Plural: string; Count: Integer): string;
begin
  // 简单的复数处理（英语规则）
  // TODO: 支持更复杂的复数规则（如俄语）
  if Count = 1 then
    Result := Format(Translate(Singular), [Count])
  else
    Result := Format(Translate(Plural), [Count]);
end;

function TUniBaseI18n.GetAvailableLanguages: TLanguageInfoArray;
var
  Query: TFDQuery;
  List: TList<TLanguageInfo>;
  Info: TLanguageInfo;
begin
  SetLength(Result, 0);
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    List := TList<TLanguageInfo>.Create;
    try
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := FConnection;
        Query.SQL.Text := 'SELECT * FROM Languages ORDER BY SortOrder';
        Query.Open;
        
        while not Query.Eof do
        begin
          Info.LangCode := Query.FieldByName('LangCode').AsString;
          Info.LangName := Query.FieldByName('LangName').AsString;
          Info.NativeName := Query.FieldByName('NativeName').AsString;
          Info.FlagIcon := Query.FieldByName('FlagIcon').AsString;
          Info.IsEnabled := Query.FieldByName('IsEnabled').AsInteger = 1;
          Info.IsDefault := Query.FieldByName('IsDefault').AsInteger = 1;
          List.Add(Info);
          Query.Next;
        end;
      finally
        Query.Free;
      end;
      
      Result := List.ToArray;
    finally
      List.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseI18n.GetEnabledLanguages: TLanguageInfoArray;
var
  Query: TFDQuery;
  List: TList<TLanguageInfo>;
  Info: TLanguageInfo;
begin
  SetLength(Result, 0);
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    List := TList<TLanguageInfo>.Create;
    try
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := FConnection;
        Query.SQL.Text := 'SELECT * FROM Languages WHERE IsEnabled = 1 ORDER BY SortOrder';
        Query.Open;
        
        while not Query.Eof do
        begin
          Info.LangCode := Query.FieldByName('LangCode').AsString;
          Info.LangName := Query.FieldByName('LangName').AsString;
          Info.NativeName := Query.FieldByName('NativeName').AsString;
          Info.FlagIcon := Query.FieldByName('FlagIcon').AsString;
          Info.IsEnabled := True;
          Info.IsDefault := Query.FieldByName('IsDefault').AsInteger = 1;
          List.Add(Info);
          Query.Next;
        end;
      finally
        Query.Free;
      end;
      
      Result := List.ToArray;
    finally
      List.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseI18n.GetDefaultLanguage: string;
var
  Query: TFDQuery;
begin
  Result := 'en-US'; // 默认返回英文
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT LangCode FROM Languages WHERE IsDefault = 1 LIMIT 1';
      Query.Open;
      
      if not Query.Eof then
        Result := Query.FieldByName('LangCode').AsString;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
