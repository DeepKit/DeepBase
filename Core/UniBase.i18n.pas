{ ============================================================================
  UniBase.i18n - Internationalization Module
  
  Version: 0.3
  Description: Provides i18n translation with LRU cache and thread-safe
               protection.
  Thread Safety: All public methods are thread-safe.
  ============================================================================ }

unit UniBase.i18n;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  UniBase.Types,
  UniBase.Consts,
  UniBase.Interfaces;

const
  DEFAULT_CACHE_CAPACITY = 10000;

type
  /// <summary>
  /// LRU cache item
  /// </summary>
  TLRUCacheItem = record
    Value: string;
    LastAccess: TDateTime;
  end;

  /// <summary>
  /// I18n manager with LRU cache and multicast language change notifications.
  /// Implements IUniBaseI18n for dependency injection and testing.
  /// </summary>
  TUniBaseI18n = class(TInterfacedObject, IUniBaseI18n)
  private
    FConnection: TFDConnection;
    FLock: TObject;
    FCache: TDictionary<string, TLRUCacheItem>;
    FCacheCapacity: Integer;
    FCurrentLanguage: string;
    FOnLanguageChanged: TNotifyEvent;
    FLanguageChangeListeners: TList<TNotifyEvent>;

    function MakeCacheKey(const SourceText, LangCode: string): string;
    function ReadFromDB(const SourceText, LangCode: string): string;
    procedure EvictOldestIfNeeded;
    procedure RecordMissingTranslation(const SourceText, LangCode: string);
    function GetCurrentLanguage: string;
    procedure SetCurrentLanguage(const Value: string);

  public
    constructor Create(AConnection: TFDConnection; ALock: TObject);
    destructor Destroy; override;
    
    /// <summary>Clear cache</summary>
    procedure ClearCache;
    
    /// <summary>Preload translations for specified language</summary>
    procedure PreloadCache(const LangCode: string);
    
    // ========================================
    // Translation Methods
    // ========================================
    
    /// <summary>
    /// Translate text using current language
    /// </summary>
    function Translate(const Text: string): string;
    
    /// <summary>
    /// Translate text to specified language
    /// </summary>
    function TranslateTo(const Text, LangCode: string): string;
    
    /// <summary>
    /// Format and translate text
    /// </summary>
    function TranslateFormat(const Text: string; const Args: array of const): string;
    
    /// <summary>
    /// Plural form translation
    /// </summary>
    function TranslatePlural(const Singular, Plural: string; Count: Integer): string;
    
    // ========================================
    // Language Management
    // ========================================
    
    /// <summary>
    /// Get all available languages
    /// </summary>
    function GetAvailableLanguages: TLanguageInfoArray;
    
    /// <summary>
    /// Get enabled languages
    /// </summary>
    function GetEnabledLanguages: TLanguageInfoArray;
    
    /// <summary>
    /// Get default language
    /// </summary>
    function GetDefaultLanguage: string;
    
    /// <summary>
    /// Add or update a translation (useful for demos and runtime additions)
    /// </summary>
    procedure AddTranslation(const SourceText, LangCode, TranslatedText: string);
    
    // ========================================
    // Properties
    // ========================================
    
    /// <summary>Current language code</summary>
    property CurrentLanguage: string read GetCurrentLanguage write SetCurrentLanguage;
    
    /// <summary>Cache capacity</summary>
    property CacheCapacity: Integer read FCacheCapacity write FCacheCapacity;
    
    /// <summary>Language changed event (single-cast, for backward compatibility)</summary>
    property OnLanguageChanged: TNotifyEvent read FOnLanguageChanged write FOnLanguageChanged;
    
    /// <summary>Subscribe to language change notifications (multicast)</summary>
    procedure SubscribeLanguageChange(AHandler: TNotifyEvent);
    
    /// <summary>Unsubscribe from language change notifications</summary>
    procedure UnsubscribeLanguageChange(AHandler: TNotifyEvent);
    
    /// <summary>Notify all subscribers of language change</summary>
    procedure NotifyLanguageChanged;
  end;

/// <summary>
/// Global translate function (shorthand)
/// </summary>
function T(const Text: string): string;

/// <summary>
/// Global format and translate function
/// </summary>
function TFmt(const Text: string; const Args: array of const): string;

/// <summary>
/// Global plural translation function
/// </summary>
function TN(const Singular, Plural: string; Count: Integer): string;

