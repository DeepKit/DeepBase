{ ============================================================================
  DeepBase.Browser.Registry
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Backend registry for Browser Automation. Each backend
                self-registers during unit initialization. Consumers discover
                available backends through this registry.
  Thread Safety: All public methods are thread-safe (TMonitor on FLock).
  ============================================================================ }

unit DeepBase.Browser.Registry;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  DeepBase.Browser.Types;

type
  TBrowserBackendKind = (
    bbkWebView2,
    bbkCEF,
    bbkCustom
  );

  TBrowserBackendInfo = record
    Kind: TBrowserBackendKind;
    Name: string;
    IsAvailableFunc: TFunc<Boolean>;
    FactoryFunc: TFunc<IBrowserSession>;
    Enabled: Boolean;
    Priority: Integer;
  end;

  TBrowserRegistry = class
  private
    class var FLock: TObject;
    class var FBackends: TList<TBrowserBackendInfo>;
    // Kept for backward compat; no-op now that class constructor handles init.
    class procedure EnsureInit; static;
  public
    // H6 fix: class constructors run before any class method and are
    // guaranteed single-threaded by the Delphi RTL, eliminating the
    // EnsureInit TOCTOU race.
    class constructor Create;
    class destructor Destroy;

    class procedure Register(const AInfo: TBrowserBackendInfo);
    class procedure Unregister(const AName: string;
      AKind: TBrowserBackendKind);
    class procedure Disable(const AName: string;
      AKind: TBrowserBackendKind);
    class procedure Enable(const AName: string;
      AKind: TBrowserBackendKind);
    class procedure SetPriority(const AName: string;
      AKind: TBrowserBackendKind; APriority: Integer);

    class function Discover(AOnlyAvailable: Boolean = True):
      TArray<TBrowserBackendInfo>;
    class function FindBest: TBrowserBackendInfo;
    class function IsRegistered(const AName: string;
      AKind: TBrowserBackendKind): Boolean;
    class function Count: Integer;
    class function CreateSession(
      const ABackendName: string = ''): IBrowserSession;
  end;

implementation

uses
  System.Math;

{ TBrowserRegistry }

class constructor TBrowserRegistry.Create;
begin
  FLock := TObject.Create;
  FBackends := TList<TBrowserBackendInfo>.Create;
end;

class destructor TBrowserRegistry.Destroy;
begin
  FreeAndNil(FBackends);
  FreeAndNil(FLock);
end;

class procedure TBrowserRegistry.EnsureInit;
begin
  // H6 fix: no-op; class constructor performs initialization atomically.
end;

class procedure TBrowserRegistry.Register(
  const AInfo: TBrowserBackendInfo);
var
  I: Integer;
begin
  EnsureInit;
  TMonitor.Enter(FLock);
  try
    for I := 0 to FBackends.Count - 1 do
      if (FBackends[I].Name = AInfo.Name) and
        (FBackends[I].Kind = AInfo.Kind) then
      begin
        FBackends[I] := AInfo;
        Exit;
      end;
    FBackends.Add(AInfo);
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TBrowserRegistry.Unregister(const AName: string;
  AKind: TBrowserBackendKind);
var
  I: Integer;
begin
  EnsureInit;
  TMonitor.Enter(FLock);
  try
    for I := FBackends.Count - 1 downto 0 do
      if (FBackends[I].Name = AName) and
        (FBackends[I].Kind = AKind) then
      begin
        FBackends.Delete(I);
        Break;
      end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TBrowserRegistry.Disable(const AName: string;
  AKind: TBrowserBackendKind);
var
  I: Integer;
  LInfo: TBrowserBackendInfo;
begin
  EnsureInit;
  TMonitor.Enter(FLock);
  try
    for I := 0 to FBackends.Count - 1 do
      if (FBackends[I].Name = AName) and
        (FBackends[I].Kind = AKind) then
      begin
        LInfo := FBackends[I];
        LInfo.Enabled := False;
        FBackends[I] := LInfo;
        Exit;
      end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TBrowserRegistry.Enable(const AName: string;
  AKind: TBrowserBackendKind);
var
  I: Integer;
  LInfo: TBrowserBackendInfo;
