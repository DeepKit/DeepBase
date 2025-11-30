{ ============================================================================
  UniBase.Security - Security Module with DPAPI Encryption
  
  Version: 0.3
  Description: Provides secure storage for sensitive data using Windows DPAPI.
               Use this module for passwords, API keys, tokens, and other secrets.
  
  Thread Safety: All public methods are thread-safe.
  
  SECURITY NOTES:
  - DPAPI uses user-scope encryption by default (current Windows user only)
  - Encrypted data cannot be decrypted on different machines or users
  - For cross-machine scenarios, use CRYPTPROTECT_LOCAL_MACHINE flag
  ============================================================================ }

unit UniBase.Security;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  UniBase.Types;

type
  /// <summary>
  /// Security manager for sensitive data using Windows DPAPI
  /// </summary>
  TUniBaseSecurity = class
  private
    FConnection: TFDConnection;
    FLock: TObject;
    
    procedure EnsureSecretsTable;
    
  public
    constructor Create(AConnection: TFDConnection; ALock: TObject);
    destructor Destroy; override;
    
    // ========================================
    // DPAPI Encryption Functions
    // ========================================
    
    /// <summary>
    /// Encrypt string using Windows DPAPI (user scope).
    /// Returns encrypted binary data.
    /// </summary>
    function ProtectString(const AText: string): TBytes;
    
    /// <summary>
    /// Decrypt binary data using Windows DPAPI.
    /// Returns decrypted string.
    /// </summary>
    function UnprotectString(const AData: TBytes): string;
    
    // ========================================
    // Secret Management
    // ========================================
    
    /// <summary>
    /// Load a secret value by name. Returns empty string if not found.
    /// The value is automatically decrypted using DPAPI.
    /// </summary>
    function LoadSecret(const AName: string): string;
    
    /// <summary>
    /// Save a secret value. The value is automatically encrypted using DPAPI.
    /// </summary>
    procedure SaveSecret(const AName, APlainValue: string; 
      const ADescription: string = '');
    
    /// <summary>
    /// Delete a secret by name.
    /// </summary>
    procedure DeleteSecret(const AName: string);
    
    /// <summary>
    /// Check if a secret exists.
    /// </summary>
    function SecretExists(const AName: string): Boolean;
    
    /// <summary>
    /// Get all secret names (without values for security).
    /// </summary>
    function GetSecretNames: TArray<string>;
  end;

// ============================================================================
// Global Shortcut Functions
// ============================================================================

/// <summary>
/// Load secret from UniBase security store.
/// Shortcut for UniBase.Security.LoadSecret().
/// </summary>
function LoadSecret(const AName: string): string;

/// <summary>
/// Save secret to UniBase security store.
/// Shortcut for UniBase.Security.SaveSecret().
/// </summary>
procedure SaveSecret(const AName, APlainValue: string; 
  const ADescription: string = '');

/// <summary>
/// Check if secret exists in UniBase security store.
/// </summary>
function SecretExists(const AName: string): Boolean;

// ============================================================================
// Low-level DPAPI Functions (for advanced usage)
// ============================================================================

/// <summary>
/// Encrypt string using Windows DPAPI (user scope).
/// </summary>
function ProtectStringDpapi(const AText: string): TBytes;

/// <summary>
/// Decrypt binary data using Windows DPAPI.
/// </summary>
function UnprotectStringDpapi(const AData: TBytes): string;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  System.NetEncoding,
  UniBase.Manager,
  UniBase.Consts;

{$IFDEF MSWINDOWS}
// ============================================================================
// Windows DPAPI Declarations
// ============================================================================

type
  PDataBlob = ^TDataBlob;
  TDataBlob = record
    cbData: DWORD;
    pbData: PByte;
  end;

function CryptProtectData(pDataIn: PDataBlob; szDataDescr: PWideChar;
  pOptionalEntropy: PDataBlob; pvReserved: Pointer;
  pPromptStruct: Pointer; dwFlags: DWORD; pDataOut: PDataBlob): BOOL; stdcall;
  external 'crypt32.dll' name 'CryptProtectData';

function CryptUnprotectData(pDataIn: PDataBlob; ppszDataDescr: PPWideChar;
  pOptionalEntropy: PDataBlob; pvReserved: Pointer;
  pPromptStruct: Pointer; dwFlags: DWORD; pDataOut: PDataBlob): BOOL; stdcall;
  external 'crypt32.dll' name 'CryptUnprotectData';

{$ENDIF}

// ============================================================================
// Global DPAPI Functions
// ============================================================================

function ProtectStringDpapi(const AText: string): TBytes;
{$IFDEF MSWINDOWS}
var
  InBlob, OutBlob: TDataBlob;
  WideText: UnicodeString;
begin
  if AText = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  
  WideText := AText; // UTF-16
  InBlob.cbData := Length(WideText) * SizeOf(WideChar);
  InBlob.pbData := PByte(PWideChar(WideText));
  
  // User-scope encryption (not using CRYPTPROTECT_LOCAL_MACHINE)
  if not CryptProtectData(@InBlob, nil, nil, nil, nil, 0, @OutBlob) then
    RaiseLastOSError;
  
  SetLength(Result, OutBlob.cbData);
  Move(OutBlob.pbData^, Result[0], OutBlob.cbData);
  LocalFree(HLOCAL(OutBlob.pbData));
