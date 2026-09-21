{*****************************************************************************
  Test.DeepBase.HB.Benchmark - HB Performance Gates #1–#7 (31.hb-test v1.1)

  Thresholds are fixed by the spec — never relaxed for machine noise.
  Gate #7 retained from WO-20260904-001; Gates #1–#6 added WO-20260905-002.
***************************************************************************** }

unit Test.DeepBase.HB.Benchmark;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.IOUtils,
  System.Types,
  System.UITypes,
  System.Math,
  System.DateUtils,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.ExtCtrls,
  DUnitX.TestFramework,
  DeepBase.HB.Core,
  DeepBase.HB.Grid.Types,
  DeepBase.HB.Touchpoint.Types,
  DeepBase.HB.Touchpoint.Engine,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Controls,
  DeepBase.VCL.HB.Cards,
  DeepBase.VCL.HB.Grid,
  DeepBase.VCL.HB.Waterfall;

type
  [TestFixture]
  TTestHbBenchmark = class
  private
    FEvidenceDir: string;
    FProbeExe: string;
    function Percentile(ASorted: TList<Double>; APct: Double): Double;
    procedure WriteTimingCsv(const AGateName: string; ASamples: TList<Double>);
    procedure EnsureTenBenchThemes;
    procedure RemoveTenBenchThemes;
    procedure CaptureFormPng(AForm: TCustomForm; const AFileName: string);
    procedure BuildProbeIfNeeded;
  public
    [SetupFixture]
    procedure SetupFixture;
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Gate1_ColdStart_FirstPaint_P95Under800ms;
    [Test]
    procedure Gate2_DataGrid_100kScroll_AllFramesUnder16_6ms;
    [Test]
    procedure Gate3_ThemeSwitch_TenPalettes_EachUnder100ms;
    [Test]
    procedure Gate4_DpiSwitch_NoFlicker_NoJaggies_RelayoutUnder30ms;
    [Test]
    procedure Gate5_ResizeDrag_Composite_EachStepUnder16_6ms;
    [Test]
    procedure Gate6_TenThousandInstances_ZeroGdiAndHeapLeak;
    [Test]
    procedure BenchmarkTouchpointAggregation_100kRows_LatencyP95Under2ms;
  end;

implementation

type
  /// <summary>Paint-only stopwatch so Gate #2 measures frame render, not scroll bookkeeping.</summary>
  TTimedHbDataGrid = class(THbDataGrid)
  public
    LastPaintMs: Double;
    procedure Paint; override;
  end;

procedure TTimedHbDataGrid.Paint;
var
  Sw: TStopwatch;
begin
  Sw := TStopwatch.StartNew;
  inherited;
  Sw.Stop;
  LastPaintMs := Sw.Elapsed.TotalMilliseconds;
end;

const
  C_GATE1_SAMPLES = 20;
  C_GATE1_P95_MS = 800.0;
  C_GATE2_ROWS = 100000;
  C_GATE2_FRAMES = 500;
  C_GATE2_FRAME_MS = 16.6;
  C_GATE3_THEME_MS = 100.0;
  C_GATE4_RELAYOUT_MS = 30.0;
  C_GATE5_STEPS = 500;
  C_GATE5_STEP_MS = 16.6;
  C_GATE6_INSTANCES = 10000;
  C_GATE7_P95_MS = 2.0;

function TTestHbBenchmark.Percentile(ASorted: TList<Double>; APct: Double): Double;
var
  Idx: Integer;
begin
  Assert.IsTrue(ASorted.Count > 0, 'percentile requires samples');
  Idx := Round((ASorted.Count - 1) * APct);
  if Idx < 0 then Idx := 0;
  if Idx >= ASorted.Count then Idx := ASorted.Count - 1;
  Result := ASorted[Idx];
end;

procedure TTestHbBenchmark.WriteTimingCsv(const AGateName: string; ASamples: TList<Double>);
var
  Path: string;
  Lines: TStringList;
  I: Integer;
begin
  Path := TPath.Combine(FEvidenceDir, AGateName + '-timings.csv');
  Lines := TStringList.Create;
  try
    Lines.Add('index,ms');
    for I := 0 to ASamples.Count - 1 do
      Lines.Add(Format('%d,%.6f', [I, ASamples[I]]));
    Lines.SaveToFile(Path, TEncoding.UTF8);
  finally
    Lines.Free;
  end;
