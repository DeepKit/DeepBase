unit Main.Form;

{*******************************************************************************
  Main Form - 主窗体

  把三个计算单元串成一条可运行的演示链：
  样例数据 -> 统计摘要 / 趋势 / 分组聚合 -> 图表描述 -> 四种格式报表落盘。
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.IOUtils,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Analysis.Engine, Data.Module, Report.Generator, Chart.Builder;

type
  TMainForm = class(TForm)
    pnlTop: TPanel;
    btnAnalyze: TButton;
    btnChart: TButton;
    btnReport: TButton;
    mmoResult: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure btnAnalyzeClick(Sender: TObject);
    procedure btnChartClick(Sender: TObject);
    procedure btnReportClick(Sender: TObject);
  private
    FValues: TArray<Double>;
    FStats: TStatsSummary;
    FTrend: TTrendResult;
    FGroups: TGroupResults;
    FReportDir: string;
    FAnalyzed: Boolean;

    procedure EnsureAnalysis;
  end;

var
  MainForm: TMainForm;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

uses
  DeepBase.Logging;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  FReportDir := TPath.Combine(TPath.GetHomePath, 'DataAnalyzerReports');
  ForceDirectories(FReportDir);

  SetLength(FValues, Length(DataMod.Records));
  for I := 0 to High(FValues) do
    FValues[I] := DataMod.Records[I].Amount;
end;

procedure TMainForm.EnsureAnalysis;
begin
  if FAnalyzed then
    Exit;

  FStats := TAnalysisEngine.CalculateStats(FValues);
  FTrend := TAnalysisEngine.AnalyzeTrend(DataMod.Series);
  FGroups := TAnalysisEngine.GroupBy<TSampleRecord>(DataMod.Records,
    function(Rec: TSampleRecord): string
    begin
      Result := Rec.Region;
    end,
    function(Rec: TSampleRecord): Double
    begin
      Result := Rec.Amount;
    end);
  FAnalyzed := True;

  Logger.InfoFmt('Analysis ready: %d records, %d groups',
    [Length(FValues), Length(FGroups)]);
end;

procedure TMainForm.btnAnalyzeClick(Sender: TObject);
var
  Group: TGroupResult;
begin
  EnsureAnalysis;

  mmoResult.Lines.BeginUpdate;
  try
    mmoResult.Lines.Clear;
    mmoResult.Lines.Add('样本: ' + Length(FValues).ToString + ' 条 / 分组: ' +
      Length(FGroups).ToString + ' 个');
    mmoResult.Lines.Add('统计摘要');
    mmoResult.Lines.Add(FStats.ToString);
    mmoResult.Lines.Add('趋势分析');
    mmoResult.Lines.Add(FTrend.ToString);
    mmoResult.Lines.Add('分组聚合');
    for Group in FGroups do
      mmoResult.Lines.Add(Format('  %s: 条数=%d 合计=%.2f 均值=%.2f',
        [Group.GroupKey, Group.Count, Group.Sum, Group.Average]));
  finally
    mmoResult.Lines.EndUpdate;
  end;
end;

procedure TMainForm.btnChartClick(Sender: TObject);
var
  Chart: TChartBuilder;
  Cfg: TChartConfig;
  BaseName: string;
begin
  EnsureAnalysis;

  Chart := TChartBuilder.Create;
  try
    // Config 是记录型属性：Delphi 禁止 Obj.Prop.Field := x（E2064），必须整体读改写回
    Cfg := Chart.Config;
    Cfg.Title := 'Sample Series';
    Cfg.XAxisLabel := 'Date';
    Cfg.YAxisLabel := 'Value';
    Chart.Config := Cfg;
    Chart.ChartType := TChartBuilder.SuggestChartType(FStats);
    Chart.AddTimeSeriesSeries('Series', DataMod.Series);
    // SaveToFile 自己补 .txt，这里传不带扩展名的基名
    BaseName := TPath.Combine(FReportDir, 'chart');
    Chart.SaveToFile(BaseName);
    mmoResult.Lines.Text := Chart.GenerateDescription +
      '输出目录: ' + FReportDir;
  finally
    Chart.Free;
  end;
end;

procedure TMainForm.btnReportClick(Sender: TObject);
const
  Extensions: array[TReportFormat] of string = ('.txt', '.html', '.csv', '.json');
  FormatNames: array[TReportFormat] of string = ('Text', 'HTML', 'CSV', 'JSON');
var
  Report: TReportGenerator;
  Fmt: TReportFormat;
begin
  EnsureAnalysis;

  Report := TReportGenerator.Create;
  try
    Report.Title := 'Data Analyzer Sample Report';
    Report.Subtitle := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
    Report.Author := 'DataAnalyzer template';
    Report.AddStatsSection('统计摘要', FStats);
    Report.AddTrendSection('趋势分析', FTrend);
    Report.AddGroupSection('分组聚合', FGroups);

    // SaveToFile 不补扩展名，文件名由调用方给全
    for Fmt := Low(TReportFormat) to High(TReportFormat) do
      Report.SaveToFile(TPath.Combine(FReportDir, 'report' + Extensions[Fmt]), Fmt);

    mmoResult.Lines.Text := Format('已生成 %d 份报表到 %s',
      [Length(Extensions), FReportDir]) + sLineBreak +
      FormatNames[High(TReportFormat)] + ' 内容预览:' + sLineBreak +
      Report.Generate(rfText);
  finally
    Report.Free;
  end;
end;

end.
