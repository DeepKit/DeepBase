{ ============================================================================
  UniBase.VCL.NotificationBar - 底部通知栏组件
  
  版本: 1.0
  说明: 显示在窗体底部的通知栏，用于后台任务进度显示
  功能:
    - 固定在窗体底部
    - 显示消息和进度
    - 可取消和关闭
    - 支持多种状态（进行中/成功/失败）
  ============================================================================ }

unit UniBase.VCL.NotificationBar;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.Math,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Graphics,
  Vcl.Buttons,
  Vcl.Forms,
  UniBase.Types;

type
  /// <summary>
  /// 通知状态
  /// </summary>
  TNotificationStatus = (nsProgress, nsSuccess, nsError, nsInfo);
  
  /// <summary>
  /// 通知栏组件
  /// </summary>
  TNotificationBar = class(TPanel)
  private
    FMessageLabel: TLabel;
    FProgressBar: TProgressBar;
    FSpinner: TPaintBox;
    FCancelButton: TSpeedButton;
    FCloseButton: TSpeedButton;
    FStatusIcon: TShape;
    FAnimationTimer: TTimer;
    
    FAnimationAngle: Integer;
    FStatus: TNotificationStatus;
    FCanCancel: Boolean;
    FCancelled: Boolean;
    FOnCancel: TNotifyEvent;
    FOnClose: TNotifyEvent;
    FAutoHideDelay: Integer;
    FAutoHideTimer: TTimer;
    
    procedure CreateControls;
    procedure AnimationTimerTick(Sender: TObject);
    procedure AutoHideTimerTick(Sender: TObject);
    procedure CancelButtonClick(Sender: TObject);
    procedure CloseButtonClick(Sender: TObject);
    procedure SpinnerPaint(Sender: TObject);
    procedure DrawSpinner(ACanvas: TCanvas; ARect: TRect);
    
    procedure SetMessage(const Value: string);
    function GetMessage: string;
    procedure SetProgress(Value: Integer);
    function GetProgress: Integer;
    procedure SetStatus(Value: TNotificationStatus);
    procedure SetCanCancel(Value: Boolean);
    procedure UpdateStatusIcon;
    
  protected
    procedure Loaded; override;
    procedure Resize; override;
    procedure SetParent(AParent: TWinControl); override;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>
    /// 显示进度通知
    /// </summary>
    procedure ShowProgress(const AMessage: string; AProgress: Integer = -1);
    
    /// <summary>
    /// 显示成功通知
    /// </summary>
    procedure ShowSuccess(const AMessage: string; AutoHideMs: Integer = 3000);
    
    /// <summary>
    /// 显示错误通知
    /// </summary>
    procedure ShowError(const AMessage: string; AutoHideMs: Integer = 0);
    
    /// <summary>
    /// 显示信息通知
    /// </summary>
    procedure ShowInfo(const AMessage: string; AutoHideMs: Integer = 3000);
    
    /// <summary>
    /// 更新进度
    /// </summary>
    procedure UpdateProgress(AProgress: Integer; const AMessage: string = '');
    
    /// <summary>
    /// 隐藏通知栏
    /// </summary>
    procedure HideNotification;
    
    /// <summary>
    /// 检查是否已取消
    /// </summary>
    function CheckCancelled: Boolean;
    
  published
    /// <summary>
    /// 消息文本
    /// </summary>
    property Message: string read GetMessage write SetMessage;
    
    /// <summary>
    /// 当前进度 (0-100, -1 表示不确定)
    /// </summary>
    property Progress: Integer read GetProgress write SetProgress;
    
    /// <summary>
    /// 当前状态
    /// </summary>
    property Status: TNotificationStatus read FStatus write SetStatus default nsProgress;
    
    /// <summary>
    /// 是否允许取消
    /// </summary>
    property CanCancel: Boolean read FCanCancel write SetCanCancel default True;
    
    /// <summary>
    /// 是否已取消
    /// </summary>
    property Cancelled: Boolean read FCancelled;
    
    /// <summary>
    /// 自动隐藏延迟（毫秒，0 表示不自动隐藏）
    /// </summary>
    property AutoHideDelay: Integer read FAutoHideDelay write FAutoHideDelay default 0;
    
    /// <summary>
    /// 取消事件
    /// </summary>
    property OnCancel: TNotifyEvent read FOnCancel write FOnCancel;
    
    /// <summary>
    /// 关闭事件
    /// </summary>
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
  end;

procedure Register;

implementation

uses
  Winapi.Windows;

procedure Register;
begin
  RegisterComponents('UniBase', [TNotificationBar]);
end;

{ TNotificationBar }

constructor TNotificationBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  // 面板属性
  Height := 40;
  Align := alBottom;
  BevelOuter := bvNone;
  ParentBackground := False;
  Color := $00F0F0F0; // 浅灰色背景
  Visible := False;
  
  FAnimationAngle := 0;
  FStatus := nsProgress;
  FCanCancel := True;
  FCancelled := False;
  FAutoHideDelay := 0;
  
  CreateControls;