type
  /// <summary>
  /// Translate callback function type
  /// </summary>
  TTranslateCallback = reference to function(const Text: string): string;

/// <summary>
/// Set the global translate callback (called by TUniBaseManager during init).
/// This decouples i18n from Manager to avoid circular references.
/// </summary>
procedure SetGlobalTranslateCallback(ACallback: TTranslateCallback);

/// <summary>
/// Check if global translate callback is set
/// </summary>
function IsTranslateCallbackSet: Boolean;

type
  /// <summary>
  /// Language getter callback for plural rules
  /// </summary>
  TGetCurrentLanguageFunc = reference to function: string;

/// <summary>
/// Set the global language getter callback
/// </summary>
procedure SetGlobalLanguageCallback(ACallback: TGetCurrentLanguageFunc);

implementation

uses
  System.DateUtils,
  UniBase.i18n.Plural
  {$IFDEF MSWINDOWS}
  , Winapi.Windows
  {$ENDIF}
  ;

var
  GTranslateCallback: TTranslateCallback = nil;
  GLanguageCallback: TGetCurrentLanguageFunc = nil;

procedure SetGlobalTranslateCallback(ACallback: TTranslateCallback);
begin
  GTranslateCallback := ACallback;
end;

function IsTranslateCallbackSet: Boolean;
begin
  Result := Assigned(GTranslateCallback);
end;

procedure SetGlobalLanguageCallback(ACallback: TGetCurrentLanguageFunc);
begin
  GLanguageCallback := ACallback;
end;

function GetCurrentLanguageCode: string;
begin
  if Assigned(GLanguageCallback) then
    Result := GLanguageCallback
  else
    Result := 'en';  // Default to English
end;

{ Global function implementations }

/// <summary>
/// Translate text using global callback.
/// IMPORTANT: This function uses a volatile pattern to prevent constant folding.
/// The compiler may otherwise optimize T('literal') to a constant at compile time,
/// which would bypass runtime translation lookup.
/// </summary>
{$OPTIMIZATION OFF}
function T(const Text: string): string;
var
  LText: string;  // Local copy prevents compile-time evaluation
begin
  LText := Text;  // Force runtime copy
  if Assigned(GTranslateCallback) then
    Result := GTranslateCallback(LText)
  else
    Result := LText;  // Fallback: return original text
end;
{$OPTIMIZATION ON}

function TFmt(const Text: string; const Args: array of const): string;
begin
  Result := Format(T(Text), Args);
end;

function TN(const Singular, Plural: string; Count: Integer): string;
var
  LangCode: string;
  Forms: array of string;
begin
  LangCode := GetCurrentLanguageCode;
  
  // Use CLDR plural rules for proper localization
  // Most languages use [singular, plural] forms
  // Some languages (like Russian) need more forms
  SetLength(Forms, 2);
  Forms[0] := T(Singular);  // for 'one' category
  Forms[1] := T(Plural);    // for 'other' category
  
  Result := PluralSelect(LangCode, Count, Forms);
end;

{ TUniBaseI18n }

function TUniBaseI18n.GetCurrentLanguage: string;
begin
  Result := FCurrentLanguage;
end;

procedure TUniBaseI18n.SetCurrentLanguage(const Value: string);
begin
  FCurrentLanguage := Value;
end;

constructor TUniBaseI18n.Create(AConnection: TFDConnection; ALock: TObject);
begin
  inherited Create;
  FConnection := AConnection;
  FLock := ALock;
  FCache := TDictionary<string, TLRUCacheItem>.Create;
  FLanguageChangeListeners := TList<TNotifyEvent>.Create;
  FCacheCapacity := DEFAULT_CACHE_CAPACITY;
  FCurrentLanguage := SDefaultLanguage;
end;

destructor TUniBaseI18n.Destroy;
begin
  FLanguageChangeListeners.Free;
  FCache.Free;
  inherited;
end;

procedure TUniBaseI18n.SubscribeLanguageChange(AHandler: TNotifyEvent);
begin
  TMonitor.Enter(FLock);
  try
    if not FLanguageChangeListeners.Contains(AHandler) then
      FLanguageChangeListeners.Add(AHandler);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseI18n.UnsubscribeLanguageChange(AHandler: TNotifyEvent);
begin
  TMonitor.Enter(FLock);
  try
    FLanguageChangeListeners.Remove(AHandler);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseI18n.NotifyLanguageChanged;
var
  Handler: TNotifyEvent;
  Listeners: TArray<TNotifyEvent>;
  I: Integer;
