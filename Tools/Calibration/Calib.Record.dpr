{ ============================================================================
  Calib.Record - DeepAxis perception L0 frame recorder (console, real machine)

  用法:
    Calib.Record <seqId> <kind> <frames> <intervalMs> [sampleRoot]

    seqId       sequence id, e.g. seq-001 (dir name under <sampleRoot>/<kind>/)
    kind        static | changed | boundary  (docs/94 §6.2 sample classes)
    frames      number of frames to capture (>=2; 1st seeds the differ)
    intervalMs  ms between captures (e.g. 500)
    sampleRoot  optional; default = ./Calib.Samples

  录制 docs/94 §6.2 样本集的 B 步真机采集端。每帧用 TDesktopPerceptionEngine
  .CaptureScreen 取真机 BitBlt 截图，解码 ImageBase64(PNG) <sampleRoot>/<kind>/写盘
  为 NNNN.png，并追加一行 JSONL 到 manifest.jsonl (seqId/frameIdx/tsMs/pngName/
  engineUnchanged/widthPx/heightPx)。人工按 kind 安排场景 (static=待机亚像素抖动,
  changed=消息收发, boundary=渐变/淡入)。

  产物直接被 Calib.Sweep 消费 (按目录约定 static/changed/boundary/<seq>/*.png)。
  真实场景不使用合成位图 (合成图无法反映亚像素抖动, 见 §6.2)。
  ========================================================================== }

program Calib.Record;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.StrUtils,
  System.IOUtils,
  System.NetEncoding,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
  DeepBase.Desktop.Perception.Engine,
  DeepBase.Desktop.Perception.Types;

function EnsureKind(const S: string): string;
begin
  Result := LowerCase(S);
  if (Result <> 'static') and (Result <> 'changed') and (Result <> 'boundary') then
    raise EArgumentException.CreateFmt(
      'kind must be static|changed|boundary, got "%s"', [S]);
end;

/// PNG-encoded screenshot bytes from ImageBase64 (base64-decode the PNG).
function PngBytesFromBase64(const ABase64: string): TBytes;
var
  LDec: TBytes;
begin
  LDec := TNetEncoding.Base64.DecodeStringToBytes(ABase64);
  Result := LDec;
end;

procedure WritePngFile(const AOutPath: string; const APngBytes: TBytes;
  out AWidthPx, AHeightPx: Integer);
var
  LMs: TBytesStream;
  LPng: TPngImage;
  LBmp: TBitmap;
begin
  AWidthPx := 0;
  AHeightPx := 0;
  LMs := TBytesStream.Create(APngBytes);
  try
    LPng := TPngImage.Create;
    try
      LPng.LoadFromStream(LMs);
      LPng.SaveToFile(AOutPath);
      AWidthPx := LPng.Width;
      AHeightPx := LPng.Height;
    finally
      LPng.Free;
    end;
  finally
    LMs.Free;
  end;
end;

/// Append one JSONL record. We hand-build the JSON line to avoid pulling a
/// JSON serializer into a standalone capsule tool; fields are simple scalars.
function JsonLine(const ASeqId: string; AFrameIdx: Integer;
  ATsTicks: Int64; const APngName: string; AEngineUnchanged: Boolean;
  AWidthPx, AHeightPx: Integer): string;
const
  CQuote = '"';
begin
  Result := Format(
    '{' +
      CQuote + 'seqId'    + CQuote + ':' + CQuote + '%s' + CQuote + ',' +
      CQuote + 'frameIdx' + CQuote + ':%d,' +
      CQuote + 'tsMs'     + CQuote + ':%d,' +
      CQuote + 'png'      + CQuote + ':' + CQuote + '%s' + CQuote + ',' +
      CQuote + 'engineUnchanged' + CQuote + ':%s,' +
      CQuote + 'widthPx'  + CQuote + ':%d,' +
      CQuote + 'heightPx' + CQuote + ':%d' +
    '}',
    [ASeqId, AFrameIdx, ATsTicks, APngName,
     IfThen(AEngineUnchanged, 'true', 'false'), AWidthPx, AHeightPx]);
end;

var
  GSeqId, GKind, GSampleRoot: string;
  GFrames, GIntervalMs, I: Integer;
  GSeqDir, GManifestPath, GSeqKindDir: string;
  GEngine: TDesktopPerceptionEngine;
  GShot: TDesktopScreenshot;
  GPngName, GPngPath: string;
  GBytes: TBytes;
  GW, GH: Integer;
  GTicks: Int64;
  GManifest: TStreamWriter;
begin
  GSeqId := '';
  GKind := '';
  GSampleRoot := 'Calib.Samples';
  GFrames := 0;
  GIntervalMs := 0;
  ExitCode := 0;
  try
    if ParamCount < 4 then
    begin
      Writeln('Usage: Calib.Record <seqId> <kind> <frames> <intervalMs> [sampleRoot]');
      Writeln('  kind = static | changed | boundary');
      ExitCode := 2;
      Exit;
    end;
    GSeqId := ParamStr(1);
    GKind := EnsureKind(ParamStr(2));
    GFrames := StrToInt(ParamStr(3));
    GIntervalMs := StrToInt(ParamStr(4));
    if ParamCount >= 5 then
      GSampleRoot := ParamStr(5);

    if GFrames < 2 then
      raise EArgumentException.Create('frames must be >= 2 (1st seeds the differ)');
    if GIntervalMs < 1 then
      raise EArgumentException.Create('intervalMs must be >= 1');

    GSeqKindDir := TPath.Combine(
      TPath.Combine(TPath.GetFullPath(GSampleRoot), GKind), GSeqId);
    TDirectory.CreateDirectory(GSeqKindDir);
    GManifestPath := TPath.Combine(GSeqKindDir, 'manifest.jsonl');

    GManifest := TStreamWriter.Create(GManifestPath, False, TEncoding.UTF8);
    GManifest.NewLine := #10;
    try
      Writeln(Format('Recording kind=%s seq=%s frames=%d interval=%dms -> %s',
        [GKind, GSeqId, GFrames, GIntervalMs, GSeqKindDir]));
      Writeln('Arrange the real DeepAxis scene now (see docs/94 §6.2). Capturing...');

      GEngine := TDesktopPerceptionEngine.Create;
      try
        for I := 1 to GFrames do
        begin
          GTicks := TThread.GetTickCount;  // monotonic-ish ms since boot
          GShot := GEngine.CaptureScreen;

          if not GShot.IsValid then
            raise Exception.Create('CaptureScreen returned an invalid screenshot');

          GPngName := Format('%.4d.png', [I]);
          GPngPath := TPath.Combine(GSeqKindDir, GPngName);
          GBytes := PngBytesFromBase64(GShot.ImageBase64);
          WritePngFile(GPngPath, GBytes, GW, GH);
          GManifest.WriteLine(JsonLine(GSeqId, I, GTicks, GPngName,
            GShot.Unchanged, GW, GH));
          Writeln(Format('  %s  %s  engineUnchanged=%s  %dx%d',
            [GPngName, GShot.MimeType,
             IfThen(GShot.Unchanged, 'true', 'false'), GW, GH]));

          if I < GFrames then
            Sleep(GIntervalMs);
        end;
      finally
        GEngine.Free;
      end;
    finally
      GManifest.Free;
    end;

    Writeln;
    Writeln(Format('Done. %d frames + manifest at %s', [GFrames, GSeqKindDir]));
    Writeln('Repeat for each (static/changed/boundary) seq covering docs/94 §6.2,');
    Writeln('then run: Calib.Sweep ' + GSampleRoot);

    ExitCode := 0;
  except
    on E: EArgumentException do
    begin
      Writeln(ErrOutput, 'Argument error: ' + E.Message);
      ExitCode := 2;
    end;
    on E: Exception do
    begin
      Writeln(ErrOutput, 'Record failed: ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
