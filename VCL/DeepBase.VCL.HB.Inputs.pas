{ ============================================================================
  DeepBase.VCL.HB.Inputs - Modern Token-Driven Input Controls for VCL

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Complete HB Input Controls Suite:
               - THbEdit (Vector single-line text input with placeholder & clear button)
               - THbComboBox (Vector dropdown selector with custom styling & chevron)
               - THbCheckBox (Vector checkbox with rounded corners & smooth checkmark)
               - THbToggleSwitch (Pill capsule switch for inline activation & task status)
               - THbThemeSelector (Theme switcher combo bound to THbTheme.ApplyTheme)
  ============================================================================ }

unit DeepBase.VCL.HB.Inputs;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Math,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.StdCtrls,
  Vcl.Forms,
  Vcl.Menus,
  DeepBase.HB.Core,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Controls;

type
  { --------------------------------------------------------------------------
    THbCheckBox - Modern Vector CheckBox
    -------------------------------------------------------------------------- }
  THbCheckBox = class(THbCustomControl)
  private
    FChecked: Boolean;
    FCaption: string;
    FOnChange: TNotifyEvent;
    procedure SetChecked(Value: Boolean);
    procedure SetCaption(const Value: string);
    function GetBoxRect: TGPRectF;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Toggle;
  published
    property Align;
    property Anchors;
    property Checked: Boolean read FChecked write SetChecked default False;
    property Caption: string read FCaption write SetCaption;
    property Enabled;
    property TabStop default True;
    property Visible;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnClick;
    property OnEnter;
    property OnExit;
  end;

  { --------------------------------------------------------------------------
    THbToggleSwitch - Inline Pill Switch for Instant Activation
    -------------------------------------------------------------------------- }
  THbToggleSwitch = class(THbCustomControl)
  private
    FChecked: Boolean;
    FShowText: Boolean;
    FOnText: string;
    FOffText: string;
    FOnChange: TNotifyEvent;
    procedure SetChecked(Value: Boolean);
    procedure SetShowText(Value: Boolean);
    procedure SetOnText(const Value: string);
    procedure SetOffText(const Value: string);
    function GetPillRect: TGPRectF;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Toggle;
  published
    property Align;
    property Anchors;
    property Checked: Boolean read FChecked write SetChecked default False;
    property ShowText: Boolean read FShowText write SetShowText default True;
    property OnText: string read FOnText write SetOnText;
    property OffText: string read FOffText write SetOffText;
    property Enabled;
    property TabStop default True;
    property Visible;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnClick;
    property OnEnter;
    property OnExit;
  end;

  { --------------------------------------------------------------------------
    THbEdit - Modern Vector Single-Line Text Input
    -------------------------------------------------------------------------- }
  THbEdit = class(THbCustomControl)
  private
    FInnerEdit: TEdit;
    FPlaceholderText: string;
    FClearButton: Boolean;
    FReadOnly: Boolean;
    FPasswordChar: Char;
    FOnChange: TNotifyEvent;

    function GetText: string;
    procedure SetText(const Value: string);
    procedure SetPlaceholderText(const Value: string);
    procedure SetClearButton(Value: Boolean);
    procedure SetReadOnly(Value: Boolean);
    procedure SetPasswordChar(Value: Char);

    procedure OnInnerEditChange(Sender: TObject);
    procedure OnInnerEditEnter(Sender: TObject);
    procedure OnInnerEditExit(Sender: TObject);
    procedure OnInnerEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure UpdateInnerEditBounds;
    function GetClearButtonRect: TGPRectF;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Clear;
    procedure SelectAll;
    property InnerEdit: TEdit read FInnerEdit;
  published
    property Align;
    property Anchors;
    property Text: string read GetText write SetText;
    property PlaceholderText: string read FPlaceholderText write SetPlaceholderText;
    property ClearButton: Boolean read FClearButton write SetClearButton default False;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
    property PasswordChar: Char read FPasswordChar write SetPasswordChar default #0;
    property Enabled;
    property TabStop default True;
    property Visible;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
  end;

  { --------------------------------------------------------------------------
    THbComboBox - Modern Vector Dropdown Selector
    -------------------------------------------------------------------------- }
  THbComboBox = class(THbCustomControl)
  private
    FItems: TStringList;
    FItemIndex: Integer;
    FPlaceholderText: string;
    FOnChange: TNotifyEvent;
    FPopupMenu: TPopupMenu;

    procedure SetItemIndex(Value: Integer);
    procedure SetItems(Value: TStringList);
    procedure SetPlaceholderText(const Value: string);
    function GetText: string;
    procedure SetText(const Value: string);
    procedure OnMenuItemClick(Sender: TObject);
    procedure PopupDropdown;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddItem(const AItem: string);
    procedure Clear;
  published
    property Align;
    property Anchors;
    property Items: TStringList read FItems write SetItems;
    property ItemIndex: Integer read FItemIndex write SetItemIndex default -1;
    property Text: string read GetText write SetText;
    property PlaceholderText: string read FPlaceholderText write SetPlaceholderText;
    property Enabled;
    property TabStop default True;
    property Visible;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnClick;
    property OnEnter;
    property OnExit;
  end;

  { --------------------------------------------------------------------------
    THbThemeSelector - Universal Theme Switcher Dropdown
    -------------------------------------------------------------------------- }
  THbThemeSelector = class(THbCustomControl)
  private
    FThemeIds: TStringList;
    FThemeNames: TStringList;
    FSelectedIndex: Integer;
    FPopupMenu: TPopupMenu;
    FAutoBroadcast: Boolean;
    FOnChange: TNotifyEvent;

    procedure RefreshThemes;
    procedure OnMenuItemClick(Sender: TObject);
    procedure PopupDropdown;
    function GetSelectedThemeId: string;
    procedure SetSelectedThemeId(const AThemeId: string);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ReloadThemes;
    property SelectedThemeId: string read GetSelectedThemeId write SetSelectedThemeId;
  published
    property Align;
    property Anchors;
    property AutoBroadcast: Boolean read FAutoBroadcast write FAutoBroadcast default True;
    property Enabled;
    property TabStop default True;
    property Visible;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnClick;
    property OnEnter;
    property OnExit;
  end;

