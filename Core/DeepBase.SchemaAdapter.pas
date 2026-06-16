{ ============================================================================
  DeepBase.SchemaAdapter - Schema Adapter Core
  Version: 0.7
  ============================================================================ }

unit DeepBase.SchemaAdapter;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Variants,
  DeepBase.SchemaAdapter.Types,
  DeepBase.Exceptions,
  DeepBase.Logging;

type
  ISchemaAdapter = interface
    ['{C7D2B8E1-4F6A-4C9D-B3E2-8A1F5C7D9E3B}']
    function GetVersion: string;
    function GetVersionRange: string;
    function GetColumnCount: Integer;
    function GetColumnIndex(const TargetField: string): Integer;
    function MapRow(const RawRow: TDictionary<string, Variant>): TInternalRow;
    function MapRows(const RawRows: TArray<TDictionary<string, Variant>>): TArray<IMapResult>;
    function MapDirection(const RawDirection: Variant): TDirection;
    function MapMessageType(const RawType: Variant): TNormalizedMsgType;
    function GetMappedFields: TArray<TFieldMapping>;
    function GetUnmappedFields: TArray<string>;
    function GetForbiddenFields: TArray<string>;
    function IsCompatible: Boolean;
    function GetCompatibilityReport: string;
    function GetTimestampRule: TFunc<Variant, TDateTime>;
    procedure Validate;
  end;

  TBaseSchemaAdapter = class; // forward
  TSchemaAdapterClass = class of TBaseSchemaAdapter;

  ISchemaAdapterRegistry = interface
    ['{E2F6A8B4-3C7D-4E1F-8A9D-5B2C7E9F1A6D}']
    procedure Register(const VersionRange: string;
      const AdapterClass: TSchemaAdapterClass);
    function Resolve(const SchemaFingerprint, Version: string): ISchemaAdapter;
    function TryResolve(const SchemaFingerprint, Version: string;
      out Adapter: ISchemaAdapter): Boolean;
    function GetRegisteredVersions: TArray<string>;
    function Count: Integer;
  end;

  TBaseSchemaAdapter = class(TInterfacedObject, ISchemaAdapter)
  protected
    FVersion: string;
    FVersionRange: string;
    FFieldMappings: TArray<TFieldMapping>;
    FForbiddenFieldsDict: TDictionary<string, Boolean>;
    FForbiddenFieldNames: TArray<string>;
    FSchemaFingerprintPrefixes: TArray<string>;
    FCachedDirectionMapping: TDirectionMapping;
    FCachedMessageTypeMapping: TMsgTypeMapping;
    function GetDirection: TDirectionMapping; virtual; abstract;
    function GetMessageType: TMsgTypeMapping; virtual; abstract;
    function GetTimestamp: TTimestampMapping; virtual; abstract;
  public
    constructor Create;
    destructor Destroy; override;
    function GetVersion: string;
    function GetVersionRange: string;
    function GetColumnCount: Integer;
    function GetColumnIndex(const TargetField: string): Integer;
    function MapRow(const RawRow: TDictionary<string, Variant>): TInternalRow; virtual;
    function MapRows(const RawRows: TArray<TDictionary<string, Variant>>): TArray<IMapResult>; virtual;
    function MapDirection(const RawDirection: Variant): TDirection; virtual;
    function MapMessageType(const RawType: Variant): TNormalizedMsgType; virtual;
    function GetMappedFields: TArray<TFieldMapping>;
    function GetUnmappedFields: TArray<string>;
    function GetForbiddenFields: TArray<string>;
    function IsCompatible: Boolean; virtual;
    function GetCompatibilityReport: string; virtual;
    function GetTimestampRule: TFunc<Variant, TDateTime>;
    procedure Validate; virtual;
    function TryMatchFingerprint(const Fingerprint: string): Boolean;
  end;

implementation

constructor TBaseSchemaAdapter.Create;
begin
  inherited;
  FForbiddenFieldsDict := TDictionary<string, Boolean>.Create;
end;

destructor TBaseSchemaAdapter.Destroy;
begin
  FForbiddenFieldsDict.Free;
  inherited;
end;

function TBaseSchemaAdapter.GetVersion: string;
begin
  Result := FVersion;
end;

function TBaseSchemaAdapter.GetVersionRange: string;
begin
  Result := FVersionRange;
end;

function TBaseSchemaAdapter.GetColumnCount: Integer;
begin
  Result := Length(FFieldMappings);
end;

function TBaseSchemaAdapter.GetColumnIndex(const TargetField: string): Integer;
begin
  for var I := 0 to High(FFieldMappings) do
    if SameText(FFieldMappings[I].TargetField, TargetField) then
      Exit(I);
  Result := -1;
