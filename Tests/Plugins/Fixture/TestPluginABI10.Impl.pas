{ ============================================================================
  TestPluginABI10.Impl — ABI 1.0 fixture impl（task#11 A11-1/A11-2）

  极简 stub：
  - 报 ABI major=1 / minor=0（1.0 不含通用 invoke capability）
  - 不实现 invoke 语义（fixture 不导出 dbp_invoke / dbp_invoke_alloc）
  - Initialize/Shutdown/ReloadConfig/GetMetadata/GetHealth/GetLastError 全 no-op OK
  - Capabilities 声明空数组（1.0 无 capability 要求）

  仅供 CAbiLoader 门禁契约测试（场景1: 1.0 加载成功 / 场景2: 软拒绝 EMissingInvoke）。
  ============================================================================ }
unit TestPluginABI10.Impl;

interface

uses
  DeepBase.Plugins.Contracts;

function CreateAbi10Plugin: IPluginContract; stdcall;

implementation

uses
  System.SysUtils;

type
  { ABI 1.0 stub plugin — no invoke capability, minimal lifecycle OK. }
  TAbi10Stub = class(TInterfacedObject, IPluginContract)
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

{ TAbi10Stub }

function TAbi10Stub.Initialize(const AConfigBytes: TBytes): Integer;
begin
  Result := PLUGIN_OK;
end;

function TAbi10Stub.Shutdown: Integer;
begin
  Result := PLUGIN_OK;
end;

function TAbi10Stub.ReloadConfig(const AConfigBytes: TBytes): Integer;
begin
  Result := PLUGIN_OK;
end;

function TAbi10Stub.GetAbiMajor: Integer;
begin
  Result := 1;   { ABI MAJOR 1 }
end;

function TAbi10Stub.GetAbiMinor: Integer;
begin
  Result := 0;   { ABI MINOR 0 — 1.0 无 invoke capability }
end;

function TAbi10Stub.GetMetadata(var AMetaJsonBytes: TBytes): Integer;
var
  LMeta: TPluginMetadata;
begin
  LMeta := Default(TPluginMetadata);
  LMeta.Name := 'ABI10';
  LMeta.Version := '1.0.0-fixture';
  LMeta.PluginType := ptExperimental;
  LMeta.Description := 'ABI 1.0 stub fixture (no invoke capability)';
  LMeta.Author := 'DeepBase.Tests';
  LMeta.AbiMajor := 1;
  LMeta.AbiMinor := 0;
  LMeta.SupportsHotReload := False;
  LMeta.Capabilities := nil;   { 1.0 无 capability 声明 }
  AMetaJsonBytes := MetadataToJsonBytes(LMeta);
  Result := PLUGIN_OK;
end;

function TAbi10Stub.GetHealthStatus(var AHealthJsonBytes: TBytes): Integer;
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

function TAbi10Stub.IsHealthy: Boolean;
begin
  Result := True;
end;

function TAbi10Stub.GetLastError(var AMsgBytes: TBytes): Integer;
begin
  AMsgBytes := TEncoding.UTF8.GetBytes('');
  Result := PLUGIN_OK;
end;

function CreateAbi10Plugin: IPluginContract;
begin
  Result := TAbi10Stub.Create;
end;

end.
