unit uDoQryTxManager;

interface

uses
  System.SysUtils, Winapi.Windows, FireDAC.Comp.Client, uDoQryTypes;

function StartTx(const Ctx: TDoQryContext): IDoQryTx;

implementation

type
  TDoQryTx = class(TInterfacedObject, IDoQryTx)
  private
    FCtx: TDoQryContext;
    FOuterMost: Boolean;
    FSavepoint: string;
    FActive: Boolean;
  public
    constructor Create(const Ctx: TDoQryContext);
    destructor Destroy; override;
    procedure Commit;
    procedure Rollback;
  end;

function GenSavepointName: string;
begin
  Result := 'sp_' + IntToHex(Integer(GetTickCount64 mod $7FFFFFFF), 8);
end;

constructor TDoQryTx.Create(const Ctx: TDoQryContext);
begin
  inherited Create;
  FCtx := Ctx;
  FActive := True;
  if not FCtx.Connection.InTransaction then
  begin
    FCtx.Connection.StartTransaction;
    FOuterMost := True;
  end
  else
  begin
    FOuterMost := False;
    FSavepoint := GenSavepointName;
    FCtx.Connection.ExecSQL('SAVEPOINT ' + FSavepoint);
  end;
end;

destructor TDoQryTx.Destroy;
begin
  if FActive then
    Rollback;
  inherited;
end;

procedure TDoQryTx.Commit;
begin
  if not FActive then Exit;
  if FOuterMost then
    FCtx.Connection.Commit
  else
    FCtx.Connection.ExecSQL('RELEASE SAVEPOINT ' + FSavepoint);
  FActive := False;
end;

procedure TDoQryTx.Rollback;
begin
  if not FActive then Exit;
  if FOuterMost then
    FCtx.Connection.Rollback
  else
    FCtx.Connection.ExecSQL('ROLLBACK TO SAVEPOINT ' + FSavepoint);
  FActive := False;
end;

function StartTx(const Ctx: TDoQryContext): IDoQryTx;
begin
  Result := TDoQryTx.Create(Ctx);
end;

end.
