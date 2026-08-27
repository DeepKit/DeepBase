{ ============================================================================
  DeepBase.VCL.HB.AI - Dual-Pane AI Console & Collaboration Workspace for VCL

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: THbAIConsole:
               - Dual-Pane layout: Left master orchestration + Right closable scratchpad
               - Model switcher (aimLocal8B, aimCloudPro, aimCloudFlash)
               - Thought fold (Chain-of-Thought with time & evidence counts)
               - Diff review propose cards with Ctrl+Enter one-click adoption
  ============================================================================ }

unit DeepBase.VCL.HB.AI;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  DeepBase.HB.Core,
  DeepBase.HB.AI.Types,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Controls,
  DeepBase.VCL.HB.Cards;

type
  THbPromptSubmitEvent = procedure(Sender: TObject; const APrompt: string; AModel: THbAIModelKind) of object;
  THbDiffDecisionEvent = procedure(Sender: TObject; const AProposeId: string; AAccepted: Boolean) of object;

  /// <summary>
  /// THbAIConsole: Dual-Pane AI Collaboration Console for VCL.
  /// </summary>
  THbAIConsole = class(TCustomControl)
  private
    FSelectedModel: THbAIModelKind;
    FTokenCount: Int64;
    FEstimatedCost: Double;
    FThoughts: TList<THbThoughtStep>;
    FProposals: TList<THbProposeDiffItem>;
    FIsAuxDrawerOpen: Boolean;
    FAuxDrawerWidth: Integer;
    FScratchpadText: string;
    FOnPromptSubmit: THbPromptSubmitEvent;
    FOnDiffDecision: THbDiffDecisionEvent;

    // Sub-controls
    FPnlTopToolbar: TPanel;
    FPnlSplitHost: TPanel;
    FPnlLeftMain: TPanel;
    FPnlRightAux: TPanel;
    FBtnModel: THbButton;
    FLblTokenStats: TLabel;
    FBtnToggleAux: THbButton;
    FScrollMain: TScrollBox;
    FPnlPromptBar: TPanel;
    FEdtPrompt: TEdit;
    FBtnSend: THbButton;
    FMmoScratchpad: TMemo;

    procedure SetSelectedModel(Value: THbAIModelKind);
    procedure SetIsAuxDrawerOpen(Value: Boolean);
    procedure SetTokenCount(Value: Int64);
    function GetScratchpadText: string;
    procedure SetScratchpadText(const Value: string);
    procedure OnModelBtnClick(Sender: TObject);
    procedure OnToggleAuxClick(Sender: TObject);
    procedure OnSendClick(Sender: TObject);
    procedure OnAdoptBtnClick(Sender: TObject);
    procedure OnPromptKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure UpdateModelButtonCaption;
  protected
    procedure Resize; override;
    procedure CreateHandle; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddThoughtStep(const ASummary: string; const ADetails: string = '';
      ADurationMs: Integer = 0; AEvidenceCount: Integer = 0);
    procedure AddDiffProposal(const AId, ATargetKey, ATargetLabel, AOldVal, ANewVal, AReason: string);
    procedure Clear;

    property Thoughts: TList<THbThoughtStep> read FThoughts;
    property Proposals: TList<THbProposeDiffItem> read FProposals;
    property ScratchpadText: string read GetScratchpadText write SetScratchpadText;
  published
    property Align;
    property Anchors;
    property SelectedModel: THbAIModelKind read FSelectedModel write SetSelectedModel default aimCloudPro;
    property TokenCount: Int64 read FTokenCount write SetTokenCount default 0;
    property IsAuxDrawerOpen: Boolean read FIsAuxDrawerOpen write SetIsAuxDrawerOpen default True;
    property AuxDrawerWidth: Integer read FAuxDrawerWidth write FAuxDrawerWidth default 320;
    property OnPromptSubmit: THbPromptSubmitEvent read FOnPromptSubmit write FOnPromptSubmit;
    property OnDiffDecision: THbDiffDecisionEvent read FOnDiffDecision write FOnDiffDecision;
  end;

implementation

{ THbAIConsole }

