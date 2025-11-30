{ ============================================================================
  UniBase.Config - Configuration Management Module
  
  Version: 0.3
  Description: Provides type-safe config read/write with memory cache and
               thread-safe protection.
  Thread Safety: All public methods are thread-safe.
  ============================================================================ }

unit UniBase.Config;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.NetEncoding,
  FireDAC.Comp.Client,
  UniBase.Types,
  UniBase.Consts;

type
  /// <summary>
  /// Configuration manager
  /// </summary>
  TUniBaseConfig = class
  private
    FConnection: TFDConnection;
    FLock: TObject;
    FCache: TDictionary<string, string>;
    FCacheEnabled: Boolean;
    FOnConfigChanged: TConfigChangedEvent;
    
    function ReadFromDB(const Key: string; const Default: string = ''): string;
    function ReadFromDBEx(const Key: string; out IsEncrypted: Boolean; const Default: string = ''): string;
    procedure WriteToDB(const Key, Value: string; const Category: string; 
      const ValueType: string; const Description: string);
    procedure WriteToDBEncrypted(const Key, Value: string; const Category: string;
      IsEncrypted: Boolean);
    
    // Simple encryption (XOR + Base64) for sensitive config values
    function EncryptValue(const Value: string): string;
    function DecryptValue(const EncryptedValue: string): string;
    
  public
    constructor Create(AConnection: TFDConnection; ALock: TObject);
    destructor Destroy; override;
    
    /// <summary>Clear cache</summary>
    procedure ClearCache;
    
    /// <summary>Preload all config into cache</summary>
    procedure PreloadCache;
    
    // ========================================
    // String Config
    // ========================================
    
    function GetConfig(const Key: string; const Default: string = ''): string;
    procedure SetConfig(const Key, Value: string; const Category: string = SConfigCategoryGeneral);
    
    // ========================================
    // Integer Config
    // ========================================
    
    function GetConfigInt(const Key: string; Default: Integer = 0): Integer;
    procedure SetConfigInt(const Key: string; Value: Integer; const Category: string = SConfigCategoryGeneral);
    
    // ========================================
    // Boolean Config
    // ========================================
    
    function GetConfigBool(const Key: string; Default: Boolean = False): Boolean;
    procedure SetConfigBool(const Key: string; Value: Boolean; const Category: string = SConfigCategoryGeneral);
    
    // ========================================
    // Float Config
    // ========================================
    
    function GetConfigFloat(const Key: string; Default: Double = 0): Double;
    procedure SetConfigFloat(const Key: string; Value: Double; const Category: string = SConfigCategoryGeneral);
    
    // ========================================
    // Batch Operations
    // ========================================
    
    /// <summary>Get all configs for a category</summary>
    function GetConfigsByCategory(const Category: string): TDictionary<string, string>;
    
    /// <summary>Delete config</summary>
    procedure DeleteConfig(const Key: string);
    
    /// <summary>Check if config exists</summary>
    function ConfigExists(const Key: string): Boolean;
    
    // ========================================
    // Encrypted Config (DEPRECATED)
    // WARNING: Uses XOR obfuscation, NOT secure encryption!
    // For secure storage of passwords/API keys, use UniBase.Security module instead:
    //   UniBase.Security.SaveSecret('key', 'value');
    //   Value := UniBase.Security.LoadSecret('key');
    // ========================================
    
    /// <summary>
    /// Get encrypted config value (auto-decrypts).
    /// DEPRECATED: Use UniBase.Security.LoadSecret() instead for secure storage.
    /// </summary>
    function GetConfigEncrypted(const Key: string; const Default: string = ''): string;
      deprecated 'Use UniBase.Security.LoadSecret() for secure DPAPI encryption';
    
    /// <summary>
    /// Set config with XOR obfuscation.
    /// DEPRECATED: Use UniBase.Security.SaveSecret() instead for secure storage.
    /// </summary>
    procedure SetConfigEncrypted(const Key, Value: string; const Category: string = SConfigCategoryGeneral);
      deprecated 'Use UniBase.Security.SaveSecret() for secure DPAPI encryption';
    
    // ========================================
    // Properties
    // ========================================
    
    /// <summary>Enable cache</summary>
    property CacheEnabled: Boolean read FCacheEnabled write FCacheEnabled;
    
    /// <summary>Config changed event</summary>
    property OnConfigChanged: TConfigChangedEvent read FOnConfigChanged write FOnConfigChanged;
  end;

