{ ============================================================================
  DeepBase.VCL.TrayIcon - VCL Tray Icon Component

  Description: VCL wrapper for DeepBase.TrayIcon with host-form lifecycle
               support (minimize to tray / close to tray / restore).
  ============================================================================ }

unit DeepBase.VCL.TrayIcon;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  Vcl.Graphics,
  Vcl.Menus,
  Vcl.Controls,
  Vcl.Forms,
  DeepBase.TrayIcon;

type
  TDeepBaseTrayIcon = class(TComponent)
  private
    FToolTip: string;
    FIcon: TIcon;
    FPopupMenu: TPopupMenu;
    FHostForm: TForm;
    FVisible: Boolean;
    FMinimizeToTray: Boolean;
    FCloseToTray: Boolean;
    FRestoreOnDoubleClick: Boolean;
    FOnDoubleClick: TNotifyEvent;
    FOnBalloonClick: TNotifyEvent;
    FMenuAdapter: IInterface;
    FPrevOnCloseQuery: TCloseQueryEvent;
    FPrevOnResize: TNotifyEvent;
    FHooksInstalled: Boolean;
    FAllowClose: Boolean;
    procedure SetToolTip(const Value: string);
    procedure SetIcon(const Value: TIcon);
    procedure SetPopupMenu(const Value: TPopupMenu);
    procedure SetHostForm(const Value: TForm);
    procedure SetVisible(const Value: Boolean);
    procedure SetMinimizeToTray(const Value: Boolean);
    procedure SetCloseToTray(const Value: Boolean);
    procedure SetRestoreOnDoubleClick(const Value: Boolean);
    procedure IconChange(Sender: TObject);
    procedure HostFormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure HostFormResize(Sender: TObject);
    procedure InstallHostFormHooks;
    procedure UninstallHostFormHooks;
    procedure RestoreHostForm;
    procedure HideHostFormToTray;
    procedure UpdateTrayCallbacks;
    procedure UpdateTrayMenuAdapter;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowBalloon(const ATitle, AText: string;
      AIconType: TBalloonIconType = bitInfo; ATimeoutMs: Integer = 5000);
    procedure HideBalloon;
    procedure ShowHostForm;
    procedure HideHostForm;
    procedure ToggleHostForm;
    procedure CloseHostForm;
  published
    property ToolTip: string read FToolTip write SetToolTip;
    property Icon: TIcon read FIcon write SetIcon;
    property PopupMenu: TPopupMenu read FPopupMenu write SetPopupMenu;
    property HostForm: TForm read FHostForm write SetHostForm;
    property MinimizeToTray: Boolean read FMinimizeToTray write SetMinimizeToTray default True;
    property CloseToTray: Boolean read FCloseToTray write SetCloseToTray default True;
    property RestoreOnDoubleClick: Boolean read FRestoreOnDoubleClick write SetRestoreOnDoubleClick default True;
    property Visible: Boolean read FVisible write SetVisible default False;
    property OnDoubleClick: TNotifyEvent read FOnDoubleClick write FOnDoubleClick;
    property OnBalloonClick: TNotifyEvent read FOnBalloonClick write FOnBalloonClick;
  end;

  TUniTrayIcon = TDeepBaseTrayIcon;

  TVclPopupMenuAdapter = class(TInterfacedObject, IPopupMenuAdapter)
  private
    FPopupMenu: TPopupMenu;
  public
    constructor Create(APopupMenu: TPopupMenu);
    procedure Popup(X, Y: Integer);
  end;

implementation

function MethodEquals(const A, B: TMethod): Boolean;
begin
  Result := (A.Code = B.Code) and (A.Data = B.Data);
end;

{ TVclPopupMenuAdapter }

constructor TVclPopupMenuAdapter.Create(APopupMenu: TPopupMenu);
begin
  inherited Create;
  FPopupMenu := APopupMenu;
end;

procedure TVclPopupMenuAdapter.Popup(X, Y: Integer);
begin
  if Assigned(FPopupMenu) then
    FPopupMenu.Popup(X, Y);
end;

{ TDeepBaseTrayIcon }

constructor TDeepBaseTrayIcon.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FIcon := TIcon.Create;
  FIcon.OnChange := IconChange;
  FToolTip := Application.Title;
  FMinimizeToTray := True;
  FCloseToTray := True;
  FRestoreOnDoubleClick := True;
  FHooksInstalled := False;
  FAllowClose := False;
  FHostForm := nil;
  FVisible := False;
  if AOwner is TForm then
    SetHostForm(TForm(AOwner));
end;