end;

function TBaseSchemaAdapter.MapRow(
  const RawRow: TDictionary<string, Variant>): TInternalRow;
begin
  SetLength(Result, Length(FFieldMappings));
  for var I := 0 to High(FFieldMappings) do
  begin
    var Mapping := FFieldMappings[I];
    if not RawRow.ContainsKey(Mapping.SourceField) then
    begin
      Result[I] := Null;
      Continue;
    end;
    if FForbiddenFieldsDict.ContainsKey(Mapping.SourceField) then
    begin
      Logger.WarnFmt('SchemaAdapter: forbidden field %s skipped', [Mapping.SourceField], 'SchemaAdapter');
      Result[I] := Null;
      Continue;
    end;
    var RawValue := RawRow[Mapping.SourceField];
    if Assigned(Mapping.Transform) then
    begin
      try
        Result[I] := Mapping.Transform(RawValue);
      except
        on E: Exception do
        begin
          Logger.WarnFmt('SchemaAdapter: Transform failed [%s->%s]: %s',
            [Mapping.SourceField, Mapping.TargetField, E.Message], 'SchemaAdapter');
          Result[I] := Null;
        end;
      end;
    end
    else
      Result[I] := RawValue;
  end;
end;

function TBaseSchemaAdapter.MapRows(
  const RawRows: TArray<TDictionary<string, Variant>>): TArray<IMapResult>;
begin
  SetLength(Result, Length(RawRows));
  for var I := 0 to High(RawRows) do
  begin
    try
      var Row := MapRow(RawRows[I]);
      Result[I] := TMapResult.Create(Row, True, '');
    except
      on E: Exception do
        Result[I] := TMapResult.Create(nil, False,
          Format('Row %d: %s', [I, E.Message]));
    end;
  end;
end;

function TBaseSchemaAdapter.MapDirection(const RawDirection: Variant): TDirection;
begin
  if FCachedDirectionMapping = nil then
    FCachedDirectionMapping := GetDirection;
  if not FCachedDirectionMapping.TryGetValue(RawDirection, Result) then
    Result := dUnknown;
end;

function TBaseSchemaAdapter.MapMessageType(const RawType: Variant): TNormalizedMsgType;
begin
  if FCachedMessageTypeMapping = nil then
    FCachedMessageTypeMapping := GetMessageType;
  if not FCachedMessageTypeMapping.TryGetValue(RawType, Result) then
    Result := mtUnknown;
end;

function TBaseSchemaAdapter.GetMappedFields: TArray<TFieldMapping>;
begin
  Result := FFieldMappings;
end;

function TBaseSchemaAdapter.GetUnmappedFields: TArray<string>;
begin
  SetLength(Result, 0);
end;

function TBaseSchemaAdapter.GetForbiddenFields: TArray<string>;
begin
  Result := FForbiddenFieldNames;
end;

function TBaseSchemaAdapter.IsCompatible: Boolean;
begin
  Result := True;
end;

function TBaseSchemaAdapter.GetCompatibilityReport: string;
begin
  Result := Format('SchemaAdapter %s (%s)', [FVersion, FVersionRange]);
end;

function TBaseSchemaAdapter.GetTimestampRule: TFunc<Variant, TDateTime>;
begin
  // GetTimestamp is virtual;abstract — subclasses return a TFunc<Variant,TDateTime>
  var BaseFunc := GetTimestamp;
  Result := BaseFunc;
end;

procedure TBaseSchemaAdapter.Validate;
begin
  for var Forbidden in FForbiddenFieldNames do
    for var Mapping in FFieldMappings do
      if SameText(Mapping.SourceField, Forbidden) then
        raise ESchemaAdapterValidationError.CreateFmt(
          'Forbidden field %s appears in FieldMappings', [Forbidden]);

  for var Prefix in FSchemaFingerprintPrefixes do
    if Length(Prefix) < 10 then
      raise ESchemaAdapterValidationError.Create(
        'Fingerprint prefix must be at least 10 hex characters');

  for var I := 0 to High(FFieldMappings) do
    if FFieldMappings[I].ColumnIndex <> I then
      raise ESchemaAdapterValidationError.CreateFmt(
        'ColumnIndex mismatch at position %d: expected %d, got %d',
        [I, I, FFieldMappings[I].ColumnIndex]);
end;

function TBaseSchemaAdapter.TryMatchFingerprint(const Fingerprint: string): Boolean;
begin
  for var Prefix in FSchemaFingerprintPrefixes do
    if Fingerprint.StartsWith(Prefix) then
      Exit(True);
  Result := False;
end;

end.
