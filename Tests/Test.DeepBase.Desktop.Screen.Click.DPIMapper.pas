{ ============================================================================
  Test.DeepBase.Desktop.Screen.Click.DPIMapper
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : Unit tests for DPI-aware coordinate mapping functionality.
  
  Features Tested:
    - Per-monitor DPI detection
    - Relative-to-absolute coordinate conversion
    - Multi-monitor support validation
    - Fallback mechanism for legacy systems
  ========================================================================== }

unit Test.DeepBase.Desktop.Screen.Click.DPIMapper;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DeepBase.Desktop.Screen.Click.DPIMapper;

type
  [TestFixture]
  TTestDPIMapper = class(TObject)
  public
    [Setup]
    procedure Setup;
    [Teardown]
    procedure Teardown;
    
    [Test]
    procedure TestGetCurrentDPI;
    [Test]
    procedure TestMapRelativeToAbsoluteRangeValidation;
    [Test]
    procedure TestMapPercentageExactCenterPoint;
    [Test]
    procedure TestEdgeCasesZeroAndOneHundredPercent;
    [Test]
    procedure TestInvertedCoordinateMapping;
    [Test]
    procedure TestDPIAwarePropertyState;
  end;

var
  Implementation : TTestDPIMapper;

initialization
  TDUnitX.RegisterTestFixture(Implementation);

end.
