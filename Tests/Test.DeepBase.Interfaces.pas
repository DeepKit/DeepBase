{ ============================================================================
  Test.DeepBase.Interfaces - Unit Tests for Core Interfaces
  
  Test Coverage:
    - IDeepBaseConfig mock implementation
    - IDeepBaseLogger mock implementation
    - IDeepBaseI18n mock implementation
    - IDeepBaseMRU mock implementation
    - IDeepBaseManager mock implementation
  ============================================================================ }

unit Test.DeepBase.Interfaces;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Math,
  System.Generics.Collections,
  DeepBase.Types,
  DeepBase.Interfaces;

type
  // Mock implementations for interfaces
  TMockConfig = class(TInterfacedObject, IDeepBaseConfig)
  private
    FStore: TDictionary<string, string>;
  public
    constructor Create;
    destructor Destroy; override;
    
    function GetConfig(const Key: string; const Default: string = ''): string;
    procedure SetConfig(const Key, Value: string; const Category: string = 'General');
    function GetConfigInt(const Key: string; Default: Integer = 0): Integer;
    procedure SetConfigInt(const Key: string; Value: Integer; const Category: string = 'General');
    function GetConfigBool(const Key: string; Default: Boolean = False): Boolean;
    procedure SetConfigBool(const Key: string; Value: Boolean; const Category: string = 'General');
    function GetConfigFloat(const Key: string; Default: Double = 0): Double;
    procedure SetConfigFloat(const Key: string; Value: Double; const Category: string = 'General');
    function GetConfigEncrypted(const Key: string; const Default: string = ''): string;
    procedure SetConfigEncrypted(const Key, Value: string; const Category: string = 'General');
    procedure DeleteConfig(const Key: string);
    function ConfigExists(const Key: string): Boolean;
    procedure ClearCache;
    procedure PreloadCache;
  end;

  TMockLogger = class(TInterfacedObject, IDeepBaseLogger)
  private
    FMinLevel: TLogLevel;
    FMessages: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Log(const Msg: string; Level: TLogLevel = llInfo; const Source: string = '');
    procedure Debug(const Msg: string; const Source: string = '');
    procedure Info(const Msg: string; const Source: string = '');
    procedure Warn(const Msg: string; const Source: string = '');
    procedure Error(const Msg: string; const Source: string = '');
    procedure Fatal(const Msg: string; const Source: string = '');
    procedure LogException(E: Exception; const Msg: string = ''; Level: TLogLevel = llError);
    function GetMinLevel: TLogLevel;
    procedure SetMinLevel(Value: TLogLevel);
  end;

  TMockI18n = class(TInterfacedObject, IDeepBaseI18n)
  private
    FLang: string;
  public
    constructor Create;
    
    function Translate(const Text: string): string;
    function TranslateTo(const Text, LangCode: string): string;
    function TranslateFormat(const Text: string; const Args: array of const): string;
    function TranslatePlural(const Singular, Plural: string; Count: Integer): string;
    function GetAvailableLanguages: TLanguageInfoArray;
    function GetCurrentLanguage: string;
    procedure SetCurrentLanguage(const Value: string);
    procedure ClearCache;
  end;

  TMockMRU = class(TInterfacedObject, IDeepBaseMRU)
  private
    FItems: TDictionary<string, TList<string>>;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure AddMRU(const Category, ItemKey: string; const DisplayName: string = ''; IconIndex: Integer = 0);
    function GetMRUList(const Category: string; MaxItems: Integer = 10): TArray<string>;
    function GetMRUItems(const Category: string; MaxItems: Integer = 10): TMRUItemArray;
    procedure RemoveMRU(const Category, ItemKey: string);
    procedure ClearMRU(const Category: string);
    function RemoveInvalidMRU(const Category: string = ''): Integer;
    procedure SetPinned(const Category, ItemKey: string; IsPinned: Boolean);
    function IsPinned(const Category, ItemKey: string): Boolean;
    function GetMRUCount(const Category: string): Integer;
  end;

  TMockManager = class(TInterfacedObject, IDeepBaseManager)
  private
    FConfig: IDeepBaseConfig;
    FLogger: IDeepBaseLogger;
    FI18n: IDeepBaseI18n;
    FMRU: IDeepBaseMRU;
    FRootPath: string;
    FInitialized: Boolean;
  public
    constructor Create;
    
    function Initialize: Boolean;
    procedure Finalize;
    function GetIsInitialized: Boolean;
    function GetConfig: IDeepBaseConfig;
    function GetLogger: IDeepBaseLogger;
    function GetI18n: IDeepBaseI18n;
    function GetMRU: IDeepBaseMRU;
    function GetRootPath: string;
  end;

  [TestFixture]
  TTestInterfaces = class
  public
    [Test]
    procedure Test_Config_Interface_Basic;
    [Test]
    procedure Test_Logger_Interface_Basic;
    [Test]
    procedure Test_I18n_Interface_Basic;
    [Test]
    procedure Test_MRU_Interface_Basic;
    [Test]
    procedure Test_Manager_Interface_Basic;
  end;

