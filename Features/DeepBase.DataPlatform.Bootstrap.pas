{ ============================================================================
  DeepBase.DataPlatform.Bootstrap - Composition Root for Data Platform
  Version: 0.7
  ============================================================================ }

unit DeepBase.DataPlatform.Bootstrap;

interface

uses
  System.SysUtils, System.Generics.Collections,
  DeepBase.Interfaces,
  DeepBase.External.Types,
  DeepBase.External.Auditor,
  DeepBase.External.SQLiteReader,
  DeepBase.SchemaAdapter.Types,
  DeepBase.SchemaAdapter.Registry,
  DeepBase.SchemaAdapter.WeChat39x,
  {$IFDEF MSWINDOWS}
  DeepBase.UIA.Engine,
  {$ENDIF}
  DeepBase.ClipboardGuard,
  DeepBase.WindowMonitor;

type
  TDataPlatformServices = record
  private
    FShutdownCalled: Boolean;
  public
    WindowMonitor: IWindowMonitor;
    ClipboardGuardFactory: TFunc<IClipboardGuard>;
    Auditor: IBodyZeroAuditor;
    ExternalReader: IExternalDBReader;
    SchemaAdapterRegistry: ISchemaAdapterRegistry;
    UIAEngine: IUIAutomationEngine;
    procedure Shutdown;
  end;

  TDataPlatformBootstrap = class
  public
    class function Bootstrap: TDataPlatformServices; static;
  end;

implementation

{ TDataPlatformBootstrap }

class function TDataPlatformBootstrap.Bootstrap: TDataPlatformServices;
begin
  // Phase 0: Infrastructure (no dependencies)
  Result.WindowMonitor := TWindowMonitor.Create;
  Result.WindowMonitor.Start;

  // Phase 1: ClipboardGuard factory (no dependencies)
  Result.ClipboardGuardFactory :=
    function: IClipboardGuard
    begin
      Result := TClipboardGuard.Create;
    end;

  // Phase 2: Auditor (shared by Reader and UIA)
  Result.Auditor := TBodyZeroAuditorImpl.Create(10);

  // Phase 3: External DB Reader
  Result.ExternalReader := TExternalSQLiteReader.Create(
    WeChat39xCipherConfig, Result.Auditor);

  // Phase 4: SchemaAdapter registry
  Result.SchemaAdapterRegistry := TSchemaAdapterRegistry.Create;
  Result.SchemaAdapterRegistry.Register('3.9.0-3.9.99', TWeChat39xAdapter);

  (Result.ExternalReader as TExternalSQLiteReader).SetAdapterRegistry(
    Result.SchemaAdapterRegistry);

  // Phase 5: UIA Engine
  {$IFDEF MSWINDOWS}
  Result.UIAEngine := TUIAEngineWin32.Create(
    Result.WindowMonitor, Result.ClipboardGuardFactory, Result.Auditor);
  {$ENDIF}
end;

{ TDataPlatformServices }

procedure TDataPlatformServices.Shutdown;
begin
  if FShutdownCalled then Exit;
  FShutdownCalled := True;

  UIAEngine := nil;
  SchemaAdapterRegistry := nil;
  ExternalReader := nil;
  Auditor := nil;
  ClipboardGuardFactory := nil;
  if Assigned(WindowMonitor) then
  begin
    WindowMonitor.Stop;
    WindowMonitor := nil;
  end;
end;

end.
