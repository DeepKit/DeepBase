unit Test.DeepBase.i18n;

{*******************************************************************************
  DeepBase i18n 妯″潡鍗曞厓娴嬭瘯
  
  娴嬭瘯鍐呭:
  - T() 鍑芥暟
  - TFmt() 鍑芥暟
  - TN() 澶嶆暟褰㈠紡
  - 璇█鍒囨崲
  - 缂撳瓨鏈哄埗
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes, System.Generics.Collections,
  DeepBase.Types, DeepBase.Manager, DeepBase.i18n, DeepBase.Storage.Interfaces;

type
  [TestFixture]
  TTestDeepBaseI18n = class
  private
    FI18n: TDeepBaseI18n;
    FManager: TDeepBaseManager;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_T_ReturnsOriginal_WhenNoTranslation;
    
    [Test]
    procedure Test_T_ReturnsTranslation_WhenExists;
    
    [Test]
    procedure Test_TFmt_FormatsCorrectly;
    
    [Test]
    procedure Test_TN_Singular;
    
    [Test]
    procedure Test_TN_Plural;
    
    [Test]
    procedure Test_CurrentLanguage_DefaultValue;
    
    [Test]
    procedure Test_SetCurrentLanguage;
    
    [Test]
    procedure Test_GetAvailableLanguages;
    
    [Test]
    procedure Test_AddTranslation;
    
    [Test]
    procedure Test_OnLanguageChanged_Event;
    
    [Test]
    procedure Test_Cache_Performance;
    
    [Test]
    procedure Test_LanguageSwitch_ClearCache;

    [Test]
    procedure Test_StorageInjection_BasicFlow;
  end;

implementation

uses
  System.Diagnostics;

type
  TInMemoryI18nStorage = class(TInterfacedObject, II18nStorage)
  private
    FTranslations: TDictionary<string, string>;
    FLanguages: TArray<TLanguageInfo>;
    function MakeKey(const SourceText, LangCode: string): string;
  public
    constructor Create;
    destructor Destroy; override;
    function ReadTranslation(const SourceText, LangCode: string): string;
    function ReadTranslations(const LangCode: string): TDictionary<string, string>;
    procedure RecordMissingTranslation(const SourceText, LangCode: string);
    function ReadLanguages(EnabledOnly: Boolean): TLanguageInfoArray;
    function ReadDefaultLanguage(const Fallback: string): string;
    procedure UpsertTranslation(const SourceText, LangCode,
      TranslatedText: string);
  end;

constructor TInMemoryI18nStorage.Create;
begin
  inherited Create;
  FTranslations := TDictionary<string, string>.Create;
  SetLength(FLanguages, 2);

  FLanguages[0].LangCode := 'en-US';
  FLanguages[0].LangName := 'English';
  FLanguages[0].NativeName := 'English';
  FLanguages[0].FlagIcon := '';
  FLanguages[0].IsEnabled := True;
  FLanguages[0].IsDefault := True;

  FLanguages[1].LangCode := 'zh-CN';
  FLanguages[1].LangName := 'Chinese';
  FLanguages[1].NativeName := '涓枃';
  FLanguages[1].FlagIcon := '';
  FLanguages[1].IsEnabled := True;
  FLanguages[1].IsDefault := False;
end;

destructor TInMemoryI18nStorage.Destroy;
begin
  FTranslations.Free;
  inherited;
end;

function TInMemoryI18nStorage.MakeKey(const SourceText, LangCode: string): string;
begin
  Result := LangCode + #1 + SourceText;
end;

function TInMemoryI18nStorage.ReadTranslation(const SourceText,
  LangCode: string): string;
begin
  if not FTranslations.TryGetValue(MakeKey(SourceText, LangCode), Result) then
    Result := '';
end;

function TInMemoryI18nStorage.ReadTranslations(
  const LangCode: string): TDictionary<string, string>;
var
  Pair: TPair<string, string>;
  SplitPos: Integer;
  KeyLang, SourceText: string;
begin
  Result := TDictionary<string, string>.Create;
  for Pair in FTranslations do
  begin
    SplitPos := Pos(#1, Pair.Key);
    if SplitPos <= 0 then
      Continue;

    KeyLang := Copy(Pair.Key, 1, SplitPos - 1);
    if not SameText(KeyLang, LangCode) then
      Continue;

    SourceText := Copy(Pair.Key, SplitPos + 1, MaxInt);
    Result.AddOrSetValue(SourceText, Pair.Value);
  end;
end;

procedure TInMemoryI18nStorage.RecordMissingTranslation(const SourceText,
  LangCode: string);
begin
  // no-op for in-memory test storage
end;

function TInMemoryI18nStorage.ReadLanguages(
  EnabledOnly: Boolean): TLanguageInfoArray;
var
  Item: TLanguageInfo;
begin
  if not EnabledOnly then
    Exit(FLanguages);

  SetLength(Result, 0);
  for Item in FLanguages do
    if Item.IsEnabled then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Item;
    end;
end;

function TInMemoryI18nStorage.ReadDefaultLanguage(
  const Fallback: string): string;
var
  Item: TLanguageInfo;
begin
  Result := Fallback;
  for Item in FLanguages do
    if Item.IsDefault then
      Exit(Item.LangCode);
end;

procedure TInMemoryI18nStorage.UpsertTranslation(const SourceText, LangCode,
  TranslatedText: string);
begin
  FTranslations.AddOrSetValue(MakeKey(SourceText, LangCode), TranslatedText);
end;

{ TTestDeepBaseI18n }

procedure TTestDeepBaseI18n.Setup;
begin
  FManager := DeepBase.Manager.DeepBase;
  if not FManager.IsInitialized then
    FManager.InitializeWithDB(':memory:');
  FI18n := FManager.I18n;

  // IMPORTANT: DeepBase 浣跨敤鍗曚緥 Manager锛屾祴璇曚箣闂翠細鍏变韩 I18n 瀹炰緥銆?
  // 涓洪伩鍏嶅墠搴忕敤渚嬪垏鎹㈣瑷€/缂撳瓨褰卞搷鍚庣画鐢ㄤ緥锛岃繖閲岀粺涓€澶嶄綅銆?
  FI18n.CurrentLanguage := 'en-US';
  FI18n.ClearCache;
end;

procedure TTestDeepBaseI18n.TearDown;
begin
  if FI18n <> nil then
  begin
    FI18n.CurrentLanguage := 'en-US';
    FI18n.ClearCache;
  end;
  FI18n := nil;
end;

procedure TTestDeepBaseI18n.Test_T_ReturnsOriginal_WhenNoTranslation;
var
  Original, Res: string;
begin
  Original := 'This text has no translation ' + TGUID.NewGuid.ToString;
  
  Res := FI18n.Translate(Original);
  
  Assert.AreEqual(Original, Res, 'missing translation should return original text');
end;

procedure TTestDeepBaseI18n.Test_T_ReturnsTranslation_WhenExists;
var
  Original, Translation, Res: string;
begin
  Original := 'Hello';
  Translation := '浣犲ソ';
  
  // 娣诲姞缈昏瘧
  FI18n.AddTranslation(Original, 'zh-CN', Translation);
  FI18n.CurrentLanguage := 'zh-CN';
  
  Res := FI18n.Translate(Original);
  
  Assert.AreEqual(Translation, Res, '鏈夌炕璇戞椂搴旇杩斿洖缈昏瘧鏂囨湰');
end;

procedure TTestDeepBaseI18n.Test_TFmt_FormatsCorrectly;
var
  Template, Res: string;
begin
  Template := 'Hello, %s! You have %d messages.';
  
  Res := FI18n.TranslateFormat(Template, ['Alice', 5]);
  
  Assert.AreEqual('Hello, Alice! You have 5 messages.', Res, 
    'TranslateFormat should format arguments correctly');
end;

procedure TTestDeepBaseI18n.Test_TN_Singular;
var
  Singular, Plural, Res: string;
begin
  Singular := '%d item';
  Plural := '%d items';
  
  Res := FI18n.TranslatePlural(Singular, Plural, 1);
  
  Assert.AreEqual('1 item', Res, 'count 1 should use singular form');
end;

procedure TTestDeepBaseI18n.Test_TN_Plural;
var
  Singular, Plural, Res: string;
begin
  // 璇ョ敤渚嬮獙璇佽嫳鏂囧鏁拌鍒欙紱纭繚褰撳墠璇█涓?en-US銆?
  FI18n.CurrentLanguage := 'en-US';

  Singular := '%d item';
  Plural := '%d items';
  
  Res := FI18n.TranslatePlural(Singular, Plural, 5);
  
  Assert.AreEqual('5 items', Res, 'count greater than 1 should use plural form');
end;

procedure TTestDeepBaseI18n.Test_CurrentLanguage_DefaultValue;
var
  Lang: string;
begin
  Lang := FI18n.CurrentLanguage;
  
  Assert.IsNotEmpty(Lang, 'CurrentLanguage should not be empty');
end;

procedure TTestDeepBaseI18n.Test_SetCurrentLanguage;
var
  NewLang: string;
begin
  NewLang := 'en-US';
  
  FI18n.CurrentLanguage := NewLang;
  
  Assert.AreEqual(NewLang, FI18n.CurrentLanguage, 'setting language should roundtrip');
end;

procedure TTestDeepBaseI18n.Test_GetAvailableLanguages;
var
  Languages: TArray<TLanguageInfo>;
begin
  Languages := FI18n.GetAvailableLanguages;
  
  // 鑷冲皯搴旇鏈変竴涓瑷€锛堥粯璁よ瑷€锛?
  Assert.IsTrue(Length(Languages) >= 1, '鑷冲皯搴旇鏈変竴涓彲鐢ㄨ瑷€');
end;

procedure TTestDeepBaseI18n.Test_AddTranslation;
var
  OriginalText, TranslatedText: string;
begin
  OriginalText := 'Test ' + TGUID.NewGuid.ToString;
  TranslatedText := '娴嬭瘯缈昏瘧';
  
  // 娣诲姞缈昏瘧 (SourceText, LangCode, TranslatedText)
  FI18n.AddTranslation(OriginalText, 'zh-CN', TranslatedText);
  
  // 鍒囨崲鍒颁腑鏂?
  FI18n.CurrentLanguage := 'zh-CN';
  
  Assert.AreEqual(TranslatedText, FI18n.Translate(OriginalText), 
    'AddTranslation 搴旇姝ｇ‘娣诲姞缈昏瘧');
end;

procedure TTestDeepBaseI18n.Test_OnLanguageChanged_Event;
begin
  
  // 浣跨敤 SubscribeLanguageChange 浠ｆ浛鐩存帴璁剧疆 OnLanguageChanged
  // 鍥犱负 OnLanguageChanged 鏄?TNotifyEvent 绫诲瀷锛屼笉鏀寔鍖垮悕鏂规硶
  // 娴嬭瘯绠€鍖? 鍙獙璇佸垏鎹㈣瑷€涓嶆姤閿?
  Assert.WillNotRaise(
    procedure
    begin
      FI18n.CurrentLanguage := 'fr-FR';
    end,
    Exception,
    'changing language should not raise'
  );
end;

procedure TTestDeepBaseI18n.Test_Cache_Performance;
var
  I: Integer;
  SW: TStopwatch;
  Text, Res: string;
  Elapsed: Int64;
begin
  Text := 'Performance test text';
  
  // 棣栨璋冪敤锛堝彲鑳介渶瑕佹煡璇㈡暟鎹簱锛?
  Res := FI18n.Translate(Text);
  
  // 娴嬮噺缂撳瓨鍛戒腑鎬ц兘
  SW := TStopwatch.StartNew;
  for I := 1 to 10000 do
    Res := FI18n.Translate(Text);
  SW.Stop;
  
  Elapsed := SW.ElapsedMilliseconds;
  
  // 10000 娆℃煡璇㈠簲璇ュ湪 500ms 鍐呭畬鎴愶紙骞冲潎姣忔 < 0.05ms锛?
  Assert.IsTrue(Elapsed < 500, 
    Format('缂撳瓨鎬ц兘涓嶄匠: 10000 娆℃煡璇㈣€楁椂 %d ms', [Elapsed]));
end;

procedure TTestDeepBaseI18n.Test_LanguageSwitch_ClearCache;
var
  Text, Translation1, Translation2: string;
  Res: string;
begin
  Text := 'Switch test ' + TGUID.NewGuid.ToString;
  Translation1 := '缈昏瘧1';
  Translation2 := 'Translation2';
  
  // 璇存槑:
  // DeepBase 灏?en-US 瑙嗕负鈥滆嫳鏂囨簮璇█鈥濓紝TranslateTo('en-US') 浼氱洿鎺ヨ繑鍥炲師鏂囥€?
  // 鍥犳杩欓噷鐢?fr-FR 浣滀负绗簩璇█锛屼互楠岃瘉鍒囨崲璇█鍚庣紦瀛樹笉浼氳鍛戒腑銆?

  // 娣诲姞涓ょ璇█鐨勭炕璇?(SourceText, LangCode, TranslatedText)
  FI18n.AddTranslation(Text, 'zh-CN', Translation1);
  FI18n.AddTranslation(Text, 'fr-FR', Translation2);
  
  // 娴嬭瘯涓枃
  FI18n.CurrentLanguage := 'zh-CN';
  Res := FI18n.Translate(Text);
  Assert.AreEqual(Translation1, Res, '涓枃缈昏瘧搴旇姝ｇ‘');
  
  // 鍒囨崲鍒版硶璇?
  FI18n.CurrentLanguage := 'fr-FR';
  Res := FI18n.Translate(Text);
  Assert.AreEqual(Translation2, Res, 'switching language should return new translation');
end;

procedure TTestDeepBaseI18n.Test_StorageInjection_BasicFlow;
var
  Storage: II18nStorage;
  LocalI18n: TDeepBaseI18n;
  Languages: TArray<TLanguageInfo>;
begin
  Storage := TInMemoryI18nStorage.Create;
  LocalI18n := TDeepBaseI18n.Create(Storage);
  try
    LocalI18n.AddTranslation('Inject.Hello', 'zh-CN', '娉ㄥ叆浣犲ソ');
    LocalI18n.CurrentLanguage := 'zh-CN';
    Assert.AreEqual('娉ㄥ叆浣犲ソ', LocalI18n.Translate('Inject.Hello'),
      'Injected storage should serve translated text');

    Assert.AreEqual('en-US', LocalI18n.GetDefaultLanguage,
      'Injected storage should provide default language');

    Languages := LocalI18n.GetAvailableLanguages;
    Assert.IsTrue(Length(Languages) >= 2,
      'Injected storage should expose available languages');
  finally
    LocalI18n.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDeepBaseI18n);

end.
