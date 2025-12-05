unit UniBase.Configuration;

{*******************************************************************************
  UniBase Configuration Management
  A comprehensive configuration system with:
  - Multiple configuration sources
  - Environment variable support
  - Hierarchical key-value store
  - Configuration layering and override
  - Hot reload capability
  - Type-safe value access
  - Change notifications
  - Sections and nested configurations
  
  Author: UniBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.JSON, System.IniFiles, System.SyncObjs, System.Rtti,
  System.IOUtils, System.TypInfo;

type
  EConfigurationException = class(Exception);

  /// <summary>Configuration change event</summary>
  TConfigChangeEvent = procedure(Sender: TObject; const AKey: string) of object;
  TConfigChangeCallback = reference to procedure(const AKey: string; const AOldValue, ANewValue: string);

  /// <summary>Configuration value with metadata</summary>
  TConfigValue = record
    Value: string;
    Source: string;
    Timestamp: TDateTime;
    
    function AsString: string;
    function AsInteger(ADefault: Integer = 0): Integer;
    function AsInt64(ADefault: Int64 = 0): Int64;
    function AsFloat(ADefault: Double = 0): Double;
    function AsBoolean(ADefault: Boolean = False): Boolean;
    function AsDateTime(ADefault: TDateTime = 0): TDateTime;
    function AsArray(const ADelimiter: string = ','): TArray<string>;
    function IsEmpty: Boolean;
  end;

  /// <summary>Configuration source interface</summary>
  IConfigurationSource = interface
    ['{A1B2C3D4-5678-9ABC-DEF0-111111111111}']
    function GetName: string;
    function Load: TDictionary<string, string>;
    function SupportsReload: Boolean;
    procedure Reload;
    property Name: string read GetName;
  end;

  /// <summary>Base configuration source</summary>
  TBaseConfigurationSource = class(TInterfacedObject, IConfigurationSource)
  protected
    FName: string;
  public
    constructor Create(const AName: string);
    function GetName: string;
    function Load: TDictionary<string, string>; virtual; abstract;
    function SupportsReload: Boolean; virtual;
    procedure Reload; virtual;
    property Name: string read GetName;
  end;

  /// <summary>Memory configuration source</summary>
  TMemoryConfigurationSource = class(TBaseConfigurationSource)
  private
    FValues: TDictionary<string, string>;
  public
    constructor Create(const AName: string = 'Memory');
    destructor Destroy; override;
    
    procedure SetValue(const AKey, AValue: string);
    procedure SetValues(const AValues: array of string); // ['key1=value1', 'key2=value2']
    procedure Clear;
    
    function Load: TDictionary<string, string>; override;
  end;

  /// <summary>Environment variable configuration source</summary>
  TEnvironmentConfigurationSource = class(TBaseConfigurationSource)
  private
    FPrefix: string;
    FStripPrefix: Boolean;
  public
    constructor Create(const APrefix: string = ''; AStripPrefix: Boolean = True);
    function Load: TDictionary<string, string>; override;
    function SupportsReload: Boolean; override;
  end;

  /// <summary>INI file configuration source</summary>
  TIniFileConfigurationSource = class(TBaseConfigurationSource)
  private
    FFilePath: string;
    FSectionDelimiter: string;
  public
    constructor Create(const AFilePath: string; const ASectionDelimiter: string = ':');
    function Load: TDictionary<string, string>; override;
    function SupportsReload: Boolean; override;
    property FilePath: string read FFilePath;
  end;

  /// <summary>JSON file configuration source</summary>
  TJsonFileConfigurationSource = class(TBaseConfigurationSource)
  private
    FFilePath: string;
    FKeyDelimiter: string;
    
    procedure FlattenJson(AJson: TJSONValue; const APrefix: string; AResult: TDictionary<string, string>);
  public
    constructor Create(const AFilePath: string; const AKeyDelimiter: string = ':');
    function Load: TDictionary<string, string>; override;
    function SupportsReload: Boolean; override;
    property FilePath: string read FFilePath;
  end;

  /// <summary>Command line arguments configuration source</summary>
  TCommandLineConfigurationSource = class(TBaseConfigurationSource)
  private
    FArgs: TArray<string>;
    FPrefix: string;
  public
    constructor Create(const APrefix: string = '--');
    function Load: TDictionary<string, string>; override;
  end;

  /// <summary>
  /// Encrypted configuration source - wraps another source and decrypts values.
  /// Values should be stored as Base64-encoded DPAPI-encrypted strings.
  /// Use ProtectStringDpapi() from UniBase.Security to encrypt values.
  /// </summary>
  TEncryptedConfigurationSource = class(TBaseConfigurationSource)
  private
    FInnerSource: IConfigurationSource;
    FEncryptedKeys: TArray<string>;  // Keys to decrypt (empty = all keys)
    FOwnsInner: Boolean;
  public
    /// <summary>
    /// Create encrypted configuration source.
    /// </summary>
    /// <param name="AInnerSource">The wrapped configuration source</param>
    /// <param name="AEncryptedKeys">Keys to decrypt (empty array = all keys)</param>
    /// <param name="AOwnsInner">Whether to free inner source on destroy</param>
    constructor Create(AInnerSource: IConfigurationSource; 
      const AEncryptedKeys: TArray<string> = nil; AOwnsInner: Boolean = False);
    destructor Destroy; override;
    
    function Load: TDictionary<string, string>; override;
    function SupportsReload: Boolean; override;
    procedure Reload; override;
    
    /// <summary>Check if a key should be decrypted</summary>
    function ShouldDecrypt(const AKey: string): Boolean;
  end;

  /// <summary>Configuration section</summary>
  IConfigurationSection = interface
    ['{B1C2D3E4-5678-9ABC-DEF0-222222222222}']
    function GetKey: string;
    function GetPath: string;
    function GetValue: string;
    procedure SetValue(const AValue: string);
    function GetSection(const AKey: string): IConfigurationSection;
    function GetChildren: TArray<IConfigurationSection>;
    function Exists: Boolean;
    
    property Key: string read GetKey;
    property Path: string read GetPath;
    property Value: string read GetValue write SetValue;
  end;

  /// <summary>Forward declaration</summary>
  TConfiguration = class;

  /// <summary>Configuration section implementation</summary>
  TConfigurationSection = class(TInterfacedObject, IConfigurationSection)
  private
    FConfig: TConfiguration;
    FPath: string;
    function GetKey: string;
    function GetPath: string;
    function GetValue: string;
    procedure SetValue(const AValue: string);
  public
    constructor Create(AConfig: TConfiguration; const APath: string);
    
    function GetSection(const AKey: string): IConfigurationSection;
    function GetChildren: TArray<IConfigurationSection>;
    function Exists: Boolean;
    
    property Key: string read GetKey;
    property Path: string read GetPath;
    property Value: string read GetValue write SetValue;
  end;

  /// <summary>Configuration builder</summary>
  TConfigurationBuilder = class
  private
    FSources: TList<IConfigurationSource>;
    FKeyDelimiter: string;
  public
    constructor Create;
    destructor Destroy; override;
    
    function AddSource(ASource: IConfigurationSource): TConfigurationBuilder;
    function AddMemory(const AValues: array of string): TConfigurationBuilder;
    function AddEnvironmentVariables(const APrefix: string = ''): TConfigurationBuilder;
    function AddIniFile(const AFilePath: string; AOptional: Boolean = False): TConfigurationBuilder;
    function AddJsonFile(const AFilePath: string; AOptional: Boolean = False): TConfigurationBuilder;
    function AddCommandLine: TConfigurationBuilder;
    function SetKeyDelimiter(const ADelimiter: string): TConfigurationBuilder;
    
    function Build: TConfiguration;
  end;

  /// <summary>Main configuration class</summary>
  TConfiguration = class
  private
    FSources: TList<IConfigurationSource>;
    FValues: TDictionary<string, TConfigValue>;
    FLock: TCriticalSection;
    FKeyDelimiter: string;
    FOnChange: TConfigChangeEvent;
    FChangeCallbacks: TList<TConfigChangeCallback>;
    FWatching: Boolean;
    FWatchThread: TThread;
    FFileTimestamps: TDictionary<string, TDateTime>;
    FCallbacksLock: TCriticalSection;
    FWatchIntervalMs: Integer;
    
    procedure LoadAllSources;
    procedure NotifyChange(const AKey: string; const AOldValue, ANewValue: string);
    procedure WatchFiles;
    function NormalizeKey(const AKey: string): string;
    function GetChildKeys(const AParentPath: string): TArray<string>;
  public
    constructor Create(ASources: TList<IConfigurationSource>; const AKeyDelimiter: string = ':');
    destructor Destroy; override;
    
    /// <summary>Get value by key</summary>
    function GetValue(const AKey: string): TConfigValue;
    function TryGetValue(const AKey: string; out AValue: TConfigValue): Boolean;
    
    /// <summary>Get typed values</summary>
    function GetString(const AKey: string; const ADefault: string = ''): string;
    function GetInteger(const AKey: string; ADefault: Integer = 0): Integer;
    function GetInt64(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetFloat(const AKey: string; ADefault: Double = 0): Double;
    function GetBoolean(const AKey: string; ADefault: Boolean = False): Boolean;
    function GetDateTime(const AKey: string; ADefault: TDateTime = 0): TDateTime;
    function GetArray(const AKey: string; const ADelimiter: string = ','): TArray<string>;
    
    /// <summary>Set value</summary>
    procedure SetValue(const AKey, AValue: string);
    
    /// <summary>Check if key exists</summary>
    function ContainsKey(const AKey: string): Boolean;
    
    /// <summary>Get section</summary>
    function GetSection(const APath: string): IConfigurationSection;
    
    /// <summary>Get all keys</summary>
    function GetAllKeys: TArray<string>;
    
    /// <summary>Reload configuration</summary>
    procedure Reload;
    
    /// <summary>Start watching for file changes</summary>
    procedure StartWatching(AIntervalMs: Integer = 1000);
    procedure StopWatching;
    
    /// <summary>Bind to object</summary>
    procedure BindTo<T: class>(AObject: T; const ASectionPath: string = '');
    
    /// <summary>Add change callback</summary>
    procedure OnChanged(ACallback: TConfigChangeCallback);
    
    /// <summary>Export to dictionary</summary>
    function ToDictionary: TDictionary<string, string>;
    
    /// <summary>Default accessor</summary>
    property Values[const AKey: string]: TConfigValue read GetValue; default;
    property KeyDelimiter: string read FKeyDelimiter;
    property OnChange: TConfigChangeEvent read FOnChange write FOnChange;
  end;

  /// <summary>Configuration options for binding</summary>
  TConfigurationOptions = record
    Prefix: string;
    CaseSensitive: Boolean;
    ThrowOnMissing: Boolean;
    
    class function Default: TConfigurationOptions; static;
  end;

  /// <summary>Static configuration helper</summary>
  TConfig = class
  private
    class var FDefault: TConfiguration;
    class var FLock: TCriticalSection;
  public
    class constructor Create;
    class destructor Destroy;
    
    /// <summary>Set default configuration</summary>
    class procedure SetDefault(AConfig: TConfiguration);
    
    /// <summary>Get default configuration</summary>
    class function Default: TConfiguration;
    
    /// <summary>Quick access methods</summary>
    class function Get(const AKey: string; const ADefault: string = ''): string;
    class function GetInt(const AKey: string; ADefault: Integer = 0): Integer;
    class function GetBool(const AKey: string; ADefault: Boolean = False): Boolean;
    class function GetFloat(const AKey: string; ADefault: Double = 0): Double;
    
    /// <summary>Create builder</summary>
    class function Builder: TConfigurationBuilder;
    
    /// <summary>Quick load from JSON file</summary>
    class function FromJsonFile(const AFilePath: string): TConfiguration;
    
    /// <summary>Quick load from INI file</summary>
    class function FromIniFile(const AFilePath: string): TConfiguration;
  end;

  /// <summary>Strongly typed configuration section</summary>
  TTypedConfiguration<T: class, constructor> = class
  private
    FConfig: TConfiguration;
    FSectionPath: string;
    FInstance: T;
    
    procedure LoadValues;
  public
    constructor Create(AConfig: TConfiguration; const ASectionPath: string = '');
    destructor Destroy; override;
    
    procedure Reload;
    function GetValue: T;
    
    property Value: T read GetValue;
  end;

implementation

uses
  System.DateUtils, System.NetEncoding, Winapi.Windows;

{ TConfigValue }

function TConfigValue.AsString: string;
begin
  Result := Value;
end;

function TConfigValue.AsInteger(ADefault: Integer): Integer;
begin
  if not TryStrToInt(Value, Result) then
    Result := ADefault;
end;

function TConfigValue.AsInt64(ADefault: Int64): Int64;
begin
  if not TryStrToInt64(Value, Result) then
    Result := ADefault;
end;

function TConfigValue.AsFloat(ADefault: Double): Double;
begin
  if not TryStrToFloat(Value, Result) then
    Result := ADefault;
end;

function TConfigValue.AsBoolean(ADefault: Boolean): Boolean;
begin
  if SameText(Value, 'true') or SameText(Value, '1') or SameText(Value, 'yes') then
    Result := True
  else if SameText(Value, 'false') or SameText(Value, '0') or SameText(Value, 'no') then
    Result := False
  else
    Result := ADefault;
end;

function TConfigValue.AsDateTime(ADefault: TDateTime): TDateTime;
begin
  if not TryStrToDateTime(Value, Result) then
    Result := ADefault;
end;

function TConfigValue.AsArray(const ADelimiter: string): TArray<string>;
begin
  if Value = '' then
    Result := nil
  else
    Result := Value.Split([ADelimiter]);
end;

function TConfigValue.IsEmpty: Boolean;
begin
  Result := Value = '';
end;

{ TBaseConfigurationSource }

constructor TBaseConfigurationSource.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

function TBaseConfigurationSource.GetName: string;
begin
  Result := FName;
end;

function TBaseConfigurationSource.SupportsReload: Boolean;
begin
  Result := False;
end;

procedure TBaseConfigurationSource.Reload;
begin
  // Default: do nothing
end;

{ TMemoryConfigurationSource }

constructor TMemoryConfigurationSource.Create(const AName: string);
begin
  inherited Create(AName);
  FValues := TDictionary<string, string>.Create;
end;

destructor TMemoryConfigurationSource.Destroy;
begin
  FValues.Free;
  inherited;
end;

procedure TMemoryConfigurationSource.SetValue(const AKey, AValue: string);
begin
  FValues.AddOrSetValue(AKey, AValue);
end;

procedure TMemoryConfigurationSource.SetValues(const AValues: array of string);
var
  LPair: string;
  LPos: Integer;
begin
  for LPair in AValues do
  begin
    LPos := Pos('=', LPair);
    if LPos > 0 then
      FValues.AddOrSetValue(
        Copy(LPair, 1, LPos - 1),
        Copy(LPair, LPos + 1, MaxInt)
      );
  end;
end;

procedure TMemoryConfigurationSource.Clear;
begin
  FValues.Clear;
end;

function TMemoryConfigurationSource.Load: TDictionary<string, string>;
var
  LPair: TPair<string, string>;
begin
  Result := TDictionary<string, string>.Create;
  for LPair in FValues do
    Result.Add(LPair.Key, LPair.Value);
end;

{ TEnvironmentConfigurationSource }

constructor TEnvironmentConfigurationSource.Create(const APrefix: string; AStripPrefix: Boolean);
begin
  inherited Create('Environment');
  FPrefix := APrefix;
  FStripPrefix := AStripPrefix;
end;

function TEnvironmentConfigurationSource.Load: TDictionary<string, string>;
var
  LEnvBlock: PChar;
  LEnvStr: PChar;
  LLine: string;
  LPos: Integer;
  LKey, LValue: string;
begin
  Result := TDictionary<string, string>.Create;
  
  LEnvBlock := GetEnvironmentStrings;
  if LEnvBlock <> nil then
  try
    LEnvStr := LEnvBlock;
    while LEnvStr^ <> #0 do
    begin
      LLine := string(LEnvStr);
      LPos := Pos('=', LLine);
      if LPos > 1 then
      begin
        LKey := Copy(LLine, 1, LPos - 1);
        LValue := Copy(LLine, LPos + 1, MaxInt);
        
        if (FPrefix = '') or LKey.StartsWith(FPrefix, True) then
        begin
          if FStripPrefix and (FPrefix <> '') then
            LKey := Copy(LKey, Length(FPrefix) + 1, MaxInt);
          
          // Replace __ with : for hierarchical keys
          LKey := StringReplace(LKey, '__', ':', [rfReplaceAll]);
          Result.AddOrSetValue(LKey, LValue);
        end;
      end;
      Inc(LEnvStr, Length(LLine) + 1);
    end;
  finally
    FreeEnvironmentStrings(LEnvBlock);
  end;
end;

function TEnvironmentConfigurationSource.SupportsReload: Boolean;
begin
  Result := True;
end;

{ TIniFileConfigurationSource }

constructor TIniFileConfigurationSource.Create(const AFilePath: string; const ASectionDelimiter: string);
begin
  inherited Create('IniFile:' + AFilePath);
  FFilePath := AFilePath;
  FSectionDelimiter := ASectionDelimiter;
end;

function TIniFileConfigurationSource.Load: TDictionary<string, string>;
var
  LIni: TIniFile;
  LSections: TStringList;
  LKeys: TStringList;
  LSection, LKey, LFullKey: string;
begin
  Result := TDictionary<string, string>.Create;
  
  if not FileExists(FFilePath) then
    Exit;
    
  LIni := TIniFile.Create(FFilePath);
  LSections := TStringList.Create;
  LKeys := TStringList.Create;
  try
    LIni.ReadSections(LSections);
    for LSection in LSections do
    begin
      LKeys.Clear;
      LIni.ReadSection(LSection, LKeys);
      for LKey in LKeys do
      begin
        if LSection = '' then
          LFullKey := LKey
        else
          LFullKey := LSection + FSectionDelimiter + LKey;
        Result.AddOrSetValue(LFullKey, LIni.ReadString(LSection, LKey, ''));
      end;
    end;
  finally
    LKeys.Free;
    LSections.Free;
    LIni.Free;
  end;
end;

function TIniFileConfigurationSource.SupportsReload: Boolean;
begin
  Result := True;
end;

{ TJsonFileConfigurationSource }

constructor TJsonFileConfigurationSource.Create(const AFilePath: string; const AKeyDelimiter: string);
begin
  inherited Create('JsonFile:' + AFilePath);
  FFilePath := AFilePath;
  FKeyDelimiter := AKeyDelimiter;
end;

procedure TJsonFileConfigurationSource.FlattenJson(AJson: TJSONValue; const APrefix: string; AResult: TDictionary<string, string>);
var
  LObj: TJSONObject;
  LArr: TJSONArray;
  I: Integer;
  LKey: string;
begin
  if AJson is TJSONObject then
  begin
    LObj := TJSONObject(AJson);
    for I := 0 to LObj.Count - 1 do
    begin
      if APrefix = '' then
        LKey := LObj.Pairs[I].JsonString.Value
      else
        LKey := APrefix + FKeyDelimiter + LObj.Pairs[I].JsonString.Value;
      
      if LObj.Pairs[I].JsonValue is TJSONObject then
        FlattenJson(LObj.Pairs[I].JsonValue, LKey, AResult)
      else if LObj.Pairs[I].JsonValue is TJSONArray then
        FlattenJson(LObj.Pairs[I].JsonValue, LKey, AResult)
      else if LObj.Pairs[I].JsonValue is TJSONNull then
        AResult.AddOrSetValue(LKey, '')
      else
        AResult.AddOrSetValue(LKey, LObj.Pairs[I].JsonValue.Value);
    end;
  end
  else if AJson is TJSONArray then
  begin
    LArr := TJSONArray(AJson);
    for I := 0 to LArr.Count - 1 do
    begin
      LKey := APrefix + FKeyDelimiter + IntToStr(I);
      if LArr.Items[I] is TJSONObject then
        FlattenJson(LArr.Items[I], LKey, AResult)
      else if LArr.Items[I] is TJSONArray then
        FlattenJson(LArr.Items[I], LKey, AResult)
      else if not (LArr.Items[I] is TJSONNull) then
        AResult.AddOrSetValue(LKey, LArr.Items[I].Value);
    end;
  end;
end;

function TJsonFileConfigurationSource.Load: TDictionary<string, string>;
var
  LContent: string;
  LJson: TJSONValue;
begin
  Result := TDictionary<string, string>.Create;
  
  if not FileExists(FFilePath) then
    Exit;
    
  LContent := TFile.ReadAllText(FFilePath, TEncoding.UTF8);
  LJson := TJSONObject.ParseJSONValue(LContent);
  if Assigned(LJson) then
  try
    FlattenJson(LJson, '', Result);
  finally
    LJson.Free;
  end;
end;

function TJsonFileConfigurationSource.SupportsReload: Boolean;
begin
  Result := True;
end;

{ TCommandLineConfigurationSource }

constructor TCommandLineConfigurationSource.Create(const APrefix: string);
begin
  inherited Create('CommandLine');
  FPrefix := APrefix;
  
  SetLength(FArgs, ParamCount);
  for var I := 1 to ParamCount do
    FArgs[I - 1] := ParamStr(I);
end;

function TCommandLineConfigurationSource.Load: TDictionary<string, string>;
var
  LArg: string;
  LArgTrimmed: string;
  LKey, LValue: string;
  LPos: Integer;
begin
  Result := TDictionary<string, string>.Create;
  
  for LArg in FArgs do
  begin
    if LArg.StartsWith(FPrefix) then
    begin
      LArgTrimmed := Copy(LArg, Length(FPrefix) + 1, MaxInt);
      LPos := Pos('=', LArgTrimmed);
      if LPos > 0 then
      begin
        LKey := Copy(LArgTrimmed, 1, LPos - 1);
        LValue := Copy(LArgTrimmed, LPos + 1, MaxInt);
      end
      else
      begin
        LKey := LArgTrimmed;
        LValue := 'true';
      end;
      Result.AddOrSetValue(LKey, LValue);
    end;
  end;
end;

{ DPAPI Helper for TEncryptedConfigurationSource }

{$IFDEF MSWINDOWS}
type
  PDataBlob = ^TDataBlob;
  TDataBlob = record
    cbData: DWORD;
    pbData: PByte;
  end;

function CryptUnprotectData(pDataIn: PDataBlob; ppszDataDescr: PPWideChar;
  pOptionalEntropy: PDataBlob; pvReserved: Pointer;
  pPromptStruct: Pointer; dwFlags: DWORD; pDataOut: PDataBlob): BOOL; stdcall;
  external 'crypt32.dll' name 'CryptUnprotectData';
{$ENDIF}

function DecryptDpapiLocal(const AData: TBytes): string;
{$IFDEF MSWINDOWS}
var
  InBlob, OutBlob: TDataBlob;
  WideText: UnicodeString;
begin
  if Length(AData) = 0 then
    Exit('');
    
  InBlob.cbData := Length(AData);
  InBlob.pbData := @AData[0];
  
  if not CryptUnprotectData(@InBlob, nil, nil, nil, nil, 0, @OutBlob) then
    RaiseLastOSError;
    
  SetString(WideText, PWideChar(OutBlob.pbData), OutBlob.cbData div SizeOf(WideChar));
  Result := WideText;
  LocalFree(HLOCAL(OutBlob.pbData));
end;
{$ELSE}
begin
  // Non-Windows fallback (not secure)
  Result := TEncoding.UTF8.GetString(AData);
end;
{$ENDIF}

{ TEncryptedConfigurationSource }

constructor TEncryptedConfigurationSource.Create(AInnerSource: IConfigurationSource;
  const AEncryptedKeys: TArray<string>; AOwnsInner: Boolean);
begin
  inherited Create('Encrypted:' + AInnerSource.Name);
  FInnerSource := AInnerSource;
  FEncryptedKeys := AEncryptedKeys;
  FOwnsInner := AOwnsInner;
end;

destructor TEncryptedConfigurationSource.Destroy;
begin
  if FOwnsInner then
    FInnerSource := nil;  // Release reference
  inherited;
end;

function TEncryptedConfigurationSource.ShouldDecrypt(const AKey: string): Boolean;
var
  LEncKey: string;
begin
  // If no specific keys defined, decrypt all
  if Length(FEncryptedKeys) = 0 then
    Exit(True);
    
  // Check if key matches any encrypted key pattern
  for LEncKey in FEncryptedKeys do
  begin
    if SameText(AKey, LEncKey) then
      Exit(True);
  end;
  Result := False;
end;

function TEncryptedConfigurationSource.Load: TDictionary<string, string>;
var
  LInnerData: TDictionary<string, string>;
  LPair: TPair<string, string>;
  LDecrypted: string;
  LCipherBytes: TBytes;
begin
  Result := TDictionary<string, string>.Create;
  LInnerData := FInnerSource.Load;
  try
    for LPair in LInnerData do
    begin
      if ShouldDecrypt(LPair.Key) and (LPair.Value <> '') then
      begin
        try
          // Decode Base64 and decrypt using DPAPI
          LCipherBytes := TNetEncoding.Base64.DecodeStringToBytes(LPair.Value);
          if Length(LCipherBytes) > 0 then
            LDecrypted := DecryptDpapiLocal(LCipherBytes)
          else
            LDecrypted := '';
          Result.AddOrSetValue(LPair.Key, LDecrypted);
        except
          // If decryption fails, use original value (might not be encrypted)
          {$IFDEF DEBUG}
          OutputDebugString(PChar('UniBase.Configuration: Failed to decrypt key: ' + LPair.Key));
          {$ENDIF}
          Result.AddOrSetValue(LPair.Key, LPair.Value);
        end;
      end
      else
        Result.AddOrSetValue(LPair.Key, LPair.Value);
    end;
  finally
    LInnerData.Free;
  end;
end;

function TEncryptedConfigurationSource.SupportsReload: Boolean;
begin
  Result := FInnerSource.SupportsReload;
end;

procedure TEncryptedConfigurationSource.Reload;
begin
  FInnerSource.Reload;
end;

{ TConfigurationSection }

constructor TConfigurationSection.Create(AConfig: TConfiguration; const APath: string);
begin
  inherited Create;
  FConfig := AConfig;
  FPath := APath;
end;

function TConfigurationSection.GetKey: string;
var
  LPos: Integer;
begin
  LPos := FPath.LastIndexOf(FConfig.KeyDelimiter);
  if LPos >= 0 then
    // LastIndexOf 返回 0-based 索引，这里需要换算成 1-based 并跳过完整分隔符
    Result := Copy(FPath, LPos + Length(FConfig.KeyDelimiter) + 1, MaxInt)
  else
    Result := FPath;
end;

function TConfigurationSection.GetPath: string;
begin
  Result := FPath;
end;

function TConfigurationSection.GetValue: string;
begin
  Result := FConfig.GetString(FPath);
end;

procedure TConfigurationSection.SetValue(const AValue: string);
begin
  FConfig.SetValue(FPath, AValue);
end;

function TConfigurationSection.GetSection(const AKey: string): IConfigurationSection;
var
  LPath: string;
begin
  if FPath = '' then
    LPath := AKey
  else
    LPath := FPath + FConfig.KeyDelimiter + AKey;
  Result := TConfigurationSection.Create(FConfig, LPath);
end;

function TConfigurationSection.GetChildren: TArray<IConfigurationSection>;
var
  LKeys: TArray<string>;
  LList: TList<IConfigurationSection>;
  LKey: string;
begin
  LKeys := FConfig.GetChildKeys(FPath);
  LList := TList<IConfigurationSection>.Create;
  try
    for LKey in LKeys do
      LList.Add(GetSection(LKey));
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TConfigurationSection.Exists: Boolean;
begin
  Result := FConfig.ContainsKey(FPath);
end;

{ TConfigurationBuilder }

constructor TConfigurationBuilder.Create;
begin
  inherited;
  FSources := TList<IConfigurationSource>.Create;
  FKeyDelimiter := ':';
end;

destructor TConfigurationBuilder.Destroy;
begin
  FSources.Free;
  inherited;
end;

function TConfigurationBuilder.AddSource(ASource: IConfigurationSource): TConfigurationBuilder;
begin
  FSources.Add(ASource);
  Result := Self;
end;

function TConfigurationBuilder.AddMemory(const AValues: array of string): TConfigurationBuilder;
var
  LSource: TMemoryConfigurationSource;
begin
  LSource := TMemoryConfigurationSource.Create;
  LSource.SetValues(AValues);
  FSources.Add(LSource);
  Result := Self;
end;

function TConfigurationBuilder.AddEnvironmentVariables(const APrefix: string): TConfigurationBuilder;
begin
  FSources.Add(TEnvironmentConfigurationSource.Create(APrefix));
  Result := Self;
end;

function TConfigurationBuilder.AddIniFile(const AFilePath: string; AOptional: Boolean): TConfigurationBuilder;
begin
  if not AOptional and not FileExists(AFilePath) then
    raise EConfigurationException.CreateFmt('Configuration file not found: %s', [AFilePath]);
  FSources.Add(TIniFileConfigurationSource.Create(AFilePath));
  Result := Self;
end;

function TConfigurationBuilder.AddJsonFile(const AFilePath: string; AOptional: Boolean): TConfigurationBuilder;
begin
  if not AOptional and not FileExists(AFilePath) then
    raise EConfigurationException.CreateFmt('Configuration file not found: %s', [AFilePath]);
  FSources.Add(TJsonFileConfigurationSource.Create(AFilePath, FKeyDelimiter));
  Result := Self;
end;

function TConfigurationBuilder.AddCommandLine: TConfigurationBuilder;
begin
  FSources.Add(TCommandLineConfigurationSource.Create);
  Result := Self;
end;

function TConfigurationBuilder.SetKeyDelimiter(const ADelimiter: string): TConfigurationBuilder;
begin
  FKeyDelimiter := ADelimiter;
  Result := Self;
end;

function TConfigurationBuilder.Build: TConfiguration;
begin
  Result := TConfiguration.Create(FSources, FKeyDelimiter);
  FSources := TList<IConfigurationSource>.Create; // Transfer ownership
end;

{ TConfiguration }

constructor TConfiguration.Create(ASources: TList<IConfigurationSource>; const AKeyDelimiter: string);
begin
  inherited Create;
  FSources := ASources;
  FValues := TDictionary<string, TConfigValue>.Create;
  FLock := TCriticalSection.Create;
  FKeyDelimiter := AKeyDelimiter;
  FChangeCallbacks := TList<TConfigChangeCallback>.Create;
  FFileTimestamps := TDictionary<string, TDateTime>.Create;
  FCallbacksLock := TCriticalSection.Create;
  FWatching := False;
  FWatchIntervalMs := 1000;
  
  LoadAllSources;
end;

destructor TConfiguration.Destroy;
begin
  StopWatching;
  FFileTimestamps.Free;
  FChangeCallbacks.Free;
  FCallbacksLock.Free;
  FLock.Free;
  FValues.Free;
  FSources.Free;
  inherited;
end;

function TConfiguration.NormalizeKey(const AKey: string): string;
begin
  Result := LowerCase(Trim(AKey));
end;

procedure TConfiguration.LoadAllSources;
var
  LSource: IConfigurationSource;
  LData: TDictionary<string, string>;
  LPair: TPair<string, string>;
  LValue: TConfigValue;
  LNormKey: string;
begin
  FLock.Enter;
  try
    FValues.Clear;
    
    for LSource in FSources do
    begin
      LData := LSource.Load;
      try
        for LPair in LData do
        begin
          LNormKey := NormalizeKey(LPair.Key);
          LValue.Value := LPair.Value;
          LValue.Source := LSource.Name;
          LValue.Timestamp := Now;
          FValues.AddOrSetValue(LNormKey, LValue);
        end;
      finally
        LData.Free;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TConfiguration.NotifyChange(const AKey: string; const AOldValue, ANewValue: string);
var
  LCallback: TConfigChangeCallback;
  LCallbacks: TArray<TConfigChangeCallback>;
begin
  // 拷贝一份回调快照，避免在回调过程中修改列表导致并发问题
  FCallbacksLock.Enter;
  try
    LCallbacks := FChangeCallbacks.ToArray;
  finally
    FCallbacksLock.Leave;
  end;

  if Assigned(FOnChange) then
    FOnChange(Self, AKey);
    
  for LCallback in LCallbacks do
    LCallback(AKey, AOldValue, ANewValue);
end;

function TConfiguration.GetValue(const AKey: string): TConfigValue;
begin
  if not TryGetValue(AKey, Result) then
  begin
    Result.Value := '';
    Result.Source := '';
    Result.Timestamp := 0;
  end;
end;

function TConfiguration.TryGetValue(const AKey: string; out AValue: TConfigValue): Boolean;
var
  LNormKey: string;
begin
  LNormKey := NormalizeKey(AKey);
  
  FLock.Enter;
  try
    Result := FValues.TryGetValue(LNormKey, AValue);
  finally
    FLock.Leave;
  end;
end;

function TConfiguration.GetString(const AKey: string; const ADefault: string): string;
var
  LValue: TConfigValue;
begin
  if TryGetValue(AKey, LValue) then
    Result := LValue.Value
  else
    Result := ADefault;
end;

function TConfiguration.GetInteger(const AKey: string; ADefault: Integer): Integer;
begin
  Result := GetValue(AKey).AsInteger(ADefault);
end;

function TConfiguration.GetInt64(const AKey: string; ADefault: Int64): Int64;
begin
  Result := GetValue(AKey).AsInt64(ADefault);
end;

function TConfiguration.GetFloat(const AKey: string; ADefault: Double): Double;
begin
  Result := GetValue(AKey).AsFloat(ADefault);
end;

function TConfiguration.GetBoolean(const AKey: string; ADefault: Boolean): Boolean;
begin
  Result := GetValue(AKey).AsBoolean(ADefault);
end;

function TConfiguration.GetDateTime(const AKey: string; ADefault: TDateTime): TDateTime;
begin
  Result := GetValue(AKey).AsDateTime(ADefault);
end;

function TConfiguration.GetArray(const AKey: string; const ADelimiter: string): TArray<string>;
begin
  Result := GetValue(AKey).AsArray(ADelimiter);
end;

procedure TConfiguration.SetValue(const AKey, AValue: string);
var
  LNormKey: string;
  LConfigValue: TConfigValue;
  LOldValue: string;
begin
  LNormKey := NormalizeKey(AKey);
  LOldValue := '';
  
  FLock.Enter;
  try
    if FValues.TryGetValue(LNormKey, LConfigValue) then
      LOldValue := LConfigValue.Value;
      
    LConfigValue.Value := AValue;
    LConfigValue.Source := 'Runtime';
    LConfigValue.Timestamp := Now;
    FValues.AddOrSetValue(LNormKey, LConfigValue);
  finally
    FLock.Leave;
  end;
  
  if LOldValue <> AValue then
    NotifyChange(AKey, LOldValue, AValue);
end;

function TConfiguration.ContainsKey(const AKey: string): Boolean;
var
  LNormKey: string;
begin
  LNormKey := NormalizeKey(AKey);
  
  FLock.Enter;
  try
    Result := FValues.ContainsKey(LNormKey);
  finally
    FLock.Leave;
  end;
end;

function TConfiguration.GetSection(const APath: string): IConfigurationSection;
begin
  Result := TConfigurationSection.Create(Self, APath);
end;

function TConfiguration.GetAllKeys: TArray<string>;
var
  LList: TList<string>;
begin
  LList := TList<string>.Create;
  try
    FLock.Enter;
    try
      for var LKey in FValues.Keys do
        LList.Add(LKey);
    finally
      FLock.Leave;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TConfiguration.GetChildKeys(const AParentPath: string): TArray<string>;
var
  LList: TList<string>;
  LPrefix: string;
  LKey, LChild: string;
  LPos: Integer;
  LSet: TDictionary<string, Boolean>;
begin
  LList := TList<string>.Create;
  LSet := TDictionary<string, Boolean>.Create;
  try
    if AParentPath = '' then
      LPrefix := ''
    else
      LPrefix := NormalizeKey(AParentPath) + LowerCase(FKeyDelimiter);
      
    FLock.Enter;
    try
      for LKey in FValues.Keys do
      begin
        if (LPrefix = '') or LKey.StartsWith(LPrefix) then
        begin
          LChild := Copy(LKey, Length(LPrefix) + 1, MaxInt);
          LPos := Pos(LowerCase(FKeyDelimiter), LChild);
          if LPos > 0 then
            LChild := Copy(LChild, 1, LPos - 1);
          
          if (LChild <> '') and not LSet.ContainsKey(LChild) then
          begin
            LSet.Add(LChild, True);
            LList.Add(LChild);
          end;
        end;
      end;
    finally
      FLock.Leave;
    end;
    Result := LList.ToArray;
  finally
    LSet.Free;
    LList.Free;
  end;
end;

procedure TConfiguration.Reload;
var
  LOldValues: TDictionary<string, string>;
  LPair: TPair<string, TConfigValue>;
  LNewValue: TConfigValue;
begin
  // Save old values for comparison
  LOldValues := TDictionary<string, string>.Create;
  try
    FLock.Enter;
    try
      for LPair in FValues do
        LOldValues.Add(LPair.Key, LPair.Value.Value);
    finally
      FLock.Leave;
    end;
    
    // Reload
    LoadAllSources;
    
    // Compare and notify
    FLock.Enter;
    try
      for LPair in FValues do
      begin
        if LOldValues.ContainsKey(LPair.Key) then
        begin
          if LOldValues[LPair.Key] <> LPair.Value.Value then
            NotifyChange(LPair.Key, LOldValues[LPair.Key], LPair.Value.Value);
        end
        else
          NotifyChange(LPair.Key, '', LPair.Value.Value);
      end;
    finally
      FLock.Leave;
    end;
  finally
    LOldValues.Free;
  end;
end;

procedure TConfiguration.WatchFiles;
begin
  // Simple polling implementation
  while FWatching do
  begin
    var LNeedReload := False;
    
    for var LSource in FSources do
    begin
      if LSource is TIniFileConfigurationSource then
      begin
        var LPath := TIniFileConfigurationSource(LSource).FilePath;
        if FileExists(LPath) then
        begin
          var LTime := TFile.GetLastWriteTime(LPath);
          var LOldTime: TDateTime;
          if FFileTimestamps.TryGetValue(LPath, LOldTime) then
          begin
            if LTime <> LOldTime then
            begin
              LNeedReload := True;
              FFileTimestamps[LPath] := LTime;
            end;
          end
          else
            FFileTimestamps.Add(LPath, LTime);
        end;
      end
      else if LSource is TJsonFileConfigurationSource then
      begin
        var LPath := TJsonFileConfigurationSource(LSource).FilePath;
        if FileExists(LPath) then
        begin
          var LTime := TFile.GetLastWriteTime(LPath);
          var LOldTime: TDateTime;
          if FFileTimestamps.TryGetValue(LPath, LOldTime) then
          begin
            if LTime <> LOldTime then
            begin
              LNeedReload := True;
              FFileTimestamps[LPath] := LTime;
            end;
          end
          else
            FFileTimestamps.Add(LPath, LTime);
        end;
      end;
    end;
    
    if LNeedReload then
      TThread.Synchronize(nil, Reload);
      
    if FWatchIntervalMs <= 0 then
      Sleep(1000)
    else
      Sleep(FWatchIntervalMs);
  end;
end;

procedure TConfiguration.StartWatching(AIntervalMs: Integer);
begin
  if FWatching then
    Exit;

  // 防止过于频繁地轮询配置文件，设置一个合理下限
  if AIntervalMs < 100 then
    FWatchIntervalMs := 100
  else
    FWatchIntervalMs := AIntervalMs;
    
  FWatching := True;
  FWatchThread := TThread.CreateAnonymousThread(WatchFiles);
  FWatchThread.FreeOnTerminate := False;
  FWatchThread.Start;
end;

procedure TConfiguration.StopWatching;
begin
  if not FWatching then
    Exit;
    
  FWatching := False;
  if Assigned(FWatchThread) then
  begin
    FWatchThread.WaitFor;
    FreeAndNil(FWatchThread);
  end;
end;

procedure TConfiguration.BindTo<T>(AObject: T; const ASectionPath: string);
var
  LCtx: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LKey: string;
  LValue: TConfigValue;
begin
  LCtx := TRttiContext.Create;
  try
    LType := LCtx.GetType(TObject(AObject).ClassType);
    for LProp in LType.GetProperties do
    begin
      if LProp.IsWritable then
      begin
        if ASectionPath = '' then
          LKey := LProp.Name
        else
          LKey := ASectionPath + FKeyDelimiter + LProp.Name;
          
        if TryGetValue(LKey, LValue) then
        begin
          case LProp.PropertyType.TypeKind of
            tkInteger:
              LProp.SetValue(TObject(AObject), LValue.AsInteger);
            tkInt64:
              LProp.SetValue(TObject(AObject), LValue.AsInt64);
            tkFloat:
              LProp.SetValue(TObject(AObject), LValue.AsFloat);
            tkString, tkLString, tkWString, tkUString:
              LProp.SetValue(TObject(AObject), LValue.AsString);
            tkEnumeration:
              if LProp.PropertyType.Handle = TypeInfo(Boolean) then
                LProp.SetValue(TObject(AObject), LValue.AsBoolean);
          end;
        end;
      end;
    end;
  finally
    LCtx.Free;
  end;
end;

procedure TConfiguration.OnChanged(ACallback: TConfigChangeCallback);
begin
  FCallbacksLock.Enter;
  try
    FChangeCallbacks.Add(ACallback);
  finally
    FCallbacksLock.Leave;
  end;
end;

function TConfiguration.ToDictionary: TDictionary<string, string>;
var
  LPair: TPair<string, TConfigValue>;
begin
  Result := TDictionary<string, string>.Create;
  FLock.Enter;
  try
    for LPair in FValues do
      Result.Add(LPair.Key, LPair.Value.Value);
  finally
    FLock.Leave;
  end;
end;

{ TConfigurationOptions }

class function TConfigurationOptions.Default: TConfigurationOptions;
begin
  Result.Prefix := '';
  Result.CaseSensitive := False;
  Result.ThrowOnMissing := False;
end;

{ TConfig }

class constructor TConfig.Create;
begin
  FLock := TCriticalSection.Create;
end;

class destructor TConfig.Destroy;
begin
  FreeAndNil(FDefault);
  FreeAndNil(FLock);
end;

class procedure TConfig.SetDefault(AConfig: TConfiguration);
begin
  FLock.Enter;
  try
    FreeAndNil(FDefault);
    FDefault := AConfig;
  finally
    FLock.Leave;
  end;
end;

class function TConfig.Default: TConfiguration;
begin
  FLock.Enter;
  try
    Result := FDefault;
  finally
    FLock.Leave;
  end;
end;

class function TConfig.Get(const AKey: string; const ADefault: string): string;
begin
  if Assigned(FDefault) then
    Result := FDefault.GetString(AKey, ADefault)
  else
    Result := ADefault;
end;

class function TConfig.GetInt(const AKey: string; ADefault: Integer): Integer;
begin
  if Assigned(FDefault) then
    Result := FDefault.GetInteger(AKey, ADefault)
  else
    Result := ADefault;
end;

class function TConfig.GetBool(const AKey: string; ADefault: Boolean): Boolean;
begin
  if Assigned(FDefault) then
    Result := FDefault.GetBoolean(AKey, ADefault)
  else
    Result := ADefault;
end;

class function TConfig.GetFloat(const AKey: string; ADefault: Double): Double;
begin
  if Assigned(FDefault) then
    Result := FDefault.GetFloat(AKey, ADefault)
  else
    Result := ADefault;
end;

class function TConfig.Builder: TConfigurationBuilder;
begin
  Result := TConfigurationBuilder.Create;
end;

class function TConfig.FromJsonFile(const AFilePath: string): TConfiguration;
begin
  Result := TConfigurationBuilder.Create
    .AddJsonFile(AFilePath)
    .Build;
end;

class function TConfig.FromIniFile(const AFilePath: string): TConfiguration;
begin
  Result := TConfigurationBuilder.Create
    .AddIniFile(AFilePath)
    .Build;
end;

{ TTypedConfiguration<T> }

constructor TTypedConfiguration<T>.Create(AConfig: TConfiguration; const ASectionPath: string);
begin
  inherited Create;
  FConfig := AConfig;
  FSectionPath := ASectionPath;
  FInstance := T.Create;
  LoadValues;
end;

destructor TTypedConfiguration<T>.Destroy;
begin
  FInstance.Free;
  inherited;
end;

procedure TTypedConfiguration<T>.LoadValues;
begin
  FConfig.BindTo<T>(FInstance, FSectionPath);
end;

procedure TTypedConfiguration<T>.Reload;
begin
  LoadValues;
end;

function TTypedConfiguration<T>.GetValue: T;
begin
  Result := FInstance;
end;

end.
