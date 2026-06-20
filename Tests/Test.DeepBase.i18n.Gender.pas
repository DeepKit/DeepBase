unit Test.DeepBase.i18n.Gender;

{*******************************************************************************
  Unit Tests for DeepBase.i18n.Gender
  Tests grammatical gender, case variants, RTL support and capitalization
*******************************************************************************}

interface
uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestDeepBaseI18nGender = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // TGenderVariant Tests
    [Test]
    procedure TestGenderVariantHasGender;
    [Test]
    procedure TestGenderVariantHasCases;
    [Test]
    procedure TestGenderVariantGetDirection;
    [Test]
    procedure TestGenderVariantIsRTL;
    [Test]
    procedure TestGenderVariantSelectMasculine;
    [Test]
    procedure TestGenderVariantSelectFeminine;
    [Test]
    procedure TestGenderVariantSelectNeuter;
    [Test]
    procedure TestGenderVariantTransformFrench;
    [Test]
    procedure TestGenderVariantTransformSpanish;
    [Test]
    procedure TestGenderVariantFormat;

    // TCaseVariant Tests
    [Test]
    procedure TestCaseVariantSelect;
    [Test]
    procedure TestCaseVariantGetCaseName;

    // TRTLUtils Tests
    [Test]
    procedure TestRTLIsRTLChar;
    [Test]
    procedure TestRTLContainsRTL;
    [Test]
    procedure TestRTLGetDominantDirection;
    [Test]
    procedure TestRTLEmbedRTL;
    [Test]
    procedure TestRTLEmbedLTR;
    [Test]
    procedure TestRTLReverseString;

    // TCaseUtils Tests
    [Test]
    procedure TestCaseUtilsToLower;
    [Test]
    procedure TestCaseUtilsToUpper;
    [Test]
    procedure TestCaseUtilsToTitleCase;
    [Test]
    procedure TestCaseUtilsToSentenceCase;
    [Test]
    procedure TestCaseUtilsCapitalize;
    [Test]
    procedure TestCaseUtilsUncapitalize;
    [Test]
    procedure TestCaseUtilsIsLower;
    [Test]
    procedure TestCaseUtilsIsUpper;
    [Test]
    procedure TestCaseUtilsApply;

    // Language-specific Tests
    [Test]
    procedure TestGermanGenders;
    [Test]
    procedure TestRussianCases;
    [Test]
    procedure TestArabicRTL;
    [Test]
    procedure TestChineseNoGender;

    // Global Helper Tests
    [Test]
    procedure TestGlobalGenderSelect;
    [Test]
    procedure TestGlobalCaseSelect;
    [Test]
    procedure TestGlobalIsRTLLanguage;
    [Test]
    procedure TestGlobalGetGenderName;
    [Test]
    procedure TestGlobalGetCaseName;
  end;
implementation
uses
  System.SysUtils,
  System.Generics.Collections,
  DeepBase.i18n.Gender;

procedure TTestDeepBaseI18nGender.Setup;
begin
end;

procedure TTestDeepBaseI18nGender.TearDown;
begin
end;

// TGenderVariant Tests

procedure TTestDeepBaseI18nGender.TestGenderVariantHasGender;
begin
  Assert.IsTrue(TGenderVariant.HasGender('de'));
  Assert.IsTrue(TGenderVariant.HasGender('fr'));
  Assert.IsTrue(TGenderVariant.HasGender('es'));
  Assert.IsTrue(TGenderVariant.HasGender('ru'));
  Assert.IsFalse(TGenderVariant.HasGender('en'));
  Assert.IsFalse(TGenderVariant.HasGender('zh'));
  Assert.IsFalse(TGenderVariant.HasGender('ja'));
end;

procedure TTestDeepBaseI18nGender.TestGenderVariantHasCases;
begin
  Assert.IsTrue(TGenderVariant.HasCases('de'));
  Assert.IsTrue(TGenderVariant.HasCases('ru'));
  Assert.IsTrue(TGenderVariant.HasCases('pl'));
  Assert.IsTrue(TGenderVariant.HasCases('tr'));
  Assert.IsFalse(TGenderVariant.HasCases('en'));
  Assert.IsFalse(TGenderVariant.HasCases('fr'));
  Assert.IsFalse(TGenderVariant.HasCases('zh'));
end;

