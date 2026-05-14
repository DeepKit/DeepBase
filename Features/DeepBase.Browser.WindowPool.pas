{ ============================================================================
  DeepBase.Browser.WindowPool
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Multi-window pool manager for browser automation.
                Provides session pooling with Acquire/Release semantics,
                layout management, and integration with recovery monitoring.
                Engine-agnostic: works with any IBrowserSession implementation.
  ============================================================================ }

unit DeepBase.Browser.WindowPool;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  Winapi.Windows,
  DeepBase.Browser.Types;

type
  TBrowserWindowConfig = record
    Width: Integer;
    Height: Integer;
    X: Integer;
    Y: Integer;
    Visible: Boolean;
    UserDataFolder: string;
    class function Default: TBrowserWindowConfig; static;
  end;

  TLayoutMode = (
    lmGrid,
    lmHorizontal,
    lmVertical,
    lmCascade
  );

  TWindowLayout = record
    Mode: TLayoutMode;
    Rects: TArray<TRect>;
    class function CreateGrid(ACount, ARows, ACols: Integer;
      const AWorkArea: TRect): TWindowLayout; static;
    class function CreateHorizontal(ACount: Integer;
      const AWorkArea: TRect): TWindowLayout; static;
    class function CreateVertical(ACount: Integer;
      const AWorkArea: TRect): TWindowLayout; static;
  end;

  TSessionFactoryFunc = reference to function(
    const AConfig: TBrowserWindowConfig): IBrowserSession;

  TPoolEntry = class
    SessionId: TBrowserSessionId;
    Session: IBrowserSession;
    InUse: Boolean;
    Config: TBrowserWindowConfig;
  end;

  TBrowserWindowPool = class
  private
    FEntries: TObjectList<TPoolEntry>;
    FById: TDictionary<TBrowserSessionId, TPoolEntry>;
    FLock: TCriticalSection;
    FMaxPoolSize: Integer;
    FScreenMargin: Integer;
    FSessionFactory: TSessionFactoryFunc;
    FDefaultConfig: TBrowserWindowConfig;

    function GetWorkArea: TRect;
    function InternalAcquire: TPoolEntry;
  public
    constructor Create(
      ASessionFactory: TSessionFactoryFunc;
      const ADefaultConfig: TBrowserWindowConfig;
      AMaxPoolSize: Integer = 4);
    destructor Destroy; override;

    function Acquire(out ASessionId: TBrowserSessionId;
      out ASession: IBrowserSession): Boolean;
    procedure Release(const ASessionId: TBrowserSessionId);
    procedure ReleaseAll;
    procedure ShutdownAll;

    function GetSession(
      const ASessionId: TBrowserSessionId): IBrowserSession;
    function TryGetSession(
      const ASessionId: TBrowserSessionId;
      out ASession: IBrowserSession): Boolean;
    function GetActiveSessions: TArray<IBrowserSession>;
    function GetActiveIds: TArray<TBrowserSessionId>;

    procedure ApplyLayout(const ALayout: TWindowLayout);
    function GenerateGridLayout(ACount: Integer): TWindowLayout;
    function GenerateHorizontalLayout(
      ACount: Integer): TWindowLayout;
    function GenerateVerticalLayout(
      ACount: Integer): TWindowLayout;

    property MaxPoolSize: Integer read FMaxPoolSize;
    property ScreenMargin: Integer
      read FScreenMargin write FScreenMargin;
    property DefaultConfig: TBrowserWindowConfig
      read FDefaultConfig write FDefaultConfig;
  end;

implementation

uses
  System.Math,
  Vcl.Forms,
  DeepBase.Browser.Events,
  DeepBase.Logging;

{ TBrowserWindowConfig }

class function TBrowserWindowConfig.Default: TBrowserWindowConfig;
begin
  Result := System.Default(TBrowserWindowConfig);
  Result.Width := 800;
  Result.Height := 600;
  Result.X := 0;
  Result.Y := 0;
  Result.Visible := True;
end;

{ TWindowLayout }

class function TWindowLayout.CreateGrid(ACount, ARows, ACols: Integer;
  const AWorkArea: TRect): TWindowLayout;
var
  I: Integer;
  LCol, LRow: Integer;
  LCellW, LCellH: Integer;
begin
  // M8 fix: defensive against zero / negative grid divisors.
  if ACount <= 0 then
  begin
    Result.Mode := lmGrid;
    Result.Rects := nil;
    Exit;
  end;
  if ARows <= 0 then ARows := 1;
  if ACols <= 0 then ACols := 1;

  Result.Mode := lmGrid;
  SetLength(Result.Rects, ACount);
  LCellW := (AWorkArea.Width) div ACols;
  LCellH := (AWorkArea.Height) div ARows;
  for I := 0 to ACount - 1 do
  begin
    LCol := I mod ACols;
    LRow := I div ACols;
    Result.Rects[I] := Rect(
      AWorkArea.Left + LCol * LCellW,
      AWorkArea.Top + LRow * LCellH,
      AWorkArea.Left + (LCol + 1) * LCellW,
      AWorkArea.Top + (LRow + 1) * LCellH);
  end;
