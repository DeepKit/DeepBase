{ ============================================================================
  Calib.Sweep - TFrameDiffer threshold sweep runner (console)

  用法:
    Calib.Sweep <sampleRoot>            扫描并打印 summary + §6 markdown 表
    Calib.Sweep <sampleRoot> --md <f>   另存 markdown 表到文件 f (供 docs/94 粘贴)

  实现 docs/94 §6.3 阈值标定协议的真机执行端 (B 步)。样本由 Calib.Record.dpr
  录制到 <sampleRoot>/static|changed|boundary/<seq>/*.png。详见 Calib.SweepLib.pas
  头注。
  ========================================================================== }

program Calib.Sweep;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  Calib.SweepLib in 'Calib.SweepLib.pas';

var
  GRoot, GMdPath: string;
  GReport: TSweepReport;
  GNoStatic, GNoChanged, GNoBoundary: Boolean;
begin
  GRoot := '';
  GMdPath := '';
  try
    if ParamCount < 1 then
    begin
      Writeln('Usage: Calib.Sweep <sampleRoot> [--md <outFile>]');
      ExitCode := 2;
      Exit;
    end;
    GRoot := ParamStr(1);
    if (ParamCount >= 3) and (SameText(ParamStr(2), '--md')) then
      GMdPath := ParamStr(3);

    if not TDirectory.Exists(GRoot) then
    begin
      Writeln(ErrOutput, 'Sample root not found: ' + GRoot);
      ExitCode := 2;
      Exit;
    end;

    GNoStatic   := not TDirectory.Exists(TPath.Combine(GRoot, 'static'));
    GNoChanged  := not TDirectory.Exists(TPath.Combine(GRoot, 'changed'));
    GNoBoundary := not TDirectory.Exists(TPath.Combine(GRoot, 'boundary'));
    if GNoStatic and GNoChanged and GNoBoundary then
    begin
      Writeln(ErrOutput,
        'No static/changed/boundary sample dirs under: ' + GRoot);
      Writeln(ErrOutput, 'Record samples first with Calib.Record.dpr.');
      ExitCode := 2;
      Exit;
    end;

    GReport := SweepThresholds(GRoot);

    Writeln(GReport.Summary);
    Writeln;
    Writeln('--- docs/94 §6 results table ---');
    Writeln(GReport.MarkdownTable);

    if GMdPath <> '' then
    begin
      TFile.WriteAllText(GMdPath, GReport.MarkdownTable, TEncoding.UTF8);
      Writeln;
      Writeln('Markdown table written to: ' + GMdPath);
    end;

    ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, 'Sweep failed: ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
