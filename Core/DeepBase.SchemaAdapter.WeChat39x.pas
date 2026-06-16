{ ============================================================================
  DeepBase.SchemaAdapter.WeChat39x - WeChat 3.9.x Adapter
  Version: 0.7
  ============================================================================ }

unit DeepBase.SchemaAdapter.WeChat39x;

interface

uses
  System.SysUtils, System.DateUtils, System.Variants,
  DeepBase.SchemaAdapter.Types,
  DeepBase.SchemaAdapter;

type
  TWeChat39xAdapter = class(TBaseSchemaAdapter)
  protected
    function GetDirection: TDirectionMapping; override;
    function GetMessageType: TMsgTypeMapping; override;
    function GetTimestamp: TTimestampMapping; override;
  public
    constructor Create;
  end;

implementation

function UnixTimestampToDateTime(v: Variant): TDateTime;
begin
  if VarIsNull(v) or VarIsEmpty(v) then
    Result := 0
  else
    Result := TDateTime(Int64(v.AsInt64) / SecsPerDay + UnixDateDelta);
end;

constructor TWeChat39xAdapter.Create;
begin
  inherited;
  FVersion := '3.9.x';
  FVersionRange := '3.9.0-3.9.99';
  FSchemaFingerprintPrefixes := ['e4a7bXXXXX...'];

  SetLength(FFieldMappings, 10);
  FFieldMappings[0] := FieldMap('UserName', 'contact_id');
  FFieldMappings[1] := FieldMap('NickName', 'nickname');
  FFieldMappings[2] := FieldMap('Remark', 'remark');
  FFieldMappings[3] := FieldMap('Alias', 'alias');
  FFieldMappings[4] := FieldMap('LabelIDList', 'label_ids');
  FFieldMappings[5] := FieldMap('CreateTime', 'sent_at',
    function(v: Variant): Variant
    begin
      if VarIsNull(v) or VarIsEmpty(v) then
        Result := Null
      else
        Result := TDateTime(Int64(v.AsInt64) / SecsPerDay + UnixDateDelta);
    end);
  FFieldMappings[6] := FieldMap('Type', 'raw_type');
  FFieldMappings[7] := FieldMap('IsSender', 'raw_direction',
    function(v: Variant): Variant
    begin
      case v.AsInteger of
        0: Result := 'inbound';
        1: Result := 'outbound';
        else Result := 'unknown';
      end;
    end);
  FFieldMappings[8] := FieldMap('TalkerId', 'peer_id');
  FFieldMappings[9] := FieldMap('LocalID', 'source_row_ref');

  for var I := 0 to High(FFieldMappings) do
    FFieldMappings[I].ColumnIndex := I;

  FForbiddenFieldsDict.Add('StrContent', True);
  FForbiddenFieldsDict.Add('MsgSource', True);
  FForbiddenFieldsDict.Add('ImgBuf', True);
  FForbiddenFieldsDict.Add('VoiceBuf', True);
  FForbiddenFieldNames := ['StrContent', 'MsgSource', 'ImgBuf', 'VoiceBuf'];
end;

function TWeChat39xAdapter.GetDirection: TDirectionMapping;
begin
  Result := TDirectionMapping.Create;
  Result.Add(0, dInbound);
  Result.Add(1, dOutbound);
end;

function TWeChat39xAdapter.GetMessageType: TMsgTypeMapping;
begin
  Result := TMsgTypeMapping.Create;
  Result.Add(1, mtText);
  Result.Add(3, mtImage);
  Result.Add(34, mtVoice);
  Result.Add(43, mtVideo);
  Result.Add(47, mtImage);
  Result.Add(49, mtFile);
  Result.Add(10000, mtSystem);
end;

function TWeChat39xAdapter.GetTimestamp: TTimestampMapping;
begin
  Result := UnixTimestampToDateTime;
end;

end.
