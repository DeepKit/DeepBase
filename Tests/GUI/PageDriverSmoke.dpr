program PageDriverSmoke;

{$APPTYPE GUI}

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  uWVLoader,
  DeepBase.BrowserAutomation in '..\..\Features\DeepBase.BrowserAutomation.pas',
  DeepBase.Browser.Types in '..\..\Features\DeepBase.Browser.Types.pas',
  DeepBase.Browser.AutomationAdapter in '..\..\Features\DeepBase.Browser.AutomationAdapter.pas',
  DeepBase.Browser.Engine.WebView2 in '..\..\Features\DeepBase.Browser.Engine.WebView2.pas',
  DeepBase.Browser.PageDriver in '..\..\Features\DeepBase.Browser.PageDriver.pas';

type
  TSmokeForm = class(TForm)
  private
    FTopPanel: TPanel;
    FBrowserHost: TPanel;
    FLog: TMemo;
    FRunButton: TButton;
    FSessionObj: TWebView2BrowserSession;
    FSession: IBrowserAutomationSession;
    FLogFile: string;
    FFailed: Boolean;

    procedure BuildUI;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure RunButtonClick(Sender: TObject);
    procedure Log(const Msg: string);
    procedure Fail(const Msg: string);
    function WaitForLoader(TimeoutMs: Integer): Boolean;
    function WaitForSession(TimeoutMs: Integer): Boolean;
    function ParamValue(const Prefix: string): string;
    function FileUrl(const Path: string): string;
    procedure RunSmoke;
    procedure RunDomAutomation(const FixtureUrl: string);
    procedure InstallExtensionIfConfigured;
    procedure RunPageDriver;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

