unit uDoQry;

interface

uses
  System.SysUtils, System.Classes, System.Variants,
  FireDAC.Comp.Client, DBClient,
  uDoQryTypes;

// 初始化与上下文
procedure DoQryInit(const ProjectRoot: string);
function DoQryMakeContext(Conn: TFDConnection; DBType: TDBType; TimeoutSec: Integer; const CorrelationId: string): TDoQryContext;
function DoQryNewCorrelationId: string;

// 事务
function DoQryBeginTx(const Ctx: TDoQryContext): IDoQryTx;
procedure DoQryRunInTx(const Ctx: TDoQryContext; const Proc: TProc);

// 执行器
function DoQryExecSelect(const Proc: string; const ParamsJson: string; var Data: TClientDataSet; const Ctx: TDoQryContext): Integer;
function DoQryExecNonQuery(const Proc: string; const ParamsJson: string; const Ctx: TDoQryContext): Integer;
function DoQryExecInsertReturningId(const Proc: string; const ParamsJson: string; const Ctx: TDoQryContext): Integer;
function DoQryExecScalar(const Proc: string; const ParamsJson: string; const Ctx: TDoQryContext): Variant;
function DoQryBuildSqlPreview(const Proc: string; const ParamsJson: string; const Ctx: TDoQryContext): string;

implementation

uses
  System.Generics.Collections,
  uDoQryLogger, uDoQryErrors, uDoQryExecutor, uDoQryTxManager;

procedure DoQryInit(const ProjectRoot: string);
begin
  DoQryLoggerInit(ProjectRoot);
end;

function DoQryMakeContext(Conn: TFDConnection; DBType: TDBType; TimeoutSec: Integer; const CorrelationId: string): TDoQryContext;
begin
  Result := MakeContext(Conn, DBType, TimeoutSec, CorrelationId);
end;

function DoQryNewCorrelationId: string;
var
  G: TGUID;
begin
  CreateGUID(G);
  Result := GUIDToString(G);
end;

function DoQryBeginTx(const Ctx: TDoQryContext): IDoQryTx;
begin
  Result := StartTx(Ctx);
end;

procedure DoQryRunInTx(const Ctx: TDoQryContext; const Proc: TProc);
var
  Tx: IDoQryTx;
begin
  Tx := StartTx(Ctx);
  try
    Proc();
    Tx.Commit;
  except
    Tx.Rollback;
    raise;
  end;
end;

function DoQryExecSelect(const Proc: string; const ParamsJson: string; var Data: TClientDataSet; const Ctx: TDoQryContext): Integer;
begin
  Result := uDoQryExecutor.ExecSelect(Proc, ParamsJson, Data, Ctx);
end;

function DoQryExecNonQuery(const Proc: string; const ParamsJson: string; const Ctx: TDoQryContext): Integer;
begin
  Result := uDoQryExecutor.ExecNonQuery(Proc, ParamsJson, Ctx);
end;

function DoQryExecInsertReturningId(const Proc: string; const ParamsJson: string; const Ctx: TDoQryContext): Integer;
begin
  Result := uDoQryExecutor.ExecInsertReturningId(Proc, ParamsJson, Ctx);
end;

function DoQryExecScalar(const Proc: string; const ParamsJson: string; const Ctx: TDoQryContext): Variant;
begin
  Result := uDoQryExecutor.ExecScalar(Proc, ParamsJson, Ctx);
end;

function DoQryBuildSqlPreview(const Proc: string; const ParamsJson: string; const Ctx: TDoQryContext): string;
begin
  Result := uDoQryExecutor.BuildSqlPreview(Proc, ParamsJson, Ctx);
end;

end.