implementation

{ TMockConfig }

constructor TMockConfig.Create;
begin
  inherited Create;
  FStore := TDictionary<string, string>.Create;
end;

destructor TMockConfig.Destroy;
begin
  FStore.Free;
  inherited;
end;

function TMockConfig.GetConfig(const Key, Default: string): string;
begin
  if not FStore.TryGetValue(Key, Result) then
    Result := Default;
end;

procedure TMockConfig.SetConfig(const Key, Value, Category: string);
begin
  FStore.AddOrSetValue(Key, Value);
end;

function TMockConfig.GetConfigInt(const Key: string; Default: Integer): Integer;
var
  S: string;
begin
  S := GetConfig(Key, IntToStr(Default));
  Result := StrToIntDef(S, Default);
end;

procedure TMockConfig.SetConfigInt(const Key: string; Value: Integer; const Category: string);
begin
  SetConfig(Key, IntToStr(Value), Category);
end;

function TMockConfig.GetConfigBool(const Key: string; Default: Boolean): Boolean;
var
  S: string;
begin
  S := GetConfig(Key, BoolToStr(Default, True));
  Result := SameText(S, 'True') or SameText(S, '1');
end;

procedure TMockConfig.SetConfigBool(const Key: string; Value: Boolean; const Category: string);
begin
  SetConfig(Key, BoolToStr(Value, True), Category);
end;

function TMockConfig.GetConfigFloat(const Key: string; Default: Double): Double;
var
  S: string;
begin
  S := GetConfig(Key, FloatToStr(Default));
  Result := StrToFloatDef(S, Default);
end;

procedure TMockConfig.SetConfigFloat(const Key: string; Value: Double; const Category: string);
begin
  SetConfig(Key, FloatToStr(Value), Category);
end;

function TMockConfig.GetConfigEncrypted(const Key, Default: string): string;
begin
  Result := GetConfig(Key, Default);
end;

procedure TMockConfig.SetConfigEncrypted(const Key, Value, Category: string);
begin
  SetConfig(Key, Value, Category);
end;

procedure TMockConfig.DeleteConfig(const Key: string);
begin
  FStore.Remove(Key);
end;

function TMockConfig.ConfigExists(const Key: string): Boolean;
begin
  Result := FStore.ContainsKey(Key);
end;

procedure TMockConfig.ClearCache;
begin
  FStore.Clear;
end;

procedure TMockConfig.PreloadCache;
begin
  // No-op in mock
end;

{ TMockLogger }

constructor TMockLogger.Create;
begin
  inherited Create;
  FMinLevel := llDebug;
  FMessages := TList<string>.Create;
end;

destructor TMockLogger.Destroy;
begin
  FMessages.Free;
  inherited;
end;

procedure TMockLogger.Log(const Msg: string; Level: TLogLevel; const Source: string);
begin
  if Level < FMinLevel then
    Exit;
  FMessages.Add(Msg);
end;

procedure TMockLogger.Debug(const Msg, Source: string);
begin
  Log(Msg, llDebug, Source);
end;

procedure TMockLogger.Info(const Msg, Source: string);
begin
  Log(Msg, llInfo, Source);
