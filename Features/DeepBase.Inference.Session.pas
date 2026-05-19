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
    function RunTyped(const AInputs: TArray<TInferenceInput>): TInferenceOutput;
    function GetCustomMetadata(const AKey: string): string;
    procedure Dispose;
  end;

implementation

uses
  System.Diagnostics,
  {$IFDEF HAS_ONNX}
  onnxruntime,
  onnxruntime_pas_api,
  {$ENDIF}
  DeepBase.Logging;

{$IFDEF HAS_ONNX}
type
  TORTSessionPtr = ^TORTSession;
{$ENDIF}

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
{$IFDEF HAS_ONNX}
var
  LSession: TORTSession;
{$ENDIF}
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

  {$IFDEF HAS_ONNX}
  try
    LSession := TORTSession.Create(AModelPath);
    GetMem(FOrtSession, SizeOf(TORTSession));
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
      // INFER-008: free any partially allocated ONNX resources before
      // re-raising. Without this, ExtractModelInfo failing after FOrtSession
      // has been allocated leaks the underlying TORTSession (and its model
      // weights) until process exit.
      ReleaseOrtSession;
      FState := issUninitialized;
      raise EInferenceModelError.CreateFmt(
        'Failed to load model from file: %s (%s)', [AModelPath, E.Message]);
    end;
  end;
  {$ELSE}
  raise EInferenceModelError.Create('ONNX runtime not available');
  {$ENDIF}
end;

constructor TInferenceSession.CreateFromBytes(
  const ARuntime: IInferenceRuntime; const AModelData: TBytes);
{$IFDEF HAS_ONNX}
var
  LSession: TORTSession;
{$ENDIF}
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

  {$IFDEF HAS_ONNX}
  try
    LSession := TORTSession.Create(
      DefaultEnv, @AModelData[0], Length(AModelData), DefaultSessionOptions);
    GetMem(FOrtSession, SizeOf(TORTSession));
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
      // INFER-008: see CreateFromPath -- release any partially allocated
      // ONNX resources before re-raising so the failed-construct path does
      // not leak model weights into the process.
      ReleaseOrtSession;
      FState := issUninitialized;
      raise EInferenceModelError.CreateFmt(
        'Failed to load model from memory: %s', [E.Message]);
    end;
  end;
  {$ELSE}
  raise EInferenceModelError.Create('ONNX runtime not available');
  {$ENDIF}
end;

destructor TInferenceSession.Destroy;
begin
  ReleaseOrtSession;
  FState := issDisposed;
  inherited;
end;

procedure TInferenceSession.ReleaseOrtSession;
{$IFDEF HAS_ONNX}
var
  P: TORTSessionPtr;
{$ENDIF}
begin
  if FOrtSession <> nil then
  begin
    {$IFDEF HAS_ONNX}
    P := TORTSessionPtr(FOrtSession);
    // TORTSession is a managed record. Finalize it before freeing memory
    // so the smart-pointer housekeeper decrements the ORT refcount.
    Finalize(P^);
    FreeMem(P);
    {$ENDIF}
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
{$IFDEF HAS_ONNX}
var
  LMeta: TORTModelMetadata;
  LP: Pointer;
{$ENDIF}
begin
  FModelInfo := TInferenceModelInfo.Empty;

  {$IFDEF HAS_ONNX}
  FModelInfo.InputCount :=
    Integer(TORTSessionPtr(FOrtSession)^.GetInputCount);
  FModelInfo.OutputCount :=
    Integer(TORTSessionPtr(FOrtSession)^.GetOutputCount);

  LMeta := TORTSessionPtr(FOrtSession)^.GetModelMetadata;
  try
    // INFER-005: Use UTF-8 conversion to preserve non-ASCII characters in
    // metadata strings. AnsiString cast loses CJK/emoji content depending on
    // the Windows ANSI codepage.
    LP := LMeta.GetProducerNameAllocated(DefaultAllocator).Instance;
    if LP <> nil then FModelInfo.ProducerName := UTF8ToString(PAnsiChar(LP));
    LP := LMeta.GetGraphNameAllocated(DefaultAllocator).Instance;
    if LP <> nil then FModelInfo.GraphName := UTF8ToString(PAnsiChar(LP));
    LP := LMeta.GetDescriptionAllocated(DefaultAllocator).Instance;
    if LP <> nil then FModelInfo.Description := UTF8ToString(PAnsiChar(LP));
  except
    // metadata extraction is non-critical
  end;
  {$ENDIF}
