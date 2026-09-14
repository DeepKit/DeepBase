{ ============================================================================
  DeepBase.VCL.HB.Choice - Modern Token-Driven 0-9 Choice Deck Component

  Version: 2.1 (Delphi 13.1 on Win64)
  Description: THbChoiceDeck - Universal AI Choice Interaction Standard Control:
               - 1-7 Contextual options (Key 1 can be Recommended)
               - 8 Fixed control: Regenerate (Contextual re-generation)
               - 9 Fixed control: Human Override / Free Input (Frame Rejection)
               - 0 Fixed control: Navigate Back (Pure navigation)
                - Decision Cardinality: ecSingle, ecMultiple (L4 §5.5, CSV-003)
               - Frame Rejection Tri-State: eokCandidateReject, eokAlternativeExpression, eokFrameRejection
               - Multi-modal action abstraction: THbChoiceAction & THbChoiceInputSource
               - 4 Layout modes: clmDeck, clmRow, clmNumberedList, clmInline
               - Truthful State Machine: csReady, csChoosing, csRegenerating,
                 csFreeInput, csLoading, csNoReliableCandidates, csDisabled, csError
               - Active Choice Surface arbitration & Text Entry Owns Keyboard rule
               - High-DPI GDI+ vector rendering, WCAG AA contrast
               - Verified 100% backward-compatible with v1.0 & v2.0 callers
  ============================================================================ }

unit DeepBase.VCL.HB.Choice;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Math,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
  DeepBase.HB.Core,
  DeepBase.EHAI.Types,
  DeepBase.HB.Choice.Types,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Controls;

type
  /// <summary>
  /// THbChoiceDeck: Universal AI Choice Interaction Standard Component for VCL.
  /// </summary>
  THbChoiceDeck = class(THbCustomControl)
  private
    FItems: TList<THbChoiceItem>;
    FSelectedIndex: Integer;
    FHoverIndex: Integer;
    FPressedIndex: Integer;
    FItemHeight: Integer;
    FItemSpacing: Integer;
    FLayoutMode: THbChoiceLayoutMode;
    FState: THbChoiceState;
    FFreeInputMode: THbChoiceFreeInputMode;
    FCardinality: TEhaiCardinality;
    FDefaultProfile: TEhaiInvolvementProfile;
    FContextBinding: TEhaiContextBinding;
    FContextTitle: string;
    FStepInfo: string;
    FStatusMessage: string;
    FIsActiveChoiceSurface: Boolean;

    // Built-in Free Input components
    FInlineEdit: TEdit;
    FBtnSubmit: THbButton;
    FBtnCancel: THbButton;

    // Events
    FOnChoice: THbChoiceEvent;
    FOnCustomInput: THbChoiceInputEvent;
    FOnAction: THbChoiceActionEvent;
    FOnFreeInputRequested: THbChoiceFreeInputRequestEvent;
    FOnStateChanged: TNotifyEvent;
    FOnMultiSelect: THbChoiceMultiSelectEvent;

    procedure SetSelectedIndex(Value: Integer);
    procedure SetLayoutMode(Value: THbChoiceLayoutMode);
    procedure SetState(Value: THbChoiceState);
    procedure SetCardinality(Value: TEhaiCardinality);
    procedure SetContextTitle(const Value: string);
    procedure SetStepInfo(const Value: string);
    procedure SetStatusMessage(const Value: string);
    procedure SetIsActiveChoiceSurface(Value: Boolean);

    function ItemIndexAt(X, Y: Integer): Integer;
    function GetItemCount: Integer;
    function GetItem(Index: Integer): THbChoiceItem;
    procedure SetItem(Index: Integer; const Value: THbChoiceItem);

    function GetHeaderHeight: Integer;
    procedure UpdateInlineEditLayout;
    procedure OnInlineEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure OnSubmitClick(Sender: TObject);
    procedure OnCancelClick(Sender: TObject);
  protected
    procedure Paint; override;
    procedure PaintDeckLayout(Graphics: TGPGraphics; const Tokens: THbTokens; TopOffset: Integer);
    procedure PaintRowLayout(Graphics: TGPGraphics; const Tokens: THbTokens; TopOffset: Integer);
    procedure PaintNumberedListLayout(Graphics: TGPGraphics; const Tokens: THbTokens; TopOffset: Integer);
    procedure PaintInlineLayout(Graphics: TGPGraphics; const Tokens: THbTokens; TopOffset: Integer);
    procedure PaintStatusOverlay(Graphics: TGPGraphics; const Tokens: THbTokens; TopOffset: Integer);

    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure WMKeyDown(var Message: TWMKeyDown); message WM_KEYDOWN;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Item manipulation
    procedure Clear;
    procedure AddOption(AKey: Integer; const AText: string;
      const ADesc: string = ''; AIsRecommended: Boolean = False;
      APayload: NativeInt = 0; AIsSelected: Boolean = False;
      AOverrideKind: TEhaiOverrideKind = eokNone;
      ASource: TEhaiSource = esHuman);
    procedure AddStandardControls(AHasRegenerate: Boolean = True;
      AHasInput: Boolean = True; AHasBack: Boolean = True);
    procedure SetOptions(const AOptions: array of string; ARecommendedKey: Integer = 1);
    procedure SetCandidates(const ACandidates: array of THbChoiceItem;
      AAddStandardControls: Boolean = True);

    // Key selection & trigger
    procedure SelectKey(AKey: Integer; ASource: THbChoiceInputSource = cisProgrammatic);
    procedure TriggerAction(AKind: THbChoiceActionKind; AKey: Integer;
      const AText: string; APayload: NativeInt; ASource: THbChoiceInputSource);
    procedure TriggerActionWithOverride(AKind: THbChoiceActionKind; AKey: Integer;
      const AText: string; APayload: NativeInt; ASource: THbChoiceInputSource;
      AOverrideKind: TEhaiOverrideKind; ASemanticSource: TEhaiSource = esHuman;
      AProfile: TEhaiInvolvementProfile = eipJudge);
    procedure TriggerOverrideAction(AOverrideKind: TEhaiOverrideKind;
      const AText: string; APayload: NativeInt; ASource: THbChoiceInputSource);
    procedure TriggerMultiAction(const ASelectedKeys: array of Integer;
      APayload: NativeInt; ASource: THbChoiceInputSource);
    procedure SetItemEnabled(AKey: Integer; AEnabled: Boolean);
    function FindItemByKey(AKey: Integer; out AItem: THbChoiceItem): Boolean;
    function IndexOfKey(AKey: Integer): Integer;
    function ItemRect(AIndex: Integer): TRect;

    // Multi-choice operations (L4 §5.5, CSV-003)
    function GetSelectedKeys: TArray<Integer>;
    procedure SetItemChecked(AKey: Integer; AChecked: Boolean);
    procedure ToggleItemChecked(AKey: Integer);
    procedure SubmitMultiChoice(ASource: THbChoiceInputSource = cisProgrammatic);

    // State management
    procedure BeginRegenerate;
    procedure EndRegenerate;
    procedure SetNoReliableCandidates(const AMessage: string = '');
    procedure SetError(const AErrorMessage: string);
    procedure ResetToReady;
    procedure EnterFreeInput(const APrefillText: string = '');
    procedure CancelFreeInput;
    procedure SubmitFreeInput(const AText: string);
    procedure SubmitFreeInputWithKind(const AText: string; AOverrideKind: TEhaiOverrideKind);

    // Properties
    property Items[Index: Integer]: THbChoiceItem read GetItem write SetItem;
    property ItemCount: Integer read GetItemCount;
    property SelectedIndex: Integer read FSelectedIndex write SetSelectedIndex;
    property SelectedKeys: TArray<Integer> read GetSelectedKeys;
  published
    property Align;
    property Anchors;
    property Enabled;
    property TabStop default True;
    property Visible;
    property LayoutMode: THbChoiceLayoutMode read FLayoutMode write SetLayoutMode default clmDeck;
    property State: THbChoiceState read FState write SetState default csReady;
    property FreeInputMode: THbChoiceFreeInputMode read FFreeInputMode write FFreeInputMode default fimBuiltIn;
    property Cardinality: TEhaiCardinality read FCardinality write SetCardinality default ecSingle;
    property DefaultProfile: TEhaiInvolvementProfile read FDefaultProfile write FDefaultProfile default eipJudge;
    property ContextBinding: TEhaiContextBinding read FContextBinding write FContextBinding;
    property ContextTitle: string read FContextTitle write SetContextTitle;
    property StepInfo: string read FStepInfo write SetStepInfo;
    property StatusMessage: string read FStatusMessage write SetStatusMessage;
    property IsActiveChoiceSurface: Boolean read FIsActiveChoiceSurface write SetIsActiveChoiceSurface default True;
    property ItemHeight: Integer read FItemHeight write FItemHeight default 46;
    property ItemSpacing: Integer read FItemSpacing write FItemSpacing default 8;

    property OnAction: THbChoiceActionEvent read FOnAction write FOnAction;
    property OnChoice: THbChoiceEvent read FOnChoice write FOnChoice;
    property OnCustomInput: THbChoiceInputEvent read FOnCustomInput write FOnCustomInput;
    property OnFreeInputRequested: THbChoiceFreeInputRequestEvent read FOnFreeInputRequested write FOnFreeInputRequested;
    property OnStateChanged: TNotifyEvent read FOnStateChanged write FOnStateChanged;
    property OnMultiSelect: THbChoiceMultiSelectEvent read FOnMultiSelect write FOnMultiSelect;

    property OnClick;
    property OnEnter;
    property OnExit;
  end;

