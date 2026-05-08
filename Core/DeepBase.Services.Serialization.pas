{ ============================================================================
  DeepBase.Services.Serialization - Serialization Service Implementation

  Version: 1.0
  Description: Implements ISerializationService interface wrapping
               DeepBase.Serialization module functionality.
  ============================================================================ }

unit DeepBase.Services.Serialization;

interface

uses
  System.SysUtils,
  System.Classes,
  DeepBase.Services.Interfaces,
  DeepBase.Serialization;

type
  /// <summary>
  /// Implementation of ISerializationService using DeepBase.Serialization
  /// </summary>
  TSerializationServiceImpl = class(TInterfacedObject, ISerializationService)
  public
    function ObjectToJson(AObject: TObject): string;
    function ObjectFromJson(const Json: string; AClass: TClass): TObject;
    function ObjectToXml(AObject: TObject): string;
    function ObjectFromXml(const Xml: string; AClass: TClass): TObject;
    function ObjectToBytes(AObject: TObject): TBytes;
    function ObjectFromBytes(const Data: TBytes; AClass: TClass): TObject;
    function CloneObject(AObject: TObject): TObject;
  end;

implementation

{ TSerializationServiceImpl }

function TSerializationServiceImpl.ObjectToJson(AObject: TObject): string;
begin
  Result := TSerializer.ToJson(AObject);
end;

function TSerializationServiceImpl.ObjectFromJson(const Json: string;
  AClass: TClass): TObject;
begin
  Result := TSerializer.FromJson(Json, AClass);
end;

function TSerializationServiceImpl.ObjectToXml(AObject: TObject): string;
begin
  Result := TSerializer.ToXml(AObject);
end;

function TSerializationServiceImpl.ObjectFromXml(const Xml: string;
  AClass: TClass): TObject;
begin
  Result := TSerializer.FromXml(Xml, AClass);
end;

function TSerializationServiceImpl.ObjectToBytes(AObject: TObject): TBytes;
begin
  Result := TSerializer.ToBytes(AObject);
end;

function TSerializationServiceImpl.ObjectFromBytes(const Data: TBytes;
  AClass: TClass): TObject;
begin
  Result := TSerializer.FromBytes(Data, AClass);
end;

function TSerializationServiceImpl.CloneObject(AObject: TObject): TObject;
begin
  if AObject = nil then
    Exit(nil);

  Result := TSerializer.FromBytes(TSerializer.ToBytes(AObject),
    AObject.ClassType);
end;

end.
