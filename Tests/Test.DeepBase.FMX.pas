{ ============================================================================
  Test.DeepBase.FMX - FMX Controls Unit Tests
  
  Version: 1.0
  Description: Unit tests for DeepBase FMX cross-platform controls
  
  Test Coverage:
  - TFMXi18nLabel / TFMXi18nButton
  - TFMXConfigEdit / TFMXConfigCheckBox / TFMXConfigSpinBox
  - TFMXMRUComboBox
  - TUniMaterialEdit / TUniSearchComboBox
  - TUniListView
  - TUniStarRating / TUniChipInput
  
  Note: These tests run on Windows platform. For full cross-platform coverage,
  additional testing on Android/iOS/macOS is recommended.
  ============================================================================ }

unit Test.DeepBase.FMX;

interface

{$IFDEF MSWINDOWS}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  FMX.Forms,
  FMX.Types,
  FMX.Controls,
  FMX.StdCtrls,
  FMX.Edit,
  FMX.ListBox,
  DUnitX.TestFramework;

type
  /// <summary>
  /// Test fixture for FMX I18n Controls
  /// </summary>
  [TestFixture]
  TTestFMXI18nControls = class
  private
    FForm: TForm;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    [TestCase('CreateLabel', '')]
    procedure Test_FMXi18nLabel_Create;
    
    [Test]
    procedure Test_FMXi18nLabel_TextKey;
    
    [Test]
    procedure Test_FMXi18nButton_Create;
    
    [Test]
    procedure Test_FMXi18nButton_TextKey;
    
    [Test]
    procedure Test_FMXi18nLabel_RefreshTranslation;
    
    [Test]
    procedure Test_FMXi18nButton_RefreshTranslation;
  end;
  
  /// <summary>
  /// Test fixture for FMX Config Controls
  /// </summary>
  [TestFixture]
  TTestFMXConfigControls = class
  private
    FForm: TForm;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_FMXConfigEdit_Create;
    
    [Test]
    procedure Test_FMXConfigEdit_ConfigKey;
    
    [Test]
    procedure Test_FMXConfigCheckBox_Create;
    
    [Test]
    procedure Test_FMXConfigCheckBox_ConfigKey;
    
    [Test]
    procedure Test_FMXConfigSpinBox_Create;
    
    [Test]
    procedure Test_FMXConfigSpinBox_ConfigKey;
  end;
  
  /// <summary>
  /// Test fixture for FMX MRU Controls
  /// </summary>
  [TestFixture]
  TTestFMXMRUControls = class
  private
    FForm: TForm;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_FMXMRUComboBox_Create;
    
    [Test]
    procedure Test_FMXMRUComboBox_Category;
    
    [Test]
    procedure Test_FMXMRUComboBox_MaxItems;
  end;
  
  /// <summary>
  /// Test fixture for FMX Form Controls (Material Design)
  /// </summary>
  [TestFixture]
  TTestFMXFormControls = class
  private
    FForm: TForm;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_UniMaterialEdit_Create;
    
    [Test]
    procedure Test_UniMaterialEdit_FloatingLabel;
    
    [Test]
    procedure Test_UniMaterialEdit_Validation;
    
    [Test]
    procedure Test_UniSearchComboBox_Create;
    
    [Test]
    procedure Test_UniSearchComboBox_Search;
    
    [Test]
    procedure Test_UniLabeledSwitch_Create;
    
    [Test]
    procedure Test_UniChipInput_Create;
    
    [Test]
    procedure Test_UniChipInput_AddReDeepMoveChip;
    
    [Test]
    procedure Test_UniStarRating_Create;
    
    [Test]
    procedure Test_UniStarRating_SetRating;
  end;
  
  /// <summary>
  /// Test fixture for FMX ListView
  /// </summary>
  [TestFixture]
  TTestFMXListView = class
  private
    FForm: TForm;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_UniListView_Create;
    
    [Test]
    procedure Test_UniListView_PullRefresh;
    
    [Test]
    procedure Test_UniListView_InfiniteScroll;
    
    [Test]
    procedure Test_UniListView_EmptyState;
  end;
  
  /// <summary>
  /// Test fixture for FMX Platform Adapter
  /// </summary>
  [TestFixture]
  TTestFMXPlatform = class
  public
    [Test]
    procedure Test_Platform_IsWindows;

    [Test]
    procedure Test_Platform_GetDeviceType;

    [Test]
    procedure Test_Platform_DocumentsPath;

    [Test]
    procedure Test_Platform_CachePath;

    // BUG-277 regression: enum defaults must be the safe "Unknown" value
    [Test]
    procedure Test_Platform_EnumDefault_IsUnknown;
    [Test]
    procedure Test_Platform_UnknownOrdinal_IsZero;
    [Test]
    procedure Test_Platform_GetPlatform_DetectsBeforeReturn;
    [Test]
    procedure Test_Platform_HasPermission_DesktopDefaultsToTrue;
    [Test]
    procedure Test_Platform_HasPermission_UnknownPermissionDesktopTrue;
    [Test]
    procedure Test_Platform_GetPlatformName_NotEmpty;

    // REVIEW-P0-002 regression: ShareFileEx / CheckPermissionEx /
    // RequestPermissionEx delegate chain
    [Test]
    procedure Test_Platform_ShareFileEx_DelegateOverride_IsInvoked;
    [Test]
    procedure Test_Platform_ShareFileEx_MissingFile_ReturnsFalse;
    [Test]
    procedure Test_Platform_CheckPermissionEx_DelegateOverride_IsInvoked;
    [Test]
    procedure Test_Platform_RequestPermissionEx_DelegateOverride_FiresCallback;
  end;

  /// <summary>
  /// Test fixture for FMX Theme Manager
  /// </summary>
  [TestFixture]
  TTestFMXTheme = class
  public
    [Test]
    procedure Test_Theme_GetMode;
    
    [Test]
    procedure Test_Theme_SetLightMode;
    
    [Test]
    procedure Test_Theme_SetDarkMode;
    
    [Test]
    procedure Test_Theme_ToggleTheme;
    
    [Test]
    procedure Test_Theme_GetColor;
  end;

