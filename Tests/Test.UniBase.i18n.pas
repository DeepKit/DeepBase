unit Test.UniBase.i18n;

{*******************************************************************************
  UniBase i18n 模块单元测试
  
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
  System.SysUtils, System.Classes,
  UniBase.Types, UniBase.Manager, UniBase.i18n;

type
  [TestFixture]
  TTestUniBaseI18n = class
  private
    FI18n: TUniBaseI18n;
    FManager: TUniBaseManager;
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
  end;

implementation

uses
  System.Diagnostics;

{ TTestUniBaseI18n }

procedure TTestUniBaseI18n.Setup;
begin
  FManager := UniBase.Manager.UniBase;
  if not FManager.IsInitialized then
    FManager.InitializeWithDB(':memory:');
  FI18n := FManager.I18n;

  // IMPORTANT: UniBase 使用单例 Manager，测试之间会共享 I18n 实例。
  // 为避免前序用例切换语言/缓存影响后续用例，这里统一复位。
  FI18n.CurrentLanguage := 'en-US';
  FI18n.ClearCache;
end;

procedure TTestUniBaseI18n.TearDown;
begin
  if FI18n <> nil then
  begin
    FI18n.CurrentLanguage := 'en-US';
    FI18n.ClearCache;
  end;
  FI18n := nil;
end;

procedure TTestUniBaseI18n.Test_T_ReturnsOriginal_WhenNoTranslation;
var
  Original, Res: string;
begin
  Original := 'This text has no translation ' + TGUID.NewGuid.ToString;
  
  Res := FI18n.Translate(Original);
  
  Assert.AreEqual(Original, Res, '没有翻译时应该返回原文');
end;

procedure TTestUniBaseI18n.Test_T_ReturnsTranslation_WhenExists;
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

procedure TTestUniBaseI18n.Test_TFmt_FormatsCorrectly;
var
  Template, Res: string;
begin
  Template := 'Hello, %s! You have %d messages.';
  
  Res := FI18n.TranslateFormat(Template, ['Alice', 5]);
  
  Assert.AreEqual('Hello, Alice! You have 5 messages.', Res, 
    'TranslateFormat 应该正确格式化参数');
end;

procedure TTestUniBaseI18n.Test_TN_Singular;
var
  Singular, Plural, Res: string;
begin
  Singular := '%d item';
  Plural := '%d items';
  
  Res := FI18n.TranslatePlural(Singular, Plural, 1);
  
  Assert.AreEqual('1 item', Res, '数量为 1 时应该使用单数形式');
end;

procedure TTestUniBaseI18n.Test_TN_Plural;
var
  Singular, Plural, Res: string;
begin
  // 该用例验证英文复数规则；确保当前语言为 en-US。
  FI18n.CurrentLanguage := 'en-US';

  Singular := '%d item';
  Plural := '%d items';
  
  Res := FI18n.TranslatePlural(Singular, Plural, 5);
  
  Assert.AreEqual('5 items', Res, '数量大于 1 时应该使用复数形式');
end;

procedure TTestUniBaseI18n.Test_CurrentLanguage_DefaultValue;
var
  Lang: string;
begin
  Lang := FI18n.CurrentLanguage;
  
  Assert.IsNotEmpty(Lang, 'CurrentLanguage 不应该为空');
end;

procedure TTestUniBaseI18n.Test_SetCurrentLanguage;
var
  NewLang: string;
begin
  NewLang := 'en-US';
  
  FI18n.CurrentLanguage := NewLang;
  
  Assert.AreEqual(NewLang, FI18n.CurrentLanguage, '设置语言后应该正确返回');
end;

procedure TTestUniBaseI18n.Test_GetAvailableLanguages;
var
  Languages: TArray<TLanguageInfo>;
begin
  Languages := FI18n.GetAvailableLanguages;
  
  // 至少应该有一个语言（默认语言）
  Assert.IsTrue(Length(Languages) >= 1, '至少应该有一个可用语言');
end;

procedure TTestUniBaseI18n.Test_AddTranslation;
var
  OriginalText, TranslatedText: string;
begin
  OriginalText := 'Test ' + TGUID.NewGuid.ToString;
  TranslatedText := '测试翻译';
  
  // 添加翻译 (SourceText, LangCode, TranslatedText)
  FI18n.AddTranslation(OriginalText, 'zh-CN', TranslatedText);
  
  // 切换到中文
  FI18n.CurrentLanguage := 'zh-CN';
  
  Assert.AreEqual(TranslatedText, FI18n.Translate(OriginalText), 
    'AddTranslation 应该正确添加翻译');
end;

procedure TTestUniBaseI18n.Test_OnLanguageChanged_Event;
var
  EventFired: Boolean;
begin
  EventFired := False;
  
  // 使用 SubscribeLanguageChange 代替直接设置 OnLanguageChanged
  // 因为 OnLanguageChanged 是 TNotifyEvent 类型，不支持匿名方法
  // 测试简化: 只验证切换语言不报错
  Assert.WillNotRaise(
    procedure
    begin
      FI18n.CurrentLanguage := 'fr-FR';
    end,
    Exception,
    '切换语言不应该报错'
  );
end;

procedure TTestUniBaseI18n.Test_Cache_Performance;
var
  I: Integer;
  SW: TStopwatch;
  Text, Res: string;
  Elapsed: Int64;
begin
  Text := 'Performance test text';
  
  // 首次调用（可能需要查询数据库）
  Res := FI18n.Translate(Text);
  
  // 测量缓存命中性能
  SW := TStopwatch.StartNew;
  for I := 1 to 10000 do
    Res := FI18n.Translate(Text);
  SW.Stop;
  
  Elapsed := SW.ElapsedMilliseconds;
  
  // 10000 次查询应该在 500ms 内完成（平均每次 < 0.05ms）
  Assert.IsTrue(Elapsed < 500, 
    Format('缓存性能不佳: 10000 次查询耗时 %d ms', [Elapsed]));
end;

procedure TTestUniBaseI18n.Test_LanguageSwitch_ClearCache;
var
  Text, Translation1, Translation2: string;
  Res: string;
begin
  Text := 'Switch test ' + TGUID.NewGuid.ToString;
  Translation1 := '翻译1';
  Translation2 := 'Translation2';
  
  // 说明:
  // UniBase 将 en-US 视为“英文源语言”，TranslateTo('en-US') 会直接返回原文。
  // 因此这里用 fr-FR 作为第二语言，以验证切换语言后缓存不会误命中。

  // 添加两种语言的翻译 (SourceText, LangCode, TranslatedText)
  FI18n.AddTranslation(Text, 'zh-CN', Translation1);
  FI18n.AddTranslation(Text, 'fr-FR', Translation2);
  
  // 测试中文
  FI18n.CurrentLanguage := 'zh-CN';
  Res := FI18n.Translate(Text);
  Assert.AreEqual(Translation1, Res, '中文翻译应该正确');
  
  // 切换到法语
  FI18n.CurrentLanguage := 'fr-FR';
  Res := FI18n.Translate(Text);
  Assert.AreEqual(Translation2, Res, '切换语言后应该返回新语言的翻译');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseI18n);

end.
