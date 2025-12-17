/// <summary>
/// Unit tests for UniBase.Types module
/// Tests: THealthCheckResult, TInitErrorCode, TLogLevel, helper functions
/// </summary>
unit Test.UniBase.Types;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  UniBase.Types;

type
  /// <summary>
  /// Tests for TInitErrorCode enum and helper function
  /// </summary>
  [TestFixture]
  TInitErrorCodeTests = class
  public
    [Test]
    procedure Test_InitErrorCodeToStr_Success;
    [Test]
    procedure Test_InitErrorCodeToStr_ConfigDBNotFound;
    [Test]
    procedure Test_InitErrorCodeToStr_ConfigDBCorrupted;
    [Test]
    procedure Test_InitErrorCodeToStr_PermissionDenied;
    [Test]
    procedure Test_InitErrorCodeToStr_InvalidPath;
    [Test]
    procedure Test_InitErrorCodeToStr_MissingAssets;
    [Test]
    procedure Test_InitErrorCodeToStr_Unknown;
  end;

  /// <summary>
  /// Tests for TLogLevel enum and helper functions
  /// </summary>
  [TestFixture]
  TLogLevelTests = class
  public
    [Test]
    procedure Test_LogLevelToStr_Debug;
    [Test]
    procedure Test_LogLevelToStr_Info;
    [Test]
    procedure Test_LogLevelToStr_Warn;
    [Test]
    procedure Test_LogLevelToStr_Error;
    [Test]
    procedure Test_LogLevelToStr_Fatal;
    [Test]
    procedure Test_StrToLogLevel_Debug;
    [Test]
    procedure Test_StrToLogLevel_Info;
    [Test]
    procedure Test_StrToLogLevel_Warn;
    [Test]
    procedure Test_StrToLogLevel_Warning;
    [Test]
    procedure Test_StrToLogLevel_Error;
    [Test]
    procedure Test_StrToLogLevel_Fatal;
    [Test]
    procedure Test_StrToLogLevel_CaseInsensitive;
    [Test]
    procedure Test_StrToLogLevel_Unknown;
  end;

  /// <summary>
  /// Tests for THealthCheckResult record
  /// </summary>
  [TestFixture]
  THealthCheckResultTests = class
  public
    [Test]
    procedure Test_Init_DefaultValues;
    [Test]
    procedure Test_Init_EmptyMessages;
    [Test]
    procedure Test_AddMessage_Single;
    [Test]
    procedure Test_AddMessage_Multiple;
    [Test]
    procedure Test_AddMessage_GrowsArray;
    [Test]
    procedure Test_MessageCount_AfterAdd;
    [Test]
    procedure Test_TrimMessages_ReducesLength;
    [Test]
    procedure Test_TrimMessages_WhenAlreadyTrimmed;
  end;

  /// <summary>
  /// Tests for TLanguageInfo record
  /// </summary>
  [TestFixture]
  TLanguageInfoTests = class
  public
    [Test]
    procedure Test_Record_Fields;
    [Test]
    procedure Test_Record_Assignment;
    [Test]
    procedure Test_Array_Type;
  end;

  /// <summary>
  /// Tests for TMRUItem record
  /// </summary>
  [TestFixture]
  TMRUItemTests = class
  public
    [Test]
    procedure Test_Record_Fields;
    [Test]
    procedure Test_Record_Assignment;
    [Test]
    procedure Test_Array_Type;
  end;

  /// <summary>
  /// Tests for TThemeInfo record
  /// </summary>
  [TestFixture]
  TThemeInfoTests = class
  public
    [Test]
    procedure Test_Record_Fields;
    [Test]
    procedure Test_Record_Assignment;
    [Test]
    procedure Test_Array_Type;
  end;

  /// <summary>
  /// Tests for TAnimationAssetData record
  /// </summary>
  [TestFixture]
  TAnimationAssetDataTests = class
  public
    [Test]
    procedure Test_Record_Fields;
    [Test]
    procedure Test_Record_Assignment;
  end;

  /// <summary>
  /// Tests for TUpdateInfo record
  /// </summary>
  [TestFixture]
  TUpdateInfoTests = class
  public
    [Test]
    procedure Test_Record_Fields;
    [Test]
    procedure Test_Record_Assignment;
    [Test]
    procedure Test_ForceUpdate_Default;
  end;

  /// <summary>
  /// Tests for THotkeyDefault record
  /// </summary>
  [TestFixture]
  THotkeyDefaultTests = class
  public
    [Test]
    procedure Test_Record_Fields;
    [Test]
    procedure Test_Record_Assignment;
  end;

