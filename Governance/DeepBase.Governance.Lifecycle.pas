{ ============================================================================
  DeepBase.Governance.Lifecycle
  ---------------------------------------------------------------------------
  Version     : 2.2
  Description : Lifecycle manager for OCGS Governance. Wires the 9 engines
                and invokes a user-provided setup callback that registers
                gates/actions/purposes in code (no external config files).
                Supports two paths:
                  1) Legacy callback (TGovernanceSetupProc) — in-memory only.
                  2) ConfigDB-backed (TGovernanceConfigSetupProc) — persists
                     gates/actions/purposes to governance_* tables and wraps
                     the GateResolver with TObserveGateResolver for runtime
                     observe/enforce switching.
  Rule        : Honors DeepBase config rule — no JSON/INI/YAML on disk.
  ============================================================================ }

unit DeepBase.Governance.Lifecycle;

interface

uses
  System.SysUtils,
  System.IOUtils,
  FireDAC.Comp.Client,
  DeepBase.Governance.Types,
  DeepBase.Governance.Model,
  DeepBase.Governance.Interfaces,
  DeepBase.Governance.KeyResolver,
  DeepBase.Governance.DueChecker,
  DeepBase.Governance.ActionGrid,
  DeepBase.Governance.GateResolver,
  DeepBase.Governance.RouteResolver,
  DeepBase.Governance.ProjectionResolver,
  DeepBase.Governance.FeedbackResolver,
  DeepBase.Governance.ActionExecutor,
  DeepBase.Governance.Runtime,
  DeepBase.Governance.Purpose,
  DeepBase.Governance.AI.SteeringExporter,
  DeepBase.Governance.ObserveGateResolver,
  DeepBase.Governance.EvidenceRecorder,
  DeepBase.Governance.EvidenceStore.SQLite,
  DeepBase.Governance.ConfigRegistrar,
  DeepBase.Governance.ReviewQueue,
  DeepBase.Governance.ReviewQueue.SQLite;

type
  TGovernanceMode = (gmObserve, gmEnforce, gmOff);

  /// Legacy setup callback (6 params, in-memory only).
  TGovernanceSetupProc = reference to procedure(
    AKey: TKeyResolver;
    ADueChecker: TDueChecker;
    AActionGrid: TActionGrid;
    AGateResolver: TGateResolver;
    APurposeSet: TPurposeSet;
    ARuntime: TOCGSRuntime);

  /// ConfigDB-backed setup callback. Downstream calls RegisterGate /
  /// RegisterAction / RegisterPurpose on the registrar which persists to
  /// governance_* tables AND registers in-memory objects.
  TGovernanceConfigSetupProc = reference to procedure(
    ARegistrar: TConfigRegistrar;
    AGateResolver: TGateResolver;
    ARuntime: TOCGSRuntime);

  TGovernanceLifecycle = class
  private
    FKeyResolver: TKeyResolver;
    FDueChecker: TDueChecker;
    FActionGrid: TActionGrid;
    FGateResolver: TGateResolver;
    FRouteResolver: TRouteResolver;
    FProjection: TProjectionResolver;
    FFeedback: TFeedbackResolver;
    FExecutor: TActionExecutor;
    FRuntime: TOCGSRuntime;
    FPurposeSet: TPurposeSet;
    FSteeringExporter: TSteeringExporter;
    FSetupProc: TGovernanceSetupProc;
    FConfigSetupProc: TGovernanceConfigSetupProc;
    FMode: TGovernanceMode;
    FStarted: Boolean;
    FInitialized: Boolean;
    // ConfigDB-backed components
    FConfigDB: TFDConnection;
    FConfigRegistrar: TConfigRegistrar;
    FReviewQueue: IReviewQueue;
    FReviewDecisionVerifier: IReviewDecisionVerifier;
    FEvidenceStore: IEvidenceStore;
    FEvidenceRecorder: TEvidenceRecorder;
    FEvidenceRecorderIntf: IEvidenceRecorder;
    FObserveResolver: IGateResolver;
    function IsObserveMode: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    /// Legacy configure (no ConfigDB).
    procedure Configure(AMode: TGovernanceMode; ASetupProc: TGovernanceSetupProc);
    /// ConfigDB-backed configure.
    procedure ConfigureEx(AMode: TGovernanceMode; AConfigDB: TFDConnection;
      ASetupProc: TGovernanceConfigSetupProc);
    procedure Initialize;
    procedure Start;
    procedure Stop;
    procedure Shutdown;

    /// <summary>
    /// Flip governance mode at runtime (observe ↔ enforce). Persists the
    /// change via ConfigRegistrar AND updates the in-memory mode the
    /// ObserveGateResolver reads, so the next Resolve call sees the new mode
    /// without needing a full re-initialise.
    /// </summary>
    procedure SwitchMode(ANewMode: TGovernanceMode);

    property KeyResolver: TKeyResolver read FKeyResolver;
    property DueChecker: TDueChecker read FDueChecker;
    property ActionGrid: TActionGrid read FActionGrid;
    property GateResolver: TGateResolver read FGateResolver;
    property RouteResolver: TRouteResolver read FRouteResolver;
    property ProjectionResolver: TProjectionResolver read FProjection;
    property FeedbackResolver: TFeedbackResolver read FFeedback;
    property ActionExecutor: TActionExecutor read FExecutor;
    property Runtime: TOCGSRuntime read FRuntime;
    property PurposeSet: TPurposeSet read FPurposeSet;
    property ConfigRegistrar: TConfigRegistrar read FConfigRegistrar;
    property EvidenceRecorder: TEvidenceRecorder read FEvidenceRecorder;
    // ASY-GOV-006 阶段5: 暴露 review queue 给 Assayer admin handler
    // (HandleAdminReviews) 取实例做人工裁决录入。与 ActionExecutor 等同构只读属性。
    property ReviewQueue: IReviewQueue read FReviewQueue;
    property Mode: TGovernanceMode read FMode;
    property Started: Boolean read FStarted;
  end;

