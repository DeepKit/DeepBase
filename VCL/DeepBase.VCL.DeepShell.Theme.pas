{ ============================================================================
  DeepBase.VCL.DeepShell.Theme

  Default IShellThemeService implementation. Tracks the active theme id and
  notifies subscribers when it changes. Actual theme application against
  VCL styles is left to adapter units (themes are applied by the host or
  by a registered ThemeAdapter), keeping the shell core decoupled from
  Vcl.Themes API surfaces beyond what is required for in-process tracking.
  ============================================================================ }

unit DeepBase.VCL.DeepShell.Theme;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  DeepBase.VCL.DeepShell.Intf;

type
  TShellDefaultThemeService = class(TInterfacedObject, IShellThemeService)
  private
    type
      TSub = record
        Token: string;
        Handler: TShellThemeChangedHandler;
      end;
  private
    FLock: TCriticalSection;
    FCurrent: string;
    FThemes: TList<string>;
    FSubs: TList<TSub>;
    FNextToken: Int64;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterTheme(const AThemeId: string);
    // IShellThemeService
    function CurrentTheme: string;
    procedure ApplyTheme(const AThemeId: string);
    function GetThemes: TArray<string>;
    function OnThemeChanged(AHandler: TShellThemeChangedHandler): string;
    procedure RemoveThemeChanged(const AToken: string);
  end;

implementation

{ TShellDefaultThemeService }

constructor TShellDefaultThemeService.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FThemes := TList<string>.Create;
  FSubs := TList<TSub>.Create;
  FNextToken := 0;
  // Sensible defaults; downstream may add more via RegisterTheme.
  FThemes.Add('Light');
  FThemes.Add('Dark');
  FThemes.Add('System');
  FCurrent := 'System';
end;

destructor TShellDefaultThemeService.Destroy;
begin
  FreeAndNil(FSubs);
  FreeAndNil(FThemes);
  FreeAndNil(FLock);
  inherited;
end;

procedure TShellDefaultThemeService.RegisterTheme(const AThemeId: string);
begin
  if AThemeId = '' then
    Exit;
  FLock.Enter;
  try
    if not FThemes.Contains(AThemeId) then
      FThemes.Add(AThemeId);
  finally
    FLock.Leave;
  end;
end;

function TShellDefaultThemeService.CurrentTheme: string;
begin
  FLock.Enter;
  try
    Result := FCurrent;
  finally
    FLock.Leave;
  end;
end;

procedure TShellDefaultThemeService.ApplyTheme(const AThemeId: string);
var
  LSnapshot: TArray<TSub>;
  I: Integer;
begin
  FLock.Enter;
  try
    if AThemeId = '' then
      Exit;
    // Auto-register the theme if it's new.
    if not FThemes.Contains(AThemeId) then
      FThemes.Add(AThemeId);
    if SameText(FCurrent, AThemeId) then
      Exit;
    FCurrent := AThemeId;
    LSnapshot := FSubs.ToArray;
  finally
    FLock.Leave;
  end;

  var LIsMain := TThread.CurrentThread.ThreadID = MainThreadID;
  for I := 0 to High(LSnapshot) do
  begin
    var LHandler := LSnapshot[I].Handler;
    var LId := AThemeId;
    if LIsMain then
      try LHandler(LId) except end
    else
      TThread.Queue(nil,
        procedure
        begin
          try LHandler(LId) except end;
        end);
  end;
end;

function TShellDefaultThemeService.GetThemes: TArray<string>;
begin
  FLock.Enter;
  try
    Result := FThemes.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TShellDefaultThemeService.OnThemeChanged(
  AHandler: TShellThemeChangedHandler): string;
var
  LSub: TSub;
begin
  if not Assigned(AHandler) then
    raise EArgumentNilException.Create('TShellDefaultThemeService.OnThemeChanged: nil handler');
  LSub.Token := Format('thm-%d', [TInterlocked.Increment(FNextToken)]);
  LSub.Handler := AHandler;
  FLock.Enter;
  try
    FSubs.Add(LSub);
  finally
    FLock.Leave;
  end;
  Result := LSub.Token;
end;

procedure TShellDefaultThemeService.RemoveThemeChanged(const AToken: string);
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