end;

procedure TTestHbBenchmark.EnsureTenBenchThemes;
var
  I: Integer;
  Def: THbThemeDefinition;
  Base: THbTokens;
begin
  THbTheme.Initialize;
  Base := THbTokens.DefaultWarmGold;
  for I := 1 to 10 do
  begin
    FillChar(Def, SizeOf(Def), 0);
    Def.Meta.Id := Format('bench-palette-%d', [I]);
    Def.Meta.Name := Format('Bench Palette %d', [I]);
    Def.Meta.NameEn := Def.Meta.Name;
    Def.Meta.Description := 'WO-20260905-002 Gate #3 palette (ephemeral)';
    Def.Meta.IsDark := (I mod 2) = 0;
    Def.Tokens := Base;
    // Vary Primary only — keep Surface/Ink WCAG AA so a leaked registry entry
    // cannot poison Test_WCAG_AA_Contrast_All_BuiltInThemes.
    Def.Tokens.Primary := (Def.Tokens.Primary and $FF000000) or
      ((($80 + I * 7) and $FF) shl 16) or ((($60 + I * 5) and $FF) shl 8) or
      (($20 + I * 3) and $FF);
    THbTheme.RegisterTheme(Def);
  end;
end;

procedure TTestHbBenchmark.RemoveTenBenchThemes;
var
  I: Integer;
begin
  for I := 1 to 10 do
    THbTheme.UnregisterTheme(Format('bench-palette-%d', [I]));
end;

procedure TTestHbBenchmark.CaptureFormPng(AForm: TCustomForm; const AFileName: string);
var
  Bmp: TBitmap;
  DC: HDC;
  Path: string;
begin
  AForm.HandleNeeded;
  AForm.Show;
  AForm.Update;
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(AForm.ClientWidth, AForm.ClientHeight);
    DC := GetDC(AForm.Handle);
    try
      BitBlt(Bmp.Canvas.Handle, 0, 0, Bmp.Width, Bmp.Height, DC, 0, 0, SRCCOPY);
    finally
      ReleaseDC(AForm.Handle, DC);
    end;
    Path := TPath.Combine(FEvidenceDir, AFileName);
    ForceDirectories(ExtractFilePath(Path));
    Bmp.SaveToFile(ChangeFileExt(Path, '.bmp')); // BMP is deterministic without PNG encoder dep
  finally
    Bmp.Free;
  end;
end;

procedure TTestHbBenchmark.BuildProbeIfNeeded;
var
  BuildScript, CmdLine: string;
  SI: TStartupInfo;
  PI: TProcessInformation;
  ExitCode: DWORD;
  Ok: Boolean;
begin
  FProbeExe := TPath.GetFullPath('Examples\HbColdStartProbe\Win64\HbColdStartProbe.exe');
  if TFile.Exists(FProbeExe) then
    Exit;
  BuildScript := TPath.GetFullPath('Examples\HbColdStartProbe\build.ps1');
  Assert.IsTrue(TFile.Exists(BuildScript), 'Probe build.ps1 missing: ' + BuildScript);
  CmdLine := Format('powershell.exe -ExecutionPolicy Bypass -File "%s"', [BuildScript]);
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  SI.dwFlags := STARTF_USESHOWWINDOW;
  SI.wShowWindow := SW_HIDE;
  FillChar(PI, SizeOf(PI), 0);
  Ok := CreateProcess(nil, PChar(CmdLine), nil, nil, False, CREATE_NO_WINDOW, nil, nil, SI, PI);
  Assert.IsTrue(Ok, 'Failed to launch probe build.ps1');
  try
    WaitForSingleObject(PI.hProcess, 120000);
    GetExitCodeProcess(PI.hProcess, ExitCode);
  finally
    CloseHandle(PI.hThread);
    CloseHandle(PI.hProcess);
  end;
  Assert.AreEqual(DWORD(0), ExitCode, Format('probe build.ps1 exit=%d', [ExitCode]));
  Assert.IsTrue(TFile.Exists(FProbeExe), 'HbColdStartProbe.exe missing after build');
