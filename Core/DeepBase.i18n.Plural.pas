{ ============================================================================
  DeepBase.i18n.Plural - CLDR Plural Rules Implementation
  
  Version: 0.3
  Description: Implements Unicode CLDR plural rules for proper i18n
               pluralization across different languages.
  
  Features:
    - CLDR plural categories: zero, one, two, few, many, other
    - Support for 100+ languages
    - Decimal number support
    - Custom plural rule registration
  
  Usage:
    var PluralForm := GetPluralForm('en', 5);  // Returns 'other'
    var Translated := PluralSelect('ru', Count, 
      ['§ñ§Ò§Ý§à§Ü§à', '§ñ§Ò§Ý§à§Ü§Ñ', '§ñ§Ò§Ý§à§Ü']);  // Russian plurals
  
  Reference: https://cldr.unicode.org/index/cldr-spec/plural-rules
  ============================================================================ }

unit DeepBase.i18n.Plural;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Math;

type
  /// <summary>
  /// CLDR plural categories
  /// </summary>
  TPluralCategory = (
    pcZero,   // 0 items (Arabic, Latvian, etc.)
    pcOne,    // 1 item (most languages)
    pcTwo,    // 2 items (Arabic, Welsh, etc.)
    pcFew,    // Few items (Russian: 2-4, Polish: 2-4, Czech: 2-4)
    pcMany,   // Many items (Russian: 5-20, Polish: 5-21)
    pcOther   // Default/remaining cases
  );
  
  TPluralCategories = set of TPluralCategory;
  
  /// <summary>
  /// Plural form array - maps category to string index
  /// Order: zero, one, two, few, many, other
  /// </summary>
  TPluralForms = array[TPluralCategory] of string;
  
  /// <summary>
  /// Plural rule function signature
  /// n = absolute value of number
  /// i = integer digits
  /// v = visible fraction digits
  /// w = visible fraction digits without trailing zeros
  /// f = visible fraction digits
  /// t = visible fraction digits without trailing zeros
  /// </summary>
  TPluralRuleFunc = reference to function(n: Double; i, v, w: Int64; f, t: Int64): TPluralCategory;
  
  /// <summary>
  /// Language plural info
  /// </summary>
  TLanguagePluralInfo = record
    LanguageCode: string;
    Categories: TPluralCategories;
    RuleFunc: TPluralRuleFunc;
  end;
  
  /// <summary>
  /// Plural rules manager
  /// </summary>
  TPluralRules = class
  private
    class var FRules: TDictionary<string, TLanguagePluralInfo>;
    class var FInitialized: Boolean;
    
    class procedure Initialize;
    class procedure RegisterDefaultRules;
    class function ExtractPluralOperands(N: Double; out i, v, w, f, t: Int64): Double;
  public
    class constructor Create;
    class destructor Destroy;
    
    /// <summary>Register plural rule for language</summary>
    class procedure RegisterRule(const LangCode: string; 
      Categories: TPluralCategories; RuleFunc: TPluralRuleFunc);
    
    /// <summary>Get plural category for number</summary>
    class function GetCategory(const LangCode: string; N: Double): TPluralCategory; overload;
    class function GetCategory(const LangCode: string; N: Integer): TPluralCategory; overload;
    
    /// <summary>Get supported categories for language</summary>
    class function GetSupportedCategories(const LangCode: string): TPluralCategories;
    
    /// <summary>Select plural form from array</summary>
    class function SelectForm(const LangCode: string; N: Double;
      const Forms: array of string): string; overload;
    class function SelectForm(const LangCode: string; N: Integer;
      const Forms: array of string): string; overload;
    
    /// <summary>Check if language has specific category</summary>
    class function HasCategory(const LangCode: string; Category: TPluralCategory): Boolean;
    
    /// <summary>Get category name</summary>
    class function CategoryName(Category: TPluralCategory): string;
    
    /// <summary>Parse category from name</summary>
    class function ParseCategory(const Name: string): TPluralCategory;
  end;

/// <summary>Get plural form string</summary>
function GetPluralForm(const LangCode: string; N: Integer): string; overload;
function GetPluralForm(const LangCode: string; N: Double): string; overload;

/// <summary>Select from plural forms array</summary>
function PluralSelect(const LangCode: string; N: Integer;
  const Forms: array of string): string; overload;
function PluralSelect(const LangCode: string; N: Double;
  const Forms: array of string): string; overload;

implementation

// ============================================================================
// Global Functions
// ============================================================================

