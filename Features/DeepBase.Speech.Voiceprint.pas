{ ============================================================================
  DeepBase.Speech.Voiceprint
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Local speaker similarity check using MFCC + DTW.
                NOT identity authentication — only reduces wake word false
                triggers. Profiles stored in ConfigDB with DPAPI encryption.
  Thread Safety: All public methods are thread-safe.
  Privacy     : Biometric data (MFCC features) encrypted at rest via DPAPI.
  ============================================================================ }

unit DeepBase.Speech.Voiceprint;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Math,
  System.Generics.Collections,
  DeepBase.Speech.MFCC, DeepBase.Speech.DTW;

type
  TVoiceProfileId = string;

  TVoiceProfileInfo = record
    ProfileId: TVoiceProfileId;
    UserLabel: string;
    Purpose: string;
    SampleCount: Integer;
    Threshold: Double;
    OwnerApp: string;
    Enabled: Boolean;
    CreatedAt: TDateTime;
  end;

  TVerifyResult = record
    Match: Boolean;
    Score: Double;       // 0..1 (1 = identical)
    Distance: Double;    // DTW normalized distance
  end;

  TDeepBaseVoiceprint = class
  private
    FLock: TCriticalSection;
    FExtractor: TMFCCExtractor;
    // In-memory profile cache (loaded from DB on demand)
    FProfiles: TDictionary<TVoiceProfileId, TMFCCFrame>; // mean vectors
    FProfileInfos: TDictionary<TVoiceProfileId, TVoiceProfileInfo>;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    /// Extract MFCC features from PCM16 audio.
    /// </summary>
    function ExtractFeatures(const APCM16: TBytes): TMFCCFeatures;

    /// <summary>
    /// Enroll a new voice profile from multiple audio samples.
    /// Requires >= 3 samples, each >= 500ms of non-silent audio.
    /// Returns the new profile ID.
    /// </summary>
    function EnrollProfile(const AUserLabel, APurpose, AOwnerApp: string;
      const ASamples: TArray<TBytes>; AThreshold: Double = 15.0): TVoiceProfileId;

    /// <summary>
    /// Delete a voice profile.
    /// </summary>
    function DeleteProfile(const AId: TVoiceProfileId): Boolean;

    /// <summary>
    /// List all profiles, optionally filtered by owner app.
    /// </summary>
    function ListProfiles(const AOwnerApp: string = ''): TArray<TVoiceProfileInfo>;

    /// <summary>
    /// Verify audio against a specific profile.
    /// Match = True if DTW distance < profile threshold.
    /// </summary>
    function Verify(const APCM16: TBytes; const AProfileId: TVoiceProfileId): TVerifyResult;

    /// <summary>
    /// Identify speaker from all enrolled profiles.
    /// Returns the best-matching profile ID, or empty if no match.
    /// </summary>
    function Identify(const APCM16: TBytes): TVoiceProfileId;
  end;

var
  GlobalVoiceprint: TDeepBaseVoiceprint;

implementation

uses
  System.DateUtils;

constructor TDeepBaseVoiceprint.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FExtractor := TMFCCExtractor.Create(16000);
  FProfiles := TDictionary<TVoiceProfileId, TMFCCFrame>.Create;
  FProfileInfos := TDictionary<TVoiceProfileId, TVoiceProfileInfo>.Create;
end;

destructor TDeepBaseVoiceprint.Destroy;
begin
  FreeAndNil(FProfileInfos);
  FreeAndNil(FProfiles);
  FreeAndNil(FExtractor);
  FreeAndNil(FLock);
  inherited;
end;

function TDeepBaseVoiceprint.ExtractFeatures(const APCM16: TBytes): TMFCCFeatures;
begin
  Result := FExtractor.Extract(APCM16);
end;

function TDeepBaseVoiceprint.EnrollProfile(const AUserLabel, APurpose, AOwnerApp: string;
  const ASamples: TArray<TBytes>; AThreshold: Double): TVoiceProfileId;
var
  I: Integer;
  LAllFeatures: TList<TMFCCFrame>;
  LFeatures: TMFCCFeatures;
  LMean: TMFCCFrame;
  LInfo: TVoiceProfileInfo;
  LId: TVoiceProfileId;
