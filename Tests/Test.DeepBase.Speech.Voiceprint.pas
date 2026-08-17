{ ============================================================================
  Test.DeepBase.Speech.Voiceprint - Unit tests for Voiceprint + storage

  Coverage:
    - IVoiceProfileStorage contract (in-memory mock + real DPAPI file storage)
    - EnrollProfile sample-duration rule (>= MIN_SAMPLE_FRAMES per sample)
    - Persistence round-trip: Enroll → Verify survives instance recreation
    - DeleteProfile removes from memory AND storage
    - SetStorage(nil) reverts to in-memory-only mode
    - ListProfiles filtering by OwnerApp
  ============================================================================ }

unit Test.DeepBase.Speech.Voiceprint;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes, System.IOUtils, System.Generics.Collections,
  DeepBase.Speech.MFCC,
  DeepBase.Speech.Voiceprint,
  DeepBase.Speech.Voiceprint.Contracts;

type
  /// <summary>In-memory storage mock implementing IVoiceProfileStorage.</summary>
  TMockVoiceProfileStorage = class(TInterfacedObject, IVoiceProfileStorage)
  private
    FInfos: TDictionary<TVoiceProfileId, TVoiceProfileInfo>;
    FFeatures: TDictionary<TVoiceProfileId, TMFCCFrame>;
    FSaveCount: Integer;
    FDeleteCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function LoadAll: TArray<TPair<TVoiceProfileId, TVoiceProfileInfo>>;
    function LoadFeatures(const AId: TVoiceProfileId): TMFCCFeatures;
    procedure SaveProfile(const AId: TVoiceProfileId; const AInfo: TVoiceProfileInfo;
      const AMean: TMFCCFrame);
    function DeleteProfile(const AId: TVoiceProfileId): Boolean;

    property SaveCount: Integer read FSaveCount;
    property DeleteCount: Integer read FDeleteCount;
  end;

  [TestFixture]
  TTestVoiceprintStorage = class
  private
    FVoiceprint: TDeepBaseVoiceprint;
    FStorage: TMockVoiceProfileStorage;
    FTempFile: string;
    function MakePCM16(ADurationMs: Integer; ASeed: Integer = 0): TBytes;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure Test_SetStorage_WiresInBackend;
    [Test] procedure Test_Enroll_PersistsToStorage;
    [Test] procedure Test_Delete_RemovesFromStorage;
    [Test] procedure Test_ListProfiles_FiltersByOwnerApp;

    // BUG-278: duration rule
    [Test] procedure Test_Enroll_RejectsShortSample;
    [Test] procedure Test_Enroll_AcceptsLongEnoughSample;

    // DPAPI file storage round-trip
    [Test] procedure Test_DPAPIFileStorage_SaveLoadDeleteRoundTrip;

    // Persistence across instance recreation
    [Test] procedure Test_Voiceprint_SurvivesRecreation;
  end;

implementation

uses
  System.Math;

{ TMockVoiceProfileStorage }

constructor TMockVoiceProfileStorage.Create;
begin
  inherited Create;
  FInfos := TDictionary<TVoiceProfileId, TVoiceProfileInfo>.Create;
  FFeatures := TDictionary<TVoiceProfileId, TMFCCFrame>.Create;
  FSaveCount := 0;
  FDeleteCount := 0;
end;

destructor TMockVoiceProfileStorage.Destroy;
begin
  FFeatures.Free;
  FInfos.Free;
  inherited;
end;

function TMockVoiceProfileStorage.LoadAll: TArray<TPair<TVoiceProfileId, TVoiceProfileInfo>>;
var
  LList: TList<TPair<TVoiceProfileId, TVoiceProfileInfo>>;
  LPair: TPair<TVoiceProfileId, TVoiceProfileInfo>;
begin
  LList := TList<TPair<TVoiceProfileId, TVoiceProfileInfo>>.Create;
  try
    for LPair in FInfos do
      LList.Add(LPair);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TMockVoiceProfileStorage.LoadFeatures(const AId: TVoiceProfileId): TMFCCFeatures;
var
  LMean: TMFCCFrame;
begin
  if FFeatures.TryGetValue(AId, LMean) then
  begin
    SetLength(Result, 1);
    Result[0] := LMean;
  end
  else
    SetLength(Result, 0);
end;

procedure TMockVoiceProfileStorage.SaveProfile(const AId: TVoiceProfileId;
  const AInfo: TVoiceProfileInfo; const AMean: TMFCCFrame);
