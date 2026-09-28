{ ============================================================================
  A5-R05：IoC 单例双路径收口（三条硬约束）

  判据来源：CodeReview/20260925-AUDIT-甲-A4-证据/附件/A404_IoC.dpr.template
  的 S1/S2/S3 三个探针（改制为单测），外加主控三条硬约束各自的反例面：
    1. 单一真相源 —— 对象先解析 / 接口先解析 / 仅接口登记三种序都必须
       只构造 1 个实例、两条路径同一实例、容器释放后零遗留；
    2. 复用既有实例建接口视图时，不得把按 Create 出来、引用计数为 0 的单例
       抬到 1 再打回 0（对象自毁，容器缓存指针悬垂）；
    3. 只有接口视图、取不到对象视图时，对象路径抛 EIoCException，不再 AV。

  计数口径：三类探针各维护 Created/Destroyed 类变量，Setup 归零，用例互不污染。
  泄漏判据一律在容器释放之后断言，且测试侧的接口引用先放手 —— 否则测试自己的
  引用会成为唯一持有者，把「容器释放即析构」这条判据搅浑。
  ============================================================================ }

unit Test.DeepBase.IoCSingletonIdentity;

{$M+}

interface

uses
  System.SysUtils,
  System.TypInfo,
  DUnitX.TestFramework,
  DeepBase.IoC;

type
  IIoCProbe = interface
    ['{7C1D5E90-4B2A-4F83-9E61-3A57C2B84D11}']
    function Id: Integer;
  end;

  { 引用计数实现的单例（TInterfacedObject）：容器持有接口视图之后，
    对象寿命归引用计数负责，容器不得再 Free。 }
  TIoCRefcountedProbe = class(TInterfacedObject, IIoCProbe)
  private
    FId: Integer;
  public
    class var Created: Integer;
    class var Destroyed: Integer;
    constructor Create; reintroduce;
    destructor Destroy; override;
    function Id: Integer;
  end;

  { 普通类直接实现接口：_AddRef/_Release 返回 -1（引用计数空操作），
    引用计数锚不存在，容器必须继续自己持有并释放对象。
    Delphi 不允许 TObject 后代省略 IInterface 三件套，所以这里手工实现。 }
  TIoCPlainProbe = class(TObject, IInterface, IIoCProbe)
  private
    FId: Integer;
  public
    class var Created: Integer;
    class var Destroyed: Integer;
    constructor Create; reintroduce;
    destructor Destroy; override;
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
    function Id: Integer;
  end;

  { 只放行自身 IID 的引用计数实现：QI 对 `Intf as TObject` 的对象转换查询返回
    E_NOINTERFACE，等价于 COM/代理/适配器交付给容器的实例——容器拿不到对象视图。
    TInterfacedObject 的 QueryInterface 是 protected 非虚方法，无法 override，
    所以这里按手写 IUnknown 的形态自己实现三件套。约束 3 的判据面。 }
  TIoCNoObjectViewProbe = class(TObject, IInterface, IIoCProbe)
  private
    FRef: Integer;
    FId: Integer;
  public
    class var Created: Integer;
    class var Destroyed: Integer;
    constructor Create; reintroduce;
    destructor Destroy; override;
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
    function Id: Integer;
  end;

  [TestFixture]
  TIoCSingletonIdentityTests = class
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure ObjectPathFirst_BothPathsShareOneInstance;

    [Test]
    procedure InterfacePathFirst_BothPathsShareOneInstance;

    [Test]
    procedure RegisteredInstance_ObjectPathReturnsSameInstance;

    [Test]
    procedure NamedSingletons_EachKeepsItsOwnSingleInstance;

    [Test]
    procedure InterfaceOnlyWithoutObjectView_ObjectPathRaisesTypedError;

    [Test]
    procedure InterfaceViewFromObjectSingleton_DoesNotSelfDestructInstance;

    [Test]
    procedure FactorySingleton_InterfacePathFirst_FactoryRunsOnce;

    [Test]
    procedure FactorySingleton_ObjectPathFirst_FactoryRunsOnce;

    [Test]
    procedure PlainClassSingleton_ContainerKeepsOwningAndFreesOnce;

    [Test]
    procedure ResolveAll_OnSingletonRegistration_AddsNoExtraInstance;
  end;

