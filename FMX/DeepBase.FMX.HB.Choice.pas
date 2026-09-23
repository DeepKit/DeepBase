{ ============================================================================
  DeepBase.FMX.HB.Choice - Modern Token-Driven 0-9 Choice Deck for FireMonkey

  Version: 2.1 (Delphi 13.1 on Win64 / Cross-Platform FMX)
  Description: THbFmxChoiceDeck - Universal AI Choice Interaction Standard for FMX:
               - 1-7 Contextual options (Key 1 can be Recommended)
               - 8 Fixed control: Regenerate (Contextual re-generation)
               - 9 Fixed control: Human Override / Free Input (Frame Rejection)
               - 0 Fixed control: Navigate Back (Pure navigation)
               - Decision Cardinality: ecSingle, ecMultiple (L4 §5.5, CSV-003)
               - Frame Rejection Tri-State: eokCandidateReject, eokAlternativeExpression, eokFrameRejection
               - Multi-modal action abstraction: THbChoiceAction & THbChoiceInputSource
               - 4 Layout modes: clmDeck, clmRow, clmNumberedList, clmInline
               - Truthful State Machine: csReady, csRegenerating, csFreeInput,
                 csLoading, csNoReliableCandidates, csDisabled, csError
               - Active Choice Surface arbitration & Text Entry Owns Keyboard rule
               - FMX TCanvas vector anti-aliased rendering
               - Verified 100% backward-compatible with v1.0 & v2.0
  ============================================================================ }

unit DeepBase.FMX.HB.Choice;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Math,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Graphics,
  FMX.Objects,
  DeepBase.HB.Core,
  DeepBase.EHAI.Types,
  DeepBase.HB.Choice.Types,
  DeepBase.FMX.HB.Theme,
  DeepBase.FMX.HB.Controls;

type
  /// <summary>
  /// THbFmxChoiceDeck: Universal AI Choice Interaction Standard Component for FMX.
  /// </summary>
  THbFmxChoiceDeck = class(THbFmxControl)
  private
    FItems: TList<THbChoiceItem>;
    FSelectedIndex: Integer;
    FHoverIndex: Integer;
    FPressedIndex: Integer;
    FItemHeight: Single;
    FItemSpacing: Single;
    FLayoutMode: THbChoiceLayoutMode;
    FChoiceState: THbChoiceState;
    FFreeInputMode: THbChoiceFreeInputMode;
    FCardinality: TEhaiCardinality;
    FDefaultProfile: TEhaiInvolvementProfile;
    FContextBinding: TEhaiContextBinding;
    FContextTitle: string;
    FStepInfo: string;
    FStatusMessage: string;
    FIsActiveChoiceSurface: Boolean;

    // Events
    FOnChoice: THbChoiceEvent;
    FOnCustomInput: THbChoiceInputEvent;
    FOnAction: THbChoiceActionEvent;
    FOnFreeInputRequested: THbChoiceFreeInputRequestEvent;
    FOnStateChanged: TNotifyEvent;
    FOnMultiSelect: THbChoiceMultiSelectEvent;

    procedure SetSelectedIndex(Value: Integer);
    procedure SetLayoutMode(Value: THbChoiceLayoutMode);
    procedure SetChoiceState(Value: THbChoiceState);
    procedure SetCardinality(Value: TEhaiCardinality);
    procedure SetContextTitle(const Value: string);
    procedure SetStepInfo(const Value: string);
    procedure SetStatusMessage(const Value: string);
    procedure SetIsActiveChoiceSurface(Value: Boolean);

    function ItemIndexAt(X, Y: Single): Integer;
    function GetItemCount: Integer;
    function GetItem(Index: Integer): THbChoiceItem;
    procedure SetItem(Index: Integer; const Value: THbChoiceItem);
    function GetHeaderHeight: Single;
  protected
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens); override;
    procedure DrawDeckLayout(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens; TopOffset: Single);
    procedure DrawRowLayout(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens; TopOffset: Single);
    procedure DrawNumberedListLayout(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens; TopOffset: Single);
    procedure DrawInlineLayout(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens; TopOffset: Single);
    procedure DrawStatusOverlay(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens; TopOffset: Single);

    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DoMouseLeave; override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
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
    function ItemRect(AIndex: Integer): TRectF;

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
    property Visible;
    property LayoutMode: THbChoiceLayoutMode read FLayoutMode write SetLayoutMode default clmDeck;
    property State: THbChoiceState read FChoiceState write SetChoiceState default csReady;
    property FreeInputMode: THbChoiceFreeInputMode read FFreeInputMode write FFreeInputMode default fimBuiltIn;
    property Cardinality: TEhaiCardinality read FCardinality write SetCardinality default ecSingle;
    property DefaultProfile: TEhaiInvolvementProfile read FDefaultProfile write FDefaultProfile default eipJudge;
    property ContextBinding: TEhaiContextBinding read FContextBinding write FContextBinding;
    property ContextTitle: string read FContextTitle write SetContextTitle;
    property StepInfo: string read FStepInfo write SetStepInfo;
    property StatusMessage: string read FStatusMessage write SetStatusMessage;
    property IsActiveChoiceSurface: Boolean read FIsActiveChoiceSurface write SetIsActiveChoiceSurface default True;
    property ItemHeight: Single read FItemHeight write FItemHeight;
    property ItemSpacing: Single read FItemSpacing write FItemSpacing;

    property OnAction: THbChoiceActionEvent read FOnAction write FOnAction;
    property OnChoice: THbChoiceEvent read FOnChoice write FOnChoice;
    property OnCustomInput: THbChoiceInputEvent read FOnCustomInput write FOnCustomInput;
    property OnFreeInputRequested: THbChoiceFreeInputRequestEvent read FOnFreeInputRequested write FOnFreeInputRequested;
    property OnStateChanged: TNotifyEvent read FOnStateChanged write FOnStateChanged;
    property OnMultiSelect: THbChoiceMultiSelectEvent read FOnMultiSelect write FOnMultiSelect;

    property OnClick;
  end;

  THbChoiceDeck = THbFmxChoiceDeck;