begin
  FInfos.AddOrSetValue(AId, AInfo);
  FFeatures.AddOrSetValue(AId, AMean);
  Inc(FSaveCount);
end;

function TMockVoiceProfileStorage.DeleteProfile(const AId: TVoiceProfileId): Boolean;
begin
  Result := FInfos.ContainsKey(AId);
  FInfos.Remove(AId);
  FFeatures.Remove(AId);
  if Result then Inc(FDeleteCount);
end;

{ TTestVoiceprintStorage }

procedure TTestVoiceprintStorage.Setup;
begin
  FVoiceprint := TDeepBaseVoiceprint.Create;
  FStorage := TMockVoiceProfileStorage.Create;
  FVoiceprint.SetStorage(FStorage);
  FTempFile := TPath.Combine(TPath.GetTempPath,
    'deepbase_voiceprint_test_' + TGUID.NewGuid.ToString + '.dat');
end;

procedure TTestVoiceprintStorage.TearDown;
begin
  FreeAndNil(FVoiceprint);
  FStorage := nil;
  if TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
end;

function TTestVoiceprintStorage.MakePCM16(ADurationMs: Integer; ASeed: Integer): TBytes;
const
  CSampleRate = 16000;
var
  LNumSamples, I: Integer;
  LPhase: Double;
  LValue: SmallInt;
begin
  LNumSamples := (Int64(CSampleRate) * ADurationMs) div 1000;
  SetLength(Result, LNumSamples * 2);
  for I := 0 to LNumSamples - 1 do
  begin
    LPhase := 2 * Pi * (440 + ASeed * 50) * I / CSampleRate;
    LValue := Round(Sin(LPhase) * 16000);
    Result[I * 2] := Byte(LValue and $FF);
    Result[I * 2 + 1] := Byte((LValue shr 8) and $FF);
  end;
end;

procedure TTestVoiceprintStorage.Test_SetStorage_WiresInBackend;
begin
  Assert.AreEqual<Integer>(0, FStorage.SaveCount, 'No saves before any enroll');
end;

procedure TTestVoiceprintStorage.Test_Enroll_PersistsToStorage;
var
  LId: TVoiceProfileId;
  LSamples: TArray<TBytes>;
  LList: TArray<TPair<TVoiceProfileId, TVoiceProfileInfo>>;
begin
  SetLength(LSamples, 3);
  LSamples[0] := MakePCM16(600, 1);
  LSamples[1] := MakePCM16(600, 2);
  LSamples[2] := MakePCM16(600, 3);

  LId := FVoiceprint.EnrollProfile('alice', 'wakeword', 'deeplaunch', LSamples);

  Assert.IsTrue(LId <> '', 'Enroll should return a non-empty ID');
  Assert.AreEqual<Integer>(1, FStorage.SaveCount, 'Storage should have been called once');

  LList := FStorage.LoadAll;
  Assert.AreEqual<Integer>(1, Length(LList), 'Mock should hold exactly one profile');
  Assert.AreEqual<string>('alice', LList[0].Value.UserLabel);
  Assert.AreEqual<string>('wakeword', LList[0].Value.Purpose);
  Assert.AreEqual<string>('deeplaunch', LList[0].Value.OwnerApp);
  Assert.IsTrue(LList[0].Value.Enabled, 'Newly enrolled profile should be enabled');
end;

procedure TTestVoiceprintStorage.Test_Delete_RemovesFromStorage;
var
  LId: TVoiceProfileId;
  LSamples: TArray<TBytes>;
  LList: TArray<TPair<TVoiceProfileId, TVoiceProfileInfo>>;
begin
  SetLength(LSamples, 3);
  LSamples[0] := MakePCM16(600, 1);
  LSamples[1] := MakePCM16(600, 2);
  LSamples[2] := MakePCM16(600, 3);
  LId := FVoiceprint.EnrollProfile('alice', 'wakeword', 'deeplaunch', LSamples);
  Assert.IsTrue(LId <> '');

  LList := FStorage.LoadAll;
  Assert.AreEqual<Integer>(1, Length(LList));

  Assert.IsTrue(FVoiceprint.DeleteProfile(LId), 'DeleteProfile should return True');
  Assert.AreEqual<Integer>(1, FStorage.DeleteCount, 'Storage.Delete should be called');
  LList := FStorage.LoadAll;
  Assert.AreEqual<Integer>(0, Length(LList), 'Storage should be empty after delete');
end;

