{ ============================================================================
  DeepBase.SchemaAdapter.Types - Schema Adapter Type Definitions
  Version: 0.7
  ============================================================================ }

unit DeepBase.SchemaAdapter.Types;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.Variants;

type
  TFieldMapping = record
    SourceField: string;
    TargetField: string;
    ColumnIndex: Integer;
    Transform: TFunc<Variant, Variant>;
  end;

  TInternalRow = TArray<Variant>;

  TDirection = (dInbound, dOutbound, dUnknown);
  TNormalizedMsgType = (mtText, mtImage, mtFile, mtVoice, mtVideo, mtSystem, mtUnknown);

  TDirectionMapping = TDictionary<Int64, TDirection>;
  TMsgTypeMapping = TDictionary<Int64, TNormalizedMsgType>;
  TTimestampMapping = TFunc<Variant, TDateTime>;

  IMapResult = interface
    ['{D4E8F2A6-1B3C-4D7E-9F2A-6C8B4E1D5A7F}']
    function GetRow: TInternalRow;
    function IsSuccess: Boolean;
    function GetError: string;
  end;

  TMapResult = class(TInterfacedObject, IMapResult)
  private
    FRow: TInternalRow;
    FSuccess: Boolean;
    FError: string;
  public
    constructor Create(const ARow: TInternalRow; ASuccess: Boolean;
      const AError: string = '');
    function GetRow: TInternalRow;
    function IsSuccess: Boolean;
    function GetError: string;
  end;

function FieldMap(const ASource, ATarget: string;
  const ATransform: TFunc<Variant, Variant> = nil): TFieldMapping;

implementation

function FieldMap(const ASource, ATarget: string;
  const ATransform: TFunc<Variant, Variant>): TFieldMapping;
begin
  Result.SourceField := ASource;
  Result.TargetField := ATarget;
  Result.ColumnIndex := -1;
  Result.Transform := ATransform;
end;

constructor TMapResult.Create(const ARow: TInternalRow; ASuccess: Boolean;
  const AError: string);
begin
  inherited Create;
  FRow := ARow;
  FSuccess := ASuccess;
  FError := AError;
end;

function TMapResult.GetRow: TInternalRow;
begin
  Result := FRow;
end;

function TMapResult.IsSuccess: Boolean;
begin
  Result := FSuccess;
end;

function TMapResult.GetError: string;
begin
  Result := FError;
end;

end.