implementation

{ THbFmxChoiceDeck }

constructor THbFmxChoiceDeck.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TList<THbChoiceItem>.Create;
  FSelectedIndex := -1;
  FHoverIndex := -1;
  FPressedIndex := -1;
  FLayoutMode := clmDeck;
  FChoiceState := csReady;
  FFreeInputMode := fimBuiltIn;
  FCardinality := ecSingle;
  FDefaultProfile := eipJudge;
  FillChar(FContextBinding, SizeOf(FContextBinding), 0);
  FContextTitle := '';
  FStepInfo := '';
  FStatusMessage := '';
  FIsActiveChoiceSurface := True;
  FItemHeight := 46;
  FItemSpacing := 8;
  Width := 440;
  Height := 380;
  CanFocus := True;
end;

destructor THbFmxChoiceDeck.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure THbFmxChoiceDeck.Clear;
begin
  FItems.Clear;
  FSelectedIndex := -1;
  FHoverIndex := -1;
  FPressedIndex := -1;
  FChoiceState := csReady;
  Repaint;
end;

function THbFmxChoiceDeck.GetItemCount: Integer;
begin
  Result := FItems.Count;
end;

function THbFmxChoiceDeck.GetItem(Index: Integer): THbChoiceItem;
begin
  Result := FItems[Index];
end;

procedure THbFmxChoiceDeck.SetItem(Index: Integer; const Value: THbChoiceItem);
begin
  FItems[Index] := Value;
  Repaint;
end;

procedure THbFmxChoiceDeck.SetSelectedIndex(Value: Integer);
begin
  if (Value >= -1) and (Value < FItems.Count) and (FSelectedIndex <> Value) then
  begin
    FSelectedIndex := Value;
    Repaint;
  end;
end;

procedure THbFmxChoiceDeck.SetLayoutMode(Value: THbChoiceLayoutMode);
begin
  if FLayoutMode <> Value then
  begin
    FLayoutMode := Value;
    Repaint;
  end;
end;

procedure THbFmxChoiceDeck.SetCardinality(Value: TEhaiCardinality);
begin
  if FCardinality <> Value then
  begin
    FCardinality := Value;
    Repaint;
  end;
end;

procedure THbFmxChoiceDeck.SetChoiceState(Value: THbChoiceState);
begin
  if FChoiceState <> Value then
  begin
    FChoiceState := Value;
    if Assigned(FOnStateChanged) then
      FOnStateChanged(Self);
    Repaint;
  end;
end;