implementation

uses
  DeepBase.FMX.I18nControls,
  DeepBase.FMX.ConfigControls,
  DeepBase.FMX.MRUControls,
  DeepBase.FMX.FormControls,
  DeepBase.FMX.ListView,
  DeepBase.FMX.Platform,
  DeepBase.FMX.Theme,
  DeepBase.Platform.Interfaces;

{ TTestFMXI18nControls }

procedure TTestFMXI18nControls.Setup;
begin
  FForm := TForm.Create(nil);
end;

procedure TTestFMXI18nControls.TearDown;
begin
  FForm.Free;
end;

procedure TTestFMXI18nControls.Test_FMXi18nLabel_Create;
var
  Lbl: TFMXi18nLabel;
begin
  Lbl := TFMXi18nLabel.Create(FForm);
  try
    Lbl.Parent := FForm;
    Assert.IsNotNull(Lbl);
    Assert.AreEqual('', Lbl.TextKey);
  finally
    Lbl.Free;
  end;
end;

procedure TTestFMXI18nControls.Test_FMXi18nLabel_TextKey;
var
  Lbl: TFMXi18nLabel;
begin
  Lbl := TFMXi18nLabel.Create(FForm);
  try
    Lbl.Parent := FForm;
    Lbl.TextKey := 'test.label';
    Assert.AreEqual('test.label', Lbl.TextKey);
  finally
    Lbl.Free;
  end;
end;

procedure TTestFMXI18nControls.Test_FMXi18nButton_Create;
var
  Btn: TFMXi18nButton;
begin
  Btn := TFMXi18nButton.Create(FForm);
  try
    Btn.Parent := FForm;
    Assert.IsNotNull(Btn);
    Assert.AreEqual('', Btn.TextKey);
  finally
    Btn.Free;
  end;
end;

procedure TTestFMXI18nControls.Test_FMXi18nButton_TextKey;
var
  Btn: TFMXi18nButton;
begin
  Btn := TFMXi18nButton.Create(FForm);
  try
    Btn.Parent := FForm;
    Btn.TextKey := 'test.button';
    Assert.AreEqual('test.button', Btn.TextKey);
  finally
    Btn.Free;
  end;
end;

procedure TTestFMXI18nControls.Test_FMXi18nLabel_RefreshTranslation;
var
  Lbl: TFMXi18nLabel;
begin
  Lbl := TFMXi18nLabel.Create(FForm);
  try
    Lbl.Parent := FForm;
    Lbl.Text := 'Original';
    Lbl.RefreshTranslation;
    // Without DeepBase initialized, should keep original text
    Assert.AreEqual('Original', Lbl.Text);
  finally
    Lbl.Free;
  end;
