program ConfigRegistrarPBT;

{ ============================================================================
  TConfigRegistrar — Property-Based Tests (standalone headless harness)
  ---------------------------------------------------------------------------
  Validates:
    Property 1 — Registration Round-Trip
      For any gate/action/purpose registered via ConfigRegistrar,
      LoadFromDB into a fresh KeyResolver+PurposeSet produces objects
      with equivalent key, display name, risk level, gate link.

    Property 2 — Registration Idempotence
      Registering the same key twice with different display names
      yields exactly one row per table, and the second registration's
      values win.

  Runs 100 randomised iterations per property. Exit code 0 on pass.
  ============================================================================ }

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Option,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  DeepBase.Governance.Types in '..\..\Governance\DeepBase.Governance.Types.pas',
  DeepBase.Governance.Model in '..\..\Governance\DeepBase.Governance.Model.pas',
  DeepBase.Governance.KeyResolver in '..\..\Governance\DeepBase.Governance.KeyResolver.pas',
  DeepBase.Governance.Purpose in '..\..\Governance\DeepBase.Governance.Purpose.pas',
  DeepBase.Governance.ConfigRegistrar in '..\..\Governance\DeepBase.Governance.ConfigRegistrar.pas';

const
  ITERATIONS = 100;

var
  GFailures: Integer = 0;
  GConn: TFDConnection;

function RandomKey(const APrefix: string; ASuffixLen: Integer = 6): string;
const
  ALPHA = 'abcdefghijklmnopqrstuvwxyz0123456789_';
var
  I: Integer;
begin
  Result := APrefix;
  for I := 1 to ASuffixLen do
    Result := Result + ALPHA[Random(Length(ALPHA)) + 1];
end;

function RandomDisplayName: string;
const
  WORDS: array[0..9] of string =
    ('Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon',
     'Rotate', 'Purge', 'Publish', 'Activate', 'Reset');
begin
  Result := WORDS[Random(Length(WORDS))] + ' ' +
            WORDS[Random(Length(WORDS))];
end;

function RandomRiskLevel: TRiskLevel;
begin
  Result := TRiskLevel(Random(Ord(High(TRiskLevel)) + 1));
end;

function RandomGateType: TGateType;
begin
  Result := TGateType(Random(Ord(High(TGateType)) + 1));
end;

procedure Report(AResult: Boolean; const AMessage: string);
begin
  if AResult then
    Writeln('  [OK] ', AMessage)
  else
  begin
    Writeln('  [FAIL] ', AMessage);
    Inc(GFailures);
  end;
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

// ============================================================================
// Property 1 — Registration Round-Trip
// ============================================================================
procedure RunProperty1;
var
  I: Integer;
  LKey: TKeyResolver;
  LPur: TPurposeSet;
  LReg: TConfigRegistrar;
  LKey2: TKeyResolver;
  LPur2: TPurposeSet;
  LReg2: TConfigRegistrar;

  LGateKey, LActionKey, LPurposeKey: string;
  LGateName, LActionName, LPurposeName: string;
  LRisk: TRiskLevel;
  LGateType: TGateType;

  LSrcGate, LRoundGate: TAccessGate;
  LSrcAction, LRoundAction: TAction;
  LSrcPurpose, LRoundPurpose: TPurpose;
  LAllPass: Boolean;
