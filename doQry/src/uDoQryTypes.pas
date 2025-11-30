unit uDoQryTypes;

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client;

type
  TDBType = (dbPostgreSQL, dbSQLite);

  TDoQryContext = record
    Connection: TFDConnection;
    DBType: TDBType;
    TimeoutSec: Integer;
    CorrelationId: string;
  end;

  IDoQryTx = interface
    ['{C65E0523-4B7D-40B4-9CFD-2DAD3866E062}']
    procedure Commit;
    procedure Rollback;
  end;

  TQueryDef = record
    ProcName: string;
    SQLTemplate: string;
    ParamSchemaJson: string;
    TimeoutSec: Integer;
    DefaultLimit: Integer;
    AllowFullScan: Boolean;
    IdField: string; // for insert returning id
  end;

function MakeContext(Conn: TFDConnection; DBType: TDBType; TimeoutSec: Integer; const CorrId: string): TDoQryContext;

implementation

function MakeContext(Conn: TFDConnection; DBType: TDBType; TimeoutSec: Integer; const CorrId: string): TDoQryContext;
begin
  Result.Connection := Conn;
  Result.DBType := DBType;
  Result.TimeoutSec := TimeoutSec;
  Result.CorrelationId := CorrId;
end;

end.