implementation

function CreateRoundRectPath(const Rect: TGPRectF; Radius: Single): TGPGraphicsPath;
var
  D: Single;
begin
  Result := TGPGraphicsPath.Create;
  D := Radius * 2.0;

  if (D > Rect.Width) or (D > Rect.Height) then
    D := Min(Rect.Width, Rect.Height);

  if D <= 0 then
  begin
    Result.AddRectangle(Rect);
    Exit;
  end;

  Result.AddArc(Rect.X, Rect.Y, D, D, 180, 90);
  Result.AddArc(Rect.X + Rect.Width - D, Rect.Y, D, D, 270, 90);
  Result.AddArc(Rect.X + Rect.Width - D, Rect.Y + Rect.Height - D, D, D, 0, 90);
  Result.AddArc(Rect.X, Rect.Y + Rect.Height - D, D, D, 90, 90);
  Result.CloseFigure;
end;

{ THbChoiceDeck }

constructor THbChoiceDeck.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TList<THbChoiceItem>.Create;
  FSelectedIndex := -1;
  FHoverIndex := -1;
  FPressedIndex := -1;
  FLayoutMode := clmDeck;
  FState := csReady;
  FFreeInputMode := fimBuiltIn;
  FCardinality := ecSingle;
  FDefaultProfile := eipJudge;
  FillChar(FContextBinding, SizeOf(FContextBinding), 0);
  FContextTitle := '';
  FStepInfo := '';
  FStatusMessage := '';
  FIsActiveChoiceSurface := True;
  FItemHeight := ScalePixels(46);
  FItemSpacing := ScalePixels(8);
  Width := ScalePixels(440);
  Height := ScalePixels(380);
  TabStop := True;
  DoubleBuffered := True;

  // Create built-in inline editor child controls
  FInlineEdit := TEdit.Create(Self);
  FInlineEdit.Parent := Self;
  FInlineEdit.Visible := False;
  FInlineEdit.OnKeyDown := OnInlineEditKeyDown;

  FBtnSubmit := THbButton.Create(Self);
  FBtnSubmit.Parent := Self;
  FBtnSubmit.Caption := '确认';
  FBtnSubmit.Kind := bkPrimary;
  FBtnSubmit.Visible := False;
  FBtnSubmit.OnClick := OnSubmitClick;

  FBtnCancel := THbButton.Create(Self);
  FBtnCancel.Parent := Self;
  FBtnCancel.Caption := '取消';
  FBtnCancel.Kind := bkGhost;
  FBtnCancel.Visible := False;
  FBtnCancel.OnClick := OnCancelClick;
end;

destructor THbChoiceDeck.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

procedure THbChoiceDeck.Resize;
begin
  inherited;
  if FState = csFreeInput then
    UpdateInlineEditLayout;
  Invalidate;
end;

procedure THbChoiceDeck.Clear;
begin
  FItems.Clear;
  FSelectedIndex := -1;
  FHoverIndex := -1;
  FPressedIndex := -1;
  if FState = csFreeInput then
    CancelFreeInput;
  FState := csReady;
  Invalidate;
end;

function THbChoiceDeck.GetItemCount: Integer;
begin
  Result := FItems.Count;
end;

function THbChoiceDeck.GetItem(Index: Integer): THbChoiceItem;
begin
  Result := FItems[Index];
end;

procedure THbChoiceDeck.SetItem(Index: Integer; const Value: THbChoiceItem);
begin
  FItems[Index] := Value;
  Invalidate;
end;

procedure THbChoiceDeck.SetSelectedIndex(Value: Integer);
begin
  if (Value >= -1) and (Value < FItems.Count) and (FSelectedIndex <> Value) then
  begin
    FSelectedIndex := Value;
    Invalidate;
  end;
end;

procedure THbChoiceDeck.SetLayoutMode(Value: THbChoiceLayoutMode);
begin
  if FLayoutMode <> Value then
  begin
    FLayoutMode := Value;
    Invalidate;
  end;
end;

procedure THbChoiceDeck.SetCardinality(Value: TEhaiCardinality);
begin
  if FCardinality <> Value then
  begin
    FCardinality := Value;
    Invalidate;
  end;
end;

procedure THbChoiceDeck.SetState(Value: THbChoiceState);
begin
  if FState <> Value then
  begin
    FState := Value;
    if FState = csFreeInput then
    begin
      UpdateInlineEditLayout;
      FInlineEdit.Visible := True;
      FBtnSubmit.Visible := True;
      FBtnCancel.Visible := True;
      if FInlineEdit.CanFocus and FInlineEdit.Showing then
      try
        FInlineEdit.SetFocus;
      except
      end;
    end
    else
    begin
      FInlineEdit.Visible := False;
      FBtnSubmit.Visible := False;
      FBtnCancel.Visible := False;
    end;

    if Assigned(FOnStateChanged) then
      FOnStateChanged(Self);
    Invalidate;
  end;
end;

procedure THbChoiceDeck.SetContextTitle(const Value: string);
begin
  if FContextTitle <> Value then
  begin
    FContextTitle := Value;
    FContextBinding.ContextTitle := Value;
    Invalidate;
  end;
end;

procedure THbChoiceDeck.SetStepInfo(const Value: string);
begin
  if FStepInfo <> Value then
  begin
    FStepInfo := Value;
    FContextBinding.StepInfo := Value;
    Invalidate;
  end;
end;