implementation

// ============================================================================
// TInitErrorCodeTests
// ============================================================================

procedure TInitErrorCodeTests.Test_InitErrorCodeToStr_Success;
begin
  Assert.AreEqual('Success', InitErrorCodeToStr(ecSuccess));
end;

procedure TInitErrorCodeTests.Test_InitErrorCodeToStr_ConfigDBNotFound;
begin
  Assert.AreEqual('ConfigDB Not Found', InitErrorCodeToStr(ecConfigDBNotFound));
end;

procedure TInitErrorCodeTests.Test_InitErrorCodeToStr_ConfigDBCorrupted;
begin
  Assert.AreEqual('ConfigDB Corrupted', InitErrorCodeToStr(ecConfigDBCorrupted));
end;

procedure TInitErrorCodeTests.Test_InitErrorCodeToStr_PermissionDenied;
begin
  Assert.AreEqual('Permission Denied', InitErrorCodeToStr(ecPermissionDenied));
end;

procedure TInitErrorCodeTests.Test_InitErrorCodeToStr_InvalidPath;
begin
  Assert.AreEqual('Invalid Path', InitErrorCodeToStr(ecInvalidPath));
end;

procedure TInitErrorCodeTests.Test_InitErrorCodeToStr_MissingAssets;
begin
  Assert.AreEqual('Missing Assets', InitErrorCodeToStr(ecMissingAssets));
end;

procedure TInitErrorCodeTests.Test_InitErrorCodeToStr_Unknown;
begin
  Assert.AreEqual('Unknown Error', InitErrorCodeToStr(ecUnknown));
end;

// ============================================================================
// TLogLevelTests
// ============================================================================

procedure TLogLevelTests.Test_LogLevelToStr_Debug;
begin
  Assert.AreEqual('DEBUG', LogLevelToStr(llDebug));
end;

procedure TLogLevelTests.Test_LogLevelToStr_Info;
begin
  Assert.AreEqual('INFO', LogLevelToStr(llInfo));
end;

procedure TLogLevelTests.Test_LogLevelToStr_Warn;
begin
  Assert.AreEqual('WARN', LogLevelToStr(llWarn));
end;

procedure TLogLevelTests.Test_LogLevelToStr_Error;
begin
  Assert.AreEqual('ERROR', LogLevelToStr(llError));
end;

procedure TLogLevelTests.Test_LogLevelToStr_Fatal;
begin
  Assert.AreEqual('FATAL', LogLevelToStr(llFatal));
end;

procedure TLogLevelTests.Test_StrToLogLevel_Debug;
begin
  Assert.AreEqual(llDebug, StrToLogLevel('DEBUG'));
end;

procedure TLogLevelTests.Test_StrToLogLevel_Info;
begin
  Assert.AreEqual(llInfo, StrToLogLevel('INFO'));
end;

procedure TLogLevelTests.Test_StrToLogLevel_Warn;
begin
  Assert.AreEqual(llWarn, StrToLogLevel('WARN'));
end;

procedure TLogLevelTests.Test_StrToLogLevel_Warning;
begin
  // WARNING is also accepted as WARN
  Assert.AreEqual(llWarn, StrToLogLevel('WARNING'));
end;

procedure TLogLevelTests.Test_StrToLogLevel_Error;
begin
  Assert.AreEqual(llError, StrToLogLevel('ERROR'));
end;

procedure TLogLevelTests.Test_StrToLogLevel_Fatal;
begin
  Assert.AreEqual(llFatal, StrToLogLevel('FATAL'));
end;

procedure TLogLevelTests.Test_StrToLogLevel_CaseInsensitive;
begin
  Assert.AreEqual(llDebug, StrToLogLevel('debug'));
  Assert.AreEqual(llDebug, StrToLogLevel('Debug'));
  Assert.AreEqual(llInfo, StrToLogLevel('info'));
  Assert.AreEqual(llWarn, StrToLogLevel('warn'));
  Assert.AreEqual(llError, StrToLogLevel('error'));
  Assert.AreEqual(llFatal, StrToLogLevel('fatal'));
end;

procedure TLogLevelTests.Test_StrToLogLevel_Unknown;
begin
  // Unknown strings default to INFO
  Assert.AreEqual(llInfo, StrToLogLevel('UNKNOWN'));
  Assert.AreEqual(llInfo, StrToLogLevel(''));
  Assert.AreEqual(llInfo, StrToLogLevel('something'));
end;

// ============================================================================
// THealthCheckResultTests
// ============================================================================

procedure THealthCheckResultTests.Test_Init_DefaultValues;
var
  Result: THealthCheckResult;
