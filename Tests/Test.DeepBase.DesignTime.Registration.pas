{ ============================================================================
  Test.DeepBase.DesignTime.Registration - 设计时注册完整性架构测试

  版本: 1.0
  说明: 验证 VCL/FMX 设计时组件注册完整性

  REVIEW5-UI-006: 统一 VCL/FMX 设计时注册聚合
  ============================================================================ }

unit Test.DeepBase.DesignTime.Registration;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
  System.Classes;

type
  [TestFixture]
  TDesignTimeRegistrationTests = class
  public
    [Test]
    procedure VCL_RegisterUnit_Exists;
    [Test]
    procedure FMX_RegisterUnit_Exists;
    [Test]
    procedure VCL_RegisterProcedure_CallsRegisterComponents;
    [Test]
    procedure FMX_RegisterProcedure_CallsRegisterComponents;
    [Test]
    procedure VCL_RegistersMinimumComponents;
    [Test]
    procedure FMX_RegistersMinimumComponents;
    [Test]
    procedure DesignTimePackages_Exist;
  end;

implementation

{ TDesignTimeRegistrationTests }

procedure TDesignTimeRegistrationTests.VCL_RegisterUnit_Exists;
var
  LPath: string;
begin
  LPath := TPath.Combine(TDirectory.GetCurrentDirectory, 'VCL\DeepBase.VCL.Controls.pas');
  Assert.IsTrue(TFile.Exists(LPath),
    'VCL design-time registration unit should exist: VCL\DeepBase.VCL.Controls.pas');
end;

procedure TDesignTimeRegistrationTests.FMX_RegisterUnit_Exists;
var
  LPath: string;
begin
  LPath := TPath.Combine(TDirectory.GetCurrentDirectory, 'FMX\DeepBase.FMX.Controls.pas');
  Assert.IsTrue(TFile.Exists(LPath),
    'FMX design-time registration unit should exist: FMX\DeepBase.FMX.Controls.pas');
end;

procedure TDesignTimeRegistrationTests.VCL_RegisterProcedure_CallsRegisterComponents;
var
  LContent: string;
  LPath: string;
begin
  LPath := TPath.Combine(TDirectory.GetCurrentDirectory, 'VCL\DeepBase.VCL.Controls.pas');
  LContent := TFile.ReadAllText(LPath);

  // Check that Register procedure exists
  Assert.IsTrue(LContent.Contains('procedure Register;'),
    'VCL Controls should have Register procedure');

  // Check that RegisterComponents is called
  Assert.IsTrue(LContent.Contains('RegisterComponents('),
    'VCL Register procedure should call RegisterComponents');
end;

procedure TDesignTimeRegistrationTests.FMX_RegisterProcedure_CallsRegisterComponents;
var
  LContent: string;
  LPath: string;
begin
  LPath := TPath.Combine(TDirectory.GetCurrentDirectory, 'FMX\DeepBase.FMX.Controls.pas');
  LContent := TFile.ReadAllText(LPath);

  // Check that Register procedure exists
  Assert.IsTrue(LContent.Contains('procedure Register;'),
    'FMX Controls should have Register procedure');

  // Check that RegisterComponents is called
  Assert.IsTrue(LContent.Contains('RegisterComponents('),
    'FMX Register procedure should call RegisterComponents');
end;

procedure TDesignTimeRegistrationTests.VCL_RegistersMinimumComponents;
var
  LContent: string;
  LPath: string;
  LComponentCount: Integer;
begin
  LPath := TPath.Combine(TDirectory.GetCurrentDirectory, 'VCL\DeepBase.VCL.Controls.pas');
  LContent := TFile.ReadAllText(LPath);

  // Count TComponent registrations (simple heuristic: count T followed by uppercase)
  // This is a basic check - real implementation would parse the RegisterComponents call
  LComponentCount := 0;
  if LContent.Contains('TConfigEdit') then Inc(LComponentCount);
  if LContent.Contains('TConfigCheckBox') then Inc(LComponentCount);
  if LContent.Contains('TI18nLabel') then Inc(LComponentCount);
  if LContent.Contains('TI18nButton') then Inc(LComponentCount);
  if LContent.Contains('TLogListView') then Inc(LComponentCount);
  if LContent.Contains('TLLMConfigPanel') then Inc(LComponentCount);
  if LContent.Contains('TNotificationBar') then Inc(LComponentCount);

  Assert.IsTrue(LComponentCount >= 7,
    'VCL should register at least 7 components, found: ' + IntToStr(LComponentCount));
end;

procedure TDesignTimeRegistrationTests.FMX_RegistersMinimumComponents;
var
  LContent: string;
  LPath: string;
  LComponentCount: Integer;
begin
  LPath := TPath.Combine(TDirectory.GetCurrentDirectory, 'FMX\DeepBase.FMX.Controls.pas');
  LContent := TFile.ReadAllText(LPath);

  // Count TComponent registrations
  LComponentCount := 0;
  if LContent.Contains('TFMXConfigEdit') then Inc(LComponentCount);
  if LContent.Contains('TFMXConfigCheckBox') then Inc(LComponentCount);
  if LContent.Contains('TFMXi18nLabel') then Inc(LComponentCount);
  if LContent.Contains('TFMXi18nButton') then Inc(LComponentCount);
  if LContent.Contains('TFMXLLMConfigPanel') then Inc(LComponentCount);
  if LContent.Contains('TFMXLogListView') then Inc(LComponentCount);
  if LContent.Contains('TFMXNotificationBar') then Inc(LComponentCount);

  Assert.IsTrue(LComponentCount >= 7,
    'FMX should register at least 7 components, found: ' + IntToStr(LComponentCount));
end;

procedure TDesignTimeRegistrationTests.DesignTimePackages_Exist;
var
  LPath: string;
begin
  // Check dclDeepBaseCore.dpk
  LPath := TPath.Combine(TDirectory.GetCurrentDirectory, 'dclDeepBaseCore.dpk');
  Assert.IsTrue(TFile.Exists(LPath),
    'Design-time package dclDeepBaseCore.dpk should exist');

  // Check dclDeepBaseVCL.dpk
  LPath := TPath.Combine(TDirectory.GetCurrentDirectory, 'dclDeepBaseVCL.dpk');
  Assert.IsTrue(TFile.Exists(LPath),
    'Design-time package dclDeepBaseVCL.dpk should exist');

  // Check dclDeepBaseFMX.dpk
  LPath := TPath.Combine(TDirectory.GetCurrentDirectory, 'dclDeepBaseFMX.dpk');
  Assert.IsTrue(TFile.Exists(LPath),
    'Design-time package dclDeepBaseFMX.dpk should exist');
end;

end.
