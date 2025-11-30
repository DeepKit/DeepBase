unit CtrlMain;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  TConfigItem = record
    Key: string;
    Value: string;
    DefaultValue: string;
    Description: string;
  end;

  TLogFileInfo = record
    FileName: string;
    FilePath: string;
    FileSize: Int64;
    ModifiedTime: TDateTime;
  end;

  ICtrlMain = interface
    ['{00000001-0000-0000-0000-000000000001}']
    procedure Initialize;
    function GetRootPath: string;
    function GetConfigGroups: TArray<string>;
    function GetConfigsInGroup(const AGroup: string): TArray<TConfigItem>;
    function GetConfigValue(const AKey: string): string;
    procedure SetConfigValue(const AKey, AValue: string);
    function ValidateConfig(const AKey, AValue: string): Boolean;
    function GetLogFileList: TArray<TLogFileInfo>;
    function LoadLogContent(const AFilePath: string; AMaxLines: Integer): TArray<string>;
    function FilterLogLines(const ALines: TArray<string>; const AKeyword: string; const ALevel: string): TArray<string>;
    function PerformSelfCheck: string;
  end;

  TCtrlMain = class(TInterfacedObject, ICtrlMain)
  private
    FRootPath: string;
    FConfigGroups: TStringList;
    procedure LoadConfigGroups;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Initialize;
    function GetRootPath: string;
    function GetConfigGroups: TArray<string>;
    function GetConfigsInGroup(const AGroup: string): TArray<TConfigItem>;
    function GetConfigValue(const AKey: string): string;
    procedure SetConfigValue(const AKey, AValue: string);
    function ValidateConfig(const AKey, AValue: string): Boolean;
    function GetLogFileList: TArray<TLogFileInfo>;
    function LoadLogContent(const AFilePath: string; AMaxLines: Integer): TArray<string>;
    function FilterLogLines(const ALines: TArray<string>; const AKeyword: string; const ALevel: string): TArray<string>;
    function PerformSelfCheck: string;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.Types;

constructor TCtrlMain.Create;
begin
  inherited Create;
  FConfigGroups := TStringList.Create;
  FRootPath := '';
end;

destructor TCtrlMain.Destroy;
begin
  FConfigGroups.Free;
  inherited Destroy;
end;

procedure TCtrlMain.Initialize;
begin
  FRootPath := ExtractFilePath(ParamStr(0));
  LoadConfigGroups;
end;

function TCtrlMain.GetRootPath: string;
begin
  Result := FRootPath;
end;

procedure TCtrlMain.LoadConfigGroups;
begin
  FConfigGroups.Clear;
  FConfigGroups.Add('App');
  FConfigGroups.Add('UI');
  FConfigGroups.Add('Log');
  FConfigGroups.Add('Database');
end;

function TCtrlMain.GetConfigGroups: TArray<string>;
var
  i: Integer;
begin
  SetLength(Result, FConfigGroups.Count);
  for i := 0 to FConfigGroups.Count - 1 do
    Result[i] := FConfigGroups[i];
end;

function TCtrlMain.GetConfigsInGroup(const AGroup: string): TArray<TConfigItem>;
var
  ConfigItems: TList<TConfigItem>;
  Item: TConfigItem;
begin
  ConfigItems := TList<TConfigItem>.Create;
  try
    if AGroup = 'App' then
    begin
      Item.Key := 'App.Name';
      Item.Value := 'UniBaseRun';
      Item.DefaultValue := 'UniBaseRun';
      Item.Description := 'Application name';
      ConfigItems.Add(Item);
      Item.Key := 'App.Version';
      Item.Value := '0.1.0-dev';
      Item.DefaultValue := '0.1.0';
      Item.Description := 'Application version';
      ConfigItems.Add(Item);
    end
    else if AGroup = 'UI' then
    begin
      Item.Key := 'UI.Theme';
      Item.Value := 'Light';
      Item.DefaultValue := 'Light';
      Item.Description := 'UI theme (Light/Dark)';
      ConfigItems.Add(Item);
      Item.Key := 'UI.Language';
      Item.Value := 'en-US';
      Item.DefaultValue := 'en-US';
      Item.Description := 'UI language';
      ConfigItems.Add(Item);
    end
    else if AGroup = 'Log' then
    begin
      Item.Key := 'Log.Level';
      Item.Value := 'Info';
      Item.DefaultValue := 'Info';
      Item.Description := 'Log level (Trace/Debug/Info/Warn/Error)';
      ConfigItems.Add(Item);
      Item.Key := 'Log.MaxSize';
      Item.Value := '10485760';
      Item.DefaultValue := '10485760';
      Item.Description := 'Maximum log file size (bytes)';
      ConfigItems.Add(Item);
    end;
    Result := ConfigItems.ToArray;
  finally
    ConfigItems.Free;
  end;