implementation

uses
  System.StrUtils;

const
  // ============================================================================
  // WARNING: SECURITY NOTICE
  // ============================================================================
  // This is NOT cryptographically secure encryption!
  // XOR + Base64 provides OBFUSCATION only, not security.
  //
  // Limitations:
  //   - Fixed key hardcoded in source (can be extracted via reverse engineering)
  //   - Simple XOR is trivially breakable with known plaintext
  //   - Provides no protection against determined attackers
  //
  // Suitable for:
  //   - Preventing casual viewing of config values in plain text
  //   - Meeting basic compliance requirements for "not storing passwords in clear"
  //
  // NOT suitable for:
  //   - Protecting highly sensitive data (API keys with billing, passwords)
  //   - PCI-DSS, HIPAA, or other compliance requirements
  //
  // For stronger protection, consider:
  //   - Windows: Use DPAPI via CryptProtectData/CryptUnprotectData
  //   - Cross-platform: Use AES-256 with user-derived key
  //   - Hardware: Use platform keychain/credential manager
  // ============================================================================
  CONFIG_ENCRYPT_KEY: array[0..15] of Byte = (
    $A3, $7B, $F2, $91, $C4, $8E, $5D, $06,
    $3A, $E7, $1C, $B5, $68, $2F, $D9, $40
  );

{ TUniBaseConfig }

constructor TUniBaseConfig.Create(AConnection: TFDConnection; ALock: TObject);
begin
  inherited Create;
  FConnection := AConnection;
  FLock := ALock;
  FCache := TDictionary<string, string>.Create;
  FCacheEnabled := True;
end;

destructor TUniBaseConfig.Destroy;
begin
  FCache.Free;
  inherited;
end;

procedure TUniBaseConfig.ClearCache;
begin
  TMonitor.Enter(FLock);
  try
    FCache.Clear;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseConfig.PreloadCache;
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    FCache.Clear;
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT Key, Value FROM Settings';
      Query.Open;
      
      while not Query.Eof do
      begin
        FCache.AddOrSetValue(
          Query.FieldByName('Key').AsString,
          Query.FieldByName('Value').AsString
        );
        Query.Next;
      end;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseConfig.ReadFromDB(const Key: string; const Default: string): string;
var
  Query: TFDQuery;
begin
  Result := Default;
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT Value FROM Settings WHERE Key = :Key';
    Query.ParamByName('Key').AsString := Key;
    Query.Open;
    
    if not Query.Eof then
      Result := Query.FieldByName('Value').AsString;
  finally
    Query.Free;
  end;
end;

