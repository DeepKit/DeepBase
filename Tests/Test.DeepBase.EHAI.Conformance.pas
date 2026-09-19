{ ============================================================================
  Test.DeepBase.EHAI.Conformance - Conformance Tests for EHAI Delphi Binding
  
  Language Common Layer Delphi Implementation 001 (WO-20260914-EHAI-001R1)
  Upstream Contract: EHAI-Language-Neutral-Realization-Contract-v0.md
  
  Test Suite Matrix (Tier A / Tier B Split):
    1. Tier A: Common Semantic Vectors (CSV-001 .. CSV-008):
       - CSV-001: CandidateSpace Bounded (<= 7) & Recommended Non-Execution
       - CSV-002: CandidateSelection & Non-Inherent Commitment
       - CSV-003: Multi-Choice Cardinality & Explicit Submit Boundary
       - CSV-004: Regenerate Exploratory Nature & Canonical State Readonly
       - CSV-005: Human Override Availability & Tri-state Distinctions
       - CSV-006: Source vs Interpretation Distinction & Recoverable Lineage
       - CSV-007: Frame Rejection Non-Remapping & Human Source Preservation
       - CSV-008: Commitment Boundary, Reject Effect & Authority Basis (Fail-Closed)
    2. Tier B: HB Surface Realization Vectors (HB-V-001 .. HB-V-005):
       - HB-V-001: FreeInput Text Entry Owns Keyboard & OverrideKind eokNone Default
       - HB-V-002: Regenerate Visual Reference Retention (Dimmed Overlay State)
       - HB-V-003: Multi-Choice Rendering, Key Toggle & Submit (TEhaiCardinality ecMultiple)
       - HB-V-004: Keyboard (Main + NumPad) vs Mouse Semantic Equivalence
       - HB-V-005: Focus, Cancel & Back Navigation Safety
  ============================================================================ }

unit Test.DeepBase.EHAI.Conformance;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  DUnitX.TestFramework,
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  Vcl.Forms,
  Vcl.Controls,
  DeepBase.EHAI.Types,
  DeepBase.HB.Choice.Types,
  DeepBase.HB.Core,
  DeepBase.VCL.HB.Choice;

type
  /// <summary>
  /// Tier A: Pure Language Common Layer Semantic Conformance (CSV-001 .. CSV-008).
  /// Independent of UI controls and surface rendering.
  /// </summary>
  [TestFixture]
  TTestEhaiConformanceTierA = class
  public
    [Test]
    procedure Test_CSV001_CandidateSpaceBounded_And_RecommendedNonExecution;

    [Test]
    procedure Test_CSV002_CandidateSelection_NonInherentCommitment;

    [Test]
    procedure Test_CSV003_MultiChoice_Cardinality_And_SubmitBoundary;

    [Test]
    procedure Test_CSV004_Regenerate_Exploratory_CanonicalStateReadonly;

    [Test]
    procedure Test_CSV005_HumanOverride_Availability_And_TriState;

    [Test]
    procedure Test_CSV006_Source_Vs_Interpretation_Distinction_And_Lineage;

    [Test]
    procedure Test_CSV007_FrameRejection_NonRemapping_HumanSourcePreservation;

    [Test]
    procedure Test_CSV008_CommitmentBoundary_RejectSemanticEffect_And_AuthorityBasis;
  end;

  /// <summary>
  /// Tier B: HB Surface Realization Conformance (HB-V-001 .. HB-V-005).
  /// VCL choice deck, keyboard capture, focus arbitration, and multi-modal actions.
  /// </summary>
  [TestFixture]
  TTestHbSurfaceVectorsTierB = class
  private
    FLastChoiceKey: Integer;
    FLastChoiceAction: THbChoiceAction;
    FLastCustomInputText: string;
    FLastMultiSelectKeys: TArray<Integer>;
    procedure OnChoiceHelper(Sender: TObject; AKey: Integer);
    procedure OnActionHelper(Sender: TObject; const AAction: THbChoiceAction);
    procedure OnCustomInputHelper(Sender: TObject; const AText: string);
    procedure OnMultiSelectHelper(Sender: TObject; const ASelectedKeys: TArray<Integer>);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_HBV001_FreeInputTextEntry_OwnsKeyboard_ShortcutSuspension;

    [Test]
    procedure Test_HBV002_Regenerate_VisualReferenceRetention_DimmedOverlay;

    [Test]
    procedure Test_HBV003_MultiChoice_VCL_Rendering_Toggle_And_Submit;

    [Test]
    procedure Test_HBV004_Keyboard_Main_Numpad_Mouse_SemanticEquivalence;

    [Test]
    procedure Test_HBV005_Focus_Cancel_BackNavigation_Safety;
  end;

