unit Test.DeepBase.DeepFlow.RoleGuid;

(********************************************************************************
  Test.DeepBase.DeepFlow.RoleGuid - B2-12 回归

  被测面：DeepFlow.Role 中 12 个角色接口的 GUID。
  TInterfacedObject 只按 GUID 认领接口：旧定义里 ILogistics 与 IEngine 同为 {...0010}、
  IChronicler 与 IInspector 同为 {...0011}，于是"同时实现两个 L1 接口"的对象会被
  Supports/as 当成 L0 角色用，编译期与运行期都不报错。
  所以这里除了断言 12 个 GUID 两两不同，还要把类型混淆的现场本身钉住：桩对象必须支持
  自己的两个接口（正向对照，证明用例不是恒真），且必须不支持被冒用的那两个 L0 接口
  （判别用例，旧代码下必红）。
*******************************************************************************)

interface

uses
  System.SysUtils, System.TypInfo, System.JSON,
  DUnitX.TestFramework,
  DeepFlow.Message, DeepFlow.Role;

type
  /// <summary>一次采集、多个用例共用：接口名 + 其 GUID 的规范字符串形态。</summary>
  TGuidEntry = record
    Name: string;
    GuidText: string;
  end;

  /// <summary>只为钉住"一个对象同时承担两个 L1 角色"的形状，无业务语义。</summary>
  TFoundationRoleStub = class(TDeepFlowRoleBase, ILogistics, IChronicler)
  private
    procedure Put(const ANamespace, AKey: string; const AValue: TJSONValue);
    function Get(const ANamespace, AKey: string): TJSONValue;
    procedure Delete(const ANamespace, AKey: string);
    procedure Log(const ALevel, AComponent, AMessage: string;
      const ADetails: TJSONObject = nil);
    procedure AuditLog(const AEvent: TJSONObject);
    function QueryLogs(const AFilter: TJSONObject): TJSONArray;
  protected
    procedure DoInitialize; override;
    procedure DoStart; override;
    procedure DoStop; override;
    function DoHandleMessage(const AMessage: TDeepFlowMessage): TDeepFlowMessage; override;
  end;

  [TestFixture]
  TTestDeepFlowRoleGuid = class
  private
    FGuids: array[0..11] of TGuidEntry;
  public
    [Setup]
    procedure SetUp;

    [Test]
    procedure Test_All_Role_Interface_GUIDs_Are_Unique;
    [Test]
    procedure Test_All_Role_Interface_GUIDs_Share_Family_Prefix;
    [Test]
    procedure Test_Stub_Supports_Own_Role_Interfaces;
    [Test]
    procedure Test_Stub_Not_Supports_L0_Role_Interfaces;
  end;

implementation

const
  // GUID 族前缀：末字节才是各接口自己的编号，前四段全族共用
  FAMILY_PREFIX = '{A1B2C3D4-0001-0000-0000-';

function GuidEntry(const AName: string; ATypeInfo: PTypeInfo): TGuidEntry;
begin
  Result.Name := AName;
  Result.GuidText := GuidToString(GetTypeData(ATypeInfo)^.Guid);
end;

function StubMetaInfo: TRoleMetaInfo;
begin
  Result.Name := 'FoundationStub';
  Result.DisplayName := 'L1 角色桩';
  Result.Level := rlFoundation;
  Result.TrustLevel := tlFullTrust;
  Result.Description := '仅用于 B2-12 GUID 回归';
  Result.Version := '1.0';
end;

{ TFoundationRoleStub }

procedure TFoundationRoleStub.Put(const ANamespace, AKey: string; const AValue: TJSONValue);
begin
end;

function TFoundationRoleStub.Get(const ANamespace, AKey: string): TJSONValue;
begin
  Result := nil;
end;

procedure TFoundationRoleStub.Delete(const ANamespace, AKey: string);
begin
end;

procedure TFoundationRoleStub.Log(const ALevel, AComponent, AMessage: string;
  const ADetails: TJSONObject);
begin
end;

procedure TFoundationRoleStub.AuditLog(const AEvent: TJSONObject);
begin
end;

function TFoundationRoleStub.QueryLogs(const AFilter: TJSONObject): TJSONArray;
begin
  Result := nil;
end;

