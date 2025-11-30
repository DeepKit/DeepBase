unit uDoQryJsonParams;

interface

uses
  System.SysUtils, System.JSON, System.DateUtils;

function ParseParamsJson(const ParamsJson: string): TJSONObject;
function TryAsISODateTime(const S: string; out DT: TDateTime): Boolean;

implementation

function ParseParamsJson(const ParamsJson: string): TJSONObject;
var
  V: TJSONValue;
begin
  if ParamsJson.Trim = '' then
    Exit(TJSONObject.Create);
  V := TJSONObject.ParseJSONValue(ParamsJson);
  if (V = nil) or (not (V is TJSONObject)) then
  begin
    FreeAndNil(V);
    Result := TJSONObject.Create;
    Exit;
  end;
  Result := TJSONObject(V);
end;

function TryAsISODateTime(const S: string; out DT: TDateTime): Boolean;
begin
  Result := TryISO8601ToDate(S, DT, False);
  if not Result then
    Result := TryISO8601ToDate(S, DT, True);
end;

end.