implementation

{ THbCheckBox }

constructor THbCheckBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csAcceptsControls] + [csOpaque];
  FChecked := False;
  FCaption := 'HbCheckBox';
  Width := ScalePixels(120);
  Height := ScalePixels(24);
  TabStop := True;
  DoubleBuffered := True;
end;

procedure THbCheckBox.SetChecked(Value: Boolean);
begin
  if FChecked <> Value then
  begin
    FChecked := Value;
    Invalidate;
    if Assigned(FOnChange) then
      FOnChange(Self);
  end;
end;

procedure THbCheckBox.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Invalidate;
  end;
end;

procedure THbCheckBox.Toggle;
begin
  Checked := not Checked;
end;

function THbCheckBox.GetBoxRect: TGPRectF;
var
  BoxSz: Single;
begin
  BoxSz := ScaleDIP(16.0);
  Result := MakeRect(ScaleDIP(2.0), (Height - BoxSz) * 0.5, BoxSz, BoxSz);
end;

procedure THbCheckBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and Enabled then
  begin
    if CanFocus then SetFocus;
    Toggle;
  end;
end;

procedure THbCheckBox.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  if Enabled and ((Key = VK_SPACE) or (Key = VK_RETURN)) then
  begin
    Toggle;
    Key := 0;
  end;
end;

procedure THbCheckBox.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  BoxRect, TextRect: TGPRectF;
  Path: TGPGraphicsPath;
  Brush: TGPSolidBrush;
  Pen: TGPPen;
  FontFamily: TGPFontFamily;
  Font: TGPFont;
  StrFmt: TGPStringFormat;
  BoxSz: Single;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    EraseBackground(Graphics);

    BoxRect := GetBoxRect;
    BoxSz := BoxRect.Width;
    Path := CreateRoundRectPath(BoxRect, ScaleDIP(Tokens.RadiusS));
    try
      if FChecked then
      begin
        // Checked: Primary background
        if not Enabled then
          Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted))
        else
          Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
        try
          Graphics.FillPath(Brush, Path);
        finally
          Brush.Free;
        end;

        // Checkmark vector
        Pen := TGPPen.Create(ColorToARGB(Tokens.OnPrimary), 1.8);
        try
          Graphics.DrawLine(Pen, BoxRect.X + BoxSz * 0.22, BoxRect.Y + BoxSz * 0.52,
                                 BoxRect.X + BoxSz * 0.44, BoxRect.Y + BoxSz * 0.74);
          Graphics.DrawLine(Pen, BoxRect.X + BoxSz * 0.44, BoxRect.Y + BoxSz * 0.74,
                                 BoxRect.X + BoxSz * 0.78, BoxRect.Y + BoxSz * 0.28);
        finally
          Pen.Free;
        end;
      end
      else
      begin
        // Unchecked: SurfaceAlt background + Border
        if CurrentState = csHover then
          Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt))
        else
          Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Surface));
        try
          Graphics.FillPath(Brush, Path);
        finally
          Brush.Free;
        end;

        if CurrentState = csHover then
          Pen := TGPPen.Create(ColorToARGB(Tokens.Primary), 1.2)
        else
          Pen := TGPPen.Create(ColorToARGB(Tokens.Border), 1.0);
        try
          Graphics.DrawPath(Pen, Path);
        finally
          Pen.Free;
        end;
      end;

      if Focused then
        DrawFocusRing(Graphics, BoxRect, ScaleDIP(Tokens.RadiusS));
    finally
      Path.Free;
    end;

    // Text Label
    if FCaption <> '' then
    begin
      FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
      try
        Font := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeM), FontStyleRegular, UnitPixel);
        try
          if not Enabled then
            Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted))
          else
            Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
          try
            StrFmt := TGPStringFormat.Create;
            try
              StrFmt.SetAlignment(StringAlignmentNear);
              StrFmt.SetLineAlignment(StringAlignmentCenter);
              StrFmt.SetFormatFlags(StrFmt.GetFormatFlags or StringFormatFlagsNoWrap);

              TextRect := MakeRect(BoxRect.X + BoxSz + ScaleDIP(Tokens.SpaceS), 0.0,
                                   Width - (BoxRect.X + BoxSz + ScaleDIP(Tokens.SpaceS)), Height);
              Graphics.DrawString(FCaption, Length(FCaption), Font, TextRect, StrFmt, Brush);
            finally
              StrFmt.Free;
            end;
          finally
            Brush.Free;
          end;
        finally
          Font.Free;
        end;
      finally
        FontFamily.Free;
      end;
    end;
  finally
    Graphics.Free;
  end;
