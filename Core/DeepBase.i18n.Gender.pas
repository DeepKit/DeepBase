{ ============================================================================
  DeepBase.i18n.Gender - Gender and Case Variant Support
  
  Version: 0.3
  Description: Implements grammatical gender and case variations for
               proper i18n across different languages.
  
  Features:
    - Grammatical gender: masculine, feminine, neuter, common
    - Case variations: nominative, genitive, dative, accusative, etc.
    - RTL (Right-to-Left) language support
    - Language-specific formatting rules
  
  Usage:
    var Text := TGenderSelect.Select('de', gmMasculine, 
      ['der Mann', 'die Frau', 'das Kind']);
    
    var Greeting := TGenderVariant.Format('fr', 'Cher {name}',
      gmFeminine, [('name', 'Marie')]);  // Returns 'Chere Marie'
  
  Reference: https://cldr.unicode.org/index/cldr-spec/grammatical-features
  ============================================================================ }

unit DeepBase.i18n.Gender;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Character;

type
  /// <summary>
  /// Grammatical gender categories
  /// </summary>
  TGrammaticalGender = (
    ggMasculine,  // Masculine gender (he, der, le)
    ggFeminine,   // Feminine gender (she, die, la)
    ggNeuter,     // Neuter gender (it, das, lo)
    ggCommon,     // Common gender (Swedish: en-words)
    ggAnimate,    // Animate (some Slavic languages)
    ggInanimate,  // Inanimate (some Slavic languages)
    ggUnknown     // Unknown/unspecified
  );
  
  TGrammaticalGenders = set of TGrammaticalGender;
  
  /// <summary>
  /// Grammatical case categories
  /// </summary>
  TGrammaticalCase = (
    gcNominative,   // Subject case (who/what)
    gcGenitive,     // Possessive case (whose/of what)
    gcDative,       // Indirect object (to whom)
    gcAccusative,   // Direct object (whom/what)
    gcInstrumental, // By means of (with what)
    gcLocative,     // Location (where/in what)
    gcVocative,     // Direct address
    gcAblative,     // Motion away from
    gcPrepositional // Used with prepositions (Russian)
  );
  
  TGrammaticalCases = set of TGrammaticalCase;
  
  /// <summary>
  /// Text direction
  /// </summary>
  TTextDirection = (
    tdLeftToRight,  // LTR: English, German, French, etc.
    tdRightToLeft   // RTL: Arabic, Hebrew, Persian, etc.
  );
  
  /// <summary>
  /// Gender variant forms array
  /// Order: masculine, feminine, neuter, common, animate, inanimate, unknown
  /// </summary>
  TGenderForms = array[TGrammaticalGender] of string;
  
  /// <summary>
  /// Case variant forms array
  /// </summary>
  TCaseForms = array[TGrammaticalCase] of string;
  
  /// <summary>
  /// Language gender info
  /// </summary>
  TLanguageGenderInfo = record
    LanguageCode: string;
    Genders: TGrammaticalGenders;
    Cases: TGrammaticalCases;
    Direction: TTextDirection;
    HasGenderAgreement: Boolean;
  end;
  
  /// <summary>
  /// Gender transformation rule
  /// </summary>
  TGenderTransformFunc = reference to function(const AText: string; 
    AGender: TGrammaticalGender): string;
  
  /// <summary>
  /// Case transformation rule
  /// </summary>
  TCaseTransformFunc = reference to function(const AText: string; 
    ACase: TGrammaticalCase): string;
  
  /// <summary>
  /// Gender-aware text formatter
  /// </summary>
  TGenderVariant = class
  private
    class var FLanguageInfo: TDictionary<string, TLanguageGenderInfo>;
    class var FGenderTransforms: TDictionary<string, TGenderTransformFunc>;
    class var FCaseTransforms: TDictionary<string, TCaseTransformFunc>;
    class var FInitialized: Boolean;
    
    class procedure Initialize;
    class procedure RegisterDefaultLanguages;
    class procedure RegisterDefaultTransforms;
  public
    class constructor Create;
    class destructor Destroy;
    
    /// <summary>Register language gender info</summary>
    class procedure RegisterLanguage(const ALangCode: string; 
      AGenders: TGrammaticalGenders; ACases: TGrammaticalCases;
      ADirection: TTextDirection; AHasGenderAgreement: Boolean);
    
    /// <summary>Register gender transformation for language</summary>
    class procedure RegisterGenderTransform(const ALangCode: string;
      ATransform: TGenderTransformFunc);
    
    /// <summary>Register case transformation for language</summary>
    class procedure RegisterCaseTransform(const ALangCode: string;
      ATransform: TCaseTransformFunc);
    
    /// <summary>Get language gender info</summary>
    class function GetLanguageInfo(const ALangCode: string): TLanguageGenderInfo;
    
    /// <summary>Check if language supports grammatical gender</summary>
    class function HasGender(const ALangCode: string): Boolean;
    
    /// <summary>Check if language supports grammatical cases</summary>
    class function HasCases(const ALangCode: string): Boolean;
    
    /// <summary>Get text direction for language</summary>
    class function GetDirection(const ALangCode: string): TTextDirection;
    
    /// <summary>Check if language is RTL</summary>
    class function IsRTL(const ALangCode: string): Boolean;
    
    /// <summary>Select gender variant from array</summary>
    class function Select(const ALangCode: string; AGender: TGrammaticalGender;
      const AForms: array of string): string;
    
    /// <summary>Apply gender transformation</summary>
    class function Transform(const ALangCode: string; const AText: string;
      AGender: TGrammaticalGender): string;
    
    /// <summary>Format text with gender-aware substitutions</summary>
    class function Format(const ALangCode: string; const ATemplate: string;
      AGender: TGrammaticalGender; 
      const AParams: array of TPair<string, string>): string;
  end;
  
  /// <summary>
  /// Case-aware text formatter
  /// </summary>
  TCaseVariant = class
  public
    /// <summary>Select case variant from array</summary>
    class function Select(const ALangCode: string; ACase: TGrammaticalCase;
      const AForms: array of string): string;
    
    /// <summary>Apply case transformation</summary>
    class function Transform(const ALangCode: string; const AText: string;
      ACase: TGrammaticalCase): string;
    
    /// <summary>Get case name</summary>
    class function GetCaseName(ACase: TGrammaticalCase): string;
  end;
  
  /// <summary>
  /// RTL text utilities
  /// </summary>
  TRTLUtils = class
  public
    /// <summary>Check if character is RTL</summary>
    class function IsRTLChar(AChar: Char): Boolean;
    
    /// <summary>Check if string contains RTL characters</summary>
    class function ContainsRTL(const AText: string): Boolean;
    
    /// <summary>Get dominant direction of text</summary>
    class function GetDominantDirection(const AText: string): TTextDirection;
    
    /// <summary>Add RTL embedding marks</summary>
    class function EmbedRTL(const AText: string): string;
    
    /// <summary>Add LTR embedding marks</summary>
    class function EmbedLTR(const AText: string): string;
    
    /// <summary>Normalize bidirectional text</summary>
    class function NormalizeBidi(const AText: string; 
      ADirection: TTextDirection): string;
    
    /// <summary>Reverse string for display</summary>
    class function ReverseString(const AText: string): string;
  end;
  
  /// <summary>
  /// Text capitalization utilities
  /// </summary>
  TCapitalization = (
    capLowercase,     // all lowercase
    capUppercase,     // ALL UPPERCASE
    capTitleCase,     // Title Case
    capSentenceCase,  // Sentence case
    capToggleCase     // tOGGLE cASE
  );
  
  TCaseUtils = class
  public
    /// <summary>Apply capitalization</summary>
    class function Apply(const AText: string; ACap: TCapitalization): string;
    
    /// <summary>Convert to lowercase</summary>
    class function ToLower(const AText: string): string;
    
    /// <summary>Convert to uppercase</summary>
    class function ToUpper(const AText: string): string;
    
    /// <summary>Convert to title case</summary>
    class function ToTitleCase(const AText: string): string;
    
    /// <summary>Convert to sentence case</summary>
    class function ToSentenceCase(const AText: string): string;
    
    /// <summary>Capitalize first character</summary>
    class function Capitalize(const AText: string): string;
    
    /// <summary>Uncapitalize first character</summary>
    class function Uncapitalize(const AText: string): string;
    
    /// <summary>Check if string is all lowercase</summary>
    class function IsLower(const AText: string): Boolean;
    
    /// <summary>Check if string is all uppercase</summary>
    class function IsUpper(const AText: string): Boolean;
    
    /// <summary>Check if string is title case</summary>
    class function IsTitleCase(const AText: string): Boolean;
  end;

