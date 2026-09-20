{ ============================================================================
  DeepBase.HB.Dialogs.Types - Cross-Framework Types for HB Dialogs & Wizards

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Shared type definitions for THbDialog, THbSummaryBar,
               THbWaterfallWizard (Vertical & Horizontal Accordion).
  ============================================================================ }

unit DeepBase.HB.Dialogs.Types;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Generics.Collections,
  System.JSON,
  System.DateUtils,
  DeepBase.HB.Core,
  DeepBase.HB.Touchpoint.Types;

type
  /// <summary>
  /// Semantic kind of modern dialog.
  /// </summary>
  THbDialogKind = (
    dkInfo,          // Information notice
    dkSuccess,       // Operation successful
    dkWarning,       // Non-blocking warning
    dkDanger,        // High-risk interception (P0 Fail-Closed)
    dkConfirm,       // General binary confirmation
    dkPrompt,        // Single-line text input
    dkPromptReason   // Multi-line justification / reject reason input
  );

  /// <summary>
  /// Dialog result action.
  /// </summary>
  THbDialogResult = (
    drNone,
    drOk,            // Confirm / Allow
    drCancel,        // Cancel / Reject / Dismiss
    drOnce,          // Allow once / Temporary override
    drDefer,         // Stash / Defer to queue
    drCustom         // Custom extension action
  );

  /// <summary>
  /// THbDialogOptions: Detailed configuration structure for THbDialog.
  /// </summary>
  THbDialogOptions = record
    Kind: THbDialogKind;
    Title: string;
    Subtitle: string;
    Summary: string;
    BoundaryNotice: string;
    PromptLabel: string;
    DefaultInput: string;
    IsInputMultiline: Boolean;
    ShowEvidenceFold: Boolean;
    EvidenceText: string;
    OkCaption: string;
    CancelCaption: string;
    OnceCaption: string;
    DeferCaption: string;
    IsDestructive: Boolean;
  end;

  /// <summary>
  /// Layout orientation for waterfall accordion wizard.
  /// </summary>
  THbWaterfallOrientation = (
    woVertical,      // Vertical stacked list (standard waterfall)
    woHorizontal     // Horizontal strip accordion (expanding columns)
  );

  /// <summary>
  /// Lifecycle state of a wizard step.
  /// </summary>
  THbStepState = (
    ssPending,       // Waiting for upstream prerequisites
    ssActive,        // Currently active and expanded
    ssCompleted,     // Finished and validated with summary
    ssError          // Validation failed
  );

  /// <summary>
  /// Data snapshot for a single step in a wizard.
  /// </summary>
  THbStepItem = record
    Index: Integer;
    StepKey: string;
    Title: string;
    SummaryText: string;
    State: THbStepState;
    IsExpanded: Boolean;
    ConfigPath: string;
    DataJson: string;
  end;

  /// <summary>
  /// Manages multi-step wizard state, fields, and session snapshot for dialogs (Framework-Agnostic RTL).
  /// </summary>
  THbDialogWizardSession = class(TInterfacedObject, IHbSnapshotProvider)
  private
    FSurfaceId: string;
    FControlId: string;
    FCurrentStep: Integer;
    FTotalSteps: Integer;
    FFieldValues: TDictionary<string, string>;
    FRestoreNotice: string;
  public
    constructor Create(const ASurfaceId: string = 'HbDialogWizard'; const AControlId: string = 'wizard_steps');
    destructor Destroy; override;

    procedure SetFieldValue(const AKey, AValue: string);
    function GetFieldValue(const AKey: string; const ADefault: string = ''): string;
    procedure SetStep(AStep, ATotal: Integer);

    // IHbSnapshotProvider
    function GetSurfaceId: string;
    function GetControlId: string;
    function CaptureSnapshot: string;
    procedure RestoreSnapshot(const APayload: string);

    property SurfaceId: string read FSurfaceId write FSurfaceId;
    property ControlId: string read FControlId write FControlId;
    property CurrentStep: Integer read FCurrentStep write FCurrentStep;
    property TotalSteps: Integer read FTotalSteps write FTotalSteps;
    property RestoreNotice: string read FRestoreNotice;
  end;

implementation

{ THbDialogWizardSession }

constructor THbDialogWizardSession.Create(const ASurfaceId, AControlId: string);
begin
  inherited Create;
  FSurfaceId := ASurfaceId;
  FControlId := AControlId;
  FCurrentStep := 1;
  FTotalSteps := 1;
  FFieldValues := TDictionary<string, string>.Create;
  FRestoreNotice := '';
end;

destructor THbDialogWizardSession.Destroy;
begin
  FFieldValues.Free;
  inherited Destroy;
end;

procedure THbDialogWizardSession.SetFieldValue(const AKey, AValue: string);
begin
  FFieldValues.AddOrSetValue(AKey, AValue);
end;

function THbDialogWizardSession.GetFieldValue(const AKey, ADefault: string): string;
begin
  if not FFieldValues.TryGetValue(AKey, Result) then
    Result := ADefault;
end;

procedure THbDialogWizardSession.SetStep(AStep, ATotal: Integer);
begin
  FCurrentStep := AStep;
  FTotalSteps := ATotal;
end;

function THbDialogWizardSession.GetSurfaceId: string;
begin
  Result := FSurfaceId;
end;

function THbDialogWizardSession.GetControlId: string;
begin
  Result := FControlId;
end;

function THbDialogWizardSession.CaptureSnapshot: string;
var
  Obj, FieldsObj: TJSONObject;
  Pair: TPair<string, string>;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('surface_id', FSurfaceId);
    Obj.AddPair('control_id', FControlId);
    Obj.AddPair('current_step', TJSONNumber.Create(FCurrentStep));
    Obj.AddPair('total_steps', TJSONNumber.Create(FTotalSteps));
    Obj.AddPair('timestamp_utc', TJSONNumber.Create(DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000));

    FieldsObj := TJSONObject.Create;
    for Pair in FFieldValues do
      FieldsObj.AddPair(Pair.Key, Pair.Value);
    Obj.AddPair('fields', FieldsObj);

    Result := Obj.ToJSON;
  finally
    Obj.Free;
  end;
end;

procedure THbDialogWizardSession.RestoreSnapshot(const APayload: string);
var
  Val: TJSONValue;
  Obj, FieldsObj: TJSONObject;
  I: Integer;
  Pair: TJSONPair;
begin
  FRestoreNotice := '';
  if Trim(APayload) = '' then
    Exit;

  Val := TJSONObject.ParseJSONValue(APayload);
  if Val = nil then
    Exit;

  try
    if Val is TJSONObject then
    begin
      Obj := TJSONObject(Val);
      if Obj.Values['current_step'] is TJSONNumber then
        FCurrentStep := TJSONNumber(Obj.Values['current_step']).AsInt;
      if Obj.Values['total_steps'] is TJSONNumber then
        FTotalSteps := TJSONNumber(Obj.Values['total_steps']).AsInt;

      if Obj.Values['fields'] is TJSONObject then
      begin
        FieldsObj := TJSONObject(Obj.Values['fields']);
        FFieldValues.Clear;
        for I := 0 to FieldsObj.Count - 1 do
        begin
          Pair := FieldsObj.Pairs[I];
          FFieldValues.AddOrSetValue(Pair.JsonString.Value, Pair.JsonValue.Value);
        end;
      end;
      FRestoreNotice := '已为您恢复上次推演进度';
    end;
  finally
    Val.Free;
  end;
end;

end.
