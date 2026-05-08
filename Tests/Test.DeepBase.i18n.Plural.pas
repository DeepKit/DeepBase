/// <summary>
/// Unit tests for DeepBase.i18n.Plural module
/// Tests: TPluralRules, CLDR plural categories, multi-language support
/// </summary>
unit Test.DeepBase.i18n.Plural;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DeepBase.i18n.Plural;

type
  /// <summary>
  /// Tests for TPluralCategory
  /// </summary>
  [TestFixture]
  TPluralCategoryTests = class
  public
    [Test]
    procedure Test_CategoryName_Zero;
    [Test]
    procedure Test_CategoryName_One;
    [Test]
    procedure Test_CategoryName_Two;
    [Test]
    procedure Test_CategoryName_Few;
    [Test]
    procedure Test_CategoryName_Many;
    [Test]
    procedure Test_CategoryName_Other;
    [Test]
    procedure Test_ParseCategory_Zero;
    [Test]
    procedure Test_ParseCategory_One;
    [Test]
    procedure Test_ParseCategory_CaseInsensitive;
    [Test]
    procedure Test_ParseCategory_Unknown;
  end;

  /// <summary>
  /// Tests for English plural rules
  /// </summary>
  [TestFixture]
  TEnglishPluralTests = class
  public
    [Test]
    procedure Test_English_Zero;
    [Test]
    procedure Test_English_One;
    [Test]
    procedure Test_English_Two;
    [Test]
    procedure Test_English_Many;
    [Test]
    procedure Test_English_Negative;
    [Test]
    procedure Test_English_Decimal;
    [Test]
    procedure Test_English_Categories;
    [Test]
    procedure Test_English_HasCategory;
  end;

  /// <summary>
  /// Tests for French plural rules
  /// </summary>
  [TestFixture]
  TFrenchPluralTests = class
  public
    [Test]
    procedure Test_French_Zero;
    [Test]
    procedure Test_French_One;
    [Test]
    procedure Test_French_Two;
    [Test]
    procedure Test_French_Categories;
  end;

  /// <summary>
  /// Tests for Russian plural rules
  /// </summary>
  [TestFixture]
  TRussianPluralTests = class
  public
    [Test]
    procedure Test_Russian_One;
    [Test]
    procedure Test_Russian_Few_2;
    [Test]
    procedure Test_Russian_Few_3;
    [Test]
    procedure Test_Russian_Few_4;
    [Test]
    procedure Test_Russian_Many_0;
    [Test]
    procedure Test_Russian_Many_5;
    [Test]
    procedure Test_Russian_Many_11;
    [Test]
    procedure Test_Russian_Many_20;
    [Test]
    procedure Test_Russian_21;
    [Test]
    procedure Test_Russian_22;
    [Test]
    procedure Test_Russian_25;
    [Test]
    procedure Test_Russian_100;
    [Test]
    procedure Test_Russian_101;
    [Test]
    procedure Test_Russian_102;
    [Test]
    procedure Test_Russian_111;
    [Test]
    procedure Test_Russian_Categories;
  end;

  /// <summary>
  /// Tests for Polish plural rules
  /// </summary>
  [TestFixture]
  TPolishPluralTests = class
  public
    [Test]
    procedure Test_Polish_One;
    [Test]
    procedure Test_Polish_Few;
    [Test]
    procedure Test_Polish_Many;
    [Test]
    procedure Test_Polish_Categories;
  end;

  /// <summary>
  /// Tests for Arabic plural rules
  /// </summary>
  [TestFixture]
  TArabicPluralTests = class
  public
    [Test]
    procedure Test_Arabic_Zero;
    [Test]
    procedure Test_Arabic_One;
    [Test]
    procedure Test_Arabic_Two;
    [Test]
    procedure Test_Arabic_Few;
    [Test]
    procedure Test_Arabic_Many;
    [Test]
    procedure Test_Arabic_Other;
    [Test]
    procedure Test_Arabic_Categories;
  end;

  /// <summary>
  /// Tests for Chinese/Japanese/Korean plural rules (no plural forms)
  /// </summary>
  [TestFixture]
  TCJKPluralTests = class
  public
    [Test]
    procedure Test_Chinese_AllOther;
    [Test]
    procedure Test_Japanese_AllOther;
    [Test]
    procedure Test_Korean_AllOther;
    [Test]
    procedure Test_Chinese_Categories;
  end;

  /// <summary>
  /// Tests for Czech/Slovak plural rules
  /// </summary>
  [TestFixture]
  TCzechPluralTests = class
  public
    [Test]
    procedure Test_Czech_One;
    [Test]
    procedure Test_Czech_Few;
    [Test]
    procedure Test_Czech_Other;
    [Test]
    procedure Test_Czech_Categories;
  end;

  /// <summary>
  /// Tests for Welsh plural rules
  /// </summary>
  [TestFixture]
  TWelshPluralTests = class
  public
    [Test]
    procedure Test_Welsh_Zero;
    [Test]
    procedure Test_Welsh_One;
    [Test]
    procedure Test_Welsh_Two;
    [Test]
    procedure Test_Welsh_Few;
    [Test]
    procedure Test_Welsh_Many;
    [Test]
    procedure Test_Welsh_Other;
    [Test]
    procedure Test_Welsh_Categories;
  end;

  /// <summary>
  /// Tests for Irish plural rules
  /// </summary>
  [TestFixture]
  TIrishPluralTests = class
  public
    [Test]
    procedure Test_Irish_One;
    [Test]
    procedure Test_Irish_Two;
    [Test]
    procedure Test_Irish_Few;
    [Test]
    procedure Test_Irish_Many;
    [Test]
    procedure Test_Irish_Other;
  end;

  /// <summary>
  /// Tests for SelectForm function
  /// </summary>
  [TestFixture]
  TSelectFormTests = class
  public
    [Test]
    procedure Test_SelectForm_EmptyArray;
    [Test]
    procedure Test_SelectForm_SingleForm;
    [Test]
    procedure Test_SelectForm_English;
    [Test]
    procedure Test_SelectForm_Russian;
    [Test]
    procedure Test_SelectForm_Arabic;
    [Test]
    procedure Test_SelectForm_FallbackToLast;
  end;

  /// <summary>
  /// Tests for global functions
  /// </summary>
  [TestFixture]
  TGlobalFunctionTests = class
  public
    [Test]
    procedure Test_GetPluralForm_Integer;
    [Test]
    procedure Test_GetPluralForm_Double;
    [Test]
    procedure Test_PluralSelect_Integer;
    [Test]
    procedure Test_PluralSelect_Double;
  end;

  /// <summary>
  /// Tests for language fallback
  /// </summary>
  [TestFixture]
  TLanguageFallbackTests = class
  public
    [Test]
    procedure Test_LanguageCode_CaseInsensitive;
    [Test]
    procedure Test_LanguageVariant_FallsBackToBase;
    [Test]
    procedure Test_UnknownLanguage_FallsBackToEnglish;
    [Test]
    procedure Test_PortugueseBrazil;
  end;

  /// <summary>
  /// Tests for custom rule registration
  /// </summary>
  [TestFixture]
  TCustomRuleTests = class
  public
    [Test]
    procedure Test_RegisterCustomRule;
    [Test]
    procedure Test_OverrideExistingRule;
  end;

  /// <summary>
  /// Tests for decimal number handling
  /// </summary>
  [TestFixture]
  TDecimalPluralTests = class
  public
    [Test]
    procedure Test_English_Decimal_1_0;
    [Test]
    procedure Test_English_Decimal_1_5;
    [Test]
    procedure Test_Russian_Decimal;
    [Test]
    procedure Test_French_Decimal;
  end;

  /// <summary>
  /// Tests for additional languages
  /// </summary>
  [TestFixture]
  TAdditionalLanguageTests = class
  public
    // German (same as English)
    [Test]
    procedure Test_German;
    // Lithuanian
    [Test]
    procedure Test_Lithuanian_One;
    [Test]
    procedure Test_Lithuanian_Few;
    [Test]
    procedure Test_Lithuanian_Other;
    // Latvian
    [Test]
    procedure Test_Latvian_Zero;
    [Test]
    procedure Test_Latvian_One;
    [Test]
    procedure Test_Latvian_Other;
    // Slovenian
    [Test]
    procedure Test_Slovenian_One;
    [Test]
    procedure Test_Slovenian_Two;
    [Test]
    procedure Test_Slovenian_Few;
    [Test]
    procedure Test_Slovenian_Other;
    // Hebrew
    [Test]
    procedure Test_Hebrew_One;
    [Test]
    procedure Test_Hebrew_Two;
    [Test]
    procedure Test_Hebrew_Other;
    // Romanian
    [Test]
    procedure Test_Romanian_One;
    [Test]
    procedure Test_Romanian_Few;
    [Test]
    procedure Test_Romanian_Other;
  end;

