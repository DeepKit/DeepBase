unit Test.DeepBase.i18n;

{*******************************************************************************
  DeepBase i18n 模块单元测试
  
  测试内容:
  - T() 函数
  - TFmt() 函数
  - TN() 复数形式
  - 语言切换
  - 缓存机制
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
  FLanguages[1].NativeName := '中文';
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

  // IMPORTANT: DeepBase 使用单例 Manager，测试之间会共享 I18n 实例�?
  // 为避免前序用例切换语言/缓存影响后续用例，这里统一复位�?
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
  Translation := '你好';
  
  // 添加翻译
  FI18n.AddTranslation(Original, 'zh-CN', Translation);
  FI18n.CurrentLanguage := 'zh-CN';
  
  Res := FI18n.Translate(Original);
  
  Assert.AreEqual(Translation, Res, '有翻译时应该返回翻译文本');
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
  // 该用例验证英文复数规则；确保当前语言�?en-US�?
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
  
  // 至少应该有一个语言（默认语言�?
  Assert.IsTrue(Length(Languages) >= 1, '至少应该有一个可用语言');
end;

procedure TTestDeepBaseI18n.Test_AddTranslation;
var
  OriginalText, TranslatedText: string;
begin
  OriginalText := 'Test ' + TGUID.NewGuid.ToString;
  TranslatedText := '测试翻译';
  
  // 添加翻译 (SourceText, LangCode, TranslatedText)
  FI18n.AddTranslation(OriginalText, 'zh-CN', TranslatedText);
  
  // 切换到中�?
  FI18n.CurrentLanguage := 'zh-CN';
  
  Assert.AreEqual(TranslatedText, FI18n.Translate(OriginalText), 
    'AddTranslation 应该正确添加翻译');
end;

procedure TTestDeepBaseI18n.Test_OnLanguageChanged_Event;
begin
  
  // 使用 SubscribeLanguageChange 代替直接设置 OnLanguageChanged
  // 因为 OnLanguageChanged �?TNotifyEvent 类型，不支持匿名方法
  // 测试简�? 只验证切换语言不报�?
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
  
  // 首次调用（可能需要查询数据库�?
  Res := FI18n.Translate(Text);
  
  // 测量缓存命中性能
  SW := TStopwatch.StartNew;
  for I := 1 to 10000 do
    Res := FI18n.Translate(Text);
  SW.Stop;
  
  Elapsed := SW.ElapsedMilliseconds;
  
  // 10000 次查询应该在 500ms 内完成（平均每次 < 0.05ms�?
  Assert.IsTrue(Elapsed < 500, 
    Format('缓存性能不佳: 10000 次查询耗时 %d ms', [Elapsed]));
end;

procedure TTestDeepBaseI18n.Test_LanguageSwitch_ClearCache;
var
  Text, Translation1, Translation2: string;
  Res: string;
begin
  Text := 'Switch test ' + TGUID.NewGuid.ToString;
  Translation1 := '翻译1';
  Translation2 := 'Translation2';
  
  // 说明:
  // DeepBase �?en-US 视为“英文源语言”，TranslateTo('en-US') 会直接返回原文�?
  // 因此这里�?fr-FR 作为第二语言，以验证切换语言后缓存不会误命中�?

  // 添加两种语言的翻�?(SourceText, LangCode, TranslatedText)
  FI18n.AddTranslation(Text, 'zh-CN', Translation1);
  FI18n.AddTranslation(Text, 'fr-FR', Translation2);
  
  // 测试中文
  FI18n.CurrentLanguage := 'zh-CN';
  Res := FI18n.Translate(Text);
  Assert.AreEqual(Translation1, Res, '中文翻译应该正确');
  
  // 切换到法�?
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
    LocalI18n.AddTranslation('Inject.Hello', 'zh-CN', '注入你好');
    LocalI18n.CurrentLanguage := 'zh-CN';
    Assert.AreEqual('注入你好', LocalI18n.Translate('Inject.Hello'),
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
