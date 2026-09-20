{*****************************************************************************
  DeepBase.HB.Lifecycle - Shared lifecycle phase guard (VCL/FMX SSOT)

  Phase transitions + Paint precondition live here so VCL and FMX do not fork.
***************************************************************************** }

unit DeepBase.HB.Lifecycle;

interface

uses
  System.SysUtils,
  System.DateUtils,
  DeepBase.HB.Runtime,
  DeepBase.HB.Touchpoint.Types,
  DeepBase.HB.Touchpoint.Engine;

type
  THbLifecycleErrorProc = reference to procedure(const AStep: string; AException: Exception);

  /// <summary>UI-agnostic lifecycle state owned by VCL/FMX base controls.</summary>
  THbLifecycleState = record
    Phase: THbLifecyclePhase;
    IsDisposed: Boolean;
    TouchpointId: string;
    SurfaceId: string;
    TargetState: string;
    procedure ResetCreated;
    procedure BindToken;
    procedure BindState;
    procedure AttachTouchpoint(const ATouchpoint: IHbTouchpoint;
      const ASurfaceId: string);
    procedure AssertPaintAllowed(const AControlClassName: string);
    procedure MarkRendered;
    procedure EmitTelemetry(const ATouchpoint: IHbTouchpoint;
      const ADefaultActionType: string = 'Render');
    procedure HandleError(const AHandler: THbLifecycleErrorProc;
      const AStep: string; AException: Exception);
    procedure Dispose;
  end;

implementation

procedure THbLifecycleState.ResetCreated;
begin
  Phase := lpCreated;
  IsDisposed := False;
  TouchpointId := '';
  SurfaceId := '';
  TargetState := '';
end;

procedure THbLifecycleState.BindToken;
begin
  Phase := lpTokenBound;
end;

procedure THbLifecycleState.BindState;
begin
  Phase := lpStateBound;
end;

procedure THbLifecycleState.AttachTouchpoint(const ATouchpoint: IHbTouchpoint;
  const ASurfaceId: string);
begin
  if ATouchpoint = nil then
    Exit;
  TouchpointId := ATouchpoint.GetID;
  TargetState := ATouchpoint.GetAfterState;
  if ASurfaceId <> '' then
    SurfaceId := ASurfaceId;
  THbTouchpointEngine.Instance.RegisterTouchpoint(
    TouchpointId,
    ATouchpoint.GetLevel,
    SurfaceId,
    TargetState);
  Phase := lpTouchpointAttached;
end;

procedure THbLifecycleState.AssertPaintAllowed(const AControlClassName: string);
begin
  if Phase < lpTokenBound then
    raise EHbLifecycleViolation.Create(AControlClassName, Phase);
end;

procedure THbLifecycleState.MarkRendered;
begin
  if Phase < lpRendered then
    Phase := lpRendered;
end;

procedure THbLifecycleState.EmitTelemetry(const ATouchpoint: IHbTouchpoint;
  const ADefaultActionType: string);
var
  Ev: TTouchEvidence;
begin
  if (ATouchpoint = nil) and (TouchpointId = '') then
    Exit;

  if ATouchpoint <> nil then
  begin
    Ev := ATouchpoint.EmitEvidence;
    if Ev.TouchpointId = '' then
      Ev.TouchpointId := ATouchpoint.GetID;
    if (Ev.SurfaceId = '') and (SurfaceId <> '') then
      Ev.SurfaceId := SurfaceId;
  end
  else
  begin
    FillChar(Ev, SizeOf(Ev), 0);
    Ev.TouchpointId := TouchpointId;
    Ev.SurfaceId := SurfaceId;
  end;
  if Ev.TimestampUtc <= 0 then
    Ev.TimestampUtc := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000;
  if Ev.ActionType = '' then
    Ev.ActionType := ADefaultActionType;
  Ev.Success := True;
  THbTouchpointEngine.Instance.EmitEvidence(Ev);
end;

procedure THbLifecycleState.HandleError(const AHandler: THbLifecycleErrorProc;
  const AStep: string; AException: Exception);
begin
  try
    if Assigned(AHandler) then
      AHandler(AStep, AException);
  finally
    Dispose;
  end;
end;

procedure THbLifecycleState.Dispose;
begin
  if IsDisposed then
    Exit;
  IsDisposed := True;
  Phase := lpDisposed;
  TouchpointId := '';
  TargetState := '';
end;

end.