implementation

// ============================================================================
// TPluralCategoryTests
// ============================================================================

procedure TPluralCategoryTests.Test_CategoryName_Zero;
begin
  Assert.AreEqual('zero', TPluralRules.CategoryName(pcZero));
end;

procedure TPluralCategoryTests.Test_CategoryName_One;
begin
  Assert.AreEqual('one', TPluralRules.CategoryName(pcOne));
end;

procedure TPluralCategoryTests.Test_CategoryName_Two;
begin
  Assert.AreEqual('two', TPluralRules.CategoryName(pcTwo));
end;

procedure TPluralCategoryTests.Test_CategoryName_Few;
begin
  Assert.AreEqual('few', TPluralRules.CategoryName(pcFew));
end;

procedure TPluralCategoryTests.Test_CategoryName_Many;
begin
  Assert.AreEqual('many', TPluralRules.CategoryName(pcMany));
end;

procedure TPluralCategoryTests.Test_CategoryName_Other;
begin
  Assert.AreEqual('other', TPluralRules.CategoryName(pcOther));
end;

procedure TPluralCategoryTests.Test_ParseCategory_Zero;
begin
  Assert.AreEqual(pcZero, TPluralRules.ParseCategory('zero'));
end;

procedure TPluralCategoryTests.Test_ParseCategory_One;
begin
  Assert.AreEqual(pcOne, TPluralRules.ParseCategory('one'));
