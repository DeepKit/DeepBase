// AI-GENERATED
// DeepBase.Governance.Purpose.pas
// P03：目的对象 — 回答"为什么要做"

unit DeepBase.Governance.Purpose;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  /// 目的对象
  TPurpose = class
  private
    FKey: string;
    FName: string;
    FDescription: string;
    FParentKey: string;
    FStatus: string;  // Draft/Active/Deprecated/Retired
  public
    constructor Create(const AKey, AName: string;
      const ADescription: string = ''; const AParentKey: string = '');
    property Key: string read FKey;
    property Name: string read FName;
    property Description: string read FDescription;
    property ParentKey: string read FParentKey;
    property Status: string read FStatus write FStatus;
  end;

  /// 目的集合
  TPurposeSet = class
  private
    FPurposes: TObjectDictionary<string, TPurpose>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Register(APurpose: TPurpose);
    function Find(const AKey: string): TPurpose;
    function Exists(const AKey: string): Boolean;
    function GetAll: TArray<TPurpose>;
    function Count: Integer;

    /// 目的对齐检查：ActionKey 的 PurposeKey 是否已注册
    function IsAligned(const APurposeKey: string): Boolean;
  end;

implementation

{ TPurpose }

constructor TPurpose.Create(const AKey, AName, ADescription, AParentKey: string);
begin
  inherited Create;
  FKey := AKey;
  FName := AName;
  FDescription := ADescription;
  FParentKey := AParentKey;
  FStatus := 'Active';
end;

{ TPurposeSet }

constructor TPurposeSet.Create;
begin
  inherited Create;
  FPurposes := TObjectDictionary<string, TPurpose>.Create([doOwnsValues]);
end;

destructor TPurposeSet.Destroy;
begin
  FPurposes.Free;
  inherited;
end;

procedure TPurposeSet.Register(APurpose: TPurpose);
begin
  FPurposes.AddOrSetValue(APurpose.Key, APurpose);
end;

function TPurposeSet.Find(const AKey: string): TPurpose;
begin
  if not FPurposes.TryGetValue(AKey, Result) then
    Result := nil;
end;

function TPurposeSet.Exists(const AKey: string): Boolean;
begin
  Result := FPurposes.ContainsKey(AKey);
end;

function TPurposeSet.GetAll: TArray<TPurpose>;
begin
  Result := FPurposes.Values.ToArray;
end;

function TPurposeSet.Count: Integer;
begin
  Result := FPurposes.Count;
end;

function TPurposeSet.IsAligned(const APurposeKey: string): Boolean;
begin
  Result := (APurposeKey = '') or FPurposes.ContainsKey(APurposeKey);
end;

end.