implementation

{ TIoCRefcountedProbe }

constructor TIoCRefcountedProbe.Create;
begin
  inherited Create;
  Inc(Created);
  FId := Created;
end;

destructor TIoCRefcountedProbe.Destroy;
begin
  Inc(Destroyed);
  inherited;
end;

function TIoCRefcountedProbe.Id: Integer;
begin
  Result := FId;
end;

{ TIoCPlainProbe }

constructor TIoCPlainProbe.Create;
begin
  inherited Create;
  Inc(Created);
  FId := Created;
end;

destructor TIoCPlainProbe.Destroy;
begin
  Inc(Destroyed);
  inherited;
end;

function TIoCPlainProbe.Id: Integer;
begin
  Result := FId;
end;

function TIoCPlainProbe.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  // 必须走 TObject.GetInterface：接口指针不等于对象指针（多接口类按 IOffset 偏移），
  // 手工写 Pointer(Obj) := Self 会让调用方拿到错位的 vtable，方法调用直接飞跳。
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

function TIoCPlainProbe._AddRef: Integer;
begin
  Result := -1;
end;

function TIoCPlainProbe._Release: Integer;
begin
  Result := -1;
end;

{ TIoCNoObjectViewProbe }

constructor TIoCNoObjectViewProbe.Create;
begin
  inherited Create;
  FRef := 0;
  Inc(Created);
  FId := Created;
end;

destructor TIoCNoObjectViewProbe.Destroy;
begin
  Inc(Destroyed);
  inherited;
end;

function TIoCNoObjectViewProbe.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  // 只放行自身接口；其余一律 E_NOINTERFACE —— 其中就包括 `Intf as TObject`
  // 走的对象转换查询，所以容器永远取不到该注册的对象视图。
  // 指针必须来自 TObject.GetInterface：多接口类的接口指针按 IOffset 偏移，
  // 不等于对象指针，手工写 Pointer(Obj) := Self 会让调用方拿到错位的 vtable。
  if IsEqualGUID(IID, IIoCProbe) and GetInterface(IID, Obj) then
    Exit(S_OK);
  Pointer(Obj) := nil;
  Result := E_NOINTERFACE;
end;

function TIoCNoObjectViewProbe._AddRef: Integer;
begin
  Inc(FRef);
  Result := FRef;
end;

function TIoCNoObjectViewProbe._Release: Integer;
begin
  Dec(FRef);
  Result := FRef;
  if Result = 0 then
    Free;
end;

function TIoCNoObjectViewProbe.Id: Integer;
begin
  Result := FId;
end;

{ TIoCSingletonIdentityTests }

procedure TIoCSingletonIdentityTests.Setup;
begin
  TIoCRefcountedProbe.Created := 0;
  TIoCRefcountedProbe.Destroyed := 0;
  TIoCPlainProbe.Created := 0;
  TIoCPlainProbe.Destroyed := 0;
  TIoCNoObjectViewProbe.Created := 0;
  TIoCNoObjectViewProbe.Destroyed := 0;
end;

procedure TIoCSingletonIdentityTests.ObjectPathFirst_BothPathsShareOneInstance;
var
  C: TIoCContainer;
  First, Second: TObject;
  View: IIoCProbe;
