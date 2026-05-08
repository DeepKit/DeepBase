{ ============================================================================
  Test.DeepBase.SplashScreen - Unit Tests for Splash Screen Module
  
  Test Coverage:
    - TSplashOptions record defaults
    - TSplashScreen static helper methods
  Note: GUI tests are limited due to VCL form dependency
  ============================================================================ }

unit Test.DeepBase.SplashScreen;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.UITypes,
  DeepBase.SplashScreen;

type
  [TestFixture]
  TTestSplashOptions = class
  public
    [Test]
    procedure Test_Default_ShowProgress;
    [Test]
    procedure Test_Default_ShowStatus;
    [Test]
    procedure Test_Default_FadeIn;
    [Test]
    procedure Test_Default_FadeOut;
    [Test]
    procedure Test_Default_FadeDuration;
    [Test]
    procedure Test_Default_StayOnTop;
    [Test]
    procedure Test_Default_AutoClose;
    [Test]
    procedure Test_Default_AutoCloseDelay;
    [Test]
    procedure Test_Default_StatusFont;
    [Test]
    procedure Test_Default_ProgressHeight;
    [Test]
    procedure Test_CustomOptions;
  end;

  [TestFixture]
  TTestSplashScreenStatic = class
  public
    [Test]
    procedure Test_IsVisible_InitiallyFalse;
    [Test]
    procedure Test_Hide_WhenNotShown;
    [Test]
    procedure Test_SetProgress_WhenNotShown;
    [Test]
    procedure Test_SetStatus_WhenNotShown;
    [Test]
    procedure Test_ProcessMessages;
  end;

  [TestFixture]
  TTestSplashOptionsCustomization = class
  public
    [Test]
    procedure Test_DisableFade;
    [Test]
    procedure Test_LongFadeDuration;
    [Test]
    procedure Test_NoProgress;
    [Test]
    procedure Test_NoStatus;
    [Test]
    procedure Test_AutoClose_WithDelay;
    [Test]
    procedure Test_NotStayOnTop;
    [Test]
    procedure Test_CustomProgressHeight;
  end;

implementation

{ TTestSplashOptions }

procedure TTestSplashOptions.Test_Default_ShowProgress;
var
  Options: TSplashOptions;
begin
  Options := TSplashOptions.Default;
  Assert.IsTrue(Options.ShowProgress);
end;

procedure TTestSplashOptions.Test_Default_ShowStatus;
var
  Options: TSplashOptions;
begin
  Options := TSplashOptions.Default;
  Assert.IsTrue(Options.ShowStatus);
end;

procedure TTestSplashOptions.Test_Default_FadeIn;
var
  Options: TSplashOptions;
begin
  Options := TSplashOptions.Default;
  Assert.IsTrue(Options.FadeIn);
end;

procedure TTestSplashOptions.Test_Default_FadeOut;
var
  Options: TSplashOptions;
begin
  Options := TSplashOptions.Default;
  Assert.IsTrue(Options.FadeOut);
end;

procedure TTestSplashOptions.Test_Default_FadeDuration;
var
  Options: TSplashOptions;
begin
  Options := TSplashOptions.Default;
  Assert.AreEqual(300, Options.FadeDuration);
end;

procedure TTestSplashOptions.Test_Default_StayOnTop;
var
  Options: TSplashOptions;
begin
  Options := TSplashOptions.Default;
  Assert.IsTrue(Options.StayOnTop);
end;

procedure TTestSplashOptions.Test_Default_AutoClose;
var
  Options: TSplashOptions;
begin
  Options := TSplashOptions.Default;
  Assert.IsFalse(Options.AutoClose);
end;

procedure TTestSplashOptions.Test_Default_AutoCloseDelay;
var
  Options: TSplashOptions;
begin
  Options := TSplashOptions.Default;
  Assert.AreEqual(3000, Options.AutoCloseDelay);
end;

procedure TTestSplashOptions.Test_Default_StatusFont;
var
  Options: TSplashOptions;
begin
  Options := TSplashOptions.Default;
  Assert.IsNull(Options.StatusFont);
end;

procedure TTestSplashOptions.Test_Default_ProgressHeight;
var
  Options: TSplashOptions;
begin
  Options := TSplashOptions.Default;
  Assert.AreEqual(6, Options.ProgressHeight);
end;

procedure TTestSplashOptions.Test_CustomOptions;
var
  Options: TSplashOptions;
