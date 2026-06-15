{ ============================================================================
  DeepBase.SchemaAdapter.Registry - Adapter Registry
  Version: 0.7
  ============================================================================ }

unit DeepBase.SchemaAdapter.Registry;

interface

uses
  System.SysUtils, System.Generics.Collections,
  DeepBase.SchemaAdapter.Types,
  DeepBase.SchemaAdapter,
  DeepBase.Exceptions;

type
  TVersionedAdapter = record
    VersionRange: string;
    AdapterClass: TSchemaAdapterClass;
  end;

  TSchemaAdapterRegistry = class(TInterfacedObject, ISchemaAdapterRegistry)
  private
    FAdapters: TList<TVersionedAdapter>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Register(const VersionRange: string;
      const AdapterClass: TSchemaAdapterClass);
    function Resolve(const SchemaFingerprint, Version: string): ISchemaAdapter;
    function TryResolve(const SchemaFingerprint, Version: string;
      out Adapter: ISchemaAdapter): Boolean;
    function GetRegisteredVersions: TArray<string>;
    function Count: Integer;
  end;

implementation

constructor TSchemaAdapterRegistry.Create;
begin
  inherited;
  FAdapters := TList<TVersionedAdapter>.Create;
end;

destructor TSchemaAdapterRegistry.Destroy;
begin
  FAdapters.Free;
  inherited;
end;

procedure TSchemaAdapterRegistry.Register(const VersionRange: string;
  const AdapterClass: TSchemaAdapterClass);
var
  Entry: TVersionedAdapter;
begin
  Entry.VersionRange := VersionRange;
  Entry.AdapterClass := AdapterClass;
  FAdapters.Add(Entry);
end;

function TSchemaAdapterRegistry.Resolve(const SchemaFingerprint, Version: string): ISchemaAdapter;
var
  Adapter: ISchemaAdapter;
begin
  if TryResolve(SchemaFingerprint, Version, Adapter) then
    Result := Adapter
  else
    raise EUnsupportedSchemaVersion.CreateFmt(
      'No SchemaAdapter for fingerprint %s version %s', [SchemaFingerprint, Version]);
end;

function TSchemaAdapterRegistry.TryResolve(const SchemaFingerprint, Version: string;
  out Adapter: ISchemaAdapter): Boolean;
begin
  Result := False;
  Adapter := nil;
  for var Entry in FAdapters do
  begin
    var Temp := Entry.AdapterClass.Create;
    try
      for var Prefix in Temp.FSchemaFingerprintPrefixes do
        if SchemaFingerprint.StartsWith(Prefix) then
        begin
          Temp.Validate;
          Adapter := Temp;
          Temp := nil;
          Exit(True);
        end;
    finally
      Temp.Free;
    end;
  end;
end;

function TSchemaAdapterRegistry.GetRegisteredVersions: TArray<string>;
begin
  SetLength(Result, FAdapters.Count);
  for var I := 0 to FAdapters.Count - 1 do
    Result[I] := FAdapters[I].VersionRange;
end;

function TSchemaAdapterRegistry.Count: Integer;
begin
  Result := FAdapters.Count;
end;

end.