end;

{ THbToggleSwitch }

constructor THbToggleSwitch.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csAcceptsControls] + [csOpaque];
  FChecked := False;
  FShowText := True;
  FOnText := 'ON';
  FOffText := 'OFF';
  Width := ScalePixels(80);
  Height := ScalePixels(26);
  TabStop := True;
  DoubleBuffered := True;
end;

procedure THbToggleSwitch.SetChecked(Value: Boolean);
begin
  if FChecked <> Value then
  begin
    FChecked := Value;
    Invalidate;
    if Assigned(FOnChange) then
      FOnChange(Self);
  end;
end;

procedure THbToggleSwitch.SetShowText(Value: Boolean);
begin
  if FShowText <> Value then
  begin
    FShowText := Value;
    Invalidate;
  end;
end;

procedure THbToggleSwitch.SetOnText(const Value: string);
begin
  if FOnText <> Value then
  begin
    FOnText := Value;
    Invalidate;
  end;
end;

procedure THbToggleSwitch.SetOffText(const Value: string);
begin
  if FOffText <> Value then
  begin
    FOffText := Value;
    Invalidate;
  end;
end;

procedure THbToggleSwitch.Toggle;
begin
  Checked := not Checked;
end;

function THbToggleSwitch.GetPillRect: TGPRectF;
var
  PillW, PillH: Single;
begin
  PillW := ScaleDIP(38.0);
  PillH := ScaleDIP(20.0);
  Result := MakeRect(ScaleDIP(2.0), (Height - PillH) * 0.5, PillW, PillH);
end;

procedure THbToggleSwitch.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and Enabled then
  begin
    if CanFocus then SetFocus;
    Toggle;
  end;
end;

procedure THbToggleSwitch.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  if Enabled and ((Key = VK_SPACE) or (Key = VK_RETURN)) then
  begin
    Toggle;
    Key := 0;
  end;
end;

procedure THbToggleSwitch.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  PillRect, TextRect: TGPRectF;
  Path: TGPGraphicsPath;
  Brush: TGPSolidBrush;
  Pen: TGPPen;
  KnobDiameter, KnobX, KnobY: Single;
  FontFamily: TGPFontFamily;
  Font: TGPFont;
  StrFmt: TGPStringFormat;
  LabelText: string;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    EraseBackground(Graphics);

    PillRect := GetPillRect;
    Path := CreateRoundRectPath(PillRect, PillRect.Height * 0.5);
    try
      // Track Background
      if FChecked then
      begin
        if not Enabled then
          Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted))
        else if CurrentState = csHover then
          Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary))
        else
          Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
      end
      else
      begin
        if CurrentState = csHover then
          Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt))
        else
          Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Sunken));
      end;
      try
        Graphics.FillPath(Brush, Path);
      finally
        Brush.Free;
      end;

      // Track Border
      if not FChecked then
      begin
        Pen := TGPPen.Create(ColorToARGB(Tokens.Border), 1.0);
        try
          Graphics.DrawPath(Pen, Path);
        finally
          Pen.Free;
        end;
      end;

      if Focused then
        DrawFocusRing(Graphics, PillRect, PillRect.Height * 0.5);
    finally
      Path.Free;
    end;

    // Knob Circle
    KnobDiameter := PillRect.Height - ScaleDIP(4.0);
    KnobY := PillRect.Y + ScaleDIP(2.0);
    if FChecked then
      KnobX := PillRect.X + PillRect.Width - KnobDiameter - ScaleDIP(2.0)
    else
      KnobX := PillRect.X + ScaleDIP(2.0);

    Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Surface));
    try
      Graphics.FillEllipse(Brush, KnobX, KnobY, KnobDiameter, KnobDiameter);
    finally
      Brush.Free;
    end;

    Pen := TGPPen.Create(ColorToARGB(Tokens.Border, 100), 1.0);
    try
      Graphics.DrawEllipse(Pen, KnobX, KnobY, KnobDiameter, KnobDiameter);
    finally
      Pen.Free;
    end;

    // Optional Text (ON / OFF)
    if FShowText then
    begin
      if FChecked then
        LabelText := FOnText
      else
        LabelText := FOffText;

      if LabelText <> '' then
      begin
        FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
        try
          Font := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeS), FontStyleBold, UnitPixel);
          try
            if FChecked then
              Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary))
            else
              Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted));
            try
              StrFmt := TGPStringFormat.Create;
              try
                StrFmt.SetAlignment(StringAlignmentNear);
                StrFmt.SetLineAlignment(StringAlignmentCenter);
                StrFmt.SetFormatFlags(StrFmt.GetFormatFlags or StringFormatFlagsNoWrap);

                TextRect := MakeRect(PillRect.X + PillRect.Width + ScaleDIP(Tokens.SpaceS), 0.0,
                                     Width - (PillRect.X + PillRect.Width + ScaleDIP(Tokens.SpaceS)), Height);
                Graphics.DrawString(LabelText, Length(LabelText), Font, TextRect, StrFmt, Brush);
              finally
                StrFmt.Free;
              end;
            finally
              Brush.Free;
            end;
          finally
            Font.Free;
          end;
        finally
          FontFamily.Free;
        end;
      end;
    end;
  finally
    Graphics.Free;
  end;