begin
  EnsureInit;
  TMonitor.Enter(FLock);
  try
    for I := 0 to FBackends.Count - 1 do
      if (FBackends[I].Name = AName) and
        (FBackends[I].Kind = AKind) then
      begin
        LInfo := FBackends[I];
        LInfo.Enabled := True;
        FBackends[I] := LInfo;
        Exit;
      end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TBrowserRegistry.SetPriority(const AName: string;
  AKind: TBrowserBackendKind; APriority: Integer);
var
  I: Integer;
  LInfo: TBrowserBackendInfo;
begin
  EnsureInit;
  TMonitor.Enter(FLock);
  try
    for I := 0 to FBackends.Count - 1 do
      if (FBackends[I].Name = AName) and
        (FBackends[I].Kind = AKind) then
      begin
        LInfo := FBackends[I];
        LInfo.Priority := APriority;
        FBackends[I] := LInfo;
        Exit;
      end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TBrowserRegistry.Discover(
  AOnlyAvailable: Boolean): TArray<TBrowserBackendInfo>;
var
  LResult: TList<TBrowserBackendInfo>;
  LInfo: TBrowserBackendInfo;
begin
  EnsureInit;
  LResult := TList<TBrowserBackendInfo>.Create;
  try
    TMonitor.Enter(FLock);
    try
      for LInfo in FBackends do
      begin
        if not LInfo.Enabled then
          Continue;
        if AOnlyAvailable and Assigned(LInfo.IsAvailableFunc) and
          not LInfo.IsAvailableFunc() then
          Continue;
        LResult.Add(LInfo);
      end;
    finally
      TMonitor.Exit(FLock);
    end;
    LResult.Sort(TComparer<TBrowserBackendInfo>.Construct(
      function(const L, R: TBrowserBackendInfo): Integer
      begin
        // BUG-BA-020 fix: avoid integer overflow on extreme priority values
        Result := CompareValue(L.Priority, R.Priority);
      end));
    Result := LResult.ToArray;
  finally
    LResult.Free;
  end;
end;

class function TBrowserRegistry.FindBest: TBrowserBackendInfo;
var
  LAll: TArray<TBrowserBackendInfo>;
begin
  LAll := Discover(True);
  if Length(LAll) > 0 then
    Result := LAll[0]
  else
  begin
    Result := Default(TBrowserBackendInfo);
    Result.Name := '';
    Result.Enabled := False;
  end;
end;

class function TBrowserRegistry.IsRegistered(const AName: string;
  AKind: TBrowserBackendKind): Boolean;
var
  LInfo: TBrowserBackendInfo;
begin
  EnsureInit;
  Result := False;
  TMonitor.Enter(FLock);
  try
    for LInfo in FBackends do
      if (LInfo.Name = AName) and (LInfo.Kind = AKind) then
        Exit(True);
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TBrowserRegistry.Count: Integer;
begin
  EnsureInit;
  TMonitor.Enter(FLock);
  try
    Result := FBackends.Count;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TBrowserRegistry.CreateSession(
  const ABackendName: string): IBrowserSession;
var
  LInfo: TBrowserBackendInfo;
  LAll: TArray<TBrowserBackendInfo>;
begin
  Result := nil;

  if ABackendName <> '' then
  begin
    TMonitor.Enter(FLock);
    try
      for LInfo in FBackends do
        if SameText(LInfo.Name, ABackendName) and LInfo.Enabled then
        begin
          if not Assigned(LInfo.FactoryFunc) then
            raise EBrowserError.CreateFmt(
              'Backend "%s" has no factory function', [ABackendName]);
          Result := LInfo.FactoryFunc();
          Exit;
        end;
    finally
      TMonitor.Exit(FLock);
    end;
    raise EBrowserError.CreateFmt(
      'Backend "%s" not found or not enabled', [ABackendName]);
  end;

  LAll := Discover(True);
  if Length(LAll) = 0 then
    raise EBrowserError.Create('No browser backend available');

  LInfo := LAll[0];
  if not Assigned(LInfo.FactoryFunc) then
    raise EBrowserError.CreateFmt(
      'Backend "%s" has no factory function', [LInfo.Name]);

  Result := LInfo.FactoryFunc();
end;

// H6 fix: class constructor / destructor handle init+cleanup, no separate
// initialization / finalization needed.

end.
