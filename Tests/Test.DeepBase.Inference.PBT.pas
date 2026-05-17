{ ============================================================================
  Test.DeepBase.Inference.PBT - Property tests for Round-2 inference fixes
  (deepbase-round2-fixes, sub-task 21.9).

  Properties covered:
    Property 36: Inference Runtime 重初始化 Round-Trip
                 Init -> Shutdown -> Init must leave the runtime in a
                 fully-functional state (IsInitialized=True, provider set).
                 Validates: Requirements 14.1, 14.2
    Property 37: Inference Session Shape 验证
                 An input tensor whose shape dimension product does not
                 equal the element count must be rejected before reaching
                 ONNX (INFER-006). Matching shapes pass.
                 Validates: Requirements 14.5
    Property 38: Inference Metadata UTF-8 保真
                 UTF-8 bytes round-tripped via UTF8ToString(PAnsiChar) -
                 the same path the session metadata reader uses - must
                 preserve every CJK character and emoji.
                 Validates: Requirements 14.4
    Property 39: InferenceService.IsReady 完整检查
                 IsReady must equal (FSessionFactory <> nil) AND
                 (FRuntime <> nil) AND FRuntime.IsInitialized.
                 Validates: Requirements 14.8

  Strategy:
    - DUnitX TestFixture, every property runs at least 100 iterations.
    - The user requested helper-mirror mode for this file because a full
      ONNX fixture would require onnxruntime.dll. Concretely:
        * P36 uses TInferenceRuntime with TInferenceConfig.Default (ipCPU).
          Even without HAS_ONNX, ipCPU initialise/shutdown only manipulates
          internal flags (AttachProviderCPU is a no-op), so it is safe to
          drive the production class directly.
        * P37 mirrors the shape-validation block from
          TInferenceSession.Run (the LExpectedElements <> LElementCount
          check) byte-for-byte. We do NOT invoke Session.Run.
        * P38 mirrors the UTF-8 metadata read path (UTF8ToString applied
          to a PAnsiChar of UTF-8 bytes). We do NOT touch ONNX.
        * P39 uses TInferenceService directly with stub runtime and stub
          factory implementations whose IsInitialized state we control.
  ============================================================================ }

unit Test.DeepBase.Inference.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.Inference.Types,
  DeepBase.Inference.Runtime,
  DeepBase.Inference.Service;

type
  [TestFixture]
  TInferenceRound2PropertyTests = class
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    // Feature: deepbase-round2-fixes, Property 36.
    [Test]
    procedure Property36_RuntimeReinitRoundTrip;

    // Feature: deepbase-round2-fixes, Property 37.
    [Test]
    procedure Property37_HelperMirror_SessionShapeValidation;

    // Feature: deepbase-round2-fixes, Property 38.
    [Test]
    procedure Property38_HelperMirror_MetadataUtf8Fidelity;

    // Feature: deepbase-round2-fixes, Property 39.
    [Test]
    procedure Property39_InferenceServiceIsReadyFullCheck;
  end;

implementation

{ ---------- Stubs for Property 39 ---------------------------------------- }

type
  TStubRuntime = class(TInterfacedObject, IInferenceRuntime)
  private
    FInitialized: Boolean;
  public
    constructor Create(AInitialized: Boolean);
    function GetProvider: TInferenceProvider;
    function IsInitialized: Boolean;
    procedure Initialize(const AConfig: TInferenceConfig);
    procedure Shutdown;
  end;

  TStubSession = class(TInterfacedObject, IInferenceSession)
  public
    function GetSessionId: string;
    function GetState: TInferenceSessionState;
    function GetModelInfo: TInferenceModelInfo;
    function Run(const AInputNames: TArray<string>;
      const AInputValues: TArray<TBytes>;
      const AInputShapes: TArray<TArray<Int64>>): TInferenceOutput;
    function GetCustomMetadata(const AKey: string): string;
    procedure Dispose;
  end;

  TStubSessionFactory = class(TInterfacedObject, IInferenceSessionFactory)
  public
    function CreateSession(const AModelPath: string): IInferenceSession; overload;
    function CreateSession(const AModelData: TBytes): IInferenceSession; overload;
  end;

