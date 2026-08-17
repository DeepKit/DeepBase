{ ============================================================================
  DeepBase.Speech.Voiceprint
  ---------------------------------------------------------------------------
  Version     : 1.1
  Description : Local speaker similarity check using MFCC + DTW.
                NOT identity authentication — only reduces wake word false
                triggers.
  Thread Safety: All public methods are thread-safe.
  Privacy     : Biometric data (MFCC features) encrypted at rest via DPAPI
                when an IVoiceProfileStorage backend is wired in.
  Persistence : In-memory by default. Assign a storage via SetStorage() (or
                LoadFromStorage) to persist across restarts. Ships with
                TDPAPIFileVoiceProfileStorage (file + DPAPI) — callers can
                provide a DB-backed implementation that talks to the
                voice_profiles table from DeepBase.Speech.Schema.
  Sample rule : Each enrollment sample must contain >= MIN_SAMPLE_FRAMES
                MFCC frames (>= ~500ms of non-silent PCM16@16kHz).
  ============================================================================ }

unit DeepBase.Speech.Voiceprint;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Math,
  System.Generics.Collections,
  DeepBase.Speech.MFCC, DeepBase.Speech.DTW,
  DeepBase.Speech.Voiceprint.Contracts;

const
  /// <summary>
  /// Minimum MFCC frames per enrollment sample.
  /// With 25ms window + 10ms hop, 45 frames ≈ 500ms of audio at 16kHz.
  /// Samples shorter than this are rejected to keep FAR low.
  /// </summary>
  MIN_SAMPLE_FRAMES = 45;

type
  // TVoiceProfileId, TVoiceProfileInfo, IVoiceProfileStorage are declared in
  // DeepBase.Speech.Voiceprint.Contracts so the Persistence-layer
  // TDBVoiceProfileStorage can implement them without Features <-> Persistence
  // coupling. Re-exported here for source-compat.

  TVerifyResult = record
    Match: Boolean;
    Score: Double;       // 0..1 (1 = identical)
    Distance: Double;    // DTW normalized distance
  end;

  /// <summary>
  /// File-backed DPAPI-encrypted storage. Writes a single JSON blob to disk,
  /// protected via CryptProtectData. Suitable for local desktop apps.
  /// For multi-user or server deployments, supply a DB-backed implementation
  /// that uses the voice_profiles table from DeepBase.Speech.Schema.
  /// </summary>
  TDPAPIFileVoiceProfileStorage = class(TInterfacedObject, IVoiceProfileStorage)
  private
    FFilePath: string;
    function FramesToBytes(const AFeatures: TMFCCFeatures): TBytes;
    function BytesToFrames(const ABytes: TBytes): TMFCCFeatures;
  public
    constructor Create(const AFilePath: string);
    function LoadAll: TArray<TPair<TVoiceProfileId, TVoiceProfileInfo>>;
    function LoadFeatures(const AId: TVoiceProfileId): TMFCCFeatures;
    procedure SaveProfile(const AId: TVoiceProfileId; const AInfo: TVoiceProfileInfo;
      const AMean: TMFCCFrame);
    function DeleteProfile(const AId: TVoiceProfileId): Boolean;
  end;

  TDeepBaseVoiceprint = class
  private
    FLock: TCriticalSection;
    FExtractor: TMFCCExtractor;
    // In-memory profile cache (kept in sync with FStorage when assigned)
    FProfiles: TDictionary<TVoiceProfileId, TMFCCFrame>; // mean vectors
    FProfileInfos: TDictionary<TVoiceProfileId, TVoiceProfileInfo>;
    FStorage: IVoiceProfileStorage;
    procedure PersistToStorage(const AId: TVoiceProfileId);
    procedure RemoveFromStorage(const AId: TVoiceProfileId);
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    /// Plug in a persistence backend. Non-owning — caller keeps the reference.
    /// Pass nil to revert to in-memory-only mode.
    /// </summary>
    procedure SetStorage(const AStorage: IVoiceProfileStorage);

    /// <summary>
    /// Load profiles from the current storage backend into the in-memory cache.
    /// No-op if no storage is set. Safe to call repeatedly.
    /// </summary>
    procedure LoadFromStorage;

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
    /// List all profiles currently in the in-memory cache, optionally filtered
    /// by owner app. To pick up changes made by other processes, call
    /// LoadFromStorage first.
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
  System.DateUtils, System.IOUtils, System.JSON,
  DeepBase.Security.DPAPI, DeepBase.Crypto, DeepBase.Crypto.Encoding;

{ TDPAPIFileVoiceProfileStorage }