destructor TDeepBaseTrayIcon.Destroy;
begin
  UninstallHostFormHooks;
  Visible := False;  // UI2-014 fix: TTrayIcon.Hide now destroys FIconHandle
  if Assigned(FPopupMenu) then
    FPopupMenu.RemoveFreeNotification(Self);
  FPopupMenu := nil;
  FHostForm := nil;
  // UI2-014 fix: FIcon.Handle 已因 Hide 中 TTrayIcon.Hide 的 DestroyIcon
  // 而被销毁。把 Handle 置为 0，避免 TIcon.Destroy 再次 ReleaseHandle
  // 导致 Double-Free。
  if Assigned(FIcon) then
    FIcon.Handle := 0;
  FIcon.Free;
  inherited;
end;

procedure TDeepBaseTrayIcon.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FPopupMenu) then
  begin
    FPopupMenu := nil;
    if FVisible then
      UpdateTrayMenuAdapter;
  end;
  if (Operation = opRemove) and (AComponent = FHostForm) then
  begin
    UninstallHostFormHooks;
    FHostForm := nil;
  end;
end;

procedure TDeepBaseTrayIcon.SetToolTip(const Value: string);
begin
  if FToolTip <> Value then
  begin
    FToolTip := Value;
    if FVisible then
      TTrayIcon.UpdateToolTip(FToolTip);
  end;
end;

procedure TDeepBaseTrayIcon.SetIcon(const Value: TIcon);
begin
  if Assigned(Value) then
    FIcon.Assign(Value)
  else
  begin
    // UI2-014 fix: explicitly drop the icon handle so that, even when the
    // tray icon is not currently visible (and therefore IconChange will
    // not propagate the change), the old HICON is not leaked via the
    // TIcon.Handle setter's ReleaseHandle path.
    FIcon.Handle := 0;
  end;
end;

procedure TDeepBaseTrayIcon.SetPopupMenu(const Value: TPopupMenu);
begin
  if FPopupMenu = Value then
    Exit;

  if Assigned(FPopupMenu) then
    FPopupMenu.RemoveFreeNotification(Self);

  FPopupMenu := Value;
  if Assigned(FPopupMenu) then
    FPopupMenu.FreeNotification(Self);

  if FVisible then
    UpdateTrayMenuAdapter;
end;

procedure TDeepBaseTrayIcon.SetHostForm(const Value: TForm);
begin
  if FHostForm = Value then
    Exit;

  UninstallHostFormHooks;
  FHostForm := Value;
  if Assigned(FHostForm) then
  begin
    FHostForm.FreeNotification(Self);
    InstallHostFormHooks;
  end;
end;

procedure TDeepBaseTrayIcon.SetMinimizeToTray(const Value: Boolean);
begin
  if FMinimizeToTray = Value then
    Exit;
  FMinimizeToTray := Value;
  if Assigned(FHostForm) then
    InstallHostFormHooks;
end;

procedure TDeepBaseTrayIcon.SetCloseToTray(const Value: Boolean);
begin
  if FCloseToTray = Value then
    Exit;
  FCloseToTray := Value;
  if Assigned(FHostForm) then
    InstallHostFormHooks;
end;

procedure TDeepBaseTrayIcon.SetRestoreOnDoubleClick(const Value: Boolean);
begin
  if FRestoreOnDoubleClick = Value then
    Exit;
  FRestoreOnDoubleClick := Value;
  if FVisible then
    UpdateTrayCallbacks;
end;

procedure TDeepBaseTrayIcon.IconChange(Sender: TObject);
begin
  if FVisible and (FIcon.Handle <> 0) then
    TTrayIcon.UpdateIcon(FIcon.Handle);
end;

procedure TDeepBaseTrayIcon.InstallHostFormHooks;
begin
  if FHooksInstalled or not Assigned(FHostForm) then
    Exit;

  FPrevOnCloseQuery := FHostForm.OnCloseQuery;
  FPrevOnResize := FHostForm.OnResize;
  FHostForm.OnCloseQuery := HostFormCloseQuery;
  FHostForm.OnResize := HostFormResize;
  FHooksInstalled := True;
end;

procedure TDeepBaseTrayIcon.UninstallHostFormHooks;
var
  CurrentCloseQuery: TMethod;
  CurrentResize: TMethod;
  SelfCloseQuery: TCloseQueryEvent;
  SelfResize: TNotifyEvent;