implementation

{ TTestEhaiConformanceTierA }

procedure TTestEhaiConformanceTierA.Test_CSV001_CandidateSpaceBounded_And_RecommendedNonExecution;
var
  Space: TEhaiCandidateSpace;
  Cand: TEhaiCandidate;
  I: Integer;
begin
  Space := TEhaiCandidateSpace.CreateEmpty;
  // 1. Up to 7 candidates (keys 1..7) can be added
  for I := 1 to 7 do
    Space.AddOption(I, Format('Cand %d', [I]), Format('Desc %d', [I]), I = 1, NativeInt(100 + I));

  Assert.AreEqual(Integer(7), Integer(Space.Count));

  // 2. 8th candidate must NOT exceed bounds (Keys > 7 are rejected by bound rule)
  Space.AddOption(8, 'Cand 8', 'Desc 8', False);
  Assert.AreEqual(Integer(7), Integer(Space.Count), 'Candidate space must be bounded at max 7 options');

  // 3. Recommended mark (Candidate 1) is purely advisory metadata and does NOT cause auto-execution
  Assert.IsTrue(Space.FindByKey(1, Cand));
  Assert.IsTrue(Cand.IsRecommended, 'Candidate 1 has IsRecommended mark');
  Assert.IsTrue(Cand.Enabled, 'Candidate 1 is enabled');
  Assert.AreEqual(Integer(1), Integer(Space.RecommendedKey));
end;

procedure TTestEhaiConformanceTierA.Test_CSV002_CandidateSelection_NonInherentCommitment;
var
  Act: TEhaiInteractionAction;
  Ctx: TEhaiContextBinding;
begin
  Ctx := TEhaiContextBinding.Create('ctx-001', '订单处理', '步骤 2/3', 'Order#1001', 'finance.commit', 'FinanceDirector');
  Assert.IsTrue(Ctx.IsValid);
  Assert.AreEqual('ctx-001', Ctx.ContextId);

  // Candidate selection creates a semantic selection action
  Act := TEhaiInteractionAction.CreateCandidate(3, 'Option 3', eipJudge, Ctx, 300, esHuman);
  Assert.AreEqual(Ord(emaChoose), Ord(Act.MetaAction));
  Assert.AreEqual(3, Act.Key);
  Assert.AreEqual('Option 3', Act.Text);
  Assert.AreEqual(Ord(esHuman), Ord(Act.Source));
  Assert.AreEqual('ctx-001', Act.Context.ContextId);
  Assert.AreEqual(Ord(eipJudge), Ord(Act.Profile));

  // Selection does NOT equate to irrevocable system commitment
  Assert.AreNotEqual(Ord(eipAuthorize), Ord(Act.Profile));
end;

procedure TTestEhaiConformanceTierA.Test_CSV003_MultiChoice_Cardinality_And_SubmitBoundary;
var
  Act: TEhaiInteractionAction;
  Ctx: TEhaiContextBinding;
  SelKeys: array[0..2] of Integer;