end;

{ THbEdit }

constructor THbEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csAcceptsControls] + [csOpaque];
  FPlaceholderText := '';
  FClearButton := False;
  FReadOnly := False;
  FPasswordChar := #0;

  Width := ScalePixels(180);
  Height := ScalePixels(32);
  TabStop := True;
  DoubleBuffered := True;

  FInnerEdit := TEdit.Create(Self);
  FInnerEdit.Parent := Self;
  FInnerEdit.BorderStyle := bsNone;
  FInnerEdit.OnChange := OnInnerEditChange;
  FInnerEdit.OnEnter := OnInnerEditEnter;
  FInnerEdit.OnExit := OnInnerEditExit;
  FInnerEdit.OnKeyDown := OnInnerEditKeyDown;

  UpdateInnerEditBounds;
end;

destructor THbEdit.Destroy;
begin
  inherited;
end;

procedure THbEdit.Resize;
begin
  inherited;
  UpdateInnerEditBounds;
end;

procedure THbEdit.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  if Assigned(FInnerEdit) and FInnerEdit.CanFocus then
    if Assigned(FInnerEdit) and FInnerEdit.CanFocus then FInnerEdit.SetFocus;
end;

procedure THbEdit.UpdateInnerEditBounds;
var
  PadL, PadR: Integer;
  Tokens: THbTokens;
begin
  if not Assigned(FInnerEdit) then
    Exit;

  Tokens := GetTokens;
  PadL := ScalePixels(Tokens.SpaceS);
  if FClearButton then
    PadR := ScalePixels(24.0)
  else
    PadR := ScalePixels(Tokens.SpaceS);

  FInnerEdit.SetBounds(PadL, (Height - FInnerEdit.Height) div 2, Max(10, Width - PadL - PadR), FInnerEdit.Height);
  FInnerEdit.Color := AlphaColorToColor(Tokens.Surface);
  FInnerEdit.Font.Name := Tokens.FontFamily;
  FInnerEdit.Font.Size := Round(Tokens.SizeM);
  FInnerEdit.Font.Color := AlphaColorToColor(Tokens.Ink);
  FInnerEdit.ReadOnly := FReadOnly;
  FInnerEdit.PasswordChar := FPasswordChar;
end;

function THbEdit.GetText: string;
begin
  if Assigned(FInnerEdit) then
    Result := FInnerEdit.Text
  else
    Result := '';
end;

procedure THbEdit.SetText(const Value: string);
begin
  if Assigned(FInnerEdit) and (FInnerEdit.Text <> Value) then
  begin
    FInnerEdit.Text := Value;
    Invalidate;
  end;
end;

procedure THbEdit.SetPlaceholderText(const Value: string);
begin
  if FPlaceholderText <> Value then
  begin
    FPlaceholderText := Value;
    Invalidate;
  end;
end;

procedure THbEdit.SetClearButton(Value: Boolean);
begin
  if FClearButton <> Value then
  begin
    FClearButton := Value;
    UpdateInnerEditBounds;
    Invalidate;
  end;
end;

procedure THbEdit.SetReadOnly(Value: Boolean);
begin
  if FReadOnly <> Value then
  begin
    FReadOnly := Value;
    if Assigned(FInnerEdit) then
      FInnerEdit.ReadOnly := FReadOnly;
    Invalidate;
  end;
end;

procedure THbEdit.SetPasswordChar(Value: Char);
begin
  if FPasswordChar <> Value then
  begin
    FPasswordChar := Value;
    if Assigned(FInnerEdit) then
      FInnerEdit.PasswordChar := FPasswordChar;
    Invalidate;
  end;
end;

procedure THbEdit.Clear;
begin
  if Assigned(FInnerEdit) then
    FInnerEdit.Clear;
end;

procedure THbEdit.SelectAll;
begin
  if Assigned(FInnerEdit) then
    FInnerEdit.SelectAll;
end;

procedure THbEdit.OnInnerEditChange(Sender: TObject);
begin
  Invalidate;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure THbEdit.OnInnerEditEnter(Sender: TObject);
begin
  Invalidate;
end;

procedure THbEdit.OnInnerEditExit(Sender: TObject);
begin
  Invalidate;
end;

procedure THbEdit.OnInnerEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  // Forward KeyDown
end;

