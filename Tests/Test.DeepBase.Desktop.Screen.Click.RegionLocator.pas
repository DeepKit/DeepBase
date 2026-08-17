{ ============================================================================
  Test.DeepBase.Desktop.Screen.Click.RegionLocator
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : Comprehensive unit tests for TScreenRegionLocator and
                image-based template matching functionality.
  
  Features Tested:
    - Multi-scale template search with pyramid optimization
    - ROI-constrained search performance
    - Confidence threshold validation
    - Sub-pixel coordinate refinement
  
  Performance Metrics:
    - Template match on full screen (~1920x1080): < 50ms expected
    - ROI-constrained match (< 10% area): < 5ms expected
  ========================================================================== }

unit Test.DeepBase.Desktop.Screen.Click.RegionLocator;

interface

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  Graphics32,
  DUnitX.TestFramework,
  DeepBase.Desktop.Screen.Click.RegionLocator;

type
  [TestFixture]
  TTestScreenRegionLocator = class(TObject)
  public
    [Setup]
    procedure Setup;
    [Teardown]
    procedure Teardown;
    
    // Basic functionality tests
    [Test]
    procedure TestTemplateMatchAccuracy;
    [Test]
    procedure TestMultiScaleSearch;
    [Test]
    procedure TestROIConstrainedSearch;
    [Test]
    procedure TestToleranceMatching;
    [Test]
    procedure TestNoFalsePositiveDetection;
    
    // Edge case tests
    [Test]
    procedure TestEmptyImageHandling;
    [Test]
    procedure TestTemplateLargerThanSource;
    [Test]
    procedure TestSinglePixelTemplate;
    
    // Performance tests
    [Test]
    procedure TestPerformanceFullScreenSearch;
    [Test]
    procedure TestPerformanceROIConstraint;
    
    // Property tests
    [Test]
    procedure TestOptionsConfiguration;
  end;

var
  Implementation : TTestScreenRegionLocator;
  TestBitmap: TBitmap32;

procedure TTestScreenRegionLocator.Setup;
