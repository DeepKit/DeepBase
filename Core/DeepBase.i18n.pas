{ ============================================================================
  DeepBase.i18n - Internationalization Module
  
  Version: 0.3
  Description: Provides i18n translation with LRU cache and thread-safe
               protection.
  Thread Safety: All public methods are thread-safe.
  ============================================================================ }

unit DeepBase.i18n;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DeepBase.Types,
  DeepBase.Consts,
  DeepBase.Interfaces,
  DeepBase.Storage.Interfaces;

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
  /// Implements IDeepBaseI18n for dependency injection and testing.
  /// </summary>
  TDeepBaseI18n = class(TInterfacedObject, IDeepBaseI18n)
  private
    FConnection: TObject;
    FStorage: II18nStorage;
    FLock: TObject;
    FOwnsLock: Boolean;
    FCache: TDictionary<string, TLRUCacheItem>;
    FCacheCapacity: Integer;
    FCurrentLanguage: string;
    FOnLanguageChanged: TNotifyEvent;
    FLanguageChangeListeners: TList<TNotifyEvent>;
    class var FConnectionStorageFactory: TFunc<TObject, II18nStorage>;

    function MakeCacheKey(const SourceText, LangCode: string): string;
    function ReadFromDB(const SourceText, LangCode: string): string;
    procedure EvictOldestIfNeeded;
    procedure RecordMissingTranslation(const SourceText, LangCode: string);
    function GetCurrentLanguage: string;
    procedure SetCurrentLanguage(const Value: string);
    class function CreateStorageFromConnection(
      AConnection: TObject): II18nStorage; static;

  public
    constructor Create(AConnection: TObject;
      ALock: TObject = nil); overload;
    constructor Create(const AStorage: II18nStorage;
      ALock: TObject = nil); overload;
    destructor Destroy; override;

    class procedure SetConnectionStorageFactory(
      const AFactory: TFunc<TObject, II18nStorage>); static;
    
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
/// Set the global translate callback (called by TDeepBaseManager during init).
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
  DeepBase.i18n.Plural
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

{ TDeepBaseI18n }

function TDeepBaseI18n.GetCurrentLanguage: string;
begin
  Result := FCurrentLanguage;
end;

procedure TDeepBaseI18n.SetCurrentLanguage(const Value: string);
begin
  FCurrentLanguage := Value;
end;

constructor TDeepBaseI18n.Create(AConnection: TObject; ALock: TObject);
begin
  Create(CreateStorageFromConnection(AConnection), ALock);
  FConnection := AConnection;
end;

constructor TDeepBaseI18n.Create(const AStorage: II18nStorage; ALock: TObject);
begin
  inherited Create;
  FStorage := AStorage;
  if Assigned(ALock) then
  begin
    FLock := ALock;
    FOwnsLock := False;
  end
  else
  begin
    FLock := TObject.Create;
    FOwnsLock := True;
  end;
  FCache := TDictionary<string, TLRUCacheItem>.Create;
  FLanguageChangeListeners := TList<TNotifyEvent>.Create;
  FCacheCapacity := DEFAULT_CACHE_CAPACITY;
  FCurrentLanguage := SDefaultLanguage;
end;

destructor TDeepBaseI18n.Destroy;
begin
  if FOwnsLock then
    FreeAndNil(FLock);
  FreeAndNil(FLanguageChangeListeners);
  FreeAndNil(FCache);
  inherited;
end;

class procedure TDeepBaseI18n.SetConnectionStorageFactory(
  const AFactory: TFunc<TObject, II18nStorage>);
begin
  FConnectionStorageFactory := AFactory;
end;

class function TDeepBaseI18n.CreateStorageFromConnection(
  AConnection: TObject): II18nStorage;
begin
  Result := nil;
  if Assigned(AConnection) and Assigned(FConnectionStorageFactory) then
    Result := FConnectionStorageFactory(AConnection);
  if (Result = nil) and Assigned(AConnection) then
    raise EInvalidOp.Create(
      'No i18n storage factory registered for connection-backed constructor. ' +
      'Include DeepBase.Persistence.I18n.FireDAC or DeepBase.Persistence.Manager.FireDAC.');
end;

procedure TDeepBaseI18n.SubscribeLanguageChange(AHandler: TNotifyEvent);
begin
  TMonitor.Enter(FLock);
  try
    if not FLanguageChangeListeners.Contains(AHandler) then
      FLanguageChangeListeners.Add(AHandler);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseI18n.UnsubscribeLanguageChange(AHandler: TNotifyEvent);
begin
  TMonitor.Enter(FLock);
  try
    FLanguageChangeListeners.Remove(AHandler);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseI18n.NotifyLanguageChanged;
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

function TDeepBaseI18n.MakeCacheKey(const SourceText, LangCode: string): string;
begin
  Result := LangCode + #1 + SourceText;
end;

procedure TDeepBaseI18n.ClearCache;
begin
  TMonitor.Enter(FLock);
  try
    FCache.Clear;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseI18n.PreloadCache(const LangCode: string);
var
  Translations: TDictionary<string, string>;
  Pair: TPair<string, string>;
  CacheKey: string;
  Item: TLRUCacheItem;