end;

procedure TPluralCategoryTests.Test_ParseCategory_CaseInsensitive;
begin
  Assert.AreEqual(pcFew, TPluralRules.ParseCategory('FEW'));
  Assert.AreEqual(pcMany, TPluralRules.ParseCategory('Many'));
end;

procedure TPluralCategoryTests.Test_ParseCategory_Unknown;
begin
  Assert.AreEqual(pcOther, TPluralRules.ParseCategory('unknown'));
end;

// ============================================================================
// TEnglishPluralTests
// ============================================================================

procedure TEnglishPluralTests.Test_English_Zero;
begin
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('en', 0));
end;

procedure TEnglishPluralTests.Test_English_One;
begin
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('en', 1));
end;

procedure TEnglishPluralTests.Test_English_Two;
begin
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('en', 2));
end;

procedure TEnglishPluralTests.Test_English_Many;
begin
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('en', 100));
end;

procedure TEnglishPluralTests.Test_English_Negative;
begin
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('en', -1));
end;

procedure TEnglishPluralTests.Test_English_Decimal;
begin
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('en', 1.5));
end;

procedure TEnglishPluralTests.Test_English_Categories;
var
  Categories: TPluralCategories;
begin
  Categories := TPluralRules.GetSupportedCategories('en');
  Assert.IsTrue(pcOne in Categories);
  Assert.IsTrue(pcOther in Categories);
  Assert.IsFalse(pcZero in Categories);
  Assert.IsFalse(pcTwo in Categories);
  Assert.IsFalse(pcFew in Categories);
  Assert.IsFalse(pcMany in Categories);
end;

procedure TEnglishPluralTests.Test_English_HasCategory;
begin
  Assert.IsTrue(TPluralRules.HasCategory('en', pcOne));
  Assert.IsTrue(TPluralRules.HasCategory('en', pcOther));
  Assert.IsFalse(TPluralRules.HasCategory('en', pcZero));
