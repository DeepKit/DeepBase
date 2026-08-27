{ ============================================================================
  DeepBase.VCL.HB.Dock - Modern Docking, Float Island & Multi-Monitor Proportions for VCL

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: THbDockSite, THbDockPanel, THbFloatIsland, and
               THbWindowProportionHelper for multi-monitor native excellence.
  ============================================================================ }

unit DeepBase.VCL.HB.Dock;

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
  Vcl.ExtCtrls,
  DeepBase.HB.Core,
  DeepBase.HB.Dock.Types,
  DeepBase.VCL.HB.Theme;

type
  THbDockPanel = class;

  /// <summary>
  /// THbDockSite: Container supporting dockable panels.
  /// </summary>
  THbDockSite = class(TCustomControl)
  private
    FPanels: TList<THbDockPanel>;
    FActiveGuideZone: THbDockGuideZone;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure DockPanel(APanel: THbDockPanel; APosition: THbDockPosition);
    procedure UndockPanel(APanel: THbDockPanel);

    property Panels: TList<THbDockPanel> read FPanels;
    property ActiveGuideZone: THbDockGuideZone read FActiveGuideZone write FActiveGuideZone;
  published
    property Align;
    property Anchors;
  end;

  /// <summary>
  /// THbDockPanel: Individual dockable/floatable panel.
  /// </summary>
  THbDockPanel = class(TCustomControl)
  private
    FTitle: string;
    FPosition: THbDockPosition;
    FIsFloating: Boolean;
    FFloatForm: TCustomForm;
    procedure SetTitle(const Value: string);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure TearOffToFloat;
    procedure DockBackTo(ASite: THbDockSite; APosition: THbDockPosition);

    property IsFloating: Boolean read FIsFloating;
  published
    property Align;
    property Anchors;
    property Title: string read FTitle write SetTitle;
    property Position: THbDockPosition read FPosition write FPosition default dpCenterTab;
  end;

  /// <summary>
  /// THbWindowProportionHelper: Multi-monitor consistent window sizing helper.
  /// </summary>
  THbWindowProportionHelper = class
  public
    class procedure ApplyProportions(AForm: TCustomForm; const AProp: THbWindowProportion);
    class procedure RescueOffScreenWindow(AForm: TCustomForm);
  end;

implementation

{ THbDockSite }

constructor THbDockSite.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 600;
  Height := 400;
  FPanels := TList<THbDockPanel>.Create;
  FActiveGuideZone := dgzNone;
  DoubleBuffered := True;
end;

destructor THbDockSite.Destroy;
begin
  FPanels.Free;
  inherited;
end;

procedure THbDockSite.DockPanel(APanel: THbDockPanel; APosition: THbDockPosition);
begin
  if not FPanels.Contains(APanel) then
    FPanels.Add(APanel);

  APanel.Parent := Self;
  APanel.Position := APosition;
  case APosition of
    dpLeft:   APanel.Align := alLeft;
    dpRight:  APanel.Align := alRight;
    dpTop:    APanel.Align := alTop;
    dpBottom: APanel.Align := alBottom;
    dpCenterTab: APanel.Align := alClient;
  end;
  Invalidate;
end;

procedure THbDockSite.UndockPanel(APanel: THbDockPanel);
begin
  FPanels.Remove(APanel);
  APanel.Parent := nil;
  Invalidate;
end;

procedure THbDockSite.Paint;
var
  Tokens: THbTokens;
begin
  Tokens := THbTheme.Tokens;
  Canvas.Brush.Color := TColor(Tokens.Surface and $00FFFFFF);
  Canvas.FillRect(ClientRect);
end;

{ THbDockPanel }

constructor THbDockPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 200;
  Height := 200;
  FTitle := 'Dock Panel';
  FPosition := dpCenterTab;
  FIsFloating := False;
  FFloatForm := nil;
  DoubleBuffered := True;
end;

destructor THbDockPanel.Destroy;
begin
  if Assigned(FFloatForm) then
    FFloatForm.Free;
  inherited;
end;

