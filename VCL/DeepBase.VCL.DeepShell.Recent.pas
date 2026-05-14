{ ============================================================================
  DeepBase.VCL.DeepShell.Recent

  In-memory IShellRecentService implementation. Production apps should
  register a DB1-backed implementation; this is the default fallback used
  by tests and the demo.
  See docs/74.vcl.DeepShell-MRU-Layout-Settings设计.md
  ============================================================================ }

unit DeepBase.VCL.DeepShell.Recent;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.SyncObjs,
  System.Generics.Collections,
  System.Generics.Defaults,
  DeepBase.VCL.DeepShell.Types,
  DeepBase.VCL.DeepShell.Intf;

type
  TShellInMemoryRecentService = class(TInterfacedObject, IShellRecentService)
  private
    FLock: TCriticalSection;
    FItems: TList<TShellRecentItem>;
    FCapacity: Integer;
    function FindIndex(AKind: TShellRecentKind; const AItemKey: string): Integer;
    procedure TrimToCapacity;
  public
    constructor Create(ACapacity: Integer = 32);
    destructor Destroy; override;
    // IShellRecentService
    procedure AddRecent(const AItem: TShellRecentItem);
    procedure AddRecentProject(const AProjectId, APath, ADisplayName, ALayoutKey: string);
    function GetRecent(AKind: TShellRecentKind): TArray<TShellRecentItem>;
    function GetRecentProjects: TArray<TShellRecentItem>;
    procedure MarkInvalid(AKind: TShellRecentKind; const AItemKey: string);
    procedure Remove(AKind: TShellRecentKind; const AItemKey: string);
    procedure Clear;
  end;

implementation

{ TShellInMemoryRecentService }

constructor TShellInMemoryRecentService.Create(ACapacity: Integer);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FItems := TList<TShellRecentItem>.Create;
  FCapacity := if ACapacity > 0 then ACapacity else 32;
end;

destructor TShellInMemoryRecentService.Destroy;
begin
  FreeAndNil(FItems);
  FreeAndNil(FLock);
  inherited;
end;

function TShellInMemoryRecentService.FindIndex(AKind: TShellRecentKind;
  const AItemKey: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
    if (FItems[I].Kind = AKind) and SameText(FItems[I].ItemKey, AItemKey) then
      Exit(I);
  Result := -1;
end;

procedure TShellInMemoryRecentService.TrimToCapacity;
begin
  while FItems.Count > FCapacity do
    FItems.Delete(FItems.Count - 1);
end;

procedure TShellInMemoryRecentService.AddRecent(const AItem: TShellRecentItem);
var
  LItem: TShellRecentItem;
  LIdx: Integer;
begin
  if AItem.ItemKey = '' then
    raise EArgumentException.Create('TShellInMemoryRecentService.AddRecent: empty ItemKey');

  LItem := AItem;
  if LItem.LastOpenedAt = 0 then
    LItem.LastOpenedAt := Now;

  FLock.Enter;
  try
    LIdx := FindIndex(LItem.Kind, LItem.ItemKey);
    if LIdx >= 0 then
      FItems.Delete(LIdx);
    FItems.Insert(0, LItem);
    TrimToCapacity;
  finally
    FLock.Leave;
  end;
end;

procedure TShellInMemoryRecentService.AddRecentProject(const AProjectId, APath,
  ADisplayName, ALayoutKey: string);
var
  LItem: TShellRecentItem;
begin
  LItem := Default(TShellRecentItem);
  LItem.Kind := rkProject;
  LItem.ItemKey := if AProjectId <> '' then AProjectId else APath;
  LItem.ProjectId := AProjectId;
  LItem.Path := APath;
  LItem.DisplayName := if ADisplayName <> '' then ADisplayName else AProjectId;
  LItem.LayoutKey := ALayoutKey;
  LItem.LastOpenedAt := Now;
  AddRecent(LItem);
end;

function TShellInMemoryRecentService.GetRecent(AKind: TShellRecentKind): TArray<TShellRecentItem>;
var
  LList: TList<TShellRecentItem>;
  I: Integer;
begin
  LList := TList<TShellRecentItem>.Create;
  try
    FLock.Enter;
    try
      for I := 0 to FItems.Count - 1 do
        if FItems[I].Kind = AKind then
          LList.Add(FItems[I]);
    finally
      FLock.Leave;
    end;

    LList.Sort(TComparer<TShellRecentItem>.Construct(
      function(const L, R: TShellRecentItem): Integer
      begin
        Result := CompareDateTime(R.LastOpenedAt, L.LastOpenedAt);
      end));

    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TShellInMemoryRecentService.GetRecentProjects: TArray<TShellRecentItem>;
begin
  Result := GetRecent(rkProject);
end;

procedure TShellInMemoryRecentService.MarkInvalid(AKind: TShellRecentKind;
  const AItemKey: string);
var
  LIdx: Integer;
  LItem: TShellRecentItem;
begin
  FLock.Enter;
  try
    LIdx := FindIndex(AKind, AItemKey);
    if LIdx >= 0 then
    begin
      LItem := FItems[LIdx];
      LItem.Invalid := True;
      FItems[LIdx] := LItem;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TShellInMemoryRecentService.Remove(AKind: TShellRecentKind;
  const AItemKey: string);
var
  LIdx: Integer;
begin
  FLock.Enter;
  try
    LIdx := FindIndex(AKind, AItemKey);
    if LIdx >= 0 then
      FItems.Delete(LIdx);
  finally
    FLock.Leave;
  end;
end;

procedure TShellInMemoryRecentService.Clear;
begin
  FLock.Enter;
  try
    FItems.Clear;
  finally
    FLock.Leave;
  end;
end;

end.
