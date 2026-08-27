{ ============================================================================
  DeepBase.VCL.DeepShell.Localization

  Default IShellLocalizationService implementation. Stores text key /
  default mappings per locale. Adapters (e.g. backed by DeepBase.i18n) can
  replace this implementation through ServiceRegistry.
  ============================================================================ }

unit DeepBase.VCL.DeepShell.Localization;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  DeepBase.VCL.DeepShell.Intf;

/// <summary>
/// Detect the user's preferred locale from Windows. Falls back to en-US
/// when the system call returns nothing usable. Exposed so callers can
/// pass its return value as the constructor's ADefaultLocale instead of
/// hard-coding 'en-US'.
/// </summary>
function DetectSystemLocale: string;

type
  TShellDefaultLocalizationService = class(TInterfacedObject, IShellLocalizationService)
  private
    type
      TSub = record
        Token: string;
        Handler: TShellLocaleChangedHandler;
      end;
  private
    FLock: TCriticalSection;
    FLocale: string;
    FLocales: TList<string>;
    // locale -> (key -> text)
    FTexts: TObjectDictionary<string, TDictionary<string, string>>;
    FSubs: TList<TSub>;
    FNextToken: Int64;
    function EnsureLocaleBucket(const ALocale: string): TDictionary<string, string>;
  public
    constructor Create(const ADefaultLocale: string = 'en-US');
    destructor Destroy; override;

    /// <summary>
    /// Bulk register text for a locale. Call during shell initialisation.
    /// </summary>
    procedure RegisterText(const ALocale, AKey, AText: string);
    procedure RegisterLocale(const ALocale: string);

    // IShellLocalizationService
    function Text(const AKey, ADefault: string): string;
    function CurrentLocale: string;
    procedure SetLocale(const ALocale: string);
    function GetLocales: TArray<string>;
    function OnLocaleChanged(AHandler: TShellLocaleChangedHandler): string;
    procedure RemoveLocaleChanged(const AToken: string);
  end;

implementation

uses
  Winapi.Windows;

function DetectSystemLocale: string;
const
  LOCALE_NAME_MAX_LENGTH = 85;
var
  LBuffer: array[0..LOCALE_NAME_MAX_LENGTH - 1] of WideChar;
  LLen: Integer;
  LLangId: LANGID;
begin
  // [i18n 2026-08-25] 显式覆盖优先：DEEPBASE_LANG 环境变量（如 zh-CN / en-US）。
  // 自动检测在"英文 Windows + 中文用户"的机器上会返回 en-US，此时以此开关
  // 强制界面语言，无需改系统设置。
  var LOverride := GetEnvironmentVariable('DEEPBASE_LANG');
  if LOverride <> '' then
    Exit(LOverride);
  // [i18n 2026-08-25] 用户 **UI 语言**（显示语言）优先——GetUserDefaultLocaleName
  // 返回的是区域格式（Regional Format），机器完全可能"显示语言中文 + 区域格式
  // 英文"，此时按旧逻辑会错配 en-US。先取 GetUserDefaultUILanguage 的
  // LOCALE_SNAME（BCP-47 如 'zh-CN'），失败再退回区域格式，最后 en-US。
  LLangId := GetUserDefaultUILanguage;
  LLen := GetLocaleInfoW(LLangId, LOCALE_SNAME, LBuffer, LOCALE_NAME_MAX_LENGTH);
  if LLen > 1 then
  begin
    Result := string(PWideChar(@LBuffer[0]));
    if Result <> '' then
      Exit;
  end;
  // Prefer GetUserDefaultLocaleName (BCP-47 form like 'zh-CN' / 'en-US').
  LLen := GetUserDefaultLocaleName(LBuffer, LOCALE_NAME_MAX_LENGTH);
  if LLen > 1 then
  begin
    // GetUserDefaultLocaleName returns length INCLUDING the null terminator.
    Result := string(PWideChar(@LBuffer[0]));
    if Result <> '' then
      Exit;
  end;
  // [i18n 2026-08-25] 中国区常见"英文显示语言 + 中文区域"配置：系统 ANSI
  // 代码页 936(GB2312) 时按中文用户对待。
  if GetACP = 936 then
    Exit('zh-CN');
  Result := 'en-US';
end;

{ TShellDefaultLocalizationService }

