{ ============================================================================
  UniBase.VCL.TrayIcon - VCL Tray Icon Component

  Version: 1.0
  Description: TComponent adapter for UniBase.TrayIcon.TTrayIcon.
               Can be dropped onto any form in the designer.

  Features:
    - Design-time component with published properties
    - PopupMenu integration (TPopupMenu)
    - Balloon notifications
    - Auto-manages tray icon lifecycle with form
  ============================================================================ }

unit UniBase.VCL.TrayIcon;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Graphics,
  Vcl.Menus,
  Vcl.Controls,
  UniBase.TrayIcon;

type
  TUniTrayIcon = class(TComponent)
  private
    FToolTip: string;
    FIcon: TIcon;
    FPopupMenu: TPopupMenu;
    FVisible: Boolean;
    FOnDoubleClick: TNotifyEvent;
    FOnBalloonClick: TNotifyEvent;
    FMenuAdapter: IInterface;
    procedure SetToolTip(const Value: string);
    procedure SetIcon(const Value: TIcon);
    procedure SetVisible(const Value: Boolean);
    procedure IconChange(Sender: TObject);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowBalloon(const ATitle, AText: string;
      AIconType: TBalloonIconType = bitInfo; ATimeoutMs: Integer = 5000);
    procedure HideBalloon;
  published
    property ToolTip: string read FToolTip write SetToolTip;
    property Icon: TIcon read FIcon write SetIcon;
    property PopupMenu: TPopupMenu read FPopupMenu write FPopupMenu;
    property Visible: Boolean read FVisible write SetVisible default False;
    property OnDoubleClick: TNotifyEvent read FOnDoubleClick write FOnDoubleClick;
    property OnBalloonClick: TNotifyEvent read FOnBalloonClick write FOnBalloonClick;
  end;

  TVclPopupMenuAdapter = class(TInterfacedObject, IPopupMenuAdapter)
  private
    FPopupMenu: TPopupMenu;
  public
    constructor Create(APopupMenu: TPopupMenu);
    procedure Popup(X, Y: Integer);
  end;

implementation

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

{ TUniTrayIcon }

constructor TUniTrayIcon.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FIcon := TIcon.Create;
  FIcon.OnChange := IconChange;
  FVisible := False;
end;

destructor TUniTrayIcon.Destroy;
begin
  Visible := False;
  FIcon.Free;
  inherited;
end;

procedure TUniTrayIcon.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FPopupMenu) then
    FPopupMenu := nil;
end;

procedure TUniTrayIcon.SetToolTip(const Value: string);
begin
  if FToolTip <> Value then
  begin
    FToolTip := Value;
    if FVisible then
      TTrayIcon.UpdateToolTip(FToolTip);
  end;
end;

procedure TUniTrayIcon.SetIcon(const Value: TIcon);
begin
  FIcon.Assign(Value);
end;

procedure TUniTrayIcon.IconChange(Sender: TObject);
begin
  if FVisible and (FIcon.Handle <> 0) then
    TTrayIcon.UpdateIcon(FIcon.Handle);
end;

procedure TUniTrayIcon.SetVisible(const Value: Boolean);
begin
  if FVisible = Value then
    Exit;

  FVisible := Value;
  if FVisible then
  begin
    TTrayIcon.OnDoubleClick :=
      procedure
      begin
        if Assigned(FOnDoubleClick) then
          FOnDoubleClick(Self);
      end;
    TTrayIcon.OnBalloonClick :=
      procedure
      begin
        if Assigned(FOnBalloonClick) then
          FOnBalloonClick(Self);
      end;
    if Assigned(FPopupMenu) then
    begin
      FMenuAdapter := TVclPopupMenuAdapter.Create(FPopupMenu);
      TTrayIcon.SetPopupMenuAdapter(FMenuAdapter as IPopupMenuAdapter);
    end;
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

procedure TUniTrayIcon.ShowBalloon(const ATitle, AText: string;
  AIconType: TBalloonIconType; ATimeoutMs: Integer);
begin
  if FVisible then
    TTrayIcon.ShowBalloon(ATitle, AText, AIconType, ATimeoutMs);
end;

procedure TUniTrayIcon.HideBalloon;
begin
  if FVisible then
    TTrayIcon.HideBalloon;
end;

end.