begin
  C := TIoCContainer.Create;
  try
    C.RegisterSingleton<IIoCProbe, TIoCRefcountedProbe>;
    First := C.Resolve(TypeInfo(IIoCProbe));
    View := C.Resolve<IIoCProbe>;
    Second := C.Resolve(TypeInfo(IIoCProbe));

    Assert.AreEqual(1, TIoCRefcountedProbe.Created,
      '一条单例注册、两种解析路径只能构造 1 个实例');
    Assert.AreSame(First, Second, '对象路径两次解析必须同一实例');
    Assert.AreEqual(TIoCRefcountedProbe(First).Id, View.Id,
      '对象路径与接口路径必须解析到同一实例');
    View := nil;
  finally
    C.Free;
  end;
  Assert.AreEqual(TIoCRefcountedProbe.Created, TIoCRefcountedProbe.Destroyed,
    '容器释放后不得遗留实例');
end;

procedure TIoCSingletonIdentityTests.InterfacePathFirst_BothPathsShareOneInstance;
var
  C: TIoCContainer;
  First, Second: TObject;
  View: IIoCProbe;
begin
  C := TIoCContainer.Create;
  try
    C.RegisterSingleton<IIoCProbe, TIoCRefcountedProbe>;
    View := C.Resolve<IIoCProbe>;
    First := C.Resolve(TypeInfo(IIoCProbe));
    Second := C.Resolve(TypeInfo(IIoCProbe));

    Assert.AreEqual(1, TIoCRefcountedProbe.Created,
      '接口先解析同样只能构造 1 个实例');
    Assert.AreSame(First, Second, '对象路径两次解析必须同一实例');
    Assert.AreEqual(TIoCRefcountedProbe(First).Id, View.Id,
      '接口路径先建立时对象路径必须复用该实例');
    View := nil;
  finally
    C.Free;
  end;
  Assert.AreEqual(TIoCRefcountedProbe.Created, TIoCRefcountedProbe.Destroyed,
    '容器释放后不得遗留实例');
end;

procedure TIoCSingletonIdentityTests.RegisteredInstance_ObjectPathReturnsSameInstance;
var
  C: TIoCContainer;
  Registered, View: IIoCProbe;
  Obj: TObject;
begin
  C := TIoCContainer.Create;
  try
    Registered := TIoCRefcountedProbe.Create;
    C.RegisterSingleton<IIoCProbe>(Registered);

    View := C.Resolve<IIoCProbe>;
    Assert.AreEqual(Registered.Id, View.Id, '接口路径必须返回登记的那个实例');

    Obj := C.Resolve(TypeInfo(IIoCProbe));
    Assert.AreEqual(1, TIoCRefcountedProbe.Created,
      '仅接口登记后，对象路径不得再构造新实例');
    Assert.AreEqual(Registered.Id, TIoCRefcountedProbe(Obj).Id,
      '仅接口登记的单例，对象路径要返回同一个对象而不是 AV');
    Assert.AreSame(Obj, C.Resolve(TypeInfo(IIoCProbe)),
      '对象路径第二次解析复用已缓存的对象视图');

    View := nil;
    Registered := nil;
  finally
    C.Free;
  end;
  Assert.AreEqual(TIoCRefcountedProbe.Created, TIoCRefcountedProbe.Destroyed,
    '容器释放后不得遗留登记实例');
end;

procedure TIoCSingletonIdentityTests.NamedSingletons_EachKeepsItsOwnSingleInstance;
var
  C: TIoCContainer;
  L0, L1, View: IIoCProbe;
  All: TArray<IIoCProbe>;
