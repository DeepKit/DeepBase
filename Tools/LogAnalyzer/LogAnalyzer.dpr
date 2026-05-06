{ ============================================================================
  LogAnalyzer - UniBase 日志分析工具

  版本: 1.0
  说明: 分析和可视化 UniBase 日志数据
  功能:
    - 多数据库日志查看
    - 时间范围和级别过滤
    - 关键词搜索
    - 统计图表
    - 导出功能 (CSV/JSON/HTML)
  ============================================================================ }

program LogAnalyzer;

uses
  Vcl.Forms,
  LogAnalyzer.MainForm in 'LogAnalyzer.MainForm.pas' {frmLogAnalyzer},
  LogAnalyzer.Data in 'LogAnalyzer.Data.pas',
  LogAnalyzer.Stats in 'LogAnalyzer.Stats.pas',
  LogAnalyzer.Export in 'LogAnalyzer.Export.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'UniBase 日志分析器';
  Application.CreateForm(TfrmLogAnalyzer, frmLogAnalyzer);
  Application.Run;
end.
