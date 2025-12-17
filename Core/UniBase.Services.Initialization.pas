unit UniBase.Services.Initialization;

interface

uses
  System.SysUtils, System.Classes,
  UniBase.Common;

type
  /// <summary>初始化服务接口</summary>
  IInitializationService = interface
    ['{B8F5E2A1-4C3D-4E2F-9A1B-8D7C6E5F4A3B}']
    function Initialize: Boolean;
    procedure Finalize;
    function IsInitialized: Boolean;
    function GetLastError: string;
  end;

  /// <summary>初始化服务实现</summary>
  TInitializationService = class(TInterfacedObject, IInitializationService)
  private
    FIsInitialized: Boolean;
    FLastError: string;
  public
    function Initialize: Boolean; virtual;
    procedure Finalize; virtual;
    function IsInitialized: Boolean;
    function GetLastError: string;
  end;

implementation

{ TInitializationService }

function TInitializationService.Initialize: Boolean;
begin
  Result := True;
  FIsInitialized := True;
  FLastError := '';
end;

procedure TInitializationService.Finalize;
begin
  FIsInitialized := False;
end;

function TInitializationService.IsInitialized: Boolean;
begin
  Result := FIsInitialized;
end;

function TInitializationService.GetLastError: string;
begin
  Result := FLastError;
end;

end.