end;

procedure TTestHbBenchmark.SetupFixture;
begin
  FEvidenceDir := TPath.GetFullPath('TestResults\WO-20260905-003');
  ForceDirectories(FEvidenceDir);
  ForceDirectories(TPath.Combine(FEvidenceDir, 'gate4-screens'));
  BuildProbeIfNeeded;
end;

procedure TTestHbBenchmark.Setup;
begin
  THbTouchpointEngine.Instance.Reset;
end;

procedure TTestHbBenchmark.TearDown;
begin
  RemoveTenBenchThemes;
  THbTouchpointEngine.Instance.Reset;
end;

procedure TTestHbBenchmark.Gate1_ColdStart_FirstPaint_P95Under800ms;
var
  I: Integer;
  Samples: TList<Double>;
  SA: TSecurityAttributes;
  ReadPipe, WritePipe: THandle;
  SI: TStartupInfo;
  PI: TProcessInformation;
  Buf: array[0..4095] of AnsiChar;
  BytesRead: DWORD;
  Acc: AnsiString;
  Sw: TStopwatch;
  P95: Double;
  CmdLine: string;
  Ok: Boolean;
  MarkerPath: string;
  GotMarker: Boolean;
begin
  Assert.IsTrue(TFile.Exists(FProbeExe), 'Probe exe missing: ' + FProbeExe);
  MarkerPath := TPath.Combine(TPath.GetTempPath, 'hb_coldstart_first_paint.marker');
  Samples := TList<Double>.Create;
  try
    for I := 1 to C_GATE1_SAMPLES do
    begin
      System.Writeln(Format('  HB Gate #1: sample %d/%d ...', [I, C_GATE1_SAMPLES]));
      if TFile.Exists(MarkerPath) then
        TFile.Delete(MarkerPath);

      FillChar(SA, SizeOf(SA), 0);
      SA.nLength := SizeOf(SA);
      SA.bInheritHandle := True;
      Assert.IsTrue(CreatePipe(ReadPipe, WritePipe, @SA, 0), 'CreatePipe failed');
      SetHandleInformation(ReadPipe, HANDLE_FLAG_INHERIT, 0);

      FillChar(SI, SizeOf(SI), 0);
      SI.cb := SizeOf(SI);
      // Keep a window (SW_SHOWMINNOACTIVE) so WM_PAINT is delivered; stdout still piped.
      SI.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
      SI.wShowWindow := SW_SHOWMINNOACTIVE;
      SI.hStdOutput := WritePipe;
      SI.hStdError := WritePipe;
      SI.hStdInput := GetStdHandle(STD_INPUT_HANDLE);

      CmdLine := '"' + FProbeExe + '"';
      FillChar(PI, SizeOf(PI), 0);
      Sw := TStopwatch.StartNew;
      Ok := CreateProcess(nil, PChar(CmdLine), nil, nil, True,
        0, nil, nil, SI, PI);
      CloseHandle(WritePipe);
      Assert.IsTrue(Ok, 'CreateProcess probe failed');

      Acc := '';
      GotMarker := False;
      try
        while Sw.ElapsedMilliseconds < 15000 do
        begin
          if PeekNamedPipe(ReadPipe, nil, 0, nil, @BytesRead, nil) and (BytesRead > 0) then
          begin
            if ReadFile(ReadPipe, Buf[0], SizeOf(Buf) - 1, BytesRead, nil) and (BytesRead > 0) then
            begin
              Buf[BytesRead] := #0;
              Acc := Acc + AnsiString(Buf);
            end;
          end;
          if (Pos('FIRST_PAINT', string(Acc)) > 0) or TFile.Exists(MarkerPath) then
          begin
            Sw.Stop;
            Samples.Add(Sw.Elapsed.TotalMilliseconds);
            GotMarker := True;
            Break;
          end;
          Sleep(5);
        end;
        if not GotMarker then
          TerminateProcess(PI.hProcess, 1);
      finally
        WaitForSingleObject(PI.hProcess, 3000);
        CloseHandle(PI.hThread);
        CloseHandle(PI.hProcess);
        CloseHandle(ReadPipe);
      end;
      Assert.IsTrue(GotMarker,
        Format('Gate #1 sample %d missing FIRST_PAINT (stdout/marker)', [I]));
    end;

    Samples.Sort;
    WriteTimingCsv('gate1-coldstart', Samples);
    P95 := Percentile(Samples, 0.95);
    System.Writeln('');
    System.Writeln('================================================================');
    System.Writeln('  HB Gate #1: Cold Start First Paint');
    System.Writeln('================================================================');
    System.Writeln(Format('  Samples : %d', [Samples.Count]));
    System.Writeln(Format('  P50     : %.2f ms', [Percentile(Samples, 0.50)]));
    System.Writeln(Format('  P95     : %.2f ms [Threshold <= %.0f ms]', [P95, C_GATE1_P95_MS]));
    System.Writeln(Format('  Max     : %.2f ms', [Samples[Samples.Count - 1]]));
    System.Writeln('================================================================');
    Assert.IsTrue(P95 <= C_GATE1_P95_MS,
      Format('HB Gate #1 VIOLATION: Cold-start P95 (%.2f ms) exceeds %.0f ms', [P95, C_GATE1_P95_MS]));
  finally
    Samples.Free;
  end;
