{ ============================================================================
  DeepBase.UIA.Types - UIA Engine Type Definitions
  Version: 0.7
  ============================================================================ }

unit DeepBase.UIA.Types;

interface

uses
  System.SysUtils, System.Generics.Collections;

type
  TUIAElementLocator = record
    Name: string;
    AutomationId: string;
    ClassName: string;
    ControlType: Integer;
    TargetProcessName: string;
    FallbackChain: TArray<TUIAElementLocator>;
    TimeoutMs: Integer;
  end;

  TFallbackPolicy = (fpStrict, fpBestEffort);

  TUIAMapping = record
    AppName: string;
    AppVersion: string;
    VersionRange: string;
    WindowLocator: TUIAElementLocator;
    FallbackPolicy: TFallbackPolicy;
  end;

  TUIAMappingRegistry = class
  private
    FItems: TObjectDictionary<string, TObjectDictionary<string, TUIAElementLocator>>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const AppName, AppVersion: string; const Elements: TObjectDictionary<string, TUIAElementLocator>);
    function TryGetValue(const AppName, AppVersion: string; out Elements: TObjectDictionary<string, TUIAElementLocator>): Boolean;
    function Count: Integer;
  end;

implementation

constructor TUIAMappingRegistry.Create;
begin
  inherited;
  FItems := TObjectDictionary<string, TObjectDictionary<string, TUIAElementLocator>>.Create([doOwnsValues]);
end;

destructor TUIAMappingRegistry.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TUIAMappingRegistry.Add(const AppName, AppVersion: string;
  const Elements: TObjectDictionary<string, TUIAElementLocator>);
begin
  if not FItems.ContainsKey(AppName) then
    FItems.Add(AppName, TObjectDictionary<string, TUIAElementLocator>.Create([doOwnsValues]));
  FItems[AppName].AddOrSetValue(AppVersion, Elements);
end;

function TUIAMappingRegistry.TryGetValue(const AppName, AppVersion: string;
  out Elements: TObjectDictionary<string, TUIAElementLocator>): Boolean;
begin
  Elements := nil;
  if not FItems.ContainsKey(AppName) then Exit(False);
  Result := FItems[AppName].TryGetValue(AppVersion, Elements);
end;

function TUIAMappingRegistry.Count: Integer;
begin
  Result := FItems.Count;
end;

end.