function THbEdit.GetClearButtonRect: TGPRectF;
var
  BtnSz: Single;
begin
  BtnSz := ScaleDIP(16.0);
  Result := MakeRect(Width - BtnSz - ScaleDIP(6.0), (Height - BtnSz) * 0.5, BtnSz, BtnSz);
end;

procedure THbEdit.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  ClearR: TGPRectF;
begin
  inherited;
  if (Button = mbLeft) and Enabled then
  begin
    if FClearButton and (Text <> '') then
    begin
      ClearR := GetClearButtonRect;
      if (X >= ClearR.X) and (X <= ClearR.X + ClearR.Width) and
         (Y >= ClearR.Y) and (Y <= ClearR.Y + ClearR.Height) then
      begin
        Clear;
        Exit;
      end;
    end;

    if Assigned(FInnerEdit) and FInnerEdit.CanFocus then
      if Assigned(FInnerEdit) and FInnerEdit.CanFocus then FInnerEdit.SetFocus;
  end;
end;

procedure THbEdit.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  FrameRect, ClearR: TGPRectF;
  Path: TGPGraphicsPath;
  Brush: TGPSolidBrush;
  Pen: TGPPen;
  FontFamily: TGPFontFamily;
  Font: TGPFont;
  StrFmt: TGPStringFormat;
  IsInnerFocused: Boolean;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    EraseBackground(Graphics);

    FrameRect := MakeRect(0.5, 0.5, Width - 1.0, Height - 1.0);
    Path := CreateRoundRectPath(FrameRect, ScaleDIP(Tokens.RadiusM));
    try
      // Surface Background
      if not Enabled then
        Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt))
      else
        Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Surface));
      try
        Graphics.FillPath(Brush, Path);
      finally
        Brush.Free;
      end;

      // Border / Focus Ring
      IsInnerFocused := Assigned(FInnerEdit) and FInnerEdit.Focused;
      if IsInnerFocused then
      begin
        Pen := TGPPen.Create(ColorToARGB(Tokens.FocusRing), 1.5);
        try
          Graphics.DrawPath(Pen, Path);
        finally
          Pen.Free;
        end;
      end
      else if CurrentState = csHover then
      begin
        Pen := TGPPen.Create(ColorToARGB(Tokens.Primary), 1.2);
        try
          Graphics.DrawPath(Pen, Path);
        finally
          Pen.Free;
        end;
      end
      else
      begin
        Pen := TGPPen.Create(ColorToARGB(Tokens.Border), 1.0);
        try
          Graphics.DrawPath(Pen, Path);
        finally
          Pen.Free;
        end;
      end;
    finally
      Path.Free;
    end;

    // Placeholder text if empty and not focused
    if (Text = '') and (FPlaceholderText <> '') and not IsInnerFocused then
    begin
      FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
      try
        Font := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeM), FontStyleRegular, UnitPixel);
        try
          Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted));
          try
            StrFmt := TGPStringFormat.Create;
            try
              StrFmt.SetAlignment(StringAlignmentNear);
              StrFmt.SetLineAlignment(StringAlignmentCenter);
              StrFmt.SetFormatFlags(StrFmt.GetFormatFlags or StringFormatFlagsNoWrap);

              Graphics.DrawString(FPlaceholderText, Length(FPlaceholderText), Font,
                                  MakeRect(ScaleDIP(Tokens.SpaceS), 0.0, Width - ScaleDIP(Tokens.SpaceS * 2), Height),
                                  StrFmt, Brush);
            finally
              StrFmt.Free;
            end;
          finally
            Brush.Free;
          end;
        finally
          Font.Free;
        end;
      finally
        FontFamily.Free;
      end;
    end;

    // Clear Button (x)
    if FClearButton and (Text <> '') and Enabled then
    begin
      ClearR := GetClearButtonRect;
      Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt));
      try
        Graphics.FillEllipse(Brush, ClearR);
      finally
        Brush.Free;
      end;

      Pen := TGPPen.Create(ColorToARGB(Tokens.InkMuted), 1.2);
      try
        Graphics.DrawLine(Pen, ClearR.X + ClearR.Width * 0.3, ClearR.Y + ClearR.Height * 0.3,
                               ClearR.X + ClearR.Width * 0.7, ClearR.Y + ClearR.Height * 0.7);
        Graphics.DrawLine(Pen, ClearR.X + ClearR.Width * 0.7, ClearR.Y + ClearR.Height * 0.3,
                               ClearR.X + ClearR.Width * 0.3, ClearR.Y + ClearR.Height * 0.7);
      finally
        Pen.Free;
      end;
    end;
  finally
    Graphics.Free;
  end;
end;

{ THbComboBox }

constructor THbComboBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csAcceptsControls] + [csOpaque];
  FItems := TStringList.Create;
  FItemIndex := -1;
  FPlaceholderText := '请选择...';
  Width := ScalePixels(160);
  Height := ScalePixels(32);
  TabStop := True;
  DoubleBuffered := True;

  FPopupMenu := TPopupMenu.Create(Self);
end;

