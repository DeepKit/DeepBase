{ ============================================================================
  DeepBase.Desktop.Perception.ColorMatch
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : Pixel-level color matching primitives for desktop perception.
                Captures a screen region via GDI (BitBlt) into a 32-bit bitmap
                and finds pixels whose color is within a tolerance of a
                target color. Supports single-point search and multi-point
                combined matching (relative offsets verified against one
                anchor hit). This unit is pure mechanism: it samples pixels
                and compares colors, it never decides what a color means or
                what to click. No business semantics.
                This is the fast path of the three-tier perception fallback
                (UIA -> pixel template/color match -> LLM vision): fixed UI
                state indicators (unread badges, status lights) are detected
                in milliseconds without an LLM call.
  ========================================================================== }

unit DeepBase.Desktop.Perception.ColorMatch;

interface

uses
  System.SysUtils,
  System.Types,
  System.Math,
  Winapi.Windows,
  Vcl.Graphics;

type
  // 32-bit color packed as $00RRGGBB (matches wyjx TColor32 layout so ported
  // algorithms stay bit-identical). Alpha is unused for screen pixels.
  TColor32 = type Cardinal;
  PColor32 = ^TColor32;

  // Result of a color search. Found=True means MatchX/MatchY are valid screen
  // coordinates of a hit. Similarity is 1.0 (exact) .. 0.0 (max divergence),
  // mapped as 1 - (channelDiffSum / (255*3)).
  TColorMatchResult = record
    Found: Boolean;
    MatchX: Integer;
    MatchY: Integer;
    Similarity: Double;
    function Confidence: Double;
  end;

  // A single point in a multi-point color spec. DX/DY are relative offsets
  // from the anchor hit; Tol is the per-channel-sum tolerance.
  TColorPointSpec = record
    DX: Integer;
    DY: Integer;
    Color: TColor32;
    Tol: Integer;
  end;
  TColorPointSpecArray = array of TColorPointSpec;

  // A captured 32-bit pixel buffer used as the search surface. Owns its
  // bitmap; caller must free via TPixelBuffer.Release.
  TPixelBuffer = record
    Bitmap: TBitmap;
    OriginX: Integer; // screen X of pixel (0,0) in this buffer
    OriginY: Integer;
    function Width: Integer;
    function Height: Integer;
    function IsValid: Boolean;
    // Direct read of a pixel color at buffer-local coordinates. Returns
    // $00000000 (black) for out-of-range coordinates (no exception).
    function PixelAt(X, Y: Integer): TColor32;
    procedure Release;
  end;

  TColorMatcher = class
  private
    class function SumChannelDiff(C1, C2: TColor32): Integer; static;
  public
    // Capture a screen region into a 32-bit pixel buffer. An empty rect
    // captures the full virtual screen. OriginX/OriginY record the physical
    // screen offset so hits can be reported in screen coordinates.
    class function CaptureRegion(const ARect: TRect): TPixelBuffer; static;

    // Check whether the pixel at buffer-local (X,Y) is within Tolerance of
    // TargetColor. Out-of-range coordinates return False (no exception).
    class function CheckColorAt(const ABuf: TPixelBuffer; X, Y: Integer;
      TargetColor: TColor32; Tolerance: Integer): Boolean; static;

    // Search the buffer for the first pixel within Tolerance of
    // TargetColor. Returns a hit in screen coordinates
    // (Origin + buffer-local). Empty rect on the result means not found.
    class function FindColor(const ABuf: TPixelBuffer;
      TargetColor: TColor32; Tolerance: Integer): TColorMatchResult; static;

    // Multi-point combined match: the first point in ASpecs is the anchor;
    // search the buffer for an anchor hit, then verify every subsequent
    // point's color at (anchor + DX, anchor + DY) is within its own Tol.
    // Returns the anchor hit in screen coordinates on success.
    class function FindMultiColor(const ABuf: TPixelBuffer;
      const ASpecs: TColorPointSpecArray): TColorMatchResult; static;

    // Parse a hex color string. Accepts "#RRGGBB", "0xRRGGBB", "RRGGBB".
    // Case-insensitive. Returns False on malformed input.
    class function ParseHexColor(const S: string;
      out Color: TColor32): Boolean; static;

    // Parse a point spec string "dx,dy,#RRGGBB,tol" (tol optional, default 30).
    // dx/dy may be negative. Returns False on malformed input.
    class function ParsePointSpec(const S: string; out DX, DY: Integer;
      out Color: TColor32; out Tol: Integer): Boolean; static;

    // Parse a multi-point spec string. Points separated by '|'. Example:
    // "0,0,#FF8800,30 | 10,0,#00FF00,30 | 5,10,#0000FF,30".
    class function ParseMultiSpec(const S: string;
      out ASpecs: TColorPointSpecArray): Boolean; static;
  end;

implementation

{$POINTERMATH ON}

{ TColorMatchResult }

function TColorMatchResult.Confidence: Double;
begin
  if not Found then
    Exit(0);
  Result := Similarity;
end;

{ TPixelBuffer }

function TPixelBuffer.Width: Integer;
begin
  if Bitmap <> nil then
    Result := Bitmap.Width
  else
    Result := 0;
