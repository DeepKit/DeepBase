unit uDoQryErrors;

interface

uses
  System.SysUtils, uDoQryTypes;

type
  EDoQryError = class(Exception)
  private
    FProcName: string;
    FSQL: string;
    FParamsJson: string;
    FDBType: TDBType;
    FCorrelationId: string;
  public
    constructor Create(const Msg, ProcName, SQL, ParamsJson: string; DBType: TDBType; const CorrelationId: string); reintroduce;
    property ProcName: string read FProcName;
    property SQL: string read FSQL;
    property ParamsJson: string read FParamsJson;
    property DBType: TDBType read FDBType;
    property CorrelationId: string read FCorrelationId;
  end;

implementation

constructor EDoQryError.Create(const Msg, ProcName, SQL, ParamsJson: string; DBType: TDBType; const CorrelationId: string);
begin
  inherited Create(Msg);
  FProcName := ProcName;
  FSQL := SQL;
  FParamsJson := ParamsJson;
  FDBType := DBType;
  FCorrelationId := CorrelationId;
end;

end.