begin
  if not Assigned(FStorage) then
    Exit;

  Translations := FStorage.ReadTranslations(LangCode);
  try
    TMonitor.Enter(FLock);
    try
      for Pair in Translations do
      begin
        CacheKey := MakeCacheKey(Pair.Key, LangCode);
        Item.Value := Pair.Value;
        Item.LastAccess := Now;
        FCache.AddOrSetValue(CacheKey, Item);
      end;
    finally
      TMonitor.Exit(FLock);
    end;
  finally
    Translations.Free;
  end;
end;

procedure TDeepBaseI18n.EvictOldestIfNeeded;
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

function TDeepBaseI18n.ReadFromDB(const SourceText, LangCode: string): string;
begin
  if Assigned(FStorage) then
    Result := FStorage.ReadTranslation(SourceText, LangCode)
  else
    Result := '';
end;

procedure TDeepBaseI18n.RecordMissingTranslation(const SourceText, LangCode: string);
begin
  // Record missing translation for later processing
  if not Assigned(FStorage) then
    Exit;
    
  try
    FStorage.RecordMissingTranslation(SourceText, LangCode);
  except
    on E: Exception do
    begin
      // ��¼ȱʧ����ʧ�ܣ��ǹؼ���������ʹ��OutputDebugString����ѭ������
      {$IFDEF DEBUG}
      OutputDebugString(PChar('DeepBase.i18n RecordMissingTranslation failed: ' + E.Message));
      {$ENDIF}
    end;
  end;
end;

function TDeepBaseI18n.Translate(const Text: string): string;
begin
  Result := TranslateTo(Text, FCurrentLanguage);
end;

function TDeepBaseI18n.TranslateTo(const Text, LangCode: string): string;
var
  CacheKey: string;
  Item: TLRUCacheItem;
  CacheHit: Boolean;
  NeedRecord: Boolean;
begin
  // English source text doesn't need translation
  if LangCode = SLangCodeEnUS then
  begin
    Result := Text;
    Exit;
  end;
  
  CacheKey := MakeCacheKey(Text, LangCode);
  CacheHit := False;
  NeedRecord := False;
  
  // �������ĳ���ʱ�� - �ȼ�黺��
  TMonitor.Enter(FLock);
  try
    if FCache.TryGetValue(CacheKey, Item) then
    begin
      CacheHit := True;
      // Update access time
      Item.LastAccess := Now;
      FCache.AddOrSetValue(CacheKey, Item);
      
      if Item.Value <> '' then
        Result := Item.Value
      else
        Result := Text; // Empty translation, return original
    end;
  finally
    TMonitor.Exit(FLock);
  end;
  
  // �������У�ֱ�ӷ���
  if CacheHit then
    Exit;
  
  // ����δ���У���ѯ���ݿ⣨��������У�
  Result := ReadFromDB(Text, LangCode);
  
  // ���»��棨���»�ȡ����������ʱ����̣�
  // »棨»ȡʱ̣
  // IMPORTANT: do NOT cache empty results so that the next call
  // re-queries the DB (which may have become available later).
  if Result <> '' then
  begin
    TMonitor.Enter(FLock);
    try
      EvictOldestIfNeeded;
      Item.Value := Result;
      Item.LastAccess := Now;
      FCache.AddOrSetValue(CacheKey, Item);
    finally
      TMonitor.Exit(FLock);
    end;
  end
  else
  begin
    Result := Text;
    NeedRecord := True;
  end;
  
  // �������¼ȱʧ����
  if NeedRecord then
    RecordMissingTranslation(Text, LangCode);
end;

function TDeepBaseI18n.TranslateFormat(const Text: string; const Args: array of const): string;
begin
  Result := Format(Translate(Text), Args);
end;

function TDeepBaseI18n.TranslatePlural(const Singular, Plural: string; Count: Integer): string;
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

function TDeepBaseI18n.GetAvailableLanguages: TLanguageInfoArray;
begin
  SetLength(Result, 0);
  if not Assigned(FStorage) then
    Exit;

  TMonitor.Enter(FLock);
  try
    Result := FStorage.ReadLanguages(False);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseI18n.GetEnabledLanguages: TLanguageInfoArray;
begin
  SetLength(Result, 0);
  if not Assigned(FStorage) then
    Exit;

  TMonitor.Enter(FLock);
  try
    Result := FStorage.ReadLanguages(True);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseI18n.GetDefaultLanguage: string;
begin
  Result := 'en-US'; // Default to English
  if not Assigned(FStorage) then
    Exit;

  TMonitor.Enter(FLock);
  try
    Result := FStorage.ReadDefaultLanguage(Result);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseI18n.AddTranslation(const SourceText, LangCode, TranslatedText: string);
var
  CacheKey: string;
  Item: TLRUCacheItem;
begin
  if not Assigned(FStorage) then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    FStorage.UpsertTranslation(SourceText, LangCode, TranslatedText);

    // Update cache
    CacheKey := MakeCacheKey(SourceText, LangCode);
    Item.Value := TranslatedText;
    Item.LastAccess := Now;
    FCache.AddOrSetValue(CacheKey, Item);
  finally
    TMonitor.Exit(FLock);
  end;
end;

// BUG-003 FIX: ����ȫ�ֻص����ã���ֹѭ�����õ����ڴ�й©
initialization

finalization
  GTranslateCallback := nil;
  GLanguageCallback := nil;

end.
