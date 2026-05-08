{ ============================================================================
  DeepBase.Unlock - Lightweight Unlock Module
  
  Version: 0.1
  Description:
    Lightweight, non-intrusive unlock mechanism for freemium-style apps.
    Designed for simple "follow / share" marketing flows (e.g. TwoKeyRun),
    separate from the full enterprise license system (DeepBase.License).

    Unlock code format (default implementation):
      [ProductCode][YY][MM][CheckChar]

      Example: TK2412A
        - ProductCode = 'TK' (TwoKeyRun)
        - YY         = '24' (2024)
        - MM         = '12' (December)
        - CheckChar  = computed from ProductCode + YYMM + UnlockLevel

    Validation rules:
      - Product code must match the configured product code
      - YYMM must be a valid month
      - Effective period: current month and previous 2 months
      - CheckChar must match one of the supported unlock levels

    This module is intentionally simple and NOT a strong security barrier.
    It is optimized for low-friction private-domain marketing flows.
  ============================================================================ }

unit DeepBase.Unlock;

interface

uses
  System.SysUtils,
  System.DateUtils;

type
  /// <summary>
  /// Unlock level for a product.
  /// ulFree   : default experience, no unlock code required
  /// ulFollow : unlocked after following an official account, etc.
  /// ulShare  : unlocked after sharing, inviting friends, etc.
  /// </summary>
  TUnlockLevel = (ulFree, ulFollow, ulShare);

  /// <summary>
  /// Unlock validation status.
  /// </summary>
  TUnlockValidationStatus = (
    uvsOk,              // Valid code within allowed date window
    uvsEmptyCode,       // Empty or whitespace-only code
    uvsInvalidFormat,   // Wrong length or YYMM cannot be parsed
    uvsProductMismatch, // Product code prefix does not match
    uvsExpired,         // Outside allowed date window
    uvsInvalidChecksum  // CheckChar does not match any unlock level
  );

  /// <summary>
  /// Parsed unlock information.
  /// </summary>
  TUnlockInfo = record
    ProductCode: string;
    Code: string;
    Level: TUnlockLevel;
    Year2Digit: Integer;  // 0..99 (e.g. 24 for 2024)
    Month: Integer;       // 1..12
    Status: TUnlockValidationStatus;
    ErrorMessage: string;

    /// <summary>True if Status = uvsOk.</summary>
    function IsValid: Boolean;
    /// <summary>True if Status = uvsExpired.</summary>
    function IsExpired: Boolean;
  end;

  /// <summary>
  /// Lightweight unlock manager bound to a specific product code.
  ///
  /// Persistence:
  ///   - Uses DeepBase.Config (Settings table) to store current unlock level
  ///   - Keys are of the form:
  ///       Unlock.&lt;ProductCode&gt;.Level  (Free/Follow/Share)
  ///       Unlock.&lt;ProductCode&gt;.Code   (raw code string)
  ///   - Category: 'Unlock'
  /// </summary>
  TDeepBaseUnlock = class
  private
    FProductCode: string;
    FConfigKeyLevel: string;
    FConfigKeyCode: string;

    function GetStoredLevel: TUnlockLevel;
    procedure SetStoredLevel(const Value: TUnlockLevel);
    function GetStoredCode: string;
    procedure SetStoredCode(const Value: string);

    class function NormalizeProductCode(const Value: string): string; static;
    class function LevelToStr(Level: TUnlockLevel): string; static;
    class function StrToLevel(const S: string): TUnlockLevel; static;
    class function StatusToStr(Status: TUnlockValidationStatus): string; static;

    class function ComputeLegacyCheckChar(const AProductCode: string;
      Year2, Month: Integer; Level: TUnlockLevel): Char; static;
    class function ComputeCheckChar(const AProductCode: string;
      Year2, Month: Integer; Level: TUnlockLevel): Char; static;
    class function ParseCode(const AProductCode, Code: string;
      out Year2, Month: Integer; out CheckChar: Char;
      out Status: TUnlockValidationStatus; out ErrorMsg: string): Boolean; static;
  public
    /// <summary>
    /// Create unlock manager for a specific product.
    /// ProductCode is normalized to upper case and trimmed.
    /// </summary>
    constructor Create(const AProductCode: string);

    /// <summary>
    /// Validate an unlock code without changing stored level.
    /// Fills TUnlockInfo with parsed data and status.
    /// </summary>
    function ValidateCode(const Code: string; out Info: TUnlockInfo): TUnlockValidationStatus;

    /// <summary>
    /// Validate and, if valid, persist the new level to config.
    /// If the new level is lower than the stored level, it is ignored.
    /// Returns True only when Status = uvsOk and level was accepted.
    /// </summary>
    function ApplyCode(const Code: string; out Info: TUnlockInfo): Boolean;

    /// <summary>Current stored unlock level (defaults to ulFree).</summary>
    property StoredLevel: TUnlockLevel read GetStoredLevel write SetStoredLevel;

    /// <summary>Last successfully applied unlock code (may be empty).</summary>
    property StoredCode: string read GetStoredCode write SetStoredCode;

    /// <summary>Product code this manager is bound to (upper case).</summary>
    property ProductCode: string read FProductCode;

    // ------------------------------------------------------------------------
    // Static helpers
    // ------------------------------------------------------------------------

    /// <summary>
    /// Generate an unlock code for a given product, date and level.
    /// This is intended for use by tooling (e.g. UniPublisher) and tests.
    /// </summary>
    class function GenerateCode(const AProductCode: string; ADate: TDateTime;
      Level: TUnlockLevel): string; static;

    /// <summary>String representation for logging/debugging.</summary>
    class function UnlockLevelToStr(Level: TUnlockLevel): string; static;
    class function UnlockStatusToStr(Status: TUnlockValidationStatus): string; static;
  end;