end;

function TPixelBuffer.Height: Integer;
begin
  if Bitmap <> nil then
    Result := Bitmap.Height
  else
    Result := 0;
end;

function TPixelBuffer.IsValid: Boolean;
begin
  Result := (Bitmap <> nil) and (Bitmap.Width > 0) and (Bitmap.Height > 0);
end;

function TPixelBuffer.PixelAt(X, Y: Integer): TColor32;
var
  LRow: PColor32;
begin
  Result := 0;
  if (Bitmap = nil) or (X < 0) or (Y < 0)
    or (X >= Bitmap.Width) or (Y >= Bitmap.Height) then
    Exit;
  // pf32bit ScanLine is an array of TColor32 (CARDINAL-sized). Read directly.
  LRow := PColor32(Bitmap.ScanLine[Y]);
  Result := TColor32(LRow[X]);
end;

procedure TPixelBuffer.Release;
begin
  // Note: Result aliasing in PixelAt cannot reach here; this is the explicit
  // ownership release. FreeAndNil keeps the record in a safe empty state.
  FreeAndNil(Bitmap);
  OriginX := 0;
  OriginY := 0;
end;

{ TColorMatcher }

class function TColorMatcher.SumChannelDiff(C1, C2: TColor32): Integer;
var
  R1, G1, B1, R2, G2, B2: Byte;
begin
  R1 := (C1 shr 16) and $FF;
  G1 := (C1 shr 8) and $FF;
  B1 := C1 and $FF;
  R2 := (C2 shr 16) and $FF;
  G2 := (C2 shr 8) and $FF;
  B2 := C2 and $FF;
  Result := Abs(R1 - R2) + Abs(G1 - G2) + Abs(B1 - B2);
end;

class function TColorMatcher.CaptureRegion(
  const ARect: TRect): TPixelBuffer;
var
  LScreenDc, LMemDc: HDC;
  LOldBmp: HBitmap;
  LWidth, LHeight: Integer;
  LRect: TRect;
begin
  Result.Bitmap := nil;
  Result.OriginX := 0;
  Result.OriginY := 0;
  LRect := ARect;
  if (LRect.Width <= 0) or (LRect.Height <= 0) then
  begin
    LRect := Rect(0, 0, GetSystemMetrics(SM_CXSCREEN),
      GetSystemMetrics(SM_CYSCREEN));
    if LRect.Width <= 0 then
      Exit;
  end;
  Result.OriginX := LRect.Left;
  Result.OriginY := LRect.Top;
  LWidth := LRect.Width;
  LHeight := LRect.Height;
  LScreenDc := GetDC(0);
  if LScreenDc = 0 then
    Exit;
  try
    LMemDc := CreateCompatibleDC(LScreenDc);
    if LMemDc = 0 then
      Exit;
    try
      Result.Bitmap := TBitmap.Create;
      try
        // pf32bit gives a CARDINAL-sized ScanLine so PixelAt reads TColor32
        // without per-pixel format conversion.
        Result.Bitmap.PixelFormat := pf32bit;
        Result.Bitmap.Width := LWidth;
        Result.Bitmap.Height := LHeight;
        LOldBmp := SelectObject(LMemDc, Result.Bitmap.Handle);
        try
          BitBlt(LMemDc, 0, 0, LWidth, LHeight, LScreenDc,
            LRect.Left, LRect.Top, SRCCOPY);
        finally
          SelectObject(LMemDc, LOldBmp);
        end;
      except
        FreeAndNil(Result.Bitmap);
        raise;
      end;
    finally
      DeleteDC(LMemDc);
    end;
  finally
    ReleaseDC(0, LScreenDc);
  end;
end;

class function TColorMatcher.CheckColorAt(const ABuf: TPixelBuffer;
  X, Y: Integer; TargetColor: TColor32; Tolerance: Integer): Boolean;
var
  LPixel: TColor32;
begin
  Result := False;
  if not ABuf.IsValid then
    Exit;
  LPixel := ABuf.PixelAt(X, Y);
  Result := SumChannelDiff(LPixel, TargetColor) <= Tolerance;
end;

class function TColorMatcher.FindColor(const ABuf: TPixelBuffer;
  TargetColor: TColor32; Tolerance: Integer): TColorMatchResult;
var
  X, Y: Integer;
  LRow: PColor32;
  LPixel: TColor32;
  LDiff: Integer;
begin
  Result.Found := False;
  Result.MatchX := 0;
  Result.MatchY := 0;
  Result.Similarity := 0;
  if not ABuf.IsValid then
    Exit;
  for Y := 0 to ABuf.Height - 1 do
  begin
    LRow := PColor32(ABuf.Bitmap.ScanLine[Y]);
    for X := 0 to ABuf.Width - 1 do
    begin
      LPixel := TColor32(LRow[X]);
      LDiff := SumChannelDiff(LPixel, TargetColor);
      if LDiff <= Tolerance then
      begin
        Result.Found := True;
        Result.MatchX := ABuf.OriginX + X;
        Result.MatchY := ABuf.OriginY + Y;
        Result.Similarity := 1.0 - (LDiff / (255.0 * 3.0));
        Exit;
      end;
    end;
  end;
