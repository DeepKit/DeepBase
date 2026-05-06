unit UniBase.Services.HealthCheck;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  /// <summary>健康检查状态</summary>
  THealthStatus = (hsHealthy, hsUnhealthy, hsDegraded, hsUnknown);

  /// <summary>健康检查结果</summary>
  THealthCheckResult = record
    Status: THealthStatus;
    Description: string;
    Data: TDictionary<string, string>;
    Duration: Cardinal;
  end;

  /// <summary>健康检查接口</summary>
  IHealthCheck = interface
    ['{A7D4C8B2-3E1F-4A5B-9C6D-2E8F7A1B4C5D}']
    function Check: THealthCheckResult;
    function GetName: string;
  end;

  /// <summary>健康检查服务</summary>
  IHealthCheckService = interface
    ['{C9E5F1A3-6B2D-4E8F-A1C7-5D9B3F7E2A4C}']
    procedure RegisterCheck(const Check: IHealthCheck);
    procedure UnregisterCheck(const Name: string);
    function CheckHealth: TDictionary<string, THealthCheckResult>;
    function GetOverallStatus: THealthStatus;
  end;

  /// <summary>健康检查服务实现</summary>
  THealthCheckService = class(TInterfacedObject, IHealthCheckService)
  private
    FChecks: TDictionary<string, IHealthCheck>;
    FLock: TObject;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterCheck(const Check: IHealthCheck);
    procedure UnregisterCheck(const Name: string);
    function CheckHealth: TDictionary<string, THealthCheckResult>;
    function GetOverallStatus: THealthStatus;
  end;

implementation

uses
  System.SyncObjs, System.DateUtils;

{ THealthCheckService }

constructor THealthCheckService.Create;
begin
  inherited;
  FChecks := TDictionary<string, IHealthCheck>.Create;
  FLock := TObject.Create;
end;

destructor THealthCheckService.Destroy;
begin
  FreeAndNil(FChecks);
  FreeAndNil(FLock);
  inherited;
end;

procedure THealthCheckService.RegisterCheck(const Check: IHealthCheck);
begin
  TMonitor.Enter(FLock);
  try
    FChecks.AddOrSetValue(Check.GetName, Check);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure THealthCheckService.UnregisterCheck(const Name: string);
begin
  TMonitor.Enter(FLock);
  try
    FChecks.Remove(Name);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function THealthCheckService.CheckHealth: TDictionary<string, THealthCheckResult>;
var
  Check: IHealthCheck;
  Name: string;
  StartTime: TDateTime;
  CheckResult: THealthCheckResult;
begin
  Result := TDictionary<string, THealthCheckResult>.Create;
  
  TMonitor.Enter(FLock);
  try
    for Name in FChecks.Keys do
    begin
      Check := FChecks[Name];
      StartTime := Now;
      try
        CheckResult := Check.Check;
        CheckResult.Duration := MilliSecondsBetween(Now, StartTime);
      except
        on E: Exception do
        begin
          CheckResult.Status := hsUnhealthy;
          CheckResult.Description := E.Message;
          CheckResult.Duration := MilliSecondsBetween(Now, StartTime);
        end;
      end;
      Result.AddOrSetValue(Name, CheckResult);
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function THealthCheckService.GetOverallStatus: THealthStatus;
var
  Results: TDictionary<string, THealthCheckResult>;
  CheckResult: THealthCheckResult;
  HasUnhealthy, HasDegraded: Boolean;
begin
  Results := CheckHealth;
  try
    HasUnhealthy := False;
    HasDegraded := False;
    
    for CheckResult in Results.Values do
    begin
      case CheckResult.Status of
        hsUnhealthy: HasUnhealthy := True;
        hsDegraded: HasDegraded := True;
      end;
    end;
    
    if HasUnhealthy then
      Result := hsUnhealthy
    else if HasDegraded then
      Result := hsDegraded
    else
      Result := hsHealthy;
  finally
    Results.Free;
  end;
end;

end.
