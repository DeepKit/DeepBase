{ ============================================================================
  Test.Regression.CR20260824_OwnerDecisions - Owner 决策落地回归 (2026-08-24)

  Covers:
  - CR-294(决策B): TRateLimitManager 遇未知限额名默认拒绝(fail-closed)，
    显式 FailOpenOnUnknownLimit=True 才放行。
  - CR-281b(决策A): TLogFilter.WithLevel 链式调用改追加语义(带去重)。
  - 决策3: JSON 序列化根对象无可序列化属性时抛 ESerializationException
    并提示添加 Serialize 特性或启用 M+ 编译指令(普通 public 类此前静默
    输出空对象)。
  ============================================================================ }

unit Test.Regression.CR20260824_OwnerDecisions;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.Types,
  DeepBase.LogAggregator,
  DeepBase.RateLimiter,
  DeepBase.Serialization;

type
  // 无任何序列化标注的普通类 —— 决策3 的目标场景
  TPlainDto = class
  private
    FName: string;
  public
    property Name: string read FName write FName;
  end;

  [TestFixture]
  [Category('regression')]
  TOwnerDecisionsTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    procedure Test_CR294_UnknownLimit_DefaultDeny;

    [Test]
    procedure Test_CR294_FailOpenOptIn_Allows;

    [Test]
    procedure Test_CR281b_WhereLevel_AppendsNotOverwrites;

    [Test]
    procedure Test_Decision3_PlainDtoRoot_SerializeRaisesWithGuidance;
  end;

implementation

{ TOwnerDecisionsTest }

function TOwnerDecisionsTest.GetBugNumber: string;
begin
  Result := 'CR-294/CR-281b/Decision3';
end;

function TOwnerDecisionsTest.GetBugDescription: string;
begin
  Result := 'Owner decisions: fail-closed unknown limits / WithLevel append / serialization empty-root fast-fail';
end;

function TOwnerDecisionsTest.GetFixDate: string;
begin
  Result := '2026-08-24';
end;

function TOwnerDecisionsTest.GetPriority: string;
begin
  Result := 'P2';
end;

function TOwnerDecisionsTest.GetAffectedFile: string;
begin
  Result := 'Core\DeepBase.RateLimiter.pas; Core\DeepBase.LogAggregator.pas; Core\DeepBase.Serialization.pas';
end;

procedure TOwnerDecisionsTest.Test_CR294_UnknownLimit_DefaultDeny;
var
  Mgr: TRateLimitManager;
begin
  Mgr := TRateLimitManager.Create;
  try
    Assert.IsFalse(Mgr.HasLimit('typo_name'));

    // 决策B 默认 fail-closed：未知限额一律拒绝
    Assert.IsFalse(Mgr.Check('typo_name'), 'unknown limit must DENY by default');

    var R := Mgr.Acquire('typo_name');
    Assert.IsFalse(R.Allowed, 'unknown limit Acquire must deny');
    Assert.IsTrue(R.RetryAfterMs > 0,
      'deny must carry non-zero retry window to avoid busy-wait');
  finally
    Mgr.Free;
  end;
end;

procedure TOwnerDecisionsTest.Test_CR294_FailOpenOptIn_Allows;
var
  Mgr: TRateLimitManager;
begin
  Mgr := TRateLimitManager.Create;
  try
    Mgr.FailOpenOnUnknownLimit := True; // 非关键路径显式选择旧行为
    Assert.IsTrue(Mgr.Check('typo_name'),
      'explicit fail-open must allow unknown limits');
  finally
    Mgr.Free;
  end;
end;

procedure TOwnerDecisionsTest.Test_CR281b_WhereLevel_AppendsNotOverwrites;
var
  F1, F2, F3: TLogFilter;
begin
  F1 := Default(TLogFilter);
  F1 := F1.WithLevel(llWarn);
  F2 := F1.WithLevel(llError);
  F3 := F2.WithLevel(llWarn); // 去重

  Assert.AreEqual<Integer>(2, Length(F2.Levels), 'append semantics expected');
  Assert.IsTrue((F2.Levels[0] = llWarn) and (F2.Levels[1] = llError),
    'order preserved');
  Assert.AreEqual(Length(F2.Levels), Length(F3.Levels), 'duplicate level deduped');
end;

procedure TOwnerDecisionsTest.Test_Decision3_PlainDtoRoot_SerializeRaisesWithGuidance;
var
  LProc: TProc;
begin
  LProc := procedure
  var
    Dto: TPlainDto;
    S: string;
  begin
    Dto := TPlainDto.Create;
    try
      Dto.Name := 'silent-loss';
      S := TSerializer.ToJson(Dto); // pre-fix: "{}" silently
    finally
      Dto.Free;
    end;
  end;
  Assert.WillRaise(LProc, ESerializationException);
end;

initialization
  TDUnitX.RegisterTestFixture(TOwnerDecisionsTest);

end.
