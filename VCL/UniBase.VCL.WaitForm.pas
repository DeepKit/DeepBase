{ ============================================================================
  UniBase.VCL.WaitForm - 等待窗口组件
  
  版本: 1.0
  说明: 显示带动画的等待窗口，支持进度更新和取消操作
  功能:
    - 模态/非模态显示
    - 旋转动画
    - 进度条显示
    - 可取消操作
  ============================================================================ }

unit UniBase.VCL.WaitForm;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.Math,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Graphics,
  Vcl.Buttons,
  UniBase.Types;

type
  /// <summary>
  /// 等待窗口取消事件
  /// </summary>
  TWaitCancelEvent = procedure(Sender: TObject; var Cancel: Boolean) of object;
  
  /// <summary>
  /// 等待窗口类
  /// </summary>
  TWaitForm = class(TForm)
  private
    FMessageLabel: TLabel;
    FProgressBar: TProgressBar;
    FAnimationPanel: TPaintBox;
    FAnimationTimer: TTimer;
    FCancelButton: TButton;
    
    FAnimationAngle: Integer;
    FCanCancel: Boolean;
    FCancelled: Boolean;
    FShowProgress: Boolean;
    FOnCancel: TWaitCancelEvent;
    FOnMinimize: TNotifyEvent;
    
    procedure CreateControls;
    procedure AnimationTimerTick(Sender: TObject);
    procedure CancelButtonClick(Sender: TObject);
    procedure DrawSpinner(ACanvas: TCanvas; ARect: TRect);
    procedure AnimationPanelPaint(Sender: TObject);
    
    procedure SetMessage(const Value: string);
    function GetMessage: string;
    procedure SetProgress(Value: Integer);
    function GetProgress: Integer;
    procedure SetShowProgress(Value: Boolean);
    procedure SetCanCancel(Value: Boolean);
    
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    
  public
    constructor Create(AOwner: TComponent); override;
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
    destructor Destroy; override;
    
    /// <summary>
    /// 显示等待窗口（类方法）
    /// </summary>
    class function ShowWait(const AMessage: string; ACanCancel: Boolean = False): TWaitForm;
    
    /// <summary>
    /// 关闭等待窗口（类方法）
    /// </summary>
    class procedure CloseWait(var AWaitForm: TWaitForm);
    
    /// <summary>
    /// 更新消息
    /// </summary>
    procedure UpdateMessage(const AMessage: string);
    
    /// <summary>
    /// 更新进度
    /// </summary>
    procedure UpdateProgress(ACurrent, ATotal: Integer; const AStatus: string = '');
    
    /// <summary>
    /// 检查是否已取消
    /// </summary>
    function CheckCancelled: Boolean;
    
    /// <summary>
    /// 处理消息（保持界面响应）
    /// </summary>
    procedure ProcessMessages;
    
    /// <summary>
    /// 显示消息文本
    /// </summary>
    property Message: string read GetMessage write SetMessage;
    
    /// <summary>
    /// 当前进度 (0-100)
    /// </summary>
    property Progress: Integer read GetProgress write SetProgress;
    
    /// <summary>
    /// 是否显示进度条
    /// </summary>
    property ShowProgress: Boolean read FShowProgress write SetShowProgress;
    
    /// <summary>
    /// 是否允许取消
    /// </summary>
    property CanCancel: Boolean read FCanCancel write SetCanCancel;
    
    /// <summary>
    /// 是否已取消
    /// </summary>
    property Cancelled: Boolean read FCancelled;
    
    /// <summary>
    /// 取消事件
    /// </summary>
    property OnCancel: TWaitCancelEvent read FOnCancel write FOnCancel;
    
    /// <summary>
    /// 最小化事件
    /// </summary>
    property OnMinimize: TNotifyEvent read FOnMinimize write FOnMinimize;
  end;

