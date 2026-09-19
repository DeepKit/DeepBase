{ ============================================================================
  AcceptanceReport - 楠屾敹鎶ュ憡鐢熸垚鍣?
  
  鐗堟湰: 1.0
  璇存槑: 鐢熸垚璇︾粏鐨勯獙鏀舵姤鍛?(HTML/JSON/XML)
  ============================================================================ }

unit AcceptanceReport;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.IOUtils,
  System.TypInfo, AcceptanceRunner;

type
  TReportFormat = (rfHTML, rfJSON, rfXML);
  
  TAcceptanceReportGenerator = class
  private
    FRunner: TAcceptanceRunner;
    
    function GenerateHTMLReport: string;
    function GenerateJSONReport: string;
    function GenerateXMLReport: string;
    
    function GetStatusColor(Status: TTestStatus): string;
    function GetStatusIcon(Status: TTestStatus): string;
    function GetPriorityText(Priority: TTestPriority): string;
    function GetStatusText(Status: TTestStatus): string;
    function GetPhaseName(Phase: Integer): string;
    
  public
    constructor Create(ARunner: TAcceptanceRunner);
    
    procedure GenerateReport(const OutputPath: string; Format: TReportFormat = rfHTML);
    procedure GenerateAllFormats(const BasePath: string);
    
    property Runner: TAcceptanceRunner read FRunner;
  end;

implementation

uses
  System.DateUtils;

const
  PHASE_NAMES: array[1..8] of string = (
    '鏂囨。涓庢灦鏋勫鏌?,
    '闈欐€佷唬鐮佸垎鏋?, 
    '鍗曞厓娴嬭瘯楠岃瘉',
    '闆嗘垚娴嬭瘯',
    '瀹夊叏涓撻」娴嬭瘯',
    '鍏煎鎬ф祴璇?,
    '绀轰緥椤圭洰楠岃瘉',
    '鏈€缁堥獙鏀?
  );

{ TAcceptanceReportGenerator }

constructor TAcceptanceReportGenerator.Create(ARunner: TAcceptanceRunner);
begin
  inherited Create;
  FRunner := ARunner;
end;

procedure TAcceptanceReportGenerator.GenerateReport(const OutputPath: string; Format: TReportFormat);
var
  Content: string;
begin
  case Format of
    rfHTML: Content := GenerateHTMLReport;
    rfJSON: Content := GenerateJSONReport;
    rfXML: Content := GenerateXMLReport;
  else
    Content := GenerateHTMLReport;
  end;
  
  ForceDirectories(ExtractFilePath(OutputPath));
  TFile.WriteAllText(OutputPath, Content, TEncoding.UTF8);
end;

procedure TAcceptanceReportGenerator.GenerateAllFormats(const BasePath: string);
var
  TimeStamp: string;
begin
  TimeStamp := FormatDateTime('yyyymmdd_hhnnss', Now);
  
  GenerateReport(TPath.Combine(BasePath, 'AcceptanceReport_' + TimeStamp + '.html'), rfHTML);
  GenerateReport(TPath.Combine(BasePath, 'AcceptanceReport_' + TimeStamp + '.json'), rfJSON);
  GenerateReport(TPath.Combine(BasePath, 'AcceptanceReport_' + TimeStamp + '.xml'), rfXML);
end;

function TAcceptanceReportGenerator.GetStatusColor(Status: TTestStatus): string;
begin
  case Status of
    tsPassed: Result := '#4CAF50';
    tsFailed: Result := '#f44336';
    tsManual: Result := '#FF9800';
    tsSkipped: Result := '#9E9E9E';
    tsRunning: Result := '#2196F3';
  else
    Result := '#757575';
  end;
end;

function TAcceptanceReportGenerator.GetStatusIcon(Status: TTestStatus): string;
begin
  case Status of
    tsPassed: Result := '鉁?;
    tsFailed: Result := '鉁?;
    tsManual: Result := '鈿?;
    tsSkipped: Result := '鈼?;
    tsRunning: Result := '鉄?;
  else
    Result := '-';
  end;
end;

function TAcceptanceReportGenerator.GetPriorityText(Priority: TTestPriority): string;
begin
  case Priority of
    tpP0: Result := 'P0';
    tpP1: Result := 'P1';
    tpP2: Result := 'P2';
    tpP3: Result := 'P3';
  end;
