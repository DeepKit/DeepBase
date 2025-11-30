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
    property UpdateUrl: string read FUpdateUrl write FUpdateUrl;
    property AutoCheck: Boolean read FAutoCheck write FAutoCheck default True;
  end;

implementation

{ TAutoUpdater }

constructor TAutoUpdater.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAutoCheck := True;
end;

destructor TAutoUpdater.Destroy;
begin
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
  AutoUpdate: TUniBaseAutoUpdate;
  Info: TUpdateInfo;
begin
  if not UniBase.Manager.UniBase.IsInitialized then Exit;
  
  // Use Manager's AutoUpdate module
  AutoUpdate := UniBase.Manager.UniBase.AutoUpdate;
  if AutoUpdate = nil then Exit;
  
  // Override URL if property set
  if FUpdateUrl <> '' then
    AutoUpdate.UpdateUrl := FUpdateUrl
  else
  begin
    // Use default from Manager/Config if not set
    if AutoUpdate.UpdateUrl = '' then
      AutoUpdate.UpdateUrl := UniBase.Manager.UniBase.Config.GetConfig('App.UpdateUrl', '');
  end;
  
  if AutoUpdate.UpdateUrl = '' then Exit;
  
  // Async Check
  AutoUpdate.CheckForUpdateAsync(
    procedure(Success: Boolean; UpdateInfo: TUpdateInfo)
    begin
      if Success then
      begin
        // Show Dialog
        TUpdateDialog.Execute(AutoUpdate, UpdateInfo);
      end;
    end).Start;
end;

end.