begin
  C := TIoCContainer.Create;
  try
    L0 := TIoCRefcountedProbe.Create;
    L1 := TIoCRefcountedProbe.Create;
    C.RegisterSingleton<IIoCProbe>(L0, 'L0');
    C.RegisterSingleton<IIoCProbe>(L1, 'L1');

    View := C.Resolve<IIoCProbe>('L0');
    Assert.AreEqual(L0.Id, View.Id, '具名单例 L0 必须返回登记的实例');
    View := C.Resolve<IIoCProbe>('L1');
    Assert.AreEqual(L1.Id, View.Id, '具名单例 L1 必须返回登记的实例');

    All := C.ResolveAll<IIoCProbe>;
    Assert.AreEqual<Integer>(2, Length(All), '具名单例注册各返回一项');
    Assert.AreEqual(2, TIoCRefcountedProbe.Created,
      '具名单例的解析不得另建实例（两条注册共用 ResolveAll 也仍是 2 个）');

    View := nil;
    All := nil;
    L0 := nil;
    L1 := nil;
  finally
    C.Free;
  end;
  Assert.AreEqual(TIoCRefcountedProbe.Created, TIoCRefcountedProbe.Destroyed,
    '容器释放后不得遗留具名单例');
end;

procedure TIoCSingletonIdentityTests.InterfaceOnlyWithoutObjectView_ObjectPathRaisesTypedError;
var
  C: TIoCContainer;
  LProbe: TProc;
  Registered: IIoCProbe;
begin
  C := TIoCContainer.Create;
  try
    Registered := TIoCNoObjectViewProbe.Create;
    C.RegisterSingleton<IIoCProbe>(Registered);

    LProbe := procedure
      begin
        C.Resolve(TypeInfo(IIoCProbe));
      end;
    Assert.WillRaise(LProbe, EIoCException,
      '只有接口视图的单例走对象路径必须抛 EIoCException，不允许 AV 或静默');

    Registered := nil;
  finally
    C.Free;
  end;
  Assert.AreEqual(TIoCNoObjectViewProbe.Created, TIoCNoObjectViewProbe.Destroyed,
    '抛异常的路径同样不得遗留实例');
end;

procedure TIoCSingletonIdentityTests.InterfaceViewFromObjectSingleton_DoesNotSelfDestructInstance;
var
  C: TIoCContainer;
  First, Second: TObject;
  View: IIoCProbe;
begin
  C := TIoCContainer.Create;
  try
    C.RegisterSingleton<IIoCProbe, TIoCRefcountedProbe>;
    First := C.Resolve(TypeInfo(IIoCProbe));
    Assert.AreEqual(0, TIoCRefcountedProbe.Destroyed,
      '对象路径建立的单例引用计数仍为 0，此时不该有任何析构');

    View := C.Resolve<IIoCProbe>;
    View := nil;

    Assert.AreEqual(0, TIoCRefcountedProbe.Destroyed,
      '接口视图建立并放手不得把 refcount-0 的单例打回 0（自毁后容器缓存指针悬垂）');

    Second := C.Resolve(TypeInfo(IIoCProbe));
    Assert.AreSame(First, Second, '接口视图建立后对象路径仍返回同一实例');
    Assert.AreEqual(1, TIoCRefcountedProbe(Second).Id,
      '实例必须还活着：读回属性即可暴露悬垂指针');
  finally
    C.Free;
  end;
  Assert.AreEqual(TIoCRefcountedProbe.Created, TIoCRefcountedProbe.Destroyed,
    '容器释放后不得遗留实例');
end;

procedure TIoCSingletonIdentityTests.FactorySingleton_InterfacePathFirst_FactoryRunsOnce;
var
  C: TIoCContainer;
  Calls: Integer;
  Factory: TServiceFactory<IIoCProbe>;
  Obj: TObject;
  View: IIoCProbe;
begin
  Calls := 0;
  C := TIoCContainer.Create;
  try
    Factory :=
      function: IIoCProbe
      begin
        Inc(Calls);
        Result := TIoCRefcountedProbe.Create;
      end;
    C.RegisterFactory<IIoCProbe>(Factory, slSingleton);

    View := C.Resolve<IIoCProbe>;
    Obj := C.Resolve(TypeInfo(IIoCProbe));

    Assert.AreEqual(1, Calls, '单例的接口工厂只能执行一次');
    Assert.AreEqual(1, TIoCRefcountedProbe.Created, '接口工厂单例只构造 1 个实例');
    Assert.AreEqual(TIoCRefcountedProbe(Obj).Id, View.Id,
      '对象路径必须复用接口工厂产物，而不是另建一个实例');
    View := nil;
  finally
    C.Free;
  end;
  Assert.AreEqual(TIoCRefcountedProbe.Created, TIoCRefcountedProbe.Destroyed,
    '容器释放后不得遗留工厂产物');
