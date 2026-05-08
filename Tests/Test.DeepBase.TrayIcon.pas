{ ============================================================================
  Test.DeepBase.TrayIcon - Unit Tests for System Tray Module
  ============================================================================ }

unit Test.DeepBase.TrayIcon;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Winapi.Windows,
  DeepBase.TrayIcon;

type
  [TestFixture]
  TTestTrayIconProperties = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Active_Default_False;
    [Test]
    procedure Test_Callbacks_Default_Nil;
    [Test]
    procedure Test_Hide_When_Not_Active_NoException;
    [Test]
    procedure Test_HideBalloon_When_Not_Active_NoException;
  end;

  [TestFixture]
  TTestTrayIconShowHide = class
  public
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Show_Sets_Active;
    [Test]
    procedure Test_Hide_Clears_Active;
    [Test]
    procedure Test_Show_With_Default_Icon;
    [Test]
    procedure Test_UpdateToolTip;
    [Test]
    procedure Test_Show_Twice_NoException;
    [Test]
    procedure Test_Hide_Twice_NoException;
    [Test]
    procedure Test_Hide_Clears_Callbacks;
  end;

  [TestFixture]
  TTestTrayIconCallbacks = class
  private
    FDoubleClickFired: Boolean;
    FMouseDownFired: Boolean;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_OnDoubleClick_CanBeAssigned;
    [Test]
    procedure Test_OnMouseDown_CanBeAssigned;
    [Test]
    procedure Test_SetPopupMenuAdapter_AcceptsNil;
  end;

  [TestFixture]
  TTestIPopupMenuAdapter = class
  public
    [Test]
    procedure Test_IPopupMenuAdapter_GUID;
  end;

implementation

{ TTestTrayIconProperties }

procedure TTestTrayIconProperties.Setup;
begin
  if TTrayIcon.Active then
    TTrayIcon.Hide;
end;

procedure TTestTrayIconProperties.TearDown;
begin
  if TTrayIcon.Active then
    TTrayIcon.Hide;
end;

procedure TTestTrayIconProperties.Test_Active_Default_False;
begin
  Assert.IsFalse(TTrayIcon.Active);
end;

procedure TTestTrayIconProperties.Test_Callbacks_Default_Nil;
begin
  Assert.IsFalse(Assigned(TTrayIcon.OnDoubleClick));
  Assert.IsFalse(Assigned(TTrayIcon.OnBalloonClick));
  Assert.IsFalse(Assigned(TTrayIcon.OnMouseDown));
end;

procedure TTestTrayIconProperties.Test_Hide_When_Not_Active_NoException;
begin
  TTrayIcon.Hide;
  Assert.Pass;
end;

procedure TTestTrayIconProperties.Test_HideBalloon_When_Not_Active_NoException;
begin
  TTrayIcon.HideBalloon;
  Assert.Pass;
end;

{ TTestTrayIconShowHide }

procedure TTestTrayIconShowHide.TearDown;
begin
  if TTrayIcon.Active then
    TTrayIcon.Hide;
end;

procedure TTestTrayIconShowHide.Test_Show_Sets_Active;
begin
  TTrayIcon.Show('Test App');
  Assert.IsTrue(TTrayIcon.Active);
end;

procedure TTestTrayIconShowHide.Test_Hide_Clears_Active;
begin
  TTrayIcon.Show('Test App');
  TTrayIcon.Hide;
  Assert.IsFalse(TTrayIcon.Active);
end;

procedure TTestTrayIconShowHide.Test_Show_With_Default_Icon;
begin
  TTrayIcon.Show('Test', LoadIcon(0, IDI_APPLICATION));
  Assert.IsTrue(TTrayIcon.Active);
end;

procedure TTestTrayIconShowHide.Test_UpdateToolTip;
begin
  TTrayIcon.Show('Original');
  TTrayIcon.UpdateToolTip('Updated');
  Assert.IsTrue(TTrayIcon.Active);
end;

procedure TTestTrayIconShowHide.Test_Show_Twice_NoException;
begin
  TTrayIcon.Show('First');
  TTrayIcon.Show('Second');
  Assert.IsTrue(TTrayIcon.Active);
end;

procedure TTestTrayIconShowHide.Test_Hide_Twice_NoException;
begin
  TTrayIcon.Show('Test');
  TTrayIcon.Hide;
  TTrayIcon.Hide;
  Assert.IsFalse(TTrayIcon.Active);
end;

procedure TTestTrayIconShowHide.Test_Hide_Clears_Callbacks;
begin
  TTrayIcon.OnDoubleClick :=
    procedure
    begin
    end;
  TTrayIcon.OnBalloonClick :=
    procedure
    begin
    end;
  TTrayIcon.OnMouseDown :=
    procedure(Button: Integer; X, Y: Integer)
    begin
    end;
  TTrayIcon.Show('Test');
  TTrayIcon.Hide;
  Assert.IsFalse(TTrayIcon.Active);
  Assert.IsFalse(Assigned(TTrayIcon.OnDoubleClick));
  Assert.IsFalse(Assigned(TTrayIcon.OnBalloonClick));
  Assert.IsFalse(Assigned(TTrayIcon.OnMouseDown));
end;

{ TTestTrayIconCallbacks }

procedure TTestTrayIconCallbacks.Setup;
begin
  FDoubleClickFired := False;
  FMouseDownFired := False;
  if TTrayIcon.Active then
    TTrayIcon.Hide;
end;

procedure TTestTrayIconCallbacks.TearDown;
begin
  TTrayIcon.OnDoubleClick := nil;
  TTrayIcon.OnMouseDown := nil;
  if TTrayIcon.Active then
    TTrayIcon.Hide;
end;

procedure TTestTrayIconCallbacks.Test_OnDoubleClick_CanBeAssigned;
begin
  TTrayIcon.OnDoubleClick :=
    procedure
    begin
      FDoubleClickFired := True;
    end;
  Assert.IsTrue(Assigned(TTrayIcon.OnDoubleClick));
end;

procedure TTestTrayIconCallbacks.Test_OnMouseDown_CanBeAssigned;
begin
  TTrayIcon.OnMouseDown :=
    procedure(Button: Integer; X, Y: Integer)
    begin
      FMouseDownFired := True;
    end;
  Assert.IsTrue(Assigned(TTrayIcon.OnMouseDown));
end;

procedure TTestTrayIconCallbacks.Test_SetPopupMenuAdapter_AcceptsNil;
begin
  TTrayIcon.SetPopupMenuAdapter(nil);
  Assert.Pass;
end;

{ TTestIPopupMenuAdapter }

procedure TTestIPopupMenuAdapter.Test_IPopupMenuAdapter_GUID;
var
  GUID: TGUID;
  EmptyGUID: TGUID;
begin
  GUID := IPopupMenuAdapter;
  EmptyGUID := TGUID.Empty;
  Assert.AreNotEqual(EmptyGUID.ToString, GUID.ToString);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestTrayIconProperties);
  TDUnitX.RegisterTestFixture(TTestTrayIconShowHide);
  TDUnitX.RegisterTestFixture(TTestTrayIconCallbacks);
  TDUnitX.RegisterTestFixture(TTestIPopupMenuAdapter);

end.
