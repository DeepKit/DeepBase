{ ============================================================================
  Test.DeepBase.HB.Tray - Unit Tests for Tray Icon and Token Menu

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Tests for THbTrayMenu item structures, header formatting,
               check state toggling, destructive items, and badge counts.
  ============================================================================ }

unit Test.DeepBase.HB.Tray;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  DeepBase.HB.Core,
  DeepBase.HB.Tray.Types,
  DeepBase.VCL.HB.Tray;

type
  [TestFixture]
  TTestHbTrayMenu = class
  public
    [Test]
    procedure Test_TrayMenu_Creation_And_ItemCount;

    [Test]
    procedure Test_TrayMenu_CheckItem_Toggle;

    [Test]
    procedure Test_TrayMenu_HeaderData;

    [Test]
    procedure Test_TrayIcon_BadgeCount_Formatting;
  end;

implementation

{ TTestHbTrayMenu }

procedure TTestHbTrayMenu.Test_TrayMenu_Creation_And_ItemCount;
var
  Menu: THbTrayMenu;
  Item1, Item2, Item3: THbTrayMenuItem;
begin
  Menu := THbTrayMenu.Create(nil);
  try
    Item1 := Menu.AddItem('打开主控制台', nil, 'Enter', True);
    Item2 := Menu.AddSeparator;
    Item3 := Menu.AddDestructiveItem('退出应用', nil);

    Assert.AreEqual(Integer(3), Integer(Menu.Items.Count));
    Assert.AreEqual(Ord(tikItem), Ord(Item1.Kind));
    Assert.IsTrue(Item1.IsDefault);
    Assert.IsFalse(Item1.IsDestructive);

    Assert.AreEqual(Ord(tikSeparator), Ord(Item2.Kind));

    Assert.AreEqual(Ord(tikItem), Ord(Item3.Kind));
    Assert.IsTrue(Item3.IsDestructive);
  finally
    Menu.Free;
  end;
end;

procedure TTestHbTrayMenu.Test_TrayMenu_CheckItem_Toggle;
var
  Menu: THbTrayMenu;
  CheckItem: THbTrayMenuItem;
begin
  Menu := THbTrayMenu.Create(nil);
  try
    CheckItem := Menu.AddCheckItem('开机自动启动', nil, True);
    Assert.AreEqual(Ord(tikCheck), Ord(CheckItem.Kind));
    Assert.IsTrue(CheckItem.IsChecked);

    CheckItem.IsChecked := False;
    Assert.IsFalse(CheckItem.IsChecked);
  finally
    Menu.Free;
  end;
end;

procedure TTestHbTrayMenu.Test_TrayMenu_HeaderData;
var
  Menu: THbTrayMenu;
begin
  Menu := THbTrayMenu.Create(nil);
  try
    Menu.SetHeader('DeepCommerce 唤金', '● 在线服务中', 'v1.2.0', btSuccess, True);
    Assert.IsTrue(Menu.Header.Visible);
    Assert.AreEqual(string('DeepCommerce 唤金'), Menu.Header.Title);
    Assert.AreEqual(string('● 在线服务中'), Menu.Header.Subtitle);
    Assert.AreEqual(string('v1.2.0'), Menu.Header.VersionText);
    Assert.AreEqual(Ord(btSuccess), Ord(Menu.Header.Tone));
    Assert.IsTrue(Menu.Header.HasBreathingDot);
  finally
    Menu.Free;
  end;
end;

procedure TTestHbTrayMenu.Test_TrayIcon_BadgeCount_Formatting;
var
  Tray: THbTrayIcon;
begin
  Tray := THbTrayIcon.Create(nil);
  try
    Tray.ToolTip := 'DeepCommerce 唤金';
    Tray.BadgeCount := 3;
    Assert.AreEqual(Integer(3), Integer(Tray.BadgeCount));
    Assert.IsTrue(Pos('3 条新通知', Tray.ToolTip) > 0);
  finally
    Tray.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestHbTrayMenu);

end.