constructor THbAIConsole.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 800;
  Height := 550;
  FSelectedModel := aimCloudPro;
  FTokenCount := 0;
  FEstimatedCost := 0.0;
  FIsAuxDrawerOpen := True;
  FAuxDrawerWidth := 300;
  FScratchpadText := '// 旁路证据与临时草稿记事区 (不污染主会话上下文)...';
  FThoughts := TList<THbThoughtStep>.Create;
  FProposals := TList<THbProposeDiffItem>.Create;

  DoubleBuffered := True;

  // 1. Top Toolbar (Model & Pricing Switcher)
  FPnlTopToolbar := TPanel.Create(Self);
  FPnlTopToolbar.Align := alTop;
  FPnlTopToolbar.Height := 42;
  FPnlTopToolbar.BevelOuter := bvNone;
  FPnlTopToolbar.Parent := Self;

  FBtnModel := THbButton.Create(FPnlTopToolbar);
  FBtnModel.Align := alLeft;
  FBtnModel.Width := 300;
  FBtnModel.Kind := bkSoft;
  FBtnModel.OnClick := OnModelBtnClick;
  FBtnModel.Parent := FPnlTopToolbar;
  UpdateModelButtonCaption;

  FLblTokenStats := TLabel.Create(FPnlTopToolbar);
  FLblTokenStats.Align := alLeft;
  FLblTokenStats.Caption := '  消耗: 0 Tokens (预估: ¥0.00)';
  FLblTokenStats.Parent := FPnlTopToolbar;

  FBtnToggleAux := THbButton.Create(FPnlTopToolbar);
  FBtnToggleAux.Align := alRight;
  FBtnToggleAux.Width := 120;
  FBtnToggleAux.Caption := '▶ 旁路推演抽屉';
  FBtnToggleAux.Kind := bkSoft;
  FBtnToggleAux.OnClick := OnToggleAuxClick;
  FBtnToggleAux.Parent := FPnlTopToolbar;

  // 2. Split Host Container
  FPnlSplitHost := TPanel.Create(Self);
  FPnlSplitHost.Align := alClient;
  FPnlSplitHost.BevelOuter := bvNone;
  FPnlSplitHost.Parent := Self;

  // 3. Right Aux Drawer
  FPnlRightAux := TPanel.Create(FPnlSplitHost);
  FPnlRightAux.Align := alRight;
  FPnlRightAux.Width := FAuxDrawerWidth;
  FPnlRightAux.BevelOuter := bvNone;
  FPnlRightAux.Parent := FPnlSplitHost;

  FMmoScratchpad := TMemo.Create(FPnlRightAux);
  FMmoScratchpad.Align := alClient;
  FMmoScratchpad.Parent := FPnlRightAux;

  // 4. Left Main Workspace
  FPnlLeftMain := TPanel.Create(FPnlSplitHost);
  FPnlLeftMain.Align := alClient;
  FPnlLeftMain.BevelOuter := bvNone;
  FPnlLeftMain.Parent := FPnlSplitHost;

  // 5. Prompt Bar
  FPnlPromptBar := TPanel.Create(FPnlLeftMain);
  FPnlPromptBar.Align := alBottom;
  FPnlPromptBar.Height := 46;
  FPnlPromptBar.BevelOuter := bvNone;
  FPnlPromptBar.Parent := FPnlLeftMain;

  FBtnSend := THbButton.Create(FPnlPromptBar);
  FBtnSend.Align := alRight;
  FBtnSend.Width := 80;
  FBtnSend.Caption := '发送 ▶';
  FBtnSend.Kind := bkPrimary;
  FBtnSend.OnClick := OnSendClick;
  FBtnSend.Parent := FPnlPromptBar;

  FEdtPrompt := TEdit.Create(FPnlPromptBar);
  FEdtPrompt.Align := alClient;
  FEdtPrompt.OnKeyDown := OnPromptKeyDown;
  FEdtPrompt.Parent := FPnlPromptBar;

  // 6. Main Scrollbox (Thoughts + Diff cards)
  FScrollMain := TScrollBox.Create(FPnlLeftMain);
  FScrollMain.Align := alClient;
  FScrollMain.Parent := FPnlLeftMain;
end;

destructor THbAIConsole.Destroy;
begin
  FThoughts.Free;
  FProposals.Free;
  inherited;
end;

procedure THbAIConsole.Resize;
begin
  inherited;
  if Assigned(FPnlRightAux) then
    FPnlRightAux.Width := FAuxDrawerWidth;
end;

procedure THbAIConsole.CreateHandle;
begin
  inherited;
  if Assigned(FMmoScratchpad) and (FScratchpadText <> '') then
    FMmoScratchpad.Lines.Text := FScratchpadText;
  if Assigned(FEdtPrompt) then
    FEdtPrompt.TextHint := '输入指令或输入 / 呼出 Slash 快捷指令 (Enter 发送)...';
end;