end;

class function TColorMatcher.FindMultiColor(const ABuf: TPixelBuffer;
  const ASpecs: TColorPointSpecArray): TColorMatchResult;
var
  I, X, Y: Integer;
  LAnchor: TColorPointSpec;
  LRow: PColor32;
  LPixel: TColor32;
  LDiff, LMaxDiff: Integer;
  LMinSim: Double;
begin
  Result.Found := False;
  Result.MatchX := 0;
  Result.MatchY := 0;
  Result.Similarity := 0;
  if (Length(ASpecs) = 0) or not ABuf.IsValid then
    Exit;
  LAnchor := ASpecs[0];
  if LAnchor.Tol < 0 then
    LAnchor.Tol := 0;
  for Y := 0 to ABuf.Height - 1 do
  begin
    LRow := PColor32(ABuf.Bitmap.ScanLine[Y]);
    for X := 0 to ABuf.Width - 1 do
    begin
      LPixel := TColor32(LRow[X]);
      LDiff := SumChannelDiff(LPixel, LAnchor.Color);
      if LDiff > LAnchor.Tol then
        Continue;
      // Anchor hit at buffer-local (X,Y). Verify remaining points at their
      // relative offsets. All must pass; track the worst similarity.
      LMaxDiff := LDiff;
      LMinSim := 1.0 - (LDiff / (255.0 * 3.0));
      for I := 1 to High(ASpecs) do
      begin
        if not CheckColorAt(ABuf, X + ASpecs[I].DX, Y + ASpecs[I].DY,
          ASpecs[I].Color, ASpecs[I].Tol) then
        begin
          LMaxDiff := -1; // signal: verification failed
          Break;
        end;
        LPixel := ABuf.PixelAt(X + ASpecs[I].DX, Y + ASpecs[I].DY);
        LDiff := SumChannelDiff(LPixel, ASpecs[I].Color);
        if LDiff > LMaxDiff then
          LMaxDiff := LDiff;
        if (1.0 - (LDiff / (255.0 * 3.0))) < LMinSim then
          LMinSim := 1.0 - (LDiff / (255.0 * 3.0));
      end;
      if LMaxDiff >= 0 then
      begin
        Result.Found := True;
        Result.MatchX := ABuf.OriginX + X;
        Result.MatchY := ABuf.OriginY + Y;
        Result.Similarity := LMinSim;
        Exit;
      end;
    end;
  end;
end;

class function TColorMatcher.ParseHexColor(const S: string;
  out Color: TColor32): Boolean;
var
  LHex: string;
  LVal: Integer;
  I: Integer;
begin
  Result := False;
  Color := 0;
  LHex := Trim(S);
  if LHex = '' then
    Exit;
  if (Length(LHex) >= 1) and (LHex[1] = '#') then
    Delete(LHex, 1, 1);
  if (Length(LHex) >= 2) and (UpCase(LHex[1]) = '0')
    and (UpCase(LHex[2]) = 'X') then
    Delete(LHex, 1, 2);
  if Length(LHex) <> 6 then
    Exit;
  // Validate every char is a hex digit before converting. StrToInt with a
  // '$' prefix parses hex but raises on garbage; we validate first so a
  // malformed string returns False instead of raising.
  for I := 1 to 6 do
    if not CharInSet(UpCase(LHex[I]), ['0'..'9', 'A'..'F']) then
      Exit;
  LVal := StrToIntDef('$' + LHex, -1);
  if LVal < 0 then
    Exit;
  Color := TColor32(LVal);
  Result := True;
end;

class function TColorMatcher.ParsePointSpec(const S: string;
  out DX, DY: Integer; out Color: TColor32; out Tol: Integer): Boolean;
var
  LParts: TArray<string>;
begin
  Result := False;
  DX := 0;
  DY := 0;
  Color := 0;
  Tol := 30;
  LParts := S.Split([',']);
  if Length(LParts) < 3 then
    Exit;
  if not TryStrToInt(Trim(LParts[0]), DX) then
    Exit;
  if not TryStrToInt(Trim(LParts[1]), DY) then
    Exit;
  if not ParseHexColor(LParts[2], Color) then
    Exit;
  if Length(LParts) >= 4 then
    if not TryStrToInt(Trim(LParts[3]), Tol) then
      Exit;
  Result := True;
end;

class function TColorMatcher.ParseMultiSpec(const S: string;
  out ASpecs: TColorPointSpecArray): Boolean;
var
  LParts: TArray<string>;
  I: Integer;
  LSpec: TColorPointSpec;
begin
  Result := False;
  ASpecs := nil;
  LParts := S.Split(['|']);
  if Length(LParts) = 0 then
    Exit;
  SetLength(ASpecs, Length(LParts));
  for I := 0 to High(LParts) do
  begin
    if not ParsePointSpec(LParts[I], LSpec.DX, LSpec.DY,
      LSpec.Color, LSpec.Tol) then
    begin
      ASpecs := nil;
      Exit;
    end;
    ASpecs[I] := LSpec;
  end;
  Result := True;
end;

end.