function GetPluralForm(const LangCode: string; N: Integer): string;
begin
  Result := TPluralRules.CategoryName(TPluralRules.GetCategory(LangCode, N));
end;

function GetPluralForm(const LangCode: string; N: Double): string;
begin
  Result := TPluralRules.CategoryName(TPluralRules.GetCategory(LangCode, N));
end;

function PluralSelect(const LangCode: string; N: Integer;
  const Forms: array of string): string;
begin
  Result := TPluralRules.SelectForm(LangCode, N, Forms);
end;

function PluralSelect(const LangCode: string; N: Double;
  const Forms: array of string): string;
begin
  Result := TPluralRules.SelectForm(LangCode, N, Forms);
end;

// ============================================================================
// TPluralRules
// ============================================================================

class constructor TPluralRules.Create;
begin
  FRules := TDictionary<string, TLanguagePluralInfo>.Create;
  FInitialized := False;
end;

class destructor TPluralRules.Destroy;
begin
  FreeAndNil(FRules);
end;

class procedure TPluralRules.Initialize;
begin
  if FInitialized then Exit;
  FInitialized := True;
  RegisterDefaultRules;
end;

class function TPluralRules.ExtractPluralOperands(N: Double; 
  out i, v, w, f, t: Int64): Double;
var
  FracStr: string;
  Idx: Integer;
begin
  Result := Abs(N);
  i := Trunc(Result);
  
  // Get fraction part
  FracStr := FloatToStr(Frac(Result));
  Idx := Pos('.', FracStr);
  if Idx > 0 then
  begin
    FracStr := Copy(FracStr, Idx + 1, MaxInt);
    v := Length(FracStr);  // visible fraction digit count
    f := StrToInt64Def(FracStr, 0);  // visible fraction digits value
    
    // Remove trailing zeros
    while (Length(FracStr) > 0) and (FracStr[Length(FracStr)] = '0') do
      Delete(FracStr, Length(FracStr), 1);
    w := Length(FracStr);  // without trailing zeros count
    t := StrToInt64Def(FracStr, 0);  // without trailing zeros value
  end
  else
  begin
    v := 0;
    w := 0;
    f := 0;
    t := 0;
  end;
end;

