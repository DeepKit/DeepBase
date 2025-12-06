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
  UniBase.Types, UniBase.Manager, UniBase.Theme;

type
  [TestFixture]
  TTestUniBaseTheme = class
  private
    FTheme: TUniBaseTheme;
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
  end;

implementation

{ TTestUniBaseTheme }

procedure TTestUniBaseTheme.Setup;
begin
  if not UniBase.IsInitialized then
    UniBase.InitializeWithDB(':memory:');
  
  FTheme := UniBase.Theme;
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
  Current := FTheme.CurrentTheme;
  
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
  EventFired: Boolean;
  NewThemeName: string;
  Themes: TArray<TThemeInfo>;
begin
  Themes := FTheme.GetAvailableThemes;
  if Length(Themes) < 2 then
    Exit; // 需要至少 2 个主题来测试切换
  
  EventFired := False;
  NewThemeName := '';
  
  FTheme.OnThemeChanged := 
    procedure(const ATheme: string)
    begin
      EventFired := True;
      NewThemeName := ATheme;
    end;
  
  try
    // 切换到不同的主题
    if FTheme.CurrentTheme <> Themes[0].Name then
      FTheme.ApplyTheme(Themes[0].Name)
    else
      FTheme.ApplyTheme(Themes[1].Name);
    
    Assert.IsTrue(EventFired, 'OnThemeChanged 事件应该被触发');
    Assert.IsNotEmpty(NewThemeName, '事件应该传递主题名称');
  finally
    FTheme.OnThemeChanged := nil;
  end;
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
  
  Retrieved := FTheme.CurrentTheme;
  
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

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseTheme);

end.