var
  GovernanceLifecycle: TGovernanceLifecycle;

implementation

constructor TGovernanceLifecycle.Create;
begin
  inherited Create;
  FMode := gmObserve;
  FStarted := False;
  FInitialized := False;
end;

destructor TGovernanceLifecycle.Destroy;
begin
  if FStarted then
    Shutdown;
  inherited;
end;

procedure TGovernanceLifecycle.Configure(AMode: TGovernanceMode;
  ASetupProc: TGovernanceSetupProc);
begin
  FMode := AMode;
  FSetupProc := ASetupProc;
  FConfigSetupProc := nil;
  FConfigDB := nil;
end;

procedure TGovernanceLifecycle.ConfigureEx(AMode: TGovernanceMode;
  AConfigDB: TFDConnection; ASetupProc: TGovernanceConfigSetupProc);
begin
  FMode := AMode;
  FSetupProc := nil;
  FConfigSetupProc := ASetupProc;
  FConfigDB := AConfigDB;
end;

function TGovernanceLifecycle.IsObserveMode: Boolean;
begin
  Result := FMode = gmObserve;
end;

procedure TGovernanceLifecycle.Initialize;
var
  LModeProvider: TObserveModeProvider;
  LResolverForRuntime: IGateResolver;
  LPersistedMode: string;
begin
  if FMode = gmOff then Exit;
  // DATA2-008: Guard against reentry — calling Initialize twice without
  // Shutdown leaks all engine instances created in the first call.
  if FInitialized then Exit;

  // Engine graph, bottom-up.
  FKeyResolver   := TKeyResolver.Create;
  FDueChecker    := TDueChecker.Create(FKeyResolver);
  FActionGrid    := TActionGrid.Create(FDueChecker);
  FGateResolver  := TGateResolver.Create(FKeyResolver);
  FRouteResolver := TRouteResolver.Create;
  FProjection    := TProjectionResolver.Create(FGateResolver);
  FFeedback      := TFeedbackResolver.Create;
  FExecutor      := TActionExecutor.Create(FActionGrid, FDueChecker, nil);
  FPurposeSet    := TPurposeSet.Create;

  // ConfigDB-backed wiring when a connection was provided.
  if FConfigDB <> nil then
  begin
    // DATA2-005: 第 3 个参数是 HMAC 密钥（空 = 回退到 SHA-256 检测篡改）。
    // 若需 HMAC 强度，从 TKeyManager.Instance.GetActiveKeyForPurpose(kpSigning) 获取。
    FEvidenceStore := TEvidenceStoreSQLite.Create(FConfigDB, [], False);
    FEvidenceRecorder := TEvidenceRecorder.Create(FEvidenceStore);
    FEvidenceRecorderIntf := FEvidenceRecorder;
    // REVIEW5-GOV-001: Pass ActionGrid and DueChecker to ConfigRegistrar so it
    // can sync Action registrations to all three registries (KeyResolver, ActionGrid, DueChecker)
    FConfigRegistrar := TConfigRegistrar.Create(
      FConfigDB, FKeyResolver, FPurposeSet, FActionGrid, FDueChecker);

    // Persisted mode overrides the default when caller passed gmObserve.
    if FMode = gmObserve then
    begin
      LPersistedMode := FConfigRegistrar.GetMode;
      if SameText(LPersistedMode, 'enforce') then
        FMode := gmEnforce;
    end
    else
      FConfigRegistrar.SetMode('enforce');

    // GOV-006 阶段4: Wire the ReviewQueue + decision verifier into the
    // ActionExecutor so execute-path challenges are verified fail-closed.
    // ConfigDB-backed path only — the legacy (no ConfigDB) path stays
    // verifier=nil to preserve backward compatibility. TReviewQueueSQLite
    // owns no connection (the ConfigDB lifecycle is managed by TDeepBaseManager)
    // and creates its tables idempotently in its constructor (EnsureTable).
    // DATA2-005: empty HMAC key -> ReviewQueue falls back to SHA-256 for
    // tamper detection (same posture as EvidenceStore above).
    FReviewQueue := TReviewQueueSQLite.Create(FConfigDB, [], False);
    FReviewDecisionVerifier := TReviewDecisionVerifier.Create(FReviewQueue);
    FExecutor.SetVerifier(FReviewDecisionVerifier);
  end;

  // Mode provider closure for the ObserveGateResolver decorator.
  LModeProvider :=
    function: Boolean
    begin
      Result := Self.IsObserveMode;
    end;

  FObserveResolver := TObserveGateResolver.Create(
    FGateResolver, FEvidenceRecorderIntf, LModeProvider);
  LResolverForRuntime := FObserveResolver;

  FRuntime := TOCGSRuntime.Create(
    FActionGrid,
    LResolverForRuntime,
    FRouteResolver,
    FExecutor,
    FDueChecker,
    FProjection,
    FFeedback,
    FEvidenceRecorderIntf,
    FKeyResolver);

  FSteeringExporter := TSteeringExporter.Create(
    FKeyResolver,
    FPurposeSet,
    TPath.Combine(ExtractFilePath(ParamStr(0)), '.kiro\steering'));

  FInitialized := True;