end;

// ============================================================================
// TFrenchPluralTests
// ============================================================================

procedure TFrenchPluralTests.Test_French_Zero;
begin
  // French: 0 is considered "one" category
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('fr', 0));
end;

procedure TFrenchPluralTests.Test_French_One;
begin
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('fr', 1));
end;

procedure TFrenchPluralTests.Test_French_Two;
begin
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('fr', 2));
end;

procedure TFrenchPluralTests.Test_French_Categories;
var
  Categories: TPluralCategories;
begin
  Categories := TPluralRules.GetSupportedCategories('fr');
  Assert.IsTrue(pcOne in Categories);
  Assert.IsTrue(pcOther in Categories);
end;

// ============================================================================
// TRussianPluralTests
// ============================================================================

procedure TRussianPluralTests.Test_Russian_One;
begin
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('ru', 1));
end;

procedure TRussianPluralTests.Test_Russian_Few_2;
begin
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('ru', 2));
end;

procedure TRussianPluralTests.Test_Russian_Few_3;
begin
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('ru', 3));
end;

procedure TRussianPluralTests.Test_Russian_Few_4;
begin
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('ru', 4));
end;

procedure TRussianPluralTests.Test_Russian_Many_0;
begin
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('ru', 0));
end;

procedure TRussianPluralTests.Test_Russian_Many_5;
begin
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('ru', 5));
end;

procedure TRussianPluralTests.Test_Russian_Many_11;
begin
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('ru', 11));
end;

procedure TRussianPluralTests.Test_Russian_Many_20;
begin
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('ru', 20));
end;

procedure TRussianPluralTests.Test_Russian_21;
begin
  // 21 mod 10 = 1, 21 mod 100 = 21 (not 11) -> one
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('ru', 21));
end;

procedure TRussianPluralTests.Test_Russian_22;
begin
  // 22 mod 10 = 2, 22 mod 100 = 22 (not 12) -> few
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('ru', 22));
end;

procedure TRussianPluralTests.Test_Russian_25;
begin
  // 25 mod 10 = 5 -> many
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('ru', 25));
end;

procedure TRussianPluralTests.Test_Russian_100;
begin
  // 100 mod 10 = 0 -> many
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('ru', 100));
end;

procedure TRussianPluralTests.Test_Russian_101;
begin
  // 101 mod 10 = 1, 101 mod 100 = 1 (not 11) -> one
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('ru', 101));
end;

procedure TRussianPluralTests.Test_Russian_102;
begin
  // 102 mod 10 = 2, 102 mod 100 = 2 (not 12) -> few
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('ru', 102));
end;

procedure TRussianPluralTests.Test_Russian_111;
begin
  // 111 mod 10 = 1, but 111 mod 100 = 11 -> many
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('ru', 111));
end;

procedure TRussianPluralTests.Test_Russian_Categories;
var
  Categories: TPluralCategories;
begin
  Categories := TPluralRules.GetSupportedCategories('ru');
  Assert.IsTrue(pcOne in Categories);
  Assert.IsTrue(pcFew in Categories);
  Assert.IsTrue(pcMany in Categories);
  Assert.IsTrue(pcOther in Categories);
end;

// ============================================================================
// TPolishPluralTests
// ============================================================================

procedure TPolishPluralTests.Test_Polish_One;
begin
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('pl', 1));
end;

procedure TPolishPluralTests.Test_Polish_Few;
begin
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('pl', 2));
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('pl', 3));
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('pl', 4));
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('pl', 22));
end;

procedure TPolishPluralTests.Test_Polish_Many;
begin
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('pl', 0));
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('pl', 5));
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('pl', 11));
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('pl', 12));
end;

procedure TPolishPluralTests.Test_Polish_Categories;
var
  Categories: TPluralCategories;
begin
  Categories := TPluralRules.GetSupportedCategories('pl');
  Assert.IsTrue(pcOne in Categories);
  Assert.IsTrue(pcFew in Categories);
  Assert.IsTrue(pcMany in Categories);
  Assert.IsTrue(pcOther in Categories);