/// <summary>Global helper functions</summary>
function GenderSelect(const ALangCode: string; AGender: TGrammaticalGender;
  const AForms: array of string): string;
function CaseSelect(const ALangCode: string; ACase: TGrammaticalCase;
  const AForms: array of string): string;
function IsRTLLanguage(const ALangCode: string): Boolean;
function GetGenderName(AGender: TGrammaticalGender): string;
function GetCaseName(ACase: TGrammaticalCase): string;

implementation

const
  // Unicode bidirectional formatting characters
  LRE = #$202A;  // Left-to-Right Embedding
  RLE = #$202B;  // Right-to-Left Embedding
  PDF = #$202C;  // Pop Directional Formatting
  LRO = #$202D;  // Left-to-Right Override
  RLO = #$202E;  // Right-to-Left Override
  LRM = #$200E;  // Left-to-Right Mark
  RLM = #$200F;  // Right-to-Left Mark
  ALM = #$061C;  // Arabic Letter Mark
  LRI = #$2066;  // Left-to-Right Isolate
  RLI = #$2067;  // Right-to-Left Isolate
  FSI = #$2068;  // First Strong Isolate
  PDI = #$2069;  // Pop Directional Isolate

{ TGenderVariant }

class constructor TGenderVariant.Create;
begin
  FLanguageInfo := TDictionary<string, TLanguageGenderInfo>.Create;
  FGenderTransforms := TDictionary<string, TGenderTransformFunc>.Create;
  FCaseTransforms := TDictionary<string, TCaseTransformFunc>.Create;
  FInitialized := False;
