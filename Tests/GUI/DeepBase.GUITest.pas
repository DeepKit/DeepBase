{ ============================================================================
  DeepBase.GUITest - GUI 自动化测试框�?
  
  版本: 1.0
  说明: 提供完整�?GUI 自动化测试基础设施
  功能:
    - 测试生命周期管理
    - 截图比对测试
    - 交互流程测试
    - 视觉回归测试
    - 测试报告生成
  ============================================================================ }

unit DeepBase.GUITest;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  System.Math,
  System.StrUtils,
  System.Generics.Collections,
  System.TypInfo,
  Winapi.Windows,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Imaging.pngimage,
  DeepBase.TestHelper;

{$IFDEF USE_DUNITX}
const
  DUNITX_AVAILABLE = True;
{$ELSE}
const
  DUNITX_AVAILABLE = False;
{$ENDIF}

type
  /// <summary>
  /// 时间戳辅�?
  /// </summary>
  TStopwatch = record
  private
    FStartTime: Int64;
    FFrequency: Int64;
    FRunning: Boolean;
  public
    procedure Start;
    procedure Stop;
    procedure Reset;
    function ElapsedMilliseconds: Int64;
    class function StartNew: TStopwatch; static;
  end;
  /// <summary>
  /// 截图比较结果
  /// </summary>
  TScreenshotCompareResult = record
    IsMatch: Boolean;
    DifferencePercent: Double;
    DifferentPixels: Integer;
    TotalPixels: Integer;
    DiffImagePath: string;
    
    procedure Clear;
  end;
  
  /// <summary>
  /// GUI 测试步骤记录
  /// </summary>
  TGUITestStep = record
    StepNumber: Integer;
    Description: string;
    Action: string;
    ControlName: string;
    Expected: string;
    Actual: string;
    Success: Boolean;
    ScreenshotPath: string;
    TimeMs: Int64;
  end;
  
  TGUITestStepArray = TArray<TGUITestStep>;
  
  /// <summary>
  /// GUI 测试结果
  /// </summary>
  TGUITestResult = record
    TestName: string;
    FormClass: string;
    StartTime: TDateTime;
    EndTime: TDateTime;
    DurationMs: Int64;
    Success: Boolean;
    Steps: TGUITestStepArray;
    ErrorMessage: string;
    BaselineScreenshot: string;
    FinalScreenshot: string;
  end;
  
  /// <summary>
  /// 截图比较选项
  /// </summary>
  TScreenshotCompareOptions = record
    Tolerance: Double;         // 颜色容差 (0-255)
    IgnoreRegions: TArray<TRect>;  // 忽略区域
    HighlightDiff: Boolean;    // 高亮差异
    DiffColor: TColor;         // 差异高亮颜色
    
    class function Default: TScreenshotCompareOptions; static;
  end;
  
  /// <summary>
  /// GUI 测试配置
  /// </summary>
  TGUITestConfig = record
    BaselinesPath: string;     // 基准截图路径
    OutputPath: string;        // 输出路径
    AutoCapture: Boolean;      // 自动截图
    CaptureOnFailure: Boolean; // 失败时截图
    StepDelay: Integer;        // 步骤间延时(ms)
    ScreenshotFormat: string;  // 截图格式 (png/bmp)
    FormLeft: Integer;         // 测试窗体 Left
    FormTop: Integer;          // 测试窗体 Top
    CompareOptions: TScreenshotCompareOptions;

    class function Default: TGUITestConfig; static;
  end;
  
  /// <summary>
  /// GUI 测试上下�?
  /// </summary>
  TGUITestContext = class
  private
    FTestName: string;
    FFormClass: string;
    FConfig: TGUITestConfig;
    FSteps: TList<TGUITestStep>;
    FCurrentStepNumber: Integer;
    FStartTime: TDateTime;
    FStopwatch: TStopwatch;
    FLastActionTime: Int64;
    FSuccess: Boolean;
    FErrorMessage: string;
    
  public
    constructor Create(const ATestName: string; AConfig: TGUITestConfig);
    destructor Destroy; override;
    
    /// <summary>记录步骤开�?/summary>
    procedure BeginStep(const Description: string);
    
    /// <summary>记录步骤完成</summary>
    procedure EndStep(Success: Boolean; const Expected, Actual: string);
    
    /// <summary>记录控件操作</summary>
    procedure LogAction(const Action, ControlName: string);
    
    /// <summary>添加截图</summary>
    procedure AddScreenshot(const Path: string);
    
    /// <summary>设置错误</summary>
    procedure SetError(const Msg: string);
    
    /// <summary>获取结果</summary>
    function GetResult: TGUITestResult;
    
    property TestName: string read FTestName;
    property FormClass: string read FFormClass write FFormClass;
    property Config: TGUITestConfig read FConfig;
    property Success: Boolean read FSuccess;
    property CurrentStepNumber: Integer read FCurrentStepNumber;
  end;
  
  /// <summary>
  /// 截图比较�?
  /// </summary>
  TScreenshotComparer = class
  private
    class function ColorDistance(C1, C2: TColor): Double;
    class function IsInIgnoreRegion(X, Y: Integer; 
      const Regions: TArray<TRect>): Boolean;
      
  public
    /// <summary>比较两张图片</summary>
    class function Compare(const BaselinePath, ActualPath: string;
      Options: TScreenshotCompareOptions): TScreenshotCompareResult; overload;
      
    class function Compare(Baseline, Actual: TBitmap;
      Options: TScreenshotCompareOptions): TScreenshotCompareResult; overload;
    
    /// <summary>生成差异�?/summary>
    class function GenerateDiffImage(Baseline, Actual: TBitmap;
      Options: TScreenshotCompareOptions): TBitmap;
  end;
  
  /// <summary>
  /// GUI 测试报告生成�?
  /// </summary>
  TGUITestReporter = class
  public
    class procedure GenerateHTMLReport(const Results: TArray<TGUITestResult>;
      const OutputPath: string);
    class procedure GenerateJSONReport(const Results: TArray<TGUITestResult>;
      const OutputPath: string);
    class procedure GenerateSummary(const Results: TArray<TGUITestResult>;
      out Passed, Failed, Total: Integer);
  end;
  
  /// <summary>
  /// GUI 测试基类 - 可独立使用或�?DUnitX 集成
  /// </summary>
  TGUITestBase = class
  private
    FContext: TGUITestContext;
    FForm: TForm;
    FResults: TList<TGUITestResult>;
    FConfig: TGUITestConfig;
    
  protected
    /// <summary>创建测试窗体 - 子类重写</summary>
    function CreateTestForm: TForm; virtual; abstract;
    
    /// <summary>销毁测试窗�?/summary>
    procedure DestroyTestForm; virtual;
    
    /// <summary>当前测试窗体</summary>
    property Form: TForm read FForm;
    
    /// <summary>测试上下�?/summary>
    property Context: TGUITestContext read FContext;
    
    /// <summary>测试配置</summary>
    property Config: TGUITestConfig read FConfig write FConfig;
    
    // ========== 测试辅助方法 ==========
    
    /// <summary>模拟点击控件</summary>
    procedure Click(const ControlName: string); overload;
    procedure Click(AControl: TControl); overload;
    
    /// <summary>模拟双击控件</summary>
    procedure DoubleClick(const ControlName: string); overload;
    procedure DoubleClick(AControl: TControl); overload;
    
    /// <summary>模拟输入文本</summary>
    procedure Input(const ControlName, Text: string); overload;
    procedure Input(AControl: TControl; const Text: string); overload;
    
    /// <summary>模拟选择</summary>
    procedure Select(const ControlName: string; Index: Integer); overload;
    procedure Select(const ControlName, Text: string); overload;
    
    /// <summary>模拟勾�?/summary>
    procedure Check(const ControlName: string; Checked: Boolean);
    
    /// <summary>模拟按键</summary>
    procedure PressKey(Key: Word; Shift: TShiftState = []);
    
    /// <summary>等待</summary>
    procedure Wait(Ms: Integer);
    
    /// <summary>处理消息</summary>
    procedure ProcessMessages;
    
    // ========== 断言方法 ==========
    
    /// <summary>断言控件可见</summary>
    procedure AssertVisible(const ControlName: string; const Msg: string = '');
    
    /// <summary>断言控件不可�?/summary>
    procedure AssertNotVisible(const ControlName: string; const Msg: string = '');
    
    /// <summary>断言控件启用</summary>
    procedure AssertEnabled(const ControlName: string; const Msg: string = '');
    
    /// <summary>断言控件禁用</summary>
    procedure AssertDisabled(const ControlName: string; const Msg: string = '');
    
    /// <summary>断言控件文本</summary>
    procedure AssertText(const ControlName, Expected: string; const Msg: string = '');
    
    /// <summary>断言控件�?/summary>
    procedure AssertValue(const ControlName, Expected: string; const Msg: string = '');
    
    /// <summary>断言控件存在</summary>
    procedure AssertControlExists(const ControlName: string; const Msg: string = '');
    
    /// <summary>断言控件焦点</summary>
    procedure AssertFocused(const ControlName: string; const Msg: string = '');
    
    /// <summary>断言窗体标题</summary>
    procedure AssertCaption(const Expected: string; const Msg: string = '');
    
    // ========== 截图方法 ==========
    
    /// <summary>捕获当前截图</summary>
    function CaptureScreenshot(const Suffix: string = ''): string;
    
    /// <summary>保存为基准截�?/summary>
    procedure SaveBaseline(const Name: string);
    
    /// <summary>与基准截图比�?/summary>
    function CompareWithBaseline(const Name: string): TScreenshotCompareResult;
    
    /// <summary>断言截图匹配</summary>
    procedure AssertScreenshotMatch(const BaselineName: string; 
      MaxDiffPercent: Double = 0.1; const Msg: string = '');
    
    // ========== 步骤记录 ==========
    
    /// <summary>开始步�?/summary>
    procedure Step(const Description: string);
    
    /// <summary>验证步骤</summary>
    procedure Verify(Condition: Boolean; const Expected, Actual: string);
    
  public
    /// <summary>Setup - 在每个测试之前调�?/summary>
    procedure Setup; virtual;
    
    /// <summary>TearDown - 在每个测试之后调�?/summary>
    procedure TearDown; virtual;
    
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>获取所有测试结�?/summary>
    function GetAllResults: TArray<TGUITestResult>;
  end;
  
  /// <summary>
  /// GUI 测试运行�?
  /// </summary>
  TGUITestRunner = class
  private
    FConfig: TGUITestConfig;
    FResults: TList<TGUITestResult>;
    
  public
    constructor Create(AConfig: TGUITestConfig);
    destructor Destroy; override;
    
    /// <summary>运行测试�?/summary>
    procedure RunTests(TestClass: TClass);
    
    /// <summary>运行单个测试</summary>
    procedure RunTest(Test: TGUITestBase; const MethodName: string);
    
    /// <summary>生成报告</summary>
    procedure GenerateReport(const OutputPath: string);
    
    property Results: TList<TGUITestResult> read FResults;
    property Config: TGUITestConfig read FConfig write FConfig;
  end;

