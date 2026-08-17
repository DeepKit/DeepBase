{ ============================================================================
  Test.DeepBase.Persistence.Speech.Voiceprint.FireDAC
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : DUnitX regression tests for TDBVoiceProfileStorage (the
                FireDAC/voice_profiles implementation of IVoiceProfileStorage).
                Uses an in-memory SQLite connection; no disk I/O, no DPAPI.
  ============================================================================ }

unit Test.DeepBase.Persistence.Speech.Voiceprint.FireDAC;

interface

{$IFDEF MSWINDOWS}

uses
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Phys.SQLite,
  FireDAC.Stan.Param,
  DeepBase.Speech.MFCC,
  DeepBase.Speech.Voiceprint.Contracts,
  DeepBase.Persistence.Speech.Voiceprint.FireDAC;

type
  [TestFixture]
  TTestDBVoiceProfileStorage = class
  private
    FConn: TFDConnection;
    FStorage: TDBVoiceProfileStorage;
    function MakeMean(Seed: Single): TMFCCFrame;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_LoadAll_EmptyTable_ReturnsEmptyArray;
    [Test]
    procedure Test_SaveProfile_ThenLoadAll_RoundTrips;
    [Test]
    procedure Test_SaveProfile_ThenLoadFeatures_RoundTrips;
    [Test]
    procedure Test_LoadFeatures_UnknownId_ReturnsEmpty;
    [Test]
    procedure Test_DeleteProfile_ExistingRow_ReturnsTrue;
    [Test]
    procedure Test_DeleteProfile_UnknownId_ReturnsFalse;
    [Test]
    procedure Test_SaveProfile_UpdateExisting_PreservesCreatedAt;
    [Test]
    procedure Test_OwnerApp_Isolation;
    [Test]
    procedure Test_TamperedFeatures_HmacMismatch_Raises;
    [Test]
    procedure Test_Ctor_NilConnection_Raises;
    [Test]
    procedure Test_Ctor_EmptyOwnerApp_Raises;
  end;

{$ENDIF}

implementation

{$IFDEF MSWINDOWS}

uses
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.DatS,
  FireDAC.Comp.Script,
  FireDAC.Comp.ScriptCommands;

{ TTestDBVoiceProfileStorage }

procedure TTestDBVoiceProfileStorage.Setup;
begin
  FConn := TFDConnection.Create(nil);
  FConn.DriverName := 'SQLite';
  FConn.Params.Database := ':memory:';
  FConn.LoginPrompt := False;
  FConn.Connected := True;
  FStorage := TDBVoiceProfileStorage.Create(FConn, 'com.deepbase.tests');
end;

procedure TTestDBVoiceProfileStorage.TearDown;
begin
  FStorage.Free;
  FConn.Free;
end;

function TTestDBVoiceProfileStorage.MakeMean(Seed: Single): TMFCCFrame;
var
  I: Integer;
begin
  for I := 0 to 12 do
    Result[I] := Seed + I * 0.1;
end;

procedure TTestDBVoiceProfileStorage.Test_LoadAll_EmptyTable_ReturnsEmptyArray;
var
  LResult: TArray<TPair<TVoiceProfileId, TVoiceProfileInfo>>;
begin
  LResult := FStorage.LoadAll;
  Assert.AreEqual<Integer>(0, Length(LResult),
    'Empty voice_profiles must yield an empty LoadAll result');
end;

procedure TTestDBVoiceProfileStorage.Test_SaveProfile_ThenLoadAll_RoundTrips;
var
  LId: TVoiceProfileId;
  LInfo, LLoaded: TVoiceProfileInfo;
  LResult: TArray<TPair<TVoiceProfileId, TVoiceProfileInfo>>;
  LFound: Boolean;
  LPair: TPair<TVoiceProfileId, TVoiceProfileInfo>;
begin
  LId := 'profile-001';
  LInfo.ProfileId := LId;
  LInfo.UserLabel := 'Alice';
  LInfo.Purpose := 'wake-word';
  LInfo.SampleCount := 5;
  LInfo.Threshold := 12.5;
  LInfo.OwnerApp := 'com.deepbase.tests';
  LInfo.Enabled := True;
  LInfo.CreatedAt := Now;

  FStorage.SaveProfile(LId, LInfo, MakeMean(1.0));

  LResult := FStorage.LoadAll;
  Assert.AreEqual<Integer>(1, Length(LResult),
    'After SaveProfile, LoadAll must return exactly one row');

  LFound := False;
  for LPair in LResult do
    if LPair.Key = LId then
    begin
      LLoaded := LPair.Value;
      LFound := True;
      Break;
    end;
  Assert.IsTrue(LFound, 'Saved profile_id must appear in LoadAll result');
  Assert.AreEqual(LInfo.UserLabel, LLoaded.UserLabel);
  Assert.AreEqual(LInfo.Purpose, LLoaded.Purpose);
  Assert.AreEqual(LInfo.SampleCount, LLoaded.SampleCount);
  Assert.AreEqual(LInfo.OwnerApp, LLoaded.OwnerApp);
  Assert.IsTrue(LLoaded.Enabled);
  Assert.AreEqual(Double(LInfo.Threshold), Double(LLoaded.Threshold), 1e-9);