end;

class destructor TGenderVariant.Destroy;
begin
  FLanguageInfo.Free;
  FGenderTransforms.Free;
  FCaseTransforms.Free;
end;

class procedure TGenderVariant.Initialize;
begin
  if FInitialized then Exit;
  RegisterDefaultLanguages;
  RegisterDefaultTransforms;
  FInitialized := True;
end;

class procedure TGenderVariant.RegisterDefaultLanguages;
begin
  // Germanic languages
  RegisterLanguage('en', [], [], tdLeftToRight, False);
  RegisterLanguage('de', [ggMasculine, ggFeminine, ggNeuter], 
    [gcNominative, gcGenitive, gcDative, gcAccusative], tdLeftToRight, True);
  RegisterLanguage('nl', [ggCommon, ggNeuter], [], tdLeftToRight, True);
  RegisterLanguage('sv', [ggCommon, ggNeuter], [], tdLeftToRight, True);
  
  // Romance languages
  RegisterLanguage('fr', [ggMasculine, ggFeminine], [], tdLeftToRight, True);
  RegisterLanguage('es', [ggMasculine, ggFeminine], [], tdLeftToRight, True);
  RegisterLanguage('it', [ggMasculine, ggFeminine], [], tdLeftToRight, True);
  RegisterLanguage('pt', [ggMasculine, ggFeminine], [], tdLeftToRight, True);
  RegisterLanguage('ro', [ggMasculine, ggFeminine, ggNeuter], [], tdLeftToRight, True);
  
  // Slavic languages
  RegisterLanguage('ru', [ggMasculine, ggFeminine, ggNeuter],
    [gcNominative, gcGenitive, gcDative, gcAccusative, gcInstrumental, gcPrepositional],
    tdLeftToRight, True);
  RegisterLanguage('pl', [ggMasculine, ggFeminine, ggNeuter],
    [gcNominative, gcGenitive, gcDative, gcAccusative, gcInstrumental, gcLocative, gcVocative],
    tdLeftToRight, True);
  RegisterLanguage('cs', [ggMasculine, ggFeminine, ggNeuter],
    [gcNominative, gcGenitive, gcDative, gcAccusative, gcVocative, gcLocative, gcInstrumental],
    tdLeftToRight, True);
  RegisterLanguage('uk', [ggMasculine, ggFeminine, ggNeuter],
    [gcNominative, gcGenitive, gcDative, gcAccusative, gcInstrumental, gcLocative, gcVocative],
    tdLeftToRight, True);
  
  // RTL languages
  RegisterLanguage('ar', [ggMasculine, ggFeminine],
    [gcNominative, gcGenitive, gcAccusative], tdRightToLeft, True);
  RegisterLanguage('he', [ggMasculine, ggFeminine], [], tdRightToLeft, True);
  RegisterLanguage('fa', [], [], tdRightToLeft, False);
  RegisterLanguage('ur', [ggMasculine, ggFeminine], [], tdRightToLeft, True);
  
  // Asian languages (no grammatical gender)
  RegisterLanguage('zh', [], [], tdLeftToRight, False);
  RegisterLanguage('ja', [], [], tdLeftToRight, False);
  RegisterLanguage('ko', [], [], tdLeftToRight, False);
  RegisterLanguage('vi', [], [], tdLeftToRight, False);
  RegisterLanguage('th', [], [], tdLeftToRight, False);
  
  // Other languages
  RegisterLanguage('tr', [], [gcNominative, gcGenitive, gcDative, gcAccusative, gcLocative, gcAblative],
    tdLeftToRight, False);
  RegisterLanguage('fi', [], [gcNominative, gcGenitive, gcAccusative, gcInstrumental, gcLocative],
    tdLeftToRight, False);
  RegisterLanguage('hu', [], [gcNominative, gcAccusative, gcDative, gcInstrumental, gcLocative],
    tdLeftToRight, False);
  RegisterLanguage('el', [ggMasculine, ggFeminine, ggNeuter],
    [gcNominative, gcGenitive, gcAccusative, gcVocative], tdLeftToRight, True);