constructor TDPAPIFileVoiceProfileStorage.Create(const AFilePath: string);
begin
  inherited Create;
  if AFilePath = '' then
    raise EArgumentException.Create('TDPAPIFileVoiceProfileStorage: file path must not be empty');
  FFilePath := AFilePath;
end;

function TDPAPIFileVoiceProfileStorage.FramesToBytes(const AFeatures: TMFCCFeatures): TBytes;
var
  LTotal, LOfs, I: Integer;
begin
  // TMFCCFrame = array[0..12] of Single (13 * 4 = 52 bytes).
  LTotal := Length(AFeatures) * SizeOf(TMFCCFrame);
  SetLength(Result, LTotal);
  LOfs := 0;
  for I := 0 to High(AFeatures) do
  begin
    Move(AFeatures[I][0], Result[LOfs], SizeOf(TMFCCFrame));
    Inc(LOfs, SizeOf(TMFCCFrame));
  end;
end;

function TDPAPIFileVoiceProfileStorage.BytesToFrames(const ABytes: TBytes): TMFCCFeatures;
var
  LFrameSize, LCount, LOfs, I: Integer;
begin
  LFrameSize := SizeOf(TMFCCFrame);
  if (Length(ABytes) = 0) or (Length(ABytes) mod LFrameSize <> 0) then
    raise EArgumentException.Create('Voiceprint storage: corrupted feature blob');
  LCount := Length(ABytes) div LFrameSize;
  SetLength(Result, LCount);
  LOfs := 0;
  for I := 0 to LCount - 1 do
  begin
    Move(ABytes[LOfs], Result[I][0], LFrameSize);
    Inc(LOfs, LFrameSize);
  end;
end;

function TDPAPIFileVoiceProfileStorage.LoadAll:
  TArray<TPair<TVoiceProfileId, TVoiceProfileInfo>>;
var
  LEncrypted, LPlain: TBytes;
  LJson: string;
  LArr: TJSONArray;
  LItem: TJSONValue;
  LObj: TJSONObject;
  LList: TList<TPair<TVoiceProfileId, TVoiceProfileInfo>>;
  LId: string;
  LInfo: TVoiceProfileInfo;
begin
  SetLength(Result, 0);
  if not TFile.Exists(FFilePath) then Exit;

  try
    LEncrypted := TFile.ReadAllBytes(FFilePath);
    if Length(LEncrypted) = 0 then Exit;
    LPlain := TDPAPIHelper.Unprotect(LEncrypted);
    LJson := TEncoding.UTF8.GetString(LPlain);

    LArr := TJSONObject.ParseJSONValue(LJson) as TJSONArray;
    if LArr = nil then Exit;
    try
      LList := TList<TPair<TVoiceProfileId, TVoiceProfileInfo>>.Create;
      try
        for LItem in LArr do
        begin
          LObj := LItem as TJSONObject;
          LId := LObj.GetValue('id').Value;
          LInfo.ProfileId := LId;
          LInfo.UserLabel := LObj.GetValue('user_label').Value;
          LInfo.Purpose := LObj.GetValue('purpose').Value;
          LInfo.SampleCount := (LObj.GetValue('sample_count') as TJSONNumber).AsInt;
          LInfo.Threshold := (LObj.GetValue('threshold') as TJSONNumber).AsDouble;
          LInfo.OwnerApp := LObj.GetValue('owner_app').Value;
          LInfo.Enabled := (LObj.GetValue('enabled') as TJSONNumber).AsInt <> 0;
          LInfo.CreatedAt := ISO8601ToDate(LObj.GetValue('created_at').Value, False);
          LList.Add(TPair<TVoiceProfileId, TVoiceProfileInfo>.Create(LId, LInfo));
        end;
        Result := LList.ToArray;
      finally
        LList.Free;
      end;
    finally
      LArr.Free;
    end;
  except
    // Corrupted or unreadable storage — start clean rather than crashing.
    on E: Exception do
    begin
      // Optional: log to DeepBase.Logging here.
      SetLength(Result, 0);
    end;
  end;
end;

function TDPAPIFileVoiceProfileStorage.LoadFeatures(const AId: TVoiceProfileId): TMFCCFeatures;
var
  LEncrypted, LPlain: TBytes;
  LJson: string;
  LArr: TJSONArray;
  LItem: TJSONValue;
  LObj: TJSONObject;
  LBytes: TBytes;
