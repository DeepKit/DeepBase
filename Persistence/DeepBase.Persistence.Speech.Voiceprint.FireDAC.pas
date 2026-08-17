{ ============================================================================
  DeepBase.Persistence.Speech.Voiceprint.FireDAC
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : FireDAC-backed IVoiceProfileStorage implementation.
                Uses the voice_profiles table from DeepBase.Speech.Schema
                (caller is responsible for calling EnsureSpeechSchema on the
                connection before using this storage, or for invoking it via
                TDBVoiceProfileStorage.Create which ensures the table lazily).

                Integrity: features BLOB is HMAC-SHA256 signed with a key
                derived from the owner_app. On read, a mismatch raises
                EDatabaseVoiceprintTampered so callers can surface an alert
                rather than silently accepting tampered biometric data.

                Thread safety: FireDAC TFDConnection is NOT thread safe;
                callers must either pin a connection per thread or serialize
                access externally. TDBVoiceProfileStorage itself is
                reentrant-safe only to the extent the underlying connection is.

                Lifecycle: the storage does NOT own the TFDConnection. Callers
                own it and must keep it alive longer than the storage.
  ============================================================================ }

unit DeepBase.Persistence.Speech.Voiceprint.FireDAC;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  DeepBase.Speech.MFCC,
  DeepBase.Speech.Voiceprint.Contracts;

type
  /// <summary>Raised when the on-disk features BLOB does not match the
  /// stored HMAC — indicates storage-level tampering or corruption.</summary>
  EDatabaseVoiceprintTampered = class(Exception);

  /// <summary>
  /// FireDAC-backed voice profile storage using the voice_profiles table
  /// (see DeepBase.Speech.Schema).
  /// </summary>
  TDBVoiceProfileStorage = class(TInterfacedObject, IVoiceProfileStorage)
  private
    FConnection: TFDConnection;
    FOwnerApp: string;
    procedure EnsureSchema;
    class function FramesToBytes(const AFeatures: TMFCCFeatures): TBytes; static;
    class function BytesToFrames(const ABytes: TBytes): TMFCCFeatures; static;
    class function DeriveHmacKey(const AOwnerApp: string): TBytes; static;
    class function ComputeHmac(const AKey, AData: TBytes): string; static;
  public
    /// <summary>Create a storage bound to <c>AConnection</c> and
    /// <c>AOwnerApp</c>. The connection is NOT owned; its lifetime must
    /// exceed that of the storage. Calls EnsureSpeechSchema lazily on
    /// first use.</summary>
    constructor Create(AConnection: TFDConnection; const AOwnerApp: string);

    function LoadAll: TArray<TPair<TVoiceProfileId, TVoiceProfileInfo>>;
    function LoadFeatures(const AId: TVoiceProfileId): TMFCCFeatures;
    procedure SaveProfile(const AId: TVoiceProfileId; const AInfo: TVoiceProfileInfo;
      const AMean: TMFCCFrame);
    function DeleteProfile(const AId: TVoiceProfileId): Boolean;
  end;

implementation

uses
  System.DateUtils,
  System.StrUtils,
  Data.DB,
  FireDAC.Stan.Param,
  FireDAC.DatS,
  DeepBase.Speech.Schema,
  DeepBase.Crypto, DeepBase.Crypto.Hash;

{ TDBVoiceProfileStorage }

constructor TDBVoiceProfileStorage.Create(AConnection: TFDConnection;
  const AOwnerApp: string);
begin
  inherited Create;
  if AConnection = nil then
    raise EArgumentException.Create(
      'TDBVoiceProfileStorage: connection must not be nil');
  if AOwnerApp = '' then
    raise EArgumentException.Create(
      'TDBVoiceProfileStorage: owner_app must not be empty');
  FConnection := AConnection;
  FOwnerApp := AOwnerApp;
end;

procedure TDBVoiceProfileStorage.EnsureSchema;
begin
  // Idempotent DDL; safe to call on every entry point.
  DeepBase.Speech.Schema.EnsureSpeechSchema(FConnection);
end;

class function TDBVoiceProfileStorage.DeriveHmacKey(
  const AOwnerApp: string): TBytes;