begin
  if (not FHooksInstalled) or (FHostForm = nil) then
    Exit;

  SelfCloseQuery := HostFormCloseQuery;
  SelfResize := HostFormResize;

  CurrentCloseQuery := TMethod(FHostForm.OnCloseQuery);
  if MethodEquals(CurrentCloseQuery, TMethod(SelfCloseQuery)) then
    FHostForm.OnCloseQuery := FPrevOnCloseQuery;

  CurrentResize := TMethod(FHostForm.OnResize);
  if MethodEquals(CurrentResize, TMethod(SelfResize)) then
    FHostForm.OnResize := FPrevOnResize;

  FPrevOnCloseQuery := nil;
  FPrevOnResize := nil;
  FHooksInstalled := False;
end;

procedure TDeepBaseTrayIcon.HostFormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  PrevCanClose: Boolean;
begin
  PrevCanClose := CanClose;

  if Assigned(FPrevOnCloseQuery) then
    FPrevOnCloseQuery(Sender, CanClose);

  if not CanClose then
    Exit;

  if FAllowClose then
  begin
    FAllowClose := False;
    Exit;
  end;

  if Application.Terminated then
    Exit;

  if FCloseToTray and FVisible then
  begin
    HideHostFormToTray;
    CanClose := False;
  end
  else
    CanClose := PrevCanClose and CanClose;
end;

procedure TDeepBaseTrayIcon.HostFormResize(Sender: TObject);
begin
  if Assigned(FPrevOnResize) then
    FPrevOnResize(Sender);

  if not Assigned(FHostForm) then
    Exit;

  if not (FVisible and FMinimizeToTray) then
    Exit;

  if FHostForm.WindowState = wsMinimized then
    HideHostFormToTray;
end;

procedure TDeepBaseTrayIcon.RestoreHostForm;
begin
  if not Assigned(FHostForm) then
    Exit;

  if not FHostForm.Visible then
    FHostForm.Show;
  FHostForm.WindowState := wsNormal;
  SetForegroundWindow(FHostForm.Handle);
end;

procedure TDeepBaseTrayIcon.HideHostFormToTray;
begin
  if not Assigned(FHostForm) then
    Exit;
  if FHostForm.Visible then
    FHostForm.Hide;
end;

procedure TDeepBaseTrayIcon.UpdateTrayCallbacks;
begin
  TTrayIcon.OnDoubleClick :=
    procedure
    begin
      if FRestoreOnDoubleClick then
        ToggleHostForm;
      if Assigned(FOnDoubleClick) then
        FOnDoubleClick(Self);
    end;

  TTrayIcon.OnBalloonClick :=
    procedure
    begin
      if Assigned(FOnBalloonClick) then
        FOnBalloonClick(Self);
    end;
end;

procedure TDeepBaseTrayIcon.UpdateTrayMenuAdapter;
begin
  if not FVisible then
    Exit;

  if Assigned(FPopupMenu) then
  begin
    FMenuAdapter := TVclPopupMenuAdapter.Create(FPopupMenu);
    TTrayIcon.SetPopupMenuAdapter(FMenuAdapter as IPopupMenuAdapter);
  end
  else
  begin
    FMenuAdapter := nil;
    TTrayIcon.SetPopupMenuAdapter(nil);
  end;
end;

procedure TDeepBaseTrayIcon.SetVisible(const Value: Boolean);
begin
  if FVisible = Value then
    Exit;

  FVisible := Value;
  if FVisible then
  begin
    InstallHostFormHooks;
    UpdateTrayCallbacks;
    UpdateTrayMenuAdapter;
    TTrayIcon.Show(FToolTip, FIcon.Handle);
  end
  else
  begin
    TTrayIcon.Hide;
    TTrayIcon.SetPopupMenuAdapter(nil);
    TTrayIcon.OnDoubleClick := nil;
    TTrayIcon.OnBalloonClick := nil;
    FMenuAdapter := nil;
  end;
end;

procedure TDeepBaseTrayIcon.ShowBalloon(const ATitle, AText: string;
  AIconType: TBalloonIconType; ATimeoutMs: Integer);
begin
  if FVisible then
    TTrayIcon.ShowBalloon(ATitle, AText, AIconType, ATimeoutMs);
end;

procedure TDeepBaseTrayIcon.HideBalloon;
begin
  if FVisible then
    TTrayIcon.HideBalloon;
end;

procedure TDeepBaseTrayIcon.ShowHostForm;
begin
  RestoreHostForm;
end;

procedure TDeepBaseTrayIcon.HideHostForm;
begin
  HideHostFormToTray;
end;

procedure TDeepBaseTrayIcon.ToggleHostForm;
begin
  if not Assigned(FHostForm) then
    Exit;

  if FHostForm.Visible then
    HideHostFormToTray
  else
    RestoreHostForm;
end;

procedure TDeepBaseTrayIcon.CloseHostForm;
begin
  if not Assigned(FHostForm) then
    Exit;

  FAllowClose := True;
  FHostForm.Close;
end;

end.
