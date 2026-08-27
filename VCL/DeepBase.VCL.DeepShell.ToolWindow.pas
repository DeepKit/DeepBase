{ ============================================================================
  DeepBase.VCL.DeepShell.ToolWindow

  Native TForm-based floating tool window. The first version intentionally
  avoids docking frameworks - layout state is just bounds + flags.

  See docs/71.vcl.DeepShell-结构规范.md §3.1
  ============================================================================ }

unit DeepBase.VCL.DeepShell.ToolWindow;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  DeepBase.VCL.DeepShell.Types,
  DeepBase.VCL.DeepShell.Intf;

type
  TDeepShellToolWindow = class(TForm)
  private
    FWindowId: string;
    FUpper: TPanel;
    FLower: TPanel;
    FSplitter: TSplitter;
    FState: TShellToolWindowState;
    FPinned: Boolean;
    FOnVisibleChange: TProc<Boolean>;
    procedure DoFormClose(Sender: TObject; var Action: TCloseAction);
    procedure ApplyPinned(AValue: Boolean);
  public
    constructor CreateForShell(AOwner: TComponent; const AWindowId, ATitle: string);
    procedure SetPinned(AValue: Boolean);
    procedure SetState(const AState: TShellToolWindowState);
    function State: TShellToolWindowState;
    procedure ShowToolWindow;
    procedure HideToolWindow;
    procedure ToggleVisible;
    procedure ConstrainToWorkAreaOf(AReference: TForm);
    property WindowId: string read FWindowId;
    property Upper: TPanel read FUpper;
    property Lower: TPanel read FLower;
    property Pinned: Boolean read FPinned;
    property OnVisibleChange: TProc<Boolean> read FOnVisibleChange write FOnVisibleChange;
  end;

implementation

uses
  Winapi.Windows,
  Winapi.MultiMon;

{ TDeepShellToolWindow }

constructor TDeepShellToolWindow.CreateForShell(AOwner: TComponent;
  const AWindowId, ATitle: string);
const
  DEFAULT_TOOL_WIDTH_96  = 320;
  DEFAULT_TOOL_HEIGHT_96 = 480;
  DEFAULT_LOWER_HEIGHT_96 = 140;
var
  LDPI: Integer;
begin
  inherited CreateNew(AOwner);
  FWindowId := AWindowId;
  Caption := ATitle;

  // Scale default size by current screen DPI so the tool window stays usable
  // on 4K / 200% DPI displays. Falls back to 96 DPI defaults.
  LDPI := if (Screen <> nil) and (Screen.PixelsPerInch > 0)
    then Screen.PixelsPerInch
    else 96;
  Width := MulDiv(DEFAULT_TOOL_WIDTH_96, LDPI, 96);
  Height := MulDiv(DEFAULT_TOOL_HEIGHT_96, LDPI, 96);

  Position := poDesigned;
  BorderStyle := bsSizeToolWin;
  PopupMode := pmExplicit;
  DefaultMonitor := dmDesktop;
  OnClose := DoFormClose;

  FUpper := TPanel.Create(Self);
  FUpper.Parent := Self;
  FUpper.Align := alClient;
  FUpper.BevelOuter := bvNone;

  // VCL alBottom stacks bottom-up by creation order. FLower must be created
  // first so it sits at the bottom; FSplitter is created next so it docks
  // immediately above FLower.
  FLower := TPanel.Create(Self);
  FLower.Parent := Self;
  FLower.Align := alBottom;
  FLower.Height := MulDiv(DEFAULT_LOWER_HEIGHT_96, LDPI, 96);
  FLower.BevelOuter := bvNone;

  FSplitter := TSplitter.Create(Self);
  FSplitter.Parent := Self;
  FSplitter.Align := alBottom;
  FSplitter.Height := 4;
  FSplitter.MinSize := 32;

  FState := TShellToolWindowState.Make(AWindowId);
  FState.Width := Width;
  FState.Height := Height;
end;

procedure TDeepShellToolWindow.DoFormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caHide;
  FState.Visible := False;
  if Assigned(FOnVisibleChange) then
    FOnVisibleChange(False);
end;

procedure TDeepShellToolWindow.ApplyPinned(AValue: Boolean);
begin
  if AValue then
    FormStyle := fsStayOnTop
  else
    FormStyle := fsNormal;
end;

procedure TDeepShellToolWindow.SetPinned(AValue: Boolean);
begin
  if FPinned = AValue then
    Exit;
  FPinned := AValue;
  FState.Pinned := AValue;
  ApplyPinned(AValue);
end;

procedure TDeepShellToolWindow.SetState(const AState: TShellToolWindowState);
begin
  FState := AState;
  if FState.Width <= 0 then FState.Width := 320;
  if FState.Height <= 0 then FState.Height := 480;
  Width := FState.Width;
  Height := FState.Height;
  Left := FState.Left;
  Top := FState.Top;
  ApplyPinned(FState.Pinned);
  FPinned := FState.Pinned;
  if FState.Visible then
    ShowToolWindow
  else
    HideToolWindow;
end;

function TDeepShellToolWindow.State: TShellToolWindowState;
begin
  FState.WindowId := FWindowId;
  FState.Visible := Showing;
  FState.Pinned := FPinned;
  FState.Left := Left;
  FState.Top := Top;
  FState.Width := Width;
  FState.Height := Height;
  Result := FState;
end;

procedure TDeepShellToolWindow.ShowToolWindow;
begin
  if not Visible then
    Show;
  FState.Visible := True;
  if Assigned(FOnVisibleChange) then
    FOnVisibleChange(True);
end;

procedure TDeepShellToolWindow.HideToolWindow;
begin
  if Visible then
    Hide;
  FState.Visible := False;
  if Assigned(FOnVisibleChange) then
    FOnVisibleChange(False);
end;

procedure TDeepShellToolWindow.ToggleVisible;
begin
  if Visible then
    HideToolWindow
  else
    ShowToolWindow;
end;

procedure TDeepShellToolWindow.ConstrainToWorkAreaOf(AReference: TForm);
var
  LMonitor: TMonitor;
  LRect: TRect;
begin
  if AReference <> nil then
    LMonitor := AReference.Monitor
  else
    LMonitor := Screen.PrimaryMonitor;
  if LMonitor = nil then
    Exit;

  LRect := LMonitor.WorkareaRect;

  // Keep at least 32x32 of the title bar inside the work area.
  if Left + 32 < LRect.Left then Left := LRect.Left;
  if Top + 32 < LRect.Top then Top := LRect.Top;
  if Left + Width > LRect.Right then Left := LRect.Right - Width;
  if Top + Height > LRect.Bottom then Top := LRect.Bottom - Height;
  if Left < LRect.Left then Left := LRect.Left;
  if Top < LRect.Top then Top := LRect.Top;
  if Width > (LRect.Right - LRect.Left) then Width := LRect.Right - LRect.Left;
  if Height > (LRect.Bottom - LRect.Top) then Height := LRect.Bottom - LRect.Top;
end;

end.
