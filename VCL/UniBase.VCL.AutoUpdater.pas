{ ============================================================================
  UniBase.VCL.AutoUpdater - 自动更新组件
  
  版本: 0.3
  说明: 非可视组件，封装 AutoUpdate 核心模块和 UI 交互
  ============================================================================ }

unit UniBase.VCL.AutoUpdater;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Dialogs,
  UniBase.Manager,
  UniBase.AutoUpdate,
  UniBase.VCL.UpdateDialog;

type
  TAutoUpdater = class(TComponent)
  private
    FUpdateUrl: string;
    FAutoCheck: Boolean;
    FAutoUpdate: TUniBaseAutoUpdate;
    FCurrentVersion: string;

    procedure CheckUpdate;
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>
    /// 手动检查更新
    /// </summary>
    procedure Execute;

  published
    /// <summary>版本信息 JSON 的 URL（通常是 version.json 的完整地址）。</summary>
    property UpdateUrl: string read FUpdateUrl write FUpdateUrl;
    /// <summary>当前应用版本号（例如 '1.0.0'）。用于与远程版本比较。</summary>
    property CurrentVersion: string read FCurrentVersion write FCurrentVersion;
    /// <summary>是否在 Loaded 时自动检查更新。</summary>
    property AutoCheck: Boolean read FAutoCheck write FAutoCheck default True;
  end;

implementation

{ TAutoUpdater }

constructor TAutoUpdater.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAutoCheck := True;
  FUpdateUrl := '';
  FCurrentVersion := '';
  FAutoUpdate := TUniBaseAutoUpdate.Create('', '');
end;

destructor TAutoUpdater.Destroy;
begin
  FAutoUpdate.Free;
  inherited;
end;

procedure TAutoUpdater.Loaded;
begin
  inherited;
  if not (csDesigning in ComponentState) and FAutoCheck then
  begin
    // Delay check slightly to let UI show up
    TThread.ForceQueue(nil, procedure
    begin
      CheckUpdate;
    end);
  end;
end;

procedure TAutoUpdater.Execute;
begin
  CheckUpdate;
end;

procedure TAutoUpdater.CheckUpdate;
var
  Info: TUpdateInfo;
begin
  // Configure URL
  if FUpdateUrl <> '' then
    FAutoUpdate.UpdateUrl := FUpdateUrl;

  // If URL is still empty, try to read from config when UniBase is available
  if (FAutoUpdate.UpdateUrl = '') and UniBase.Manager.UniBase.IsInitialized then
    FAutoUpdate.UpdateUrl := UniBase.Manager.UniBase.Config.GetConfig('App.UpdateUrl', '');

  if FAutoUpdate.UpdateUrl = '' then
    Exit;

  // Configure current version (fallback to 0.0.0)
  if FCurrentVersion <> '' then
    FAutoUpdate.CurrentVersion := FCurrentVersion
  else
    FAutoUpdate.CurrentVersion := '0.0.0';

  // Async check
  FAutoUpdate.CheckForUpdateAsync(
    procedure(Success: Boolean; UpdateInfo: TUpdateInfo)
    begin
      if Success then
      begin
        // Show dialog for this update
        TUpdateDialog.Execute(FAutoUpdate, UpdateInfo);
      end;
    end).Start;
end;

end.
