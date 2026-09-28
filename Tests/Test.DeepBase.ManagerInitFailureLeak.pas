unit Test.DeepBase.ManagerInitFailureLeak;
{
  WO-20260925-AUDIT-甲-A5 / A5-R03 回归单元。

  被测缺陷：InitializeEx / InitializeWithDB 把 `FIsInitialized := True` 放在
  `InitializeModules` 之后。模块创建中途抛异常时 FIsInitialized 保持 False，而
  Finalize 首行 `if not FIsInitialized then Exit` 让唯一释放点 FinalizeModules 被跳过
  ⇒ 已创建的模块（Logger/Config/I18n…）整批泄漏，且 InitializeModules 里
  SetGlobalLogger / SetGlobalTranslateCallback 装上的全局指针悬挂在已死对象上。

  注入方式沿用甲 A4 的 A4-02 探针 S2
  （CodeReview/20260925-AUDIT-甲-A4-证据/附件/A402_Manager.dpr.template）：
  用失败版 IConfigStorage 包住真实 FireDAC storage。Manager 在 InitializeModules 内
  FConfig.PreloadCache 有保护、随后的 FConfig.GetConfig 无保护，异常正好落在
  「模块已部分创建」的窗口。
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  DeepBase.Types,
  DeepBase.Storage.Interfaces,
  DeepBase.Logging,
  DeepBase.Config,
  DeepBase.I18n,
  DeepBase.Manager;

type
  EInitInjected = class(Exception);

  /// 配置读取即抛错的 IConfigStorage（失败点选在模块创建窗口内部）
  TFailingConfigStorage = class(TInterfacedObject, IConfigStorage)
  public
    function ReadValue(const Key: string; const Default: string): string;
    procedure WriteValue(const Key, Value, Category, ValueType, Description: string);
    procedure LoadAll(AValues: TDictionary<string, string>);
    procedure LoadByCategory(const Category: string; AValues: TDictionary<string, string>);
    procedure DeleteValue(const Key: string);
    function ValueExists(const Key: string): Boolean;
  end;

  /// 只替换 CreateConfigStorage，其余全部转发给真实 FireDAC storage，
  /// 使连接/建表阶段真实走完，失败只发生在模块创建阶段。
  TInjectingManagerStorage = class(TInterfacedObject, IManagerStorage)
  private
    FInner: IManagerStorage;
  public
    constructor Create(const AInner: IManagerStorage);
    function CountCoreTables(const TableNames: array of string): Integer;
    function TableExists(const TableName: string): Boolean;
    function ColumnExists(const TableName, ColumnName: string): Boolean;
    procedure ExecuteStatement(const SQL: string);
    procedure AddColumn(const TableName, ColumnName, ColumnDef: string);
    function ReadSchemaVersion: string;
    procedure UpdateSchemaInfo(const SchemaVersion, LastUpgradeIso8601: string);
    function ReadProjectInfo(const Key: string): string;
    procedure UpsertProjectInfo(const Key, Value: string);
    function CreateConfigStorage: IConfigStorage;
    function CreateI18nStorage: II18nStorage;
    function CreateThemeStorage: IThemeStorage;
    function CreateSecuritySecretStorage: ISecuritySecretStorage;
    function CreateFormStateStorage: IFormStateStorage;
    function CreateMRUStorage: IMRUStorage;
    function CreateHotkeyStorage: IHotkeyStorage;
  end;

  [TestFixture]
  TManagerInitFailureLeak = class
  private
    FTempRoot: string;
    FRootTxtPath: string;
    procedure ResetGlobalState;
    function MakeManager: TDeepBaseManager;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure InjectedFailureReachesModuleCreationStage;

    [Test]
    procedure FailedInit_ReleasesAlreadyCreatedModules;

    [Test]
    procedure FailedInit_DetachesGlobalLoggerBeforeDestroy;

    [Test]
    procedure FailedInit_ClearsGlobalTranslateCallback;

    [Test]
    procedure FailedInit_DestroyLeavesNoGlobalState;

    [Test]
    procedure FailedInit_ExplicitFinalizeAfterReleaseIsSafe;

    [Test]
    procedure SuccessfulInit_FinalizeThenDestroyReleasesOnce;

    [Test]
    procedure SuccessfulInit_DestroyWithoutFinalizeReleases;

    [Test]
    procedure FailedInitThenSuccessfulReinit_LeavesNoGlobalState;

    [Test]
    procedure InitializeEx_FailurePath_ReleasesGlobalLogger;
  end;

implementation

uses
  DeepBase.Persistence.Manager.FireDAC;

const
  ROOT_TXT = 'root.txt';
  INJECTED_MARK = 'INJECTED-ReadValue';

var
  // 注入开关放在单元级：storage 工厂是类级钩子、注入实例由 Manager 在建连路径内部创建，
  // fixture 拿不到该实例引用；把 Self 捕获进长期存在的工厂闭包会在用例结束后悬垂。
  GInjectConfigReadFailure: Boolean;

{ TFailingConfigStorage }

function TFailingConfigStorage.ReadValue(const Key, Default: string): string;
begin
  raise EInitInjected.Create(INJECTED_MARK);
end;

procedure TFailingConfigStorage.WriteValue(const Key, Value, Category, ValueType,
  Description: string);
begin
  raise EInitInjected.Create('INJECTED-WriteValue');
end;

procedure TFailingConfigStorage.LoadAll(AValues: TDictionary<string, string>);
begin
  raise EInitInjected.Create('INJECTED-LoadAll');
end;

procedure TFailingConfigStorage.LoadByCategory(const Category: string;
  AValues: TDictionary<string, string>);
begin
  raise EInitInjected.Create('INJECTED-LoadByCategory');
end;

procedure TFailingConfigStorage.DeleteValue(const Key: string);
begin
end;

function TFailingConfigStorage.ValueExists(const Key: string): Boolean;
begin
  Result := False;
end;

{ TInjectingManagerStorage }

constructor TInjectingManagerStorage.Create(const AInner: IManagerStorage);
begin
  inherited Create;
  FInner := AInner;
end;

function TInjectingManagerStorage.CountCoreTables(
  const TableNames: array of string): Integer;
begin
  Result := FInner.CountCoreTables(TableNames);
end;

function TInjectingManagerStorage.TableExists(const TableName: string): Boolean;
begin
  Result := FInner.TableExists(TableName);
end;

function TInjectingManagerStorage.ColumnExists(const TableName,
  ColumnName: string): Boolean;
begin
  Result := FInner.ColumnExists(TableName, ColumnName);
end;

procedure TInjectingManagerStorage.ExecuteStatement(const SQL: string);
begin
  FInner.ExecuteStatement(SQL);
end;

procedure TInjectingManagerStorage.AddColumn(const TableName, ColumnName,
  ColumnDef: string);
begin
  FInner.AddColumn(TableName, ColumnName, ColumnDef);
end;

function TInjectingManagerStorage.ReadSchemaVersion: string;
begin
  Result := FInner.ReadSchemaVersion;
end;

procedure TInjectingManagerStorage.UpdateSchemaInfo(const SchemaVersion,
  LastUpgradeIso8601: string);
begin
  FInner.UpdateSchemaInfo(SchemaVersion, LastUpgradeIso8601);
end;

function TInjectingManagerStorage.ReadProjectInfo(const Key: string): string;
begin
  Result := FInner.ReadProjectInfo(Key);
end;

procedure TInjectingManagerStorage.UpsertProjectInfo(const Key, Value: string);
begin
  FInner.UpsertProjectInfo(Key, Value);
end;

function TInjectingManagerStorage.CreateConfigStorage: IConfigStorage;
begin
  if GInjectConfigReadFailure then
    Result := TFailingConfigStorage.Create
  else
    Result := FInner.CreateConfigStorage;
end;

function TInjectingManagerStorage.CreateI18nStorage: II18nStorage;
begin
  Result := FInner.CreateI18nStorage;
end;

function TInjectingManagerStorage.CreateThemeStorage: IThemeStorage;
begin
  Result := FInner.CreateThemeStorage;
end;

function TInjectingManagerStorage.CreateSecuritySecretStorage: ISecuritySecretStorage;
begin
  Result := FInner.CreateSecuritySecretStorage;
end;

function TInjectingManagerStorage.CreateFormStateStorage: IFormStateStorage;
begin
  Result := FInner.CreateFormStateStorage;
end;

function TInjectingManagerStorage.CreateMRUStorage: IMRUStorage;
begin
  Result := FInner.CreateMRUStorage;
end;

function TInjectingManagerStorage.CreateHotkeyStorage: IHotkeyStorage;
begin
  Result := FInner.CreateHotkeyStorage;
end;

{ TManagerInitFailureLeak }

procedure TManagerInitFailureLeak.ResetGlobalState;
begin
  SetGlobalLogger(nil);
  SetGlobalTranslateCallback(nil);
end;

function TManagerInitFailureLeak.MakeManager: TDeepBaseManager;
begin
  Result := TDeepBaseManager.Create(nil);
end;

procedure TManagerInitFailureLeak.Setup;
begin
  GInjectConfigReadFailure := False;
  FRootTxtPath := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), ROOT_TXT);
  FTempRoot := TPath.Combine(TPath.GetTempPath,
    'DeepBaseA5R03_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FTempRoot);
  RegisterManagerConnectionAdapter;
  TDeepBaseManager.SetStorageFactory(
    function(AConnection: TObject): IManagerStorage
    begin
      Result := TInjectingManagerStorage.Create(
        CreateManagerStorage(TFDConnection(AConnection)));
    end);
  // 全局单例与本 fixture 无关，先收干净，避免前序用例留下的状态串到这里
  if DeepBase.Manager.DeepBase.IsInitialized then
    DeepBase.Manager.DeepBase.Finalize;
  ResetGlobalState;
end;

procedure TManagerInitFailureLeak.TearDown;
begin
  GInjectConfigReadFailure := False;
  if TFile.Exists(FRootTxtPath) then
    TFile.Delete(FRootTxtPath);
  ResetGlobalState;
  RegisterManagerStorageFactory;
  if TDirectory.Exists(FTempRoot) then
    TDirectory.Delete(FTempRoot, True);
end;

procedure TManagerInitFailureLeak.InjectedFailureReachesModuleCreationStage;
var
  M: TDeepBaseManager;
begin
  GInjectConfigReadFailure := True;
  M := MakeManager;
  try
    Assert.IsFalse(M.InitializeWithDB(':memory:'),
      '注入的配置读取异常必须让初始化失败（fail-closed，不得静默成功）');
    Assert.IsFalse(M.IsInitialized, '失败路径不得报告已初始化');
    Assert.IsTrue(Pos(INJECTED_MARK, M.LastError) > 0,
      '前置条件：异常确实发生在模块创建窗口内，而不是连接/建表阶段之前 ' + M.LastError);
  finally
    M.Free;
  end;
end;

procedure TManagerInitFailureLeak.FailedInit_ReleasesAlreadyCreatedModules;
var
  M: TDeepBaseManager;
begin
  GInjectConfigReadFailure := True;
  M := MakeManager;
  try
    M.InitializeWithDB(':memory:');
    // 失败返回后，本次已经创建出来的模块必须被自己收走，
    // 不能把半初始化的实例留在管理器字段上（那正是 Finalize 跳过时的泄漏现场）。
    Assert.IsNull(M.Logger, '失败路径必须释放已创建的 Logger');
    Assert.IsNull(M.Config, '失败路径必须释放已创建的 Config');
    Assert.IsNull(M.I18n, '失败路径必须释放已创建的 I18n');
  finally
    M.Free;
  end;
end;

procedure TManagerInitFailureLeak.FailedInit_DetachesGlobalLoggerBeforeDestroy;
begin
  GInjectConfigReadFailure := True;
  var M := MakeManager;
  try
    M.InitializeWithDB(':memory:');
    Assert.IsFalse(IsLoggerInitialized,
      'InitializeModules 装上的全局 logger 必须随失败路径摘除，' +
      '否则宿主释放后 Logger() 仍指向已死对象');
  finally
    M.Free;
  end;
end;

procedure TManagerInitFailureLeak.FailedInit_ClearsGlobalTranslateCallback;
begin
  GInjectConfigReadFailure := True;
  var M := MakeManager;
  try
    M.InitializeWithDB(':memory:');
    Assert.IsFalse(IsTranslateCallbackSet,
      '全局翻译回调指向 FI18n，失败路径必须一起清空（FinalizeModules 的同一段职责）');
  finally
    M.Free;
  end;
end;

procedure TManagerInitFailureLeak.FailedInit_DestroyLeavesNoGlobalState;
begin
  GInjectConfigReadFailure := True;
  var M := MakeManager;
  try
    M.InitializeWithDB(':memory:');
  finally
    M.Free;
  end;
  Assert.IsFalse(IsLoggerInitialized,
    'A4-02 S2 判据：释放后 loggerInstalled 必须为 0（修前为 1 且 samePtr 悬挂）');
  Assert.IsFalse(IsTranslateCallbackSet, '释放后不得残留全局翻译回调');
end;

procedure TManagerInitFailureLeak.FailedInit_ExplicitFinalizeAfterReleaseIsSafe;
var
  M: TDeepBaseManager;
begin
  GInjectConfigReadFailure := True;
  M := MakeManager;
  try
    M.InitializeWithDB(':memory:');
    M.Finalize;
    M.Finalize;
    Assert.IsFalse(IsLoggerInitialized,
      '失败路径已释放后，调用方再显式 Finalize 必须是幂等空操作（不得双释放）');
  finally
    M.Free;
  end;
end;

procedure TManagerInitFailureLeak.SuccessfulInit_FinalizeThenDestroyReleasesOnce;
var
  M: TDeepBaseManager;
begin
  M := MakeManager;
  try
    Assert.IsTrue(M.InitializeWithDB(':memory:'), '对照用例：正常初始化应成功');
    Assert.IsTrue(IsLoggerInitialized, '成功初始化后全局 logger 应就位');
    M.Finalize;
    Assert.IsFalse(IsLoggerInitialized, 'Finalize 必须摘除全局 logger');
  finally
    M.Free;
  end;
  Assert.IsFalse(IsLoggerInitialized,
    'Finalize 之后析构不得再次释放同一批模块（防修出双释放）');
end;

procedure TManagerInitFailureLeak.SuccessfulInit_DestroyWithoutFinalizeReleases;
var
  M: TDeepBaseManager;
begin
  M := MakeManager;
  Assert.IsTrue(M.InitializeWithDB(':memory:'), '对照用例：正常初始化应成功');
  M.Free;
  Assert.IsFalse(IsLoggerInitialized, '未显式 Finalize 时析构必须完成释放');
  Assert.IsFalse(IsTranslateCallbackSet, '析构后不得残留全局翻译回调');
end;

procedure TManagerInitFailureLeak.FailedInitThenSuccessfulReinit_LeavesNoGlobalState;
var
  M: TDeepBaseManager;
begin
  M := MakeManager;
  try
    GInjectConfigReadFailure := True;
    Assert.IsFalse(M.InitializeWithDB(':memory:'), '第一步：失败初始化');
    GInjectConfigReadFailure := False;
    Assert.IsTrue(M.InitializeWithDB(':memory:'),
      '同一实例在失败路径之后仍应能重新初始化（失败路径不得留下占位字段）');
    Assert.IsTrue(IsLoggerInitialized, '重新初始化后全局 logger 应就位');
  finally
    M.Free;
  end;
  Assert.IsFalse(IsLoggerInitialized, '二次初始化后释放必须干净');
end;

procedure TManagerInitFailureLeak.InitializeEx_FailurePath_ReleasesGlobalLogger;
var
  M: TDeepBaseManager;
  ErrorMsg: string;
  Ok: Boolean;
begin
  // InitializeEx 走 root.txt + {AppName}Config.db 路径，与 InitializeWithDB 是两条 except 分支
  TFile.WriteAllText(FRootTxtPath, FTempRoot + sLineBreak, TEncoding.UTF8);
  GInjectConfigReadFailure := True;
  M := MakeManager;
  try
    Ok := M.InitializeEx(ErrorMsg);
    Assert.IsFalse(Ok, 'InitializeEx 失败路径应返回 False: ' + ErrorMsg);
    Assert.IsTrue(Pos(INJECTED_MARK, M.LastError) > 0,
      '前置条件：InitializeEx 的异常同样落在模块创建窗口内 ' + M.LastError);
    Assert.IsNull(M.Logger, 'InitializeEx 失败路径必须释放已创建的 Logger');
  finally
    M.Free;
  end;
  Assert.IsFalse(IsLoggerInitialized,
    'InitializeEx 失败路径同样不得把全局 logger 留在原地（两条 except 分支同修）');
end;

initialization
  TDUnitX.RegisterTestFixture(TManagerInitFailureLeak);

end.