procedure TFoundationRoleStub.DoInitialize;
begin
  SetState(rsReady);
end;

procedure TFoundationRoleStub.DoStart;
begin
  SetState(rsRunning);
end;

procedure TFoundationRoleStub.DoStop;
begin
  SetState(rsStopped);
end;

function TFoundationRoleStub.DoHandleMessage(const AMessage: TDeepFlowMessage): TDeepFlowMessage;
begin
  Result := nil;
end;

{ TTestDeepFlowRoleGuid }

procedure TTestDeepFlowRoleGuid.SetUp;
begin
  FGuids[0] := GuidEntry('IDeepFlowRole', TypeInfo(IDeepFlowRole));
  FGuids[1] := GuidEntry('IEngine', TypeInfo(IEngine));
  FGuids[2] := GuidEntry('IInspector', TypeInfo(IInspector));
  FGuids[3] := GuidEntry('ICommander', TypeInfo(ICommander));
  FGuids[4] := GuidEntry('IDispatcher', TypeInfo(IDispatcher));
  FGuids[5] := GuidEntry('IAdvisor', TypeInfo(IAdvisor));
  FGuids[6] := GuidEntry('IExecutor', TypeInfo(IExecutor));
  FGuids[7] := GuidEntry('IGuard', TypeInfo(IGuard));
  FGuids[8] := GuidEntry('IQuartermaster', TypeInfo(IQuartermaster));
  FGuids[9] := GuidEntry('ILogistics', TypeInfo(ILogistics));
  FGuids[10] := GuidEntry('IChronicler', TypeInfo(IChronicler));
  FGuids[11] := GuidEntry('ISignalOfficer', TypeInfo(ISignalOfficer));
end;

procedure TTestDeepFlowRoleGuid.Test_All_Role_Interface_GUIDs_Are_Unique;
var
  I, J: Integer;
begin
  for I := Low(FGuids) to High(FGuids) - 1 do
    for J := I + 1 to High(FGuids) do
      Assert.AreNotEqual(FGuids[I].GuidText, FGuids[J].GuidText,
        Format('接口 %s 与 %s 共用 GUID %s；QueryInterface 只按 GUID 认人，'
          + '两个语义不同的角色会被当成同一个用',
          [FGuids[I].Name, FGuids[J].Name, FGuids[I].GuidText]));
end;

procedure TTestDeepFlowRoleGuid.Test_All_Role_Interface_GUIDs_Share_Family_Prefix;
var
  I: Integer;
begin
  // 防的是"顺手粘一个外来 GUID"：族前缀漂了，唯一性还在但编号规则已失守
  for I := Low(FGuids) to High(FGuids) do
    Assert.AreEqual(FAMILY_PREFIX, Copy(FGuids[I].GuidText, 1, Length(FAMILY_PREFIX)),
      Format('接口 %s 的 GUID %s 不在 DeepFlow 角色族前缀内',
        [FGuids[I].Name, FGuids[I].GuidText]));
end;

procedure TTestDeepFlowRoleGuid.Test_Stub_Supports_Own_Role_Interfaces;
var
  Role: IInterface;
  Logistics: ILogistics;
  Chronicler: IChronicler;
begin
  Role := TFoundationRoleStub.Create(StubMetaInfo);
  Assert.IsTrue(Supports(Role, ILogistics, Logistics),
    '桩对象声明了 ILogistics 却拿不到该接口，正向对照失效');
  Assert.IsTrue(Supports(Role, IChronicler, Chronicler),
    '桩对象声明了 IChronicler 却拿不到该接口，正向对照失效');
end;

procedure TTestDeepFlowRoleGuid.Test_Stub_Not_Supports_L0_Role_Interfaces;
var
  Role: IInterface;
begin
  Role := TFoundationRoleStub.Create(StubMetaInfo);
  // 旧定义下这两条都判不出"不支持"：L0 的 GUID 正是被 L1 借走的那两个值
  Assert.IsFalse(Supports(Role, IEngine),
    'L1 角色桩被当成 IEngine（元层引擎）——GUID 撞车即类型混淆');
  Assert.IsFalse(Supports(Role, IInspector),
    'L1 角色桩被当成 IInspector（元层督察）——GUID 撞车即类型混淆');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDeepFlowRoleGuid);

end.
