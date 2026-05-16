unit DeepBase.VCL.LLMSettingsFrame;

{ DeepBase VCL LLM Settings Frame — Providers / Tiers / Test 三 Tab }

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  System.Threading, System.DateUtils, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.ExtCtrls, Vcl.Graphics, Vcl.Menus,
  DeepBase.LLM.Client, DeepBase.LLM.Types, DeepBase.LLM.Service;

type
  TLLMSettingsFrame = class(TFrame)
    PgSettings: TPageControl;
    // Providers Tab
    TabProviders: TTabSheet;
    LbProviders: TListBox;
    BtnAddProvider: TButton; BtnDeleteProvider: TButton;
    LblProviderName: TLabel; EdtProviderName: TEdit;
    LblEndpoint: TLabel; EdtEndpoint: TEdit;
    LblApiKey: TLabel; EdtApiKey: TEdit;
    LblApiFormat: TLabel; CmbApiFormat: TComboBox;
    BtnSaveProvider: TButton; BtnFetchModels: TButton;
    LblProviderModels: TLabel; LbProviderModels: TListBox;
    // Tiers Tab
    TabTiers: TTabSheet;
    CmbTierProvider: TComboBox; LblTierProvider: TLabel;
    LbAllModels: TListBox; LblAllModels: TLabel;
    BtnRefreshModels: TButton;
    BtnToSmart: TButton; BtnFromSmart: TButton;
    BtnToBalanced: TButton; BtnFromBalanced: TButton;
    BtnToFast: TButton; BtnFromFast: TButton;
    LblSmartTitle: TLabel; LbSmart: TListBox;
    LblBalancedTitle: TLabel; LbBalanced: TListBox;
    LblFastTitle: TLabel; LbFast: TListBox;
    BtnSmartUp: TButton; BtnSmartDown: TButton;
    BtnBalancedUp: TButton; BtnBalancedDown: TButton;
    BtnFastUp: TButton; BtnFastDown: TButton;
    PopupTier: TPopupMenu;
    MnuPrimary: TMenuItem; MnuFallback: TMenuItem; MnuDisabled: TMenuItem;
    // Test Tab
    TabTest: TTabSheet;
    LbTestProviders: TListBox;
    LbTestModels: TListBox;
    MemTestPrompt: TMemo;
    BtnTest: TButton;
    MemTestResponse: TMemo;
    LblTestProvider: TLabel; LblTestModel: TLabel;
    LblTestPrompt: TLabel; LblElapsed: TLabel;
    // Events
    procedure LbProvidersClick(Sender: TObject);
    procedure BtnAddProviderClick(Sender: TObject);
    procedure BtnDeleteProviderClick(Sender: TObject);
    procedure BtnSaveProviderClick(Sender: TObject);
    procedure BtnFetchModelsClick(Sender: TObject);
    procedure CmbTierProviderChange(Sender: TObject);
    procedure BtnRefreshModelsClick(Sender: TObject);
    procedure BtnToSmartClick(Sender: TObject); procedure BtnToBalancedClick(Sender: TObject);
    procedure BtnToFastClick(Sender: TObject);
    procedure BtnFromSmartClick(Sender: TObject); procedure BtnFromBalancedClick(Sender: TObject);
    procedure BtnFromFastClick(Sender: TObject);
    procedure BtnSmartUpClick(Sender: TObject); procedure BtnSmartDownClick(Sender: TObject);
    procedure BtnBalancedUpClick(Sender: TObject); procedure BtnBalancedDownClick(Sender: TObject);
    procedure BtnFastUpClick(Sender: TObject); procedure BtnFastDownClick(Sender: TObject);
    procedure LbTestProvidersClick(Sender: TObject);
    procedure BtnTestClick(Sender: TObject);
    procedure TierListMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure MnuPrimaryClick(Sender: TObject); procedure MnuFallbackClick(Sender: TObject);
    procedure MnuDisabledClick(Sender: TObject);
  private
    FProviders: TList<TProviderConfig>;
    FProviderModels: TDictionary<string, TArray<string>>;
    FLastRightClickList: TListBox;
    procedure RefreshProviderListBox;
    procedure SyncFieldsToProvider;
    procedure SyncProviderToFields;
    procedure RefreshAllModelList;
    procedure RefreshTierList(AListBox: TListBox; const ATier: string);
    procedure RefreshAllTierLists;
    procedure MoveToTier(const ATier: string);
    procedure MoveFromTier(const ATier: string);
    procedure SetTierStatus(const AListBox: TListBox; const AStatus: string);
    procedure SwapTierItems(AListBox: TListBox; AIdx1, AIdx2: Integer);
    procedure RefreshTestModels;
    procedure SaveToAdmin;
    function GetFullModelKey(const AModelId, AProvider: string): string;
    function ParseModelKey(const AFullKey: string; out AModelId, AProvider: string): Boolean;
    function ParseTierItem(const AFullText: string; out AModelId, AProvider, AStatus: string): Boolean;
    procedure DoFetchModels(const AProvider: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

{$R *.dfm}

constructor TLLMSettingsFrame.Create(AOwner: TComponent);
begin
  inherited;
  FProviders := TList<TProviderConfig>.Create;
  FProviderModels := TDictionary<string, TArray<string>>.Create;
  PgSettings.ActivePage := TabProviders;
  CmbApiFormat.ItemIndex := 0;
  MemTestPrompt.Text := '你是什么模型？';
  RefreshProviderListBox;
  if LbProviders.Items.Count > 0 then
  begin
    LbProviders.ItemIndex := 0;
    SyncProviderToFields;
  end;
end;

destructor TLLMSettingsFrame.Destroy;
begin
  FreeAndNil(FProviders);
  FreeAndNil(FProviderModels);
  inherited;
end;

// ---- Provider List ----

procedure TLLMSettingsFrame.RefreshProviderListBox;
begin
  LbProviders.Items.Clear;
  CmbTierProvider.Items.Clear;
  LbTestProviders.Items.Clear;

  FProviders.Clear;
  for var P in LLMAdmin.GetProviders do
    FProviders.Add(P);

  for var P in FProviders do
  begin
    LbProviders.Items.Add(P.Name);
    CmbTierProvider.Items.Add(P.Name);
    LbTestProviders.Items.Add(P.Name);
  end;

  if CmbTierProvider.Items.Count > 0 then
    CmbTierProvider.ItemIndex := 0;
end;

procedure TLLMSettingsFrame.LbProvidersClick(Sender: TObject);
begin
  SyncProviderToFields;
end;

procedure TLLMSettingsFrame.SyncProviderToFields;
begin
  if LbProviders.ItemIndex < 0 then Exit;
  var Name := LbProviders.Items[LbProviders.ItemIndex];
  var P := FProviders[LbProviders.ItemIndex];
  if P.Name <> Name then Exit;
  EdtProviderName.Text := P.Name;
  EdtEndpoint.Text := P.Endpoint;
  EdtApiKey.Text := '';
  CmbApiFormat.ItemIndex := 0;
  if P.ApiFormat = 'anthropic' then CmbApiFormat.ItemIndex := 1;

  LbProviderModels.Items.Clear;
  var Models: TArray<string>;
  if FProviderModels.TryGetValue(Name, Models) then
    for var M in Models do
      LbProviderModels.Items.Add(M);
end;

procedure TLLMSettingsFrame.SyncFieldsToProvider;
begin
  if LbProviders.ItemIndex < 0 then Exit;
  var OldName := LbProviders.Items[LbProviders.ItemIndex];
  var NewName := Trim(EdtProviderName.Text);
  if (OldName = '') or (NewName = '') then Exit;

  var P: TProviderConfig;
  P.Name := NewName;
  P.Endpoint := Trim(EdtEndpoint.Text);
  P.ApiFormat := 'openai';
  if CmbApiFormat.ItemIndex = 1 then P.ApiFormat := 'anthropic';

  // Update local list
  if OldName <> NewName then
  begin
    LLMAdmin.RemoveProvider(OldName);
    if FProviderModels.ContainsKey(OldName) then
    begin
      var Models := FProviderModels[OldName];
      FProviderModels.Remove(OldName);
      FProviderModels.AddOrSetValue(NewName, Models);
    end;
  end;
  LLMAdmin.AddProvider(NewName, P.Endpoint, Trim(EdtApiKey.Text), P.ApiFormat);
  RefreshProviderListBox;
  var Idx := LbProviders.Items.IndexOf(NewName);
  if Idx >= 0 then LbProviders.ItemIndex := Idx;
end;

procedure TLLMSettingsFrame.BtnAddProviderClick(Sender: TObject);
begin
  LLMAdmin.AddProvider('NewProvider', '', '', 'openai');
  RefreshProviderListBox;
  LbProviders.ItemIndex := LbProviders.Items.Count - 1;
  SyncProviderToFields;
  EdtProviderName.SetFocus;
end;

procedure TLLMSettingsFrame.BtnDeleteProviderClick(Sender: TObject);
begin
  if LbProviders.ItemIndex < 0 then Exit;
  var Name := LbProviders.Items[LbProviders.ItemIndex];
  LLMAdmin.RemoveProvider(Name);
  FProviderModels.Remove(Name);
  RefreshProviderListBox;
  LbProviderModels.Items.Clear;
  if LbProviders.Items.Count > 0 then
  begin
    LbProviders.ItemIndex := 0;
    SyncProviderToFields;
  end;
end;

procedure TLLMSettingsFrame.BtnSaveProviderClick(Sender: TObject);
begin
  SyncFieldsToProvider;
  LLMAdmin.Save;
end;

procedure TLLMSettingsFrame.DoFetchModels(const AProvider: string);
var
  P: TProviderConfig;
begin
  for var PP in FProviders do
    if PP.Name = AProvider then
    begin
      P := PP;
      Break;
    end;
  if P.Name = '' then Exit;

  var Models := LLMAdmin.GetAvailableModels(P.Name);
  if Length(Models) > 0 then
  begin
    FProviderModels.AddOrSetValue(P.Name, Models);
    LbProviderModels.Items.Clear;
    for var M in Models do
      LbProviderModels.Items.Add(M);
    RefreshAllModelList;
    RefreshAllTierLists;
  end;
end;

procedure TLLMSettingsFrame.BtnFetchModelsClick(Sender: TObject);
begin
  SyncFieldsToProvider;
  if LbProviders.ItemIndex < 0 then Exit;
  BtnFetchModels.Enabled := False;
  BtnFetchModels.Caption := 'Loading...';
  LbProviderModels.Items.Clear;
  Application.ProcessMessages;
  // VCL-003: Capture VCL control value before spawning the worker; control
  // members must not be touched off the UI thread.
  var LProviderName := LbProviders.Items[LbProviders.ItemIndex];
  TThread.CreateAnonymousThread(procedure
  begin
    DoFetchModels(LProviderName);
    TThread.Queue(nil, procedure
    begin
      BtnFetchModels.Enabled := True;
      BtnFetchModels.Caption := 'Models';
    end);
  end).Start;
end;

// ---- Tier Tab ----

procedure TLLMSettingsFrame.CmbTierProviderChange(Sender: TObject);
begin
  RefreshAllModelList;
  RefreshAllTierLists;
end;

procedure TLLMSettingsFrame.BtnRefreshModelsClick(Sender: TObject);
begin
  var N := CmbTierProvider.Text;
  if N = '' then Exit;
  BtnRefreshModels.Enabled := False;
  BtnRefreshModels.Caption := 'Loading...';
  Application.ProcessMessages;
  TThread.CreateAnonymousThread(procedure
  begin
    DoFetchModels(N);
    TThread.Queue(nil, procedure
    begin
      RefreshAllModelList;
      RefreshAllTierLists;
      BtnRefreshModels.Enabled := True;
      BtnRefreshModels.Caption := 'Refresh Models';
    end);
  end).Start;
end;

// ---- Model Key Parsing ----

function TLLMSettingsFrame.GetFullModelKey(const AModelId, AProvider: string): string;
begin
  Result := Format('[%s] %s', [AProvider, AModelId]);
end;

function TLLMSettingsFrame.ParseModelKey(const AFullKey: string; out AModelId, AProvider: string): Boolean;
begin
  Result := False;
  if (Length(AFullKey) < 3) or (AFullKey[1] <> '[') then Exit;
  var CB := Pos(']', AFullKey);
  if CB = 0 then Exit;
  AProvider := Copy(AFullKey, 2, CB - 2);
  AModelId := Trim(Copy(AFullKey, CB + 2, MaxInt));
  Result := True;
end;

function TLLMSettingsFrame.ParseTierItem(const AFullText: string; out AModelId, AProvider, AStatus: string): Boolean;
begin
  var S := AFullText;
  AStatus := '';
  if Pos(' [首用]', S) > 0 then begin AStatus := 'primary'; S := StringReplace(S, ' [首用]', '', []); end
  else if Pos(' [兜底]', S) > 0 then begin AStatus := 'fallback'; S := StringReplace(S, ' [兜底]', '', []); end
  else if Pos(' [不用]', S) > 0 then begin AStatus := 'disabled'; S := StringReplace(S, ' [不用]', '', []); end;
  Result := ParseModelKey(Trim(S), AModelId, AProvider);
end;

procedure TLLMSettingsFrame.RefreshAllModelList;
begin
  LbAllModels.Items.Clear;
  var N := CmbTierProvider.Text;
  if N = '' then Exit;
  var Models: TArray<string>;
  if FProviderModels.TryGetValue(N, Models) then
    for var M in Models do
      LbAllModels.Items.Add(GetFullModelKey(M, N));
end;

procedure TLLMSettingsFrame.RefreshTierList(AListBox: TListBox; const ATier: string);
begin
  AListBox.Items.Clear;
  var Models := LLMAdmin.GetTierModels(TModelTier(ATier));
  for var I := 0 to High(Models) do
  begin
    // VCL-004: Match the provider that actually owns the model rather than
    // selecting the first provider unconditionally.
    var ProvName := '';
    for var P in FProviders do
    begin
      var Found := False;
      var ProviderModels: TArray<string>;
      if FProviderModels.TryGetValue(P.Name, ProviderModels) then
        for var PM in ProviderModels do
          if SameText(PM, Models[I]) then
          begin
            Found := True;
            Break;
          end;
      if Found then
      begin
        ProvName := P.Name;
        Break;
      end;
    end;
    var Tag := if I = 0 then ' [首用]' else ' [兜底]';
    AListBox.Items.Add(GetFullModelKey(Models[I], ProvName) + Tag);
  end;
end;

procedure TLLMSettingsFrame.RefreshAllTierLists;
begin
  RefreshTierList(LbSmart, 'smart');
  RefreshTierList(LbBalanced, 'balanced');
  RefreshTierList(LbFast, 'fast');
end;

procedure TLLMSettingsFrame.MoveToTier(const ATier: string);
begin
  if LbAllModels.ItemIndex < 0 then Exit;
  var FK := LbAllModels.Items[LbAllModels.ItemIndex];
  var MId, Prov: string;
  if not ParseModelKey(FK, MId, Prov) then Exit;
  var Existing := LLMAdmin.GetTierModels(TModelTier(ATier));
  SetLength(Existing, Length(Existing) + 1);
  Existing[High(Existing)] := MId;
  LLMAdmin.SetTierModels(TModelTier(ATier), Existing);
  RefreshAllTierLists;
end;

procedure TLLMSettingsFrame.MoveFromTier(const ATier: string);
var
  LB: TListBox;
begin
  if ATier = 'smart' then LB := LbSmart
  else if ATier = 'balanced' then LB := LbBalanced
  else if ATier = 'fast' then LB := LbFast
  else Exit;
  if LB.ItemIndex < 0 then Exit;
  var FK := LB.Items[LB.ItemIndex];
  var MId, Prov, St: string;
  if not ParseTierItem(FK, MId, Prov, St) then Exit;
  var Models := LLMAdmin.GetTierModels(TModelTier(ATier));
  var NewList: TArray<string>;
  for var M in Models do
    if M <> MId then
    begin
      SetLength(NewList, Length(NewList) + 1);
      NewList[High(NewList)] := M;
    end;
  LLMAdmin.SetTierModels(TModelTier(ATier), NewList);
  RefreshAllTierLists;
end;

procedure TLLMSettingsFrame.BtnToSmartClick(Sender: TObject); begin MoveToTier('smart'); end;
procedure TLLMSettingsFrame.BtnToBalancedClick(Sender: TObject); begin MoveToTier('balanced'); end;
procedure TLLMSettingsFrame.BtnToFastClick(Sender: TObject); begin MoveToTier('fast'); end;
procedure TLLMSettingsFrame.BtnFromSmartClick(Sender: TObject); begin MoveFromTier('smart'); end;
procedure TLLMSettingsFrame.BtnFromBalancedClick(Sender: TObject); begin MoveFromTier('balanced'); end;
procedure TLLMSettingsFrame.BtnFromFastClick(Sender: TObject); begin MoveFromTier('fast'); end;

procedure TLLMSettingsFrame.SwapTierItems(AListBox: TListBox; AIdx1, AIdx2: Integer);
begin
  if (AIdx1 < 0) or (AIdx2 < 0) or (AIdx1 >= AListBox.Items.Count) or (AIdx2 >= AListBox.Items.Count) then Exit;
  AListBox.Items.Exchange(AIdx1, AIdx2);
  // VCL-005: Persist the new ordering so the in-memory swap is reflected in
  // LLMAdmin tier configuration.
  var LTier: string;
  if AListBox = LbSmart then
    LTier := 'smart'
  else if AListBox = LbBalanced then
    LTier := 'balanced'
  else if AListBox = LbFast then
    LTier := 'fast'
  else
    Exit;
  var LModels := LLMAdmin.GetTierModels(TModelTier(LTier));
  if (AIdx1 < Length(LModels)) and (AIdx2 < Length(LModels)) then
  begin
    var LTmp := LModels[AIdx1];
    LModels[AIdx1] := LModels[AIdx2];
    LModels[AIdx2] := LTmp;
    LLMAdmin.SetTierModels(TModelTier(LTier), LModels);
  end;
end;

procedure TLLMSettingsFrame.BtnSmartUpClick(Sender: TObject); begin SwapTierItems(LbSmart, LbSmart.ItemIndex, LbSmart.ItemIndex-1); end;
procedure TLLMSettingsFrame.BtnSmartDownClick(Sender: TObject); begin SwapTierItems(LbSmart, LbSmart.ItemIndex, LbSmart.ItemIndex+1); end;
procedure TLLMSettingsFrame.BtnBalancedUpClick(Sender: TObject); begin SwapTierItems(LbBalanced, LbBalanced.ItemIndex, LbBalanced.ItemIndex-1); end;
procedure TLLMSettingsFrame.BtnBalancedDownClick(Sender: TObject); begin SwapTierItems(LbBalanced, LbBalanced.ItemIndex, LbBalanced.ItemIndex+1); end;
procedure TLLMSettingsFrame.BtnFastUpClick(Sender: TObject); begin SwapTierItems(LbFast, LbFast.ItemIndex, LbFast.ItemIndex-1); end;
procedure TLLMSettingsFrame.BtnFastDownClick(Sender: TObject); begin SwapTierItems(LbFast, LbFast.ItemIndex, LbFast.ItemIndex+1); end;

procedure TLLMSettingsFrame.TierListMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbRight then Exit;
  var LB := Sender as TListBox;
  var I := LB.ItemAtPos(Point(X, Y), True);
  if I >= 0 then
  begin
    LB.ItemIndex := I;
    FLastRightClickList := LB;
    PopupTier.Popup(LB.ClientToScreen(Point(X, Y)).X, LB.ClientToScreen(Point(X, Y)).Y);
  end;
end;

procedure TLLMSettingsFrame.SetTierStatus(const AListBox: TListBox; const AStatus: string);
begin
  // Status change — update tier model entry
  // For simplicity, status is tracked inline with model ordering
  RefreshAllTierLists;
end;

procedure TLLMSettingsFrame.MnuPrimaryClick(Sender: TObject); begin SetTierStatus(FLastRightClickList, 'primary'); end;
procedure TLLMSettingsFrame.MnuFallbackClick(Sender: TObject); begin SetTierStatus(FLastRightClickList, 'fallback'); end;
procedure TLLMSettingsFrame.MnuDisabledClick(Sender: TObject); begin SetTierStatus(FLastRightClickList, 'disabled'); end;

// ---- Test Tab ----

procedure TLLMSettingsFrame.LbTestProvidersClick(Sender: TObject);
begin
  RefreshTestModels;
end;

procedure TLLMSettingsFrame.RefreshTestModels;
begin
  LbTestModels.Items.Clear;
  if LbTestProviders.ItemIndex < 0 then Exit;
  var N := LbTestProviders.Items[LbTestProviders.ItemIndex];
  var Models: TArray<string>;
  if FProviderModels.TryGetValue(N, Models) then
    for var M in Models do
      LbTestModels.Items.Add(Format('[%s] %s', [N, M]));
end;

procedure TLLMSettingsFrame.BtnTestClick(Sender: TObject);
begin
  if (LbTestProviders.ItemIndex < 0) or (LbTestModels.ItemIndex < 0) then Exit;
  var ProvName := LbTestProviders.Items[LbTestProviders.ItemIndex];
  var FullModel := LbTestModels.Items[LbTestModels.ItemIndex];
  var Prompt := MemTestPrompt.Text;
  if (FullModel = '') or (Prompt = '') then Exit;

  var ModelId := FullModel;
  if (Length(ModelId) > 0) and (ModelId[1] = '[') then
  begin
    var CB := Pos(']', ModelId);
    if CB > 0 then ModelId := Trim(Copy(ModelId, CB + 2, MaxInt));
  end;

  BtnTest.Enabled := False;
  BtnTest.Caption := 'Testing...';
  MemTestResponse.Text := '';
  LblElapsed.Caption := '';
  Application.ProcessMessages;

  var Started := Now;
  TThread.CreateAnonymousThread(procedure
  var
    Dur: Integer; Err: string; OK: Boolean;
  begin
    OK := LLMAdmin.TestConnection(ProvName, ModelId, Dur, Err);
    TThread.Queue(nil, procedure
    begin
      LblElapsed.Caption := Format('Done: %ds', [SecondsBetween(Now, Started)]);
      if OK then
        MemTestResponse.Text := Format('OK (%dms)', [Dur])
      else
        MemTestResponse.Text := 'FAILED: ' + Err;
      BtnTest.Enabled := True;
      BtnTest.Caption := 'Test';
    end);
  end).Start;
end;

procedure TLLMSettingsFrame.SaveToAdmin;
begin
  LLMAdmin.Save;
end;

end.