end;

// ============================================================================
// TArabicPluralTests
// ============================================================================

procedure TArabicPluralTests.Test_Arabic_Zero;
begin
  Assert.AreEqual(pcZero, TPluralRules.GetCategory('ar', 0));
end;

procedure TArabicPluralTests.Test_Arabic_One;
begin
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('ar', 1));
end;

procedure TArabicPluralTests.Test_Arabic_Two;
begin
  Assert.AreEqual(pcTwo, TPluralRules.GetCategory('ar', 2));
end;

procedure TArabicPluralTests.Test_Arabic_Few;
begin
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('ar', 3));
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('ar', 10));
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('ar', 103));
end;

procedure TArabicPluralTests.Test_Arabic_Many;
begin
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('ar', 11));
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('ar', 99));
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('ar', 111));
end;

procedure TArabicPluralTests.Test_Arabic_Other;
begin
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('ar', 100));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('ar', 101));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('ar', 102));
end;

procedure TArabicPluralTests.Test_Arabic_Categories;
var
  Categories: TPluralCategories;
begin
  Categories := TPluralRules.GetSupportedCategories('ar');
  Assert.IsTrue(pcZero in Categories);
  Assert.IsTrue(pcOne in Categories);
  Assert.IsTrue(pcTwo in Categories);
  Assert.IsTrue(pcFew in Categories);
  Assert.IsTrue(pcMany in Categories);
  Assert.IsTrue(pcOther in Categories);
end;

// ============================================================================
// TCJKPluralTests
// ============================================================================

procedure TCJKPluralTests.Test_Chinese_AllOther;
begin
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('zh', 0));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('zh', 1));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('zh', 2));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('zh', 100));
end;

procedure TCJKPluralTests.Test_Japanese_AllOther;
begin
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('ja', 0));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('ja', 1));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('ja', 100));
end;

procedure TCJKPluralTests.Test_Korean_AllOther;
begin
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('ko', 0));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('ko', 1));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('ko', 100));
end;

procedure TCJKPluralTests.Test_Chinese_Categories;
var
  Categories: TPluralCategories;
begin
  Categories := TPluralRules.GetSupportedCategories('zh');
  Assert.IsTrue(pcOther in Categories);
  Assert.IsFalse(pcOne in Categories);
end;

// ============================================================================
// TCzechPluralTests
// ============================================================================

procedure TCzechPluralTests.Test_Czech_One;
begin
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('cs', 1));
end;

procedure TCzechPluralTests.Test_Czech_Few;
begin
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('cs', 2));
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('cs', 3));
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('cs', 4));
end;

procedure TCzechPluralTests.Test_Czech_Other;
begin
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('cs', 0));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('cs', 5));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('cs', 10));
end;

procedure TCzechPluralTests.Test_Czech_Categories;
var
  Categories: TPluralCategories;
begin
  Categories := TPluralRules.GetSupportedCategories('cs');
  Assert.IsTrue(pcOne in Categories);
  Assert.IsTrue(pcFew in Categories);
  Assert.IsTrue(pcOther in Categories);
end;

// ============================================================================
// TWelshPluralTests
// ============================================================================

procedure TWelshPluralTests.Test_Welsh_Zero;
begin
  Assert.AreEqual(pcZero, TPluralRules.GetCategory('cy', 0));
end;

procedure TWelshPluralTests.Test_Welsh_One;
begin
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('cy', 1));
end;

procedure TWelshPluralTests.Test_Welsh_Two;
begin
  Assert.AreEqual(pcTwo, TPluralRules.GetCategory('cy', 2));
end;

procedure TWelshPluralTests.Test_Welsh_Few;
begin
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('cy', 3));
end;

procedure TWelshPluralTests.Test_Welsh_Many;
begin
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('cy', 6));
end;

procedure TWelshPluralTests.Test_Welsh_Other;
begin
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('cy', 4));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('cy', 5));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('cy', 7));
end;

procedure TWelshPluralTests.Test_Welsh_Categories;
var
  Categories: TPluralCategories;