end;

destructor TNotificationBar.Destroy;
begin
  if Assigned(FAnimationTimer) then
    FAnimationTimer.Enabled := False;
  if Assigned(FAutoHideTimer) then
    FAutoHideTimer.Enabled := False;
  inherited;
end;

procedure TNotificationBar.CreateControls;
begin
  // 状态图标（用于成功/错误状态）
  FStatusIcon := TShape.Create(Self);
  FStatusIcon.Parent := Self;
  FStatusIcon.SetBounds(10, 10, 20, 20);
  FStatusIcon.Shape := stCircle;
  FStatusIcon.Brush.Color := clGreen;
  FStatusIcon.Pen.Style := psClear;
  FStatusIcon.Visible := False;
  
  // 旋转加载指示器
  FSpinner := TPaintBox.Create(Self);
  FSpinner.Parent := Self;
  FSpinner.SetBounds(10, 8, 24, 24);
  FSpinner.OnPaint := SpinnerPaint;
  
  // 消息标签
  FMessageLabel := TLabel.Create(Self);
  FMessageLabel.Parent := Self;
  FMessageLabel.SetBounds(45, 12, 300, 16);
  FMessageLabel.AutoSize := False;
  FMessageLabel.Caption := '';
  FMessageLabel.Font.Size := 9;
  
  // 进度条
  FProgressBar := TProgressBar.Create(Self);
  FProgressBar.Parent := Self;
  FProgressBar.SetBounds(45, 30, 200, 6);
  FProgressBar.Min := 0;
  FProgressBar.Max := 100;
  FProgressBar.Visible := False;
  
  // 取消按钮
  FCancelButton := TSpeedButton.Create(Self);
  FCancelButton.Parent := Self;
  FCancelButton.Width := 60;
  FCancelButton.Height := 24;
  FCancelButton.Caption := 'Cancel';
  FCancelButton.Flat := True;
  FCancelButton.OnClick := CancelButtonClick;
  
  // 关闭按钮
  FCloseButton := TSpeedButton.Create(Self);
  FCloseButton.Parent := Self;
  FCloseButton.Width := 24;
  FCloseButton.Height := 24;
  FCloseButton.Caption := '×';
  FCloseButton.Flat := True;
  FCloseButton.Font.Size := 12;
  FCloseButton.OnClick := CloseButtonClick;
  
  // 动画计时器
  FAnimationTimer := TTimer.Create(Self);
  FAnimationTimer.Interval := 50;
  FAnimationTimer.OnTimer := AnimationTimerTick;
  FAnimationTimer.Enabled := False;
  
  // 自动隐藏计时器
  FAutoHideTimer := TTimer.Create(Self);
  FAutoHideTimer.Enabled := False;
  FAutoHideTimer.OnTimer := AutoHideTimerTick;
end;

procedure TNotificationBar.Loaded;
begin
  inherited;
  Resize;
end;

procedure TNotificationBar.SetParent(AParent: TWinControl);
begin
  inherited;
  if Assigned(AParent) then
    Resize;
end;

procedure TNotificationBar.Resize;
begin
  inherited;
  
  if Width < 100 then Exit;
  
  // 重新布局控件
  if Assigned(FCloseButton) then
    FCloseButton.SetBounds(Width - 30, 8, 24, 24);
    
  if Assigned(FCancelButton) then
    FCancelButton.SetBounds(Width - 95, 8, 60, 24);
    
  if Assigned(FMessageLabel) then
    FMessageLabel.Width := Width - 160;
  
  if Assigned(FProgressBar) then
    FProgressBar.Width := Width - 160;
end;

procedure TNotificationBar.AnimationTimerTick(Sender: TObject);
begin
  FAnimationAngle := (FAnimationAngle + 20) mod 360;
  if Assigned(FSpinner) and FSpinner.Visible then
    FSpinner.Invalidate;
end;

procedure TNotificationBar.AutoHideTimerTick(Sender: TObject);
begin
  FAutoHideTimer.Enabled := False;
  HideNotification;
end;

procedure TNotificationBar.DrawSpinner(ACanvas: TCanvas; ARect: TRect);
var
  CenterX, CenterY, Radius: Integer;
  I: Integer;
  Angle: Double;
  X, Y: Integer;
  DotRadius: Integer;
  ColorIntensity: Integer;
begin
  CenterX := (ARect.Left + ARect.Right) div 2;
  CenterY := (ARect.Top + ARect.Bottom) div 2;
  Radius := Min(ARect.Width, ARect.Height) div 2 - 4;
  DotRadius := 2;
  
  ACanvas.Pen.Style := psClear;
  
  for I := 0 to 7 do
  begin
    Angle := ((I * 45) + FAnimationAngle) * Pi / 180;
    X := CenterX + Round(Radius * Cos(Angle));
    Y := CenterY + Round(Radius * Sin(Angle));
    
    ColorIntensity := 200 - (I * 22);
    if ColorIntensity < 60 then ColorIntensity := 60;
    
    ACanvas.Brush.Color := RGB(0, Round(122 * ColorIntensity / 200), ColorIntensity);
    ACanvas.Ellipse(X - DotRadius, Y - DotRadius, X + DotRadius, Y + DotRadius);
  end;