procedure THbChoiceDeck.SetStatusMessage(const Value: string);
begin
  if FStatusMessage <> Value then
  begin
    FStatusMessage := Value;
    Invalidate;
  end;
end;

procedure THbChoiceDeck.SetIsActiveChoiceSurface(Value: Boolean);
begin
  if FIsActiveChoiceSurface <> Value then
  begin
    FIsActiveChoiceSurface := Value;
    Invalidate;
  end;
end;

function THbChoiceDeck.GetHeaderHeight: Integer;
begin
  Result := 0;
  if (FContextTitle <> '') or (FStepInfo <> '') then
    Result := ScalePixels(38);
end;

procedure THbChoiceDeck.AddOption(AKey: Integer; const AText, ADesc: string;
  AIsRecommended: Boolean; APayload: NativeInt; AIsSelected: Boolean;
  AOverrideKind: TEhaiOverrideKind; ASource: TEhaiSource);
var
  Item: THbChoiceItem;
begin
  Item := THbChoiceItem.Create(AKey, AText, ADesc, AIsRecommended, True, APayload,
    AIsSelected, AOverrideKind, ASource);
  FItems.Add(Item);
  if (FSelectedIndex = -1) and (FItems.Count = 1) then
    FSelectedIndex := 0;
  Invalidate;
end;

procedure THbChoiceDeck.AddStandardControls(AHasRegenerate, AHasInput, AHasBack: Boolean);
begin
  if AHasRegenerate then
    AddOption(8, GetDefaultKeyLabel(8), '在当前上下文换一组候选');
  if AHasInput then
    AddOption(9, GetDefaultKeyLabel(9), '手动输入或打破预设框架');
  if AHasBack then
    AddOption(0, GetDefaultKeyLabel(0), '返回上一步');
end;

procedure THbChoiceDeck.SetOptions(const AOptions: array of string; ARecommendedKey: Integer);
var
  I, Key: Integer;
begin
  Clear;
  for I := 0 to High(AOptions) do
  begin
    Key := I + 1;
    if Key <= 7 then
      AddOption(Key, AOptions[I], '', Key = ARecommendedKey);
  end;
  AddStandardControls(True, True, True);
end;

procedure THbChoiceDeck.SetCandidates(const ACandidates: array of THbChoiceItem;
  AAddStandardControls: Boolean);
var
  I: Integer;
begin
  Clear;
  for I := 0 to High(ACandidates) do
    FItems.Add(ACandidates[I]);

  if AAddStandardControls then
    AddStandardControls(True, True, True);

  if (FSelectedIndex = -1) and (FItems.Count > 0) then
    FSelectedIndex := 0;
  Invalidate;
end;

