unit UniBase.FMX.FormControls;

{*******************************************************************************
  UniBase FMX Form Controls - Enhanced Cross-Platform Input Controls

  Provides enhanced form input components with:
  - Material Design style inputs
  - Floating labels
  - Validation support
  - Error states
  - Helper text
  - Character counters
  - Cross-platform keyboard handling
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.Types,
  System.Generics.Collections, System.RegularExpressions,
  FMX.Types, FMX.Controls, FMX.StdCtrls, FMX.Edit, FMX.Memo, FMX.ComboEdit,
  FMX.ListBox, FMX.Objects, FMX.Layouts, FMX.Effects, FMX.Ani, FMX.Graphics,
  FMX.Controls.Presentation;

type
  /// <summary>Validation result</summary>
  TValidationResult = record
    IsValid: Boolean;
    ErrorMessage: string;
    class function Valid: TValidationResult; static;
    class function Invalid(const Msg: string): TValidationResult; static;
  end;

  /// <summary>Validation function type</summary>
  TValidationFunc = reference to function(const Value: string): TValidationResult;

  /// <summary>Input state</summary>
  TInputState = (uisNormal, uisFocused, uisError, uisDisabled);

  /// <summary>
  /// Material Design style text input with floating label
  /// </summary>
  TUniMaterialEdit = class(TLayout)
  private
    FEdit: TEdit;
    FFloatingLabel: TLabel;
    FHelperLabel: TLabel;
    FUnderline: TRectangle;
    FUnderlineFocused: TRectangle;
    FCharCounter: TLabel;

    FLabelText: string;
    FHelperText: string;
    FErrorText: string;
    FMaxLength: Integer;
    FShowCharCounter: Boolean;
    FRequired: Boolean;
    FState: TInputState;

    FValidators: TList<TValidationFunc>;
    FOnValidate: TNotifyEvent;

    // Colors
    FPrimaryColor: TAlphaColor;
    FErrorColor: TAlphaColor;
    FHelperColor: TAlphaColor;

    procedure SetLabelText(const Value: string);
    procedure SetHelperText(const Value: string);
    procedure SetErrorText(const Value: string);
    procedure SetMaxLength(const Value: Integer);
    procedure SetShowCharCounter(const Value: Boolean);
    procedure SetRequired(const Value: Boolean);
    procedure SetText(const Value: string);
    function GetText: string;
    procedure SetState(const Value: TInputState);

    procedure EditEnter(Sender: TObject);
    procedure EditExit(Sender: TObject);
    procedure EditChange(Sender: TObject);
    procedure UpdateFloatingLabel(Animated: Boolean);
    procedure UpdateCharCounter;
    procedure UpdateUnderline;
    procedure UpdateState;
  protected
    procedure DoValidate;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Validation
    procedure AddValidator(Validator: TValidationFunc);
    procedure ClearValidators;
    function Validate: Boolean;

    // Built-in validators
    class function RequiredValidator: TValidationFunc;
    class function EmailValidator: TValidationFunc;
    class function MinLengthValidator(MinLen: Integer): TValidationFunc;
    class function MaxLengthValidator(MaxLen: Integer): TValidationFunc;
    class function PatternValidator(const Pattern, ErrorMsg: string): TValidationFunc;

    // Properties
    property Edit: TEdit read FEdit;
    property Text: string read GetText write SetText;
    property LabelText: string read FLabelText write SetLabelText;
    property HelperText: string read FHelperText write SetHelperText;
    property ErrorText: string read FErrorText write SetErrorText;
    property MaxLength: Integer read FMaxLength write SetMaxLength;
    property ShowCharCounter: Boolean read FShowCharCounter write SetShowCharCounter;
    property Required: Boolean read FRequired write SetRequired;
    property State: TInputState read FState write SetState;

    // Colors
    property PrimaryColor: TAlphaColor read FPrimaryColor write FPrimaryColor;
    property ErrorColor: TAlphaColor read FErrorColor write FErrorColor;

    // Events
    property OnValidate: TNotifyEvent read FOnValidate write FOnValidate;
  end;

  /// <summary>
  /// Enhanced ComboBox with search/filter support
  /// </summary>
  TUniSearchComboBox = class(TLayout)
  private
    FComboEdit: TComboEdit;
    FLabel: TLabel;
    FItems: TStrings;
    FFilteredItems: TStringList;
    FAllowCustom: Boolean;
    FMinSearchLength: Integer;
    FOnItemSelected: TNotifyEvent;

    procedure SetLabelText(const Value: string);
    function GetLabelText: string;
    procedure SetItems(const Value: TStrings);
    function GetText: string;
    procedure SetText(const Value: string);
    function GetItemIndex: Integer;
    procedure SetItemIndex(const Value: Integer);

    procedure ComboEditChange(Sender: TObject);
    procedure FilterItems(const SearchText: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    property Text: string read GetText write SetText;
    property LabelText: string read GetLabelText write SetLabelText;
    property Items: TStrings read FItems write SetItems;
    property ItemIndex: Integer read GetItemIndex write SetItemIndex;
    property AllowCustom: Boolean read FAllowCustom write FAllowCustom;
    property MinSearchLength: Integer read FMinSearchLength write FMinSearchLength;
    property OnItemSelected: TNotifyEvent read FOnItemSelected write FOnItemSelected;
  end;

  /// <summary>
  /// Switch/Toggle with label
  /// </summary>
  TUniLabeledSwitch = class(TLayout)
  private
    FSwitch: TSwitch;
    FLabel: TLabel;
    FOnChange: TNotifyEvent;

    procedure SetLabelText(const Value: string);
    function GetLabelText: string;
    procedure SetIsChecked(const Value: Boolean);
    function GetIsChecked: Boolean;
    procedure SwitchChange(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    property LabelText: string read GetLabelText write SetLabelText;
    property IsChecked: Boolean read GetIsChecked write SetIsChecked;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  /// <summary>
  /// Form validation manager
  /// </summary>
  TUniFormValidator = class
  private
    FControls: TList<TUniMaterialEdit>;
    FOnValidationComplete: TProc<Boolean>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddControl(Control: TUniMaterialEdit);
    procedure RemoveControl(Control: TUniMaterialEdit);
    procedure Clear;
    function ValidateAll: Boolean;
    procedure ValidateAllAsync;

    property OnValidationComplete: TProc<Boolean> read FOnValidationComplete
      write FOnValidationComplete;
  end;

  /// <summary>
  /// Chip/Tag input control
  /// </summary>
  TUniChipInput = class(TLayout)
  private
    FChipsLayout: TFlowLayout;
    FEditBox: TEdit;
    FChips: TStringList;
    FOnChipsChanged: TNotifyEvent;
    FMaxChips: Integer;
    FChipColor: TAlphaColor;
    FChipTextColor: TAlphaColor;

    procedure EditKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
    procedure ChipCloseClick(Sender: TObject);
    procedure AddChipControl(const Text: string);
    procedure RemoveChipControl(const Text: string);
    procedure RebuildChips;
    function GetChipCount: Integer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddChip(const Text: string);
    procedure RemoveChip(const Text: string);
    procedure ClearChips;
    function GetChips: TArray<string>;
    procedure SetChips(const Values: TArray<string>);

    property ChipCount: Integer read GetChipCount;
    property MaxChips: Integer read FMaxChips write FMaxChips;
    property ChipColor: TAlphaColor read FChipColor write FChipColor;
    property ChipTextColor: TAlphaColor read FChipTextColor write FChipTextColor;
    property OnChipsChanged: TNotifyEvent read FOnChipsChanged write FOnChipsChanged;
  end;

  /// <summary>
  /// Star rating control
  /// </summary>
  TUniStarRating = class(TLayout)
  private
    FStars: array[0..4] of TPath;
    FRating: Integer;
    FMaxRating: Integer;
    FReadOnly: Boolean;
    FStarSize: Single;
    FActiveColor: TAlphaColor;
    FInactiveColor: TAlphaColor;
    FOnRatingChange: TNotifyEvent;

    procedure SetRating(const Value: Integer);
    procedure SetStarSize(const Value: Single);
    procedure UpdateStars;
    procedure StarClick(Sender: TObject);
    procedure CreateStars;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    property Rating: Integer read FRating write SetRating;
    property MaxRating: Integer read FMaxRating;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
    property StarSize: Single read FStarSize write SetStarSize;
    property ActiveColor: TAlphaColor read FActiveColor write FActiveColor;
    property InactiveColor: TAlphaColor read FInactiveColor write FInactiveColor;
    property OnRatingChange: TNotifyEvent read FOnRatingChange write FOnRatingChange;
  end;

implementation

uses
  System.Math, FMX.Platform;

const
  STAR_PATH = 'M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z';

{ TValidationResult }

class function TValidationResult.Valid: TValidationResult;
begin
  Result.IsValid := True;
  Result.ErrorMessage := '';
end;

class function TValidationResult.Invalid(const Msg: string): TValidationResult;
begin
  Result.IsValid := False;
  Result.ErrorMessage := Msg;
end;

{ TUniMaterialEdit }

constructor TUniMaterialEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Height := 72;

  FValidators := TList<TValidationFunc>.Create;
  FPrimaryColor := $FF1976D2;
  FErrorColor := $FFB00020;
  FHelperColor := $8A000000;
  FState := uisNormal;
  FMaxLength := 0;

  // Create underline background
  FUnderline := TRectangle.Create(Self);
  FUnderline.Parent := Self;
  FUnderline.Align := TAlignLayout.Bottom;
  FUnderline.Height := 1;
  FUnderline.Stroke.Kind := TBrushKind.None;
  FUnderline.Fill.Color := $42000000;

  // Create focused underline
  FUnderlineFocused := TRectangle.Create(Self);
  FUnderlineFocused.Parent := Self;
  FUnderlineFocused.Align := TAlignLayout.Bottom;
  FUnderlineFocused.Height := 2;
  FUnderlineFocused.Stroke.Kind := TBrushKind.None;
  FUnderlineFocused.Fill.Color := FPrimaryColor;
  FUnderlineFocused.Width := 0;
  FUnderlineFocused.Position.X := Width / 2;

  // Create edit
  FEdit := TEdit.Create(Self);
  FEdit.Parent := Self;
  FEdit.Align := TAlignLayout.Client;
  FEdit.Margins.Top := 20;
  FEdit.Margins.Bottom := 20;
  FEdit.StyleLookup := 'transparentedit';
  FEdit.OnEnter := EditEnter;
  FEdit.OnExit := EditExit;
  FEdit.OnChange := EditChange;

  // Create floating label
  FFloatingLabel := TLabel.Create(Self);
  FFloatingLabel.Parent := Self;
  FFloatingLabel.Position.Y := 28;
  FFloatingLabel.AutoSize := True;
  FFloatingLabel.StyledSettings := [];
  FFloatingLabel.TextSettings.Font.Size := 16;
  FFloatingLabel.TextSettings.FontColor := FHelperColor;
  FFloatingLabel.HitTest := False;

  // Create helper/error label
  FHelperLabel := TLabel.Create(Self);
  FHelperLabel.Parent := Self;
  FHelperLabel.Align := TAlignLayout.Bottom;
  FHelperLabel.Height := 16;
  FHelperLabel.StyledSettings := [];
  FHelperLabel.TextSettings.Font.Size := 12;
  FHelperLabel.TextSettings.FontColor := FHelperColor;
  FHelperLabel.Margins.Top := 4;

  // Create char counter
  FCharCounter := TLabel.Create(Self);
  FCharCounter.Parent := Self;
  FCharCounter.Align := TAlignLayout.Bottom;
  FCharCounter.Height := 16;
  FCharCounter.StyledSettings := [];
  FCharCounter.TextSettings.Font.Size := 12;
  FCharCounter.TextSettings.FontColor := FHelperColor;
  FCharCounter.TextSettings.HorzAlign := TTextAlign.Trailing;
  FCharCounter.Visible := False;
end;

destructor TUniMaterialEdit.Destroy;
begin
  FreeAndNil(FValidators);
  inherited;
end;

procedure TUniMaterialEdit.SetLabelText(const Value: string);
begin
  FLabelText := Value;
  FFloatingLabel.Text := Value;
end;

procedure TUniMaterialEdit.SetHelperText(const Value: string);
begin
  FHelperText := Value;
  if FState <> uisError then
    FHelperLabel.Text := Value;
end;

procedure TUniMaterialEdit.SetErrorText(const Value: string);
begin
  FErrorText := Value;
  if FState = uisError then
    FHelperLabel.Text := Value;
end;

procedure TUniMaterialEdit.SetMaxLength(const Value: Integer);
begin
  FMaxLength := Value;
  FEdit.MaxLength := Value;
  UpdateCharCounter;
end;

procedure TUniMaterialEdit.SetShowCharCounter(const Value: Boolean);
begin
  FShowCharCounter := Value;
  FCharCounter.Visible := Value and (FMaxLength > 0);
  UpdateCharCounter;
end;

procedure TUniMaterialEdit.SetRequired(const Value: Boolean);
begin
  FRequired := Value;
end;

procedure TUniMaterialEdit.SetText(const Value: string);
begin
  FEdit.Text := Value;
  UpdateFloatingLabel(False);
  UpdateCharCounter;
end;

function TUniMaterialEdit.GetText: string;
begin
  Result := FEdit.Text;
end;

procedure TUniMaterialEdit.SetState(const Value: TInputState);
begin
  if FState <> Value then
  begin
    FState := Value;
    UpdateState;
  end;
end;

procedure TUniMaterialEdit.EditEnter(Sender: TObject);
begin
  if FState <> uisError then
    FState := uisFocused;
  UpdateFloatingLabel(True);
  UpdateUnderline;
  UpdateState;
end;

procedure TUniMaterialEdit.EditExit(Sender: TObject);
begin
  if FState = uisFocused then
    FState := uisNormal;
  UpdateFloatingLabel(True);
  UpdateUnderline;
  DoValidate;
end;

procedure TUniMaterialEdit.EditChange(Sender: TObject);
begin
  UpdateCharCounter;
  // Clear error state on change
  if FState = uisError then
  begin
    FState := uisFocused;
    UpdateState;
  end;
end;

procedure TUniMaterialEdit.UpdateFloatingLabel(Animated: Boolean);
var
  IsFloated: Boolean;
begin
  IsFloated := FEdit.IsFocused or (FEdit.Text <> '');

  if Animated then
  begin
    if IsFloated then
    begin
      TAnimator.AnimateFloat(FFloatingLabel, 'Position.Y', 4, 0.2);
      TAnimator.AnimateFloat(FFloatingLabel, 'TextSettings.Font.Size', 12, 0.2);
    end
    else
    begin
      TAnimator.AnimateFloat(FFloatingLabel, 'Position.Y', 28, 0.2);
      TAnimator.AnimateFloat(FFloatingLabel, 'TextSettings.Font.Size', 16, 0.2);
    end;
  end
  else
  begin
    if IsFloated then
    begin
      FFloatingLabel.Position.Y := 4;
      FFloatingLabel.TextSettings.Font.Size := 12;
    end
    else
    begin
      FFloatingLabel.Position.Y := 28;
      FFloatingLabel.TextSettings.Font.Size := 16;
    end;
  end;
end;

procedure TUniMaterialEdit.UpdateCharCounter;
begin
  if FShowCharCounter and (FMaxLength > 0) then
    FCharCounter.Text := Format('%d / %d', [Length(FEdit.Text), FMaxLength]);
end;

procedure TUniMaterialEdit.UpdateUnderline;
begin
  if FEdit.IsFocused then
  begin
    FUnderlineFocused.Width := Width;
    FUnderlineFocused.Position.X := 0;
  end
  else
  begin
    FUnderlineFocused.Width := 0;
    FUnderlineFocused.Position.X := Width / 2;
  end;
end;

procedure TUniMaterialEdit.UpdateState;
var
  LabelColor, UnderlineColor: TAlphaColor;
begin
  case FState of
    uisNormal:
      begin
        LabelColor := FHelperColor;
        UnderlineColor := FPrimaryColor;
        FHelperLabel.Text := FHelperText;
        FHelperLabel.TextSettings.FontColor := FHelperColor;
      end;
    uisFocused:
      begin
        LabelColor := FPrimaryColor;
        UnderlineColor := FPrimaryColor;
        FHelperLabel.Text := FHelperText;
        FHelperLabel.TextSettings.FontColor := FHelperColor;
      end;
    uisError:
      begin
        LabelColor := FErrorColor;
        UnderlineColor := FErrorColor;
        FHelperLabel.Text := FErrorText;
        FHelperLabel.TextSettings.FontColor := FErrorColor;
      end;
    uisDisabled:
      begin
        LabelColor := $42000000;
        UnderlineColor := $42000000;
        FEdit.Enabled := False;
      end;
  end;

  FFloatingLabel.TextSettings.FontColor := LabelColor;
  FUnderlineFocused.Fill.Color := UnderlineColor;
end;

procedure TUniMaterialEdit.DoValidate;
var
  ValidationResult: TValidationResult;
  Validator: TValidationFunc;
begin
  // Check required first
  if FRequired and (FEdit.Text = '') then
  begin
    FState := uisError;
    FErrorText := 'This field is required';
    UpdateState;
    Exit;
  end;

  // Run custom validators
  for Validator in FValidators do
  begin
    ValidationResult := Validator(FEdit.Text);
    if not ValidationResult.IsValid then
    begin
      FState := uisError;
      FErrorText := ValidationResult.ErrorMessage;
      UpdateState;
      Exit;
    end;
  end;

  // Validation passed
  if FState = uisError then
  begin
    FState := uisNormal;
    UpdateState;
  end;

  if Assigned(FOnValidate) then
    FOnValidate(Self);
end;

procedure TUniMaterialEdit.AddValidator(Validator: TValidationFunc);
begin
  FValidators.Add(Validator);
end;

procedure TUniMaterialEdit.ClearValidators;
begin
  FValidators.Clear;
end;

function TUniMaterialEdit.Validate: Boolean;
begin
  DoValidate;
  Result := FState <> uisError;
end;

class function TUniMaterialEdit.RequiredValidator: TValidationFunc;
begin
  Result := function(const Value: string): TValidationResult
    begin
      if Value.Trim = '' then
        Result := TValidationResult.Invalid('This field is required')
      else
        Result := TValidationResult.Valid;
    end;
end;

class function TUniMaterialEdit.EmailValidator: TValidationFunc;
begin
  Result := function(const Value: string): TValidationResult
    begin
      if Value = '' then
        Result := TValidationResult.Valid
      else if TRegEx.IsMatch(Value, '^[\w\.-]+@[\w\.-]+\.\w+$') then
        Result := TValidationResult.Valid
      else
        Result := TValidationResult.Invalid('Please enter a valid email address');
    end;
end;

class function TUniMaterialEdit.MinLengthValidator(MinLen: Integer): TValidationFunc;
begin
  Result := function(const Value: string): TValidationResult
    begin
      if (Value = '') or (Length(Value) >= MinLen) then
        Result := TValidationResult.Valid
      else
        Result := TValidationResult.Invalid(Format('Minimum %d characters required', [MinLen]));
    end;
end;

class function TUniMaterialEdit.MaxLengthValidator(MaxLen: Integer): TValidationFunc;
begin
  Result := function(const Value: string): TValidationResult
    begin
      if Length(Value) <= MaxLen then
        Result := TValidationResult.Valid
      else
        Result := TValidationResult.Invalid(Format('Maximum %d characters allowed', [MaxLen]));
    end;
end;

class function TUniMaterialEdit.PatternValidator(const Pattern, ErrorMsg: string): TValidationFunc;
begin
  Result := function(const Value: string): TValidationResult
    begin
      if (Value = '') or TRegEx.IsMatch(Value, Pattern) then
        Result := TValidationResult.Valid
      else
        Result := TValidationResult.Invalid(ErrorMsg);
    end;
end;

{ TUniSearchComboBox }

constructor TUniSearchComboBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Height := 56;

  FItems := TStringList.Create;
  FFilteredItems := TStringList.Create;
  FMinSearchLength := 1;
  FAllowCustom := False;

  FLabel := TLabel.Create(Self);
  FLabel.Parent := Self;
  FLabel.Align := TAlignLayout.Top;
  FLabel.Height := 16;
  FLabel.StyledSettings := [];
  FLabel.TextSettings.Font.Size := 12;

  FComboEdit := TComboEdit.Create(Self);
  FComboEdit.Parent := Self;
  FComboEdit.Align := TAlignLayout.Client;
  FComboEdit.OnChange := ComboEditChange;
end;

destructor TUniSearchComboBox.Destroy;
begin
  FreeAndNil(FItems);
  FreeAndNil(FFilteredItems);
  inherited;
end;

procedure TUniSearchComboBox.SetLabelText(const Value: string);
begin
  FLabel.Text := Value;
end;

function TUniSearchComboBox.GetLabelText: string;
begin
  Result := FLabel.Text;
end;

procedure TUniSearchComboBox.SetItems(const Value: TStrings);
begin
  FItems.Assign(Value);
  FComboEdit.Items.Assign(Value);
end;

function TUniSearchComboBox.GetText: string;
begin
  Result := FComboEdit.Text;
end;

procedure TUniSearchComboBox.SetText(const Value: string);
begin
  FComboEdit.Text := Value;
end;

function TUniSearchComboBox.GetItemIndex: Integer;
begin
  Result := FComboEdit.ItemIndex;
end;

procedure TUniSearchComboBox.SetItemIndex(const Value: Integer);
begin
  FComboEdit.ItemIndex := Value;
end;

procedure TUniSearchComboBox.ComboEditChange(Sender: TObject);
begin
  if Length(FComboEdit.Text) >= FMinSearchLength then
    FilterItems(FComboEdit.Text)
  else
    FComboEdit.Items.Assign(FItems);
end;

procedure TUniSearchComboBox.FilterItems(const SearchText: string);
var
  I: Integer;
  SearchLower: string;
begin
  SearchLower := LowerCase(SearchText);
  FFilteredItems.Clear;

  for I := 0 to FItems.Count - 1 do
  begin
    if Pos(SearchLower, LowerCase(FItems[I])) > 0 then
      FFilteredItems.Add(FItems[I]);
  end;

  FComboEdit.Items.Assign(FFilteredItems);
  if FFilteredItems.Count > 0 then
    FComboEdit.DropDown;
end;

{ TUniLabeledSwitch }

constructor TUniLabeledSwitch.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Height := 44;

  FLabel := TLabel.Create(Self);
  FLabel.Parent := Self;
  FLabel.Align := TAlignLayout.Client;
  FLabel.TextSettings.VertAlign := TTextAlign.Center;

  FSwitch := TSwitch.Create(Self);
  FSwitch.Parent := Self;
  FSwitch.Align := TAlignLayout.Right;
  FSwitch.Width := 60;
  FSwitch.OnSwitch := SwitchChange;
end;

destructor TUniLabeledSwitch.Destroy;
begin
  inherited;
end;

procedure TUniLabeledSwitch.SetLabelText(const Value: string);
begin
  FLabel.Text := Value;
end;

function TUniLabeledSwitch.GetLabelText: string;
begin
  Result := FLabel.Text;
end;

procedure TUniLabeledSwitch.SetIsChecked(const Value: Boolean);
begin
  FSwitch.IsChecked := Value;
end;

function TUniLabeledSwitch.GetIsChecked: Boolean;
begin
  Result := FSwitch.IsChecked;
end;

procedure TUniLabeledSwitch.SwitchChange(Sender: TObject);
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

{ TUniFormValidator }

constructor TUniFormValidator.Create;
begin
  inherited Create;
  FControls := TList<TUniMaterialEdit>.Create;
end;

destructor TUniFormValidator.Destroy;
begin
  FreeAndNil(FControls);
  inherited;
end;

procedure TUniFormValidator.AddControl(Control: TUniMaterialEdit);
begin
  if not FControls.Contains(Control) then
    FControls.Add(Control);
end;

procedure TUniFormValidator.RemoveControl(Control: TUniMaterialEdit);
begin
  FControls.Remove(Control);
end;

procedure TUniFormValidator.Clear;
begin
  FControls.Clear;
end;

function TUniFormValidator.ValidateAll: Boolean;
var
  Control: TUniMaterialEdit;
begin
  Result := True;
  for Control in FControls do
  begin
    if not Control.Validate then
      Result := False;
  end;
end;

procedure TUniFormValidator.ValidateAllAsync;
begin
  TThread.CreateAnonymousThread(
    procedure
    var
      IsValid: Boolean;
    begin
      IsValid := ValidateAll;
      TThread.Synchronize(nil, TThreadProcedure(
        procedure
        begin
          if Assigned(FOnValidationComplete) then
            FOnValidationComplete(IsValid);
        end));
    end).Start;
end;

{ TUniChipInput }

constructor TUniChipInput.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Height := 56;

  FChips := TStringList.Create;
  FMaxChips := 10;
  FChipColor := $FFE0E0E0;
  FChipTextColor := $DE000000;

  FChipsLayout := TFlowLayout.Create(Self);
  FChipsLayout.Parent := Self;
  FChipsLayout.Align := TAlignLayout.Client;

  FEditBox := TEdit.Create(Self);
  FEditBox.Parent := FChipsLayout;
  FEditBox.Width := 100;
  FEditBox.OnKeyDown := EditKeyDown;
end;

destructor TUniChipInput.Destroy;
begin
  FreeAndNil(FChips);
  inherited;
end;

procedure TUniChipInput.EditKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin
  // Enter or comma adds chip
  if (Key = vkReturn) or (KeyChar = ',') then
  begin
    if FEditBox.Text.Trim <> '' then
    begin
      AddChip(FEditBox.Text.Trim);
      FEditBox.Text := '';
    end;
    Key := 0;
    KeyChar := #0;
  end
  // Backspace removes last chip if edit is empty
  else if (Key = vkBack) and (FEditBox.Text = '') and (FChips.Count > 0) then
  begin
    RemoveChip(FChips[FChips.Count - 1]);
  end;
end;

procedure TUniChipInput.ChipCloseClick(Sender: TObject);
begin
  if Sender is TLabel then
    RemoveChip(TLabel(Sender).TagString);
end;

procedure TUniChipInput.AddChipControl(const Text: string);
var
  ChipLayout: TLayout;
  ChipRect: TRectangle;
  ChipLabel: TLabel;
  CloseBtn: TLabel;
begin
  ChipLayout := TLayout.Create(FChipsLayout);
  ChipLayout.Parent := FChipsLayout;
  ChipLayout.Width := 0; // Will be auto-sized
  ChipLayout.Height := 32;
  ChipLayout.Margins.Right := 4;
  ChipLayout.Margins.Bottom := 4;
  ChipLayout.Tag := FChips.IndexOf(Text);
  ChipLayout.TagString := Text;

  ChipRect := TRectangle.Create(ChipLayout);
  ChipRect.Parent := ChipLayout;
  ChipRect.Align := TAlignLayout.Client;
  ChipRect.Fill.Color := FChipColor;
  ChipRect.Stroke.Kind := TBrushKind.None;
  ChipRect.Corners := [TCorner.TopLeft, TCorner.TopRight, TCorner.BottomLeft, TCorner.BottomRight];
  ChipRect.XRadius := 16;
  ChipRect.YRadius := 16;

  ChipLabel := TLabel.Create(ChipLayout);
  ChipLabel.Parent := ChipLayout;
  ChipLabel.Align := TAlignLayout.Client;
  ChipLabel.Margins.Left := 12;
  ChipLabel.Margins.Right := 28;
  ChipLabel.Text := Text;
  ChipLabel.StyledSettings := [];
  ChipLabel.TextSettings.FontColor := FChipTextColor;
  ChipLabel.TextSettings.VertAlign := TTextAlign.Center;
  ChipLabel.AutoSize := True;

  CloseBtn := TLabel.Create(ChipLayout);
  CloseBtn.Parent := ChipLayout;
  CloseBtn.Align := TAlignLayout.Right;
  CloseBtn.Width := 24;
  CloseBtn.Text := '×';
  CloseBtn.StyledSettings := [];
  CloseBtn.TextSettings.FontColor := FChipTextColor;
  CloseBtn.TextSettings.HorzAlign := TTextAlign.Center;
  CloseBtn.TextSettings.VertAlign := TTextAlign.Center;
  CloseBtn.HitTest := True;
  CloseBtn.Cursor := crHandPoint;
  CloseBtn.TagString := Text;
  CloseBtn.OnClick := ChipCloseClick;

  // Auto-size chip width
  ChipLayout.Width := ChipLabel.Width + 44;
end;

procedure TUniChipInput.RemoveChipControl(const Text: string);
var
  I: Integer;
begin
  for I := FChipsLayout.ChildrenCount - 1 downto 0 do
  begin
    if (FChipsLayout.Children[I] is TLayout) and
       (TLayout(FChipsLayout.Children[I]).TagString = Text) then
    begin
      FChipsLayout.Children[I].Free;
      Break;
    end;
  end;
end;

procedure TUniChipInput.RebuildChips;
var
  I: Integer;
begin
  // Remove all chip controls
  for I := FChipsLayout.ChildrenCount - 1 downto 0 do
  begin
    if FChipsLayout.Children[I] <> FEditBox then
      FChipsLayout.Children[I].Free;
  end;

  // Recreate
  for I := 0 to FChips.Count - 1 do
    AddChipControl(FChips[I]);
end;

function TUniChipInput.GetChipCount: Integer;
begin
  Result := FChips.Count;
end;

procedure TUniChipInput.AddChip(const Text: string);
begin
  if (FChips.IndexOf(Text) < 0) and (FChips.Count < FMaxChips) then
  begin
    FChips.Add(Text);
    AddChipControl(Text);
    if Assigned(FOnChipsChanged) then
      FOnChipsChanged(Self);
  end;
end;

procedure TUniChipInput.RemoveChip(const Text: string);
var
  Index: Integer;
begin
  Index := FChips.IndexOf(Text);
  if Index >= 0 then
  begin
    FChips.Delete(Index);
    RemoveChipControl(Text);
    if Assigned(FOnChipsChanged) then
      FOnChipsChanged(Self);
  end;
end;

procedure TUniChipInput.ClearChips;
begin
  FChips.Clear;
  RebuildChips;
  if Assigned(FOnChipsChanged) then
    FOnChipsChanged(Self);
end;

function TUniChipInput.GetChips: TArray<string>;
begin
  Result := FChips.ToStringArray;
end;

procedure TUniChipInput.SetChips(const Values: TArray<string>);
var
  S: string;
begin
  FChips.Clear;
  for S in Values do
    FChips.Add(S);
  RebuildChips;
end;

{ TUniStarRating }

constructor TUniStarRating.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMaxRating := 5;
  FRating := 0;
  FStarSize := 32;
  FReadOnly := False;
  FActiveColor := $FFFFC107; // Amber
  FInactiveColor := $FFE0E0E0;

  Height := FStarSize;
  Width := FStarSize * FMaxRating;

  CreateStars;
end;

destructor TUniStarRating.Destroy;
begin
  inherited;
end;

procedure TUniStarRating.CreateStars;
var
  I: Integer;
begin
  for I := 0 to FMaxRating - 1 do
  begin
    FStars[I] := TPath.Create(Self);
    FStars[I].Parent := Self;
    FStars[I].Width := FStarSize;
    FStars[I].Height := FStarSize;
    FStars[I].Position.X := I * FStarSize;
    FStars[I].Data.Data := STAR_PATH;
    FStars[I].WrapMode := TPathWrapMode.Fit;
    FStars[I].Fill.Color := FInactiveColor;
    FStars[I].Stroke.Kind := TBrushKind.None;
    FStars[I].Tag := I + 1;
    FStars[I].HitTest := True;
    FStars[I].OnClick := StarClick;
  end;
end;

procedure TUniStarRating.SetRating(const Value: Integer);
begin
  FRating := EnsureRange(Value, 0, FMaxRating);
  UpdateStars;
  if Assigned(FOnRatingChange) then
    FOnRatingChange(Self);
end;

procedure TUniStarRating.SetStarSize(const Value: Single);
var
  I: Integer;
begin
  FStarSize := Value;
  Height := FStarSize;
  Width := FStarSize * FMaxRating;

  for I := 0 to FMaxRating - 1 do
  begin
    FStars[I].Width := FStarSize;
    FStars[I].Height := FStarSize;
    FStars[I].Position.X := I * FStarSize;
  end;
end;

procedure TUniStarRating.UpdateStars;
var
  I: Integer;
begin
  for I := 0 to FMaxRating - 1 do
  begin
    if I < FRating then
      FStars[I].Fill.Color := FActiveColor
    else
      FStars[I].Fill.Color := FInactiveColor;
  end;
end;

procedure TUniStarRating.StarClick(Sender: TObject);
begin
  if not FReadOnly then
    Rating := TPath(Sender).Tag;
end;

end.