end;

procedure TNotificationBar.SpinnerPaint(Sender: TObject);
var
  PaintBox: TPaintBox;
begin
  if Sender is TPaintBox then
  begin
    PaintBox := TPaintBox(Sender);
    PaintBox.Canvas.Brush.Color := Color;
    PaintBox.Canvas.FillRect(PaintBox.ClientRect);
    DrawSpinner(PaintBox.Canvas, PaintBox.ClientRect);
  end;
end;

procedure TNotificationBar.CancelButtonClick(Sender: TObject);
begin
  FCancelled := True;
  if Assigned(FOnCancel) then
    FOnCancel(Self);
end;

procedure TNotificationBar.CloseButtonClick(Sender: TObject);
begin
  HideNotification;
  if Assigned(FOnClose) then
    FOnClose(Self);
end;

procedure TNotificationBar.SetMessage(const Value: string);
begin
  if Assigned(FMessageLabel) then
    FMessageLabel.Caption := Value;
end;

function TNotificationBar.GetMessage: string;
begin
  if Assigned(FMessageLabel) then
    Result := FMessageLabel.Caption
  else
    Result := '';
end;

procedure TNotificationBar.SetProgress(Value: Integer);
begin
  if Assigned(FProgressBar) then
  begin
    if Value < 0 then
    begin
      FProgressBar.Style := pbstMarquee;
      FProgressBar.Visible := True;
    end
    else
    begin
      FProgressBar.Style := pbstNormal;
      FProgressBar.Position := Value;
      FProgressBar.Visible := True;
    end;
  end;
end;

function TNotificationBar.GetProgress: Integer;
begin
  if Assigned(FProgressBar) then
    Result := FProgressBar.Position
  else
    Result := 0;
end;

procedure TNotificationBar.SetStatus(Value: TNotificationStatus);
begin
  FStatus := Value;
  UpdateStatusIcon;
  
  // 根据状态显示/隐藏控件
  case FStatus of
    nsProgress:
      begin
        FSpinner.Visible := True;
        FStatusIcon.Visible := False;
        FCancelButton.Visible := FCanCancel;
        FAnimationTimer.Enabled := True;
      end;
    nsSuccess, nsError, nsInfo:
      begin
        FSpinner.Visible := False;
        FStatusIcon.Visible := True;
        FCancelButton.Visible := False;
        FProgressBar.Visible := False;
        FAnimationTimer.Enabled := False;
      end;
  end;
end;

procedure TNotificationBar.SetCanCancel(Value: Boolean);
begin
  FCanCancel := Value;
  if Assigned(FCancelButton) then
    FCancelButton.Visible := Value and (FStatus = nsProgress);
end;

procedure TNotificationBar.UpdateStatusIcon;
begin
  if not Assigned(FStatusIcon) then Exit;
  
  case FStatus of
    nsSuccess:
      begin
        FStatusIcon.Brush.Color := $0000C853; // 绿色
        Color := $00E8F5E9; // 浅绿背景
      end;
    nsError:
      begin
        FStatusIcon.Brush.Color := $003030FF; // 红色
        Color := $00E0E0FF; // 浅红背景
      end;
    nsInfo:
      begin
        FStatusIcon.Brush.Color := $00F57C00; // 橙色
        Color := $00FFF3E0; // 浅橙背景
      end;
    nsProgress:
      begin
        Color := $00F0F0F0; // 默认灰色
      end;
  end;
  
  // 更新 Spinner 背景色
  if Assigned(FSpinner) then
    FSpinner.Color := Color;
end;

procedure TNotificationBar.ShowProgress(const AMessage: string; AProgress: Integer);
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

procedure TNotificationBar.ShowSuccess(const AMessage: string; AutoHideMs: Integer);
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

procedure TNotificationBar.ShowError(const AMessage: string; AutoHideMs: Integer);
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

procedure TNotificationBar.ShowInfo(const AMessage: string; AutoHideMs: Integer);
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

procedure TNotificationBar.UpdateProgress(AProgress: Integer; const AMessage: string);
begin
  Progress := AProgress;
  if AMessage <> '' then
    Message := AMessage;
end;

procedure TNotificationBar.HideNotification;
begin
  Visible := False;
  FAnimationTimer.Enabled := False;
  FAutoHideTimer.Enabled := False;
  FCancelled := False;
end;

function TNotificationBar.CheckCancelled: Boolean;
begin
  Application.ProcessMessages;
  Result := FCancelled;
end;

end.