end;

function TInferenceSession.Run(const AInputNames: TArray<string>;
  const AInputValues: TArray<TBytes>;
  const AInputShapes: TArray<TArray<Int64>>): TInferenceOutput;
{$IFDEF HAS_ONNX}
var
  LInputs, LOutputs: TORTNameValueList;
  LSW: TStopwatch;
  LNames: TArray<string>;
  LData: TArray<TBytes>;
  LShapes: TArray<TArray<Int64>>;
  i: Integer;
  LFloatData: TArray<Single>;
  LShape: TArray<Int64>;
  LRevShape: TArray<Int64>;
  LValue: TORTValue;
  LElementCount: size_t;
  j: Integer;
  LOutValue: TORTValue;
  LOutShape: TArray<Int64>;
  LByteCount: NativeUInt;
  LRawPtr: Pointer;
{$ENDIF}
begin
  if FState <> issReady then
    Exit(TInferenceOutput.Failed('Session is not ready'));

  if Length(AInputNames) <> Length(AInputValues) then
    Exit(TInferenceOutput.Failed('InputNames and InputValues length mismatch'));
  if Length(AInputNames) <> Length(AInputShapes) then
    Exit(TInferenceOutput.Failed('InputNames and InputShapes length mismatch'));

  {$IFDEF HAS_ONNX}
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

      // INFER-006: Validate that the declared shape's product matches the
      // element count before calling into ONNX, otherwise the runtime can
      // read past buffer boundaries.
      var LExpectedElements: Int64 := 1;
      for var LDimIdx := 0 to High(LShape) do
      begin
        if LShape[LDimIdx] <= 0 then
          raise EInferenceSessionError.CreateFmt(
            'Input "%s" has non-positive dimension %d at index %d',
            [AInputNames[i], LShape[LDimIdx], LDimIdx]);
        LExpectedElements := LExpectedElements * LShape[LDimIdx];
      end;
      if LExpectedElements <> Int64(LElementCount) then
        raise EInferenceSessionError.CreateFmt(
          'Input "%s" shape product (%d) does not match element count (%d)',
          [AInputNames[i], LExpectedElements, LElementCount]);

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
    SetLength(LData, LOutputs.Count);
    SetLength(LShapes, LOutputs.Count);
    for i := 0 to LOutputs.Count - 1 do
    begin
      LNames[i] := string(AnsiString(LOutputs.Keys[i]));
      LOutValue := LOutputs.Values[i];
      LOutShape := LOutValue.GetTensorShape;
      LShapes[i] := LOutShape;

      LByteCount := 1;
      for j := 0 to High(LOutShape) do
        LByteCount := LByteCount * NativeUInt(LOutShape[j]);
      LByteCount := LByteCount * SizeOf(Single);

      SetLength(LData[i], LByteCount);
      LRawPtr := LOutValue.GetTensorMutableData<Single>;
      if (LByteCount > 0) and (LRawPtr <> nil) then
        Move(LRawPtr^, LData[i][0], LByteCount);
    end;

    Result := TInferenceOutput.Succeeded(
      LSW.Elapsed.TotalMilliseconds, LNames, LData, LShapes);

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
  {$ELSE}
  Result := TInferenceOutput.Failed('ONNX runtime not available');
  {$ENDIF}
end;

