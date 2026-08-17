{ ============================================================================
  DeepBase.Plugins.Verifier - DLL 加载前完整性校验（SHA-256 白名单）

  法源：docs/77.extend.PluginHotReload §7（签名校验用例）
        docs/77a.adr.Plugin-ABI-and-Lifetime §4（校验逻辑归口 Verifier）

  安全纪律：
  - 严格模式（默认）：DLL 未注册可信 SHA-256 或哈希不匹配 -> 拒载；
  - 宽松模式（宿主显式开启，如 Assayer 过渡期）：未注册时告警放行，
    哈希不匹配仍然拒载；
  - 哈希用真实 SHA-256（RTL System.Hash.THashSHA2，无包间依赖），
    拒绝一切弱哈希/演示哈希。
  ============================================================================ }

unit DeepBase.Plugins.Verifier;

interface

uses
  System.SysUtils, System.SyncObjs, System.Generics.Collections;

type
  { DLL 签名验证失败异常（宿主必须让它穿透，不得吞掉后继续加载） }
  EPluginVerificationError = class(Exception)
  end;

  TPluginVerifyAlertEvent = procedure(const ADllPath: string;
    const AReason: string) of object;

  IPluginVerifier = interface
    ['{C4D91B0A-6E2F-4A57-9C38-20B7F5A1D6E3}']
    { 校验通过返回 True；严格模式下未注册/不匹配抛 EPluginVerificationError }
    function VerifyPlugin(const ADllPath: string): Boolean;
    procedure RegisterTrustedHash(const ADllName, AHashHex: string);
    procedure UnregisterHash(const ADllName: string);
    function GetTrustedHash(const ADllName: string): string;
    { 从 plugin_manifest.json（77 §S0 包格式）批量导入 DLL 哈希白名单 }
    procedure LoadWhitelistFromManifest(const AManifestJsonPath: string);
    procedure ClearAllTrustedHashes;
  end;

  TPluginVerifier = class(TInterfacedObject, IPluginVerifier)
  private
    FLock: TCriticalSection;
    { key = DLL 文件名（不含路径，不区分大小写），value = 小写 hex SHA-256 }
    FTrustedHashes: TDictionary<string, string>;
    FStrictMode: Boolean;
    FOnAlert: TPluginVerifyAlertEvent;
    function NormalizeName(const ADllPath: string): string;
    procedure Alert(const ADllPath, AReason: string);
  public
    constructor Create;
    destructor Destroy; override;

    function VerifyPlugin(const ADllPath: string): Boolean;
    procedure RegisterTrustedHash(const ADllName, AHashHex: string);
    procedure UnregisterHash(const ADllName: string);
    function GetTrustedHash(const ADllName: string): string;
    procedure LoadWhitelistFromManifest(const AManifestJsonPath: string);
    procedure ClearAllTrustedHashes;

    { 严格模式：未注册即拒载（默认 True）。宽松模式仅用于过渡期宿主。 }
    property StrictMode: Boolean read FStrictMode write FStrictMode;
    property OnAlert: TPluginVerifyAlertEvent
      read FOnAlert write FOnAlert;
  end;

{ 全局单例访问（宿主启动期初始化白名单，Manager 加载期调用校验） }
function PluginVerifier: IPluginVerifier;
procedure SetPluginVerifier(const AVerifier: IPluginVerifier);

implementation

uses
  System.IOUtils, System.JSON, System.Hash;

var
  GVerifierLock: TCriticalSection;
  GVerifier: IPluginVerifier;

function PluginVerifier: IPluginVerifier;
begin
  GVerifierLock.Enter;
  try
    if GVerifier = nil then
      GVerifier := TPluginVerifier.Create;
    Result := GVerifier;
  finally
    GVerifierLock.Leave;
  end;
end;

procedure SetPluginVerifier(const AVerifier: IPluginVerifier);
begin
  GVerifierLock.Enter;
  try
    GVerifier := AVerifier;
  finally
    GVerifierLock.Leave;
  end;
end;

{ TPluginVerifier }

constructor TPluginVerifier.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FTrustedHashes := TDictionary<string, string>.Create;
  FStrictMode := True;
end;

destructor TPluginVerifier.Destroy;
begin
  FTrustedHashes.Free;
  FLock.Free;
  inherited;
end;