begin
  Result.Init;
  Assert.IsFalse(Result.IsHealthy);
  Assert.IsFalse(Result.ConfigDBOk);
  Assert.IsFalse(Result.AssetsDirOk);
  Assert.IsFalse(Result.LLMConnectionOk);
end;

procedure THealthCheckResultTests.Test_Init_EmptyMessages;
var
  Result: THealthCheckResult;
begin
  Result.Init;
  Assert.AreEqual(0, Result.MessageCount);
  Assert.AreEqual(Integer(0), Integer(Length(Result.Messages)));
end;

procedure THealthCheckResultTests.Test_AddMessage_Single;
var
  Result: THealthCheckResult;
begin
  Result.Init;
  Result.AddMessage('Test message');
  Assert.AreEqual(1, Result.MessageCount);
  Assert.AreEqual('Test message', Result.Messages[0]);
end;

procedure THealthCheckResultTests.Test_AddMessage_Multiple;
var
  Result: THealthCheckResult;
begin
  Result.Init;
  Result.AddMessage('Message 1');
  Result.AddMessage('Message 2');
  Result.AddMessage('Message 3');
  Assert.AreEqual(3, Result.MessageCount);
  Assert.AreEqual('Message 1', Result.Messages[0]);
  Assert.AreEqual('Message 2', Result.Messages[1]);
  Assert.AreEqual('Message 3', Result.Messages[2]);
end;

procedure THealthCheckResultTests.Test_AddMessage_GrowsArray;
var
  Result: THealthCheckResult;
  I: Integer;
begin
  Result.Init;
  // Add more than initial allocation (grows by 8)
  for I := 1 to 20 do
    Result.AddMessage('Message ' + IntToStr(I));
    
  Assert.AreEqual(20, Result.MessageCount);
  // Array length should be at least 20, rounded up by GROW_SIZE
  Assert.IsTrue(Length(Result.Messages) >= 20);
  Assert.AreEqual('Message 1', Result.Messages[0]);
  Assert.AreEqual('Message 20', Result.Messages[19]);
end;

procedure THealthCheckResultTests.Test_MessageCount_AfterAdd;
var
  Result: THealthCheckResult;
begin
  Result.Init;
  Assert.AreEqual(0, Result.MessageCount);
  
  Result.AddMessage('First');
  Assert.AreEqual(1, Result.MessageCount);
  
  Result.AddMessage('Second');
  Assert.AreEqual(2, Result.MessageCount);
end;

procedure THealthCheckResultTests.Test_TrimMessages_ReducesLength;
var
  Result: THealthCheckResult;
begin
  Result.Init;
  Result.AddMessage('Message 1');
  Result.AddMessage('Message 2');
  
  // After adding, array may have extra capacity
  // (first add grows by 8, so Length should be 8)
  Assert.IsTrue(Length(Result.Messages) >= Result.MessageCount);
  
  Result.TrimMessages;
  
  // After trim, Length equals MessageCount
  Assert.AreEqual(Result.MessageCount, Integer(Length(Result.Messages)));
  Assert.AreEqual(Integer(2), Integer(Length(Result.Messages)));
end;

procedure THealthCheckResultTests.Test_TrimMessages_WhenAlreadyTrimmed;
var
  Result: THealthCheckResult;
begin
  Result.Init;
  Result.AddMessage('Only one');
  Result.TrimMessages;
  
  // Trimming again should be safe
  Result.TrimMessages;
  
  Assert.AreEqual(1, Result.MessageCount);
  Assert.AreEqual(Integer(1), Integer(Length(Result.Messages)));
end;

// ============================================================================
// TLanguageInfoTests
// ============================================================================

procedure TLanguageInfoTests.Test_Record_Fields;
var
  Info: TLanguageInfo;
begin
  Info.LangCode := 'zh-CN';
  Info.LangName := 'Chinese (Simplified)';
  Info.NativeName := '简体中文';
  Info.FlagIcon := 'cn.png';
  Info.IsEnabled := True;
  Info.IsDefault := True;
  
  Assert.AreEqual('zh-CN', Info.LangCode);
  Assert.AreEqual('Chinese (Simplified)', Info.LangName);
  Assert.AreEqual('简体中文', Info.NativeName);
  Assert.AreEqual('cn.png', Info.FlagIcon);
  Assert.IsTrue(Info.IsEnabled);
  Assert.IsTrue(Info.IsDefault);
end;

procedure TLanguageInfoTests.Test_Record_Assignment;
var
  Info1, Info2: TLanguageInfo;