end;
{$ELSE}
begin
  // Non-Windows: fallback to simple encoding (NOT SECURE!)
  // TODO: Implement cross-platform encryption
  Result := TEncoding.UTF8.GetBytes(AText);
end;
{$ENDIF}

function UnprotectStringDpapi(const AData: TBytes): string;
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
  // Non-Windows: fallback
  Result := TEncoding.UTF8.GetString(AData);
end;
{$ENDIF}

// ============================================================================
// Global Shortcut Functions
// ============================================================================

function LoadSecret(const AName: string): string;
begin
  if UniBase.Manager.UniBase.IsInitialized and 
     Assigned(UniBase.Manager.UniBase.Security) then
    Result := UniBase.Manager.UniBase.Security.LoadSecret(AName)
  else
    Result := '';
end;

procedure SaveSecret(const AName, APlainValue: string; 
  const ADescription: string);
begin
  if UniBase.Manager.UniBase.IsInitialized and 
     Assigned(UniBase.Manager.UniBase.Security) then
    UniBase.Manager.UniBase.Security.SaveSecret(AName, APlainValue, ADescription);
end;

function SecretExists(const AName: string): Boolean;
begin
  if UniBase.Manager.UniBase.IsInitialized and 
     Assigned(UniBase.Manager.UniBase.Security) then
    Result := UniBase.Manager.UniBase.Security.SecretExists(AName)
  else
    Result := False;
end;

// ============================================================================
// TUniBaseSecurity
// ============================================================================

constructor TUniBaseSecurity.Create(AConnection: TFDConnection; ALock: TObject);
begin
  inherited Create;
  FConnection := AConnection;
  FLock := ALock;
end;

destructor TUniBaseSecurity.Destroy;
begin
  inherited;
end;

procedure TUniBaseSecurity.EnsureSecretsTable;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  FConnection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS ' + STableSecrets + ' (' +
    '  Name        TEXT PRIMARY KEY,' +
    '  CipherBlob  TEXT NOT NULL,' +
    '  Description TEXT,' +
    '  CreatedAt   TEXT NOT NULL,' +
    '  UpdatedAt   TEXT NOT NULL' +
    ')'
  );
end;

function TUniBaseSecurity.ProtectString(const AText: string): TBytes;
begin
  Result := ProtectStringDpapi(AText);
end;

function TUniBaseSecurity.UnprotectString(const AData: TBytes): string;
begin
  Result := UnprotectStringDpapi(AData);
end;

function TUniBaseSecurity.LoadSecret(const AName: string): string;
var
  Query: TFDQuery;
  CipherBase64: string;
  CipherBytes: TBytes;
begin
  Result := '';
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  TMonitor.Enter(FLock);
  try
    EnsureSecretsTable;
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT CipherBlob FROM ' + STableSecrets + 
        ' WHERE Name = :Name';
      Query.ParamByName('Name').AsString := AName;
      Query.Open;
      
      if Query.Eof then
        Exit;
      
      CipherBase64 := Query.FieldByName('CipherBlob').AsString;
      if CipherBase64 = '' then
        Exit;
        
      CipherBytes := TNetEncoding.Base64.DecodeStringToBytes(CipherBase64);
      Result := UnprotectString(CipherBytes);
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseSecurity.SaveSecret(const AName, APlainValue: string;
  const ADescription: string);
var
  Query: TFDQuery;
  CipherBytes: TBytes;
  CipherBase64: string;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  TMonitor.Enter(FLock);
  try
    EnsureSecretsTable;
    
    CipherBytes := ProtectString(APlainValue);
    CipherBase64 := TNetEncoding.Base64.EncodeBytesToString(CipherBytes);
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text :=
        'INSERT OR REPLACE INTO ' + STableSecrets + 
        ' (Name, CipherBlob, Description, CreatedAt, UpdatedAt) ' +
        'VALUES (:Name, :CipherBlob, :Description, ' +
        '  COALESCE((SELECT CreatedAt FROM ' + STableSecrets + ' WHERE Name = :Name), datetime(''now'')), ' +
        '  datetime(''now''))';
      Query.ParamByName('Name').AsString := AName;
      Query.ParamByName('CipherBlob').AsString := CipherBase64;
      Query.ParamByName('Description').AsString := ADescription;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseSecurity.DeleteSecret(const AName: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'DELETE FROM ' + STableSecrets + ' WHERE Name = :Name';
      Query.ParamByName('Name').AsString := AName;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseSecurity.SecretExists(const AName: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  TMonitor.Enter(FLock);
  try
    EnsureSecretsTable;
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT 1 FROM ' + STableSecrets + ' WHERE Name = :Name';
      Query.ParamByName('Name').AsString := AName;
      Query.Open;
      Result := not Query.Eof;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseSecurity.GetSecretNames: TArray<string>;
var
  Query: TFDQuery;
  List: TList<string>;
begin
  SetLength(Result, 0);
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  TMonitor.Enter(FLock);
  try
    EnsureSecretsTable;
    
    List := TList<string>.Create;
    try
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := FConnection;
        Query.SQL.Text := 'SELECT Name FROM ' + STableSecrets + ' ORDER BY Name';
        Query.Open;
        
        while not Query.Eof do
        begin
          List.Add(Query.FieldByName('Name').AsString);
          Query.Next;
        end;
      finally
        Query.Free;
      end;
      
      Result := List.ToArray;
    finally
      List.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
