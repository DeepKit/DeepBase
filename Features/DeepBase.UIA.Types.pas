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
    FItems: TDictionary<string, TObjectDictionary<string, TUIAElementLocator>>;
  public
    constructor Create;
    destructor Destroy; override;
    function Count: Integer;
  end;

implementation

constructor TUIAMappingRegistry.Create;
begin
  inherited;
  FItems := TDictionary<string, TObjectDictionary<string, TUIAElementLocator>>.Create;
end;

destructor TUIAMappingRegistry.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TUIAMappingRegistry.Count: Integer;
begin
  Result := FItems.Count;
end;

end.
