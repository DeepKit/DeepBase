unit DeepBase.VCL.DeepShell.Settings;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  DeepBase.VCL.DeepShell.Intf;

type
  TShellInMemorySettingsStore = class(TInterfacedObject, IShellSettingsStore)
  private
    FLock: TCriticalSection;
    FValues: TDictionary<string, string>;
  public
    constructor Create;
    destructor Destroy; override;
    function ReadString(const AKey, ADefault: string): string;
    procedure WriteString(const AKey, AValue: string);
    function ReadBool(const AKey: string; ADefault: Boolean): Boolean;
    procedure WriteBool(const AKey: string; AValue: Boolean);
    function ReadInteger(const AKey: string; ADefault: Integer): Integer;
    procedure WriteInteger(const AKey: string; AValue: Integer);
    procedure RemoveKey(const AKey: string);
  end;

  TDeepShellSettingsForm = class(TForm)
  private
    FProviders: TList<ISettingsPageProvider>;
    FLocalization: IShellLocalizationService;
    FCommands: IShellCommandManager;
    FResetAction: TFunc<ISettingsPageProvider, Boolean>;
    FList: TListBox;
    FHost: TPanel;
    FButtons: TPanel;
    FBtnOK: TButton;
    FBtnApply: TButton;
    FBtnCancel: TButton;
    FBtnDefaults: TButton;
    FPages: TDictionary<string, TControl>;
    FCurrent: TControl;
    function L(const AKey, ADefault: string): string;
    procedure CreateLayout;
    procedure RebuildList;
    procedure ShowProvider(AIndex: Integer);
    procedure DoOK(Sender: TObject);
    procedure DoApply(Sender: TObject);
    procedure DoCancel(Sender: TObject);
    procedure DoDefaults(Sender: TObject);
    procedure DoListClick(Sender: TObject);
  public
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
    destructor Destroy; override;
    procedure SetProviders(const AProviders: TArray<ISettingsPageProvider>);
    procedure SetLocalization(const ALocalization: IShellLocalizationService);
    procedure SetCommands(const ACommands: IShellCommandManager);
    procedure SetResetAction(const AAction: TFunc<ISettingsPageProvider, Boolean>);
    function Run: Boolean;
  end;

implementation

uses
  Vcl.Dialogs;

constructor TShellInMemorySettingsStore.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FValues := TDictionary<string, string>.Create;
end;

destructor TShellInMemorySettingsStore.Destroy;
begin
  FreeAndNil(FValues);
  FreeAndNil(FLock);
  inherited;
end;

function TShellInMemorySettingsStore.ReadString(const AKey, ADefault: string): string;
begin
  FLock.Enter;
  try
    if not FValues.TryGetValue(AKey, Result) then
      Result := ADefault;
  finally
    FLock.Leave;
  end;
end;

procedure TShellInMemorySettingsStore.WriteString(const AKey, AValue: string);
begin
  if AKey = '' then Exit;
  FLock.Enter;
  try
    FValues.AddOrSetValue(AKey, AValue);
  finally
    FLock.Leave;
  end;
end;

function TShellInMemorySettingsStore.ReadBool(const AKey: string; ADefault: Boolean): Boolean;
var
  LRaw: string;
begin
  LRaw := ReadString(AKey, '');
  if LRaw = '' then Exit(ADefault);
  Result := SameText(LRaw, 'true') or (LRaw = '1');
end;

procedure TShellInMemorySettingsStore.WriteBool(const AKey: string; AValue: Boolean);
begin
  WriteString(AKey, if AValue then 'true' else 'false');
end;

function TShellInMemorySettingsStore.ReadInteger(const AKey: string; ADefault: Integer): Integer;
var
  LRaw: string;
begin
  LRaw := ReadString(AKey, '');
  if LRaw = '' then Exit(ADefault);
  if not TryStrToInt(LRaw, Result) then
    Result := ADefault;
end;

procedure TShellInMemorySettingsStore.WriteInteger(const AKey: string; AValue: Integer);
begin
  WriteString(AKey, IntToStr(AValue));
end;