end;

class function TWindowLayout.CreateHorizontal(ACount: Integer;
  const AWorkArea: TRect): TWindowLayout;
var
  I: Integer;
  LCellW: Integer;
begin
  // M8 fix: handle empty layout request gracefully
  if ACount <= 0 then
  begin
    Result.Mode := lmHorizontal;
    Result.Rects := nil;
    Exit;
  end;

  Result.Mode := lmHorizontal;
  SetLength(Result.Rects, ACount);
  LCellW := (AWorkArea.Width) div ACount;
  for I := 0 to ACount - 1 do
    Result.Rects[I] := Rect(
      AWorkArea.Left + I * LCellW,
      AWorkArea.Top,
      AWorkArea.Left + (I + 1) * LCellW,
      AWorkArea.Bottom);
end;

class function TWindowLayout.CreateVertical(ACount: Integer;
  const AWorkArea: TRect): TWindowLayout;
var
  I: Integer;
  LCellH: Integer;
begin
  // M8 fix: handle empty layout request gracefully
  if ACount <= 0 then
  begin
    Result.Mode := lmVertical;
    Result.Rects := nil;
    Exit;
  end;

  Result.Mode := lmVertical;
  SetLength(Result.Rects, ACount);
  LCellH := (AWorkArea.Height) div ACount;
  for I := 0 to ACount - 1 do
    Result.Rects[I] := Rect(
      AWorkArea.Left,
      AWorkArea.Top + I * LCellH,
      AWorkArea.Right,
      AWorkArea.Top + (I + 1) * LCellH);
end;

{ TBrowserWindowPool }

constructor TBrowserWindowPool.Create(
  ASessionFactory: TSessionFactoryFunc;
  const ADefaultConfig: TBrowserWindowConfig;
  AMaxPoolSize: Integer);
begin
  inherited Create;
  FSessionFactory := ASessionFactory;
  FDefaultConfig := ADefaultConfig;
  FMaxPoolSize := AMaxPoolSize;
  FScreenMargin := 50;
  FEntries := TObjectList<TPoolEntry>.Create(True);
  FById := TDictionary<TBrowserSessionId, TPoolEntry>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TBrowserWindowPool.Destroy;
begin
  ShutdownAll;
  FById.Free;
  FEntries.Free;
  FLock.Free;
  inherited;
end;

function TBrowserWindowPool.GetWorkArea: TRect;
begin
  Result := Screen.WorkAreaRect;
  Result.Left := Result.Left + FScreenMargin;
  Result.Top := Result.Top + FScreenMargin;
  Result.Right := Result.Right - FScreenMargin;
  Result.Bottom := Result.Bottom - FScreenMargin;
end;

function TBrowserWindowPool.InternalAcquire: TPoolEntry;
var
  LEntry: TPoolEntry;
begin
  // Try to find an existing idle entry
  for LEntry in FEntries do
    if not LEntry.InUse then
    begin
      LEntry.InUse := True;
      Exit(LEntry);
    end;

  // Create a new entry if under pool limit
  if FEntries.Count < FMaxPoolSize then
  begin
    LEntry := TPoolEntry.Create;
    LEntry.Config := FDefaultConfig;
    LEntry.Session := FSessionFactory(FDefaultConfig);
    LEntry.SessionId := LEntry.Session.GetSessionId;
    LEntry.InUse := True;
    FEntries.Add(LEntry);
    FById.AddOrSetValue(LEntry.SessionId, LEntry);

    TBrowserEvents.Publish(betWindowOpened,
      LEntry.SessionId,
      '{"width":' + IntToStr(FDefaultConfig.Width) +
      ',"height":' + IntToStr(FDefaultConfig.Height) + '}');

    Exit(LEntry);
  end;

  Result := nil;
end;

function TBrowserWindowPool.Acquire(
  out ASessionId: TBrowserSessionId;
  out ASession: IBrowserSession): Boolean;
var
  LEntry: TPoolEntry;
begin
  ASessionId := '';
  ASession := nil;

  FLock.Enter;
  try
    LEntry := InternalAcquire;
    if LEntry = nil then
      Exit(False);
    ASessionId := LEntry.SessionId;
    ASession := LEntry.Session;
    Result := True;
  finally
    FLock.Leave;
  end;
end;

procedure TBrowserWindowPool.Release(
  const ASessionId: TBrowserSessionId);
var
  LEntry: TPoolEntry;