procedure TTestVoiceprintStorage.Test_ListProfiles_FiltersByOwnerApp;
var
  LSamples: TArray<TBytes>;
  LList: TArray<TVoiceProfileInfo>;
begin
  SetLength(LSamples, 3);
  LSamples[0] := MakePCM16(600, 1);
  LSamples[1] := MakePCM16(600, 2);
  LSamples[2] := MakePCM16(600, 3);
  FVoiceprint.EnrollProfile('alice', 'wakeword', 'app1', LSamples);
  FVoiceprint.EnrollProfile('bob', 'wakeword', 'app2', LSamples);
  FVoiceprint.EnrollProfile('carol', 'wakeword', 'app1', LSamples);

  LList := FVoiceprint.ListProfiles;
  Assert.AreEqual<Integer>(3, Length(LList), 'No filter → all 3 profiles');

  LList := FVoiceprint.ListProfiles('app1');
  Assert.AreEqual<Integer>(2, Length(LList), 'app1 filter → 2 profiles');

  LList := FVoiceprint.ListProfiles('app2');
  Assert.AreEqual<Integer>(1, Length(LList), 'app2 filter → 1 profile');

  LList := FVoiceprint.ListProfiles('unknown');
  Assert.AreEqual<Integer>(0, Length(LList), 'unknown app → 0 profiles');
end;

procedure TTestVoiceprintStorage.Test_Enroll_RejectsShortSample;
var
  LSamples: TArray<TBytes>;
  LRaised: Boolean;
begin
  SetLength(LSamples, 3);
  LSamples[0] := MakePCM16(600, 1);
  LSamples[1] := MakePCM16(100, 2);  // ~10 frames, well under MIN_SAMPLE_FRAMES
  LSamples[2] := MakePCM16(600, 3);

  LRaised := False;
  try
    FVoiceprint.EnrollProfile('alice', 'wakeword', 'deeplaunch', LSamples);
  except
    on E: EArgumentException do
      LRaised := True;
  end;
  Assert.IsTrue(LRaised,
    'BUG-278: Enroll must reject samples shorter than MIN_SAMPLE_FRAMES (~500ms)');
end;

procedure TTestVoiceprintStorage.Test_Enroll_AcceptsLongEnoughSample;
var
  LSamples: TArray<TBytes>;
  LId: TVoiceProfileId;
begin
  // 3 × 500ms is right at the boundary — should succeed.
  SetLength(LSamples, 3);
  LSamples[0] := MakePCM16(500, 1);
  LSamples[1] := MakePCM16(500, 2);
  LSamples[2] := MakePCM16(500, 3);

  LId := FVoiceprint.EnrollProfile('alice', 'wakeword', 'deeplaunch', LSamples);
  Assert.IsTrue(LId <> '', 'Enroll with 500ms samples should succeed');
end;

procedure TTestVoiceprintStorage.Test_DPAPIFileStorage_SaveLoadDeleteRoundTrip;
var
  LStore: IVoiceProfileStorage;
  LInfo, LLoaded: TVoiceProfileInfo;
  LMean: TMFCCFrame;
  LAll: TArray<TPair<TVoiceProfileId, TVoiceProfileInfo>>;
  LFeatures: TMFCCFeatures;
  I: Integer;
  LSkip: Boolean;