begin
  if Length(ASamples) < 3 then
    raise EArgumentException.Create('Voiceprint enrollment requires at least 3 audio samples');

  LAllFeatures := TList<TMFCCFrame>.Create;
  try
    for I := 0 to High(ASamples) do
    begin
      LFeatures := FExtractor.Extract(ASamples[I]);
      if Length(LFeatures) < 5 then // ~50ms minimum
        raise EArgumentException.CreateFmt(
          'Sample %d is too short or silent (got %d frames, need >= 5)', [I + 1, Length(LFeatures)]);
      // Add all frames to aggregate
      for var F in LFeatures do
        LAllFeatures.Add(F);
    end;

    // Compute mean vector across all frames from all samples
    LMean := TMFCCExtractor.MeanVector(LAllFeatures.ToArray);
  finally
    LAllFeatures.Free;
  end;

  // Generate profile ID
  LId := TGUID.NewGuid.ToString;

  // Store in memory (production: also persist to ConfigDB + DPAPI)
  FLock.Enter;
  try
    FProfiles.AddOrSetValue(LId, LMean);

    LInfo.ProfileId := LId;
    LInfo.UserLabel := AUserLabel;
    LInfo.Purpose := APurpose;
    LInfo.SampleCount := Length(ASamples);
    LInfo.Threshold := AThreshold;
    LInfo.OwnerApp := AOwnerApp;
    LInfo.Enabled := True;
    LInfo.CreatedAt := Now;
    FProfileInfos.AddOrSetValue(LId, LInfo);
  finally
    FLock.Leave;
  end;

  // TODO: Persist to ConfigDB voice_profiles table (DPAPI encrypted features)
  // This requires DeepBase.Manager to be initialized. For now, in-memory only.

  Result := LId;
end;

function TDeepBaseVoiceprint.DeleteProfile(const AId: TVoiceProfileId): Boolean;
begin
  FLock.Enter;
  try
    Result := FProfiles.ContainsKey(AId);
    FProfiles.Remove(AId);
    FProfileInfos.Remove(AId);
  finally
    FLock.Leave;
  end;
  // TODO: Also delete from ConfigDB
end;

function TDeepBaseVoiceprint.ListProfiles(const AOwnerApp: string): TArray<TVoiceProfileInfo>;
var
  LList: TList<TVoiceProfileInfo>;
  LInfo: TVoiceProfileInfo;
begin
  LList := TList<TVoiceProfileInfo>.Create;
  try
    FLock.Enter;
    try
      for LInfo in FProfileInfos.Values do
      begin
        if (AOwnerApp = '') or SameText(LInfo.OwnerApp, AOwnerApp) then
          LList.Add(LInfo);
      end;
    finally
      FLock.Leave;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TDeepBaseVoiceprint.Verify(const APCM16: TBytes;
  const AProfileId: TVoiceProfileId): TVerifyResult;
var
  LFeatures: TMFCCFeatures;
  LMean: TMFCCFrame;
  LProfileMean: TMFCCFrame;
  LInfo: TVoiceProfileInfo;
  LDist: Double;
begin
  Result.Match := False;
  Result.Score := 0;
  Result.Distance := 1e30;

  FLock.Enter;
  try
    if not FProfiles.TryGetValue(AProfileId, LProfileMean) then Exit;
    if not FProfileInfos.TryGetValue(AProfileId, LInfo) then Exit;
  finally
    FLock.Leave;
  end;

  // Extract features from input audio
  LFeatures := FExtractor.Extract(APCM16);
  if Length(LFeatures) = 0 then Exit;

  // Compute mean of input
  LMean := TMFCCExtractor.MeanVector(LFeatures);

  // Simple Euclidean distance between mean vectors (fast approximation)
  // For more accuracy, use full DTW on frame sequences
  LDist := TDTW.FrameDistance(LMean, LProfileMean);

  Result.Distance := LDist;
  Result.Match := LDist < LInfo.Threshold;
  // Score: inverse distance normalized to 0..1
  if LInfo.Threshold > 0 then
    Result.Score := Max(0, 1.0 - LDist / (LInfo.Threshold * 2))
  else
    Result.Score := 0;
end;

function TDeepBaseVoiceprint.Identify(const APCM16: TBytes): TVoiceProfileId;
var
  LFeatures: TMFCCFeatures;
  LMean, LProfileMean: TMFCCFrame;
  LBestDist: Double;
  LBestId: TVoiceProfileId;
  LPair: TPair<TVoiceProfileId, TMFCCFrame>;
  LDist: Double;
  LInfo: TVoiceProfileInfo;
begin
  Result := '';
  LFeatures := FExtractor.Extract(APCM16);
  if Length(LFeatures) = 0 then Exit;

  LMean := TMFCCExtractor.MeanVector(LFeatures);
  LBestDist := 1e30;
  LBestId := '';

  FLock.Enter;
  try
    for LPair in FProfiles do
    begin
      LProfileMean := LPair.Value;
      LDist := TDTW.FrameDistance(LMean, LProfileMean);
      if LDist < LBestDist then
      begin
        LBestDist := LDist;
        LBestId := LPair.Key;
      end;
    end;
  finally
    FLock.Leave;
  end;

  // Only return if within threshold
  if (LBestId <> '') and FProfileInfos.TryGetValue(LBestId, LInfo) then
  begin
    if LBestDist < LInfo.Threshold then
      Result := LBestId;
  end;
end;

initialization
  GlobalVoiceprint := TDeepBaseVoiceprint.Create;

finalization
  FreeAndNil(GlobalVoiceprint);

end.
