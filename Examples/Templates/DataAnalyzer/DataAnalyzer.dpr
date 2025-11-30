program DataAnalyzer;

{$APPTYPE GUI}

{$R *.res}

uses
  Vcl.Forms,
  Main.Form in 'Main.Form.pas' {MainForm},
  Data.Module in 'Data.Module.pas' {DataMod: TDataModule},
  Analysis.Engine in 'Analysis.Engine.pas',
  Report.Generator in 'Report.Generator.pas',
  Chart.Builder in 'Chart.Builder.pas';

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Data Analyzer Template';
  Application.CreateForm(TDataMod, DataMod);
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