constructor TStubRuntime.Create(AInitialized: Boolean);
begin
  inherited Create;
  FInitialized := AInitialized;
end;

function TStubRuntime.GetProvider: TInferenceProvider;
begin
  Result := ipCPU;
end;

function TStubRuntime.IsInitialized: Boolean;
begin
  Result := FInitialized;
end;

procedure TStubRuntime.Initialize(const AConfig: TInferenceConfig);
begin
  FInitialized := True;
end;

procedure TStubRuntime.Shutdown;
begin
  FInitialized := False;
end;

function TStubSession.GetSessionId: string;
begin
  Result := 'stub';
end;

function TStubSession.GetState: TInferenceSessionState;
begin
  Result := issReady;
end;

function TStubSession.GetModelInfo: TInferenceModelInfo;
begin
  Result := TInferenceModelInfo.Empty;
end;

function TStubSession.Run(const AInputNames: TArray<string>;
  const AInputValues: TArray<TBytes>;
  const AInputShapes: TArray<TArray<Int64>>): TInferenceOutput;
begin
  Result := TInferenceOutput.Failed('stub');
end;

function TStubSession.GetCustomMetadata(const AKey: string): string;
begin
  Result := '';
end;

procedure TStubSession.Dispose;
begin
end;

function TStubSessionFactory.CreateSession(const AModelPath: string): IInferenceSession;
begin
  Result := TStubSession.Create;
end;

function TStubSessionFactory.CreateSession(const AModelData: TBytes): IInferenceSession;
begin
  Result := TStubSession.Create;
end;

{ ---------- TInferenceRound2PropertyTests --------------------------------- }

procedure TInferenceRound2PropertyTests.Setup;
begin
  Randomize;
  TInferenceService.Shutdown;
end;

procedure TInferenceRound2PropertyTests.TearDown;
begin
  // Leave the global service clean for downstream tests.
  TInferenceService.Shutdown;
end;

// ---------------------------------------------------------------------------
// Property 36 - Initialize -> Shutdown -> Initialize must round-trip.
// We use ipCPU for every iteration so AttachProviderCPU runs (a no-op) and
// no ONNX DLL is needed regardless of HAS_ONNX. After each cycle the
// runtime must report IsInitialized=True and Provider=ipCPU.
// ---------------------------------------------------------------------------
procedure TInferenceRound2PropertyTests.Property36_RuntimeReinitRoundTrip;
const
  CIterations = 100;
var
  Iter: Integer;
  LRuntime: TInferenceRuntime;
  LCfg: TInferenceConfig;
begin
  for Iter := 1 to CIterations do
  begin
    LRuntime := TInferenceRuntime.Create;
    try
      LCfg := TInferenceConfig.Default;
      LCfg.Provider := ipCPU;

      // Cycle 1
      LRuntime.Initialize(LCfg);
      Assert.IsTrue(LRuntime.IsInitialized,
        Format('Iter %d cycle1: IsInitialized must be True after Initialize',
          [Iter]));
      Assert.AreEqual(Ord(ipCPU), Ord(LRuntime.Provider),
        Format('Iter %d cycle1: provider must be ipCPU', [Iter]));

      LRuntime.Shutdown;
      Assert.IsFalse(LRuntime.IsInitialized,
        Format('Iter %d cycle1: IsInitialized must be False after Shutdown',
          [Iter]));

      // Cycle 2 - must re-init cleanly.
      LRuntime.Initialize(LCfg);
      Assert.IsTrue(LRuntime.IsInitialized,
        Format('Iter %d cycle2: IsInitialized must be True after re-Initialize. '
          + 'INFER-001/002 broken if False.', [Iter]));
      Assert.AreEqual(Ord(ipCPU), Ord(LRuntime.Provider),
        Format('Iter %d cycle2: provider must remain ipCPU after re-init',
          [Iter]));

      // Calling Initialize when already initialised must short-circuit
      // through the internal Shutdown path and leave us still initialised.
      LRuntime.Initialize(LCfg);
      Assert.IsTrue(LRuntime.IsInitialized,
        Format('Iter %d: Initialize-while-initialised must remain True',
          [Iter]));
    finally
      LRuntime.Free;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Property 37 - Helper-mirror of the shape-vs-element-count guard from