function THbChoiceDeck.IndexOfKey(AKey: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FItems.Count - 1 do
    if FItems[I].Key = AKey then
      Exit(I);
end;

function THbChoiceDeck.FindItemByKey(AKey: Integer; out AItem: THbChoiceItem): Boolean;
var
  Idx: Integer;
begin
  Idx := IndexOfKey(AKey);
  if Idx >= 0 then
  begin
    AItem := FItems[Idx];
    Result := True;
  end
  else
    Result := False;
end;

procedure THbChoiceDeck.SetItemEnabled(AKey: Integer; AEnabled: Boolean);
var
  Idx: Integer;
  Item: THbChoiceItem;
begin
  Idx := IndexOfKey(AKey);
  if Idx >= 0 then
  begin
    Item := FItems[Idx];
    if Item.Enabled <> AEnabled then
    begin
      Item.Enabled := AEnabled;
      FItems[Idx] := Item;
      Invalidate;
    end;
  end;
end;

function THbChoiceDeck.GetSelectedKeys: TArray<Integer>;
var
  I, Count: Integer;
begin
  Count := 0;
  for I := 0 to FItems.Count - 1 do
    if FItems[I].IsSelected and (FItems[I].Kind = ckOption) then
      Inc(Count);

  SetLength(Result, Count);
  Count := 0;
  for I := 0 to FItems.Count - 1 do
    if FItems[I].IsSelected and (FItems[I].Kind = ckOption) then
    begin
      Result[Count] := FItems[I].Key;
      Inc(Count);
    end;
end;

procedure THbChoiceDeck.SetItemChecked(AKey: Integer; AChecked: Boolean);
var
  Idx: Integer;
  Item: THbChoiceItem;
begin
  Idx := IndexOfKey(AKey);
  if (Idx >= 0) and (FItems[Idx].Kind = ckOption) then
  begin
    Item := FItems[Idx];
    if Item.IsSelected <> AChecked then
    begin
      Item.IsSelected := AChecked;
      FItems[Idx] := Item;
      Invalidate;
      if Assigned(FOnMultiSelect) then
        FOnMultiSelect(Self, GetSelectedKeys);
    end;
  end;
end;

procedure THbChoiceDeck.ToggleItemChecked(AKey: Integer);
var
  Idx: Integer;
begin
  Idx := IndexOfKey(AKey);
  if (Idx >= 0) and (FItems[Idx].Kind = ckOption) then
    SetItemChecked(AKey, not FItems[Idx].IsSelected);
end;

procedure THbChoiceDeck.SubmitMultiChoice(ASource: THbChoiceInputSource);
var
  Keys: TArray<Integer>;
  Action: THbChoiceAction;
begin
  Keys := GetSelectedKeys;
  if Length(Keys) = 0 then
    Exit;

  Action := THbChoiceAction.CreateMulti(Keys, 0, ASource, FDefaultProfile, FContextBinding.ContextId);
  if Assigned(FOnAction) then
    FOnAction(Self, Action);
  if Assigned(FOnMultiSelect) then
    FOnMultiSelect(Self, Keys);
end;

procedure THbChoiceDeck.TriggerAction(AKind: THbChoiceActionKind; AKey: Integer;
  const AText: string; APayload: NativeInt; ASource: THbChoiceInputSource);
begin
  TriggerActionWithOverride(AKind, AKey, AText, APayload, ASource, eokNone, esHuman, FDefaultProfile);
end;

procedure THbChoiceDeck.TriggerActionWithOverride(AKind: THbChoiceActionKind; AKey: Integer;
  const AText: string; APayload: NativeInt; ASource: THbChoiceInputSource;
  AOverrideKind: TEhaiOverrideKind; ASemanticSource: TEhaiSource;
  AProfile: TEhaiInvolvementProfile);
var
  Action: THbChoiceAction;
  Handled: Boolean;
begin
  Action := THbChoiceAction.Create(AKind, AKey, AText, APayload, ASource,
    AOverrideKind, ASemanticSource, AProfile, FContextBinding.ContextId);

  // 1. Dispatch Unified Action Event
  if Assigned(FOnAction) then
    FOnAction(Self, Action);

  // 2. Dispatch Backward-Compatible Events
  if Assigned(FOnChoice) then
    FOnChoice(Self, AKey);

  // 3. Special handling for Key 9 (Free Input)
  if AKey = 9 then
  begin
    if Assigned(FOnCustomInput) then
      FOnCustomInput(Self, AText);

    Handled := False;
    if Assigned(FOnFreeInputRequested) then
      FOnFreeInputRequested(Self, Handled);

    if not Handled and (FFreeInputMode = fimBuiltIn) then
      EnterFreeInput;
  end;
end;

procedure THbChoiceDeck.TriggerOverrideAction(AOverrideKind: TEhaiOverrideKind;
  const AText: string; APayload: NativeInt; ASource: THbChoiceInputSource);
begin
  TriggerActionWithOverride(cakFreeInput, 9, AText, APayload, ASource,
    AOverrideKind, esHuman, eipProvide);
end;

procedure THbChoiceDeck.TriggerMultiAction(const ASelectedKeys: array of Integer;
  APayload: NativeInt; ASource: THbChoiceInputSource);
var
  Action: THbChoiceAction;
  KeysArray: TArray<Integer>;
  I: Integer;
begin
  Action := THbChoiceAction.CreateMulti(ASelectedKeys, APayload, ASource,
    FDefaultProfile, FContextBinding.ContextId);

  if Assigned(FOnAction) then
    FOnAction(Self, Action);

  if Assigned(FOnMultiSelect) then
  begin
    SetLength(KeysArray, Length(ASelectedKeys));
    for I := 0 to High(ASelectedKeys) do
      KeysArray[I] := ASelectedKeys[I];
    FOnMultiSelect(Self, KeysArray);
  end;
end;

procedure THbChoiceDeck.SelectKey(AKey: Integer; ASource: THbChoiceInputSource);
var
  Idx: Integer;
  Item: THbChoiceItem;
begin
  Idx := IndexOfKey(AKey);
  if (Idx >= 0) and FItems[Idx].Enabled then
  begin
    Item := FItems[Idx];
    FSelectedIndex := Idx;

    if (FCardinality = ecMultiple) and (Item.Kind = ckOption) then
    begin
      ToggleItemChecked(AKey);
    end
    else
    begin
      Invalidate;
      TriggerAction(ChoiceKindToActionKind(Item.Kind), Item.Key, Item.Text, Item.Payload, ASource);
    end;
  end;
end;

procedure THbChoiceDeck.BeginRegenerate;
begin
  SetState(csRegenerating);
end;

procedure THbChoiceDeck.EndRegenerate;
begin
  SetState(csReady);
end;

procedure THbChoiceDeck.SetNoReliableCandidates(const AMessage: string);
begin
  if AMessage <> '' then
    FStatusMessage := AMessage
  else
    FStatusMessage := '当前信息还不足以给出可靠候选。';
  SetState(csNoReliableCandidates);
end;

procedure THbChoiceDeck.SetError(const AErrorMessage: string);
begin
  FStatusMessage := AErrorMessage;
  SetState(csError);
end;

procedure THbChoiceDeck.ResetToReady;
begin
  FStatusMessage := '';
  SetState(csReady);
end;

procedure THbChoiceDeck.EnterFreeInput(const APrefillText: string);
begin
  FInlineEdit.Text := APrefillText;
  SetState(csFreeInput);
end;

procedure THbChoiceDeck.CancelFreeInput;
begin
  SetState(csReady);
  if CanFocus and Showing then
  try
    SetFocus;
  except
  end;
end;

procedure THbChoiceDeck.SubmitFreeInputWithKind(const AText: string; AOverrideKind: TEhaiOverrideKind);
var
  Trimmed: string;
begin
  Trimmed := Trim(AText);
  SetState(csReady);
  if CanFocus and Showing then
  try
    SetFocus;
  except
  end;
  if Trimmed <> '' then
    TriggerActionWithOverride(cakFreeInput, 9, Trimmed, 0, cisKeyboard,
      AOverrideKind, esHuman, eipProvide);
end;

procedure THbChoiceDeck.SubmitFreeInput(const AText: string);
begin
  SubmitFreeInputWithKind(AText, eokNone);
end;

procedure THbChoiceDeck.UpdateInlineEditLayout;
var
  HdrH, Y, InputW: Integer;
begin
  HdrH := GetHeaderHeight;
  Y := HdrH + ScalePixels(8);
  InputW := Width - ScalePixels(170);

  FInlineEdit.SetBounds(ScalePixels(12), Y, InputW, ScalePixels(32));
  FBtnSubmit.SetBounds(ScalePixels(16) + InputW, Y, ScalePixels(68), ScalePixels(32));
  FBtnCancel.SetBounds(ScalePixels(90) + InputW, Y, ScalePixels(68), ScalePixels(32));
end;

procedure THbChoiceDeck.OnInlineEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    Key := 0;
    CancelFreeInput;
  end
  else if Key = VK_RETURN then
  begin
    Key := 0;
    SubmitFreeInput(FInlineEdit.Text);
  end;
end;

procedure THbChoiceDeck.OnSubmitClick(Sender: TObject);
begin
  SubmitFreeInput(FInlineEdit.Text);
end;

procedure THbChoiceDeck.OnCancelClick(Sender: TObject);
begin
  CancelFreeInput;
end;

function THbChoiceDeck.ItemRect(AIndex: Integer): TRect;
var
  HdrH, Y, X, ItemW, Col, Row, ColCount, RowH: Integer;
begin
  if (AIndex < 0) or (AIndex >= FItems.Count) then
    Exit(Rect(0, 0, 0, 0));

  HdrH := GetHeaderHeight;

  case FLayoutMode of
    clmDeck:
    begin
      Y := HdrH + ScalePixels(6) + AIndex * (FItemHeight + FItemSpacing);
      Result := Rect(ScalePixels(8), Y, Width - ScalePixels(8), Y + FItemHeight);
    end;

    clmRow:
    begin
      ColCount := Max(1, (Width - ScalePixels(16)) div ScalePixels(96));
      Col := AIndex mod ColCount;
      Row := AIndex div ColCount;
      ItemW := (Width - ScalePixels(16) - (ColCount - 1) * FItemSpacing) div ColCount;
      RowH := ScalePixels(38);
      X := ScalePixels(8) + Col * (ItemW + FItemSpacing);
      Y := HdrH + ScalePixels(6) + Row * (RowH + FItemSpacing);
      Result := Rect(X, Y, X + ItemW, Y + RowH);
    end;

    clmNumberedList:
    begin
      RowH := ScalePixels(32);
      Y := HdrH + ScalePixels(4) + AIndex * (RowH + ScalePixels(4));
      Result := Rect(ScalePixels(6), Y, Width - ScalePixels(6), Y + RowH);
    end;

    clmInline:
    begin
      ItemW := ScalePixels(80);
      X := ScalePixels(6) + AIndex * (ItemW + ScalePixels(6));
      Y := HdrH + ScalePixels(4);
      Result := Rect(X, Y, X + ItemW, Y + ScalePixels(30));
    end;
  else
    Result := Rect(0, 0, 0, 0);
  end;
end;

function THbChoiceDeck.ItemIndexAt(X, Y: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FItems.Count - 1 do
    if PtInRect(ItemRect(I), Point(X, Y)) then
      Exit(I);
end;

procedure THbChoiceDeck.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Idx: Integer;
begin
  inherited;
  if CanFocus and Showing then
  try
    SetFocus;
  except
  end;

  if Button = mbLeft then
  begin
    Idx := ItemIndexAt(X, Y);
    if (Idx >= 0) and FItems[Idx].Enabled then
    begin
      FPressedIndex := Idx;
      FSelectedIndex := Idx;
      Invalidate;
    end;
  end;
end;

procedure THbChoiceDeck.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Idx: Integer;
begin
  inherited;
  Idx := ItemIndexAt(X, Y);
  if FHoverIndex <> Idx then
  begin
    FHoverIndex := Idx;
    Invalidate;
  end;
end;

procedure THbChoiceDeck.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Idx: Integer;
  Item: THbChoiceItem;
begin
  inherited;
  if Button = mbLeft then
  begin
    Idx := ItemIndexAt(X, Y);
    if (FPressedIndex >= 0) and (FPressedIndex = Idx) and FItems[Idx].Enabled then
    begin
      Item := FItems[Idx];
      FPressedIndex := -1;

      if (FCardinality = ecMultiple) and (Item.Kind = ckOption) then
      begin
        ToggleItemChecked(Item.Key);
      end
      else
      begin
        Invalidate;
        TriggerAction(ChoiceKindToActionKind(Item.Kind), Item.Key, Item.Text, Item.Payload, cisMouse);
      end;
    end
    else
    begin
      FPressedIndex := -1;
      Invalidate;
    end;
  end;
end;

procedure THbChoiceDeck.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  if FHoverIndex <> -1 then
  begin
    FHoverIndex := -1;
    FPressedIndex := -1;
    Invalidate;
  end;
end;

procedure THbChoiceDeck.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  Invalidate;
end;

procedure THbChoiceDeck.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;
  Invalidate;
end;

procedure THbChoiceDeck.WMKeyDown(var Message: TWMKeyDown);
var
  DigitKey: Integer;
  InputSrc: THbChoiceInputSource;
  Idx: Integer;
  Item: THbChoiceItem;
begin
  // Rule: Text Entry Owns Keyboard (suspend choice shortcuts if free text entry active)
  if FState = csFreeInput then
  begin
    inherited;
    Exit;
  end;

  // Active Choice Surface Check
  if not FIsActiveChoiceSurface then
  begin
    inherited;
    Exit;
  end;

  DigitKey := -1;
  InputSrc := cisKeyboard;

  // 1. Direct Number Key Mappings (0..9) on Main Keyboard
  case Message.CharCode of
    Ord('0'): DigitKey := 0;
    Ord('1'): DigitKey := 1;
    Ord('2'): DigitKey := 2;
    Ord('3'): DigitKey := 3;
    Ord('4'): DigitKey := 4;
    Ord('5'): DigitKey := 5;
    Ord('6'): DigitKey := 6;
    Ord('7'): DigitKey := 7;
    Ord('8'): DigitKey := 8;
    Ord('9'): DigitKey := 9;

    // 2. NumPad Mappings (When NumLock is active, equivalent to 0..9)
    VK_NUMPAD0: begin DigitKey := 0; InputSrc := cisNumPad; end;
    VK_NUMPAD1: begin DigitKey := 1; InputSrc := cisNumPad; end;
    VK_NUMPAD2: begin DigitKey := 2; InputSrc := cisNumPad; end;
    VK_NUMPAD3: begin DigitKey := 3; InputSrc := cisNumPad; end;
    VK_NUMPAD4: begin DigitKey := 4; InputSrc := cisNumPad; end;
    VK_NUMPAD5: begin DigitKey := 5; InputSrc := cisNumPad; end;
    VK_NUMPAD6: begin DigitKey := 6; InputSrc := cisNumPad; end;
    VK_NUMPAD7: begin DigitKey := 7; InputSrc := cisNumPad; end;
    VK_NUMPAD8: begin DigitKey := 8; InputSrc := cisNumPad; end;
    VK_NUMPAD9: begin DigitKey := 9; InputSrc := cisNumPad; end;

    VK_UP, VK_LEFT:
    begin
      if FSelectedIndex > 0 then
        SelectedIndex := FSelectedIndex - 1
      else if (FSelectedIndex = -1) and (FItems.Count > 0) then
        SelectedIndex := 0;
      Exit;
    end;

    VK_DOWN, VK_RIGHT:
    begin
      if FSelectedIndex < FItems.Count - 1 then
        SelectedIndex := FSelectedIndex + 1
      else if (FSelectedIndex = -1) and (FItems.Count > 0) then
        SelectedIndex := 0;
      Exit;
    end;

    VK_RETURN, VK_SPACE:
    begin
      if FCardinality = ecMultiple then
      begin
        if (FSelectedIndex >= 0) and (FSelectedIndex < FItems.Count) and FItems[FSelectedIndex].Enabled then
          DigitKey := FItems[FSelectedIndex].Key
        else
        begin
          SubmitMultiChoice(cisKeyboard);
          Exit;
        end;
      end
      else
      begin
        if (FSelectedIndex >= 0) and (FSelectedIndex < FItems.Count) and FItems[FSelectedIndex].Enabled then
          DigitKey := FItems[FSelectedIndex].Key;
      end;
    end;
  end;

  if DigitKey >= 0 then
  begin
    Idx := IndexOfKey(DigitKey);
    if (Idx >= 0) and FItems[Idx].Enabled then
    begin
      Item := FItems[Idx];
      FSelectedIndex := Idx;

      if (FCardinality = ecMultiple) and (Item.Kind = ckOption) then
      begin
        ToggleItemChecked(DigitKey);
      end
      else
      begin
        Invalidate;
        TriggerAction(ChoiceKindToActionKind(Item.Kind), Item.Key, Item.Text, Item.Payload, InputSrc);
      end;
    end;
  end
  else
    inherited;
end;

procedure THbChoiceDeck.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  HdrH: Integer;
  FontFam: TGPFontFamily;
  TitleFont, StepFont: TGPFont;
  FormatLeft, FormatRight: TGPStringFormat;
  TitleBrush, StepBrush: TGPSolidBrush;
  TitleR, StepR: TGPRectF;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    EraseBackground(Graphics);

    HdrH := GetHeaderHeight;

    // 1. Draw Context Title & Step Header if present
    if HdrH > 0 then
    begin
      FontFam := TGPFontFamily.Create(PWideChar(Tokens.FontFamily));
      try
        TitleFont := TGPFont.Create(FontFam, Tokens.SizeM, FontStyleBold, UnitPoint);
        StepFont := TGPFont.Create(FontFam, Tokens.SizeS, FontStyleRegular, UnitPoint);
        FormatLeft := TGPStringFormat.Create;
        FormatLeft.SetAlignment(StringAlignmentNear);
        FormatLeft.SetLineAlignment(StringAlignmentCenter);
        FormatLeft.SetFormatFlags(StringFormatFlagsNoWrap);

        FormatRight := TGPStringFormat.Create;
        FormatRight.SetAlignment(StringAlignmentFar);
        FormatRight.SetLineAlignment(StringAlignmentCenter);
        try
          if FContextTitle <> '' then
          begin
            TitleR := MakeRect(ScaleDIP(8), ScaleDIP(4), Single(Width) - ScaleDIP(80), ScaleDIP(28));
            TitleBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
            try
              Graphics.DrawString(PWideChar(FContextTitle), Length(FContextTitle), TitleFont, TitleR, FormatLeft, TitleBrush);
            finally
              TitleBrush.Free;
            end;
          end;

          if FStepInfo <> '' then
          begin
            StepR := MakeRect(Single(Width) - ScaleDIP(80), ScaleDIP(4), ScaleDIP(72), ScaleDIP(28));
            StepBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted));
            try
              Graphics.DrawString(PWideChar(FStepInfo), Length(FStepInfo), StepFont, StepR, FormatRight, StepBrush);
            finally
              StepBrush.Free;
            end;
          end;
        finally
          FormatLeft.Free;
          FormatRight.Free;
          TitleFont.Free;
          StepFont.Free;
        end;
      finally
        FontFam.Free;
      end;
    end;

    // 2. Draw Items based on Layout Mode
    case FLayoutMode of
      clmDeck:         PaintDeckLayout(Graphics, Tokens, HdrH);
      clmRow:          PaintRowLayout(Graphics, Tokens, HdrH);
      clmNumberedList: PaintNumberedListLayout(Graphics, Tokens, HdrH);
      clmInline:       PaintInlineLayout(Graphics, Tokens, HdrH);
    end;

    // 3. Draw State Overlay (Regenerating / NoReliableCandidates / Error)
    if FState in [csRegenerating, csNoReliableCandidates, csError, csLoading] then
      PaintStatusOverlay(Graphics, Tokens, HdrH);

  finally
    Graphics.Free;
  end;