begin
  Categories := TPluralRules.GetSupportedCategories('cy');
  Assert.IsTrue(pcZero in Categories);
  Assert.IsTrue(pcOne in Categories);
  Assert.IsTrue(pcTwo in Categories);
  Assert.IsTrue(pcFew in Categories);
  Assert.IsTrue(pcMany in Categories);
  Assert.IsTrue(pcOther in Categories);
end;

// ============================================================================
// TIrishPluralTests
// ============================================================================

procedure TIrishPluralTests.Test_Irish_One;
begin
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('ga', 1));
end;

procedure TIrishPluralTests.Test_Irish_Two;
begin
  Assert.AreEqual(pcTwo, TPluralRules.GetCategory('ga', 2));
end;

procedure TIrishPluralTests.Test_Irish_Few;
begin
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('ga', 3));
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('ga', 4));
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('ga', 5));
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('ga', 6));
end;

procedure TIrishPluralTests.Test_Irish_Many;
begin
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('ga', 7));
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('ga', 8));
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('ga', 9));
  Assert.AreEqual(pcMany, TPluralRules.GetCategory('ga', 10));
end;

procedure TIrishPluralTests.Test_Irish_Other;
begin
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('ga', 0));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('ga', 11));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('ga', 100));
end;

// ============================================================================
// TSelectFormTests
// ============================================================================

procedure TSelectFormTests.Test_SelectForm_EmptyArray;
begin
  Assert.AreEqual('', TPluralRules.SelectForm('en', 1, []));
end;

procedure TSelectFormTests.Test_SelectForm_SingleForm;
begin
  Assert.AreEqual('item', TPluralRules.SelectForm('en', 1, ['item']));
  Assert.AreEqual('item', TPluralRules.SelectForm('en', 5, ['item']));
end;

procedure TSelectFormTests.Test_SelectForm_English;
begin
  // English: one, other
  Assert.AreEqual('apple', TPluralRules.SelectForm('en', 1, ['apple', 'apples']));
  Assert.AreEqual('apples', TPluralRules.SelectForm('en', 0, ['apple', 'apples']));
  Assert.AreEqual('apples', TPluralRules.SelectForm('en', 2, ['apple', 'apples']));
  Assert.AreEqual('apples', TPluralRules.SelectForm('en', 100, ['apple', 'apples']));
end;

procedure TSelectFormTests.Test_SelectForm_Russian;
begin
  // Russian: one, few, many, other
  // яблоко (1), яблока (2-4), яблок (5-20, 0)
  Assert.AreEqual('яблоко', TPluralRules.SelectForm('ru', 1, ['яблоко', 'яблока', 'яблок']));
  Assert.AreEqual('яблока', TPluralRules.SelectForm('ru', 2, ['яблоко', 'яблока', 'яблок']));
  Assert.AreEqual('яблок', TPluralRules.SelectForm('ru', 5, ['яблоко', 'яблока', 'яблок']));
  Assert.AreEqual('яблок', TPluralRules.SelectForm('ru', 0, ['яблоко', 'яблока', 'яблок']));
end;

procedure TSelectFormTests.Test_SelectForm_Arabic;
begin
  // Arabic has 6 forms: zero, one, two, few, many, other
  Assert.AreEqual('zero', TPluralRules.SelectForm('ar', 0, ['zero', 'one', 'two', 'few', 'many', 'other']));
  Assert.AreEqual('one', TPluralRules.SelectForm('ar', 1, ['zero', 'one', 'two', 'few', 'many', 'other']));
  Assert.AreEqual('two', TPluralRules.SelectForm('ar', 2, ['zero', 'one', 'two', 'few', 'many', 'other']));
end;

procedure TSelectFormTests.Test_SelectForm_FallbackToLast;
begin
  // If not enough forms provided, fallback to last
  Assert.AreEqual('items', TPluralRules.SelectForm('ru', 5, ['item', 'items']));
end;

// ============================================================================
// TGlobalFunctionTests
// ============================================================================

procedure TGlobalFunctionTests.Test_GetPluralForm_Integer;
begin
  Assert.AreEqual('one', GetPluralForm('en', 1));
  Assert.AreEqual('other', GetPluralForm('en', 2));