procedure TTestDeepBaseI18nGender.TestGenderVariantGetDirection;
begin
  Assert.AreEqual(tdLeftToRight, TGenderVariant.GetDirection('en'));
  Assert.AreEqual(tdLeftToRight, TGenderVariant.GetDirection('de'));
  Assert.AreEqual(tdLeftToRight, TGenderVariant.GetDirection('zh'));
  Assert.AreEqual(tdRightToLeft, TGenderVariant.GetDirection('ar'));
  Assert.AreEqual(tdRightToLeft, TGenderVariant.GetDirection('he'));
  Assert.AreEqual(tdRightToLeft, TGenderVariant.GetDirection('fa'));
end;

procedure TTestDeepBaseI18nGender.TestGenderVariantIsRTL;
begin
  Assert.IsFalse(TGenderVariant.IsRTL('en'));
  Assert.IsFalse(TGenderVariant.IsRTL('de'));
  Assert.IsFalse(TGenderVariant.IsRTL('ru'));
  Assert.IsTrue(TGenderVariant.IsRTL('ar'));
  Assert.IsTrue(TGenderVariant.IsRTL('he'));
  Assert.IsTrue(TGenderVariant.IsRTL('ur'));
end;

procedure TTestDeepBaseI18nGender.TestGenderVariantSelectMasculine;
begin
  Assert.AreEqual('der Mann', TGenderVariant.Select('de', ggMasculine, 
    ['der Mann', 'die Frau', 'das Kind']));
end;

procedure TTestDeepBaseI18nGender.TestGenderVariantSelectFeminine;
begin
  Assert.AreEqual('die Frau', TGenderVariant.Select('de', ggFeminine, 
    ['der Mann', 'die Frau', 'das Kind']));
end;

procedure TTestDeepBaseI18nGender.TestGenderVariantSelectNeuter;
begin
  Assert.AreEqual('das Kind', TGenderVariant.Select('de', ggNeuter, 
    ['der Mann', 'die Frau', 'das Kind']));
end;

procedure TTestDeepBaseI18nGender.TestGenderVariantTransformFrench;
begin
  // French: add 'e' for feminine
  Assert.AreEqual('grande', TGenderVariant.Transform('fr', 'grand', ggFeminine));
  Assert.AreEqual('petit', TGenderVariant.Transform('fr', 'petit', ggMasculine));
  Assert.AreEqual('petite', TGenderVariant.Transform('fr', 'petit', ggFeminine));
end;

procedure TTestDeepBaseI18nGender.TestGenderVariantTransformSpanish;
begin
  // Spanish: replace 'o' with 'a' for feminine
  Assert.AreEqual('alta', TGenderVariant.Transform('es', 'alto', ggFeminine));
  Assert.AreEqual('bajo', TGenderVariant.Transform('es', 'bajo', ggMasculine));
  Assert.AreEqual('baja', TGenderVariant.Transform('es', 'bajo', ggFeminine));
end;

procedure TTestDeepBaseI18nGender.TestGenderVariantFormat;
var
  Result: string;
begin
  Result := TGenderVariant.Format('en', 'Hello {name}!', ggUnknown, 
    [TPair<string, string>.Create('name', 'World')]);
  Assert.AreEqual('Hello World!', Result);
end;

// TCaseVariant Tests

procedure TTestDeepBaseI18nGender.TestCaseVariantSelect;
begin
  Assert.AreEqual('dom', TCaseVariant.Select('ru', gcNominative, 
    ['dom', 'doma', 'domu', 'dom', 'domom', 'dome']));
  Assert.AreEqual('doma', TCaseVariant.Select('ru', gcGenitive, 
    ['dom', 'doma', 'domu', 'dom', 'domom', 'dome']));
end;

procedure TTestDeepBaseI18nGender.TestCaseVariantGetCaseName;
begin
  Assert.AreEqual('Nominative', TCaseVariant.GetCaseName(gcNominative));
  Assert.AreEqual('Genitive', TCaseVariant.GetCaseName(gcGenitive));
  Assert.AreEqual('Dative', TCaseVariant.GetCaseName(gcDative));
  Assert.AreEqual('Accusative', TCaseVariant.GetCaseName(gcAccusative));
end;

// TRTLUtils Tests

