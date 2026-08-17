{ ============================================================================
  DeepBase.Theme - Theme metadata and platform theme dispatch

  Version: 1.2
  Description: Keeps theme metadata in Core without depending on VCL/FMX.
               Platform packages can register adapters to apply real UI styles.
  Thread Safety: All public methods are thread-safe.
  ============================================================================ }

unit DeepBase.Theme;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Threading,
  {$IFDEF DEBUG}
  Winapi.Windows,
  {$ENDIF}
  DeepBase.Types,
  DeepBase.Logging,
  DeepBase.Storage.Interfaces,
  DeepBase.StorageFactory;

type
  TThemeApplyFunc = reference to function(const ThemeName: string;
    out ActiveThemeName: string): Boolean;
  TThemeListFunc = reference to function: TThemeInfoArray;
  TThemeExistsFunc = reference to function(const ThemeName: string): Boolean;
  TThemeCurrentFunc = reference to function: string;

  /// <summary>
  /// Theme manager. Core owns metadata/cache; UI packages own actual style APIs.
  /// </summary>
  TDeepBaseTheme = class
  private
    FConnection: TObject;
    FStorage: IThemeStorage;
    FLock: TObject;
    FOwnsLock: Boolean;
    FCurrentThemeName: string;
    FOnThemeChanged: TNotifyEvent;
    FThemeCache: TDictionary<string, TThemeInfo>;
    FPendingThemeName: string;
    class var FPlatformApplyTheme: TThemeApplyFunc;
    class var FPlatformListThemes: TThemeListFunc;
    class var FPlatformThemeExists: TThemeExistsFunc;
    class var FPlatformCurrentTheme: TThemeCurrentFunc;

    function GetSystemThemeInfo(const StyleName: string): TThemeInfo;
    function GetDBThemeInfo(const ThemeName: string): TThemeInfo;
    procedure LoadThemeCache;
    procedure DoThemeChanged;
    procedure ApplyThemeSync;

  public
    constructor Create(AConnection: TObject; ALock: TObject = nil); overload;
    constructor Create(const AStorage: IThemeStorage;
      ALock: TObject = nil); overload;
    destructor Destroy; override;

    class procedure SetConnectionStorageFactory(
      const AFactory: TFunc<TObject, IThemeStorage>); static;
    class procedure SetPlatformAdapter(const AApplyTheme: TThemeApplyFunc;
      const AListThemes: TThemeListFunc; const AThemeExists: TThemeExistsFunc;
      const ACurrentTheme: TThemeCurrentFunc); static;

    /// <summary>Apply a theme. Without a platform adapter this updates metadata only.</summary>
    procedure ApplyTheme(const ThemeName: string);

    /// <summary>Get DB-configured themes plus platform-provided themes.</summary>
    function GetAvailableThemes: TThemeInfoArray;

    function IsDarkTheme: Boolean; overload;
    function IsDarkTheme(const ThemeName: string): Boolean; overload;
    function GetThemeInfo(const ThemeName: string): TThemeInfo;
    function IsThemeAvailable(const ThemeName: string): Boolean;
    procedure RefreshThemeCache;

    property OnThemeChanged: TNotifyEvent read FOnThemeChanged write FOnThemeChanged;
    property CurrentThemeName: string read FCurrentThemeName;
  end;

implementation

{ TDeepBaseTheme }

constructor TDeepBaseTheme.Create(AConnection: TObject; ALock: TObject);
var
  LStorage: IThemeStorage;
begin
  LStorage := TConnectionStorageFactory<IThemeStorage>.Create(AConnection);
  if (LStorage = nil) and Assigned(AConnection) then
    raise EInvalidOp.Create(
      'No theme storage factory registered for connection-backed constructor. ' +
      'Include DeepBase.Persistence.Theme.FireDAC or DeepBase.Persistence.Manager.FireDAC.');
  Create(LStorage, ALock);
  FConnection := AConnection;
end;

constructor TDeepBaseTheme.Create(const AStorage: IThemeStorage;
  ALock: TObject);
begin
  inherited Create;
  FStorage := AStorage;
  if ALock <> nil then
  begin
    FLock := ALock;
    FOwnsLock := False;
  end
  else
  begin
    FLock := TObject.Create;
    FOwnsLock := True;
  end;
  FThemeCache := TDictionary<string, TThemeInfo>.Create;

  FCurrentThemeName := 'Windows';
  if Assigned(FPlatformCurrentTheme) then
  begin
    try
      FCurrentThemeName := FPlatformCurrentTheme();
    except
      FCurrentThemeName := 'Windows';
    end;
  end;

  LoadThemeCache;
end;

destructor TDeepBaseTheme.Destroy;
begin
  FreeAndNil(FThemeCache);
  if FOwnsLock then
    FreeAndNil(FLock);
  inherited;
end;

class procedure TDeepBaseTheme.SetConnectionStorageFactory(
  const AFactory: TFunc<TObject, IThemeStorage>);
begin
  TConnectionStorageFactory<IThemeStorage>.SetFactory(AFactory);
end;

class procedure TDeepBaseTheme.SetPlatformAdapter(
  const AApplyTheme: TThemeApplyFunc; const AListThemes: TThemeListFunc;
  const AThemeExists: TThemeExistsFunc; const ACurrentTheme: TThemeCurrentFunc);
begin
  FPlatformApplyTheme := AApplyTheme;
  FPlatformListThemes := AListThemes;
  FPlatformThemeExists := AThemeExists;
  FPlatformCurrentTheme := ACurrentTheme;
end;

procedure TDeepBaseTheme.LoadThemeCache;
var
  Themes: TThemeInfoArray;
  Info: TThemeInfo;