end;

procedure TGlobalFunctionTests.Test_GetPluralForm_Double;
begin
  Assert.AreEqual('other', GetPluralForm('en', 1.5));
end;

procedure TGlobalFunctionTests.Test_PluralSelect_Integer;
begin
  Assert.AreEqual('apple', PluralSelect('en', 1, ['apple', 'apples']));
end;

procedure TGlobalFunctionTests.Test_PluralSelect_Double;
begin
  Assert.AreEqual('apples', PluralSelect('en', 1.5, ['apple', 'apples']));
end;

// ============================================================================
// TLanguageFallbackTests
// ============================================================================

procedure TLanguageFallbackTests.Test_LanguageCode_CaseInsensitive;
begin
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('EN', 1));
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('En', 1));
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('eN', 1));
end;

procedure TLanguageFallbackTests.Test_LanguageVariant_FallsBackToBase;
begin
  // en-US should fall back to en
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('en-US', 1));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('en-US', 2));
end;

procedure TLanguageFallbackTests.Test_UnknownLanguage_FallsBackToEnglish;
begin
  // Unknown language should fall back to English rules
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('xyz', 1));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('xyz', 2));
end;

procedure TLanguageFallbackTests.Test_PortugueseBrazil;
begin
  // pt-BR has its own rule (same as French)
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('pt-BR', 0));
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('pt-BR', 1));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('pt-BR', 2));
end;

// ============================================================================
// TCustomRuleTests
// ============================================================================

procedure TCustomRuleTests.Test_RegisterCustomRule;
begin
  TPluralRules.RegisterRule('test-lang', [pcOne, pcOther],
    function(n: Double; i, v, w, f, t: Int64): TPluralCategory
    begin
      if i = 42 then
        Result := pcOne
      else
        Result := pcOther;
    end);

  Assert.AreEqual(pcOne, TPluralRules.GetCategory('test-lang', 42));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('test-lang', 1));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('test-lang', 100));
end;

procedure TCustomRuleTests.Test_OverrideExistingRule;
var
  OriginalCategory: TPluralCategory;
begin
  // Get original English result for 1
  OriginalCategory := TPluralRules.GetCategory('en', 1);
  Assert.AreEqual(pcOne, OriginalCategory);

  // Register override
  TPluralRules.RegisterRule('en-custom', [pcOther],
    function(n: Double; i, v, w, f, t: Int64): TPluralCategory
    begin
      Result := pcOther;  // Always return other
    end);

  Assert.AreEqual(pcOther, TPluralRules.GetCategory('en-custom', 1));
end;

// ============================================================================
// TDecimalPluralTests
// ============================================================================

procedure TDecimalPluralTests.Test_English_Decimal_1_0;
begin
  // 1.0 should be treated as integer 1 with 0 visible fraction digits
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('en', 1.0));
end;

procedure TDecimalPluralTests.Test_English_Decimal_1_5;
begin
  // 1.5 has visible fraction digits, so it's "other"
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('en', 1.5));
end;

procedure TDecimalPluralTests.Test_Russian_Decimal;
begin
  // Decimals in Russian go to "other" category
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('ru', 1.5));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('ru', 2.5));
end;

procedure TDecimalPluralTests.Test_French_Decimal;
begin
  // French: decimals under 2 are "one"
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('fr', 0.5));
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('fr', 1.5));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('fr', 2.5));
end;

// ============================================================================
// TAdditionalLanguageTests
// ============================================================================

procedure TAdditionalLanguageTests.Test_German;
begin
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('de', 1));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('de', 0));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('de', 2));
end;

procedure TAdditionalLanguageTests.Test_Lithuanian_One;
begin
  // Lithuanian: n mod 10 = 1 and n mod 100 != 11..19
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('lt', 1));
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('lt', 21));
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('lt', 31));
end;

procedure TAdditionalLanguageTests.Test_Lithuanian_Few;
begin
  // Lithuanian: n mod 10 = 2..9 and n mod 100 != 11..19
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('lt', 2));
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('lt', 9));
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('lt', 22));
end;

