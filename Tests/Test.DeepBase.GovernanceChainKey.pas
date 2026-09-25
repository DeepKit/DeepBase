unit Test.DeepBase.GovernanceChainKey;

{*******************************************************************************
  A2-13 regression: governance evidence/review chains must be keyed HMAC-SHA256.
  - Empty HMAC key must reject construction (fail-closed) for both stores.
  - With a real key: clean chain verifies; a single tampered row is detected.
*******************************************************************************}

interface

uses
  System.SysUtils,
  System.DateUtils,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  DUnitX.TestFramework,
  DeepBase.Exceptions,
  DeepBase.Governance.Types,
  DeepBase.Governance.EvidenceRecorder,
  DeepBase.Governance.EvidenceStore.SQLite,
  DeepBase.Governance.ReviewQueue.SQLite;

type
  [TestFixture]
  TTestGovernanceChainKey = class
  private
    function MakeKey: TBytes;
    function MakeConn: TFDConnection;
    function MakeEntry(const AId: string): TEvidenceEntry;
  public
    /// <summary>EvidenceStore must reject an empty HMAC key</summary>
    [Test]
    procedure Test_EvidenceStore_EmptyKey_Rejects;

    /// <summary>ReviewQueue must reject an empty HMAC key</summary>
    [Test]
    procedure Test_ReviewQueue_EmptyKey_Rejects;

    /// <summary>Keyed chain verifies clean, detects a tampered row</summary>
    [Test]
    procedure Test_KeyedChain_TamperDetected;
  end;

implementation

{ TTestGovernanceChainKey }

function TTestGovernanceChainKey.MakeKey: TBytes;
var
  I: Integer;
begin
  SetLength(Result, 32);
  for I := 0 to 31 do
    Result[I] := Byte(I * 3 + 11);
end;

function TTestGovernanceChainKey.MakeConn: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.DriverName := 'SQLite';
  Result.Params.Database := ':memory:';
  Result.Params.Values['LockingMode'] := 'Normal';
  Result.Connected := True;
end;

function TTestGovernanceChainKey.MakeEntry(const AId: string): TEvidenceEntry;
begin
  Result.Id := AId;
  Result.SchemaVersion := 1;
  Result.CorrelationId := 'corr-' + AId;
  // Whole-second timestamp avoids TDateTime<->ISO8601 roundtrip drift in VerifyChain
  Result.Timestamp := EncodeDateTime(2026, 9, 25, 10, 0, 0, 0);
  Result.UserId := 'user-a';
  Result.ActionKey := 'action.sample';
  Result.RiskLevel := rlL1;
  Result.GatePath := 'gate/one';
  Result.InputSummary := 'input summary ' + AId;
  Result.OutputSummary := 'output summary';
  Result.Result := erSuccess;
  Result.BlockedReason := '';
  Result.SnapshotData := '';
  Result.PolicyPackageId := '';
  Result.PolicyVersion := '';
  Result.ActionIntentId := '';
  Result.HumanDecisionId := '';
  Result.ParametersDigest := '';
end;

procedure TTestGovernanceChainKey.Test_EvidenceStore_EmptyKey_Rejects;
var
  LConn: TFDConnection;
  LStore: TEvidenceStoreSQLite;
  LRaised: Boolean;
begin
  LConn := MakeConn;
  try
    LRaised := False;
    try
      LStore := TEvidenceStoreSQLite.Create(LConn, [], False);
      LStore.Free;
    except
      on E: EMissingConfigurationException do
        LRaised := True;
    end;
    Assert.IsTrue(LRaised,
      'Empty HMAC key must reject TEvidenceStoreSQLite construction (A2-13 fail-closed)');
  finally
    LConn.Free;
  end;
end;

procedure TTestGovernanceChainKey.Test_ReviewQueue_EmptyKey_Rejects;
var
  LConn: TFDConnection;
  LQueue: TReviewQueueSQLite;
  LRaised: Boolean;
begin
  LConn := MakeConn;
  try
    LRaised := False;
    try
      LQueue := TReviewQueueSQLite.Create(LConn, [], False);
      LQueue.Free;
    except
      on E: EMissingConfigurationException do
        LRaised := True;
    end;
    Assert.IsTrue(LRaised,
      'Empty HMAC key must reject TReviewQueueSQLite construction (A2-13 fail-closed)');
  finally
    LConn.Free;
  end;
end;

procedure TTestGovernanceChainKey.Test_KeyedChain_TamperDetected;
var
  LConn: TFDConnection;
  LStore: TEvidenceStoreSQLite;
  LBroken, LTotal: Integer;
  LQuery: TFDQuery;
begin
  LConn := MakeConn;
  LStore := TEvidenceStoreSQLite.Create(LConn, MakeKey, False);
  try
    LStore.Save(MakeEntry('ev-1'));
    LStore.Save(MakeEntry('ev-2'));

    Assert.IsTrue(LStore.VerifyChain(LBroken, LTotal),
      'Untampered keyed chain must verify clean');
    Assert.AreEqual(2, LTotal, 'Two rows stored');

    // Attacker with raw DB write access edits one payload column in place
    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := LConn;
      LQuery.ExecSQL(
        'UPDATE governance_evidence SET input_summary = ''forged'' WHERE id = ''ev-1''');
    finally
      LQuery.Free;
    end;

    Assert.IsFalse(LStore.VerifyChain(LBroken, LTotal),
      'Tampered row must break HMAC chain verification');
    Assert.IsTrue(LBroken >= 1,
      'VerifyChain must report at least one broken link');
  finally
    LStore.Free;
    LConn.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestGovernanceChainKey);

end.
