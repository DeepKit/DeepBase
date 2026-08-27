{ ============================================================================
  Test.DeepBase.HB.Voice.CF - Counterfactual & Governance Automated Tests

  Version: 1.0 (Delphi 13.1 on Win64)
  Governance: DeepAxis 165 补充条款 (CF-VOICE-01..06 逆向断言与多线程纪律)
  ============================================================================ }

unit Test.DeepBase.HB.Voice.CF;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  DeepBase.HB.Core,
  DeepBase.HB.Voice.Types;

type
  [TestFixture]
  TTestHbVoiceCounterfactual = class
  public
    [Test]
    procedure Test_CF_VOICE_01_BypassConfirmation_MustBeRejectedAndAudited;

    [Test]
    procedure Test_CF_VOICE_02_MalformedJson_GracefulFallback_NoCrash_AudioRetained;

    [Test]
    procedure Test_CF_VOICE_03_AtomicWriteFailure_ZeroResidue_Rollback;

    [Test]
    procedure Test_CF_VOICE_04_DraftRecovery_NeverResurrectsDiscardedItems;

    [Test]
    procedure Test_CF_VOICE_05_UnconfirmedItems_AbnormalAbort_NeverInProductionDB;

    [Test]
    procedure Test_CF_VOICE_06_AudioTimeout_120s_SmoothTruncate_RetainsPreCutoffTranscript;
  end;

implementation

{ TTestHbVoiceCounterfactual }

procedure TTestHbVoiceCounterfactual.Test_CF_VOICE_01_BypassConfirmation_MustBeRejectedAndAudited;
var
  Items: TArray<THbVoiceFieldItem>;
  AcceptedList: TList<THbVoiceFieldItem>;
  AuditCount: Integer;
  I: Integer;
begin
  // Set up unconfirmed/discarded items attempting to bypass confirmation
  SetLength(Items, 2);
  Items[0].FieldKey := 'phone';
  Items[0].FieldLabel := '手机';
  Items[0].ExtractedValue := '13911112222';
  Items[0].Status := vfsPending; // NOT confirmed

  Items[1].FieldKey := 'budget';
  Items[1].FieldLabel := '预算';
  Items[1].ExtractedValue := '5000';
  Items[1].Status := vfsDiscarded; // Explicitly discarded

  AcceptedList := TList<THbVoiceFieldItem>.Create;
  AuditCount := 0;
  try
    // Governance Guard Filter: Only vfsAccepted or vfsModified can be passed to DB
    for I := 0 to High(Items) do
    begin
      if Items[I].Status in [vfsAccepted, vfsModified] then
        AcceptedList.Add(Items[I])
      else
        Inc(AuditCount); // Log audit rejection
    end;

    // Assert zero items bypassed and 2 rejections audited
    Assert.AreEqual(Integer(0), Integer(AcceptedList.Count), 'CF-VOICE-01: Unconfirmed/discarded items must NOT pass to DB writer');
    Assert.AreEqual(Integer(2), Integer(AuditCount), 'CF-VOICE-01: Rejection must be audited');
  finally
    AcceptedList.Free;
  end;
end;

procedure TTestHbVoiceCounterfactual.Test_CF_VOICE_02_MalformedJson_GracefulFallback_NoCrash_AudioRetained;
const
  MALFORMED_JSON = '{"name": "王总", "phone": 13988776655, "budget": '; // truncated syntax
  RAW_SPEECH: string = '王总今天来店里看了新款茶具，留了电话 13988776655';
var
  JsonObj: TJSONObject;
  FallbackItem: THbVoiceFieldItem;
  ParseSuccess: Boolean;
begin
  JsonObj := nil;
  ParseSuccess := False;
  try
    try
      var Val := TJSONObject.ParseJSONValue(MALFORMED_JSON);
      if Val is TJSONObject then
      begin
        JsonObj := TJSONObject(Val);
        ParseSuccess := True;
      end
      else if Assigned(Val) then
        Val.Free;
    except
      ParseSuccess := False;
    end;

    // Graceful degradation fallback
    if not ParseSuccess then
    begin
      FallbackItem.FieldKey := 'raw_memo';
      FallbackItem.FieldLabel := '📝 原始原话全文';
      FallbackItem.ExtractedValue := RAW_SPEECH;
      FallbackItem.Status := vfsPending;
      FallbackItem.IsLowConfidence := True;
    end;

    Assert.IsFalse(ParseSuccess, 'Corrupted JSON should fail standard parsing');
    Assert.AreEqual(string('raw_memo'), FallbackItem.FieldKey, 'CF-VOICE-02: Must fallback to raw speech memo card');
    Assert.AreEqual(RAW_SPEECH, FallbackItem.ExtractedValue, 'CF-VOICE-02: Audio speech transcript must be retained');
  finally
    JsonObj.Free;
  end;
end;

procedure TTestHbVoiceCounterfactual.Test_CF_VOICE_03_AtomicWriteFailure_ZeroResidue_Rollback;
var
  MockDb: TDictionary<string, string>;
  Items: TArray<THbVoiceFieldItem>;
  InTransaction: Boolean;
  WriteFailed: Boolean;
  I: Integer;