implementation

{ TScreenshotCompareResult }

procedure TScreenshotCompareResult.Clear;
begin
  IsMatch := False;
  DifferencePercent := 0;
  DifferentPixels := 0;
  TotalPixels := 0;
  DiffImagePath := '';
end;

{ TScreenshotCompareOptions }

class function TScreenshotCompareOptions.Default: TScreenshotCompareOptions;
begin
  Result.Tolerance := 5.0;
  SetLength(Result.IgnoreRegions, 0);
  Result.HighlightDiff := True;
  Result.DiffColor := clRed;
end;

{ TGUITestConfig }

class function TGUITestConfig.Default: TGUITestConfig;
begin
  Result.BaselinesPath := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'Baselines');
  Result.OutputPath := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'TestOutput');
  Result.AutoCapture := True;
  Result.CaptureOnFailure := True;
  Result.StepDelay := 50;
  Result.ScreenshotFormat := 'png';
  Result.FormLeft := 100;
  Result.FormTop := 300;
  Result.CompareOptions := TScreenshotCompareOptions.Default;
end;

{ TStopwatch }

procedure TStopwatch.Start;
begin
  QueryPerformanceFrequency(FFrequency);
  QueryPerformanceCounter(FStartTime);
  FRunning := True;
end;

procedure TStopwatch.Stop;
begin
  FRunning := False;