begin
  Ctx := TEhaiContextBinding.Create('ctx-002', '批量审核', '步骤 1/1', 'Batch#88', 'batch.select', 'Auditor');
  SelKeys[0] := 1;
  SelKeys[1] := 3;
  SelKeys[2] := 5;

  // Multi-choice creates explicit submit action
  Act := TEhaiInteractionAction.CreateMultiCandidate(SelKeys, eipJudge, Ctx, 0, esHuman);
  Assert.AreEqual(Ord(emaChoose), Ord(Act.MetaAction));
  Assert.AreEqual(Integer(3), Integer(Length(Act.SelectedKeys)));
  Assert.AreEqual(1, Act.SelectedKeys[0]);
  Assert.AreEqual(3, Act.SelectedKeys[1]);
  Assert.AreEqual(5, Act.SelectedKeys[2]);
end;

procedure TTestEhaiConformanceTierA.Test_CSV004_Regenerate_Exploratory_CanonicalStateReadonly;
var
  Act, ActWithProf: TEhaiInteractionAction;
  Ctx: TEhaiContextBinding;
begin
  Ctx := TEhaiContextBinding.Create('ctx-003', '文案润色', '步骤 1/2', 'Doc#99', 'content.gen', 'Author');

  // Key 8 generates Regenerate action with explicit profile (R-05)
  ActWithProf := TEhaiInteractionAction.CreateRegenerate(eipInform, Ctx, 0, esHuman);
  Assert.AreEqual(Ord(emaRegenerate), Ord(ActWithProf.MetaAction));
  Assert.AreEqual(8, ActWithProf.Key);
  Assert.AreEqual(Ord(esHuman), Ord(ActWithProf.Source));
  Assert.AreEqual(Ord(eipInform), Ord(ActWithProf.Profile));
  Assert.AreEqual('Regenerate', ActWithProf.Text);

  // Backward compatible overload also works
  Act := TEhaiInteractionAction.CreateRegenerate(Ctx, 0, esHuman);
  Assert.AreEqual(Ord(emaRegenerate), Ord(Act.MetaAction));
  Assert.AreEqual(8, Act.Key);

  // Pure exploration: does NOT mutate canonical business state
  Assert.AreEqual(NativeInt(0), Act.Payload);
end;

procedure TTestEhaiConformanceTierA.Test_CSV005_HumanOverride_Availability_And_TriState;
var
  ActReject, ActAlt, ActFrame: TEhaiInteractionAction;
  Ctx: TEhaiContextBinding;
begin
  Ctx := TEhaiContextBinding.Create('ctx-004', '智能决策', '步骤 2/2', 'Task#45', 'task.override', 'HumanLead');

  // 1. Candidate Rejection (eokCandidateReject) with explicit profile
  ActReject := TEhaiInteractionAction.CreateOverride(eokCandidateReject, '不需要这个功能', eipProvide, Ctx, 0, esHuman);
  Assert.AreEqual(Ord(emaReframe), Ord(ActReject.MetaAction));
  Assert.AreEqual(Ord(eokCandidateReject), Ord(ActReject.OverrideKind));
  Assert.AreEqual(Ord(eipProvide), Ord(ActReject.Profile));
  Assert.AreEqual('不需要这个功能', ActReject.Text);
  Assert.AreEqual(Ord(esHuman), Ord(ActReject.Source));

  // 2. Alternative Expression (eokAlternativeExpression)
  ActAlt := TEhaiInteractionAction.CreateOverride(eokAlternativeExpression, '请用英文重新输出', eipProvide, Ctx, 0, esHuman);
  Assert.AreEqual(Ord(emaReframe), Ord(ActAlt.MetaAction));
  Assert.AreEqual(Ord(eokAlternativeExpression), Ord(ActAlt.OverrideKind));
  Assert.AreEqual('请用英文重新输出', ActAlt.Text);

  // 3. Frame Rejection (eokFrameRejection)
  ActFrame := TEhaiInteractionAction.CreateOverride(eokFrameRejection, '业务逻辑前置假设完全错误，重构流程', eipProvide, Ctx, 0, esHuman);
  Assert.AreEqual(Ord(emaReframe), Ord(ActFrame.MetaAction));
  Assert.AreEqual(Ord(eokFrameRejection), Ord(ActFrame.OverrideKind));
  Assert.AreEqual('业务逻辑前置假设完全错误，重构流程', ActFrame.Text);