begin
  Info1.LangCode := 'en-US';
  Info1.LangName := 'English';
  Info1.NativeName := 'English';
  Info1.FlagIcon := 'us.png';
  Info1.IsEnabled := True;
  Info1.IsDefault := False;
  
  Info2 := Info1;
  
  Assert.AreEqual(Info1.LangCode, Info2.LangCode);
  Assert.AreEqual(Info1.LangName, Info2.LangName);
  Assert.AreEqual(Info1.NativeName, Info2.NativeName);
  Assert.AreEqual(Info1.IsEnabled, Info2.IsEnabled);
end;

procedure TLanguageInfoTests.Test_Array_Type;
var
  Arr: TLanguageInfoArray;
begin
  SetLength(Arr, 2);
  Arr[0].LangCode := 'en';
  Arr[1].LangCode := 'zh';

  Assert.AreEqual(Integer(2), Integer(Length(Arr)));
  Assert.AreEqual('en', Arr[0].LangCode);
  Assert.AreEqual('zh', Arr[1].LangCode);
end;

// ============================================================================
// TMRUItemTests
// ============================================================================

procedure TMRUItemTests.Test_Record_Fields;
var
  Item: TMRUItem;
begin
  Item.ItemKey := 'file://test.txt';
  Item.DisplayName := 'Test File';
  Item.LastAccess := Now;
  Item.AccessCount := 5;
  Item.IconIndex := 2;
  
  Assert.AreEqual('file://test.txt', Item.ItemKey);
  Assert.AreEqual('Test File', Item.DisplayName);
  Assert.AreEqual(5, Item.AccessCount);
  Assert.AreEqual(2, Item.IconIndex);
end;

procedure TMRUItemTests.Test_Record_Assignment;
var
  Item1, Item2: TMRUItem;
begin
  Item1.ItemKey := 'key1';
  Item1.DisplayName := 'Name1';
  Item1.AccessCount := 10;
  
  Item2 := Item1;
  
  Assert.AreEqual(Item1.ItemKey, Item2.ItemKey);
  Assert.AreEqual(Item1.AccessCount, Item2.AccessCount);
end;

procedure TMRUItemTests.Test_Array_Type;
var
  Arr: TMRUItemArray;
begin
  SetLength(Arr, 3);
  Arr[0].ItemKey := 'key0';
  Arr[1].ItemKey := 'key1';
  Arr[2].ItemKey := 'key2';

  Assert.AreEqual(Integer(3), Integer(Length(Arr)));
  Assert.AreEqual('key1', Arr[1].ItemKey);
end;

// ============================================================================
// TThemeInfoTests
// ============================================================================

procedure TThemeInfoTests.Test_Record_Fields;
var
  Theme: TThemeInfo;
begin
  Theme.Name := 'Dark Mode';
  Theme.StyleFile := 'dark.vsf';
  Theme.IsDark := True;
  Theme.IsBuiltIn := True;
  
  Assert.AreEqual('Dark Mode', Theme.Name);
  Assert.AreEqual('dark.vsf', Theme.StyleFile);
  Assert.IsTrue(Theme.IsDark);
  Assert.IsTrue(Theme.IsBuiltIn);
end;

procedure TThemeInfoTests.Test_Record_Assignment;
var
  Theme1, Theme2: TThemeInfo;
begin
  Theme1.Name := 'Light';
  Theme1.IsDark := False;
  Theme1.IsBuiltIn := True;
  
  Theme2 := Theme1;
  
  Assert.AreEqual(Theme1.Name, Theme2.Name);
  Assert.AreEqual(Theme1.IsDark, Theme2.IsDark);
end;

procedure TThemeInfoTests.Test_Array_Type;
var
  Arr: TThemeInfoArray;
begin
  SetLength(Arr, 2);
  Arr[0].Name := 'Light';
  Arr[0].IsDark := False;
  Arr[1].Name := 'Dark';
  Arr[1].IsDark := True;

  Assert.AreEqual(Integer(2), Integer(Length(Arr)));
  Assert.IsFalse(Arr[0].IsDark);
  Assert.IsTrue(Arr[1].IsDark);
end;

// ============================================================================
// TAnimationAssetDataTests
// ============================================================================

procedure TAnimationAssetDataTests.Test_Record_Fields;
var
  Asset: TAnimationAssetData;