implementation

uses
  System.Hash,
  DeepBase.Config;

const
  // Category used when persisting unlock-related settings.
  UNLOCK_CONFIG_CATEGORY = 'Unlock';

  // Secret seed used for CheckChar computation.
  // NOTE: This is not meant for strong cryptographic protection, only to
  // prevent trivial manual guessing of valid codes.
  UNLOCK_SECRET = 'DeepBase-Unlock-Seed-2025';

  // Alphabet used to map checksum index to visible character.
  // Digits 0/1 and letters O/I are intentionally omitted to reduce confusion.
  CHECK_ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  LEVEL_CHECK_STRIDE = 11; // Keeps Free/Follow/Share chars distinct in a 32-char alphabet.

{ TUnlockInfo }

function TUnlockInfo.IsValid: Boolean;
begin
  Result := Status = uvsOk;
end;

function TUnlockInfo.IsExpired: Boolean;
begin
  Result := Status = uvsExpired;
end;

{ TDeepBaseUnlock }

constructor TDeepBaseUnlock.Create(const AProductCode: string);
begin
  inherited Create;
  FProductCode := NormalizeProductCode(AProductCode);
  if FProductCode = '' then
    raise EArgumentException.Create('ProductCode must not be empty for TDeepBaseUnlock');

  FConfigKeyLevel := Format('Unlock.%s.Level', [FProductCode]);
  FConfigKeyCode  := Format('Unlock.%s.Code', [FProductCode]);
end;

class function TDeepBaseUnlock.NormalizeProductCode(const Value: string): string;
begin
  Result := UpperCase(Trim(Value));
end;

class function TDeepBaseUnlock.LevelToStr(Level: TUnlockLevel): string;
begin
  case Level of
    ulFree:   Result := 'Free';
    ulFollow: Result := 'Follow';
    ulShare:  Result := 'Share';
  else
    Result := 'Unknown';
  end;
end;

class function TDeepBaseUnlock.StrToLevel(const S: string): TUnlockLevel;
var
  Upper: string;
begin
  Upper := UpperCase(Trim(S));
  if (Upper = '') or (Upper = 'FREE') then
    Result := ulFree
  else if Upper = 'FOLLOW' then
    Result := ulFollow
  else if Upper = 'SHARE' then
    Result := ulShare
  else
    Result := ulFree; // Fallback
end;

class function TDeepBaseUnlock.StatusToStr(Status: TUnlockValidationStatus): string;
begin
  case Status of
    uvsOk:              Result := 'Ok';
    uvsEmptyCode:       Result := 'EmptyCode';
    uvsInvalidFormat:   Result := 'InvalidFormat';
    uvsProductMismatch: Result := 'ProductMismatch';
    uvsExpired:         Result := 'Expired';
    uvsInvalidChecksum: Result := 'InvalidChecksum';
  else
    Result := 'Unknown';
  end;
end;

class function TDeepBaseUnlock.UnlockLevelToStr(Level: TUnlockLevel): string;
begin
  Result := LevelToStr(Level);
end;

class function TDeepBaseUnlock.UnlockStatusToStr(Status: TUnlockValidationStatus): string;
begin
  Result := StatusToStr(Status);
end;

function TDeepBaseUnlock.GetStoredLevel: TUnlockLevel;
var
  S: string;
