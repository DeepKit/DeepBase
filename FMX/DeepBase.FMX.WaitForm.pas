{ ============================================================================
  DeepBase.FMX.WaitForm - FMX Wait Dialog
  
  Version: 1.0
  Description: FMX version of wait dialog with spinning animation.
  Features:
    - Modal/Non-modal display
    - Spinning animation (using TFloatAnimation on TArc)
    - Progress bar support
    - Cancellation support
  ============================================================================ }

unit DeepBase.FMX.WaitForm;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  FMX.Types,
  FMX.Forms,
  FMX.Controls,
  FMX.StdCtrls,
  FMX.Layouts,
  FMX.Objects,
  FMX.Ani,
  FMX.Graphics,
  DeepBase.Types;

type
  /// <summary>
  /// Wait form cancel event
  /// </summary>
  TFMXWaitCancelEvent = procedure(Sender: TObject; var Cancel: Boolean) of object;
  
  /// <summary>
  /// FMX Wait Form
  /// </summary>
  TFMXWaitForm = class(TForm)
  private
    FMessageLabel: TLabel;
    FProgressBar: TProgressBar;
    FSpinnerArc: TArc;
    FSpinnerAnimation: TFloatAnimation;
    FCancelButton: TButton;
    FLayoutMain: TLayout;
    
    FCanCancel: Boolean;
    FCancelled: Boolean;
    FShowProgress: Boolean;
    FOnCancel: TFMXWaitCancelEvent;
    
    procedure CreateControls;
    procedure CancelButtonClick(Sender: TObject);
    
    procedure SetMessage(const Value: string);
    function GetMessage: string;
    procedure SetProgress(Value: Integer);
    function GetProgress: Integer;
    procedure SetShowProgress(Value: Boolean);
    procedure SetCanCancel(Value: Boolean);
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>
    /// Show wait form (class method)
    /// </summary>
    class function ShowWait(const AMessage: string; ACanCancel: Boolean = False): TFMXWaitForm;
    
    /// <summary>
    /// Close wait form (class method)
    /// </summary>
    class procedure CloseWait(var AWaitForm: TFMXWaitForm);
    
    /// <summary>
    /// Update message
    /// </summary>
    procedure UpdateMessage(const AMessage: string);
    
    /// <summary>
    /// Update progress
    /// </summary>
    procedure UpdateProgress(ACurrent, ATotal: Integer; const AStatus: string = '');
    
    /// <summary>
    /// Check if cancelled
    /// </summary>
    function CheckCancelled: Boolean;
    
    /// <summary>
    /// Process messages (keep UI responsive)
    /// </summary>
    procedure ProcessMessages;
    
    /// <summary>Message text</summary>
    property Message: string read GetMessage write SetMessage;
    
    /// <summary>Progress (0-100)</summary>
    property Progress: Integer read GetProgress write SetProgress;
    
    /// <summary>Show progress bar</summary>
    property ShowProgress: Boolean read FShowProgress write SetShowProgress;
    
    /// <summary>Allow cancellation</summary>
    property CanCancel: Boolean read FCanCancel write SetCanCancel;
    
    /// <summary>Cancelled flag</summary>
    property Cancelled: Boolean read FCancelled;
    
    /// <summary>Cancel event</summary>
    property OnCancel: TFMXWaitCancelEvent read FOnCancel write FOnCancel;
  end;

/// <summary>
/// Global helper functions
/// </summary>
function ShowFMXWaitForm(const AMessage: string; ACanCancel: Boolean = False): TFMXWaitForm;
procedure CloseFMXWaitForm(var AWaitForm: TFMXWaitForm);
procedure UpdateFMXWaitForm(AWaitForm: TFMXWaitForm; const AMessage: string); overload;
procedure UpdateFMXWaitForm(AWaitForm: TFMXWaitForm; ACurrent, ATotal: Integer; const AStatus: string = ''); overload;

implementation

{ Helper functions }

function ShowFMXWaitForm(const AMessage: string; ACanCancel: Boolean): TFMXWaitForm;
begin
  Result := TFMXWaitForm.ShowWait(AMessage, ACanCancel);