destructor THbComboBox.Destroy;
begin
  FPopupMenu.Free;
  FItems.Free;
  inherited;
end;

procedure THbComboBox.AddItem(const AItem: string);
begin
  FItems.Add(AItem);
  if FItemIndex = -1 then
    FItemIndex := 0;
  Invalidate;
end;

procedure THbComboBox.Clear;
begin
  FItems.Clear;
  FItemIndex := -1;
  Invalidate;
end;

procedure THbComboBox.SetItems(Value: TStringList);
begin
  FItems.Assign(Value);
  Invalidate;
end;

procedure THbComboBox.SetItemIndex(Value: Integer);
begin
  if (Value >= -1) and (Value < FItems.Count) and (FItemIndex <> Value) then
  begin
    FItemIndex := Value;
    Invalidate;
    if Assigned(FOnChange) then
      FOnChange(Self);
  end;
end;

procedure THbComboBox.SetPlaceholderText(const Value: string);
begin
  if FPlaceholderText <> Value then
  begin
    FPlaceholderText := Value;
    Invalidate;
  end;
end;

function THbComboBox.GetText: string;
begin
  if (FItemIndex >= 0) and (FItemIndex < FItems.Count) then
    Result := FItems[FItemIndex]
  else
    Result := '';
end;

procedure THbComboBox.SetText(const Value: string);
var
  Idx: Integer;
begin
  Idx := FItems.IndexOf(Value);
  if Idx >= 0 then
    SetItemIndex(Idx);
end;

procedure THbComboBox.OnMenuItemClick(Sender: TObject);
var
  MI: TMenuItem;
begin
  if Sender is TMenuItem then
  begin
    MI := TMenuItem(Sender);
    SetItemIndex(MI.Tag);
  end;
end;

procedure THbComboBox.PopupDropdown;
var
  I: Integer;
  MI: TMenuItem;
  Pt: TPoint;
begin
  FPopupMenu.Items.Clear;
  for I := 0 to FItems.Count - 1 do
  begin
    MI := TMenuItem.Create(FPopupMenu);
    MI.Caption := FItems[I];
    MI.Tag := I;
    MI.OnClick := OnMenuItemClick;
    if I = FItemIndex then
      MI.Checked := True;
    FPopupMenu.Items.Add(MI);
  end;

  Pt := ClientToScreen(Point(0, Height));
  FPopupMenu.Popup(Pt.X, Pt.Y);
end;

procedure THbComboBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and Enabled then
  begin
    if CanFocus then SetFocus;
    PopupDropdown;
  end;
end;

procedure THbComboBox.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  if Enabled then
  begin
    if (Key = VK_DOWN) and (Shift = [ssAlt]) then
    begin
      PopupDropdown;
      Key := 0;
    end
    else if Key = VK_DOWN then
    begin
      if FItemIndex < FItems.Count - 1 then
        SetItemIndex(FItemIndex + 1);
      Key := 0;
    end
    else if Key = VK_UP then
    begin
      if FItemIndex > 0 then
        SetItemIndex(FItemIndex - 1);
      Key := 0;
    end;
  end;
end;

procedure THbComboBox.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  FrameRect, TextRect: TGPRectF;
  Path: TGPGraphicsPath;
  Brush: TGPSolidBrush;
  Pen: TGPPen;
  FontFamily: TGPFontFamily;
  Font: TGPFont;
  StrFmt: TGPStringFormat;
  DispText: string;
  ArrX, ArrY: Single;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    EraseBackground(Graphics);

    FrameRect := MakeRect(0.5, 0.5, Width - 1.0, Height - 1.0);
    Path := CreateRoundRectPath(FrameRect, ScaleDIP(Tokens.RadiusM));
    try
      // Background
      if not Enabled then
        Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt))
      else if CurrentState = csHover then
        Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt))
      else
        Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Surface));
      try
        Graphics.FillPath(Brush, Path);
      finally
        Brush.Free;
      end;

      // Border / Focus Ring
      if Focused then
      begin
        Pen := TGPPen.Create(ColorToARGB(Tokens.FocusRing), 1.5);
        try
          Graphics.DrawPath(Pen, Path);
        finally
          Pen.Free;
        end;
      end
      else if CurrentState = csHover then
      begin
        Pen := TGPPen.Create(ColorToARGB(Tokens.Primary), 1.2);
        try
          Graphics.DrawPath(Pen, Path);
        finally
          Pen.Free;
        end;
      end
      else
      begin
        Pen := TGPPen.Create(ColorToARGB(Tokens.Border), 1.0);
        try
          Graphics.DrawPath(Pen, Path);
        finally
          Pen.Free;
        end;
      end;
    finally
      Path.Free;
    end;

    // Display Text
    if (FItemIndex >= 0) and (FItemIndex < FItems.Count) then
      DispText := FItems[FItemIndex]
    else
      DispText := FPlaceholderText;

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      Font := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeM), FontStyleRegular, UnitPixel);
      try
        if (FItemIndex >= 0) and Enabled then
          Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink))
        else
          Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.InkMuted));
        try
          StrFmt := TGPStringFormat.Create;
          try
            StrFmt.SetAlignment(StringAlignmentNear);
            StrFmt.SetLineAlignment(StringAlignmentCenter);
            StrFmt.SetFormatFlags(StrFmt.GetFormatFlags or StringFormatFlagsNoWrap);
            StrFmt.SetTrimming(StringTrimmingEllipsisCharacter);

            TextRect := MakeRect(ScaleDIP(Tokens.SpaceS), 0.0, Width - ScaleDIP(32.0), Height);
            Graphics.DrawString(DispText, Length(DispText), Font, TextRect, StrFmt, Brush);
          finally
            StrFmt.Free;
          end;
        finally
          Brush.Free;
        end;
      finally
        Font.Free;
      end;
    finally
      FontFamily.Free;
    end;

    // Chevron Arrow (v)
    ArrX := Width - ScaleDIP(18.0);
    ArrY := Height * 0.5 - ScaleDIP(2.0);
    Pen := TGPPen.Create(ColorToARGB(Tokens.InkMuted), 1.4);
    try
      Graphics.DrawLine(Pen, ArrX, ArrY, ArrX + ScaleDIP(4.0), ArrY + ScaleDIP(4.0));
      Graphics.DrawLine(Pen, ArrX + ScaleDIP(4.0), ArrY + ScaleDIP(4.0), ArrX + ScaleDIP(8.0), ArrY);
    finally
      Pen.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