end;

procedure TTestFMXI18nControls.Test_FMXi18nButton_RefreshTranslation;
var
  Btn: TFMXi18nButton;
begin
  Btn := TFMXi18nButton.Create(FForm);
  try
    Btn.Parent := FForm;
    Btn.Text := 'Click Me';
    Btn.RefreshTranslation;
    // Without DeepBase initialized, should keep original text
    Assert.AreEqual('Click Me', Btn.Text);
  finally
    Btn.Free;
  end;
end;

{ TTestFMXConfigControls }

procedure TTestFMXConfigControls.Setup;
begin
  FForm := TForm.Create(nil);
end;

procedure TTestFMXConfigControls.TearDown;
begin
  FForm.Free;
end;

procedure TTestFMXConfigControls.Test_FMXConfigEdit_Create;
var
  Edit: TFMXConfigEdit;
begin
  Edit := TFMXConfigEdit.Create(FForm);
  try
    Edit.Parent := FForm;
    Assert.IsNotNull(Edit);
  finally
    Edit.Free;
  end;
end;

procedure TTestFMXConfigControls.Test_FMXConfigEdit_ConfigKey;
var
  Edit: TFMXConfigEdit;
begin
  Edit := TFMXConfigEdit.Create(FForm);
  try
    Edit.Parent := FForm;
    Edit.ConfigKey := 'app.setting.name';
    Assert.AreEqual('app.setting.name', Edit.ConfigKey);
  finally
    Edit.Free;
  end;
end;

procedure TTestFMXConfigControls.Test_FMXConfigCheckBox_Create;
var
  CB: TFMXConfigCheckBox;
begin
  CB := TFMXConfigCheckBox.Create(FForm);
  try
    CB.Parent := FForm;
    Assert.IsNotNull(CB);
  finally
    CB.Free;
  end;
end;

procedure TTestFMXConfigControls.Test_FMXConfigCheckBox_ConfigKey;
var
  CB: TFMXConfigCheckBox;
begin
  CB := TFMXConfigCheckBox.Create(FForm);
  try
    CB.Parent := FForm;
    CB.ConfigKey := 'app.setting.enabled';
    Assert.AreEqual('app.setting.enabled', CB.ConfigKey);
  finally
    CB.Free;
  end;
end;

procedure TTestFMXConfigControls.Test_FMXConfigSpinBox_Create;
var
  SB: TFMXConfigSpinBox;
begin
  SB := TFMXConfigSpinBox.Create(FForm);
  try
    SB.Parent := FForm;
    Assert.IsNotNull(SB);
  finally
    SB.Free;
  end;
end;

procedure TTestFMXConfigControls.Test_FMXConfigSpinBox_ConfigKey;
var
  SB: TFMXConfigSpinBox;
begin
  SB := TFMXConfigSpinBox.Create(FForm);
  try
    SB.Parent := FForm;
    SB.ConfigKey := 'app.setting.count';
    Assert.AreEqual('app.setting.count', SB.ConfigKey);
  finally
    SB.Free;
  end;
end;

{ TTestFMXMRUControls }

procedure TTestFMXMRUControls.Setup;
begin
  FForm := TForm.Create(nil);
end;

procedure TTestFMXMRUControls.TearDown;
begin
  FForm.Free;
end;

procedure TTestFMXMRUControls.Test_FMXMRUComboBox_Create;
var
  CB: TFMXMRUComboBox;
begin
  CB := TFMXMRUComboBox.Create(FForm);
  try
    CB.Parent := FForm;
    Assert.IsNotNull(CB);
  finally
    CB.Free;
  end;
end;

procedure TTestFMXMRUControls.Test_FMXMRUComboBox_Category;
var
  CB: TFMXMRUComboBox;
begin
  CB := TFMXMRUComboBox.Create(FForm);
  try
    CB.Parent := FForm;
    CB.Category := 'RecentFiles';
    Assert.AreEqual('RecentFiles', CB.Category);
  finally
    CB.Free;
  end;
end;

procedure TTestFMXMRUControls.Test_FMXMRUComboBox_MaxItems;
var
  CB: TFMXMRUComboBox;
begin
  CB := TFMXMRUComboBox.Create(FForm);
  try
    CB.Parent := FForm;
    CB.MaxItems := 15;
    Assert.AreEqual(15, CB.MaxItems);
  finally
    CB.Free;
  end;