function SmokeLogPath(const FileName: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\..\TestResults\' + FileName));
  ForceDirectories(TPath.GetDirectoryName(Result));
end;

procedure WriteCrashLog(const Msg: string);
var
  Path: string;
begin
  Path := SmokeLogPath('PageDriverSmoke.crash.log');
  TFile.AppendAllText(Path,
    FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + '  ' + Msg + sLineBreak,
    TEncoding.UTF8);
end;

constructor TSmokeForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  BuildUI;
end;

destructor TSmokeForm.Destroy;
begin
  FSession := nil;
  FSessionObj.Free;
  inherited Destroy;
end;

procedure TSmokeForm.BuildUI;
begin
  Caption := 'DeepBase Native PageDriver WebView2 Smoke';
  OnClose := FormClose;
  Width := 1160;
  Height := 760;

  FTopPanel := TPanel.Create(Self);
  FTopPanel.Parent := Self;
  FTopPanel.Align := alTop;
  FTopPanel.Height := 44;
  FTopPanel.BevelOuter := bvNone;

  FRunButton := TButton.Create(Self);
  FRunButton.Parent := FTopPanel;
  FRunButton.Left := 12;
  FRunButton.Top := 8;
  FRunButton.Width := 140;
  FRunButton.Caption := 'Run Smoke';
  FRunButton.OnClick := RunButtonClick;

  FLog := TMemo.Create(Self);
  FLog.Parent := Self;
  FLog.Align := alRight;
  FLog.Width := 430;
  FLog.ScrollBars := ssVertical;
  FLog.WordWrap := False;

  FBrowserHost := TPanel.Create(Self);
  FBrowserHost.Parent := Self;
  FBrowserHost.Align := alClient;
  FBrowserHost.BevelOuter := bvNone;
end;

procedure TSmokeForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Application.Terminate;
end;

procedure TSmokeForm.RunButtonClick(Sender: TObject);
begin
  FRunButton.Enabled := False;
  try
    try
      RunSmoke;
    except
      on E: Exception do
      begin
        Fail(E.ClassName + ': ' + E.Message);
        raise;
      end;
    end;
  finally
    FRunButton.Enabled := True;
  end;
end;

procedure TSmokeForm.Log(const Msg: string);
begin
  FLog.Lines.Add(FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + Msg);
  FLog.Perform(EM_LINESCROLL, 0, FLog.Lines.Count);
  if FLogFile <> '' then
    TFile.AppendAllText(FLogFile,
      FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + '  ' + Msg + sLineBreak,
      TEncoding.UTF8);
  Application.ProcessMessages;
end;

procedure TSmokeForm.Fail(const Msg: string);
begin
  FFailed := True;
  ExitCode := 1;
  Log('FAIL: ' + Msg);
end;

function TSmokeForm.WaitForLoader(TimeoutMs: Integer): Boolean;
var
  Deadline: UInt64;
begin
  Deadline := GetTickCount64 + UInt64(TimeoutMs);
  repeat
    Application.ProcessMessages;
    Sleep(50);
    Result := (GlobalWebView2Loader <> nil) and GlobalWebView2Loader.Initialized;
    if Result then
      Exit;
    if (GlobalWebView2Loader <> nil) and GlobalWebView2Loader.InitializationError then
      Exit(False);
  until GetTickCount64 >= Deadline;
  Result := False;
end;

function TSmokeForm.WaitForSession(TimeoutMs: Integer): Boolean;
var
  Deadline: UInt64;
begin
  Deadline := GetTickCount64 + UInt64(TimeoutMs);
  repeat
    Application.ProcessMessages;
    Sleep(50);
    Result := (FSessionObj <> nil) and FSessionObj.Ready;
    if Result then
      Exit;
  until GetTickCount64 >= Deadline;
  Result := False;
end;

function TSmokeForm.ParamValue(const Prefix: string): string;
var
  I: Integer;
  S: string;
begin
  Result := '';
  for I := 1 to ParamCount do
  begin
    S := ParamStr(I);
    if SameText(Copy(S, 1, Length(Prefix)), Prefix) then
      Exit(Copy(S, Length(Prefix) + 1, MaxInt));
  end;
end;

function TSmokeForm.FileUrl(const Path: string): string;
begin
  Result := 'file:///' + StringReplace(TPath.GetFullPath(Path), '\', '/', [rfReplaceAll]);
end;

procedure TSmokeForm.RunSmoke;
var
  UserData: string;
  FixturePath: string;
begin
  FFailed := False;
  FLogFile := SmokeLogPath('PageDriverSmoke.log');
  if TFile.Exists(FLogFile) then
    TFile.Delete(FLogFile);

  FLog.Clear;
  Log('Starting WebView2 native PageDriver smoke.');

  UserData := TPath.Combine(TPath.GetTempPath, 'DeepBasePageDriverSmoke');
  ForceDirectories(UserData);
  InitializeWebView2(UserData, True);

  if not WaitForLoader(15000) then
  begin
    if GlobalWebView2Loader <> nil then
      Fail('WebView2 loader failed: ' + string(GlobalWebView2Loader.ErrorMessage))
    else
      Fail('WebView2 loader failed: GlobalWebView2Loader is nil');
    Exit;
  end;

  Log('WebView2 runtime: ' + string(GlobalWebView2Loader.InstalledRuntimeVersion));
  Log('WebView2 initialized.');

  if FSessionObj = nil then
  begin
    FSessionObj := TWebView2BrowserSession.Create(FBrowserHost);
    FSession := FSessionObj.AsAutomationSession;
  end;

  if not WaitForSession(15000) then
  begin
    Fail('WebView2 session did not become ready.');
    Exit;
  end;

  FixturePath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'PageDriverSmoke.fixture.html');
  if not TFile.Exists(FixturePath) then
    FixturePath := TPath.Combine(ExtractFilePath(Application.ExeName), 'PageDriverSmoke.fixture.html');

  Log('Fixture: ' + FixturePath);
  RunDomAutomation(FileUrl(FixturePath));
  RunPageDriver;
  if FFailed then
    ExitCode := 1
  else
  begin
    ExitCode := 0;
    Log('PASS: PageDriver smoke completed.');
  end;
end;

procedure TSmokeForm.RunDomAutomation(const FixtureUrl: string);
var
  Runner: TBrowserAutomationRunner;
  Results: TArray<TBrowserAutomationResult>;
  R: TBrowserAutomationResult;
  FinalText: string;
begin
  FinalText := '';
  Log('Running deterministic DOM automation.');
  Runner := TBrowserAutomationRunner.Create(FSession);
  try
    Results := Runner.Run([
      TBrowserAutomationAction.Navigate(FixtureUrl),
      TBrowserAutomationAction.WaitForSelector('#name'),
      TBrowserAutomationAction.InputText('#name', 'DeepBase'),
      TBrowserAutomationAction.Click('#apply'),
      TBrowserAutomationAction.GetText('#result')
    ]);

    for R in Results do
    begin
      if R.Success then
        Log('DOM action ok: ' + BrowserAutomationActionTypeToString(R.ActionType) + ' value=' + R.Value)
      else
        Fail('DOM action failed: ' + BrowserAutomationActionTypeToString(R.ActionType) + ' error=' + R.ErrorMessage);
      if R.ActionType = baatGetText then
        FinalText := R.Value;
    end;

    if FinalText <> 'Applied: DeepBase' then
      Fail('DOM result mismatch: ' + FinalText);
  finally
    Runner.Free;
  end;
end;

procedure TSmokeForm.InstallExtensionIfConfigured;
var
  ExtensionPath: string;
begin
  ExtensionPath := ParamValue('--extension=');
  if ExtensionPath = '' then
    ExtensionPath := GetEnvironmentVariable('PAGE_AGENT_EXTENSION_PATH');

  if ExtensionPath = '' then
  begin
    Log('No PageAgent extension path configured; skipping extension install.');
    Exit;
  end;

  if not TDirectory.Exists(ExtensionPath) then
  begin
    Fail('PageAgent extension path not found: ' + ExtensionPath);
    Exit;
  end;

  if FSessionObj.Browser.AddBrowserExtension(ExtensionPath) then
    Log('PageAgent extension install requested: ' + ExtensionPath)
  else
    Fail('PageAgent extension install request failed: ' + ExtensionPath);
end;

procedure TSmokeForm.RunPageDriver;
var
  Config: TPageDriverConfig;
  Driver: TPageDriver;
  ResultInfo: TPageDriverResult;
  Raw, Err: string;
  Image: TBytes;
  ScreenshotPath: string;
begin
  Log('Loading native PageDriver.');
  Config := TPageDriverConfig.Default;

  if GetEnvironmentVariable('PAGEDRIVER_BASE_URL') <> '' then
    Config.BaseURL := GetEnvironmentVariable('PAGEDRIVER_BASE_URL')
  else if GetEnvironmentVariable('PAGE_AGENT_BASE_URL') <> '' then
    Config.BaseURL := GetEnvironmentVariable('PAGE_AGENT_BASE_URL');

  if GetEnvironmentVariable('PAGEDRIVER_API_KEY') <> '' then
    Config.ApiKey := GetEnvironmentVariable('PAGEDRIVER_API_KEY')
  else if GetEnvironmentVariable('PAGE_AGENT_API_KEY') <> '' then
    Config.ApiKey := GetEnvironmentVariable('PAGE_AGENT_API_KEY');

  if GetEnvironmentVariable('PAGEDRIVER_MODEL') <> '' then
    Config.Model := GetEnvironmentVariable('PAGEDRIVER_MODEL')
  else if GetEnvironmentVariable('PAGE_AGENT_MODEL') <> '' then
    Config.Model := GetEnvironmentVariable('PAGE_AGENT_MODEL');

  if GetEnvironmentVariable('PAGEDRIVER_LANGUAGE') <> '' then
    Config.Language := GetEnvironmentVariable('PAGEDRIVER_LANGUAGE')
  else if GetEnvironmentVariable('PAGE_AGENT_LANGUAGE') <> '' then
    Config.Language := GetEnvironmentVariable('PAGE_AGENT_LANGUAGE');

  Log('Planner endpoint: ' + Config.BaseURL);
  Log('Planner model: ' + Config.Model);

  Driver := TPageDriver.Create(Config);
  try
    if not Driver.Load(FSession) then
    begin
      Fail('PageDriver load failed: ' + Driver.LastError);
      Exit;
    end;

    Log('Native PageDriver ready. Executing natural language instruction.');
    if Driver.Execute('Type PageDriver into the Name field and click the Apply button', ResultInfo) then
    begin
      Log('PageDriver result success=' + BoolToStr(ResultInfo.Success, True) +
        ' error=' + ResultInfo.ErrorMessage + ' raw=' + ResultInfo.RawResponse);
      if not ResultInfo.Success then
        Fail('PageDriver instruction returned failure: ' + ResultInfo.ErrorMessage);
    end
    else
      Fail('PageDriver execute bridge failed: ' + ResultInfo.ErrorMessage);

    if FSession.EvaluateScript('document.querySelector("#result").textContent', 5000, Raw, Err) then
    begin
      Log('Result text after PageDriver: ' + Raw)
    end
    else
      Fail('Result text read failed: ' + Err);

    if FSession.CaptureScreenshot(Image, Err) then
    begin
      ScreenshotPath := TPath.Combine(TPath.GetTempPath, 'DeepBasePageDriverSmoke.png');
      TFile.WriteAllBytes(ScreenshotPath, Image);
      Log('Screenshot: ' + ScreenshotPath);
    end
    else
      Fail('Screenshot failed: ' + Err);
  finally
    Driver.Free;
  end;
end;

var
  SmokeForm: TSmokeForm;
  AutoRun: Boolean;
  ExitAfterRun: Boolean;

begin
  try
    Application.Initialize;
    Application.MainFormOnTaskbar := True;
    SmokeForm := TSmokeForm.Create(nil);
    try
      SmokeForm.Show;
      AutoRun := FindCmdLineSwitch('autorun', True);
      ExitAfterRun := FindCmdLineSwitch('exit', True);

      if AutoRun then
      try
        SmokeForm.RunSmoke;
        if ExitAfterRun then
          Halt(ExitCode);
      except
        on E: Exception do
        begin
          WriteCrashLog(E.ClassName + ': ' + E.Message);
          ExitCode := 2;
          Halt(2);
        end;
      end;
      if ExitAfterRun then
        Halt(ExitCode)
      else
        Application.Run;
    finally
      SmokeForm.Free;
    end;
  except
    on E: Exception do
    begin
      WriteCrashLog(E.ClassName + ': ' + E.Message);
      ExitCode := 2;
      Halt(2);
    end;
  end;
end.
