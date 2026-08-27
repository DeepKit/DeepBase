{ ============================================================================
  DeepBase.FMX.HB.AI - Dual-Pane AI Console for FMX

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform)
  Description: THbFmxAIConsole for FMX.
  ============================================================================ }

unit DeepBase.FMX.HB.AI;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  DeepBase.HB.Core,
  DeepBase.HB.AI.Types,
  DeepBase.FMX.HB.Theme;

type
  /// <summary>
  /// THbFmxAIConsole: AI Console for FMX.
  /// </summary>
  THbFmxAIConsole = class(TControl)
  private
    FSelectedModel: THbAIModelKind;
    FTokenCount: Int64;
    FThoughts: TList<THbThoughtStep>;
    FProposals: TList<THbProposeDiffItem>;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddThoughtStep(const ASummary: string; const ADetails: string = '';
      ADurationMs: Integer = 0; AEvidenceCount: Integer = 0);
    procedure AddDiffProposal(const AId, ATargetKey, ATargetLabel, AOldVal, ANewVal, AReason: string);
    procedure Clear;

    property Thoughts: TList<THbThoughtStep> read FThoughts;
    property Proposals: TList<THbProposeDiffItem> read FProposals;
  published
    property Align;
    property SelectedModel: THbAIModelKind read FSelectedModel write FSelectedModel default aimCloudPro;
    property TokenCount: Int64 read FTokenCount write FTokenCount default 0;
  end;

implementation

{ THbFmxAIConsole }

constructor THbFmxAIConsole.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 600;
  Height := 400;
  FSelectedModel := aimCloudPro;
  FTokenCount := 0;
  FThoughts := TList<THbThoughtStep>.Create;
  FProposals := TList<THbProposeDiffItem>.Create;
end;

destructor THbFmxAIConsole.Destroy;
begin
  FThoughts.Free;
  FProposals.Free;
  inherited;
end;

procedure THbFmxAIConsole.AddThoughtStep(const ASummary, ADetails: string; ADurationMs, AEvidenceCount: Integer);
var
  Step: THbThoughtStep;
begin
  Step.StepIndex := FThoughts.Count + 1;
  Step.TimestampStr := FormatDateTime('hh:nn:ss.zzz', Now);
  Step.Summary := ASummary;
  Step.DetailLog := ADetails;
  Step.DurationMs := ADurationMs;
  Step.EvidenceCount := AEvidenceCount;
  FThoughts.Add(Step);
end;

procedure THbFmxAIConsole.AddDiffProposal(const AId, ATargetKey, ATargetLabel, AOldVal, ANewVal, AReason: string);
var
  Prop: THbProposeDiffItem;
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
end;

procedure THbFmxAIConsole.Clear;
begin
  FThoughts.Clear;
  FProposals.Clear;
  FTokenCount := 0;
end;

end.
