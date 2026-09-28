{ ============================================================================
  DeepBase.TimeSource - Core 的单一时钟源（带 last-seen 单调水位）

  为什么存在：许可与密钥的过期判定若直接取系统墙钟，把系统时间往回调就能让
  已到期的许可/密钥重新生效。本单元把"现在几点"收口到一处，并为每次读数推进
  last-seen 水位：EffectiveNow = Max(读数, 水位)，在本进程内时间只能向前走。

  - 读数可注入（TDeepBaseNowFunc），缺省为墙钟 Now；宿主与测试替换注入函数，
    不需要替换对象。
  - 水位可被外部推进（SeedWatermark，只升不降），用于把许可证里持久化的
    last-seen 载荷读回内存，防止删除或回滚许可文件把水位清零。
  - 回拨只登记、不续命：读数低于水位时返回水位值，并累计次数与最大幅度。

  跨进程的持久水位属于许可证存储（Features 侧）职责：Core 只规定"载荷里的
  last-seen 只能推进水位，不能降低水位"。
  ============================================================================ }

unit DeepBase.TimeSource;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.SyncObjs;

type
  /// <summary>时钟读数提供者；nil 表示回到系统墙钟。</summary>
  TDeepBaseNowFunc = reference to function: TDateTime;

  /// <summary>进程级唯一时钟源：读数单调、可注入、回拨可观测。</summary>
  TDeepBaseTimeSource = class
  strict private
    FLock: TCriticalSection;
    FNowFunc: TDeepBaseNowFunc;
    FLastSeen: TDateTime;
    FRollbackCount: Integer;
    FMaxRollbackSeconds: Int64;
    function GetLastSeen: TDateTime;
    function GetRollbackCount: Integer;
    function GetMaxRollbackSeconds: Int64;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>EffectiveNow：Max(注入读数, 水位)，并推进水位。</summary>
    function Now: TDateTime;

    /// <summary>注入读数来源；传 nil 恢复系统墙钟。</summary>
    procedure SetNowFunc(const ANowFunc: TDeepBaseNowFunc);

    /// <summary>用外部持久化的 last-seen 推进水位；只升不降。</summary>
    procedure SeedWatermark(const ALastSeen: TDateTime);

    /// <summary>清空注入函数、水位与回拨计数（测试与宿主的确定性起点）。</summary>
    procedure Reset;

    property LastSeen: TDateTime read GetLastSeen;
    property RollbackCount: Integer read GetRollbackCount;
    property MaxRollbackSeconds: Int64 read GetMaxRollbackSeconds;

    /// <summary>进程共享实例（单元 initialization 期建立，无惰性构造竞态）。</summary>
    class function Shared: TDeepBaseTimeSource; static;
  end;

implementation

var
  SharedTimeSource: TDeepBaseTimeSource;

{ TDeepBaseTimeSource }

constructor TDeepBaseTimeSource.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FNowFunc := nil;
  FLastSeen := 0;
  FRollbackCount := 0;
  FMaxRollbackSeconds := 0;
end;

destructor TDeepBaseTimeSource.Destroy;
begin
  FreeAndNil(FLock);
  inherited Destroy;
end;

function TDeepBaseTimeSource.GetLastSeen: TDateTime;
begin
  FLock.Enter;
  try
    Result := FLastSeen;
  finally
    FLock.Leave;
  end;
end;

function TDeepBaseTimeSource.GetRollbackCount: Integer;
begin
  FLock.Enter;
  try
    Result := FRollbackCount;
  finally
    FLock.Leave;
  end;
end;

function TDeepBaseTimeSource.GetMaxRollbackSeconds: Int64;
begin
  FLock.Enter;
  try
    Result := FMaxRollbackSeconds;
  finally
    FLock.Leave;
  end;
end;

function TDeepBaseTimeSource.Now: TDateTime;
var
  Reading: TDateTime;
  RollbackSeconds: Int64;
begin
  if Assigned(FNowFunc) then
    Reading := FNowFunc()
  else
    // 必须全限定：本单元的方法名同样是 Now，裸调用会自我递归
    Reading := System.SysUtils.Now;

  FLock.Enter;
  try
    if Reading < FLastSeen then
    begin
      // 回拨只登记不续命：返回水位值，过期判定因此继续成立
      Inc(FRollbackCount);
      RollbackSeconds := SecondsBetween(FLastSeen, Reading);
      if RollbackSeconds > FMaxRollbackSeconds then
        FMaxRollbackSeconds := RollbackSeconds;
      Result := FLastSeen;
    end
    else
    begin
      FLastSeen := Reading;
      Result := Reading;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TDeepBaseTimeSource.SetNowFunc(const ANowFunc: TDeepBaseNowFunc);
begin
  FLock.Enter;
  try
    FNowFunc := ANowFunc;
  finally
    FLock.Leave;
  end;
end;

procedure TDeepBaseTimeSource.SeedWatermark(const ALastSeen: TDateTime);
begin
  if ALastSeen <= 0 then
    Exit; // 0 = UnassignedDateTime，许可证里没有 last-seen 字段（历史载荷）

  FLock.Enter;
  try
    // 只升不降：载荷可被换成更早的旧副本，水位不能跟着倒退
    if ALastSeen > FLastSeen then
      FLastSeen := ALastSeen;
  finally
    FLock.Leave;
  end;
end;

procedure TDeepBaseTimeSource.Reset;
begin
  FLock.Enter;
  try
    FNowFunc := nil;
    FLastSeen := 0;
    FRollbackCount := 0;
    FMaxRollbackSeconds := 0;
  finally
    FLock.Leave;
  end;
end;

class function TDeepBaseTimeSource.Shared: TDeepBaseTimeSource;
begin
  Result := SharedTimeSource;
end;

initialization
  SharedTimeSource := TDeepBaseTimeSource.Create;

finalization
  FreeAndNil(SharedTimeSource);

end.