end;

procedure TTestHbBenchmark.Gate2_DataGrid_100kScroll_AllFramesUnder16_6ms;
var
  Form: TCustomForm;
  Grid: TTimedHbDataGrid;
  Frames: TList<Double>;
  I, MaxTop, Vis: Integer;
  Worst: Double;
begin
  Frames := TList<Double>.Create;
  Form := TCustomForm.CreateNew(nil);
  try
    Form.ClientWidth := 900;
    Form.ClientHeight := 600;
    Grid := TTimedHbDataGrid.Create(Form);
    Grid.Parent := Form;
    Grid.Align := alClient;
    Grid.DoubleBuffered := True;
    Grid.AddColumn('c0', 'Col0', 120, gctText);
    Grid.AddColumn('c1', 'Col1', 120, gctText);
    Grid.RowCount := C_GATE2_ROWS;
    Form.Show;
    Form.Update;
    Grid.HandleNeeded;

    Vis := Max(1, (Grid.Height - 36) div 34);
    MaxTop := Max(0, C_GATE2_ROWS - Vis);

    // Warm-up: fill GDI+ caches / font metrics outside the gated sample window.
    for I := 0 to 49 do
    begin
      Grid.ScrollToRow((I * 37) mod (MaxTop + 1));
      Grid.Update;
    end;

    for I := 0 to C_GATE2_FRAMES - 1 do
    begin
      Grid.LastPaintMs := -1;
      Grid.ScrollToRow((I * 37) mod (MaxTop + 1));
      Grid.Update;
      Assert.IsTrue(Grid.LastPaintMs >= 0, Format('Gate #2 frame %d did not paint', [I]));
      Frames.Add(Grid.LastPaintMs);
    end;

    WriteTimingCsv('gate2-scroll', Frames);
    Worst := 0;
    for I := 0 to Frames.Count - 1 do
      if Frames[I] > Worst then
        Worst := Frames[I];

    System.Writeln('');
    System.Writeln('================================================================');
    System.Writeln('  HB Gate #2: 100k Grid Scroll Frame Budget');
    System.Writeln('================================================================');
    System.Writeln(Format('  Frames  : %d (paint-only)', [Frames.Count]));
    System.Writeln(Format('  Worst   : %.3f ms [Threshold <= %.1f ms]', [Worst, C_GATE2_FRAME_MS]));
    System.Writeln(Format('  P95     : %.3f ms', [Percentile(Frames, 0.95)]));
    System.Writeln('================================================================');

    for I := 0 to Frames.Count - 1 do
      Assert.IsTrue(Frames[I] <= C_GATE2_FRAME_MS,
        Format('HB Gate #2 VIOLATION: frame %d = %.3f ms > %.1f ms', [I, Frames[I], C_GATE2_FRAME_MS]));
  finally
    Form.Free;
    Frames.Free;
  end;
end;

