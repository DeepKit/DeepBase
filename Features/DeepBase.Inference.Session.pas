{ ============================================================================
  DeepBase.Inference.Session
  ---------------------------------------------------------------------------
  Description : Session management for ONNX model inference. Wraps
                TORTSession lifecycle -- model loading, inference execution,
                and disposal.
  ============================================================================ }

unit DeepBase.Inference.Session;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  DeepBase.Inference.Types;

type
  TInferenceSessionFactory = class(TInterfacedObject, IInferenceSessionFactory)
  private
    FRuntime: IInferenceRuntime;
  public
    constructor Create(const ARuntime: IInferenceRuntime);
    function CreateSession(const AModelPath: string): IInferenceSession; overload;
    function CreateSession(const AModelData: TBytes): IInferenceSession; overload;
  end;

  TInferenceSession = class(TInterfacedObject, IInferenceSession)
  private
    FSessionId: string;
    FState: TInferenceSessionState;
    FModelInfo: TInferenceModelInfo;
    FRuntime: IInferenceRuntime;
    FOrtSession: Pointer; // heap-allocated ^TORTSession; typed in impl
    procedure ExtractModelInfo;
    procedure ReleaseOrtSession;
  public
    constructor CreateFromPath(const ARuntime: IInferenceRuntime;
      const AModelPath: string);
    constructor CreateFromBytes(const ARuntime: IInferenceRuntime;
      const AModelData: TBytes);
    destructor Destroy; override;

    { IInferenceSession }
    function GetSessionId: string;
    function GetState: TInferenceSessionState;
    function GetModelInfo: TInferenceModelInfo;
    function Run(const AInputNames: TArray<string>;
      const AInputValues: TArray<TBytes>;
      const AInputShapes: TArray<TArray<Int64>>): TInferenceOutput;
    procedure Dispose;
  end;

implementation

uses
  System.Diagnostics,
  onnxruntime,
  onnxruntime_pas_api,
  DeepBase.Logging;

type
  TORTSessionPtr = ^TORTSession;

var
  GSessionCounter: Integer = 0;

function NewSessionId: string;
begin
  Result := 'ONNX-' + IntToStr(TInterlocked.Increment(GSessionCounter));
end;

{ --- TInferenceSessionFactory -------------------------------------------- }

constructor TInferenceSessionFactory.Create(
  const ARuntime: IInferenceRuntime);
begin
  inherited Create;
  if ARuntime = nil then
    raise EArgumentNilException.Create('ARuntime cannot be nil');
  FRuntime := ARuntime;
end;

function TInferenceSessionFactory.CreateSession(
  const AModelPath: string): IInferenceSession;
begin
  Result := TInferenceSession.CreateFromPath(FRuntime, AModelPath);
end;

function TInferenceSessionFactory.CreateSession(
  const AModelData: TBytes): IInferenceSession;
begin
  Result := TInferenceSession.CreateFromBytes(FRuntime, AModelData);
end;

{ --- TInferenceSession -------------------------------------------------- }

constructor TInferenceSession.CreateFromPath(
  const ARuntime: IInferenceRuntime; const AModelPath: string);
var
  LSession: TORTSession;
begin
  inherited Create;
  if ARuntime = nil then
    raise EArgumentNilException.Create('ARuntime cannot be nil');
  if not FileExists(AModelPath) then
    raise EInferenceModelError.CreateFmt('Model file not found: %s', [AModelPath]);

  FRuntime := ARuntime;
  FSessionId := NewSessionId;
  FState := issUninitialized;
  FOrtSession := nil;

  try
    LSession := TORTSession.Create(AModelPath);
    New(FOrtSession);
    TORTSessionPtr(FOrtSession)^ := LSession;

    ExtractModelInfo;
    FState := issReady;

    Logger.InfoFmt(
      'Inference.Session: loaded from file (%s, %d inputs, %d outputs)',
      [AModelPath, FModelInfo.InputCount, FModelInfo.OutputCount],
      'Inference');
  except
    on E: Exception do
    begin
      FState := issUninitialized;
      raise EInferenceModelError.CreateFmt(
        'Failed to load model from file: %s (%s)', [AModelPath, E.Message]);
    end;
  end;
end;

constructor TInferenceSession.CreateFromBytes(
  const ARuntime: IInferenceRuntime; const AModelData: TBytes);
var
  LSession: TORTSession;
begin
  inherited Create;
  if ARuntime = nil then
    raise EArgumentNilException.Create('ARuntime cannot be nil');
  if Length(AModelData) = 0 then
    raise EInferenceModelError.Create('Model data is empty');

  FRuntime := ARuntime;
  FSessionId := NewSessionId;
  FState := issUninitialized;
  FOrtSession := nil;

  try
    LSession := TORTSession.Create(
      DefaultEnv, @AModelData[0], Length(AModelData), DefaultSessionOptions);
    New(FOrtSession);
    TORTSessionPtr(FOrtSession)^ := LSession;

    ExtractModelInfo;
    FState := issReady;

    Logger.InfoFmt(
      'Inference.Session: loaded from memory (%d bytes, %d inputs, %d outputs)',
      [Length(AModelData), FModelInfo.InputCount, FModelInfo.OutputCount],
      'Inference');
  except
    on E: Exception do
    begin
      FState := issUninitialized;
      raise EInferenceModelError.CreateFmt(
        'Failed to load model from memory: %s', [E.Message]);
    end;
  end;
