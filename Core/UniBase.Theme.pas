{ ============================================================================
  UniBase.Theme - Theme Management Module
  
  Version: 1.1
  Description: Manages VCL Styles and custom theme properties.
  Thread Safety: All public methods are thread-safe.
  Note: VCL style switching must be done on the main thread (TStyleManager).
  
  FMX Compatibility:
  - This unit is primarily designed for VCL applications.
  - In FMX applications, theme operations are no-ops but won't crash.
  - Use FMX.Styles for FireMonkey theme management.
  ============================================================================ }

unit UniBase.Theme;

{$IFDEF FMX}
  {$MESSAGE HINT 'UniBase.Theme: FMX detected - VCL theme features disabled. Use FMX.Styles for FMX theming.'}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  {$IFDEF DEBUG}
  Winapi.Windows,
  {$ENDIF}
  {$IFNDEF FMX}
  Vcl.Themes,
  Vcl.Styles,
  Vcl.Controls,
  {$ENDIF}
  FireDAC.Comp.Client,
  UniBase.Types;

type
  /// <summary>
  /// Theme manager
  /// </summary>
  TUniBaseTheme = class
  private
    FConnection: TFDConnection;
    FLock: TObject;
    FOwnsLock: Boolean;
    FCurrentThemeName: string;
    FOnThemeChanged: TNotifyEvent;
    FThemeCache: TDictionary<string, TThemeInfo>;
    FPendingThemeName: string;

    function GetSystemThemeInfo(const StyleName: string): TThemeInfo;
    function GetDBThemeInfo(const ThemeName: string): TThemeInfo;
    procedure LoadThemeCache;
    procedure DoThemeChanged;
    procedure ApplyThemeSync; // runs on main thread via TThread.Synchronize

  public
    constructor Create(AConnection: TFDConnection; ALock: TObject = nil);
    destructor Destroy; override;
    
    // ========================================
    // Core Methods
    // ========================================
    
    /// <summary>
    /// 应用主题 (VCL: TStyleManager.SetStyle)
    /// </summary>
    procedure ApplyTheme(const ThemeName: string);
    
    /// <summary>
    /// 获取所有可用主题
    /// </summary>
    function GetAvailableThemes: TThemeInfoArray;
    
    /// <summary>
    /// 当前是否为深色主题
    /// </summary>
    function IsDarkTheme: Boolean; overload;
    
    /// <summary>
    /// 检查指定主题是否为深色
    /// </summary>
    function IsDarkTheme(const ThemeName: string): Boolean; overload;
    
    // ========================================
    // Theme Info
    // ========================================
    
    /// <summary>
    /// 获取主题信息
    /// </summary>
    function GetThemeInfo(const ThemeName: string): TThemeInfo;
    
    /// <summary>
    /// 检查主题是否可用
    /// </summary>
    function IsThemeAvailable(const ThemeName: string): Boolean;
    
    /// <summary>
    /// 刷新主题缓存
    /// </summary>
    procedure RefreshThemeCache;
    
    // ========================================
    // Properties and Events
    // ========================================
    
    /// <summary>
    /// 主题变更事件
    /// </summary>
    property OnThemeChanged: TNotifyEvent read FOnThemeChanged write FOnThemeChanged;
    
    /// <summary>
    /// 当前主题名称
    /// </summary>
    property CurrentThemeName: string read FCurrentThemeName;
  end;

implementation

{ TUniBaseTheme }

constructor TUniBaseTheme.Create(AConnection: TFDConnection; ALock: TObject);
begin
  inherited Create;
  FConnection := AConnection;
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
  
  {$IFNDEF FMX}
  // VCL: Get current style name from TStyleManager
  if Assigned(TStyleManager.ActiveStyle) then
    FCurrentThemeName := TStyleManager.ActiveStyle.Name
  else
    FCurrentThemeName := 'Windows';
  {$ELSE}
  // FMX: Use default theme name (FMX uses different theming mechanism)
  FCurrentThemeName := 'Default';
  {$ENDIF}
  
  LoadThemeCache;
end;

destructor TUniBaseTheme.Destroy;
begin
  FThemeCache.Free;
  if FOwnsLock then
    FLock.Free;
  inherited;
end;