/// <summary>
/// 全局等待窗口辅助函数
/// </summary>
function ShowWaitForm(const AMessage: string; ACanCancel: Boolean = False): TWaitForm;
procedure CloseWaitForm(var AWaitForm: TWaitForm);
procedure UpdateWaitForm(AWaitForm: TWaitForm; const AMessage: string); overload;
procedure UpdateWaitForm(AWaitForm: TWaitForm; ACurrent, ATotal: Integer; const AStatus: string = ''); overload;

implementation

uses
  Winapi.Windows;

{ Helper functions }

function ShowWaitForm(const AMessage: string; ACanCancel: Boolean): TWaitForm;
begin
  Result := TWaitForm.ShowWait(AMessage, ACanCancel);
end;

procedure CloseWaitForm(var AWaitForm: TWaitForm);
begin
  TWaitForm.CloseWait(AWaitForm);
end;

procedure UpdateWaitForm(AWaitForm: TWaitForm; const AMessage: string);
begin
  if Assigned(AWaitForm) then
    AWaitForm.UpdateMessage(AMessage);
end;

procedure UpdateWaitForm(AWaitForm: TWaitForm; ACurrent, ATotal: Integer; const AStatus: string);
begin
  if Assigned(AWaitForm) then
    AWaitForm.UpdateProgress(ACurrent, ATotal, AStatus);
end;

{ TWaitForm }

constructor TWaitForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  CreateControls;
end;

constructor TWaitForm.CreateNew(AOwner: TComponent; Dummy: Integer);
begin
  inherited CreateNew(AOwner, Dummy);
  
  // 窗体属性
  BorderStyle := bsDialog;
  Position := poScreenCenter;
  Caption := '';
  Width := 350;
  Height := 120;
  BorderIcons := [];
  FormStyle := fsStayOnTop;
  
  FAnimationAngle := 0;
  FCanCancel := False;
  FCancelled := False;
  FShowProgress := False;
  
  CreateControls;
end;

destructor TWaitForm.Destroy;
begin
  if Assigned(FAnimationTimer) then
  begin
    FAnimationTimer.Enabled := False;
    FreeAndNil(FAnimationTimer);  // 确保释放定时器对象
  end;
  inherited;
end;

procedure TWaitForm.CreateParams(var Params: TCreateParams);
begin
  inherited;
  Params.ExStyle := Params.ExStyle or WS_EX_TOOLWINDOW;
end;

procedure TWaitForm.CreateControls;
begin
  // 动画面板
  FAnimationPanel := TPaintBox.Create(Self);
  FAnimationPanel.Parent := Self;
  FAnimationPanel.SetBounds(20, 20, 48, 48);
  FAnimationPanel.OnPaint := AnimationPanelPaint;
  
  // 消息标签
  FMessageLabel := TLabel.Create(Self);
  FMessageLabel.Parent := Self;
  FMessageLabel.SetBounds(80, 30, 240, 40);
  FMessageLabel.AutoSize := False;
  FMessageLabel.WordWrap := True;
  FMessageLabel.Caption := 'Please wait...';
  FMessageLabel.Font.Size := 10;
  
  // 进度条
  FProgressBar := TProgressBar.Create(Self);
  FProgressBar.Parent := Self;
  FProgressBar.SetBounds(20, 80, 310, 20);
  FProgressBar.Visible := False;
  FProgressBar.Min := 0;
  FProgressBar.Max := 100;
  
  // 取消按钮
  FCancelButton := TButton.Create(Self);
  FCancelButton.Parent := Self;
  FCancelButton.SetBounds(125, 110, 100, 25);
  FCancelButton.Caption := 'Cancel';
  FCancelButton.Visible := False;
  FCancelButton.OnClick := CancelButtonClick;
  
  // 动画计时器
  FAnimationTimer := TTimer.Create(Self);
  FAnimationTimer.Interval := 50; // 20 FPS
  FAnimationTimer.OnTimer := AnimationTimerTick;
  FAnimationTimer.Enabled := True;
end;

procedure TWaitForm.AnimationTimerTick(Sender: TObject);
begin
  FAnimationAngle := (FAnimationAngle + 15) mod 360;
  if Assigned(FAnimationPanel) then
    FAnimationPanel.Invalidate;