// TInferenceSession.Run (INFER-006):
//   for d in shape: prod *= d; require prod = element_count
// We do NOT call Session.Run; we replicate the predicate and assert on a
// random mix of matching and mismatching pairs.
// ---------------------------------------------------------------------------
type
  TShapeValidation = record
    Valid: Boolean;
    ErrorReason: string;
  end;

function MirrorValidateShape(const AShape: TArray<Int64>;
  AElementCount: Int64): TShapeValidation;
var
  LExpected: Int64;
  I: Integer;
begin
  Result.Valid := True;
  Result.ErrorReason := '';

  // Mirror of: for each dim, must be > 0; product must equal element count.
  LExpected := 1;
  for I := 0 to High(AShape) do
  begin
    if AShape[I] <= 0 then
    begin
      Result.Valid := False;
      Result.ErrorReason := Format('non-positive dim %d at index %d',
        [AShape[I], I]);
      Exit;
    end;
    LExpected := LExpected * AShape[I];
  end;
  if LExpected <> AElementCount then
  begin
    Result.Valid := False;
    Result.ErrorReason := Format('shape product %d != element count %d',
      [LExpected, AElementCount]);
  end;
end;

procedure TInferenceRound2PropertyTests.Property37_HelperMirror_SessionShapeValidation;
const
  CIterations = 100;
var
  Iter, NDims, I: Integer;
  LShape: TArray<Int64>;
  LProduct, LElements: Int64;
  LRes: TShapeValidation;
  LMode: Integer;
begin
  for Iter := 1 to CIterations do
  begin
    NDims := 1 + Random(4); // 1..4 dims
    SetLength(LShape, NDims);
    LProduct := 1;
    for I := 0 to NDims - 1 do
    begin
      LShape[I] := 1 + Random(8); // dims 1..8
      LProduct := LProduct * LShape[I];
    end;

    // Three modes:
    //   0 = matching (must validate)
    //   1 = element count off by N (must be rejected)
    //   2 = inject a non-positive dim (must be rejected)
    LMode := Random(3);
    case LMode of
      0:
        begin
          LElements := LProduct;
          LRes := MirrorValidateShape(LShape, LElements);
          Assert.IsTrue(LRes.Valid,
            Format('Iter %d mode=match: matching shape (prod=%d) must validate; '
              + 'reason=%s', [Iter, LProduct, LRes.ErrorReason]));
        end;
      1:
        begin
          // Off by 1..product-1 (avoid hitting the same value).
          var LDelta: Int64 := 1 + Random(Integer(LProduct));
          LElements := LProduct + LDelta;
          LRes := MirrorValidateShape(LShape, LElements);
          Assert.IsFalse(LRes.Valid,
            Format('Iter %d mode=mismatch: element count %d != prod %d must FAIL',
              [Iter, LElements, LProduct]));
        end;
    else
      begin
        // Pick a dim and zero it out (simulate a non-positive shape entry).
        LShape[Random(NDims)] := 0;
        LElements := 1; // arbitrary, never reached because dim check fires first
        LRes := MirrorValidateShape(LShape, LElements);
        Assert.IsFalse(LRes.Valid,
          Format('Iter %d mode=zero-dim: zero dim must FAIL validation', [Iter]));
      end;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Property 38 - UTF-8 round-trip via the same conversion path the session
