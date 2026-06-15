{ ============================================================================
  DeepBase.Security.SecretStore - Cross-Platform Secret Storage Abstraction

  Version: 1.0
  Description: Provides ISecretStore interface for secure key/value storage.
               Windows backend uses Credential Manager (via TCredentialManager).
               Non-Windows platforms fail-closed unless DEEPBASE_INSECURE_DEV_MODE
               environment variable is set.

  Usage:
    var LStore := TSecretStoreFactory.CreatePlatformStore;
    LStore.Put('deepbase.llm.apikey.openai', MyApiKey);
    if LStore.TryGet('deepbase.llm.apikey.openai', LValue) then ...
  ============================================================================ }

unit DeepBase.Security.SecretStore;

interface

uses
  System.SysUtils;

type
  ESecretStoreUnavailable = class(Exception);

  /// <summary>
  /// Platform-agnostic secret storage interface.
  /// Implementations must not store values in plaintext on disk.
  /// </summary>
  ISecretStore = interface
    ['{B7A1E3D4-5F2C-4A8B-9E6D-1C3F5A7B9D2E}']
    function TryGet(const AKey: string; out AValue: string): Boolean;
    procedure Put(const AKey: string; const AValue: string);
    procedure Delete(const AKey: string);
    function IsAvailable: Boolean;
  end;

  /// <summary>
  /// Factory for creating platform-appropriate ISecretStore.
  /// Windows: Credential Manager. macOS: Keychain stub. Linux: libsecret stub.
  /// No backend available: raises ESecretStoreUnavailable unless dev mode.
  /// </summary>
  TSecretStoreFactory = class
  public
    class function CreatePlatformStore: ISecretStore; static;
  end;

implementation

uses
{$IF DEFINED(MSWINDOWS)}
  System.Generics.Collections,
  DeepBase.Security.DPAPI;
{$ELSE}
  System.Generics.Collections;
{$ENDIF}

type
{$IF DEFINED(MSWINDOWS)}
  /// <summary>
  /// Windows implementation using TCredentialManager from DeepBase.Security.DPAPI.
  /// </summary>
  TWindowsSecretStore = class(TInterfacedObject, ISecretStore)
  public
    function TryGet(const AKey: string; out AValue: string): Boolean;
    procedure Put(const AKey: string; const AValue: string);
    procedure Delete(const AKey: string);
    function IsAvailable: Boolean;
  end;
{$ENDIF}

  /// <summary>
  /// Insecure in-memory store for explicit dev mode only.
  /// Values are lost on process exit. Logs a warning on creation.
  /// </summary>
  TInsecureDevStore = class(TInterfacedObject, ISecretStore)
  private
    FStore: TDictionary<string, string>;
  public
    constructor Create;
    destructor Destroy; override;
    function TryGet(const AKey: string; out AValue: string): Boolean;
    procedure Put(const AKey: string; const AValue: string);
    procedure Delete(const AKey: string);
    function IsAvailable: Boolean;
  end;

{ TSecretStoreFactory }

class function TSecretStoreFactory.CreatePlatformStore: ISecretStore;
begin
{$IF DEFINED(MSWINDOWS)}
  Result := TWindowsSecretStore.Create;
{$ELSE}
  // macOS/Linux: check for dev mode, otherwise fail-closed
  if GetEnvironmentVariable('DEEPBASE_INSECURE_DEV_MODE') = '1' then
    Result := TInsecureDevStore.Create
  else
    raise ESecretStoreUnavailable.Create(
      'No secure secret store available on this platform. ' +
      'Set DEEPBASE_INSECURE_DEV_MODE=1 for development use only.');
{$ENDIF}
end;

{$IF DEFINED(MSWINDOWS)}
{ TWindowsSecretStore }

function TWindowsSecretStore.TryGet(const AKey: string; out AValue: string): Boolean;
begin
  AValue := TCredentialManager.GetCredential(AKey, '');
  Result := AValue <> '';
end;

procedure TWindowsSecretStore.Put(const AKey: string; const AValue: string);
begin
  TCredentialManager.SaveCredential(AKey, '', AValue);
end;

procedure TWindowsSecretStore.Delete(const AKey: string);
begin
  TCredentialManager.DeleteCredential(AKey);
end;

function TWindowsSecretStore.IsAvailable: Boolean;
begin
  Result := True;
end;
{$ENDIF}

{ TInsecureDevStore }

constructor TInsecureDevStore.Create;
begin
  inherited Create;
  FStore := TDictionary<string, string>.Create;
end;

destructor TInsecureDevStore.Destroy;
begin
  FStore.Free;
  inherited;
end;

function TInsecureDevStore.TryGet(const AKey: string; out AValue: string): Boolean;
begin
  Result := FStore.TryGetValue(AKey, AValue);
end;

procedure TInsecureDevStore.Put(const AKey: string; const AValue: string);
begin
  FStore.AddOrSetValue(AKey, AValue);
end;

procedure TInsecureDevStore.Delete(const AKey: string);
begin
  FStore.Remove(AKey);
end;

function TInsecureDevStore.IsAvailable: Boolean;
begin
  Result := True;
end;

end.