begin
  // Copy listeners to avoid lock during notification
  TMonitor.Enter(FLock);
  try
    Listeners := FLanguageChangeListeners.ToArray;
  finally
    TMonitor.Exit(FLock);
  end;
  
  // Notify all multicast listeners
  for I := 0 to High(Listeners) do
  begin
    Handler := Listeners[I];
    if Assigned(Handler) then
      Handler(Self);
  end;
  
  // Also call the single-cast event for backward compatibility
  if Assigned(FOnLanguageChanged) then
    FOnLanguageChanged(Self);
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
  // Called within lock
  if FCache.Count < FCacheCapacity then
    Exit;
    
  // Find oldest entry
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
  NowStr: string;
begin
  // Record missing translation for later processing
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  try
    // Use ISO8601 format for SQLite datetime compatibility
    NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 
        'INSERT OR IGNORE INTO I18nTexts (SourceText, LangCode, LastUsedTime) ' +
        'VALUES (:SourceText, :LangCode, :LastUsedTime)';
      Query.ParamByName('SourceText').AsString := SourceText;
      Query.ParamByName('LangCode').AsString := LangCode;
      Query.ParamByName('LastUsedTime').AsString := NowStr;
      Query.ExecSQL;
      
      // Update last used time
      Query.SQL.Text := 
        'UPDATE I18nTexts SET LastUsedTime = :LastUsedTime ' +
        'WHERE SourceText = :SourceText AND LangCode = :LangCode';
      Query.ParamByName('SourceText').AsString := SourceText;
      Query.ParamByName('LangCode').AsString := LangCode;
      Query.ParamByName('LastUsedTime').AsString := NowStr;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  except
    on E: Exception do
    begin
      // 记录缺失翻译失败（非关键操作），使用OutputDebugString避免循环依赖
      {$IFDEF DEBUG}
      OutputDebugString(PChar('UniBase.i18n RecordMissingTranslation failed: ' + E.Message));
      {$ENDIF}
    end;
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
  // English source text doesn't need translation
  if LangCode = SLangCodeEnUS then
  begin
    Result := Text;
    Exit;
  end;
  
  TMonitor.Enter(FLock);
  try
    CacheKey := MakeCacheKey(Text, LangCode);
    
    // Check cache
    if FCache.TryGetValue(CacheKey, Item) then
    begin
      // Update access time
      Item.LastAccess := Now;
      FCache.AddOrSetValue(CacheKey, Item);
      
      if Item.Value <> '' then
        Result := Item.Value
      else
        Result := Text; // Empty translation, return original
      Exit;
    end;
    
    // Query database
    Result := ReadFromDB(Text, LangCode);
    
    // Cache result (even if empty to avoid repeated queries)
    EvictOldestIfNeeded;
    Item.Value := Result;
    Item.LastAccess := Now;
    FCache.AddOrSetValue(CacheKey, Item);
    
    // If no translation found, return original and record
    if Result = '' then
    begin
      Result := Text;
      // Record missing translation outside lock
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
var
  Forms: array of string;
  Selected: string;
begin
  // Use CLDR plural rules for proper localization
  SetLength(Forms, 2);
  Forms[0] := Translate(Singular);  // for 'one' category
  Forms[1] := Translate(Plural);    // for 'other' category
  
  Selected := PluralSelect(FCurrentLanguage, Count, Forms);
  Result := Format(Selected, [Count]);
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
  Result := 'en-US'; // Default to English
  
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

procedure TUniBaseI18n.AddTranslation(const SourceText, LangCode, TranslatedText: string);
var
  Query: TFDQuery;
  CacheKey: string;
  Item: TLRUCacheItem;
  NowStr: string;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    // Use ISO8601 format for SQLite datetime compatibility
    NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      // Insert or replace translation
      Query.SQL.Text := 
        'INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, LastUsedTime) ' +
        'VALUES (:SourceText, :LangCode, :TranslatedText, :LastUsedTime)';
      Query.ParamByName('SourceText').AsString := SourceText;
      Query.ParamByName('LangCode').AsString := LangCode;
      Query.ParamByName('TranslatedText').AsString := TranslatedText;
      Query.ParamByName('LastUsedTime').AsString := NowStr;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
    
    // Update cache
    CacheKey := MakeCacheKey(SourceText, LangCode);
    Item.Value := TranslatedText;
    Item.LastAccess := Now;
    FCache.AddOrSetValue(CacheKey, Item);
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
