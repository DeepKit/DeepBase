{ ============================================================================
  DeepBase.FMX.NotificationBar - FMX Cross-platform Notification Bar
  
  Version: 1.0
  Description: Bottom notification bar for showing messages, progress, and status
  Features:
    - Docks to bottom of parent
    - Shows message and optional progress
    - Supports multiple states (Progress/Success/Error/Info)
    - Cancel and close buttons
    - Auto-hide with configurable delay
    - Animated spinner for indeterminate progress
  ============================================================================ }

unit DeepBase.FMX.NotificationBar;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Math,
  FMX.Types,
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Layouts,
  FMX.StdCtrls,
  FMX.Objects,
  FMX.Graphics,
  FMX.Ani,
  FMX.Effects,
  FMX.Forms;

type
  TFMXNotificationStatus = (nsProgress, nsSuccess, nsError, nsInfo);

  TFMXNotificationBar = class(TLayout)
  private
    FBackground: TRectangle;
    FMessageLabel: TLabel;
    FProgressBar: TProgressBar;
    FSpinner: TArc;
    FSpinnerAnimation: TFloatAnimation;
    FStatusIcon: TCircle;
    FCancelButton: TButton;
    FCloseButton: TButton;
    
    FStatus: TFMXNotificationStatus;
    FCanCancel: Boolean;
    FCancelled: Boolean;
    FAutoHideDelay: Integer;
    FAutoHideTimer: TTimer;
    
    FOnCancel: TNotifyEvent;
    FOnClose: TNotifyEvent;
    
    procedure CreateControls;
    procedure AutoHideTimerTick(Sender: TObject);
    procedure CancelButtonClick(Sender: TObject);
    procedure CloseButtonClick(Sender: TObject);
    
    procedure SetMessage(const Value: string);
    function GetMessage: string;
    procedure SetProgress(Value: Single);
    function GetProgress: Single;
    procedure SetStatus(Value: TFMXNotificationStatus);
    procedure SetCanCancel(Value: Boolean);
    procedure UpdateStatusIcon;
    procedure UpdateLayout;
    
  protected
    procedure Resize; override;
    procedure DoRealign; override;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure ShowProgress(const AMessage: string; AProgress: Single = -1);
    procedure ShowSuccess(const AMessage: string; AutoHideMs: Integer = 3000);
    procedure ShowError(const AMessage: string; AutoHideMs: Integer = 0);
    procedure ShowInfo(const AMessage: string; AutoHideMs: Integer = 3000);
    procedure UpdateProgress(AProgress: Single; const AMessage: string = '');
    procedure HideNotification;
    function CheckCancelled: Boolean;
    
    property Message: string read GetMessage write SetMessage;
    property Progress: Single read GetProgress write SetProgress;
    property Status: TFMXNotificationStatus read FStatus write SetStatus default nsProgress;
    property CanCancel: Boolean read FCanCancel write SetCanCancel default True;
    property Cancelled: Boolean read FCancelled;
    property AutoHideDelay: Integer read FAutoHideDelay write FAutoHideDelay default 0;
    property OnCancel: TNotifyEvent read FOnCancel write FOnCancel;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
  end;

implementation

{ TFMXNotificationBar }

constructor TFMXNotificationBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Height := 48;
  Align := TAlignLayout.Bottom;
  Visible := False;
  
  FStatus := nsProgress;
  FCanCancel := True;
  FCancelled := False;
  FAutoHideDelay := 0;
  
  CreateControls;
  
  FAutoHideTimer := TTimer.Create(Self);
  FAutoHideTimer.Enabled := False;
  FAutoHideTimer.OnTimer := AutoHideTimerTick;
end;

destructor TFMXNotificationBar.Destroy;
begin
  if Assigned(FSpinnerAnimation) then
    FSpinnerAnimation.Stop;
  if Assigned(FAutoHideTimer) then
    FAutoHideTimer.Enabled := False;
  inherited;
end;