procedure TShellInMemorySettingsStore.RemoveKey(const AKey: string);
begin
  FLock.Enter;
  try
    FValues.Remove(AKey);
  finally
    FLock.Leave;
  end;
end;

constructor TDeepShellSettingsForm.CreateNew(AOwner: TComponent; Dummy: Integer);
begin
  inherited CreateNew(AOwner, Dummy);
  // Caption assigned in SetLocalization; falls back to default via L() if no service.
  Caption := L('shell.settings.title', 'Settings');
  Width := 720;
  Height := 480;
  Position := poOwnerFormCenter;
  BorderStyle := bsSizeable;
  FProviders := TList<ISettingsPageProvider>.Create;
  FPages := TDictionary<string, TControl>.Create;
  CreateLayout;
end;

destructor TDeepShellSettingsForm.Destroy;
begin
  FCurrent := nil;
  FLocalization := nil;
  FCommands := nil;
  FResetAction := nil;
  FreeAndNil(FPages);
  FreeAndNil(FProviders);
  inherited;
end;

function TDeepShellSettingsForm.L(const AKey, ADefault: string): string;
begin
  if FLocalization <> nil then
    Result := FLocalization.Text(AKey, ADefault)
  else
    Result := ADefault;
end;

procedure TDeepShellSettingsForm.SetLocalization(const ALocalization: IShellLocalizationService);
begin
  FLocalization := ALocalization;
  Caption := L('shell.settings.title', 'Settings');
  if FBtnOK <> nil then FBtnOK.Caption := L('shell.btn.ok', 'OK');
  if FBtnApply <> nil then FBtnApply.Caption := L('shell.btn.apply', 'Apply');
  if FBtnCancel <> nil then FBtnCancel.Caption := L('shell.btn.cancel', 'Cancel');
  if FBtnDefaults <> nil then FBtnDefaults.Caption := L('shell.btn.restoreDefaults', 'Restore Defaults');
end;

procedure TDeepShellSettingsForm.SetCommands(const ACommands: IShellCommandManager);
begin
  FCommands := ACommands;
end;

procedure TDeepShellSettingsForm.SetResetAction(const AAction: TFunc<ISettingsPageProvider, Boolean>);
begin
  FResetAction := AAction;
end;

procedure TDeepShellSettingsForm.CreateLayout;
begin
  FList := TListBox.Create(Self);
  FList.Parent := Self;
  FList.Align := alLeft;
  FList.Width := 200;
  FList.OnClick := DoListClick;

  FButtons := TPanel.Create(Self);
  FButtons.Parent := Self;
  FButtons.Align := alBottom;
  FButtons.Height := 44;
  FButtons.BevelOuter := bvNone;
  FButtons.Padding.SetBounds(8, 8, 8, 8);

  FBtnDefaults := TButton.Create(Self);
  FBtnDefaults.Parent := FButtons;
  FBtnDefaults.Caption := L('shell.btn.restoreDefaults', 'Restore Defaults');
  FBtnDefaults.Width := 120;
  FBtnDefaults.Align := alLeft;
  FBtnDefaults.OnClick := DoDefaults;

  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := FButtons;
  FBtnCancel.Caption := L('shell.btn.cancel', 'Cancel');
  FBtnCancel.Width := 88;
  FBtnCancel.Align := alRight;
  FBtnCancel.OnClick := DoCancel;
  FBtnCancel.Cancel := True;

  FBtnApply := TButton.Create(Self);
  FBtnApply.Parent := FButtons;
  FBtnApply.Caption := L('shell.btn.apply', 'Apply');
  FBtnApply.Width := 88;
  FBtnApply.Align := alRight;
  FBtnApply.OnClick := DoApply;

  FBtnOK := TButton.Create(Self);
  FBtnOK.Parent := FButtons;
  FBtnOK.Caption := L('shell.btn.ok', 'OK');
  FBtnOK.Width := 88;
  FBtnOK.Align := alRight;
  FBtnOK.OnClick := DoOK;
  FBtnOK.Default := True;

  FHost := TPanel.Create(Self);
  FHost.Parent := Self;
  FHost.Align := alClient;
  FHost.BevelOuter := bvNone;
  FHost.Padding.SetBounds(8, 8, 8, 8);
end;