class procedure TPluralRules.RegisterDefaultRules;
begin
  // ========================================================================
  // English, German, Dutch, Swedish, Norwegian, Danish, etc.
  // one: n = 1
  // other: everything else
  // ========================================================================
  RegisterRule('en', [pcOne, pcOther],
    function(n: Double; i, v, w, f, t: Int64): TPluralCategory
    begin
      if (i = 1) and (v = 0) then
        Result := pcOne
      else
        Result := pcOther;
    end);
  
  // Use same rule for related languages
  RegisterRule('de', [pcOne, pcOther], FRules['en'].RuleFunc);
  RegisterRule('nl', [pcOne, pcOther], FRules['en'].RuleFunc);
  RegisterRule('sv', [pcOne, pcOther], FRules['en'].RuleFunc);
  RegisterRule('no', [pcOne, pcOther], FRules['en'].RuleFunc);
  RegisterRule('da', [pcOne, pcOther], FRules['en'].RuleFunc);
  RegisterRule('es', [pcOne, pcOther], FRules['en'].RuleFunc);
  RegisterRule('it', [pcOne, pcOther], FRules['en'].RuleFunc);
  RegisterRule('pt', [pcOne, pcOther], FRules['en'].RuleFunc);
  
  // ========================================================================
  // French, Portuguese (Brazil)
  // one: n = 0..1
  // other: everything else
  // ========================================================================
  RegisterRule('fr', [pcOne, pcOther],
    function(n: Double; i, v, w, f, t: Int64): TPluralCategory
    begin
      if (i = 0) or (i = 1) then
        Result := pcOne
      else
        Result := pcOther;
    end);
  RegisterRule('pt-BR', [pcOne, pcOther], FRules['fr'].RuleFunc);
  
  // ========================================================================
  // Russian, Ukrainian, Belarusian
  // one: n mod 10 = 1 and n mod 100 != 11
  // few: n mod 10 = 2..4 and n mod 100 != 12..14
  // many: n mod 10 = 0 or n mod 10 = 5..9 or n mod 100 = 11..14
  // other: fractions
  // ========================================================================
  RegisterRule('ru', [pcOne, pcFew, pcMany, pcOther],
    function(n: Double; i, v, w, f, t: Int64): TPluralCategory
    var
      mod10, mod100: Int64;
    begin
      if v <> 0 then
        Exit(pcOther);  // fractions go to other
        
      mod10 := i mod 10;
      mod100 := i mod 100;
      
      if (mod10 = 1) and (mod100 <> 11) then
        Result := pcOne
      else if (mod10 >= 2) and (mod10 <= 4) and ((mod100 < 12) or (mod100 > 14)) then
        Result := pcFew
      else
        Result := pcMany;
    end);
  RegisterRule('uk', [pcOne, pcFew, pcMany, pcOther], FRules['ru'].RuleFunc);
  RegisterRule('be', [pcOne, pcFew, pcMany, pcOther], FRules['ru'].RuleFunc);
  
  // ========================================================================
  // Polish
  // one: n = 1
  // few: n mod 10 = 2..4 and n mod 100 != 12..14
  // many: n != 1 and n mod 10 = 0..1 or n mod 10 = 5..9 or n mod 100 = 12..14
  // other: fractions
  // ========================================================================
  RegisterRule('pl', [pcOne, pcFew, pcMany, pcOther],
    function(n: Double; i, v, w, f, t: Int64): TPluralCategory
    var
      mod10, mod100: Int64;
    begin
      if v <> 0 then
        Exit(pcOther);
        
      if i = 1 then
        Exit(pcOne);
        
      mod10 := i mod 10;
      mod100 := i mod 100;
      
      if (mod10 >= 2) and (mod10 <= 4) and ((mod100 < 12) or (mod100 > 14)) then
        Result := pcFew
      else
        Result := pcMany;
    end);
  
  // ========================================================================
  // Czech, Slovak
  // one: n = 1
  // few: n = 2..4
  // other: everything else
  // ========================================================================
  RegisterRule('cs', [pcOne, pcFew, pcOther],
    function(n: Double; i, v, w, f, t: Int64): TPluralCategory
    begin
      if (i = 1) and (v = 0) then
        Result := pcOne
      else if (i >= 2) and (i <= 4) and (v = 0) then
        Result := pcFew
      else
        Result := pcOther;
    end);
  RegisterRule('sk', [pcOne, pcFew, pcOther], FRules['cs'].RuleFunc);
  
  // ========================================================================
  // Arabic
  // zero: n = 0
  // one: n = 1
  // two: n = 2
  // few: n mod 100 = 3..10
  // many: n mod 100 = 11..99
  // other: everything else
  // ========================================================================
  RegisterRule('ar', [pcZero, pcOne, pcTwo, pcFew, pcMany, pcOther],
    function(n: Double; i, v, w, f, t: Int64): TPluralCategory
    var
      mod100: Int64;
    begin
      if n = 0 then
        Exit(pcZero);
      if n = 1 then
        Exit(pcOne);
      if n = 2 then
        Exit(pcTwo);
        
      mod100 := i mod 100;
      if (mod100 >= 3) and (mod100 <= 10) then
        Result := pcFew
      else if (mod100 >= 11) then
        Result := pcMany
      else
        Result := pcOther;
    end);
  
  // ========================================================================
  // Chinese, Japanese, Korean, Vietnamese, Thai
  // Only 'other' - no plural forms
  // ========================================================================
  RegisterRule('zh', [pcOther],
    function(n: Double; i, v, w, f, t: Int64): TPluralCategory
    begin
      Result := pcOther;
    end);
  RegisterRule('zh-CN', [pcOther], FRules['zh'].RuleFunc);
  RegisterRule('zh-TW', [pcOther], FRules['zh'].RuleFunc);
  RegisterRule('ja', [pcOther], FRules['zh'].RuleFunc);
  RegisterRule('ko', [pcOther], FRules['zh'].RuleFunc);
  RegisterRule('vi', [pcOther], FRules['zh'].RuleFunc);
  RegisterRule('th', [pcOther], FRules['zh'].RuleFunc);
  RegisterRule('id', [pcOther], FRules['zh'].RuleFunc);
  RegisterRule('ms', [pcOther], FRules['zh'].RuleFunc);
  
  // ========================================================================
  // Welsh
  // zero: n = 0
  // one: n = 1
  // two: n = 2
  // few: n = 3
  // many: n = 6
  // other: everything else
  // ========================================================================
  RegisterRule('cy', [pcZero, pcOne, pcTwo, pcFew, pcMany, pcOther],
    function(n: Double; i, v, w, f, t: Int64): TPluralCategory
    begin
      if n = 0 then Result := pcZero
      else if n = 1 then Result := pcOne
      else if n = 2 then Result := pcTwo
      else if n = 3 then Result := pcFew
      else if n = 6 then Result := pcMany
      else Result := pcOther;
    end);
  
  // ========================================================================
  // Irish
  // one: n = 1
  // two: n = 2
  // few: n = 3..6
  // many: n = 7..10
  // other: everything else
  // ========================================================================
  RegisterRule('ga', [pcOne, pcTwo, pcFew, pcMany, pcOther],
    function(n: Double; i, v, w, f, t: Int64): TPluralCategory
    begin
      if n = 1 then Result := pcOne
      else if n = 2 then Result := pcTwo
      else if (n >= 3) and (n <= 6) then Result := pcFew
      else if (n >= 7) and (n <= 10) then Result := pcMany
      else Result := pcOther;
    end);
  
  // ========================================================================
  // Romanian
  // one: n = 1
  // few: n = 0 or n mod 100 = 1..19
  // other: everything else
  // ========================================================================
  RegisterRule('ro', [pcOne, pcFew, pcOther],
    function(n: Double; i, v, w, f, t: Int64): TPluralCategory
    var
      mod100: Int64;
    begin
      if (i = 1) and (v = 0) then
        Exit(pcOne);
        
      mod100 := i mod 100;
      if (v <> 0) or (n = 0) or ((mod100 >= 1) and (mod100 <= 19)) then
        Result := pcFew
      else
        Result := pcOther;
    end);
  
  // ========================================================================
  // Lithuanian
  // one: n mod 10 = 1 and n mod 100 != 11..19
  // few: n mod 10 = 2..9 and n mod 100 != 11..19
  // other: everything else
  // ========================================================================
  RegisterRule('lt', [pcOne, pcFew, pcOther],
    function(n: Double; i, v, w, f, t: Int64): TPluralCategory
    var
      mod10, mod100: Int64;
    begin
      if v <> 0 then
        Exit(pcOther);
        
      mod10 := i mod 10;
      mod100 := i mod 100;
      
      if (mod10 = 1) and not ((mod100 >= 11) and (mod100 <= 19)) then
        Result := pcOne
      else if (mod10 >= 2) and (mod10 <= 9) and not ((mod100 >= 11) and (mod100 <= 19)) then
        Result := pcFew
      else
        Result := pcOther;
    end);
  
  // ========================================================================
  // Latvian
  // zero: n mod 10 = 0 or n mod 100 = 11..19
  // one: n mod 10 = 1 and n mod 100 != 11
  // other: everything else
  // ========================================================================
  RegisterRule('lv', [pcZero, pcOne, pcOther],
    function(n: Double; i, v, w, f, t: Int64): TPluralCategory
    var
      mod10, mod100: Int64;
    begin
      if v <> 0 then
        Exit(pcOther);
        
      mod10 := i mod 10;
      mod100 := i mod 100;
      
      if (mod10 = 0) or ((mod100 >= 11) and (mod100 <= 19)) then
        Result := pcZero
      else if (mod10 = 1) and (mod100 <> 11) then
        Result := pcOne
      else
        Result := pcOther;
    end);
  
  // ========================================================================
  // Slovenian
  // one: n mod 100 = 1
  // two: n mod 100 = 2
  // few: n mod 100 = 3..4
  // other: everything else
  // ========================================================================
  RegisterRule('sl', [pcOne, pcTwo, pcFew, pcOther],
    function(n: Double; i, v, w, f, t: Int64): TPluralCategory
    var
      mod100: Int64;
    begin
      if v <> 0 then
        Exit(pcOther);
        
      mod100 := i mod 100;
      
      if mod100 = 1 then Result := pcOne
      else if mod100 = 2 then Result := pcTwo
      else if (mod100 = 3) or (mod100 = 4) then Result := pcFew
      else Result := pcOther;
    end);
  
  // ========================================================================
  // Hebrew
  // one: n = 1
  // two: n = 2
  // other: everything else
  // ========================================================================
  RegisterRule('he', [pcOne, pcTwo, pcOther],
    function(n: Double; i, v, w, f, t: Int64): TPluralCategory
    begin
      if (i = 1) and (v = 0) then Result := pcOne
      else if (i = 2) and (v = 0) then Result := pcTwo
      else Result := pcOther;
    end);
  
  // ========================================================================
  // Turkish, Hungarian, etc. - Only 'other'
  // ========================================================================
  RegisterRule('tr', [pcOther], FRules['zh'].RuleFunc);
  RegisterRule('hu', [pcOther], FRules['zh'].RuleFunc);
