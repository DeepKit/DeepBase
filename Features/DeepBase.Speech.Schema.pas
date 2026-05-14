{ ============================================================================
  DeepBase.Speech.Schema
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : DDL for speech-related tables in ConfigDB.
                Tables: voice_profiles (声纹档案)
                Called during DeepBase.Manager initialization.
  ============================================================================ }

unit DeepBase.Speech.Schema;

interface

uses
  FireDAC.Comp.Client;

/// <summary>
/// Create speech tables if they don't exist. Safe to call repeatedly.
/// </summary>
procedure EnsureSpeechSchema(AConn: TFDConnection);

implementation

const
  SQL_CREATE_VOICE_PROFILES =
    'CREATE TABLE IF NOT EXISTS voice_profiles (' +
    '  profile_id TEXT PRIMARY KEY,' +
    '  user_label TEXT NOT NULL,' +
    '  purpose TEXT NOT NULL,' +
    '  sample_count INTEGER NOT NULL DEFAULT 0,' +
    '  features BLOB,' +
    '  features_hmac TEXT,' +
    '  threshold REAL NOT NULL DEFAULT 15.0,' +
    '  owner_app TEXT NOT NULL,' +
    '  feature_version INTEGER NOT NULL DEFAULT 1,' +
    '  created_at TEXT NOT NULL,' +
    '  updated_at TEXT NOT NULL,' +
    '  enabled INTEGER NOT NULL DEFAULT 1' +
    ')';

  SQL_IDX_VOICE_PROFILES_APP =
    'CREATE INDEX IF NOT EXISTS idx_voice_profiles_app ON voice_profiles(owner_app)';

  SQL_IDX_VOICE_PROFILES_PURPOSE =
    'CREATE INDEX IF NOT EXISTS idx_voice_profiles_purpose ON voice_profiles(purpose)';

  SQL_CREATE_SPEECH_CONFIG =
    'CREATE TABLE IF NOT EXISTS speech_config (' +
    '  key TEXT PRIMARY KEY,' +
    '  value TEXT NOT NULL,' +
    '  updated_at TEXT NOT NULL DEFAULT (datetime(''now''))' +
    ')';

procedure EnsureSpeechSchema(AConn: TFDConnection);
begin
  if AConn = nil then Exit;
  AConn.ExecSQL(SQL_CREATE_VOICE_PROFILES);
  AConn.ExecSQL(SQL_IDX_VOICE_PROFILES_APP);
  AConn.ExecSQL(SQL_IDX_VOICE_PROFILES_PURPOSE);
  AConn.ExecSQL(SQL_CREATE_SPEECH_CONFIG);
end;

end.
