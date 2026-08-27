{ ============================================================================
  DeepBase.FMX.HB.NavTree - Multi-Tree Navigation for FMX

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform)
  Description: THbFmxNavTree for FMX.
  ============================================================================ }

unit DeepBase.FMX.HB.NavTree;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  DeepBase.HB.Core,
  DeepBase.HB.NavTree.Types,
  DeepBase.FMX.HB.Theme;

type
  /// <summary>
  /// THbFmxNavTree: Navigation tree for FMX.
  /// </summary>
  THbFmxNavTree = class(TControl)
  private
    FItems: TList<THbNavItemData>;
    FSelectedId: string;
    FIsCollapsed: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddSection(const ATitle: string);
    procedure AddItem(const AId, ATitle: string; const ABadge: string = '');
    procedure SelectNode(const AId: string);
    procedure Clear;

    property Items: TList<THbNavItemData> read FItems;
    property SelectedId: string read FSelectedId write SelectNode;
  published
    property Align;
    property IsCollapsed: Boolean read FIsCollapsed write FIsCollapsed default False;
  end;

implementation

{ THbFmxNavTree }

constructor THbFmxNavTree.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 220;
  Height := 400;
  FIsCollapsed := False;
  FSelectedId := '';
  FItems := TList<THbNavItemData>.Create;
end;

destructor THbFmxNavTree.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure THbFmxNavTree.AddSection(const ATitle: string);
var
  N: THbNavItemData;
begin
  N.Id := '';
  N.ParentId := '';
  N.Title := ATitle;
  N.Kind := nnSectionHeader;
  N.BadgeText := '';
  N.BadgeTone := btNeutral;
  N.ShortcutText := '';
  N.IsExpanded := True;
  N.IsSelected := False;
  N.IsVisible := True;
  N.Tag := 0;
  FItems.Add(N);
end;

procedure THbFmxNavTree.AddItem(const AId, ATitle, ABadge: string);
var
  N: THbNavItemData;
begin
  N.Id := AId;
  N.ParentId := '';
  N.Title := ATitle;
  N.Kind := nnItem;
  N.BadgeText := ABadge;
  N.BadgeTone := btBrand;
  N.ShortcutText := '';
  N.IsExpanded := True;
  N.IsSelected := False;
  N.IsVisible := True;
  N.Tag := 0;
  FItems.Add(N);
end;

procedure THbFmxNavTree.SelectNode(const AId: string);
begin
  FSelectedId := AId;
end;

procedure THbFmxNavTree.Clear;
begin
  FItems.Clear;
  FSelectedId := '';
end;

end.