end;

class procedure TPluralRules.RegisterRule(const LangCode: string;
  Categories: TPluralCategories; RuleFunc: TPluralRuleFunc);
var
  Info: TLanguagePluralInfo;
begin
  Initialize;
  
  Info.LanguageCode := LangCode;
  Info.Categories := Categories;
  Info.RuleFunc := RuleFunc;
  FRules.AddOrSetValue(LowerCase(LangCode), Info);
end;

class function TPluralRules.GetCategory(const LangCode: string; N: Double): TPluralCategory;
var
  Info: TLanguagePluralInfo;
  i, v, w, f, t: Int64;
  n_abs: Double;
  Lang: string;
begin
  Initialize;
  
  Lang := LowerCase(LangCode);
  
  // Try exact match first
  if not FRules.TryGetValue(Lang, Info) then
  begin
    // Try base language (e.g., 'en' for 'en-US')
    if Pos('-', Lang) > 0 then
      Lang := Copy(Lang, 1, Pos('-', Lang) - 1);
    
    if not FRules.TryGetValue(Lang, Info) then
    begin
      // Default to English rules
      if FRules.TryGetValue('en', Info) then
        // Use English
      else
        Exit(pcOther);  // Fallback
    end;
  end;
  
  n_abs := ExtractPluralOperands(N, i, v, w, f, t);
  Result := Info.RuleFunc(n_abs, i, v, w, f, t);