end;

procedure TStopwatch.Reset;
begin
  FStartTime := 0;
  FRunning := False;
end;

function TStopwatch.ElapsedMilliseconds: Int64;
var
  EndTime: Int64;
begin
  if FFrequency = 0 then
    Exit(0);
    
  QueryPerformanceCounter(EndTime);
  Result := ((EndTime - FStartTime) * 1000) div FFrequency;
end;

class function TStopwatch.StartNew: TStopwatch;
begin
  Result.Reset;
  Result.Start;
end;

{ TGUITestContext }

constructor TGUITestContext.Create(const ATestName: string; AConfig: TGUITestConfig);
begin
  inherited Create;
  FTestName := ATestName;
  FConfig := AConfig;
  FSteps := TList<TGUITestStep>.Create;
  FCurrentStepNumber := 0;
  FStartTime := Now;
  FStopwatch := TStopwatch.StartNew;
  FSuccess := True;
  FErrorMessage := '';
end;

destructor TGUITestContext.Destroy;
begin
  FSteps.Free;
  inherited;
end;

procedure TGUITestContext.BeginStep(const Description: string);
var
  Step: TGUITestStep;
begin
  Inc(FCurrentStepNumber);
  
  Step.StepNumber := FCurrentStepNumber;
  Step.Description := Description;
  Step.Action := '';
  Step.ControlName := '';
  Step.Expected := '';
  Step.Actual := '';
  Step.Success := True;
  Step.ScreenshotPath := '';
  Step.TimeMs := FStopwatch.ElapsedMilliseconds;
  
  FSteps.Add(Step);
  FLastActionTime := Step.TimeMs;
end;

procedure TGUITestContext.EndStep(Success: Boolean; const Expected, Actual: string);
var
  Step: TGUITestStep;
begin
  if FSteps.Count = 0 then
    Exit;
    
  Step := FSteps[FSteps.Count - 1];
  Step.Success := Success;
  Step.Expected := Expected;
  Step.Actual := Actual;
  Step.TimeMs := FStopwatch.ElapsedMilliseconds - FLastActionTime;
  FSteps[FSteps.Count - 1] := Step;
  
  if not Success then
    FSuccess := False;
end;

procedure TGUITestContext.LogAction(const Action, ControlName: string);
var
  Step: TGUITestStep;
begin
  if FSteps.Count = 0 then
    Exit;
    
  Step := FSteps[FSteps.Count - 1];
  Step.Action := Action;
  Step.ControlName := ControlName;
  FSteps[FSteps.Count - 1] := Step;
end;

procedure TGUITestContext.AddScreenshot(const Path: string);
var
  Step: TGUITestStep;
begin
  if FSteps.Count = 0 then
    Exit;
    
  Step := FSteps[FSteps.Count - 1];
  Step.ScreenshotPath := Path;
  FSteps[FSteps.Count - 1] := Step;
end;

procedure TGUITestContext.SetError(const Msg: string);
begin
  FSuccess := False;
  FErrorMessage := Msg;
end;

function TGUITestContext.GetResult: TGUITestResult;
begin
  Result.TestName := FTestName;
  Result.FormClass := FFormClass;
  Result.StartTime := FStartTime;
  Result.EndTime := Now;
  Result.DurationMs := FStopwatch.ElapsedMilliseconds;
  Result.Success := FSuccess;
  Result.Steps := FSteps.ToArray;
  Result.ErrorMessage := FErrorMessage;
  Result.BaselineScreenshot := '';
  Result.FinalScreenshot := '';
end;

{ TScreenshotComparer }

class function TScreenshotComparer.ColorDistance(C1, C2: TColor): Double;
var
  R1, G1, B1, R2, G2, B2: Byte;
begin
  R1 := GetRValue(C1);
  G1 := GetGValue(C1);
  B1 := GetBValue(C1);
  R2 := GetRValue(C2);
  G2 := GetGValue(C2);
  B2 := GetBValue(C2);
  
  Result := Sqrt(Sqr(R1 - R2) + Sqr(G1 - G2) + Sqr(B1 - B2));
end;

class function TScreenshotComparer.IsInIgnoreRegion(X, Y: Integer;
  const Regions: TArray<TRect>): Boolean;
var
  R: TRect;
begin
  Result := False;
  for R in Regions do
  begin
    if PtInRect(R, Point(X, Y)) then
      Exit(True);
  end;
end;