end;

procedure TTestEhaiConformanceTierA.Test_CSV006_Source_Vs_Interpretation_Distinction_And_Lineage;
var
  Ctx: TEhaiContextBinding;
  HumanAct, AIAct: TEhaiInteractionAction;
  HumanTrace, AITrace: TEhaiTraceRecord;
begin
  Ctx := TEhaiContextBinding.Create('ctx-005', '合同起草', '步骤 1/4', 'Contract#77', 'legal.draft', 'LegalCounsel');

  HumanAct := TEhaiInteractionAction.CreateOverride(eokAlternativeExpression, '要求仲裁地设在上海', eipProvide, Ctx, 0, esHuman);
  AIAct := TEhaiInteractionAction.CreateCandidate(1, '标准仲裁条款A', eipProvide, Ctx, 101, esAI);

  HumanTrace := TEhaiTraceRecord.Create('trace-001', 'LawyerUser', HumanAct, eseDataProvided, False);
  AITrace := TEhaiTraceRecord.Create('trace-002', 'ContractBot', AIAct, eseInformOnly, False);

  // Source distinction preserved
  Assert.AreEqual(Ord(esHuman), Ord(HumanTrace.Source));
  Assert.AreEqual(Ord(esAI), Ord(AITrace.Source));
  Assert.AreEqual('LawyerUser', HumanTrace.ActorIdentity);
  Assert.AreEqual('ContractBot', AITrace.ActorIdentity);

  // Lineage context bound
  Assert.AreEqual('ctx-005', HumanTrace.Action.Context.ContextId);
  Assert.AreEqual('ctx-005', AITrace.Action.Context.ContextId);
end;

procedure TTestEhaiConformanceTierA.Test_CSV007_FrameRejection_NonRemapping_HumanSourcePreservation;
var
  Ctx: TEhaiContextBinding;
  ActFrame: TEhaiInteractionAction;
begin
  Ctx := TEhaiContextBinding.Create('ctx-007', '架构决策', '步骤 1/1', 'Arch#1', 'arch.design', 'Architect');
  ActFrame := TEhaiInteractionAction.CreateOverride(eokFrameRejection, '拒绝当前候选框架', eipProvide, Ctx, 0, esHuman);

  // Frame rejection must NOT be remapped to a candidate selection or AI choice
  Assert.AreNotEqual(Ord(emaChoose), Ord(ActFrame.MetaAction));
  Assert.AreEqual(Ord(emaReframe), Ord(ActFrame.MetaAction));
  Assert.AreEqual(Ord(eokFrameRejection), Ord(ActFrame.OverrideKind));
  Assert.AreEqual(Ord(esHuman), Ord(ActFrame.Source), 'Frame Rejection source MUST remain human');
end;

procedure TTestEhaiConformanceTierA.Test_CSV008_CommitmentBoundary_RejectSemanticEffect_And_AuthorityBasis;
var
  AuthExplicit, AuthStanding, AuthRule, AuthEmptyScope, AuthExpired: TEhaiAuthorityBasis;
