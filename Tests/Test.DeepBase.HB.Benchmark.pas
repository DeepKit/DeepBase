{ ============================================================================
  Test.DeepBase.HB.Benchmark - HB Touchpoint Write Latency Benchmark (Gate #7)

  Version: 1.0 (Delphi 13.1 on Win64 / DUnitX)
  Description: Benchmark test for 31.hb-test v1.1 Gate #7:
               100,000 row interactions scenario with aggregated telemetry writes.
               Enforces P95 write latency <= 2.0 ms threshold.
               Complies with WO-20260904-001 Task C3.
  ============================================================================ }

unit Test.DeepBase.HB.Benchmark;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  System.Generics.Collections,
  System.Generics.Defaults,
  DUnitX.TestFramework,
  DeepBase.HB.Touchpoint.Types,
  DeepBase.HB.Touchpoint.Engine;

type
  [TestFixture]
  TTestHbBenchmark = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure BenchmarkTouchpointAggregation_100kRows_LatencyP95Under2ms;
  end;

implementation

procedure TTestHbBenchmark.Setup;
begin
  THbTouchpointEngine.Instance.Reset;
end;

procedure TTestHbBenchmark.TearDown;
begin
  THbTouchpointEngine.Instance.Reset;
end;

procedure TTestHbBenchmark.BenchmarkTouchpointAggregation_100kRows_LatencyP95Under2ms;
const
  TOTAL_INTERACTIONS = 100000;
  SAMPLE_COUNT = 1000; // 抽取 1000 个细粒度样本点统计精确延迟分布
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

    // 预热 (Warm-up)
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
      begin
        Engine.RecordGridInteraction('tp_grid_benchmark', 'frm_benchmark', 'RowSelect', True);
      end;
    end;

    Engine.FlushGridAggregations;
    TotalStopwatch.Stop;
    TotalElapsedMs := TotalStopwatch.Elapsed.TotalMilliseconds;

    // 统计分位数
    LatenciesMs.Sort;
    Assert.IsTrue(LatenciesMs.Count > 0, 'Must have recorded latency samples');

    P50 := LatenciesMs[Round((LatenciesMs.Count - 1) * 0.50)];
    P90 := LatenciesMs[Round((LatenciesMs.Count - 1) * 0.90)];
    P95Index := Round((LatenciesMs.Count - 1) * 0.95);
    P95 := LatenciesMs[P95Index];
    P99 := LatenciesMs[Round((LatenciesMs.Count - 1) * 0.99)];
    MaxVal := LatenciesMs[LatenciesMs.Count - 1];
    AvgMs := TotalElapsedMs / TOTAL_INTERACTIONS;

    // 输出基准数据
    System.Writeln('');
    System.Writeln('================================================================');
    System.Writeln('  HB Gate #7: Touchpoint Evidence Write Latency Benchmark');
    System.Writeln('================================================================');
    System.Writeln(Format('  Total Interactions : %d', [TOTAL_INTERACTIONS]));
    System.Writeln(Format('  Total Time         : %.2f ms', [TotalElapsedMs]));
    System.Writeln(Format('  Average Write Time : %.4f ms (%.2f us)', [AvgMs, AvgMs * 1000]));
    System.Writeln(Format('  Latency P50        : %.4f ms', [P50]));
    System.Writeln(Format('  Latency P90        : %.4f ms', [P90]));
    System.Writeln(Format('  Latency P95        : %.4f ms [Threshold <= 2.0 ms]', [P95]));
    System.Writeln(Format('  Latency P99        : %.4f ms', [P99]));
    System.Writeln(Format('  Latency Max        : %.4f ms', [MaxVal]));
    System.Writeln(Format('  Buffered Evidences : %d', [Engine.GetBufferedCount]));
    System.Writeln('================================================================');

    // 硬门禁断言：P95 写入延迟必须 <= 2.0 ms
    Assert.IsTrue(P95 <= 2.0, Format('HB Gate #7 VIOLATION: Latency P95 (%.4f ms) exceeds threshold 2.0 ms', [P95]));
    // 总量验证
    Assert.AreEqual(TOTAL_INTERACTIONS div 50, Engine.GetBufferedCount);
  finally
    LatenciesMs.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestHbBenchmark);

end.