end;

class procedure TGenderVariant.RegisterDefaultTransforms;
begin
  // French gender agreement for adjectives
  RegisterGenderTransform('fr', function(const AText: string; 
    AGender: TGrammaticalGender): string
  begin
    Result := AText;
    if AGender = ggFeminine then
    begin
      // Simple rules: add 'e' for feminine if not already ending in 'e'
      if (Length(Result) > 0) and not CharInSet(Result[Length(Result)], ['e', 'E']) then
        Result := Result + 'e';
    end;
  end);
  
  // Spanish gender agreement
  RegisterGenderTransform('es', function(const AText: string; 
    AGender: TGrammaticalGender): string
  begin
    Result := AText;
    if AGender = ggFeminine then
    begin
      // Simple rule: replace final 'o' with 'a'
      if (Length(Result) > 0) and (Result[Length(Result)] = 'o') then
        Result[Length(Result)] := 'a';
    end;
  end);
  
  // Italian gender agreement
  RegisterGenderTransform('it', function(const AText: string; 
    AGender: TGrammaticalGender): string
  begin
    Result := AText;
    if AGender = ggFeminine then
    begin
      // Simple rule: replace final 'o' with 'a'
      if (Length(Result) > 0) and (Result[Length(Result)] = 'o') then
        Result[Length(Result)] := 'a';
    end;
  end);
  
  // Portuguese gender agreement
  RegisterGenderTransform('pt', function(const AText: string; 
    AGender: TGrammaticalGender): string
  begin
    Result := AText;
    if AGender = ggFeminine then
    begin
      if (Length(Result) > 0) and (Result[Length(Result)] = 'o') then
        Result[Length(Result)] := 'a';
    end;
  end);
