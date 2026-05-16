unit DeepBase.IntentClarification.Rapport;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Math,
  System.Generics.Collections,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces;

type
  /// <summary>
  /// 融洽度层 - 维护每个用户的 TRapportProfile。
  /// 使用内存字典存储（SQLite 持久化在 Task 17.2 中实现）。
  /// Property 33: 所有 Double 字段在 [0.0, 1.0]，CommunicationStyle 在预定义集合中。
  /// Property 34: UpdateAfterSession 更新 LastUpdated。
  /// Property 35: 高 PreferredDepth → 更高初始深度；低 → 更低。
  /// Requirements: 11.1-11.5
  /// </summary>
  TRapportLayer = class
  private
    const
      CValidStyles: array[0..2] of string = ('direct', 'exploratory', 'empathetic');
      CDefaultDepth = 0.5;
    var
      FProfiles: TDictionary<string, TRapportProfile>;
      FLock: TCriticalSection;

    function ClampDouble(AValue: Double): Double;
    function IsValidStyle(const AStyle: string): Boolean;
    function SanitizeProfile(const AProfile: TRapportProfile): TRapportProfile;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Loads a profile for the given user. Returns default if not found.</summary>
    function LoadProfile(const AUserId: string): TRapportProfile;

    /// <summary>Saves a profile (validates and clamps fields before storing).</summary>
    procedure SaveProfile(const AProfile: TRapportProfile);

    /// <summary>
    /// Updates the user's rapport profile after a session completes.
    /// Always updates LastUpdated to Now.
    /// </summary>
    procedure UpdateAfterSession(const AUserId: string;
      const ASessionState: TSessionState);

    /// <summary>
    /// Returns the recommended initial depth for a user based on their PreferredDepth.
    /// High PreferredDepth → higher initial depth; low → lower.
    /// </summary>
    function GetInitialDepth(const AUserId: string): Double;

    /// <summary>Returns True if the user profile exists in memory.</summary>
    function HasProfile(const AUserId: string): Boolean;
  end;

implementation

{ TRapportLayer }

constructor TRapportLayer.Create;
begin
  inherited Create;
  FProfiles := TDictionary<string, TRapportProfile>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TRapportLayer.Destroy;
begin
  FProfiles.Free;
  FLock.Free;
  inherited;
end;

function TRapportLayer.ClampDouble(AValue: Double): Double;
begin
  Result := EnsureRange(AValue, 0.0, 1.0);
end;

function TRapportLayer.IsValidStyle(const AStyle: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := Low(CValidStyles) to High(CValidStyles) do
  begin
    if SameText(AStyle, CValidStyles[I]) then
      Exit(True);
  end;
end;

function TRapportLayer.SanitizeProfile(const AProfile: TRapportProfile): TRapportProfile;
begin
  Result := AProfile;
  // Property 33: clamp all Double fields to [0.0, 1.0]
  Result.TrustLevel := ClampDouble(Result.TrustLevel);
  Result.Familiarity := ClampDouble(Result.Familiarity);
  Result.PreferredDepth := ClampDouble(Result.PreferredDepth);

  // Property 33: CommunicationStyle must be in predefined set
  if not IsValidStyle(Result.CommunicationStyle) then
    Result.CommunicationStyle := 'direct';
end;

function TRapportLayer.LoadProfile(const AUserId: string): TRapportProfile;
begin
  // IC-022: protect FProfiles with FLock for concurrent access.
  FLock.Enter;
  try
    if FProfiles.TryGetValue(AUserId, Result) then
      Exit;
  finally
    FLock.Leave;
  end;

  // Return default profile for unknown users
  Result := Default(TRapportProfile);
  Result.UserId := AUserId;
  Result.TrustLevel := 0.5;
  Result.Familiarity := 0.0;
  Result.PreferredDepth := 0.5;
  Result.CommunicationStyle := 'direct';
  Result.LastUpdated := Now;
end;

procedure TRapportLayer.SaveProfile(const AProfile: TRapportProfile);
var
  LSanitized: TRapportProfile;
begin
  LSanitized := SanitizeProfile(AProfile);
  FLock.Enter;
  try
    FProfiles.AddOrSetValue(LSanitized.UserId, LSanitized);
  finally
    FLock.Leave;
  end;
end;

procedure TRapportLayer.UpdateAfterSession(const AUserId: string;
  const ASessionState: TSessionState);
var
  LProfile: TRapportProfile;
begin
  LProfile := LoadProfile(AUserId);

  // Increase familiarity slightly with each session
  LProfile.Familiarity := ClampDouble(LProfile.Familiarity + 0.05);

  // Adjust preferred depth based on session's actual depth usage
  LProfile.PreferredDepth := ClampDouble(
    LProfile.PreferredDepth * 0.8 + ASessionState.CurrentDepth * 0.2);

  // Increase trust slightly for completed sessions
  if ASessionState.Status = ssCompleted then
    LProfile.TrustLevel := ClampDouble(LProfile.TrustLevel + 0.02);

  // Property 34: always update LastUpdated
  LProfile.LastUpdated := Now;

  SaveProfile(LProfile);
end;

function TRapportLayer.GetInitialDepth(const AUserId: string): Double;
var
  LProfile: TRapportProfile;
begin
  LProfile := LoadProfile(AUserId);

  // Property 35: high PreferredDepth → higher initial depth; low → lower
  // Scale around the default (0.5) based on user preference
  Result := CDefaultDepth + (LProfile.PreferredDepth - 0.5) * 0.4;
  Result := EnsureRange(Result, 0.0, 1.0);
end;

function TRapportLayer.HasProfile(const AUserId: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FProfiles.ContainsKey(AUserId);
  finally
    FLock.Leave;
  end;
end;

end.