begin
  // Bind HMAC material to the owner_app so cross-app blob swaps fail.
  Result := THashUtils.HASHBytes(
    TEncoding.UTF8.GetBytes(AOwnerApp + #0'veoice_profiles_hmac_v1'),
    haSHA256);
end;

class function TDBVoiceProfileStorage.ComputeHmac(const AKey,
  AData: TBytes): string;
begin
  Result := THashUtils.HashToHex(
    THashUtils.HMAC(AKey, AData, haSHA256));
end;

class function TDBVoiceProfileStorage.FramesToBytes(
  const AFeatures: TMFCCFeatures): TBytes;
var
  LTotal, LOfs, I: Integer;
begin
  LTotal := Length(AFeatures) * SizeOf(TMFCCFrame);
  SetLength(Result, LTotal);
  LOfs := 0;
  for I := 0 to High(AFeatures) do
  begin
    Move(AFeatures[I][0], Result[LOfs], SizeOf(TMFCCFrame));
    Inc(LOfs, SizeOf(TMFCCFrame));
  end;
end;

class function TDBVoiceProfileStorage.BytesToFrames(
  const ABytes: TBytes): TMFCCFeatures;
var
  LFrameSize, LCount, LOfs, I: Integer;
begin
  LFrameSize := SizeOf(TMFCCFrame);
  if (Length(ABytes) = 0) or (Length(ABytes) mod LFrameSize <> 0) then
    raise EDatabaseVoiceprintTampered.Create(
      'Voiceprint storage: corrupted feature blob (size not a multiple of frame)');
  LCount := Length(ABytes) div LFrameSize;
  SetLength(Result, LCount);
  LOfs := 0;
  for I := 0 to LCount - 1 do
  begin
    Move(ABytes[LOfs], Result[I][0], LFrameSize);
    Inc(LOfs, LFrameSize);
  end;
end;

function TDBVoiceProfileStorage.LoadAll:
  TArray<TPair<TVoiceProfileId, TVoiceProfileInfo>>;
var
  LQry: TFDQuery;
  LList: TList<TPair<TVoiceProfileId, TVoiceProfileInfo>>;
  LInfo: TVoiceProfileInfo;
  LId: string;
begin
  EnsureSchema;
  LList := TList<TPair<TVoiceProfileId, TVoiceProfileInfo>>.Create;
  try
    LQry := TFDQuery.Create(nil);
    try
      LQry.Connection := FConnection;
      LQry.SQL.Text :=
        'SELECT profile_id, user_label, purpose, sample_count, threshold, ' +
        'owner_app, enabled, created_at FROM voice_profiles ' +
        'WHERE owner_app = :owner_app AND enabled <> 0';
      LQry.ParamByName('owner_app').AsString := FOwnerApp;
      LQry.Open;
      while not LQry.Eof do
      begin
        LId := LQry.FieldByName('profile_id').AsString;
        LInfo.ProfileId := LId;
        LInfo.UserLabel := LQry.FieldByName('user_label').AsString;
        LInfo.Purpose := LQry.FieldByName('purpose').AsString;
        LInfo.SampleCount := LQry.FieldByName('sample_count').AsInteger;
        LInfo.Threshold := LQry.FieldByName('threshold').AsFloat;
        LInfo.OwnerApp := LQry.FieldByName('owner_app').AsString;
        LInfo.Enabled := LQry.FieldByName('enabled').AsInteger <> 0;
        LInfo.CreatedAt := ISO8601ToDate(
        ReplaceStr(LQry.FieldByName('created_at').AsString, ' ', 'T'), False);
        LList.Add(TPair<TVoiceProfileId, TVoiceProfileInfo>.Create(LId, LInfo));
        LQry.Next;
      end;
    finally
      LQry.Free;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TDBVoiceProfileStorage.LoadFeatures(
  const AId: TVoiceProfileId): TMFCCFeatures;
var
  LQry: TFDQuery;
  LBytes: TBytes;
  LStoredHmac, LComputedHmac: string;
  LKey: TBytes;
begin
  SetLength(Result, 0);
  EnsureSchema;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := FConnection;
    LQry.SQL.Text :=
      'SELECT features, features_hmac FROM voice_profiles ' +
      'WHERE profile_id = :id AND owner_app = :owner_app';
    LQry.ParamByName('id').AsString := AId;
    LQry.ParamByName('owner_app').AsString := FOwnerApp;
    LQry.Open;
    if LQry.IsEmpty then
      Exit;

    if LQry.FieldByName('features').IsNull then
      Exit;

    // Read the BLOB via TField.AsBytes — simpler than CreateBlobStream and
    // driver-agnostic (works for SQLite and PostgreSQL backends).
    LBytes := LQry.FieldByName('features').AsBytes;

    // Integrity check: if a stored HMAC is present, recompute and compare.
    LStoredHmac := LQry.FieldByName('features_hmac').AsString;
    if LStoredHmac <> '' then
    begin
      LKey := DeriveHmacKey(FOwnerApp);
      LComputedHmac := ComputeHmac(LKey, LBytes);
      if not SameText(LStoredHmac, LComputedHmac) then
        raise EDatabaseVoiceprintTampered.CreateFmt(
          'Voiceprint features HMAC mismatch for profile "%s" (owner="%s")',
          [AId, FOwnerApp]);
    end;

    Result := BytesToFrames(LBytes);
  finally
    LQry.Free;
  end;
end;

procedure TDBVoiceProfileStorage.SaveProfile(const AId: TVoiceProfileId;
  const AInfo: TVoiceProfileInfo; const AMean: TMFCCFrame);
var
  LFeatures: TMFCCFeatures;
  LBytes: TBytes;
  LHmac: string;
  LKey: TBytes;
  LQry: TFDQuery;
  LIsUpdate: Boolean;
begin
  EnsureSchema;

  // 1. Serialize features (AMean is a single TMFCCFrame).
  SetLength(LFeatures, 1);
  LFeatures[0] := AMean;
  LBytes := FramesToBytes(LFeatures);

  LKey := DeriveHmacKey(FOwnerApp);
  LHmac := ComputeHmac(LKey, LBytes);

  // 2. Try an UPDATE first. If the row exists, created_at is preserved
  //    automatically because UPDATE does not touch it.
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := FConnection;
    LQry.SQL.Text :=
      'UPDATE voice_profiles SET ' +
      '  user_label = :user_label, purpose = :purpose, ' +
      '  sample_count = :sample_count, features = :features, ' +
      '  features_hmac = :hmac, threshold = :threshold, ' +
      '  updated_at = :updated_at, enabled = :enabled ' +
      'WHERE profile_id = :id AND owner_app = :owner_app';
    LQry.ParamByName('id').AsString := AId;
    LQry.ParamByName('owner_app').AsString := FOwnerApp;
    LQry.ParamByName('user_label').AsString := AInfo.UserLabel;
    LQry.ParamByName('purpose').AsString := AInfo.Purpose;
    LQry.ParamByName('sample_count').AsInteger := AInfo.SampleCount;
    var LStream := TMemoryStream.Create;
    try
      LStream.WriteBuffer(Pointer(LBytes)^, Length(LBytes));
      LStream.Position := 0;
      LQry.ParamByName('features').LoadFromStream(LStream, ftBlob);
    finally
      LStream.Free;
    end;
    LQry.ParamByName('hmac').AsString := LHmac;
    LQry.ParamByName('threshold').AsFloat := AInfo.Threshold;
    LQry.ParamByName('updated_at').AsString :=
      FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz', Now);
    LQry.ParamByName('enabled').AsInteger := Ord(AInfo.Enabled);
    LQry.ExecSQL;
    LIsUpdate := LQry.RowsAffected > 0;

    if not LIsUpdate then
    begin
      // 3. Row didn't exist — INSERT with a fresh created_at.
      LQry.SQL.Text :=
        'INSERT INTO voice_profiles (' +
        '  profile_id, user_label, purpose, sample_count, features, ' +
        '  features_hmac, threshold, owner_app, feature_version, ' +
        '  created_at, updated_at, enabled' +
        ') VALUES (' +
        '  :id, :user_label, :purpose, :sample_count, :features, ' +
        '  :hmac, :threshold, :owner_app, 1, ' +
        '  :created_at, :updated_at, :enabled' +
        ')';
      LQry.ParamByName('id').AsString := AId;
      LQry.ParamByName('user_label').AsString := AInfo.UserLabel;
      LQry.ParamByName('purpose').AsString := AInfo.Purpose;
      LQry.ParamByName('sample_count').AsInteger := AInfo.SampleCount;
      LStream := TMemoryStream.Create;
      try
        LStream.WriteBuffer(Pointer(LBytes)^, Length(LBytes));
        LStream.Position := 0;
        LQry.ParamByName('features').LoadFromStream(LStream, ftBlob);
      finally
        LStream.Free;
      end;
      LQry.ParamByName('hmac').AsString := LHmac;
      LQry.ParamByName('threshold').AsFloat := AInfo.Threshold;
      LQry.ParamByName('owner_app').AsString := FOwnerApp;
      LQry.ParamByName('created_at').AsString :=
        FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz', Now);
      LQry.ParamByName('updated_at').AsString :=
        FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz', Now);
      LQry.ParamByName('enabled').AsInteger := Ord(AInfo.Enabled);
      LQry.ExecSQL;
    end;
  finally
    LQry.Free;
  end;
end;

function TDBVoiceProfileStorage.DeleteProfile(
  const AId: TVoiceProfileId): Boolean;
var
  LQry: TFDQuery;
begin
  EnsureSchema;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := FConnection;
    LQry.SQL.Text := 'DELETE FROM voice_profiles ' +
      'WHERE profile_id = :id AND owner_app = :owner_app';
    LQry.ParamByName('id').AsString := AId;
    LQry.ParamByName('owner_app').AsString := FOwnerApp;
    LQry.ExecSQL;
    Result := LQry.RowsAffected > 0;
  finally
    LQry.Free;
  end;
end;

end.