end;

procedure TMockLogger.Warn(const Msg, Source: string);
begin
  Log(Msg, llWarn, Source);
end;

procedure TMockLogger.Error(const Msg, Source: string);
begin
  Log(Msg, llError, Source);
end;

procedure TMockLogger.Fatal(const Msg, Source: string);
begin
  Log(Msg, llFatal, Source);
end;

procedure TMockLogger.LogException(E: Exception; const Msg: string; Level: TLogLevel);
begin
  Log(Format('%s: %s', [E.ClassName, Msg]), Level);
end;

function TMockLogger.GetMinLevel: TLogLevel;
begin
  Result := FMinLevel;
end;

procedure TMockLogger.SetMinLevel(Value: TLogLevel);
begin
  FMinLevel := Value;
end;

{ TMockI18n }

constructor TMockI18n.Create;
begin
  inherited Create;
  FLang := 'en';
end;

function TMockI18n.Translate(const Text: string): string;
begin
  Result := '[T]' + FLang + ':' + Text;
end;

function TMockI18n.TranslateTo(const Text, LangCode: string): string;
begin
  Result := '[T]' + LangCode + ':' + Text;
end;

function TMockI18n.TranslateFormat(const Text: string; const Args: array of const): string;
begin
  Result := Format(Text, Args);
end;

function TMockI18n.TranslatePlural(const Singular, Plural: string; Count: Integer): string;
begin
  if Count = 1 then
    Result := Singular
  else
    Result := Plural;
end;

function TMockI18n.GetAvailableLanguages: TLanguageInfoArray;
begin
  SetLength(Result, 2);
  Result[0].LangCode := 'en';
  Result[0].LangName := 'English';
  Result[1].LangCode := 'zh-CN';
  Result[1].LangName := 'Simplified Chinese';
end;

function TMockI18n.GetCurrentLanguage: string;
begin
  Result := FLang;
end;

procedure TMockI18n.SetCurrentLanguage(const Value: string);
begin
  FLang := Value;
end;

procedure TMockI18n.ClearCache;
begin
  // No-op in mock
end;

{ TMockMRU }

constructor TMockMRU.Create;
begin
  inherited Create;
  FItems := TDictionary<string, TList<string>>.Create;
end;

destructor TMockMRU.Destroy;
var
  Pair: TPair<string, TList<string>>;
begin
  for Pair in FItems do
    Pair.Value.Free;
  FItems.Free;
  inherited;
end;

procedure TMockMRU.AddMRU(const Category, ItemKey, DisplayName: string; IconIndex: Integer);
var
  List: TList<string>;
begin
  if not FItems.TryGetValue(Category, List) then
  begin
    List := TList<string>.Create;
    FItems.Add(Category, List);
  end;
  if not List.Contains(ItemKey) then
    List.Insert(0, ItemKey);
end;

function TMockMRU.GetMRUList(const Category: string; MaxItems: Integer): TArray<string>;
var
  List: TList<string>;
  I, Count: Integer;
begin
  if not FItems.TryGetValue(Category, List) then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  Count := Min(MaxItems, List.Count);
  SetLength(Result, Count);
  for I := 0 to Count - 1 do
    Result[I] := List[I];
end;

function TMockMRU.GetMRUItems(const Category: string; MaxItems: Integer): TMRUItemArray;
begin
  // Simplified: only return keys
  var Keys := GetMRUList(Category, MaxItems);
  SetLength(Result, Length(Keys));
  for var I := 0 to High(Keys) do
    Result[I].ItemKey := Keys[I];
end;

procedure TMockMRU.RemoveMRU(const Category, ItemKey: string);
var
  List: TList<string>;
begin
  if FItems.TryGetValue(Category, List) then
    List.Remove(ItemKey);
end;

procedure TMockMRU.ClearMRU(const Category: string);
var
  List: TList<string>;
begin
  if FItems.TryGetValue(Category, List) then
    List.Clear;
end;

function TMockMRU.RemoveInvalidMRU(const Category: string): Integer;
begin
  // Not tracking validity; return 0 in mock
  Result := 0;
end;

