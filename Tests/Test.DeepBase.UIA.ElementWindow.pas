{ ============================================================================
  Test.DeepBase.UIA.ElementWindow - 元素窗口句柄来源与前景校验回归

  覆盖 B2-02 的两处恒真根因：
    1) TUIAElementAdapter.GetNativeWindowHandle 曾直接返回 GetForegroundWindow
       （且误读 ProcessId 属性后丢弃），元素自身窗口从未参与判断；
    2) VerifyForegroundWindow 拿这个"前台窗口自己"再与 GetForegroundWindow 比对 ⇒
       校验恒真，SetValue 里"SetFocus 后前景已改变即中止"的保护成为死代码。
  修后句柄唯一来源是 UIA NativeWindowHandle 属性（provider 沿元素树向上给出的最近
  窗口祖先），取不到即 HWND(0) 并判否。

  夹具口径：前景判定与句柄解析都经 TUIAElementAdapter 本体（只把"属性值从哪来"
  这一处经虚方法注入），测的是生产实现路径而不是副本；输入用与桌面状态无关的
  句柄值，保证非交互会话下结果确定。

  法源：WO-20260925-AUDIT-乙-B2 §B2-02。
  ============================================================================ }
unit Test.DeepBase.UIA.ElementWindow;

interface

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  DeepBase.UIA.Types,
  DeepBase.UIA.Engine,
  {$ENDIF}
  DUnitX.TestFramework,
  System.SysUtils,
  System.Variants;

type
  {$IFDEF MSWINDOWS}
  /// <summary>只替换"元素属性从哪来"这一处，其余（含 GetNativeWindowHandle 本体）
  /// 走生产实现，避免测试自造第二套句柄解析。</summary>
  TFakeNativeWindowElement = class(TUIAElementAdapter)
  private
    FNativeValue: Variant;
  public
    constructor CreateWithValue(const AValue: Variant);
    function GetCurrentPropertyValue(PropertyId: Integer): Variant; override;
  end;

  [TestFixture]
  TTestUIAElementWindow = class
  private const
    // 非 0 且不是任何真实窗口的句柄：构造"元素窗口 ≠ 前景窗口"的确定输入
    FOREIGN_HWND = HWND($1337);
  private
    class function ElementHandleOf(const AValue: Variant): HWND;
  public
    [Test]
    procedure Test_HandleComesFromNativeWindowProperty;
    [Test]
    procedure Test_NonForegroundElementWindow_IsRejected;
    [Test]
    procedure Test_MissingHandleProperty_FailsClosedToZero;
    [Test]
    procedure Test_ZeroHandle_IsNeverAcceptedAsForeground;
    [Test]
    procedure Test_Int32HighBitHandle_SignExtendedRoundTrip;
    [Test]
    procedure Test_SameWindowAsForeground_IsAccepted;
  end;
  {$ENDIF}

implementation

{$IFDEF MSWINDOWS}

{ TFakeNativeWindowElement }

constructor TFakeNativeWindowElement.CreateWithValue(const AValue: Variant);
begin
  // raw = nil：本夹具只经虚方法提供属性值，不触达 COM 对象
  inherited Create(nil, Default(TUIAElementLocator));
  FNativeValue := AValue;
end;

function TFakeNativeWindowElement.GetCurrentPropertyValue(
  PropertyId: Integer): Variant;
begin
  // 连读取的属性号一起断言：旧实现读的是 UIA_ProcessIdPropertyId 且把结果丢弃
  Assert.AreEqual(UIA_NativeWindowHandlePropertyId, PropertyId,
    'element window handle must be read from UIA_NativeWindowHandlePropertyId');
  Result := FNativeValue;
end;

{ TTestUIAElementWindow }

class function TTestUIAElementWindow.ElementHandleOf(const AValue: Variant): HWND;
var
  El: IUIAElement;
begin
  El := TFakeNativeWindowElement.CreateWithValue(AValue);
  Result := El.GetNativeWindowHandle;
end;

procedure TTestUIAElementWindow.Test_HandleComesFromNativeWindowProperty;
var
  LValue: Variant;
begin
  LValue := Int64(FOREIGN_HWND);
  Assert.AreEqual(NativeUInt(FOREIGN_HWND), NativeUInt(ElementHandleOf(LValue)),
    'GetNativeWindowHandle must return the element''s own window handle');
end;

// 工单判定：构造非前台元素，定位校验必须能拒绝
procedure TTestUIAElementWindow.Test_NonForegroundElementWindow_IsRejected;
var
  El: IUIAElement;
  LElemHwnd: HWND;
  LForeground: HWND;