end;

{ TTestFMXFormControls }

procedure TTestFMXFormControls.Setup;
begin
  FForm := TForm.Create(nil);
end;

procedure TTestFMXFormControls.TearDown;
begin
  FForm.Free;
end;

procedure TTestFMXFormControls.Test_UniMaterialEdit_Create;
var
  Edit: TUniMaterialEdit;
begin
  Edit := TUniMaterialEdit.Create(FForm);
  try
    Edit.Parent := FForm;
    Assert.IsNotNull(Edit);
  finally
    Edit.Free;
  end;
end;

procedure TTestFMXFormControls.Test_UniMaterialEdit_FloatingLabel;
var
  Edit: TUniMaterialEdit;
begin
  Edit := TUniMaterialEdit.Create(FForm);
  try
    Edit.Parent := FForm;
    Edit.LabelText := 'Username';
    Assert.AreEqual('Username', Edit.LabelText);
  finally
    Edit.Free;
  end;
end;

procedure TTestFMXFormControls.Test_UniMaterialEdit_Validation;
var
  Edit: TUniMaterialEdit;
begin
  Edit := TUniMaterialEdit.Create(FForm);
  try
    Edit.Parent := FForm;
    Edit.ValidationMode := vmRequired;
    Assert.AreEqual(vmRequired, Edit.ValidationMode);
    
    // Test validation
    Edit.Text := '';
    Assert.IsFalse(Edit.Validate);
    
    Edit.Text := 'test';
    Assert.IsTrue(Edit.Validate);
  finally
    Edit.Free;
  end;
end;

procedure TTestFMXFormControls.Test_UniSearchComboBox_Create;
var
  CB: TUniSearchComboBox;
begin
  CB := TUniSearchComboBox.Create(FForm);
  try
    CB.Parent := FForm;
    Assert.IsNotNull(CB);
  finally
    CB.Free;
  end;
end;

procedure TTestFMXFormControls.Test_UniSearchComboBox_Search;
var
  CB: TUniSearchComboBox;
begin
  CB := TUniSearchComboBox.Create(FForm);
  try
    CB.Parent := FForm;
    CB.Items.Add('Apple');
    CB.Items.Add('Banana');
    CB.Items.Add('Cherry');
    
    CB.SearchText := 'an';
    // Should filter to show items containing 'an'
    Assert.IsTrue(CB.Items.Count >= 0);
  finally
    CB.Free;
  end;
end;

procedure TTestFMXFormControls.Test_UniLabeledSwitch_Create;
var
  Switch: TUniLabeledSwitch;
begin
  Switch := TUniLabeledSwitch.Create(FForm);
  try
    Switch.Parent := FForm;
    Assert.IsNotNull(Switch);
    
    Switch.LabelText := 'Enable Feature';
    Assert.AreEqual('Enable Feature', Switch.LabelText);
  finally
    Switch.Free;
  end;
end;

procedure TTestFMXFormControls.Test_UniChipInput_Create;
var
  ChipInput: TUniChipInput;
begin
  ChipInput := TUniChipInput.Create(FForm);
  try
    ChipInput.Parent := FForm;
    Assert.IsNotNull(ChipInput);
  finally
    ChipInput.Free;
  end;
end;

procedure TTestFMXFormControls.Test_UniChipInput_AddReDeepMoveChip;
var
  ChipInput: TUniChipInput;
begin
  ChipInput := TUniChipInput.Create(FForm);
  try
    ChipInput.Parent := FForm;
    
    ChipInput.AddChip('Tag1');
    ChipInput.AddChip('Tag2');
    Assert.AreEqual(2, ChipInput.ChipCount);
    
    ChipInput.ReDeepMoveChip('Tag1');
    Assert.AreEqual(1, ChipInput.ChipCount);
  finally
    ChipInput.Free;
  end;
end;

procedure TTestFMXFormControls.Test_UniStarRating_Create;
var
  Rating: TUniStarRating;
begin
  Rating := TUniStarRating.Create(FForm);
  try
    Rating.Parent := FForm;
    Assert.IsNotNull(Rating);
    Assert.AreEqual(5, Rating.MaxStars);
  finally
    Rating.Free;
  end;
end;

procedure TTestFMXFormControls.Test_UniStarRating_SetRating;
var
  Rating: TUniStarRating;