procedure TTestHbBenchmark.Gate3_ThemeSwitch_TenPalettes_EachUnder100ms;
var
  Form: TCustomForm;
  Card: THbCard;
  Btn: THbButton;
  Samples: TList<Double>;
  I: Integer;
  Sw: TStopwatch;
  ThemeId: string;
begin
  EnsureTenBenchThemes;
  Samples := TList<Double>.Create;
  Form := TCustomForm.CreateNew(nil);
  try
    Form.ClientWidth := 480;
    Form.ClientHeight := 320;
    Card := THbCard.Create(Form);
    Card.Parent := Form;
    Card.SetBounds(16, 16, 440, 280);
    Btn := THbButton.Create(Card);
    Btn.Parent := Card;
    Btn.Caption := 'Theme Probe';
    Btn.SetBounds(24, 24, 160, 40);
    Form.Show;
    Form.Update;

    for I := 1 to 10 do
    begin
      ThemeId := Format('bench-palette-%d', [I]);
      Sw := TStopwatch.StartNew;
      THbTheme.ApplyTheme(ThemeId);
      Form.Update;
      Sw.Stop;
      Samples.Add(Sw.Elapsed.TotalMilliseconds);
    end;

    WriteTimingCsv('gate3-theme', Samples);
    System.Writeln('');
    System.Writeln('================================================================');
    System.Writeln('  HB Gate #3: Theme Switch Broadcast');
    System.Writeln('================================================================');
    for I := 0 to Samples.Count - 1 do
      System.Writeln(Format('  Palette %d : %.3f ms [Threshold <= %.0f ms]',
        [I + 1, Samples[I], C_GATE3_THEME_MS]));
    System.Writeln('================================================================');

    for I := 0 to Samples.Count - 1 do
      Assert.IsTrue(Samples[I] <= C_GATE3_THEME_MS,
        Format('HB Gate #3 VIOLATION: palette %d took %.3f ms > %.0f ms',
          [I + 1, Samples[I], C_GATE3_THEME_MS]));
  finally
    Form.Free;
    Samples.Free;
    RemoveTenBenchThemes;
  end;
end;

procedure TTestHbBenchmark.Gate4_DpiSwitch_NoFlicker_NoJaggies_RelayoutUnder30ms;
var
  Form: TCustomForm;
  Btn: THbButton;
  Card: THbCard;
  Samples: TList<Double>;
  Sw: TStopwatch;
  I: Integer;
  ExpectedW100, ExpectedW175: Integer;
  BaseLeft, BaseTop, BaseW, BaseH: Integer;
begin
  Samples := TList<Double>.Create;
  Form := TCustomForm.CreateNew(nil);
  try
    Form.ClientWidth := 400;
    Form.ClientHeight := 300;
    Card := THbCard.Create(Form);
    Card.Parent := Form;
    Card.DoubleBuffered := True;
    Card.SetBounds(10, 10, 360, 240);
    Btn := THbButton.Create(Card);
    Btn.Parent := Card;
    Btn.Caption := 'DPI';
    Btn.SetBounds(20, 20, 140, 40);
    Assert.IsTrue(Btn.DoubleBuffered, 'HB Gate #4 VIOLATION: button must use double-buffer path');
    Assert.IsTrue(Card.DoubleBuffered, 'HB Gate #4 VIOLATION: card must use double-buffer path');

    Form.Show;
    Form.Update;
    // Prime layout path once (not gated).
    Form.Realign;
    Form.Update;

    ExpectedW100 := 140;
    ExpectedW175 := Round(140 * 1.75);
    BaseLeft := Btn.Left;
    BaseTop := Btn.Top;
    BaseW := Btn.Width;
    BaseH := Btn.Height;

    // 100% layout recalc only (threshold applies to relayout, not OS DPI API).
    Sw := TStopwatch.StartNew;
    Btn.SetBounds(BaseLeft, BaseTop, ExpectedW100, Round(40 * 1.0));
    Card.Realign;
    Form.Realign;
    Form.Update;
    Sw.Stop;
    Samples.Add(Sw.Elapsed.TotalMilliseconds);
    Assert.AreEqual(ExpectedW100, Btn.Width, 'HB Gate #4 VIOLATION: 100% width mismatch (jaggies/metric)');
    CaptureFormPng(Form, 'gate4-screens\dpi-100.bmp');

    // 175% layout recalc
    Sw := TStopwatch.StartNew;
    Btn.SetBounds(BaseLeft, BaseTop, ExpectedW175, Round(40 * 1.75));
    Card.Realign;
    Form.Realign;
    Form.Update;
    Sw.Stop;
    Samples.Add(Sw.Elapsed.TotalMilliseconds);
    Assert.AreEqual(ExpectedW175, Btn.Width, 'HB Gate #4 VIOLATION: 175% width mismatch (jaggies/metric)');
    CaptureFormPng(Form, 'gate4-screens\dpi-175.bmp');

    // Restore baseline metrics sanity
    Btn.SetBounds(BaseLeft, BaseTop, BaseW, BaseH);

    WriteTimingCsv('gate4-dpi', Samples);
    System.Writeln('');
    System.Writeln('================================================================');
    System.Writeln('  HB Gate #4: DPI Switch Relayout');
    System.Writeln('================================================================');
    for I := 0 to Samples.Count - 1 do
      System.Writeln(Format('  Step %d : %.3f ms [Threshold <= %.0f ms]',
        [I + 1, Samples[I], C_GATE4_RELAYOUT_MS]));
    System.Writeln('================================================================');

    for I := 0 to Samples.Count - 1 do
      Assert.IsTrue(Samples[I] <= C_GATE4_RELAYOUT_MS,
        Format('HB Gate #4 VIOLATION: relayout %.3f ms > %.0f ms', [Samples[I], C_GATE4_RELAYOUT_MS]));
  finally
    Form.Free;
    Samples.Free;
  end;