class function TScreenshotComparer.Compare(const BaselinePath, ActualPath: string;
  Options: TScreenshotCompareOptions): TScreenshotCompareResult;
var
  Baseline, Actual: TBitmap;
  PNG: TPngImage;
begin
  Result.Clear;
  
  if not TFile.Exists(BaselinePath) then
  begin
    Result.IsMatch := False;
    Exit;
  end;
  
  if not TFile.Exists(ActualPath) then
  begin
    Result.IsMatch := False;
    Exit;
  end;
  
  Baseline := TBitmap.Create;
  Actual := TBitmap.Create;
  try
    // 加载基准�?
    if LowerCase(TPath.GetExtension(BaselinePath)) = '.png' then
    begin
      PNG := TPngImage.Create;
      try
        PNG.LoadFromFile(BaselinePath);
        Baseline.Assign(PNG);
      finally
        PNG.Free;
      end;
    end
    else
      Baseline.LoadFromFile(BaselinePath);
    
    // 加载实际�?
    if LowerCase(TPath.GetExtension(ActualPath)) = '.png' then
    begin
      PNG := TPngImage.Create;
      try
        PNG.LoadFromFile(ActualPath);
        Actual.Assign(PNG);
      finally
        PNG.Free;
      end;
    end
    else
      Actual.LoadFromFile(ActualPath);
    
    Result := Compare(Baseline, Actual, Options);
  finally
    Baseline.Free;
    Actual.Free;
  end;
end;

class function TScreenshotComparer.Compare(Baseline, Actual: TBitmap;
  Options: TScreenshotCompareOptions): TScreenshotCompareResult;
var
  X, Y: Integer;
  C1, C2: TColor;
  Distance: Double;
begin
  Result.Clear;
  
  // 尺寸不匹�?
  if (Baseline.Width <> Actual.Width) or (Baseline.Height <> Actual.Height) then
  begin
    Result.IsMatch := False;
    Result.DifferencePercent := 100;
    Exit;
  end;
  
  Result.TotalPixels := Baseline.Width * Baseline.Height;
  Result.DifferentPixels := 0;
  
  Baseline.PixelFormat := pf24bit;
  Actual.PixelFormat := pf24bit;
  
  for Y := 0 to Baseline.Height - 1 do
  begin
    for X := 0 to Baseline.Width - 1 do
    begin
      // 检查是否在忽略区域
      if IsInIgnoreRegion(X, Y, Options.IgnoreRegions) then
        Continue;
        
      C1 := Baseline.Canvas.Pixels[X, Y];
      C2 := Actual.Canvas.Pixels[X, Y];
      
      Distance := ColorDistance(C1, C2);
      if Distance > Options.Tolerance then
        Inc(Result.DifferentPixels);
    end;
  end;
  
  if Result.TotalPixels > 0 then
    Result.DifferencePercent := (Result.DifferentPixels / Result.TotalPixels) * 100
  else
    Result.DifferencePercent := 0;
    
  Result.IsMatch := Result.DifferencePercent < 0.1; // 默认 0.1% 阈�?
end;

class function TScreenshotComparer.GenerateDiffImage(Baseline, Actual: TBitmap;
  Options: TScreenshotCompareOptions): TBitmap;
var
  X, Y: Integer;
  C1, C2: TColor;
  Distance: Double;
begin
  Result := TBitmap.Create;
  Result.SetSize(Max(Baseline.Width, Actual.Width), Max(Baseline.Height, Actual.Height));
  Result.PixelFormat := pf24bit;
  
  // 复制实际图像
  Result.Canvas.Draw(0, 0, Actual);
  
  if not Options.HighlightDiff then
    Exit;
  
  Baseline.PixelFormat := pf24bit;
  Actual.PixelFormat := pf24bit;
  
  for Y := 0 to Min(Baseline.Height, Actual.Height) - 1 do
  begin
    for X := 0 to Min(Baseline.Width, Actual.Width) - 1 do
    begin
      if IsInIgnoreRegion(X, Y, Options.IgnoreRegions) then
        Continue;
        
      C1 := Baseline.Canvas.Pixels[X, Y];
      C2 := Actual.Canvas.Pixels[X, Y];
      
      Distance := ColorDistance(C1, C2);
      if Distance > Options.Tolerance then
        Result.Canvas.Pixels[X, Y] := Options.DiffColor;
    end;
  end;
end;

{ TGUITestReporter }

class procedure TGUITestReporter.GenerateHTMLReport(const Results: TArray<TGUITestResult>;
  const OutputPath: string);
var
  HTML: TStringList;
  R: TGUITestResult;
  S: TGUITestStep;
  Passed, Failed, Total: Integer;
  StatusClass, StatusText: string;