end;

function TAcceptanceReportGenerator.GetStatusText(Status: TTestStatus): string;
begin
  case Status of
    tsNotRun: Result := '鏈墽琛?;
    tsRunning: Result := '鎵ц涓?;
    tsPassed: Result := '閫氳繃';
    tsFailed: Result := '澶辫触';
    tsSkipped: Result := '璺宠繃';
    tsManual: Result := '寰呬汉宸?;
  else
    Result := '鏈煡';
  end;
end;

function TAcceptanceReportGenerator.GetPhaseName(Phase: Integer): string;
begin
  if (Phase >= 1) and (Phase <= 8) then
    Result := PHASE_NAMES[Phase]
  else
    Result := '鏈煡闃舵';
end;

function TAcceptanceReportGenerator.GenerateHTMLReport: string;
var
  HTML: TStringList;
  Item: TTestItem;
  TotalTests, PassedTests, FailedTests, ManualTests: Integer;
  Phase: Integer;
  PhaseTests: TArray<TTestItem>;
  StatusColor, StatusIcon: string;
begin
  TotalTests := FRunner.Tests.Count;
  PassedTests := 0;
  FailedTests := 0;
  ManualTests := 0;
  
  for Item in FRunner.Tests do
  begin
    case Item.Status of
      tsPassed: Inc(PassedTests);
      tsFailed: Inc(FailedTests);
      tsManual: Inc(ManualTests);
    end;
  end;
  
  HTML := TStringList.Create;
  try
    HTML.Add('<!DOCTYPE html>');
    HTML.Add('<html lang="zh-CN"><head>');
    HTML.Add('<meta charset="UTF-8">');
    HTML.Add('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
    HTML.Add('<title>DeepBase 楠屾敹鎶ュ憡</title>');
    HTML.Add('<style>');
    HTML.Add('* { margin: 0; padding: 0; box-sizing: border-box; }');
    HTML.Add('body { font-family: "Segoe UI", "Microsoft YaHei", Arial, sans-serif; background: #f5f7fa; }');
    HTML.Add('.container { max-width: 1200px; margin: 0 auto; padding: 20px; }');
    HTML.Add('.header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 12px; margin-bottom: 30px; }');
    HTML.Add('.header h1 { font-size: 2em; margin-bottom: 10px; }');
    HTML.Add('.stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; margin-bottom: 30px; }');
    HTML.Add('.stat-card { background: white; padding: 20px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); text-align: center; }');
    HTML.Add('.stat-number { font-size: 2em; font-weight: bold; margin-bottom: 5px; }');
    HTML.Add('.stat-label { color: #666; }');
    HTML.Add('.stat-total .stat-number { color: #2196F3; }');
    HTML.Add('.stat-pass .stat-number { color: #4CAF50; }');
    HTML.Add('.stat-fail .stat-number { color: #f44336; }');
    HTML.Add('.stat-manual .stat-number { color: #FF9800; }');
    HTML.Add('.phase { background: white; margin-bottom: 20px; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }');
    HTML.Add('.phase-header { background: #e3f2fd; padding: 15px 20px; border-bottom: 1px solid #ddd; font-weight: bold; color: #1976D2; }');
    HTML.Add('.test-item { padding: 12px 20px; border-bottom: 1px solid #eee; display: flex; align-items: center; }');
    HTML.Add('.test-item:hover { background: #f8f9fa; }');
    HTML.Add('.test-id { width: 80px; font-weight: bold; color: #666; }');
    HTML.Add('.test-name { flex: 1; }');
    HTML.Add('.test-priority { width: 50px; text-align: center; }');
    HTML.Add('.test-status { width: 80px; text-align: center; font-weight: 500; }');
    HTML.Add('.test-duration { width: 80px; text-align: right; color: #666; }');
    HTML.Add('.footer { text-align: center; margin-top: 40px; padding: 20px; color: #666; }');
    HTML.Add('</style>');
    HTML.Add('</head><body>');
    
    HTML.Add('<div class="container">');
    
    // Header
    HTML.Add('<div class="header">');
    HTML.Add('<h1>馃И DeepBase 楠屾敹鎶ュ憡</h1>');
    HTML.Add('<div>鐢熸垚鏃堕棿: ' + FormatDateTime('yyyy骞磎m鏈坉d鏃?hh:nn:ss', Now) + '</div>');
    HTML.Add('</div>');
    
    // Statistics
    HTML.Add('<div class="stats">');
    HTML.Add('<div class="stat-card stat-total">');
    HTML.Add(Format('<div class="stat-number">%d</div>', [TotalTests]));
    HTML.Add('<div class="stat-label">鎬绘祴璇曢」</div>');
    HTML.Add('</div>');
    HTML.Add('<div class="stat-card stat-pass">');
    HTML.Add(Format('<div class="stat-number">%d</div>', [PassedTests]));
    HTML.Add('<div class="stat-label">閫氳繃</div>');
    HTML.Add('</div>');
    HTML.Add('<div class="stat-card stat-fail">');
    HTML.Add(Format('<div class="stat-number">%d</div>', [FailedTests]));
    HTML.Add('<div class="stat-label">澶辫触</div>');
    HTML.Add('</div>');
    HTML.Add('<div class="stat-card stat-manual">');
    HTML.Add(Format('<div class="stat-number">%d</div>', [ManualTests]));
    HTML.Add('<div class="stat-label">寰呬汉宸ョ‘璁?/div>');
    HTML.Add('</div>');
    HTML.Add('</div>');
    
    // Phases
    for Phase := 1 to 8 do
    begin
      PhaseTests := FRunner.GetTestsByPhase(Phase);
      if Length(PhaseTests) = 0 then Continue;
      
      HTML.Add('<div class="phase">');
      HTML.Add(Format('<div class="phase-header">绗?%d 闃舵: %s</div>', [Phase, GetPhaseName(Phase)]));
      
      for Item in PhaseTests do
      begin
        StatusColor := GetStatusColor(Item.Status);
        StatusIcon := GetStatusIcon(Item.Status);
        
        HTML.Add('<div class="test-item">');
        HTML.Add(Format('<div class="test-id">%s</div>', [Item.ID]));
        HTML.Add(Format('<div class="test-name">%s</div>', [Item.Name]));
        HTML.Add(Format('<div class="test-priority">%s</div>', [GetPriorityText(Item.Priority)]));
        HTML.Add(Format('<div class="test-status" style="color:%s">%s %s</div>', [StatusColor, StatusIcon, GetStatusText(Item.Status)]));
        HTML.Add(Format('<div class="test-duration">%d ms</div>', [Item.DurationMs]));
        HTML.Add('</div>');
      end;
      
      HTML.Add('</div>');
    end;
    
    HTML.Add('<div class="footer">');
    HTML.Add('鎶ュ憡鐢?DeepBase 鍙鍖栭獙鏀舵祴璇曞伐鍏疯嚜鍔ㄧ敓鎴?);
    HTML.Add('</div>');
    
    HTML.Add('</div>');
    HTML.Add('</body></html>');
    
    Result := HTML.Text;
  finally
    HTML.Free;
  end;
end;

function TAcceptanceReportGenerator.GenerateJSONReport: string;
var
  JSON: TJSONObject;
  Stats, PhaseObj, TestObj: TJSONObject;
  Phases, TestArray: TJSONArray;
  Item: TTestItem;
  Phase: Integer;
  PhaseTests: TArray<TTestItem>;
  PassedCount, FailedCount, ManualCount: Integer;
begin
  JSON := TJSONObject.Create;
  try
    JSON.AddPair('title', 'DeepBase 楠屾敹鎶ュ憡');
    JSON.AddPair('generated_at', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now));
    JSON.AddPair('version', 'DeepBase Framework v1.0');
    
    // Statistics
    PassedCount := 0;
    FailedCount := 0;
    ManualCount := 0;
    for Item in FRunner.Tests do
    begin
      case Item.Status of
        tsPassed: Inc(PassedCount);
        tsFailed: Inc(FailedCount);
        tsManual: Inc(ManualCount);
      end;
    end;
    
    Stats := TJSONObject.Create;
    Stats.AddPair('total_tests', TJSONNumber.Create(FRunner.Tests.Count));
    Stats.AddPair('passed_tests', TJSONNumber.Create(PassedCount));
    Stats.AddPair('failed_tests', TJSONNumber.Create(FailedCount));
    Stats.AddPair('manual_tests', TJSONNumber.Create(ManualCount));
    JSON.AddPair('statistics', Stats);
    
    // Phases
    Phases := TJSONArray.Create;
    for Phase := 1 to 8 do
    begin
      PhaseTests := FRunner.GetTestsByPhase(Phase);
      if Length(PhaseTests) = 0 then Continue;
      
      PhaseObj := TJSONObject.Create;
      PhaseObj.AddPair('phase_number', TJSONNumber.Create(Phase));
      PhaseObj.AddPair('phase_name', GetPhaseName(Phase));
      
      TestArray := TJSONArray.Create;
      for Item in PhaseTests do
      begin
        TestObj := TJSONObject.Create;
        TestObj.AddPair('id', Item.ID);
        TestObj.AddPair('name', Item.Name);
        TestObj.AddPair('description', Item.Description);
        TestObj.AddPair('priority', GetPriorityText(Item.Priority));
        TestObj.AddPair('status', GetStatusText(Item.Status));
        TestObj.AddPair('duration_ms', TJSONNumber.Create(Item.DurationMs));
        TestObj.AddPair('is_manual', TJSONBool.Create(Item.IsManual));
        if Item.ErrorMessage <> '' then
          TestObj.AddPair('error_message', Item.ErrorMessage);
        TestArray.AddElement(TestObj);
      end;
      PhaseObj.AddPair('tests', TestArray);
      Phases.AddElement(PhaseObj);
    end;
    JSON.AddPair('phases', Phases);
    
    Result := JSON.ToString;
  finally
    JSON.Free;
  end;
end;

function TAcceptanceReportGenerator.GenerateXMLReport: string;
var
  XML: TStringList;
  Item: TTestItem;
  Phase: Integer;
  PhaseTests: TArray<TTestItem>;
  PassedCount, FailedCount, ManualCount: Integer;
begin
  PassedCount := 0;
  FailedCount := 0;
  ManualCount := 0;
  for Item in FRunner.Tests do
  begin
    case Item.Status of
      tsPassed: Inc(PassedCount);
      tsFailed: Inc(FailedCount);
      tsManual: Inc(ManualCount);
    end;
  end;

  XML := TStringList.Create;
  try
    XML.Add('<?xml version="1.0" encoding="UTF-8"?>');
    XML.Add('<acceptance_report>');
    XML.Add('  <metadata>');
    XML.Add('    <title>DeepBase 楠屾敹鎶ュ憡</title>');
    XML.Add('    <generated_at>' + FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now) + '</generated_at>');
    XML.Add('    <version>DeepBase Framework v1.0</version>');
    XML.Add('  </metadata>');
    
    XML.Add('  <statistics>');
    XML.Add(Format('    <total_tests>%d</total_tests>', [FRunner.Tests.Count]));
    XML.Add(Format('    <passed_tests>%d</passed_tests>', [PassedCount]));
    XML.Add(Format('    <failed_tests>%d</failed_tests>', [FailedCount]));
    XML.Add(Format('    <manual_tests>%d</manual_tests>', [ManualCount]));
    XML.Add('  </statistics>');
    
    XML.Add('  <phases>');
    for Phase := 1 to 8 do
    begin
      PhaseTests := FRunner.GetTestsByPhase(Phase);
      if Length(PhaseTests) = 0 then Continue;
      
      XML.Add(Format('    <phase number="%d" name="%s">', [Phase, GetPhaseName(Phase)]));
      XML.Add('      <tests>');
      
      for Item in PhaseTests do
      begin
        XML.Add(Format('        <test id="%s" priority="%s" status="%s" duration_ms="%d">', [
          Item.ID, GetPriorityText(Item.Priority), GetStatusText(Item.Status), Item.DurationMs]));
        XML.Add('          <name>' + Item.Name + '</name>');
        XML.Add('          <description>' + Item.Description + '</description>');
        if Item.ErrorMessage <> '' then
          XML.Add('          <error_message>' + Item.ErrorMessage + '</error_message>');
        XML.Add('        </test>');
      end;
      
      XML.Add('      </tests>');
      XML.Add('    </phase>');
    end;
    XML.Add('  </phases>');
    XML.Add('</acceptance_report>');
    
    Result := XML.Text;
  finally
    XML.Free;
  end;
end;

end.
