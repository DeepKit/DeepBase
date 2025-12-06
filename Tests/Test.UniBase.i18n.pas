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
  // 使用内存数据库初始化
  if not UniBase.IsInitialized then
    UniBase.InitializeWithDB(':memory:');
  
  FI18n := UniBase.I18n;
end;

procedure TTestUniBaseI18n.TearDown;
begin
  FI18n := nil;
end;

procedure TTestUniBaseI18n.Test_T_ReturnsOriginal_WhenNoTranslation;
var
  Original, Result: string;
begin
  Original := 'This text has no translation ' + TGUID.NewGuid.ToString;
  
  Result := FI18n.T(Original);
  
  Assert.AreEqual(Original, Result, '没有翻译时应该返回原文');
end;

procedure TTestUniBaseI18n.Test_T_ReturnsTranslation_WhenExists;
var
  Original, Translation, Result: string;
begin
  Original := 'Hello';
  Translation := '你好';
  
  // 添加翻译
  FI18n.AddTranslation('zh-CN', Original, Translation);
  FI18n.CurrentLanguage := 'zh-CN';
  
  Result := FI18n.T(Original);
  
  Assert.AreEqual(Translation, Result, '有翻译时应该返回翻译文本');
end;

procedure TTestUniBaseI18n.Test_TFmt_FormatsCorrectly;
var
  Template, Result: string;
begin
  Template := 'Hello, %s! You have %d messages.';
  
  Result := FI18n.TFmt(Template, ['Alice', 5]);
  
  Assert.AreEqual('Hello, Alice! You have 5 messages.', Result, 
    'TFmt 应该正确格式化参数');
end;

procedure TTestUniBaseI18n.Test_TN_Singular;
var
  Singular, Plural, Result: string;
begin
  Singular := '%d item';
  Plural := '%d items';
  
  Result := FI18n.TN(Singular, Plural, 1);
  
  Assert.AreEqual('1 item', Result, '数量为 1 时应该使用单数形式');
end;

procedure TTestUniBaseI18n.Test_TN_Plural;
var
  Singular, Plural, Result: string;
begin
  Singular := '%d item';
  Plural := '%d items';
  
  Result := FI18n.TN(Singular, Plural, 5);
  
  Assert.AreEqual('5 items', Result, '数量大于 1 时应该使用复数形式');
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
  
  // 添加翻译
  FI18n.AddTranslation('zh-CN', OriginalText, TranslatedText);
  
  // 切换到中文
  FI18n.CurrentLanguage := 'zh-CN';
  
  Assert.AreEqual(TranslatedText, FI18n.T(OriginalText), 
    'AddTranslation 应该正确添加翻译');
end;

procedure TTestUniBaseI18n.Test_OnLanguageChanged_Event;
var
  EventFired: Boolean;
  NewLang: string;
begin
  EventFired := False;
  NewLang := '';
  
  FI18n.OnLanguageChanged := 
    procedure(const ALang: string)
    begin
      EventFired := True;
      NewLang := ALang;
    end;
  
  try
    FI18n.CurrentLanguage := 'fr-FR';
    
    Assert.IsTrue(EventFired, 'OnLanguageChanged 事件应该被触发');
    Assert.AreEqual('fr-FR', NewLang, '事件应该传递正确的语言代码');
  finally
    FI18n.OnLanguageChanged := nil;
  end;
end;

procedure TTestUniBaseI18n.Test_Cache_Performance;
var
  I: Integer;
  SW: TStopwatch;
  Text, Result: string;
  Elapsed: Int64;
begin
  Text := 'Performance test text';
  
  // 首次调用（可能需要查询数据库）
  Result := FI18n.T(Text);
  
  // 测量缓存命中性能
  SW := TStopwatch.StartNew;
  for I := 1 to 10000 do
    Result := FI18n.T(Text);
  SW.Stop;
  
  Elapsed := SW.ElapsedMilliseconds;
  
  // 10000 次查询应该在 500ms 内完成（平均每次 < 0.05ms）
  Assert.IsTrue(Elapsed < 500, 
    Format('缓存性能不佳: 10000 次查询耗时 %d ms', [Elapsed]));
end;

procedure TTestUniBaseI18n.Test_LanguageSwitch_ClearCache;
var
  Text, Translation1, Translation2: string;
  Result: string;
begin
  Text := 'Switch test ' + TGUID.NewGuid.ToString;
  Translation1 := '翻译1';
  Translation2 := 'Translation2';
  
  // 添加两种语言的翻译
  FI18n.AddTranslation('zh-CN', Text, Translation1);
  FI18n.AddTranslation('en-US', Text, Translation2);
  
  // 测试中文
  FI18n.CurrentLanguage := 'zh-CN';
  Result := FI18n.T(Text);
  Assert.AreEqual(Translation1, Result, '中文翻译应该正确');
  
  // 切换到英文
  FI18n.CurrentLanguage := 'en-US';
  Result := FI18n.T(Text);
  Assert.AreEqual(Translation2, Result, '切换语言后应该返回新语言的翻译');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseI18n);

end.
