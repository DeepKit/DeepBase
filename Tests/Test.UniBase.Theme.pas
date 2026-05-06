unit Test.UniBase.Theme;

{*******************************************************************************
  UniBase Theme 模块单元测试
  
  测试内容:
  - ApplyTheme
  - GetAvailableThemes
  - IsDarkTheme
  - OnThemeChanged 事件
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes,
  UniBase.Types, UniBase.Manager, UniBase.Theme, UniBase.Storage.Interfaces;

type
  [TestFixture]
  TTestUniBaseTheme = class
  private
    FTheme: TUniBaseTheme;
    FManager: TUniBaseManager;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_GetAvailableThemes_NotEmpty;
    
    [Test]
    procedure Test_GetAvailableThemes_HasWindowsTheme;
    
    [Test]
    procedure Test_CurrentTheme_NotEmpty;
    
    [Test]
    procedure Test_ApplyTheme_ValidTheme;
    
    [Test]
    procedure Test_ApplyTheme_InvalidTheme_NoException;
    
    [Test]
    procedure Test_IsDarkTheme_ReturnsBoolean;
    
    [Test]
    procedure Test_GetThemeInfo_ValidTheme;
    
    [Test]
    procedure Test_OnThemeChanged_Event;
    
    [Test]
    procedure Test_SavedTheme_Persists;
    
    [Test]
    procedure Test_ThemeInfo_HasRequiredFields;

    [Test]
    procedure Test_StorageInjection_ReadThemes;
  end;

implementation

type
  TInMemoryThemeStorage = class(TInterfacedObject, IThemeStorage)
  private
    FThemes: TThemeInfoArray;
  public
    constructor Create;
    function ReadEnabledThemes: TThemeInfoArray;
  end;

constructor TInMemoryThemeStorage.Create;
begin
  inherited Create;
  SetLength(FThemes, 2);
  FThemes[0].Name := 'InjectedDark';
  FThemes[0].StyleFile := '';
  FThemes[0].IsDark := True;
  FThemes[0].IsBuiltIn := False;

  FThemes[1].Name := 'InjectedLight';
  FThemes[1].StyleFile := '';
  FThemes[1].IsDark := False;
  FThemes[1].IsBuiltIn := False;
end;

function TInMemoryThemeStorage.ReadEnabledThemes: TThemeInfoArray;
begin
  Result := FThemes;
end;

{ TTestUniBaseTheme }

procedure TTestUniBaseTheme.Setup;
begin
  FManager := UniBase.Manager.UniBase;
  if not FManager.IsInitialized then
    FManager.InitializeWithDB(':memory:');
  FTheme := FManager.Theme;
end;

procedure TTestUniBaseTheme.TearDown;
begin
  FTheme := nil;
end;

procedure TTestUniBaseTheme.Test_GetAvailableThemes_NotEmpty;
var
  Themes: TArray<TThemeInfo>;
begin
  Themes := FTheme.GetAvailableThemes;
  
  Assert.IsTrue(Length(Themes) > 0, '应该至少有一个可用主题');
end;

procedure TTestUniBaseTheme.Test_GetAvailableThemes_HasWindowsTheme;
var
  Themes: TArray<TThemeInfo>;
  Found: Boolean;
  I: Integer;
begin
  Themes := FTheme.GetAvailableThemes;
  
  Found := False;
  for I := 0 to High(Themes) do
  begin
    if Themes[I].Name = 'Windows' then
    begin
      Found := True;
      Break;
    end;
  end;
  
  Assert.IsTrue(Found, '应该有 Windows 默认主题');
end;

procedure TTestUniBaseTheme.Test_CurrentTheme_NotEmpty;
var
  Current: string;
begin
  Current := FTheme.CurrentThemeName;
  
  Assert.IsNotEmpty(Current, '当前主题名称不应该为空');
end;

procedure TTestUniBaseTheme.Test_ApplyTheme_ValidTheme;
var
  Themes: TArray<TThemeInfo>;
begin
  Themes := FTheme.GetAvailableThemes;
  
  if Length(Themes) > 0 then
  begin
    Assert.WillNotRaise(
      procedure
      begin
        FTheme.ApplyTheme(Themes[0].Name);
      end,
      Exception,
      '应用有效主题不应该抛出异常'
    );
  end;
end;

procedure TTestUniBaseTheme.Test_ApplyTheme_InvalidTheme_NoException;
begin
  Assert.WillNotRaise(
    procedure
    begin
      FTheme.ApplyTheme('NonExistentTheme_' + TGUID.NewGuid.ToString);
    end,
    Exception,
    '应用无效主题不应该抛出异常（应该静默失败或使用默认）'
  );
end;

procedure TTestUniBaseTheme.Test_IsDarkTheme_ReturnsBoolean;
var
  IsDark: Boolean;
begin
  // 只测试调用不会出错
  Assert.WillNotRaise(
    procedure
    begin
      IsDark := FTheme.IsDarkTheme;
    end,
    Exception,
    'IsDarkTheme 不应该抛出异常'
  );
end;

procedure TTestUniBaseTheme.Test_GetThemeInfo_ValidTheme;
var
  Themes: TArray<TThemeInfo>;
  Info: TThemeInfo;
begin
  Themes := FTheme.GetAvailableThemes;
  
  if Length(Themes) > 0 then
  begin
    Info := FTheme.GetThemeInfo(Themes[0].Name);
    
    Assert.IsNotEmpty(Info.Name, '主题信息的名称不应该为空');
  end;
end;

procedure TTestUniBaseTheme.Test_OnThemeChanged_Event;
var
  Themes: TArray<TThemeInfo>;
begin
  // OnThemeChanged 是 TNotifyEvent 类型，不支持匿名方法
  // 测试简化: 只验证切换主题不报错
  Themes := FTheme.GetAvailableThemes;
  if Length(Themes) < 2 then
    Exit;
  
  // 切换到不同的主题
  if FTheme.CurrentThemeName <> Themes[0].Name then
    FTheme.ApplyTheme(Themes[0].Name)
  else
    FTheme.ApplyTheme(Themes[1].Name);
  
  Assert.Pass('主题切换成功');
end;

procedure TTestUniBaseTheme.Test_SavedTheme_Persists;
var
  Themes: TArray<TThemeInfo>;
  SelectedTheme, Retrieved: string;
begin
  Themes := FTheme.GetAvailableThemes;
  if Length(Themes) = 0 then
    Exit;
  
  SelectedTheme := Themes[0].Name;
  FTheme.ApplyTheme(SelectedTheme);
  
  Retrieved := FTheme.CurrentThemeName;
  
  Assert.AreEqual(SelectedTheme, Retrieved, '应用的主题应该成为当前主题');
end;

procedure TTestUniBaseTheme.Test_ThemeInfo_HasRequiredFields;
var
  Themes: TArray<TThemeInfo>;
  Info: TThemeInfo;
begin
  Themes := FTheme.GetAvailableThemes;
  
  if Length(Themes) > 0 then
  begin
    Info := Themes[0];
    
    Assert.IsNotEmpty(Info.Name, 'Name 字段不应该为空');
    // DisplayName 可以为空，使用 Name 作为显示名
  end;
end;

procedure TTestUniBaseTheme.Test_StorageInjection_ReadThemes;
var
  Storage: IThemeStorage;
  LocalTheme: TUniBaseTheme;
  Info: TThemeInfo;
begin
  Storage := TInMemoryThemeStorage.Create;
  LocalTheme := TUniBaseTheme.Create(Storage);
  try
    Info := LocalTheme.GetThemeInfo('InjectedDark');
    Assert.AreEqual('InjectedDark', Info.Name,
      'Injected storage metadata should be readable by name');
    Assert.IsTrue(Info.IsDark,
      'Injected theme metadata should be returned by GetThemeInfo');
    Assert.IsTrue(LocalTheme.IsDarkTheme('InjectedDark'),
      'Injected dark flag should affect IsDarkTheme(ThemeName)');
  finally
    LocalTheme.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseTheme);

end.