end;

procedure THbChoiceDeck.PaintDeckLayout(Graphics: TGPGraphics; const Tokens: THbTokens; TopOffset: Integer);
var
  I: Integer;
  Item: THbChoiceItem;
  R: TRect;
  ItemBox, BadgeBox, RecBadgeBox: TGPRectF;
  ItemPath, BadgePath, RecBadgePath: TGPGraphicsPath;
  BgBrush, BadgeBrush, TextBrush, SubBrush: TGPSolidBrush;
  BorderPen: TGPPen;
  FontFam: TGPFontFamily;
  MainFont, KeyFont, DescFont, BadgeFont: TGPFont;
  FormatLeft, FormatCenter: TGPStringFormat;
  KeyStr, RecStr: string;
  AccentColor, BorderColor, FillColor: TAlphaColor;
  IsItemHover, IsItemPressed, IsItemFocused: Boolean;
  Rad, DimAlphaFactor: Single;
begin
  FontFam := TGPFontFamily.Create(PWideChar(Tokens.FontFamily));
  try
    MainFont := TGPFont.Create(FontFam, Tokens.SizeM, FontStyleRegular, UnitPoint);
    KeyFont := TGPFont.Create(FontFam, Tokens.SizeM, FontStyleBold, UnitPoint);
    DescFont := TGPFont.Create(FontFam, Tokens.SizeS, FontStyleRegular, UnitPoint);
    BadgeFont := TGPFont.Create(FontFam, Tokens.SizeXS, FontStyleBold, UnitPoint);
    FormatLeft := TGPStringFormat.Create;
    FormatLeft.SetAlignment(StringAlignmentNear);
    FormatLeft.SetLineAlignment(StringAlignmentCenter);
    FormatLeft.SetFormatFlags(StringFormatFlagsNoWrap);

    FormatCenter := TGPStringFormat.Create;
    FormatCenter.SetAlignment(StringAlignmentCenter);
    FormatCenter.SetLineAlignment(StringAlignmentCenter);
    try
      Rad := ScaleDIP(Tokens.RadiusM);
      DimAlphaFactor := 1.0;
      if FState = csRegenerating then
        DimAlphaFactor := 0.45;

      for I := 0 to FItems.Count - 1 do
      begin
        Item := FItems[I];
        R := ItemRect(I);
        ItemBox := MakeRect(Single(R.Left), Single(R.Top), Single(R.Width), Single(R.Height));

        IsItemHover := (FHoverIndex = I) and (FState = csReady);
        IsItemPressed := (FPressedIndex = I) and (FState = csReady);
        IsItemFocused := (FSelectedIndex = I) and Focused and FIsActiveChoiceSurface;

        // Resolve Accent
        case Item.Kind of
          ckOption:
          begin
            AccentColor := Tokens.ChoiceOption;
            BorderColor := Tokens.Border;
            if Item.IsRecommended then
              BorderColor := Tokens.ChoiceRecommended;
            if Item.IsSelected then
              BorderColor := Tokens.Primary;
          end;
          ckRegenerate:
          begin
            AccentColor := Tokens.ChoiceRegenerate;
            BorderColor := Tokens.ChoiceRegenerate;
          end;
          ckInput:
          begin
            AccentColor := Tokens.ChoiceInput;
            BorderColor := Tokens.ChoiceInput;
          end;
          ckBack:
          begin
            AccentColor := Tokens.ChoiceBack;
            BorderColor := Tokens.ChoiceBack;
          end;
        else
          AccentColor := Tokens.ChoiceOption;
          BorderColor := Tokens.Border;
        end;

        // Fill color calculation
        if not Item.Enabled then
        begin
          FillColor := ColorToARGB(Tokens.Sunken, Round(160 * DimAlphaFactor));
          BorderColor := ColorToARGB(Tokens.Border, Round(100 * DimAlphaFactor));
        end
        else if IsItemPressed then
          FillColor := ColorToARGB(AccentColor, Round(60 * DimAlphaFactor))
        else if IsItemHover then
          FillColor := ColorToARGB(AccentColor, Round(35 * DimAlphaFactor))
        else if Item.IsSelected and (Item.Kind = ckOption) then
          FillColor := ColorToARGB(AccentColor, Round(25 * DimAlphaFactor))
        else
          FillColor := ColorToARGB(Tokens.Surface, Round(255 * DimAlphaFactor));

        // Draw Container Card
        ItemPath := CreateRoundRectPath(ItemBox, Rad);
        try
          BgBrush := TGPSolidBrush.Create(FillColor);
          try
            Graphics.FillPath(BgBrush, ItemPath);
          finally
            BgBrush.Free;
          end;

          if IsItemFocused then
            BorderPen := TGPPen.Create(ColorToARGB(Tokens.FocusRing), 2.0)
          else if Item.IsSelected and (Item.Kind = ckOption) then
            BorderPen := TGPPen.Create(ColorToARGB(Tokens.Primary, Round(220 * DimAlphaFactor)), 2.0)
          else
            BorderPen := TGPPen.Create(ColorToARGB(BorderColor, Round(180 * DimAlphaFactor)), 1.0);

          try
            Graphics.DrawPath(BorderPen, ItemPath);
          finally
            BorderPen.Free;
          end;
        finally
          ItemPath.Free;
        end;

        // Key Badge [1..7, 8, 9, 0] or Checkbox badge in multi-choice
        BadgeBox := MakeRect(ItemBox.X + ScaleDIP(8),
                             ItemBox.Y + (ItemBox.Height - ScaleDIP(28)) * 0.5,
                             ScaleDIP(32), ScaleDIP(28));
        BadgePath := CreateRoundRectPath(BadgeBox, ScaleDIP(Tokens.RadiusS));
        try
          if (FCardinality = ecMultiple) and (Item.Kind = ckOption) then
          begin
            if Item.IsSelected then
            begin
              BadgeBrush := TGPSolidBrush.Create(ColorToARGB(AccentColor, Round(220 * DimAlphaFactor)));
              try
                Graphics.FillPath(BadgeBrush, BadgePath);
              finally
                BadgeBrush.Free;
              end;

              KeyStr := '✓ ' + IntToStr(Item.Key);
              TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Surface, Round(255 * DimAlphaFactor)));
              try
                Graphics.DrawString(PWideChar(KeyStr), Length(KeyStr), KeyFont, BadgeBox, FormatCenter, TextBrush);
              finally
                TextBrush.Free;
              end;
            end
            else
            begin
              BadgeBrush := TGPSolidBrush.Create(ColorToARGB(AccentColor, Round(35 * DimAlphaFactor)));
              try
                Graphics.FillPath(BadgeBrush, BadgePath);
              finally
                BadgeBrush.Free;
              end;

              BorderPen := TGPPen.Create(ColorToARGB(BorderColor, Round(160 * DimAlphaFactor)), 1.0);
              try
                Graphics.DrawPath(BorderPen, BadgePath);
              finally
                BorderPen.Free;
              end;

              KeyStr := IntToStr(Item.Key);
              TextBrush := TGPSolidBrush.Create(ColorToARGB(AccentColor, Round(255 * DimAlphaFactor)));
              try
                Graphics.DrawString(PWideChar(KeyStr), Length(KeyStr), KeyFont, BadgeBox, FormatCenter, TextBrush);
              finally
                TextBrush.Free;
              end;
            end;
          end
          else
          begin
            BadgeBrush := TGPSolidBrush.Create(ColorToARGB(AccentColor, Round(35 * DimAlphaFactor)));
            try
              Graphics.FillPath(BadgeBrush, BadgePath);
            finally
              BadgeBrush.Free;
            end;

            BorderPen := TGPPen.Create(ColorToARGB(BorderColor, Round(160 * DimAlphaFactor)), 1.0);
            try
              Graphics.DrawPath(BorderPen, BadgePath);
            finally
              BorderPen.Free;
            end;

            KeyStr := IntToStr(Item.Key);
            TextBrush := TGPSolidBrush.Create(ColorToARGB(AccentColor, Round(255 * DimAlphaFactor)));
            try
              Graphics.DrawString(PWideChar(KeyStr), Length(KeyStr), KeyFont, BadgeBox, FormatCenter, TextBrush);
            finally
              TextBrush.Free;
            end;
          end;
        finally
          BadgePath.Free;
        end;

        // Text & Description
        var TextLeft := ItemBox.X + ScaleDIP(48);
        var TextRight := ItemBox.Width - ScaleDIP(56);
        if Item.IsRecommended then
          TextRight := TextRight - ScaleDIP(60);

        var TextRect := MakeRect(TextLeft, ItemBox.Y + ScaleDIP(4), TextRight, ItemBox.Height - ScaleDIP(8));
        TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink, Round(255 * DimAlphaFactor)));
        try
          if Item.Description <> '' then
          begin
            var TitleR := MakeRect(TextLeft, ItemBox.Y + ScaleDIP(5), TextRight, ScaleDIP(18));
            var DescR := MakeRect(TextLeft, ItemBox.Y + ScaleDIP(23), TextRight, ScaleDIP(16));

            Graphics.DrawString(PWideChar(Item.Text), Length(Item.Text), MainFont, TitleR, FormatLeft, TextBrush);

            SubBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted, Round(255 * DimAlphaFactor)));
            try
              Graphics.DrawString(PWideChar(Item.Description), Length(Item.Description), DescFont, DescR, FormatLeft, SubBrush);
            finally
              SubBrush.Free;
            end;
          end
          else
            Graphics.DrawString(PWideChar(Item.Text), Length(Item.Text), MainFont, TextRect, FormatLeft, TextBrush);
        finally
          TextBrush.Free;
        end;

        // Recommended Badge
        if Item.IsRecommended then
        begin
          RecBadgeBox := MakeRect(ItemBox.X + ItemBox.Width - ScaleDIP(54),
                                  ItemBox.Y + (ItemBox.Height - ScaleDIP(20)) * 0.5,
                                  ScaleDIP(46), ScaleDIP(20));
          RecBadgePath := CreateRoundRectPath(RecBadgeBox, ScaleDIP(Tokens.RadiusS));
          try
            BadgeBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.ChoiceRecommended, Round(30 * DimAlphaFactor)));
            try
              Graphics.FillPath(BadgeBrush, RecBadgePath);
            finally
              BadgeBrush.Free;
            end;

            BorderPen := TGPPen.Create(ColorToARGB(Tokens.ChoiceRecommended, Round(160 * DimAlphaFactor)), 1.0);
            try
              Graphics.DrawPath(BorderPen, RecBadgePath);
            finally
              BorderPen.Free;
            end;

            RecStr := '推荐';
            TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.ChoiceRecommended, Round(255 * DimAlphaFactor)));
            try
              Graphics.DrawString(PWideChar(RecStr), Length(RecStr), BadgeFont, RecBadgeBox, FormatCenter, TextBrush);
            finally
              TextBrush.Free;
            end;
          finally
            RecBadgePath.Free;
          end;
        end;
      end;
    finally
      FormatLeft.Free;
      FormatCenter.Free;
      MainFont.Free;
      KeyFont.Free;
      DescFont.Free;
      BadgeFont.Free;
    end;
  finally
    FontFam.Free;
  end;