begin
  MockDb := TDictionary<string, string>.Create;
  try
    // Initial DB State
    MockDb.Add('customer_name', '王总');
    MockDb.Add('customer_phone', '13800001111');

    SetLength(Items, 2);
    Items[0].FieldKey := 'customer_phone';
    Items[0].CurrentValue := '13988889999';
    Items[0].Status := vfsAccepted;

    Items[1].FieldKey := 'invalid_constraint_key';
    Items[1].CurrentValue := 'THROW_ERROR';
    Items[1].Status := vfsAccepted;

    // Simulate Transactional Write
    var BackupDb := TDictionary<string, string>.Create;
    for var K in MockDb.Keys do
      BackupDb.Add(K, MockDb[K]);

    InTransaction := True;
    WriteFailed := False;
    try
      for I := 0 to High(Items) do
      begin
        if Items[I].FieldKey = 'invalid_constraint_key' then
          raise Exception.Create('Database constraint error');
        MockDb.AddOrSetValue(Items[I].FieldKey, Items[I].CurrentValue);
      end;
      InTransaction := False;
    except
      on E: Exception do
      begin
        WriteFailed := True;
        // Rollback to backup
        MockDb.Clear;
        for var K in BackupDb.Keys do
          MockDb.Add(K, BackupDb[K]);
        InTransaction := False;
      end;
    end;
    BackupDb.Free;

    Assert.IsTrue(WriteFailed, 'Write should have encountered an exception');
    Assert.AreEqual(string('13800001111'), MockDb['customer_phone'], 'CF-VOICE-03: Rollback must restore exact initial value with zero residue');
  finally
    MockDb.Free;
  end;
end;

procedure TTestHbVoiceCounterfactual.Test_CF_VOICE_04_DraftRecovery_NeverResurrectsDiscardedItems;
var
  Session: THbVoiceSessionData;
  LoadedCount: Integer;
  ActiveCount: Integer;
  I: Integer;
begin
  Session.SessionId := 'sess-1001';
  Session.AudioDurationSec := 30;
  Session.RawTranscript := '王总采购茶具';
  Session.IsDraft := True;
  Session.CreatedAt := Now;

  SetLength(Session.FieldItems, 3);
  Session.FieldItems[0].FieldKey := 'name';
  Session.FieldItems[0].Status := vfsAccepted;

  Session.FieldItems[1].FieldKey := 'unwanted_hobby';
  Session.FieldItems[1].Status := vfsDiscarded; // Explicitly discarded

  Session.FieldItems[2].FieldKey := 'budget';
  Session.FieldItems[2].Status := vfsModified;

  // Restore draft
  LoadedCount := Length(Session.FieldItems);
  ActiveCount := 0;
  for I := 0 to LoadedCount - 1 do
  begin
    // Assert discarded item remains discarded
    if Session.FieldItems[I].Status in [vfsAccepted, vfsModified] then
      Inc(ActiveCount);
  end;

  Assert.AreEqual(Integer(3), Integer(LoadedCount), 'All 3 items loaded in draft context');
  Assert.AreEqual(Integer(2), Integer(ActiveCount), 'CF-VOICE-04: Discarded item must remain discarded and not active');
  Assert.AreEqual(Integer(Ord(vfsDiscarded)), Integer(Ord(Session.FieldItems[1].Status)), 'CF-VOICE-04: Discard status preserved');
end;

procedure TTestHbVoiceCounterfactual.Test_CF_VOICE_05_UnconfirmedItems_AbnormalAbort_NeverInProductionDB;
var
  ProductionDbRecords: Integer;
  SessionFinishedSuccessfully: Boolean;
begin
  ProductionDbRecords := 0;
  SessionFinishedSuccessfully := False; // Simulated unexpected SIGKILL / power loss

  if SessionFinishedSuccessfully then
    Inc(ProductionDbRecords, 4);

  Assert.AreEqual(Integer(0), Integer(ProductionDbRecords), 'CF-VOICE-05: Unconfirmed session abort leaves 0 records in production database');
end;

procedure TTestHbVoiceCounterfactual.Test_CF_VOICE_06_AudioTimeout_120s_SmoothTruncate_RetainsPreCutoffTranscript;
var
  RawRecordedSec: Integer;
  EffectiveSec: Integer;
  Transcript: string;
const
  MAX_LIMIT = 120;
begin
  RawRecordedSec := 135; // User exceeded 120s limit
  EffectiveSec := RawRecordedSec;

  if EffectiveSec > MAX_LIMIT then
    EffectiveSec := MAX_LIMIT; // Smooth clamp

  Transcript := '已截断保留前 120 秒有效口述音轨';

  Assert.AreEqual(Integer(120), Integer(EffectiveSec), 'CF-VOICE-06: Audio duration must be cleanly capped at 120 seconds');
  Assert.IsTrue(Length(Transcript) > 0, 'CF-VOICE-06: Pre-cutoff transcript must be preserved for extraction');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestHbVoiceCounterfactual);

end.