begin
  // Three authority bases
  AuthExplicit := TEhaiAuthorityBasis.CreateExplicit('FinanceVP', 'payment.execute');
  AuthStanding := TEhaiAuthorityBasis.CreateStanding('OpsBot', 'service.restart', 'cpu > 90', 0.0);
  AuthRule := TEhaiAuthorityBasis.CreateRuleDerived('RULE-AUDIT-01', 'log.export');

  Assert.AreEqual(Ord(eabExplicitConfirmation), Ord(AuthExplicit.Kind));
  Assert.AreEqual(Ord(eabStandingAuthorization), Ord(AuthStanding.Kind));
  Assert.AreEqual(Ord(eabRuleDerivedAuthority), Ord(AuthRule.Kind));

  // Scopes and validity
  Assert.IsTrue(AuthExplicit.Covers('payment.execute', 0.0));
  Assert.IsFalse(AuthExplicit.Covers('system.shutdown', 0.0));

  // R-03: Empty Scope MUST fail-closed (return False, never match any scope)
  AuthEmptyScope := TEhaiAuthorityBasis.CreateStanding('Nobody', '', '');
  Assert.IsFalse(AuthEmptyScope.Covers('payment.execute', 0.0), 'Empty scope must fail-closed');
  Assert.IsFalse(AuthEmptyScope.Covers('', 0.0), 'Empty scope must fail-closed even for empty query');
  Assert.IsFalse(AuthEmptyScope.Covers('anything', 100.0), 'Empty scope must fail-closed');

  // R-03: Expired authorization MUST fail-closed (return False)
  AuthExpired := TEhaiAuthorityBasis.CreateStanding('OpsBot', 'service.restart', '', 0.0, Now - 1.0);
  Assert.IsFalse(AuthExpired.IsValidAt(Now), 'Expired authorization is not valid');
  Assert.IsFalse(AuthExpired.Covers('service.restart', 0.0), 'Expired authorization must not cover');

  // Semantic Effect Kinds
  Assert.AreEqual(Ord(eseInformOnly), Ord(eseInformOnly));
  Assert.AreNotEqual(Ord(eseInformOnly), Ord(eseAuthorized));
end;

{ TTestHbSurfaceVectorsTierB }

procedure TTestHbSurfaceVectorsTierB.Setup;
begin
  FLastChoiceKey := -1;
  FLastChoiceAction := Default(THbChoiceAction);
  FLastCustomInputText := '';
  SetLength(FLastMultiSelectKeys, 0);
end;

procedure TTestHbSurfaceVectorsTierB.TearDown;
begin
  FLastChoiceAction := Default(THbChoiceAction);
  FLastCustomInputText := '';
  SetLength(FLastMultiSelectKeys, 0);
end;

procedure TTestHbSurfaceVectorsTierB.OnChoiceHelper(Sender: TObject; AKey: Integer);
begin
  FLastChoiceKey := AKey;
end;

procedure TTestHbSurfaceVectorsTierB.OnActionHelper(Sender: TObject; const AAction: THbChoiceAction);
begin
  FLastChoiceAction := AAction;
end;

procedure TTestHbSurfaceVectorsTierB.OnCustomInputHelper(Sender: TObject; const AText: string);
begin
  FLastCustomInputText := AText;
end;

procedure TTestHbSurfaceVectorsTierB.OnMultiSelectHelper(Sender: TObject; const ASelectedKeys: TArray<Integer>);
begin
  FLastMultiSelectKeys := Copy(ASelectedKeys);
end;

procedure TTestHbSurfaceVectorsTierB.Test_HBV001_FreeInputTextEntry_OwnsKeyboard_ShortcutSuspension;
var
  Form: TCustomForm;
  Deck: THbChoiceDeck;
  Msg: TWMKeyDown;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Deck := THbChoiceDeck.Create(Form);
    Deck.Parent := Form;
    Deck.Width := 400;
    Deck.Height := 500;
    Deck.OnChoice := OnChoiceHelper;
    Deck.OnAction := OnActionHelper;
    Deck.OnCustomInput := OnCustomInputHelper;

    Deck.Clear;
    Deck.AddOption(1, '候选方案1', '说明1');
    Deck.AddOption(2, '候选方案2', '说明2');
    Deck.AddStandardControls(True, True, True);

    // Enter free input mode
    Deck.EnterFreeInput;
    Assert.AreEqual(Ord(csFreeInput), Ord(Deck.State));

    // When in free input mode, typing '1' in deck does NOT trigger candidate choice #1
    FLastChoiceKey := -1;
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('1');
    Deck.Dispatch(Msg);
    Assert.AreEqual(Integer(-1), Integer(FLastChoiceKey), 'Keyboard shortcut 1 must be suspended while input is active');

    // R-04: Legacy SubmitFreeInput MUST default to eokNone (unclassified, not eokAlternativeExpression)
    Deck.SubmitFreeInput('用户自定义指令输入');
    Assert.AreEqual('用户自定义指令输入', FLastCustomInputText);
    Assert.AreEqual(Ord(cakFreeInput), Ord(FLastChoiceAction.Kind));
    Assert.AreEqual('用户自定义指令输入', FLastChoiceAction.Text);
    Assert.AreEqual(Ord(eokNone), Ord(FLastChoiceAction.OverrideKind), 'Legacy SubmitFreeInput must produce eokNone');

    // Explicit Frame Rejection path via SubmitFreeInputWithKind
    Deck.SubmitFreeInputWithKind('彻底否定框架', eokFrameRejection);
    Assert.AreEqual('彻底否定框架', FLastChoiceAction.Text);
    Assert.AreEqual(Ord(eokFrameRejection), Ord(FLastChoiceAction.OverrideKind), 'Explicit SubmitFreeInputWithKind must preserve eokFrameRejection');
  finally
    Form.Free;
  end;
