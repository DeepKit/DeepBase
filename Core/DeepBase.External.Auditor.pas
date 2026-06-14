{ ============================================================================
  DeepBase.External.Auditor - BodyZero Audit Implementation
  Version: 0.7
  ============================================================================ }

unit DeepBase.External.Auditor;

interface

uses
  System.SysUtils, System.Generics.Collections,
  DeepBase.External.Types;

type
  IBodyZeroAuditor = interface
    ['{B9E4A7F2-1C3D-4B8E-9A6F-5D2C8E1B4A3F}']
    procedure RecordColumnAccess(const ColumnName: string);
    function GetQueriedColumns: TArray<string>;
    function GetBodyColumnsSeen: Boolean;
    function GetWriteAttempts: Integer;
    function GetUIACallCount: Integer;
    function IsFaulted: Boolean;
    procedure IncrementFaultCount;
    procedure IncrementWriteAttempts;
    procedure RecordRawSQLAccess(const SQL: string);
    procedure RecordUIAOperation(const Path: string; const Value: string);
    procedure Reset;
    function GenerateBodyZeroReport: TBodyZeroReport;
  end;

  TBodyZeroAuditorImpl = class(TInterfacedObject, IBodyZeroAuditor)
  private
    FQueriedColumns: TList<string>;
    FBodyColumnsSeen: Boolean;
    FWriteAttempts: Integer;
    FUIACallCount: Integer;
    FFaultCount: Integer;
    FMaxFaultCount: Integer;
    FRawSQLAccess: TList<string>;
    FUIAOperations: TList<string>;
  public
    constructor Create(AMaxFaultCount: Integer = 10);
    destructor Destroy; override;
    procedure RecordColumnAccess(const ColumnName: string);
    function GetQueriedColumns: TArray<string>;
    function GetBodyColumnsSeen: Boolean;
    function GetWriteAttempts: Integer;
    function GetUIACallCount: Integer;
    function IsFaulted: Boolean;
    procedure IncrementFaultCount;
    procedure IncrementWriteAttempts;
    procedure RecordRawSQLAccess(const SQL: string);
    procedure RecordUIAOperation(const Path: string; const Value: string);
    procedure Reset;
    function GenerateBodyZeroReport: TBodyZeroReport;
  end;

implementation

constructor TBodyZeroAuditorImpl.Create(AMaxFaultCount: Integer);
begin
  inherited Create;
  FMaxFaultCount := AMaxFaultCount;
  FQueriedColumns := TList<string>.Create;
  FRawSQLAccess := TList<string>.Create;
  FUIAOperations := TList<string>.Create;
end;

destructor TBodyZeroAuditorImpl.Destroy;
begin
  FQueriedColumns.Free;
  FRawSQLAccess.Free;
  FUIAOperations.Free;
  inherited;
end;

procedure TBodyZeroAuditorImpl.RecordColumnAccess(const ColumnName: string);
begin
  FQueriedColumns.Add(ColumnName);
end;

function TBodyZeroAuditorImpl.GetQueriedColumns: TArray<string>;
begin
  Result := FQueriedColumns.ToArray;
end;

function TBodyZeroAuditorImpl.GetBodyColumnsSeen: Boolean;
begin
  Result := FBodyColumnsSeen;
end;

function TBodyZeroAuditorImpl.GetWriteAttempts: Integer;
begin
  Result := FWriteAttempts;
end;

function TBodyZeroAuditorImpl.GetUIACallCount: Integer;
begin
  Result := FUIACallCount;
end;

function TBodyZeroAuditorImpl.IsFaulted: Boolean;
begin
  Result := FFaultCount >= FMaxFaultCount;
end;

procedure TBodyZeroAuditorImpl.IncrementFaultCount;
begin
  Inc(FFaultCount);
end;

procedure TBodyZeroAuditorImpl.IncrementWriteAttempts;
begin
  Inc(FWriteAttempts);
end;

procedure TBodyZeroAuditorImpl.RecordRawSQLAccess(const SQL: string);
begin
  FRawSQLAccess.Add(SQL);
end;

procedure TBodyZeroAuditorImpl.RecordUIAOperation(const Path: string; const Value: string);
begin
  Inc(FUIACallCount);
  FUIAOperations.Add(Format('%s: %s', [Path, Copy(Value, 1, 100)]));
end;

procedure TBodyZeroAuditorImpl.Reset;
begin
  FQueriedColumns.Clear;
  FBodyColumnsSeen := False;
  FWriteAttempts := 0;
  FUIACallCount := 0;
  FFaultCount := 0;
  FRawSQLAccess.Clear;
  FUIAOperations.Clear;
end;

function TBodyZeroAuditorImpl.GenerateBodyZeroReport: TBodyZeroReport;
begin
  Result.BodyColumnsSeen := FBodyColumnsSeen;
  Result.WriteAttempts := FWriteAttempts;
  Result.UIACallCount := FUIACallCount;
  Result.QueriedColumns := FQueriedColumns.ToArray;
  Result.Faulted := IsFaulted;
  Result.CompatibilityReport := '';
end;

end.