end;

class procedure TGenderVariant.RegisterLanguage(const ALangCode: string;
  AGenders: TGrammaticalGenders; ACases: TGrammaticalCases;
  ADirection: TTextDirection; AHasGenderAgreement: Boolean);
var
  Info: TLanguageGenderInfo;
begin
  Info.LanguageCode := LowerCase(ALangCode);
  Info.Genders := AGenders;
  Info.Cases := ACases;
  Info.Direction := ADirection;
  Info.HasGenderAgreement := AHasGenderAgreement;
  FLanguageInfo.AddOrSetValue(Info.LanguageCode, Info);
end;

class procedure TGenderVariant.RegisterGenderTransform(const ALangCode: string;
  ATransform: TGenderTransformFunc);
begin
  FGenderTransforms.AddOrSetValue(LowerCase(ALangCode), ATransform);
end;

class procedure TGenderVariant.RegisterCaseTransform(const ALangCode: string;
  ATransform: TCaseTransformFunc);
begin
  FCaseTransforms.AddOrSetValue(LowerCase(ALangCode), ATransform);
end;

class function TGenderVariant.GetLanguageInfo(const ALangCode: string): TLanguageGenderInfo;
var
  LangCode: string;
begin
  Initialize;
  LangCode := LowerCase(Copy(ALangCode, 1, 2));
  if not FLanguageInfo.TryGetValue(LangCode, Result) then
  begin
    // Return default info for unknown language
    Result.LanguageCode := LangCode;
    Result.Genders := [];
    Result.Cases := [];
    Result.Direction := tdLeftToRight;
    Result.HasGenderAgreement := False;
  end;
end;

class function TGenderVariant.HasGender(const ALangCode: string): Boolean;
begin
  Result := GetLanguageInfo(ALangCode).Genders <> [];
end;

class function TGenderVariant.HasCases(const ALangCode: string): Boolean;
begin
  Result := GetLanguageInfo(ALangCode).Cases <> [];
end;

class function TGenderVariant.GetDirection(const ALangCode: string): TTextDirection;
begin
  Result := GetLanguageInfo(ALangCode).Direction;
end;

class function TGenderVariant.IsRTL(const ALangCode: string): Boolean;
begin
  Result := GetDirection(ALangCode) = tdRightToLeft;
end;

class function TGenderVariant.Select(const ALangCode: string; 
  AGender: TGrammaticalGender; const AForms: array of string): string;
var
  Index: Integer;
begin
  Initialize;
  if Length(AForms) = 0 then
    Exit('');
    
  // Map gender to index
  Index := Ord(AGender);
  
  // Fallback if index out of range
  if Index >= Length(AForms) then
    Index := Length(AForms) - 1;
  if Index < 0 then
    Index := 0;
    
  Result := AForms[Index];
end;

class function TGenderVariant.Transform(const ALangCode: string; 
  const AText: string; AGender: TGrammaticalGender): string;
var
  TransformFunc: TGenderTransformFunc;
  LangCode: string;
begin
  Initialize;
  Result := AText;
  LangCode := LowerCase(Copy(ALangCode, 1, 2));
  
  if FGenderTransforms.TryGetValue(LangCode, TransformFunc) then
    Result := TransformFunc(AText, AGender);
end;

class function TGenderVariant.Format(const ALangCode: string; 
  const ATemplate: string; AGender: TGrammaticalGender;
  const AParams: array of TPair<string, string>): string;
var
  I: Integer;
  Key, Value: string;
begin
  Initialize;
  Result := ATemplate;
  
  for I := 0 to High(AParams) do
  begin
    Key := AParams[I].Key;
    Value := AParams[I].Value;
    
    // Apply gender transformation to value if language supports it
    if HasGender(ALangCode) then
      Value := Transform(ALangCode, Value, AGender);
    
    Result := StringReplace(Result, '{' + Key + '}', Value, [rfReplaceAll]);
  end;
end;

