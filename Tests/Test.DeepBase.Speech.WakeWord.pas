{ ============================================================================
  Test.DeepBase.Speech.WakeWord
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Regression tests for WakeWord handle lifecycle management.
                Verifies that event handles are properly closed to prevent
                handle leaks during Start/Stop cycles.
  ============================================================================ }

unit Test.DeepBase.Speech.WakeWord;

interface

uses
  System.SysUtils, System.Classes,
  DUnitX.TestFramework,
  DeepBase.Speech.WakeWord,
  Winapi.Windows;

type
  [TestFixture]
  TWakeWordHandleLeakTests = class
  private
    FWakeWord: TDeepBaseWakeWord;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestStop_ClosesBothEventHandles;

    [Test]
    procedure TestStartAfterStop_DoesNotLeakHandles;

    [Test]
    procedure TestMultipleStartStopCycles_NoHandleGrowth;

    [Test]
    procedure TestStartWithoutWords_ReturnsFalseWithoutCreatingHandles;

    [Test]
    procedure TestStopWhenNotRunning_DoesNotLeak;
  end;

implementation

procedure TWakeWordHandleLeakTests.Setup;
begin
  FWakeWord := TDeepBaseWakeWord.Create;
end;

procedure TWakeWordHandleLeakTests.TearDown;
begin
  FreeAndNil(FWakeWord);
end;

procedure TWakeWordHandleLeakTests.TestStop_ClosesBothEventHandles;
var
  LHandleCountBefore: DWORD;
  LHandleCountAfter: DWORD;
begin
  // Set wake words (required for Start to succeed)
  FWakeWord.SetWords(['小启', '你好']);

  // Get initial handle count
  LHandleCountBefore := GetCurrentProcessHandleCount;

  // Start the wake word detector (creates 2 event handles)
  if FWakeWord.Start then
  begin
    // Stop should close both event handles
    FWakeWord.Stop;

    // Get final handle count - should be close to initial
    LHandleCountAfter := GetCurrentProcessHandleCount;

    // Allow for some variance (±2 handles) due to COM objects or other factors
    // The key is that we don't have a consistent growth pattern
    Assert.LessThanOrEquals(
      LHandleCountAfter,
      LHandleCountBefore + 2,
      'Handle count grew after Start/Stop cycle - possible handle leak'
    );
  end
  else
  begin
    // SAPI not available - skip test
    Assert.Pass('SAPI not available - skipping handle leak test');
  end;
end;

procedure TWakeWordHandleLeakTests.TestStartAfterStop_DoesNotLeakHandles;
var
  LHandleCountBefore: DWORD;
  LHandleCountAfter: DWORD;
  I: Integer;
begin
  FWakeWord.SetWords(['测试']);

  LHandleCountBefore := GetCurrentProcessHandleCount;

  // Perform multiple Start/Stop cycles
  for I := 1 to 3 do
  begin
    if FWakeWord.Start then
    begin
      FWakeWord.Stop;
    end
    else
    begin
      // SAPI not available
      Exit;
    end;
  end;

  LHandleCountAfter := GetCurrentProcessHandleCount;

  // After 3 cycles, handle count should not have grown significantly
  // If there's a leak, we'd expect at least 6 handles leaked (2 per cycle)
  Assert.LessThanOrEquals(
    LHandleCountAfter,
    LHandleCountBefore + 3,
    'Handle count grew after multiple Start/Stop cycles - possible handle leak'
  );
end;

procedure TWakeWordHandleLeakTests.TestMultipleStartStopCycles_NoHandleGrowth;
var
  LHandleCounts: TArray<Integer>;
  I: Integer;
  LInitialCount: DWORD;
begin
  FWakeWord.SetWords(['唤醒']);

  SetLength(LHandleCounts, 5);
  LInitialCount := GetCurrentProcessHandleCount;
  LHandleCounts[0] := LInitialCount;

  // Measure handle count after each cycle
  for I := 1 to 4 do
  begin
    if FWakeWord.Start then
    begin
      FWakeWord.Stop;
      LHandleCounts[I] := GetCurrentProcessHandleCount;
    end
    else
    begin
      // SAPI not available
      Exit;
    end;
  end;

  // Check that handle count doesn't show consistent growth
  // A leak would cause monotonic increase
  for I := 1 to 4 do
  begin
    Assert.LessThanOrEquals(
      LHandleCounts[I],
      LHandleCounts[I-1] + 2,
      Format('Handle count grew from %d to %d at cycle %d - possible leak',
        [LHandleCounts[I-1], LHandleCounts[I], I])
    );
  end;
end;

procedure TWakeWordHandleLeakTests.TestStartWithoutWords_ReturnsFalseWithoutCreatingHandles;
var
  LHandleCountBefore: DWORD;
  LHandleCountAfter: DWORD;
begin
  LHandleCountBefore := GetCurrentProcessHandleCount;

  // Start without setting words should return False
  Assert.IsFalse(FWakeWord.Start, 'Start without words should return False');

  LHandleCountAfter := GetCurrentProcessHandleCount;

  // No handles should have been created
  Assert.AreEqual(
    Integer(LHandleCountBefore),
    Integer(LHandleCountAfter),
    'Handle count changed when Start returned False - possible handle leak'
  );
end;

procedure TWakeWordHandleLeakTests.TestStopWhenNotRunning_DoesNotLeak;
var
  LHandleCountBefore: DWORD;
  LHandleCountAfter: DWORD;
begin
  LHandleCountBefore := GetCurrentProcessHandleCount;

  // Stop when not running should be safe
  FWakeWord.Stop;

  LHandleCountAfter := GetCurrentProcessHandleCount;

  // No handles should have been leaked
  Assert.LessThanOrEquals(
    Integer(LHandleCountAfter),
    Integer(LHandleCountBefore) + 1,
    'Handle count grew after Stop when not running - possible leak'
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TWakeWordHandleLeakTests);

end.
