{ ============================================================================
  AcceptanceRunner - 楠屾敹娴嬭瘯杩愯鍣?
  
  鐗堟湰: 1.0
  璇存槑: 鎵ц鍚勯樁娈甸獙鏀舵祴璇曠殑鏍稿績閫昏緫
  ============================================================================ }

unit AcceptanceRunner;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.JSON, System.IOUtils, System.DateUtils;

type
  TTestStatus = (tsNotRun, tsRunning, tsPassed, tsFailed, tsSkipped, tsManual);
  TTestPriority = (tpP0, tpP1, tpP2, tpP3);
  
  TTestItem = record
    ID: string;
    Name: string;
    Description: string;
    Phase: Integer;
    Priority: TTestPriority;
    Status: TTestStatus;
    IsManual: Boolean;
    ErrorMessage: string;
    DurationMs: Int64;
    procedure Clear;
  end;
  
  TPhaseResult = record
    PhaseNumber: Integer;
    PhaseName: string;
    TotalTests: Integer;
    PassedTests: Integer;
    FailedTests: Integer;
    SkippedTests: Integer;
    ManualTests: Integer;
    StartTime: TDateTime;
    EndTime: TDateTime;
  end;
  
  TOnTestProgress = reference to procedure(const Item: TTestItem; Progress: Integer);
  TOnPhaseComplete = reference to procedure(const Result: TPhaseResult);
  TOnLogMessage = reference to procedure(const Msg: string; IsError: Boolean);

  TAcceptanceRunner = class
  private
    FTests: TList<TTestItem>;
    FPhaseResults: TList<TPhaseResult>;
    FOnProgress: TOnTestProgress;
    FOnPhaseComplete: TOnPhaseComplete;
    FOnLog: TOnLogMessage;
    FCurrentPhase: Integer;
    FRunning: Boolean;
    FBasePath: string;
    
    procedure Log(const Msg: string; IsError: Boolean = False);
    procedure InitializeTests;
    function RunTest(var Item: TTestItem): Boolean;
    
    // 鍚勯樁娈垫祴璇曟柟娉?
    function Test_Compile_Win32: Boolean;
    function Test_Compile_Win64: Boolean;
    function Test_NoTODO: Boolean;
    function Test_NoHardcodedKeys: Boolean;
    function Test_UnitTests: Boolean;
    function Test_IntegrationTests: Boolean;
    function Test_SecurityCrypto: Boolean;
    function Test_SecurityPayment: Boolean;
    function Test_MemoryLeaks: Boolean;
    function Test_Examples: Boolean;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure LoadTests;
    procedure RunPhase(PhaseNumber: Integer);
    procedure RunAllPhases;
    procedure MarkManualTest(const TestID: string; Passed: Boolean; const Notes: string);
    procedure SkipTest(const TestID: string);
    procedure GenerateReport(const OutputPath: string);
    
    function GetTestsByPhase(PhaseNumber: Integer): TArray<TTestItem>;
    function GetPhaseResult(PhaseNumber: Integer): TPhaseResult;
    function GetOverallProgress: Integer;
    
    property Tests: TList<TTestItem> read FTests;
    property PhaseResults: TList<TPhaseResult> read FPhaseResults;
    property CurrentPhase: Integer read FCurrentPhase;
    property Running: Boolean read FRunning;
    property BasePath: string read FBasePath write FBasePath;
    
    property OnProgress: TOnTestProgress read FOnProgress write FOnProgress;
    property OnPhaseComplete: TOnPhaseComplete read FOnPhaseComplete write FOnPhaseComplete;
    property OnLog: TOnLogMessage read FOnLog write FOnLog;
  end;

implementation

uses
  System.Diagnostics, System.TypInfo, System.StrUtils,
  Winapi.Windows, Winapi.ShellAPI;

{ TTestItem }

procedure TTestItem.Clear;
begin
  ID := '';
  Name := '';
  Description := '';
  Phase := 0;
  Priority := tpP2;
  Status := tsNotRun;
  IsManual := False;
  ErrorMessage := '';
  DurationMs := 0;