procedure TMockMRU.SetPinned(const Category, ItemKey: string; IsPinned: Boolean);
begin
  // No-op in mock
end;

function TMockMRU.IsPinned(const Category, ItemKey: string): Boolean;
begin
  Result := False;
end;

function TMockMRU.GetMRUCount(const Category: string): Integer;
var
  List: TList<string>;
begin
  if FItems.TryGetValue(Category, List) then
    Result := List.Count
  else
    Result := 0;
end;

{ TMockManager }

constructor TMockManager.Create;
begin
  inherited Create;
  FConfig := TMockConfig.Create;
  FLogger := TMockLogger.Create;
  FI18n := TMockI18n.Create;
  FMRU := TMockMRU.Create;
  FRootPath := 'C:\DeepBaseTestRoot';
  FInitialized := False;
end;

function TMockManager.Initialize: Boolean;
begin
  FInitialized := True;
  Result := True;
end;

procedure TMockManager.Finalize;
begin
  FInitialized := False;
end;

function TMockManager.GetIsInitialized: Boolean;
begin
  Result := FInitialized;
end;

function TMockManager.GetConfig: IDeepBaseConfig;
begin
  Result := FConfig;
end;

function TMockManager.GetLogger: IDeepBaseLogger;
begin
  Result := FLogger;
end;

function TMockManager.GetI18n: IDeepBaseI18n;
begin
  Result := FI18n;
end;

function TMockManager.GetMRU: IDeepBaseMRU;
begin
  Result := FMRU;
end;

function TMockManager.GetRootPath: string;
begin
  Result := FRootPath;
end;

{ TTestInterfaces }

procedure TTestInterfaces.Test_Config_Interface_Basic;
var
  C: IDeepBaseConfig;
begin
  C := TMockConfig.Create;
  C.SetConfig('Key1', 'Value1');
  Assert.AreEqual('Value1', C.GetConfig('Key1'));
  Assert.IsTrue(C.ConfigExists('Key1'));
  C.DeleteConfig('Key1');
  Assert.IsFalse(C.ConfigExists('Key1'));
end;

procedure TTestInterfaces.Test_Logger_Interface_Basic;
var
  L: IDeepBaseLogger;
begin
  L := TMockLogger.Create;
  L.Info('Test message', 'Test');
  L.Debug('Debug message');
  L.SetMinLevel(llError);
  L.Error('Error message');
  Assert.IsTrue(True); // Just ensure calls succeed
end;

procedure TTestInterfaces.Test_I18n_Interface_Basic;
var
  I18n: IDeepBaseI18n;
  S: string;
begin
  I18n := TMockI18n.Create;
  S := I18n.Translate('Hello');
  Assert.IsTrue(S.Contains('Hello'));
  
  I18n.CurrentLanguage := 'zh-CN';
  Assert.AreEqual('zh-CN', I18n.CurrentLanguage);
end;

procedure TTestInterfaces.Test_MRU_Interface_Basic;
var
  M: IDeepBaseMRU;
  List: TArray<string>;
begin
  M := TMockMRU.Create;
  M.AddMRU('files', 'file1');
  M.AddMRU('files', 'file2');
  List := M.GetMRUList('files', 10);
  Assert.IsTrue(Length(List) >= 2);
  Assert.AreEqual('file2', List[0]); // last added first
end;

procedure TTestInterfaces.Test_Manager_Interface_Basic;
var
  M: IDeepBaseManager;
  Lang: string;
begin
  M := TMockManager.Create;
  Assert.IsFalse(M.IsInitialized);
  Assert.IsTrue(M.Initialize);
  Assert.IsTrue(M.IsInitialized);
  
  M.Config.SetConfig('Key', 'Val');
  Assert.AreEqual('Val', M.Config.GetConfig('Key'));
  
  Lang := M.I18n.CurrentLanguage;
  M.I18n.CurrentLanguage := 'en';
  Assert.AreEqual('en', M.I18n.CurrentLanguage);
  
  M.MRU.AddMRU('cat', 'item');
  Assert.IsTrue(M.MRU.GetMRUCount('cat') >= 1);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestInterfaces);

end.