begin
  // Default to Free if nothing stored.
  S := DeepBase.Config.GetConfig(FConfigKeyLevel, 'Free');
  Result := StrToLevel(S);
end;

procedure TDeepBaseUnlock.SetStoredLevel(const Value: TUnlockLevel);
begin
  DeepBase.Config.SetConfig(FConfigKeyLevel, LevelToStr(Value), UNLOCK_CONFIG_CATEGORY);
end;

function TDeepBaseUnlock.GetStoredCode: string;
begin
  Result := DeepBase.Config.GetConfig(FConfigKeyCode, '');
end;

procedure TDeepBaseUnlock.SetStoredCode(const Value: string);
begin
  DeepBase.Config.SetConfig(FConfigKeyCode, Trim(Value), UNLOCK_CONFIG_CATEGORY);
end;

class function TDeepBaseUnlock.ComputeLegacyCheckChar(const AProductCode: string;
  Year2, Month: Integer; Level: TUnlockLevel): Char;
var
  Seed, Hash: string;
  I, Sum, Index: Integer;
begin
  // Basic normalization and clamping
  if Year2 < 0 then
    Year2 := 0
  else if Year2 > 99 then
    Year2 := Year2 mod 100;

  if Month < 1 then
    Month := 1
  else if Month > 12 then
    Month := Month mod 12;

  Seed := NormalizeProductCode(AProductCode) +
          Format('%.2d%.2d', [Year2, Month]) +
          IntToStr(Ord(Level)) +
          UNLOCK_SECRET;

  Hash := THashSHA2.GetHashString(Seed, THashSHA2.TSHA2Version.SHA256);
  Sum := 0;
  for I := 1 to Length(Hash) do
    Inc(Sum, Ord(Hash[I]));

  if Length(CHECK_ALPHABET) = 0 then
    Result := 'A'
  else
  begin
    Index := (Sum mod Length(CHECK_ALPHABET)) + 1;
    Result := CHECK_ALPHABET[Index];
  end;
end;

class function TDeepBaseUnlock.ComputeCheckChar(const AProductCode: string;
  Year2, Month: Integer; Level: TUnlockLevel): Char;
var
  Seed, Hash: string;
  I, Sum, Index: Integer;
begin
  // Basic normalization and clamping
  if Year2 < 0 then
    Year2 := 0
  else if Year2 > 99 then
    Year2 := Year2 mod 100;

  if Month < 1 then
    Month := 1
  else if Month > 12 then
    Month := Month mod 12;

  Seed := NormalizeProductCode(AProductCode) +
          Format('%.2d%.2d', [Year2, Month]) +
          UNLOCK_SECRET;

  Hash := THashSHA2.GetHashString(Seed, THashSHA2.TSHA2Version.SHA256);
  Sum := 0;
  for I := 1 to Length(Hash) do
    Inc(Sum, Ord(Hash[I]));

  if Length(CHECK_ALPHABET) = 0 then
    Result := 'A'
  else
  begin
    Index := ((Sum + Ord(Level) * LEVEL_CHECK_STRIDE) mod Length(CHECK_ALPHABET)) + 1;
    Result := CHECK_ALPHABET[Index];
  end;
end;

class function TDeepBaseUnlock.ParseCode(const AProductCode, Code: string;
  out Year2, Month: Integer; out CheckChar: Char;
  out Status: TUnlockValidationStatus; out ErrorMsg: string): Boolean;
var
  Trimmed, Prod, YYStr, MMStr: string;
  ProdLen: Integer;
begin
  Result := False;
  Status := uvsInvalidFormat;
  ErrorMsg := '';
  Year2 := -1;
  Month := -1;
  CheckChar := #0;

  Trimmed := Trim(Code);
  if Trimmed = '' then
  begin
    Status := uvsEmptyCode;
    ErrorMsg := 'Unlock code is empty.';
    Exit;
  end;

  Prod := NormalizeProductCode(AProductCode);
  ProdLen := Length(Prod);

  // Expected format: [Prod][YY][MM][Check] => length = ProdLen + 5
  if Length(Trimmed) <> ProdLen + 5 then
  begin
    Status := uvsInvalidFormat;
    ErrorMsg := Format('Unlock code must have length %d for product %s.',
      [ProdLen + 5, Prod]);
    Exit;
  end;

  if not SameText(Copy(Trimmed, 1, ProdLen), Prod) then
  begin
    Status := uvsProductMismatch;
    ErrorMsg := 'Product code prefix does not match.';
    Exit;
  end;

  YYStr := Copy(Trimmed, ProdLen + 1, 2);
  MMStr := Copy(Trimmed, ProdLen + 3, 2);
  CheckChar := UpCase(Trimmed[Length(Trimmed)]);

  if (not TryStrToInt(YYStr, Year2)) or
     (not TryStrToInt(MMStr, Month)) then
  begin
    Status := uvsInvalidFormat;
    ErrorMsg := 'YYMM segment is not numeric.';
    Exit;
  end;

  if (Month < 1) or (Month > 12) then
  begin
    Status := uvsInvalidFormat;
    ErrorMsg := 'Month in code is out of range (1..12).';
    Exit;
  end;

  Status := uvsOk;
  Result := True;