end;

procedure CloseFMXWaitForm(var AWaitForm: TFMXWaitForm);
begin
  TFMXWaitForm.CloseWait(AWaitForm);
end;

procedure UpdateFMXWaitForm(AWaitForm: TFMXWaitForm; const AMessage: string);
begin
  if Assigned(AWaitForm) then
    AWaitForm.UpdateMessage(AMessage);
end;

procedure UpdateFMXWaitForm(AWaitForm: TFMXWaitForm; ACurrent, ATotal: Integer; const AStatus: string);
begin
  if Assigned(AWaitForm) then
    AWaitForm.UpdateProgress(ACurrent, ATotal, AStatus);
end;

{ TFMXWaitForm }

constructor TFMXWaitForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  // Form properties
  BorderStyle := TFmxFormBorderStyle.None;
  Position := TFormPosition.ScreenCenter;
  Caption := '';
  ClientWidth := 350;
  ClientHeight := 120;
  FormStyle := TFormStyle.StayOnTop;
  Transparency := False;
  Fill.Color := TAlphaColorRec.White;
  Fill.Kind := TBrushKind.Solid;
  
  FCanCancel := False;
  FCancelled := False;
  FShowProgress := False;
  
  CreateControls;
end;

destructor TFMXWaitForm.Destroy;
begin
  if Assigned(FSpinnerAnimation) then
    FSpinnerAnimation.Stop;
  inherited;
end;

procedure TFMXWaitForm.CreateControls;
begin
  // Main layout
  FLayoutMain := TLayout.Create(Self);
  FLayoutMain.Parent := Self;
  FLayoutMain.Align := TAlignLayout.Client;
  FLayoutMain.Padding.Rect := RectF(20, 20, 20, 20);
  
  // Spinner arc
  FSpinnerArc := TArc.Create(Self);
  FSpinnerArc.Parent := FLayoutMain;
  FSpinnerArc.Position.X := 0;
  FSpinnerArc.Position.Y := 0;
  FSpinnerArc.Width := 48;
  FSpinnerArc.Height := 48;
  FSpinnerArc.StartAngle := 0;
  FSpinnerArc.EndAngle := 270;
  FSpinnerArc.Stroke.Color := TAlphaColorRec.Dodgerblue;
  FSpinnerArc.Stroke.Thickness := 4;
  FSpinnerArc.Fill.Kind := TBrushKind.None;
  
  // Spinner animation
  FSpinnerAnimation := TFloatAnimation.Create(Self);
  FSpinnerAnimation.Parent := FSpinnerArc;
  FSpinnerAnimation.PropertyName := 'RotationAngle';
  FSpinnerAnimation.StartValue := 0;
  FSpinnerAnimation.StopValue := 360;
  FSpinnerAnimation.Duration := 1;
  FSpinnerAnimation.Loop := True;
  FSpinnerAnimation.Start;
  
  // Message label
  FMessageLabel := TLabel.Create(Self);
  FMessageLabel.Parent := FLayoutMain;
  FMessageLabel.Position.X := 60;
  FMessageLabel.Position.Y := 10;
  FMessageLabel.Width := 260;
  FMessageLabel.Height := 40;
  FMessageLabel.WordWrap := True;
  FMessageLabel.Text := 'Please wait...';
  FMessageLabel.StyledSettings := FMessageLabel.StyledSettings - [TStyledSetting.Size];
  FMessageLabel.TextSettings.Font.Size := 14;
  FMessageLabel.TextSettings.VertAlign := TTextAlign.Center;
  
  // Progress bar
  FProgressBar := TProgressBar.Create(Self);
  FProgressBar.Parent := FLayoutMain;
  FProgressBar.Position.X := 0;
  FProgressBar.Position.Y := 60;
  FProgressBar.Width := 310;
  FProgressBar.Height := 20;
  FProgressBar.Visible := False;
  FProgressBar.Min := 0;
  FProgressBar.Max := 100;
  
  // Cancel button
  FCancelButton := TButton.Create(Self);
  FCancelButton.Parent := FLayoutMain;
  FCancelButton.Position.X := 105;
  FCancelButton.Position.Y := 90;
  FCancelButton.Width := 100;
  FCancelButton.Height := 32;
  FCancelButton.Text := 'Cancel';
  FCancelButton.Visible := False;
  FCancelButton.OnClick := CancelButtonClick;