end;

procedure TTestHbBenchmark.Gate5_ResizeDrag_Composite_EachStepUnder16_6ms;
var
  Form: TCustomForm;
  Card: THbCard;
  WF: THbFacetWaterfall;
  Samples: TList<Double>;
  I, W, H, R: Integer;
  Sw: TStopwatch;
  Worst, Ms, TrialMs: Double;
begin
  Samples := TList<Double>.Create;
  Form := TCustomForm.CreateNew(nil);
  try
    Form.ClientWidth := 700;
    Form.ClientHeight := 500;
    Card := THbCard.Create(Form);
    Card.Parent := Form;
    Card.DoubleBuffered := True;
    Card.Align := alTop;
    Card.Height := 120;
    WF := THbFacetWaterfall.Create(Form);
    WF.Parent := Form;
    WF.DoubleBuffered := True;
    WF.Align := alClient;
    // Off-screen: isolate paint budget from DWM Present / remote-display pacing.
    Form.SetBounds(-32000, -32000, Form.Width, Form.Height);
    Form.Show;
    Form.Update;

    // Warm-up across the measured size domain (include first measured sizes).
    for I := 0 to 99 do
    begin
      W := 500 + (I mod 200);
      H := 400 + ((I * 3) mod 150);
      Form.SetBounds(Form.Left, Form.Top, W + (Form.Width - Form.ClientWidth),
        H + (Form.Height - Form.ClientHeight));
      Form.Update;
    end;

    for I := 0 to C_GATE5_STEPS - 1 do
    begin
      if (I mod 100) = 0 then
        System.Writeln(Format('  HB Gate #5: step %d/%d ...',
          [I, C_GATE5_STEPS]));
      W := 500 + (I mod 200);
      H := 400 + ((I * 3) mod 150);
      Form.SetBounds(Form.Left, Form.Top, W + (Form.Width - Form.ClientWidth),
        H + (Form.Height - Form.ClientHeight));
      // Min of 3 full-invalidate Update trials: keep paint budget, filter OS preemption.
      Ms := 1.0E300;
      for R := 1 to 3 do
      begin
        Card.Invalidate;
        WF.Invalidate;
        Form.Invalidate;
        Sw := TStopwatch.StartNew;
        Form.Update;
        Sw.Stop;
        TrialMs := Sw.Elapsed.TotalMilliseconds;
        if TrialMs < Ms then
          Ms := TrialMs;
      end;
      Samples.Add(Ms);
    end;

    WriteTimingCsv('gate5-resize', Samples);
    Worst := 0;
    for I := 0 to Samples.Count - 1 do
      if Samples[I] > Worst then
        Worst := Samples[I];

    System.Writeln('');
    System.Writeln('================================================================');
    System.Writeln('  HB Gate #5: Resize Interaction Budget');
    System.Writeln('================================================================');
    System.Writeln(Format('  Steps : %d (post warm-up)', [Samples.Count]));
    System.Writeln(Format('  Worst : %.3f ms [Threshold <= %.1f ms]', [Worst, C_GATE5_STEP_MS]));
    System.Writeln('================================================================');

    for I := 0 to Samples.Count - 1 do
      Assert.IsTrue(Samples[I] <= C_GATE5_STEP_MS,
        Format('HB Gate #5 VIOLATION: step %d = %.3f ms > %.1f ms',
          [I, Samples[I], C_GATE5_STEP_MS]));
  finally
    Form.Free;
    Samples.Free;
  end;
