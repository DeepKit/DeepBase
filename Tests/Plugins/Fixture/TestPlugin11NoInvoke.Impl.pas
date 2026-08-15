{ ============================================================================
  TestPlugin11NoInvoke.Impl — 1.1 声明 capability 但缺 invoke 导出 fixture（task#11 场景4）

  - 报 ABI major=1 / minor=1
  - metadata 声明 has_invoke capability（像 1.1 插件该有的能力）
  - Impl 自身无 Invoke 方法实现（fixture .dpr 故意不导出 dbp_invoke）
  - 验证 CAbiLoader L189：minor>=1 但缺 dbp_invoke 导出 → capability 不一致拒载
  ============================================================================ }
unit TestPlugin11NoInvoke.Impl;

interface

uses
  DeepBase.Plugins.Contracts;

function CreateNoInvokePlugin: IPluginContract; stdcall;

implementation

uses
  System.SysUtils;

type
  TNoInvokeStub = class(TInterfacedObject, IPluginContract)
  public
    function Initialize(const AConfigBytes: TBytes): Integer; stdcall;
    function Shutdown: Integer; stdcall;
    function ReloadConfig(const AConfigBytes: TBytes): Integer; stdcall;
    function GetAbiMajor: Integer; stdcall;
    function GetAbiMinor: Integer; stdcall;
    function GetMetadata(var AMetaJsonBytes: TBytes): Integer; stdcall;
    function GetHealthStatus(var AHealthJsonBytes: TBytes): Integer; stdcall;
    function IsHealthy: Boolean; stdcall;
    function GetLastError(var AMsgBytes: TBytes): Integer; stdcall;
  end;

{ TNoInvokeStub }

function TNoInvokeStub.Initialize(const AConfigBytes: TBytes): Integer;
begin
  Result := PLUGIN_OK;
end;

function TNoInvokeStub.Shutdown: Integer;
begin
  Result := PLUGIN_OK;
end;

function TNoInvokeStub.ReloadConfig(const AConfigBytes: TBytes): Integer;
begin
  Result := PLUGIN_OK;
end;

function TNoInvokeStub.GetAbiMajor: Integer;
begin
  Result := 1;
end;

function TNoInvokeStub.GetAbiMinor: Integer;
begin
  Result := 1;   { minor>=1 触发 CAbiLoader L187 invoke 导出要求 }
end;

function TNoInvokeStub.GetMetadata(var AMetaJsonBytes: TBytes): Integer;
var
  LMeta: TPluginMetadata;
begin
  LMeta := Default(TPluginMetadata);
  LMeta.Name := 'NoInvoke';
  LMeta.Version := '1.1.0-fixture';
  LMeta.PluginType := ptExperimental;
  LMeta.Description := 'ABI 1.1 declares has_invoke but lacks dbp_invoke export';
  LMeta.Author := 'DeepBase.Tests';
  LMeta.AbiMajor := 1;
  LMeta.AbiMinor := 1;
  LMeta.SupportsHotReload := False;
  LMeta.Capabilities := TArray<string>.Create('has_invoke');  { 故意声明 has_invoke }
  AMetaJsonBytes := MetadataToJsonBytes(LMeta);
  Result := PLUGIN_OK;
end;

function TNoInvokeStub.GetHealthStatus(var AHealthJsonBytes: TBytes): Integer;
var
  LHealth: TPluginHealthStatus;
begin
  LHealth := Default(TPluginHealthStatus);
  LHealth.IsHealthy := True;
  LHealth.LastCheckTime := Now;
  LHealth.UptimeSeconds := 0;
  AHealthJsonBytes := HealthToJsonBytes(LHealth);
  Result := PLUGIN_OK;
end;

function TNoInvokeStub.IsHealthy: Boolean;
begin
  Result := True;
end;

function TNoInvokeStub.GetLastError(var AMsgBytes: TBytes): Integer;
begin
  AMsgBytes := TEncoding.UTF8.GetBytes('');
  Result := PLUGIN_OK;
end;

function CreateNoInvokePlugin: IPluginContract;
begin
  Result := TNoInvokeStub.Create;
end;

end.