procedure THbDockPanel.SetTitle(const Value: string);
begin
  if FTitle <> Value then
  begin
    FTitle := Value;
    Invalidate;
  end;
end;

procedure THbDockPanel.TearOffToFloat;
begin
  if not FIsFloating then
  begin
    FIsFloating := True;
    if not Assigned(FFloatForm) then
    begin
      FFloatForm := TCustomForm.CreateNew(Application);
      FFloatForm.Caption := FTitle;
      FFloatForm.SetBounds(200, 200, Width, Height);
    end;
    Parent := FFloatForm;
    Align := alClient;
    FFloatForm.Show;
  end;
end;

procedure THbDockPanel.DockBackTo(ASite: THbDockSite; APosition: THbDockPosition);
begin
  if FIsFloating then
  begin
    FIsFloating := False;
    if Assigned(FFloatForm) then
    begin
      FFloatForm.Hide;
      FreeAndNil(FFloatForm);
    end;
  end;
  if Assigned(ASite) then
    ASite.DockPanel(Self, APosition);
end;

procedure THbDockPanel.Paint;
var
  Tokens: THbTokens;
begin
  Tokens := THbTheme.Tokens;
  Canvas.Brush.Color := TColor(Tokens.SurfaceAlt and $00FFFFFF);
  Canvas.FillRect(ClientRect);
  Canvas.Font.Color := TColor(Tokens.Ink and $00FFFFFF);
  Canvas.TextOut(8, 6, FTitle);
end;

{ THbWindowProportionHelper }

class procedure THbWindowProportionHelper.ApplyProportions(AForm: TCustomForm; const AProp: THbWindowProportion);
var
  Mon: TMonitor;
  WorkW, WorkH, TargetW, TargetH: Integer;
begin
  if not Assigned(AForm) then
    Exit;

  Mon := Screen.MonitorFromWindow(AForm.Handle);
  if not Assigned(Mon) then
    Mon := Screen.PrimaryMonitor;

  WorkW := Mon.WorkareaRect.Width;
  WorkH := Mon.WorkareaRect.Height;

  TargetW := Round(WorkW * AProp.WidthRatio);
  TargetH := Round(WorkH * AProp.HeightRatio);

  if AProp.MinWidthPx > 0 then
    TargetW := Max(TargetW, AProp.MinWidthPx);
  if AProp.MinHeightPx > 0 then
    TargetH := Max(TargetH, AProp.MinHeightPx);

  if AProp.LockAspectRatio and (AProp.AspectRatio > 0.01) then
  begin
    if TargetW / TargetH > AProp.AspectRatio then
      TargetW := Round(TargetH * AProp.AspectRatio)
    else
      TargetH := Round(TargetW / AProp.AspectRatio);
  end;

  AForm.SetBounds(
    Mon.WorkareaRect.Left + (WorkW - TargetW) div 2,
    Mon.WorkareaRect.Top + (WorkH - TargetH) div 2,
    TargetW,
    TargetH
  );
end;

class procedure THbWindowProportionHelper.RescueOffScreenWindow(AForm: TCustomForm);
var
  I: Integer;
  IsOnScreen: Boolean;
  CenterPt: TPoint;
  Mon: TMonitor;
begin
  if not Assigned(AForm) then
    Exit;

  CenterPt := Point(AForm.Left + AForm.Width div 2, AForm.Top + AForm.Height div 2);
  IsOnScreen := False;

  for I := 0 to Screen.MonitorCount - 1 do
  begin
    if PtInRect(Screen.Monitors[I].BoundsRect, CenterPt) then
    begin
      IsOnScreen := True;
      Break;
    end;
  end;

  if not IsOnScreen then
  begin
    Mon := Screen.PrimaryMonitor;
    AForm.SetBounds(
      Mon.WorkareaRect.Left + (Mon.WorkareaRect.Width - AForm.Width) div 2,
      Mon.WorkareaRect.Top + (Mon.WorkareaRect.Height - AForm.Height) div 2,
      AForm.Width,
      AForm.Height
    );
  end;
end;

end.