procedure THbFmxChoiceDeck.SetContextTitle(const Value: string);
begin
  if FContextTitle <> Value then
  begin
    FContextTitle := Value;
    FContextBinding.ContextTitle := Value;
    Repaint;
  end;
end;

procedure THbFmxChoiceDeck.SetStepInfo(const Value: string);
begin
  if FStepInfo <> Value then
  begin
    FStepInfo := Value;
    FContextBinding.StepInfo := Value;
    Repaint;
  end;
end;

procedure THbFmxChoiceDeck.SetStatusMessage(const Value: string);
begin
  if FStatusMessage <> Value then
  begin
    FStatusMessage := Value;
    Repaint;
  end;
end;

procedure THbFmxChoiceDeck.SetIsActiveChoiceSurface(Value: Boolean);
begin
  if FIsActiveChoiceSurface <> Value then
  begin
    FIsActiveChoiceSurface := Value;
    Repaint;
  end;
end;

function THbFmxChoiceDeck.GetHeaderHeight: Single;
begin
  Result := 0;
  if (FContextTitle <> '') or (FStepInfo <> '') then
    Result := 38;
end;

procedure THbFmxChoiceDeck.AddOption(AKey: Integer; const AText, ADesc: string;
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
  Repaint;
end;

procedure THbFmxChoiceDeck.AddStandardControls(AHasRegenerate, AHasInput, AHasBack: Boolean);
begin
  if AHasRegenerate then
    AddOption(8, GetDefaultKeyLabel(8), '在当前上下文换一组候选');
  if AHasInput then
    AddOption(9, GetDefaultKeyLabel(9), '手动输入或打破预设框架');
  if AHasBack then
    AddOption(0, GetDefaultKeyLabel(0), '返回上一步');
end;

procedure THbFmxChoiceDeck.SetOptions(const AOptions: array of string; ARecommendedKey: Integer);
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

procedure THbFmxChoiceDeck.SetCandidates(const ACandidates: array of THbChoiceItem;
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
  Repaint;
end;

function THbFmxChoiceDeck.IndexOfKey(AKey: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FItems.Count - 1 do
    if FItems[I].Key = AKey then
      Exit(I);
end;

function THbFmxChoiceDeck.FindItemByKey(AKey: Integer; out AItem: THbChoiceItem): Boolean;
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

procedure THbFmxChoiceDeck.SetItemEnabled(AKey: Integer; AEnabled: Boolean);
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
      Repaint;
    end;
  end;
end;

function THbFmxChoiceDeck.GetSelectedKeys: TArray<Integer>;
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

procedure THbFmxChoiceDeck.SetItemChecked(AKey: Integer; AChecked: Boolean);
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
      Repaint;
      if Assigned(FOnMultiSelect) then
        FOnMultiSelect(Self, GetSelectedKeys);
    end;
  end;
end;

procedure THbFmxChoiceDeck.ToggleItemChecked(AKey: Integer);
var
  Idx: Integer;
begin
  Idx := IndexOfKey(AKey);
  if (Idx >= 0) and (FItems[Idx].Kind = ckOption) then
    SetItemChecked(AKey, not FItems[Idx].IsSelected);
end;

procedure THbFmxChoiceDeck.SubmitMultiChoice(ASource: THbChoiceInputSource);
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

procedure THbFmxChoiceDeck.TriggerAction(AKind: THbChoiceActionKind; AKey: Integer;
  const AText: string; APayload: NativeInt; ASource: THbChoiceInputSource);
begin
  TriggerActionWithOverride(AKind, AKey, AText, APayload, ASource, eokNone, esHuman, FDefaultProfile);
end;

procedure THbFmxChoiceDeck.TriggerActionWithOverride(AKind: THbChoiceActionKind; AKey: Integer;
  const AText: string; APayload: NativeInt; ASource: THbChoiceInputSource;
  AOverrideKind: TEhaiOverrideKind; ASemanticSource: TEhaiSource;
  AProfile: TEhaiInvolvementProfile);
var
  Action: THbChoiceAction;
  Handled: Boolean;
begin
  Action := THbChoiceAction.Create(AKind, AKey, AText, APayload, ASource,
    AOverrideKind, ASemanticSource, AProfile, FContextBinding.ContextId);

  if Assigned(FOnAction) then
    FOnAction(Self, Action);

  if Assigned(FOnChoice) then
    FOnChoice(Self, AKey);

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

procedure THbFmxChoiceDeck.TriggerOverrideAction(AOverrideKind: TEhaiOverrideKind;
  const AText: string; APayload: NativeInt; ASource: THbChoiceInputSource);
begin
  TriggerActionWithOverride(cakFreeInput, 9, AText, APayload, ASource,
    AOverrideKind, esHuman, eipProvide);
end;

procedure THbFmxChoiceDeck.TriggerMultiAction(const ASelectedKeys: array of Integer;
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

procedure THbFmxChoiceDeck.SelectKey(AKey: Integer; ASource: THbChoiceInputSource);
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
      Repaint;
      TriggerAction(ChoiceKindToActionKind(Item.Kind), Item.Key, Item.Text, Item.Payload, ASource);
    end;
  end;
end;

procedure THbFmxChoiceDeck.BeginRegenerate;
begin
  SetChoiceState(csRegenerating);
end;

procedure THbFmxChoiceDeck.EndRegenerate;
begin
  SetChoiceState(csReady);
end;

procedure THbFmxChoiceDeck.SetNoReliableCandidates(const AMessage: string);
begin
  if AMessage <> '' then
    FStatusMessage := AMessage
  else
    FStatusMessage := '当前信息还不足以给出可靠候选。';
  SetChoiceState(csNoReliableCandidates);
end;

procedure THbFmxChoiceDeck.SetError(const AErrorMessage: string);
begin
  FStatusMessage := AErrorMessage;
  SetChoiceState(csError);
end;

procedure THbFmxChoiceDeck.ResetToReady;
begin
  FStatusMessage := '';
  SetChoiceState(csReady);
end;

procedure THbFmxChoiceDeck.EnterFreeInput(const APrefillText: string);
begin
  SetChoiceState(csFreeInput);
end;

procedure THbFmxChoiceDeck.CancelFreeInput;
begin
  SetChoiceState(csReady);
end;

procedure THbFmxChoiceDeck.SubmitFreeInputWithKind(const AText: string; AOverrideKind: TEhaiOverrideKind);
var
  Trimmed: string;
begin
  Trimmed := Trim(AText);
  SetChoiceState(csReady);
  if Trimmed <> '' then
    TriggerActionWithOverride(cakFreeInput, 9, Trimmed, 0, cisKeyboard,
      AOverrideKind, esHuman, eipProvide);
end;

procedure THbFmxChoiceDeck.SubmitFreeInput(const AText: string);
begin
  SubmitFreeInputWithKind(AText, eokNone);
end;

function THbFmxChoiceDeck.ItemRect(AIndex: Integer): TRectF;
var
  HdrH, Y, X, ItemW, Col, Row, ColCount, RowH: Single;
begin
  if (AIndex < 0) or (AIndex >= FItems.Count) then
    Exit(RectF(0, 0, 0, 0));

  HdrH := GetHeaderHeight;

  case FLayoutMode of
    clmDeck:
    begin
      Y := HdrH + 6 + AIndex * (FItemHeight + FItemSpacing);
      Result := RectF(8, Y, Width - 8, Y + FItemHeight);
    end;

    clmRow:
    begin
      ColCount := Max(1, Floor((Width - 16) / 96));
      Col := AIndex mod Trunc(ColCount);
      Row := AIndex div Trunc(ColCount);
      ItemW := (Width - 16 - (ColCount - 1) * FItemSpacing) / ColCount;
      RowH := 38;
      X := 8 + Col * (ItemW + FItemSpacing);
      Y := HdrH + 6 + Row * (RowH + FItemSpacing);
      Result := RectF(X, Y, X + ItemW, Y + RowH);
    end;

    clmNumberedList:
    begin
      RowH := 32;
      Y := HdrH + 4 + AIndex * (RowH + 4);
      Result := RectF(6, Y, Width - 6, Y + RowH);
    end;

    clmInline:
    begin
      ItemW := 80;
      X := 6 + AIndex * (ItemW + 6);
      Y := HdrH + 4;
      Result := RectF(X, Y, X + ItemW, Y + 30);
    end;
  else
    Result := RectF(0, 0, 0, 0);
  end;
end;

function THbFmxChoiceDeck.ItemIndexAt(X, Y: Single): Integer;
var
  I: Integer;
  R: TRectF;
begin
  Result := -1;
  for I := 0 to FItems.Count - 1 do
  begin
    R := ItemRect(I);
    if R.Contains(PointF(X, Y)) then
      Exit(I);
  end;
end;

procedure THbFmxChoiceDeck.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Idx: Integer;
begin
  inherited;
  if CanFocus then
    SetFocus;

  if Button = TMouseButton.mbLeft then
  begin
    Idx := ItemIndexAt(X, Y);
    if (Idx >= 0) and FItems[Idx].Enabled then
    begin
      FPressedIndex := Idx;
      FSelectedIndex := Idx;
      Repaint;
    end;
  end;
end;

procedure THbFmxChoiceDeck.MouseMove(Shift: TShiftState; X, Y: Single);
var
  Idx: Integer;
begin
  inherited;
  Idx := ItemIndexAt(X, Y);
  if FHoverIndex <> Idx then
  begin
    FHoverIndex := Idx;
    Repaint;
  end;
end;

procedure THbFmxChoiceDeck.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Idx: Integer;
  Item: THbChoiceItem;
begin
  inherited;
  if Button = TMouseButton.mbLeft then
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
        Repaint;
        TriggerAction(ChoiceKindToActionKind(Item.Kind), Item.Key, Item.Text, Item.Payload, cisMouse);
      end;
    end
    else
    begin
      FPressedIndex := -1;
      Repaint;
    end;
  end;
end;

procedure THbFmxChoiceDeck.DoMouseLeave;
begin
  inherited;
  if FHoverIndex <> -1 then
  begin
    FHoverIndex := -1;
    FPressedIndex := -1;
    Repaint;
  end;
end;

procedure THbFmxChoiceDeck.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
var
  DigitKey: Integer;
  InputSrc: THbChoiceInputSource;
  Idx: Integer;
  Item: THbChoiceItem;
begin
  if (FChoiceState = csFreeInput) or not FIsActiveChoiceSurface then
  begin
    inherited;
    Exit;
  end;

  DigitKey := -1;
  InputSrc := cisKeyboard;

  if KeyChar in ['0'..'9'] then
  begin
    DigitKey := Ord(KeyChar) - Ord('0');
  end
  else
  begin
    case Key of
      vkUp, vkLeft:
      begin
        if FSelectedIndex > 0 then
          SelectedIndex := FSelectedIndex - 1
        else if (FSelectedIndex = -1) and (FItems.Count > 0) then
          SelectedIndex := 0;
        Exit;
      end;
      vkDown, vkRight:
      begin
        if FSelectedIndex < FItems.Count - 1 then
          SelectedIndex := FSelectedIndex + 1
        else if (FSelectedIndex = -1) and (FItems.Count > 0) then
          SelectedIndex := 0;
        Exit;
      end;
      vkReturn, vkSpace:
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
        Repaint;
        TriggerAction(ChoiceKindToActionKind(Item.Kind), Item.Key, Item.Text, Item.Payload, InputSrc);
      end;
    end;
  end
  else
    inherited;
end;

procedure THbFmxChoiceDeck.DrawHbControl(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens);
var
  HdrH: Single;
  TitleR, StepR: TRectF;
begin
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := Tokens.Surface;
  Canvas.FillRect(ARect, 0, 0, [], 1.0);

  HdrH := GetHeaderHeight;

  // Header Title
  if HdrH > 0 then
  begin
    Canvas.Font.Family := Tokens.FontFamily;
    Canvas.Font.Size := Tokens.SizeM;
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.Fill.Color := Tokens.Ink;

    if FContextTitle <> '' then
    begin
      TitleR := RectF(8, 4, ARect.Width - 80, 32);
      Canvas.FillText(TitleR, FContextTitle, False, 1.0, [], TTextAlign.Leading, TTextAlign.Center);
    end;

    if FStepInfo <> '' then
    begin
      StepR := RectF(ARect.Width - 80, 4, ARect.Width - 8, 32);
      Canvas.Font.Size := Tokens.SizeS;
      Canvas.Font.Style := [];
      Canvas.Fill.Color := Tokens.InkMuted;
      Canvas.FillText(StepR, FStepInfo, False, 1.0, [], TTextAlign.Trailing, TTextAlign.Center);
    end;
  end;

  // Draw Items based on layout
  case FLayoutMode of
    clmDeck:         DrawDeckLayout(Canvas, ARect, Tokens, HdrH);
    clmRow:          DrawRowLayout(Canvas, ARect, Tokens, HdrH);
    clmNumberedList: DrawNumberedListLayout(Canvas, ARect, Tokens, HdrH);
    clmInline:       DrawInlineLayout(Canvas, ARect, Tokens, HdrH);
  end;

  // State Overlay
  if FChoiceState in [csRegenerating, csNoReliableCandidates, csError, csLoading] then
    DrawStatusOverlay(Canvas, ARect, Tokens, HdrH);
end;

procedure THbFmxChoiceDeck.DrawDeckLayout(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens; TopOffset: Single);
var
  I: Integer;
  Item: THbChoiceItem;
  R, BadgeR, RecR, TextR: TRectF;
  AccentColor, BorderColor, FillColor: TAlphaColor;
  IsItemHover, IsItemFocused: Boolean;
  DimFactor: Single;
begin
  DimFactor := 1.0;
  if FChoiceState = csRegenerating then
    DimFactor := 0.45;

  for I := 0 to FItems.Count - 1 do
  begin
    Item := FItems[I];
    R := ItemRect(I);
    IsItemHover := (FHoverIndex = I) and (FChoiceState = csReady);
    IsItemFocused := (FSelectedIndex = I) and IsFocused and FIsActiveChoiceSurface;

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
    if not Item.Enabled then
    begin
      FillColor := HbColorWithAlpha(Tokens.Sunken, Round(160 * DimFactor));
      BorderColor := HbColorWithAlpha(Tokens.Border, Round(100 * DimFactor));
    end
    else if IsItemHover then
      FillColor := HbColorWithAlpha(AccentColor, Round(35 * DimFactor))
    else if Item.IsSelected and (Item.Kind = ckOption) then
      FillColor := HbColorWithAlpha(AccentColor, Round(25 * DimFactor))
    else
      FillColor := HbColorWithAlpha(Tokens.Surface, Round(255 * DimFactor));

    // Draw container card
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := FillColor;
    Canvas.FillRect(R, Tokens.RadiusM, Tokens.RadiusM, AllCorners, 1.0);

    Canvas.Stroke.Kind := TBrushKind.Solid;
    if IsItemFocused then
    begin
      Canvas.Stroke.Color := Tokens.FocusRing;
      Canvas.Stroke.Thickness := 2.0;
    end
    else if Item.IsSelected and (Item.Kind = ckOption) then
    begin
      Canvas.Stroke.Color := Tokens.Primary;
      Canvas.Stroke.Thickness := 2.0;
    end
    else
    begin
      Canvas.Stroke.Color := HbColorWithAlpha(BorderColor, Round(180 * DimFactor));
      Canvas.Stroke.Thickness := 1.0;
    end;
    Canvas.DrawRect(R, Tokens.RadiusM, Tokens.RadiusM, AllCorners, 1.0);

    // Key Badge [1..7, 8, 9, 0] or Multi-choice Checkbox badge
    BadgeR := RectF(R.Left + 8, R.Top + (R.Height - 28) * 0.5, R.Left + 40, R.Top + (R.Height + 28) * 0.5);
    if (FCardinality = ecMultiple) and (Item.Kind = ckOption) then
    begin
      if Item.IsSelected then
      begin
        Canvas.Fill.Color := HbColorWithAlpha(AccentColor, Round(220 * DimFactor));
        Canvas.FillRect(BadgeR, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);
        Canvas.Font.Size := Tokens.SizeS;
        Canvas.Font.Style := [TFontStyle.fsBold];
        Canvas.Fill.Color := HbColorWithAlpha(Tokens.Surface, Round(255 * DimFactor));
        Canvas.FillText(BadgeR, '✓ ' + IntToStr(Item.Key), False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
      end
      else
      begin
        Canvas.Fill.Color := HbColorWithAlpha(AccentColor, Round(35 * DimFactor));
        Canvas.FillRect(BadgeR, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);
        Canvas.Font.Size := Tokens.SizeM;
        Canvas.Font.Style := [TFontStyle.fsBold];
        Canvas.Fill.Color := HbColorWithAlpha(AccentColor, Round(255 * DimFactor));
        Canvas.FillText(BadgeR, IntToStr(Item.Key), False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
      end;
    end
    else
    begin
      Canvas.Fill.Color := HbColorWithAlpha(AccentColor, Round(35 * DimFactor));
      Canvas.FillRect(BadgeR, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);

      Canvas.Font.Size := Tokens.SizeM;
      Canvas.Font.Style := [TFontStyle.fsBold];
      Canvas.Fill.Color := HbColorWithAlpha(AccentColor, Round(255 * DimFactor));
      Canvas.FillText(BadgeR, IntToStr(Item.Key), False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
    end;

    // Text & Description
    TextR := RectF(R.Left + 48, R.Top + 4, R.Right - 56, R.Bottom - 4);
    if Item.Description <> '' then
    begin
      var TitleR := RectF(TextR.Left, R.Top + 5, TextR.Right, R.Top + 23);
      var DescR := RectF(TextR.Left, R.Top + 23, TextR.Right, R.Bottom - 4);

      Canvas.Font.Size := Tokens.SizeM;
      Canvas.Font.Style := [];
      Canvas.Fill.Color := HbColorWithAlpha(Tokens.Ink, Round(255 * DimFactor));
      Canvas.FillText(TitleR, Item.Text, False, 1.0, [], TTextAlign.Leading, TTextAlign.Center);

      Canvas.Font.Size := Tokens.SizeS;
      Canvas.Fill.Color := HbColorWithAlpha(Tokens.InkMuted, Round(255 * DimFactor));
      Canvas.FillText(DescR, Item.Description, False, 1.0, [], TTextAlign.Leading, TTextAlign.Center);
    end
    else
    begin
      Canvas.Font.Size := Tokens.SizeM;
      Canvas.Font.Style := [];
      Canvas.Fill.Color := HbColorWithAlpha(Tokens.Ink, Round(255 * DimFactor));
      Canvas.FillText(TextR, Item.Text, False, 1.0, [], TTextAlign.Leading, TTextAlign.Center);
    end;

    // Recommended Badge
    if Item.IsRecommended then
    begin
      RecR := RectF(R.Right - 54, R.Top + (R.Height - 20) * 0.5, R.Right - 8, R.Top + (R.Height + 20) * 0.5);
      Canvas.Fill.Color := HbColorWithAlpha(Tokens.ChoiceRecommended, Round(30 * DimFactor));
      Canvas.FillRect(RecR, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);

      Canvas.Stroke.Color := HbColorWithAlpha(Tokens.ChoiceRecommended, Round(160 * DimFactor));
      Canvas.Stroke.Thickness := 1.0;
      Canvas.DrawRect(RecR, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);

      Canvas.Font.Size := Tokens.SizeXS;
      Canvas.Font.Style := [TFontStyle.fsBold];
      Canvas.Fill.Color := HbColorWithAlpha(Tokens.ChoiceRecommended, Round(255 * DimFactor));
      Canvas.FillText(RecR, '推荐', False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
    end;
  end;
end;

procedure THbFmxChoiceDeck.DrawRowLayout(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens; TopOffset: Single);
var
  I: Integer;
  Item: THbChoiceItem;
  R: TRectF;
  AccentColor, BorderColor, FillColor: TAlphaColor;
  IsItemHover, IsItemFocused: Boolean;
  LabelStr: string;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    Item := FItems[I];
    R := ItemRect(I);
    IsItemHover := (FHoverIndex = I) and (FChoiceState = csReady);
    IsItemFocused := (FSelectedIndex = I) and IsFocused and FIsActiveChoiceSurface;

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
      FillColor := HbColorWithAlpha(AccentColor, 40)
    else if Item.IsSelected and (Item.Kind = ckOption) then
      FillColor := HbColorWithAlpha(AccentColor, 60)
    else
      FillColor := Tokens.Surface;

    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := FillColor;
    Canvas.FillRect(R, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);

    Canvas.Stroke.Kind := TBrushKind.Solid;
    if IsItemFocused then
    begin
      Canvas.Stroke.Color := Tokens.FocusRing;
      Canvas.Stroke.Thickness := 2.0;
    end
    else
    begin
      Canvas.Stroke.Color := HbColorWithAlpha(BorderColor, 180);
      Canvas.Stroke.Thickness := 1.0;
    end;
    Canvas.DrawRect(R, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);

    Canvas.Font.Size := Tokens.SizeS;
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.Fill.Color := Tokens.Ink;

    if (FCardinality = ecMultiple) and (Item.Kind = ckOption) and Item.IsSelected then
      LabelStr := '✓ ' + IntToStr(Item.Key) + ' ' + Item.Text
    else
      LabelStr := IntToStr(Item.Key) + ' ' + Item.Text;

    Canvas.FillText(R, LabelStr, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
  end;
end;

procedure THbFmxChoiceDeck.DrawNumberedListLayout(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens; TopOffset: Single);
var
  I: Integer;
  Item: THbChoiceItem;
  R, KeyR, TextR: TRectF;
  LabelStr: string;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    Item := FItems[I];
    R := ItemRect(I);

    if (FHoverIndex = I) or (FSelectedIndex = I) then
    begin
      Canvas.Fill.Kind := TBrushKind.Solid;
      Canvas.Fill.Color := HbColorWithAlpha(Tokens.Primary, 30);
      Canvas.FillRect(R, 0, 0, [], 1.0);
    end;

    KeyR := RectF(R.Left, R.Top, R.Left + 32, R.Bottom);
    Canvas.Font.Size := Tokens.SizeM;
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.Fill.Color := Tokens.Primary;

    if (FCardinality = ecMultiple) and (Item.Kind = ckOption) and Item.IsSelected then
      LabelStr := '✓' + IntToStr(Item.Key) + '.'
    else
      LabelStr := IntToStr(Item.Key) + '.';

    Canvas.FillText(KeyR, LabelStr, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);

    TextR := RectF(R.Left + 36, R.Top, R.Right - 4, R.Bottom);
    Canvas.Font.Size := Tokens.SizeM;
    Canvas.Font.Style := [];
    Canvas.Fill.Color := Tokens.Ink;
    Canvas.FillText(TextR, Item.Text, False, 1.0, [], TTextAlign.Leading, TTextAlign.Center);
  end;
end;

procedure THbFmxChoiceDeck.DrawInlineLayout(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens; TopOffset: Single);
var
  I: Integer;
  Item: THbChoiceItem;
  R: TRectF;
  LabelStr: string;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    Item := FItems[I];
    R := ItemRect(I);

    Canvas.Fill.Kind := TBrushKind.Solid;
    if (FHoverIndex = I) or (FSelectedIndex = I) or (Item.IsSelected and (Item.Kind = ckOption)) then
      Canvas.Fill.Color := HbColorWithAlpha(Tokens.ChoiceOption, 40)
    else
      Canvas.Fill.Color := Tokens.Surface;

    Canvas.FillRect(R, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);

    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.Stroke.Color := HbColorWithAlpha(Tokens.ChoiceOption, 160);
    Canvas.Stroke.Thickness := 1.0;
    Canvas.DrawRect(R, Tokens.RadiusS, Tokens.RadiusS, AllCorners, 1.0);

    Canvas.Font.Size := Tokens.SizeS;
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.Fill.Color := Tokens.Ink;

    if (FCardinality = ecMultiple) and (Item.Kind = ckOption) and Item.IsSelected then
      LabelStr := '✓' + IntToStr(Item.Key) + ':' + Item.Text
    else
      LabelStr := IntToStr(Item.Key) + ':' + Item.Text;

    Canvas.FillText(R, LabelStr, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
  end;
end;

procedure THbFmxChoiceDeck.DrawStatusOverlay(const Canvas: TCanvas; const ARect: TRectF; const Tokens: THbTokens; TopOffset: Single);
var
  BoxR: TRectF;
  DisplayMsg: string;
begin
  if FStatusMessage <> '' then
    DisplayMsg := FStatusMessage
  else if FChoiceState = csRegenerating then
    DisplayMsg := '正在换一组候选...'
  else if FChoiceState = csNoReliableCandidates then
    DisplayMsg := '当前信息不足，暂无可靠建议。'
  else if FChoiceState = csError then
    DisplayMsg := '加载失败，请重试。'
  else
    DisplayMsg := '处理中...';

  BoxR := RectF(16, Height - 42, Width - 16, Height - 8);
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := HbColorWithAlpha(Tokens.SurfaceAlt, 240);
  Canvas.FillRect(BoxR, Tokens.RadiusM, Tokens.RadiusM, AllCorners, 1.0);

  Canvas.Font.Family := Tokens.FontFamily;
  Canvas.Font.Size := Tokens.SizeS;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.Fill.Color := Tokens.Primary;
  Canvas.FillText(BoxR, DisplayMsg, False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
end;

end.
