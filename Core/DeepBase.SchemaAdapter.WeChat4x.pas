{ ============================================================================
  DeepBase.SchemaAdapter.WeChat4x - WeChat 4.x Adapter
  Version: 0.8
  ============================================================================ }

unit DeepBase.SchemaAdapter.WeChat4x;

interface

uses
  System.SysUtils, System.DateUtils, System.Variants, System.RegularExpressions,
  DeepBase.SchemaAdapter.Types,
  DeepBase.SchemaAdapter;

type
  TWeChat4xAdapter = class(TBaseSchemaAdapter)
  private
    class function TryParseDirectionFromSource(const Source: string): TDirection;
    class function TryParseIsSenderFromSource(const Source: string): Variant;
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

class function TWeChat4xAdapter.TryParseDirectionFromSource(
  const Source: string): TDirection;
begin
  if Source.IsEmpty then
    Exit(dUnknown);

  var Match := TRegEx.Match(Source, '<IsSender>(\d)</IsSender>',
    [roIgnoreCase]);
  if Match.Success then
  begin
    case Match.Groups[1].Value[1] of
      '0': Result := dInbound;
      '1': Result := dOutbound;
      else Result := dUnknown;
    end;
  end
  else
    Result := dUnknown;
end;

class function TWeChat4xAdapter.TryParseIsSenderFromSource(
  const Source: string): Variant;
begin
  var Dir := TryParseDirectionFromSource(Source);
  case Dir of
    dInbound:  Result := 'inbound';
    dOutbound: Result := 'outbound';
    else       Result := 'unknown';
  end;
end;

constructor TWeChat4xAdapter.Create;
begin
  inherited;
  FVersion := '4.x';
  FVersionRange := '4.0.0-4.99.99';

  // Schema fingerprint: column-signature-based (not table-name-based,
  // because Msg_* table names are dynamic per-contact hashes).
  // Standardized columns: local_id,server_id,local_type,sort_seq,
  //   real_sender_id,create_time,status,upload_status,download_status,
  //   server_seq,origin_source,source,message_content,compress_content,
  //   packed_info_data,WCDB_CT_message_content,WCDB_CT_source
  // Placeholder — replace with actual SHA256 prefix after probe run.
  FSchemaFingerprintPrefixes := ['4x_MSG_'];

  // 10 output fields (same target schema as 3.9.x)
  SetLength(FFieldMappings, 10);
  FFieldMappings[0] := FieldMap('local_id', 'source_row_ref');
  FFieldMappings[1] := FieldMap('server_id', 'server_id');
  FFieldMappings[2] := FieldMap('local_type', 'raw_type');
  FFieldMappings[3] := FieldMap('create_time', 'sent_at',
    function(v: Variant): Variant
    begin
      if VarIsNull(v) or VarIsEmpty(v) then
        Result := Null
      else
        Result := TDateTime(Int64(v.AsInt64) / SecsPerDay + UnixDateDelta);
    end);
  FFieldMappings[4] := FieldMap('source', 'raw_direction',
    function(v: Variant): Variant
    begin
      if VarIsNull(v) or VarIsEmpty(v) then
        Result := 'unknown'
      else
        Result := TryParseIsSenderFromSource(v.AsString);
    end);
  FFieldMappings[5] := FieldMap('message_content', 'content');
  FFieldMappings[6] := FieldMap('source', 'source_info');
  FFieldMappings[7] := FieldMap('real_sender_id', 'real_sender_id');
  FFieldMappings[8] := FieldMap('sort_seq', 'sort_seq');
  FFieldMappings[9] := FieldMap('status', 'status');

  for var I := 0 to High(FFieldMappings) do
    FFieldMappings[I].ColumnIndex := I;

  // Forbidden: compress_content, WCDB CT columns (BodyZero redline)
  FForbiddenFieldsDict.Add('compress_content', True);
  FForbiddenFieldsDict.Add('WCDB_CT_message_content', True);
  FForbiddenFieldsDict.Add('WCDB_CT_source', True);
  FForbiddenFieldNames := ['compress_content', 'WCDB_CT_message_content',
    'WCDB_CT_source'];
end;

function TWeChat4xAdapter.GetDirection: TDirectionMapping;
begin
  Result := TDirectionMapping.Create;
  Result.Add(0, dInbound);
  Result.Add(1, dOutbound);
end;

function TWeChat4xAdapter.GetMessageType: TMsgTypeMapping;
begin
  Result := TMsgTypeMapping.Create;
  // Base types
  Result.Add(1, mtText);
  Result.Add(3, mtImage);
  Result.Add(10000, mtSystem);
  // Composite types (large values) — map to unknown for now
  // These are bitmask-encoded compound types; future analysis needed
end;

function TWeChat4xAdapter.GetTimestamp: TTimestampMapping;
begin
  Result := UnixTimestampToDateTime;
end;

end.