procedure THbAIConsole.UpdateModelButtonCaption;
begin
  if not Assigned(FBtnModel) then
    Exit;

  case FSelectedModel of
    aimLocal8B:    FBtnModel.Caption := '⚡ 本地离线 8B (SenseVoice/0延迟) ▼';
    aimCloudPro:   FBtnModel.Caption := '🚀 云端深度推理 (DeepSeek-R1) ▼';
    aimCloudFlash: FBtnModel.Caption := '⚡ 云端快速轻量 (Claude 3.5) ▼';
  end;
end;

function THbAIConsole.GetScratchpadText: string;
begin
  if Assigned(FMmoScratchpad) and FMmoScratchpad.HandleAllocated then
    Result := FMmoScratchpad.Lines.Text
  else
    Result := FScratchpadText;
end;

procedure THbAIConsole.SetScratchpadText(const Value: string);
begin
  FScratchpadText := Value;
  if Assigned(FMmoScratchpad) and FMmoScratchpad.HandleAllocated then
    FMmoScratchpad.Lines.Text := Value;
end;

procedure THbAIConsole.SetSelectedModel(Value: THbAIModelKind);
begin
  FSelectedModel := Value;
  UpdateModelButtonCaption;
end;

procedure THbAIConsole.SetIsAuxDrawerOpen(Value: Boolean);
begin
  if FIsAuxDrawerOpen <> Value then
  begin
    FIsAuxDrawerOpen := Value;
    if Assigned(FPnlRightAux) then
      FPnlRightAux.Visible := FIsAuxDrawerOpen;
    if Assigned(FBtnToggleAux) then
    begin
      if FIsAuxDrawerOpen then
        FBtnToggleAux.Caption := '▶ 旁路推演抽屉'
      else
        FBtnToggleAux.Caption := '◀ 展开推演抽屉';
    end;
  end;
end;

procedure THbAIConsole.SetTokenCount(Value: Int64);
begin
  FTokenCount := Value;
  FEstimatedCost := (FTokenCount / 1000.0) * 0.002;
  if Assigned(FLblTokenStats) then
    FLblTokenStats.Caption := Format('  消耗: %d Tokens (预估: ¥%.4f)', [FTokenCount, FEstimatedCost]);
end;

procedure THbAIConsole.OnModelBtnClick(Sender: TObject);
begin
  // Cycle through models or show popup menu
  case FSelectedModel of
    aimLocal8B:    SetSelectedModel(aimCloudPro);
    aimCloudPro:   SetSelectedModel(aimCloudFlash);
    aimCloudFlash: SetSelectedModel(aimLocal8B);
  end;
end;

procedure THbAIConsole.OnToggleAuxClick(Sender: TObject);
begin
  SetIsAuxDrawerOpen(not FIsAuxDrawerOpen);
end;

procedure THbAIConsole.OnSendClick(Sender: TObject);
var
  P: string;
begin
  P := Trim(FEdtPrompt.Text);
  if P <> '' then
  begin
    FEdtPrompt.Text := '';
    if Assigned(FOnPromptSubmit) then
      FOnPromptSubmit(Self, P, FSelectedModel);
  end;
end;

procedure THbAIConsole.OnPromptKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (ssCtrl in Shift) then
  begin
    Key := 0;
    if (FProposals.Count > 0) and Assigned(FOnDiffDecision) then
      FOnDiffDecision(Self, FProposals[0].Id, True);
  end
  else if (Key = VK_RETURN) and not (ssShift in Shift) then
  begin
    Key := 0;
    OnSendClick(Self);
  end;
end;

procedure THbAIConsole.AddThoughtStep(const ASummary, ADetails: string; ADurationMs, AEvidenceCount: Integer);
var
  Step: THbThoughtStep;
  Card: THbCard;
  LblTitle, LblDetail: TLabel;