end;

function TCtrlMain.GetConfigValue(const AKey: string): string;
begin
  if AKey = 'App.Name' then
    Result := 'UniBaseRun'
  else if AKey = 'App.Version' then
    Result := '0.1.0-dev'
  else if AKey = 'UI.Theme' then
    Result := 'Light'
  else if AKey = 'UI.Language' then
    Result := 'en-US'
  else if AKey = 'Log.Level' then
    Result := 'Info'
  else if AKey = 'Log.MaxSize' then
    Result := '10485760'
  else
    Result := '';
end;

procedure TCtrlMain.SetConfigValue(const AKey, AValue: string);
begin
  if ValidateConfig(AKey, AValue) then
  begin
  end;
end;

function TCtrlMain.ValidateConfig(const AKey, AValue: string): Boolean;
begin
  Result := True;
  if AKey = 'Log.MaxSize' then
  begin
    try
      StrToInt64(AValue);
      Result := True;
    except
      Result := False;
    end;
  end;
end;

function TCtrlMain.GetLogFileList: TArray<TLogFileInfo>;
var
  LogDir: string;
  LogFiles: TArray<string>;
  LogItems: TList<TLogFileInfo>;
  FileInfo: TLogFileInfo;
  i: Integer;
begin
  LogItems := TList<TLogFileInfo>.Create;
  try
    LogDir := TPath.Combine(FRootPath, 'logs');
    if TDirectory.Exists(LogDir) then
    begin
      LogFiles := TDirectory.GetFiles(LogDir, '*.log');
      for i := 0 to Length(LogFiles) - 1 do
      begin
        FileInfo.FileName := TPath.GetFileName(LogFiles[i]);
        FileInfo.FilePath := LogFiles[i];
        FileInfo.FileSize := 0;
        FileInfo.ModifiedTime := Now;
        LogItems.Add(FileInfo);
      end;
    end;
    Result := LogItems.ToArray;
  finally
    LogItems.Free;
  end;
end;

function TCtrlMain.LoadLogContent(const AFilePath: string; AMaxLines: Integer): TArray<string>;
var
  LogLines: TStringList;
  StartIdx: Integer;
  i: Integer;
begin
  LogLines := TStringList.Create;
  try
    if TFile.Exists(AFilePath) then
    begin
      LogLines.LoadFromFile(AFilePath);
      if LogLines.Count > AMaxLines then
        StartIdx := LogLines.Count - AMaxLines
      else
        StartIdx := 0;
      SetLength(Result, LogLines.Count - StartIdx);
      for i := StartIdx to LogLines.Count - 1 do
        Result[i - StartIdx] := LogLines[i];
    end
    else
      Result := nil;
  finally
    LogLines.Free;
  end;
end;

function TCtrlMain.FilterLogLines(const ALines: TArray<string>; const AKeyword: string; const ALevel: string): TArray<string>;
var
  FilteredLines: TList<string>;
  i: Integer;
begin
  FilteredLines := TList<string>.Create;
  try
    for i := 0 to Length(ALines) - 1 do
    begin
      if (AKeyword = '') or (Pos(AKeyword, ALines[i]) > 0) then
      begin
        if (ALevel = '') or (Pos('[' + ALevel + ']', ALines[i]) > 0) then
          FilteredLines.Add(ALines[i]);
      end;
    end;
    Result := FilteredLines.ToArray;
  finally
    FilteredLines.Free;
  end;
end;

function TCtrlMain.PerformSelfCheck: string;
var
  CheckResults: TStringList;
  ConfigPath, LogsPath: string;
begin
  CheckResults := TStringList.Create;
  try
    CheckResults.Add('=== UniBaseRun Self-Check Results ===');
    CheckResults.Add('');
    if TDirectory.Exists(FRootPath) then
      CheckResults.Add('OK Root path exists: ' + FRootPath)
    else
      CheckResults.Add('FAIL Root path NOT found: ' + FRootPath);
    ConfigPath := TPath.Combine(FRootPath, 'config.db');
    if TFile.Exists(ConfigPath) then
      CheckResults.Add('OK config.db exists')
    else
      CheckResults.Add('WARN config.db NOT found');
    LogsPath := TPath.Combine(FRootPath, 'logs');
    if TDirectory.Exists(LogsPath) then
    begin
      CheckResults.Add('OK logs directory exists');
      CheckResults.Add('  Files: ' + IntToStr(Length(TDirectory.GetFiles(LogsPath))));
    end
    else
      CheckResults.Add('WARN logs directory NOT found');
    CheckResults.Add('');
    CheckResults.Add('=== End of Self-Check ===');
    Result := CheckResults.Text;
  finally
    CheckResults.Free;
  end;
end;

end.