begin
  FLock.Enter;
  try
    if FById.TryGetValue(ASessionId, LEntry) then
      LEntry.InUse := False;
  finally
    FLock.Leave;
  end;

  // M7 fix: window is returned to the pool, not actually closed
  TBrowserEvents.Publish(betWindowReleased, ASessionId, '');
end;

procedure TBrowserWindowPool.ReleaseAll;
var
  LEntry: TPoolEntry;
begin
  FLock.Enter;
  try
    for LEntry in FEntries do
      LEntry.InUse := False;
  finally
    FLock.Leave;
  end;
end;

procedure TBrowserWindowPool.ShutdownAll;
var
  LId: TBrowserSessionId;
  LIds: TArray<TBrowserSessionId>;
  LEntries: TArray<TPoolEntry>;
  LEntry: TPoolEntry;
  I: Integer;
begin
  // BUG-BA-015 fix: snapshot inside lock, release/dispose outside
  FLock.Enter;
  try
    LIds := FById.Keys.ToArray;
    SetLength(LEntries, FEntries.Count);
    for I := 0 to FEntries.Count - 1 do
      LEntries[I] := FEntries[I];
    FEntries.OwnsObjects := False;  // we'll free them ourselves
    FEntries.Clear;
    FById.Clear;
  finally
    FLock.Leave;
  end;

  // Outside the lock: publish events + free entries (which decreases the
  // IBrowserSession refcount and may invoke synchronous browser shutdown).
  for LId in LIds do
    TBrowserEvents.Publish(betWindowClosed, LId, '');

  for LEntry in LEntries do
    LEntry.Free;

  // Restore ownership for future entries
  FLock.Enter;
  try
    FEntries.OwnsObjects := True;
  finally
    FLock.Leave;
  end;
end;

function TBrowserWindowPool.GetSession(
  const ASessionId: TBrowserSessionId): IBrowserSession;
begin
  if not TryGetSession(ASessionId, Result) then
    Result := nil;
end;

function TBrowserWindowPool.TryGetSession(
  const ASessionId: TBrowserSessionId;
  out ASession: IBrowserSession): Boolean;
var
  LEntry: TPoolEntry;
begin
  ASession := nil;
  FLock.Enter;
  try
    Result := FById.TryGetValue(ASessionId, LEntry);
    if Result then
      ASession := LEntry.Session;
  finally
    FLock.Leave;
  end;
end;

function TBrowserWindowPool.GetActiveSessions: TArray<IBrowserSession>;
var
  LList: TList<IBrowserSession>;
  LEntry: TPoolEntry;
begin
  LList := TList<IBrowserSession>.Create;
  try
    FLock.Enter;
    try
      for LEntry in FEntries do
        if LEntry.InUse then
          LList.Add(LEntry.Session);
    finally
      FLock.Leave;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TBrowserWindowPool.GetActiveIds: TArray<TBrowserSessionId>;
var
  LList: TList<TBrowserSessionId>;
  LEntry: TPoolEntry;
begin
  LList := TList<TBrowserSessionId>.Create;
  try
    FLock.Enter;
    try
      for LEntry in FEntries do
        if LEntry.InUse then
          LList.Add(LEntry.SessionId);
    finally
      FLock.Leave;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

procedure TBrowserWindowPool.ApplyLayout(
  const ALayout: TWindowLayout);
var
  LActive: TArray<TBrowserSessionId>;
  I: Integer;
  LEntry: TPoolEntry;
begin
  LActive := GetActiveIds;
  for I := 0 to Min(Length(LActive), Length(ALayout.Rects)) - 1 do
  begin
    FLock.Enter;
    try
      if FById.TryGetValue(LActive[I], LEntry) then
      begin
        LEntry.Config.X := ALayout.Rects[I].Left;
        LEntry.Config.Y := ALayout.Rects[I].Top;
        LEntry.Config.Width := ALayout.Rects[I].Width;
        LEntry.Config.Height := ALayout.Rects[I].Height;
      end;
    finally
      FLock.Leave;
    end;
  end;
end;

function TBrowserWindowPool.GenerateGridLayout(
  ACount: Integer): TWindowLayout;
var
  LCols: Integer;
  LRows: Integer;
begin
  LCols := Ceil(Sqrt(ACount));
  LRows := Ceil(ACount / LCols);
  Result := TWindowLayout.CreateGrid(ACount, LRows, LCols,
    GetWorkArea);
end;

function TBrowserWindowPool.GenerateHorizontalLayout(
  ACount: Integer): TWindowLayout;
begin
  Result := TWindowLayout.CreateHorizontal(ACount, GetWorkArea);
end;

function TBrowserWindowPool.GenerateVerticalLayout(
  ACount: Integer): TWindowLayout;
begin
  Result := TWindowLayout.CreateVertical(ACount, GetWorkArea);
end;

end.