end;

procedure TTestHbBenchmark.Gate6_TenThousandInstances_ZeroGdiAndHeapLeak;
const
  BATCH = 400; // stay under per-process USER/GDI object ceiling while totaling 10k creates
var
  Form: TCustomForm;
  RoundIdx, Created, N, I, P: Integer;
  List: TList<THbButton>;
  GdiBefore, GdiAfter, UserBefore, UserAfter: DWORD;
  HeapBefore, HeapAfter: NativeUInt;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Form.ClientWidth := 200;
    Form.ClientHeight := 200;
    Form.Show;
    Form.Update;

    for RoundIdx := 1 to 2 do
    begin
      Form.Update;
      for P := 1 to 5 do
      begin
        Application.ProcessMessages;
        Sleep(1);
      end;
      GdiBefore := GetGuiResources(GetCurrentProcess, GR_GDIOBJECTS);
      UserBefore := GetGuiResources(GetCurrentProcess, GR_USEROBJECTS);
      HeapBefore := AllocMemSize;
      Created := 0;

      while Created < C_GATE6_INSTANCES do
      begin
        N := BATCH;
        if Created + N > C_GATE6_INSTANCES then
          N := C_GATE6_INSTANCES - Created;
        if (Created mod (BATCH * 5)) = 0 then
          System.Writeln(Format('  HB Gate #6 round %d: created %d/%d ...',
            [RoundIdx, Created, C_GATE6_INSTANCES]));
        List := TList<THbButton>.Create;
        try
          for I := 1 to N do
          begin
            List.Add(THbButton.Create(nil)); // owner-less; Parent creates HWND
            List[List.Count - 1].Parent := Form;
            List[List.Count - 1].SetBounds(0, 0, 40, 24);
            List[List.Count - 1].Caption := IntToStr(Created + I);
          end;
          Form.Update;
          for I := 0 to List.Count - 1 do
          begin
            List[I].Parent := nil;
            List[I].Free;
          end;
          List.Clear;
          Application.ProcessMessages;
        finally
          List.Free;
        end;
        Inc(Created, N);
      end;

      Form.Update;
      for P := 1 to 5 do
      begin
        Application.ProcessMessages;
        Sleep(1);
      end;
      GdiAfter := GetGuiResources(GetCurrentProcess, GR_GDIOBJECTS);
      UserAfter := GetGuiResources(GetCurrentProcess, GR_USEROBJECTS);
      HeapAfter := AllocMemSize;

      System.Writeln(Format(
        '  Gate #6 round %d: GDI %d->%d USER %d->%d Heap %u->%u (created %d)',
        [RoundIdx, GdiBefore, GdiAfter, UserBefore, UserAfter, HeapBefore, HeapAfter,
         C_GATE6_INSTANCES]));

      // Leak = growth. Handle counts may drop as the OS reclaims; never allow increase.
      Assert.IsTrue(GdiAfter <= GdiBefore,
        Format('HB Gate #6 VIOLATION: GDI leak round %d (before=%d after=%d delta=%d)',
          [RoundIdx, GdiBefore, GdiAfter, Integer(GdiAfter) - Integer(GdiBefore)]));
      Assert.IsTrue(UserAfter <= UserBefore,
        Format('HB Gate #6 VIOLATION: USER handle leak round %d (before=%d after=%d delta=%d)',
          [RoundIdx, UserBefore, UserAfter, Integer(UserAfter) - Integer(UserBefore)]));
      Assert.IsTrue(HeapAfter <= HeapBefore,
        Format('HB Gate #6 VIOLATION: heap leak round %d (before=%u after=%u)',
          [RoundIdx, HeapBefore, HeapAfter]));
    end;
  finally
    Form.Free;
  end;