begin
  El := TFakeNativeWindowElement.CreateWithValue(Int64(FOREIGN_HWND));
  LElemHwnd := El.GetNativeWindowHandle;
  LForeground := GetForegroundWindow;
  // 拒绝必须建立在"句柄来自元素自身"之上：少了这条前提，无桌面会话下
  // GetForegroundWindow=0 会让冒充前台窗口的旧实现也"恰好被拒绝"，用例就变成假绿。
  Assert.AreEqual(NativeUInt(FOREIGN_HWND), NativeUInt(LElemHwnd),
    'the handle used for the rejection must be the element''s own window handle');
  Assert.AreNotEqual(NativeUInt(FOREIGN_HWND), NativeUInt(LForeground),
    'the injected element window must differ from the live foreground window');
  Assert.IsFalse(IsWindowInForeground(LElemHwnd, LForeground),
    'an element window that is not the foreground window must be rejected');
  // 前景参数另给一个确定非 0 的真实窗口：无桌面会话下 GetForegroundWindow=0，
  // 只靠实时前景会让「判据恒真」的变异从 HWND(0) 守卫处逃过检测（实测）。
  Assert.IsFalse(IsWindowInForeground(FOREIGN_HWND, GetDesktopWindow),
    'a foreign element window must be rejected against any nonzero foreground window');
  Assert.IsFalse(IsElementWindowInForeground(LElemHwnd),
    'the production check must reject a non-foreground element window');
end;

procedure TTestUIAElementWindow.Test_MissingHandleProperty_FailsClosedToZero;
var
  LEmpty: Variant;
  LZero: Variant;
  LText: Variant;
  LObj: Variant;
begin
  LZero := Integer(0);
  LText := 'not-a-handle';
  LObj := TFakeNativeWindowElement.CreateWithValue(Integer(0)) as IUnknown;
  Assert.AreEqual(NativeUInt(0), NativeUInt(ElementHandleOf(LEmpty)),
    'VT_EMPTY (windowless element) must map to HWND(0), never to the foreground window');
  Assert.AreEqual(NativeUInt(0), NativeUInt(ElementHandleOf(LZero)),
    'a zero handle property must map to HWND(0)');
  Assert.AreEqual(NativeUInt(0), NativeUInt(ElementHandleOf(LText)),
    'a non-numeric property value must map to HWND(0)');
  Assert.AreEqual(NativeUInt(0), NativeUInt(ElementHandleOf(LObj)),
    'an interface-valued property must map to HWND(0) instead of raising or leaking a handle');
end;

// 「元素无句柄」与「系统无前景」不得互相抵消成恒真
procedure TTestUIAElementWindow.Test_ZeroHandle_IsNeverAcceptedAsForeground;
begin
  Assert.IsFalse(IsWindowInForeground(HWND(0), GetForegroundWindow),
    'HWND(0) must never pass the foreground check');
  Assert.IsFalse(IsWindowInForeground(HWND(0), HWND(0)),
    'no-handle element must not pass merely because there is no foreground window');
  Assert.IsFalse(IsWindowInForeground(FOREIGN_HWND, HWND(0)),
    'a real element handle must not pass when there is no foreground window');
  Assert.IsFalse(IsElementWindowInForeground(ElementHandleOf(Integer(0))),
    'windowless element must be rejected end to end');
end;

procedure TTestUIAElementWindow.Test_Int32HighBitHandle_SignExtendedRoundTrip;
var
  LValue: Variant;
begin
  // 32 位 provider 以 VT_I4 报 HWND：$80000001 需符号扩展回同一个窗口，而不是丢高位
  LValue := Integer($80000001);
  Assert.AreEqual(NativeUInt($FFFFFFFF80000001),
    NativeUInt(ElementHandleOf(LValue)),
    'a VT_I4 handle with the high bit set must sign-extend to the full HWND');
end;

procedure TTestUIAElementWindow.Test_SameWindowAsForeground_IsAccepted;
var
  LReal: HWND;
begin
  LReal := GetDesktopWindow;
  Assert.IsTrue(IsWindowInForeground(LReal, LReal),
    'the element window equal to the foreground window must pass');
  // 端到端：句柄来自元素属性、前景来自真实窗口，两侧同值即通过。
  // 不用 GetForegroundWindow 做正例——无桌面会话时它是 0，断言会退化成永真。
  Assert.IsTrue(IsWindowInForeground(ElementHandleOf(Int64(LReal)), LReal),
    'an element whose own window is the foreground window must pass');
end;

{$ENDIF}

initialization
  {$IFDEF MSWINDOWS}
  TDUnitX.RegisterTestFixture(TTestUIAElementWindow);
  {$ENDIF}

end.