function TInferenceSession.RunTyped(
  const AInputs: TArray<TInferenceInput>): TInferenceOutput;
{$IFDEF HAS_ONNX}
var
  LInputs, LOutputs: TORTNameValueList;
  LSW: TStopwatch;
  LNames: TArray<string>;
  LData: TArray<TBytes>;
  LShapes: TArray<TArray<Int64>>;
  i, j: Integer;
  LRevShape: TArray<Int64>;
  LFloatData: TArray<Single>;
  LIntData: TArray<Integer>;
  LValue: TORTValue;
  LElementCount: size_t;
  LOutValue: TORTValue;
  LOutShape: TArray<Int64>;
  LByteCount: NativeUInt;
  LRawPtr: Pointer;
{$ENDIF}
begin
  if FState <> issReady then
    Exit(TInferenceOutput.Failed('Session is not ready'));

  {$IFDEF HAS_ONNX}
  try
    LInputs := Default(TORTNameValueList);

    for i := 0 to High(AInputs) do
    begin
      if Length(AInputs[i].Data) = 0 then
        raise EInferenceSessionError.CreateFmt(
          'Empty input data for "%s"', [AInputs[i].Name]);

      LRevShape := Copy(AInputs[i].Shape);
      for j := 0 to High(LRevShape) div 2 do
      begin
        var LTemp: Int64 := LRevShape[j];
        LRevShape[j] := LRevShape[High(LRevShape) - j];
        LRevShape[High(LRevShape) - j] := LTemp;
      end;

      case AInputs[i].ElementType of
        ietFloat32:
        begin
          LElementCount := Length(AInputs[i].Data) div SizeOf(Single);
          SetLength(LFloatData, LElementCount);
          Move(AInputs[i].Data[0], LFloatData[0], LElementCount * SizeOf(Single));
          LValue := TORTValue.CreateTensor<Single>(
            DefaultAllocator.GetInfo,
            LFloatData[0],
            LElementCount,
            @LRevShape[0],
            Length(LRevShape));
        end;
        ietInt32:
        begin
          LElementCount := Length(AInputs[i].Data) div SizeOf(Integer);
          SetLength(LIntData, LElementCount);
          Move(AInputs[i].Data[0], LIntData[0], LElementCount * SizeOf(Integer));
          LValue := TORTValue.CreateTensor<Integer>(
            DefaultAllocator.GetInfo,
            LIntData[0],
            LElementCount,
            @LRevShape[0],
            Length(LRevShape));
        end;
      else
        raise EInferenceSessionError.CreateFmt(
          'Unsupported element type for input "%s"', [AInputs[i].Name]);
      end;

      LInputs.AddOrSetValue(AnsiString(AInputs[i].Name), LValue);
    end;

    LSW := TStopwatch.StartNew;
    LOutputs := TORTSessionPtr(FOrtSession)^.Run(LInputs);
    LSW.Stop;

    SetLength(LNames, LOutputs.Count);
    SetLength(LData, LOutputs.Count);
    SetLength(LShapes, LOutputs.Count);
    for i := 0 to LOutputs.Count - 1 do
    begin
      LNames[i] := string(AnsiString(LOutputs.Keys[i]));
      LOutValue := LOutputs.Values[i];
      LOutShape := LOutValue.GetTensorShape;
      LShapes[i] := LOutShape;

      LByteCount := 1;
      for j := 0 to High(LOutShape) do
        LByteCount := LByteCount * NativeUInt(LOutShape[j]);
      LByteCount := LByteCount * SizeOf(Single);

      SetLength(LData[i], LByteCount);
      LRawPtr := LOutValue.GetTensorMutableData<Single>;
      if (LByteCount > 0) and (LRawPtr <> nil) then
        Move(LRawPtr^, LData[i][0], LByteCount);
    end;

    Result := TInferenceOutput.Succeeded(
      LSW.Elapsed.TotalMilliseconds, LNames, LData, LShapes);

    Logger.DebugFmt(
      'Inference.Session: RunTyped completed in %.1fms (%d inputs, %d outputs)',
      [LSW.Elapsed.TotalMilliseconds, Length(AInputs), LOutputs.Count],
      'Inference');
  except
    on E: Exception do
    begin
      Result := TInferenceOutput.Failed(E.Message);
      Logger.ErrorFmt('Inference.Session: RunTyped failed: %s',
        [E.Message], 'Inference');
    end;
  end;
  {$ELSE}
  Result := TInferenceOutput.Failed('ONNX runtime not available');
  {$ENDIF}
end;

function TInferenceSession.GetCustomMetadata(const AKey: string): string;
{$IFDEF HAS_ONNX}
var
  LMeta: TORTModelMetadata;
  LAllocd: AllocatedStringPtr;
  LP: Pointer;
{$ENDIF}
begin
  Result := '';
  {$IFDEF HAS_ONNX}
  if FOrtSession = nil then
    Exit;
  try
    LMeta := TORTSessionPtr(FOrtSession)^.GetModelMetadata;
    LAllocd := LMeta.LookupCustomMetadataMapAllocated(
      PAnsiChar(AnsiString(AKey)), DefaultAllocator);
    LP := LAllocd.Instance;
    if LP <> nil then
      Result := string(AnsiString(PAnsiChar(LP)));
  except
    // metadata lookup failure is non-critical
  end;
  {$ENDIF}
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