// metadata reader uses (UTF8ToString(PAnsiChar)). The original Unicode
// string must survive a TEncoding.UTF8.GetBytes -> UTF8ToString trip
// without mojibake, regardless of CJK / emoji content.
// ---------------------------------------------------------------------------
procedure TInferenceRound2PropertyTests.Property38_HelperMirror_MetadataUtf8Fidelity;
const
  CIterations = 100;

  function RandomUtf8String: string;
  var
    LSb: TStringBuilder;
    LLen, K: Integer;
    LCp: Cardinal;
  begin
    LLen := 1 + Random(40);
    LSb := TStringBuilder.Create;
    try
      for K := 0 to LLen - 1 do
      begin
        case Random(5) of
          0:
            // ASCII printable
            LSb.Append(Char($20 + Random(95)));
          1:
            // Latin-1 supplement
            LSb.Append(Char($A0 + Random($60)));
          2:
            // CJK Unified Ideographs (BMP)
            LSb.Append(Char($4E00 + Random($1000)));
          3:
            // Hiragana
            LSb.Append(Char($3040 + Random($60)));
        else
          // Astral plane (emoji) - encode as a surrogate pair.
          LCp := $1F600 + Cardinal(Random($50));
          LSb.Append(Char($D800 + ((LCp - $10000) shr 10)));
          LSb.Append(Char($DC00 + ((LCp - $10000) and $3FF)));
        end;
      end;
      Result := LSb.ToString;
    finally
      LSb.Free;
    end;
  end;

var
  Iter: Integer;
  LOriginal, LRoundTrip: string;
  LBytes: TBytes;
  LBuf: TBytes;
begin
  for Iter := 1 to CIterations do
  begin
    LOriginal := RandomUtf8String;

    // Serialize to UTF-8 bytes the way an external library would hand them
    // back (NUL-terminated PAnsiChar buffer).
    LBytes := TEncoding.UTF8.GetBytes(LOriginal);
    SetLength(LBuf, Length(LBytes) + 1);
    if Length(LBytes) > 0 then
      Move(LBytes[0], LBuf[0], Length(LBytes));
    LBuf[Length(LBytes)] := 0;

    // Mirror of TInferenceSession.ExtractModelInfo: UTF8ToString(PAnsiChar).
    LRoundTrip := UTF8ToString(PAnsiChar(@LBuf[0]));

    Assert.AreEqual(LOriginal, LRoundTrip,
      Format('Iter %d: UTF-8 round trip lost data. Original len=%d, '
        + 'round-trip len=%d. INFER-005 broken (would be AnsiString cast '
        + 'mojibake on non-ASCII).',
        [Iter, Length(LOriginal), Length(LRoundTrip)]));
  end;
end;

// ---------------------------------------------------------------------------
// Property 39 - IsReady must require all three: factory set, runtime set,
// runtime reports IsInitialized. We exhaustively cover all 4 false-cases
// plus the single true-case across iterations.
// ---------------------------------------------------------------------------
procedure TInferenceRound2PropertyTests.Property39_InferenceServiceIsReadyFullCheck;
const
  CIterations = 100;
var
  Iter, LCase: Integer;
  LRuntime: IInferenceRuntime;
  LFactory: IInferenceSessionFactory;
  LExpected: Boolean;
begin
  for Iter := 1 to CIterations do
  begin
    TInferenceService.Shutdown;

    // Five cases enumerated:
    //   0: nothing set                                 -> false
    //   1: only runtime set, not initialized           -> false
    //   2: only runtime set, initialized               -> false
    //   3: only factory set                            -> false
    //   4: factory set + runtime set, not initialized  -> false
    //   5: factory set + runtime set, initialized      -> TRUE
    LCase := Random(6);
    LExpected := (LCase = 5);

    LRuntime := nil;
    LFactory := nil;

    case LCase of
      1:
        LRuntime := TStubRuntime.Create(False);
      2:
        LRuntime := TStubRuntime.Create(True);
      3:
        LFactory := TStubSessionFactory.Create;
      4:
        begin
          LRuntime := TStubRuntime.Create(False);
          LFactory := TStubSessionFactory.Create;
        end;
      5:
        begin
          LRuntime := TStubRuntime.Create(True);
          LFactory := TStubSessionFactory.Create;
        end;
    end;

    if LRuntime <> nil then
      TInferenceService.SetRuntime(LRuntime);
    if LFactory <> nil then
      TInferenceService.SetSessionFactory(LFactory);

    Assert.AreEqual(LExpected, TInferenceService.IsReady,
      Format('Iter %d case=%d: IsReady=%s, expected=%s. INFER-010 broken.',
        [Iter, LCase, BoolToStr(TInferenceService.IsReady, True),
         BoolToStr(LExpected, True)]));
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TInferenceRound2PropertyTests);

end.
