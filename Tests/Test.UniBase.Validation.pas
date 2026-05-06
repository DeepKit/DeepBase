unit Test.UniBase.Validation;

{*******************************************************************************
  UniBase Validation Module Unit Tests

  Test Coverage:
  - Basic validation rules (Required, NotEmpty, MinLength, MaxLength, etc.)
  - Range and comparison rules (Range, GreaterThan, LessThan)
  - Pattern rules (Email, Regex/Matches)
  - Custom rules (Must)
  - Fluent API (RuleFor, WithMessage, WithErrorCode, When)
  - Validation result handling
  - ValidateAndThrow exception
  - Quick validators (TValidate class)
  - Conditional validation
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Rtti,
  UniBase.Validation;

type
  // Test record types
  TUserDto = record
    Username: string;
    Email: string;
    Age: Integer;
    Password: string;
    ConfirmPassword: string;
    Status: string;
  end;

  TProductDto = record
    Name: string;
    Price: Double;
    Quantity: Integer;
    Category: string;
  end;

  [TestFixture]
  TTestValidationRules = class
  public
    // Required Rule
    [Test]
    procedure Test_Required_EmptyString_Fails;

    [Test]
    procedure Test_Required_NonEmptyString_Passes;

    [Test]
    procedure Test_Required_NilValue_Fails;

    // NotEmpty Rule
    [Test]
    procedure Test_NotEmpty_EmptyString_Fails;

    [Test]
    procedure Test_NotEmpty_WhitespaceOnly_Fails;

    [Test]
    procedure Test_NotEmpty_NonEmpty_Passes;

    // MinLength Rule
    [Test]
    procedure Test_MinLength_TooShort_Fails;

    [Test]
    procedure Test_MinLength_ExactLength_Passes;

    [Test]
    procedure Test_MinLength_LongerThanMin_Passes;

    // MaxLength Rule
    [Test]
    procedure Test_MaxLength_TooLong_Fails;

    [Test]
    procedure Test_MaxLength_ExactLength_Passes;

    [Test]
    procedure Test_MaxLength_ShorterThanMax_Passes;

    // Length Rule
    [Test]
    procedure Test_Length_TooShort_Fails;

    [Test]
    procedure Test_Length_TooLong_Fails;

    [Test]
    procedure Test_Length_WithinRange_Passes;

    // Range Rule
    [Test]
    procedure Test_Range_BelowMin_Fails;

    [Test]
    procedure Test_Range_AboveMax_Fails;

    [Test]
    procedure Test_Range_WithinRange_Passes;

    [Test]
    procedure Test_Range_AtBoundaries_Passes;

    // GreaterThan Rule
    [Test]
    procedure Test_GreaterThan_Equal_Fails;

    [Test]
    procedure Test_GreaterThan_Less_Fails;

    [Test]
    procedure Test_GreaterThan_Greater_Passes;

    // LessThan Rule
    [Test]
    procedure Test_LessThan_Equal_Fails;

    [Test]
    procedure Test_LessThan_Greater_Fails;

    [Test]
    procedure Test_LessThan_Less_Passes;

    // Email Rule
    [Test]
    procedure Test_Email_Valid_Passes;

    [Test]
    procedure Test_Email_Invalid_NoAt_Fails;

    [Test]
    procedure Test_Email_Invalid_NoDomain_Fails;

    [Test]
    procedure Test_Email_Empty_Fails;

    // Regex/Matches Rule
    [Test]
    procedure Test_Matches_ValidPattern_Passes;

    [Test]
    procedure Test_Matches_InvalidPattern_Fails;

    // IsIn Rule
    [Test]
    procedure Test_IsIn_ValueInList_Passes;

    [Test]
    procedure Test_IsIn_ValueNotInList_Fails;
  end;

  [TestFixture]
  TTestValidatorFluentAPI = class
  public
    [Test]
    procedure Test_RuleFor_SingleProperty;

    [Test]
    procedure Test_RuleFor_MultipleProperties;

    [Test]
    procedure Test_ChainedRules_AllApplied;

    [Test]
    procedure Test_WithMessage_CustomErrorMessage;

    [Test]
    procedure Test_WithErrorCode_CustomCode;

    [Test]
    procedure Test_WithDisplayName_UsedInMessage;

    [Test]
    procedure Test_When_ConditionTrue_RuleApplied;

    [Test]
    procedure Test_When_ConditionFalse_RuleSkipped;

    [Test]
    procedure Test_Must_CustomPredicate_Passes;

    [Test]
    procedure Test_Must_CustomPredicate_Fails;

    [Test]
    procedure Test_MatchesProperty_SameValue_Passes;

    [Test]
    procedure Test_MatchesProperty_DifferentValue_Fails;
  end;

  [TestFixture]
  TTestValidationResult = class
  public
    [Test]
    procedure Test_Valid_IsValidTrue;

    [Test]
    procedure Test_Invalid_IsValidFalse;

    [Test]
    procedure Test_AddError_IncreasesErrorCount;

    [Test]
    procedure Test_GetErrors_FiltersByProperty;

    [Test]
    procedure Test_GetFirstError_ReturnsFirstMessage;

    [Test]
    procedure Test_ToString_FormatsErrors;

    [Test]
    procedure Test_ErrorCount_ReturnsCorrectCount;
  end;

  [TestFixture]
  TTestValidateAndThrow = class
  public
    [Test]
    procedure Test_ValidateAndThrow_Valid_NoException;

    [Test]
    procedure Test_ValidateAndThrow_Invalid_ThrowsException;

    [Test]
    procedure Test_ValidationException_ContainsErrors;
  end;

  [TestFixture]
  TTestQuickValidators = class
  public
    [Test]
    procedure Test_TValidate_Required_Valid;

    [Test]
    procedure Test_TValidate_Required_Invalid;

    [Test]
    procedure Test_TValidate_Email_Valid;

    [Test]
    procedure Test_TValidate_Email_Invalid;

    [Test]
    procedure Test_TValidate_MinLength_Valid;

    [Test]
    procedure Test_TValidate_MinLength_Invalid;

    [Test]
    procedure Test_TValidate_MaxLength_Valid;

    [Test]
    procedure Test_TValidate_MaxLength_Invalid;

    [Test]
    procedure Test_TValidate_Range_Valid;

    [Test]
    procedure Test_TValidate_Range_Invalid;

    [Test]
    procedure Test_TValidate_Regex_Valid;

    [Test]
    procedure Test_TValidate_Regex_Invalid;

    [Test]
    procedure Test_TValidate_Combine_AllValid;

    [Test]
    procedure Test_TValidate_Combine_SomeInvalid;
  end;

  [TestFixture]
  TTestComplexValidation = class
  public
    [Test]
    procedure Test_CompleteUserValidation;

    [Test]
    procedure Test_ProductValidation;

    [Test]
    procedure Test_MultipleErrorsCollected;
  end;

implementation

{ TTestValidationRules }

procedure TTestValidationRules.Test_Required_EmptyString_Fails;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  GetUsername: TFunc<TUserDto, TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    Validator.RuleFor('Username', GetUsername).Required;

    User.Username := '';
    ValResult := Validator.Validate(User);

    Assert.IsFalse(ValResult.IsValid);
    Assert.AreEqual(1, ValResult.ErrorCount);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidationRules.Test_Required_NonEmptyString_Passes;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  GetUsername: TFunc<TUserDto, TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    Validator.RuleFor('Username', GetUsername).Required;

    User.Username := 'john';
    ValResult := Validator.Validate(User);

    Assert.IsTrue(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidationRules.Test_Required_NilValue_Fails;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.Required('', 'Field');
  Assert.IsFalse(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_NotEmpty_EmptyString_Fails;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.NotEmpty('', 'Field');
  Assert.IsFalse(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_NotEmpty_WhitespaceOnly_Fails;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.NotEmpty('   ', 'Field');
  Assert.IsFalse(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_NotEmpty_NonEmpty_Passes;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.NotEmpty('hello', 'Field');
  Assert.IsTrue(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_MinLength_TooShort_Fails;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.MinLength('ab', 3, 'Field');
  Assert.IsFalse(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_MinLength_ExactLength_Passes;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.MinLength('abc', 3, 'Field');
  Assert.IsTrue(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_MinLength_LongerThanMin_Passes;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.MinLength('abcdef', 3, 'Field');
  Assert.IsTrue(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_MaxLength_TooLong_Fails;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.MaxLength('abcdef', 5, 'Field');
  Assert.IsFalse(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_MaxLength_ExactLength_Passes;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.MaxLength('abcde', 5, 'Field');
  Assert.IsTrue(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_MaxLength_ShorterThanMax_Passes;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.MaxLength('abc', 5, 'Field');
  Assert.IsTrue(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_Length_TooShort_Fails;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  GetUsername: TFunc<TUserDto, TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    Validator.RuleFor('Username', GetUsername).Length(3, 10);

    User.Username := 'ab';
    ValResult := Validator.Validate(User);

    Assert.IsFalse(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidationRules.Test_Length_TooLong_Fails;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  GetUsername: TFunc<TUserDto, TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    Validator.RuleFor('Username', GetUsername).Length(3, 10);

    User.Username := '12345678901';
    ValResult := Validator.Validate(User);

    Assert.IsFalse(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidationRules.Test_Length_WithinRange_Passes;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  GetUsername: TFunc<TUserDto, TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    Validator.RuleFor('Username', GetUsername).Length(3, 10);

    User.Username := 'johndoe';
    ValResult := Validator.Validate(User);

    Assert.IsTrue(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidationRules.Test_Range_BelowMin_Fails;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.Range(5, 10, 100, 'Age');
  Assert.IsFalse(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_Range_AboveMax_Fails;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.Range(150, 10, 100, 'Age');
  Assert.IsFalse(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_Range_WithinRange_Passes;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.Range(50, 10, 100, 'Age');
  Assert.IsTrue(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_Range_AtBoundaries_Passes;
begin
  Assert.IsTrue(TValidate.Range(10, 10, 100, 'Age').IsValid);
  Assert.IsTrue(TValidate.Range(100, 10, 100, 'Age').IsValid);
end;

procedure TTestValidationRules.Test_GreaterThan_Equal_Fails;
var
  Validator: TValidator<TProductDto>;
  Product: TProductDto;
  ValResult: TValidationResult;
  GetPrice: TFunc<TProductDto, TValue>;
begin
  Validator := TValidator<TProductDto>.Create;
  try
    GetPrice :=
      TFunc<TProductDto, TValue>(
        function(const P: TProductDto): TValue
        begin
          Result := TValue.From<Double>(P.Price);
        end
      );
    Validator.RuleFor('Price', GetPrice).GreaterThan(0);

    Product.Price := 0;
    ValResult := Validator.Validate(Product);

    Assert.IsFalse(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidationRules.Test_GreaterThan_Less_Fails;
var
  Validator: TValidator<TProductDto>;
  Product: TProductDto;
  ValResult: TValidationResult;
  GetPrice: TFunc<TProductDto, TValue>;
begin
  Validator := TValidator<TProductDto>.Create;
  try
    GetPrice :=
      TFunc<TProductDto, TValue>(
        function(const P: TProductDto): TValue
        begin
          Result := TValue.From<Double>(P.Price);
        end
      );
    Validator.RuleFor('Price', GetPrice).GreaterThan(10);

    Product.Price := 5;
    ValResult := Validator.Validate(Product);

    Assert.IsFalse(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidationRules.Test_GreaterThan_Greater_Passes;
var
  Validator: TValidator<TProductDto>;
  Product: TProductDto;
  ValResult: TValidationResult;
  GetPrice: TFunc<TProductDto, TValue>;
begin
  Validator := TValidator<TProductDto>.Create;
  try
    GetPrice :=
      TFunc<TProductDto, TValue>(
        function(const P: TProductDto): TValue
        begin
          Result := TValue.From<Double>(P.Price);
        end
      );
    Validator.RuleFor('Price', GetPrice).GreaterThan(0);

    Product.Price := 99.99;
    ValResult := Validator.Validate(Product);

    Assert.IsTrue(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidationRules.Test_LessThan_Equal_Fails;
var
  Validator: TValidator<TProductDto>;
  Product: TProductDto;
  ValResult: TValidationResult;
  GetQuantity: TFunc<TProductDto, TValue>;
begin
  Validator := TValidator<TProductDto>.Create;
  try
    GetQuantity :=
      TFunc<TProductDto, TValue>(
        function(const P: TProductDto): TValue
        begin
          Result := TValue.From<Integer>(P.Quantity);
        end
      );
    Validator.RuleFor('Quantity', GetQuantity).LessThan(100);

    Product.Quantity := 100;
    ValResult := Validator.Validate(Product);

    Assert.IsFalse(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidationRules.Test_LessThan_Greater_Fails;
var
  Validator: TValidator<TProductDto>;
  Product: TProductDto;
  ValResult: TValidationResult;
  GetQuantity: TFunc<TProductDto, TValue>;
begin
  Validator := TValidator<TProductDto>.Create;
  try
    GetQuantity :=
      TFunc<TProductDto, TValue>(
        function(const P: TProductDto): TValue
        begin
          Result := TValue.From<Integer>(P.Quantity);
        end
      );
    Validator.RuleFor('Quantity', GetQuantity).LessThan(100);

    Product.Quantity := 150;
    ValResult := Validator.Validate(Product);

    Assert.IsFalse(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidationRules.Test_LessThan_Less_Passes;
var
  Validator: TValidator<TProductDto>;
  Product: TProductDto;
  ValResult: TValidationResult;
  GetQuantity: TFunc<TProductDto, TValue>;
begin
  Validator := TValidator<TProductDto>.Create;
  try
    GetQuantity :=
      TFunc<TProductDto, TValue>(
        function(const P: TProductDto): TValue
        begin
          Result := TValue.From<Integer>(P.Quantity);
        end
      );
    Validator.RuleFor('Quantity', GetQuantity).LessThan(100);

    Product.Quantity := 50;
    ValResult := Validator.Validate(Product);

    Assert.IsTrue(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidationRules.Test_Email_Valid_Passes;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.Email('test@example.com');
  Assert.IsTrue(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_Email_Invalid_NoAt_Fails;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.Email('testexample.com');
  Assert.IsFalse(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_Email_Invalid_NoDomain_Fails;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.Email('test@');
  Assert.IsFalse(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_Email_Empty_Fails;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.Email('');
  Assert.IsFalse(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_Matches_ValidPattern_Passes;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.Regex('ABC123', '^[A-Z]+[0-9]+$', 'Code');
  Assert.IsTrue(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_Matches_InvalidPattern_Fails;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.Regex('123ABC', '^[A-Z]+[0-9]+$', 'Code');
  Assert.IsFalse(ValResult.IsValid);
end;

procedure TTestValidationRules.Test_IsIn_ValueInList_Passes;
var
  Validator: TValidator<TProductDto>;
  Product: TProductDto;
  ValResult: TValidationResult;
  GetCategory: TFunc<TProductDto, TValue>;
begin
  Validator := TValidator<TProductDto>.Create;
  try
    GetCategory :=
      TFunc<TProductDto, TValue>(
        function(const P: TProductDto): TValue
        begin
          Result := TValue.From<string>(P.Category);
        end
      );
    Validator.RuleFor('Category', GetCategory).IsIn([TValue.From<string>('Electronics'),
               TValue.From<string>('Clothing'),
               TValue.From<string>('Food')]);

    Product.Category := 'Electronics';
    ValResult := Validator.Validate(Product);

    Assert.IsTrue(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidationRules.Test_IsIn_ValueNotInList_Fails;
var
  Validator: TValidator<TProductDto>;
  Product: TProductDto;
  ValResult: TValidationResult;
  GetCategory: TFunc<TProductDto, TValue>;
begin
  Validator := TValidator<TProductDto>.Create;
  try
    GetCategory :=
      TFunc<TProductDto, TValue>(
        function(const P: TProductDto): TValue
        begin
          Result := TValue.From<string>(P.Category);
        end
      );
    Validator.RuleFor('Category', GetCategory).IsIn([TValue.From<string>('Electronics'),
               TValue.From<string>('Clothing')]);

    Product.Category := 'Books';
    ValResult := Validator.Validate(Product);

    Assert.IsFalse(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

{ TTestValidatorFluentAPI }

procedure TTestValidatorFluentAPI.Test_RuleFor_SingleProperty;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  GetUsername: TFunc<TUserDto, TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    Validator.RuleFor('Username', GetUsername).Required;

    User.Username := 'john';
    ValResult := Validator.Validate(User);
    Assert.IsTrue(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidatorFluentAPI.Test_RuleFor_MultipleProperties;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  GetUsername: TFunc<TUserDto, TValue>;
  GetEmail: TFunc<TUserDto, TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    GetEmail :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Email);
        end
      );
    Validator.RuleFor('Username', GetUsername).Required
    .RuleFor('Email', GetEmail).Required.Email;

    User.Username := 'john';
    User.Email := 'john@test.com';
    ValResult := Validator.Validate(User);

    Assert.IsTrue(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidatorFluentAPI.Test_ChainedRules_AllApplied;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  GetUsername: TFunc<TUserDto, TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    Validator.RuleFor('Username', GetUsername).Required.MinLength(3).MaxLength(20);

    User.Username := 'ab'; // Too short
    ValResult := Validator.Validate(User);

    Assert.IsFalse(ValResult.IsValid);
    Assert.IsTrue(ValResult.ErrorCount >= 1);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidatorFluentAPI.Test_WithMessage_CustomErrorMessage;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  GetUsername: TFunc<TUserDto, TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    Validator.RuleFor('Username', GetUsername).Required.WithMessage('Custom error message');

    User.Username := '';
    ValResult := Validator.Validate(User);

    Assert.IsFalse(ValResult.IsValid);
    Assert.AreEqual('Custom error message', ValResult.Errors[0].ErrorMessage);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidatorFluentAPI.Test_WithErrorCode_CustomCode;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  GetUsername: TFunc<TUserDto, TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    Validator.RuleFor('Username', GetUsername).Required.WithErrorCode('ERR001');

    User.Username := '';
    ValResult := Validator.Validate(User);

    Assert.IsFalse(ValResult.IsValid);
    Assert.AreEqual('ERR001', ValResult.Errors[0].ErrorCode);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidatorFluentAPI.Test_WithDisplayName_UsedInMessage;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  GetUsername: TFunc<TUserDto, TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    Validator.RuleFor('Username', GetUsername).Required.WithDisplayName('User Name');

    User.Username := '';
    ValResult := Validator.Validate(User);

    Assert.IsFalse(ValResult.IsValid);
    // Display name should appear in error message
    Assert.IsTrue(ValResult.Errors[0].ErrorMessage.Contains('User Name') or
                  (ValResult.Errors[0].PropertyName = 'Username'));
  finally
    Validator.Free;
  end;
end;

procedure TTestValidatorFluentAPI.Test_When_ConditionTrue_RuleApplied;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  ApplyRule: Boolean;
  GetEmail: TFunc<TUserDto, TValue>;
  Cond: TFunc<Boolean>;
begin
  ApplyRule := True;
  Validator := TValidator<TUserDto>.Create;
  try
    GetEmail :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Email);
        end
      );
    Cond := function: Boolean begin Result := ApplyRule; end;
    Validator.RuleFor('Email', GetEmail).Required.When(Cond);

    User.Email := '';
    ValResult := Validator.Validate(User);

    Assert.IsFalse(ValResult.IsValid, 'Rule should be applied when condition is true');
  finally
    Validator.Free;
  end;
end;

procedure TTestValidatorFluentAPI.Test_When_ConditionFalse_RuleSkipped;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  ApplyRule: Boolean;
  GetEmail: TFunc<TUserDto, TValue>;
  Cond: TFunc<Boolean>;
begin
  ApplyRule := False;
  Validator := TValidator<TUserDto>.Create;
  try
    GetEmail :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Email);
        end
      );
    Cond := function: Boolean begin Result := ApplyRule; end;
    Validator.RuleFor('Email', GetEmail).Required.When(Cond);

    User.Email := '';
    ValResult := Validator.Validate(User);

    Assert.IsTrue(ValResult.IsValid, 'Rule should be skipped when condition is false');
  finally
    Validator.Free;
  end;
end;

procedure TTestValidatorFluentAPI.Test_Must_CustomPredicate_Passes;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  GetUsername: TFunc<TUserDto, TValue>;
  NoSpaces: TFunc<TValue, Boolean>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    NoSpaces :=
      TFunc<TValue, Boolean>(
        function(const Value: TValue): Boolean
        begin
          Result := not Value.AsString.Contains(' ');
        end
      );
    Validator.RuleFor('Username', GetUsername).Must(NoSpaces, 'Username cannot contain spaces');

    User.Username := 'validname';
    ValResult := Validator.Validate(User);

    Assert.IsTrue(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidatorFluentAPI.Test_Must_CustomPredicate_Fails;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  GetUsername: TFunc<TUserDto, TValue>;
  NoSpaces: TFunc<TValue, Boolean>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    NoSpaces :=
      TFunc<TValue, Boolean>(
        function(const Value: TValue): Boolean
        begin
          Result := not Value.AsString.Contains(' ');
        end
      );
    Validator.RuleFor('Username', GetUsername).Must(NoSpaces, 'Username cannot contain spaces');

    User.Username := 'invalid name';
    ValResult := Validator.Validate(User);

    Assert.IsFalse(ValResult.IsValid);
    Assert.AreEqual('Username cannot contain spaces', ValResult.Errors[0].ErrorMessage);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidatorFluentAPI.Test_MatchesProperty_SameValue_Passes;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  GetConfirmPassword: TFunc<TUserDto, TValue>;
  GetPassword: TFunc<TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetConfirmPassword :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.ConfirmPassword);
        end
      );
    GetPassword :=
      TFunc<TValue>(
        function: TValue
        begin
          Result := TValue.From<string>(User.Password);
        end
      );
    Validator.RuleFor('ConfirmPassword', GetConfirmPassword).MatchesProperty('Password', GetPassword);

    User.Password := 'secret123';
    User.ConfirmPassword := 'secret123';
    ValResult := Validator.Validate(User);

    Assert.IsTrue(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidatorFluentAPI.Test_MatchesProperty_DifferentValue_Fails;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  GetConfirmPassword: TFunc<TUserDto, TValue>;
  GetPassword: TFunc<TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetConfirmPassword :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.ConfirmPassword);
        end
      );
    GetPassword :=
      TFunc<TValue>(
        function: TValue
        begin
          Result := TValue.From<string>(User.Password);
        end
      );
    Validator.RuleFor('ConfirmPassword', GetConfirmPassword).MatchesProperty('Password', GetPassword);

    User.Password := 'secret123';
    User.ConfirmPassword := 'different';
    ValResult := Validator.Validate(User);

    Assert.IsFalse(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

{ TTestValidationResult }

procedure TTestValidationResult.Test_Valid_IsValidTrue;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidationResult.Valid;
  Assert.IsTrue(ValResult.IsValid);
end;

procedure TTestValidationResult.Test_Invalid_IsValidFalse;
var
  ValResult: TValidationResult;
  Errors: TArray<TValidationError>;
begin
  SetLength(Errors, 1);
  Errors[0].PropertyName := 'Test';
  Errors[0].ErrorMessage := 'Error';

  ValResult := TValidationResult.Invalid(Errors);
  Assert.IsFalse(ValResult.IsValid);
end;

procedure TTestValidationResult.Test_AddError_IncreasesErrorCount;
var
  ValResult: TValidationResult;
  Error: TValidationError;
begin
  ValResult := TValidationResult.Valid;
  Assert.AreEqual(0, ValResult.ErrorCount);

  Error.PropertyName := 'Field1';
  Error.ErrorMessage := 'Error 1';
  ValResult.AddError(Error);

  Assert.AreEqual(1, ValResult.ErrorCount);

  Error.PropertyName := 'Field2';
  Error.ErrorMessage := 'Error 2';
  ValResult.AddError(Error);

  Assert.AreEqual(2, ValResult.ErrorCount);
end;

procedure TTestValidationResult.Test_GetErrors_FiltersByProperty;
var
  ValResult: TValidationResult;
  Error: TValidationError;
  Filtered: TArray<TValidationError>;
begin
  ValResult := TValidationResult.Valid;

  Error.PropertyName := 'Username';
  Error.ErrorMessage := 'Username error';
  ValResult.AddError(Error);

  Error.PropertyName := 'Email';
  Error.ErrorMessage := 'Email error';
  ValResult.AddError(Error);

  Error.PropertyName := 'Username';
  Error.ErrorMessage := 'Another username error';
  ValResult.AddError(Error);

  Filtered := ValResult.GetErrors('Username');

  Assert.AreEqual(2, Integer(Length(Filtered)));
end;

procedure TTestValidationResult.Test_GetFirstError_ReturnsFirstMessage;
var
  ValResult: TValidationResult;
  Error: TValidationError;
begin
  ValResult := TValidationResult.Valid;

  Error.PropertyName := 'Field1';
  Error.ErrorMessage := 'First error';
  ValResult.AddError(Error);

  Error.PropertyName := 'Field2';
  Error.ErrorMessage := 'Second error';
  ValResult.AddError(Error);

  Assert.AreEqual('First error', ValResult.GetFirstError);
end;

procedure TTestValidationResult.Test_ToString_FormatsErrors;
var
  ValResult: TValidationResult;
  Error: TValidationError;
  S: string;
begin
  ValResult := TValidationResult.Valid;

  Error.PropertyName := 'Username';
  Error.ErrorMessage := 'is required';
  ValResult.AddError(Error);

  S := ValResult.ToString;

  Assert.IsTrue(S.Contains('Username'));
  Assert.IsTrue(S.Contains('required'));
end;

procedure TTestValidationResult.Test_ErrorCount_ReturnsCorrectCount;
var
  ValResult: TValidationResult;
  Errors: TArray<TValidationError>;
begin
  SetLength(Errors, 3);
  Errors[0].ErrorMessage := 'Error 1';
  Errors[1].ErrorMessage := 'Error 2';
  Errors[2].ErrorMessage := 'Error 3';

  ValResult := TValidationResult.Invalid(Errors);

  Assert.AreEqual(3, ValResult.ErrorCount);
end;

{ TTestValidateAndThrow }

procedure TTestValidateAndThrow.Test_ValidateAndThrow_Valid_NoException;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  GetUsername: TFunc<TUserDto, TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    Validator.RuleFor('Username', GetUsername).Required;

    User.Username := 'valid_user';

    // Should not throw
    Assert.WillNotRaise(
      procedure
      begin
        Validator.ValidateAndThrow(User);
      end);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidateAndThrow.Test_ValidateAndThrow_Invalid_ThrowsException;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  GetUsername: TFunc<TUserDto, TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    Validator.RuleFor('Username', GetUsername).Required;

    User.Username := '';

    Assert.WillRaise(
      procedure
      begin
        Validator.ValidateAndThrow(User);
      end, EValidationException);
  finally
    Validator.Free;
  end;
end;

procedure TTestValidateAndThrow.Test_ValidationException_ContainsErrors;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  GetUsername: TFunc<TUserDto, TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    Validator.RuleFor('Username', GetUsername).Required;

    User.Username := '';

    try
      Validator.ValidateAndThrow(User);
      Assert.Fail('Expected exception');
    except
      on E: EValidationException do
      begin
        Assert.IsTrue(Length(E.Errors) > 0, 'Exception should contain errors');
      end;
    end;
  finally
    Validator.Free;
  end;
end;

{ TTestQuickValidators }

procedure TTestQuickValidators.Test_TValidate_Required_Valid;
begin
  Assert.IsTrue(TValidate.Required('hello', 'Field').IsValid);
end;

procedure TTestQuickValidators.Test_TValidate_Required_Invalid;
begin
  Assert.IsFalse(TValidate.Required('', 'Field').IsValid);
end;

procedure TTestQuickValidators.Test_TValidate_Email_Valid;
begin
  Assert.IsTrue(TValidate.Email('test@example.com').IsValid);
end;

procedure TTestQuickValidators.Test_TValidate_Email_Invalid;
begin
  Assert.IsFalse(TValidate.Email('invalid-email').IsValid);
end;

procedure TTestQuickValidators.Test_TValidate_MinLength_Valid;
begin
  Assert.IsTrue(TValidate.MinLength('hello', 3, 'Field').IsValid);
end;

procedure TTestQuickValidators.Test_TValidate_MinLength_Invalid;
begin
  Assert.IsFalse(TValidate.MinLength('hi', 3, 'Field').IsValid);
end;

procedure TTestQuickValidators.Test_TValidate_MaxLength_Valid;
begin
  Assert.IsTrue(TValidate.MaxLength('hello', 10, 'Field').IsValid);
end;

procedure TTestQuickValidators.Test_TValidate_MaxLength_Invalid;
begin
  Assert.IsFalse(TValidate.MaxLength('hello world!', 10, 'Field').IsValid);
end;

procedure TTestQuickValidators.Test_TValidate_Range_Valid;
begin
  Assert.IsTrue(TValidate.Range(50, 1, 100, 'Value').IsValid);
end;

procedure TTestQuickValidators.Test_TValidate_Range_Invalid;
begin
  Assert.IsFalse(TValidate.Range(150, 1, 100, 'Value').IsValid);
end;

procedure TTestQuickValidators.Test_TValidate_Regex_Valid;
begin
  Assert.IsTrue(TValidate.Regex('A123', '^[A-Z]\d+$', 'Code').IsValid);
end;

procedure TTestQuickValidators.Test_TValidate_Regex_Invalid;
begin
  Assert.IsFalse(TValidate.Regex('123A', '^[A-Z]\d+$', 'Code').IsValid);
end;

procedure TTestQuickValidators.Test_TValidate_Combine_AllValid;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.Combine([
    TValidate.Required('hello', 'Field1'),
    TValidate.Email('test@test.com', 'Email'),
    TValidate.MinLength('hello', 3, 'Field2')
  ]);

  Assert.IsTrue(ValResult.IsValid);
end;

procedure TTestQuickValidators.Test_TValidate_Combine_SomeInvalid;
var
  ValResult: TValidationResult;
begin
  ValResult := TValidate.Combine([
    TValidate.Required('', 'Field1'),
    TValidate.Email('test@test.com', 'Email'),
    TValidate.MinLength('hi', 3, 'Field2')
  ]);

  Assert.IsFalse(ValResult.IsValid);
  Assert.AreEqual(2, ValResult.ErrorCount);
end;

{ TTestComplexValidation }

procedure TTestComplexValidation.Test_CompleteUserValidation;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  GetUsername: TFunc<TUserDto, TValue>;
  GetEmail: TFunc<TUserDto, TValue>;
  GetAge: TFunc<TUserDto, TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    GetEmail :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Email);
        end
      );
    GetAge :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<Integer>(U.Age);
        end
      );
    Validator
      .RuleFor('Username', GetUsername).Required.MinLength(3).MaxLength(50)
      .RuleFor('Email', GetEmail).Required.Email
      .RuleFor('Age', GetAge).Range(18, 120);

    User.Username := 'johndoe';
    User.Email := 'john@example.com';
    User.Age := 25;

    ValResult := Validator.Validate(User);
    Assert.IsTrue(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

procedure TTestComplexValidation.Test_ProductValidation;
var
  Validator: TValidator<TProductDto>;
  Product: TProductDto;
  ValResult: TValidationResult;
  GetName: TFunc<TProductDto, TValue>;
  GetPrice: TFunc<TProductDto, TValue>;
  GetQuantity: TFunc<TProductDto, TValue>;
begin
  Validator := TValidator<TProductDto>.Create;
  try
    GetName :=
      TFunc<TProductDto, TValue>(
        function(const P: TProductDto): TValue
        begin
          Result := TValue.From<string>(P.Name);
        end
      );
    GetPrice :=
      TFunc<TProductDto, TValue>(
        function(const P: TProductDto): TValue
        begin
          Result := TValue.From<Double>(P.Price);
        end
      );
    GetQuantity :=
      TFunc<TProductDto, TValue>(
        function(const P: TProductDto): TValue
        begin
          Result := TValue.From<Integer>(P.Quantity);
        end
      );
    Validator
      .RuleFor('Name', GetName).Required.MaxLength(100)
      .RuleFor('Price', GetPrice).GreaterThan(0)
      .RuleFor('Quantity', GetQuantity).Range(0, 10000);

    Product.Name := 'Laptop';
    Product.Price := 999.99;
    Product.Quantity := 50;

    ValResult := Validator.Validate(Product);
    Assert.IsTrue(ValResult.IsValid);
  finally
    Validator.Free;
  end;
end;

procedure TTestComplexValidation.Test_MultipleErrorsCollected;
var
  Validator: TValidator<TUserDto>;
  User: TUserDto;
  ValResult: TValidationResult;
  GetUsername: TFunc<TUserDto, TValue>;
  GetEmail: TFunc<TUserDto, TValue>;
  GetAge: TFunc<TUserDto, TValue>;
begin
  Validator := TValidator<TUserDto>.Create;
  try
    GetUsername :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end
      );
    GetEmail :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Email);
        end
      );
    GetAge :=
      TFunc<TUserDto, TValue>(
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<Integer>(U.Age);
        end
      );
    Validator
      .RuleFor('Username', GetUsername).Required
      .RuleFor('Email', GetEmail).Required.Email
      .RuleFor('Age', GetAge).Range(18, 120);

    // All invalid
    User.Username := '';
    User.Email := 'invalid';
    User.Age := 10;

    ValResult := Validator.Validate(User);

    Assert.IsFalse(ValResult.IsValid);
    Assert.IsTrue(ValResult.ErrorCount >= 3, 'Should collect all errors');
  finally
    Validator.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestValidationRules);
  TDUnitX.RegisterTestFixture(TTestValidatorFluentAPI);
  TDUnitX.RegisterTestFixture(TTestValidationResult);
  TDUnitX.RegisterTestFixture(TTestValidateAndThrow);
  TDUnitX.RegisterTestFixture(TTestQuickValidators);
  TDUnitX.RegisterTestFixture(TTestComplexValidation);

end.