begin
  SetLength(Result, 0);
  if not TFile.Exists(FFilePath) then Exit;

  try
    LEncrypted := TFile.ReadAllBytes(FFilePath);
    if Length(LEncrypted) = 0 then Exit;
    LPlain := TDPAPIHelper.Unprotect(LEncrypted);
    LJson := TEncoding.UTF8.GetString(LPlain);

    LArr := TJSONObject.ParseJSONValue(LJson) as TJSONArray;
    if LArr = nil then Exit;
    try
      for LItem in LArr do
      begin
        LObj := LItem as TJSONObject;
        if LObj.GetValue('id').Value = AId then
        begin
          LBytes := TEncodingUtils.Base64Decode(
            LObj.GetValue('features_b64').Value);
          Result := BytesToFrames(LBytes);
          Exit;
        end;
      end;
    finally
      LArr.Free;
    end;
  except
    on E: Exception do
      SetLength(Result, 0);
  end;
end;

procedure TDPAPIFileVoiceProfileStorage.SaveProfile(const AId: TVoiceProfileId;
  const AInfo: TVoiceProfileInfo; const AMean: TMFCCFrame);
var
  LOldArr, LNewArr: TJSONArray;
  LObj: TJSONObject;
  LJson: string;
  LPlain, LEncrypted: TBytes;
  LDir: string;
  LFeatures: TMFCCFeatures;
  LBytes: TBytes;
  I: Integer;
  LItem: TJSONValue;
begin
  LOldArr := nil;
  LNewArr := TJSONArray.Create;
  try
    // 1. Read existing entries (if any), skipping any entry that matches AId.
    if TFile.Exists(FFilePath) then
    begin
      try
        LPlain := TDPAPIHelper.Unprotect(TFile.ReadAllBytes(FFilePath));
        LJson := TEncoding.UTF8.GetString(LPlain);
        LOldArr := TJSONObject.ParseJSONValue(LJson) as TJSONArray;
      except
        LOldArr := nil;
      end;
    end;

    if LOldArr <> nil then
    try
      for I := 0 to LOldArr.Count - 1 do
      begin
        LItem := LOldArr.Items[I];
        if LItem is TJSONObject then
        begin
          LObj := TJSONObject(LItem);
          if LObj.GetValue('id').Value = AId then
            Continue; // drop: will be replaced
        end;
        // Copy entry by serializing and re-parsing — avoids ownership gymnastics
        // across Delphi JSON versions.
        LNewArr.AddElement(
          TJSONObject.ParseJSONValue(TJSONObject(LItem).ToJSON) as TJSONObject);
      end;
    finally
      LOldArr.Free;
    end;

    // 2. Encode MFCC mean vector.
    SetLength(LFeatures, 1);
    LFeatures[0] := AMean;
    LBytes := FramesToBytes(LFeatures);

    // 3. Append new entry.
    LObj := TJSONObject.Create;
    LObj.AddPair('id', AId);
    LObj.AddPair('user_label', AInfo.UserLabel);
    LObj.AddPair('purpose', AInfo.Purpose);
    LObj.AddPair('sample_count', TJSONNumber.Create(AInfo.SampleCount));
    LObj.AddPair('threshold', TJSONNumber.Create(AInfo.Threshold));
    LObj.AddPair('owner_app', AInfo.OwnerApp);
    LObj.AddPair('enabled', TJSONNumber.Create(Integer(AInfo.Enabled)));
    LObj.AddPair('created_at', DateToISO8601(AInfo.CreatedAt, False));
    LObj.AddPair('features_b64', TEncodingUtils.Base64Encode(LBytes));
    LNewArr.AddElement(LObj);

    // 4. Serialize, DPAPI-protect, write.
    LJson := LNewArr.ToJSON;
    LPlain := TEncoding.UTF8.GetBytes(LJson);
    LEncrypted := TDPAPIHelper.Protect(LPlain);

    LDir := TPath.GetDirectoryName(FFilePath);
    if (LDir <> '') and not TDirectory.Exists(LDir) then
      TDirectory.CreateDirectory(LDir);
    TFile.WriteAllBytes(FFilePath, LEncrypted);
  finally
    LNewArr.Free;
  end;
end;

function TDPAPIFileVoiceProfileStorage.DeleteProfile(const AId: TVoiceProfileId): Boolean;
var
  LEncrypted, LPlain: TBytes;
  LJson: string;
  LOldArr, LNewArr: TJSONArray;
  LObj: TJSONObject;
  LItem: TJSONValue;
  I: Integer;
