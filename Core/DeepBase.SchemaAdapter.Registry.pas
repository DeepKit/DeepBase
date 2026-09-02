{ ============================================================================
  DeepBase.SchemaAdapter.Registry - Adapter Registry
  Version: 0.7
  ============================================================================ }

unit DeepBase.SchemaAdapter.Registry;

interface

uses
  System.SysUtils, System.Generics.Collections, System.SyncObjs,
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
    FLock: TCriticalSection;
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
  FLock := TCriticalSection.Create;
end;

destructor TSchemaAdapterRegistry.Destroy;
begin
  FLock.Free;
  FAdapters.Free;
  inherited;
end;

procedure TSchemaAdapterRegistry.Register(const VersionRange: string;
  const AdapterClass: TSchemaAdapterClass);
var
  Entry: TVersionedAdapter;
  Prefixes: TArray<string>;
  Prefix: string;
begin
  // Guard: skip adapters with empty or placeholder fingerprints (DATA2-017)
  var Temp := AdapterClass.Create;
  try
    Prefixes := Temp.GetSchemaFingerprintPrefixes;
    if Length(Prefixes) = 0 then
      Exit;
    for Prefix in Prefixes do
    begin
      if (Prefix = '') or TBaseSchemaAdapter.IsPlaceholderFingerprint(Prefix) then
        Exit;
    end;
  finally
    Temp.Free;
  end;

  FLock.Enter;
  try
    Entry.VersionRange := VersionRange;
    Entry.AdapterClass := AdapterClass;
    FAdapters.Add(Entry);
  finally
    FLock.Leave;
  end;
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
var
  BestLen: Integer;
  MatchLen: Integer;
  Temp: TBaseSchemaAdapter;
  Snap: TArray<TVersionedAdapter>;
begin
  Result := False;
  Adapter := nil;
  BestLen := 0;

  FLock.Enter;
  try
    Snap := FAdapters.ToArray;
  finally
    FLock.Leave;
  end;

  for var Entry in Snap do
  begin
    Temp := Entry.AdapterClass.Create;
    try
      MatchLen := Temp.GetLongestMatchingPrefixLength(SchemaFingerprint);
      if MatchLen > BestLen then
      begin
        BestLen := MatchLen;
        Temp.Validate;
        // Transfer ownership to Adapter (interfaced)
        Adapter := Temp;
        Temp := nil;
      end;
    finally
      Temp.Free;
    end;
  end;
  Result := BestLen > 0;
end;

function TSchemaAdapterRegistry.GetRegisteredVersions: TArray<string>;
var
  Snap: TArray<TVersionedAdapter>;
  I: Integer;
begin
  FLock.Enter;
  try
    Snap := FAdapters.ToArray;
  finally
    FLock.Leave;
  end;
  SetLength(Result, Length(Snap));
  for I := 0 to High(Snap) do
    Result[I] := Snap[I].VersionRange;
end;

function TSchemaAdapterRegistry.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FAdapters.Count;
  finally
    FLock.Leave;
  end;
end;

end.