begin
  GenerateSummary(Results, Passed, Failed, Total);
  
  HTML := TStringList.Create;
  try
    HTML.Add('<!DOCTYPE html>');
    HTML.Add('<html><head>');
    HTML.Add('<meta charset="UTF-8">');
    HTML.Add('<title>DeepBase GUI 测试报告</title>');
    HTML.Add('<style>');
    HTML.Add('body { font-family: "Segoe UI", Arial, sans-serif; margin: 20px; background: #f5f5f5; }');
    HTML.Add('.container { max-width: 1200px; margin: 0 auto; }');
    HTML.Add('.summary { background: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }');
    HTML.Add('.summary h1 { margin: 0 0 20px 0; color: #333; }');
    HTML.Add('.stats { display: flex; gap: 20px; }');
    HTML.Add('.stat { padding: 15px 25px; border-radius: 8px; color: white; }');
    HTML.Add('.stat-total { background: #2196F3; }');
    HTML.Add('.stat-passed { background: #4CAF50; }');
    HTML.Add('.stat-failed { background: #f44336; }');
    HTML.Add('.stat-number { font-size: 32px; font-weight: bold; }');
    HTML.Add('.stat-label { font-size: 14px; opacity: 0.9; }');
    HTML.Add('.test-case { background: white; margin-bottom: 15px; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }');
    HTML.Add('.test-header { padding: 15px 20px; cursor: pointer; display: flex; justify-content: space-between; align-items: center; }');
    HTML.Add('.test-header.passed { border-left: 4px solid #4CAF50; }');
    HTML.Add('.test-header.failed { border-left: 4px solid #f44336; }');
    HTML.Add('.test-name { font-weight: bold; font-size: 16px; }');
    HTML.Add('.test-duration { color: #666; font-size: 14px; }');
    HTML.Add('.test-status { padding: 4px 12px; border-radius: 4px; font-size: 12px; font-weight: bold; }');
    HTML.Add('.status-passed { background: #e8f5e9; color: #2e7d32; }');
    HTML.Add('.status-failed { background: #ffebee; color: #c62828; }');
    HTML.Add('.test-details { padding: 20px; border-top: 1px solid #eee; display: none; }');
    HTML.Add('.steps-table { width: 100%; border-collapse: collapse; }');
    HTML.Add('.steps-table th, .steps-table td { padding: 10px; text-align: left; border-bottom: 1px solid #eee; }');
    HTML.Add('.steps-table th { background: #f5f5f5; font-weight: 600; }');
    HTML.Add('.step-passed { color: #4CAF50; }');
    HTML.Add('.step-failed { color: #f44336; }');
    HTML.Add('.screenshot { max-width: 200px; cursor: pointer; border: 1px solid #ddd; border-radius: 4px; }');
    HTML.Add('.error-msg { background: #ffebee; color: #c62828; padding: 10px; border-radius: 4px; margin-top: 10px; }');
    HTML.Add('</style>');
    HTML.Add('</head><body>');
    HTML.Add('<div class="container">');
    
    // 摘要
    HTML.Add('<div class="summary">');
    HTML.Add('<h1>🧪 DeepBase GUI 测试报告</h1>');
    HTML.Add('<p>生成时间: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + '</p>');
    HTML.Add('<div class="stats">');
    HTML.Add(Format('<div class="stat stat-total"><div class="stat-number">%d</div><div class="stat-label">总测试数</div></div>', [Total]));
    HTML.Add(Format('<div class="stat stat-passed"><div class="stat-number">%d</div><div class="stat-label">通过</div></div>', [Passed]));
    HTML.Add(Format('<div class="stat stat-failed"><div class="stat-number">%d</div><div class="stat-label">失败</div></div>', [Failed]));
    HTML.Add('</div></div>');
    
    // 测试用例
    for R in Results do
    begin
      if R.Success then
      begin
        StatusClass := 'passed';
        StatusText := '通过';
      end
      else
      begin
        StatusClass := 'failed';
        StatusText := '失败';
      end;
      
      HTML.Add('<div class="test-case">');
      HTML.Add(Format('<div class="test-header %s" onclick="toggleDetails(this)">', [StatusClass]));
      HTML.Add(Format('<div><span class="test-name">%s</span><span class="test-duration"> (%d ms)</span></div>', 
        [R.TestName, R.DurationMs]));
      HTML.Add(Format('<span class="test-status status-%s">%s</span>', [StatusClass, StatusText]));
      HTML.Add('</div>');
      
      HTML.Add('<div class="test-details">');
      HTML.Add(Format('<p><strong>窗体�?</strong> %s</p>', [R.FormClass]));
      HTML.Add(Format('<p><strong>开始时�?</strong> %s</p>', [FormatDateTime('hh:nn:ss.zzz', R.StartTime)]));
      
      if Length(R.Steps) > 0 then
      begin
        HTML.Add('<table class="steps-table">');
        HTML.Add('<tr><th>#</th><th>描述</th><th>操作</th><th>预期</th><th>实际</th><th>状�?/th><th>截图</th></tr>');
        
        for S in R.Steps do
        begin
          if S.Success then
            StatusClass := 'step-passed'
          else
            StatusClass := 'step-failed';
            
          HTML.Add('<tr>');
          HTML.Add(Format('<td>%d</td>', [S.StepNumber]));
          HTML.Add(Format('<td>%s</td>', [S.Description]));
          HTML.Add(Format('<td>%s %s</td>', [S.Action, S.ControlName]));
          HTML.Add(Format('<td>%s</td>', [S.Expected]));
          HTML.Add(Format('<td>%s</td>', [S.Actual]));
          HTML.Add(Format('<td class="%s">%s</td>', [StatusClass, IfThen(S.Success, '�?, '�?)]));
          if S.ScreenshotPath <> '' then
            HTML.Add(Format('<td><img src="%s" class="screenshot" onclick="window.open(this.src)"></td>', [S.ScreenshotPath]))
          else
            HTML.Add('<td>-</td>');
          HTML.Add('</tr>');
        end;
        
        HTML.Add('</table>');
      end;
      
      if R.ErrorMessage <> '' then
        HTML.Add(Format('<div class="error-msg">%s</div>', [R.ErrorMessage]));
      
      HTML.Add('</div></div>');
    end;
    
    HTML.Add('</div>');
    HTML.Add('<script>');
    HTML.Add('function toggleDetails(header) {');
    HTML.Add('  var details = header.nextElementSibling;');
    HTML.Add('  details.style.display = details.style.display === "none" ? "block" : "none";');
    HTML.Add('}');
    HTML.Add('</script>');
    HTML.Add('</body></html>');
    
    ForceDirectories(TPath.GetDirectoryName(OutputPath));
    HTML.SaveToFile(OutputPath, TEncoding.UTF8);
  finally
    HTML.Free;
  end;
end;

class procedure TGUITestReporter.GenerateJSONReport(const Results: TArray<TGUITestResult>;
  const OutputPath: string);
var
  JSON, TestObj, StepObj: TJSONObject;
  ResultsArr, StepsArr: TJSONArray;
  R: TGUITestResult;
  S: TGUITestStep;
begin
  JSON := TJSONObject.Create;
  try
    JSON.AddPair('generated', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now));
    JSON.AddPair('totalTests', TJSONNumber.Create(Length(Results)));
    
    ResultsArr := TJSONArray.Create;
    for R in Results do
    begin
      TestObj := TJSONObject.Create;
      TestObj.AddPair('name', R.TestName);
      TestObj.AddPair('formClass', R.FormClass);
      TestObj.AddPair('success', TJSONBool.Create(R.Success));
      TestObj.AddPair('durationMs', TJSONNumber.Create(R.DurationMs));
      TestObj.AddPair('errorMessage', R.ErrorMessage);
      
      StepsArr := TJSONArray.Create;
      for S in R.Steps do
      begin
        StepObj := TJSONObject.Create;
        StepObj.AddPair('step', TJSONNumber.Create(S.StepNumber));
        StepObj.AddPair('description', S.Description);
        StepObj.AddPair('action', S.Action);
        StepObj.AddPair('controlName', S.ControlName);
        StepObj.AddPair('expected', S.Expected);
        StepObj.AddPair('actual', S.Actual);
        StepObj.AddPair('success', TJSONBool.Create(S.Success));
        StepObj.AddPair('screenshot', S.ScreenshotPath);
        StepObj.AddPair('timeMs', TJSONNumber.Create(S.TimeMs));
        StepsArr.AddElement(StepObj);
      end;
      TestObj.AddPair('steps', StepsArr);
      
      ResultsArr.AddElement(TestObj);
    end;
    JSON.AddPair('results', ResultsArr);
    
    ForceDirectories(TPath.GetDirectoryName(OutputPath));
    TFile.WriteAllText(OutputPath, JSON.Format(2), TEncoding.UTF8);
  finally
    JSON.Free;
  end;