procedure TAdditionalLanguageTests.Test_Lithuanian_Other;
begin
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('lt', 0));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('lt', 10));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('lt', 11));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('lt', 19));
end;

procedure TAdditionalLanguageTests.Test_Latvian_Zero;
begin
  // Latvian: n mod 10 = 0 or n mod 100 = 11..19
  Assert.AreEqual(pcZero, TPluralRules.GetCategory('lv', 0));
  Assert.AreEqual(pcZero, TPluralRules.GetCategory('lv', 10));
  Assert.AreEqual(pcZero, TPluralRules.GetCategory('lv', 11));
  Assert.AreEqual(pcZero, TPluralRules.GetCategory('lv', 19));
end;

procedure TAdditionalLanguageTests.Test_Latvian_One;
begin
  // Latvian: n mod 10 = 1 and n mod 100 != 11
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('lv', 1));
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('lv', 21));
end;

procedure TAdditionalLanguageTests.Test_Latvian_Other;
begin
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('lv', 2));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('lv', 5));
end;

procedure TAdditionalLanguageTests.Test_Slovenian_One;
begin
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('sl', 1));
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('sl', 101));
end;

procedure TAdditionalLanguageTests.Test_Slovenian_Two;
begin
  Assert.AreEqual(pcTwo, TPluralRules.GetCategory('sl', 2));
  Assert.AreEqual(pcTwo, TPluralRules.GetCategory('sl', 102));
end;

procedure TAdditionalLanguageTests.Test_Slovenian_Few;
begin
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('sl', 3));
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('sl', 4));
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('sl', 103));
end;

procedure TAdditionalLanguageTests.Test_Slovenian_Other;
begin
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('sl', 0));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('sl', 5));
end;

procedure TAdditionalLanguageTests.Test_Hebrew_One;
begin
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('he', 1));
end;

procedure TAdditionalLanguageTests.Test_Hebrew_Two;
begin
  Assert.AreEqual(pcTwo, TPluralRules.GetCategory('he', 2));
end;

procedure TAdditionalLanguageTests.Test_Hebrew_Other;
begin
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('he', 0));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('he', 3));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('he', 10));
end;

procedure TAdditionalLanguageTests.Test_Romanian_One;
begin
  Assert.AreEqual(pcOne, TPluralRules.GetCategory('ro', 1));
end;

procedure TAdditionalLanguageTests.Test_Romanian_Few;
begin
  // Romanian: n = 0 or n mod 100 = 1..19
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('ro', 0));
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('ro', 2));
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('ro', 19));
  Assert.AreEqual(pcFew, TPluralRules.GetCategory('ro', 101));
end;

procedure TAdditionalLanguageTests.Test_Romanian_Other;
begin
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('ro', 20));
  Assert.AreEqual(pcOther, TPluralRules.GetCategory('ro', 100));
end;

initialization
  TDUnitX.RegisterTestFixture(TPluralCategoryTests);
  TDUnitX.RegisterTestFixture(TEnglishPluralTests);
  TDUnitX.RegisterTestFixture(TFrenchPluralTests);
  TDUnitX.RegisterTestFixture(TRussianPluralTests);
  TDUnitX.RegisterTestFixture(TPolishPluralTests);
  TDUnitX.RegisterTestFixture(TArabicPluralTests);
  TDUnitX.RegisterTestFixture(TCJKPluralTests);
  TDUnitX.RegisterTestFixture(TCzechPluralTests);
  TDUnitX.RegisterTestFixture(TWelshPluralTests);
  TDUnitX.RegisterTestFixture(TIrishPluralTests);
  TDUnitX.RegisterTestFixture(TSelectFormTests);
  TDUnitX.RegisterTestFixture(TGlobalFunctionTests);
  TDUnitX.RegisterTestFixture(TLanguageFallbackTests);
  TDUnitX.RegisterTestFixture(TCustomRuleTests);
  TDUnitX.RegisterTestFixture(TDecimalPluralTests);
  TDUnitX.RegisterTestFixture(TAdditionalLanguageTests);

end.
