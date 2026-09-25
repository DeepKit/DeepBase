{ ============================================================================
  Test.DeepBase.HBThemeListenerIdentity - A2-10 regression

  THbTheme listener collection must key on full TMethod identity (Code +
  Data). With the old default comparer only Code was considered, so a second
  instance registering the same-named method was silently dropped as a
  duplicate and RemoveListener could detach the wrong instance.
  ============================================================================ }

unit Test.DeepBase.HBThemeListenerIdentity;

interface

uses
  System.Classes,
  DUnitX.TestFramework,
  DeepBase.HB.Core;

type
  THbHitListener = class
  public
    Hits: Integer;
    procedure OnChanged(Sender: TObject);
  end;

  [TestFixture]
  TTestHBThemeListenerIdentityA210 = class
  private
    FA, FB: THbHitListener;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_TwoInstances_SameMethodIdentity_BothNotified;

    [Test]
    procedure Test_RemoveOnlyDetachesMatchingInstance;

    [Test]
    procedure Test_SameInstanceRegisteredTwice_Deduped;
  end;

implementation

{ THbHitListener }

procedure THbHitListener.OnChanged(Sender: TObject);
begin
  Inc(Hits);
end;

{ TTestHBThemeListenerIdentityA210 }

procedure TTestHBThemeListenerIdentityA210.SetUp;
begin
  FA := THbHitListener.Create;
  FB := THbHitListener.Create;
end;

procedure TTestHBThemeListenerIdentityA210.TearDown;
begin
  // idempotent even when a test already removed its registrations
  THbTheme.RemoveListener(FA.OnChanged);
  THbTheme.RemoveListener(FB.OnChanged);
  FA.Free;
  FB.Free;
end;

procedure TTestHBThemeListenerIdentityA210.Test_TwoInstances_SameMethodIdentity_BothNotified;
begin
  THbTheme.AddListener(FA.OnChanged);
  THbTheme.AddListener(FB.OnChanged);
  try
    THbTheme.BroadcastChange;
    Assert.AreEqual(1, FA.Hits, 'instance A must be notified');
    Assert.AreEqual(1, FB.Hits,
      'instance B registers the same method on a different Self and must NOT ' +
      'be swallowed as a duplicate (A2-10)');
  finally
    THbTheme.RemoveListener(FA.OnChanged);
    THbTheme.RemoveListener(FB.OnChanged);
  end;
end;

procedure TTestHBThemeListenerIdentityA210.Test_RemoveOnlyDetachesMatchingInstance;
begin
  THbTheme.AddListener(FA.OnChanged);
  THbTheme.AddListener(FB.OnChanged);
  try
    THbTheme.RemoveListener(FA.OnChanged);
    THbTheme.BroadcastChange;
    Assert.AreEqual(0, FA.Hits, 'removed listener must stop receiving');
    Assert.AreEqual(1, FB.Hits, 'the other instance must stay registered');
  finally
    THbTheme.RemoveListener(FB.OnChanged);
  end;
end;

procedure TTestHBThemeListenerIdentityA210.Test_SameInstanceRegisteredTwice_Deduped;
begin
  THbTheme.AddListener(FA.OnChanged);
  THbTheme.AddListener(FA.OnChanged);
  try
    THbTheme.BroadcastChange;
    Assert.AreEqual(1, FA.Hits);
  finally
    THbTheme.RemoveListener(FA.OnChanged);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestHBThemeListenerIdentityA210);

end.
