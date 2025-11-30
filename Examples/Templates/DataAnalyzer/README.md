# Data Analyzer Application Template

基于 UniBase 框架的数据分析应用程序模板。

## 功能特性

- 统计分析（均值、中位数、标准差、四分位数等）
- 趋势分析（线性回归、R² 系数）
- 数据分组聚合
- 多格式报表生成（Text/HTML/CSV/JSON）
- 图表构建器框架

## 项目结构

```
DataAnalyzer/
├── DataAnalyzer.dpr      # 项目主文件
├── Main.Form.pas/dfm     # 主窗体
├── Data.Module.pas/dfm   # 数据访问模块
├── Analysis.Engine.pas   # 统计分析引擎
├── Report.Generator.pas  # 报表生成器
├── Chart.Builder.pas     # 图表构建器（存根）
└── README.md             # 本文件
```

## 核心组件

### Analysis.Engine

提供全面的统计分析功能：

```pascal
// 计算完整统计摘要
var Stats := TAnalysisEngine.CalculateStats(Values);
// Stats.Mean, Stats.Median, Stats.StdDev, Stats.Q1, Stats.Q3...

// 趋势分析
var Trend := TAnalysisEngine.AnalyzeTrend(TimeSeries);
// Trend.Slope, Trend.RSquared, Trend.Trend ('Up'/'Down'/'Stable')

// 移动平均
var MA := TAnalysisEngine.MovingAverage(Values, 7);  // 7日移动平均

// 相关性分析
var Corr := TAnalysisEngine.Correlation(X, Y);  // -1 到 1
```

### Report.Generator

多格式报表生成：

```pascal
var Report := TReportGenerator.Create;
try
  Report.Title := 'Sales Analysis Report';
  Report.AddStatsSection('Summary Statistics', Stats);
  Report.AddTrendSection('Trend Analysis', Trend);
  Report.AddGroupSection('By Region', GroupResults);
  
  // 生成不同格式
  Report.SaveToFile('report.html', rfHTML);
  Report.SaveToFile('report.csv', rfCSV);
  Report.SaveToFile('report.json', rfJSON);
finally
  Report.Free;
end;
```

### Chart.Builder

图表构建器框架（需集成实际图表组件）：

```pascal
var Chart := TChartBuilder.Create;
try
  Chart.ChartType := ctLine;
  Chart.Config.Title := 'Monthly Sales';
  Chart.AddSeries('2024', SalesData2024);
  Chart.AddSeries('2023', SalesData2023);
  Chart.SaveToFile('sales_chart');
finally
  Chart.Free;
end;
```

## UniBase 功能演示

### 日志记录
```pascal
Log.Info('Analysis started: %d records', [RecordCount]);
Log.Debug('Statistics: %s', [Stats.ToString]);
```

### 配置管理
```pascal
// 保存用户偏好
UniBase.Config.SetConfig('report.defaultFormat', 'HTML');
UniBase.Config.SetConfigInt('analysis.defaultWindow', 30);
```

### 性能基准
```pascal
uses UniBase.Benchmark;

var ElapsedMs := MeasureTime(procedure
begin
  Stats := TAnalysisEngine.CalculateStats(LargeDataset);
end);
Log.Info('Analysis completed in %.2f ms', [ElapsedMs]);
```

## 扩展指南

### 添加新的统计函数

在 `Analysis.Engine.pas` 中添加：

```pascal
class function TAnalysisEngine.Skewness(const Values: TArray<Double>): Double;
var
  M, S: Double;
  N: Integer;
  Sum: Double;
  V: Double;
begin
  N := Length(Values);
  if N < 3 then Exit(0);
  
  M := Mean(Values);
  S := StdDev(Values);
  if S = 0 then Exit(0);
  
  Sum := 0;
  for V in Values do
    Sum := Sum + Power((V - M) / S, 3);
  
  Result := (N / ((N-1) * (N-2))) * Sum;
end;
```

### 集成图表组件

将 `Chart.Builder.pas` 中的存根实现替换为实际图表组件：

```pascal
// 使用 TeeChart
uses VCLTee.Chart, VCLTee.Series;

procedure TChartBuilder.RenderToChart(Chart: TChart);
var
  Series: TChartSeries;
  LineSeries: TLineSeries;
begin
  Chart.Title.Text.Text := FConfig.Title;
  
  for Series in FSeries do
  begin
    LineSeries := TLineSeries.Create(Chart);
    LineSeries.Title := Series.Name;
    LineSeries.AddArray(Series.Values);
    Chart.AddSeries(LineSeries);
  end;
end;
```

## 依赖

- UniBase Framework
- FireDAC (用于数据访问)
- VCL

## 许可

MIT License