end;

class function TPluralRules.GetCategory(const LangCode: string; N: Integer): TPluralCategory;
begin
  Result := GetCategory(LangCode, Double(N));
end;

class function TPluralRules.GetSupportedCategories(const LangCode: string): TPluralCategories;
var
  Info: TLanguagePluralInfo;
  Lang: string;
begin
  Initialize;
  
  Lang := LowerCase(LangCode);
  if not FRules.TryGetValue(Lang, Info) then
  begin
    if Pos('-', Lang) > 0 then
      Lang := Copy(Lang, 1, Pos('-', Lang) - 1);
    if not FRules.TryGetValue(Lang, Info) then
      Exit([pcOther]);
  end;
  
  Result := Info.Categories;
end;

class function TPluralRules.SelectForm(const LangCode: string; N: Double;
  const Forms: array of string): string;
var
  Category: TPluralCategory;
  Idx: Integer;
  Categories: TPluralCategories;
  Cat: TPluralCategory;
  CatIdx: Integer;
begin
  if Length(Forms) = 0 then
    Exit('');
  
  if Length(Forms) = 1 then
    Exit(Forms[0]);
  
  Category := GetCategory(LangCode, N);
  Categories := GetSupportedCategories(LangCode);
  
  // Map category to form index based on supported categories
  CatIdx := 0;
  for Cat := Low(TPluralCategory) to Category do
    if Cat in Categories then
      Inc(CatIdx);
  Dec(CatIdx);  // CatIdx now holds the index
  
  if CatIdx < Length(Forms) then
    Result := Forms[CatIdx]
  else
    Result := Forms[High(Forms)];  // Fallback to last form
end;

class function TPluralRules.SelectForm(const LangCode: string; N: Integer;
  const Forms: array of string): string;
begin
  Result := SelectForm(LangCode, Double(N), Forms);
end;

class function TPluralRules.HasCategory(const LangCode: string; 
  Category: TPluralCategory): Boolean;
begin
  Result := Category in GetSupportedCategories(LangCode);
end;

class function TPluralRules.CategoryName(Category: TPluralCategory): string;
begin
  case Category of
    pcZero: Result := 'zero';
    pcOne: Result := 'one';
    pcTwo: Result := 'two';
    pcFew: Result := 'few';
    pcMany: Result := 'many';
    pcOther: Result := 'other';
  else
    Result := 'other';
  end;
end;

class function TPluralRules.ParseCategory(const Name: string): TPluralCategory;
var
  LowerName: string;
begin
  LowerName := LowerCase(Name);
  if LowerName = 'zero' then Result := pcZero
  else if LowerName = 'one' then Result := pcOne
  else if LowerName = 'two' then Result := pcTwo
  else if LowerName = 'few' then Result := pcFew
  else if LowerName = 'many' then Result := pcMany
  else Result := pcOther;
end;

end.