begin
  if not Assigned(FStorage) then
    Exit;

  TMonitor.Enter(FLock);
  try
    FThemeCache.Clear;

    try
      Themes := FStorage.ReadEnabledThemes;
      for Info in Themes do
        FThemeCache.AddOrSetValue(Info.Name, Info);
    except
      on E: Exception do
        {$IFDEF DEBUG}
        OutputDebugString(PChar('DeepBase.Theme: LoadThemeCache failed: ' + E.Message));
        {$ENDIF}
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseTheme.DoThemeChanged;
begin
  if Assigned(FOnThemeChanged) then
    FOnThemeChanged(Self);
end;

procedure TDeepBaseTheme.ApplyThemeSync;
var
  ActiveThemeName: string;
  Success: Boolean;
begin
  ActiveThemeName := FPendingThemeName;
  Success := True;

  try
    if Assigned(FPlatformApplyTheme) then
      Success := FPlatformApplyTheme(FPendingThemeName, ActiveThemeName);
  except
    on E: Exception do
    begin
      Success := False;
      if IsLoggerInitialized then
        Logger.Error('Theme platform apply failed: ' + E.Message);
    end;
  end;

  if Success then
  begin
    FCurrentThemeName := ActiveThemeName;
    DoThemeChanged;
  end;
end;

function TDeepBaseTheme.GetSystemThemeInfo(const StyleName: string): TThemeInfo;
var
  UpperName: string;
begin
  Result.Name := StyleName;
  Result.StyleFile := '';
  Result.IsBuiltIn := True;
  UpperName := StyleName.ToUpperInvariant;
  Result.IsDark :=
    UpperName.Contains('DARK') or
    UpperName.Contains('BLACK') or
    UpperName.Contains('CARBON') or
    UpperName.Contains('SLATE');
end;

function TDeepBaseTheme.GetDBThemeInfo(const ThemeName: string): TThemeInfo;
begin
  TMonitor.Enter(FLock);
  try
    if not FThemeCache.TryGetValue(ThemeName, Result) then
      Result := GetSystemThemeInfo(ThemeName);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseTheme.ApplyTheme(const ThemeName: string);
var
  ActualTheme: string;
begin
  ActualTheme := ThemeName;
  if ActualTheme = '' then
    ActualTheme := 'Windows';

  if Assigned(FPlatformThemeExists) then
  begin
    try
      if not FPlatformThemeExists(ActualTheme) then
        ActualTheme := 'Windows';
    except
      ActualTheme := 'Windows';
    end;
  end;

  FPendingThemeName := ActualTheme;
  if TThread.CurrentThread.ThreadID = MainThreadID then
    ApplyThemeSync
  else
    TTask.Run(
      procedure
      begin
        try
          TThread.Synchronize(nil, ApplyThemeSync);
        except
          on E: Exception do
            if IsLoggerInitialized then
              Logger.Error('Theme synchronization failed: ' + E.Message);
        end;
      end);
end;

function TDeepBaseTheme.GetAvailableThemes: TThemeInfoArray;
var
  List: TList<TThemeInfo>;
  AddedNames: TDictionary<string, Boolean>;
  Info: TThemeInfo;
  PlatformThemes: TThemeInfoArray;

  procedure AddTheme(const AInfo: TThemeInfo);
  var
    Key: string;
  begin
    if AInfo.Name = '' then
      Exit;
    Key := AInfo.Name.ToLowerInvariant;
    if AddedNames.ContainsKey(Key) then
      Exit;
    AddedNames.Add(Key, True);
    List.Add(AInfo);
  end;

begin
  List := TList<TThemeInfo>.Create;
  AddedNames := TDictionary<string, Boolean>.Create;
  try
    TMonitor.Enter(FLock);
    try
      for Info in FThemeCache.Values do
        AddTheme(Info);
    finally
      TMonitor.Exit(FLock);
    end;

    if Assigned(FPlatformListThemes) then
    begin
      try
        PlatformThemes := FPlatformListThemes();
        for Info in PlatformThemes do
          AddTheme(Info);
      except
        on E: Exception do
          if IsLoggerInitialized then
            Logger.Error('Theme platform list failed: ' + E.Message);
      end;
    end;

    if List.Count = 0 then
      AddTheme(GetSystemThemeInfo('Windows'));

    Result := List.ToArray;
  finally
    AddedNames.Free;
    List.Free;
  end;
end;

function TDeepBaseTheme.IsDarkTheme: Boolean;
begin
  Result := IsDarkTheme(FCurrentThemeName);
end;

function TDeepBaseTheme.IsDarkTheme(const ThemeName: string): Boolean;
var
  Info: TThemeInfo;
begin
  Info := GetDBThemeInfo(ThemeName);
  Result := Info.IsDark;
end;

function TDeepBaseTheme.GetThemeInfo(const ThemeName: string): TThemeInfo;
begin
  Result := GetDBThemeInfo(ThemeName);
end;

function TDeepBaseTheme.IsThemeAvailable(const ThemeName: string): Boolean;
begin
  if ThemeName = '' then
    Exit(False);

  TMonitor.Enter(FLock);
  try
    if FThemeCache.ContainsKey(ThemeName) then
      Exit(True);
  finally
    TMonitor.Exit(FLock);
  end;

  if Assigned(FPlatformThemeExists) then
  begin
    try
      Exit(FPlatformThemeExists(ThemeName));
    except
      Exit(False);
    end;
  end;

  Result := SameText(ThemeName, 'Windows');
end;

procedure TDeepBaseTheme.RefreshThemeCache;
begin
  LoadThemeCache;
end;

end.
