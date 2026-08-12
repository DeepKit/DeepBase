{ ============================================================================
  TestPlugin77.Impl — 77-S3 验收测试 fixture 插件（实现 IPluginContract）

  行为由 Initialize 配置 JSON 控制（字段：abi_major / abi_minor / init_fail）
  ReloadConfig 入参含 "crash" 字样时故意抛出未捕获异常
  （模拟违反"跨边界不抛异常"纪律的坏插件，验证宿主 SafeGuard 兜底）。
  ============================================================================ }
unit TestPlugin77.Impl;

interface

uses
  DeepBase.Plugins.Contracts;

{ 导出工厂：函数名遵循 Manager 的 Kind 前缀约定 Create<Name>Plugin }
function CreateEchoPlugin: IPluginContract; stdcall;
function CreateBasePlugin: IPluginContract; stdcall;
function CreateAbiBadPlugin: IPluginContract; stdcall;

implementation

uses
  System.SysUtils, System.JSON;

type
  { Echo — echo fixture with config-driven ABI/init_fail behavior }
  TEchoPlugin = class(TInterfacedObject, IPluginContract)
  private
    FAbiMajor: Integer;
    FAbiMinor: Integer;
    FInitFail: Boolean;
    FInitialized: Boolean;
    FInitCount: Integer;
  public
    constructor Create;
    { --- IPluginContract --- }
    function Initialize(const AConfigBytes: TBytes): Integer; virtual; stdcall;
    function Shutdown: Integer; stdcall;
    function ReloadConfig(const AConfigBytes: TBytes): Integer; stdcall;
    function GetAbiMajor: Integer; virtual; stdcall;
    function GetAbiMinor: Integer; stdcall;
    function GetMetadata(var AMetaJsonBytes: TBytes): Integer; stdcall;
    function GetHealthStatus(var AHealthJsonBytes: TBytes): Integer; stdcall;
    function IsHealthy: Boolean; stdcall;
    function GetLastError(var AMsgBytes: TBytes): Integer; stdcall;
  end;
  { ABI mismatch fixture: manager must reject before Initialize. }
  TAbiBadPlugin = class(TEchoPlugin)
  public
    function GetAbiMajor: Integer; override; stdcall;
  end;
  { Base — simplified fixture used by dependency-loading tests }
  TBasePlugin = class(TInterfacedObject, IPluginContract)
  private
    FInitialized: Boolean;
  public
    constructor Create;
    function Initialize(const AConfigBytes: TBytes): Integer; virtual; stdcall;
    function Shutdown: Integer; stdcall;
    function ReloadConfig(const AConfigBytes: TBytes): Integer; stdcall;
    function GetAbiMajor: Integer; virtual; stdcall;
    function GetAbiMinor: Integer; stdcall;
    function GetMetadata(var AMetaJsonBytes: TBytes): Integer; stdcall;
    function GetHealthStatus(var AHealthJsonBytes: TBytes): Integer; stdcall;
    function IsHealthy: Boolean; stdcall;
    function GetLastError(var AMsgBytes: TBytes): Integer; stdcall;
  end;
{ TEchoPlugin }

constructor TEchoPlugin.Create;
begin
  inherited Create;
  FAbiMajor := PLUGIN_ABI_MAJOR;
  FAbiMinor := PLUGIN_ABI_MINOR;
  FInitFail := False;
  FInitialized := False;
  FInitCount := 0;
end;

function TEchoPlugin.Initialize(const AConfigBytes: TBytes): Integer;
var
  LRoot: TJSONValue;
  LObj: TJSONObject;
begin
  Result := PLUGIN_OK;
  if Length(AConfigBytes) > 0 then
  begin
    LRoot := nil;
    try
      LRoot := TJSONObject.ParseJSONValue(
        TEncoding.UTF8.GetString(AConfigBytes));
      if LRoot is TJSONObject then
      begin
        LObj := TJSONObject(LRoot);
        LObj.TryGetValue<Integer>('abi_major', FAbiMajor);
        LObj.TryGetValue<Integer>('abi_minor', FAbiMinor);
        LObj.TryGetValue<Boolean>('init_fail', FInitFail);
      end;
    except
      Result := PLUGIN_INVALID_INPUT;
    end;
    LRoot.Free;
    if Result <> PLUGIN_OK then
      Exit;
  end;
  if FInitFail then
    Exit(PLUGIN_INTERNAL_ERROR);
  FInitialized := True;
  Inc(FInitCount);
end;

function TEchoPlugin.Shutdown: Integer;
begin
  FInitialized := False;
  Result := PLUGIN_OK;
end;

function TEchoPlugin.ReloadConfig(const AConfigBytes: TBytes): Integer;
var
  LText: string;
begin
  LText := TEncoding.UTF8.GetString(AConfigBytes);
  // 故意不捕获：模拟坏插件跨边界抛异常（宿主 SafeGuard 必须兜底）
  if Pos('crash', LText) > 0 then
    raise Exception.Create('fixture: simulated plugin crash on ReloadConfig');
  Result := PLUGIN_OK;
