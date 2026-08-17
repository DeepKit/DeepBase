{ ============================================================================
  Test.DeepBase.Desktop.Screen.Click.SmartExecutor
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : Unit tests for intelligent click execution with tolerance and retry logic.
  
  Features Tested:
    - Multi-point tolerance matching accuracy
    - Retry mechanism with timeout control
    - Anchor point selection strategies
    - Timeout handling for missing targets
  ========================================================================== }

unit Test.DeepBase.Desktop.Screen.Click.SmartExecutor;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Graphics32,
  DeepBase.Desktop.Screen.Click.SmartExecutor;

type
  [TestFixture]
  TTestSmartClickExecutor = class(TObject)
  public
    [Setup]
    procedure Setup;
    [Teardown]
    procedure Teardown;
    
    [Test]
    procedure TestClickByTemplateSuccessDetection;
    [Test]
    procedure TestClickByTemplateNoMatchCase;
    [Test]
    procedure TestRetryMechanismWithTimeout;
    [Test]
    procedure TestToleranceParameterValidation;
    [Test]
    procedure TestAnchorModeCenterPointSelection;
    [Test]
    procedure TestAnchorModeTopLeftPointSelection;
    [Test]
    procedure TestWaitForTargetToAppearTimeout;
    [Test]
    procedure TestWaitForTargetToAppearSuccessCase;
  end;

var
  Implementation : TTestSmartClickExecutor;

initialization
  TDUnitX.RegisterTestFixture(Implementation);

end.