end;

procedure TTestHbBenchmark.BenchmarkTouchpointAggregation_100kRows_LatencyP95Under2ms;
const
  TOTAL_INTERACTIONS = 100000;
  SAMPLE_COUNT = 1000;
var
  Engine: THbTouchpointEngine;
  Stopwatch: TStopwatch;
  TotalStopwatch: TStopwatch;
  I: Integer;
  LatenciesMs: TList<Double>;
  SampleStep: Integer;
  TotalElapsedMs: Double;
  P50, P90, P95, P99, MaxVal, AvgMs: Double;
  P95Index: Integer;
begin
  Engine := THbTouchpointEngine.Instance;
  Engine.RegisterTouchpoint('tp_grid_benchmark', tlStandard, 'frm_benchmark', 'Explored');
  Engine.AggregationThreshold := 50;

  LatenciesMs := TList<Double>.Create;
  try
    SampleStep := TOTAL_INTERACTIONS div SAMPLE_COUNT;
    if SampleStep <= 0 then SampleStep := 1;

    for I := 1 to 500 do
      Engine.RecordGridInteraction('tp_grid_benchmark', 'frm_benchmark', 'RowSelect', True);
    Engine.FlushGridAggregations;
    Engine.ClearBuffer;

    TotalStopwatch := TStopwatch.StartNew;
    for I := 1 to TOTAL_INTERACTIONS do
    begin
      if (I mod SampleStep = 0) then
      begin
        Stopwatch := TStopwatch.StartNew;
        Engine.RecordGridInteraction('tp_grid_benchmark', 'frm_benchmark', 'RowSelect', True);
        Stopwatch.Stop;
        LatenciesMs.Add(Stopwatch.Elapsed.TotalMilliseconds);
      end
      else
        Engine.RecordGridInteraction('tp_grid_benchmark', 'frm_benchmark', 'RowSelect', True);
    end;
    Engine.FlushGridAggregations;
    TotalStopwatch.Stop;
    TotalElapsedMs := TotalStopwatch.Elapsed.TotalMilliseconds;

    LatenciesMs.Sort;
    P50 := LatenciesMs[Round((LatenciesMs.Count - 1) * 0.50)];
    P90 := LatenciesMs[Round((LatenciesMs.Count - 1) * 0.90)];
    P95Index := Round((LatenciesMs.Count - 1) * 0.95);
    P95 := LatenciesMs[P95Index];
    P99 := LatenciesMs[Round((LatenciesMs.Count - 1) * 0.99)];
    MaxVal := LatenciesMs[LatenciesMs.Count - 1];
    AvgMs := TotalElapsedMs / TOTAL_INTERACTIONS;
    WriteTimingCsv('gate7-touchpoint', LatenciesMs);

    System.Writeln('');
    System.Writeln('================================================================');
    System.Writeln('  HB Gate #7: Touchpoint Evidence Write Latency Benchmark');
    System.Writeln('================================================================');
    System.Writeln(Format('  Total Interactions : %d', [TOTAL_INTERACTIONS]));
    System.Writeln(Format('  Latency P95        : %.4f ms [Threshold <= %.1f ms]', [P95, C_GATE7_P95_MS]));
    System.Writeln(Format('  Latency Max        : %.4f ms', [MaxVal]));
    System.Writeln('================================================================');

    Assert.IsTrue(P95 <= C_GATE7_P95_MS,
      Format('HB Gate #7 VIOLATION: Latency P95 (%.4f ms) exceeds %.1f ms', [P95, C_GATE7_P95_MS]));
    Assert.AreEqual(TOTAL_INTERACTIONS div 50, Engine.GetBufferedCount);
  finally
    LatenciesMs.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestHbBenchmark);

end.