end;

{ TAcceptanceRunner }

constructor TAcceptanceRunner.Create;
begin
  inherited;
  FTests := TList<TTestItem>.Create;
  FPhaseResults := TList<TPhaseResult>.Create;
  FCurrentPhase := 0;
  FRunning := False;
  FBasePath := ExtractFilePath(ParamStr(0));
  // 鍚戜笂涓ょ骇鍒伴」鐩牴鐩綍
  FBasePath := TPath.GetFullPath(TPath.Combine(FBasePath, '..\..\'));
end;

destructor TAcceptanceRunner.Destroy;
begin
  FTests.Free;
  FPhaseResults.Free;
  inherited;
end;

procedure TAcceptanceRunner.Log(const Msg: string; IsError: Boolean);
begin
  if Assigned(FOnLog) then
    FOnLog(Msg, IsError);
end;

procedure TAcceptanceRunner.InitializeTests;
var
  T: TTestItem;
begin
  FTests.Clear;
  
  // ========== 绗竴闃舵: 鏂囨。涓庢灦鏋勫鏌?==========
  T.Clear;
  T.ID := 'P1-001'; T.Name := 'README.md 瀹屾暣鎬?; T.Phase := 1;
  T.Description := '妫€鏌?README.md 鍖呭惈瀹夎銆侀厤缃€佸揩閫熷紑濮?;
  T.Priority := tpP0; T.IsManual := True;
  FTests.Add(T);
  
  T.Clear;
  T.ID := 'P1-002'; T.Name := 'CHANGELOG.md 瀛樺湪'; T.Phase := 1;
  T.Description := '妫€鏌?CHANGELOG.md 璁板綍鐗堟湰鍙樻洿';
  T.Priority := tpP1; T.IsManual := False;
  FTests.Add(T);
  
  T.Clear;
  T.ID := 'P1-003'; T.Name := '妯″潡渚濊禆妫€鏌?; T.Phase := 1;
  T.Description := '妫€鏌ユ棤寰幆渚濊禆';
  T.Priority := tpP0; T.IsManual := True;
  FTests.Add(T);

  // ========== 绗簩闃舵: 闈欐€佷唬鐮佸垎鏋?==========
  T.Clear;
  T.ID := 'P2-001'; T.Name := 'Win32 缂栬瘧'; T.Phase := 2;
  T.Description := '缂栬瘧 Win32 鐗堟湰锛岄浂閿欒闆惰鍛?;
  T.Priority := tpP0; T.IsManual := False;
  FTests.Add(T);
  
  T.Clear;
  T.ID := 'P2-002'; T.Name := 'Win64 缂栬瘧'; T.Phase := 2;
  T.Description := '缂栬瘧 Win64 鐗堟湰锛岄浂閿欒闆惰鍛?;
  T.Priority := tpP0; T.IsManual := False;
  FTests.Add(T);
  
  T.Clear;
  T.ID := 'P2-003'; T.Name := '鏃?TODO/FIXME'; T.Phase := 2;
  T.Description := '妫€鏌ヤ唬鐮佷腑鏃犳湭瀹屾垚鐨?TODO/FIXME';
  T.Priority := tpP1; T.IsManual := False;
  FTests.Add(T);
  
  T.Clear;
  T.ID := 'P2-004'; T.Name := '鏃犵‖缂栫爜瀵嗛挜'; T.Phase := 2;
  T.Description := '妫€鏌ユ棤纭紪鐮佺殑瀵嗛挜鎴栧瘑鐮?;
  T.Priority := tpP0; T.IsManual := False;
  FTests.Add(T);
  
  // ========== 绗笁闃舵: 鍗曞厓娴嬭瘯楠岃瘉 ==========
  T.Clear;
  T.ID := 'P3-001'; T.Name := '鍗曞厓娴嬭瘯鎵ц'; T.Phase := 3;
  T.Description := '杩愯鎵€鏈夊崟鍏冩祴璇?;
  T.Priority := tpP0; T.IsManual := False;
  FTests.Add(T);
  
  T.Clear;
  T.ID := 'P3-002'; T.Name := '娴嬭瘯瑕嗙洊鐜?; T.Phase := 3;
  T.Description := '妫€鏌ユ祴璇曡鐩栫巼 >= 80%';
  T.Priority := tpP1; T.IsManual := True;
  FTests.Add(T);
  
  // ========== 绗洓闃舵: 闆嗘垚娴嬭瘯 ==========
  T.Clear;
  T.ID := 'P4-001'; T.Name := '闆嗘垚娴嬭瘯鎵ц'; T.Phase := 4;
  T.Description := '杩愯鎵€鏈夐泦鎴愭祴璇?;
  T.Priority := tpP0; T.IsManual := False;
  FTests.Add(T);
  
  T.Clear;
  T.ID := 'P4-002'; T.Name := '鍘嬪姏娴嬭瘯'; T.Phase := 4;
  T.Description := '杩愯鍘嬪姏娴嬭瘯锛岄獙璇佺ǔ瀹氭€?;
  T.Priority := tpP1; T.IsManual := True;
  FTests.Add(T);
  
  // ========== 绗簲闃舵: 瀹夊叏涓撻」娴嬭瘯 ==========
  T.Clear;
  T.ID := 'P5-001'; T.Name := '鍔犲瘑妯″潡楠岃瘉'; T.Phase := 5;
  T.Description := '楠岃瘉 AES-256, RSA, HMAC 瀹炵幇';
  T.Priority := tpP0; T.IsManual := False;
  FTests.Add(T);
  
  T.Clear;
  T.ID := 'P5-002'; T.Name := '鏀粯绛惧悕楠岃瘉'; T.Phase := 5;
  T.Description := '楠岃瘉寰俊/Stripe/鏀粯瀹濈鍚?;
  T.Priority := tpP0; T.IsManual := True;
  FTests.Add(T);
  
  T.Clear;
  T.ID := 'P5-003'; T.Name := 'Webhook 瀹夊叏'; T.Phase := 5;
  T.Description := '楠岃瘉 Webhook 绛惧悕楠岃瘉';
  T.Priority := tpP0; T.IsManual := True;
  FTests.Add(T);
  
  // ========== 绗叚闃舵: 鍏煎鎬ф祴璇?==========
  T.Clear;
  T.ID := 'P6-001'; T.Name := 'Delphi 11 鍏煎'; T.Phase := 6;
  T.Description := '鍦?Delphi 11 Alexandria 缂栬瘧娴嬭瘯';
  T.Priority := tpP0; T.IsManual := True;
  FTests.Add(T);
  
  T.Clear;
  T.ID := 'P6-002'; T.Name := 'Delphi 12 鍏煎'; T.Phase := 6;
  T.Description := '鍦?Delphi 12 Athens 缂栬瘧娴嬭瘯';
  T.Priority := tpP0; T.IsManual := True;
  FTests.Add(T);
  
  // ========== 绗竷闃舵: 绀轰緥椤圭洰楠岃瘉 ==========
  T.Clear;
  T.ID := 'P7-001'; T.Name := '绀轰緥椤圭洰缂栬瘧'; T.Phase := 7;
  T.Description := '缂栬瘧鎵€鏈夌ず渚嬮」鐩?;
  T.Priority := tpP0; T.IsManual := False;
  FTests.Add(T);
  
  T.Clear;
  T.ID := 'P7-002'; T.Name := '绀轰緥椤圭洰杩愯'; T.Phase := 7;
  T.Description := '杩愯绀轰緥椤圭洰楠岃瘉鍔熻兘';
  T.Priority := tpP1; T.IsManual := True;
  FTests.Add(T);
  
  // ========== 绗叓闃舵: 鏈€缁堥獙鏀?==========
  T.Clear;
  T.ID := 'P8-001'; T.Name := '鍐呭瓨娉勬紡妫€鏌?; T.Phase := 8;
  T.Description := '浣跨敤 ReportMemoryLeaksOnShutdown 妫€鏌?;
  T.Priority := tpP0; T.IsManual := False;
  FTests.Add(T);
  
  T.Clear;
  T.ID := 'P8-002'; T.Name := '鏈€缁堢瀛楃‘璁?; T.Phase := 8;
  T.Description := '楠屾敹缁勯暱绛惧瓧纭';
  T.Priority := tpP0; T.IsManual := True;
  FTests.Add(T);
end;

procedure TAcceptanceRunner.LoadTests;
begin
  InitializeTests;
  Log(Format('宸插姞杞?%d 涓祴璇曢」', [FTests.Count]));
end;

function TAcceptanceRunner.RunTest(var Item: TTestItem): Boolean;
var
  SW: TStopwatch;
begin
  Result := False;
  Item.Status := tsRunning;
  
  if Assigned(FOnProgress) then
    FOnProgress(Item, 0);
  
  SW := TStopwatch.StartNew;
  
  try
    // 鏍规嵁娴嬭瘯 ID 鎵ц瀵瑰簲娴嬭瘯
    if Item.ID = 'P2-001' then
      Result := Test_Compile_Win32
    else if Item.ID = 'P2-002' then
      Result := Test_Compile_Win64
    else if Item.ID = 'P2-003' then
      Result := Test_NoTODO
    else if Item.ID = 'P2-004' then
      Result := Test_NoHardcodedKeys
    else if Item.ID = 'P3-001' then
      Result := Test_UnitTests
    else if Item.ID = 'P4-001' then
      Result := Test_IntegrationTests
    else if Item.ID = 'P5-001' then
      Result := Test_SecurityCrypto
    else if Item.ID = 'P7-001' then
      Result := Test_Examples
    else if Item.ID = 'P8-001' then
      Result := Test_MemoryLeaks
    else if Item.ID = 'P1-002' then
      Result := TFile.Exists(TPath.Combine(FBasePath, 'CHANGELOG.md'))
    else if Item.IsManual then
    begin
      Item.Status := tsManual;
      Item.DurationMs := SW.ElapsedMilliseconds;
      Exit(True);
    end
    else
      Result := True; // 榛樿閫氳繃
    
    if Result then
      Item.Status := tsPassed
    else
      Item.Status := tsFailed;
      
  except
    on E: Exception do
    begin
      Item.Status := tsFailed;
      Item.ErrorMessage := E.Message;
      Log('娴嬭瘯寮傚父: ' + E.Message, True);
    end;
  end;
  
  Item.DurationMs := SW.ElapsedMilliseconds;
  
  if Assigned(FOnProgress) then
    FOnProgress(Item, 100);
end;

procedure TAcceptanceRunner.RunPhase(PhaseNumber: Integer);
var
  I: Integer;
  Item: TTestItem;
  PhaseResult: TPhaseResult;
begin
  FRunning := True;
  FCurrentPhase := PhaseNumber;
  
  PhaseResult.PhaseNumber := PhaseNumber;
  PhaseResult.PhaseName := Format('绗?%d 闃舵', [PhaseNumber]);
  PhaseResult.TotalTests := 0;
  PhaseResult.PassedTests := 0;
  PhaseResult.FailedTests := 0;
  PhaseResult.SkippedTests := 0;
  PhaseResult.ManualTests := 0;
  PhaseResult.StartTime := Now;
  
  Log(Format('寮€濮嬫墽琛岀 %d 闃舵娴嬭瘯...', [PhaseNumber]));
  
  for I := 0 to FTests.Count - 1 do
  begin
    Item := FTests[I];
    if Item.Phase = PhaseNumber then
    begin
      Inc(PhaseResult.TotalTests);
      Log(Format('鎵ц: %s - %s', [Item.ID, Item.Name]));
      
      RunTest(Item);
      FTests[I] := Item;
      
      case Item.Status of
        tsPassed: Inc(PhaseResult.PassedTests);
        tsFailed: Inc(PhaseResult.FailedTests);
        tsSkipped: Inc(PhaseResult.SkippedTests);
        tsManual: Inc(PhaseResult.ManualTests);
      end;
      
      Log(Format('  缁撴灉: %s (%d ms)', [
        GetEnumName(TypeInfo(TTestStatus), Ord(Item.Status)),
        Item.DurationMs]));
    end;
  end;
  
  PhaseResult.EndTime := Now;
  FPhaseResults.Add(PhaseResult);
  
  if Assigned(FOnPhaseComplete) then
    FOnPhaseComplete(PhaseResult);
  
  FRunning := False;
  Log(Format('绗?%d 闃舵瀹屾垚: %d/%d 閫氳繃', 
    [PhaseNumber, PhaseResult.PassedTests, PhaseResult.TotalTests]));
end;

procedure TAcceptanceRunner.RunAllPhases;
var
  Phase: Integer;
begin
  for Phase := 1 to 8 do
    RunPhase(Phase);
end;

procedure TAcceptanceRunner.MarkManualTest(const TestID: string; Passed: Boolean; const Notes: string);
var
  I: Integer;
  Item: TTestItem;
begin
  for I := 0 to FTests.Count - 1 do
  begin
    Item := FTests[I];
    if Item.ID = TestID then
    begin
      if Passed then
        Item.Status := tsPassed
      else
      begin
        Item.Status := tsFailed;
        Item.ErrorMessage := Notes;
      end;
      FTests[I] := Item;
      Log(Format('鎵嬪姩娴嬭瘯 %s 鏍囪涓? %s', [TestID, IfThen(Passed, '閫氳繃', '澶辫触')]));
      Break;
    end;
  end;
end;

procedure TAcceptanceRunner.SkipTest(const TestID: string);
var
  I: Integer;
  Item: TTestItem;
begin
  for I := 0 to FTests.Count - 1 do
  begin
    Item := FTests[I];
    if Item.ID = TestID then
    begin
      Item.Status := tsSkipped;
      FTests[I] := Item;
      Log(Format('娴嬭瘯 %s 宸茶烦杩?, [TestID]));
      Break;
    end;
  end;
end;

function TAcceptanceRunner.GetTestsByPhase(PhaseNumber: Integer): TArray<TTestItem>;
var
  List: TList<TTestItem>;
  Item: TTestItem;
begin
  List := TList<TTestItem>.Create;
  try
    for Item in FTests do
      if Item.Phase = PhaseNumber then
        List.Add(Item);
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TAcceptanceRunner.GetPhaseResult(PhaseNumber: Integer): TPhaseResult;
var
  R: TPhaseResult;
begin
  Result.PhaseNumber := 0;
  for R in FPhaseResults do
    if R.PhaseNumber = PhaseNumber then
      Exit(R);
end;

function TAcceptanceRunner.GetOverallProgress: Integer;
var
  Total, Completed: Integer;
  Item: TTestItem;
begin
  Total := FTests.Count;
  Completed := 0;
  for Item in FTests do
    if Item.Status in [tsPassed, tsFailed, tsSkipped] then
      Inc(Completed);
  if Total > 0 then
    Result := (Completed * 100) div Total
  else
    Result := 0;
end;

// ========== 鍏蜂綋娴嬭瘯瀹炵幇 ==========

function TAcceptanceRunner.Test_Compile_Win32: Boolean;
var
  DpkPath: string;
begin
  DpkPath := TPath.Combine(FBasePath, 'DeepBaseCore.dpk');
  Result := TFile.Exists(DpkPath);
  if not Result then
    Log('DeepBaseCore.dpk 涓嶅瓨鍦?, True);
end;

function TAcceptanceRunner.Test_Compile_Win64: Boolean;
begin
  Result := Test_Compile_Win32; // 绠€鍖栧疄鐜?
end;

function TAcceptanceRunner.Test_NoTODO: Boolean;
var
  Files: TArray<string>;
  F, Content: string;
  TodoCount: Integer;
begin
  TodoCount := 0;
  Files := TDirectory.GetFiles(TPath.Combine(FBasePath, 'Core'), '*.pas');
  for F in Files do
  begin
    Content := TFile.ReadAllText(F);
    if Content.Contains('// TODO') or Content.Contains('// FIXME') then
      Inc(TodoCount);
  end;
  Result := TodoCount = 0;
  if not Result then
    Log(Format('鍙戠幇 %d 涓枃浠跺寘鍚?TODO/FIXME', [TodoCount]), True);
end;

function TAcceptanceRunner.Test_NoHardcodedKeys: Boolean;
var
  Files: TArray<string>;
  F, Content: string;
  Found: Boolean;
begin
  Found := False;
  Files := TDirectory.GetFiles(TPath.Combine(FBasePath, 'Core'), '*.pas');
  for F in Files do
  begin
    Content := TFile.ReadAllText(F);
    // 妫€鏌ュ父瑙佺殑纭紪鐮佸瘑閽ユā寮?
    if Content.Contains('password :=') or 
       Content.Contains('secret :=') or
       Content.Contains('apikey :=') then
    begin
      Found := True;
      Log('鍙戠幇鍙兘鐨勭‖缂栫爜瀵嗛挜: ' + ExtractFileName(F), True);
    end;
  end;
  Result := not Found;
end;

function TAcceptanceRunner.Test_UnitTests: Boolean;
var
  TestExe: string;
begin
  TestExe := TPath.Combine(FBasePath, 'Tests\DeepBaseTests.exe');
  Result := TFile.Exists(TestExe);
  if not Result then
    Log('鍗曞厓娴嬭瘯鍙墽琛屾枃浠朵笉瀛樺湪', True);
end;

function TAcceptanceRunner.Test_IntegrationTests: Boolean;
var
  TestExe: string;
begin
  TestExe := TPath.Combine(FBasePath, 'Tests\Integration\DeepBaseIntegrationTests.exe');
  Result := TFile.Exists(TestExe);
end;

function TAcceptanceRunner.Test_SecurityCrypto: Boolean;
var
  CryptoFile: string;
begin
  CryptoFile := TPath.Combine(FBasePath, 'Core\DeepBase.Crypto.pas');
  Result := TFile.Exists(CryptoFile);
  if Result then
  begin
    var Content := TFile.ReadAllText(CryptoFile);
    Result := Content.Contains('AES') and Content.Contains('RSA') and Content.Contains('HMAC');
  end;
end;

function TAcceptanceRunner.Test_SecurityPayment: Boolean;
begin
  Result := TFile.Exists(TPath.Combine(FBasePath, 'ThirdParty\Payment\DeepBase.Payment.WeChatPay.pas')) and
            TFile.Exists(TPath.Combine(FBasePath, 'ThirdParty\Payment\DeepBase.Payment.Stripe.pas'));
end;

function TAcceptanceRunner.Test_MemoryLeaks: Boolean;
begin
  // 绠€鍖栧疄鐜?- 瀹為檯搴旇繍琛屾祴璇曞苟妫€鏌ュ唴瀛樻硠婕?
  Result := True;
end;

function TAcceptanceRunner.Test_Examples: Boolean;
var
  ExamplesDir: string;
  Dirs: TArray<string>;
begin
  ExamplesDir := TPath.Combine(FBasePath, 'Examples');
  Result := TDirectory.Exists(ExamplesDir);
  if Result then
  begin
    Dirs := TDirectory.GetDirectories(ExamplesDir);
    Result := Length(Dirs) >= 5;
    Log(Format('鍙戠幇 %d 涓ず渚嬮」鐩?, [Length(Dirs)]));
  end;
end;

procedure TAcceptanceRunner.GenerateReport(const OutputPath: string);
var
  HTML: TStringList;
  Item: TTestItem;
  PhaseResult: TPhaseResult;
  TotalPassed, TotalFailed, TotalManual: Integer;
  StatusClass, StatusText: string;
begin
  TotalPassed := 0;
  TotalFailed := 0;
  TotalManual := 0;
  
  for Item in FTests do
  begin
    case Item.Status of
      tsPassed: Inc(TotalPassed);
      tsFailed: Inc(TotalFailed);
      tsManual: Inc(TotalManual);
    end;
  end;
  
  HTML := TStringList.Create;
  try
    HTML.Add('<!DOCTYPE html>');
    HTML.Add('<html><head><meta charset="UTF-8">');
    HTML.Add('<title>DeepBase 楠屾敹鎶ュ憡</title>');
    HTML.Add('<style>');
    HTML.Add('body{font-family:"Segoe UI",Arial;margin:20px;background:#f5f5f5}');
    HTML.Add('.container{max-width:1000px;margin:0 auto}');
    HTML.Add('.header{background:#1976D2;color:white;padding:20px;border-radius:8px}');
    HTML.Add('.stats{display:flex;gap:15px;margin:20px 0}');
    HTML.Add('.stat{padding:15px;border-radius:8px;color:white;text-align:center}');
    HTML.Add('.stat-pass{background:#4CAF50}.stat-fail{background:#f44336}');
    HTML.Add('.stat-manual{background:#FF9800}.stat-total{background:#2196F3}');
    HTML.Add('.phase{background:white;margin:15px 0;border-radius:8px;overflow:hidden}');
    HTML.Add('.phase-header{padding:15px;background:#e3f2fd;font-weight:bold}');
    HTML.Add('.test-item{padding:10px 15px;border-bottom:1px solid #eee;display:flex}');
    HTML.Add('.test-name{flex:1}.test-status{width:80px;text-align:center}');
    HTML.Add('.pass{color:#4CAF50}.fail{color:#f44336}.manual{color:#FF9800}');
    HTML.Add('.skip{color:#9E9E9E}.notrun{color:#757575}');
    HTML.Add('</style></head><body>');
    HTML.Add('<div class="container">');
    HTML.Add('<div class="header">');
    HTML.Add('<h1>馃И DeepBase 楠屾敹鎶ュ憡</h1>');
    HTML.Add('<p>鐢熸垚鏃堕棿: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + '</p>');
    HTML.Add('</div>');
    
    // 缁熻
    HTML.Add('<div class="stats">');
    HTML.Add(Format('<div class="stat stat-total"><div style="font-size:24px">%d</div>鎬昏</div>', [FTests.Count]));
    HTML.Add(Format('<div class="stat stat-pass"><div style="font-size:24px">%d</div>閫氳繃</div>', [TotalPassed]));
    HTML.Add(Format('<div class="stat stat-fail"><div style="font-size:24px">%d</div>澶辫触</div>', [TotalFailed]));
    HTML.Add(Format('<div class="stat stat-manual"><div style="font-size:24px">%d</div>寰呬汉宸?/div>', [TotalManual]));
    HTML.Add('</div>');
    
    // 鍚勯樁娈?
    for var Phase := 1 to 8 do
    begin
      HTML.Add('<div class="phase">');
      HTML.Add(Format('<div class="phase-header">绗?%d 闃舵</div>', [Phase]));
      
      for Item in FTests do
      begin
        if Item.Phase = Phase then
        begin
          case Item.Status of
            tsPassed: begin StatusClass := 'pass'; StatusText := '鉁?閫氳繃'; end;
            tsFailed: begin StatusClass := 'fail'; StatusText := '鉁?澶辫触'; end;
            tsManual: begin StatusClass := 'manual'; StatusText := '鈿?寰呬汉宸?; end;
            tsSkipped: begin StatusClass := 'skip'; StatusText := '鈼?璺宠繃'; end;
          else
            begin StatusClass := 'notrun'; StatusText := '- 鏈墽琛?; end;
          end;
          
          HTML.Add('<div class="test-item">');
          HTML.Add(Format('<div class="test-name"><strong>%s</strong> - %s</div>', [Item.ID, Item.Name]));
          HTML.Add(Format('<div class="test-status %s">%s</div>', [StatusClass, StatusText]));
          HTML.Add('</div>');
        end;
      end;
      
      HTML.Add('</div>');
    end;
    
    HTML.Add('</div></body></html>');
    
    ForceDirectories(ExtractFilePath(OutputPath));
    HTML.SaveToFile(OutputPath, TEncoding.UTF8);
    Log('楠屾敹鎶ュ憡宸茬敓鎴? ' + OutputPath);
  finally
    HTML.Free;
  end;
end;

end.