{ THbThemeSelector }

constructor THbThemeSelector.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csAcceptsControls] + [csOpaque];
  FThemeIds := TStringList.Create;
  FThemeNames := TStringList.Create;
  FSelectedIndex := -1;
  FAutoBroadcast := True;
  Width := ScalePixels(170);
  Height := ScalePixels(32);
  TabStop := True;
  DoubleBuffered := True;

  FPopupMenu := TPopupMenu.Create(Self);
  RefreshThemes;
end;

destructor THbThemeSelector.Destroy;
begin
  FPopupMenu.Free;
  FThemeNames.Free;
  FThemeIds.Free;
  inherited;
end;

procedure THbThemeSelector.Loaded;
begin
  inherited;
  RefreshThemes;
end;

procedure THbThemeSelector.ReloadThemes;
begin
  RefreshThemes;
  Invalidate;
end;

procedure THbThemeSelector.RefreshThemes;
var
  Themes: TArray<THbThemeMetadata>;
  I: Integer;
  CurId: string;
begin
  FThemeIds.Clear;
  FThemeNames.Clear;

  Themes := THbTheme.GetAvailableThemes;
  CurId := THbTheme.CurrentId;
  FSelectedIndex := -1;

  for I := 0 to High(Themes) do
  begin
    FThemeIds.Add(Themes[I].Id);
    FThemeNames.Add(Themes[I].Name);
    if (CurId <> '') and SameText(Themes[I].Id, CurId) then
      FSelectedIndex := I;
  end;

  if (FSelectedIndex = -1) and (FThemeIds.Count > 0) then
    FSelectedIndex := 0;
end;

function THbThemeSelector.GetSelectedThemeId: string;
begin
  if (FSelectedIndex >= 0) and (FSelectedIndex < FThemeIds.Count) then
    Result := FThemeIds[FSelectedIndex]
  else
    Result := THbTheme.CurrentId;
end;

procedure THbThemeSelector.SetSelectedThemeId(const AThemeId: string);
var
  Idx: Integer;
begin
  Idx := FThemeIds.IndexOf(AThemeId);
  if Idx >= 0 then
  begin
    FSelectedIndex := Idx;
    if FAutoBroadcast then
      THbTheme.ApplyTheme(AThemeId);
    Invalidate;
    if Assigned(FOnChange) then
      FOnChange(Self);
  end;
end;

procedure THbThemeSelector.OnMenuItemClick(Sender: TObject);
var
  MI: TMenuItem;
  TargetId: string;
begin
  if Sender is TMenuItem then
  begin
    MI := TMenuItem(Sender);
    if (MI.Tag >= 0) and (MI.Tag < FThemeIds.Count) then
    begin
      FSelectedIndex := MI.Tag;
      TargetId := FThemeIds[FSelectedIndex];
      if FAutoBroadcast then
        THbTheme.ApplyTheme(TargetId);
      Invalidate;
      if Assigned(FOnChange) then
        FOnChange(Self);
    end;
  end;
end;

procedure THbThemeSelector.PopupDropdown;
var
  I: Integer;
  MI: TMenuItem;
  Pt: TPoint;
begin
  RefreshThemes;
  FPopupMenu.Items.Clear;
  for I := 0 to FThemeIds.Count - 1 do
  begin
    MI := TMenuItem.Create(FPopupMenu);
    MI.Caption := FThemeNames[I];
    MI.Tag := I;
    MI.OnClick := OnMenuItemClick;
    if I = FSelectedIndex then
      MI.Checked := True;
    FPopupMenu.Items.Add(MI);
  end;

  Pt := ClientToScreen(Point(0, Height));
  FPopupMenu.Popup(Pt.X, Pt.Y);