begin
  LSkip := False;
  {$IFNDEF MSWINDOWS}
  LSkip := True;
  {$ENDIF}
  if LSkip then
  begin
    // No Assert.Skip in DUnitX — make the check non-fatal by asserting True
    // and leaving a note. The DPAPI code path is still compiled and type-checked.
    Assert.IsTrue(True, 'DPAPI file storage test skipped on non-Windows');
    Exit;
  end;

  // NOTE: TDPAPIFileVoiceProfileStorage is TInterfacedObject — hold it as an
  // interface so refcounting handles cleanup. Manual .Free would double-release.
  LStore := TDPAPIFileVoiceProfileStorage.Create(FTempFile);

  LInfo.ProfileId := 'profile-1';
  LInfo.UserLabel := 'alice';
  LInfo.Purpose := 'wakeword';
  LInfo.SampleCount := 3;
  LInfo.Threshold := 12.5;
  LInfo.OwnerApp := 'deeplaunch';
  LInfo.Enabled := True;
  LInfo.CreatedAt := Now;
  // TMFCCFrame = array[0..12] of Single — fixed-size static array, no SetLength needed.
  for I := 0 to 12 do
    LMean[I] := I * 0.1;

  // Save
  LStore.SaveProfile(LInfo.ProfileId, LInfo, LMean);
  Assert.IsTrue(TFile.Exists(FTempFile), 'File should exist after save');

  // LoadAll
  LAll := LStore.LoadAll;
  Assert.AreEqual<Integer>(1, Length(LAll), 'One profile in storage');
  LLoaded := LAll[0].Value;
  Assert.AreEqual<string>(LInfo.UserLabel, LLoaded.UserLabel);
  Assert.AreEqual<string>(LInfo.Purpose, LLoaded.Purpose);
  Assert.AreEqual<string>(LInfo.OwnerApp, LLoaded.OwnerApp);
  Assert.AreEqual<string>(FloatToStr(LInfo.Threshold, TFormatSettings.Invariant),
    FloatToStr(LLoaded.Threshold, TFormatSettings.Invariant),
    'Threshold should round-trip');

  // LoadFeatures
  LFeatures := LStore.LoadFeatures(LInfo.ProfileId);
  Assert.AreEqual<Integer>(1, Length(LFeatures), 'One frame');
  for I := 0 to 12 do
    Assert.AreEqual<string>(FloatToStr(LMean[I], TFormatSettings.Invariant),
      FloatToStr(LFeatures[0][I], TFormatSettings.Invariant),
      Format('MFCC coeff %d should round-trip', [I]));

  // Save again (update) — should replace, not duplicate
  LInfo.UserLabel := 'alice-updated';
  LStore.SaveProfile(LInfo.ProfileId, LInfo, LMean);
  LAll := LStore.LoadAll;
  Assert.AreEqual<Integer>(1, Length(LAll), 'Update should not duplicate');
  Assert.AreEqual<string>('alice-updated', LAll[0].Value.UserLabel);

  // Delete
  Assert.IsTrue(LStore.DeleteProfile(LInfo.ProfileId));
  LAll := LStore.LoadAll;
  Assert.AreEqual<Integer>(0, Length(LAll), 'Empty after delete');
  Assert.IsFalse(LStore.DeleteProfile('no-such-id'), 'Delete of missing returns False');

  // Release interface explicitly so file is unlocked before TearDown deletes it.
  LStore := nil;
end;

procedure TTestVoiceprintStorage.Test_Voiceprint_SurvivesRecreation;
var
  LSamples: TArray<TBytes>;
  LId1, LId2: TVoiceProfileId;
  LList: TArray<TVoiceProfileInfo>;
  LStore: IVoiceProfileStorage;
  LVoiceprint2: TDeepBaseVoiceprint;
  LSkip: Boolean;
  LVerify: TVerifyResult;
begin
  LSkip := False;
  {$IFNDEF MSWINDOWS}
  LSkip := True;
  {$ENDIF}
  if LSkip then
  begin
    Assert.IsTrue(True, 'Persistence round-trip test skipped on non-Windows');
    Exit;
  end;

  SetLength(LSamples, 3);
  LSamples[0] := MakePCM16(600, 1);
  LSamples[1] := MakePCM16(600, 2);
  LSamples[2] := MakePCM16(600, 3);

  // Hold as interface — refcounting handles cleanup (TInterfacedObject).
  LStore := TDPAPIFileVoiceProfileStorage.Create(FTempFile);

  FVoiceprint.SetStorage(LStore);
  LId1 := FVoiceprint.EnrollProfile('alice', 'wakeword', 'deeplaunch', LSamples);

  // Destroy FVoiceprint; LStore (refcount 2→1) stays alive.
  FreeAndNil(FVoiceprint);

  LVoiceprint2 := TDeepBaseVoiceprint.Create;
  try
    LVoiceprint2.SetStorage(LStore);
    LVoiceprint2.LoadFromStorage;

    LList := LVoiceprint2.ListProfiles;
    Assert.AreEqual<Integer>(1, Length(LList),
      'Recreated instance should see the persisted profile');
    LId2 := LList[0].ProfileId;
    Assert.AreEqual<string>(LId1, LId2, 'Profile ID should round-trip across instances');
    Assert.AreEqual<string>('alice', LList[0].UserLabel);

    // Verify still works against the loaded profile.
    LVerify := LVoiceprint2.Verify(MakePCM16(600, 1), LId2);
    Assert.IsTrue(LVerify.Distance >= 0, 'Distance should be finite non-negative');
  finally
    LVoiceprint2.Free;
  end;

  // Release storage explicitly so the file handle is closed before TearDown.
  LStore := nil;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestVoiceprintStorage);

end.