procedure TFMXNotificationBar.CreateControls;
begin
  FBackground := TRectangle.Create(Self);
  FBackground.Parent := Self;
  FBackground.Align := TAlignLayout.Client;
  FBackground.Fill.Color := TAlphaColorRec.Whitesmoke;
  FBackground.Stroke.Kind := TBrushKind.None;
  FBackground.XRadius := 0;
  FBackground.YRadius := 0;
  FBackground.HitTest := False;
  
  // Spinner (animated arc)
  FSpinner := TArc.Create(Self);
  FSpinner.Parent := Self;
  FSpinner.Width := 24;
  FSpinner.Height := 24;
  FSpinner.Position.X := 12;
  FSpinner.Position.Y := 12;
  FSpinner.StartAngle := 0;
  FSpinner.EndAngle := 270;
  FSpinner.Stroke.Color := TAlphaColorRec.Dodgerblue;
  FSpinner.Stroke.Thickness := 3;
  FSpinner.Fill.Kind := TBrushKind.None;
  
  FSpinnerAnimation := TFloatAnimation.Create(FSpinner);
  FSpinnerAnimation.Parent := FSpinner;
  FSpinnerAnimation.PropertyName := 'RotationAngle';
  FSpinnerAnimation.StartValue := 0;
  FSpinnerAnimation.StopValue := 360;
  FSpinnerAnimation.Duration := 1.0;
  FSpinnerAnimation.Loop := True;
  
  // Status icon (circle)
  FStatusIcon := TCircle.Create(Self);
  FStatusIcon.Parent := Self;
  FStatusIcon.Width := 20;
  FStatusIcon.Height := 20;
  FStatusIcon.Position.X := 14;
  FStatusIcon.Position.Y := 14;
  FStatusIcon.Fill.Color := TAlphaColorRec.Green;
  FStatusIcon.Stroke.Kind := TBrushKind.None;
  FStatusIcon.Visible := False;
  
  // Message label
  FMessageLabel := TLabel.Create(Self);
  FMessageLabel.Parent := Self;
  FMessageLabel.Position.X := 48;
  FMessageLabel.Position.Y := 8;
  FMessageLabel.Width := 300;
  FMessageLabel.Height := 18;
  FMessageLabel.Text := '';
  FMessageLabel.AutoSize := False;
  FMessageLabel.WordWrap := False;
  
  // Progress bar
  FProgressBar := TProgressBar.Create(Self);
  FProgressBar.Parent := Self;
  FProgressBar.Position.X := 48;
  FProgressBar.Position.Y := 30;
  FProgressBar.Width := 200;
  FProgressBar.Height := 8;
  FProgressBar.Min := 0;
  FProgressBar.Max := 100;
  FProgressBar.Visible := False;
  
  // Cancel button
  FCancelButton := TButton.Create(Self);
  FCancelButton.Parent := Self;
  FCancelButton.Width := 70;
  FCancelButton.Height := 28;
  FCancelButton.Text := 'Cancel';
  FCancelButton.OnClick := CancelButtonClick;
  
  // Close button
  FCloseButton := TButton.Create(Self);
  FCloseButton.Parent := Self;
  FCloseButton.Width := 28;
  FCloseButton.Height := 28;
  FCloseButton.Text := '×';
  FCloseButton.OnClick := CloseButtonClick;
  FCloseButton.StyledSettings := FCloseButton.StyledSettings - [TStyledSetting.Size];
  FCloseButton.Font.Size := 16;
end;

procedure TFMXNotificationBar.Resize;
begin
  inherited;
  UpdateLayout;
end;

procedure TFMXNotificationBar.DoRealign;
begin
  inherited;
  UpdateLayout;
end;

procedure TFMXNotificationBar.UpdateLayout;
begin
  if Width < 100 then Exit;
  
  if Assigned(FCloseButton) then
  begin
    FCloseButton.Position.X := Width - 36;
    FCloseButton.Position.Y := 10;
  end;
  
  if Assigned(FCancelButton) then
  begin
    FCancelButton.Position.X := Width - 112;
    FCancelButton.Position.Y := 10;
  end;
  
  if Assigned(FMessageLabel) then
    FMessageLabel.Width := Width - 180;
  
  if Assigned(FProgressBar) then
    FProgressBar.Width := Width - 180;
end;

procedure TFMXNotificationBar.AutoHideTimerTick(Sender: TObject);
begin
  FAutoHideTimer.Enabled := False;
  HideNotification;
end;

procedure TFMXNotificationBar.CancelButtonClick(Sender: TObject);
begin
  FCancelled := True;
  if Assigned(FOnCancel) then
    FOnCancel(Self);
end;

procedure TFMXNotificationBar.CloseButtonClick(Sender: TObject);
begin
  HideNotification;
  if Assigned(FOnClose) then
    FOnClose(Self);
end;

procedure TFMXNotificationBar.SetMessage(const Value: string);
begin
  if Assigned(FMessageLabel) then
    FMessageLabel.Text := Value;
end;