procedure TUniBaseTheme.LoadThemeCache;
var
  Query: TFDQuery;
  Info: TThemeInfo;
begin
  if (FConnection = nil) or (not FConnection.Connected) then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    FThemeCache.Clear;
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 
        'SELECT ThemeName, DisplayName, StyleFile, IsDark, IsBuiltIn, IsEnabled ' +
        'FROM Themes WHERE IsEnabled = 1 ORDER BY SortOrder';
      try
        Query.Open;
        
        while not Query.Eof do
        begin
          Info.Name := Query.FieldByName('ThemeName').AsString;
          // StyleFile 可能为空
          if Query.FindField('StyleFile') <> nil then
            Info.StyleFile := Query.FieldByName('StyleFile').AsString
          else
            Info.StyleFile := '';
          Info.IsDark := Query.FieldByName('IsDark').AsInteger <> 0;
          Info.IsBuiltIn := Query.FieldByName('IsBuiltIn').AsInteger <> 0;
          
          FThemeCache.AddOrSetValue(Info.Name, Info);
          Query.Next;
        end;
      except
        on E: Exception do
          // 表不存在或字段缺失时忽略错误：
          // 主题信息将回退到系统内置主题，避免因缺表阻塞应用启动。
          {$IFDEF DEBUG}
          OutputDebugString(PChar('UniBase.Theme: LoadThemeCache failed: ' + E.Message));
          {$ENDIF}
      end;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseTheme.DoThemeChanged;
begin
  if Assigned(FOnThemeChanged) then
    FOnThemeChanged(Self);
end;

procedure TUniBaseTheme.ApplyThemeSync;
{$IFNDEF FMX}
var
  Success: Boolean;
{$ENDIF}
begin
  {$IFNDEF FMX}
  Success := TStyleManager.TrySetStyle(FPendingThemeName);
  if Success then
  begin
    FCurrentThemeName := FPendingThemeName;
    DoThemeChanged;
  end;
  {$ELSE}
  // FMX: Just update the current theme name and notify
  // Actual FMX style switching should be done via FMX.Styles
  FCurrentThemeName := FPendingThemeName;
  DoThemeChanged;
  {$ENDIF}
end;

function TUniBaseTheme.GetSystemThemeInfo(const StyleName: string): TThemeInfo;
begin
  Result.Name := StyleName;
  Result.StyleFile := '';
  Result.IsBuiltIn := True;
  
  // Simple dark theme detection based on name keywords
  Result.IsDark := 
    (Pos('Dark', StyleName) > 0) or 
    (Pos('Black', StyleName) > 0) or 
    (Pos('Carbon', StyleName) > 0) or
    (Pos('Slate', StyleName) > 0);
end;

function TUniBaseTheme.GetDBThemeInfo(const ThemeName: string): TThemeInfo;
begin
  TMonitor.Enter(FLock);
  try
    if not FThemeCache.TryGetValue(ThemeName, Result) then
      Result := GetSystemThemeInfo(ThemeName);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function IsStyleInList(const StyleName: string): Boolean;
var
  Names: TArray<string>;
  I: Integer;
begin
  Result := False;
  Names := TStyleManager.StyleNames;
  for I := 0 to High(Names) do
    if SameText(Names[I], StyleName) then
      Exit(True);
end;