{ TCaseVariant }

class function TCaseVariant.Select(const ALangCode: string; 
  ACase: TGrammaticalCase; const AForms: array of string): string;
var
  Index: Integer;
begin
  if Length(AForms) = 0 then
    Exit('');
    
  Index := Ord(ACase);
  
  if Index >= Length(AForms) then
    Index := 0; // Fallback to nominative
  if Index < 0 then
    Index := 0;
    
  Result := AForms[Index];
end;

class function TCaseVariant.Transform(const ALangCode: string; 
  const AText: string; ACase: TGrammaticalCase): string;
var
  TransformFunc: TCaseTransformFunc;
  LangCode: string;
begin
  TGenderVariant.Initialize;
  Result := AText;
  LangCode := LowerCase(Copy(ALangCode, 1, 2));
  
  if TGenderVariant.FCaseTransforms.TryGetValue(LangCode, TransformFunc) then
    Result := TransformFunc(AText, ACase);
end;

class function TCaseVariant.GetCaseName(ACase: TGrammaticalCase): string;
const
  CaseNames: array[TGrammaticalCase] of string = (
    'Nominative', 'Genitive', 'Dative', 'Accusative', 
    'Instrumental', 'Locative', 'Vocative', 'Ablative', 'Prepositional'
  );
begin
  Result := CaseNames[ACase];
end;

{ TRTLUtils }

class function TRTLUtils.IsRTLChar(AChar: Char): Boolean;
var
  CharType: TUnicodeCategory;
begin
  // Check for RTL Unicode ranges
  // Arabic: U+0600-U+06FF, U+0750-U+077F, U+08A0-U+08FF
  // Hebrew: U+0590-U+05FF
  // Syriac: U+0700-U+074F
  // Thaana: U+0780-U+07BF
  // N'Ko: U+07C0-U+07FF
  Result := ((Ord(AChar) >= $0590) and (Ord(AChar) <= $05FF)) or  // Hebrew
            ((Ord(AChar) >= $0600) and (Ord(AChar) <= $06FF)) or  // Arabic
            ((Ord(AChar) >= $0700) and (Ord(AChar) <= $074F)) or  // Syriac
            ((Ord(AChar) >= $0750) and (Ord(AChar) <= $077F)) or  // Arabic Supplement
            ((Ord(AChar) >= $0780) and (Ord(AChar) <= $07BF)) or  // Thaana
            ((Ord(AChar) >= $07C0) and (Ord(AChar) <= $07FF)) or  // N'Ko
            ((Ord(AChar) >= $08A0) and (Ord(AChar) <= $08FF)) or  // Arabic Extended-A
            ((Ord(AChar) >= $FB50) and (Ord(AChar) <= $FDFF)) or  // Arabic Presentation Forms-A
            ((Ord(AChar) >= $FE70) and (Ord(AChar) <= $FEFF));    // Arabic Presentation Forms-B
end;