end;

function TEchoPlugin.GetAbiMajor: Integer;
begin
  Result := FAbiMajor;
end;





function TAbiBadPlugin.GetAbiMajor: Integer;
begin
  Result := PLUGIN_ABI_MAJOR + 1;
end;
function TEchoPlugin.GetAbiMinor: Integer;
begin
  Result := FAbiMinor;
end;

function TEchoPlugin.GetMetadata(var AMetaJsonBytes: TBytes): Integer;
var
  LMeta: TPluginMetadata;
begin
  LMeta := Default(TPluginMetadata);
  LMeta.Name := 'Echo';
  LMeta.Version := '1.0.0-fixture';
  LMeta.PluginType := ptExperimental;
  LMeta.Description := '77-S3 acceptance fixture plugin';
  LMeta.Author := 'DeepBase.Tests';
  LMeta.AbiMajor := FAbiMajor;
  LMeta.AbiMinor := FAbiMinor;
  LMeta.SupportsHotReload := True;
  AMetaJsonBytes := MetadataToJsonBytes(LMeta);
  Result := PLUGIN_OK;
end;

function TEchoPlugin.GetHealthStatus(var AHealthJsonBytes: TBytes): Integer;
var
  LHealth: TPluginHealthStatus;
begin
  LHealth := Default(TPluginHealthStatus);
  LHealth.IsHealthy := FInitialized;
  LHealth.LastCheckTime := Now;
  LHealth.UptimeSeconds := 0;
  AHealthJsonBytes := HealthToJsonBytes(LHealth);
  Result := PLUGIN_OK;
end;

function TEchoPlugin.IsHealthy: Boolean;
begin
  Result := FInitialized;
end;

function TEchoPlugin.GetLastError(var AMsgBytes: TBytes): Integer;
begin
  AMsgBytes := TEncoding.UTF8.GetBytes('');
  Result := PLUGIN_OK;
end;

function CreateEchoPlugin: IPluginContract;
begin
  Result := TEchoPlugin.Create;
end;

{ ============================================================================
  TBasePlugin - 简化的基础插件（仅用于依赖测试）
  ============================================================================ }
{ TBasePlugin }

constructor TBasePlugin.Create;
begin
  inherited Create;
  FInitialized := False;
end;

function TBasePlugin.Initialize(const AConfigBytes: TBytes): Integer;
begin
  FInitialized := True;
  Result := PLUGIN_OK;
end;

function TBasePlugin.Shutdown: Integer;
begin
  FInitialized := False;
  Result := PLUGIN_OK;
end;

function TBasePlugin.ReloadConfig(const AConfigBytes: TBytes): Integer;
begin
  Result := PLUGIN_OK;
end;

function TBasePlugin.GetAbiMajor: Integer;
begin
  Result := PLUGIN_ABI_MAJOR;
end;

function TBasePlugin.GetAbiMinor: Integer;
begin
  Result := PLUGIN_ABI_MINOR;
end;

function TBasePlugin.GetMetadata(var AMetaJsonBytes: TBytes): Integer;
var
  LMeta: TPluginMetadata;
begin
  LMeta := Default(TPluginMetadata);
  LMeta.Name := 'Base';
  LMeta.Version := '1.0.0-fixture';
  LMeta.PluginType := ptExperimental;
  LMeta.Description := '77-S3 base fixture for dependency test';
  LMeta.Author := 'DeepBase.Tests';
  LMeta.AbiMajor := PLUGIN_ABI_MAJOR;
  LMeta.AbiMinor := PLUGIN_ABI_MINOR;
  LMeta.SupportsHotReload := False;
  AMetaJsonBytes := MetadataToJsonBytes(LMeta);
  Result := PLUGIN_OK;
end;

function TBasePlugin.GetHealthStatus(var AHealthJsonBytes: TBytes): Integer;
var
  LHealth: TPluginHealthStatus;
begin
  LHealth := Default(TPluginHealthStatus);
  LHealth.IsHealthy := FInitialized;
  LHealth.LastCheckTime := Now;
  LHealth.ErrorMessage := '';
  LHealth.UptimeSeconds := 0;
  LHealth.RequestCount := 0;
  LHealth.ErrorCount := 0;
  AHealthJsonBytes := HealthToJsonBytes(LHealth);
  Result := PLUGIN_OK;
end;

function TBasePlugin.IsHealthy: Boolean;
begin
  Result := FInitialized;
end;

function TBasePlugin.GetLastError(var AMsgBytes: TBytes): Integer;
begin
  AMsgBytes := TEncoding.UTF8.GetBytes('');
  Result := PLUGIN_OK;
end;

function CreateAbiBadPlugin: IPluginContract;
begin
  Result := TAbiBadPlugin.Create;
end;
function CreateBasePlugin: IPluginContract;
begin
  Result := TBasePlugin.Create;
end;




end.