end;

procedure TTestDBVoiceProfileStorage.Test_SaveProfile_ThenLoadFeatures_RoundTrips;
var
  LId: TVoiceProfileId;
  LInfo: TVoiceProfileInfo;
  LMean, LLoaded: TMFCCFrame;
  LFeatures: TMFCCFeatures;
  I: Integer;
begin
  LId := 'profile-002';
  LInfo.ProfileId := LId;
  LInfo.UserLabel := 'Bob';
  LInfo.Purpose := 'wake-word';
  LInfo.SampleCount := 3;
  LInfo.Threshold := 15.0;
  LInfo.OwnerApp := 'com.deepbase.tests';
  LInfo.Enabled := True;
  LInfo.CreatedAt := Now;
  LMean := MakeMean(2.5);

  FStorage.SaveProfile(LId, LInfo, LMean);

  LFeatures := FStorage.LoadFeatures(LId);
  Assert.AreEqual<Integer>(1, Length(LFeatures),
    'Saved mean (1 frame) must round-trip as a 1-element TMFCCFeatures');
  LLoaded := LFeatures[0];
  for I := 0 to 12 do
    Assert.AreEqual(Double(LMean[I]), Double(LLoaded[I]), 1e-5,
      Format('Coefficient[%d] must match saved mean', [I]));
end;

procedure TTestDBVoiceProfileStorage.Test_LoadFeatures_UnknownId_ReturnsEmpty;
var
  LFeatures: TMFCCFeatures;
begin
  LFeatures := FStorage.LoadFeatures('no-such-id');
  Assert.AreEqual<Integer>(0, Length(LFeatures),
    'Unknown profile_id must return an empty TMFCCFeatures array');
end;

procedure TTestDBVoiceProfileStorage.Test_DeleteProfile_ExistingRow_ReturnsTrue;
var
  LId: TVoiceProfileId;
  LInfo: TVoiceProfileInfo;
begin
  LId := 'profile-003';
  LInfo.ProfileId := LId;
  LInfo.UserLabel := 'Charlie';
  LInfo.Purpose := 'wake-word';
  LInfo.SampleCount := 4;
  LInfo.Threshold := 14.0;
  LInfo.OwnerApp := 'com.deepbase.tests';
  LInfo.Enabled := True;
  LInfo.CreatedAt := Now;
  FStorage.SaveProfile(LId, LInfo, MakeMean(0.0));

  Assert.IsTrue(FStorage.DeleteProfile(LId),
    'DeleteProfile on an existing row must return True');
  Assert.AreEqual<Integer>(0, Length(FStorage.LoadAll),
    'After DeleteProfile, LoadAll must be empty');
end;

procedure TTestDBVoiceProfileStorage.Test_DeleteProfile_UnknownId_ReturnsFalse;
begin
  Assert.IsFalse(FStorage.DeleteProfile('no-such-id'),
    'DeleteProfile on unknown id must return False');
end;

procedure TTestDBVoiceProfileStorage.Test_SaveProfile_UpdateExisting_PreservesCreatedAt;
var
  LId: TVoiceProfileId;
  LInfo, LLoaded: TVoiceProfileInfo;
  LResult: TArray<TPair<TVoiceProfileId, TVoiceProfileInfo>>;
  LPair: TPair<TVoiceProfileId, TVoiceProfileInfo>;
  LOriginalCreated: TDateTime;
  LPair2: TPair<TVoiceProfileId, TVoiceProfileInfo>;
begin
  LId := 'profile-004';
  LInfo.ProfileId := LId;
  LInfo.UserLabel := 'Dana';
  LInfo.Purpose := 'wake-word';
  LInfo.SampleCount := 2;
  LInfo.Threshold := 16.0;
  LInfo.OwnerApp := 'com.deepbase.tests';
  LInfo.Enabled := True;
  // created_at is set by the implementation on first insert — we ignore
  // whatever the caller passes in. Read back the real DB value after save.
  LInfo.CreatedAt := EncodeDateTime(2024, 1, 15, 10, 30, 0, 0);

  FStorage.SaveProfile(LId, LInfo, MakeMean(0.0));

  // Capture the real created_at from the DB (the implementation uses Now
  // on insert, not AInfo.CreatedAt).
  LResult := FStorage.LoadAll;
  Assert.AreEqual<Integer>(1, Length(LResult));
  for LPair2 in LResult do
    if LPair2.Key = LId then
      LOriginalCreated := LPair2.Value.CreatedAt;

  // Update user_label and sample_count.
  LInfo.UserLabel := 'Dana (updated)';
  LInfo.SampleCount := 7;
  FStorage.SaveProfile(LId, LInfo, MakeMean(0.5));

  LResult := FStorage.LoadAll;
  Assert.AreEqual<Integer>(1, Length(LResult));
  for LPair in LResult do
    if LPair.Key = LId then
      LLoaded := LPair.Value;

  Assert.AreEqual('Dana (updated)', LLoaded.UserLabel,
    'Update must overwrite user_label');
  Assert.AreEqual(7, LLoaded.SampleCount,
    'Update must overwrite sample_count');
  // created_at preservation is second-precision (SQLite datetime('now')).
  // EncodeDateTime carries ms; SQLite truncates to seconds. Compare as Double
  // with a 1-second tolerance to cover the rounding window.
  Assert.AreEqual(Double(LOriginalCreated), Double(LLoaded.CreatedAt),
    1 / SecsPerDay,
    'created_at must be preserved across updates');