begin
  Writeln('[pbt] Property 1 — Registration Round-Trip');
  LAllPass := True;

  for I := 1 to ITERATIONS do
  begin
    GConn := CreateInMemoryConn;
    LKey := TKeyResolver.Create;
    LPur := TPurposeSet.Create;
    try
      LReg := TConfigRegistrar.Create(GConn, LKey, LPur);
      try
        // Generate random entities.
        LGateKey := RandomKey('gate_');
        LActionKey := RandomKey('act_');
        LPurposeKey := RandomKey('pur_');
        LGateName := RandomDisplayName;
        LActionName := RandomDisplayName;
        LPurposeName := RandomDisplayName;
        LRisk := RandomRiskLevel;
        LGateType := RandomGateType;

        // Register.
        LReg.RegisterPurpose(LPurposeKey, LPurposeName, 'desc', '');
        LReg.RegisterGate(LGateKey, LGateName, LGateType, LRisk);
        LReg.RegisterAction(LActionKey, LActionName, LRisk,
          LGateKey, LPurposeKey);

        LSrcGate := LKey.ResolveGateKey(LGateKey);
        LSrcAction := LKey.ResolveActionKey(LActionKey);
        LSrcPurpose := LPur.Find(LPurposeKey);

        if (LSrcGate = nil) or (LSrcAction = nil) or (LSrcPurpose = nil) then
        begin
          Writeln(Format('  [FAIL] Iter %d: in-memory objects missing after registration',
            [I]));
          LAllPass := False;
          Continue;
        end;
      finally
        LReg.Free;
      end;

      // Round-trip — fresh resolver + fresh registrar over the SAME DB.
      LKey2 := TKeyResolver.Create;
      LPur2 := TPurposeSet.Create;
      try
        LReg2 := TConfigRegistrar.Create(GConn, LKey2, LPur2);
        try
          LReg2.LoadFromDB;

          LRoundGate := LKey2.ResolveGateKey(LGateKey);
          LRoundAction := LKey2.ResolveActionKey(LActionKey);
          LRoundPurpose := LPur2.Find(LPurposeKey);

          if (LRoundGate = nil) then
          begin
            Writeln(Format('  [FAIL] Iter %d: gate "%s" missing after LoadFromDB',
              [I, LGateKey]));
            LAllPass := False;
          end
          else if (LRoundGate.DisplayName <> LGateName) or
                  (LRoundGate.GateType <> LGateType) then
          begin
            Writeln(Format('  [FAIL] Iter %d: gate round-trip mismatch (name=%s vs %s)',
              [I, LRoundGate.DisplayName, LGateName]));
            LAllPass := False;
          end;

          if (LRoundAction = nil) then
          begin
            Writeln(Format('  [FAIL] Iter %d: action "%s" missing after LoadFromDB',
              [I, LActionKey]));
            LAllPass := False;
          end
          else if (LRoundAction.DisplayName <> LActionName) or
                  (LRoundAction.RiskLevel <> LRisk) or
                  (LRoundAction.GateKey <> LGateKey) or
                  (LRoundAction.PurposeKey <> LPurposeKey) then
          begin
            Writeln(Format('  [FAIL] Iter %d: action round-trip mismatch', [I]));
            LAllPass := False;
          end;

          if (LRoundPurpose = nil) then
          begin
            Writeln(Format('  [FAIL] Iter %d: purpose "%s" missing',
              [I, LPurposeKey]));
            LAllPass := False;
          end
          else if (LRoundPurpose.Name <> LPurposeName) then
          begin
            Writeln(Format('  [FAIL] Iter %d: purpose round-trip mismatch', [I]));
            LAllPass := False;
          end;
        finally
          LReg2.Free;
        end;
      finally
        LPur2.Free;
        LKey2.Free;
      end;
    finally
      LPur.Free;
      LKey.Free;
      GConn.Free;
    end;
  end;

  Report(LAllPass, Format('P1 Registration Round-Trip (%d iterations)',
    [ITERATIONS]));
end;

// ============================================================================
// Property 2 — Registration Idempotence
// ============================================================================
procedure RunProperty2;
var
  I: Integer;
  LKey: TKeyResolver;
  LPur: TPurposeSet;
  LReg: TConfigRegistrar;

  LGateKey: string;
  LName1, LName2: string;
  LRisk1, LRisk2: TRiskLevel;
  LGateType1, LGateType2: TGateType;

  LResolved: TAccessGate;
  LGateRows: Integer;
  LAllPass: Boolean;
begin
  Writeln('[pbt] Property 2 — Registration Idempotence');
  LAllPass := True;

  for I := 1 to ITERATIONS do
  begin
    GConn := CreateInMemoryConn;
    LKey := TKeyResolver.Create;
    LPur := TPurposeSet.Create;
    try
      LReg := TConfigRegistrar.Create(GConn, LKey, LPur);
      try
        LGateKey := RandomKey('idem_');
        LName1 := RandomDisplayName + ' v1';
        LName2 := RandomDisplayName + ' v2';
        LRisk1 := RandomRiskLevel;
        LRisk2 := RandomRiskLevel;
        LGateType1 := RandomGateType;
        LGateType2 := RandomGateType;

        // Register twice with same key, different fields.
        LReg.RegisterGate(LGateKey, LName1, LGateType1, LRisk1);
        LReg.RegisterGate(LGateKey, LName2, LGateType2, LRisk2);

        // Exactly one row in governance_gates for this key.
        LGateRows := CountRows(GConn, 'governance_gates',
          Format('key = ''%s''', [LGateKey]));
        if LGateRows <> 1 then
        begin
          Writeln(Format('  [FAIL] Iter %d: expected 1 row for key "%s", got %d',
            [I, LGateKey, LGateRows]));
          LAllPass := False;
        end;

        // Second registration's values win (in the in-memory KeyResolver).
        LResolved := LKey.ResolveGateKey(LGateKey);
        if (LResolved = nil) then
        begin
          Writeln(Format('  [FAIL] Iter %d: key "%s" not resolvable',
            [I, LGateKey]));
          LAllPass := False;
        end
        else if (LResolved.DisplayName <> LName2) or
                (LResolved.GateType <> LGateType2) then
        begin
          Writeln(Format('  [FAIL] Iter %d: second registration did not win (got %s)',
            [I, LResolved.DisplayName]));
          LAllPass := False;
        end;
      finally
        LReg.Free;
      end;
    finally
      LPur.Free;
      LKey.Free;
      GConn.Free;
    end;
  end;

  Report(LAllPass, Format('P2 Registration Idempotence (%d iterations)',
    [ITERATIONS]));
end;

begin
  Randomize;
  Writeln('=====================================');
  Writeln('TConfigRegistrar PBT Harness');
  Writeln('=====================================');
  try
    RunProperty1;
    RunProperty2;
  except
    on E: Exception do
    begin
      Writeln('[pbt] UNHANDLED EXCEPTION: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;

  Writeln;
  if GFailures = 0 then
  begin
    Writeln('[pbt] ALL PROPERTIES PASSED');
    Halt(0);
  end
  else
  begin
    Writeln(Format('[pbt] %d PROPERT(IES) FAILED', [GFailures]));
    Halt(1);
  end;
end.