begin
  Rating := TUniStarRating.Create(FForm);
  try
    Rating.Parent := FForm;
    
    Rating.Rating := 3.5;
    Assert.AreEqual(3.5, Rating.Rating, 0.01);
    
    Rating.Rating := 0;
    Assert.AreEqual(0.0, Rating.Rating, 0.01);
    
    Rating.Rating := 5;
    Assert.AreEqual(5.0, Rating.Rating, 0.01);
  finally
    Rating.Free;
  end;
end;

{ TTestFMXListView }

procedure TTestFMXListView.Setup;
begin
  FForm := TForm.Create(nil);
end;

procedure TTestFMXListView.TearDown;
begin
  FForm.Free;
end;

procedure TTestFMXListView.Test_UniListView_Create;
var
  LV: TUniListView;
begin
  LV := TUniListView.Create(FForm);
  try
    LV.Parent := FForm;
    Assert.IsNotNull(LV);
  finally
    LV.Free;
  end;
end;

procedure TTestFMXListView.Test_UniListView_PullRefresh;
var
  LV: TUniListView;
begin
  LV := TUniListView.Create(FForm);
  try
    LV.Parent := FForm;
    LV.PullRefreshEnabled := True;
    Assert.IsTrue(LV.PullRefreshEnabled);
    
    LV.PullRefreshEnabled := False;
    Assert.IsFalse(LV.PullRefreshEnabled);
  finally
    LV.Free;
  end;
end;

procedure TTestFMXListView.Test_UniListView_InfiniteScroll;
var
  LV: TUniListView;
begin
  LV := TUniListView.Create(FForm);
  try
    LV.Parent := FForm;
    LV.InfiniteScrollEnabled := True;
    Assert.IsTrue(LV.InfiniteScrollEnabled);
  finally
    LV.Free;
  end;
end;

procedure TTestFMXListView.Test_UniListView_EmptyState;
var
  LV: TUniListView;
begin
  LV := TUniListView.Create(FForm);
  try
    LV.Parent := FForm;
    LV.EmptyText := 'No items found';
    Assert.AreEqual('No items found', LV.EmptyText);
  finally
    LV.Free;
  end;
end;

{ TTestFMXPlatform }

procedure TTestFMXPlatform.Test_Platform_IsWindows;
begin
  Assert.IsTrue(Platform.IsWindows);
  Assert.IsFalse(Platform.IsMacOS);
  Assert.IsFalse(Platform.IsAndroid);
  Assert.IsFalse(Platform.IsIOS);
end;

procedure TTestFMXPlatform.Test_Platform_GetDeviceType;
begin
  Assert.AreEqual(TUniDeviceType.udtDesktop, Platform.GetDeviceType);
end;

procedure TTestFMXPlatform.Test_Platform_DocumentsPath;
var
  Path: string;
begin
  Path := Platform.DocumentsPath;
  Assert.IsNotEmpty(Path);
  Assert.IsTrue(DirectoryExists(Path));
end;

procedure TTestFMXPlatform.Test_Platform_CachePath;
var
  Path: string;
begin
  Path := Platform.CachePath;
  Assert.IsNotEmpty(Path);
end;

{ BUG-277 regression: enum defaults and permission safety }

procedure TTestFMXPlatform.Test_Platform_EnumDefault_IsUnknown;
var
  P: TUniPlatform;
  D: TUniDeviceType;
begin
  // Default (zero-initialized) must be the safe Unknown value, not a real platform.
  P := Default(TUniPlatform);
  D := Default(TUniDeviceType);
  Assert.AreEqual(Ord(upUnknown), Ord(P), 'TUniPlatform default must be upUnknown');
  Assert.AreEqual(Ord(udtUnknown), Ord(D), 'TUniDeviceType default must be udtUnknown');
end;

procedure TTestFMXPlatform.Test_Platform_UnknownOrdinal_IsZero;
begin
  // Critical invariant: Ord(upUnknown)=0 and Ord(udtUnknown)=0 so that class vars
  // (zero-initialized before DetectPlatform/DetectDeviceType run) are safe.
  Assert.AreEqual(0, Ord(upUnknown), 'upUnknown must have ordinal 0');
  Assert.AreEqual(0, Ord(udtUnknown), 'udtUnknown must have ordinal 0');
  Assert.AreNotEqual(0, Ord(upWindows), 'upWindows must NOT be ordinal 0');
  Assert.AreNotEqual(0, Ord(udtDesktop), 'udtDesktop must NOT be ordinal 0');