procedure TUniBaseConfig.WriteToDB(const Key, Value, Category, ValueType, Description: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'INSERT OR REPLACE INTO Settings (Key, Value, Category, ValueType, Description) ' +
      'VALUES (:Key, :Value, :Category, :ValueType, :Description)';
    Query.ParamByName('Key').AsString := Key;
    Query.ParamByName('Value').AsString := Value;
    Query.ParamByName('Category').AsString := Category;
    Query.ParamByName('ValueType').AsString := ValueType;
    Query.ParamByName('Description').AsString := Description;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TUniBaseConfig.ReadFromDBEx(const Key: string; out IsEncrypted: Boolean; 
  const Default: string): string;
var
  Query: TFDQuery;
begin
  Result := Default;
  IsEncrypted := False;
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT Value, IsEncrypted FROM Settings WHERE Key = :Key';
    Query.ParamByName('Key').AsString := Key;
    Query.Open;
    
    if not Query.Eof then
    begin
      Result := Query.FieldByName('Value').AsString;
      IsEncrypted := Query.FieldByName('IsEncrypted').AsInteger = 1;
    end;
  finally
    Query.Free;
  end;
end;

procedure TUniBaseConfig.WriteToDBEncrypted(const Key, Value: string; 
  const Category: string; IsEncrypted: Boolean);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'INSERT OR REPLACE INTO Settings (Key, Value, Category, ValueType, IsEncrypted) ' +
      'VALUES (:Key, :Value, :Category, ''String'', :Encrypted)';
    Query.ParamByName('Key').AsString := Key;
    Query.ParamByName('Value').AsString := Value;
    Query.ParamByName('Category').AsString := Category;
    Query.ParamByName('Encrypted').AsInteger := Ord(IsEncrypted);
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TUniBaseConfig.EncryptValue(const Value: string): string;
var
  Bytes: TBytes;
  i: Integer;
begin
  if Value = '' then
    Exit('');
    
  Bytes := TEncoding.UTF8.GetBytes(Value);
  
  // XOR with key (cycling through key bytes)
  for i := 0 to Length(Bytes) - 1 do
    Bytes[i] := Bytes[i] xor CONFIG_ENCRYPT_KEY[i mod Length(CONFIG_ENCRYPT_KEY)];
  
  // Encode as Base64 for safe storage
  Result := TNetEncoding.Base64.EncodeBytesToString(Bytes);
end;

function TUniBaseConfig.DecryptValue(const EncryptedValue: string): string;
var
  Bytes: TBytes;
  i: Integer;
begin
  if EncryptedValue = '' then
    Exit('');
  
  try
    // Decode from Base64
    Bytes := TNetEncoding.Base64.DecodeStringToBytes(EncryptedValue);
    
    // XOR with key (same key for decrypt)
    for i := 0 to Length(Bytes) - 1 do
      Bytes[i] := Bytes[i] xor CONFIG_ENCRYPT_KEY[i mod Length(CONFIG_ENCRYPT_KEY)];
    
    Result := TEncoding.UTF8.GetString(Bytes);
  except
    // If decryption fails, return empty
    Result := '';
  end;
end;

function TUniBaseConfig.GetConfigEncrypted(const Key: string; const Default: string): string;
var
  IsEncrypted: Boolean;
  RawValue: string;
begin
  TMonitor.Enter(FLock);
  try
    RawValue := ReadFromDBEx(Key, IsEncrypted, Default);
    
    if (RawValue <> Default) and IsEncrypted then
      Result := DecryptValue(RawValue)
    else
      Result := RawValue;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseConfig.SetConfigEncrypted(const Key, Value: string; const Category: string);
var
  EncryptedValue: string;
begin
  TMonitor.Enter(FLock);
  try
    EncryptedValue := EncryptValue(Value);
    WriteToDBEncrypted(Key, EncryptedValue, Category, True);
    
    // Do NOT cache encrypted values for security
    FCache.Remove(Key);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseConfig.GetConfig(const Key: string; const Default: string): string;
begin
  TMonitor.Enter(FLock);
  try
    // Check cache first
    if FCacheEnabled and FCache.TryGetValue(Key, Result) then
      Exit;
      
    // Query database
    Result := ReadFromDB(Key, Default);
    
    // Write to cache
    if FCacheEnabled and (Result <> Default) then
      FCache.AddOrSetValue(Key, Result);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseConfig.SetConfig(const Key, Value: string; const Category: string);
var
  OldValue: string;
begin
  TMonitor.Enter(FLock);
  try
    // Get old value
    if FCacheEnabled and FCache.TryGetValue(Key, OldValue) then
      // From cache
    else
      OldValue := ReadFromDB(Key, '');
    
    // Write to database
    WriteToDB(Key, Value, Category, 'String', '');
    
    // Update cache
    if FCacheEnabled then
      FCache.AddOrSetValue(Key, Value);
      
    // Trigger event
    if (OldValue <> Value) and Assigned(FOnConfigChanged) then
      FOnConfigChanged(Self, Key, OldValue, Value);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseConfig.GetConfigInt(const Key: string; Default: Integer): Integer;
var
  StrValue: string;
begin
  StrValue := GetConfig(Key, '');
  if StrValue = '' then
    Result := Default
  else if not TryStrToInt(StrValue, Result) then
  begin
    // Type conversion failed, return default
    // TODO: Log warning after integrating logger
    Result := Default;
  end;
end;

procedure TUniBaseConfig.SetConfigInt(const Key: string; Value: Integer; const Category: string);
var
  OldValue: string;
begin
  TMonitor.Enter(FLock);
  try
    if FCacheEnabled and FCache.TryGetValue(Key, OldValue) then
      // From cache
    else
      OldValue := ReadFromDB(Key, '');
    
    WriteToDB(Key, IntToStr(Value), Category, 'Integer', '');
    
    if FCacheEnabled then
      FCache.AddOrSetValue(Key, IntToStr(Value));
      
    if (OldValue <> IntToStr(Value)) and Assigned(FOnConfigChanged) then
      FOnConfigChanged(Self, Key, OldValue, IntToStr(Value));
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseConfig.GetConfigBool(const Key: string; Default: Boolean): Boolean;
var
  StrValue: string;
begin
  StrValue := UpperCase(GetConfig(Key, ''));
  if StrValue = '' then
    Result := Default
  else if (StrValue = 'TRUE') or (StrValue = '1') or (StrValue = 'YES') then
    Result := True
  else if (StrValue = 'FALSE') or (StrValue = '0') or (StrValue = 'NO') then
    Result := False
  else
  begin
    // Type conversion failed, return default
    Result := Default;
  end;
end;

procedure TUniBaseConfig.SetConfigBool(const Key: string; Value: Boolean; const Category: string);
var
  OldValue, NewValue: string;
begin
  TMonitor.Enter(FLock);
  try
    if FCacheEnabled and FCache.TryGetValue(Key, OldValue) then
      // From cache
    else
      OldValue := ReadFromDB(Key, '');
    
    if Value then
      NewValue := 'True'
    else
      NewValue := 'False';
      
    WriteToDB(Key, NewValue, Category, 'Boolean', '');
    
    if FCacheEnabled then
      FCache.AddOrSetValue(Key, NewValue);
      
    if (OldValue <> NewValue) and Assigned(FOnConfigChanged) then
      FOnConfigChanged(Self, Key, OldValue, NewValue);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseConfig.GetConfigFloat(const Key: string; Default: Double): Double;
var
  StrValue: string;
begin
  StrValue := GetConfig(Key, '');
  if StrValue = '' then
    Result := Default
  else if not TryStrToFloat(StrValue, Result) then
  begin
    // Type conversion failed, return default
    Result := Default;
  end;
end;

procedure TUniBaseConfig.SetConfigFloat(const Key: string; Value: Double; const Category: string);
var
  OldValue, NewValue: string;
begin
  TMonitor.Enter(FLock);
  try
    if FCacheEnabled and FCache.TryGetValue(Key, OldValue) then
      // From cache
    else
      OldValue := ReadFromDB(Key, '');
    
    NewValue := FloatToStr(Value);
    WriteToDB(Key, NewValue, Category, 'Float', '');
    
    if FCacheEnabled then
      FCache.AddOrSetValue(Key, NewValue);
      
    if (OldValue <> NewValue) and Assigned(FOnConfigChanged) then
      FOnConfigChanged(Self, Key, OldValue, NewValue);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseConfig.GetConfigsByCategory(const Category: string): TDictionary<string, string>;
var
  Query: TFDQuery;
begin
  Result := TDictionary<string, string>.Create;
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT Key, Value FROM Settings WHERE Category = :Category';
      Query.ParamByName('Category').AsString := Category;
      Query.Open;
      
      while not Query.Eof do
      begin
        Result.Add(
          Query.FieldByName('Key').AsString,
          Query.FieldByName('Value').AsString
        );
        Query.Next;
      end;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseConfig.DeleteConfig(const Key: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    // Delete from cache
    FCache.Remove(Key);
    
    // Delete from database
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'DELETE FROM Settings WHERE Key = :Key';
      Query.ParamByName('Key').AsString := Key;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseConfig.ConfigExists(const Key: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  
  TMonitor.Enter(FLock);
  try
    // Check cache first
    if FCacheEnabled and FCache.ContainsKey(Key) then
    begin
      Result := True;
      Exit;
    end;
    
    // Query database
    if not Assigned(FConnection) or not FConnection.Connected then
      Exit;
      
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT 1 FROM Settings WHERE Key = :Key';
      Query.ParamByName('Key').AsString := Key;
      Query.Open;
      Result := not Query.Eof;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