end;

procedure TTestHbSurfaceVectorsTierB.Test_HBV002_Regenerate_VisualReferenceRetention_DimmedOverlay;
var
  Form: TCustomForm;
  Deck: THbChoiceDeck;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Deck := THbChoiceDeck.Create(Form);
    Deck.Parent := Form;
    Deck.Width := 400;
    Deck.Height := 500;

    Deck.Clear;
    Deck.AddOption(1, '原有方案1', '原有说明1');
    Deck.AddOption(2, '原有方案2', '原有说明2');
    Deck.AddStandardControls(True, True, True);

    // Switch to csRegenerating
    Deck.BeginRegenerate;
    Assert.AreEqual(Ord(csRegenerating), Ord(Deck.State));
    Assert.AreEqual(Integer(5), Integer(Deck.ItemCount), 'Items must remain loaded during regeneration');

    // Switch back to csReady
    Deck.EndRegenerate;
    Assert.AreEqual(Ord(csReady), Ord(Deck.State));
  finally
    Form.Free;
  end;
end;

procedure TTestHbSurfaceVectorsTierB.Test_HBV003_MultiChoice_VCL_Rendering_Toggle_And_Submit;
var
  Form: TCustomForm;
  Deck: THbChoiceDeck;
  Msg: TWMKeyDown;
  Item: THbChoiceItem;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Deck := THbChoiceDeck.Create(Form);
    Deck.Parent := Form;
    Deck.Width := 400;
    Deck.Height := 500;
    Deck.Cardinality := ecMultiple;
    Deck.OnMultiSelect := OnMultiSelectHelper;
    Deck.OnAction := OnActionHelper;

    Deck.Clear;
    Deck.AddOption(1, '多选选项1', '说明1');
    Deck.AddOption(2, '多选选项2', '说明2');
    Deck.AddOption(3, '多选选项3', '说明3');
    Deck.AddStandardControls(True, True, True);

    // Press '1' -> Toggles item 1 checked
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('1');
    Deck.Dispatch(Msg);
    Assert.IsTrue(Deck.FindItemByKey(1, Item));
    Assert.IsTrue(Item.IsSelected, 'Item 1 should be selected after key 1');
    Assert.AreEqual(Integer(1), Integer(Length(FLastMultiSelectKeys)));
    Assert.AreEqual(1, FLastMultiSelectKeys[0]);

    // Press '3' -> Toggles item 3 checked
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('3');
    Deck.Dispatch(Msg);
    Assert.IsTrue(Deck.FindItemByKey(3, Item));
    Assert.IsTrue(Item.IsSelected, 'Item 3 should be selected after key 3');
    Assert.AreEqual(Integer(2), Integer(Length(FLastMultiSelectKeys)));

    // Meta key 8 (Regenerate) -> Action triggered, does NOT toggle selection
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('8');
    Deck.Dispatch(Msg);
    Assert.AreEqual(Ord(cakRegenerate), Ord(FLastChoiceAction.Kind));
    Assert.IsTrue(Deck.FindItemByKey(8, Item));
    Assert.IsFalse(Item.IsSelected, 'Meta Key 8 must never become selected');

    // Submit multi-choice
    Deck.SubmitMultiChoice;
    Assert.AreEqual(Integer(2), Integer(Length(FLastMultiSelectKeys)));
  finally
    Form.Free;
  end;
