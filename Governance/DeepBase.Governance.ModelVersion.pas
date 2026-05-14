// AI-GENERATED
// DeepBase.Governance.ModelVersion.pas
// P09：元模型与版本层 — KeyPolicy / ModelVersion / ChangeSet / RouteVersion

unit DeepBase.Governance.ModelVersion;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TChangeKind = (ckAdd, ckModify, ckRemove, ckEnable, ckDisable);

  TChangeEntry = record
    Id: string;
    ChangeKind: TChangeKind;
    ObjectType: string;
    ObjectKey: string;
    OldValue: string;
    NewValue: string;
    Timestamp: TDateTime;
  end;

  TChangeSet = class
  private
    FId: string;
    FVersion: Integer;
    FDescription: string;
    FAuthor: string;
    FCreatedAt: TDateTime;
    FEntries: TList<TChangeEntry>;
  public
    constructor Create(AVersion: Integer; const ADescription, AAuthor: string);
    destructor Destroy; override;
    procedure AddEntry(AKind: TChangeKind; const AObjectType, AObjectKey, AOldValue, ANewValue: string);
    function GetEntries: TArray<TChangeEntry>;
    function EntryCount: Integer;
    property Id: string read FId;
    property Version: Integer read FVersion;
    property Description: string read FDescription;
    property Author: string read FAuthor;
    property CreatedAt: TDateTime read FCreatedAt;
  end;

  TModelVersion = class
  private
    FCurrentVersion: Integer;
    FChangeSets: TObjectList<TChangeSet>;
  public
    constructor Create;
    destructor Destroy; override;
    function CreateChangeSet(const ADescription, AAuthor: string): TChangeSet;
    function GetCurrentVersion: Integer;
    function GetChangeSet(AVersion: Integer): TChangeSet;
    function Rollback(AToVersion: Integer): Boolean;
    function GetHistory: TArray<TChangeSet>;
    property CurrentVersion: Integer read FCurrentVersion;
  end;

  TViewScopeVisibility = (vsvVisible, vsvHidden, vsvLocked);

  TViewScopeEntry = record
    ObjectKey: string;
    Audience: string;  // 'user' / 'dev' / 'ai'
    Visibility: TViewScopeVisibility;
  end;

  TViewScope = class
  private
    FEntries: TList<TViewScopeEntry>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetVisibility(const AObjectKey, AAudience: string; AVisibility: TViewScopeVisibility);
    function GetVisibility(const AObjectKey, AAudience: string): TViewScopeVisibility;
    function IsVisible(const AObjectKey, AAudience: string): Boolean;
    function GetVisibleKeys(const AAudience: string): TArray<string>;
  end;

implementation

{ TChangeSet }

constructor TChangeSet.Create(AVersion: Integer; const ADescription, AAuthor: string);
begin
  inherited Create;
  FId := TGUID.NewGuid.ToString;
  FVersion := AVersion;
  FDescription := ADescription;
  FAuthor := AAuthor;
  FCreatedAt := Now;
  FEntries := TList<TChangeEntry>.Create;
end;

destructor TChangeSet.Destroy;
begin
  FEntries.Free;
  inherited;
end;

procedure TChangeSet.AddEntry(AKind: TChangeKind; const AObjectType, AObjectKey, AOldValue, ANewValue: string);
var
  E: TChangeEntry;
begin
  E.Id := TGUID.NewGuid.ToString;
  E.ChangeKind := AKind;
  E.ObjectType := AObjectType;
  E.ObjectKey := AObjectKey;
  E.OldValue := AOldValue;
  E.NewValue := ANewValue;
  E.Timestamp := Now;
  FEntries.Add(E);
end;

function TChangeSet.GetEntries: TArray<TChangeEntry>;
begin
  Result := FEntries.ToArray;
end;

function TChangeSet.EntryCount: Integer;
begin
  Result := FEntries.Count;
end;

{ TModelVersion }

constructor TModelVersion.Create;
begin
  inherited Create;
  FCurrentVersion := 0;
  FChangeSets := TObjectList<TChangeSet>.Create(True);
end;

destructor TModelVersion.Destroy;
begin
  FChangeSets.Free;
  inherited;
end;

function TModelVersion.CreateChangeSet(const ADescription, AAuthor: string): TChangeSet;
begin
  Inc(FCurrentVersion);
  Result := TChangeSet.Create(FCurrentVersion, ADescription, AAuthor);
  FChangeSets.Add(Result);
end;

function TModelVersion.GetCurrentVersion: Integer;
begin
  Result := FCurrentVersion;
end;

function TModelVersion.GetChangeSet(AVersion: Integer): TChangeSet;
var
  CS: TChangeSet;
begin
  for CS in FChangeSets do
    if CS.Version = AVersion then
      Exit(CS);
  Result := nil;
end;

function TModelVersion.Rollback(AToVersion: Integer): Boolean;
begin
  if (AToVersion >= 0) and (AToVersion < FCurrentVersion) then
  begin
    FCurrentVersion := AToVersion;
    Result := True;
  end
  else
    Result := False;
end;

function TModelVersion.GetHistory: TArray<TChangeSet>;
begin
  Result := FChangeSets.ToArray;
end;

{ TViewScope }

constructor TViewScope.Create;
begin
  inherited Create;
  FEntries := TList<TViewScopeEntry>.Create;
end;

destructor TViewScope.Destroy;
begin
  FEntries.Free;
  inherited;
end;

procedure TViewScope.SetVisibility(const AObjectKey, AAudience: string; AVisibility: TViewScopeVisibility);
var
  I: Integer;
  E: TViewScopeEntry;
begin
  for I := 0 to FEntries.Count - 1 do
    if SameText(FEntries[I].ObjectKey, AObjectKey) and SameText(FEntries[I].Audience, AAudience) then
    begin
      E := FEntries[I];
      E.Visibility := AVisibility;
      FEntries[I] := E;
      Exit;
    end;
  E.ObjectKey := AObjectKey;
  E.Audience := AAudience;
  E.Visibility := AVisibility;
  FEntries.Add(E);
end;

function TViewScope.GetVisibility(const AObjectKey, AAudience: string): TViewScopeVisibility;
var
  Entry: TViewScopeEntry;
begin
  for Entry in FEntries do
    if SameText(Entry.ObjectKey, AObjectKey) and SameText(Entry.Audience, AAudience) then
      Exit(Entry.Visibility);
  Result := vsvVisible;  // default visible
end;

function TViewScope.IsVisible(const AObjectKey, AAudience: string): Boolean;
begin
  Result := GetVisibility(AObjectKey, AAudience) = vsvVisible;
end;

function TViewScope.GetVisibleKeys(const AAudience: string): TArray<string>;
var
  LList: TList<string>;
  Entry: TViewScopeEntry;
begin
  LList := TList<string>.Create;
  try
    for Entry in FEntries do
      if SameText(Entry.Audience, AAudience) and (Entry.Visibility = vsvVisible) then
        LList.Add(Entry.ObjectKey);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

end.