end;

procedure THbChoiceDeck.PaintRowLayout(Graphics: TGPGraphics; const Tokens: THbTokens; TopOffset: Integer);
var
  I: Integer;
  Item: THbChoiceItem;
  R: TRect;
  ItemBox: TGPRectF;
  ItemPath: TGPGraphicsPath;
  BgBrush, TextBrush: TGPSolidBrush;
  BorderPen: TGPPen;
  FontFam: TGPFontFamily;
  MainFont: TGPFont;
  FormatCenter: TGPStringFormat;
  LabelStr: string;
  AccentColor, BorderColor, FillColor: TAlphaColor;
  IsItemHover, IsItemFocused: Boolean;
begin
  FontFam := TGPFontFamily.Create(PWideChar(Tokens.FontFamily));
  try
    MainFont := TGPFont.Create(FontFam, Tokens.SizeS, FontStyleBold, UnitPoint);
    FormatCenter := TGPStringFormat.Create;
    FormatCenter.SetAlignment(StringAlignmentCenter);
    FormatCenter.SetLineAlignment(StringAlignmentCenter);
    try
      for I := 0 to FItems.Count - 1 do
      begin
        Item := FItems[I];
        R := ItemRect(I);
        ItemBox := MakeRect(Single(R.Left), Single(R.Top), Single(R.Width), Single(R.Height));

        IsItemHover := (FHoverIndex = I) and (FState = csReady);
        IsItemFocused := (FSelectedIndex = I) and Focused and FIsActiveChoiceSurface;

        case Item.Kind of
          ckRegenerate: AccentColor := Tokens.ChoiceRegenerate;
          ckInput:      AccentColor := Tokens.ChoiceInput;
          ckBack:       AccentColor := Tokens.ChoiceBack;
        else
          if Item.IsRecommended then
            AccentColor := Tokens.ChoiceRecommended
          else
            AccentColor := Tokens.ChoiceOption;
        end;

        BorderColor := AccentColor;
        if IsItemHover then
          FillColor := ColorToARGB(AccentColor, 40)
        else if Item.IsSelected and (Item.Kind = ckOption) then
          FillColor := ColorToARGB(AccentColor, 60)
        else
          FillColor := Tokens.Surface;

        ItemPath := CreateRoundRectPath(ItemBox, ScaleDIP(Tokens.RadiusS));
        try
          BgBrush := TGPSolidBrush.Create(FillColor);
          try
            Graphics.FillPath(BgBrush, ItemPath);
          finally
            BgBrush.Free;
          end;

          if IsItemFocused then
            BorderPen := TGPPen.Create(ColorToARGB(Tokens.FocusRing), 2.0)
          else
            BorderPen := TGPPen.Create(ColorToARGB(BorderColor, 180), 1.0);

          try
            Graphics.DrawPath(BorderPen, ItemPath);
          finally
            BorderPen.Free;
          end;

          if (FCardinality = ecMultiple) and (Item.Kind = ckOption) and Item.IsSelected then
            LabelStr := '✓ ' + IntToStr(Item.Key) + ' ' + Item.Text
          else
            LabelStr := IntToStr(Item.Key) + ' ' + Item.Text;

          TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
          try
            Graphics.DrawString(PWideChar(LabelStr), Length(LabelStr), MainFont, ItemBox, FormatCenter, TextBrush);
          finally
            TextBrush.Free;
          end;
        finally
          ItemPath.Free;
        end;
      end;
    finally
      FormatCenter.Free;
      MainFont.Free;
    end;
  finally
    FontFam.Free;
  end;