end;

class procedure TGUITestReporter.GenerateSummary(const Results: TArray<TGUITestResult>;
  out Passed, Failed, Total: Integer);
var
  R: TGUITestResult;
begin
  Total := Length(Results);
  Passed := 0;
  Failed := 0;
  
  for R in Results do
  begin
    if R.Success then
      Inc(Passed)
    else
      Inc(Failed);
  end;
end;

{ TGUITestBase }

constructor TGUITestBase.Create;
begin
  inherited Create;
  FResults := TList<TGUITestResult>.Create;
  FConfig := TGUITestConfig.Default;
end;

destructor TGUITestBase.Destroy;
begin
  FResults.Free;
  inherited;
end;

procedure TGUITestBase.Setup;
var
  TestName: string;
begin
  // 获取当前测试名称
  TestName := ClassName + '.' + 'Test';  // DUnitX 会设置具体测试名
  
  // 确保输出目录存在
  ForceDirectories(FConfig.BaselinesPath);
  ForceDirectories(FConfig.OutputPath);
  
  // 创建上下�?
  FContext := TGUITestContext.Create(TestName, FConfig);
  
  // 创建测试窗体
  FForm := CreateTestForm;
  if Assigned(FForm) then
  begin
    FContext.FormClass := FForm.ClassName;
    FForm.Position := poDesigned;
    FForm.Left := FConfig.FormLeft;
    FForm.Top := FConfig.FormTop;
    FForm.Show;
    Application.ProcessMessages;
  end;
end;

procedure TGUITestBase.TearDown;
begin
  // 保存结果
  if Assigned(FContext) then
  begin
    FResults.Add(FContext.GetResult);
    FreeAndNil(FContext);
  end;
  
  // 销毁窗�?
  DestroyTestForm;
end;

procedure TGUITestBase.DestroyTestForm;
begin
  if Assigned(FForm) then
  begin
    FForm.Close;
    FreeAndNil(FForm);
  end;
end;

function TGUITestBase.GetAllResults: TArray<TGUITestResult>;
begin
  Result := FResults.ToArray;
end;

// ========== 测试辅助方法 ==========

procedure TGUITestBase.Click(const ControlName: string);
var
  C: TControl;
begin
  C := TDeepBaseTestHelper.FindControl(FForm, ControlName);
  if Assigned(C) then
    Click(C)
  else
    raise ETestAssertionFailed.CreateFmt('Control "%s" not found', [ControlName]);
end;

procedure TGUITestBase.Click(AControl: TControl);
begin
  if Assigned(FContext) then
    FContext.LogAction('Click', AControl.Name);
    
  TDeepBaseTestHelper.SimulateClick(AControl);
  Wait(FConfig.StepDelay);
end;

procedure TGUITestBase.DoubleClick(const ControlName: string);
var
  C: TControl;
begin
  C := TDeepBaseTestHelper.FindControl(FForm, ControlName);
  if Assigned(C) then
    DoubleClick(C)
  else
    raise ETestAssertionFailed.CreateFmt('Control "%s" not found', [ControlName]);
end;

procedure TGUITestBase.DoubleClick(AControl: TControl);
begin
  if Assigned(FContext) then
    FContext.LogAction('DoubleClick', AControl.Name);
    
  TDeepBaseTestHelper.SimulateDoubleClick(AControl);
  Wait(FConfig.StepDelay);
end;

procedure TGUITestBase.Input(const ControlName, Text: string);
var
  C: TControl;
