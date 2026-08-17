{ ============================================================================
  TestPlugin11NoHealth.Impl — 1.1 缺 dbp_get_health 导出 fixture（task#11 场景3）

  - 报 ABI 1.1，必需导出表故意缺 dbp_get_health（触发 ResolveProc 拒载）
  - 带 invoke 语义能力（minor>=1 契约要求，避免误倒在场景4 invoke 缺失门）
  - 场景隔离：拒绝必须定位在 "缺少导出函数 dbp_get_health"，非 invoke 缺失。
  ============================================================================ }
unit TestPlugin11NoHealth.Impl;

interface

uses
  DeepBase.Plugins.Contracts;

function CreateNoHealthPlugin: IPluginContract; stdcall;

implementation

uses
  System.SysUtils;

type
  TNoHealthStub = class(TInterfacedObject, IPluginContract)
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

{ TNoHealthStub —— 注：GetHealthStatus 在此实现存在，但 .dpr/CAbi 不导出
  dbp_get_health，故宿主 ResolveProc 拿不到导出函数而拒载（场景3）。 impl
  保留完整接口以满足 IPluginContract 契约。 }

function TNoHealthStub.Initialize(const AConfigBytes: TBytes): Integer;
begin
  Result := PLUGIN_OK;
end;

function TNoHealthStub.Shutdown: Integer;
begin
  Result := PLUGIN_OK;
end;

function TNoHealthStub.ReloadConfig(const AConfigBytes: TBytes): Integer;
begin
  Result := PLUGIN_OK;
end;

function TNoHealthStub.GetAbiMajor: Integer;
begin
  Result := 1;
end;

function TNoHealthStub.GetAbiMinor: Integer;
begin
  Result := 1;
end;

function TNoHealthStub.GetMetadata(var AMetaJsonBytes: TBytes): Integer;
var
  LMeta: TPluginMetadata;
begin
  LMeta := Default(TPluginMetadata);
  LMeta.Name := 'NoHealth';
  LMeta.Version := '1.1.0-fixture';
  LMeta.PluginType := ptExperimental;
  LMeta.Description := 'ABI 1.1 fixture missing dbp_get_health export';
  LMeta.Author := 'DeepBase.Tests';
  LMeta.AbiMajor := 1;
  LMeta.AbiMinor := 1;
  LMeta.SupportsHotReload := False;
  LMeta.Capabilities := TArray<string>.Create('has_invoke');
  AMetaJsonBytes := MetadataToJsonBytes(LMeta);
  Result := PLUGIN_OK;
end;

function TNoHealthStub.GetHealthStatus(var AHealthJsonBytes: TBytes): Integer;
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

function TNoHealthStub.IsHealthy: Boolean;
begin
  Result := True;
end;

function TNoHealthStub.GetLastError(var AMsgBytes: TBytes): Integer;
begin
  AMsgBytes := TEncoding.UTF8.GetBytes('');
  Result := PLUGIN_OK;
end;

function CreateNoHealthPlugin: IPluginContract;
begin
  Result := TNoHealthStub.Create;
end;

end.