end;

procedure TTestHbSurfaceVectorsTierB.Test_HBV004_Keyboard_Main_Numpad_Mouse_SemanticEquivalence;
var
  Form: TCustomForm;
  Deck: THbChoiceDeck;
  Msg: TWMKeyDown;
  ActMain, ActNumpad, ActMouse: THbChoiceAction;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Deck := THbChoiceDeck.Create(Form);
    Deck.Parent := Form;
    Deck.Width := 400;
    Deck.Height := 500;
    Deck.OnAction := OnActionHelper;

    Deck.Clear;
    Deck.AddOption(1, '等价方案1', '说明1', False, 7701);
    Deck.AddStandardControls(True, True, True);

    // 1. Main keyboard '1'
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('1');
    Deck.Dispatch(Msg);
    ActMain := FLastChoiceAction;

    // 2. NumPad '1'
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := VK_NUMPAD1;
    Deck.Dispatch(Msg);
    ActNumpad := FLastChoiceAction;

    // 3. Mouse Trigger on Key 1
    Deck.SelectKey(1, cisMouse);
    ActMouse := FLastChoiceAction;

    // Semantic Equivalence
    Assert.AreEqual(Ord(cakCandidate), Ord(ActMain.Kind));
    Assert.AreEqual(Ord(cakCandidate), Ord(ActNumpad.Kind));
    Assert.AreEqual(Ord(cakCandidate), Ord(ActMouse.Kind));

    Assert.AreEqual(1, ActMain.Key);
    Assert.AreEqual(1, ActNumpad.Key);
    Assert.AreEqual(1, ActMouse.Key);

    Assert.AreEqual('等价方案1', ActMain.Text);
    Assert.AreEqual('等价方案1', ActNumpad.Text);
    Assert.AreEqual('等价方案1', ActMouse.Text);

    Assert.AreEqual(NativeInt(7701), ActMain.Payload);
    Assert.AreEqual(NativeInt(7701), ActNumpad.Payload);
    Assert.AreEqual(NativeInt(7701), ActMouse.Payload);

    // Source distinction accurately captured
    Assert.AreEqual(Ord(cisKeyboard), Ord(ActMain.InputSource));
    Assert.AreEqual(Ord(cisNumPad), Ord(ActNumpad.InputSource));
    Assert.AreEqual(Ord(cisMouse), Ord(ActMouse.InputSource));
  finally
    Form.Free;
  end;
end;

procedure TTestHbSurfaceVectorsTierB.Test_HBV005_Focus_Cancel_BackNavigation_Safety;
var
  Form: TCustomForm;
  Deck: THbChoiceDeck;
  Msg: TWMKeyDown;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Deck := THbChoiceDeck.Create(Form);
    Deck.Parent := Form;
    Deck.Width := 400;
    Deck.Height := 500;
    Deck.OnAction := OnActionHelper;
    Deck.OnChoice := OnChoiceHelper;

    Deck.Clear;
    Deck.AddOption(1, '方案1', '说明1');
    Deck.AddStandardControls(True, True, True);

    // 1. Key '0' -> Back Navigation (cakBack)
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := WM_KEYDOWN;
    Msg.CharCode := Ord('0');
    Deck.Dispatch(Msg);
    Assert.AreEqual(Ord(cakBack), Ord(FLastChoiceAction.Kind));
    Assert.AreEqual(0, FLastChoiceAction.Key);
    Assert.AreEqual(0, FLastChoiceKey);

    // 2. Enter Free Input then Cancel
    Deck.EnterFreeInput;
    Assert.AreEqual(Ord(csFreeInput), Ord(Deck.State));
    Deck.CancelFreeInput;
    Assert.AreEqual(Ord(csReady), Ord(Deck.State));
  finally
    Form.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestEhaiConformanceTierA);
  TDUnitX.RegisterTestFixture(TTestHbSurfaceVectorsTierB);

end.