begin
  Options.ShowProgress := False;
  Options.ShowStatus := False;
  Options.FadeIn := False;
  Options.FadeOut := False;
  Options.FadeDuration := 500;
  Options.StayOnTop := False;
  Options.AutoClose := True;
  Options.AutoCloseDelay := 5000;
  Options.ProgressHeight := 10;
  
  Assert.IsFalse(Options.ShowProgress);
  Assert.IsFalse(Options.ShowStatus);
  Assert.IsFalse(Options.FadeIn);
  Assert.IsFalse(Options.FadeOut);
  Assert.AreEqual(500, Options.FadeDuration);
  Assert.IsFalse(Options.StayOnTop);
  Assert.IsTrue(Options.AutoClose);
  Assert.AreEqual(5000, Options.AutoCloseDelay);
  Assert.AreEqual(10, Options.ProgressHeight);
end;

{ TTestSplashScreenStatic }

procedure TTestSplashScreenStatic.Test_IsVisible_InitiallyFalse;
begin
  // Initially, splash screen should not be visible
  Assert.IsFalse(TSplashScreen.IsVisible);
end;

procedure TTestSplashScreenStatic.Test_Hide_WhenNotShown;
begin
  // Calling Hide when not shown should not crash
  TSplashScreen.Hide;
  Assert.IsFalse(TSplashScreen.IsVisible);
end;

procedure TTestSplashScreenStatic.Test_SetProgress_WhenNotShown;
begin
  // Calling SetProgress when not shown should not crash
  TSplashScreen.SetProgress(50);
  Assert.Pass;
end;

procedure TTestSplashScreenStatic.Test_SetStatus_WhenNotShown;
begin
  // Calling SetStatus when not shown should not crash
  TSplashScreen.SetStatus('Loading...');
  Assert.Pass;
end;

procedure TTestSplashScreenStatic.Test_ProcessMessages;
begin
  // ProcessMessages should not crash even when not shown
  TSplashScreen.ProcessMessages;
  Assert.Pass;
end;

{ TTestSplashOptionsCustomization }

procedure TTestSplashOptionsCustomization.Test_DisableFade;
var
  Options: TSplashOptions;
begin
  Options := TSplashOptions.Default;
  Options.FadeIn := False;
  Options.FadeOut := False;
  
  Assert.IsFalse(Options.FadeIn);
  Assert.IsFalse(Options.FadeOut);
end;

procedure TTestSplashOptionsCustomization.Test_LongFadeDuration;
var
  Options: TSplashOptions;
begin
  Options := TSplashOptions.Default;
  Options.FadeDuration := 1000;
  
  Assert.AreEqual(1000, Options.FadeDuration);
end;

procedure TTestSplashOptionsCustomization.Test_NoProgress;
var
  Options: TSplashOptions;
begin
  Options := TSplashOptions.Default;
  Options.ShowProgress := False;
  
  Assert.IsFalse(Options.ShowProgress);
end;

procedure TTestSplashOptionsCustomization.Test_NoStatus;
var
  Options: TSplashOptions;
begin
  Options := TSplashOptions.Default;
  Options.ShowStatus := False;
  
  Assert.IsFalse(Options.ShowStatus);
end;

procedure TTestSplashOptionsCustomization.Test_AutoClose_WithDelay;
var
  Options: TSplashOptions;
begin
  Options := TSplashOptions.Default;
  Options.AutoClose := True;
  Options.AutoCloseDelay := 2000;
  
  Assert.IsTrue(Options.AutoClose);
  Assert.AreEqual(2000, Options.AutoCloseDelay);
end;

procedure TTestSplashOptionsCustomization.Test_NotStayOnTop;
var
  Options: TSplashOptions;
begin
  Options := TSplashOptions.Default;
  Options.StayOnTop := False;
  
  Assert.IsFalse(Options.StayOnTop);
end;

procedure TTestSplashOptionsCustomization.Test_CustomProgressHeight;
var
  Options: TSplashOptions;
begin
  Options := TSplashOptions.Default;
  Options.ProgressHeight := 12;
  
  Assert.AreEqual(12, Options.ProgressHeight);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSplashOptions);
  TDUnitX.RegisterTestFixture(TTestSplashScreenStatic);
  TDUnitX.RegisterTestFixture(TTestSplashOptionsCustomization);

end.