constructor TShellDefaultLocalizationService.Create(const ADefaultLocale: string);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FLocales := TList<string>.Create;
  FTexts := TObjectDictionary<string, TDictionary<string, string>>.Create([doOwnsValues]);
  FSubs := TList<TSub>.Create;
  FNextToken := 0;
  FLocale := if ADefaultLocale <> '' then ADefaultLocale else DetectSystemLocale;
  FLocales.Add(FLocale);
  FTexts.Add(FLocale, TDictionary<string, string>.Create);
end;

destructor TShellDefaultLocalizationService.Destroy;
begin
  FreeAndNil(FSubs);
  FreeAndNil(FTexts);
  FreeAndNil(FLocales);
  FreeAndNil(FLock);
  inherited;
end;

function TShellDefaultLocalizationService.EnsureLocaleBucket(
  const ALocale: string): TDictionary<string, string>;
begin
  if not FTexts.TryGetValue(ALocale, Result) then
  begin
    Result := TDictionary<string, string>.Create;
    FTexts.Add(ALocale, Result);
    if not FLocales.Contains(ALocale) then
      FLocales.Add(ALocale);
  end;
end;

procedure TShellDefaultLocalizationService.RegisterText(const ALocale, AKey,
  AText: string);
var
  LBucket: TDictionary<string, string>;
begin
  if (ALocale = '') or (AKey = '') then
    Exit;
  FLock.Enter;
  try
    LBucket := EnsureLocaleBucket(ALocale);
    LBucket.AddOrSetValue(AKey, AText);
  finally
    FLock.Leave;
  end;
end;

procedure TShellDefaultLocalizationService.RegisterLocale(const ALocale: string);
begin
  if ALocale = '' then
    Exit;
  FLock.Enter;
  try
    EnsureLocaleBucket(ALocale);
  finally
    FLock.Leave;
  end;
end;

function TShellDefaultLocalizationService.Text(const AKey, ADefault: string): string;
var
  LBucket: TDictionary<string, string>;
begin
  Result := ADefault;
  FLock.Enter;
  try
    if FTexts.TryGetValue(FLocale, LBucket) then
      if LBucket.TryGetValue(AKey, Result) then
        Exit;
    Result := ADefault;
  finally
    FLock.Leave;
  end;
end;

function TShellDefaultLocalizationService.CurrentLocale: string;
begin
  FLock.Enter;
  try
    Result := FLocale;
  finally
    FLock.Leave;
  end;
end;

procedure TShellDefaultLocalizationService.SetLocale(const ALocale: string);
var
  LSnapshot: TArray<TSub>;
  I: Integer;
begin
  if ALocale = '' then
    Exit;
  FLock.Enter;
  try
    if SameText(FLocale, ALocale) then
      Exit;
    EnsureLocaleBucket(ALocale);
    FLocale := ALocale;
    LSnapshot := FSubs.ToArray;
  finally
    FLock.Leave;
  end;

  var LIsMain := TThread.CurrentThread.ThreadID = MainThreadID;
  for I := 0 to High(LSnapshot) do
  begin
    var LHandler := LSnapshot[I].Handler;
    var LLocaleId := ALocale;
    if LIsMain then
      try LHandler(LLocaleId) except end
    else
      TThread.Queue(nil,
        procedure
        begin
          try LHandler(LLocaleId) except end;
        end);
  end;
end;

function TShellDefaultLocalizationService.GetLocales: TArray<string>;
begin
  FLock.Enter;
  try
    Result := FLocales.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TShellDefaultLocalizationService.OnLocaleChanged(
  AHandler: TShellLocaleChangedHandler): string;
var
  LSub: TSub;
begin
  if not Assigned(AHandler) then
    raise EArgumentNilException.Create('TShellDefaultLocalizationService.OnLocaleChanged: nil handler');
  LSub.Token := Format('loc-%d', [TInterlocked.Increment(FNextToken)]);
  LSub.Handler := AHandler;
  FLock.Enter;
  try
    FSubs.Add(LSub);
  finally
    FLock.Leave;
  end;
  Result := LSub.Token;
end;

procedure TShellDefaultLocalizationService.RemoveLocaleChanged(const AToken: string);
var
  I: Integer;
begin
  FLock.Enter;
  try
    for I := FSubs.Count - 1 downto 0 do
      if FSubs[I].Token = AToken then
      begin
        FSubs.Delete(I);
        Break;
      end;
  finally
    FLock.Leave;
  end;
end;

end.