end;

procedure TFMXWaitForm.CancelButtonClick(Sender: TObject);
var
  DoCancel: Boolean;
begin
  DoCancel := True;
  
  if Assigned(FOnCancel) then
    FOnCancel(Self, DoCancel);
    
  if DoCancel then
    FCancelled := True;
end;

procedure TFMXWaitForm.SetMessage(const Value: string);
begin
  if Assigned(FMessageLabel) then
  begin
    FMessageLabel.Text := Value;
    ProcessMessages;
  end;
end;

function TFMXWaitForm.GetMessage: string;
begin
  if Assigned(FMessageLabel) then
    Result := FMessageLabel.Text
  else
    Result := '';
end;

procedure TFMXWaitForm.SetProgress(Value: Integer);
begin
  if Assigned(FProgressBar) then
  begin
    FProgressBar.Value := Value;
    ProcessMessages;
  end;
end;

function TFMXWaitForm.GetProgress: Integer;
begin
  if Assigned(FProgressBar) then
    Result := Round(FProgressBar.Value)
  else
    Result := 0;
end;

procedure TFMXWaitForm.SetShowProgress(Value: Boolean);
begin
  FShowProgress := Value;
  if Assigned(FProgressBar) then
  begin
    FProgressBar.Visible := Value;
    
    // Adjust form height
    if Value then
    begin
      if FCanCancel then
        ClientHeight := 170
      else
        ClientHeight := 120;
    end
    else
    begin
      if FCanCancel then
        ClientHeight := 150
      else
        ClientHeight := 100;
    end;
  end;
end;

procedure TFMXWaitForm.SetCanCancel(Value: Boolean);
begin
  FCanCancel := Value;
  if Assigned(FCancelButton) then
  begin
    FCancelButton.Visible := Value;
    
    // Adjust form height
    if Value then
    begin
      if FShowProgress then
        ClientHeight := 170
      else
        ClientHeight := 150;
      FCancelButton.Position.Y := ClientHeight - 60;
    end
    else
    begin
      if FShowProgress then
        ClientHeight := 120
      else
        ClientHeight := 100;
    end;
  end;
end;

class function TFMXWaitForm.ShowWait(const AMessage: string; ACanCancel: Boolean): TFMXWaitForm;
begin
  Result := TFMXWaitForm.Create(Application);
  Result.Message := AMessage;
  Result.CanCancel := ACanCancel;
  Result.Show;
  Result.ProcessMessages;
end;

class procedure TFMXWaitForm.CloseWait(var AWaitForm: TFMXWaitForm);
var
  LForm: TFMXWaitForm;
begin
  if Assigned(AWaitForm) then
  begin
    // UI2-015 fix: capture the reference and nil the var-param before
    // Close, then defer the actual Free to the next message-loop tick so
    // any OnClose handler can still safely reference AWaitForm.
    LForm := AWaitForm;
    AWaitForm := nil;
    LForm.Close;
    TThread.ForceQueue(nil,
      procedure
      begin
        LForm.Free;
      end);
  end;
end;

procedure TFMXWaitForm.UpdateMessage(const AMessage: string);
begin
  Message := AMessage;
end;

procedure TFMXWaitForm.UpdateProgress(ACurrent, ATotal: Integer; const AStatus: string);
var
  Percent: Integer;
begin
  if ATotal > 0 then
    Percent := (ACurrent * 100) div ATotal
  else
    Percent := 0;
    
  if not FShowProgress then
    ShowProgress := True;
    
  Progress := Percent;
  
  if AStatus <> '' then
    Message := AStatus
  else
    Message := Format('Processing... %d%%', [Percent]);
end;

function TFMXWaitForm.CheckCancelled: Boolean;
begin
  ProcessMessages;
  Result := FCancelled;
end;

procedure TFMXWaitForm.ProcessMessages;
begin
  Application.ProcessMessages;
end;

end.