class function TRTLUtils.ContainsRTL(const AText: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to Length(AText) do
    if IsRTLChar(AText[I]) then
      Exit(True);
  Result := False;
end;

class function TRTLUtils.GetDominantDirection(const AText: string): TTextDirection;
var
  I, LTRCount, RTLCount: Integer;
begin
  LTRCount := 0;
  RTLCount := 0;
  
  for I := 1 to Length(AText) do
  begin
    if IsRTLChar(AText[I]) then
      Inc(RTLCount)
    else if AText[I].IsLetter then
      Inc(LTRCount);
  end;
  
  if RTLCount > LTRCount then
    Result := tdRightToLeft
  else
    Result := tdLeftToRight;
end;

class function TRTLUtils.EmbedRTL(const AText: string): string;
begin
  Result := RLI + AText + PDI;
end;

class function TRTLUtils.EmbedLTR(const AText: string): string;
begin
  Result := LRI + AText + PDI;
end;

class function TRTLUtils.NormalizeBidi(const AText: string; 
  ADirection: TTextDirection): string;
begin
  if ADirection = tdRightToLeft then
    Result := RLI + AText + PDI
  else
    Result := LRI + AText + PDI;
end;

class function TRTLUtils.ReverseString(const AText: string): string;
var
  I, Len: Integer;
begin
  Len := Length(AText);
  SetLength(Result, Len);
  for I := 1 to Len do
    Result[Len - I + 1] := AText[I];
end;

{ TCaseUtils }

class function TCaseUtils.Apply(const AText: string; ACap: TCapitalization): string;
begin
  case ACap of
    capLowercase: Result := ToLower(AText);
    capUppercase: Result := ToUpper(AText);
    capTitleCase: Result := ToTitleCase(AText);
    capSentenceCase: Result := ToSentenceCase(AText);
    capToggleCase:
    begin
      Result := '';
      for var C in AText do
      begin
        if C.IsUpper then
          Result := Result + C.ToLower
        else
          Result := Result + C.ToUpper;
      end;
    end;
  else
    Result := AText;
  end;
end;

class function TCaseUtils.ToLower(const AText: string): string;
begin
  Result := LowerCase(AText);
end;

class function TCaseUtils.ToUpper(const AText: string): string;
begin
  Result := UpperCase(AText);
end;

class function TCaseUtils.ToTitleCase(const AText: string): string;
var
  I: Integer;
  PrevSpace: Boolean;
begin
  Result := LowerCase(AText);
  PrevSpace := True;
  
  for I := 1 to Length(Result) do
  begin
    if PrevSpace and Result[I].IsLetter then
      Result[I] := Result[I].ToUpper;
    PrevSpace := Result[I].IsWhiteSpace or CharInSet(Result[I], ['-', '''']);
  end;
end;

class function TCaseUtils.ToSentenceCase(const AText: string): string;
var
  I: Integer;
  NewSentence: Boolean;
begin
  Result := LowerCase(AText);
  NewSentence := True;
  
  for I := 1 to Length(Result) do
  begin
    if NewSentence and Result[I].IsLetter then
    begin
      Result[I] := Result[I].ToUpper;
      NewSentence := False;
    end;
    if CharInSet(Result[I], ['.', '!', '?']) then
      NewSentence := True;
  end;
end;

class function TCaseUtils.Capitalize(const AText: string): string;
begin
  if Length(AText) = 0 then
    Exit('');
  Result := AText[1].ToUpper + Copy(AText, 2, MaxInt);
end;

class function TCaseUtils.Uncapitalize(const AText: string): string;
begin
  if Length(AText) = 0 then
    Exit('');
  Result := AText[1].ToLower + Copy(AText, 2, MaxInt);
end;

class function TCaseUtils.IsLower(const AText: string): Boolean;
begin
  Result := AText = LowerCase(AText);
end;

class function TCaseUtils.IsUpper(const AText: string): Boolean;
begin
  Result := AText = UpperCase(AText);
end;

class function TCaseUtils.IsTitleCase(const AText: string): Boolean;
begin
  Result := AText = ToTitleCase(AText);
end;

{ Global helper functions }

function GenderSelect(const ALangCode: string; AGender: TGrammaticalGender;
  const AForms: array of string): string;
begin
  Result := TGenderVariant.Select(ALangCode, AGender, AForms);
end;

function CaseSelect(const ALangCode: string; ACase: TGrammaticalCase;
  const AForms: array of string): string;
begin
  Result := TCaseVariant.Select(ALangCode, ACase, AForms);
end;

function IsRTLLanguage(const ALangCode: string): Boolean;
begin
  Result := TGenderVariant.IsRTL(ALangCode);
end;

function GetGenderName(AGender: TGrammaticalGender): string;
const
  GenderNames: array[TGrammaticalGender] of string = (
    'Masculine', 'Feminine', 'Neuter', 'Common', 
    'Animate', 'Inanimate', 'Unknown'
  );
begin
  Result := GenderNames[AGender];
end;

function GetCaseName(ACase: TGrammaticalCase): string;
begin
  Result := TCaseVariant.GetCaseName(ACase);
end;

end.