begin
  C := TDeepBaseTestHelper.FindControl(FForm, ControlName);
  if Assigned(C) then
    Input(C, Text)
  else
    raise ETestAssertionFailed.CreateFmt('Control "%s" not found', [ControlName]);
end;

procedure TGUITestBase.Input(AControl: TControl; const Text: string);
begin
  if Assigned(FContext) then
    FContext.LogAction('Input "' + Text + '"', AControl.Name);
    
  TDeepBaseTestHelper.SimulateInput(AControl, Text);
  Wait(FConfig.StepDelay);
end;

procedure TGUITestBase.Select(const ControlName: string; Index: Integer);
var
  C: TControl;
begin
  C := TDeepBaseTestHelper.FindControl(FForm, ControlName);
  if Assigned(C) then
  begin
    if Assigned(FContext) then
      FContext.LogAction(Format('Select [%d]', [Index]), ControlName);
      
    TDeepBaseTestHelper.SimulateSelect(C, Index);
    Wait(FConfig.StepDelay);
  end
  else
    raise ETestAssertionFailed.CreateFmt('Control "%s" not found', [ControlName]);
end;

procedure TGUITestBase.Select(const ControlName, Text: string);
var
  C: TControl;
begin
  C := TDeepBaseTestHelper.FindControl(FForm, ControlName);
  if Assigned(C) then
  begin
    if Assigned(FContext) then
      FContext.LogAction('Select "' + Text + '"', ControlName);
      
    TDeepBaseTestHelper.SimulateSelect(C, Text);
    Wait(FConfig.StepDelay);
  end
  else
    raise ETestAssertionFailed.CreateFmt('Control "%s" not found', [ControlName]);
end;

procedure TGUITestBase.Check(const ControlName: string; Checked: Boolean);
var
  C: TControl;
begin
  C := TDeepBaseTestHelper.FindControl(FForm, ControlName);
  if Assigned(C) then
  begin
    if Assigned(FContext) then
      FContext.LogAction(IfThen(Checked, 'Check', 'Uncheck'), ControlName);
      
    TDeepBaseTestHelper.SimulateCheck(C, Checked);
    Wait(FConfig.StepDelay);
  end
  else
    raise ETestAssertionFailed.CreateFmt('Control "%s" not found', [ControlName]);
end;

procedure TGUITestBase.PressKey(Key: Word; Shift: TShiftState);
begin
  if Assigned(FContext) then
    FContext.LogAction(Format('KeyPress [%d]', [Key]), '');
    
  if Assigned(FForm) and (FForm.ActiveControl <> nil) then
    TDeepBaseTestHelper.SimulateKeyPress(FForm.ActiveControl, Key, Shift);
    
  Wait(FConfig.StepDelay);
end;

procedure TGUITestBase.Wait(Ms: Integer);
begin
  Sleep(Ms);
  Application.ProcessMessages;
end;

procedure TGUITestBase.ProcessMessages;
begin
  Application.ProcessMessages;
end;

// ========== 断言方法 ==========

procedure TGUITestBase.AssertVisible(const ControlName: string; const Msg: string);
var
  C: TControl;
begin
  C := TDeepBaseTestHelper.FindControl(FForm, ControlName);
  if C = nil then
    raise ETestAssertionFailed.CreateFmt('Control "%s" not found', [ControlName]);
    
  if not C.Visible then
  begin
    if Msg <> '' then
      raise ETestAssertionFailed.Create(Msg)
    else
      raise ETestAssertionFailed.CreateFmt('Control "%s" is not visible', [ControlName]);
  end;
end;

procedure TGUITestBase.AssertNotVisible(const ControlName: string; const Msg: string);
var
  C: TControl;
begin
  C := TDeepBaseTestHelper.FindControl(FForm, ControlName);
  if C = nil then
    Exit; // 不存在等同于不可�?
    
  if C.Visible then
  begin
    if Msg <> '' then
      raise ETestAssertionFailed.Create(Msg)
    else
      raise ETestAssertionFailed.CreateFmt('Control "%s" is visible (expected not visible)', [ControlName]);
  end;
end;

procedure TGUITestBase.AssertEnabled(const ControlName: string; const Msg: string);
var
  C: TControl;
begin
  C := TDeepBaseTestHelper.FindControl(FForm, ControlName);
  if C = nil then
    raise ETestAssertionFailed.CreateFmt('Control "%s" not found', [ControlName]);
    
  if not C.Enabled then
  begin
    if Msg <> '' then
      raise ETestAssertionFailed.Create(Msg)
    else
      raise ETestAssertionFailed.CreateFmt('Control "%s" is not enabled', [ControlName]);
  end;
end;

procedure TGUITestBase.AssertDisabled(const ControlName: string; const Msg: string);
var
  C: TControl;
begin
  C := TDeepBaseTestHelper.FindControl(FForm, ControlName);
  if C = nil then
    raise ETestAssertionFailed.CreateFmt('Control "%s" not found', [ControlName]);
    
  if C.Enabled then
  begin
    if Msg <> '' then
      raise ETestAssertionFailed.Create(Msg)
    else
      raise ETestAssertionFailed.CreateFmt('Control "%s" is enabled (expected disabled)', [ControlName]);
  end;
end;

procedure TGUITestBase.AssertText(const ControlName, Expected: string; const Msg: string);
var
  C: TControl;
begin
  C := TDeepBaseTestHelper.FindControl(FForm, ControlName);
  if C = nil then
    raise ETestAssertionFailed.CreateFmt('Control "%s" not found', [ControlName]);
    
  TDeepBaseTestHelper.AssertText(C, Expected, Msg);
end;

procedure TGUITestBase.AssertValue(const ControlName, Expected: string; const Msg: string);
var
  C: TControl;