end;

procedure THbThemeSelector.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and Enabled then
  begin
    if CanFocus then SetFocus;
    PopupDropdown;
  end;
end;

procedure THbThemeSelector.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  if Enabled then
  begin
    if (Key = VK_DOWN) and (Shift = [ssAlt]) then
    begin
      PopupDropdown;
      Key := 0;
    end
    else if Key = VK_DOWN then
    begin
      if FSelectedIndex < FThemeIds.Count - 1 then
        SetSelectedThemeId(FThemeIds[FSelectedIndex + 1]);
      Key := 0;
    end
    else if Key = VK_UP then
    begin
      if FSelectedIndex > 0 then
        SetSelectedThemeId(FThemeIds[FSelectedIndex - 1]);
      Key := 0;
    end;
  end;
end;

procedure THbThemeSelector.Paint;
var
  Graphics: TGPGraphics;
  Tokens: THbTokens;
  FrameRect, TextRect: TGPRectF;
  Path: TGPGraphicsPath;
  Brush: TGPSolidBrush;
  Pen: TGPPen;
  FontFamily: TGPFontFamily;
  Font: TGPFont;
  StrFmt: TGPStringFormat;
  DispText: string;
  ArrX, ArrY, PaletteDotX, PaletteDotY: Single;
begin
  Tokens := GetTokens;
  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Graphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

    EraseBackground(Graphics);

    FrameRect := MakeRect(0.5, 0.5, Width - 1.0, Height - 1.0);
    Path := CreateRoundRectPath(FrameRect, ScaleDIP(Tokens.RadiusM));
    try
      // Background
      if not Enabled then
        Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt))
      else if CurrentState = csHover then
        Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.SurfaceAlt))
      else
        Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Surface));
      try
        Graphics.FillPath(Brush, Path);
      finally
        Brush.Free;
      end;

      // Border / Focus Ring
      if Focused then
      begin
        Pen := TGPPen.Create(ColorToARGB(Tokens.FocusRing), 1.5);
        try
          Graphics.DrawPath(Pen, Path);
        finally
          Pen.Free;
        end;
      end
      else if CurrentState = csHover then
      begin
        Pen := TGPPen.Create(ColorToARGB(Tokens.Primary), 1.2);
        try
          Graphics.DrawPath(Pen, Path);
        finally
          Pen.Free;
        end;
      end
      else
      begin
        Pen := TGPPen.Create(ColorToARGB(Tokens.Border), 1.0);
        try
          Graphics.DrawPath(Pen, Path);
        finally
          Pen.Free;
        end;
      end;
    finally
      Path.Free;
    end;

    // Theme Color Indicator Swatch Dot
    PaletteDotX := ScaleDIP(10.0);
    PaletteDotY := Height * 0.5;
    Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Primary));
    try
      Graphics.FillEllipse(Brush, PaletteDotX - ScaleDIP(4.0), PaletteDotY - ScaleDIP(4.0), ScaleDIP(8.0), ScaleDIP(8.0));
    finally
      Brush.Free;
    end;

    // Display Theme Name
    if (FSelectedIndex >= 0) and (FSelectedIndex < FThemeNames.Count) then
      DispText := FThemeNames[FSelectedIndex]
    else
      DispText := '主题切换';

    FontFamily := TGPFontFamily.Create(Tokens.FontFamily);
    try
      Font := TGPFont.Create(FontFamily, ScaleDIP(Tokens.SizeM), FontStyleRegular, UnitPixel);
      try
        Brush := TGPSolidBrush.Create(ColorToARGB(Tokens.Ink));
        try
          StrFmt := TGPStringFormat.Create;
          try
            StrFmt.SetAlignment(StringAlignmentNear);
            StrFmt.SetLineAlignment(StringAlignmentCenter);
            StrFmt.SetFormatFlags(StrFmt.GetFormatFlags or StringFormatFlagsNoWrap);
            StrFmt.SetTrimming(StringTrimmingEllipsisCharacter);

            TextRect := MakeRect(ScaleDIP(22.0), 0.0, Width - ScaleDIP(44.0), Height);
            Graphics.DrawString(DispText, Length(DispText), Font, TextRect, StrFmt, Brush);
          finally
            StrFmt.Free;
          end;
        finally
          Brush.Free;
        end;
      finally
        Font.Free;
      end;
    finally
      FontFamily.Free;
    end;

    // Chevron Arrow (v)
    ArrX := Width - ScaleDIP(18.0);
    ArrY := Height * 0.5 - ScaleDIP(2.0);
    Pen := TGPPen.Create(ColorToARGB(Tokens.InkMuted), 1.4);
    try
      Graphics.DrawLine(Pen, ArrX, ArrY, ArrX + ScaleDIP(4.0), ArrY + ScaleDIP(4.0));
      Graphics.DrawLine(Pen, ArrX + ScaleDIP(4.0), ArrY + ScaleDIP(4.0), ArrX + ScaleDIP(8.0), ArrY);
    finally
      Pen.Free;
    end;
  finally
    Graphics.Free;
  end;
end;

end.