end;

procedure THbChoiceDeck.PaintNumberedListLayout(Graphics: TGPGraphics; const Tokens: THbTokens; TopOffset: Integer);
var
  I: Integer;
  Item: THbChoiceItem;
  R: TRect;
  ItemBox, TextR: TGPRectF;
  BgBrush, TextBrush: TGPSolidBrush;
  FontFam: TGPFontFamily;
  MainFont, KeyFont: TGPFont;
  FormatLeft, FormatCenter: TGPStringFormat;
  LabelStr: string;
begin
  FontFam := TGPFontFamily.Create(PWideChar(Tokens.FontFamily));
  try
    MainFont := TGPFont.Create(FontFam, Tokens.SizeM, FontStyleRegular, UnitPoint);
    KeyFont := TGPFont.Create(FontFam, Tokens.SizeM, FontStyleBold, UnitPoint);
    FormatLeft := TGPStringFormat.Create;
    FormatLeft.SetAlignment(StringAlignmentNear);
    FormatLeft.SetLineAlignment(StringAlignmentCenter);
    FormatCenter := TGPStringFormat.Create;
    FormatCenter.SetAlignment(StringAlignmentCenter);
    FormatCenter.SetLineAlignment(StringAlignmentCenter);
    try
      for I := 0 to FItems.Count - 1 do
      begin
        Item := FItems[I];
        R := ItemRect(I);
        ItemBox := MakeRect(Single(R.Left), Single(R.Top), Single(R.Width), Single(R.Height));

        if (FHoverIndex = I) or (FSelectedIndex = I) then
        begin
          BgBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary, 30));
          try
            Graphics.FillRectangle(BgBrush, ItemBox);
          finally
            BgBrush.Free;
          end;
        end;

        // Key Prefix
        var KeyR := MakeRect(ItemBox.X, ItemBox.Y, ScaleDIP(32), ItemBox.Height);
        if (FCardinality = ecMultiple) and (Item.Kind = ckOption) and Item.IsSelected then
          LabelStr := '✓' + IntToStr(Item.Key) + '.'
        else
          LabelStr := IntToStr(Item.Key) + '.';

        TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
        try
          Graphics.DrawString(PWideChar(LabelStr), Length(LabelStr), KeyFont, KeyR, FormatCenter, TextBrush);
        finally
          TextBrush.Free;
        end;

        // Content
        TextR := MakeRect(ItemBox.X + ScaleDIP(36), ItemBox.Y, ItemBox.Width - ScaleDIP(40), ItemBox.Height);
        TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
        try
          Graphics.DrawString(PWideChar(Item.Text), Length(Item.Text), MainFont, TextR, FormatLeft, TextBrush);
        finally
          TextBrush.Free;
        end;
      end;
    finally
      FormatLeft.Free;
      FormatCenter.Free;
      MainFont.Free;
      KeyFont.Free;
    end;
  finally
    FontFam.Free;
  end;