end;

procedure TWaitForm.DrawSpinner(ACanvas: TCanvas; ARect: TRect);
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
  Radius := Min(ARect.Width, ARect.Height) div 2 - 8;
  DotRadius := 4;
  
  ACanvas.Pen.Style := psClear;
  
  // 绘制 8 个点，形成旋转动画
  for I := 0 to 7 do
  begin
    Angle := ((I * 45) + FAnimationAngle) * Pi / 180;
    X := CenterX + Round(Radius * Cos(Angle));
    Y := CenterY + Round(Radius * Sin(Angle));
    
    // 渐变颜色强度
    ColorIntensity := 255 - (I * 28);
    if ColorIntensity < 80 then ColorIntensity := 80;
    
    ACanvas.Brush.Color := RGB(0, Round(122 * ColorIntensity / 255), ColorIntensity);
    ACanvas.Ellipse(X - DotRadius, Y - DotRadius, X + DotRadius, Y + DotRadius);
  end;
end;

procedure TWaitForm.AnimationPanelPaint(Sender: TObject);
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

procedure TWaitForm.CancelButtonClick(Sender: TObject);
var
  DoCancel: Boolean;
begin
  DoCancel := True;
  
  if Assigned(FOnCancel) then
    FOnCancel(Self, DoCancel);
    
  if DoCancel then
    FCancelled := True;
end;

procedure TWaitForm.SetMessage(const Value: string);
begin
  if Assigned(FMessageLabel) then
  begin
    FMessageLabel.Caption := Value;
    ProcessMessages;
  end;
end;

function TWaitForm.GetMessage: string;
begin
  if Assigned(FMessageLabel) then
    Result := FMessageLabel.Caption
  else
    Result := '';
end;

procedure TWaitForm.SetProgress(Value: Integer);
begin
  if Assigned(FProgressBar) then
  begin
    FProgressBar.Position := Value;
    ProcessMessages;
  end;
end;

function TWaitForm.GetProgress: Integer;
begin
  if Assigned(FProgressBar) then
    Result := FProgressBar.Position
  else
    Result := 0;
end;

procedure TWaitForm.SetShowProgress(Value: Boolean);
begin
  FShowProgress := Value;
  if Assigned(FProgressBar) then
  begin
    FProgressBar.Visible := Value;
    
    // 调整窗体高度
    if Value then
    begin
      if FCanCancel then
        Height := 170
      else
        Height := 120;
    end
    else
    begin
      if FCanCancel then
        Height := 150
      else
        Height := 100;
    end;
  end;
end;

procedure TWaitForm.SetCanCancel(Value: Boolean);
begin
  FCanCancel := Value;
  if Assigned(FCancelButton) then
  begin
    FCancelButton.Visible := Value;
    
    // 调整窗体高度
    if Value then
    begin
      if FShowProgress then
        Height := 170
      else
        Height := 150;
      FCancelButton.Top := Height - 40;
    end
    else
    begin
      if FShowProgress then
        Height := 120
      else
        Height := 100;
    end;
  end;
end;

class function TWaitForm.ShowWait(const AMessage: string; ACanCancel: Boolean): TWaitForm;
begin
  Result := TWaitForm.CreateNew(Application);
  Result.Message := AMessage;
  Result.CanCancel := ACanCancel;
  Result.Show;
  Result.ProcessMessages;
end;

class procedure TWaitForm.CloseWait(var AWaitForm: TWaitForm);
begin
  if Assigned(AWaitForm) then
  begin
    AWaitForm.Close;
    FreeAndNil(AWaitForm);
  end;
end;

procedure TWaitForm.UpdateMessage(const AMessage: string);
begin
  Message := AMessage;
end;

procedure TWaitForm.UpdateProgress(ACurrent, ATotal: Integer; const AStatus: string);
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

function TWaitForm.CheckCancelled: Boolean;
begin
  ProcessMessages;
  Result := FCancelled;
end;

procedure TWaitForm.ProcessMessages;
begin
  Application.ProcessMessages;
end;

end.