function TPluginVerifier.NormalizeName(const ADllPath: string): string;
begin
  Result := LowerCase(ExtractFileName(ADllPath));
end;

procedure TPluginVerifier.Alert(const ADllPath, AReason: string);
begin
  if Assigned(FOnAlert) then
    FOnAlert(ADllPath, AReason);
end;

function TPluginVerifier.VerifyPlugin(const ADllPath: string): Boolean;
var
  LName, LExpectedHash, LActualHash: string;
begin
  if not FileExists(ADllPath) then
    raise EPluginVerificationError.Create('DLL 文件不存在：' + ADllPath);

  LName := NormalizeName(ADllPath);
  FLock.Enter;
  try
    LExpectedHash := '';
    FTrustedHashes.TryGetValue(LName, LExpectedHash);
  finally
    FLock.Leave;
  end;

  if LExpectedHash = '' then
  begin
    if FStrictMode then
    begin
      Alert(ADllPath, '未注册可信 SHA-256，严格模式拒载');
      raise EPluginVerificationError.Create(
        'DLL 未注册可信哈希（严格模式拒载）：' + LName);
    end;
    Alert(ADllPath, '未注册可信 SHA-256，宽松模式放行（过渡期）');
    Exit(True);
  end;

  LActualHash := LowerCase(THashSHA2.GetHashStringFromFile(ADllPath));
  if SameText(LExpectedHash, LActualHash) then
    Exit(True);

  Alert(ADllPath, Format('SHA-256 不匹配（期望 %s，实际 %s），疑似篡改',
    [LExpectedHash, LActualHash]));
  raise EPluginVerificationError.Create(
    Format('DLL 签名校验失败（SHA-256 不匹配）：%s', [ADllPath]));
end;

procedure TPluginVerifier.RegisterTrustedHash(const ADllName,
  AHashHex: string);
begin
  FLock.Enter;
  try
    FTrustedHashes.AddOrSetValue(LowerCase(ADllName), LowerCase(AHashHex));
  finally
    FLock.Leave;
  end;
end;

procedure TPluginVerifier.UnregisterHash(const ADllName: string);
begin
  FLock.Enter;
  try
    FTrustedHashes.Remove(LowerCase(ADllName));
  finally
    FLock.Leave;
  end;
end;

function TPluginVerifier.GetTrustedHash(const ADllName: string): string;
begin
  FLock.Enter;
  try
    if not FTrustedHashes.TryGetValue(LowerCase(ADllName), Result) then
      Result := '';
  finally
    FLock.Leave;
  end;
end;

procedure TPluginVerifier.LoadWhitelistFromManifest(
  const AManifestJsonPath: string);
var
  LRoot: TJSONValue;
  LPlugins: TJSONArray;
  LItem: TJSONObject;
  LName, LHash: string;
  I: Integer;
begin
  if not FileExists(AManifestJsonPath) then
    raise EPluginVerificationError.Create(
      'plugin_manifest.json 不存在：' + AManifestJsonPath);

  LRoot := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(AManifestJsonPath, TEncoding.UTF8));
  if LRoot = nil then
    raise EPluginVerificationError.Create(
      'plugin_manifest.json 解析失败：' + AManifestJsonPath);
  try
    { 格式见 77 §S0：plugins 数组，每项含 name/dll/sha256 字段 }
    if not (LRoot is TJSONObject) then
      Exit;
    if not TJSONObject(LRoot).TryGetValue<TJSONArray>('plugins', LPlugins) then
      Exit;
    for I := 0 to LPlugins.Count - 1 do
    begin
      if not (LPlugins.Items[I] is TJSONObject) then
        Continue;
      LItem := TJSONObject(LPlugins.Items[I]);
      if LItem.TryGetValue<string>('dll', LName) and
         LItem.TryGetValue<string>('sha256', LHash) then
        RegisterTrustedHash(ExtractFileName(LName), LHash);
    end;
  finally
    LRoot.Free;
  end;
end;

procedure TPluginVerifier.ClearAllTrustedHashes;
begin
  FLock.Enter;
  try
    FTrustedHashes.Clear;
  finally
    FLock.Leave;
  end;
end;

initialization
  GVerifierLock := TCriticalSection.Create;

finalization
  GVerifier := nil;
  GVerifierLock.Free;

end.