begin
  C := TDeepBaseTestHelper.FindControl(FForm, ControlName);
  if C = nil then
    raise ETestAssertionFailed.CreateFmt('Control "%s" not found', [ControlName]);
    
  TDeepBaseTestHelper.AssertValue(C, Expected, Msg);
end;

procedure TGUITestBase.AssertControlExists(const ControlName: string; const Msg: string);
var
  C: TControl;
begin
  C := TDeepBaseTestHelper.FindControl(FForm, ControlName);
  if C = nil then
  begin
    if Msg <> '' then
      raise ETestAssertionFailed.Create(Msg)
    else
      raise ETestAssertionFailed.CreateFmt('Control "%s" does not exist', [ControlName]);
  end;
end;

procedure TGUITestBase.AssertFocused(const ControlName: string; const Msg: string);
var
  C: TControl;
begin
  C := TDeepBaseTestHelper.FindControl(FForm, ControlName);
  if C = nil then
    raise ETestAssertionFailed.CreateFmt('Control "%s" not found', [ControlName]);
    
  if not (C is TWinControl) then
    raise ETestAssertionFailed.CreateFmt('Control "%s" cannot receive focus', [ControlName]);
    
  if FForm.ActiveControl <> TWinControl(C) then
  begin
    if Msg <> '' then
      raise ETestAssertionFailed.Create(Msg)
    else
      raise ETestAssertionFailed.CreateFmt('Control "%s" is not focused', [ControlName]);
  end;
end;

procedure TGUITestBase.AssertCaption(const Expected: string; const Msg: string);
begin
  if FForm.Caption <> Expected then
  begin
    if Msg <> '' then
      raise ETestAssertionFailed.Create(Msg)
    else
      raise ETestAssertionFailed.CreateFmt('Form caption mismatch. Expected: "%s", Actual: "%s"',
        [Expected, FForm.Caption]);
  end;
end;

// ========== 截图方法 ==========

function TGUITestBase.CaptureScreenshot(const Suffix: string): string;
var
  FileName: string;
begin
  FileName := Format('%s_%s_%s.%s', [
    FContext.TestName,
    FormatDateTime('hhnnsszzz', Now),
    Suffix,
    FConfig.ScreenshotFormat
  ]);
  Result := TPath.Combine(FConfig.OutputPath, FileName);
  
  TDeepBaseTestHelper.SaveScreenshotToFile(FForm, Result);
  
  if Assigned(FContext) then
    FContext.AddScreenshot(Result);
end;

procedure TGUITestBase.SaveBaseline(const Name: string);
var
  FileName: string;
begin
  FileName := TPath.Combine(FConfig.BaselinesPath, Name + '.' + FConfig.ScreenshotFormat);
  TDeepBaseTestHelper.SaveScreenshotToFile(FForm, FileName);
end;

function TGUITestBase.CompareWithBaseline(const Name: string): TScreenshotCompareResult;
var
  BaselinePath, ActualPath: string;
begin
  BaselinePath := TPath.Combine(FConfig.BaselinesPath, Name + '.' + FConfig.ScreenshotFormat);
  ActualPath := CaptureScreenshot('compare');
  
  Result := TScreenshotComparer.Compare(BaselinePath, ActualPath, FConfig.CompareOptions);
end;

procedure TGUITestBase.AssertScreenshotMatch(const BaselineName: string;
  MaxDiffPercent: Double; const Msg: string);
var
  CompareResult: TScreenshotCompareResult;
begin
  CompareResult := CompareWithBaseline(BaselineName);
  
  if CompareResult.DifferencePercent > MaxDiffPercent then
  begin
    if Msg <> '' then
      raise ETestAssertionFailed.Create(Msg)
    else
      raise ETestAssertionFailed.CreateFmt(
        'Screenshot mismatch for "%s". Difference: %.2f%% (max allowed: %.2f%%)',
        [BaselineName, CompareResult.DifferencePercent, MaxDiffPercent]);
  end;
end;

// ========== 步骤记录 ==========

procedure TGUITestBase.Step(const Description: string);
begin
  if Assigned(FContext) then
    FContext.BeginStep(Description);
end;

procedure TGUITestBase.Verify(Condition: Boolean; const Expected, Actual: string);
begin
  if Assigned(FContext) then
    FContext.EndStep(Condition, Expected, Actual);
    
  if not Condition then
    raise ETestAssertionFailed.CreateFmt('Verification failed. Expected: %s, Actual: %s',
      [Expected, Actual]);
end;

{ TGUITestRunner }

constructor TGUITestRunner.Create(AConfig: TGUITestConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FResults := TList<TGUITestResult>.Create;
end;

destructor TGUITestRunner.Destroy;
begin
  FResults.Free;
  inherited;
end;

procedure TGUITestRunner.RunTests(TestClass: TClass);
begin
  // 使用 DUnitX 运行
  // 这里提供一个简化的运行器接�?
end;

procedure TGUITestRunner.RunTest(Test: TGUITestBase; const MethodName: string);
begin
  Test.Config := FConfig;
  Test.Setup;
  try
    // 调用测试方法
  finally
    Test.TearDown;
    // 收集结果
    for var R in Test.GetAllResults do
      FResults.Add(R);
  end;
end;

procedure TGUITestRunner.GenerateReport(const OutputPath: string);
begin
  TGUITestReporter.GenerateHTMLReport(FResults.ToArray, 
    TPath.Combine(OutputPath, 'gui_test_report.html'));
  TGUITestReporter.GenerateJSONReport(FResults.ToArray,
    TPath.Combine(OutputPath, 'gui_test_report.json'));
end;

end.
