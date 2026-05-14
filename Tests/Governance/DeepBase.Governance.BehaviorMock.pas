{ ============================================================================
  DeepBase.Governance.BehaviorMock — shared helpers for downstream
  governance behavior tests. Keeps the per-project .dpr harnesses terse.
  ---------------------------------------------------------------------------
  Responsibilities:
    - Unified [OK]/[FAIL] assertion protocol that tracks a global failure
      count so the harness can set the process exit code accordingly.
    - Helpers for counting rows in governance_* tables.
    - Small builders for deterministic JSON context objects used as
      EnterGate payloads.
  ============================================================================ }

unit DeepBase.Governance.BehaviorMock;

interface

uses
  System.SysUtils,
  System.JSON,
  FireDAC.Comp.Client;

type
  /// <summary>Lightweight assertion wrapper used by the .dpr harnesses.</summary>
  TBehaviorMockAsserter = class
  private
    FFailures: Integer;
    FChecks: Integer;
  public
    procedure Check(ACondition: Boolean; const AMessage: string);
    procedure Section(const ATitle: string);
    procedure Summary;
    function ExitCode: Integer;
    property Failures: Integer read FFailures;
    property Checks: Integer read FChecks;
  end;

/// Creates a lightweight in-memory SQLite connection. Caller owns.
function CreateInMemoryConn: TFDConnection;

/// Counts rows in a table. Returns -1 if the table doesn't exist.
function CountRows(AConn: TFDConnection; const ATable: string;
  const AWhere: string = ''): Integer;

/// Build a JSON context with a single string pair. Caller owns.
function MakeCtx(const AKey, AValue: string): TJSONObject; overload;
/// Build a JSON context with a bool pair. Caller owns.
function MakeCtx(const AKey: string; AValue: Boolean): TJSONObject; overload;

implementation

uses
  FireDAC.Stan.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Option,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef;

{ TBehaviorMockAsserter }

procedure TBehaviorMockAsserter.Check(ACondition: Boolean; const AMessage: string);
begin
  Inc(FChecks);
  if ACondition then
    Writeln('  [OK] ', AMessage)
  else
  begin
    Writeln('  [FAIL] ', AMessage);
    Inc(FFailures);
  end;
end;

procedure TBehaviorMockAsserter.Section(const ATitle: string);
begin
  Writeln;
  Writeln('--- ', ATitle, ' ---');
end;

procedure TBehaviorMockAsserter.Summary;
begin
  Writeln;
  Writeln(Format('[summary] %d checks, %d failures',
    [FChecks, FFailures]));
end;

function TBehaviorMockAsserter.ExitCode: Integer;
begin
  if FFailures = 0 then
    Result := 0
  else
    Result := 1;
end;

function CreateInMemoryConn: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.DriverName := 'SQLite';
  Result.Params.Database := ':memory:';
  Result.Params.Values['LockingMode'] := 'Normal';
  Result.Connected := True;
end;

function CountRows(AConn: TFDConnection; const ATable: string;
  const AWhere: string = ''): Integer;
var
  Q: TFDQuery;
begin
  Result := -1;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := AConn;
    if AWhere <> '' then
      Q.SQL.Text := Format('SELECT COUNT(*) FROM %s WHERE %s',
        [ATable, AWhere])
    else
      Q.SQL.Text := Format('SELECT COUNT(*) FROM %s', [ATable]);
    try
      Q.Open;
      Result := Q.Fields[0].AsInteger;
    except
      Result := -1;
    end;
  finally
    Q.Free;
  end;
end;

function MakeCtx(const AKey, AValue: string): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair(AKey, AValue);
end;

function MakeCtx(const AKey: string; AValue: Boolean): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair(AKey, TJSONBool.Create(AValue));
end;

end.