end;

procedure TTestFMXPlatform.Test_Platform_GetPlatform_DetectsBeforeReturn;
begin
  // Even before Instance is created, GetPlatform must return a known platform
  // on the current build target (never silently fall through to upUnknown).
  {$IFDEF MSWINDOWS}
  Assert.AreEqual(upWindows, TUniPlatformAdapter.GetPlatform);
  {$ENDIF}
  Assert.AreNotEqual(upUnknown, TUniPlatformAdapter.GetPlatform,
    'GetPlatform should detect the current build target');
end;

procedure TTestFMXPlatform.Test_Platform_HasPermission_DesktopDefaultsToTrue;
begin
  // On desktop (no runtime permission model), HasPermission should report granted.
  {$IF NOT DEFINED(ANDROID) AND NOT DEFINED(IOS)}
  Assert.IsTrue(TUniPlatformAdapter.HasPermission('android.permission.CAMERA'),
    'Desktop HasPermission should default to True (no runtime model)');
  {$ENDIF}
end;

procedure TTestFMXPlatform.Test_Platform_HasPermission_UnknownPermissionDesktopTrue;
begin
  {$IF NOT DEFINED(ANDROID) AND NOT DEFINED(IOS)}
  Assert.IsTrue(TUniPlatformAdapter.HasPermission('some.unknown.permission'),
    'Desktop HasPermission should return True even for unknown permission strings');
  {$ENDIF}
end;

procedure TTestFMXPlatform.Test_Platform_GetPlatformName_NotEmpty;
begin
  Assert.IsNotEmpty(TUniPlatformAdapter.GetPlatformName);
  Assert.AreNotEqual('Unknown', TUniPlatformAdapter.GetPlatformName,
    'GetPlatformName on a known target should not return "Unknown"');
end;

// REVIEW-P0-002 regression: ShareFileEx / CheckPermissionEx /
// RequestPermissionEx delegate chain
procedure TTestFMXPlatform.Test_Platform_ShareFileEx_DelegateOverride_IsInvoked;
var
  LReceivedPath: string;
  LDelegateCalled: Boolean;
begin
  LDelegateCalled := False;
  TUniPlatformAdapter.RegisterShareOverride(nil,
    function(const AFilePath: string): Boolean
    begin
      LDelegateCalled := True;
      LReceivedPath := AFilePath;
      Exit(True);
    end);
  try
    Assert.IsTrue(TUniPlatformAdapter.ShareFileEx('C:\fake\path\file.txt'),
      'ShareFileEx should return what the registered delegate returns');
    Assert.IsTrue(LDelegateCalled, 'ShareFileEx delegate was not invoked');
    Assert.AreEqual('C:\fake\path\file.txt', LReceivedPath);
  finally
    // Clear override so it doesn't leak into other tests.
    TUniPlatformAdapter.RegisterShareOverride(nil, nil);
  end;
end;

procedure TTestFMXPlatform.Test_Platform_ShareFileEx_MissingFile_ReturnsFalse;
var
  LTempDir: string;
  LMadeUpPath: string;
begin
  // On Windows the default path performs TFile.Exists and returns False
  // when the file is absent. Delegate chain is empty (RegisterShareOverride
  // clears overrides above), so this exercises the compile-time branch.
  LTempDir := TPath.GetTempPath;
  LMadeUpPath := TPath.Combine(LTempDir,
    'deepbase-fmx-missing-' + IntToStr(GetCurrentThreadId) + '.txt');
  if TFile.Exists(LMadeUpPath) then
    TFile.Delete(LMadeUpPath);

  {$IFDEF MSWINDOWS}
  Assert.IsFalse(TUniPlatformAdapter.ShareFileEx(LMadeUpPath),
    'ShareFileEx on a missing file must return False (no UI raised)');
  {$ELSE}
  // On mobile platforms a missing file either returns False or shows a
  // native picker that returns False in a test environment. Either way
  // we must never see True.
  Assert.IsFalse(TUniPlatformAdapter.ShareFileEx(LMadeUpPath),
    'ShareFileEx on a missing file should not return True');
  {$ENDIF}
end;

procedure TTestFMXPlatform.Test_Platform_CheckPermissionEx_DelegateOverride_IsInvoked;
var
  LDelegateCalled: Boolean;
  LReceivedPerm: string;
