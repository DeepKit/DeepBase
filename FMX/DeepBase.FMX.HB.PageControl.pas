{ ============================================================================
  DeepBase.FMX.HB.PageControl - Modern Tab Control for FMX

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform)
  Description: THbFmxPageControl for FMX.
  ============================================================================ }

unit DeepBase.FMX.HB.PageControl;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  DeepBase.HB.Core,
  DeepBase.HB.PageControl.Types,
  DeepBase.FMX.HB.Theme;

type
  /// <summary>
  /// THbFmxPageControl: Modern Tab Control for FMX.
  /// </summary>
  THbFmxPageControl = class(TControl)
  private
    FTabs: TList<THbTabItemData>;
    FTabStyle: THbTabStyle;
    FActiveTabIndex: Integer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function AddTab(const AId, ATitle: string; ABadgeCount: Integer = 0): Integer;
    procedure RemoveTab(Index: Integer);
    procedure ClearTabs;

    property Tabs: TList<THbTabItemData> read FTabs;
  published
    property Align;
    property TabStyle: THbTabStyle read FTabStyle write FTabStyle default tsUnderline;
    property ActiveTabIndex: Integer read FActiveTabIndex write FActiveTabIndex default 0;
  end;

implementation

{ THbFmxPageControl }

constructor THbFmxPageControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 400;
  Height := 250;
  FTabStyle := tsUnderline;
  FActiveTabIndex := 0;
  FTabs := TList<THbTabItemData>.Create;
end;

destructor THbFmxPageControl.Destroy;
begin
  FTabs.Free;
  inherited;
end;

function THbFmxPageControl.AddTab(const AId, ATitle: string; ABadgeCount: Integer): Integer;
var
  T: THbTabItemData;
begin
  T.Id := AId;
  T.Title := ATitle;
  T.IconSvg := '';
  T.BadgeCount := ABadgeCount;
  T.IsClosable := False;
  T.IsEnabled := True;
  T.IsVisible := True;
  T.Tag := 0;
  Result := FTabs.Add(T);
  if FTabs.Count = 1 then
    FActiveTabIndex := 0;
end;

procedure THbFmxPageControl.RemoveTab(Index: Integer);
begin
  if (Index >= 0) and (Index < FTabs.Count) then
  begin
    FTabs.Delete(Index);
    if FActiveTabIndex >= FTabs.Count then
      FActiveTabIndex := FTabs.Count - 1;
  end;
end;

procedure THbFmxPageControl.ClearTabs;
begin
  FTabs.Clear;
  FActiveTabIndex := -1;
end;

end.