end;

procedure THbChoiceDeck.PaintInlineLayout(Graphics: TGPGraphics; const Tokens: THbTokens; TopOffset: Integer);
var
  I: Integer;
  Item: THbChoiceItem;
  R: TRect;
  ItemBox: TGPRectF;
  ItemPath: TGPGraphicsPath;
  BgBrush, TextBrush: TGPSolidBrush;
  BorderPen: TGPPen;
  FontFam: TGPFontFamily;
  MainFont: TGPFont;
  FormatCenter: TGPStringFormat;
  LabelStr: string;
begin
  FontFam := TGPFontFamily.Create(PWideChar(Tokens.FontFamily));
  try
    MainFont := TGPFont.Create(FontFam, Tokens.SizeS, FontStyleBold, UnitPoint);
    FormatCenter := TGPStringFormat.Create;
    FormatCenter.SetAlignment(StringAlignmentCenter);
    FormatCenter.SetLineAlignment(StringAlignmentCenter);
    try
      for I := 0 to FItems.Count - 1 do
      begin
        Item := FItems[I];
        R := ItemRect(I);
        ItemBox := MakeRect(Single(R.Left), Single(R.Top), Single(R.Width), Single(R.Height));

        ItemPath := CreateRoundRectPath(ItemBox, ScaleDIP(Tokens.RadiusS));
        try
          if (FHoverIndex = I) or (FSelectedIndex = I) or (Item.IsSelected and (Item.Kind = ckOption)) then
            BgBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.ChoiceOption, 40))
          else
            BgBrush := TGPSolidBrush.Create(Tokens.Surface);

          try
            Graphics.FillPath(BgBrush, ItemPath);
          finally
            BgBrush.Free;
          end;

          BorderPen := TGPPen.Create(ColorToARGB(Tokens.ChoiceOption, 160), 1.0);
          try
            Graphics.DrawPath(BorderPen, ItemPath);
          finally
            BorderPen.Free;
          end;

          if (FCardinality = ecMultiple) and (Item.Kind = ckOption) and Item.IsSelected then
            LabelStr := '✓' + IntToStr(Item.Key) + ':' + Item.Text
          else
            LabelStr := IntToStr(Item.Key) + ':' + Item.Text;

          TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
          try
            Graphics.DrawString(PWideChar(LabelStr), Length(LabelStr), MainFont, ItemBox, FormatCenter, TextBrush);
          finally
            TextBrush.Free;
          end;
        finally
          ItemPath.Free;
        end;
      end;
    finally
      FormatCenter.Free;
      MainFont.Free;
    end;
  finally
    FontFam.Free;
  end;
end;

procedure THbChoiceDeck.PaintStatusOverlay(Graphics: TGPGraphics; const Tokens: THbTokens; TopOffset: Integer);
var
  BoxR: TGPRectF;
  BoxPath: TGPGraphicsPath;
  BgBrush, TextBrush: TGPSolidBrush;
  FontFam: TGPFontFamily;
  FontMsg: TGPFont;
  FormatCenter: TGPStringFormat;
  DisplayMsg: string;
begin
  if FStatusMessage <> '' then
    DisplayMsg := FStatusMessage
  else if FState = csRegenerating then
    DisplayMsg := '正在换一组候选...'
  else if FState = csNoReliableCandidates then
    DisplayMsg := '当前信息不足，暂无可靠建议。'
  else if FState = csError then
    DisplayMsg := '加载失败，请重试。'
  else
    DisplayMsg := '处理中...';

  BoxR := MakeRect(ScaleDIP(16), Single(Height - ScaleDIP(42)), Single(Width - ScaleDIP(32)), ScaleDIP(34));
  BoxPath := CreateRoundRectPath(BoxR, ScaleDIP(Tokens.RadiusM));
  try
    BgBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt, 240));
    try
      Graphics.FillPath(BgBrush, BoxPath);
    finally
      BgBrush.Free;
    end;
  finally
    BoxPath.Free;
  end;

  FontFam := TGPFontFamily.Create(PWideChar(Tokens.FontFamily));
  try
    FontMsg := TGPFont.Create(FontFam, Tokens.SizeS, FontStyleBold, UnitPoint);
    FormatCenter := TGPStringFormat.Create;
    FormatCenter.SetAlignment(StringAlignmentCenter);
    FormatCenter.SetLineAlignment(StringAlignmentCenter);
    try
      TextBrush := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
      try
        Graphics.DrawString(PWideChar(DisplayMsg), Length(DisplayMsg), FontMsg, BoxR, FormatCenter, TextBrush);
      finally
        TextBrush.Free;
      end;
    finally
      FormatCenter.Free;
      FontMsg.Free;
    end;
  finally
    FontFam.Free;
  end;
end;

end.
