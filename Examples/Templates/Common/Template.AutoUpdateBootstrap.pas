{ ============================================================================
  Template.AutoUpdateBootstrap

  说明:
    涓烘ā鏉垮伐绋嬫彁渚涚粺涓€鐨勮嚜鍔ㄦ洿鏂板垵濮嬪寲鍏ュ彛銆?    默认启用 DeepBase 2026-05 鐨勭瓥鐣ュ寲闈欓粯鏇存柊缂栨帓锛?      - onExit/whenIdle staged 下载
      - 后台轮询安装窗口
      - 閫€鍑鸿Е鍙戝畨瑁呯獥鍙?  ============================================================================ }

unit Template.AutoUpdateBootstrap;

interface

uses
  System.Classes;

procedure StartTemplateAutoUpdate(AOwner: TComponent = nil);
procedure StopTemplateAutoUpdate;

implementation

uses
  System.SysUtils,
  Vcl.Forms,
  DeepBase.Manager,
  DeepBase.Updater,
  DeepBase.VCL.AutoUpdater;

var
  GAutoUpdater: TAutoUpdater = nil;

procedure StartTemplateAutoUpdate(AOwner: TComponent);
var
  OwnerComponent: TComponent;
begin
  if GAutoUpdater <> nil then
    Exit;

  if AOwner <> nil then
    OwnerComponent := AOwner
  else
    OwnerComponent := Application;

  GAutoUpdater := TAutoUpdater.Create(OwnerComponent);
  GAutoUpdater.AutoCheck := False;
  GAutoUpdater.Channel := ucStable;
  GAutoUpdater.ShowDialogOnUpdate := True;
  GAutoUpdater.EnablePolicyDrivenSilentUpdate := True;
  GAutoUpdater.SilentInstallPollIntervalMs := 30000;
  GAutoUpdater.AutoTriggerExitInstall := True;
  GAutoUpdater.SilentInstallMainExePath := '';

  // 绾﹀畾锛氫笅娓稿彲鍦?Settings 中配置App.UpdateUrl / App.Version銆?  if DeepBase.Manager.DeepBase.IsInitialized then
  begin
    GAutoUpdater.UpdateUrl := DeepBase.Manager.DeepBase.Config.GetConfig('App.UpdateUrl', '');
    GAutoUpdater.CurrentVersion := DeepBase.Manager.DeepBase.Config.GetConfig('App.Version', '0.0.0');
  end;

  // 运行时创建的组件不会触发 Loaded；手动异步触发一次检查?  TThread.ForceQueue(nil,
    procedure
    begin
      if GAutoUpdater <> nil then
        GAutoUpdater.Execute;
    end);
end;

procedure StopTemplateAutoUpdate;
begin
  FreeAndNil(GAutoUpdater);
end;

end.