end;

function TDeepBaseUnlock.ValidateCode(const Code: string; out Info: TUnlockInfo): TUnlockValidationStatus;
var
  Y2, M: Integer;
  Check: Char;
  Status: TUnlockValidationStatus;
  Err: string;
  L: TUnlockLevel;
  Matched: Boolean;
  YearFull: Word;
  IssueDate, Earliest, Latest: TDateTime;
begin
  Info.ProductCode := FProductCode;
  Info.Code := Trim(Code);
  Info.Level := ulFree;
  Info.Year2Digit := -1;
  Info.Month := -1;
  Info.Status := uvsInvalidFormat;
  Info.ErrorMessage := '';

  if not ParseCode(FProductCode, Info.Code, Y2, M, Check, Status, Err) then
  begin
    Info.Status := Status;
    Info.ErrorMessage := Err;
    Result := Status;
    Exit;
  end;

  // Try to infer unlock level from CheckChar by testing all levels
  Matched := False;
  for L := Low(TUnlockLevel) to High(TUnlockLevel) do
  begin
    if ComputeCheckChar(FProductCode, Y2, M, L) = Check then
    begin
      Info.Level := L;
      Matched := True;
      Break;
    end;
  end;

  // Compatibility with codes generated before the collision-safe checksum.
  if not Matched then
  begin
    for L := Low(TUnlockLevel) to High(TUnlockLevel) do
    begin
      if ComputeLegacyCheckChar(FProductCode, Y2, M, L) = Check then
      begin
        Info.Level := L;
        Matched := True;
        Break;
      end;
    end;
  end;

  if not Matched then
  begin
    Info.Status := uvsInvalidChecksum;
    Info.ErrorMessage := 'Checksum does not match any supported unlock level.';
    Result := uvsInvalidChecksum;
    Exit;
  end;

  Info.Year2Digit := Y2;
  Info.Month := M;

  // Date window validation: current month and previous 2 months only
  try
    YearFull := 2000 + Word(Y2 mod 100);
    IssueDate := EncodeDate(YearFull, M, 1);
  except
    on E: Exception do
    begin
      Info.Status := uvsInvalidFormat;
      Info.ErrorMessage := 'Invalid date encoded in unlock code: ' + E.Message;
      Result := uvsInvalidFormat;
      Exit;
    end;
  end;

  Earliest := IncMonth(StartOfTheMonth(Now), -2);
  Latest := EndOfTheMonth(Now);

  if (IssueDate < Earliest) or (IssueDate > Latest) then
  begin
    Info.Status := uvsExpired;
    Info.ErrorMessage := 'Unlock code is outside the allowed 3-month window.';
    Result := uvsExpired;
    Exit;
  end;

  Info.Status := uvsOk;
  Info.ErrorMessage := '';
  Result := uvsOk;
end;

function TDeepBaseUnlock.ApplyCode(const Code: string; out Info: TUnlockInfo): Boolean;
var
  Status: TUnlockValidationStatus;
  Current: TUnlockLevel;
begin
  Status := ValidateCode(Code, Info);
  Result := Status = uvsOk;
  if not Result then
    Exit;

  Current := GetStoredLevel;
  if Ord(Info.Level) > Ord(Current) then
  begin
    SetStoredLevel(Info.Level);
    SetStoredCode(Info.Code);
  end;
end;

class function TDeepBaseUnlock.GenerateCode(const AProductCode: string; ADate: TDateTime;
  Level: TUnlockLevel): string;
var
  Prod: string;
  Y2, M, D: Word;
  Check: Char;
begin
  Prod := NormalizeProductCode(AProductCode);
  DecodeDate(ADate, Y2, M, D);
  Y2 := Y2 mod 100; // 2-digit year
  Check := ComputeCheckChar(Prod, Y2, M, Level);
  Result := Prod + Format('%.2d%.2d', [Y2, M]) + Check;
end;

end.