function TFMXNotificationBar.GetMessage: string;
begin
  if Assigned(FMessageLabel) then
    Result := FMessageLabel.Text
  else
    Result := '';
end;

procedure TFMXNotificationBar.SetProgress(Value: Single);
begin
  if Assigned(FProgressBar) then
  begin
    if Value < 0 then
    begin
      FProgressBar.Visible := False;
    end
    else
    begin
      FProgressBar.Value := Value;
      FProgressBar.Visible := True;
    end;
  end;
end;

function TFMXNotificationBar.GetProgress: Single;
begin
  if Assigned(FProgressBar) then
    Result := FProgressBar.Value
  else
    Result := 0;
end;

procedure TFMXNotificationBar.SetStatus(Value: TFMXNotificationStatus);
begin
  FStatus := Value;
  UpdateStatusIcon;
  
  case FStatus of
    nsProgress:
      begin
        FSpinner.Visible := True;
        FStatusIcon.Visible := False;
        FCancelButton.Visible := FCanCancel;
        FSpinnerAnimation.Start;
      end;
    nsSuccess, nsError, nsInfo:
      begin
        FSpinner.Visible := False;
        FStatusIcon.Visible := True;
        FCancelButton.Visible := False;
        FProgressBar.Visible := False;
        FSpinnerAnimation.Stop;
      end;
  end;
end;

procedure TFMXNotificationBar.SetCanCancel(Value: Boolean);
begin
  FCanCancel := Value;
  if Assigned(FCancelButton) then
    FCancelButton.Visible := Value and (FStatus = nsProgress);
end;

procedure TFMXNotificationBar.UpdateStatusIcon;
begin
  if not Assigned(FStatusIcon) or not Assigned(FBackground) then Exit;
  
  case FStatus of
    nsSuccess:
      begin
        FStatusIcon.Fill.Color := TAlphaColorRec.Limegreen;
        FBackground.Fill.Color := $FFE8F5E9;  // Light green
      end;
    nsError:
      begin
        FStatusIcon.Fill.Color := TAlphaColorRec.Red;
        FBackground.Fill.Color := $FFFFEBEE;  // Light red
      end;
    nsInfo:
      begin
        FStatusIcon.Fill.Color := TAlphaColorRec.Orange;
        FBackground.Fill.Color := $FFFFF3E0;  // Light orange
      end;
    nsProgress:
      begin
        FBackground.Fill.Color := TAlphaColorRec.Whitesmoke;
      end;
  end;
end;

procedure TFMXNotificationBar.ShowProgress(const AMessage: string; AProgress: Single);
begin
  FCancelled := False;
  Status := nsProgress;
  Message := AMessage;
  
  if AProgress >= 0 then
    Progress := AProgress
  else
    FProgressBar.Visible := False;
  
  Visible := True;
end;

procedure TFMXNotificationBar.ShowSuccess(const AMessage: string; AutoHideMs: Integer);
begin
  Status := nsSuccess;
  Message := AMessage;
  Visible := True;
  
  if AutoHideMs > 0 then
  begin
    FAutoHideTimer.Interval := AutoHideMs;
    FAutoHideTimer.Enabled := True;
  end;
end;

procedure TFMXNotificationBar.ShowError(const AMessage: string; AutoHideMs: Integer);
begin
  Status := nsError;
  Message := AMessage;
  Visible := True;
  
  if AutoHideMs > 0 then
  begin
    FAutoHideTimer.Interval := AutoHideMs;
    FAutoHideTimer.Enabled := True;
  end;
end;

procedure TFMXNotificationBar.ShowInfo(const AMessage: string; AutoHideMs: Integer);
begin
  Status := nsInfo;
  Message := AMessage;
  Visible := True;
  
  if AutoHideMs > 0 then
  begin
    FAutoHideTimer.Interval := AutoHideMs;
    FAutoHideTimer.Enabled := True;
  end;
end;

procedure TFMXNotificationBar.UpdateProgress(AProgress: Single; const AMessage: string);
begin
  Progress := AProgress;
  if AMessage <> '' then
    Message := AMessage;
end;

procedure TFMXNotificationBar.HideNotification;
begin
  Visible := False;
  if Assigned(FSpinnerAnimation) then
    FSpinnerAnimation.Stop;
  if Assigned(FAutoHideTimer) then
    FAutoHideTimer.Enabled := False;
  FCancelled := False;
end;

function TFMXNotificationBar.CheckCancelled: Boolean;
begin
  Application.ProcessMessages;
  Result := FCancelled;
end;

end.