end;

procedure TIoCSingletonIdentityTests.FactorySingleton_ObjectPathFirst_FactoryRunsOnce;
var
  C: TIoCContainer;
  Calls: Integer;
  Factory: TServiceFactory<IIoCProbe>;
  First, Second: TObject;
begin
  Calls := 0;
  C := TIoCContainer.Create;
  try
    Factory :=
      function: IIoCProbe
      begin
        Inc(Calls);
        Result := TIoCRefcountedProbe.Create;
      end;
    C.RegisterFactory<IIoCProbe>(Factory, slSingleton);

    First := C.Resolve(TypeInfo(IIoCProbe));
    Second := C.Resolve(TypeInfo(IIoCProbe));

    Assert.AreEqual(1, Calls, '对象路径先解析时接口工厂同样只执行一次');
    Assert.AreEqual(1, TIoCRefcountedProbe.Created, '对象路径先解析只构造 1 个实例');
    Assert.AreSame(First, Second, '两次对象路径解析必须同一实例');
  finally
    C.Free;
  end;
  Assert.AreEqual(TIoCRefcountedProbe.Created, TIoCRefcountedProbe.Destroyed,
    '容器释放后不得遗留工厂产物');
end;

procedure TIoCSingletonIdentityTests.PlainClassSingleton_ContainerKeepsOwningAndFreesOnce;
var
  C: TIoCContainer;
  Obj: TObject;
  View: IIoCProbe;
begin
  C := TIoCContainer.Create;
  try
    C.RegisterSingleton<IIoCProbe, TIoCPlainProbe>;
    View := C.Resolve<IIoCProbe>;
    Obj := C.Resolve(TypeInfo(IIoCProbe));

    Assert.AreEqual(1, TIoCPlainProbe.Created, '非引用计数单例只构造 1 个实例');
    Assert.AreEqual(TIoCPlainProbe(Obj).Id, View.Id, '两条路径必须同一实例');

    View := nil;
    Assert.AreEqual(0, TIoCPlainProbe.Destroyed,
      '非引用计数实现的 _Release 是空操作，容器仍持有对象');
  finally
    C.Free;
  end;
  Assert.AreEqual(1, TIoCPlainProbe.Destroyed, '容器释放，且只释放一次');
end;

procedure TIoCSingletonIdentityTests.ResolveAll_OnSingletonRegistration_AddsNoExtraInstance;
var
  C: TIoCContainer;
  All: TArray<IIoCProbe>;
  Obj: TObject;
begin
  C := TIoCContainer.Create;
  try
    C.RegisterSingleton<IIoCProbe, TIoCRefcountedProbe>;
    All := C.ResolveAll<IIoCProbe>;
    Obj := C.Resolve(TypeInfo(IIoCProbe));

    Assert.AreEqual<Integer>(1, Length(All), 'ResolveAll 对单例注册只返回一项');
    Assert.AreEqual(1, TIoCRefcountedProbe.Created,
      'ResolveAll 不得为单例注册另建实例');
    Assert.AreEqual(TIoCRefcountedProbe(Obj).Id, All[0].Id,
      'ResolveAll 返回的接口必须指向容器单例');
    All := nil;
  finally
    C.Free;
  end;
  Assert.AreEqual(TIoCRefcountedProbe.Created, TIoCRefcountedProbe.Destroyed,
    '容器释放后不得遗留实例');
end;

initialization
  TDUnitX.RegisterTestFixture(TIoCSingletonIdentityTests);

end.