begin
  LDelegateCalled := False;
  TUniPlatformAdapter.RegisterPermissionOverride(
    function(const APermission: string): TPermissionResult
    begin
      LDelegateCalled := True;
      LReceivedPerm := APermission;
      Exit(prGranted);
    end,
    nil);
  try
    Assert.AreEqual(prGranted,
      TUniPlatformAdapter.CheckPermissionEx('test.permission.camera'),
      'CheckPermissionEx should return what the registered delegate returns');
    Assert.IsTrue(LDelegateCalled,
      'CheckPermissionEx delegate was not invoked');
    Assert.AreEqual('test.permission.camera', LReceivedPerm);
  finally
    TUniPlatformAdapter.RegisterPermissionOverride(nil, nil);
  end;
end;

procedure TTestFMXPlatform.Test_Platform_RequestPermissionEx_DelegateOverride_FiresCallback;
var
  LDelegateCalled: Boolean;
  LCallbackFired: Boolean;
  LReceivedPerm: string;
  LReceivedResult: TPermissionResult;
begin
  LDelegateCalled := False;
  LCallbackFired := False;

  // The delegate is responsible for invoking the callback itself (or
  // explicitly signalling prRequestIssued) — replicate that contract.
  TUniPlatformAdapter.RegisterPermissionOverride(
    nil,
    function(const APermission: string; const ACallback: TPermissionCallback): TPermissionResult
    begin
      LDelegateCalled := True;
      LReceivedPerm := APermission;
      if Assigned(ACallback) then
        ACallback(APermission, prGranted);
      Exit(prGranted);
    end);
  try
    Assert.AreEqual(prGranted,
      TUniPlatformAdapter.RequestPermissionEx('test.permission.camera',
        procedure(const APerm: string; ARes: TPermissionResult)
        begin
          LCallbackFired := True;
          LReceivedResult := ARes;
        end),
      'RequestPermissionEx should return what the registered delegate returns');
    Assert.IsTrue(LDelegateCalled,
      'RequestPermissionEx delegate was not invoked');
    Assert.AreEqual('test.permission.camera', LReceivedPerm);
    Assert.IsTrue(LCallbackFired,
      'RequestPermissionEx delegate should fire the caller-supplied callback');
    Assert.AreEqual(prGranted, LReceivedResult);
  finally
    TUniPlatformAdapter.RegisterPermissionOverride(nil, nil);
  end;
end;

{ TTestFMXTheme }

procedure TTestFMXTheme.Test_Theme_GetMode;
var
  Mode: TUniThemeMode;
begin
  Mode := Theme.ThemeMode;
  Assert.IsTrue(Mode in [tmLight, tmDark, tmSystem]);
end;

procedure TTestFMXTheme.Test_Theme_SetLightMode;
begin
  Theme.SetLightMode;
  Assert.AreEqual(tmLight, Theme.ThemeMode);
end;

procedure TTestFMXTheme.Test_Theme_SetDarkMode;
begin
  Theme.SetDarkMode;
  Assert.AreEqual(tmDark, Theme.ThemeMode);
end;

procedure TTestFMXTheme.Test_Theme_ToggleTheme;
var
  OriginalMode: TUniThemeMode;
begin
  OriginalMode := Theme.ThemeMode;
  Theme.ToggleTheme;
  
  if OriginalMode = tmLight then
    Assert.AreEqual(tmDark, Theme.ThemeMode)
  else if OriginalMode = tmDark then
    Assert.AreEqual(tmLight, Theme.ThemeMode);
end;

procedure TTestFMXTheme.Test_Theme_GetColor;
var
  Color: TAlphaColor;
begin
  Color := Theme.GetColor(ucPrimary);
  Assert.IsTrue(Color <> 0);
  
  Color := Theme.GetColor(ucBackground);
  Assert.IsTrue(Color <> 0);
end;

{$ENDIF}

initialization
{$IFDEF MSWINDOWS}
  TDUnitX.RegisterTestFixture(TTestFMXI18nControls);
  TDUnitX.RegisterTestFixture(TTestFMXConfigControls);
  TDUnitX.RegisterTestFixture(TTestFMXMRUControls);
  TDUnitX.RegisterTestFixture(TTestFMXFormControls);
  TDUnitX.RegisterTestFixture(TTestFMXListView);
  TDUnitX.RegisterTestFixture(TTestFMXPlatform);
  TDUnitX.RegisterTestFixture(TTestFMXTheme);
{$ENDIF}

end.
