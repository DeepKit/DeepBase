unit Chart.Builder;

{*******************************************************************************
  Data Analyzer Template - Chart Builder
  
  Provides chart generation capabilities. This is a stub implementation
  that can be extended with actual charting components (TeeChart, etc.).
  
  Features demonstrated:
  - Chart type definitions
  - Data series management
  - Export capabilities
*******************************************************************************}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Graphics,
  Analysis.Engine;

type
  TChartType = (
    ctLine,
    ctBar,
    ctPie,
    ctArea,
    ctScatter
  );

  /// <summary>
  /// Data series for charts
  /// </summary>
  TChartSeries = record
    Name: string;
    Values: TArray<Double>;
    Labels: TArray<string>;
    Color: TColor;
  end;

  /// <summary>
  /// Chart configuration
  /// </summary>
  TChartConfig = record
    Title: string;
    XAxisLabel: string;
    YAxisLabel: string;
    ShowLegend: Boolean;
    ShowGrid: Boolean;
    Width: Integer;
    Height: Integer;
  end;

  /// <summary>
  /// Chart builder class
  /// </summary>
  TChartBuilder = class
  private
    FChartType: TChartType;
    FConfig: TChartConfig;
    FSeries: TList<TChartSeries>;
  public
    constructor Create;
    destructor Destroy; override;
    
    // Configuration
    property ChartType: TChartType read FChartType write FChartType;
    property Config: TChartConfig read FConfig write FConfig;
    
    // Series management
    procedure AddSeries(const Name: string; const Values: TArray<Double>;
      const Labels: TArray<string> = nil; Color: TColor = clBlue);
    procedure AddTimeSeriesSeries(const Name: string; 
      const Data: TTimeSeriesData; Color: TColor = clBlue);
    procedure ClearSeries;
    
    // Generation (stub - would need actual chart component)
    function GenerateDescription: string;
    procedure SaveToFile(const FileName: string);
    
    // Helper
    class function SuggestChartType(const Stats: TStatsSummary): TChartType;
  end;

implementation

uses
  System.IOUtils,
  UniBase.Logging;

{ TChartBuilder }

constructor TChartBuilder.Create;
begin
  inherited;
  FSeries := TList<TChartSeries>.Create;
  
  // Default configuration
  FChartType := ctLine;
  FConfig.Title := 'Chart';
  FConfig.XAxisLabel := 'X';
  FConfig.YAxisLabel := 'Y';
  FConfig.ShowLegend := True;
  FConfig.ShowGrid := True;
  FConfig.Width := 800;
  FConfig.Height := 600;
end;

destructor TChartBuilder.Destroy;
begin
  FSeries.Free;
  inherited;
end;

procedure TChartBuilder.AddSeries(const Name: string; 
  const Values: TArray<Double>;
  const Labels: TArray<string>;
  Color: TColor);
var
  Series: TChartSeries;
begin
  Series.Name := Name;
  Series.Values := Values;
  Series.Labels := Labels;
  Series.Color := Color;
  FSeries.Add(Series);
end;

procedure TChartBuilder.AddTimeSeriesSeries(const Name: string;
  const Data: TTimeSeriesData; Color: TColor);
var
  Values: TArray<Double>;
  Labels: TArray<string>;
  I: Integer;
begin
  SetLength(Values, Length(Data));
  SetLength(Labels, Length(Data));
  
  for I := 0 to High(Data) do
  begin
    Values[I] := Data[I].Value;
    if Data[I].Label <> '' then
      Labels[I] := Data[I].Label
    else
      Labels[I] := FormatDateTime('yyyy-mm-dd', Data[I].Timestamp);
  end;
  
  AddSeries(Name, Values, Labels, Color);
end;

procedure TChartBuilder.ClearSeries;
begin
  FSeries.Clear;
end;

function TChartBuilder.GenerateDescription: string;
var
  SB: TStringBuilder;
  Series: TChartSeries;
  ChartTypeStr: string;
begin
  case FChartType of
    ctLine: ChartTypeStr := 'Line';
    ctBar: ChartTypeStr := 'Bar';
    ctPie: ChartTypeStr := 'Pie';
    ctArea: ChartTypeStr := 'Area';
    ctScatter: ChartTypeStr := 'Scatter';
  end;
  
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('Chart Description');
    SB.AppendLine('=================');
    SB.AppendLine('Title: ' + FConfig.Title);
    SB.AppendLine('Type: ' + ChartTypeStr);
    SB.AppendLine(Format('Size: %d x %d', [FConfig.Width, FConfig.Height]));
    SB.AppendLine('X-Axis: ' + FConfig.XAxisLabel);
    SB.AppendLine('Y-Axis: ' + FConfig.YAxisLabel);
    SB.AppendLine;
    SB.AppendLine('Series:');
    
    for Series in FSeries do
    begin
      SB.AppendLine(Format('  - %s: %d data points', 
        [Series.Name, Length(Series.Values)]));
      if Length(Series.Values) > 0 then
      begin
        SB.AppendLine(Format('    Min: %.2f, Max: %.2f',
          [TAnalysisEngine.Min(Series.Values), 
           TAnalysisEngine.Max(Series.Values)]));
      end;
    end;
    
    SB.AppendLine;
    SB.AppendLine('Note: This is a stub implementation.');
    SB.AppendLine('Integrate with TeeChart or similar for actual charts.');
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

procedure TChartBuilder.SaveToFile(const FileName: string);
begin
  // Stub implementation - save description
  TFile.WriteAllText(FileName + '.txt', GenerateDescription, TEncoding.UTF8);
  Log.Info('Chart description saved: %s.txt', [FileName]);
  
  // In a real implementation, this would save an image file
  // using TeeChart or similar component
end;

class function TChartBuilder.SuggestChartType(const Stats: TStatsSummary): TChartType;
begin
  // Simple heuristic for suggesting chart type
  if Stats.Count <= 5 then
    Result := ctPie  // Small datasets work well with pie charts
  else if Stats.Count <= 12 then
    Result := ctBar  // Medium datasets with bar charts
  else
    Result := ctLine;  // Larger datasets with line charts
end;

end.
