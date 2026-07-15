unit DeepBase.Services.HealthCheck;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  /// <summary>å¥åº·æ£æ¥ç¶æ?/summary>
  THealthStatus = (hsHealthy, hsUnhealthy, hsDegraded, hsUnknown);

  /// <summary>å¥åº·æ£æ¥ç»æ?/summary>
  THealthCheckResult = record
    Status: THealthStatus;
    Description: string;
    Data: TDictionary<string, string>;
    Duration: Cardinal;
  end;

  /// <summary>å¥åº·æ£æ¥æ¥å?/summary>
  IHealthCheck = interface
    ['{A7D4C8B2-3E1F-4A5B-9C6D-2E8F7A1B4C5D}']
    function Check: THealthCheckResult;
    function GetName: string;
  end;

  /// <summary>å¥åº·æ£æ¥æå?/summary>
  IHealthCheckService = interface
    ['{C9E5F1A3-6B2D-4E8F-A1C7-5D9B3F7E2A4C}']
    procedure RegisterCheck(const Check: IHealthCheck);
    procedure UnregisterCheck(const Name: string);
    function CheckHealth: TDictionary<string, THealthCheckResult>;
    function GetOverallStatus: THealthStatus;
  end;

  /// <summary>å¥åº·æ£æ¥æå¡å®ç?/summary>
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
      CheckResult.Data := TDictionary<string, string>.Create;
      try
        CheckResult := Check.Check;
        if CheckResult.Data = nil then
          CheckResult.Data := TDictionary<string, string>.Create;
        CheckResult.Duration := MilliSecondsBetween(Now, StartTime);
      except
        on E: Exception do
        begin
          CheckResult.Status := hsUnhealthy;
          // BUG EXP-P1-008 FIX: do NOT echo `E.Message` to the external
          // caller — it may contain internal paths, connection strings or
          // SQL text. Surface only the exception class name (already safe:
          // it's a compile-time identifier) so operators still see *which*
          // check failed, without leaking implementation details. Internal
          // diagnostics should be obtained from the structured log sink.
          CheckResult.Description := Format('Check failed (%s)', [E.ClassName]);
          CheckResult.Duration := MilliSecondsBetween(Now, StartTime);
          if CheckResult.Data = nil then
            CheckResult.Data := TDictionary<string, string>.Create;
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
      // BIZ2-031 fix: each CheckResult owns its Data dictionary (created by
      // CheckHealth). Free it here since the record has no destructor to
      // clean it up automatically.
      FreeAndNil(CheckResult.Data);
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