end;

destructor TInferenceSession.Destroy;
begin
  ReleaseOrtSession;
  FState := issDisposed;
  inherited;
end;

procedure TInferenceSession.ReleaseOrtSession;
begin
  if FOrtSession <> nil then
  begin
    var P: TORTSessionPtr := TORTSessionPtr(FOrtSession);
    // TORTSession is a managed record. Finalize it before freeing memory
    // so the smart-pointer housekeeper decrements the ORT refcount.
    Finalize(P^);
    System.Dispose(P);
    FOrtSession := nil;
  end;
end;

function TInferenceSession.GetSessionId: string;
begin
  Result := FSessionId;
end;

function TInferenceSession.GetState: TInferenceSessionState;
begin
  Result := FState;
end;

function TInferenceSession.GetModelInfo: TInferenceModelInfo;
begin
  Result := FModelInfo;
end;

procedure TInferenceSession.ExtractModelInfo;
var
  LMeta: TORTModelMetadata;
begin
  FModelInfo := TInferenceModelInfo.Empty;

  FModelInfo.InputCount :=
    Integer(TORTSessionPtr(FOrtSession)^.GetInputCount);
  FModelInfo.OutputCount :=
    Integer(TORTSessionPtr(FOrtSession)^.GetOutputCount);

  LMeta := TORTSessionPtr(FOrtSession)^.GetModelMetadata;
  try
    FModelInfo.ProducerName := string(AnsiString(
      LMeta.GetProducerNameAllocated(DefaultAllocator).Instance));
    FModelInfo.GraphName := string(AnsiString(
      LMeta.GetGraphNameAllocated(DefaultAllocator).Instance));
    FModelInfo.Description := string(AnsiString(
      LMeta.GetDescriptionAllocated(DefaultAllocator).Instance));
  except
    // metadata extraction is non-critical
  end;
end;

function TInferenceSession.Run(const AInputNames: TArray<string>;
  const AInputValues: TArray<TBytes>;
  const AInputShapes: TArray<TArray<Int64>>): TInferenceOutput;
var
  LInputs, LOutputs: TORTNameValueList;
  LSW: TStopwatch;
  LNames: TArray<string>;
  i: Integer;
  LFloatData: TArray<Single>;
  LShape: TArray<Int64>;
  LRevShape: TArray<Int64>;
  LValue: TORTValue;
  LElementCount: size_t;
  j: Integer;
begin
  if FState <> issReady then
    Exit(TInferenceOutput.Failed('Session is not ready'));

  if Length(AInputNames) <> Length(AInputValues) then
    Exit(TInferenceOutput.Failed('InputNames and InputValues length mismatch'));
  if Length(AInputNames) <> Length(AInputShapes) then
    Exit(TInferenceOutput.Failed('InputNames and InputShapes length mismatch'));

  try
    LInputs := Default(TORTNameValueList);

    for i := 0 to High(AInputNames) do
    begin
      LShape := AInputShapes[i];

      if Length(AInputValues[i]) = 0 then
        raise EInferenceSessionError.CreateFmt(
          'Empty input data for "%s"', [AInputNames[i]]);

      // Convert raw bytes to TArray<Single> for CreateTensor<T>
      LElementCount := Length(AInputValues[i]) div SizeOf(Single);
      SetLength(LFloatData, LElementCount);
      Move(AInputValues[i][0], LFloatData[0], LElementCount * SizeOf(Single));

      // TORTValue.CreateTensor<T> expects shape in reverse (row-major) order
      // matching the TOrtTensor<T>.ToValue pattern
      LRevShape := Copy(LShape);
      for j := 0 to High(LRevShape) div 2 do
      begin
        var LTemp: Int64 := LRevShape[j];
        LRevShape[j] := LRevShape[High(LRevShape) - j];
        LRevShape[High(LRevShape) - j] := LTemp;
      end;

      LValue := TORTValue.CreateTensor<Single>(
        DefaultAllocator.GetInfo,
        LFloatData[0],
        LElementCount,
        @LRevShape[0],
        Length(LRevShape));
      LInputs.AddOrSetValue(AnsiString(AInputNames[i]), LValue);
    end;

    LSW := TStopwatch.StartNew;
    LOutputs := TORTSessionPtr(FOrtSession)^.Run(LInputs);
    LSW.Stop;

    SetLength(LNames, LOutputs.Count);
    for i := 0 to LOutputs.Count - 1 do
      LNames[i] := string(AnsiString(LOutputs.Keys[i]));

    Result := TInferenceOutput.Succeeded(
      LSW.Elapsed.TotalMilliseconds, LNames);

    Logger.DebugFmt(
      'Inference.Session: Run completed in %.1fms (%d outputs)',
      [LSW.Elapsed.TotalMilliseconds, LOutputs.Count], 'Inference');
  except
    on E: Exception do
    begin
      Result := TInferenceOutput.Failed(E.Message);
      Logger.ErrorFmt('Inference.Session: Run failed: %s',
        [E.Message], 'Inference');
    end;
  end;
end;

procedure TInferenceSession.Dispose;
begin
  if FState = issDisposed then
    Exit;

  ReleaseOrtSession;
  FState := issDisposed;
  Logger.InfoFmt('Inference.Session: disposed (%s)', [FSessionId],
    'Inference');
end;

end.