begin
  Step.StepIndex := FThoughts.Count + 1;
  Step.TimestampStr := FormatDateTime('hh:nn:ss.zzz', Now);
  Step.Summary := ASummary;
  Step.DetailLog := ADetails;
  Step.DurationMs := ADurationMs;
  Step.EvidenceCount := AEvidenceCount;
  FThoughts.Add(Step);

  if Assigned(FScrollMain) then
  begin
    Card := THbCard.Create(FScrollMain);
    Card.Parent := FScrollMain;
    Card.Align := alTop;
    Card.Height := Round(56 * (CurrentPPI / 96.0));
    Card.Margins.SetBounds(Round(8 * (CurrentPPI / 96.0)), Round(4 * (CurrentPPI / 96.0)), Round(8 * (CurrentPPI / 96.0)), Round(4 * (CurrentPPI / 96.0)));
    Card.AlignWithMargins := True;
    Card.Kind := ckSurface;

    LblTitle := TLabel.Create(Card);
    LblTitle.Parent := Card;
    LblTitle.Left := Round(12 * (CurrentPPI / 96.0));
    LblTitle.Top := Round(8 * (CurrentPPI / 96.0));
    LblTitle.Font.Style := [fsBold];
    LblTitle.Caption := Format('🧠 思考节点 #%d [%dms | %d证据]: %s', [Step.StepIndex, ADurationMs, AEvidenceCount, ASummary]);

    LblDetail := TLabel.Create(Card);
    LblDetail.Parent := Card;
    LblDetail.Left := Round(12 * (CurrentPPI / 96.0));
    LblDetail.Top := Round(30 * (CurrentPPI / 96.0));
    LblDetail.Font.Size := 9;
    LblDetail.Caption := ADetails;
  end;
end;

procedure THbAIConsole.AddDiffProposal(const AId, ATargetKey, ATargetLabel, AOldVal, ANewVal, AReason: string);
var
  Prop: THbProposeDiffItem;
  Card: THbCard;
  LblTitle, LblDiff: TLabel;
  BtnAdopt: THbButton;
begin
  Prop.Id := AId;
  Prop.TargetKey := ATargetKey;
  Prop.TargetLabel := ATargetLabel;
  Prop.OldValue := AOldVal;
  Prop.NewValue := ANewVal;
  Prop.Reason := AReason;
  Prop.Status := psPending;
  Prop.TimestampStr := FormatDateTime('hh:nn:ss', Now);
  FProposals.Add(Prop);

  if Assigned(FScrollMain) then
  begin
    Card := THbCard.Create(FScrollMain);
    Card.Parent := FScrollMain;
    Card.Align := alTop;
    Card.Height := Round(84 * (CurrentPPI / 96.0));
    Card.Margins.SetBounds(Round(8 * (CurrentPPI / 96.0)), Round(4 * (CurrentPPI / 96.0)), Round(8 * (CurrentPPI / 96.0)), Round(4 * (CurrentPPI / 96.0)));
    Card.AlignWithMargins := True;
    Card.Kind := ckSurface;

    LblTitle := TLabel.Create(Card);
    LblTitle.Parent := Card;
    LblTitle.Left := Round(12 * (CurrentPPI / 96.0));
    LblTitle.Top := Round(8 * (CurrentPPI / 96.0));
    LblTitle.Font.Style := [fsBold];
    LblTitle.Caption := '📝 方案建议: ' + ATargetLabel + ' (' + AReason + ')';

    LblDiff := TLabel.Create(Card);
    LblDiff.Parent := Card;
    LblDiff.Left := Round(12 * (CurrentPPI / 96.0));
    LblDiff.Top := Round(30 * (CurrentPPI / 96.0));
    LblDiff.Caption := '原值: ' + AOldVal + '  ➔  新值: ' + ANewVal;

    BtnAdopt := THbButton.Create(Card);
    BtnAdopt.Parent := Card;
    BtnAdopt.SetBounds(Card.Width - Round(120 * (CurrentPPI / 96.0)), Round(16 * (CurrentPPI / 96.0)), Round(100 * (CurrentPPI / 96.0)), Round(32 * (CurrentPPI / 96.0)));
    BtnAdopt.Anchors := [akTop, akRight];
    BtnAdopt.Caption := '✓ 一键采纳';
    BtnAdopt.Kind := bkPrimary;
    BtnAdopt.Tag := FProposals.Count - 1;
    BtnAdopt.OnClick := OnAdoptBtnClick;
  end;
end;

procedure THbAIConsole.OnAdoptBtnClick(Sender: TObject);
var
  Idx: Integer;
begin
  if Sender is TComponent then
  begin
    Idx := TComponent(Sender).Tag;
    if (Idx >= 0) and (Idx < FProposals.Count) and Assigned(FOnDiffDecision) then
      FOnDiffDecision(Self, FProposals[Idx].Id, True);
  end;
end;

procedure THbAIConsole.Clear;
begin
  FThoughts.Clear;
  FProposals.Clear;
  SetTokenCount(0);
  if Assigned(FScrollMain) then
  begin
    while FScrollMain.ControlCount > 0 do
      FScrollMain.Controls[0].Free;
  end;
end;

end.