end;

procedure TTestDBVoiceProfileStorage.Test_OwnerApp_Isolation;
var
  LOther: TDBVoiceProfileStorage;
  LId: TVoiceProfileId;
  LInfo: TVoiceProfileInfo;
  LFeatures: TMFCCFeatures;
begin
  // Second storage bound to a different owner_app on the same connection.
  LOther := TDBVoiceProfileStorage.Create(FConn, 'com.deepbase.other');
  try
    LId := 'profile-iso-1';
    LInfo.ProfileId := LId;
    LInfo.UserLabel := 'Isolated';
    LInfo.Purpose := 'wake-word';
    LInfo.SampleCount := 3;
    LInfo.Threshold := 15.0;
    LInfo.OwnerApp := 'com.deepbase.tests';
    LInfo.Enabled := True;
    LInfo.CreatedAt := Now;
    FStorage.SaveProfile(LId, LInfo, MakeMean(0.0));

    // Other owner_app must NOT see this row.
    Assert.AreEqual<Integer>(0, Length(LOther.LoadAll),
      'Storage bound to a different owner_app must see no rows');
    LFeatures := LOther.LoadFeatures(LId);
    Assert.AreEqual<Integer>(0, Length(LFeatures),
      'Storage bind to a different owner_app must return empty features');

    // And delete against the wrong owner_app must not affect the row.
    Assert.IsFalse(LOther.DeleteProfile(LId),
      'DeleteProfile against wrong owner_app must return False');
    Assert.AreEqual<Integer>(1, Length(FStorage.LoadAll),
      'Original row must survive cross-owner delete attempt');
  finally
    LOther.Free;
  end;
end;

procedure TTestDBVoiceProfileStorage.Test_TamperedFeatures_HmacMismatch_Raises;
var
  LQry: TFDQuery;
  LId: TVoiceProfileId;
  LInfo: TVoiceProfileInfo;
begin
  LId := 'profile-tamper';
  LInfo.ProfileId := LId;
  LInfo.UserLabel := 'Tamper';
  LInfo.Purpose := 'wake-word';
  LInfo.SampleCount := 3;
  LInfo.Threshold := 15.0;
  LInfo.OwnerApp := 'com.deepbase.tests';
  LInfo.Enabled := True;
  LInfo.CreatedAt := Now;
  FStorage.SaveProfile(LId, LInfo, MakeMean(0.0));

  // Directly overwrite the BLOB, leaving the stored HMAC unchanged.
  // The HMAC check inside LoadFeatures must then raise.
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := FConn;
    LQry.SQL.Text :=
      'UPDATE voice_profiles SET features = :b WHERE profile_id = :id';
    with LQry.ParamByName('b') do
    begin
      DataType := ftBlob;
      AsBlob := RawByteString('tampered-bytes');
    end;
    LQry.ParamByName('id').AsString := LId;
    LQry.ExecSQL;
  finally
    LQry.Free;
  end;

  Assert.WillRaise(
    procedure
    begin
      FStorage.LoadFeatures(LId);
    end,
    EDatabaseVoiceprintTampered);
end;

procedure TTestDBVoiceProfileStorage.Test_Ctor_NilConnection_Raises;
begin
  Assert.WillRaise(
    procedure
    begin
      TDBVoiceProfileStorage.Create(nil, 'com.deepbase.tests').Free;
    end,
    EArgumentException);
end;

procedure TTestDBVoiceProfileStorage.Test_Ctor_EmptyOwnerApp_Raises;
begin
  Assert.WillRaise(
    procedure
    begin
      TDBVoiceProfileStorage.Create(FConn, '').Free;
    end,
    EArgumentException);
end;

{$ENDIF}

initialization
{$IFDEF MSWINDOWS}
  TDUnitX.RegisterTestFixture(TTestDBVoiceProfileStorage);
{$ENDIF}

end.