procedure TDeepShellSettingsForm.SetProviders(const AProviders: TArray<ISettingsPageProvider>);
var
  I: Integer;
begin
  FProviders.Clear;
  for I := 0 to High(AProviders) do
    if AProviders[I] <> nil then
      FProviders.Add(AProviders[I]);
  RebuildList;
  if FList.Count > 0 then
  begin
    FList.ItemIndex := 0;
    ShowProvider(0);
  end;
end;

procedure TDeepShellSettingsForm.RebuildList;
var
  I: Integer;
begin
  FList.Items.BeginUpdate;
  try
    FList.Items.Clear;
    for I := 0 to FProviders.Count - 1 do
      FList.Items.Add(FProviders[I].Caption);
  finally
    FList.Items.EndUpdate;
  end;
end;

procedure TDeepShellSettingsForm.ShowProvider(AIndex: Integer);
var
  LProvider: ISettingsPageProvider;
  LCtl: TControl;
  LLabel: TLabel;
begin
  if (AIndex < 0) or (AIndex >= FProviders.Count) then Exit;
  LProvider := FProviders[AIndex];
  if FCurrent <> nil then
    FCurrent.Visible := False;
  if not FPages.TryGetValue(LProvider.PageId, LCtl) then
  begin
    try
      LCtl := LProvider.CreatePage(FHost);
    except
      on E: Exception do
      begin
        LLabel := TLabel.Create(FHost);
        LLabel.Parent := FHost;
        LLabel.Caption := Format('Failed to create settings page %s: %s',
          [LProvider.PageId, E.Message]);
        LCtl := LLabel;
      end;
    end;
    if LCtl <> nil then
    begin
      LCtl.Parent := FHost;
      LCtl.Align := alClient;
      FPages.Add(LProvider.PageId, LCtl);
    end;
  end;
  if LCtl <> nil then
  begin
    LCtl.Visible := True;
    FCurrent := LCtl;
  end;
end;

procedure TDeepShellSettingsForm.DoListClick(Sender: TObject);
begin
  ShowProvider(FList.ItemIndex);
end;

procedure TDeepShellSettingsForm.DoOK(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to FProviders.Count - 1 do
    try
      FProviders[I].Apply;
    except
      on E: Exception do
        ShowMessage(Format('Settings page "%s" failed to apply: %s',
          [FProviders[I].Caption, E.Message]));
    end;
  ModalResult := mrOk;
end;

procedure TDeepShellSettingsForm.DoApply(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to FProviders.Count - 1 do
    try
      FProviders[I].Apply;
    except
      on E: Exception do
        ShowMessage(Format('Settings page "%s" failed to apply: %s',
          [FProviders[I].Caption, E.Message]));
    end;
end;

procedure TDeepShellSettingsForm.DoCancel(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to FProviders.Count - 1 do
    try
      FProviders[I].Cancel;
    except
    end;
  ModalResult := mrCancel;
end;

procedure TDeepShellSettingsForm.DoDefaults(Sender: TObject);
var
  LIdx: Integer;
  LProvider: ISettingsPageProvider;
begin
  LIdx := FList.ItemIndex;
  if (LIdx < 0) or (LIdx >= FProviders.Count) then Exit;
  LProvider := FProviders[LIdx];
  // The dialog's Restore Defaults button is per-page (resets only the
  // currently visible settings page). Route through FResetAction so
  // TDeepMainForm can wrap the per-page reset in a governance check (with
  // page-specific evidence) before calling provider.RestoreDefaults.
  // Falls back to direct dispatch when no action is injected (unit tests
  // or non-shell hosts).
  if Assigned(FResetAction) then
  begin
    try
      FResetAction(LProvider);
      Exit;
    except
      on E: Exception do
        ShowMessage(Format('RestoreDefaults via reset action failed: %s', [E.Message]));
    end;
  end;
  try
    LProvider.RestoreDefaults;
  except
    on E: Exception do
      ShowMessage(Format('RestoreDefaults failed for "%s": %s',
        [LProvider.Caption, E.Message]));
  end;
end;

function TDeepShellSettingsForm.Run: Boolean;
begin
  Result := ShowModal = mrOk;
end;

end.