begin
  Result := False;
  if not TFile.Exists(FFilePath) then Exit;

  try
    LEncrypted := TFile.ReadAllBytes(FFilePath);
    if Length(LEncrypted) = 0 then Exit;
    LPlain := TDPAPIHelper.Unprotect(LEncrypted);
    LJson := TEncoding.UTF8.GetString(LPlain);

    LOldArr := TJSONObject.ParseJSONValue(LJson) as TJSONArray;
    if LOldArr = nil then Exit;

    LNewArr := TJSONArray.Create;
    try
      // Copy entries that don't match the ID being deleted.
      for I := 0 to LOldArr.Count - 1 do
      begin
        LItem := LOldArr.Items[I];
        if LItem is TJSONObject then
        begin
          LObj := TJSONObject(LItem);
          if LObj.GetValue('id').Value = AId then
          begin
            Result := True;
            Continue; // skip the deleted entry
          end;
        end;
        LNewArr.AddElement(
          TJSONObject.ParseJSONValue(TJSONObject(LItem).ToJSON) as TJSONObject);
      end;

      if Result then
      begin
        LJson := LNewArr.ToJSON;
        LPlain := TEncoding.UTF8.GetBytes(LJson);
        LEncrypted := TDPAPIHelper.Protect(LPlain);
        TFile.WriteAllBytes(FFilePath, LEncrypted);
      end;
    finally
      LNewArr.Free;
      LOldArr.Free;
    end;
  except
    on E: Exception do
      Result := False;
  end;
end;

{ TDeepBaseVoiceprint }

constructor TDeepBaseVoiceprint.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FExtractor := TMFCCExtractor.Create(16000);
  FProfiles := TDictionary<TVoiceProfileId, TMFCCFrame>.Create;
  FProfileInfos := TDictionary<TVoiceProfileId, TVoiceProfileInfo>.Create;
  FStorage := nil;
end;

destructor TDeepBaseVoiceprint.Destroy;
begin
  FStorage := nil; // non-owning — clear before inherited in case it re-enters
  FreeAndNil(FProfileInfos);
  FreeAndNil(FProfiles);
  FreeAndNil(FExtractor);
  FreeAndNil(FLock);
  inherited;
end;

procedure TDeepBaseVoiceprint.SetStorage(const AStorage: IVoiceProfileStorage);
begin
  FLock.Enter;
  try
    FStorage := AStorage;
  finally
    FLock.Leave;
  end;
end;

procedure TDeepBaseVoiceprint.LoadFromStorage;
var
  LAll: TArray<TPair<TVoiceProfileId, TVoiceProfileInfo>>;
  LPair: TPair<TVoiceProfileId, TVoiceProfileInfo>;
  LFeatures: TMFCCFeatures;
begin
  FLock.Enter;
  try
    if FStorage = nil then Exit;
    try
      LAll := FStorage.LoadAll;
      for LPair in LAll do
      begin
        FProfileInfos.AddOrSetValue(LPair.Key, LPair.Value);
        if not FProfiles.ContainsKey(LPair.Key) then
        begin
          LFeatures := FStorage.LoadFeatures(LPair.Key);
          if Length(LFeatures) > 0 then
            FProfiles.AddOrSetValue(LPair.Key, LFeatures[0]);
        end;
      end;
    except
      // Storage failures must never prevent the Voiceprint from being usable.
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TDeepBaseVoiceprint.PersistToStorage(const AId: TVoiceProfileId);
var
  LInfo: TVoiceProfileInfo;
  LMean: TMFCCFrame;
begin
  if FStorage = nil then Exit;
  if not FProfileInfos.TryGetValue(AId, LInfo) then Exit;
  if not FProfiles.TryGetValue(AId, LMean) then Exit;
  try
    FStorage.SaveProfile(AId, LInfo, LMean);
  except
    // Persist failures are non-fatal — the in-memory copy is still authoritative.
  end;
end;

procedure TDeepBaseVoiceprint.RemoveFromStorage(const AId: TVoiceProfileId);
begin
  if FStorage = nil then Exit;
  try
    FStorage.DeleteProfile(AId);
  except
    // Same contract as PersistToStorage — never raise through the public API.
  end;
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
      // BUG-278: each sample must cover >= 500ms of non-silent audio.
      // With MFCC 25ms window + 10ms hop, MIN_SAMPLE_FRAMES (=45) frames ≈ 500ms.
      if Length(LFeatures) < MIN_SAMPLE_FRAMES then
        raise EArgumentException.CreateFmt(
          'Sample %d is too short or silent (got %d frames, need >= %d for ~500ms)',
          [I + 1, Length(LFeatures), MIN_SAMPLE_FRAMES]);
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

  // Update in-memory cache
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

  // Persist if a storage backend is wired in. Done outside the lock so a slow
  // disk / DPAPI call can't block verify/identify.
  PersistToStorage(LId);

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
  // Also remove from the storage backend (outside the lock).
  if Result then
    RemoveFromStorage(AId);
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