procedure TTestDeepBaseI18nGender.TestRTLIsRTLChar;
begin
  Assert.IsTrue(TRTLUtils.IsRTLChar(#$0627));  // Arabic Alef
  Assert.IsTrue(TRTLUtils.IsRTLChar(#$05D0));  // Hebrew Alef
  Assert.IsFalse(TRTLUtils.IsRTLChar('A'));
  Assert.IsFalse(TRTLUtils.IsRTLChar('1'));
end;

procedure TTestDeepBaseI18nGender.TestRTLContainsRTL;
begin
  Assert.IsTrue(TRTLUtils.ContainsRTL('Hello '#$0627#$0644#$0639#$0631#$0628#$064A#$0629));
  Assert.IsFalse(TRTLUtils.ContainsRTL('Hello World'));
end;

procedure TTestDeepBaseI18nGender.TestRTLGetDominantDirection;
begin
  Assert.AreEqual(tdLeftToRight, TRTLUtils.GetDominantDirection('Hello World'));
  Assert.AreEqual(tdRightToLeft, TRTLUtils.GetDominantDirection(#$0645#$0631#$062D#$0628#$0627));
end;

procedure TTestDeepBaseI18nGender.TestRTLEmbedRTL;
var
  Result: string;
begin
  Result := TRTLUtils.EmbedRTL('test');
  Assert.IsTrue(Length(Result) > 4);
end;

procedure TTestDeepBaseI18nGender.TestRTLEmbedLTR;
var
  Result: string;
begin
  Result := TRTLUtils.EmbedLTR('test');
  Assert.IsTrue(Length(Result) > 4);
end;

procedure TTestDeepBaseI18nGender.TestRTLReverseString;
begin
  Assert.AreEqual('dcba', TRTLUtils.ReverseString('abcd'));
  Assert.AreEqual('321', TRTLUtils.ReverseString('123'));
  Assert.AreEqual('', TRTLUtils.ReverseString(''));
end;

// TCaseUtils Tests

procedure TTestDeepBaseI18nGender.TestCaseUtilsToLower;
begin
  Assert.AreEqual('hello world', TCaseUtils.ToLower('HELLO WORLD'));
  Assert.AreEqual('hello world', TCaseUtils.ToLower('Hello World'));
end;

procedure TTestDeepBaseI18nGender.TestCaseUtilsToUpper;
begin
  Assert.AreEqual('HELLO WORLD', TCaseUtils.ToUpper('hello world'));
  Assert.AreEqual('HELLO WORLD', TCaseUtils.ToUpper('Hello World'));
end;

procedure TTestDeepBaseI18nGender.TestCaseUtilsToTitleCase;
begin
  Assert.AreEqual('Hello World', TCaseUtils.ToTitleCase('hello world'));
  Assert.AreEqual('Hello World', TCaseUtils.ToTitleCase('HELLO WORLD'));
  Assert.AreEqual('The Quick Brown Fox', TCaseUtils.ToTitleCase('the quick brown fox'));
end;

procedure TTestDeepBaseI18nGender.TestCaseUtilsToSentenceCase;
begin
  Assert.AreEqual('Hello world. How are you?', 
    TCaseUtils.ToSentenceCase('HELLO WORLD. HOW ARE YOU?'));
end;

procedure TTestDeepBaseI18nGender.TestCaseUtilsCapitalize;
begin
  Assert.AreEqual('Hello', TCaseUtils.Capitalize('hello'));
  Assert.AreEqual('Hello', TCaseUtils.Capitalize('Hello'));
  Assert.AreEqual('', TCaseUtils.Capitalize(''));
end;

procedure TTestDeepBaseI18nGender.TestCaseUtilsUncapitalize;
begin
  Assert.AreEqual('hello', TCaseUtils.Uncapitalize('Hello'));
  Assert.AreEqual('hello', TCaseUtils.Uncapitalize('hello'));
  Assert.AreEqual('', TCaseUtils.Uncapitalize(''));
end;

procedure TTestDeepBaseI18nGender.TestCaseUtilsIsLower;
begin
  Assert.IsTrue(TCaseUtils.IsLower('hello'));
  Assert.IsFalse(TCaseUtils.IsLower('Hello'));
  Assert.IsFalse(TCaseUtils.IsLower('HELLO'));
end;

procedure TTestDeepBaseI18nGender.TestCaseUtilsIsUpper;
begin
  Assert.IsTrue(TCaseUtils.IsUpper('HELLO'));
  Assert.IsFalse(TCaseUtils.IsUpper('Hello'));
  Assert.IsFalse(TCaseUtils.IsUpper('hello'));
end;

procedure TTestDeepBaseI18nGender.TestCaseUtilsApply;
begin
  Assert.AreEqual('hello', TCaseUtils.Apply('HELLO', capLowercase));
  Assert.AreEqual('HELLO', TCaseUtils.Apply('hello', capUppercase));
  Assert.AreEqual('Hello World', TCaseUtils.Apply('hello world', capTitleCase));
  Assert.AreEqual('hELLO', TCaseUtils.Apply('Hello', capToggleCase));
end;

// Language-specific Tests

procedure TTestDeepBaseI18nGender.TestGermanGenders;
var
  Info: TLanguageGenderInfo;
begin
  Info := TGenderVariant.GetLanguageInfo('de');
  Assert.IsTrue(ggMasculine in Info.Genders);
  Assert.IsTrue(ggFeminine in Info.Genders);
  Assert.IsTrue(ggNeuter in Info.Genders);
  Assert.IsTrue(gcNominative in Info.Cases);
  Assert.IsTrue(gcGenitive in Info.Cases);
  Assert.IsTrue(gcDative in Info.Cases);
  Assert.IsTrue(gcAccusative in Info.Cases);
end;

procedure TTestDeepBaseI18nGender.TestRussianCases;
var
  Info: TLanguageGenderInfo;
begin
  Info := TGenderVariant.GetLanguageInfo('ru');
  Assert.IsTrue(gcNominative in Info.Cases);
  Assert.IsTrue(gcGenitive in Info.Cases);
  Assert.IsTrue(gcDative in Info.Cases);
  Assert.IsTrue(gcAccusative in Info.Cases);
  Assert.IsTrue(gcInstrumental in Info.Cases);
  Assert.IsTrue(gcPrepositional in Info.Cases);
end;

procedure TTestDeepBaseI18nGender.TestArabicRTL;
var
  Info: TLanguageGenderInfo;
begin
  Info := TGenderVariant.GetLanguageInfo('ar');
  Assert.AreEqual(tdRightToLeft, Info.Direction);
  Assert.IsTrue(ggMasculine in Info.Genders);
  Assert.IsTrue(ggFeminine in Info.Genders);
end;

procedure TTestDeepBaseI18nGender.TestChineseNoGender;
var
  Info: TLanguageGenderInfo;
begin
  Info := TGenderVariant.GetLanguageInfo('zh');
  Assert.IsTrue(Info.Genders = []);
  Assert.IsTrue(Info.Cases = []);
  Assert.AreEqual(tdLeftToRight, Info.Direction);
end;

// Global Helper Tests

procedure TTestDeepBaseI18nGender.TestGlobalGenderSelect;
begin
  Assert.AreEqual('male', GenderSelect('en', ggMasculine, ['male', 'female', 'neutral']));
  Assert.AreEqual('female', GenderSelect('en', ggFeminine, ['male', 'female', 'neutral']));
end;

procedure TTestDeepBaseI18nGender.TestGlobalCaseSelect;
begin
  Assert.AreEqual('nominative', CaseSelect('en', gcNominative, ['nominative', 'genitive']));
  Assert.AreEqual('genitive', CaseSelect('en', gcGenitive, ['nominative', 'genitive']));
end;

procedure TTestDeepBaseI18nGender.TestGlobalIsRTLLanguage;
begin
  Assert.IsFalse(IsRTLLanguage('en'));
  Assert.IsTrue(IsRTLLanguage('ar'));
  Assert.IsTrue(IsRTLLanguage('he'));
end;

procedure TTestDeepBaseI18nGender.TestGlobalGetGenderName;
begin
  Assert.AreEqual('Masculine', GetGenderName(ggMasculine));
  Assert.AreEqual('Feminine', GetGenderName(ggFeminine));
  Assert.AreEqual('Neuter', GetGenderName(ggNeuter));
  Assert.AreEqual('Unknown', GetGenderName(ggUnknown));
end;

procedure TTestDeepBaseI18nGender.TestGlobalGetCaseName;
begin
  Assert.AreEqual('Nominative', GetCaseName(gcNominative));
  Assert.AreEqual('Genitive', GetCaseName(gcGenitive));
  Assert.AreEqual('Accusative', GetCaseName(gcAccusative));
end;
initialization
  TDUnitX.RegisterTestFixture(TTestDeepBaseI18nGender);
end.