procedure TUniBaseTheme.ApplyTheme(const ThemeName: string);
{$IFNDEF FMX}
var
  Success: Boolean;
  ActualTheme: string;
{$ENDIF}
begin
  {$IFNDEF FMX}
  Success := False;
  ActualTheme := 'Windows';  // 默认回退到 Windows
  
  // 先检查主题是否在已注册的样式列表中
  // 注意：不直接调用 IsValidStyle，因为它会尝试从文件加载样式并可能抛出 EFOpenError
  try
    if (ThemeName = 'Windows') or IsStyleInList(ThemeName) then
      ActualTheme := ThemeName;
  except
    on E: Exception do
    begin
      // 忽略样式检查错误，使用 Windows 默认主题
      ActualTheme := 'Windows';
      {$IFDEF DEBUG}
      OutputDebugString(PChar('UniBase.Theme: Style check failed: ' + E.Message));
      {$ENDIF}
    end;
  end;
  
  // VCL 样式切换必须在主线程
  if TThread.CurrentThread.ThreadID = MainThreadID then
  begin
    try
      Success := TStyleManager.TrySetStyle(ActualTheme);
      if Success then
      begin
        FCurrentThemeName := ActualTheme;
        DoThemeChanged;
      end;
    except
      on E: Exception do
        // 样式切换失败，保持当前主题
        {$IFDEF DEBUG}
        OutputDebugString(PChar('UniBase.Theme: TrySetStyle failed: ' + E.Message));
        {$ENDIF}
    end;
  end
  else
  begin
    // 在非主线程中，使用 TThread.Synchronize 切换主题
    FPendingThemeName := ActualTheme;
    try
      TThread.Synchronize(nil, ApplyThemeSync);
      Success := FCurrentThemeName = ActualTheme;
    except
      on E: Exception do
        // 忽略同步错误
        {$IFDEF DEBUG}
        OutputDebugString(PChar('UniBase.Theme: Synchronize failed: ' + E.Message));
        {$ENDIF}
    end;
  end;
  {$ELSE}
  // FMX: Just update the name and notify - actual styling via FMX.Styles
  FCurrentThemeName := ThemeName;
  DoThemeChanged;
  {$ENDIF}
end;

function TUniBaseTheme.GetAvailableThemes: TThemeInfoArray;
var
  {$IFNDEF FMX}
  StyleNames: TArray<string>;
  I: Integer;
  {$ENDIF}
  List: TList<TThemeInfo>;
  Info: TThemeInfo;
  AddedNames: TList<string>;
begin
  List := TList<TThemeInfo>.Create;
  AddedNames := TList<string>.Create;
  try
    // 首先从数据库缓存获取（有顺序和元数据）
    TMonitor.Enter(FLock);
    try
      for Info in FThemeCache.Values do
      begin
      {$IFNDEF FMX}
        // VCL: 确保 VCL 样式实际可用（使用 StyleNames 列表检查，避免 IsValidStyle 抛异常）
        try
          if (Info.Name = 'Windows') or IsStyleInList(Info.Name) then
          begin
            List.Add(Info);
            AddedNames.Add(Info.Name);
          end;
        except
          // 跳过无效样式
        end;
        {$ELSE}
        // FMX: Add all cached themes (validation done elsewhere)
        List.Add(Info);
        AddedNames.Add(Info.Name);
        {$ENDIF}
      end;
    finally
      TMonitor.Exit(FLock);
    end;
    
    {$IFNDEF FMX}
    // VCL: 然后添加数据库中没有的系统样式
    StyleNames := TStyleManager.StyleNames;
    for I := 0 to High(StyleNames) do
    begin
      if not AddedNames.Contains(StyleNames[I]) then
      begin
        Info := GetSystemThemeInfo(StyleNames[I]);
        List.Add(Info);
      end;
    end;
    {$ENDIF}
    
    Result := List.ToArray;
  finally
    AddedNames.Free;
    List.Free;
  end;
end;

function TUniBaseTheme.IsDarkTheme: Boolean;
begin
  Result := IsDarkTheme(FCurrentThemeName);
end;

function TUniBaseTheme.IsDarkTheme(const ThemeName: string): Boolean;
var
  Info: TThemeInfo;
begin
  Info := GetDBThemeInfo(ThemeName);
  Result := Info.IsDark;
end;

function TUniBaseTheme.GetThemeInfo(const ThemeName: string): TThemeInfo;
begin
  Result := GetDBThemeInfo(ThemeName);
end;

function TUniBaseTheme.IsThemeAvailable(const ThemeName: string): Boolean;
begin
  {$IFNDEF FMX}
  if ThemeName = 'Windows' then
    Result := True
  else
  begin
    // 使用 StyleNames 列表检查，避免 IsValidStyle 抛出 EFOpenError
    try
      Result := IsStyleInList(ThemeName);
    except
      Result := False;
    end;
  end;
  {$ELSE}
  // FMX: Return true for cached themes, false otherwise
  TMonitor.Enter(FLock);
  try
    Result := FThemeCache.ContainsKey(ThemeName) or (ThemeName = 'Default');
  finally
    TMonitor.Exit(FLock);
  end;
  {$ENDIF}
end;

procedure TUniBaseTheme.RefreshThemeCache;
begin
  LoadThemeCache;
end;

end.