end;

procedure TGovernanceLifecycle.Start;
begin
  if FMode = gmOff then Exit;

  // Downstream setup — registers gates / actions / bridges / evaluators.
  if Assigned(FConfigSetupProc) and (FConfigRegistrar <> nil) then
    FConfigSetupProc(FConfigRegistrar, FGateResolver, FRuntime)
  else if Assigned(FSetupProc) then
    FSetupProc(FKeyResolver, FDueChecker, FActionGrid, FGateResolver,
               FPurposeSet, FRuntime);

  // Export AI steering model.
  ForceDirectories(FSteeringExporter.OutputDir);
  try
    FSteeringExporter.ExportToFile('governance-model.md');
  except
    on E: Exception do
      ; // Non-fatal
  end;

  FStarted := True;
end;

procedure TGovernanceLifecycle.Stop;
begin
  FStarted := False;
end;

procedure TGovernanceLifecycle.SwitchMode(ANewMode: TGovernanceMode);
begin
  if ANewMode = gmOff then
    Exit; // refuse — call Shutdown if you want to turn governance off
  FMode := ANewMode;
  if FConfigRegistrar <> nil then
  begin
    case ANewMode of
      gmObserve: FConfigRegistrar.SetMode('observe');
      gmEnforce: FConfigRegistrar.SetMode('enforce');
    end;
  end;
end;

procedure TGovernanceLifecycle.Shutdown;
begin
  Stop;
  // DATA2-008: Reset initialized flag so a subsequent Initialize can rebuild.
  FInitialized := False;
  // SteeringExporter is a plain TObject — safe to FreeAndNil.
  FreeAndNil(FSteeringExporter);

  // Runtime holds interface references to every resolver/executor/recorder/grid.
  // Each of those concrete classes is TInterfacedObject, so the interface ref
  // pinned them at refcount=1. Freeing Runtime releases those refs, which
  // triggers Destroy on each concrete object via the interface _Release path.
  // After this call every raw pointer below is DANGLING.
  FreeAndNil(FRuntime);

  // Parallel interface refs → nil (Runtime already dropped them to zero).
  FObserveResolver := nil;
  FEvidenceRecorderIntf := nil;
  FEvidenceStore := nil;
  // GOV-006 阶段4: ReviewQueue + verifier are interface refs held by this
  // lifecycle. The verifier is also held by FExecutor (released when the
  // executor chain is torn down above); nil our refs here — if the executor
  // still pins the verifier, this just drops our extra ref harmlessly.
  FReviewDecisionVerifier := nil;
  FReviewQueue := nil;

  // Clear dangling raw pointers without calling Free — they're already freed.
  FEvidenceRecorder := nil;
  FKeyResolver := nil;
  FDueChecker := nil;
  FActionGrid := nil;
  FGateResolver := nil;
  FRouteResolver := nil;
  FProjection := nil;
  FFeedback := nil;
  FExecutor := nil;

  // Plain TObject components — FreeAndNil is the right call.
  FreeAndNil(FConfigRegistrar);
  FreeAndNil(FPurposeSet);
end;

end.
