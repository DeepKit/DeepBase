unit Data.Module;

{*******************************************************************************
  Data Module - 样例数据模块

  为分析引擎提供确定性的内存样例数据：一组按区域分组的金额 + 一条日度时间序列。

  为什么这里没有数据库：Analysis.Engine / Report.Generator / Chart.Builder 的输入
  全部是内存数组（TArray<Double>、TTimeSeriesData），本模板在仓内也没有对应的表
  结构。挂一个 FireDAC 连接却指向不存在的库，只会让模板跑不起来。
*******************************************************************************}

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Classes,
  System.Math,
  Analysis.Engine;

type
  /// <summary>
  /// 一条待分析记录：按 Region 分组、对 Amount 聚合
  /// </summary>
  TSampleRecord = record
    Region: string;
    Amount: Double;
  end;

  /// <summary>
  /// 模板的样例数据源
  /// </summary>
  TDataMod = class(TDataModule)
    procedure DataModuleCreate(Sender: TObject);
  private
    FRecords: TArray<TSampleRecord>;
    FSeries: TTimeSeriesData;
  public
    property Records: TArray<TSampleRecord> read FRecords;
    property Series: TTimeSeriesData read FSeries;
  end;

var
  DataMod: TDataMod;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

const
  Regions: array[0..3] of string = ('华东', '华北', '华南', '西南');
  RecordCount = 48;
  SeriesPointCount = 60;
  SeriesBase = 100.0;   // 起点水位
  SeriesSlope = 0.8;    // 每日趋势增量
  SeriesWaveAmp = 15.0; // 周周期振幅
  SeriesWaveDays = 7.0;

procedure TDataMod.DataModuleCreate(Sender: TObject);
var
  I: Integer;
  StartDate: TDateTime;
begin
  // 金额用取模而不是随机数：模板要能核对报表，每次运行必须得到同一组统计值。
  SetLength(FRecords, RecordCount);
  for I := 0 to High(FRecords) do
  begin
    FRecords[I].Region := Regions[I mod Length(Regions)];
    FRecords[I].Amount := 500 + (I * 137) mod 4000;
  end;

  SetLength(FSeries, SeriesPointCount);
  StartDate := EncodeDate(2026, 1, 1);
  for I := 0 to High(FSeries) do
  begin
    FSeries[I].Timestamp := IncDay(StartDate, I);
    FSeries[I].Value := SeriesBase + SeriesSlope * I +
      SeriesWaveAmp * Sin((I + 1) / SeriesWaveDays * Pi);
    FSeries[I].PointLabel := FormatDateTime('yyyy-mm-dd', FSeries[I].Timestamp);
  end;
end;

end.
