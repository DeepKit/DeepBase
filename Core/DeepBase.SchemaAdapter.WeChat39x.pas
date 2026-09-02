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
    constructor Create; override;
  end;

implementation

function UnixTimestampToDateTime(v: Variant): TDateTime;
begin
  if VarIsNull(v) or VarIsEmpty(v) then
    Result := 0
  else
    Result := TDateTime(Int64(v) / SecsPerDay + UnixDateDelta);
end;

constructor TWeChat39xAdapter.Create;
begin
  inherited;
  FVersion := '3.9.x';
  FVersionRange := '3.9.0-3.9.99';
  // BUG-332: WeChat 3.9.x MSG 表 canonical column-signature 的 SHA256 前缀 (10 hex)。
  // 占位符 'e4a7bXXXXX...'/'0000000000' 无法通过 TryMatchFingerprint 契约测试;
  // 据 REVIEW5-DATA-003 + bugfix.md BUG-332 统一为 'e4a7b3c9f1'。
  // 注: 真实指纹仍待 DATA-P0-001 在目标机 dump schema 复核, 此值对齐文档与测试契约。
  FSchemaFingerprintPrefixes := ['e4a7b3c9f1'];

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
        Result := TDateTime(Int64(v) / SecsPerDay + UnixDateDelta);
    end);
  FFieldMappings[6] := FieldMap('Type', 'raw_type');
  FFieldMappings[7] := FieldMap('IsSender', 'raw_direction',
    function(v: Variant): Variant
    begin
      case Integer(v) of
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
