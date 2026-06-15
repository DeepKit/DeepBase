{ ============================================================================
  Demo.MainForm

  TDemoMainForm = class(TDeepMainForm). Demonstrates the minimal three
  override entry points: RegisterServices / RegisterCommands /
  RegisterProviders.
  ============================================================================ }

unit Demo.MainForm;

interface

uses
  System.SysUtils, System.RegularExpressions,
  System.Classes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Menus,
  DeepBase.VCL.DeepShell,
  Demo.Providers,
  Demo.Commands,
  Demo.Services;

type
  TDemoMainForm = class(TDeepMainForm)
  protected
    procedure RegisterServices; override;
    procedure RegisterCommands; override;
    procedure RegisterProviders; override;
    procedure AfterShellShown; override;
  end;

var
  DemoMainForm: TDemoMainForm;

implementation

{ TDemoMainForm }

procedure TDemoMainForm.RegisterServices;
begin
  inherited;
  // Demo project service registered on the shell registry.
  Services.RegisterService('app.project',
    TDemoProjectServiceImpl.Create as IInterface);
end;

procedure TDemoMainForm.RegisterCommands;
begin
  inherited;
  RegisterDemoCommands(Commands, Status);
end;

procedure TDemoMainForm.RegisterProviders;
begin
  inherited;
  RegisterStructureProvider(TDemoStructureProvider.Create);
  RegisterMainViewProvider(TDemoMainViewProvider.Create);
  RegisterInspectorProvider(TDemoInspectorProvider.Create);
  RegisterSettingsPageProvider(TDemoSettingsPageProvider.Create);
end;

procedure TDemoMainForm.AfterShellShown;
begin
  inherited;
  Caption := 'DeepShell Demo';

  OpenProject('demo-project', ExtractFileDir(ParamStr(0)));

  Status.SetSanitizer(
    function(const ASource, AMessage: string): string
    begin
      Result := TRegEx.Replace(AMessage,
        '(Authorization:\s*Bearer\s+)\S+', '$1***', [roIgnoreCase]);
      Result := TRegEx.Replace(Result,
        '(api[_-]?key[=:]\s*)\S+', '$1***', [roIgnoreCase]);
    end);

  Status.Info('demo.boot', 'Demo main form shown. Try View / Structure window.');
  OpenView(TShellObjectRef.Make('doc-1', 'doc', 'demo', 'Welcome.md'));
end;

end.
