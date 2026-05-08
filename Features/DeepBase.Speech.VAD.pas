unit DeepBase.Speech.VAD;

interface

uses
  System.Math;

type
  TDeepBaseSpeechVAD = class
  private
    FThreshold: Double;
    FSilenceFrames: Integer;
    FFrameSize: Integer;
    FMaxSilenceFrames: Integer;
    FTriggered: Boolean;
  public
    constructor Create(AThresholdDb: Double = -40; AFrameMs: Double = 100;
      ASampleRate: Integer = 16000; ASilenceSeconds: Double = 1.5);
    function ProcessFrame(const ASamples: PSingle; ACount: Integer): Boolean;
    function ProcessAll(const ASamples: PSingle; ATotalCount: Integer): Boolean;
    procedure Reset;
    property Threshold: Double read FThreshold;
    property FrameSize: Integer read FFrameSize;
  end;

implementation

{$POINTERMATH ON}

constructor TDeepBaseSpeechVAD.Create(AThresholdDb, AFrameMs: Double;
  ASampleRate: Integer; ASilenceSeconds: Double);
begin
  inherited Create;
  FThreshold := Power(10, AThresholdDb / 20);
  FFrameSize := Max(1, Round(ASampleRate * AFrameMs / 1000));
  FMaxSilenceFrames := Max(1, Round(ASilenceSeconds / (AFrameMs / 1000)));
  Reset;
end;

function TDeepBaseSpeechVAD.ProcessFrame(const ASamples: PSingle;
  ACount: Integer): Boolean;
var
  I: Integer;
  RMS: Double;
  Sum: Double;
begin
  Result := False;
  if (ASamples = nil) or (ACount <= 0) then
    Exit;

  Sum := 0;
  for I := 0 to ACount - 1 do
    Sum := Sum + ASamples[I] * ASamples[I];
  RMS := Sqrt(Sum / ACount);

  if RMS >= FThreshold then
  begin
    FTriggered := True;
    FSilenceFrames := 0;
  end
  else if FTriggered then
  begin
    Inc(FSilenceFrames);
    Result := FSilenceFrames >= FMaxSilenceFrames;
  end;
end;

function TDeepBaseSpeechVAD.ProcessAll(const ASamples: PSingle;
  ATotalCount: Integer): Boolean;
var
  ChunkSize: Integer;
  Offset: Integer;
begin
  Result := False;
  Reset;
  if (ASamples = nil) or (ATotalCount <= 0) then
    Exit;

  Offset := 0;
  while Offset < ATotalCount do
  begin
    ChunkSize := Min(FFrameSize, ATotalCount - Offset);
    if ProcessFrame(@ASamples[Offset], ChunkSize) then
      Exit(True);
    Inc(Offset, ChunkSize);
  end;
end;

procedure TDeepBaseSpeechVAD.Reset;
begin
  FSilenceFrames := 0;
  FTriggered := False;
end;

end.