begin
  Asset.Name := 'loading';
  Asset.SvgContent := '<svg>...</svg>';
  Asset.FrameCount := 10;
  Asset.FrameDuration := 100;
  Asset.Width := 64;
  Asset.Height := 64;
  
  Assert.AreEqual('loading', Asset.Name);
  Assert.AreEqual('<svg>...</svg>', Asset.SvgContent);
  Assert.AreEqual(10, Asset.FrameCount);
  Assert.AreEqual(100, Asset.FrameDuration);
  Assert.AreEqual(64, Asset.Width);
  Assert.AreEqual(64, Asset.Height);
end;

procedure TAnimationAssetDataTests.Test_Record_Assignment;
var
  Asset1, Asset2: TAnimationAssetData;
begin
  Asset1.Name := 'spinner';
  Asset1.FrameCount := 12;
  Asset1.Width := 32;
  
  Asset2 := Asset1;
  
  Assert.AreEqual(Asset1.Name, Asset2.Name);
  Assert.AreEqual(Asset1.FrameCount, Asset2.FrameCount);
  Assert.AreEqual(Asset1.Width, Asset2.Width);
end;

// ============================================================================
// TUpdateInfoTests
// ============================================================================

procedure TUpdateInfoTests.Test_Record_Fields;
var
  Info: TUpdateInfo;
begin
  Info.Version := '2.0.0';
  Info.ReleaseDate := EncodeDate(2024, 1, 15);
  Info.DownloadUrl := 'https://example.com/update.zip';
  Info.FileSize := 1024 * 1024 * 50;  // 50 MB
  Info.SHA256 := 'abc123def456';
  Info.Changelog := 'Bug fixes and improvements';
  Info.ForceUpdate := False;
  
  Assert.AreEqual('2.0.0', Info.Version);
  Assert.AreEqual('https://example.com/update.zip', Info.DownloadUrl);
  Assert.AreEqual(Int64(50 * 1024 * 1024), Info.FileSize);
  Assert.AreEqual('abc123def456', Info.SHA256);
  Assert.AreEqual('Bug fixes and improvements', Info.Changelog);
  Assert.IsFalse(Info.ForceUpdate);
end;

procedure TUpdateInfoTests.Test_Record_Assignment;
var
  Info1, Info2: TUpdateInfo;
begin
  Info1.Version := '1.5.0';
  Info1.ForceUpdate := True;
  
  Info2 := Info1;
  
  Assert.AreEqual(Info1.Version, Info2.Version);
  Assert.AreEqual(Info1.ForceUpdate, Info2.ForceUpdate);
end;

procedure TUpdateInfoTests.Test_ForceUpdate_Default;
var
  Info: TUpdateInfo;
begin
  // Default value should be False
  FillChar(Info, SizeOf(Info), 0);
  Assert.IsFalse(Info.ForceUpdate);
end;

// ============================================================================
// THotkeyDefaultTests
// ============================================================================

procedure THotkeyDefaultTests.Test_Record_Fields;
var
  Hotkey: THotkeyDefault;
begin
  Hotkey.ActionName := 'SaveFile';
  Hotkey.Shortcut := 'Ctrl+S';
  Hotkey.Description := 'Save the current file';
  Hotkey.Category := 'File';
  
  Assert.AreEqual('SaveFile', Hotkey.ActionName);
  Assert.AreEqual('Ctrl+S', Hotkey.Shortcut);
  Assert.AreEqual('Save the current file', Hotkey.Description);
  Assert.AreEqual('File', Hotkey.Category);
end;

procedure THotkeyDefaultTests.Test_Record_Assignment;
var
  Hotkey1, Hotkey2: THotkeyDefault;
begin
  Hotkey1.ActionName := 'Copy';
  Hotkey1.Shortcut := 'Ctrl+C';
  Hotkey1.Category := 'Edit';
  
  Hotkey2 := Hotkey1;
  
  Assert.AreEqual(Hotkey1.ActionName, Hotkey2.ActionName);
  Assert.AreEqual(Hotkey1.Shortcut, Hotkey2.Shortcut);
  Assert.AreEqual(Hotkey1.Category, Hotkey2.Category);
end;

initialization
  TDUnitX.RegisterTestFixture(TInitErrorCodeTests);
  TDUnitX.RegisterTestFixture(TLogLevelTests);
  TDUnitX.RegisterTestFixture(THealthCheckResultTests);
  TDUnitX.RegisterTestFixture(TLanguageInfoTests);
  TDUnitX.RegisterTestFixture(TMRUItemTests);
  TDUnitX.RegisterTestFixture(TThemeInfoTests);
  TDUnitX.RegisterTestFixture(TAnimationAssetDataTests);
  TDUnitX.RegisterTestFixture(TUpdateInfoTests);
  TDUnitX.RegisterTestFixture(THotkeyDefaultTests);

end.
