{ ============================================================================
  DeepBase.Inference.Service
  ---------------------------------------------------------------------------
  Description : Static facade for the Inference framework.
                Provides global access to runtime and session factory.
                Follows TBrowserService pattern.
  ============================================================================ }

unit DeepBase.Inference.Service;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  DeepBase.Inference.Types;

type
  TInferenceService = class
  private
    class var FRuntime: IInferenceRuntime;
    class var FSessionFactory: IInferenceSessionFactory;
    class var FLock: TCriticalSection;
  public
    class constructor Create;
    class destructor Destroy;

    class procedure SetRuntime(const ARuntime: IInferenceRuntime);
    class procedure SetSessionFactory(
      const AFactory: IInferenceSessionFactory);
    class procedure Shutdown;

    class function Runtime: IInferenceRuntime;
    class function SessionFactory: IInferenceSessionFactory;
    class function IsReady: Boolean;

    class function CreateSession(
      const AModelPath: string): IInferenceSession; overload;
    class function CreateSession(
      const AModelData: TBytes): IInferenceSession; overload;

    class function Run(ASession: IInferenceSession;
      const AInputNames: TArray<string>;
      const AInputValues: TArray<TBytes>;
      const AInputShapes: TArray<TArray<Int64>>): TInferenceOutput;
  end;

implementation

uses
  DeepBase.Logging;

{ --- TInferenceService -------------------------------------------------- }

class constructor TInferenceService.Create;
begin
  FLock := TCriticalSection.Create;
end;

class destructor TInferenceService.Destroy;
begin
  Shutdown;
  FreeAndNil(FLock);
end;

class procedure TInferenceService.SetRuntime(
  const ARuntime: IInferenceRuntime);
begin
  FLock.Enter;
  try
    FRuntime := ARuntime;
  finally
    FLock.Leave;
  end;
end;

class procedure TInferenceService.SetSessionFactory(
  const AFactory: IInferenceSessionFactory);
begin
  FLock.Enter;
  try
    FSessionFactory := AFactory;
  finally
    FLock.Leave;
  end;
end;

class procedure TInferenceService.Shutdown;
begin
  FLock.Enter;
  try
    FSessionFactory := nil;
    FRuntime := nil;
  finally
    FLock.Leave;
  end;
end;

class function TInferenceService.Runtime: IInferenceRuntime;
begin
  FLock.Enter;
  try
    Result := FRuntime;
  finally
    FLock.Leave;
  end;
end;

class function TInferenceService.SessionFactory: IInferenceSessionFactory;
begin
  FLock.Enter;
  try
    Result := FSessionFactory;
  finally
    FLock.Leave;
  end;
end;

class function TInferenceService.IsReady: Boolean;
begin
  FLock.Enter;
  try
    Result := (FSessionFactory <> nil);
  finally
    FLock.Leave;
  end;
end;

class function TInferenceService.CreateSession(
  const AModelPath: string): IInferenceSession;
begin
  FLock.Enter;
  try
    if FSessionFactory = nil then
      raise EInferenceError.Create(
        'Inference service is not initialized. Call SetSessionFactory first.');
    Result := FSessionFactory.CreateSession(AModelPath);
  finally
    FLock.Leave;
  end;
end;

class function TInferenceService.CreateSession(
  const AModelData: TBytes): IInferenceSession;
begin
  FLock.Enter;
  try
    if FSessionFactory = nil then
      raise EInferenceError.Create(
        'Inference service is not initialized. Call SetSessionFactory first.');
    Result := FSessionFactory.CreateSession(AModelData);
  finally
    FLock.Leave;
  end;
end;

class function TInferenceService.Run(ASession: IInferenceSession;
  const AInputNames: TArray<string>;
  const AInputValues: TArray<TBytes>;
  const AInputShapes: TArray<TArray<Int64>>): TInferenceOutput;
begin
  if ASession = nil then
    Exit(TInferenceOutput.Failed('Session is nil'));
  Result := ASession.Run(AInputNames, AInputValues, AInputShapes);
end;

end.
